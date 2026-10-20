extends SceneTree
## Real scene, real ordered hand, and a read-only CanvasItem presenter.
## Failures collect and exit nonzero; no model fixture replaces the live app.

const CARD_FACTS := {
	"warden_strike": ["warden", 1, [1, 2], "enemy_single", [1, 2]],
	"warden_brace": ["warden", 1, [1, 2, 3], "self", []],
	"warden_shield_bash": ["warden", 2, [1], "enemy_single", [1]],
	"seamstress_prick": ["seamstress", 1, [1, 2, 3], "enemy_single", [1, 2, 3]],
	"seamstress_mend": ["seamstress", 1, [2, 3], "ally_single", []],
	"seamstress_stitch_up": ["seamstress", 1, [1, 2, 3], "ally_single", []],
	"tinker_pop_shot": ["tinker", 1, [2, 3], "enemy_single", [1, 2, 3]],
	"tinker_scrap_bomb": ["tinker", 2, [3], "enemy_all", [1, 2, 3]],
	"tinker_tune_up": ["tinker", 0, [1, 2, 3], "none", []],
}
const TARGET_LINES := {
	"enemy_single": "To enemy ", "enemy_all": "All enemies ",
	"self": "Self", "ally_single": "Ally", "none": "No target",
}
const SUPPORT_IDS := ["warden_brace", "tinker_tune_up", "seamstress_mend", "seamstress_stitch_up"]

var failures: Array[String] = []
var checks := 0
var saw_compact := false
var saw_tall := false
var app
var presenter
var catalog := StarterCards.new()


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	await process_frame
	await process_frame


func _snapshot() -> Array:
	return [
		app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(),
		app.intent_label.text, app.run_rng.seed, app.run_rng.state, app.run_seed,
	]


func _expected_positions(positions: Array) -> String:
	if positions.size() == 1:
		return str(positions[0])
	if positions.size() > 1:
		return "%s–%s" % [positions[0], positions.back()]
	return "?"


func _catalog_facts() -> void:
	for card_id in CARD_FACTS:
		var authored: Array = CARD_FACTS[card_id]
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty(), "required catalog entry exists: " + card_id)
		if definition.is_empty():
			continue
		_check(definition.get("owner") == authored[0], "catalog owner exact: " + card_id)
		_check(definition.get("cost") == authored[1], "catalog cost exact: " + card_id)
		_check(definition.get("from_positions") == authored[2], "catalog source positions exact: " + card_id)
		_check(definition.get("target_kind") == authored[3], "catalog target kind exact: " + card_id)
		_check(definition.get("to_positions") == authored[4], "catalog destination exact: " + card_id)


func _panels() -> Array[Node]:
	return app.hand_view.get_children() if is_instance_valid(app.hand_view) else []


