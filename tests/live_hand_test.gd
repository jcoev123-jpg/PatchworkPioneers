extends SceneTree

const EXPECTED := {
	"warden_strike": 2, "warden_brace": 1, "warden_shield_bash": 1,
	"seamstress_prick": 2, "seamstress_mend": 1, "seamstress_stitch_up": 1,
	"tinker_pop_shot": 2, "tinker_scrap_bomb": 1, "tinker_tune_up": 1,
}

var failures: Array[String] = []
var checks := 0
var starts := 0
var app


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _snapshot(deck: CombatDeck) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(),
		deck.discard_pile.duplicate(), deck.turn_active]


func _copies(cards: Array) -> Dictionary:
	var result := {}
	for card in cards:
		result[card] = result.get(card, 0) + 1
	return result


func _visible(app) -> void:
	_check(app.battle_view != null and app.battle_view.is_visible_in_tree(), "battle mounted and visible")
	_check(app.hand_view != null and app.hand_view.is_visible_in_tree(), "hand mounted and visible")
	if app.hand_view == null:
		return
	_check(app.hand_view.get_child_count() == 5, "five visible card panels")
	var ids: Array[String] = []
	for panel in app.hand_view.get_children():
		_check(panel is PanelContainer and panel.is_visible_in_tree(), "visible placeholder panel")
		var label = panel.get_child(0) if panel.get_child_count() > 0 else null
		# The raw-ID label stays as the stable hand identity but is no longer
		# drawn: the V4 cream card is rendered by the metadata decorator.
		_check(label is Label and not label.is_visible_in_tree(), "identity label retained, raw ID hidden")
		if label is Label:
			ids.append(label.text)
	_check(ids == app.deck.hand, "visible IDs match actual hand in order")
	_check(app.pile_label != null and app.pile_label.is_visible_in_tree(), "visible pile counts exist")
	if app.pile_label != null:
		_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
			app.deck.draw_pile.size(), app.deck.discard_pile.size()], "visible counts match actual piles")
	_check(app.deck.hand.size() == 5 and app.deck.turn_active, "five actual cards in active turn")
	_check(_copies(app.deck.draw_pile + app.deck.hand + app.deck.discard_pile) == EXPECTED,
		"all twelve starter copies conserved")


