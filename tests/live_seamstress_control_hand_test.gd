extends SceneTree
## Mounted shared-hand coverage for the six authored Seamstress enemy-control
## variants (Needle Pin, Snag and Unpick, base and '+').
##
## Every cast starts from the real seeded app scene, draws the authored pool
## card through the real CombatDeck, targets the real held panel by mouse or
## keyboard, resolves through CombatSeamstressPoolControl and is compared with
## an independent copy of that service fed the same pre-cast snapshot. One case
## fills the battle's own normal-tier Unravel gauge and ends the real turn, so
## the announced enemy action must actually be skipped and the gauge consumed.
## Rejected, stale and replayed inputs must leave every snapshot untouched.

const PIN := "seamstress_needle_pin"
const PIN_PLUS := "seamstress_needle_pin_plus"
const SNAG := "seamstress_snag"
const SNAG_PLUS := "seamstress_snag_plus"
const UNPICK := "seamstress_unpick"
const UNPICK_PLUS := "seamstress_unpick_plus"
const CONTROL_IDS := [PIN, PIN_PLUS, SNAG, SNAG_PLUS, UNPICK, UNPICK_PLUS]
const SNAG_IDS := [SNAG, SNAG_PLUS]
const NEEDLE_IDS := [PIN, PIN_PLUS]
const UNPICK_IDS := [UNPICK, UNPICK_PLUS]
const SEED := 42
const TIER_CATALOGS := [
	["res://data/enemies/starter_enemies.json", "normal"],
	["res://data/enemies/run_enemies.json", "normal"],
	["res://data/enemies/m04_elites.json", "elite"],
	["res://data/enemies/boss.json", "boss"],
]

var failures: Array[String] = []
var checks := 0
var app
var presenter
var support
var catalog := SeamstressPoolCards.new()
var resolver := CombatSeamstressPoolControl.new()
var _oracle_pinned: CombatPinned
var _oracle_unravel: CombatUnravel
var _oracle_enemies: CombatEnemies


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	for frame in range(3):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


## Physical pointer activation; the duplicate press must still resolve once.
func _mouse(control: Control) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree(),
		"mouse recipient really exists and is visible")
	if not is_instance_valid(control):
		return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		if pressed:
			root.push_input(event, true)
	await _frames()


func _panel(card_id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and panel.get_child(0).text == card_id:
			return panel
	return null


## Cards and combat state that must survive any refusal, replay or return.
func _state() -> Dictionary:
	var gauges: Dictionary = {}
	var tiers: Dictionary = {}
	var pins: Dictionary = {}
	if presenter != null and presenter._pinned != null:
		pins = presenter._pinned._pinner_by_position.duplicate(true)
	if presenter != null and presenter._unravel != null:
		gauges = presenter._unravel._gauges.duplicate(true)
		tiers = presenter._unravel._tiers_by_position.duplicate(true)
	return {
		"draw": app.deck.draw_pile.duplicate(),
		"hand": app.deck.hand.duplicate(),
		"discard": app.deck.discard_pile.duplicate(),
		"energy": app.deck.energy,
		"turn": app.deck.turn_active,
		"heroes": app.party.get_heroes().duplicate(true),
		"enemies": app.enemies.get_enemies().duplicate(true),
		"intents": app.enemy_intents.get_intents().duplicate(true),
		"attacks": app.enemy_attacks.duplicate(true),
		"run_seed": app.run_rng.seed,
		"run_state": app.run_rng.state,
		"deck_state": app.deck._rng.state,
		"outcome": app.battle_result.get_outcome(),
		"closed": app._battle_closed,
		"pins": pins,
		"gauges": gauges,
		"tiers": tiers,
	}


## Independent tier classification from the four shipped catalogs, never from
## the presenter or the gauge under test.
func _test_tier_map(enemies: CombatEnemies) -> Dictionary:
	var table: Dictionary = {}
	for entry in TIER_CATALOGS:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(str(entry[0])))
		if not parsed is Array:
			return {}
		for record in parsed:
			var id := str(record.get("id", ""))
			if id.is_empty():
				return {}
			if table.has(id) and table[id] != entry[1]:
				table[id] = ""
			elif not table.has(id):
				table[id] = entry[1]
	var tiers: Dictionary = {}
	var roster: Array = enemies.get_enemies()
	if roster.is_empty():
		return tiers
	for index in range(roster.size()):
		var id := str(roster[index].get("id", ""))
		if not table.has(id) or str(table[id]).is_empty():
			return {}
		tiers[index + 1] = table[id]
	return tiers


func _setup_oracle() -> void:
	var definitions: Array[Dictionary] = []
	for enemy in app.enemies.get_enemies():
		definitions.append({"id": String(enemy["id"]), "max_hp": int(enemy["max_hp"])})
	_oracle_enemies = CombatEnemies.new(definitions)
	_oracle_enemies._enemies.assign(app.enemies.get_enemies().duplicate(true))
	_oracle_pinned = CombatPinned.new()
	_oracle_unravel = CombatUnravel.new()
	_check(_oracle_unravel.bind_roster(_oracle_enemies, _test_tier_map(_oracle_enemies)),
		"independent service oracle binds its gauge from the same authored tiers")


