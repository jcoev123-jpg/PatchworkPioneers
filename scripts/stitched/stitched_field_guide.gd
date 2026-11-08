class_name StitchedFieldGuide
extends Control
## A read-only, focus-trapped village field guide. It owns no run or RNG.

signal close_requested

const FELT := preload("res://assets/paper/ui/panel_felt.png")
const GOTHIC := preload("res://themes/gothic_theme.tres")
const PART_INSPECTOR_SCENE := preload("res://scenes/stitched_part_inspector.tscn")
const WARDEN_PARTS := "res://data/parts/warden_parts.json"
const SEAMSTRESS_PARTS := "res://data/parts/seamstress_parts.json"
const TINKER_PARTS := "res://data/parts/tinker_parts.json"
const YARN_RANGER_PARTS := "res://data/parts/yarn_ranger_parts.json"
const FOE_PARTS := "res://data/parts/enemy_parts.json"
const LANTERN_MONK_PARTS := "res://data/parts/lantern_monk_parts.json"
const BUTTON_GOLEM_PARTS := "res://data/parts/button_golem_parts.json"
const RAG_DUELIST_PARTS := "res://data/parts/rag_duelist_parts.json"
const BONE := Color("#f4e5cd")
const BRASS := Color("#e0b977")
const PAGES := [
	[
		"FRONT TO BACK  |  Four allied ranks run 1 (front) through 4 (back). Foes also occupy ranks 1–4. A fight begins with 2–3 foes; the fourth arrives only by summon or split.",
		"ROUND ORDER  |  Each round, seeded SPEED + 1d8 sets action order. Ties favour heroes, then lower ranks. Each unit gets one turn, except some bosses acting twice.",
		"FOUR SIGNATURE ABILITIES  |  Each of the eight heroes has FOUR fixed, distinct signature abilities chosen for their role, not granted by worn parts. Each has legal launch ranks, target ranks and a side: foe, ally or self.",
		"ABILITY EXAMPLES  |  Heroes may heal an ally, mark a foe, pierce ranks or guard another doll; their kits are not just generic strike and guard.",
		"WORN LIMBS  |  HEAD, ARMS, TORSO and LEGS are sewn physical body parts with cloth patches, not sources of the four active ability names.",
		"OTHER ACTIONS  |  MOVE swaps adjacent heroes; RE-TIE repairs a snipped shared thread; PASS ends the hero's turn."
	],
	[
		"RETREAT  |  A seeded non-boss RETREAT succeeds 75% of the time. Failure consumes the acting hero's turn. Success forfeits all rewards and gives EACH hero +15 Fray.",
		"SNIPPED THREAD  |  A cut blocks that doll's movement and ally healing or guarding across the cut until RE-TIE repairs the shared thread.",
		"ABILITY PATCH SOCKETS  |  Found effect patches SEW ONTO a fixed ability, not body-part stats. Each ability normally has one socket; a gold patch permits two.",
		"THREAD QUALITY  |  Rarity runs cotton < wool < silk < gold. Cotton and wool are common in fights and events; silk and gold mainly come from Elite or Boss prizes. Quality shows in thread colour, never a numeric tier.",
		"EFFECTS ON THE ACTUAL TARGET  |  Bleed, Pull, Push, Stun, Mark, Blind, stuffing steal or Chain to the next foe affect whoever the ability actually hits. A bleed-patched HEAL can bleed your own ally.",
		"ALLY PATCHES  |  Some patches fit ally heals or guards: regen, cleanse and extra guard. Unsew and resew ability patches at the Sewing Circle."
	],
	[
		"FRAY  |  Fray ranges from 0–200. Reaching 100 triggers a resolve check.",
		"STEADFAST  |  25% chance: return to 45 Fray, deal +10% damage, and reduce every party member's Fray by 2 on this hero's turns until the floor ends.",
		"UNRAVELLED  |  75% chance at 100 Fray: Unravelled lasts until Fray falls below 50.",
		"COMING APART  |  At 200 Fray, the hero Comes Apart: HP becomes 0 and Fray becomes 150. If already Hanging by a Thread, that hero is LOST.",
		"HANGING BY A THREAD  |  At 0 HP the doll stays in its rank and can still act. Reaching 0 HP does not itself tear off a limb.",
		"FURTHER DIRECT HITS  |  EACH further direct hit while at 0 HP tears off one seeded random remaining ARM, LEG or HEAD. Head chance is small on the first further hit, larger on the second and CERTAIN on the third. Losing the HEAD means LOST.",
		"TORN LIMBS  |  A lost arm weakens strikes and disables that arm's patched ability. A lost leg prevents rank changes and delays turns.",
		"RECOVERY  |  Tears persist through corridor Walk and later fights. Healing above 0 resets the further-hit count but never regrows a limb. Mend at the Sewing Circle or Campfire; replace LOST dolls from available heroes at the Sewing Circle."
	],
	[
		"CANDLE  |  Begins at 100. Each entered routed stop in the CORRIDOR costs 8 Candle, down to 0. Visits happen in the corridor, not on a separate map screen.",
		"BRIGHT 76–100  |  15% chance the party acts first; no penalty.",
		"DIM 51–75  |  +10% Fray gain; +25% loot.",
		"GLOOM 26–50  |  +20% Fray gain; foes gain +5 ACC and +10% damage; +50% loot.",
		"DARK 1–25  |  +30% Fray gain; foes gain +10 ACC and +15% damage; +75% loot.",
		"SNUFFED 0  |  +40% Fray gain; foes gain +25% damage; 25% chance foes act first; +100% loot.",
		"LOOT  |  Candle multipliers modify loot if awarded; they do not guarantee a drop.",
		"CAMPFIRE  |  Choose ONE: Mend heals 30% HP each; Tell Tales reduces Fray by 25 each; Trim Wick restores 50 Candle. A Peddler candle stub restores 25 Candle.",
		"SATCHEL  |  Hold up to six spare parts. Sew worn HEAD, ARMS, TORSO and LEGS at a Campfire or Sewing Circle, not in a fight.",
		"SIDE DOORS  |  After Elite or Boss fights, an optional door MAY appear. The under-bed door offers a silk/gold ability patch or Wren gift at a cost: limb, stuffing/max HP or Wren fear. The attic door may bless with mend all, steady candle or guard the head; ANY under-bed deal closes attic blessings for the rest of this run."
	]
]
const TABS := ["Ranks & turns", "Seams & retreat", "Fray & resolve", "Candle & stops"]
## The Seams & retreat page also carries the two freshly derived S14 patch examples.
const LESSON_PAGE := 1

