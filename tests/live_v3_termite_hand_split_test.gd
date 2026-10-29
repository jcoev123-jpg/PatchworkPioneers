extends SceneTree

## Live seam: a paid held-card lethal hit on the authored Quilt Termite must
## split it through the app's real post-card observation boundary, and normal
## play must continue against both halves until they both die.
##
## The Fight is reached the way a player reaches it: a seeded run map, a real
## routed chooser, RNG-free Rest/Campfire/Treasure transit and then the first
## authored Fight on a floor whose band can draw the Quilt Termite.

const PartyChoice := preload("res://tests/party_choice.gd")
const TARGETING := preload("res://scripts/combat_attack_targeting.gd")
## Node kinds the live app resolves without spending the one run RNG, so the
## authored band draw of the later Fight stays independently reproducible.
const TRANSIT_KINDS := ["Rest", "Campfire", "Treasure"]
const TERMITE_MIN_FLOOR := 5
const TERMITE_MAX_FLOOR := 8

var failures: Array[String] = []
var checks := 0
var app
var presenter


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for index in range(4):
		await process_frame


func _click(control: Control) -> void:
	_check(is_instance_valid(control), "physical click requires an existing control")
	if not is_instance_valid(control):
		return
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


## Every RNG-free transit chain from one opening node to the first authored
## Fight on a floor whose normal band can offer the Termite.
func _transit_chains(map, id: String, depth: int, trail: Array) -> Array:
	var node: Dictionary = map.get_node(id)
	if node.is_empty():
		return []
	if node.get("type") == "Fight":
		var floor_number := int(node.get("floor", 0))
		if floor_number < TERMITE_MIN_FLOOR or floor_number > TERMITE_MAX_FLOOR:
			return []
		return [trail + [id]]
	if node.get("type") not in TRANSIT_KINDS or depth >= 7:
		return []
	var chains: Array = []
	for next_id in node.get("outgoing", []):
		chains.append_array(_transit_chains(map, next_id, depth + 1, trail + [id]))
	return chains


## Rebuild one candidate route from its seed without any mounted scene and
## return the exact committed group. This oracle never touches the live app.
func _committed(value: int, chain: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	var map := RunMap.new()
	if not map.generate(rng):
		return {}
	var kinds: Array = []
	for step in chain:
		if not map.get_legal_choices().has(step):
			return {}
		kinds.append(map.get_node(step).get("type"))
		if not map.choose_node(step):
			return {}
	var selected := RunAuthoredBattleEntry.new().entry_current_battle(
		map, rng, RunFightEncounterSelection.new())
	if not selected.get("success", false):
		return {}
	var ids: Array = []
	for enemy in selected["enemies"].get_enemies():
		ids.append(enemy.id)
	return {"ids": ids, "kinds": kinds}


## One genuinely generated opening route whose first Fight is a two-foe authored
## group containing the Quilt Termite.
func _fixture() -> Dictionary:
	for value in range(1, 30001):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		for id in map.get_legal_choices():
			if map.get_node(id).get("type") not in TRANSIT_KINDS:
				continue
			for chain in _transit_chains(map, id, 0, []):
				var committed := _committed(value, chain)
				if committed.is_empty() or committed.ids.size() != 2 \
						or not committed.ids.has(CombatEnemies.TERMITE_ID) \
						or committed.kinds.has("Fight") == false:
					continue
				return {"seed": value, "chain": chain, "ids": committed.ids,
					"kinds": committed.kinds}
	return {}


func _route_button(id: String):
	for button in app.route_buttons:
		if is_instance_valid(button) and button.get_meta("route_id", "") == id:
			return button
	return null


## Take one already-chosen legal route step through the real chooser. A Campfire
## or Rest leaves unchanged for free; a Treasure needs no panel at all.
func _transit(step: String, kind: String) -> bool:
	var button = _route_button(step)
	_check(button != null and not button.disabled, "the real chooser offers route step " + step)
	if button == null:
		return false
	await _click(button)
	await _frames()
	_check(app.run_map.get_current_node_id() == step, "the real route commits " + step)
	match kind:
		"Rest", "Campfire":
			_check(app.campfire_view != null and app.campfire_view.is_visible_in_tree()
				and app.campfire_visit != null
				and app.campfire_visit.read_state().status == RunCampfireVisit.OPEN,
				"a genuine Campfire mounts its live visit on " + step)
			if app.campfire_view == null or app.campfire_leave_button == null:
				return false
			await _click(app.campfire_leave_button)
			await _frames()
			_check(app._campfire_closed and app._can_choose_connected_route(),
				"a free Campfire Leave reopens the connected chooser on " + step)
		"Treasure":
			_check(app._placeholder_route.has(step) and app._can_choose_connected_route(),
				"a Treasure step keeps the connected chooser live on " + step)
		"Fight":
			_check(app.deck != null and app.enemies != null and is_instance_valid(app.battle_view),
				"the seeded Fight step admits a live battle on " + step)
			return app.deck != null and app.enemies != null
	if app.deck != null:
		return true
	return app._can_choose_connected_route()


func _panel(card_id: String):
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0).text == card_id:
			return panel
	return null


