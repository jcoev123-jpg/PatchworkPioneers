extends SceneTree

var failures: Array[String] = []
var checks := 0
## Four chips must share one narrow ribbon row, so a fallen actor with all three
## stacks gets compact-but-complete names; the tooltip keeps the full ones.
const STATUS_SHORT := {"bleed": "Ble", "weak": "Wea", "exposed": "Exp"}
## The committed Block icon the mounted ribbons must display beside a positive amount.
const BLOCK_ART := "res://assets/paper/ui/hud_block.png"
## Independent literal expectations for the eight authored M05 HEAD/ARM rules.
## These fourth tooltip lines are written from data/patches/m05_*.json and the
## rule scripts, never produced by the presenter under test, so a wrong amount,
## effect kind, recipient scope or condition cannot pass by agreeing with it.
const M05_EXPECTED_POWERS := {
	"bloodstitch_bonnet": "Authored patch rule: card_bleed_bonus +1 to positive Bleed on cards owned by this living wearer.",
	"button_glass_visor": "Authored patch rule: card_exposed_bonus +1 to positive Exposed on this wearer's cards.",
	"stern_seam_cap": "Authored patch rule: card_weak_bonus +1 to positive Weak on this wearer's cards.",
	"reinforced_browband": "Authored patch rule: card_block_bonus +2 to positive Block on this wearer's cards, applied to the card's actual Block recipient (even if it is an ally).",
	"hemguard_cuff": "Authored patch rule: card_block_bonus +2 to positive Block on this wearer's cards.",
	"red_bobbin_cuff": "Authored patch rule: card_bleed_bonus +1 to positive Bleed on this wearer's cards; not Hemorrhage Hem's multiplier.",
	"loose_thread_glove": "Authored patch rule: card_unravel_bonus +1 to positive Unravel on this wearer's cards.",
	"frayfinder_mitt": "Authored patch rule: +2 Unravel ONLY on this living wearer's first single-target attack hit, if that enemy's gauge is already at least 1/2 of its current threshold; once per PLAYER turn. Normal/elite/boss base thresholds 8/12/16, grow +4 per break. Not any area/multi-hit/later hit.",
}
## Catalog facts each literal line restates: slot, authored effect key, amount and
## the positive status it may boost. The seven card bonuses are wearer-owned and
## positive-only; Frayfinder is the conditional first-hit Unravel bonus.
const M05_EXPECTED_FACTS := {
	"bloodstitch_bonnet": {"slot": "HEAD", "effect": "card_bleed_bonus", "amount": 1, "status": "Bleed"},
	"button_glass_visor": {"slot": "HEAD", "effect": "card_exposed_bonus", "amount": 1, "status": "Exposed"},
	"stern_seam_cap": {"slot": "HEAD", "effect": "card_weak_bonus", "amount": 1, "status": "Weak"},
	"reinforced_browband": {"slot": "HEAD", "effect": "card_block_bonus", "amount": 2, "status": "Block"},
	"hemguard_cuff": {"slot": "ARM", "effect": "card_block_bonus", "amount": 2, "status": "Block"},
	"red_bobbin_cuff": {"slot": "ARM", "effect": "card_bleed_bonus", "amount": 1, "status": "Bleed"},
	"loose_thread_glove": {"slot": "ARM", "effect": "card_unravel_bonus", "amount": 1, "status": "Unravel"},
	"frayfinder_mitt": {"slot": "ARM", "effect": "first_single_target_half_unravel_attack_bonus", "amount": 2, "status": "Unravel"},
}


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
			app.party.get_heroes(), app.enemies.get_enemies(), app.enemy_intents.get_intents(),
			app.enemy_intents.is_bound())
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


## The actual enemy service owns every readout; hero ribbons and fail-closed
## states must have neither a visible fraction nor an orphan tooltip.
func _assert_thread(app, meter: CombatActorMeter, actor: Dictionary, side: String) -> void:
	var content := meter.get_node("Padding/Content") as VBoxContainer
	var thread := content.get_node_or_null("UnravelThread") as ProgressBar
	if side == "hero":
		_check(thread == null, "no Unravel bar or alternate tracker appears on heroes")
		return
	_check(thread != null and content.find_children("UnravelThread", "ProgressBar", false, false).size() == 1,
		"one reusable enemy Unravel bar exists in the original position: " + meter.name)
	if thread == null:
		return
	var number := thread.get_node_or_null("ThreadFraction") as Label
	var hover := thread.get_node_or_null("ThreadHover") as Button
	_check(number != null and thread.get_index() == meter.hp_bar.get_index() + 1
		and thread.custom_minimum_size.y <= 18 and thread.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and thread.focus_mode == Control.FOCUS_NONE and thread.show_percentage == false
		and thread.get_node_or_null("ThreadStitch") != null and hover != null
		and hover.mouse_filter == Control.MOUSE_FILTER_STOP and hover.focus_mode == Control.FOCUS_NONE
		and hover.pressed.get_connections().is_empty()
		and number.mouse_filter == Control.MOUSE_FILTER_IGNORE and number.focus_mode == Control.FOCUS_NONE,
		"thin stitched input-inert fraction immediately follows HP in the real enemy ribbon")
	var service: CombatUnravel = app.round_flow._unravel if app.round_flow != null else null
	var authorized: bool = service != null and is_instance_valid(service) \
		and app.round_flow._deck == app.deck and app.round_flow._party == app.party \
		and app.round_flow._enemies == app.enemies and app.round_flow._intents == app.enemy_intents \
		and app.round_flow._result == app.battle_result \
		and service._bound_enemies == app.enemies and not app._battle_closed
	var snapshot: Dictionary = service.get_snapshot(actor.position) if authorized else {}
	if actor.hp <= 0 or snapshot.is_empty():
		_check(not thread.visible and number.text.is_empty() and thread.tooltip_text.is_empty()
			and thread.value == 0 and thread.max_value == 1,
			"slain, unbound or foreign-roster slot clears fill, fraction and hover text")
	else:
		_check(thread.visible and thread.is_visible_in_tree()
			and thread.value == snapshot["gauge"] and thread.max_value == snapshot["threshold"]
			and number.text == "%d/%d" % [snapshot["gauge"], snapshot["threshold"]]
			and thread.tooltip_text.contains(number.text)
			and hover.tooltip_text == thread.tooltip_text
			and thread.tooltip_text.contains("UNRAVELLED") == snapshot["skip_pending"],
			"source snapshot exactly matches visible enemy fill, fraction and truthful hover")
		_check(meter.name == "enemy%d" % actor.position,
			"Unravel bar remains keyed to original roster position")


