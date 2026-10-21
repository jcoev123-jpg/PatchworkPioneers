extends SceneTree
## Real sewn inventories, authoritative re_sew oracle and mounted input events.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _fixture(scraps: int = 4) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	_check(typeof(raw) == TYPE_ARRAY and raw.size() == 3, "real three-hero catalog")
	if typeof(raw) != TYPE_ARRAY or raw.size() != 3:
		return {}
	var combat_defs: Array = raw.duplicate(true)
	for record in combat_defs:
		record["max_hp"] = int(record["max_hp"])
	var party := CombatParty.new(combat_defs)
	_check(party.is_valid(), "real CombatParty from authored hero definitions")
	if not party.is_valid():
		return {}
	var heroes := party.get_heroes()
	var torn := RunTornMending.new(heroes)
	var definitions := []
	var known := {}
	for catalog in ["initial_patch_slots", "m04_attack_patches", "m04_coat_patches"]:
		var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/%s.json" % catalog))
		_check(typeof(entries) == TYPE_ARRAY, catalog + " authored JSON loaded")
		if typeof(entries) != TYPE_ARRAY:
			return {}
		for entry in entries:
			definitions.append({"id": entry["id"], "slot": entry["slot"]})
			known[entry["id"]] = entry["slot"]
	_check(known.get("button_eye") == "HEAD" and known.get("pincushion_arm") == "ARM"
		and known.get("quilted_coat") == "COAT" and known.get("stitched_badge") == "HEAD"
		and known.get("spare_spool") == "ARM", "all five authored slot identities present")
	var owned := ["button_eye", "pincushion_arm", "quilted_coat", "stitched_badge", "spare_spool"]
	var w := RunPatchWardrobe.new(heroes, owned, definitions, scraps, 37,
		["warden_strike"], 93811, true)
	_check(torn.is_valid() and w.is_valid(), "genuine ledger and torn services")
	if not torn.is_valid() or not w.is_valid():
		return {}
	for instruction in [["button_eye", "warden", "HEAD"],
			["pincushion_arm", "seamstress", "ARM"],
			["quilted_coat", "tinker", "COAT"],
			["stitched_badge", "seamstress", "HEAD"],
			["spare_spool", "tinker", "ARM"]]:
		var receipt := w.sew(instruction[0], instruction[1], instruction[2],
			"sew:" + instruction[0], w.get_snapshot())
		_check(receipt.ok and receipt.receipt.slot == instruction[2],
			"actual owned patch sewn: " + instruction[0])
	_check(w.start_rest("rest_real", w.get_snapshot()).ok, "exact open Rest")
	return {"w": w, "t": torn, "rest": "rest_real"}


func _option(f: Dictionary, patch: String, target: String) -> Dictionary:
	var state: Dictionary = f.w.get_snapshot()
	var model := RunRestPatchResewOptions.project(f.w, f.t, state, f.rest)
	_check(model.ok and model.scraps >= 1 and model.options.size() > 0,
		"real current Rest has legal options")
	if not model.ok:
		return {}
	for choice in model.options:
		if choice.patch_id == patch and choice.to_hero == target:
			return choice
	_check(false, "selected real option exists: " + patch + " to " + target)
	return {}


func _forecast_and_commit(f: Dictionary, patch: String, target: String, kind: String) -> void:
	var w: RunPatchWardrobe = f.w
	var t: RunTornMending = f.t
	var option := _option(f, patch, target)
	if option.is_empty():
		return
	var original := w.get_snapshot()
	var torn_before := t.read_state()
	var option_before := option.duplicate(true)
	var result := RunRestPatchResewOptions.forecast(w, t, original, f.rest, option)
	_check(result.get("ok") == true and result.get("kind") == kind
		and result.get("cost") == 1 and result.get("exchanged_id") == option.exchanged_id,
		"forecast is legal, correct MOVE/SWAP and exactly 1 scrap")
	if not result.get("ok"):
		return
	var source: String = option.from_hero
	var dest: String = option.to_hero
	var slot: String = option.slot
	_check(result.source.before.slots == _expected_slots(original.worn[source], torn_before.heroes, source)
		and result.destination.before.slots == _expected_slots(original.worn[dest], torn_before.heroes, dest),
		"both full original slot assignments/activity match actual ledger")
	var proposed: Dictionary = original.worn.duplicate(true)
	proposed[source][slot] = original.worn[dest][slot]
	proposed[dest][slot] = patch
	_check(result.source.after.slots == _expected_slots(proposed[source], torn_before.heroes, source)
		and result.destination.after.slots == _expected_slots(proposed[dest], torn_before.heroes, dest),
		"both full projected assignments, effects and active flags match")
	_check(w.get_snapshot() == original and t.read_state() == torn_before
		and option == option_before, "pure preview leaves ledger, torn and option untouched")
	var repeat := RunRestPatchResewOptions.forecast(w, t, original, f.rest, option)
	_check(result == repeat, "same exact snapshot gives identical detached result")
	result.source.after.slots[slot].id = "corruption"
	_check(RunRestPatchResewOptions.forecast(w, t, original, f.rest, option) == repeat,
		"nested output cannot alias source or subsequent forecast")
	var commit := w.re_sew(patch, source, dest, f.rest,
		"transfer:" + patch + ":" + dest, original)
	var after := w.get_snapshot()
	_check(commit.ok and commit.receipt.exchanged_id == option.exchanged_id
		and after.worn == proposed and after.scraps == original.scraps - 1
		and after.owned == original.owned and after.heroes == original.heroes
		and after.gold == original.gold and after.cards == original.cards
		and after.seed == original.seed, "independent real re_sew agrees; every other slot intact")
	_check(t.read_state() == torn_before and after.operation_ids.size() == original.operation_ids.size() + 1,
		"no HP/heal/torn/seed changes, exactly one new operation")


