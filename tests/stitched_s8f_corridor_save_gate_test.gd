extends SceneTree
## S8f: title -> junction door -> Event Walk -> in-place consequential Event ->
## Fight Walk -> 2-3-foe corridor -> mounted S14 signature -> corridor Save -> title Continue.
const TEST_SAVE := "user://stitched_s8f_corridor_save_gate_test.save"
const EVENT_KIND := "Event"
const FIGHT_KIND := "Fight"
const PINNED_EVENT := "v3_thimble_raincollector"
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, explanation: String) -> void:
	checks += 1
	if not condition:
		failures.append(explanation)


func _press(button: BaseButton, label: String) -> bool:
	var usable := is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled
	_check(usable, "mounted, enabled player control: " + label)
	if usable:
		button.pressed.emit()
	return usable


func _app(seed_number: int) -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = seed_number
	app.stitched_walks = true
	app.stitched_save_path = TEST_SAVE
	root.add_child(app)
	return app


## The road map is the live junction: assert the mounted page and its doors.
func _junction(app: Node, label: String) -> StitchedCorridorJunction:
	var session: StitchedRunSession = app.stitched_run_session
	var junction: StitchedCorridorJunction = app.stitched_run_panel as StitchedCorridorJunction
	_check(junction != null and junction.name == "StitchedRunPage"
		and str(junction.get_meta("page_kind", "")) == "map"
		and junction.is_visible_in_tree() and session != null and session.phase == "map",
		label + ": the road map is the live in-corridor junction")
	if junction == null or session == null:
		return null
	var choices: Array = session.choices()
	_check(not choices.is_empty() and junction.doors.size() == choices.size()
		and junction.sides.size() == choices.size(),
		label + ": every legal choice has exactly one junction door and side")
	for id in choices:
		var door: Button = junction.doors.get(id)
		_check(door != null and door.is_visible_in_tree() and not door.disabled
			and str(door.get_meta("route_id", "")) == str(id)
			and str(door.get_meta("node_kind", "")) == str(session.map.get_node(id).type)
			and str(junction.sides.get(id, "")) in ["left", "forward", "right"],
			label + ": junction door " + str(id) + " is a visible enabled mounted control")
	var save_button: Button
	for button: Button in app.stitched_run_buttons:
		if button.text == "Save run" and button.is_visible_in_tree():
			save_button = button
			break
	_check(save_button != null, label + ": the junction corner offers the public Save run")
	return junction


func _door(app: Node, kinds: Array) -> Button:
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		return null
	var junction: StitchedCorridorJunction = app.stitched_run_panel as StitchedCorridorJunction
	if junction == null:
		return null
	for id in session.choices():
		if str(session.map.get_node(id).type) in kinds:
			var door: Button = junction.doors.get(id)
			if door != null:
				return door
	return null


func _visit_button(app: Node, action_id: String) -> Button:
	for button: Button in app.stitched_run_buttons:
		if str(button.get_meta("action_id", "")) == action_id and not button.disabled:
			return button
	return null


func _walk_to_stop(app: Node, node_id: String, ordinal: int) -> bool:
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.phase == "walk" and session.walk != null
		and is_instance_valid(app.stitched_run_walk),
		"Walk %d is an authenticated mounted route" % ordinal)
	if session == null or session.walk == null or not is_instance_valid(app.stitched_run_walk):
		return false
	var walker: StitchedWalkScreen = app.stitched_run_walk
	_check(walker.host == session and walker.walk == session.walk and walker.is_visible_in_tree(),
		"Walk %d uses the real hosted Walk screen" % ordinal)
	var steps := 0
	while is_instance_valid(app.stitched_run_walk) and steps < 40:
		walker = app.stitched_run_walk
		var curio: Dictionary = walker.current_curio()
		if not curio.is_empty() and not walker.walk.tug_unresolved():
			var previous := session.journal.size()
			var offered := walker.walk.curio_choices(str(curio.instance))
			_check(not offered.is_empty() and walker.event_panel.is_visible_in_tree()
				and walker.event_buttons.size() == offered.size(),
				"placed curio offers genuine mounted choices")
			if offered.is_empty() or walker.event_buttons.size() != offered.size() \
					or not _press(walker.event_buttons[0], "placed curio " + str(curio.id)):
				return false
			await process_frame
			_check(session.journal.size() == previous + 1 and session.journal.back().action == "walk"
				and session.journal.back().command.kind == "curio" and session.is_consistent(),
				"curio resolves once through its visible player choice")
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
	var arrived := steps > 0 and steps < 40 and session.walk == null \
		and not is_instance_valid(app.stitched_run_walk) and session.phase in ["visit", "battle"] \
		and session.walk_receipts.size() == ordinal \
		and str(session.walk_receipts.back().get("node_id", "")) == node_id
	_check(arrived, "Walk %d arrives with exactly its true stop receipt" % ordinal)
	return arrived


