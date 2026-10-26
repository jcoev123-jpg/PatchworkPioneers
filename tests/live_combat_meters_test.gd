extends SceneTree

var failures: Array[String] = []
var checks := 0
## Status chips keep their complete names at a readable size: at every normal 1280x720
## actor width the flow lays "Bleed 3" style labels out at 14 px and wraps them onto as
## many rows as the actor's own slot needs, reserving exactly that height.
const READABLE_CHIP_FONT := 14
## The hero threat tag must word its already-announced count grammatically at a legible
## size: "1 FOE", "2 FOES", and nothing at all when no source targets that hero.
const THREAT_BADGE_FONT := 12
const THREAT_BADGE_ONE := "1 FOE"
const THREAT_BADGE_MANY := "%d FOES"
## The committed Block icon the mounted ribbons must display beside a positive amount.
const BLOCK_ART := "res://assets/paper/ui/hud_block.png"
## Independent literal expectations for the authored M05 HEAD/ARM/COAT rules.
## These fourth tooltip lines are written from data/patches/m05_*.json, the shared
## M04 attack catalog (Switchback Button) and the rule scripts, never produced by
## the presenter under test, so a wrong amount, effect kind, recipient scope or
## condition cannot pass by agreeing with it. Each line is player language: no
## internal effect keys and no "Authored patch rule" preamble.
const M05_EXPECTED_POWERS := {
	"bloodstitch_bonnet": "This wearer's cards that already apply Bleed add 1 more Bleed.",
	"button_glass_visor": "This wearer's cards that already apply Exposed add 1 more Exposed.",
	"stern_seam_cap": "This wearer's cards that already apply Weak add 1 more Weak.",
	"reinforced_browband": "This wearer's cards that already grant Block grant 2 more Block, to the card's actual recipient (even an ally).",
	"hemguard_cuff": "This wearer's cards that already grant Block grant 2 more Block.",
	"threadguard_wrap": "This wearer's cards that already grant Block grant 1 more Block, to the card's actual recipient; a damage-only card that grants no Block gains no Block from it.",
	"red_bobbin_cuff": "This wearer's cards that already apply Bleed add 1 more Bleed; it never multiplies Hemorrhage Hem.",
	"loose_thread_glove": "This wearer's cards that already grant Unravel grant 1 more Unravel.",
	"frayfinder_mitt": "Once per player turn, this living wearer's first confirmed single-target attack hit of the player turn deals +2 attack damage before Weak/Exposed, but only if that enemy's Unravel was already at least 1/2 of its current threshold before the hit. Normal/elite/boss base thresholds 8/12/16, grow +4 per break. Never an Unravel gauge gain, not any area/multi-hit/later hit, and no bonus on a rejected play.",
	"switchback_button": "Once per player turn, when a different living hero's committed card or ordered stitched half immediately precedes this living, untorn wearer's committed card or half, the wearer gains +2 Block; each ordered stitched half counts for its real owner, and a failed, invalid or uncommitted play never sets or claims it.",
	"borrowed_button": "Once per combat, when a different living hero's committed card or ordered stitched half actually restores at least 1 HP to this living, untorn wearer, that wearer gains 3 Block; never from this wearer's own play, a heal that restores 0 HP, Rest mending or a failed play.",
}
## Catalog facts each literal line restates: slot, authored effect key, amount and
## the positive status or damage it may boost. The eight card bonuses are
## wearer-owned and positive-only, phrased with the human verb and amount a player
## reads; Frayfinder is the conditional first-hit +2 attack-damage bonus;
## Switchback Button is the once-per-player-turn +2 Block awarded to the wearer
## whose committed play follows a different living owner; Borrowed Button is the
## conditional other-hero heal Block award.
const M05_EXPECTED_FACTS := {
	"bloodstitch_bonnet": {"slot": "HEAD", "effect": "card_bleed_bonus", "amount": 1,
		"status": "Bleed", "verb": "apply", "bonus": "add 1 more Bleed"},
	"button_glass_visor": {"slot": "HEAD", "effect": "card_exposed_bonus", "amount": 1,
		"status": "Exposed", "verb": "apply", "bonus": "add 1 more Exposed"},
	"stern_seam_cap": {"slot": "HEAD", "effect": "card_weak_bonus", "amount": 1,
		"status": "Weak", "verb": "apply", "bonus": "add 1 more Weak"},
	"reinforced_browband": {"slot": "HEAD", "effect": "card_block_bonus", "amount": 2,
		"status": "Block", "verb": "grant", "bonus": "grant 2 more Block"},
	"hemguard_cuff": {"slot": "ARM", "effect": "card_block_bonus", "amount": 2,
		"status": "Block", "verb": "grant", "bonus": "grant 2 more Block"},
	"threadguard_wrap": {"slot": "ARM", "effect": "card_block_bonus", "amount": 1,
		"status": "Block", "verb": "grant", "bonus": "grant 1 more Block"},
	"red_bobbin_cuff": {"slot": "ARM", "effect": "card_bleed_bonus", "amount": 1,
		"status": "Bleed", "verb": "apply", "bonus": "add 1 more Bleed"},
	"loose_thread_glove": {"slot": "ARM", "effect": "card_unravel_bonus", "amount": 1,
		"status": "Unravel", "verb": "grant", "bonus": "grant 1 more Unravel"},
	"frayfinder_mitt": {"slot": "ARM", "effect": "first_single_target_half_unravel_attack_bonus",
		"amount": 2, "status": "attack damage", "timing": "before Weak/Exposed",
		"hit": "first confirmed single-target attack hit", "limit": "Once per player turn",
		"exclusions": "not any area/multi-hit/later hit", "numerator": 1, "denominator": 2},
	"switchback_button": {"slot": "HEAD", "effect": "different_owner_followup_block",
		"amount": 2, "status": "Block", "limit": "Once per player turn",
		"gate": "different living hero", "order": "immediately precedes",
		"owner_scope": "counts for its real owner", "refusal": "never sets or claims it"},
	"borrowed_button": {"slot": "COAT", "effect": "other_hero_committed_heal_block",
		"heal_threshold": 1, "block": 3, "uses_per_combat": 1},
}
## Internal implementation keys must never leak into a player-facing hover line.
const M05_INTERNAL_KEYS := ["Authored patch rule", "card_bleed_bonus", "card_block_bonus",
	"card_unravel_bonus", "card_exposed_bonus", "card_weak_bonus"]



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


func _buttons(meter: CombatActorMeter) -> HFlowContainer:
	return meter.get_node_or_null("Padding/Content/StatusButtons") as HFlowContainer


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


## Measured label widths of the pool's first `count` chips. The layout under test sets
## their text and font size, so these are the widths it has to wrap.
func _chip_widths(buttons: HFlowContainer, count: int) -> Array[float]:
	var widths: Array[float] = []
	for index in range(count):
		var button := buttons.get_child(index) as Button
		widths.append(button.get_minimum_size().x)
	return widths


func _widest(widths: Array[float]) -> float:
	var widest := 0.0
	for width in widths:
		widest = maxf(widest, width)
	return widest


## Independent wrap oracle: the rows a left-to-right flow needs for these measured chip
## widths inside `available` px, using the separations the mounted container really has.
## The test counts rows itself instead of asking the presenter for its own answer.
func _measured_rows(widths: Array[float], available: float, separation: float) -> int:
	var rows := 1
	var used := 0.0
	for width in widths:
		if used <= 0.0:
			used = width
		elif used + separation + width <= available + 0.001:
			used += separation + width
		else:
			rows += 1
			used = width
	return rows


## Distinct vertical bands the laid-out chips really occupy after a layout pass.
func _rendered_rows(chips: Array[Button]) -> int:
	var bands: Array[float] = []
	for chip in chips:
		var band := roundf(chip.position.y)
		if not bands.has(band):
			bands.append(band)
	return bands.size()


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
	for key in ["bleed", "weak", "exposed", "tangled", "riposte"]:
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
	if actor.hp == 0:
		chips.append("DOWNED" if side == "hero" else "SLAIN")
	var statuses: Dictionary = actor.get("statuses", {})
	for key in ["bleed", "weak", "exposed", "tangled", "riposte"]:
		var count: int = statuses.get(key, 0)
		if count > 0:
			chips.append("%s %d" % [String(key).capitalize(), count])
	if side == "enemy" and actor.hp > 0 and actor.get("thorns", 0) > 0:
		chips.append("Thorns %d" % actor["thorns"])
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


