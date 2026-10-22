extends SceneTree
## Mounted D2-1 self-energy cards: real held panels, physical mouse/keyboard,
## independent CombatPoolEnergyCards oracle, seeded draws and fail-closed receipts.

const IDS := ["tinker_overclock", "tinker_overclock_plus",
	"seamstress_tailors_trance", "seamstress_tailors_trance_plus"]
const SEED := 1407

var checks := 0
var failures: Array[String] = []
var app
var adapter
var preview
var service := CombatPoolEnergyCards.new()


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _frames() -> void:
	for index in range(4):
		await process_frame


func _panel(card_id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and panel.get_child(0).text == card_id:
			return panel
	return null


func _mouse(panel: Control) -> void:
	var center: Vector2 = panel.get_global_rect().get_center()
	_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(center),
		"real held panel mouse hit inside 1280x720 viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = center
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = center
		event.pressed = pressed
		root.push_input(event, true)
		if pressed:
			root.push_input(event, true)
	await _frames()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _state() -> Dictionary:
	return {"draw": app.deck.draw_pile.duplicate(), "hand": app.deck.hand.duplicate(),
		"discard": app.deck.discard_pile.duplicate(), "energy": app.deck.energy,
		"active": app.deck.turn_active, "party": app.party.get_heroes(),
		"enemies": app.enemies.get_enemies(), "seed": app.run_rng.seed,
		"rng": app.run_rng.state, "deck_rng": app.deck._rng.state,
		"first": preview._play._tinker._consumed,
		"intents": app.enemy_intents.get_intents(),
		"turn": app.enemy_intents._turn_index, "attacks": app.enemy_attacks.duplicate(true),
		"outcome": app.battle_result.get_outcome(), "closed": app._battle_closed,
		"gold": app.session_gold}


func _oracle(before: Dictionary, card_id: String) -> Dictionary:
	# An independent service, deck, party and generator, not the live objects.
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
	var ok: bool = CombatPoolEnergyCards.new().play_card(deck, party, card_id, 0)
	return {"ok": ok, "draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"party": party.get_heroes(), "rng": rng.state}


func _compare(before: Dictionary, expected: Dictionary, card_id: String) -> void:
	_check(expected.ok, "independent energy resolver accepts real held " + card_id)
	_check(app.deck.draw_pile == expected.draw and app.deck.hand == expected.hand
		and app.deck.discard_pile == expected.discard and app.deck.energy == expected.energy,
		"exact draw/hand/discard/energy equals detached oracle: " + card_id)
	_check(app.party.get_heroes() == expected.party,
		"Block, HP and downed party state equal detached oracle: " + card_id)
	_check(app.run_rng.state == expected.rng and app.deck._rng.state == expected.rng,
		"actual injected run/deck RNG equals independent seeded oracle: " + card_id)
	_check(preview._play._tinker._consumed == before.first,
		"self card never consumes shared first-attack latch: " + card_id)
	_check(app.enemies.get_enemies() == before.enemies and app.enemy_attacks == before.attacks
		and app.enemy_intents.get_intents() == before.intents
		and app.enemy_intents._turn_index == before.turn,
		"self utility cannot attack or progress enemy turn: " + card_id)
	_check(app.battle_result.get_outcome() == before.outcome and app._battle_closed == before.closed
		and app.session_gold == before.gold,
		"nonterminal self cast preserves outcome/loot: " + card_id)
	_check(app.deck.turn_active == before.active and adapter._pending.is_empty(),
		"single receipt has retired without changing turn: " + card_id)
	_check(app.hand_view.get_child_count() == app.deck.hand.size()
		and app.pile_label.text == "Draw: %d | Discard: %d" % [
			app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		"live hand and pile label refreshed: " + card_id)
	for position in range(1, 4):
		var hero: Dictionary = app.party.get_hero(position)
		var label: Label = app.hero_panels[position - 1].get_child(0) as Label
		_check(label != null and label.text.contains("HP: %d/%d | Block: %d" % [
			hero.hp, hero.max_hp, hero.block])
			and (label.text.contains("DOWNED") == app.party.is_downed(position)),
			"live HP, Block and downed counters refreshed for hero " + str(position))


func _start(card_id: String) -> bool:
	_check(app.deck == null, "title session precedes new live battle")
	app.run_seed = SEED
	if not app._start_battle():
		_check(false, "real 3-hero encounter starts")
		return false
	await _frames()
	var ready: bool = app.deck != null and app.deck.turn_active and app.party != null \
		and app.party.is_valid() and app.enemies != null and app.enemies.is_valid() \
		and app.battle_result != null and app.run_rng != null \
		and app.deck._rng == app.run_rng and preview._play != null
	_check(ready, "mounted fight shares real deck/party/result and seeded run RNG")
	if ready:
		_check(app.deck.hand.size() == CombatDeck.TURN_DRAW
			and app.deck.energy == CombatState.TURN_ENERGY,
			"genuine shared three-hero battle starts with five held cards and three energy")
	if not ready:
		return false
	var definition: Dictionary = _definition(card_id)
	_check(definition.get("id") == card_id and definition.get("target_kind") == "self"
		and definition.get("to_positions", null) == [],
		"authored real self-card definition is present: " + card_id)
	app.deck.draw_pile.append(card_id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.has(card_id),
		"real CombatDeck draws authored ID into shared hand: " + card_id)
	app._refresh_hand()
	await _frames()
	var panel: Control = _panel(card_id)
	_check(panel != null and adapter._bindings.has(panel),
		"live adapter binds real held panel: " + card_id)
	return panel != null and adapter._bindings.has(panel)


func _definition(card_id: String) -> Dictionary:
	return TinkerPoolCards.new().get_definition(card_id) if card_id.begins_with("tinker_") \
		else SeamstressPoolCards.new().get_definition(card_id)


func _face(card_id: String) -> void:
	var panel: Control = _panel(card_id)
	if panel == null:
		_check(false, "actual held panel required for visible face")
		return
	var definition: Dictionary = _definition(card_id)
	var effect: Dictionary = definition.effects
	var face: Dictionary = adapter.face_text(panel)
	var is_tinker: bool = card_id.begins_with("tinker_")
	_check(panel.get_parent() == app.hand_view
		and panel.get_child(0) is Label and panel.get_child(0).text == card_id
		and panel.get_index() == app.deck.hand.find(card_id)
		and not panel.get_child(0).is_visible_in_tree(),
		"canonical hidden ID, exact deck index, actual shared hand: " + card_id)
	_check(panel.gui_input.get_connections().size() == 1
		and panel.focus_mode == Control.FOCUS_ALL
		and panel.mouse_filter == Control.MOUSE_FILTER_STOP,
		"one real input callback, keyboard focus, mouse hit routing: " + card_id)
	_check(face.get("name") == definition.display_name and face.name != "Unknown card"
		and face.get("cost", "").contains("%d energy" % int(definition.cost)),
		"visible exact authored name and cost: " + card_id)
	_check(face.get("variant", "").contains("Tinker" if is_tinker else "Seamstress")
		and face.get("variant", "").contains(adapter._positions(definition.from_positions))
		and face.get("area", "").contains("Self")
		and face.get("target", "").contains("No target choice"),
		"visible owner, from positions and self-only targeting: " + card_id)
	var expected_effect: String = ("Gain 1 energy; 3 self-damage (Block first)" if is_tinker else
		"Gain 1 energy; draw %d cards" % int(effect.draw))
	_check(face.get("bleed", "") == expected_effect
		and not face.get("bleed", "").contains("first attack")
		and not face.get("area", "").contains("enemies"),
		"self utility effect is printed without misleading enemy/attack cues: " + card_id)
	_check(panel.tooltip_text.contains(definition.display_name)
		and panel.tooltip_text.contains("Enter / Space")
		and panel.tooltip_text.contains("Self:")
		and panel.tooltip_text.contains("no target choice"),
		"tooltip conveys keyboard access and real self rules: " + card_id)
	var cue = adapter._bindings[panel].get("cue")
	_check(is_instance_valid(cue) and cue.is_visible_in_tree()
		and cue.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and cue.focus_mode == Control.FOCUS_NONE and cue.get_index() > 0
		and cue.get_theme_stylebox("panel").border_color == (Color("#c49a3a") if is_tinker else Color("#6e4f6b")),
		"cream noninteractive stitched owner-colour face: " + card_id)
	_check(root.size == Vector2i(1280, 720) and cue.size == panel.size
		and adapter.button == null and adapter.get_child_count() == 0,
		"1280x720 full-panel cue with no extra controls: " + card_id)


func _return() -> void:
	if is_instance_valid(app.return_button):
		app.return_button.pressed.emit()
	await _frames()


func _cast(card_id: String, use_key: bool, code: Key = KEY_ENTER,
		near_lethal: bool = false, block_case: bool = false,
		draw_mode: String = "ordinary") -> void:
	if not await _start(card_id):
		await _return()
		return
	_face(card_id)
	var is_tinker: bool = card_id.begins_with("tinker_")
	var owner_slot: int = 0
	for hero in app.party.get_heroes():
		if hero.id == ("tinker" if is_tinker else "seamstress"):
			owner_slot = int(hero.position)
	_check(owner_slot == (3 if is_tinker else 2), "real living owner starts in legal slot")
	if near_lethal:
		var hp: int = int(app.party.get_hero(owner_slot).hp)
		_check(app.party.apply_damage(owner_slot, hp - 3)
			and app.party.get_hero(owner_slot).hp == 3
			and app.party.get_hero(owner_slot).block == 0,
			"near-lethal owner has exactly 3 HP and zero Block")
	elif block_case:
		_check(app.party.gain_block(owner_slot, 2)
			and app.party.get_hero(owner_slot).block == 2,
			"real owner obtains two damage-absorbing Block")
	if not is_tinker and draw_mode == "refill":
		# Preserve only legitimate starter cards from the seeded run in discard.
		app.deck.discard_pile.append_array(app.deck.draw_pile)
		app.deck.draw_pile.clear()
		_check(app.deck.discard_pile.size() >= 3,
			"actual starter card discard supplies seeded reshuffle")
	elif not is_tinker and draw_mode == "empty":
		app.deck.draw_pile.clear()
		app.deck.discard_pile.clear()
		_check(app.deck.draw_pile.is_empty() and app.deck.discard_pile.is_empty(),
			"empty-supply fixture contains only legitimately held copies")
	var panel: Control = _panel(card_id)
	var callback: Callable = adapter._bindings[panel]["callback"]
	var before: Dictionary = _state()
	var expected: Dictionary = _oracle(before, card_id)
	_check(expected.ok, "detached oracle has valid cast preconditions: " + card_id)
	if use_key:
		panel.grab_focus()
		_check(panel.has_focus(), "focused authentic held card before key " + card_id)
		await _key(code)
	else:
		await _mouse(panel)
	_compare(before, expected, card_id)
	_check(adapter.last_event.get("ok", false) and adapter.last_event.get("card_id") == card_id
		and adapter.last_event.get("target_kind") == "self",
		"successful self card publishes one true receipt: " + card_id)
	_check(app.deck.discard_pile.count(card_id) == before.discard.count(card_id) + 1
		and (app.deck.hand.count(card_id) + app.deck.draw_pile.count(card_id)
			+ app.deck.discard_pile.count(card_id))
			== (before.hand.count(card_id) + before.draw.count(card_id)
			+ before.discard.count(card_id)),
		"exact played copy discarded once and catalog ID count conserved")
	if is_tinker:
		_check(app.deck.energy == before.energy + 1
			and app.run_rng.state == before.rng
			and app.party.get_hero(owner_slot).block == (0 if block_case else before.party[owner_slot - 1].block),
			"Overclock pays +1 regardless of Block/HP, never spends RNG")
		if near_lethal:
			_check(app.party.is_downed(owner_slot) and app.party.get_hero(owner_slot).hp == 0,
				"3 HP/0 Block Overclock downs Tinker and still awards energy")
		elif block_case:
			_check(app.party.get_hero(owner_slot).hp == before.party[owner_slot - 1].hp - 1,
				"Block-first Overclock absorbs two damage before one HP")
	else:
		var amount: int = 3 if card_id.ends_with("_plus") else 2
		var supply: int = before.draw.size() + before.discard.size()
		_check(app.deck.energy == before.energy
			and app.deck.hand.size() == before.hand.size() - 1 + mini(amount, supply),
			"Trance pays then gains 1 energy; draws exactly available 2/3 cards")
		if draw_mode == "empty":
			_check(app.run_rng.state == before.rng and app.deck.hand.size() == before.hand.size() - 1,
				"empty supply cannot create cards or advance RNG")
		elif draw_mode == "refill":
			_check(app.run_rng.state != before.rng,
				"actual seeded discard reshuffle advances the one run RNG")
	var after: Dictionary = _state()
	callback.call(_press())
	await _frames()
	_check(_state() == after and adapter._pending.is_empty(),
		"stale repeated mouse/key callback cannot spend twice: " + card_id)
	await _return()


func _reject(card_id: String, mode: String) -> void:
	if not await _start(card_id):
		await _return()
		return
	var panel: Control = _panel(card_id)
	var callback: Callable = adapter._bindings[panel]["callback"]
	if mode == "misposition":
		var proposed: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
		_check(proposed.get("ok", false), "authentic adjacent swap can move Seamstress to slot 1")
		if proposed.get("ok", false):
			app.party._heroes.assign(proposed.heroes)
		_check(app.party.get_hero(1).id == "seamstress", "Trance owner truly at forbidden slot 1")
	elif mode == "downed":
		var owner_slot: int = 3 if card_id.begins_with("tinker_") else 2
		var hp: int = int(app.party.get_hero(owner_slot).hp)
		_check(app.party.apply_damage(owner_slot, hp)
			and app.party.is_downed(owner_slot), "real card owner is downed")
	elif mode == "energy":
		_check(app.deck.try_spend_energy(app.deck.energy) and app.deck.energy == 0,
			"Trance genuinely lacks its one energy")
	elif mode == "unheld":
		_check(app.deck.discard_played(card_id) and not app.deck.hand.has(card_id),
			"captured panel ID is no longer held")
	elif mode == "removed":
		app._refresh_hand()
		await _frames()
		_check(not adapter._bindings.has(panel), "old panel has actually been replaced and unbound")
	elif mode == "finished":
		for position in range(1, app.enemies.get_enemies().size() + 1):
			_check(app.enemies.apply_damage(position, 10000),
				"real enemy dies before completed-battle refusal")
		_check(app.battle_result.evaluate() == CombatBattleResult.VICTORY,
			"authentic completed battle evaluates to victory")
		app._observe_battle_result()
		await _frames()
		_check(app._battle_closed and not app.deck.turn_active,
			"live victory observer closes the combat input window")
	elif mode == "hidden":
		app.battle_view.hide()
		_check(not panel.is_visible_in_tree(), "original battle panel is hidden")
	var before: Dictionary = _state()
	callback.call(_press())
	await _frames()
	var after: Dictionary = _state()
	_check(after == before and adapter._pending.is_empty(),
		"invalid real panel input is atomic with no RNG drift: " + card_id + "/" + mode)
	app.battle_view.show()
	await _return()


func _queued_and_rebind() -> void:
	if not await _start("tinker_overclock_plus"):
		await _return()
		return
	var panel: Control = _panel("tinker_overclock_plus")
	var callback: Callable = adapter._bindings[panel]["callback"]
	callback.call(_press())
	_check(not adapter._pending.is_empty(), "valid held click enqueues one deferred receipt")
	callback.call(_press())
	_check(not adapter._pending.is_empty(), "repeat input retains same queued receipt")
	_check(app.deck.end_turn(), "real turn end discards unplayed held card")
	var before: Dictionary = _state()
	await _frames()
	_check(_state() == before and adapter._pending.is_empty(),
		"stale queued receipt cannot play after real turn ends")
	await _return()
	# A captured callback from the previous battle must never affect a new battle.
	if not await _start("seamstress_tailors_trance"):
		await _return()
		return
	var fresh_before: Dictionary = _state()
	callback.call(_press())
	await _frames()
	_check(_state() == fresh_before and adapter._pending.is_empty(),
		"previous battle/title callback cannot commit in a rebound battle")
	_check(_panel("seamstress_tailors_trance") != null
		and adapter._bindings.has(_panel("seamstress_tailors_trance")),
		"new battle legitimately rebinds only its held self card")
	await _return()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real runnable app scene loads")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	adapter = app.get_node_or_null("LiveAreaAttackAction")
	preview = app.get_node_or_null("LiveAttackPreview")
	_check(adapter != null and preview != null and app.deck == null,
		"actual title mounts existing adapter and first-attack presenter")
	if adapter == null or preview == null:
		app.free()
		_finish()
		return
	for card_id in IDS:
		var definition: Dictionary = _definition(card_id)
		_check(service.is_supported_card(card_id) and definition.get("id") == card_id
			and definition.get("owner") == ("tinker" if card_id.begins_with("tinker_") else "seamstress"),
			"catalog-backed supported energy card " + card_id)
	await _cast(IDS[0], false, KEY_ENTER, false, true)
	await _cast(IDS[1], true, KEY_ENTER, true)
	await _cast(IDS[0], true, KEY_SPACE)
	await _cast(IDS[2], false)
	await _cast(IDS[3], true, KEY_SPACE)
	await _cast(IDS[2], true, KEY_ENTER, false, false, "refill")
	await _cast(IDS[3], false, KEY_ENTER, false, false, "empty")
	for item in [
		[IDS[2], "misposition"], [IDS[0], "downed"], [IDS[3], "downed"],
		[IDS[2], "energy"], [IDS[0], "unheld"], [IDS[3], "removed"],
		[IDS[1], "finished"], [IDS[2], "hidden"]]:
		await _reject(item[0], item[1])
	await _queued_and_rebind()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_pool_energy_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
