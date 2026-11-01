extends "res://tests/live_support_hand_test.gd"
## Rag Duelist cape self-Dodge cards played from the REAL shared support hand (V3-1).
##
## Every case starts a genuine seeded app battle, installs a real CombatDeck draw that
## holds authentic copies of the printed card and seats a living Rag Duelist in one of
## the three authored FROM seats. The mounted panel is clicked or keyboard-activated
## through LiveSupportHand (the older battle-scoped adapter must bind NONE of these),
## and the shipped paid resolver charges the printed cost (1, or 0 for the '+'), discards
## exactly one held copy and keeps the owner's one-shot integer Dodge at 1.
##
## The face and hover help come from the very catalog record that resolver authenticates.
## The real CombatWardenGuardReactions then spends that Dodge on the next genuine incoming
## attack with no HP/Block damage, and the real CombatStatusTurnBatch owner-turn boundary
## expires an unused token. Every refusal, stale callback and replay leaves deck, party,
## enemies, intents, result, wallet and RNG byte-identical.

const IDS := ["rag_duelist_cape_slip", "rag_duelist_cape_slip_plus",
	"rag_duelist_cape_flourish", "rag_duelist_cape_flourish_plus"]
const DODGE := "dodge_next_attack"


func _catalog(id: String) -> Dictionary:
	var starter := RagDuelistStarterCards.new().get_definition(id)
	return starter if not starter.is_empty() else RagDuelistPoolCards.new().get_definition(id)


func _title(id: String) -> String:
	return str(_catalog(id).get("display_name", id))


func _cost(id: String) -> int:
	return int(_catalog(id).get("cost", -1))


## The real mounted app battle with a genuine five-card draw that holds `copies`
## authentic printings and a living Rag Duelist in `seat`.
func _begin(id: String, seat: int = 2, energy: int = 3, copies: int = 2) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	_check(app.deck == null, "the title screen precedes the cape battle: " + id)
	app.run_seed = 4247
	_check(app._start_battle(), "the shipped App admits a real standalone battle: " + id)
	presenter = app.get_node_or_null("LiveSupportHand")
	var legacy = app.get_node_or_null("LiveRagDuelistRiposteHand")
	_check(presenter != null and legacy != null,
		"the shared hand and the older battle-scoped adapter are both mounted")
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_rng.seed
	var cards: Array[String] = [id, "warden_strike", "seamstress_prick", "tinker_tune_up"]
	cards.append(id if copies == 2 else "warden_brace")
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.size() == 5
		and app.deck.hand.count(id) == copies,
		"a genuine five-card draw holds the authentic cape copies: " + id)
	app.deck.combat_state.energy = energy
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, {"id": "rag_duelist", "name": "Rag Duelist", "max_hp": 32})
	app.party = CombatParty.new(heroes)
	_check(app.party.is_valid() and app.party.get_hero(seat).get("id") == "rag_duelist"
		and int(app.party.get_hero(seat).get("hp")) == 32 and app.enemies.is_valid(),
		"a living Rag Duelist really sits in authored seat %d beside a real enemy roster" % seat)
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
		"the older battle-scoped adapter yields these IDs to the shared hand: " + id)
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
	var starter := id.begins_with("rag_duelist_cape_slip")
	_check(not catalog.is_empty() and catalog.get("id") == id
		and catalog.get("owner") == "rag_duelist" and int(catalog.get("cost")) == _cost(id)
		and catalog.get("target_kind") == "self"
		and catalog.get("from_positions") == [1, 2, 3]
		and (catalog.get("to_positions", []) as Array).is_empty()
		and catalog.get("effects") == {DODGE: 1, "duration": 1}
		and int(catalog.get("starting_copies", -1)) == (1 if starter and not id.ends_with("_plus") else 0)
		and bool(catalog.get("reward_eligible")) == (not starter and not id.ends_with("_plus")),
		"the authored catalog record really is this printing: " + id)
	_check(meta.definition(id) == catalog, "the drawn face is that authentic catalog record: " + id)
	_check(facts.get("known") == true and facts.get("display_name") == catalog.get("display_name")
		and int(facts.get("cost")) == _cost(id) and facts.get("owner") == "rag_duelist"
		and facts.get("from_text") == "From " + meta._positions([1, 2, 3])
		and facts.get("target_text") == "Self",
		"the face prints the authentic name, owner, cost and self target: " + id)
	var short: String = meta.short_line(id)
	_check(short.contains("Dodge the next attack") and short.contains("expires"),
		"the face prints the one-shot Dodge and its turn-end expiry: " + id)
	var help: String = panel.tooltip_text
	_check(help.contains(_title(id)) and help.contains("Rag Duelist")
		and help.contains("%d energy" % _cost(id)) and help.contains("To self")
		and help.contains("Dodge the next attack") and help.contains("one-shot")
		and help.contains("expires") and help.contains("No target choice"),
		"the hover help states the printed cost, self target and one-shot Dodge: " + id)
	_check(panel.tooltip_text.contains("Click or focus and press Enter / Space to play"),
		"the mounted hand keeps its real playable-card help: " + id)
	_check(bool(meta.visual_state(panel).get("playable", false))
		and presenter.rag_duelist_cape_actionable(panel, id),
		"the face is enabled only by the shared hand's own paid admission: " + id)


