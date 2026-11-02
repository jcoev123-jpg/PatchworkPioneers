extends SceneTree
## Cycle 138: CombatQuiltBonus is reached only through real committed held-card
## actions of a mounted, seeded routed battle. Every expectation comes from a
## detached CombatQuiltBonus/CombatDeck/CombatParty oracle, never from the bridge.

const SEED_LIMIT := 20000
var failures: Array[String] = []
var checks := 0
var app
var presenter
var support
var catalog := StarterCards.new()

var fixture: Dictionary = {}
var previous_quilt_row_id := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for frame in range(4):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _click_point(point: Vector2) -> void:
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


func _click(control: Control) -> void:
	_check(is_instance_valid(control), "physical click requires an existing control")
	if not is_instance_valid(control):
		return
	await _click_point(control.get_global_rect().get_center())


## Assert the actual mounted SupportHUD against the detached service read, never
## deriving expected owners, colours or completion from the presenter itself.
func _assert_quilt(note: String) -> void:
	var service: CombatQuiltBonus = app._quilt_bonus
	_check(service != null and service._deck == app.deck and service._party == app.party,
		note + ": live Quilt authority is bound to this party and deck")
	if service == null:
		return
	var row: HBoxContainer = support.quilt_row
	_check(is_instance_valid(row) and row.get_parent() == app.battle_view.find_child(
		"SupportHUD", true, false) and row.visible,
		note + ": exactly three mounted patches are visible in SupportHUD")
	if not is_instance_valid(row):
		return
	var marks := row.find_child("QuiltOwnerMarks", true, false) as HBoxContainer
	_check(marks != null and marks.get_child_count() == 3,
		note + ": shared Quilt cloth groups exactly three owner marks")
	if marks == null:
		return
	var snapshot: Dictionary = service.get_patch_progress()
	_check(snapshot.active and snapshot.patches.size() == 3,
		note + ": service has three active ID patches")
	_check(support.quilt_patches.size() == 3, note + ": exactly three indexed reusable squares")
	var expected_ids := ["warden", "seamstress", "tinker"]
	for index in range(expected_ids.size()):
		var owner: String = expected_ids[index]
		var square = marks.get_child(index)
		var expected: Dictionary = snapshot.patches.get(owner, {})
		_check(square == support.quilt_patches.get(owner)
			and square.owner_id == owner and square.name == "QuiltPatch_" + owner,
			note + ": square order and identity follow " + owner)
		var color := Color(str(expected.get("color", "#000000")))
		var fill: Color = color if bool(expected.get("played", false)) else Color("302b26").lerp(color, 0.23)
		if not bool(expected.get("living", false)):
			fill = fill.darkened(0.58)
		_check(square.played == expected.get("played")
			and square.living == expected.get("living")
			and square.awarded == snapshot.awarded
			and square.felt_color == color and square.fill_color == fill,
			note + ": " + owner + " fill and felt colour mirror the authoritative snapshot")
		_check(square.tooltip_text.contains(owner.capitalize())
			and square.tooltip_text.contains("Play cards from all living heroes")
			and square.tooltip_text.contains("3 Block; draw 1 once per turn")
			and square.tooltip_text.contains("played" if bool(expected.get("played", false)) else "unplayed")
			and (bool(expected.get("living", false)) or square.tooltip_text.contains("not required"))
			and (not snapshot.awarded or square.tooltip_text.contains("awarded this turn")),
			note + ": " + owner + " hover explains its actual progress and Quilt rule")
		_check(square.focus_mode == Control.FOCUS_NONE
			and square.mouse_filter == Control.MOUSE_FILTER_STOP,
			note + ": " + owner + " is focus-free but hoverable")
	var rect := row.get_global_rect()
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(viewport.encloses(rect) and rect.size.y <= 76
		and support.backing.covers(row),
		note + ": sewn squares fit on the real 1280x720 felt-table backing")
	for other in [support.energy_orb, support.help_label, app.hand_view, app.pile_label,
			app.end_turn_button, app.return_button]:
		if is_instance_valid(other) and other.is_visible_in_tree():
			_check(not rect.intersects(other.get_global_rect()),
				note + ": squares do not cover " + other.name)


func _assert_quilt_read_only(note: String) -> void:
	var state_before := _state()
	var progress_before: Dictionary = app._quilt_bonus.get_patch_progress()
	var row = support.quilt_row
	for repetition in range(4):
		support._sync_battle()
	_check(_state() == state_before and app._quilt_bonus.get_patch_progress() == progress_before,
		note + ": repeated passive redraw leaves piles, energy, actors, RNG and receipts unchanged")
	_check(support.quilt_row == row and row.get_parent().get_children().count(row) == 1,
		note + ": resync reuses the exact same Quilt row")
	_assert_quilt(note)


func _panel(card_id: String):
	for panel in app.hand_view.get_children():
		if panel.get_child(0).text == card_id:
			return panel
	return null


## Exact authoritative combat state used for every boundary comparison.
func _state() -> Array:
	return [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.run_rng.state,
		app.party.get_heroes(), app.enemies.get_enemies(), app.deck.turn_active]


func _deck_state(deck: CombatDeck) -> Array:
	return [deck.hand.duplicate(), deck.draw_pile.duplicate(),
		deck.discard_pile.duplicate(), deck.energy, deck._rng.state, deck.turn_active]


func _blocks(heroes: Array) -> Dictionary:
	var blocks := {}
	for hero in heroes:
		blocks[hero.id] = hero.block
	return blocks


## The detached oracle starts from the mounted battle's own admitted state and is
## then only ever driven by the scene-free services and the real Quilt service.
func _oracle() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var deck := CombatDeck.new([], rng)
	deck.hand.assign(app.deck.hand)
	deck.draw_pile.assign(app.deck.draw_pile)
	deck.discard_pile.assign(app.deck.discard_pile)
	deck.combat_state.player_turn_active = app.deck.turn_active
	deck.combat_state.energy = app.deck.energy
	var heroes: Array[Dictionary] = app.party.get_heroes()
	var party := CombatParty.new(heroes)
	party._heroes.assign(heroes)
	var foes: Array[Dictionary] = app.enemies.get_enemies()
	var enemies := CombatEnemies.new(foes)
	enemies._enemies.assign(foes)
	var intents := CombatEnemyIntents.new(app.enemy_intents._definitions)
	# The opening announcement has already been committed; clone that immutable
	# batch, then let the independent shared RNG draw subsequent batches.
	intents._bound = true
	intents._party = party
	intents._rng = rng
	intents._enemies = enemies
	intents._slots = app.enemy_intents._slots.duplicate(true)
	intents._cache = app.enemy_intents.get_intents()
	var flow := CombatRoundFlow.new(deck, party, enemies, intents,
		CombatBattleResult.new(party, enemies))
	flow._started = true # Detached already-active turn, never a second opening deal.
	var quilt := CombatQuiltBonus.new(party, deck)
	if not quilt.begin_player_turn():
		return {}
	return {"deck": deck, "party": party, "enemies": enemies, "quilt": quilt,
		"attacks": CombatAttackCards.new(), "flow": flow}


func _oracle_state(oracle: Dictionary) -> Array:
	var deck: CombatDeck = oracle["deck"]
	var party: CombatParty = oracle["party"]
	var enemies: CombatEnemies = oracle["enemies"]
	return [deck.hand.duplicate(), deck.draw_pile.duplicate(), deck.discard_pile.duplicate(),
		deck.energy, deck._rng.state, party.get_heroes(), enemies.get_enemies(), deck.turn_active]