func _find_attack(target: int) -> String:
	if target < 1 or app.enemies.is_slain(target):
		return ""
	for card_id in app.deck.hand:
		var preview: Dictionary = TARGETING.new().get_preview(
			app.deck, app.party, app.enemies, card_id)
		if preview.get("playable", false) and preview.get("requires_selection", false) \
				and target in preview.get("target_positions", []):
			return card_id
	return ""


func _ensure_attack(target: int) -> String:
	for attempt in range(5):
		var card_id := _find_attack(target)
		if not card_id.is_empty():
			return card_id
		if app._battle_closed or app.battle_result.get_outcome() != CombatBattleResult.ACTIVE:
			break
		await _click(app.end_turn_button)
		await _frames()
	return ""


func _play_attack(card_id: String, target: int) -> bool:
	var panel = _panel(card_id)
	_check(panel != null, "held attack panel is mounted for " + card_id)
	if panel == null:
		return false
	await _click(panel)
	_check(presenter._card_id(presenter._armed) == card_id,
		"physical card selection arms the paid attack " + card_id)
	await _key(KEY_1 if target == 1 else (KEY_2 if target == 2 else KEY_3))
	return presenter.last_event.get("ok", false)


func _roster_ids() -> Array:
	var ids: Array = []
	for enemy in app.enemies.get_enemies():
		ids.append(enemy.id)
	return ids


## One paid held-card kill of a living actor already left at one HP. Ending a
## turn is legitimate continuing play; the bounded retry only looks for a hand
## that can actually reach the slot.
func _paid_kill(position: int) -> bool:
	for attempt in range(6):
		if app._battle_closed or app.enemies.is_slain(position):
			return false
		var card_id := _find_attack(position)
		if not card_id.is_empty():
			var preview: Dictionary = TARGETING.new().get_preview(
				app.deck, app.party, app.enemies, card_id)
			_check(preview.get("playable", false)
				and position in preview.get("target_positions", []),
				"the chosen paid card legally targets the living actor at %d" % position)
			var hp: int = app.enemies.get_enemy(position).get("hp", 0)
			_check(hp > 0, "paid-kill fixture keeps a living actor at position %d" % position)
			_check(app.enemies.apply_damage(position, hp - 1)
				and app.enemies.get_enemy(position).get("hp") == 1,
				"fixture leaves actor %d at one HP" % position)
			if not await _play_attack(card_id, position):
				return false
			_check(app.enemies.is_slain(position), "paid held attack kills actor %d" % position)
			return app.enemies.is_slain(position)
		_check(not app.end_turn_button.disabled,
			"End Turn stays legal while a paid kill needs another hand")
		await _click(app.end_turn_button)
		await _frames()
	return false


