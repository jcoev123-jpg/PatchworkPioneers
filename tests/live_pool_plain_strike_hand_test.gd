extends SceneTree
## Mounted shared-hand coverage for the four plain reward-pool strikes:
## Brass Buckle / Brass Buckle+ and Thread Whip / Thread Whip+.
## Real scene, real seeded CombatDeck draw, real hand panels, real enemy
## selector, physical mouse and keyboard input. Expected HP, Block, energy,
## piles and RNG come from the authored catalog plus an independent pure
## CombatPoolPlainStrikes oracle; never from the presenter's own return value.

const IDS := [
	"warden_brass_buckle", "warden_brass_buckle_plus",
	"seamstress_thread_whip", "seamstress_thread_whip_plus",
]
const SEED := 42

var failures: Array[String] = []
var checks := 0
var app
var presenter
var _statuses := CombatStatuses.new()


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	await process_frame
	await process_frame


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	return event


func _keyboard(code: Key) -> void:
	root.push_input(_key(code), true)
	root.push_input(_key(code, false), true)
	await _frames()


func _click_point(point: Vector2) -> void:
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
			# A duplicate press in one dispatch must still resolve only once.
			root.push_input(event, true)
	await _frames()


func _mouse(control: Control) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), "physical target is really on screen")
	if not is_instance_valid(control):
		return
	await _click_point(control.get_global_rect().get_center())


func _panel(card_id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and panel.get_child(0).text == card_id:
			return panel
	return null


func _owner(card_id: String) -> String:
	return "warden" if card_id.begins_with("warden_") else "seamstress"


func _definition(card_id: String) -> Dictionary:
	return (WardenPoolCards.new().get_definition(card_id) if card_id.begins_with("warden_")
		else SeamstressPoolCards.new().get_definition(card_id))


func _owner_position(owner: String) -> int:
	for hero in app.party.get_heroes():
		if hero.id == owner:
			return int(hero.position)
	return 0


func _state() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.deck.combat_state.energy, app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(),
		app.battle_result.get_outcome(), app.run_rng.seed, app.run_rng.state,
		app.session_gold, app._battle_closed]


## Keyboard hint mirrors the presenter's own readable contract, derived here
## from the catalog's authored TO slots and the currently living enemies.
func _key_hint(positions: Array) -> String:
	var keys: PackedStringArray = []
	for position in positions:
		keys.append(str(position))
	if keys.is_empty():
		return "1-%d" % CombatEnemies.MAX_ENEMIES
	if keys.size() > 1 and int(positions[positions.size() - 1]) - int(positions[0]) == keys.size() - 1:
		return "%s-%s" % [keys[0], keys[keys.size() - 1]]
	return ", ".join(keys)


func _expected_cue(card_id: String) -> String:
	var definition := _definition(card_id)
	var owner_position := _owner_position(_owner(card_id))
	_check(owner_position > 0, "authored owner really occupies a slot: " + card_id)
	var owner_statuses: Dictionary = app.party.get_hero(owner_position).get("statuses", {})
	var base_damage: int = int(definition.effects.damage)
	var positions: Array = []
	var parts: PackedStringArray = []
	for enemy in app.enemies.get_enemies():
		if int(enemy.hp) > 0 and definition.to_positions.has(enemy.position):
			positions.append(enemy.position)
			parts.append("%d: %d damage" % [enemy.position,
				_statuses.adjusted_attack_damage(base_damage, owner_statuses, enemy.get("statuses", {}))])
	var description := "Choose one enemy slot: " + "; ".join(parts)
	var block: int = int(definition.effects.get("block", 0))
	if block > 0:
		description += " | %s gains %d Block" % [String(definition.owner).capitalize(), block]
	return "%s | %d energy | P / click card; %s / click enemy\n%s" % [
		definition.display_name, int(definition.cost), _key_hint(positions), description]


