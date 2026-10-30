extends "res://tests/live_warden_v3_taunt_hand_test.gd"
## Live physical shared-hand -> authentic V3 Guard -> real End Turn enemy-phase path.

const PRINTINGS := CombatWardenV3GuardCards.CARDS


func _guard_state() -> Array:
	var guard: CombatWardenV3GuardCards = app.round_flow.get_warden_guard_authority()
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemies.get_enemies(),
		app.enemy_intents.get_intents(), guard.has_pending_guard(),
		guard.get_guarded_hero_id(), guard.get_pending_guard_card_id()]


func _cast(id: String, keyboard: bool) -> bool:
	var panel := _panel(id)
	_check(panel != null and panel.is_visible_in_tree() and presenter._bindings.has(panel),
		"physical held V3 guard card is wired by support hand: " + id)
	if panel == null:
		return false
	await _input_card(panel, keyboard)
	_check(presenter._pending.get("choosing", false) and presenter._targets.size() > 0
		and presenter.cancel_button.visible and app.hero_panels.size() == 3,
		"mouse/keyboard opens actual living-ally targeting and Cancel")
	var target: Control = app.hero_panels[2]
	_check(presenter._targets.has(target) and target.is_visible_in_tree(),
		"living Tinker is a reachable selectable hero target")
	if not presenter._targets.has(target):
		return false
	if keyboard:
		target.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(target)
	await _frames()
	return true


func _case(id: String, keyboard: bool, middle: bool) -> Array:
	var panel := await _begin_taunt(id)
	if panel == null:
		await _complete()
		return []
	if middle:
		var swap: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
		_check(swap.get("ok", false), "precondition: authentic Warden can move to seat 2")
		if swap.get("ok", false):
			app.party._heroes.assign(swap.heroes)
		app._refresh_party()
		await _frames()
	var warden_seat := 2 if middle else 1
	_check(app.party.get_hero(warden_seat).id == "warden"
		and app.party.get_hero(warden_seat).hp == 40
		and app.party.get_hero(3).id == "tinker" and app.party.get_hero(3).hp == 26
		and app.deck.hand.count(id) == 2 and app.deck.energy == 3
		and app.enemy_intents.get_intents()[0].hits == 2,
		"non-vacuous live Warden/ally/hand/multi-hit preconditions")
	var guard: CombatWardenV3GuardCards = app.round_flow.get_warden_guard_authority()
	_check(not guard.has_pending_guard() and guard.is_authentic_card(id),
		"fresh fight starts unarmed and catalog authenticates exact printing")
	var face: Dictionary = presenter._metadata.definition(id)
	var amount: int = int(PRINTINGS[id].block)
	_check(face.get("id") == id and face.get("owner") == "warden"
		and face.get("target_kind") == "ally_single" and face.get("cost") == 1
		and presenter._metadata.base_effect_text(id).contains("Guard"),
		"real sewn face identifies authenticated ally Guard rules")
	var old_rng: int = app.run_rng.state
	var announcements: Array = app.enemy_intents.get_intents()
	_check(await _cast(id, keyboard), "player can choose a living Tinker")
	_check(app.deck.hand.count(id) == 1 and app.deck.discard_pile.count(id) == 1
		and app.deck.energy == 2 and app.party.get_hero(3).block == amount,
		"exactly one 1-energy copy pays and grants printed %d Block" % amount)
	_check(guard.has_pending_guard() and guard.get_guarded_hero_id() == "tinker"
		and guard.get_pending_guard_card_id() == id and app.run_rng.state == old_rng
		and app.enemy_intents.get_intents() == announcements,
		"paid cast arms same fight identity, no RNG/intent mutation")
	# Any rehearsal must not publish the one-shot.
	var actors: Array = app.party.get_heroes()
	_check(app.round_flow._phase_is_executable(actors, announcements)
		and app.round_flow._phase_is_executable(actors, announcements)
		and guard.has_pending_guard() and app.run_rng.state == old_rng,
		"repeated full enemy-phase rehearsal leaves real one-shot armed and RNG unchanged")
	await _end(not keyboard)
	var expected_tinker_block: int = 0 # fresh player-turn opening clears carried Block
	var expected_tinker_hp: int = 26 - maxi(0, 4 - amount)
	_check(not guard.has_pending_guard() and app.party.get_hero(3).hp == expected_tinker_hp
		and app.party.get_hero(3).block == expected_tinker_block
		and app.party.get_hero(warden_seat).hp == (36 if middle else 40)
		and app.party.get_hero(warden_seat).block == 0,
		"real End Turn: first hit Warden, second Tinker, later attack and next-turn Block reset")
	_check(app.party.get_hero(1 if middle else 2).hp == 30 if middle else
		app.party.get_hero(2).hp == 25,
		"later separate enemy attack obeys its actual announced seat")
	_check(app.enemies.get_enemy(3).block == 2
		and app.round_flow._v3_guard.get_guarded_hero_id().is_empty()
		and app.enemy_intents.get_intents() != [],
		"nonattack Block, intent advancement and one-use consumption survive real phase")
	var state := _guard_state()
	await _complete()
	return state


