extends SceneTree
## S6 Roadblock: the mounted title's authenticated Fight consumes one 8-point
## candle charge; isolated S2 still begins at its authored 78.
var failures: Array[String] = []
var checks := 0

const CIRCLE_BUILD_SCRIPT := """extends "res://scripts/app.gd"
var fail_circle_build := false
var circle_builds := 0
func _build_stitched_sewing(panel: Control, quote: Dictionary,
		mend_quote: Dictionary, upgrade_quote: Dictionary) -> bool:
	circle_builds += 1
	if fail_circle_build:
		return false
	return super._build_stitched_sewing(panel, quote, mend_quote, upgrade_quote)
"""

func _carry(app: Node) -> Dictionary:
	return {"candle": app.stitched_roadblock_candle, "gold": app.stitched_preview_gold,
		"scraps": app.stitched_preview_scraps, "satchel": app.stitched_preview_satchel.duplicate(true),
		"gear": app._stitched_gear_overrides.duplicate(true),
		"hp": app._stitched_hp_carry.duplicate(true),
		"ranks": app._stitched_rank_carry.duplicate(true),
		"fray": app._stitched_fray_carry.duplicate(true),
		"party": app._stitched_party_picks.duplicate()}

func _circle_case(candle: Variant, fail_build: bool = false, bad_service: bool = false) -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	var script := GDScript.new()
	script.source_code = CIRCLE_BUILD_SCRIPT
	_check(script.reload() == OK, "Circle mount-failure subclass compiles")
	app.set_script(script)
	app.fail_circle_build = fail_build
	root.add_child(app)
	await process_frame
	var fresh := _carry(app)
	_check(not app._open_stitched_sewing([], []) and _carry(app) == fresh,
		"fresh/unwon direct Circle entry cannot open or spend")
	var stage: StitchedBattleScreen = await _admit(app)
	_check(_battle_input(stage, 92), "boundary witness first pays real Fight 100 -> 92")
	var victory := _victory(stage)
	_check(victory.get("outcome") == "victory" and victory.get("abilities", 0) > 0,
		"Circle boundary witness earns an authentic legal victory")
	if stage == null or victory.get("outcome") != "victory":
		app.free()
		return
	var heroes: Array = stage.battle.get_heroes()
	_check(heroes.size() == 4 and heroes.all(func(hero): return not hero.get("lost", false)),
		"Circle boundary victory has four real survivors")
	var live := _carry(app)
	_check(not app._open_stitched_sewing(heroes, app.STITCHED_ROADBLOCK_FOES)
		and _carry(app) == live, "even won combat cannot bypass its authenticated exit")
	# Boundary fixtures affect only the entrance ledger, after real combat.
	app.stitched_roadblock_candle = candle
	if bad_service:
		app.stitched_preview_satchel.append({"id": "invalid", "slot": "arms", "tier": 1, "torn": false})
	seed(53201)
	var expected_rng := randi()
	seed(53201)
	var stage_ref: WeakRef = weakref(stage)
	await _exit(stage)
	var valid := typeof(candle) == TYPE_INT and int(candle) >= 0 and int(candle) <= 100
	var mounted := valid and not fail_build and not bad_service
	var expected: Variant = maxi(0, int(candle) - 8) if mounted else candle
	_check(typeof(app.stitched_roadblock_candle) == typeof(expected)
		and app.stitched_roadblock_candle == expected
		and is_instance_valid(app.stitched_sewing_panel) == mounted
		and (app.stitched_sewing_visit != null) == mounted
		and (app.stitched_sewing_mend_visit != null) == mounted
		and (app.stitched_sewing_upgrade_visit != null) == mounted,
		"valid entrance debits once; invalid ledger/service/build publishes nothing: %s" % str(candle))
	_check(app.stitched_preview_gold == 10 and app.stitched_preview_scraps == 1
		and app.stitched_preview_satchel.size() == (4 if bad_service else 3)
		and app._stitched_party_picks == live["party"] and app._stitched_gear_overrides == live["gear"]
		and randi() == expected_rng and _neutral(app),
		"entrance preserves normal victory rewards, party, gear, wallets and global RNG")
	_check(app.circle_builds == (1 if valid and not bad_service else 0),
		"invalid ledgers/services fail before panel construction; failed build was actually exercised")
	var settled := _carry(app)
	app._stitched_fight_exit(stage_ref)
	_check(not app._open_stitched_sewing(heroes, app.STITCHED_ROADBLOCK_FOES)
		and _carry(app) == settled, "retired exit and direct replay cannot remount or double charge")
	if mounted:
		var panel: Control = app.stitched_sewing_panel
		var panel_ref: WeakRef = weakref(panel)
		var state: Dictionary = app.stitched_sewing_visit.read_state()
		panel.get_node("SewingLeave").pressed.emit()
		await process_frame
		_check(app.stitched_sewing_panel == null and _carry(app)["candle"] == expected,
			"Circle Leave keeps the charged boundary ledger")
		var onward := _carry(app)
		_check(not app._stitched_sewing_leave(state, panel_ref).get("ok")
			and not app._open_stitched_sewing(heroes, app.STITCHED_ROADBLOCK_FOES)
			and _carry(app) == onward, "stale Leave/direct entry preserves every onward ledger")
		var next: StitchedBattleScreen = await _admit(app)
		_check(_battle_input(next, maxi(0, int(expected) - 8))
			and app.stitched_roadblock_candle == maxi(0, int(expected) - 8),
			"following real Roadblock receives exactly charged Circle carry minus its own debit")
	app.free()
	await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures.append(note)

