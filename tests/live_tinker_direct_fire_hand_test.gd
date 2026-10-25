extends SceneTree
## Real mounted hand selection with a separately seeded scene-free resolver oracle.

const IDS := [
	"tinker_rivet_shot", "tinker_rivet_shot_plus",
	"tinker_spring_trap", "tinker_spring_trap_plus",
	"tinker_long_barrel", "tinker_long_barrel_plus",
	"tinker_bobbin_cannon", "tinker_bobbin_cannon_plus"
]
const SEED := 13906

var app
var view
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _frames() -> void:
	await process_frame
	await process_frame


func _key(keycode: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.pressed = down
		root.push_input(e, true)
	await _frames()


func _click(control: Control) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(),
		"actual mouse recipient must be visible")
	if not is_instance_valid(control):
		return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
	await _frames()


func _panel(id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and panel.get_child(0).text == id:
			return panel
	return null


func _state() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_intents.get_intents(), app.battle_result.get_outcome(),
		app.run_rng.seed, app.run_rng.state, view._play._tinker._consumed,
		app._battle_closed, view._pinned._pinner_by_position.duplicate(true) if view._pinned != null else {}]


func _oracle(id: String, position: int, before: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(before[9])
	rng.state = int(before[10])
	var deck := CombatDeck.new([], rng)
	deck.draw_pile.assign(before[0])
	deck.hand.assign(before[1])
	deck.discard_pile.assign(before[2])
	deck.combat_state.player_turn_active = bool(before[4])
	deck.combat_state.energy = int(before[3])
	var party := CombatParty.new(app._load_party_definitions())
	party._heroes.assign((before[5] as Array).duplicate(true))
	var enemies := CombatEnemies.new(app._load_enemy_definitions())
	enemies._enemies.assign((before[6] as Array).duplicate(true))
	var first := CombatTinkerFirstAttack.new()
	first._consumed = bool(before[11])
	var pin := CombatPinned.new()
	pin._pinner_by_position = (before[13] as Dictionary).duplicate(true)
	var service := CombatTinkerPoolAttacks.new(first, pin)
	var event: Dictionary = service.play_attack(deck, party, enemies, id, position)
	return {"event": event, "draw": deck.draw_pile.duplicate(),
		"hand": deck.hand.duplicate(), "discard": deck.discard_pile.duplicate(),
		"energy": deck.energy, "party": party.get_heroes(),
		"enemies": enemies.get_enemies(), "seed": rng.seed,
		"rng": rng.state, "consumed": first._consumed,
		"pin": pin._pinner_by_position.duplicate(true)}


func _compare(oracle: Dictionary, id: String, before: Array) -> void:
	_check(oracle.event.get("ok", false) and view.last_event == oracle.event,
		id + " committed event equals detached pure resolver")
	_check(app.deck.draw_pile == oracle.draw and app.deck.hand == oracle.hand
		and app.deck.discard_pile == oracle.discard and app.deck.energy == oracle.energy,
		id + " entire deck and energy equal independent oracle")
	_check(app.party.get_heroes() == oracle.party and app.enemies.get_enemies() == oracle.enemies,
		id + " complete hero/enemy HP, Block and status roster equals oracle")
	_check(app.run_rng.seed == oracle.seed and app.run_rng.state == oracle.rng
		and app.run_rng.state == before[10] and app.deck._rng == app.run_rng,
		id + " real seeded run RNG unchanged and shared")
	_check(view._play._tinker._consumed == oracle.consumed
		and view._direct_fire.get_first_attack() == view._play._tinker,
		id + " direct and starter use identical first-attack latch")
	_check(view._pinned != null and view._pinned._pinner_by_position == oracle.pin
		and view._direct_fire.get_pinned() == view._pinned,
		id + " exact battle-shared Pinned state equals detached resolver")
	_check(app.enemy_intents.get_intents() == before[7]
		and app.battle_result.get_outcome() == before[8],
		id + " no foreign turn or outcome mutation")
	var played_id: String = str(oracle.discard.back())
	_check(app.deck.hand.count(played_id) == int(before[1].count(played_id)) - 1
		and app.deck.discard_pile.count(played_id) == int(before[2].count(played_id)) + 1,
		id + " only one actual held copy consumed")


func _begin(id: String = "") -> bool:
	_check(app.deck == null, "real title precedes each new mounted battle")
	app.run_seed = SEED
	var started: bool = app._start_battle()
	await _frames()
	var ready: bool = started and app.deck is CombatDeck and app.party is CombatParty \
		and app.enemies is CombatEnemies and app.enemy_intents != null \
		and app.run_rng != null and app.deck._rng == app.run_rng \
		and app.battle_result != null and is_instance_valid(app.hand_view)
	_check(ready and view._play._tinker == view._direct_fire.get_first_attack()
		and view._pinned != null and view._direct_fire.get_pinned() == view._pinned,
		"real fresh scene mounts the battle and a shared Tinker passive")
	if not ready:
		return false
	if id != "":
		app.deck.draw_pile.append(id)
		_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == id,
			"genuine CombatDeck draw of " + id)
		app._refresh_hand()
		await _frames()
		_check(_panel(id) != null, "real held first-child ID for " + id)
	return true


