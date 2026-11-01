extends "res://tests/live_warden_v3_taunt_hand_test.gd"
## Mounted real hand -> authentic Jury-rig/+ -> observed Tune Up/+ witness.
##
## The fixture opens a deterministic hand containing two shipped Jury-rig
## printings and the authentic Tune Up source. Every success, refusal, stale
## selection and fresh-fight reset runs through the real mounted app scene.

const JURY_IDS := ["tinker_v3_jury_rig", "tinker_v3_jury_rig_plus"]
const SOURCE_IDS := ["tinker_tune_up", "tinker_tune_up_plus"]
const SPARE_IDS := ["tinker_spare_parts", "tinker_spare_parts_plus"]
const FILLERS := ["warden_brace", "seamstress_mend", "seamstress_stitch_up",
	"tinker_scrap_bomb", "warden_brace_plus", "seamstress_mend_plus"]


func _cards(jury_id: String, sources: Array, extras: Array, size: int = 9) -> Array[String]:
	var cards: Array[String] = [jury_id, jury_id]
	for id in sources:
		cards.append(str(id))
	for id in extras:
		cards.append(str(id))
	var index := 0
	while cards.size() < size:
		cards.append(FILLERS[index % FILLERS.size()])
		index += 1
	return cards


func _seed_for(cards: Array[String], required: Dictionary) -> int:
	for candidate in range(3000):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		deck.start_turn()
		var ok := true
		for id in required:
			if deck.hand.count(str(id)) < int(required[id]):
				ok = false
				break
		if ok:
			return candidate
	return -1


## The authentic printed record for a last-play source, from the catalog that owns it.
func _source_definition(source_id: String) -> Dictionary:
	if TinkerPoolCards.new().has_card(source_id):
		return TinkerPoolCards.new().get_definition(source_id)
	return StarterCards.new().get_definition(source_id)


## The same opening hand as `_seed_for`, but the genuine FOLLOWING turn must also hold
## a Jury-rig copy: the cost-zero source is committed, its printed draw runs, End Turn
## disposes the hand and the next hand draws. That is exactly the real deck API, so the
## stale-turn case can click a really held card instead of inventing one.
func _seed_for_next(cards: Array[String], required: Dictionary, source_id: String,
		jury_id: String) -> int:
	var source_draw: int = int(_source_definition(source_id).get("effects", {}).get("draw", 0))
	for candidate in range(3000):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		deck.start_turn()
		var ok := true
		for id in required:
			if deck.hand.count(str(id)) < int(required[id]):
				ok = false
				break
		if not ok:
			continue
		if not deck.discard_played(source_id) or deck.draw_extra(source_draw) < 0:
			continue
		if not deck.end_turn() or not deck.start_turn():
			continue
		if deck.hand.count(jury_id) >= 1 and deck.energy == 3:
			return candidate
	return -1


func _heroes(tinker_seat: int) -> Array:
	var heroes: Array = [
		{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 30},
		{"id": "tinker", "name": "Tinker", "max_hp": 26}]
	if tinker_seat == 2:
		heroes = [heroes[0], heroes[2], heroes[1]]
	elif tinker_seat == 1:
		heroes = [heroes[2], heroes[0], heroes[1]]
	return heroes


func _install(cards: Array[String], seed_value: int, tinker_seat: int, jury_id: String) -> Control:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	app.party = CombatParty.new(_heroes(tinker_seat))
	app.enemies = CombatEnemies.new([
		{"id": "jury_one", "name": "Jury One", "max_hp": 45},
		{"id": "jury_two", "name": "Jury Two", "max_hp": 45},
		{"id": "jury_three", "name": "Jury Three", "max_hp": 45}])
	app.enemy_intents = CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 3, "target_position": 3}]},
		{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 2, "target_position": 2}]},
		{"enemy_position": 3, "pattern": [{"type": "block", "amount": 2}]}])
	app.enemy_attacks = app.enemy_intents.get_intents()
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies,
		app.enemy_intents, app.battle_result)
	_check(app.round_flow.begin_fight(), "authentic round flow opens the Jury-rig fixture")
	app._refresh_intents()
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _panel(jury_id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel)
		and panel.gui_input.get_connections().size() == 1
		and panel.focus_mode == Control.FOCUS_ALL,
		"Jury-rig has one real mounted clickable/focusable hand panel: " + jury_id)
	return panel


func _mount(jury_id: String, sources: Array, extras: Array, required: Dictionary,
		tinker_seat: int = 3, size: int = 9, next_source: String = "") -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 390390
	_check(app._start_battle(), "real battle UI mounts before the Jury-rig fixture")
	presenter = app.get_node("LiveSupportHand")
	var cards := _cards(jury_id, sources, extras, size)
	var seed_value := _seed_for_next(cards, required, next_source, jury_id) \
		if not next_source.is_empty() else _seed_for(cards, required)
	_check(seed_value >= 0, "deterministic opening holds Jury-rig, Tune Up source and required cards")
	if seed_value < 0:
		return null
	return await _install(cards, seed_value, tinker_seat, jury_id)


func _state() -> Array:
	if presenter == null or presenter._jury == null:
		return []
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemies.get_enemies(),
		app.enemy_intents.get_intents(), presenter._jury.has_used_this_combat(),
		presenter._jury.committed_history(), presenter._jury_receipts.duplicate(true),
		presenter._jury_witness.duplicate(true)]


## The drawn face's own brightness, the same cue every other mounted card test
## reads: an impossible cast is dimmed, a genuine one is drawn at full colour.
func _bright(panel: Control) -> bool:
	return panel != null and panel.self_modulate.is_equal_approx(Color.WHITE)


func _dimmed(panel: Control) -> bool:
	return panel != null and not panel.self_modulate.is_equal_approx(Color.WHITE)


func _press_at(panel: Control) -> Vector2:
	var point := panel.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	await _frames()
	return point


func _release_at(point: Vector2) -> void:
	var release := InputEventMouseButton.new()
	release.position = point
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	root.push_input(release, true)
	await _frames()


func _expected_draw(cards: Array, jury_id: String, draw: int) -> Array:
	var hand: Array = cards[0].duplicate()
	var pile: Array = cards[1].duplicate()
	hand.erase(jury_id)
	for slot in range(draw):
		if pile.is_empty():
			break
		hand.append(pile.pop_back())
	return [hand, pile, cards[2] + [jury_id]]


