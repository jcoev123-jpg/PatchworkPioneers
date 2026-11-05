extends SceneTree
const LEGACY_ENTRY := preload("res://tests/legacy_card_app_fixture.gd")
## Deterministic checks for the sewn Shop/Rest action skin.
##
## The helper in LiveVisitCardTiles is the actual code the mounted visit calls.
## It is exercised on real Button instances and on the real ?screen=shop and
## ?screen=rest mounts, so nothing here is a parallel reimplementation. Style
## facts only: identity, labels, callbacks, overrides, ink/fill contrast and the
## reversible per-visit record. The tile faces are checked against the reward
## renderer's own art resolver, texture and presentation mode together, and the
## in-face SELECTED stamp is only checked by measuring its live controls, never
## by hard-coded coordinates or screenshots.

const GALLERY := preload("res://scripts/live_visit_card_tiles.gd")
const REWARD := preload("res://scripts/live_run_card_reward_choice_panel.gd")
const FABRIC := "res://assets/paper/ui/reward_button.png"
const MISSING_FABRIC := "res://assets/paper/ui/absent_action_fabric.png"
const EDGE := 22
const FACE_STATES := ["normal", "hover", "pressed", "hover_pressed", "disabled"]
## The complete word the sewn face stamps on its canonical selected row.
const SELECTED_TEXT := "SELECTED"
## A deliberately long, wrapping probe title used only by this rendering test.
## It is never catalog data and never enters a real visit.
const LONG_PROBE_TITLE := "Counter-stitch Across the Whole Wrapping Seam of Tailor's Trance"
## A deliberately long, wrapping equipment preview used only by this rendering
## test. It is never catalog data and never enters a real visit; it stands in for
## the long authored patch preview that used to push Return below the window.
const LONG_PATCH_PREVIEW := "Switchback Button (Head slot)\nEffect: " \
	+ "Once per player turn, when a different living hero's committed card or stitched half immediately precedes this living wearer's committed card or half, this wearer gains 2 Block; same-owner repeats and rejected plays never set it up. " \
	+ "This deliberately long probe sentence is repeated so the autowrapped preview is unmistakably taller than the bounded card, exactly like the longest authored conditional patch text. " \
	+ "Once per player turn, when a different living hero's committed card or stitched half immediately precedes this living wearer's committed card or half, this wearer gains 2 Block. " \
	+ "Same-owner repeats and rejected plays never set it up, and every further line of this probe keeps wrapping inside the preview's own column. " \
	+ "The bounded card scrolls this text so the fixed action rows below it never leave the 1280x720 window. " \
	+ "Inactive while wearer is torn."
## The paper inset the stamp must keep before the sewn border, measured here
## independently from the gallery's own layout constant. The same minimum is
## required below the settled stamp's own rect, so a stamp resting on (or
## clipping through) the lower sewn hem fails instead of passing on a zero gap.
const REQUIRED_STAMP_INSET := 4.0
const REQUIRED_STAMP_BOTTOM_CLEARANCE := 4.0

var failures: Array[String] = []
var checks := 0
var _fabric_avg := Color(-1.0, -1.0, -1.0, 0.0)


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var gallery = GALLERY.new()
	gallery.name = "ActionSkinProbe"
	root.add_child(gallery)
	await process_frame
	_check_constructed_faces(gallery)
	await _check_constructed_selected_stamp(gallery)
	await _check_tile_art_modes(gallery)
	await _check_mounted_rail("shop")
	await _check_mounted_rail("rest")
	gallery.free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("live_visit_action_skin_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Four process frames, the same settling window the other mounted visit tests
## give real pointer and keyboard input.
func _frames() -> void:
	for frame in range(4):
		await process_frame


## Real keyboard input through the root viewport.
func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


## Real pointer click at the control's own centre.
func _click(control: Control) -> void:
	_check(is_instance_valid(control), "physical click requires an existing control")
	if not is_instance_valid(control):
		return
	_check(control.is_visible_in_tree() and control.size.x > 0 and control.size.y > 0
		and Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()),
		"clicked control is visible inside 1280x720")
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()



# --- real constructed Buttons ---------------------------------------------

