extends "res://tests/live_support_hand_test.gd"
## Actual scene-mounted area action, using the shared physical input harness.

const IDS := ["yarn_ranger_unspool", "yarn_ranger_unspool_plus"]
## Mounted wrong-role and malformed status injections. Each starts from a
## genuinely playable hand face and must disable it before any payment.
const STATUS_NEGATIVE_MODES := ["owner_blind", "defender_dodge", "blind_bool",
	"dodge_string", "blind_negative", "fear_int", "counter_negative"]


## One genuine mounted battle: real deck, party and enemy models. The optional
## statuses replace the fixture's own attacker and first-slot defender records so
## the same mounted fixture can carry authentic Dodge/Fear/Blind tokens.
func _begin(id: String, seat: int = 2, owner_statuses: Variant = null,
		first_enemy_statuses: Variant = null) -> Control:
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = 290
	_check(app._start_battle(), "mounted battle starts")
	presenter = app.get_node("LiveAreaAttackAction")
	var rng := RandomNumberGenerator.new()
	rng.seed = 290
	var cards: Array[String] = [id, id, "warden_strike", "warden_brace", "tinker_tune_up"]
	app.deck = CombatDeck.new(cards, rng)
	app.run_rng = rng
	_check(app.deck.start_turn() and app.deck.hand.count(id) == 2, "two genuine drawn copies")
	app.deck.combat_state.energy = 6
	var ranger := {"id": "yarn_ranger", "name": "Yarn Ranger", "max_hp": 27,
		"statuses": {"weak": 1}}
	if owner_statuses is Dictionary:
		ranger["statuses"] = (owner_statuses as Dictionary).duplicate(true)
	var heroes: Array = [{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "tinker", "name": "Tinker", "max_hp": 25}]
	heroes.insert(seat - 1, ranger)
	app.party = CombatParty.new(heroes)
	var tangled_foe := {"id": "tangled", "max_hp": 50, "statuses": {"tangled": 2, "exposed": 1}}
	if first_enemy_statuses is Dictionary:
		tangled_foe["statuses"] = (first_enemy_statuses as Dictionary).duplicate(true)
	app.enemies = CombatEnemies.new([
		tangled_foe,
		{"id": "untangled", "max_hp": 50, "statuses": {"bleed": 2}},
		{"id": "slain", "max_hp": 50, "statuses": {"tangled": 3}}])
	_check(app.party.is_valid() and app.enemies.is_valid(), "real valid rosters")
	_check(app.enemies.gain_block(1, 3) and app.enemies.apply_damage(3, 50), "Block and slain Tangled fixture")
	app.battle_result = CombatBattleResult.new(app.party, app.enemies)
	app.victory_gold = RunVictoryGold.new(app.battle_result)
	app.round_flow = CombatRoundFlow.new(app.deck, app.party, app.enemies, app.enemy_intents, app.battle_result)
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_hand()
	await _frames()
	var panel := _panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel), "authentic panel bound by mounted adapter")
	return panel


func _state() -> Array:
	return [_live(), app.battle_result.get_outcome(), app._battle_closed]


func _dispose() -> void:
	app.free()
	await _frames()


func _success(id: String, keyboard: bool, seat: int) -> void:
	var panel := await _begin(id, seat)
	if panel == null:
		await _dispose()
		return
	var meta = app.get_node("LiveSupportHand")._metadata
	var facts: Dictionary = meta.get_facts(panel)
	var face: Dictionary = presenter.face_text(panel)
	_check(facts.known and facts.owner == "yarn_ranger" and facts.owner_text == "Yarn Ranger" and facts.cost == 2, "authentic metadata face")
	_check(face.owner == "Yarn Ranger" and face.cost == "2 energy" and face.effect.contains("living Tangled enemies only")
		and face.from_pips == [false, true, true] and face.to_pips == [true, true, true] and face.thread, "mounted conditional cue and pips")
	_check(not presenter.face_children(panel).is_empty() and panel.tooltip_text.contains("Tangled")
		and panel.tooltip_text.contains("Yarn Ranger") and panel.tooltip_text.contains("2 energy"), "visible children and full tooltip")
	_check(meta.visual_state(panel).playable and panel.gui_input.get_connections().size() == 1, "single enabled hand entry")
	var expected := _state().duplicate(true)
	var snapshot: Array = expected[0][0]
	snapshot[1].erase(id)
	snapshot[2].append(id)
	snapshot[3] -= 2
	# Combined Weak/Exposed floors once, then Tangled adds 2 before Block.
	var base := 10 if id.ends_with("_plus") else 7
	var damage := int(floor(base * 9.0 / 8.0)) + 2
	expected[0][5][0].hp -= damage - 3
	expected[0][5][0].block = 0
	var callback: Callable = presenter._bindings[panel].callback
	if keyboard:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER), true)
		root.push_input(_key(KEY_ENTER), true)
		root.push_input(_key(KEY_ENTER, false), true)
		await _frames()
	else:
		await _mouse(panel)
	_check(_state() == expected, "exact full state: one payment/discard, adjusted hit, untouched statuses/other slots/intents/RNG")
	_check(presenter.last_event.get("ok", false) and presenter.last_event.hits.size() == 1
		and presenter.last_event.hits[0].position == 1 and presenter.last_event.hits[0].damage == damage, "resolver event forwarded")
	callback.call(_press())
	await _frames()
	_check(_state() == expected and app.deck.hand.count(id) == 1, "retired listener cannot spend affordable remaining copy")
	await _dispose()


