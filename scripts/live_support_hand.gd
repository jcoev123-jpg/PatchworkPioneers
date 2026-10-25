extends Node
## Input/presentation only. Support and movement services own effects and charges.

const SUPPORT_IDS := ["warden_brace", "warden_brace_plus", "tinker_tune_up", "tinker_tune_up_plus",
	"seamstress_mend", "seamstress_mend_plus", "seamstress_stitch_up", "seamstress_stitch_up_plus"]
const SPARE_PARTS_IDS := ["tinker_spare_parts", "tinker_spare_parts_plus"]
const ALLY_IDS := ["seamstress_mend", "seamstress_mend_plus", "seamstress_stitch_up",
	"seamstress_v3_mending_knot", "seamstress_v3_mending_knot_plus",
	"seamstress_v3_darn_the_tear", "seamstress_v3_darn_the_tear_plus",
	"seamstress_stitch_up_plus", "warden_patch_guard", "warden_patch_guard_plus",
	"seamstress_darning", "seamstress_darning_plus", "seamstress_thimble_tea", "seamstress_thimble_tea_plus"]
const TABLE_ID := "SupportTableBacking"
const QUILT_IDS := ["warden", "seamstress", "tinker"]
const QUILT_RULE := "Play cards from all living heroes: each living hero gains 3 Block; draw 1 once per turn"
## Committed sewn HUD art. Every load here is optional and cached: a missing image keeps
## the drawn felt/spool/packet and the theme button face, so play never depends on art.
const UI_ART_DIR := "res://assets/paper/ui/"
const HUD_ART := {
	"hand_tray": "hud_hand_tray.png",
	"draw_pile": "hud_draw_pile.png",
	"discard_pile": "hud_discard_pile.png",
	"energy": "hud_energy.png",
	"end_turn": "hud_end_turn.png",
}
## The real End Turn button's own visual states; it keeps its signal, focus, text and
## disabled state, only the sewn face behind them changes.
const BUTTON_STATES := ["normal", "hover", "pressed", "disabled"]
## Visible idle cue only: the complete mouse/keyboard instructions live in TABLE_HELP_DETAIL,
## exposed by hover, click and F1 without stretching the action rail.
const TABLE_HELP := "Help"
const TABLE_HELP_DETAIL := "Click, drag or focus a card and press Enter / Space to play it. " \
	+ "Up / Down or Tab moves between cards. Esc or Cancel clears a chosen target."
## Idle Help is sewn in the shipped display heading; the longer targeting prompt uses the
## theme's PatrickHand body face. Both stay at the VIS V2 >= 18 px readable floor.
const HELP_IDLE_FACE := &"PatchHeading"
const HELP_BODY_FACE := &""
const HELP_FONT_SIZE := 18
var _battle: Control
var _deck: CombatDeck
var _party: CombatParty
var _bindings: Dictionary = {}
var _move_context: Dictionary = {}
var _pending: Dictionary = {}
var _targets: Dictionary = {}
var _token := 0
var _dragging := false
var _drag_origin := Vector2.ZERO
var cancel_button: Button
var energy_label: Label
var energy_orb: Control
var help_label: Label
var help_disclosure: Label
var _help_slot: Control
var _information: Control
var footer_spring: Control
var backing: Control
var quilt_row: HBoxContainer
var quilt_patches: Dictionary = {}
var draw_token: Control
var discard_token: Control
## Presentation-only art root. A redirected or unavailable root (missing file or import)
## keeps every drawn fallback instead of failing, and repaints the same mounted nodes.
var ui_art_root := UI_ART_DIR
var _ui_art_cache: Dictionary = {}
## One saved pre-battle variation per real action control; never replace its signal or skin.
var _action_variations: Dictionary = {}
var _hud: Control
var _play := CombatStarterSupportPlay.new()
var _block_cards := CombatWardenPoolBlockCards.new()
var _energy_cards := CombatPoolEnergyCards.new()
var _tinker_gadgets := CombatTinkerPoolGadgets.new()
var _heal_cards := CombatSeamstressPoolHeals.new()
var _cleansing := CombatSeamstressV3CleansingCards.new()
var cleanse_choices: HBoxContainer
var _metadata = preload("res://scripts/live_hand_card_metadata.gd").new()
var _receipt_seq := 0


## Resolved path of one committed HUD image under the current presentation-only root.
func ui_art_path(key: String) -> String:
	if not HUD_ART.has(key):
		return ""
	return ui_art_root + String(HUD_ART[key])


## Cached, optional texture: an unavailable image stays null (a negative entry is cached
## too), so the drawn fallback is never replaced by a failed load and is probed only once.
func ui_art_texture(key: String) -> Texture2D:
	var path := ui_art_path(key)
	if path.is_empty():
		return null
	if not _ui_art_cache.has(path):
		_ui_art_cache[path] = LiveEnemyIntentBadge.load_icon_texture(path)
	return _ui_art_cache[path] as Texture2D


