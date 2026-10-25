extends SceneTree
## Mounted target-free Tinker cards: real held input versus independent seeded
## CombatTinkerPoolAttacks, including the starter presenter's one shared latch.

const IDS := ["tinker_scatter_bolts", "tinker_scatter_bolts_plus",
	"tinker_ricochet", "tinker_ricochet_plus"]
const SHRAPNEL := "tinker_shrapnel_seam"
const SHRAPNEL_PLUS := "tinker_shrapnel_seam_plus"
const UNRAVEL_IDS := [SHRAPNEL, SHRAPNEL_PLUS]
const SEED := 42
## Exact compact rule each authored Tinker area face must print.
const EXPECTED_EFFECT := {
	"tinker_scatter_bolts": "Deal 3 to all.",
	"tinker_scatter_bolts_plus": "Deal 4 to all.",
	"tinker_shrapnel_seam": "Deal 5 to all. Unravel 2.",
	"tinker_shrapnel_seam_plus": "Deal 7 to all. Unravel 3.",
	"tinker_ricochet": "Deal 4 x3, random.",
	"tinker_ricochet_plus": "Deal 6 x3, random.",
}
const TIER_CATALOGS := [
	["res://data/enemies/starter_enemies.json", "normal"],
	["res://data/enemies/run_enemies.json", "normal"],
	["res://data/enemies/m04_elites.json", "elite"],
	["res://data/enemies/boss.json", "boss"],
]

var failures: Array[String] = []
var checks := 0
var app
var adapter
var preview
var catalog := TinkerPoolCards.new()
var sewn_wardrobe: RunPatchWardrobe
var sewn_route: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _mouse(panel: Control) -> void:
	var point := panel.get_global_rect().get_center()
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(point),
		"held card hit point is visible within 1280x720")
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


