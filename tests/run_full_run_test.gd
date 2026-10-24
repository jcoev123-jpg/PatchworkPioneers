extends "res://tests/live_run_map_entry_test.gd"
## Mounted twelve-floor gate. Only physical input mutates gameplay state.
const SEED_LIMIT := 256
var app
var trace: Array = []
var stale: Array[Callable] = []
var attacks := 0
var supports := 0
var enemy_phases := 0
var keyboard_attacks := 0
var mouse_attacks := 0
var invalid_targets := 0
var energy_rejections := 0
var purchases := 0
var picks := 0
var skips := 0
var no_effect_visits := 0
var moth_visits := 0
var quilt_awards := 0


func _frames() -> void:
	for frame in range(3):
		await process_frame


func _search(map: RunMap, choices: Array, path: Array, counts: Dictionary) -> Array:
	for id in choices:
		var node := map.get_node(id)
		var kind: String = node.type
		if path.is_empty() and kind != "Fight":
			continue
		var next := counts.duplicate()
		next[kind] = next.get(kind, 0) + 1
		if next.get("Fight", 0) > 2 or next.get("Elite", 0) > 1:
			continue
		var prefix := path.duplicate()
		prefix.append(id)
		if kind == "Boss":
			if prefix.size() == 12 and next.get("Fight", 0) == 2 and next.get("Elite", 0) == 1 \
				and next.get("Rest", 0) >= 2 and next.get("Shop", 0) > 0 \
				and next.get("Event", 0) >= 2:
				return prefix
			continue
		var found := _search(map, node.outgoing, prefix, next)
		if not found.is_empty():
			return found
	return []


func _fixture() -> Dictionary:
	for value in range(8, SEED_LIMIT + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var path := _search(map, map.get_legal_choices(), [], {})
		if not path.is_empty():
			return {"seed": value, "path": path, "graph": map.get_floors()}
	return {}


func _state() -> Array:
	var combat: Array = []
	if app.deck != null:
		combat = [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
			app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
			app.party.get_heroes(), app.enemies.get_enemies(), app.enemy_intents.get_intents(),
			app.enemy_intents._turn_index, app.battle_result.get_outcome()]
	return [app.run_map.get_route(), str(app.run_rng.state), app.run_deck.duplicate(),
		app.run_heroes.duplicate(true), app.session_gold, app.run_scraps,
		app.run_trinkets.duplicate(), app.run_stitch_descriptors.duplicate(true),
		app.run_next_stitch_id, app.run_removal_count, app.encounter_id,
		app.party_carryover.read_state(), app.act_outcome.get_state(), combat,
		app.fight_reward_offers.duplicate(true), app.fight_reward_claimed,
		app.multi_fight_rewards.read_state() if app.multi_fight_rewards != null else {},
		app.shop_visit.get_state() if app.shop_visit != null else {},
		app.shop_purchases.get_state() if app.shop_purchases != null else {},
		app.shop_purchases.get_stock() if app.shop_purchases != null else {},
		[app.fight_rewards._prepared, app.fight_rewards._award,
			app.fight_rewards._choice.get_offers(), app.fight_rewards._choice.is_claimed()]
			if app.fight_rewards != null else [],
		app.rest_recovery.is_consumed() if app.rest_recovery != null else false,
		app.fight_selection._selected.duplicate(true), app.run_map.get_floors()]


func _inventory() -> Array:
	return [app.run_deck.duplicate(), app.run_heroes.duplicate(true), app.session_gold,
		app.run_scraps, app.run_trinkets.duplicate(), app.run_stitch_descriptors.duplicate(true),
		app.run_next_stitch_id, app.run_removal_count, str(app.run_rng.state),
		app.party_carryover.read_state()]


func _record(action: Array) -> void:
	trace.append([action, _state()])


func _activate(button: Button, keyboard: bool = false) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled,
		"enabled mounted button exists")
	if not is_instance_valid(button):
		return
	_check(Rect2(0, 0, 1280, 720).encloses(button.get_global_rect()), "button fits viewport")
	if keyboard:
		button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(button)
	await _frames()


func _retained(button: Button) -> Callable:
	var connections := button.pressed.get_connections()
	_check(not connections.is_empty(), "mounted control has real callback")
	return connections[0].callable if not connections.is_empty() else Callable()


