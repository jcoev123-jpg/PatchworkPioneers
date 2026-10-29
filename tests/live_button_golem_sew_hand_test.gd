extends "res://tests/live_button_golem_pop_hand_test.gd"

const SEW_IDS := ["button_golem_starter_seam_resew", "button_golem_starter_seam_resew_plus",
	"button_golem_sew_on", "button_golem_sew_on_plus"]


func _sew_success(id: String, seat: int, input: int, count: int) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	app.party._heroes[seat - 1].buttons_popped = count
	var meta = presenter._metadata
	var definition: Dictionary = ButtonGolemStarterCards.new().get_definition(id) if id.begins_with("button_golem_starter") else ButtonGolemPoolCards.new().get_definition(id)
	var facts: Dictionary = meta.get_facts(panel)
	_check(not definition.is_empty() and meta.definition(id) == definition, "authentic distinct Sew catalog")
	_check(facts.known and facts.owner_text == "Button Golem" and facts.cost == 1
		and facts.from_text == "From " + meta._positions([1, 2, 3]) and facts.target_text == "Self"
		and meta.visual_state(panel).playable and panel.focus_mode == Control.FOCUS_ALL,
		"mounted owner, energy, legal positions, self and enabled keyboard")
	var multiplier: int = 2 if id == SEW_IDS[3] else 1
	var flat: int = 2 if id == SEW_IDS[1] else 0
	var line := "Gain %d Block per button popped%s; self only." % [multiplier, " + 2 Block" if flat else ""]
	_check(meta.short_line(id) == line and panel.tooltip_text.contains(line)
		and panel.tooltip_text.contains("1 energy") and panel.tooltip_text.contains("To self"), "exact authored multiplier and flat Block printed")
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_rng.seed
	rng.state = app.run_rng.state
	var oracle := CombatDeck.new([], rng)
	oracle.hand.assign(app.deck.hand)
	oracle.draw_pile.assign(app.deck.draw_pile)
	oracle.discard_pile.assign(app.deck.discard_pile)
	oracle.combat_state = CombatState.new()
	oracle.combat_state.player_turn_active = true
	oracle.combat_state.energy = app.deck.energy
	var party := CombatParty.new(app.party.get_heroes())
	party._heroes = app.party.get_heroes()
	var result := CombatButtonGolemSewCards.new().play_card(oracle, party, id, 0)
	_check(result.ok and result.block_gained == count * multiplier + flat, "independent paid resolver oracle")
	var enemies: Array = app.enemies.get_enemies()
	var rng_state: int = app.run_rng.state
	var callback: Callable = presenter._bindings[panel]
	if input == 0:
		await _mouse(panel)
	else:
		panel.grab_focus()
		await _keyboard(KEY_ENTER if input == 1 else KEY_SPACE)
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(oracle, party, rng)
		and app.enemies.get_enemies() == enemies and app.run_rng.state == rng_state,
		"exact mounted state equals resolver; enemies and RNG unchanged")
	_check(app.deck.hand.count(id) == 1 and app.deck.discard_pile.count(id) == 1
		and app.party.get_hero(seat).block == 10 + count * multiplier + flat
		and app.party.get_hero(seat).buttons_popped == count, "exactly one paid held copy, Golem Block, counter retained")
	_check(app.hero_panels[seat - 1].get_child(0).text.contains("Block: %d" % (10 + count * multiplier + flat))
		and presenter.energy_label.text == str(app.deck.energy)
		and app.hand_view.get_child_count() == app.deck.hand.size(), "Block energy and hand HUD refresh")
	_check(presenter._pending.is_empty() and presenter._targets.is_empty() and not presenter.cancel_button.visible,
		"no target picker")
	var after := _pool_state()
	callback.call(_press())
	await _frames()
	_check(_pool_state() == after, "retired callback cannot spend duplicate held copy")
	_last_result = after.duplicate(true)
	await _dispose()


