extends SceneTree
## Mounted shared-hand coverage for the five resolved Warden pure-Block pool cards.
## Real scene, real CombatDeck draw, real hand panels and authoritative battle state.
## Expected Block is derived independently from the authored catalog, never from the
## resolver's return value. The routed cases admit a genuine Fight through the authored
## opening book with the run's real RunTornCarryover, so a sewn M05 Hemguard Cuff is
## applied by the live shared-hand transaction, never by a detached fake effect.

const INSTRUCTION := "Click or focus and press Enter / Space to play"
const REQUIRED_BASE_IDS := [
	"warden_hold_the_line",
	"warden_patch_guard",
	"warden_quick_darn",
	"warden_iron_hem",
	"warden_bastion_quilt",
]

var failures: Array[String] = []
var checks := 0
var app
var presenter
var catalog := WardenPoolCards.new()
## The seeded authored opening book that offers two connected Fights, resolved once.
var opening_seed := -1
var opening_fight := ""
var next_fight := ""


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
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


func _mouse(control: Control, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
		if pressed:
			# A duplicate press before deferred activation must resolve only once.
			root.push_input(event, true)
	await _frames()


func _press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _forms() -> Array[String]:
	var ids: Array[String] = []
	for base_id in REQUIRED_BASE_IDS:
		ids.append(base_id)
		ids.append(base_id + "_plus")
	return ids


func _panel(card_id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and panel.get_child(0).text == card_id:
			return panel
	return null


func _state() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(),
		app.intent_label.text, app.run_rng.seed, app.run_rng.state,
		app.battle_result.get_outcome(), app.session_gold]


func _from_text(positions: Array) -> String:
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


func _target_text(target_kind: String) -> String:
	match target_kind:
		"self":
			return "Self"
		"ally_single":
			return "Ally"
		"party_all":
			return "All living heroes"
	return "Unknown target"


func _effect_phrases(definition: Dictionary) -> Array[String]:
	var effects: Dictionary = definition.get("effects", {})
	var phrases: Array[String] = []
	if effects.has("block"):
		phrases.append("BASE gain %d Block" % int(effects["block"]))
	if effects.has("other_ally_block"):
		phrases.append("BASE each other living ally gains %d Block" % int(effects["other_ally_block"]))
	if effects.has("block_all"):
		phrases.append("BASE each living hero gains %d Block" % int(effects["block_all"]))
	return phrases


## The Hemguard Cuff bonus is an authored +N on the card's own positive "block"
## field: it never touches "block_all" or "other_ally_block" (brief M05 semantics).
func _blocks_after(heroes: Array, definition: Dictionary, target_position: int,
		bonus: int = 0) -> Dictionary:
	var effects: Dictionary = definition.get("effects", {})
	var blocks := {}
	var owner_position := 0
	for hero in heroes:
		blocks[hero.position] = int(hero.block)
		if hero.id == "warden":
			owner_position = int(hero.position)
	match definition.get("target_kind", ""):
		"self":
			blocks[owner_position] += int(effects["block"]) + bonus
			if effects.has("other_ally_block"):
				for hero in heroes:
					if hero.id != "warden" and int(hero.hp) > 0:
						blocks[hero.position] += int(effects["other_ally_block"])
		"party_all":
			for hero in heroes:
				if int(hero.hp) > 0:
					blocks[hero.position] += int(effects["block_all"])
		"ally_single":
			blocks[target_position] += int(effects["block"]) + bonus
	return blocks


## Block each hero actually gained from the committed card, in hero-slot order.
func _party_block_gain(before: Array) -> Array:
	var values := []
	for index in range(before.size()):
		values.append(int(app.party.get_hero(index + 1).block) - int(before[index].block))
	return values


## Independent catalog-derived expectation: only authored Block recipients differ;
## every other field on every hero, enemy, pile, intent and RNG stays identical.
## `bonus` is the authenticated cuff amount the live resolver may add to the card's
## own "block" field only; `expected_blocks` is the exact Block each living hero
## gained from the committed card, if given.
func _assert_success(card_id: String, before: Array, target_position: int, stage: String,
		bonus: int = 0, expected_blocks: Array = []) -> void:
	var definition: Dictionary = catalog.get_definition(card_id)
	var cost: int = int(definition.get("cost", -1))
	_check(app.deck.energy == int(before[3]) - cost, "exactly one authored energy payment: " + stage)
	var expected_hand: Array = before[1].duplicate()
	expected_hand.erase(card_id)
	_check(app.deck.hand == expected_hand and not app.deck.hand.has(card_id),
		"exactly one held copy discarded: " + stage)
	var expected_discard: Array = before[2].duplicate()
	expected_discard.append(card_id)
	_check(app.deck.discard_pile == expected_discard and app.deck.discard_pile.back() == card_id,
		"played card lands in discard once: " + stage)
	_check(app.deck.draw_pile == before[0], "draw pile unchanged: " + stage)
	_check(app.deck.turn_active == before[4], "turn state unchanged: " + stage)
	var blocks := _blocks_after(before[5], definition, target_position, bonus)
	for index in range(before[5].size()):
		var was: Dictionary = before[5][index]
		var now: Dictionary = app.party.get_hero(index + 1)
		var expected: Dictionary = was.duplicate(true)
		expected.block = blocks[was.position]
		_check(now == expected, "only authored Block recipients changed: %s slot %d" % [stage, index + 1])
		_check(now.block == blocks[was.position], "exact catalog Block total: %s slot %d" % [stage, index + 1])
	if not expected_blocks.is_empty():
		_check(_party_block_gain(before[5]) == expected_blocks,
			"exact live party Block gain %s (live %s): %s" % [
				str(expected_blocks), str(_party_block_gain(before[5])), stage])
	_check(app.enemies.get_enemies() == before[6], "enemy roster unchanged: " + stage)
	_check(app.enemy_attacks == before[7], "enemy attacks unchanged: " + stage)
	_check(app.enemy_intents.get_intents() == before[8], "enemy intents unchanged: " + stage)
	_check(app.intent_label.text == before[9], "intent label unchanged: " + stage)
	_check(app.run_rng.seed == before[10] and app.run_rng.state == before[11],
		"injected run RNG untouched: " + stage)
	_check(app.battle_result.get_outcome() == before[12], "battle outcome unchanged: " + stage)
	_check(app.session_gold == before[13], "session gold unchanged: " + stage)
	_check(presenter._pending.is_empty() and presenter._targets.is_empty(),
		"success leaves no pending target or handler: " + stage)
	_check(is_instance_valid(app.hand_view) and app.hand_view.get_child_count() == app.deck.hand.size(),
		"mounted hand matches post-play hand count: " + stage)


func _assert_display(card_id: String, stage: String) -> void:
	var panel := _panel(card_id)
	_check(is_instance_valid(panel), "real held pool panel mounted: " + card_id)
	if panel == null:
		return
	var definition: Dictionary = catalog.get_definition(card_id)
	_check(not definition.is_empty() and definition.get("id") == card_id, "authored catalog record: " + card_id)
	var facts: Dictionary = presenter._metadata.get_facts(panel)
	_check(facts.get("known") == true and facts.get("id") == card_id, "catalog-derived known facts: " + card_id)
	_check(facts.get("owner") == "warden" and facts.get("owner_text") == "Warden", "warden owner badge: " + card_id)
	_check(facts.get("cost") == int(definition.get("cost", -1))
		and facts.get("cost_text") == "Cost %d" % int(definition.get("cost", -1)), "authored cost badge: " + card_id)
	_check(facts.get("from_text") == "From " + _from_text(definition.get("from_positions", [])),
		"authored source positions: " + card_id)
	_check(facts.get("target_text") == _target_text(definition.get("target_kind", "")),
		"authored target line: " + card_id)
	_check(presenter._metadata._bindings.has(panel) and presenter._metadata._bindings[panel]["draw_count"] > 0,
		"real panel actually drew catalog decoration: " + card_id)
	_check(panel.focus_mode == Control.FOCUS_ALL and panel.gui_input.get_connections().size() == 1,
		"pool card keeps exactly one mounted input binding: " + card_id)
	_check(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "pool card stays pointer reachable: " + card_id)
	_check(panel.get_child(0).text == card_id and not panel.get_child(0).visible,
		"original ID label retained but never rendered: " + card_id)
	_check(panel.tooltip_text.begins_with(INSTRUCTION), "mounted play instruction: " + card_id)
	_check(panel.tooltip_text.contains(definition.get("display_name", "")), "catalog display name in tooltip: " + card_id)
	for phrase in _effect_phrases(definition):
		_check(panel.tooltip_text.contains(phrase), "tooltip shows every recipient's Block: %s (%s)" % [card_id, phrase])
	_check(presenter.energy_label.text == "%d" % app.deck.energy, "energy orb authoritative: " + card_id)
	_check(presenter.help_label.text == presenter.TABLE_HELP, "shared hand help outside targeting: " + stage)


func _start(card_id: String) -> bool:
	_check(app.deck == null, "title precedes a fresh mounted battle")
	app.run_seed = 42
	_fixture_start(app)
	await _frames()
	var ready: bool = app.deck is CombatDeck and app.party is CombatParty and app.enemies != null \
		and app.battle_result != null and app.run_rng != null and is_instance_valid(app.battle_view) \
		and is_instance_valid(app.hand_view)
	_check(ready, "real standalone battle starts complete")
	if not ready:
		return false
	# The run deck owns reward cards in live play; put one authored copy through the
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


func _play_target_free(card_id: String, keyboard: bool) -> void:
	if not await _start(card_id):
		await _return()
		return
	_assert_display(card_id, "before " + card_id)
	var panel := _panel(card_id)
	var callback: Callable = presenter._bindings[panel]
	var before := _state()
	if keyboard:
		panel.grab_focus()
		_check(panel.has_focus(), "keyboard path focuses the real pool panel: " + card_id)
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	_assert_success(card_id, before, 0, card_id)
	var after := _state()
	# Replaying the captured callback after the successful play must be inert.
	callback.call(_key(KEY_ENTER))
	await _frames()
	_check(_state() == after, "captured callback cannot charge a second time: " + card_id)
	await _return()


## Patch Guard keeps the starter living-ally targeting UI: arm, choose, commit.
func _play_patch_guard(card_id: String, keyboard: bool) -> void:
	if not await _start(card_id):
		await _return()
		return
	_assert_display(card_id, "before " + card_id)
	var definition: Dictionary = catalog.get_definition(card_id)
	var panel := _panel(card_id)
	var before := _state()
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	_check(_state() == before, "arming Patch Guard never pre-spends: " + card_id)
	var choosing: bool = presenter._pending.get("choosing", false)
	_check(choosing and presenter.cancel_button.is_visible_in_tree(), "real living-ally target mode: " + card_id)
	_check(presenter.help_label.text == "%s: choose a living ally | Esc: cancel" % definition.display_name,
		"targeting help names the authored card: " + card_id)
	for index in range(3):
		var hero: Control = app.hero_panels[index]
		var living: bool = not app.party.is_downed(index + 1)
		_check(presenter._targets.has(hero) == living, "only living ally is targetable: " + card_id)
		_check((hero.focus_mode == Control.FOCUS_ALL) == living, "only living ally focusable: " + card_id)
	var target := 2
	var hero: Control = app.hero_panels[target - 1]
	if keyboard:
		app.hero_panels[0].grab_focus()
		for step in range(target - 1):
			await _keyboard(KEY_TAB)
		_check(hero.has_focus(), "Tab reaches the chosen living ally: " + card_id)
		root.push_input(_key(KEY_ENTER), true)
		root.push_input(_key(KEY_ENTER), true)
		root.push_input(_key(KEY_ENTER, false), true)
		await _frames()
	else:
		await _mouse(hero)
	_assert_success(card_id, before, target, card_id)
	_check(app.party.get_hero(target).block == _blocks_after(before[5], definition, target)[target],
		"chosen ally received the authored Block: " + card_id)
	await _return()


func _cancellation_cases() -> void:
	for card_id in ["warden_patch_guard", "warden_patch_guard_plus"]:
		for mode in ["escape", "cancel_button"]:
			if not await _start(card_id):
				await _return()
				continue
			var panel := _panel(card_id)
			var before := _state()
			await _mouse(panel)
			_check(presenter._pending.get("choosing", false), "cancel case really armed: " + card_id + "/" + mode)
			if mode == "escape":
				await _keyboard(KEY_ESCAPE)
			else:
				await _mouse(presenter.cancel_button)
			_check(_state() == before, "target cancellation spends nothing: " + card_id + "/" + mode)
			_check(presenter._pending.is_empty() and presenter._targets.is_empty()
				and not presenter.cancel_button.visible, "cancel clears all target state: " + card_id + "/" + mode)
			for hero in app.hero_panels:
				_check(hero.focus_mode == Control.FOCUS_NONE and hero.get_child_count() == 2
					and hero.gui_input.get_connections().is_empty(), "cancel restores inert hero panels: " + mode)
			await _return()
	# An invalid target position through a real captured callback is inert.
	if not await _start("warden_patch_guard"):
		await _return()
		return
	await _mouse(_panel("warden_patch_guard"))
	var hero: Control = app.hero_panels[1]
	var before := _state()
	var callback: Callable = presenter._targets[hero].callback
	hero.grab_focus()
	for position in [0, 1, 4]:
		presenter._on_target_input(_key(KEY_ENTER), hero, position, presenter._token)
	await _frames()
	_check(_state() == before, "invalid target positions never commit")
	# A disabled/hidden source control cannot resolve its queued target.
	hero.hide()
	callback.call(_press())
	await _frames()
	_check(_state() == before and presenter._pending.get("choosing", false),
		"hidden target control never commits")
	hero.show()
	await _return()


func _invalid_and_stale() -> void:
	var card_id := "warden_iron_hem"
	# Insufficient energy: otherwise current card, owner and battle.
	if not await _start(card_id):
		await _return()
		return
	app.deck.combat_state.energy = 1
	var before := _state()
	await _mouse(_panel(card_id))
	_check(_state() == before and presenter._pending.is_empty(), "insufficient energy rejects without spend")
	app.deck.combat_state.energy = 3
	# Inactive player turn.
	app.deck.combat_state.player_turn_active = false
	before = _state()
	await _mouse(_panel(card_id))
	_check(_state() == before and presenter._pending.is_empty(), "inactive turn rejects without spend")
	app.deck.combat_state.player_turn_active = true
	# Completed battle latch.
	app._battle_closed = true
	before = _state()
	await _mouse(_panel(card_id))
	_check(_state() == before and presenter._pending.is_empty(), "inactive battle rejects without spend")
	app._battle_closed = false
	# Hidden battle and hidden panel fail closed through the same bound callbacks.
	app.battle_view.hide()
	before = _state()
	presenter._on_card_input(_press(), _panel(card_id), card_id, app.deck, app.party, app.battle_view)
	await _frames()
	_check(_state() == before, "hidden battle rejects")
	app.battle_view.show()
	var panel := _panel(card_id)
	panel.hide()
	before = _state()
	presenter._on_card_input(_press(), panel, card_id, app.deck, app.party, app.battle_view)
	await _frames()
	_check(_state() == before, "hidden panel rejects")
	panel.show()
	# Wrong session objects fail closed.
	var foreign_party := CombatParty.new(app._load_party_definitions())
	before = _state()
	presenter._on_card_input(null, panel, card_id, app.deck, app.party, app.battle_view)
	presenter._on_card_input(_press(), panel, card_id, app.deck, foreign_party, app.battle_view)
	presenter._on_card_input(_press(), panel, "warden_quick_darn", app.deck, app.party, app.battle_view)
	await _frames()
	_check(_state() == before, "null/foreign/wrong-ID inputs preserve complete state")
	# Downed owner: payment and Block must never happen.
	_check(app.party.apply_damage(1, 10000) and app.party.is_downed(1), "Warden really downed")
	before = _state()
	await _mouse(panel)
	_check(_state() == before and presenter._pending.is_empty(), "downed owner rejects without spend")
	await _return()

	# Authored source position: Hold the Line requires Warden in the front or middle.
	if not await _start("warden_hold_the_line"):
		await _return()
		return
	for pair in [1, 2]:
		var proposal := CombatPositionSwaps.preview_adjacent_swap(app.party, pair, 1)
		_check(proposal.ok, "production preview moves Warden one slot back")
		app.party._heroes.assign(proposal.heroes)
	_check(app.party.get_hero(3).id == "warden", "Warden really moved to the back slot")
	app._refresh_party()
	presenter._sync_battle()
	await _frames()
	before = _state()
	await _mouse(_panel("warden_hold_the_line"))
	_check(_state() == before and presenter._pending.is_empty(),
		"authored source position rejects without spend")
	await _return()

	# Downed Patch Guard recipient is not offered and a stale receipt cannot commit.
	if not await _start("warden_patch_guard"):
		await _return()
		return
	_check(app.party.apply_damage(2, 10000) and app.party.is_downed(2), "recipient really downed")
	await _mouse(_panel("warden_patch_guard"))
	_check(not presenter._targets.has(app.hero_panels[1]) and app.hero_panels[1].focus_mode == Control.FOCUS_NONE,
		"downed ally is not a target")
	before = _state()
	presenter._on_target_input(_key(KEY_ENTER), app.hero_panels[1], 2, presenter._token)
	await _frames()
	_check(_state() == before, "downed ally receipt cannot commit")
	await _return()

	# Detached stale panel cannot act on the old session.
	if not await _start("warden_hold_the_line"):
		await _return()
		return
	panel = _panel("warden_hold_the_line")
	var callback: Callable = presenter._bindings[panel]
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_rng: RandomNumberGenerator = app.run_rng
	var old_state := _state()
	app.hand_view.remove_child(panel)
	presenter._sync_battle()
	_check(panel.gui_input.get_connections().is_empty(), "detached panel unbound")
	callback.call(_press())
	await _frames()
	_check(_state() == old_state, "detached stale callback cannot mutate old session")
	_check(panel.get_parent() == null, "detached panel really left the hand")
	panel.free()
	await _return()
	# The old session references stayed untouched through Return.
	_check(old_deck.hand.has("warden_hold_the_line"), "detached attempts left old deck hand intact")
	_check(old_party.is_valid() and old_rng.seed == 42, "old session objects unchanged")
	_check(app.deck == null, "Return released the mounted session")
	await _frames()


func _starter_handler_intact() -> void:
	if not await _start("warden_quick_darn"):
		await _return()
		return
	# Keep the still-supported starter card on exactly the same mounted controls.
	app.deck.draw_pile.append("warden_brace")
	_check(app.deck.draw_extra(1) == 1, "starter Brace enters the real hand")
	app._refresh_hand()
	await _frames()
	var panel := _panel("warden_brace")
	_check(is_instance_valid(panel) and panel.focus_mode == Control.FOCUS_ALL
		and panel.gui_input.get_connections().size() == 1, "starter support keeps its handler")
	if panel == null:
		await _return()
		return
	var before := _state()
	var old_block: int = app.party.get_hero(1).block
	await _mouse(panel)
	_check(app.deck.energy == int(before[3]) - 1 and app.party.get_hero(1).block == old_block + 7,
		"starter Brace still spends one and adds seven")
	_check(app.deck.discard_pile.back() == "warden_brace" and not app.deck.hand.has("warden_brace"),
		"starter Brace still discards exactly once")
	_check(app.run_rng.state == before[11], "starter play still leaves run RNG untouched")
	await _return()


## The seeded authored opening book that offers a Fight and then a connected
## onward Fight, found once (the seed search only reads generated maps).
func _opening_choice() -> bool:
	if opening_seed > 0:
		return true
	for number in range(1, 400):
		var rng := RandomNumberGenerator.new()
		rng.seed = number
		var generated := RunMap.new()
		generated.generate(rng)
		for node_id in generated.get_legal_choices():
			if generated.get_node(node_id).get("type", "") != "Fight":
				continue
			if not generated.choose_node(node_id):
				continue
			for next_id in generated.get_legal_choices():
				if generated.get_node(next_id).get("type", "") == "Fight":
					opening_seed = number
					opening_fight = node_id
					next_fight = next_id
					return true
	return false


## Press a real mounted route control, the same connected admission a click follows.
func _choose_route_node(node_id: String) -> bool:
	var action: Button = null
	for button in app.route_buttons:
		if button.get_meta("route_id") == node_id:
			action = button
			break
	_check(is_instance_valid(action) and action.is_visible_in_tree() and not action.disabled,
		"real route chooser mounts the connected node: " + node_id)
	if not is_instance_valid(action):
		return false
	action.pressed.emit()
	await _frames()
	return true


## Settle the genuine opening Fight through the run's real reward and route
## services, so a later Fight is admitted from a real between-fights route.
func _settle_opening_fight() -> bool:
	var defeated := true
	for enemy in app.enemies.get_enemies():
		defeated = app.enemies.apply_damage(int(enemy.position), 99999) and defeated
	_check(defeated, "opening Fight enemies are genuinely defeated")
	app._observe_battle_result()
	await _frames()
	_check(app._battle_closed and app.reward_buttons.size() >= 4,
		"real opening Fight victory mounts its reward claim")
	if app.reward_buttons.size() < 4:
		return false
	app.reward_buttons[3].pressed.emit()
	await _frames()
	_check(is_instance_valid(app.continue_button) and app.fight_reward_claimed,
		"actual routed reward service accepts the skip receipt")
	if not is_instance_valid(app.continue_button):
		return false
	app.continue_button.pressed.emit()
	await _frames()
	var ready: bool = is_instance_valid(app.route_view) \
		and app.run_map.get_legal_choices().has(next_fight)
	_check(ready, "first reward settles and the connected Fight is selectable")
	return ready


## Prior-earned M05 ownership plus the genuine sewn ARM ledger, built from the
## run's real inventory context and bound with the carryover's own API.
func _sew_run_cuff(wearer: String) -> bool:
	_check(not app.run_trinkets.has("hemguard_cuff"),
		"authentic run does not own the M05 cuff yet")
	app.run_trinkets.append("hemguard_cuff")
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		[{"id": "hemguard_cuff", "slot": "ARM"}], app.run_scraps,
		app.session_gold, app.run_deck, app.run_seed, true)
	var sewn: Dictionary = wardrobe.sew("hemguard_cuff", wearer, "ARM",
		"lane2-live-cuff-" + wearer, wardrobe.get_snapshot())
	_check(wardrobe.is_valid() and sewn.get("ok", false),
		"real prior-earned cuff is sewn to the %s ARM slot" % wearer)
	var carry := app.party_carryover as RunTornCarryover
	var bound: bool = carry != null \
		and carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()) \
		and carry._wardrobe == wardrobe
	_check(bound, "run carryover authentically owns this sewn ARM ledger")
	return wardrobe.is_valid() and sewn.get("ok", false) and bound


