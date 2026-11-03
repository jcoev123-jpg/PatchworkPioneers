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


func _normalized_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		var record := {}
		for key in value:
			record[key] = _normalized_numbers(value[key])
		return record
	if value is Array:
		var items: Array = []
		for item in value:
			items.append(_normalized_numbers(item))
		return items
	if value is float and is_finite(value) and floorf(value) == value:
		return int(value)
	return value


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


## The wasp witness depends on the run's seeded group draws; the Guard Ragling's
## authored shield rush spends one new draw per fight, which shifted them. The
## bounded search keeps its first four band-covering routes off: they no longer
## deal a mid-band needle_wasp, while the fifth genuine route still does.
const ROUTE_SKIP := 4


func _seeded_route(skip_routes: int = ROUTE_SKIP) -> Dictionary:
	var skipped := 0
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
				if skipped < skip_routes:
					skipped += 1
					break
				return {"seed": value, "path": path}
	return {}


func _verify_band(floor_number: int) -> void:
	var band_key := 1 if floor_number <= 4 else (5 if floor_number <= 8 else 9)
	seen_bands[band_key] = true
	var original_texts: Dictionary = {}
	for path in RunAuthoredBattleEntry.BAND_CATALOG_PATHS:
		original_texts[path] = FileAccess.get_file_as_string(path)
	original_texts[RunAuthoredBattleEntry.TOUGH_NORMALS_PATH] = FileAccess.get_file_as_string(
		RunAuthoredBattleEntry.TOUGH_NORMALS_PATH)
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
		# JSON decodes whole numbers as floats while the live app normalizes
		# integral authored fields, so compare both sides on integer numbers.
		_check(_normalized_numbers(metadata) == _normalized_numbers(authored_metadata)
			and actor.id == original.id,
			"all identity, art, target-independent traits and other metadata untouched: "
			+ actor.id)
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
				var source: Dictionary = FLOOR_BAND_ORACLE.records()[app.enemies.get_enemy(selected).id]
				var expected := 0
				for option in source.intent.actions:
					if option.type == "attack" and option.get("move", "") == announced.get("move", ""):
						expected = int(option.amount)
				_check(expected > 0 and amount == expected,
					"early actor announces its exact source-owned move amount")
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


func _ram_phases() -> Array:
	var actors: Array = app.enemies.get_enemies()
	var ram_slot := 0
	for actor in actors:
		if actor.id == "spindle_ram":
			ram_slot = actor.position
	_check(ram_slot > 0 and actors.size() >= 2 and actors.size() <= 3,
		"genuine late route admits Ram in an ordinary two-or-three foe Fight")
	if ram_slot == 0:
		return []
	var trace: Array = [_mounted_state()]
	var ram: Dictionary = app.enemies.get_enemy(ram_slot)
	_check(ram.max_hp == 45 and ram.hp == 45 and ram.charge == true
		and ram.intent.target == "front" and ram.intent.actions[2].amount == 12,
		"Ram keeps charge/front targeting with existing high-floor HP 45 and base attack 12")
	for actor in actors:
		if actor.position != ram_slot:
			_check(app.enemies.apply_damage(actor.position, 99999), "isolate the authentic routed Ram")
	var witnessed := {}
	var strikes := 0
	for turn in range(50):
		if witnessed.has("shove") and witnessed.has("block") and strikes >= 2:
			break
		_check(not app._battle_closed and app.deck.turn_active, "Ram witness has a playable real turn")
		if app._battle_closed or not app.deck.turn_active:
			break
		for hero in app.party._heroes:
			hero.hp = hero.max_hp
			hero.block = 0
			hero.statuses = {}
		var action: Dictionary = app.enemy_intents.get_intents()[ram_slot - 1]
		var armed: bool = app.enemies.get_enemy(ram_slot).has("charge_pending")
		var shield := 3 if armed and strikes > 0 else 0
		if shield > 0:
			_check(app.party.gain_block(action.target_position, shield), "real Block mitigates the second charge")
		app._refresh_enemy_roster()
		var badge: LiveEnemyIntentBadge = app.get_node("LiveEnemyRoster")._badges[ram_slot - 1]
		_check(badge.is_visible_in_tree() and badge.source_position == ram_slot
			and badge.intent_type == action.type and badge.amount == action.amount,
			"mounted Ram badge is visible and matches the authoritative source/action/amount")
		if action.type == "attack":
			_check(action.amount == (30 if armed else 0)
				and badge.charge_state == ("strike" if armed else "wind_up")
				and badge.tooltip_text.contains("30"), "mounted wind-up/strike shows floor(12 * 2.5) = 30")
		var heroes: Array = app.party.get_heroes()
		var block_before: int = app.enemies.get_enemy(ram_slot).block
		trace.append([action.duplicate(true), heroes, app.enemies.get_enemies(), app.run_rng.state])
		await _click(app.end_turn_button)
		if action.type == "shove":
			_check(action.target_position == 1 and action.direction == 1
				and app.party.get_hero(1).id == heroes[1].id
				and app.party.get_hero(2).id == heroes[0].id, "authored front shove swaps the actual front and middle heroes")
			witnessed.shove = true
		elif action.type == "block":
			_check(action.amount == 7 and app.enemies.get_enemy(ram_slot).block == block_before + 7,
				"authored Block 7 resolves on the real Ram")
			witnessed.block = true
		elif action.type == "attack":
			var hero: Dictionary = app.party.get_hero(action.target_position)
			_check(hero.hp == heroes[action.target_position - 1].hp - maxi(0, action.amount - shield),
				"real charge phase deals exactly the displayed damage after Block")
			_check(app.enemies.get_enemy(ram_slot).has("charge_pending") != armed,
				"wind-up arms and the next real strike consumes the actor-owned latch")
			if armed:
				strikes += 1
			else:
				witnessed.wind_up = true
		trace.append(_mounted_state())
	_check(witnessed.has("shove") and witnessed.has("block") and witnessed.has("wind_up")
		and strikes >= 2, "non-vacuous Ram trace resolves shove, Block, wind-up and two scaled strikes")
	return trace


