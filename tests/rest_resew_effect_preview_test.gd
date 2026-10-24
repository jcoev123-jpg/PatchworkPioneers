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
	for catalog in ["initial_patch_slots", "m04_attack_patches", "m04_coat_patches",
			"m05_head_patches", "m05_arm_support_patches", "m05_attack_patches"]:
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
		and known.get("spare_spool") == "ARM" and known.get("bloodstitch_bonnet") == "HEAD"
		and known.get("frayfinder_mitt") == "ARM", "all required authored slot identities present")
	var owned := ["button_eye", "pincushion_arm", "quilted_coat", "stitched_badge", "spare_spool",
		"bloodstitch_bonnet", "button_glass_visor", "stern_seam_cap", "reinforced_browband",
		"hemguard_cuff", "red_bobbin_cuff", "loose_thread_glove", "frayfinder_mitt"]
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
	_check(result.source.before.hp == result.source.after.hp
		and result.destination.before.hp == result.destination.after.hp
		and result.source.before.base_max_hp == result.source.after.base_max_hp
		and result.destination.before.base_max_hp == result.destination.after.base_max_hp,
		"preview preserves HP and base maximum HP for both wearers")
	if slot != "COAT":
		_check(result.source.before.effective_max_hp == result.source.after.effective_max_hp
			and result.destination.before.effective_max_hp == result.destination.after.effective_max_hp,
			"HEAD/ARM preview preserves effective maximum HP for both wearers")
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


var _cached_coat_amounts := {}

func _load_coat_amounts() -> Dictionary:
	if not _cached_coat_amounts.is_empty():
		return _cached_coat_amounts
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_coat_patches.json"))
	_check(typeof(raw) == TYPE_ARRAY, "m04_coat_patches.json array loaded")
	if typeof(raw) == TYPE_ARRAY:
		for entry in raw:
			if entry is Dictionary and entry.has("id") and entry.has("max_hp_bonus"):
				_cached_coat_amounts[entry["id"]] = int(entry["max_hp_bonus"])
	return _cached_coat_amounts


func _expected_slots(assignments: Dictionary, heroes: Array, owner: String) -> Dictionary:
	var hp := 0
	for hero in heroes:
		if hero.id == owner:
			hp = hero.hp
	var coat_amounts := _load_coat_amounts()
	var slots := {}
	for slot in ["HEAD", "ARM", "COAT"]:
		var id: String = assignments[slot]
		var effect := ""
		if id == "button_eye":
			effect = "first attack each combat: Exposed 1"
		elif id == "pincushion_arm":
			effect = "damage-dealing cards: +1 damage"
		elif slot == "COAT" and coat_amounts.has(id):
			effect = "+%d effective max HP (no heal)" % coat_amounts[id]
		elif id == CombatShopPatchRules.STITCHED_BADGE_ID:
			effect = "+%d opening Block to living wearer (stacks with innate Block)" % CombatShopPatchRules.OPENING_BLOCK_BONUS
		elif id == CombatShopPatchRules.SPARE_SPOOL_ID:
			effect = "+%d healing on positive-heal cards owned by wearer only" % CombatShopPatchRules.HEALING_CARD_BONUS
		elif id != "":
			effect = RunPatchWearerSummary.KNOWN_TEXTS.get(id, "")
		slots[slot] = {"id": id, "active": id != "" and hp > 0, "effect": effect}
	return slots


