extends "res://tests/live_elite_reward_continuation_test.gd"
## Mounted claim -> free sew -> connected continuation -> second drop -> reset/replay.

var sewing


func _click(control: Control) -> void:
	if is_instance_valid(control):
		_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()),
			"physical input bounds: %s %s" % [control.name, control.get_global_rect()])
	await super._click(control)


func _complete_state() -> Array:
	return [_settlement_state(), app.run_scraps, app.run_map.get_floors(),
		app.run_map.get_generation_revision(), app.run_seed,
		app.act_outcome.get_state(), app.run_removal_count,
		app.party_carryover.torn.read_state(), app.party_carryover._receipts.duplicate(true),
		app.multi_fight_rewards._paid_battles.duplicate() if app.multi_fight_rewards != null else [],
		app.multi_fight_rewards._pending if app.multi_fight_rewards != null else null,
		sewing.wardrobe.get_snapshot() if sewing.wardrobe != null else {}, sewing.summary.text]


func _reject_patch(callback: Callable, message: String) -> void:
	var before := _complete_state()
	callback.call()
	_check(_complete_state() == before, message + ": complete run/wardrobe unchanged")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	sewing = app.get_node("LiveElitePatchSewing")
	var fixture := _multi_fixture()
	_check(not fixture.is_empty(), "real seeded route reaches two Elites and Shop")
	if fixture.is_empty():
		await _finish_sewing()
		return
	var replay: Array = []
	var retained: Array[Callable] = []
	for session in range(2):
		seed(850085)
		var global_next := randi()
		seed(850085)
		if not await _routed_win(fixture, false):
			break
		_check(sewing.wardrobe == null and sewing.hero_buttons.is_empty(), "fresh replay has no assignments or choices")
		for callback in retained:
			_reject_patch(callback, "prior session callback")
		await _click(app.reward_buttons[0])
		await _click(app.continue_button)
		var observations: Array = []
		var first_worn := {}
		for index in range(2):
			var path: Array = fixture.paths[index].duplicate()
			var elite: String = path.pop_back()
			await _visit_path(path, session == 1)
			await _click(_route_action(elite))
			_check(app.run_map.get_node(elite).type == "Elite" and not app._battle_closed,
				"genuine connected Elite is mounted")
			if index == 1:
				_check(sewing.wardrobe.get_snapshot().worn == first_worn and not sewing.summary.text.is_empty(),
					"ownership stays displayed through Continue and next connected battle")
				var base: Array = app.party_carryover.read_state().heroes
				var effective: Array = app.party.get_heroes()
				for i in range(3):
					_check(effective[i].hp == base[i].hp and effective[i].max_hp == base[i].max_hp + (6 if effective[i].id == "warden" else 0),
						"connected real battle projects +6 only on wearer without healing")
				_check(app.party.heal(1, 999) and app.party.get_hero(1).hp == 46,
					"real combat healing reaches effective coat cap")
				_check(app.party.apply_damage(1, app.party.get_hero(1).block + 2)
					and app.party.get_hero(1).hp == 44, "real damage uses effective HP")
			for callback in retained:
				_reject_patch(callback, "wrong battle callback")
			if index == 1:
				var moved := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
				_check(moved.ok, "actual Elite party supports a changed formation")
				if moved.ok:
					app.party._heroes.assign(moved.heroes)
				_check(app.party.apply_damage(1, 1), "actual changed formation carries injury")
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.apply_damage(enemy.position, 9999), "defeat actual mounted Elite enemy")
			app._observe_battle_result()
			await _frames()
			var service: RunMultiFightRewards = app.multi_fight_rewards
			_check(service != null and app.reward_buttons.size() == 4, "real Elite reward coordinator and choices exist")
			if service == null:
				break
			var drop: String = app.fight_reward_trinket
			if index == 0:
				_check(drop == "quilted_coat", "fixed seed %s actually earns coat first (got %s)" % [fixture.seed, drop])
			_check(not app.run_trinkets.has(drop), "pending drop is not yet owned")
			var forged := {"ok": true, "receipt": {"node_id": elite,
				"node_kind": "Elite", "trinket_drop_id": drop}}
			_reject_patch(sewing.observe_claim.bind(service, forged), "pre-claim forged receipt")
			_reject_patch(sewing._sew.bind("warden", app.reward_buttons[0], sewing._token, {}), "pre-claim sew")
			_check(sewing.hero_buttons.is_empty() or not sewing._eligible(), "no eligible pre-claim hero input")
			var reward_state := _reward_oracle_after_prepare(service)
			if index == 1:
				var reward_callback: Callable = app.reward_buttons[0 if index == 0 else 3].pressed.get_connections()[0].callable
				app.party._heroes[1].max_hp += 1
				_reject_patch(reward_callback, "invalid effective battle cap rejects claim")
				app.party._heroes[1].max_hp -= 1
			if session == 0:
				await _click(app.reward_buttons[0 if index == 0 else 3])
			else:
				app.reward_buttons[0 if index == 0 else 3].grab_focus()
				await _key(KEY_ENTER)
			_check(app.fight_reward_claimed and app.run_trinkets.has(drop)
				and service._paid_battles.has(app.battle_result), "physical pick/skip commits the genuine drop once")
			if index == 1:
				var wearer: Dictionary = app.run_heroes.filter(func(h): return h.id == "warden")[0]
				_check(wearer.max_hp == 40 and wearer.hp == 40,
					"settlement clamps above-base HP and never persists derived +6")
			_check(sewing.wardrobe != null and sewing.hero_buttons.size() == 3, "owned authored drop exposes all three hero choices")
			if sewing.wardrobe == null or sewing.hero_buttons.size() != 3:
				break
			var state: Dictionary = sewing.wardrobe.get_snapshot()
			_test_context_refresh(state)
			_check(state.heroes == app.run_heroes and state.owned == app.run_trinkets
				and state.cards == app.run_deck and state.scraps == app.run_scraps
				and state.gold == app.session_gold and state.seed == app.run_seed, "wardrobe receives full actual committed run context")
			for button in sewing.hero_buttons:
				_check(button.is_visible_in_tree() and not button.disabled and button.focus_mode == Control.FOCUS_ALL
					and Rect2(0, 0, 1280, 720).encloses(button.get_global_rect()), "each hero choice visible, focusable and in viewport")
			var button: Button = sewing.hero_buttons[index]
			var hero: String = button.get_meta("hero_id")
			var callback: Callable = button.pressed.get_connections()[0].callable
			button.disabled = true
			_reject_patch(callback, "disabled hero choice")
			button.disabled = false
			button.hide()
			_reject_patch(callback, "hidden hero choice")
			button.show()
			app.return_button.grab_focus()
			for choice in sewing.hero_buttons:
				await _key(KEY_TAB)
				_check(choice.has_focus(), "physical Tab reaches every hero choice")
			await _key(KEY_TAB)
			_check(app.continue_button.has_focus(), "physical Tab exits choices to Continue")
			_reject_patch(sewing._sew.bind("foreign", button, sewing._token, state), "forged hero")
			_reject_patch(sewing._sew.bind(hero, button, sewing._token, {}), "malformed wardrobe guard")
			_reject_patch(sewing._sew.bind(hero, app.return_button, sewing._token, state), "foreign button")
			var forged_state := state.duplicate(true)
			forged_state.scraps += 1
			_reject_patch(sewing._sew.bind(hero, button, sewing._token, forged_state), "stale wardrobe snapshot")
			app.run_map._route.pop_back()
			_reject_patch(callback, "wrong current node")
			app.run_map._route.append(elite)
			app.run_map._nodes[elite].outgoing.append("foreign")
			_reject_patch(callback, "graph drift")
			app.run_map._nodes[elite].outgoing.erase("foreign")
			app.run_scraps += 1
			_reject_patch(callback, "run resources drift")
			app.run_scraps -= 1
			app.run_trinkets.erase(drop)
			_reject_patch(callback, "drop no longer owned")
			app.run_trinkets.append(drop)
			app.session_gold += 1
			_reject_patch(callback, "gold drift")
			app.session_gold -= 1
			app.run_deck.append("warden_strike")
			_reject_patch(callback, "deck drift")
			app.run_deck.pop_back()
			var revision: int = app.run_map._generation_revision
			app.run_map._generation_revision += 1
			_reject_patch(callback, "regenerated map revision")
			app.run_map._generation_revision = revision
			var unchanged := _settlement_state()
			var scraps: int = app.run_scraps
			if session == 0:
				await _click(button)
			else:
				app.return_button.grab_focus()
				await _key(KEY_TAB)
				_check(sewing.hero_buttons[0].has_focus(), "physical Tab reaches first hero from reward actions")
				if index == 1:
					await _key(KEY_TAB)
				_check(button.has_focus(), "physical Tab reaches selected hero")
				await _key(KEY_SPACE if index == 0 else KEY_ENTER)
			var after: Dictionary = sewing.wardrobe.get_snapshot()
			_check(app.party_carryover._wardrobe == sewing.wardrobe,
				"successful sewing binds the exact live carryover wardrobe")
			var slot: String = after.definitions[drop]
			_check(after.worn[hero][slot] == drop and sewing.summary.text.contains("%s: %s (%s)" % [hero.capitalize(), drop, slot]),
				"physical confirmation sews authored slot and visibly names wearer")
			_check(_settlement_state() == unchanged and app.run_scraps == scraps and after.scraps == scraps,
				"free sewing changes no run, reward, deck, route, gold or RNG state")
			_check(after.operation_ids.size() == index + 1, "one successful sew receipt per earned drop")
			if index == 0:
				first_worn = after.worn.duplicate(true)
			else:
				for id in first_worn:
					for previous_slot in first_worn[id]:
						if first_worn[id][previous_slot] != "":
							_check(after.worn[id][previous_slot] == first_worn[id][previous_slot], "second legitimate drop preserves first assignment")
			for action in sewing.hero_buttons:
				action.disabled = false
			_reject_patch(callback, "forced duplicate sew")
			_reject_patch(sewing.observe_claim.bind(service, forged), "duplicate claim observation")
			retained.append(callback)
			observations.append([after, reward_state, app.run_rng.state, app.run_trinkets.duplicate()])
			await _click(app.continue_button)
			_check(app.route_view.is_visible_in_tree() and sewing.summary.text.contains(drop), "Continue retains visible wearer")
			_reject_patch(callback, "stale sew after Continue")
		_check(observations.size() == 2, "both earned drops actually sewn")
		if session == 0:
			replay = observations.duplicate(true)
		else:
			_check(observations == replay, "same-seed replay reproduces complete wardrobe and reward state")
		# Existing Elite suite independently verifies exact Shop stock and RNG.
		var old_carry: RunTornCarryover = app.party_carryover
		await _click(app.route_back_button)
		_check(old_carry._wardrobe == null, "return clears even the retained carryover binding")
		_check(sewing.wardrobe == null and sewing.hero_buttons.is_empty() and sewing.summary.text.is_empty(), "title resets companion completely")
		for callback in retained:
			callback.call()
		_check(sewing.wardrobe == null and app.run_trinkets.is_empty() and app.run_scraps == 0
			and app.run_map == null and app.title_view.visible, "old callbacks cannot restore a title-state assignment")
		_check(randi() == global_next, "claim, sewing, negatives and reset preserve global RNG")
	await _finish_sewing()


