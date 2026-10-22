extends SceneTree

var failures: Array[String] = []
var checks := 0
## Four chips must share one narrow ribbon row, so a fallen actor with all three
## stacks gets compact-but-complete names; the tooltip keeps the full ones.
const STATUS_SHORT := {"bleed": "Ble", "weak": "Wea", "exposed": "Exp"}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for frame in range(4):
		await process_frame


func _state(app) -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(), app.deck.hand.duplicate(),
		app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(), app.deck.energy,
		app.deck.turn_active, app.run_rng.state, app.enemy_intents.get_intents(), app.enemy_attacks.duplicate(true),
		app.enemy_intents._turn_index, app.battle_result.get_outcome()]


## Ordered live actors regardless of how each side wraps its slots.
func _collect_meters(node: Node, result: Array[CombatActorMeter]) -> void:
	for child in node.get_children():
		if child is CombatActorMeter:
			result.append(child)
		_collect_meters(child, result)


func _meters(app) -> Array[CombatActorMeter]:
	var result: Array[CombatActorMeter] = []
	var presenter = app.get_node_or_null("LiveCombatMeters")
	if presenter != null and is_instance_valid(presenter.row):
		_collect_meters(presenter.row, result)
	return result


func _buttons(meter: CombatActorMeter) -> HBoxContainer:
	return meter.get_node_or_null("Padding/Content/StatusButtons") as HBoxContainer


func _visible_buttons(meter: CombatActorMeter) -> Array[Button]:
	var shown: Array[Button] = []
	var buttons := _buttons(meter)
	if buttons == null:
		return shown
	for child in buttons.get_children():
		var button := child as Button
		if button != null and button.visible:
			shown.append(button)
	return shown


## The live stage slot of an actor, read from the mounted stage instead of the presenter.
func _slot(app, side: String, position: int) -> Control:
	if side == "hero":
		return app.hero_panels[position - 1] if position <= app.hero_panels.size() else null
	var roster = app.get_node_or_null("LiveEnemyRoster")
	if roster == null:
		return null
	if is_instance_valid(roster.panel) and roster.panel.get_child_count() > 0:
		var columns: Node = roster.panel.get_child(0)
		if columns != null and columns.get_child_count() >= position:
			return columns.get_child(position - 1) as Control
	if roster._puppets.size() > CombatParty.PARTY_SIZE + position - 1:
		return roster._puppets[CombatParty.PARTY_SIZE + position - 1] as Control
	return null


func _forecast(app) -> Dictionary:
	if app.enemy_intents != null and app.enemy_intents.is_valid():
		return CombatIncomingAttackPreview.new().forecast(
			app.party.get_heroes(), app.enemies.get_enemies(), app.enemy_intents.get_intents())
	return {"ok": false, "heroes": []}


func _expected_status(actor: Dictionary) -> String:
	var active: Array[String] = []
	var statuses: Dictionary = actor.get("statuses", {})
	for key in ["bleed", "weak", "exposed"]:
		var count: int = statuses.get(key, 0)
		if count > 0:
			active.append("%s %d" % [key.capitalize(), count])
	return "Statuses: none" if active.is_empty() else "Statuses: " + " · ".join(active)


func _expected_rules(actor: Dictionary) -> String:
	var rules: Array[String] = []
	if actor.hp > 0:
		var statuses: Dictionary = actor.get("statuses", {})
		if statuses.get("weak", 0) > 0:
			rules.append("Weak: -25% attack damage")
		if statuses.get("exposed", 0) > 0:
			rules.append("Exposed: +50% attack damage taken")
	return "\n".join(rules)


## Pure owner-turn oracle: the rendered warning may only describe this detached tick.
func _expected_bleed(actor: Dictionary) -> String:
	if actor.hp <= 0:
		return ""
	var tick: Dictionary = CombatStatuses.new().end_owner_turn(
		actor.hp, actor.block, actor.get("statuses", {}).duplicate(true))
	if not tick["ok"] or tick["bleed_hp_loss"] <= 0:
		return ""
	return "Bleed next: -%d HP (bypasses Block)%s" % [
		tick["bleed_hp_loss"], " — LETHAL" if tick["hp"] == 0 else ""]


func _expected_incoming(actor: Dictionary, forecast: Dictionary) -> String:
	if actor.hp == 0:
		return "DOWNED"
	if not forecast["ok"]:
		return "Incoming: unavailable"
	var next: Dictionary = forecast["heroes"][actor.position - 1]
	return "Incoming: none" if next["incoming"] == 0 else (
		"Incoming: %d Block, %d HP" % [next["block_absorbed"], next["hp_lost"]])


func _expected_chips(actor: Dictionary, side: String) -> Array[String]:
	var chips: Array[String] = []
	var stacks: Array[String] = []
	if actor.hp == 0:
		chips.append("DOWNED" if side == "hero" else "SLAIN")
	var statuses: Dictionary = actor.get("statuses", {})
	for key in ["bleed", "weak", "exposed"]:
		var count: int = statuses.get(key, 0)
		if count > 0:
			stacks.append(key)
	# Four chips share one narrow row, so their labels are compact but complete.
	var compact := chips.size() + stacks.size() > 3
	for key in stacks:
		var count: int = statuses[key]
		chips.append("%s %d" % [STATUS_SHORT[key] if compact else String(key).capitalize(), count])
	return chips


## Stable combined hover text: status model line, modifiers, hero forecast, owner Bleed.
func _expected_tooltip(actor: Dictionary, side: String, forecast: Dictionary) -> String:
	var lines: Array[String] = [_expected_status(actor)]
	var rules := _expected_rules(actor)
	if not rules.is_empty():
		lines.append(rules)
	if side == "hero":
		lines.append(_expected_incoming(actor, forecast))
	var bleed := _expected_bleed(actor)
	if not bleed.is_empty():
		lines.append(bleed)
	return "\n".join(lines)


func _incoming(app, position: int) -> String:
	var meters := _meters(app)
	if meters.size() < position or position < 1:
		return ""
	var label := meters[position - 1].get_node_or_null("Padding/Content/IncomingForecast") as Label
	return label.text if label != null else ""