func _sew_refuse(mode: String, queued: bool) -> void:
	var panel := await _begin(SEW_IDS[1])
	if panel == null:
		await _dispose()
		return
	_check(presenter._metadata.visual_state(panel).playable, "valid before rejection fixture")
	var callback: Callable = presenter._bindings[panel]
	if queued:
		panel.grab_focus()
		callback.call(_key(KEY_ENTER))
		_check(not presenter._pending.is_empty(), "real deferred input armed")
	var token: int = presenter._token
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"counter": app.party._heroes[1].buttons_popped = -1
		"counter_type": app.party._heroes[1].buttons_popped = 1.5
		"overflow": app.party._heroes[1].block = CombatParty.MAX_INT
		"torn": app.party.apply_damage(2, 999)
		"owner": app.party._heroes[1].id = "seamstress"
		"duplicate_owner": app.party._heroes[0].id = "button_golem"
		"inactive": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"turn": app.enemy_intents.advance_turn()
		"hand":
			app.deck.discard_played(SEW_IDS[1])
			app.deck.discard_played(SEW_IDS[1])
		"panel": app._refresh_hand()
		"label": panel.get_child(0).text = SEW_IDS[0]
		"battle":
			app.battle_view = app.battle_view.duplicate(0)
			app.add_child(app.battle_view)
		"seat":
			var hero: Dictionary = app.party._heroes[1]
			app.party._heroes[1] = app.party._heroes[0]
			app.party._heroes[0] = hero
			app.party._heroes[0].position = 1
			app.party._heroes[1].position = 2
			_check(app.party.is_valid(), "otherwise legal moved owner")
		"cancel": presenter._cancel_pending()
	app._refresh_intents()
	if not queued and mode not in ["panel", "battle"]:
		presenter._metadata._update_visual(panel)
		_check(not presenter._metadata.visual_state(panel).playable, "invalid card dims: " + mode)
	var before := _pool_state()
	if mode == "cancel":
		presenter._activate(panel, SEW_IDS[1], app.deck, app.party, app.battle_view, token)
	else:
		callback.call(_key(KEY_ENTER))
	await _frames()
	_check(_pool_state() == before and presenter._pending.is_empty(), "no-spend rejected " + mode)
	if mode == "cancel":
		presenter._activate(panel, SEW_IDS[1], app.deck, app.party, app.battle_view, token)
	else:
		callback.call(_press())
	await _frames()
	_check(_pool_state() == before, "rejected replay inert " + mode)
	await _dispose()


func _pop_then_sew() -> void:
	var panel := await _begin(IDS[0])
	_check(panel != null, "real Pop panel")
	app.deck.hand[app.deck.hand.find(IDS[0])] = SEW_IDS[3]
	app._refresh_hand()
	await _frames()
	panel = _pool_panel(IDS[0])
	await _arm_pop(panel, false)
	await _keyboard(KEY_1)
	_check(app.party.get_hero(2).buttons_popped == 8 and app.party.get_hero(2).block == 5, "live Pop writes counter")
	var state: int = app.run_rng.state
	var energy: int = app.deck.energy
	await _mouse(_pool_panel(SEW_IDS[3]))
	_check(app.party.get_hero(2).block == 21 and app.party.get_hero(2).buttons_popped == 8
		and app.deck.energy == energy - 1 and app.run_rng.state == state, "live Sew reads Pop counter for 16 own Block")
	await _dispose()


func _unknown() -> void:
	await _begin(SEW_IDS[0])
	var id := "button_golem_sew_on_plus_plus"
	app.deck.hand[0] = id
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(id)
	_check(panel != null and not presenter._bindings.has(panel), "unknown alias has no action binding")
	if panel != null:
		_check(not presenter._metadata.get_facts(panel).known
			and not presenter._metadata.visual_state(panel).playable, "unknown alias stays unknown and dim")
		var before := _pool_state()
		await _mouse(panel)
		_check(panel.focus_mode == Control.FOCUS_NONE, "unknown alias cannot enter keyboard focus")
		await _keyboard(KEY_ENTER)
		await _keyboard(KEY_SPACE)
		_check(_pool_state() == before, "unknown alias mouse and keys cannot spend")
	await _dispose()


## Button Golem's two authentic Eyelet Guard printings, exercised through the same
## mounted support hand, the fight's single paid resolver and the real End Turn.
const EYELET_IDS := ["button_golem_eyelet_guard", "button_golem_eyelet_guard_plus"]


## The authored printed Block and Thorns of one printing, read from the pool
## catalog the paid resolver authenticates (never from this test's own constants).
func _eyelet_printed(card_id: String) -> Array:
	var definition: Dictionary = ButtonGolemPoolCards.new().get_definition(card_id)
	var effects: Dictionary = definition.get("effects", {})
	_check(definition.get("id") == card_id and definition.get("target_kind") == "self"
		and effects.size() == 3,
		"authentic self-only pool record precedes " + card_id)
	return [int(effects.get("block", 0)), int(effects.get("thorns", 0))]