var tab_buttons: Array[Button] = []
var page_labels: Array[Label] = []
var page_scroll: ScrollContainer
var close_button: Button
var atlas_button: Button
var atlas_status: Label
var part_atlas: StitchedPartInspector
# Fixed live sources. The mounted regression can replace one with a missing path
# to prove that a partial catalog never leaves stale or selectable parts.
var catalog_paths: Array[String] = [WARDEN_PARTS, SEAMSTRESS_PARTS, TINKER_PARTS,
	YARN_RANGER_PARTS, FOE_PARTS, LANTERN_MONK_PARTS, BUTTON_GOLEM_PARTS,
	RAG_DUELIST_PARTS]
# Detached lesson sources for headless regression; null reads the live S14 catalogs.
var lesson_kits: Variant = null
var lesson_patches: Variant = null
var page_index := 0
var _active := false
# Button-down edges only; retain across hide/reopen to reject held/stale input.
var _held_gamepad_buttons: Dictionary = {}
const GUIDE_GAMEPAD_BUTTONS := [
	JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
	JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_B,
]


func _ready() -> void:
	name = "StitchedFieldGuide"
	# Live play inherits App's Gothic theme; a local Theme would break the shared
	# downstream-control theme inheritance contract.
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_view()
	visibility_changed.connect(_on_visibility_changed)
	hide()


func is_open() -> bool:
	return _active


func open_guide() -> bool:
	if _active or not is_inside_tree() or not get_parent().is_visible_in_tree():
		return false
	_active = true
	_refresh_lesson_page()
	show()
	select_page(0)
	tab_buttons[0].grab_focus()
	return true