func _finish() -> void:
	if app != null and is_instance_valid(app):
		app.free()
	await _frames()
	for failure in failures:
		print("FAILURE: ", failure)
		printerr(failure)
	print("live_v3_termite_hand_split_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _fixture()
	_check(not fixture.is_empty(),
		"bounded seeds find an RNG-free route to a two-foe mid-band Termite Fight")
	if fixture.is_empty():
		await _finish()
		return
	app.run_seed = fixture.seed
	await _click(app.start_button)
	PartyChoice.choose(app)
	await _frames()
	_check(app.run_map != null and app.deck == null, "a chosen party opens the genuine route")
	if app.run_map == null:
		await _finish()
		return
	var transit_rng: int = app.run_rng.state
	for index in range(fixture.chain.size()):
		var reached: bool = await _transit(fixture.chain[index], fixture.kinds[index])
		if not reached:
			_check(false, "the seeded route reaches step %d" % index)
			await _finish()
			return
		if index < fixture.chain.size() - 1:
			_check(app.run_rng.state == transit_rng,
				"RNG-free transit step %s spends no run randomness" % fixture.chain[index])
	var fight_click_rng: int = app.run_rng.state
	_check(app.deck != null and app.party != null and app.enemies != null \
		and app.enemy_intents != null and app.round_flow != null \
		and is_instance_valid(app.battle_view),
		"fixture Fight mounts a complete, live battle")
	if app.deck == null:
		await _finish()
		return
	var ids := _roster_ids()
	_check(ids == fixture.ids, "the mounted roster is the exact authored seeded band group")
	_check(app.run_map.get_current_node_id() == fixture.chain.back(),
		"the live route committed the seeded Fight node")
	_check(fight_click_rng != transit_rng,
		"the authored entry spent the one run RNG after the RNG-free transit")
	var termite_position: int = ids.find(CombatEnemies.TERMITE_ID) + 1
	_check(termite_position > 0 and not app.enemies.is_victorious(),
		"the genuine group really contains a living Quilt Termite")
	if termite_position < 1:
		await _finish()
		return
	var termite: Dictionary = app.enemies.get_enemy(termite_position)
	_check(termite.get("id") == CombatEnemies.TERMITE_ID
		and termite.get(CombatEnemies.SPLIT_FIELD) == true
		and termite.get("chew_block_on_attack") == true,
		"the mounted Termite is the authored split-on-death record")
	_check(termite.get("hp") == termite.get("max_hp") and termite.get("hp") > 0,
		"the Termite starts at its full authored (or legitimately scaled) HP")
	_check(CombatEnemies._termite_parent_attack(termite, termite_position) > 0,
		"the mounted Termite carries its canonical weighted front attack")
	# A nonlethal, non-card model loss must not arm a split receipt.
	var rng_before: int = app.run_rng.state
	var direct: Array = app.enemies.get_enemies()
	_check(app.enemies.apply_damage(termite_position, 1)
		and app._observe_battle_result() and app.enemies.get_enemies() != direct
		and app.enemies.get_enemies().size() == ids.size()
		and app._termite_split_hit.is_empty() and app.run_rng.state == rng_before,
		"nonlethal/direct model damage never arms or publishes a paid-card split")
	# A malformed pending receipt is fail-closed and preserves the live roster.
	var guarded: Array = app.enemies.get_enemies()
	app._termite_split_hit = {"enemies": app.enemies, "position": 99}
	_check(app._observe_battle_result()
		and app.enemies.get_enemies() == guarded and app._termite_split_hit.is_empty(),
		"malformed split receipt is cleared without touching the fight")
	# Leave the Termite as the only living original foe, so the paid lethal hit
	# would end the Fight if the split were not staged before evaluate().
	for position in range(1, ids.size() + 1):
		if position == termite_position:
			continue
		_check(app.enemies.apply_damage(position, 999)
			and app.enemies.is_slain(position),
			"fixture defeats the unrelated authored foe at position %d" % position)
	_check(app._observe_battle_result()
		and app.battle_result.get_outcome() == CombatBattleResult.ACTIVE
		and not app._battle_closed and not app.enemies.is_victorious()
		and app._termite_split_hit.is_empty(),
		"with every other foe dead the living Termite keeps the Fight active")
	# Make the next paid single-target hit genuinely lethal without inventing a card.
	termite = app.enemies.get_enemy(termite_position)
	var card_id := await _ensure_attack(termite_position)
	_check(not card_id.is_empty(), "a real held single-target attack can target the Termite")
	if card_id.is_empty():
		await _finish()
		return
	termite = app.enemies.get_enemy(termite_position)
	_check(app.enemies.apply_damage(termite_position, termite.hp - 1)
		and app.enemies.get_enemy(termite_position).hp == 1,
		"fixture leaves the Termite at one HP for the paid held-card kill")
	var energy_before: int = app.deck.energy
	var discard_before: int = app.deck.discard_pile.size()
	var rng_pre_kill: int = app.run_rng.state
	termite = app.enemies.get_enemy(termite_position)
	_check(await _play_attack(card_id, termite_position),
		"paid held attack commits against the Termite")
	_check(app.deck.energy < energy_before and app.deck.discard_pile.has(card_id)
		and app.deck.discard_pile.size() > discard_before,
		"the lethal hit really charged energy and discarded its held card")
	var roster: Array = app.enemies.get_enemies()
	var left_position := termite_position
	var right_position: int = roster.size()
	_check(roster.size() == ids.size() + 1,
		"a lethal paid card hit replaces one slot and appends exactly one half")
	_check(roster[left_position - 1].id == CombatEnemies.HALF_LEFT_ID
		and roster[right_position - 1].id == CombatEnemies.HALF_RIGHT_ID
		and roster[left_position - 1].id != roster[right_position - 1].id,
		"both clean half identities occupy legal replacement and appended slots")
	var expected_hp := int(ceil(termite.max_hp / 2.0))
	var expected_bite := int(ceil(int(termite.intent.actions[0].amount) / 2.0))
	for position in [left_position, right_position]:
		var half: Dictionary = roster[position - 1]
		_check(half.hp == expected_hp and half.max_hp == expected_hp and half.block == 0,
			"half has once-halved full HP and no inherited Block")
		_check(not half.has("statuses") and not half.has("split_on_death") \
			and not half.has("chew_block_on_attack") and not half.has("revive_once"),
			"half inherits no statuses, Unravel/Split flags or chewing passive")
		_check(half.intent == {"target": "front", "actions": [
			{"type": "attack", "amount": expected_bite, "weight": 1}]},
			"half carries only its permitted once-scaled front attack")
	var expected_ids: Array = ids.slice(0, left_position - 1) \
		+ [CombatEnemies.HALF_LEFT_ID] + ids.slice(left_position) \
		+ [CombatEnemies.HALF_RIGHT_ID]
	_check(_roster_ids() == expected_ids,
		"only the dead source slot changed; every unrelated authored foe keeps its slot")
	_check(app.battle_result.get_outcome() == CombatBattleResult.ACTIVE
		and not app._battle_closed,
		"the post-card boundary stages the split instead of closing the Fight")
	# Mounted scheduler, announcements and gauges must all describe both halves.
	var announcements: Array = app.enemy_intents.get_intents()
	_check(announcements.size() == roster.size() and app.enemy_intents.is_bound(),
		"bound scheduler announces exactly one action per new actor")
	var positions: Array = []
	for announcement in announcements:
		positions.append(announcement.enemy_position)
	var ordered: Array = []
	for index in range(roster.size()):
		ordered.append(index + 1)
	_check(positions == ordered, "announcements occupy every roster position in order")
	_check(app.enemy_attacks == announcements
		and app.enemy_intents._slots.size() == roster.size(),
		"cached announcements and slots match the mounted roster")
	var roster_view = app.get_node("LiveEnemyRoster")
	_check(roster_view.enemies == app.enemies
		and roster_view._labels.size() == roster.size()
		and roster_view._badges.size() == roster.size(),
		"mounted actor selection, name tags and intent tickets rebuild for both halves")
	_check(app.intent_label.text.contains("Enemy %d" % left_position)
		and app.intent_label.text.contains("Enemy %d" % right_position),
		"the visible intent line names both new actors")
	var meters = app.get_node("LiveCombatMeters")
	_check(meters._enemies == app.enemies and meters.row.get_child_count() == 3 + roster.size(),
		"visible HP meters rebuild for both halves")
	for position in [left_position, right_position]:
		var meter = meters.row.get_child(3 + position - 1)
		var half: Dictionary = app.enemies.get_enemy(position)
		_check(meter.hp_text.text == "%d/%d" % [half.hp, half.max_hp]
			and meter.hp_bar.value == half.hp,
			"mounted HP meter shows the half's real half HP")
	var gauge: CombatUnravel = app.round_flow._unravel
	_check(gauge != null and gauge._bound_enemies == app.enemies
		and app.round_flow._valid_unravel_binding(),
		"the routed Fight's one Unravel ledger still binds the live roster")
	if gauge != null:
		_check(gauge.get_snapshot(left_position).gauge == 0
			and gauge.get_snapshot(right_position).gauge == 0
			and not gauge.get_snapshot(left_position).skip_pending
			and not gauge.get_snapshot(right_position).skip_pending,
			"both new actors have clean Unravel gauges with no transferred charge or skip")
		_check(gauge._gauges.size() == roster.size()
			and gauge._tiers_by_position.size() == roster.size(),
			"the gauge ledger has one position for every new actor")
	_check(not app.end_turn_button.disabled and app.run_rng.state == rng_pre_kill,
		"End Turn stays legal and the split draws no extra run RNG")
	# Duplicate and repeated observations cannot create grandchildren.
	var split_roster: Array = app.enemies.get_enemies()
	app._observe_battle_result()
	_check(app.enemies.get_enemies() == split_roster and app._termite_split_hit.is_empty(),
		"repeated observation and duplicate receipts never split twice")
	# Continuing play stays legal: a genuine enemy phase over both new actors.
	var turn_before: int = app.enemy_intents._turn_index
	await _click(app.end_turn_button)
	await _frames()
	_check(not app._battle_closed or app.battle_result.get_outcome() == CombatBattleResult.VICTORY,
		"the next enemy phase leaves a legitimate live Fight or a genuine victory")
	_check(app.enemies.get_enemies().size() == roster.size(),
		"the enemy phase never spawns another actor")
	if app.enemy_intents._turn_index > turn_before:
		_check(app.enemy_intents.get_intents().size() == app.enemies.get_enemies().size(),
			"the advanced scheduler announces one action per living slot")
	_check(not app._battle_closed, "both halves together do not end the Fight early")
	# Both children are targetable; victory arrives only after both die.
	for position in [left_position, right_position]:
		var half: Dictionary = app.enemies.get_enemy(position)
		_check(half.get("id") == roster[position - 1].get("id") and half.get("hp", 0) > 0,
			"half %d is a legal living target with its published identity" % position)
		_check(await _paid_kill(position),
			"paid held attack kills half %d" % position)
		_check(app.enemies.get_enemies().size() == roster.size(),
			"a half's death never spawns another actor")
		if position == left_position and not app.enemies.is_slain(right_position):
			_check(app.battle_result.get_outcome() == CombatBattleResult.ACTIVE
				and not app._battle_closed and not app.enemies.is_victorious(),
				"killing only the first half leaves the Fight legitimately active")
	_check(app.enemies.is_victorious() and app._battle_closed
		and app.battle_result.get_outcome() == CombatBattleResult.VICTORY,
		"victory is published only after both halves die")
	_check(app.enemies.get_enemies().size() == roster.size()
		and app.result_label.text.contains("VICTORY") and app.end_turn_button.disabled,
		"terminal control and label show the true victory with no duplicates")
	await _finish()