## A real admitted fight (real round flow, real opening hand, real intents) whose
## shared hand genuinely holds both Eyelet Guard printings. Enemy 1 announces the
## passed attack at `target`; enemy 2 blocks.
func _begin_eyelet(seat: int, target: int, amount: int = 4, hits: int = 1) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 290
	_check(app._start_battle(), "mounted battle starts")
	presenter = app.get_node("LiveSupportHand")
	var rng := RandomNumberGenerator.new()
	rng.seed = 290
	var cards: Array[String] = [EYELET_IDS[0], EYELET_IDS[1], "warden_strike",
		"warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 26}]
	heroes.insert(seat - 1, {"id": "button_golem", "name": "Button Golem", "max_hp": 30})
	app.party = CombatParty.new(heroes)
	app.enemies = CombatEnemies.new([
		{"id": "raider", "max_hp": 40}, {"id": "bystander", "max_hp": 40}])
	var beat := {"type": "attack", "amount": amount, "target_position": target}
	if hits == 2:
		beat["hits"] = 2
	app.enemy_intents = CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [beat]},
		{"enemy_position": 2, "pattern": [{"type": "block", "amount": 2}]}])
	_check(app.party.is_valid() and app.enemies.is_valid() and app.enemy_intents.is_valid()
		and app.party.get_hero(seat).id == "button_golem"
		and target >= 1 and target <= 3,
		"real three-hero party, living Golem seat and legal announced target")
	app.enemy_attacks = app.enemy_intents.get_intents()
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	_check(app.round_flow.begin_fight() and app.deck.turn_active and app.deck.energy == 3
		and app.deck.hand.count(EYELET_IDS[0]) == 1
		and app.deck.hand.count(EYELET_IDS[1]) == 1,
		"the admitted fight really opened one hand with both Eyelet printings")
	app._refresh_intents()
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(EYELET_IDS[0])
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel),
		"authentic Eyelet Guard is a real clickable/focusable hand panel")
	return panel


