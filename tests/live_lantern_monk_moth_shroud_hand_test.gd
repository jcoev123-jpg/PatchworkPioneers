extends "res://tests/live_support_hand_test.gd"
## Lantern Monk Moth Shroud / Moth Shroud+ played from the REAL shared support hand (V3-1).
##
## Every case starts a genuine seeded app battle, replaces its deck with a real CombatDeck
## draw that holds authentic copies of the printed pool card and seats a living Lantern Monk
## in one of the two authored FROM seats (2 or 3). The drawn panel is clicked or focused and
## played through the shared hand's own living-ally target control (real hero panels), and
## the shipped paid resolver charges exactly one energy, discards exactly the held copy, adds
## the printed Block (6 base / 8 plus) and arms the one-shot Dodge (kept at 1, never 2).
##
## The face and its hover help are read from the very catalog record that resolver
## authenticates. The real CombatWardenGuardReactions then consumes that Dodge on the next
## genuine incoming attack without damage. Every refusal, stale callback and replay leaves
## deck, party, enemies, intents, attack list, result, economy and RNG byte-identical.

const IDS := ["lantern_monk_moth_shroud", "lantern_monk_moth_shroud_plus"]
const DODGE := "dodge_next_attack"


func _catalog(id: String) -> Dictionary:
	return LanternMonkPoolCards.new().get_definition(id)


func _title(id: String) -> String:
	return "Moth Shroud+" if id.ends_with("_plus") else "Moth Shroud"


func _block(id: String) -> int:
	return 8 if id.ends_with("_plus") else 6


## The real mounted app battle with a genuine two-copy drawn hand and a living Monk in `seat`.
func _begin(id: String, seat: int = 2, energy: int = 3) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	_check(app.deck == null, "the title screen precedes the Shroud battle: " + id)
	app.run_seed = 4247
	_check(app._start_battle(), "the shipped App admits a real standalone battle: " + id)
	presenter = app.get_node_or_null("LiveSupportHand")
	var legacy = app.get_node_or_null("LiveLanternMonkPoleShelterHand")
	_check(presenter != null and legacy != null,
		"the real shared hand and the older hero-specific hand are both scene-mounted")
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_rng.seed
	var cards: Array[String] = [id, "warden_strike", "seamstress_prick", "tinker_tune_up", id]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.size() == 5 and app.deck.hand.count(id) == 2,
		"a genuine five-card draw holds two authentic copies: " + id)
	app.deck.combat_state.energy = energy
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "lantern_monk", "name": "Lantern Monk", "max_hp": 30})
	app.party = CombatParty.new(heroes)
	_check(app.party.is_valid() and app.party.get_hero(seat).get("id") == "lantern_monk"
		and int(app.party.get_hero(seat).get("hp")) > 0 and app.enemies.is_valid()
		and app.enemies.get_enemies().size() >= 1,
		"a living Monk really sits in authored seat %d beside a real enemy roster" % seat)
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and panel is PanelContainer and panel.is_visible_in_tree()
		and presenter._bindings.has(panel), "the drawn copy is really mounted and bound: " + id)
	_check(panel != null and presenter._bindings.has(panel)
		and panel.gui_input.get_connections().size() == 1,
		"the drawn copy has exactly ONE real input owner: " + id)
	_check(legacy != null and not legacy._bindings.has(panel),
		"the older hero-specific hand yields these IDs to the shared hand: " + id)
	return panel


func _dispose() -> void:
	if is_instance_valid(app):
		app.free()
	await _frames()