## AC1: an authentic enemy Blind (`blind_next_attack: 1`) and Fear
## (`cannot_buff_next_turn: true`) on the living Tangled foe, plus a legal
## attacker Dodge and Fear beside ordinary Weak on the Yarn Ranger, leave the
## real held face playable and resolve exactly one paid all-enemy attack. Blind,
## Fear, Dodge and Tangled all survive untouched and the run RNG never moves.
func _blind_fear_success(id: String, keyboard: bool, seat: int) -> void:
	var owner_statuses := {"weak": 1, "dodge_next_attack": 1, "cannot_buff_next_turn": true}
	var enemy_statuses := {"tangled": 2, "exposed": 1, "blind_next_attack": 1,
		"cannot_buff_next_turn": true}
	var panel := await _begin(id, seat, owner_statuses, enemy_statuses)
	if panel == null:
		await _dispose()
		return
	var meta = app.get_node("LiveSupportHand")._metadata
	var facts: Dictionary = meta.get_facts(panel)
	var face: Dictionary = presenter.face_text(panel)
	var base := 10 if id.ends_with("_plus") else 7
	_check(facts.known and facts.owner == "yarn_ranger" and facts.cost == 2,
		"authentic metadata face with role tokens: " + id)
	_check(face.effect == "Deal %d to living Tangled enemies only." % base
		and face.cost == "2 energy" and face.from_pips == [false, true, true]
		and face.to_pips == [true, true, true] and face.thread,
		"printed base damage and mounted conditional cue unchanged: " + id)
	_check(meta.visual_state(panel).playable and panel.gui_input.get_connections().size() == 1,
		"Blind/Fear Tangled foe and Dodge/Fear owner keep one enabled hand entry: " + id)
	var attacker_before: Dictionary = app.party.get_hero(seat).get("statuses", {})
	var defender_before: Dictionary = app.enemies.get_enemy(1).get("statuses", {})
	_check(attacker_before == owner_statuses, "fixture owner really carries Dodge/Fear/Weak")
	_check(defender_before == enemy_statuses, "fixture foe really carries Blind/Fear/Tangled")
	var rng_before := [app.run_rng.seed, app.run_rng.state]
	var expected := _state().duplicate(true)
	var snapshot: Array = expected[0][0]
	snapshot[1].erase(id)
	snapshot[2].append(id)
	snapshot[3] -= 2
	# Combined Weak/Exposed floors once, then Tangled adds 2 before Block.
	var damage := int(floor(base * 9.0 / 8.0)) + 2
	expected[0][5][0].hp -= damage - 3
	expected[0][5][0].block = 0
	var callback: Callable = presenter._bindings[panel].callback
	if keyboard:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER), true)
		root.push_input(_key(KEY_ENTER), true)
		root.push_input(_key(KEY_ENTER, false), true)
		await _frames()
	else:
		await _mouse(panel)
	_check(_state() == expected, "one 2-energy charge, one discard and the adjusted hit only: " + id)
	_check(app.party.get_hero(seat).get("statuses") == attacker_before,
		"owner Dodge/Fear/Weak untouched by the paid attack: " + id)
	_check(app.enemies.get_enemy(1).get("statuses") == defender_before,
		"defender Blind/Fear/Tangled/Exposed untouched: " + id)
	_check(app.enemies.get_enemy(2).get("hp") == 50
		and app.enemies.get_enemy(2).get("statuses") == {"bleed": 2},
		"living untangled foe never struck: " + id)
	_check(app.enemies.get_enemy(3).get("hp") == 0
		and app.enemies.get_enemy(3).get("statuses") == {"tangled": 3},
		"slain Tangled foe never struck: " + id)
	_check([app.run_rng.seed, app.run_rng.state] == rng_before, "seeded run RNG unchanged: " + id)
	_check(presenter.last_event.get("ok", false) and presenter.last_event.hits.size() == 1
		and presenter.last_event.hits[0].position == 1
		and presenter.last_event.hits[0].damage == damage
		and presenter.last_event.hits[0].block_absorbed == 3
		and presenter.last_event.hits[0].hp_loss == damage - 3,
		"one forwarded all-enemy hit through Block: " + id)
	callback.call(_press())
	await _frames()
	_check(_state() == expected and app.deck.hand.count(id) == 1,
		"retired listener cannot charge the remaining copy: " + id)
	await _dispose()


