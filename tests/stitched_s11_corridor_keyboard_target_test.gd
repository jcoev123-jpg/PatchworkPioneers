extends SceneTree
## Real 1280x720 mounted corridor keyboard targeting; engine remains the only authority.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	var release := InputEventKey.new()
	release.keycode = code
	release.pressed = false
	root.push_input(release, true)


func _mount() -> StitchedCorridorFight:
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(StitchedBattleScreen.read_preview()), "authentic seeded preview begins")
	root.add_child(screen)
	await process_frame
	var fight := StitchedCorridorFight.attach(screen, "walls")
	_check(fight != null and fight.engine == screen and fight.battle == screen.battle,
		"actual corridor attaches to hidden battle engine")
	await process_frame
	return fight


func _actor_count(screen: StitchedBattleScreen, side: String) -> int:
	var count := 0
	for rank in range(1, 5):
		if not screen._unit_at(side, rank).is_empty():
			count += 1
	return count


func _multi_slot(fight: StitchedCorridorFight) -> String:
	for slot in StitchedBattleScreen.SLOTS:
		if fight.part_buttons[slot].disabled:
			continue
		if fight.engine.select_part(slot) and fight.engine.legal_targets().size() >= 2:
			fight.engine._selected_part = ""
			fight.engine._refresh()
			fight.refresh()
			return slot
		fight.engine._selected_part = ""
		fight.engine._refresh()
	fight.refresh()
	return ""


