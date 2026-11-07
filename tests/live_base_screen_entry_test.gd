extends SceneTree
## Cycle 151: the pinned Quilt village base between the title and a run.
## Proves the village view refuses malformed Path data, and that the live title's
## Base opens the four-doll Stitched picker from Set out with no run allocated.

const APP_SCENE := "res://scenes/app.tscn"
const BASE_SCENE := "res://scenes/base_screen.tscn"
const SEAMSTRESS_PATHS_PATH := "res://data/heroes/seamstress_paths.json"
const TINKER_PATHS_PATH := "res://data/heroes/tinker_paths.json"
const BASE_BACKDROP := "res://assets/paper/backgrounds/base_village.png"
const PartyChoice := preload("res://tests/party_choice.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	StitchedBedroom.enabled = false
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _click(button: Button) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree(), "mouse target is mounted")
	if not is_instance_valid(button):
		return
	var point := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "mouse target inside viewport")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame


## Real pointer movement without a click and without changing focus.
func _move_mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame


func _hover(button: Button) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree(), "hover target is mounted")
	if not is_instance_valid(button):
		return
	await _move_mouse(button.get_global_rect().get_center())


func _unhover() -> void:
	await _move_mouse(Vector2(8, 8))


## Authored JSON numbers arrive as floats; a validated receipt normalizes them.
func _norm(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number:
			return int(number)
		return value
	if value is Array:
		var out_list: Array = []
		for item in value:
			out_list.append(_norm(item))
		return out_list
	if value is Dictionary:
		var out_dict: Dictionary = {}
		for key in value:
			out_dict[key] = _norm(value[key])
		return out_dict
	return value


## The exact authored Path record, read here independently of the run service.
func _authored_path(path_id: String) -> Dictionary:
	return _authored_record(SEAMSTRESS_PATHS_PATH, path_id)


## The exact authored Tinker Path record, read independently of the run service.
func _authored_tinker_path(path_id: String) -> Dictionary:
	if not FileAccess.file_exists(TINKER_PATHS_PATH):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(TINKER_PATHS_PATH)) != OK:
		return {}
	if not parser.data is Dictionary:
		return {}
	var rows: Variant = (parser.data as Dictionary).get("paths")
	if not rows is Array:
		return {}
	for record in rows:
		if record is Dictionary and String(record.get("id", "")) == path_id:
			return _norm(record)
	return {}


