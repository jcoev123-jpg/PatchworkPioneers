extends "res://tests/live_routed_battle_reentry_test.gd"
## Real title -> won Fight -> connected Fight with authentic run-owned sewing.
## All attack assertions use physical held panels and the mounted presenter.

const PartyChoice := preload("res://tests/party_choice.gd")
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
		presenter._unravel.get_snapshot(1) if presenter._unravel != null else {},
		presenter._play._tinker.path_bonus(),
		presenter._play._head_rules.read_projection() if presenter._play._head_rules != null else null]


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


## A P12 Needle Echo is worn before this genuine connected Fight, never
## put into Peddler stock and never substituted into an attack-only fixture.
func _bind_needle(owner: String) -> bool:
	var definitions: Array = RunAuthoredPatchDefinitions.load_definitions()
	_check(definitions.any(func(item): return item.get("id") == "needle_echo" and item.get("slot") == "HEAD"), "authored Needle Echo HEAD record exists")
	app.run_trinkets.append("needle_echo")
	var carry := app.party_carryover as RunTornCarryover
	if carry == null or not carry.is_valid():
		return false
	worn_wardrobe = RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		definitions, app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	if not worn_wardrobe.is_valid():
		return false
	var sewn: Dictionary = worn_wardrobe.sew("needle_echo", owner, "HEAD",
		"live_needle_echo_sew", worn_wardrobe.get_snapshot())
	var expected := worn_wardrobe.get_snapshot()
	_check(sewn.get("ok", false) and expected.worn[owner].HEAD == "needle_echo"
		and carry.can_bind_wardrobe(worn_wardrobe, carry.torn, expected)
		and carry.bind_wardrobe(worn_wardrobe, carry.torn, expected),
		"authentic worn HEAD Needle receipt bound to actual carryover")
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
	var expected_cost := mini(3, maxi(
		int(RunRestStitchCards.resolve_card_definition(first_id).cost),
		int(RunRestStitchCards.resolve_card_definition(second_id).cost)) + 1)
	_check(result.get("ok", false) and result.descriptor.owners[0] != result.descriptor.owners[1]
		and result.descriptor.cost == expected_cost,
		"Rest service creates ordered two-owner capped-cost composite")
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
		mitt: bool = false, stitch_pair: Array = [], scope: bool = false,
		head_status: bool = false, visor: String = "", heavy: bool = false,
		needle: bool = false, upgrade_strike: bool = false) -> bool:
	worn_wardrobe = null
	# Only the predecessor is terminally settled to reach a genuine connected
	# route quickly. Every asserted patch attack below hits a live next Fight.
	app.run_seed = fixture.seed
	if scope:
		# Make Sharpshot an authentic selected Path from the actual village.
		await _click(app.base_button)
		var village: BaseScreen = app.base_screen
		var sharpshot: Button = null
		if village != null:
			for button in village.tinker_buttons:
				if button.get_meta("path_id", "") == "sharpshot":
					sharpshot = button
					break
		_check(sharpshot != null and not sharpshot.disabled,
			"real village offers the Sharpshot Scope path")
		if sharpshot == null:
			return false
		await _click(sharpshot)
		_check(village.selected_tinker_path_id() == "sharpshot",
			"real village commits Sharpshot before the run")
		await _click(village.set_out_button)
		PartyChoice.choose(app)  # Cycle 345: Set out first asks for the party.
	else:
		await _click(app.route_button)
	await _click(_route_action(fixture.fight))
	_check(app.deck != null and app.deck.hand.size() == 5
		and app.encounter_id == "starter_attacks" and app.party.is_valid(),
		"seeded predecessor is the genuine authored opening Fight")
	if app.deck == null:
		return false
	if downed:
		var dpos := 1 if owner == "warden" else 3
		var dname := "Warden" if owner == "warden" else "Tinker"
		_check(app.party.apply_damage(dpos, 9999) and app.party.is_downed(dpos),
			"authentic run downed %s before battle settlement" % dname)
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
	if upgrade_strike:
		var slot: int = app.run_deck.find("warden_strike")
		var upgraded := RunRestCardUpgrade.new(app.run_deck,
			{"warden_strike": "warden_strike_plus"}).choose_upgrade(slot)
		_check(slot >= 0 and upgraded.get("ok", false)
			and upgraded.deck.has("warden_strike_plus"),
			"genuine upgraded Warden Strike+ joins owned run deck before Fight")
		if not upgraded.get("ok", false):
			return false
		app.run_deck.assign(upgraded.deck)
	if visor == "absent":
		# A genuinely unpatched run: the real deck owns both Rivet variants but
		# no wardrobe is ever bound for this battle.
		_own_rivets()
	if heavy:
		_own_heavy_cards()
	if owner != "":
		var bound := false
		if not visor.is_empty():
			bound = _bind_visor(owner, visor == "sewn")
		elif head_status:
			bound = _bind_head_statuses()
		elif needle:
			bound = _bind_needle(owner)
		elif mitt:
			bound = _bind_mitt(owner)
		else:
			bound = _bind_authored(owner, downed)
		if not bound:
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
	if head_status:
		var head_rules: CombatM05HeadPatchRules = presenter._play._head_rules
		_check(head_rules != null and head_rules.read_projection().ok
			and head_rules.read_projection().heads.warden.patch_id == "stern_seam_cap"
			and head_rules.read_projection().heads.seamstress.patch_id == "bloodstitch_bonnet",
			"live presenter shares both genuine battle-scoped M05 HEAD projections")
	elif visor == "sewn" or visor == "owned":
		# One battle-scoped projection must price BOTH the starter service and the
		# direct-fire resolver, so Rivet Shot and every starter card see one truth.
		var battle_heads: CombatM05HeadPatchRules = presenter._play._head_rules
		var direct_heads: CombatM05HeadPatchRules = presenter._direct_fire.get_head_patches()
		var projection: Dictionary = battle_heads.read_projection() if battle_heads != null else {}
		var expected_sewn: Dictionary = {} if visor == "owned" or downed else {
			"patch_id": "button_glass_visor", "effect": "card_exposed_bonus", "amount": 1}
		_check(battle_heads != null and direct_heads == battle_heads
			and projection.get("ok", false)
			and projection.get("heads", {}).get(owner, {}) == expected_sewn,
			"starter and direct-fire services share one authenticated HEAD projection")
	elif not mitt and not needle:
		await _probe_patch_refresh(owner)
	elif mitt:
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