func _check_constructed_faces(gallery) -> void:
	var sentinel := StyleBoxFlat.new()
	sentinel.bg_color = Color("#123456")
	var original_ink := Color("#f0e0c0")
	var presses := [0]
	var button := Button.new()
	button.text = "Upgrade selected card (instead of Heal)"
	button.custom_minimum_size = Vector2(480, 48)
	button.add_theme_stylebox_override("normal", sentinel)
	button.add_theme_color_override("font_color", original_ink)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(func(): presses[0] += 1)
	root.add_child(button)
	var identity := button.get_instance_id()
	var label := button.text
	var minimum := button.custom_minimum_size
	var connections := button.pressed.get_connections().size()
	var children := button.get_child_count()

	_check(gallery.apply_action_skin(button), "helper skins a real constructed action Button")
	_check(gallery.is_action_skinned(button) and gallery.action_skin_count() == 1,
		"helper keeps exactly one record for one Button")
	_check(button.get_instance_id() == identity and button.text == label
		and button.custom_minimum_size == minimum and not button.disabled,
		"skin preserves identity, exact label, minimum size and enabled state")
	_check(button.pressed.get_connections().size() == connections,
		"skin adds no pressed callback")
	_check(button.get_child_count() == children, "skin adds no visual child")
	_check(gallery.action_skin_texture_path(button) == FABRIC,
		"skin records the shipped fabric it used")
	_check(button.theme_type_variation == "PatchHeadingButton",
		"action wears the shared PatchHeadingButton variation")
	_check(button.get_theme_font_size("font_size") >= 18,
		"action label stays at a readable size")
	_check_face(button, true, "constructed action")

	button.pressed.emit()
	_check(presses[0] == 1, "the original pressed callback still fires exactly once")
	var records: int = gallery.action_skin_count()
	gallery.apply_action_skin(button)
	gallery.apply_action_skin(button)
	_check(gallery.action_skin_count() == records and gallery.is_action_skinned(button),
		"reapplying the skin reuses its one record")
	_check(button.pressed.get_connections().size() == connections
		and button.get_child_count() == children and button.text == label,
		"reapplying adds no callback, child or label change")
	button.pressed.emit()
	_check(presses[0] == 2, "repeated skinning cannot duplicate the press effect")

	gallery.restore_action_skin()
	_check(not gallery.is_action_skinned(button) and gallery.action_skin_count() == 0,
		"teardown drops every skin record")
	_check(button.has_theme_stylebox_override("normal")
		and button.get_theme_stylebox("normal") == sentinel,
		"teardown reinstates the original normal style override")
	for state in ["hover", "pressed", "hover_pressed", "disabled", "focus"]:
		_check(not button.has_theme_stylebox_override(state),
			"teardown removes the added style override: " + state)
	_check(button.has_theme_color_override("font_color")
		and button.get_theme_color("font_color") == original_ink,
		"teardown reinstates the original ink override")
	_check(not button.has_theme_color_override("font_hover_color")
		and not button.has_theme_color_override("font_disabled_color"),
		"teardown removes the added ink overrides")
	_check(button.has_theme_font_size_override("font_size")
		and button.get_theme_font_size("font_size") == 15,
		"teardown reinstates the original font size override")
	_check(button.theme_type_variation == "",
		"teardown returns the Button's own theme variation")
	button.free()

	# A genuinely disabled action must stay disabled and still get a distinct face.
	var disabled := Button.new()
	disabled.text = "Heal party (30% max HP; revive downed heroes)"
	disabled.disabled = true
	root.add_child(disabled)
	_check(gallery.apply_action_skin(disabled), "helper skins an already disabled action")
	_check(disabled.disabled, "skin never clears or sets the disabled flag")
	_check_face(disabled, true, "disabled action")
	gallery.restore_action_skin()
	_check(disabled.disabled and not disabled.has_theme_stylebox_override("disabled")
		and disabled.theme_type_variation == "",
		"restoring a disabled action leaves it disabled and unthemed")
	disabled.free()

	# Without the shipped image the helper must still sew a readable flat face.
	var fallback := Button.new()
	fallback.text = "Return to title (skip remaining removal)"
	root.add_child(fallback)
	_check(gallery.apply_action_skin(fallback, MISSING_FABRIC),
		"missing fabric still produces a usable action face")
	_check(gallery.action_skin_texture_path(fallback).is_empty(),
		"fallback records that no fabric texture was used")
	_check_face(fallback, false, "fallback action")
	gallery.restore_action_skin()
	_check(not fallback.has_theme_stylebox_override("normal"),
		"fallback skin restores the untouched Button")
	fallback.free()

	# The canonical selector is not part of the action skin.
	var option := OptionButton.new()
	option.add_item("canonical row")
	root.add_child(option)
	_check(not gallery.apply_action_skin(option),
		"helper refuses the canonical OptionButton")
	_check(not gallery.is_action_skinned(option)
		and option.theme_type_variation == ""
		and not option.has_theme_stylebox_override("normal"),
		"canonical OptionButton keeps its shared theme skin")
	option.free()


# --- the in-face SELECTED stamp (constructed faces) ------------------------

## AC1 (constructed): every sewn card face reserves a real row inside its paper
## for the complete SELECTED stamp. The label is not a child of TileName's
## wrapping row, its measured width is the full word, and both an ordinary and a
## long wrapping title keep it inside the cream paper with its own right inset.
## Hidden and selected states are both exercised; no screenshot is involved.
func _check_constructed_selected_stamp(gallery) -> void:
	var column := VBoxContainer.new()
	column.name = "SelectedStampProbe"
	column.add_theme_constant_override("separation", 6)
	column.size = Vector2(620, 460)
	root.add_child(column)
	var normal: Dictionary = gallery.build_card_face({
		"card_id": "warden_strike", "art_id": "warden_strike", "owner": "warden",
		"title": "Warden Strike", "meta": "3 gold • you have 100",
		"effects": "Deal 6."})
	var wrapped: Dictionary = gallery.build_card_face({
		"card_id": "hemorrhage_hem", "art_id": "hemorrhage_hem", "owner": "warden",
		"title": LONG_PROBE_TITLE, "meta": "3 gold • you have 100",
		"effects": "Deal 3. Bleed 2."})
	column.add_child(normal["tile"])
	column.add_child(wrapped["tile"])
	await _frames()
	var normal_marker: Label = normal["selected_label"]
	var wrapped_marker: Label = wrapped["selected_label"]
	_check(not normal_marker.visible and not wrapped_marker.visible,
		"constructed faces hide SELECTED until their canonical row is chosen")
	var normal_row: Control = normal_marker.get_parent()
	_check(normal_row != null and String(normal_row.name) == "SelectedRow"
		and normal_row.custom_minimum_size.y > 0.0,
		"constructed faces reserve a SELECTED row even while the stamp is hidden")
	_check(normal_marker.text == SELECTED_TEXT and wrapped_marker.text == SELECTED_TEXT,
		"constructed faces carry the complete SELECTED word")

	# Selected state: reveal both stamps and measure the real settled layout.
	normal_marker.visible = true
	wrapped_marker.visible = true
	await _frames()
	_check_selected_fit(normal["tile"], normal_marker, "constructed normal face")
	_check_selected_fit(wrapped["tile"], wrapped_marker, "constructed long-name face")
	var normal_size := normal_marker.size
	var normal_right := normal_marker.get_global_rect().end.x
	var wrapped_size := wrapped_marker.size
	var wrapped_right := wrapped_marker.get_global_rect().end.x
	_check(normal_size.x > 0.0 and is_equal_approx(normal_size.x, wrapped_size.x),
		"a long wrapping name does not change the SELECTED stamp's own width")
	_check(is_equal_approx(normal_right, wrapped_right),
		"a long wrapping name does not move the SELECTED stamp past its paper inset")
	_check(wrapped["title_label"].get_theme_font("font").get_string_size(
		wrapped["title_label"].text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		wrapped["title_label"].get_theme_font_size("font_size")).x
		> normal["title_label"].get_theme_font("font").get_string_size(
			normal["title_label"].text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			normal["title_label"].get_theme_font_size("font_size")).x,
		"the probe title really is wider than the ordinary name")

	# Runtime independence from TileName's own text width: retitling the same face
	# to the long probe may wrap the name but cannot resize or shift the stamp.
	var normal_title: Label = normal["title_label"]
	var original_title := normal_title.text
	normal_title.text = LONG_PROBE_TITLE
	await _frames()
	_check(normal_marker.size.is_equal_approx(normal_size)
		and is_equal_approx(normal_marker.get_global_rect().end.x, normal_right),
		"an enlarged TileName cannot resize or shift the SELECTED stamp")
	_check_selected_fit(normal["tile"], normal_marker, "constructed retitled face")
	normal_title.text = original_title
	await _frames()
	_check(normal_marker.size.is_equal_approx(normal_size),
		"restoring the name leaves the SELECTED stamp unchanged")

	# Hidden again: the stamp is gone but its reserved slot remains.
	normal_marker.visible = false
	await _frames()
	_check(not normal_marker.visible and normal_row.custom_minimum_size.y > 0.0,
		"hiding the stamp keeps its reserved in-face row")
	column.free()
	await process_frame