func _refusal(id: String, mode: String, queued: bool) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel].callback
	if queued:
		panel.grab_focus()
		root.push_input(_key(KEY_ENTER), true)
		_check(not presenter._pending.is_empty(), "actual input queued before invalidation")
	# Every status negative below starts from a genuinely playable face, so the
	# disabled face afterwards proves the injected token alone refused the cast.
	if mode in STATUS_NEGATIVE_MODES:
		var live_meta = app.get_node("LiveSupportHand")._metadata
		live_meta._update_visual(panel)
		_check(live_meta.visual_state(panel).playable, "status negative starts playable: " + mode)
	match mode:
		"targets": app.enemies._enemies[0].statuses.erase("tangled")
		"energy": app.deck.combat_state.energy = 1
		"missing": app.party._heroes[1].id = "seamstress"
		"downed": app.party.apply_damage(2, 1000)
		"position":
			var heroes: Array = app.party.get_heroes()
			var first = heroes[0]
			heroes[0] = heroes[1]
			heroes[1] = first
			app.party._heroes = CombatParty.new(heroes).get_heroes()
			_check(app.party.get_hero(1).id == "yarn_ranger", "valid front-seat owner")
		"absent":
			app.deck.discard_played(id)
			app.deck.discard_played(id)
		"closed": app._battle_closed = true
		"turn": app.enemy_intents.advance_turn()
		"label": panel.get_child(0).text = IDS[1] if id == IDS[0] else IDS[0]
		"rebuild": app._refresh_hand()
		"session": app.battle_result = CombatBattleResult.new(app.party, app.enemies)
		"inactive": app.deck.combat_state.player_turn_active = false
		"status": app.enemies._enemies[0].statuses.exposed = "bad"
		# A hero-side Blind and an enemy-side Dodge are the wrong roles for an
		# outgoing attack: both stay refused even as the int 1 the token names.
		"owner_blind": app.party._heroes[1].statuses["blind_next_attack"] = 1
		"defender_dodge": app.enemies._enemies[0].statuses["dodge_next_attack"] = 1
		# Malformed token types and counts, and a malformed Fear value.
		"blind_bool": app.enemies._enemies[0].statuses["blind_next_attack"] = true
		"dodge_string": app.party._heroes[1].statuses["dodge_next_attack"] = "1"
		"blind_negative": app.enemies._enemies[0].statuses["blind_next_attack"] = -1
		"fear_int": app.party._heroes[1].statuses["cannot_buff_next_turn"] = 1
		# A malformed damage-status counter beside a legal Tangled counter.
		"counter_negative": app.enemies._enemies[0].statuses["riposte"] = -1
	# Settle the HUD's legitimate response to the changed fixture before input.
	app._refresh_intents()
	var before := _state()
	if mode != "rebuild":
		var meta = app.get_node("LiveSupportHand")._metadata
		meta._update_visual(panel)
		_check(not meta.visual_state(panel).playable, "unavailable face: " + mode)
	callback.call(_press())
	await _frames()
	_check(_state() == before, "full no-spend snapshot: " + mode)
	await _dispose()