## Real hover without a press, so the forecast can be examined before commit.
func _hover(panel: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = panel.get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames()


func _quote_text(hits: Array) -> String:
	var parts: Array[String] = []
	for index in range(hits.size()):
		parts.append("hit %d → enemy %d" % [index + 1, int(hits[index]["position"])])
	return "If played now: " + "; ".join(parts)


func _press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _panel(id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and panel.get_child(0).text == id:
			return panel
	return null


func _state() -> Dictionary:
	var gauges: Dictionary = {}
	var tiers: Dictionary = {}
	var pins: Dictionary = {}
	if preview != null and preview._unravel != null:
		gauges = preview._unravel._gauges.duplicate(true)
		tiers = preview._unravel._tiers_by_position.duplicate(true)
	if preview != null and preview._pinned != null:
		pins = preview._pinned._pinner_by_position.duplicate(true)
	return {"draw": app.deck.draw_pile.duplicate(), "hand": app.deck.hand.duplicate(),
		"discard": app.deck.discard_pile.duplicate(), "energy": app.deck.energy,
		"active": app.deck.turn_active, "party": app.party.get_heroes(),
		"enemies": app.enemies.get_enemies(), "seed": app.run_rng.seed,
		"rng": app.run_rng.state, "deck_rng": app.deck._rng.state,
		"attacks": app.enemy_attacks.duplicate(true),
		"intents": app.enemy_intents.get_intents(),
		"turn": app.enemy_intents._turn_index,
		"outcome": app.battle_result.get_outcome(), "closed": app._battle_closed,
		"gold": app.session_gold, "first": preview._play._tinker._consumed,
		"patch_active": preview._play._patches.active_snapshot() if preview._play._patches != null else {},
		"patch_latch": preview._play._patches.latch_snapshot() if preview._play._patches != null else {},
		"wardrobe": sewn_wardrobe.get_snapshot() if sewn_wardrobe != null else {},
		"run_deck": app.run_deck.duplicate(), "trinkets": app.run_trinkets.duplicate(),
		"scraps": app.run_scraps, "run_heroes": app.run_heroes.duplicate(true),
		"gauges": gauges, "tiers": tiers, "pins": pins,
		"flow_gauge": app.round_flow._unravel if app.round_flow != null else null}


## The live battle's one gauge and pin set, read without copying identities.
func _gauges() -> Dictionary:
	return preview._unravel._gauges.duplicate(true) if preview._unravel != null else {}


func _pins() -> Dictionary:
	return preview._pinned._pinner_by_position.duplicate(true) if preview._pinned != null else {}


## Independent tier classification from the four shipped catalogs, never from
## the presenter or the gauge under test.
func _test_tier_map(enemies: CombatEnemies) -> Dictionary:
	var table: Dictionary = {}
	for entry in TIER_CATALOGS:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(str(entry[0])))
		if not parsed is Array:
			return {}
		for record in parsed:
			var enemy_id := str(record.get("id", ""))
			if enemy_id.is_empty():
				return {}
			if table.has(enemy_id) and table[enemy_id] != entry[1]:
				table[enemy_id] = ""
			elif not table.has(enemy_id):
				table[enemy_id] = entry[1]
	var tiers: Dictionary = {}
	var roster: Array = enemies.get_enemies()
	if roster.is_empty():
		return tiers
	for index in range(roster.size()):
		var roster_id := str(roster[index].get("id", ""))
		if not table.has(roster_id) or str(table[roster_id]).is_empty():
			return {}
		tiers[index + 1] = table[roster_id]
	return tiers


func _oracle(before: Dictionary, id: String, is_starter: bool = false) -> Dictionary:
	# A separate service, deck, seeded RNG and real detached combat models.
	var rng := RandomNumberGenerator.new()
	rng.seed = before.seed
	rng.state = before.rng
	var deck := CombatDeck.new([], rng)
	deck.draw_pile.assign(before.draw)
	deck.hand.assign(before.hand)
	deck.discard_pile.assign(before.discard)
	deck.combat_state.energy = before.energy
	deck.combat_state.player_turn_active = before.active
	var party := CombatParty.new(app._load_party_definitions())
	party._heroes.assign((before.party as Array).duplicate(true))
	var definitions: Array[Dictionary] = []
	for enemy in before.enemies:
		definitions.append({"id": enemy.id, "max_hp": enemy.max_hp})
	var enemies := CombatEnemies.new(definitions)
	enemies._enemies.assign((before.enemies as Array).duplicate(true))
	# The battle's single Unravel gauge and Pinned set, replayed independently.
	var unravel := CombatUnravel.new()
	if not (before.tiers as Dictionary).is_empty():
		_check(unravel.bind_roster(enemies, (before.tiers as Dictionary).duplicate(true)),
			"independent oracle binds the authored tier map")
		unravel._gauges = (before.gauges as Dictionary).duplicate(true)
	var pinned := CombatPinned.new()
	pinned._pinner_by_position = (before.pins as Dictionary).duplicate(true)
	var first := CombatTinkerFirstAttack.new()
	first._consumed = before.first
	var rules: CombatPatchAttackRules = null
	if sewn_wardrobe != null and not (before.patch_active as Dictionary).is_empty():
		rules = CombatPatchAttackRules.new()
		var carry := app.party_carryover as RunTornCarryover
		_check(carry != null and rules.bind_wardrobe(sewn_wardrobe, carry.torn),
			"independent oracle binds genuine sewn wardrobe and Torn ledger")
		if rules.is_valid():
			_check(rules.active_snapshot() == before.patch_active,
				"independent wardrobe projection matches the live wearer")
			rules._consumed = (before.patch_latch as Dictionary).duplicate(true)
	var event: Dictionary
	if is_starter:
		var starter := CombatAttackCards.new()
		starter._tinker = first
		starter._patches = rules
		event = starter.play_attack(deck, party, enemies, id, 1)
	elif id in UNRAVEL_IDS:
		var unravel_attack := CombatTinkerPoolUnravelAttacks.new(first)
		_check(unravel_attack.set_patch_rules(rules),
			"independent Shrapnel resolver accepts current sewn snapshot")
		event = unravel_attack.play_attack(deck, party, enemies, id, 0, unravel, pinned)
	else:
		event = CombatTinkerPoolAttacks.new(first).play_attack(deck, party, enemies, id, 0)
	return {"event": event, "draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"active": deck.turn_active, "party": party.get_heroes(),
		"enemies": enemies.get_enemies(), "rng": rng.state, "first": first._consumed,
		"patch_latch": rules.latch_snapshot() if rules != null else {},
		"gauges": unravel._gauges.duplicate(true),
		"tiers": unravel._tiers_by_position.duplicate(true),
		"pins": pinned._pinner_by_position.duplicate(true)}


func _same_as_oracle(before: Dictionary, oracle: Dictionary, stage: String) -> void:
	_check(oracle.event.get("ok", false) and not oracle.event.hits.is_empty(),
		"independent scene-free service succeeds: " + stage)
	_check(app.deck.draw_pile == oracle.draw and app.deck.hand == oracle.hand
		and app.deck.discard_pile == oracle.discard and app.deck.energy == oracle.energy
		and app.deck.turn_active == oracle.active,
		"authoritative draw, hand, discard, energy and turn equal detached oracle: " + stage)
	_check(app.party.get_heroes() == oracle.party and app.enemies.get_enemies() == oracle.enemies,
		"actual hero HP/Block/status and enemy fixed slots equal detached oracle: " + stage)
	_check(app.run_rng.state == oracle.rng and app.deck._rng.state == oracle.rng,
		"single seeded run/deck RNG exactly matches independent oracle: " + stage)
	_check(preview._play._tinker._consumed == oracle.first,
		"starter presenter owns consumed first-attack latch: " + stage)
	_check((preview._play._patches.latch_snapshot() if preview._play._patches != null else {})
		== oracle.patch_latch, "starter presenter owns persistent Button Eye latch: " + stage)
	_check(_gauges() == oracle.gauges and _pins() == oracle.pins,
		"battle Unravel gauges and Pinned tokens equal detached oracle: " + stage)
	_check(app.enemy_attacks == before.attacks and app.enemy_intents.get_intents() == before.intents
		and app.enemy_intents._turn_index == before.turn,
		"confirmed cast doesn't advance enemy phase or intents: " + stage)
	_check(app.battle_result.get_outcome() == before.outcome and app._battle_closed == before.closed
		and app.session_gold == before.gold, "nonterminal cast keeps result and gold: " + stage)
	_check(adapter._pending.is_empty() and app.pile_label.text == "Draw: %d | Discard: %d" % [
		app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		"receipt retires and live hand counters refresh: " + stage)
	_check(app.hand_view.get_child_count() == app.deck.hand.size(),
		"rendered hand follows authoritative pile: " + stage)


func _start(id: String) -> bool:
	_check(app.deck == null, "new mounted battle begins at title")
	app.run_seed = SEED
	if not app._start_battle():
		_check(false, "real standalone battle starts")
		return false
	await _frames()
	var ready: bool = app.deck != null and app.party != null and app.enemies != null \
		and app.battle_result != null and app.run_rng != null and app.deck.turn_active \
		and app.enemy_intents != null and preview._play._tinker.bonus_for_attack(id) == 3
	_check(ready, "real mounted fight provides combat authority and unused passive")
	if not ready:
		return false
	_check(preview._unravel != null and preview._pinned != null
		and preview._unravel._bound_enemies == app.enemies,
		"the battle's single Unravel gauge and Pinned set bind the seeded roster")
	_check(_test_tier_map(app.enemies) == preview._unravel._tiers_by_position,
		"independent authored catalog tiers equal the live gauge tiers")
	# Draw through the genuine shared CombatDeck, then refresh the real hand.
	app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.has(id),
		"authored pool ID is genuinely drawn into held hand")
	app._refresh_hand()
	await _frames()
	_check(is_instance_valid(_panel(id)) and adapter._bindings.has(_panel(id)),
		"real scene binds the newly held Tinker card")
	return _panel(id) != null


func _return() -> void:
	if is_instance_valid(app.return_button):
		app.return_button.pressed.emit()
	await _frames()
	sewn_wardrobe = null


func _face(id: String) -> void:
	var panel := _panel(id)
	if panel == null:
		_check(false, "real authored panel exists for face assertions")
		return
	var definition := catalog.get_definition(id)
	var effects: Dictionary = definition.effects
	var face: Dictionary = adapter.face_text(panel)
	_check(panel.get_child(0) is Label and panel.get_child(0).text == id
		and panel.get_index() == app.deck.hand.find(id),
		"first-child hidden ID and original hand index validate real identity: " + id)
	_check(panel.gui_input.get_connections().size() == 1
		and panel.focus_mode == Control.FOCUS_ALL and panel.mouse_filter == Control.MOUSE_FILTER_STOP,
		"one callback, keyboard focus and physical mouse input: " + id)
	_check(face.get("name") == definition.display_name and face.name != "Unknown card"
		and face.get("cost", "") == "%d energy" % int(definition.cost),
		"authored visible name and energy cost, not raw-ID placeholder: " + id)
	_check(face.get("name", "").ends_with("+") == id.ends_with("_plus"),
		"visible name keeps the authored '+' upgrade suffix: " + id)
	_check(face.get("effect", "") == EXPECTED_EFFECT.get(id, ""),
		"visible face prints the exact compact authored rule: " + id)
	var shown: String = "%s %s %s" % [str(face.get("name", "")), str(face.get("cost", "")),
		str(face.get("effect", ""))]
	for jargon in ["From", "Target", "No target choice", "living", "first attack", "base"]:
		_check(not shown.contains(jargon), "face never prints '%s': %s" % [jargon, id])
	# Three small source circles and three small target squares, read from the
	# authored positions; only the simultaneous every-enemy cards are stitched.
	var from_positions: Array = definition.from_positions
	var to_positions: Array = definition.to_positions
	var from_pips: Array = face.get("from_pips", [])
	var to_pips: Array = face.get("to_pips", [])
	_check(from_pips.size() == 3 and to_pips.size() == 3,
		"face reports exactly three source and three target pips: " + id)
	for index in range(mini(from_pips.size(), 3)):
		_check(bool(from_pips[index]) == from_positions.has(index + 1),
			"source pip %d matches the authored from positions: %s" % [index + 1, id])
		_check(bool(to_pips[index]) == to_positions.has(index + 1),
			"target pip %d matches the authored to positions: %s" % [index + 1, id])
	_check(bool(face.get("thread", false)) == (definition.target_kind == "enemy_all"),
		"stitched thread only for Scatter/Shrapnel, never Ricochet: " + id)
	_check(panel.tooltip_text.contains(definition.display_name)
		and panel.tooltip_text.contains("Enter / Space")
		and panel.tooltip_text.contains("Tinker") and panel.tooltip_text.contains("no target choice")
		and panel.tooltip_text.contains("first attack +3")
		and panel.tooltip_text.contains("From %s" % adapter._positions(from_positions)),
		"tooltip explains keyboard, owner, positions, target and first-attack rule: " + id)
	if id in UNRAVEL_IDS:
		_check(panel.tooltip_text.contains("Unravel %d" % int(effects.unravel))
			and panel.tooltip_text.contains("All living enemies %s" % adapter._positions(to_positions)),
			"tooltip keeps the Unravel charge and original-position area scope: " + id)
	elif definition.target_kind == "enemy_all":
		_check(panel.tooltip_text.contains("living")
			and panel.tooltip_text.contains(adapter._positions(to_positions)),
			"tooltip keeps the living every-enemy scope: " + id)
	else:
		_check(panel.tooltip_text.contains("random living hits")
			and panel.tooltip_text.contains(adapter._positions(to_positions)),
			"tooltip keeps the random living-target policy and positions: " + id)
	if definition.target_kind == "enemy_random":
		_check(panel.tooltip_text.contains("run RNG"),
			"tooltip explains the seeded per-hit random policy: " + id)
	var cue = adapter._bindings[panel].get("cue")
	_check(is_instance_valid(cue) and cue.is_visible_in_tree() and cue.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and cue.focus_mode == Control.FOCUS_NONE and cue.get_index() > 0
		and cue.get_theme_stylebox("panel").border_color == Color("#c49a3a"),
		"noninteractive mustard sewn-paper overlay covers real held panel: " + id)
	if is_instance_valid(cue):
		# Genuinely mounted children, not a detached layout.
		var nodes: Array = adapter.face_children(panel)
		var visible := 0
		for node in nodes:
			if node is Control and node.is_visible_in_tree() and node.size.x > 0 and node.size.y > 0 \
					and node.mouse_filter != Control.MOUSE_FILTER_STOP:
				visible += 1
		_check(nodes.size() >= 13 and visible == nodes.size(),
			"every sewn text/pip child is attached, visible and never takes input: " + id)
		_check(cue.get_child_count() == 1 and cue.get_child(0) is MarginContainer
			and cue.get_child(0).is_visible_in_tree(),
			"cue mounts its margin/content child instead of leaving it detached: " + id)
		for index in range(3):
			var from_pip = cue.find_child("From%d" % (index + 1), true, false)
			var to_pip = cue.find_child("To%d" % (index + 1), true, false)
			var from_style = from_pip.get_theme_stylebox("panel") if from_pip is Panel else null
			var to_style = to_pip.get_theme_stylebox("panel") if to_pip is Panel else null
			_check(from_style is StyleBoxFlat and from_pip.is_visible_in_tree()
				and _pip_filled(from_pip) == from_positions.has(index + 1)
				and (not from_positions.has(index + 1) or from_style.bg_color == Color("#c49a3a"))
				and from_style.corner_radius_top_left * 2 >= int(from_pip.size.x),
				"mounted circular source pip %d matches authored from positions: %s" % [index + 1, id])
			_check(to_style is StyleBoxFlat and to_pip.is_visible_in_tree()
				and _pip_filled(to_pip) == to_positions.has(index + 1)
				and (not to_positions.has(index + 1) or to_style.bg_color == Color("#c49a3a"))
				and to_style.corner_radius_top_left == 0,
				"mounted square target pip %d matches authored to positions: %s" % [index + 1, id])
			_check(cue.get_global_rect().grow(1.0).encloses(from_pip.get_global_rect())
				and cue.get_global_rect().grow(1.0).encloses(to_pip.get_global_rect()),
				"source and target pip %d stay inside the sewn face: %s" % [index + 1, id])
		_assert_thread(cue, definition, id)
	_check(not panel.get_child(0).is_visible_in_tree()
		and not panel.focus_neighbor_bottom.is_empty()
		and panel.get_node_or_null(panel.focus_neighbor_bottom) == app.end_turn_button,
		"hidden original label and usable End Turn focus exit: " + id)
	_check(root.size == Vector2i(1280, 720) and cue.size == panel.size,
		"1280x720 headless viewport and legible full-panel sewn face: " + id)
	_check(adapter.button == null and adapter.get_child_count() == 1
		and adapter.get_child(0).name == "LiveSeamstressSingleBleedHand"
		and not adapter.get_child(0) is Control
		and app.battle_view.get_node_or_null("SeamstressBleedChoiceOverlay") == null,
		"no second attack button or overlay node exists: " + id)


## A pip is filled when its sewn style has a real background colour.
func _pip_filled(pip: Control) -> bool:
	var style = pip.get_theme_stylebox("panel")
	return style is StyleBoxFlat and style.bg_color.a > 0.0


## The stitched thread is measured from the mounted nodes: every authored target
## square is crossed through its centre by a real drawn stitch, the source
## circles are never stitched, and Ricochet mounts no thread at all.
func _assert_thread(cue: Control, definition: Dictionary, stage: String) -> void:
	var thread = cue.find_child("Thread", true, false)
	_check((thread != null) == (definition.target_kind == "enemy_all"),
		"mounted stitched thread only on Scatter/Shrapnel, never Ricochet: " + stage)
	if not thread is Control:
		return
	_check(thread.is_visible_in_tree() and thread.mouse_filter != Control.MOUSE_FILTER_STOP
		and thread.focus_mode == Control.FOCUS_NONE,
		"the stitched thread is visible and never takes pointer input: " + stage)
	var stitches: Array[Rect2] = []
	for child in thread.get_children():
		if child is ColorRect and String(child.name).begins_with("Stitch") \
				and child.is_visible_in_tree() and child.size.x > 0 and child.size.y > 0:
			stitches.append((child as ColorRect).get_global_rect())
	var to_positions: Array = definition.to_positions
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


func _case(id: String, by_key: bool, key: Key = KEY_ENTER, hole: bool = false) -> void:
	if not await _start(id):
		await _return()
		return
	_face(id)
	# Use actual current hero slots, not an assumed spawn coordinate.
	var owner_slot := -1
	for hero in app.party.get_heroes():
		if hero.id == "tinker":
			owner_slot = hero.position
	_check(owner_slot == 3, "standalone roster starts with Tinker in slot 3")
	app.party._heroes[owner_slot - 1]["statuses"] = {"weak": 1}
	_check(app.enemies.gain_block(1, 2) and app.enemies.apply_statuses({1: {"exposed": 1}}),
		"authoritative enemy Block/Exposed and owner Weak fixture")
	# Preserve victory-free post-state for a one-to-one resolver comparison.
	for enemy in app.enemies._enemies:
		enemy.max_hp = 65
		enemy.hp = 65
	if hole and app.enemies.get_enemies().size() >= 2:
		_check(app.enemies.apply_damage(2, 65) and app.enemies.is_slain(2),
			"real dead enemy remains original slot 2, never compacted")
	var panel := _panel(id)
	var callback: Callable = adapter._bindings[panel]["callback"]
	var before := _state()
	var oracle := _oracle(before, id)
	if id.begins_with("tinker_ricochet"):
		_check(oracle.event.get("ok", false) and not oracle.event.hits.is_empty(),
			"Ricochet quote has an independent genuine seeded-play oracle")
		if by_key:
			panel.grab_focus()
			await _frames()
			_check(panel.has_focus(), "Ricochet keyboard focus is on real held panel")
		else:
			await _hover(panel)
		_check(panel.tooltip_text.contains(_quote_text(oracle.event.hits)),
			"mounted hover/focus quotes exact independent ordered original hit slots: " + id)
		_check(_state() == before and app.run_rng.state == before.rng,
			"mounting and refreshing Ricochet quote never spends or advances seed: " + id)
	if by_key:
		panel.grab_focus()
		_check(panel.has_focus(), "real Tinker hand card focused: " + id)
		await _key(key)
	else:
		await _mouse(panel)
	_same_as_oracle(before, oracle, id)
	_check(adapter.last_event == oracle.event,
		"complete ordered hit positions, damage, Block and HP loss equal resolver: " + id)
	var cost: int = int(catalog.get_definition(id).get("cost", 1))
	_check(app.deck.energy == before.energy - cost
		and app.deck.discard_pile.count(id) == 1 and app.deck.hand.count(id) == 0,
		"exact %d energy and one held copy spent: %s" % [cost, id])
	_check(preview._play._tinker.bonus_for_attack(id) == 0,
		"successful area card consumes the starter presenter's opportunity: " + id)
	var after := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == after and adapter._pending.is_empty(),
		"stale duplicate callback never commits a second cast: " + id)
	await _return()