## Independent pure-resolver oracle built from the same seeded snapshot on
## detached real models. It never touches the mounted app or its presenter.
func _oracle(card_id: String, target: int, before: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(before[11])
	rng.state = int(before[12])
	var deck := CombatDeck.new([], rng)
	deck.draw_pile.assign(before[0])
	deck.hand.assign(before[1])
	deck.discard_pile.assign(before[2])
	deck.combat_state.player_turn_active = bool(before[4])
	deck.combat_state.energy = int(before[5])
	var party := CombatParty.new(app._load_party_definitions())
	party._heroes.assign((before[6] as Array).duplicate(true))
	var enemies := CombatEnemies.new(app._load_enemy_definitions())
	enemies._enemies.assign((before[7] as Array).duplicate(true))
	var event: Dictionary = CombatPoolPlainStrikes.new().play_card(deck, party, enemies, card_id, target)
	return {
		"event": event,
		"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"rng_seed": deck._rng.seed, "rng_state": deck._rng.state,
	}


func _assert_display(card_id: String) -> void:
	var panel := _panel(card_id)
	_check(is_instance_valid(panel), "real held pool panel mounted: " + card_id)
	if panel == null:
		return
	var definition := _definition(card_id)
	_check(definition.get("id") == card_id and definition.get("owner") == _owner(card_id),
		"authored catalog record backs the mounted card: " + card_id)
	_check(presenter._bindings.has(panel) and panel.gui_input.get_connections().size() == 1,
		"exactly one attack input binding per held instance: " + card_id)
	_check(panel.mouse_entered.get_connections().size() == 1
		and panel.mouse_exited.get_connections().size() == 1,
		"one hover binding per held instance: " + card_id)
	_check(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "pool strike is pointer reachable: " + card_id)
	_check(not app.get_node("LiveSupportHand")._bindings.has(panel),
		"the attack hand is the only live caller for a pool strike: " + card_id)
	_check(presenter._eligible(panel), "pool strike is live keyboard-reachable through P cycling: " + card_id)
	_check(panel.get_child(0).text == card_id, "original identity label retained: " + card_id)


func _assert_cue(card_id: String) -> void:
	_check(presenter._card_id(presenter._selected) == card_id,
		"physical selection selected the actual held instance: " + card_id)
	_check(presenter.cue.text == _expected_cue(card_id),
		"exact catalog name/cost, authored slots and non-mutating forecast: " + card_id)
	_check(presenter.cue.is_visible_in_tree()
		and root.get_visible_rect().encloses(presenter.cue.get_global_rect()),
		"attack cue readable at 1280x720: " + card_id)
	_check(presenter.cue.get_line_count() <= 2, "attack cue fits two readable lines: " + card_id)


func _assert_success(card_id: String, before: Array, target: int, stage: String,
		oracle: Dictionary) -> void:
	var definition := _definition(card_id)
	var owner_position := _owner_position(_owner(card_id))
	_check(app.deck.energy == int(before[3]) - 1
		and app.deck.combat_state.energy == int(before[5]) - 1,
		"exactly one energy paid: " + stage)
	var expected_hand: Array = before[1].duplicate()
	expected_hand.erase(card_id)
	_check(app.deck.hand == expected_hand, "exactly one held copy discarded: " + stage)
	var expected_discard: Array = before[2].duplicate()
	expected_discard.append(card_id)
	_check(app.deck.discard_pile == expected_discard and app.deck.discard_pile.back() == card_id,
		"played copy lands in discard once: " + stage)
	_check(app.deck.draw_pile == before[0], "draw pile untouched: " + stage)
	_check(app.deck.turn_active == before[4] and bool(before[14]) == false,
		"player turn stays active in a live battle: " + stage)

	# Only the actual Warden gains the authored self Block.
	var hero_before: Dictionary = before[6][owner_position - 1]
	var hero_after: Dictionary = app.party.get_hero(owner_position)
	var expected_hero: Dictionary = hero_before.duplicate(true)
	if definition.effects.has("block"):
		expected_hero.block = int(hero_before.block) + int(definition.effects.block)
	_check(hero_after == expected_hero, "owner receives exactly the authored Block: " + stage)
	for index in range(before[6].size()):
		if index != owner_position - 1:
			_check(app.party.get_hero(index + 1) == before[6][index],
				"unrelated hero unchanged: %s slot %d" % [stage, index + 1])

	# Target damage is the catalog damage after real Weak/Exposed, then Block.
	var enemy_before: Dictionary = before[7][target - 1]
	var damage: int = _statuses.adjusted_attack_damage(int(definition.effects.damage),
		hero_before.get("statuses", {}), enemy_before.get("statuses", {}))
	var absorbed: int = mini(int(enemy_before.block), damage)
	var loss: int = mini(int(enemy_before.hp), damage - absorbed)
	var expected_enemy: Dictionary = enemy_before.duplicate(true)
	expected_enemy.block = int(enemy_before.block) - absorbed
	expected_enemy.hp = int(enemy_before.hp) - loss
	_check(app.enemies.get_enemy(target) == expected_enemy,
		"target loses exactly %d damage through %d Block: %s" % [damage, absorbed, stage])
	for index in range(before[7].size()):
		if index != target - 1:
			_check(app.enemies.get_enemy(index + 1) == before[7][index],
				"unrelated enemy unchanged: %s slot %d" % [stage, index + 1])
	_check(hero_after.get("statuses", {}) == hero_before.get("statuses", {})
		and app.enemies.get_enemy(target).get("statuses", {}) == enemy_before.get("statuses", {}),
		"no starter status hook or passive rides a pool strike: " + stage)

	# Shared systems and the seeded generator stay untouched.
	_check(app.enemy_attacks == before[8] and app.enemy_intents.get_intents() == before[9],
		"enemy announcements and intents untouched: " + stage)
	_check(app.battle_result.get_outcome() == before[10], "battle outcome unchanged: " + stage)
	_check(app.deck._rng.seed == int(before[11]) and app.deck._rng.state == int(before[12]),
		"seeded RNG untouched by forecast and play: " + stage)
	_check(app.session_gold == int(before[13]), "session gold unchanged: " + stage)
	_check(app.deck._rng == app.run_rng, "shared seeded generator is still the run's own")

	# One confirmed play exactly matches the detached resolver oracle.
	_check(presenter.last_event == oracle["event"],
		"one confirmed play matches the pure pool resolver event: " + stage)
	_check(app.deck.hand == oracle["hand"] and app.deck.draw_pile == oracle["draw"]
		and app.deck.discard_pile == oracle["discard"] and app.deck.energy == oracle["energy"],
		"piles and energy match the oracle: " + stage)
	_check(app.party.get_heroes() == oracle["heroes"],
		"HP, Block and statuses match the oracle: " + stage)
	_check(app.enemies.get_enemies() == oracle["enemies"],
		"complete enemy roster matches the oracle: " + stage)
	_check(app.deck._rng.seed == oracle["rng_seed"] and app.deck._rng.state == oracle["rng_state"],
		"oracle RNG ends exactly where the live deck is: " + stage)


func _assert_inert(before: Array, stage: String) -> void:
	_check(_state() == before, "complete battle state unchanged (no spend, no mutation): " + stage)


func _start(card_id: String = "") -> bool:
	_check(app.deck == null, "title precedes a fresh mounted battle")
	app.run_seed = SEED
	_fixture_start(app)
	await _frames()
	var ready: bool = app.deck is CombatDeck and app.party is CombatParty and app.enemies != null \
		and app.battle_result != null and app.run_rng != null and app.enemy_intents != null \
		and is_instance_valid(app.battle_view) and is_instance_valid(app.hand_view)
	_check(ready, "real standalone battle starts complete")
	if not ready:
		return false
	if card_id.is_empty():
		return true
	# Reward cards reach a live run deck through the real draw path, never a
	# synthetic hand: append one authored copy and draw it with the real deck.
	app.deck.draw_pile.append(card_id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == card_id,
		"real deck draws the authored pool strike: " + card_id)
	app._refresh_hand()
	await _frames()
	return _panel(card_id) != null


func _return() -> void:
	await _mouse(app.return_button)
	_check(app.deck == null and presenter.cue == null and presenter._bindings.is_empty(),
		"Return clears the attack cue and every binding")


func _key_select(card_id: String) -> bool:
	for attempt in range(app.deck.hand.size() + 1):
		await _keyboard(KEY_P)
		if presenter._armed != null and presenter._armed == _panel(card_id) \
				and presenter._bindings.has(presenter._armed):
			return true
	return false


func _play(card_id: String, keyboard: bool) -> void:
	if not await _start(card_id):
		await _return()
		return
	_assert_display(card_id)
	var panel := _panel(card_id)
	var target := 2
	if keyboard:
		_check(await _key_select(card_id), "P cycles to the real held pool panel: " + card_id)
	else:
		await _mouse(panel)
	_check(presenter._armed == panel, "physical selection armed the held pool strike: " + card_id)
	var before := _state()
	_assert_cue(card_id)
	_check(_state() == before, "selecting a pool strike never pre-spends: " + card_id)
	var oracle := _oracle(card_id, target, before)
	if keyboard:
		await _keyboard(KEY_2)
	else:
		await _mouse(app.get_node("LiveEnemyRoster")._labels[target - 1])
	_assert_success(card_id, before, target, card_id, oracle)
	var after := _state()
	# A consumed selection stays inert for both duplicate physical inputs.
	await _keyboard(KEY_2)
	await _mouse(app.get_node("LiveEnemyRoster")._labels[target - 1])
	_check(_state() == after, "consumed selection cannot double-cast: " + card_id)
	_check(app.deck.hand.count(card_id) == int(before[1].count(card_id)) - 1
		and app.deck.discard_pile.count(card_id) == int(before[2].count(card_id)) + 1,
		"one physical activation spends exactly one held copy: " + card_id)
	await _return()


## Two held copies stay independent: one binding each, P cycles real instances,
## and a confirmed play spends exactly one of them.
func _duplicate_instances() -> void:
	var card_id := "warden_brass_buckle"
	if not await _start():
		await _return()
		return
	app.deck.draw_pile.append(card_id)
	app.deck.draw_pile.append(card_id)
	_check(app.deck.draw_extra(2) == 2, "two real pool copies drawn through the deck")
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	var copies: Array[Control] = []
	for panel in app.hand_view.get_children():
		if panel.get_child(0).text == card_id:
			copies.append(panel)
	_check(copies.size() == 2 and copies[0] != copies[1],
		"two distinct live pool instances occupy two panels")
	for panel in copies:
		_check(presenter._bindings.has(panel) and panel.gui_input.get_connections().size() == 1,
			"each held pool copy owns exactly one input binding")
	if copies.size() != 2:
		await _return()
		return
	var before := _state()
	await _mouse(copies[0])
	_check(presenter._armed == copies[0], "the first copy arms independently")
	await _keyboard(KEY_P)
	_check(presenter._armed == copies[1], "P cycles to the second real copy, not a deduplicated ID")
	_check(_state() == before, "cycling duplicate copies never pre-spends")
	await _keyboard(KEY_1)
	_check(app.deck.hand.count(card_id) == 1
		and app.deck.discard_pile.count(card_id) == int(before[2].count(card_id)) + 1
		and app.deck.energy == int(before[3]) - 1,
		"one confirmed play spends exactly one of two held copies")
	await _return()


## Real Weak on the owner and real Exposed on the targets must shape the cue and
## the committed damage. Brass Buckle's own Block remains a separate self effect.
func _status_forecast() -> void:
	for card_id in ["warden_brass_buckle_plus", "seamstress_thread_whip_plus"]:
		if not await _start(card_id):
			await _return()
			return
		var owner_position := _owner_position(_owner(card_id))
		app.party._heroes[owner_position - 1]["statuses"] = {"weak": 1}
		_check(app.enemies.apply_statuses({1: {"exposed": 1}, 2: {"exposed": 1}}),
			"real Exposed applied to both authored target slots")
		await _frames()
		await _mouse(_panel(card_id))
		var before := _state()
		_assert_cue(card_id)
		var definition := _definition(card_id)
		var expected_damage: int = _statuses.adjusted_attack_damage(
			int(definition.effects.damage), {"weak": 1}, {"exposed": 1})
		var block: int = int(definition.effects.get("block", 0))
		_check(presenter.cue.text.contains("1: %d damage" % expected_damage),
			"cue shows the real Weak/Exposed damage: " + card_id)
		if block > 0:
			_check(presenter.cue.text.contains("%s gains %d Block"
				% [String(definition.owner).capitalize(), block]),
				"Brass Buckle shows its own Block separately: " + card_id)
			_check(not presenter.cue.text.contains("1: %d damage" % (expected_damage + block)),
				"own Block gain is never mistaken for target damage: " + card_id)
		else:
			_check(not presenter.cue.text.contains("Block"),
				"Thread Whip promises no Block: " + card_id)
		var oracle := _oracle(card_id, 1, before)
		await _keyboard(KEY_1)
		_assert_success(card_id, before, 1, card_id + " weak/exposed", oracle)
		_check(presenter.last_event.get("hits", [{}])[0].get("damage") == expected_damage,
			"committed hit equals the adjusted forecast: " + card_id)
		await _return()
	# Forecast refresh follows the live statuses without another selection.
	if not await _start("warden_brass_buckle"):
		await _return()
		return
	await _mouse(_panel("warden_brass_buckle"))
	var healthy = presenter.cue.text
	app.party._heroes[0]["statuses"] = {"weak": 1}
	await _frames()
	var weakened = presenter.cue.text
	_check(weakened != healthy and weakened.contains("1: 3 damage"),
		"same selected cue observes the real Weak stack")
	app.party._heroes[0]["statuses"] = {}
	await _frames()
	_check(presenter.cue.text == healthy, "cue refresh returns to the unmodified damage")
	await _return()


func _rejection(card_id: String, scenario: String, keyboard: bool) -> void:
	if not await _start(card_id):
		await _return()
		return
	var panel := _panel(card_id)
	var owner_position := _owner_position(_owner(card_id))
	match scenario:
		"energy":
			app.deck.combat_state.energy = 0
		"inactive":
			app.deck.combat_state.player_turn_active = false
		"downed":
			_check(app.party.apply_damage(owner_position, 10000)
				and app.party.is_downed(owner_position), "authored owner really downed")
		"wrong_position":
			for pair in [1, 2]:
				var proposal := CombatPositionSwaps.preview_adjacent_swap(app.party, pair, 1)
				_check(proposal.ok, "production preview moves the owner back one slot")
				app.party._heroes.assign(proposal.heroes)
			app._refresh_party()
			_check(_owner_position(_owner(card_id)) == 3, "owner really moved to the back slot")
		"slain":
			_check(app.enemies.apply_damage(2, 10000) and app.enemies.is_slain(2),
				"second authored target slot really slain")
		"absent":
			_check(app.deck.discard_played(card_id), "remove the actual held pool copy")
		"finished":
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.apply_damage(enemy.position, 10000), "defeat mounted enemy")
	await _frames()
	if scenario in ["energy", "downed", "wrong_position", "slain"]:
		# Presentation stays honest: no illegal slot or damage forecast survives.
		if keyboard:
			_check(await _key_select(card_id), "keyboard still reaches the held panel: " + scenario)
		else:
			await _mouse(panel)
		var cue: String = presenter.cue.text
		if scenario == "slain":
			_check(not cue.contains("2: "), "slain authored target is not offered: " + scenario)
			_check(cue.contains("1: 5 damage"), "the surviving authored slot stays offered: " + scenario)
			_check(cue.contains("P / click card; 1 / click enemy"),
				"keyboard hint narrows to the surviving legal slot: " + scenario)
		else:
			_check(cue.contains("Unavailable") and not cue.contains(" damage"),
				"no stale legal target or damage cue: " + scenario)
	# The illegal input is the real thing: slain slot two, otherwise slot one.
	var position := 2 if scenario == "slain" else 1
	var before := _state()
	if keyboard:
		await _keyboard(KEY_1 + position - 1)
	else:
		var roster = app.get_node("LiveEnemyRoster")
		if position - 1 < roster._labels.size():
			await _mouse(roster._labels[position - 1])
		else:
			await _frames()
	await _keyboard(KEY_1 + position - 1)
	_assert_inert(before, scenario + " / " + card_id)
	_check(presenter.last_event.get("ok", false) != true or _state() == before,
		"rejected input never reports a committed play: " + scenario)
	await _return()
	_check(app.deck == null, "rejection return leaves the title clean: " + scenario)


