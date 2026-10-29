extends SceneTree
## Genuine mounted hand -> authenticated Casing/Clamp resolver; no mocked input.

const IDS := ["tinker_v3_brass_casing", "tinker_v3_brass_casing_plus",
	"tinker_v3_spring_clamp", "tinker_v3_spring_clamp_plus"]
const SEED := 14703

var app
var view
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _frames() -> void:
	await process_frame
	await process_frame


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.pressed = down
		root.push_input(e, true)
	await _frames()


func _click(control: Control) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(), "mouse control exists and visible")
	if not is_instance_valid(control):
		return
	var at: Vector2 = control.get_global_rect().get_center()
	var m := InputEventMouseMotion.new()
	m.position = at
	root.push_input(m, true)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = at
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		root.push_input(e, true)
	await _frames()


func _panel(id: String) -> Control:
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label and panel.get_child(0).text == id:
			return panel
	return null


func _state() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.seed,
		app.run_rng.state, app.run_scraps, app.battle_result.get_outcome(),
		app._battle_closed, view._play._tinker._consumed,
		view._pinned._pinner_by_position.duplicate(true), app.enemy_intents.get_intents()]


func _begin(id: String, seat: int = 3, copies: int = 2, block_slot: int = 1) -> bool:
	_check(app.deck == null, "title before actual battle")
	app.run_seed = SEED
	var started: bool = app._start_battle()
	await _frames()
	var ready: bool = started and app.deck is CombatDeck and app.party is CombatParty \
		and app.enemies is CombatEnemies and app.enemy_intents != null \
		and app.battle_result != null and app.deck._rng == app.run_rng
	_check(ready, "actual mounted deck, enemies, party, result and seeded RNG")
	if not ready:
		return false
	if seat == 2:
		var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
		_check(swap.get("ok", false), "legal Tinker middle-seat swap")
		if not swap.get("ok", false):
			return false
		app.party._heroes.assign(swap.heroes)
	_check(app.party.get_hero(seat).id == "tinker" and not app.party.is_downed(seat),
		"actual living Tinker in printed seat")
	app.party._heroes[seat - 1]["combat_scrap"] = 2
	app.party._heroes[0]["combat_scrap"] = 7
	_check(app.enemies.get_enemies().size() >= block_slot and not app.enemies.is_slain(block_slot),
		"real original foe slots present")
	_check(app.enemies.gain_block(block_slot, 8), "real enemy Block from authoritative model")
	for i in range(copies):
		app.deck.draw_pile.append(id)
	_check(app.deck.draw_extra(copies) == copies and app.deck.hand.count(id) == copies,
		"authentic copies genuinely drawn into shared hand")
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and view._bindings.has(panel), "drawn card is live-bound")
	if panel == null:
		return false
	_check(panel.gui_input.get_connections().size() == 1
		and not app.get_node("LiveSupportHand")._bindings.has(panel),
		"single mounted hand input owner")
	return true


func _leave() -> void:
	await _click(app.return_button)
	_check(app.deck == null and view._bindings.is_empty() and view._overload_hud == null,
		"battle returns to title, retires bindings and HUD")