func _run() -> void:
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/starter_deck.json"))
	_check(source is Array, "starter JSON is an array")
	if not source is Array:
		_finish()
		return
	_check(_copies(source) == EXPECTED, "starter multiplicities match design exactly")
	var cards: Array[String] = []
	cards.assign(source)
	var scene: PackedScene = load("res://scenes/app.tscn")
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_check(app.title_label.text == "Patchwork Pioneers" and app.title_label.is_visible_in_tree(), "title retained")
	_check(app.start_button != null and app.start_button.is_visible_in_tree(), "Start run mounted")
	_check(app.start_button.has_focus(), "title starts with keyboard focus")
	_check(app.deck == null and app.run_rng == null and app.battle_view == null, "initial session empty")
	app.start_run_requested.connect(func(): starts += 1)
	app.run_seed = 42
	var first_trace: Array = []
	for session in range(2):
		_fixture_start(app)
		_check(starts == 0, "fixture does not emit seeded Start; duplicate Start still emits")
		_check(app.deck != null and app.run_rng != null, "Start run creates real session objects")
		if app.deck == null or app.run_rng == null:
			app.free()
			_finish()
			return
		_check(not app.title_view.is_visible_in_tree(), "title hidden in battle")
		_check(app.end_turn_button.has_focus(), "End Turn receives keyboard focus")
		_check(app.end_turn_button.focus_mode == Control.FOCUS_ALL and
			app.return_button.focus_mode == Control.FOCUS_ALL, "battle actions support keyboard and mouse")
		var actions: Array = [app.end_turn_button, app.return_button]
		var juice = app.get_node_or_null("LiveCombatJuice")
		_check(juice != null and is_instance_valid(juice.fast_button),
			"battle row mounts the Fast animations toggle")
		if juice != null and is_instance_valid(juice.fast_button):
			actions.append(juice.fast_button)
		_check(actions.size() == 3, "End Turn, Return and the Fast toggle form the battle action loop")
		_check(is_instance_valid(app.action_corner) and app.action_corner.is_ancestor_of(app.return_button)
			and app.action_corner_row.is_ancestor_of(juice.fast_button)
			and not app.action_corner.is_ancestor_of(app.end_turn_button),
			"Return and Fast share one compact sewn corner beside End Turn")
		for index in range(actions.size()):
			_check(actions[index].get_node(actions[index].focus_next) == actions[(index + 1) % actions.size()] and
				actions[index].get_node(actions[index].focus_previous) == actions[(index - 1 + actions.size()) % actions.size()],
				"complete forward and reverse keyboard action cycle")
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		var reference := CombatDeck.new(cards, rng)
		reference.start_turn()
		var trace: Array = []
		var deck_ref: WeakRef = weakref(app.deck)
		var rng_ref: WeakRef = weakref(app.run_rng)
		var view_id: int = app.battle_view.get_instance_id()
		var child_count: int = app.get_child_count()
		# A second request while active cannot replace the current session.
		app._start_run()
		_check(app.deck == deck_ref.get_ref() and app.get_child_count() == child_count, "duplicate start preserves session")
		for turn in range(12):
			if session == 0 and turn == 0:
				if "--inject-wrong-count" in OS.get_cmdline_user_args():
					app.pile_label.text = "wrong"
				if "--inject-missing-control" in OS.get_cmdline_user_args():
					app.hand_view.get_child(0).free()
			_visible(app)
			_check(_snapshot(app.deck) == _snapshot(reference), "UI lifecycle matches real deck reference")
			_check(app.run_rng.state == rng.state, "UI uses only the session RNG")
			trace.append(_snapshot(app.deck))
			if turn == 0:
				_check(app.deck.draw_pile.size() == 7 and app.deck.discard_pile.is_empty(), "opening piles 7/0")
			if turn == 1:
				_check(app.deck.draw_pile.size() == 2 and app.deck.discard_pile == trace[0][1], "first end discards entire opening hand")
			if turn == 2:
				_check(app.deck.draw_pile.size() == 7 and app.deck.discard_pile.is_empty(), "third hand crosses seeded reshuffle")
			if turn < 11:
				_check(reference.end_turn() and reference.start_turn(), "reference turn advances")
				app.end_turn_button.pressed.emit()
				await process_frame
		if session == 0:
			first_trace = trace
		else:
			_check(trace == first_trace, "fresh fixed-seed session replays every opening and later pile")
		app.return_button.pressed.emit()
		await process_frame
		_check(app.deck == null and app.run_rng == null, "return clears session references")
		_check(deck_ref.get_ref() == null and rng_ref.get_ref() == null, "return releases deck and RNG")
		_check(not is_instance_id_valid(view_id), "battle view removed and freed")
		_check(app.battle_view == null and app.hand_view == null and app.pile_label == null and
			app.end_turn_button == null and app.return_button == null, "battle control references cleared")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "return restores visible focused title")
		app._end_turn()
		app._return_to_title()
		_check(app.deck == null and app.get_child_count() == child_count - 1, "inactive actions do not recreate stale session")
	await _pool_faces()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")


func _frames() -> void:
	await process_frame
	await process_frame


## Every authored pool record (base and '+' upgrade), driven from each source
## catalog's own enumerator so a new pool entry cannot be silently skipped.
func _pool_face_ids() -> Array[String]:
	var ids: Array[String] = []
	var warden := WardenPoolCards.new()
	for base_id in warden.get_base_ids():
		ids.append(base_id)
		ids.append(base_id + "_plus")
	var seamstress := SeamstressPoolCards.new()
	for base_id in seamstress.get_base_ids():
		ids.append(base_id)
		ids.append(base_id + "_plus")
	var tinker := TinkerPoolCards.new()
	for base_id in tinker.get_pool_card_ids():
		ids.append(base_id)
		ids.append(base_id + "_plus")
	return ids


func _pool_definition(card_id: String) -> Dictionary:
	var warden := WardenPoolCards.new().get_definition(card_id)
	if not warden.is_empty():
		return warden
	var seamstress := SeamstressPoolCards.new().get_definition(card_id)
	if not seamstress.is_empty():
		return seamstress
	return TinkerPoolCards.new().get_definition(card_id)