## Brass Buckle cannot reach a living slot three; only its authored TO slots are legal.
func _illegal_slot() -> void:
	if not await _start("warden_brass_buckle"):
		await _return()
		return
	# The starter roster has two enemies, so mount a genuinely living third slot
	# from authored enemy shape data; Brass Buckle's authored TO slots still stop
	# at two and must reject it for both input devices.
	var definitions: Array = app._load_enemy_definitions()
	definitions.append({"id": "fixture_third", "name": "Third Ragling", "max_hp": 12,
		"art_path": String(definitions[0]["art_path"])})
	var three := CombatEnemies.new(definitions)
	_check(three.is_valid() and three.get_enemies().size() == 3
		and not three.is_slain(3), "mounted fixture really has a living third slot")
	app.enemies = three
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	presenter._sync_battle()
	await _frames()
	await _mouse(_panel("warden_brass_buckle"))
	_check(presenter.cue.text.contains("1: 5 damage") and presenter.cue.text.contains("2: 5 damage")
		and not presenter.cue.text.contains("3: "),
		"only the authored TO slots are offered while slot three lives")
	var before := _state()
	await _keyboard(KEY_3)
	_assert_inert(before, "Brass Buckle cannot select living enemy slot three")
	await _mouse(app.get_node("LiveEnemyRoster")._labels[2])
	_assert_inert(before, "Brass Buckle click on living enemy slot three is inert")
	_check(presenter._armed != null and presenter._card_id(presenter._armed) == "warden_brass_buckle",
		"the illegal selection never disarms the real card")
	await _keyboard(KEY_ESCAPE)
	var cancelled := _state()
	_check(presenter._armed == null and presenter._selected == null,
		"Esc cancels the armed pool selection")
	await _keyboard(KEY_1)
	_assert_inert(cancelled, "cancelled selection cannot commit later")
	await _return()


