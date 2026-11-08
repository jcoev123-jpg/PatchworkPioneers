extends SceneTree
## S8/S9 live combat: junction doors -> pinned Event -> corridor Fight victory ->
## Sewing Circle socket -> second corridor's sewn-on patch cast -> mid-Fight Save ->
## exact fresh title Continue. Only the live mounted UI can spend actions.
const SAVE_PATH := "user://stitched_s8s9_live_combat_continue_test.save"
const PINNED_EVENT := "v3_thimble_raincollector"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _press(button: BaseButton, label: String) -> bool:
	var ready := is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree() and not button.disabled
	_check(ready, "real enabled mounted control: " + label)
	if ready:
		button.pressed.emit()
	return ready


func _app(seed_number: int) -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = seed_number
	app.stitched_walks = true
	app.stitched_save_path = SAVE_PATH
	root.add_child(app)
	return app


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


func _fight(app: Node, session: StitchedRunSession, label: String) -> StitchedCorridorFight:
	var stages := app.find_children("CorridorFight", "Control", true, false)
	var screen: StitchedBattleScreen = app.stitched_run_battle
	var good: bool = session != null and session.phase == "battle" and session.battle != null \
		and stages.size() == 1 and is_instance_valid(screen) and screen.battle == session.battle \
		and screen.is_visible_in_tree() and not app.title_view.visible
	var corridor: StitchedCorridorFight = stages[0] as StitchedCorridorFight if stages.size() == 1 else null
	_check(good and corridor != null and corridor.engine == screen and corridor.battle == session.battle
		and corridor.is_visible_in_tree() and corridor.get_parent() == screen,
		label + ": exactly one live corridor overlays the session's authoritative Fight")
	return corridor if good else null


func _state(session: StitchedRunSession, screen: StitchedBattleScreen) -> Dictionary:
	return {"snapshot": session.snapshot(), "journal": session.journal.duplicate(true),
		"run_rng": session.rng.state, "battle": session.battle.state_snapshot(),
		"ui_receipts": screen.receipts.duplicate(true)}


func _off_rank_refusal(corridor: StitchedCorridorFight, session: StitchedRunSession) -> bool:
	var screen: StitchedBattleScreen = corridor.engine
	# Find a mounted part with a real target choice; no fixture or synthesized combat.
	for slot in StitchedBattleScreen.SLOTS:
		if corridor.part_buttons[slot].disabled:
			continue
		var before := session.journal.size()
		_press(corridor.part_buttons[slot], "choose " + slot + " for negative rank check")
		if session.journal.size() != before: # one-target part auto-committed; try the next live actor
			return false
		if screen._selected_part != slot or screen.legal_targets().is_empty():
			continue
		var legal := screen.legal_targets()
		for rank in range(1, 5):
			var key := "foe_" + str(rank)
			if legal.has(key):
				continue
			var pristine := _state(session, screen)
			var selected := screen._selected_part
			var refused := corridor.click_figure("foe", rank)
			_check(refused.get("ok") == false and _state(session, screen) == pristine
				and screen._selected_part == selected and session.is_consistent(),
				"off-rank target is refused with unchanged HP/fray/actions/resources/journal/RNG")
			return true
	return false


func _foe_receipts_since(session: StitchedRunSession, start: int) -> int:
	var count := 0
	for entry in session.journal.slice(start):
		if entry is Dictionary and entry.get("action") == "battle" \
			and entry.get("method") in ["use_foe_ability", "pass_turn"]:
			# Only a foe's recorded ability is a meaningful foe response.
			if entry.get("method") == "use_foe_ability":
				count += 1
	return count


## True only when the receipt holds this patch effect's own landed entry: never a
## resisted roll and never a refused status.
func _landed_status(statuses: Array, effect: String, amount: int) -> bool:
	for entry in statuses:
		if str(entry.get("status", "")) == effect and not entry.has("resisted") \
				and not bool(entry.get("refused", false)) \
				and int(entry.get("duration", 0)) >= amount:
			return true
	return false


## True when the receipt records the effect as shrugged off by an S15 foe resist roll.
func _resisted_status(statuses: Array, effect: String) -> bool:
	for entry in statuses:
		if str(entry.get("status", "")) == effect and entry.has("resisted"):
			return true
	return false