func _starter(id: String) -> bool:
	# The keyboard path used by real players: P cycles actual held attack panels,
	# 1 selects living original enemy position 1 for Pop Shot.
	var panel := _panel(id)
	for i in range(CombatAttackTargeting.ATTACK_IDS.size() + 3):
		await _key(KEY_P)
		if preview._armed == panel:
			break
	_check(panel != null and preview._armed == panel, "P selects held Pop Shot")
	if preview._armed != panel:
		return false
	await _key(KEY_1)
	return true


## A legal noncombat prefix permits an authentic sewn wardrobe before the
## first routed Fight. Cache only the route recipe; every case re-enters the
## actual app and uses its own fresh run ledgers and fight authorities.
func _sewn_route_fixture() -> Dictionary:
	if not sewn_route.is_empty():
		return sewn_route
	for value in range(1, 1500):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for first in map.get_legal_choices():
			if map.get_node(first).get("type") != "Treasure":
				continue
			var replay_rng := RandomNumberGenerator.new()
			replay_rng.seed = value
			var replay := RunMap.new()
			replay.generate(replay_rng)
			if not replay.choose_node(first):
				continue
			for second in replay.get_legal_choices():
				if replay.get_node(second).get("type") == "Fight":
					sewn_route = {"seed": value, "treasure": first, "fight": second}
					return sewn_route
	return {}


func _route_button(route_id: String) -> Button:
	for button in app.route_buttons:
		if button.get_meta("route_id") == route_id:
			return button
	return null