## Sharpshot Scope's genuine +4 survives Frayfinder's authenticated stitched
## replay: the first sewn Tinker half gains 5 + 3 + 4 + 2, then is latched.
func _mitt_scope_stitched_case(fixture: Dictionary) -> void:
	if not await _entry(fixture, "tinker", false, false, true,
			["tinker_pop_shot", "warden_strike"], true):
		_check(false, "selected Scope + sewn mitt connected Fight entered")
		return
	var stitched_id := ""
	for id in app.run_stitch_descriptors:
		stitched_id = id
	_check(not stitched_id.is_empty() and presenter.tinker_ready()
		and app.run_tinker_path_receipt.get("path_id") == "sharpshot",
		"genuine run retains Sharpshot and a sewn Rest descriptor")
	if stitched_id.is_empty():
		await _click(app.return_button)
		return
	# Use real deck draws, never append synthetic cards to the hand.
	var held := await _ensure_held("tinker_scope")
	held = (await _ensure_held(stitched_id)) and held
	held = (await _ensure_held("tinker_pop_shot")) and held
	_check(held and app.deck.hand.has("tinker_scope")
		and app.deck.hand.has(stitched_id) and app.deck.hand.has("tinker_pop_shot"),
		"Scope, stitched Tinker first half and remaining Tinker hit are held together")
	if not held or not app.deck.hand.has("tinker_scope") or not app.deck.hand.has(stitched_id) or not app.deck.hand.has("tinker_pop_shot"):
		await _click(app.return_button)
		return
	var mitt: CombatFrayfinderMitt = presenter._fray
	var gauge: CombatUnravel = presenter._unravel
	_check(mitt._attacks == presenter._play and app.round_flow._unravel == gauge
		and gauge.apply_unravel(app.enemies, 1, 4)
		and gauge.apply_unravel(app.enemies, 2, 4),
		"one authenticated attack authority and genuine half-Unravel targets")
	# Play the selected zero-cost Path card through its actual mounted panel.
	var scope_energy: int = app.deck.energy
	var scope_rng: int = app.run_rng.state
	await _click(_panel("tinker_scope"))
	await _frames()
	_check(not app.deck.hand.has("tinker_scope")
		and app.deck.discard_pile.count("tinker_scope") == 1
		and app.deck.energy == scope_energy and app.run_rng.state == scope_rng
		and presenter._play._tinker.path_bonus() == 4
		and presenter._tinker_path.get_rules()._scope_armed,
		"physical zero-cost Scope arms +4 on the shared combat Tinker latch")
	var quote: Dictionary = mitt.quote_stitched_half(presenter._ledger(), stitched_id, 0, 1)
	var sealed: Dictionary = quote.duplicate(true)
	_check(quote.get("bonus") == 2 and quote.get("tinker_path_bonus_before") == 4
		and mitt.authorize_stitched_half(quote, app.deck, app.party, app.enemies,
			presenter._ledger(), stitched_id, 0, 1) == 2,
		"Frayfinder quote seals the genuine pre-commit +4 Scope state")
	sealed.tinker_path_bonus_before = 0
	_check(mitt.authorize_stitched_half(sealed, app.deck, app.party, app.enemies,
		presenter._ledger(), stitched_id, 0, 1) == 0,
		"changing the pending Scope bonus without resealing rejects a tampered quote")
	var before_failure := _live_state()
	var rollback: Dictionary = CombatStitchedCards.new(presenter._play).play_stitched(
		app.deck, app.party, app.enemies, presenter._ledger(), stitched_id, 1, 9, mitt)
	_check(not rollback.get("ok", false) and _live_state() == before_failure
		and presenter._play._tinker.path_bonus() == 4
		and mitt.latch_snapshot().is_empty(),
		"late second-half rejection rolls back both halves and pending Scope")
	var first_enemy: Dictionary = app.enemies.get_enemy(1)
	var second_enemy: Dictionary = app.enemies.get_enemy(2)
	var energy_before: int = app.deck.energy
	var discard_before: int = app.deck.discard_pile.count(stitched_id)
	var rng_before: int = app.run_rng.state
	var turn_before: int = app.enemy_intents._turn_index
	_check(await _choose(stitched_id, false), "real stitched face arms after Scope")
	await _key(KEY_1)
	await _key(KEY_2)
	var receipt: Dictionary = presenter.last_event
	_check(receipt.get("ok", false) and receipt.get("halves", []).size() == 2,
		"real held stitched hit confirms both ordered halves")
	if receipt.get("ok", false) and receipt.get("halves", []).size() == 2:
		_check(receipt.halves[0].hits[0].damage == 14
			and receipt.halves[1].hits[0].damage == 6
			and receipt.halves[0].hits[0].position == 1
			and receipt.halves[1].hits[0].position == 2
			and app.enemies.get_enemy(1).hp == maxi(0, first_enemy.hp - maxi(0, 14 - first_enemy.block))
			and app.enemies.get_enemy(2).hp == maxi(0, second_enemy.hp - maxi(0, 6 - second_enemy.block)),
			"first sewn Tinker half applies 5 printed +3 native +4 Scope +2 mitt")
	_check(app.deck.energy == energy_before - 2
		and app.deck.discard_pile.count(stitched_id) == discard_before + 1
		and not app.deck.hand.has(stitched_id) and app.run_rng.state == rng_before
		and presenter._play._tinker._consumed
		and presenter._play._tinker.path_bonus() == 0
		and mitt.latch_snapshot() == {"tinker": true},
		"Scope and mitt spent once, stitched card charges/discards once")
	_check(not mitt.consume_confirmed_hit(quote, receipt, presenter._ledger()),
		"sealed stitched receipt cannot latch twice after authentic +14 hit")
	# Same deck turn, second held eligible Tinker hit earns neither +4 nor +2.
	_check(app.deck.hand.has("tinker_pop_shot") and app.deck.energy == 1
		and app.enemies.get_enemy(2).hp > 5, "second wearer hit is really eligible this turn")
	if app.deck.hand.has("tinker_pop_shot") and app.enemies.get_enemy(2).hp > 5:
		await _physical_hit("tinker_pop_shot", 2, false, 5, {})
		_check(app.enemy_intents._turn_index == turn_before
			and mitt.latch_snapshot() == {"tinker": true}
			and presenter._play._tinker.path_bonus() == 0,
			"second same-turn physical wearer hit gets no extra +2 or Scope +4")
	await _click(app.return_button)
	_check(presenter._fray == null, "Scope stitched route retires its battle latch")


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
	await _mitt_scope_stitched_case(fixture)
	await _head_mounted_cases(fixture)
	await _visor_cases(fixture)
	await _mitt_heavy_cases(fixture)
	await _needle_mounted_cases(fixture)
	await _finish_patch_play()


func _finish_patch_play() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_worn_attack_patch_play_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Sew both authored status HEAD patches into the persistent routed run before
## battle entry. The owner binds the exact current receipt, not a test projection.
func _bind_head_statuses() -> bool:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m05_head_patches.json"))
	_check(raw is Array, "live authored M05 HEAD metadata loads")
	if not raw is Array:
		return false
	var expected := {
		"stern_seam_cap": {"effect": "card_weak_bonus", "amount": 1},
		"bloodstitch_bonnet": {"effect": "card_bleed_bonus", "amount": 1},
		"button_glass_visor": {"effect": "card_exposed_bonus", "amount": 1},
		"reinforced_browband": {"effect": "card_block_bonus", "amount": 2},
	}
	var definitions := []
	for id in expected:
		var matches: Array = raw.filter(func(entry): return entry is Dictionary and entry.get("id") == id)
		_check(matches.size() == 1 and matches[0].get("slot") == "HEAD"
			and matches[0].get("effect") == expected[id].effect
			and matches[0].get("amount") == expected[id].amount,
			"mounted real catalog records correct named HEAD power " + id)
		if matches.size() != 1:
			return false
		definitions.append({"id": id, "slot": "HEAD"})
	for id in ["stern_seam_cap", "bloodstitch_bonnet"]:
		app.run_trinkets.append(id)
	var carry := app.party_carryover as RunTornCarryover
	_check(carry != null and carry.is_valid() and carry.read_state().heroes == app.run_heroes,
		"routed M05 receipt uses real carried living roster")
	if carry == null:
		return false
	worn_wardrobe = RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		definitions, app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	_check(worn_wardrobe.is_valid(), "genuine M05 two-wearer wardrobe is valid")
	if not worn_wardrobe.is_valid():
		return false
	var warden := worn_wardrobe.sew("stern_seam_cap", "warden", "HEAD",
		"live_head_warden", worn_wardrobe.get_snapshot())
	var seamstress := worn_wardrobe.sew("bloodstitch_bonnet", "seamstress", "HEAD",
		"live_head_seamstress", worn_wardrobe.get_snapshot())
	_check(warden.get("ok", false) and seamstress.get("ok", false)
		and warden.receipt.patch_id == "stern_seam_cap"
		and seamstress.receipt.patch_id == "bloodstitch_bonnet"
		and warden.receipt.hero_id == "warden"
		and seamstress.receipt.hero_id == "seamstress",
		"distinct real sewn M05 HEAD receipts belong to original owners")
	var current: Dictionary = worn_wardrobe.get_snapshot()
	var projected := worn_wardrobe.project_active(carry.torn.read_state())
	_check(projected.ok and projected.worn.warden.HEAD == "stern_seam_cap"
		and projected.worn.seamstress.HEAD == "bloodstitch_bonnet"
		and projected.active.warden == ["stern_seam_cap"]
		and projected.active.seamstress == ["bloodstitch_bonnet"]
		and carry.can_bind_wardrobe(worn_wardrobe, carry.torn, current)
		and carry.bind_wardrobe(worn_wardrobe, carry.torn, current),
		"actual routed run owns both HEAD projections before next Fight")
	return carry._wardrobe == worn_wardrobe