func _leave() -> void:
	await _click(app.return_button)
	_check(app.deck == null and view._bindings.is_empty() and view.cue == null,
		"Return retires battle bindings and cue")


func _select_p(id: String) -> bool:
	for index in range(app.deck.hand.size() + 2):
		await _key(KEY_P)
		if view._armed == _panel(id) and view._bindings.has(view._armed):
			return true
	return false


func _show(id: String) -> void:
	var panel := _panel(id)
	_check(panel != null and panel.get_index() < app.deck.hand.size()
		and app.deck.hand[panel.get_index()] == id,
		"mounted original hand index and first-child ID agree")
	_check(view._bindings.has(panel) and panel.gui_input.get_connections().size() == 1
		and not app.get_node("LiveSupportHand")._bindings.has(panel),
		"only one input owner and one handler per direct-fire panel")
	var preview: Dictionary = view._direct_fire_preview.get_preview(
		app.deck, app.party, app.enemies, id, view._direct_fire)
	var before: Array = _state()
	_check(preview.playable and preview.requires_selection
		and preview.target_positions.has(1), "true resolver-preflight accepts enemy slot 1")
	_check(_state() == before and view.current_forecast.is_empty(),
		"helper forecast spends no energy, latch, run RNG or rosters")
	_check(view.cue.text.contains(TinkerPoolCards.new().get_definition(id).display_name)
		and view.cue.text.contains("energy") and view.cue.text.contains("Tinker FROM")
		and view.cue.text.contains("1: ") and view.cue.text.contains("damage"),
		"authored face and cue show name, cost, FROM, legal slot and damage")
	if id.begins_with("tinker_rivet_shot"):
		_check(view.cue.text.contains("Exposed") and view.cue.text.contains("after hit"),
			"Rivet exposes only after confirmed damage")
	else:
		_check(not view.cue.text.contains("after hit"), "non-Rivet damage has no Exposed")
	_check(view.cue.get_line_count() <= 2,
		"single-target cue remains in two readable stitched-paper lines")
	_check(view.cue.is_visible_in_tree()
		and root.get_visible_rect().encloses(view.cue.get_global_rect()),
		"cue visible and inside 1280x720 battle screen")