func _start_sewn(id: String, patches: Array[String]) -> bool:
	var fixture := _sewn_route_fixture()
	_check(not fixture.is_empty() and app.deck == null,
		"authored Treasure to Fight route starts from the real title")
	if fixture.is_empty() or app.deck != null:
		return false
	app.run_seed = fixture.seed
	app.route_button.pressed.emit()
	await _frames()
	var treasure := _route_button(fixture.treasure)
	_check(treasure != null and not treasure.disabled, "genuine Treasure prefix is actionable")
	if treasure == null:
		return false
	treasure.pressed.emit()
	await _frames()
	_check(app.run_map.get_route() == [fixture.treasure],
		"connected noncombat prefix is genuinely committed")
	var carry := app.party_carryover as RunTornCarryover
	_check(carry != null and carry.is_valid() and carry.torn.is_valid()
		and carry.read_state().heroes == app.run_heroes,
		"real run carryover and Torn/Mending ledger agree")
	if carry == null:
		return false
	var definitions: Array[Dictionary] = []
	for patch_id in patches:
		var catalog_path := "res://data/patches/m04_attack_patches.json"
		if patch_id == "loose_thread_glove":
			catalog_path = "res://data/patches/m05_arm_support_patches.json"
		var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		var found := false
		if records is Array:
			for record in records:
				if record is Dictionary and record.get("id") == patch_id:
					_check(record.get("amount") == 1 and record.get("slot") in ["ARM", "HEAD"],
						"genuine authored attack patch effect and equipment slot: " + patch_id)
					definitions.append({"id": patch_id, "slot": record.slot})
					found = true
		_check(found, "required authored patch ID occurs in real catalog: " + patch_id)
		if not found:
			return false
		app.run_trinkets.append(patch_id)
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		definitions, app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	_check(wardrobe.is_valid(), "run-owned wardrobe accepts exact run inventory and hero state")
	if not wardrobe.is_valid():
		return false
	for patch in definitions:
		var sew := wardrobe.sew(patch.id, "tinker", patch.slot,
			"sew_" + patch.id, wardrobe.get_snapshot())
		_check(sew.get("ok", false) and sew.receipt.patch_id == patch.id,
			"authentic Tinker sewn " + patch.slot + " receipt: " + patch.id)
		if not sew.get("ok", false):
			return false
	var expected := wardrobe.get_snapshot()
	_check(carry.can_bind_wardrobe(wardrobe, carry.torn, expected)
		and carry.bind_wardrobe(wardrobe, carry.torn, expected),
		"real persistent run carryover admits sewn wardrobe before Fight")
	if carry._wardrobe != wardrobe:
		return false
	var fight := _route_button(fixture.fight)
	_check(fight != null and not fight.disabled and app._can_choose_connected_route(),
		"connected authored Fight remains legal with sewn wardrobe")
	if fight == null or fight.disabled:
		return false
	fight.pressed.emit()
	await _frames()
	_check(app.deck != null and is_instance_valid(app.battle_view)
		and app.battle_result._party == app.party and app.battle_result._enemies == app.enemies,
		"authentic routed Fight mounts matching battle, party, enemies and result")
	if app.deck == null:
		return false
	sewn_wardrobe = wardrobe
	var rules: CombatPatchAttackRules = preview._play._patches
	_check(rules != null and rules.is_valid()
		and rules.active_snapshot().get("tinker", []).size() == patches.size(),
		"starter presenter has validated the real Tinker sewn projection")
	if rules == null or not rules.is_valid():
		return false
	_check(adapter._live_tinker_patch_rules(app).get("rules") == rules,
		"Shrapnel adapter selects the exact existing battle rules object")
	_check(_test_tier_map(app.enemies) == preview._unravel._tiers_by_position,
		"routed gauge tiers match independent authored enemy catalog")
	for position in range(1, app.enemies.get_enemies().size() + 1):
		var tier: String = _test_tier_map(app.enemies)[position]
		_check(preview._unravel.get_snapshot(position).get("threshold") ==
			{"normal": 8, "elite": 12, "boss": 16}[tier],
			"routed original enemy slot has correct normal/elite/boss threshold")
	app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.has(id),
		"authored Shrapnel copy actually drawn by the routed shared deck")
	app._refresh_hand()
	await _frames()
	_check(_panel(id) != null and adapter._bindings.has(_panel(id)),
		"sewn Shrapnel panel mounted through the normal live hand")
	return _panel(id) != null


func _shared_latch() -> void:
	for order in ["starter_first", "area_first"]:
		var id := "tinker_scatter_bolts"
		if not await _start(id):
			await _return()
			continue
		app.deck.draw_pile.append("tinker_pop_shot")
		_check(app.deck.draw_extra(1) == 1 and app.deck.hand.has("tinker_pop_shot"),
			"authentic Pop Shot held beside area card")
		app._refresh_hand()
		await _frames()
		for enemy in app.enemies._enemies:
			enemy.max_hp = 85
			enemy.hp = 85
		var ids: Array = ["tinker_pop_shot", id] if order == "starter_first" else [id, "tinker_pop_shot"]
		for selected in ids:
			var before := _state()
			var oracle := _oracle(before, selected, selected == "tinker_pop_shot")
			if selected == "tinker_pop_shot":
				if not await _starter(selected):
					break
				_check(preview.last_event == oracle.event,
					"mounted starter ordered event equals independent starter oracle: " + order)
			else:
				await _mouse(_panel(selected))
				_check(adapter.last_event == oracle.event,
					"mounted area ordered event equals independent pool oracle: " + order)
			_same_as_oracle(before, oracle, order + " / " + selected)
			_check(preview._play._tinker._consumed,
				"only one Tinker first-attack opportunity per turn: " + order)
		if order == "area_first" and app.deck.turn_active:
			app.end_turn_button.pressed.emit()
			await _frames()
			_check(app.enemy_intents._turn_index > 0 and app.deck.turn_active,
				"real End Turn advances through enemy phase to next player turn")
			_check(not preview._play._tinker._consumed
				and preview._play._tinker.bonus_for_attack(id) == 3,
				"starter and area share next-turn latch reset, not panel rebind reset")
		await _return()


## AC2: the target-free Shrapnel Seam reads the battle's foreign Pinned token,
## pays two energy, damages every survivor and charges its authored Unravel.
## Genuine sewn ARM fixtures exercise both base/upgraded Shrapnel in the
## physical hand, including status floor rounding, Block, Pinned and RNG.
func _sewn_arm_cases() -> void:
	for patch in ["pincushion_arm", "loose_thread_glove"]:
		for id in UNRAVEL_IDS:
			var worn: Array[String] = [patch]
			if not await _start_sewn(id, worn):
				await _return()
				continue
			var rules: CombatPatchAttackRules = preview._play._patches
			_check(sewn_wardrobe.get_snapshot().worn.tinker.ARM == patch
				and sewn_wardrobe.get_snapshot().worn.tinker.HEAD == ""
				and rules.latch_snapshot().get("tinker") == false,
				"exactly one authentic ARM patch, no HEAD, no consumed first-hit")
			for enemy in app.enemies._enemies:
				enemy.max_hp = 140
				enemy.hp = 140
			app.party._heroes[2]["statuses"] = {"weak": 1}
			_check(app.enemies.gain_block(1, 4), "first original enemy wears real Block")
			if app.enemies.get_enemies().size() > 1:
				_check(app.enemies.apply_statuses({2: {"exposed": 1}}),
					"second original enemy has real Exposed for floor rounding")
			_check(preview._pinned.pin_enemy(app.enemies, 1, "warden"),
				"foreign Warden Pinned token pre-exists sewn Shrapnel")
			var before := _state()
			var oracle := _oracle(before, id)
			_check(oracle.event.get("ok", false) and not oracle.event.hits.is_empty(),
				"detached patched resolver accepts genuine mounted card fixture")
			await _mouse(_panel(id))
			_same_as_oracle(before, oracle, patch + " / " + id)
			_check(adapter.last_event == oracle.event,
				"exact patch damage, Weak/Exposed flooring, Block and Unravel hit receipt")
			var authored: Dictionary = catalog.get_definition(id).effects
			var wanted_unravel: int = int(authored.unravel) + (1 if patch == "loose_thread_glove" else 0)
			for hit in adapter.last_event.get("hits", []):
				_check(hit.unravel == wanted_unravel
					and preview._unravel.get_snapshot(hit.position).gauge == wanted_unravel,
					"surviving slot receives only its authored + sewn Unravel: " + patch)
			_check(adapter.last_event.hits[0].damage ==
				CombatStatuses.new().adjusted_attack_damage(
					int(authored.damage) + 3 + (1 if patch == "pincushion_arm" else 0) + 5,
					{"weak": 1}, app.enemies.get_enemy(1).get("statuses", {})),
				"sewn per-hit Pincushion bonus and foreign pin precede Weak rounding")
			_check(_pins().is_empty() and app.deck.energy == before.energy - 2
				and app.deck.discard_pile.count(id) == 1
				and before.wardrobe == sewn_wardrobe.get_snapshot(),
				"one payment, one discard, consumed pin and untouched sewn run ledger")
			await _return()

## First HEAD effect is a battle-long latch, independent of Tinker's +3 turn.
func _sewn_button_eye_orders() -> void:
	for order in ["pop_first", "shrapnel_first"]:
		var head: Array[String] = ["button_eye"]
		if not await _start_sewn(SHRAPNEL, head):
			await _return()
			continue
		var rules: CombatPatchAttackRules = preview._play._patches
		_check(rules.active_snapshot().get("tinker", []) == ["button_eye"]
			and sewn_wardrobe.get_snapshot().worn.tinker.ARM == "",
			"genuine HEAD-only projection, ARM empty")
		for enemy in app.enemies._enemies:
			enemy.max_hp = 160
			enemy.hp = 160
		app.deck.draw_pile.append("tinker_pop_shot")
		_check(app.deck.draw_extra(1) == 1, "routed Pop Shot drawn")
		app._refresh_hand()
		await _frames()
		var sequence: Array = ["tinker_pop_shot", SHRAPNEL] if order == "pop_first" \
			else [SHRAPNEL, "tinker_pop_shot"]
		for i in range(sequence.size()):
			var selected: String = sequence[i]
			var before := _state()
			var oracle := _oracle(before, selected, selected == "tinker_pop_shot")
			_check(oracle.event.get("ok", false), "detached HEAD oracle attack succeeds")
			if selected == "tinker_pop_shot":
				if not await _starter(selected):
					break
				_check(preview.last_event == oracle.event, "physical starter receipt equals oracle")
			else:
				await _mouse(_panel(selected))
				_check(adapter.last_event == oracle.event, "physical Shrapnel receipt equals oracle")
			_same_as_oracle(before, oracle, order + " / " + selected)
			_check(rules == preview._play._patches and rules.latch_snapshot().tinker,
				"same battle rules object consumes first-hit exactly once")
			_check(oracle.event.hits[0].statuses.get("exposed", 0) == (1 if i == 0 else 0),
				"first confirmed Tinker attack alone applies Exposed")
			if selected == SHRAPNEL and i == 0:
				for j in range(1, oracle.event.hits.size()):
					_check(oracle.event.hits[j].statuses.is_empty(),
						"later targets of same Shrapnel do not gain same-card Exposed")
			app._refresh_hand()
			await _frames()
			_check(preview._play._patches == rules and rules.latch_snapshot().tinker,
				"genuine hand refresh preserves consumed Button Eye")
		_check(app.deck.energy == 0 and app.deck.discard_pile.count(SHRAPNEL) == 1,
			"alternating two-cost and one-cost attacks charged once each")
		app.end_turn_button.pressed.emit()
		await _frames()
		_check(app.deck.turn_active and app.deck.energy == 3
			and not preview._play._tinker._consumed and rules.latch_snapshot().tinker,
			"new player turn re-arms native +3, not combat-long first Exposed")
		app.deck.draw_pile.append(SHRAPNEL_PLUS)
		_check(app.deck.draw_extra(1) == 1, "upgraded Shrapnel drawn next turn")
		app._refresh_hand()
		await _frames()
		var before_plus := _state()
		var plus_oracle := _oracle(before_plus, SHRAPNEL_PLUS)
		await _mouse(_panel(SHRAPNEL_PLUS))
		_same_as_oracle(before_plus, plus_oracle, "upgraded Shrapnel after Button Eye used")
		_check(adapter.last_event == plus_oracle.event
			and adapter.last_event.hits[0].statuses.get("exposed", 0) == 0
			and rules.latch_snapshot().tinker,
			"upgraded Shrapnel after turn/refresh does not reapply Button Eye")
		await _return()