func _spawn() -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	return app

func _neutral(app: Node) -> bool:
	return app.deck == null and app.run_map == null and app.run_rng == null \
		and app.session_gold == 0 and app.run_scraps == 0 \
		and app.run_deck.is_empty() and app.run_heroes.is_empty() \
		and app._stitched_gear_overrides.is_empty()

func _offer(app: Node) -> LiveEventChoicePanel:
	if not app.title_view.is_visible_in_tree():
		return null
	app._open_stitched_fight() # Explicit Roadblock regression entry.
	await process_frame
	return app.stitched_event_panel

func _admit(app: Node) -> StitchedBattleScreen:
	var panel: LiveEventChoicePanel = await _offer(app)
	if panel == null or not panel.has_open_event():
		_check(false, "genuine title action mounted an authenticated Roadblock")
		return null
	var buttons := panel.get_choice_buttons()
	if buttons.size() != 3 or buttons[0].disabled or app.stitched_event_gate == null:
		_check(false, "genuine Roadblock offers its enabled Fight")
		return null
	buttons[0].pressed.emit()
	await process_frame
	return app.stitched_fight_view

func _battle_input(stage: StitchedBattleScreen, expected: int) -> bool:
	return stage != null and stage.is_inside_tree() and stage.is_visible_in_tree() \
		and stage.get_parent() != null and stage.battle != null \
		and stage.battle.is_valid() and stage.config.get("candle") == expected \
		and stage.battle.candle() == expected \
		and stage.battle.state_snapshot().get("candle") == expected \
		and stage.battle.candle_band() == StitchedS1BEffects.candle_band(expected) \
		and stage._labels.has("candle") \
		and stage._labels["candle"].text.contains("CANDLE  %d / 100" % expected)

func _exit(stage: StitchedBattleScreen) -> void:
	if stage != null and stage._action_buttons.has("exit"):
		stage._action_buttons["exit"].pressed.emit()
	await process_frame