func _head_mounted_cases(fixture: Dictionary) -> void:
	for scenario in ["bash_mouse", "prick_keyboard", "stitched_mouse", "stitched_keyboard"]:
		var stitched: bool = scenario.begins_with("stitched")
		var keyboard: bool = scenario.ends_with("keyboard")
		var pair := ["warden_shield_bash", "seamstress_prick"] if stitched else []
		if not await _entry(fixture, "warden", false, keyboard, false, pair, false, true):
			_check(false, "real connected M05 HEAD fixture entered: " + scenario)
			continue
		var head_rules: CombatM05HeadPatchRules = presenter._play._head_rules
		_check(head_rules != null and presenter._controls._head_rules == head_rules,
			"same HEAD object backs control and starter attack battle authorities")
		var before_refresh := _live_state()
		for repeated in range(3):
			app._refresh_hand()
			await _frames()
		_check(presenter._play._head_rules == head_rules
			and head_rules.read_projection().ok and _live_state() == before_refresh,
			"real three-time hand refresh preserves worn HEAD projection and full state")
		if not stitched:
			var id := "warden_shield_bash" if scenario == "bash_mouse" else "seamstress_prick"
			var amount := 2 if scenario == "bash_mouse" else 4
			var status := "weak" if scenario == "bash_mouse" else "bleed"
			var target := 1
			if await _ensure_held(id):
				var untouched := _live_state()
				await _hover(_panel(id))
				_check(presenter.cue.text.contains(status.capitalize() + " 0 → " + str(amount))
					and _live_state() == untouched,
					"mounted live status forecast shows exact sewn " + status + " counter without mutation")
				if status == "bleed":
					_check(await _choose(id, keyboard), "HEAD held Prick arms for stale-click check")
					var no_change := _live_state()
					presenter._queue_attack(4)
					_check(_live_state() == no_change and not presenter._queued,
						"illegal HEAD enemy target cannot queue or mutate")
					presenter._queue_attack(1)
					_check(presenter._queued, "real selected target schedules a HEAD commit")
					var original_enemy_id: String = app.enemies._enemies[0]["id"]
					app.enemies._enemies[0]["id"] = "substituted_enemy"
					await _frames()
					app.enemies._enemies[0]["id"] = original_enemy_id
					_check(_live_state() == no_change and not presenter._queued,
						"replaced enemy rejects deferred HEAD commit without spend/status/RNG")
				var required := {"weak": amount} if status == "weak" else {"bleed": amount}
				await _physical_hit(id, target, keyboard, 8 if status == "weak" else 3, required)
				_check(app.enemies.get_enemy(target).get("statuses", {}).get(status, 0) == amount,
					"held routed " + id + " commits exact HEAD status to its confirmed target")
			await _click(app.return_button)
			_check(presenter._play._head_rules == null,
				"return ends battle-scoped M05 HEAD projection")
			continue
		var stitch_id := ""
		for key in app.run_stitch_descriptors:
			stitch_id = key
		_check(not stitch_id.is_empty(), "Rest-created canonical stitched ID in routed run")
		if stitch_id.is_empty() or not await _ensure_held(stitch_id):
			await _click(app.return_button)
			continue
		var descriptor: Dictionary = app.run_stitch_descriptors[stitch_id]
		var preview: Dictionary = presenter._stitch_preview(stitch_id)
		_check(preview.playable and preview.halves.size() == 2
			and descriptor.half_ids == ["warden_shield_bash", "seamstress_prick"]
			and descriptor.owners == ["warden", "seamstress"] and descriptor.cost == 3
			and app.deck.energy == 3,
			"genuine Rest composites preserve ordered owner halves and capped 3-energy cost")
		var first_target := 1
		var second_target := 2
		_check(preview.halves[0].target_positions.has(first_target)
			and preview.halves[1].target_positions.has(second_target),
			"both original enemy slots are legal for sewn stitched halves")
		if not preview.halves[0].target_positions.has(first_target) \
				or not preview.halves[1].target_positions.has(second_target):
			await _click(app.return_button)
			continue
		var before := _live_state()
		var before_hand: Array = app.deck.hand.duplicate()
		var before_discard: Array = app.deck.discard_pile.duplicate()
		var before_foes: Array = app.enemies.get_enemies()
		var before_rng: int = app.run_rng.state
		var recorded: Array = []
		var capture := func():
			if presenter.current_forecast.get("playable", false) \
					and presenter.current_forecast.get("halves", []).size() == 2:
				recorded.append({"cue": presenter.cue.text,
					"forecast": presenter.current_forecast.duplicate(true),
					"enemies": app.enemies.get_enemies(),
					"rng": app.run_rng.state})
		presenter.forecast_updated.connect(capture)
		_check(await _choose(stitch_id, keyboard), "genuine held stitched face selected")
		if keyboard:
			await _key(KEY_1)
			await _key(KEY_2)
		else:
			await _click(app.get_node("LiveEnemyRoster")._labels[0])
			await _click(app.get_node("LiveEnemyRoster")._labels[1])
		if presenter.forecast_updated.is_connected(capture):
			presenter.forecast_updated.disconnect(capture)
		_check(not recorded.is_empty(), "mounted read-only stitched outcome forecast fired")
		if not recorded.is_empty():
			var seen: Dictionary = recorded.back()
			_check(seen.cue.contains("Weak 2") and seen.cue.contains("Bleed 4")
				and seen.forecast.halves[0].hits[0].statuses == {"weak": 2}
				and seen.forecast.halves[1].hits[0].statuses == {"bleed": 4}
				and seen.enemies == before_foes and seen.rng == before_rng,
				"two owner-specific on-hit HEAD counters forecast before staged commit")
		var event: Dictionary = presenter.last_event
		_check(event.get("ok", false) and event.get("halves", []).size() == 2,
			"physical stitched transaction resolves through real shared hand")
		if event.get("ok", false):
			_check(event.halves[0].hits == [{
				"position": first_target, "damage": 8, "block_absorbed": 0,
				"hp_loss": 8, "statuses": {"weak": 2}}]
				and event.halves[1].hits == [{
				"position": second_target, "damage": 3, "block_absorbed": 0,
				"hp_loss": 3, "statuses": {"bleed": 4}}],
				"stitched Warden then Seamstress resolve exact independent damage/statuses")
			_check(app.enemies.get_enemy(1).get("statuses", {}).get("weak", 0) == 2
				and app.enemies.get_enemy(2).get("statuses", {}).get("bleed", 0) == 4
				and app.deck.energy == before[15] - 3
				and app.deck.hand.count(stitch_id) == before_hand.count(stitch_id) - 1
				and app.deck.discard_pile.count(stitch_id) == before_discard.count(stitch_id) + 1
				and app.run_rng.state == before_rng,
				"one composite energy/discard, ordered target statuses and zero RNG spend")
		await _click(app.return_button)
		_check(presenter._play._head_rules == null,
			"stitched battle return retires the one shared HEAD authority")


## Both authored Rivet variants must be genuinely owned by the real run deck.
## Two copies each leave a real second held copy for a later attempt.
func _own_rivets() -> void:
	for id in ["tinker_rivet_shot", "tinker_rivet_shot_plus"]:
		for copy in range(2):
			app.run_deck.append(id)


## Genuine authored Button Glass Visor sewn (or merely owned) on the persistent
## run before the next routed Fight. Only the run owner binds the exact receipt.
func _bind_visor(owner: String, sew_visor: bool = true) -> bool:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m05_head_patches.json"))
	_check(raw is Array, "live authored M05 HEAD catalog loads for the visor")
	if not raw is Array:
		return false
	var visor: Array = raw.filter(func(entry): return entry is Dictionary and entry.get("id") == "button_glass_visor")
	_check(visor.size() == 1 and visor[0].get("slot") == "HEAD"
		and visor[0].get("effect") == "card_exposed_bonus"
		and visor[0].get("amount") == 1,
		"button_glass_visor is authored once as HEAD card_exposed_bonus 1")
	if visor.size() != 1:
		return false
	var definitions := []
	for entry in raw:
		if entry is Dictionary and entry.has("id") and entry.has("slot"):
			definitions.append({"id": entry["id"], "slot": entry["slot"]})
	_own_rivets()
	app.run_trinkets.append("button_glass_visor")
	if sew_visor:
		# The later genuine Rest re-sew must be affordable from real run scraps.
		app.run_scraps += 4
	var carry := app.party_carryover as RunTornCarryover
	_check(carry != null and carry.is_valid() and carry.read_state().heroes == app.run_heroes,
		"routed visor receipt uses the real carried roster")
	if carry == null:
		return false
	worn_wardrobe = RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		definitions, app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	_check(worn_wardrobe.is_valid() and worn_wardrobe.get_snapshot().scraps == app.run_scraps,
		"genuine M05 visor wardrobe is valid for the real run purse")
	if not worn_wardrobe.is_valid():
		return false
	if sew_visor:
		var sewn: Dictionary = worn_wardrobe.sew("button_glass_visor", owner, "HEAD",
			"live_visor_" + owner, worn_wardrobe.get_snapshot())
		_check(sewn.get("ok", false) and sewn.receipt.patch_id == "button_glass_visor"
			and sewn.receipt.hero_id == owner and sewn.receipt.slot == "HEAD",
			"genuine sewn HEAD receipt wears the visor on " + owner)
		if not sewn.get("ok", false):
			return false
	var current: Dictionary = worn_wardrobe.get_snapshot()
	var torn_state: Dictionary = carry.torn.read_state()
	var projected := worn_wardrobe.project_active(torn_state)
	var wearer_hp := 0
	for hero in torn_state.get("heroes", []):
		if hero.get("id") == owner:
			wearer_hp = int(hero.get("hp", 0))
	var expected_active: Array = ["button_glass_visor"] if sew_visor and wearer_hp > 0 else []
	_check(projected.get("ok", false)
		and projected.worn[owner].HEAD == ("button_glass_visor" if sew_visor else "")
		and projected.active[owner] == expected_active,
		"real head ledger projects exactly the visor sewn on " + owner)
	_check(carry.can_bind_wardrobe(worn_wardrobe, carry.torn, current)
		and carry.bind_wardrobe(worn_wardrobe, carry.torn, current),
		"routed run owner binds the genuine visor wardrobe")
	return carry._wardrobe == worn_wardrobe


