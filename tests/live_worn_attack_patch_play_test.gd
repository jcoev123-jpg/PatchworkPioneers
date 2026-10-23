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
		active, latch, presenter.last_event.duplicate(true),
		presenter._fray.latch_snapshot() if presenter._fray != null else null,
		presenter._unravel.get_snapshot(1) if presenter._unravel != null else {}]


## A genuine run-owned ARM receipt, separate from the existing M04 patch
## scenarios. The persistent wardrobe is sewn before entering the next Fight.
func _bind_mitt(owner: String) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m05_attack_patches.json"))
	_check(source is Array and not source.is_empty(), "M05 authored patch catalog")
	if not source is Array:
		return false
	var found := []
	for record in source:
		if record.get("id") == "frayfinder_mitt":
			found.append(record)
	_check(found.size() == 1 and found[0].get("slot") == "ARM"
		and found[0].get("amount") == 2, "unique canonical M05 ARM mitt")
	if found.size() != 1:
		return false
	app.run_trinkets.append("frayfinder_mitt")
	var carry := app.party_carryover as RunTornCarryover
	if carry == null or not carry.is_valid():
		return false
	worn_wardrobe = RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		[{"id": "frayfinder_mitt", "slot": "ARM"}], app.run_scraps,
		app.session_gold, app.run_deck, app.run_seed, true)
	if not worn_wardrobe.is_valid():
		return false
	var sewn := worn_wardrobe.sew("frayfinder_mitt", owner, "ARM",
		"authentic_m05_sew", worn_wardrobe.get_snapshot())
	var expected := worn_wardrobe.get_snapshot()
	_check(sewn.get("ok", false) and sewn.receipt.patch_id == "frayfinder_mitt"
		and carry.can_bind_wardrobe(worn_wardrobe, carry.torn, expected)
		and carry.bind_wardrobe(worn_wardrobe, carry.torn, expected),
		"genuine M05 receipt bound by actual run carryover")
	return sewn.get("ok", false) and carry._wardrobe == worn_wardrobe


## Rest's canonical two-owner stitch transaction is committed to the run deck,
## rather than forging a stitched hand instance or detached half descriptor.
func _prepare_live_stitch(first_id: String, second_id: String) -> String:
	var first: int = app.run_deck.find(first_id)
	var second: int = app.run_deck.find(second_id)
	_check(first >= 0 and second >= 0 and first != second,
		"two distinct owned starter instances available for genuine Rest stitching")
	if first < 0 or second < 0 or first == second:
		return ""
	app.run_scraps += RunRestStitchCards.SCRAP_COST
	var rest := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors,
		app.run_scraps, app.run_next_stitch_id)
	var result := rest.choose_stitch(first, second, rest.get_snapshot())
	_check(result.get("ok", false) and result.descriptor.owners[0] != result.descriptor.owners[1]
		and result.descriptor.cost == 2, "Rest service creates ordered two-owner cost-2 composite")
	if not result.get("ok", false):
		return ""
	app.run_deck.assign(result.deck)
	app.run_stitch_descriptors = result.descriptors.duplicate(true)
	app.run_scraps = result.remaining_scraps
	app.run_next_stitch_id = result.next_stitch_id
	return result.stitched_id


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
	var coats: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_coat_patches.json"))
	_check(coats is Array and RunPatchCoatRules._valid_authored(coats),
		"authoritative authored COAT catalog has the real max-HP power")
	if coats is Array and RunPatchCoatRules._valid_authored(coats):
		definitions.append({"id": RunPatchCoatRules.BONUS_ID, "slot": "COAT"})
		owned.append(RunPatchCoatRules.BONUS_ID)
	_check(owned.has("button_eye") and owned.has("pincushion_arm")
		and owned.has(RunPatchCoatRules.BONUS_ID),
		"all required HEAD/ARM/COAT IDs are authored without catalog-size assumptions")
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
	var coat := worn_wardrobe.sew(RunPatchCoatRules.BONUS_ID, owner,
		"COAT", "owned-coat", expected)
	_check(coat.ok and coat.receipt.patch_id == RunPatchCoatRules.BONUS_ID,
		"genuine authored COAT receipt")
	if not coat.ok:
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