## Presentation only: one stitched felt sewing table drawn behind the mounted piles, hand,
## energy spool and action row. It is a sibling placed just before the battle column, so it
## draws behind every real control, never joins the hand container and never changes any
## container's minimum size. It takes no pointer or keyboard input.
class FeltTableBacking extends Control:
	const FELT_DEEP := Color("302b26")
	const HEM := Color("56483d")
	const THREAD := Color("c9b996")
	const PATCHES := [Color("42392f"), Color("473e34"), Color("39312a"), Color("443a31")]
	const INSET := 4.0
	var band := Rect2()
	var draw_count := 0
	## Committed hand-tray art, drawn across the sewn cloth behind every live card.
	## Optional: while it is missing the drawn panels stay as the fallback.
	var tray_texture: Texture2D = null
	var tray_rect := Rect2()
	var tray_draw_count := 0
	var _content: Array[Control] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(refresh_band)

	## Follow one real mounted control, so the table is always sized from live layout.
	func attach(control: Control) -> void:
		if control == null or control in _content:
			return
		_content.append(control)
		control.item_rect_changed.connect(refresh_band)
		refresh_band()

	## Re-measure the sewn bar from the attached controls; redraw only on a real change.
	func refresh_band() -> void:
		var measured := _measure_band()
		if measured == band:
			return
		band = measured
		tray_rect = band
		queue_redraw()

	## Bind (or drop) the committed tray art. Swapping it repaints this same sewn band,
	## so a missing image can never leave a stale picture behind.
	func set_tray_texture(texture: Texture2D) -> void:
		if tray_texture == texture:
			return
		tray_texture = texture
		tray_rect = band
		queue_redraw()

	## Test hook: the authored tray image now painted here, empty for the drawn fallback.
	func tray_art_path() -> String:
		return "" if tray_texture == null else tray_texture.resource_path

	## The drawn cloth panels inside the sewn band: the felt fallback under the tray.
	func cloth_rect() -> Rect2:
		if band.size.x < 8.0 or band.size.y < 8.0:
			return Rect2()
		return band.grow_individual(-INSET, -INSET, -INSET, -INSET)

	## The source crop of the authored tray. The picture keeps its own proportions and is
	## cropped (never squashed) to the live cloth, so a resize cannot distort the art.
	func tray_source_rect() -> Rect2:
		if tray_texture == null or tray_rect.size.x <= 0.0 or tray_rect.size.y <= 0.0:
			return Rect2()
		var source := Rect2(Vector2.ZERO, tray_texture.get_size())
		if source.size.x <= 0.0 or source.size.y <= 0.0:
			return Rect2()
		var target_aspect: float = tray_rect.size.x / tray_rect.size.y
		if source.size.x / source.size.y > target_aspect:
			var width: float = source.size.y * target_aspect
			return Rect2(source.position + Vector2((source.size.x - width) * 0.5, 0),
				Vector2(width, source.size.y))
		var height: float = source.size.x / target_aspect
		return Rect2(source.position + Vector2(0, (source.size.y - height) * 0.5),
			Vector2(source.size.x, height))

	func _measure_band() -> Rect2:
		var frame := Rect2(Vector2.ZERO, size)
		if not is_inside_tree() or frame.size.x <= 0.0 or frame.size.y <= 0.0:
			return Rect2()
		var lower := Rect2()
		var found := false
		for control in _content:
			if not is_instance_valid(control) or not control.is_visible_in_tree():
				continue
			var rect := _local_rect(control)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue
			lower = rect if not found else lower.merge(rect)
			found = true
		if not found:
			return Rect2()
		# The bar spans the full table width and clamps to the battle area, so it can never
		# reach up into the actor stage or draw past the viewport's bottom edge.
		var top := clampf(lower.position.y, frame.position.y, frame.end.y)
		var bottom := clampf(lower.end.y, top, frame.end.y)
		return Rect2(frame.position.x, top, frame.size.x, bottom - top)

	func _local_rect(control: Control) -> Rect2:
		var rect := control.get_global_rect()
		return Rect2(rect.position - get_global_rect().position, rect.size)

	## Test hook: does this Control's real rect sit inside the sewn table?
	func covers(control: Control) -> bool:
		if not is_instance_valid(control) or band.size.x <= 0.0 or band.size.y <= 0.0:
			return false
		return band.encloses(_local_rect(control))

	## Test hook: does the sewn table reach into this Control's real rect?
	func overlaps(control: Control) -> bool:
		if not is_instance_valid(control) or band.size.x <= 0.0 or band.size.y <= 0.0:
			return false
		return band.intersects(_local_rect(control))

	func _draw() -> void:
		if band.size.x < 24.0 or band.size.y < 24.0:
			return
		draw_count += 1
		draw_rect(band, FELT_DEEP)
		var cloth := cloth_rect()
		# Uneven sewn panels read as one quilted cloth without any texture file.
		var count := 6
		for index in range(count):
			var from := cloth.position.x + cloth.size.x * float(index) / float(count)
			var to := cloth.position.x + cloth.size.x * float(index + 1) / float(count)
			draw_rect(Rect2(from, cloth.position.y, to - from - 2.0, cloth.size.y), PATCHES[index % PATCHES.size()])
		# The committed tray lies over the drawn cloth and behind every real control; the
		# drawn panels remain the fallback whenever the image is missing.
		if tray_texture != null and tray_rect.size.x > 0.0 and tray_rect.size.y > 0.0:
			tray_draw_count += 1
			draw_texture_rect_region(tray_texture, tray_rect, tray_source_rect())
		draw_rect(Rect2(cloth.position, Vector2(cloth.size.x, 3.0)), HEM)
		draw_rect(Rect2(cloth.position.x, cloth.end.y - 3.0, cloth.size.x, 3.0), HEM)
		for y in [cloth.position.y, cloth.end.y]:
			draw_dashed_line(Vector2(cloth.position.x, y), Vector2(cloth.end.x, y), THREAD, 1.0, 6.0)
		for index in range(1, count):
			var x := cloth.position.x + cloth.size.x * float(index) / float(count)
			draw_dashed_line(Vector2(x, cloth.position.y), Vector2(x, cloth.end.y), THREAD, 1.0, 5.0)
			for y in [cloth.position.y + 9.0, cloth.end.y - 9.0]:
				draw_line(Vector2(x - 3.0, y - 3.0), Vector2(x + 3.0, y + 3.0), THREAD, 1.2, true)
				draw_line(Vector2(x - 3.0, y + 3.0), Vector2(x + 3.0, y - 3.0), THREAD, 1.2, true)