## One real mouse or keyboard play of one printing, then two real End Turns.
func _eyelet_success(card_id: String, seat: int, input: int) -> void:
	var mounted := await _begin_eyelet(seat, seat)
	if mounted == null:
		await _dispose()
		return
	var printed := _eyelet_printed(card_id)
	var block: int = printed[0]
	var thorns: int = printed[1]
	var definition: Dictionary = ButtonGolemPoolCards.new().get_definition(card_id)
	var panel := _pool_panel(card_id)
	_check(panel != null, "the requested printing is held and mounted: " + card_id)
	if panel == null:
		await _dispose()
		return
	var meta = presenter._metadata
	var facts: Dictionary = meta.get_facts(panel)
	_check(not definition.is_empty() and meta.definition(card_id) == definition,
		"authentic distinct Eyelet Guard catalog: " + card_id)
	_check(facts.known and facts.owner_text == "Button Golem" and facts.cost == 1
		and facts.from_text == "From " + meta._positions([1, 2, 3])
		and facts.target_text == "Self"
		and meta.visual_state(panel).playable and panel.focus_mode == Control.FOCUS_ALL,
		"mounted owner, energy, legal seats, self target and enabled keyboard: " + card_id)
	var line := "Gain %d Block. Gain %d Thorns until your next turn." % [block, thorns]
	_check(meta.short_line(card_id) == line and facts.get("rules") == line
		and panel.tooltip_text.contains("1 energy")
		and panel.tooltip_text.contains("To self")
		and panel.tooltip_text.contains("Gain %d Block and %d Thorns" % [block, thorns])
		and panel.tooltip_text.contains("Re-arming refreshes"),
		"exact authored Block and one-turn Thorns printed on face and tooltip: " + card_id)
	var authority = app.round_flow.get_eyelet_guard_authority()
	_check(authority != null and not authority.is_armed(),
		"the fight starts with one unarmed Eyelet authority: " + card_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_rng.seed
	rng.state = app.run_rng.state
	var oracle := CombatDeck.new([], rng)
	oracle.hand.assign(app.deck.hand)
	oracle.draw_pile.assign(app.deck.draw_pile)
	oracle.discard_pile.assign(app.deck.discard_pile)
	oracle.combat_state = CombatState.new()
	oracle.combat_state.player_turn_active = true
	oracle.combat_state.energy = app.deck.energy
	var party := CombatParty.new(app.party.get_heroes())
	party._heroes = app.party.get_heroes()
	var result: Dictionary = CombatButtonGolemEyeletGuardCards.new().play_card(
		oracle, party, card_id, 0)
	_check(result.get("ok", false) and result.get("block_gained") == block
		and result.get("thorns_gained") == thorns,
		"independent paid resolver oracle really commits: " + card_id)
	var enemies: Array = app.enemies.get_enemies()
	var rng_state: int = app.run_rng.state
	var callback: Callable = presenter._bindings[panel]
	if input == 0:
		await _mouse(panel)
	else:
		panel.grab_focus()
		await _keyboard(KEY_ENTER if input == 1 else KEY_SPACE)
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(oracle, party, rng)
		and app.enemies.get_enemies() == enemies and app.run_rng.state == rng_state,
		"exact mounted state equals the resolver; enemies and RNG unchanged: " + card_id)
	_check(app.deck.energy == 2 and app.deck.hand.count(card_id) == 0
		and app.deck.discard_pile.count(card_id) == 1,
		"exactly one authentic held copy paid and discarded: " + card_id)
	_check(app.party.get_hero(seat).block == block
		and app.round_flow.get_eyelet_guard_authority() == authority
		and authority.is_armed() and authority.get_armed_thorns() == thorns
		and not app.party.get_hero(seat).get("statuses", {}).has("thorns"),
		"printed Block on the real seat and one-turn Thorns armed on the fight's own instance")
	_check(app.hero_panels[seat - 1].get_child(0).text.contains("Block: %d" % block)
		and presenter.energy_label.text == str(app.deck.energy)
		and app.hand_view.get_child_count() == app.deck.hand.size(),
		"visible Block, energy and hand HUD all refreshed: " + card_id)
	_check(presenter._pending.is_empty() and presenter._targets.is_empty()
		and not presenter.cancel_button.visible,
		"a self-only cast never opens a target picker: " + card_id)
	await _frames()
	var remaining := _pool_panel(EYELET_IDS[1] if card_id == EYELET_IDS[0] else EYELET_IDS[0])
	_check(remaining != null and remaining.tooltip_text.contains("1 energy")
		and presenter._metadata.visual_state(remaining).playable,
		"the refreshed hand keeps the other printing's authentic face and tooltip")
	var after := _pool_state()
	callback.call(_press())
	await _frames()
	_check(_pool_state() == after, "retired callback cannot spend a duplicate copy")
	# A real End Turn quotes that same armed Thorns against the announced attacker.
	await _mouse(app.end_turn_button)
	_check(app.party.get_hero(seat).hp == 30,
		"the announced four stays inside the Golem's own printed Block: " + card_id)
	_check(app.enemies.get_enemy(1).hp == 40 - thorns,
		"the real enemy turn retaliates %d against the original attacker" % thorns)
	_check(app.enemies.get_enemy(2).block == 2, "the non-attacking sibling still blocks")
	_check(not authority.is_armed() and authority.get_armed_thorns() == 0,
		"the first accepted next player turn expires the one-turn mode")
	await _mouse(app.end_turn_button)
	_check(app.party.get_hero(seat).hp == 26 and app.party.get_hero(seat).block == 0
		and app.enemies.get_enemy(1).hp == 40 - thorns,
		"the following turn takes four HP and retaliates nothing after expiry")
	_last_result = _pool_state().duplicate(true)
	await _dispose()


## A real recast in one turn refreshes (never stacks) the armed value, and the
## next enemy turn retaliates exactly the refreshed number.
func _eyelet_refresh(seat: int) -> void:
	var panel := await _begin_eyelet(seat, seat)
	if panel == null:
		await _dispose()
		return
	var base := _eyelet_printed(EYELET_IDS[0])
	var plus := _eyelet_printed(EYELET_IDS[1])
	var authority = app.round_flow.get_eyelet_guard_authority()
	await _mouse(panel)
	_check(authority.is_armed() and authority.get_armed_thorns() == base[1],
		"the first printing arms its own printed Thorns")
	await _frames()
	var second := _pool_panel(EYELET_IDS[1])
	_check(second != null and presenter._metadata.visual_state(second).playable,
		"the upgrade is still affordable and playable in the same turn")
	second.grab_focus()
	await _keyboard(KEY_ENTER)
	_check(app.deck.energy == 1 and app.party.get_hero(seat).block == base[0] + plus[0]
		and authority.get_armed_thorns() == plus[1],
		"a recast refreshes to the upgraded Thorns instead of summing stacks")
	await _mouse(app.end_turn_button)
	_check(app.enemies.get_enemy(1).hp == 40 - plus[1],
		"the enemy turn retaliates the refreshed value exactly once")
	await _dispose()