## AC1: the stamp's slot and display, measured on a real mounted face. Its text
## is literal and whole, it lives in its own SelectedRow inside SewnFace (never
## in TitleRow), its reserved width is at least the word's own measured width,
## it is inert, and its settled rect sits inside the cream paper with an inset
## before the sewn border.
func _check_selected_fit(panel: Control, marker: Label, label: String) -> void:
	_check(is_instance_valid(panel) and is_instance_valid(marker),
		label + " has a mounted SewnFace and SELECTED stamp")
	if not is_instance_valid(panel) or not is_instance_valid(marker):
		return
	_check(marker.text == SELECTED_TEXT,
		label + " prints the complete SELECTED word")
	_check(marker.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and marker.focus_mode == Control.FOCUS_NONE,
		label + " SELECTED stamp stays mouse and focus inert")
	var title_row := panel.find_child("TitleRow", true, false) as Control
	_check(title_row != null and not title_row.is_ancestor_of(marker),
		label + " SELECTED stamp is not inside the wrapping TitleRow")
	var row := marker.get_parent() as Control
	_check(row != null and String(row.name) == "SelectedRow"
		and panel.is_ancestor_of(marker),
		label + " SELECTED stamp owns an in-face row of SewnFace")
	var font: Font = marker.get_theme_font("font")
	var font_size: int = marker.get_theme_font_size("font_size")
	_check(font != null, label + " SELECTED stamp resolves its own face")
	if font == null:
		return
	var needed := font.get_string_size(SELECTED_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size).x
	_check(needed > 0.0 and marker.get_minimum_size().x >= needed - 1.0,
		label + " reserves the complete SELECTED text width")
	_check(marker.size.x >= marker.get_minimum_size().x - 1.0,
		label + " displays the reserved SELECTED width without squeezing")
	_check(marker.size.y >= font.get_height(font_size) - 1.0,
		label + " reserves the SELECTED line's own height without clipping")
	var paper := _paper_rect(panel)
	var stamp := marker.get_global_rect()
	_check(paper.size.x > 0.0 and paper.size.y > 0.0,
		label + " exposes its cream paper rect")
	_check(paper.grow(0.5).encloses(stamp),
		label + " SELECTED stamp sits fully inside the sewn paper")
	_check(stamp.end.x <= paper.end.x - REQUIRED_STAMP_INSET + 1.0,
		label + " SELECTED stamp keeps its inset before the sewn border")
	# A settled stamp may not rest on the lower sewn hem: the whole word keeps a
	# positive paper inset below its own rect, measured from the inner cream edge
	# the panel style defines rather than from a guessed screen coordinate.
	var bottom_clearance := paper.end.y - stamp.end.y
	_check(bottom_clearance >= REQUIRED_STAMP_BOTTOM_CLEARANCE - 0.5,
		label + " SELECTED stamp keeps a positive paper inset above the lower sewn hem ("
			+ str(snappedf(bottom_clearance, 0.01)) + " px)")
	# And that clearance is reserved by the face itself: the stamp's row is at
	# least its own measured line height plus the bottom paper inset, so the
	# clearance survives the panel being exactly as tall as its content.
	var stamp_line: float = font.get_height(font_size)
	_check(row != null and row.size.y >= stamp_line + REQUIRED_STAMP_BOTTOM_CLEARANCE - 0.5,
		label + " SELECTED row reserves the stamp's measured line height plus its bottom inset")


## The cream paper rect inside a sewn face: its own panel style's margins.
func _paper_rect(panel: Control) -> Rect2:
	var style: StyleBox = panel.get_theme_stylebox("panel")
	if style == null:
		return Rect2()
	var rect := panel.get_global_rect()
	return Rect2(rect.position + Vector2(style.get_margin(SIDE_LEFT),
			style.get_margin(SIDE_TOP)),
		rect.size - Vector2(style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT),
			style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)))



# --- sewn card art (resolver parity) --------------------------------------

