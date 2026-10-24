extends SceneTree

var failures: Array[String] = []
var checks := 0
var host: Control
var picker: LiveRestPatchResewPicker

## The master faces project.godot installs: Londrina headings, Patrick Hand body.
const BODY_FACE_PATH := "res://assets/fonts/PatrickHand-Regular.ttf"
const HEADING_FACE_PATH := "res://assets/fonts/LondrinaSolid-Regular.ttf"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	host = Control.new()
	host.name = "RestPickerFixture"
	host.size = Vector2(1280, 720)
	root.add_child(host)
	picker = LiveRestPatchResewPicker.new()
	picker.size = Vector2(1280, 720)
	host.add_child(picker)
	await process_frame
	_typography_checks()
	var f := _fixture(3)
	if not f.is_empty():
		_positive(f)
		_torn_mend(f)
		_negative(f)
	_torn_preview_active()
	await _input_checks()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("rest_patch_resew_picker_test: PASS (", checks, " checks)")
	else:
		for msg in failures:
			printerr("rest_patch_resew_picker_test: " + msg)
		print("rest_patch_resew_picker_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


## The face a mounted control really resolves through the installed project
## theme, looking through code-drawn FontVariation wrappers to their base font.
func _face_path(control: Control) -> String:
	if not is_instance_valid(control):
		return ""
	var font: Font = control.get_theme_font("font")
	while font is FontVariation and (font as FontVariation).base_font != null:
		font = (font as FontVariation).base_font
	return font.resource_path if font != null else ""


func _luminance(color: Color) -> float:
	var channels := []
	for value in [color.r, color.g, color.b]:
		channels.append(value / 12.92 if value <= 0.04045
			else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


func _contrast(first: Color, second: Color) -> float:
	var a := _luminance(first)
	var b := _luminance(second)
	return (max(a, b) + 0.05) / (min(a, b) + 0.05)


## The sewn option chips are body text too; checked on a picker that really
## mounts five worn sources and their two same-slot recipients.
func _chip_face_checks() -> void:
	_check(picker._source_buttons.size() == 5 and picker._destination_buttons.size() == 2,
		"chip typography fixture really mounts five sources and two recipients")
	for chip in picker._source_buttons + picker._destination_buttons:
		_check(_face_path(chip) == BODY_FACE_PATH
			and chip.get_theme_font_size("font_size") == 13,
			"sewn option chip text stays in the readable Patrick Hand body face")


## AC1/AC2: the mounted picker's own named headings and Confirm button inherit
## the master theme's Londrina faces, while every body text keeps Patrick Hand.
func _typography_checks() -> void:
	var theme_path := str(ProjectSettings.get_setting("gui/theme/custom", ""))
	var master: Theme = load(theme_path) if ResourceLoader.exists(theme_path) else null
	_check(master != null and theme_path == "res://assets/fonts/patchwork_theme.tres",
		"project installs the master patchwork theme as its default")
	if master == null:
		return
	var heading_font: Font = master.get_font("font", "PatchHeading")
	var button_font: Font = master.get_font("font", "PatchHeadingButton")
	_check(master.is_type_variation("PatchHeading", "Label")
		and master.is_type_variation("PatchHeadingButton", "Button")
		and heading_font != null and heading_font.resource_path == HEADING_FACE_PATH
		and button_font != null and button_font.resource_path == HEADING_FACE_PATH
		and master.default_font != null
		and master.default_font.resource_path == BODY_FACE_PATH,
		"master theme really provides Londrina headings and the Patrick Hand body face")
	var banner := picker.find_child("ResewBanner", true, false) as Label
	var source := picker.find_child("ResewSourceHeading", true, false) as Label
	var destination := picker.find_child("ResewDestinationHeading", true, false) as Label
	_check(banner != null and banner == picker.banner_label and banner.is_visible_in_tree()
		and source != null and source == picker.source_heading and source.is_visible_in_tree()
		and destination != null and destination == picker.destination_heading
		and destination.is_visible_in_tree(),
		"mounted picker exposes its named banner, source and recipient headings")
	var panel := picker.find_child("StitchedPaperRestPanel", true, false) as Control
	_check(panel != null and Rect2(0, 0, 1280, 720).encloses(panel.get_global_rect()),
		"stitched Rest panel stays inside the 1280x720 screen")
	for spec in [[banner, "REST  /  RE-SEW PATCHES", 26],
			[source, "WORN PATCH  /  SOURCE HERO", 18],
			[destination, "RECIPIENT HERO  /  MATCHING SLOT", 18]]:
		var label := spec[0] as Label
		if label == null:
			_check(false, "named picker heading exists: " + str(spec[1]))
			continue
		_check(label.text == spec[1] and label.theme_type_variation == "PatchHeading"
			and _face_path(label) == heading_font.resource_path
			and label.get_theme_font_size("font_size") == spec[2]
			and (panel == null or panel.get_global_rect().encloses(label.get_global_rect())),
			"named picker heading inherits the master PatchHeading Londrina face: " + str(spec[1]))
	for body in [picker.find_child("ResewInstruction", true, false), picker.scraps_label,
			picker.preview_label, picker.feedback_label]:
		var label := body as Label
		_check(label != null and label.theme_type_variation == ""
			and _face_path(label) == master.default_font.resource_path,
			"ordinary picker instruction, scraps, preview and feedback keep Patrick Hand")
	_check(picker.confirm_button.theme_type_variation == "PatchHeadingButton"
		and _face_path(picker.confirm_button) == button_font.resource_path
		and picker.confirm_button.is_visible_in_tree()
		and picker.confirm_button.focus_mode == Control.FOCUS_ALL
		and not picker.confirm_button.pressed.get_connections().is_empty(),
		"Confirm re-sew inherits PatchHeadingButton and keeps its real pressed signal")
	var face: Font = picker.confirm_button.get_theme_font("font")
	var face_size := picker.confirm_button.get_theme_font_size("font_size")
	var caption := face.get_string_size(picker.confirm_button.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, face_size)
	var confirm_box := picker.confirm_button.get_global_rect()
	_check(confirm_box.size.x > caption.x and confirm_box.size.y >= face_size
		and Rect2(0, 0, 1280, 720).encloses(confirm_box),
		"Confirm caption fits its real button on the 1280x720 Rest screen")
	for spec in [["normal", "font_color"], ["hover", "font_hover_color"],
			["pressed", "font_pressed_color"], ["hover_pressed", "font_hover_pressed_color"],
			["focus", "font_focus_color"], ["disabled", "font_disabled_color"]]:
		var surface := picker.confirm_button.get_theme_stylebox(spec[0]) as StyleBoxFlat
		var ink: Color = picker.confirm_button.get_theme_color(spec[1])
		_check(surface != null and _contrast(ink, surface.bg_color) >= 3.0,
			"Confirm stays legible in its %s state" % spec[0])


func _json(path: String) -> Variant:
	var raw := FileAccess.get_file_as_string(path)
	_check(not raw.is_empty(), "authored catalog exists: " + path)
	return JSON.parse_string(raw)


func _catalog_has(catalog: Array, id: String, fields: Dictionary) -> bool:
	for entry in catalog:
		if typeof(entry) != TYPE_DICTIONARY or entry.get("id") != id:
			continue
		var matches := true
		for field in fields:
			if entry.get(field) != fields[field]:
				matches = false
		if matches:
			return true
	return false


func _fixture(scraps: int) -> Dictionary:
	var authored_heroes: Variant = _json("res://data/heroes/starter_party.json")
	var slots: Variant = _json("res://data/patches/initial_patch_slots.json")
	var attacks: Variant = _json("res://data/patches/m04_attack_patches.json")
	var coats: Variant = _json("res://data/patches/m04_coat_patches.json")
	if not (authored_heroes is Array and slots is Array and attacks is Array and coats is Array):
		_check(false, "all four genuine catalogs parse into arrays")
		return {}
	var expected_names := ["warden", "seamstress", "tinker"]
	var expected_hp := [40, 30, 26]
	_check(authored_heroes.size() == 3, "starter party has exactly three hero roles")
	if authored_heroes.size() != 3:
		return {}
	for i in range(3):
		_check(authored_heroes[i].get("id") == expected_names[i]
			and authored_heroes[i].get("max_hp") == expected_hp[i],
			"authored hero identity, position and original health " + str(i))
	var defs := []
	var counts := {}
	for catalog in [slots, attacks, coats]:
		for entry in catalog:
			if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("id")) != TYPE_STRING:
				continue
			counts[entry["id"]] = counts.get(entry["id"], 0) + 1
			defs.append({"id": entry["id"], "slot": entry["slot"]})
	var intended := {"stitched_badge": "HEAD", "spare_spool": "ARM",
		"button_eye": "HEAD", "pincushion_arm": "ARM", "quilted_coat": "COAT"}
	for id in intended:
		_check(counts.get(id, 0) == 1 and defs.any(func(item): return item["id"] == id and item["slot"] == intended[id]),
			"named authored patch present exactly once with correct slot: " + id)
	_check(_catalog_has(attacks, "button_eye", {"effect": "first_attack_exposed", "amount": 1}),
		"button eye authored first attack exposes 1 per combat")
	_check(_catalog_has(attacks, "pincushion_arm", {"effect": "card_attack_bonus", "amount": 1}),
		"pincushion authored +1 damage metadata")
	_check(_catalog_has(coats, "quilted_coat", {"max_hp_bonus": 6}), "quilted coat authored +6 metadata")
	var combat_defs: Array = authored_heroes.duplicate(true)
	for entry in combat_defs:
		entry["max_hp"] = int(entry["max_hp"])
	var party := CombatParty.new(combat_defs)
	_check(party.is_valid(), "genuine CombatParty constructs from author data")
	if not party.is_valid():
		return {}
	var heroes: Array = party.get_heroes()
	var torn := RunTornMending.new(heroes)
	var owned: Array = intended.keys()
	var wardrobe := RunPatchWardrobe.new(heroes, owned, defs, scraps,
		173, ["warden_strike", "seamstress_prick"], 90217)
	_check(torn.is_valid() and wardrobe.is_valid(), "genuine mending and wardrobe service admitted")
	if not torn.is_valid() or not wardrobe.is_valid():
		return {}
	for step in [
		["button_eye", "warden", "HEAD"],
		["stitched_badge", "seamstress", "HEAD"],
		["pincushion_arm", "seamstress", "ARM"],
		["spare_spool", "tinker", "ARM"],
		["quilted_coat", "warden", "COAT"]
	]:
		var sewn := wardrobe.sew(step[0], step[1], step[2],
			"sew_" + step[0], wardrobe.get_snapshot())
		_check(sewn.get("ok") == true and sewn.receipt.scrap_delta == 0,
			"genuine sew establishes patch: " + step[0])
	var pre_rest := wardrobe.get_snapshot()
	var opened := wardrobe.start_rest("rest_resew_ui", pre_rest)
	_check(opened.get("ok") == true and opened.state.rest_id == "rest_resew_ui",
		"opening actual wardrobe Rest commits confirmed node")
	var f := {"party": party, "torn": torn, "wardrobe": wardrobe,
		"coats": coats, "rest": "rest_resew_ui", "requests": [],
		"receipts": [], "mode": "commit", "primary": RunRestRecovery.new(heroes)}
	return f


func _choices(f: Dictionary) -> Dictionary:
	return RunRestPatchResewOptions.project(f.wardrobe, f.torn,
		f.wardrobe.get_snapshot(), f.rest)


func _owner(patch: String, from_id: String, to_id: String,
		rest: String, expected: Dictionary, f: Dictionary) -> void:
	f.requests.append({"patch_id": patch, "from_hero": from_id, "to_hero": to_id,
		"rest": rest, "snapshot": expected.duplicate(true)})
	if f.mode == "hold":
		return
	if f.mode == "reject":
		_check(picker.present(f.wardrobe, f.torn, f.wardrobe.get_snapshot(),
			f.rest, "Owner rejected request"), "owner rejection re-presents live state")
		return
	var operation_id := "owner_resew_" + str(f.receipts.size() + 1)
	var receipt: Dictionary = f.wardrobe.re_sew(patch, from_id, to_id,
		rest, operation_id, expected)
	f.receipts.append(receipt.duplicate(true))
	_check(receipt.get("ok") == true, "run-owner uses exact detached signal snapshot and fresh ID")
	_check(picker.present(f.wardrobe, f.torn, f.wardrobe.get_snapshot(),
		f.rest, "Owner accepted " + operation_id) or f.wardrobe.get_snapshot().scraps == 0,
		"owner success refreshes the picker with a new receipt")


func _pick(patch_id: String, destination: String) -> void:
	var source_index := -1
	for i in range(picker._sources.size()):
		if picker._sources[i]["patch_id"] == patch_id:
			source_index = i
			break
	_check(source_index >= 0, "sewn source tag contains " + patch_id)
	if source_index < 0:
		return
	picker._source_buttons[source_index].pressed.emit()
	_check(picker.source_selector.selected == source_index
		and picker._source_buttons[source_index].button_pressed,
		"source tag identity and selected felt style match " + patch_id)
	var to_index := -1
	for j in range(picker._destinations.size()):
		if picker._destinations[j]["to_hero"] == destination:
			to_index = j
			break
	_check(to_index >= 0, "sewn destination tag contains " + destination)
	if to_index >= 0:
		picker._destination_buttons[to_index].pressed.emit()
		_check(picker.selected_option() == picker._destinations[to_index]
			and picker._destination_buttons[to_index].button_pressed,
			"selected destination matches exact authoritative service option")


const KNOWN_PATCH_POWERS := {
	"button_eye": "first attack each combat: Exposed 1",
	"stitched_badge": "+3 opening Block to living wearer (stacks with innate Block)",
	"pincushion_arm": "damage-dealing cards: +1 damage",
	"spare_spool": "+2 healing on positive-heal cards owned by wearer only",
	"quilted_coat": "+6 effective max HP (no heal)"
}


func _assert_changed_slot_preview(f: Dictionary, kind: String, slot: String,
		from_id: String, to_id: String, source_before: String, source_after: String,
		destination_before: String, destination_after: String) -> void:
	var option := picker.selected_option()
	var snapshot: Dictionary = f.wardrobe.get_snapshot()
	var forecast := RunRestPatchResewOptions.forecast(
		f.wardrobe, f.torn, snapshot, f.rest, option)
	var selected_is_real: bool = not option.is_empty() and forecast.get("ok") == true
	_check(selected_is_real and option.get("kind") == kind and option.get("slot") == slot
		and option.get("from_hero") == from_id and option.get("to_hero") == to_id
		and option.get("cost") == 1 and forecast.get("cost") == 1,
		"mounted %s %s has an authentic selected option and forecast" % [kind, slot])
	if not selected_is_real:
		return
	var source: Dictionary = forecast["source"]
	var destination: Dictionary = forecast["destination"]
	_check(source["before"]["slots"][slot]["id"] == source_before
		and source["after"]["slots"][slot]["id"] == source_after
		and destination["before"]["slots"][slot]["id"] == destination_before
		and destination["after"]["slots"][slot]["id"] == destination_after,
		"real %s %s forecast has the expected two before/after slot assignments" % [kind, slot])
	var preview := picker.preview_label.text
	var lines := preview.split(String.chr(10))
	_check(lines.size() == 3, "preview has just an action and two changed-slot lines")
	if lines.size() != 3:
		return
	var slot_name := slot.to_lower().capitalize() + " patch"
	var header := "%s / %s / %s to %s / Cost: %d scrap / Scraps %d to %d" % [
		kind.to_lower().capitalize(), slot_name, from_id.capitalize(), to_id.capitalize(),
		forecast["cost"], snapshot["scraps"], snapshot["scraps"] - forecast["cost"]]
	_check(lines[0] == header and picker.scraps_label.text == "Scraps: %d" % snapshot["scraps"],
		"action and wallet match real %s %s forecast and current purse" % [kind, slot])
	for index in range(2):
		var wearer: Dictionary = source if index == 0 else destination
		var before: Dictionary = wearer["before"]
		var after: Dictionary = wearer["after"]
		var before_patch: Dictionary = before["slots"][slot]
		var after_patch: Dictionary = after["slots"][slot]
		var expected_start := "%s %s: %s to %s / " % [
			wearer["hero_id"].capitalize(), slot_name,
			_expected_patch_state(before_patch), _expected_patch_state(after_patch)]
		var expected_health := "HP %d/%d to %d/%d / effective cap %d to %d" % [
			before["hp"], before["base_max_hp"], after["hp"], after["base_max_hp"],
			before["effective_max_hp"], after["effective_max_hp"]]
		_check(lines[index + 1] == expected_start + expected_health,
			"changed %s wearer quotes actual slot, power, activity, HP and cap" % wearer["hero_id"])
		for patch in [before_patch, after_patch]:
			var patch_id: String = patch["id"]
			if patch_id.is_empty():
				_check(patch["effect"] == "" and not patch["active"],
					"empty changed slot cannot invent a patch power")
			elif KNOWN_PATCH_POWERS.has(patch_id):
				_check(patch["effect"] == KNOWN_PATCH_POWERS[patch_id],
					"real forecast cites the independently known power: " + patch_id)
	for other_slot in ["HEAD", "ARM", "COAT"]:
		if other_slot == slot:
			continue
		_check(not preview.contains(other_slot) and
			not preview.contains(other_slot.to_lower().capitalize() + " patch:"),
			"preview omits unrelated %s inventories" % other_slot)


func _expected_patch_state(patch: Dictionary) -> String:
	var id: String = patch["id"]
	if id.is_empty():
		return "empty"
	var name := id.replace("_", " ").capitalize()
	var effect: String = patch["effect"]
	if not patch["active"]:
		return "%s (dormant; inactive power: %s)" % [name, effect] \
			if not effect.is_empty() else "%s (dormant)" % name
	return "%s (active: %s)" % [name, effect] \
		if not effect.is_empty() else "%s (active)" % name


func _positive(f: Dictionary) -> void:
	var w: RunPatchWardrobe = f.wardrobe
	var start := w.get_snapshot()
	var original_torn: Dictionary = f.torn.read_state()
	var original_coats: Array = f.coats.duplicate(true)
	var snapshot_before := start.duplicate(true)
	var model := _choices(f)
	_check(model.ok and model.scraps == 3 and model.options.size() == 10,
		"five genuinely worn patches each allow two other recipients")
	var expected := [
		["button_eye", "warden", "seamstress", "HEAD", "SWAP", "stitched_badge"],
		["button_eye", "warden", "tinker", "HEAD", "MOVE", ""],
		["quilted_coat", "warden", "seamstress", "COAT", "MOVE", ""],
		["quilted_coat", "warden", "tinker", "COAT", "MOVE", ""],
		["stitched_badge", "seamstress", "warden", "HEAD", "SWAP", "button_eye"],
		["stitched_badge", "seamstress", "tinker", "HEAD", "MOVE", ""],
		["pincushion_arm", "seamstress", "warden", "ARM", "MOVE", ""],
		["pincushion_arm", "seamstress", "tinker", "ARM", "SWAP", "spare_spool"],
		["spare_spool", "tinker", "warden", "ARM", "MOVE", ""],
		["spare_spool", "tinker", "seamstress", "ARM", "SWAP", "pincushion_arm"]
	]
	for i in range(expected.size()):
		var option: Dictionary = model.options[i] if model.options.size() > i else {}
		var spec: Array = expected[i]
		_check(option.get("patch_id") == spec[0] and option.get("from_hero") == spec[1]
			and option.get("to_hero") == spec[2] and option.get("slot") == spec[3]
			and option.get("kind") == spec[4] and option.get("exchanged_id") == spec[5]
			and option.get("cost") == 1 and option.get("source_active") == true
			and option.get("destination_active") == true,
			"ordered worn source/destination slot preview " + str(i))
	var mutated := model.duplicate(true)
	mutated.options[0].patch_id = "forged"
	mutated.options.clear()
	_check(_choices(f) == model and w.get_snapshot() == snapshot_before,
		"choice arrays and nested records detach from every service and each query")
	_check(not model.options.any(func(option): return option.patch_id == "foreign"),
		"non-owned patches never become options")
	_check(picker.present(w, f.torn, start, f.rest)
		and picker.scraps_label.text == "Scraps: 3"
		and picker._source_buttons.size() == 5 and not picker.confirm_button.disabled,
		"real picker renders five source selectors and truthful purse")
	_chip_face_checks()
	var human_slots := {"HEAD": "Head patch", "ARM": "Arm patch", "COAT": "Coat patch"}
	for i in range(picker._sources.size()):
		var source: Dictionary = picker._sources[i]
		var source_slot := ""
		for option in model.options:
			if option.patch_id == source.patch_id and option.from_hero == source.from_hero:
				source_slot = option.slot
				break
		_check(human_slots.has(source_slot)
			and picker._source_buttons[i].text.contains(
				"%s / %s" % [str(source.from_hero).capitalize(), human_slots.get(source_slot, "")])
			and picker._source_buttons[i].text.contains(
				str(source.patch_id).replace("_", " ").capitalize()),
			"mounted source chip gives friendly hero, slot and patch: " + source.patch_id)
	var initial_choice := picker.selected_option()
	_check(initial_choice == picker._destinations[0]
		and picker._source_buttons[0].button_pressed
		and picker._destination_buttons[0].button_pressed,
		"initial stitched source/destination state is exact")
	picker._source_buttons[3].pressed.emit()
	var offered := []
	for option in model.options:
		if option.patch_id == picker._sources[3].patch_id:
			offered.append(option)
	_check(picker._destinations == offered and offered.size() == 2
		and picker.destination_selector.selected == -1 and picker.selected_option().is_empty()
		and picker.confirm_button.disabled and not picker._source_buttons[0].button_pressed
		and picker._source_buttons[3].button_pressed,
		"changing source rebuilds only its offered recipients and clears stale destination")
	_check(offered.size() == 2
		and offered[0].kind == "MOVE" and offered[1].kind == "SWAP"
		and picker._destination_buttons[0].text.contains("Warden / Move")
		and picker._destination_buttons[0].text.contains("empty Arm slot")
		and picker._destination_buttons[1].text.contains("Tinker / Swap")
		and picker._destination_buttons[1].text.contains("Arm patch • swap with Spare Spool")
		and not picker._destination_buttons[0].text.contains("MOVE")
		and not picker._destination_buttons[1].text.contains("SWAP"),
		"destination chips distinguish friendly Move/Swap and empty/occupied Arm slots")
	picker.re_sew_requested.connect(_owner.bind(f))
	_pick("button_eye", "tinker")
	var head_move := picker.selected_option()
	_check(head_move.get("kind") == "MOVE" and head_move.get("slot") == "HEAD"
		and head_move.get("patch_id") == "button_eye" and head_move.get("cost") == 1
		and picker._destination_buttons[picker.destination_selector.selected].text.contains(
			"Tinker / Move")
		and picker._destination_buttons[picker.destination_selector.selected].text.contains(
			"empty Head slot"),
		"HEAD move chip uses human labels but exact machine option")
	_assert_changed_slot_preview(f, "MOVE", "HEAD", "warden", "tinker",
		"button_eye", "", "", "button_eye")
	_pick("button_eye", "seamstress")
	var head_swap := picker.selected_option()
	_check(head_swap.get("kind") == "SWAP" and head_swap.get("slot") == "HEAD"
		and head_swap.get("patch_id") == "button_eye"
		and head_swap.get("from_hero") == "warden"
		and head_swap.get("to_hero") == "seamstress"
		and head_swap.get("exchanged_id") == "stitched_badge"
		and head_swap.get("cost") == 1
		and picker._destination_buttons[picker.destination_selector.selected].text.contains(
			"Seamstress / Swap")
		and picker._destination_buttons[picker.destination_selector.selected].text.contains(
			"Head patch")
		and picker._destination_buttons[picker.destination_selector.selected].text.contains(
			"swap with Stitched Badge"),
		"HEAD swap chip uses friendly labels; ledger IDs remain exact")
	_assert_changed_slot_preview(f, "SWAP", "HEAD", "warden", "seamstress",
		"button_eye", "stitched_badge", "stitched_badge", "button_eye")
	picker.confirm_button.pressed.emit()
	var first := w.get_snapshot()
	_check(f.receipts.size() == 1 and f.receipts[0].receipt.exchanged_id == "stitched_badge"
		and first.worn.warden.HEAD == "stitched_badge"
		and first.worn.seamstress.HEAD == "button_eye"
		and first.scraps == 2 and picker.scraps_label.text == "Scraps: 2",
		"HEAD swapped through UI signal, fresh operation and rerendered exact scraps")
	_pick("pincushion_arm", "warden")
	_check(picker.selected_option().get("kind") == "MOVE"
		and picker.selected_option().get("slot") == "ARM",
		"ARM move retains exact selected option and human slot")
	_assert_changed_slot_preview(f, "MOVE", "ARM", "seamstress", "warden",
		"pincushion_arm", "", "", "pincushion_arm")
	_pick("pincushion_arm", "tinker")
	_check(picker.selected_option().get("kind") == "SWAP"
		and picker.selected_option().get("exchanged_id") == "spare_spool"
		and picker.selected_option().get("cost") == 1,
		"ARM swap retains exact selected option and exchanged patch")
	_assert_changed_slot_preview(f, "SWAP", "ARM", "seamstress", "tinker",
		"pincushion_arm", "spare_spool", "spare_spool", "pincushion_arm")
	picker.confirm_button.pressed.emit()
	var second := w.get_snapshot()
	_check(f.receipts.size() == 2 and f.receipts[1].receipt.exchanged_id == "spare_spool"
		and second.worn.seamstress.ARM == "spare_spool"
		and second.worn.tinker.ARM == "pincushion_arm"
		and second.scraps == 1 and picker.scraps_label.text == "Scraps: 1",
		"ARM swapped through owner callback exactly once")
	_pick("quilted_coat", "tinker")
	_check(picker.selected_option().get("kind") == "MOVE"
		and picker.selected_option().get("patch_id") == "quilted_coat"
		and picker.selected_option().get("slot") == "COAT"
		and picker.selected_option().get("from_hero") == "warden"
		and picker.selected_option().get("to_hero") == "tinker"
		and picker.selected_option().get("exchanged_id") == ""
		and picker.selected_option().get("cost") == 1
		and picker._destination_buttons[picker.destination_selector.selected].text.contains(
			"Tinker / Move")
		and picker._destination_buttons[picker.destination_selector.selected].text.contains(
			"empty Coat slot"),
		"COAT move chip uses human labels with exact machine option")
	_assert_changed_slot_preview(f, "MOVE", "COAT", "warden", "tinker",
		"quilted_coat", "", "", "quilted_coat")
	var coat_forecast := RunRestPatchResewOptions.forecast(
		w, f.torn, w.get_snapshot(), f.rest, picker.selected_option())
	_check(coat_forecast.get("ok") == true, "live Quilted Coat projection exists")
	if coat_forecast.get("ok") == true:
		var from_before: Dictionary = coat_forecast["source"]["before"]
		var from_after: Dictionary = coat_forecast["source"]["after"]
		var to_before: Dictionary = coat_forecast["destination"]["before"]
		var to_after: Dictionary = coat_forecast["destination"]["after"]
		var live_heroes: Array = f.torn.read_state().heroes
		_check(from_before["hp"] == live_heroes[0]["hp"]
			and to_before["hp"] == live_heroes[2]["hp"]
			and from_before["hp"] == from_after["hp"]
			and to_before["hp"] == to_after["hp"]
			and from_before["base_max_hp"] == from_after["base_max_hp"]
			and to_before["base_max_hp"] == to_after["base_max_hp"]
			and from_before["effective_max_hp"] == from_after["effective_max_hp"] + 6
			and to_after["effective_max_hp"] == to_before["effective_max_hp"] + 6,
			"Coat moves exactly +6 effective cap between actual live HP; no equip healing")
	picker.confirm_button.pressed.emit()
	var after := w.get_snapshot()
	_check(f.receipts.size() == 3 and f.receipts[2].receipt.exchanged_id == ""
		and after.worn.warden.COAT == "" and after.worn.tinker.COAT == "quilted_coat"
		and after.scraps == 0 and picker.scraps_label.text == "Scraps: 0",
		"COAT moves to empty recipient and exact 3 scrap spend exhausts purse")
	_check(f.requests.size() == 3 and after.operation_ids.size() == start.operation_ids.size() + 3
		and after.operation_ids[-3] == "owner_resew_1"
		and after.operation_ids[-1] == "owner_resew_3",
		"one detached signal and one fresh operation ID per confirmed action")
	_check(after.worn == {"warden": {"HEAD": "stitched_badge", "ARM": "", "COAT": ""},
		"seamstress": {"HEAD": "button_eye", "ARM": "spare_spool", "COAT": ""},
		"tinker": {"HEAD": "", "ARM": "pincushion_arm", "COAT": "quilted_coat"}},
		"all HEAD ARM COAT assignments, including unswapped positions, are exact")
	_check(after.owned == start.owned and after.owned.size() == 5
		and after.definitions == start.definitions and after.heroes == start.heroes
		and after.gold == start.gold and after.cards == start.cards and after.seed == start.seed
		and f.torn.read_state() == original_torn and f.coats == original_coats,
		"real ledger conserves all five owned IDs, catalog, base HP/status/slots and resources")
	_check(not f.primary.is_consumed() and after.rest_id == f.rest,
		"re-sewing leaves actual RunRestRecovery and primary Upgrade/Stitch unconsumed")
	var projected := w.project_active(f.torn.read_state())
	_check(projected.ok and projected.active.warden == ["stitched_badge"]
		and projected.active.seamstress == ["button_eye", "spare_spool"]
		and projected.active.tinker == ["pincushion_arm", "quilted_coat"],
		"all three active-slot wearer projections follow the committed assignments")
	var health := RunPatchCoatRules.project_health(f.torn.read_state(), w, f.coats)
	_check(health.ok and health.heroes[0].max_hp == 40 and health.heroes[1].max_hp == 30
		and health.heroes[2].max_hp == 32 and health.heroes[2].hp == 26,
		"coat gives +6 only on latest living recipient without equipping heal")
	var detached_request: Dictionary = f.requests[0].snapshot
	detached_request.worn.warden.HEAD = "spoof"
	detached_request.owned.clear()
	_check(w.get_snapshot() == after and _choices(f).ok == false,
		"signal snapshot is detached and 0 scrap disables all choices")
	picker.re_sew_requested.disconnect(_owner.bind(f))


func _refresh(f: Dictionary, available: int) -> void:
	var w: RunPatchWardrobe = f.wardrobe
	var old := w.get_snapshot()
	var heroes: Array = f.torn.read_state().heroes
	_check(w.refresh_run_context(heroes, old.owned, available, old.gold, old.cards, old),
		"actual run owner refreshes wardrobe after changed torn/mended heroes")


func _torn_mend(f: Dictionary) -> void:
	var w: RunPatchWardrobe = f.wardrobe
	var t: RunTornMending = f.torn
	var start: Array = t.read_state().heroes
	var ending: Array = start.duplicate(true)
	ending[2].hp = 0
	_check(t.observe_battle_end("battle_tear", start, ending).ok,
		"real battle-ending observation tears Tinker once")
	_check(t.read_state().heroes[2].max_hp == 23 and t.read_state().heroes[2].hp == 0,
		"tear applies -3 base max HP and 0 HP, assignments not changed")
	var stale_wardrobe := w.get_snapshot()
	_check(not RunRestPatchResewOptions.project(w, t, stale_wardrobe, f.rest).ok
		and not RunPatchCoatRules.project_health(t.read_state(), w, f.coats).ok,
		"unrefreshed torn roster fails closed")
	_refresh(f, 0)
	var marked := w.project_active(t.read_state())
	_check(marked.ok and marked.worn.tinker.COAT == "quilted_coat"
		and marked.worn.tinker.ARM == "pincushion_arm" and marked.active.tinker == []
		and marked.active.seamstress == ["button_eye", "spare_spool"],
		"torn Tinker keeps both assignments but no powers are active")
	var caps := RunPatchCoatRules.project_health(t.read_state(), w, f.coats)
	_check(caps.ok and caps.heroes[2].max_hp == 23 and caps.heroes[2].hp == 0,
		"torn recipient cannot gain effective +6")
	var receipt := t.choose_mend("map_mend", "mend_tinker", "tinker", 3, 2,
		t.read_state().heroes, true)
	_check(receipt.ok and receipt.remaining_scraps == 0
		and receipt.heroes[2].hp == 5 and receipt.heroes[2].max_hp == 23,
		"existing 2-scrap mend revives at floor(23/4)=5")
	_refresh(f, receipt.remaining_scraps)
	var restored := w.project_active(t.read_state())
	caps = RunPatchCoatRules.project_health(t.read_state(), w, f.coats)
	_check(restored.ok and restored.active.tinker == ["pincushion_arm", "quilted_coat"]
		and caps.ok and caps.heroes[2].max_hp == 29 and caps.heroes[2].hp == 5
		and w.get_snapshot().worn == marked.worn,
		"mending reactivates same patches, only derived cap +6 without healing")


func _negative(f: Dictionary) -> void:
	var w: RunPatchWardrobe = f.wardrobe
	var t: RunTornMending = f.torn
	var zero := w.get_snapshot()
	_check(not picker.present(w, t, zero, f.rest)
		and picker.scraps_label.text == "Scraps: 0" and picker.confirm_button.disabled,
		"empty purse visibly disables picker without losing scrap information")
	_check(not _choices(f).ok and _choices(f).options.is_empty(),
		"0 scraps projects no eligible choices")
	var stale := zero.duplicate(true)
	stale.scraps = 4
	_check(not RunRestPatchResewOptions.project(w, t, stale, f.rest).ok,
		"forged snapshot cannot fabricate affordability")
	_check(not RunRestPatchResewOptions.project(w, t, zero, "other_rest").ok,
		"wrong node rejects projector")
	var f2 := _fixture(2)
	if f2.is_empty():
		return
	var w2: RunPatchWardrobe = f2.wardrobe
	var t2: RunTornMending = f2.torn
	var live := w2.get_snapshot()
	var before_t := t2.read_state()
	var expected_global: int
	var local := RandomNumberGenerator.new()
	local.seed = 752321
	var local_state := local.state
	seed(752321)
	expected_global = randi()
	seed(752321)
	var valid := RunRestPatchResewOptions.project(w2, t2, live, f2.rest)
	_check(valid.ok and valid.options.size() == 10, "affordable negative fixture genuinely has ten options")
	var forged := live.duplicate(true)
	forged.receipt = "not_a_receipt"
	_check(not RunRestPatchResewOptions.project(w2, t2, forged, f2.rest).ok,
		"forged receipt denied")
	forged = live.duplicate(true)
	forged.heroes[0].hp = 0
	_check(not RunRestPatchResewOptions.project(w2, t2, forged, f2.rest).ok,
		"forged stale run roster denied")
	forged = live.duplicate(true)
	forged.worn.warden.HEAD = "alien"
	_check(not RunRestPatchResewOptions.project(w2, t2, forged, f2.rest).ok,
		"forged worn ownership denied")
	var old := live.duplicate(true)
	old.rest_id = ""
	_check(not RunRestPatchResewOptions.project(w2, t2, old, f2.rest).ok,
		"expired previsit exact receipt is refused")
	_check(not picker.present(w2, t2, old, f2.rest)
		and picker.confirm_button.disabled, "stale visit cannot arm UI")
	_check(picker.present(w2, t2, live, f2.rest), "valid UI re-arm after prior-visit rejection")
	var baseline := w2.get_snapshot()
	for proposal in [
		["same hero", "button_eye", "warden", "warden", f2.rest],
		["non-owned", "intruder", "warden", "tinker", f2.rest],
		["wrong slot unworn", "spare_spool", "warden", "tinker", f2.rest],
		["wrong source", "button_eye", "seamstress", "tinker", f2.rest],
		["wrong rest", "button_eye", "warden", "tinker", "other_rest"],
		["unknown target", "button_eye", "warden", "visitor", f2.rest]
	]:
		var result := w2.re_sew(proposal[1], proposal[2], proposal[3],
			proposal[4], "failed_" + proposal[0], w2.get_snapshot())
		_check(not result.ok and w2.get_snapshot() == baseline,
			proposal[0] + " rejected without mutation or operation claim")
	_check(not w2.re_sew("button_eye", "warden", "tinker",
		f2.rest, "failed_stale", old).ok and w2.get_snapshot() == baseline,
		"genuine wardrobe stale exact snapshot cannot spend or claim")
	_pick("button_eye", "seamstress")
	f2.mode = "hold"
	picker.re_sew_requested.connect(_owner.bind(f2))
	picker.confirm_button.pressed.emit()
	picker.confirm_button.pressed.emit()
	_check(f2.requests.size() == 1 and picker.confirm_button.disabled
		and w2.get_snapshot() == baseline and picker.feedback_label.text.contains("Waiting"),
		"pending duplicate confirm emits one request, with no local ledger mutation")
	f2.mode = "reject"
	_check(picker.present(w2, t2, w2.get_snapshot(), f2.rest, "Owner rejected request"),
		"run owner can re-present rejection without side effects")
	_check(not picker.confirm_button.disabled and picker.scraps_label.text == "Scraps: 2",
		"acknowledged rejection re-arms fresh choices and exact scrap count")
	_check(w2.get_snapshot() == baseline and not f2.primary.is_consumed(),
		"pending/rejected visit cannot consume primary Rest action")
	var closed := w2.end_rest(f2.rest, w2.get_snapshot())
	_check(closed.ok, "real Rest exit closes wardrobe visit")
	var post := w2.get_snapshot()
	_check(not RunRestPatchResewOptions.project(w2, t2, post, f2.rest).ok
		and not picker.present(w2, t2, post, f2.rest)
		and picker.confirm_button.disabled, "closed Rest disables stale retained controls")
	_check(not w2.re_sew("button_eye", "warden", "tinker", f2.rest,
		"closed_move", post).ok and w2.get_snapshot() == post,
		"closed Rest genuine mutator cannot spend or claim IDs")
	_check(not w2.start_rest(f2.rest, w2.get_snapshot()).ok
		and w2.get_snapshot() == post, "prior visit ID cannot be replayed")
	_check(local.state == local_state and randi() == expected_global
		and t2.read_state() == before_t and not f2.primary.is_consumed(),
		"read/preview/rejected operations advance neither local/global seeded RNG nor torn/primary state")
	picker.re_sew_requested.disconnect(_owner.bind(f2))


func _torn_preview_active() -> void:
	var f := _fixture(2)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var t: RunTornMending = f.torn
	var start: Array = t.read_state().heroes
	var ending: Array = start.duplicate(true)
	ending[2].hp = 0
	_check(t.observe_battle_end("torn_preview_battle", start, ending).ok,
		"torn-indicator fixture observes actual zero-HP battle")
	_refresh(f, 2)
	var before := w.get_snapshot()
	var model := _choices(f)
	var torn_source := false
	var torn_target := false
	for entry in model.options:
		if entry.patch_id == "spare_spool" and not entry.source_active:
			torn_source = true
		if entry.to_hero == "tinker" and not entry.destination_active:
			torn_target = true
	_check(model.ok and model.options.size() == 10 and torn_source and torn_target,
		"torn wearer is still selectable as both source and target but inactive")
	_check(picker.present(w, t, before, f.rest),
		"two-scrap torn wearer still has all valid re-sew choices")
	_pick("spare_spool", "warden")
	_assert_changed_slot_preview(f, "MOVE", "ARM", "tinker", "warden",
		"spare_spool", "", "", "spare_spool")
	var source_line := picker.preview_label.text.split(String.chr(10))[1]
	_check(picker._source_buttons[picker.source_selector.selected].text.contains("torn/inactive")
		and source_line.contains("Tinker Arm patch:")
		and source_line.contains("Spare Spool (dormant; inactive power:")
		and not source_line.contains("Spare Spool (active:"),
		"torn source's moved power is explicitly dormant, never applied")
	_pick("quilted_coat", "tinker")
	_assert_changed_slot_preview(f, "MOVE", "COAT", "warden", "tinker",
		"quilted_coat", "", "", "quilted_coat")
	var torn_coat := RunRestPatchResewOptions.forecast(
		w, t, before, f.rest, picker.selected_option())
	_check(torn_coat.get("ok") == true, "torn target Coat forecast is authentic")
	if torn_coat.get("ok") == true:
		var recipient: Dictionary = torn_coat["destination"]["after"]
		var destination_line := picker.preview_label.text.split(String.chr(10))[2]
		_check(not recipient["slots"]["COAT"]["active"] and recipient["hp"] == 0
			and recipient["effective_max_hp"] == recipient["base_max_hp"]
			and recipient["base_max_hp"] == t.read_state().heroes[2].max_hp
			and destination_line.contains(
				"Quilted Coat (dormant; inactive power: +6 effective max HP (no heal))")
			and not destination_line.contains("Quilted Coat (active:"),
			"torn Tinker cannot activate Quilted Coat +6 or receive an equip heal")
	_check(w.get_snapshot() == before and t.read_state().heroes[2].hp == 0
		and picker.scraps_label.text == "Scraps: 2",
		"rendering torn and living changes never revives, reassigns or spends")



func _input_checks() -> void:
	# Controls must remain within 1280x720 and retain keyboard focus.
	var controls: Array[Control] = [picker.source_selector,
		picker.destination_selector, picker.confirm_button]
	for control in controls:
		var box := control.get_global_rect()
		_check(box.position.x >= 0 and box.position.y >= 0
			and box.end.x <= 1280 and box.end.y <= 720 and box.size.x > 0
			and box.size.y > 0,
			"1280x720 visible full control rectangle: " + control.name)
		_check(control.focus_mode == Control.FOCUS_ALL,
			"select/confirm supports keyboard focus: " + control.name)
	var f := _fixture(1)
	if f.is_empty():
		return
	_check(picker.present(f.wardrobe, f.torn, f.wardrobe.get_snapshot(), f.rest),
		"fresh UI for keyboard and mouse input checks")
	picker.source_selector.grab_focus()
	await process_frame
	_check(root.gui_get_focus_owner() == picker.source_selector,
		"keyboard focus can reach source selector")
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	_check(root.gui_get_focus_owner() != null and root.gui_get_focus_owner() != picker.source_selector,
		"keyboard Tab navigates to subsequent control")
	# Both physical click and keyboard button activation use its pressed signal.
	_pick("button_eye", "seamstress")
	var emitted := []
	picker.re_sew_requested.connect(func(p, from_id, to_id, node, snap):
		emitted.append([p, from_id, to_id, node, snap]))
	picker.confirm_button.grab_focus()
	await process_frame
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter, true)
	await process_frame
	var enter_up := InputEventKey.new()
	enter_up.keycode = KEY_ENTER
	enter_up.pressed = false
	root.push_input(enter_up, true)
	await process_frame
	_check(emitted.size() == 1 and emitted[0][0] == "button_eye"
		and emitted[0][2] == "seamstress" and f.wardrobe.get_snapshot().scraps == 1,
		"actual keyboard Enter on focused confirmation sends one detached signal only")
	_check(picker.present(f.wardrobe, f.torn, f.wardrobe.get_snapshot(), f.rest),
		"run owner can reject/re-arm before physical mouse click")
	var rect := picker.confirm_button.get_global_rect()
	var point := rect.position + rect.size / 2.0
	var mouse_down := InputEventMouseButton.new()
	mouse_down.position = point
	mouse_down.global_position = point
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	root.push_input(mouse_down, true)
	var mouse_up := InputEventMouseButton.new()
	mouse_up.position = point
	mouse_up.global_position = point
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	root.push_input(mouse_up, true)
	await process_frame
	_check(emitted.size() == 2 and f.wardrobe.get_snapshot().scraps == 1,
		"actual 1280x720 mouse click sends one request without committing ledger")