## Replay the exact pre-cast snapshot through a detached service and roster.
func _oracle_cast(before: Dictionary, card_id: String, position: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(before["run_seed"])
	rng.state = int(before["deck_state"])
	var deck := CombatDeck.new([], rng)
	deck.draw_pile.assign(before["draw"])
	deck.hand.assign(before["hand"])
	deck.discard_pile.assign(before["discard"])
	deck.combat_state.player_turn_active = bool(before["turn"])
	deck.combat_state.energy = int(before["energy"])
	var party := CombatParty.new(app._load_party_definitions())
	party._heroes.assign((before["heroes"] as Array).duplicate(true))
	_oracle_enemies._enemies.assign((before["enemies"] as Array).duplicate(true))
	var event: Dictionary = resolver.play_card(deck, party, _oracle_enemies,
		_oracle_pinned, _oracle_unravel, card_id, position)
	return {"event": event, "draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"rng": deck._rng.state, "party": party.get_heroes(),
		"enemies": _oracle_enemies.get_enemies(),
		"pins": _oracle_pinned._pinner_by_position.duplicate(true),
		"gauges": _oracle_unravel._gauges.duplicate(true)}


func _assert_cast(card_id: String, before: Dictionary, position: int, stage: String) -> void:
	var oracle := _oracle_cast(before, card_id, position)
	_check(oracle.event.get("ok", false),
		"independent service accepts the same pre-state: " + stage)
	_check(presenter.last_event == oracle.event,
		"mounted receipt equals the independent service event: " + stage)
	_check(app.deck.draw_pile == oracle.draw and app.deck.hand == oracle.hand
		and app.deck.discard_pile == oracle.discard and app.deck.energy == oracle.energy,
		"piles and energy equal the independent service: " + stage)
	_check(app.deck._rng.state == oracle.rng
		and app.deck._rng.state == int(before["deck_state"]),
		"a committed cast consumes no deck or run RNG draw: " + stage)
	_check(app.party.get_heroes() == oracle.party,
		"party HP, Block and statuses equal the independent service: " + stage)
	_check(app.enemies.get_enemies() == oracle.enemies,
		"enemy HP, Block and statuses equal the independent service: " + stage)
	_check(presenter._pinned._pinner_by_position == oracle.pins,
		"Pinned tokens equal the independent service: " + stage)
	_check(presenter._unravel._gauges == oracle.gauges,
		"Unravel gauges equal the independent service: " + stage)
	_check(app.deck.discard_pile.count(card_id) == int(before["discard"].count(card_id)) + 1
		and app.deck.hand.count(card_id) == int(before["hand"].count(card_id)) - 1,
		"exactly one held copy is spent and discarded: " + stage)
	_check(app.hand_view.get_child_count() == app.deck.hand.size(),
		"the mounted hand matches the post-cast hand: " + stage)


## Start a fresh seeded battle and draw the requested authored pool cards
## through the real deck instead of fabricating hand panels.
func _new_battle(cards: Array[String] = []) -> bool:
	if app.deck != null:
		await _return()
	_check(app.deck == null, "the title precedes every mounted battle")
	app.run_seed = SEED
	var started: bool = app._start_battle()
	await _frames()
	var ready: bool = started and app.deck is CombatDeck and app.party is CombatParty \
		and app.enemies is CombatEnemies and app.enemy_intents != null \
		and app.battle_result != null and is_instance_valid(app.battle_view) \
		and is_instance_valid(app.hand_view) and app.deck.turn_active and app.deck.energy == 3
	_check(ready, "seeded scene battle starts with a live hand and three energy")
	if not ready:
		return false
	_check(presenter._pinned is CombatPinned and presenter._unravel is CombatUnravel,
		"the presenter owns one Pinned set and one Unravel gauge")
	var tiers: Dictionary = presenter.enemy_tier_map(app.enemies)
	_check(tiers.size() == app.enemies.get_enemies().size(),
		"every original enemy ID classifies against the four authored catalogs")
	for position in tiers:
		_check(tiers[position] == "normal", "starter enemy is a normal-tier original slot")
	_check(presenter._unravel._bound_enemies == app.enemies,
		"the gauge binds the exact battle roster")
	var snapshot: Dictionary = presenter._unravel.get_snapshot(1)
	_check(int(snapshot.get("threshold", 0)) == CombatUnravel.THRESHOLD_NORMAL
		and int(snapshot.get("gauge", -1)) == 0,
		"a normal gauge starts empty at its authored threshold of eight")
	if not cards.is_empty():
		for id in cards:
			app.deck.draw_pile.append(id)
		_check(app.deck.draw_extra(cards.size()) == cards.size(),
			"the real seeded deck draws the authored control cards")
		app._refresh_hand()
		await _frames()
	for id in cards:
		_check(_panel(id) != null, "real held panel mounted: " + id)
	_setup_oracle()
	return true


func _return() -> void:
	if is_instance_valid(app.return_button):
		app.return_button.pressed.emit()
	await _frames()


## Physical mouse click or P selection of the real held instance.
func _select(card_id: String, keyboard: bool) -> bool:
	var panel := _panel(card_id)
	_check(panel != null, "real panel is held before selection: " + card_id)
	if panel == null:
		return false
	if keyboard:
		for step in range(app.deck.hand.size() + 2):
			await _key(KEY_P)
			if presenter._armed == panel:
				break
	else:
		await _mouse(panel)
	_check(presenter._armed == panel and presenter._bindings.has(panel),
		"the real panel is armed for targeting: " + card_id)
	_check(not support._bindings.has(panel),
		"the support presenter never claims a control panel: " + card_id)
	var facts: Dictionary = support._metadata.get_facts(panel)
	var definition: Dictionary = catalog.get_definition(card_id)
	_check(facts.get("known") == true and facts.get("owner") == "seamstress"
		and facts.get("cost") == definition.get("cost")
		and panel.get_child(0).text == card_id,
		"the same real panel keeps its authored face and hidden identity: " + card_id)
	return presenter._armed == panel


func _target(position: int, keyboard: bool) -> void:
	if keyboard:
		await _key(KEY_1 if position == 1 else KEY_2 if position == 2 else KEY_3)
	else:
		await _mouse(app.get_node("LiveEnemyRoster")._labels[position - 1])


func _assert_cue(card_id: String, slots: Array) -> void:
	var definition: Dictionary = catalog.get_definition(card_id)
	var text: String = presenter.cue.text
	_check(text.contains(String(definition.get("display_name", "")))
		and text.contains("%d energy" % int(definition.get("cost", -1))),
		"live cue states the authored name and cost: " + card_id)
	_check(text.contains("Choose one enemy slot"),
		"live cue names the genuine target choice: " + card_id)
	for position in slots:
		_check(text.contains("%d: " % int(position)),
			"live cue lists legal slot %d: %s" % [int(position), card_id])
	for position in [1, 2, 3]:
		if position in slots:
			continue
		_check(not text.contains("%d: " % position),
			"live cue never offers illegal slot %d: %s" % [position, card_id])


## The cue's per-slot numbers must also match the authored record and the
## oracle's pre-cast rules state, not just the slot list.
func _assert_control_cue(card_id: String, slots: Array) -> void:
	_assert_cue(card_id, slots)
	var effects: Dictionary = catalog.get_definition(card_id).get("effects", {})
	for position in slots:
		if card_id in NEEDLE_IDS:
			var bonus: int = _oracle_pinned.bonus_for_attack(_oracle_enemies, int(position), "seamstress")
			var damage: int = int(effects.get("damage", -1)) + bonus
			_check(presenter.cue.text.contains("%d: %d damage" % [int(position), damage]),
				"live cue shows the serviced damage for slot %d: %s" % [int(position), card_id])
			if bonus > 0:
				_check(presenter.cue.text.contains("(+%d Pinned)" % bonus),
					"live cue states the cross-hero pin bonus: " + card_id)
		else:
			var gauge: Dictionary = _oracle_unravel.get_snapshot(int(position))
			var amount: int = int(effects.get("unravel", 0))
			var threshold: int = int(gauge.get("threshold", 0))
			var after: int = mini(int(gauge.get("gauge", 0)) + amount, threshold)
			_check(presenter.cue.text.contains(
				"Unravel %d → %d/%d" % [amount, after, threshold]),
				"live cue shows the serviced gauge charge for slot %d: %s" % [int(position), card_id])
			if card_id in SNAG_IDS:
				var projected: Dictionary = resolver.snag_weak_preview(card_id)
				_check(projected.get("ok", false)
					and presenter.cue.text.contains("Weak %d" % int(projected.get("weak", -1))),
					"live cue states the effective real HEAD Weak: " + card_id)


func _needle_cases() -> void:
	# Base Needle Pin through the mouse: real damage and a fresh Seamstress pin.
	if not await _new_battle([PIN]):
		return
	_check(await _select(PIN, false), "mouse selects the held base Needle Pin")
	var first_before := _state()
	_assert_control_cue(PIN, [1, 2])
	await _target(1, false)
	_assert_cast(PIN, first_before, 1, "base Needle Pin mouse")
	_check(int(presenter.last_event.get("damage", 0)) == 3
		and int(presenter.last_event.get("hp_loss", 0)) == 3
		and int(presenter.last_event.get("pinned_bonus", 0)) == 0,
		"base Needle Pin deals its authored three damage")
	_check(app.enemies.get_enemy(1)["hp"] == 9
		and presenter._pinned.pinner_for_enemy(1) == "seamstress",
		"the surviving target is repinned by the Seamstress")
	_check(app.enemies.get_enemy(2)["hp"] == 12 and app.enemies.get_enemy(3).is_empty(),
		"an unrelated living slot and the absent slot stay untouched")

	# '+' Needle Pin via the keyboard while a real cross-hero pin waits.
	if not await _new_battle([PIN_PLUS]):
		return
	_check(presenter._pinned.pin_enemy(app.enemies, 1, "warden")
		and _oracle_pinned.pin_enemy(_oracle_enemies, 1, "warden"),
		"an independent cross-hero pin is waiting on the target")
	_check(await _select(PIN_PLUS, true), "keyboard selects the held Needle Pin+")
	var plus_before := _state()
	_assert_control_cue(PIN_PLUS, [1, 2])
	await _target(1, true)
	_assert_cast(PIN_PLUS, plus_before, 1, "Needle Pin+ keyboard")
	_check(int(presenter.last_event.get("pinned_bonus", 0)) == 5
		and int(presenter.last_event.get("damage", 0)) == 9
		and int(presenter.last_event.get("hp_loss", 0)) == 9,
		"Needle Pin+ adds the authored four plus the confirmed +5 Pinned bonus")
	_check(app.enemies.get_enemy(1)["hp"] == 3
		and presenter._pinned.pinner_for_enemy(1) == "seamstress",
		"the cross-hero pin is consumed once and the Seamstress repins")
	for id in [PIN, PIN_PLUS]:
		_check(not CombatAttackTargeting.ATTACK_IDS.has(id),
			id + ": stays outside the starter-only attack enumeration")


func _snag_cases() -> void:
	if not await _new_battle([SNAG]):
		return
	_check(await _select(SNAG, false), "mouse selects the held Snag")
	var before := _state()
	_assert_control_cue(SNAG, [1, 2])
	await _target(1, false)
	_assert_cast(SNAG, before, 1, "Snag mouse")
	_check(int(presenter.last_event.get("damage", 0)) == 0
		and int(presenter.last_event.get("weak_applied", 0)) == 1
		and int(presenter.last_event.get("unravel_applied", 0)) == 3,
		"Snag applies authored Weak and three Unravel with zero damage")
	_check(app.enemies.get_enemy(1)["hp"] == 12
		and app.enemies.get_enemy(1)["statuses"].get("weak", 0) == 1,
		"Snag leaves HP intact and the Weak status live")
	var gauge: Dictionary = presenter._unravel.get_snapshot(1)
	_check(int(gauge.get("gauge", -1)) == 3 and int(gauge.get("threshold", 0)) == 8
		and not bool(gauge.get("skip_pending", true)),
		"Snag charges only the chosen normal gauge")

	if not await _new_battle([SNAG_PLUS]):
		return
	_check(await _select(SNAG_PLUS, true), "keyboard selects the held Snag+")
	before = _state()
	await _target(2, true)
	_assert_cast(SNAG_PLUS, before, 2, "Snag+ keyboard")
	_check(int(presenter._unravel.get_snapshot(2)["gauge"]) == 4
		and int(presenter._unravel.get_snapshot(1)["gauge"]) == 0,
		"Snag+ charges exactly the chosen original slot")


## Routed admission uses a completed opening Fight, real reward settlement,
## the existing run's genuine sewn wardrobe and an onward connected Fight.
## No fabricated deck, combat receipt or alternate presenter is involved.
func _head_route_case(card_id: String, keyboard: bool) -> void:
	if app.deck != null:
		await _return()
	_check(app.deck == null and app.run_map == null,
		"routed HEAD check starts at an actual clean title")
	var opening_seed := -1
	var first_fight := ""
	var second_fight := ""
	for number in range(1, 400):
		var rng := RandomNumberGenerator.new()
		rng.seed = number
		var generated := RunMap.new()
		generated.generate(rng)
		for node_id in generated.get_legal_choices():
			if generated.get_node(node_id).get("type", "") != "Fight":
				continue
			if not generated.choose_node(node_id):
				continue
			for next_id in generated.get_legal_choices():
				if generated.get_node(next_id).get("type", "") == "Fight":
					opening_seed = number
					first_fight = node_id
					second_fight = next_id
					break
			if opening_seed >= 0:
				break
		if opening_seed >= 0:
			break
	_check(opening_seed >= 0 and not second_fight.is_empty(),
		"seeded authored route connects an opening Fight to another Fight")
	if opening_seed < 0:
		return
	app.run_seed = opening_seed
	await _mouse(app.route_button)
	_check(app.run_map != null and app.party_carryover is RunTornCarryover
		and app.run_map.get_legal_choices().has(first_fight),
		"real title enters the generated opening route")
	if app.run_map == null:
		return
	_check(app._choose_route(first_fight),
		"real opening chooser admits first Fight with pristine starter inventory")
	await _frames()
	_check(app._current_carryover_fight() and app.enemies != null,
		"unpatched opening battle is genuinely admitted")
	if app.enemies == null:
		return
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 99999),
			"opening battle enemy is genuinely defeated")
	app._observe_battle_result()
	await _frames()
	_check(app._battle_closed and app.reward_buttons.size() >= 4,
		"real first Fight victory mounts the reward claim")
	if app.reward_buttons.size() < 4:
		return
	app.reward_buttons[3].pressed.emit()
	await _frames()
	_check(is_instance_valid(app.continue_button) and app.fight_reward_claimed,
		"actual routed reward service accepts the skip receipt")
	if not is_instance_valid(app.continue_button):
		return
	app.continue_button.pressed.emit()
	await _frames()
	_check(is_instance_valid(app.route_view)
		and app.run_map.get_legal_choices().has(second_fight),
		"first reward settles and connected second Fight is selectable: deck=%s route=%s legal=%s second=%s claimed=%s can_leave=%s pending=%s" % [
			app.deck != null, is_instance_valid(app.route_view), app.run_map.get_legal_choices(),
			second_fight, app.fight_reward_claimed, app._can_leave_fight(),
			app.act_outcome.get_state()])
	if not is_instance_valid(app.route_view):
		return

	# Prior-earned M05 ownership is a deterministic inventory fixture. Both
	# sewing and carryover binding use their actual optimistic ledger APIs.
	_check(app.run_trinkets.is_empty(), "settled opening run has no owned head patch yet")
	app.run_trinkets.append("stern_seam_cap")
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		[{"id": "stern_seam_cap", "slot": "HEAD"}],
		app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	_check(wardrobe.is_valid() and wardrobe.sew("stern_seam_cap", "seamstress", "HEAD",
		"earned_cap_sew", wardrobe.get_snapshot()).get("ok", false),
		"real prior-earned cap is sewn to the currently living Seamstress")
	var carry := app.party_carryover as RunTornCarryover
	_check(carry != null and carry.bind_wardrobe(wardrobe, carry.torn,
		wardrobe.get_snapshot()) and carry._wardrobe == wardrobe,
		"run carryover authentically owns this sewn M05 HEAD ledger")
	var route_action: Button = null
	for button in app.route_buttons:
		if button.get_meta("route_id") == second_fight:
			route_action = button
			break
	_check(is_instance_valid(route_action) and route_action.is_visible_in_tree(),
		"real connected chooser mounts the second Fight control")
	if not is_instance_valid(route_action):
		return
	# Emitting the actual chooser's signal follows the same connected route
	# admission as a click; cards below are exercised by physical input.
	route_action.pressed.emit()
	await _frames()
	_check(app._current_carryover_fight() and app.deck is CombatDeck
		and app.run_map.get_current_node_id() == second_fight
		and presenter._controls._head_rules != null
		and presenter._controls.head_binding_valid()
		and presenter._controls.snag_weak_preview(card_id) == {"ok": true, "weak": 2}
		and presenter._play._patches != null and presenter._play._patches.is_valid()
		and carry._wardrobe == wardrobe,
		"real onward routed battle binds one live HEAD projection to control and attack")
	if app.deck == null or not presenter._controls.head_binding_valid() \
			or presenter._controls.snag_weak_preview(card_id).get("weak", 0) != 2:
		return

	var head := CombatM05HeadPatchRules.new()
	_check(head.bind_wardrobe(wardrobe, carry.torn) and head.get_bonus(
		"seamstress", card_id, "weak") == 1,
		"independent HEAD oracle uses exact living owner and fresh run ledger")
	resolver.bind_head_patch_rules(head)
	# Draw through the genuine shared deck; do not replace its hand/turn state.
	app.deck.draw_pile.append(card_id)
	_check(app.deck.draw_extra(1) == 1, "authored Snag is drawn by real combat deck")
	app._refresh_hand()
	await _frames()
	var panel := _panel(card_id)
	_check(panel != null, "new held Snag panel is mounted on routed battle")
	if panel == null:
		return
	_setup_oracle()
	var pre_hover := _state()
	var hover := InputEventMouseMotion.new()
	hover.position = panel.get_global_rect().get_center()
	root.push_input(hover, true)
	await _frames()
	_check(_state() == pre_hover,
		"moving pointer over a real patched Snag is read-only")
	_check(await _select(card_id, keyboard), "physical routed patched Snag is aimed")
	var before := _state()
	var legal: Array = presenter._control_preview(card_id).get("target_positions", [])
	_check(not legal.is_empty() and legal.has(1),
		"routed Snag can aim at a real living enemy in original slot one")
	if legal.is_empty() or not legal.has(1):
		return
	_assert_control_cue(card_id, legal)
	var forecast_hits: Array = presenter.current_forecast.get("hits", [])
	_check(presenter.current_forecast.get("playable", false)
		and not forecast_hits.is_empty()
		and forecast_hits[0].get("weak_applied", 0) == 2,
		"HEAD Weak 2 appears in the actual forecast before commitment")
	for index in range(3):
		presenter._refresh()
		await _frames()
	_check(_state() == before and presenter.cue.text.contains("Weak 2"),
		"repeated forecast preserves energy, statuses, gauge and seeded RNG")
	var callback: Callable = presenter._bindings[panel].input
	await _target(1, keyboard)
	_assert_cast(card_id, before, 1, "routed HEAD " + card_id)
	var charge := 3 if card_id == SNAG else 4
	_check(presenter.last_event.get("weak_applied", -1) == 2
		and presenter.last_event.get("unravel_applied", -1) == charge
		and app.enemies.get_enemy(1).get("statuses", {}).get("weak", 0) == 2
		and presenter._unravel.get_snapshot(1).get("gauge", -1) == charge,
		"committed routed Snag adds exactly Weak 2 and authored Unravel")
	var committed := _state()
	callback.call(_mouse_event())
	await _key(KEY_1)
	_check(_state() == committed, "stale routed panel cannot double-charge HEAD")
	resolver.bind_head_patch_rules(null)
	await _return()
	_check(app.deck == null and presenter._controls._head_rules == null,
		"Return retires old bound HEAD with the battle")