## One ribbon must show exactly its actor's authoritative values and hover rules.
func _assert_ribbon(app, meter: CombatActorMeter, actor: Dictionary, side: String, forecast: Dictionary) -> void:
	var heading := "%d. %s" % [actor.position, actor.name]
	if actor.hp == 0:
		heading += " — DOWNED" if side == "hero" else " — SLAIN"
	_check(meter.actor_heading.text == heading and not meter.actor_heading.is_visible_in_tree(),
		"exact actor heading is retained but kept off the ribbon: " + meter.name)
	_check(meter.is_visible_in_tree() and meter.hp_text.is_visible_in_tree()
		and meter.hp_text.text == "HP: %d/%d" % [actor.hp, actor.max_hp],
		"ribbon shows the authoritative HP number: " + meter.name)
	_check(meter.hp_bar.is_visible_in_tree() and meter.hp_bar.value == actor.hp
		and meter.hp_bar.max_value == actor.max_hp, "ribbon HP bar matches the model: " + meter.name)
	_check(meter.block_text.is_visible_in_tree() and meter.block_text.text == "Block: %d" % actor.block,
		"ribbon shows one authoritative Block value: " + meter.name)
	_check(not meter.block_bar.is_visible_in_tree() and meter.block_bar.value == actor.block
		and meter.block_bar.max_value == maxi(1, maxi(actor.max_hp, actor.block)),
		"the duplicate Block bar stays exact and hidden: " + meter.name)
	var content := meter.get_node("Padding/Content")
	var status := meter.get_node_or_null("Padding/Content/StatusText") as Label
	_check(status != null and status == meter.status_text and not status.is_visible_in_tree()
		and status.text == _expected_status(actor) and status.focus_mode == Control.FOCUS_NONE
		and status.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"exact status model line is preserved but not laid out: " + meter.name)
	var modifier := meter.get_node_or_null("Padding/Content/ModifierExplanation") as Label
	_check(modifier != null and modifier == meter.modifier_explanation
		and modifier.text == _expected_rules(actor) and not modifier.is_visible_in_tree()
		and modifier.focus_mode == Control.FOCUS_NONE and modifier.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"full Weak/Exposed rules stay exact and hidden: " + meter.name)
	var warning := meter.get_node_or_null("Padding/Content/BleedWarning") as Label
	_check(warning != null and warning == meter.bleed_warning
		and warning.text == _expected_bleed(actor) and not warning.is_visible_in_tree()
		and warning.focus_mode == Control.FOCUS_NONE and warning.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"owner-turn Bleed/LETHAL text stays exact and hidden: " + meter.name)
	var line := meter.get_node_or_null("Padding/Content/IncomingForecast") as Label
	_check((line != null) == (side == "hero"), "hero-only forecast control, never on an enemy ribbon: " + meter.name)
	if line != null:
		_check(line.text == _expected_incoming(actor, forecast) and not line.is_visible_in_tree()
			and line.focus_mode == Control.FOCUS_NONE and line.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"hero forecast is populated before the hover text and hidden: " + meter.name)
	_check(content.find_children("StatusText", "Label", false, false).size() == 1
		and content.find_children("ModifierExplanation", "Label", false, false).size() == 1
		and content.find_children("BleedWarning", "Label", false, false).size() == 1
		and content.find_children("IncomingForecast", "Label", false, false).size() == (1 if side == "hero" else 0)
		and content.find_children("StatusButtons", "HBoxContainer", false, false).size() == 1,
		"one of each named snapshot child per mounted ribbon: " + meter.name)
	_check(content.get_child_count() == (10 if side == "hero" else 9),
		"a ribbon keeps exactly its preserved snapshot content: " + meter.name)
	var buttons := _buttons(meter)
	_check(buttons != null, "every ribbon owns one status button row: " + meter.name)
	if buttons == null:
		return
	var chips := _expected_chips(actor, side)
	_check(buttons.visible == not chips.is_empty()
		and buttons.is_visible_in_tree() == not chips.is_empty()
		and buttons.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and buttons.focus_mode == Control.FOCUS_NONE,
		"empty status row collapses; real statuses restore it without intercepting input: " + meter.name)
	_check(buttons.get_child_count() == 4, "one reusable four-button pool: " + meter.name)
	var expected_tooltip := _expected_tooltip(actor, side, forecast)
	var texts: Array[String] = []
	for child in buttons.get_children():
		var button := child as Button
		if button == null:
			continue
		_check(button.focus_mode == Control.FOCUS_NONE, "status chip is never a keyboard stop: " + meter.name)
		_check(button.pressed.get_connections().is_empty(), "status chip activates nothing: " + meter.name)
		if not button.visible:
			_check(button.tooltip_text.is_empty(), "hidden extra chip keeps no orphan tooltip: " + meter.name)
			continue
		texts.append(button.text)
		_check(button.is_visible_in_tree() and button.mouse_filter == Control.MOUSE_FILTER_STOP
			and button.mouse_default_cursor_shape == Control.CURSOR_HELP,
			"visible status chip is hoverable by pointer: " + meter.name)
		_check(button.tooltip_text == expected_tooltip,
			"exact combined hover text on '%s': %s" % [button.text, meter.name])
	_check(texts == chips, "status chips match the authoritative counts %s: %s" % [str(chips), meter.name])
	# Semantic slot identity only: the mounted ribbon belongs to this actor's side and
	# position, and the actor drawn in that stage slot is the same authoritative actor.
	var slot := _slot(app, side, actor.position)
	_check(slot != null and slot.is_visible_in_tree(), "the actor's own stage slot exists: " + meter.name)
	_check(meter.name == "%s%d" % [side, actor.position],
		"ribbon identity follows the actor's side and position: " + meter.name)
	if slot != null:
		var puppet := slot.get_node_or_null("%sPuppet%d" % ["Hero" if side == "hero" else "Enemy",
			actor.position])
		_check(puppet != null and puppet.actor_id == actor.get("id", ""),
			"the stage slot draws the same authoritative actor as its ribbon: " + meter.name)


## Four-chip ribbon: a fallen actor keeps all three stacks, so every chip must show its
## complete name and count inside its own rendered width instead of being clipped.
func _assert_dense_chips(meter: CombatActorMeter, actor: Dictionary, side: String,
		expected: Array[String]) -> void:
	var shown := _visible_buttons(meter)
	var texts: Array[String] = []
	_check(shown.size() == 4, "a fallen actor keeps all four status chips: " + meter.name)
	for button in shown:
		texts.append(button.text)
		_check(not button.clip_text, "dense chip never clips its label: " + button.text)
		_check(button.get_theme_font_size("font_size") >= 10,
			"dense chip keeps a legible font size: " + button.text)
		_check(button.get_minimum_size().x <= button.size.x + 0.5,
			"dense chip renders its complete label inside its own width: " + button.text)
		_check(button.size.x > 0.0 and button.size.y > 0.0,
			"dense chip has a real rendered area: " + button.text)
	_check(texts == expected, "every dense chip keeps its name and count %s: %s" % [str(expected), meter.name])
	_check(texts == _expected_chips(actor, side), "dense chips mirror the authoritative stacks: " + meter.name)
	if shown.size() == 4:
		var fallen_style := shown[0].get_theme_stylebox("normal") as StyleBoxFlat
		var stack_style := shown[1].get_theme_stylebox("normal") as StyleBoxFlat
		_check(fallen_style != null and stack_style != null
			and fallen_style.bg_color != stack_style.bg_color,
			"the fallen cue is a distinct chip, not another stack: " + meter.name)


