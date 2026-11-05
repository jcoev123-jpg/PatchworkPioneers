extends SceneTree
## Mounted seeded Stitched battle: four worn parts, tier truth, locked help, no UI rolls.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _view_state(stage: StitchedBattleScreen) -> Dictionary:
	return {"battle": stage.battle.state_snapshot(), "rng": stage.battle.rng_state(),
		"receipts": stage.receipts.size(), "actor": stage.battle.current_actor_id(),
		"selected": stage._selected_part, "targets": stage.legal_targets()}


func _actor_turn(stage: StitchedBattleScreen, id: String) -> bool:
	var index := stage.battle._order.find(id)
	if index < 0:
		return false
	stage.battle._turn_index = index
	stage._refresh()
	return stage.battle.current_actor_id() == id


func _assert_digest(stage: StitchedBattleScreen, slot: String, label: String) -> void:
	var before := _view_state(stage)
	var actor := stage.battle.get_unit(stage.battle.current_actor_id())
	var worn: Dictionary = actor.get("parts", {}).get(slot, {})
	var cue: Dictionary = stage._part_cues[slot]
	var digest := str(cue["digest"])
	var preview: Label = stage._labels["preview"]
	var usable := stage._valid_part(actor, worn)
	_check(bool(cue["usable"]) == usable and digest.ends_with("READY" if usable else "LOCKED"),
		label + ": digest truthfully exposes action status")
	if not usable:
		_check(str(cue["full"]).contains(stage._part_lock_reason(actor, worn)),
			label + ": full help retains the exact blocked reason")
	if stage.parts.has(str(worn.get("id", ""))):
		var ability := StitchedParts.ability_at_tier(stage.parts[str(worn["id"])], int(worn["tier"]))
		_check(digest.begins_with(str(ability["name"]) + " " +
			str(StitchedPartActionCues.ROMAN[int(worn["tier"])])) and
			digest.contains("LAUNCH R" + ",".join(ability["launch"].map(func(r): return str(r)))) and
			digest.contains(str(ability["target_side"]).to_upper() + " R" +
				",".join(ability["target"].map(func(r): return str(r)))),
			label + ": current-tier identity and exact launch/target envelope")
		if int(ability["dmg"][1]) > 0:
			_check(digest.contains("DMG %d–%d" % [int(ability["dmg"][0]), int(ability["dmg"][1])]),
				label + ": actual tier damage range")
		for effect in ability["effects"]:
			_check(digest.contains("%s %d" % [str(effect).to_upper(), int(ability["effects"][effect])]),
				label + ": actual tier effect " + str(effect))
		if int(ability["self_move"]) != 0:
			_check(digest.contains("STEP FRONT" if int(ability["self_move"]) < 0 else "STEP BACK"),
				label + ": mandatory movement disclosed")
		if int(ability["mark_damage"]) > 0:
			_check(digest.contains("MARK DMG +%d" % int(ability["mark_damage"])),
				label + ": marked-target damage disclosed")
		_check(digest.contains(" ALL ·") == bool(ability["multi"]), label + ": multi-target scope")
	else:
		_check(digest == ("Unfilled" if str(worn.get("id", "")).is_empty() else "Unknown worn part") +
			" · LOCKED", label + ": missing slot contains no borrowed ability facts")
	stage._part_help_buttons[slot].mouse_entered.emit()
	await process_frame
	var font := preview.get_theme_font("font")
	var font_size := preview.get_theme_font_size("font_size")
	_check(preview.is_visible_in_tree() and preview.size == Vector2(749, 26) and font != null and font_size > 0,
		label + ": actual mounted preview geometry and font exist")
	_check(preview.text == digest and not digest.contains("\n") and not digest.contains("\r") and
		font.get_string_size(digest, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= preview.size.x and
		preview.get_line_count() == 1 and font.get_height(font_size) <= preview.size.y,
		label + ": complete digest fits one measured line in the live preview: " + digest)
	_check(stage._part_disclosure.visible and stage._part_disclosure_text.text == cue["full"] and
		preview.tooltip_text == cue["full"] and not stage._part_help_buttons[slot].disabled,
		label + ": pointer help and preview tooltip retain full disclosure")
	stage._part_help_buttons[slot].mouse_exited.emit()
	_check(_view_state(stage) == before, label + ": inspection preserves seeded state, RNG, receipts and selection")


func _assert_cues(stage: StitchedBattleScreen, label: String) -> void:
	var actor := stage.battle.get_unit(stage.battle.current_actor_id())
	_check(not actor.is_empty() and actor.get("side") == "hero", label + ": active hero exists")
	if actor.is_empty():
		return
	for slot in StitchedBattleScreen.SLOTS:
		var worn: Dictionary = actor["parts"].get(slot, {})
		var id := str(worn.get("id", ""))
		_check(not id.is_empty() and stage.parts.has(id), label + ": valid equipped " + slot)
		if not stage.parts.has(id):
			continue
		var part: Dictionary = stage.parts[id]
		var tier := int(worn["tier"])
		var ability := StitchedParts.ability_at_tier(part, tier)
		var stat := StitchedParts.stat_at_tier(part, tier)
		var cue: Dictionary = stage._part_cues[slot]
		var full := str(cue["full"])
		var title := str(stage._part_buttons[slot].text)
		_check(title == cue["title"] and title.contains(slot.to_upper()) and
			title.contains(str(part["name"])) and
			title.contains(str(StitchedPartActionCues.ROMAN[tier])),
			label + ": actual slot, full part name and roman stitch tier in " + slot)
		_check(full.contains("ID: " + id) and full.contains(str(ability["name"])) and
			full.contains(str(ability["kind"])) and
			full.contains(str(part["text"])) and
			full.contains("Launch ranks:") and full.contains("Target: " + str(ability["target_side"])) and
			full.contains("Multi:") and full.contains("ACC: %d" % int(ability["acc"])) and
			full.contains("Damage: %d–%d" % [int(ability["dmg"][0]), int(ability["dmg"][1])]) and
			full.contains("Crit bonus: +%d" % int(ability["crit"])) and
			full.contains("Effects:") and full.contains("Self-move:") and full.contains("Pose:"),
			label + ": real tier-adjusted full ability disclosure in " + slot)
		for key in stat:
			_check(full.contains("%s %+d" % [str(key).to_upper(), int(stat[key])]),
				label + ": tier-adjusted " + str(key) + " displayed in " + slot)
		_check(stage._part_help_buttons.has(slot) and
			stage._part_help_buttons[slot].focus_mode == Control.FOCUS_ALL and
			not stage._part_help_buttons[slot].disabled and
			stage._part_help_buttons[slot].tooltip_text.contains(full),
			label + ": independently focusable full help in " + slot)
		await _assert_digest(stage, slot, label + " " + slot)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var cfg := StitchedBattleScreen.read_preview()
	_check(cfg.get("heroes", []).size() == 4 and cfg.get("foes", []).size() == 3,
		"precondition: shipped fixed-seed preview supplies real 4v3")
	var catalog := StitchedParts.build_catalog(cfg.get("parts", []))
	_check(bool(catalog.get("ok", false)) and catalog.get("by_id", {}).has("any_arm_red_thread") and
		catalog.get("by_id", {}).has("warden_head_button_eye"),
		"precondition: validated shipped catalog contains foreign and Warden parts")
	var stage := StitchedBattleScreen.new()
	_check(stage.begin(cfg), "real battle screen accepts shipped preview")
	if stage.battle == null:
		_finish()
		return
	root.add_child(stage)
	await process_frame
	_check(stage._part_buttons.size() == 4 and stage._part_help_buttons.size() == 4 and
		stage._part_disclosure != null and stage.battle.current_side() == "hero" and
		stage.receipts.is_empty(), "live mounted screen has four action/help pairs and initial hero turn")
	await _assert_cues(stage, "initial")

	var quiet := _view_state(stage)
	stage._part_help_buttons["head"].mouse_entered.emit()
	_check(stage._part_disclosure.visible and
		stage._part_disclosure_text.text == stage._part_cues["head"]["full"] and
		stage._labels["preview"].text == stage._part_cues["head"]["digest"],
		"hover independently opens the full sewn readout and digest")
	stage._part_help_buttons["head"].mouse_exited.emit()
	_check(not stage._part_disclosure.visible, "leaving help clears only the disclosure")
	stage._part_help_buttons["head"].grab_focus()
	await process_frame
	_check(stage._part_help_buttons["head"].has_focus() and stage._part_disclosure.visible,
		"keyboard focus exposes identical full disclosure")
	stage._part_help_buttons["head"].pressed.emit()
	_check(stage._part_help_dialog.dialog_text == stage._part_cues["head"]["full"],
		"activate help shows full accessible text, not a combat action")
	stage._part_help_dialog.hide()
	stage._action_buttons["pass"].grab_focus()
	stage._refresh()
	_check(_view_state(stage) == quiet, "hover, keyboard help, dialog and refresh are entirely read-only")

	var initial_units := stage.battle._units.duplicate(true)
	var initial_turn := stage.battle._turn_index
	var initial_outcome := stage.battle._outcome
	_check(_actor_turn(stage, "tinker"), "precondition: Tinker appears in seeded initiative")
	var tinker := stage.battle.get_unit("tinker")
	_check(tinker["parts"]["head"]["id"] == "warden_head_button_eye" and
		stage._part_cues["head"]["part_id"] == "warden_head_button_eye" and
		stage._part_cues["head"]["title"].contains(str(stage.parts["warden_head_button_eye"]["name"])) and
		str(stage.parts["warden_head_button_eye"]["owner"]) == "warden",
		"foreign Warden part stays equipped and described on Tinker, without owner substitution")
	await _assert_cues(stage, "foreign parts on Tinker")
	var replaced_head: Dictionary = stage.battle._units["tinker"]["parts"]["head"]
	var old_head_id := str(replaced_head["id"])
	replaced_head["id"] = "any_head_needle_pin"
	stage._refresh()
	_check(stage._part_cues["head"]["part_id"] == "any_head_needle_pin" and
		str(stage._part_cues["head"]["title"]).contains("Needle Pin") and
		not str(stage._part_cues["head"]["full"]).contains("Button Eye"),
		"live equipment replacement refreshes the actual current part, not a cached owner's part")
	await _assert_digest(stage, "head", "replaced head")
	replaced_head["id"] = old_head_id
	stage._refresh()
	var old_arms: Dictionary = stage.battle._units["tinker"]["parts"]["arms"]
	stage.battle._units["tinker"]["parts"]["arms"] = {}
	stage._refresh()
	_check(stage._part_buttons["arms"].disabled and not stage._part_help_buttons["arms"].disabled and
		str(stage._part_cues["arms"]["title"]).contains("Unfilled") and
		not str(stage._part_cues["arms"]["full"]).contains("Brace") and
		not stage.select_part("arms"), "unfilled slot is truthful, inspectable and unselectable")
	await _assert_digest(stage, "arms", "unfilled")
	stage.battle._units["tinker"]["parts"]["arms"] = {"id": "nonexistent_part", "tier": 1, "torn": false}
	stage._refresh()
	_check(stage._part_buttons["arms"].disabled and
		str(stage._part_cues["arms"]["title"]).contains("Unknown worn part") and
		not str(stage._part_cues["arms"]["full"]).contains("Brace"),
		"unknown equipped part never borrows an existing part's details")
	await _assert_digest(stage, "arms", "unknown")
	stage.battle._units["tinker"]["parts"]["arms"] = old_arms
	stage._refresh()
	_check(_actor_turn(stage, "seamstress") and
		stage._part_cues["arms"]["part_id"] == "any_arm_red_thread" and
		str(stage._part_cues["arms"]["full"]).contains("Red Thread"),
		"Seamstress exposes her actual foreign-capable red thread")
	await _assert_cues(stage, "Seamstress")

	_check(_actor_turn(stage, "warden"), "precondition: Warden appears in seeded initiative")
	await _assert_cues(stage, "Warden tier I")
	var worn: Dictionary = stage.battle._units["warden"]["parts"]["torso"]
	var previous := str(stage._part_cues["torso"]["full"])
	var base := StitchedParts.ability_at_tier(stage.parts[str(worn["id"])], 1)
	for tier in [2, 3]:
		worn["tier"] = tier
		stage._refresh()
		await _assert_cues(stage, "Warden tier " + str(tier))
		var tier_ability := StitchedParts.ability_at_tier(stage.parts[str(worn["id"])], tier)
		var tier_stat := StitchedParts.stat_at_tier(stage.parts[str(worn["id"])], tier)
		_check(tier_ability["effects"] != base["effects"] and
			str(stage._part_cues["torso"]["full"]) != previous and
			str(stage._part_cues["torso"]["full"]).contains("MAX_HP %+d" % int(tier_stat["max_hp"])),
			"tier " + str(tier) + " changes visible thorns and max-HP stat from actual overrides")
		previous = str(stage._part_cues["torso"]["full"])
	worn["tier"] = 1
	stage._refresh()

	var helm: Dictionary = stage.battle._units["warden"]["parts"]["head"]
	var legal_helm := stage._valid_part(stage.battle.get_unit("warden"), helm)
	_check(legal_helm, "precondition: Warden Iron Helm has a genuine legal rank/target")
	if legal_helm:
		_check(stage.select_part("head") and not stage.legal_targets().is_empty(),
			"precondition: a legal Warden part selects lit targets")
	helm["torn"] = true
	stage._refresh()
	var torn_quiet := _view_state(stage)
	_check(stage._part_buttons["head"].disabled and not stage._part_help_buttons["head"].disabled and
		stage._selected_part.is_empty() and stage.legal_targets().is_empty() and
		str(stage._part_cues["head"]["full"]).contains("TORN") and
		str(stage._part_cues["head"]["full"]).contains("Sewing Circle") and
		not stage.select_part("head") and
		not bool(stage.submit_part(str(helm["id"]), 1).get("ok", false)),
		"torn worn part is refused, deselected and still has separately accessible truthful help")
	await _assert_digest(stage, "head", "torn")
	stage._part_help_buttons["head"].grab_focus()
	await process_frame
	_check(stage._part_disclosure.visible and
		stage._part_disclosure_text.text.contains("TORN"),
		"keyboard help for a disabled torn ability remains mounted")
	stage._action_buttons["pass"].grab_focus()
	_check(_view_state(stage) == torn_quiet,
		"torn refusal, focus and inspection spend no turns, receipts or RNG")
	helm["torn"] = false

	stage.battle._units["warden"]["rank"] = 4
	stage._refresh()
	var wrong_quiet := _view_state(stage)
	_check(stage._part_buttons["head"].disabled and not stage._part_help_buttons["head"].disabled and
		str(stage._part_cues["head"]["full"]).contains("Wrong launch rank") and
		not stage.select_part("head") and not bool(stage.submit_part(str(helm["id"]), 1).get("ok", false)),
		"incorrect launch rank shows the real gate and refuses action")
	await _assert_digest(stage, "head", "wrong rank")
	_check(_view_state(stage) == wrong_quiet, "wrong-rank refusal preserves snapshot and RNG")

	stage.battle._units["warden"]["rank"] = 1
	for foe in stage.battle.get_foes():
		var enemy: Dictionary = stage.battle._units[str(foe["id"])]
		enemy["dead"] = true
		enemy["hp"] = 0
	stage._refresh()
	var no_target_quiet := _view_state(stage)
	_check(stage._part_buttons["head"].disabled and
		str(stage._part_cues["head"]["full"]).contains("No legal target") and
		not stage.select_part("head") and not bool(stage.submit_part(str(helm["id"]), 1).get("ok", false)),
		"actual rules target gate refuses an ability with no living legal foe")
	await _assert_digest(stage, "head", "no target")
	_check(_view_state(stage) == no_target_quiet, "no-target refusal is pure")

	stage.battle._units = initial_units.duplicate(true)
	_check(_actor_turn(stage, "tinker"), "restore: Tinker turn reachable")
	stage.battle._units["tinker"]["rank"] = 4 # Stride launches from 1 or 4
	stage.battle._units["tinker"]["statuses"]["tangled"] = 1
	stage._refresh()
	var step_ability := StitchedParts.ability_at_tier(stage.parts["warden_legs_stride"], 1)
	_check(int(step_ability["self_move"]) == -1 and
		stage._part_buttons["legs"].disabled and not stage._part_help_buttons["legs"].disabled and
		str(stage._part_cues["legs"]["full"]).contains("Movement/thread lock") and
		not stage.select_part("legs"), "mandatory move uses rules gate, exposes movement/thread lock")
	await _assert_digest(stage, "legs", "movement lock")
	stage.battle._units = initial_units.duplicate(true)
	for hero_id in ["warden", "seamstress", "tinker", "lantern_monk"]:
		_check(_actor_turn(stage, hero_id), "tier matrix: seeded hero turn exists for " + hero_id)
		for tier in [1, 2, 3]:
			for slot in StitchedBattleScreen.SLOTS:
				stage.battle._units[hero_id]["parts"][slot]["tier"] = tier
			stage._refresh()
			var matrix_quiet := _view_state(stage)
			await _assert_cues(stage, hero_id + " all parts tier " + str(tier))
			stage._refresh()
			_check(_view_state(stage) == matrix_quiet, "tier matrix: refresh and all reads preserve state/RNG/receipts")
	stage.battle._units = initial_units.duplicate(true)
	stage.battle._turn_index = initial_turn
	stage._refresh()
	_check(stage._part_cues["head"]["part_id"] ==
		str(stage.battle.get_unit(stage.battle.current_actor_id())["parts"]["head"]["id"]),
		"actor change returns details to the authoritative acting hero, not a previous owner")

	stage.battle._outcome = "victory"
	stage._refresh()
	_check(stage._selected_part.is_empty() and stage.legal_targets().is_empty() and
		not stage._part_disclosure.visible and stage._part_help_buttons["head"].disabled and
		not str(stage._part_buttons["head"].text).contains("Iron Helm") and
		str(stage._part_cues["head"]["title"]).contains("Unfilled"),
		"combat ending removes stale hero facts, targeting and inspection")
	stage.battle._outcome = initial_outcome
	stage._refresh()

	var actor_id := stage.battle.current_actor_id()
	var hero := stage.battle.get_unit(actor_id)
	var committed := false
	for slot in StitchedBattleScreen.SLOTS:
		if not stage._valid_part(hero, hero["parts"][slot]):
			continue
		var ability := StitchedParts.ability_at_tier(stage.parts[str(hero["parts"][slot]["id"])],
			int(hero["parts"][slot]["tier"]))
		if str(ability["target_side"]) != "enemy":
			continue
		var before := stage.receipts.size()
		var button: Button = stage._part_buttons[slot]
		button.pressed.emit()
		if stage._selected_part != slot:
			continue
		for key in stage.legal_targets():
			var key_parts := str(key).split("_")
			if key_parts.size() != 2 or key_parts[0] != "foe":
				continue
			stage._target_buttons[key].mouse_entered.emit()
			_check(str(stage._labels["preview"].text).contains("HIT") and
				stage._labels["preview"].text == StitchedTargetForecast.for_rank(
					stage.battle, hero, ability, "foe", int(key_parts[1]))["text"],
				"lit target forecast beats help digest and uses existing exact forecast")
			stage._part_help_buttons[slot].mouse_entered.emit()
			_check(str(stage._labels["preview"].text).contains("HIT"),
				"hovering help never obscures active lit-target forecast")
			var before_state := _view_state(stage)
			stage._part_help_buttons[slot].mouse_exited.emit()
			_check(_view_state(stage) == before_state, "hover on selected ability leaves selection intact")
			stage._target_buttons[key].pressed.emit()
			_check(stage.receipts.size() > before and
				stage.receipts[before]["action"] == "ability" and
				stage.receipts[before]["actor"] == actor_id and
				stage.receipts[before]["part"] == hero["parts"][slot]["id"] and
				stage.receipts[before]["ability"] == ability["id"] and
				(stage.battle.current_actor_id() != actor_id or stage.battle.is_over()),
				"actual mounted action/target buttons commit one correct ability and advance rules turn")
			var matching_receipts := 0
			for receipt in stage.receipts.slice(before):
				if receipt.get("action") == "ability" and receipt.get("actor") == actor_id:
					matching_receipts += 1
			_check(matching_receipts == 1, "mounted legal action commits exactly one hero ability receipt")
			committed = true
			break
		if committed:
			break
	_check(committed, "precondition: the real battle has a legal enemy ability that commits")
	stage.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s6_battle_part_disclosure_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