## Inspect the real mounted CombatMeters controls, not a detached presenter service.
## Expected ownership comes from the bound ledger; current HP and position from battle.
func _assert_worn_chips(owner: String) -> void:
	var meter_node = app.get_node("LiveCombatMeters")
	_check(meter_node.row != null and meter_node.row.get_child_count() >= 5,
		"routed battle has physically mounted combat ribbons")
	if meter_node.row == null:
		return
	var snapshot: Dictionary = worn_wardrobe.get_snapshot() if worn_wardrobe != null else {}
	var owner_slots: Dictionary = snapshot.get("worn", {}).get(owner, {})
	var current: Array[Dictionary] = app.party.get_heroes()
	var expected_effects := {
		"button_eye": "First successful attack in this combat also applies Exposed %d." % CombatPatchAttackRules.EFFECTS["button_eye"]["amount"],
		"pincushion_arm": "Damage-dealing cards owned by this wearer deal +%d damage." % CombatPatchAttackRules.EFFECTS["pincushion_arm"]["amount"],
		RunPatchCoatRules.BONUS_ID: "+%d effective maximum HP while living; no free healing." % RunPatchCoatRules.BONUS}
	var expected_names := {"button_eye": "Button Eye", "pincushion_arm": "Pincushion Arm",
		RunPatchCoatRules.BONUS_ID: "Quilted Coat"}
	var seen_ids := {}
	for position in range(1, 4):
		var hero: Dictionary = current[position - 1]
		var meter := meter_node.row.get_child(position - 1) as CombatActorMeter
		var row := meter.get_node_or_null("Padding/Content/PatchButtons") as HBoxContainer
		var expected: bool = owner == hero["id"] and not owner_slots.is_empty()
		_check(row != null and row.visible == expected and row.get_child_count() == 3,
			"only actual patched wearer has a visible row at current position %d" % position)
		if row == null:
			continue
		var slots: Dictionary = snapshot.get("worn", {}).get(hero["id"], {})
		for slot in RunPatchWardrobe.SLOTS:
			var chip := row.get_node("Patch" + slot) as Button
			var id: String = slots.get(slot, "")
			_check(chip.visible == not id.is_empty() and chip.text == (slot if not id.is_empty() else ""),
				"sewn %s slot and no empty slot follow hero %s" % [slot, hero["id"]])
			if id.is_empty():
				_check(chip.tooltip_text.is_empty(), "empty slot has no stale tooltip")
				continue
			seen_ids[id] = true
			var tooltip: String = chip.tooltip_text
			var condition := "ACTIVE" if hero["hp"] > 0 else "DORMANT"
			var exact := "%s (%s)\n%s (%s) — %s\n%s\n%s" % [
				hero["name"], hero["id"], expected_names.get(id, id), id, slot,
				condition, expected_effects.get(id, "")]
			_check(tooltip == exact,
				"hover exactly names %s, %s, %s and authored power" % [hero["id"], id, condition])
			_check(chip.is_visible_in_tree() and chip.focus_mode == Control.FOCUS_NONE
				and chip.mouse_filter == Control.MOUSE_FILTER_STOP
				and chip.mouse_default_cursor_shape == Control.CURSOR_HELP
				and chip.pressed.get_connections().is_empty()
				and Rect2(0, 0, 1280, 720).encloses(chip.get_global_rect()),
				"routed sewn chip is visible, in viewport, hover-only and keyboard inert")
			await _hover(chip)
			_check(chip.get_global_rect().end.y <= app.find_child("PileCounts", true, false).get_global_rect().position.y,
				"patch chip never occupies the pile-count/hand HUD band")
			_check(root.gui_get_hovered_control() == chip,
				"physical pointer hits actual sewn %s patch on %s" % [slot, hero["id"]])
	for index in range(3, meter_node.row.get_child_count()):
		var enemy_meter := meter_node.row.get_child(index) as CombatActorMeter
		_check(enemy_meter.get_node_or_null("Padding/Content/PatchButtons") == null,
			"enemy ribbon never receives a patch chip row")
	if owner != "":
		_check(seen_ids.has("button_eye") and seen_ids.has("pincushion_arm")
			and seen_ids.has(RunPatchCoatRules.BONUS_ID) and seen_ids.size() == 3,
			"genuine HEAD, ARM, COAT are visible exactly once")