## Save a real partially traversed corridor, then independently Continue it from
## a fresh title. Both mounted buttons must make the same next seeded command.
func _walk_save_replay(app: Node) -> void:
	var session: StitchedRunSession = app.stitched_run_session
	var walker: StitchedWalkScreen = app.stitched_run_walk
	_check(is_instance_valid(walker) and walker.walk == session.walk
		and session.walk.snapshot().step == 0, "mid-Walk witness starts on a real opening step")
	if not is_instance_valid(walker) or not _press(walker.forward_button, "mid-Walk first forward"):
		return
	await process_frame
	_check(session.phase == "walk" and session.walk != null and session.is_consistent(),
		"mid-Walk save is taken after a committed player step, not at entry")
	if session.phase != "walk":
		return
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	var receipts := session.receipts.duplicate(true)
	var walks := session.walk_receipts.duplicate(true)
	_check(StitchedRunSave.write_file(TEST_SAVE, session),
		"authoritative Save writes an independently loadable mid-Walk document")
	var stored := StitchedRunSave.read_file(TEST_SAVE)
	_check(stored != null and stored.snapshot() == before and stored.journal == journal
		and stored.receipts == receipts and stored.walk_receipts == walks
		and stored.rng.state == before.rng,
		"mid-Walk Save preserves party, pending node, pockets, ledger, receipts, RNG")
	var fresh := _app(999)
	await process_frame
	await process_frame
	if not _press(fresh.stitched_continue_button, "separate title Continue mid-Walk"):
		fresh.free()
		return
	await process_frame
	var restored: StitchedRunSession = fresh.stitched_run_session
	_check(restored != null and restored != session and restored.phase == "walk"
		and restored.snapshot() == before and restored.journal == journal
		and restored.receipts == receipts and restored.walk_receipts == walks
		and is_instance_valid(fresh.stitched_run_walk)
		and fresh.stitched_run_walk.walk == restored.walk, "title Continue mounts exact mid-Walk state")
	if restored != null and restored.phase == "walk" and session.phase == "walk":
		var baseline_walk := session.journal.size()
		var first: StitchedWalkScreen = app.stitched_run_walk
		var second: StitchedWalkScreen = fresh.stitched_run_walk
		_check(first.walk.tug_unresolved() == second.walk.tug_unresolved(),
			"next seeded Walk command has identical preconditions")
		_press(first.forward_button, "uninterrupted next Walk command")
		_press(second.forward_button, "reloaded next Walk command")
		await process_frame
		_check(session.journal.size() == baseline_walk + 1
			and restored.snapshot() == session.snapshot()
			and restored.journal == session.journal
			and restored.receipts == session.receipts
			and restored.walk_receipts == session.walk_receipts
			and restored.rng.state == session.rng.state and session.is_consistent(),
			"independent next public Walk step reproduces state, pocket budgets, receipt and RNG")
	fresh.free()
	await process_frame


func _corridors(app: Node) -> Array:
	return app.find_children("CorridorFight", "Control", true, false)


func _check_fight(app: Node, session: StitchedRunSession, label: String) -> void:
	var matches := _corridors(app)
	var stage: StitchedBattleScreen = app.stitched_run_battle
	_check(session != null and session.phase == "battle" and session.battle != null
		and session.battle_config is Dictionary and not session.battle_config.is_empty(),
		label + ": session holds a configured live battle")
	_check(matches.size() == 1 and is_instance_valid(stage) and stage.is_inside_tree()
		and stage.battle == session.battle and stage.is_visible_in_tree(),
		label + ": exactly one visible mounted corridor fight has the live session battle")
	if matches.size() == 1 and is_instance_valid(stage):
		var corridor: StitchedCorridorFight = matches[0] as StitchedCorridorFight
		_check(corridor != null and corridor.engine == stage
			and corridor.battle == session.battle and corridor.is_visible_in_tree()
			and stage.get_parent() == app,
			label + ": corridor view wraps the actual gameplay engine")