func _authored_record(path: String, path_id: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	if not parser.data is Array:
		return {}
	for record in parser.data:
		if record is Dictionary and String(record.get("id", "")) == path_id:
			return _norm(record)
	return {}


## The Path button for one authored ID, or null.
func _path_button(view: BaseScreen, path_id: String) -> Button:
	for button in view.path_buttons:
		if is_instance_valid(button) and String(button.get_meta("path_id", "")) == path_id:
			return button
	return null


## Everything the title state owns; opening and leaving the Base must not touch it.
func _title_snapshot(app) -> Array:
	return [app.run_seed, app.session_gold, app.run_scraps, app.run_map, app.deck, app.run_rng,
		app.stitched_run_session,
		app.run_seamstress_path_receipt.duplicate(true),
		app.run_tinker_path_receipt.duplicate(true), app.run_warden_path_receipt.duplicate(true)]


## AC1/AC2/AC4: the preview formatter prints exactly the validated authored
## records, keeps PASSIVE and CARD apart, and invents nothing it cannot verify.
func _check_preview_formatter() -> void:
	var seamstress := RunSeamstressPathChoice.new()
	_check(seamstress.is_valid() and not seamstress.is_claimed()
		and seamstress.get_paths().size() == 2,
		"the preview check starts from the genuine unclaimed Seamstress setup")
	var bloodline := VillagePathPreview.seamstress(
		{"id": "bloodline", "display_name": "Bloodline", "card_name": "Leech Stitch"})
	var unpicker := VillagePathPreview.seamstress(
		{"id": "unpicker", "display_name": "Unpicker", "card_name": "Fray"})
	var sharpshot := VillagePathPreview.tinker(
		{"id": "sharpshot", "display_name": "Sharpshot", "card_name": "Scope"})
	var clockwork := VillagePathPreview.tinker(
		{"id": "clockwork", "display_name": "Clockwork", "card_name": "Wind-up"})
	for pair in [[bloodline, "bloodline"], [unpicker, "unpicker"]]:
		var preview: Dictionary = pair[0]
		var record := _authored_path(String(pair[1]))
		var card: Dictionary = record.get("card", {})
		_check(not record.is_empty() and not preview.is_empty() and bool(preview.get("ok", false))
			and String(preview.get("display_name", "")) == String(record.get("display_name", ""))
			and String(preview.get("card_name", "")) == String(card.get("display_name", ""))
			and String(preview.get("hint", "")).contains(String(card.get("display_name", ""))),
			"a Seamstress preview matches its authored record: " + String(pair[1]))
		var tooltip := String(preview.get("tooltip", ""))
		_check(tooltip.contains("PASSIVE: ") and tooltip.contains("CARD: ")
			and tooltip.contains(String(preview.get("passive_text", "")))
			and tooltip.contains(String(preview.get("card_text", "")))
			and not String(preview.get("passive_text", "")).contains(String(card.get("display_name", "")))
			and not String(preview.get("passive_text", "")).is_empty()
			and not String(preview.get("card_text", "")).is_empty(),
			"the tooltip states the PASSIVE and CARD rules separately: " + String(pair[1]))
		var card_text := String(preview.get("card_text", ""))
		_check(card_text.contains(String(card.get("display_name", "")))
			and card_text.contains("cost %d energy" % int(card.get("cost", -1)))
			and card_text.contains("from positions 1-3")
			and card_text.contains("target enemy 1-3"),
			"the card line prints its authored cost, positions and target: " + String(pair[1]))
	_check(String(bloodline.get("passive_text", "")).contains("Bleed +1")
		and String(bloodline.get("passive_text", "")).contains("not another stack")
		and not String(bloodline.get("passive_text", "")).contains("Unravel")
		and String(bloodline.get("card_text", "")).contains("Bleed 3")
		and String(bloodline.get("card_text", "")).contains("weakest living ally")
		and String(bloodline.get("card_text", "")).contains("2 HP")
		and String(bloodline.get("card_text", "")).contains("missing HP")
		and String(bloodline.get("hint", "")).contains("Bleed +1"),
		"Bloodline previews Bleed +1 and Leech Stitch's own effect")
	_check(String(unpicker.get("passive_text", "")).contains("Replaces")
		and String(unpicker.get("passive_text", "")).contains("Bleed +1")
		and String(unpicker.get("passive_text", "")).contains("+2 Unravel")
		and String(unpicker.get("card_text", "")).contains("Unravel 4")
		and String(unpicker.get("card_text", "")).contains("Bleed 1")
		and not String(unpicker.get("passive_text", "")).contains("Bleed 3")
		and String(unpicker.get("hint", "")).contains("+2 Unravel"),
		"Unpicker previews the passive it replaces and Fray's own effect")
	for pair in [[sharpshot, "sharpshot"], [clockwork, "clockwork"]]:
		var preview: Dictionary = pair[0]
		var record := _authored_tinker_path(String(pair[1]))
		var card: Dictionary = record.get("card", {})
		var positions := "from positions 2-3" if String(pair[1]) == "clockwork" else "from position 3"
		var tooltip := String(preview.get("tooltip", ""))
		_check(not record.is_empty() and not preview.is_empty() and bool(preview.get("ok", false))
			and String(preview.get("display_name", "")) == String(record.get("display_name", ""))
			and String(preview.get("card_name", "")) == String(card.get("display_name", ""))
			and String(preview.get("hint", "")).contains(String(card.get("display_name", "")))
			and tooltip.contains("PASSIVE: ") and tooltip.contains("CARD: "),
			"a Tinker preview matches its authored record: " + String(pair[1]))
		_check(String(preview.get("card_text", "")).contains("cost %d energy" % int(card.get("cost", -1)))
			and String(preview.get("card_text", "")).contains(positions)
			and String(preview.get("card_text", "")).contains("no target"),
			"the Tinker card line prints cost, positions and no target: " + String(pair[1]))
	_check(String(sharpshot.get("passive_text", "")).contains("first attack")
		and String(sharpshot.get("passive_text", "")).contains("+3")
		and String(sharpshot.get("passive_text", "")).contains("existing passive")
		and String(sharpshot.get("card_text", "")).contains("next attack this turn")
		and String(sharpshot.get("card_text", "")).contains("+4")
		and String(sharpshot.get("hint", "")).contains("First attack +3"),
		"Sharpshot previews the first-attack +3 and Scope's +4")
	_check(String(clockwork.get("passive_text", "")).contains("printed cost 2 or more")
		and String(clockwork.get("passive_text", "")).contains("1 less")
		and not String(clockwork.get("passive_text", "")).contains("Wind-up")
		and String(clockwork.get("card_text", "")).contains("+1 energy next turn"),
		"Clockwork previews the printed-cost discount and Wind-up's energy")
	# Unknown, foreign or renamed options never acquire an invented rule.
	var refused: Array = [
		VillagePathPreview.seamstress({"id": "bloodline", "display_name": "Bloodline", "card_name": "Fray"}),
		VillagePathPreview.seamstress({"id": "bloodline", "display_name": "Unpicker", "card_name": "Leech Stitch"}),
		VillagePathPreview.seamstress({"id": "not_an_authored_path", "display_name": "Bloodline", "card_name": "Leech Stitch"}),
		VillagePathPreview.seamstress({"id": "bloodline", "display_name": "Bloodline", "card_name": ""}),
		VillagePathPreview.seamstress({"id": "", "display_name": "", "card_name": ""}),
		VillagePathPreview.tinker({"id": "sharpshot", "display_name": "Sharpshot", "card_name": "Wind-up"}),
		VillagePathPreview.tinker({"id": "bloodline", "display_name": "Bloodline", "card_name": "Leech Stitch"}),
		VillagePathPreview.seamstress({"id": "SharpShot", "display_name": "Sharpshot", "card_name": "Scope"}),
		VillagePathPreview.seamstress(null),
		VillagePathPreview.seamstress("bloodline"),
		VillagePathPreview.seamstress([{"id": "bloodline"}])]
	var invented := false
	for entry in refused:
		var result: Dictionary = entry
		invented = invented or not result.is_empty() \
			or not String(result.get("tooltip", "")).is_empty() \
			or not String(result.get("hint", "")).is_empty()
	_check(not invented, "unknown, foreign or mismatched options invent no passive or card rule")
	seed(171171)
	var expected_global := randi()
	seed(171171)
	_check(VillagePathPreview.seamstress({"id": "bloodline", "display_name": "Bloodline",
		"card_name": "Leech Stitch"}) == bloodline, "repeated previews are identical")
	_check(randi() == expected_global, "previewing spends no global RNG")
	var tinker := RunTinkerPathChoice.new()
	var offers_before: Array = tinker.get_offers()
	_check(not seamstress.is_claimed() and seamstress.get_receipt().is_empty()
		and offers_before.size() == 2 and not tinker.has_selection()
		and tinker.get_offers() == offers_before,
		"previewing claims no Path and leaves both authored choices untouched")
	bloodline["passive_text"] = "tampered"
	_check(String(VillagePathPreview.seamstress({"id": "bloodline", "display_name": "Bloodline",
		"card_name": "Leech Stitch"}).get("passive_text", "")) != "tampered",
		"each preview is detached from the returned records")


## Exercise the genuine title-mounted Base, not a detached helper or invented run.
func _check_parts_house(app, view: BaseScreen) -> void:
	var before := _title_snapshot(app)
	var tier_before: Dictionary = app.difficulty_state().duplicate(true)
	var path_before := [view.selected_path_id(), view.selected_tinker_path_id(),
		view.selected_warden_path_id()]
	var tier_caption_before: Array[String] = []
	for button in view.difficulty_buttons:
		tier_caption_before.append(button.text)
	var choices_before := [app.run_seamstress_path_choice, app.run_tinker_path_choice,
		app.run_warden_path_choice]
	var signals := [0, 0, 0, 0, 0, 0]
	view.path_choice_requested.connect(func(_id: String): signals[0] += 1)
	view.tinker_path_choice_requested.connect(func(_id: String): signals[1] += 1)
	view.warden_path_choice_requested.connect(func(_id: String): signals[2] += 1)
	view.difficulty_choice_requested.connect(func(_tier: int): signals[3] += 1)
	view.set_out_requested.connect(func(): signals[4] += 1)
	view.back_requested.connect(func(): signals[5] += 1)
	seed(388612)
	var next_global := randi()
	seed(388612)
	var house := Rect2(778, 240, 190, 150)
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(view.parts_button != null and view.parts_button.is_visible_in_tree()
		and not view.parts_button.disabled and house.encloses(view.parts_button.get_global_rect())
		and viewport.encloses(view.parts_button.get_global_rect()),
		"Parts house has a sewn action inside its actual painted house")
	for control in view.path_buttons + view.tinker_buttons + view.warden_buttons 			+ [view.back_button, view.set_out_button]:
		_check(not view.parts_button.get_global_rect().intersects(control.get_global_rect()),
			"Parts action never overlays another mounted action")
	await _click(view.parts_button)
	var guide := view.field_guide
	var inspector := guide.part_atlas
	_check(guide.is_open() and inspector != null and inspector.is_visible_in_tree(),
		"pointer opens the existing mounted Stitched inspector directly")
	if inspector == null:
		return
	_check(inspector.scene_file_path == "res://scenes/stitched_part_inspector.tscn"
		and inspector.select_part("warden_head_pot_helm_bonk")
		and inspector.select_part("scissor_crab_claw_arm"),
		"validated Warden and foe parts are selectable in the genuine inspector")
	_check(root.gui_get_focus_owner() == inspector.get_node("CloseButton"),
		"Parts entry focuses inspector Close")
	await _key(KEY_TAB)
	_check(root.gui_get_focus_owner() == inspector.get_node("CatalogPanel/SlotHead"),
		"inspector Tab traps focus away from underlying Base")
	view.set_out_button.pressed.emit()
	view.back_button.pressed.emit()
	view.path_buttons[0].pressed.emit()
	view.tinker_buttons[0].pressed.emit()
	view.warden_buttons[0].pressed.emit()
	view.difficulty_buttons[0].pressed.emit()
	view.parts_button.pressed.emit()
	view.guide_button.pressed.emit()
	_check(guide.is_open() and guide.part_atlas == inspector and app.base_screen == view
		and app.party_picker == null, "repeated and underlying actions cannot escape modal")
	await _key(KEY_ESCAPE)
	_check(guide.is_open() and not inspector.visible and inspector.selected_part_id.is_empty()
		and guide.atlas_button.has_focus(), "first Escape clears atlas and focuses guide")
	await _key(KEY_ESCAPE)
	_check(not guide.is_open() and view.parts_button.has_focus(),
		"second Escape restores exact Parts house entry")
	view.back_button.grab_focus()
	await _key(KEY_TAB)
	_check(view.heroes_house_button.has_focus(), "Tab reaches Heroes")
	await _key(KEY_TAB)
	_check(view.camp_house_button.has_focus(), "Tab reaches Camp")
	await _key(KEY_TAB)
	_check(view.parts_button.has_focus(), "Tab reaches actual Parts house")
	await _key(KEY_ENTER)
	_check(inspector.is_visible_in_tree(), "Enter opens direct parts inspector")
	await _click(inspector.get_node("CloseButton"))
	await _click(guide.close_button)
	_check(view.parts_button.has_focus(), "pointer closes restore Parts house")
	await _key(KEY_SPACE)
	_check(inspector.is_visible_in_tree(), "Space opens direct parts inspector")
	view.hide()
	_check(not guide.is_open() and not inspector.visible and inspector.selected_part_id.is_empty(),
		"hidden Base clears both modals")
	view.parts_button.pressed.emit()
	_check(not guide.is_open(), "hidden Parts callback fails closed")
	view.show()
	_check(not guide.is_open() and not view.parts_button.disabled, "show does not resurrect modal")
	for pending in ["_set_out_pending", "_back_pending", "_path_pending", "_tinker_pending", "_warden_pending"]:
		view.set(pending, true)
		view.parts_button.pressed.emit()
		_check(not guide.is_open(), "pending route rejects Parts: " + pending)
		view.set(pending, false)
	guide.catalog_paths[1] = "res://missing-parts-house-catalog.json"
	await _click(view.parts_button)
	_check(guide.is_open() and not inspector.visible and inspector.selected_part_id.is_empty()
		and inspector.part_ids_in_slot("head").is_empty()
		and guide.atlas_status.text.contains("UNAVAILABLE"),
		"invalid direct catalog opens readable failure with no stale parts")
	await _key(KEY_ESCAPE)
	_check(view.parts_button.has_focus(), "invalid route restores original Parts focus")
	guide.catalog_paths[1] = StitchedFieldGuide.FOE_PARTS
	await _click(view.guide_button)
	_check(guide.is_open() and not inspector.visible, "guide entry still opens guide alone")
	await _key(KEY_ESCAPE)
	_check(view.guide_button.has_focus(), "guide dismissal restores its own distinct entry")
	_check(_title_snapshot(app) == before and app.difficulty_state() == tier_before
		and [view.selected_path_id(), view.selected_tinker_path_id(),
			view.selected_warden_path_id()] == path_before
		and [app.run_seamstress_path_choice, app.run_tinker_path_choice,
			app.run_warden_path_choice] == choices_before,
		"parts mouse and keyboard inspection change no run, wallet, route or Paths")
	var tier_caption_after: Array[String] = []
	for button in view.difficulty_buttons:
		tier_caption_after.append(button.text)
	_check(tier_caption_after == tier_caption_before and signals == [0, 0, 0, 0, 0, 0],
		"all six Base action signals and the selected difficulty are untouched")
	_check(randi() == next_global, "parts doorway and all its input consume no global RNG")
	view.set_out_button.grab_focus()


func _check_stitched_parts_flow() -> void:
	var app = (load(APP_SCENE) as PackedScene).instantiate()
	root.add_child(app)
	await process_frame
	await _click(app.base_button)
	var view: BaseScreen = app.base_screen
	_check(view != null and view.is_visible_in_tree(), "production title mounts Base")
	if view == null:
		app.free()
		return
	await _check_parts_house(app, view)
	await _click(view.set_out_button)
	_check(is_instance_valid(app.stitched_run_panel) and app.stitched_run_panel.is_visible_in_tree()
		and app.stitched_run_draft.size() == 4 and app.stitched_run_buttons.size() == 2
		and not view.visible
		and app.run_map == null and app.run_rng == null and app.stitched_run_session == null,
		"Parts browsing leaves real four-doll Stitched Set out picker available without allocation")
	if is_instance_valid(app.stitched_run_panel):
		await _click(app.stitched_run_buttons[1])
		_check(view.is_visible_in_tree() and not view.set_out_button.disabled,
			"Stitched picker cancel restores usable village")
	app.free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load(APP_SCENE) as PackedScene
	_check(scene != null, "real app scene loads")
	var base_scene := load(BASE_SCENE) as PackedScene
	_check(base_scene != null, "real Base scene loads")
	if scene == null or base_scene == null:
		_finish()
		return
	# AC1/AC2/AC4: the formatter itself, before any scene is mounted.
	_check_preview_formatter()
	# The village itself is presentation-only: it refuses malformed host data and
	# never resolves a Path ID, authored record or deck on its own.
	var standalone := base_scene.instantiate() as BaseScreen
	root.add_child(standalone)
	await process_frame
	_check(not standalone.present_path_options("bloodline")
		and not standalone.present_path_options([{"id": "", "display_name": "Bloodline",
			"card_name": "Leech Stitch"}])
		and not standalone.present_path_options([{"id": "bloodline", "display_name": "",
			"card_name": ""}])
		and not standalone.present_path_options([{"id": "bloodline", "display_name": "Bloodline"},
			{"id": "bloodline", "display_name": "Again"}]),
		"the view refuses malformed or duplicate Path options")
	_check(not standalone.present_tinker_path_options("sharpshot")
		and not standalone.present_tinker_path_options([{"id": "", "display_name": "Sharpshot",
			"card_name": "Scope"}])
		and not standalone.present_tinker_path_options([{"id": "sharpshot", "display_name": "",
			"card_name": ""}])
		and not standalone.present_tinker_path_options([{"id": "sharpshot", "display_name": "Sharpshot"},
			{"id": "sharpshot", "display_name": "Again"}]),
		"the view refuses malformed or duplicate Tinker options")
	_check(standalone.path_buttons.is_empty() and standalone.tinker_buttons.is_empty()
		and not standalone.path_panel.visible and not standalone.tinker_panel.visible
		and not standalone.has_open_village(), "refused options build nothing on a closed village")
	_check(standalone.open_village(3, 4), "a standalone village still opens")
	# AC4: host options the formatter cannot verify keep the plain host tooltip,
	# invent no rule, and never block a later truthful preview.
	_check(standalone.present_path_options([
		{"id": "bloodline", "display_name": "Bloodline", "card_name": "Fray"},
		{"id": "not_an_authored_path", "display_name": "Stray", "card_name": "Nothing"}])
		and standalone.path_buttons.size() == 2,
		"the view still mounts host options it cannot preview")
	_check(standalone.path_buttons[0].tooltip_text == "Seamstress Path: Bloodline · card Fray"
		and standalone.path_buttons[1].tooltip_text == "Seamstress Path: Stray · card Nothing",
		"an unverifiable option keeps the plain host tooltip")
	await _hover(standalone.path_buttons[0])
	_check(standalone.path_hint_label.text == "Choose one Path for this run",
		"an unverifiable option invents no passive or card hint")
	await _unhover()
	_check(standalone.present_tinker_path_options([
		{"id": "sharpshot", "display_name": "Sharpshot", "card_name": "Wind-up"},
		{"id": "clockwork", "display_name": "Clockwork", "card_name": "Scope"}])
		and standalone.tinker_buttons.size() == 2,
		"the Tinker board mounts unverifiable host options too")
	_check(standalone.tinker_buttons[0].tooltip_text == "Tinker Path: Sharpshot · card Wind-up"
		and standalone.tinker_buttons[1].tooltip_text == "Tinker Path: Clockwork · card Scope",
		"an unverifiable Tinker option keeps the plain host tooltip")
	await _hover(standalone.tinker_buttons[0])
	_check(standalone.tinker_hint_label.text == "Choose one Tinker Path for this run",
		"an unverifiable Tinker option invents no rule")
	await _unhover()
	_check(standalone.present_path_options([
		{"id": "bloodline", "display_name": "Bloodline", "card_name": "Leech Stitch"},
		{"id": "unpicker", "display_name": "Unpicker", "card_name": "Fray"}])
		and standalone.path_buttons.size() == 2
		and standalone.path_buttons[0].text == "Bloodline"
		and standalone.path_buttons[1].text == "Unpicker"
		and standalone.selected_path_id() == "",
		"the view presents exactly the authored names it was given")
	_check(standalone.path_buttons[0].tooltip_text.contains("PASSIVE: ")
		and standalone.path_buttons[0].tooltip_text.contains("CARD: Leech Stitch")
		and standalone.path_buttons[1].tooltip_text.contains("CARD: Fray"),
		"authored options preview fully again after an unverifiable attempt")
	await _hover(standalone.path_buttons[1])
	_check(standalone.path_hint_label.text == String(VillagePathPreview.seamstress(
		{"id": "unpicker", "display_name": "Unpicker", "card_name": "Fray"}).get("hint", ""))
		and standalone.path_hint_label.text.contains("+2 Unravel"),
		"a valid option previews normally after an unverifiable one")
	await _unhover()
	_check(standalone.path_hint_label.text == "Choose one Path for this run"
		and standalone.selected_path_id() == "",
		"leaving that preview claims nothing")
	_check(standalone.mark_path_selected("bloodline", "Bloodline")
		and standalone.selected_path_id() == "bloodline"
		and standalone.path_buttons[0].disabled and standalone.path_buttons[1].disabled
		and not standalone.mark_path_selected("unpicker", "Unpicker")
		and standalone.selected_path_id() == "bloodline"
		and not standalone.release_path_choice(),
		"a confirmed Path in the view cannot be replaced or released")
	_check(standalone.present_tinker_path_options([
		{"id": "sharpshot", "display_name": "Sharpshot", "card_name": "Scope"},
		{"id": "clockwork", "display_name": "Clockwork", "card_name": "Wind-up"}])
		and standalone.tinker_buttons.size() == 2
		and standalone.tinker_buttons[0].text == "Sharpshot"
		and standalone.tinker_buttons[1].text == "Clockwork"
		and standalone.selected_tinker_path_id() == "",
		"the view presents exactly the authored Tinker names it was given")
	_check(standalone.mark_tinker_path_selected("clockwork", "Clockwork")
		and standalone.selected_tinker_path_id() == "clockwork"
		and standalone.tinker_buttons[0].disabled and standalone.tinker_buttons[1].disabled
		and not standalone.mark_tinker_path_selected("sharpshot", "Sharpshot")
		and standalone.selected_tinker_path_id() == "clockwork"
		and not standalone.release_tinker_path_choice()
		and standalone.selected_path_id() == "bloodline",
		"a confirmed Tinker Path cannot be replaced and leaves the Seamstress board alone")
	standalone.close_village()
	_check(standalone.selected_path_id() == "" and standalone.selected_tinker_path_id() == "",
		"closing the view clears both shown Paths")
	root.remove_child(standalone)
	standalone.free()
	await process_frame
	await _check_stitched_parts_flow()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_base_screen_entry_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
