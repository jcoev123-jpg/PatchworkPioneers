extends SceneTree
## Cycle 169: both authored Tinker Paths chosen in the Quilt village are really
## live in a routed Fight.
##
## Every case starts at the real title, opens the real village, confirms one or
## both authored Path picks with the mouse or the keyboard, sets out through the
## real opening book and enters a Fight through its real route button. The one
## battle deck, the seeded replay, the mounted hand face, the real mouse/keyboard
## commits, the Path authority's per-turn boundaries and every rejection are then
## checked against independent oracles and the authored data.

const APP_SCENE := "res://scenes/app.tscn"
const TINKER_PATHS := "res://data/heroes/tinker_paths.json"
const SEAMSTRESS_PATHS := "res://data/heroes/seamstress_paths.json"
const SCOPE := "tinker_scope"
const WIND_UP := "tinker_wind_up"
const POP_SHOT := "tinker_pop_shot"
const SCRAP_BOMB := "tinker_scrap_bomb"

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
	_check(root.get_visible_rect().has_point(point), "mouse target is inside the viewport")
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


## The Path authority's own state plus the shared first-attack latch every Tinker
## resolver reads: a cast or a preview may change none of it.
func _tinker_state() -> Array:
	if presenter == null or presenter._tinker_path == null:
		return []
	var rules: CombatTinkerPathRules = presenter._tinker_path.get_rules()
	return [rules._path_id, rules._turn_active, rules._scope_armed,
		rules._clockwork_used, rules._pending_energy, rules._ready_energy,
		presenter._tinker_path._active,
		presenter._play._tinker._consumed, presenter._play._tinker.path_bonus()]


## Everything a cast may touch. Both run receipts are read detached.
func _snapshot() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state,
		app.deck._rng.state, app.enemy_intents.get_intents(),
		app.enemy_intents._turn_index, app.battle_result.get_outcome(),
		_tinker_state(), app.session_gold, app.run_scraps, app._battle_closed,
		app.run_deck.duplicate(), app.run_tinker_path_receipt.duplicate(true),
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


func _authored_path(paths_path: String, path_id: String) -> Dictionary:
	if not FileAccess.file_exists(paths_path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(paths_path)) != OK:
		return {}
	var listed: Variant = parser.data
	if listed is Dictionary:
		listed = (listed as Dictionary).get("paths")
	if not listed is Array:
		return {}
	for record in listed:
		if record is Dictionary and String(record.get("id", "")) == path_id:
			return _norm(record)
	return {}


func _tinker_card(path_id: String) -> Dictionary:
	var record := _authored_path(TINKER_PATHS, path_id)
	var card: Variant = record.get("card")
	return card if card is Dictionary else {}


## The exact canonical admitted deck plus the selected Path cards, from the same
## ledger admission and one shuffle the app performs.
func _oracle(seed_value: int, node_id: String, path_cards: Array) -> Dictionary:
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
		"enemy_count": entry["enemies"].get_enemies().size(),
		"twelve_hand": twelve.hand.duplicate(), "twelve_draw": twelve.draw_pile.duplicate(),
		"twelve_rng": rng.state, "hand": twelve.hand.duplicate(),
		"draw": twelve.draw_pile.duplicate(), "rng_state": rng.state}
	if path_cards.is_empty():
		return result
	rng.state = state_before
	var ids: Array[String] = []
	ids.assign(snapshot.deck)
	for card_id in path_cards:
		ids.append(String(card_id))
	var deal := CombatDeck.new(ids, rng)
	var path_intents := CombatEnemyIntents.new(entry.intents._definitions)
	_check(path_intents.bind_battle(entry.enemies, party, rng),
		"independent Path deck shuffle is followed by cached weighted intentions")
	if not deal.start_turn():
		return {}
	result["hand"] = deal.hand.duplicate()
	result["draw"] = deal.draw_pile.duplicate()
	result["rng_state"] = rng.state
	return result


## The first seed whose opening Fight really deals every required card into the
## first hand. Nothing is special-cased: it is the same map, entry, ledger
## admission and single shuffle the app performs.
func _find_fixture(path_cards: Array, required_hand: Array, min_enemies: int = 0) -> Dictionary:
	# A repeated ID means "this many held copies", so a fixture can require the two
	# authored Pop Shots rather than merely one.
	var needed := {}
	for card_id in required_hand:
		needed[card_id] = int(needed.get(card_id, 0)) + 1
	for seed_value in range(1, 200):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var run_map := RunMap.new()
		run_map.generate(rng)
		for node_id in run_map.get_legal_choices():
			if run_map.get_node(node_id).get("type") != "Fight":
				continue
			var oracle := _oracle(seed_value, String(node_id), path_cards)
			if oracle.is_empty() or int(oracle.get("enemy_count", 0)) < min_enemies:
				continue
			var missing := false
			for card_id in needed:
				if (oracle["hand"] as Array).count(card_id) < int(needed[card_id]):
					missing = true
			if missing:
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


func _tinker_button(path_id: String) -> Button:
	if not is_instance_valid(app.base_screen):
		return null
	for button in app.base_screen.tinker_buttons:
		if is_instance_valid(button) and String(button.get_meta("path_id", "")) == path_id:
			return button
	return null


func _seamstress_button(path_id: String) -> Button:
	if not is_instance_valid(app.base_screen):
		return null
	for button in app.base_screen.path_buttons:
		if is_instance_valid(button) and String(button.get_meta("path_id", "")) == path_id:
			return button
	return null


## Real title -> real village -> one authored Tinker Path (by mouse or keyboard)
## -> real opening book -> the real routed Fight.
func _enter_routed_fight(fixture: Dictionary, path_id: String, use_mouse: bool,
		seamstress_id: String = "") -> bool:
	app = (load(APP_SCENE) as PackedScene).instantiate()
	root.add_child(app)
	await _frames()
	_check(app.deck == null and app.run_map == null and app.title_view.is_visible_in_tree()
		and app.run_tinker_path_receipt.is_empty(),
		"case starts from the real title with no battle or Tinker receipt: " + path_id)
	app.run_seed = int(fixture["seed"])
	await _click(app.base_button)
	_check(is_instance_valid(app.base_screen) and app.base_screen.has_open_village(),
		"the real Quilt village opens: " + path_id)
	if not is_instance_valid(app.base_screen):
		return false
	var view: BaseScreen = app.base_screen
	_check(view.tinker_path_options().size() == 2 and view.path_options().size() == 2,
		"the village offers both Tinker Paths beside the Seamstress board")
	var target := _tinker_button(path_id)
	_check(target != null and not target.disabled,
		"the authored Tinker Path option is offered: " + path_id)
	if target == null:
		return false
	if use_mouse:
		await _click(target)
	else:
		for attempt in range(view.path_buttons.size() + view.tinker_buttons.size() + 6):
			if target.has_focus():
				break
			await _key(KEY_TAB)
		_check(target.has_focus(), "physical Tab reaches the Tinker Path option: " + path_id)
		await _key(KEY_ENTER)
	_check(view.selected_tinker_path_id() == path_id,
		"the village confirms the selected Tinker Path: " + path_id)
	if not seamstress_id.is_empty():
		await _click(_seamstress_button(seamstress_id))
		_check(view.selected_path_id() == seamstress_id,
			"the independent Seamstress board still confirms its own pick")
	await _click(view.set_out_button)
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


