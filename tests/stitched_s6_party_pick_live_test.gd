extends SceneTree
## S6: title Roadblock selection, authenticated mounted fight, Circle and replay.
const ALT := ["button_golem", "rag_duelist", "yarn_ranger", "scarecrow"]
const DEFAULT := ["warden", "seamstress", "tinker", "lantern_monk"]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _fresh() -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	return app


func _neutral(app: Node) -> bool:
	return app.deck == null and app.run_map == null and app.run_rng == null \
		and app.session_gold == 0 and app.run_scraps == 0 and app.run_deck.is_empty()


func _toggle(app: Node, id: String, pressed: bool) -> void:
	var box: CheckBox = app._stitched_party_checkboxes.get(id)
	_check(is_instance_valid(box), "mounted checkbox exists for " + id)
	if is_instance_valid(box):
		box.button_pressed = pressed


func _offer(app: Node) -> LiveEventChoicePanel:
	app._open_stitched_fight() # Explicit Roadblock regression entry.
	await process_frame
	return app.stitched_event_panel


func _act_from_mounted_controls(stage: StitchedBattleScreen) -> bool:
	if stage.battle == null or stage.battle.current_side() != "hero" or stage.battle.is_over():
		return false
	var actor: Dictionary = stage.battle.get_unit(stage.battle.current_actor_id())
	var best_slot := ""
	var best_target := ""
	var score := -10000
	for slot in StitchedParts.SLOTS:
		if not stage._valid_part(actor, actor["parts"][slot]) or not stage.select_part(slot):
			continue
		var id: String = str(actor["parts"][slot]["id"])
		var skill := StitchedParts.ability_at_tier(stage.parts[id], int(actor["parts"][slot]["tier"]))
		for key in stage.legal_targets():
			var parts := str(key).split("_")
			if parts.size() != 2:
				continue
			var side := parts[0]
			var rank := int(parts[1])
			var weight := -20
			if side == "foe":
				weight = int(skill.get("dmg", [0, 0])[1]) * 4 \
					+ int(skill.get("dmg", [0, 0])[0])
				if rank == 1:
					weight += 3
				if skill.get("kind") == "debuff" and skill.get("effects", {}).has("exposed"):
					weight += 1
			elif skill.get("kind") == "heal" and side == "hero":
				var ally: Dictionary = stage._unit_at("hero", rank)
				var missing := int(ally.get("max_hp", 0)) - int(ally.get("hp", 0))
				if missing >= 8:
					weight = 38 + missing
			if weight > score:
				score = weight
				best_slot = slot
				best_target = str(key)
	if best_slot.is_empty():
		var before_pass := stage.receipts.size()
		stage._action_buttons["pass"].pressed.emit()
		return stage.receipts.size() > before_pass
	var part_button: Button = stage._part_buttons[best_slot]
	var target_button: Button = stage._target_buttons[best_target]
	if part_button.disabled:
		return false
	part_button.pressed.emit()
	if target_button.disabled or not stage._selected_part == best_slot:
		return false
	var before := stage.receipts.size()
	target_button.pressed.emit()
	return stage.receipts.size() > before \
		and stage.receipts[before].get("action") == "ability"


func _win(stage: StitchedBattleScreen) -> Dictionary:
	if stage == null or stage.battle == null:
		return {}
	var initial := stage.battle.state_snapshot()
	var acted := 0
	for turn in range(140):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		if not _act_from_mounted_controls(stage):
			break
		acted += 1
	return {"initial": initial, "acted": acted, "outcome": stage.battle.outcome(),
		"state": stage.battle.state_snapshot(), "rng": stage.battle.rng_state(),
		"receipts": stage.receipts.duplicate(true)}