func _validate_display(observed: Dictionary) -> void:
	_check(app.deck is CombatDeck and app.battle_view != null and app.hand_view != null,
		"authoritative run and mounted battle/hand exist")
	if app.deck == null or app.hand_view == null:
		return
	var panels := _panels()
	_check(panels.size() == app.deck.hand.size(), "exact live hand count")
	_check(panels.size() > 0, "nonvacuous current card panels")
	var metadata = presenter._metadata
	_check(metadata._bindings.size() == panels.size(), "one drawing binding per current panel")
	var ids: Array[String] = []
	var initial_display := observed.is_empty()
	for index in range(panels.size()):
		var panel := panels[index] as Control
		_check(panel != null and panel is PanelContainer and panel.is_visible_in_tree(),
			"actual visible PanelContainer")
		if panel == null or panel.get_child_count() == 0:
			_check(false, "panel's original Label exists")
			continue
		var original := panel.get_child(0) as Label
		_check(original != null and original.is_visible_in_tree(), "first child is visible ID label")
		if original == null:
			continue
		var card_id: String = original.text
		ids.append(card_id)
		observed[card_id] = true
		_check(index < app.deck.hand.size() and card_id == app.deck.hand[index],
			"original unchanged ID text equals ordered deck.hand")
		var support: bool = card_id in SUPPORT_IDS
		_check(panel.get_child_count() == (2 if support else 1),
			"support retains exactly two children; other cards exactly one")
		if support and panel.get_child_count() >= 2:
			_check(panel.get_child(1) is Label and panel.get_child(1).text == "Click / Enter / Space",
				"original visible support action hint survives")
			_check(panel.tooltip_text.begins_with("Click or focus and press Enter / Space to play"), "support hint preserved")
			_check(panel.tooltip_text.contains("BASE"), "support tooltip includes base effect detail")
		var attack: bool = catalog.get_definition(card_id).get("target_kind") in ["enemy_single", "enemy_all"]
		_check(panel.gui_input.get_connections().size() == (1 if support or attack else 0),
			"exactly one handler for support or held attack; remaining inert cards have none")
		_check(panel.focus_mode == (Control.FOCUS_ALL if support else Control.FOCUS_NONE),
			"support focusability and inert non-support focus preserved")
		_check(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "card remains mouse hit-testable")
		_check(metadata._bindings.has(panel), "presenter keyed by actual live panel instance")
		if not metadata._bindings.has(panel):
			continue
		var binding: Dictionary = metadata._bindings[panel]
		_check(binding["id"] == card_id, "presenter keyed by unchanged original card ID")
		_check(panel.draw.get_connections().size() == 1
			and panel.draw.is_connected(binding["draw"]), "one exact CanvasItem draw callback")
		_check(panel.resized.get_connections().size() == 1
			and panel.tree_exiting.is_connected(binding["exit"]),
			"one resize/exit cleanup callback")
		_check(binding["draw_count"] > 0, "CanvasItem actually drew paper details")
		var expected: Array = CARD_FACTS.get(card_id, [])
		_check(not expected.is_empty(), "drawn held ID is a required catalog card")
		if expected.is_empty():
			continue
		var facts: Dictionary = metadata.get_facts(panel)
		var definition := catalog.get_definition(card_id)
		_check(facts.get("known") == true and facts.get("id") == card_id,
			"badge is from actual present catalog ID")
		_check(facts.get("owner") == definition.owner and facts.get("owner_text") == definition.owner.capitalize(),
			"owner badge matches unmodified catalog")
		_check(facts.get("cost") == definition.cost and facts.get("cost_text") == "Cost %d" % definition.cost,
			"cost badge matches unmodified catalog")
		_check(facts.get("from_text") == "From " + _expected_positions(definition.from_positions),
			"authored source positions printed")
		var target_line: String = TARGET_LINES[definition.target_kind]
		if definition.target_kind in ["enemy_single", "enemy_all"]:
			target_line += _expected_positions(definition.to_positions)
		_check(facts.get("target_text") == target_line, "authored enemy/ally/self/no-target line printed")
		# Tooltip verifies the base effect text for every held card.
		var tooltip_text := panel.tooltip_text
		var tooltip_lines := tooltip_text.split("\n")
		var header_line := "%s; %s; %d energy" % [definition.display_name, definition.owner.capitalize(), definition.cost]
		_check(tooltip_lines.has(header_line), "tooltip exact header line: " + card_id)
		var from_line := "From " + _expected_positions(definition.from_positions)
		_check(tooltip_lines.has(from_line), "tooltip exact from line: " + card_id)
		var tooltip_target_line := ""
		match definition.target_kind:
			"enemy_single":
				tooltip_target_line = "To one selected enemy"
				if not definition.to_positions.is_empty():
					tooltip_target_line += " " + _expected_positions(definition.to_positions)
			"enemy_all":
				tooltip_target_line = "All enemies"
				if not definition.to_positions.is_empty():
					tooltip_target_line += " " + _expected_positions(definition.to_positions)
			"self":
				tooltip_target_line = "Self"
			"ally_single":
				tooltip_target_line = "Choose one living ally"
			"none":
				tooltip_target_line = "No target"
		_check(tooltip_lines.has(tooltip_target_line), "tooltip exact target line: " + card_id)
		_check(tooltip_text.contains("BASE"), "tooltip states base effect: " + card_id)
		# Exact per-required-ID tooltip assertions for the nine authored cards.
		if card_id == "warden_strike":
			_check(tooltip_text.contains("BASE deal 6 damage"), "exact strike damage: " + card_id)
			_check(tooltip_text.contains("To one selected enemy 1\u20132"), "exact strike target: " + card_id)
		elif card_id == "warden_brace":
			_check(tooltip_text.contains("BASE gain 7 Block"), "exact brace block: " + card_id)
			_check(tooltip_text.contains("Self"), "exact brace target: " + card_id)
		elif card_id == "warden_shield_bash":
			_check(tooltip_text.contains("BASE deal 8 damage"), "exact bash damage: " + card_id)
			_check(tooltip_text.contains("To one selected enemy 1"), "exact bash target: " + card_id)
			_check(tooltip_lines.has("BASE deal 8 damage; ON CONFIRMED HIT add Weak 1"),
				"Shield Bash exact authored confirmed-hit Weak rule, not generic status")
		elif card_id == "seamstress_prick":
			_check(tooltip_text.contains("BASE deal 3 damage"), "exact prick damage: " + card_id)
			_check(tooltip_lines.has("BASE deal 3 damage; ON CONFIRMED HIT add Bleed 3 (authored Bleed 2 + Seamstress passive 1)"),
				"Prick exact confirmed-hit stack derives authored 2 plus passive 1")
			_check(tooltip_text.contains("To one selected enemy 1\u20133"), "exact prick target: " + card_id)
		elif card_id == "seamstress_mend":
			_check(tooltip_text.contains("BASE heal 5 HP, capped at max HP"), "exact mend heal with cap: " + card_id)
			_check(tooltip_text.contains("Choose one living ally"), "exact mend living ally: " + card_id)
		elif card_id == "seamstress_stitch_up":
			_check(tooltip_text.contains("BASE gain 5 Block"), "exact stitch block: " + card_id)
			_check(tooltip_text.contains("Choose one living ally"), "exact stitch living ally: " + card_id)
		elif card_id == "tinker_pop_shot":
			_check(tooltip_text.contains("BASE deal 5 damage"), "exact pop shot damage: " + card_id)
			_check(tooltip_text.contains("To one selected enemy 1\u20133"), "exact pop shot target: " + card_id)
		elif card_id == "tinker_scrap_bomb":
			_check(tooltip_text.contains("BASE deal 4 damage"), "exact scrap bomb damage: " + card_id)
			_check(tooltip_text.contains("All enemies 1\u20133"), "exact scrap bomb all-enemies target: " + card_id)
		elif card_id == "tinker_tune_up":
			_check(tooltip_text.contains("BASE draw 1 card"), "exact tune draw: " + card_id)
			_check(tooltip_text.contains("No target"), "exact tune no target: " + card_id)
		if card_id in ["warden_strike", "tinker_pop_shot", "tinker_scrap_bomb"]:
			_check(not tooltip_text.contains("ON CONFIRMED HIT") and not tooltip_text.contains("Bleed")
				and not tooltip_text.contains("Weak"), "neutral attack never claims a debuff: " + card_id)
		# Support cards: exact instruction plus appended effect detail.
		if card_id in SUPPORT_IDS:
			_check(tooltip_text.begins_with("Click or focus and press Enter / Space to play"), "support exact instruction preserved: " + card_id)
			_check(tooltip_text.contains("BASE"), "support tooltip contains base effect: " + card_id)
			if card_id == "warden_brace":
				_check(tooltip_text.contains("BASE gain 7 Block"), "support brace effect exact: " + card_id)
			elif card_id == "tinker_tune_up":
				_check(tooltip_text.contains("BASE draw 1 card"), "support tune effect exact: " + card_id)
			elif card_id == "seamstress_mend":
				_check(tooltip_text.contains("BASE heal 5 HP, capped at max HP"), "support mend effect exact: " + card_id)
			elif card_id == "seamstress_stitch_up":
				_check(tooltip_text.contains("BASE gain 5 Block"), "support stitch effect exact: " + card_id)
		var geometry: Dictionary = metadata.get_geometry(panel)
		if not geometry.is_empty():
			if geometry["compact"]:
				saw_compact = true
			else:
				saw_tall = true
		_check(not geometry.is_empty() and panel.size.x >= 88 and panel.size.y >= 30,
			"actual compact or tall panel fits its measured badge geometry")
		var bounds := Rect2(Vector2.ZERO, panel.size)
		for key in ["owner", "cost", "footer"]:
			if geometry.has(key):
				var rect: Rect2 = geometry[key]
				_check(rect.size.x > 0 and rect.size.y > 0 and bounds.encloses(rect),
					"all %s paper/felt drawing stays inside live panel" % key)
			else:
				_check(false, "required badge geometry exists: " + key)
		if not geometry.is_empty():
			_check(geometry["owner"].end.x < geometry["cost"].position.x,
				"owner and cost patches do not overlap")
			_check(geometry["footer"].position.y > geometry["owner"].end.y,
				"lower rules do not overlap owner tag")
		_check(root.get_visible_rect().encloses(panel.get_global_rect()),
			"whole card remains within the 1280x720 viewport")
	_check(ids == app.deck.hand, "all current panel IDs exactly follow deck.hand")
	_check(app.end_turn_button.is_visible_in_tree() and app.return_button.is_visible_in_tree(),
		"End Turn and Return remain accessible")
	_check(app.end_turn_button.focus_mode == Control.FOCUS_ALL
		and app.return_button.focus_mode == Control.FOCUS_ALL,
		"End Turn/Return keyboard activation remains available")
	_check(is_instance_valid(presenter.energy_label) and
		presenter.energy_label.text.begins_with("Energy: %d |" % app.deck.energy),
		"energy/action controls remain visible and authoritative")