func _probe_patch_refresh(owner: String) -> void:
	var meter_node = app.get_node("LiveCombatMeters")
	var initial := _live_state()
	var ids := []
	for meter in meter_node.row.get_children():
		if not meter is CombatActorMeter:
			continue
		var row := meter.get_node_or_null("Padding/Content/PatchButtons") as HBoxContainer
		if row != null:
			ids.append([row.get_instance_id(), row.get_child(0).get_instance_id(),
				row.get_child(1).get_instance_id(), row.get_child(2).get_instance_id()])
	for repeat in range(4):
		meter_node._sync_battle()
		await _frames()
	_check(_live_state() == initial, "multiple mounted patch refreshes leave full combat, ledger and RNG alone")
	var after := []
	for meter in meter_node.row.get_children():
		if not meter is CombatActorMeter:
			continue
		var row := meter.get_node_or_null("Padding/Content/PatchButtons") as HBoxContainer
		if row != null:
			after.append([row.get_instance_id(), row.get_child(0).get_instance_id(),
				row.get_child(1).get_instance_id(), row.get_child(2).get_instance_id()])
	_check(ids == after, "repeated sync reuses each patch row and every chip")
	await _assert_worn_chips(owner)


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
	_check(presenter.cue.is_visible_in_tree()
		and Rect2(0, 0, 1280, 720).encloses(presenter.cue.get_global_rect()),
		"selected attack cue fits 1280x720")
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
			"%d" % app.deck.energy, "mounted hand and energy redraw")
	_check(presenter.cue != null and presenter.cue.text == ""
		and not presenter.cue.is_visible_in_tree(),
		"committed attack retires the idle attack cue")


func _entry(fixture: Dictionary, owner: String, downed: bool, keyboard: bool,
		mitt: bool = false, stitch_pair: Array = []) -> bool:
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
	if not stitch_pair.is_empty():
		_check(stitch_pair.size() == 2 and not _prepare_live_stitch(stitch_pair[0], stitch_pair[1]).is_empty(),
			"genuine Rest descriptor ready before routed battle")
	if owner != "":
		if not (_bind_mitt(owner) if mitt else _bind_authored(owner, downed)):
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
	if not mitt:
		await _probe_patch_refresh(owner)
	else:
		_check(presenter._fray != null and presenter._fray.is_valid()
			and presenter._fray._unravel == presenter._unravel
			and presenter._fray._deck == app.deck
			and presenter._fray._party == app.party
			and presenter._fray._enemies == app.enemies
			and presenter._fray._turn_open,
			"real presenter binds Frayfinder to routed battle/deck/round Unravel")
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


