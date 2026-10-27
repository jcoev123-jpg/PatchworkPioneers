extends "res://tests/live_routed_battle_reentry_test.gd"
## Mounted, genuine seeded Fight admissions: original JSON, authoritative intent,
## sewn ticket and current enemy-phase damage share the same band-scaled base.

const BASE_TO_BAND := {
	5: {1: 5, 5: 6, 9: 7},
	6: {1: 6, 5: 7, 9: 9},
	7: {1: 7, 5: 8, 9: 10},
	8: {1: 8, 5: 10, 9: 12},
	9: {1: 9, 5: 11, 9: 13},
}
var seen_bands: Dictionary = {}
var eligible_early := 0
var phase_bands: Dictionary = {}
var eligible_mid := 0
var eligible_high := 0
var phase_hits := 0
var wasp_hits := 0
var wasp_blind := false


func _target_path(map: RunMap, current: String, path: Array, middle: bool) -> Array:
	var node: Dictionary = map.get_node(current)
	if node.is_empty() or node.get("type") not in ["Fight", "Elite", "Rest", "Shop", "Event"]:
		return []
	var floor_number: int = node.get("floor", 0)
	var through_middle: bool = middle or (node.type == "Fight" and floor_number >= 5
		and floor_number <= 8)
	var next: Array = path + [current]
	if node.type == "Fight" and floor_number >= 9 and floor_number <= 11 			and through_middle:
		return next
	var children: Array = node.outgoing.duplicate()
	children.sort()
	for id in children:
		var result := _target_path(map, id, next, through_middle)
		if not result.is_empty():
			return result
	return []


func _seeded_route() -> Dictionary:
	for value in range(1, 4001):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for id in map.get_legal_choices():
			if map.get_node(id).get("type") != "Fight":
				continue
			var path := _target_path(map, id, [], false)
			if not path.is_empty():
				return {"seed": value, "path": path}
	return {}


func _verify_band(floor_number: int) -> void:
	var band_key := 1 if floor_number <= 4 else (5 if floor_number <= 8 else 9)
	seen_bands[band_key] = true
	var original_texts: Dictionary = {}
	for path in RunAuthoredBattleEntry.BAND_CATALOG_PATHS:
		original_texts[path] = FileAccess.get_file_as_string(path)
	var actors: Array[Dictionary] = app.enemies.get_enemies()
	var actions: Array[Dictionary] = app.enemy_intents.get_intents()
	var roster = app.get_node("LiveEnemyRoster")
	_check(not actors.is_empty() and actors.size() == app.enemy_intents._slots.size()
		and actions.size() == actors.size() and roster._badges.size() == actors.size(),
		"real stage has a complete source-bound roster, first announcements and badges")
	_check(FLOOR_BAND_ORACLE.legal_group(actors.map(func(a): return a.id), floor_number),
		"admitted actors belong to the original floor band")
	var total_eligible := 0
	for index in range(actors.size()):
		var actor: Dictionary = actors[index]
		var original: Dictionary = FLOOR_BAND_ORACLE.records().get(actor.id, {})
		_check(not original.is_empty() and actor.position == index + 1,
			"authored source identity and unchanged slot order")
		if original.is_empty():
			continue
		var metadata: Dictionary = actor.duplicate(true)
		for key in ["max_hp", "hp", "block", "position", "intent"]:
			metadata.erase(key)
		var authored_metadata: Dictionary = original.duplicate(true)
		for key in ["max_hp", "intent"]:
			authored_metadata.erase(key)
		_check(metadata == authored_metadata and actor.id == original.id,
			"all identity, art, target-independent traits and other metadata untouched")
		var factor := 1.0 if band_key == 1 else (1.25 if band_key == 5 else 1.5)
		var hp := floori(float(original.max_hp) * factor)
		_check(actor.max_hp == hp and actor.hp == hp,
			"the existing floor-scaled max HP is still applied exactly once")
		_check(actor.intent.target == original.intent.target
			and actor.intent.actions.size() == original.intent.actions.size(),
			"target policy and alternative count are unchanged")
		var slot: Dictionary = app.enemy_intents._slots[index]
		_check(slot.enemy_position == actor.position and slot.target == actor.intent.target
			and slot.actions.size() == actor.intent.actions.size(),
			"authoritative weighted slot is bound to staged actor")
		for option_index in range(original.intent.actions.size()):
			var source: Dictionary = original.intent.actions[option_index]
			var authored := CombatEnemyIntents.weighted_action(source)
			var staged := CombatEnemyIntents.weighted_action(actor.intent.actions[option_index])
			_check(not authored.is_empty() and not staged.is_empty(),
				"each original and staged weighted alternative validates")
			if authored.is_empty() or staged.is_empty():
				continue
			var expected: Dictionary = source.duplicate(true)
			var body: Dictionary = authored.action
			if body.type == "attack" and body.amount in BASE_TO_BAND:
				expected.amount = BASE_TO_BAND[body.amount][band_key]
				total_eligible += 1
			_check(actor.intent.actions[option_index] == expected
				and staged.weight == authored.weight,
				"only eligible attack amounts change; weights and other actions stay authored")
			var normalized: Dictionary = expected.duplicate(true)
			var norm_result := CombatEnemyIntents.weighted_action(normalized)
			_check(not norm_result.is_empty()
				and slot.actions[option_index] == norm_result,
				"bound weighted alternative executes exactly the staged amount")
		var action: Dictionary = actions[index]
		var badge: LiveEnemyIntentBadge = roster._badges[index]
		_check(action.enemy_position == actor.position and badge.source_position == actor.position,
			"first announcement, roster and sewn cue use the same source position")
		if action.type == "attack":
			_check(badge.intent_type == "attack" and badge.amount == action.amount
				and badge.tooltip_text.contains(str(action.amount))
				and badge.readable_text.contains(str(action.amount)),
				"real visible sewn caption and tooltip match bound attack amount")
	var before: Array = [app.enemies.get_enemies(), app.enemy_intents.get_intents(),
		app.enemy_intents._slots.duplicate(true), app.run_rng.state]
	seed(45898)
	app._refresh_enemy_roster()
	app._refresh_enemy_roster()
	var global_after := randi()
	seed(45898)
	_check(global_after == randi() and before == [
		app.enemies.get_enemies(), app.enemy_intents.get_intents(),
		app.enemy_intents._slots.duplicate(true), app.run_rng.state],
		"repainting twice neither scales cached amounts again nor spends either RNG")
	for path in original_texts:
		_check(FileAccess.get_file_as_string(path) == original_texts[path],
			"the original normal source JSON is never modified")
	if band_key == 1:
		eligible_early += total_eligible
		_check(total_eligible > 0,
			"early Fight contains authored five-point attack alternatives")
	elif band_key == 5:
		eligible_mid += total_eligible
	else:
		eligible_high += total_eligible


