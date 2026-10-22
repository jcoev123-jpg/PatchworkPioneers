extends SceneTree
## Mounted target-free Tinker cards: real held input versus independent seeded
## CombatTinkerPoolAttacks, including the starter presenter's one shared latch.

const IDS := ["tinker_scatter_bolts", "tinker_scatter_bolts_plus",
	"tinker_ricochet", "tinker_ricochet_plus"]
const SHRAPNEL := "tinker_shrapnel_seam"
const SHRAPNEL_PLUS := "tinker_shrapnel_seam_plus"
const UNRAVEL_IDS := [SHRAPNEL, SHRAPNEL_PLUS]
const SEED := 42
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
	var event: Dictionary
	if is_starter:
		var starter := CombatAttackCards.new()
		starter._tinker = first
		event = starter.play_attack(deck, party, enemies, id, 1)
	elif id in UNRAVEL_IDS:
		event = CombatTinkerPoolUnravelAttacks.new(first).play_attack(deck, party,
			enemies, id, 0, unravel, pinned)
	else:
		event = CombatTinkerPoolAttacks.new(first).play_attack(deck, party, enemies, id, 0)
	return {"event": event, "draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"active": deck.turn_active, "party": party.get_heroes(),
		"enemies": enemies.get_enemies(), "rng": rng.state, "first": first._consumed,
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
	_check(face.get("variant", "").contains("Tinker") and face.variant.contains(
		adapter._positions(definition.from_positions)),
		"from-position and Tinker owner are printed: " + id)
	_check(face.get("area", "").contains(adapter._positions(definition.to_positions))
		and face.get("target", "").contains("No target choice"),
		"original enemy scope and target-free rule are visible: " + id)
	var effect: String = face.get("bleed", "")
	_check(effect.contains(str(effects.damage)) and effect.contains("+3 first attack")
		and (effect.contains("3 hits") if definition.target_kind == "enemy_random" else effect.contains("damage each")),
		"visible correct damage and authored hit count: " + id)
	if id in UNRAVEL_IDS:
		_check(effect.contains("Unravel %d" % int(effects.unravel))
			and face.get("area", "") == "All enemies %s" % adapter._positions(definition.to_positions)
			and panel.tooltip_text.contains("Unravel %d" % int(effects.unravel)),
			"visible Unravel charge and original-position area scope: " + id)
	_check(panel.tooltip_text.contains(definition.display_name)
		and panel.tooltip_text.contains("Enter / Space")
		and panel.tooltip_text.contains("Tinker") and panel.tooltip_text.contains("no target choice"),
		"tooltip explains keyboard, owner, scope and hit rule: " + id)
	var cue = adapter._bindings[panel].get("cue")
	_check(is_instance_valid(cue) and cue.is_visible_in_tree() and cue.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and cue.focus_mode == Control.FOCUS_NONE and cue.get_index() > 0
		and cue.get_theme_stylebox("panel").border_color == Color("#c49a3a"),
		"noninteractive mustard sewn-paper overlay covers real held panel: " + id)
	_check(not panel.get_child(0).is_visible_in_tree()
		and not panel.focus_neighbor_bottom.is_empty()
		and panel.get_node_or_null(panel.focus_neighbor_bottom) == app.end_turn_button,
		"hidden original label and usable End Turn focus exit: " + id)
	_check(root.size == Vector2i(1280, 720) and cue.size == panel.size,
		"1280x720 headless viewport and legible full-panel sewn face: " + id)
	_check(adapter.button == null and adapter.get_child_count() == 0,
		"no second attack button or overlay node exists: " + id)


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
	await _shrapnel_pinned()
	await _shrapnel_latch()
	await _shrapnel_unravel_skip()
	await _routed_three()
	await _ricochet_reselect()
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