## Mounted Frayfinder: the very same shared CombatUnravel used by RoundFlow
## gates actual physical hand damage, not a second scene-free fake attack.
func _mitt_starter_cases(fixture: Dictionary) -> void:
	for scenario in ["at_half", "below_half", "other_owner", "torn", "status"]:
		var owner := "tinker" if scenario in ["other_owner", "torn"] else (
			"warden" if scenario == "status" else "seamstress")
		if not await _entry(fixture, owner, scenario == "torn", false, true):
			_check(false, "M05 starter routed fixture entered: " + scenario)
			continue
		var mitt: CombatFrayfinderMitt = presenter._fray
		var gauge: CombatUnravel = presenter._unravel
		var attack_id := "tinker_pop_shot" if scenario == "torn" else (
			"warden_strike" if scenario in ["other_owner", "status"] else "seamstress_prick")
		if not await _ensure_held(attack_id):
			await _click(app.return_button)
			continue
		var charge := 3 if scenario == "below_half" else 4
		_check(gauge.apply_unravel(app.enemies, 1, charge)
			and app.round_flow._unravel == gauge
			and gauge.get_snapshot(1).gauge == charge
			and gauge.get_snapshot(1).threshold == 8,
			"actual routed RoundFlow authority receives %d/8 charge" % charge)
		var before := _live_state()
		var quote: Dictionary = mitt.quote_starter_hit(attack_id, 1)
		var expected := 2 if scenario in ["at_half", "status"] else 0
		_check(quote.get("bonus") == expected and quote == mitt.quote_starter_hit(attack_id, 1)
			and _live_state() == before and mitt.latch_snapshot().is_empty(),
			"live quote is read-only and respects gauge, sewn owner and torn state: " + scenario)
		if scenario == "torn":
			_check(app.party.is_downed(3) and not presenter._resolve_attack(
				app.party, app.enemies, attack_id, 1).get("ok", false)
				and _live_state() == before, "torn Tinker cannot commit or spend the mitt")
		elif scenario == "other_owner":
			await _physical_hit("warden_strike", 1, false, 6, {})
			_check(mitt.latch_snapshot().is_empty(),
				"other owner's confirmed starter cannot consume Tinker's mitt")
			if await _ensure_held("tinker_pop_shot"):
				_check(gauge.apply_unravel(app.enemies, 2, 4),
					"second original enemy obtains real half gauge")
				await _physical_hit("tinker_pop_shot", 2, false, 10, {})
				_check(mitt.latch_snapshot() == {"tinker": true},
					"wearer's first Tinker hit includes +3 native and +2 mitt independently")
		elif scenario == "below_half":
			_check(await _choose("seamstress_prick", false), "below-half card physically armed")
			var rejected := _live_state()
			presenter._queue_attack(4)
			_check(_live_state() == rejected and mitt.latch_snapshot().is_empty(),
				"invalid mounted target fails atomically without a latch")
			await _physical_hit("seamstress_prick", 1, false, 3, {"bleed": 3})
			_check(mitt.latch_snapshot().is_empty(),
				"below-half genuine attack leaves entitlement untouched")
			if await _ensure_held("seamstress_prick"):
				_check(gauge.apply_unravel(app.enemies, 1, 1),
					"same live gauge rises from 3/8 to 4/8")
				await _physical_hit("seamstress_prick", 1, false, 5, {"bleed": 3})
				_check(mitt.latch_snapshot() == {"seamstress": true},
					"next qualifying wearer attack earns +2 exactly once")
		elif scenario == "status":
			app.party._heroes[0]["statuses"] = {"weak": 1}
			_check(app.enemies.apply_statuses({1: {"exposed": 1}}),
				"real status authorities apply Weak and Exposed")
			var damaged: int = CombatStatuses.new().adjusted_attack_damage(
				8, {"weak": 1}, {"exposed": 1})
			var vanilla: int = CombatStatuses.new().adjusted_attack_damage(
				6, {"weak": 1}, {"exposed": 1})
			_check(damaged == 9 and vanilla == 6,
				"mitt base +2 enters BEFORE combined 9/8 Weak/Exposed rounding")
			await _physical_hit("warden_strike", 1, false, damaged, {})
			_check(mitt.latch_snapshot() == {"warden": true},
				"status-adjusted genuine hit consumes one Warden latch")
		else:
			await _physical_hit("seamstress_prick", 1, false, 5, {"bleed": 3})
			_check(mitt.latch_snapshot() == {"seamstress": true}
				and not mitt.consume_confirmed_hit(quote, presenter.last_event),
				"augmented real receipt consumes once and replay is rejected")
			if await _ensure_held("seamstress_prick"):
				await _physical_hit("seamstress_prick", 1, false, 3, {"bleed": 3})
				_check(mitt.latch_snapshot() == {"seamstress": true},
					"second genuine same-turn wearer hit cannot reapply +2")
			var previous_turn: int = app.enemy_intents._turn_index
			await _click(app.end_turn_button)
			await _frames()
			_check(app.enemy_intents._turn_index == previous_turn + 1
				and app.deck.turn_active and mitt.latch_snapshot().is_empty()
				and mitt._unravel == app.round_flow._unravel,
				"real ended/started player turn resets only the mitt latch")
			if await _ensure_held("seamstress_prick"):
				_check(app.enemies.get_enemy(2).hp > 0 and gauge.apply_unravel(
					app.enemies, 2, 4) and gauge.get_snapshot(2).gauge >= 4,
					"second live-turn recipient receives same authoritative half gauge")
				await _physical_hit("seamstress_prick", 2, false, 5, {"bleed": 3})
				_check(mitt.latch_snapshot() == {"seamstress": true},
					"new real turn permits exactly one fresh +2 confirmed hit")
		await _click(app.return_button)
		_check(presenter._fray == null and presenter._unravel == null,
			"title retires both linked battle services: " + scenario)