func _exercise() -> Dictionary:
	var app := _fresh()
	await process_frame
	_check(not app._stitched_party_locked and _neutral(app) \
		and not app.stitched_fight_button.is_visible_in_tree()
		and app.stitched_fight_button.disabled and app.start_button.is_visible_in_tree(),
		"real title has a dormant Roadblock without ordinary run or wallet")
	var offer: LiveEventChoicePanel = await _offer(app)
	_check(offer != null and offer.has_open_event() and app.stitched_event_gate != null,
		"title mounts real Roadblock gate and authored offer")
	if offer == null:
		app.free()
		await process_frame
		return {}
	var gate: RunV3FightEventGate = app.stitched_event_gate
	var buttons := offer.get_choice_buttons()
	_check(buttons.size() == 3 and not buttons[0].disabled and buttons[1].disabled \
		and not buttons[2].disabled, "all three authentic buttons keep default admission")
	_check(app._stitched_party_checkboxes.size() == 8 \
		and offer.find_child("StitchedPartyPicker", true, false) != null \
		and is_instance_valid(app._stitched_party_confirm_button) \
		and is_instance_valid(app._stitched_party_cancel_button),
		"themed four-of-eight picker, Confirm and Cancel are mounted")
	for id in StitchedPartyAdmission.HERO_IDS:
		var box: CheckBox = app._stitched_party_checkboxes.get(id)
		_check(is_instance_valid(box) and box.focus_mode != Control.FOCUS_NONE \
			and box.button_pressed == (id in DEFAULT),
			"all eight choices are mouse/keyboard usable with default checkboxes: " + id)
	var initial: Dictionary = app._stitched_floor_config()
	var default_receipt := StitchedPartyAdmission.admit(DEFAULT)
	_check(default_receipt.get("ok") == true \
		and app._stitched_party_receipt == default_receipt \
		and initial.get("heroes", []).size() == 4 \
		and initial["heroes"][0]["id"] == default_receipt["hero_ids"][0],
		"default config is independently admitted with canonical ranks")
	seed(176601)
	var expected := randi()
	seed(176601)
	_toggle(app, "warden", false)
	_check(app._stitched_party_draft.size() == 3 and buttons[0].disabled,
		"three picks disable Fight without claiming the gate")
	buttons[0].pressed.emit()
	app._stitched_party_confirm_button.pressed.emit()
	_check(app._stitched_party_picks == DEFAULT and not gate.is_claimed() \
		and app.stitched_fight_view == null and _neutral(app),
		"incomplete selection and injected Fight/Confirm spend nothing")
	_toggle(app, "warden", true)
	_toggle(app, "rag_duelist", true)
	_check(app._stitched_party_draft.size() == 5 and buttons[0].disabled,
		"five picks disable Fight before authentication")
	buttons[0].pressed.emit()
	app._stitched_party_confirm_button.pressed.emit()
	app._stitched_picker_changed(true, "unknown", weakref(offer), gate, offer._generation)
	app._stitched_picker_changed(true, "warden", weakref(offer), gate, offer._generation)
	var fake := {"ok": true, "heroes": [{"id": "forged"}], "hero_ids": ["forged"]}
	_check(app._stitched_floor_config(fake).is_empty() \
		and app._stitched_party_picks == DEFAULT \
		and app.stitched_fight_view == null and not gate.is_claimed() \
		and _neutral(app), "five/unknown/duplicate/fake receipt do not mutate authority")
	_toggle(app, "rag_duelist", false)
	_toggle(app, "warden", false)
	app._stitched_party_cancel_button.pressed.emit()
	_check(app._stitched_party_draft == DEFAULT and app._stitched_party_picks == DEFAULT \
		and not buttons[0].disabled and _neutral(app) and not gate.is_claimed(),
		"Cancel restores the canonical default without spending or gate claim")
	# Leave an unconfirmed three-pick edit via the third ORIGINAL ticket.
	var stale_source: WeakRef = weakref(offer)
	var stale_gate := gate
	var stale_generation: int = offer._generation
	_toggle(app, "warden", false)
	buttons[2].pressed.emit()
	await process_frame
	_check(app.stitched_event_panel == null and app.stitched_event_gate == null \
		and app.title_view.is_visible_in_tree() and app._stitched_party_picks == DEFAULT \
		and app._stitched_gear_overrides.is_empty() and _neutral(app),
		"authentic Leave drops only unconfirmed choices; no wallet or gear changes")
	offer = await _offer(app)
	_check(offer != null and offer != stale_source.get_ref() \
		and app._stitched_party_picks == DEFAULT and app.stitched_fight_view == null,
		"new Roadblock opens default confirmed party after Leave")
	if offer == null:
		app.free()
		await process_frame
		return {}
	gate = app.stitched_event_gate
	buttons = offer.get_choice_buttons()
	app._stitched_picker_changed(true, "warden", stale_source, stale_gate, stale_generation)
	app._stitched_picker_confirm(stale_source, stale_gate, stale_generation)
	app._stitched_picker_cancel(stale_source, stale_gate, stale_generation)
	_check(app._stitched_party_draft == DEFAULT and not gate.is_claimed() \
		and app._stitched_party_hint.text.contains("RANKS"),
		"old checkboxes and callbacks cannot change fresh picker or gate")
	for id in DEFAULT:
		_toggle(app, id, false)
	for id in ALT:
		_toggle(app, id, true)
	_check(app._stitched_party_draft == ALT and buttons[0].disabled \
		and not app._stitched_party_confirm_button.disabled,
		"edited valid four require Confirm before Fight")
	var wanted := StitchedPartyAdmission.admit(ALT)
	_check(wanted.get("ok") == true and wanted["hero_ids"].size() == 4 \
		and wanted["hero_ids"] != default_receipt["hero_ids"],
		"alternate selection resolves canonical collision ranks")
	app._stitched_party_confirm_button.pressed.emit()
	_check(app._stitched_party_picks == ALT and app._stitched_party_receipt == wanted \
		and not buttons[0].disabled and not gate.is_claimed(),
		"Confirm stores only the canonical detached receipt")
	var forged_offer := {"ok": true, "event_id": "v3_stitchline_roadblock",
		"choice_id": "break_barricade", "wallet": {"gold": 0, "scraps": 0},
		"fight_request": {"node_type": "Boss"}}
	app._commit_stitched_roadblock(forged_offer, weakref(offer), gate)
	_check(app.stitched_fight_view == null and not gate.is_claimed() \
		and app._stitched_floor_config(forged_offer).is_empty(),
		"forged battle receipt cannot bypass panel or roster authentication")
	buttons[0].pressed.emit()
	var stage: StitchedBattleScreen = app.stitched_fight_view
	_check(stage != null and gate.is_claimed() and app.stitched_event_panel == null,
		"real Fight choice claims once and mounts Stitched combat")
	if stage == null:
		app.free()
		await process_frame
		return {}
	var hero_list := stage.battle.get_heroes()
	_check(hero_list.size() == 4 and stage.battle.get_foes().size() == 3 \
		and stage.battle.current_side() == "hero" and _neutral(app),
		"alternate live 4v3 seeded combat exists without ordinary run resources")
	var equipped := true
	for index in range(mini(4, hero_list.size())):
		var expected_hero: Dictionary = wanted["heroes"][index]
		var unit: Dictionary = hero_list[index]
		equipped = equipped and unit.get("id") == expected_hero["id"] \
			and unit.get("rank") == index + 1 \
			and unit.get("base_max_hp") == expected_hero["max_hp"] \
			and unit.get("parts", {}).size() == 4
		for slot in StitchedParts.SLOTS:
			var worn: Dictionary = unit.get("parts", {}).get(slot, {})
			var definition: Dictionary = stage.parts.get(str(worn.get("id", "")), {})
			equipped = equipped and worn.get("tier") == 1 and worn.get("torn") == false \
				and definition.get("owner") == unit["id"] \
				and definition.get("slot") == slot \
				and not StitchedParts.ability_at_tier(definition, 1).is_empty()
	_check(equipped, "all alternate heroes wear distinct owned tier-I authored four-slot kits")
	var before_duplicate := stage.battle.state_snapshot()
	var rng_duplicate := stage.battle.rng_state()
	buttons[0].pressed.emit()
	app._stitched_picker_confirm(weakref(offer), gate, offer._generation)
	app._stitched_picker_cancel(weakref(offer), gate, offer._generation)
	_check(stage.battle.state_snapshot() == before_duplicate \
		and stage.battle.rng_state() == rng_duplicate \
		and app.stitched_fight_view == stage and randi() == expected \
		and _neutral(app), "stale callbacks and double-click leave battle/RNG/wallet intact")
	var win := _win(stage)
	_check(win.get("outcome") == "victory" and win.get("acted", 0) > 0 \
		and win.get("receipts", []).size() > 0,
		"mounted part buttons and targets win the actual Roadblock: " + str(win.get("outcome")))
	if win.get("outcome") != "victory":
		stage._action_buttons["exit"].pressed.emit()
		await process_frame
		app.free()
		await process_frame
		return win
	var earned_hp: Dictionary = {}
	var earned_ranks: Dictionary = {}
	var earned_fray: Dictionary = {}
	var earned_bleed: Dictionary = {}
	var wounded := 0
	for hero in stage.battle.get_heroes():
		var id := str(hero["id"])
		earned_hp[id] = int(hero["hp"])
		earned_ranks[id] = int(hero["rank"])
		earned_fray[id] = {"fray": hero["fray"], "resolve": hero["resolve"]}
		var bleed: Variant = hero.get("statuses", {}).get("bleed", 0)
		if typeof(bleed) == TYPE_INT and int(bleed) > 0:
			earned_bleed[id] = bleed
		if int(hero["hp"]) < int(hero["max_hp"]):
			wounded += 1
	_check(earned_hp.size() == 4 and earned_ranks.size() == 4 and wounded > 0 \
		and not app._stitched_party_locked,
		"real battle has four earned survivors including wounded HP; no pre-Leave lock")
	stage._action_buttons["exit"].pressed.emit()
	var circle: Control = app.stitched_sewing_panel
	_check(circle != null and app.stitched_sewing_visit != null \
		and app.stitched_preview_scraps == 1 and _neutral(app),
		"true victory retires battle and enters authentic Sewing Circle with earned scrap")
	if circle == null:
		app.free()
		await process_frame
		return win
	var quote: Dictionary = app.stitched_sewing_visit.quote()
	var circle_ids: Array = []
	for hero_row in quote.get("heroes", []):
		circle_ids.append(hero_row["hero_id"])
	_check(quote.get("ok") == true and circle_ids.size() == 4 \
		and quote.get("satchel_count") == 3 \
		and circle_ids.has("rag_duelist") and circle_ids.has("button_golem") \
		and circle_ids.has("yarn_ranger") and circle_ids.has("scarecrow"),
		"Circle receives the same four alternate survivors and authentic trophies")
	var swaps := circle.find_children("Swap_*", "Button", true, false)
	var swapped_id := ""
	var swapped_arm := ""
	if not swaps.is_empty():
		var swap: Button = swaps[0]
		swapped_id = str(swap.name).trim_prefix("Swap_").rsplit("_", true, 1)[0]
		swap.pressed.emit()
		swapped_arm = str(app._stitched_gear_overrides.get(swapped_id, {}).get("arms", {}).get("id", ""))
	_check(not swapped_id.is_empty() and not swapped_arm.is_empty(),
		"mounted Circle swap commits real named trophy to a chosen hero")
	var leave: Button = circle.find_child("SewingLeave", true, false)
	_check(is_instance_valid(leave) and leave.focus_mode != Control.FOCUS_NONE \
		and not app._stitched_party_locked,
		"real Circle Leave is keyboard focusable and lock is absent until success")
	if leave != null:
		leave.pressed.emit()
	await process_frame
	var carry: Dictionary = {"hp": app._stitched_hp_carry.duplicate(true),
		"ranks": app._stitched_rank_carry.duplicate(true),
		"fray": app._stitched_fray_carry.duplicate(true),
		"bleed": app._stitched_bleed_carry.duplicate(true),
		"gear": app._stitched_gear_overrides.duplicate(true),
		"satchel": app.stitched_preview_satchel.duplicate(true),
		"scraps": app.stitched_preview_scraps,
		"gold": app.stitched_preview_gold,
		"candle": app.stitched_roadblock_candle,
		"stop": app._stitched_postvictory_stop_available}
	_check(app.stitched_sewing_panel == null and app.title_view.is_visible_in_tree() \
		and app._stitched_party_locked and app._stitched_party_picks == ALT \
		and carry["hp"] == earned_hp and carry["ranks"] == earned_ranks \
		and carry["fray"] == earned_fray and carry["bleed"] == earned_bleed \
		and carry["stop"] == true and _neutral(app),
		"authentic Circle Leave alone locks the four earned IDs and canonical carry")
	var next_offer: LiveEventChoicePanel = await _offer(app)
	_check(next_offer != null and app._stitched_party_picks == ALT \
		and app._stitched_party_receipt == wanted,
		"fresh Roadblock retains selected party instead of resetting defaults")
	if next_offer != null:
		var read_only := next_offer.find_child("StitchedPartyPicker", true, false)
		var choices := next_offer.get_choice_buttons()
		var read_only_labels: Array = read_only.find_children("*", "Label", true, false) if read_only != null else []
		var labels_match := read_only_labels.size() == 5
		for hero in wanted["heroes"]:
			var found := false
			for display in read_only_labels:
				if display.text == "%d  %s" % [hero["rank"], hero["name"]]:
					found = true
			labels_match = labels_match and found
		_check(labels_match, "locked panel visibly names and seats all four earned survivors")
		_check(read_only != null and read_only.find_children("*", "CheckBox", true, false).is_empty() \
			and app._stitched_party_checkboxes.is_empty() \
			and not is_instance_valid(app._stitched_party_confirm_button) \
			and not is_instance_valid(app._stitched_party_cancel_button) \
			and choices.size() == 3 and not choices[0].disabled and not choices[2].disabled \
			and choices[0].focus_mode != Control.FOCUS_NONE \
			and choices[2].focus_mode != Control.FOCUS_NONE,
			"mounted locked roster shows survivors without editable controls; real Fight/Leave stay focusable")
		var lock_source: WeakRef = weakref(next_offer)
		var lock_gate: RunV3FightEventGate = app.stitched_event_gate
		var lock_generation: int = next_offer._generation
		seed(176602)
		var expected_forged_rng := randi()
		seed(176602)
		app._stitched_picker_changed(false, ALT[0], lock_source, lock_gate, lock_generation)
		app._stitched_picker_changed(true, DEFAULT[0], lock_source, lock_gate, lock_generation)
		app._stitched_picker_confirm(lock_source, lock_gate, lock_generation)
		app._stitched_picker_cancel(lock_source, lock_gate, lock_generation)
		app._stitched_picker_changed(false, ALT[0], stale_source, stale_gate, stale_generation)
		app._stitched_picker_confirm(stale_source, stale_gate, stale_generation)
		app._stitched_picker_cancel(stale_source, stale_gate, stale_generation)
		_check(app._stitched_party_picks == ALT and app._stitched_party_draft == ALT \
			and app._stitched_party_receipt == wanted and not lock_gate.is_claimed() \
			and app._stitched_hp_carry == carry["hp"] \
			and app._stitched_rank_carry == carry["ranks"] \
			and app._stitched_fray_carry == carry["fray"] \
			and app._stitched_bleed_carry == carry["bleed"] \
			and app._stitched_gear_overrides == carry["gear"] \
			and app.stitched_preview_satchel == carry["satchel"] \
			and app.stitched_preview_scraps == carry["scraps"] \
			and app.stitched_preview_gold == carry["gold"] \
			and app.stitched_roadblock_candle == carry["candle"] \
			and app._stitched_postvictory_stop_available == carry["stop"] \
			and randi() == expected_forged_rng and _neutral(app),
			"forged current/stale picker signals cannot reseat party, consume RNG or change earned resources/stop")
		choices[0].pressed.emit()
	var next_stage: StitchedBattleScreen = app.stitched_fight_view
	_check(next_stage != null and next_stage.battle != null \
		and next_stage.battle.get_heroes().size() == 4,
		"fresh authentic Fight remounts chosen four")
	var next_initial: Dictionary = {}
	if next_stage != null:
		next_initial = next_stage.battle.state_snapshot()
		var next_unit := next_stage.battle.get_unit(swapped_id)
		var mounted_hp: Dictionary = {}
		var mounted_ranks: Dictionary = {}
		var mounted_fray: Dictionary = {}
		var mounted_bleed: Dictionary = {}
		for hero in next_stage.battle.get_heroes():
			var id := str(hero["id"])
			mounted_hp[id] = int(hero["hp"])
			mounted_ranks[id] = int(hero["rank"])
			mounted_fray[id] = {"fray": hero["fray"], "resolve": hero["resolve"]}
			var bleed: Variant = hero.get("statuses", {}).get("bleed", 0)
			if typeof(bleed) == TYPE_INT and int(bleed) > 0:
				mounted_bleed[id] = bleed
		_check(mounted_hp == earned_hp and mounted_ranks == earned_ranks \
			and mounted_fray == earned_fray and mounted_bleed == earned_bleed \
			and next_stage.config.get("candle") == maxi(0, int(carry["candle"]) - app.STITCHED_ROADBLOCK_CANDLE_COST) \
			and app.stitched_roadblock_candle == next_stage.config.get("candle") \
			and next_unit.get("parts", {}).get("arms", {}).get("id") == swapped_arm \
			and next_unit.get("rank") == earned_ranks.get(swapped_id) \
			and next_stage.battle.get_heroes().size() == 4,
			"new real Fight preserves all earned IDs, wounds, FRAY, Bleed, ranks, gear and debits only normal candle")
		next_stage._action_buttons["exit"].pressed.emit()
	await process_frame
	var trace := {"first": win, "circle_heroes": circle_ids,
		"swapped_id": swapped_id, "swapped_arm": swapped_arm,
		"next": next_initial, "party": app._stitched_party_receipt.duplicate(true)}
	app.free()
	await process_frame
	return trace


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var first: Dictionary = await _exercise()
	var second: Dictionary = await _exercise()
	_check(not first.is_empty() and first == second \
		and first.get("first", {}).get("outcome") == "victory",
		"two independently mounted alternate teams replay battle, Circle, gear and next Fight")
	for failure in failures:
		printerr(failure)
	print("stitched_s6_party_pick_live_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
