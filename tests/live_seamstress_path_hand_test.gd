extends SceneTree
## Cycle 168: the Seamstress Path card chosen in the Quilt village is really
## dealt into, and playable from, a routed Fight's shared hand.
##
## Every case starts at the real title, opens the real village, selects one
## authored Path with the mouse or the keyboard, sets out through the real
## opening book and enters a Fight through its real route button. The battle
## deck, the seeded replay, the mounted hand face, the mouse/number-key cast and
## every rejection are then checked against independent oracles.

const PartyChoice := preload("res://tests/party_choice.gd")
const APP_SCENE := "res://scenes/app.tscn"
const PATHS_PATH := "res://data/heroes/seamstress_paths.json"
const LEECH := "seamstress_leech_stitch"
const FRAY := "seamstress_fray"

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
		app.run_seamstress_path_receipt.duplicate(true)]


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


func _authored_path(path_id: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(PATHS_PATH)) != OK or not parser.data is Array:
		return {}
	for record in parser.data:
		if record is Dictionary and String(record.get("id", "")) == path_id:
			return _norm(record)
	return {}


## The canonical Path receipt and the exact card it carries, from the authored
## record, never from the app's own copy.
func _receipt(path_id: String, starter: Array[String]) -> Dictionary:
	var authored := _authored_path(path_id)
	var card: Dictionary = authored.get("card", {})
	var deck: Array = []
	for card_id in starter:
		deck.append(card_id)
	deck.append(String(card.get("id", "")))
	return {"ok": true, "owner": "seamstress", "path_id": path_id,
		"display_name": String(authored.get("display_name", "")),
		"passive": authored.get("passive", {}), "card": card, "deck": deck}


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
	for button in app.base_screen.path_buttons:
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
		for attempt in range(view.path_buttons.size() + 4):
			if target.has_focus():
				break
			await _key(KEY_TAB)
		_check(target.has_focus(), "physical Tab reaches the Path option: " + path_id)
		await _key(KEY_ENTER)
	_check(view.selected_path_id() == path_id, "the village confirms the selected Path: " + path_id)
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


## Both Path cards must be exactly once in the thirteen-card battle deck while
## the stitchable run ledger stays the authored twelve.
func _check_deck(card_id: String, fixture: Dictionary) -> void:
	var total: int = app.deck.draw_pile.size() + app.deck.hand.size() + app.deck.discard_pile.size()
	var copies: int = app.deck.draw_pile.count(card_id) + app.deck.hand.count(card_id) \
		+ app.deck.discard_pile.count(card_id)
	var other: String = FRAY if card_id == LEECH else LEECH
	var other_copies: int = app.deck.draw_pile.count(other) + app.deck.hand.count(other) \
		+ app.deck.discard_pile.count(other)
	_check(total == 13, "the battle deck holds thirteen cards: " + card_id)
	_check(copies == 1, "the selected Path card is dealt exactly once: " + card_id)
	_check(other_copies == 0, "the other Path card never enters this battle: " + card_id)
	_check(app.run_deck.size() == 12 and not app.run_deck.has(card_id),
		"the stitchable run ledger stays the twelve authored cards: " + card_id)
	_check(app.deck.hand == fixture["hand"] and app.deck.draw_pile == fixture["draw"],
		"the dealt hand is the independent thirteen-card seed oracle: " + card_id)
	_check(app.run_rng.state == int(fixture["rng_state"]),
		"one shuffle of the thirteen cards is the recorded run RNG state: " + card_id)
	_check(app.encounter_id == String(fixture["encounter_id"]),
		"the battle is the fixture encounter: " + card_id)
	_check(_hand_ids() == app.deck.hand, "the mounted hand is the authoritative dealt hand: " + card_id)
	_check(_panel(card_id) != null and _panel(card_id).is_visible_in_tree(),
		"the Path card is a real visible hand panel: " + card_id)


## Every living hero carries real missing HP, so the Leech Stitch heal and its
## weakest-ally choice are non-vacuous.
func _wound_party(card_id: String) -> void:
	for position in range(1, CombatParty.PARTY_SIZE + 1):
		if not app.party.is_downed(position):
			_check(app.party.apply_damage(position, 3),
				"the fixture really wounds hero %d: %s" % [position, card_id])
	app._refresh_party()