## AC1/AC2 live route: title -> seeded authored opening book -> real Fight(s)
## admitted with the run's genuine RunTornCarryover. `prior_earned` settles the
## opening Fight first, owns the cuff between fights and admits the connected
## Fight naturally, so the resolver binds at ordinary battle synchronization; a
## single-fight case sews at the mounted battle's documented rebind boundary.
## No detached fake effect is injected anywhere.
func _enter_routed(card_id: String, wearer: String, prior_earned: bool = false) -> bool:
	_check(app.deck == null and app.run_map == null, "routed case starts at a clean title")
	if not _opening_choice():
		_check(false, "seeded authored opening book offers two connected Fights")
		return false
	app.run_seed = opening_seed
	await _mouse(app.route_button)
	var carry := app.party_carryover as RunTornCarryover
	var ready: bool = app.deck == null and app.run_map != null and carry != null \
		and app.run_map.get_legal_choices().has(opening_fight)
	_check(ready, "real title opens the seeded route with a genuine torn carryover")
	if not ready:
		return false
	_check(app._can_choose_connected_route(), "opening Fight is choosable on the connected route")
	_check(app._unfought_run(), "opening Fight belongs to a genuine unfought run")
	_check(carry.create_next_fight_party() != null,
		"the untouched ledger projects the opening fight party")
	if not await _choose_route_node(opening_fight):
		return false
	var accepted: bool = app._current_carryover_fight() and app.deck is CombatDeck \
		and app.party_carryover == carry
	_check(accepted, "real opening Fight admits with the genuine carryover")
	if not accepted:
		return false
	var node_id := opening_fight
	if prior_earned:
		if not await _settle_opening_fight():
			return false
		if wearer != "" and not _sew_run_cuff(wearer):
			return false
		if not await _choose_route_node(next_fight):
			return false
		node_id = next_fight
	elif wearer != "":
		if not _sew_run_cuff(wearer):
			return false
		# The mounted battle's own synchronization boundary rebinds the resolvers,
		# so the live hand runs against the newly authenticated projection.
		presenter._clear()
		presenter._sync_battle()
		await _frames()
		_check(app.deck is CombatDeck and is_instance_valid(app.battle_view) \
			and app.party_carryover == carry,
			"rebind boundary keeps the same real mounted battle")
	accepted = app._current_carryover_fight() and app.deck is CombatDeck \
		and app.party_carryover == carry and app.run_map.get_current_node_id() == node_id
	_check(accepted, "live Warden battle is mounted on the expected route node: " + node_id)
	if not accepted:
		return false
	var resolver = presenter._block_cards
	var expected_bonus: int = 2 if catalog.get_definition(card_id).get("effects", {}).has("block") else 0
	if wearer == "warden":
		_check(resolver is CombatWardenPoolBlockCards and resolver.is_patch_binding_valid()
			and resolver.get_wardrobe() == carry._wardrobe and resolver.get_torn() == carry.torn
			and resolver.get_patches() != null and resolver.get_patches().is_valid()
			and resolver.get_patches().card_block_bonus("warden", card_id) == expected_bonus,
			"live Block resolver carries the authenticated sewn Warden cuff")
	elif wearer == "":
		_check(resolver is CombatWardenPoolBlockCards and resolver.is_patch_binding_valid()
			and resolver.get_wardrobe() == null and resolver.get_patches() == null,
			"no-carryover routed baseline leaves the Block resolver unbound")
	else:
		_check(resolver is CombatWardenPoolBlockCards and resolver.is_patch_binding_valid()
			and resolver.get_wardrobe() == carry._wardrobe
			and resolver.get_patches().card_block_bonus("warden", card_id) == 0,
			"live Block resolver holds the ledger but awards no Warden bonus")
	# The run deck owns reward cards in live play; put one authored copy through
	# the real deck draw so the mounted panel is exactly what a run would hold.
	app.deck.draw_pile.append(card_id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == card_id,
		"real combat deck draws the authored card: " + card_id)
	app._refresh_hand()
	await _frames()
	return _panel(card_id) != null