## The authentic catalog face, its drawn rule line, the hover help and the real admission.
func _face(id: String, panel: Control) -> void:
	var catalog := _catalog(id)
	var meta = presenter._metadata
	var facts: Dictionary = meta.get_facts(panel)
	_check(not catalog.is_empty() and catalog.get("id") == id
		and catalog.get("owner") == "lantern_monk" and int(catalog.get("cost")) == 1
		and catalog.get("target_kind") == "ally_single"
		and catalog.get("from_positions") == [2, 3]
		and (catalog.get("to_positions", []) as Array).is_empty()
		and catalog.get("effects") == {"block": _block(id), DODGE: 1}
		and bool(catalog.get("reward_eligible")) == (id == IDS[0]),
		"the authored catalog record really is this printing: " + id)
	_check(meta.definition(id) == catalog, "the drawn face is that authentic catalog record: " + id)
	_check(facts.get("known") == true and facts.get("display_name") == catalog.get("display_name")
		and int(facts.get("cost")) == 1 and facts.get("owner") == "lantern_monk"
		and facts.get("from_text") == "From " + meta._positions([2, 3])
		and facts.get("target_text") == "Ally",
		"the face prints the authentic name, owner, cost and ally target: " + id)
	var short: String = meta.short_line(id)
	_check(short.contains("%d Block" % _block(id)) and short.contains("Dodge"),
		"the face prints the passed Block amount and the Dodge token: " + id)
	var help: String = panel.tooltip_text
	_check(help.contains(_title(id)) and help.contains("Lantern Monk") and help.contains("1 energy")
		and help.contains("%d Block" % _block(id)) and help.contains("Dodge")
		and help.contains("Choose one living ally") and help.contains("spends"),
		"the hover help states the printed Block, the one-shot Dodge and the ally choice: " + id)
	_check(panel.tooltip_text.contains("Click or focus and press Enter / Space to play"),
		"the mounted hand keeps its real playable-card help: " + id)
	_check(bool(meta.visual_state(panel).get("playable", false))
		and presenter.moth_shroud_actionable(panel, id),
		"the face is enabled only by the shared hand's own paid admission: " + id)


func _shroud_expected(before: Array, id: String, target: int) -> Array:
	var after: Array = before.duplicate(true)
	after[1].erase(id)
	after[2].append(id)
	after[3] = int(after[3]) - int(_catalog(id).get("cost", -1))
	var chosen: Dictionary = after[5][target - 1]
	chosen["block"] = int(chosen["block"]) + _block(id)
	if not chosen.has("statuses") or not chosen["statuses"] is Dictionary:
		chosen["statuses"] = {}
	chosen["statuses"][DODGE] = 1
	return after


## The next genuine incoming attack spends the one-shot Dodge with no damage; a following
## real attack lands, proving the token really was one-shot.
func _consume_attack(target: int) -> bool:
	var before := _pool_state()
	var hp: int = int(app.party.get_hero(target).get("hp"))
	var block: int = int(app.party.get_hero(target).get("block"))
	var reactions := CombatWardenGuardReactions.new()
	var receipt: Dictionary = reactions.resolve_enemy_attack(app.party, app.enemies,
		{"type": "attack", "enemy_position": 1, "target_position": target, "amount": 99})
	var expected: Array = before.duplicate(true)
	expected[5][target - 1]["statuses"].erase(DODGE)
	var missed: bool = receipt.get("ok", false) and not bool(receipt.get("applied", true)) \
		and _pool_state() == expected \
		and int(app.party.get_hero(target).get("hp")) == hp \
		and int(app.party.get_hero(target).get("block")) == block
	var landing: Dictionary = reactions.resolve_enemy_attack(app.party, app.enemies,
		{"type": "attack", "enemy_position": 1, "target_position": target, "amount": 1})
	return missed and landing.get("ok", false) and bool(landing.get("applied", false)) \
		and int(app.party.get_hero(target).get("hp")) == hp \
		and int(app.party.get_hero(target).get("block")) == block - 1