func _expected_weakest() -> Array:
	var lowest := CombatParty.MAX_INT
	var slot := 0
	for position in range(1, CombatParty.PARTY_SIZE + 1):
		if app.party.is_downed(position):
			continue
		var hero: Dictionary = app.party.get_hero(position)
		if hero.is_empty() or int(hero.get("hp", 0)) <= 0:
			continue
		if int(hero["hp"]) < lowest:
			lowest = int(hero["hp"])
			slot = position
	return [slot, lowest]


func _check_face(card_id: String, authored_card: Dictionary) -> void:
	var panel := _panel(card_id)
	var facts: Dictionary = metadata.describe(card_id)
	_check(facts.get("known") == true and facts.get("display_name") == authored_card.get("display_name"),
		"the Path card face names its authored record: " + card_id)
	_check(int(facts.get("cost", -1)) == int(authored_card.get("cost", -2)),
		"the Path card face shows its authored cost: " + card_id)
	var face_text: String = metadata.base_effect_text(card_id)
	for effect_name in ["bleed", "unravel"]:
		if (authored_card.get("effects", {}) as Dictionary).has(effect_name):
			_check(face_text.contains(effect_name.capitalize()),
				"the tooltip describes the authored %s effect: %s" % [effect_name, card_id])
	if card_id == LEECH:
		_check(face_text.contains("Bleed 4") and face_text.contains("Bloodline passive 1"),
			"the face shows Bleed 4 (3 authored + Bloodline 1): " + card_id)
		_check(face_text.contains("heal 2 HP") and face_text.contains("weakest living ally"),
			"the face shows the capped weakest-ally heal: " + card_id)
	else:
		_check(face_text.contains("6 Unravel") and face_text.contains("Unpicker passive 2"),
			"the face shows Unravel 6 (4 authored + Unpicker 2): " + card_id)
		_check(face_text.contains("Bleed 1"), "the face shows Fray's own Bleed 1: " + card_id)
	var faces: Dictionary = metadata.face_assets(card_id)
	var authored_art := String(authored_card.get("illustration_path", ""))
	var expected_picture := authored_art if ResourceLoader.exists(authored_art) \
		else "res://assets/paper/cards/emblem_seamstress.png"
	_check(faces.get("picture_path") == expected_picture,
		"the face uses the authored illustration path: " + card_id)
	_check(String(faces.get("frame_path", "")).ends_with("card_frame_seamstress.png"),
		"the face keeps the Seamstress felt frame: " + card_id)
	_check(panel != null and panel.tooltip_text.contains(String(authored_card.get("display_name", ""))),
		"the mounted panel carries the authored tooltip: " + card_id)
	_check(not metadata.get_geometry(panel).is_empty(),
		"the Path card draws a real face layout: " + card_id)


func _check_legal_slots(card_id: String, expected_slots: Array) -> void:
	var preview: Dictionary = presenter.path_preview(card_id)
	_check(presenter.path_ready(), "the battle-bound resolver holds the genuine Path: " + card_id)
	_check(String(presenter._path_card.get("id", "")) == card_id,
		"the bound resolver is this run's Path card: " + card_id)
	_check(preview.get("playable") == true and preview.get("requires_selection") == true
		and preview.get("target_positions") == expected_slots,
		"legal enemy slots come from the resolver preview: " + card_id)
	var panel := _panel(card_id)
	_check(panel != null and panel.gui_input.get_connections().size() == 1,
		"the held Path panel owns exactly one real input handler: " + card_id)
	_check(metadata.visual_state(panel).get("playable") == true
		and panel.self_modulate == Color.WHITE,
		"a legal Path card is drawn enabled, not dimmed: " + card_id)