## One committed routed card play through the mounted real hand. `wearer` names the
## run's actual sewn ARM owner ("" for the unsewn baseline).
func _routed_play(card_id: String, wearer: String, keyboard: bool, target_position: int,
		expected_blocks: Array, stage: String, prior_earned: bool = false) -> void:
	if not await _enter_routed(card_id, wearer, prior_earned):
		await _return()
		return
	var definition: Dictionary = catalog.get_definition(card_id)
	var effects: Dictionary = definition.get("effects", {})
	var bonus: int = 2 if wearer == "warden" and effects.has("block") else 0
	var panel := _panel(card_id)
	_assert_display(card_id, stage)
	var before := _state()
	if target_position == 0:
		if keyboard:
			panel.grab_focus()
			_check(panel.has_focus(), "keyboard path focuses the routed pool panel: " + stage)
			await _keyboard(KEY_ENTER)
		else:
			await _mouse(panel)
	else:
		await _mouse(panel)
		_check(_state() == before, "arming never pre-spends: " + stage)
		_check(presenter._pending.get("choosing", false), "real living-ally target mode: " + stage)
		var hero: Control = app.hero_panels[target_position - 1]
		if keyboard:
			app.hero_panels[0].grab_focus()
			for step in range(target_position - 1):
				await _keyboard(KEY_TAB)
			_check(hero.has_focus(), "Tab reaches the chosen living ally: " + stage)
			root.push_input(_key(KEY_ENTER), true)
			root.push_input(_key(KEY_ENTER), true)
			root.push_input(_key(KEY_ENTER, false), true)
			await _frames()
		else:
			await _mouse(hero)
	_assert_success(card_id, before, target_position, stage, bonus, expected_blocks)
	await _return()


