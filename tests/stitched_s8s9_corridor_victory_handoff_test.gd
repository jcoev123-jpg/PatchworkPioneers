extends SceneTree
## S8/S9: the public seeded Walk -> Fight -> victory Continue -> map -> title Continue handoff.
const SAVE_PATH := "user://stitched_s8s9_corridor_victory_handoff_test.save"
var failures: Array[String] = []
var checks := 0
var explored_curios := 0
var answered_horrors := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)


func _press(button: BaseButton, description: String) -> bool:
	var live := is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree() and not button.disabled
	_check(live, "mounted enabled control: " + description)
	if live:
		button.pressed.emit()
	return live


func _app(seed_number: int) -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = seed_number
	app.stitched_walks = true
	app.stitched_save_path = SAVE_PATH
	root.add_child(app)
	return app


func _ticket(app: Node, kind: String = "") -> Button:
	var session: StitchedRunSession = app.stitched_run_session
	if session == null or session.phase != "map":
		return null
	for button: Button in app.stitched_run_buttons:
		var id := str(button.get_meta("route_id", ""))
		if id in session.choices() and (kind.is_empty() or str(session.map.get_node(id).type) == kind):
			if str(session.map.get_node(id).type) != "Boss":
				return button
	return null


func _walk_to_stop(app: Node, ordinal: int, expected_id: String) -> bool:
	var session: StitchedRunSession = app.stitched_run_session
	var ready := session != null and session.phase == "walk" and session.walk != null \
		and is_instance_valid(app.stitched_run_walk)
	_check(ready, "Walk %d is actually hosted" % ordinal)
	if not ready:
		return false
	var walker: StitchedWalkScreen = app.stitched_run_walk
	_check(walker.host == session and walker.walk == session.walk and walker.is_visible_in_tree(),
		"Walk %d has genuine live movement controls" % ordinal)
	var steps := 0
	while is_instance_valid(app.stitched_run_walk) and steps < 40:
		walker = app.stitched_run_walk
		var curio: Dictionary = walker.current_curio()
		if not curio.is_empty() and not walker.walk.tug_unresolved():
			var previous := session.journal.size()
			var offered := walker.walk.curio_choices(str(curio.instance))
			_check(not offered.is_empty() and walker.event_panel.is_visible_in_tree()
				and walker.event_buttons.size() == offered.size(), "placed curio offers genuine mounted choices")
			if offered.is_empty() or walker.event_buttons.size() != offered.size() or not _press(walker.event_buttons[0], "placed curio " + str(curio.id)):
				return false
			await process_frame
			_check(session.journal.size() == previous + 1 and session.journal.back().action == "walk"
				and session.journal.back().command.kind == "curio" and session.is_consistent(),
				"curio resolves once through its visible player choice and journals its actual effects")
			explored_curios += 1
			continue
		steps += 1
		var next_horror := walker.walk.tug_unresolved()
		var previous_journal := session.journal.size()
		if not _press(walker.forward_button, "Walk %d forward / tug %d" % [ordinal, steps]):
			return false
		await process_frame
		if next_horror:
			_check(session.journal.size() == previous_journal + 1
				and session.journal.back().get("command", {}).get("kind") == "tug",
				"real tug horror is settled by the mounted Walk button")
			answered_horrors += 1
	var arrived := steps > 0 and steps < 40 and session.walk == null \
		and not is_instance_valid(app.stitched_run_walk) and session.phase in ["visit", "battle"] \
		and session.walk_receipts.size() == ordinal \
		and str(session.walk_receipts.back().get("node_id", "")) == expected_id
	_check(arrived, "Walk %d arrives with exactly its true stop receipt" % ordinal)
	return arrived


func _corridor(app: Node, session: StitchedRunSession) -> StitchedCorridorFight:
	var views := app.find_children("CorridorFight", "Control", true, false)
	var engine: StitchedBattleScreen = app.stitched_run_battle
	var good: bool = session != null and session.phase == "battle" and session.battle != null \
		and views.size() == 1 and is_instance_valid(engine) and engine.battle == session.battle \
		and engine.is_visible_in_tree() and not app.title_view.visible
	var fight: StitchedCorridorFight = views[0] as StitchedCorridorFight if views.size() == 1 else null
	_check(good and fight != null and fight.engine == engine and fight.battle == session.battle \
		and fight.is_visible_in_tree() and fight.get_parent() == engine,
		"exactly one live corridor overlays the session's authoritative Fight")
	return fight if good else null