## Owners of one really committed card: both halves of a trusted published
## stitched descriptor, or the single catalog owner of an ordinary card.
func _owners(card_id: String) -> Array[String]:
	var owners: Array[String] = []
	if app.run_stitch_descriptors.has(card_id):
		var descriptor: Dictionary = app.run_stitch_descriptors[card_id]
		for owner in descriptor.get("owners", []):
			owners.append(str(owner))
		return owners
	var definition := _definition(card_id)
	var owner = definition.get("owner")
	if owner is String:
		owners.append(str(owner))
	return owners


## The authored definition from any catalog the live hand can hold.
func _definition(card_id: String) -> Dictionary:
	var definition := catalog.get_definition(card_id)
	if definition.is_empty():
		definition = V3SeamstressStarterCards.new().get_definition(card_id)
	if definition.is_empty():
		definition = M02PositionCards.new().get_definition(card_id)
	if definition.is_empty():
		definition = WardenPoolCards.new().get_definition(card_id)
	if definition.is_empty():
		definition = SeamstressPoolCards.new().get_definition(card_id)
	if definition.is_empty():
		definition = TinkerPoolCards.new().get_definition(card_id)
	return definition


## A seeded real route whose opening Fight deals the three-owner support/attack
## hand, with the requested Warden card held.
func _find_fixture(warden_id: String) -> Dictionary:
	var cards: Array[String] = []
	cards.assign(RunV3PartyAdmission.admit(["warden", "seamstress", "tinker"]).deck)
	for value in range(1, SEED_LIMIT + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var fight := ""
		for id in map.get_legal_choices():
			if map.get_node(id).get("type") == "Fight":
				fight = id
				break
		if fight.is_empty() or not map.choose_node(fight):
			continue
		var entry := RunAuthoredBattleEntry.new().entry_current_battle(
			map, rng, RunFightEncounterSelection.new())
		if not entry.get("success", false):
			continue
		var deck := CombatDeck.new(cards, rng)
		if not deck.start_turn():
			continue
		var plan := _plan(deck.hand, warden_id)
		if plan.is_empty():
			continue
		return {"seed": value, "fight": fight, "plan": plan, "hand": deck.hand.duplicate(),
			"encounter": entry.get("encounter_id", "")}
	return {}


## Warden first, then Seamstress, then Tinker; a fourth still-held attack proves
## that a zero-energy attempt is rejected without a receipt.
func _plan(hand: Array[String], warden_id: String) -> Dictionary:
	if not hand.has(warden_id) or not hand.has("seamstress_v3_thread_prick") \
			or not hand.has("tinker_pop_shot"):
		return {}
	var warden := warden_id
	var spare := ""
	for id in hand:
		if id in [warden, "seamstress_v3_thread_prick", "tinker_pop_shot"]:
			continue
		if id in CombatAttackCards.ATTACK_IDS:
			spare = id
			break
	if spare.is_empty():
		return {}
	return {"warden": warden, "seamstress": "seamstress_v3_thread_prick",
		"tinker": "tinker_pop_shot", "spare": spare}


func _open_route(seed_value: int) -> bool:
	app.run_seed = seed_value
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	_check(app.run_map != null and is_instance_valid(app.route_view),
		"physical title Start mounts the seeded opening route")
	return app.run_map != null


func _choose_fight(node: String) -> bool:
	var button: Button = null
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == node:
			button = candidate
	_check(button != null and not button.disabled, "opening Fight route control is actionable")
	if button == null:
		return false
	await _click(button)
	await _frames()
	var ready: bool = app.deck != null and app.party != null and app.enemies != null \
		and app.battle_result != null and app.round_flow != null
	_check(ready, "physical route choice mounts a real authored fight")
	return ready


func _arm(card_id: String, keyboard: bool) -> bool:
	var panel = _panel(card_id)
	_check(panel != null, "held card panel exists: " + card_id)
	if panel == null:
		return false
	if card_id == "seamstress_v3_thread_prick":
		if keyboard:
			panel.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(panel)
		return app.get_node("LiveAreaAttackAction/LiveSeamstressSingleBleedHand")._choice.get("id") == card_id
	if keyboard:
		for attempt in range(app.hand_view.get_child_count() + 1):
			await _key(KEY_P)
			if presenter._card_id(presenter._armed) == card_id:
				break
	else:
		await _click(panel)
	return presenter._card_id(presenter._armed) == card_id


func _play_support(card_id: String, keyboard: bool, target: int) -> void:
	var panel = _panel(card_id)
	if panel == null:
		return
	if keyboard:
		panel.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(panel)
	if target > 0:
		await _click(app.hero_panels[target - 1])


func _play_attack(card_id: String, keyboard: bool, target: int) -> bool:
	if not await _arm(card_id, keyboard):
		return false
	if card_id == "seamstress_v3_thread_prick":
		var adapter = app.get_node("LiveAreaAttackAction/LiveSeamstressSingleBleedHand")
		if adapter._targets.has(target):
			await _click(adapter._targets[target])
			return true
		return false
	if keyboard:
		if target > 0:
			await _key(KEY_1 + target - 1)
		else:
			# A target-free attack (area/random) owns Enter/Space; a digit key
			# would neither pick a slot nor commit the armed card.
			await _key(KEY_ENTER)
	else:
		await _click(app.get_node("LiveEnemyRoster")._labels[target - 1])
	return true


## One committed play on the mounted hand, mirrored exactly by the detached oracle.
func _commit(card_id: String, keyboard: bool, target: int, oracle: Dictionary) -> void:
	_check(app.deck.hand.has(card_id), "card is genuinely held before its committed play: " + card_id)
	if card_id == "seamstress_v3_thread_prick":
		await _play_attack(card_id, keyboard, target)
		CombatSeamstressV3RedThreadCards.new().play_card(oracle["deck"], oracle["party"], oracle["enemies"], card_id, target)
	elif card_id in CombatAttackCards.ATTACK_IDS:
		await _play_attack(card_id, keyboard, target)
		var attacks: CombatAttackCards = oracle["attacks"]
		attacks.play_attack(oracle["deck"], oracle["party"], oracle["enemies"], card_id, target)
	else:
		await _play_support(card_id, keyboard, target)
		if card_id in support.SPARE_PARTS_IDS:
			CombatTinkerPoolGadgets.new().resolve_spare_parts(
				oracle["deck"], oracle["party"], card_id)
		else:
			CombatStarterSupportPlay.new().play_card(oracle["deck"], oracle["party"], card_id, target)
	var quilt: CombatQuiltBonus = oracle["quilt"]
	for owner in _owners(card_id):
		quilt.record_confirmed_play(owner)


## The real presenter callback bound to the currently held panel of one card.
func _bound_callback(card_id: String) -> Callable:
	var panel = _panel(card_id)
	if panel == null:
		return Callable()
	if card_id in CombatAttackCards.ATTACK_IDS:
		var binding: Dictionary = presenter._bindings.get(panel, {})
		var input = binding.get("input")
		return input if input is Callable else Callable()
	var bound = support._bindings.get(panel)
	return bound if bound is Callable else Callable()


## The first held card the real hand can legally play right now, with its target.
func _first_playable() -> Dictionary:
	for card_id in app.deck.hand:
		var definition := _definition(card_id)
		var cost := int(definition.get("cost", -1))
		if definition.is_empty() or cost < 0 or cost > app.deck.energy:
			continue
		if card_id == "seamstress_v3_thread_prick":
			var adapter = app.get_node("LiveAreaAttackAction/LiveSeamstressSingleBleedHand")
			if adapter._v3_service._prepare(app.deck, app.party, app.enemies, card_id, 1).get("ok", false):
				return {"id": card_id, "target": 1}
			continue
		if card_id in CombatAttackCards.ATTACK_IDS:
			var preview := CombatAttackTargeting.new().get_preview(
				app.deck, app.party, app.enemies, card_id)
			if preview.playable:
				return {"id": card_id,
					"target": preview.target_positions[0] if preview.requires_selection else 0}
			continue
		if card_id not in support.SUPPORT_IDS:
			continue
		var owned := false
		for hero in app.party.get_heroes():
			if hero.id == definition.owner and hero.hp > 0 \
					and hero.position in definition.from_positions:
				owned = true
		if not owned:
			continue
		var target := 0
		if definition.target_kind == "ally_single":
			for hero in app.party.get_heroes():
				if hero.hp > 0:
					target = hero.position
					break
		return {"id": card_id, "target": target}
	return {}


func _scenario_three_owners(seed_fixture: Dictionary) -> Array:
	if not await _open_route(seed_fixture.seed) or not await _choose_fight(seed_fixture.fight):
		return []
	var plan: Dictionary = seed_fixture.plan
	var expected_hand: Array[String] = []
	expected_hand.assign(seed_fixture.hand)
	_check(app.deck.hand == expected_hand, "mounted hand is the searched seeded deal")
	var foes: Array = app.enemies.get_enemies()
	_check(not foes.is_empty(), "authored fight mounts living enemies")
	# Keep the authored enemies alive at full HP so the whole turn really plays out.
	for index in range(foes.size()):
		app.enemies._enemies[index]["max_hp"] = maxi(int(foes[index]["max_hp"]), 60)
		app.enemies._enemies[index]["hp"] = app.enemies._enemies[index]["max_hp"]
	for index in range(CombatParty.PARTY_SIZE):
		app.party._heroes[index]["block"] = 0
	var heroes: Array = app.party.get_heroes()
	_check(heroes.size() == 3 and heroes[0].id == "warden" and heroes[1].id == "seamstress"
		and heroes[2].id == "tinker" and heroes[0].hp > 0 and heroes[1].hp > 0 and heroes[2].hp > 0,
		"all three distinct owners are living at their authored positions")
	_check(app.deck.turn_active and app.deck.energy == 3, "fresh player turn holds three energy")
	_check(app._quilt_bonus != null and app._quilt_turn_open, "the quota is bound to this real battle")
	var progress: Dictionary = app._quilt_bonus.get_patch_progress()
	_check(progress.active and not progress.awarded and progress.patches.keys().size() == 3,
		"fresh battle opens an unawarded three-patch quota")
	await _frames()
	_assert_quilt_read_only("new seeded battle before any play")
	# Even a temporarily invalid app-to-service binding cannot show a plausible stale set.
	var bound_deck: CombatDeck = app._quilt_deck
	var before_invalid := _state()
	app._quilt_deck = null
	support._sync_battle()
	_check(not support.quilt_row.visible and _state() == before_invalid,
		"invalid Quilt-to-deck binding hides all patches without altering combat")
	app._quilt_deck = bound_deck
	support._sync_battle()
	_assert_quilt("restored real binding returns the same unfilled row")
	var motion := InputEventMouseMotion.new()
	motion.position = support.quilt_patches["warden"].get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames()
	_check(root.gui_get_hovered_control() == support.quilt_patches["warden"],
		"real pointer hit-test reaches the Warden tooltip patch, not an input action")
	if previous_quilt_row_id != 0:
		_check(support.quilt_row.get_instance_id() != previous_quilt_row_id,
			"new battle receives a new row, not the previous fight's stale squares")
	previous_quilt_row_id = support.quilt_row.get_instance_id()

	var oracle := _oracle()
	_check(not oracle.is_empty(), "detached Quilt service binds the same real opening state")
	if oracle.is_empty():
		return []
	# A Warden Strike needs a real, legal enemy slot; the oracle must use the same
	# target the mounted click resolves, never a placeholder zero.
	var warden_target := 0
	if plan.warden in CombatAttackCards.ATTACK_IDS:
		var preview := CombatAttackTargeting.new().get_preview(
			app.deck, app.party, app.enemies, plan.warden)
		_check(preview.playable and preview.requires_selection
			and not preview.target_positions.is_empty(),
			"the held Warden attack has a legal living enemy target")
		if not preview.playable or not preview.requires_selection:
			return []
		warden_target = int(preview.target_positions[0])
	var trace: Array = [_state()]

	# Mere selection is never a receipt.
	var before := _state()
	_check(await _arm(plan.tinker, true), "real keyboard input selects the Tinker card")
	_check(_state() == before, "a selected held card changes no pile, energy, Block or RNG")
	await _key(KEY_ESCAPE)
	_check(_state() == before and presenter._armed == null, "cancelled selection invents no receipt")
	_assert_quilt("selection and Escape leave all three squares unplayed")

	# Capture the real bound callback while the Warden panel is still held, so the
	# stale-input check after the hand rebuild is never conditional on a missing key.
	var stale_warden := _bound_callback(plan.warden)
	_check(stale_warden.is_valid(), "the held Warden panel has a live committed callback")
	await _commit(plan.warden, false, warden_target, oracle)
	trace.append(_state())
	_check(_state() == _oracle_state(oracle), "mouse Warden play matches the detached oracle exactly")
	_check(_blocks(app.party.get_heroes()) == _blocks(oracle["party"].get_heroes()),
		"one owner alone grants no bonus Block")
	_check(app._quilt_bonus.get_patch_progress().patches.warden.played
		and not app._quilt_bonus.get_patch_progress().awarded,
		"only the Warden patch fills after one distinct owner")
	_assert_quilt_read_only("first confirmed Warden owner")
	# The retained callback of the consumed panel cannot replay the transaction.
	var after_warden := _state()
	_check(stale_warden.is_valid(), "the captured Warden callback survives the committed play")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	stale_warden.call(click)
	await _frames()
	await _key(KEY_1)
	_check(_state() == after_warden and not app._quilt_bonus.get_patch_progress().awarded,
		"stale duplicate input after the first owner invents no receipt or award")
	_assert_quilt("stale callback leaves only Warden filled")

	await _commit(plan.seamstress, true, 2, oracle)
	trace.append(_state())
	_check(_state() == _oracle_state(oracle), "keyboard Seamstress play matches the detached oracle exactly")
	_check(app._quilt_bonus.get_patch_progress().patches.seamstress.played
		and not app._quilt_bonus.get_patch_progress().awarded,
		"two distinct owners still award nothing")
	_assert_quilt("Warden and Seamstress receipts, no award yet")

	var before_award := _state()
	var top_card: String = app.deck.draw_pile.back()
	await _commit(plan.tinker, false, 2, oracle)
	trace.append(_state())
	_check(_state() == _oracle_state(oracle),
		"third distinct owner matches the detached oracle: Block, draw/hand/discard, energy and RNG")
	var awarded: Dictionary = app._quilt_bonus.get_patch_progress()
	_check(awarded.awarded and awarded.patches.warden.played
		and awarded.patches.seamstress.played and awarded.patches.tinker.played,
		"the three confirmed owners fill the quota exactly once")
	_check(_blocks(app.party.get_heroes()) == _blocks(oracle["party"].get_heroes()),
		"every living hero gained exactly the oracle's three Block")
	_check(app.deck.hand.size() == before_award[0].size()
		and app.deck.discard_pile.size() == before_award[2].size() + 1,
		"the real shared deck drew one card while one held copy moved to discard")
	_check(app.deck.hand.back() == top_card,
		"the awarded draw consumed the real next pile card")
	_check(awarded == oracle["quilt"].get_patch_progress(),
		"mounted patch progress equals the detached service")
	_assert_quilt_read_only("third owner filled and Quilt awarded")
	_check(app.deck.energy == before_award[3] - 1 and app.run_rng.state == oracle["deck"]._rng.state,
		"the award spends no extra energy and preserves the exact seeded RNG")

	# A second receipt for an already counted owner never awards again.
	var awarded_state := _state()
	_check(not app._quilt_bonus.record_confirmed_play("tinker").triggered
		and not app._quilt_bonus.record_confirmed_play("warden").triggered
		and _state() == awarded_state, "duplicate confirmed owners cannot replay the award")
	var spent := _state()
	for repeat in range(2):
		await _key(KEY_P)
		await _key(KEY_1)
		await _key(KEY_2)
		await _click(app.get_node("LiveEnemyRoster")._labels[0])
	_check(_state() == spent and app._quilt_bonus.get_patch_progress() == awarded,
		"repeated stale clicks after the award change nothing")

	# Insufficient energy: the fourth still-held attack is rejected with no receipt.
	_check(app.deck.energy == 0 and app.deck.hand.has(plan.spare),
		"the spare attack is still held at zero energy")
	var before_spare := _state()
	await _play_attack(plan.spare, false, 1)
	_check(_state() == before_spare, "insufficient energy spends nothing and invents no receipt")
	_check(app._quilt_bonus.get_patch_progress() == awarded,
		"the rejected attempt leaves the completed quota untouched")
	_assert_quilt("rejected zero-energy play does not disturb filled squares")

	# A real End Turn advances one turn: receipts and the single-award latch reset.
	var oracle_deck: CombatDeck = oracle["deck"]
	_check(oracle["flow"].end_turn(),
		"independent bound oracle commits real enemy phase, ticks and weighted next cache")
	await _click(app.end_turn_button)
	await _frames()
	_check(app.deck.turn_active and not app._battle_closed, "real End Turn opens the mounted next turn")
	_check(_deck_state(app.deck) == _deck_state(oracle_deck)
		and app.party.get_heroes() == oracle["party"].get_heroes()
		and app.enemies.get_enemies() == oracle["enemies"].get_enemies()
		and app.enemy_intents.get_intents() == oracle["flow"]._intents.get_intents(),
		"next turn matches the oracle's hand, piles, energy and RNG exactly")
	# A fresh detached mirror of the mounted next-turn state, including the
	# enemy-phase HP changes the mounted party really took.
	var mirror := _oracle()
	_check(not mirror.is_empty(), "detached Quilt service binds the mounted next turn")
	if mirror.is_empty():
		return trace
	_check(app._quilt_bonus.get_patch_progress() == mirror["quilt"].get_patch_progress(),
		"the next turn starts with clean indicators and no carried award")
	_assert_quilt_read_only("real End Turn resets Quilt squares and award cue")
	_check(_blocks(app.party.get_heroes()) == {"warden": 0, "seamstress": 0, "tinker": 0},
		"the new turn starts from reset Block, never a replayed +3")
	trace.append(_state())

	# The new turn's first real receipt alone still awards nothing.
	var next_play := _first_playable()
	_check(not next_play.is_empty(), "the next hand holds a genuinely playable card")
	if not next_play.is_empty():
		var before_first := _state()
		await _commit(next_play.id, true, int(next_play.target), mirror)

		_check(_state() != before_first, "the next turn's play really committed")
		_check(not app._quilt_bonus.get_patch_progress().awarded,
			"one receipt in the next turn does not award")
		_check(_state() == _oracle_state(mirror),
			"the next turn's first receipt matches the detached oracle exactly")
		_assert_quilt("new turn's first committed play fills its real owner only")
	trace.append(_state())
	var old_row: Control = support.quilt_row
	await _click(app.return_button)
	await _frames()
	support._sync_battle()
	_check(app.deck == null and app._quilt_bonus == null,
		"Return releases the battle and its quota")
	_check(not is_instance_valid(old_row) and support.quilt_row == null
		and support.quilt_patches.is_empty(),
		"Return releases all three patch controls and prevents stale tooltips")
	return trace


## The real shared deck can hold duplicate copies; this counts one ID.
func _count(cards: Array[String], card_id: String) -> int:
	var count := 0
	for card in cards:
		if card == card_id:
			count += 1
	return count


## A genuine draw-before-discard card (Spare Parts) while an older copy of that
## same ID waits in discard, and the draw pile is empty so the committed action
## reshuffles that older copy out of discard before appending the played copy.
## The receipt must still complete the quota and award Block plus one shared draw.
func _scenario_reshuffle_duplicate(seed_fixture: Dictionary) -> void:
	if not await _open_route(seed_fixture.seed) or not await _choose_fight(seed_fixture.fight):
		return
	var spare := "tinker_spare_parts"
	# A later routed Fight could admit exactly this deck: two Spare Parts copies,
	# an older one already in discard, and no draw pile left to draw from.
	var held: Array[String] = ["warden_brace", "seamstress_prick", spare]
	var older_discard: Array[String] = [spare, "warden_brace", "seamstress_mend", "tinker_pop_shot"]
	app.deck.hand.assign(held)
	app.deck.discard_pile.assign(older_discard)
	app.deck.draw_pile.clear()
	for index in range(CombatParty.PARTY_SIZE):
		app.party._heroes[index]["block"] = 0
	var foes: Array = app.enemies.get_enemies()
	for index in range(foes.size()):
		app.enemies._enemies[index]["max_hp"] = maxi(int(foes[index]["max_hp"]), 60)
		app.enemies._enemies[index]["hp"] = app.enemies._enemies[index]["max_hp"]
	app._refresh_hand()
	await _frames()
	_check(app.deck.turn_active and app.deck.energy == 3,
		"the duplicate-ID battle opens a real three-energy player turn")
	_check(_panel("warden_brace") != null and _panel("seamstress_prick") != null
		and _panel(spare) != null, "all three owner cards are genuinely held and bound")
	_check(app.deck.draw_pile.is_empty() and _count(app.deck.discard_pile, spare) == 1,
		"an older same-ID Spare Parts copy waits in an otherwise full discard pile")
	_check(app._quilt_bonus != null and app._quilt_turn_open
		and not app._quilt_bonus.get_patch_progress().awarded,
		"the duplicate-ID battle starts with an unawarded bound quota")
	_assert_quilt_read_only("duplicate-ID battle initial row")

	var oracle := _oracle()
	_check(not oracle.is_empty(), "detached Quilt service binds the duplicate-ID battle")
	if oracle.is_empty():
		return

	await _commit("warden_brace", false, 0, oracle)
	_check(_state() == _oracle_state(oracle),
		"the Warden receipt matches the detached oracle on the crafted deck")
	_assert_quilt("duplicate-ID first owner")
	await _commit("seamstress_prick", true, 1, oracle)
	_check(_state() == _oracle_state(oracle),
		"the Seamstress receipt matches the detached oracle on the crafted deck")
	_assert_quilt("duplicate-ID second owner")
	_check(app.deck.draw_pile.is_empty() and _count(app.deck.discard_pile, spare) == 1,
		"the older duplicate still waits in discard before the reshuffling play")

	var spare_callback := _bound_callback(spare)
	_check(spare_callback.is_valid(), "the held Spare Parts panel is bound before its commit")
	var before_blocks := _blocks(app.party.get_heroes())
	await _commit(spare, false, 0, oracle)
	_check(_state() == _oracle_state(oracle),
		"the reshuffling third-owner play matches the oracle: Block, piles, energy and RNG")
	_check(app.deck.draw_pile.size() == 4 and app.deck.discard_pile == [spare],
		"the committed draw reshuffled the old discard and appended only the played copy")
	_check(app.deck.energy == 1 and app.deck.hand.size() == 2,
		"the awarded draw added one shared card without extra energy")
	var progress: Dictionary = app._quilt_bonus.get_patch_progress()
	_check(progress.awarded and progress.patches.warden.played
		and progress.patches.seamstress.played and progress.patches.tinker.played,
		"the reshuffled duplicate still yields all three owner receipts exactly once")
	_check(progress == oracle["quilt"].get_patch_progress(),
		"mounted duplicate-ID progress equals the detached service")
	_assert_quilt_read_only("duplicate-ID third owner and reshuffle award")
	var award_delta := {}
	var after_blocks := _blocks(app.party.get_heroes())
	for hero_id in after_blocks:
		award_delta[hero_id] = int(after_blocks[hero_id]) - int(before_blocks.get(hero_id, 0))
	var spare_block := int(_definition(spare).get("effects", {}).get("block", 0))
	_check(spare_block > 0 and award_delta == {
		"warden": CombatQuiltBonus.BLOCK_REWARD,
		"seamstress": CombatQuiltBonus.BLOCK_REWARD,
		"tinker": CombatQuiltBonus.BLOCK_REWARD + spare_block},
		"every living hero gained exactly the award's three Block over the gadget's own Block")
	_check(app.run_rng.state == oracle["deck"]._rng.state,
		"the reshuffle consumed exactly the detached oracle's seeded RNG")

	# Negative controls: the consumed panel and a duplicate receipt replay nothing.
	var awarded_state := _state()
	spare_callback.call(InputEventMouseButton.new())
	await _frames()
	_check(_state() == awarded_state and app._quilt_bonus.get_patch_progress() == progress,
		"the consumed Spare Parts callback invents no receipt after an awarded reshuffle")
	_check(not app._quilt_bonus.record_confirmed_play("tinker").triggered
		and not app._quilt_bonus.record_confirmed_play("warden").triggered
		and _state() == awarded_state,
		"duplicate confirmed owners cannot replay the reshuffled award")
	# A genuinely held card drawn by the award replays no second Block or draw.
	var post_award := _first_playable()
	_check(not post_award.is_empty(), "the awarded crafted hand still holds a playable card")
	if not post_award.is_empty():
		await _commit(post_award.id, true, int(post_award.target), oracle)
		_check(_state() == _oracle_state(oracle)
			and app._quilt_bonus.get_patch_progress() == progress,
			"a post-award held play matches the oracle and replays no award")
	await _click(app.return_button)
	_check(app.deck == null and app._quilt_bonus == null,
		"Return clears the duplicate-ID battle quota")


## A trusted published stitched descriptor with two owners while the third owner
## is downed: both owners count, the downed hero is neither required nor rewarded.
func _scenario_stitched_owners() -> void:
	if not await _open_route(fixture.seed) or not await _choose_fight(fixture.fight):
		return
	# A real Rest transaction publishes the canonical two-owner descriptor.
	var ledger := RunRestStitchCards.new(app.run_deck, {}, 3, 1)
	_check(ledger.is_valid(), "starter run deck is a valid Rest ledger")
	if not ledger.is_valid():
		return
	var made := ledger.choose_stitch(app.run_deck.find("warden_strike"),
		app.run_deck.find("seamstress_v3_thread_prick"), ledger.get_snapshot())
	_check(bool(made.get("ok", false)) and made.descriptor.half_ids ==
		["warden_strike", "seamstress_v3_thread_prick"], "real Rest action publishes the two-owner descriptor")
	if not bool(made.get("ok", false)):
		return
	app.run_deck = made.deck.duplicate()
	app.run_stitch_descriptors = made.descriptors.duplicate(true)
	app.run_scraps = made.remaining_scraps
	app.run_next_stitch_id = made.next_stitch_id
	var stitched_id: String = made.stitched_id
	var owners: Array[String] = _owners(stitched_id)
	_check(owners == ["warden", "seamstress"],
		"the trusted descriptor names its two distinct owners")

	# Real adjacent swap keeps both owner identities while changing positions.
	var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
	_check(swap.ok and swap.heroes[0].id == "seamstress" and swap.heroes[1].id == "warden",
		"real adjacent swap moves both owners to different positions")
	app.party._heroes.assign(swap.heroes)
	for index in range(CombatParty.PARTY_SIZE):
		app.party._heroes[index]["block"] = 0
	_check(app.party.apply_damage(3, 999) and app.party.is_downed(3),
		"actual damage downs the third owner")
	app._refresh_party()
	_check(app.party.get_hero(1).id == "seamstress" and app.party.get_hero(1).hp > 0
		and app.party.get_hero(2).id == "warden" and app.party.get_hero(2).hp > 0,
		"the two composite owners are living at new positions")
	await _frames()
	_assert_quilt_read_only("swapped roster with downed Tinker before any composite play")
	var foes: Array = app.enemies.get_enemies()
	for index in range(foes.size()):
		app.enemies._enemies[index]["max_hp"] = maxi(int(foes[index]["max_hp"]), 60)
		app.enemies._enemies[index]["hp"] = app.enemies._enemies[index]["max_hp"]

	# The mounted Fight began from the plain starter deck; hold the owned composite
	# exactly as a later routed Fight's admitted deck would (the opening Fight
	# legally precedes the Rest that creates it).
	var held_before: Dictionary = app._quilt_bonus.get_patch_progress()
	app.deck.hand.append(stitched_id)
	app._refresh_hand()
	await _frames()
	_check(_panel(stitched_id) != null and presenter._bindings.has(_panel(stitched_id)),
		"the composite is genuinely held and bound to the production presenter")
	_check(app._quilt_bonus.get_patch_progress() == held_before,
		"simply holding the composite invents no receipt")
	_check(app._quilt_bonus.get_patch_progress().patches.tinker.living == false,
		"the downed Tinker is excluded before the play")

	# Detached oracle: same swapped/downed roster and the same real shared state.
	var oracle := _oracle()
	_check(not oracle.is_empty(), "detached Quilt service binds the swapped roster")
	if oracle.is_empty():
		return
	var oracle_ledger := RunRestStitchCards.new(app.run_deck,
		app.run_stitch_descriptors.duplicate(true), app.run_scraps, app.run_next_stitch_id)
	var expected := CombatStitchedCards.new(oracle["attacks"]).play_stitched(
		oracle["deck"], oracle["party"], oracle["enemies"], oracle_ledger, stitched_id, 1, 2)
	_check(expected.ok, "independent scene-free composite transaction succeeds")
	var before := _state()
	_check(await _arm(stitched_id, true), "keyboard input selects the held composite")
	await _key(KEY_1)
	await _key(KEY_2)
	await _frames()
	_check(presenter.last_event == expected, "physical composite event equals the detached oracle")
	var quilt: CombatQuiltBonus = oracle["quilt"]
	var first_receipt := quilt.record_confirmed_play("warden")
	var second_receipt := quilt.record_confirmed_play("seamstress")
	_check(first_receipt.triggered == false and second_receipt.triggered == true
		and second_receipt.drawn == 1, "two owners complete the quota with one real draw")
	_check(_state() == _oracle_state(oracle),
		"stitched completion matches the oracle: Block, draw/hand/discard, energy and RNG")
	_check(_blocks(app.party.get_heroes()) == {"seamstress": 3, "warden": 3, "tinker": 0},
		"both living owners gain three Block; the downed owner gains none")
	var progress: Dictionary = app._quilt_bonus.get_patch_progress()
	_check(progress.awarded and progress.patches.warden.played
		and progress.patches.seamstress.played and not progress.patches.tinker.played
		and not progress.patches.tinker.living,
		"two distinct owner identities fill the quota exactly once")
	_check(progress == quilt.get_patch_progress(), "mounted progress equals the detached service")
	_assert_quilt_read_only("stitched two-owner award leaves downed patch muted")
	_check(app.deck.hand.size() == before[0].size()
		and app.deck.discard_pile.size() == before[2].size() + 1,
		"the composite moved one copy to discard and the award drew one shared card")
	var awarded := _state()
	await _key(KEY_1)
	await _key(KEY_2)
	_check(_state() == awarded and app._quilt_bonus.get_patch_progress() == progress,
		"a repeated composite target after the award replays nothing")
	await _click(app.return_button)
	_check(app.deck == null and app._quilt_bonus == null, "Return clears the stitched battle quota")




func _sew_switchback_wardrobe(wearer: String = "warden") -> RunPatchWardrobe:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	_check(raw is Array, "Switchback: catalog parsed")
	var definitions: Array = []
	if raw is Array:
		for entry in raw:
			definitions.append({"id": entry.id, "slot": entry.slot})
	var carry := app.party_carryover as RunTornCarryover
	_check(carry != null and carry.is_valid(), "Switchback: carryover valid")
	if not app.run_trinkets.has("switchback_button"):
		app.run_trinkets.append("switchback_button")
	var wardrobe := RunPatchWardrobe.new(app.run_heroes,
		app.run_trinkets, definitions, app.run_scraps, app.session_gold, app.run_deck, app.run_seed)
	_check(wardrobe.is_valid(), "Switchback: wardrobe valid")
	if wearer != "":
		var sew_result := wardrobe.sew("switchback_button", wearer, "HEAD", "sew", wardrobe.get_snapshot())
		_check(sew_result.ok, "Switchback: sew succeeded")
	_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()), "Switchback: bind succeeded")
	presenter.ensure_quilt_switchback_bound()
	return wardrobe