## The inset spool that carries the live energy number. It paints the committed
## `hud_energy.png` inside its own disc when available; otherwise it draws the sewn felt
## spool, and its child Label keeps showing the authoritative amount either way.
class EnergyOrb extends Control:
	## The spool is drawn inset from the control rect, so the whole disc keeps a clear
	## margin inside the 76 px footer box and never crowds the battle area's bottom edge.
	const INSET := 8.0
	const DISK := Color("555d48")
	const RIM := Color("ecdfbd")
	const THREAD := Color("c9b996")
	var draw_count := 0
	## Committed energy-spool art, optional: null keeps the drawn felt disc.
	var texture: Texture2D = null
	var art_draw_count := 0

	func _ready() -> void:
		custom_minimum_size = Vector2(76, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	## Radius of the drawn fabric disc: always inside the control rect, never the rect itself.
	func disc_radius() -> float:
		return maxf(minf(size.x, size.y) * 0.5 - INSET, 8.0)

	## Test hook: the sewn disc in this control's local space.
	func disc_rect() -> Rect2:
		var radius := disc_radius()
		return Rect2(size * 0.5 - Vector2(radius, radius), Vector2(radius, radius) * 2.0)

	## Test hook: the authored spool image now painted here, empty for the drawn fallback.
	func art_path() -> String:
		return "" if texture == null else texture.resource_path

	func _draw() -> void:
		var center := size * 0.5
		var radius := disc_radius()
		draw_count += 1
		if texture != null:
			art_draw_count += 1
			draw_texture_rect(texture, disc_rect(), false)
			return
		draw_circle(center, radius, DISK)
		draw_arc(center, radius, 0, TAU, 64, RIM, 2, true)
		for index in range(16):
			var angle := TAU * index / 16.0
			draw_line(center + Vector2.from_angle(angle) * (radius - 6),
				center + Vector2.from_angle(angle + 0.07) * (radius - 4), THREAD, 1, true)


## One inert authored pile token. It is a picture only: the exact draw/discard counts stay
## in the existing pile Label, so this control never duplicates a number, never takes the
## pointer or keyboard and never owns a button, handler or tooltip.
class PileToken extends Control:
	const SIZE := Vector2(24, 24)
	const CLOTH := Color("42392f")
	const THREAD := Color("c9b996")
	## "draw" or "discard"; only chooses the drawn fallback's arrow direction.
	var kind := "draw"
	var texture: Texture2D = null
	var draw_count := 0

	func _ready() -> void:
		custom_minimum_size = SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		resized.connect(queue_redraw)

	## Test hook: the authored pile image now painted here, empty for the drawn packet.
	func art_path() -> String:
		return "" if texture == null else texture.resource_path

	## The picture keeps its own proportions inside this token instead of being squashed.
	func art_rect() -> Rect2:
		var box := Rect2(Vector2.ZERO, size)
		if texture == null or box.size.x <= 0.0 or box.size.y <= 0.0:
			return Rect2()
		var pixels := Vector2(texture.get_width(), texture.get_height())
		if pixels.x <= 0.0 or pixels.y <= 0.0:
			return Rect2()
		var fit: float = minf(box.size.x / pixels.x, box.size.y / pixels.y)
		return Rect2(box.get_center() - pixels * fit * 0.5, pixels * fit)

	func _draw() -> void:
		if size.x < 6.0 or size.y < 6.0:
			return
		draw_count += 1
		if texture != null:
			draw_texture_rect(texture, art_rect(), false)
			return
		# Drawn fallback: a small stitched felt packet with a card leaving or arriving.
		var box := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		draw_rect(box, CLOTH)
		for y in [box.position.y, box.end.y]:
			draw_dashed_line(Vector2(box.position.x, y), Vector2(box.end.x, y), THREAD, 1.0, 3.0)
		for x in [box.position.x, box.end.x]:
			draw_dashed_line(Vector2(x, box.position.y), Vector2(x, box.end.y), THREAD, 1.0, 3.0)
		var arrow: float = -1.0 if kind == "draw" else 1.0
		var centre := box.get_center()
		var tip := Vector2(centre.x + arrow * box.size.x * 0.2, centre.y)
		draw_line(Vector2(centre.x - arrow * box.size.x * 0.2, centre.y), tip, THREAD, 1.5, true)
		draw_line(tip, tip + Vector2(-arrow * 3.5, -3.0), THREAD, 1.5, true)
		draw_line(tip, tip + Vector2(-arrow * 3.5, 3.0), THREAD, 1.5, true)


## Decorative only: a sewn thread border inside the Help patch. It is a child of the real
## hoverable Label, ignores the mouse and takes no focus, so hovering still reaches the
## Label's tooltip rather than this inert drawing.
class HelpStitch extends Control:
	const THREAD := Color("c9b996")
	const EDGE := 3.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var cloth := Rect2(Vector2(EDGE, EDGE), size - Vector2(EDGE, EDGE) * 2.0)
		if cloth.size.x < 12.0 or cloth.size.y < 8.0:
			return
		var corners := [cloth.position, Vector2(cloth.end.x, cloth.position.y),
			cloth.end, Vector2(cloth.position.x, cloth.end.y)]
		for index in range(corners.size()):
			draw_dashed_line(corners[index], corners[(index + 1) % corners.size()], THREAD, 1.0, 4.0)
			var point: Vector2 = corners[index]
			draw_line(point + Vector2(-2, -2), point + Vector2(2, 2), THREAD, 1.2, true)
			draw_line(point + Vector2(-2, 2), point + Vector2(2, -2), THREAD, 1.2, true)


## A passive, ID-keyed felt square. Nothing here can arm a card or award a receipt.
## Tooltip mouse hover is the only input accepted; no keyboard focus or button action.
class QuiltPatch extends Control:
	const THREAD := Color("c9b996")
	const DARK := Color("302b26")
	var owner_id := ""
	var living := false
	var played := false
	var awarded := false
	var felt_color := Color("302b26")
	var fill_color := Color("302b26")

	func _ready() -> void:
		custom_minimum_size = Vector2(34, 34)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_HELP
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	func display(owner: String, snapshot: Dictionary, has_award: bool) -> void:
		var next_living: bool = bool(snapshot.get("living", false))
		var next_played: bool = bool(snapshot.get("played", false))
		var next_color := Color(str(snapshot.get("color", "#302b26")))
		var changed := owner_id != owner or living != next_living or played != next_played \
			or awarded != has_award or felt_color != next_color
		owner_id = owner
		living = next_living
		played = next_played
		awarded = has_award
		felt_color = next_color
		fill_color = felt_color if played else DARK.lerp(felt_color, 0.23)
		if not living:
			fill_color = fill_color.darkened(0.58)
		var state := "played" if played else "unplayed"
		if not living:
			state += ", downed (not required)"
		elif not played:
			state += ", needed"
		if awarded:
			state += ", Quilt awarded this turn"
		tooltip_text = "%s — %s\n%s" % [owner.capitalize(), state, QUILT_RULE]
		if changed:
			queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		if rect.size.x < 16 or rect.size.y < 16:
			return
		draw_rect(rect, fill_color)
		var thread := THREAD if living else THREAD.darkened(0.58)
		for y in [rect.position.y, rect.end.y]:
			draw_dashed_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), thread, 1.0, 3.0)
		for x in [rect.position.x, rect.end.x]:
			draw_dashed_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), thread, 1.0, 3.0)
		# Owner-colour appliques: shield, threaded needle and cog. Their silhouettes
		# remain distinct before a play; the brighter cloth/check records progress.
		var centre := size * 0.5
		var motif := felt_color.lightened(0.35) if living else thread.darkened(0.3)
		match owner_id:
			"warden":
				var shield := PackedVector2Array([centre + Vector2(-7, -8),
					centre + Vector2(7, -8), centre + Vector2(6, 2),
					centre + Vector2(0, 8), centre + Vector2(-6, 2)])
				draw_colored_polygon(shield, motif)
				draw_line(centre + Vector2(0, -5), centre + Vector2(0, 4), DARK, 1.5, true)
			"seamstress":
				draw_line(centre + Vector2(-6, 8), centre + Vector2(5, -7), motif, 3.0, true)
				draw_arc(centre + Vector2(5, -6), 2.5, 0, TAU, 12, thread, 1.0, true)
				draw_polyline(PackedVector2Array([centre + Vector2(7, -6),
					centre + Vector2(9, -1), centre + Vector2(5, 3),
					centre + Vector2(1, 1)]), motif, 1.5, true)
			"tinker":
				for tooth in range(8):
					var spoke := Vector2.from_angle(float(tooth) * TAU / 8.0)
					draw_line(centre + spoke * 5, centre + spoke * 9, motif, 3.0, true)
				draw_arc(centre, 5.5, 0, TAU, 20, motif, 3.0, true)
		if played:
			# A completed stitch is separate from the owner's unplayed dark fill.
			draw_line(Vector2(5, size.y - 8), Vector2(9, size.y - 4), thread, 1.5)
			draw_line(Vector2(9, size.y - 4), Vector2(15, size.y - 12), thread, 1.5)
		if not living:
			draw_line(Vector2(5, 5), size - Vector2(5, 5), thread.darkened(0.3), 1.5)
		if awarded:
			# Small golden award knot, not a fourth patch or a new action.
			var knot := Vector2(size.x - 7, 7)
			var gold := Color("f2d58e")
			draw_colored_polygon(PackedVector2Array([knot + Vector2(0, -4),
				knot + Vector2(4, 0), knot + Vector2(0, 4), knot + Vector2(-4, 0)]), gold)


func _ready() -> void:
	get_parent().start_run_requested.connect(_sync_battle, CONNECT_DEFERRED)


func _process(_delta: float) -> void:
	_sync_battle()


func _toggle_help() -> void:
	if is_instance_valid(_help_slot) and not _pending.get("choosing", false):
		_help_slot.visible = not _help_slot.visible


func _on_help_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed and help_label.get_parent() == _information:
		_toggle_help()
		help_label.accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and is_instance_valid(help_disclosure) and is_instance_valid(_battle) \
			and _battle.is_visible_in_tree():
		if event.keycode == KEY_F1 and not _pending.get("choosing", false):
			_toggle_help()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and _help_slot.visible and not _pending.get("choosing", false):
			_help_slot.hide()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and not _pending.is_empty():
		var source = _pending.panel
		if is_instance_valid(source):
			source.set_meta("aiming", true)
			source.set_meta("aim_point", event.position)
			source.queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _dragging:
		_dragging = false
		if _pending.is_empty() or not _selection_valid():
			_cancel_pending()
			return
		_pending.panel.set_meta("aiming", false)
		if _pending.id in ALLY_IDS:
			if not _pending.get("choosing", false):
				_choose_target()
			if event.position.distance_to(_drag_origin) > 10:
				# Drag release uses exactly the same target receipt and deferred commit.
				for panel in _targets:
					if panel.get_global_rect().has_point(event.position):
						var press := InputEventMouseButton.new()
						press.button_index = MOUSE_BUTTON_LEFT
						press.pressed = true
						_on_target_input(press, panel, _targets[panel].position, _token)
						return
				_cancel_pending()
		else:
			if _pending.panel.get_global_rect().has_point(event.position):
				_activate.call_deferred(_pending.panel, _pending.id, _deck, _party, _battle, _token)
			else:
				_cancel_pending()
	if not _pending.is_empty() and event.is_action_pressed("ui_cancel"):
		_cancel_pending()
		get_viewport().set_input_as_handled()


## True only for the five resolved Warden pure-Block pool records and their '+' forms.
## The resolver's kind table is the authority, so a future catalog entry cannot be
## admitted by a stale local list.
func _is_block_card(card_id: String) -> bool:
	var base_id := card_id.trim_suffix("_plus")
	return CombatWardenPoolBlockCards.SUPPORTED_KINDS.has(base_id) \
		and (card_id == base_id or card_id == base_id + "_plus")


func _is_energy_card(card_id: String) -> bool:
	return CombatPoolEnergyCards.SUPPORTED_IDS.has(card_id)