## The exact authored Rivet records, read straight from the card catalog.
func _assert_rivet_record(id: String) -> Dictionary:
	var record := TinkerPoolCards.new().get_definition(id)
	var upgrade := id.ends_with("_plus")
	_check(record.get("id") == id and record.get("owner") == "tinker"
		and record.get("cost") == 1 and record.get("from_positions") == [2, 3]
		and record.get("to_positions") == [1, 2, 3]
		and record.get("target_kind") == "enemy_single"
		and int(record.effects.damage) == (6 if upgrade else 4)
		and int(record.effects.exposed) == 1,
		"authored " + id + " is cost 1, FROM 2-3, one enemy in 1-3, " +
			("6" if upgrade else "4") + " damage and authored Exposed 1")
	return record


## One genuinely held Rivet cast through the physical mounted hand: the live
## forecast and the confirmed hit must agree on exact damage and post-hit Exposed.
func _rivet_cast(id: String, target: int, damage: int, exposed_before: int,
		exposed_after: int, keyboard: bool = false) -> Dictionary:
	var record := _assert_rivet_record(id)
	if not await _ensure_held(id):
		return {}
	var panel := _panel(id)
	_check(panel != null and panel.is_visible_in_tree()
		and Rect2(0, 0, 1280, 720).encloses(panel.get_global_rect()),
		"held Rivet panel is mounted inside 1280x720: " + id)
	await _hover(panel)
	_check(presenter.cue.text.contains("Exposed %d → %d after hit" % [exposed_before, exposed_after]),
		"live cue projects the exact confirmed Exposed %d → %d" % [exposed_before, exposed_after])
	var preview: Dictionary = presenter._target_preview(id)
	var legal: Array = preview.get("target_positions", [])
	var hit: Dictionary = {}
	for candidate in preview.get("hits", []):
		if int(candidate.get("position", 0)) == target:
			hit = candidate
	_check(preview.get("playable", false) and legal.has(1) and legal.has(2)
		and target in legal and hit.get("damage") == damage
		and hit.get("exposed_before") == exposed_before
		and hit.get("exposed_after") == exposed_after,
		"live resolver forecast names the real living slots and exact outcome: " + id)
	var enemy: Dictionary = app.enemies.get_enemy(target)
	var before := _live_state()
	var held_before: int = app.deck.hand.count(id)
	var discard_before: int = app.deck.discard_pile.count(id)
	_check(enemy.get("statuses", {}) == ({"exposed": exposed_before} if exposed_before > 0 else {}),
		"the target holds no status before the confirmed " + id)
	_check(await _choose(id, keyboard), "physical hand selection arms the real " + id)
	var armed := _live_state()
	# The mounted battle may hold two or three real enemies: only a slot past
	# the actual roster is unoccupied, so it must not queue a cast or mutate.
	var illegal_slot: int = app.enemies.get_enemies().size() + 1
	presenter._queue_attack(illegal_slot)
	_check(not presenter._queued and _live_state() == armed,
		"an unoccupied enemy slot cannot queue the real " + id)
	_check(_live_state() == before and app.enemies.get_enemy(target).get("statuses", {})
		== enemy.get("statuses", {}) and app.deck.energy == before[15],
		"arming " + id + " charges no energy and applies no status")
	if keyboard:
		await _key(KEY_1 + target - 1)
	else:
		await _click(app.get_node("LiveEnemyRoster")._labels[target - 1])
	var event: Dictionary = presenter.last_event
	_check(event.get("ok", false) and event.get("hits", []).size() == 1
		and event.hits[0].position == target and event.hits[0].damage == damage
		and event.hits[0].statuses == {"exposed": exposed_after - exposed_before},
		"confirmed " + id + " reports exact damage and its Exposed rider")
	var after: Dictionary = app.enemies.get_enemy(target)
	_check(after.get("statuses", {}) == {"exposed": exposed_after}
		and after.hp == enemy.hp - maxi(0, damage - enemy.block)
		and after.block == maxi(0, enemy.block - damage),
		"post-hit target carries exactly Exposed " + str(exposed_after) + " after real damage")
	_check(app.deck.energy == before[15] - int(record.cost)
		and app.deck.hand.count(id) == held_before - 1
		and app.deck.discard_pile.count(id) == discard_before + 1
		and app.run_rng.state == before[10],
		"one held copy is charged once and discarded once without using run RNG")
	_check(presenter.cue != null and not presenter.cue.is_visible_in_tree(),
		"confirmed cast retires the idle attack cue")
	return event


## A genuine Rest re-sew that moves the sewn visor away from Tinker must leave
## the battle's HEAD authority stale: the cast is refused, never silently
## reverted to the unpatched authored Exposed 1.
func _visor_stale_authority() -> void:
	var head_rules: CombatM05HeadPatchRules = presenter._play._head_rules
	app.deck.combat_state.energy = 1
	var held := await _ensure_held("tinker_rivet_shot")
	_check(held and app.deck.hand.has("tinker_rivet_shot"),
		"a genuinely held second Rivet waits for the stale-authority attempt")
	if not held:
		return
	var opened: Dictionary = worn_wardrobe.start_rest("live_visor_rest", worn_wardrobe.get_snapshot())
	var moved: Dictionary = worn_wardrobe.re_sew("button_glass_visor", "tinker", "warden",
		"live_visor_rest", "live_visor_moved", worn_wardrobe.get_snapshot())
	_check(opened.get("ok", false) and moved.get("ok", false)
		and moved.receipt.patch_id == "button_glass_visor"
		and worn_wardrobe.get_snapshot().worn.warden.HEAD == "button_glass_visor"
		and worn_wardrobe.get_snapshot().worn.tinker.HEAD == "",
		"real Rest re-sew moves the sewn visor from Tinker to the Warden")
	app.run_scraps = worn_wardrobe.get_snapshot().scraps
	await _frames()
	_check(head_rules != null and head_rules == presenter._play._head_rules
		and presenter._direct_fire.get_head_patches() == head_rules
		and not head_rules.read_projection().get("ok", false),
		"the moved run ledger leaves the one battle-scoped HEAD authority stale")
	var frozen := _live_state()
	_check(not presenter._target_preview("tinker_rivet_shot").playable,
		"stale HEAD authority makes the mounted Rivet forecast unavailable")
	_check(await _choose("tinker_rivet_shot", false), "stale Rivet panel is still physically held")
	presenter._queue_attack(1)
	_check(not presenter._queued and _live_state() == frozen,
		"stale authority cannot queue, charge or apply the real held Rivet")
	_check(not presenter._resolve_attack(app.party, app.enemies,
		"tinker_rivet_shot", 1).get("ok", false) and _live_state() == frozen,
		"stale authority refuses the cast instead of a forged vanilla Exposed 1")
	var back: Dictionary = worn_wardrobe.re_sew("button_glass_visor", "warden", "tinker",
		"live_visor_rest", "live_visor_back", worn_wardrobe.get_snapshot())
	app.run_scraps = worn_wardrobe.get_snapshot().scraps
	_check(back.get("ok", false)
		and worn_wardrobe.get_snapshot().worn.tinker.HEAD == "button_glass_visor"
		and not presenter._play._head_rules.read_projection().get("ok", false),
		"re-sewing the same visor back never revives the stale battle authority")


