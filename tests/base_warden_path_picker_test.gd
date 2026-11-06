extends SceneTree
## Standalone view-only Warden Path offers, sourced from the shipped catalog.
const WARDEN_DATA := "res://data/heroes/warden_paths.json"
const SEAMSTRESS_DATA := "res://data/heroes/seamstress_paths.json"
const TINKER_DATA := "res://data/heroes/tinker_paths.json"
## The App's shared Theme builder and the two shipped display faces the village must wear.
const SHELL_SCRIPT := "res://scripts/patchwork_ui_shell.gd"
const TITLE_FONT := "res://assets/fonts/LondrinaSolid-Black.ttf"
const HEADING_FONT := "res://assets/fonts/LondrinaSolid-Regular.ttf"
const BODY_FONT := "res://assets/fonts/PatrickHand-Regular.ttf"
var failures: Array[String] = []
var checks := 0
var requests: Array[String] = []
var set_out_count := 0
var back_count := 0


func _initialize() -> void:
	StitchedBedroom.enabled = false
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _requested(id: String) -> void:
	requests.append(id)


func _on_set_out() -> void:
	set_out_count += 1


func _on_back() -> void:
	back_count += 1


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _click(button: Button) -> void:
	_check(button.is_visible_in_tree() and not button.disabled, "mouse action is enabled and visible")
	var point := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "mouse action is within viewport")
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


func _option(record: Dictionary) -> Dictionary:
	var card: Dictionary = record.get("card", {})
	return {"id": record.get("id", ""), "display_name": record.get("display_name", ""),
		"card_name": card.get("display_name", "")}


func _authored_options() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WARDEN_DATA))
	_check(parsed is Dictionary and parsed.get("id") == "warden",
		"shipped Warden data is a real readable hero catalog")
	if not parsed is Dictionary:
		return []
	var passive: Variant = parsed.get("base_passive", {})
	_check(passive is Dictionary and passive.get("kind") == "starting_block"
		and int(passive.get("starting_block", -1)) == 6,
		"Warden baseline is 6 opening Block")
	var paths: Variant = parsed.get("paths", [])
	_check(paths is Array, "Warden data has authored path records")
	if not paths is Array:
		return []
	var offered: Array = []
	var seen: Dictionary = {}
	for raw in paths:
		if not raw is Dictionary:
			continue
		var record: Dictionary = raw
		var id := String(record.get("id", ""))
		if id != "bulwark" and id != "vanguard":
			continue
		seen[id] = true
		var option := _option(record)
		offered.append(option)
		var preview := VillagePathPreview.warden(option)
		_check(not preview.is_empty() and preview.get("ok") == true
			and preview.get("owner") == "warden" and preview.get("path_id") == id
			and preview.get("display_name") == record.get("display_name")
			and preview.get("card_name") == option["card_name"],
			"exact shipped identity creates a Warden preview: " + id)
		var card: Dictionary = record.get("card", {})
		var card_line := String(preview.get("card_text", ""))
		var passive_line := String(preview.get("passive_text", ""))
		var tooltip := String(preview.get("tooltip", ""))
		var hint := String(preview.get("hint", ""))
		_check(card_line.contains(String(card.get("display_name", "")))
			and card_line.contains("cost %d energy" % int(card.get("cost", -1)))
			and tooltip.contains("PASSIVE: " + passive_line)
			and tooltip.contains("CARD: " + card_line)
			and hint.contains(String(card.get("display_name", ""))) and hint.contains("1 energy"),
			"Warden preview prints authored cost, named passive and card: " + id)
		if id == "bulwark":
			_check(card.get("id") == "warden_bulwark_brace"
				and card_line.contains("from positions 1-3")
				and card_line.contains("target SELF (no enemy slots)")
				and card_line.contains("9 Block")
				and passive_line.contains("6 Block") and passive_line.contains("10 Block")
				and passive_line.contains("Replaces") and passive_line.contains("does not stack")
				and hint.contains("6") and hint.contains("10") and hint.contains("9"),
				"Bulwark replaces 6 with 10; Brace costs 1, self from 1-3, +9")
		else:
			_check(card.get("id") == "warden_lance_pin"
				and card_line.contains("from position 1") and card_line.contains("target enemy 1-2")
				and card_line.contains("6 damage") and card_line.contains("Pinned")
				and passive_line.contains("first confirmed attack EACH player turn")
				and passive_line.contains("Replaces opening 6 Block")
				and passive_line.contains("DIFFERENT hero attack")
				and passive_line.contains("+5") and passive_line.contains("-25%")
				and passive_line.contains("+50%") and passive_line.contains("rounded down")
				and hint.contains("6") and hint.contains("Pinned"),
				"Vanguard's per-turn confirmed Pin and Lance Pin's exact rule")
		_check(VillagePathPreview.warden({"id": id, "display_name": option["display_name"],
			"card_name": "Wrong card"}) == {}
			and VillagePathPreview.warden({"id": id, "display_name": "Wrong Path",
				"card_name": option["card_name"]}) == {}
			and VillagePathPreview.warden({"id": "foreign_path",
				"display_name": option["display_name"], "card_name": option["card_name"]}) == {},
			"unknown or mismatched Warden tuples do not claim detailed rules")
	_check(seen.has("bulwark") and seen.has("vanguard")
		and offered.size() >= 2, "both authored Warden IDs were actually checked")
	var seam := VillagePathPreview.seamstress({"id": "bloodline",
		"display_name": "Bloodline", "card_name": "Leech Stitch"})
	var tinker := VillagePathPreview.tinker({"id": "sharpshot",
		"display_name": "Sharpshot", "card_name": "Scope"})
	_check(String(seam.get("card_text", "")).contains("target enemy 1-3")
		and String(seam.get("passive_text", "")).contains("Bleed +1")
		and String(tinker.get("card_text", "")).contains("no target")
		and String(tinker.get("passive_text", "")).contains("+3 damage"),
		"Seamstress and Tinker previews keep their prior behavior")
	return offered