func _scenario_switchback_ordinary_and_quilt(seed_fixture: Dictionary) -> Array:
	if not await _open_route(seed_fixture.seed) or not await _choose_fight(seed_fixture.fight):
		return []
	var wardrobe := _sew_switchback_wardrobe("warden")
	var quilt: CombatQuiltBonus = app._quilt_bonus
	_check(quilt != null and quilt.is_switchback_active(), "Switchback ordinary: active on combat Quilt authority")
	var initial_sw: Dictionary = quilt.get_switchback_state()
	_check(not initial_sw.consumed and initial_sw.prev_owner == "" and initial_sw.receipts_observed.is_empty(),
		"Switchback ordinary: clean opening state")

	for index in range(CombatParty.PARTY_SIZE):
		app.party._heroes[index]["block"] = 0
	var foes: Array = app.enemies.get_enemies()
	for index in range(foes.size()):
		app.enemies._enemies[index]["max_hp"] = maxi(int(foes[index]["max_hp"]), 60)
		app.enemies._enemies[index]["hp"] = app.enemies._enemies[index]["max_hp"]

	app.deck.hand.assign(["warden_brace", "seamstress_prick", "warden_strike", "tinker_tune_up"])
	app.deck.energy = 3
	app._refresh_hand()
	await _frames()

	var trace: Array = [_state()]

	# Step 1: Warden plays warden_brace (wearer plays first: no prior owner -> no switchback award)
	var warden_block_before: int = app.party.get_hero(1).block
	_check(warden_block_before == 0, "Warden starts at 0 Block")
	await _play_support("warden_brace", false, 0)
	await _frames()
	var warden_block_after_brace: int = app.party.get_hero(1).block
	_check(warden_block_after_brace == 7, "Warden brace grants printed 7 Block only, no switchback on opening play")
	var sw_state: Dictionary = quilt.get_switchback_state()
	_check(not sw_state.consumed and sw_state.prev_owner == "warden" and sw_state.receipts_observed.size() == 1,
		"Switchback: Warden receipt recorded, latch unconsumed")
	trace.append(_state())

	# Step 2: Seamstress plays seamstress_prick on enemy 1 (different living owner sets up transition)
	var seam_block_before: int = app.party.get_hero(2).block
	await _play_attack("seamstress_prick", false, 1)
	await _frames()
	var seam_block_after: int = app.party.get_hero(2).block
	_check(seam_block_after == seam_block_before, "Seamstress has no Switchback patch, Block unchanged")
	sw_state = quilt.get_switchback_state()
	_check(not sw_state.consumed and sw_state.prev_owner == "seamstress" and sw_state.receipts_observed.size() == 2,
		"Switchback: Seamstress receipt recorded, prev_owner advanced to seamstress")
	trace.append(_state())

	# Step 3: Warden plays warden_strike on enemy 1 (wearer immediately follows DIFFERENT living hero -> EXACTLY +2 Block!)
	var warden_block_before_strike: int = app.party.get_hero(1).block
	_check(warden_block_before_strike == 7, "Warden before strike still at 7 Block")
	await _play_attack("warden_strike", false, 1)
	await _frames()
	var warden_block_after_strike: int = app.party.get_hero(1).block
	_check(warden_block_after_strike == 9, "AC1: Warden wearer immediately following Seamstress gains exactly +2 Block (total 9)")
	sw_state = quilt.get_switchback_state()
	_check(sw_state.consumed and sw_state.prev_owner == "warden" and sw_state.receipts_observed.size() == 3,
		"Switchback: latch consumed, Warden receipt recorded")
	trace.append(_state())

	# Step 4: Duplicate / repeat transition within the same turn:
	# Tinker plays tinker_tune_up (free support)
	await _play_support("tinker_tune_up", false, 0)
	await _frames()
	sw_state = quilt.get_switchback_state()
	_check(sw_state.consumed and sw_state.prev_owner == "tinker" and sw_state.receipts_observed.size() == 4,
		"Switchback: Tinker receipt recorded, latch remains consumed")
	var progress: Dictionary = quilt.get_patch_progress()
	_check(progress.awarded and progress.patches.warden.played and progress.patches.seamstress.played and progress.patches.tinker.played,
		"AC4: Quilt bonus awarded when all 3 living heroes have played")
	var blocks_after_quilt: Dictionary = _blocks(app.party.get_heroes())
	_check(blocks_after_quilt == {"warden": 12, "seamstress": 3, "tinker": 3},
		"AC4: Quilt awards exactly +3 Block to each living hero (Warden 9+3=12, Seamstress 3, Tinker 3)")
	trace.append(_state())

	# Step 5: Second eligible transition by Warden in the same turn:
	app.deck.hand.assign(["warden_brace"])
	app.deck.combat_state.energy = 1
	app._refresh_hand()
	await _frames()
	await _play_support("warden_brace", false, 0)
	await _frames()
	var warden_block_after_repeat: int = app.party.get_hero(1).block
	_check(warden_block_after_repeat == 12 + 7, "Switchback: repeat eligible transition in same turn grants ONLY printed 7 Block (19), no extra Switchback")
	_check(quilt.get_switchback_state().consumed, "Switchback latch remains consumed")
	trace.append(_state())

	# Step 6: End Turn and New Player Turn re-arms Switchback
	await _click(app.end_turn_button)
	await _frames()
	_check(app.deck.turn_active and not app._battle_closed, "New turn active")
	var new_quilt: CombatQuiltBonus = app._quilt_bonus
	_check(new_quilt != null and new_quilt.is_switchback_active(), "Switchback active in new turn")
	var new_sw: Dictionary = new_quilt.get_switchback_state()
	_check(not new_sw.consumed and new_sw.prev_owner == "", "AC3: New player turn re-arms Switchback (consumed false, prev_owner empty)")
	var new_blocks: Dictionary = _blocks(app.party.get_heroes())
	_check(new_blocks == {"warden": 0, "seamstress": 0, "tinker": 0}, "Party Block reset on new turn")

	# Step 7: Prove re-armed Switchback triggers in new turn:
	app.deck.hand.assign(["seamstress_prick", "warden_brace"])
	app.deck.energy = 3
	app._refresh_hand()
	await _frames()
	await _play_attack("seamstress_prick", false, 1)
	await _frames()
	await _play_support("warden_brace", false, 0)
	await _frames()
	_check(app.party.get_hero(1).block == 7 + 2, "AC3: Re-armed Switchback triggers in new turn granting exactly +2 Block (total 9)")
	_check(new_quilt.get_switchback_state().consumed, "Switchback consumed once again in new turn")
	trace.append(_state())

	await _click(app.return_button)
	await _frames()
	return trace