## An explicit invalid sewn authority or downed owner never falls back.
func _sewn_refusals() -> void:
	for mode in ["invalid_rules", "missing_rules", "invalid_wardrobe", "downed"]:
		var arm: Array[String] = ["pincushion_arm"]
		if not await _start_sewn(SHRAPNEL, arm):
			await _return()
			continue
		var panel := _panel(SHRAPNEL)
		var callback: Callable = adapter._bindings[panel]["callback"]
		var rules: CombatPatchAttackRules = preview._play._patches
		var carry := app.party_carryover as RunTornCarryover
		match mode:
			"invalid_rules":
				rules._valid = false
			"missing_rules":
				preview._play._patches = null
			"invalid_wardrobe":
				carry._wardrobe = RunPatchWardrobe.new()
			"downed":
				_check(app.party.apply_damage(3, app.party.get_hero(3).hp)
					and app.party.is_downed(3), "authentic Tinker downed in mounted battle")
		var before := _state()
		callback.call(_press())
		await _frames()
		_check(_state() == before and adapter._pending.is_empty(),
			"explicit invalid wearer authority rejects without spend/RNG: " + mode)
		await _return()

	var heroes := CombatParty.new(app._load_party_definitions()).get_heroes()
	var torn := RunTornMending.new(heroes)
	var downed := heroes.duplicate(true)
	downed[2]["hp"] = 0
	_check(torn.observe_battle_end("shrapnel_torn", heroes, downed).get("ok", false),
		"genuine Torn/Mending end observation records Tinker down")
	var wardrobe := RunPatchWardrobe.new(torn.read_state().heroes, ["pincushion_arm"],
		[{"id": "pincushion_arm", "slot": "ARM"}], 0, 0, [], SEED, true)
	_check(wardrobe.is_valid() and wardrobe.sew("pincushion_arm", "tinker", "ARM",
		"sew_torn", wardrobe.get_snapshot()).get("ok", false),
		"assigned patch remains genuinely sewn on torn wearer")
	var patch_rules := CombatPatchAttackRules.new()
	_check(patch_rules.bind_wardrobe(wardrobe, torn)
		and patch_rules.active_snapshot().get("tinker", []).is_empty()
		and patch_rules.damage_bonus("tinker") == 0,
		"torn ledger masks Pincushion even while sewn")

func _shrapnel_pinned() -> void:
	if not await _start(SHRAPNEL_PLUS):
		await _return()
		return
	for enemy in app.enemies._enemies:
		enemy.max_hp = 60
		enemy.hp = 60
	_check(preview._pinned.pin_enemy(app.enemies, 1, "warden"),
		"a foreign Warden pin waits on the first original slot")
	var before := _state()
	var oracle := _oracle(before, SHRAPNEL_PLUS)
	await _mouse(_panel(SHRAPNEL_PLUS))
	_same_as_oracle(before, oracle, "Shrapnel Seam+ with a foreign pin")
	_check(adapter.last_event == oracle.event and adapter.last_event.hits.size() == 2
		and adapter.last_event.hits[0].position == 1 and adapter.last_event.hits[0].damage == 15
		and adapter.last_event.hits[1].position == 2 and adapter.last_event.hits[1].damage == 10,
		"the foreign pin adds five to its own survivor, plus the once-only first attack")
	_check(app.enemies.get_enemy(1).hp == 45 and app.enemies.get_enemy(2).hp == 50,
		"both survivors keep their authored per-position damage")
	_check(_pins().is_empty(), "the cross-hero pin is consumed exactly once")
	_check(int(preview._unravel.get_snapshot(1).get("gauge", 0)) == 3
		and int(preview._unravel.get_snapshot(2).get("gauge", 0)) == 3,
		"Shrapnel Seam+ charges three Unravel on every survivor")
	_check(app.deck.energy == 1 and app.deck.discard_pile.count(SHRAPNEL_PLUS) == 1,
		"the paid area cast spends exactly two energy and one held copy")
	await _return()


## The new resolver must spend the starter presenter's one latch, never its own.
func _shrapnel_latch() -> void:
	for order in ["starter_first", "area_first"]:
		if not await _start(SHRAPNEL):
			await _return()
			continue
		app.deck.draw_pile.append("tinker_pop_shot")
		_check(app.deck.draw_extra(1) == 1 and app.deck.hand.has("tinker_pop_shot"),
			"authentic Pop Shot held beside Shrapnel Seam: " + order)
		app._refresh_hand()
		await _frames()
		for enemy in app.enemies._enemies:
			enemy.max_hp = 85
			enemy.hp = 85
		var ids: Array = ["tinker_pop_shot", SHRAPNEL] if order == "starter_first" \
			else [SHRAPNEL, "tinker_pop_shot"]
		for selected in ids:
			var before := _state()
			var oracle := _oracle(before, selected, selected == "tinker_pop_shot")
			if selected == "tinker_pop_shot":
				if not await _starter(selected):
					break
				_check(preview.last_event == oracle.event,
					"mounted starter ordered event equals independent starter oracle: " + order)
			else:
				await _mouse(_panel(selected))
				_check(adapter.last_event == oracle.event,
					"mounted Shrapnel ordered event equals independent pool oracle: " + order)
			_same_as_oracle(before, oracle, order + " / " + selected)
			_check(preview._play._tinker._consumed,
				"only one Tinker first-attack opportunity per turn: " + order)
		_check(app.deck.energy == 0,
			"the two-cost Shrapnel and one-cost Pop Shot spend the real turn exactly: " + order)
		await _return()