## The hover/keyboard projection is read-only and names the same slots the
## resolver admits; no Bleed tick or Unravel charge is simulated.
func _check_preview(card_id: String, target: int, before: Array) -> void:
	var panel := _panel(card_id)
	await _hover(panel)
	_check(presenter._selected == panel and presenter.cue.is_visible_in_tree(),
		"hovering the Path card shows its live forecast: " + card_id)
	var reading: String = presenter.cue.text
	_check(reading.contains(_definition_name(card_id)), "forecast names the card: " + card_id)
	_check(reading.contains("P / click card") and reading.contains("/ click enemy"),
		"forecast exposes mouse and keyboard targeting: " + card_id)
	if card_id == LEECH:
		_check(reading.contains("%d: Bleed " % target) and reading.contains("heal "),
			"Leech Stitch forecast projects Bleed and the heal on slot %d" % target)
		_check(not reading.contains("Unravel"),
			"Leech Stitch never claims an Unravel charge: " + card_id)
	else:
		_check(reading.contains("%d: Bleed " % target) and reading.contains("Unravel 6 → "),
			"Fray forecast projects Bleed 1 and Unravel 6 on slot %d" % target)
		var gauge: Dictionary = _unravel_snapshot(target)
		var reaches: int = mini(int(gauge.get("gauge", 0)) + 6, int(gauge.get("threshold", 0)))
		_check(reading.contains("/%d" % int(gauge.get("threshold", 0)))
			and reading.contains("skip") == (reaches == int(gauge.get("threshold", 0))),
			"the Fray forecast only claims a skip the shared gauge really reaches: " + card_id)
	await _key(KEY_ESCAPE)
	_check(_snapshot() == before and presenter._armed == null and presenter.cue.text == ""
		and not presenter.cue.is_visible_in_tree(),
		"cancel retires the forecast without any transaction: " + card_id)


func _definition_name(card_id: String) -> String:
	var path_id := "bloodline" if card_id == LEECH else "unpicker"
	return String(_authored_path(path_id).get("card", {}).get("display_name", ""))


func _unravel_snapshot(position: int) -> Dictionary:
	if presenter == null or presenter._unravel == null:
		return {}
	return presenter._unravel.get_snapshot(position)


func _arm(card_id: String, use_mouse: bool) -> Control:
	if use_mouse:
		await _click(_panel(card_id))
	else:
		for attempt in range(CombatEnemies.MAX_ENEMIES + 9):
			await _key(KEY_P)
			if presenter._card_id(presenter._armed) == card_id:
				break
	_check(presenter._card_id(presenter._armed) == card_id,
		"real input arms this Path card: " + card_id)
	return presenter._armed


func _cast(card_id: String, target: int, use_mouse: bool) -> void:
	if use_mouse:
		await _click(app.get_node("LiveEnemyRoster")._labels[target - 1])
	else:
		await _key(KEY_1 + target - 1)