func _success(id: String, seat: int, target: int, keyboard: bool, refresh: bool,
		consume: bool) -> Array:
	var panel := await _begin(id, seat, 3)
	if panel == null:
		_check(false, "the Shroud success fixture must start a real mounted battle")
		await _dispose()
		return []
	if refresh:
		# A living recipient that already bears the genuine one-shot Dodge (and Block).
		_check(app.party.gain_block(target, 2), "nonzero pre-existing Block prerequisite")
		app.party._heroes[target - 1]["statuses"] = {DODGE: 1}
		app._refresh_party()
		await _frames()
	panel = _pool_panel(id)
	_check(panel != null and presenter._bindings.has(panel), "the surviving drawn copy stays mounted")
	if panel == null:
		await _dispose()
		return []
	_face(id, panel)
	var card_callback: Callable = presenter._bindings[panel]
	var before := _pool_state()
	if keyboard:
		panel.grab_focus()
		_check(panel.has_focus(), "the drawn card is really keyboard-focused")
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	_check(presenter._pending.get("choosing", false) and presenter._targets.size() == 3
		and presenter._targets.has(app.hero_panels[target - 1]),
		"the real shared-hand ally target control offers every living seat: " + id)
	_check(_pool_state() == before, "the armed selection preview spends nothing including RNG: " + id)
	_check(presenter.cancel_button.is_visible_in_tree(), "cancel stays reachable while choosing")
	_check(presenter.help_label.text.contains(_title(id))
		and presenter.help_label.text.contains("choose a living ally"),
		"the real prompt names the held printing and its ally choice: " + id)
	var cueed := true
	for hero_panel in app.hero_panels:
		if not presenter._targets.has(hero_panel) \
				or String(presenter._targets[hero_panel].cue.text) != "Choose ally":
			cueed = false
	_check(cueed, "each living ally carries only the inert Choose ally cue")
	var target_callback: Callable = presenter._targets[app.hero_panels[target - 1]].callback
	if keyboard:
		app.hero_panels[0].grab_focus()
		for step in range(target - 1):
			await _keyboard(KEY_TAB)
		_check(app.hero_panels[target - 1].has_focus(), "real focus reaches the chosen living ally")
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(app.hero_panels[target - 1])
	var expected := _shroud_expected(before, id, target)
	_check(_pool_state() == expected,
		"exact printed Block, exactly one energy and one discarded copy; every other actor, enemy, intent and RNG unchanged: " + id)
	_check(app.deck.energy == int(before[3]) - 1, "exactly one energy really paid: " + id)
	_check(app.deck.hand.count(id) == int(before[1].count(id)) - 1
		and app.deck.discard_pile.count(id) == int(before[2].count(id)) + 1,
		"exactly the held copy is discarded: " + id)
	var chosen: Dictionary = app.party.get_hero(target)
	_check(int(chosen.get("block")) == int(before[5][target - 1]["block"]) + _block(id),
		"exactly the printed %d Block landed on the chosen ally: %s" % [_block(id), id])
	_check(int((chosen.get("statuses", {}) as Dictionary).get(DODGE, 0)) == 1,
		"the recipient carries exactly one Dodge token, never two: " + id)
	for other in range(1, 4):
		if other == target:
			continue
		_check(app.party.get_hero(other) == before[5][other - 1],
			"every unchosen ally is untouched: " + id)
	_check(presenter._pending.is_empty() and presenter._targets.is_empty(),
		"the paid commit retires every target control: " + id)
	_check(app.end_turn_button.has_focus(), "a successful Shroud restores End Turn focus: " + id)
	_check(presenter.energy_label.text == str(app.deck.energy)
		and app.pile_label.text.contains("Discard: %d" % app.deck.discard_pile.size()),
		"the sewn energy and pile HUD really refresh: " + id)
	_check(app.hero_panels[target - 1].get_child(0).text.contains("Block: %d" % chosen.block),
		"the chosen ally's real HUD shows the new Block: " + id)
	card_callback.call(_press())
	target_callback.call(_press())
	await _frames()
	_check(_pool_state() == expected, "retired card and ally callbacks cannot replay the charge: " + id)
	if consume:
		_check(_consume_attack(target),
			"the genuine next incoming attack spends only Dodge and deals no damage; the next one lands: " + id)
	await _dispose()
	return expected


