extends "res://tests/live_support_hand_test.gd"
## Cycle 333: Button Golem's Knuckle and Snag (base and +) play from the real mounted hand
## through LiveAttackPreview against the battle's one shared Pinned set.

const IDS := ["button_golem_button_knuckle", "button_golem_button_knuckle_plus",
	"button_golem_buttonhole_snag", "button_golem_buttonhole_snag_plus"]
## Printed damage and Tangled per printing, written out here rather than read from the resolver.
const DAMAGE := [5, 7, 3, 4]
const TANGLED := [0, 0, 2, 3]

func _begin(id: String, seat: int = 2) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 290
	_check(app._start_battle(), "mounted battle starts")
	presenter = app.get_node("LiveAttackPreview")
	var rng := RandomNumberGenerator.new()
	rng.seed = 290
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "two genuine drawn copies")
	app.deck.combat_state.energy = 1
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "button_golem", "name": "Button Golem", "max_hp": 30, "statuses": {"weak": 1}})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "tangled", "max_hp": 50, "statuses": {"tangled": 2, "exposed": 1}},
		{"id": "untangled", "max_hp": 50, "statuses": {"bleed": 2}},
		{"id": "back", "max_hp": 50, "statuses": {"tangled": 3}}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "real valid rosters")
	_check(app.enemies.gain_block(2, 3), "middle enemy has Block")
	_check(app.party.get_hero(seat).id == "button_golem" and app.enemies.get_enemy(2).block == 3,
		"non-vacuous owner seat and real Block preconditions")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel), "authentic panel bound by mounted adapter")
	return panel


func _dispose() -> void:
	app.free()
	await _frames()


func _pins() -> Dictionary:
	return presenter._pinned._pinner_by_position.duplicate() if presenter._pinned != null else {}


func _state() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemies.get_enemies(),
		app.battle_result.get_outcome(), presenter.last_event.duplicate(true), _pins()]


func _arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		await _keyboard(KEY_ESCAPE)
		await _keyboard(KEY_P)
	else:
		await _mouse(panel)
	_check(presenter._armed == panel, "actual held panel armed")


func _press_slot(target: int, keyboard: bool) -> void:
	if keyboard:
		var key: Key = [KEY_1, KEY_2, KEY_3][target - 1]
		root.push_input(_key(key), true)
		root.push_input(_key(key), true)
		root.push_input(_key(key, false), true)
		await _frames()
	else:
		await _mouse(app.get_node("LiveEnemyRoster")._labels[target - 1])