func _victory(stage: StitchedBattleScreen) -> Dictionary:
	# Drive the actual mounted rules controller with legal abilities, as in the
	# S5 spoils regression. No HP, outcome, foe roster or RNG fixture mutation.
	if stage == null or stage.battle == null:
		return {}
	var steps := 0
	var abilities := 0
	for turn in range(100):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		var actor: Dictionary = stage.battle.get_unit(stage.battle.current_actor_id())
		var score := -10000
		var part_id := ""
		var target_rank := 0
		for slot in StitchedParts.SLOTS:
			if not stage._valid_part(actor, actor["parts"][slot]):
				continue
			var candidate := str(actor["parts"][slot]["id"])
			var definition: Dictionary = stage.parts.get(candidate, {})
			var skill: Dictionary = StitchedParts.ability_at_tier(
				definition, int(actor["parts"][slot]["tier"]))
			for rank in range(1, 5):
				var legal: Array = stage.battle._legal_targets(actor, skill, rank)
				if legal.is_empty():
					continue
				var weight := -20
				if str(legal[0]["side"]) == "foe":
					weight = int(skill.get("dmg", [0, 0])[1]) * 4 \
						+ int(skill.get("dmg", [0, 0])[0])
					if str(skill.get("kind", "")) == "ranged":
						weight += 1
					if rank == 1:
						weight += 3
				elif str(skill.get("kind", "")) == "heal":
					var ally: Dictionary = stage._unit_at("hero", rank)
					var missing := int(ally.get("max_hp", 0)) - int(ally.get("hp", 0))
					if missing >= 8:
						weight = 38 + missing
				if weight > score:
					score = weight
					part_id = candidate
					target_rank = rank
		var receipt: Dictionary
		if not part_id.is_empty():
			receipt = stage.submit_part(part_id, target_rank)
			if receipt.get("ok") == true and receipt.get("action") == "ability":
				abilities += 1
		else:
			receipt = stage.submit_pass()
		if receipt.get("ok") != true:
			break
		steps += 1
	return {"outcome": stage.battle.outcome(), "steps": steps, "abilities": abilities,
		"foes": stage.battle.get_foes().size(), "rng": stage.battle.rng_state(),
		"receipts": stage.receipts.duplicate(true)}