func _wraith_phases() -> Array:
	var actors: Array = app.enemies.get_enemies()
	var position := 0
	for actor in actors:
		if actor.id == "razor_ribbon_wraith":
			position = actor.position
	_check(position > 0 and actors.size() >= 2 and actors.size() <= 3,
		"genuine late route admits Wraith in an ordinary two-or-three foe Fight")
	if position == 0:
		return []
	var trace: Array = [_mounted_state()]
	var wraith: Dictionary = app.enemies.get_enemy(position)
	_check(wraith.hp == 40 and wraith.max_hp == 40 and wraith.revive_once == true
		and not wraith.get("revived", false) and wraith.intent.target == "lowest_living_hp"
		and _normalized_numbers(wraith.intent.actions) == [
			{"type": "debuff", "status": "bleed", "amount": 2, "weight": 2},
			{"type": "debuff", "status": "exposed", "amount": 1, "weight": 1},
			{"type": "attack", "amount": 13, "weight": 3}],
		"Wraith scales HP 27 to 40 and Attack 9 to 13, preserving traits and 2:1:3 weights")
	for actor in actors:
		if actor.position != position:
			_check(app.enemies.apply_damage(actor.position, 99999), "isolate the authentic routed Wraith")
	var witnessed := {}
	var attacks := 0
	for turn in range(50):
		if witnessed.has("bleed") and witnessed.has("exposed") and attacks >= 2:
			break
		_check(not app._battle_closed and app.deck.turn_active, "Wraith witness has a playable real turn")
		if app._battle_closed or not app.deck.turn_active:
			break
		var action: Dictionary = app.enemy_intents.get_intents()[position - 1]
		var target: int = action.target_position
		var lowest: Dictionary = app.party.get_hero(1)
		for hero in app.party.get_heroes():
			if hero.hp > 0 and (lowest.hp <= 0 or hero.hp < lowest.hp):
				lowest = hero
		_check(target == lowest.position, "Wraith independently announces the actual lowest living HP hero")
		if target > 1:
			witnessed.low_target = true
		# Keep the announced target uniquely lowest while clearing prior status
		# effects, so each real action's result has an independent exact expectation.
		for hero in app.party._heroes:
			hero.hp = 20 if hero.position == target else hero.max_hp
			hero.block = 0
			hero.statuses = {}
		var shield := 3 if action.type == "attack" and attacks > 0 else 0
		if shield > 0:
			_check(app.party.gain_block(target, shield), "real Block mitigates Wraith's second attack")
		app._refresh_enemy_roster()
		var badge: LiveEnemyIntentBadge = app.get_node("LiveEnemyRoster")._badges[position - 1]
		_check(badge.is_visible_in_tree() and badge.source_position == position
			and badge.intent_type == action.type and badge.amount == action.amount
			and badge.target_position == target and badge.tooltip_text.contains(str(action.amount)),
			"visible Wraith cue matches source, action, amount and lowest-HP target")
		if action.type == "debuff":
			_check(badge.action_status == action.status and badge.readable_text.contains(action.status.capitalize()),
				"visible Wraith debuff names its authentic status")
		trace.append([action.duplicate(true), _mounted_state()])
		await _click(app.end_turn_button)
		for hero in app.party.get_heroes():
			if hero.position != target:
				_check(hero.hp == hero.max_hp and hero.get("statuses", {}).is_empty(),
					"Wraith affects only the uniquely lowest living HP hero")
		var affected: Dictionary = app.party.get_hero(target)
		if action.type == "attack":
			_check(action.amount == 13 and affected.hp == 20 - (13 - shield) and affected.block == 0,
				"real Wraith Attack 13 deals exact unblocked or Block-mitigated damage")
			attacks += 1
		else:
			_check(action.type == "debuff" and action.status in ["bleed", "exposed"]
				and action.amount == (2 if action.status == "bleed" else 1)
				and affected.hp == 20 and affected.get("statuses", {}).get(action.status, 0) == action.amount,
				"real weighted Bleed 2 and Exposed 1 resolve unchanged on lowest-HP hero")
			witnessed[action.status] = true
		trace.append(_mounted_state())
	_check(witnessed.has("bleed") and witnessed.has("exposed") and witnessed.has("low_target") and attacks >= 2,
		"non-vacuous Wraith trace resolves both weighted debuffs and two scaled attacks")
	var before: Dictionary = app.enemies.get_enemy(position)
	var rng_before: int = app.run_rng.state
	_check(app.enemies.apply_damage(position, 99999), "first lethal hit reaches actual routed Wraith")
	app._observe_battle_result()
	app._refresh_enemy_roster()
	var revived: Dictionary = app.enemies.get_enemy(position)
	_check(revived.hp == 20 and revived.max_hp == 40 and revived.revived == true
		and revived.position == position and revived.intent == before.intent
		and not app._battle_closed and app.battle_result.get_outcome() == CombatBattleResult.ACTIVE
		and app.run_rng.state == rng_before,
		"first lethal revives once at half scaled HP in the same slot without victory or RNG")
	trace.append(_mounted_state())
	for hero in app.party._heroes:
		hero.hp = hero.max_hp
		hero.block = 0
		hero.statuses = {}
	_check(app.enemy_intents.get_intents()[position - 1].enemy_position == position,
		"revived Wraith retains a real bound announcement")
	await _click(app.end_turn_button)
	_check(app.enemies.get_enemy(position).hp == 20 and not app._battle_closed and app.deck.turn_active,
		"revived routed Wraith takes another real enemy phase and leaves a playable turn")
	trace.append(_mounted_state())
	_check(app.enemies.apply_damage(position, 99999), "second lethal hit reaches revived Wraith")
	app._observe_battle_result()
	await _frames()
	_check(app.enemies.is_slain(position) and app.enemies.get_enemy(position).hp == 0
		and app.enemies.get_enemy(position).revived == true and app._battle_closed
		and app.battle_result.get_outcome() == CombatBattleResult.VICTORY,
		"second lethal is final and genuine routed victory opens only after it")
	trace.append(_mounted_state())
	return trace