## One full authentic source -> preview -> paid Jury-rig -> double-play attempt.
func _case(jury_id: String, source_id: String, keyboard: bool, tinker_seat: int = 3) -> Array:
	var panel := await _mount(jury_id, [source_id], [],
		{jury_id: 2, source_id: 1}, tinker_seat)
	if panel == null:
		await _complete()
		return []
	var source_face := StarterCards.new().get_definition(source_id)
	var source_draw: int = int(source_face.get("effects", {}).get("draw", 0))
	var cost: int = int(CombatTinkerV3JuryRigCards.CARDS[jury_id]["cost"])
	_check(source_draw == (1 if source_id == "tinker_tune_up" else 2),
		"authentic source prints its exact draw: " + source_id)
	_check(app.deck.energy == 3 and app.party.get_hero(tinker_seat).id == "tinker",
		"fixture has printed energy and a living Tinker at the required seat")
	_check(not presenter._jury_can_cast(jury_id)
		and not presenter._metadata.visual_state(_panel(jury_id)).get("playable", false)
		and _dimmed(_panel(jury_id)),
		"before any source the mounted Jury-rig is truthfully disabled and drawn dim")
	# Play the authentic source through the real hand.
	var source_panel := _panel(source_id)
	_check(source_panel != null, "source card is genuinely held before play")
	await _input_card(source_panel, keyboard)
	_check(not app.deck.hand.has(source_id), "successful source left the hand")
	_check(app.deck.discard_pile.count(source_id) == 1, "exactly one source was discarded")
	_check(presenter._jury_receipts.size() == 1
		and presenter._jury_receipts[0].get("card_id") == source_id,
		"presenter observed only the genuine successful source commit")
	_check(presenter._jury_can_cast(jury_id), "living Tinker, energy and source admit Jury-rig")
	var armed_panel := _panel(jury_id)
	_check(armed_panel != null
		and bool(presenter._metadata.visual_state(armed_panel).get("playable", false))
		and _bright(armed_panel),
		"mounted Jury-rig face becomes playable at full colour after the verified commit")
	var armed := _state()
	# Preview, pending choice and cancel must be pure reads.
	await _hover(armed_panel)
	_check(_state() == armed, "hovering the armed Jury-rig changes no state")
	var point := await _press_at(armed_panel)
	_check(presenter._pending.get("id") == jury_id
		and presenter._pending.has("jury_state") and presenter._jury_selection_valid(),
		"real mouse press snapshots the exact deck, battle and witness")
	_check(_state() == armed, "selecting Jury-rig spends, draws, latches and mutates nothing")
	await _keyboard(KEY_ESCAPE)
	_check(presenter._pending.is_empty() and _state() == armed,
		"Cancel leaves the source witness, piles, party, RNG and latch unchanged")
	await _release_at(point)
	_check(_state() == armed, "releasing the cancelled press cannot replay the selection")
	# Capture the deterministic pre-pay state and the Tune Up receipt for latch proof.
	var before: Array = [_snapshot(app.deck, app.party, app.run_rng),
		app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate(), app.run_rng.state]
	var receipts: Array = presenter._jury_receipts.duplicate(true)
	var block_before: int = app.party.get_hero(tinker_seat).block
	_check(app.deck.draw_pile.size() >= source_draw,
		"fixture keeps enough live cards for the copied draw")
	await _input_card(_panel(jury_id), keyboard)
	var expected := _expected_draw([before[1], before[2], before[3]], jury_id, source_draw)
	_check(app.deck.hand == expected[0] and app.deck.draw_pile == expected[1]
		and app.deck.discard_pile == expected[2],
		"paid copy draws exactly the source's printed amount from the live deck")
	_check(app.party.get_hero(tinker_seat).block == block_before,
		"a copied Tune Up grants no Block to the Tinker")
	_check(app.deck.energy == 3 - cost and app.deck.hand.count(jury_id) == 1,
		"exactly one printed cost is paid and one held copy is discarded")
	_check(app.run_rng.state == before[4],
		"the live deck's seeded RNG is untouched when no reshuffle is needed")
	_check(presenter._jury.has_used_this_combat()
		and presenter._jury.committed_history().size() == 1
		and presenter._jury.committed_history()[0].get("card_id") == source_id,
		"accepted play sets the once-per-combat latch and keeps the authentic history")
	_check(presenter._jury_receipts.is_empty(),
		"the presenter consumes the witness after the paid copy")
	_check(presenter._jury.preflight(app.deck, app.party, jury_id, receipts).get("reason", "")
		== "already_used", "the accepted service itself refuses a second combat copy")
	# A genuinely held second copy must refuse without any second charge or draw.
	var second := _panel(jury_id)
	_check(second != null and not presenter._jury_can_cast(jury_id),
		"a second held Jury-rig is mounted but no longer actionable")
	var locked := _state()
	await _input_card(second, not keyboard)
	_check(_state() == locked and app.deck.energy == 3 - cost
		and app.deck.discard_pile.count(jury_id) == 1,
		"double-play refusal spends, draws, discards or latches nothing more")
	var trace := _state()
	await _complete()
	return trace


## A later real support card replaces the source with an unsupported one.
func _unsupported_source(jury_id: String, source_id: String, keyboard: bool) -> void:
	var panel := await _mount(jury_id, [source_id], ["warden_brace"],
		{jury_id: 2, source_id: 1, "warden_brace": 1})
	if panel == null:
		await _complete()
		return
	await _input_card(_panel(source_id), keyboard)
	_check(presenter._jury_can_cast(jury_id), "authentic source briefly arms Jury-rig")
	await _input_card(_panel("warden_brace"), not keyboard)
	_check(app.deck.discard_pile.count("warden_brace") == 1
		and presenter._jury_receipts.is_empty(),
		"a later real support commit replaces the Tune Up witness")
	_check(not presenter._jury_can_cast(jury_id)
		and not presenter._metadata.visual_state(_panel(jury_id)).get("playable", false)
		and _dimmed(_panel(jury_id)),
		"unsupported preceding card leaves Jury-rig truthfully disabled and drawn dim")
	var before := _state()
	await _input_card(_panel(jury_id), keyboard)
	_check(_state() == before and not presenter._jury.has_used_this_combat(),
		"clicking the disabled Jury-rig cannot spend, draw or latch")
	await _complete()


## A real later play arrives after selection but before deferred activation.
func _stale_deferred(jury_id: String, source_id: String) -> void:
	var panel := await _mount(jury_id, [source_id], ["warden_brace"],
		{jury_id: 2, source_id: 1, "warden_brace": 1})
	if panel == null:
		await _complete()
		return
	await _input_card(_panel(source_id), true)
	var point := await _press_at(_panel(jury_id))
	_check(presenter._pending.get("id") == jury_id and presenter._jury_selection_valid(),
		"stale case starts with a genuinely valid deferred selection")
	_check(presenter._play_held(app.deck, app.party, "warden_brace", 0),
		"the intervening Brace is a real successful support commit")
	var after_other := _state()
	_check(after_other != [], "intervening commit is observable")
	await _release_at(point)
	_check(presenter._pending.is_empty() and _state() == after_other
		and not presenter._jury.has_used_this_combat(),
		"stale deferred Jury-rig activation cannot spend, draw or latch into the changed deck")
	await _complete()