func _reject_stale() -> void:
	var before := _state()
	for callback in stale:
		callback.call()
	await _frames()
	_check(_state() == before, "retained route/reward/visit/turn callbacks preserve all state and RNG")


func _start(fixture: Dictionary) -> void:
	_check(app.title_view.is_visible_in_tree() and app.deck == null and app.run_map == null,
		"fresh title has no previous run")
	app.run_seed = fixture.seed
	await _activate(app.start_button, true)
	_check(app.run_map != null and app.route_view != null, "physical title Start mounts route")
	_check(app.run_map.get_floors() == fixture.graph and app.run_map.get_route().is_empty(),
		"Start uses searched seeded graph without selecting a node")
	await _reject_stale()


func _node(id: String, index: int) -> bool:
	var button: Button
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == id:
			button = candidate
	_check(button != null and app.run_map.get_legal_choices().has(id), "connected route control exists: " + id)
	if button == null:
		return false
	var inventory := _inventory()
	var kind: String = app.run_map.get_node(id).type
	var callback := _retained(button)
	await _activate(button, index % 2 == 1)
	_check(app.run_map.get_route().size() == index + 1 and app.run_map.get_current_node_id() == id,
		"physical connected selection advances exactly one floor")
	stale.append(callback)
	if kind in ["Event", "Treasure"]:
		if is_instance_valid(app.quiet_spool_panel):
			_check(app.route_view == null, "first Event blocks next floor until choice")
			var choice: Callable = app.quiet_spool_panel.choice_committed.get_connections()[0].callable.bind("quiet_spool", "ignore")
			await _activate(app.quiet_spool_panel.get_choice_buttons()[1], true)
			stale.append(choice)
		elif is_instance_valid(app.moth_panel):
			_check(app.route_view == null, "second Event blocks next floor until its Moth choice")
			var moth_choice: Callable = app.moth_panel.choice_committed.get_connections()[0].callable.bind("moth_infestation", "escape")
			await _activate(app.moth_panel.get_choice_buttons()[2], true)
			stale.append(moth_choice)
			moth_visits += 1
		elif is_instance_valid(app.dye_vat_panel):
			_check(app.route_view == null, "third Event blocks routing until Dye Vat choice")
			await _activate(app.dye_vat_panel.get_choice_buttons()[2], true)
		elif is_instance_valid(app.wallet_event_panel):
			var panel: LiveEventChoicePanel = app.wallet_event_panel
			var record: Dictionary = panel._selector.get_event()
			var expected_rng := RandomNumberGenerator.new()
			expected_rng.state = int(inventory[8])
			var history: Array = app._wallet_event_history.duplicate()
			history.pop_back()
			var selected := RunM04EventRotation.new().select_event(expected_rng, history)
			_check(selected.ok and selected.event == record and app.run_rng.state == expected_rng.state,
				"later Event uses exactly one seeded rotation draw")
			var wallet := {"gold": app.session_gold, "scraps": app.run_scraps}
			for choice_index in range(record.choices.size()):
				var receipt := RunEventChoice.new(record).choose_with_wallet(record.choices[choice_index].id, wallet)
				if not receipt.ok:
					continue
				await _activate(panel.get_choice_buttons()[choice_index], index % 2 == 0)
				inventory[2] = receipt.wallet.gold
				inventory[3] = receipt.wallet.scraps
				inventory[8] = str(expected_rng.state)
				break
		_check(_inventory() == inventory, "visit applies only its exact authored wallet and seeded draw; HP and ledgers unchanged")
		no_effect_visits += 1
	await _reject_stale()
	_record(["node", id, app.run_map.get_node(id).type])
	return true


## True only when this held card supplies the last living owner that has not yet
## played this turn, so CombatQuiltBonus will award Block and draw one card.
## The rule stays in the service; the test only reads its public progress.
func _quilt_award_pending(id: String) -> bool:
	if app._quilt_bonus == null or not app._quilt_turn_open:
		return false
	var progress: Dictionary = app._quilt_bonus.get_patch_progress()
	if not bool(progress.get("active", false)) or bool(progress.get("awarded", false)):
		return false
	var owner: String = str(StarterCards.new().get_definition(id).get("owner", ""))
	if owner.is_empty():
		return false
	var patches: Dictionary = progress.get("patches", {})
	if not bool(patches.get(owner, {}).get("living", false)):
		return false
	for hero_id in patches:
		if hero_id == owner:
			continue
		var patch: Dictionary = patches[hero_id]
		if bool(patch.get("living", false)) and not bool(patch.get("played", false)):
			return false
	return true