func _expected_slots(assignments: Dictionary, heroes: Array, owner: String) -> Dictionary:
	var hp := 0
	for hero in heroes:
		if hero.id == owner:
			hp = hero.hp
	var slots := {}
	for slot in ["HEAD", "ARM", "COAT"]:
		var id: String = assignments[slot]
		var effect := ""
		if id == "button_eye":
			effect = "first attack each combat: Exposed 1"
		elif id == "pincushion_arm":
			effect = "damage-dealing cards: +1 damage"
		elif id == "quilted_coat":
			effect = "+6 effective max HP (no heal)"
		slots[slot] = {"id": id, "active": id != "" and hp > 0, "effect": effect}
	return slots


func _pure_tests() -> void:
	_forecast_and_commit(_fixture(), "button_eye", "tinker", "MOVE")
	_forecast_and_commit(_fixture(), "button_eye", "seamstress", "SWAP")
	_forecast_and_commit(_fixture(), "pincushion_arm", "warden", "MOVE")
	_forecast_and_commit(_fixture(), "quilted_coat", "warden", "MOVE")
	var f := _fixture()
	var choice := _option(f, "quilted_coat", "warden")
	if choice.is_empty():
		return
	var forecast := RunRestPatchResewOptions.forecast(
		f.w, f.t, f.w.get_snapshot(), f.rest, choice)
	_check(forecast.ok and forecast.source.before.effective_max_hp == 32
		and forecast.source.after.effective_max_hp == 26
		and forecast.destination.before.effective_max_hp == 40
		and forecast.destination.after.effective_max_hp == 46
		and forecast.destination.after.hp == 40
		and forecast.destination.after.base_max_hp == 40,
		"+6 only at active coat wearer; no HP healing or max HP mutation")
	_check(forecast.source.before.slots.ARM.id == "spare_spool"
		and forecast.source.before.slots.ARM.effect == ""
		and forecast.destination.before.slots.HEAD.id == "button_eye",
		"unknown Shop ID has no invented rule and unrelated slots remain visible")


func _torn_test() -> void:
	var f := _fixture()
	var w: RunPatchWardrobe = f.w
	var t: RunTornMending = f.t
	var old: Array = t.read_state().heroes
	var ending: Array = old.duplicate(true)
	ending[0].hp = 0
	_check(t.observe_battle_end("combat_tear", old, ending).ok,
		"real battle observation tears Warden")
	var stale := w.get_snapshot()
	var choice := _option_unchecked(f, "button_eye", "tinker")
	_check(not RunRestPatchResewOptions.forecast(w, t, stale, f.rest, choice).ok,
		"stale wardrobe-to-torn context rejects after actual tear")
	_check(w.refresh_run_context(t.read_state().heroes, stale.owned,
		stale.scraps, stale.gold, stale.cards, stale), "owner refreshes torn roster")
	var option := _option(f, "button_eye", "tinker")
	if option.is_empty():
		return
	var next := RunRestPatchResewOptions.forecast(
		w, t, w.get_snapshot(), f.rest, option)
	_check(next.ok and next.source.before.hp == 0
		and next.source.before.base_max_hp == 37
		and next.source.before.slots.HEAD.id == "button_eye"
		and not next.source.before.slots.HEAD.active
		and not next.source.before.slots.HEAD.effect.is_empty()
		and next.source.after.hp == 0
		and next.destination.after.slots.HEAD.active,
		"torn source stays sewn, documented power dormant, living target activates")
	_check(next.source.before.slots.HEAD.effect == next.destination.after.slots.HEAD.effect,
		"same authored rule becomes active only at living destination")
	var coat := _option(f, "quilted_coat", "warden")
	var health := RunRestPatchResewOptions.forecast(
		w, t, w.get_snapshot(), f.rest, coat)
	_check(health.ok and health.destination.after.hp == 0
		and health.destination.after.effective_max_hp == 37
		and not health.destination.after.slots.COAT.active
		and health.destination.after.slots.COAT.effect.contains("+6"),
		"torn coat target has dormant +6, effective cap 37 not 43, no revival")