## Independent exact rule oracles for only the two new chips. Existing status chips
## retain the unchanged combined status/forecast/Bleed hover paragraphs.
func _expected_chip_tooltip(actor: Dictionary, side: String, forecast: Dictionary,
		chip: String) -> String:
	if chip.begins_with("Thorns "):
		var n: int = actor["thorns"]
		return "Thorns %d: Each confirmed positive-damage hit on this enemy deals %d damage back to its attacking hero, even if enemy Block absorbs that hit. Hero Block absorbs the retaliation before HP. Misses, failed plays, zero-damage attacks and previews do not retaliate." % [n, n]
	var full := _expected_tooltip(actor, side, forecast)
	if chip.begins_with("Tangled "):
		var n: int = actor["statuses"]["tangled"]
		return full + "\nTangled %d: Cannot move or be moved by its own side for %d remaining owner turns. Takes +2 attack damage from each positive-base attack after Weak/Exposed adjustment, once per attack (not per Tangled stack)." % [n, n]
	if chip.begins_with("Riposte "):
		var n: int = actor["statuses"]["riposte"]
		return full + "\nRiposte %d: Deals %d counterdamage on each confirmed hit while active. %d is damage per hit, not a turn count; Riposte expires completely at this actor's next owner-turn end." % [n, n, n]
	return full


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
		and content.find_children("StatusButtons", "HFlowContainer", false, false).size() == 1
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
	_check(buttons.get_child_count() == 6, "one reusable six-button pool: " + meter.name)
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
		_check(button.tooltip_text == _expected_chip_tooltip(actor, side, forecast, button.text),
			"exact independent hover text on '%s': %s" % [button.text, meter.name])
		# Every normal 1280x720 slot keeps the complete name at the readable size; the
		# flow may wrap, but it never narrows or truncates a mounted chip.
		_check(button.get_theme_font_size("font_size") >= READABLE_CHIP_FONT,
			"mounted chip keeps a %d px or larger font at this actor width: %s" % [
				READABLE_CHIP_FONT, meter.name])
		_check(not button.clip_text and button.get_minimum_size().x <= button.size.x + 0.5,
			"mounted chip renders its complete label inside its own width: %s min=%s size=%s" % [
				button.text, button.get_minimum_size(), button.size])
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
## complete name and count inside its own rendered width instead of being clipped, and
## the wrapped flow must never push a chip outside the ribbon that owns it.
func _assert_dense_chips(meter: CombatActorMeter, actor: Dictionary, side: String,
		expected: Array[String]) -> void:
	var shown := _visible_buttons(meter)
	var texts: Array[String] = []
	_check(shown.size() == expected.size(), "a fallen actor keeps every status chip: " + meter.name)
	for button in shown:
		texts.append(button.text)
		_check(not button.clip_text, "dense chip never clips its label: " + button.text)
		_check(button.get_theme_font_size("font_size") >= READABLE_CHIP_FONT,
			"dense chip keeps the readable %d px font: %s" % [READABLE_CHIP_FONT, button.text])
		_check(button.get_minimum_size().x <= button.size.x + 0.5,
			"dense chip renders its complete label inside its own width: " + button.text)
		_check(button.size.x > 0.0 and button.size.y > 0.0,
			"dense chip has a real rendered area: " + button.text)
		_check(button.mouse_filter == Control.MOUSE_FILTER_STOP
			and button.focus_mode == Control.FOCUS_NONE,
			"dense chip keeps its hover target and stays keyboard-inert: " + button.text)
	_check(texts == expected, "every dense chip keeps its name and count %s: %s" % [str(expected), meter.name])
	_check(texts == _expected_chips(actor, side), "dense chips mirror the authoritative stacks: " + meter.name)
	_check(not shown.is_empty() and shown[0].text in ["DOWNED", "SLAIN"],
		"the fallen cue is the first dense chip: " + meter.name)
	if shown.size() >= 2:
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
			and control.get_parent() is HFlowContainer and control.get_parent().name == "StatusButtons",
			"status rules live only on a visible chip, never a duplicate stage control")
	var expected_carriers := 0
	for meter in _meters(app):
		for chip in _visible_buttons(meter):
			if chip.tooltip_text.contains("Statuses:"):
				expected_carriers += 1
	_check(carriers == expected_carriers,
		"only real mounted status chips carry tooltips, with no neutral or duplicate controls")


## Every visible chip of every mounted ribbon stays wholly inside its own ribbon, keeps
## a real pointer target, and never crosses the shared hand, the action buttons or
## another actor's ribbon - whether the flow used one row or wrapped onto more.
func _assert_chip_geometry(app) -> void:
	var meters := _meters(app)
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	for meter in meters:
		var ribbon := meter.get_global_rect()
		var chips := _visible_buttons(meter)
		for chip in chips:
			var rect := chip.get_global_rect()
			_check(rect.has_area() and viewport.encloses(rect),
				"status chip stays inside the window: %s/%s" % [meter.name, chip.text])
			_check(ribbon.grow(1.0).encloses(rect),
				"status chip stays inside its own actor ribbon: %s/%s" % [meter.name, chip.text])
			_check(chip.mouse_filter == Control.MOUSE_FILTER_STOP
				and chip.get_minimum_size().x <= chip.size.x + 0.5
				and chip.get_minimum_size().y <= chip.size.y + 0.5,
				"status chip keeps a complete hover target at its rendered size: %s" % chip.text)
			_check(not rect.intersects(app.hand_view.get_global_rect())
				and not rect.intersects(app.end_turn_button.get_global_rect())
				and not rect.intersects(app.return_button.get_global_rect()),
				"status chip never covers the shared hand or the action buttons: " + chip.text)
			for other in meters:
				if other == meter:
					continue
				_check(not rect.intersects(other.get_global_rect()),
					"status chip never spills into another actor's ribbon: %s/%s" % [meter.name, chip.text])
		for index in range(chips.size()):
			for other in range(index):
				_check(not chips[index].get_global_rect().intersects(chips[other].get_global_rect()),
					"separate status chips never overlap each other: " + meter.name)


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
	_assert_chip_geometry(app)


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
	_check(control_ids.size() == 6 and not buttons.visible and _visible_buttons(meter).is_empty(),
		"authentic opening has a collapsed status row and six dormant buttons")
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
		_check(actual_ids == control_ids and buttons.get_child_count() == 6
			and meter == _meters(app)[3], "status refresh reuses six original chips and mounted meter")
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