## Mirrors one committed play's seeded pile transactions without mutating combat:
## the played copy is discarded, Tune-Up's authored draw happens first, and a
## third distinct living owner makes the Quilt award draw one shared card.
func _play_mirror(id: String, award: bool) -> CombatDeck:
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var mirror := CombatDeck.new([], rng)
	mirror.hand.assign(app.deck.hand)
	mirror.draw_pile.assign(app.deck.draw_pile)
	mirror.discard_pile.assign(app.deck.discard_pile)
	mirror.combat_state.player_turn_active = app.deck.turn_active
	mirror.combat_state.energy = app.deck.energy
	mirror.try_spend_energy(int(StarterCards.new().get_definition(id).get("cost", 0)))
	if id == "tinker_tune_up":
		mirror.draw_extra(1)
	mirror.discard_played(id)
	if award:
		mirror.draw_extra(1)
	return mirror


func _play(id: String, target: int, keyboard: bool) -> void:
	var index: int = app.deck.hand.find(id)
	_check(index >= 0, "selected card is actually held")
	if index < 0:
		return
	var definition := StarterCards.new().get_definition(id)
	var energy: int = app.deck.energy
	var rng: int = app.run_rng.state
	var award := _quilt_award_pending(id)
	var mirror := _play_mirror(id, award)
	var panel: Control = app.hand_view.get_child(index)
	_check(Rect2(0, 0, 1280, 720).encloses(panel.get_global_rect()), "held card fits: %s %s route=%s" % [id, panel.get_global_rect(), app.run_map.get_route()])
	var attack: bool = id in CombatAttackCards.ATTACK_IDS
	var callback: Callable
	if attack:
		var presenter = app.get_node("LiveAttackPreview")
		callback = presenter._bindings[panel].input
		if keyboard:
			for attempt in range(app.deck.hand.size() + 1):
				await _key(KEY_P)
				if presenter._armed == panel:
					break
			_check(presenter._armed == panel, "P selects the intended held instance")
		else:
			await _click_point(panel.get_global_rect().get_center())
		if definition.target_kind == "enemy_single":
			var before := _state()
			var preview := CombatAttackTargeting.new().get_preview(app.deck, app.party, app.enemies, id)
			var invalid := 0
			for position in [1, 2, 3]:
				if position not in preview.target_positions:
					invalid = position
					break
			if invalid > 0:
				await _key(KEY_1 + invalid - 1)
				_check(_state() == before, "illegal held target changes no piles, ledgers, rewards or RNG")
				invalid_targets += 1
			if keyboard:
				await _key(KEY_1 + target - 1)
			else:
				await _click_point(app.get_node("LiveEnemyRoster")._labels[target - 1].get_global_rect().get_center())
		elif keyboard:
			await _key(KEY_ENTER)
		_check(presenter.last_event.get("ok", false) and not presenter.last_event.get("hits", []).is_empty(),
			"real held attack witnesses authored hit events")
		attacks += 1
		keyboard_attacks += 1 if keyboard else 0
		mouse_attacks += 0 if keyboard else 1
	else:
		callback = app.get_node("LiveSupportHand")._bindings[panel]
		if keyboard:
			panel.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click_point(panel.get_global_rect().get_center())
		if definition.target_kind == "ally_single":
			await _click_point(app.hero_panels[target - 1].get_global_rect().get_center())
		supports += 1
	await _frames()
	_check(app.deck.energy == (0 if app._battle_closed else energy - definition.cost),
		"held play charges authored energy; terminal closes energy: " + id)
	# Terminal closure discards the remaining hand; otherwise one held copy moves.
	# Tune-Up's authored draw happens before that discard, and a third distinct
	# living owner makes CombatQuiltBonus draw one shared card, which can reshuffle
	# older discard cards. Compare the exact seeded piles instead of a fixed delta.
	if not app._battle_closed:
		_check(app.deck.hand == mirror.hand and app.deck.draw_pile == mirror.draw_pile
			and app.deck.discard_pile == mirror.discard_pile and app.deck.energy == mirror.energy
			and app.run_rng.state == mirror._rng.state,
			"one held copy moves to discard and any Quilt award draw matches the seeded piles and RNG: " + id)
		if not award and id != "tinker_tune_up":
			_check(app.run_rng.state == rng, "an ordinary held play consumes no RNG: " + id)
		if award and bool(app._quilt_bonus.get_patch_progress().get("awarded", false)):
			quilt_awards += 1
	_record(["play", id, target, keyboard])
	var after := _state()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	callback.call(click)
	await _frames()
	_check(_state() == after, "consumed hand-panel callback is inert")


