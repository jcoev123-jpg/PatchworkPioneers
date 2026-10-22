extends "res://tests/live_routed_battle_reentry_test.gd"
## Real title -> won Fight -> connected Fight with authentic run-owned sewing.
## All attack assertions use physical held panels and the mounted presenter.

var worn_wardrobe: RunPatchWardrobe


func _panel(id: String) -> Control:
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and panel.get_child(0).text == id:
			return panel
	return null


func _hover(control: Control) -> void:
	var away := InputEventMouseMotion.new()
	away.position = Vector2(2, 2)
	root.push_input(away, true)
	await _frames()
	var event := InputEventMouseMotion.new()
	event.position = control.get_global_rect().get_center()
	root.push_input(event, true)
	await _frames()


func _live_state() -> Array:
	var active: Variant = null
	var latch: Variant = null
	if presenter._play._patches != null:
		active = presenter._play._patches.active_snapshot()
		latch = presenter._play._patches.latch_snapshot()
	return [app.run_heroes.duplicate(true), app.run_deck.duplicate(),
		app.run_trinkets.duplicate(), app.run_scraps, app.session_gold,
		app.party_carryover.read_state(), app.party_carryover.torn.read_state(),
		worn_wardrobe.get_snapshot() if worn_wardrobe != null else null,
		app.run_seed, app.run_rng.seed, app.run_rng.state,
		app.run_map.get_route(), app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_intents.get_intents(), app.enemy_intents._turn_index,
		app.battle_result.get_outcome(), presenter._play._tinker._consumed,
		active, latch, presenter.last_event.duplicate(true)]


func _bind_authored(owner: String, torn_owner: bool = false) -> bool:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	_check(records is Array, "authored attack patch catalog is an array")
	if not records is Array:
		return false
	var definitions := []
	var owned := []
	for entry in records:
		if not entry is Dictionary or entry.get("id") not in ["button_eye", "pincushion_arm"]:
			continue
		var slot := "HEAD" if entry.id == "button_eye" else "ARM"
		_check(not owned.has(entry.id) and entry.get("slot") == slot
			and entry.get("amount") == 1
			and entry.get("effect") == (
				"first_attack_exposed" if entry.id == "button_eye" else "card_attack_bonus"),
			"required patch IDs have unique exact authored effects and slots")
		if owned.has(entry.id):
			return false
		definitions.append({"id": entry.id, "slot": slot})
		owned.append(entry.id)
	_check(owned.has("button_eye") and owned.has("pincushion_arm"),
		"both required authored patches are present without assuming a catalog size")
	if not owned.has("button_eye") or not owned.has("pincushion_arm"):
		return false
	for id in owned:
		app.run_trinkets.append(id)
	var carry := app.party_carryover as RunTornCarryover
	_check(carry != null and carry.is_valid() and carry.torn.is_valid()
		and carry.read_state().heroes == app.run_heroes,
		"actual routed carryover agrees with authentic persistent heroes")
	if carry == null:
		return false
	worn_wardrobe = RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		definitions, app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	_check(worn_wardrobe.is_valid(), "authoritative sewn run ledger is valid")
	if not worn_wardrobe.is_valid():
		return false
	var expected := worn_wardrobe.get_snapshot()
	var first := worn_wardrobe.sew("button_eye", owner, "HEAD", "owned-head", expected)
	_check(first.ok and first.receipt.patch_id == "button_eye", "genuine HEAD receipt")
	if not first.ok:
		return false
	expected = worn_wardrobe.get_snapshot()
	var second := worn_wardrobe.sew("pincushion_arm", owner, "ARM", "owned-arm", expected)
	_check(second.ok and second.receipt.patch_id == "pincushion_arm", "genuine ARM receipt")
	if not second.ok:
		return false
	expected = worn_wardrobe.get_snapshot()
	_check(carry.can_bind_wardrobe(worn_wardrobe, carry.torn, expected)
		and carry.bind_wardrobe(worn_wardrobe, carry.torn, expected)
		and carry._wardrobe == worn_wardrobe,
		"authentic latest receipt binds directly through run owner")
	var projection := worn_wardrobe.project_active(carry.torn.read_state())
	_check(projection.ok and projection.worn[owner].HEAD == "button_eye"
		and projection.worn[owner].ARM == "pincushion_arm"
		and projection.active[owner] == ([] if torn_owner else owned),
		"real sewn slots project only the living wearer")
	return carry._wardrobe == worn_wardrobe