func _jury_refusals(jury_id: String, source_id: String) -> void:
	var panel := await _mount(jury_id, [source_id], [],
		{jury_id: 2, source_id: 1})
	if panel == null:
		await _complete()
		return
	await _input_card(_panel(source_id), false)
	_check(presenter._jury_can_cast(jury_id), "refusal fixture starts with a verified source")
	# The mounted face must state the real price, both supported source families and
	# that every other preceding card leaves it disabled.
	var cost: int = int(CombatTinkerV3JuryRigCards.CARDS[jury_id]["cost"])
	var tooltip: String = presenter._metadata.base_effect_text(jury_id)
	_check(tooltip.contains("%d energy" % cost) and tooltip.contains("Tune Up")
		and tooltip.contains("Tune Up+") and tooltip.contains("Spare Parts")
		and tooltip.contains("Spare Parts+") and tooltip.contains("Block")
		and tooltip.contains("0 energy") and tooltip.contains("disabled"),
		"the mounted face names the printed cost, both supported sources and the disabled rule")
	_check(presenter._metadata._rules(jury_id).contains("Tune Up")
		and presenter._metadata._rules(jury_id).contains("Spare Parts")
		and presenter._metadata._rules(jury_id).contains("free"),
		"the drawn face line names both supported sources and the free copy")
	# Wrong owner identity.
	app.party._heroes[2]["id"] = "not_tinker"
	var wrong_owner := _state()
	await _input_card(_panel(jury_id), false)
	_check(_state() == wrong_owner, "illegal owner refuses without any mutation")
	app.party._heroes[2]["id"] = "tinker"
	# Unheld copies are never inferred from the catalog.
	while app.deck.hand.has(jury_id):
		app.deck.hand.erase(jury_id)
	var gone := _state()
	await _input_card(_panel(jury_id), true)
	_check(_state() == gone, "unheld Jury-rig cannot spend, draw or latch")
	# Forged ID is neither actionable nor accepted by the observed route.
	var forged_before := _state()
	_check(not presenter._is_actionable(jury_id + "_forged")
		and not presenter._play_held(app.deck, app.party, jury_id + "_forged", 0)
		and not presenter._play_jury_rig(app.deck, app.party, jury_id + "_forged")
		and _state() == forged_before,
		"forged Jury-rig ID fails closed before any combat mutation")
	await _complete()


## The source is genuinely committed while the shared spool cannot afford Jury-rig,
## so the refusal comes from the resolver's printed energy, with the witness valid.
func _insufficient_energy(jury_id: String, source_id: String) -> void:
	var panel := await _mount(jury_id, [source_id], [],
		{jury_id: 2, source_id: 1})
	if panel == null:
		await _complete()
		return
	var cost: int = int(CombatTinkerV3JuryRigCards.CARDS[jury_id]["cost"])
	app.deck.combat_state.energy = cost - 1
	await _input_card(_panel(source_id), false)
	_check(presenter._jury_witness_valid(), "cheap source commits into the low-energy spool")
	_check(presenter._jury.preflight(app.deck, app.party, jury_id,
		presenter._jury_receipts).get("reason") == "insufficient_energy",
		"the accepted resolver itself reports the printed energy refusal")
	_check(not presenter._jury_can_cast(jury_id)
		and not presenter._metadata.visual_state(_panel(jury_id)).get("playable", false)
		and _dimmed(_panel(jury_id)),
		"low energy leaves the mounted Jury-rig truthfully disabled and drawn dim")
	var poor := _state()
	await _input_card(_panel(jury_id), true)
	_check(_state() == poor and not presenter._jury.has_used_this_combat(),
		"insufficient energy spends, draws, latches and moves the source witness not at all")
	await _complete()


func _front_tinker_refusal(jury_id: String, source_id: String) -> void:
	var panel := await _mount(jury_id, [source_id], [],
		{jury_id: 2, source_id: 1}, 1)
	if panel == null:
		await _complete()
		return
	_check(app.party.get_hero(1).id == "tinker" and app.party.get_hero(1).hp > 0,
		"precondition: the Tinker is alive but not in a legal back/middle seat")
	await _input_card(_panel(source_id), false)
	_check(presenter._jury_witness_valid()
		and presenter._jury.preflight(app.deck, app.party, jury_id,
			presenter._jury_receipts).get("reason") == "owner_illegal_position",
		"the source genuinely committed before the position refusal")
	_check(not presenter._jury_can_cast(jury_id)
		and not presenter._metadata.visual_state(_panel(jury_id)).get("playable", false)
		and _dimmed(_panel(jury_id)),
		"front-seat Tinker is truthfully unable to cast Jury-rig")
	var before := _state()
	await _input_card(_panel(jury_id), true)
	_check(_state() == before and not presenter._jury.has_used_this_combat(),
		"illegal owner position refuses without spend, draw or latch")
	await _complete()


## The printed rule needs a LIVING back/middle Tinker: genuine damage downing the owner
## leaves the witnessed action inert even with printed energy and a real source.
func _downed_tinker(jury_id: String, source_id: String) -> void:
	var panel := await _mount(jury_id, [source_id], [], {jury_id: 2, source_id: 1})
	if panel == null:
		await _complete()
		return
	await _input_card(_panel(source_id), false)
	_check(presenter._jury_can_cast(jury_id), "the witnessed source arms a living back-seat Tinker")
	_check(app.party.apply_damage(3, 999) and app.party.is_downed(3)
		and not app.party.is_defeated(),
		"genuine damage downs the Tinker while the rest of the party survives")
	await _frames()
	_check(presenter._jury.preflight(app.deck, app.party, jury_id,
		presenter._jury_receipts).get("reason") == "owner_downed",
		"the accepted resolver itself reports the downed-owner refusal")
	_check(not presenter._jury_can_cast(jury_id) and _dimmed(_panel(jury_id)),
		"a downed Tinker leaves the mounted Jury-rig dim and inert")
	var before := _state()
	await _input_card(_panel(jury_id), true)
	_check(_state() == before and not presenter._jury.has_used_this_combat(),
		"downed-owner click spends, draws, discards, latches and moves the witness not at all")
	await _complete()