## AC2: a real paid Shrapnel Seam fills the normal gauge, and the next actual
## enemy phase consumes the queued skip through the shared round flow.
func _shrapnel_unravel_skip() -> void:
	# Baseline: the same announced Block action really executes without a skip.
	if not await _start(SHRAPNEL):
		await _return()
		return
	_check(int(app.enemies.get_enemy(2).get("block", 0)) == 0,
		"the second original enemy starts with no Block")
	app.end_turn_button.pressed.emit()
	await _frames()
	_check(app.enemy_intents._turn_index == 1
		and int(app.enemies.get_enemy(2).get("block", 0)) == 1,
		"without a pending skip the announced Block action executes")
	await _return()

	# The battle's own gauge holds a real six-thread charge before the cast.
	if not await _start(SHRAPNEL):
		await _return()
		return
	_check(preview._unravel.apply_unravel(app.enemies, 2, 6),
		"the battle's own gauge holds a real six-thread charge on slot 2")
	_check(app.round_flow._unravel == null,
		"the live round flow shares no gauge before the first gauge cast")
	var before := _state()
	var oracle := _oracle(before, SHRAPNEL)
	await _mouse(_panel(SHRAPNEL))
	_same_as_oracle(before, oracle, "Shrapnel Seam fills the normal gauge")
	var filled: Dictionary = preview._unravel.get_snapshot(2)
	_check(int(filled.get("gauge", 0)) == 8 and int(filled.get("threshold", 0)) == 8
		and bool(filled.get("unravelled", false)) and bool(filled.get("skip_pending", false)),
		"the normal gauge is exactly full with one pending skip")
	_check(int(preview._unravel.get_snapshot(1).get("gauge", 0)) == 2
		and int(preview._unravel.get_snapshot(1).get("threshold", 0)) == 8,
		"the other surviving slot charged only its authored two threads")
	_check(app.round_flow._unravel == preview._unravel,
		"the same battle gauge is bound to the live round flow by the real cast")
	_check(app.enemy_intents.get_intents()[1].get("type") == "block"
		and int(app.enemy_intents.get_intents()[1].get("amount", 0)) == 1,
		"the second original enemy has a genuine announced one-Block action")
	var pre_turn := _state()
	var hero_hp: Array = []
	for hero in pre_turn.party:
		hero_hp.append(int(hero.get("hp", 0)))
	app.end_turn_button.pressed.emit()
	await _frames()
	_check(app.enemy_intents._turn_index == 1 and app.deck.turn_active and app.deck.energy == 3,
		"the real End Turn opens the next player turn")
	_check(int(app.enemies.get_enemy(2).get("block", 0)) == 0,
		"the full gauge skips the announced enemy Block action")
	_check(app.enemies.get_enemy(1)["hp"] == int(pre_turn.enemies[0]["hp"]),
		"the skipped source never damages or replaces any enemy")
	var hp_kept := true
	for index in range(app.party.get_heroes().size()):
		if int(app.party.get_heroes()[index].get("hp", -1)) != int(hero_hp[index]):
			hp_kept = false
	_check(hp_kept, "hero HP is exactly unchanged through the skipped enemy phase")
	var reset: Dictionary = preview._unravel.get_snapshot(2)
	_check(int(reset.get("gauge", -1)) == 0 and int(reset.get("threshold", 0)) == 12
		and not bool(reset.get("skip_pending", true))
		and not bool(reset.get("unravelled", true)),
		"consuming the real skip resets the gauge and raises its threshold by four")
	_check(int(preview._unravel.get_snapshot(1).get("gauge", -1)) == 2
		and int(preview._unravel.get_snapshot(1).get("threshold", 0)) == 8,
		"the untouched first gauge keeps its own threshold and charge")
	_check(app.round_flow._unravel == preview._unravel,
		"the next enemy phase still shares the same battle gauge")
	await _return()


## AC3: illegal, absent-authority and title-restarted Shrapnel plays mutate nothing.
func _shrapnel_refusals() -> void:
	for mode in ["energy", "position", "removed", "hidden", "wrong_id", "replaced",
			"party", "rng", "turn", "intents", "result", "end_turn", "unbound_gauge",
			"foreign_gauge", "missing_pin"]:
		var id := SHRAPNEL
		if not await _start(id):
			await _return()
			return
		var panel := _panel(id)
		var callback: Callable = adapter._bindings[panel]["callback"]
		if mode == "energy":
			app.deck.combat_state.energy = 0
		elif mode == "position":
			var proposed := CombatPositionSwaps.preview_adjacent_swap(app.party, 3, -1)
			_check(proposed.ok, "move Tinker into the middle using real swap rules")
			app.party._heroes.assign(proposed.heroes)
			proposed = CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
			_check(proposed.ok, "move Tinker to the front using real swap rules")
			app.party._heroes.assign(proposed.heroes)
			_check(app.party.get_hero(1).id == "tinker",
				"bad Shrapnel Seam owner position really constructed")
		elif mode == "removed":
			_check(app.deck.discard_played(id), "held Shrapnel Seam removed before input")
		elif mode == "hidden":
			app.battle_view.hide()
		elif mode == "wrong_id":
			app.hand_view.get_child(panel.get_index()).get_child(0).text = SHRAPNEL_PLUS
		elif mode == "replaced":
			app._refresh_hand()
			await _frames()
		elif mode == "party":
			app.party = CombatParty.new(app._load_party_definitions())
		elif mode == "rng":
			app.run_rng = RandomNumberGenerator.new()
		elif mode == "turn":
			app.enemy_intents.advance_turn()
		elif mode == "intents":
			app.enemy_intents = CombatEnemyIntents.new(app._load_enemy_schedule())
		elif mode == "result":
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		elif mode == "end_turn":
			app.deck.end_turn()
		elif mode == "unbound_gauge":
			preview._unravel = CombatUnravel.new()
		elif mode == "foreign_gauge":
			app.round_flow._unravel = CombatUnravel.new()
		elif mode == "missing_pin":
			preview._pinned = null
		var before := _state()
		callback.call(_press())
		await _frames()
		var after := _state()
		if after != before:
			for field in before:
				if before[field] != after[field]:
					printerr("Shrapnel refusal drift ", mode, " ", field)
		_check(after == before and adapter._pending.is_empty(),
			"refused Shrapnel Seam input is wholly inert, including gauge, pin and RNG: " + mode)
		app.battle_view.show()
		await _return()


## A Shrapnel receipt that was valid at enqueue must die with the session it saw.
func _shrapnel_queued_stale() -> void:
	for mode in ["turn", "party", "rng", "intents", "panel", "result", "hidden"]:
		if not await _start(SHRAPNEL):
			await _return()
			return
		var panel := _panel(SHRAPNEL)
		var callback: Callable = adapter._bindings[panel]["callback"]
		callback.call(_press())
		_check(not adapter._pending.is_empty(),
			"valid Shrapnel input queues guarded receipt: " + mode)
		if mode == "turn":
			app.enemy_intents.advance_turn()
		elif mode == "party":
			app.party = CombatParty.new(app._load_party_definitions())
		elif mode == "rng":
			app.run_rng = RandomNumberGenerator.new()
		elif mode == "intents":
			app.enemy_intents = CombatEnemyIntents.new(app._load_enemy_schedule())
		elif mode == "panel":
			app._refresh_hand()
		elif mode == "result":
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		elif mode == "hidden":
			app.battle_view.hide()
		var before := _state()
		await _frames()
		_check(_state() == before and adapter._pending.is_empty(),
			"changed battle/turn/identity/panel invalidates queued Shrapnel receipt without spend, gauge, pin or RNG: " + mode)
		app.battle_view.show()
		await _return()


## AC3: Return retires the battle and a captured Shrapnel callback cannot
## mutate the old deck, gauge, pins or seeded RNG, nor the next battle.
func _shrapnel_title_restart() -> void:
	if not await _start(SHRAPNEL):
		await _return()
		return
	var panel := _panel(SHRAPNEL)
	var callback: Callable = adapter._bindings[panel]["callback"]
	var old_deck: CombatDeck = app.deck
	var old_rng: RandomNumberGenerator = app.run_rng
	var old_unravel: CombatUnravel = preview._unravel
	var old_pinned: CombatPinned = preview._pinned
	_check(preview._pinned.pin_enemy(app.enemies, 1, "warden"),
		"the old battle holds a real Pinned token before Return")
	var old_pins: Dictionary = old_pinned._pinner_by_position.duplicate(true)
	var old_gauges: Dictionary = old_unravel._gauges.duplicate(true)
	var old_hand: Array = old_deck.hand.duplicate()
	var old_energy: int = old_deck.energy
	var old_rng_state: int = old_rng.state
	await _return()
	_check(app.deck == null and adapter._bindings.is_empty() and adapter._pending.is_empty(),
		"Return retires the Shrapnel panel binding and receipt")
	callback.call(_press())
	await _frames()
	_check(old_deck.hand == old_hand and old_deck.energy == old_energy
		and old_rng.state == old_rng_state,
		"the captured Shrapnel callback cannot spend the retired deck or move the run RNG")
	_check(old_unravel._gauges == old_gauges and old_pinned._pinner_by_position == old_pins,
		"the retired gauge and pin set keep exactly the state they ended with")
	if not await _start(SHRAPNEL):
		await _return()
		return
	_check(preview._unravel != old_unravel and preview._pinned != old_pinned,
		"the next battle owns different Unravel and Pinned authorities")
	_check(app.round_flow._unravel == null,
		"the old gauge never leaks into the new round flow before a cast")
	_check(preview._pinned._pinner_by_position.is_empty(),
		"the next battle starts with no Pinned token")
	var fresh := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == fresh, "the captured old callback cannot mutate the new battle")
	await _return()