func _ensure_held(id: String) -> bool:
	# Draw exclusively through the real deck. Never fabricate a card in hand.
	for attempt in range(4):
		if app.deck.hand.has(id):
			break
		while not app.deck.hand.has(id) and not app.deck.draw_pile.is_empty():
			_check(app.deck.draw_extra(1) == 1, "real seeded draw adds one held card")
		app._refresh_hand()
		await _frames()
		if app.deck.hand.has(id):
			break
		await _click(app.end_turn_button)
	_check(app.deck.hand.has(id) and _panel(id) != null and app.deck.energy > 0,
		"actual held and affordable " + id)
	return app.deck.hand.has(id) and _panel(id) != null and app.deck.energy > 0


func _physical_hit(id: String, position: int, keyboard: bool, damage: int,
		expected_statuses: Dictionary) -> void:
	if not await _ensure_held(id):
		return
	var panel = _panel(id)
	_check(panel.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(panel.get_global_rect()),
		"held attack panel is visible inside 1280x720")
	var forecast: Dictionary = presenter._resolve_attack(app.party, app.enemies, id, 0, true)
	_check(forecast.playable and position in forecast.hits.map(func(hit): return hit.position),
		"mounted attack authority forecasts real recipient")
	_check(await _choose(id, keyboard), "physical hand selection succeeded: " + id)
	var before := _live_state()
	var enemy: Dictionary = app.enemies.get_enemy(position)
	var cost: int = StarterCards.new().get_definition(id).cost
	if keyboard:
		await _key(KEY_1 if position == 1 else KEY_2)
	else:
		await _click(app.get_node("LiveEnemyRoster")._labels[position - 1])
	var event: Dictionary = presenter.last_event
	_check(event.get("ok", false) and event.hits.size() == 1
		and event.hits[0].damage == damage and event.hits[0].statuses == expected_statuses,
		"physical attack uses exact adjusted damage and confirmed statuses: " + id)
	var after: Dictionary = app.enemies.get_enemy(position)
	_check(app.deck.energy == before[15] - cost
		and app.deck.hand.count(id) == before[12].count(id) - 1
		and app.deck.discard_pile.count(id) == before[14].count(id) + 1,
		"one physical card charges energy and moves exactly once to discard")
	_check(after.block == maxi(0, enemy.block - damage)
		and after.hp == enemy.hp - maxi(0, damage - enemy.block)
		and app.run_rng.state == before[10],
		"real HP, Block, and run RNG agree with confirmed attack")
	_check(app.hand_view.get_child_count() == app.deck.hand.size()
		and app.get_node("LiveSupportHand").energy_label.text ==
			"Energy\n%d" % app.deck.energy, "mounted hand and energy redraw")
	_check(presenter.cue != null and presenter.cue.is_visible_in_tree()
		and Rect2(0, 0, 1280, 720).encloses(presenter.cue.get_global_rect()),
		"actual attack cue fits 1280x720")