## The selected Path card is exactly once in the expanded battle deck while the
## stitchable run ledger stays the authored twelve.
func _check_deck(path_id: String, card_id: String, other_id: String, fixture: Dictionary,
		card_count: int = 1) -> void:
	var total: int = app.deck.draw_pile.size() + app.deck.hand.size() + app.deck.discard_pile.size()
	var copies: int = app.deck.draw_pile.count(card_id) + app.deck.hand.count(card_id) \
		+ app.deck.discard_pile.count(card_id)
	var other_copies: int = app.deck.draw_pile.count(other_id) + app.deck.hand.count(other_id) \
		+ app.deck.discard_pile.count(other_id)
	_check(total == 12 + card_count, "the battle deck holds the twelve cards plus its Path cards: " + path_id)
	_check(copies == 1, "the selected Tinker Path card is dealt exactly once: " + path_id)
	_check(other_copies == 0, "the other Tinker Path card never enters this battle: " + path_id)
	_check(app.run_deck.size() == 12 and not app.run_deck.has(card_id),
		"the stitchable run ledger stays the twelve authored cards: " + path_id)
	_check(app.deck.hand == fixture["hand"] and app.deck.draw_pile == fixture["draw"],
		"the dealt hand is the independent seeded deck oracle: " + path_id)
	_check(app.run_rng.state == int(fixture["rng_state"]),
		"one shuffle of the expanded deck is the recorded run RNG state: " + path_id)
	_check(app.encounter_id == String(fixture["encounter_id"]),
		"the battle is the fixture encounter: " + path_id)
	_check(_hand_ids() == app.deck.hand, "the mounted hand is the authoritative dealt hand: " + path_id)
	_check(_panel(card_id) != null and _panel(card_id).is_visible_in_tree(),
		"the Tinker Path card is a real visible hand panel: " + path_id)


## Both receipts are detached run records; the Path cards stay out of the run deck.
func _check_receipts(path_id: String, card_id: String) -> void:
	var receipt: Dictionary = app.run_tinker_path_receipt
	_check(bool(receipt.get("ok", false)) and String(receipt.get("path_id", "")) == path_id
		and String(receipt.get("card_id", "")) == card_id
		and String(receipt.get("passive_id", "")) == String(_authored_path(TINKER_PATHS, path_id).get("passive_id", "")),
		"the run carries the validated Tinker receipt: " + path_id)
	_check((receipt.get("deck", []) as Array).size() == 13
		and String((receipt.get("deck", []) as Array)[12]) == card_id,
		"the proposed thirteenth card stays inside the receipt: " + path_id)
	_check(app.run_tinker_path_choice != null and app.run_tinker_path_choice.has_selection()
		and String(app.run_tinker_path_choice.get_selection().get("card_id", "")) == card_id,
		"the claimed setup is kept for the whole run: " + path_id)
	_check(app._quilt_owners_of(card_id) == ["tinker"],
		"the validated receipt names the Tinker as the Path card's owner: " + path_id)
	_check(app._quilt_owners_of(other_path_card(path_id)) == [],
		"the unselected Path card earns no owner: " + path_id)


func other_path_card(path_id: String) -> String:
	return WIND_UP if path_id == "sharpshot" else SCOPE


## The Path authority really bound to this battle, this deck and this turn.
func _check_authority(path_id: String, card_id: String) -> void:
	var hand: CombatTinkerPathHand = presenter._tinker_path
	_check(hand != null and hand.is_bound(), "the battle binds one genuine Tinker Path authority: " + path_id)
	if hand == null:
		return
	_check(hand.deck == app.deck and hand.party == app.party,
		"the authority is bound to this real deck and party: " + path_id)
	_check(String(hand.get_rules()._path_id) == path_id,
		"the authority is the selected Path: " + path_id)
	_check(hand.get_rules()._turn_active and presenter._tinker_path._active,
		"the authority adopted the already-open player turn: " + path_id)
	_check(String(hand._selected_card.get("id", "")) == card_id,
		"the authority authenticates the authored Path card: " + path_id)
	_check(presenter.tinker_ready() and presenter.tinker_path_is_card(card_id)
		and presenter.tinker_path_playable(card_id),
		"the held genuine Path card is admitted: " + path_id)
	_check(not presenter.tinker_path_is_card(other_path_card(path_id)),
		"the other Path card is never admitted: " + path_id)


func _check_face(path_id: String, card_id: String) -> void:
	var authored := _tinker_card(path_id)
	var panel := _panel(card_id)
	var facts: Dictionary = metadata.describe(card_id)
	_check(facts.get("known") == true and facts.get("display_name") == authored.get("display_name"),
		"the Tinker Path card face names its authored record: " + card_id)
	_check(int(facts.get("cost", -1)) == int(authored.get("cost", -2)),
		"the face shows the authored cost: " + card_id)
	_check(String(facts.get("owner_text", "")) == "Tinker",
		"the face is owned by the Tinker: " + card_id)
	var face_text: String = metadata.base_effect_text(card_id)
	if card_id == SCOPE:
		_check(face_text.contains("+4 damage") and face_text.contains("this turn"),
			"the tooltip describes the authored +4 next attack this turn: " + card_id)
	else:
		_check(face_text.contains("gain 1 energy on your next turn"),
			"the tooltip describes the authored next-turn energy: " + card_id)
	_check(not face_text.contains("not described"),
		"the face interprets every authored effect key: " + card_id)
	var faces: Dictionary = metadata.face_assets(card_id)
	_check(String(faces.get("frame_path", "")).ends_with("card_frame_tinker.png"),
		"the face keeps the Tinker felt frame: " + card_id)
	_check(panel != null and panel.tooltip_text.contains(String(authored.get("display_name", ""))),
		"the mounted panel carries the authored tooltip: " + card_id)
	_check(not metadata.get_geometry(panel).is_empty(),
		"the Tinker Path card draws a real face layout: " + card_id)
	_check(panel != null and panel.gui_input.get_connections().size() == 1,
		"the held Path panel owns exactly one real input handler: " + card_id)
	_check(metadata.visual_state(panel).get("playable") == true
		and panel.self_modulate == Color.WHITE,
		"a legal Tinker Path card is drawn enabled, not dimmed: " + card_id)


## One real mouse or keyboard commit of the target-free Path card, with the
## authority revalidating metadata, position, turn and energy.
func _cast_path_card(card_id: String, use_mouse: bool) -> void:
	var panel := _panel(card_id)
	if use_mouse:
		await _click(panel)
	else:
		panel.grab_focus()
		await _key(KEY_ENTER)