func _ordered_keys(legal: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for side in ["hero", "foe"]:
		for rank in range(1, 5):
			var key: String = side + "_" + str(rank)
			if legal.has(key):
				keys.append(key)
	return keys


func _unchanged(fight: StitchedCorridorFight, snapshot: Dictionary, rng: int,
		receipts: Array, hand_open: bool, note: String) -> void:
	_check(fight.battle.state_snapshot() == snapshot and fight.battle.rng_state() == rng
		and fight.engine.receipts == receipts and fight.battle.hand_action_open() == hand_open,
		note + ": no state, RNG, receipt or hand budget spent")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fight := await _mount()
	if fight == null:
		_finish()
		return
	var screen := fight.engine
	_check(_actor_count(screen, "hero") == 4 and _actor_count(screen, "foe") == 3
		and screen.battle.current_side() == "hero" and fight.is_visible_in_tree(),
		"non-vacuous mounted 4v3 hero turn with visible corridor")
	var slot := _multi_slot(fight)
	_check(not slot.is_empty(), "a genuine equipped part has two or more legal occupied ranks")
	if slot.is_empty():
		_finish()
		return
	var choice := fight.choose_part(slot)
	var legal := screen.legal_targets()
	var ordered := _ordered_keys(legal)
	_check(choice.get("pending") == slot and ordered.size() >= 2
		and fight._keyboard_targets == ordered and fight._keyboard_target.is_empty(),
		"part choice reads engine legal keys in deterministic side/rank order, none preselected")
	var pristine := fight.battle.state_snapshot()
	var rng := fight.battle.rng_state()
	var receipts := screen.receipts.duplicate(true)
	var hand_open := fight.battle.hand_action_open()
	# A focused part button must not get an accidental Enter/Space activation while a
	# pending choice has no explicit arrow selection.
	fight.part_buttons[slot].grab_focus()
	_key(KEY_ENTER)
	_key(KEY_SPACE)
	_unchanged(fight, pristine, rng, receipts, hand_open, "confirmation before arrow")
	_check(fight._keyboard_target.is_empty() and screen._selected_part == slot,
		"no implicit first target, selected part remains pending")
	_key(KEY_RIGHT)
	_check(fight._keyboard_target == ordered[0], "right arrow explicitly selects first legal rank")
	_check(fight.stage.figure_nodes[ordered[0]].modulate.r > 1.5
		and fight.plates[ordered[0]].get_node("Back").self_modulate.r > 1.5
		and fight.log_label.text.contains("Enter / Space"),
		"existing 3D figure/name plate and bone FightLine distinguish keyboard target")
	_key(KEY_RIGHT)
	_check(fight._keyboard_target == ordered[1], "right arrow advances to next legal occupied rank")
	_key(KEY_LEFT)
	_check(fight._keyboard_target == ordered[0], "left arrow reverses legal rank order")
	_key(KEY_UP)
	_check(fight._keyboard_target == ordered.back(), "up wraps first to last")
	_key(KEY_DOWN)
	_check(fight._keyboard_target == ordered[0], "down wraps last to first")
	_unchanged(fight, pristine, rng, receipts, hand_open, "five arrows plus highlight and clue")
	# Closing and reopening a choice, Escape and More remove the cursor but
	# preserve a fresh route for the very same valid choice.
	_key(KEY_ESCAPE)
	_check(fight._keyboard_target.is_empty() and screen._selected_part.is_empty(),
		"Escape clears keyboard cursor and engine choice")
	_unchanged(fight, pristine, rng, receipts, hand_open, "Escape cancel")
	fight.choose_part(slot)
	_key(KEY_LEFT)
	_check(fight._keyboard_target == ordered.back(), "fresh choice can select last via left arrow")
	fight.choose_part(slot)
	_check(fight._keyboard_target.is_empty() and screen._selected_part.is_empty(),
		"toggling part off clears keyboard target")
	fight.choose_part(slot)
	_key(KEY_RIGHT)
	fight.set_more_open(true)
	_check(fight._keyboard_target.is_empty() and fight._keyboard_targets.is_empty()
		and fight.more_panel.visible, "More takes focus and releases pending keyboard cursor")
	fight.set_more_open(false)
	_key(KEY_ENTER)
	_unchanged(fight, pristine, rng, receipts, hand_open, "More close cannot restore stale target")
	_key(KEY_RIGHT)
	_check(fight._keyboard_target == ordered[0], "selection after More needs fresh arrow")

	# If the engine changes its legal projection between arrow and confirm,
	# there must not be a stale click or RNG draw; another legal target remains.
	screen._target_ranks.erase(ordered[0])
	_key(KEY_SPACE)
	_unchanged(fight, pristine, rng, receipts, hand_open, "removed legal rank")
	_check(fight._keyboard_target.is_empty() and screen._selected_part == slot,
		"invalid rank resets cursor without losing the pending part")
	var remaining := _ordered_keys(screen.legal_targets())
	_check(remaining.size() >= 1 and not remaining.has(ordered[0]),
		"engine still exposes a distinct valid alternative")
	if remaining.is_empty():
		_finish()
		return
	_key(KEY_RIGHT)
	_check(fight._keyboard_target == remaining[0], "remaining legal rank can be chosen")
	screen._refresh()
	fight.refresh()
	_check(fight._keyboard_target.is_empty(), "engine target change revalidates cursor")
	_key(KEY_RIGHT)
	_check(fight._keyboard_target == ordered[0], "restored authoritative target selectable")

	# Compare mounted keyboard confirmation to identical seeded mouse transaction.
	var target := fight._keyboard_target
	var before := screen.receipts.size()
	var actor := fight.battle.current_actor_id()
	_key(KEY_ENTER)
	var keyboard_receipts := screen.receipts.duplicate(true)
	var keyboard_state := fight.battle.state_snapshot()
	var keyboard_rng := fight.battle.rng_state()
	var hero_actions := 0
	for index in range(before, screen.receipts.size()):
		if str(screen.receipts[index].get("actor", "")) == actor:
			hero_actions += 1
	_check(screen.receipts.size() > before and hero_actions == 1
		and screen._selected_part.is_empty() and fight._keyboard_target.is_empty(),
		"keyboard Enter commits exactly one real equipped part action and clears cursor")
	fight.engine.free()
	await process_frame
	var clicked := await _mount()
	if clicked == null:
		_finish()
		return
	var click_choice := clicked.choose_part(slot)
	_check(click_choice.get("pending") == slot and clicked.engine.legal_targets().has(target),
		"identical seeded mouse fixture has exactly the same legal part/target")
	var click_receipt := clicked.click_figure(target.get_slice("_", 0), int(target.get_slice("_", 1)))
	_check(click_receipt.get("ok") == true and clicked.engine.receipts == keyboard_receipts
		and clicked.battle.state_snapshot() == keyboard_state and clicked.battle.rng_state() == keyboard_rng,
		"keyboard target follows identical seeded pointer transaction and receipt")
	clicked.engine.free()
	await process_frame

	# A fresh Wren hand needs an arrow as well; Steady spends only one hand
	# receipt and does not take the acting doll's turn.
	var hand_fight := await _mount()
	if hand_fight == null:
		_finish()
		return
	var hs := hand_fight.engine
	var hand_actor := hand_fight.battle.current_actor_id()
	var hand_turn: int = int(hand_fight.battle.state_snapshot().get("turn_index"))
	_check(hand_fight.battle.hand_action_open() and hs.hand_slots().has("steady")
		and not hand_fight.hand_buttons.steady.disabled, "real Wren Steady is open")
	hand_fight.hand_buttons.steady.pressed.emit()
	var hand_keys := _ordered_keys(hs.legal_targets())
	_check(hs._hand_pending == "steady" and hand_keys.size() >= 2,
		"mounted Wren Steady waits on multiple actual dolls")
	var hand_snapshot := hand_fight.battle.state_snapshot()
	var hand_rng := hand_fight.battle.rng_state()
	var hand_receipts := hs.receipts.duplicate(true)
	_key(KEY_SPACE)
	_unchanged(hand_fight, hand_snapshot, hand_rng, hand_receipts, true, "hand confirm without arrow")
	_key(KEY_LEFT)
	_check(hand_fight._keyboard_target == hand_keys.back(), "hand arrow selects a legal doll")
	_unchanged(hand_fight, hand_snapshot, hand_rng, hand_receipts, true, "hand cycling")
	var hand_key := hand_fight._keyboard_target
	var doll_id := str(hs._unit_at("hero", int(hand_key.get_slice("_", 1))).get("id", ""))
	# Exercise the real fray reduction, not a vacuous zero-fray clamp.
	hand_fight.battle.apply_fray_event(doll_id, 20, "event")
	var fray_before := int(hand_fight.battle.get_unit(doll_id).get("fray", 0))
	_check(fray_before >= 8, "Steady target has real fray to remove")
	_key(KEY_SPACE)
	_check(hs.receipts.size() == hand_receipts.size() + 1
		and hs.receipts.back().get("action") == "hand"
		and hs.receipts.back().get("hand_action") == "steady"
		and hs.receipts.back().get("actor") == doll_id
		and not bool(hs.receipts.back().get("failed", true))
		and not hand_fight.battle.hand_action_open()
		and hand_fight.battle.current_actor_id() == hand_actor
		and hand_fight.battle.state_snapshot().get("turn_index") == hand_turn
		and int(hand_fight.battle.get_unit(doll_id).get("fray", 0)) == maxi(0, fray_before - 8),
		"Space makes one authoritative targeted Steady hand action, -8 fray, no doll turn")
	var spent_state := hand_fight.battle.state_snapshot()
	var spent_rng := hand_fight.battle.rng_state()
	var spent_receipts := hs.receipts.duplicate(true)
	_key(KEY_ENTER)
	_key(KEY_SPACE)
	_unchanged(hand_fight, spent_state, spent_rng, spent_receipts, false, "repeated hand confirm")
	_check(hand_fight._keyboard_target.is_empty(), "spent Wren hand clears selection")
	hand_fight.engine.free()
	await process_frame

	# Changing the real acting doll through an action invalidates a pending
	# cursor; no stale Enter is allowed to act on the next doll's turn.
	var turned := await _mount()
	if turned != null:
		var turn_slot := _multi_slot(turned)
		_check(not turn_slot.is_empty(), "turn-change fixture has a multi-target part")
		if not turn_slot.is_empty():
			turned.choose_part(turn_slot)
			_key(KEY_RIGHT)
			var former_actor := turned.battle.current_actor_id()
			var pass_receipt := turned.engine.submit_pass()
			turned.refresh()
			_check(pass_receipt.get("ok") == true
				and former_actor != turned.battle.current_actor_id()
				and turned._keyboard_target.is_empty(),
				"real Pass changes actor and invalidates old target")
			var post_pass := turned.battle.state_snapshot()
			var post_rng := turned.battle.rng_state()
			var post_receipts := turned.engine.receipts.duplicate(true)
			_key(KEY_ENTER)
			_unchanged(turned, post_pass, post_rng, post_receipts,
				turned.battle.hand_action_open(), "old cursor after actual turn change")
		turned.engine.free()
	await process_frame

	# An occupied foe rank becoming dead must disappear from the live legal
	# candidate set, even when a cursor was already pointed at it.
	var fallen := await _mount()
	if fallen != null:
		var fall_slot := _multi_slot(fallen)
		_check(not fall_slot.is_empty(), "fallen-rank fixture can select a legal foe")
		if not fall_slot.is_empty():
			fallen.choose_part(fall_slot)
			var foe_keys := _ordered_keys(fallen.engine.legal_targets())
			var foe_key := ""
			for key in foe_keys:
				if key.begins_with("foe_"):
					foe_key = key
					break
			_check(not foe_key.is_empty(), "equipped part genuinely includes an occupied foe rank")
			if not foe_key.is_empty():
				for index in range(foe_keys.find(foe_key) + 1):
					_key(KEY_RIGHT)
				_check(fallen._keyboard_target == foe_key, "cursor points at living foe before fall")
				var rank := int(foe_key.get_slice("_", 1))
				var original := fallen.engine._unit_at("foe", rank).duplicate(true)
				var corpse: Dictionary = fallen.battle._units[str(original.id)]
				corpse["hp"] = 0
				corpse["dead"] = true
				fallen.engine._refresh()
				fallen.refresh()
				var after_fall := fallen.battle.state_snapshot()
				var after_fall_rng := fallen.battle.rng_state()
				var after_fall_receipts := fallen.engine.receipts.duplicate(true)
				_key(KEY_SPACE)
				_check(not fallen.engine.legal_targets().has(foe_key)
					and fallen._keyboard_target.is_empty(),
					"dead foe target is removed and cursor reset")
				_unchanged(fallen, after_fall, after_fall_rng, after_fall_receipts,
					fallen.battle.hand_action_open(), "dead/empty target confirmation")
				fallen.battle._units[str(original.id)] = original.duplicate(true)
				fallen.engine._refresh()
				fallen.refresh()
				_key(KEY_RIGHT)
				_check(not fallen._keyboard_target.is_empty()
					and fallen.engine.legal_targets().has(fallen._keyboard_target),
					"restored live rank remains selectable after invalid confirmation")
		fallen.engine.free()
	await process_frame

	# Original shortcuts still feed this exact mounted engine, including
	# single-target body parts that were already designed to auto-commit.
	var shortcuts := await _mount()
	if shortcuts != null:
		_key(KEY_1)
		_check(shortcuts.engine._selected_part == "head" or not shortcuts.engine.receipts.is_empty(),
			"number 1 activates an equipped body part or its existing single-target auto-commit")
		_key(KEY_ESCAPE)
		_check(shortcuts.engine._selected_part.is_empty(), "Escape leaves number-selected part")
		_key(KEY_M)
		_check(shortcuts.more_panel.visible and shortcuts._keyboard_target.is_empty(),
			"M opens the one existing More tray")
		_key(KEY_ESCAPE)
		_check(not shortcuts.more_panel.visible, "Escape closes More without action")
		shortcuts.engine.free()
	await process_frame
	for index in range(4):
		var gift_view := await _mount()
		if gift_view == null:
			continue
		var gift_id: String = str(gift_view.engine.hand_slots()[index])
		var key_code: Key = [KEY_Q, KEY_W, KEY_E, KEY_R][index]
		var gift_before := gift_view.engine.receipts.size()
		_key(key_code)
		if StitchedBattleScreen.hand_target_side(gift_id).is_empty():
			_check(gift_view.engine.receipts.size() == gift_before + 1
				and not gift_view.battle.hand_action_open(),
				"hand shortcut %s commits its no-target gift once" % gift_id)
		else:
			_check(gift_view.engine._hand_pending == gift_id
				and gift_view.battle.hand_action_open(),
				"hand shortcut %s enters correct target mode" % gift_id)
		if gift_id == "lift":
			var lift_keys := _ordered_keys(gift_view.engine.legal_targets())
			_check(not lift_keys.is_empty(), "Lift offers authentic movable dolls")
			if not lift_keys.is_empty():
				_key(KEY_RIGHT)
				_key(KEY_ENTER)
				_check(gift_view.engine._hand_pending.begins_with("lift:")
					and gift_view.battle.hand_action_open(),
					"Lift target confirmation defers to existing Step direction")
				_key(KEY_M)
				_check(gift_view.more_panel.visible
					and (not gift_view.more_buttons.move_front.disabled
					or not gift_view.more_buttons.move_back.disabled),
					"Lift exposes an authorized Step front/back in More")
				var step: Button = gift_view.more_buttons.move_front if not gift_view.more_buttons.move_front.disabled else gift_view.more_buttons.move_back
				if not step.disabled:
					step.pressed.emit()
					_check(not gift_view.battle.hand_action_open()
						and gift_view.engine.receipts.size() == gift_before + 1,
						"directional Lift resolves through existing More button exactly once")
		gift_view.engine.free()
		await process_frame

	# Full-fight end state never retains a candidate or lets Enter/Space replay
	# an ability; the original finished Continue must remain live.
	var ended := await _mount()
	if ended != null:
		ended.battle._outcome = "victory"
		ended.engine._selected_part = ""
		ended.engine._refresh()
		ended.refresh()
		var ended_state := ended.battle.state_snapshot()
		var ended_rng := ended.battle.rng_state()
		var ended_receipts := ended.engine.receipts.duplicate(true)
		_check(ended._keyboard_target.is_empty() and ended._keyboard_targets.is_empty()
			and ended.continue_button.visible, "completed battle clears target mode and shows Continue")
		var exited := [false]
		ended.engine.exit_requested.connect(func(): exited[0] = true)
		_key(KEY_ENTER)
		_check(exited[0], "finished-fight Enter still reaches Continue")
		_unchanged(ended, ended_state, ended_rng, ended_receipts,
			ended.battle.hand_action_open(), "finished Continue never spends battle state")
		ended.engine.free()
	_finish()


func _finish() -> void:
	for error in failures:
		printerr(error)
	print("stitched_s11_corridor_keyboard_target_test: %s (%d checks, %d failures)" % [
		"PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