func _sibling_options(records: Array) -> Array:
	var offers: Array = []
	for record in records:
		var card: Dictionary = record.get("card", {})
		offers.append({"id": record.get("id", ""),
			"display_name": record.get("display_name", ""),
			"card_name": card.get("display_name", "")})
	return offers


## The authored friendly names from all three shipped Path catalogs, keyed by ID:
## the sewn button captions must match these independently of any service.
func _authored_names() -> Dictionary:
	var names: Dictionary = {}
	for path in [SEAMSTRESS_DATA, TINKER_DATA, WARDEN_DATA]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var records: Variant = parsed
		if parsed is Dictionary:
			records = parsed.get("paths", [])
		if not records is Array:
			continue
		for raw in records:
			if raw is Dictionary:
				var record: Dictionary = raw
				names[String(record.get("id", ""))] = String(record.get("display_name", ""))
	return names


## The shipped Warden palette the bone board and slate focus ring must keep.
func _warden_palette() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WARDEN_DATA))
	if parsed is Dictionary:
		var palette: Variant = parsed.get("palette", {})
		if palette is Dictionary:
			return palette
	return {}


func _button(view: BaseScreen, id: String) -> Button:
	for button in view.warden_buttons:
		if String(button.get_meta("path_id", "")) == id:
			return button
	return null


## The real Theme the App installs under its children: the title shell duplicates
## the master Theme and adds the sewn button states and display faces.
func _shared_theme() -> Theme:
	var shell: Control = load(SHELL_SCRIPT).new()
	var shared: Theme = shell._build_theme()
	shell.free()
	return shared


func _channel_luminance(value: float) -> float:
	return value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _channel_luminance(color.r) + 0.7152 * _channel_luminance(color.g) \
		+ 0.0722 * _channel_luminance(color.b)


## WCAG-style contrast ratio between text ink and the paper it is sewn onto.
func _contrast(ink: Color, paper: Color) -> float:
	var first := _luminance(ink)
	var second := _luminance(paper)
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)


func _option_button(buttons: Array, path_id: String) -> Button:
	for button in buttons:
		if is_instance_valid(button) and String(button.get_meta("path_id", "")) == path_id:
			return button
	return null


func _preview(owner: String, option: Dictionary) -> Dictionary:
	if owner == "seamstress":
		return VillagePathPreview.seamstress(option)
	if owner == "tinker":
		return VillagePathPreview.tinker(option)
	return VillagePathPreview.warden(option)