func _play_path_card(card_id: String, path_id: String, use_mouse: bool,
		armed_total: int = 7) -> void:
	var panel := _panel(card_id)
	_check(panel != null and panel.get_index() == app.deck.hand.find(card_id),
		"the Path panel sits at its authoritative hand slot: " + card_id)
	if panel == null:
		return
	var before := _snapshot()
	await _hover(panel)
	_check(_snapshot() == before, "previewing a Tinker Path card never mutates the battle: " + card_id)
	var quote: Dictionary = presenter.tinker_path_quote(card_id)
	_check(bool(quote.get("ok", false))
		and int(quote.get("cost", -1)) == int(_tinker_card(path_id).get("cost", -2)),
		"the authority quotes the authored cost from a genuine held copy: " + card_id)
	var energy_before: int = app.deck.energy
	var discard_before: int = app.deck.discard_pile.size()
	var rng_before: int = app.run_rng.state
	await _cast_path_card(card_id, use_mouse)
	# The pile must gain exactly this one committed copy; a prior discard of another
	# card in the same turn must not be mistaken for the Path card's own slot.
	_check(not app.deck.hand.has(card_id)
		and app.deck.discard_pile.size() == discard_before + 1
		and app.deck.discard_pile.count(card_id) == 1,
		"exactly one held Path copy is committed to the discard: " + card_id)
	_check(app.run_rng.state == rng_before and app.deck._rng.state == rng_before,
		"the Path cast never advances the seeded run RNG: " + card_id)
	var rules: CombatTinkerPathRules = presenter._tinker_path.get_rules()
	if card_id == SCOPE:
		_check(app.deck.energy == energy_before,
			"Scope spends its authored zero energy: " + card_id)
		_check(rules._scope_armed and presenter._play._tinker.path_bonus() == 4,
			"the confirmed Scope arms its exact +4 on the shared Tinker latch")
		_check(presenter._play._tinker.bonus_for_attack(POP_SHOT) == armed_total,
			"the next Tinker attack projects exactly the armed bonus (%d)" % armed_total)
	else:
		_check(app.deck.energy == energy_before - 1,
			"Wind-up spends exactly its authored one energy: " + card_id)
		_check(rules._pending_energy == 1 and rules._ready_energy == 0
			and not rules._clockwork_used,
			"Wind-up queues one future credit and consumes no Clockwork discount")
		_check(app.deck.energy == 2, "the live energy really dropped to two: " + card_id)
	var quilt: Dictionary = app._quilt_bonus.get_patch_progress()
	_check(quilt.get("patches", {}).get("tinker", {}).get("played") == true,
		"the confirmed Path play credits its real owner for the Quilt: " + card_id)
	_check(_hand_ids() == app.deck.hand
		and app.pile_label.text == "Draw: %d | Discard: %d" % [
			app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		"the mounted hand and piles refresh after the Path cast: " + card_id)


## The real first Tinker attack of the turn lands with the exact projected bonus.
func _cast_attack(card_id: String, use_mouse: bool, position: int = 1) -> void:
	var keys: Array[Key] = [KEY_1, KEY_2, KEY_3]
	if use_mouse:
		await _click(_panel(card_id))
		_check(presenter._card_id(presenter._armed) == card_id,
			"a real mouse press arms the Tinker attack: " + card_id)
		await _click(app.get_node("LiveEnemyRoster")._labels[position - 1])
	else:
		for attempt in range(CombatEnemies.MAX_ENEMIES + 9):
			await _key(KEY_P)
			if presenter._card_id(presenter._armed) == card_id:
				break
		_check(presenter._card_id(presenter._armed) == card_id,
			"real input arms the Tinker attack: " + card_id)
		await _key(keys[position - 1])


func _hover_attack(card_id: String) -> String:
	var panel := _panel(card_id)
	if panel == null:
		return ""
	await _hover(panel)
	return presenter.cue.text


func _scope_case(use_mouse: bool) -> void:
	var path_id := "sharpshot"
	var fixture := _find_fixture([SCOPE], [SCOPE, POP_SHOT])
	_check(not fixture.is_empty(), "an opening Fight really deals Scope and a Tinker attack")
	if fixture.is_empty():
		return
	if not await _enter_routed_fight(fixture, path_id, use_mouse):
		await _dispose()
		return
	_check_receipts(path_id, SCOPE)
	_check_deck(path_id, SCOPE, WIND_UP, fixture)
	_check_authority(path_id, SCOPE)
	_check_face(path_id, SCOPE)
	await _play_path_card(SCOPE, path_id, use_mouse)
	var armed := _snapshot()
	await _hover_attack(POP_SHOT)
	_check(_snapshot() == armed, "hovering an attack never spends the armed Scope")
	_check(presenter.cue.text.contains("1: %d damage" % 12),
		"the live forecast shows 5 printed +3 Sharpshot +4 Scope = 12 damage")
	var enemy_before: Dictionary = app.enemies.get_enemy(1)
	var energy_before: int = app.deck.energy
	await _cast_attack(POP_SHOT, not use_mouse)
	_check(presenter.last_event.get("ok", false), "the committed Tinker attack reported success")
	_check(app.deck.energy == energy_before - 1,
		"the attack spends exactly its authored one energy")
	_check(app.enemies.get_enemy(1).get("hp", 0) == int(enemy_before.get("hp", 0)) - 12,
		"the first Tinker attack really deals the full 12 damage")
	var rules: CombatTinkerPathRules = presenter._tinker_path.get_rules()
	_check(presenter._play._tinker._consumed and presenter._play._tinker.path_bonus() == 0
		and not rules._scope_armed,
		"the confirmed first hit consumes Sharpshot and Scope exactly once")
	_check(int(rules.preview(POP_SHOT, int(presenter._tinker_position()),
		int(presenter._tinker_hero().get("hp", 0)), app.deck.energy).get("damage_bonus", -1)) == 0,
		"the battle's Path authority records no remaining first-hit bonus")
	var after := _snapshot()
	await _key(KEY_1)
	_check(_snapshot() == after, "the consumed Scope cannot be spent twice")
	await _dispose()
	# The same seed and pick replayed on the opposite input device is identical.
	if not await _enter_routed_fight(fixture, path_id, not use_mouse):
		await _dispose()
		return
	await _play_path_card(SCOPE, path_id, not use_mouse)
	await _cast_attack(POP_SHOT, use_mouse)
	_check(_snapshot() == after,
		"the opposite input device replays the identical committed battle")
	await _dispose()


## A held Scope played AFTER this turn's first Tinker hit still grants its exact
## authored +4 to the next attack, the forecast matches the real damage, and the
## next turn owes only the native +3.
func _scope_after_first_hit_case(use_mouse: bool) -> void:
	var path_id := "sharpshot"
	var fixture := _find_fixture([SCOPE], [SCOPE, POP_SHOT, POP_SHOT], 2)
	_check(not fixture.is_empty(),
		"an opening Fight really deals Scope and two Tinker attacks in one hand")
	if fixture.is_empty():
		return
	if not await _enter_routed_fight(fixture, path_id, use_mouse):
		await _dispose()
		return
	_check_deck(path_id, SCOPE, WIND_UP, fixture)
	_check_authority(path_id, SCOPE)
	var rules: CombatTinkerPathRules = presenter._tinker_path.get_rules()
	var position: int = presenter._tinker_position()
	var tinker_hp: int = int(presenter._tinker_hero().get("hp", 0))
	var first_enemy: Dictionary = app.enemies.get_enemy(1)
	var second_enemy: Dictionary = app.enemies.get_enemy(2)
	_check(not first_enemy.is_empty() and not second_enemy.is_empty()
		and int(second_enemy.get("hp", 0)) > 9,
		"the fixture Fight really fields a second enemy that survives the later hit")
	if first_enemy.is_empty() or int(second_enemy.get("hp", 0)) <= 9:
		await _dispose()
		return
	# The turn's first confirmed Tinker hit spends ONLY the native Sharpshot +3.
	await _cast_attack(POP_SHOT, not use_mouse, 1)
	_check(presenter.last_event.get("ok", false)
		and int(app.enemies.get_enemy(1).get("hp", 0)) == int(first_enemy.get("hp", 0)) - 8,
		"the turn's first Tinker hit deals printed 5 + native 3 = 8")
	_check(presenter._play._tinker._consumed and presenter._play._tinker.path_bonus() == 0
		and not rules._scope_armed
		and int(rules.preview(POP_SHOT, position, tinker_hp, app.deck.energy).get("damage_bonus", -1)) == 0,
		"the native first-hit +3 is already spent before the held Scope is cast")
	var second_before: Dictionary = app.enemies.get_enemy(2)
	var discard_before: int = app.deck.discard_pile.size()
	# The same still-held Scope now arms the NEXT attack despite that spent latch.
	await _play_path_card(SCOPE, path_id, not use_mouse, 4)
	var armed_quote: Dictionary = rules.preview(POP_SHOT, position, tinker_hp, app.deck.energy)
	_check(rules._scope_armed and presenter._play._tinker.path_bonus() == 4
		and int(armed_quote.get("scope_bonus", -1)) == 4
		and int(armed_quote.get("damage_bonus", -1)) == 4,
		"Scope cast after the first hit still arms exactly its authored +4")
	var before := _snapshot()
	var cue := await _hover_attack(POP_SHOT)
	_check(cue.contains("2: 9 damage"),
		"the live forecast shows printed 5 + Scope 4 = 9 damage, never +7")
	_check(_snapshot() == before, "the Scope-only forecast spends and mutates nothing")
	var rng_before: int = app.run_rng.state
	await _cast_attack(POP_SHOT, use_mouse, 2)
	_check(presenter.last_event.get("ok", false), "the second Tinker hit reported success")
	var hit: Dictionary = presenter.last_event.get("hits", [{}])[0]
	_check(int(hit.get("position", 0)) == 2
		and int(hit.get("damage", -1)) == 9
		and int(app.enemies.get_enemy(2).get("hp", 0)) == int(second_before.get("hp", 0)) - 9,
		"the second hit really deals printed 5 + Scope 4 = 9, never +7")
	_check(app.deck.discard_pile.size() == discard_before + 2
		and app.run_rng.state == rng_before and app.deck._rng.state == rng_before,
		"the second hit spends exactly its own card and no seeded RNG")
	_check(presenter._play._tinker._consumed and presenter._play._tinker.path_bonus() == 0
		and not rules._scope_armed,
		"the armed +4 is spent exactly once with that confirmed hit")
	_check(presenter._play._tinker.bonus_for_attack(POP_SHOT) == 0
		and presenter._play._tinker.bonus_for_attack(SCRAP_BOMB) == 0
		and int(rules.preview(SCRAP_BOMB, position, tinker_hp, 3).get("damage_bonus", -1)) == 0,
		"a later hit in the same turn gets neither stale +4 nor another +3")
	var spent := _snapshot()
	await _key(KEY_1)
	_check(_snapshot() == spent, "the spent Scope bonus cannot be spent twice")
	# The next real player turn restores only the native +3.
	var turn_before: int = app.enemy_intents._turn_index
	await _click(app.end_turn_button)
	await _frames()
	_check(app.enemy_intents._turn_index == turn_before + 1 and app.deck.turn_active,
		"the real End Turn opens the next genuine player turn")
	var next_quote: Dictionary = rules.preview(POP_SHOT, int(presenter._tinker_position()),
		int(presenter._tinker_hero().get("hp", 0)), app.deck.energy)
	_check(not rules._scope_armed and presenter._play._tinker.path_bonus() == 0
		and not presenter._play._tinker._consumed
		and int(next_quote.get("damage_bonus", -1)) == 3
		and presenter._play._tinker.bonus_for_attack(POP_SHOT) == 3,
		"the next turn owes only the native Sharpshot +3, never a stale +4")
	await _dispose()


## A held Scope that is never spent expires at the real end of turn.
func _scope_expiry_case() -> void:
	var path_id := "sharpshot"
	var fixture := _find_fixture([SCOPE], [SCOPE])
	_check(not fixture.is_empty(), "an opening Fight deals Scope for the expiry case")
	if fixture.is_empty():
		return
	if not await _enter_routed_fight(fixture, path_id, true):
		await _dispose()
		return
	await _play_path_card(SCOPE, path_id, true)
	var rules: CombatTinkerPathRules = presenter._tinker_path.get_rules()
	_check(rules._scope_armed and presenter._play._tinker.path_bonus() == 4,
		"the unspent Scope is armed before the turn ends")
	var turn_before: int = app.enemy_intents._turn_index
	await _click(app.end_turn_button)
	await _frames()
	_check(app.enemy_intents._turn_index == turn_before + 1 and app.deck.turn_active,
		"the real End Turn opens the next genuine player turn")
	_check(not rules._scope_armed and presenter._play._tinker.path_bonus() == 0
		and not presenter._play._tinker._consumed,
		"the unspent Scope expired and a fresh first hit is available")
	_check(int(rules.preview(POP_SHOT, int(presenter._tinker_position()),
		int(presenter._tinker_hero().get("hp", 0)), app.deck.energy).get("damage_bonus", -1)) == 3,
		"the next turn projects only the native Sharpshot +3")
	await _dispose()


func _clockwork_case(use_mouse: bool) -> void:
	var path_id := "clockwork"
	var fixture := _find_fixture([WIND_UP], [WIND_UP, SCRAP_BOMB])
	_check(not fixture.is_empty(),
		"an opening Fight really deals Wind-up and the qualifying two-cost card")
	if fixture.is_empty():
		return
	if not await _enter_routed_fight(fixture, path_id, use_mouse):
		await _dispose()
		return
	_check_receipts(path_id, WIND_UP)
	_check_deck(path_id, WIND_UP, SCOPE, fixture)
	_check_authority(path_id, WIND_UP)
	_check_face(path_id, WIND_UP)
	await _play_path_card(WIND_UP, path_id, use_mouse)
	var rules: CombatTinkerPathRules = presenter._tinker_path.get_rules()
	var position: int = presenter._tinker_position()
	var hp: int = int(presenter._tinker_hero().get("hp", 0))
	_check(int(rules.preview(SCRAP_BOMB, position, hp, app.deck.energy).get("cost", -1)) == 1
		and presenter._play._tinker.bonus_for_attack(SCRAP_BOMB) == 3,
		"Clockwork discounts the qualifying card and the first hit still applies")
	var energy_before: int = app.deck.energy
	var enemy_before: Array = app.enemies.get_enemies().duplicate(true)
	_check(not enemy_before.is_empty(), "the qualifying area cast really has enemies in front of it")
	if use_mouse:
		await _click(_panel(SCRAP_BOMB))
	else:
		for attempt in range(CombatEnemies.MAX_ENEMIES + 9):
			await _key(KEY_P)
			if presenter._card_id(presenter._armed) == SCRAP_BOMB:
				break
		_check(presenter._card_id(presenter._armed) == SCRAP_BOMB,
			"real input arms the qualifying two-cost card")
		await _key(KEY_ENTER)
	_check(presenter.last_event.get("ok", false), "the committed two-cost cast reported success")
	_check(app.deck.energy == energy_before - 1,
		"Clockwork charges exactly one energy less than the printed two")
	_check(rules._clockwork_used,
		"the authority records the one discount of this turn")
	_check(int(rules.preview(SCRAP_BOMB, position, hp, 3).get("discount", -1)) == 0,
		"a second qualifying cast in the same turn is not discounted again")
	for index in range(enemy_before.size()):
		var before: Dictionary = enemy_before[index]
		var after: Dictionary = app.enemies.get_enemy(int(before.get("position", 0)))
		_check(int(after.get("hp", 0)) == int(before.get("hp", 0)) - 7,
			"the two-cost area attack really dealt its 4 printed +3 first-hit damage")
	var turn_before: int = app.enemy_intents._turn_index
	await _click(app.end_turn_button)
	await _frames()
	_check(app.enemy_intents._turn_index == turn_before + 1 and app.deck.turn_active,
		"the real End Turn opens the next genuine player turn")
	_check(app.deck.energy == 4 and app.deck.combat_state.energy == 4,
		"the held Wind-up credits exactly one energy on the next turn")
	_check(rules._pending_energy == 0 and rules._ready_energy == 0,
		"the queued credit is claimed exactly once")
	_check(not rules._clockwork_used,
		"Clockwork's discount is available again on the new turn")
	await _click(app.end_turn_button)
	await _frames()
	_check(app.deck.turn_active and app.deck.energy == 3,
		"the following turn resets to three with no stale credit")
	await _dispose()


## Target-free real commit of one held area card on the requested input device.
func _cast_area_card(card_id: String, use_mouse: bool) -> void:
	var panel := _panel(card_id)
	if use_mouse:
		await _click(panel)
		return
	for attempt in range(CombatEnemies.MAX_ENEMIES + 9):
		await _key(KEY_P)
		if presenter._card_id(presenter._armed) == card_id:
			break
	_check(presenter._card_id(presenter._armed) == card_id,
		"real keyboard input arms the target-free card: " + card_id)
	await _key(KEY_ENTER)


## Clockwork's authored reduction is a REAL price: a printed-cost-2 Tinker attack
## is offered, castable and charged at the single energy the rules quote, while a
## refused cast changes nothing at all.
func _clockwork_one_energy_case(use_mouse: bool) -> void:
	var path_id := "clockwork"
	var fixture := _find_fixture([WIND_UP], [WIND_UP, SCRAP_BOMB, POP_SHOT], 2)
	_check(not fixture.is_empty(),
		"an opening Fight really deals Wind-up, the two-cost card and a spare attack")
	if fixture.is_empty():
		return
	if not await _enter_routed_fight(fixture, path_id, use_mouse):
		await _dispose()
		return
	_check_authority(path_id, WIND_UP)
	await _play_path_card(WIND_UP, path_id, use_mouse)
	var rules: CombatTinkerPathRules = presenter._tinker_path.get_rules()
	var position: int = presenter._tinker_position()
	var hp: int = int(presenter._tinker_hero().get("hp", 0))
	_check(app.deck.energy == 2, "Wind-up leaves the authored two energy")
	# Normal play: the player really has only the discounted one energy left.
	app.deck.combat_state.energy = 1
	await _frames()
	var quote: Dictionary = rules.preview(SCRAP_BOMB, position, hp, app.deck.energy)
	_check(quote.get("ok", false) and int(quote.get("cost", -1)) == 1
		and int(quote.get("printed_cost", -1)) == 2
		and int(quote.get("discount", -1)) == 1,
		"the one Path authority quotes the printed two at one energy")
	_check(presenter.tinker_cost_discount(SCRAP_BOMB) == 1,
		"the mounted authority exposes that same one-point reduction")
	var panel := _panel(SCRAP_BOMB)
	_check(panel != null and panel.is_visible_in_tree(),
		"the qualifying two-cost Tinker attack is really held")
	if panel == null:
		await _dispose()
		return
	var cue := await _hover_attack(SCRAP_BOMB)
	_check(cue.contains("1: 7 damage"),
		"the live forecast is playable at one energy and shows 4 printed +3")
	_check(cue.contains("Scrap Bomb | 1 energy"),
		"the forecast quotes the one energy the authority will really charge")
	_check(metadata.visual_state(panel).get("playable") == true
		and panel.self_modulate == Color.WHITE,
		"the affordable discounted card is drawn enabled, not dimmed")
	_check(bool(presenter._target_preview(SCRAP_BOMB).get("playable", false)),
		"the live target preview admits the discounted cast at one energy")
	var energy_before: int = app.deck.energy
	var enemy_before: Array = app.enemies.get_enemies().duplicate(true)
	await _cast_area_card(SCRAP_BOMB, use_mouse)
	_check(presenter.last_event.get("ok", false),
		"the discounted cast really succeeded with one energy")
	_check(energy_before == 1 and app.deck.energy == 0,
		"the resolver charged exactly the one discounted energy")
	_check(rules._clockwork_used,
		"the authority records the one discount of this turn")
	for index in range(enemy_before.size()):
		var prior: Dictionary = enemy_before[index]
		var now: Dictionary = app.enemies.get_enemy(int(prior.get("position", 0)))
		_check(int(now.get("hp", 0)) == int(prior.get("hp", 0)) - 7,
			"the discounted cast really dealt its 4 printed +3 first-hit damage")
	var after_cast := _snapshot()
	# No second discount this turn, for a repeat or for another expensive card.
	_check(presenter.tinker_cost_discount(SCRAP_BOMB) == 0
		and presenter.tinker_cost_discount("tinker_long_barrel") == 0,
		"neither a repeat nor a second expensive Tinker card is discounted again")
	_check(int(rules.preview("tinker_long_barrel", position, hp, 3).get("discount", -1)) == 0
		and int(rules.preview(SCRAP_BOMB, position, hp, 3).get("cost", -1)) == 2,
		"the authored rules agree a later expensive card pays its full printed cost")
	# A refused cast changes no pile, HP, energy, rule or RNG state.
	app.deck.combat_state.energy = 0
	await _frames()
	var spare := _panel(POP_SHOT)
	_check(spare != null
		and not bool(presenter._target_preview(POP_SHOT).get("playable", false)),
		"with no energy the spent discount leaves the spare attack unplayable")
	var refused := _snapshot()
	await _click(spare)
	_check(_snapshot() == refused,
		"a refused Tinker cast changes no piles, HP, energy, rules or RNG")
	var resolved: Dictionary = presenter._resolve_attack(
		app.party, app.enemies, SCRAP_BOMB, 0)
	_check(not resolved.get("ok", false) and _snapshot() == refused,
		"the real resolver refuses the spent-discount cast without mutation")
	# The next turn offers the discount again, and Wind-up still credits once.
	app.deck.combat_state.energy = 3
	await _frames()
	var turn_before: int = app.enemy_intents._turn_index
	await _click(app.end_turn_button)
	await _frames()
	_check(app.enemy_intents._turn_index == turn_before + 1 and app.deck.turn_active
		and app.deck.energy == 4,
		"the next turn still claims the held Wind-up credit exactly once")
	_check(not rules._clockwork_used and presenter.tinker_cost_discount(SCRAP_BOMB) == 1,
		"Clockwork's one discount is available again on the new turn")
	await _dispose()
	# The same seed and pick replayed on the other input device lands identically.
	if not await _enter_routed_fight(fixture, path_id, not use_mouse):
		await _dispose()
		return
	await _play_path_card(WIND_UP, path_id, not use_mouse)
	app.deck.combat_state.energy = 1
	await _frames()
	await _cast_area_card(SCRAP_BOMB, not use_mouse)
	_check(_snapshot() == after_cast,
		"the opposite input device replays the identical discounted cast")
	await _dispose()


## The same one-point reduction is honoured and charged by the other live Tinker
## resolvers (direct fire and area), and a reduction outside the authored contract
## is refused atomically. Scene-free, against real catalogs, decks and rosters.
func _discount_thread_case() -> void:
	var party: CombatParty = _scene_party()
	var enemies: CombatEnemies = _scene_enemies()
	_check(party.is_valid() and enemies.is_valid() and party.get_hero(3).get("id") == "tinker",
		"the discount case really has a live Tinker in its authored back slot")
	# Direct fire: printed cost 2 is unplayable at one energy without the discount.
	var first := CombatTinkerFirstAttack.new()
	first.start_player_turn()
	var direct := CombatTinkerPoolAttacks.new(first)
	var deck: CombatDeck = _scene_deck(["tinker_long_barrel"])
	deck.combat_state.energy = 1
	var before := _world(deck, party, enemies, first)
	_check(not direct.play_attack(deck, party, enemies, "tinker_long_barrel", 1, null, 0).get("ok", false)
		and _world(deck, party, enemies, first) == before,
		"a printed-cost-2 direct cast is refused at one energy without mutation")
	var direct_event: Dictionary = direct.play_attack(
		deck, party, enemies, "tinker_long_barrel", 1, null, 1)
	_check(direct_event.get("ok", false) and deck.energy == 0
		and deck.discard_pile == ["tinker_long_barrel"],
		"the direct-fire resolver charges the discounted one energy exactly once")
	_check(int(direct_event.get("hits", [{}])[0].get("damage", -1)) == 15
		and int(enemies.get_enemy(1).get("hp", 0)) == 55,
		"the discounted direct cast really deals its 12 printed +3 first hit")
	# A reduction on a printed-cost-1 card is outside the authored contract.
	var cheap_first := CombatTinkerFirstAttack.new()
	cheap_first.start_player_turn()
	var cheap_deck: CombatDeck = _scene_deck(["tinker_rivet_shot"])
	cheap_deck.combat_state.energy = 1
	var cheap_before := _world(cheap_deck, party, enemies, cheap_first)
	_check(not CombatTinkerPoolAttacks.new(cheap_first).play_attack(
		cheap_deck, party, enemies, "tinker_rivet_shot", 1, null, 1).get("ok", false)
		and _world(cheap_deck, party, enemies, cheap_first) == cheap_before,
		"a reduction on a printed-cost-1 direct cast is refused without mutation")
	# Area: Shrapnel Seam is a printed-cost-2 Tinker area attack.
	var area_first := CombatTinkerFirstAttack.new()
	area_first.start_player_turn()
	var unravel := CombatUnravel.new()
	_check(unravel.bind_roster(enemies, {1: "normal", 2: "normal", 3: "normal"}),
		"the area cast has this roster's one real gauge")
	var area_deck: CombatDeck = _scene_deck(["tinker_shrapnel_seam"])
	area_deck.combat_state.energy = 1
	var area_before := _world(area_deck, party, enemies, area_first)
	var area := CombatTinkerPoolUnravelAttacks.new(area_first, unravel, CombatPinned.new())
	_check(not area.play_attack(area_deck, party, enemies, "tinker_shrapnel_seam", 0,
		unravel, CombatPinned.new()).get("ok", false)
		and _world(area_deck, party, enemies, area_first) == area_before,
		"the printed-cost-2 area cast is refused at one energy without mutation")
	area = CombatTinkerPoolUnravelAttacks.new(area_first, unravel, CombatPinned.new())
	_check(area.set_cost_discount(1), "the area resolver accepts the authored one point")
	var area_event: Dictionary = area.play_attack(area_deck, party, enemies,
		"tinker_shrapnel_seam", 0, unravel, CombatPinned.new())
	_check(area_event.get("ok", false) and area_deck.energy == 0
		and area_deck.discard_pile == ["tinker_shrapnel_seam"],
		"the area resolver charges the discounted one energy exactly once")
	_check(not area.set_cost_discount(2), "an out-of-contract reduction is refused")
	# Support: no authored Tinker support card is expensive, so a reduction there
	# fails closed rather than silently under-charging the battle.
	var support_deck: CombatDeck = _scene_deck(["tinker_tune_up"])
	support_deck.combat_state.energy = 1
	var support_party: CombatParty = _scene_party()
	var support_before := support_party.get_heroes()
	var support := CombatSupportCards.new()
	_check(not support.play_support(support_deck, support_party, {
		"id": "tinker_tune_up", "owner_id": "tinker", "cost": 0,
		"from_positions": [1, 2, 3], "effect": "draw", "amount": 1}, 0, 1)
		and support_deck.energy == 1 and support_deck.hand == ["tinker_tune_up"]
		and support_party.get_heroes() == support_before,
		"a reduction on a printed-cost-0 support card is refused without mutation")
	_check(support.play_support(support_deck, support_party, {
		"id": "tinker_tune_up", "owner_id": "tinker", "cost": 0,
		"from_positions": [1, 2, 3], "effect": "draw", "amount": 1}, 0, 0)
		and support_deck.energy == 1,
		"the same support card still plays at its authored zero cost")


func _scene_party() -> CombatParty:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	var definitions: Array = []
	if raw is Array:
		for id in ["warden", "seamstress", "tinker"]:
			for hero in raw:
				if hero.get("id") == id:
					var definition: Dictionary = hero.duplicate(true)
					definition["max_hp"] = int(hero["max_hp"])
					definitions.append(definition)
	return CombatParty.new(definitions)


func _scene_enemies() -> CombatEnemies:
	return CombatEnemies.new([
		{"id": "foe_1", "max_hp": 70}, {"id": "foe_2", "max_hp": 70},
		{"id": "foe_3", "max_hp": 70}])


func _scene_deck(ids: Array[String]) -> CombatDeck:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var deck := CombatDeck.new(ids, rng)
	_check(deck.start_turn() and deck.hand == ids, "the scene-free deck really holds " + str(ids))
	return deck


## Every pile, energy, roster, latch state and seeded RNG position.
func _world(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		first: CombatTinkerFirstAttack) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(),
		deck.discard_pile.duplicate(), deck.energy, deck.turn_active,
		party.get_heroes(), enemies.get_enemies(), deck._rng.state,
		first._consumed, first.path_bonus()]