func _play_one(id: String, keyboard: bool, weak: bool = false) -> void:
	if not await _begin(id):
		return
	if weak:
		app.party._heroes[2]["statuses"] = {"weak": 1}
		_check(app.enemies.apply_statuses({1: {"exposed": 1}}) and app.enemies.gain_block(1, 5),
			"real defender Exposed and Block plus Tinker Weak")
	var panel := _panel(id)
	if keyboard:
		_check(await _select_p(id), "P selects actual mounted " + id)
	else:
		await _click(panel)
	_check(view._armed == panel, "held panel armed for " + id)
	var before: Array = _state()
	_show(id)
	_check(_state() == before, "mouse/P selection and hover leave state unchanged")
	var oracle: Dictionary = _oracle(id, 1, before)
	if keyboard:
		await _key(KEY_1)
	else:
		await _click(app.get_node("LiveEnemyRoster")._labels[0])
	_compare(oracle, id, before)
	if id.begins_with("tinker_spring_trap"):
		_check(not app.enemies.is_slain(1) and view._pinned.pinner_for_enemy(1) == "tinker"
			and oracle.pin.get(1, "") == "tinker",
			"surviving Spring Trap keeps Tinker's shared pin")
	var after: Array = _state()
	await _key(KEY_1)
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	_check(_state() == after, "repeated click/key after commit cannot double-play " + id)
	await _leave()


func _position_and_gaps() -> void:
	if not await _begin("tinker_rivet_shot"):
		return
	var candidate: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
	_check(candidate.get("ok", false), "real adjacent swap preview makes Tinker middle")
	if candidate.get("ok", false):
		app.party._heroes.assign(candidate.heroes)
		_check(app.party.get_hero(2).id == "tinker", "Tinker in authoritative slot 2")
	await _click(_panel("tinker_rivet_shot"))
	var available: Dictionary = view._target_preview("tinker_rivet_shot")
	_check(available.playable, "middle Tinker may Rivet")
	var before: Array = _state()
	await _key(KEY_1)
	_compare(_oracle("tinker_rivet_shot", 1, before), "middle-slot Rivet", before)
	await _leave()
	for id in ["tinker_long_barrel", "tinker_bobbin_cannon"]:
		if not await _begin(id):
			return
		var proposal: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
		_check(proposal.ok, "position switch preview valid " + id)
		app.party._heroes.assign(proposal.heroes)
		await _click(_panel(id))
		var denied: Array = _state()
		_check(not view._target_preview(id).playable
			and view.cue.text.contains("Unavailable"), "middle Tinker forbidden " + id)
		await _key(KEY_1)
		_check(_state() == denied, "forbidden FROM rejects without effects " + id)
		await _leave()

	if not await _begin("tinker_rivet_shot_plus"):
		return
	var definitions: Array = app._load_enemy_definitions()
	definitions.append({"id": "third_original", "name": "Third", "max_hp": 90,
		"art_path": str(definitions[0].get("art_path", ""))})
	app.enemies = CombatEnemies.new(definitions)
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	_check(app.enemies.is_valid() and app.enemies.apply_damage(2, 10000)
		and app.enemies.is_slain(2) and app.enemies.get_enemy(3).id == "third_original",
		"slain middle enemy keeps real third original slot")
	app._refresh_enemy_roster()
	view._sync_battle()
	await _frames()
	await _click(_panel("tinker_rivet_shot_plus"))
	var forecast: Dictionary = view._target_preview("tinker_rivet_shot_plus")
	_check(forecast.playable and forecast.target_positions == [1, 3],
		"preview offers enemy original slots 1 and 3, never dead slot 2")
	var before_gap: Array = _state()
	await _key(KEY_2)
	_check(_state() == before_gap, "slain original slot 2 is inert")
	var oracle_gap := _oracle("tinker_rivet_shot_plus", 3, before_gap)
	await _key(KEY_3)
	_compare(oracle_gap, "Rivet+ original slot 3", before_gap)
	await _leave()