## A witnessed Tune Up belongs to the turn it was played in. End Turn must expire it
## instead of letting a stale copy be cast from the following hand.
func _stale_turn(jury_id: String, source_id: String) -> void:
	var panel := await _mount(jury_id, [source_id], [], {jury_id: 2, source_id: 1},
		3, 9, source_id)
	if panel == null:
		await _complete()
		return
	await _input_card(_panel(source_id), false)
	_check(presenter._jury_can_cast(jury_id), "the source arms Jury-rig inside its own turn")
	await _end(true)
	_check(app.deck.turn_active and app.deck.energy == 3 and app.deck.hand.has(jury_id),
		"the next genuine turn opened a fresh hand really holding a Jury-rig copy")
	_check(presenter._jury_receipts.size() == 1 and not presenter._jury_witness_valid()
		and not presenter._jury_can_cast(jury_id) and _dimmed(_panel(jury_id)),
		"End Turn invalidates the previous turn's witness instead of reusing it")
	var before := _state()
	await _input_card(_panel(jury_id), false)
	_check(_state() == before and not presenter._jury.has_used_this_combat(),
		"a later turn's stale Jury-rig spends, draws, discards and latches nothing")
	await _complete()


## Independent oracle for one reshuffling copy: the same authored deck and seed, driven
## with the genuine deck operations (the source draws before it discards; the paid
## Jury-rig copy pays, discards, then draws). Nothing here reads our presenter.
func _reference_copy_state(cards: Array[String], seed_value: int, source_id: String,
		jury_id: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new(cards, rng)
	deck.start_turn()
	var draw: int = int(_source_definition(source_id).get("effects", {}).get("draw", 0))
	deck.draw_extra(draw)
	deck.discard_played(source_id)
	deck.try_spend_energy(int(CombatTinkerV3JuryRigCards.CARDS[jury_id]["cost"]))
	deck.discard_played(jury_id)
	deck.draw_extra(draw)
	return [deck.hand, deck.draw_pile, deck.discard_pile, deck.energy, rng.state]


## A copied draw that must reshuffle proves the copy runs on the LIVE deck's own seeded
## RNG instead of a private or fresh generator.
func _reshuffle_draw(jury_id: String, source_id: String) -> void:
	var cards := _cards(jury_id, [source_id], [], 6)
	var seed_value := _seed_for(cards, {jury_id: 1, source_id: 1})
	_check(seed_value >= 0, "a deterministic six-card deck holds the source and a copy")
	if seed_value < 0:
		return
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 390390
	_check(app._start_battle(), "real battle UI mounts before the reshuffle fixture")
	presenter = app.get_node("LiveSupportHand")
	var panel := await _install(cards, seed_value, 3, jury_id)
	if panel == null:
		await _complete()
		return
	await _input_card(_panel(source_id), false)
	_check(app.deck.draw_pile.is_empty() and app.deck.discard_pile == [source_id],
		"the source commit leaves an empty draw pile and only the source in discard")
	_check(presenter._jury_can_cast(jury_id),
		"the witnessed copy is still admissible with no draw pile")
	var seeded: int = app.run_rng.state
	var reference := _reference_copy_state(cards, seed_value, source_id, jury_id)
	await _input_card(_panel(jury_id), true)
	_check(app.deck.hand == reference[0] and app.deck.draw_pile == reference[1]
		and app.deck.discard_pile == reference[2] and app.deck.energy == reference[3],
		"the copied draw reshuffles exactly as the same seeded live deck does")
	_check(app.run_rng.state == reference[4] and app.run_rng.state != seeded,
		"the copied draw consumes that live deck's own seeded RNG across the reshuffle")
	await _complete()


## A newer Tune Up+ must replace an older Tune Up as the copied source.
func _source_replacement(jury_id: String) -> void:
	var panel := await _mount(jury_id, SOURCE_IDS, [],
		{jury_id: 2, "tinker_tune_up": 1, "tinker_tune_up_plus": 1}, 3, 12)
	if panel == null:
		await _complete()
		return
	await _input_card(_panel("tinker_tune_up"), false)
	_check(presenter._jury_receipts.size() == 1
		and presenter._jury_receipts[0].get("card_id") == "tinker_tune_up",
		"first source is witnessed")
	await _input_card(_panel("tinker_tune_up_plus"), true)
	_check(presenter._jury_receipts.size() == 1
		and presenter._jury_receipts[0].get("card_id") == "tinker_tune_up_plus",
		"newer Tune Up+ replaces the older source")
	var before := _state()
	var piles: Array = [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate()]
	await _input_card(_panel(jury_id), true)
	var expected := _expected_draw(piles, jury_id, 2)
	_check(app.deck.hand == expected[0] and app.deck.draw_pile == expected[1]
		and app.deck.discard_pile == expected[2],
		"the copied Tune Up+ draws two, not the earlier Tune Up's one")
	_check(presenter._jury.committed_history()[0].get("card_id") == "tinker_tune_up_plus"
		and _state() != before, "accepted play records only the newer source")
	await _complete()


func _fresh_fight(jury_id: String, source_id: String) -> void:
	var panel := await _mount(jury_id, [source_id], [],
		{jury_id: 2, source_id: 1})
	if panel == null:
		await _complete()
		return
	await _input_card(_panel(source_id), false)
	await _input_card(_panel(jury_id), true)
	var prior: CombatTinkerV3JuryRigCards = presenter._jury
	_check(prior != null and prior.has_used_this_combat(),
		"first fight really owns the used once-per-combat latch")
	app._return_to_title()
	_check(app._start_battle() and app.round_flow != null,
		"a new genuine app fight mounts after Return")
	panel = await _mount_into_current(jury_id, source_id)
	_check(panel != null and presenter._jury != prior
		and not presenter._jury.has_used_this_combat()
		and presenter._jury_receipts.is_empty(),
		"new deck/battle creates a fresh empty Jury-rig service and witness")
	await _input_card(_panel(source_id), true)
	_check(presenter._jury_can_cast(jury_id), "fresh fight accepts a new verified source")
	await _input_card(_panel(jury_id), false)
	_check(presenter._jury.has_used_this_combat()
		and app.deck.energy == 3 - int(CombatTinkerV3JuryRigCards.CARDS[jury_id]["cost"]),
		"fresh fight can spend its own copy instead of reusing the old latch")
	await _complete()


## Reuse the already-mounted app after Return -> Start Battle.
func _mount_into_current(jury_id: String, source_id: String) -> Control:
	presenter = app.get_node("LiveSupportHand")
	var cards := _cards(jury_id, [source_id], [], 9)
	var seed_value := _seed_for(cards, {jury_id: 2, source_id: 1})
	_check(seed_value >= 0, "fresh fight has a deterministic Jury-rig opening")
	if seed_value < 0:
		return null
	return await _install(cards, seed_value, 3, jury_id)


## A real run's seeded opening route with a genuine Fight, so the mounted battle owns
## the carryover/wardrobe context a Switchback Button is really sewn and worn in.
func _mount_run_fight(jury_id: String, sources: Array, extras: Array,
		required: Dictionary) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 390391
	await _mouse(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	await _frames()
	_check(app.run_map != null and app.party_carryover != null
		and not app.run_heroes.is_empty(),
		"physical Start admits a real run with carryover, roster and wardrobe context")
	if app.run_map == null or app.party_carryover == null:
		return null
	var fight := ""
	for id in app.run_map.get_legal_choices():
		if app.run_map.get_node(id).get("type") == "Fight":
			fight = id
			break
	_check(not fight.is_empty(), "the seeded opening route offers an authentic Fight")
	var button: Button = null
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == fight:
			button = candidate
	_check(button != null and not button.disabled, "the opening Fight control is actionable")
	if button == null:
		return null
	await _mouse(button)
	await _frames()
	_check(app.deck != null and app.round_flow != null and app.party != null,
		"physical route choice mounts the real authored fight")
	presenter = app.get_node("LiveSupportHand")
	var cards := _cards(jury_id, sources, extras, 9)
	var seed_value := _seed_for(cards, required)
	_check(seed_value >= 0,
		"deterministic fixed hand holds Jury-rig, Tune Up and the other hero's card")
	if seed_value < 0:
		return null
	return await _install(cards, seed_value, 3, jury_id)


## Sew the authentic Switchback Button into one wearer's HEAD slot through the real
## wardrobe and carryover, then let the presenter bind it to the live Quilt service.
func _sew_switchback(wearer: String) -> bool:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	_check(raw is Array, "Switchback: the authored patch catalog parses")
	if not raw is Array:
		return false
	var definitions: Array = []
	for entry in raw:
		definitions.append({"id": entry.id, "slot": entry.slot})
	var carry := app.party_carryover as RunTornCarryover
	_check(carry != null and carry.is_valid(), "Switchback: the run carryover is valid")
	if carry == null or not carry.is_valid():
		return false
	if not app.run_trinkets.has("switchback_button"):
		app.run_trinkets.append("switchback_button")
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets, definitions,
		app.run_scraps, app.session_gold, app.run_deck, app.run_seed)
	_check(wardrobe.is_valid(), "Switchback: the admitted run wardrobe is valid")
	if not wardrobe.is_valid():
		return false
	var sewn: Dictionary = wardrobe.sew("switchback_button", wearer, "HEAD", "sew",
		wardrobe.get_snapshot())
	_check(sewn.get("ok", false), "Switchback: the real HEAD sew succeeds")
	_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()),
		"Switchback: the carryover binds the exact sewn wardrobe")
	presenter._ensure_quilt_switchback_bound()
	var active: bool = app._quilt_bonus != null and app._quilt_bonus.is_switchback_active()
	_check(active, "Switchback: the live battle's Quilt authority is switchback-active")
	return active