func _refresh_preserves_everything(observed: Dictionary) -> void:
	var before := _snapshot()
	var panels := _panels()
	var old_draws := {}
	var original_rects := {}
	for panel in panels:
		old_draws[panel] = presenter._metadata._bindings[panel]["draw_count"]
		original_rects[panel] = panel.get_global_rect()
	presenter._sync_battle()
	presenter._sync_battle()
	presenter._sync_battle()
	await _frames()
	_check(_snapshot() == before, "repeated UI-only synchronization preserves full battle, intents and RNG")
	for panel in panels:
		_check(presenter._metadata._bindings.has(panel)
			and presenter._metadata._bindings[panel]["draw_count"] == old_draws[panel],
			"unchanged facts and geometry never queue redundant redraws")
		_check(panel.get_global_rect() == original_rects[panel], "decoration preserves original card hitbox")
	# Byte-for-byte tooltip stability across repeated sync.
	for panel in panels:
		var original_tooltip: String = panel.tooltip_text
		presenter._sync_battle()
		await _frames()
		_check(is_instance_valid(panel) and panel.tooltip_text == original_tooltip,
			"repeated sync preserves tooltip byte-for-byte: " + (panel.get_child(0).text if panel.get_child_count() > 0 else "?"))
	_validate_display(observed)