## Both Path receipts in one run: two independent cards, two independent
## authorities, one seeded battle deck and an unchanged run ledger.
func _two_paths_case() -> void:
	var fixture := _find_fixture(["seamstress_fray", SCOPE], [])
	_check(not fixture.is_empty(), "a seeded opening Fight accepts both selected Paths")
	if fixture.is_empty():
		return
	if not await _enter_routed_fight(fixture, "sharpshot", true, "unpicker"):
		await _dispose()
		return
	_check(app.run_seamstress_path_receipt.get("path_id", "") == "unpicker"
		and app.run_tinker_path_receipt.get("path_id", "") == "sharpshot",
		"both independent receipts survive into the routed battle")
	var total: int = app.deck.draw_pile.size() + app.deck.hand.size() + app.deck.discard_pile.size()
	_check(total == 14 and app.deck.draw_pile.count(SCOPE) + app.deck.hand.count(SCOPE)
		+ app.deck.discard_pile.count(SCOPE) == 1
		and app.deck.draw_pile.count("seamstress_fray") + app.deck.hand.count("seamstress_fray")
		+ app.deck.discard_pile.count("seamstress_fray") == 1,
		"the one battle deck holds exactly one card from each selected Path")
	_check(app.run_deck.size() == 12 and not app.run_deck.has(SCOPE)
		and not app.run_deck.has("seamstress_fray"),
		"neither Path card reaches the stitchable run ledger")
	_check(app.deck.hand == fixture["hand"] and app.deck.draw_pile == fixture["draw"]
		and app.run_rng.state == int(fixture["rng_state"]),
		"the fourteen-card deal is the independent single-shuffle oracle")
	_check(presenter.path_ready() and presenter.tinker_ready(),
		"both battle Path authorities are bound at once")
	_check(app._quilt_owners_of(SCOPE) == ["tinker"]
		and app._quilt_owners_of("seamstress_fray") == ["seamstress"],
		"each Path card is credited to its own authored owner")
	await _dispose()