## The settled piles after the genuine source commit plus any automatic Quilt draw.
func _piles_after_source(piles: Array, source_id: String, draws: int) -> Array:
	var hand: Array = piles[0].duplicate()
	var draw: Array = piles[1].duplicate()
	var discard: Array = piles[2].duplicate()
	hand.erase(source_id)
	for slot in range(draws):
		if draw.is_empty():
			break
		hand.append(draw.pop_back())
	discard.append(source_id)
	return [hand, draw, discard]


## Switchback Button regression: another living hero commits, then the genuine Tune
## Up/+ is the most recent card. Its own +2 Block reward must not invalidate the
## witness, and the held affordable Jury-rig must really pay, discard and draw.
func _switchback_source(jury_id: String, source_id: String, keyboard: bool) -> void:
	var panel := await _mount_run_fight(jury_id, [source_id], ["warden_brace"],
		{jury_id: 2, source_id: 1, "warden_brace": 1})
	if panel == null:
		await _complete()
		return
	if not await _sew_switchback("tinker"):
		await _complete()
		return
	for index in range(CombatParty.PARTY_SIZE):
		app.party._heroes[index]["block"] = 0
	app._refresh_party()
	await _frames()
	var quilt: CombatQuiltBonus = app._quilt_bonus
	var clean: Dictionary = quilt.get_switchback_state()
	_check(not clean.consumed and clean.prev_owner == "",
		"Switchback fixture starts unconsumed with no previous owner")
	# A different living hero really commits first.
	await _input_card(_panel("warden_brace"), not keyboard)
	_check(app.party.get_hero(1).block == 7 and app.party.get_hero(3).block == 0,
		"the other hero's committed Brace grants its printed Block only")
	var after_other: Dictionary = quilt.get_switchback_state()
	_check(not after_other.consumed and after_other.prev_owner == "warden",
		"the other hero's commit arms the different-owner transition")
	# Then the genuine Tune Up/+ is the most recent committed card.
	var cost: int = int(CombatTinkerV3JuryRigCards.CARDS[jury_id]["cost"])
	var source_draw: int = int(StarterCards.new().get_definition(source_id).get("effects", {}).get("draw", 0))
	var piles: Array = [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate()]
	await _input_card(_panel(source_id), keyboard)
	var sw: Dictionary = quilt.get_switchback_state()
	_check(sw.consumed and sw.prev_owner == "tinker",
		"Switchback consumed the different-owner transition on the source commit")
	_check(app.party.get_hero(3).block == 2,
		"the Tinker gained exactly 2 Switchback Block after the genuine Tune Up")
	var expected := _piles_after_source(piles, source_id, source_draw)
	_check(app.deck.hand == expected[0] and app.deck.draw_pile == expected[1]
		and app.deck.discard_pile == expected[2],
		"the source still draws exactly its printed amount from the live deck")
	_check(presenter._jury_receipts.size() == 1
		and presenter._jury_receipts[0].get("card_id") == source_id
		and presenter._jury.committed_history().is_empty(),
		"only the genuine Tune Up receipt is witnessed; no phantom previous play")
	_check(presenter._jury_witness_valid()
		and presenter._jury_witness.get("state") == presenter._jury_state(),
		"the witness is finalized onto the settled post-Switchback deck and party")
	_check(presenter._jury_can_cast(jury_id),
		"the held affordable Jury-rig remains actionable after the automatic Block")
	var armed_panel := _panel(jury_id)
	_check(armed_panel != null
		and bool(presenter._metadata.visual_state(armed_panel).get("playable", false))
		and _bright(armed_panel),
		"the mounted Jury-rig face refreshes to playable at full colour")
	# Cancel in this post-reward state must stay inert.
	var armed := _state()
	await _hover(armed_panel)
	_check(_state() == armed, "hovering the post-reward armed Jury-rig changes no state")
	var point := await _press_at(armed_panel)
	_check(presenter._pending.get("id") == jury_id and presenter._jury_selection_valid(),
		"selection still snapshots the exact settled deck, battle and witness")
	await _keyboard(KEY_ESCAPE)
	_check(presenter._pending.is_empty() and _state() == armed,
		"cancel after the automatic reward spends, draws, latches and rebases nothing")
	await _release_at(point)
	_check(_state() == armed, "the cancelled press cannot replay the selection")
	# The paid copy runs from the settled live deck.
	var before: Array = [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate()]
	var deck_rng: int = app.run_rng.state
	await _input_card(_panel(jury_id), keyboard)
	var copy := _expected_draw([before[0], before[1], before[2]], jury_id, source_draw)
	_check(app.deck.hand == copy[0] and app.deck.draw_pile == copy[1]
		and app.deck.discard_pile == copy[2],
		"the paid copy draws exactly the source's printed amount from the live deck")
	_check(app.deck.energy == 3 - 1 - cost and app.deck.hand.count(jury_id) == 1,
		"exactly one printed cost is paid after the other hero's card and no more")
	_check(app.deck.discard_pile.count(source_id) == 1,
		"the source card is never paid for or discarded a second time")
	_check(app.run_rng.state == deck_rng,
		"the live seeded RNG is untouched when no reshuffle is needed")
	_check(presenter._jury.has_used_this_combat()
		and presenter._jury.committed_history().size() == 1
		and presenter._jury.committed_history()[0].get("card_id") == source_id,
		"the accepted play sets the latch and records only the genuine source")
	_check(presenter._jury_receipts.is_empty(),
		"the presenter consumes the witness after the paid copy")
	var second := _panel(jury_id)
	var locked := _state()
	await _input_card(second, not keyboard)
	_check(_state() == locked and app.deck.energy == 3 - 1 - cost,
		"the second held copy refuses without any further spend, draw or latch")
	await _complete()