## The player-facing stage text must come only from the hoverable chips.
func _assert_no_duplicate_rule_tooltips(app) -> void:
	var carriers := 0
	for node in app.battle_view.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.tooltip_text.contains("Statuses:"):
			continue
		carriers += 1
		_check(control is Button and control.is_visible_in_tree()
			and control.get_parent() is HBoxContainer and control.get_parent().name == "StatusButtons",
			"status rules live only on a visible chip, never a duplicate stage control")
	var expected_carriers := 0
	for meter in _meters(app):
		expected_carriers += _visible_buttons(meter).size()
	_check(carriers == expected_carriers,
		"only real mounted status chips carry tooltips, with no neutral or duplicate controls")


func _visible(app) -> void:
	var meters := _meters(app)
	var actors: Array = app.party.get_heroes() + app.enemies.get_enemies()
	_check(meters.size() == actors.size(), "exactly one real ribbon per presented actor")
	if meters.size() != actors.size():
		return
	var forecast := _forecast(app)
	var ids: Array[int] = []
	for index in range(meters.size()):
		var meter := meters[index]
		var side := "hero" if index < CombatParty.PARTY_SIZE else "enemy"
		_check(not ids.has(meter.get_instance_id()), "each actor owns a distinct ribbon")
		ids.append(meter.get_instance_id())
		_assert_ribbon(app, meters[index], actors[index], side, forecast)
	for control in [app.hero_view, app.hand_view, app.end_turn_button, app.return_button]:
		_check(control.is_visible_in_tree(), "existing battle control stays visible: %s" % control.name)
	_check(app.find_children("CombatMeters", "Control", true, false).size() == 1,
		"exactly one mounted ribbon row per battle")
	_check(app.end_turn_button.focus_next == app.end_turn_button.get_path_to(app.return_button), "existing Tab cycle")
	_assert_no_duplicate_rule_tooltips(app)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await _frames()


func _mouse(control: Control) -> void:
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
		await _frames()