## New V3-2 counters are supplied by authoritative roster slots, not by a
## not-yet-wired card cast or by editing a presenter-only dictionary.
func _exercise_new_status_ribbons(app, presenter) -> void:
	var meters := _meters(app)
	_check(meters.size() == 5 and app.party.get_hero(2)["hp"] > 0
		and app.enemies.get_enemy(1)["hp"] > 0,
		"V3-2 ribbon case starts with mounted living hero and enemy authorities")
	if meters.size() != 5 or app.party.get_hero(2)["hp"] <= 0 or app.enemies.get_enemy(1)["hp"] <= 0:
		return
	var original_heroes: Array[Dictionary] = app.party.get_heroes()
	var original_enemies: Array[Dictionary] = app.enemies.get_enemies()
	var before := _state(app)
	var hero_ids: Array[int] = []
	var enemy_ids: Array[int] = []
	for child in _buttons(meters[1]).get_children():
		hero_ids.append(child.get_instance_id())
	for child in _buttons(meters[3]).get_children():
		enemy_ids.append(child.get_instance_id())
	_check(hero_ids.size() == 6 and enemy_ids.size() == 6,
		"both real status rows reserve six stable actionless controls")
	app.party._heroes[1]["statuses"] = {"tangled": 2, "riposte": 3}
	app.enemies._enemies[0]["statuses"] = {"bleed": 2, "weak": 1, "exposed": 2,
		"tangled": 2, "riposte": 3}
	app.enemies._enemies[0]["thorns"] = 2
	var hero: Dictionary = app.party.get_hero(2)
	var enemy: Dictionary = app.enemies.get_enemy(1)
	_check(hero["statuses"] == {"tangled": 2, "riposte": 3}
		and enemy["statuses"].size() == 5 and enemy["thorns"] == 2,
		"living hero/enemy reader snapshots really own the new positive counters")
	var model := _state(app)
	seed(82913)
	var global_next := randi()
	seed(82913)
	for iteration in range(3):
		presenter._sync_battle()
		await _frames()
	_visible(app)
	_check(_state(app) == model and randi() == global_next,
		"V3-2 mounted refresh leaves all combat, status, intent, deck and both RNG ledgers intact")
	var shown_hero := _visible_buttons(meters[1])
	var shown_enemy := _visible_buttons(meters[3])
	_check(shown_hero.size() == 2 and _expected_chips(hero, "hero") == ["Tangled 2", "Riposte 3"]
		and shown_enemy.size() == 6
		and _expected_chips(enemy, "enemy") == ["Bleed 2", "Weak 1", "Exposed 2",
			"Tangled 2", "Riposte 3", "Thorns 2"],
		"source-specific living ribbons hold two and six correctly ordered positive chips")
	for index in [0, 2, 4]:
		_check(_visible_buttons(meters[index]).is_empty(),
			"unaffected actor never inherits hero/enemy Tangled or Riposte")
	for details in [{"buttons": shown_hero, "actor": hero, "side": "hero"},
			{"buttons": shown_enemy, "actor": enemy, "side": "enemy"}]:
		var actor: Dictionary = details["actor"]
		var side: String = details["side"]
		for chip in details["buttons"]:
			var button := chip as Button
			await _hover(button)
			_check(root.gui_get_hovered_control() == button and button.focus_mode == Control.FOCUS_NONE
				and button.pressed.get_connections().is_empty()
				and button.tooltip_text == _expected_chip_tooltip(actor, side, _forecast(app), button.text),
				"actual %s '%s' hover matches the independent complete rule oracle" % [side, button.text])
	var flow := _buttons(meters[3])
	var dense_rows := _rendered_rows(shown_enemy)
	var measured_rows := _measured_rows(_chip_widths(flow, shown_enemy.size()),
		flow.size.x, float(flow.get_theme_constant("h_separation")))
	var chip_height := shown_enemy[0].size.y if shown_enemy.size() == 6 else 0.0
	var row_gap := float(flow.get_theme_constant("v_separation"))
	_check(dense_rows >= 2 and dense_rows == measured_rows
		and is_equal_approx(flow.custom_minimum_size.y,
			dense_rows * chip_height + row_gap * float(dense_rows - 1))
		and presenter.row.custom_minimum_size.y >= meters[3].get_combined_minimum_size().y,
		"all six live dense chips wrap into precisely reserved, legible rows")
	# The pure accepted owner-turn rules project status expiry on copied snapshots.
	# Fixture-owned authority adopts those results; no unwired combat hook is invented.
	var hero_tick := CombatStatuses.new().end_owner_turn(
		hero["hp"], hero["block"], hero["statuses"].duplicate(true))
	var enemy_tick := CombatStatuses.new().end_owner_turn(
		enemy["hp"], enemy["block"], enemy["statuses"].duplicate(true))
	_check(hero_tick["ok"] and enemy_tick["ok"]
		and hero_tick["statuses"] == {"tangled": 1}
		and enemy_tick["statuses"] == {"bleed": 1, "exposed": 1, "tangled": 1}
		and enemy_tick["hp"] == enemy["hp"] - 2,
		"copied owner-turn rule expires Riposte fully, decrements Tangled, and keeps Bleed damage")
	if not hero_tick["ok"] or not enemy_tick["ok"]:
		return
	app.party._heroes[1]["statuses"] = hero_tick["statuses"].duplicate(true)
	app.enemies._enemies[0]["statuses"] = enemy_tick["statuses"].duplicate(true)
	app.enemies._enemies[0]["hp"] = enemy_tick["hp"]
	presenter._sync_battle()
	await _frames()
	_visible(app)
	_check(_expected_chips(app.party.get_hero(2), "hero") == ["Tangled 1"]
		and _visible_buttons(meters[1]).size() == 1
		and _visible_buttons(meters[1])[0].text == "Tangled 1"
		and _expected_chips(app.enemies.get_enemy(1), "enemy")
			== ["Bleed 1", "Exposed 1", "Tangled 1", "Thorns 2"]
		and _visible_buttons(meters[3]).size() == 4
		and _visible_buttons(meters[3])[2].text == "Tangled 1",
		"owner-turn expiry clears Riposte completely without counting N turns and decrements Tangled")
	# The maximum fallen case has six chips too: the fallen cue replaces Thorns.
	var lethal_amount: int = app.enemies.get_enemy(1)["hp"] + app.enemies.get_enemy(1)["block"]
	_check(app.enemies.apply_damage(1, lethal_amount),
		"real combat authority slays the displayed enemy without fabricating a presenter death")
	app.enemies._enemies[0]["statuses"] = {"bleed": 1, "weak": 1, "exposed": 1,
		"tangled": 2, "riposte": 3}
	presenter._sync_battle()
	await _frames()
	_visible(app)
	var dead: Dictionary = app.enemies.get_enemy(1)
	_assert_dense_chips(meters[3], dead, "enemy",
		["SLAIN", "Bleed 1", "Weak 1", "Exposed 1", "Tangled 2", "Riposte 3"])
	_check(_visible_buttons(meters[3]).size() == 6
		and not _expected_chips(dead, "enemy").has("Thorns 2")
		and not meters[3].bleed_warning.visible,
		"fallen source retains all five timed/status counts without a live Thorns chip")
	# Malformed counts are rejected by the actual mounted meter; the next live
	# refresh must recover solely from its valid authoritative roster snapshot.
	var invalid_source: Dictionary = app.party.get_hero(2)
	invalid_source["statuses"] = {"tangled": -1, "riposte": 3}
	var model_before_reject := _state(app)
	_check(not meters[1].show_actor(invalid_source, "hero")
		and not meters[1].visible and meters[1].status_text.text.is_empty(),
		"negative Tangled fails closed and clears even an already mounted status label")
	presenter._sync_battle()
	await _frames()
	_check(_state(app) == model_before_reject and meters[1].visible
		and meters[1].status_text.text == "Statuses: Tangled 1",
		"live refresh restores valid actor-only statuses without persisting malformed input")
	# A present zero is just as inactive as an absent counter.
	app.party._heroes[1]["statuses"] = {"tangled": 0, "riposte": 0}
	app.enemies._enemies[0]["statuses"] = {"tangled": 0, "riposte": 0}
	presenter._sync_battle()
	await _frames()
	_visible(app)
	_check(_visible_buttons(meters[1]).is_empty()
		and _visible_buttons(meters[3]).size() == 1
		and _visible_buttons(meters[3])[0].text == "SLAIN",
		"zero-valued Tangled and Riposte produce no ghost chips on either side")
	# Complete expiration removes labels AND tooltips, including the dormant pool.
	app.party._heroes[1].erase("statuses")
	app.enemies._enemies[0].erase("statuses")
	app.enemies._enemies[0]["thorns"] = 0
	presenter._sync_battle()
	await _frames()
	_visible(app)
	_check(_visible_buttons(meters[1]).is_empty() and not _buttons(meters[1]).visible
		and _visible_buttons(meters[3]).size() == 1
		and _visible_buttons(meters[3])[0].text == "SLAIN",
		"expired living stacks and dead stacks vanish, retaining only fallen state")
	for meter in [meters[1], meters[3]]:
		for button in _buttons(meter).get_children():
			if not button.visible:
				_check(button.tooltip_text.is_empty() and button.text.is_empty(),
					"expired V3-2 chip has neither orphan tooltip nor stale count")
	for index in range(3):
		app.party._heroes[index] = original_heroes[index].duplicate(true)
	for index in range(original_enemies.size()):
		app.enemies._enemies[index] = original_enemies[index].duplicate(true)
	presenter._sync_battle()
	await _frames()
	_visible(app)
	var final_hero_ids: Array[int] = []
	var final_enemy_ids: Array[int] = []
	for child in _buttons(meters[1]).get_children():
		final_hero_ids.append(child.get_instance_id())
	for child in _buttons(meters[3]).get_children():
		final_enemy_ids.append(child.get_instance_id())
	_check(_state(app) == before and hero_ids == final_hero_ids and enemy_ids == final_enemy_ids
		and _visible_buttons(meters[1]).is_empty() and _visible_buttons(meters[3]).is_empty(),
		"V3-2 fixture restores exact original state, original six controls and empty rows")


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
		await _frames() # FlowContainer applies changed chip widths on its layout pass.
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
	_assert_dense_chips(meters[3], dense, "enemy", ["SLAIN", "Bleed 3", "Weak 1", "Exposed 2"])
	var dense_chips := _visible_buttons(meters[3])
	if dense_chips.size() == 4:
		await _hover(dense_chips[3])
		_check(root.gui_get_hovered_control() == dense_chips[3]
			and dense_chips[3].tooltip_text == _expected_tooltip(dense, "enemy", _forecast(app))
			and dense_chips[3].tooltip_text == "Statuses: Bleed 3 · Weak 1 · Exposed 2",
			"hovering the dense fallen chip exposes the full status names")
	# Width-aware flow: the same four complete chips reflow inside a narrow slot instead
	# of shrinking or clipping, and the ribbon reserves exactly the rows it uses.
	await _assert_wrapped_chips(app, presenter, meters[3], dense)
	# Restore the identical authoritative session so the existing attack/replay
	# assertions still run on the authored opening state, not synthetic combat.
	for index in range(3):
		app.party._heroes[index] = original_heroes[index].duplicate(true)
	for index in range(2):
		app.enemies._enemies[index] = original_enemies[index].duplicate(true)
	presenter._sync_battle()
	await _frames()
	_visible(app)
	_check(_state(app) == before and incoming_before != [],
		"live status probe restores complete authored combat, intents, deck and RNG")
	for index in range(5):
		_check(meters[index].bleed_warning.text.is_empty()
			and not meters[index].bleed_warning.visible
			and meters[index].modifier_explanation.text.is_empty()
			and not meters[index].modifier_explanation.visible,
			"clearing real statuses immediately hides every old warning")