## True only for the six authored Seamstress healing pool records the resolver owns.
func _is_heal_card(card_id: String) -> bool:
	return card_id in CombatSeamstressPoolHeals.DARNING_IDS \
		or card_id in CombatSeamstressPoolHeals.TEA_IDS \
		or card_id in CombatSeamstressPoolHeals.FIELD_MEND_IDS

## Read-only handoff of THIS battle's one healing service to the mounted attack
## presenter that commits Rest-stitched composites. The very same instance (and so
## the very same once-per-combat COAT latch) is returned only while its deck, party
## and battle view are still the live hand's, so a stale sibling node, a previous
## combat or a replaced battle can never lend a foreign latch. Nothing is bound,
## reset, spent or discarded here.
func stitched_heal_authority(deck: CombatDeck, party: CombatParty, battle) -> CombatSeamstressPoolHeals:
	if _heal_cards == null or deck == null or party == null or not is_instance_valid(battle):
		return null
	if not is_inside_tree():
		return null
	var app = get_parent()
	if app == null or deck != _deck or party != _party or battle != _battle \
			or app.deck != deck or app.party != party or app.battle_view != battle:
		return null
	return _heal_cards

## The battle-scoped Path authority lives on the mounted attack presenter, which
## already owns this battle's shared Tinker first-attack latch and turn boundary.
## A stale or foreign presenter never authorizes a Path cast.
func _path_presenter():
	var app = get_parent()
	if app == null:
		return null
	var presenter = app.get_node_or_null("LiveAttackPreview")
	if presenter == null or not is_instance_valid(presenter) \
			or presenter._deck != _deck or presenter._battle != _battle:
		return null
	return presenter


## A selected Tinker Path card is actionable only while this battle's one Path
## authority is really bound to this deck, turn and hand.
func _is_path_card(card_id: String) -> bool:
	var presenter = _path_presenter()
	return presenter != null and presenter.tinker_path_is_card(card_id)


## The battle's one Path authority's authored Clockwork reduction, read BEFORE
## the support service's printed-cost check so a discounted card stays castable.
func _path_discount(card_id: String) -> int:
	var presenter = _path_presenter()
	return 0 if presenter == null else int(presenter.tinker_cost_discount(card_id))


func _is_actionable(card_id: String) -> bool:
	if _cleansing.is_supported_card(card_id):
		return true
	return card_id in SUPPORT_IDS or card_id in SPARE_PARTS_IDS or card_id in M02PositionCards.IDS or _is_block_card(card_id) or _is_energy_card(card_id) or _is_heal_card(card_id) or _is_path_card(card_id)


## One entry point keeps starter support and pool Block cards on the same commit path.
func _play_held(deck: CombatDeck, party: CombatParty, card_id: String, position: int, debuff: String = "") -> bool:
	if _cleansing.is_supported_card(card_id):
		return bool(_cleansing.play_card(deck, party, card_id, position, debuff).get("ok", false))
	if _is_path_card(card_id):
		return _play_path_card(card_id)
	if card_id in SPARE_PARTS_IDS:
		return _tinker_gadgets != null and bool(_tinker_gadgets.resolve_spare_parts(deck, party, card_id, position).get("ok", false))
	if _is_block_card(card_id):
		if _block_cards == null:
			return false
		return bool(_block_cards.play_card(deck, party, card_id, position).get("ok", false))
	if _is_energy_card(card_id):
		if _energy_cards == null:
			return false
		return bool(_energy_cards.play_card(deck, party, card_id, 0))
	if _is_heal_card(card_id):
		if _heal_cards == null:
			return false
		return bool(_heal_cards.play_card(deck, party, card_id, position))
	if card_id in ["seamstress_mend", "seamstress_mend_plus"]:
		# Observe the actual recipient, not a preview or printed heal amount.
		# Only the successful authentic held-card transaction may issue a COAT receipt.
		var before_hp := -1
		if party != null and party.is_valid() and position >= 1 and position <= CombatParty.PARTY_SIZE:
			before_hp = int(party.get_hero(position).get("hp", -1))
		var hand_before: int = deck.hand.count(card_id) if deck != null else 0
		var discard_before: int = deck.discard_pile.size() if deck != null else -1
		var energy_before: int = deck.energy if deck != null else -1
		var committed: bool = _play != null and _play.play_card(deck, party, card_id, position,
			_path_discount(card_id))
		if committed and _heal_cards != null and before_hp >= 0:
			_heal_cards.notify_committed_starter_mend(deck, party, card_id, position, before_hp,
				int(party.get_hero(position)["hp"]), hand_before, discard_before, energy_before)
		return committed
	return _play != null and _play.play_card(deck, party, card_id, position,
		_path_discount(card_id))


## Target-free commit of the selected Tinker Path card. The face the player is
## looking at supplies the presented metadata; the battle's one Path authority
## revalidates it with the real Tinker position, turn and energy before it
## spends, discards or arms anything.
func _play_path_card(card_id: String) -> bool:
	var presenter = _path_presenter()
	if presenter == null:
		return false
	var presented: Dictionary = _metadata.definition(card_id)
	if presented.is_empty():
		return false
	var receipt: Dictionary = presenter.commit_tinker_path_card(card_id,
		String(presented.get("owner", "")), int(presented.get("cost", -1)),
		String(presented.get("target_kind", "")))
	return bool(receipt.get("ok", false))