func _trace() -> Dictionary:
	var app := _spawn()
	await process_frame
	_check(_neutral(app) and app.stitched_roadblock_candle == 100 \
		and not app.stitched_fight_button.is_visible_in_tree()
		and app.stitched_fight_button.disabled and app.start_button.is_visible_in_tree(),
		"fresh real title begins with independent candle 100 and untouched run wallets")
	var s2 := StitchedBattleScreen.read_preview()
	_check(s2.get("candle") == 78 and app._stitched_floor_config().get("candle") == 78,
		"S2 preview/config remains at 78 until authenticated S6 Fight projection")

	var panel: LiveEventChoicePanel = await _offer(app)
	if panel == null or app.stitched_event_gate == null:
		_check(false, "initial genuine Roadblock exists")
		app.free()
		await process_frame
		return {}
	var gate: RunV3FightEventGate = app.stitched_event_gate
	var buttons: Array = panel.get_choice_buttons()
	if buttons.size() != 3:
		_check(false, "three canonical Roadblock choices are mounted")
		app.free()
		await process_frame
		return {}
	var selector: RunEventChoice = panel._selector
	var forged := {"ok": true, "event_id": app.STITCHED_ROADBLOCK_ID,
		"choice_id": gate.get_fight_choice_id(), "wallet": {"gold": 0, "scraps": 0},
		"fight_request": {"node_type": "Fight"}}
	seed(513608)
	var rng_expected := randi()
	seed(513608)
	_check(gate.is_valid() and not gate.is_claimed() and not buttons[0].disabled \
		and buttons[1].disabled and not buttons[2].disabled,
		"unclaimed Fight, blocked toll and permitted Leave are real UI choices")
	app._commit_stitched_roadblock(forged, weakref(panel), gate)
	_check(not app._begin_stitched_battle(forged, gate),
		"direct forged admission cannot bypass authentic panel claim")
	panel._on_choice_pressed(selector, gate.get_fight_choice_id(), panel._generation - 1, buttons[0])
	panel._on_choice_pressed(selector, gate.get_fight_choice_id(), panel._generation, buttons[1])
	buttons[1].pressed.emit()
	_check(app.stitched_roadblock_candle == 100 and app.stitched_fight_view == null \
		and not gate.is_claimed() and _neutral(app),
		"forged, stale, wrong-button and unaffordable choices never debit")
	# A disabled party draft is another blocked genuine Fight.
	var warden_box: CheckBox = app._stitched_party_checkboxes.get("warden")
	_check(warden_box != null, "real party picker checkbox is mounted")
	if warden_box != null:
		warden_box.button_pressed = false
		_check(buttons[0].disabled and app.stitched_roadblock_candle == 100,
			"incomplete party disables live Fight without debit")
		buttons[0].pressed.emit()
		warden_box.button_pressed = true
	_check(app.stitched_fight_view == null and app.stitched_roadblock_candle == 100,
		"disabled choice injection is no admission")
	buttons[2].pressed.emit()
	await process_frame
	_check(gate.is_claimed() and app.stitched_event_panel == null \
		and app.stitched_fight_view == null and app.stitched_roadblock_candle == 100,
		"authentic Leave preserves all 100 candle points")
	_check(not app._begin_stitched_battle(forged, gate) \
		and app.stitched_roadblock_candle == 100,
		"claimed Leave ticket cannot be forged into later direct Fight")
	_check(randi() == rng_expected and _neutral(app),
		"all rejected/Leave paths preserve global RNG, gear and legacy wallets")

	# Genuine UI ticket, but invalid supplied gear prevents stage configuration:
	# gate claim is allowed, unsuccessful mount must not burn candle.
	app._stitched_gear_overrides["warden"] = {
		"arms": {"id": "not_a_real_part", "tier": 1, "torn": false}}
	var failed_panel: LiveEventChoicePanel = await _offer(app)
	_check(failed_panel != null and failed_panel.get_choice_buttons().size() == 3,
		"failed mount witness still starts from a real offered Fight")
	if failed_panel != null:
		failed_panel.get_choice_buttons()[0].pressed.emit()
		await process_frame
	_check(app.stitched_roadblock_candle == 100 and app.stitched_fight_view == null \
		and app.title_view.is_visible_in_tree() \
		and app._stitched_gear_overrides.has("warden"),
		"failed real admission/config build does not debit or alter carried invalid gear")
	app._stitched_gear_overrides.clear()

	var first: StitchedBattleScreen = await _admit(app)
	if first == null:
		_check(false, "first real Fight must mount")
		app.free()
		await process_frame
		return {}
	_check(_battle_input(first, 92) and app.stitched_roadblock_candle == 92,
		"100 -> 92 charged once on mounted Fight, delivered to battle rules and HUD")
	var first_start := first.battle.state_snapshot()
	var first_rng := first.battle.rng_state()
	# Duplicate/stale panel callbacks and external begin cannot double charge.
	var stale_receipt := forged.duplicate(true)
	app._commit_stitched_roadblock(stale_receipt, weakref(panel), gate)
	_check(not app._begin_stitched_battle(stale_receipt, gate) \
		and app.stitched_fight_view == first and app.stitched_roadblock_candle == 92 \
		and first.battle.state_snapshot() == first_start and first.battle.rng_state() == first_rng,
		"duplicate/stale claims neither create another stage nor burn twice")
	await _exit(first)
	_check(app.stitched_roadblock_candle == 92 and app.stitched_fight_view == null \
		and app.title_view.is_visible_in_tree() and _neutral(app),
		"unwon exit retains debit, refunds nothing, and preserves run/gear")
	var second: StitchedBattleScreen = await _admit(app)
	if second == null:
		_check(false, "second real Fight must mount")
		app.free()
		await process_frame
		return {}
	_check(_battle_input(second, 84) and app.stitched_roadblock_candle == 84,
		"second independently claimed Fight receives 84 rather than S2 reset")
	var second_start := second.battle.state_snapshot()
	var second_rng := second.battle.rng_state()
	var victory := _victory(second)
	_check(victory.get("outcome") == "victory" \
		and int(victory.get("steps", 0)) > 0 and int(victory.get("abilities", 0)) > 0 \
		and victory.get("foes") == 3,
		"mounted combat earns genuine victory before Sewing Circle")
	if victory.get("outcome") != "victory":
		await _exit(second)
		app.free()
		await process_frame
		return {}
	await _exit(second)
	var circle: Control = app.stitched_sewing_panel
	_check(circle != null and circle.is_visible_in_tree() \
		and app.stitched_sewing_visit != null and app.stitched_sewing_mend_visit != null \
		and app.stitched_roadblock_candle == 76 and app.stitched_preview_scraps == 1 \
		and app.stitched_preview_satchel.size() == 3,
		"authentic victory mounts real Circle with its independent eight-candle debit")
	if circle == null:
		app.free()
		await process_frame
		return {}
	var leave: Button = circle.get_node_or_null("SewingLeave") as Button
	_check(leave != null and not leave.disabled, "real Sewing Circle Leave control exists")
	if leave != null:
		leave.pressed.emit()
		await process_frame
	_check(app.stitched_sewing_panel == null and app.stitched_roadblock_candle == 76 \
		and app.title_view.is_visible_in_tree() and _neutral(app),
		"Circle Leave returns to same title with 76 candle and no run-wallet change")

	var repeats: Array = []
	var zero_snapshot: Dictionary = {}
	var zero_rng := 0
	# At 76, nine more entries reach 4, the next hits 0; further real
	# admissions stay at zero (not a direct private-state clamp fixture).
	for index in range(13):
		var before: int = app.stitched_roadblock_candle
		var expected: int = maxi(0, before - 8)
		var stage: StitchedBattleScreen = await _admit(app)
		if stage == null:
			_check(false, "repeat Fight mounted at entry " + str(index))
			app.free()
			await process_frame
			return {}
		_check(_battle_input(stage, expected) \
			and app.stitched_roadblock_candle == expected,
			"repeat authenticated Fight %d clamps to %d and passes it to stage" % [index, expected])
		repeats.append({"before": before, "after": expected})
		if expected == 0:
			var snapshot := stage.battle.state_snapshot()
			var state := stage.battle.rng_state()
			if zero_snapshot.is_empty():
				zero_snapshot = snapshot
				zero_rng = state
			else:
				_check(snapshot == zero_snapshot and state == zero_rng,
					"independent zero-candle mounted fights start with identical rules/RNG")
		await _exit(stage)
		_check(app.stitched_roadblock_candle == expected and _neutral(app),
			"repeat exit does not refund or touch normal wallets")
	_check(app.stitched_roadblock_candle == 0 \
		and repeats.size() == 13 and repeats[repeats.size() - 1]["after"] == 0,
		"13 genuine repeat entries floor at zero without underflow")
	var final_offer: LiveEventChoicePanel = await _offer(app)
	_check(final_offer != null and app.stitched_roadblock_candle == 0,
		"reopened unclaimed offer does not spend at zero")
	if final_offer != null:
		final_offer.get_choice_buttons()[2].pressed.emit()
		await process_frame
	_check(app.stitched_roadblock_candle == 0 and _neutral(app),
		"authentic Leave remains free at zero")
	var trace := {"first": first_start, "first_rng": first_rng,
		"second": second_start, "second_rng": second_rng,
		"victory": victory, "repeat": repeats, "zero": zero_snapshot, "zero_rng": zero_rng,
		"final": app.stitched_roadblock_candle,
		"scraps": app.stitched_preview_scraps,
		"satchel": app.stitched_preview_satchel.duplicate(true)}
	app.free()
	await process_frame
	return trace

func _run() -> void:
	root.size = Vector2i(1280, 720)
	for candle in [92, 100, 4, 0, -1, 101, 4.5, "4", true, null]:
		await _circle_case(candle)
	await _circle_case(92, true)
	await _circle_case(92, false, true)
	var first := await _trace()
	var second := await _trace()
	_check(not first.is_empty() and first == second,
		"fresh app instances replay the same public title/roadblock/fight/Circle/candle trace")
	for failure in failures:
		printerr(failure)
	print("stitched_s6_candle_admission_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