func _rejections() -> void:
	for mode in ["energy", "inactive", "downed", "unheld", "slain", "target_changed",
			"session", "turn", "hand_changed", "deck_changed", "rng_changed"]:
		if not await _begin("tinker_bobbin_cannon"):
			return
		var panel := _panel("tinker_bobbin_cannon")
		await _click(panel)
		var old_target_id: String = app.enemies.get_enemy(1).id
		var original_hand: Array = app.deck.hand.duplicate()
		var original_deck = app.deck
		var original_map = app.run_map
		var old_turn: int = view._turn
		match mode:
			"energy":
				app.deck.combat_state.energy = 2
			"inactive":
				app.deck.combat_state.player_turn_active = false
			"downed":
				_check(app.party.apply_damage(3, 10000) and app.party.is_downed(3),
					"downed Tinker setup")
			"unheld":
				_check(app.deck.discard_played("tinker_bobbin_cannon"), "unheld setup")
			"slain":
				_check(app.enemies.apply_damage(1, 10000) and app.enemies.is_slain(1),
					"slain target setup")
			"target_changed":
				app.enemies._enemies[0]["id"] = "replacement"
			"session":
				view._session = []
			"turn":
				view._turn += 1
			"hand_changed":
				app.deck.hand.reverse()
			"deck_changed":
				original_deck = CombatDeck.new([], app.run_rng)
			"rng_changed":
				var false_rng := RandomNumberGenerator.new()
				false_rng.seed = 999
				app.deck._rng = false_rng
		var pre: Array = _state()
		var last: Dictionary = view.last_event.duplicate(true)
		# A queued callback whose check fails at deferred commit cannot pay.
		view._queued = true
		view._commit(panel, "tinker_bobbin_cannon", 1, view._token,
			app.party, app.enemies, app.battle_result, app.run_rng, old_turn,
			old_target_id, panel.get_index(), original_deck, original_hand, original_map)
		_check(_state() == pre and view.last_event == last,
			"deferred " + mode + " rejection preserves complete battle, intents, RNG and latch")
		await _key(KEY_1)
		_check(_state() == pre, "rejected " + mode + " cannot key-replay")
		await _leave()


func _shared_latch() -> void:
	for first_id in ["tinker_pop_shot", "tinker_rivet_shot"]:
		if not await _begin("tinker_rivet_shot"):
			return
		app.deck.draw_pile.append("tinker_pop_shot")
		_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == "tinker_pop_shot",
			"first-attack setup truly draws Pop Shot via genuine CombatDeck")
		app._refresh_hand()
		await _frames()
		var first_panel := _panel(first_id)
		_check(first_panel != null, "starter/direct interleave actual held first")
		await _click(first_panel)
		await _key(KEY_1)
		_check(view._play._tinker._consumed and view._direct_fire.get_first_attack()._consumed,
			"first successful " + first_id + " consumes shared latch")
		var second_id := "tinker_rivet_shot" if first_id == "tinker_pop_shot" else "tinker_pop_shot"
		var second_panel := _panel(second_id)
		_check(second_panel != null, "opposite attack remains held after first")
		await _click(second_panel)
		var second_before: Array = _state()
		var hit: Dictionary = view._resolve_attack(app.party, app.enemies, second_id, 0, true)
		var record: Dictionary = (TinkerPoolCards.new().get_definition(second_id)
			if second_id == "tinker_rivet_shot" else StarterCards.new().get_definition(second_id))
		var base: int = int(record.effects.damage)
		var expected: int = CombatStatuses.new().adjusted_attack_damage(base,
			app.party.get_hero(3).get("statuses", {}), app.enemies.get_enemy(1).get("statuses", {}))
		_check(hit.playable and not hit.hits.is_empty() and hit.hits[0].damage == expected,
			"second hit uses unboosted authored damage and actual status math")
		if second_id == "tinker_rivet_shot":
			var oracle: Dictionary = _oracle(second_id, 1, second_before)
			await _key(KEY_1)
			_compare(oracle, "Pop then Rivet", second_before)
		else:
			await _key(KEY_1)
			_check(view.last_event.ok and view._play._tinker._consumed,
				"Rivet then Pop retains consumed passive")
		await _leave()