func _panel_for(card_id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and (panel.get_child(0) as Label).text == card_id:
			return panel
	return null


func _combat_state() -> Array:
	return [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_intents.get_intents(), app.run_rng.seed, app.run_rng.state,
		app.battle_result.get_outcome(), app.session_gold]


func _click_center(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	var location: Vector2 = panel.get_global_rect().get_center()
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


## Authored ranges are contiguous today; mirrors the drawn badge without sharing
## the presenter's own helper, so a wrong range on the face is caught.
func _face_positions(positions: Array) -> String:
	if positions.is_empty():
		return "?"
	var values: Array[String] = []
	for position in positions:
		values.append(str(position))
	var contiguous := true
	for index in range(1, positions.size()):
		if int(positions[index]) != int(positions[index - 1]) + 1:
			contiguous = false
	if contiguous and positions.size() > 1:
		return "%s–%s" % [values.front(), values.back()]
	return ",".join(values)


func _badge_target(target_kind: String, to_positions: Array) -> String:
	var positions: String = _face_positions(to_positions)
	match target_kind:
		"enemy_single":
			return "To enemy " + positions
		"enemy_all":
			return "All enemies " + positions
		"enemy_random":
			return "Random enemy " + positions
		"self":
			return "Self"
		"ally_single":
			return "Ally"
		"party_all":
			return "All living heroes"
		"none":
			return "No target"
	return "Unknown target"


func _precise_target(target_kind: String, to_positions: Array) -> String:
	var positions: String = _face_positions(to_positions)
	match target_kind:
		"enemy_single":
			return "To one selected enemy " + positions
		"enemy_all":
			return "All enemies " + positions
		"enemy_random":
			return "A random living enemy per hit (%s)" % positions
		"self":
			return "Self"
		"ally_single":
			return "Choose one living ally"
		"party_all":
			return "All living heroes"
		"none":
			return "No target"
	return "Unknown target"


## Independent precise-rule expectations straight from the detached authored
## record: every present effect must be readable in the tooltip, never invented.
func _expected_tooltip_phrases(card_id: String, definition: Dictionary) -> Array[String]:
	var effects: Dictionary = definition.get("effects", {})
	var phrases: Array[String] = []
	if effects.has("damage"):
		phrases.append("deal %d damage" % int(effects["damage"]))
		var hits: int = int(effects.get("hits", effects.get("hit_count", 1)))
		if hits > 1:
			phrases.append("%d hits" % hits)
	if bool(effects.get("random_target_each_hit", false)):
		phrases.append("random living enemy")
	if effects.has("block"):
		phrases.append("gain %d Block" % int(effects["block"]))
	if effects.has("other_ally_block"):
		phrases.append("each other living ally gains %d Block" % int(effects["other_ally_block"]))
	if effects.has("block_all"):
		phrases.append("each living hero gains %d Block" % int(effects["block_all"]))
	if effects.has("heal"):
		phrases.append("heal %d HP" % int(effects["heal"]))
	if effects.has("exposed"):
		phrases.append("Exposed %d" % int(effects["exposed"]))
	if effects.has("weak"):
		phrases.append("Weak %d" % int(effects["weak"]))
	if effects.has("bleed"):
		var applied: int = int(effects["bleed"])
		if CombatSeamstressPoolBleed.SUPPORTED_IDS.has(card_id):
			applied += 1
			phrases.append("Seamstress passive 1")
		phrases.append("Bleed %d" % applied)
	if effects.has("unravel"):
		phrases.append("%d Unravel" % int(effects["unravel"]))
	if effects.has("bleed_multiplier"):
		phrases.append("Bleed")
	if effects.has("pinned"):
		phrases.append("Pin")
		phrases.append("next attack gets +5 damage")
	if effects.has("guarding"):
		phrases.append("Guard")
	if effects.has("thorns"):
		phrases.append("%d Thorns" % int(effects["thorns"]))
	if effects.has("draw"):
		phrases.append("draw %d card" % int(effects["draw"]))
	if effects.has("gain_energy"):
		phrases.append("gain %d energy" % int(effects["gain_energy"]))
	if effects.has("energy") and not effects.has("gain_energy"):
		phrases.append("gain %d energy" % int(effects["energy"]))
	if effects.has("self_hp_loss"):
		phrases.append("self-damage %d" % int(effects["self_hp_loss"]))
	if effects.has("conditional_damage"):
		var condition: Dictionary = effects["conditional_damage"]
		phrases.append("%d damage instead" % int(condition.get("damage", 0)))
		phrases.append("Unravelled")
	return phrases


## Independent short-rule expectations for the line actually drawn on the card.
func _expected_rule_tokens(card_id: String, definition: Dictionary) -> Array[String]:
	var effects: Dictionary = definition.get("effects", {})
	var tokens: Array[String] = []
	if effects.has("damage"):
		tokens.append("%d dmg" % int(effects["damage"]))
		var hits: int = int(effects.get("hits", effects.get("hit_count", 1)))
		if hits > 1:
			tokens.append("x%d" % hits)
	if bool(effects.get("random_target_each_hit", false)):
		tokens.append("random each hit")
	if effects.has("block"):
		tokens.append("%d Block" % int(effects["block"]))
	if effects.has("other_ally_block"):
		tokens.append("%d Block to other allies" % int(effects["other_ally_block"]))
	if effects.has("block_all"):
		tokens.append("%d Block to all heroes" % int(effects["block_all"]))
	if effects.has("heal"):
		tokens.append("heal %d" % int(effects["heal"]))
	if effects.has("exposed"):
		tokens.append("Exposed %d" % int(effects["exposed"]))
	if effects.has("weak"):
		tokens.append("Weak %d" % int(effects["weak"]))
	if effects.has("bleed"):
		var applied: int = int(effects["bleed"])
		if CombatSeamstressPoolBleed.SUPPORTED_IDS.has(card_id):
			applied += 1
		tokens.append("Bleed %d" % applied)
	if effects.has("unravel"):
		tokens.append("Unravel %d" % int(effects["unravel"]))
	if effects.has("bleed_multiplier"):
		tokens.append("Bleed")
	if effects.has("pinned"):
		tokens.append("Pin")
	if effects.has("guarding"):
		tokens.append("Guard")
	if effects.has("thorns"):
		tokens.append("Thorns %d" % int(effects["thorns"]))
	if effects.has("draw"):
		tokens.append("draw %d" % int(effects["draw"]))
	if effects.has("gain_energy"):
		tokens.append("+%d energy" % int(effects["gain_energy"]))
	if effects.has("energy") and not effects.has("gain_energy"):
		tokens.append("+%d energy" % int(effects["energy"]))
	if effects.has("self_hp_loss"):
		tokens.append("-%d HP" % int(effects["self_hp_loss"]))
	if effects.has("conditional_damage"):
		var condition: Dictionary = effects["conditional_damage"]
		tokens.append("%d dmg if" % int(condition.get("damage", 0)))
	return tokens


func _area_card(card_id: String) -> bool:
	var area = app.get_node_or_null("LiveAreaAttackAction")
	return area != null and card_id in area.CARD_IDS


## Independent admission expectation built from the real resolver tables and the
## mounted area adapter's own card list, never from the presenter being checked.
func _pool_admitted(card_id: String) -> bool:
	var base_id: String = card_id.trim_suffix("_plus")
	if CombatWardenPoolBlockCards.SUPPORTED_KINDS.has(base_id) \
			and (card_id == base_id or card_id == base_id + "_plus"):
		return true
	if CombatPoolEnergyCards.SUPPORTED_IDS.has(card_id):
		return true
	if CombatPoolPlainStrikes.SUPPORTED_IDS.has(card_id):
		return true
	if CombatWardenPoolHeavyAttacks.SUPPORTED_CARD_IDS.has(card_id):
		return true
	if CombatTinkerDirectFirePreview.IDS.has(card_id):
		return true
	if card_id in CombatAttackTargeting.SIGHT_GLASS_IDS:
		return true
	if card_id in ["tinker_spare_parts", "tinker_spare_parts_plus"]:
		return true
	# The six Seamstress enemy-control variants are live-admitted by the mounted
	# attack presenter, so this independent expectation must admit them too.
	if card_id in CombatSeamstressPoolControl.NEEDLE_IDS \
			or card_id in CombatSeamstressPoolControl.SNAG_IDS \
			or card_id in CombatSeamstressPoolControl.UNPICK_IDS:
		return true
	# The six authored Seamstress healing variants are live-admitted by the shared
	# support hand, whose pool resolver is the independent authority here.
	if card_id in CombatSeamstressPoolHeals.DARNING_IDS \
			or card_id in CombatSeamstressPoolHeals.TEA_IDS \
			or card_id in CombatSeamstressPoolHeals.FIELD_MEND_IDS:
		return true
	# D2-1 enemy-single Bleed variants are now admitted by the mounted
	# LiveAreaAttackAction child, not by a separate combat button.
	if card_id in ["seamstress_running_stitch", "seamstress_running_stitch_plus",
			"seamstress_hemorrhage_hem", "seamstress_hemorrhage_hem_plus",
			"seamstress_red_thread", "seamstress_red_thread_plus"]:
		return true
	return _area_card(card_id)


## One authored pool card mounted alone in the real hand, checked against its
## detached catalog record: name, owner, cost, positions, rules and tooltip.
func _check_pool_face(card_id: String, definition: Dictionary) -> void:
	var metadata = app.get_node("LiveSupportHand")._metadata
	var panel := _panel_for(card_id)
	_check(panel != null, "authored pool card really mounted: " + card_id)
	if panel == null:
		return
	_check(panel.get_child_count() >= 1 and panel.get_child(0) is Label
		and not panel.get_child(0).is_visible_in_tree(),
		"identity label kept but raw ID never rendered: " + card_id)
	var facts: Dictionary = metadata.get_facts(panel)
	_check(facts.get("known") == true and facts.get("id") == card_id,
		"catalog-derived face facts: " + card_id)
	var binding: Dictionary = metadata._bindings.get(panel, {})
	_check(binding.get("id") == card_id and int(binding.get("draw_count", 0)) > 0
		and panel.draw.is_connected(binding.get("draw")),
		"real CanvasItem actually draws the pool face: " + card_id)
	_check(facts.get("display_name") == str(definition.get("display_name", "")),
		"authored display name on the face: " + card_id)
	var owner: String = str(definition.get("owner", ""))
	_check(facts.get("owner") == owner and facts.get("owner_text") == owner.capitalize(),
		"authored owner badge: " + card_id)
	var cost: int = int(definition.get("cost", -1))
	_check(facts.get("cost") == cost and facts.get("cost_text") == "Cost %d" % cost,
		"authored cost badge: " + card_id)
	_check(facts.get("from_text") == "From " + _face_positions(definition.get("from_positions", [])),
		"authored source positions on the face: " + card_id)
	var target_kind: String = str(definition.get("target_kind", ""))
	_check(target_kind in ["enemy_single", "enemy_all", "enemy_random", "self",
		"ally_single", "party_all", "none"], "authored target kind: " + card_id)
	var expected_target: String = _badge_target(target_kind, definition.get("to_positions", []))
	_check(facts.get("target_text") == expected_target,
		"authored target badge '%s': %s" % [expected_target, card_id])
	var rules: String = str(facts.get("rules", ""))
	_check(not rules.is_empty() and not rules.contains("BASE") and not rules.contains("Unknown"),
		"card line states readable short rules: " + card_id + " (" + rules + ")")
	_check(rules.length() <= 80, "card line stays short: " + card_id + " (" + rules + ")")
	for token in _expected_rule_tokens(card_id, definition):
		_check(rules.contains(token), "card line covers '%s': %s" % [token, card_id])
	var tooltip: String = panel.tooltip_text
	_check(tooltip.contains(str(definition.get("display_name", ""))),
		"mounted tooltip names the authored card: " + card_id)
	_check(not tooltip.contains("Unknown card") and not tooltip.contains("Rules unknown"),
		"no unknown placeholder for an authored card: " + card_id)
	# The mounted area adapter owns the tooltip for its own target-free families;
	# every other authored pool card keeps the shared precise tooltip.
	if not _area_card(card_id):
		var lines: PackedStringArray = tooltip.split("\n")
		var header := "%s; %s; %d energy" % [
			str(definition.get("display_name", "")), owner.capitalize(), cost]
		_check(lines.has(header), "tooltip exact header line: " + card_id)
		_check(lines.has("From " + _face_positions(definition.get("from_positions", []))),
			"tooltip exact from line: " + card_id)
		_check(lines.has(_precise_target(target_kind, definition.get("to_positions", []))),
			"tooltip exact target line: " + card_id)
		for phrase in _expected_tooltip_phrases(card_id, definition):
			_check(tooltip.contains(phrase), "tooltip states '%s': %s" % [phrase, card_id])
	var geometry: Dictionary = metadata.get_geometry(panel)
	_check(not geometry.is_empty(), "real panel measures a drawn card: " + card_id)
	if not geometry.is_empty():
		var bounds := Rect2(Vector2.ZERO, panel.size)
		for key in ["owner", "cost", "footer"]:
			var rect: Rect2 = geometry[key]
			_check(rect.size.x > 0.0 and rect.size.y > 0.0 and bounds.encloses(rect),
				"drawn %s stays inside the real card: %s" % [key, card_id])
		_check(geometry["owner"].end.x < geometry["cost"].position.x,
			"owner and cost patches never overlap: " + card_id)
	# Recognized display knowledge must never imply live admission.
	var admitted: bool = _pool_admitted(card_id)
	_check(panel.gui_input.get_connections().size() == (1 if admitted else 0),
		"pool card wired exactly when a presenter admits it: " + card_id)
	var visual: Dictionary = metadata.visual_state(panel)
	_check(bool(visual.get("playable", false)) == admitted,
		"full opening energy: playable look exactly for admitted cards: " + card_id)
	_check(panel.self_modulate.is_equal_approx(Color.WHITE) == admitted,
		"enabled colour only for admitted cards: " + card_id)
	if not admitted:
		_check(panel.focus_mode == Control.FOCUS_NONE,
			"unwired pool card takes no keyboard focus: " + card_id)
	var hitbox: Rect2 = panel.get_global_rect()
	metadata.sync(app.hand_view.get_children(), app.deck.hand)
	_check(panel.get_global_rect() == hitbox,
		"decoration preserves the original card hitbox: " + card_id)
	_check(root.get_visible_rect().encloses(panel.get_global_rect()),
		"whole pool card stays inside the 1280x720 viewport: " + card_id)


## Catalog expansion is display-only: every authored pool face is inspected from
## real mounted panels while admission, action handling and models stay put.
func _pool_faces() -> void:
	root.size = Vector2i(1280, 720)
	var ids: Array[String] = _pool_face_ids()
	_check(ids.size() >= 6 and not ids.has(""), "pool catalogs enumerate their base and '+' IDs")
	for required in ["warden_hold_the_line", "warden_hold_the_line_plus",
			"seamstress_running_stitch", "seamstress_running_stitch_plus",
			"tinker_ricochet", "tinker_ricochet_plus"]:
		_check(ids.has(required), "required authored pool ID present: " + required)
	# Three cards per real battle keeps every panel wide enough to draw while a
	# fresh battle (never a hand-side mutation) retires the inspected copies, so
	# no fixture step can look like a committed play to the quilt reconciler.
	var batch: Array[String] = []
	for card_id in ids:
		batch.append(card_id)
		if batch.size() >= 3:
			await _inspect_pool_batch(batch)
			batch = []
	if not batch.is_empty():
		await _inspect_pool_batch(batch)
	await _sewn_and_unknown_faces()
	await _admitted_pool_play()


func _open_battle(stage: String) -> bool:
	_check(app.deck == null, "fixture battle starts from the title: " + stage)
	app.run_seed = 42
	_fixture_start(app)
	await _frames()
	var ready: bool = app.deck is CombatDeck and app.party is CombatParty and app.enemies != null \
		and app.battle_result != null and app.run_rng != null \
		and is_instance_valid(app.battle_view) and is_instance_valid(app.hand_view)
	_check(ready, "real standalone battle: " + stage)
	if not ready:
		return false
	_check(app.deck.energy == CombatState.TURN_ENERGY, "full opening energy precondition: " + stage)
	var slots: Array[int] = []
	for hero in app.party.get_heroes():
		slots.append(int(hero.position))
		_check(int(hero.hp) > 0, "living authored hero precondition: " + str(hero.id))
	_check(slots == [1, 2, 3], "authored front/middle/back roster precondition: " + stage)
	return true


func _close_battle(stage: String) -> void:
	app.return_button.pressed.emit()
	await _frames()
	_check(app.deck == null and app.run_rng == null and app.title_view.is_visible_in_tree(),
		"fixture battle returns to a clean title: " + stage)
	_check(app.get_node("LiveSupportHand")._metadata._bindings.is_empty(),
		"fixture battle leaves no stale decoration: " + stage)


## Mount a batch of authored pool cards through the real deck draw and compare
## every real panel against its detached catalog record.
func _inspect_pool_batch(batch: Array[String]) -> void:
	if not await _open_battle("pool faces"):
		return
	var metadata = app.get_node("LiveSupportHand")._metadata
	var rng_seed: int = app.run_rng.seed
	var rng_state: int = app.run_rng.state
	var roster: Array = app.party.get_heroes()
	var enemy_roster: Array = app.enemies.get_enemies()
	for card_id in batch:
		var definition: Dictionary = _pool_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			"detached authored catalog record: " + card_id)
		if definition.is_empty():
			continue
		app.deck.draw_pile.append(card_id)
		_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == card_id,
			"real deck draws the authored pool card: " + card_id)
		app._refresh_hand()
		await _frames()
		_check(app.hand_view.get_child_count() == app.deck.hand.size(),
			"real hand panels match the drawn hand: " + card_id)
		_check_pool_face(card_id, definition)
		if card_id == "warden_pinning_jab":
			var panel := _panel_for(card_id)
			var before := _combat_state()
			await _click_center(panel)
			_check(_combat_state() == before and app.get_node("LiveSupportHand")._pending.is_empty(),
				"recognized but unwired pool card rejects real pointer input: " + card_id)
	_check(app.run_rng.seed == rng_seed and app.run_rng.state == rng_state,
		"drawing and decorating pool faces consumes no run RNG")
	_check(app.party.get_heroes() == roster and app.enemies.get_enemies() == enemy_roster,
		"drawing and decorating pool faces mutates no actor")
	_check(app.deck.energy == CombatState.TURN_ENERGY, "catalog display consumes no energy")
	await _close_battle("pool faces")


