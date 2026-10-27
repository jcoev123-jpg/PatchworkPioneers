extends SceneTree
## Cycle 246: the Warden Path card chosen in the Quilt village is really
## dealt into, and playable from, a routed Fight's shared hand.
##
## Every case starts at the real title, opens the real village, selects one
## authored Path with the mouse or the keyboard, sets out through the real
## opening book and enters a Fight through its real route button. The battle
## deck, the seeded replay, the mounted hand face, the mouse/number-key cast and
## every rejection are then checked against independent oracles.

const PartyChoice := preload("res://tests/party_choice.gd")
const APP_SCENE := "res://scenes/app.tscn"
const PATHS_PATH := "res://data/heroes/warden_paths.json"
const BRACE := "warden_bulwark_brace"
const LANCE := "warden_lance_pin"

var failures: Array[String] = []
var checks := 0
var app
var presenter
var metadata


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for index in range(4):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _hover(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var away := InputEventMouseMotion.new()
	away.position = Vector2(2, 2)
	root.push_input(away, true)
	await _frames()
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(motion.position), "pointer target is inside 1280x720")
	root.push_input(motion, true)
	await _frames()


func _click(control: Control) -> void:
	if not is_instance_valid(control):
		_check(false, "mouse target exists")
		return
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
	await _frames()


func _panel(card_id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and panel.get_child(0).text == card_id:
			return panel
	return null


func _hand_ids() -> Array[String]:
	var ids: Array[String] = []
	if not is_instance_valid(app.hand_view):
		return ids
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label:
			ids.append(panel.get_child(0).text)
	return ids


## Everything a cast may touch. The Unravel gauge and the Quilt receipts are
## read through their real battle-scoped services.
func _snapshot() -> Array:
	var gauges: Array = []
	if presenter != null and presenter._unravel != null:
		for position in range(1, CombatEnemies.MAX_ENEMIES + 1):
			gauges.append(presenter._unravel.get_snapshot(position))
	var quilt: Dictionary = {}
	if app._quilt_bonus != null:
		quilt = app._quilt_bonus.get_patch_progress()
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state,
		app.deck._rng.state, app.enemy_intents.get_intents(),
		app.enemy_intents._turn_index, app.battle_result.get_outcome(), gauges, quilt,
		app.session_gold, app.run_scraps, app._battle_closed, app.run_deck.duplicate(),
		app.run_warden_path_receipt.duplicate(true), presenter._pinned._pinner_by_position.duplicate(true)]


## Authored JSON numbers arrive as floats; a validated receipt normalizes them.
func _norm(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number:
			return int(number)
		return value
	if value is Array:
		var out_list: Array = []
		for item in value:
			out_list.append(_norm(item))
		return out_list
	if value is Dictionary:
		var out_dict: Dictionary = {}
		for key in value:
			out_dict[key] = _norm(value[key])
		return out_dict
	return value


## An independent seed/route oracle for one routed Fight: the canonical admitted
## deck, the optional appended Path card and the one shuffle the app records.
## The Path case rewinds to the pre-admission state, exactly like the app.
func _oracle(seed_value: int, node_id: String, card_id: String) -> Dictionary:
	var starter: Array[String] = StarterCards.new().get_starting_deck()
	var ledger := RunRestStitchCards.new(starter, {}, 0, 1)
	if not ledger.is_valid():
		return {}
	var snapshot: Dictionary = ledger.get_snapshot()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var run_map := RunMap.new()
	run_map.generate(rng)
	if not run_map.choose_node(node_id):
		return {}
	var entry := RunAuthoredBattleEntry.new().entry_current_battle(
		run_map, rng, RunFightEncounterSelection.new())
	if not entry.get("success", false):
		return {}
	var state_before := rng.state
	var admission := RunStitchedBattleHandEntry.new().admit_next_fight(
		starter, {}, 0, 1, snapshot.receipt, rng)
	if not admission.get("ok", false):
		return {}
	var twelve: CombatDeck = admission.combat_deck
	var party := CombatParty.new(_norm(JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))))
	var first_intents := CombatEnemyIntents.new(entry.intents._definitions)
	_check(party.is_valid() and first_intents.bind_battle(entry.enemies, party, rng),
		"independent twelve-card shuffle is followed by cached weighted intentions")
	if not twelve.start_turn():
		return {}
	var result := {"encounter_id": String(entry.get("encounter_id", "")),
		"twelve_hand": twelve.hand.duplicate(), "twelve_draw": twelve.draw_pile.duplicate(),
		"twelve_rng": rng.state, "hand": twelve.hand.duplicate(),
		"draw": twelve.draw_pile.duplicate(), "rng_state": rng.state}
	if card_id.is_empty():
		return result
	rng.state = state_before
	var ids: Array[String] = []
	ids.assign(snapshot.deck)
	ids.append(card_id)
	var thirteen := CombatDeck.new(ids, rng)
	var path_intents := CombatEnemyIntents.new(entry.intents._definitions)
	_check(path_intents.bind_battle(entry.enemies, party, rng),
		"independent Path deck shuffle is followed by cached weighted intentions")
	if not thirteen.start_turn():
		return {}
	result["hand"] = thirteen.hand.duplicate()
	result["draw"] = thirteen.draw_pile.duplicate()
	result["rng_state"] = rng.state
	return result