func _pure_tests() -> void:
	_forecast_and_commit(_fixture(), "button_eye", "tinker", "MOVE")
	_forecast_and_commit(_fixture(), "button_eye", "seamstress", "SWAP")
	_forecast_and_commit(_fixture(), "pincushion_arm", "warden", "MOVE")
	_forecast_and_commit(_fixture(), "quilted_coat", "warden", "MOVE")
	_forecast_and_commit(_fixture(), "stitched_badge", "tinker", "MOVE")
	_forecast_and_commit(_fixture(), "stitched_badge", "warden", "SWAP")
	_forecast_and_commit(_fixture(), "spare_spool", "warden", "MOVE")
	_forecast_and_commit(_fixture(), "spare_spool", "seamstress", "SWAP")
	for head_patch in ["bloodstitch_bonnet", "button_glass_visor", "stern_seam_cap", "reinforced_browband"]:
		var fh := _fixture()
		fh.w.sew(head_patch, "tinker", "HEAD", "sew", fh.w.get_snapshot())
		_forecast_and_commit(fh, head_patch, "warden", "SWAP")
	for arm_patch in ["hemguard_cuff", "red_bobbin_cuff", "loose_thread_glove", "frayfinder_mitt"]:
		var fa := _fixture()
		fa.w.sew(arm_patch, "warden", "ARM", "sew", fa.w.get_snapshot())
		_forecast_and_commit(fa, arm_patch, "seamstress", "SWAP")
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
		and forecast.source.before.slots.ARM.effect.contains(
			str(CombatShopPatchRules.HEALING_CARD_BONUS))
		and forecast.source.before.slots.ARM.effect.contains("owned by wearer only")
		and forecast.destination.before.slots.HEAD.id == "button_eye",
		"Spare Spool accurately previews owned-heal bonus alongside other slots")


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


func _torn_shop_test() -> void:
	var f := _fixture()
	var w: RunPatchWardrobe = f.w
	var t: RunTornMending = f.t
	var original: Array = t.read_state().heroes
	var ending: Array = original.duplicate(true)
	ending[1].hp = 0
	ending[2].hp = 0
	_check(t.observe_battle_end("shop_torn", original, ending).ok,
		"real battle tears both Shop patch wearers")
	var stale := w.get_snapshot()
	_check(w.refresh_run_context(t.read_state().heroes, stale.owned,
		stale.scraps, stale.gold, stale.cards, stale), "Shop forecast uses exact torn context")
	for entry in [["stitched_badge", "warden", "HEAD", "seamstress"],
			["spare_spool", "warden", "ARM", "tinker"]]:
		var option := _option(f, entry[0], entry[1])
		_check(not option.is_empty(), "legal move from torn Shop wearer")
		if option.is_empty():
			continue
		var before := w.get_snapshot()
		var forecast := RunRestPatchResewOptions.forecast(w, t, before, f.rest, option)
		if not forecast.ok:
			_check(false, "torn Shop forecast remains available")
			continue
		var source_slot: Dictionary = forecast.source.before.slots[entry[2]]
		var destination_slot: Dictionary = forecast.destination.after.slots[entry[2]]
		_check(forecast.source.hero_id == entry[3]
			and forecast.destination.hero_id == "warden"
			and not source_slot.active and destination_slot.active
			and source_slot.effect == destination_slot.effect
			and source_slot.effect.contains(str(CombatShopPatchRules.EFFECTS[entry[0]]["amount"]))
			and forecast.source.before.hp == 0 and forecast.destination.after.hp == 40
			and w.get_snapshot() == before,
			"Shop effect described but dormant on torn wearer; active if moved")


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