func _sync_battle() -> void:
	var app = get_parent()
	if app.deck == null or not is_instance_valid(app.battle_view):
		_clear()
		return
	if _battle != app.battle_view or _deck != app.deck or _party != app.party:
		_clear()
		_battle = app.battle_view
		_deck = app.deck
		_party = app.party
		_play = CombatStarterSupportPlay.new()
		_block_cards = CombatWardenPoolBlockCards.new()
		_energy_cards = CombatPoolEnergyCards.new()
		_tinker_gadgets = CombatTinkerPoolGadgets.new()
		_heal_cards = CombatSeamstressPoolHeals.new()
		var carry = app.party_carryover
		if carry is RunTornCarryover and carry._wardrobe != null:
			var state: Dictionary = carry._wardrobe.get_snapshot()
			if app._current_carryover_fight() and carry.can_bind_wardrobe(carry._wardrobe, carry.torn, state):
				_play.bind_patch_wardrobe(carry._wardrobe, carry.torn, state, carry.torn.read_state())
				_heal_cards.bind_patch_wardrobe(carry._wardrobe, carry.torn, state, carry.torn.read_state())
				# The pure-Block resolver receives the same authenticated projection, so a
				# sewn ARM cuff applies to the exact live shared-hand card play.
				_block_cards.bind_patch_wardrobe(carry._wardrobe, carry.torn, state, carry.torn.read_state())
			else:
				# Explicit invalid run authority must never fall back to unbound play.
				_play.bind_patch_wardrobe(null, null)
				_heal_cards.bind_patch_wardrobe(null, null)
				_block_cards.bind_patch_wardrobe(null, null)
		_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
		var hud := _battle.find_child("SupportHUD", true, false) as HBoxContainer
		energy_orb = EnergyOrb.new()
		_add_named(hud, energy_orb, "SupportHandEnergyOrb")
		hud.move_child(energy_orb, 0)
		energy_label = Label.new()
		energy_label.name = "SupportHandEnergy"
		energy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		energy_label.add_theme_font_size_override("font_size", 18)
		# The number must stay legible over the authored spool art, not only the drawn disc.
		energy_label.add_theme_color_override("font_outline_color", Color("2a2621"))
		energy_label.add_theme_constant_override("outline_size", 4)
		energy_orb.add_child(energy_label)
		energy_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		help_label = Label.new()
		help_label.name = "SupportHandHelp"
		# A small sewn patch: the visible cue is one short word, the complete instructions
		# stay on a real hoverable tooltip and never occupy a stretch row of the footer.
		help_label.text = TABLE_HELP
		help_label.mouse_filter = Control.MOUSE_FILTER_STOP
		help_label.mouse_default_cursor_shape = Control.CURSOR_HELP
		help_label.focus_mode = Control.FOCUS_NONE
		help_label.tooltip_text = TABLE_HELP_DETAIL
		help_label.theme_type_variation = HELP_IDLE_FACE
		# Fit the existing information strip without taking height from the actor stage.
		help_label.custom_minimum_size = Vector2(64, 32)
		help_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		help_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		help_label.add_theme_font_size_override("font_size", HELP_FONT_SIZE)
		help_label.add_theme_color_override("font_color", Color("ecdfbd"))
		var patch := StyleBoxFlat.new()
		patch.bg_color = Color("42392f")
		patch.border_color = Color("c9b996")
		patch.set_border_width_all(1)
		patch.set_corner_radius_all(6)
		patch.content_margin_left = 10
		patch.content_margin_right = 10
		patch.content_margin_top = 5
		patch.content_margin_bottom = 5
		help_label.add_theme_stylebox_override("normal", patch)
		var stitch := HelpStitch.new()
		stitch.name = "SupportHandHelpStitch"
		help_label.add_child(stitch)
		_information = _battle.find_child("BattleHandInformation", true, false)
		_help_slot = _battle.find_child("BattleHandDisclosureSlot", true, false)
		_add_named(_information, help_label, "SupportHandHelp")
		help_label.gui_input.connect(_on_help_input)
		help_disclosure = Label.new()
		help_disclosure.name = "SupportHandHelpDisclosure"
		help_disclosure.text = TABLE_HELP_DETAIL
		help_disclosure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help_disclosure.add_theme_font_size_override("font_size", HELP_FONT_SIZE)
		help_disclosure.add_theme_color_override("font_color", Color("ecdfbd"))
		help_disclosure.add_theme_stylebox_override("normal", patch.duplicate())
		help_disclosure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_help_slot.add_child(help_disclosure)
		var disclosure_stitch := HelpStitch.new()
		disclosure_stitch.name = "SupportHelpDisclosureStitch"
		help_disclosure.add_child(disclosure_stitch)
		# Inert spring: the cue itself no longer stretches, and the accepted End Turn / Return
		# row keeps its far-right placement. Hidden while a target message needs the room.
		footer_spring = Control.new()
		footer_spring.name = "SupportHandFooterSpring"
		footer_spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		footer_spring.focus_mode = Control.FOCUS_NONE
		footer_spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_add_named(hud, footer_spring, "SupportHandFooterSpring")
		hud.move_child(footer_spring, 2)
		# Owner identity follows the Quilt service, never hero slots or card indices.
		quilt_row = HBoxContainer.new()
		quilt_row.name = "SupportHandQuiltPatches"
		quilt_row.add_theme_constant_override("separation", 4)
		quilt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quilt_row.focus_mode = Control.FOCUS_NONE
		quilt_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var quilt_cloth := PanelContainer.new()
		quilt_cloth.name = "QuiltCloth"
		quilt_cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var quilt_style := patch.duplicate() as StyleBoxFlat
		quilt_style.content_margin_left = 8
		quilt_style.content_margin_right = 8
		quilt_style.content_margin_top = 5
		quilt_style.content_margin_bottom = 5
		quilt_cloth.add_theme_stylebox_override("panel", quilt_style)
		quilt_row.add_child(quilt_cloth)
		var quilt_column := VBoxContainer.new()
		quilt_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quilt_column.add_theme_constant_override("separation", 0)
		quilt_cloth.add_child(quilt_column)
		var quilt_title := Label.new()
		quilt_title.name = "SupportHandQuiltTitle"
		quilt_title.text = "Quilt"
		quilt_title.theme_type_variation = "PatchHeading"
		quilt_title.add_theme_font_size_override("font_size", 16)
		quilt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quilt_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quilt_column.add_child(quilt_title)
		var marks := HBoxContainer.new()
		marks.name = "QuiltOwnerMarks"
		marks.add_theme_constant_override("separation", 4)
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quilt_column.add_child(marks)
		var quilt_stitch := HelpStitch.new()
		quilt_stitch.name = "QuiltStitch"
		quilt_cloth.add_child(quilt_stitch)
		for owner_id in QUILT_IDS:
			var square := QuiltPatch.new()
			square.name = "QuiltPatch_" + owner_id
			square.owner_id = owner_id
			marks.add_child(square)
			quilt_patches[owner_id] = square
		_add_named(hud, quilt_row, "SupportHandQuiltPatches")
		hud.move_child(quilt_row, 2)
		quilt_row.hide()
		cancel_button = Button.new()
		cancel_button.text = "Cancel target (Esc)"
		cancel_button.pressed.connect(_cancel_pending)
		hud.add_child(cancel_button)
		cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cancel_button.hide()
		_hud = hud
		_mount_table(app)
		_mount_pile_tokens(app)
	if not _pending.is_empty() and not _selection_valid():
		_cancel_pending()
	if not _targets_valid():
		_cancel_pending()
	for panel in _targets:
		var cue: Label = _targets[panel].cue
		cue.position = panel.global_position - Vector2(0, 16)
		cue.size = Vector2(panel.size.x, 16)
	# The spool is only 76 px across: the left-over charge alone sits inside its disc,
	# never a wrapped "Energy" word that would spill past the inset rim.
	energy_label.text = "%d" % _deck.energy
	# Idle: one short sewn cue, no stretch. Targeting: the full card-name prompt takes the row.
	var choosing: bool = _pending.get("choosing", false)
	var help_home: Control = _hud if choosing else _information
	if help_label.get_parent() != help_home:
		help_label.reparent(help_home)
		if choosing:
			_hud.move_child(help_label, 1)
	if choosing:
		_help_slot.visible = is_instance_valid(cleanse_choices)
	var help_text: String = TABLE_HELP
	if choosing:
		help_text = "%s: choose a living ally | Esc: cancel" % _metadata.definition(_pending.id).get("display_name", _pending.id)
		if _cleansing.is_supported_card(_pending.id):
			help_text = "%s: 1 energy; heal %d; %s | Esc: cancel" % [_metadata.definition(_pending.id).display_name,
				_metadata.definition(_pending.id).effects.heal,
				"choose Bleed / Weak / Exposed below (Tab, Enter / Space)" if is_instance_valid(cleanse_choices) else "choose a living ally, then a debuff"]
	if help_label.text != help_text:
		help_label.text = help_text
	# The same patch keeps the sewn frame; only its face changes: idle Help in the shipped
	# display heading, the longer targeting prompt in the body face. Restored on cancel.
	var help_face: StringName = HELP_BODY_FACE if choosing else HELP_IDLE_FACE
	if help_label.theme_type_variation != help_face:
		help_label.theme_type_variation = help_face
	var help_flags: int = Control.SIZE_EXPAND_FILL if choosing else Control.SIZE_SHRINK_BEGIN
	if help_label.size_flags_horizontal != help_flags:
		help_label.size_flags_horizontal = help_flags
	if is_instance_valid(footer_spring) and footer_spring.visible == choosing:
		footer_spring.visible = not choosing
	_sync_quilt(app, choosing)
	# The committed HUD art is resolved against the same mounted controls every frame, so a
	# redirected or missing art root can never leave a stale picture or a duplicate node.
	_sync_hud_art(app)
	# The felt table follows the real lower controls, including every resize.
	if is_instance_valid(backing):
		backing.refresh_band()
	for panel in _bindings.keys():
		if not is_instance_valid(panel) or panel.get_parent() != app.hand_view:
			_unbind(panel)
	# Decorate only the exact ordered live cards, without replacing their input panels.
	_metadata.set_app(app)
	_metadata.sync(app.hand_view.get_children(), _deck.hand)
	var actionable: Array[Control] = []
	for panel in app.hand_view.get_children():
		var label := panel.get_child(0) as Label
		if label == null or not _is_actionable(label.text):
			continue
		actionable.append(panel)
		if _bindings.has(panel):
			continue
		panel.focus_mode = Control.FOCUS_ALL
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.tooltip_text = "Click or focus and press Enter / Space to play\n" + _metadata.base_effect_text(label.text)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(0, 0, 0, 0)
		focus.border_color = Color("ece0c8")
		focus.set_border_width_all(3)
		panel.add_theme_stylebox_override("focus", focus)
		var callback := _on_card_input.bind(panel, label.text, _deck, _party, _battle)
		_bindings[panel] = callback
		if label.text in M02PositionCards.IDS:
			_move_context[panel] = _current_move_context(panel)
		panel.gui_input.connect(callback)
	# Keep the existing End/Return Tab cycle; Up enters the card row, Down exits it.
	if not actionable.is_empty():
		for button in [app.end_turn_button, app.return_button]:
			button.focus_neighbor_top = button.get_path_to(actionable[0])
		for index in range(actionable.size()):
			var panel := actionable[index]
			panel.focus_next = panel.get_path_to(actionable[(index + 1) % actionable.size()])
			panel.focus_previous = panel.get_path_to(actionable[(index - 1 + actionable.size()) % actionable.size()])
			panel.focus_neighbor_bottom = panel.get_path_to(app.end_turn_button)
	else:
		app.end_turn_button.focus_neighbor_top = NodePath()
		app.return_button.focus_neighbor_top = NodePath()