## One ribbon must show exactly its actor's authoritative values and hover rules.
func _assert_ribbon(app, meter: CombatActorMeter, actor: Dictionary, side: String, forecast: Dictionary) -> void:
	var heading := "%d. %s" % [actor.position, actor.name]
	if actor.hp == 0:
		heading += " — DOWNED" if side == "hero" else " — SLAIN"
	_check(meter.actor_heading.text == heading and not meter.actor_heading.is_visible_in_tree(),
		"exact actor heading is retained but kept off the ribbon: " + meter.name)
	_check(meter.is_visible_in_tree() and meter.hp_text.is_visible_in_tree()
		and meter.hp_text.text == "%d/%d" % [actor.hp, actor.max_hp]
		and meter.hp_text.get_parent() == meter.hp_bar,
		"ribbon shows the authoritative HP numbers inside the bar: " + meter.name)
	_check(meter.hp_bar.is_visible_in_tree() and meter.hp_bar.value == actor.hp
		and meter.hp_bar.max_value == actor.max_hp, "ribbon HP bar matches the model: " + meter.name)
	_check(meter.hp_text.size == meter.hp_bar.size
		and Rect2(Vector2.ZERO, meter.hp_bar.size).encloses(
			Rect2(meter.hp_text.position, meter.hp_text.size))
		and meter.hp_bar.size.y >= meter.hp_text.get_combined_minimum_size().y
		and meter.hp_bar.custom_minimum_size.y >= meter.hp_text.get_combined_minimum_size().y
		and meter.hp_text.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and meter.hp_text.vertical_alignment == VERTICAL_ALIGNMENT_CENTER
		and meter.hp_text.get_theme_font_size("font_size") >= 12
		and meter.hp_text.get_theme_constant("outline_size") > 0,
		"ribbon HP numbers stay centred and wholly inside their tall enough bar: " + meter.name)
	_check(meter.block_badge.visible == (actor.block > 0)
		and meter.block_text.text == ("%d" % actor.block if actor.block > 0 else "")
		and meter.block_shield.custom_minimum_size == CombatActorMeter.BlockShield.GLYPH_SIZE
		and meter.block_shield.get_combined_minimum_size().x >= 24.0
		and meter.block_shield.get_combined_minimum_size().y >= 28.0
		and (actor.block == 0 or (meter.block_text.is_visible_in_tree()
			and meter.block_shield.is_visible_in_tree())),
		"ribbon shows one authoritative doubled Block shield and count: " + meter.name)
	_assert_block_icon(meter, actor)
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
		and content.find_children("StatusButtons", "HBoxContainer", false, false).size() == 1
		and content.find_children("PatchButtons", "HBoxContainer", false, false).size() == (1 if side == "hero" else 0),
		"one of each named snapshot child per mounted ribbon: " + meter.name)
	_check(content.find_children("HPText", "Label", false, false).is_empty()
		and content.find_children("BlockBadge", "HBoxContainer", false, false).size() == 1
		and meter.hp_text.get_parent() == meter.hp_bar,
		"the ribbon has one bar-borne HP number and one Block badge, never a second HP row: " + meter.name)
	_check(content.get_child_count() == (10 if side == "hero" else 9),
		"only enemy ribbons gain exactly one UnravelThread directly below HP: " + meter.name)
	_assert_thread(app, meter, actor, side)
	var patches := meter.get_node_or_null("Padding/Content/PatchButtons") as HBoxContainer
	if side == "hero":
		_check(patches != null and patches.get_child_count() == 3
			and not patches.is_visible_in_tree() and not patches.visible
			and patches.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and patches.focus_mode == Control.FOCUS_NONE,
			"unpatched standalone hero has one collapsed non-intercepting patch row")
		if patches != null:
			for child in patches.get_children():
				var chip := child as Button
				_check(chip != null and not chip.visible and chip.text.is_empty()
					and chip.tooltip_text.is_empty() and chip.focus_mode == Control.FOCUS_NONE
					and chip.pressed.get_connections().is_empty(),
					"unpatched hero keeps no fictional sewn tooltip or action")
	else:
		_check(patches == null, "enemy never owns a patch row")
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


## The authored Block icon lives inside the meter's own sewn glyph: present only while the
## model amount is positive, pointer/keyboard inert, and never part of the amount or layout.
func _assert_block_icon(meter: CombatActorMeter, actor: Dictionary) -> void:
	var icon := meter.block_shield.get_node_or_null("BlockIcon") as TextureRect
	_check(icon != null and icon.get_parent() == meter.block_shield
		and meter.block_shield.find_children("BlockIcon", "TextureRect", false, false).size() == 1,
		"the Block badge owns exactly one authored icon slot: " + meter.name)
	if icon == null:
		return
	_check(icon.texture is Texture2D and icon.texture.resource_path == BLOCK_ART,
		"the mounted badge carries the committed Block art: " + meter.name)
	var positive: bool = actor.block > 0
	_check(icon.visible == positive and icon.is_visible_in_tree() == positive,
		"the authored Block icon appears only while protection is positive: " + meter.name)
	_check(icon.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and icon.focus_mode == Control.FOCUS_NONE
		and icon.gui_input.get_connections().is_empty()
		and icon.get_child_count() == 0 and icon.tooltip_text.is_empty(),
		"authored Block icon takes no pointer, keyboard or tooltip: " + meter.name)
	_check(Rect2(Vector2.ZERO, meter.block_shield.size).grow(0.5).encloses(
		Rect2(icon.position, icon.size)),
		"authored Block icon stays inside the existing badge slot: " + meter.name)
	_check(meter.block_text.text == ("%d" % actor.block if positive else ""),
		"authored icon never stands in for the exact Block amount: " + meter.name)


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
		and meters[0].block_text.text == "6" and meters[0].block_badge.visible
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
		_check(_incoming(app, 1) == "Incoming: 0 Block, 1 HP"
			and _incoming(app, 2) == "Incoming: none",
			"real End Turn reveals the next front-target Ragling intent on the Warden ribbon")
		# Direct valid model changes must refresh without app refresh callbacks.
		_check(app.party.gain_block(1, 7) and app.party.apply_damage(1, 3), "valid hero Block absorption")
		_check(app.party.apply_damage(3, 999) and app.enemies.gain_block(1, 8)
			and app.enemies.apply_damage(1, 3) and app.enemies.apply_damage(2, 1), "valid HP/Block, enemy Block absorption and zero HP mutations")
		var before := _state(app)
		await _frames()
		_visible(app)
		_check(_incoming(app, 1) == "Incoming: 1 Block, 0 HP"
			and _incoming(app, 2) == "Incoming: none",
			"real living attacker forecasts against changed Warden Block")
		_check(_state(app) == before, "display refresh preserves every model, energy, piles, intents and RNG")
		_check(app.party.apply_damage(2, 999) and app.party.is_downed(2),
			"live downed target remains at position two")
		await _frames()
		_visible(app)
		_check(_incoming(app, 2) == "DOWNED" and _incoming(app, 1) == "Incoming: 1 Block, 0 HP"
			and _incoming(app, 3) == "DOWNED",
			"downed heroes never show a plausible incoming line while the living target keeps its forecast")
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
	await _unravel_bound_fight(app, presenter)
	await _status_end_turns(app, presenter)
	await _three_enemy_stage(app, presenter)
	await _block_art_case(app, presenter)
	await _worn_coat_ribbons_test(app, presenter)
	await _m05_patch_ribbons_test(app, presenter)
	app.free()
	await _frames()
	_finish()