## The accepted target-free adapter owns Scatter/Ricochet panels; its real
## input must consume the SAME first-attack latch as this direct-fire route.
func _area_interleave() -> void:
	for area_id in ["tinker_scatter_bolts", "tinker_ricochet"]:
		if not await _begin("tinker_rivet_shot"):
			return
		app.deck.draw_pile.append(area_id)
		_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == area_id,
			"draw real held area copy: " + area_id)
		app._refresh_hand()
		await _frames()
		var area_panel := _panel(area_id)
		var adapter = app.get_node("LiveAreaAttackAction")
		_check(area_panel != null and adapter._bindings.has(area_panel)
			and not view._bindings.has(area_panel),
			"target-free area adapter uniquely binds " + area_id)
		var first_before: Array = _state()
		await _click(area_panel)
		if app.deck.hand.has(area_id):
			await _key(KEY_ENTER)
		_check(not app.deck.hand.has(area_id) and app.deck.energy == int(first_before[3]) - 1,
			"real mounted area input spent and discarded once: " + area_id)
		_check(view._play._tinker._consumed and view._direct_fire.get_first_attack()._consumed,
			"area first consumes shared first-attack latch: " + area_id)
		var direct_panel := _panel("tinker_rivet_shot")
		_check(direct_panel != null, "Rivet remains genuinely held after " + area_id)
		await _click(direct_panel)
		var direct_before: Array = _state()
		var forecast: Dictionary = view._target_preview("tinker_rivet_shot")
		if forecast.playable:
			var living_slot: int = int(forecast.target_positions[0])
			_check(not app.enemies.is_slain(living_slot), "area leaves a true living original enemy slot")
			var adjusted: int = CombatStatuses.new().adjusted_attack_damage(4,
				app.party.get_hero(3).get("statuses", {}),
				app.enemies.get_enemy(living_slot).get("statuses", {}))
			_check(forecast.hits[0].position == living_slot and forecast.hits[0].damage == adjusted,
				"after " + area_id + " the direct-fire forecast cannot add +3")
			var oracle: Dictionary = _oracle("tinker_rivet_shot", living_slot, direct_before)
			await _key(KEY_1 + living_slot - 1)
			_compare(oracle, "area-before-Rivet " + area_id, direct_before)
		else:
			_check(false, "surviving legal target after " + area_id)
		await _leave()

	# A direct-fire first hit also suppresses the subsequent area packet.
	if not await _begin("tinker_rivet_shot"):
		return
	app.deck.draw_pile.append("tinker_scatter_bolts")
	_check(app.deck.draw_extra(1) == 1, "real Scatter copy drawn after Rivet")
	app._refresh_hand()
	await _frames()
	await _click(_panel("tinker_rivet_shot"))
	await _key(KEY_1)
	_check(view.last_event.ok and view._play._tinker._consumed,
		"Rivet first consumes the very same Tinker latch")
	var enemy_before: Array[Dictionary] = app.enemies.get_enemies()
	var scatter_panel := _panel("tinker_scatter_bolts")
	_check(scatter_panel != null and app.get_node("LiveAreaAttackAction")._bindings.has(scatter_panel),
		"Scatter still reachable from live held panel after Rivet")
	await _click(scatter_panel)
	if app.deck.hand.has("tinker_scatter_bolts"):
		await _key(KEY_ENTER)
	_check(not app.deck.hand.has("tinker_scatter_bolts"),
		"Scatter after Rivet commits once through area adapter")
	for index in range(enemy_before.size()):
		var old: Dictionary = enemy_before[index]
		if old.hp <= 0:
			continue
		var damage: int = CombatStatuses.new().adjusted_attack_damage(3,
			app.party.get_hero(3).get("statuses", {}), old.get("statuses", {}))
		var after: Dictionary = app.enemies.get_enemy(index + 1)
		var absorbed: int = mini(int(old.block), damage)
		_check(after.hp == maxi(0, int(old.hp) - (damage - absorbed))
			and after.block == int(old.block) - absorbed,
			"Scatter after Rivet applies unboosted base damage in original slot %d" % (index + 1))
	await _leave()