## Rebuild only the Seams & retreat page from its fixed authored baseline plus the
## two freshly derived patch examples. Resetting to the baseline first means repeated
## open/close can never duplicate a lesson, and an invalid catalog leaves no stale line.
func _refresh_lesson_page() -> void:
	if page_labels.size() <= LESSON_PAGE:
		return
	var lines: Array = PAGES[LESSON_PAGE].duplicate()
	var lesson := StitchedPatchLesson.examples(lesson_kits, lesson_patches)
	if lesson.size() == 2:
		lines.append_array(lesson)
	page_labels[LESSON_PAGE].text = "\n\n".join(lines)


func dismiss() -> void:
	_close_part_atlas(false)
	_active = false
	hide()


func select_page(index: int) -> void:
	if not _active or index < 0 or index >= page_labels.size():
		return
	page_index = index
	page_scroll.scroll_vertical = 0
	for i in range(page_labels.size()):
		page_labels[i].visible = i == index
		tab_buttons[i].button_pressed = i == index


func page_text(index: int) -> String:
	if index < 0 or index >= page_labels.size():
		return ""
	return page_labels[index].text


func _request_close() -> void:
	if _active:
		close_requested.emit()


func _input(event: InputEvent) -> void:
	# Keep button-down edge state even while hidden. A held/repeated input
	# cannot become a fresh page turn or B when reopening the modal.
	if event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if GUIDE_GAMEPAD_BUTTONS.has(joy.button_index):
			if not joy.pressed:
				_held_gamepad_buttons.erase(joy.button_index)
				return
			if _held_gamepad_buttons.has(joy.button_index):
				if _active and is_visible_in_tree():
					get_viewport().set_input_as_handled()
				return
			_held_gamepad_buttons[joy.button_index] = true
	if not _active or not is_visible_in_tree():
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			# Key echoes are not fresh page turns; block repeated GUI arrows.
			if not _atlas_is_open() and (event.is_action("ui_left") or event.is_action("ui_right")):
				get_viewport().set_input_as_handled()
			return
		if key_event.keycode == KEY_TAB and _atlas_is_open():
			get_viewport().set_input_as_handled()
			_cycle_atlas_focus(key_event.shift_pressed)
			return
		if key_event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _atlas_is_open():
				_close_part_atlas(true)
			else:
				_request_close()
			return
	elif event is InputEventJoypadButton:
		var button := (event as InputEventJoypadButton).button_index
		if button == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			if _atlas_is_open():
				_close_part_atlas(true)
			else:
				_request_close()
			return
		if button == JOY_BUTTON_DPAD_UP or button == JOY_BUTTON_DPAD_DOWN:
			# Vertical focus stays in the inspector's existing enabled ring.
			get_viewport().set_input_as_handled()
			if _atlas_is_open():
				_cycle_atlas_focus(button == JOY_BUTTON_DPAD_UP)
			return
		if _atlas_is_open():
			if button in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
					JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
				get_viewport().set_input_as_handled()
			return
	else:
		return
	# The nested atlas never turns a guide page.
	if _atlas_is_open():
		return
	var direction := 0
	if event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_RIGHT_SHOULDER:
				direction = 1
			JOY_BUTTON_LEFT_SHOULDER:
				direction = -1
	if direction == 0:
		if event.is_action_pressed("ui_right"):
			direction = 1
		elif event.is_action_pressed("ui_left"):
			direction = -1
	if direction != 0:
		get_viewport().set_input_as_handled()
		select_page(posmod(page_index + direction, tab_buttons.size()))
		tab_buttons[page_index].grab_focus()

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_close_part_atlas(false)
		_active = false