func _actual_attack_phases(floor_number: int) -> void:
	# Use one genuine selected actor from the current floor band. Slay the other live sources so
	# there is exactly one attack, with no invented action or target.
	var selected := 0
	for actor in app.enemies.get_enemies():
		var raw: Dictionary = FLOOR_BAND_ORACLE.records().get(actor.id, {})
		if raw.is_empty():
			continue
		if floor_number <= 4 and actor.id not in ["ragling", "fray_scavenger",
			"button_guard", "spool_stalker", "seam_ripper", "felt_bulwark",
			"moth_scribe", "pin_skitter", "thread_biter"]:
			continue
		for option in raw.intent.actions:
			var parsed := CombatEnemyIntents.weighted_action(option)
			if not parsed.is_empty() and parsed.action.type == "attack" 					and parsed.action.amount in BASE_TO_BAND \
					and (not raw.has("chew_block_on_attack") or raw.get("chew_block_on_attack", false) != true):
				selected = actor.position
				break
		if selected > 0:
			break
	_check(selected > 0, "real band group includes an eligible authored attack (formerly weak on floors 1-4)")
	if selected == 0:
		return
	for actor in app.enemies.get_enemies():
		if actor.id == "needle_wasp":
			selected = actor.position
	for actor in app.enemies.get_enemies():
		if actor.position != selected:
			_check(app.enemies.apply_damage(actor.position, 99999),
				"other real sources slain to isolate authoritative damage")
	var unblocked := false
	var blocked := false
	for turn in range(20):
		if unblocked and blocked:
			break
		if app._battle_closed or not app.deck.turn_active:
			break
		# Test controls for mitigation use the actual bound hero model.
		for i in range(3):
			app.party._heroes[i].hp = app.party._heroes[i].max_hp
			app.party._heroes[i].block = 0
			app.party._heroes[i].statuses = {}
		var announced: Dictionary = {}
		for action in app.enemy_intents.get_intents():
			if action.enemy_position == selected and action.type == "attack":
				announced = action
		if not announced.is_empty():
			var target: int = announced.target_position
			var amount: int = announced.amount
			if floor_number <= 4:
				_check(amount == 5, "formerly weak early actor announces exactly five damage")
			var is_wasp: bool = app.enemies.get_enemy(selected).id == "needle_wasp"
			if is_wasp and not wasp_blind:
				_check(floor_number >= 5 and floor_number <= 8 and amount == 10
					and announced.get("hits") == 2, "routed Wasp announces total ten and two hits")
				app.enemies._enemies[selected - 1].statuses = {"blind_next_attack": 1}
				var protected: Array = app.party.get_heroes()
				await _click(app.end_turn_button)
				_check(app.party.get_heroes() == protected
					and not app.enemies.get_enemy(selected).statuses.has("blind_next_attack"),
					"mounted next Wasp attack entirely misses and consumes Blind")
				wasp_blind = true
				continue
			var shield := 0 if not unblocked else (5 if is_wasp else 3)
			if shield > 0:
				_check(app.party.gain_block(target, shield),
					"authentic CombatParty gains mitigating Block")
			var first_hp: int = app.party.get_hero(target).hp
			var first_block: int = app.party.get_hero(target).block
			app._refresh_enemy_roster()
			var badge: LiveEnemyIntentBadge = app.get_node("LiveEnemyRoster")._badges[selected - 1]
			_check(badge.amount == amount and badge.tooltip_text.contains(str(amount)),
				"sewn current-phase badge announces exactly the attack to execute")
			await _click(app.end_turn_button)
			var hero: Dictionary = app.party.get_hero(target)
			_check(hero.hp == first_hp - maxi(0, amount - first_block)
				and hero.block == maxi(0, first_block - amount),
				"current real enemy phase loses exact announced HP after Block absorbs first")
			if is_wasp:
				_check(amount == 10 and announced.get("hits") == 2
					and hero.get("statuses", {}).get("bleed", 0) == (2 if shield == 0 else 1),
					"mounted Wasp deals 5+5: exact first-hit Block prevents only first Bleed")
				wasp_hits += 1
			phase_hits += 1
			if shield == 0:
				unblocked = true
			else:
				blocked = true
		else:
			await _click(app.end_turn_button)
	_check(unblocked and blocked, "both unmitigated and Block-mitigated real attacks resolved")
	if unblocked and blocked:
		phase_bands[1 if floor_number <= 4 else (5 if floor_number <= 8 else 9)] = true


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	for base in BASE_TO_BAND:
		for floor_number in [1, 5, 9]:
			_check(BASE_TO_BAND[base][floor_number] == (
				base if floor_number == 1 else (
				(base * 5 / 4) if floor_number == 5 else (base * 3 / 2))),
				"fixed 5-9 integer-truncated literals for all three floor bands")
	var fixture := _seeded_route()
	_check(not fixture.is_empty(), "bounded seeded RunMap search finds a legal Fight route through three bands")
	if not fixture.is_empty():
		app.run_seed = fixture.seed
		await _click(app.route_button)
		var first_entry: Dictionary = {}
		for id in fixture.path:
			var node: Dictionary = app.run_map.get_node(id)
			if node.type not in ["Fight", "Elite"]:
				await _visit_path([id], false)
				continue
			var expected_entry := _oracle(id)
			_check(not expected_entry.is_empty(), "every test battle has independent entry oracle")
			seed(67713)
			var global_expected := randi()
			seed(67713)
			await _click(_route_action(id))
			_check(app.run_map.get_current_node_id() == id and app.enemies != null
				and app.enemy_intents.is_bound() and app.round_flow._started,
				"genuine route click creates bound playable battle")
			_check(_mounted_state() == expected_entry,
				"one seeded encounter, roster draw, first intents and five-card hand match oracle")
			_check(randi() == global_expected, "real Fight entry leaves global RNG untouched")
			var floor_number: int = node.floor
			if node.type == "Fight":
				_verify_band(floor_number)
			if first_entry.is_empty():
				first_entry = _mounted_state()
			if node.type == "Fight":
				await _actual_attack_phases(floor_number)
				if floor_number >= 9:
					break
			for enemy in app.enemies.get_enemies():
				if enemy.hp > 0:
					_check(app.enemies.apply_damage(enemy.position, 99999),
						"authentic battle settles using real enemy HP models")
			_check(app.enemies.get_enemies().all(func(enemy): return enemy.hp == 0), "all real sources are slain before settlement")
			app._observe_battle_result()
			await _frames()
			_check(app._battle_closed and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
				and app.reward_buttons.size() >= 4,
				"completed routed Fight or Elite offers genuine reward and Continue controls")
			if app.reward_buttons.size() < 4:
				break
			await _click(app.reward_buttons[3])
			await _click(app.continue_button)
		_check(first_entry.get("hand", []).size() == 5,
			"actual seeded opening is dealt a five-card playable hand")
	_check(seen_bands.has(1) and seen_bands.has(5) and seen_bands.has(9)
		and eligible_early > 0 and eligible_mid > 0 and eligible_high > 0,
		"first, middle and high genuine Fights covered, with eligible authored high-band actions")
	_check(phase_hits >= 6 and phase_bands.has(1) and phase_bands.has(5) and phase_bands.has(9),
		"actual normal-Fight damage and Block mitigation exercised in every band")
	_check(wasp_hits == 2 and wasp_blind, "bounded genuine route exercised Wasp two hits and Blind")
	if failures.is_empty():
		print("live_v3_normal_attack_band_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("live_v3_normal_attack_band_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