func _terminal_and_stale(id: String) -> void:
	var panel := await _begin(id)
	if panel == null:
		await _dispose()
		return
	_check(app.enemies.apply_damage(2, 50) and app.enemies.apply_damage(1, 49), "last living Tangled enemy at lethal HP after Block")
	# Damage first absorbed 3 Block, leaving four HP: still a lethal authored hit.
	var oracle := RandomNumberGenerator.new()
	oracle.seed = app.run_rng.seed
	oracle.state = app.run_rng.state
	var gold := oracle.randi_range(10, 20)
	await _mouse(panel)
	_check(presenter.last_event.get("ok", false) and app.enemies.is_victorious()
		and app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and not app.deck.turn_active and app.end_turn_button.disabled, "real result observer closes final cast")
	_check(app.session_gold == gold and app.run_rng.state == oracle.state, "only existing victory reward consumes RNG")
	await _dispose()
	panel = await _begin(id)
	if panel == null:
		await _dispose()
		return
	var callback: Callable = presenter._bindings[panel].callback
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_enemies: CombatEnemies = app.enemies
	var old_rng: RandomNumberGenerator = app.run_rng
	var before := [_snapshot(old_deck, old_party, old_rng), old_enemies.get_enemies()]
	panel.grab_focus()
	root.push_input(_key(KEY_ENTER), true)
	_check(not presenter._pending.is_empty(), "cast queued before leaving battle")
	app.return_button.pressed.emit()
	callback.call(_press())
	await _frames()
	_check([_snapshot(old_deck, old_party, old_rng), old_enemies.get_enemies()] == before,
		"closed battle and queued retired callback preserve old authorities")
	_check(app._start_battle(), "replacement real battle starts")
	await _frames()
	var fresh := _state()
	callback.call(_press())
	await _frames()
	_check(_state() == fresh, "stale panel cannot mutate replacement battle")
	await _dispose()


## AC2: one paid cast from a Dodging/Feared owner reaches every living Tangled
## foe exactly once in seat order, including foes that also carry Blind and
## Fear, and never the slain or untangled slots.
func _multiple(id: String) -> void:
	var panel := await _begin(id, 3, {"weak": 1, "dodge_next_attack": 1, "cannot_buff_next_turn": true},
		{"tangled": 2, "exposed": 1, "blind_next_attack": 1, "cannot_buff_next_turn": true})
	if panel == null:
		await _dispose()
		return
	app.enemies._enemies[1].statuses["tangled"] = 1
	app.enemies._enemies[1].statuses["blind_next_attack"] = 1
	app.enemies._enemies[1].statuses["cannot_buff_next_turn"] = true
	_check(app.enemies.gain_block(2, 2), "second living Tangled target has Block")
	app._refresh_intents()
	var owner_statuses: Dictionary = app.party.get_hero(3).get("statuses", {})
	var first_statuses: Dictionary = app.enemies.get_enemy(1).get("statuses", {})
	var second_statuses: Dictionary = app.enemies.get_enemy(2).get("statuses", {})
	_check(owner_statuses == {"weak": 1, "dodge_next_attack": 1, "cannot_buff_next_turn": true}
		and first_statuses == {"tangled": 2, "exposed": 1, "blind_next_attack": 1,
			"cannot_buff_next_turn": true}
		and second_statuses == {"bleed": 2, "tangled": 1, "blind_next_attack": 1,
			"cannot_buff_next_turn": true},
		"multi-target fixture really carries every authentic token")
	var expected := _state().duplicate(true)
	expected[0][0][1].erase(id)
	expected[0][0][2].append(id)
	expected[0][0][3] -= 2
	var base := 10 if id.ends_with("_plus") else 7
	expected[0][5][0].hp -= int(floor(base * 9.0 / 8.0)) + 2 - 3
	expected[0][5][0].block = 0
	expected[0][5][1].hp -= int(floor(base * 0.75)) + 2 - 2
	expected[0][5][1].block = 0
	await _mouse(panel)
	_check(_state() == expected and presenter.last_event.hits.size() == 2
		and presenter.last_event.hits[0].position == 1 and presenter.last_event.hits[1].position == 2,
		"each living Tangled slot hit once in order with independent modifiers; slain slot unchanged")
	_check(app.party.get_hero(3).get("statuses") == owner_statuses,
		"owner Dodge/Fear/Weak survive the multi-target cast")
	_check(app.enemies.get_enemy(1).get("statuses") == first_statuses
		and app.enemies.get_enemy(2).get("statuses") == second_statuses,
		"both defenders keep Blind, Fear and their Tangled counters")
	_check(app.enemies.get_enemy(3).get("hp") == 0
		and app.enemies.get_enemy(3).get("statuses") == {"tangled": 3},
		"slain Tangled slot is still untouched")
	await _dispose()