func _refusals() -> void:
	for mode in ["energy", "downed", "position", "targets", "removed", "hidden",
			"wrong_id", "replaced", "party", "rng", "turn", "intents", "result",
			"end_turn", "return"]:
		var id := "tinker_ricochet"
		if not await _start(id):
			await _return()
			return
		var panel := _panel(id)
		var callback: Callable = adapter._bindings[panel]["callback"]
		if mode == "energy":
			app.deck.combat_state.energy = 0
		elif mode == "downed":
			_check(app.party.apply_damage(3, 26) and app.party.is_downed(3),
				"downed Tinker rejection fixture is real")
		elif mode == "position":
			var proposed := CombatPositionSwaps.preview_adjacent_swap(app.party, 3, -1)
			_check(proposed.ok, "move Tinker into middle using real swap rules")
			app.party._heroes.assign(proposed.heroes)
			proposed = CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
			_check(proposed.ok, "move Tinker to front using real swap rules")
			app.party._heroes.assign(proposed.heroes)
			_check(app.party.get_hero(1).id == "tinker", "bad owner position really constructed")
		elif mode == "targets":
			for position in range(1, app.enemies.get_enemies().size() + 1):
				_check(app.enemies.apply_damage(position, 10000), "all real targets are slain")
		elif mode == "removed":
			_check(app.deck.discard_played(id), "hand copy removed before input")
		elif mode == "hidden":
			app.battle_view.hide()
		elif mode == "wrong_id":
			app.hand_view.get_child(panel.get_index()).get_child(0).text = "tinker_scatter_bolts"
		elif mode == "replaced":
			app._refresh_hand()
			await _frames()
		elif mode == "party":
			app.party = CombatParty.new(app._load_party_definitions())
		elif mode == "rng":
			app.run_rng = RandomNumberGenerator.new()
		elif mode == "turn":
			app.enemy_intents.advance_turn()
		elif mode == "intents":
			app.enemy_intents = CombatEnemyIntents.new(app._load_enemy_schedule())
		elif mode == "result":
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		elif mode == "end_turn":
			app.deck.end_turn()
		var before := _state()
		if is_instance_valid(panel) and mode != "return":
			# Refresh synchronously BEFORE an obsolete session can rebind.
			# No extra frame may run here: the original regression proves
			# that a captured callback is rejected after the authority swap.
			adapter._refresh_ricochet_tooltips()
			_check(not panel.tooltip_text.contains("hit 1 → enemy")
				and _state() == before,
				"stale or unplayable Ricochet has no invented quote or spend: " + mode)
		if mode == "targets":
			callback.call(_press())
			_check(_state() == before and adapter._pending.is_empty(),
				"zero-living-target callback is rejected before the regular victory observer")
			await _return()
			continue
		if mode == "return":
			var old_deck: CombatDeck = app.deck
			var old_rng: RandomNumberGenerator = app.run_rng
			await _return()
			callback.call(_press())
			await _frames()
			_check(old_deck.hand.has(id) and old_rng.state == before.rng,
				"returned battle rejects captured input without RNG movement")
			continue
		if mode in ["party", "rng", "turn", "intents", "result", "end_turn"]:
			# Prove a receipt that was valid at enqueue becomes stale.
			# The captured panel still cannot be played in a changed session.
			callback.call(_press())
		else:
			callback.call(_press())
		await _frames()
		var after := _state()
		if after != before:
			for field in before:
				if before[field] != after[field]:
					printerr("refusal drift ", mode, " ", field, ": ", before[field], " -> ", after[field])
		_check(after == before and adapter._pending.is_empty(),
			"refused/obsolete callback is wholly inert, including run RNG: " + mode)
		app.battle_view.show()
		await _return()


func _queued_and_discard() -> void:
	if not await _start("tinker_scatter_bolts"):
		await _return()
		return
	var panel := _panel("tinker_scatter_bolts")
	var callback: Callable = adapter._bindings[panel]["callback"]
	callback.call(_press())
	_check(not adapter._pending.is_empty(), "actual held input creates one deferred receipt")
	callback.call(_press())
	_check(not adapter._pending.is_empty(), "duplicate input shares pending receipt")
	_check(app.deck.end_turn(), "turn end clears held card without playing it")
	var before := _state()
	await _frames()
	_check(_state() == before and adapter._pending.is_empty(),
		"queued card cannot play after end-turn discard")
	_check(app.deck.discard_pile.has("tinker_scatter_bolts"),
		"card was discarded by End Turn rather than played")
	await _return()



## Find an authentic routed Fight with three original enemy positions; do not
## manufacture a roster disconnected from the mounted battle result.
func _three_enemy_fixture() -> Dictionary:
	for value in range(1, 1025):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var before: int = rng.state
		for choice in map.get_legal_choices():
			if map.get_node(choice).get("type") != "Fight":
				continue
			rng.state = before
			if not map.choose_node(choice):
				continue
			var selected := RunAuthoredBattleEntry.new().entry_current_battle(
				map, rng, RunFightEncounterSelection.new())
			map.undo_choice(choice, [])
			if selected.get("success", false) and selected["enemies"].get_enemies().size() == 3:
				return {"seed": value, "choice": choice}
	return {}


func _routed_three() -> void:
	var fixture: Dictionary = _three_enemy_fixture()
	_check(not fixture.is_empty(), "real authored run rotation offers a 3-enemy Fight")
	if fixture.is_empty():
		return
	app.run_seed = fixture.seed
	app.start_button.pressed.emit()
	await _frames()
	var button: Button = null
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == fixture.choice:
			button = candidate
			break
	_check(button != null and not button.disabled, "enabled map choice enters real 3-enemy fight")
	if button == null:
		await _return()
		return
	button.pressed.emit()
	await _frames()
	_check(app.deck != null and app.enemies.get_enemies().size() == 3
		and app.battle_result._enemies == app.enemies,
		"three-enemy Fight shares the battle result authority")
	if app.deck == null or app.enemies.get_enemies().size() != 3:
		await _return()
		return
	var id := "tinker_scatter_bolts_plus"
	for enemy in app.enemies._enemies:
		enemy.max_hp = 70
		enemy.hp = 70
	_check(app.enemies.apply_damage(2, 70) and app.enemies.is_slain(2)
		and app.enemies.get_enemy(3).position == 3,
		"slain middle keeps its original position; rightmost living slot remains 3")
	_check(app.enemies.gain_block(1, 3) and app.enemies.apply_statuses({3: {"exposed": 2}}),
		"authentic 3-enemy fight has distinct defensive statuses")
	app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(1) == 1, "routed shared deck drew authored Scatter+")
	app._refresh_hand()
	await _frames()
	_face(id)
	var before := _state()
	var oracle := _oracle(before, id)
	await _mouse(_panel(id))
	_same_as_oracle(before, oracle, "routed 3-enemy Scatter+")
	_check(adapter.last_event == oracle.event and adapter.last_event.hits.size() == 2
		and adapter.last_event.hits[0].position == 1
		and adapter.last_event.hits[1].position == 3
		and app.enemies.is_slain(2),
		"Scatter+ strikes living original slots 1,3 in order and leaves hole 2")
	# The same real routed fight then plays the authored target-free Shrapnel
	# Seam+ into the remaining original slots, sharing the consumed latch.
	var area := SHRAPNEL_PLUS
	app.deck.draw_pile.append(area)
	_check(app.deck.draw_extra(1) == 1, "routed shared deck drew authored Shrapnel Seam+")
	app._refresh_hand()
	await _frames()
	_face(area)
	var area_before := _state()
	var area_oracle := _oracle(area_before, area)
	_check(preview._play._tinker.bonus_for_attack(area) == 0,
		"the routed Scatter+ already consumed the shared first-attack bonus")
	await _mouse(_panel(area))
	_same_as_oracle(area_before, area_oracle, "routed 3-enemy Shrapnel Seam+")
	_check(adapter.last_event == area_oracle.event and adapter.last_event.hits.size() == 2
		and adapter.last_event.hits[0].position == 1
		and adapter.last_event.hits[1].position == 3
		and app.enemies.is_slain(2),
		"Shrapnel Seam+ strikes living original slots 1,3 in order and leaves hole 2")
	_check(int(preview._unravel.get_snapshot(1).get("gauge", 0)) == 3
		and int(preview._unravel.get_snapshot(3).get("gauge", 0)) == 3
		and int(preview._unravel.get_snapshot(2).get("gauge", 0)) == 0,
		"the routed area cast charges exactly its living original slots")
	_check(app.deck.energy == 0, "the routed area cast paid exactly its two-energy cost")
	await _return()



