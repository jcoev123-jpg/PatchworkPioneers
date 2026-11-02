extends "res://tests/live_support_hand_test.gd"
## Mounted regression for the two authored Purling Barrage printings. Everything
## below runs through the real res://scenes/app.tscn battle, its shared mounted
## hand/LiveAttackPreview, a real CombatDeck/CombatParty/CombatEnemies, the real
## CombatBattleResult + CombatRoundFlow and the battle's own bound CombatUnravel.

const IDS := ["yarn_ranger_purling_barrage", "yarn_ranger_purling_barrage_plus"]
const CATALOG := preload("res://data/cards/yarn_ranger_pool_cards.gd")

## Non-vacuity counters: the loop below must really exercise both facts.
var lethal_quotes := 0
var lethal_hits := 0


## A genuine mounted battle whose real hand holds exactly one printing. `seat`
## places the living Yarn Ranger, `mode` selects the authored roster variant.
func _begin(id: String, seat: int = 3, mode: String = "") -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 433
	_check(app._start_battle(), "genuine mounted battle starts")
	presenter = app.get_node("LiveAttackPreview")
	var rng := RandomNumberGenerator.new()
	rng.seed = 433
	var cards: Array[String] = [id, "warden_strike", "warden_brace", "tinker_tune_up",
		"seamstress_mend"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 1 and app.deck.energy == 3,
		"a real seeded 5-card / 3-energy hand holds the printed copy")
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 26}]
	heroes.insert(seat - 1, {"id": "yarn_ranger", "name": "Yarn Ranger", "max_hp": 27})
	app.party = CombatParty.new(heroes)
	# Every foe ID occurs in the shipped enemy tier catalogs, so this battle's
	# own Unravel gauge really binds to this exact roster.
	app.enemies = CombatEnemies.new([
		{"id": "ragling", "name": "Ragling", "max_hp": 2 if mode == "lethal" else 18},
		{"id": "ragling_guard", "name": "Guard Ragling", "max_hp": 23},
		{"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 35}])
	_check(app.enemies.gain_block(1, _front_block(mode))
		and app.enemies.gain_block(2, 2) and app.enemies.gain_block(3, 5),
		"original enemy slots carry distinct real Block")
	if mode == "statuses":
		app.party._heroes[seat - 1]["statuses"] = {"weak": 1}
		app.enemies._enemies[0]["statuses"] = {"exposed": 1, "tangled": 1}
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var owner_seat := 0
	for index in range(app.party.get_heroes().size()):
		if app.party.get_hero(index + 1).get("id") == "yarn_ranger":
			owner_seat = index + 1
	_check(app.party.is_valid() and app.enemies.is_valid() and owner_seat == seat
		and presenter._unravel != null and presenter._unravel._bound_enemies == app.enemies
		and presenter._unravel.get_snapshot(1).get("threshold") == 8
		and app.round_flow._enemies == app.enemies,
		"non-vacuous living roster, real round-bound battle and bound 8-threshold gauge")
	var panel := _pool_panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel),
		"the genuine reward/upgrade copy gets a live mounted input binding")
	return panel


func _dispose() -> void:
	app.free()
	await _frames()


## Complete battle/hand/gauge observation; a preview or refusal must not move it.
## The mounted HUD's energy label is checked after a real play instead: a negative
## fixture writes deck energy directly, and the label only re-syncs next frame.
func _state() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng),
		app.enemies.get_enemies(), app.battle_result.get_outcome(),
		presenter._unravel._gauges.duplicate(true), app.round_flow._unravel,
		presenter.last_event.duplicate(true)]


func _arm(panel: Control, keyboard: bool) -> void:
	if keyboard:
		await _keyboard(KEY_ESCAPE)
		# Other held cards are legal too, so P cycles until THIS panel is armed.
		for index in range(12):
			await _keyboard(KEY_P)
			if presenter._armed == panel:
				break
	else:
		await _mouse(panel)
	_check(presenter._armed == panel, "genuine panel armed by P or mouse")


func _front_hp(mode: String) -> int:
	return 2 if mode == "lethal" else 18


func _front_block(mode: String) -> int:
	if mode == "lethal":
		return 0
	return 2 if mode == "statuses" else 4


func _printed(id: String) -> int:
	return 3 if id == IDS[0] else 4


func _unravel(id: String) -> int:
	return 1 if id == IDS[0] else 2


## The shared status rules are the printed per-hit damage oracle: each independent
## hit is adjusted by the real Weak on the owner and the affected foe's own
## Exposed/Tangled (only the front foe carries them in the status case).
func _damage_for(id: String, mode: String, target: int) -> int:
	var attacker := {"weak": 1} if mode == "statuses" else {}
	var defender := {"exposed": 1, "tangled": 1} \
		if mode == "statuses" and target == 1 else {}
	return CombatStatuses.new().adjusted_attack_damage(_printed(id), attacker, defender)