func _fight_to_victory(fight: StitchedCorridorFight, session: StitchedRunSession) -> bool:
	var screen: StitchedBattleScreen = fight.engine
	var hand_before := session.journal.size()
	_check(fight.hand_buttons.has("shield_candle") and session.battle.hand_action_open(),
		"Wren's free Shield hand is mounted and unspent on the public hero turn")
	if fight.hand_buttons.has("shield_candle"):
		_press(fight.hand_buttons["shield_candle"], "Wren's mounted Shield the Candle hand")
	_check(session.journal.size() == hand_before + 1
		and session.journal.back().get("action") == "battle"
		and session.journal.back().get("method") == "use_hand_action"
		and session.journal.back().get("arguments", [])[0] == "shield_candle"
		and session.is_consistent(), "Wren's hand commits exactly one authentic budgeted battle receipt")
	var attacks := 0
	var waits := 0
	var turns := 0
	while not session.battle.is_over() and turns < 250:
		turns += 1
		if session.battle.current_side() != "hero":
			_check(false, "the real engine returns to a playable doll turn")
			break
		var committed := false
		# Prefer damaging parts. A one-target part may commit immediately in choose_part.
		for slot in ["arms", "legs", "torso", "head"]:
			if fight.part_buttons[slot].disabled:
				continue
			var before := session.journal.size()
			var result := fight.choose_part(slot)
			if str(result.get("pending", "")) == slot:
				var targets := screen.legal_targets()
				if not targets.is_empty():
					var target: String = str(targets.keys()[0])
					for key in targets:
						if str(key).begins_with("foe_"):
							target = str(key)
							break
					result = fight.click_figure(target.get_slice("_", 0), int(target.get_slice("_", 1)))
			if session.journal.size() > before:
				_check(result.get("ok") == true and session.journal.back().get("action") == "battle" \
					and session.is_consistent(), "mounted body-part attack commits one real battle command")
				attacks += 1
				committed = true
				break
			# A rejected/pending part is not a turn; clear the selection through the same control.
			if screen._selected_part == slot:
				fight.choose_part(slot)
		if not committed:
			var previous := session.journal.size()
			if not _press(fight.more_button, "More for legal Pass"):
				break
			if not _press(fight.more_buttons["pass"], "Pass the doll's turn"):
				break
			_check(session.journal.size() > previous and session.journal[previous].get("method") == "pass_turn" \
				and session.is_consistent(), "Pass is journaled through the visible More menu")
			waits += 1
		await process_frame
	var won := session.battle != null and session.battle.is_over() and session.battle.outcome() == "victory"
	_check(won and turns < 250 and attacks >= 3, 
		"four dolls genuinely win seeded corridor Fight with %d part actions and %d passes in %d turns" % [attacks, waits, turns])
	return won



## The 50-seed cohort's actual lawful survival priorities (no HP writes or forced outcome).
## Kept in this mounted gate so the same seeded party can reach an authentic terminal.
func _route_node(session: StitchedRunSession) -> String:
	var choices := session.choices()
	if choices.is_empty():
		return ""
	var wounded := session.heroes.any(func(h: Dictionary): return not h.lost and h.hp < h.max_hp)
	var lost := session.heroes.any(func(h: Dictionary): return h.lost)
	var priorities := ["SewingCircle", "Campfire", "Rest", "Shop", "Peddler", "PatchStall",
		"Treasure", "Event", "Unpicker", "Fight", "Elite", "Boss"]
	if not wounded:
		priorities.erase("Campfire")
		priorities.erase("Rest")
		priorities.insert(7, "Campfire")
		priorities.insert(8, "Rest")
	if not lost:
		priorities.erase("SewingCircle")
		priorities.insert(4, "SewingCircle")
	for kind in priorities:
		for node_id in choices:
			if session.map.get_node(node_id).type == kind:
				return str(node_id)
	return str(choices[0])


func _walk_command(session: StitchedRunSession) -> Dictionary:
	var walk := session.walk
	var state := walk.snapshot()
	var actor := str(state.get("viewpoint", ""))
	if actor.is_empty():
		return {}
	if walk.tug_unresolved():
		return {"kind": "tug", "actor": actor, "target": state.tug.id, "choice": "yield"}
	for curio in state.curios:
		if curio.step == state.step and not bool(curio.get("resolved", false)):
			var choices := walk.curio_choices(curio.instance)
			if not choices.is_empty():
				return {"kind": "curio", "actor": actor, "target": curio.instance, "choice": choices[0]}
	return {"kind": "forward", "actor": actor}