## AC1/AC2: a face built by build_card_face binds the reward renderer's resolver
## result as one decision - the texture AND its presentation mode - so an authored
## picture stays a contained picture, an owner emblem gets the wide sewn-felt
## backing, and a face with no image keeps the drawn paper patch. Every branch is
## chosen from what the resolver actually loaded on this machine; no PNG is ever
## assumed to be absent and no art is added, removed or faked here.
func _check_tile_art_modes(gallery) -> void:
	# The brief's two canonical Warden faces: an authored starter and a pool card
	# that may only have the hero emblem. Both are built through the real route.
	for card_id: String in ["warden_strike", "warden_pinning_jab"]:
		var resolved: Dictionary = REWARD.resolve_card_art(card_id, "warden")
		var face: Dictionary = gallery.build_card_face({
			"card_id": card_id, "art_id": card_id, "owner": "warden",
			"title": card_id, "meta": "probe", "effects": "probe"})
		root.add_child(face["tile"])
		await process_frame
		_check_mode_parity(face["picture"], resolved, "Warden face " + card_id)
		# A disk fact, not an assumption: whichever of the two images exists now
		# decides which mode the resolver must have reported.
		if ResourceLoader.exists(REWARD.card_art_path(card_id)):
			_check(String(resolved.get("mode", ""))
				== LiveRunCardRewardChoicePanel._CardIllustration.MODE_CARD_ART,
				"Warden face " + card_id + " resolves its authored picture as card art")
		elif ResourceLoader.exists(REWARD.emblem_path("warden")):
			_check(String(resolved.get("mode", ""))
				== LiveRunCardRewardChoicePanel._CardIllustration.MODE_EMBLEM,
				"Warden face " + card_id + " falls back to the owner emblem mode")
		face["tile"].free()

	# The no-image path: an unknown card and an unknown owner resolve nothing, so
	# the face must keep the reward illustration's own drawn paper patch and its
	# readable text. The expectation still comes from the resolver, not from a
	# hard-coded "this file is missing" claim.
	var unresolved: Dictionary = REWARD.resolve_card_art("zz_synthetic_missing_art",
		"synthetic_owner")
	var drawn: Dictionary = gallery.build_card_face({
		"card_id": "zz_synthetic_missing_art", "art_id": "zz_synthetic_missing_art",
		"owner": "synthetic_owner", "title": "Synthetic probe", "meta": "probe",
		"effects": "probe"})
	root.add_child(drawn["tile"])
	await process_frame
	_check_mode_parity(drawn["picture"], unresolved, "Unresolved face")
	_check(drawn["title_label"].text == "Synthetic probe"
		and drawn["effects_label"].text == "probe",
		"an unresolved face still mounts its own readable text")
	drawn["tile"].free()


## One face's CardArt against the resolver result: the exact texture, the exact
## mode, and the mode predicate that decides how the illustration is painted.
func _check_mode_parity(picture, resolved: Dictionary, label: String) -> void:
	var expected_texture: Texture2D = resolved.get("texture") as Texture2D
	var expected_mode := String(resolved.get("mode", ""))
	_check(picture.picture == expected_texture and picture.mode == expected_mode,
		label + " binds the reward resolver's texture and mode together")
	if expected_mode == LiveRunCardRewardChoicePanel._CardIllustration.MODE_CARD_ART:
		_check(picture.is_card_art() and not picture.is_emblem()
			and not picture.is_paper_patch(),
			label + " keeps authored art as the contained card picture")
	elif expected_mode == LiveRunCardRewardChoicePanel._CardIllustration.MODE_EMBLEM:
		_check(picture.is_emblem() and not picture.is_card_art()
			and not picture.is_paper_patch(),
			label + " gives the owner emblem its wide sewn-felt backing")
	else:
		_check(picture.is_paper_patch() and not picture.has_picture()
			and not picture.is_card_art() and not picture.is_emblem(),
			label + " keeps the drawn paper patch when no image resolves")
	_check(picture.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and picture.focus_mode == Control.FOCUS_NONE,
		label + " art stays mouse and focus inert")


# --- the real mounted visit rails -----------------------------------------

func _check_mounted_rail(screen: String) -> void:
	var app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var boot = root.get_node("LiveWebPlaytestBoot")
	var entered: bool = await boot.enter_preview(LEGACY_ENTRY.prepare(app), screen)
	_check(entered, "real mounted " + screen + " preview precondition")
	var view: Control = app.shop_view if screen == "shop" else app.rest_view
	var gallery = app.get_node_or_null("LiveVisitCardTiles")
	if not entered or not is_instance_valid(view):
		_check(false, screen + " preview mounts its real visit view")
		app.free()
		await process_frame
		return
	if screen == "shop":
		await _check_peddler_rail(app)
		app.free()
		await process_frame
		return
	_check(gallery != null and gallery.is_gallery_mounted() and gallery.gallery_kind() == screen.capitalize(),
		screen + " mounts the real visit card gallery")
	if gallery == null or not gallery.is_gallery_mounted():
		app.free()
		await process_frame
		return
	var actions: Array[Button] = []
	for child in view.get_children():
		if child is Button and not (child is OptionButton):
			actions.append(child)
	_check(not actions.is_empty(), screen + " mounts a real direct action rail")
	_check(gallery.action_skin_count() == actions.size(),
		"every direct " + screen + " action Button is skinned")
	var wallet := [app.session_gold, app.run_scraps, app.run_deck.duplicate(true)]
	var snapshots: Array = []
	for button in actions:
		snapshots.append([button.get_instance_id(), button.text, button.disabled,
			button.pressed.get_connections().size()])
		_check(gallery.is_action_skinned(button),
			screen + " action keeps its skin record: " + button.text)
		_check_face(button, true, screen + " action")
	if screen == "shop":
		_check(app.shop_buy_button in actions and app.shop_remove_button in actions
			and app.shop_back_button in actions,
			"Shop Buy, Remove and Return remain the rail's own Button instances")
		_check(app.shop_buy_button.text == "Buy"
			and app.shop_remove_button.text == "Remove",
			"Shop action labels are concise")
		for button in [app.shop_buy_button, app.shop_remove_button, app.shop_back_button]:
			_check(button.pressed.get_connections().size() == 1,
				"Shop action keeps exactly its one canonical transaction callback")
		_check(not gallery.is_action_skinned(app.shop_offers)
			and app.shop_offers.get_theme_stylebox("normal") is StyleBoxEmpty,
			"masked Shop offer selector keeps the gallery mask, not the action skin")
		_check(not gallery.is_action_skinned(app.shop_patch_buy_button),
			"the nested patch row is not part of the direct action rail")
		_check(gallery.offer_tiles().size() == app.shop_offers.item_count
			and gallery.offer_tiles().all(func(tile): return not gallery.is_action_skinned(tile)),
			"Shop card gallery and its tiles are untouched by the action skin")
	else:
		_check(app.rest_heal_button in actions and app.rest_upgrade_button in actions
			and app.rest_stitch_button in actions
			and app.rest_stitch_guided_button in actions and app.rest_back_button in actions,
			"Rest Heal, Upgrade, Stitch and Return remain the rail's own Button instances")
		_check(app.rest_heal_button.text == "Heal"
			and app.rest_upgrade_button.text == "Upgrade"
			and app.rest_stitch_button.text == "Stitch (3 scraps)"
			and app.rest_stitch_guided_button.text == "Guided Stitch (3 scraps)",
			"Rest action labels are concise with exact scrap costs")
		for button in [app.rest_heal_button, app.rest_upgrade_button,
				app.rest_stitch_button, app.rest_stitch_guided_button,
				app.rest_back_button]:
			_check(button.pressed.get_connections().size() == 1,
				"Rest action keeps exactly its one canonical transaction callback")
		_check(not gallery.is_action_skinned(app.rest_upgrade_cards)
			and app.rest_upgrade_cards.get_theme_stylebox("normal") is StyleBoxEmpty,
			"masked Rest upgrade selector keeps the gallery mask, not the action skin")
		_check(gallery.upgrade_tiles().size() == app.rest_upgrade_cards.item_count
			and gallery.upgrade_tiles().all(func(tile): return not gallery.is_action_skinned(tile)),
			"Rest card gallery and its tiles are untouched by the action skin")
	_check([app.session_gold, app.run_scraps, app.run_deck] == wallet,
		screen + " inspection spends nothing and leaves the shared deck alone")
	if screen == "shop":
		await _check_bounded_shop_rail(app, gallery)
	_check_mounted_tile_art(gallery, screen)
	await _check_mounted_selected_stamps(app, gallery, screen)

	# Hiding the visit is the same live path that releases the gallery on a
	# return; its teardown must put the app's own Buttons back untouched.
	view.hide()
	await process_frame
	await process_frame
	_check(not gallery.is_gallery_mounted() and gallery.action_skin_count() == 0,
		screen + " teardown releases the action skin")
	for index in range(actions.size()):
		var button = actions[index]
		if not is_instance_valid(button):
			continue
		var snapshot: Array = snapshots[index]
		_check(button.get_instance_id() == snapshot[0] and button.text == snapshot[1]
			and button.disabled == snapshot[2],
			screen + " teardown preserves the action's identity, label and disabled state")
		_check(not button.has_theme_stylebox_override("normal")
			and not button.has_theme_stylebox_override("hover")
			and not button.has_theme_stylebox_override("focus")
			and not button.has_theme_color_override("font_color")
			and not button.has_theme_font_size_override("font_size")
			and button.theme_type_variation == "",
			screen + " teardown removes every temporary action override")
		_check(button.pressed.get_connections().size() == snapshot[3],
			screen + " teardown leaves the action's callbacks exactly as mounted")
	app.free()
	await process_frame