func _overlaps_any(label: Label, buttons: Array) -> bool:
	var rect := label.get_global_rect()
	for button in buttons:
		if is_instance_valid(button) and rect.intersects(button.get_global_rect()):
			return true
	return false


## The confirmed-Path line the board must show for one authored option.
func _selected_line(option: Dictionary) -> String:
	return "Selected: %s · card %s" % [String(option["display_name"]), String(option["card_name"])]


## AC1/AC2/AC3: the real village, mounted under the App's shared Theme, keeps a
## legible display hierarchy without losing any authored hint, name or card.
func _typography_case(offered: Array) -> void:
	var shared := _shared_theme()
	if shared == null:
		_check(false, "the App's shared display Theme is available")
		return
	var shared_face := shared.get_font("font", "PatchHeadingButton") as Font
	_check(shared.get_type_variation_base("PatchTitle") == &"Label"
		and shared.get_type_variation_base("PatchHeading") == &"Label"
		and shared.get_type_variation_base("PatchHeadingButton") == &"Button"
		and (shared.get_font("font", "PatchTitle") as Font).resource_path == TITLE_FONT
		and (shared.get_font("font", "PatchHeading") as Font).resource_path == HEADING_FONT
		and shared_face != null and shared_face.resource_path == HEADING_FONT
		and ResourceLoader.exists(HEADING_FONT),
		"the App's shared Theme really authors the shipped Patch display faces, including the button face")
	var view := BaseScreen.new()
	view.theme = shared
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	view.set_out_requested.connect(_on_set_out)
	var seam_offers := _sibling_options(RunSeamstressPathChoice.new().get_paths())
	var tink_offers := _sibling_options(RunTinkerPathChoice.new().get_offers())
	_check(view.open_village(2, 5) and view.present_path_options(seam_offers)
		and view.present_tinker_path_options(tink_offers)
		and view.present_warden_path_options(offered),
		"the shared-Theme village mounts all three real Path boards")
	await process_frame
	await process_frame
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var authored_names := _authored_names()
	var palette := _warden_palette()
	_check(authored_names.size() >= 6 and not String(authored_names.get("bulwark", "")).is_empty()
		and not String(authored_names.get("vanguard", "")).is_empty()
		and not String(authored_names.get("bloodline", "")).is_empty()
		and not String(authored_names.get("unpicker", "")).is_empty()
		and not String(authored_names.get("sharpshot", "")).is_empty()
		and not String(authored_names.get("clockwork", "")).is_empty(),
		"all six authored Path friendly names are really present in the shipped catalogs")
	var palette_keys := ["bone", "slate_blue", "rust"]
	var palette_ok := true
	for key in palette_keys:
		palette_ok = palette_ok and palette.has(key) \
			and not String(palette.get(key, "")).is_empty()
	_check(palette_ok, "the shipped Warden catalog keeps its bone/slate/rust palette")
	var face_ok: Dictionary = {}
	var title := view.village_title_label
	var title_font := title.get_theme_font("font")
	var strip := view.find_child("TopStrip", true, false) as PanelContainer
	_check(title.theme_type_variation == &"PatchTitle" and title_font != null
		and title_font.resource_path == TITLE_FONT
		and title_font.resource_path == (shared.get_font("font", "PatchTitle") as Font).resource_path
		and title.get_theme_font_size("font_size") >= 40
		and title.get_theme_font_size("font_size") <= 44
		and strip != null and strip.get_global_rect().encloses(title.get_global_rect())
		and _contrast(title.get_theme_color("font_color"),
			strip.get_theme_stylebox("panel").bg_color) >= 4.5,
		"AC1: 'Quilt village' is the master Londrina Black PatchTitle at 40-44 px, dark on its paper strip")
	var boards: Array = [
		{"tag": "Seamstress", "owner": "seamstress", "panel": view.path_panel,
			"heading": "HeroesHeading", "hint": view.path_hint_label,
			"status": view.path_status_label, "buttons": view.path_buttons, "options": seam_offers},
		{"tag": "Tinker", "owner": "tinker", "panel": view.tinker_panel,
			"heading": "TinkerHeading", "hint": view.tinker_hint_label,
			"status": view.tinker_status_label, "buttons": view.tinker_buttons, "options": tink_offers},
		{"tag": "Warden", "owner": "warden", "panel": view.warden_panel,
			"heading": "WardenHeading", "hint": view.warden_hint_label,
			"status": view.warden_status_label, "buttons": view.warden_buttons, "options": offered},
	]
	for board in boards:
		var tag := String(board["tag"])
		var panel: PanelContainer = board["panel"]
		var paper: Color = panel.get_theme_stylebox("panel").bg_color
		var heading := panel.find_child(String(board["heading"]), true, false) as Label
		var heading_font: Font = heading.get_theme_font("font") if heading != null else null
		_check(heading != null and heading.theme_type_variation == &"PatchHeading"
			and heading_font != null and heading_font.resource_path == HEADING_FONT
			and heading_font.resource_path == (shared.get_font("font", "PatchHeading") as Font).resource_path
			and heading.get_theme_font_size("font_size") >= 22
			and heading.get_theme_font_size("font_size") <= 24
			and panel.get_global_rect().encloses(heading.get_global_rect()),
			"AC1: the %s board heading is the Londrina PatchHeading face at 22-24 px" % tag)
		var hint: Label = board["hint"]
		var status: Label = board["status"]
		for label: Label in [hint, status]:
			_check(label.get_theme_font_size("font_size") >= 18
				and not label.clip_text and label.autowrap_mode != TextServer.AUTOWRAP_OFF
				and (label.get_theme_font("font") as Font).resource_path == BODY_FONT
				and _contrast(label.get_theme_color("font_color"), paper) >= 4.5
				and panel.get_global_rect().encloses(label.get_global_rect()),
				"AC2: %s hint/status is dark sewn ink in the Patrick Hand body at 18 px or more" % tag)
		for option in board["options"]:
			var option_id := String(option["id"])
			var button := _option_button(board["buttons"], option_id)
			var preview := _preview(String(board["owner"]), option)
			_check(button != null and button.is_visible_in_tree() and not preview.is_empty(),
				"AC2: %s %s really offers its authored preview" % [tag, option_id])
			if button == null:
				continue
			# AC1: the sewn caption face on every authored Path option.
			var face_font := button.get_theme_font("font") as Font
			var face_size := button.get_theme_font_size("font_size")
			var text_width := INF
			if face_font != null:
				text_width = face_font.get_string_size(button.text,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, face_size).x
			var authored_name := String(authored_names.get(option_id, ""))
			var face_pass := button.theme_type_variation == &"PatchHeadingButton" \
				and face_font != null and face_font.resource_path == HEADING_FONT \
				and shared_face != null and face_font.resource_path == shared_face.resource_path \
				and face_size >= 18 \
				and not button.clip_text \
				and button.text == authored_name and button.text == String(option["display_name"]) \
				and not authored_name.is_empty() \
				and text_width <= button.size.x \
				and button.get_minimum_size().x <= button.size.x + 0.5 \
				and panel.get_global_rect().encloses(button.get_global_rect()) \
				and viewport.encloses(button.get_global_rect()) \
				and button.focus_mode == Control.FOCUS_ALL
			face_ok[option_id] = face_pass
			_check(face_pass,
				"AC1: %s %s wears the shipped Londrina Solid Regular PatchHeadingButton face at 18 px+ with its full authored name inside its board"
					% [tag, option_id])
			button.grab_focus()
			await process_frame
			await process_frame
			_check(hint.text == String(preview.get("hint", ""))
				and hint.get_line_count() >= 1
				and hint.get_visible_line_count() == hint.get_line_count()
				and panel.get_global_rect().encloses(hint.get_global_rect())
				and not _overlaps_any(hint, board["buttons"])
				and button.tooltip_text == String(preview.get("tooltip", ""))
				and button.tooltip_text.contains("PASSIVE: ")
				and button.tooltip_text.contains("CARD: "),
				"AC2: %s %s keeps its whole focused hint on the board and its full unchanged rule in the tooltip"
					% [tag, option_id])
		for button in board["buttons"]:
			var button_id := String(button.get_meta("path_id", ""))
			if board["owner"] == "warden":
				# Warden's authored bone/slate/rust contrast must survive the new face.
				var surface := button.get_theme_stylebox("normal") as StyleBoxFlat
				var focus_ring := button.get_theme_stylebox("focus") as StyleBoxFlat
				var state_inks := {"normal": "font_color", "hover": "font_hover_color",
					"pressed": "font_pressed_color", "hover_pressed": "font_hover_pressed_color",
					"disabled": "font_disabled_color"}
				var readable := true
				for state in state_inks:
					var state_surface := button.get_theme_stylebox(state) as StyleBoxFlat
					if state_surface == null:
						readable = false
						continue
					readable = readable and _contrast(button.get_theme_color(state_inks[state]),
						state_surface.bg_color) >= 4.5
				_check(button.has_theme_stylebox_override("normal") and surface != null
					and surface.bg_color == Color(String(palette.get("bone", "")))
					and surface.border_color == Color(String(palette.get("rust", "")))
					and readable
					and focus_ring != null and focus_ring.border_width_top >= 3
					and focus_ring.border_color == Color(String(palette.get("slate_blue", "")))
					and _contrast(focus_ring.border_color, surface.bg_color) >= 3.0,
					"AC2: Warden %s keeps its bone/rust surface, dark ink in every state and the slate focus ring"
						% button_id)
			else:
				var shared_surface := shared.get_stylebox("normal", "Button")
				var shared_focus := button.get_theme_stylebox("focus") as StyleBoxFlat
				_check(not button.has_theme_stylebox_override("normal")
					and button.get_theme_stylebox("normal") == shared_surface
					and shared_focus != null and shared_focus.border_width_top >= 3
					and shared_focus.border_color.a >= 0.99,
					"AC2: %s %s keeps its shared sewn surface and focus ring under the display face"
						% [tag, button_id])
		var chosen: Dictionary = board["options"][0]
		# The longest authored name/card line is the worst case for the status label.
		for option in board["options"]:
			if _selected_line(option).length() > _selected_line(chosen).length():
				chosen = option
		var chosen_id := String(chosen["id"])
		var chosen_name := String(chosen["display_name"])
		var marked := false
		if board["owner"] == "seamstress":
			marked = view.mark_path_selected(chosen_id, chosen_name)
		elif board["owner"] == "tinker":
			marked = view.mark_tinker_path_selected(chosen_id, chosen_name)
		else:
			marked = view.mark_warden_path_selected(chosen_id, chosen_name)
		await process_frame
		_check(marked and status.is_visible_in_tree()
			and status.text == _selected_line(chosen)
			and status.get_visible_line_count() == status.get_line_count()
			and panel.get_global_rect().encloses(status.get_global_rect())
			and status.get_theme_font_size("font_size") >= 18,
			"AC2: %s keeps the confirmed Path name and its card readable at 18 px" % tag)
	var required_faces := ["bulwark", "vanguard", "bloodline", "unpicker", "sharpshot", "clockwork"]
	var missing_faces: Array[String] = []
	for required in required_faces:
		if face_ok.get(required, false) != true:
			missing_faces.append(required)
	_check(missing_faces.is_empty() and face_ok.size() == required_faces.size(),
		"AC1: all six mounted Path option buttons pass the display-face check (missing: %s)"
			% str(missing_faces))
	_check(view.selected_path_id() != "" and view.selected_tinker_path_id() != ""
		and view.selected_warden_path_id() != "",
		"AC3: all three independent Path boards keep their own confirmed pick")
	_check(view.set_out_button.theme_type_variation == &"PatchHeadingButton"
		and view.set_out_button.get_theme_font_size("font_size") >= 18
		and view.find_child("SetOutButton", true, false) == view.set_out_button
		and view.set_out_button.has_focus()
		and viewport.encloses(view.set_out_button.get_global_rect()),
		"AC1: the real Set out action keeps its PatchHeadingButton face, viewport fit and keyboard focus")
	var focus_style := view.set_out_button.get_theme_stylebox("focus") as StyleBoxFlat
	_check(focus_style != null and focus_style.border_width_top >= 3
		and focus_style.border_color.a >= 0.99,
		"AC1: Set out keeps a distinct opaque sewn keyboard-focus ring")
	var set_out_before := set_out_count
	view.set_out_button.pressed.emit()
	_check(set_out_count == set_out_before + 1,
		"AC1: Set out is still the real mounted control behind its own signal")
	view.close_village()
	view.free()
	await process_frame