## The first seed whose opening Fight really deals the selected Path card into
## the first hand. Nothing is special-cased: it is the same map, entry, ledger
## admission and single shuffle the app performs.
func _find_fixture(card_id: String) -> Dictionary:
	for seed_value in range(1, 80):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var run_map := RunMap.new()
		run_map.generate(rng)
		for node_id in run_map.get_legal_choices():
			if run_map.get_node(node_id).get("type") != "Fight":
				continue
			var oracle := _oracle(seed_value, String(node_id), card_id)
			if oracle.is_empty() or not (oracle["hand"] as Array).has(card_id):
				continue
			oracle["seed"] = seed_value
			oracle["node_id"] = String(node_id)
			return oracle
	return {}


func _route_button(node_id: String) -> Button:
	for button in app.route_buttons:
		if is_instance_valid(button) and String(button.get_meta("route_id", "")) == node_id:
			return button
	return null


func _path_button(path_id: String) -> Button:
	if not is_instance_valid(app.base_screen):
		return null
	for button in app.base_screen.warden_buttons:
		if is_instance_valid(button) and String(button.get_meta("path_id", "")) == path_id:
			return button
	return null


## Real title -> real village -> one authored Path -> real opening book -> the
## real routed Fight. Returns false before any battle assertion on a refusal.
func _enter_routed_fight(fixture: Dictionary, path_id: String, use_mouse: bool) -> bool:
	app = (load(APP_SCENE) as PackedScene).instantiate()
	root.add_child(app)
	await _frames()
	_check(app.deck == null and app.run_map == null and app.title_view.is_visible_in_tree(),
		"case starts from the real title with no battle: " + path_id)
	app.run_seed = int(fixture["seed"])
	await _click(app.base_button)
	_check(is_instance_valid(app.base_screen) and app.base_screen.has_open_village(),
		"the real Quilt village opens: " + path_id)
	if not is_instance_valid(app.base_screen):
		return false
	var view: BaseScreen = app.base_screen
	var target := _path_button(path_id)
	_check(target != null and not target.disabled, "authored Path option is offered: " + path_id)
	if target == null:
		return false
	if use_mouse:
		await _click(target)
	else:
		for attempt in range(view.warden_buttons.size() + 14):
			if target.has_focus():
				break
			await _key(KEY_TAB)
		_check(target.has_focus(), "physical Tab reaches the Path option: " + path_id)
		await _key(KEY_ENTER)
	_check(view.selected_warden_path_id() == path_id, "the village confirms the selected Path: " + path_id)
	await _click(view.set_out_button)
	PartyChoice.choose(app)  # Cycle 345: Set out first asks for the party.
	await _frames()
	_check(is_instance_valid(app.route_view) and app.base_screen == null,
		"Set out opens the real opening book: " + path_id)
	var route := _route_button(String(fixture["node_id"]))
	_check(route != null and not route.disabled, "the opening offers the fixture Fight: " + path_id)
	if route == null:
		return false
	await _click(route)
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	metadata = app.get_node("LiveSupportHand")._metadata
	return app.deck != null and is_instance_valid(app.battle_view) \
		and app.battle_view.is_visible_in_tree() and presenter != null