func _click(panel: Control) -> void:
	var location := panel.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = location
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = location
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _find(card_id: String) -> Control:
	for panel in _panels():
		if panel.get_child(0).text == card_id:
			return panel
	return null


func _start() -> bool:
	app.run_seed = 42
	app.start_button.pressed.emit()
	await _frames()
	var ready: bool = app.deck is CombatDeck and app.party is CombatParty and app.run_rng != null 		and is_instance_valid(app.battle_view) and is_instance_valid(app.hand_view)
	_check(ready, "real Start Run creates complete seeded M01 battle")
	if not ready:
		return false
	_check(app.run_seed == 42, "live run preserves requested fixed seed 42")
	_check(app.deck.hand.size() == 5 and app.hand_view.get_child_count() == 5, "Start Run draws exactly five real panels")
	return true


func _play_support(card_id: String, observed: Dictionary) -> bool:
	var panel := _find(card_id)
	if panel == null:
		return false
	# This is a real play, not a fake deck consumption.
	var before := _snapshot()
	var original_hand: Array = app.deck.hand.duplicate()
	var old_bindings := _panels()
	await _click(panel)
	if app.deck.hand == original_hand:
		_check(_snapshot() == before, "unplayable support never mutates battle")
		return false
	_check(app.deck.hand.size() == original_hand.size() - (0 if card_id == "tinker_tune_up" else 1),
		"valid support consumes one card; Tune Up draws one replacement")
	_check(card_id in app.deck.discard_pile, "played support moved to discard")
	for previous in old_bindings:
		if is_instance_valid(previous):
			_check(not presenter._metadata._bindings.has(previous),
				"replaced panels are disconnected after support play")
	_validate_display(observed)
	return true