func _cape_expected(before: Array, id: String, seat: int) -> Array:
	var after: Array = before.duplicate(true)
	after[1].erase(id)
	after[2].append(id)
	after[3] = int(after[3]) - _cost(id)
	var owner: Dictionary = after[5][seat - 1]
	if not owner.has("statuses") or not owner["statuses"] is Dictionary:
		owner["statuses"] = {}
	var statuses: Dictionary = (owner["statuses"] as Dictionary).duplicate(true)
	statuses[DODGE] = 1
	owner["statuses"] = statuses
	after[5][seat - 1] = owner
	return after


## The next genuine incoming attack spends the one-shot Dodge with no damage; a
## following real attack lands, proving the token really was one-shot.
func _consume_attack(seat: int) -> bool:
	_check(app.party.gain_block(seat, 2), "nonzero pre-existing Block prerequisite")
	var before := _pool_state()
	var hp: int = int(app.party.get_hero(seat).get("hp"))
	var block: int = int(app.party.get_hero(seat).get("block"))
	var reactions := CombatWardenGuardReactions.new()
	var receipt: Dictionary = reactions.resolve_enemy_attack(app.party, app.enemies,
		{"type": "attack", "enemy_position": 1, "target_position": seat, "amount": 99})
	var expected: Array = before.duplicate(true)
	expected[5][seat - 1]["statuses"].erase(DODGE)
	var missed: bool = receipt.get("ok", false) and not bool(receipt.get("applied", true)) \
		and _pool_state() == expected \
		and int(app.party.get_hero(seat).get("hp")) == hp \
		and int(app.party.get_hero(seat).get("block")) == block
	var landing: Dictionary = reactions.resolve_enemy_attack(app.party, app.enemies,
		{"type": "attack", "enemy_position": 1, "target_position": seat, "amount": 1})
	return missed and landing.get("ok", false) and bool(landing.get("applied", false)) \
		and int(app.party.get_hero(seat).get("hp")) == hp \
		and int(app.party.get_hero(seat).get("block")) == block - 1