## The two real held Ricochets share the same battle, but never a stale
## tooltip. Rebinding, keyboard focus changes, roster deaths, energy and turn
## changes must recompute or retire the seeded sequence before another cast.
func _ricochet_quote_refresh() -> void:
	var base := "tinker_ricochet"
	var plus := "tinker_ricochet_plus"
	if not await _start(base):
		await _return()
		return
	app.deck.draw_pile.append(plus)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.has(plus),
		"second actual held Ricochet+ is drawn for switching focus")
	app._refresh_hand()
	await _frames()
	var first_panel := _panel(base)
	var plus_panel := _panel(plus)
	_check(first_panel != null and plus_panel != null
		and adapter._bindings.has(first_panel) and adapter._bindings.has(plus_panel),
		"both area cards have valid live hand bindings")
	if first_panel == null or plus_panel == null:
		await _return()
		return
	# Move pointer off the hand, then use genuine focus traversal.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(1, 1)
	root.push_input(motion, true)
	first_panel.grab_focus()
	await _frames()
	var original := _state()
	var oracle_base := _oracle(original, base)
	_check(oracle_base.event.get("ok", false) and not oracle_base.event.hits.is_empty()
		and first_panel.tooltip_text.contains(_quote_text(oracle_base.event.hits)),
		"first held Ricochet keyboard focus displays its genuine seeded route")
	plus_panel.grab_focus()
	await _frames()
	var second := _state()
	var oracle_plus := _oracle(second, plus)
	_check(oracle_plus.event.get("ok", false) and not oracle_plus.event.hits.is_empty()
		and plus_panel.tooltip_text.contains(_quote_text(oracle_plus.event.hits)),
		"focus switching to Ricochet+ quotes its own upgraded cast")
	_check(not first_panel.tooltip_text.contains("hit 1 → enemy")
		and _state() == original,
		"switching focus retires the earlier card forecast without any spend")
	# A seeded run RNG change must use the current seed, never cached order.
	app.run_rng.seed = 771
	var reseeded := _state()
	var reseeded_oracle := _oracle(reseeded, plus)
	await _frames()
	_check(reseeded_oracle.event.get("ok", false)
		and plus_panel.tooltip_text.contains(_quote_text(reseeded_oracle.event.hits))
		and _state() == reseeded,
		"focus quote tracks a changed run RNG without advancing it")
	# Leave only original foe 1 alive on two HP: later hits do not exist.
	for pos in range(2, app.enemies.get_enemies().size() + 1):
		var hp: int = app.enemies.get_enemy(pos).hp
		_check(app.enemies.apply_damage(pos, hp), "other foe actually slain in original slot")
	var first_hp: int = app.enemies.get_enemy(1).hp
	_check(first_hp >= 2 and app.enemies.apply_damage(1, first_hp - 2)
		and app.enemies.get_enemy(1).hp == 2, "only surviving target is two HP")
	var lethal_before := _state()
	await _frames()
	_check(plus_panel.tooltip_text.contains("If played now: hit 1 → enemy 1")
		and not plus_panel.tooltip_text.contains("hit 2")
		and _state() == lethal_before,
		"fresh living roster shortens the quote to one terminal original-slot hit")
	app.deck.combat_state.energy = 0
	var unaffordable := _state()
	await _frames()
	_check(plus_panel.tooltip_text.contains("If played now: unavailable")
		and not plus_panel.tooltip_text.contains("hit 1 → enemy")
		and _state() == unaffordable,
		"energy loss clears a previously legal hit order and does not commit")
	app.deck.combat_state.energy = 3
	app.enemy_intents.advance_turn()
	await _frames()
	var turn_now := _state()
	var refreshed := _oracle(turn_now, plus)
	var tooltip: String = plus_panel.tooltip_text
	_check((tooltip.contains(_quote_text(refreshed.event.hits))
		if refreshed.event.get("ok", false) else tooltip.contains("unavailable"))
		and _state() == turn_now,
		"turn/session refresh never promises an outdated hit order")
	_check(app.deck.end_turn(), "real end-turn retires forecast availability")
	await _frames()
	_check(not plus_panel.tooltip_text.contains("hit 1 → enemy")
		and not first_panel.tooltip_text.contains("hit 1 → enemy"),
		"turn end clears both held-card forecasts")
	await _return()


func _ricochet_reselect() -> void:
	var id := "tinker_ricochet_plus"
	if not await _start(id):
		await _return()
		return
	# Pick a doomed initial slot using a CLONE of the current run RNG; never
	# pre-advance the actual run stream just to predict a card result.
	var cloned := RandomNumberGenerator.new()
	cloned.state = app.run_rng.state
	var chosen: int = cloned.randi_range(0, app.enemies.get_enemies().size() - 1) + 1
	for enemy in app.enemies._enemies:
		enemy.max_hp = 70
		enemy.hp = 70
	app.enemies._enemies[chosen - 1].hp = 2
	var before := _state()
	var oracle := _oracle(before, id)
	_check(oracle.event.ok and oracle.event.hits.size() == 3
		and oracle.event.hits[0].position == chosen
		and oracle.event.hits[1].position != chosen
		and oracle.event.hits[2].position != chosen,
		"Ricochet+ independent oracle rerolls only living survivors after first lethal hit")
	await _mouse(_panel(id))
	_same_as_oracle(before, oracle, "Ricochet+ new living target every hit")
	_check(adapter.last_event == oracle.event
		and app.enemies.is_slain(chosen) and app.battle_result.can_continue(),
		"mounted sequential Ricochet+ uses no prechosen dead recipient")
	await _return()

	# With exactly one low-health survivor all later hits stop; the ordinary
	# mounted victory observer then closes the turn and awards gold.
	if not await _start(id):
		await _return()
		return
	for position in range(2, app.enemies.get_enemies().size() + 1):
		_check(app.enemies.apply_damage(position, 10000), "other enemy downed pre-cast")
	_check(app.enemies.apply_damage(1, app.enemies.get_enemy(1).hp - 2),
		"last living enemy has two HP")
	var before_final := _state()
	var terminal_oracle := _oracle(before_final, id)
	_check(terminal_oracle.event.ok and terminal_oracle.event.hits.size() == 1,
		"independent resolver stops after the last enemy dies")
	await _mouse(_panel(id))
	_check(adapter.last_event == terminal_oracle.event
		and app.enemies.is_victorious()
		and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and not app.deck.turn_active and app.deck.discard_pile.has(id),
		"one-hit Ricochet live victory stops remaining hits and uses battle's normal close")
	await _return()


func _queued_stale_receipts() -> void:
	for mode in ["turn", "party", "rng", "intents", "panel", "result", "hidden"]:
		var id := "tinker_scatter_bolts"
		if not await _start(id):
			await _return()
			return
		var panel := _panel(id)
		var callback: Callable = adapter._bindings[panel]["callback"]
		callback.call(_press())
		_check(not adapter._pending.is_empty(), "valid mounted input queues guarded receipt: " + mode)
		if mode == "turn":
			app.enemy_intents.advance_turn()
		elif mode == "party":
			app.party = CombatParty.new(app._load_party_definitions())
		elif mode == "rng":
			app.run_rng = RandomNumberGenerator.new()
		elif mode == "intents":
			app.enemy_intents = CombatEnemyIntents.new(app._load_enemy_schedule())
		elif mode == "panel":
			app._refresh_hand()
		elif mode == "result":
			app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		elif mode == "hidden":
			app.battle_view.hide()
		var before := _state()
		await _frames()
		_check(_state() == before and adapter._pending.is_empty(),
			"changed battle/turn/identity/panel invalidates queued receipt without spend/RNG: " + mode)
		app.battle_view.show()
		await _return()


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
	preview = app.get_node_or_null("LiveAttackPreview")
	_check(adapter != null and preview != null and app.deck == null,
		"actual scene mounts both presenters at title")
	if adapter == null or preview == null:
		app.free()
		_finish()
		return
	for id in IDS:
		var def: Dictionary = catalog.get_definition(id)
		_check(def.get("id") == id and def.get("cost") == 1 and def.get("owner") == "tinker",
			"authored and upgraded Tinker entries exist: " + id)
	for id in UNRAVEL_IDS:
		var area_def: Dictionary = catalog.get_definition(id)
		var area_effects: Dictionary = area_def.get("effects", {})
		_check(area_def.get("id") == id and area_def.get("cost") == 2
			and area_def.get("owner") == "tinker" and area_def.get("target_kind") == "enemy_all"
			and area_def.get("from_positions") == [3] and area_def.get("to_positions") == [1, 2, 3]
			and area_effects.get("living_targets_only") == true
			and int(area_effects.get("damage", 0)) == (7 if id.ends_with("_plus") else 5)
			and int(area_effects.get("unravel", 0)) == (3 if id.ends_with("_plus") else 2),
			"authored and upgraded Shrapnel Seam entries exist: " + id)
		_check(not CombatAttackTargeting.new().supports(id),
			"Shrapnel Seam stays out of the single-target picker: " + id)
		_check(CombatTinkerPoolUnravelAttacks.SUPPORTED_CARD_IDS.has(id),
			"the shared Unravel resolver owns the authored ID: " + id)
	await _case(IDS[0], false)
	await _case(IDS[1], true, KEY_ENTER)
	await _case(IDS[2], true, KEY_SPACE)
	await _case(IDS[3], false)
	await _case(IDS[0], false, KEY_ENTER, true)
	await _case(SHRAPNEL, false)
	await _case(SHRAPNEL_PLUS, true, KEY_ENTER)
	await _case(SHRAPNEL, true, KEY_SPACE)
	await _case(SHRAPNEL_PLUS, false)
	await _case(SHRAPNEL_PLUS, false, KEY_ENTER, true)
	await _sewn_arm_cases()
	await _sewn_button_eye_orders()
	await _sewn_refusals()
	await _shrapnel_pinned()
	await _shrapnel_latch()
	await _shrapnel_unravel_skip()
	await _routed_three()
	await _ricochet_reselect()
	await _ricochet_quote_refresh()
	await _shared_latch()
	await _queued_and_discard()
	await _queued_stale_receipts()
	await _shrapnel_queued_stale()
	await _shrapnel_refusals()
	await _shrapnel_title_restart()
	await _refusals()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_tinker_pool_area_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