func _visit_command(session: StitchedRunSession) -> Dictionary:
	var actions := session.visit_actions()
	var kind := str(session.pending.get("service", ""))
	var steps: Array = session.pending.get("steps", [])
	var lost := session.heroes.any(func(h: Dictionary): return h.lost)
	var wounded := session.heroes.any(func(h: Dictionary): return not h.lost and h.hp < h.max_hp)
	var preferences: Array = ["leave"]
	if kind == "SewingCircle" and steps.size() < 3:
		preferences = ["replace", "mend", "upgrade", "leave"] if lost else ["mend", "upgrade", "leave"]
	elif kind == "Campfire":
		preferences = ["mend", "tell_tales", "trim_the_wick", "leave"] if wounded else ["tell_tales", "trim_the_wick", "leave"]
	elif kind == "Peddler":
		preferences = ["bandage", "buy_candle_stub", "leave"] if wounded else ["buy_candle_stub", "leave"]
	for preferred in preferences:
		for action in actions:
			if action.enabled and action.id == preferred:
				if preferred == "buy_candle_stub" and session.candle > 50:
					continue
				return action
	for action in actions:
		if action.enabled:
			return action
	return {}


func _ability_score(ability: Dictionary, targets: Array, actor: Dictionary) -> int:
	var side := str(ability.get("target_side", ""))
	var kind := str(ability.get("kind", ""))
	var damage: Array = ability.get("dmg", [0, 0])
	var high := int(damage.back()) if not damage.is_empty() else 0
	var score := 5
	if side == "enemy":
		score = 25 + high * 4
		for target in targets:
			if int(target.hp) > 0 and int(target.hp) <= maxi(1, high):
				score += 12
			if int(target.hp) > 0:
				score += 1
	elif kind == "heal":
		var missing := 0
		for target in targets:
			missing = maxi(missing, int(target.get("max_hp", 0)) - int(target.get("hp", 0)))
		score = 10 + mini(50, missing * 3) if missing >= 5 else 1
	elif side == "self":
		score = 4
	if actor.side == "foe" and side == "enemy":
		score += 10
	return score


func _battle_command(battle: StitchedRules, catalog: Dictionary) -> Dictionary:
	var actor_id := battle.current_actor_id()
	var actor := battle.get_unit(actor_id)
	if actor.is_empty() or not actor.get("side") in ["hero", "foe"]:
		return {"ok": false, "error": "invalid actor"}
	var candidates: Array = []
	var abilities: Array = []
	if actor.side == "hero":
		for slot in ["head", "arms", "torso", "legs"]:
			if not actor.get("parts", {}).has(slot):
				continue
			var worn: Dictionary = actor.parts[slot]
			if worn.get("torn", true) or not catalog.has(str(worn.get("id", ""))):
				continue
			var ability: Dictionary = StitchedParts.ability_at_tier(catalog[worn.id], int(worn.tier))
			if not ability.is_empty():
				abilities.append({"id": worn.id, "ability": ability})
	else:
		for ability in actor.get("abilities", []):
			abilities.append({"id": ability.id, "ability": ability})
	for entry in abilities:
		var ability: Dictionary = entry.ability
		if not StitchedParts.ranks_allowed(int(ability.launch_mask), int(actor.rank)):
			continue
		if not battle._self_move_gate(actor, ability).is_empty():
			continue
		for rank in range(1, 5):
			var targets := battle._legal_targets(actor, ability, rank)
			if targets.is_empty():
				continue
			if actor.get("walk_intruder", false):
				var alive := battle.get_heroes().filter(func(h: Dictionary): return not h.lost)
				if alive.is_empty() or int(alive.back().rank) != rank:
					continue
			candidates.append({"id": entry.id, "rank": rank,
				"score": _ability_score(ability, targets, actor)})
	if not candidates.is_empty():
		candidates.sort_custom(func(a: Dictionary, b: Dictionary):
			if a.score == b.score:
				return str(a.id) < str(b.id) if a.id != b.id else a.rank < b.rank
			return a.score > b.score)
		var chosen: Dictionary = candidates[0]
		return battle.use_part(chosen.id, chosen.rank) if actor.side == "hero" \
			else battle.use_foe_ability(chosen.id, chosen.rank)
	if actor.side == "hero":
		for direction in [-1, 1]:
			var target_rank: int = int(actor.rank) + direction
			if target_rank < 1 or target_rank > 4:
				continue
			var neighbor := battle.get_heroes().filter(func(h: Dictionary):
				return not h.lost and int(h.rank) == target_rank)
			if int(actor.statuses.get("tangled", 0)) == 0 and not battle.is_held(actor_id) \
					and battle.thread_cuts().is_empty() and (neighbor.is_empty() \
					or int(neighbor[0].statuses.get("tangled", 0)) == 0):
				return battle.move(direction)
	return battle.pass_turn()