func _scenario_switchback_stitched(seed_fixture: Dictionary) -> void:
	if not await _open_route(seed_fixture.seed) or not await _choose_fight(seed_fixture.fight):
		return
	# Create the stitch first so run_deck and run_scraps are published before wardrobe binding:
	var ledger := RunRestStitchCards.new(app.run_deck, {}, 3, 1)
	var made := ledger.choose_stitch(app.run_deck.find("seamstress_v3_thread_prick"),
		app.run_deck.find("warden_strike"), ledger.get_snapshot())
	_check(bool(made.get("ok", false)), "Switchback stitched: created composite seamstress + warden")
	if not bool(made.get("ok", false)):
		await _click(app.return_button)
		return
	app.run_deck = made.deck.duplicate()
	app.run_stitch_descriptors = made.descriptors.duplicate(true)
	app.run_scraps = made.remaining_scraps
	app.run_next_stitch_id = made.next_stitch_id
	var stitched_id: String = made.stitched_id

	# Now bind genuinely sewn wardrobe with Switchback Button on Warden:
	var wardrobe := _sew_switchback_wardrobe("warden")
	var quilt: CombatQuiltBonus = app._quilt_bonus
	_check(quilt != null and quilt.is_switchback_active(), "Switchback stitched: active")

	for index in range(CombatParty.PARTY_SIZE):
		app.party._heroes[index]["block"] = 0
	var foes: Array = app.enemies.get_enemies()
	for index in range(foes.size()):
		app.enemies._enemies[index]["max_hp"] = maxi(int(foes[index]["max_hp"]), 60)
		app.enemies._enemies[index]["hp"] = app.enemies._enemies[index]["max_hp"]

	app.deck.hand.assign([stitched_id])
	app.deck.energy = 3
	app._refresh_hand()
	await _frames()

	# Partial selection then cancellation (ESC):
	_check(await _arm(stitched_id, true), "Stitched card armed")
	await _key(KEY_1)
	await _frames()
	_check(presenter._choices.size() == 1, "Half 0 chosen, half 1 pending")
	await _key(KEY_ESCAPE)
	await _frames()
	_check(presenter._armed == null and presenter._choices.is_empty(), "Partial stitched selection cancelled")
	var sw_state: Dictionary = quilt.get_switchback_state()
	_check(not sw_state.consumed and sw_state.prev_owner == "" and sw_state.receipts_observed.is_empty(),
		"AC2: Cancelled partial stitched selection forwards NO receipts and consumes NO latch")
	_check(_blocks(app.party.get_heroes()) == {"warden": 0, "seamstress": 0, "tinker": 0},
		"Party Block unchanged after cancelled partial stitch")

	# Genuine commitment of composite (Seamstress half 0, Warden half 1):
	_check(await _arm(stitched_id, true), "Stitched card re-armed")
	await _key(KEY_1)
	await _key(KEY_1)
	await _frames()

	_check(presenter.last_event.get("ok", false), "Stitched play committed successfully")
	sw_state = quilt.get_switchback_state()
	_check(sw_state.consumed, "AC2: Stitched second half (Warden) triggered Switchback latch")
	_check(sw_state.prev_owner == "warden", "AC2: Final owner pointer is second half (warden)")
	_check(sw_state.receipts_observed.size() == 2, "AC2: Exactly two ordered half receipts observed")
	_check(sw_state.receipts_observed[0].begins_with("stitched_") and sw_state.receipts_observed[1].begins_with("stitched_"),
		"AC2: Distinct stitched half receipt IDs")
	_check(app.party.get_hero(1).block == 2, "AC2: Warden gained exactly +2 Block from Switchback on second half")

	await _click(app.return_button)
	await _frames()