## AC1: a genuine sewn visor on the living Tinker raises a real mounted Rivet
## Shot cast to Exposed 2 (authored 1 + HEAD 1), for base and upgrade.
func _visor_sewn_case(fixture: Dictionary, scenario: String) -> void:
	var id := "tinker_rivet_shot_plus" if scenario == "upgrade" else "tinker_rivet_shot"
	var damage := 9 if scenario == "upgrade" else 7
	if not await _entry(fixture, "tinker", false, scenario == "upgrade",
			false, [], false, false, "sewn"):
		_check(false, "genuine sewn visor routed fixture entered: " + scenario)
		return
	var head_rules: CombatM05HeadPatchRules = presenter._play._head_rules
	_check(presenter._direct_fire.get_first_attack() == presenter._play._tinker,
		"direct fire keeps the one shared Tinker first-attack latch: " + scenario)
	_check(head_rules != null and presenter._direct_fire.get_head_patches() == head_rules
		and head_rules.read_projection().get("ok", false)
		and head_rules.read_projection().heads.tinker.patch_id == "button_glass_visor",
		"the mounted battle authenticates one sewn visor HEAD projection for Tinker")
	for card_id in ["tinker_rivet_shot", "tinker_rivet_shot_plus"]:
		_check(head_rules.get_bonus("tinker", card_id, "exposed") == 1
			and int(_assert_rivet_record(card_id).effects.exposed) == 1,
			card_id + " authored Exposed 1 gains exactly the sewn visor 1")
	_check(head_rules.get_bonus("warden", id, "exposed") == 0
		and head_rules.get_bonus("tinker", "tinker_pop_shot", "exposed") == 0
		and head_rules.get_bonus("tinker", id, "bleed") == 0,
		"the visor never adds Exposed to another wearer, card or effect")
	# AC1 boundary: exactly one real energy still pays the cost-1 cast once.
	app.deck.combat_state.energy = 1
	var event := await _rivet_cast(id, 1, damage, 0, 2, scenario == "upgrade")
	_check(event.get("ok", false) and app.deck.energy == 0,
		"a single real energy pays for the sewn " + id)
	if scenario == "base":
		await _visor_stale_authority()
	await _click(app.return_button)
	_check(presenter._direct_fire.get_head_patches() == null
		and presenter._play._head_rules == null,
		"return retires the battle-scoped visor authority from both services")


## AC3: the same mounted battle keeps the one shared first-attack latch and the
## real Weak/Exposed flooring while the sewn rider stays attached.
func _visor_latch_case(fixture: Dictionary) -> void:
	if not await _entry(fixture, "tinker", false, false, false, [], false, false, "sewn"):
		_check(false, "shared-latch visor fixture entered")
		return
	var head_rules: CombatM05HeadPatchRules = presenter._play._head_rules
	_check(head_rules != null and head_rules.get_bonus("tinker", "tinker_rivet_shot", "exposed") == 1,
		"the latch battle starts with the genuine sewn visor rider")
	await _rivet_cast("tinker_rivet_shot", 1, 7, 0, 2)
	_check(presenter._play._tinker._consumed
		and presenter._direct_fire.get_first_attack()._consumed,
		"one confirmed Rivet consumes the single shared Tinker first-attack latch")
	app.party._heroes[2]["statuses"] = {"weak": 1}
	_check(app.enemies.apply_statuses({2: {"exposed": 1}}),
		"the second real target carries Exposed 1 before the upgraded Rivet")
	var plus := TinkerPoolCards.new().get_definition("tinker_rivet_shot_plus")
	var expected: int = CombatStatuses.new().adjusted_attack_damage(
		int(plus.effects.damage), {"weak": 1}, {"exposed": 1})
	_check(expected == 6, "independent rule oracle floors 6 under Weak and Exposed to 6")
	await _rivet_cast("tinker_rivet_shot_plus", 2, expected, 1, 3, true)
	_check(app.enemies.get_enemy(1).get("statuses", {}) == {"exposed": 2}
		and app.enemies.get_enemy(2).get("statuses", {}) == {"exposed": 3},
		"the Exposed each cast applies affects later hits, not the hit that made it")
	await _click(app.return_button)


## AC2: absent, owned-but-unworn, wrong-wearer and torn visors must never grant
## the rider; the unpatched legal Rivet keeps exactly its authored Exposed 1.
func _visor_negative_case(fixture: Dictionary, scenario: String) -> void:
	var owner := "" if scenario == "absent" else (
		"warden" if scenario == "other_owner" else "tinker")
	var visor := ""
	if scenario == "absent":
		visor = "absent"
	elif scenario == "unworn":
		visor = "owned"
	else:
		visor = "sewn"
	var downed := scenario == "torn"
	if not await _entry(fixture, owner, downed, false, false, [], false, false, visor):
		_check(false, "routed visor negative fixture entered: " + scenario)
		return
	var head_rules: CombatM05HeadPatchRules = presenter._play._head_rules
	if scenario == "absent":
		_check(head_rules == null and presenter._direct_fire.get_head_patches() == null,
			"an unpatched battle gives both mounted services no HEAD authority")
	else:
		# Prove the negative precondition instead of trusting an empty projection.
		var ledger: Dictionary = worn_wardrobe.get_snapshot()
		if scenario == "unworn":
			_check(ledger.owned.has("button_glass_visor")
				and ledger.worn.tinker.HEAD == "",
				"the unworn fixture really owns the visor without sewing it")
		elif scenario == "other_owner":
			_check(ledger.worn.warden.HEAD == "button_glass_visor"
				and ledger.worn.tinker.HEAD == "",
				"the wrong-wearer fixture really sews the visor on the Warden's HEAD")
		_check(head_rules != null and presenter._direct_fire.get_head_patches() == head_rules
			and head_rules.read_projection().get("ok", false)
			and head_rules.get_bonus("tinker", "tinker_rivet_shot", "exposed") == 0
			and head_rules.get_bonus("tinker", "tinker_rivet_shot_plus", "exposed") == 0,
			scenario + " leaves the living Tinker without any HEAD Exposed bonus")
	if scenario == "torn":
		_check(app.party.is_downed(3)
			and app.party_carryover.torn.read_state().heroes[2].hp == 0,
			"the torn precondition really holds in the run ledger")
		if await _ensure_held("tinker_rivet_shot"):
			var frozen := _live_state()
			_check(not presenter._target_preview("tinker_rivet_shot").playable
				and not presenter._resolve_attack(app.party, app.enemies,
					"tinker_rivet_shot", 1).get("ok", false)
				and _live_state() == frozen
				and app.enemies.get_enemy(1).get("statuses", {}) == {},
				"a torn wearer is refused, never a forged vanilla Exposed 1")
	else:
		await _rivet_cast("tinker_rivet_shot", 1, 7, 0, 1)
	await _click(app.return_button)


## M05 Button Glass Visor through the real mounted hand.
func _visor_cases(fixture: Dictionary) -> void:
	for scenario in ["base", "upgrade"]:
		await _visor_sewn_case(fixture, scenario)
	await _visor_latch_case(fixture)
	for scenario in ["absent", "unworn", "other_owner", "torn"]:
		await _visor_negative_case(fixture, scenario)


## Authored Warden heavy cards genuinely owned by the real run deck.
func _own_heavy_cards() -> void:
	for id in ["warden_heavy_thimble", "warden_heavy_thimble_plus",
			"warden_pin_and_pound", "warden_pin_and_pound_plus"]:
		for copy in range(3):
			app.run_deck.append(id)