## Only the already bound live CombatQuiltBonus may supply display state.
## A preview, stale battle, closed turn or mismatched authority has no visible row.
func _sync_quilt(app, choosing: bool) -> void:
	if not is_instance_valid(quilt_row):
		return
	var service = app._quilt_bonus
	var valid: bool = service is CombatQuiltBonus and app._quilt_turn_open \
		and app._quilt_deck == _deck and app._quilt_party == _party \
		and service._deck == _deck and service._party == _party \
		and not app._battle_closed and _deck != null and _deck.turn_active \
		and _party != null and _party.is_valid() and service._bindings_valid()
	if not valid or choosing:
		quilt_row.hide()
		return
	var snapshot: Dictionary = service.get_patch_progress()
	var patches: Dictionary = snapshot.get("patches", {})
	if not bool(snapshot.get("active", false)) or patches.size() != QUILT_IDS.size():
		quilt_row.hide()
		return
	for owner_id in QUILT_IDS:
		if not patches.get(owner_id) is Dictionary or not quilt_patches.has(owner_id):
			quilt_row.hide()
			return
	for owner_id in QUILT_IDS:
		var square: QuiltPatch = quilt_patches[owner_id]
		square.display(owner_id, patches[owner_id], bool(snapshot.get("awarded", false)))
	quilt_row.show()


func _mount_table(app) -> void:
	# Exactly one table per battle: a stale one from an earlier mount is dropped first.
	for stale in _battle.find_children(TABLE_ID, "Control", true, false):
		stale.free()
	backing = FeltTableBacking.new()
	backing.name = TABLE_ID
	_battle.add_child(backing)
	# Place it immediately before the battle column, so the accepted actor-stage backdrop and
	# every existing control keep their own sibling order and draw on top of the table.
	var column := _hud.get_parent() as Control
	while column != null and column.get_parent() != _battle:
		column = column.get_parent() as Control
	if column != null and column.get_parent() == _battle:
		_battle.move_child(backing, column.get_index())
	var pile_row = app.pile_label.get_parent() if is_instance_valid(app.pile_label) else null
	for content in [pile_row, app.pile_label, app.hand_view, _hud, app.end_turn_button]:
		if content is Control:
			backing.attach(content)


## Add one presentation child under a stable authored name. A previous mount's node with
## the same name is detached first (a same-battle rebind would otherwise make Godot fall
## back to a generated `@Control@id` name that later name lookups cannot find).
func _add_named(parent: Node, node: Node, node_name: String) -> void:
	node.name = node_name
	if parent != null:
		for stale in parent.get_children():
			if stale.name == node_name and stale != node:
				parent.remove_child(stale)
				stale.queue_free()
	parent.add_child(node)


## The two authored pile pictures are purely decorative tokens in the EXISTING pile row:
## the exact counts stay in the one pile Label, and the tokens flank it without covering a
## digit, taking the pointer, the keyboard or adding a second count.
func _mount_pile_tokens(app) -> void:
	if not is_instance_valid(app.pile_label):
		return
	var row: Node = app.pile_label.get_parent()
	if row == null:
		return
	draw_token = PileToken.new()
	_add_named(row, draw_token, "SupportHandDrawPile")
	draw_token.kind = "draw"
	row.move_child(draw_token, app.pile_label.get_index())
	discard_token = PileToken.new()
	_add_named(row, discard_token, "SupportHandDiscardPile")
	discard_token.kind = "discard"
	row.move_child(discard_token, app.pile_label.get_index() + 1)


## Resolve the committed HUD art for the mounted controls. Every lookup is cached and
## optional: a missing image leaves the existing drawn fallback in place, and re-resolving
## after a redirected art root repaints the SAME nodes instead of mounting duplicates.
func _sync_hud_art(app) -> void:
	if is_instance_valid(energy_orb):
		var spool := ui_art_texture("energy")
		if energy_orb.texture != spool:
			energy_orb.texture = spool
			energy_orb.queue_redraw()
	if is_instance_valid(backing):
		backing.set_tray_texture(ui_art_texture("hand_tray"))
	for token in [draw_token, discard_token]:
		if not is_instance_valid(token):
			continue
		var art := ui_art_texture("draw_pile" if token == draw_token else "discard_pile")
		if token.texture != art:
			token.texture = art
			token.queue_redraw()
	_paint_end_turn(app.end_turn_button if is_instance_valid(app) else null)
	_sync_action_fonts(app)


## The live actions retain their own Button nodes, wording, callbacks, state skins and
## focus routes. Saving each prior variation once makes per-frame repaint idempotent.
func _sync_action_fonts(app) -> void:
	if not is_instance_valid(app):
		return
	for action in [app.end_turn_button, app.return_button, cancel_button]:
		if not is_instance_valid(action) or not action is Button:
			continue
		var button := action as Button
		if not _action_variations.has(button):
			_action_variations[button] = button.theme_type_variation
		if button.theme_type_variation != &"PatchHeadingButton":
			button.theme_type_variation = &"PatchHeadingButton"


func _restore_action_fonts() -> void:
	for action in _action_variations:
		if is_instance_valid(action):
			(action as Button).theme_type_variation = _action_variations[action]
	_action_variations.clear()


## The real End Turn button keeps its own text, pressed signal, focus, Tab cycle and
## disabled state; only the sewn face behind them is replaced when the art exists.
func _paint_end_turn(button) -> void:
	if not is_instance_valid(button):
		return
	var art := ui_art_texture("end_turn")
	var path := "" if art == null else art.resource_path
	if str(button.get_meta("hud_end_turn_art", "")) == path:
		return
	button.set_meta("hud_end_turn_art", path)
	for state in BUTTON_STATES:
		button.remove_theme_stylebox_override(state)
	if art == null:
		return
	for state in BUTTON_STATES:
		var face := StyleBoxTexture.new()
		face.texture = art
		face.texture_margin_left = 14.0
		face.texture_margin_right = 14.0
		face.texture_margin_top = 10.0
		face.texture_margin_bottom = 10.0
		# No extra vertical padding: the sewn face must not grow the accepted 48 px control.
		face.content_margin_left = 10.0
		face.content_margin_right = 10.0
		face.content_margin_top = 0.0
		face.content_margin_bottom = 0.0
		if state == "disabled":
			face.modulate_color = Color(0.62, 0.58, 0.54)
		button.add_theme_stylebox_override(state, face)


func _current_move_context(panel) -> Array:
	var app = get_parent()
	return [app.deck, app.party, app.battle_view, app.enemies, app.battle_result,
		app.run_rng, app.enemy_intents, app.enemy_intents._turn_index if app.enemy_intents != null else -1, panel.get_index()]