## One real mounted fight with a genuine original-position roster binding. Cards
## are admitted by the existing authored rule resolver from the actual CombatDeck;
## the separately owned live hand-target adapter is exercised by its own suite.
func _unravel_bound_fight(app, presenter) -> void:
	_fixture_start(app)
	await _frames()
	_check(app.round_flow != null and app.round_flow._started and app.deck.turn_active
		and app.enemies.get_enemies().size() == 2 and app.party.get_hero(2).id == "seamstress",
		"real started battle, living Seamstress and two real source slots precede Unravel")
	if app.round_flow == null or app.enemies == null:
		return
	var authority := CombatUnravel.new()
	_check(authority.bind_roster(app.enemies, {1: "normal", 2: "normal"}),
		"real starter-normal roster is bound to one authoritative Unravel service")
	app.round_flow._unravel = authority
	var before := _state(app)
	presenter._sync_battle()
	_visible(app)
	_check(_state(app) == before and authority.get_snapshot(1).gauge == 0
		and authority.get_snapshot(1).threshold == 8,
		"starting 0/8 is read-only and derives from the real roster")
	var meters := _meters(app)
	_check(meters.size() == 5, "real bound fight mounts all five original actor slots")
	if meters.size() != 5:
		app.return_button.pressed.emit()
		return
	var thread := meters[3].get_node("Padding/Content/UnravelThread") as ProgressBar
	var thread_id := thread.get_instance_id()
	await _frames()
	var hover := thread.get_node("ThreadHover") as Button
	await _hover(hover)
	_check(root.gui_get_hovered_control() == hover and hover.tooltip_text.contains("0/8"),
		"pointer can read the thin live thread tooltip without a focusable/clicking control")
	_check(not thread.get_global_rect().intersects(app.hand_view.get_global_rect())
		and not thread.get_global_rect().intersects(app.end_turn_button.get_global_rect())
		and not thread.get_global_rect().intersects(app.return_button.get_global_rect())
		and not thread.get_global_rect().intersects(meters[3].hp_bar.get_global_rect()),
		"visible bound thread remains separate from HP, hand, energy and battle buttons")
	var intents_before: Array = app.enemy_intents.get_intents()
	var rng_before: int = app.deck._rng.state
	for card_id in ["seamstress_snag", "seamstress_unpick"]:
		_check(SeamstressPoolCards.new().has_card(card_id), "authoritative Snag/Unpick catalog entry exists")
		app.deck.draw_pile.append(card_id)
		_check(app.deck.draw_extra(1) == 1 and app.deck.hand.has(card_id),
			"authored control card drawn into genuine shared combat hand: " + card_id)
		app._refresh_hand()
		var previous := authority.get_snapshot(1)
		var receipt: Dictionary = CombatSeamstressPoolControl.new().play_card(
			app.deck, app.party, app.enemies, null, authority, card_id, 1)
		_check(receipt.get("ok", false) and receipt.get("unravel_applied", -1) == (3 if card_id == "seamstress_snag" else 5)
			and app.deck.discard_pile.has(card_id), "genuine hand transaction commits authored control: " + card_id)
		presenter._sync_battle()
		var expected: Dictionary = authority.get_snapshot(1)
		_check(expected["gauge"] == (3 if card_id == "seamstress_snag" else 8)
			and thread.value == expected["gauge"] and thread.max_value == expected["threshold"]
			and (thread.get_node("ThreadFraction") as Label).text == "%d/%d" % [expected.gauge, expected.threshold],
			"visible 3/8 then 8/8 follows each committed shared-hand rule receipt")
		_check(app.enemy_intents.get_intents() == intents_before and app.deck._rng.state == rng_before,
			"Snag/Unpick presentation does not advance scheduler or injected RNG")
		_check(expected.gauge >= previous.gauge, "authoritative gauge increased only on paid play")
	var roster = app.get_node("LiveEnemyRoster")
	roster._refresh()
	_check(authority.get_snapshot(1).skip_pending and roster._badges[0].readable_text == "UNRAVELLED"
		and roster._badges[0].icon_mode == "unravelled" and roster._badges[0].amount == 0
		and roster._badges[0].target_position == 0 and roster._badges[1].icon_mode == "block",
		"pending skip replaces only the first original-position announcement")
	_check(app.enemy_intents.get_intents() == intents_before, "badge never mutates authored intents")
	var state_before_refresh := _state(app)
	for iteration in range(5):
		presenter._sync_battle()
		roster._refresh()
	_check(_state(app) == state_before_refresh and thread.get_instance_id() == thread_id
		and meters[3].get_node("Padding/Content").find_children("UnravelThread", "ProgressBar", false, false).size() == 1,
		"repeated mounted refresh preserves receipt/state/RNG and reuses one thread")
	var hero_before: Dictionary = app.party.get_hero(1)
	app.end_turn_button.pressed.emit()
	await _frames()
	presenter._sync_battle()
	roster._refresh()
	var skipped: Dictionary = authority.get_snapshot(1)
	_check(skipped.gauge == 0 and skipped.threshold == 12 and not skipped.skip_pending
		and app.enemy_intents._turn_index == 1 and app.enemies.get_enemy(2).block == 1,
		"actual End Turn consumes one skip, raises threshold to 12, other enemy still acts")
	_check(app.party.get_hero(1).hp == hero_before.hp and app.enemy_intents._turn_index == 1
		and not app.enemy_intents.get_intents().is_empty(),
		"the skipped original attack causes no HP loss while the scheduler legitimately advances")
	_check(thread.value == 0 and thread.max_value == 12 and (thread.get_node("ThreadFraction") as Label).text == "0/12"
		and roster._badges[0].icon_mode == "attack" and roster._badges[0].readable_text.begins_with("ATK "),
		"after real skipped action gauge resets and next scheduler action resumes")
	_check(app.enemies.apply_statuses({1: {"bleed": 1}}), "surviving enemy gains real Bleed before owner tick")
	var before_bleed: Dictionary = authority.get_snapshot(1)
	var enemy_before: Dictionary = app.enemies.get_enemy(1)
	app.end_turn_button.pressed.emit()
	await _frames()
	presenter._sync_battle()
	_check(not app.enemies.is_slain(1) and app.enemies.get_enemy(1).hp == enemy_before.hp - 1
		and authority.get_snapshot(1).gauge == before_bleed.gauge + 1 and thread.value == 1
		and (thread.get_node("ThreadFraction") as Label).text == "1/12",
		"positive enemy owner Bleed tick adds exactly one visible Unravel thread")
	# Upgraded variants use the same real deck admission and a separate living
	# original source, without borrowing the first enemy's post-skip threshold.
	var other_thread := meters[4].get_node("Padding/Content/UnravelThread") as ProgressBar
	_check(authority.get_snapshot(2).gauge == 0 and authority.get_snapshot(2).threshold == 8,
		"second real normal enemy begins with its independent 0/8 gauge")
	var before_plus_rng: int = app.deck._rng.state
	for upgraded in ["seamstress_snag_plus", "seamstress_unpick_plus"]:
		app.deck.draw_pile.append(upgraded)
		_check(app.deck.draw_extra(1) == 1 and app.deck.hand.has(upgraded),
			"genuine shared hand draws upgraded catalog control: " + upgraded)
		app._refresh_hand()
		var plus_receipt: Dictionary = CombatSeamstressPoolControl.new().play_card(
			app.deck, app.party, app.enemies, null, authority, upgraded, 2)
		_check(plus_receipt.get("ok", false) and plus_receipt.get("unravel_applied", -1)
			== (4 if upgraded == "seamstress_snag_plus" else 7),
			"upgraded charged value comes from published Seamstress card effects")
		presenter._sync_battle()
		var plus_snapshot: Dictionary = authority.get_snapshot(2)
		_check(plus_snapshot.gauge == (4 if upgraded == "seamstress_snag_plus" else 8)
			and other_thread.value == plus_snapshot.gauge
			and other_thread.max_value == 8
			and (other_thread.get_node("ThreadFraction") as Label).text == "%d/8" % plus_snapshot.gauge,
			"Snag+ 4/8 and Unpick+ capped 8/8 both reach their real source gauge")
	_check(app.deck._rng.state == before_plus_rng and authority.get_snapshot(2).skip_pending,
		"upgraded charges spend no injected RNG and arm exactly one second-source skip")
	roster._refresh()
	_check(roster._badges[1].readable_text == "UNRAVELLED"
		and roster._badges[0].icon_mode == "attack" and app.enemy_intents.get_intents()[1].type == "block",
		"only the upgraded target's scheduled Block is visually suppressed, not rewritten")
	app.end_turn_button.pressed.emit()
	await _frames()
	presenter._sync_battle()
	roster._refresh()
	_check(authority.get_snapshot(2).gauge == 0 and authority.get_snapshot(2).threshold == 12
		and roster._badges[1].icon_mode == "block" and other_thread.max_value == 12,
		"actual next phase skips upgraded target once, resets it to 0/12 and restores Block cue")
	# Wrong-bound and missing authority are non-mutations and wipe old hover text.
	var foreign := CombatUnravel.new()
	var other_enemies := CombatEnemies.new(app.enemies.get_enemies())
	_check(foreign.bind_roster(other_enemies, {1: "elite", 2: "boss"}),
		"independent enemy object can never impersonate the mounted roster")
	var source_state := _state(app)
	app.round_flow._unravel = foreign
	presenter._sync_battle()
	_check(not thread.visible and thread.tooltip_text.is_empty()
		and (thread.get_node("ThreadFraction") as Label).text.is_empty(),
		"roster-mismatched elite/boss service is hidden, never guessed from actor names")
	app.round_flow._unravel = null
	presenter._sync_battle()
	_check(not thread.visible and thread.value == 0 and thread.max_value == 1
		and _state(app) == source_state, "null service hides all old thread numbers without altering battle")
	app.round_flow._unravel = authority
	_check(app.enemies.apply_damage(1, 999) and app.enemies.is_slain(1),
		"real enemy death retains an original slain slot")
	presenter._sync_battle()
	_check(not thread.visible and thread.tooltip_text.is_empty()
		and (thread.get_node("ThreadFraction") as Label).text.is_empty(),
		"slain original slot leaves no stale gauge or tooltip")
	var old_thread_id := thread.get_instance_id()
	app.return_button.pressed.emit()
	await _frames()
	_check(presenter.row == null and not is_instance_id_valid(old_thread_id),
		"Return disposes the old gauge and its tooltip with the battle")


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
				app.enemies.get_enemies(), app.enemy_intents.get_intents(),
				app.enemy_intents.is_bound())
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
	_threat_cue_cases(app, presenter)
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
		and _meters(app)[1].block_badge.visible
		and _meters(app)[1].block_text.text == str(app.party.get_hero(2)["block"]),
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


