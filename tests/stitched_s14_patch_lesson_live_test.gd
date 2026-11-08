extends SceneTree
## S14 patch-lesson lane: the pure StitchedPatchLesson formatter and four lines
## inside the real Wren Drawings field guide on the mounted base screen.

const SCENE := preload("res://scenes/base_screen.tscn")

var failures: Array[String] = []
var checks := 0
var view: BaseScreen
var original_bedroom_enabled := true
var guide_close_calls := 0
var leaked_host_calls := 0


func _initialize() -> void:
	original_bedroom_enabled = StitchedBedroom.enabled
	StitchedBedroom.enabled = true
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)


func _frames() -> void:
	for _i in range(3):
		await process_frame


func _key(key: Key, shifted: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.shift_pressed = shifted
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


## Inject individual controller edges through the live scene tree.
func _pad(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "visible pointer target " + button.name)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _has_digit(text: String) -> bool:
	for index in text.length():
		if text[index].is_valid_int():
			return true
	return false


func _collect_focusable(node: Node, out: Array) -> void:
	if node is Control:
		var control := node as Control
		if control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
			out.append(control)
	for child in node.get_children():
		_collect_focusable(child, out)


## Independent source assertions plus the exact four derived lines.
func _catalog_checks() -> void:
	var kits := StitchedS14Abilities.kits()
	var patches := StitchedS14Abilities.patches()
	_check(not kits.is_empty() and patches.get("by_id", {}) is Dictionary
		and not patches.by_id.is_empty(), "live S14 ability and patch catalogs validate")
	var heal: Dictionary = kits.get("seamstress", {}).get("head", {})
	_check(str(heal.get("id", "")) == "seamstress_head_mending_knot"
		and str(heal.get("name", "")) == "Mending Knot"
		and str(heal.get("kind", "")) == "heal"
		and str(heal.get("target_side", "")) == "ally"
		and int(heal.get("effects", {}).get("heal", 0)) == 5,
		"shipped Seamstress head record is the ally heal Mending Knot with heal 5")
	var strike: Dictionary = kits.get("warden", {}).get("torso", {})
	_check(str(strike.get("id", "")) == "warden_torso_iron_challenge"
		and str(strike.get("name", "")) == "Iron Challenge"
		and str(strike.get("kind", "")) == "melee"
		and str(strike.get("target_side", "")) == "enemy"
		and int(strike.get("effects", {}).get("weak", 0)) == 2,
		"shipped Warden torso record is the enemy melee Iron Challenge with weak 2")
	var ward: Dictionary = kits.get("tinker", {}).get("torso", {})
	_check(str(ward.get("id", "")) == "tinker_torso_casing_ward"
		and str(ward.get("name", "")) == "Casing Ward"
		and str(ward.get("slot", "")) == "torso"
		and str(ward.get("kind", "")) == "buff"
		and str(ward.get("target_side", "")) == "self"
		and str(ward.get("move", "")) == "skill"
		and int(ward.get("effects", {}).get("thorns", 0)) == 2,
		"shipped Tinker torso is the self-targeted thorns Casing Ward skill")
	var wash: Dictionary = kits.get("lantern_monk", {}).get("torso", {})
	_check(str(wash.get("id", "")) == "lantern_monk_torso_lamplight_wash"
		and str(wash.get("name", "")) == "Lamplight Wash"
		and str(wash.get("slot", "")) == "torso"
		and str(wash.get("kind", "")) == "heal"
		and str(wash.get("target_side", "")) == "ally"
		and str(wash.get("move", "")) == "skill"
		and wash.get("multi", false) is bool and wash.get("multi", false) == true
		and int(wash.get("effects", {}).get("heal", 0)) == 4,
		"shipped Lantern Monk torso is the multi-ally Lamplight Wash healing skill")
	var lint: Dictionary = patches.by_id.get("cotton_red_lint", {})
	_check(str(lint.get("id", "")) == "cotton_red_lint"
		and str(lint.get("name", "")) == "Red Lint"
		and str(lint.get("rarity", "")) == "cotton"
		and str(lint.get("effect", "")) == "bleed"
		and int(lint.get("amount", 0)) == 2,
		"shipped Red Lint record is a cotton bleed patch of amount 2")
	var fuzz: Dictionary = patches.by_id.get("cotton_mending_fuzz", {})
	_check(str(fuzz.get("id", "")) == "cotton_mending_fuzz"
		and str(fuzz.get("name", "")) == "Mending Fuzz"
		and str(fuzz.get("rarity", "")) == "cotton"
		and str(fuzz.get("effect", "")) == "heal"
		and int(fuzz.get("amount", 0)) == 2,
		"shipped Mending Fuzz record is a cotton heal patch of amount 2")
	var pin: Dictionary = patches.by_id.get("silk_pin_prick", {})
	_check(str(pin.get("id", "")) == "silk_pin_prick"
		and str(pin.get("name", "")) == "Pin Prick"
		and str(pin.get("rarity", "")) == "silk"
		and str(pin.get("effect", "")) == "stun"
		and int(pin.get("amount", 0)) == 1,
		"shipped Pin Prick is a silk stun patch of amount 1")
	var loop: Dictionary = patches.by_id.get("silk_life_loop", {})
	_check(str(loop.get("id", "")) == "silk_life_loop"
		and str(loop.get("name", "")) == "Life Loop"
		and str(loop.get("rarity", "")) == "silk"
		and str(loop.get("effect", "")) == "regen"
		and int(loop.get("amount", 0)) == 2,
		"shipped Life Loop is a silk regen patch of amount 2")
	var lines := StitchedPatchLesson.examples()
	var expected := [
		"PATCH EXAMPLE  |  %s + %s: the heal can also bleed the ally it heals." % [str(heal.name), str(lint.name)],
		"PATCH EXAMPLE  |  %s + %s: the hostile hit can mend the foe it strikes if that foe survives." % [str(strike.name), str(fuzz.name)],
		"PATCH EXAMPLE  |  Casing Ward + Pin Prick: a self ward can also stun Tinker.",
		"PATCH EXAMPLE  |  Lamplight Wash + Life Loop: each ally healed can also gain regeneration.",
	]
	_check(lines == expected, "examples() returns exactly four precise source-derived lines in order")
	if lines.size() == 4:
		_check(lines[0].contains("Mending Knot + Red Lint") and lines[0].contains("ally")
			and lines[0].contains("bleed"),
			"first line pairs Mending Knot + Red Lint and names the bled ally")
		_check(lines[1].contains("Iron Challenge + Mending Fuzz") and lines[1].contains("foe")
			and lines[1].contains("survives"),
			"second line pairs Iron Challenge + Mending Fuzz and conditions on the surviving foe")
		_check(lines[2].contains("Casing Ward + Pin Prick") and lines[2].contains("stun Tinker"),
			"third line pairs a self ward with its possible caster stun")
		_check(lines[3].contains("Lamplight Wash + Life Loop") and lines[3].contains("each ally healed"),
			"fourth line pairs the group heal with possible regen for each ally")
		var digit_free := true
		for line in lines:
			if _has_digit(line):
				digit_free = false
		_check(digit_free, "all four lesson lines contain no numbers, costs, odds or forecasts")
	_check(StitchedPatchLesson.examples(kits, patches) == expected,
			"detached live sources derive exactly the same four lines")
	seed(918273)
	var expected_rng := randi()
	seed(918273)
	StitchedPatchLesson.examples()
	StitchedPatchLesson.examples(kits, patches)
	_check(randi() == expected_rng, "formatting consumes no global RNG")


## Adversarial detached copies: every invalid combination fails closed to [],
## inputs stay unmodified and the live caches are never poisoned.
func _invalid_checks() -> void:
	var kits := StitchedS14Abilities.kits()
	var patches := StitchedS14Abilities.patches()
	var kits_snapshot: Dictionary = kits.duplicate(true)
	var patches_snapshot: Dictionary = patches.duplicate(true)
	_check(StitchedPatchLesson.examples({}, {}) == []
		and StitchedPatchLesson.examples(null, {}) == []
		and StitchedPatchLesson.examples({}, null) == [],
		"empty or half-empty sources fail closed")
	seed(72914)
	var expected_invalid_rng := randi()
	seed(72914)
	var kit_cases: Array = []
	var missing_heal: Dictionary = kits.duplicate(true)
	missing_heal["seamstress"].erase("head")
	kit_cases.append(["seamstress head ability missing", missing_heal, patches])
	var missing_strike: Dictionary = kits.duplicate(true)
	missing_strike["warden"].erase("torso")
	kit_cases.append(["warden torso ability missing", missing_strike, patches])
	var wrong_side: Dictionary = kits.duplicate(true)
	wrong_side["seamstress"]["head"]["target_side"] = "enemy"
	kit_cases.append(["heal target side flipped", wrong_side, patches])
	var wrong_kind: Dictionary = kits.duplicate(true)
	wrong_kind["warden"]["torso"]["kind"] = "heal"
	kit_cases.append(["strike kind wrong", wrong_kind, patches])
	var empty_effects: Dictionary = kits.duplicate(true)
	empty_effects["warden"]["torso"]["effects"] = {}
	kit_cases.append(["strike without authored effects", empty_effects, patches])
	var no_heal_effect: Dictionary = kits.duplicate(true)
	no_heal_effect["seamstress"]["head"]["effects"] = {"weak": 2}
	kit_cases.append(["heal without a positive heal effect", no_heal_effect, patches])
	var wrong_name: Dictionary = kits.duplicate(true)
	wrong_name["seamstress"]["head"]["name"] = "Patchwork Knot"
	kit_cases.append(["heal name mismatch", wrong_name, patches])
	var wrong_id: Dictionary = kits.duplicate(true)
	wrong_id["warden"]["torso"]["id"] = "warden_torso_other_challenge"
	kit_cases.append(["strike id mismatch", wrong_id, patches])
	var bad_kit: Dictionary = kits.duplicate(true)
	bad_kit["tinker"].erase("torso")
	kit_cases.append(["Tinker self ward missing", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["lantern_monk"].erase("torso")
	kit_cases.append(["Lantern Monk group heal missing", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["tinker"]["torso"]["target_side"] = "ally"
	kit_cases.append(["Tinker ward is not self-targeted", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["lantern_monk"]["torso"]["target_side"] = "self"
	kit_cases.append(["Lantern Monk heal does not target allies", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["tinker"]["torso"]["kind"] = "guard"
	kit_cases.append(["Tinker ward kind is wrong", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["lantern_monk"]["torso"]["kind"] = "buff"
	kit_cases.append(["Lantern Monk heal kind is wrong", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["tinker"]["torso"]["effects"] = {"guard": 2}
	kit_cases.append(["Tinker thorns effect missing", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["lantern_monk"]["torso"]["effects"]["heal"] = 0
	kit_cases.append(["Lantern Monk heal amount zero", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["tinker"]["torso"]["id"] = "tinker_torso_other_ward"
	kit_cases.append(["Tinker ability ID wrong", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["lantern_monk"]["torso"]["name"] = "Dusk Wash"
	kit_cases.append(["Lantern Monk ability name wrong", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["tinker"]["torso"]["slot"] = "arms"
	kit_cases.append(["Tinker ward slot contradicts torso", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["lantern_monk"]["torso"]["slot"] = "head"
	kit_cases.append(["Lantern Monk heal slot contradicts torso", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["tinker"]["torso"]["move"] = "attack"
	kit_cases.append(["Tinker ward move is not skill", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["lantern_monk"]["torso"]["move"] = "guard"
	kit_cases.append(["Lantern Monk heal move is not skill", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["lantern_monk"]["torso"].erase("multi")
	kit_cases.append(["Lantern Monk multi missing", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["lantern_monk"]["torso"]["multi"] = false
	kit_cases.append(["Lantern Monk multi false", bad_kit, patches])
	bad_kit = kits.duplicate(true)
	bad_kit["lantern_monk"]["torso"]["multi"] = 1
	kit_cases.append(["Lantern Monk multi is not a boolean", bad_kit, patches])
	for entry in kit_cases:
		var before: Dictionary = (entry[1] as Dictionary).duplicate(true)
		_check(StitchedPatchLesson.examples(entry[1], entry[2]) == [],
			"invalid kits rejected: " + str(entry[0]))
		_check(entry[1] == before, "invalid kit copy is not mutated: " + str(entry[0]))
	var patch_cases: Array = []
	var missing_lint: Dictionary = patches.duplicate(true)
	missing_lint.by_id.erase("cotton_red_lint")
	patch_cases.append(["red lint missing", kits, missing_lint])
	var missing_fuzz: Dictionary = patches.duplicate(true)
	missing_fuzz.by_id.erase("cotton_mending_fuzz")
	patch_cases.append(["mending fuzz missing", kits, missing_fuzz])
	var wrong_effect: Dictionary = patches.duplicate(true)
	wrong_effect.by_id["cotton_red_lint"]["effect"] = "heal"
	patch_cases.append(["red lint effect wrong", kits, wrong_effect])
	var wrong_rarity: Dictionary = patches.duplicate(true)
	wrong_rarity.by_id["cotton_mending_fuzz"]["rarity"] = "gold"
	patch_cases.append(["mending fuzz rarity wrong", kits, wrong_rarity])
	var wrong_patch_name: Dictionary = patches.duplicate(true)
	wrong_patch_name.by_id["cotton_red_lint"]["name"] = "Grey Lint"
	patch_cases.append(["red lint name wrong", kits, wrong_patch_name])
	var zero_amount: Dictionary = patches.duplicate(true)
	zero_amount.by_id["cotton_mending_fuzz"]["amount"] = 0
	patch_cases.append(["mending fuzz amount not positive", kits, zero_amount])
	var bad_patch: Dictionary = patches.duplicate(true)
	bad_patch.by_id.erase("silk_pin_prick")
	patch_cases.append(["Pin Prick missing", kits, bad_patch])
	bad_patch = patches.duplicate(true)
	bad_patch.by_id.erase("silk_life_loop")
	patch_cases.append(["Life Loop missing", kits, bad_patch])
	bad_patch = patches.duplicate(true)
	bad_patch.by_id["silk_pin_prick"]["name"] = "Blunt Prick"
	patch_cases.append(["Pin Prick name wrong", kits, bad_patch])
	bad_patch = patches.duplicate(true)
	bad_patch.by_id["silk_life_loop"]["id"] = "silk_other_loop"
	patch_cases.append(["Life Loop ID wrong", kits, bad_patch])
	bad_patch = patches.duplicate(true)
	bad_patch.by_id["silk_pin_prick"]["rarity"] = "cotton"
	patch_cases.append(["Pin Prick silk switched to cotton", kits, bad_patch])
	bad_patch = patches.duplicate(true)
	bad_patch.by_id["silk_life_loop"]["rarity"] = "cotton"
	patch_cases.append(["Life Loop silk switched to cotton", kits, bad_patch])
	bad_patch = patches.duplicate(true)
	bad_patch.by_id["silk_pin_prick"]["effect"] = "heal"
	patch_cases.append(["Pin Prick no longer stuns", kits, bad_patch])
	bad_patch = patches.duplicate(true)
	bad_patch.by_id["silk_life_loop"]["effect"] = "stun"
	patch_cases.append(["Life Loop no longer regenerates", kits, bad_patch])
	bad_patch = patches.duplicate(true)
	bad_patch.by_id["silk_pin_prick"]["amount"] = 0
	patch_cases.append(["Pin Prick amount zero", kits, bad_patch])
	bad_patch = patches.duplicate(true)
	bad_patch.by_id["silk_life_loop"]["amount"] = 0
	patch_cases.append(["Life Loop amount zero", kits, bad_patch])
	for entry in patch_cases:
		var before: Dictionary = (entry[2] as Dictionary).duplicate(true)
		_check(StitchedPatchLesson.examples(entry[1], entry[2]) == [],
			"invalid patches rejected: " + str(entry[0]))
		_check(entry[2] == before, "invalid patch copy is not mutated: " + str(entry[0]))
	_check(randi() == expected_invalid_rng,
		"invalid fixtures and fail-closed formatting consume no global RNG")
	_check(kits == kits_snapshot and patches == patches_snapshot
		and StitchedS14Abilities.kits() == kits_snapshot
		and StitchedS14Abilities.patches() == patches_snapshot,
		"live catalogs and caches are unpoisoned after every invalid fixture")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_catalog_checks()
	_invalid_checks()
	view = SCENE.instantiate() as BaseScreen
	root.add_child(view)
	await _frames()
	var room := view.bedroom
	var guide := view.field_guide
	_check(room != null and guide != null and not guide.is_open(),
		"bedroom-enabled base screen mounts the closed guide")
	if room == null or guide == null:
		_finish()
		return
	var drawings := room.spot("drawings")
	_check(drawings != null and drawings == view.guide_button,
		"the real Drawings hotspot is the adopted guide entry")
	_check(view.open_village(31, 7), "bedroom host actually opens at 1280x720")
	await _frames()
	_check(drawings.is_visible_in_tree() and not drawings.disabled
		and root.get_visible_rect().has_point(drawings.get_global_rect().get_center()),
		"live Drawings hotspot is clickable")
	seed(551109)
	var browse_rng := randi()
	seed(551109)
	await _click(drawings)
	_check(guide.is_open() and guide.is_visible_in_tree()
		and root.gui_get_focus_owner() == guide.tab_buttons[0],
		"Drawings opens the guide focused on tab 0")
	_check(guide.tab_buttons.size() == 4 and guide.page_labels.size() == 4
		and guide.TABS == ["Ranks & turns", "Seams & retreat", "Fray & resolve", "Candle & stops"],
		"four original tabs and pages remain")
	_check(guide.get_child_count() == 2, "no extra child controls were added to the guide")
	var focusable: Array = []
	_collect_focusable(guide, focusable)
	_check(focusable.size() == 6, "exactly the six original controls are focusable inside the guide")
	await _click(guide.tab_buttons[1])
	_check(guide.page_index == 1 and guide.page_labels[1].is_visible_in_tree()
		and guide.tab_buttons[1].button_pressed,
		"tab 1 selects the Seams & retreat page")
	var visible_pages := 0
	for i in range(4):
		if guide.page_labels[i].visible:
			visible_pages += 1
	_check(visible_pages == 1, "exactly one page is visible at a time")
	var page := guide.page_text(1)
	var static_phrases := ["RETREAT", "SNIPPED THREAD", "ABILITY PATCH SOCKETS", "THREAD QUALITY",
		"EFFECTS ON THE ACTUAL TARGET", "ALLY PATCHES", "Sewing Circle",
		"cotton < wool < silk < gold", "bleed-patched HEAL", "your own ally"]
	var missing: Array = []
	for phrase in static_phrases:
		if not page.contains(phrase):
			missing.append(phrase)
	_check(missing.is_empty(), "all original Seams & retreat lines survive: " + str(missing))
	var lessons := StitchedPatchLesson.examples()
	var all_present_once := lessons.size() == 4
	var indices: Array[int] = []
	for line in lessons:
		if page.count(line) != 1:
			all_present_once = false
		indices.append(page.find(line))
	var ordered := indices.size() == 4
	if ordered:
		for i in range(1, indices.size()):
			if indices[i] <= indices[i - 1]:
				ordered = false
	_check(all_present_once and ordered,
		"all four exact lines render exactly once, in order, on the real Seams & retreat page")
	var scroll_bar := guide.page_scroll.get_v_scroll_bar()
	_check(guide.page_scroll != null and scroll_bar != null
		and guide.page_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"page scroll remains reachable with horizontal scroll disabled")
	var travel := maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	guide.page_scroll.scroll_vertical = int(travel)
	await process_frame
	_check(travel > 0.0 and guide.page_scroll.scroll_vertical > 0,
		"four lessons overflow the 1280x720 guide and its vertical scroll moves")
	guide.page_scroll.scroll_vertical = 0
	await _key(KEY_RIGHT)
	_check(guide.page_index == 2 and root.gui_get_focus_owner() == guide.tab_buttons[2],
		"right arrow turns exactly one page and keeps focus on its tab")
	await _click(guide.tab_buttons[1])
	await _key(KEY_TAB)
	_check(focusable.has(root.gui_get_focus_owner()), "Tab keeps focus inside the guide ring, no leak")
	await _click(guide.close_button)
	_check(not guide.is_open() and root.gui_get_focus_owner() == drawings,
		"Close dismisses and restores the live Drawings focus")
	await _click(drawings)
	_check(guide.is_open(), "Drawings reopens the same mounted guide")
	await _click(guide.tab_buttons[1])
	page = guide.page_text(1)
	var reopened_complete := page.contains("RETREAT")
	for line in lessons:
		if page.count(line) != 1:
			reopened_complete = false
	_check(reopened_complete,
		"reopen shows all four examples once each with original static content intact")
	var broken_kits: Dictionary = StitchedS14Abilities.kits().duplicate(true)
	broken_kits["seamstress"].erase("head")
	guide.lesson_kits = broken_kits
	await _click(guide.close_button)
	await _click(drawings)
	await _click(guide.tab_buttons[1])
	page = guide.page_text(1)
	var baseline := "\n\n".join(StitchedFieldGuide.PAGES[1])
	var invalid_clean := page == baseline
	for line in lessons:
		if page.contains(line):
			invalid_clean = false
	_check(invalid_clean,
		"an invalid required lesson row rebuilds only the plain baseline, without stale lines")
	guide.lesson_kits = null
	await _click(guide.close_button)
	await _click(drawings)
	await _click(guide.tab_buttons[1])
	page = guide.page_text(1)
	var restored_complete := page.contains("RETREAT")
	for line in lessons:
		if page.count(line) != 1:
			restored_complete = false
	_check(restored_complete,
		"restored live sources re-derive all four examples exactly once")
	await _key(KEY_ESCAPE)
	_check(not guide.is_open() and root.gui_get_focus_owner() == drawings
		and not drawings.disabled,
		"Escape dismisses and restores the live Drawings focus")
	# Mounted, controller-only route: real bedroom hotspot -> existing guide
	# -> validated nested atlas -> one-level-at-a-time B -> Drawings.
	guide.close_requested.connect(func() -> void: guide_close_calls += 1)
	view.back_requested.connect(func() -> void: leaked_host_calls += 1)
	view.set_out_requested.connect(func() -> void: leaked_host_calls += 1)
	view.path_choice_requested.connect(func(_id: String) -> void: leaked_host_calls += 1)
	var original_record := room.record.duplicate(true)
	var original_wallet := view.wallet_label.text
	var original_paths := [view.selected_path_id(), view.selected_tinker_path_id(),
		view.selected_warden_path_id(), view._set_out_pending, view._back_pending]
	var close_before := guide_close_calls
	await _pad(JOY_BUTTON_B, true)
	await _pad(JOY_BUTTON_B, false)
	await _pad(JOY_BUTTON_RIGHT_SHOULDER, true)
	await _pad(JOY_BUTTON_RIGHT_SHOULDER, false)
	_check(not guide.is_open() and guide_close_calls == close_before,
		"hidden guide ignores controller B and shoulder")
	drawings.grab_focus()
	await _key(KEY_ENTER)
	_check(guide.is_open() and root.gui_get_focus_owner() == guide.tab_buttons[0],
		"focused real bedroom Drawings opens guide through existing activation")
	await _pad(JOY_BUTTON_LEFT_SHOULDER, true)
	_check(guide.page_index == 3 and root.gui_get_focus_owner() == guide.tab_buttons[3],
		"left shoulder wraps focused page from first to last")
	await _pad(JOY_BUTTON_LEFT_SHOULDER, true)
	_check(guide.page_index == 3, "held shoulder event cannot double-page")
	await _pad(JOY_BUTTON_LEFT_SHOULDER, false)
	await _pad(JOY_BUTTON_RIGHT_SHOULDER, true)
	_check(guide.page_index == 0 and root.gui_get_focus_owner() == guide.tab_buttons[0],
		"right shoulder wraps page from last to first")
	await _pad(JOY_BUTTON_RIGHT_SHOULDER, false)
	await _click(guide.atlas_button)
	_check(guide._atlas_is_open() and guide.part_atlas.is_visible_in_tree()
		and root.gui_get_focus_owner() == guide.part_atlas.get_node("CloseButton"),
		"existing Parts & spoils button opens live validated nested atlas")
	if guide._atlas_is_open():
		var inspector := guide.part_atlas
		var ring := guide._atlas_focus_buttons()
		_check(ring.size() > 7 and ring[0] == inspector.get_node("CloseButton")
			and ring.has(inspector.get_node("CatalogPanel/OwnerFilter"))
			and ring.has(inspector.get_node("DetailsPanel/TierIII")),
			"mounted nested atlas exposes enabled owner, slots, rows and tier ring")
		var selected_id := inspector.selected_part_id
		var selected_tier := inspector.selected_tier
		var selected_owner := inspector.selected_owner
		await _pad(JOY_BUTTON_DPAD_UP, true)
		_check(root.gui_get_focus_owner() == ring[ring.size() - 1],
			"up wraps atlas focus from Close to last enabled tier")
		await _pad(JOY_BUTTON_DPAD_UP, false)
		await _pad(JOY_BUTTON_DPAD_DOWN, true)
		_check(root.gui_get_focus_owner() == ring[0],
			"down wraps atlas focus from last tier to Close")
		await _pad(JOY_BUTTON_DPAD_DOWN, false)
		var page_before := guide.page_index
		await _pad(JOY_BUTTON_RIGHT_SHOULDER, true)
		await _pad(JOY_BUTTON_RIGHT_SHOULDER, false)
		await _pad(JOY_BUTTON_LEFT_SHOULDER, true)
		await _pad(JOY_BUTTON_LEFT_SHOULDER, false)
		await _pad(JOY_BUTTON_Y, true)
		await _pad(JOY_BUTTON_Y, false)
		_check(guide.page_index == page_before
			and root.gui_get_focus_owner() == ring[0]
			and inspector.selected_part_id == selected_id
			and inspector.selected_tier == selected_tier
			and inspector.selected_owner == selected_owner,
			"nested controller focus never selects, equips or changes guide page")
		await _pad(JOY_BUTTON_B, true)
		_check(not guide._atlas_is_open() and guide.is_open()
			and root.gui_get_focus_owner() == guide.atlas_button
			and inspector.selected_part_id.is_empty()
			and inspector.get_node("DetailsPanel/PatchPreview").texture == null
			and inspector.get_node("DetailsPanel/TierBorderPreview").texture == null
			and guide_close_calls == close_before,
			"first B dismisses only atlas, clears stale data and restores Parts focus")
		await _pad(JOY_BUTTON_B, true)
		_check(guide.is_open() and root.gui_get_focus_owner() == guide.atlas_button
			and guide_close_calls == close_before,
			"held B does not leak into second modal close")
		await _pad(JOY_BUTTON_B, false)
		await _pad(JOY_BUTTON_B, true)
		_check(not guide.is_open() and not guide._atlas_is_open()
			and root.gui_get_focus_owner() == drawings and not drawings.disabled
			and guide_close_calls == close_before + 1,
			"fresh second B closes only guide with one signal, returns Drawings focus")
		await _pad(JOY_BUTTON_B, false)
		await _click(drawings)
		_check(guide.is_open() and root.gui_get_focus_owner() == guide.tab_buttons[0],
			"Drawings reopens only guide with no stale nested inspector")
		await _pad(JOY_BUTTON_B, true)
		_check(not guide.is_open() and root.gui_get_focus_owner() == drawings
			and guide_close_calls == close_before + 2,
			"B from guide alone returns directly to Drawings once")
		await _pad(JOY_BUTTON_B, false)
	_check(room.record == original_record and view.wallet_label.text == original_wallet
		and [view.selected_path_id(), view.selected_tinker_path_id(),
			view.selected_warden_path_id(), view._set_out_pending, view._back_pending] == original_paths
		and leaked_host_calls == 0 and randi() == browse_rng,
		"controller route changes no bedroom record, wallet, choices, callbacks or RNG")
	view.queue_free()
	await _frames()
	_finish()


func _finish() -> void:
	StitchedBedroom.enabled = original_bedroom_enabled
	if failures.is_empty():
		print("stitched_s14_patch_lesson_live_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		printerr("stitched_s14_patch_lesson_live_test: FAIL (%d/%d)" % [failures.size(), checks])
		quit(1)