## AC1: the mounted Shop's left action rail is bounded to the actual window. The
## real action Buttons keep their identity and one canonical callback, and the
## one variable-height part - the autowrapped equipment card - gives up height to
## its own scroll instead of pushing Return/Continue below the 720 px view. The
## tall preview here is a probe of exactly that defect; no screenshot or
## hard-coded coordinate is involved.
func _check_bounded_shop_rail(app, gallery) -> void:
	var layout: Dictionary = gallery.action_rail_layout()
	_check(not layout.is_empty(), "mounted Shop publishes its bounded action rail")
	_check(bool(layout.get("fits", false)),
		"Shop action rail is bounded to the mounted window instead of its bare minimum height")
	_check(bool(layout.get("equipment_bounded", false)),
		"the autowrapped equipment card is the one bounded part of the Shop rail")
	_check(float(layout.get("equipment_visible_height", 0.0)) > 0.0,
		"the bounded equipment card still shows a real window onto its content")
	var actions: Array = [
		[app.shop_buy_button, "Buy"], [app.shop_remove_button, "Remove"],
		[app.peddler_leave_button, "Continue"], [app.shop_back_button, "Return"]]
	for entry in actions:
		var button = entry[0]
		var name: String = entry[1]
		_check(is_instance_valid(button) and button.is_visible_in_tree()
			and button.is_inside_tree() and app.shop_view.is_ancestor_of(button),
			"bounded rail keeps the mounted Shop action: " + name)
		_check(is_instance_valid(button) and button.pressed.get_connections().size() == 1,
			"bounded rail keeps exactly one canonical callback: " + name)
	var wallet := [app.session_gold, app.run_scraps, app.run_deck.duplicate(true)]
	var rng = app.run_rng
	var rng_state: Variant = rng.state if rng != null else null
	var preview: Label = app.shop_patch_preview
	_check(is_instance_valid(preview) and preview.is_visible_in_tree(),
		"mounted Shop keeps its real equipment preview label")
	if not is_instance_valid(preview):
		return
	var original := preview.text
	preview.text = LONG_PATCH_PREVIEW
	await _frames()
	var tall: Dictionary = gallery.action_rail_layout()
	_check(bool(tall.get("fits", false)),
		"a tall wrapping equipment preview cannot push the Shop action rail below the window")
	_check(bool(tall.get("equipment_scrolls", false)),
		"the tall preview scrolls inside its bounded card instead of being clipped or growing the rail")
	_check(float(tall.get("equipment_visible_height", 0.0)) > 0.0
		and float(tall.get("equipment_visible_height", 0.0))
			< float(tall.get("equipment_content_height", 0.0)),
		"the bounded card keeps a visible window shorter than its taller content")
	for name in ["Remove", "Continue", "Return"]:
		var button: Button = app.shop_remove_button if name == "Remove" \
			else app.peddler_leave_button if name == "Continue" else app.shop_back_button
		_check(is_instance_valid(button) and button.is_visible_in_tree()
			and not button.disabled and button.pressed.get_connections().size() == 1,
			"tall preview leaves the same enabled Shop action mounted: " + name)
	_check([app.session_gold, app.run_scraps, app.run_deck] == wallet,
		"a tall preview and the bounded rail leave the wallet and deck alone")
	if rng != null:
		_check(app.run_rng.state == rng_state, "the bounded rail draws no RNG")
	preview.text = original
	await _frames()
	var restored: Dictionary = gallery.action_rail_layout()
	_check(bool(restored.get("fits", false)) and preview.text == original,
		"restoring the authored preview keeps the Shop action rail bounded and the real text intact")