## Third distinct living hero: the Quilt's own Block/draw reward lands after the Tune
## Up commit and must not leave the witnessed copy phantom or a second source charge.
func _quilt_third_source(jury_id: String, source_id: String, keyboard: bool) -> void:
	var panel := await _mount(jury_id, [source_id],
		["warden_brace", "seamstress_stitch_up"],
		{jury_id: 2, source_id: 1, "warden_brace": 1, "seamstress_stitch_up": 1})
	if panel == null:
		await _complete()
		return
	for index in range(CombatParty.PARTY_SIZE):
		app.party._heroes[index]["block"] = 0
	app.deck.combat_state.energy = 5
	app._refresh_party()
	app._refresh_hand()
	await _frames()
	_check(app.deck.energy == 5 and app.deck.hand.count(jury_id) == 2
		and app.deck.hand.has(source_id) and app.deck.hand.has("warden_brace")
		and app.deck.hand.has("seamstress_stitch_up"),
		"fixture holds both Jury copies, the source and two other living heroes' cards")
	# Warden and Seamstress each really commit one card.
	await _input_card(_panel("warden_brace"), not keyboard)
	await _input_card(_panel("seamstress_stitch_up"), not keyboard)
	_check(presenter._pending.get("choosing", false),
		"the Seamstress ally card is genuinely waiting for its living target")
	await _mouse(app.hero_panels[0])
	await _frames()
	_check(app.deck.discard_pile.count("seamstress_stitch_up") == 1
		and app.party.get_hero(1).block == 12,
		"two distinct living heroes committed: printed Brace and Stitch Block")
	var quilt: CombatQuiltBonus = app._quilt_bonus
	var progress: Dictionary = quilt.get_patch_progress()
	_check(not progress.awarded and progress.patches.warden.played
		and progress.patches.seamstress.played and not progress.patches.tinker.played,
		"two of the three living owners are recorded before the source")
	# The Tinker's Tune Up is the third distinct living hero play.
	var cost: int = int(CombatTinkerV3JuryRigCards.CARDS[jury_id]["cost"])
	var source_draw: int = int(StarterCards.new().get_definition(source_id).get("effects", {}).get("draw", 0))
	var piles: Array = [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate()]
	await _input_card(_panel(source_id), keyboard)
	var awarded: Dictionary = quilt.get_patch_progress()
	_check(awarded.awarded and awarded.patches.tinker.played,
		"the Tune Up completed the third distinct living hero play")
	_check(app.party.get_hero(1).block == 15 and app.party.get_hero(2).block == 3
		and app.party.get_hero(3).block == 3,
		"the Quilt really awarded its 3 Block to every living hero after the commit")
	var expected := _piles_after_source(piles, source_id, source_draw + 1)
	_check(app.deck.hand == expected[0] and app.deck.draw_pile == expected[1]
		and app.deck.discard_pile == expected[2],
		"the source draw and the Quilt draw both settled against the live deck")
	_check(presenter._jury_receipts.size() == 1
		and presenter._jury_receipts[0].get("card_id") == source_id
		and presenter._jury.committed_history().is_empty(),
		"the Quilt reward invents no phantom previous-play receipt")
	_check(presenter._jury_witness_valid()
		and presenter._jury_witness.get("state") == presenter._jury_state(),
		"the witness is finalized onto the settled post-Quilt deck and party")
	_check(presenter._jury_can_cast(jury_id),
		"the held affordable Jury-rig remains actionable after the Quilt reward")
	var armed_panel := _panel(jury_id)
	_check(armed_panel != null
		and bool(presenter._metadata.visual_state(armed_panel).get("playable", false))
		and _bright(armed_panel),
		"the mounted Jury-rig face is playable at full colour after the Quilt reward")
	var armed := _state()
	await _hover(armed_panel)
	_check(_state() == armed, "previewing the post-Quilt armed Jury-rig changes no state")
	var before: Array = [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate()]
	await _input_card(_panel(jury_id), keyboard)
	var copy := _expected_draw([before[0], before[1], before[2]], jury_id, source_draw)
	_check(app.deck.hand == copy[0] and app.deck.draw_pile == copy[1]
		and app.deck.discard_pile == copy[2],
		"the paid copy draws exactly the source's printed amount from the live deck")
	_check(app.deck.energy == 5 - 1 - 1 - cost and app.deck.discard_pile.count(source_id) == 1
		and app.deck.hand.count(source_id) == 0,
		"exactly the printed Jury-rig cost is paid, with no second source charge")
	_check(presenter._jury.has_used_this_combat()
		and presenter._jury.committed_history().size() == 1
		and presenter._jury.committed_history()[0].get("card_id") == source_id,
		"the accepted play latches once and records only the genuine source")
	await _complete()