## The authored Block icon follows exact live Block values, hides at zero, survives missing
## art as the drawn shield and is disposed with its own ribbon on Return.
## Counts on the actual HP trough of an admitted, seeded three-enemy battle.
## Each fixture binds one complete real CombatEnemyIntents batch; no redraw is
## requested by the presenter. Restore every battle object afterwards.
func _threat_cue_cases(app, presenter) -> void:
	var flow: CombatRoundFlow = app.round_flow
	var old_intents: CombatEnemyIntents = app.enemy_intents
	var old_unravel: CombatUnravel = flow._unravel
	var old_roster: Array[Dictionary] = app.enemies.get_enemies()
	var old_party: Array[Dictionary] = app.party.get_heroes()
	var old_rng: int = app.run_rng.state
	var before: Array = _state(app)
	_check(old_intents != null and old_intents.is_bound() and old_roster.size() == 3
		and presenter.row != null and _meters(app).size() == 6
		and presenter._bound_unravel(app) != null,
		"threat fixtures begin in a genuine seeded mounted three-enemy Fight")
	if not old_intents.is_bound() or old_roster.size() != 3 or presenter._bound_unravel(app) == null:
		return
	var patterns: Array = old_intents._definitions.duplicate(true)
	var scenarios := [
		[{"target": "front", "actions": [{"type": "attack", "amount": 3, "weight": 1}]},
		 {"target": "front", "actions": [{"type": "block", "amount": 2, "weight": 1}]},
		 {"target": "front", "actions": [{"type": "buff", "amount": 1, "weight": 1}]}],
		[{"target": "front", "actions": [{"type": "attack", "amount": 3, "weight": 1}]},
		 {"target": "front", "actions": [{"type": "debuff", "status": "weak", "amount": 1, "weight": 1}]},
		 {"target": "front", "actions": [{"type": "block", "amount": 2, "weight": 1}]}],
		[{"target": "front", "actions": [{"type": "shove", "direction": 1, "amount": 0, "weight": 1}]},
		 {"target": "lowest_living_hp", "actions": [{"type": "debuff", "status": "bleed", "amount": 2, "weight": 1}]},
		 {"target": "random", "actions": [{"type": "attack", "amount": 2, "weight": 1}]}],
	]
	for case_index in range(scenarios.size()):
		for index in range(3):
			app.enemies._enemies[index]["intent"] = scenarios[case_index][index].duplicate(true)
		var schedule := CombatEnemyIntents.new(patterns)
		_check(schedule.bind_battle(app.enemies, app.party, app.run_rng),
			"three real test-authored weighted actions bind case %d" % case_index)
		if not schedule.is_bound():
			continue
		app.enemy_intents = schedule
		flow._intents = schedule
		flow._battle_intents = schedule
		var cached: Array[Dictionary] = schedule.get_intents()
		var expected: Array[int] = [0, 0, 0]
		for action in cached:
			if action.type not in ["attack", "debuff", "shove"]:
				continue
			var effective := CombatEnemyIntents.resolve_announced_action(app.party, action, app.enemies)
			expected[effective.target_position - 1] += 1
		var rng_before: int = app.run_rng.state
		var state_before: Array = _state(app)
		for read in range(3):
			presenter._sync_battle()
			var meters := _meters(app)
			for position in range(1, 4):
				var pin := meters[position - 1].hp_bar.get_node_or_null("ThreatPin") as Panel
				_check(pin != null and pin.mouse_filter == Control.MOUSE_FILTER_IGNORE
					and pin.focus_mode == Control.FOCUS_NONE,
					"target pin is mounted on HP and cannot intercept combat input")
				if pin != null:
					var label := pin.get_node("Count") as Label
					_check(pin.visible == (expected[position - 1] > 0)
						and label.text == ("! %d" % expected[position - 1]
							if expected[position - 1] > 0 else ""),
						"read %d of mixed seeded case %d targets hero slot %d exactly" % [read, case_index, position])
		_check(_state(app) == state_before and schedule.get_intents() == cached
			and app.run_rng.state == rng_before,
			"repeated threat displays preserve HP, Block, statuses, deck, energy, cached actions and run RNG")
		if case_index == 1:
			_check(expected == [2, 0, 0], "two original living sources pin only the front hero")
			# Compare the *next* authored announcement to an independent replay
			# fed the same still-unspent RNG state.
			var replay_rng := RandomNumberGenerator.new()
			replay_rng.state = rng_before
			var expected_next := CombatEnemyIntents._draw_batch(schedule._slots, app.party, replay_rng)
			_check(schedule.advance_turn() and schedule.get_intents() == expected_next
				and app.run_rng.state == replay_rng.state,
				"next-announcement replay is unchanged by read-only threat refresh")
			# The original announced cache is still our input for fallback checks.
			schedule._cache.assign(cached.duplicate(true))
			app.run_rng.state = rng_before
			_check(app.party.apply_damage(1, 999) and app.party.is_downed(1),
				"authentic front target is downed after its action was announced")
			presenter._sync_battle()
			var fallen_pins := _meters(app)
			_check(not fallen_pins[0].hp_bar.get_node("ThreatPin").visible
				and fallen_pins[1].hp_bar.get_node("ThreatPin/Count").text == "! 2"
				and fallen_pins[1].hp_bar.get_node("ThreatPin").visible,
				"both policies use deterministic front fallback on living H2 with no RNG reroll")
			_check(schedule.get_intents() == cached and app.run_rng.state == rng_before,
				"downed announced target does not replace original cache or consume run RNG")
			app.party._heroes.assign(old_party.duplicate(true))
			presenter._sync_battle()
			_check(_meters(app)[0].hp_bar.get_node("ThreatPin/Count").text == "! 2",
				"restored first hero recovers the two-source warning")
		if case_index == 0:
			_check(expected == [1, 0, 0], "one attack pins one hero; block and buff never count")
			var skip := CombatUnravel.new()
			_check(skip.bind_roster(app.enemies, {1: "normal", 2: "normal", 3: "normal"})
				and skip.apply_unravel(app.enemies, 1, 8), "real Unravel service queues a source skip")
			flow._unravel = skip
			presenter._sync_battle()
			_check(_meters(app)[0].hp_bar.get_node("ThreatPin").visible == false,
				"pending skip removes its only threat")
			flow._unravel = old_unravel
			_check(app.enemies.apply_damage(1, 999), "test kills its only attacking source")
			presenter._sync_battle()
			_check(not _meters(app)[0].hp_bar.get_node("ThreatPin").visible,
				"slain attacker cannot contribute threats")
			app.enemies._enemies.assign(old_roster.duplicate(true))
			presenter._sync_battle()
			_check(_meters(app)[0].hp_bar.get_node("ThreatPin").visible,
				"restoring source restores its announced threat")
			# A closed fight and missing/mismatched scheduler both fail closed.
			app._battle_closed = true
			presenter._sync_battle()
			_check(not _meters(app)[0].hp_bar.get_node("ThreatPin").visible,
				"closed fight clears pending warning while ribbon exists")
			app._battle_closed = false
			app.enemy_intents = null
			presenter._sync_battle()
			_check(not _meters(app)[0].hp_bar.get_node("ThreatPin").visible,
				"missing intent authority hides stale target pin")
			app.enemy_intents = schedule
			var foreign := CombatEnemyIntents.new(patterns)
			app.enemy_intents = foreign
			presenter._sync_battle()
			_check(not _meters(app)[0].hp_bar.get_node("ThreatPin").visible,
				"unbound, mismatched authority cannot fabricate a threat")
			app.enemy_intents = schedule
			presenter._sync_battle()
	app.enemies._enemies.assign(old_roster.duplicate(true))
	app.party._heroes.assign(old_party.duplicate(true))
	app.enemy_intents = old_intents
	flow._intents = old_intents
	flow._battle_intents = old_intents
	flow._unravel = old_unravel
	app.run_rng.state = old_rng
	presenter._sync_battle()
	_check(_state(app) == before, "all threat-cue fixture scenarios restore the entire live battle snapshot")


