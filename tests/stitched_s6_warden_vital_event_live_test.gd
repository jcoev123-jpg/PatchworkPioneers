extends "res://tests/stitched_s6_full_run_test.gd"
## Deterministic headless live-session test for routing Warden Buckle-Heart vital event (S6).

func _run() -> void:
	await _test_ac1_admission_and_mounting()
	await _test_ac2_positive_choices_and_derived_max()
	await _test_ac3_refusal_and_fail_closed()
	await _test_ac4_save_replay_and_generic_route()
	StitchedRunSession.pinned_event_id = ""
	_done()


func _first_event_node(session: StitchedRunSession) -> String:
	for node_id in session.choices():
		if session.map.get_node(node_id).type == "Event":
			return node_id
	return ""


## AC1: Given the live seeded four-doll Stitched run with a present, non-LOST Warden,
## v3_warden_buckle_heart_ward is a real eligible Event and displays its three quoted choices
## through the existing Event control path; without an eligible Warden it cannot be sampled.
func _test_ac1_admission_and_mounting() -> void:
	StitchedRunSession.pinned_event_id = "v3_warden_buckle_heart_ward"

	# Mounted UI verification
	var app: Node = await _new_run(234)
	var live: StitchedRunSession = app.stitched_run_session
	_check(live != null, "AC1: Real session created through app flow")
	if live != null:
		var event_node := _first_event_node(live)
		_check(not event_node.is_empty(), "AC1: Found floor 1 Event node at seed 234")
		var pressed := _press_route(app, event_node)
		_check(pressed and live.phase == "visit", "AC1: Real route enters Event node")
		_check(live.pending.event_id == "v3_warden_buckle_heart_ward", "AC1: Published event_id is v3_warden_buckle_heart_ward")
		_check(live.pending.title == "The Buckle-Heart Ward", "AC1: Published title is The Buckle-Heart Ward")
		_check(live.visit_story().begins_with("A huge patched shield"), "AC1: Story text matches authored description")
		_check(live._service is RunStitchedHeroVitalSeams, "AC1: Live service is RunStitchedHeroVitalSeams")

		var actions: Array = live.visit_actions()
		_check(actions.size() == 3, "AC1: Exactly three authored actions published")
		var expected_ids := ["reinforce_shield_seam", "sell_rivets", "leave"]
		var expected_texts := [
			"Spend 2 scraps to sew a lasting shield seam (+3 max HP)",
			"Trade 2 max HP of rivets for 24 gold",
			"Leave the rivet gate untouched",
		]
		for i in range(actions.size()):
			_check(actions[i].id == expected_ids[i], "AC1: Choice %d ID matches %s" % [i, expected_ids[i]])
			_check(actions[i].text == expected_texts[i], "AC1: Choice %d text matches authored string" % i)

		# Buttons mounted in app UI
		_check(app.stitched_run_buttons.size() >= 3, "AC1: Mounted Event buttons exist")
		for i in range(actions.size()):
			var button: Button = app.stitched_run_buttons[i]
			_check(button.get_meta("action_id") == actions[i].id, "AC1: Button %d meta action_id is %s" % [i, actions[i].id])
			_check(button.focus_mode == Control.FOCUS_ALL, "AC1: Button %d focusable by mouse and keyboard" % i)
			_check(button.disabled == (not actions[i].enabled), "AC1: Button %d disabled state reflects availability" % i)
	app.free()
	await process_frame

	# Exclusion 1: Party without Warden never samples or offers this event
	var no_warden_session := StitchedRunSession.start(234, ["seamstress", "tinker", "lantern_monk", "rag_duelist"])
	_check(no_warden_session != null, "AC1: Party without Warden initialized")
	if no_warden_session != null:
		var target := _first_event_node(no_warden_session)
		_check(not target.is_empty(), "AC1: Event node present for non-Warden party")
		var entered := no_warden_session.enter(target, no_warden_session.snapshot())
		_check(entered and no_warden_session.phase == "visit", "AC1: Map entry succeeds for non-Warden party")
		_check(no_warden_session.pending.event_id != "v3_warden_buckle_heart_ward",
			"AC1: Party without Warden never offers v3_warden_buckle_heart_ward")

	# Exclusion 2: Party with LOST Warden never samples or offers this event
	var lost_session := StitchedRunSession.start(234)
	_check(lost_session != null, "AC1: Session with Warden initialized")
	if lost_session != null:
		var target := _first_event_node(lost_session)
		# Mark Warden as lost before entering event
		for hero in lost_session.heroes:
			if hero.id == "warden":
				hero.lost = true
				hero.hp = 0
				hero.parts.clear()
		lost_session._seal()
		var entered := lost_session.enter(target, lost_session.snapshot())
		_check(entered and lost_session.phase == "visit", "AC1: Map entry succeeds for party with LOST Warden")
		_check(lost_session.pending.event_id != "v3_warden_buckle_heart_ward",
			"AC1: Party with LOST Warden never offers v3_warden_buckle_heart_ward")

	StitchedRunSession.pinned_event_id = ""