func _battle(loss: bool = false) -> bool:
	_check(app.deck != null and app.party != null and app.enemies != null and app.round_flow != null,
		"real selected battle mounts non-null models")
	if app.deck == null:
		return false
	var pools: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RunAuthoredBattleEntry.POOLS_PATH))
	var kind: String = app.run_map.get_node(app.run_map.get_current_node_id()).type
	_check(pools[kind].has(app.encounter_id), "encounter belongs to selected authored type")
	var entry: Dictionary = pools[kind][app.encounter_id]
	var ids: Array = []
	for enemy in app.enemies.get_enemies():
		ids.append(enemy.id)
	_check(ids == entry.enemy_ids and not ids.is_empty(), "actual typed enemies mounted")
	_check(app.enemy_intents._definitions == RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(entry.schedule)), "actual authored enemy schedule mounted")
	# The routed Fight/Elite/Boss admission binds that genuine roster and party to
	# the run RNG, then announces the authored weighted choice per typed ID.
	var live_intents: Array = app.enemy_intents.get_intents()
	_check(app.enemy_intents.is_bound() and app.enemy_attacks == live_intents
		and live_intents.size() == ids.size(),
		"routed battle announces one authored weighted action per typed enemy ID")
	for index in range(ids.size()):
		_check(not CombatEnemyIntents.policy_for(app.enemies, index + 1).is_empty(),
			"typed enemy slot keeps its authored target policy")
	var expected: Array = app.run_heroes.duplicate(true)
	for hero in expected:
		hero.block = 6 if hero.id == "warden" else 0
	_check(app.party.get_heroes() == expected, "battle starts from exact carried heroes plus opening Block")
	var owned: Array = app.deck.hand + app.deck.draw_pile + app.deck.discard_pile
	owned.sort()
	var persistent: Array = app.run_deck.duplicate()
	persistent.sort()
	_check(owned == persistent, "next battle contains exact settled persistent deck")
	_check(Rect2(0, 0, 1280, 720).encloses(app.battle_view.get_global_rect())
		and Rect2(0, 0, 1280, 720).encloses(app.get_node("LiveCombatMeters").row.get_global_rect()),
		"complete routed battle and meters fit 1280x720")
	_record(["entry", kind, app.encounter_id, ids])
	var attacks_before := attacks
	var phases_before := enemy_phases
	var end_callback := _retained(app.end_turn_button)
	for turn in range(100):
		if app._battle_closed:
			break
		if not loss:
			for action in range(12):
				if app._battle_closed:
					break
				var selected := ""
				var target := 0
				# Authored damage first; support spends only energy left after attacks.
				for id in app.deck.hand:
					if id not in CombatAttackCards.ATTACK_IDS:
						continue
					var preview := CombatAttackTargeting.new().get_preview(app.deck, app.party, app.enemies, id)
					if preview.playable:
						selected = id
						target = preview.target_positions[0] if preview.requires_selection else 0
						break
				if selected.is_empty():
					for id in app.deck.hand:
						if id not in app.get_node("LiveSupportHand").SUPPORT_IDS:
							continue
						var def := StarterCards.new().get_definition(id)
						var owner: Dictionary = {}
						for hero in app.party.get_heroes():
							if hero.id == def.owner:
								owner = hero
						if owner.is_empty() or owner.hp <= 0 or not owner.position in def.from_positions or def.cost > app.deck.energy:
							continue
						selected = id
						if def.target_kind == "ally_single":
							var living: Array = app.party.get_heroes().filter(func(h): return h.hp > 0)
							living.sort_custom(func(a, b): return a.hp < b.hp)
							target = living[0].position
						break
				if selected.is_empty():
					break
				await _play(selected, target, attacks % 2 == 0)
		if app._battle_closed:
			break
		# A held, living-owner, legal-target attack with insufficient energy.
		for id in app.deck.hand:
			if id not in CombatAttackCards.ATTACK_IDS:
				continue
			var definition := StarterCards.new().get_definition(id)
			if definition.cost <= app.deck.energy:
				continue
			var owner: Dictionary = {}
			for hero in app.party.get_heroes():
				if hero.id == definition.owner:
					owner = hero
			if owner.is_empty() or owner.hp <= 0 or not owner.position in definition.from_positions:
				continue
			var legal: Array = app.enemies.get_enemies().filter(func(e):
				return e.hp > 0 and e.position in definition.to_positions)
			if legal.is_empty():
				continue
			var before := _state()
			await _click_point(app.hand_view.get_child(app.deck.hand.find(id)).get_global_rect().get_center())
			if definition.target_kind == "enemy_single":
				await _key(KEY_1 + legal[0].position - 1)
			_check(_state() == before, "insufficient-energy held input preserves entire run and RNG")
			energy_rejections += 1
			break
		var previous := _state()
		await _activate(app.end_turn_button, turn % 2 == 0)
		_check(_state() != previous, "End Turn executes actual enemy phase and pile transition")
		enemy_phases += 1
		_record(["end", turn])
	_check(app._battle_closed and app.battle_result.get_outcome() == (
		CombatBattleResult.DEFEAT if loss else CombatBattleResult.VICTORY), "bounded legal battle reaches intended outcome: " + kind)
	_check(enemy_phases > phases_before and (loss or attacks > attacks_before),
		"each selected encounter witnesses real enemy phases and winning held attacks")
	stale.append(end_callback)
	return app._battle_closed and app.battle_result.get_outcome() == (CombatBattleResult.DEFEAT if loss else CombatBattleResult.VICTORY)