## Independent sequential oracle: identical status-adjusted damage per hit, Block
## spent before HP, and the sequence stops as soon as the foe is slain.
func _simulate(hp: int, block: int, damage: int, count: int) -> Dictionary:
	var remaining_hp := hp
	var remaining_block := block
	var strikes: Array[Dictionary] = []
	for index in range(count):
		if remaining_hp <= 0:
			break
		var absorbed: int = mini(remaining_block, damage)
		var hp_loss: int = mini(remaining_hp, damage - absorbed)
		remaining_block -= absorbed
		remaining_hp -= hp_loss
		strikes.append({"index": index + 1, "damage": damage,
			"block_absorbed": absorbed, "hp_loss": hp_loss})
	return {"hits": strikes, "hp": remaining_hp, "block": remaining_block}


## One authentic play: charge two of three energy, discard exactly one held copy,
## resolve two sequential Block-then-HP hits on the SAME foe (stopping after a
## lethal first hit) and add the printed Unravel exactly once to a survivor.
func _success(id: String, target: int, keyboard: bool, mode: String = "") -> void:
	var panel := await _begin(id, 3, mode)
	if panel == null:
		await _dispose()
		return
	var metadata = app.get_node("LiveSupportHand")._metadata
	var facts: Dictionary = metadata.get_facts(panel)
	var authored := CATALOG.new().get_definition(id)
	var each := _damage_for(id, mode, target)
	var front := _simulate(_front_hp(mode), _front_block(mode), _damage_for(id, mode, 1), 2)
	var front_each := int(front.hits[0].damage)
	_check(facts.get("known", false) and facts.id == id
		and facts.display_name == authored.display_name and facts.cost == 2
		and facts.owner == "yarn_ranger" and facts.cost_text == "Cost 2"
		and facts.from_text == "From 3"
		and facts.target_text.begins_with("To enemy 1")
		and facts.target_text.ends_with("3")
		and metadata.definition(id) == authored
		and authored.from_positions == [3] and authored.to_positions == [1, 2, 3]
		and authored.target_kind == "enemy_single"
		and metadata.short_line(id) == "Two hits of %d; then Unravel %d once if target survives." % [
			_printed(id), _unravel(id)]
		and metadata.visual_state(panel).playable
		and metadata.base_effect_text(id).contains("TWO independent hits")
		and metadata.base_effect_text(id).contains("Unravel ONCE"),
		"real hand shows authentic name/cost/From 3/target/rule face and enables it")
	_check(authored.reward_eligible == (id == IDS[0])
		and (authored.has("upgrade_of") == (id != IDS[0]))
		and authored.illustration_path.ends_with("yarn_ranger_purling_barrage.png"),
		"pool catalog still distinguishes the base reward printing from its upgrade")
	var before := _state()
	await _hover(panel)
	var quote: Dictionary = presenter.current_forecast.duplicate(true)
	_check(quote.get("playable", false) and quote.get("requires_selection", false)
		and quote.target_positions == [1, 2, 3] and quote.hits.size() == 3
		and quote.hits[0].position == 1
		and quote.hits[0].hit_count == front.hits.size()
		and quote.hits[0].base_damage == _printed(id)
		and quote.hits[0].first_damage == front_each
		and quote.hits[0].second_damage == (front_each if front.hits.size() > 1 else 0)
		and quote.hits[0].hp_after == front.hp and quote.hits[0].block_after == front.block
		and quote.hits[0].unravel == (_unravel(id) if front.hp > 0 else 0)
		and quote.hits[0].unravel_printed == _unravel(id)
		and quote.hits[0].gauge == 0 and quote.hits[0].threshold == 8,
		"pure per-slot quote states two independent printed hits and one Unravel")
	var lethal_first: bool = front.hits.size() == 1
	_check(presenter.cue.text.contains(authored.display_name)
		and presenter.cue.text.contains("2 energy")
		and presenter.cue.text.contains("1: %d + %d damage" % [
			int(front.hits[0].damage), front_each if front.hits.size() > 1 else 0])
		and presenter.cue.text.contains("Unravel %d once if it survives" % _unravel(id))
		and presenter.cue.text.contains("both hits stay on it")
		and presenter.cue.text.contains("first hit lethal") == lethal_first,
		"mounted strip quotes two hits and the single post-hit Unravel truthfully")
	if lethal_first:
		lethal_quotes += 1
	_check(_state() == before, "hover quotes without charging or changing any state")
	await _arm(panel, keyboard)
	_check(_state() == before, "mouse/physical keyboard arming is pure")
	presenter._queue_attack(4)
	await _frames()
	_check(not presenter._queued and _state() == before,
		"enemy seat four is never offered or queued")
	_check(presenter.cue.text.contains("Unravel"), "armed panel keeps its honest quote")
	var enemies_before: Array = app.enemies.get_enemies()
	var heroes_before: Array = app.party.get_heroes()
	var hand_before: Array = app.deck.hand.duplicate()
	var discard_before: Array = app.deck.discard_pile.duplicate()
	var draw_before: Array = app.deck.draw_pile.duplicate()
	var rng_before: int = app.run_rng.state
	var gauge: CombatUnravel = presenter._unravel
	var callback: Callable = presenter._bindings[panel].input
	var queued: Array = [panel, id, target, presenter._token, app.party, app.enemies,
		app.battle_result, app.run_rng, presenter._turn, app.enemies.get_enemy(target).id,
		panel.get_index(), app.deck, app.deck.hand.duplicate(), app.run_map, presenter._pinned,
		gauge]
	var source: Dictionary = enemies_before[target - 1].duplicate(true)
	var expected := _simulate(int(source.hp), int(source.block), each, 2)
	var added: int = _unravel(id) if expected.hp > 0 and not expected.hits.is_empty() else 0
	if keyboard:
		var code := KEY_1 + (target - 1)
		root.push_input(_key(code), true)
		root.push_input(_key(code), true)
		root.push_input(_key(code, false), true)
		await _frames()
	else:
		await _mouse(app.get_node("LiveEnemyRoster")._labels[target - 1])
	var event: Dictionary = presenter.last_event
	_check(event.get("ok", false) and event.card_id == id and event.cost == 2
		and event.target_position == target and event.damage_per_hit == _printed(id)
		and event.hit_count == expected.hits.size() and event.hits == expected.hits
		and event.unravel_added == added
		and event.total_hp_loss == int(source.hp) - int(expected.hp),
		"paid receipt is two sequential status/Block/HP hits plus one post-sequence Unravel")
	if expected.hits.size() == 1:
		lethal_hits += 1
		_check(added == 0 and expected.hp == 0
			and gauge.get_snapshot(target).gauge == 0,
			"a lethal first hit really stops the second hit and the Unravel")
	var victim: Dictionary = source.duplicate(true)
	victim.hp = expected.hp
	victim.block = expected.block
	var expected_roster: Array = enemies_before.duplicate(true)
	expected_roster[target - 1] = victim
	_check(app.enemies.get_enemies() == expected_roster and app.party.get_heroes() == heroes_before,
		"exact deterministic HP/Block on the same foe; every other actor untouched")
	var snapshot: Dictionary = gauge.get_snapshot(target)
	_check(snapshot.gauge == added and snapshot.threshold == 8
		and app.round_flow._unravel == gauge and gauge == presenter._unravel,
		"the printed Unravel lands once on the battle's one shared existing gauge")
	hand_before.erase(id)
	discard_before.append(id)
	_check(app.deck.energy == 1 and app.deck.hand == hand_before
		and app.deck.discard_pile == discard_before and app.deck.draw_pile == draw_before
		and app.run_rng.state == rng_before
		and app.hand_view.get_child_count() == hand_before.size()
		and not presenter._bindings.has(panel)
		and app.get_node("LiveSupportHand").energy_label.text == "1",
		"two energy charged, one copy discarded, mounted hand refreshed, no RNG draw")
	var settled := _state()
	callback.call(_press())
	presenter._commit.callv(queued)
	presenter._queue_attack(target)
	await _frames()
	_check(_state() == settled, "old panel/duplicate press/queued replay is inert")
	await _dispose()