func _scenario_switchback_negatives() -> void:
	# Negative 1: Unequipped wardrobe (no Switchback Button)
	if not await _open_route(fixture.seed) or not await _choose_fight(fixture.fight):
		return
	var wardrobe_unworn := _sew_switchback_wardrobe("")
	var quilt: CombatQuiltBonus = app._quilt_bonus
	_check(quilt != null and not quilt.is_switchback_active(), "AC3: Unequipped wardrobe fails closed (switchback inactive)")
	for index in range(CombatParty.PARTY_SIZE):
		app.party._heroes[index]["block"] = 0
	app.deck.hand.assign(["seamstress_prick", "warden_brace"])
	app.deck.energy = 3
	app._refresh_hand()
	await _frames()
	await _play_attack("seamstress_prick", false, 1)
	await _frames()
	await _play_support("warden_brace", false, 0)
	await _frames()
	_check(app.party.get_hero(1).block == 7, "AC3: Unworn Switchback grants NO +2 Block (only printed 7)")
	await _click(app.return_button)
	await _frames()

	# Negative 2: Torn wearer
	if not await _open_route(fixture.seed) or not await _choose_fight(fixture.fight):
		return
	var wardrobe_torn := _sew_switchback_wardrobe("warden")
	quilt = app._quilt_bonus
	_check(quilt != null and quilt.is_switchback_active(), "Switchback active before tear")
	var carry := app.party_carryover as RunTornCarryover
	var start_heroes: Array = carry.torn.read_state().heroes
	var end_heroes: Array = start_heroes.duplicate(true)
	end_heroes[0].hp = 0
	_check(carry.torn.observe_battle_end("tear_node", start_heroes, end_heroes).ok, "Tear recorded on Warden")
	_check(carry.torn.read_state().tear_counts.warden == 1, "Warden tear count is 1")
	wardrobe_torn.refresh_run_context(app.run_heroes, app.run_trinkets, app.run_scraps, app.session_gold, app.run_deck, wardrobe_torn.get_snapshot())
	for index in range(CombatParty.PARTY_SIZE):
		app.party._heroes[index]["block"] = 0
	app.deck.hand.assign(["seamstress_prick", "warden_brace"])
	app.deck.energy = 3
	app._refresh_hand()
	await _frames()
	await _play_attack("seamstress_prick", false, 1)
	await _frames()
	await _play_support("warden_brace", false, 0)
	await _frames()
	_check(app.party.get_hero(1).block == 7, "AC3: Torn wearer gains NO +2 Block (only printed 7)")
	_check(not quilt.get_switchback_state().consumed, "AC3: Torn wearer leaves Switchback latch unconsumed")
	await _click(app.return_button)
	await _frames()

	# Negative 3: Downed wearer
	if not await _open_route(fixture.seed) or not await _choose_fight(fixture.fight):
		return
	_sew_switchback_wardrobe("warden")
	quilt = app._quilt_bonus
	for index in range(CombatParty.PARTY_SIZE):
		app.party._heroes[index]["block"] = 0
	_check(app.party.apply_damage(1, 999) and app.party.is_downed(1), "Warden downed by combat damage")
	app.deck.hand.assign(["seamstress_prick", "warden_brace"])
	app.deck.energy = 3
	app._refresh_hand()
	await _frames()
	await _play_attack("seamstress_prick", false, 1)
	await _frames()
	var state_before_downed_cast: Array = _state()
	await _play_support("warden_brace", false, 0)
	await _frames()
	_check(_state() == state_before_downed_cast, "AC3: Downed wearer play is rejected; combat state unchanged")
	_check(not quilt.get_switchback_state().consumed, "AC3: Downed wearer leaves latch unconsumed")
	await _click(app.return_button)
	await _frames()

	# Negative 4: Stale wardrobe fails closed
	if not await _open_route(fixture.seed) or not await _choose_fight(fixture.fight):
		return
	_sew_switchback_wardrobe("warden")
	quilt = app._quilt_bonus
	_check(quilt.is_switchback_active(), "Switchback active before drift")
	var gold_before: int = app.session_gold
	app.session_gold += 99
	presenter.ensure_quilt_switchback_bound()
	_check(not quilt.is_switchback_active(), "AC3: Stale wardrobe fails closed (switchback disabled)")
	for index in range(CombatParty.PARTY_SIZE):
		app.party._heroes[index]["block"] = 0
	app.deck.hand.assign(["seamstress_prick", "warden_brace"])
	app.deck.energy = 3
	app._refresh_hand()
	await _frames()
	await _play_attack("seamstress_prick", false, 1)
	await _frames()
	await _play_support("warden_brace", false, 0)
	await _frames()
	_check(app.party.get_hero(1).block == 7, "AC3: Stale wardrobe grants NO Switchback Block")
	app.session_gold = gold_before
	await _click(app.return_button)
	await _frames()

	# Negative 5: Insufficient energy / rejected play does not set up or claim transition
	if not await _open_route(fixture.seed) or not await _choose_fight(fixture.fight):
		return
	_sew_switchback_wardrobe("warden")
	quilt = app._quilt_bonus
	for index in range(CombatParty.PARTY_SIZE):
		app.party._heroes[index]["block"] = 0
	app.deck.hand.assign(["seamstress_prick", "warden_brace"])
	app.deck.combat_state.energy = 0
	app._refresh_hand()
	await _frames()
	var state_before_rejected: Array = _state()
	var sw_before_rejected: Dictionary = quilt.get_switchback_state()
	await _play_attack("seamstress_prick", false, 1)
	await _frames()
	_check(_state() == state_before_rejected and quilt.get_switchback_state() == sw_before_rejected,
		"AC3: Rejected 0-energy play leaves combat state and Switchback tracker untouched")
	await _click(app.return_button)
	await _frames()


