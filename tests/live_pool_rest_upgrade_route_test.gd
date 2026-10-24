extends "res://tests/live_rest_upgrade_choice_test.gd"
## Real earned pool reward -> Rest selection/upgrade -> next connected Fight cast.
## Reuses the mounted Rest harness and its atomic rejection helpers.


func _pool_fixtures(limit: int) -> Array:
	var fixtures: Array = []
	for value in range(1, 6000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var opening_rng := rng.state
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for rest in map.get_node(fight).outgoing:
				if map.get_node(rest).type != "Rest":
					continue
				for next in map.get_node(rest).outgoing:
					if map.get_node(next).type != "Fight":
						continue
					var selector := RunFightEncounterSelection.new()
					rng.state = opening_rng
					map.choose_node(fight)
					var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
					map.undo_choice(fight, [])
					if selected.get("encounter_id") == "starter_attacks":
						fixtures.append({"seed": value, "fight": fight, "rest": rest, "next": next})
						break
				if not fixtures.is_empty() and fixtures.back().get("seed") == value:
					break
			if not fixtures.is_empty() and fixtures.back().get("seed") == value:
				break
		if fixtures.size() >= limit:
			break
	return fixtures


## Bases the live attack preview can actually resolve today. Derived from the
## mounted resolvers so this fixture never hard-codes a catalog total.
func _mounted_base_ids() -> Array[String]:
	var ids: Array[String] = []
	for card_id in CombatPoolPlainStrikes.SUPPORTED_IDS:
		var id := String(card_id)
		if not id.ends_with("_plus") and not ids.has(id):
			ids.append(id)
	for card_id in CombatWardenPoolHeavyAttacks.SUPPORTED_CARD_IDS:
		var id := String(card_id)
		if not id.ends_with("_plus") and not ids.has(id):
			ids.append(id)
	return ids


func _mounted_playable_offer_index() -> int:
	for index in range(app.fight_reward_offers.size()):
		var offer: Dictionary = app.fight_reward_offers[index]
		if _mounted_base_ids().has(String(offer.get("id", ""))):
			return index
	return -1


func _plus_definition(base_id: String) -> Dictionary:
	var base: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(base_id)
	var plus_id := String(base.get("upgrade_id", ""))
	match String(base.get("owner", "")):
		"warden":
			return WardenPoolCards.new().get_definition(plus_id)
		"seamstress":
			return SeamstressPoolCards.new().get_definition(plus_id)
		"tinker":
			return TinkerPoolCards.new().get_definition(plus_id)
	return {}


## Deterministic, independent rendering of the authored plus effects. Mirrors
## the documented label contract so the test never trusts the app's own text.
func _authored_effect_text(effects: Dictionary) -> String:
	var parts: PackedStringArray = []
	var keys: Array = effects.keys()
	keys.sort()
	for key in keys:
		var value: Variant = effects[key]
		var label := String(key).replace("_", " ")
		if value is bool:
			if value:
				parts.append(label)
		elif value is int:
			parts.append("%d %s" % [value, label])
		elif value is String:
			parts.append("%s %s" % [label, String(value).replace("_", " ")])
	return ", ".join(parts)


func _select_mouse_row(choices: OptionButton, row: int) -> void:
	var tile = _tile_for("upgrade", row)
	_check(tile != null, "earned pool row owns one sewn upgrade tile")
	if tile == null:
		return
	await _click_tile(tile)
	_check(choices.selected == row, "physical pointer selects the earned pool row")
	_check(_visit_tiles().tile_details(tile).selected, "chosen earned row is visibly selected")


func _select_keyboard_row(choices: OptionButton, row: int) -> void:
	var tile = _tile_for("upgrade", row)
	_check(tile != null, "earned pool row owns one sewn upgrade tile")
	if tile == null:
		return
	await _select_tile_by_key(tile)
	_check(choices.selected == row, "physical keys select the earned pool row")
	_check(_visit_tiles().tile_details(tile).selected, "chosen earned row is visibly selected")


func _play_earned_pool(session: int, plus_id: String, plus_def: Dictionary) -> Array:
	while not app.deck.hand.has(plus_id) and not app.deck.draw_pile.is_empty():
		_check(app.deck.draw_extra(1) == 1, "real next-battle draw reaches the upgraded pool copy")
	app._refresh_hand()
	await _frames()
	_check(app.deck.hand.has(plus_id), "upgraded pool copy is actually held in the next connected Fight")
	if not app.deck.hand.has(plus_id):
		return []
	var preview := CombatAttackTargeting.new().get_preview(app.deck, app.party, app.enemies, plus_id)
	_check(preview.get("playable", false) and preview.get("requires_selection", false)
		and not preview.get("target_positions", []).is_empty(), "mounted live preview admits the authored upgraded pool cast")
	if not preview.get("playable", false) or preview.get("target_positions", []).is_empty():
		return []
	var target: int = int(preview.target_positions[0])
	var owner_position := 0
	for hero in app.party.get_heroes():
		if hero.get("id") == String(plus_def.get("owner", "")):
			owner_position = int(hero.get("position", 0))
	_check(owner_position > 0 and app.party.get_hero(owner_position).get("statuses", {}).is_empty()
		and app.enemies.get_enemy(target).get("statuses", {}).is_empty(),
		"authored plus damage is unmodified in the fresh next Fight")
	var enemy: Dictionary = app.enemies.get_enemy(target)
	var energy: int = app.deck.energy
	var hand: Array = app.deck.hand.duplicate()
	var discard: Array = app.deck.discard_pile.duplicate()
	var draw: Array = app.deck.draw_pile.duplicate()
	var rng_state: int = app.run_rng.state
	if await _choose(plus_id, session == 1):
		await _key([KEY_1, KEY_2, KEY_3][target - 1])
	var hits: Array = presenter.last_event.get("hits", [])
	_check(presenter.last_event.get("ok", false) and not hits.is_empty()
		and int(hits[0].get("damage", 0)) == int(plus_def.effects.damage),
		"real held input resolves exact authored plus damage")
	_check(app.deck.energy == energy - int(plus_def.cost)
		and app.deck.hand == _without(hand, plus_id)
		and app.deck.discard_pile == discard + [plus_id]
		and app.deck.draw_pile == draw and app.run_rng.state == rng_state,
		"standard single charge/discard preserves remaining piles and RNG")
	var expected_hits: int = int(plus_def.effects.get("hits", 1))
	var total_loss := 0
	for hit in hits:
		total_loss += int(hit.get("hp_loss", 0))
	_check(hits.size() >= 1 and hits.size() <= expected_hits
		and app.enemies.get_enemy(target).hp == int(enemy.hp) - total_loss,
		"actual recipient loses exactly the authored sequential damage")
	if plus_def.effects.has("block"):
		_check(presenter.last_event.get("block_deltas", {}) == {owner_position: int(plus_def.effects.block)},
			"authored self Block is applied as its own effect")
	return [presenter.last_event.duplicate(true), app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.run_rng.state]


func _without(cards: Array, card_id: String) -> Array:
	var result: Array = cards.duplicate()
	result.erase(card_id)
	return result


func _pool_route_session(chosen: Dictionary, reward_index: int, keyboard: bool) -> Array:
	var base_id := String(app.fight_reward_offers[reward_index].id)
	var offer_owner := String(app.fight_reward_offers[reward_index].owner)
	var base_def: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(base_id)
	var plus_def := _plus_definition(base_id)
	var plus_id := String(base_def.get("upgrade_id", ""))
	_check(not base_def.is_empty() and not plus_def.is_empty()
		and plus_def.get("id") == plus_id and plus_def.get("owner") == offer_owner
		and _mounted_base_ids().has(base_id),
		"earned reward is a real authored pool base with a mounted resolver")
	if base_def.is_empty() or plus_def.is_empty():
		return []
	if keyboard:
		app.reward_buttons[reward_index].grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(app.reward_buttons[reward_index])
	_check(app.fight_reward_claimed and app.run_deck.count(base_id) == 1
		and app.run_deck.back() == base_id, "claimed earned pool base enters the single shared run deck")
	var gold_after_reward: int = app.session_gold
	var scraps_after_reward: int = app.run_scraps
	await _click(app.continue_button)
	var rest_button := _route_action(chosen.rest)
	_check(rest_button != null and not rest_button.disabled, "connected Rest remains actionable after the earned reward")
	if rest_button == null:
		return []
	if keyboard:
		rest_button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(rest_button)
	_check(app.rest_view != null and app.rest_upgrade != null and is_instance_valid(app.rest_upgrade_cards),
		"real connected Rest mounts the upgrade service for the earned deck")
	if app.rest_upgrade == null or not is_instance_valid(app.rest_upgrade_cards):
		return []
	_bounds(app.rest_view)
	var choices: OptionButton = app.rest_upgrade_cards
	var visit: RunRestCardUpgrade = app.rest_upgrade
	var button: Button = app.rest_upgrade_button
	var upgrade: Callable = button.pressed.get_connections()[0].callable
	var heal: Callable = app.rest_heal_button.pressed.get_connections()[0].callable
	var next: Callable = app.rest_continue_button.pressed.get_connections()[0].callable
	var source: Array = app.run_deck.duplicate()
	var heroes: Array = app.run_heroes.duplicate(true)
	var ledger: Dictionary = app.party_carryover.read_state()
	var pool_index: int = source.size() - 1
	_check(pool_index >= 0 and source[pool_index] == base_id, "earned base keeps its actual zero-based deck index")
	var canonical: Dictionary = RunRestCardUpgrade.list_authored_choices(
		app.run_deck, app.run_stitch_descriptors, app.run_next_stitch_id)
	_check(canonical.get("ok", false) and canonical.get("choices") is Array
		and canonical.get("permitted_upgrades") is Dictionary,
		"visit projects canonical authored choices from the live deck and ledger")
	if not canonical.get("ok", false):
		return []
	_check(canonical.choices == app._rest_upgrade_choices
		and canonical.permitted_upgrades == visit._upgrades,
		"mounted selector and visit hold this visit's canonical projection")
	var rows: Array = canonical.choices
	var expected_indices: Array = []
	for index in range(app.run_deck.size()):
		if app.run_deck[index] in ["warden_strike", "warden_brace", "seamstress_mend",
				"seamstress_stitch_up", base_id]:
			expected_indices.append(index)
	var shown_indices: Array = []
	var pool_row := -1
	for item in range(rows.size()):
		var row: Dictionary = rows[item]
		var row_index := int(row.get("index", -1))
		shown_indices.append(row_index)
		_check(app.run_deck[row_index] == String(row.get("base_id", "")),
			"each row owns its actual deck copy")
		_check(not String(row.get("source_id", "")).ends_with("_plus"),
			"already-upgraded card is never offered")
		_check(not String(row.get("source_id", "")).begins_with(RunRestStitchCards.ID_PREFIX),
			"stitched card is never offered")
		if row_index == pool_index:
			pool_row = item
	_check(shown_indices == expected_indices and shown_indices.size() == expected_indices.size(),
		"exactly every owned upgradeable base is offered by real index")
	_check(pool_row >= 0 and choices.item_count == rows.size(), "earned base owns one visible selector row")
	if pool_row < 0:
		return []
	var row: Dictionary = rows[pool_row]
	_check(String(row.get("source_id", "")) == base_id and String(row.get("plus_id", "")) == plus_id
		and String(row.get("owner", "")) == offer_owner, "earned base maps to its canonical authored plus")
	_check(String(row.get("display_name", "")) == String(base_def.get("display_name", ""))
		and String(row.get("plus_display_name", "")) == String(plus_def.get("display_name", ""))
		and int(row.get("plus_cost", -1)) == int(plus_def.get("cost", -1))
		and row.get("plus_effects", {}) == plus_def.get("effects", {}),
		"row carries the authored base/+ name, cost and effect")
	var expected_text := "Deck #%d: %s -> %s (%d energy; %s)" % [pool_index + 1,
		String(base_def.get("display_name", "")), String(plus_def.get("display_name", "")),
		int(plus_def.get("cost", 0)), _authored_effect_text(plus_def.get("effects", {}))]
	_check(choices.get_item_text(pool_row) == expected_text
		and choices.get_item_text(pool_row).contains(String(base_def.get("display_name", "")))
		and choices.get_item_text(pool_row).contains(String(plus_def.get("display_name", ""))),
		"visible row is exactly the authored base -> canonical plus reading")
	for item in range(rows.size()):
		var item_index := int(rows[item].get("index", -1))
		_check(choices.get_item_metadata(item) == item_index
			and choices.get_item_text(item) == app._rest_upgrade_text(item_index)
			and not choices.is_item_disabled(item), "each visible row identifies its own deck index")
	_check(choices.item_count == rows.size() and choices.selected >= 0 and not button.disabled,
		"complete authorized selector is actionable")
	_check(not heal.is_null() and not next.is_null(), "exclusive Heal and Continue callbacks are mounted")
	_reject_upgrade(next, "premature Continue before the earned pool upgrade")
	app._rest_committed_deck.assign(source)
	_reject_upgrade(upgrade, "forged partially committed earned deck")
	app._rest_committed_deck.clear()
	var foreign_mapping: Dictionary = {}
	foreign_mapping[base_id] = plus_id
	_reject_upgrade(app._upgrade_at_rest.bind(
		RunRestCardUpgrade.new(source, foreign_mapping), button, choices), "foreign earned visitor")
	_reject_upgrade(app._upgrade_at_rest.bind(visit, app.rest_heal_button, choices), "foreign action")
	var foreign := OptionButton.new()
	_reject_upgrade(app._upgrade_at_rest.bind(visit, button, foreign), "foreign selector")
	foreign.free()
	for invalid in [-1, source.size(), "12", 1.5, source.find("warden_brace")]:
		choices.set_item_metadata(pool_row, invalid)
		_reject_upgrade(upgrade, "forged earned index " + str(invalid))
	choices.set_item_metadata(pool_row, pool_index)
	choices.set_item_text(pool_row, "forged label")
	_reject_upgrade(upgrade, "forged earned label")
	choices.set_item_text(pool_row, expected_text)
	var canonical_mapping: Dictionary = visit._upgrades.duplicate(true)
	var wrong_mapping: Dictionary = canonical_mapping.duplicate(true)
	wrong_mapping[base_id] = "warden_brace"
	for mapping in [{}, wrong_mapping, {"warden_strike": "unknown"}]:
		visit._upgrades = mapping
		_reject_upgrade(upgrade, "altered earned mapping")
	visit._upgrades = canonical_mapping
	visit._valid = false
	_reject_upgrade(upgrade, "invalid earned visitor")
	visit._valid = true
	visit._consumed = true
	_reject_upgrade(upgrade, "forged consumed earned visitor")
	_reject_upgrade(next, "forged consumption cannot complete the Rest")
	visit._consumed = false
	visit._deck[pool_index] = "warden_brace"
	_reject_upgrade(upgrade, "forged earned visitor deck")
	visit._deck.assign(source)
	app.run_deck[pool_index] = "warden_brace"
	_reject_upgrade(upgrade, "changed live earned deck")
	app.run_deck.assign(source)
	var allocator: int = app.run_next_stitch_id
	app.run_next_stitch_id = allocator + 1
	_reject_upgrade(upgrade, "altered stitch allocator")
	app.run_next_stitch_id = allocator
	var descriptors: Dictionary = app.run_stitch_descriptors.duplicate(true)
	app.run_stitch_descriptors["stitched_000001"] = {"id": "stitched_000001"}
	_reject_upgrade(upgrade, "altered stitch ledger")
	app.run_stitch_descriptors = descriptors
	app.run_heroes[0].hp -= 1
	_reject_upgrade(upgrade, "changed party before earned upgrade")
	app.run_heroes = heroes.duplicate(true)
	app.session_gold += 1
	_reject_upgrade(upgrade, "changed gold before earned upgrade")
	app.session_gold -= 1
	var rng_state: int = app.run_rng.state
	app.run_rng.randi()
	_reject_upgrade(upgrade, "changed run RNG before earned upgrade")
	app.run_rng.state = rng_state
	for control in [button, choices, app.rest_view]:
		control.hide()
		_reject_upgrade(upgrade, "hidden earned input or visit")
		control.show()
	button.disabled = true
	_reject_upgrade(upgrade, "disabled earned action")
	button.disabled = false
	choices.disabled = true
	_reject_upgrade(upgrade, "disabled earned selector")
	choices.disabled = false
	if keyboard:
		await _select_keyboard_row(choices, pool_row)
	else:
		await _select_mouse_row(choices, pool_row)
	var committed: Array = source.duplicate()
	committed[pool_index] = plus_id
	if keyboard:
		var pool_tile = _tile_for("upgrade", pool_row)
		pool_tile.grab_focus()
		for step in range(_visit_tiles().upgrade_tiles().size() + 2):
			if button.has_focus():
				break
			await _key(KEY_TAB)
		_check(button.has_focus(), "Tab reaches the earned Upgrade action")
		await _key(KEY_ENTER)
	else:
		await _click(button)
	_check(visit.is_consumed() and app.run_deck == committed,
		"one physical input upgrades exactly the selected earned copy once")
	_check(app.run_scraps == scraps_after_reward and app.session_gold == gold_after_reward
		and app.run_heroes == heroes and app.party_carryover.read_state() == ledger
		and app.run_rng.state == rng_state and app.run_stitch_descriptors == descriptors
		and app.run_next_stitch_id == allocator,
		"earned upgrade preserves scraps, gold, HP, ledger, stitches and run RNG")
	_check(_without(app.run_deck, plus_id) == _without(source, base_id),
		"every other owned card copy is unchanged")
	_check(app.rest_heal_button.disabled and button.disabled and choices.disabled
		and not app.rest_continue_button.disabled, "consumed earned upgrade enables normal Continuation")
	_reject_upgrade(upgrade, "duplicate earned Upgrade")
	_reject_upgrade(heal, "Heal after earned Upgrade")
	if keyboard:
		app.rest_back_button.grab_focus()
		await _key(KEY_TAB)
		_check(app.rest_continue_button.has_focus(), "Tab reaches Continue after the earned upgrade")
		await _key(KEY_ENTER)
	else:
		await _click(app.rest_continue_button)
	_check(app.route_view != null and not app.rest_view.visible, "earned upgrade Continue opens the legal next chooser")
	_reject_upgrade(upgrade, "hidden prior earned Rest")
	var oracle := _oracle(chosen.next)
	_check(not oracle.is_empty(), "typed next-Fight oracle succeeds on the upgraded shared deck")
	if oracle.is_empty():
		return []
	var upgrades_before: Array = app.run_deck.duplicate()
	await _click(_route_action(chosen.next))
	_check(app.battle_result.get_outcome() == CombatBattleResult.ACTIVE and _mounted_state() == oracle,
		"next connected Fight mounts the upgraded shared deck and unchanged carried party")
	_check(app.run_deck == upgrades_before and app.run_deck[pool_index] == plus_id,
		"next connected Fight admits the upgraded pool ID unchanged")
	var play_state: Array = await _play_earned_pool(1 if keyboard else 0, plus_id, plus_def)
	_check(not play_state.is_empty(), "authored upgraded pool play completes in the real next Fight")
	var result: Array = [_persistent(), app.party_carryover.read_state()] + play_state
	await _click(app.return_button)
	_check(app.title_view.visible and app.run_map == null and app.deck == null and app.run_deck.is_empty()
		and app.rest_upgrade == null and app.rest_upgrade_cards == null and app.rest_upgrade_button == null
		and app._rest_upgrade_choices.is_empty() and app.run_rng == null,
		"Return after the earned route clears all run and upgrade state")
	upgrade.call()
	_check(app.run_map == null and app.run_deck.is_empty(), "post-title earned upgrade callback is inert")
	return result.duplicate(true)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixtures := _pool_fixtures(32)
	_check(not fixtures.is_empty(), "seeded graphs reach Fight -> Rest -> Fight with a starter encounter")
	var chosen: Dictionary = {}
	var reward_index := -1
	var replay: Array = []
	for session in range(2):
		seed(910091)
		var global_next := randi()
		seed(910091)
		if session == 0:
			for candidate in fixtures:
				if not await _routed_win(candidate, false):
					_check(false, "seeded routed victory wins its opening Fight")
					break
				var index := _mounted_playable_offer_index()
				if index >= 0:
					chosen = candidate
					reward_index = index
					break
				await _click(app.return_button)
				_check(app.title_view.visible and app.run_map == null and app.run_deck.is_empty(),
					"non-matching seeded reward run returns to a clean title")
			_check(not chosen.is_empty(), "a seeded routed victory earns a mounted-playable upgradeable pool base")
			if chosen.is_empty():
				break
		else:
			if not await _routed_win(chosen, false):
				_check(false, "same seeded fixture replays its routed victory")
				break
			_check(_mounted_playable_offer_index() == reward_index,
				"same seeded reward offering replays the same earned base index")
		var state := await _pool_route_session(chosen, reward_index, session == 1)
		if state.is_empty():
			break
		if session == 0:
			replay = state
		else:
			_check(state == replay, "same-seed mouse/keyboard replay matches the full earned route and cast")
		_check(randi() == global_next, "complete earned pool route consumes no global RNG")
	await _finish_pool_route()


func _finish_pool_route() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_pool_rest_upgrade_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