func _eligible(panel, card_id: String, deck: CombatDeck, party: CombatParty, battle) -> bool:
	var app = get_parent()
	if not is_instance_valid(panel) or not is_instance_valid(battle):
		return false
	if not _bindings.has(panel) or not _is_actionable(card_id):
		return false
	if app.deck != deck or app.party != party or app.battle_view != battle:
		return false
	if deck != _deck or party != _party or battle != _battle:
		return false
	if not panel.is_visible_in_tree() or not battle.is_visible_in_tree() or panel.get_parent() != app.hand_view:
		return false
	if _is_block_card(card_id):
		# Presentation preflight only: the pool resolver revalidates and commits.
		if app._battle_closed or not deck.turn_active or app.battle_result == null \
			or not app.battle_result.can_continue() or app.battle_result._party != party \
			or app.battle_result._enemies != app.enemies or not party.is_valid() \
			or app.enemies == null or not app.enemies.is_valid() \
			or party.is_defeated() or app.enemies.is_victorious():
			return false
	if _is_energy_card(card_id) or card_id in SPARE_PARTS_IDS or _is_heal_card(card_id) or _cleansing.is_supported_card(card_id):
		# Presentation preflight only: the pool resolver revalidates and commits.
		if app._battle_closed or not deck.turn_active or app.battle_result == null \
			or not app.battle_result.can_continue() or app.battle_result._party != party \
			or app.battle_result._enemies != app.enemies or not party.is_valid() \
			or app.enemies == null or not app.enemies.is_valid() \
			or party.is_defeated() or app.enemies.is_victorious():
			return false
	if card_id in M02PositionCards.IDS:
		if app.enemy_intents == null or _move_context.get(panel, []) != _current_move_context(panel):
			return false
		if app._battle_closed or not deck.turn_active or app.battle_result == null \
			or not app.battle_result.can_continue() or app.battle_result._party != party \
			or app.battle_result._enemies != app.enemies or not party.is_valid() \
			or app.enemies == null or not app.enemies.is_valid() \
			or party.is_defeated() or app.enemies.is_victorious():
			return false
	if _is_path_card(card_id):
		# Presentation preflight only: the one Path authority revalidates and commits.
		if app._battle_closed or not deck.turn_active or app.battle_result == null \
			or not app.battle_result.can_continue() or app.battle_result._party != party \
			or app.battle_result._enemies != app.enemies or not party.is_valid() \
			or app.enemies == null or not app.enemies.is_valid() \
			or party.is_defeated() or app.enemies.is_victorious():
			return false
		var presenter = _path_presenter()
		if presenter == null or not presenter.tinker_path_playable(card_id):
			return false
	var index: int = panel.get_index()
	return index < deck.hand.size() and deck.hand[index] == card_id \
		and panel.get_child(0) is Label and panel.get_child(0).text == card_id


func _on_card_input(event: InputEvent, panel, card_id: String, deck: CombatDeck, party: CombatParty, battle) -> void:
	if event == null or not _eligible(panel, card_id, deck, party, battle):
		return
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var accept: bool = event is InputEventKey and panel.has_focus() and event.is_action_pressed("ui_accept") and not event.echo
	if not click and not accept:
		return
	panel.accept_event()
	if not _pending.is_empty() and _pending.panel == panel:
		return
	_cancel_pending()
	_pending = {"panel": panel, "id": card_id, "choosing": false, "queued": false, "context": _current_move_context(panel)}
	if _cleansing.is_supported_card(card_id):
		_pending.owner_roster = _party.get_heroes().map(func(hero): return [hero.id, hero.position])
	if card_id in ALLY_IDS and not _selection_valid():
		_cancel_pending()
		return
	if click:
		_dragging = true
		_drag_origin = panel.get_global_transform() * event.position
	# Ally selection can arm immediately; target-free mouse casts wait for release.
	if accept or card_id in ALLY_IDS:
		_activate.call_deferred(panel, card_id, deck, party, battle, _token)


func _activate(panel, card_id: String, deck: CombatDeck, party: CombatParty, battle, token: int = -1) -> void:
	if token != _token or _pending.is_empty():
		return
	if not _eligible(panel, card_id, deck, party, battle):
		_cancel_pending()
		return
	if card_id in SPARE_PARTS_IDS and not _selection_valid():
		_cancel_pending()
		return
	if card_id in ALLY_IDS:
		if _pending.get("choosing", false):
			return
		if _selection_valid():
			_choose_target()
		else:
			_cancel_pending()
		return
	_cancel_pending()
	if card_id in M02PositionCards.IDS:
		if CombatPositionSwaps.play_move_card(deck, party, card_id, M02PositionCards.new().get_definition(card_id)):
			_forward_switchback_ordinary_play(card_id)
			var app = get_parent()
			app._refresh_party()
			app._refresh_intents()
			app._refresh_hand()
			_sync_battle()
			app.end_turn_button.grab_focus()
		return
	var energy_before: int = deck.energy
	if not _play_held(deck, party, card_id, 0):
		return
	_report_path_play(card_id, energy_before)
	_forward_switchback_ordinary_play(card_id)
	var app = get_parent()
	app._refresh_party()
	app._refresh_hand()
	_sync_battle()
	app.end_turn_button.grab_focus()


## A real, successful Tinker support play still belongs to the battle's one Path
## authority, so Clockwork's authored discount is a real cost reduction. The Path
## card itself already recorded its own commit.
func _report_path_play(card_id: String, energy_before: int) -> void:
	if _is_path_card(card_id):
		return
	var presenter = _path_presenter()
	if presenter != null:
		presenter.report_tinker_play(card_id, energy_before)


func _selection_valid() -> bool:
	if _pending.is_empty() or not _eligible(_pending.panel, _pending.id, _deck, _party, _battle):
		return false
	if _pending.get("context", []) != _current_move_context(_pending.panel):
		return false
	if _cleansing.is_supported_card(_pending.id):
		if _pending.owner_roster != _party.get_heroes().map(func(hero): return [hero.id, hero.position]):
			return false
		if _pending.has("statuses") and _party.get_hero(_pending.target.position).get("statuses", {}) != _pending.statuses:
			return false
	if _pending.id not in ALLY_IDS:
		return true
	# Presentation preflight only; the support service revalidates and commits.
	var authored: Dictionary = _metadata.definition(_pending.id)
	if not _party.is_valid() or not _deck.turn_active or _deck.energy < int(authored.get("cost", -1)):
		return false
	for hero in _party.get_heroes():
		if hero.id == authored.get("owner", ""):
			return hero.hp > 0 and hero.position in authored.get("from_positions", [])
	return false


func _choose_target() -> void:
	_help_slot.hide()
	_pending.choosing = true
	cancel_button.show()
	var panels: Array[Control] = []
	var app = get_parent()
	for index in range(app.hero_panels.size()):
		var panel: Control = app.hero_panels[index]
		if _party.is_downed(index + 1):
			continue
		panels.append(panel)
		panel.focus_mode = Control.FOCUS_ALL
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cue := Label.new()
		cue.text = "Choose ally"
		# A caption above the existing actor never expands or overprints its state.
		cue.top_level = true
		cue.add_theme_font_size_override("font_size", 12)
		cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(cue)
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(0, 0, 0, 0)
		focus.border_color = Color("ece0c8")
		focus.set_border_width_all(3)
		panel.add_theme_stylebox_override("focus", focus)
		var callback := _on_target_input.bind(panel, index + 1, _token)
		_targets[panel] = {"callback": callback, "cue": cue,
			"position": index + 1, "hero_id": _party.get_hero(index + 1).id}
		panel.gui_input.connect(callback)
	for index in range(panels.size()):
		var panel := panels[index]
		panel.focus_next = panel.get_path_to(panels[(index + 1) % panels.size()])
		panel.focus_previous = panel.get_path_to(panels[(index - 1 + panels.size()) % panels.size()])
		panel.focus_neighbor_bottom = panel.get_path_to(cancel_button)
	if not panels.is_empty():
		panels[0].grab_focus()
	_sync_battle()