func _reward(pick: bool) -> void:
	_check(app.reward_buttons.size() == 4 and app.fight_reward_offers.size() == 3 and not app.fight_reward_claimed,
		"real victory offers three cards and Skip")
	if app.reward_buttons.size() != 4:
		return
	# Live rewards must be the authored weighted D2-1 base pools, never the old
	# unweighted starter fallback.
	var authored_bases := {}
	for record: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
		authored_bases[String(record.get("id", ""))] = String(record.get("owner", ""))
	for offer: Dictionary in app.fight_reward_offers:
		_check(authored_bases.get(String(offer.id), "") == String(offer.owner)
			and not StarterCards.new().has_card(String(offer.id)),
			"mounted victory offers only authored base pool cards")
	var expected: Array = app.run_deck.duplicate()
	var chosen: String = app.fight_reward_offers[0].id if pick else ""
	if pick:
		expected.append(chosen)
	var callback := _retained(app.reward_buttons[0 if pick else 3])
	var rng: int = app.run_rng.state
	var gold: int = app.session_gold + app.fight_reward_gold
	var scraps: int = app.run_scraps + (2 if app.run_map.get_node(app.run_map.get_current_node_id()).type == "Elite" else 1)
	await _activate(app.reward_buttons[0 if pick else 3], pick)
	_check(app.fight_reward_claimed and app.run_deck == expected and app.run_rng.state == rng,
		"Pick adds exactly one offered card; Skip adds none without RNG")
	_check(app.session_gold == gold and app.run_scraps == scraps, "reward pays exact prepared gold and authored scraps once")
	picks += 1 if pick else 0
	skips += 0 if pick else 1
	stale.append(callback)
	await _reject_stale()
	_record(["reward", chosen])
	var continuation := _retained(app.continue_button)
	await _activate(app.continue_button)
	stale.append(continuation)
	await _reject_stale()