## AC2: Given sufficient wallet and a legal real Warden choice, reinforce_shield_seam pays 2 scraps
## for permanent +3 Warden max HP without a heal; sell_rivets grants 24 gold for -2 permanent
## Warden max HP, respecting floor 10/clamping; leave changes nothing.
## Three fresh real-session receipts, derived-maximum recomputation and saved replay prove correct values
## and no other doll altered.
func _test_ac2_positive_choices_and_derived_max() -> void:
	StitchedRunSession.pinned_event_id = "v3_warden_buckle_heart_ward"

	# Branch A: reinforce_shield_seam (+3 max HP, -2 scraps, no heal)
	var session_a := StitchedRunSession.start(234)
	session_a.scraps = 5
	session_a._seal()
	var node_a := _first_event_node(session_a)
	_check(session_a.enter(node_a, session_a.snapshot()), "AC2: Entered Event node for reinforce_shield_seam")

	var scraps_before := session_a.scraps
	var gold_before := session_a.gold
	var warden_a: Dictionary = session_a.heroes[0]
	_check(warden_a.id == "warden", "AC2: First hero is Warden")
	var base_max_before := int(warden_a.base_max_hp)
	var eff_max_before := int(warden_a.max_hp)
	var hp_before := int(warden_a.hp)
	var other_heroes_before: Array = []
	for i in range(1, 4):
		other_heroes_before.append(session_a.heroes[i].duplicate(true))

	var chosen_a := session_a.choose_visit("reinforce_shield_seam", [], session_a.snapshot())
	_check(chosen_a, "AC2: choose_visit reinforce_shield_seam succeeded")
	_check(session_a.phase == "map", "AC2: Phase returned to map after reinforce_shield_seam")
	_check(session_a.scraps == scraps_before - 2, "AC2: Scraps decreased by exactly 2")
	_check(session_a.gold == gold_before, "AC2: Gold unchanged by reinforce_shield_seam")

	var warden_after_a: Dictionary = session_a.heroes[0]
	_check(warden_after_a.base_max_hp == base_max_before + 3, "AC2: Warden base_max_hp increased by +3")
	_check(warden_after_a.max_hp == eff_max_before + 3, "AC2: Warden effective max_hp increased by +3")
	_check(warden_after_a.hp == hp_before, "AC2: Warden current HP unchanged (not healed)")

	for i in range(1, 4):
		_check(session_a.heroes[i] == other_heroes_before[i - 1], "AC2: Companion hero %s unchanged" % session_a.heroes[i].id)

	_check(session_a.receipts.size() == 1, "AC2: Exactly one receipt recorded")
	var r_a: Dictionary = session_a.receipts[0]
	_check(r_a.node_id == node_a and r_a.decision == "reinforce_shield_seam" and r_a.event_id == "v3_warden_buckle_heart_ward",
		"AC2: Receipt stamps node_id, decision and event_id")

	# Branch B: sell_rivets (+24 gold, -2 max HP, HP clamped)
	var session_b := StitchedRunSession.start(234)
	var node_b := _first_event_node(session_b)
	_check(session_b.enter(node_b, session_b.snapshot()), "AC2: Entered Event node for sell_rivets")

	var gold_before_b := session_b.gold
	var scraps_before_b := session_b.scraps
	var warden_b: Dictionary = session_b.heroes[0]
	var base_max_b := int(warden_b.base_max_hp)
	var eff_max_b := int(warden_b.max_hp)

	var chosen_b := session_b.choose_visit("sell_rivets", [], session_b.snapshot())
	_check(chosen_b, "AC2: choose_visit sell_rivets succeeded")
	_check(session_b.phase == "map", "AC2: Phase returned to map after sell_rivets")
	_check(session_b.gold == gold_before_b + 24, "AC2: Gold increased by exactly 24")
	_check(session_b.scraps == scraps_before_b, "AC2: Scraps unchanged by sell_rivets")

	var warden_after_b: Dictionary = session_b.heroes[0]
	_check(warden_after_b.base_max_hp == base_max_b - 2, "AC2: Warden base_max_hp decreased by -2")
	_check(warden_after_b.max_hp == eff_max_b - 2, "AC2: Warden effective max_hp decreased by -2")
	_check(warden_after_b.hp <= warden_after_b.max_hp, "AC2: Warden current HP clamped to reduced max HP")

	# Branch B2: Floor 10 boundary: when effective max HP is 10, sell_rivets is disallowed
	var session_b2 := StitchedRunSession.start(234)
	# Configure Warden with base_max_hp = 4 and torso (+6) giving effective max_hp = 10
	session_b2.heroes[0].base_max_hp = 4
	session_b2.heroes[0].max_hp = 10
	session_b2.heroes[0].hp = 10
	session_b2._seal()
	var node_b2 := _first_event_node(session_b2)
	_check(session_b2.enter(node_b2, session_b2.snapshot()), "AC2: Entered Event node at floor 10 max HP")
	var actions_b2 := session_b2.visit_actions()
	for act in actions_b2:
		if act.id == "sell_rivets":
			_check(not act.enabled, "AC2: sell_rivets disabled at vitality floor 10")
	var rejected_floor := session_b2.choose_visit("sell_rivets", [], session_b2.snapshot())
	_check(not rejected_floor, "AC2: choose_visit sell_rivets rejected at vitality floor 10")
	_check(session_b2.heroes[0].max_hp == 10, "AC2: Warden max HP unchanged on floor rejection")

	# Branch C: leave (no mutations)
	var session_c := StitchedRunSession.start(234)
	var node_c := _first_event_node(session_c)
	_check(session_c.enter(node_c, session_c.snapshot()), "AC2: Entered Event node for leave")
	var snap_c_before := session_c.snapshot()
	var chosen_c := session_c.choose_visit("leave", [], session_c.snapshot())
	_check(chosen_c, "AC2: choose_visit leave succeeded")
	_check(session_c.phase == "map", "AC2: Phase returned to map after leave")
	_check(session_c.gold == snap_c_before.gold and session_c.scraps == snap_c_before.scraps, "AC2: Wallet unchanged by leave")
	_check(session_c.heroes[0].base_max_hp == snap_c_before.heroes[0].base_max_hp, "AC2: Warden base_max_hp unchanged by leave")
	_check(session_c.heroes[0].max_hp == snap_c_before.heroes[0].max_hp, "AC2: Warden max_hp unchanged by leave")
	_check(session_c.receipts.size() == 1 and session_c.receipts[0].decision == "leave", "AC2: Leave receipt stamped")

	StitchedRunSession.pinned_event_id = ""