## The width-aware chip flow of one mounted ribbon. The complete fallen/chip set keeps
## its 14 px names at the real actor width, wraps onto as many rows as its own measured
## chip widths need while reserving exactly that height, stays unclipped with a real
## hover target, and only a slot below the ribbon's own 84 px floor may fall back to the
## compact name. The test counts the rows itself from the measured chips; a second
## readable row at a dense actor width is valid, so nothing here demands one row.
func _assert_wrapped_chips(app, presenter, meter: CombatActorMeter, actor: Dictionary) -> void:
	var buttons := _buttons(meter)
	var before := _state(app)
	var expected := _expected_chips(actor, "enemy")
	var entries: Array[Dictionary] = []
	entries.append({"kind": "fallen", "full": expected[0], "short": expected[0]})
	var statuses: Dictionary = actor.get("statuses", {})
	for key in ["bleed", "weak", "exposed"]:
		entries.append({"kind": key,
			"full": "%s %d" % [String(key).capitalize(), statuses[key]],
			"short": "%s %d" % [String(key).capitalize().substr(0, 3), statuses[key]]})
	var wide: Dictionary = presenter._layout_chips(buttons, entries, 200.0)
	var h_separation := float(buttons.get_theme_constant("h_separation"))
	var row_gap := float(buttons.get_theme_constant("v_separation"))
	var wide_available: float = 200.0 - presenter.RIBBON_SLOT_INSET
	var wide_widths := _chip_widths(buttons, entries.size())
	var wide_widest := _widest(wide_widths)
	var wide_rows := _measured_rows(wide_widths, wide_available, h_separation)
	_check(wide["font_size"] >= READABLE_CHIP_FONT and wide["compact"] == false
		and wide["texts"] == expected and wide_widest > 0.0
		and wide_widest <= wide_available + 0.5
		and wide_rows >= 1 and wide_rows <= entries.size(),
		"the normal actor width keeps all four complete names at the readable size")
	_check(wide["rows"] == wide_rows
		and is_equal_approx(wide["height"],
			wide_rows * wide["chip_height"] + row_gap * float(wide_rows - 1))
		and wide["height"] >= wide_rows * wide["chip_height"],
		"the normal-width flow wraps exactly the rows its measured chips need and reserves them")
	var narrow: Dictionary = presenter._layout_chips(buttons, entries, 96.0)
	var narrow_available: float = 96.0 - presenter.RIBBON_SLOT_INSET
	var narrow_rows := _measured_rows(_chip_widths(buttons, entries.size()), narrow_available,
		h_separation)
	_check(narrow["font_size"] >= READABLE_CHIP_FONT and narrow["compact"] == false
		and narrow["texts"] == expected and narrow["rows"] == narrow_rows and narrow_rows >= 2
		and is_equal_approx(narrow["height"],
			narrow_rows * narrow["chip_height"] + row_gap * float(narrow_rows - 1))
		and narrow["height"] > narrow["chip_height"],
		"a narrow actor slot wraps the same complete chips onto further readable rows")
	# The presenter itself applies that layout: complete labels, 14 px, measured to fit.
	presenter._sync_status_buttons(meter, actor, "enemy", null, 96.0)
	_check(buttons.custom_minimum_size.y == narrow["height"]
		and buttons.custom_minimum_size.y > narrow["chip_height"],
		"the wrapped ribbon reserves the extra rows it really uses")
	var texts: Array[String] = []
	var widest := 0.0
	for button in _visible_buttons(meter):
		texts.append(button.text)
		widest = maxf(widest, button.get_minimum_size().x)
		_check(not button.clip_text
			and button.get_theme_font_size("font_size") >= READABLE_CHIP_FONT
			and button.get_minimum_size().x <= 96.0 - 4.0 + 0.5
			and button.mouse_filter == Control.MOUSE_FILTER_STOP
			and button.tooltip_text.contains("Statuses:"),
			"a wrapped chip keeps its complete text, readable font and hover target: " + button.text)
	_check(texts == expected and widest > 0.0 and widest <= 92.0,
		"every wrapped chip is measured inside the narrow slot, never clipped")
	# The narrowest slot the real stage can produce still keeps complete 14 px names.
	var floor_layout: Dictionary = presenter._layout_chips(buttons, entries,
		presenter.RIBBON_MIN_WIDTH)
	_check(floor_layout["font_size"] >= READABLE_CHIP_FONT and not floor_layout["compact"]
		and floor_layout["texts"] == expected and floor_layout["rows"] >= 2,
		"even the narrowest real ribbon keeps the complete names at 14 px by wrapping")
	# Below that floor the compact fallback keeps a complete count on every chip.
	var tiny: Dictionary = presenter._layout_chips(buttons, entries, 40.0)
	_check(tiny["compact"] and tiny["font_size"] >= 11 and tiny["rows"] == 4
		and tiny["texts"] == ["SLAIN", "Ble 3", "Wea 1", "Exp 2"],
		"below the ribbon floor the compact fallback keeps every count, never a blank chip")
	presenter._sync_battle()
	await _frames()
	_visible(app)
	var restored := _visible_buttons(meter)
	var restored_texts: Array[String] = []
	for button in restored:
		restored_texts.append(button.text)
	var restored_rows := _rendered_rows(restored)
	var restored_chip_height := restored[0].size.y if restored.size() == entries.size() else 0.0
	var restored_height := restored_chip_height * float(restored_rows) \
		+ row_gap * float(restored_rows - 1)
	var restored_measured := _measured_rows(_chip_widths(buttons, entries.size()),
		buttons.size.x, h_separation)
	_check(_state(app) == before and restored.size() == 4 and restored_texts == expected,
		"the narrow probe restores the real-width chips without spending or mutating combat")
	_check(restored_rows >= 1 and restored_rows == restored_measured
		and is_equal_approx(buttons.custom_minimum_size.y, restored_height)
		and buttons.size.y >= restored_height - 0.5,
		"the restored real-width flow wraps its measured rows and reserves exactly that height")
	# Each restored chip stays a distinct hover target inside its own ribbon, inside the
	# window and clear of the shared hand, the action buttons and its sibling chips.
	for chip in restored:
		await _hover(chip)
		_check(root.gui_get_hovered_control() == chip
			and chip.tooltip_text == _expected_tooltip(actor, "enemy", _forecast(app)),
			"each restored chip is its own hover target with the full rules: " + chip.text)
		_check(meter.get_global_rect().grow(1.0).encloses(chip.get_global_rect())
			and buttons.get_global_rect().grow(1.0).encloses(chip.get_global_rect())
			and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(chip.get_global_rect())
			and not chip.get_global_rect().intersects(app.hand_view.get_global_rect())
			and not chip.get_global_rect().intersects(app.end_turn_button.get_global_rect())
			and not chip.get_global_rect().intersects(app.return_button.get_global_rect()),
			"restored chip stays inside its ribbon and clear of the shared hand: " + chip.text)
	for index in range(restored.size()):
		for other in range(index):
			_check(not restored[index].get_global_rect().intersects(
				restored[other].get_global_rect()),
				"restored wrapped chips never overlap each other: " + restored[index].text)
	# Exercise wrapping through the genuine mounted refresh too: larger valid counts
	# require extra rows at the actual actor width without substituting a test presenter.
	# Two readable rows are the correct outcome here, so the check measures the rendered
	# bands and requires the ribbon to reserve exactly those rows.
	var position: int = actor["position"]
	_check(app.enemies.apply_statuses({position: {"bleed": 12345, "weak": 12345,
		"exposed": 12345}}), "real status API supplies a non-vacuous mounted wrap case")
	var wrapped_state := _state(app)
	await _frames()
	_visible(app)
	var wrapped := _visible_buttons(meter)
	var wrapped_rows := _rendered_rows(wrapped)
	var wrapped_chip_height := wrapped[0].size.y if wrapped.size() == 4 else 0.0
	var wrapped_height := wrapped_chip_height * float(wrapped_rows) \
		+ row_gap * float(wrapped_rows - 1)
	_check(wrapped.size() == 4 and wrapped_rows >= 2
		and wrapped_rows == _measured_rows(_chip_widths(buttons, entries.size()),
			buttons.size.x, h_separation)
		and is_equal_approx(buttons.custom_minimum_size.y, wrapped_height)
		and buttons.size.y >= wrapped_height - 0.5
		and presenter.row.custom_minimum_size.y >= meter.get_combined_minimum_size().y,
		"actual slot width wraps all four mounted chips onto its measured rows and reserves them")
	for chip in wrapped:
		await _hover(chip)
		_check(root.gui_get_hovered_control() == chip
			and chip.tooltip_text == _expected_tooltip(app.enemies.get_enemy(position), "enemy", _forecast(app)),
			"every mounted wrapped chip retains its complete hover tooltip: " + chip.text)
	_check(_state(app) == wrapped_state, "mounted wrap and hover preserve combat, deck and RNG")
	app.enemies._enemies[position - 1] = actor.duplicate(true)
	await _frames()
	_visible(app)
	_check(_state(app) == before, "mounted wrap fixture restores the identical authoritative state")


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
		await _exercise_new_status_ribbons(app, presenter)
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
		_assert_dense_chips(_meters(app)[1], downed, "hero", ["DOWNED", "Bleed 3", "Weak 1", "Exposed 2"])
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
		# Rebind while both original authorities STILL contain new status counts:
		# replacing a party must clear its old hero chips, replacing enemies must
		# clear the old enemy chips, and no new source may inherit their tooltips.
		app.party._heroes[1]["statuses"] = {"tangled": 2, "riposte": 3}
		app.enemies._enemies[0]["statuses"] = {"tangled": 2, "riposte": 3}
		await _frames()
		_visible(app)
		_check(_expected_chips(app.party.get_hero(2), "hero")
			== ["DOWNED", "Tangled 2", "Riposte 3"]
			and _expected_chips(app.enemies.get_enemy(1), "enemy")
			== ["SLAIN", "Tangled 2", "Riposte 3"],
			"stale-rebind starts with genuine hero and enemy V3-2 status-bearing authorities")
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
			if source == "party":
				_check(_visible_buttons(_meters(app)[1]).is_empty()
					and _visible_buttons(_meters(app)[3]).size() == 3,
					"party replacement drops Tangled/Riposte hero chips, preserving still-owned enemy counters")
			elif source == "enemies":
				_check(_visible_buttons(_meters(app)[1]).is_empty()
					and _visible_buttons(_meters(app)[3]).is_empty(),
					"enemy replacement cannot inherit old Tangled/Riposte counts or hover tooltips")
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
	await _switchback_threadguard_ribbons_test(app, presenter)
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
		and roster._badges[0].icon_mode == "attack" and roster._badges[0].readable_text.begins_with("Hit "),
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
	_assert_dense_chips(_meters(app)[4], fallen, "enemy", ["SLAIN", "Bleed 3", "Weak 1", "Exposed 2"])
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


## Independent wording oracle for the mounted hero threat tag: grammatical, exact, and
## deliberately not produced by the presenter under test.
func _expected_threat_text(count: int) -> String:
	if count <= 0:
		return ""
	return THREAT_BADGE_ONE if count == 1 else THREAT_BADGE_MANY % count


