extends "res://tests/stitched_s6_routed_vis_a_test.gd"
## Genuine combat loss -> connected Shop -> mounted Circle -> onward ranked battle.

const SAVE_PATH := "user://stitched_s6_routed_replacement_live.save"


func _button(app: Node, id: String, arguments: Array = []) -> Button:
	var actions: Array = app.stitched_run_session.visit_actions()
	for index in actions.size():
		if actions[index].id == id and actions[index].arguments == arguments:
			return app.stitched_run_buttons[index]
	_check(false, "mounted action exists: " + id + str(arguments))
	return null


func _reload(app: Node, label: String) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	var before := session.snapshot()
	var actions := session.visit_actions()
	var count := actions.size() if session.phase == "visit" else session.choices().size()
	app.stitched_save_path = SAVE_PATH
	_check(app.stitched_run_buttons[count].text == "Save run", label + " has mounted Save")
	app.stitched_run_buttons[count].pressed.emit()
	app.stitched_run_buttons[count + 1].pressed.emit()
	_check(app.stitched_run_session != session and app.stitched_run_session.snapshot() == before
		and app.stitched_run_session.visit_actions() == actions,
		label + " restores exact snapshot and authenticated choices through mounted Save/Reload")


func _healthy_circle() -> void:
	var witness := _seed_with_kind("SewingCircle")
	_check(not witness.is_empty(), "healthy Circle has a genuine generated opening witness")
	if witness.is_empty():
		return
	var app: Node = await _new_run(witness.seed)
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and _press_route(app, witness.id), "healthy party mounts the actual routed Circle")
	if session != null and session.phase == "visit":
		_check(session.heroes.all(func(hero: Dictionary): return not hero.lost and hero.hp > 0)
			and not session.visit_actions().any(func(action: Dictionary): return action.id == "replace"),
			"healthy dolls have no mounted replacement offer")
		var before := session.snapshot()
		_check(not session.choose_visit("replace", ["scarecrow", session.heroes[0].id], before)
			and session.snapshot() == before, "healthy replacement fails closed")
		_check(_button(app, "leave") != null, "healthy Circle retains free Leave")
	app.free()
	await process_frame