func _pick(button: Button, keyboard: bool) -> void:
	_check(button.visible and not button.disabled and button.focus_mode == Control.FOCUS_ALL,
		"physical sewn button is visible and keyboard reachable")
	if keyboard:
		button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(button)
	_check(button.button_pressed, "physical sewn chip retains selected felt state")


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
	_check((picker.preview_label.text.contains("Move") or picker.preview_label.text.contains("Swap"))
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
	# Exercise both Shop powers through physical mouse selections; the following
	# Button Eye selection exercises the keyboard on this same mounted picker.
	for spec in [
			["stitched_badge", "tinker", "MOVE", "HEAD", "opening Block",
				CombatShopPatchRules.OPENING_BLOCK_BONUS, "Stitched Badge"],
			["stitched_badge", "warden", "SWAP", "HEAD", "opening Block",
				CombatShopPatchRules.OPENING_BLOCK_BONUS, "Stitched Badge"],
			["spare_spool", "warden", "MOVE", "ARM", "positive-heal",
				CombatShopPatchRules.HEALING_CARD_BONUS, "Spare Spool"],
			["spare_spool", "seamstress", "SWAP", "ARM", "positive-heal",
				CombatShopPatchRules.HEALING_CARD_BONUS, "Spare Spool"]]:
		var source_index := -1
		for i in range(picker._sources.size()):
			if picker._sources[i].patch_id == spec[0]:
				source_index = i
		_check(source_index >= 0, "Shop patch is a selectable real source: " + spec[0])
		if source_index < 0:
			continue
		await _pick(picker._source_buttons[source_index], false)
		var destination_index := -1
		for i in range(picker._destinations.size()):
			if picker._destinations[i].to_hero == spec[1]:
				destination_index = i
		_check(destination_index >= 0, "Shop patch has legal same-slot destination: " + str(spec[0]) + " to " + str(spec[1]))
		if destination_index < 0:
			continue
		await _pick(picker._destination_buttons[destination_index], false)
		var preview: String = picker.preview_label.text
		var selected: Dictionary = picker.selected_option()
		var service: Dictionary = _option(f, spec[0], spec[1])
		var forecast: Dictionary = RunRestPatchResewOptions.forecast(w, t, original, f.rest, service)
		_check(selected == service and forecast.get("ok") == true
			and selected.kind == forecast.kind and selected.slot == forecast.slot
			and selected.exchanged_id == forecast.exchanged_id,
			"physical tags bind the entire exact service option and forecast")
		if forecast.get("ok") == true:
			for wearer in [forecast.source, forecast.destination]:
				for phase in ["before", "after"]:
					var state: Dictionary = wearer[phase]
					var marker := "%s %s • HP %d/%d, effective cap %d" % [
						str(wearer.hero_id).capitalize(), phase.to_upper(),
						state.hp, state.base_max_hp, state.effective_max_hp]
					_check(preview.contains(marker),
						"mounted preview exactly reflects forecast hero, HP and effective cap")
					for slot in RunRestPatchResewOptions.SLOTS:
						var patch_state: Dictionary = state.slots[slot]
						var display := "%s empty" % slot if patch_state.id == "" else (
							"%s %s (%s)" % [slot, str(patch_state.id).replace("_", " ").capitalize(),
								"active" if patch_state.active else "dormant"])
						_check(preview.contains(display),
							"mounted before/after forecast shows each authentic slot and activity")
		var friendly_kind := str(spec[2]).capitalize()
		var friendly_slot := str(spec[3]).capitalize()
		var friendly_detail := "empty %s slot" % friendly_slot if spec[2] == "MOVE" else (
			"swap with %s" % str(service.exchanged_id).replace("_", " ").capitalize())
		_check(preview.contains("%s • %s patch" % [friendly_kind, friendly_slot])
			and preview.contains(friendly_detail)
			and picker._source_buttons[source_index].text.contains(
				"%s patch" % friendly_slot)
			and picker._destination_buttons[destination_index].text.contains(friendly_kind)
			and picker._destination_buttons[destination_index].text.contains(friendly_detail),
			"mouse-selected sewn chips and forecast use human action/slot/recipient labels")
		_check(preview.contains(friendly_kind) and preview.contains("BEFORE")
			and preview.contains("AFTER") and preview.contains("Cost: 1 scrap")
			and preview.contains(spec[3] + " " + spec[6] + " (active)")
			and preview.contains(spec[4]) and preview.contains(str(spec[5]))
			and not picker.confirm_button.disabled,
			"physical mouse choice shows real Shop MOVE/SWAP and exact active power: "
			+ spec[0] + " to " + spec[1])
	_check(picker.present(w, t, original, f.rest),
		"mounted picker can re-present the same unchanged Rest after Shop inspection")
	await _frames()
	var head_index := -1
	for i in range(picker._sources.size()):
		if picker._sources[i].patch_id == "button_eye":
			head_index = i
	_check(head_index >= 0, "authored Button Eye source is selectable")
	if head_index >= 0:
		await _pick(picker._source_buttons[head_index], true)
		_check(picker.source_selector.selected == head_index
			and picker._source_buttons[head_index].button_pressed
			and picker.destination_selector.selected == -1
			and picker.confirm_button.disabled
			and picker.preview_label.text.contains("Select a destination"),
			"changing source visibly clears any stale destination and preview")
		for step in range(picker._source_buttons.size() - head_index):
			await _key(KEY_TAB)
		_check(picker.destination_selector.has_focus(),
			"Tab traverses remaining source tags before destination")

		var move_index := -1
		for i in range(picker._destinations.size()):
			if picker._destinations[i].to_hero == "tinker":
				move_index = i
		_check(move_index >= 0, "empty same-slot target exists")
		if move_index >= 0:
			await _pick(picker._destination_buttons[move_index], false)
			_check(picker.preview_label.text.contains("Move • Head patch")
				and picker.preview_label.text.contains("empty Head slot")
				and picker.preview_label.text.contains("Tinker AFTER"),
				"physical mouse selection displays empty MOVE and its active recipient")
		var target_index := -1
		for i in range(picker._destinations.size()):
			if picker._destinations[i].to_hero == "seamstress":
				target_index = i
		_check(target_index >= 0, "occupied same-slot recipient reachable")
		if target_index >= 0:
			await _pick(picker._destination_buttons[target_index], false)
			_check(picker.preview_label.text.contains("Swap • Head patch")
				and picker.preview_label.text.contains("swap with Stitched Badge")
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
	var counterfeit: Dictionary = exact.duplicate(true)
	counterfeit["definitions"] = counterfeit["definitions"].duplicate(true)
	counterfeit["definitions"]["bloodstitch_bonnet"] = "ARM"
	var counterfeit_option: Dictionary = option.duplicate(true)
	counterfeit_option["slot"] = "ARM"
	counterfeit_option["patch_id"] = "bloodstitch_bonnet"
	_check(not RunRestPatchResewOptions.forecast(w, t, counterfeit, f.rest, counterfeit_option).ok,
		"counterfeit catalog definitions rejected")
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


func _coat_fixture_with(sewn_coats: Dictionary, torn_hero_ids: Array = []) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	if typeof(raw) != TYPE_ARRAY or raw.size() != 3:
		return {}
	var combat_defs: Array = raw.duplicate(true)
	for record in combat_defs:
		record["max_hp"] = int(record["max_hp"])
	var party := CombatParty.new(combat_defs)
	if not party.is_valid():
		return {}
	var heroes := party.get_heroes()
	var torn := RunTornMending.new(heroes)
	if not torn_hero_ids.is_empty():
		var old_heroes := heroes.duplicate(true)
		var damaged := heroes.duplicate(true)
		for hero in damaged:
			if torn_hero_ids.has(hero["id"]):
				hero["hp"] = 0
		_check(torn.observe_battle_end("test_tear", old_heroes, damaged).ok, "fixture tear observed")
		heroes = torn.read_state()["heroes"]
	var definitions := []
	for catalog in ["initial_patch_slots", "m04_attack_patches", "m04_coat_patches"]:
		var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/%s.json" % catalog))
		if typeof(entries) == TYPE_ARRAY:
			for entry in entries:
				definitions.append({"id": entry["id"], "slot": entry["slot"]})
	var owned := ["button_eye", "pincushion_arm", "stitched_badge", "spare_spool"]
	for coat_id in sewn_coats.values():
		if not owned.has(coat_id):
			owned.append(coat_id)
	for coat_id in _load_coat_amounts():
		if not owned.has(coat_id):
			owned.append(coat_id)
	var w := RunPatchWardrobe.new(heroes, owned, definitions, 10, 50,
		["warden_strike"], 93811, true)
	if not torn.is_valid() or not w.is_valid():
		return {}
	for hero_id in sewn_coats:
		var coat_id: String = sewn_coats[hero_id]
		var receipt := w.sew(coat_id, hero_id, "COAT", "sew:" + coat_id, w.get_snapshot())
		_check(receipt.ok, "fixture coat sewn: " + coat_id)
	_check(w.start_rest("rest_coats", w.get_snapshot()).ok, "rest started for coat fixture")
	return {"w": w, "t": torn, "rest": "rest_coats"}


func _coat_preview_tests() -> void:
	var coat_amounts := _load_coat_amounts()
	_check(coat_amounts.get("scrap_lined_vest") == 3
		and coat_amounts.get("padded_vest") == 4
		and coat_amounts.get("wool_patch_cloak") == 5
		and coat_amounts.get("quilted_coat") == 6
		and coat_amounts.get("chain_stitched_coat") == 7
		and coat_amounts.get("double_quilt_coat") == 8,
		"all six authored coat bonus amounts (+3, +4, +5, +6, +7, +8) present")
	var coats_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_coat_patches.json"))
	for coat_id in ["scrap_lined_vest", "padded_vest", "wool_patch_cloak",
			"quilted_coat", "chain_stitched_coat", "double_quilt_coat"]:
		var bonus: int = coat_amounts[coat_id]
		var f := _coat_fixture_with({"tinker": coat_id})
		var choice := _option(f, coat_id, "warden")
		_check(not choice.is_empty(), "legal MOVE option for " + coat_id)
		if choice.is_empty():
			continue
		var snap_before: Dictionary = f.w.get_snapshot()
		var torn_state: Dictionary = f.t.read_state()
		var forecast := RunRestPatchResewOptions.forecast(f.w, f.t, snap_before, f.rest, choice)
		_check(forecast.get("ok") == true and forecast.get("kind") == "MOVE"
			and forecast.get("cost") == 1,
			"forecast succeeds for " + coat_id)
		_check(f.w.get_snapshot() == snap_before and f.t.read_state() == torn_state
			and f.w.get_snapshot().scraps == 10,
			"detached forecast leaves ledger, scraps and torn untouched for " + coat_id)
		_check(forecast.source.before.hp == 26 and forecast.source.after.hp == 26
			and forecast.destination.before.hp == 40 and forecast.destination.after.hp == 40
			and forecast.source.before.base_max_hp == 26 and forecast.source.after.base_max_hp == 26
			and forecast.destination.before.base_max_hp == 40 and forecast.destination.after.base_max_hp == 40,
			"MOVE %s: HP and base_max_hp never mutate or heal in preview" % coat_id)
		_check(forecast.source.before.effective_max_hp == 26 + bonus
			and forecast.source.after.effective_max_hp == 26
			and forecast.destination.before.effective_max_hp == 40
			and forecast.destination.after.effective_max_hp == 40 + bonus,
			"MOVE %s: effective max HP correctly shows +%d bonus transfer" % [coat_id, bonus])
		_check(forecast.source.before.slots.COAT.effect == "+%d effective max HP (no heal)" % bonus
			and forecast.destination.after.slots.COAT.effect == "+%d effective max HP (no heal)" % bonus,
			"MOVE %s: coat effect text truthfully describes +%d bonus" % [coat_id, bonus])
		var proj_before := RunPatchCoatRules.project_health(torn_state, f.w, coats_raw)
		_check(proj_before.get("ok") == true, "project_health succeeds before commit for " + coat_id)
		for hero in proj_before.get("heroes", []):
			if hero["id"] == "tinker":
				_check(hero["max_hp"] == forecast.source.before.effective_max_hp,
					"project_health matches source before effective_max_hp for " + coat_id)
			elif hero["id"] == "warden":
				_check(hero["max_hp"] == forecast.destination.before.effective_max_hp,
					"project_health matches dest before effective_max_hp for " + coat_id)
		var commit: Dictionary = f.w.re_sew(coat_id, "tinker", "warden", f.rest, "commit:" + coat_id, snap_before)
		_check(commit.ok and f.w.get_snapshot().scraps == snap_before.scraps - 1,
			"real commit spends exactly 1 scrap for " + coat_id)
		var proj_after := RunPatchCoatRules.project_health(torn_state, f.w, coats_raw)
		_check(proj_after.get("ok") == true, "project_health succeeds after commit for " + coat_id)
		for hero in proj_after.get("heroes", []):
			if hero["id"] == "tinker":
				_check(hero["max_hp"] == forecast.source.after.effective_max_hp,
					"project_health matches source after effective_max_hp for " + coat_id)
			elif hero["id"] == "warden":
				_check(hero["max_hp"] == forecast.destination.after.effective_max_hp,
					"project_health matches dest after effective_max_hp for " + coat_id)

	# Legal SWAP of two different coats: Warden wears double_quilt_coat (+8), Tinker wears padded_vest (+4)
	var f_swap := _coat_fixture_with({"warden": "double_quilt_coat", "tinker": "padded_vest"})
	var swap_opt := _option(f_swap, "double_quilt_coat", "tinker")
	_check(not swap_opt.is_empty() and swap_opt.kind == "SWAP"
		and swap_opt.exchanged_id == "padded_vest", "legal SWAP option for different coats")
	if not swap_opt.is_empty():
		var snap_swap: Dictionary = f_swap.w.get_snapshot()
		var torn_swap: Dictionary = f_swap.t.read_state()
		var forecast_swap := RunRestPatchResewOptions.forecast(f_swap.w, f_swap.t, snap_swap, f_swap.rest, swap_opt)
		_check(forecast_swap.get("ok") == true and forecast_swap.get("kind") == "SWAP",
			"SWAP forecast succeeds")
		_check(forecast_swap.source.before.effective_max_hp == 48
			and forecast_swap.source.after.effective_max_hp == 44
			and forecast_swap.source.before.hp == 40 and forecast_swap.source.after.hp == 40
			and forecast_swap.source.before.base_max_hp == 40 and forecast_swap.source.after.base_max_hp == 40,
			"SWAP source (Warden): +8 before, +4 after, HP unchanged")
		_check(forecast_swap.destination.before.effective_max_hp == 30
			and forecast_swap.destination.after.effective_max_hp == 34
			and forecast_swap.destination.before.hp == 26 and forecast_swap.destination.after.hp == 26
			and forecast_swap.destination.before.base_max_hp == 26 and forecast_swap.destination.after.base_max_hp == 26,
			"SWAP destination (Tinker): +4 before, +8 after, HP unchanged")
		_check(forecast_swap.source.before.slots.COAT.effect == "+8 effective max HP (no heal)"
			and forecast_swap.source.after.slots.COAT.effect == "+4 effective max HP (no heal)"
			and forecast_swap.destination.before.slots.COAT.effect == "+4 effective max HP (no heal)"
			and forecast_swap.destination.after.slots.COAT.effect == "+8 effective max HP (no heal)",
			"SWAP coat effect descriptions match authored amounts")
		var swap_proj_before := RunPatchCoatRules.project_health(torn_swap, f_swap.w, coats_raw)
		for hero in swap_proj_before.get("heroes", []):
			if hero["id"] == "warden":
				_check(hero["max_hp"] == forecast_swap.source.before.effective_max_hp, "swap proj before warden")
			elif hero["id"] == "tinker":
				_check(hero["max_hp"] == forecast_swap.destination.before.effective_max_hp, "swap proj before tinker")
		var swap_commit: Dictionary = f_swap.w.re_sew("double_quilt_coat", "warden", "tinker", f_swap.rest, "commit_swap", snap_swap)
		_check(swap_commit.ok and f_swap.w.get_snapshot().scraps == snap_swap.scraps - 1,
			"real SWAP commit spends exactly 1 scrap")
		var swap_proj_after := RunPatchCoatRules.project_health(torn_swap, f_swap.w, coats_raw)
		for hero in swap_proj_after.get("heroes", []):
			if hero["id"] == "warden":
				_check(hero["max_hp"] == forecast_swap.source.after.effective_max_hp, "swap proj after warden")
			elif hero["id"] == "tinker":
				_check(hero["max_hp"] == forecast_swap.destination.after.effective_max_hp, "swap proj after tinker")

	# MOVE to a torn/downed recipient with no active bonus: Seamstress is torn (hp = 0, base_max = 27), Tinker wears chain_stitched_coat (+7)
	var f_torn := _coat_fixture_with({"tinker": "chain_stitched_coat"}, ["seamstress"])
	var move_torn := _option(f_torn, "chain_stitched_coat", "seamstress")
	_check(not move_torn.is_empty(), "legal MOVE to torn recipient")
	if not move_torn.is_empty():
		var snap_torn: Dictionary = f_torn.w.get_snapshot()
		var state_torn: Dictionary = f_torn.t.read_state()
		var forecast_torn := RunRestPatchResewOptions.forecast(f_torn.w, f_torn.t, snap_torn, f_torn.rest, move_torn)
		_check(forecast_torn.get("ok") == true, "forecast to torn recipient succeeds")
		_check(forecast_torn.source.before.effective_max_hp == 33
			and forecast_torn.source.after.effective_max_hp == 26
			and forecast_torn.source.before.hp == 26 and forecast_torn.source.after.hp == 26,
			"source living loses bonus on transfer to torn hero")
		_check(forecast_torn.destination.before.hp == 0 and forecast_torn.destination.after.hp == 0
			and forecast_torn.destination.before.base_max_hp == 27
			and forecast_torn.destination.after.base_max_hp == 27
			and forecast_torn.destination.before.effective_max_hp == 27
			and forecast_torn.destination.after.effective_max_hp == 27
			and not forecast_torn.destination.after.slots.COAT.active
			and forecast_torn.destination.after.slots.COAT.effect == "+7 effective max HP (no heal)",
			"downed recipient has dormant +7, effective cap 27 not 34, no active bonus or revival")
		var torn_proj := RunPatchCoatRules.project_health(state_torn, f_torn.w, coats_raw)
		for hero in torn_proj.get("heroes", []):
			if hero["id"] == "seamstress":
				_check(hero["max_hp"] == forecast_torn.destination.before.effective_max_hp,
					"project_health confirms torn recipient has base max_hp (no coat bonus)")
		var torn_commit: Dictionary = f_torn.w.re_sew("chain_stitched_coat", "tinker", "seamstress", f_torn.rest, "commit_torn", snap_torn)
		_check(torn_commit.ok, "re_sew to torn recipient succeeds")
		var torn_proj_after := RunPatchCoatRules.project_health(state_torn, f_torn.w, coats_raw)
		for hero in torn_proj_after.get("heroes", []):
			if hero["id"] == "seamstress":
				_check(hero["max_hp"] == forecast_torn.destination.after.effective_max_hp,
					"project_health after commit confirms torn recipient still has base max_hp")

	# Forged coat slot in definitions rejected
	var f_forge := _coat_fixture_with({"tinker": "padded_vest"})
	var opt_forge := _option(f_forge, "padded_vest", "warden")
	if not opt_forge.is_empty():
		var forged_snap: Dictionary = f_forge.w.get_snapshot().duplicate(true)
		forged_snap["definitions"]["padded_vest"] = "HEAD"
		_check(not RunRestPatchResewOptions.forecast(f_forge.w, f_forge.t, forged_snap, f_forge.rest, opt_forge).ok,
			"forged non-COAT slot definition for coat patch is rejected")



func _run() -> void:
	_pure_tests()
	_coat_preview_tests()
	_torn_test()
	_torn_shop_test()
	await _ui_test(KEY_SPACE)
	await _ui_test(KEY_ENTER)
	_deny_test()
	for failure in failures:
		printerr(failure)
	print("rest_resew_effect_preview_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