## WCAG relative luminance, used only to prove the felt tag keeps readable ink/thread.
func _relative_luminance(color: Color) -> float:
	var channels: Array[float] = []
	for value in [color.r, color.g, color.b]:
		channels.append(value / 12.92 if value <= 0.03928
			else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


func _contrast_ratio(first: Color, second: Color) -> float:
	var high := maxf(_relative_luminance(first), _relative_luminance(second))
	var low := minf(_relative_luminance(first), _relative_luminance(second))
	return (high + 0.05) / (low + 0.05)


## One legible sewn threat tag on the hero's own HP trough. The tag is what the player
## reads instead of a cryptic "! N", so this asserts its exact grammatical text, its
## minimum type size, the pale-on-dark felt with a stitched border, its pointer/keyboard
## inertness, and that the complete word fits without covering the centred HP numerals.
func _assert_threat_tag(meter: CombatActorMeter, count: int) -> void:
	var pin := meter.hp_bar.get_node_or_null("ThreatPin") as Panel
	_check(pin != null and meter.hp_bar.find_children("ThreatPin", "Panel", false, false).size() == 1,
		"hero ribbon mounts exactly one threat tag on its HP trough: " + meter.name)
	if pin == null:
		return
	var label := pin.get_node_or_null("Count") as Label
	_check(label != null, "threat tag owns one Count label: " + meter.name)
	if label == null:
		return
	var expected := _expected_threat_text(count)
	_check(pin.visible == (count > 0) and pin.is_visible_in_tree() == (count > 0)
		and label.text == expected,
		"threat tag reads '%s' for %d announced source(s): %s" % [
			expected, count, meter.name])
	_check(label.get_theme_font_size("font_size") >= THREAT_BADGE_FONT
		and label.get_combined_minimum_size().x > 0.0
		and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER,
		"threat wording is centred at %d px or larger: %s" % [THREAT_BADGE_FONT, meter.name])
	_check(pin.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and pin.focus_mode == Control.FOCUS_NONE
		and label.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and label.focus_mode == Control.FOCUS_NONE
		and pin.gui_input.get_connections().is_empty()
		and pin.tooltip_text.is_empty() and label.tooltip_text.is_empty(),
		"threat tag stays pointer/focus inert and claims no action or hover: " + meter.name)
	if count <= 0:
		return
	var felt := pin.get_theme_stylebox("panel") as StyleBoxFlat
	_check(felt != null and felt.get_border_width(SIDE_LEFT) >= 2
		and felt.get_corner_radius(CORNER_TOP_LEFT) >= 2,
		"threat tag draws a sewn felt tag with a stitched border: " + meter.name)
	if felt == null:
		return
	var ink := label.get_theme_color("font_color")
	_check(_contrast_ratio(ink, felt.bg_color) >= 4.5
		and _contrast_ratio(felt.border_color, felt.bg_color) >= 3.0,
		"threat tag keeps pale ink on dark felt with a visible stitched edge: " + meter.name)
	_check(label.get_combined_minimum_size().x <= label.size.x + 0.5
		and label.get_combined_minimum_size().y <= label.size.y + 0.5
		and Rect2(Vector2.ZERO, meter.hp_bar.size).grow(0.5).encloses(
			Rect2(pin.position, pin.size)),
		"the complete threat word fits its tag inside the HP trough: " + meter.name)
	# The numerals are centred across the whole trough, so the tag's left edge must stay
	# beyond the measured numeral box rather than painting over the HP value.
	var numerals_end := (meter.hp_bar.size.x + meter.hp_text.get_combined_minimum_size().x) * 0.5
	_check(pin.position.x >= numerals_end,
		"threat tag leaves the centred HP value uncovered: " + meter.name)


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
		var badge_ids: Array[int] = []
		for read in range(3):
			presenter._sync_battle()
			var meters := _meters(app)
			for position in range(1, 4):
				var meter := meters[position - 1]
				var badge := meter.hp_bar.get_node_or_null("ThreatPin/Count")
				_check(badge != null, "mounted hero threat tag exists: " + meter.name)
				if badge == null:
					continue
				if read == 0:
					badge_ids.append(badge.get_instance_id())
				else:
					_check(badge.get_instance_id() == badge_ids[position - 1],
						"read %d reuses the same threat tag for hero slot %d" % [read, position])
				_assert_threat_tag(meter, expected[position - 1])
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
			_assert_threat_tag(fallen_pins[0], 0)
			_assert_threat_tag(fallen_pins[1], 2)
			_check(not fallen_pins[0].hp_bar.get_node("ThreatPin").visible
				and fallen_pins[1].hp_bar.get_node("ThreatPin/Count").text == "2 FOES"
				and fallen_pins[1].hp_bar.get_node("ThreatPin").visible,
				"both policies use deterministic front fallback on living H2 with no RNG reroll")
			_check(schedule.get_intents() == cached and app.run_rng.state == rng_before,
				"downed announced target does not replace original cache or consume run RNG")
			app.party._heroes.assign(old_party.duplicate(true))
			presenter._sync_battle()
			_assert_threat_tag(_meters(app)[0], 2)
			_check(_meters(app)[0].hp_bar.get_node("ThreatPin/Count").text == "2 FOES",
				"restored first hero recovers the two-source warning")
		if case_index == 0:
			_check(expected == [1, 0, 0], "one attack pins one hero; block and buff never count")
			var skip := CombatUnravel.new()
			_check(skip.bind_roster(app.enemies, {1: "normal", 2: "normal", 3: "normal"})
				and skip.apply_unravel(app.enemies, 1, 8), "real Unravel service queues a source skip")
			flow._unravel = skip
			presenter._sync_battle()
			_assert_threat_tag(_meters(app)[0], 0)
			_check(_meters(app)[0].hp_bar.get_node("ThreatPin").visible == false,
				"pending skip removes its only threat")
			flow._unravel = old_unravel
			_check(app.enemies.apply_damage(1, 999), "test kills its only attacking source")
			presenter._sync_battle()
			_assert_threat_tag(_meters(app)[0], 0)
			_check(not _meters(app)[0].hp_bar.get_node("ThreatPin").visible,
				"slain attacker cannot contribute threats")
			app.enemies._enemies.assign(old_roster.duplicate(true))
			presenter._sync_battle()
			_assert_threat_tag(_meters(app)[0], 1)
			_check(_meters(app)[0].hp_bar.get_node("ThreatPin").visible,
				"restoring source restores its announced threat")
			# A closed fight and missing/mismatched scheduler both fail closed.
			app._battle_closed = true
			presenter._sync_battle()
			_assert_threat_tag(_meters(app)[0], 0)
			_check(not _meters(app)[0].hp_bar.get_node("ThreatPin").visible,
				"closed fight clears pending warning while ribbon exists")
			app._battle_closed = false
			app.enemy_intents = null
			presenter._sync_battle()
			_assert_threat_tag(_meters(app)[0], 0)
			_check(not _meters(app)[0].hp_bar.get_node("ThreatPin").visible,
				"missing intent authority hides stale target pin")
			app.enemy_intents = schedule
			var foreign := CombatEnemyIntents.new(patterns)
			app.enemy_intents = foreign
			presenter._sync_battle()
			_assert_threat_tag(_meters(app)[0], 0)
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


## The authored catalog record for one bounded M05 HEAD/ARM/COAT ID, plus the shared
## M04 attack catalog where Switchback Button ships; looked up by ID presence so
## growing catalogs never invalidate this check.
func _m05_catalog_entry(patch_id: String) -> Dictionary:
	for path in ["res://data/patches/m04_attack_patches.json",
			"res://data/patches/m05_head_patches.json",
			"res://data/patches/m05_arm_support_patches.json",
			"res://data/patches/m05_attack_patches.json",
			"res://data/patches/m05_coat_patches.json"]:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if raw is Array:
			for entry in raw:
				if entry is Dictionary and entry.get("id") == patch_id:
					return entry
	return {}


## Re-derive one M05 rule independently of the presenter: player language with no
## internal effect key or preamble, exact catalog amount and effect family, the
## positive status, wearer-owned cards, the real Block recipient, Red Bobbin versus
## Hemorrhage Hem, Frayfinder's +2 attack-damage first single-target hit /
## half-threshold / once-per-player-turn limit, Switchback Button's ordered
## different-owner follow-up award, and Borrowed Button's other-hero positive-heal
## 3-Block rule.
func _assert_m05_rule_terms(patch_id: String, line: String) -> void:
	var facts: Dictionary = M05_EXPECTED_FACTS[patch_id]
	var entry := _m05_catalog_entry(patch_id)
	for token in M05_INTERNAL_KEYS:
		_check(not line.contains(String(token)),
			"the %s line uses player language, never %s: %s" % [patch_id, token, line])
	if patch_id == "switchback_button":
		_check(not entry.is_empty() and entry.get("slot") == facts["slot"]
			and entry.get("effect") == facts["effect"]
			and int(entry.get("amount", -1)) == int(facts["amount"])
			and entry.get("once_per_player_turn") == true,
			"authored catalog agrees with the expected Switchback Button HEAD +2 once-per-player-turn rule")
		_check(line.contains(String(facts["limit"])),
			"Switchback Button states its once-per-player-turn limit: " + line)
		_check(line.contains(String(facts["gate"])) and line.contains("committed card"),
			"Switchback Button requires a different living hero's committed play: " + line)
		_check(line.contains(String(facts["order"])),
			"Switchback Button requires the immediately preceding committed play: " + line)
		_check(line.contains("ordered stitched half")
			and line.contains(String(facts["owner_scope"])),
			"Switchback Button counts ordered stitched halves by their real owner: " + line)
		_check(line.contains("+%d Block" % int(facts["amount"])),
			"Switchback Button awards its authored +2 Block: " + line)
		_check(line.contains("living, untorn wearer"),
			"Switchback Button requires the living, untorn wearer: " + line)
		_check(line.contains(String(facts["refusal"]))
			and line.contains("failed, invalid or uncommitted play"),
			"Switchback Button never arms itself from a failed, invalid or uncommitted play: " + line)
		_check(not line.contains("all living heroes") and not line.contains("draw")
			and not line.contains("+3 Block"),
			"Switchback Button is never described as the separate Quilt reward: " + line)
		return
	if patch_id == "borrowed_button":
		_check(not entry.is_empty() and entry.get("slot") == facts["slot"]
			and entry.get("effect") == facts["effect"]
			and int(entry.get("heal_threshold", 0)) == int(facts["heal_threshold"])
			and int(entry.get("block", 0)) == int(facts["block"])
			and int(entry.get("uses_per_combat", 0)) == int(facts["uses_per_combat"]),
			"authored catalog agrees with the expected Borrowed Button rule: %s" % patch_id)
		_check(line.contains("Once per combat") and facts["uses_per_combat"] == 1,
			"Borrowed Button states its once-per-combat limit: " + line)
		_check(line.contains("different living hero")
			and entry.get("effect") == "other_hero_committed_heal_block",
			"Borrowed Button restricts healer to a different living hero: " + line)
		_check(line.contains("committed card or ordered stitched half"),
			"Borrowed Button specifies committed card or ordered stitched half: " + line)
		_check(line.contains("restores at least %d HP" % facts["heal_threshold"]),
			"Borrowed Button requires restoring at least 1 HP: " + line)
		_check(line.contains("living, untorn wearer"),
			"Borrowed Button specifies the living, untorn wearer recipient: " + line)
		_check(line.contains("that wearer gains %d Block" % facts["block"]),
			"Borrowed Button awards 3 Block to the wearer: " + line)
		_check(line.contains("this wearer's own play") and line.contains("restores 0 HP"),
			"Borrowed Button excludes a self-heal and a zero-HP heal: " + line)
		_check(line.contains("Rest mending") and line.contains("failed play"),
			"Borrowed Button excludes Rest mending and a failed play: " + line)
		_check(not line.contains("maximum HP") and not line.contains("+max-HP")
			and not line.contains("effective maximum HP") and not line.contains("free healing"),
			"Borrowed Button never invents a maximum HP bonus: " + line)
		return
	_check(not entry.is_empty() and entry.get("slot") == facts["slot"]
		and entry.get("effect") == facts["effect"]
		and int(entry.get("amount", -1)) == int(facts["amount"]),
		"authored catalog agrees with the expected %s %s +%d rule: %s" % [
			facts["slot"], facts["effect"], facts["amount"], patch_id])
	if patch_id == "frayfinder_mitt":
		var numerator := int(entry.get("minimum_unravel_numerator", 0))
		var denominator := int(entry.get("minimum_unravel_denominator", 0))
		_check(not line.contains("+%d Unravel" % facts["amount"]),
			"Frayfinder Mitt never describes its +%d as an Unravel award: %s" % [facts["amount"], line])
		_check(line.contains("+%d %s" % [facts["amount"], facts["status"]]),
			"Frayfinder Mitt states its authored +%d %s, not a gauge bonus: %s" % [
				facts["amount"], facts["status"], line])
		_check(line.contains(String(facts["timing"])),
			"Frayfinder Mitt's damage applies before Weak/Exposed: " + line)
		_check(line.contains(String(facts["hit"]))
			and line.contains("of the player turn"),
			"Frayfinder Mitt keeps its first confirmed single-target hit of the player turn: " + line)
		_check(line.contains("at least %d/%d of its current threshold before the hit" % [numerator, denominator]),
			"Frayfinder Mitt gates on half the CURRENT threshold measured before the hit: " + line)
		_check(line.contains(String(facts["limit"]))
			and entry.get("once_per_player_turn") == true,
			"Frayfinder Mitt stays once per player turn: " + line)
		_check(line.contains(String(facts["exclusions"]))
			and entry.get("target_kind") == "enemy_single"
			and int(entry.get("hit_number", 0)) == 1
			and numerator == int(facts["numerator"]) and denominator == int(facts["denominator"]),
			"Frayfinder Mitt excludes area, multi-hit and later hits: " + line)
		_check(line.contains("Never an Unravel gauge gain"),
			"Frayfinder Mitt says it adds nothing to the Unravel gauge: " + line)
		_check(line.contains("no bonus on a rejected play"),
			"Frayfinder Mitt promises nothing for a rejected play: " + line)
		_check(not line.contains("unconditional") and not line.contains("every attack"),
			"Frayfinder Mitt never claims an unconditional or per-attack bonus: " + line)
		_check(line.contains("Normal/elite/boss base thresholds %d/%d/%d, grow +%d per break" % [
				CombatUnravel.THRESHOLD_NORMAL, CombatUnravel.THRESHOLD_ELITE,
				CombatUnravel.THRESHOLD_BOSS, CombatUnravel.THRESHOLD_INCREMENT]),
			"Frayfinder Mitt states the real Unravel base thresholds and growth: " + line)
	else:
		_check(line.contains("This wearer's cards that already %s %s" % [
				facts["verb"], facts["status"]]),
			"the %s line limits the bonus to this wearer's card that already %ss %s: %s" % [
				patch_id, facts["verb"], facts["status"], line])
		_check(line.contains(String(facts["bonus"])),
			"the %s line states its authored +%d %s amount in player words: %s" % [
				patch_id, facts["amount"], facts["status"], line])
		_check(not line.contains("any hero") and not line.contains("unconditional")
			and not line.contains("any cards") and not line.contains("every card"),
			"the %s line never claims an unconditional bonus to anyone's cards: %s" % [patch_id, line])
		_check(not line.contains("free cast") and not line.contains("grants %s to" % facts["status"]),
			"the %s line never claims a free card cast or an unconditional status: %s" % [patch_id, line])
	if patch_id == "reinforced_browband":
		_check(line.contains("actual recipient") and line.contains("even an ally"),
			"Reinforced Browband names the card's real Block recipient, including an ally: " + line)
	if patch_id == "red_bobbin_cuff":
		_check(line.contains("never multiplies Hemorrhage Hem")
			and not line.contains("Hemorrhage Hem's multiplier"),
			"Red Bobbin Cuff is not Hemorrhage Hem's multiplier: " + line)
	if patch_id == "threadguard_wrap":
		_check(line.contains("actual recipient"),
			"Threadguard Wrap applies to the card's actual recipient: " + line)
		_check(line.contains("damage-only card")
			and line.contains("gains no Block from it")
			and not line.contains("any card") and not line.contains("every card"),
			"Threadguard Wrap invents no Block on a damage-only card: " + line)
		_check(int(entry.get("amount", 0)) == int(facts["amount"])
			and int(_m05_catalog_entry("hemguard_cuff").get("amount", -1)) == 2,
			"Threadguard Wrap stays its authored +1 beside Hemguard Cuff's +2")
		_check(line.contains("grant 1 more Block") and not line.contains("grant 2 more Block"),
			"Threadguard Wrap never claims Hemguard Cuff's +2 amount: " + line)


## A named sewn HEAD/ARM/COAT patch: readable name, authored ID, real wearer and
## slot, plus the independently expected player-language power sentence for every
## authored M05/MPW entry, never an invented/fabricated effect sentence. Unknown
## IDs keep only the neutral 3-line prefix.
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
			"m05_head_patches", "m05_arm_support_patches", "m05_attack_patches",
			"m05_coat_patches"]:
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
		"spare_spool": "Spare Spool", "borrowed_button": "Borrowed Button",
		"switchback_button": "Switchback Button", "threadguard_wrap": "Threadguard Wrap"}
	for id in labels:
		_check(presenter.PATCH_LABELS.get(id, "") == labels[id],
			"authored readable patch label stays intact: " + id)
	# AC1/AC2: all eleven presenter power lines are player language - no "Authored
	# patch rule" preamble and no internal effect key - and each matches the
	# independently written literal line before any mounted case can skip it.
	_check(M05_EXPECTED_POWERS.size() == 11,
		"eleven authored M05/MPW patch powers have independent expectations")
	for patch_id in M05_EXPECTED_POWERS:
		var power: String = presenter._patch_power(patch_id)
		_check(power == M05_EXPECTED_POWERS[patch_id],
			"%s presenter power matches the independent player sentence: %s" % [patch_id, power])
		_check(not power.is_empty(),
			"%s has a readable worn-patch power line" % patch_id)
		for token in M05_INTERNAL_KEYS:
			_check(not power.contains(String(token)),
				"%s power never exposes %s" % [patch_id, token])
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
	var glove_chip := _patch_chip(meters[2], "ARM")
	_check(glove_chip != null and glove_chip.tooltip_text.contains("grant 1 more Unravel")
		and glove_chip.tooltip_text.contains("already grant Unravel")
		and not glove_chip.tooltip_text.contains("card_unravel_bonus")
		and not M05_EXPECTED_POWERS["frayfinder_mitt"].contains("+2 Unravel")
		and M05_EXPECTED_POWERS["loose_thread_glove"].contains("grant 1 more Unravel"),
		"Loose Thread Glove stays the real Unravel award, distinct from Frayfinder's +2 damage")
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
		and arm_chip.tooltip_text.contains("+2 attack damage")
		and not arm_chip.tooltip_text.contains("+2 Unravel")
		and arm_chip.tooltip_text.contains("before Weak/Exposed")
		and arm_chip.tooltip_text.contains("first confirmed single-target attack hit")
		and arm_chip.tooltip_text.contains("at least 1/2 of its current threshold before the hit")
		and arm_chip.tooltip_text.contains("Once per player turn")
		and arm_chip.tooltip_text.contains("Never an Unravel gauge gain")
		and arm_chip.tooltip_text.contains("not any area/multi-hit/later hit")
		and arm_chip.tooltip_text.contains("no bonus on a rejected play")
		and not arm_chip.tooltip_text.contains("unconditional"),
		"real pointer hover reads Frayfinder Mitt's authored conditional +2 attack-damage rule")
	_check(arm_chip != null and arm_chip.tooltip_text.split("\n").size() == 4
		and arm_chip.tooltip_text.split("\n")[0] == "Seamstress (seamstress)"
		and arm_chip.tooltip_text.split("\n")[1].contains("Frayfinder Mitt (frayfinder_mitt) — ARM")
		and arm_chip.tooltip_text.split("\n")[2] == "ACTIVE",
		"the Seamstress ARM hover keeps the genuine wearer/name/ID/slot/ACTIVE prefix")
	await _mouse(app.return_button)
	await _frames()
	_check(app.title_view.is_visible_in_tree() and presenter.row == null,
		"M05 case B cleans up and returns to title")
	# Case C: genuine Borrowed Button on a living hero's COAT slot (AC1, AC2, AC3).
	var case_c := await _m05_worn_fixture(app, presenter, [
		["bloodstitch_bonnet", "warden", "HEAD"],
		["reinforced_patchcoat", "warden", "COAT"],
		["borrowed_button", "tinker", "COAT"]])
	_check(not case_c.is_empty(), "M05 case C: real wardrobe, carryover and live meters")
	if case_c.is_empty():
		return
	var c_meters: Array = case_c["meters"]
	var c_carry: RunTornCarryover = case_c["carry"]
	var c_wardrobe: RunPatchWardrobe = case_c["wardrobe"]
	# AC1: living wearer (Tinker) has Borrowed Button sewn on COAT.
	# Check Tinker's max_hp is untouched (26/26), no fabricated +max-HP coat power.
	_check(app.party.get_hero(3)["max_hp"] == 26 and app.party.get_hero(3)["hp"] == 26,
		"Tinker wears borrowed_button with unchanged 26 max HP, no fabricated +max-HP coat power")
	_check(c_meters[2].hp_text.text == "26/26",
		"M05 case C: Tinker visible HP number carries the authentic base cap")
	var c_tinker_coat := _patch_chip(c_meters[2], "COAT")
	_assert_named_chip(c_tinker_coat, app.party.get_hero(3), "Borrowed Button", "borrowed_button", "COAT", true)
	_check(c_tinker_coat != null and c_tinker_coat.tooltip_text
		== _patch_tooltip(app.party.get_hero(3), "Borrowed Button", "borrowed_button", "COAT", true)
			+ "\n" + M05_EXPECTED_POWERS["borrowed_button"],
		"Tinker COAT chip matches independent Borrowed Button tooltip")
	_check(c_tinker_coat != null
		and c_tinker_coat.tooltip_text.contains("Once per combat")
		and c_tinker_coat.tooltip_text.contains("different living hero")
		and c_tinker_coat.tooltip_text.contains("committed card or ordered stitched half")
		and c_tinker_coat.tooltip_text.contains("restores at least 1 HP")
		and c_tinker_coat.tooltip_text.contains("living, untorn wearer")
		and c_tinker_coat.tooltip_text.contains("that wearer gains 3 Block")
		and not c_tinker_coat.tooltip_text.contains("maximum HP")
		and not c_tinker_coat.tooltip_text.contains("effective maximum HP"),
		"Tinker COAT tooltip accurately describes the authored conditional 3-Block rule")
	# Check other heroes' chips are unaffected:
	# Warden has Reinforced Patchcoat (+9 max HP, ACTIVE).
	var c_warden_coat := _patch_chip(c_meters[0], "COAT")
	_check(c_warden_coat != null and c_warden_coat.visible and c_warden_coat.text == "COAT"
		and c_warden_coat.tooltip_text.contains("Reinforced Patchcoat")
		and c_warden_coat.tooltip_text.contains("+9 effective maximum HP while living; no free healing.")
		and c_warden_coat.tooltip_text.contains("ACTIVE"),
		"M05 case C: Warden COAT chip remains Reinforced Patchcoat with its +9 cap")
	# Seamstress has no COAT sewn; slot is hidden.
	var c_seamstress_coat := _patch_chip(c_meters[1], "COAT")
	_check(c_seamstress_coat != null and not c_seamstress_coat.visible
		and c_seamstress_coat.text.is_empty() and c_seamstress_coat.tooltip_text.is_empty(),
		"M05 case C: Seamstress unsewn COAT slot stays hidden with no invented bonus")
	# AC3: Real hover and repeated refresh are read-only with identical state.
	var c_before := _state(app)
	var c_ledger: Dictionary = c_wardrobe.get_snapshot()
	seed(49201)
	var c_expected_global := randi()
	seed(49201)
	for repeat in range(4):
		presenter._sync_battle()
		await _frames()
	await _hover(c_tinker_coat)
	_check(root.gui_get_hovered_control() == c_tinker_coat
		and c_tinker_coat.tooltip_text.contains("that wearer gains 3 Block"),
		"real pointer hover reads Borrowed Button rule without an action")
	_check(_state(app) == c_before and randi() == c_expected_global
		and c_wardrobe.get_snapshot() == c_ledger and app.party_carryover == c_carry
		and c_carry._wardrobe == c_wardrobe,
		"M05 case C: repeated hover/refresh never spends, changes HP/Block/ownership or advances RNG")
	_check(app.party.get_hero(3)["block"] == 0,
		"hovering Borrowed Button never fabricates a live Block award")
	# AC2: Down the wearer via real party API and refresh.
	_check(app.party.apply_damage(3, 999) and app.party.is_downed(3),
		"M05 case C: the real party API downs the borrowed_button wearer")
	presenter._sync_battle()
	await _frames()
	_check(c_meters[2].hp_text.text == "0/26",
		"the downed Tinker keeps its base 26 cap at zero HP")
	_check(c_tinker_coat.visible and c_tinker_coat.text == "COAT"
		and c_tinker_coat.tooltip_text
			== _patch_tooltip(app.party.get_hero(3), "Borrowed Button", "borrowed_button", "COAT", false)
				+ "\n" + M05_EXPECTED_POWERS["borrowed_button"]
		and c_tinker_coat.tooltip_text.contains("DORMANT")
		and not c_tinker_coat.tooltip_text.contains("ACTIVE")
		and bool(c_tinker_coat.get_meta("fallen_chip")) == true,
		"the worn COAT chip reads DORMANT with no false active bonus once Tinker is downed")
	_check(app.party.get_hero(3)["block"] == 0,
		"downed wearer still has 0 Block, no fabricated Block award")
	_check(c_warden_coat.visible and c_warden_coat.tooltip_text.contains("ACTIVE")
		and c_warden_coat.tooltip_text.contains("+9 effective maximum HP"),
		"unrelated living Warden COAT chip remains ACTIVE and unaffected")
	# Neutral unknown ID and empty slots through the mounted presenter itself.
	var c_tinker_snap: Dictionary = app.party.get_hero(3)
	presenter._sync_patch_buttons(c_meters[2], c_tinker_snap,
		{"HEAD": "", "ARM": "", "COAT": "mystery_borrowed_coat"})
	var c_unknown_coat := _patch_chip(c_meters[2], "COAT")
	_check(c_unknown_coat != null and c_unknown_coat.visible and c_unknown_coat.text == "COAT"
		and c_unknown_coat.tooltip_text == _patch_tooltip(c_tinker_snap, "mystery_borrowed_coat",
			"mystery_borrowed_coat", "COAT", false)
		and c_unknown_coat.tooltip_text.split("\n").size() == 3,
		"an unknown COAT patch ID keeps its raw authored ID and invents no power line")
	_check(not _patch_chip(c_meters[2], "HEAD").visible
		and _patch_chip(c_meters[2], "HEAD").tooltip_text.is_empty()
		and not _patch_chip(c_meters[2], "ARM").visible
		and _patch_chip(c_meters[2], "ARM").tooltip_text.is_empty(),
		"empty HEAD/ARM slots never gain a fictional bonus")
	presenter._sync_battle()
	await _frames()
	_check(_patch_chip(c_meters[2], "COAT").tooltip_text.contains(
			"Borrowed Button (borrowed_button) — COAT")
		and not _patch_chip(c_meters[2], "HEAD").visible,
		"the next authoritative frame restores the real sewn Borrowed Button chip")
	await _mouse(app.return_button)
	await _frames()
	_check(app.title_view.is_visible_in_tree() and presenter.row == null,
		"M05 case C cleans up and returns to title")