func _oracle(id: String, slot: int, before: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = before[7]
	rng.state = before[8]
	var deck := CombatDeck.new([], rng)
	deck.draw_pile.assign(before[0])
	deck.hand.assign(before[1])
	deck.discard_pile.assign(before[2])
	deck.combat_state.energy = before[3]
	deck.combat_state.player_turn_active = before[4]
	var party := CombatParty.new(app._load_party_definitions())
	party._heroes.assign(before[5].duplicate(true))
	var enemies := CombatEnemies.new(app._load_enemy_definitions())
	enemies._enemies.assign(before[6].duplicate(true))
	var event := CombatTinkerV3CasingClampCards.new().play_card(deck, party, enemies, id, slot)
	return {"event": event, "draw": deck.draw_pile, "hand": deck.hand,
		"discard": deck.discard_pile, "energy": deck.energy,
		"heroes": party.get_heroes(), "enemies": enemies.get_enemies(), "rng": rng.state}


func _positive(id: String, seat: int, keyboard: bool, slot: int) -> Dictionary:
	if not await _begin(id, seat, 2, slot):
		return {}
	var before := _state()
	var panel := _panel(id)
	if keyboard:
		for i in range(app.deck.hand.size() + 1):
			await _key(KEY_P)
			if view._armed == panel:
				break
	else:
		await _click(panel)
	_check(view._armed == panel, "mouse/P arms genuinely held card")
	var preview: Dictionary = view._target_preview(id)
	var raw: int = int(CombatTinkerV3CasingClampCards.CARDS[id].damage)
	var weak: int = int(CombatTinkerV3CasingClampCards.CARDS[id].weak)
	var living: Array[int] = []
	for pos in range(1, app.enemies.get_enemies().size() + 1):
		if not app.enemies.is_slain(pos):
			living.append(pos)
	_check(not living.is_empty() and preview.playable and preview.requires_selection
		and preview.target_positions == living and not preview.target_positions.has(3),
		"only genuine living original target slots offered; missing third is excluded")
	for hit in preview.hits:
		_check(hit.damage == raw and hit.weak == weak and hit.combat_scrap_gain == 1,
			"forecast exact authenticated raw hit, Weak and Tinker-only gain")
	_check(_state() == before, "selection/forecast has no wallet, RNG, latch or battle mutation")
	_check(view.current_forecast == preview and view.cue.text.contains("%d: %d damage" % [slot, raw])
		and view.cue.text.contains("Combat Scrap 2 -> 3")
		and (weak == 0 or view.cue.text.contains("Weak 1 even through Block")),
		"live cue reports genuine printed effects")
	_check(view.cue.is_visible_in_tree() and root.get_visible_rect().encloses(view.cue.get_global_rect()),
		"target cue visible within shipped 1280x720 viewport")
	var oracle := _oracle(id, slot, before)
	_check(oracle.event.get("ok", false) and oracle == _oracle(id, slot, before),
		"detached genuine paid resolver deterministic on seeded state")
	if keyboard:
		await _key(KEY_1 + slot - 1)
	else:
		await _click(app.get_node("LiveEnemyRoster")._labels[slot - 1])
	var paid: Dictionary = view.last_event.duplicate(true)
	var hit_rows: Array = paid.get("hits", [])
	_check(paid.get("ok", false) and hit_rows.size() == 1
		and hit_rows[0].position == slot and hit_rows[0].damage == raw
		and hit_rows[0].hp_loss == oracle.event.hp_loss
		and hit_rows[0].block_absorbed == oracle.event.block_absorbed,
		"single confirmed hit row derives from paid receipt, never forecast")
	paid.erase("hits")
	_check(paid == oracle.event, "live paid receipt equals independent resolver")
	_check(app.deck.draw_pile == oracle.draw and app.deck.hand == oracle.hand
		and app.deck.discard_pile == oracle.discard, "live deck piles match exact paid oracle")
	_check(app.deck.energy == before[3] - 1 and app.deck.hand.count(id) == 1
		and app.deck.discard_pile.count(id) == before[2].count(id) + 1,
		"one energy and exactly one of two held copies spent")
	_check(app.party.get_heroes() == oracle.heroes and app.enemies.get_enemies() == oracle.enemies,
		"entire party and enemy state match real resolver")
	var foe_before: Dictionary = before[6][slot - 1]
	var foe_after: Dictionary = app.enemies.get_enemy(slot)
	var absorbed: int = mini(raw, int(foe_before.block))
	var loss: int = mini(int(foe_before.hp), maxi(0, raw - int(foe_before.block)))
	_check(foe_after.block == int(foe_before.block) - absorbed
		and foe_after.hp == int(foe_before.hp) - loss
		and int(foe_after.get("statuses", {}).get("weak", 0)) ==
			int(foe_before.get("statuses", {}).get("weak", 0)) + weak,
		"enemy Block before HP, Weak even under fully absorbing Block")
	_check(app.party.get_hero(seat).combat_scrap == 3 and app.party.get_hero(1).combat_scrap == 7
		and app.run_scraps == before[9] and app.run_rng.state == before[8],
		"Tinker only counter +1; wallet, front hero and RNG unchanged")
	_check(view._play._tinker._consumed == before[12] and
		view._pinned._pinner_by_position == before[13], "no duplicated passive or pinned status")
	_check(view._overload_hud.is_visible_in_tree()
		and view._overload_hud.text.contains("Tinker Combat Scrap: 3")
		and view._overload_hud.text.contains("gained 1 Combat Scrap"),
		"visible HUD and counter refreshed from confirmed play")
	_check(_panel(id) != null and view._bindings.has(_panel(id)),
		"remaining copy is rebound for subsequent input")
	var after := _state()
	await _key(KEY_1 + slot - 1)
	await _click(app.get_node("LiveEnemyRoster")._labels[slot - 1])
	_check(_state() == after, "target retry without fresh selection cannot spend duplicate")
	var result := paid.duplicate(true)
	await _leave()
	return result


func _rejections(id: String) -> void:
	var modes := ["front", "downed", "missing", "no_energy", "unheld", "counter_negative",
		"counter_float", "counter_string", "overflow", "status_negative",
		"target_slain", "target_replaced", "hand", "session", "turn",
		"deck", "map", "rng", "token", "closed"]
	if id.begins_with("tinker_v3_spring_clamp"):
		modes.append("weak_overflow")
	for mode in modes:
		if not await _begin(id, 3, 1):
			return
		var panel := _panel(id)
		await _click(panel)
		_check(view._armed == panel, "negative starts with armed actual panel " + mode)
		var hand: Array = app.deck.hand.duplicate()
		var target: String = app.enemies.get_enemy(1).id
		var turn: int = view._turn
		var token: int = view._token
		var deck = app.deck
		var map = app.run_map
		match mode:
			"front":
				var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
				app.party._heroes.assign(swap.heroes)
				swap = CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
				app.party._heroes.assign(swap.heroes)
				_check(app.party.get_hero(1).id == "tinker", "front Tinker actually moved")
			"downed":
				_check(app.party.apply_damage(3, 10000) and app.party.is_downed(3), "real downed Tinker")
			"missing":
				app.party._heroes[2].id = "not_tinker"
			"no_energy":
				app.deck.combat_state.energy = 0
			"unheld":
				_check(app.deck.discard_played(id) and not app.deck.hand.has(id), "unheld card really absent")
			"counter_negative":
				app.party._heroes[2].combat_scrap = -1
			"counter_float":
				app.party._heroes[2].combat_scrap = 2.0
			"counter_string":
				app.party._heroes[2].combat_scrap = "2"
			"overflow":
				app.party._heroes[2].combat_scrap = CombatParty.MAX_INT
			"status_negative":
				app.enemies._enemies[0].statuses = {"weak": -1}
			"weak_overflow":
				app.enemies._enemies[0].statuses = {"weak": CombatParty.MAX_INT}
			"target_slain":
				_check(app.enemies.apply_damage(1, 10000) and app.enemies.is_slain(1),
					"original queued target slain")
				_check(not view._target_preview(id).target_positions.has(1), "dead original slot not offered")
			"target_replaced":
				app.enemies._enemies[0].id = "replacement"
			"hand":
				app.deck.hand.reverse()
			"session":
				view._session = []
			"turn":
				view._turn += 1
			"deck":
				deck = null
			"map":
				map = RefCounted.new()
			"rng":
				app.deck._rng = RandomNumberGenerator.new()
				app.deck._rng.seed = 8
			"token":
				token -= 1
			"closed":
				app._battle_closed = true
		var before := _state()
		var previous: Dictionary = view.last_event.duplicate(true)
		view._queued = true
		view._commit(panel, id, 1, token, app.party, app.enemies, app.battle_result,
			app.run_rng, turn, target, panel.get_index(), deck, hand, map, view._pinned)
		_check(_state() == before and view.last_event == previous,
			"deferred invalid callback has zero payment/mutation " + mode)
		view._commit(panel, id, 1, token, app.party, app.enemies, app.battle_result,
			app.run_rng, turn, target, panel.get_index(), deck, hand, map, view._pinned)
		_check(_state() == before, "replayed invalid callback is inert " + mode)
		await _leave()


func _forged_and_missing() -> void:
	if not await _begin(IDS[0], 3, 1):
		return
	var panel := _panel(IDS[0])
	var forged := CombatTinkerV3CasingClampCards.casing_clamp_definition(IDS[0])
	forged["effects"]["damage"] = 99
	_check(not CombatTinkerV3CasingClampCards.is_authentic_definition(forged, IDS[0]),
		"forged catalog payload fails printed record authentication")
	_check(view._definition("tinker_v3_brass_casing_forged").is_empty()
		and view._definition("").is_empty(), "missing/forged card IDs have no payable rules")
	panel.get_child(0).text = "tinker_v3_brass_casing_forged"
	var before := _state()
	await _click(panel)
	_check(view._armed != panel and _state() == before,
		"forged face cannot select, target or pay a held legitimate card")
	await _leave()


func _stale_and_retry() -> void:
	if not await _begin(IDS[0]):
		return
	var old := _panel(IDS[0])
	var captured: Callable = view._bindings[old].input
	app.hand_view.remove_child(old)
	app._refresh_hand()
	await _frames()
	_check(not view._bindings.has(old) and old.gui_input.get_connections().is_empty(),
		"obsolete panel disconnected")
	var before := _state()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	captured.call(event)
	await _key(KEY_1)
	_check(_state() == before, "removed panel callback fails closed")
	old.free()
	await _click(_panel(IDS[0]))
	await _key(KEY_ESCAPE)
	before = _state()
	await _key(KEY_1)
	_check(_state() == before, "canceled real selection cannot pay")
	app.deck.combat_state.energy = 0
	await _click(_panel(IDS[0]))
	before = _state()
	await _key(KEY_1)
	_check(_state() == before, "no-energy input fails closed")
	app.deck.combat_state.energy = 3
	await _click(_panel(IDS[0]))
	before = _state()
	var oracle := _oracle(IDS[0], 1, before)
	await _key(KEY_1)
	var paid: Dictionary = view.last_event.duplicate(true)
	paid.erase("hits")
	_check(paid == oracle.event and app.deck.energy == 2, "fresh retry valid and deterministic")
	await _leave()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real shipped app.tscn")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	view = app.get_node_or_null("LiveAttackPreview")
	_check(view != null, "mounted live attacker exists")
	if view == null:
		app.free()
		_finish()
		return
	for id in IDS:
		for seat in [2, 3]:
			for slot in [1, 2]:
				var first := await _positive(id, seat, seat == 2, slot)
				var replay := await _positive(id, seat, seat == 2, slot)
				_check(not first.is_empty() and first == replay, "same seed, genuine mounted replay")
		await _rejections(id)
	await _forged_and_missing()
	await _stale_and_retry()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_tinker_v3_casing_clamp_hand_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