## Continue only through authoritative public route/rules commands, using the
## same full-route policy as stitched_50_seed_cohort_test. No state injection.
func _to_terminal(session: StitchedRunSession, label: String) -> Dictionary:
	var previous_phase := ""
	var phase_steps := 0
	var phases := 0
	var previous_key := ""
	var action_count := 0
	var initial_receipts := session.receipts.size()
	var initial_floor := session.map.get_current_floor()
	for tick in range(100000):
		if session.phase in ["victory", "defeat"]:
			break
		var key := str(session.phase) + ":" + str(session.pending.get("node_id", ""))
		if key != previous_key:
			previous_key = key
			phase_steps = 0
			phases += 1
		phase_steps += 1
		var limit := 450 if session.phase == "walk" else 600 if session.phase == "battle" else 24 if session.phase == "visit" else 1
		if phase_steps > limit or phases > 500:
			_check(false, label + " stalled at " + key)
			return {}
		var before := session.snapshot()
		var previous_receipts := session.receipts.size()
		var before_journal := session.journal.size()
		var before_walks := session.walk_receipts.size()
		var ok := false
		match session.phase:
			"map":
				var id := _route_node(session)
				ok = not id.is_empty() and session.enter(id, before)
				if ok:
					_check(session.candle == maxi(0, int(before.candle) - StitchedRunSession.NODE_CANDLE_COST)
						and session.receipts.size() == previous_receipts
						and session.journal.back() == {"action": "enter", "node_id": id},
						label + " lawful map entry has one candle toll and no early reward")
			"walk":
				var command := _walk_command(session)
				ok = not command.is_empty() and bool(session.walk_act(command, before).get("ok", false))
				if ok:
					_check(session.journal.back() == {"action": "walk", "command": command}
						and session.walk_receipts.size() - before_walks in [0, 1],
						label + " one seeded Walk action and at most one walk receipt")
			"visit":
				var choice := _visit_command(session)
				ok = not choice.is_empty() and session.choose_visit(choice.id, choice.arguments, before)
				if ok:
					_check(session.journal.back().get("id") == choice.id
						and session.receipts.size() - previous_receipts in [0, 1],
						label + " one offered visit decision and at most one receipt")
			"battle":
				if session.battle == null or not session.battle.is_valid():
					break
				if session.battle.is_over():
					ok = session.settle_battle(session.battle)
					if ok:
						_check(session.journal.back() == {"action": "settle"}
							and session.receipts.size() == previous_receipts + 1,
							label + " one authentic Fight settlement")
				else:
					ok = bool(_battle_command(session.battle, session.catalog).get("ok", false))
			_:
				break
		if not ok or not session.is_consistent() or session.journal.size() != before_journal + 1:
			_check(false, label + " refused or nonjournaled legal action at " + key)
			return {}
		action_count += 1
	var bosses := session.receipts.filter(func(receipt: Dictionary): return receipt.get("kind") == "Boss")
	var route := session.map.get_route()
	var nodes := {}
	for receipt in session.receipts:
		nodes[receipt.get("node_id", "")] = true
	_check(session.phase in ["victory", "defeat"] and action_count > 0
		and session.receipts.size() > initial_receipts and session.map.get_current_floor() >= initial_floor
		and route.size() == session.receipts.size() and nodes.size() == route.size(),
		label + " genuinely completes a unique-receipt seeded route")
	if session.phase == "victory":
		_check(route.size() == 12 and session.map.get_current_floor() == 12
			and bosses.size() == 1 and bosses[0].outcome == "victory"
			and session.map.get_node(bosses[0].node_id).type == "Boss"
			and bosses[0].node_id == route.back(),
			label + " settles exactly one floor-12 Boss victory")
	else:
		_check(session.phase == "defeat" and bosses.size() <= 1
			and (bosses.is_empty() or bosses[0].outcome == "defeat"),
			label + " authentic defeat has no fabricated Boss victory")
	return {"state": session.snapshot(), "journal": session.journal.duplicate(true),
		"receipts": session.receipts.duplicate(true),
		"walks": session.walk_receipts.duplicate(true), "rng": session.rng.state,
		"outcome": session.phase, "route": route.duplicate(true)}