## Genuine Rest descriptors, held illustrated composite face, two physical
## target selections, per-owner staged effects, and only one real spend/discard.
func _mitt_stitched_cases(fixture: Dictionary) -> void:
	for scenario in ["first", "second", "support_second", "target_free_first"]:
		var support: bool = scenario == "support_second"
		var target_free: bool = scenario == "target_free_first"
		var owner := "tinker" if scenario == "first" else "warden"
		var pair := ["seamstress_mend", "warden_strike"] if support else (
			["tinker_tune_up", "warden_strike"] if target_free else [
			"tinker_pop_shot", "warden_strike"])
		if not await _entry(fixture, owner, false, false, true, pair):
			_check(false, "stitched mounted fixture entered: " + scenario)
			continue
		var id := ""
		for card_id in app.run_stitch_descriptors:
			id = card_id
		_check(not id.is_empty() and app.run_stitch_descriptors.has(id),
			"actual Rest descriptor belongs to mounted run")
		if id.is_empty() or not await _ensure_held(id):
			await _click(app.return_button)
			continue
		var preview: Dictionary = presenter._stitch_preview(id)
		var mitt: CombatFrayfinderMitt = presenter._fray
		var gauge: CombatUnravel = presenter._unravel
		_check(preview.get("playable", false) and preview.halves.size() == 2
			and preview.halves[0].owner != preview.halves[1].owner,
			"physical stitched face recognizes distinct ordered owner halves")
		_check(gauge.apply_unravel(app.enemies, 1, 4),
			"stitched real target one has half authoritative gauge")
		if not support:
			_check(gauge.apply_unravel(app.enemies, 2, 4),
				"stitched real target two has half authoritative gauge")
		else:
			_check(app.party.apply_damage(3, 9), "support's ally is genuinely wounded")
		var before_hand: Array = app.deck.hand.duplicate()
		var before_discard: Array = app.deck.discard_pile.duplicate()
		var before_energy: int = app.deck.energy
		var before_rng: int = app.run_rng.state
		var before_party: Array = app.party.get_heroes()
		var before_enemies: Array = app.enemies.get_enemies()
		var first_quote: Dictionary = mitt.quote_stitched_half(
			presenter._ledger(), id, 0, 1)
		var second_quote: Dictionary = mitt.quote_stitched_half(
			presenter._ledger(), id, 1, 1 if support else 2)
		_check(first_quote.get("bonus", 0) == (2 if scenario == "first" else 0)
			and second_quote.get("bonus", 0) == (2 if scenario != "first" else 0),
			"each genuine attacking half quotes only its actual sewn owner")
		# A later invalid half must roll back the FIRST tentative half too.
		var rollback_before := _live_state()
		var rejected: Dictionary = CombatStitchedCards.new(presenter._play).play_stitched(
			app.deck, app.party, app.enemies, presenter._ledger(), id,
			3 if support else (0 if target_free else 1), 9, mitt)
		_check(not rejected.get("ok", false) and _live_state() == rollback_before,
			"rejected late composite half rolls back both effects and all latches")
		_check(await _choose(id, false) and presenter._armed == _panel(id),
			"mounted stitched face arms through physical input")
		var refuse := _live_state()
		presenter._choose_stitch(9)
		_check(_live_state() == refuse and mitt.latch_snapshot().is_empty(),
			"invalid later-half target cannot spend, damage or latch")
		if not target_free:
			await _key(KEY_3 if support else KEY_1)
		await _key(KEY_1 if support or target_free else KEY_2)
		var receipt: Dictionary = presenter.last_event
		_check(receipt.get("ok", false) and receipt.halves.size() == 2,
			"physical two-half stitched commit returns authentic ordered receipt")
		if receipt.get("ok", false):
			if target_free:
				_check(receipt.halves[0].get("effect") == "draw"
					and not receipt.halves[0].has("hits")
					and receipt.halves[1].hits[0].damage == 8
					and receipt.halves[1].hits[0].position == 1,
					"target-free Tinker draw takes no mitt bonus; second Warden attack takes +2")
			elif support:
				_check(receipt.halves[0].get("effect") == "ally_heal"
					and not receipt.halves[0].has("hits")
					and app.party.get_hero(3).hp == before_party[2].hp + 5,
					"support half authentic heal occurs before attacking half")
				_check(receipt.halves[1].hits[0].damage == 8
					and receipt.halves[1].hits[0].position == 1,
					"second attacking Warden half deals +2 base")
			else:
				var first_damage := 10 if scenario == "first" else 8
				var second_damage := 8 if scenario == "second" else 6
				_check(receipt.halves[0].hits[0].damage == first_damage
					and receipt.halves[1].hits[0].damage == second_damage
					and receipt.halves[0].hits[0].position == 1
					and receipt.halves[1].hits[0].position == 2,
					"ordered Tinker/Warden halves retain independent native passive and mitt")
			_check(app.deck.energy == before_energy - 2
				and app.deck.hand.count(id) == before_hand.count(id) - 1
				and app.deck.discard_pile.count(id) == before_discard.count(id) + 1
				and (target_free or app.run_rng.state == before_rng)
				and app.enemies.get_enemies() != before_enemies
				and mitt.latch_snapshot() == {owner: true},
				"composite spends/discards once, no bonus RNG and confirms only wearer latch")
			var latched := _live_state()
			_check(not mitt.consume_confirmed_hit(
				first_quote if scenario == "first" else second_quote,
				receipt, presenter._ledger()) and _live_state() == latched,
				"stitched replay receipt cannot spend the wearer a second time")
		await _click(app.return_button)
		_check(presenter._fray == null, "stitched battle return retires M05 latch")


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
			if scenario == "seamstress":
				var original := _live_state()
				var movement := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
				_check(movement.ok and movement.heroes[0].id == "seamstress",
					"authentic legal swap moves sewn Seamstress from middle to front")
				if movement.ok:
					for index in range(3):
						app.party._heroes[index] = movement.heroes[index].duplicate(true)
					await _frames()
					await _assert_worn_chips(owner)
					var backward := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
					_check(backward.ok, "genuine reverse swap is legal")
					if backward.ok:
						for index in range(3):
							app.party._heroes[index] = backward.heroes[index].duplicate(true)
					await _frames()
					_check(_live_state() == original,
						"two real legal position changes restore full ledger and RNG")
					await _assert_worn_chips(owner)
				# Invalid authored metadata in a bound ledger fails closed, then recovers.
				var unchanged := _live_state()
				worn_wardrobe._definitions["button_eye"] = "ARM"
				var forged := _live_state()
				await _frames()
				for index in range(3):
					_check(not app.get_node("LiveCombatMeters").row.get_child(index)
						.get_node("Padding/Content/PatchButtons").visible,
						"invalid bound patch definition hides every hero patch row")
				_check(_live_state() == forged, "invalid snapshot rejection has no game-state effects")
				worn_wardrobe._definitions["button_eye"] = "HEAD"
				await _frames()
				_check(_live_state() == unchanged, "restoring source also restores exact run state")
				await _assert_worn_chips(owner)
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
			if scenario in ["seamstress", "tinker"]:
				var wearer_position := 0
				for hero in app.party.get_heroes():
					if hero.id == owner:
						wearer_position = hero.position
				_check(wearer_position > 0 and not app.party.is_downed(wearer_position),
					"living sewn wearer can be downed in this same live fight")
				if wearer_position > 0 and not app.party.is_downed(wearer_position):
					_check(app.party.apply_damage(wearer_position, 9999),
						"real CombatParty damage downs previously active sewn wearer")
					var fallen := _live_state()
					await _frames()
					await _assert_worn_chips(owner)
					_check(_live_state() == fallen,
						"mid-combat downing suppresses visible powers with no presenter mutation")
			_check(randi() == global_next, "all patches and physical inputs avoid global RNG")
			var observation := _live_state()
			if not replay.is_empty():
				_check(observation == replay, "same seeded routed mouse/keyboard full state replay: " + scenario)
			else:
				replay = observation
			await _click(app.return_button)
			_check(app.get_node("LiveCombatMeters").row == null
				and app.find_children("PatchButtons", "HBoxContainer", true, false).is_empty(),
				"Return destroys sewn rows and their hover bindings")
			_check(presenter._battle == null and presenter._bindings.is_empty()
				and presenter._play._patches == null and not presenter._play._tinker._consumed
				and app.party_carryover == null and app.deck == null,
				"Return disconnects battle, wardrobe and the entire per-battle attack latch")
	await _mitt_starter_cases(fixture)
	await _mitt_stitched_cases(fixture)
	await _finish_patch_play()


func _finish_patch_play() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_worn_attack_patch_play_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