## True only for a receipt entry stamped with this very patch id (heal, steal, cleanse
## and regen report the patch that produced them explicitly).
func _patch_entry(statuses: Array, patch_id: String, effect: String) -> bool:
	for entry in statuses:
		if str(entry.get("status", "")) == effect and str(entry.get("patch", "")) == patch_id:
			return true
	return false


## S15-aware witness: the sewn patch really executed on its correct target or actor.
## A hit with the patches list alone is not enough, a resisted or refused status entry
## never counts, and the live unit must still carry (or have settled) the effect itself.
func _patch_witness(patch: Dictionary, receipt: Dictionary, struck: Dictionary, actor: Dictionary) -> bool:
	if receipt.is_empty() or struck.is_empty() or actor.is_empty() \
			or str(struck.get("side", "")) != "foe" or bool(struck.get("dead", false)) \
			or int(struck.get("hp", 0)) <= 0:
		return false
	var statuses: Array = receipt.get("statuses", [])
	var effect := str(patch.get("effect", ""))
	var amount := int(patch.get("amount", 0))
	var patch_id := str(patch.get("id", ""))
	if effect == "regen":
		return _patch_entry(statuses, patch_id, "regen") \
			and int(struck.get("statuses", {}).get("regen", 0)) >= amount
	if effect == "cleanse":
		if not _patch_entry(statuses, patch_id, "cleanse"):
			return false
		for key in ["bleed", "weak", "exposed", "tangled", "blind", "mark", "stun", "rot"]:
			if int(struck.get("statuses", {}).get(key, 0)) > 0:
				return false
		return true
	if effect == "steal":
		for entry in statuses:
			if str(entry.get("status", "")) == "steal" and str(entry.get("patch", "")) == patch_id \
					and int(entry.get("amount", 0)) > 0:
					return true
		return false
	if effect == "heal":
		return _patch_entry(statuses, patch_id, "heal") \
			and int(receipt.get("target_hp", -1)) == int(struck.get("hp", -2))
	if effect == "guard":
		for entry in statuses:
			if str(entry.get("status", "")) == "guard" \
					and str(entry.get("guards", "")) == str(struck.get("id", "")) \
					and int(entry.get("duration", 0)) >= amount:
				return int(actor.get("statuses", {}).get("guard", 0)) >= amount
		return false
	if effect == "pull" or effect == "push":
		var shift: Dictionary = receipt.get("shift", {})
		return bool(shift.get("ok", false)) and not _resisted_status(statuses, effect) \
			and int(struck.get("rank", -1)) == int(shift.get("to", -2))
	if effect == "chain":
		return bool(receipt.get("chained", false))
	return _landed_status(statuses, effect, amount) and not _resisted_status(statuses, effect) \
		and int(struck.get("statuses", {}).get(effect, 0)) >= amount