## Scene-free paid regression for both printings: the resolver itself — not just
## the mounted face — admits an attacker's Dodge/Fear and a defender's Blind/Fear,
## and refuses every wrong-role or malformed token before paying. Real
## CombatDeck/CombatParty/CombatEnemies with one seeded run RNG.
func _role_policy_cases() -> void:
	var resolver := CombatYarnRangerUnspoolCards.new()
	for id: String in IDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 425
		var deck := _policy_deck(id, rng)
		var party := _policy_party({"weak": 1, "dodge_next_attack": 1, "cannot_buff_next_turn": true})
		var enemies := _policy_enemies({"tangled": 1, "blind_next_attack": 1,
			"cannot_buff_next_turn": true})
		_check(enemies.gain_block(1, 2) and enemies.apply_damage(3, 40),
			"scene-free fixture really has Block and a slain Tangled slot")
		var rng_before := [rng.seed, rng.state]
		var base := 10 if id.ends_with("_plus") else 7
		var hit := resolver.play_card(deck, party, enemies, id)
		# Weak floors once, then Tangled adds its flat +2; Block absorbs first.
		var damage := int(floor(base * 0.75)) + 2
		_check(hit.get("ok", false) and hit.hits.size() == 1
			and hit.hits[0].position == 1 and hit.hits[0].damage == damage
			and hit.hits[0].block_absorbed == 2 and hit.hits[0].hp_loss == damage - 2,
			"scene-free: one paid hit through Block on the Blinded/Feared Tangled foe: " + id)
		_check(deck.energy == 1 and deck.hand.is_empty() and deck.discard_pile == [id],
			"scene-free: exactly two energy and one copy were spent: " + id)
		_check(party.get_hero(2).get("statuses") == {"weak": 1, "dodge_next_attack": 1,
				"cannot_buff_next_turn": true},
			"scene-free: attacker Dodge/Fear/Weak untouched: " + id)
		_check(enemies.get_enemy(1).get("statuses") == {"tangled": 1, "blind_next_attack": 1,
				"cannot_buff_next_turn": true},
			"scene-free: defender Blind/Fear/Tangled untouched: " + id)
		_check(enemies.get_enemy(2).get("hp") == 40
			and enemies.get_enemy(3).get("hp") == 0, "scene-free: other slots untouched: " + id)
		_check([rng.seed, rng.state] == rng_before, "scene-free: paid hit consumes no RNG: " + id)
		var refused: Array[Dictionary] = [
			{"label": "hero Blind", "owner": {"blind_next_attack": 1}, "enemy": {"tangled": 1}},
			{"label": "hero Blind 0", "owner": {"blind_next_attack": 0}, "enemy": {"tangled": 1}},
			{"label": "enemy Dodge", "owner": {}, "enemy": {"tangled": 1, "dodge_next_attack": 1}},
			{"label": "enemy Dodge bool", "owner": {}, "enemy": {"tangled": 1, "dodge_next_attack": true}},
			{"label": "hero Dodge bool", "owner": {"dodge_next_attack": true}, "enemy": {"tangled": 1}},
			{"label": "hero Dodge string", "owner": {"dodge_next_attack": "1"}, "enemy": {"tangled": 1}},
			{"label": "hero Dodge two", "owner": {"dodge_next_attack": 2}, "enemy": {"tangled": 1}},
			{"label": "hero Dodge negative", "owner": {"dodge_next_attack": -1}, "enemy": {"tangled": 1}},
			{"label": "enemy Blind bool", "owner": {}, "enemy": {"tangled": 1, "blind_next_attack": true}},
			{"label": "enemy Blind string", "owner": {}, "enemy": {"tangled": 1, "blind_next_attack": "1"}},
			{"label": "enemy Blind two", "owner": {}, "enemy": {"tangled": 1, "blind_next_attack": 2}},
			{"label": "enemy Blind negative", "owner": {}, "enemy": {"tangled": 1, "blind_next_attack": -1}},
			{"label": "hero Fear false", "owner": {"cannot_buff_next_turn": false}, "enemy": {"tangled": 1}},
			{"label": "hero Fear int", "owner": {"cannot_buff_next_turn": 1}, "enemy": {"tangled": 1}},
			{"label": "enemy Fear string", "owner": {},
				"enemy": {"tangled": 1, "cannot_buff_next_turn": "true"}},
			{"label": "enemy counter float", "owner": {}, "enemy": {"tangled": 1, "exposed": 1.0}},
			{"label": "enemy counter negative", "owner": {}, "enemy": {"tangled": 1, "riposte": -1}},
			{"label": "enemy unknown status", "owner": {}, "enemy": {"tangled": 1, "haste": 1}},
		]
		for entry: Dictionary in refused:
			var case_rng := RandomNumberGenerator.new()
			case_rng.seed = 425
			var case_deck := _policy_deck(id, case_rng)
			var case_party := _policy_party(entry["owner"])
			var case_enemies := _policy_enemies(entry["enemy"])
			var before := _policy_state(case_deck, case_party, case_enemies, case_rng)
			_check(resolver.play_card(case_deck, case_party, case_enemies, id).get("ok", false) == false,
				"scene-free refusal: %s (%s)" % [entry["label"], id])
			_check(_policy_state(case_deck, case_party, case_enemies, case_rng) == before,
				"scene-free refusal leaves deck, energy, actors and RNG untouched: %s (%s)" % [
					entry["label"], id])