func _unpick_cases() -> void:
	if not await _new_battle([UNPICK]):
		return
	_check(await _select(UNPICK, false), "mouse selects the held Unpick")
	var before := _state()
	_assert_control_cue(UNPICK, [1, 2])
	await _target(1, false)
	_assert_cast(UNPICK, before, 1, "Unpick mouse")
	_check(int(presenter.last_event.get("unravel_applied", 0)) == 5
		and int(presenter.last_event.get("weak_applied", 0)) == 0
		and int(presenter._unravel.get_snapshot(1)["gauge"]) == 5,
		"Unpick applies exactly its authored five gauge and no Weak")

	if not await _new_battle([UNPICK_PLUS]):
		return
	_check(await _select(UNPICK_PLUS, true), "keyboard selects the held Unpick+")
	before = _state()
	_assert_control_cue(UNPICK_PLUS, [1, 2])
	await _target(2, true)
	_assert_cast(UNPICK_PLUS, before, 2, "Unpick+ keyboard")
	_check(int(presenter._unravel.get_snapshot(2)["gauge"]) == 7
		and int(presenter._unravel.get_snapshot(2)["threshold"]) == 8,
		"Unpick+ charges seven toward the normal threshold")


## The authored Guard Ragling now chooses between five Block, a right shield
## rush and a real six-point hit; the gauge tests only need one genuine authored
## second-slot action, never a fixed passive Block.
func _authored_guard_action(announcements: Array) -> bool:
	for action in announcements:
		if not action is Dictionary or action.get("enemy_position") != 2:
			continue
		match String(action.get("type", "")):
			"block":
				return int(action.get("amount", 0)) == 5 and not action.has("target_position")
			"shove":
				return int(action.get("amount", -1)) == 0 \
					and int(action.get("direction", 0)) == 1 \
					and action.get("target_position") in [1, 2, 3]
			"attack":
				return int(action.get("amount", 0)) == 6 \
					and action.get("target_position") in [1, 2, 3]
		return false
	return false


