extends SceneTree
## Mounted shared-hand coverage for the two authored Blanket Stitch Bleed pool
## cards, cast from the real held hand through the mounted LiveAreaAttackAction
## adapter. Expected Bleed is derived independently from the authored catalog
## (printed Bleed + the Seamstress passive) and the complete post-state is
## compared with the scene-free CombatSeamstressPoolBleed resolver fed the same
## seeded pre-state, never with the mounted adapter's own return value.

const INSTRUCTION := "Click or focus and press Enter / Space to play"
const IDS := ["seamstress_blanket_stitch", "seamstress_blanket_stitch_plus"]
## A genuinely unauthored ID: since cycle 141 every authored pool record now has a
## readable shared face, so fail-closed coverage needs an ID no catalog knows.
const OTHER_UNKNOWN := "seamstress_unreleased_card"
const SEED := 42

var failures: Array[String] = []
var checks := 0
var app
var adapter
var catalog := SeamstressPoolCards.new()


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	await process_frame
	await process_frame
	await process_frame


func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func _keyboard(code: Key) -> void:
	root.push_input(_key(code), true)
	root.push_input(_key(code, false), true)
	await _frames()


## Physical pointer activation. A duplicate press in the same dispatch must still
## resolve the cast exactly once.
func _mouse(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		if pressed:
			root.push_input(event, true)
	await _frames()


func _press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _panel(card_id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and panel.get_child(0).text == card_id:
			return panel
	return null


## draw, hand, discard, energy, turn, heroes, enemies, intents, intent text,
## run RNG seed/state, outcome, session gold, deck RNG state, closed latch.
func _state() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(),
		app.intent_label.text, app.run_rng.seed, app.run_rng.state,
		app.battle_result.get_outcome(), app.session_gold, app.deck._rng.state,
		app._battle_closed]


## Independent scene-free expectation: real seeded deck, real party and roster
## restored from the same pre-cast snapshot, resolved by the authored service.
func _oracle(card_id: String, before: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(before[10])
	rng.state = int(before[11])
	var deck := CombatDeck.new([], rng)
	deck.draw_pile.assign(before[0])
	deck.hand.assign(before[1])
	deck.discard_pile.assign(before[2])
	deck.combat_state.player_turn_active = bool(before[4])
	deck.combat_state.energy = int(before[3])
	var party := CombatParty.new(app._load_party_definitions())
	party._heroes.assign((before[5] as Array).duplicate(true))
	var definitions: Array[Dictionary] = []
	for enemy in (before[6] as Array):
		definitions.append({"id": String(enemy["id"]), "max_hp": int(enemy["max_hp"])})
	var enemies := CombatEnemies.new(definitions)
	enemies._enemies.assign((before[6] as Array).duplicate(true))
	var event: Dictionary = CombatSeamstressPoolBleed.new().play_card(deck, party, enemies, card_id, 0)
	return {"event": event, "draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"turn": deck.turn_active, "party": party.get_heroes(),
		"enemies": enemies.get_enemies(), "rng_state": deck._rng.state}


## Visible status chips of one mounted enemy ribbon, in ribbon order.
func _chips(position: int) -> Array[String]:
	var texts: Array[String] = []
	var meters = app.get_node_or_null("LiveCombatMeters")
	if meters == null or not is_instance_valid(meters.row):
		return texts
	var index: int = CombatParty.PARTY_SIZE + position - 1
	if index < 0 or index >= meters.row.get_child_count():
		return texts
	var buttons: Node = meters.row.get_child(index).get_node_or_null("Padding/Content/StatusButtons")
	if buttons == null:
		return texts
	for button in buttons.get_children():
		if button is Button and button.visible and not String(button.text).is_empty():
			texts.append(String(button.text))
	return texts


func _chip_shows(position: int, status: String, amount: int) -> bool:
	var prefix := status.substr(0, 3).capitalize()
	for text in _chips(position):
		if text.begins_with(prefix) and text.ends_with(" %d" % amount):
			return true
	return false


func _bleed_total(enemy: Dictionary) -> int:
	return int(enemy.get("statuses", {}).get("bleed", 0))


## The real panel must show the authored identity as visible text, not only as
## the hidden source Label or a mouse-only tooltip. The sewn face prints the
## authored name, cost and one compact rule plus drawn position pips; the
## positions, passive and target policy live in the detailed tooltip.
func _assert_face(panel: Control, card_id: String, stage: String) -> void:
	var definition: Dictionary = catalog.get_definition(card_id)
	var effects: Dictionary = definition.get("effects", {})
	var effective_bleed: int = int(effects.get("bleed", 0)) + 1
	var face: Dictionary = adapter.face_text(panel)
	_check(not face.is_empty(), "adapter mounts a readable face: " + stage)
	_check(face.get("name", "") == definition.get("display_name", ""),
		"visible face shows the authored card name: " + stage)
	_check(face.get("name", "") != "Unknown card" and face.get("name", "").contains("Blanket Stitch"),
		"visible face never says Unknown card: " + stage)
	_check(face.get("cost", "").contains(str(int(definition.get("cost", -1))))
		and face.get("cost", "").contains("energy"),
		"visible face shows the authored cost: " + stage)
	var upgraded: bool = card_id.ends_with("_plus")
	_check(face.get("name", "").ends_with("+") == upgraded,
		"visible face keeps the authored '+' upgrade suffix: " + stage)
	_check(face.get("effect", "") == "Bleed %d to all." % effective_bleed,
		"visible face prints the short effective Bleed rule: " + stage)
	var shown: String = "%s %s %s" % [str(face.get("name", "")), str(face.get("cost", "")),
		str(face.get("effect", ""))]
	for jargon in ["From", "Target", "No target choice", "living", "first attack",
			"passive", "Base", "base +"]:
		_check(not shown.contains(jargon), "face never prints '%s': %s" % [jargon, stage])
	# Three small source circles and three small target squares, drawn from the
	# authored positions, with a thread only for the simultaneous all-enemy cast.
	var from_positions: Array = definition.get("from_positions", [])
	var to_positions: Array = definition.get("to_positions", [])
	var from_pips: Array = face.get("from_pips", [])
	var to_pips: Array = face.get("to_pips", [])
	_check(from_pips.size() == 3 and to_pips.size() == 3,
		"face reports exactly three source and three target pips: " + stage)
	for index in range(mini(from_pips.size(), 3)):
		_check(bool(from_pips[index]) == from_positions.has(index + 1),
			"source pip %d matches the authored from positions: %s" % [index + 1, stage])
		_check(bool(to_pips[index]) == to_positions.has(index + 1),
			"target pip %d matches the authored to positions: %s" % [index + 1, stage])
	_check(bool(face.get("thread", false)) == (definition.get("target_kind") == "enemy_all"),
		"only an every-enemy cast stitches its target squares: " + stage)
	var cue = adapter._bindings[panel].get("cue")
	_check(is_instance_valid(cue) and cue.get_parent() == panel and cue.is_visible_in_tree(),
		"the readable face is mounted and visible on the real panel: " + stage)
	if is_instance_valid(cue):
		_check(cue is Control and absf(cue.size.x - panel.size.x) < 1.0
			and absf(cue.size.y - panel.size.y) < 1.0,
			"the readable face covers the whole held panel: " + stage)
		_check(cue.get_index() > panel.get_child(0).get_index(),
			"the readable face draws above the hidden raw ID label: " + stage)
		_check(cue.mouse_filter == Control.MOUSE_FILTER_IGNORE and cue.focus_mode == Control.FOCUS_NONE,
			"the readable face never intercepts input or focus: " + stage)
		# Genuinely mounted children, not a detached layout.
		var nodes: Array = adapter.face_children(panel)
		var visible := 0
		for node in nodes:
			if node is Control and node.is_visible_in_tree() and node.size.x > 0 and node.size.y > 0 \
					and node.mouse_filter != Control.MOUSE_FILTER_STOP:
				visible += 1
		_check(nodes.size() >= 13 and visible == nodes.size(),
			"every face child is attached, visible, sized and never takes input: " + stage)
		_check(cue.get_child_count() == 1 and cue.get_child(0) is MarginContainer
			and cue.get_child(0).is_visible_in_tree(),
			"cue mounts its margin/content child instead of leaving it detached: " + stage)
		for index in range(3):
			var from_pip = cue.find_child("From%d" % (index + 1), true, false)
			var to_pip = cue.find_child("To%d" % (index + 1), true, false)
			var from_style = from_pip.get_theme_stylebox("panel") if from_pip is Panel else null
			var to_style = to_pip.get_theme_stylebox("panel") if to_pip is Panel else null
			_check(from_style is StyleBoxFlat and from_pip.is_visible_in_tree()
				and _pip_filled(from_pip) == from_positions.has(index + 1)
				and (not from_positions.has(index + 1) or from_style.bg_color == Color("#6e4f6b"))
				and from_style.corner_radius_top_left * 2 >= int(from_pip.size.x),
				"mounted circular source pip %d shows authored legality: %s" % [index + 1, stage])
			_check(to_style is StyleBoxFlat and to_pip.is_visible_in_tree()
				and _pip_filled(to_pip) == to_positions.has(index + 1)
				and (not to_positions.has(index + 1) or to_style.bg_color == Color("#6e4f6b"))
				and to_style.corner_radius_top_left == 0,
				"mounted square target pip %d shows its authored slot: %s" % [index + 1, stage])
			_check(cue.get_global_rect().grow(1.0).encloses(from_pip.get_global_rect())
				and cue.get_global_rect().grow(1.0).encloses(to_pip.get_global_rect()),
				"source and target pip %d stay inside the sewn face: %s" % [index + 1, stage])
		_assert_thread(cue, definition, stage)
	_check(not panel.get_child(0).is_visible_in_tree(),
		"the raw source label stays hidden behind the readable face: " + stage)
	for key in ["cue_name", "cue_cost", "cue_effect"]:
		var label = adapter._bindings[panel].get(key)
		_check(is_instance_valid(label) and label.is_visible_in_tree()
			and not String(label.text).is_empty() and label.size.x > 0 and label.size.y > 0
			and is_instance_valid(cue) and cue.is_ancestor_of(label),
			"visible face label is rendered (%s): %s" % [key, stage])


## A pip is filled when its sewn style has a real background colour.
func _pip_filled(pip: Control) -> bool:
	var style = pip.get_theme_stylebox("panel")
	return style is StyleBoxFlat and style.bg_color.a > 0.0


## The stitched thread is measured from the mounted nodes: every authored target
## square is crossed through its centre by a real drawn stitch, the source
## circles are never stitched, and a random-target face mounts no thread.
func _assert_thread(cue: Control, definition: Dictionary, stage: String) -> void:
	var all_enemy: bool = definition.get("target_kind") == "enemy_all"
	var thread = cue.find_child("Thread", true, false)
	_check((thread != null) == all_enemy,
		"only the all-enemy face draws a stitched thread: " + stage)
	if not thread is Control:
		return
	_check(thread.is_visible_in_tree() and thread.mouse_filter != Control.MOUSE_FILTER_STOP
		and thread.focus_mode == Control.FOCUS_NONE,
		"the stitched thread is visible and never takes input: " + stage)
	var stitches: Array[Rect2] = []
	for child in thread.get_children():
		if child is ColorRect and String(child.name).begins_with("Stitch") \
				and child.is_visible_in_tree() and child.size.x > 0 and child.size.y > 0:
			stitches.append((child as ColorRect).get_global_rect())
	var to_positions: Array = definition.get("to_positions", [])
	_check(stitches.size() >= 2 * to_positions.size() - 1,
		"the thread mounts one stitch per target square and gap: " + stage)
	var face_rect: Rect2 = cue.get_global_rect()
	var on_face := true
	for stitch in stitches:
		if not face_rect.grow(1.0).encloses(stitch):
			on_face = false
	_check(on_face, "every drawn stitch stays inside the visible sewn face: " + stage)
	for index in range(3):
		var square: Rect2 = (cue.find_child("To%d" % (index + 1), true, false) as Control).get_global_rect()
		var source: Rect2 = (cue.find_child("From%d" % (index + 1), true, false) as Control).get_global_rect()
		var linked := false
		var crossed_source := false
		for stitch in stitches:
			if stitch.intersects(square) and stitch.position.y <= square.get_center().y \
					and stitch.end.y >= square.get_center().y:
				linked = true
			if stitch.intersects(source):
				crossed_source = true
		_check(linked == to_positions.has(index + 1),
			"thread runs through target square %d exactly when authored: %s" % [index + 1, stage])
		_check(not crossed_source,
			"thread never crosses source circle %d: %s" % [index + 1, stage])


func _display(card_id: String, stage: String) -> void:
	var panel := _panel(card_id)
	_check(is_instance_valid(panel), "real held blank stitch panel mounted: " + card_id)
	if panel == null:
		return
	var definition: Dictionary = catalog.get_definition(card_id)
	_check(definition.get("id") == card_id and definition.get("owner") == "seamstress",
		"authored catalog record backs the mounted card: " + card_id)
	_check(adapter._bindings.has(panel) and adapter._bindings[panel]["id"] == card_id,
		"the mounted adapter owns exactly this held card: " + card_id)
	_check(panel.gui_input.get_connections().size() == 1,
		"exactly one input binding per held instance: " + card_id)
	_check(panel.focus_mode == Control.FOCUS_ALL and panel.mouse_filter == Control.MOUSE_FILTER_STOP,
		"card is both keyboard focusable and pointer reachable: " + card_id)
	_check(panel.tooltip_text.begins_with(INSTRUCTION), "mounted play instruction: " + card_id)
	_check(panel.tooltip_text.contains(definition.get("display_name", "")),
		"catalog display name in the card tooltip: " + card_id)
	_check(panel.tooltip_text.contains("All living enemies"),
		"target-free all-enemy rule stated on the card: " + card_id)
	# The detailed tooltip keeps everything the compact face leaves out.
	var effects: Dictionary = definition.get("effects", {})
	var printed_bleed: int = int(effects.get("bleed", 0))
	_check(panel.tooltip_text.contains("From %s" % adapter._positions(definition.get("from_positions", [])))
		and panel.tooltip_text.contains("All living enemies %s" % adapter._positions(
			definition.get("to_positions", [])))
		and panel.tooltip_text.contains("Bleed %d (%d + Seamstress passive 1)" % [
			printed_bleed + 1, printed_bleed])
		and panel.tooltip_text.contains("no target choice")
		and panel.tooltip_text.contains("Enter / Space"),
		"tooltip keeps positions, passive and target-free rules: " + card_id)
	_assert_face(panel, card_id, stage)
	_check(panel.get_child(0).text == card_id, "original identity label retained: " + card_id)
	# Only the two authored IDs are claimed; the other presenters keep their cards.
	_check(not app.get_node("LiveSupportHand")._bindings.has(panel),
		"support presenter does not claim the area card: " + card_id)
	_check(not app.get_node("LiveAttackPreview")._bindings.has(panel),
		"attack presenter does not claim the area card: " + card_id)
	for other in app.hand_view.get_children():
		if other == panel or other.get_child_count() < 1 or not other.get_child(0) is Label:
			continue
		var other_id: String = other.get_child(0).text
		if other_id in IDS:
			continue
		_check(not adapter._bindings.has(other),
			"adapter never claims another held card (%s): %s" % [other_id, card_id])
		break
	# No parallel combat control of any kind is mounted for this card.
	_check(adapter.button == null and app.get_node("LiveAreaAttackAction").button == null,
		"no separate area combat button exists: " + card_id)
	_check(app.get_node("LiveAreaAttackAction").get_child_count() == 1
		and app.get_node("LiveAreaAttackAction/LiveSeamstressSingleBleedHand") != null,
		"area adapter mounts only the single-enemy child, not a competing control: " + card_id)
	_check(app.get_node("LiveSupportHand").energy_label.text == "%d" % app.deck.energy,
		"shared energy display is authoritative: " + stage)
	_check(not panel.focus_neighbor_bottom.is_empty()
		and panel.get_node_or_null(panel.focus_neighbor_bottom) == app.end_turn_button,
		"keyboard focus can leave the held area card for End Turn: " + card_id)


## Independent full post-state: only the authored cost, the single discarded copy
## and the Bleed of every living enemy slot may differ from the pre-cast snapshot.
func _assert_success(card_id: String, before: Array, stage: String) -> void:
	var definition: Dictionary = catalog.get_definition(card_id)
	var cost: int = int(definition.get("cost", -1))
	var amount: int = int(definition.get("effects", {}).get("bleed", 0)) + 1
	_check(cost > 0 and before[3] >= cost, "authored cost is affordable before the cast: " + stage)
	_check(app.deck.energy == int(before[3]) - cost, "exactly one authored energy payment: " + stage)
	var expected_hand: Array = before[1].duplicate()
	expected_hand.erase(card_id)
	_check(app.deck.hand == expected_hand and not app.deck.hand.has(card_id),
		"exactly one held copy leaves the hand: " + stage)
	var expected_discard: Array = before[2].duplicate()
	expected_discard.append(card_id)
	_check(app.deck.discard_pile == expected_discard and app.deck.discard_pile.back() == card_id,
		"played card lands in the discard pile once: " + stage)
	_check(app.deck.draw_pile == before[0], "draw pile is never reshuffled: " + stage)
	_check(app.deck.turn_active == before[4], "turn state unchanged: " + stage)
	_check(app.party.get_heroes() == before[5], "party HP, Block and statuses unchanged: " + stage)
	var expected_enemies: Array = (before[6] as Array).duplicate(true)
	var living := 0
	for enemy in expected_enemies:
		if int(enemy.get("hp", 0)) > 0:
			living += 1
	for enemy in expected_enemies:
		if int(enemy.get("hp", 0)) <= 0:
			continue
		if not enemy.get("statuses", {}) is Dictionary:
			continue
		if not enemy.has("statuses"):
			enemy["statuses"] = {}
		enemy["statuses"]["bleed"] = _bleed_total(enemy) + amount
	_check(app.enemies.get_enemies() == expected_enemies,
		"every living enemy slot gains exactly the authored Bleed plus passive: " + stage)
	for enemy in app.enemies.get_enemies():
		if int(enemy.get("hp", 0)) > 0:
			_check(_chip_shows(int(enemy["position"]), "bleed", _bleed_total(enemy)),
				"mounted enemy status display shows the new Bleed (%d): %s" % [int(enemy["position"]), stage])
	_check(app.enemy_attacks == before[7], "enemy attacks unchanged: " + stage)
	_check(app.enemy_intents.get_intents() == before[8], "enemy intents unchanged: " + stage)
	_check(app.intent_label.text == before[9], "intent display unchanged: " + stage)
	_check(app.run_rng.seed == before[10] and app.run_rng.state == before[11],
		"injected run RNG untouched: " + stage)
	_check(app.deck._rng.state == before[14], "injected deck RNG untouched: " + stage)
	_check(app.battle_result.get_outcome() == before[12] and app._battle_closed == before[15],
		"battle outcome unchanged: " + stage)
	_check(app.session_gold == before[13], "session gold unchanged: " + stage)
	_check(is_instance_valid(app.hand_view) and app.hand_view.get_child_count() == app.deck.hand.size(),
		"mounted hand matches the post-cast hand: " + stage)
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
		app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		"pile counts refreshed: " + stage)
	_check(app.result_label.is_visible_in_tree() == app.battle_result.is_finished(),
		"outcome display follows the live result: " + stage)
	_check(adapter._pending.is_empty(), "a resolved cast leaves no pending receipt: " + stage)
	# Same seeded pre-state through the scene-free resolver: exact same outcome.
	var oracle := _oracle(card_id, before)
	_check(oracle.event.get("ok", false) and oracle.event.hits.size() == living,
		"scene-free resolver accepts the same pre-state for every living slot: " + stage)
	_check(app.deck.hand == oracle.hand and app.deck.draw_pile == oracle.draw
		and app.deck.discard_pile == oracle.discard,
		"piles equal the scene-free resolver: " + stage)
	_check(app.deck.energy == oracle.energy, "energy equals the scene-free resolver: " + stage)
	_check(app.party.get_heroes() == oracle.party and app.enemies.get_enemies() == oracle.enemies,
		"party and enemy statuses equal the scene-free resolver: " + stage)
	_check(app.deck._rng.state == oracle.rng_state and app.deck.turn_active == oracle.turn,
		"seeded deck state equals the scene-free resolver: " + stage)


func _start(card_id: String) -> bool:
	_check(app.deck == null, "the title precedes a fresh mounted battle")
	app.run_seed = SEED
	_fixture_start(app)
	await _frames()
	var ready: bool = app.deck is CombatDeck and app.party is CombatParty and app.enemies != null \
		and app.battle_result != null and app.run_rng != null and is_instance_valid(app.battle_view) \
		and is_instance_valid(app.hand_view) and app.enemies.get_enemies().size() == 2
	_check(ready, "real standalone battle starts complete with two living enemies")
	if not ready:
		return false
	# The run deck owns pool cards in live play; put one authored copy through the
	# real deck draw so the mounted panel is exactly what a run would hold.
	app.deck.draw_pile.append(card_id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == card_id,
		"real deck draws the authored pool card: " + card_id)
	app._refresh_hand()
	await _frames()
	return _panel(card_id) != null


func _return() -> void:
	if is_instance_valid(app.return_button):
		app.return_button.pressed.emit()
	await _frames()


func _play_from_hand(card_id: String, keyboard: bool, code: Key = KEY_ENTER) -> void:
	if not await _start(card_id):
		await _return()
		return
	_display(card_id, "before " + card_id)
	var panel := _panel(card_id)
	var callback: Callable = adapter._bindings[panel]["callback"]
	var old_cue = adapter._bindings[panel].get("cue")
	var before := _state()
	if keyboard:
		panel.grab_focus()
		_check(panel.has_focus(), "keyboard path focuses the real held panel: " + card_id)
		await _keyboard(code)
	else:
		await _mouse(panel)
	_assert_success(card_id, before, card_id)
	_check(not is_instance_valid(old_cue), "the cast hand rebuild retires the consumed cue: " + card_id)
	# A target-free area cast never arms a target choice.
	var support = app.get_node("LiveSupportHand")
	var attack = app.get_node("LiveAttackPreview")
	_check(support._pending.is_empty() and support._targets.is_empty()
		and not support.cancel_button.visible, "no target choice was armed: " + card_id)
	for hero in app.hero_panels:
		_check(hero.focus_mode == Control.FOCUS_NONE, "hero slots never become cast targets: " + card_id)
	_check(attack._armed == null, "the attack presenter never armed the area card: " + card_id)
	var after := _state()
	callback.call(_key(KEY_ENTER))
	await _frames()
	_check(_state() == after, "replaying the captured callback cannot charge twice: " + card_id)
	await _return()


## A real hand holding both authored variants plus a genuinely unauthored card:
## both Blanket Stitch faces must be readable without hovering, while the third
## panel keeps the shared presenter's own unknown placeholder untouched.
func _mixed_hand_faces() -> void:
	if not await _start("seamstress_blanket_stitch"):
		await _return()
		return
	app.deck.draw_pile.append("seamstress_blanket_stitch_plus")
	app.deck.draw_pile.append(OTHER_UNKNOWN)
	_check(app.deck.draw_extra(2) == 2 and app.deck.hand.has("seamstress_blanket_stitch_plus")
		and app.deck.hand.has(OTHER_UNKNOWN),
		"the real hand also holds the '+' and a genuinely unauthored card")
	app._refresh_hand()
	await _frames()
	var base_panel := _panel("seamstress_blanket_stitch")
	var plus_panel := _panel("seamstress_blanket_stitch_plus")
	var other_panel := _panel(OTHER_UNKNOWN)
	_check(is_instance_valid(base_panel) and is_instance_valid(plus_panel)
		and is_instance_valid(other_panel), "all three real held panels are mounted")
	if not (is_instance_valid(base_panel) and is_instance_valid(plus_panel)
			and is_instance_valid(other_panel)):
		await _return()
		return
	_assert_face(base_panel, "seamstress_blanket_stitch", "mixed hand base")
	_assert_face(plus_panel, "seamstress_blanket_stitch_plus", "mixed hand plus")
	var base_face: Dictionary = adapter.face_text(base_panel)
	var plus_face: Dictionary = adapter.face_text(plus_panel)
	_check(base_face.get("name") != plus_face.get("name")
		and String(plus_face.get("name", "")).ends_with("+"),
		"the base and '+' faces are visibly distinct")
	# A different unadvertised pool card is left entirely to the shared presenter.
	_check(not adapter._bindings.has(other_panel),
		"the adapter never claims a different unknown pool card")
	_check(other_panel.get_node_or_null(adapter.CUE_NAME) == null,
		"a different unknown pool card gets no adapter cue")
	_check(other_panel.get_child_count() == 1 and other_panel.get_child(0).text == OTHER_UNKNOWN,
		"the third panel keeps its original content")
	var metadata = app.get_node("LiveSupportHand")._metadata
	_check(not bool(metadata.describe(OTHER_UNKNOWN).get("known", true)),
		"the third card is genuinely unadvertised by the shared presenter")
	await _return()
	_check(adapter._bindings.is_empty(), "leaving the mixed hand clears every cue binding")


## A real seeded production Fight with three enemies, entered through the run map.
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
			var selected := RunAuthoredBattleEntry.new().entry_current_battle(
				map, rng, RunFightEncounterSelection.new())
			map.undo_choice(id, [])
			if selected.get("success", false) and selected["enemies"].get_enemies().size() == 3:
				return {"seed": value, "fight": id, "encounter": selected["encounter_id"]}
	return {}


func _three_enemy_case() -> void:
	var fixture := _three_enemy_fixture()
	_check(not fixture.is_empty(), "the authored Fight rotation offers a three-enemy roster")
	if fixture.is_empty():
		return
	_check(app.deck == null, "the title precedes the routed run")
	app.run_seed = int(fixture.seed)
	app.start_button.pressed.emit()
	preload("res://tests/party_choice.gd").choose(app)
	await _frames()
	var route_button: Button = null
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == fixture.fight:
			route_button = candidate
			break
	_check(route_button != null and not route_button.disabled,
		"the three-enemy Fight has a real enabled route control")
	if route_button == null:
		return
	route_button.pressed.emit()
	await _frames()
	var ready: bool = app.deck != null and app.enemies != null and app.party != null \
		and app.enemies.get_enemies().size() == 3
	_check(ready, "the mounted routed battle really holds three original enemy slots")
	if not ready:
		return
	var card_id := "seamstress_blanket_stitch_plus"
	# Real roster API: the middle slot dies after route entry, before the cast.
	_check(app.enemies.apply_damage(2, 10000) and app.enemies.is_slain(2),
		"the middle original enemy slot is genuinely slain")
	app._refresh_enemy_roster()
	app._refresh_party()
	await _frames()
	app.deck.draw_pile.append(card_id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == card_id,
		"real run deck draws the authored '+' card")
	app._refresh_hand()
	await _frames()
	_display(card_id, "before routed " + card_id)
	var before := _state()
	await _mouse(_panel(card_id))
	_assert_success(card_id, before, "routed " + card_id)
	var roster: Array = app.enemies.get_enemies()
	_check(roster.size() == 3 and roster[0]["position"] == 1 and roster[1]["position"] == 2
		and roster[2]["position"] == 3, "the original three slots stay uncompacted")
	_check(roster[1]["hp"] == 0 and _bleed_total(roster[1]) == 0,
		"the slain middle slot is never a Bleed recipient")
	_check(_bleed_total(roster[0]) > 0 and _bleed_total(roster[2]) > 0,
		"both living outer slots were bled by the target-free cast")
	_check(_chip_shows(2, "bleed", 0) == false, "the slain slot shows no invented Bleed chip")
	await _return()
	_check(app.deck == null and adapter._bindings.is_empty() and adapter._battle == null,
		"leaving the routed fight clears every binding")


func _rejections() -> void:
	var card_id := "seamstress_blanket_stitch"
	var plus := "seamstress_blanket_stitch_plus"
	# Insufficient energy for an otherwise completely legal cast.
	if await _start(card_id):
		app.deck.combat_state.energy = 1
		var before := _state()
		await _mouse(_panel(card_id))
		_check(_state() == before and adapter._pending.is_empty(),
			"insufficient energy rejects without spending or discarding")
		await _return()
	# Inactive player turn.
	if await _start(card_id):
		app.deck.combat_state.player_turn_active = false
		var before := _state()
		await _mouse(_panel(card_id))
		_check(_state() == before and adapter._pending.is_empty(),
			"inactive turn rejects without spending")
		await _return()
	# Downed Seamstress owner.
	if await _start(card_id):
		_check(app.party.apply_damage(2, 10000) and app.party.is_downed(2),
			"the real Seamstress is actually downed")
		app._refresh_party()
		var before := _state()
		await _mouse(_panel(card_id))
		_check(_state() == before and adapter._pending.is_empty(),
			"downed owner rejects without spending")
		await _return()
	# Authored source position: Blanket Stitch requires middle or back.
	if await _start(card_id):
		var proposal := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
		_check(proposal.ok, "the production preview moves the Seamstress one slot forward")
		app.party._heroes.assign(proposal.heroes)
		_check(app.party.get_hero(1).id == "seamstress", "the Seamstress really occupies the front slot")
		app._refresh_party()
		app.get_node("LiveSupportHand")._sync_battle()
		await _frames()
		var before2 := _state()
		await _mouse(_panel(card_id))
		_check(_state() == before2 and adapter._pending.is_empty(),
			"illegal Seamstress position rejects without spending")
		await _return()
	# A duplicate click on a playable card still pays and discards exactly once.
	if await _start(card_id):
		var before3 := _state()
		var panel := _panel(card_id)
		await _mouse(panel)
		_check(app.deck.energy == int(before3[3]) - 2 and app.deck.discard_pile.count(card_id) == 1
			and app.deck.hand.count(card_id) == int(before3[1].count(card_id)) - 1,
			"one physical click with a duplicate press resolves exactly once")
		await _return()
	# Hidden battle and hidden panel fail closed through the same bound callback.
	if await _start(card_id):
		var panel := _panel(card_id)
		var callback: Callable = adapter._bindings[panel]["callback"]
		app.battle_view.hide()
		var before4 := _state()
		callback.call(_press())
		await _frames()
		_check(_state() == before4, "hidden battle rejects without spending")
		app.battle_view.show()
		panel.hide()
		var before5 := _state()
		callback.call(_press())
		await _frames()
		_check(_state() == before5, "hidden panel rejects without spending")
		panel.show()
		# Foreign session identities and a wrong card identity are inert.
		var before6 := _state()
		adapter._on_card_input(null, panel, card_id)
		adapter._on_card_input(_press(), panel, "warden_strike")
		adapter._on_card_input(_press(), panel, plus)
		await _frames()
		_check(_state() == before6, "null, wrong-ID and mismatched-panel inputs preserve state")
		var foreign := CombatParty.new(app._load_party_definitions())
		app.party = foreign
		var before7 := _state()
		adapter._on_card_input(_press(), panel, card_id)
		await _frames()
		_check(_state() == before7 and adapter._bindings.is_empty(),
			"a foreign party session never resolves and is unbound")
		await _return()
	# Stale turn: a queued cast must not resolve after the turn really ended.
	if await _start(card_id):
		var panel := _panel(card_id)
		var callback2: Callable = adapter._bindings[panel]["callback"]
		callback2.call(_press())
		_check(not adapter._pending.is_empty(), "a real input queues exactly one receipt")
		_check(app.deck.end_turn() and not app.deck.turn_active, "the real turn really ended")
		var after_turn := _state()
		await _frames()
		_check(_state() == after_turn and adapter._pending.is_empty(),
			"a queued cast never resolves after the turn ended")
		await _return()
	# Stale panel: a detached real panel cannot act on the old session.
	if await _start(card_id):
		var panel := _panel(card_id)
		var callback3: Callable = adapter._bindings[panel]["callback"]
		var cue3 = adapter._bindings[panel].get("cue")
		app.hand_view.remove_child(panel)
		adapter._sync_battle()
		_check(panel.gui_input.get_connections().is_empty() and not adapter._bindings.has(panel),
			"a detached panel is unbound")
		_check(not is_instance_valid(cue3) and panel.get_node_or_null(adapter.CUE_NAME) == null,
			"a detached stale panel retires its visible cue")
		var before8 := _state()
		callback3.call(_press())
		await _frames()
		_check(_state() == before8, "a detached stale callback cannot mutate the live session")
		panel.free()
		await _return()
	# Stale session: Return releases the battle and the captured callback stays inert.
	if await _start(card_id):
		var panel := _panel(card_id)
		var callback4: Callable = adapter._bindings[panel]["callback"]
		var cue4 = adapter._bindings[panel].get("cue")
		var old_deck: CombatDeck = app.deck
		var old_party: CombatParty = app.party
		var old_enemies: CombatEnemies = app.enemies
		var old_rng: RandomNumberGenerator = app.run_rng
		var old_state := _state()
		await _return()
		_check(adapter._bindings.is_empty() and adapter._battle == null and adapter._pending.is_empty(),
			"Return immediately clears bindings, receipts and model references")
		_check(not is_instance_valid(cue4), "Return retires the visible card cue")
		_check(app.deck == null and app.title_view.is_visible_in_tree(), "Return really left the battle")
		callback4.call(_press())
		await _frames()
		_check(old_deck.hand.has(card_id) and old_deck.energy == int(old_state[3])
			and old_party.get_heroes() == old_state[5]
			and old_enemies.get_enemies() == old_state[6]
			and old_rng.seed == int(old_state[10]) and old_rng.state == int(old_state[11]),
			"the stale Returned callback leaves the old session completely untouched")
		_check(is_instance_valid(panel) == false, "the old hand panel died with its battle")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	adapter = app.get_node_or_null("LiveAreaAttackAction")
	_check(adapter != null and app.deck == null, "the title starts with the mounted inert adapter")
	if adapter == null:
		app.free()
		_finish()
		return
	for card_id in IDS:
		_check(catalog.has_card(card_id) and not catalog.get_definition(card_id).is_empty(),
			"required authored pool record present: " + card_id)
	# Alternate real mouse and keyboard input across the base and '+' forms, and
	# confirm both accepted activation keys on the same mounted path.
	await _play_from_hand("seamstress_blanket_stitch", false)
	await _play_from_hand("seamstress_blanket_stitch_plus", true, KEY_ENTER)
	await _play_from_hand("seamstress_blanket_stitch", true, KEY_SPACE)
	await _mixed_hand_faces()
	await _three_enemy_case()
	await _rejections()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_seamstress_pool_bleed_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission, exactly like the other mounted hand regressions.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		preload("res://tests/party_choice.gd").choose(target)
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