func _return_terminal(status: String) -> void:
	var panel: LiveRunTerminalResultPanel = app.terminal_result_panel
	_check(panel != null and panel.has_open_result() and panel.is_visible_in_tree()
		and panel.title_label.text == status and panel.return_button.has_focus(), "real mounted terminal: " + status)
	if panel != null and app.run_map != null and app.act_outcome != null:
		# Live depth proof: the summary must state the floor the real route
		# actually reached (the map's own current node), not the smaller number
		# of battles the settled latch witnessed on the way there.
		var terminal_map: RunMap = app.run_map
		var reached_node: Dictionary = terminal_map.get_node(terminal_map.get_current_node_id())
		var reached_floor: int = terminal_map.get_current_floor()
		var settled_battles: int = (app.act_outcome.get_state().get("settled_node_ids") as Array).size()
		_check(reached_node.get("floor") == reached_floor
			and panel.summary_label.text.contains("Floor reached: %d/%d" % [reached_floor, RunMap.FLOOR_COUNT]),
			"live terminal summary states the floor the party reached: " + status)
		if settled_battles != reached_floor:
			_check(not panel.summary_label.text.contains(
				"Floor reached: %d/%d" % [settled_battles, RunMap.FLOOR_COUNT]),
				"live terminal depth is the map floor, not the settled battle count: " + status)
		if status == "Victory":
			_check(reached_floor == RunMap.FLOOR_COUNT and reached_node.get("type") == "Boss"
				and settled_battles < RunMap.FLOOR_COUNT,
				"live BOSS victory states Floor reached: 12/12 after fewer resolved battles")
	_check(app.reward_buttons.is_empty() and app.fight_rewards == null and app.multi_fight_rewards == null
		and app.end_turn_button.disabled and not app.deck.turn_active,
		"Boss/defeat terminal closes combat and has no victory-choice reward")
	if panel == null:
		return
	var before := _state()
	app.end_turn_button.pressed.emit()
	app.return_button.pressed.emit()
	await _reject_stale()
	_check(_state() == before, "terminal rejects old battle controls without spending")
	_record(["terminal", status])
	var callback: Callable = app._terminal_return_connection
	_check(callback.is_valid(), "terminal has app-owned return connection")
	await _activate(panel.return_button, true)
	stale.append(callback)
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus()
		and app.run_map == null and app.run_rng == null and app.deck == null
		and app.party_carryover == null and app.act_outcome == null and app.terminal_result_panel == null
		and app.run_deck.is_empty() and app.run_heroes.is_empty()
		and app.get_node("LiveAttackPreview")._bindings.is_empty()
		and app.get_node("LiveSupportHand")._bindings.is_empty(), "terminal Return clears run and hand bindings")