func _reward_oracle_after_prepare(service: RunMultiFightRewards) -> Dictionary:
	return {"offers": app.fight_reward_offers.duplicate(true), "gold": app.fight_reward_gold,
		"drop": app.fight_reward_trinket, "state": service.read_state(), "rng": app.run_rng.state}


func _test_context_refresh(state: Dictionary) -> void:
	var definitions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/initial_patch_slots.json"))
	for pair in [["stitched_badge", "HEAD"], ["spare_spool", "ARM"]]:
		_check(definitions.filter(func(entry): return entry.id == pair[0] and entry.slot == pair[1]).size() == 1,
			"unique authored slot for " + pair[0])
	var foreign := RunPatchWardrobe.new(state.heroes, ["foreign_patch"], definitions,
		state.scraps, state.gold, state.cards, state.seed, true)
	_check(foreign.is_valid(), "actual current heroes admit foreign inventory without inferring a slot")
	var before := foreign.get_snapshot()
	_check(not foreign.sew("foreign_patch", "warden", "HEAD", "foreign", before).ok
		and not foreign.sew("stitched_badge", "warden", "HEAD", "unowned", before).ok
		and foreign.get_snapshot() == before, "foreign and absent eligible IDs preserve full ledger")
	_check(not foreign.refresh_run_context(state.heroes, [], state.scraps, state.gold, state.cards, before)
		and foreign.get_snapshot() == before, "refresh cannot remove previous ownership")
	var stale := before.duplicate(true)
	stale.gold += 1
	_check(not foreign.refresh_run_context(state.heroes, ["foreign_patch", "stitched_badge"],
		state.scraps, state.gold, state.cards, stale) and foreign.get_snapshot() == before,
		"refresh rejects stale receipt atomically")
	_check(foreign.refresh_run_context(state.heroes, ["foreign_patch", "stitched_badge"],
		state.scraps, state.gold, state.cards, before), "guarded refresh adds actual owned eligible ID")
	var fresh := foreign.get_snapshot()
	_check(foreign.sew("stitched_badge", "warden", "HEAD", "first", fresh).ok,
		"first sew with current heroes is free")
	var worn := foreign.get_snapshot()
	_check(foreign.refresh_run_context(state.heroes, ["foreign_patch", "stitched_badge", "spare_spool"],
		state.scraps, state.gold, state.cards, worn), "later context refresh accepts additional ownership")
	_check(foreign.get_snapshot().worn == worn.worn
		and foreign.get_snapshot().operation_ids == worn.operation_ids
		and foreign.get_snapshot().owned.has("foreign_patch"), "refresh retains worn slots, receipts and foreign inventory")


func _finish_sewing() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_elite_patch_sewing_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