## AC2: one real turn fills the battle's normal-tier gauge, then the announced
## enemy action is skipped and the shared gauge reset with a higher threshold.
func _shared_gauge_turn() -> void:
	# Baseline: the same announced Block action really happens without a skip.
	if not await _new_battle([]):
		return
	_check(int(app.enemies.get_enemy(2).get("block", 0)) == 0,
		"the second original enemy starts with no Block")
	var guard_announced: Dictionary = {}
	for action in app.enemy_intents.get_intents():
		if action.get("enemy_position") == 2:
			guard_announced = action
	await _mouse(app.end_turn_button)
	_check(app.enemy_intents._turn_index == 1
		and int(app.enemies.get_enemy(2).get("block", 0)) == (
			int(guard_announced.get("amount", 0)) if guard_announced.get("type") == "block" else 0),
		"without a pending skip the announced Guard action executes")
	await _return()

	# Fill the second original slot's gauge with the two authored control casts.
	if not await _new_battle([UNPICK, SNAG]):
		return
	_check(await _select(UNPICK, false), "mouse starts the gauge turn with Unpick")
	var before := _state()
	await _target(2, false)
	_assert_cast(UNPICK, before, 2, "gauge turn Unpick")
	_check(await _select(SNAG, true), "keyboard finishes the gauge turn with Snag")
	before = _state()
	await _target(2, true)
	_assert_cast(SNAG, before, 2, "gauge turn Snag")
	var filled: Dictionary = presenter._unravel.get_snapshot(2)
	_check(int(filled.get("gauge", 0)) == 8 and int(filled.get("threshold", 0)) == 8
		and bool(filled.get("unravelled", false)) and bool(filled.get("skip_pending", false)),
		"the normal gauge is exactly full with one pending skip")
	_check(app.round_flow._unravel == presenter._unravel,
		"the same gauge instance is bound to the live round flow before the cast")
	_check(app.deck.energy == 1 and app.deck.turn_active,
		"both authored cost-one casts spent exactly once")

	var pre := _state()
	_check(_authored_guard_action(app.enemy_intents.get_intents()),
		"the second original enemy has a genuine authored shield action")
	var hero_hp: Array = []
	for hero in pre["heroes"]:
		hero_hp.append(int(hero.get("hp", 0)))
	await _mouse(app.end_turn_button)
	_check(app.enemy_intents._turn_index == 1 and app.deck.turn_active and app.deck.energy == 3,
		"the real End Turn opens the next player turn")
	var order_kept := true
	for index in range(app.party.get_heroes().size()):
		order_kept = order_kept and app.party.get_hero(index + 1).get("id") \
			== String(pre["heroes"][index].get("id"))
	_check(int(app.enemies.get_enemy(2).get("block", 0))
		== int(pre["enemies"][1].get("block", 0)) and order_kept,
		"the full gauge skips the announced enemy action without Block or shove")
	_check(app.enemies.get_enemy(1)["hp"] == int(pre["enemies"][0]["hp"]),
		"the skipped source never damages or replaces any enemy")
	var hp_kept := true
	for index in range(app.party.get_heroes().size()):
		if int(app.party.get_heroes()[index].get("hp", -1)) != int(hero_hp[index]):
			hp_kept = false
	_check(hp_kept, "hero HP is exactly unchanged through the skipped enemy phase")
	var reset: Dictionary = presenter._unravel.get_snapshot(2)
	_check(int(reset.get("gauge", -1)) == 0 and int(reset.get("threshold", 0)) == 12
		and not bool(reset.get("skip_pending", true))
		and not bool(reset.get("unravelled", true)),
		"consuming the real skip resets the gauge and raises its threshold by four")
	_check(int(presenter._unravel.get_snapshot(1)["gauge"]) == 0
		and int(presenter._unravel.get_snapshot(1)["threshold"]) == 8,
		"the untouched first gauge keeps its own threshold and charge")
	_check(presenter._pinned._pinner_by_position.is_empty(),
		"no invented Pinned token survives the turn")
	_check(app.round_flow._unravel == presenter._unravel,
		"the next enemy phase still shares the same battle gauge")