func _block_art_case(app, presenter) -> void:
	_fixture_start(app)
	await _frames()
	_check(ResourceLoader.exists(BLOCK_ART, "Texture2D")
		and presenter.block_texture() is Texture2D
		and presenter.block_texture().resource_path == BLOCK_ART,
		"the committed Block art resolves from the mounted presenter")
	_check(app.party != null and app.party.get_hero(1)["block"] > 0
		and app.party.get_hero(3)["block"] == 0,
		"authentic opening has a protected and an unprotected hero")
	if app.party == null or app.party.get_hero(1)["block"] <= 0:
		return
	var opening_block: String = str(app.party.get_hero(1)["block"])
	var meters := _meters(app)
	_check(meters.size() == 5, "the Block-art fight mounts all five real ribbons")
	if meters.size() != 5:
		return
	var warden_icon := meters[0].block_shield.get_node_or_null("BlockIcon") as TextureRect
	var tinker_icon := meters[2].block_shield.get_node_or_null("BlockIcon") as TextureRect
	_check(warden_icon != null and tinker_icon != null
		and warden_icon.get_instance_id() != tinker_icon.get_instance_id(),
		"every mounted ribbon owns its own authored Block icon")
	if warden_icon == null or tinker_icon == null:
		return
	var warden_icon_id := warden_icon.get_instance_id()
	_check(warden_icon.visible and warden_icon.texture.resource_path == BLOCK_ART
		and meters[0].block_text.text == opening_block and meters[0].block_badge.visible,
		"mounted Warden shows the authored Block icon with the exact model amount")
	_check(not tinker_icon.visible and not tinker_icon.is_visible_in_tree()
		and meters[2].block_text.text.is_empty() and not meters[2].block_badge.visible,
		"a hero with zero Block shows no authored icon and no misleading amount")
	# Real party APIs drive the exact amount the mounted icon follows on the next frame.
	var before_gain := _state(app)
	_check(app.party.gain_block(3, 4), "real party API gives the unprotected hero Block")
	await _frames()
	_visible(app)
	_check(app.party.get_hero(3)["block"] == 4 and meters[2].block_text.text == "4"
		and tinker_icon.visible and tinker_icon.is_visible_in_tree()
		and tinker_icon.texture.resource_path == BLOCK_ART,
		"authored Block icon follows a real positive Block amount")
	_check(_state(app) != before_gain and app.deck.energy == before_gain[5],
		"only the intended Block gain changed while energy and piles stayed exact")
	# Missing art keeps the drawn sewn shield and the same nodes, never a broken icon.
	presenter.art_root = "res://assets/paper/ui/absent/"
	presenter._sync_battle()
	await _frames()
	_check(warden_icon.texture == null and not warden_icon.visible
		and tinker_icon.texture == null and not tinker_icon.visible,
		"missing Block art resolves to no icon at all")
	_check(meters[0].block_shield.is_visible_in_tree() and meters[0].block_shield.draw_count > 0
		and meters[0].block_text.text == opening_block
		and meters[0].block_badge.visible
		and meters[2].block_badge.visible and meters[2].block_text.text == "4"
		and not meters[1].block_badge.visible and meters[1].block_text.text.is_empty(),
		"missing Block art keeps the drawn sewn shield and the exact amounts")
	_check(_meters(app)[0] == meters[0] and _meters(app)[2] == meters[2]
		and meters[0].block_shield.get_node_or_null("BlockIcon") == warden_icon
		and warden_icon.get_instance_id() == warden_icon_id,
		"missing art reuses the mounted icons instead of mounting duplicates")
	presenter.art_root = presenter.UI_ART_DIR
	presenter._sync_battle()
	await _frames()
	_visible(app)
	_check(warden_icon.texture is Texture2D and warden_icon.texture.resource_path == BLOCK_ART
		and warden_icon.visible and warden_icon.get_instance_id() == warden_icon_id,
		"restored Block art repaints the same mounted icon")
	# A real turn resets Block: the icon must disappear with the exact zero amount.
	var before_turn := _state(app)
	await _mouse(app.end_turn_button)
	await _frames()
	_visible(app)
	_check(_state(app) != before_turn, "the real End Turn actually advanced the fight")
	_check(app.party.get_hero(1)["block"] == 0 and app.party.get_hero(3)["block"] == 0
		and meters[0].block_text.text.is_empty() and not meters[0].block_badge.visible
		and not warden_icon.visible and not warden_icon.is_visible_in_tree()
		and not tinker_icon.visible,
		"a real End Turn resets Block and removes the authored icon everywhere")
	var icon_ids: Array[int] = []
	for meter in meters:
		var icon := meter.block_shield.get_node_or_null("BlockIcon") as TextureRect
		if icon != null:
			icon_ids.append(icon.get_instance_id())
	_check(icon_ids.size() == 5 and icon_ids.has(warden_icon_id),
		"all five ribbons keep one authored icon through the turn")
	await _mouse(app.return_button)
	await _frames()
	_check(app.title_view.is_visible_in_tree() and presenter.row == null,
		"Block-art fight returns to the title")
	for id in icon_ids:
		_check(not is_instance_id_valid(id), "Return frees the authored Block icon with its ribbon")


func _worn_coat_ribbons_test(app, presenter) -> void:
	_fixture_start(app)
	await _frames()
	_check(app.party != null and is_instance_valid(app.battle_view),
		"worn coat ribbons: live battle ready")
	if app.party == null or not is_instance_valid(app.battle_view):
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	if typeof(raw) != TYPE_ARRAY or raw.size() != 3:
		return
	var combat_defs: Array = raw.duplicate(true)
	for record in combat_defs:
		record["max_hp"] = int(record["max_hp"])
	var party_template := CombatParty.new(combat_defs)
	var raw_heroes: Array = party_template.get_heroes()
	var definitions := []
	for catalog in ["initial_patch_slots", "m04_attack_patches", "m04_coat_patches"]:
		var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/%s.json" % catalog))
		if entries is Array:
			for entry in entries:
				definitions.append({"id": entry["id"], "slot": entry["slot"]})
	var owned := ["chain_stitched_coat", "padded_vest", "double_quilt_coat", "button_eye", "pincushion_arm", "quilted_coat"]
	var carry := RunTornCarryover.new(raw_heroes)
	_check(carry.is_valid() and carry.torn.is_valid(), "carryover and torn valid")
	var wardrobe := RunPatchWardrobe.new(raw_heroes, owned, definitions, 6, 50, ["warden_strike"], 93811, true)
	_check(wardrobe.is_valid(), "wardrobe valid for live coats test")
	if not carry.is_valid() or not wardrobe.is_valid():
		return
	# Sew chain_stitched_coat (+7) on Warden (pos 1), padded_vest (+4) on Seamstress (pos 2)
	# Tinker (pos 3) has no coat sewn (unworn)
	_check(wardrobe.sew("chain_stitched_coat", "warden", "COAT", "sew:chain", wardrobe.get_snapshot()).ok,
		"Warden sews chain_stitched_coat")
	_check(wardrobe.sew("padded_vest", "seamstress", "COAT", "sew:padded", wardrobe.get_snapshot()).ok,
		"Seamstress sews padded_vest")
	_check(carry.can_bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()),
		"can_bind_wardrobe is true")
	_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()),
		"carryover binds wardrobe with authored coats")
	app.party_carryover = carry
	var combat_party: CombatParty = carry.create_next_fight_party()
	_check(combat_party != null and combat_party.is_valid(),
		"combat party created with authored coat projections")
	if combat_party == null:
		return
	app.party = combat_party
	presenter._sync_battle()
	await _frames()
	var meters := _meters(app)
	_check(meters.size() >= 5, "hero and enemy meters mounted for coat test")
	if meters.size() < 3:
		return
	# Hero 1: Warden wearing chain_stitched_coat (+7)
	var warden_meter: CombatActorMeter = meters[0]
	_check(warden_meter.hp_text.text == "40/47", "Warden HP text shows 40/47 with +7 coat")
	var warden_patches := warden_meter.get_node_or_null("Padding/Content/PatchButtons") as HBoxContainer
	_check(warden_patches != null and warden_patches.visible, "Warden patch row is visible")
	var warden_coat_btn := warden_patches.get_node("PatchCOAT") as Button
	_check(warden_coat_btn != null and warden_coat_btn.visible and warden_coat_btn.text == "COAT",
		"Warden COAT chip visible with label COAT")
	_check(warden_coat_btn.tooltip_text.contains("Warden (warden)")
		and warden_coat_btn.tooltip_text.contains("Chain Stitched Coat (chain_stitched_coat) — COAT")
		and warden_coat_btn.tooltip_text.contains("ACTIVE")
		and warden_coat_btn.tooltip_text.contains("+7 effective maximum HP while living; no free healing."),
		"Warden COAT chip tooltip correctly names Chain Stitched Coat, ACTIVE, and +7 HP bonus")
	_check(not (warden_patches.get_node("PatchHEAD") as Button).visible
		and not (warden_patches.get_node("PatchARM") as Button).visible,
		"unsewn HEAD/ARM slots not mislabeled on Warden")
	# Hero 2: Seamstress wearing padded_vest (+4)
	var seamstress_meter: CombatActorMeter = meters[1]
	_check(seamstress_meter.hp_text.text == "30/34", "Seamstress HP text shows 30/34 with +4 coat")
	var seamstress_patches := seamstress_meter.get_node_or_null("Padding/Content/PatchButtons") as HBoxContainer
	_check(seamstress_patches != null and seamstress_patches.visible, "Seamstress patch row is visible")
	var seamstress_coat_btn := seamstress_patches.get_node("PatchCOAT") as Button
	_check(seamstress_coat_btn != null and seamstress_coat_btn.visible and seamstress_coat_btn.text == "COAT",
		"Seamstress COAT chip visible with label COAT")
	_check(seamstress_coat_btn.tooltip_text.contains("Seamstress (seamstress)")
		and seamstress_coat_btn.tooltip_text.contains("Padded Vest (padded_vest) — COAT")
		and seamstress_coat_btn.tooltip_text.contains("ACTIVE")
		and seamstress_coat_btn.tooltip_text.contains("+4 effective maximum HP while living; no free healing."),
		"Seamstress COAT chip tooltip correctly names Padded Vest, ACTIVE, and +4 HP bonus")
	# Hero 3: Tinker unworn COAT slot
	var tinker_meter: CombatActorMeter = meters[2]
	var tinker_patches := tinker_meter.get_node_or_null("Padding/Content/PatchButtons") as HBoxContainer
	if tinker_patches != null:
		var tinker_coat_btn := tinker_patches.get_node("PatchCOAT") as Button
		_check(not tinker_coat_btn.visible and tinker_coat_btn.text.is_empty()
			and tinker_coat_btn.tooltip_text.is_empty(),
			"Tinker unworn COAT chip is hidden with no active bonus or tooltip")
	# Real pointer hover on the active coat button
	await _hover(warden_coat_btn)
	_check(root.gui_get_hovered_control() == warden_coat_btn, "real pointer hover reaches Warden COAT chip")
	await _hover(seamstress_coat_btn)
	_check(root.gui_get_hovered_control() == seamstress_coat_btn, "real pointer hover reaches Seamstress COAT chip")
	# Downed wearer test: down Seamstress
	_check(app.party.apply_damage(2, 999) and app.party.is_downed(2), "Seamstress downed")
	presenter._sync_battle()
	await _frames()
	_check(seamstress_coat_btn.visible and seamstress_coat_btn.text == "COAT",
		"downed Seamstress keeps sewn COAT chip")
	_check(seamstress_coat_btn.tooltip_text.contains("DORMANT")
		and not seamstress_coat_btn.tooltip_text.contains("ACTIVE")
		and seamstress_coat_btn.tooltip_text.contains("Padded Vest (padded_vest) — COAT")
		and seamstress_coat_btn.tooltip_text.contains("+4 effective maximum HP while living; no free healing."),
		"downed wearer chip shows DORMANT condition and no active bonus")
	_check(bool(seamstress_coat_btn.get_meta("fallen_chip")) == true,
		"downed wearer chip styled with fallen tint")
	# Invariant checks: ensure carryover and wardrobe remain valid
	_check(app.party_carryover == carry and carry._wardrobe == wardrobe,
		"presentation inspection leaves carryover and wardrobe untouched")
	await _mouse(app.return_button)
	await _frames()
	_check(app.title_view.is_visible_in_tree() and presenter.row == null,
		"worn coat ribbons test cleans up and returns to title")