func _stale_cases() -> void:
	# A rebuilt hand drops the old panel and its captured callback.
	if not await _start("warden_brass_buckle"):
		await _return()
		return
	await _mouse(_panel("warden_brass_buckle"))
	var stale_panel := _panel("warden_brass_buckle")
	var stale_callback: Callable = presenter._bindings[stale_panel].input
	app.hand_view.remove_child(stale_panel)
	app._refresh_hand()
	await _frames()
	_check(stale_panel.gui_input.get_connections().is_empty(),
		"rebuilt hand disconnects the obsolete pool panel")
	var rebuilt := _state()
	stale_callback.call(_key(KEY_ENTER))
	await _frames()
	_assert_inert(rebuilt, "captured callback from a rebuilt hand is inert")
	stale_panel.free()
	await _return()

	# A hidden panel cannot arm or commit.
	if not await _start("seamstress_thread_whip"):
		await _return()
		return
	var hidden := _panel("seamstress_thread_whip")
	var hidden_callback: Callable = presenter._bindings[hidden].input
	hidden.hide()
	await _frames()
	var hidden_before := _state()
	hidden_callback.call(_key(KEY_ENTER))
	await _keyboard(KEY_1)
	await _frames()
	_assert_inert(hidden_before, "hidden pool panel cannot commit")
	hidden.show()
	await _frames()

	# A stale battle (new party/battle session) cannot be charged by the old panel.
	var stale_battle_panel := _panel("seamstress_thread_whip")
	var stale_battle_callback: Callable = presenter._bindings[stale_battle_panel].input
	app.party = CombatParty.new(app._load_party_definitions())
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	presenter._sync_battle()
	await _frames()
	var stale_battle := _state()
	stale_battle_callback.call(_key(KEY_ENTER))
	await _keyboard(KEY_1)
	await _frames()
	_assert_inert(stale_battle, "stale battle callback cannot spend or mutate")
	await _return()

	# Commit-time guards: stale session, wrong turn, empty energy, hidden hand.
	if not await _start("warden_brass_buckle"):
		await _return()
		return
	var panel := _panel("warden_brass_buckle")
	await _mouse(panel)
	for mode in ["stale_session", "wrong_turn", "no_energy", "hidden_hand"]:
		var original_session: Array = presenter._session.duplicate()
		if mode == "stale_session":
			presenter._session = []
		elif mode == "hidden_hand":
			app.hand_view.hide()
		elif mode == "no_energy":
			app.deck.combat_state.energy = 0
		var before := _state()
		var event: Dictionary = presenter.last_event.duplicate(true)
		presenter._armed = panel
		presenter._queued = true
		presenter._commit(panel, "warden_brass_buckle", 1, presenter._token,
			app.party, app.enemies, app.battle_result, app.run_rng,
			presenter._turn + (1 if mode == "wrong_turn" else 0))
		_assert_inert(before, "commit entry guard " + mode)
		_check(presenter.last_event == event, "rejected commit publishes no event: " + mode)
		presenter._session = original_session
		app.hand_view.show()
		if mode == "no_energy":
			app.deck.combat_state.energy = 3
	await _keyboard(KEY_ESCAPE)
	await _return()