## Authentic metadata plus a dim face where the printed source seat is not legal.
func _seat_two_case() -> void:
	var panel := await _begin(IDS[0], 2)
	if panel == null:
		await _dispose()
		return
	var metadata = app.get_node("LiveSupportHand")._metadata
	_check(metadata.get_facts(panel).get("known", false)
		and metadata.get_facts(panel).display_name == "Purling Barrage"
		and metadata.short_line(IDS[0]).contains("Two hits of 3")
		and not metadata.visual_state(panel).playable,
		"a recognized but illegal 2-seat printing keeps its face and stays disabled")
	_check(presenter._target_preview(IDS[0]).get("playable", false) == false
		and presenter._target_preview(IDS[0]).get("target_positions", [1]) == [],
		"the mounted presenter offers no enemy choice outside the printed FROM 3")
	await _dispose()


## Each invalidated precondition must leave every real model and the RNG untouched.
func _negative(mode: String, queued: bool) -> void:
	var panel := await _begin(IDS[0])
	if panel == null:
		await _dispose()
		return
	await _arm(panel, true)
	if queued:
		presenter._queue_attack(1)
		_check(presenter._queued, "valid cast queued before invalidation: " + mode)
	match mode:
		"seat":
			var swap: Dictionary = app.party._heroes[1]
			app.party._heroes[1] = app.party._heroes[2]
			app.party._heroes[2] = swap
			app.party._heroes[1].position = 2
			app.party._heroes[2].position = 3
		"downed": app.party.apply_damage(3, 999)
		"zero": app.deck.combat_state.energy = 0
		"one": app.deck.combat_state.energy = 1
		"missing": app.deck.discard_played(IDS[0])
		"forged": panel.get_child(0).text = "yarn_ranger_purling_barrage_forged"
		"slain": app.enemies.apply_damage(1, 999)
		"identity": app.enemies._enemies[0].id = "replacement_foe"
		"roster": app.enemies = CombatEnemies.new([
			{"id": "ragling", "name": "Ragling", "max_hp": 18},
			{"id": "ragling_guard", "name": "Guard Ragling", "max_hp": 23},
			{"id": "fray_scavenger", "name": "Fray Scavenger", "max_hp": 35}])
		"gauge": presenter._unravel = CombatUnravel.new()
		"turn": app.enemy_intents.advance_turn()
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"closed": app._battle_closed = true
		"panel": app._refresh_hand()
		"hand_order": app.deck.hand.reverse()
		"rng":
			app.run_rng = RandomNumberGenerator.new()
			app.run_rng.seed = 434
	var before := _state()
	if not queued:
		await _keyboard(KEY_1)
	else:
		await _frames()
	_check(_state() == before, "full fail-closed no-spend/no-hit/no-RNG: " + mode
		+ " queued=" + str(queued))
	var stable := _state()
	presenter._queue_attack(1)
	await _frames()
	_check(_state() == stable, "refused cast cannot replay: " + mode)
	await _dispose()