## AC1: the exact authored amounts on a genuinely sewn Warden, per target kind.
func _routed_cuff_cases() -> void:
	# The headline case runs the full natural route: a settled opening Fight, the
	# cuff sewn between fights, then a naturally admitted connected Fight.
	await _routed_play("warden_hold_the_line", "warden", false, 0, [7, 2, 2],
		"routed cuff Hold the Line", true)
	await _routed_play("warden_hold_the_line_plus", "warden", true, 0, [9, 3, 3],
		"routed cuff Hold the Line+")
	await _routed_play("warden_patch_guard", "warden", false, 2, [0, 10, 0],
		"routed cuff Patch Guard")
	await _routed_play("warden_patch_guard_plus", "warden", true, 3, [0, 0, 13],
		"routed cuff Patch Guard+")
	await _routed_play("warden_quick_darn", "warden", true, 0, [6, 0, 0],
		"routed cuff Quick Darn")
	await _routed_play("warden_iron_hem", "warden", false, 0, [16, 0, 0],
		"routed cuff Iron Hem")
	# Iron Hem+ costs one and still authors 14 Block, so the cuff makes it 16.
	await _routed_play("warden_iron_hem_plus", "warden", true, 0, [16, 0, 0],
		"routed cuff Iron Hem+")
	await _routed_play("warden_bastion_quilt", "warden", false, 0, [10, 10, 10],
		"routed cuff Bastion Quilt")