func _preserved_routes() -> void:
	# Starter attacks still bind and charge through the same presenter.
	if not await _start():
		await _return()
		return
	app.deck.hand.assign(["warden_strike"])
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	var strike := _panel("warden_strike")
	_check(strike != null and presenter._bindings.has(strike)
		and strike.gui_input.get_connections().size() == 1,
		"starter attack still binds the attack hand")
	if strike != null:
		var strike_damage: int = int(StarterCards.new().get_definition("warden_strike").effects.damage)
		var before := _state()
		await _mouse(strike)
		await _keyboard(KEY_1)
		_check(app.enemies.get_enemy(1).hp == int(before[7][0].hp) - strike_damage,
			"starter Strike still deals its authored damage")
		_check(app.deck.energy == 2 and not app.deck.hand.has("warden_strike"),
			"starter Strike still spends one energy and one copy")
		_check(presenter.last_event.get("ok", false)
			and presenter.last_event.hits[0].damage == strike_damage,
			"starter hit event still reaches the presenter")
	await _return()

	# Support cards still own their felt-table route.
	if not await _start():
		await _return()
		return
	app.deck.hand.assign(["warden_brace"])
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	var brace := _panel("warden_brace")
	_check(brace != null and app.get_node("LiveSupportHand")._bindings.has(brace),
		"starter support keeps its own handler")
	if brace != null:
		var block: int = app.party.get_hero(1).block
		var before := _state()
		await _mouse(brace)
		_check(app.party.get_hero(1).block == block + 7 and app.deck.energy == int(before[3]) - 1,
			"starter support still spends one and adds seven Block")
	await _return()

	# A genuine cross-owner Rest stitch still binds through the stitched branch.
	if not await _start():
		await _return()
		return
	var ledger := RunRestStitchCards.new(app.run_deck.duplicate(), {}, 3, 1)
	_check(ledger.is_valid(), "real Rest stitch ledger is valid")
	var first_index: int = app.run_deck.find("warden_strike")
	var second_index: int = app.run_deck.find("seamstress_prick")
	var choice: Dictionary = ledger.choose_stitch(first_index, second_index, ledger.get_snapshot())
	_check(choice.get("ok", false) and not str(choice.get("stitched_id", "")).is_empty(),
		"real cross-owner stitch allocated by the production ledger")
	if choice.get("ok", false):
		app.run_deck.assign(choice["deck"])
		app.run_stitch_descriptors = choice["descriptors"].duplicate(true)
		app.run_scraps = int(choice["remaining_scraps"])
		app.run_next_stitch_id = int(choice["next_stitch_id"])
		var stitched_id: String = choice["stitched_id"]
		app.deck.hand.assign([stitched_id])
		app.deck.combat_state.energy = 3
		app._refresh_hand()
		await _frames()
		var stitched := _panel(stitched_id)
		_check(stitched != null and presenter._bindings.has(stitched) and presenter._eligible(stitched),
			"owned stitched composite still binds the attack hand")
		if stitched != null:
			var stitched_before := _state()
			await _mouse(stitched)
			_check(presenter._is_stitched(presenter._armed),
				"stitched card still enters its ordered two-half selection")
			await _keyboard(KEY_ESCAPE)
			_check(presenter._armed == null and presenter._selected == null,
				"stitch cancel clears the selection")
			_assert_inert(stitched_before, "stitch arming and cancel spend nothing")
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
	presenter = app.get_node_or_null("LiveAttackPreview")
	_check(presenter != null and app.deck == null, "title mounts the attack presenter without a battle")
	if presenter == null:
		app.free()
		_finish()
		return
	# Required authored IDs are present independently of any catalog total.
	for card_id in IDS:
		var definition := _definition(card_id)
		_check(definition.get("id") == card_id and definition.get("owner") == _owner(card_id),
			"required authored pool strike present: " + card_id)
		_check(not CombatAttackTargeting.ATTACK_IDS.has(card_id),
			"pool strike never enters the starter ATTACK_IDS list: " + card_id)
	var index := 0
	for card_id in IDS:
		# Alternate real mouse and keyboard input across base and '+' forms.
		await _play(card_id, index % 2 == 1)
		index += 1
	await _duplicate_instances()
	await _status_forecast()
	await _illegal_slot()
	for card_id in ["warden_brass_buckle", "seamstress_thread_whip_plus"]:
		for scenario in ["energy", "inactive", "downed", "wrong_position", "absent", "finished"]:
			var applicable: bool = scenario != "wrong_position" or card_id.begins_with("warden_")
			if applicable:
				await _rejection(card_id, scenario, scenario.length() % 2 == 1)
	await _rejection("warden_brass_buckle", "slain", true)
	await _stale_cases()
	await _preserved_routes()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_pool_plain_strike_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