## The mounted patch chip for one authored slot on a hero ribbon.
func _patch_chip(meter: CombatActorMeter, slot: String) -> Button:
	var row := meter.get_node_or_null("Padding/Content/PatchButtons") as HBoxContainer
	if row == null:
		return null
	return row.get_node_or_null("Patch" + slot) as Button


## Exact wearer/id/slot/state tooltip the mounted ribbon composes for one sewn patch.
func _patch_tooltip(hero: Dictionary, label: String, patch_id: String, slot: String,
		active: bool) -> String:
	return "%s (%s)\n%s (%s) — %s\n%s" % [
		hero.get("name", String(hero["id"]).capitalize()), hero["id"],
		label, patch_id, slot, "ACTIVE" if active else "DORMANT"]


## The authored catalog record for one bounded M05 HEAD/ARM ID, looked up by ID
## presence so growing catalogs never invalidate this check.
func _m05_catalog_entry(patch_id: String) -> Dictionary:
	for path in ["res://data/patches/m05_head_patches.json",
			"res://data/patches/m05_arm_support_patches.json",
			"res://data/patches/m05_attack_patches.json"]:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if raw is Array:
			for entry in raw:
				if entry is Dictionary and entry.get("id") == patch_id:
					return entry
	return {}


## Re-derive one M05 rule independently of the presenter: exact catalog amount
## and effect key, the positive status, wearer-owned cards, the real Block
## recipient, Red Bobbin versus Hemorrhage Hem, and Frayfinder's first
## single-target hit / half-threshold / once-per-player-turn limit.
func _assert_m05_rule_terms(patch_id: String, line: String) -> void:
	var facts: Dictionary = M05_EXPECTED_FACTS[patch_id]
	var entry := _m05_catalog_entry(patch_id)
	_check(not entry.is_empty() and entry.get("slot") == facts["slot"]
		and entry.get("effect") == facts["effect"]
		and int(entry.get("amount", -1)) == int(facts["amount"]),
		"authored catalog agrees with the expected %s %s +%d rule: %s" % [
			facts["slot"], facts["effect"], facts["amount"], patch_id])
	_check(line.begins_with("Authored patch rule:"),
		"the %s line describes an authored rule, not a fabricated trigger: %s" % [patch_id, line])
	if patch_id != "frayfinder_mitt":
		_check(line.contains(String(facts["effect"])),
			"the %s line names its authored effect key: %s" % [patch_id, line])
	if patch_id == "frayfinder_mitt":
		var numerator := int(entry.get("minimum_unravel_numerator", 0))
		var denominator := int(entry.get("minimum_unravel_denominator", 0))
		_check(line.contains("+%d Unravel" % facts["amount"])
			and line.contains("first single-target attack hit")
			and line.contains("at least %d/%d of its current threshold" % [numerator, denominator])
			and line.contains("once per PLAYER turn")
			and line.contains("Not any area/multi-hit/later hit")
			and entry.get("once_per_player_turn") == true
			and int(entry.get("hit_number", 0)) == 1
			and entry.get("target_kind") == "enemy_single"
			and numerator == 1 and denominator == 2,
			"Frayfinder Mitt keeps its +2 first single-target hit, half-threshold, once-per-turn condition: " + line)
		_check(not line.contains("unconditional") and not line.contains("every attack"),
			"Frayfinder Mitt never claims an unconditional or per-attack Unravel bonus: " + line)
		_check(line.contains("Normal/elite/boss base thresholds %d/%d/%d, grow +%d per break" % [
				CombatUnravel.THRESHOLD_NORMAL, CombatUnravel.THRESHOLD_ELITE,
				CombatUnravel.THRESHOLD_BOSS, CombatUnravel.THRESHOLD_INCREMENT]),
			"Frayfinder Mitt states the real Unravel base thresholds and growth: " + line)
	else:
		_check(line.contains("+%d to positive %s" % [facts["amount"], facts["status"]]),
			"the %s line keeps its authored +%d positive %s amount: %s" % [
				patch_id, facts["amount"], facts["status"], line])
		_check(line.contains("this wearer's cards")
			or line.contains("cards owned by this living wearer"),
			"the %s line restricts the bonus to the wearer's own cards: %s" % [patch_id, line])
		_check(not line.contains("any hero") and not line.contains("unconditional")
			and not line.contains("any cards"),
			"the %s line never claims an unconditional bonus to anyone's cards: %s" % [patch_id, line])
	if patch_id == "reinforced_browband":
		_check(line.contains("actual Block recipient (even if it is an ally)"),
			"Reinforced Browband names the card's real Block recipient, including an ally: " + line)
	if patch_id == "red_bobbin_cuff":
		_check(line.contains("not Hemorrhage Hem's multiplier"),
			"Red Bobbin Cuff is not Hemorrhage Hem's multiplier: " + line)