## An unused one-turn token disappears at the SAME owner-turn boundary CombatRoundFlow
## commits, while an unrelated hero's Bleed still ticks. No HP or Block is lost to the
## expiry itself, and a later real attack is no longer dodged.
func _expire_unused(seat: int) -> bool:
	var other := 1 if seat != 1 else 2
	app.party._heroes[other - 1]["statuses"] = {"bleed": 2}
	var batch := CombatStatusTurnBatch.new()
	var tick: Dictionary = batch.tick_side("heroes", app.party.get_heroes())
	if not tick.get("ok", false):
		return false
	var owner: Dictionary = tick["actors"][seat - 1]
	var bled: Dictionary = tick["actors"][other - 1]
	var expired: bool = not (owner["statuses"] as Dictionary).has(DODGE)
	var kept_hp: bool = int(owner["hp"]) == int(app.party.get_hero(seat).get("hp")) \
		and int(owner["block"]) == int(app.party.get_hero(seat).get("block"))
	var bled_out: bool = int(bled["statuses"].get("bleed", 0)) == 1 \
		and int(bled["hp"]) == int(app.party.get_hero(other).get("hp")) - 2
	# Commit exactly the fields CombatRoundFlow writes for an accepted owner tick.
	for index in range(3):
		app.party._heroes[index]["hp"] = int(tick["actors"][index]["hp"])
		app.party._heroes[index]["block"] = int(tick["actors"][index]["block"])
		app.party._heroes[index]["statuses"] = (tick["actors"][index]["statuses"] as Dictionary).duplicate(true)
	app._refresh_party()
	var hp: int = int(app.party.get_hero(seat).get("hp"))
	var receipt: Dictionary = CombatWardenGuardReactions.new().resolve_enemy_attack(
		app.party, app.enemies, {"type": "attack", "enemy_position": 1, "target_position": seat, "amount": 1})
	return expired and kept_hp and bled_out and receipt.get("ok", false) \
		and bool(receipt.get("applied", false)) and int(app.party.get_hero(seat).get("hp")) == hp - 1


func _success(id: String, seat: int, keyboard: bool, consume: bool = false,
		expire: bool = false) -> void:
	var panel := await _begin(id, seat, _cost(id), 2)
	if panel == null:
		_check(false, "the cape success fixture must start a real mounted battle")
		await _dispose()
		return
	_face(id, panel)
	var card_callback: Callable = presenter._bindings[panel]
	var before := _pool_state()
	if keyboard:
		panel.grab_focus()
		_check(panel.has_focus(), "the drawn card is really keyboard-focused")
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	var expected := _cape_expected(before, id, seat)
	_check(_pool_state() == expected,
		"exact printed cost, exactly one discarded copy and only the owner's integer Dodge; every other actor, enemy, intent, wallet and RNG unchanged: " + id)
	_check(app.deck.energy == int(before[3]) - _cost(id),
		"the printed %d energy really paid: %s" % [_cost(id), id])
	_check(app.deck.hand.count(id) == int(before[1].count(id)) - 1
		and app.deck.discard_pile.count(id) == int(before[2].count(id)) + 1,
		"exactly one held copy is discarded: " + id)
	var owner: Dictionary = app.party.get_hero(seat)
	_check(typeof((owner.get("statuses", {}) as Dictionary).get(DODGE, 0)) == TYPE_INT
		and int((owner.get("statuses", {}) as Dictionary).get(DODGE, 0)) == 1,
		"the owner carries exactly one integer Dodge token, never two: " + id)
	for other in range(1, 4):
		if other == seat:
			continue
		_check(app.party.get_hero(other) == before[5][other - 1],
			"every other hero is untouched: " + id)
	_check(presenter._pending.is_empty() and presenter._targets.is_empty()
		and not is_instance_valid(presenter.cleanse_choices)
		and not presenter.cancel_button.is_visible_in_tree(),
		"the paid commit never opened or left a target choice: " + id)
	_check(app.end_turn_button.has_focus(), "a successful cape restores End Turn focus: " + id)
	_check(presenter.energy_label.text == str(app.deck.energy)
		and app.pile_label.text.contains("Discard: %d" % app.deck.discard_pile.size()),
		"the sewn energy and pile HUD really refresh: " + id)
	_check(app.hero_panels[seat - 1].get_child(0).text.contains("Block: %d" % int(owner.get("block", -1))),
		"the owner's real HUD refreshes: " + id)
	card_callback.call(_press())
	await _frames()
	_check(_pool_state() == expected, "the retired card callback cannot replay the charge: " + id)
	if consume:
		_check(_consume_attack(seat),
			"the genuine next incoming attack spends only Dodge and deals no damage; the next one lands: " + id)
	if expire:
		_check(_expire_unused(seat),
			"an unused one-turn Dodge expires at the owner-turn boundary without damage: " + id)
	await _dispose()