## A slain first slot is omitted from the picker without compacting the roster.
func _slain_slot() -> void:
	var panel := await _begin(IDS[1])
	app.enemies.apply_damage(1, 999)
	await _hover(panel)
	_check(presenter.current_forecast.get("target_positions", []) == [2, 3],
		"pure picker omits dead original slot 1 without compacting the roster")
	await _arm(panel, true)
	var before := _state()
	await _keyboard(KEY_1)
	_check(_state() == before, "dead slot keyboard shortcut rejected")
	await _keyboard(KEY_2)
	_check(presenter.last_event.get("ok", false)
		and presenter.last_event.target_position == 2
		and presenter.last_event.hit_count == 2
		and presenter.last_event.unravel_added == 2,
		"living original slot 2 remains keyboard-accessible for the upgrade")
	await _dispose()


## A forged spelling keeps no authentic catalog face, and an unheld printing is
## never offered a legal target by the mounted presenter.
func _unknown_card_case() -> void:
	var panel := await _begin(IDS[0])
	var metadata = app.get_node("LiveSupportHand")._metadata
	_check(metadata.definition("yarn_ranger_purling_barrage_forged").is_empty()
		and metadata.short_line("yarn_ranger_purling_barrage_forged").is_empty()
		and metadata.base_effect_text("yarn_ranger_purling_barrage_forged") == "Unknown card",
		"a forged Purling spelling has no authentic catalog face or rule line")
	app.deck.hand.erase(IDS[0])
	var before := _state()
	_check(presenter._target_preview(IDS[0]).get("playable", false) == false
		and presenter._target_preview(IDS[0]).get("target_positions", [1]) == []
		and _state() == before,
		"an unheld printing offers no target choice and mutates nothing")
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id in IDS:
		for target in [1, 2, 3]:
			for keyboard in [false, true]:
				await _success(id, target, keyboard)
		await _success(id, 1, true, "lethal")
		await _success(id, 1, false, "statuses")
		await _success(id, 2, true, "statuses")
	_check(lethal_quotes == 2 and lethal_hits == 2,
		"both printings really quoted and played a lethal first hit")
	for mode in ["seat", "downed", "zero", "one", "missing", "forged", "slain",
		"identity", "roster", "gauge", "turn", "session", "closed", "panel",
		"hand_order", "rng"]:
		# A replaced target ID or another still-held identical copy is legal until
		# a queue captured its original target/hand instance.
		for queued in ([true] if mode in ["identity", "hand_order"] else [false, true]):
			await _negative(mode, queued)
	await _seat_two_case()
	await _slain_slot()
	await _unknown_card_case()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_yarn_ranger_purling_barrage_hand_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