## One legal fixed S14 signature action through the mounted part buttons and hit targets only.
func _mounted_commit(corridor: StitchedCorridorFight, session: StitchedRunSession) -> Dictionary:
	var screen: StitchedBattleScreen = corridor.engine
	if session.battle == null or session.battle.is_over() or session.battle.current_side() != "hero":
		return {}
	var actor: Dictionary = session.battle.get_unit(session.battle.current_actor_id())
	var kits := StitchedS14Abilities.kits()
	for slot in ["arms", "legs", "torso", "head"]:
		if corridor.part_buttons[slot].disabled:
			continue
		if screen._selected_part == slot:
			corridor.choose_part(slot)
		var before := session.journal.size()
		var result := corridor.choose_part(slot)
		if session.journal.size() == before:
			if str(result.get("pending", "")) != slot:
				continue
			var targets := screen.legal_targets()
			if targets.is_empty():
				corridor.choose_part(slot)
				continue
			var key := ""
			for candidate in targets:
				if str(candidate).begins_with("foe_"):
					key = str(candidate)
					break
			if key.is_empty():
				key = str(targets.keys()[0])
			result = corridor.click_figure(key.get_slice("_", 0), int(key.get_slice("_", 1)))
		if session.journal.size() == before:
			continue
		var signature: Dictionary = kits.get(str(actor.get("id", "")), {}).get(slot, {})
		var results: Array = result.get("results", [])
		var struck_side := ""
		if not results.is_empty():
			struck_side = str(session.battle.get_unit(str(results[0].get("target", ""))).get("side", ""))
		var expected_side := "foe" if str(signature.get("target_side", "")) == "enemy" else "hero"
		return {"ok": result.get("ok") == true and not signature.is_empty()
				and str(result.get("ability", "")) == str(signature.get("id", ""))
				and not results.is_empty() and struck_side == expected_side,
			"slot": slot, "signature": str(signature.get("id", "")),
			"entry": session.journal[before], "results": results,
			"struck": str(results[0].get("target", "")) if not results.is_empty() else ""}
	return {}


func _write_document(document: Variant) -> void:
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	_check(file != null, "isolated negative save opens for write")
	if file != null:
		file.store_buffer(var_to_bytes(document))
		file.close()