## AC1: every card tile in the real mounted gallery - Shop offers, owned-card
## removals and Rest upgrades - carries the reward resolver's own texture AND
## presentation mode for its canonical art id and owner. This runs against the
## live visit view, not a stand-in, and stays conditional on what the resolver
## loaded, so a future authored pool-card PNG still passes.
func _check_mounted_tile_art(gallery, screen: String) -> void:
	var tiles: Array = []
	tiles.append_array(gallery.offer_tiles())
	tiles.append_array(gallery.removal_tiles())
	tiles.append_array(gallery.upgrade_tiles())
	_check(not tiles.is_empty(),
		screen + " gallery mounts real card tiles for the art parity check")
	for tile in tiles:
		var details: Dictionary = gallery.tile_details(tile)
		var art_id := String(details.get("art_id", ""))
		var resolved: Dictionary = REWARD.resolve_card_art(art_id,
			String(details.get("owner", "")))
		var texture: Texture2D = resolved.get("texture") as Texture2D
		var expected_path := texture.resource_path if texture != null else ""
		var picture = tile.get_parent().find_child("CardArt", true, false)
		_check(not art_id.is_empty() and picture != null,
			screen + " tile keeps a canonical art id and its CardArt window: "
				+ String(details.get("title", "")))
		if picture == null or art_id.is_empty():
			continue
		_check_mode_parity(picture, resolved, screen + " mounted tile " + art_id)
		_check(String(details.get("art_mode", "")) == String(resolved.get("mode", ""))
			and String(details.get("art_path", "")) == expected_path
			and bool(details.get("has_picture", false)) == (texture != null),
			screen + " tile audit reports the resolver's texture and mode: " + art_id)


# --- the in-face SELECTED stamp on the real mounted visits -----------------

## AC1/AC2 (mounted): on the real 1280x720 Shop and Rest, every eligible tile is
## selected through genuine pointer or keyboard input. The complete SELECTED
## stamp then appears only on that group's canonical OptionButton row, inside the
## sewn paper; every unselected card's stamp is hidden. Clearing the canonical
## dropdown hides the group's stamps, and restoring its row brings back exactly
## that row. Selecting spends no gold or scraps and never touches the deck, and
## the original action callbacks remain the only transaction path.
func _check_mounted_selected_stamps(app, gallery, screen: String) -> void:
	var groups: Array = ["offer", "removal"] if screen == "shop" else ["upgrade"]
	var before := [app.session_gold, app.run_scraps, app.run_deck.duplicate(true)]
	var touched := 0
	for group_value in groups:
		var group := String(group_value)
		var tiles := _tiles_for(gallery, group)
		_check(not tiles.is_empty(),
			screen + " mounts " + group + " tiles for the SELECTED stamp check")
		for tile in tiles:
			if tile.disabled or not tile.is_visible_in_tree():
				continue
			if touched % 2 == 0:
				# Real pointer selection, after the same scroll a player uses.
				gallery.gallery_scroll().ensure_control_visible(tile)
				await _frames()
				await _click(tile)
			else:
				# Real keyboard selection: focus the tile, then Enter activates it.
				tile.grab_focus()
				await _frames()
				_check(tile.has_focus(), screen + " keyboard focus reaches the " + group + " tile")
				await _key(KEY_ENTER)
			touched += 1
			_check(not tile.disabled and _canonical_row(app, group) == gallery.tile_row(tile),
				screen + " real input selects exactly this " + group + " tile's canonical row")
			_check_group_stamps(app, gallery, screen, group)
			for other_value in groups:
				var other := String(other_value)
				if other != group:
					_check_group_stamps(app, gallery, screen, other)
	_check(touched > 0,
		screen + " mounted selection exercised at least one eligible tile")

	# Fail closed: with no canonical dropdown row chosen, its stamps disappear;
	# restoring the canonical row shows the stamp on that row and nowhere else.
	for group_value in groups:
		var group := String(group_value)
		var selector := _visit_selector(app, group)
		var tiles := _tiles_for(gallery, group)
		if selector == null or not is_instance_valid(selector) or tiles.is_empty():
			continue
		var previous := selector.selected
		selector.select(-1)
		await _frames()
		var hidden := true
		for tile in tiles:
			var marker := _stamp(tile)
			hidden = hidden and is_instance_valid(marker) and not marker.visible
		_check(hidden, screen + " " + group
			+ " hides every SELECTED stamp when no canonical row is chosen")
		if previous >= 0 and previous < selector.item_count:
			selector.select(previous)
			await _frames()
			var exact := true
			for tile in tiles:
				var marker := _stamp(tile)
				exact = exact and is_instance_valid(marker) \
					and marker.visible == (gallery.tile_row(tile) == previous)
			_check(exact, screen + " " + group
				+ " restores SELECTED only on canonical row " + str(previous))

	# The real mounted face carries the same guarantee as the constructed one:
	# retitling its TileName to the long wrapping probe may wrap the name at the
	# gallery's actual 1280 width, but the chosen stamp keeps its box, its paper
	# inset and its visibility. The name is restored afterwards.
	var probe_tile: Button = null
	var probe_marker: Label = null
	for group_value in groups:
		for tile in _tiles_for(gallery, String(group_value)):
			var marker := _stamp(tile)
			if is_instance_valid(marker) and marker.visible:
				probe_tile = tile
				probe_marker = marker
				break
		if probe_tile != null:
			break
	_check(probe_tile != null and probe_marker != null,
		screen + " has a chosen row for the long-name stamp probe")
	if probe_tile != null and probe_marker != null:
		var probe_name := probe_tile.get_parent().find_child("TileName", true, false) as Label
		_check(probe_name != null, screen + " chosen tile keeps its TileName label")
		if probe_name != null:
			var original_title := probe_name.text
			var stamp_box := probe_marker.size
			var stamp_right := probe_marker.get_global_rect().end.x
			probe_name.text = LONG_PROBE_TITLE
			await _frames()
			_check(probe_marker.size.is_equal_approx(stamp_box)
				and is_equal_approx(probe_marker.get_global_rect().end.x, stamp_right),
				screen + " a long wrapping mounted TileName cannot resize or shift SELECTED")
			_check_selected_fit(probe_tile.get_parent(), probe_marker,
				screen + " retitled mounted face")
			probe_name.text = original_title
			await _frames()

	_check([app.session_gold, app.run_scraps, app.run_deck] == before,
		screen + " selecting every eligible tile spends nothing and leaves the deck alone")
	var actions: Array = [app.shop_buy_button, app.shop_remove_button] if screen == "shop" \
		else [app.rest_upgrade_button]
	for button in actions:
		_check(is_instance_valid(button) and button.pressed.get_connections().size() == 1,
			screen + " selection leaves the original action's one canonical callback")