## Authentic Rest ledger pair of two authored starter halves: both ordered names,
## owners and effects must be readable together on the real mounted panel, with a
## genuinely unauthored card beside it staying fail-closed.
func _sewn_and_unknown_faces() -> void:
	if not await _open_battle("sewn pair and unknown card"):
		return
	var metadata = app.get_node("LiveSupportHand")._metadata
	var ledger := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors,
		RunRestStitchCards.SCRAP_COST, app.run_next_stitch_id)
	_check(ledger.is_valid(), "real run ledger accepts the starter run deck")
	if not ledger.is_valid():
		await _close_battle("sewn pair and unknown card")
		return
	var first_index: int = app.run_deck.find("warden_brace")
	var second_index: int = app.run_deck.find("seamstress_mend")
	_check(first_index >= 0 and second_index >= 0 and first_index != second_index,
		"two authored starter halves of different owners are really in the run deck")
	if first_index < 0 or second_index < 0 or first_index == second_index:
		await _close_battle("sewn pair and unknown card")
		return
	var made: Dictionary = ledger.choose_stitch(first_index, second_index, ledger.get_snapshot())
	_check(bool(made.get("ok", false)), "real Rest stitch allocates the composite")
	if not bool(made.get("ok", false)):
		await _close_battle("sewn pair and unknown card")
		return
	var descriptor: Dictionary = made.get("descriptor", {})
	var pair: Array = descriptor.get("half_ids", [])
	_check(pair == ["warden_brace", "seamstress_mend"], "real ledger keeps authored half order")
	app.run_deck.assign(made.get("deck", []))
	app.run_stitch_descriptors = made.get("descriptors", {})
	app.run_scraps = int(made.get("remaining_scraps", 0))
	app.run_next_stitch_id = int(made.get("next_stitch_id", 2))
	_check(app._stitch_snapshot() == RunRestStitchCards.new(app.run_deck,
		app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id).get_snapshot(),
		"committed Rest receipt is the authoritative stitch snapshot")
	var stitched_id: String = str(made.get("stitched_id", ""))
	_check(stitched_id.begins_with(RunRestStitchCards.ID_PREFIX), "ledger allocated the stitched ID")
	app.deck.draw_pile.append(stitched_id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == stitched_id,
		"real deck draws the sewn card")
	app._refresh_hand()
	await _frames()
	var panel := _panel_for(stitched_id)
	_check(panel != null and metadata._bindings.has(panel), "sewn card mounted on the real hand")
	if panel != null and metadata._bindings.has(panel):
		var facts: Dictionary = metadata.get_facts(panel)
		_check(facts.get("known") == true and facts.get("halves", []) == pair,
			"face facts carry the ledger's ordered halves")
		var first: Dictionary = metadata.definition(str(pair[0]))
		var second: Dictionary = metadata.definition(str(pair[1]))
		_check(not first.is_empty() and not second.is_empty() and first.get("owner") != second.get("owner"),
			"both halves are distinct authored records")
		_check(facts.get("display_name") == str(descriptor.get("display_name", "")),
			"ledger display name on the sewn face")
		_check(facts.get("cost") == int(descriptor.get("cost", -1)), "shared stitched cost on the face")
		_check(facts.get("owner_text") == "Stitched", "stitched owner badge")
		_check(metadata._owner_color(str(first.get("owner", ""))) \
			!= metadata._owner_color(str(second.get("owner", ""))),
			"ordered halves keep distinct owner colours")
		var tooltip: String = panel.tooltip_text
		_check(tooltip.begins_with("1. Brace; Warden; 1 energy"),
			"first ordered half named precisely: " + tooltip)
		_check(tooltip.contains("\n2. Mend; Seamstress; 1 energy"),
			"second ordered half named precisely: " + tooltip)
		_check(tooltip.find("1. ") < tooltip.find("2. "), "tooltip keeps the resolution order")
		_check(tooltip.contains("BASE gain 7 Block") and tooltip.contains("BASE heal 5 HP, capped at max HP"),
			"each half keeps its own precise effect")
		_check(tooltip == metadata.stitched_tooltip(pair), "mounted tooltip is the ordered two-part tooltip")
		var geometry: Dictionary = metadata.get_geometry(panel)
		var rows: Array = geometry.get("halves", [])
		_check(rows.size() == 2, "two separately labelled stitched rows")
		if rows.size() == 2:
			var bounds := Rect2(Vector2.ZERO, panel.size)
			_check(rows[0].position.y < rows[1].position.y and rows[0].end.y <= rows[1].position.y,
				"ordered stitched rows never overlap")
			_check(bounds.encloses(rows[0]) and bounds.encloses(rows[1]),
				"both stitched rows fit the real panel")
		_check(panel.gui_input.get_connections().size() == 1
			and bool(metadata.visual_state(panel).get("playable", false)),
			"sewn card still plays through the real presenter")
	# Exactly the metadata feed the mounted tooltip uses, but for formerly
	# unrecognized pool halves: ordered authored names, owners and precise rules.
	var pool_pair: Array = ["seamstress_needle_pin", "tinker_ricochet"]
	var pool_tooltip: String = metadata.stitched_tooltip(pool_pair)
	_check(pool_tooltip.begins_with("1. Needle Pin; Seamstress; 1 energy")
		and pool_tooltip.contains("\n2. Ricochet; Tinker; 1 energy"),
		"formerly unrecognized pool halves keep ordered names and owners")
	_check(pool_tooltip.contains("BASE deal 3 damage") and pool_tooltip.contains("BASE Pin the target")
		and pool_tooltip.contains("4 damage in 3 hits") and pool_tooltip.contains("random living enemy"),
		"pool half tooltips keep each half's precise authored rules")
	var stale_tooltip: String = metadata.stitched_tooltip(["seamstress_needle_pin", "unauthored_half"])
	_check(stale_tooltip.contains("\n2. Unknown card") and not stale_tooltip.contains("unauthored_half"),
		"an unauthored stitched half stays an honest placeholder, never a raw ID")
	# A stale registry must fail closed on the real mounted panel.
	app.run_stitch_descriptors.clear()
	app._refresh_hand()
	await _frames()
	var stale_panel := _panel_for(stitched_id)
	_check(stale_panel != null and metadata.get_facts(stale_panel).get("known", true) == false,
		"a stale stitched registry fails closed on the held panel")
	_check(stale_panel != null and stale_panel.tooltip_text == "Unknown card",
		"a stale stitched card invents no half rules")
	await _unknown_pool_face(metadata)
	await _close_battle("sewn pair and unknown card")