## M05: the two earlier-omitted authored patch powers are readable from their real
## sewn battle chips - Switchback Button (HEAD) and Threadguard Wrap (ARM) - while
## the chips stay hover-only, actionless and read-only.
func _switchback_threadguard_ribbons_test(app, presenter) -> void:
	# AC1/AC2: bounded readable names for the two newly explained IDs.
	var labels := {
		"switchback_button": "Switchback Button", "threadguard_wrap": "Threadguard Wrap"}
	for id in labels:
		_check(presenter.PATCH_LABELS.get(id, "") == labels[id],
			"newly explained patch keeps its authored readable label: " + id)
	# A genuine wardrobe/carryover: Switchback Button on the Warden's HEAD, Hemguard
	# Cuff on the same Warden's ARM for the +2 comparison, Threadguard Wrap on the
	# Seamstress's ARM. Tinker wears nothing.
	var fixture := await _m05_worn_fixture(app, presenter, [
		["switchback_button", "warden", "HEAD"],
		["hemguard_cuff", "warden", "ARM"],
		["threadguard_wrap", "seamstress", "ARM"]])
	_check(not fixture.is_empty(), "Switchback/Threadguard case: real wardrobe, carryover and live meters")
	if fixture.is_empty():
		return
	var meters: Array = fixture["meters"]
	var carry: RunTornCarryover = fixture["carry"]
	var wardrobe: RunPatchWardrobe = fixture["wardrobe"]
	var warden: Dictionary = app.party.get_hero(1)
	var seamstress: Dictionary = app.party.get_hero(2)
	var tinker: Dictionary = app.party.get_hero(3)
	_check(warden["id"] == "warden" and seamstress["id"] == "seamstress"
		and tinker["id"] == "tinker"
		and warden["hp"] > 0 and seamstress["hp"] > 0 and tinker["hp"] > 0,
		"Switchback/Threadguard case: three living heroes in their authored order")
	var worn: Dictionary = wardrobe.get_snapshot()["worn"]
	_check(worn["warden"]["HEAD"] == "switchback_button"
		and worn["warden"]["ARM"] == "hemguard_cuff"
		and worn["seamstress"]["ARM"] == "threadguard_wrap",
		"Switchback/Threadguard case: the real worn ledger carries the sewn patches")
	# AC1: the real worn HEAD chip names Switchback Button, its wearer, ID, slot and
	# ACTIVE state, and states its authored follow-up award and once-per-turn limit.
	var switchback := _patch_chip(meters[0], "HEAD")
	_assert_named_chip(switchback, warden, "Switchback Button", "switchback_button", "HEAD", true)
	var switchback_entry := _m05_catalog_entry("switchback_button")
	_check(switchback_entry.get("slot") == "HEAD"
		and switchback_entry.get("effect") == "different_owner_followup_block"
		and int(switchback_entry.get("amount", -1)) == 2
		and switchback_entry.get("once_per_player_turn") == true,
		"authored Switchback Button record is HEAD, different_owner_followup_block, +2, once per player turn")
	_check(switchback != null and switchback.tooltip_text
		== _patch_tooltip(warden, "Switchback Button", "switchback_button", "HEAD", true)
			+ "\n" + M05_EXPECTED_POWERS["switchback_button"],
		"Warden HEAD chip matches the independent Switchback Button tooltip")
	_check(switchback != null and switchback.tooltip_text.contains("+2 Block")
		and switchback.tooltip_text.contains("Once per player turn")
		and switchback.tooltip_text.split("\n").size() == 4,
		"Switchback Button chip keeps its four-line ACTIVE hover with the authored +2 Block")
	# AC2: the real worn ARM chip names Threadguard Wrap, its wearer, ID, slot and
	# ACTIVE state, and states the +1 Block limited to positive-Block cards.
	var threadguard := _patch_chip(meters[1], "ARM")
	_assert_named_chip(threadguard, seamstress, "Threadguard Wrap", "threadguard_wrap", "ARM", true)
	var threadguard_entry := _m05_catalog_entry("threadguard_wrap")
	var hemguard_entry := _m05_catalog_entry("hemguard_cuff")
	_check(threadguard_entry.get("slot") == "ARM"
		and threadguard_entry.get("effect") == "card_block_bonus"
		and int(threadguard_entry.get("amount", -1)) == 1
		and hemguard_entry.get("effect") == "card_block_bonus"
		and int(hemguard_entry.get("amount", -1)) == 2,
		"authored Threadguard Wrap is ARM card_block_bonus +1 beside Hemguard Cuff's +2")
	_check(threadguard != null and threadguard.tooltip_text
		== _patch_tooltip(seamstress, "Threadguard Wrap", "threadguard_wrap", "ARM", true)
			+ "\n" + M05_EXPECTED_POWERS["threadguard_wrap"],
		"Seamstress ARM chip matches the independent Threadguard Wrap tooltip")
	_check(threadguard != null and threadguard.tooltip_text.contains("grant 1 more Block")
		and threadguard.tooltip_text.contains("actual recipient")
		and not threadguard.tooltip_text.contains("grant 2 more Block"),
		"Threadguard Wrap chip keeps its own +1 and never Hemguard Cuff's +2")
	_assert_named_chip(_patch_chip(meters[0], "ARM"), warden, "Hemguard Cuff",
		"hemguard_cuff", "ARM", true)
	# AC2: the mounted claims agree with the live authored rule owner, and a
	# damage-only card never gains a fabricated Block.
	var rules := CombatPatchAttackRules.new()
	_check(rules.bind_wardrobe(wardrobe, carry.torn),
		"Switchback/Threadguard case: the real patch resolver binds the same worn ledgers")
	_check(rules.card_block_bonus("seamstress", "seamstress_stitch_up") == 1
		and rules.project_card_support("seamstress", "seamstress_stitch_up") == {"block": 6},
		"live Threadguard Wrap adds exactly +1 to the wearer's printed 5 Block")
	_check(rules.card_block_bonus("warden", "warden_brace") == 2
		and rules.project_card_support("warden", "warden_brace") == {"block": 9},
		"live Hemguard Cuff adds its authored +2 to the same eligible kind")
	_check(rules.card_block_bonus("seamstress", "seamstress_prick") == 0
		and not rules.project_card_support("seamstress", "seamstress_prick").has("block"),
		"Threadguard Wrap fabricates no Block on a damage-only card")
	_check(rules.card_block_bonus("tinker", "tinker_spool_launcher") == 0,
		"a hero without Threadguard Wrap gains no fabricated Block bonus")
	# AC3: real pointer hover and repeated refresh are read-only.
	var before := _state(app)
	var ledger: Dictionary = wardrobe.get_snapshot()
	seed(87211)
	var expected_global := randi()
	seed(87211)
	for repeat in range(4):
		presenter._sync_battle()
		await _frames()
	await _hover(switchback)
	_check(root.gui_get_hovered_control() == switchback
		and switchback.tooltip_text.contains("+2 Block"),
		"real pointer hover reads the Switchback Button rule without an action")
	await _hover(threadguard)
	_check(root.gui_get_hovered_control() == threadguard
		and threadguard.tooltip_text.contains("grant 1 more Block"),
		"real pointer hover reads the Threadguard Wrap rule without an action")
	_check(switchback != null and threadguard != null
		and switchback.gui_input.get_connections().is_empty()
		and threadguard.gui_input.get_connections().is_empty()
		and switchback.pressed.get_connections().is_empty()
		and threadguard.pressed.get_connections().is_empty(),
		"the Switchback/Threadguard chips create no gameplay action or input handler")
	_check(_state(app) == before and randi() == expected_global
		and wardrobe.get_snapshot() == ledger and app.party_carryover == carry
		and carry._wardrobe == wardrobe,
		"repeated Switchback/Threadguard hover and refresh change no HP, Block, energy, hand, worn patches or RNG")
	_check(app.party.get_hero(1)["block"] == before[0][0]["block"]
		and app.party.get_hero(2)["block"] == before[0][1]["block"],
		"hovering either newly explained chip fabricates no live Block award")
	# AC3: an unknown ID keeps its neutral three-line prefix, never a power line.
	presenter._sync_patch_buttons(meters[0], app.party.get_hero(1),
		{"HEAD": "mystery_switchback"})
	var unknown_head := _patch_chip(meters[0], "HEAD")
	_check(unknown_head != null and unknown_head.visible and unknown_head.text == "HEAD"
		and unknown_head.tooltip_text == _patch_tooltip(app.party.get_hero(1),
			"mystery_switchback", "mystery_switchback", "HEAD", true)
		and unknown_head.tooltip_text.split("\n").size() == 3,
		"an unknown HEAD ID keeps its raw authored ID and invents no power line")
	_check(not _patch_chip(meters[0], "ARM").visible
		and _patch_chip(meters[0], "ARM").tooltip_text.is_empty(),
		"an unsewn ARM slot gains no fictional bonus beside the unknown ID")
	presenter._sync_battle()
	await _frames()
	_check(_patch_chip(meters[0], "HEAD").tooltip_text.contains(
			"Switchback Button (switchback_button) — HEAD")
		and _patch_chip(meters[0], "ARM").tooltip_text.contains(
			"Hemguard Cuff (hemguard_cuff) — ARM"),
		"the next authoritative frame restores the real sewn chips")
	_check(_state(app) == before and wardrobe.get_snapshot() == ledger,
		"inspecting an unknown ID or empty slot changes no combat or ledger state")
	# AC1/AC3: a torn Switchback Button wearer reads DORMANT with no false award.
	_check(app.party.apply_damage(1, 999) and app.party.is_downed(1),
		"Switchback/Threadguard case: the real party API downs the Switchback Button wearer")
	presenter._sync_battle()
	await _frames()
	_check(meters[0].hp_text.text == "0/40",
		"the downed Switchback Button wearer keeps its base 40 cap at zero HP")
	_check(switchback.visible and switchback.text == "HEAD"
		and switchback.tooltip_text
			== _patch_tooltip(app.party.get_hero(1), "Switchback Button", "switchback_button",
				"HEAD", false) + "\n" + M05_EXPECTED_POWERS["switchback_button"]
		and switchback.tooltip_text.contains("DORMANT")
		and not switchback.tooltip_text.contains("ACTIVE")
		and bool(switchback.get_meta("fallen_chip")) == true,
		"a torn Switchback Button wearer reads DORMANT with no false active award")
	_check(threadguard.visible and threadguard.text == "ARM"
		and threadguard.tooltip_text.contains("ACTIVE")
		and not threadguard.tooltip_text.contains("DORMANT"),
		"the other living wearer's Threadguard Wrap stays ACTIVE")
	# AC2/AC3: a torn Threadguard Wrap wearer also reads DORMANT.
	_check(app.party.apply_damage(2, 999) and app.party.is_downed(2),
		"Switchback/Threadguard case: the real party API downs the Threadguard Wrap wearer")
	presenter._sync_battle()
	await _frames()
	_check(threadguard.visible and threadguard.text == "ARM"
		and threadguard.tooltip_text
			== _patch_tooltip(app.party.get_hero(2), "Threadguard Wrap", "threadguard_wrap",
				"ARM", false) + "\n" + M05_EXPECTED_POWERS["threadguard_wrap"]
		and threadguard.tooltip_text.contains("DORMANT")
		and not threadguard.tooltip_text.contains("ACTIVE")
		and bool(threadguard.get_meta("fallen_chip")) == true,
		"a torn Threadguard Wrap wearer reads DORMANT with no fabricated Block")
	_check(app.party.get_hero(2)["block"] == 0,
		"the torn Threadguard Wrap wearer never gains Block from its hover")
	await _mouse(app.return_button)
	await _frames()
	_check(app.title_view.is_visible_in_tree() and presenter.row == null,
		"Switchback/Threadguard case cleans up and returns to title")


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