func _duplicates_and_stale_panel() -> void:
	if not await _begin():
		return
	for i in range(2):
		app.deck.draw_pile.append("tinker_rivet_shot")
	_check(app.deck.draw_extra(2) == 2, "two duplicate Rivets drawn in real hand")
	app._refresh_hand()
	await _frames()
	var copies: Array[Control] = []
	for panel in app.hand_view.get_children():
		if panel.get_child(0).text == "tinker_rivet_shot":
			copies.append(panel)
	_check(copies.size() == 2 and copies[0] != copies[1],
		"two genuinely held separate Rivet panels")
	if copies.size() != 2:
		await _leave()
		return
	for panel in copies:
		_check(view._bindings.has(panel) and panel.gui_input.get_connections().size() == 1,
			"each duplicate has precisely one presenter subscription")
	await _click(copies[0])
	await _key(KEY_P)
	_check(view._armed == copies[1], "P selects second duplicate instance, not unique ID")
	var before: Array = _state()
	var oracle: Dictionary = _oracle("tinker_rivet_shot", 1, before)
	await _key(KEY_1)
	_compare(oracle, "duplicate Rivet", before)
	_check(app.deck.hand.count("tinker_rivet_shot") == 1,
		"one of two identical drawn copies remains genuinely held")
	await _leave()

	if not await _begin("tinker_long_barrel"):
		return
	var old := _panel("tinker_long_barrel")
	await _click(old)
	var captured: Callable = view._bindings[old].input
	var last_id: String = old.get_child(0).text
	app.hand_view.remove_child(old)
	app._refresh_hand()
	await _frames()
	_check(old.gui_input.get_connections().is_empty() and old.get_child(0).text == last_id,
		"obsolete real panel unbound but captured callback retains former identity")
	var before_stale: Array = _state()
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	captured.call(event)
	await _key(KEY_1)
	_check(_state() == before_stale and not view._bindings.has(old),
		"removed-panel callback cannot stage or pay a stale Long Barrel")
	old.free()
	await _leave()
	# New session must not inherit a previous encounter's first-attack latch.
	if await _begin("tinker_rivet_shot"):
		_check(not view._play._tinker._consumed and view._direct_fire.get_first_attack() == view._play._tinker,
			"re-entry gets one fresh shared latch and no previous session panel")
		await _leave()


## Real End Turn must reset shared Tinker bonus; repeated same-turn redraw cannot.
func _real_turn_reset() -> void:
	if not await _begin("tinker_rivet_shot"):
		return
	await _click(_panel("tinker_rivet_shot"))
	await _key(KEY_1)
	_check(view.last_event.ok and view._play._tinker._consumed,
		"first Rivet consumes the passive before real End Turn")
	var old_turn: int = app.enemy_intents._turn_index
	var end_control = app.get("end_turn_button") as Control
	_check(is_instance_valid(end_control) and end_control.is_visible_in_tree(),
		"the actual End Turn button is visible and pointer-reachable")
	if not is_instance_valid(end_control):
		await _leave()
		return
	await _click(end_control)
	await _frames()
	var advanced: bool = app.enemy_intents._turn_index > old_turn and app.deck.turn_active
	_check(advanced and view._turn == app.enemy_intents._turn_index,
		"real End Turn advances enemy intents and starts next player turn")
	_check(not view._play._tinker._consumed and not view._direct_fire.get_first_attack()._consumed,
		"new turn resets the one shared passive")
	if advanced:
		app.deck.draw_pile.append("tinker_rivet_shot")
		_check(app.deck.draw_extra(1) == 1, "new player turn draws Rivet from real deck")
		app._refresh_hand()
		await _frames()
		var panel: Control = _panel("tinker_rivet_shot")
		_check(panel != null, "next turn mounts the genuinely held Rivet")
		if panel != null:
			await _click(panel)
			var before: Array = _state()
			var oracle: Dictionary = _oracle("tinker_rivet_shot", 1, before)
			await _key(KEY_1)
			_compare(oracle, "new-turn Rivet", before)
			for index in range(3):
				view._sync_battle()
			_check(view._play._tinker._consumed,
				"no repeated same-turn sync can regrant +3")
	await _leave()