func _entry(fixture: Dictionary, owner: String, downed: bool, keyboard: bool) -> bool:
	worn_wardrobe = null
	# Only the predecessor is terminally settled to reach a genuine connected
	# route quickly. Every asserted patch attack below hits a live next Fight.
	app.run_seed = fixture.seed
	await _click(app.route_button)
	await _click(_route_action(fixture.fight))
	_check(app.deck != null and app.deck.hand.size() == 5
		and app.encounter_id == "starter_attacks" and app.party.is_valid(),
		"seeded predecessor is the genuine authored opening Fight")
	if app.deck == null:
		return false
	if downed:
		_check(app.party.apply_damage(3, 9999) and app.party.is_downed(3),
			"authentic run downed Tinker before battle settlement")
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 9999), "settle predecessor, not tested target")
	app._observe_battle_result()
	await _frames()
	_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and app.reward_buttons.size() == 4, "connected predecessor genuinely settles victory")
	if app.reward_buttons.size() != 4:
		return false
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	_check(app.route_view != null and app.route_view.is_visible_in_tree()
		and app.party_carryover is RunTornCarryover,
		"rewarded Fight opens genuine connected-route chooser")
	if owner != "":
		if not _bind_authored(owner, downed):
			return false
	var action: Button = _route_action(fixture.path.back())
	_check(action != null and not action.disabled, "next Fight is an authentic connected choice")
	if action == null:
		return false
	if owner != "":
		# A stale wardrobe must be rejected before a new battle is mounted.
		var current_hp: int = worn_wardrobe._heroes[0].hp
		var preentry := _live_state()
		worn_wardrobe._heroes[0].hp = current_hp - 1
		var stale := _live_state()
		action.pressed.get_connections()[0].callable.call()
		_check(_live_state() == stale and app.route_view != null
			and app.run_rng.state == preentry[10],
			"stale authoritative wearer ledger rejects real route callback atomically")
		worn_wardrobe._heroes[0].hp = current_hp
	if keyboard:
		action.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(action)
	_check(app.route_view == null and app.battle_view.is_visible_in_tree()
		and app.party.is_valid() and app.deck.hand.size() == 5
		and app.deck.energy == 3 and presenter._deck == app.deck,
		"seeded routed Fight mounts active five-card hand and presenter")
	if app.route_view != null or presenter._deck != app.deck:
		return false
	if owner == "":
		_check(presenter._play._patches == null, "unworn baseline stays genuinely unbound")
	else:
		var patches: CombatPatchAttackRules = presenter._play._patches
		var projection := worn_wardrobe.project_active(app.party_carryover.torn.read_state())
		_check(patches != null and patches.is_valid()
			and patches.active_snapshot() == projection.active
			and patches.latch_snapshot().get(owner) == false,
			"connected presenter's single attack service sees exact sewn wearer projection")
	return true