## An unselected opening keeps the twelve-card deck, its seeded deal and no
## Tinker admission, card or authority at all.
func _unselected_case() -> void:
	var fixture := _find_fixture([WIND_UP], [WIND_UP])
	_check(not fixture.is_empty(), "unselected fixture: an opening Fight exists")
	if fixture.is_empty():
		return
	var twelve := _oracle(int(fixture["seed"]), String(fixture["node_id"]), [])
	app = (load(APP_SCENE) as PackedScene).instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = int(fixture["seed"])
	await _click(app.route_button)
	await _frames()
	_check(is_instance_valid(app.route_view) and app.run_tinker_path_receipt.is_empty(),
		"a direct opening carries no Tinker receipt")
	await _click(_route_button(String(fixture["node_id"])))
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	metadata = app.get_node("LiveSupportHand")._metadata
	var total: int = app.deck.draw_pile.size() + app.deck.hand.size() + app.deck.discard_pile.size()
	_check(total == 12 and app.deck.hand.count(WIND_UP) == 0
		and app.deck.draw_pile.count(WIND_UP) == 0 and app.deck.hand.count(SCOPE) == 0,
		"an unselected route keeps the twelve authored cards and no Tinker Path card")
	_check(app.deck.hand == twelve["hand"] and app.deck.draw_pile == twelve["draw"]
		and app.run_rng.state == int(twelve["rng_state"]),
		"an unselected route preserves the existing seeded twelve-card replay")
	_check(presenter._tinker_path == null and not presenter.tinker_ready()
		and not presenter.tinker_path_playable(WIND_UP)
		and not presenter.tinker_path_playable(SCOPE),
		"no Tinker Path authority is bound without a genuine receipt")
	await _dispose()