## pin: "" none, "warden" another owner's Pin on the target, "button_golem" the Golem's own.
func _success(id: String, seat: int, target: int, keyboard: bool, statuses: bool, pin: String) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	if not statuses:
		for hero in app.party._heroes:
			hero.statuses = {}
		for enemy in app.enemies._enemies:
			enemy.statuses = {}
	var index := IDS.find(id)
	var knuckle := index < 2
	var reach: Array = [1, 2] if knuckle else [1, 2, 3]
	if not pin.is_empty():
		_check(presenter._pinned.pin_enemy(app.enemies, target, pin), "real shared Pin placed: " + pin)
	var shared: CombatPinned = presenter._pinned
	var metadata = app.get_node("LiveSupportHand")._metadata
	var facts: Dictionary = metadata.get_facts(panel)
	_check(facts.known and facts.cost == 1 and facts.owner == "button_golem"
		and metadata.definition(id) == ButtonGolemPoolCards.new().get_definition(id)
		and presenter._definition(id) == metadata.definition(id)
		and metadata.visual_state(panel).playable, "authentic enabled Golem face")
	var before := _state()
	await _hover(panel)
	var quote: Dictionary = presenter.current_forecast.duplicate(true)
	_check(quote.get("playable", false) and quote.target_positions == reach
		and quote.owner_position == seat and presenter.cue.text.contains("1 energy")
		and presenter.cue.text.contains("Choose one enemy slot"),
		"pure forecast offers exactly the printed living slots")
	_check(_state() == before and presenter._pinned == shared, "hover is pure including RNG and Pins")
	await _arm(panel, keyboard)
	_check(_state() == before, "selection is pure")
	if knuckle:
		await _keyboard(KEY_3)
		_check(_state() == before and presenter._armed == panel, "slot three cannot commit a Knuckle")
	var heroes: Array = app.party.get_heroes()
	var enemies: Array = app.enemies.get_enemies()
	var hand: Array = app.deck.hand.duplicate()
	var discard: Array = app.deck.discard_pile.duplicate()
	var draw: Array = app.deck.draw_pile.duplicate()
	var rng_state: int = app.run_rng.state
	var bonus := 5 if pin == "warden" else 0
	var base: int = DAMAGE[index] + bonus
	# Golem Weak 1 is x0.75; enemy 1 Exposed 1 makes x1.125; an already Tangled target adds +2.
	var damage := base
	if statuses:
		damage = int(floor(base * (1.125 if target == 1 else 0.75))) + (0 if target == 2 else 2)
	_check(quote.hits[reach.find(target)].damage == damage
		and quote.hits[reach.find(target)].pin_bonus == bonus, "independent printed/Pin/status damage oracle")
	var callback: Callable = presenter._bindings[panel].input
	var replay_args: Array = [panel, id, target, presenter._token, app.party, app.enemies,
		app.battle_result, app.run_rng, presenter._turn, app.enemies.get_enemy(target).id,
		panel.get_index(), app.deck, app.deck.hand.duplicate(), app.run_map, presenter._pinned]
	await _press_slot(target, keyboard)
	var event: Dictionary = presenter.last_event
	_check(event.get("ok", false) and event.damage == damage and event.cost == 1
		and event.energy_spent == 1 and event.owner_position == seat
		and event.target_position == target and event.pin_bonus == bonus, "confirmed real resolver receipt")
	var victim: Dictionary = enemies[target - 1]
	var absorbed := mini(int(victim.block), damage)
	victim.block -= absorbed
	victim.hp -= damage - absorbed
	if TANGLED[index] > 0:
		victim.statuses["tangled"] = int(victim.statuses.get("tangled", 0)) + TANGLED[index]
	_check(app.enemies.get_enemies() == enemies and event.block_absorbed == absorbed
		and event.hp_loss == damage - absorbed and event.tangled_added == TANGLED[index],
		"exact target HP/Block, Tangled only after the hit, every other enemy field preserved")
	hand.erase(id)
	discard.append(id)
	_check(app.party.get_heroes() == heroes and app.deck.energy == 0
		and app.deck.hand == hand and app.deck.discard_pile == discard
		and app.deck.draw_pile == draw and app.run_rng.state == rng_state,
		"one exact spend/discard, every hero field and RNG preserved")
	var expected_pins := {}
	if pin == "button_golem":
		expected_pins[target] = "button_golem"
	if knuckle:
		expected_pins[target] = "button_golem"
	_check(presenter._pinned == shared and _pins() == expected_pins and event.pinned == knuckle,
		"one shared Pin set: foreign Pin consumed once, own Pin kept, Knuckle pins the survivor")
	var copies := 0
	for child in app.hand_view.get_children():
		if child.get_child_count() > 0 and child.get_child(0) is Label and child.get_child(0).text == id:
			copies += 1
	_check(copies == 1 and presenter._armed == null, "mounted hand refreshed to the one remaining copy")
	var settled := _state()
	callback.call(_press())
	presenter._commit.callv(replay_args)
	presenter._queue_attack(target)
	await _frames()
	_check(_state() == settled and presenter._armed == null, "retired panel and duplicate input cannot replay")
	await _dispose()


## A lethal Knuckle consumes another owner's Pin and leaves no token on the slain enemy.
func _lethal() -> void:
	var panel := await _begin(IDS[1], 1)
	app.enemies._enemies[0].hp = 4
	_check(presenter._pinned.pin_enemy(app.enemies, 1, "warden"), "foreign Pin on a weak enemy")
	await _arm(panel, true)
	await _press_slot(1, true)
	_check(presenter.last_event.get("ok", false) and app.enemies.is_slain(1)
		and not presenter.last_event.pinned and _pins().is_empty(), "lethal hit pins nothing and consumes once")
	await _dispose()