## AC1: a genuine Spare Parts/+ commit is the last-play source and the paid Jury-rig
## resolves exactly one free copy: the source's printed Block on the living Tinker plus
## one draw, with no second source card, payment or scrap transaction.
func _spare_parts_case(jury_id: String, source_id: String, keyboard: bool,
		tinker_seat: int = 3) -> Array:
	var panel := await _mount(jury_id, [source_id], [],
		{jury_id: 2, source_id: 1}, tinker_seat)
	if panel == null:
		await _complete()
		return []
	var source_face: Dictionary = _source_definition(source_id)
	var source_block: int = int(source_face.get("effects", {}).get("block", 0))
	var source_draw: int = int(source_face.get("effects", {}).get("draw", 0))
	var cost: int = int(CombatTinkerV3JuryRigCards.CARDS[jury_id]["cost"])
	_check(source_face.get("cost") == 0 and source_face.get("target_kind") == "self" \
		and source_face.get("from_positions") == [2, 3] \
		and source_face.get("to_positions") == [] and source_draw == 1 \
		and source_block == (3 if source_id == "tinker_spare_parts" else 4),
		"authentic Spare Parts printing is 0-cost, FROM 2-3, self, with its exact Block and draw")
	_check(app.deck.energy == 3 and app.party.get_hero(tinker_seat).id == "tinker",
		"fixture has printed energy and a living Tinker at the required seat")
	_check(not presenter._jury_can_cast(jury_id) and _dimmed(_panel(jury_id)),
		"before any source the mounted Jury-rig is truthfully disabled and drawn dim")
	var source_panel := _panel(source_id)
	_check(source_panel != null, "Spare Parts is genuinely held before play")
	await _input_card(source_panel, keyboard)
	_check(not app.deck.hand.has(source_id) and app.deck.discard_pile.count(source_id) == 1,
		"the real Spare Parts play committed exactly one held copy to the discard")
	_check(app.party.get_hero(tinker_seat).block == source_block,
		"the real Spare Parts play grants only its printed Block to the living Tinker")
	_check(presenter._jury_receipts.size() == 1 \
		and presenter._jury_receipts[0].get("card_id") == source_id \
		and presenter._jury_receipts[0].get("from_positions") == [2, 3] \
		and presenter._jury_receipts[0].get("target_kind") == "self",
		"the presenter witnessed only the genuine committed Spare Parts source")
	_check(presenter._jury_witness_valid() and presenter._jury_can_cast(jury_id),
		"living Tinker, energy and the Spare Parts source admit Jury-rig")
	var armed_panel := _panel(jury_id)
	_check(armed_panel != null \
		and bool(presenter._metadata.visual_state(armed_panel).get("playable", false)) \
		and _bright(armed_panel),
		"mounted Jury-rig face becomes playable at full colour after the Spare Parts commit")
	var others: Dictionary = {}
	for seat in [1, 2, 3]:
		if seat != tinker_seat:
			others[seat] = app.party.get_hero(seat).block
	var armed := _state()
	await _hover(armed_panel)
	_check(_state() == armed, "hovering the armed Jury-rig changes no state")
	var point := await _press_at(armed_panel)
	_check(presenter._pending.get("id") == jury_id and presenter._jury_selection_valid(),
		"real mouse press snapshots the exact deck, battle and Spare Parts witness")
	_check(_state() == armed, "selecting Jury-rig spends, draws, blocks and latches nothing")
	await _keyboard(KEY_ESCAPE)
	_check(presenter._pending.is_empty() and _state() == armed,
		"Cancel leaves the Spare Parts witness, piles, Block, RNG and latch unchanged")
	await _release_at(point)
	_check(_state() == armed, "releasing the cancelled press cannot replay the selection")
	var before: Array = [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate(), app.run_rng.state]
	var block_before: int = app.party.get_hero(tinker_seat).block
	_check(app.deck.draw_pile.size() >= source_draw,
		"fixture keeps enough live cards for the copied draw")
	await _input_card(_panel(jury_id), keyboard)
	var expected := _expected_draw([before[0], before[1], before[2]], jury_id, source_draw)
	_check(app.deck.hand == expected[0] and app.deck.draw_pile == expected[1]
		and app.deck.discard_pile == expected[2],
		"the free copy draws exactly one from the live deck and discards only the held Jury-rig")
	_check(app.party.get_hero(tinker_seat).block == block_before + source_block,
		"the free copy grants exactly the printed Block once more on the living Tinker")
	var untouched := true
	for seat in others:
		if app.party.get_hero(seat).block != others[seat]:
			untouched = false
	_check(untouched, "no other hero's Block changes for the self-targeted Spare Parts copy")
	_check(app.deck.energy == 3 - cost and app.deck.hand.count(jury_id) == 1,
		"exactly one printed Jury-rig cost is paid and one held copy is discarded")
	_check(app.deck.discard_pile.count(source_id) == 1 and not app.deck.hand.has(source_id),
		"the source card is never paid for, replayed or discarded a second time")
	_check(app.run_rng.state == before[3],
		"the live deck's seeded RNG is untouched when no reshuffle is needed")
	_check(presenter._jury.has_used_this_combat()
		and presenter._jury.committed_history().size() == 1
		and presenter._jury.committed_history()[0].get("card_id") == source_id,
		"accepted play latches once and records only the genuine Spare Parts source")
	_check(presenter._jury_receipts.is_empty(),
		"the presenter consumes the witness after the paid copy")
	var second := _panel(jury_id)
	var locked := _state()
	var locked_block: int = app.party.get_hero(tinker_seat).block
	await _input_card(second, not keyboard)
	_check(_state() == locked and app.deck.energy == 3 - cost \
		and app.party.get_hero(tinker_seat).block == locked_block,
		"a second held Jury-rig spends, draws, blocks or latches nothing more")
	var trace := _state()
	await _complete()
	return trace