func _option_unchecked(f: Dictionary, patch: String, target: String) -> Dictionary:
	var state: Dictionary = f.w.get_snapshot()
	for id in state.worn:
		if state.worn[id].values().has(patch):
			var slot: String = state.definitions[patch]
			var exchanged: String = state.worn[target][slot]
			return {"patch_id": patch, "from_hero": id, "to_hero": target,
				"slot": slot, "kind": "MOVE" if exchanged == "" else "SWAP",
				"exchanged_id": exchanged, "cost": 1, "source_active": true,
				"destination_active": true, "exchanged_active": exchanged != ""}
	return {}


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(code: Key) -> void:
	for press in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.pressed = press
		root.push_input(key, true)
	await _frames()


func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await _frames()
	for press in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = press
		root.push_input(event, true)
	await _frames()


func _pick(button: OptionButton, index: int, keyboard: bool) -> void:
	if keyboard:
		button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(button)
	var popup := button.get_popup()
	_check(popup.visible and index < button.item_count, "physical selector popup opens")
	if not popup.visible or index >= button.item_count:
		return
	if keyboard:
		await _key(KEY_HOME)
		for i in range(index):
			await _key(KEY_DOWN)
		await _key(KEY_ENTER)
	else:
		var point := Vector2(popup.position) + Vector2(popup.size.x * 0.5,
			popup.size.y * (index + 0.5) / button.item_count)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, true)
		await _frames()
		for press in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = press
			root.push_input(event, true)
		await _frames()


func _ui_test(activation: Key) -> void:
	var f := _fixture()
	var w: RunPatchWardrobe = f.w
	var t: RunTornMending = f.t
	var original := w.get_snapshot()
	var torn_before := t.read_state()
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	var picker := LiveRestPatchResewPicker.new()
	root.add_child(picker)
	picker.size = Vector2(1280, 720)
	await _frames()
	_check(picker.present(w, t, original, f.rest), "existing live-mounted picker accepts exact Rest")
	await _frames()
	_check((picker.preview_label.text.contains("MOVE") or picker.preview_label.text.contains("SWAP"))
		and picker.preview_label.text.contains("BEFORE")
		and picker.preview_label.text.contains("AFTER")
		and picker.preview_label.text.contains("Cost: 1 scrap"),
		"initial mounted choice shows both original and proposed states")
	var screen := Rect2(0, 0, 1280, 720)
	for control in [picker.source_selector, picker.destination_selector,
			picker.confirm_button, picker.preview_label]:
		_check(control.is_visible_in_tree() and screen.encloses(control.get_global_rect()),
			"mounted selector, preview and action fit 1280x720")
	var calls := []
	picker.re_sew_requested.connect(func(p, source, dest, node, snap):
		calls.append([p, source, dest, node, snap]))
	var head_index := -1
	for i in range(picker._sources.size()):
		if picker._sources[i].patch_id == "button_eye":
			head_index = i
	_check(head_index >= 0, "authored Button Eye source is selectable")
	if head_index >= 0:
		await _pick(picker.source_selector, head_index, true)
		_check(picker.preview_label.text.contains("Warden BEFORE")
			and picker.preview_label.text.contains("Warden AFTER")
			and picker.preview_label.text.contains("Exposed 1"),
			"source keyboard selection updates both wearer forecasts")
		await _key(KEY_TAB)
		_check(picker.destination_selector.has_focus(), "Tab goes from source to destination")
		var move_index := -1
		for i in range(picker._destinations.size()):
			if picker._destinations[i].to_hero == "tinker":
				move_index = i
		_check(move_index >= 0, "empty same-slot target exists")
		if move_index >= 0:
			await _pick(picker.destination_selector, move_index, false)
			_check(picker.preview_label.text.contains("MOVE")
				and picker.preview_label.text.contains("empty destination")
				and picker.preview_label.text.contains("Tinker AFTER"),
				"physical mouse selection displays empty MOVE and its active recipient")
		var target_index := -1
		for i in range(picker._destinations.size()):
			if picker._destinations[i].to_hero == "seamstress":
				target_index = i
		_check(target_index >= 0, "occupied same-slot recipient reachable")
		if target_index >= 0:
			await _pick(picker.destination_selector, target_index, false)
			_check(picker.preview_label.text.contains("SWAP")
				and picker.preview_label.text.contains("stitched_badge")
				and picker.preview_label.text.contains("Exposed 1")
				and picker.preview_label.text.contains("Seamstress BEFORE")
				and picker.preview_label.text.contains("Warden AFTER")
				and not picker.confirm_button.disabled,
				"physical keyboard source and mouse destination refresh SWAP/effects")
			var chosen := picker.selected_option()
			_check(chosen.patch_id == "button_eye" and chosen.to_hero == "seamstress",
				"real selector selection binds exact option")
			picker.confirm_button.grab_focus()
			await _key(activation)
			_check(calls.size() == 1 and calls[0] == [
				"button_eye", "warden", "seamstress", f.rest, original],
				"physical Enter/Space confirms precisely once with exact detached receipt")
			_check(picker._pending and picker.confirm_button.disabled
				and picker.source_selector.disabled and picker.destination_selector.disabled,
				"pending latch closes all actionable controls")
			picker._request_selected()
			await _click(picker.confirm_button)
			_check(calls.size() == 1, "pending keyboard and mouse replays emit nothing")
	_check(w.get_snapshot() == original and t.read_state() == torn_before,
		"UI never directly mutates genuine services or spends")
	picker.free()
	await _frames()