## A real pin survives a turn and a same-owner hit, then the mounted Warden
## consumes exactly one +5 before the two status multipliers.
func _spring_pin_followup() -> void:
	if not await _begin("tinker_spring_trap"):
		return
	app.enemies._enemies[0]["max_hp"] = 90
	app.enemies._enemies[0]["hp"] = 90
	_check(app.enemies.is_valid(), "durable original enemy supports three confirmed hits")
	await _click(_panel("tinker_spring_trap"))
	var before: Array = _state()
	var spring_oracle := _oracle("tinker_spring_trap", 1, before)
	await _key(KEY_1)
	_compare(spring_oracle, "Spring before Warden", before)
	_check(view._pinned.pinner_for_enemy(1) == "tinker",
		"first mounted Spring records Tinker in shared Pinned")
	var old_turn: int = app.enemy_intents._turn_index
	await _click(app.end_turn_button)
	_check(app.deck.turn_active and app.enemy_intents._turn_index > old_turn
		and view._pinned.pinner_for_enemy(1) == "tinker",
		"unused Spring pin persists across real End Turn")
	for id in ["tinker_pop_shot", "warden_seam_breaker"]:
		app.deck.draw_pile.append(id)
		_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == id,
			"draw genuine follow-up card " + id)
	app._refresh_hand()
	await _frames()
	_check(_panel("tinker_pop_shot") != null and _panel("warden_seam_breaker") != null
		and app.deck.energy == 3 and not app.enemies.is_slain(1),
		"new turn mounts both owners with enough energy and living target")
	await _click(_panel("tinker_pop_shot"))
	await _key(KEY_1)
	_check(view.last_event.get("ok", false) and view._pinned.pinner_for_enemy(1) == "tinker",
		"confirmed same-Tinker starter hit does not consume Spring pin")
	app.party._heroes[0]["statuses"] = {"weak": 1}
	_check(app.enemies.apply_statuses({1: {"exposed": 1}}),
		"real Weak Warden and Exposed target set status arithmetic")
	var expected: int = CombatStatuses.new().adjusted_attack_damage(12,
		app.party.get_hero(1).get("statuses", {}),
		app.enemies.get_enemy(1).get("statuses", {}))
	var no_pin: int = CombatStatuses.new().adjusted_attack_damage(7,
		app.party.get_hero(1).get("statuses", {}),
		app.enemies.get_enemy(1).get("statuses", {}))
	_check(expected > no_pin and view._pinned.bonus_for_attack(app.enemies, 1, "warden") == 5,
		"Warden's +5 is available before Weak/Exposed")
	await _click(_panel("warden_seam_breaker"))
	await _key(KEY_1)
	var hits: Array = view.last_event.get("hits", [])
	_check(view.last_event.get("ok", false) and hits.size() == 1
		and hits[0].get("pin_bonus", -1) == 5
		and hits[0].get("damage", -1) == expected
		and hits[0].get("pin_consumed", false)
		and view._pinned.pinner_for_enemy(1) == "",
		"mounted Warden gets exactly one status-adjusted +5 and consumes pin")
	await _leave()


func _spring_lethal() -> void:
	if not await _begin("tinker_spring_trap_plus"):
		return
	app.enemies._enemies[0]["hp"] = 1
	_check(app.enemies.is_valid() and not app.enemies.is_slain(1),
		"lethal Spring fixture starts with living original target")
	await _click(_panel("tinker_spring_trap_plus"))
	var before: Array = _state()
	var oracle := _oracle("tinker_spring_trap_plus", 1, before)
	await _click(app.get_node("LiveEnemyRoster")._labels[0])
	_compare(oracle, "lethal Spring+", before)
	_check(app.enemies.is_slain(1) and view._pinned.pinner_for_enemy(1) == ""
		and not bool(view.last_event.hits[0].pinned),
		"lethal Spring+ never stores a pin on the fallen enemy")
	await _leave()