func _targets_valid() -> bool:
	for panel in _targets:
		var target: Dictionary = _targets[panel]
		if not is_instance_valid(panel) or get_parent().hero_panels.find(panel) + 1 != target.position:
			return false
		var hero := _party.get_hero(target.position)
		if hero.get("id") != target.hero_id or hero.get("hp", 0) <= 0:
			return false
	return true


func _on_target_input(event: InputEvent, panel, position: int, token: int) -> void:
	if event == null or token != _token or not _targets.has(panel):
		return
	if not _selection_valid() or not _targets_valid():
		_cancel_pending()
		return
	if get_parent().hero_panels.find(panel) + 1 != position:
		return
	if _pending.get("queued", false) or not panel.is_visible_in_tree() or _party.is_downed(position):
		return
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var accept: bool = event is InputEventKey and panel.has_focus() and event.is_action_pressed("ui_accept") and not event.echo
	if not click and not accept:
		return
	panel.accept_event()
	_pending.queued = true
	_pending.target = {"position": position, "hero_id": _targets[panel].hero_id}
	if _cleansing.is_supported_card(_pending.id):
		var statuses: Variant = _party.get_hero(position).get("statuses", {})
		if not statuses is Dictionary:
			_cancel_pending()
			return
		_pending.statuses = statuses.duplicate(true)
		var options: Array[String] = []
		for debuff in CombatSeamstressV3CleansingCards.ELIGIBLE_DEBUFFS:
			var count: Variant = _pending.statuses.get(debuff, 0)
			if count is int and count > 0:
				options.append(debuff)
		if not options.is_empty():
			cleanse_choices = HBoxContainer.new()
			cleanse_choices.name = "CleansingDebuffChoices"
			help_disclosure.hide()
			_help_slot.add_child(cleanse_choices)
			for debuff in options:
				var button := Button.new()
				button.name = debuff.capitalize()
				button.text = "Remove all %s (%d)" % [debuff.capitalize(), _pending.statuses[debuff]]
				button.add_theme_font_size_override("font_size", 18)
				button.pressed.connect(_choose_debuff.bind(debuff, position, token))
				cleanse_choices.add_child(button)
			cleanse_choices.get_child(0).grab_focus()
			_sync_battle()
			return
		_pending.debuff = ""
	_resolve_target.call_deferred(position, token)


func _choose_debuff(debuff: String, position: int, token: int) -> void:
	if token != _token or _pending.is_empty() or _pending.has("debuff"):
		return
	_pending.debuff = debuff
	_resolve_target.call_deferred(position, token)


func _resolve_target(position: int, token: int) -> void:
	if token != _token or not _pending.get("queued", false):
		return
	if not _selection_valid() or not _targets_valid() \
		or _pending.target.position != position \
		or _party.get_hero(position).get("id") != _pending.target.hero_id:
		_cancel_pending()
		return
	var id: String = _pending.id
	var debuff: String = _pending.get("debuff", "")
	if _cleansing.is_supported_card(id) and not _cleansing._prepare(_deck, _party, id, position, debuff).get("ok", false):
		_cancel_pending()
		return
	_cancel_pending()
	if _play_held(_deck, _party, id, position, debuff):
		_forward_switchback_ordinary_play(id)
		var app = get_parent()
		app._refresh_party()
		app._refresh_hand()
		_sync_battle()
		app.end_turn_button.grab_focus()


func _cancel_pending() -> void:
	if is_instance_valid(cleanse_choices):
		cleanse_choices.free()
	cleanse_choices = null
	if is_instance_valid(help_disclosure):
		help_disclosure.show()
	if is_instance_valid(_help_slot):
		_help_slot.hide()
	_dragging = false
	if is_instance_valid(_pending.get("panel")):
		_pending.panel.set_meta("aiming", false)
	_token += 1
	var source = _pending.get("panel")
	_pending.clear()
	for panel in _targets:
		if is_instance_valid(panel):
			if panel.gui_input.is_connected(_targets[panel].callback):
				panel.gui_input.disconnect(_targets[panel].callback)
			if panel.has_focus():
				panel.release_focus()
			panel.focus_mode = Control.FOCUS_NONE
			panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
			panel.focus_next = NodePath()
			panel.focus_previous = NodePath()
			panel.focus_neighbor_bottom = NodePath()
			panel.remove_theme_stylebox_override("focus")
			_targets[panel].cue.free()
	_targets.clear()
	if is_instance_valid(cancel_button):
		cancel_button.hide()
	if is_instance_valid(source) and source.is_inside_tree() and source.is_visible_in_tree():
		source.grab_focus()


func _unbind(panel) -> void:
	if is_instance_valid(panel) and panel.gui_input.is_connected(_bindings[panel]):
		panel.gui_input.disconnect(_bindings[panel])
	_bindings.erase(panel)
	_move_context.erase(panel)
	if _pending.get("panel") == panel:
		_cancel_pending()


func _clear() -> void:
	_restore_action_fonts()
	_receipt_seq = 0
	_metadata.clear()
	_cancel_pending()
	for panel in _bindings.keys():
		_unbind(panel)
	_pending.clear()
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	if is_instance_valid(energy_orb):
		energy_orb.queue_free()
	energy_orb = null
	energy_label = null
	if is_instance_valid(help_label):
		help_label.queue_free()
	help_label = null
	if is_instance_valid(_help_slot):
		_help_slot.hide()
	if is_instance_valid(help_disclosure):
		help_disclosure.queue_free()
	help_disclosure = null
	_help_slot = null
	_information = null
	if is_instance_valid(footer_spring):
		footer_spring.queue_free()
	footer_spring = null
	if is_instance_valid(quilt_row):
		quilt_row.queue_free()
	quilt_row = null
	quilt_patches.clear()
	if is_instance_valid(cancel_button):
		cancel_button.queue_free()
	cancel_button = null
	if is_instance_valid(backing):
		backing.queue_free()
	backing = null
	if is_instance_valid(draw_token):
		draw_token.queue_free()
	draw_token = null
	if is_instance_valid(discard_token):
		discard_token.queue_free()
	discard_token = null
	_hud = null
	_battle = null
	_deck = null
	_party = null
	_play = null
	_block_cards = null
	_energy_cards = null
	_tinker_gadgets = null
	_heal_cards = null



func _ensure_quilt_switchback_bound() -> void:
	var presenter = _path_presenter()
	if presenter != null and presenter.has_method("ensure_quilt_switchback_bound"):
		presenter.ensure_quilt_switchback_bound()


func _owner_for_support_card(card_id: String) -> String:
	var def: Dictionary = _metadata.definition(card_id)
	var owner: String = str(def.get("owner", ""))
	if owner in CombatQuiltBonus.HERO_IDS:
		return owner
	var starter := StarterCards.new().get_definition(card_id)
	owner = str(starter.get("owner", ""))
	if owner in CombatQuiltBonus.HERO_IDS:
		return owner
	return ""


func _forward_switchback_ordinary_play(card_id: String) -> void:
	var app = get_parent()
	if app == null or not is_instance_valid(app):
		return
	_ensure_quilt_switchback_bound()
	var quilt: CombatQuiltBonus = app._quilt_bonus
	if quilt == null or not is_instance_valid(quilt) or not quilt is CombatQuiltBonus or not quilt.is_switchback_active():
		return
	var owner: String = _owner_for_support_card(card_id)
	if owner.is_empty() or not owner in CombatQuiltBonus.HERO_IDS:
		return
	_receipt_seq += 1
	var receipt_id := "support_%d" % _receipt_seq
	quilt.observe_confirmed_play(receipt_id, owner)