func _lost_circle() -> void:
	# This S6 fixture documents the legacy one-Hanging-then-LOST carry, gear transfer and
	# replacement path. S14's escalating death door is exercised by its own gate test.
	# Seed 0 is the witness where the opening Fight leaves exactly one LOST doll: the old
	# 1690 route now loses two dolls in that Fight once the Moth Swarm's third-turn
	# Tattercloud Knot joins its authored rotation.
	var app: Node = await _new_run(0)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	session.s14_enabled = false
	session._seal()
	app._present_stitched_run()
	var fight_id := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Fight":
			fight_id = id
	_check(not fight_id.is_empty() and _press_route(app, fight_id), "actual route enters the loss witness fight")
	var stage: StitchedBattleScreen = app.stitched_run_battle
	if stage == null:
		app.free()
		return
	for step in range(500):
		if stage.battle.is_over() or stage.battle.get_heroes().any(func(hero: Dictionary): return hero.lost):
			break
		stage._action_buttons["pass"].pressed.emit()
	var won := _win(stage)
	_check(won.acted > 0 and stage.battle.outcome() == "victory", "survivors earn a real victory after enemy turns")
	if stage.battle.outcome() != "victory":
		app.free()
		return
	stage._action_buttons["exit"].pressed.emit()
	var lost := session.heroes.filter(func(hero: Dictionary): return hero.lost)
	_check(lost.size() == 1 and lost[0].hp == 0 and lost[0].parts == {} and session.satchel.size() >= 4,
		"real loss publishes one zero-HP empty-parts doll and already transfers its gear")
	if lost.size() != 1:
		app.free()
		return
	var lost_id: String = lost[0].id
	var shop_id := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Shop":
			shop_id = id
	_check(not shop_id.is_empty() and _press_route(app, shop_id), "genuine loss reaches connected Peddler")
	var living: Array = session.heroes.filter(func(hero: Dictionary): return not hero.lost)
	_check(not living.is_empty() and session.gold >= 10, "survivor and earned wallet fund an unrelated pocket witness")
	if living.is_empty() or session.phase != "visit":
		app.free()
		return
	var tonic := _button(app, "buy_thimble_tonic", [living[0].id])
	if tonic == null:
		app.free()
		return
	tonic.pressed.emit()
	_check(session.pockets[living[0].id] == ["thimble_tonic"], "survivor actually owns a tonic before replacement")
	var circle_id := ""
	for id in session.choices():
		if session.map.get_node(id).type == "SewingCircle":
			circle_id = id
	_check(not circle_id.is_empty() and _press_route(app, circle_id)
		and session.pending.service == "SewingCircle"
		and session.map.get_node(session.pending.node_id).type == "SewingCircle",
		"mounted Circle is the genuine connected map node")
	if session.phase != "visit" or session.pending.service != "SewingCircle":
		app.free()
		return
	var old_offer: Button
	var offers := session.visit_actions().filter(func(action: Dictionary): return action.id == "replace")
	_check(not offers.is_empty(), "genuine LOST record exposes authenticated replacements")
	var seen := {}
	for action in offers:
		var candidate_id: String = action.arguments[0]
		_check(action.enabled and action.arguments[1] == lost_id and candidate_id in StitchedPartyAdmission.HERO_IDS
			and not candidate_id in session._party_ids(), "offers name only unused canonical heroes and the genuine LOST doll")
		seen[candidate_id] = true
		var button := _button(app, action.id, action.arguments)
		_check(button != null and button.is_visible_in_tree() and not button.disabled
			and button.focus_mode == Control.FOCUS_ALL and button.mouse_filter == Control.MOUSE_FILTER_STOP
			and button.get_meta("action_id") == action.id and button.get_meta("action_arguments") == action.arguments,
			"generic mouse/keyboard projection mounts the exact replacement action")
		if button != null:
			button.grab_focus()
			_check(button.has_focus() and not button.focus_next.is_empty(), "replacement participates in keyboard navigation")
			old_offer = button
	for hero_id in StitchedPartyAdmission.HERO_IDS:
		if not hero_id in session._party_ids():
			_check(seen.has(hero_id), "every unused authenticated identity is offered")
	# Owner 11-08: Mend is offered only when a living doll has a torn part and the scraps to sew it.
	var mendable: bool = session.scraps >= StitchedRunSession.SEWING_COST and session.heroes.any(func(hero):
		return not hero.lost and hero.parts.values().any(func(part): return part is Dictionary and part.get("torn", false)))
	for id in ["mend", "upgrade", "swap", "leave"]:
		if id == "mend" and not mendable:
			continue
		_check(session.visit_actions().any(func(action: Dictionary): return action.id == id), "Circle retains " + id)
	if offers.is_empty():
		app.free()
		return
	_reload(app, "pending LOST Circle")
	session = app.stitched_run_session
	var before := session.snapshot()
	if old_offer != null:
		old_offer.pressed.emit()
	_check(session.snapshot() == before, "pre-reload replacement callback cannot authorize the restored session")
	var action: Dictionary = offers[0]
	var args: Array = action.arguments
	var journal := session.journal.duplicate(true)
	for invalid in [[], [null, lost_id], [7, lost_id], [args[0]], [args[0], lost_id, {}],
			[args[0], living[0].id], [living[0].id, lost_id], ["forged", lost_id], [lost_id, args[0]]]:
		_check(not session.choose_visit("replace", invalid, before) and session.snapshot() == before
			and session.journal == journal, "malformed or unauthorized replacement is atomic: " + str(invalid))
	for key in ["heroes", "pending", "rng", "map", "pockets"]:
		var forged := before.duplicate(true)
		forged[key] = {}
		_check(not session.choose_visit("replace", args, forged) and session.snapshot() == before,
			"forged expected " + key + " cannot authorize replacement")
	var authority: RunStitchedSewingReplacement = session._replacement_visit
	var source := authority.read_state()
	_check(source.ok and source.open and source.node_id == session.pending.node_id and source.party == before.heroes,
		"mounted action uses the existing service with authoritative node and actual party")
	var expected_hero: Dictionary = {}
	for candidate in source.candidates:
		if candidate.id == args[0]:
			expected_hero = candidate.duplicate(true)
	_check(not expected_hero.is_empty(), "candidate has an authenticated starter template")
	if expected_hero.is_empty():
		app.free()
		return
	var lost_index := session._party_ids().find(lost_id)
	expected_hero["rank"] = before.heroes[lost_index].rank
	expected_hero["position"] = expected_hero.rank
	expected_hero["lost"] = false
	var canonical_picks := session._party_ids()
	canonical_picks[lost_index] = args[0]
	var canonical := StitchedRunSession.starter_config(canonical_picks)
	for hero in canonical.heroes:
		if hero.id == args[0]:
			_check(hero.parts == expected_hero.parts and hero.max_hp == expected_hero.base_max_hp,
				"candidate uses its own real catalog starter kit and roster base HP")
	for part in expected_hero.parts.values():
		_check(part.tier == 1 and not part.torn and session.catalog[part.id].owner == args[0], "starter part is owned, tier one and untorn")
	var twin := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(twin != null and twin.choose_visit("replace", args, twin.snapshot()), "detached replay accepts the same lawful replacement")
	var button := _button(app, "replace", args)
	button.pressed.emit()
	var after := session.snapshot()
	var expected_party: Array = before.heroes.duplicate(true)
	expected_party[lost_index] = expected_hero
	var expected_pockets: Dictionary = before.pockets.duplicate(true)
	expected_pockets.erase(lost_id)
	expected_pockets[args[0]] = []
	_check(after.heroes == expected_party and expected_hero.hp == expected_hero.max_hp,
		"one candidate with full starter HP takes exactly the same rank/index; every survivor is unchanged")
	_check(after.pockets == expected_pockets and after.pockets[living[0].id] == ["thimble_tonic"],
		"only the retired pocket identity changes; survivor ownership is preserved")
	for key in ["satchel", "gold", "scraps", "candle", "patches", "map", "rng", "receipts", "battle"]:
		_check(after[key] == before[key], "replacement preserves unrelated " + key)
	var service_party: Array = after.heroes.duplicate(true)
	service_party[lost_index].erase("position")
	_check(not authority.read_state().open and authority.read_state().version == 1
		and authority.read_state().party == service_party and after.pending.replaced
		and not session.visit_actions().any(func(offered: Dictionary): return offered.id == "replace"),
		"exactly one sealed service replacement is consumed while other Circle choices remain")
	_check(session.journal.size() == journal.size() + 1
		and session.journal.back() == {"action": "visit", "id": "replace", "arguments": args}
		and session.pending.steps.size() == before.pending.steps.size() + 1,
		"one deterministic replacement command and Circle step are journaled")
	_check(twin != null and twin.snapshot() == after and twin.journal == session.journal, "mounted and detached actions agree exactly")
	button.pressed.emit()
	_check(not session.choose_visit("replace", args, before) and not session.choose_visit("replace", args, after)
		and session.snapshot() == after, "stale and replayed replacement requests cannot apply twice")
	var document := StitchedRunSave.capture(session)
	for invalid in [null, [], [args[0], 1], [args[0], lost_id, {}], [args[0], living[0].id], ["forged", lost_id]]:
		var corrupt := document.duplicate(true)
		corrupt.journal[-1].arguments = invalid
		corrupt.digest = StitchedRunSave._digest(corrupt)
		_check(StitchedRunSave.restore(corrupt) == null, "malformed replacement replay rejects even with a valid digest")
	var doubled := document.duplicate(true)
	doubled.journal.append(doubled.journal.back().duplicate(true))
	doubled.digest = StitchedRunSave._digest(doubled)
	_check(StitchedRunSave.restore(doubled) == null, "duplicate replacement replay fails closed")
	for field in ["id", "hp", "parts"]:
		var corrupt := document.duplicate(true)
		corrupt.state.heroes[lost_index][field] = "forged"
		corrupt.digest = StitchedRunSave._digest(corrupt)
		_check(StitchedRunSave.restore(corrupt) == null and session.snapshot() == after,
			"rehashed saved replacement " + field + " must match truthful replay")
	var reopened := document.duplicate(true)
	reopened.state.pending.erase("replaced")
	reopened.digest = StitchedRunSave._digest(reopened)
	_check(StitchedRunSave.restore(reopened) == null, "saved state cannot reopen a consumed replacement")
	_reload(app, "replaced Circle")
	session = app.stitched_run_session
	var leave := _button(app, "leave")
	leave.pressed.emit()
	_check(session.phase == "map" and session.receipts.back().steps[0].action == "replace",
		"existing Leave settles the Circle with its truthful replacement step")
	var onward_id := ""
	for id in session.choices():
		if session.map.get_node(id).type in ["Fight", "Elite"]:
			onward_id = id
	_check(not onward_id.is_empty() and _press_route(app, onward_id), "replacement continues into a real connected ranked battle")
	stage = app.stitched_run_battle
	_check(stage != null and stage.battle == session.battle, "follow-on battle is actually mounted")
	if stage != null:
		var installed := stage.battle.get_unit(args[0])
		# The mounted battle opens with foe initiative, so the replacement can
		# legitimately take authenticated opening damage before this check.
		# Derive the exact post-opening HP from the canonical receipts instead of
		# the starter's pre-battle full HP.
		var opening_hp: int = expected_hero.hp
		var opening_bleed := 0
		for receipt in stage.receipts:
			for hit in receipt.get("results", []):
				if str(hit.get("target", "")) != args[0]:
					continue
				opening_hp = int(hit["target_hp"])
				for status in hit.get("statuses", []):
					if str(status.get("status", "")) == "bleed":
						opening_bleed = maxi(opening_bleed, int(status["duration"]))
		# Bleed ticks at the start of the affected doll's turn. The tick is
		# recorded in unit state rather than a damage receipt, so account for it
		# only when the applied duration has actually decremented.
		if opening_bleed > 0 and int(installed.get("statuses", {}).get("bleed", 0)) < opening_bleed:
			opening_hp -= opening_bleed
		_check(not installed.is_empty() and installed.parts == expected_hero.parts and installed.rank == expected_hero.rank
			and installed.hp == opening_hp and not installed.lost
			and stage.battle.get_unit(lost_id).is_empty(), "follow-on battle owns the replacement's truthful identity, rank, gear and HP")
		var restored := StitchedRunSave.restore(StitchedRunSave.capture(session))
		_check(restored != null and restored.snapshot() == session.snapshot(), "onward battle replays the exact replaced snapshot and RNG")
		var entered := session.snapshot()
		_check(not session.choose_visit("replace", args, entered) and session.snapshot() == entered,
			"old Circle action is inert in the onward battle")
		_check(_act(stage), "follow-on battle can spend a genuine mounted turn after replacement")
	app.free()
	await process_frame