## A tampered Tinker receipt must never add a card, bind an authority or spend.
func _tampered_receipt_case() -> void:
	var fixture := _find_fixture([SCOPE], [SCOPE])
	if fixture.is_empty():
		_check(false, "tampered receipt fixture available")
		return
	app = (load(APP_SCENE) as PackedScene).instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = int(fixture["seed"])
	await _click(app.base_button)
	await _click(_tinker_button("sharpshot"))
	await _click(app.base_screen.set_out_button)
	await _frames()
	_check(bool(app.run_tinker_path_receipt.get("ok", false)),
		"the genuine Tinker receipt was committed before tampering")
	app.run_tinker_path_receipt["card_id"] = WIND_UP
	await _click(_route_button(String(fixture["node_id"])))
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	var total: int = app.deck.draw_pile.size() + app.deck.hand.size() + app.deck.discard_pile.size()
	_check(total == 12 and not app.deck.hand.has(SCOPE) and not app.deck.draw_pile.has(SCOPE),
		"a tampered Tinker receipt adds no Path card to the routed battle")
	_check(presenter._tinker_path == null and not presenter.tinker_ready()
		and not presenter.tinker_path_playable(SCOPE),
		"a tampered receipt binds no Tinker Path authority")
	_check(not app.run_deck.has(SCOPE), "the tampered receipt never reaches the run ledger")
	await _dispose()