func _quick_fixture() -> Dictionary:
	# Direct adjacent Fight selection avoids an expansive recursive path search.
	for value in range(1, 300):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for first in map.get_legal_choices():
			if map.get_node(first).type != "Fight":
				continue
			for next in map.get_node(first).outgoing:
				if map.get_node(next).type != "Fight":
					continue
				map.choose_node(first)
				var entry := RunAuthoredBattleEntry.new().entry_current_battle(
					map, rng, RunFightEncounterSelection.new())
				if entry.get("encounter_id") == "starter_attacks":
					return {"seed": value, "fight": first, "path": [next]}
				map.undo_choice(first, [])
	return {}


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _quick_fixture()
	_check(not fixture.is_empty() and fixture.path.size() == 1,
		"generated route has legal direct next Fight after starter opening")
	if fixture.is_empty():
		await _finish_patch_play()
		return
	for scenario in ["plain_before", "seamstress", "other", "tinker", "torn", "plain_after"]:
		var replay: Array = []
		for keyboard in ([false, true] if scenario == "seamstress" else [false]):
			var owner := "" if scenario.begins_with("plain") else ("tinker" if scenario in ["tinker", "torn"] else "seamstress")
			if not await _entry(fixture, owner, scenario == "torn", keyboard):
				_check(false, "connected fixture mounted: " + scenario)
				break
			var patches: CombatPatchAttackRules = presenter._play._patches
			seed(408040)
			var global_next := randi()
			seed(408040)
			if scenario.begins_with("plain"):
				if await _ensure_held("seamstress_prick"):
					await _hover(_panel("seamstress_prick"))
					_check(presenter.cue.text.contains("3 damage") and not presenter.cue.text.contains("Exposed"),
						"unbound vanilla forecast has authored starter damage")
					await _physical_hit("seamstress_prick", 1, keyboard, 3, {"bleed": 3})
					_check(app.enemies.get_enemy(1).get("statuses", {}).get("exposed", 0) == 0,
						"unbound Prick never applies invented Button Eye")
			elif scenario == "torn":
				_check(app.party.is_downed(3) and patches.active_snapshot().tinker.is_empty()
					and patches.damage_bonus("tinker") == 0
					and patches.exposed_for_first_hit("tinker").is_empty(),
					"genuinely torn sewn wearer stays inactive")
				if await _ensure_held("tinker_pop_shot"):
					var closed := _live_state()
					_check(not presenter._resolve_attack(app.party, app.enemies,
						"tinker_pop_shot", 1).ok and _live_state() == closed,
						"downed owner cannot cast or spend")
				if await _ensure_held("warden_strike"):
					await _physical_hit("warden_strike", 1, keyboard, 6, {})
			elif scenario == "other":
				if await _ensure_held("warden_strike"):
					var unpatched: Dictionary = presenter._resolve_attack(
						app.party, app.enemies, "warden_strike", 0, true)
					_check(unpatched.playable and unpatched.hits[0].damage == 6,
						"other hero forecasts base damage despite sewn wearer")
					await _physical_hit("warden_strike", 1, keyboard, 6, {})
					_check(app.enemies.get_enemy(1).get("statuses", {}).get("exposed", 0) == 0
						and not patches.latch_snapshot().seamstress,
						"other hero real hit cannot borrow Button Eye or spend wearer's latch")
			elif scenario == "tinker":
				if await _ensure_held("tinker_pop_shot"):
					await _hover(_panel("tinker_pop_shot"))
					_check(presenter.cue.text.contains("9 damage")
						and presenter.cue.text.contains("Exposed"),
						"bound first Tinker forecast visibly includes both powers")
					await _physical_hit("tinker_pop_shot", 1, keyboard, 9, {"exposed": 1})
					_check(patches.latch_snapshot().tinker and not patches.latch_snapshot().warden,
						"first valid Tinker hit consumes only his battle latch")
					_check(patches.damage_bonus("seamstress") == 0, "patch damage is owner-only")
			else:
				if await _ensure_held("seamstress_prick"):
					_check(await _choose("seamstress_prick", keyboard), "first Prick is truly armed")
					var rejected := _live_state()
					presenter._queue_attack(4) # No shipped enemy slot four.
					_check(_live_state() == rejected and not patches.latch_snapshot().seamstress,
						"wrong-target physical shortcut and invalid callback preserve all ledgers")
					app.deck.combat_state.energy = 0
					var no_energy := _live_state()
					presenter._queue_attack(1)
					await _key(KEY_1)
					_check(_live_state() == no_energy and not patches.latch_snapshot().seamstress,
						"insufficient-energy physical attempt does not latch or mutate")
					app.deck.combat_state.energy = 3
					await _hover(_panel("seamstress_prick"))
					_check(presenter.cue.text.contains("4 damage") and presenter.cue.text.contains("Exposed"),
						"patch forecast names owner-only damage and pending confirmed-hit Exposed")
					await _physical_hit("seamstress_prick", 1, keyboard, 4,
						{"bleed": 3, "exposed": 1})
					_check(app.enemies.get_enemy(1).statuses == {"bleed": 3, "exposed": 1}
						and patches.latch_snapshot().seamstress,
						"actual Prick applies passive Bleed and exactly one Exposed")
					if await _ensure_held("seamstress_prick"):
						# Any Exposed already on the recipient affects damage, but must
						# never be applied again by Button Eye in this same combat.
						var target := 1
						var before_status: Dictionary = app.enemies.get_enemy(target).statuses
						var expected_damage := 6 # The previous hit left Exposed 1.
						await _physical_hit("seamstress_prick", target, keyboard,
							expected_damage, {"bleed": 3})
						_check(app.enemies.get_enemy(target).statuses.get("exposed", 0)
							== before_status.get("exposed", 0)
							and patches.latch_snapshot().seamstress,
							"second actual wearer attack cannot restack Button Eye")
					_check(patches.damage_bonus("warden") == 0
						and patches.exposed_for_first_hit("warden").is_empty(),
						"other hero never inherits sewn patch powers")
					# Begin a new player turn without creating a new battle:
					# Tinker's passive resets, but Button Eye must remain spent.
					await _click(app.end_turn_button)
					_check(patches.latch_snapshot().seamstress,
						"new owner turn does not refresh combat-long Button Eye latch")
			_check(randi() == global_next, "all patches and physical inputs avoid global RNG")
			var observation := _live_state()
			if not replay.is_empty():
				_check(observation == replay, "same seeded routed mouse/keyboard full state replay: " + scenario)
			else:
				replay = observation
			await _click(app.return_button)
			_check(presenter._battle == null and presenter._bindings.is_empty()
				and presenter._play._patches == null and not presenter._play._tinker._consumed
				and app.party_carryover == null and app.deck == null,
				"Return disconnects battle, wardrobe and the entire per-battle attack latch")
	await _finish_patch_play()


func _finish_patch_play() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_worn_attack_patch_play_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