## AC3: every refusal leaves energy, deck, HP, Block, mode and RNG exactly as it was.
func _eyelet_refuse(mode: String) -> void:
	var panel := await _begin_eyelet(2, 2)
	if panel == null:
		await _dispose()
		return
	_check(presenter._metadata.visual_state(panel).playable, "valid before rejection: " + mode)
	var authority = app.round_flow.get_eyelet_guard_authority()
	var callback: Callable = presenter._bindings[panel]
	if mode == "duplicate":
		await _mouse(panel)
		_check(authority.is_armed(), "a genuine first play arms the mode: " + mode)
		var armed := _pool_state()
		callback.call(_press())
		await _frames()
		_check(_pool_state() == armed and authority.get_armed_thorns() == 2,
			"a replayed receipt cannot spend or re-arm: " + mode)
		await _dispose()
		return
	match mode:
		"energy": app.deck.combat_state.energy = 0
		"unheld":
			app.deck.discard_played(EYELET_IDS[0])
			app.deck.discard_played(EYELET_IDS[0])
		"torn": app.party.apply_damage(2, 999)
		"missing": app.party._heroes[1].id = "seamstress"
		"duplicate_owner": app.party._heroes[0].id = "button_golem"
		"inactive": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"turn": app.enemy_intents.advance_turn()
		"foreign_flow":
			app.round_flow = CombatRoundFlow.new(app.deck, CombatParty.new(app.party.get_heroes()),
				app.enemies, app.enemy_intents, app.battle_result)
		"panel": app._refresh_hand()
		"label": panel.get_child(0).text = EYELET_IDS[1]
		"battle":
			app.battle_view = app.battle_view.duplicate(0)
			app.add_child(app.battle_view)
	app._refresh_intents()
	if not ["panel", "battle"].has(mode):
		presenter._metadata._update_visual(panel)
	var before := _pool_state()
	callback.call(_key(KEY_ENTER))
	await _frames()
	_check(_pool_state() == before and presenter._pending.is_empty(),
		"no-spend refusal: " + mode)
	callback.call(_press())
	await _frames()
	_check(_pool_state() == before, "rejected replay inert: " + mode)
	await _dispose()


## AC3: a rejected real enemy phase leaves everything intact and keeps the mode
## armed for the accepted retry, then the accepted turn retaliates once.
func _eyelet_rejected_turn() -> void:
	var panel := await _begin_eyelet(1, 1)
	if panel == null:
		await _dispose()
		return
	var authority = app.round_flow.get_eyelet_guard_authority()
	await _mouse(panel)
	_check(authority.is_armed() and authority.get_armed_thorns() == 2,
		"a paid cast arms the mode before the negative turn")
	app.enemy_intents._definitions[0].pattern[0].amount = -1
	app.enemy_attacks = app.enemy_intents.get_intents()
	# The presentation ribbon legitimately repaints "Intent: none" for an invalid
	# announcement, so the combat resources are compared without that caption.
	var refused := _pool_state()
	refused.remove_at(9)
	await _mouse(app.end_turn_button)
	var now := _pool_state()
	now.remove_at(9)
	_check(now == refused and authority.is_armed()
		and authority.get_armed_thorns() == 2,
		"a rejected enemy phase changes nothing and never expires the mode")
	app.enemy_intents._definitions[0].pattern[0].amount = 4
	app.enemy_attacks = app.enemy_intents.get_intents()
	_check(app.enemy_attacks == app.enemy_intents.get_intents(), "restored announcement is genuine")
	await _mouse(app.end_turn_button)
	_check(app.enemies.get_enemy(1).hp == 38 and app.party.get_hero(1).hp == 30
		and not authority.is_armed(),
		"the accepted retry retaliates its two Thorns and then expires")
	await _dispose()