func _policy_party(owner_statuses: Variant) -> CombatParty:
	var ranger := {"id": "yarn_ranger", "name": "Yarn Ranger", "max_hp": 27}
	if owner_statuses is Dictionary:
		ranger["statuses"] = (owner_statuses as Dictionary).duplicate(true)
	return CombatParty.new([{"id": "warden", "name": "Warden", "max_hp": 40}, ranger,
		{"id": "seamstress", "name": "Seamstress", "max_hp": 26}])


func _policy_enemies(slot_statuses: Variant) -> CombatEnemies:
	var tangled_foe := {"id": "tangled", "name": "Tangled", "max_hp": 50}
	if slot_statuses is Dictionary:
		tangled_foe["statuses"] = (slot_statuses as Dictionary).duplicate(true)
	return CombatEnemies.new([tangled_foe,
		{"id": "untangled", "name": "Untangled", "max_hp": 40, "statuses": {"bleed": 2}},
		{"id": "slain", "name": "Slain", "max_hp": 40, "statuses": {"tangled": 2}}])


func _policy_deck(id: String, rng: RandomNumberGenerator) -> CombatDeck:
	var deck := CombatDeck.new([id], rng)
	deck.combat_state.start_player_turn()
	deck.hand.clear()
	deck.hand.append(id)
	return deck


func _policy_state(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		rng: RandomNumberGenerator) -> Array:
	return [_snapshot(deck, party, rng), enemies.get_enemies()]


func _run() -> void:
	root.size = Vector2i(1280, 720)
	for id: String in IDS:
		for keyboard in [false, true]:
			for seat in [2, 3]:
				await _success(id, keyboard, seat)
		# Authentic Dodge/Blind/Fear tokens from both seats, by mouse and keyboard.
		await _blind_fear_success(id, false, 2)
		await _blind_fear_success(id, true, 3)
		var modes: Array = ["targets", "energy", "missing", "downed", "position", "absent", "closed", "turn", "label", "rebuild", "session", "inactive", "status"]
		for mode: String in modes:
			for queued in [false, true]:
				await _refusal(id, mode, queued)
		# Each wrong-role/malformed token disables the real face before paying, and
		# the two representative injections also prove a queued receipt cannot pay.
		for mode: String in STATUS_NEGATIVE_MODES:
			await _refusal(id, mode, false)
		for mode: String in ["owner_blind", "blind_bool"]:
			await _refusal(id, mode, true)
		await _multiple(id)
		await _terminal_and_stale(id)
	_role_policy_cases()
	var meta = preload("res://scripts/live_hand_card_metadata.gd").new()
	for id in YarnRangerPoolCards.new().get_all_card_ids():
		if CombatYarnRangerKnitCards.CARDS.has(id):
			_check(meta.definition(id) == CombatYarnRangerKnitCards.knit_definition(id), "knit IDs use authentic definitions")
		elif CombatYarnRangerBolasCards.CARDS.has(id):
			_check(meta.definition(id) == CombatYarnRangerBolasCards.bolas_definition(id), "bolas IDs use authentic definitions")
		elif CombatYarnRangerNeedleCards.CARDS.has(id):
			_check(meta.definition(id) == CombatYarnRangerNeedleCards.needle_definition(id), "needle IDs use authentic definitions")
		elif CombatYarnRangerEndlessSkeinCards.CARDS.has(id):
			_check(meta.definition(id) == CombatYarnRangerEndlessSkeinCards.skein_definition(id),
				"Endless Skein IDs use authenticated live definitions")
		elif id not in IDS and id not in ["yarn_ranger_snare_net", "yarn_ranger_snare_net_plus"]:
			_check(meta.definition(id).is_empty(), "unrelated Yarn IDs remain unwired")
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_yarn_ranger_unspool_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