## Every stamp of one mounted group against its canonical OptionButton row.
func _check_group_stamps(app, gallery, screen: String, group: String) -> void:
	var selector := _visit_selector(app, group)
	var tiles := _tiles_for(gallery, group)
	for tile in tiles:
		var marker := _stamp(tile)
		var row: int = int(gallery.tile_row(tile))
		_check(is_instance_valid(marker) and marker.text == SELECTED_TEXT,
			screen + " " + group + " row " + str(row) + " keeps its complete SELECTED stamp")
		if not is_instance_valid(marker):
			continue
		var expected: bool = selector != null and is_instance_valid(selector) \
			and selector.selected == row
		_check(marker.visible == expected, screen + " " + group + " row " + str(row)
			+ " SELECTED visibility follows the canonical OptionButton row")
		if expected:
			_check_selected_fit(tile.get_parent(), marker,
				screen + " " + group + " row " + str(row))


## The tile's own in-face SELECTED label, or null when it has none.
func _stamp(tile: Variant) -> Label:
	if not is_instance_valid(tile):
		return null
	var panel = (tile as Control).get_parent()
	if not is_instance_valid(panel):
		return null
	return panel.find_child("TileSelected", true, false) as Label


## The selected tile Buttons of one mounted group.
func _tiles_for(gallery, group: String) -> Array:
	match group:
		"offer":
			return gallery.offer_tiles()
		"removal":
			return gallery.removal_tiles()
		"upgrade":
			return gallery.upgrade_tiles()
	return []


## The visit's canonical OptionButton for one group.
func _visit_selector(app, group: String) -> OptionButton:
	match group:
		"offer":
			return app.shop_offers
		"removal":
			return app.shop_cards
		"upgrade":
			return app.rest_upgrade_cards
	return null


## The canonical row the visit currently holds for one group, or -1.
func _canonical_row(app, group: String) -> int:
	var selector := _visit_selector(app, group)
	return selector.selected if is_instance_valid(selector) else -1



# --- shared style assertions ----------------------------------------------

func _check_face(button: Button, expect_fabric: bool, label: String) -> void:
	var texture: Texture2D = null
	for state in FACE_STATES:
		var style: StyleBox = button.get_theme_stylebox(state)
		if expect_fabric:
			_check(style is StyleBoxTexture, label + " " + state + " is a sewn texture face")
			if not (style is StyleBoxTexture):
				continue
			var sewn := style as StyleBoxTexture
			_check(sewn.texture != null and sewn.texture.resource_path == FABRIC,
				label + " " + state + " uses the shipped reward fabric")
			if texture == null:
				texture = sewn.texture
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				_check(int(sewn.get_texture_margin(side)) == EDGE,
					label + " " + state + " keeps the 22px sewn edge")
			_check(sewn.draw_center, label + " " + state + " still draws its fabric face")
			_check(sewn.get_content_margin(SIDE_LEFT) >= EDGE
				and sewn.get_content_margin(SIDE_RIGHT) >= EDGE
				and sewn.get_content_margin(SIDE_TOP) <= 8
				and sewn.get_content_margin(SIDE_BOTTOM) <= 8,
				label + " " + state + " keeps the label inside a compact sewn row")
		else:
			_check(style is StyleBoxFlat, label + " " + state + " is the stitched flat fallback")
			if not (style is StyleBoxFlat):
				continue
			var flat := style as StyleBoxFlat
			_check(flat.border_width_top >= 2 and flat.border_color.a == 1.0,
				label + " " + state + " keeps its stitched edge")
			_check(flat.get_content_margin(SIDE_LEFT) >= EDGE
				and flat.get_content_margin(SIDE_TOP) <= 8,
				label + " " + state + " keeps a compact readable label box")
	var focus: StyleBox = button.get_theme_stylebox("focus")
	_check(focus is StyleBoxFlat, label + " has a dedicated keyboard focus face")
	if focus is StyleBoxFlat:
		var ring := focus as StyleBoxFlat
		_check(ring.border_width_top >= 2 and ring.border_color.a == 1.0,
			label + " focus ring is a visible opaque stitch")
		_check(not ring.draw_center, label + " focus ring never paints over the caption")
		_check(_contrast(ring.border_color, _state_fill(button, "normal", texture)) >= 4.0,
			label + " focus ring clearly contrasts the normal face")
	var focus_ink: Color = button.get_theme_color("font_focus_color")
	_check(_luminance(focus_ink) < 0.2
		and _contrast(focus_ink, _state_fill(button, "normal", texture)) >= 4.0,
		label + " keeps dark readable ink while focused")

	var fills := {}
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := _state_fill(button, state, texture)
		fills[state] = fill
		var ink: Color = button.get_theme_color(_ink_entry(state))
		var threshold: float = 4.0 if state in ["normal", "hover"] else 3.0
		var ratio := _contrast(ink, fill)
		_check(ratio >= threshold,
			label + " " + state + " ink is readable on its fill (" + str(snappedf(ratio, 0.01)) + ")")
	_check(fills["hover"] != fills["normal"] and fills["pressed"] != fills["normal"]
		and fills["disabled"] != fills["normal"],
		label + " normal, hover, pressed and disabled faces are distinct")
	_check(_luminance(fills["hover"]) > _luminance(fills["normal"])
		and _luminance(fills["pressed"]) < _luminance(fills["normal"]),
		label + " hover brightens and pressed visibly depresses the face")
	_check(button.get_theme_color("font_disabled_color") != button.get_theme_color("font_color"),
		label + " disabled ink is distinct from normal ink")
	if expect_fabric:
		_check(texture != null, label + " resolved the fabric texture for its contrast check")