func _trace_route(fixture: Dictionary, witness: String = "") -> Array:
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
			if floor_number >= 9 and not witness.is_empty():
				return await _ram_phases() if witness == "ram" else await _wraith_phases()
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
	return []


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
		await _trace_route(fixture)
	_check(seen_bands.has(1) and seen_bands.has(5) and seen_bands.has(9)
		and eligible_early > 0 and eligible_mid > 0 and eligible_high > 0,
		"first, middle and high genuine Fights covered, with eligible authored high-band actions")
	_check(phase_hits >= 6 and phase_bands.has(1) and phase_bands.has(5) and phase_bands.has(9),
		"actual normal-Fight damage and Block mitigation exercised in every band")
	_check(wasp_hits == 2 and wasp_blind, "bounded genuine route exercised Wasp two hits and Blind")
	if not fixture.is_empty():
		var traces: Array = []
		for replay in range(2):
			app.queue_free()
			await _frames()
			app = load("res://scenes/app.tscn").instantiate()
			root.add_child(app)
			await _frames()
			presenter = app.get_node("LiveAttackPreview")
			wasp_blind = false
			traces.append(await _trace_route(fixture, "ram"))
		_check(not traces[0].is_empty() and traces[0] == traces[1],
			"same-seed genuine late Ram entry, actions, damage, hand and RNG replay exactly")
	# The second band-covering generated route (seed 75) reaches a Wraith;
	# retain the earlier route's independent Ram/Wasp/band witnesses above.
	var wraith_fixture := _seeded_route(1)
	_check(not wraith_fixture.is_empty(), "bounded generated route search supplies a Wraith fixture")
	if not wraith_fixture.is_empty():
		var traces: Array = []
		for replay in range(2):
			app.queue_free()
			await _frames()
			app = load("res://scenes/app.tscn").instantiate()
			root.add_child(app)
			await _frames()
			presenter = app.get_node("LiveAttackPreview")
			traces.append(await _trace_route(wraith_fixture, "wraith"))
		_check(not traces[0].is_empty() and traces[0] == traces[1],
			"same-seed genuine Wraith entry, weighted effects, revival, hand and RNG replay exactly")

	if failures.is_empty():
		print("live_v3_normal_attack_band_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("live_v3_normal_attack_band_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