## A named sewn HEAD/ARM patch: readable name, authored ID, real wearer and
## slot, plus the independently expected authored rule line for the eight M05
## entries, never an invented/fabricated effect sentence. Unknown IDs keep only
## the neutral 3-line prefix.
func _assert_named_chip(button: Button, hero: Dictionary, label: String,
		patch_id: String, slot: String, active: bool) -> void:
	_check(button != null and button.visible and button.text == slot
		and button.focus_mode == Control.FOCUS_NONE
		and button.mouse_filter == Control.MOUSE_FILTER_STOP
		and button.mouse_default_cursor_shape == Control.CURSOR_HELP
		and button.pressed.get_connections().is_empty(),
		"sewn %s chip is a visible, hover-only, actionless slot label: %s" % [slot, patch_id])
	if button == null:
		return
	var prefix := _patch_tooltip(hero, label, patch_id, slot, active)
	if M05_EXPECTED_POWERS.has(patch_id):
		var rule_line: String = M05_EXPECTED_POWERS[patch_id]
		var lines := button.tooltip_text.split("\n")
		_check(lines.size() == 4,
			"known M05 %s tooltip has four lines (base + authored rule): %s" % [patch_id, button.tooltip_text])
		_check(lines.size() == 4 and "\n".join(lines.slice(0, 3)) == prefix,
			"%s keeps the complete wearer/name/ID/slot/ACTIVE or DORMANT prefix: %s" % [
				patch_id, button.tooltip_text])
		_check(lines.size() == 4 and lines[3] == rule_line,
			"%s shows its independently expected authored rule line: %s" % [patch_id, button.tooltip_text])
		if lines.size() == 4:
			_assert_m05_rule_terms(patch_id, lines[3])
		_check(button.tooltip_text == prefix + "\n" + rule_line,
			"%s chip matches the full expected tooltip: %s" % [patch_id, button.tooltip_text])
	else:
		_check(button.tooltip_text == prefix,
			"%s keeps its readable name, authored ID, wearer and slot: %s" % [patch_id, button.tooltip_text])
		_check(button.tooltip_text.split("\n").size() == 3,
			"unwired patch tooltip invents no effect line: " + patch_id)


## Build a genuine wardrobe/carryover exactly like real play, sew the supplied
## [patch_id, hero_id, slot] triples, mount the real combat party and return the
## live meters plus the authoritative ledgers. Returns {} on any setup failure.
func _m05_worn_fixture(app, presenter, sewn: Array) -> Dictionary:
	_fixture_start(app)
	await _frames()
	if app.party == null or not is_instance_valid(app.battle_view):
		return {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	if typeof(raw) != TYPE_ARRAY or raw.size() != 3:
		return {}
	var combat_defs: Array = raw.duplicate(true)
	for record in combat_defs:
		record["max_hp"] = int(record["max_hp"])
	var raw_heroes: Array = CombatParty.new(combat_defs).get_heroes()
	var definitions := []
	for catalog in ["initial_patch_slots", "m04_attack_patches", "m04_coat_patches",
			"m05_head_patches", "m05_arm_support_patches", "m05_attack_patches"]:
		var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/%s.json" % catalog))
		if entries is Array:
			for entry in entries:
				definitions.append({"id": entry["id"], "slot": entry["slot"]})
	var owned: Array = []
	for entry in sewn:
		owned.append(entry[0])
	var carry := RunTornCarryover.new(raw_heroes)
	var wardrobe := RunPatchWardrobe.new(raw_heroes, owned, definitions, 6, 50,
		["warden_strike"], 93811, true)
	_check(carry.is_valid() and wardrobe.is_valid(),
		"M05 worn case: real carryover and wardrobe are valid")
	if not carry.is_valid() or not wardrobe.is_valid():
		return {}
	for index in range(sewn.size()):
		var receipt: Dictionary = wardrobe.sew(sewn[index][0], sewn[index][1],
			sewn[index][2], "sew:m05:%d" % index, wardrobe.get_snapshot())
		_check(receipt.get("ok", false), "M05 worn case sews " + sewn[index][0])
		if not receipt.get("ok", false):
			return {}
	_check(carry.can_bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()),
		"M05 worn case: carryover accepts the authored wardrobe")
	_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()),
		"M05 worn case: carryover binds the wardrobe")
	app.party_carryover = carry
	var combat_party: CombatParty = carry.create_next_fight_party()
	_check(combat_party != null and combat_party.is_valid(),
		"M05 worn case: the real combat party carries the authored patch projections")
	if combat_party == null:
		return {}
	app.party = combat_party
	presenter._sync_battle()
	await _frames()
	var meters := _meters(app)
	_check(meters.size() >= 5, "M05 worn case: mounted hero ribbons exist")
	if meters.size() < 5:
		return {}
	return {"meters": meters, "carry": carry, "wardrobe": wardrobe, "party": combat_party}