func _win(fixture: Dictionary) -> Array:
	trace = []
	await _start(fixture)
	var battles := 0
	for index in range(fixture.path.size()):
		if not await _node(fixture.path[index], index):
			return []
		var kind: String = app.run_map.get_node(fixture.path[index]).type
		if kind in ["Fight", "Elite", "Boss"]:
			if not await _battle():
				return []
			battles += 1
			var carried: Array = app.party.get_heroes()
			for hero in carried:
				hero.block = 0
			_check(app.run_heroes == app.party_carryover.read_state().heroes,
				"published roster agrees with carryover ledger before claim")
			if kind == "Boss":
				_check(app.enemies.get_enemy(1).id == "patchwork_behemoth" and app.enemies.is_victorious()
					and app.act_outcome.get_state().run_status == "VICTORY" and app.run_map.get_route() == fixture.path,
					"witnessed authored final Boss victory after all twelve selections")
				await _return_terminal("Victory")
				break
			await _reward(battles == 1)
			_check(app.run_heroes == carried and app.run_heroes == app.party_carryover.read_state().heroes,
				"claim publishes exact combat HP/status/positions, clearing only transient Block")
		elif kind == "Rest":
			var before: Array = app.run_heroes.duplicate(true)
			var gold: int = app.session_gold
			var scraps: int = app.run_scraps
			var rng: int = app.run_rng.state
			var callback := _retained(app.rest_heal_button)
			await _activate(app.rest_heal_button)
			for hero in app.run_heroes:
				var prior: Dictionary = before.filter(func(h): return h.id == hero.id)[0]
				_check(hero.hp == mini(hero.max_hp, maxi(1, prior.hp) + floori(hero.max_hp * 0.3)), "Rest exact authored recovery")
			_check(app.session_gold == gold and app.run_scraps == scraps and app.run_rng.state == rng,
				"Rest heal preserves currencies and RNG")
			stale.append(callback)
			await _reject_stale()
			_record(["rest"])
			callback = _retained(app.rest_continue_button)
			await _activate(app.rest_continue_button, true)
			stale.append(callback)
		elif kind == "Shop":
			var stock: Array = app.shop_purchases.get_stock().cards
			# Buy the cheapest affordable listing: which card the seeded draw
			# puts first is not part of this paid-purchase contract.
			var offer: Dictionary = {}
			for listing in stock:
				if app.session_gold >= listing.price \
						and (offer.is_empty() or listing.price < offer.price):
					offer = listing
			if not offer.is_empty():
				# Select that listing through the mounted picker, as a player does,
				# so the enabled Buy control targets it.
				var selected: int = stock.find(offer)
				if app.shop_offers.selected != selected:
					app.shop_offers.select(selected)
					app.shop_offers.item_selected.emit(selected)
					await _frames()
				var expected: Array = app.run_deck.duplicate()
				expected.append(offer.id)
				var gold: int = app.session_gold
				var scraps: int = app.run_scraps
				var rng: int = app.run_rng.state
				var buy := _retained(app.shop_buy_button)
				await _activate(app.shop_buy_button, true)
				_check(app.run_deck == expected and app.session_gold == gold - offer.price
					and app.run_scraps == scraps and app.run_rng.state == rng, "Shop buys one actual card for exact price")
				var settled := _state()
				buy.call()
				_check(_state() == settled, "sold Shop control cannot double-pay or spend RNG")
				stale.append(buy)
				purchases += 1
			_record(["shop"])
			var callback := _retained(app.shop_continue_button)
			await _activate(app.shop_continue_button)
			stale.append(callback)
		else:
			_check(kind in ["Event", "Treasure"] and app.route_view.is_visible_in_tree(), "no-effect visit exposes next connected controls")
	_check(battles == 4, "two Fights, one Elite and final Boss actually completed")
	return trace.duplicate(true)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	seed(980098)
	var global_next := randi()
	seed(980098)
	var fixture := _fixture()
	_check(not fixture.is_empty(), "bounded connected twelve-floor fixture exists")
	if not fixture.is_empty():
		print("Full mounted route: ", fixture.seed, " ", fixture.path)
		var first := await _win(fixture)
		if app.run_map == null:
			# Independent loss starts healthy from title and uses enemy phases only.
			trace = []
			await _start(fixture)
			await _node(fixture.path[0], 0)
			var owned: Array = app.run_deck.duplicate()
			var initial_ledger: Dictionary = app.party_carryover.read_state()
			if await _battle(true):
				_check(app.party.is_defeated() and app.session_gold == 0 and app.run_scraps == 0
					and app.run_deck == owned and app.reward_buttons.is_empty() and app.fight_rewards == null,
					"authored enemy-phase wipe grants no victory rewards")
				_check(app.party_carryover.read_state() == initial_ledger
					and app.run_heroes == initial_ledger.heroes,
					"independent loss cannot commit victory carryover")
				await _return_terminal("Defeat")
		if app.run_map == null:
			# Reset only observation counters, never gameplay state.
			attacks = 0
			var second := await _win(fixture)
			_check(not first.is_empty() and first == second,
				"independent same-seed wins reproduce route, encounters, cards, rewards, carryover, terminal and RNG")
	_check(attacks > 0 and supports > 0 and enemy_phases > 0 and keyboard_attacks > 0
		and mouse_attacks > 0 and invalid_targets > 0 and energy_rejections > 0
		and purchases > 0 and picks == 2 and skips >= 2 and no_effect_visits > 0
		and moth_visits > 0 and quilt_awards > 0,
		"nonvacuous held attack/support, both inputs, enemy-phase, award and rejection coverage: attacks=%d supports=%d phases=%d keyboard=%d mouse=%d invalid=%d energy=%d purchases=%d picks=%d skips=%d no-effect=%d moth=%d quilt-awards=%d" % [
			attacks, supports, enemy_phases, keyboard_attacks, mouse_attacks,
			invalid_targets, energy_rejections, purchases, picks, skips, no_effect_visits,
			moth_visits, quilt_awards])
	_check(randi() == global_next, "search and all real runs preserve global RNG")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("run_full_run_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