func _physical_heavy_hit(id: String, position: int, keyboard: bool,
		expected_damages: Array, expected_statuses: Dictionary = {}) -> Dictionary:
	if app.deck.energy < 2:
		app.deck.combat_state.energy = 3
	if not await _ensure_held(id):
		return {}
	if app.deck.energy < 2:
		app.deck.combat_state.energy = 3
	var panel = _panel(id)
	_check(panel != null and panel.is_visible_in_tree()
		and Rect2(0, 0, 1280, 720).encloses(panel.get_global_rect()),
		"held heavy attack panel is visible inside 1280x720: " + id)
	var forecast: Dictionary = presenter._resolve_attack(app.party, app.enemies, id, 0, true)
	_check(forecast.playable and position in forecast.hits.map(func(hit): return hit.position),
		"mounted heavy attack authority forecasts legal target: " + id)
	_check(await _choose(id, keyboard), "physical heavy hand selection succeeded: " + id)
	_check(presenter.cue.is_visible_in_tree()
		and Rect2(0, 0, 1280, 720).encloses(presenter.cue.get_global_rect()),
		"selected heavy attack cue fits 1280x720: " + id)
	var before := _live_state()
	var enemy_before: Dictionary = app.enemies.get_enemy(position)
	var cost := 2
	if keyboard:
		await _key(KEY_1 if position == 1 else (KEY_2 if position == 2 else KEY_3))
	else:
		await _click(app.get_node("LiveEnemyRoster")._labels[position - 1])
	var event: Dictionary = presenter.last_event
	_check(event.get("ok", false), "heavy attack event succeeded: " + id)
	var actual_damages: Array = []
	for h in event.get("hits", []):
		actual_damages.append(h.get("damage", 0))
	_check(actual_damages == expected_damages,
		"heavy attack actual damages %s equal expected %s for %s" % [str(actual_damages), str(expected_damages), id])
	var after: Dictionary = app.enemies.get_enemy(position)
	var total_damage: int = 0
	for d in expected_damages:
		total_damage += int(d)
	_check(app.deck.energy == before[15] - cost
		and app.deck.hand.count(id) == before[12].count(id) - 1
		and app.deck.discard_pile.count(id) == before[14].count(id) + 1,
		"heavy card charges 2 energy and moves once to discard: " + id)
	_check(after.block == maxi(0, int(enemy_before.get("block", 0)) - total_damage)
		and after.hp == maxi(0, int(enemy_before.get("hp", 0)) - maxi(0, total_damage - int(enemy_before.get("block", 0))))
		and app.run_rng.state == before[10],
		"real HP, Block, and run RNG agree with confirmed heavy attack: " + id)
	_check(app.hand_view.get_child_count() == app.deck.hand.size()
		and app.get_node("LiveSupportHand").energy_label.text == "%d" % app.deck.energy,
		"mounted hand and energy redraw after heavy hit: " + id)
	_check(presenter.cue != null and presenter.cue.text == ""
		and not presenter.cue.is_visible_in_tree(),
		"committed heavy attack retires attack cue: " + id)
	return event