## M05: the live worn chip names each newly sewn patch, and the two newly authored
## coats show the authoritative RunPatchCoatRules power they already provide.
func _m05_patch_ribbons_test(app, presenter) -> void:
	# AC1: bounded known-ID labels, with the previously accepted names intact.
	var labels := {
		"bloodstitch_bonnet": "Bloodstitch Bonnet", "button_glass_visor": "Button Glass Visor",
		"stern_seam_cap": "Stern Seam Cap", "reinforced_browband": "Reinforced Browband",
		"hemguard_cuff": "Hemguard Cuff", "red_bobbin_cuff": "Red Bobbin Cuff",
		"loose_thread_glove": "Loose Thread Glove", "frayfinder_mitt": "Frayfinder Mitt",
		"reinforced_patchcoat": "Reinforced Patchcoat", "thick_felt_mantle": "Thick Felt Mantle",
		"button_eye": "Button Eye", "pincushion_arm": "Pincushion Arm",
		"quilted_coat": "Quilted Coat", "stitched_badge": "Stitched Badge",
		"spare_spool": "Spare Spool"}
	for id in labels:
		_check(presenter.PATCH_LABELS.get(id, "") == labels[id],
			"authored readable patch label stays intact: " + id)
	# Case A: both new COAT options plus representative HEAD/ARM labels.
	var case_a := await _m05_worn_fixture(app, presenter, [
		["bloodstitch_bonnet", "warden", "HEAD"],
		["hemguard_cuff", "warden", "ARM"],
		["reinforced_patchcoat", "warden", "COAT"],
		["thick_felt_mantle", "seamstress", "COAT"],
		["button_glass_visor", "tinker", "HEAD"],
		["loose_thread_glove", "tinker", "ARM"]])
	_check(not case_a.is_empty(), "M05 case A: real wardrobe, carryover and live meters")
	if case_a.is_empty():
		return
	var meters: Array = case_a["meters"]
	var carry: RunTornCarryover = case_a["carry"]
	var wardrobe: RunPatchWardrobe = case_a["wardrobe"]
	var coats: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_coat_patches.json"))
	var projected: Dictionary = RunPatchCoatRules.project_health(
		carry.torn.read_state(), wardrobe, coats)
	_check(projected.get("ok") == true, "M05 case A: authoritative coat projection is valid")
	if projected.get("ok") != true:
		return
	var by_id := {}
	for hero in projected["heroes"]:
		by_id[hero["id"]] = hero
	# AC2: real authored +9/+10 caps from the genuine carryover party, no free heal.
	_check(app.party.get_hero(1)["max_hp"] == 49 and app.party.get_hero(1)["hp"] == 40
		and app.party.get_hero(1)["max_hp"] == by_id["warden"]["max_hp"],
		"Warden wears reinforced_patchcoat for the authoritative +9 cap without a heal")
	_check(app.party.get_hero(2)["max_hp"] == 40 and app.party.get_hero(2)["hp"] == 30
		and app.party.get_hero(2)["max_hp"] == by_id["seamstress"]["max_hp"],
		"Seamstress wears thick_felt_mantle for the authoritative +10 cap without a heal")
	_check(meters[0].hp_text.text == "40/49" and meters[1].hp_text.text == "30/40"
		and meters[2].hp_text.text == "26/26",
		"M05 case A: the visible HP numbers carry the real coat caps")
	var warden_coat := _patch_chip(meters[0], "COAT")
	_check(warden_coat != null and warden_coat.visible and warden_coat.text == "COAT"
		and warden_coat.focus_mode == Control.FOCUS_NONE
		and warden_coat.pressed.get_connections().is_empty(),
		"M05 case A: Warden COAT chip is a visible, actionless slot label")
	_check(warden_coat != null and warden_coat.tooltip_text
		== _patch_tooltip(app.party.get_hero(1), "Reinforced Patchcoat", "reinforced_patchcoat",
			"COAT", true) + "\n+9 effective maximum HP while living; no free healing.",
		"Warden COAT chip names Reinforced Patchcoat, its real +9 and no free healing")
	var seamstress_coat := _patch_chip(meters[1], "COAT")
	_check(seamstress_coat != null and seamstress_coat.visible and seamstress_coat.text == "COAT",
		"M05 case A: Seamstress COAT chip is a visible slot label")
	_check(seamstress_coat != null and seamstress_coat.tooltip_text
		== _patch_tooltip(app.party.get_hero(2), "Thick Felt Mantle", "thick_felt_mantle",
			"COAT", true) + "\n+10 effective maximum HP while living; no free healing.",
		"Seamstress COAT chip names Thick Felt Mantle, its real +10 and no free healing")
	# AC1/AC3: named HEAD/ARM patches with their authored rules.
	_assert_named_chip(_patch_chip(meters[0], "HEAD"), app.party.get_hero(1),
		"Bloodstitch Bonnet", "bloodstitch_bonnet", "HEAD", true)
	_assert_named_chip(_patch_chip(meters[0], "ARM"), app.party.get_hero(1),
		"Hemguard Cuff", "hemguard_cuff", "ARM", true)
	_assert_named_chip(_patch_chip(meters[2], "HEAD"), app.party.get_hero(3),
		"Button Glass Visor", "button_glass_visor", "HEAD", true)
	_assert_named_chip(_patch_chip(meters[2], "ARM"), app.party.get_hero(3),
		"Loose Thread Glove", "loose_thread_glove", "ARM", true)
	var tinker_coat := _patch_chip(meters[2], "COAT")
	_check(tinker_coat != null and not tinker_coat.visible and tinker_coat.text.is_empty()
		and tinker_coat.tooltip_text.is_empty(),
		"an unsewn COAT slot stays hidden with no invented bonus")
	var before := _state(app)
	var ledger: Dictionary = wardrobe.get_snapshot()
	seed(61017)
	var expected_global := randi()
	seed(61017)
	for repeat in range(4):
		presenter._sync_battle()
		await _frames()
	# AC3: real pointer hover and repeated refresh spend nothing and mutate nothing.
	await _hover(warden_coat)
	_check(root.gui_get_hovered_control() == warden_coat
		and warden_coat.tooltip_text.contains("+9 effective maximum HP while living; no free healing."),
		"real pointer hover reads the mounted COAT power without an action")
	_check(_state(app) == before and randi() == expected_global
		and wardrobe.get_snapshot() == ledger and app.party_carryover == carry
		and carry._wardrobe == wardrobe,
		"M05 case A: repeated hover/refresh never spends, changes HP/Block/ownership or advances RNG")
	# Neutral unknown ID and empty slots through the mounted presenter itself.
	var tinker: Dictionary = app.party.get_hero(3)
	presenter._sync_patch_buttons(meters[2], tinker,
		{"HEAD": "mystery_m05_patch", "ARM": "", "COAT": ""})
	var unknown := _patch_chip(meters[2], "HEAD")
	_check(unknown != null and unknown.visible and unknown.text == "HEAD"
		and unknown.tooltip_text == _patch_tooltip(tinker, "mystery_m05_patch",
			"mystery_m05_patch", "HEAD", true)
		and unknown.tooltip_text.split("\n").size() == 3,
		"an unknown patch ID keeps its raw authored ID and invents no power line")
	_check(not _patch_chip(meters[2], "ARM").visible
		and _patch_chip(meters[2], "ARM").tooltip_text.is_empty()
		and not _patch_chip(meters[2], "COAT").visible
		and _patch_chip(meters[2], "COAT").tooltip_text.is_empty(),
		"empty HEAD/ARM/COAT slots never gain a fictional bonus")
	_check(_state(app) == before and wardrobe.get_snapshot() == ledger,
		"inspecting an unknown ID or empty slot changes no combat, wallet or ledger state")
	presenter._sync_battle()
	await _frames()
	_check(_patch_chip(meters[2], "HEAD").tooltip_text.contains(
			"Button Glass Visor (button_glass_visor) — HEAD")
		and not _patch_chip(meters[2], "COAT").visible,
		"the next authoritative frame restores the real sewn chips")
	# AC2: the same worn COAT chip goes DORMANT once its wearer is torn.
	_check(app.party.apply_damage(1, 999) and app.party.is_downed(1),
		"M05 case A: the real party API downs the reinforced-patchcoat wearer")
	presenter._sync_battle()
	await _frames()
	_check(meters[0].hp_text.text == "0/49", "the torn wearer keeps its real +9 cap at zero HP")
	_check(warden_coat.visible and warden_coat.text == "COAT"
		and warden_coat.tooltip_text
			== _patch_tooltip(app.party.get_hero(1), "Reinforced Patchcoat", "reinforced_patchcoat",
				"COAT", false) + "\n+9 effective maximum HP while living; no free healing."
		and not warden_coat.tooltip_text.contains("ACTIVE")
		and bool(warden_coat.get_meta("fallen_chip")) == true,
		"the worn COAT chip reads DORMANT with no false active bonus once its wearer is torn")
	_assert_named_chip(_patch_chip(meters[0], "HEAD"), app.party.get_hero(1),
		"Bloodstitch Bonnet", "bloodstitch_bonnet", "HEAD", false)
	_check(_patch_chip(meters[1], "COAT").tooltip_text.contains("ACTIVE")
		and _patch_chip(meters[1], "COAT").tooltip_text.contains("+10 effective maximum HP"),
		"the other living wearer's COAT stays ACTIVE with its own +10")
	await _mouse(app.return_button)
	await _frames()
	_check(app.title_view.is_visible_in_tree() and presenter.row == null,
		"M05 case A: real Return clears the ribbon row")
	# Case B: the remaining new HEAD/ARM labels on a genuine second wardrobe.
	var case_b := await _m05_worn_fixture(app, presenter, [
		["stern_seam_cap", "warden", "HEAD"],
		["red_bobbin_cuff", "warden", "ARM"],
		["reinforced_browband", "seamstress", "HEAD"],
		["frayfinder_mitt", "seamstress", "ARM"]])
	_check(not case_b.is_empty(), "M05 case B: real wardrobe, carryover and live meters")
	if case_b.is_empty():
		return
	var b_meters: Array = case_b["meters"]
	_assert_named_chip(_patch_chip(b_meters[0], "HEAD"), app.party.get_hero(1),
		"Stern Seam Cap", "stern_seam_cap", "HEAD", true)
	_assert_named_chip(_patch_chip(b_meters[0], "ARM"), app.party.get_hero(1),
		"Red Bobbin Cuff", "red_bobbin_cuff", "ARM", true)
	_assert_named_chip(_patch_chip(b_meters[1], "HEAD"), app.party.get_hero(2),
		"Reinforced Browband", "reinforced_browband", "HEAD", true)
	_assert_named_chip(_patch_chip(b_meters[1], "ARM"), app.party.get_hero(2),
		"Frayfinder Mitt", "frayfinder_mitt", "ARM", true)
	_check(app.party.get_hero(1)["max_hp"] == 40 and app.party.get_hero(2)["max_hp"] == 30
		and app.party.get_hero(3)["max_hp"] == 26 and b_meters[0].hp_text.text == "40/40",
		"M05 case B: HEAD/ARM patches never invent a maximum-HP change")
	for index in range(3):
		var chip := _patch_chip(b_meters[index], "COAT")
		_check(chip != null and not chip.visible and chip.text.is_empty()
			and chip.tooltip_text.is_empty(),
			"an empty COAT slot stays hidden on hero %d" % (index + 1))
	var arm_chip := _patch_chip(b_meters[1], "ARM")
	await _hover(arm_chip)
	_check(root.gui_get_hovered_control() == arm_chip
		and arm_chip.tooltip_text == _patch_tooltip(app.party.get_hero(2), "Frayfinder Mitt",
			"frayfinder_mitt", "ARM", true) + "\n" + M05_EXPECTED_POWERS["frayfinder_mitt"]
		and arm_chip.tooltip_text.contains("+2 Unravel")
		and arm_chip.tooltip_text.contains("first single-target attack hit")
		and arm_chip.tooltip_text.contains("at least 1/2 of its current threshold")
		and arm_chip.tooltip_text.contains("once per PLAYER turn")
		and not arm_chip.tooltip_text.contains("unconditional"),
		"real pointer hover reads Frayfinder Mitt's authored conditional +2 Unravel rule")
	await _mouse(app.return_button)
	await _frames()
	_check(app.title_view.is_visible_in_tree() and presenter.row == null,
		"M05 patch ribbons test cleans up and returns to title")
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