func _run() -> void:
	_hearth_rule_cases()
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	# Mounting the real scene builds the presentation-only felt puff reserve, and a
	# CPUParticles2D seeds itself from the global RNG once when it is built. The mounted-play
	# guard therefore starts after the mount and still covers every play, rejection and Return.
	seed(915033)
	var global_next := randi()
	seed(915033)
	presenter = app.get_node("LiveAttackPreview")
	support = app.get_node("LiveSupportHand")
	fixture = _find_fixture("warden_brace")
	_check(not fixture.is_empty() and fixture.plan.warden == "warden_brace",
		"seeded routed fight deals a Warden Brace three-owner hand")
	var strike_fixture := _find_fixture("warden_strike")
	_check(not strike_fixture.is_empty() and strike_fixture.plan.warden == "warden_strike",
		"seeded routed fight also deals a Warden Strike three-owner hand")
	if fixture.is_empty() or strike_fixture.is_empty():
		app.free()
		await _frames()
		_finish()
		return
	var first := await _scenario_three_owners(fixture)
	var replay := await _scenario_three_owners(fixture)
	_check(first.size() > 4 and replay == first,
		"same seeded route replays the complete three-owner trace exactly")
	# The same contract must hold when the Warden plays a real enemy-targeted
	# Strike, whose committed receipt and stale callback use a legal enemy slot.
	var strike_first := await _scenario_three_owners(strike_fixture)
	var strike_replay := await _scenario_three_owners(strike_fixture)
	_check(strike_first.size() > 4 and strike_replay == strike_first,
		"the Warden Strike seed replays the complete three-owner trace exactly")
	await _scenario_reshuffle_duplicate(fixture)
	await _scenario_stitched_owners()
	var sw_first := await _scenario_switchback_ordinary_and_quilt(fixture)
	var sw_replay := await _scenario_switchback_ordinary_and_quilt(fixture)
	_check(sw_first.size() > 4 and sw_replay == sw_first,
		"AC1/AC3: Switchback ordinary trace replays deterministically (Block, energy, piles, RNG)")
	await _scenario_switchback_stitched(fixture)
	await _scenario_switchback_negatives()
	_check(randi() == global_next,
		"mounted plays, rejections, End Turn and Return preserve the global RNG")
	app.free()
	await _frames()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_quilt_bonus_hand_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Supplement mounted acquisition coverage with explicit ineligible and failed
