extends SceneTree
## Deterministic checks for the sewn Shop/Rest action skin.
##
## The helper in LiveVisitCardTiles is the actual code the mounted visit calls.
## It is exercised on real Button instances and on the real ?screen=shop and
## ?screen=rest mounts, so nothing here is a parallel reimplementation. Style
## facts only: identity, labels, callbacks, overrides, ink/fill contrast and the
## reversible per-visit record. The tile faces are checked against the reward
## renderer's own art resolver, texture and presentation mode together. No
## coordinate or screenshot assertions.

const GALLERY := preload("res://scripts/live_visit_card_tiles.gd")
const REWARD := preload("res://scripts/live_run_card_reward_choice_panel.gd")
const FABRIC := "res://assets/paper/ui/reward_button.png"
const MISSING_FABRIC := "res://assets/paper/ui/absent_action_fabric.png"
const EDGE := 22
const FACE_STATES := ["normal", "hover", "pressed", "hover_pressed", "disabled"]

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
	var entered: bool = await boot.enter_preview(app, screen)
	_check(entered, "real mounted " + screen + " preview precondition")
	var view: Control = app.shop_view if screen == "shop" else app.rest_view
	var gallery = app.get_node_or_null("LiveVisitCardTiles")
	if not entered or not is_instance_valid(view):
		_check(false, screen + " preview mounts its real visit view")
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
		_check(app.shop_buy_button.text == "Buy selected card"
			and app.shop_remove_button.text == "Remove selected card",
			"Shop action labels are unchanged")
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
		_check(app.rest_heal_button.text.begins_with("Heal party")
			and app.rest_upgrade_button.text.begins_with("Upgrade selected card")
			and app.rest_stitch_button.text.begins_with("Stitch selected cards")
			and app.rest_stitch_guided_button.text.begins_with("Guided Stitch"),
			"Rest action labels are unchanged")
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
	_check_mounted_tile_art(gallery, screen)

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