## Held-card rejections, forged metadata, a duplicate copy and a battle teardown
## all stay fail-closed and transaction-free.
func _stale_case() -> void:
	var fixture := _find_fixture([WIND_UP], [WIND_UP])
	if fixture.is_empty():
		_check(false, "stale fixture available")
		return
	if not await _enter_routed_fight(fixture, "clockwork", true):
		await _dispose()
		return
	var panel := _panel(WIND_UP)
	_check(panel != null and presenter.tinker_ready(),
		"stale case starts from a genuine held Tinker Path card")
	if panel == null:
		await _dispose()
		return

	# Forged metadata never reaches the authority.
	var before := _snapshot()
	for forged in [{"owner": "warden", "cost": 1, "target": "none"},
			{"owner": "tinker", "cost": 0, "target": "none"},
			{"owner": "tinker", "cost": 1, "target": "enemy_single"},
			{"owner": "tinker", "cost": 1, "target": "ally_single"}]:
		var receipt: Dictionary = presenter.commit_tinker_path_card(WIND_UP,
			String(forged["owner"]), int(forged["cost"]), String(forged["target"]))
		_check(not receipt.get("ok", false), "forged Path metadata is refused: " + str(forged))
		_check(_snapshot() == before, "forged Path metadata mutates nothing: " + str(forged))
	var other: Dictionary = presenter.commit_tinker_path_card(SCOPE, "tinker", 0, "none")
	_check(not other.get("ok", false) and _snapshot() == before,
		"the other Path card can never be committed through this battle")

	# Untargeted energy: no legal play, no spend.
	app.deck.combat_state.energy = 0
	await _frames()
	before = _snapshot()
	await _click(panel)
	_check(_snapshot() == before and not presenter.tinker_path_playable(WIND_UP)
		and metadata.visual_state(panel).get("playable") == false
		and panel.self_modulate != Color.WHITE,
		"an unaffordable Path card cannot arm and is honestly dimmed")
	app.deck.combat_state.energy = 3
	await _frames()
	_check(presenter.tinker_path_playable(WIND_UP),
		"restoring energy re-enables the same held card")

	# A downed Tinker cannot commit the card at all.
	var tinker_position: int = presenter._tinker_position()
	_check(app.party.apply_damage(tinker_position, 999) and app.party.is_downed(tinker_position),
		"setup: the real Tinker is downed")
	app._refresh_party()
	await _frames()
	before = _snapshot()
	_check(not presenter.tinker_path_playable(WIND_UP), "a downed Tinker cannot play its Path card")
	await _click(panel)
	_check(_snapshot() == before, "a downed Tinker's Path card cannot spend or discard")
	await _dispose()

	# A duplicated copy fails the authority's lineage check.
	if not await _enter_routed_fight(fixture, "clockwork", false):
		await _dispose()
		return
	panel = _panel(WIND_UP)
	app.deck.discard_pile.append(WIND_UP)
	await _frames()
	before = _snapshot()
	_check(not presenter.tinker_ready() and not presenter.tinker_path_playable(WIND_UP),
		"a duplicate Path copy fails the authority lineage")
	await _click(panel)
	_check(_snapshot() == before, "a duplicate-copy Path card cannot spend or discard")
	app.deck.discard_pile.erase(WIND_UP)
	await _frames()
	# Return retires the authority and both receipts with the run.
	await _click(app.return_button)
	await _frames()
	_check(presenter._tinker_path == null and not presenter.tinker_ready()
		and not presenter.tinker_path_playable(WIND_UP),
		"Return clears the battle-bound Tinker Path authority")
	_check(app.title_view.is_visible_in_tree() and app.deck == null
		and app.run_tinker_path_receipt.is_empty() and app.run_tinker_path_choice == null
		and app.run_seamstress_path_receipt.is_empty()
		and app.run_seamstress_path_choice == null,
		"Return leaves a fresh title with no Path receipt or setup")
	await _dispose()