## Quilt transactions. Only successful support plays are reported to the rule.
func _hearth_rule_cases() -> void:
	for mode in ["live", "dead", "torn", "stale", "unworn", "overflow"]:
		var party := CombatParty.new([{"id": "warden", "max_hp": 40},
			{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}])
		var torn := RunTornMending.new(party.get_heroes())
		var wardrobe := RunPatchWardrobe.new(party.get_heroes(), ["hearth_lining"],
			RunAuthoredPatchDefinitions.load_definitions(), 0)
		_check(wardrobe.is_valid() and torn.is_valid(), "Hearth authorities genuinely admitted: " + mode)
		if mode != "unworn":
			_check(wardrobe.sew("hearth_lining", "warden", "COAT", "hearth", wardrobe.get_snapshot()).ok,
				"Hearth actual worn COAT: " + mode)
		if mode == "torn":
			torn._tear_counts.warden = 1
		var rng := RandomNumberGenerator.new()
		rng.seed = 317
		var deck := CombatDeck.new(["warden_brace", "seamstress_stitch_up", "tinker_tune_up"], rng)
		_check(deck.start_turn(), "Hearth real turn starts")
		var quilt := CombatQuiltBonus.new(party, deck)
		quilt.bind_hearth(wardrobe, torn)
		_check(quilt.begin_player_turn(), "Hearth quota opens")
		_check(party.apply_damage(1, 6), "Hearth living wearer wounded by six")
		if mode == "dead":
			_check(party.apply_damage(1, 999), "Hearth wearer actually downed")
		if mode == "stale":
			_check(wardrobe.refresh_run_context(wardrobe.get_snapshot().heroes, ["hearth_lining"],
				0, 1, [], wardrobe.get_snapshot()), "Hearth context changed after admission")
		var hp: int = party.get_hero(1).hp
		_check(not quilt.record_confirmed_play("unknown").ok and party.get_hero(1).hp == hp,
			"invalid attempted owner never earns Hearth")
		for id in ["warden_brace", "seamstress_stitch_up", "tinker_tune_up"]:
			var definition := catalog.get_definition(id)
			var target := 3 if id == "seamstress_stitch_up" else 0
			if CombatStarterSupportPlay.new().play_card(deck, party, id, target):
				if mode == "overflow" and id == "tinker_tune_up":
					party._heroes[2].block = CombatParty.MAX_INT
				quilt.record_confirmed_play(definition.owner)
		_check(party.get_hero(1).hp == (hp + 2 if mode == "live" else hp),
			"only genuine earned Quilt and living untorn current wearer heals exactly two: " + mode)
		_check(quilt._hearth_used == (mode != "overflow"), "failed Quilt does not spend Hearth: " + mode)
		if mode == "live":
			_check(deck.end_turn() and deck.start_turn() and quilt.advance_confirmed_turn(),
				"next actual turn refreshes the same quota")
			_check(party.apply_damage(1, party.get_hero(1).block + 4), "wound wearer again next turn")
			var next_hp: int = party.get_hero(1).hp
			for owner in ["warden", "seamstress", "tinker"]:
				quilt.record_confirmed_play(owner)
			_check(quilt.get_patch_progress().awarded and party.get_hero(1).hp == next_hp,
				"later genuinely earned Quilt cannot repeat Hearth heal")
			var next_fight := CombatQuiltBonus.new(party, deck)
			next_fight.bind_hearth(wardrobe, torn)
			_check(next_fight.begin_player_turn(), "new battle admits fresh Hearth latch")
			for owner in ["warden", "seamstress", "tinker"]:
				next_fight.record_confirmed_play(owner)
			_check(party.get_hero(1).hp == next_hp + 2, "new fight resets Hearth eligibility")