func _hero_contract(expected: Array, actual: Array, description: String) -> void:
	_check(expected.size() == 4 and actual.size() == 4, description + ": all four dolls are present")
	if expected.size() != actual.size():
		return
	for index in expected.size():
		var a: Dictionary = expected[index]
		var b: Dictionary = actual[index]
		_check(a.get("id") == b.get("id") and a.get("hp") == b.get("hp") \
			and a.get("fray") == b.get("fray") and a.get("parts") == b.get("parts") \
			and a.get("lost") == b.get("lost"),
			description + ": " + str(a.get("id")) + " preserves HP/fray/equipped gear/loss")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH + ".tmp")
	# Seed 18's live Event draw is pinned to the real Thimble Raincollector here so
	# shared catalog growth cannot retarget this witness: its free non-Leave action
	# grants one scrap, with an authentic placed curio and thread-tug horror.
	StitchedRunSession.pinned_event_id = "v3_thimble_raincollector"
	var app := _app(18)
	await process_frame
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.stitched_run_session == null,
		"fresh title has no fixture battle")
	if not _press(app.start_button, "New Run"):
		_finish(app)
		return
	await process_frame
	if app.stitched_run_buttons.is_empty() or not _press(app.stitched_run_buttons[0], "four-doll Set out"):
		_finish(app)
		return
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.seed_value == 18 and session.heroes.size() == 4 \
		and session.walks_enabled and session.is_consistent(), "real seed 53 four-doll Walk session")
	if session == null:
		_finish(app)
		return
	var begin: Button = app.stitched_run_intro.find_child("WrenIntroBegin", true, false) as Button \
		if is_instance_valid(app.stitched_run_intro) else null
	if not _press(begin, "Begin the night"):
		_finish(app)
		return
	await process_frame
	var event := _ticket(app, "Event")
	var before_event_entry := session.snapshot()
	var event_entries := session.journal.size()
	if not _press(event, "legal Event ticket"):
		_finish(app)
		return
	var event_id := str(event.get_meta("route_id"))
	await process_frame
	_check(session.candle == maxi(0, int(before_event_entry.candle) - StitchedRunSession.NODE_CANDLE_COST)
		and session.journal.size() == event_entries + 1
		and session.journal.back() == {"action": "enter", "node_id": event_id}
		and session.receipts.is_empty() and session.walk_receipts.is_empty(),
		"first entry charges exactly one candle toll before any Walk or Event receipt")
	if not await _walk_to_stop(app, 1, event_id) or session.phase != "visit" \
		or session.pending.get("service") != "Event":
		_check(false, "seeded Event reaches an authentic public service")
		_finish(app)
		return
	var first_carry: Array = session.walk_receipts[0].get("pending", [])
	var torn: Array = first_carry.filter(func(item: Dictionary): return item.get("kind") == "torn_part")
	var torn_hero := session.heroes.filter(func(hero: Dictionary):
		return hero.id == "lantern_monk")
	_check(torn.size() == 1 and torn[0].get("target") == "lantern_monk"
		and torn[0].get("effects", {}).get("slot") == "torso"
		and torn_hero.size() == 1 and torn_hero[0].parts.torso.torn
		and session.walk_receipts.size() == 1 and session.is_consistent(),
		"the thread-tug horror tears exactly the reported equipped torso once")
	_check(explored_curios >= 1 and answered_horrors >= 1
		and session.walk_receipts[0].get("pending", []).any(func(item: Dictionary):
			return item.get("kind") in ["torn_part", "mimic", "cut_thread"]),
		"first public Walk resolves placed curio and horror with real pending carry")
	var event_receipts := session.receipts.size()
	var before_event := session.snapshot()
	var before_event_journal := session.journal.size()
	var event_choice: Button
	for button: Button in app.stitched_run_buttons:
		if str(button.get_meta("action_id", "")) == "collect_gutter_offcuts" and not button.disabled:
			event_choice = button
			break
	_check(str(session.pending.get("event_id", "")) == "v3_thimble_raincollector"
		and event_choice != null and session.visit_actions().any(func(action: Dictionary):
			return action.id == "collect_gutter_offcuts" and action.enabled),
		"seeded Event offers the specific affordable collect-gutter-offcuts receipt")
	var refused := session.choose_visit("forged", [], before_event)
	var stale := before_event.duplicate(true)
	stale.candle += 1
	var stale_refused := session.choose_visit("collect_gutter_offcuts", [], stale)
	_check(not refused and not stale_refused and session.snapshot() == before_event
		and session.journal.size() == before_event_journal
		and session.receipts.size() == event_receipts
		and session.rng.state == before_event.rng, "forged and stale Event actions cannot spend or draw")
	if not _press(event_choice, "Event collect gutter offcuts (not Leave)"):
		_finish(app)
		return
	await process_frame
	_check(session.phase == "map" and session.receipts.size() == event_receipts + 1
		and session.receipts.back().get("decision") == "collect_gutter_offcuts"
		and session.receipts.back().get("event_id") == "v3_thimble_raincollector"
		and session.gold == before_event.gold and session.scraps == before_event.scraps + 1
		and session.candle == before_event.candle
		and session.journal.size() == before_event_journal + 1
		and session.journal.back().get("id") == "collect_gutter_offcuts"
		and session.is_consistent(), "one authenticated consequential Event receipt grants exactly one scrap")
	var event_settled := session.snapshot()
	_check(not session.choose_visit("collect_gutter_offcuts", [], before_event)
		and session.snapshot() == event_settled and session.rng.state == event_settled.rng,
		"duplicate Event command cannot repeat reward or RNG draw")
	var fight_ticket := _ticket(app, "Fight")
	var before_fight_entry := session.snapshot()
	var fight_entries := session.journal.size()
	if not _press(fight_ticket, "next legal Fight ticket"):
		_finish(app)
		return
	var fight_id := str(fight_ticket.get_meta("route_id"))
	await process_frame
	_check(session.candle == maxi(0, int(before_fight_entry.candle) - StitchedRunSession.NODE_CANDLE_COST)
		and session.journal.size() == fight_entries + 1
		and session.journal.back() == {"action": "enter", "node_id": fight_id}
		and session.receipts.size() == 1 and session.walk_receipts.size() == 1,
		"second route entry pays one toll, preserves Event settlement and opens a distinct Walk")
	if not await _walk_to_stop(app, 2, fight_id):
		_finish(app)
		return
	var corridor := _corridor(app, session)
	if corridor == null:
		_finish(app)
		return
	_check(corridor.find_children("FoeIntent*", "", true, false).is_empty(),
		"owner 11-08: live mounted corridor shows no foe intent plates")
	_check(session.receipts.filter(func(receipt: Dictionary): return receipt.get("kind") == "Fight").is_empty() \
		and session.walk_receipts.size() == 2 and not corridor.continue_button.visible \
		and not session.battle.is_over(),
		"Fight enters without its own settlement; Continue is not offered before victory")
	var before_early := session.snapshot()
	var early_journal := session.journal.duplicate(true)
	var early_receipts := session.receipts.duplicate(true)
	# Exercise the actual Continue callback while hidden: it must not exit or settle.
	corridor.continue_button.pressed.emit()
	_check(session.phase == "battle" and app.stitched_run_battle == corridor.engine \
		and session.snapshot() == before_early and session.journal == early_journal \
		and session.receipts == early_receipts, "premature Continue cannot exit, pay or spend RNG")
	if not await _fight_to_victory(corridor, session):
		_finish(app)
		return
	await process_frame
	var battle := session.battle
	var final_heroes: Array = battle.get_heroes().duplicate(true)
	var battle_satchel: Array = battle.satchel().duplicate(true)
	var previous_walks := session.walk_receipts.duplicate(true)
	var previous_receipts := session.receipts.duplicate(true)
	var previous_journal := session.journal.duplicate(true)
	var gold_before := session.gold
	var scraps_before := session.scraps
	var candle_before := session.candle
	var pockets_before := session.pockets.duplicate(true)
	var patches_before := session.patches.duplicate(true)
	var fear_before := session.kid_fear()
	_check(corridor.continue_button.is_visible_in_tree() and not corridor.continue_button.disabled \
		and corridor.outcome_label.visible and corridor.outcome_label.text == "VICTORY",
		"visible enabled post-victory Continue is the public exit")
	if not _press(corridor.continue_button, "victory Continue"):
		_finish(app)
		return
	# The original signal may still be invoked in this same frame; settlement must be one-shot.
	corridor.continue_button.pressed.emit()
	await process_frame
	_check(session.phase == "map" and session.battle == null and session.pending.is_empty() \
		and app.stitched_run_battle == null and app.stitched_run_panel != null \
		and app.stitched_run_panel.is_visible_in_tree() and app.find_children("CorridorFight", "Control", true, false).is_empty(),
		"only Continue returns to a live routed map, never a second Fight")
	_check(session.receipts.size() == previous_receipts.size() + 1 \
		and session.receipts.slice(0, previous_receipts.size()) == previous_receipts \
		and session.journal.size() == previous_journal.size() + 1 \
		and session.journal.slice(0, previous_journal.size()) == previous_journal \
		and session.journal.back() == {"action": "settle"} \
		and session.walk_receipts == previous_walks and session.is_consistent(),
		"one and only one Fight settlement receipt, journal settle and intact old Walk receipts")
	if session.receipts.size() != previous_receipts.size() + 1:
		_finish(app)
		return
	var receipt: Dictionary = session.receipts.back()
	var reward: Dictionary = receipt.get("reward", {})
	var awarded: Array = reward.get("parts", [])
	var expected_satchel: Array = battle_satchel.duplicate(true)
	expected_satchel.append_array(awarded)
	_check(receipt.get("node_id") == fight_id and receipt.get("kind") == "Fight" \
		and receipt.get("outcome") == "victory" and reward.has("gold") \
		and reward.has("scraps") and reward.has("parts") and awarded.size() <= 1,
		"receipt belongs to exactly the won routed Fight and describes its real random award")
	_check(session.gold == gold_before + int(reward.get("gold", -999)) \
		and session.scraps == scraps_before + int(reward.get("scraps", -999)) \
		and session.satchel == expected_satchel, "gold, scraps and optional trophy exactly equal receipt payouts")
	_check(session.candle == candle_before and session.pockets == pockets_before \
		and session.patches == patches_before and session.kid_fear() == fear_before,
		"settlement retains candle, pockets, patches and Wren's state")
	_hero_contract(final_heroes, session.heroes, "post-victory")
	var settled_snapshot := session.snapshot()
	var settled_journal := session.journal.duplicate(true)
	var settled_receipts := session.receipts.duplicate(true)
	var settled_walks := session.walk_receipts.duplicate(true)
	var settled_rng := session.rng.state
	# A duplicate stale signal, including one after the old stage is removed, has no entry point.
	_check(session.snapshot() == settled_snapshot and session.receipts == settled_receipts \
		and session.journal == settled_journal, "double Continue grants no second settlement")
	var save: BaseButton
	for button: Button in app.stitched_run_buttons:
		if button.text == "Save run" and button.is_visible_in_tree():
			save = button
			break
	if not _press(save, "mounted map Save run"):
		_finish(app)
		return
	var saved := StitchedRunSave.read_file(SAVE_PATH)
	_check(FileAccess.file_exists(SAVE_PATH) and saved != null and saved.snapshot() == settled_snapshot \
		and saved.journal == settled_journal and saved.receipts == settled_receipts \
		and saved.walk_receipts == settled_walks and saved.rng.state == settled_rng,
		"map Save persists the exact won snapshot, settlement, walks, journal and RNG")
	if saved == null:
		_finish(app)
		return
	app.free()
	await process_frame
	var fresh := _app(999)
	await process_frame
	await process_frame
	_check(fresh.title_view.is_visible_in_tree() and fresh.stitched_run_session == null,
		"fresh instance begins at title, not retained prior map")
	if not _press(fresh.stitched_continue_button, "fresh title Continue"):
		_finish(fresh)
		return
	await process_frame
	var restored: StitchedRunSession = fresh.stitched_run_session
	_check(restored != null and restored != session and restored.snapshot() == settled_snapshot \
		and restored.journal == settled_journal and restored.receipts == settled_receipts \
		and restored.walk_receipts == settled_walks and restored.rng.state == settled_rng \
		and restored.is_consistent() and restored.phase == "map" \
		and fresh.stitched_run_panel.is_visible_in_tree(),
		"title Continue recreates complete settled map, receipts, journal and RNG")
	if restored == null:
		_finish(fresh)
		return
	var next_ticket := _ticket(fresh)
	_check(next_ticket != null and restored.choices().size() > 0 \
		and restored.candle >= StitchedRunSession.NODE_CANDLE_COST,
		"restored map has a new legal non-Boss node and enough candle for its toll")
	if next_ticket == null:
		_finish(fresh)
		return
	var new_id := str(next_ticket.get_meta("route_id"))
	var old_candle := restored.candle
	var old_journal := restored.journal.size()
	var old_walk_count := restored.walk_receipts.size()
	var old_heroes := restored.heroes.duplicate(true)
	var old_satchel := restored.satchel.duplicate(true)
	var old_gold := restored.gold
	var old_scraps := restored.scraps
	var old_pockets := restored.pockets.duplicate(true)
	var old_patches := restored.patches.duplicate(true)
	var old_fear := restored.kid_fear()
	if not _press(next_ticket, "restored legal non-Boss route ticket"):
		_finish(fresh)
		return
	await process_frame
	_check(restored.phase == "walk" and restored.pending.get("node_id") == new_id \
		and restored.walk != null and is_instance_valid(fresh.stitched_run_walk) \
		and fresh.stitched_run_walk.is_visible_in_tree() \
		and fresh.stitched_run_walk.host == restored and fresh.stitched_run_walk.walk == restored.walk,
		"one fresh hosted Walk is mounted from a legal restored route ticket")
	_check(restored.candle == old_candle - StitchedRunSession.NODE_CANDLE_COST \
		and restored.journal.size() == old_journal + 1 \
		and restored.journal.back() == {"action": "enter", "node_id": new_id} \
		and restored.walk_receipts.size() == old_walk_count and restored.receipts == settled_receipts,
		"exactly one new node candle toll, entry and no premature Walk or Fight settlement")
	_check(restored.heroes == old_heroes and restored.satchel == old_satchel \
		and restored.gold == old_gold and restored.scraps == old_scraps \
		and restored.pockets == old_pockets and restored.patches == old_patches \
		and restored.kid_fear() == old_fear and restored.is_consistent(),
		"new Walk retains the saved dolls, gear and resources except exactly one candle toll")
	var continued := StitchedRunSave.restore(StitchedRunSave.capture(restored))
	_check(continued != null and continued.snapshot() == restored.snapshot() \
		and continued.journal == restored.journal and continued.rng.state == restored.rng.state,
		"resumed legal Walk also replays with precisely matching snapshot, journal and RNG")
	if continued == null or not await _walk_to_stop(fresh, 3, new_id):
		_finish(fresh)
		return
	# The independent, uninterrupted branch uses the exact public Walk commands
	# shown in the mounted corridor; neither branch is allowed to change HP directly.
	var replay_steps := 0
	while continued.phase == "walk" and replay_steps < 60:
		replay_steps += 1
		var command := _walk_command(continued)
		_check(not command.is_empty() and continued.walk_act(command, continued.snapshot()).get("ok") == true,
			"uninterrupted seeded third Walk uses legal forward/curio/tug command")
	_check(continued.phase == restored.phase and continued.snapshot() == restored.snapshot()
		and continued.journal == restored.journal
		and continued.walk_receipts == restored.walk_receipts
		and continued.receipts == restored.receipts
		and continued.rng.state == restored.rng.state and replay_steps > 0 and replay_steps < 60,
		"third mounted Walk and independent uninterrupted Walk converge on identical stop and RNG")
	_check(restored.walk_receipts.size() == 3 and restored.walk_receipts.back().node_id == new_id
		and restored.phase in ["visit", "battle"],
		"three distinct public Walks each settle once and Fight/Event remain in-place")
	if restored.phase == "battle":
		_check(_corridor(fresh, restored) != null,
			"third stop's Fight remains the real embedded corridor, not a standalone HUD")
	elif restored.phase == "visit":
		_check(fresh.stitched_run_panel != null and fresh.stitched_run_panel.is_visible_in_tree(),
			"third stop's Event or service remains on the embedded route page")
	var uninterrupted := _to_terminal(continued, "uninterrupted")
	var resumed_result := _to_terminal(restored, "reloaded")
	_check(not uninterrupted.is_empty() and uninterrupted == resumed_result,
		"same seed after title Continue reaches identical actual defeat/Boss ending, route, journal, receipts, pockets, heroes and RNG")
	if not resumed_result.is_empty():
		print("S8S9_ROUTE_END seed=18 outcome=%s floor=%d route_nodes=%d receipt_nodes=%d" % [
			restored.phase, restored.map.get_current_floor(), restored.map.get_route().size(), restored.receipts.size()])
	_finish(fresh)


func _finish(app: Node) -> void:
	StitchedRunSession.pinned_event_id = ""
	if is_instance_valid(app):
		app.free()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH + ".tmp")
	for failure in failures:
		printerr(failure)
	print("stitched_s8s9_corridor_victory_handoff_test: %s (%d checks, %d failures)" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