## One legal fixed S14 signature action through the mounted part buttons and hit
## targets only. With preferred_slot set, only that limb may commit.
func _mounted_commit(corridor: StitchedCorridorFight, session: StitchedRunSession,
		preferred_slot: String = "") -> Dictionary:
	var screen: StitchedBattleScreen = corridor.engine
	if session.battle == null or session.battle.is_over() or session.battle.current_side() != "hero":
		return {}
	var actor: Dictionary = session.battle.get_unit(session.battle.current_actor_id())
	var kits := StitchedS14Abilities.kits()
	var order: Array = ["arms", "legs", "torso", "head"] if preferred_slot.is_empty() else [preferred_slot]
	for slot in order:
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
		if str(result.get("action", "")) == "refused":
			# A cowering doll's legal refusal consumes its turn without an ability receipt.
			return {"ok": true, "kind": "refused", "slot": slot, "signature": "",
				"entry": session.journal[before], "results": [], "struck": ""}
		var signature: Dictionary = kits.get(str(actor.get("id", "")), {}).get(slot, {})
		var results: Array = result.get("results", [])
		var struck_side := ""
		if not results.is_empty():
			# Scrap heaps report their side on the receipt; they are not live units.
			struck_side = str(results[0].get("target_side", ""))
			if struck_side.is_empty():
				struck_side = str(session.battle.get_unit(str(results[0].get("target", ""))).get("side", ""))
		var expected_side := "foe" if str(signature.get("target_side", "")) == "enemy" else "hero"
		# A fallen foe leaves a scrap heap that enemy signatures may legally strike instead.
		var legal_sides: Array = [expected_side, "heap"] if expected_side == "foe" else [expected_side]
		return {"ok": result.get("ok") == true and not signature.is_empty()
				and str(result.get("ability", "")) == str(signature.get("id", ""))
				and not results.is_empty() and struck_side in legal_sides,
			"kind": "ability", "slot": slot, "signature": str(signature.get("id", "")),
			"entry": session.journal[before], "results": results,
			"struck": str(results[0].get("target", "")) if not results.is_empty() else ""}
	return {}


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH + ".tmp")
	# Seed 3785's live Event draw is pinned to the real Thimble Raincollector so shared
	# catalog growth cannot retarget this witness: its free collect grants one scrap and
	# one ability patch, the first Fight pays out the sewable victory patch, and the next
	# Sewing Circle sockets it for a genuine mid-corridor patch cast.
	StitchedRunSession.pinned_event_id = PINNED_EVENT
	var app := _app(3785)
	await process_frame
	await process_frame
	_check(app.title_view.is_visible_in_tree() and app.stitched_run_session == null,
		"fresh title has no prebuilt battle")
	if not _press(app.start_button, "New Run"):
		_finish(app)
		return
	await process_frame
	if app.stitched_run_buttons.is_empty() or not _press(app.stitched_run_buttons[0], "four-doll Set out"):
		_finish(app)
		return
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.seed_value == 3785 and session.heroes.size() == 4
		and session.walks_enabled and session.s14_enabled and session.is_consistent(),
		"seed 3785 runs four dolls with Walks and fixed S14 signatures")

	if session == null:
		_finish(app)
		return
	var begin: Button = app.stitched_run_intro.find_child("WrenIntroBegin", true, false) as Button \
		if is_instance_valid(app.stitched_run_intro) else null
	if not _press(begin, "Wren intro Begin the night"):
		_finish(app)
		return
	await process_frame

	if _junction(app, "post-intro") == null:
		_finish(app)
		return
	var event_door := _door(app, ["Event"])
	_check(event_door != null and str(event_door.get_meta("node_kind", "")) == "Event",
		"seed 3785 offers a legal visible Event junction door")
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
		and session.journal.size() == event_entries + 1
		and session.journal.back() == {"action": "enter", "node_id": event_id}
		and session.candle == maxi(0, int(before_event_entry.candle) - StitchedRunSession.NODE_CANDLE_COST)
		and session.receipts.is_empty() and session.walk_receipts.is_empty(),
		"the Event door charges exactly one candle toll and opens its own live Walk")
	if not await _walk_to_stop(app, event_id, 1) or session.phase != "visit" \
			or session.pending.get("service") != "Event":
		_check(false, "seeded Event Walk reaches its real in-place event visit")
		_finish(app)
		return
	var visit: StitchedCorridorVisit = app.stitched_run_panel as StitchedCorridorVisit
	_check(visit != null and visit.name == "StitchedRunPage"
		and str(visit.get_meta("page_kind", "")) == "visit:Event"
		and visit.is_visible_in_tree()
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
	var fight_door := _door(app, ["Fight"])
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
		and session.journal.size() == fight_entries + 1
		and session.candle == maxi(0, int(before_fight_entry.candle) - StitchedRunSession.NODE_CANDLE_COST)
		and session.receipts.size() == event_receipts + 1,
		"the Fight door pays one toll and opens a second distinct hosted Walk")
	if not await _walk_to_stop(app, fight_id, 2):
		_finish(app)
		return
	var corridor := _fight(app, session, "post-Walk Fight")
	if corridor == null:
		_finish(app)
		return
	var screen: StitchedBattleScreen = corridor.engine
	var battle: StitchedRunSession.RankedBattle = session.battle
	_check(battle.get_foes().size() in [2, 3],
		"the seeded corridor Fight fields 2-3 live foes, not a fixture mob")

	var fight_start := session.journal.size()
	# Continue is not offered before a real outcome; its hidden signal cannot exit or spend.
	var before_early := _state(session, screen)
	corridor.continue_button.pressed.emit()
	_check(session.phase == "battle" and _state(session, screen) == before_early
		and not corridor.continue_button.visible and not battle.is_over(),
		"premature Continue cannot exit, settle or spend RNG")
	# Let the mounted foes take their own turns once so their response is witnessed.
	var passes := 0
	while _foe_receipts_since(session, fight_start) == 0 and passes < 8 and not battle.is_over():
		passes += 1
		if not _press(corridor.more_button, "corridor More for Pass") \
				or not _press(corridor.more_buttons["pass"], "mounted Pass for the foes' turn"):
			break
		await process_frame
	_check(_foe_receipts_since(session, fight_start) > 0 and not battle.is_over()
		and session.is_consistent(),
		"the foes' own turns resolve through the dolls' mounted Pass")
	# Attempt an off-rank hit while a real part is armed, before its legitimate attack.
	var probed := false
	var refusals := 0
	while not probed and refusals < 3 and not battle.is_over():
		refusals += 1
		probed = _off_rank_refusal(corridor, session)
		if not probed and not battle.is_over():
			if not _press(corridor.more_button, "More for Pass (off-rank retry)") \
					or not _press(corridor.more_buttons["pass"], "Pass (off-rank retry)"):
				break
			await process_frame
	_check(probed, "a mounted part offered a forbidden target rank for refusal testing")
	# Win the seeded corridor Fight through the mounted part buttons only.
	var attacks := 0
	var refused_turns := 0
	var turns := 0
	while not battle.is_over() and turns < 250:
		turns += 1
		if battle.current_side() != "hero":
			_check(false, "the real engine returns to a playable doll turn")
			break
		var commit := _mounted_commit(corridor, session)
		if commit.is_empty():
			if not _press(corridor.more_button, "corridor More for Pass") \
					or not _press(corridor.more_buttons["pass"], "mounted Pass"):
				break
		elif str(commit.get("kind", "")) == "refused":
			refused_turns += 1
		else:
			_check(commit.ok and commit.entry.get("action") == "battle"
				and commit.entry.get("method") == "use_part"
				and str(commit.signature) != "" and not commit.results.is_empty(),
				"mounted body-part attack commits the legal fixed S14 signature once with real results")
			if not commit.ok:
				break
			attacks += 1
		await process_frame

	_check(battle.is_over() and battle.outcome() == "victory" and turns < 250 and attacks > 0,
		"four dolls genuinely win the seeded corridor Fight through mounted controls only")
	if not battle.is_over() or battle.outcome() != "victory":
		_finish(app)
		return
	await process_frame
	_check(corridor.continue_button.is_visible_in_tree() and not corridor.continue_button.disabled,
		"visible enabled post-victory Continue is the public exit")
	var scraps_before := session.scraps
	var inventory_before_settle := session.ability_inventory.duplicate(true)
	if not _press(corridor.continue_button, "victory Continue"):
		_finish(app)
		return
	await process_frame
	_check(session.phase == "map" and session.battle == null and session.pending.is_empty()
		and app.stitched_run_battle == null
		and app.find_children("CorridorFight", "Control", true, false).is_empty(),
		"only Continue returns to a live routed map, never a second Fight")
	var receipt: Dictionary = session.receipts.back()
	var awarded: Dictionary = receipt.get("reward", {}).get("ability_patch", {})
	_check(receipt.get("node_id") == fight_id and receipt.get("kind") == "Fight"
		and receipt.get("outcome") == "victory"
		and not awarded.is_empty() and session.ability_inventory.back() == awarded
		and session.ability_inventory.size() == inventory_before_settle.size() + 1
		and session.scraps == scraps_before + int(receipt.get("reward", {}).get("scraps", 0)),
		"the victory settlement journals exactly its real random award: one new ability patch and its scraps")

	if _junction(app, "post-victory") == null:
		_finish(app)
		return
	var sewing_door := _door(app, ["SewingCircle"])
	_check(sewing_door != null, "the won map offers a legal Sewing Circle junction door")
	if sewing_door == null:
		_finish(app)
		return
	var sewing_id := str(sewing_door.get_meta("route_id"))
	if not _press(sewing_door, "legal Sewing Circle junction door"):
		_finish(app)
		return
	await process_frame
	if not await _walk_to_stop(app, sewing_id, 3) or session.phase != "visit" \
			or session.pending.get("service") != "SewingCircle":
		_check(false, "the Sewing Circle Walk reaches its real in-place service visit")
		_finish(app)
		return
	var sewing_visit: StitchedCorridorVisit = app.stitched_run_panel as StitchedCorridorVisit
	_check(sewing_visit != null and str(sewing_visit.get_meta("page_kind", "")) == "visit:SewingCircle",
		"the Sewing Circle happens in place on the corridor visit page")
	var patch: Dictionary = session.ability_inventory.back()
	var patch_id := str(patch.get("id", ""))
	var patch_uid := int(patch.get("uid", 0))
	var warden_kit: Dictionary = StitchedS14Abilities.kits().get("warden", {}).get("head", {})
	var signature := str(warden_kit.get("id", ""))
	_check(not patch_id.is_empty() and patch_uid > 0 and not signature.is_empty()
		and str(warden_kit.get("target_side", "")) == "enemy"
		and session.scraps >= StitchedRunSession.SEWING_COST,
		"the awarded patch and the warden's enemy-facing head signature are socketable now")
	var before_socket := session.snapshot()
	var socket_journal := session.journal.size()
	var forged_socket := session.socket_ability(patch_uid, "warden", "forged_signature", 0, session.snapshot())
	var stale_socket := before_socket.duplicate(true)
	stale_socket.scraps += 1
	var stale_refused_socket := session.socket_ability(patch_uid, "warden", signature, 0, stale_socket)
	var wrong_hero := session.socket_ability(patch_uid, "missing_doll", signature, 0, session.snapshot())
	_check(not forged_socket and not stale_refused_socket and not wrong_hero
		and session.snapshot() == before_socket and session.journal.size() == socket_journal
		and session.rng.state == before_socket.rng and session.is_consistent(),
		"forged, stale and misdirected socket commands cannot spend scraps or draw")
	var socketed := session.socket_ability(patch_uid, "warden", signature, 0, session.snapshot())
	var live_sockets: Array = session.snapshot().get("s14", {}).get("sockets", {}) \
		.get("warden", {}).get(signature, [])
	_check(socketed and session.scraps == int(before_socket.scraps) - StitchedRunSession.SEWING_COST
		and session.gold == int(before_socket.gold) and session.candle == int(before_socket.candle)
		and session.journal.size() == socket_journal + 1
		and session.journal.back() == {"action": "socket", "uid": patch_uid, "hero": "warden",
			"ability": signature, "replace": 0}
		and live_sockets.has(patch_uid) and session.is_consistent(),
		"one authenticated socket sews the awarded patch onto the warden's head signature for two scraps")

	var leave := _visit_button(app, "leave")
	_check(leave != null and session.visit_actions().any(func(action: Dictionary):
			return action.id == "leave" and action.enabled),
		"the Sewing Circle offers its enabled mounted leave")
	# The session-level socket has no mounted control yet, so the wired buttons still
	# hold the pre-socket snapshot; leave through the public visit command instead.
	if not session.choose_visit("leave", [], session.snapshot()):
		_check(false, "the public Sewing Circle leave returns to the map")
		_finish(app)
		return
	await process_frame
	# The session-level commands above do not re-present the mounted page themselves.
	app._present_stitched_run()
	await process_frame
	_check(session.phase == "map" and session.battle == null,
		"leaving the Circle returns to the live junction")
	if _junction(app, "post-Circle") == null:
		_finish(app)
		return
	var second_door := _door(app, ["Fight", "Elite"])
	_check(second_door != null, "the map offers a legal Fight or Elite junction door after the Circle")
	if second_door == null:
		_finish(app)
		return
	var second_id := str(second_door.get_meta("route_id"))
	if not _press(second_door, "legal second corridor junction door"):
		_finish(app)
		return
	await process_frame

	if not await _walk_to_stop(app, second_id, 4):
		_finish(app)
		return
	var corridor2 := _fight(app, session, "second corridor Fight")
	if corridor2 == null:
		_finish(app)
		return
	var screen2: StitchedBattleScreen = corridor2.engine
	var battle2: StitchedRunSession.RankedBattle = session.battle
	_check(battle2.get_foes().size() >= 2
		and battle2.state_snapshot().get("s14", {}).get("sockets", {}) \
		.get("warden", {}).get(signature, []) == [patch_id],
		"the live second battle carries the sewn patch on the warden's head signature")
	# S15: the awarded patch must be a live entry of the current validated patch catalog;
	# catalog growth is checked by ID presence (the mildew rot patch), never by totals.
	var patch_catalog := StitchedS14Abilities.patches()
	var patch_record: Dictionary = patch_catalog.get("by_id", {}).get(patch_id, {})
	var spore: Dictionary = patch_catalog.get("by_id", {}).get("silk_mildew_spore", {})
	_check(not patch_record.is_empty() and not spore.is_empty()
		and str(spore.get("effect", "")) == "rot"
		and str(patch_record.get("rarity", "")) in StitchedS14Abilities.RARITIES
		and str(patch_record.get("effect", "")) in StitchedS14Abilities.EFFECTS
		and int(patch_record.get("amount", 0)) > 0,
		"the awarded patch is a live entry of the validated S15-aware patch catalog")
	if patch_record.is_empty() or spore.is_empty():
		_finish(app)
		return
	# S9a: one real mounted Wren hand action at an available doll turn. The no-target
	# Shield the Candle basic commits straight from its own pressed signal.
	var hand_id := "shield_candle"
	var hand_button: TextureButton = corridor2.hand_buttons.get(hand_id)
	_check(battle2.current_side() == "hero" and battle2.hand_action_open()
		and hand_button != null and not hand_button.disabled and hand_button.is_visible_in_tree(),
		"the second Fight opens on a doll turn with the mounted free-hand control enabled")
	if battle2.current_side() != "hero" or not battle2.hand_action_open() \
			or hand_button == null or hand_button.disabled:
		_finish(app)
		return

	var hand_round := battle2.round_number()
	var hand_actor := str(battle2.current_actor_id())
	var hand_turn := int(battle2.state_snapshot()["turn_index"])
	var hand_journal := session.journal.size()
	var hand_receipt_count := battle2.hand_receipts().size()
	if not _press(hand_button, "mounted Wren Shield the Candle hand action"):
		_finish(app)
		return
	await process_frame
	var hand_receipts_now: Array = battle2.hand_receipts()
	var hand_receipt: Dictionary = hand_receipts_now.back() if not hand_receipts_now.is_empty() else {}
	_check(not battle2.hand_action_open()
		and battle2.round_number() == hand_round and battle2.candle_shielded()
		and session.journal.size() == hand_journal + 1
		and session.journal.back() == {"action": "battle", "method": "use_hand_action",
			"arguments": [hand_id, "", 0]}
		and hand_receipts_now.size() == hand_receipt_count + 1
		and bool(hand_receipt.get("ok")) and str(hand_receipt.get("hand_action", "")) == hand_id
		and int(hand_receipt.get("round", -1)) == hand_round
		and int(hand_receipt.get("fear", -1)) == session.kid_fear()
		and str(battle2.current_actor_id()) == hand_actor
		and int(battle2.state_snapshot()["turn_index"]) == hand_turn
		and session.is_consistent(),
		"one real mounted hand action spends exactly the round's free hand, never the doll's turn")

	# Replayed, forged and stale hand requests refuse atomically: no journal command, no
	# extra receipt, no RNG draw and no state mutation in that same round.
	var after_hand := _state(session, screen2)
	var replayed_hand := battle2.use_hand_action(hand_id, "", 0)
	var forged_hand := battle2.use_hand_action("forged_hand", "", 0)
	var stale_hand := battle2.use_hand_action(hand_id, "warden", 0)
	var stale_direction := battle2.use_hand_action(hand_id, "", 1)
	_check(not replayed_hand.get("ok", true) and not forged_hand.get("ok", true)
		and not stale_hand.get("ok", true) and not stale_direction.get("ok", true)
		and session.journal.size() == hand_journal + 1
		and battle2.hand_receipts().size() == hand_receipt_count + 1
		and session.rng.state == after_hand.run_rng
		and _state(session, screen2) == after_hand and session.is_consistent(),
		"replayed, forged and stale hand requests refuse without journal, RNG or state drift")
	# Pass other dolls until the warden's mounted head signature lands the sewn patch with
	# a genuinely applied effect: under the S15 resist contracts a mere hit, a patches list
	# or a resisted status entry is not a witness; bounded lawful mounted turns may be needed.
	var confirmed: Dictionary = {}
	var cast_turns := 0
	var unwitnessed_casts := 0
	var hand_reopen_checked := false
	while confirmed.is_empty() and not battle2.is_over() and cast_turns < 250:
		cast_turns += 1
		if battle2.current_side() != "hero":
			_check(false, "the second engine returns to a playable doll turn")
			break
		# A new round lawfully reopens the free hand budget; it is never a duplicate spend.
		if not hand_reopen_checked and battle2.round_number() != hand_round:
			_check(battle2.hand_action_check(hand_id, "", 0) \
					!= "Wren's hand action is spent this round",
				"a new round reopens the free hand budget: the spend is never a replay")
			hand_reopen_checked = true
		var actor_id := str(battle2.get_unit(battle2.current_actor_id()).get("id", ""))
		var commit := {}
		if actor_id == "warden":
			commit = _mounted_commit(corridor2, session, "head")
		if commit.is_empty():
			if not _press(corridor2.more_button, "second corridor More for Pass") \
					or not _press(corridor2.more_buttons["pass"], "mounted Pass awaiting the warden"):
					break
		else:
			_check(commit.ok and str(commit.signature) == signature,
				"the warden's mounted head button commits its own fixed S14 signature")
			if not commit.ok:
				break
			if not commit.results.is_empty():
				var struck: Dictionary = commit.results[0]
				var struck_live: Dictionary = session.battle.get_unit(str(struck.get("target", "")))

				if bool(struck.get("hit")) and (struck.get("patches", []) as Array).has(patch_id) \
						and _patch_witness(patch_record, struck, struck_live, \
							session.battle.get_unit("warden")):
					confirmed = commit
					break
			unwitnessed_casts += 1
		await process_frame
	var struck_receipt: Dictionary = confirmed.results[0] if not confirmed.is_empty() else {}
	var struck_unit: Dictionary = session.battle.get_unit(str(confirmed.struck)) if not confirmed.is_empty() else {}
	_check(not confirmed.is_empty() and confirmed.ok
		and str(confirmed.signature) == signature
		and bool(struck_receipt.get("hit"))
		and struck_receipt.get("patches", []) == [patch_id]
		and _patch_witness(patch_record, struck_receipt, struck_unit, \
			session.battle.get_unit("warden"))
		and str(struck_unit.get("side", "")) == "foe",
		"the sewn-on patch rides the warden's legal fixed head signature onto a live foe and truly applies its effect (%d unwitnessed casts)" % unwitnessed_casts)
	if confirmed.is_empty():
		_finish(app)
		return

	# The next doll cannot replay the warden's already-spent head part.
	var warden_head_part := str(battle2.get_unit("warden").get("parts", {}).get("head", {}).get("id", ""))
	var next_actor := str(battle2.get_unit(battle2.current_actor_id()).get("id", ""))
	var before_duplicate := _state(session, screen2)
	var duplicate := battle2.use_part(warden_head_part, 1)
	_check(next_actor != "warden" and duplicate.get("ok") == false
		and _state(session, screen2) == before_duplicate and session.is_consistent(),
		"another doll cannot spend the warden's head part: the replay is refused without drift")
	# Save only through the live corridor control, after the real hand and patch evidence,
	# then compare the next mounted command.
	_press(corridor2.more_button, "corridor More for Save")
	_check(corridor2.more_panel.visible, "Save is on the mounted More panel")
	_press(corridor2.more_buttons["save"], "corridor Save run")
	var saved := _state(session, screen2)
	var saved_hand: Dictionary = saved.battle.get("hand", {})
	var saved_fear: Dictionary = saved.snapshot.get("kid_fear", {})
	var saved_heroes: Array = saved.snapshot.get("heroes", [])
	var saved_gold := int(saved.snapshot.get("gold", -1))
	var saved_scraps := int(saved.snapshot.get("scraps", -1))
	var saved_candle := int(saved.snapshot.get("candle", -1))
	var document := StitchedRunSave.read_file(SAVE_PATH)
	var saved_document: Dictionary = document.snapshot() if document != null else {}
	_check(FileAccess.file_exists(SAVE_PATH) and document != null
		and saved_document == saved.snapshot and document.journal == saved.journal
		and document.rng.state == saved.run_rng
		and saved.battle.get("s14", {}).get("sockets", {}).get("warden", {}).get(signature, []) == [patch_id]
		and not saved_hand.is_empty()
		and int(saved_hand.get("round_used", -1)) == hand_round
		and int(saved_hand.get("shield_round", -2)) == hand_round
		and (saved_hand.get("spent", [false]) as Array).is_empty()
		and (saved_hand.get("receipts", []) as Array).size() == hand_receipt_count + 1
		and str((saved_hand.get("receipts", [{}]) as Array)[0].get("hand_action", "")) == hand_id
		and saved_document.get("battle", {}).get("hand", {}) == saved_hand
		and saved_document.get("kid_fear", {}) == saved_fear
		and saved_document.get("heroes", []) == saved_heroes
		and int(saved_document.get("gold", -2)) == saved_gold
		and int(saved_document.get("scraps", -2)) == saved_scraps
		and int(saved_document.get("candle", -2)) == saved_candle
		and saved_document.get("s14", {}).get("sockets", {}) \
			== saved.snapshot.get("s14", {}).get("sockets", {}),
		"mid-Fight save captures the battle hand budget and receipts, sewn sockets, fear, limb conditions, currencies, journal and RNG")

	var prior_count := session.journal.size()
	if not corridor2.more_panel.visible:
		_press(corridor2.more_button, "uninterrupted More for next Pass")
	_press(corridor2.more_buttons["pass"], "uninterrupted next legal Pass")
	await process_frame
	var expected := session.snapshot()
	var expected_journal := session.journal.slice(prior_count).duplicate(true)
	var expected_receipts := screen2.receipts.slice(saved.ui_receipts.size()).duplicate(true)
	_check(not expected_journal.is_empty() and expected_journal[0].get("method") == "pass_turn"
		and session.is_consistent(),
		"uninterrupted next legal action and its aftermath are journaled")
	app.free()
	await process_frame
	var fresh := _app(999)
	await process_frame
	await process_frame

	_check(fresh.title_view.visible and fresh.stitched_run_session == null,
		"fresh independent application starts at title")
	_press(fresh.stitched_continue_button, "fresh title Continue")
	await process_frame
	var restored: StitchedRunSession = fresh.stitched_run_session
	var restored_corridor := _fight(fresh, restored, "fresh mid-Fight Continue")
	if restored == null or restored_corridor == null:
		_finish(fresh)
		return
	_check(restored != session and restored.snapshot() == saved.snapshot and restored.journal == saved.journal
		and restored.rng.state == saved.run_rng and restored.battle.state_snapshot() == saved.battle
		and restored.battle.state_snapshot().get("s14", {}).get("sockets", {}).get("warden", {}) \
		.get(signature, []) == [patch_id]
		and restored.battle.state_snapshot().get("hand", {}) == saved_hand
		and restored.battle.hand_receipts() == (saved_hand.get("receipts", []) as Array)
		and restored.kid_fear() == int(saved_fear.get("fear", -1))
		and restored.heroes == saved_heroes
		and restored.gold == saved_gold and restored.scraps == saved_scraps
		and restored.candle == saved_candle,
		"Continue restores the exact run, battle, hand budget and receipts, sewn sockets, fear, limb conditions, currencies, journal and RNG")
	var restored_screen: StitchedBattleScreen = restored_corridor.engine
	var before_restored_count := restored.journal.size()
	_press(restored_corridor.more_button, "resumed More for next Pass")
	_press(restored_corridor.more_buttons["pass"], "resumed next legal Pass")
	await process_frame
	_check(restored.snapshot() == expected and restored.rng.state == expected.rng
		and restored.journal.slice(before_restored_count) == expected_journal
		and restored_screen.receipts == expected_receipts and restored.is_consistent()
		and restored.battle.state_snapshot().get("hand", {}) \
			== expected.get("battle", {}).get("hand", {}),
		"resumed next mounted action exactly matches uninterrupted combat, hand budget, foe turns and RNG")

	_finish(fresh)


func _finish(app: Node) -> void:
	StitchedRunSession.pinned_event_id = ""
	if is_instance_valid(app):
		app.free()
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH + ".tmp")
	for failure in failures:
		printerr(failure)
	print("stitched_s8s9_live_combat_continue_test: %s (%d checks, %d failures)" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