## Two authentic copies drawn into one battle: a pre-armed Dodge stays at exactly 1,
## each cast pays its own printed cost once and neither retired callback can replay.
func _refresh(id: String) -> void:
	var panel := await _begin(id, 2, 2, 2)
	if panel == null:
		_check(false, "the cape refresh fixture must start a real mounted battle")
		await _dispose()
		return
	app.party._heroes[1]["statuses"] = {DODGE: 1}
	app._refresh_party()
	await _frames()
	panel = _pool_panel(id)
	_check(panel != null and presenter._bindings.has(panel), "the drawn copy stays mounted")
	if panel == null:
		await _dispose()
		return
	_check(bool(presenter._metadata.visual_state(panel).get("playable", false)),
		"an already-armed Dodge remains playable: " + id)
	var stale: Callable = presenter._bindings[panel]
	var before := _pool_state()
	await _mouse(panel)
	var after_first := _cape_expected(before, id, 2)
	_check(_pool_state() == after_first, "the first of two copies pays exactly once: " + id)
	_check(int(app.party.get_hero(2).statuses.get(DODGE, 0)) == 1,
		"re-casting keeps an armed Dodge at 1, never a second stack: " + id)
	var surviving := _pool_panel(id)
	_check(surviving != null and surviving != panel and presenter._bindings.has(surviving)
		and surviving.gui_input.get_connections().size() == 1,
		"the surviving genuine copy is rebound with one input owner: " + id)
	stale.call(_press())
	await _frames()
	_check(_pool_state() == after_first, "the retired first copy cannot pay a second time: " + id)
	if surviving == null:
		await _dispose()
		return
	await _mouse(surviving)
	var after_second := _cape_expected(after_first, id, 2)
	_check(_pool_state() == after_second, "the second copy pays its own printed effect exactly once: " + id)
	_check(app.deck.energy == int(before[3]) - _cost(id) * 2,
		"two genuine casts really spend their printed costs: " + id)
	_check(app.deck.discard_pile.count(id) == int(before[2].count(id)) + 2
		and not app.deck.hand.has(id), "both genuine copies are discarded exactly once: " + id)
	_check(int(app.party.get_hero(2).statuses.get(DODGE, 0)) == 1,
		"two casts still leave exactly one Dodge token: " + id)
	await _dispose()


## With the real panel still mounted, a downed/missing owner, an unheld copy, a short
## wallet, a closed/turned-away battle, a forged hand or label and a replaced receipt
## cannot even arm the shared hand, and a stale callback cannot spend afterwards.
func _refuse(mode: String) -> void:
	var id: String = IDS[0]
	var panel := await _begin(id, 2, 1)
	if panel == null:
		await _dispose()
		return
	var stale: Callable = presenter._bindings[panel]
	match mode:
		"downed": _check(app.party.apply_damage(2, 9999) and app.party.is_downed(2),
			"the Duelist is genuinely torn before input")
		"missing": app.party._heroes[1]["id"] = "missing_duelist"
		"absent": _check(app.deck.discard_played(id), "the real held copy is removed before input")
		"energy": app.deck.combat_state.energy = 0
		"turn": app.deck.combat_state.player_turn_active = false
		"closed": app._battle_closed = true
		"forged": app.deck.hand[panel.get_index()] = "forged_cape"
		"label": panel.get_child(0).text = IDS[1]
		"receipt": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"stale": app._refresh_hand()
	app._refresh_party()
	app._refresh_intents()
	await _frames()
	var before := _pool_state()
	if mode == "stale":
		stale.call(_press())
	else:
		await _mouse(panel)
	_check(_pool_state() == before and presenter._pending.is_empty()
		and presenter._targets.is_empty() and not is_instance_valid(presenter.cleanse_choices),
		"a refused cape never stages or spends anything: " + mode)
	if mode != "stale":
		_check(panel.gui_input.get_connections().size() <= 1,
			"the refusal keeps at most the one real input owner: " + mode)
		_check(not bool(presenter._metadata.visual_state(panel).get("playable", false)),
			"the refused face is drawn dim rather than enabled: " + mode)
	stale.call(_press())
	await _frames()
	_check(_pool_state() == before, "a stale or replayed cape callback cannot spend: " + mode)
	await _dispose()