## AC3: Given a disabled, stale, ineligible, unoffered or replayed choice, no wallet,
## hero, candle, RNG, receipt or journal is consumed; a success makes exactly one normal
## visit receipt and ends the visit.
func _test_ac3_refusal_and_fail_closed() -> void:
	StitchedRunSession.pinned_event_id = "v3_warden_buckle_heart_ward"

	# Insufficient scraps disables reinforce_shield_seam
	var session := StitchedRunSession.start(234)
	session.scraps = 1
	session._seal()
	var node := _first_event_node(session)
	_check(session.enter(node, session.snapshot()), "AC3: Entered Event node with 1 scrap")

	var actions := session.visit_actions()
	for act in actions:
		if act.id == "reinforce_shield_seam":
			_check(not act.enabled, "AC3: reinforce_shield_seam is disabled with 1 scrap")

	var state_before := session.snapshot()
	var journal_size_before := session.journal.size()
	var receipts_size_before := session.receipts.size()

	# Refusal 1: choosing disabled action
	var disabled_res := session.choose_visit("reinforce_shield_seam", [], session.snapshot())
	_check(not disabled_res, "AC3: Disabled choice rejected")
	_check(session.snapshot() == state_before, "AC3: No state mutation on disabled choice")
	_check(session.journal.size() == journal_size_before, "AC3: No journal entry on disabled choice")
	_check(session.receipts.size() == receipts_size_before, "AC3: No receipt on disabled choice")

	# Refusal 2: unoffered choice ID
	var unoffered_res := session.choose_visit("bogus_unoffered_action", [], session.snapshot())
	_check(not unoffered_res, "AC3: Unoffered choice rejected")
	_check(session.snapshot() == state_before, "AC3: No state mutation on unoffered choice")

	# Refusal 3: unexpected arguments
	var arg_mismatch := session.choose_visit("leave", [42], session.snapshot())
	_check(not arg_mismatch, "AC3: Argument mismatch rejected")
	_check(session.snapshot() == state_before, "AC3: No state mutation on argument mismatch")

	# Refusal 4: stale expected snapshot
	var stale_res := session.choose_visit("leave", [], {})
	_check(not stale_res, "AC3: Stale expected snapshot rejected")
	_check(session.snapshot() == state_before, "AC3: No state mutation on stale snapshot")

	# Valid choice ends visit
	var valid_res := session.choose_visit("leave", [], session.snapshot())
	_check(valid_res, "AC3: Valid leave choice commits successfully")
	_check(session.phase == "map", "AC3: Visit ended, phase is map")
	_check(session.receipts.size() == receipts_size_before + 1, "AC3: Exactly one receipt stamped")

	# Refusal 5: replayed choice after visit ended
	var state_after_commit := session.snapshot()
	var replayed_res := session.choose_visit("leave", [], session.snapshot())
	_check(not replayed_res, "AC3: Replayed choice after visit ended rejected")
	_check(session.snapshot() == state_after_commit, "AC3: No state mutation on replayed choice")

	StitchedRunSession.pinned_event_id = ""