func _hover(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames()


## Real pointer hover over every present ribbon's first positive or fallen chip.
func _assert_hover(app) -> void:
	for meter in _meters(app):
		var shown := _visible_buttons(meter)
		if shown.is_empty():
			_check(not _buttons(meter).visible and not _buttons(meter).is_visible_in_tree(),
				"empty mounted status row cannot capture pointer events: " + meter.name)
			continue
		await _hover(shown[0])
		_check(root.gui_get_hovered_control() == shown[0],
			"real pointer hover reaches the visible chip: " + meter.name)
		_check(shown[0].tooltip_text.contains("Statuses:"),
			"the hovered chip exposes the exact rules text: " + meter.name)


## Real mounted empty -> active -> expired status transitions on the same four controls.
func _exercise_status_row_transitions(app, presenter) -> void:
	var meters := _meters(app)
	_check(meters.size() == 5 and app.enemies.get_enemy(1)["hp"] > 3
		and app.enemies.get_enemy(1).get("statuses", {}).is_empty(),
		"status transition starts with a real healthy, stack-free mounted enemy")
	if meters.size() != 5 or app.enemies.get_enemy(1)["hp"] <= 3:
		return
	var before := _state(app)
	var original_enemies: Array[Dictionary] = app.enemies.get_enemies()
	var meter := meters[3]
	var buttons := _buttons(meter)
	var control_ids: Array[int] = []
	for child in buttons.get_children():
		control_ids.append(child.get_instance_id())
	_check(control_ids.size() == 4 and not buttons.visible and _visible_buttons(meter).is_empty(),
		"authentic opening has a collapsed status row and four dormant buttons")
	_check(app.enemies.apply_statuses({1: {"exposed": 2}}),
		"real enemy API applies Exposed 2 to an initially empty row")
	await _frames()
	_check(buttons.is_visible_in_tree() and _visible_buttons(meter).size() == 1
		and _visible_buttons(meter)[0].text == "Exposed 2",
		"first positive stack restores the same visible row")
	_check(app.enemies.apply_statuses({1: {"weak": 1, "bleed": 2}}),
		"real enemy API adds Bleed and Weak without replacing Exposed")
	await _frames()
	_visible(app)
	var actor: Dictionary = app.enemies.get_enemy(1)
	var text: Array[String] = []
	for button in _visible_buttons(meter):
		text.append(button.text)
	_check(actor["statuses"] == {"bleed": 2, "weak": 1, "exposed": 2}
		and text == ["Bleed 2", "Weak 1", "Exposed 2"],
		"mounted row follows actual Bleed, Weak, Exposed snapshots in stable order")
	if _visible_buttons(meter).size() == 3:
		await _hover(_visible_buttons(meter)[1])
		_check(root.gui_get_hovered_control() == _visible_buttons(meter)[1]
			and _visible_buttons(meter)[1].tooltip_text == _expected_tooltip(actor, "enemy", _forecast(app)),
			"live positive chip hover exposes complete ordered stacks and modifier rules")
	var refreshed := _state(app)
	seed(93031)
	var global_draw := randi()
	seed(93031)
	for repeat in range(4):
		presenter._sync_battle()
		await _frames()
		var actual_ids: Array[int] = []
		for child in buttons.get_children():
			actual_ids.append(child.get_instance_id())
		_check(actual_ids == control_ids and buttons.get_child_count() == 4
			and meter == _meters(app)[3], "status refresh reuses four original chips and mounted meter")
	_check(_state(app) == refreshed and randi() == global_draw,
		"refresh never changes deck, statuses, intents, combat or seeded/global RNG")
	var batch := CombatStatusTurnBatch.new()
	for turn in range(2):
		var tick: Dictionary = batch.tick_side("enemies", app.enemies.get_enemies())
		_check(tick["ok"] and tick["actors"].size() == 2,
			"real owner-turn status batch expires positive stacks")
		if not tick["ok"] or tick["actors"].size() != 2:
			break
		for index in range(2):
			app.enemies._enemies[index] = tick["actors"][index].duplicate(true)
		await _frames()
		_visible(app)
		actor = app.enemies.get_enemy(1)
		if turn == 0:
			_check(actor["statuses"].get("bleed", 0) == 1
				and actor["statuses"].get("weak", 0) == 0
				and actor["statuses"].get("exposed", 0) == 1
				and _visible_buttons(meter).size() == 2
				and _visible_buttons(meter)[0].text == "Bleed 1"
				and _visible_buttons(meter)[1].text == "Exposed 1",
				"first owner turn removes expired Weak, keeps positive Bleed and Exposed")
		else:
			_check(_expected_chips(actor, "enemy").is_empty()
				and _visible_buttons(meter).is_empty() and not buttons.is_visible_in_tree()
				and meter.status_text.text == "Statuses: none",
				"final expiry removes all visible chips and collapses row, retaining model text")
	var ending_ids: Array[int] = []
	for child in buttons.get_children():
		ending_ids.append(child.get_instance_id())
	_check(ending_ids == control_ids and buttons.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"expired status row is pointer inert without stale or duplicated controls")
	for index in range(original_enemies.size()):
		app.enemies._enemies[index] = original_enemies[index].duplicate(true)
	await _frames()
	_visible(app)
	_check(_state(app) == before and _visible_buttons(meter).is_empty()
		and not buttons.is_visible_in_tree(),
		"status probe restores exact original roster, deck, intents and RNG with hidden row")


func _exercise_live_bleed(app, presenter) -> void:
	# Exercise real mounted services, not a test-only presenter or mutated reader copy.
	var before := _state(app)
	var original_heroes: Array = app.party.get_heroes()
	var original_enemies: Array = app.enemies.get_enemies()
	var meters := _meters(app)
	_check(meters.size() == 5 and app.party.get_hero(1)["block"] == 6
		and app.enemies.get_enemy(1)["hp"] > 2,
		"live Bleed precondition: five authoritative living slots, six Warden Block")
	if meters.size() != 5 or app.enemies.get_enemy(1)["hp"] <= 2:
		return
	var ids: Array[int] = []
	var warning_ids: Array[int] = []
	var modifier_ids: Array[int] = []
	var button_ids: Array[Array] = []
	for meter in meters:
		ids.append(meter.get_instance_id())
		warning_ids.append(meter.bleed_warning.get_instance_id())
		modifier_ids.append(meter.modifier_explanation.get_instance_id())
		var row_ids: Array[int] = []
		for child in _buttons(meter).get_children():
			row_ids.append(child.get_instance_id())
		button_ids.append(row_ids)
	for index in range(3):
		app.party._heroes[index]["statuses"] = [
			{"bleed": 3, "weak": 1, "exposed": 2},
			{"bleed": 2, "exposed": 1},
			{"bleed": 1}][index].duplicate(true)
	_check(app.enemies.apply_damage(1, app.enemies.get_enemy(1)["hp"] - 2)
		and app.enemies.apply_statuses({
			1: {"bleed": 3, "weak": 1, "exposed": 2},
			2: {"bleed": 2, "exposed": 1}}),
		"enemy low HP and mixed-status stacks applied through real enemy APIs")
	_check(app.party.get_hero(1)["statuses"]["bleed"] == 3
		and app.enemies.get_enemy(1)["hp"] == 2
		and app.enemies.get_enemy(1)["statuses"]["bleed"] == 3,
		"actual live Warden/enemy reader snapshots contain Bleed")
	presenter._sync_battle()
	await _frames()
	_visible(app)
	_check(meters[0].modifier_explanation.text == "Weak: -25% attack damage\nExposed: +50% attack damage taken"
		and not meters[0].modifier_explanation.visible
		and meters[1].modifier_explanation.text == "Exposed: +50% attack damage taken"
		and not meters[1].modifier_explanation.visible
		and meters[2].modifier_explanation.text.is_empty() and not meters[2].modifier_explanation.visible
		and meters[3].modifier_explanation.text == meters[0].modifier_explanation.text
		and meters[4].modifier_explanation.text == meters[1].modifier_explanation.text,
		"all five live modifier texts follow their own actors while staying off the stage")
	# The enemy rules must be reachable from the mounted stage, not just stored
	# on a pointer-inert roster label: hover the actual visible status chip.
	var enemy: Dictionary = app.enemies.get_enemy(1)
	var enemy_chips := _visible_buttons(meters[3])
	var texts: Array[String] = []
	for button in enemy_chips:
		texts.append(button.text)
	_check(texts == ["Bleed 3", "Weak 1", "Exposed 2"],
		"mounted enemy ribbon lists its exact active stacks in stable order")
	if not enemy_chips.is_empty():
		var chip := enemy_chips[0]
		_check(chip.focus_mode == Control.FOCUS_NONE and chip.mouse_filter == Control.MOUSE_FILTER_STOP
			and chip.mouse_default_cursor_shape == Control.CURSOR_HELP,
			"enemy status chip accepts pointer hover while staying keyboard-inert")
		await _hover(chip)
		_check(root.gui_get_hovered_control() == chip, "real pointer hover reaches the visible enemy status chip")
		_check(chip.tooltip_text == _expected_tooltip(enemy, "enemy", _forecast(app))
			and chip.tooltip_text == "Statuses: Bleed 3 · Weak 1 · Exposed 2"
				+ "\nWeak: -25% attack damage\nExposed: +50% attack damage taken"
				+ "\nBleed next: -2 HP (bypasses Block) — LETHAL",
			"hovered enemy chip exposes the exact combined rules")
	_check(app.get_node("LiveEnemyRoster")._labels[0].mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"enemy target label stays pointer-inert so target selection is untouched")
	var before_swap := _state(app)
	var preview := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
	_check(preview["ok"] and preview["heroes"].size() == 3 and _state(app) == before_swap,
		"real adjacent living swap preview succeeds without mutation")
	if preview["ok"]:
		for index in range(3):
			app.party._heroes[index] = preview["heroes"][index].duplicate(true)
		presenter._sync_battle()
		await _frames()
		_visible(app)
		_check(app.party.get_hero(1)["id"] == "seamstress" and app.party.get_hero(2)["id"] == "warden"
			and meters[0].modifier_explanation.text == "Exposed: +50% attack damage taken"
			and meters[1].modifier_explanation.text == "Weak: -25% attack damage\nExposed: +50% attack damage taken",
			"modifier text tracks hero identity after legal adjacent position swap")
		var reverse := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
		_check(reverse["ok"], "legal reverse movement exists")
		if reverse["ok"]:
			for index in range(3):
				app.party._heroes[index] = reverse["heroes"][index].duplicate(true)
		presenter._sync_battle()
		await _frames()
		_visible(app)
		_check(_state(app) == before_swap, "reverse movement restores exact state and RNG")
	_check(meters[0].bleed_warning.text == "Bleed next: -3 HP (bypasses Block)"
		and meters[0].block_text.text == "Block: 6"
		and meters[3].bleed_warning.text == "Bleed next: -2 HP (bypasses Block) — LETHAL"
		and meters[2].bleed_warning.text == "Bleed next: -1 HP (bypasses Block)"
		and meters[4].bleed_warning.text == "Bleed next: -2 HP (bypasses Block)",
		"all five live warnings, enemy lethal clamp and unaffected starting Block")
	_check(not meters[0].bleed_warning.is_visible_in_tree() and not meters[3].bleed_warning.is_visible_in_tree(),
		"owner-turn Bleed forecast is hover-only, never a stage paragraph")
	var live_before_refresh := _state(app)
	var incoming_before := [_incoming(app, 1), _incoming(app, 2), _incoming(app, 3)]
	seed(95323)
	var expected_global := randi()
	seed(95323)
	for repeat in range(5):
		presenter._sync_battle()
		await process_frame
		for index in range(5):
			var row_ids: Array[int] = []
			for child in _buttons(meters[index]).get_children():
				row_ids.append(child.get_instance_id())
			_check(meters[index].get_instance_id() == ids[index]
				and button_ids[index] == row_ids
				and meters[index].get_node("Padding/Content").get_child_count() == (10 if index < 3 else 9),
				"read-only live refresh never allocates another chip, warning or meter")
	_check(_state(app) == live_before_refresh and randi() == expected_global
		and incoming_before == [_incoming(app, 1), _incoming(app, 2), _incoming(app, 3)],
		"repeated Bleed forecasts preserve full state, seeded/global RNG and separate incoming labels")
	await _assert_hover(app)
	# Advance the authoritative owner-side snapshots using existing pure batch rules.
	# This tests the real mounted refresh after the owner-turn boundary without
	# adding a production status persistence API or changing round-flow ownership.
	var batch := CombatStatusTurnBatch.new()
	for turn in range(3):
		var hero_turn := batch.tick_side("heroes", app.party.get_heroes())
		var enemy_turn := batch.tick_side("enemies", app.enemies.get_enemies())
		_check(hero_turn["ok"] and enemy_turn["ok"]
			and hero_turn["actors"].size() == 3 and enemy_turn["actors"].size() == 2,
			"both real actor rosters have an authoritative owner-turn tick")
		if not hero_turn["ok"] or not enemy_turn["ok"]:
			break
		for index in range(3):
			app.party._heroes[index] = hero_turn["actors"][index].duplicate(true)
		for index in range(2):
			app.enemies._enemies[index] = enemy_turn["actors"][index].duplicate(true)
		var after_owner_turn := _state(app)
		presenter._sync_battle()
		_visible(app)
		_check(_state(app) == after_owner_turn,
			"post-owner-boundary visual refresh never applies a second Bleed tick")
		for index in range(5):
			_check(meters[index].get_instance_id() == ids[index]
				and meters[index].bleed_warning.get_instance_id() == warning_ids[index]
				and meters[index].modifier_explanation.get_instance_id() == modifier_ids[index],
				"owner-turn refresh retains every persistent warning identity")
		if turn == 0:
			_check(meters[0].modifier_explanation.text == "Exposed: +50% attack damage taken"
				and not meters[1].modifier_explanation.visible
				and not meters[3].modifier_explanation.visible
				and not meters[4].modifier_explanation.visible,
				"owner tick removes Weak and expired enemy stacks, keeps living Exposed")
			_check(app.enemies.is_slain(1) and not meters[3].bleed_warning.visible
				and meters[3].bleed_warning.text.is_empty()
				and meters[0].bleed_warning.text == "Bleed next: -2 HP (bypasses Block)"
				and not meters[2].bleed_warning.visible,
				"lethal enemy Bleed hides on slain slot; Bleed one expires after boundary")
			var slain_chips: Array[String] = []
			for button in _visible_buttons(meters[3]):
				slain_chips.append(button.text)
			_check(not slain_chips.is_empty() and slain_chips[0] == "SLAIN"
				and slain_chips == _expected_chips(app.enemies.get_enemy(1), "enemy"),
				"a slain source shows a clear SLAIN chip beside its authoritative stacks")
		elif turn == 1:
			_check(not meters[0].modifier_explanation.visible and meters[0].modifier_explanation.text.is_empty(),
				"second owner tick expires Exposed explanation")
		elif turn == 2:
			for meter in meters:
				_check(not meter.modifier_explanation.visible and meter.modifier_explanation.text.is_empty(),
					"all weak and exposed descriptions are cleared after expiry")
				_check(not meter.bleed_warning.visible and meter.bleed_warning.text.is_empty(),
					"all expired Bleed stacks remove active warnings without removing labels")
	# Four-chip ribbon in the same live battle: a real slain source keeps Bleed, Weak and
	# Exposed, so every name and count must stay legible instead of being clipped.
	_check(app.enemies.apply_statuses({1: {"bleed": 3, "weak": 1, "exposed": 2}}),
		"a real slain enemy still accepts its authoritative status stacks")
	var dense: Dictionary = app.enemies.get_enemy(1)
	_check(dense["hp"] == 0 and app.enemies.is_slain(1)
		and dense["statuses"] == {"bleed": 3, "weak": 1, "exposed": 2},
		"the fallen source keeps all three stacks at zero HP")
	presenter._sync_battle()
	await _frames()
	_visible(app)
	_assert_dense_chips(meters[3], dense, "enemy", ["SLAIN", "Ble 3", "Wea 1", "Exp 2"])
	var dense_chips := _visible_buttons(meters[3])
	if dense_chips.size() == 4:
		await _hover(dense_chips[3])
		_check(root.gui_get_hovered_control() == dense_chips[3]
			and dense_chips[3].tooltip_text == _expected_tooltip(dense, "enemy", _forecast(app))
			and dense_chips[3].tooltip_text == "Statuses: Bleed 3 · Weak 1 · Exposed 2",
			"hovering the dense fallen chip exposes the full status names")
	# Restore the identical authoritative session so the existing attack/replay
	# assertions still run on the authored opening state, not synthetic combat.
	for index in range(3):
		app.party._heroes[index] = original_heroes[index].duplicate(true)
	for index in range(2):
		app.enemies._enemies[index] = original_enemies[index].duplicate(true)
	presenter._sync_battle()
	_visible(app)
	_check(_state(app) == before and incoming_before != [],
		"live status probe restores complete authored combat, intents, deck and RNG")
	for index in range(5):
		_check(meters[index].bleed_warning.text.is_empty()
			and not meters[index].bleed_warning.visible
			and meters[index].modifier_explanation.text.is_empty()
			and not meters[index].modifier_explanation.visible,
			"clearing real statuses immediately hides every old warning")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await _frames()
	var presenter = app.get_node_or_null("LiveCombatMeters")
	_check(presenter != null and is_instance_valid(app.start_button), "mounted presenter and Start Run exist")
	if presenter == null or not is_instance_valid(app.start_button):
		app.free()
		_finish()
		return
	_check(app.title_view.is_visible_in_tree() and _meters(app).is_empty(), "title has no meters")
	app.starter_party_path = "user://missing_meter_party/invalid.json"
	_fixture_start(app)
	await _frames()
	_check(app.deck == null and app.party == null and app.enemies == null and presenter.row == null,
		"failed actual Start Run creates no partial meters or rules")
	app._end_turn()
	await _frames()
	_check(_meters(app).is_empty(), "inactive End Turn has no presentation")
	app.starter_party_path = app.STARTER_PARTY_PATH
	var replay: Array = []
	for session in range(2):
		_fixture_start(app)
		await _frames()
		_check(app.deck is CombatDeck and app.party is CombatParty and app.enemies is CombatEnemies
			and app.run_rng != null and is_instance_valid(app.battle_view), "real keyboard Start Run constructs battle")
		if app.deck == null or app.party == null or app.enemies == null:
			break
		_check(app.party.get_hero(1).name == "Warden" and app.party.get_hero(1).block == 6
			and app.enemies.get_enemy(2).name == "Guard Ragling", "authored five-actor preconditions")
		# Explicit failure probes ensure missing controls/wrong values cannot pass vacuously.
		if "--inject-missing-control" in OS.get_cmdline_user_args():
			presenter.row.get_child(0).free()
			_visible(app)
			app.free()
			_finish()
			return
		if "--inject-wrong-value" in OS.get_cmdline_user_args():
			presenter.row.get_child(0).hp_bar.value = 1
			_visible(app)
			app.free()
			_finish()
			return
		_visible(app)
		await _assert_hover(app)
		await _exercise_status_row_transitions(app, presenter)
		# Inject only into an existing mounted view: no invented live status persistence.
		var model_before_status := _state(app)
		var active_meters := _meters(app)
		_check(active_meters.size() == 5, "synthetic status probes have five real mounted meters")
		if active_meters.size() == 5:
			for index in [1, 3]:
				var side := "hero" if index == 1 else "enemy"
				var snapshot: Dictionary = app.party.get_hero(2) if index == 1 else app.enemies.get_enemy(1)
				var unmodified := snapshot.duplicate(true)
				snapshot["statuses"] = {"exposed": 2, "bleed": 3, "weak": 1}
				var snapshot_before := snapshot.duplicate(true)
				var meter := active_meters[index]
				var label_id := meter.status_text.get_instance_id()
				_check(meter.show_actor(snapshot, side)
					and meter.status_text.text == "Statuses: Bleed 3 · Weak 1 · Exposed 2"
					and not meter.status_text.is_visible_in_tree()
					and not meter.actor_heading.is_visible_in_tree(),
					"mounted %s displays supplied synthetic counters without a boxed heading" % side)
				_check(snapshot == snapshot_before and not unmodified.has("statuses"),
					"synthetic %s statuses never alter source snapshot" % side)
				var displayed := meter.status_text.text
				_check(meter.show_actor(snapshot, side) and meter.status_text.text == displayed
					and meter.status_text.get_instance_id() == label_id,
					"duplicate mounted status update retains one stable label")
				var invalid := snapshot.duplicate(true)
				invalid["statuses"] = {"bleed": -1}
				_check(not meter.show_actor(invalid, side) and not meter.visible
					and meter.status_text.text.is_empty() and meter.bleed_warning.text.is_empty()
					and not meter.bleed_warning.visible and not meter.is_visible_in_tree(),
					"invalid mounted status map clears prior positive stack")
				presenter._sync_battle()
				_check(meter.visible and meter.status_text.text == "Statuses: none"
					and _visible_buttons(meter).is_empty() and not _buttons(meter).visible
					and meter.bleed_warning.text.is_empty() and not meter.bleed_warning.visible
					and meter.status_text.get_instance_id() == label_id,
					"next authoritative frame restores honest model text without a neutral widget")
			_check(_state(app) == model_before_status,
				"mounted synthetic/invalid/authoritative view refresh never mutates models or run RNG")
			_visible(app)
			await _assert_hover(app)
		_check(_incoming(app, 1) == "Incoming: 1 Block, 0 HP"
			and _incoming(app, 2) == "Incoming: none"
			and _incoming(app, 3) == "Incoming: none",
			"authored opening Warden absorbs Ragling one, Guard Block contributes zero")
		await _exercise_live_bleed(app, presenter)
		var initial := _state(app)
		if session == 0:
			replay = initial
		else:
			_check(initial == replay, "same-seed replay restores full initial state")
		var ids: Array[int] = []
		for meter in _meters(app):
			ids.append(meter.get_instance_id())
		_fixture_start(app)
		await _frames()
		for frame in range(8):
			presenter._sync_battle()
			await process_frame
		_check(_state(app) == initial and _meters(app).size() == 5, "duplicate frames/start never spend or duplicate")
		for index in range(_meters(app).size()):
			_check(_meters(app)[index].get_instance_id() == ids[index], "refresh reuses existing nodes")
		app.end_turn_button.disabled = true
		app.end_turn_button.pressed.emit()
		await _frames()
		_check(_state(app) == initial, "disabled End Turn has no state changes")
		app.end_turn_button.disabled = false
		await _mouse(app.end_turn_button)
		_check(app.party.get_hero(1).hp == 40 and app.party.get_hero(1).block == 0
			and app.enemies.get_enemy(2).block == 1, "actual turn absorbs attack and executes second enemy Block")
		_visible(app)
		_check(_incoming(app, 1) == "Incoming: none"
			and _incoming(app, 2) == "Incoming: 0 Block, 1 HP",
			"real End Turn reveals next Ragling intent at fixed Seamstress position")
		# Direct valid model changes must refresh without app refresh callbacks.
		_check(app.party.gain_block(2, 7) and app.party.apply_damage(2, 3), "valid hero Block absorption")
		_check(app.party.apply_damage(3, 999) and app.enemies.gain_block(1, 8)
			and app.enemies.apply_damage(1, 3) and app.enemies.apply_damage(2, 1), "valid HP/Block, enemy Block absorption and zero HP mutations")
		var before := _state(app)
		await _frames()
		_visible(app)
		_check(_incoming(app, 2) == "Incoming: 1 Block, 0 HP",
			"real living attacker forecasts against changed Seamstress Block")
		_check(_state(app) == before, "display refresh preserves every model, energy, piles, intents and RNG")
		_check(app.party.apply_damage(2, 999) and app.party.is_downed(2),
			"live downed target remains at position two")
		await _frames()
		_visible(app)
		_check(_incoming(app, 2) == "DOWNED" and _incoming(app, 1) == "Incoming: none"
			and _incoming(app, 3) == "DOWNED",
			"downed target is not retargeted and never has a plausible incoming line")
		var downed_chips: Array[String] = []
		for button in _visible_buttons(_meters(app)[1]):
			downed_chips.append(button.text)
		_check(downed_chips.has("DOWNED"), "a downed hero is announced clearly on its ribbon")
		# The same four-chip case on a hero ribbon: a downed hero keeps all three stacks,
		# so every name and count must stay complete and the hover must keep the rules.
		app.party._heroes[1]["statuses"] = {"bleed": 3, "weak": 1, "exposed": 2}
		await _frames()
		_visible(app)
		var downed: Dictionary = app.party.get_hero(2)
		_assert_dense_chips(_meters(app)[1], downed, "hero", ["DOWNED", "Ble 3", "Wea 1", "Exp 2"])
		var downed_dense := _visible_buttons(_meters(app)[1])
		if downed_dense.size() == 4:
			await _hover(downed_dense[2])
			_check(root.gui_get_hovered_control() == downed_dense[2]
				and downed_dense[2].tooltip_text == _expected_tooltip(downed, "hero", _forecast(app)),
				"a downed hero's dense chip keeps the full-name rules on hover")
		app.party._heroes[1].erase("statuses")
		await _frames()
		_check(app.enemies.apply_damage(1, 999) and app.enemies.is_slain(1),
			"real Ragling source is slain in retained position one")
		before = _state(app)
		await _frames()
		_visible(app)
		_check(_incoming(app, 1) == "Incoming: none" and _incoming(app, 2) == "DOWNED"
			and _incoming(app, 3) == "DOWNED",
			"slain attacker removes forecasts on surviving hero slots")
		_check(_state(app) == before, "slain-attacker refresh is entirely read-only")
		var valid_intents = app.enemy_intents
		app.enemy_intents = null
		presenter._sync_battle()
		_check(_incoming(app, 1) == "Incoming: unavailable"
			and _incoming(app, 3) == "DOWNED"
			and _incoming(app, 2) == "DOWNED",
			"missing intent interface fails closed without believable hero damage")
		_visible(app)
		_check(_incoming(app, 1) == "Incoming: unavailable"
			and _meters(app)[0].status_text.text == "Statuses: none"
			and _visible_buttons(_meters(app)[0]).is_empty()
			and not _buttons(_meters(app)[0]).visible,
			"missing intent remains authoritative without inventing a neutral hover chip")
		app.enemy_intents = valid_intents
		presenter._sync_battle()
		# Each source identity change tears down the old presentation, even with identical values.
		for source in ["party", "enemies", "deck"]:
			var old_ids: Array[int] = []
			for meter in _meters(app):
				old_ids.append(meter.get_instance_id())
			if source == "party":
				app.party = CombatParty.new(app._load_party_definitions())
			elif source == "enemies":
				app.enemies = CombatEnemies.new(app._load_enemy_definitions())
			else:
				app.deck = CombatDeck.new(["warden_brace"], app.run_rng)
				app.deck.start_turn()
			await _frames()
			_visible(app)
			for id in old_ids:
				_check(not is_instance_id_valid(id), "source replacement frees stale meters: " + source)
		# Invalid/inactive sources clear synchronously; restoring a valid source rebuilds once.
		for source in ["party", "enemies", "deck", "hidden"]:
			var before_rejection := _state(app)
			var party: CombatParty = app.party
			var enemies: CombatEnemies = app.enemies
			var deck: CombatDeck = app.deck
			if source == "party":
				app.party = CombatParty.new([])
			elif source == "enemies":
				app.enemies = CombatEnemies.new([])
			elif source == "deck":
				app.deck = null
			else:
				app.battle_view.hide()
			presenter._sync_battle()
			_check(presenter.row == null and _meters(app).is_empty(), "invalid/inactive source clears meters: " + source)
			app.party = party
			app.enemies = enemies
			app.deck = deck
			app.battle_view.show()
			await _frames()
			_visible(app)
			_check(_state(app) == before_rejection, "rejection/rebuild leaves surviving models unchanged")
		var final_ids: Array[int] = []
		for meter in _meters(app):
			final_ids.append(meter.get_instance_id())
		await _mouse(app.return_button)
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus()
			and presenter.row == null and _meters(app).is_empty(), "real Return clears presentation and restores focus")
		for id in final_ids:
			_check(not is_instance_id_valid(id), "Return frees old meter")
	await _status_end_turns(app, presenter)
	await _three_enemy_stage(app, presenter)
	app.free()
	await _frames()
	_finish()