func _unknown_check() -> void:
	var metadata = load("res://scripts/live_hand_card_metadata.gd").new()
	var unknown: Dictionary = metadata.describe("unreleased_card")
	_check(catalog.get_definition("unreleased_card").is_empty(), "unknown catalog lookup really empty")
	_check(not unknown["known"] and unknown["owner"] == "" and unknown["cost"] == -1
		and unknown["owner_text"] == "Unknown" and unknown["cost_text"] == "Cost ?",
		"unknown ID claims no invented owner or numeric energy")
	var foreign := PanelContainer.new()
	foreign.custom_minimum_size = Vector2(150, 96)
	var label := Label.new()
	label.text = "unreleased_card"
	foreign.add_child(label)
	root.add_child(foreign)
	await _frames()
	var before := _snapshot()
	var panels: Array[Node] = [foreign]
	var hand: Array[String] = ["unreleased_card"]
	metadata.sync(panels, hand)
	await _frames()
	_check(metadata._bindings.size() == 1 and metadata.get_facts(foreign) == unknown,
		"unknown ID draws only an honest placeholder")
	# Unknown tooltip must not invent any quantity.
	var unknown_tooltip := foreign.tooltip_text
	_check(unknown_tooltip == "Unknown card", "unknown tooltip is honest 'Unknown card': got '" + unknown_tooltip + "'")
	_check(not unknown_tooltip.contains("damage") and not unknown_tooltip.contains("Block")
		and not unknown_tooltip.contains("heal") and not unknown_tooltip.contains("draw")
		and not unknown_tooltip.contains("energy") and not unknown_tooltip.contains("cost"),
		"unknown tooltip invents no effect numbers")
	_check(label.text == "unreleased_card" and foreign.get_child_count() == 1
		and foreign.gui_input.get_connections().is_empty(),
		"unknown panel leaves label and input inert")
	metadata.sync(panels, hand)
	_check(foreign.draw.get_connections().size() == 1, "unknown repeat bind idempotent")
	var absent: Array[String] = ["no_longer_in_hand"]
	metadata.sync(panels, absent)
	_check(metadata._bindings.is_empty() and foreign.draw.get_connections().is_empty(),
		"absent/incorrect ID immediately releases drawing callback")
	_check(foreign.tooltip_text == "" and not foreign.tooltip_text.contains("BASE")
		and not foreign.tooltip_text.contains("damage") and not foreign.tooltip_text.contains("Block"),
		"absent sync restores empty pre-bind tooltip with no stale effect words")
	metadata.sync(panels, hand)
	_check(metadata._bindings.size() == 1 and foreign.tooltip_text == "Unknown card",
		"rebind to unknown restores exact unknown tooltip")
	metadata.clear()
	_check(metadata._bindings.is_empty() and foreign.draw.get_connections().is_empty(),
		"explicit clear releases unknown panel")
	_check(foreign.tooltip_text == "" and not foreign.tooltip_text.contains("BASE")
		and not foreign.tooltip_text.contains("damage") and not foreign.tooltip_text.contains("Block"),
		"clear restores empty pre-bind tooltip with no stale effect words")
	# Same-panel valid-ID rebind: old effect text must be replaced, not duplicated.
	var rebind_panel := PanelContainer.new()
	rebind_panel.custom_minimum_size = Vector2(150, 96)
	var real_label := Label.new()
	real_label.text = "warden_brace"
	rebind_panel.add_child(real_label)
	root.add_child(rebind_panel)
	await _frames()
	var rebind_panels: Array[Node] = [rebind_panel]
	var rebind_hand: Array[String] = ["warden_brace"]
	metadata.sync(rebind_panels, rebind_hand)
	await _frames()
	_check(metadata._bindings.has(rebind_panel), "valid rebind creates binding")
	var brace_tooltip := rebind_panel.tooltip_text
	_check(brace_tooltip.contains("BASE gain 7 Block") and brace_tooltip.contains("Self"),
		"valid rebind tooltip shows exact brace effect and target")
	# Replace with another real card on the same panel.
	real_label.text = "tinker_tune_up"
	rebind_hand = ["tinker_tune_up"]
	metadata.sync(rebind_panels, rebind_hand)
	await _frames()
	var tune_tooltip := rebind_panel.tooltip_text
	_check(tune_tooltip.contains("BASE draw 1 card") and tune_tooltip.contains("No target"),
		"rebind replaces tooltip with exact tune effect and target")
	_check(not tune_tooltip.contains("BASE gain 7 Block"),
		"rebind removes old brace effect text; no stale wording remains")
	metadata.clear()
	rebind_panel.free()
	foreign.free()
	_check(_snapshot() == before, "unknown/mismatched catalog view cannot touch any live model")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_catalog_facts()
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene exists")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node_or_null("LiveSupportHand")
	_check(presenter != null and app.deck == null, "mounted hand lifecycle starts in title")
	if presenter == null:
		app.free()
		_finish()
		return
	_check(presenter._metadata._bindings.is_empty(), "no title-time decoration binds")
	var first_trace: Array = []
	for session in range(2):
		if not await _start():
			break
		var observed := {}
		var session_trace: Array = []
		var deck_ref = app.deck
		var before_duplicate := _snapshot()
		app._start_run()
		presenter._sync_battle()
		_check(app.deck == deck_ref and _snapshot() == before_duplicate,
			"duplicate Start Run does not replace or alter session")
		_validate_display(observed)
		# Compare the same global RNG stream, not a separately seeded RNG instance.
		seed(8459)
		var next_global := randi()
		seed(8459)
		await _refresh_preserves_everything(observed)
		_check(randi() == next_global, "presentation does not draw from global RNG")
		var played_brace := false
		var played_tune := false
		for turn in range(14):
			session_trace.append([app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
				app.deck.discard_pile.duplicate()])
			if not played_brace and _find("warden_brace") != null:
				played_brace = await _play_support("warden_brace", observed)
			if not played_tune and _find("tinker_tune_up") != null:
				played_tune = await _play_support("tinker_tune_up", observed)
			_validate_display(observed)
			await _refresh_preserves_everything(observed)
			if turn < 13:
				var old_panels := _panels()
				app.end_turn_button.pressed.emit()
				await _frames()
				_check(app.deck != null and app.deck.turn_active, "legal End Turn opens next hand")
				if app.deck == null or app.hand_view == null:
					break
				for old in old_panels:
					if is_instance_valid(old):
						_check(not presenter._metadata._bindings.has(old),
							"End Turn removes stale panel drawing callback")
				_validate_display(observed)
		for card_id in CARD_FACTS:
			_check(observed.has(card_id), "all nine authored IDs were actually held: " + card_id)
		_check(played_brace and played_tune,
			"real eligible Brace and zero-energy Tune Up both played and refreshed")
		if session == 0:
			first_trace = session_trace
			await _unknown_check()
		else:
			_check(session_trace == first_trace, "two fixed-seed real-session hand/pile traces match")
		var old_panels := _panels()
		app.return_button.pressed.emit()
		_check(presenter._metadata._bindings.is_empty(), "Return immediately clears all metadata refs")
		for old in old_panels:
			if is_instance_valid(old):
				_check(old.draw.get_connections().is_empty(), "Return disconnects old draw callbacks")
				var pre_bind_tooltip: String = old.tooltip_text
				_check(not pre_bind_tooltip.contains("BASE deal") and not pre_bind_tooltip.contains("BASE gain")
					and not pre_bind_tooltip.contains("BASE heal") and not pre_bind_tooltip.contains("BASE draw"),
					"Return clears stale base-effect tooltip words: " + (old.get_child(0).text if old.get_child_count() > 0 else "?"))
		await _frames()
		_check(app.deck == null and app.battle_view == null,
			"Return to Title released run and battle")
		_check(presenter._metadata._bindings.is_empty() and app.start_button.has_focus(),
			"Title remains focusable and no stale panel survives")
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_hand_card_metadata_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