func _negatives() -> void:
	var id := "warden_v3_shield_catch"
	var panel := await _begin_taunt(id)
	if panel == null:
		await _complete()
		return
	var guard: CombatWardenV3GuardCards = app.round_flow.get_warden_guard_authority()
	var initial := _guard_state()
	# An actual pending ally selection can be cancelled without charging.
	await _input_card(panel, false)
	_check(presenter._pending.get("choosing", false), "real selection is pending before cancellation")
	await _mouse(presenter.cancel_button)
	_check(presenter._pending.is_empty() and _guard_state() == initial,
		"Cancel restores focus and leaves card/guard/RNG unchanged")
	app.deck.combat_state.energy = 0
	var poor := _guard_state()
	await _input_card(panel, true)
	_check(_guard_state() == poor and not guard.has_pending_guard(),
		"insufficient shared energy refuses before targeting or discard")
	app.deck.combat_state.energy = 3
	app.party._heroes[0].id = "not_warden"
	var wrong := _guard_state()
	await _input_card(panel, false)
	_check(_guard_state() == wrong and not guard.has_pending_guard(),
		"wrong owner cannot pay or arm")
	app.party._heroes[0].id = "warden"
	var index: int = panel.get_index()
	app.deck.hand[index] = "warden_brace"
	var stale := _guard_state()
	await _input_card(panel, true)
	_check(_guard_state() == stale, "replaced exact held instance refuses")
	app.deck.hand[index] = id
	app.deck.combat_state.player_turn_active = false
	var closed := _guard_state()
	await _input_card(panel, true)
	_check(_guard_state() == closed and not guard.has_pending_guard(),
		"inactive turn cannot start selection or spend a held guard")
	app.deck.combat_state.player_turn_active = true
	# A dead target must not appear in the real selection even when two allies survive.
	_check(app.party.apply_damage(3, 999) and app.party.is_downed(3)
		and not app.party.is_defeated(), "negative target precondition: Tinker is truly torn")
	var downed := _guard_state()
	await _input_card(panel, false)
	_check(presenter._pending.get("choosing", false)
		and not presenter._targets.has(app.hero_panels[2])
		and not guard.has_pending_guard(), "torn protected target cannot be selected")
	await _mouse(presenter.cancel_button)
	_check(_guard_state() == downed and presenter._pending.is_empty(),
		"cancel torn-target choice without spending, latching or RNG changes")
	app.party._heroes[2].hp = 26
	var original_intents: CombatEnemyIntents = app.enemy_intents
	app.enemy_intents = CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 1,
			"target_position": 3}]}])
	var foreign := _guard_state()
	await _input_card(panel, true)
	_check(_guard_state() == foreign and not guard.has_pending_guard(),
		"foreign battle scheduler invalidates previously bound hand panel")
	app.enemy_intents = original_intents
	var forged := _guard_state()
	_check(not app.round_flow.play_warden_guard_card("warden_v3_shield_catch_forged", 3)
		and not app.round_flow.play_warden_guard_card(id, 0)
		and _guard_state() == forged,
		"forged IDs and impossible ally positions refuse without mutating live combat")
	_check(_guard_state() == initial, "negative fixtures restore authentic starting state")
	_check(await _cast(id, true), "authentic cast succeeds after negative refusals")
	_check(guard.has_pending_guard(), "accepted cast genuinely armed before failed enemy batch")
	# Source 2's wrong target follows source 1's multi-hit in the same batch.
	app.enemy_intents._definitions[1].pattern[0].target_position = 99
	var failed := _guard_state()
	_check(not app.round_flow.end_turn() and _guard_state() == failed
		and guard.has_pending_guard(), "failed enemy batch leaves resources and guard unconsumed")
	app.enemy_intents._definitions[1].pattern[0].target_position = 2
	await _end(false)
	_check(not guard.has_pending_guard(), "accepted retry consumes latch exactly once")
	await _complete()


func _fresh_fight() -> void:
	var id := "warden_v3_guard_stitch"
	var panel := await _begin_taunt(id)
	if panel == null:
		await _complete()
		return
	_check(await _cast(id, false), "first fight genuinely arms Guard Stitch")
	var previous: CombatWardenV3GuardCards = app.round_flow.get_warden_guard_authority()
	_check(previous.has_pending_guard(), "retiring battle contains real armed guard")
	app._return_to_title()
	_check(app._start_battle() and app.round_flow != null
		and app.round_flow.get_warden_guard_authority() != previous
		and not app.round_flow.get_warden_guard_authority().has_pending_guard(),
		"new genuine app fight has a different, empty guard authority")
	await _complete()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	for id: String in PRINTINGS:
		# Final Bastion is a self-targeted rare (cost 3) not wired to the live hand yet.
		if id == "warden_v3_final_bastion" or id == "warden_v3_final_bastion_plus":
			continue
		for middle in [false, true]:
			var mouse: Array = await _case(id, false, middle)
			var keyboard: Array = await _case(id, true, middle)
			_check(not mouse.is_empty() and mouse == keyboard,
				"same-seed mouse/keyboard cast replays exact post-phase state and RNG: " + id)
	await _negatives()
	await _fresh_fight()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("live_warden_v3_guard_hand_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