## Two genuine copies drawn into one battle: each cast pays exactly once, the surviving
## copy is rebound with a single input owner, and neither retired callback can replay.
func _double_cast(id: String) -> void:
	var panel := await _begin(id, 2, 3)
	if panel == null:
		_check(false, "the double-cast fixture must start a real mounted battle")
		await _dispose()
		return
	var stale_source: Callable = presenter._bindings[panel]
	var before := _pool_state()
	await _mouse(panel)
	_check(presenter._targets.has(app.hero_panels[0])
		and presenter._targets.has(app.hero_panels[2]),
		"the first copy opens the real ally control: " + id)
	await _mouse(app.hero_panels[0])
	var after_first := _shroud_expected(before, id, 1)
	_check(_pool_state() == after_first, "the first of two genuine copies pays exactly once: " + id)
	var surviving := _pool_panel(id)
	_check(surviving != null and surviving != panel and presenter._bindings.has(surviving)
		and surviving.gui_input.get_connections().size() == 1,
		"the surviving genuine copy is rebound with one input owner: " + id)
	stale_source.call(_press())
	await _frames()
	_check(_pool_state() == after_first, "the retired first copy cannot pay a second time: " + id)
	if surviving == null:
		await _dispose()
		return
	await _mouse(surviving)
	_check(presenter._targets.has(app.hero_panels[2]), "the surviving copy opens the real ally control")
	await _mouse(app.hero_panels[2])
	var after_second := _shroud_expected(after_first, id, 3)
	_check(_pool_state() == after_second, "the second copy pays its own printed effect exactly once: " + id)
	_check(app.deck.energy == int(before[3]) - 2, "two genuine casts really spend two energy: " + id)
	_check(app.deck.discard_pile.count(id) == int(before[2].count(id)) + 2
		and not app.deck.hand.has(id), "both genuine copies are discarded exactly once: " + id)
	await _dispose()


## With the real panel still mounted, an unheld, unaffordable, illegally seated, missing,
## torn, hidden or turned-away Shroud cannot even arm the ally control.
func _refuse(mode: String) -> void:
	var id: String = IDS[0]
	var panel := await _begin(id, 2)
	if panel == null:
		await _dispose()
		return
	match mode:
		"absent": _check(app.deck.discard_played(id), "the real held copy is removed before input")
		"energy": app.deck.combat_state.energy = 0
		"owner": _check(app.party.apply_damage(2, 9999) and app.party.is_downed(2),
			"the Monk is genuinely torn before input")
		"seat":
			var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
			_check(swap.get("ok", false) and swap.get("heroes", [])[0].get("id") == "lantern_monk",
				"an authentic adjacent swap moves the Monk out of the authored seats")
			app.party._heroes.assign(swap.heroes)
		"missing": app.party._heroes[1]["id"] = "missing_monk"
		"turn": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"forged": app.deck.hand[panel.get_index()] = "forged_moth_shroud"
		"label": panel.get_child(0).text = IDS[1]
		"hidden": app.battle_view.hide()
	app._refresh_party()
	app._refresh_intents()
	await _frames()
	var before := _pool_state()
	await _mouse(panel)
	_check(_pool_state() == before and presenter._pending.is_empty()
		and presenter._targets.is_empty() and not is_instance_valid(presenter.cleanse_choices),
		"a refused Shroud never stages or spends anything: " + mode)
	_check(panel.gui_input.get_connections().size() == 1,
		"the refusal keeps the one real input owner: " + mode)
	_check(not bool(presenter._metadata.visual_state(panel).get("playable", false)),
		"the refused face is drawn dim rather than enabled: " + mode)
	await _dispose()