## AC2: unsewn and wrong-wearer run ledgers never award the Warden bonus.
func _routed_unsewn_cases() -> void:
	await _routed_play("warden_hold_the_line", "", false, 0, [5, 2, 2],
		"routed unsewn Hold the Line")
	await _routed_play("warden_patch_guard", "", false, 2, [0, 8, 0],
		"routed unsewn Patch Guard")
	await _routed_play("warden_iron_hem", "seamstress", false, 0, [14, 0, 0],
		"routed seamstress cuff Iron Hem")


## AC2 fail-closed: a refused/stale live binding never spends, discards or awards
## Block, and the real battle synchronization fail-closes a torn projection.
func _routed_fail_closed() -> void:
	if not await _enter_routed("warden_iron_hem", "warden"):
		await _return()
		return
	var carry := app.party_carryover as RunTornCarryover
	var panel := _panel("warden_iron_hem")
	# A mismatched expected snapshot is refused, and the live resolver fails closed.
	var before := _state()
	_check(not presenter._block_cards.bind_patch_wardrobe(carry._wardrobe, carry.torn, {}),
		"a mismatched expected wardrobe snapshot is refused")
	_check(not presenter._block_cards.is_patch_binding_valid(),
		"the refused binding explicitly fail-closes the live Block resolver")
	await _mouse(panel)
	_check(_state() == before and presenter._pending.is_empty(),
		"fail-closed live resolver never spends, discards or awards Block")
	_check(app.deck.hand.has("warden_iron_hem"),
		"fail-closed live play leaves the held copy in hand")
	# The same live resolver recovers with the real authenticated ledger.
	_check(presenter._block_cards.bind_patch_wardrobe(carry._wardrobe, carry.torn),
		"the same live resolver accepts the authenticated binding again")
	var rebound := _state()
	await _mouse(panel)
	_assert_success("warden_iron_hem", rebound, 0, "recovered cuff Iron Hem", 2, [16, 0, 0])
	# A genuine torn ledger tears the authenticated projection: the real battle
	# synchronization must fail-close the resolver instead of playing unbonused.
	# A real zero-cost copy is drawn so a refusal cannot be blamed on energy.
	app.deck.draw_pile.append("warden_quick_darn")
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == "warden_quick_darn",
		"authored zero-cost card enters the real hand for the torn check")
	app._refresh_hand()
	await _frames()
	var torn_state := carry.torn.read_state()
	var start: Array = torn_state.get("heroes", []).duplicate(true)
	var warden_index := -1
	for index in range(start.size()):
		if start[index].get("id") == "warden":
			warden_index = index
	_check(warden_index >= 0, "routed torn ledger really holds the Warden")
	if warden_index < 0:
		await _return()
		return
	var ending: Array = start.duplicate(true)
	ending[warden_index]["hp"] = 0
	var observed: Dictionary = carry.torn.observe_battle_end("lane2-live-torn", start, ending)
	_check(observed.get("ok", false),
		"genuine torn ledger marks the Warden torn: %s" % str(observed))
	presenter._clear()
	presenter._sync_battle()
	await _frames()
	_check(app.deck is CombatDeck and is_instance_valid(app.battle_view) \
		and presenter._block_cards != null,
		"torn check keeps the real mounted battle after resynchronization")
	_check(not presenter._block_cards.is_patch_binding_valid()
		and presenter._block_cards.get_wardrobe() == null,
		"stale torn carryover synchronization fail-closes the live Block resolver")
	var stale := _state()
	await _mouse(_panel("warden_quick_darn"))
	_check(_state() == stale and presenter._pending.is_empty()
		and app.deck.hand.has("warden_quick_darn"),
		"stale torn carryover never awards a cuff bonus through live play")
	await _return()


func _routed_cases() -> void:
	await _routed_cuff_cases()
	await _routed_unsewn_cases()
	await _routed_fail_closed()


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
	presenter = app.get_node_or_null("LiveSupportHand")
	_check(presenter != null and app.deck == null, "title starts without a mounted battle")
	if presenter == null:
		app.free()
		_finish()
		return
	# Required authored IDs are present independently of any catalog total.
	for card_id in _forms():
		_check(catalog.has_card(card_id) and not catalog.get_definition(card_id).is_empty(),
			"required authored pool record present: " + card_id)
	var index := 0
	for card_id in _forms():
		if card_id.begins_with("warden_patch_guard"):
			continue
		# Alternate real mouse and keyboard input across base and '+' forms.
		await _play_target_free(card_id, index % 2 == 1)
		index += 1
	await _play_patch_guard("warden_patch_guard", false)
	await _play_patch_guard("warden_patch_guard_plus", true)
	await _cancellation_cases()
	await _invalid_and_stale()
	await _starter_handler_intact()
	await _routed_cases()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_warden_pool_block_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