func _tier_cases() -> void:
	if not await _new_battle([PIN]):
		return
	_check(CombatSeamstressPoolControl.UNPICK_IDS.size() == 2
		and CombatSeamstressPoolControl.NEEDLE_IDS.size() == 2,
		"the resolver catalogs the base and '+' control variants")
	_check(presenter.enemy_tier_map(app.enemies) == {1: "normal", 2: "normal"},
		"the live starter roster classifies as two normal slots")

	var elite_records := _catalog_records("res://data/enemies/m04_elites.json")
	# The elite catalog gains v3 records over time while a roster holds at most
	# three, so bind the two named originals instead of the whole catalog.
	var named_elites: Array = elite_records.filter(func(record: Dictionary) -> bool:
		return record["id"] in ["needle_marshal", "spool_hexer"])
	_check(named_elites.size() == 2,
		"both named authored elite records are present for the tier check")
	var elite := CombatEnemies.new(named_elites)
	_check(elite.is_valid() and not presenter.enemy_tier_map(elite).is_empty(),
		"the authored elite catalog classifies")
	var elite_tiers: Dictionary = presenter.enemy_tier_map(elite)
	for position in elite_tiers:
		_check(elite_tiers[position] == "elite", "elite catalog slot maps to the elite tier")

	var boss_records := _catalog_records("res://data/enemies/boss.json")
	var boss := CombatEnemies.new(boss_records)
	var boss_tiers: Dictionary = presenter.enemy_tier_map(boss)
	_check(boss_tiers.size() == 1 and boss_tiers[1] == "boss",
		"the authored boss catalog maps to the boss tier")

	var run_records := _catalog_records("res://data/enemies/run_enemies.json")
	var run_enemies := CombatEnemies.new(run_records.slice(0, 2))
	var run_tiers: Dictionary = presenter.enemy_tier_map(run_enemies)
	_check(run_tiers.size() == 2 and run_tiers[1] == "normal" and run_tiers[2] == "normal",
		"the authored run enemy catalog maps to the normal tier")

	var unknown := CombatEnemies.new([{"id": "unlisted_foe", "max_hp": 10}])
	_check(presenter.enemy_tier_map(unknown).is_empty(),
		"an unknown original enemy ID binds no gauge")
	var mixed_records: Array = []
	mixed_records.append(named_elites[0])
	mixed_records.append(run_records[0])
	var mixed := CombatEnemies.new(mixed_records)
	_check(presenter.enemy_tier_map(mixed) == {1: "elite", 2: "normal"},
		"a mixed authored roster keeps a tier per original slot")

	var ambiguous: Array = [
		{"tier": "normal", "ids": ["same_foe"]},
		{"tier": "elite", "ids": ["same_foe"]},
	]
	_check(presenter.tier_from_catalogs("same_foe", ambiguous).is_empty(),
		"an ID classified in two tiers is rejected")
	var single: Array = [{"tier": "boss", "ids": ["only_foe"]}]
	_check(presenter.tier_from_catalogs("only_foe", single) == "boss",
		"one unambiguous authored classification is accepted")
	_check(presenter.tier_from_catalogs("missing_foe", single).is_empty(),
		"an ID absent from every catalog is rejected")
	_check(presenter.tier_from_catalogs("", single).is_empty(),
		"an empty enemy ID is rejected")
	_check(presenter.tier_from_catalogs("only_foe",
		[{"tier": "mythic", "ids": ["only_foe"]}]).is_empty(),
		"an unknown tier name is rejected")
	_check(not presenter.authored_enemy_catalogs().is_empty(),
		"the real four authored enemy catalogs load")