## A genuinely unauthored ID keeps the exact fail-closed face and never invents
## a rule, a badge or an input handler.
func _unknown_pool_face(metadata) -> void:
	var unknown := "cycle141_unreleased_card"
	_check(metadata.definition(unknown).is_empty() and _pool_definition(unknown).is_empty(),
		"chosen fail-closed ID is really unauthored")
	app.deck.draw_pile.append(unknown)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == unknown,
		"real deck can hold an unauthored card")
	app._refresh_hand()
	await _frames()
	var panel := _panel_for(unknown)
	_check(panel != null and metadata._bindings.has(panel), "unauthored card mounted honestly")
	if panel == null:
		return
	var facts: Dictionary = metadata.get_facts(panel)
	_check(facts.get("known") == false and facts.get("owner_text") == "Unknown"
		and facts.get("cost_text") == "Cost ?" and facts.get("display_name") == ""
		and facts.get("rules") == "", "unknown ID keeps the exact placeholder facts")
	_check(panel.tooltip_text == "Unknown card", "unknown tooltip invents no rules")
	_check(panel.gui_input.get_connections().is_empty()
		and panel.focus_mode == Control.FOCUS_NONE, "unknown card stays inert")
	var before := _combat_state()
	await _click_center(panel)
	_check(_combat_state() == before, "clicking an unauthored card changes nothing")