func _rejection(app: Node, reference: StitchedRunSession, expected: Dictionary,
		label: String) -> void:
	var stage: StitchedBattleScreen = app.stitched_run_battle
	var corridor: Node = _corridors(app)[0] if _corridors(app).size() == 1 else null
	var before := reference.journal.duplicate(true)
	_check(not app.load_stitched_run(TEST_SAVE), label + ": public load rejects document")
	_check(app.stitched_run_session == reference and reference.snapshot() == expected
		and reference.journal == before and reference.rng.state == expected.rng
		and reference.is_consistent(), label + ": rejected load preserves authentic run, wallet and RNG")
	_check(app.stitched_run_battle == stage and _corridors(app).size() == 1
		and _corridors(app)[0] == corridor and not app.title_view.visible,
		label + ": rejection never replaces or duplicates the mounted corridor fight")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_SAVE + ".tmp")
	# Seed 18's live Event draw is pinned to the real Thimble Raincollector so shared
	# catalog growth cannot retarget this witness: its free non-Leave action grants one
	# scrap and one S14 ability patch, with an authentic placed curio and thread-tug horror.
	StitchedRunSession.pinned_event_id = PINNED_EVENT
	var app := _app(18)
	await process_frame
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.stitched_run_session == null,
		"fresh 1280x720 title has no run or corridor fight")
	_check(app.stitched_continue_button.is_visible_in_tree()
		and app.stitched_continue_button.disabled
		and app.stitched_continue_button.focus_mode == Control.FOCUS_NONE,
		"missing title Continue is visible but disabled and unfocusable")
	app.stitched_continue_button.pressed.emit()
	_check(app.stitched_run_session == null and app.title_view.visible
		and _corridors(app).is_empty(),
		"missing title Continue signal fails closed without creating a session or fight")
	_write_document({"version": "malformed", "state": {}})
	_check(StitchedRunSave.read_file(TEST_SAVE) == null,
		"malformed save is rejected by the authoritative reader")
	app._refresh_stitched_continue_eligibility()
	_check(app.stitched_continue_button.disabled
		and app.stitched_continue_button.focus_mode == Control.FOCUS_NONE,
		"malformed title Continue stays disabled and unfocusable")
	app.stitched_continue_button.pressed.emit()
	_check(app.stitched_run_session == null and app.title_view.visible
		and _corridors(app).is_empty(),
		"malformed title Continue signal fails closed without publishing a run or fight")
	DirAccess.remove_absolute(TEST_SAVE)
	if not _press(app.start_button, "New Run"):
		_finish(app)
		return
	await process_frame
	_check(app.stitched_run_session == null and app.stitched_run_buttons.size() == 2,
		"New Run exposes the real four-doll picker")
	if app.stitched_run_buttons.is_empty() or not _press(app.stitched_run_buttons[0], "four-doll Set out"):
		_finish(app)
		return
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.heroes.size() == 4 and session.walks_enabled
		and session.picks.size() == 4 and session.seed_value == 18 and session.s14_enabled,
		"real four selected dolls start seed 18 with Walks and fixed S14 signatures")
	if session == null:
		_finish(app)
		return
	var intro: Control = app.stitched_run_intro
	var begin: Button = intro.find_child("WrenIntroBegin", true, false) as Button \
		if is_instance_valid(intro) else null
	_check(intro != null and intro.is_visible_in_tree(), "intro is mounted before the first door")
	_press(begin, "intro Begin the night")
	await process_frame
	_check(app.stitched_run_intro == null and session.phase == "map",
		"intro dismissal reveals the live junction")
	if _junction(app, "post-intro") == null:
		_finish(app)
		return
	var event_door := _door(app, [EVENT_KIND])
	_check(event_door != null and str(event_door.get_meta("node_kind", "")) == EVENT_KIND,
		"seed 18 offers a legal visible Event junction door")
	if event_door == null:
		_finish(app)
		return
	var event_id := str(event_door.get_meta("route_id"))
	var before_event_entry := session.snapshot()
	var event_entries := session.journal.size()
	if not _press(event_door, "legal Event junction door"):
		_finish(app)
		return
	await process_frame
	_check(session.phase == "walk" and session.pending.get("node_id") == event_id
		and str(session.pending.kind) == EVENT_KIND
		and session.journal.size() == event_entries + 1
		and session.journal.back() == {"action": "enter", "node_id": event_id}
		and session.candle == maxi(0, int(before_event_entry.candle) - StitchedRunSession.NODE_CANDLE_COST)
		and session.receipts.is_empty() and session.walk_receipts.is_empty(),
		"the Event door charges exactly one candle toll and opens its own live Walk")
	await _walk_save_replay(app)
	if not await _walk_to_stop(app, event_id, 1):
		_finish(app)
		return
	var visit: StitchedCorridorVisit = app.stitched_run_panel as StitchedCorridorVisit
	_check(visit != null and visit.name == "StitchedRunPage"
		and str(visit.get_meta("page_kind", "")) == "visit:" + EVENT_KIND
		and visit.is_visible_in_tree() and session.phase == "visit"
		and session.pending.get("service") == EVENT_KIND
		and str(session.pending.get("event_id", "")) == PINNED_EVENT,
		"the Event happens in place on the corridor visit page")
	var event_choice := _visit_button(app, "collect_gutter_offcuts")
	_check(event_choice != null and session.visit_actions().any(func(action: Dictionary):
			return action.id == "collect_gutter_offcuts" and action.enabled),
		"the pinned Event offers its enabled consequential collect choice")
	if event_choice == null:
		_finish(app)
		return
	var before_event := session.snapshot()
	var event_receipts := session.receipts.size()
	var before_journal := session.journal.size()
	var inventory_before := session.ability_inventory.size()
	var refused := session.choose_visit("forged", [], before_event)
	var stale := before_event.duplicate(true)
	stale.candle += 1
	var stale_refused := session.choose_visit("collect_gutter_offcuts", [], stale)
	_check(not refused and not stale_refused and session.snapshot() == before_event
		and session.journal.size() == before_journal
		and session.receipts.size() == event_receipts
		and session.rng.state == before_event.rng,
		"forged and stale Event commands cannot spend or draw")
	if not _press(event_choice, "mounted Event collect gutter offcuts"):
		_finish(app)
		return
	await process_frame
	_check(session.phase == "map" and session.receipts.size() == event_receipts + 1
		and session.receipts.back().get("decision") == "collect_gutter_offcuts"
		and session.receipts.back().get("event_id") == PINNED_EVENT
		and session.scraps == int(before_event.scraps) + 1
		and session.ability_inventory.size() == inventory_before + 1
		and session.gold == int(before_event.gold) and session.candle == int(before_event.candle)
		and session.journal.size() == before_journal + 1
		and session.journal.back().get("id") == "collect_gutter_offcuts"
		and session.is_consistent(),
		"one authenticated consequential Event receipt grants exactly one scrap and one ability patch")
	var event_settled := session.snapshot()
	_check(not session.choose_visit("collect_gutter_offcuts", [], before_event)
		and session.snapshot() == event_settled and session.rng.state == event_settled.rng,
		"duplicate Event command cannot repeat reward or RNG draw")
	if _junction(app, "post-Event") == null:
		_finish(app)
		return
	var fight_door := _door(app, [FIGHT_KIND])
	_check(fight_door != null, "the settled Event unlocks a legal Fight junction door")
	if fight_door == null:
		_finish(app)
		return
	var fight_id := str(fight_door.get_meta("route_id"))
	var before_fight_entry := session.snapshot()
	var fight_entries := session.journal.size()
	if not _press(fight_door, "legal Fight junction door"):
		_finish(app)
		return
	await process_frame
	_check(session.phase == "walk" and session.pending.get("node_id") == fight_id
		and str(session.pending.kind) == FIGHT_KIND
		and session.journal.size() == fight_entries + 1
		and session.journal.back() == {"action": "enter", "node_id": fight_id}
		and session.candle == maxi(0, int(before_fight_entry.candle) - StitchedRunSession.NODE_CANDLE_COST)
		and session.receipts.size() == event_receipts + 1,
		"the Fight door pays one toll and opens a second distinct hosted Walk")
	if not await _walk_to_stop(app, fight_id, 2):
		_finish(app)
		return
	_check_fight(app, session, "after second Walk")
	if app.stitched_run_battle == null or _corridors(app).size() != 1:
		_finish(app)
		return
	var foes := session.battle.get_foes().size()
	_check(foes in [2, 3], "the seeded corridor Fight fields 2-3 live foes, not a fixture mob")
	var torn_carry: Array = []
	for walk_receipt in session.walk_receipts:
		for item in walk_receipt.get("pending", []):
			if item.get("kind") == "torn_part":
				torn_carry.append(item)
	var torn_battle: Array = []
	for hero in session.battle.get_heroes():
		for slot in hero.parts:
			if bool(hero.parts[slot].get("torn", false)):
				torn_battle.append([str(hero.id), str(slot)])
	# S14 (owner 11-08): limbs come off only at 0 HP, so the Walk's tug opens a seam that bleeds instead.
	_check(not torn_carry.is_empty() and torn_battle.is_empty(),
		"the Walk's tugs tear no limb before the live battle")
	for item in torn_carry:
		var bleeding := false
		for hero in session.battle.get_heroes():
			if str(hero.id) == str(item.get("target", "")):
				bleeding = int(hero.get("statuses", {}).get("bleed", 0)) >= 2
		_check(bleeding, "tugged doll " + str(item.get("target", "")) + " opens the live battle bleeding")
	var corridor: StitchedCorridorFight = _corridors(app)[0] as StitchedCorridorFight
	_check(corridor.more_buttons.has("save"), "mounted corridor exposes More > Save run")
	_press(corridor.more_button, "corridor More")
	_check(corridor.more_panel.visible and corridor.more_buttons["save"].is_visible_in_tree(),
		"player opens the active More panel containing Save run")
	_press(corridor.more_buttons["save"], "corridor More > Save run")
	_check(FileAccess.file_exists(TEST_SAVE), "corridor Save creates isolated run file")
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	var preserved_receipts := session.receipts.duplicate(true)
	var preserved_walks := session.walk_receipts.duplicate(true)
	var captured := StitchedRunSave.read_file(TEST_SAVE)
	_check(captured != null and captured.snapshot() == before and captured.journal == journal
		and captured.receipts == preserved_receipts and captured.walk_receipts == preserved_walks
		and captured.rng.state == session.rng.state,
		"corridor Save replays complete party, Fight, sockets, fear, wallet, receipts and RNG")
	var commit := _mounted_commit(corridor, session)
	_check(not commit.is_empty() and commit.ok
		and commit.entry.get("action") == "battle" and commit.entry.get("method") in ["use_part", "use_ability"]
		and commit.results.size() > 0 and str(commit.signature) != "",
		"the uninterrupted mounted part button commits the legal fixed S14 signature on the struck side")
	if commit.is_empty() or not commit.ok:
		_finish(app)
		return
	await process_frame
	var commit_after := session.snapshot()
	var commit_journal := session.journal.duplicate(true)
	app.free()
	await process_frame
	var fresh := _app(999)
	await process_frame
	await process_frame
	_check(fresh.title_view.is_visible_in_tree() and fresh.stitched_run_session == null
		and _corridors(fresh).is_empty(), "fresh independent title starts with no mounted battle")
	_press(fresh.stitched_continue_button, "fresh title Continue")
	await process_frame
	var resumed: StitchedRunSession = fresh.stitched_run_session
	_check(resumed != null and resumed != session and not fresh.title_view.visible
		and resumed.snapshot() == before and resumed.journal == journal and resumed.rng.state == before.rng,
		"fresh Continue restores exact snapshot, journal, RNG and genuine seeded run")
	if resumed == null:
		_finish(fresh)
		return
	_check(resumed.heroes == before.heroes and resumed.pending == before.pending
		and resumed.candle == before.candle and resumed.kid_fear() == before.kid_fear.fear
		and resumed.gold == before.gold and resumed.scraps == before.scraps
		and resumed.battle.state_snapshot() == before.battle and resumed.journal == journal
		and resumed.snapshot().s14 == before.s14,
		"explicit party, pending Fight, resources, fear, sockets, battle and journal equal saved values")
	_check_fight(fresh, resumed, "after fresh title Continue")
	if _corridors(fresh).size() != 1:
		_finish(fresh)
		return
	var reloaded_fight: StitchedCorridorFight = _corridors(fresh)[0] as StitchedCorridorFight
	var recommit := _mounted_commit(reloaded_fight, resumed)
	_check(not recommit.is_empty() and recommit.ok and recommit.entry == commit.entry
		and recommit.results == commit.results and recommit.signature == commit.signature,
		"independent next mounted S14 signature reproduces the exact commit, journal and results")
	_check(resumed.snapshot() == commit_after and resumed.journal == commit_journal
		and resumed.receipts == preserved_receipts and resumed.walk_receipts == preserved_walks
		and resumed.rng.state == commit_after.rng and resumed.is_consistent(),
		"independent next mounted command reproduces exact Fight state, journal and RNG")
	if _corridors(fresh).size() == 1:
		var preserved := resumed.snapshot()
		DirAccess.remove_absolute(TEST_SAVE)
		_rejection(fresh, resumed, preserved, "missing file during legitimate battle")
		_write_document({"version": "malformed", "state": {}})
		_rejection(fresh, resumed, preserved, "malformed file during legitimate battle")
		var forged := StitchedRunSave.capture(resumed)
		_check(not forged.is_empty(), "authenticated save document exists before forgery")
		if not forged.is_empty():
			forged.state.candle = maxi(0, int(forged.state.candle) - 1)
			forged.digest = StitchedRunSave._digest(forged)
			_write_document(forged)
			_rejection(fresh, resumed, preserved, "rehashed forged document")
	_finish(fresh)


func _finish(app: Node) -> void:
	StitchedRunSession.pinned_event_id = ""
	if is_instance_valid(app):
		app.free()
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_SAVE + ".tmp")
	for failure in failures:
		printerr(failure)
	print("stitched_s8f_corridor_save_gate_test: %s (%d checks, %d failures)" %
		["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