func _status_end_turns(app, presenter) -> void:
	for scenario in ["weak", "exposed2", "exposed1", "combined", "bleed_slot", "lethal_bleed"]:
		var replay: Array = []
		for session in range(2):
			_fixture_start(app)
			await _frames()
			_check(app.party != null and app.round_flow != null and app.deck.turn_active
				and _meters(app).size() == 5, scenario + ": actual Start mounts authoritative active fight")
			if app.party == null or app.round_flow == null:
				return
			if scenario in ["weak", "combined"]:
				app.enemies._enemies[0]["statuses"] = {"weak": 1}
			if scenario in ["exposed2", "combined"]:
				app.party._heroes[0]["statuses"] = {"exposed": 2, "bleed": 2}
			if scenario == "exposed1":
				app.party._heroes[0]["statuses"] = {"exposed": 1}
			if scenario in ["bleed_slot", "lethal_bleed"]:
				for index in range(3 if scenario == "lethal_bleed" else 1):
					app.party._heroes[index]["hp"] = 2
					app.party._heroes[index]["statuses"] = {"bleed": 3}
			var before := _state(app)
			var heroes: Array = app.party.get_heroes()
			var prediction := CombatIncomingAttackPreview.new().forecast(heroes,
				app.enemies.get_enemies(), app.enemy_intents.get_intents())
			_check(prediction["ok"], scenario + ": live forecast valid")
			seed(49099)
			var expected_global := randi()
			seed(49099)
			for refresh in range(4):
				presenter._sync_battle()
				await _frames()
			_check(_state(app) == before and randi() == expected_global, scenario + ": live refresh preserves all state and both RNGs")
			_visible(app)
			if not prediction["ok"]:
				return
			for index in range(3):
				var predicted: Dictionary = prediction["heroes"][index]
				_check(_incoming(app, index + 1) == ("Incoming: none" if predicted["incoming"] == 0 else
					"Incoming: %d Block, %d HP" % [predicted["block_absorbed"], predicted["hp_lost"]]), scenario + ": mounted forecast oracle")
			if scenario == "lethal_bleed":
				var lethal_chips: Array[String] = []
				for button in _visible_buttons(_meters(app)[0]):
					lethal_chips.append(button.text)
				_check(lethal_chips == ["Bleed 3"] and _expected_bleed(heroes[0]).ends_with("— LETHAL")
					and _visible_buttons(_meters(app)[0])[0].tooltip_text.contains("— LETHAL"),
					scenario + ": lethal owner-turn Bleed is announced by the chip hover")
			if session == 0:
				await _mouse(app.end_turn_button)
			else:
				app.end_turn_button.grab_focus()
				await _key(KEY_SPACE)
			_check(not app.deck.turn_active if scenario == "lethal_bleed" else app.enemy_intents._turn_index == 1,
				scenario + ": actual mouse/keyboard End Turn processed")
			for index in range(3):
				var predicted: Dictionary = prediction["heroes"][index]
				var actual: Dictionary = app.party.get_hero(index + 1)
				var bleed_loss: int = mini(heroes[index]["hp"], heroes[index].get("statuses", {}).get("bleed", 0))
				_check(actual["hp"] == predicted["hp_remaining"]
					and heroes[index]["hp"] - actual["hp"] == predicted["hp_lost"] + bleed_loss,
					scenario + ": live committed HP equals attack plus separate Bleed")
				_check(actual["block"] == (predicted["block_remaining"] if scenario == "lethal_bleed" else 0)
					and predicted["block_remaining"] == heroes[index]["block"] - predicted["block_absorbed"],
					scenario + ": live Block matches absorption and new-turn reset")
			_check(app.enemies.get_enemy(2)["block"] == (0 if scenario == "lethal_bleed" else 1),
				scenario + ": owner defeat skips enemy Block as well as attacks")
			await _frames()
			_visible(app)
			var after := _state(app)
			if session == 0:
				replay = after
			else:
				_check(after == replay, scenario + ": same-seed mouse/keyboard replay full state")
			await _mouse(app.return_button)
			_check(app.title_view.is_visible_in_tree() and presenter.row == null, scenario + ": actual Return clears session")


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