## Playing an admitted pool card through the real mounted hand still spends,
## discards and resolves its authored effect, exactly as before this expansion.
func _admitted_pool_play() -> void:
	if not await _open_battle("admitted pool play"):
		return
	var card_id := "warden_hold_the_line"
	var definition: Dictionary = _pool_definition(card_id)
	app.deck.draw_pile.append(card_id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == card_id,
		"real deck draws the admitted Block card")
	app._refresh_hand()
	await _frames()
	var panel := _panel_for(card_id)
	_check(panel != null and panel.focus_mode == Control.FOCUS_ALL
		and panel.gui_input.get_connections().size() == 1,
		"admitted pool card keeps its mounted input binding")
	if panel == null:
		await _close_battle("admitted pool play")
		return
	var before := _combat_state()
	var energy: int = app.deck.energy
	await _click_center(panel)
	_check(app.deck.energy == energy - int(definition.get("cost", -1)),
		"admitted pool play spends exactly its authored cost")
	_check(app.deck.discard_pile.back() == card_id and not app.deck.hand.has(card_id),
		"admitted pool play discards exactly the played copy")
	_check(app.party.get_hero(1).block == int(before[5][0].block) + 5,
		"admitted pool play resolves the authored Warden Block")
	_check(app.party.get_hero(2).block == int(before[5][1].block) + 2,
		"admitted pool play resolves the authored other-ally Block")
	_check(app.run_rng.state == int(before[9]), "admitted pool play consumes no run RNG")
	_check(app.battle_result.get_outcome() == before[10], "admitted pool play leaves the outcome alone")
	await _close_battle("admitted pool play")