## This is an atlas, not a satchel: every configured real file catalog must validate in
## full before the existing inspector receives any entries. No gameplay API is
## referenced, and reopening always reloads the authored sources.
func open_part_atlas() -> bool:
	if not _active or not is_inside_tree() or not is_visible_in_tree() or _atlas_is_open():
		return false
	var entries: Array = []
	for path in catalog_paths:
		var result := StitchedParts.load_catalog(path)
		if not bool(result.get("ok", false)):
			_reject_part_atlas()
			return false
		entries.append_array(result["parts"])
	if entries.is_empty():
		_reject_part_atlas()
		return false
	if not is_instance_valid(part_atlas):
		part_atlas = PART_INSPECTOR_SCENE.instantiate() as StitchedPartInspector
		if part_atlas == null:
			_reject_part_atlas()
			return false
		part_atlas.name = "PartAtlasInspector"
		part_atlas.hide()
		add_child(part_atlas)
		part_atlas.close_requested.connect(_on_part_atlas_close_requested)
		var rows := part_atlas.get_node("CatalogPanel/PartScroll/PartRows")
		rows.child_entered_tree.connect(_on_atlas_rows_changed)
		rows.child_exiting_tree.connect(_on_atlas_rows_changed)
	if not part_atlas.present_parts(entries):
		_reject_part_atlas()
		return false
	(part_atlas.get_node("Subtitle") as Label).text = (
		"REFERENCE ONLY  •  Doll makers & spoils; cloth reference, no equips.")
	part_atlas.show()
	atlas_status.text = "REFERENCE ONLY  •  Inspect sewn limbs and cloth patches; no changes to your party."
	_wire_atlas_focus()
	(part_atlas.get_node("CloseButton") as Button).grab_focus()
	return true


func _atlas_is_open() -> bool:
	return is_instance_valid(part_atlas) and part_atlas.visible


func _reject_part_atlas() -> void:
	_close_part_atlas(false)
	atlas_status.text = "PARTS & SPOILS UNAVAILABLE  •  Catalog validation failed; no parts displayed."


func _on_part_atlas_close_requested() -> void:
	_close_part_atlas(true)


func _close_part_atlas(restore_focus: bool) -> void:
	if is_instance_valid(part_atlas):
		part_atlas.hide()
		# A previous successful readout must never survive hide or a bad reload.
		part_atlas.present_parts([])
	if restore_focus and _active and is_visible_in_tree():
		atlas_button.grab_focus()


func _on_atlas_rows_changed(_node: Node) -> void:
	# Inspector rebuilds its rows on slot/part selection. Re-link the newly
	# generated controls after its old, queued-for-deletion rows are gone.
	_wire_atlas_focus.call_deferred()


func _atlas_focus_buttons() -> Array[Button]:
	var ring: Array[Button] = []
	if not _atlas_is_open():
		return ring
	for path in ["CloseButton", "CatalogPanel/OwnerFilter", "CatalogPanel/SlotHead", "CatalogPanel/SlotArms",
			"CatalogPanel/SlotTorso", "CatalogPanel/SlotLegs"]:
		var button := part_atlas.get_node(path) as Button
		if not button.disabled:
			ring.append(button)
	for child in part_atlas.get_node("CatalogPanel/PartScroll/PartRows").get_children():
		if child is Button and not child.is_queued_for_deletion() and not child.disabled:
			ring.append(child as Button)
	for path in ["DetailsPanel/TierI", "DetailsPanel/TierII", "DetailsPanel/TierIII"]:
		var button := part_atlas.get_node(path) as Button
		if not button.disabled:
			ring.append(button)
	return ring


func _wire_atlas_focus() -> void:
	var ring := _atlas_focus_buttons()
	for i in range(ring.size()):
		ring[i].focus_next = ring[i].get_path_to(ring[(i + 1) % ring.size()])
		ring[i].focus_previous = ring[i].get_path_to(ring[(i - 1 + ring.size()) % ring.size()])


func _cycle_atlas_focus(backwards: bool) -> void:
	_wire_atlas_focus()
	var ring := _atlas_focus_buttons()
	if ring.is_empty():
		return
	var current := ring.find(get_viewport().gui_get_focus_owner())
	var next := 0 if current < 0 else (current + (-1 if backwards else 1) + ring.size()) % ring.size()
	ring[next].grab_focus()