## Complete mounted regression for authentic sewn Frayfinder Mitt on Warden heavy attacks.
func _mitt_heavy_cases(fixture: Dictionary) -> void:
	# --- Case 1: All 4 heavy IDs, mouse and keyboard, below-half, at-half, and turn reset ---
	for keyboard in [false, true]:
		if not await _entry(fixture, "warden", false, keyboard, true, [], false, false, "", true):
			_check(false, "M05 heavy routed fixture entered: keyboard=" + str(keyboard))
			continue
		var mitt: CombatFrayfinderMitt = presenter._fray
		var gauge: CombatUnravel = presenter._unravel
		_check(mitt != null and gauge != null, "mitt and unravel authorities bound to presenter")
		# Give enemy 1 enough block so it survives testing both below-half and at-half
		app.enemies.gain_block(1, 40)

		# Subcase 1a: Below half (3/8) -> no +2 bonus, latch not consumed
		if not await _ensure_held("warden_heavy_thimble"):
			continue
		_check(gauge.apply_unravel(app.enemies, 1, 3), "enemy 1 unravel set to 3/8")
		var q_below: Dictionary = mitt.quote_heavy_hit("warden_heavy_thimble", 1)
		_check(q_below.get("bonus") == 0 and mitt.latch_snapshot().is_empty(),
			"below-half heavy quote bonus is 0")
		await _hover(_panel("warden_heavy_thimble"))
		_check(presenter.cue.text.contains("11 damage") and not presenter.cue.text.contains("13 damage"),
			"cue shows base 11 damage when below half")
		await _physical_heavy_hit("warden_heavy_thimble", 1, keyboard, [11])
		_check(mitt.latch_snapshot().is_empty(),
			"below-half heavy hit leaves mitt latch unconsumed")

		# Subcase 1b: At half (4/8) -> +2 bonus applied to first hit, latch consumed
		app.deck.combat_state.energy = 3
		if not await _ensure_held("warden_heavy_thimble_plus"):
			continue
		_check(gauge.apply_unravel(app.enemies, 1, 1), "enemy 1 unravel rises to 4/8")
		var q_half: Dictionary = mitt.quote_heavy_hit("warden_heavy_thimble_plus", 1)
		_check(q_half.get("bonus") == 2 and mitt.latch_snapshot().is_empty(),
			"at-half heavy quote bonus is 2")
		await _hover(_panel("warden_heavy_thimble_plus"))
		_check(presenter.cue.text.contains("17 damage"),
			"cue shows upgraded 15+2=17 damage at half unravel")
		await _physical_heavy_hit("warden_heavy_thimble_plus", 1, keyboard, [17])
		_check(mitt.latch_snapshot() == {"warden": true},
			"at-half heavy hit consumes Warden mitt latch")

		# Subcase 1c: Replay / counterfeit rejection
		_check(not mitt.consume_confirmed_hit(q_half, presenter.last_event),
			"replaying confirmed heavy receipt fails")

		# Subcase 1d: Second heavy hit in SAME turn receives no bonus (latch spent)
		app.deck.combat_state.energy = 3
		if not await _ensure_held("warden_pin_and_pound"):
			continue
		app.enemies.gain_block(2, 40)
		_check(gauge.apply_unravel(app.enemies, 2, 4), "enemy 2 unravel set to 4/8")
		var q_spent: Dictionary = mitt.quote_heavy_hit("warden_pin_and_pound", 2)
		_check(q_spent.get("bonus") == 0,
			"quote bonus is 0 when latch already spent this turn")
		await _hover(_panel("warden_pin_and_pound"))
		_check(presenter.cue.text.contains("9 damage each"),
			"cue shows unboosted 9 damage each when latch is spent")
		await _physical_heavy_hit("warden_pin_and_pound", 2, keyboard, [9, 9])
		_check(mitt.latch_snapshot() == {"warden": true},
			"second attack in same turn cannot re-award or restack mitt")

		# Subcase 1e: End Turn restores availability once
		var prev_turn: int = app.enemy_intents._turn_index
		await _click(app.end_turn_button)
		await _frames()
		_check(app.enemy_intents._turn_index == prev_turn + 1
			and app.deck.turn_active and mitt.latch_snapshot().is_empty(),
			"end turn restores mitt latch availability")

		# Subcase 1f: Fresh turn Pin and Pound receives +2 on hit 1 only, hit 2 gets base 9
		if not await _ensure_held("warden_pin_and_pound"):
			continue
		_check(gauge.get_snapshot(2).gauge >= 4, "enemy 2 still at or above half unravel")
		var q_fresh: Dictionary = mitt.quote_heavy_hit("warden_pin_and_pound", 2)
		_check(q_fresh.get("bonus") == 2, "fresh turn quote gets +2")
		await _hover(_panel("warden_pin_and_pound"))
		_check(presenter.cue.text.contains("11 + 9 damage"),
			"fresh turn cue shows 11 + 9 damage for pin and pound")
		await _physical_heavy_hit("warden_pin_and_pound", 2, keyboard, [11, 9])
		_check(mitt.latch_snapshot() == {"warden": true},
			"pin and pound consumes mitt latch on hit 1 only")

		await _click(app.return_button)
		_check(presenter._fray == null and presenter._unravel == null,
			"return to title retires battle-bound mitt: keyboard=" + str(keyboard))

	# --- Case 2: Pin and Pound+ & Lethal short-circuit on hit 1 (AC2) ---
	if await _entry(fixture, "warden", false, false, true, [], false, false, "", true):
		var mitt2: CombatFrayfinderMitt = presenter._fray
		var gauge2: CombatUnravel = presenter._unravel
		app.enemies.gain_block(1, 40)
		_check(gauge2.apply_unravel(app.enemies, 1, 4), "enemy 1 at 4/8 unravel")
		# Surviving multi-hit with Pin and Pound+ (12 + 2 = 14 hit 1, 12 hit 2)
		if await _ensure_held("warden_pin_and_pound_plus"):
			await _hover(_panel("warden_pin_and_pound_plus"))
			_check(presenter.cue.text.contains("14 + 12 damage"),
				"cue shows 14 + 12 damage for pin and pound plus")
			await _physical_heavy_hit("warden_pin_and_pound_plus", 1, false, [14, 12])
			_check(mitt2.latch_snapshot() == {"warden": true},
				"pin and pound plus consumes latch")

		# End turn to restore latch
		await _click(app.end_turn_button)
		await _frames()
		_check(mitt2.latch_snapshot().is_empty(), "latch restored on end turn")

		# Lethal hit 1: set enemy 2 HP to 5, block to 0
		app.enemies._enemies[1]["hp"] = 5
		app.enemies._enemies[1]["block"] = 0
		_check(gauge2.apply_unravel(app.enemies, 2, 4), "enemy 2 at 4/8 unravel")
		# Hit 1 deals 11 damage, which kills enemy 2 (5 HP). Hit 2 must be skipped!
		var lethal_event: Dictionary = await _physical_heavy_hit("warden_pin_and_pound", 2, false, [11])
		_check(lethal_event.get("hits", []).size() == 1,
			"lethal hit 1 skips hit 2 for pin and pound")
		_check(app.enemies.is_slain(2), "target enemy 2 is slain")
		_check(mitt2.latch_snapshot() == {"warden": true},
			"lethal hit 1 still authenticated and consumed latch")

		await _click(app.return_button)

	# --- Case 3: Raised threshold & gauge progression (AC3) ---
	if await _entry(fixture, "warden", false, false, true, [], false, false, "", true):
		var mitt3: CombatFrayfinderMitt = presenter._fray
		var gauge3: CombatUnravel = presenter._unravel
		app.enemies.gain_block(1, 40)
		if await _ensure_held("warden_heavy_thimble"):
			# Unravel enemy 1 completely (8 charge) and consume skip to raise threshold by 4
			_check(gauge3.apply_unravel(app.enemies, 1, 8), "enemy 1 unravels (8/8)")
			_check(gauge3.consume_action_skip(app.enemies, 1), "action skip consumed")
			_check(gauge3.get_snapshot(1).threshold == 12, "threshold raised from 8 to 12")
			_check(gauge3.get_snapshot(1).gauge == 0, "gauge resets to 0/12")
			# At 5/12 (< 6): below half of raised threshold
			_check(gauge3.apply_unravel(app.enemies, 1, 5), "enemy 1 unravel at 5/12")
			_check(mitt3.quote_heavy_hit("warden_heavy_thimble", 1).get("bonus") == 0,
				"5/12 is strictly below half of 12, bonus is 0")
			# At 6/12 (>= 6): at half of raised threshold
			_check(gauge3.apply_unravel(app.enemies, 1, 1), "enemy 1 unravel at 6/12")
			_check(mitt3.quote_heavy_hit("warden_heavy_thimble", 1).get("bonus") == 2,
				"6/12 is at half of raised threshold 12, bonus is 2")
			await _physical_heavy_hit("warden_heavy_thimble", 1, false, [13])
			_check(mitt3.latch_snapshot() == {"warden": true},
				"raised-threshold hit consumes latch")
		await _click(app.return_button)

	# --- Case 4: Statuses (Weak, Exposed, Pinned) math (AC1, AC2) ---
	if await _entry(fixture, "warden", false, false, true, [], false, false, "", true):
		var mitt4: CombatFrayfinderMitt = presenter._fray
		var gauge4: CombatUnravel = presenter._unravel
		app.enemies.gain_block(1, 50)
		_check(gauge4.apply_unravel(app.enemies, 1, 4), "enemy 1 unravel at 4/8")
		# Cross-owner Pinned (+5 on hit 1)
		_check(presenter._pinned.pin_enemy(app.enemies, 1, "tinker"), "pin enemy 1 by Tinker")
		_check(presenter._pinned.pinner_for_enemy(1) == "tinker", "enemy 1 is pinned by Tinker")
		# Weak on Warden (-25%) and Exposed on Enemy 1 (+50%)
		app.party._heroes[0]["statuses"] = {"weak": 1}
		_check(app.enemies.apply_statuses({1: {"exposed": 1}}), "exposed applied to enemy 1")
		# Math:
		# Hit 1: base 9 + Pinned 5 + Mitt 2 = 16. With Weak+Exposed (9/8): floor(16 * 1.125) = 18.
		# Hit 2: base 9 + Pinned 0 + Mitt 0 = 9. With Weak+Exposed (9/8): floor(9 * 1.125) = 10.
		await _physical_heavy_hit("warden_pin_and_pound", 1, false, [18, 10])
		_check(presenter._pinned.pinner_for_enemy(1) == "", "pinned consumed after attack")
		_check(mitt4.latch_snapshot() == {"warden": true}, "latch consumed")
		await _click(app.return_button)

	# --- Case 5: Negative Guards, Atomic Rejections, No-Spend (AC3) ---
	# Subcase 5a: Unsewn Mitt baseline (no patch)
	if await _entry(fixture, "", false, false, false, [], false, false, "", true):
		_check(presenter._fray == null, "unsewn run has no frayfinder mitt")
		app.enemies.gain_block(1, 40)
		_check(presenter._unravel.apply_unravel(app.enemies, 1, 4), "enemy 1 at 4/8 unravel")
		await _physical_heavy_hit("warden_heavy_thimble", 1, false, [11])
		await _click(app.return_button)

	# Subcase 5b: Different wearer (Mitt sewn on Seamstress)
	if await _entry(fixture, "seamstress", false, false, true, [], false, false, "", true):
		var mitt_s: CombatFrayfinderMitt = presenter._fray
		app.enemies.gain_block(1, 40)
		_check(presenter._unravel.apply_unravel(app.enemies, 1, 4), "enemy 1 at 4/8 unravel")
		if await _ensure_held("warden_heavy_thimble"):
			# Warden plays heavy thimble, but mitt is on Seamstress -> no +2 bonus
			_check(mitt_s.quote_heavy_hit("warden_heavy_thimble", 1).get("bonus") == 0,
				"Warden gets 0 bonus when mitt is sewn on Seamstress")
			await _physical_heavy_hit("warden_heavy_thimble", 1, false, [11])
			_check(mitt_s.latch_snapshot().is_empty(),
				"Warden attack leaves Seamstress mitt latch untouched")
		await _click(app.return_button)

	# Subcase 5c: Atomic rejections (wrong target, no energy, wrong position, downed/torn)
	if await _entry(fixture, "warden", false, false, true, [], false, false, "", true):
		var mitt_neg: CombatFrayfinderMitt = presenter._fray
		app.enemies.gain_block(1, 40)
		_check(presenter._unravel.apply_unravel(app.enemies, 1, 4), "enemy 1 at 4/8")
		if await _ensure_held("warden_heavy_thimble"):
			_check(await _choose("warden_heavy_thimble", false), "heavy thimble chosen")
			# Invalid target (slot 4 does not exist)
			var state_before_target := _live_state()
			presenter._queue_attack(4)
			_check(_live_state() == state_before_target and mitt_neg.latch_snapshot().is_empty(),
				"invalid target fails atomically without mutating state or latch")

			# Insufficient energy (energy = 1, cost = 2)
			app.deck.combat_state.energy = 1
			var state_before_energy := _live_state()
			presenter._queue_attack(1)
			await _key(KEY_1)
			_check(_live_state() == state_before_energy and mitt_neg.latch_snapshot().is_empty(),
				"insufficient energy fails atomically")
			app.deck.combat_state.energy = 3

			# Invalid position (Warden not in position 1)
			var swap_res := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
			_check(swap_res.ok, "swap Warden to position 2")
			for idx in range(3):
				app.party._heroes[idx] = swap_res.heroes[idx].duplicate(true)
			await _frames()
			var state_before_pos := _live_state()
			_check(not presenter._resolve_attack(app.party, app.enemies, "warden_heavy_thimble", 1).get("ok", false),
				"Warden in pos 2 cannot play heavy attack")
			_check(_live_state() == state_before_pos and mitt_neg.latch_snapshot().is_empty(),
				"invalid hero position leaves state unchanged")
			# Swap back to position 1
			var swap_back := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
			for idx in range(3):
				app.party._heroes[idx] = swap_back.heroes[idx].duplicate(true)
			await _frames()

			# Downed Warden
			_check(app.party.apply_damage(1, 9999) and app.party.is_downed(1), "down Warden")
			var state_before_downed := _live_state()
			_check(not presenter._resolve_attack(app.party, app.enemies, "warden_heavy_thimble", 1).get("ok", false),
				"downed Warden cannot attack")
			_check(_live_state() == state_before_downed and mitt_neg.latch_snapshot().is_empty(),
				"downed Warden attempt leaves state unchanged")

		await _click(app.return_button)

	# Subcase 5d: Torn Warden (torn wearer suppresses patch)
	if await _entry(fixture, "warden", true, false, true, [], false, false, "", true):
		_check(app.party.is_downed(1) and app.party_carryover.torn.read_state().heroes[0].hp == 0,
			"Warden is authentically torn in carried run ledger")
		if await _ensure_held("warden_heavy_thimble"):
			var state_torn := _live_state()
			_check(not presenter._resolve_attack(app.party, app.enemies, "warden_heavy_thimble", 1).get("ok", false)
				and _live_state() == state_torn,
				"torn Warden cannot attack or spend mitt")
		await _click(app.return_button)