## A seeded opening whose first Fight is followed by another Fight, so the same
## run proves the Tinker admission and its authority are rebuilt per battle.
func _chain_fixture(path_cards: Array, required_hand: Array = []) -> Dictionary:
	for seed_value in range(1, 200):
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
			var oracle := _oracle(seed_value, String(node_id), path_cards)
			if oracle.is_empty():
				continue
			var missing := false
			for card_id in required_hand:
				if not (oracle["hand"] as Array).has(card_id):
					missing = true
			if missing:
				continue
			oracle["seed"] = seed_value
			oracle["node_id"] = String(node_id)
			oracle["second"] = next_fights[0]
			return oracle
	return {}


## The selected Tinker Path persists across a real victory, reward and the next
## routed Fight, where a fresh authority is bound to that battle's own deck.
func _second_fight_case() -> void:
	var fixture := _chain_fixture([SCOPE], [SCOPE])
	_check(not fixture.is_empty(), "a seeded opening offers two connected Fights")
	if fixture.is_empty():
		return
	if not await _enter_routed_fight(fixture, "sharpshot", true):
		await _dispose()
		return
	_check_deck("sharpshot", SCOPE, WIND_UP, fixture)
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
	var copies: int = app.deck.draw_pile.count(SCOPE) + app.deck.hand.count(SCOPE) \
		+ app.deck.discard_pile.count(SCOPE)
	_check(app.run_tinker_path_receipt.get("path_id", "") == "sharpshot",
		"the Tinker receipt survives a real victory and reward")
	_check(total == 13 and copies == 1 and app.deck.hand.count(WIND_UP) == 0
		and app.deck.draw_pile.count(WIND_UP) == 0 and app.deck.discard_pile.count(WIND_UP) == 0,
		"the second routed Fight gets its own one Tinker Path card")
	_check(app.run_deck.size() == 12 and not app.run_deck.has(SCOPE),
		"the run ledger still never stores the Tinker Path card")
	_check(presenter._tinker_path != null and presenter._tinker_path.is_bound()
		and presenter.tinker_ready() and presenter.tinker_path_is_card(SCOPE),
		"the new battle binds a fresh genuine Tinker Path authority")
	_check(not presenter._play._tinker._consumed and presenter._play._tinker.path_bonus() == 0
		and presenter._tinker_path.get_rules()._turn_active,
		"the new battle really opened its own first-hit turn")
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
	# Only the authored record may define these two IDs; no new entry point.
	var starter := StarterCards.new()
	var pool := TinkerPoolCards.new()
	for card_id in [SCOPE, WIND_UP]:
		_check(not starter.has_card(card_id) and not pool.has_card(card_id),
			"the Tinker Path card stays outside the starter/reward catalogs: " + card_id)
	_check(_authored_path(TINKER_PATHS, "sharpshot").get("card", {}).get("id") == SCOPE
		and _authored_path(TINKER_PATHS, "clockwork").get("card", {}).get("id") == WIND_UP,
		"both authored Tinker Paths name their own card")
	_check(not _authored_path(SEAMSTRESS_PATHS, "bloodline").is_empty(),
		"the independent Seamstress record is still readable")
	await _scope_case(true)
	await _scope_after_first_hit_case(true)
	await _clockwork_case(false)
	await _clockwork_one_energy_case(false)
	await _scope_expiry_case()
	_discount_thread_case()
	await _two_paths_case()
	await _second_fight_case()
	await _unselected_case()
	await _tampered_receipt_case()
	await _stale_case()
	_finish()


func _finish() -> void:
	for message in failures:
		printerr("FAIL: " + message)
	print("live_tinker_path_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