func _dispose() -> void:
	app.free()
	await _frames()


func _case(path: String, id: String, mouse: bool) -> void:
	var fixture := _find_fixture(id)
	_check(not fixture.is_empty(), "a real seeded opening holds " + id)
	if fixture.is_empty():
		return
	_check(await _enter_routed_fight(fixture, path, mouse), "routed battle mounted")
	if app.deck == null:
		await _dispose()
		return
	var panel := _panel(id)
	_check(panel != null and presenter.warden_ready(), "genuine held Path authority")
	_check(app.run_warden_path_receipt == RunWardenPathChoice.new().choose(path), "exact selected receipt")
	_check(app.deck.hand == fixture.hand and app.deck.draw_pile == fixture.draw
		and app.run_rng.state == fixture.rng_state, "independent seeded deal and replay")
	var all: Array = app.deck.hand + app.deck.draw_pile + app.deck.discard_pile
	_check(all.size() == 13 and all.count(id) == 1
		and not all.has(LANCE if id == BRACE else BRACE) and app.run_deck.size() == 12,
		"only this Path enters the battle deck, never the run ledger")
	_check(panel != null and presenter._eligible(panel), "real panel accepts input")
	_check(metadata.visual_state(panel).get("playable", false), "genuine held Warden face is enabled")
	if panel == null:
		await _dispose()
		return
	var before := _snapshot()
	if id == LANCE and not mouse:
		_check(presenter._pinned == presenter._direct_fire.get_pinned(), "Warden uses the shared Tinker Pin authority")
		_check(presenter._pinned.pin_enemy(app.enemies, 2, "tinker"), "cross-owner shared Pin really exists")
		before = _snapshot()
	var quote: Dictionary = presenter.warden_preview(id)
	_check(quote.get("ok", false), "held card has an executable forecast")
	await _hover(panel)
	_check(presenter.cue.is_visible_in_tree() and presenter.current_forecast == quote,
		"mounted hover shows resolver forecast")
	_check(_snapshot() == before, "preview consumes nothing")
	_check(quote.target_positions == ([] if id == BRACE else [1, 2]), "authored target slots")
	app.deck.combat_state.energy = 0
	before = _snapshot()
	await _click(panel)
	_check(not presenter.warden_preview(id).playable and _snapshot() == before, "insufficient energy refuses")
	app.deck.combat_state.energy = 3
	await _frames()
	before = _snapshot()
	_check(not presenter._resolve_attack(app.party, app.enemies,
		LANCE if id == BRACE else BRACE, 1).get("ok", false) and _snapshot() == before,
		"wrong Path cannot dispatch")
	app.run_warden_path_receipt.card.cost = 0
	before = _snapshot()
	await _click(panel)
	_check(not presenter.warden_ready() and _snapshot() == before, "forged live receipt refuses")
	app.run_warden_path_receipt = RunWardenPathChoice.new().choose(path)
	await _frames()
	if id == LANCE:
		await _click(panel)
		before = _snapshot()
		await _key(KEY_3)
		_check(_snapshot() == before and presenter._armed == panel, "illegal enemy slot refuses")
		await _key(KEY_ESCAPE)
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var expected_deck := CombatDeck.new([], rng)
	expected_deck.draw_pile.assign(app.deck.draw_pile)
	expected_deck.hand.assign(app.deck.hand)
	expected_deck.discard_pile.assign(app.deck.discard_pile)
	expected_deck.combat_state.energy = app.deck.energy
	expected_deck.combat_state.player_turn_active = true
	var expected_party := CombatParty.new([])
	expected_party._heroes = app.party.get_heroes()
	var expected_enemies := CombatEnemies.new([])
	expected_enemies._enemies = app.enemies.get_enemies()
	var expected_pin := CombatPinned.new()
	expected_pin._pinner_by_position = presenter._pinned._pinner_by_position.duplicate(true)
	var target := 0 if id == BRACE else 2
	var event := CombatWardenPathCards.new().play(expected_deck, expected_party,
		expected_enemies, id, target, app.run_warden_path_receipt, expected_pin)
	_check(event.get("ok", false), "scene-free oracle genuinely commits")
	var rng_before: int = app.run_rng.state
	if mouse:
		await _click(panel)
		if id == LANCE:
			await _click(app.get_node("LiveEnemyRoster")._labels[target - 1])
	else:
		await _key(KEY_ESCAPE)
		for attempt in range(app.deck.hand.size() + 1):
			await _key(KEY_P)
			if presenter._armed == panel:
				break
		_check(presenter._armed == panel, "P reaches held Warden card")
		await _key(KEY_ENTER if id == BRACE else KEY_2)
	_check(app.deck.energy == expected_deck.energy and app.deck.hand == expected_deck.hand
		and app.deck.discard_pile == expected_deck.discard_pile, "one authored payment and discard")
	_check(app.party.get_heroes() == expected_party.get_heroes()
		and app.enemies.get_enemies() == expected_enemies.get_enemies()
		and presenter._pinned._pinner_by_position == expected_pin._pinner_by_position,
		"mounted effects match scene-free HP Block and shared Pin")
	_check(app.run_rng.state == rng_before, "committed effects consume no RNG")
	if id == LANCE:
		_check(presenter._pinned.pinner_for_enemy(target) == "warden", "surviving enemy has Warden Pin")
	before = _snapshot()
	_check(not presenter._resolve_attack(app.party, app.enemies, id, target).get("ok", false)
		and _snapshot() == before, "unheld replay cannot mutate")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for mouse in [true, false]:
		await _case("bulwark", BRACE, mouse)
		await _case("vanguard", LANCE, mouse)
	await _negative_case()
	await _admission_case(false)
	await _admission_case(true)
	for message in failures:
		printerr("FAIL: " + message)
	print("live_warden_path_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _negative_case() -> void:
	var fixture := _find_fixture(LANCE)
	_check(not fixture.is_empty(), "negative fixture exists")
	if fixture.is_empty():
		return
	_check(await _enter_routed_fight(fixture, "vanguard", true), "negative battle mounted")
	var panel := _panel(LANCE)
	_check(panel != null and presenter.warden_path_playable(LANCE), "negative fixture genuinely playable")
	if panel == null:
		await _dispose()
		return
	var heroes: Array[Dictionary] = app.party.get_heroes()
	_check(heroes[0].id == "warden" and not app.party.is_downed(1), "living front Warden prerequisite")
	# Move the living owner out of the authored FROM slot while retaining valid slots.
	var displaced: Array[Dictionary] = heroes.duplicate(true)
	displaced[0] = heroes[1].duplicate(true)
	displaced[0].position = 1
	displaced[1] = heroes[0].duplicate(true)
	displaced[1].position = 2
	app.party._heroes = displaced
	await _frames()
	var before := _snapshot()
	_check(app.party.get_hero(2).id == "warden" and not app.party.is_downed(2), "illegal FROM is living")
	await _click(panel)
	_check(not presenter.warden_path_playable(LANCE) and _snapshot() == before, "illegal FROM never spends")
	app.party._heroes = heroes.duplicate(true)
	_check(app.party.apply_damage(1, 9999) and app.party.is_downed(1), "downed prerequisite")
	await _frames()
	before = _snapshot()
	await _click(panel)
	_check(not presenter.warden_path_playable(LANCE) and _snapshot() == before, "downed owner never spends")
	app.party._heroes = heroes.duplicate(true)
	app.deck.discard_pile.append(LANCE)
	await _frames()
	before = _snapshot()
	await _click(panel)
	_check(not presenter.warden_ready() and _snapshot() == before, "duplicate lineage refuses")
	app.deck.discard_pile.erase(LANCE)
	await _frames()
	_check(presenter.warden_path_playable(LANCE), "restored fixture playable before stale callback")
	await _click(panel)
	_check(presenter._armed == panel, "stale case arms actual panel")
	presenter._queue_attack(1)
	_check(presenter._queued, "real deferred commit queued")
	# A different held-card order invalidates the captured hand/index, without a frame.
	app.deck.hand.reverse()
	before = _snapshot()
	await _frames()
	_check(_snapshot() == before, "stale queued hand cannot commit")
	app.deck.hand.reverse()
	await _frames()
	# The real battle outcome retires eligibility and settles the old hand.
	for enemy in app.enemies.get_enemies():
		app.enemies.apply_damage(enemy.position, 9999)
	app._observe_battle_result()
	await _frames()
	_check(app._battle_closed and app.deck.discard_pile.has(LANCE), "post-battle settled the old held card")
	before = _snapshot()
	_check(not presenter._resolve_attack(app.party, app.enemies, LANCE, 1).get("ok", false)
		and _snapshot() == before, "post-battle actions mutate nothing")
	var retired_deck: CombatDeck = app.deck
	var retired_party: CombatParty = app.party
	var retired_enemies: CombatEnemies = app.enemies
	var retired_pin: CombatPinned = presenter._pinned
	var retired_rng: RandomNumberGenerator = app.run_rng
	await _click(app.return_button)
	_check(app.deck == null and app.run_warden_path_receipt.is_empty()
		and app.run_warden_path_choice == null and presenter._warden_card.is_empty(), "Return clears Warden setup and binding")
	var retired_before := [retired_deck.hand.duplicate(), retired_deck.energy,
		retired_party.get_heroes(), retired_enemies.get_enemies(),
		retired_pin._pinner_by_position.duplicate(), retired_rng.state]
	_check(not presenter._resolve_attack(retired_party, retired_enemies, LANCE, 1).get("ok", false), "retired callback refuses")
	_check(retired_before == [retired_deck.hand, retired_deck.energy,
		retired_party.get_heroes(), retired_enemies.get_enemies(),
		retired_pin._pinner_by_position, retired_rng.state], "retired callback leaves authorities unchanged")
	await _dispose()


func _admission_case(tamper: bool) -> void:
	var fixture := _find_fixture(BRACE)
	_check(not fixture.is_empty(), "admission fixture exists")
	if fixture.is_empty():
		return
	var expected := _oracle(fixture.seed, fixture.node_id, "")
	app = (load(APP_SCENE) as PackedScene).instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = fixture.seed
	await _click(app.base_button)
	var view: BaseScreen = app.base_screen
	_check(view.warden_buttons.size() == 2 and view.selected_warden_path_id().is_empty(), "real unselected Warden offers")
	if tamper:
		await _click(_path_button("bulwark"))
		_check(view.selected_warden_path_id() == "bulwark", "tamper starts with genuine claim")
	await _click(view.set_out_button)
	PartyChoice.choose(app)  # Cycle 345: Set out first asks for the party.
	var admission_rng: int = app.run_rng.state
	var admission_route: Array = app.run_map.get_route()
	if tamper:
		_check(app.run_warden_path_receipt.get("ok", false), "genuine receipt precedes tamper")
		app.run_warden_path_receipt.starter_deck.append(LANCE)
	await _click(_route_button(fixture.node_id))
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	if tamper:
		_check(app.deck == null and app.run_map.get_route() == admission_route
			and app.run_rng.state == admission_rng
			and app.route_view.is_visible_in_tree(), "forged receipt refuses battle admission")
		await _dispose()
		return
	_check(app.deck != null and app.battle_view.is_visible_in_tree(), "no-Path routed battle exists")
	var all: Array = app.deck.hand + app.deck.draw_pile + app.deck.discard_pile
	_check(all.size() == 12 and not all.has(BRACE) and not all.has(LANCE), "unselected/forged receipt admits no Path")
	_check(app.deck.hand == expected.hand and app.deck.draw_pile == expected.draw
		and app.run_rng.state == expected.rng_state, "unselected/forged receipt retains twelve-card RNG replay")
	_check(not presenter.warden_ready() and presenter._warden_card.is_empty(), "no authority without exact receipt")
	await _dispose()