func _catalog_records(path: String) -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	var records: Array = []
	for record in parsed:
		records.append({"id": String(record["id"]), "max_hp": int(record["max_hp"])})
	return records


func _rejections() -> void:
	# Genuinely slain target slot: only the surviving slot is offered.
	if await _new_battle([SNAG]):
		_check(app.enemies.apply_damage(1, 10000) and app.enemies.is_slain(1),
			"the first original enemy slot is genuinely slain")
		app._refresh_enemy_roster()
		await _frames()
		_check(await _select(SNAG, false), "Snag still selects with a surviving target")
		_assert_control_cue(SNAG, [2])
		var slain_before := _state()
		await _key(KEY_1)
		_check(_state() == slain_before, "a slain slot refuses the cast without any mutation")
		await _mouse(app.get_node("LiveEnemyRoster")._labels[0])
		_check(_state() == slain_before, "clicking a slain enemy slot also refuses without mutation")
		await _return()

	# Authored FROM slot: Snag requires the middle or back Seamstress slot.
	if await _new_battle([SNAG]):
		var swap: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
		_check(swap.get("ok", false), "the production preview moves the Seamstress forward")
		app.party._heroes.assign(swap.heroes)
		app._refresh_party()
		await _frames()
		_check(app.party.get_hero(1).get("id") == "seamstress",
			"the Seamstress really occupies the forbidden front slot")
		_check(await _select(SNAG, false), "the held Snag panel still selects")
		_check(presenter.cue.text.contains("Unavailable"),
			"the live cue refuses the authored illegal owner slot")
		var front_before := _state()
		await _key(KEY_2)
		_check(_state() == front_before, "an illegal owner slot refuses without mutation")
		await _return()

	# Downed owner.
	if await _new_battle([PIN]):
		_check(app.party.apply_damage(2, 10000) and app.party.is_downed(2),
			"the Seamstress owner is genuinely downed")
		app._refresh_party()
		await _frames()
		_check(await _select(PIN, false), "the held Needle Pin panel still selects")
		_check(presenter.cue.text.contains("Unavailable"),
			"the live cue refuses a downed owner")
		var downed_before := _state()
		await _key(KEY_1)
		_check(_state() == downed_before, "a downed owner refuses without mutation")
		await _return()

	# Insufficient energy for an otherwise legal cast.
	if await _new_battle([UNPICK]):
		app.deck.combat_state.energy = 0
		await _frames()
		var energy_before := _state()
		await _mouse(_panel(UNPICK))
		await _key(KEY_1)
		_check(_state() == energy_before and app.deck.energy == 0,
			"insufficient energy refuses without spending or discarding")
		await _return()

	# Inactive player turn.
	if await _new_battle([UNPICK]):
		app.deck.combat_state.player_turn_active = false
		await _frames()
		var inactive_before := _state()
		await _mouse(_panel(UNPICK))
		await _key(KEY_1)
		_check(_state() == inactive_before, "an inactive turn refuses without mutation")
		await _return()

	# A queued cast must not resolve after the real turn advanced.
	if await _new_battle([UNPICK]):
		_check(await _select(UNPICK, false), "a legal cast is selected before the turn moves")
		presenter._queue_attack(1)
		_check(presenter._queued, "the legal cast is genuinely queued")
		app.enemy_intents.advance_turn()
		app.enemy_attacks = app.enemy_intents.get_intents()
		var turn_before := _state()
		await _frames()
		_check(_state() == turn_before and not presenter._queued,
			"a queued cast cannot resolve after the turn index moved")
		await _return()

	# A queued cast must not resolve after the target identity changed.
	if await _new_battle([PIN]):
		_check(await _select(PIN, false), "a legal cast is selected before the target changes")
		presenter._queue_attack(1)
		_check(presenter._queued, "the legal cast is genuinely queued")
		app.enemies._enemies[0]["id"] = "swapped_foe"
		var target_before := _state()
		await _frames()
		_check(_state() == target_before and not presenter._queued,
			"a replaced target identity refuses the stale target")
		await _return()

	# A queued cast must not resolve after its held copy left the hand.
	if await _new_battle([UNPICK]):
		_check(await _select(UNPICK, false), "a legal cast is selected before the hand changes")
		presenter._queue_attack(1)
		_check(presenter._queued, "the legal cast is genuinely queued")
		_check(app.deck.discard_played(UNPICK), "the held copy really leaves the hand")
		app._refresh_hand()
		await _frames()
		var hand_before := _state()
		await _frames()
		_check(_state() == hand_before and not presenter._queued,
			"a changed hand refuses the stale held copy")
		await _return()

	# An unbound gauge must never be reported as a successful live cast.
	if await _new_battle([UNPICK]):
		presenter._unravel = CombatUnravel.new()
		_check(await _select(UNPICK, false), "the held Unpick panel still selects")
		_check(presenter.cue.text.contains("Unavailable"),
			"the live cue refuses an unbound gauge")
		var gauge_before := _state()
		await _key(KEY_1)
		_check(_state() == gauge_before and app.round_flow._unravel == null,
			"an unbound gauge leaves the cast refused and the round flow unbound")
		await _return()

	# Replaying a consumed panel callback cannot charge the same card twice.
	if await _new_battle([UNPICK]):
		var panel := _panel(UNPICK)
		var callback: Callable = presenter._bindings[panel].input
		var replay_before := _state()
		await _mouse(panel)
		await _key(KEY_1)
		_check(presenter.last_event.get("ok", false) and app.deck.energy == int(replay_before["energy"]) - 1,
			"the real cast committed exactly once")
		var replay_after := _state()
		callback.call(_mouse_event())
		await _key(KEY_1)
		_check(_state() == replay_after, "replaying the captured input and key cannot charge twice")
		await _return()