## One real mouse or number-key cast: exactly one spend, one discard and the
## exact authored effects through the shared battle gauge.
func _play_case(card_id: String, use_mouse: bool) -> void:
	var path_id := "bloodline" if card_id == LEECH else "unpicker"
	var fixture := _find_fixture(card_id)
	_check(not fixture.is_empty(), "an opening Fight really deals this Path card: " + card_id)
	if fixture.is_empty():
		return
	var starter: Array[String] = StarterCards.new().get_starting_deck()
	var expected := _receipt(path_id, starter)
	var authored_card: Dictionary = expected["card"]
	if not await _enter_routed_fight(fixture, path_id, use_mouse):
		await _dispose()
		return
	_check(app.run_seamstress_path_receipt == expected,
		"the routed battle carries the validated Path receipt: " + card_id)
	_check_deck(card_id, fixture)
	_check_face(card_id, authored_card)
	_wound_party(card_id)
	var target := 1
	var held := _panel(card_id)
	_check(held != null and held.get_index() == app.deck.hand.find(card_id),
		"the Path panel sits at its authoritative hand slot: " + card_id)
	if held == null:
		await _dispose()
		return
	var alive: Array = []
	for enemy in app.enemies.get_enemies():
		if int(enemy.get("hp", 0)) > 0:
			alive.append(int(enemy.get("position", 0)))
	_check(alive.has(target), "the fixture's first enemy slot is a real living target: " + card_id)
	_check_legal_slots(card_id, alive)
	var before := _snapshot()
	await _check_preview(card_id, target, before)
	_check(_snapshot() == before, "previewing a Path card never mutates the battle: " + card_id)

	var weakest := _expected_weakest()
	var enemy_before: Dictionary = app.enemies.get_enemy(target)
	var bleed_before: int = int(enemy_before.get("statuses", {}).get("bleed", 0))
	var gauge_before := _unravel_snapshot(target)
	var energy_before: int = app.deck.energy
	var hand_before: Array[String] = app.deck.hand.duplicate()
	var discard_before: int = app.deck.discard_pile.size()
	var rng_before: int = app.run_rng.state

	await _arm(card_id, use_mouse)
	await _cast(card_id, target, use_mouse)

	_check(presenter.last_event.get("ok", false), "the committed Path play reported success: " + card_id)
	_check(String(presenter.last_event.get("card_id", "")) == card_id,
		"the committed event names this Path card: " + card_id)
	_check(String(presenter.last_event.get("path_id", "")) == path_id,
		"the committed event names this Path: " + card_id)
	_check(int(presenter.last_event.get("target_position", 0)) == target,
		"the committed event targeted the selected enemy slot: " + card_id)
	_check(app.deck.energy == energy_before - 1,
		"the cast spends exactly the authored one energy: " + card_id)
	_check(not app.deck.hand.has(card_id) and app.deck.hand.size() == hand_before.size() - 1,
		"exactly one held Path copy leaves the hand: " + card_id)
	_check(app.deck.discard_pile.size() == discard_before + 1
		and app.deck.discard_pile.back() == card_id,
		"exactly one Path copy enters the discard pile: " + card_id)
	_check(app.run_rng.state == rng_before and app.deck._rng.state == rng_before,
		"the cast never advances the seeded run RNG: " + card_id)
	var enemy_after: Dictionary = app.enemies.get_enemy(target)
	var bleed_after: int = int(enemy_after.get("statuses", {}).get("bleed", 0))
	for other in app.enemies.get_enemies():
		if int(other.get("position", 0)) != target:
			_check(app.enemies.get_enemy(int(other["position"])) == other,
				"an unselected enemy slot is untouched: " + card_id)
	if path_id == "bloodline":
		_check(bleed_after == bleed_before + 4 and int(presenter.last_event.get("bleed_applied", 0)) == 4,
			"Leech Stitch applies exactly Bleed 4 (3 authored + Bloodline 1): " + card_id)
		_check(int(presenter.last_event.get("unravel_applied", 0)) == 0,
			"Leech Stitch adds no Unravel: " + card_id)
		var healed_slot: int = int(weakest[0])
		var missing: int = int(app.party.get_hero(healed_slot).get("max_hp", 0)) - int(weakest[1])
		var expected_heal: int = mini(2, missing)
		_check(expected_heal == 2, "the fixture really leaves HP to heal: " + card_id)
		_check(int(presenter.last_event.get("healed_slot", 0)) == healed_slot,
			"Leech Stitch heals the weakest living ally: " + card_id)
		_check(int(presenter.last_event.get("healed_amount", -1)) == expected_heal,
			"Leech Stitch heals exactly min(2, missing HP): " + card_id)
		_check(int(app.party.get_hero(healed_slot).get("hp", 0)) == int(weakest[1]) + expected_heal,
			"the healed hero really gained that HP: " + card_id)
	else:
		_check(bleed_after == bleed_before + 1 and int(presenter.last_event.get("bleed_applied", 0)) == 1,
			"Fray applies exactly Bleed 1: " + card_id)
		_check(int(presenter.last_event.get("unravel_applied", 0)) == 6,
			"Fray adds exactly 6 Unravel (4 authored + Unpicker 2): " + card_id)
		_check(int(presenter.last_event.get("healed_slot", -1)) == 0
			and int(presenter.last_event.get("healed_amount", -1)) == 0,
			"Fray heals nobody: " + card_id)
		var gauge_after: Dictionary = _unravel_snapshot(target)
		var threshold: int = int(gauge_before.get("threshold", 0))
		_check(int(gauge_before.get("gauge", -1)) == 0 and threshold > 0,
			"the fixture target starts with an empty shared gauge: " + card_id)
		_check(int(gauge_after.get("gauge", -1)) == mini(6, threshold)
			and int(gauge_after.get("threshold", -1)) == threshold,
			"the battle's own Unravel gauge received the charge: " + card_id)
		_check(presenter._unravel._bound_enemies == app.enemies
			and app.round_flow._unravel == presenter._unravel,
			"the same gauge is shared with the live round flow: " + card_id)
	var quilt: Dictionary = app._quilt_bonus.get_patch_progress()
	_check(quilt.get("patches", {}).get("seamstress", {}).get("played") == true,
		"the confirmed Path play credits its real owner for the Quilt: " + card_id)
	_check(presenter._armed == null and presenter.cue.text == "",
		"the committed selection is retired: " + card_id)
	_check(_hand_ids() == app.deck.hand
		and app.pile_label.text == "Draw: %d | Discard: %d" % [
			app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		"the mounted hand and piles refresh after the cast: " + card_id)
	var after := _snapshot()

	# The spent copy cannot be replayed, and the same seeded path replays exactly.
	await _key(KEY_1)
	await _click(app.get_node("LiveEnemyRoster")._labels[target - 1])
	_check(_snapshot() == after, "the consumed Path card cannot cast twice: " + card_id)
	await _dispose()
	if not await _enter_routed_fight(fixture, path_id, not use_mouse):
		await _dispose()
		return
	_wound_party(card_id)
	await _frames()
	_check(app.deck.hand == before[1] and app.deck.draw_pile == before[0]
		and app.run_rng.state == int(before[7]),
		"a second seed-identical session deals the same thirteen-card hand: " + card_id)
	await _arm(card_id, not use_mouse)
	await _cast(card_id, target, not use_mouse)
	_check(_strip_receipt(_snapshot()) == _strip_receipt(after),
		"the opposite input device replays the identical committed battle: " + card_id)
	await _dispose()


func _strip_receipt(state: Array) -> Array:
	# The receipt itself is asserted separately; compare the resolved battle.
	return state.slice(0, state.size() - 1)


## An unselected opening keeps the twelve-card deck, its seeded deal and no Path
## admission at all.
func _unselected_case() -> void:
	var fixture := _find_fixture(LEECH)
	_check(not fixture.is_empty(), "unselected fixture: an opening Fight exists")
	if fixture.is_empty():
		return
	var twelve := _oracle(int(fixture["seed"]), String(fixture["node_id"]), "")
	app = (load(APP_SCENE) as PackedScene).instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = int(fixture["seed"])
	await _click(app.route_button)
	await _frames()
	_check(is_instance_valid(app.route_view) and app.run_seamstress_path_receipt.is_empty(),
		"a direct opening carries no Path receipt")
	await _click(_route_button(String(fixture["node_id"])))
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	metadata = app.get_node("LiveSupportHand")._metadata
	var total: int = app.deck.draw_pile.size() + app.deck.hand.size() + app.deck.discard_pile.size()
	_check(total == 12 and app.deck.hand.count(LEECH) == 0 and app.deck.draw_pile.count(LEECH) == 0
		and app.deck.discard_pile.count(LEECH) == 0 and app.deck.hand.count(FRAY) == 0,
		"an unselected route keeps the twelve authored cards and no Path card")
	_check(app.deck.hand == twelve["hand"] and app.deck.draw_pile == twelve["draw"]
		and app.run_rng.state == int(twelve["rng_state"]),
		"an unselected route preserves the existing seeded twelve-card replay")
	_check(presenter._path_cards == null and presenter._path_card.is_empty()
		and presenter.path_preview(LEECH).get("playable") == false
		and presenter.path_preview(FRAY).get("playable") == false,
		"no Path resolver is bound without a genuine receipt")
	await _dispose()


## A tampered receipt must never add a card, bind a resolver or spend anything.
func _tampered_receipt_case() -> void:
	var fixture := _find_fixture(LEECH)
	if fixture.is_empty():
		_check(false, "tampered receipt fixture available")
		return
	app = (load(APP_SCENE) as PackedScene).instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = int(fixture["seed"])
	await _click(app.base_button)
	await _click(_path_button("bloodline"))
	await _click(app.base_screen.set_out_button)
	PartyChoice.choose(app)  # Cycle 345: Set out first asks for the party.
	await _frames()
	_check(app.run_seamstress_path_receipt["ok"] == true, "the genuine receipt was committed before tampering")
	app.run_seamstress_path_receipt["card"]["effects"]["bleed"] = 99
	await _click(_route_button(String(fixture["node_id"])))
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	var total: int = app.deck.draw_pile.size() + app.deck.hand.size() + app.deck.discard_pile.size()
	_check(total == 12 and not app.deck.hand.has(LEECH) and not app.deck.draw_pile.has(LEECH),
		"a tampered receipt adds no Path card to the routed battle")
	_check(presenter._path_cards == null and presenter.path_preview(LEECH).get("playable") == false,
		"a tampered receipt binds no Path resolver")
	_check(not app.run_deck.has(LEECH), "the tampered receipt never reaches the run ledger")
	await _dispose()


## Held-card rejections, a duplicate copy, a lost copy and a battle teardown all
## stay fail-closed and transaction-free.
func _stale_case(card_id: String) -> void:
	var path_id := "bloodline" if card_id == LEECH else "unpicker"
	var fixture := _find_fixture(card_id)
	if fixture.is_empty():
		_check(false, "stale fixture available: " + card_id)
		return
	if not await _enter_routed_fight(fixture, path_id, true):
		await _dispose()
		return
	var panel := _panel(card_id)
	_check(panel != null and presenter.path_ready(), "stale case starts from a genuine held Path card")
	if panel == null:
		await _dispose()
		return

	# Untargeted energy: no legal slot, no spend.
	app.deck.combat_state.energy = 0
	await _frames()
	var before := _snapshot()
	await _click(panel)
	_check(presenter._armed == null and _snapshot() == before,
		"an unaffordable Path card cannot even arm: " + card_id)
	_check(presenter.path_preview(card_id).get("playable") == false
		and metadata.visual_state(panel).get("playable") == false
		and panel.self_modulate != Color.WHITE,
		"an unaffordable Path card is honestly dimmed: " + card_id)
	app.deck.combat_state.energy = 3
	await _frames()
	_check(presenter.path_preview(card_id).get("playable") == true,
		"restoring energy re-enables the same held card: " + card_id)

	# A forged duplicate copy is not a playable Path card.
	app.deck.discard_pile.append(card_id)
	await _frames()
	before = _snapshot()
	_check(not presenter.path_ready() and presenter.path_preview(card_id).get("playable") == false,
		"a duplicate Path copy fails the resolver lineage: " + card_id)
	await _click(panel)
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	_check(_snapshot() == before and presenter.last_event.is_empty()
		and presenter._armed == null,
		"a duplicate-copy Path card cannot arm, spend or discard: " + card_id)
	app.deck.discard_pile.erase(card_id)
	await _frames()

	# A lost copy (the held card moved away) stays unplayable and mutates nothing.
	app.deck.hand.erase(card_id)
	app.deck.draw_pile.append(card_id)
	app._refresh_hand()
	await _frames()
	before = _snapshot()
	_check(_panel(card_id) == null and presenter.path_preview(card_id).get("playable") == false,
		"an unheld Path card is not previewed as legal: " + card_id)
	presenter._queue_attack(1)
	await _frames()
	_check(_snapshot() == before, "an unheld Path card cannot spend or discard: " + card_id)
	app.deck.draw_pile.erase(card_id)
	app.deck.hand.append(card_id)
	app._refresh_hand()
	await _frames()

	# Return retires the battle binding and every receipt with the run.
	await _click(app.return_button)
	await _frames()
	_check(presenter._path_cards == null and presenter._path_card.is_empty()
		and presenter.path_preview(card_id).get("playable") == false,
		"Return clears the battle-bound Path resolver: " + card_id)
	_check(app.title_view.is_visible_in_tree() and app.deck == null
		and app.run_seamstress_path_receipt.is_empty() and app.run_seamstress_path_choice == null,
		"Return leaves a fresh title with no Path receipt: " + card_id)
	await _dispose()


## Both authored Paths together: the chosen card for this run's seed is dealt,
## and the other Path card is never injected.
func _choices_are_exclusive() -> void:
	var fixture := _find_fixture(LEECH)
	if fixture.is_empty():
		_check(false, "exclusivity fixture available")
		return
	if not await _enter_routed_fight(fixture, "bloodline", true):
		await _dispose()
		return
	_check(app.deck.hand.count(LEECH) + app.deck.draw_pile.count(LEECH)
		+ app.deck.discard_pile.count(LEECH) == 1
		and app.deck.hand.count(FRAY) + app.deck.draw_pile.count(FRAY)
		+ app.deck.discard_pile.count(FRAY) == 0,
		"Bloodline deals Leech Stitch once and never Fray")
	_check(presenter.path_preview(FRAY).get("playable") == false
		and presenter._definition(FRAY).is_empty(),
		"the unselected Path card has no battle rules at all")
	await _dispose()


## A seeded opening whose first Fight is followed by another Fight, so the same
## run can prove the injection is reproduced per new routed fight.
func _fight_chain_fixture(card_id: String) -> Dictionary:
	for seed_value in range(1, 80):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var run_map := RunMap.new()
		run_map.generate(rng)
		for node_id in run_map.get_legal_choices():
			if run_map.get_node(node_id).get("type") != "Fight":
				continue
			var next_fights: Array[String] = []
			for next_id in run_map.get_node(node_id).get("outgoing", []):
				var next_node = run_map.get_node(String(next_id))
				if next_node is Dictionary and next_node.get("type") == "Fight":
					next_fights.append(String(next_id))
			if next_fights.is_empty():
				continue
			var oracle := _oracle(seed_value, String(node_id), card_id)
			if oracle.is_empty() or not (oracle["hand"] as Array).has(card_id):
				continue
			oracle["seed"] = seed_value
			oracle["node_id"] = String(node_id)
			oracle["second"] = next_fights[0]
			return oracle
	return {}


## The receipt survives a real victory and reward, and the NEXT routed Fight is
## admitted with its own single Path card while the run ledger stays twelve.
func _second_fight_case() -> void:
	var card_id := LEECH
	var fixture := _fight_chain_fixture(card_id)
	_check(not fixture.is_empty(), "a seeded opening offers two connected Fights")
	if fixture.is_empty():
		return
	if not await _enter_routed_fight(fixture, "bloodline", true):
		await _dispose()
		return
	_check_deck(card_id, fixture)
	for enemy in app.enemies.get_enemies():
		app.enemies.apply_damage(int(enemy.get("position", 0)), 9999)
	app._observe_battle_result()
	await _frames()
	_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and app.reward_buttons.size() == 4,
		"the first routed Fight resolves into its real reward")
	if app.reward_buttons.size() != 4:
		await _dispose()
		return
	app.reward_buttons[3].pressed.emit()
	await _frames()
	_check(is_instance_valid(app.continue_button) and not app.continue_button.disabled,
		"the settled reward offers its real Continue action")
	if not is_instance_valid(app.continue_button):
		await _dispose()
		return
	app.continue_button.pressed.emit()
	await _frames()
	var second := _route_button(String(fixture["second"]))
	_check(second != null and not second.disabled, "the connected route offers the second Fight")
	if second == null:
		await _dispose()
		return
	await _click(second)
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	metadata = app.get_node("LiveSupportHand")._metadata
	var total: int = app.deck.draw_pile.size() + app.deck.hand.size() + app.deck.discard_pile.size()
	var copies: int = app.deck.draw_pile.count(card_id) + app.deck.hand.count(card_id) \
		+ app.deck.discard_pile.count(card_id)
	_check(not app.run_seamstress_path_receipt.is_empty()
		and app.run_seamstress_path_receipt["path_id"] == "bloodline",
		"the Path receipt survives a real victory and reward")
	_check(total == 13 and copies == 1 and app.deck.hand.count(FRAY) == 0
		and app.deck.draw_pile.count(FRAY) == 0 and app.deck.discard_pile.count(FRAY) == 0,
		"the second routed Fight gets its own one Path card: " + card_id)
	_check(app.run_deck.size() == 12 and not app.run_deck.has(card_id),
		"the run ledger still never stores the Path card")
	_check(presenter.path_ready() and String(presenter._path_card.get("id", "")) == card_id,
		"the new battle binds a fresh genuine Path resolver: " + card_id)
	await _dispose()


func _dispose() -> void:
	if is_instance_valid(app):
		app.free()
	await _frames()
	app = null
	presenter = null
	metadata = null


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load(APP_SCENE) as PackedScene
	_check(scene != null, "the real app scene loads")
	if scene == null:
		_finish()
		return
	# Only the authored catalog may define these two IDs; no new entry point.
	var starter := StarterCards.new()
	var pool := SeamstressPoolCards.new()
	for card_id in [LEECH, FRAY]:
		_check(not starter.has_card(card_id) and not pool.has_card(card_id),
			"the Path card stays outside the reward/starter catalogs: " + card_id)
	await _play_case(LEECH, true)
	await _play_case(FRAY, false)
	await _unselected_case()
	await _tampered_receipt_case()
	await _stale_case(LEECH)
	await _stale_case(FRAY)
	await _choices_are_exclusive()
	await _second_fight_case()
	_finish()


func _finish() -> void:
	for message in failures:
		printerr("FAIL: " + message)
	print("live_seamstress_path_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