func _focus_loop(view: BaseScreen) -> void:
	var loop: Array[Button] = [view.back_button, view.heroes_house_button,
		view.camp_house_button, view.parts_button, view.guide_button]
	loop.append_array(view.path_buttons)
	loop.append_array(view.tinker_buttons)
	loop.append_array(view.warden_buttons)
	loop.append(view.set_out_button)
	for button in view.difficulty_buttons:
		if not button.disabled:
			loop.append(button)
	view.back_button.grab_focus()
	await process_frame
	for index in loop.size():
		_check(loop[index].has_focus(), "Tab loop visits action %d in declared order" % index)
		_check(loop[index].focus_next == loop[index].get_path_to(loop[(index + 1) % loop.size()]),
			"next focus path wraps in authored board order")
		await _key(KEY_TAB)
	_check(view.back_button.has_focus(), "Tab wraps from the last offered action to Back")


func _fresh_case(chosen: Dictionary, offered: Array, use_mouse: bool) -> void:
	requests.clear()
	set_out_count = 0
	back_count = 0
	var view := BaseScreen.new()
	root.add_child(view)
	_check(view.difficulty_buttons.all(func(button): return button.disabled),
		"unbound village offers no difficulty before the authority supplies earned tiers")
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	view.warden_path_choice_requested.connect(_requested)
	view.set_out_requested.connect(_on_set_out)
	view.back_requested.connect(_on_back)
	_check(not view.warden_panel.visible and view.warden_path_options().is_empty(),
		"Warden panel hidden until host supplies real options")
	_check(view.open_village(7, 3), "fresh village opens with no run")
	var seam_offers := _sibling_options(RunSeamstressPathChoice.new().get_paths())
	var tink_offers := _sibling_options(RunTinkerPathChoice.new().get_offers())
	_check(seam_offers.size() >= 2 and tink_offers.size() >= 2,
		"existing hero boards have genuine offered data")
	_check(view.present_path_options(seam_offers)
		and view.present_tinker_path_options(tink_offers)
		and view.present_warden_path_options(offered),
		"all three independent boards accept host-owned offers")
	await process_frame
	_check(view.warden_path_options() == offered and view.warden_buttons.size() == offered.size()
		and view.path_buttons.size() == seam_offers.size()
		and view.tinker_buttons.size() == tink_offers.size()
		and view.wallet_label.text == "Gold 7  ·  Scraps 3",
		"three boards, authored order, and wallet remain independent")
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var ward := view.warden_panel.get_global_rect()
	_check(view.warden_panel.is_visible_in_tree() and bounds.encloses(ward)
		and ward.position.x >= view.tinker_panel.get_global_rect().end.x + 24
		and ward.end.y <= view.set_out_button.get_global_rect().position.y,
		"third stitched parchment fits within village and above actions")
	for btn in view.warden_buttons:
		_check(btn.is_visible_in_tree() and not btn.disabled
			and ward.encloses(btn.get_global_rect()) and btn.get_child_count() == 1
			and btn.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE
			and btn.get_theme_font_size("font_size") >= 18,
			"each Warden option is sewn, readable and inside its own patch")
	_check(ward.encloses(view.warden_status_label.get_global_rect())
		and view.warden_status_label.get_theme_color("font_color") != view.warden_panel.get_theme_stylebox("panel").bg_color,
		"selected-card label fits and dark status ink contrasts with paper")
	await _focus_loop(view)
	view.warden_buttons[0].grab_focus()
	await process_frame
	_check(view.warden_hint_label.text == String(VillagePathPreview.warden(offered[0]).get("hint", ""))
		and view.warden_buttons[0].tooltip_text == String(VillagePathPreview.warden(offered[0]).get("tooltip", "")),
		"keyboard focus presents genuine Warden rule hint and detailed tooltip")
	view.set_out_button.grab_focus()
	await process_frame
	_check(view.warden_hint_label.text == "Choose one Warden Path for this run",
		"leaving Warden focus restores its plain prompt")
	var id := String(chosen["id"])
	var target := _button(view, id)
	_check(target != null and target.is_visible_in_tree(), "chosen Warden ID backed by offered button")
	if target == null:
		view.free()
		return
	if use_mouse:
		await _click(target)
	else:
		view.back_button.grab_focus()
		await process_frame
		for i in range(16):
			if target.has_focus():
				break
			await _key(KEY_TAB)
		_check(target.has_focus(), "physical Tab reaches Warden choice")
		await _key(KEY_SPACE)
	_check(requests == [id] and view.selected_warden_path_id().is_empty()
		and view.selected_warden_path_name().is_empty()
		and view.warden_buttons.all(func(btn: Button): return btn.disabled),
		"mouse/keyboard requests exactly once and awaits host approval")
	view._on_warden_path_pressed(id, target)
	_check(requests == [id], "pending duplicate cannot emit")
	_check(not view.mark_warden_path_selected(id, "Wrong name")
		and view.selected_warden_path_id().is_empty(), "host cannot confirm wrong offered display")
	_check(view.release_warden_path_choice() and not target.disabled
		and not view.path_buttons[0].disabled and not view.tinker_buttons[0].disabled,
		"host refusal re-enables only Warden")
	# A stale replaced button with the same ID has no authority.
	var stale := target
	_check(view.present_warden_path_options(offered), "new host offer refreshes Warden controls")
	view._on_warden_path_pressed(id, stale)
	_check(requests == [id], "stale Warden control cannot submit renewed offer")
	target = _button(view, id)
	_check(target != null and not target.disabled, "replacement offered control exists")
	if target != null:
		target.pressed.emit()
	_check(requests == [id, id] and view.selected_warden_path_id() == "",
		"only current offered control can request again")
	_check(view.mark_warden_path_selected(id, String(chosen["display_name"]))
		and view.selected_warden_path_id() == id
		and view.selected_warden_path_name() == chosen["display_name"]
		and view.warden_status_label.text.contains(String(chosen["card_name"]))
		and view.warden_buttons.all(func(btn: Button): return btn.disabled),
		"host approval sews only selected Path/card and disables both Warden options")
	_check(not view.mark_warden_path_selected(id, String(chosen["display_name"]))
		and not view.release_warden_path_choice()
		and view.selected_path_id() == "" and view.selected_tinker_path_id() == "",
		"repeat approval/refusal cannot replace confirmed Warden or other heroes")
	target.pressed.emit()
	_check(requests == [id, id], "confirmed Warden never emits again")
	view.close_village()
	view._on_warden_path_pressed(id, target)
	_check(requests == [id, id] and not view.warden_panel.visible
		and view.selected_warden_path_id().is_empty(), "closed village ignores stale requests and clears choice")
	_check(view.open_village(7, 3) and view.selected_warden_path_id() == ""
		and view.warden_panel.is_visible_in_tree() and not view.warden_buttons[0].disabled,
		"reopen restores existing offers without a run or confirmed selection")
	view._on_warden_path_pressed("unoffered", _button(view, id))
	_check(requests.size() == 2, "unoffered Warden identity cannot request")
	view.hide()
	view._on_warden_path_pressed(id, _button(view, id))
	_check(requests.size() == 2, "hidden village button cannot send")
	view.show()
	view.set_out_button.pressed.emit()
	view._on_warden_path_pressed(id, _button(view, id))
	_check(set_out_count == 1 and requests.size() == 2
		and view.release_set_out(), "Set out pending blocks Warden, then host refusal restores actions")
	view.back_button.pressed.emit()
	view._on_warden_path_pressed(id, _button(view, id))
	_check(back_count == 1 and requests.size() == 2
		and not view.release_warden_path_choice(), "Back pending blocks Warden request and refusal")
	view.close_village()
	view.free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var offered := _authored_options()
	if offered.size() >= 2:
		await _typography_case(offered)
		for option in offered:
			await _fresh_case(option, offered, String(option["id"]) == "bulwark")
	for failure in failures:
		printerr("FAIL: ", failure)
	if failures.is_empty():
		print("PASS base_warden_path_picker_test: %d checks" % checks)
	quit(0 if failures.is_empty() else 1)