## A real queued ally choice that becomes stale (energy, target, owner, seat, hand, panel,
## turn receipt, battle receipt, identity, tampering, Escape or Cancel) must never commit,
## and its captured callback cannot replay.
func _stale(mode: String) -> Array:
	var id: String = IDS[1]
	var panel := await _begin(id, 2)
	if panel == null:
		await _dispose()
		return []
	var target := 1
	await _mouse(panel)
	_check(presenter._pending.get("choosing", false)
		and presenter._targets.has(app.hero_panels[target - 1]),
		"a real ally picker exists before the stale request: " + mode)
	if not presenter._targets.has(app.hero_panels[target - 1]):
		await _dispose()
		return []
	var callback: Callable = presenter._targets[app.hero_panels[target - 1]].callback
	# Queue the real input, then change its authority before the deferred commit runs.
	callback.call(_press())
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"target": _check(app.party.apply_damage(target, 9999) and app.party.is_downed(target),
			"the chosen ally is genuinely torn after queueing")
		"owner": _check(app.party.apply_damage(2, 9999) and app.party.is_downed(2),
			"the Monk is genuinely torn after queueing")
		"seat":
			var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
			_check(swap.get("ok", false), "an authentic swap after queueing")
			app.party._heroes.assign(swap.heroes)
			app._refresh_intents()
		"hand":
			var other := ""
			for held in app.deck.hand:
				if held != id:
					other = held
					break
			_check(not other.is_empty() and app.deck.discard_played(other),
				"the shared hand really changed after queueing")
		"panel": app._refresh_hand()
		"turn": app.deck.combat_state.player_turn_active = false
		"turn_receipt": app.enemy_intents._turn_index += 1
		"battle_receipt": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"battle": app._battle_closed = true
		"identity": app.party._heroes[0]["id"] = "replacement"
		"invalid": presenter._pending.target.position = 4
		"escape": root.push_input(_key(KEY_ESCAPE), true)
		"cancel": presenter.cancel_button.pressed.emit()
	var before := _pool_state()
	await _frames()
	callback.call(_press())
	await _frames()
	_check(_pool_state() == before and presenter._pending.is_empty(),
		"the stale Shroud choice cancels without any change including RNG: " + mode)
	_check(presenter._targets.is_empty() and not is_instance_valid(presenter.cleanse_choices),
		"the stale choice retires every target control: " + mode)
	callback.call(_press())
	await _frames()
	_check(_pool_state() == before, "a refused Shroud choice cannot replay: " + mode)
	if mode in ["escape", "cancel"]:
		# A real cancellation must leave the very same drawn copy genuinely playable.
		await _mouse(_pool_panel(id))
		_check(presenter._targets.has(app.hero_panels[2]),
			"the same drawn copy re-arms after a real cancel: " + mode)
		await _mouse(app.hero_panels[2])
		_check(_pool_state() == _shroud_expected(before, id, 3),
			"after cancel/Escape the same drawn copy plays its printed effect exactly once: " + mode)
	await _dispose()
	return before


func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Both authentic printings, both authored FROM seats and every living ally seat,
	# alternating real mouse and keyboard input. The Monk's own seat is a genuine
	# self-cast; the last case of each pair also runs the real incoming attack.
	for id in IDS:
		for seat in [2, 3]:
			for target in [1, 2, 3]:
				await _success(id, seat, target, (seat + target) % 2 == 1, false, target == seat)
	# Re-casting on a living recipient that already bears Dodge keeps it at exactly 1
	# (never a second stack) and still awards the printed Block.
	for id in IDS:
		for keyboard in [false, true]:
			await _success(id, 2, 1, keyboard, true, true)
	for id in IDS:
		await _double_cast(id)
	for mode in ["absent", "energy", "owner", "seat", "missing", "turn", "closed", "forged", "label", "hidden"]:
		await _refuse(mode)
	for mode in ["energy", "target", "owner", "seat", "hand", "panel", "turn", "turn_receipt",
			"battle_receipt", "battle", "identity", "invalid", "escape", "cancel"]:
		await _stale(mode)
	_finish()