func _refuse(mode: String, queued: bool) -> void:
	var panel := await _begin(IDS[0])
	if panel == null:
		await _dispose()
		return
	await _arm(panel, true)
	if queued:
		presenter._queue_attack(1)
		_check(presenter._queued, "valid receipt genuinely queued")
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"downed": app.party.apply_damage(2, 999)
		"back_seat":
			var hero: Dictionary = app.party._heroes[1]
			app.party._heroes[1] = app.party._heroes[2]
			app.party._heroes[2] = hero
			app.party._heroes[1].position = 2
			app.party._heroes[2].position = 3
		"missing_owner": app.party._heroes[1].id = "seamstress"
		"hand":
			app.deck.discard_played(IDS[0])
			app.deck.discard_played(IDS[0])
		"hand_order": app.deck.hand.reverse()
		"dead": app.enemies.apply_damage(1, 999)
		"identity": app.enemies._enemies[0].id = "replacement"
		"status": app.enemies._enemies[0].statuses = {"weak": -1}
		"inactive": app.deck.combat_state.player_turn_active = false
		"turn": app.enemy_intents.advance_turn()
		"closed": app._battle_closed = true
		"hidden": app.battle_view.hide()
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"rng":
			app.run_rng = RandomNumberGenerator.new()
			app.run_rng.seed = 291
		"deck":
			app.deck = CombatDeck.new([IDS[0]], app.run_rng)
			app.deck.start_turn()
		"panel": app._refresh_hand()
		"label": panel.get_child(0).text = IDS[2]
		"pinned_missing": presenter._pinned = null
		"pinned_swapped": presenter._pinned = CombatPinned.new()
		"escape":
			root.push_input(_key(KEY_ESCAPE), true)
			root.push_input(_key(KEY_ESCAPE, false), true)
	var before := _state()
	# Identity replacement and a swapped Pin set are stale only once a queue bound them.
	if not queued and mode in ["identity", "pinned_swapped"]:
		await _keyboard(KEY_ESCAPE)
	elif not queued:
		root.push_input(_key(KEY_1), true)
		root.push_input(_key(KEY_1, false), true)
	await _frames()
	_check(_state() == before, "full no-spend rejection: " + mode + " queued=" + str(queued))
	var settled := _state()
	presenter._queue_attack(1)
	await _frames()
	_check(_state() == settled, "rejected selection cannot replay: " + mode)
	await _dispose()


func _dead_slot() -> void:
	var panel := await _begin(IDS[3], 1)
	app.enemies.apply_damage(2, 999)
	await _hover(panel)
	_check(presenter.current_forecast.target_positions == [1, 3], "slain original slot omitted without compaction")
	await _arm(panel, true)
	var before := _state()
	await _keyboard(KEY_2)
	_check(_state() == before, "dead slot shortcut inert")
	await _keyboard(KEY_3)
	_check(presenter.last_event.get("ok", false) and presenter.last_event.target_position == 3
		and app.enemies.get_enemy(3).statuses.tangled == 6, "surviving original slot three remains executable")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in IDS:
		var reach: Array = [1, 2] if IDS.find(id) < 2 else [1, 2, 3]
		for seat in [1, 2]:
			for target in reach:
				for keyboard in [false, true]:
					await _success(id, seat, target, keyboard, keyboard, "")
	for pin in ["warden", "button_golem"]:
		for id in IDS:
			for statuses in [false, true]:
				await _success(id, 2, 1, statuses, statuses, pin)
	await _lethal()
	for mode in ["energy", "downed", "back_seat", "missing_owner", "hand", "hand_order", "dead",
		"identity", "status", "inactive", "turn", "closed", "hidden", "session", "rng", "deck",
		"panel", "label", "pinned_missing", "pinned_swapped", "escape"]:
		for queued in [false, true]:
			await _refuse(mode, queued)
	await _dead_slot()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_button_golem_thread_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