func _build_view() -> void:
	# Both surfaces use the supplied felt image; no paint/StyleBoxFlat/draw calls.
	var veil := TextureRect.new()
	veil.name = "FeltVeil"
	veil.texture = FELT
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.modulate = Color(0.12, 0.08, 0.10, 0.92)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)

	var felt := NinePatchRect.new()
	felt.name = "FeltPanel"
	felt.texture = FELT
	felt.patch_margin_left = 90
	felt.patch_margin_top = 90
	felt.patch_margin_right = 90
	felt.patch_margin_bottom = 90
	felt.anchor_left = 0.5
	felt.anchor_top = 0.5
	felt.anchor_right = 0.5
	felt.anchor_bottom = 0.5
	felt.offset_left = -570
	felt.offset_top = -313
	felt.offset_right = 570
	felt.offset_bottom = 313
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(felt)

	var content := VBoxContainer.new()
	content.name = "GuideContent"
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	content.offset_left = 104
	content.offset_top = 82
	content.offset_right = -104
	content.offset_bottom = -80
	content.add_theme_constant_override("separation", 12)
	felt.add_child(content)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	content.add_child(heading)
	var title := Label.new()
	title.name = "GuideHeading"
	title.text = "THE STITCHED  •  FIELD NOTES"
	title.theme_type_variation = &"PatchHeading"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(title)
	close_button = Button.new()
	close_button.name = "CloseGuideButton"
	close_button.text = "Close  [Esc]"
	close_button.custom_minimum_size = Vector2(152, 46)
	close_button.add_theme_font_size_override("font_size", 19)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.pressed.connect(_request_close)
	heading.add_child(close_button)
	atlas_button = Button.new()
	atlas_button.name = "PartAtlasButton"
	atlas_button.text = "Parts & spoils"
	atlas_button.tooltip_text = "Reference only: examine doll makers and foe spoils; no equips"
	atlas_button.custom_minimum_size = Vector2(190, 46)
	atlas_button.add_theme_font_size_override("font_size", 19)
	atlas_button.focus_mode = Control.FOCUS_ALL
	atlas_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	atlas_button.pressed.connect(open_part_atlas)
	heading.add_child(atlas_button)
	heading.move_child(atlas_button, heading.get_child_count() - 2)

	var tabs := HBoxContainer.new()
	tabs.name = "GuideTabs"
	tabs.add_theme_constant_override("separation", 16)
	content.add_child(tabs)
	for i in range(TABS.size()):
		var button := Button.new()
		button.name = "GuideTab%d" % i
		button.text = TABS[i]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(212, 42)
		button.add_theme_font_size_override("font_size", 19)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(select_page.bind(i))
		tabs.add_child(button)
		tab_buttons.append(button)

	atlas_status = Label.new()
	atlas_status.name = "PartAtlasStatus"
	atlas_status.text = "REFERENCE ONLY  •  Parts & spoils shows sewn limbs and cloth patches, not rewards."
	atlas_status.add_theme_font_size_override("font_size", 16)
	atlas_status.add_theme_color_override("font_color", BRASS)
	atlas_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(atlas_status)

	# A single visible page at a time, with wrap and scroll as a smaller-screen
	# fallback. Longer 18px pages scroll within the 1280x720 stitched panel.
	page_scroll = ScrollContainer.new()
	page_scroll.name = "GuidePageScroll"
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(page_scroll)
	var pages := VBoxContainer.new()
	pages.name = "GuidePages"
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.add_child(pages)
	for i in range(PAGES.size()):
		var label := Label.new()
		label.name = "GuidePage%d" % i
		label.text = "\n\n".join(PAGES[i])
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", BONE)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.visible = false
		pages.add_child(label)
		page_labels.append(label)

	var focus_ring: Array[Button] = tab_buttons.duplicate()
	focus_ring.append(atlas_button)
	focus_ring.append(close_button)
	for i in range(focus_ring.size()):
		focus_ring[i].focus_next = focus_ring[i].get_path_to(focus_ring[(i + 1) % focus_ring.size()])
		focus_ring[i].focus_previous = focus_ring[i].get_path_to(focus_ring[(i - 1 + focus_ring.size()) % focus_ring.size()])