## A real two-hit End Turn retaliates once per confirmed hit, and a hit on another
## hero never retaliates the Golem's armed Thorns.
func _eyelet_multi_hit() -> void:
	var panel := await _begin_eyelet(2, 2, 6, 2)
	if panel == null:
		await _dispose()
		return
	var printed := _eyelet_printed(EYELET_IDS[0])
	await _mouse(panel)
	await _mouse(app.end_turn_button)
	_check(app.party.get_hero(2).hp == 30,
		"both three-point hits are absorbed by the Golem's printed Block")
	_check(app.enemies.get_enemy(1).hp == 40 - printed[1] * 2,
		"each confirmed hit of the announced two-hit attack retaliates separately")
	await _dispose()


func _eyelet_other_hero() -> void:
	var panel := await _begin_eyelet(2, 1, 4, 1)
	if panel == null:
		await _dispose()
		return
	await _mouse(panel)
	_check(app.round_flow.get_eyelet_guard_authority().is_armed(), "the Golem is really armed")
	await _mouse(app.end_turn_button)
	_check(app.party.get_hero(1).hp == 40 and app.party.get_hero(2).hp == 30
		and app.party.get_hero(2).block == 0,
		"the announced four is absorbed by the Warden, not the Golem")
	_check(app.enemies.get_enemy(1).hp == 40,
		"a hit on another hero never retaliates the Golem's Thorns")
	await _dispose()


## Both printings, every legal seat and both input paths, plus multi-hit and
## other-hero contacts, refresh, refusals, a rejected phase, the new-fight reset
## and one complete seeded replay.
func _eyelet_cases() -> void:
	# Pin the authored numbers this task makes playable without hard-coding any
	# catalog total: exactly these two printings must still print these values.
	_check(_eyelet_printed(EYELET_IDS[0]) == [6, 2]
		and _eyelet_printed(EYELET_IDS[1]) == [9, 3],
		"the two authored Eyelet printings carry 6/9 Block and 2/3 Thorns")
	for card_id in EYELET_IDS:
		for seat in [1, 2, 3]:
			for input in [0, 1, 2]:
				await _eyelet_success(card_id, seat, input)
	await _eyelet_multi_hit()
	await _eyelet_other_hero()
	for seat in [1, 2, 3]:
		await _eyelet_refresh(seat)
	for mode in ["energy", "unheld", "torn", "missing", "duplicate_owner", "inactive",
			"closed", "session", "turn", "foreign_flow", "panel", "label", "battle", "duplicate"]:
		await _eyelet_refuse(mode)
	await _eyelet_rejected_turn()
	var replay := _last_result.duplicate(true)
	await _eyelet_success(EYELET_IDS[1], 3, 2)
	_check(_last_result == replay, "complete seeded Eyelet Guard replay")
	await _eyelet_new_fight()


## A brand new admitted fight owns an independent, unarmed Eyelet authority.
func _eyelet_new_fight() -> void:
	var panel := await _begin_eyelet(2, 2)
	if panel == null:
		await _dispose()
		return
	var first = app.round_flow.get_eyelet_guard_authority()
	await _mouse(panel)
	_check(first.is_armed() and first.get_armed_thorns() == 2,
		"the first fight really owns an armed Eyelet mode")
	app._return_to_title()
	await _frames()
	_check(app.round_flow == null, "Return retires the old fight flow")
	_check(app._start_battle() and app.round_flow != null
		and app.round_flow.get_eyelet_guard_authority() != first
		and not app.round_flow.get_eyelet_guard_authority().is_armed(),
		"a subsequent real battle starts with a fresh unarmed Eyelet authority")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in SEW_IDS:
		for seat in [1, 2, 3]:
			for input in [0, 1, 2]:
				for count in [0, 7]:
					await _sew_success(id, seat, input, count)
	await _pop_then_sew()
	await _unknown()
	for mode in ["energy", "counter", "counter_type", "overflow", "torn", "owner", "duplicate_owner", "inactive", "closed", "session", "turn", "hand", "panel", "label", "battle"]:
		for queued in [false, true]:
			await _sew_refuse(mode, queued)
	for mode in ["seat", "cancel"]:
		await _sew_refuse(mode, true)
	await _sew_success(SEW_IDS[3], 3, 2, 7)
	var replay := _last_result.duplicate(true)
	await _sew_success(SEW_IDS[3], 3, 2, 7)
	_check(_last_result == replay, "complete seeded replay")
	await _eyelet_cases()
	for failure in failures:
		printerr(failure)
	print("live_button_golem_sew_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