## Another real committed card replaces the Spare Parts witness, so Jury-rig disables
## instead of copying an older Block/draw.
func _spare_parts_unsupported(jury_id: String, source_id: String, keyboard: bool) -> void:
	var panel := await _mount(jury_id, [source_id], ["warden_brace"],
		{jury_id: 2, source_id: 1, "warden_brace": 1})
	if panel == null:
		await _complete()
		return
	await _input_card(_panel(source_id), keyboard)
	_check(presenter._jury_can_cast(jury_id), "the genuine Spare Parts source briefly arms Jury-rig")
	var tinker_block: int = app.party.get_hero(3).block
	await _input_card(_panel("warden_brace"), not keyboard)
	_check(app.deck.discard_pile.count("warden_brace") == 1
		and presenter._jury_receipts.is_empty(),
		"a later real committed card replaces the Spare Parts witness")
	_check(not presenter._jury_can_cast(jury_id)
		and not presenter._metadata.visual_state(_panel(jury_id)).get("playable", false)
		and _dimmed(_panel(jury_id)),
		"an unsupported preceding card leaves Jury-rig truthfully disabled and drawn dim")
	var before := _state()
	await _input_card(_panel(jury_id), keyboard)
	_check(_state() == before and not presenter._jury.has_used_this_combat()
		and app.party.get_hero(3).block == tinker_block,
		"the disabled Jury-rig copies no Spare Parts Block, draw or spend")
	await _complete()


## A Spare Parts witness belongs to the turn it was played in: End Turn expires it.
func _spare_parts_stale_turn(jury_id: String, source_id: String) -> void:
	var panel := await _mount(jury_id, [source_id], [], {jury_id: 2, source_id: 1},
		3, 9, source_id)
	if panel == null:
		await _complete()
		return
	await _input_card(_panel(source_id), false)
	_check(presenter._jury_can_cast(jury_id),
		"the Spare Parts source arms Jury-rig inside its own turn")
	await _end(true)
	_check(app.deck.turn_active and app.deck.energy == 3 and app.deck.hand.has(jury_id),
		"the next genuine turn opened a fresh hand really holding a Jury-rig copy")
	_check(presenter._jury_receipts.size() == 1 and not presenter._jury_witness_valid()
		and not presenter._jury_can_cast(jury_id) and _dimmed(_panel(jury_id)),
		"End Turn invalidates the previous turn's Spare Parts witness instead of reusing it")
	var before := _state()
	var block_now: int = app.party.get_hero(3).block
	await _input_card(_panel(jury_id), false)
	_check(_state() == before and not presenter._jury.has_used_this_combat()
		and app.party.get_hero(3).block == block_now,
		"a later turn's stale Jury-rig copies no Spare Parts Block, draw or spend")
	await _complete()


## A genuinely printed but unsupported Tinker card is never accepted as a copy source,
## even when a forged receipt and witness are handed to the presenter directly.
func _forged_spare_parts_source(jury_id: String) -> void:
	var panel := await _mount(jury_id, ["tinker_spare_parts"], [],
		{jury_id: 2, "tinker_spare_parts": 1})
	if panel == null:
		await _complete()
		return
	_check(not presenter._play_jury_rig(app.deck, app.party, jury_id),
		"Jury-rig cannot mint a copy without any witnessed source")
	var forged: Dictionary = {"ok": true, "card_id": "tinker_long_barrel", "owner": "tinker",
		"from_positions": [3], "to_positions": [1, 2, 3], "target_kind": "enemy_single"}
	presenter._jury_receipts.clear()
	presenter._jury_receipts.append(forged)
	presenter._jury_witness = {"receipt": forged.duplicate(true), "state": presenter._jury_state()}
	_check(not presenter._jury_witness_valid() and not presenter._jury_can_cast(jury_id)
		and _dimmed(_panel(jury_id)),
		"a forged receipt naming a real but unsupported card never witnesses a copy")
	var before := _state()
	_check(not presenter._play_jury_rig(app.deck, app.party, jury_id) and _state() == before
		and not presenter._jury.has_used_this_combat(),
		"the forged source charges, blocks, draws and latches nothing")
	await _complete()



func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	for jury_id in JURY_IDS:
		for source_id in SOURCE_IDS:
			var mouse: Array = await _case(jury_id, source_id, false)
			var keyboard: Array = await _case(jury_id, source_id, true)
			_check(not mouse.is_empty() and mouse == keyboard,
				"same-seed mouse/keyboard exact post-play state and RNG: %s + %s" % [jury_id, source_id])
		# The middle seat is an authored source seat too.
		var back: Array = await _case(jury_id, "tinker_tune_up", false, 3)
		var middle: Array = await _case(jury_id, "tinker_tune_up", true, 2)
		_check(not back.is_empty() and not middle.is_empty(),
			"living back and middle Tinker can each cast " + jury_id)
		await _unsupported_source(jury_id, "tinker_tune_up", false)
		await _stale_deferred(jury_id, "tinker_tune_up")
		await _jury_refusals(jury_id, "tinker_tune_up_plus")
		await _insufficient_energy(jury_id, "tinker_tune_up")
		await _front_tinker_refusal(jury_id, "tinker_tune_up")
		await _downed_tinker(jury_id, "tinker_tune_up")
		await _stale_turn(jury_id, "tinker_tune_up")
		await _source_replacement(jury_id)
		await _reshuffle_draw(jury_id, "tinker_tune_up")
		await _fresh_fight(jury_id, "tinker_tune_up_plus")
		# V3-1: Spare Parts/+ are supported last-play sources too.
		for spare_id in SPARE_IDS:
			var spare_mouse: Array = await _spare_parts_case(jury_id, spare_id, false)
			var spare_keyboard: Array = await _spare_parts_case(jury_id, spare_id, true)
			_check(not spare_mouse.is_empty() and spare_mouse == spare_keyboard,
				"same-seed mouse/keyboard exact Spare Parts copy state and RNG: %s + %s" % [jury_id, spare_id])
		var spare_middle: Array = await _spare_parts_case(jury_id, "tinker_spare_parts_plus", true, 2)
		_check(not spare_middle.is_empty(),
			"living middle Tinker can copy Spare Parts+ with " + jury_id)
		await _spare_parts_unsupported(jury_id, "tinker_spare_parts", false)
		await _spare_parts_stale_turn(jury_id, "tinker_spare_parts")
		await _insufficient_energy(jury_id, "tinker_spare_parts")
		await _downed_tinker(jury_id, "tinker_spare_parts")
		await _forged_spare_parts_source(jury_id)
		await _reshuffle_draw(jury_id, "tinker_spare_parts")
	# The source's own automatic combat rewards settle after its commit snapshot.
	await _switchback_source("tinker_v3_jury_rig", "tinker_tune_up", false)
	await _switchback_source("tinker_v3_jury_rig_plus", "tinker_tune_up_plus", true)
	for jury_id in JURY_IDS:
		await _quilt_third_source(jury_id, "tinker_tune_up",
			jury_id == "tinker_v3_jury_rig_plus")
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_tinker_v3_jury_rig_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