## The theme ink entry Godot resolves for one button state. The normal state is
## spelled "font_color"; the others carry their state in the entry name.
func _ink_entry(state: String) -> String:
	return "font_color" if state == "normal" else "font_" + state + "_color"


## The effective fill of one button state: the fabric average multiplied by the
## style's own tint, or the flat fallback's own colour.
func _state_fill(button: Button, state: String, texture: Texture2D) -> Color:
	var style: StyleBox = button.get_theme_stylebox(state)
	if style is StyleBoxTexture:
		var average := _fabric_average(texture)
		var tint := (style as StyleBoxTexture).modulate_color
		return Color(average.r * tint.r, average.g * tint.g, average.b * tint.b, 1.0)
	if style is StyleBoxFlat:
		var bg := (style as StyleBoxFlat).bg_color
		return Color(bg.r, bg.g, bg.b, 1.0)
	return Color.TRANSPARENT


## Deterministic average colour of the shipped fabric (alpha-bearing pixels only).
func _fabric_average(texture: Texture2D) -> Color:
	if _fabric_avg.r >= 0.0:
		return _fabric_avg
	if texture == null:
		_check(false, "action fabric texture exists for the contrast measurement")
		return Color("#c3a077")
	var image := texture.get_image()
	if image == null or image.is_empty():
		_check(false, "action fabric image is readable")
		return Color("#c3a077")
	var total := Vector3.ZERO
	var count := 0
	for y in range(0, image.get_height(), 3):
		for x in range(0, image.get_width(), 3):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.5:
				total += Vector3(pixel.r, pixel.g, pixel.b)
				count += 1
	_check(count > 0, "action fabric has painted pixels")
	if count == 0:
		return Color("#c3a077")
	_fabric_avg = Color(total.x / count, total.y / count, total.z / count, 1.0)
	return _fabric_avg


func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


func _contrast(a: Color, b: Color) -> float:
	var high := maxf(_luminance(a), _luminance(b))
	var low := minf(_luminance(a), _luminance(b))
	return (high + 0.05) / (low + 0.05)


func _check_peddler_rail(app) -> void:
	_check(app.peddler_visit != null and app.peddler_visit.is_open() and app.peddler_buttons.size() == 4,
		"real preview mounts authoritative Peddler and four short choices")
	var before: Dictionary = app._sewing_context()
	var bound: Dictionary = app.peddler_visit.read_state()
	var actions: Array = app.peddler_buttons + [app.peddler_leave_button]
	var direct: Array = []
	for child in app.shop_view.get_children():
		if child is Button and not child is OptionButton:
			direct.append(child)
	_check(direct == actions, "exactly four priced choices and Leave form the sewn rail")
	var snapshots: Array = []
	for i in range(actions.size()):
		var button: Button = actions[i]
		_check_peddler_face(button, "Peddler choice")
		_check(button.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(button.get_global_rect())
			and button.pressed.get_connections().size() == 1, "Peddler action fits viewport with one authentic callback")
		var expected := LivePeddlerPanel.LEAVE_TEXT
		if i < 4:
			var offer: Dictionary = (bound.stock.cards + bound.stock.trinkets)[i]
			expected = app.shop_view._card_caption(i) if i < 3 else app.shop_view._patch_caption()
			_check(button.get_meta("offer_id") == offer.id and button.text.contains("%d gold" % offer.price),
				"Peddler retains exact authored quote and offer identity")
		_check(button.text == expected, "Peddler short price caption stays authentic")
		snapshots.append([button.get_instance_id(), button.text, button.disabled, button.pressed.get_connections()[0].callable])
	var bed: Control = app.visit_backdrop
	_check(is_instance_valid(bed) and bed.mouse_filter == Control.MOUSE_FILTER_IGNORE and bed.focus_mode == Control.FOCUS_NONE,
		"Peddler retains inert authored backdrop")
	app.shop_view.position += Vector2(1, 1)
	await process_frame
	app.shop_view.position -= Vector2(1, 1)
	app.shop_view.hide()
	await process_frame
	app.shop_view.show()
	await process_frame
	for i in range(actions.size()):
		var button: Button = actions[i]
		_check([button.get_instance_id(), button.text, button.disabled, button.pressed.get_connections()[0].callable] == snapshots[i],
			"layout and visibility retain exact labels, affordability, identities and callbacks")
		_check_peddler_face(button, "Peddler retained choice")
	_check(app._sewing_context() == before, "presentation inspection changes no run ledger or RNG")


func _check_peddler_face(button: Button, label: String) -> void:
	# The mounted panel owns plum/teal paper faces and an authored sewn focus ring.
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		_check(style != null, label + " uses the panel's stitched flat face: " + state)
		if style != null:
			_check(style.border_width_top >= 3 and style.border_color.a == 1.0
				and style.bg_color.a == 1.0 and style.get_content_margin(SIDE_LEFT) >= 8,
				label + " retains opaque face, stitched edge and readable inset: " + state)
			var ink := button.get_theme_color("font_disabled_color" if state == "disabled" else "font_color")
			_check(_contrast(ink, style.bg_color) >= 4.0, label + " text contrasts its face: " + state)
	var focus := button.get_theme_stylebox("focus") as StyleBoxTexture
	_check(focus != null and focus.texture != null and focus.texture.resource_path == LivePeddlerPanel.BUTTON_ART
		and not focus.draw_center and focus.modulate_color == LivePeddlerPanel.GOLD,
		label + " uses the authored gold sewn keyboard ring without covering its caption")
	_check(button.focus_mode == Control.FOCUS_ALL and button.get_theme_font_size("font_size") >= 20,
		label + " remains keyboard accessible at readable size")