func _mouse_event() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


## AC3: a real Return retires every live authority, and the next battle starts
## with a fresh gauge and no pins or skips from the old one.
func _return_isolation() -> void:
	if not await _new_battle([UNPICK]):
		return
	var old_panel := _panel(UNPICK)
	_check(old_panel != null and presenter._bindings.has(old_panel),
		"the old battle holds a bound Unpick panel")
	if old_panel == null or not presenter._bindings.has(old_panel):
		return
	var old_callback: Callable = presenter._bindings[old_panel].input
	_check(await _select(UNPICK, false), "the old battle selects its Unpick")
	var before := _state()
	await _target(2, false)
	_assert_cast(UNPICK, before, 2, "return isolation Unpick")
	_check(presenter._pinned.pin_enemy(app.enemies, 1, "tinker"),
		"the old battle really holds a Pinned token")
	_check(int(presenter._unravel.get_snapshot(2)["gauge"]) == 5,
		"the old battle really holds gauge charge")
	var old_pinned: CombatPinned = presenter._pinned
	var old_unravel: CombatUnravel = presenter._unravel
	var old_pins: Dictionary = old_pinned._pinner_by_position.duplicate(true)
	var old_gauges: Dictionary = old_unravel._gauges.duplicate(true)
	var old_deck: CombatDeck = app.deck
	var old_hand: Array = old_deck.hand.duplicate()
	var old_energy: int = old_deck.energy
	var old_enemies: Array = app.enemies.get_enemies().duplicate(true)
	await _return()
	_check(app.deck == null and presenter._bindings.is_empty() and presenter.cue == null,
		"Return retires every card binding and the live cue")
	_check(presenter._pinned == null and presenter._unravel == null,
		"Return drops the battle's Pinned and Unravel authorities")
	_check(old_deck.hand == old_hand and old_deck.energy == old_energy,
		"Return never rewrites the old deck or energy")
	_check(old_pinned._pinner_by_position == old_pins
		and old_unravel._gauges == old_gauges,
		"the retired authorities keep exactly the state they ended with")
	_check(old_enemies.size() == 2, "the old battle had two original enemy slots")

	_check(await _new_battle([PIN]), "a second real battle starts after Return")
	_check(presenter._pinned != old_pinned and presenter._unravel != old_unravel,
		"the new battle owns different Pinned and Unravel instances")
	_check(app.round_flow._unravel == null,
		"the old gauge never leaks into the new round flow before a cast")
	_check(presenter._pinned._pinner_by_position.is_empty(),
		"the new battle starts with no Pinned token")
	var fresh: Dictionary = presenter._unravel.get_snapshot(1)
	_check(int(fresh.get("gauge", -1)) == 0
		and int(fresh.get("threshold", 0)) == CombatUnravel.THRESHOLD_NORMAL
		and not bool(fresh.get("skip_pending", true)),
		"the new battle starts with an empty normal gauge")
	var fresh_before := _state()
	old_callback.call(_mouse_event())
	await _frames()
	await _key(KEY_1)
	_check(_state() == fresh_before,
		"the captured old callback cannot mutate the new battle")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "the real app scene loads")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node_or_null("LiveAttackPreview")
	support = app.get_node_or_null("LiveSupportHand")
	_check(presenter != null and support != null and app.deck == null,
		"the real title mounts both hand presenters with no battle")
	if presenter == null or support == null:
		app.free()
		_finish()
		return
	var targeting := CombatAttackTargeting.new()
	for id in CONTROL_IDS:
		_check(catalog.get_definition(id).get("id") == id,
			"the authored pool catalog really contains: " + id)
		_check(targeting.is_seamstress_control(id) and targeting.supports(id),
			"the picker admits the authored control card: " + id)
		_check(not CombatAttackTargeting.ATTACK_IDS.has(id),
			"the starter-only attack enumeration is preserved: " + id)
	await _needle_cases()
	await _snag_cases()
	await _unpick_cases()
	await _shared_gauge_turn()
	await _tier_cases()
	await _rejections()
	await _return_isolation()
	await _head_route_case(SNAG, false)
	await _head_route_case(SNAG_PLUS, true)
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_seamstress_control_hand_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