func _spring_rejections() -> void:
	for id in ["tinker_spring_trap", "tinker_spring_trap_plus"]:
		for mode in ["energy", "downed", "owner_slot", "unheld", "slain",
				"target_changed", "session", "turn", "hand_changed", "pin_missing",
				"pin_replaced"]:
			if not await _begin(id):
				return
			var panel := _panel(id)
			await _click(panel)
			var old_target: String = str(app.enemies.get_enemy(1).id)
			var queued_hand: Array = app.deck.hand.duplicate()
			var queued_pin: CombatPinned = view._pinned
			var old_turn: int = view._turn
			match mode:
				"energy":
					app.deck.combat_state.energy = 0
				"downed":
					_check(app.party.apply_damage(3, 10000) and app.party.is_downed(3),
						"Spring downed owner precondition")
				"owner_slot":
					var first: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
					_check(first.get("ok", false), "first real owner swap")
					app.party._heroes.assign(first.heroes)
					var second: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
					_check(second.get("ok", false), "second real owner swap")
					app.party._heroes.assign(second.heroes)
					_check(app.party.is_valid() and app.party.get_hero(1).id == "tinker",
						"living Tinker is in illegal slot 1")
				"unheld":
					_check(app.deck.discard_played(id) and not app.deck.hand.has(id),
						"Spring removed from actual shared hand")
				"slain":
					_check(app.enemies.apply_damage(1, 10000) and app.enemies.is_slain(1),
						"original Spring target slain before commit")
				"target_changed":
					app.enemies._enemies[0]["id"] = "replacement"
				"session":
					view._session = []
				"turn":
					view._turn += 1
				"hand_changed":
					app.deck.hand.reverse()
				"pin_missing":
					view._pinned = null
					view._direct_fire.set_pinned(null)
				"pin_replaced":
					view._pinned = CombatPinned.new()
			var metadata = app.get_node("LiveSupportHand")._metadata
			metadata._update_visual(panel)
			if mode == "slain":
				_check(not view._target_preview(id).get("target_positions", []).has(1),
					id + " offers no slain original target")
			elif mode != "target_changed":
				_check(not metadata.visual_state(panel).get("playable", true),
					id + " refused " + mode + " is dim in actual hand")
			var before: Array = _state()
			var last: Dictionary = view.last_event.duplicate(true)
			view._queued = true
			view._commit(panel, id, 1, view._token, app.party, app.enemies,
				app.battle_result, app.run_rng, old_turn, old_target,
				panel.get_index(), app.deck, queued_hand, app.run_map, queued_pin)
			_check(_state() == before and view.last_event == last,
				id + " deferred " + mode + " rejects without spending or RNG")
			await _key(KEY_1)
			_check(_state() == before, id + " refused key cannot replay: " + mode)
			await _leave()


func _spring_stale_panel() -> void:
	if not await _begin("tinker_spring_trap"):
		return
	var old := _panel("tinker_spring_trap")
	await _click(old)
	var captured: Callable = view._bindings[old].input
	app.hand_view.remove_child(old)
	app._refresh_hand()
	await _frames()
	_check(not view._bindings.has(old) and old.gui_input.get_connections().is_empty(),
		"removed Spring panel loses the real presenter's binding")
	var before: Array = _state()
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	captured.call(event)
	await _key(KEY_1)
	_check(_state() == before and view._pinned.pinner_for_enemy(1) == "",
		"stale Spring callback cannot spend, hit or pin")
	old.free()
	await _leave()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "actual App scene exists")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	view = app.get_node_or_null("LiveAttackPreview")
	_check(view != null and app.deck == null, "title boots with actual attack presenter")
	if view == null:
		app.free()
		_finish()
		return
	for id in IDS:
		_check(TinkerPoolCards.new().get_definition(id).get("id") == id
			and not CombatAttackTargeting.ATTACK_IDS.has(id)
			and view._direct_fire_preview.supports(id),
			"real catalog direct-fire record not grafted onto starter-only targeting: " + id)
	var i := 0
	for id in IDS:
		await _play_one(id, i % 2 == 1, i < 2)
		i += 1
	await _position_and_gaps()
	await _rejections()
	await _shared_latch()
	await _area_interleave()
	await _duplicates_and_stale_panel()
	await _real_turn_reset()
	await _spring_pin_followup()
	await _spring_lethal()
	await _spring_rejections()
	await _spring_stale_panel()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_tinker_direct_fire_hand_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