## Independent complete game snapshots include the live Needle latch/quote and
## the battle's one authentic Pinned identity, not just the rendered HUD.
func _needle_state() -> Array:
	var hand = app.get_node("LiveSupportHand")
	var rules: CombatHeirloomPatchTriggers = hand._heirloom
	return [_live_state(), presenter._pinned._pinner_by_position.duplicate(true),
		rules._needle_used if rules != null else null,
		rules._pending_needle.duplicate(true) if rules != null else null,
		rules._turn if rules != null else null, rules._ticket if rules != null else null]


func _needle_mounted_cases(fixture: Dictionary) -> void:
	for scenario in ["strike", "plus", "nonwearer", "torn", "unworn"]:
		var owner := "" if scenario == "unworn" else (
			"seamstress" if scenario == "nonwearer" else "warden")
		var upgrading: bool = scenario == "plus"
		var torn: bool = scenario == "torn"
		if not await _entry(fixture, owner, torn, false, false, [], false,
				false, "", false, owner != "", upgrading):
			_check(false, "real Needle Fight mounted " + scenario)
			continue
		var hand = app.get_node("LiveSupportHand")
		var rules: CombatHeirloomPatchTriggers = hand._heirloom
		_check(app.deck.turn_active and presenter._battle == app.battle_view
			and presenter._deck == app.deck and app.enemies.get_enemies().size() > 0
			and (rules == null if owner == "" else rules != null
				and rules._enemies == app.enemies and rules._party == app.party
				and rules._pinned == presenter._pinned),
			"nonvacuous real mounted carried battle authority " + scenario)
		if rules == null and owner != "":
			await _click(app.return_button)
			continue
		var id := "warden_strike_plus" if upgrading else "warden_strike"
		var target: Dictionary = app.enemies.get_enemy(1)
		_check(target.get("hp", 0) > 0 and presenter._pinned.pin_enemy(
			app.enemies, 1, "warden") and presenter._pinned.pinner_for_enemy(1) == "warden",
			"authentic live Pinned token and living original target " + scenario)
		if scenario != "torn" and not await _ensure_held(id):
			_check(false, "genuine held Needle target exists " + scenario)
			await _click(app.return_button)
			continue
		var before := _needle_state()
		var preview: Dictionary = presenter._resolve_attack(app.party, app.enemies, id, 0, true)
		_check((not preview.get("playable", false) if torn else (
			preview.get("playable", false) and preview.hits.any(
				func(hit): return hit.position == 1))) and _needle_state() == before,
			"read-only live forecast never quotes or consumes Needle " + scenario)
		if scenario == "torn":
			_check(app.party.is_downed(1) and not rules.quote_needle_hit("warden", 1).ok
				and _needle_state() == before,
				"torn/downed Needle wearer cannot quote or mutate state")
			await _click(app.return_button)
			continue
		if scenario == "strike":
			# Draw genuine extra copies through CombatDeck before this turn's
			# first payment so a second successful card stays in this turn.
			while app.deck.hand.count(id) < 2 and not app.deck.draw_pile.is_empty():
				_check(app.deck.draw_extra(1) == 1,
					"second Strike drawn from real owned battle deck")
			app._refresh_hand()
			await _frames()
			_check(app.deck.hand.count(id) >= 2, "two genuine held Strike copies for same-turn latch")
		if rules != null:
			var forged_source: Dictionary = rules.quote_needle_hit("warden", 1)
			if scenario in ["strike", "plus"]:
				_check(forged_source.get("ok", false)
					and forged_source.get("bonus_damage") == 1,
					"living wearer receives sealed pre-hit Needle quote")
				var forged := forged_source.duplicate(true)
				forged["ticket"] = -999
				var game_before := _live_state()
				var refused: Dictionary = presenter._play.play_attack(app.deck, app.party,
					app.enemies, id, 1, {}, {}, 0, null, {}, rules, forged)
				_check(refused == {"ok": false, "hits": []}
					and _live_state() == game_before
					and rules._pending_needle.is_empty() and not rules._needle_used,
					"forged seal refuses atomically and cancels pending quote")
				if scenario == "strike":
					var stale_quote: Dictionary = rules.quote_needle_hit("warden", 1)
					_check(stale_quote.get("ok", false)
						and presenter._pinned.clear_pin(1), "authentic pin disappears after quote")
					var without_pin := _live_state()
					var stale_result: Dictionary = presenter._play.play_attack(
						app.deck, app.party, app.enemies, id, 1, {}, {}, 0,
						null, {}, rules, stale_quote)
					_check(stale_result == {"ok": false, "hits": []}
						and _live_state() == without_pin and not rules._needle_used
						and rules._pending_needle.is_empty(),
						"stale quote after lost Pin refuses without deck, party or RNG mutation")
					_check(presenter._pinned.pin_enemy(app.enemies, 1, "warden"),
						"authentic Pinned authority can be restored for actual paid hit")
			else:
				_check(not forged_source.get("ok", false)
					and rules._pending_needle.is_empty(),
					"nonwearer cannot reserve Needle bonus")
		_check(app.enemies.gain_block(1, 3),
			"real enemy Block protects the confirmed Needle receipt")
		var original: Dictionary = app.enemies.get_enemy(1)
		var payment := [app.deck.energy, app.deck.hand.count(id),
			app.deck.discard_pile.count(id), app.run_rng.state]
		_check(await _choose(id, false), "actual selected held card " + scenario)
		await _click(app.get_node("LiveEnemyRoster")._labels[0])
		var receipt: Dictionary = presenter.last_event
		var expected_damage := (7 if upgrading else 6) + (
			1 if scenario in ["strike", "plus"] else 0)
		var now: Dictionary = app.enemies.get_enemy(1)
		_check(receipt.get("ok", false) and receipt.get("hits", []).size() == 1
			and receipt.hits[0].position == 1
			and receipt.hits[0].damage == expected_damage
			and receipt.hits[0].block_absorbed == mini(original.block, expected_damage)
			and receipt.hits[0].hp_loss == mini(original.hp,
				maxi(0, expected_damage - original.block))
			and now.hp == original.hp - receipt.hits[0].hp_loss
			and now.block == original.block - receipt.hits[0].block_absorbed,
			"actual original hit rows exactly reconcile HP/Block " + scenario)
		_check(app.deck.energy == payment[0] - 1
			and app.deck.hand.count(id) == payment[1] - 1
			and app.deck.discard_pile.count(id) == payment[2] + 1
			and app.run_rng.state == payment[3]
			and (rules == null or rules._needle_used == (scenario in ["strike", "plus"]))
			and (rules == null or rules._pending_needle.is_empty()),
			"exactly one paid/discarded card and correct latch with no RNG draw " + scenario)
		if scenario == "strike" and app.deck.hand.has(id):
			var second_before: Dictionary = app.enemies.get_enemy(1)
			var latch_before := _needle_state()
			_check(await _choose(id, false), "second real held Strike selected in same turn")
			await _click(app.get_node("LiveEnemyRoster")._labels[0])
			_check(presenter.last_event.get("ok", false)
				and presenter.last_event.hits.size() == 1
				and presenter.last_event.hits[0].damage == 6
				and app.enemies.get_enemy(1).hp == second_before.hp - 6
				and rules._needle_used,
				"second genuine same-turn hit cannot earn second +1")
			_check(_needle_state()[1] == latch_before[1],
				"same-pinner Pin survives both valid hits")
			await _click(app.end_turn_button)
			_check(app.deck.turn_active and app.enemy_intents._turn_index > 0,
				"real enemy phase opens a later player turn")
			if not app.party.is_downed(1) and app.enemies.get_enemy(1).hp > 0:
				var fresh: CombatHeirloomPatchTriggers = hand.current_attack_heirloom(
					app.deck, app.party)
				_check(fresh == rules and not rules._needle_used
					and rules._pending_needle.is_empty(),
					"next real scheduler turn re-arms exactly one Needle use")
		await _click(app.return_button)