## AC4: Given an authentic drawn Warden Event, save/replay matches the same journal,
## pending/settled event, wallet, max-HP baseline, four-doll state and RNG; unrelated
## Event/Walk/fight routes still operate and use the existing authored dark-gothic Event visual treatment.
func _test_ac4_save_replay_and_generic_route() -> void:
	StitchedRunSession.pinned_event_id = "v3_warden_buckle_heart_ward"

	# Save/restore during pending Warden Event
	var session_pending := StitchedRunSession.start(234)
	var node_p := _first_event_node(session_pending)
	_check(session_pending.enter(node_p, session_pending.snapshot()), "AC4: Entered pending Event node")

	var doc_pending := StitchedRunSave.capture(session_pending)
	_check(not doc_pending.is_empty(), "AC4: Captured save document during pending Warden Event")
	var restored_pending := StitchedRunSave.restore(doc_pending)
	_check(restored_pending != null, "AC4: Restored session from pending Warden Event save")
	if restored_pending != null:
		_check(restored_pending.snapshot() == session_pending.snapshot(),
			"AC4: Snapshot exact match on pending Warden Event restore")
		_check(restored_pending.pending.event_id == "v3_warden_buckle_heart_ward",
			"AC4: Restored pending event_id matches")
		_check(restored_pending.visit_actions().size() == 3,
			"AC4: Restored visit actions intact")
		# Can commit choice on restored session
		var commit_restored := restored_pending.choose_visit("sell_rivets", [], restored_pending.snapshot())
		_check(commit_restored, "AC4: Restored session executes choice_visit successfully")
		_check(restored_pending.phase == "map", "AC4: Restored session phase returned to map")

	# Save/restore after settled Warden Event (sell_rivets branch mutating wallet & max-HP baseline)
	var session_settled := StitchedRunSession.start(234)
	var node_s := _first_event_node(session_settled)
	session_settled.enter(node_s, session_settled.snapshot())
	session_settled.choose_visit("sell_rivets", [], session_settled.snapshot())

	var doc_settled := StitchedRunSave.capture(session_settled)
	_check(not doc_settled.is_empty(), "AC4: Captured save document after settled choice")
	var restored_settled := StitchedRunSave.restore(doc_settled)
	_check(restored_settled != null, "AC4: Restored session from settled save")
	if restored_settled != null:
		_check(restored_settled.snapshot() == session_settled.snapshot(),
			"AC4: Snapshot exact match on settled Warden Event restore")
		_check(restored_settled.journal == session_settled.journal,
			"AC4: Journal exact match on settled restore")
		_check(restored_settled.receipts == session_settled.receipts,
			"AC4: Receipts exact match on settled restore")
		_check(restored_settled.gold == session_settled.gold,
			"AC4: Wallet gold persisted across save/replay")
		_check(restored_settled.heroes[0].base_max_hp == session_settled.heroes[0].base_max_hp,
			"AC4: Warden base_max_hp persisted across save/replay")
		_check(restored_settled.heroes[0].max_hp == session_settled.heroes[0].max_hp,
			"AC4: Warden effective max_hp persisted across save/replay")

	# Save/restore after leave branch
	var session_leave := StitchedRunSession.start(234)
	var node_l := _first_event_node(session_leave)
	session_leave.enter(node_l, session_leave.snapshot())
	session_leave.choose_visit("leave", [], session_leave.snapshot())
	var doc_leave := StitchedRunSave.capture(session_leave)
	var restored_leave := StitchedRunSave.restore(doc_leave)
	_check(restored_leave != null and restored_leave.snapshot() == session_leave.snapshot(),
		"AC4: Snapshot exact match on settled leave choice restore")

	# Unpinned generic Event route still operates
	StitchedRunSession.pinned_event_id = ""
	var session_generic := StitchedRunSession.start(234)
	var node_g := _first_event_node(session_generic)
	_check(session_generic.enter(node_g, session_generic.snapshot()), "AC4: Generic event entered without pin")
	_check(session_generic.phase == "visit" and session_generic.pending.service == "Event",
		"AC4: Generic Event visit opened successfully")
	_check(not session_generic.visit_actions().is_empty(), "AC4: Generic Event published legal actions")

	# Generic converter protection: unsupported legacy hp-only outcome rejected
	var legacy_bad := {
		"id": "legacy_hp_bad",
		"title": "Legacy Bad",
		"description": "Unsupported",
		"choices": [{"id": "bad", "text": "Bad", "outcome": {"hp": -3}}]
	}
	_check(session_generic._convert_event(legacy_bad, {}).is_empty(),
		"AC4: Generic _convert_event maintains fail-closed rejection on legacy hp-only outcome")


func _done() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s6_warden_vital_event_live_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