func _hanging_circle() -> void:
	var app: Node = await _new_run(0)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		app.free()
		return
	session.s14_enabled = false
	session._seal()
	app._present_stitched_run()
	var fight_id := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Fight":
			fight_id = id
	_check(not fight_id.is_empty() and _press_route(app, fight_id), "Hanging witness enters real combat")
	var stage: StitchedBattleScreen = app.stitched_run_battle
	if stage == null:
		app.free()
		return
	for step in range(500):
		if stage.battle.is_over() or stage.battle.get_heroes().any(func(hero: Dictionary): return hero.hanging):
			break
		stage._action_buttons["pass"].pressed.emit()
	for step in range(10):
		if stage.battle.is_over():
			break
		stage._action_buttons["retreat"].pressed.emit()
	_check(stage.battle.outcome() == "retreated"
		and stage.battle.get_heroes().any(func(hero: Dictionary): return hero.hanging and not hero.lost),
		"public retreat carries a genuinely Hanging doll out of combat")
	if stage.battle.outcome() != "retreated":
		app.free()
		return
	stage._action_buttons["exit"].pressed.emit()
	var shop_id := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Shop":
			shop_id = id
	_check(not shop_id.is_empty() and _press_route(app, shop_id), "Hanging roster reaches connected Shop")
	var leave := _button(app, "leave")
	if leave == null:
		app.free()
		return
	leave.pressed.emit()
	_check(session.choices().has("f03_n3") and _press_route(app, "f03_n3"), "Hanging roster mounts connected Circle")
	var hanging := session.heroes.filter(func(hero: Dictionary): return hero.hanging and not hero.lost)
	_check(not hanging.is_empty(), "mounted Circle has a non-vacuous Hanging witness")
	for hero in hanging:
		_check(hero.hp == 0 and not session.visit_actions().any(func(action: Dictionary):
			return action.id == "replace" and action.arguments[1] == hero.id),
			"zero HP alone never creates a replacement offer")
		var before := session.snapshot()
		_check(not session.choose_visit("replace", ["scarecrow", hero.id], before)
			and session.snapshot() == before, "mounted Hanging replacement request fails without effects")
	app.free()
	await process_frame


func _run() -> void:
	await _healthy_circle()
	await _hanging_circle()
	await _lost_circle()
	DirAccess.remove_absolute(SAVE_PATH)
	for message in failures:
		printerr(message)
	print("stitched_s6_routed_replacement_live_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