func _deny_test() -> void:
	var f := _fixture()
	var w: RunPatchWardrobe = f.w
	var t: RunTornMending = f.t
	var exact := w.get_snapshot()
	var option := _option(f, "button_eye", "tinker")
	if option.is_empty():
		return
	var born := exact.duplicate(true)
	var torn_before := t.read_state()
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = 9181
	var rng_state := run_rng.state
	seed(234023)
	var expected_global := randi()
	seed(234023)
	for forged in [exact.duplicate(true), exact.duplicate(true)]:
		forged["scraps"] += 1
		_check(not RunRestPatchResewOptions.forecast(w, t, forged, f.rest, option).ok,
			"forged exact receipt rejected")
	_check(not RunRestPatchResewOptions.forecast(w, t, exact, "foreign_rest", option).ok,
		"foreign Rest node rejected")
	var altered := option.duplicate(true)
	altered["cost"] = 0
	_check(not RunRestPatchResewOptions.forecast(w, t, exact, f.rest, altered).ok,
		"forged option price rejected")
	var no_scrap := _fixture(0)
	_check(not RunRestPatchResewOptions.project(no_scrap.w, no_scrap.t,
		no_scrap.w.get_snapshot(), no_scrap.rest).ok
		and not RunRestPatchResewOptions.forecast(no_scrap.w, no_scrap.t,
			no_scrap.w.get_snapshot(), no_scrap.rest, _option_unchecked(no_scrap,
			"button_eye", "tinker")).ok, "zero-scrap Rest is not actionable")
	var picker := LiveRestPatchResewPicker.new()
	root.add_child(picker)
	picker.size = Vector2(1280, 720)
	await _frames()
	_check(picker.present(w, t, exact, f.rest), "denial fixture starts actionable")
	var calls := []
	picker.re_sew_requested.connect(func(_p, _s, _d, _n, _snap): calls.append("sent"))
	picker.hide()
	picker._request_selected()
	_check(calls.is_empty(), "hidden picker cannot request re-sew")
	picker.show()
	picker.confirm_button.disabled = true
	picker._request_selected()
	_check(calls.is_empty(), "disabled confirm cannot request re-sew")
	picker.confirm_button.disabled = false
	var stale := exact.duplicate(true)
	_check(w.re_sew(option.patch_id, option.from_hero, option.to_hero,
		f.rest, "legal_external", w.get_snapshot()).ok, "genuine external transfer creates stale picker")
	var moved := w.get_snapshot()
	picker._update_preview()
	picker._request_selected()
	_check(calls.is_empty() and picker.confirm_button.disabled
		and picker.preview_label.text == "No eligible re-sew choices",
		"stale picker loses actionable preview and cannot emit")
	_check(w.get_snapshot() == moved, "stale request does not spend again")
	picker.free()
	await _frames()
	_check(w.end_rest(f.rest, w.get_snapshot()).ok, "closing exact Rest")
	_check(not RunRestPatchResewOptions.forecast(w, t, w.get_snapshot(), f.rest, option).ok,
		"closed Rest refuses preview")
	_check(t.read_state() == torn_before and exact == born and run_rng.state == rng_state
		and randi() == expected_global, "rejections preserve torn, caller inputs and both RNGs")


func _run() -> void:
	_pure_tests()
	_torn_test()
	await _ui_test(KEY_SPACE)
	await _ui_test(KEY_ENTER)
	_deny_test()
	for failure in failures:
		printerr(failure)
	print("rest_resew_effect_preview_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