## A real queued intent that becomes stale (energy, turn, closed fight, replaced
## receipt, party or hand, rebuilt panels, Escape or Cancel) must never commit, and
## the same drawn copy still plays normally after a real cancel.
func _stale(mode: String) -> void:
	var id: String = IDS[1]
	var panel := await _begin(id, 2, 0, 2)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel]
	var bound: Array = presenter._bindings[panel].get_bound_arguments()
	callback.call(_press())
	_check(not presenter._pending.is_empty(), "a real target-free cape intent exists: " + mode)
	if presenter._pending.is_empty():
		await _dispose()
		return
	var token: int = presenter._token
	match mode:
		"energy": app.deck.combat_state.energy = -1
		"turn": app.enemy_intents.advance_turn()
		"closed": app._battle_closed = true
		"receipt": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"party": app.party = CombatParty.new(app.party.get_heroes())
		"hand":
			var other := ""
			for held in app.deck.hand:
				if held != id:
					other = held
					break
			_check(not other.is_empty() and app.deck.discard_played(other),
				"the shared hand really changed after queueing")
		"panel": app._refresh_hand()
		"escape": root.push_input(_key(KEY_ESCAPE), true)
		"cancel": presenter.cancel_button.pressed.emit()
	# Let the mounted hand reconcile the tampered authority (it may already retire
	# the queued intent) so the snapshot below is the stable post-tamper state.
	await _frames()
	var before := _pool_state()
	presenter._activate(bound[0], bound[1], bound[2], bound[3], bound[4], token)
	await _frames()
	_check(_pool_state() == before and presenter._pending.is_empty(),
		"the stale cape intent cancels without any change including RNG: " + mode)
	presenter._activate(bound[0], bound[1], bound[2], bound[3], bound[4], token)
	await _frames()
	_check(_pool_state() == before, "a refused cape intent cannot replay: " + mode)
	if mode in ["escape", "cancel"]:
		# A real cancellation must leave the very same drawn copy genuinely playable.
		await _mouse(_pool_panel(id))
		_check(_pool_state() == _cape_expected(before, id, 2),
			"after cancel/Escape the same drawn copy plays its printed effect exactly once: " + mode)
	await _dispose()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Both authentic printings (base and '+') in every authored FROM seat, alternating
	# real mouse and keyboard input, each proving the exact printed cost.
	for id in IDS:
		for seat in [1, 2, 3]:
			await _success(id, seat, (seat) % 2 == 0)
	# The existing combat reaction consumer spends the token once; the existing
	# owner-turn boundary expires an unused token.
	for id in IDS:
		await _success(id, 2, false, true, false)
		await _success(id, 1, true, false, true)
	for id in IDS:
		await _refresh(id)
	for mode in ["downed", "missing", "absent", "energy", "turn", "closed", "forged", "label",
			"receipt", "stale"]:
		await _refuse(mode)
	for mode in ["energy", "turn", "closed", "receipt", "party", "hand", "panel", "escape", "cancel"]:
		await _stale(mode)
	_finish()