## Seeded three-enemy stage: the same ribbons must follow all six live actor slots.
func _three_enemy_stage(app, presenter) -> void:
	var fixture := _three_enemy_fixture()
	_check(not fixture.is_empty(), "seeded Fight rotation supplies an authentic three-enemy roster")
	if fixture.is_empty():
		return
	app.run_seed = fixture.seed
	app.start_button.pressed.emit()
	await _frames()
	var route_button: Button = null
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == fixture.fight:
			route_button = candidate
			break
	_check(route_button != null and not route_button.disabled, "three-enemy Fight has a real enabled route control")
	if route_button == null:
		return
	route_button.pressed.emit()
	await _frames()
	await _frames()
	_check(app.enemies != null and app.enemies.get_enemies().size() == 3,
		"seeded production Fight exercises three typed enemies, not the standalone fixture")
	if app.enemies == null or app.enemies.get_enemies().size() != 3:
		return
	_check(_meters(app).size() == 6, "three-enemy stage mounts one ribbon per actor")
	var before := _state(app)
	_visible(app)
	await _assert_hover(app)
	_check(_state(app) == before, "three-enemy ribbon layout and hover are entirely read-only")
	_check(app.enemies.apply_statuses({1: {"bleed": 2}, 2: {"weak": 1, "exposed": 2},
		3: {"bleed": 1}}), "real enemy API applies mixed statuses to the three sources")
	_check(app.party.gain_block(2, 4), "real hero API raises Seamstress Block")
	await _frames()
	_visible(app)
	var third: Dictionary = app.enemies.get_enemy(3)
	var third_chips: Array[String] = []
	for button in _visible_buttons(_meters(app)[5]):
		third_chips.append(button.text)
	_check(third_chips == ["Bleed 1"] and _visible_buttons(_meters(app)[5])[0].tooltip_text
		== _expected_tooltip(third, "enemy", _forecast(app)),
		"third enemy ribbon follows its own source slot and exact hover text")
	var block_chips: Array[String] = []
	for button in _visible_buttons(_meters(app)[1]):
		block_chips.append(button.text)
	_check(block_chips.is_empty() and not _buttons(_meters(app)[1]).is_visible_in_tree()
		and _meters(app)[1].block_text.text == "Block: %d" % app.party.get_hero(2)["block"],
		"Block stays visible while a living hero's empty status row collapses")
	# Dense four-chip case in the authentic three-enemy fight: slay a fully stacked
	# source through the real enemy API and keep every name and count on its ribbon.
	_check(app.enemies.apply_statuses({2: {"bleed": 3}}),
		"real enemy API adds Bleed to the already stacked three-enemy source")
	var stacked: Dictionary = app.enemies.get_enemy(2)
	_check(app.enemies.apply_damage(2, stacked["hp"] + stacked["block"]),
		"real lethal damage slays the stacked three-enemy source")
	await _frames()
	_visible(app)
	var fallen: Dictionary = app.enemies.get_enemy(2)
	_check(fallen["hp"] == 0 and fallen["statuses"] == {"bleed": 3, "weak": 1, "exposed": 2},
		"the slain three-enemy slot keeps all three stacks")
	_assert_dense_chips(_meters(app)[4], fallen, "enemy", ["SLAIN", "Ble 3", "Wea 1", "Exp 2"])
	var fallen_chips := _visible_buttons(_meters(app)[4])
	if fallen_chips.size() == 4:
		await _hover(fallen_chips[1])
		_check(root.gui_get_hovered_control() == fallen_chips[1]
			and fallen_chips[1].tooltip_text == _expected_tooltip(fallen, "enemy", _forecast(app)),
			"the dense three-enemy chip still exposes its exact full-name hover text")
	await _mouse(app.end_turn_button)
	await _frames()
	_visible(app)
	_check(app.enemies.get_enemies().size() == 3 and _meters(app).size() == 6,
		"real End Turn keeps one ribbon per surviving source slot")
	await _mouse(app.return_button)
	await _frames()
	_check(app.title_view.is_visible_in_tree() and presenter.row == null and _meters(app).is_empty(),
		"typed three-enemy Return clears the whole ribbon row")


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_combat_meters_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
