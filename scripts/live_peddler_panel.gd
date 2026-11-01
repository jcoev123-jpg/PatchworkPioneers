class_name LivePeddlerPanel
extends Control
## V3-3 Peddler presentation and detached intents only.
##
## One genuine OPEN RunPeddlerVisit renders as three owner-labelled, priced card
## buys (one per party hero), one priced patch buy and the free Leave. The view
## never buys, leaves, debits gold, appends a card or patch, samples stock or
## advances the run RNG: a press publishes exactly one deeply detached intent
##
##   {node_id, kind, id (buys only), expected_state, expected_stock}
##
## whose kind is "card", "trinket" or "leave". An external controller must
## re-read the visit and pass those values unchanged to
## RunPeddlerVisit.choose_purchase()/leave(), which stay the single purchase
## and Leave authority. The live Shop route mounts this view through app.gd.
##
## Visible shortcuts: each of the five mounted captions opens with its own
## numeral key label (1/2/3 the cards, 4 the patch, 0 Leave) - exactly the
## unmodified keys _input below already dispatches, so a keyboard player can
## read the shortcut on the interactive surface instead of guessing it.
##
## Read-only ability preview: hovering or focusing one offered card repeats its
## authored energy cost and CardShortRules sentence in the existing status band
## and leaves the complete sentences in that card Button's tooltip. The preview
## is resolved from the offered ID in the same authored catalogs the seeded
## stock generator validates against, only while the definition's owner matches
## the offer; anything unresolvable reads "Card details unavailable" instead of
## a guessed number. It never changes a quoted price, the five actions, the
## purchase intent or the visit state.
##
## The priced patch row repeats the one trusted Patch Stall power preview:
## hovering or focusing it shows the audited LivePatchStallPanel projection's
## exact slot, power and trigger in the status band (the complete rule stays
## in the patch Button's tooltip), and anything that audit cannot prove reads
## PATCH_DETAILS_UNAVAILABLE instead of a guessed buff.
##
## VIS-A: the sewn market art floats on a genuinely opaque jewel-toned fabric
## (the shipped reward_panel.png source alpha may be transparent), and each of
## the five actions is a compact, clearly bordered sewn ticket: the illustrated
## market stays visible beside the quotes instead of behind a muddy,
## translucent, edge-to-edge slab.
##
## VIS-B: that same authored market image is the only animated decoration: a
## gentle deterministic ~17-second breathe/pan confined to an input-inert,
## clipped decorative layer under the fixed sewn outline, priced tickets,
## status labels and route-added wearer selector. It starts only for a
## visible, OPEN, still-current bound visit with loadable art, stops and
## resets on every close/hide/rebind/stale path, and honors
## accessibility/reduced_motion (default false) with a nullable override.
signal intent_requested(intent: Dictionary)

const PANEL_ART := "res://assets/paper/ui/reward_panel.png"
const BUTTON_ART := "res://assets/paper/ui/reward_button.png"
const THEME_PATH := "res://assets/fonts/patchwork_theme.tres"
const TITLE_TEXT := "PEDDLER  ·  a keepsake for the road"
const STATUS_OPEN := "Choose one of your party's three cards, the sewn patch, or leave for free."
const STATUS_CLOSED := "No open Peddler visit. No offer can be submitted."
const DETAILS_UNAVAILABLE := "Card details unavailable"
const PATCH_DETAILS_UNAVAILABLE := "Power details unavailable"
const PATCH_TORN_WARNING := "Patch powers do not work while the wearer is Torn."
## The two unlocked P12 Heirlooms supplement the ordinary/P8 audit only
## after their complete authored records pass canonical authentication.
const NEEDLE_ECHO_ID := "needle_echo"
const NEEDLE_ECHO_SLOT := "HEAD"
const NEEDLE_ECHO_SHORT := "+1 damage on the first confirmed Pinned-enemy hit each turn"
const NEEDLE_ECHO_FULL := "Once per turn, the first confirmed hit by this living, untorn wearer on a Pinned enemy deals exactly +1 damage."
const SHARED_HEM_ID := "shared_hem"
const SHARED_HEM_SLOT := "ARM"
const SHARED_HEM_SHORT := "+1 Block once/turn when a different living hero actually gains Block"
const SHARED_HEM_FULL := "Once per turn, after a different living hero actually gains Block, this living, untorn wearer gains exactly +1 Block."
const ELLIPSIS := "..."
const WALLET_CLOSED := "Wallet unavailable"
## The numeral keys _input already routes to the five mounted actions, in offer
## order (1/2/3 the three hero cards, 4 the patch, 0 Leave). Each action's own
## caption opens with its label so the working shortcut is visible on the
## interactive surface itself.
const ACTION_KEY_LABELS: Array[String] = ["1", "2", "3", "4", "0"]
const LEAVE_TEXT := "0  ·  Leave  ·  FREE"
const CARD_KIND := "card"
const PATCH_KIND := "trinket"
const LEAVE_KIND := "leave"
const CARD_COUNT := 3
const PANEL_SIZE := Vector2(900, 600)
## The status band's designed inner width at 1280x720: the compact single-line
## preview is kept inside it at the shipped 18px face, whatever a Label's own
## minimum-size growth would allow, so a long line can never spill over the
## sewn panel.
const STATUS_WIDTH := 822.0
## VIS-A legibility: every priced offer is one compact sewn ticket, not a
## full-width slab, so the imported market art stays uncovered beside the
## quotes at 1280x720.
const TICKET_WIDTH := 640.0
const CARD_TICKET_SIZE := Vector2(TICKET_WIDTH, 78)
const PATCH_TICKET_SIZE := Vector2(TICKET_WIDTH, 78)
const LEAVE_TICKET_SIZE := Vector2(TICKET_WIDTH, 58)
## The illustrated market column the compact tickets must leave visible on
## the sewn panel's right side.
const UNCOVERED_ART := 160.0
const CREAM := Color("#f3e6cf")
const GOLD := Color("#e9c47d")
const THREAD := Color("#806852")
const PLUM := Color("#37293f")
const TEAL := Color("#214b50")
const OXBLOOD := Color("#713544")
const INK := Color("#191b2a")
const DIM := Color("#655b58")
const CARD_FABRIC := Color("#f1e3cf")
const PATCH_FABRIC := Color("#dbe8dd")
const EXIT_FABRIC := Color("#efd2a4")
const REDUCED_MOTION_SETTING := "accessibility/reduced_motion"
## One slow deterministic presentation cycle (~17s) for the authored market
## image: about a 1% scale breath plus a 3-4 px drift, both exactly at rest
## at elapsed zero, driven only by accumulated presentation delta (never
## seeded or global RNG, never the wall clock).
const ART_MOTION_PERIOD := 17.0
const ART_MOTION_BREATH := 0.01
const ART_MOTION_PAN := Vector2(3.0, 4.0)
## The drifting market image stays oversized by this margin, so its gentle
## breath/pan never reveals an unpainted edge inside the clipped layer.
const ART_MOTION_MARGIN := 10.0


## Input-transparent running stitch over the sewn paper surface.
class SewnBorder extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x < 24 or size.y < 24:
			return
		var r := Rect2(Vector2(9, 8), size - Vector2(18, 16))
		for y in [r.position.y, r.end.y]:
			draw_dashed_line(Vector2(r.position.x, y), Vector2(r.end.x, y), THREAD, 1.5, 8.0)
		for x in [r.position.x, r.end.x]:
			draw_dashed_line(Vector2(x, r.position.y), Vector2(x, r.end.y), THREAD, 1.5, 8.0)


var title_label: Label
var wallet_label: Label
var status_label: Label
var card_buttons: Array[Button] = []
var patch_button: Button
var leave_button: Button

var _visit: RunPeddlerVisit
var _source: Dictionary = {}
var _epoch := 0
var _submitted := false
var _pending_intent: Dictionary = {}
var _connections: Dictionary = {} # Only view-owned Button.pressed -> Callable.
var _preview_index := -1 # Card row whose read-only preview fills the status band.
var _hover_index := -1 # Card row under the pointer; -1 when no card is hovered.
var _patch_hover_active := false # Whether the patch button is under the pointer.
var _catalogs: Array = [] # Read-only authored catalogs for the preview, built once.
var _patch_projection: Dictionary = {} # Cached audited patch slots/previews, built once.
## The authored market image as one input-inert decorative layer UNDER the
## fixed sewn outline, priced tickets, status labels and any route-added
## wearer selector. Only this layer's gentle presentation transform moves;
## the panel itself and every action descendant stay exactly fixed.
var _art_drift: Panel = null
var _art_drift_base := Vector2.ZERO
var _art_motion_elapsed := 0.0
## Nullable explicit reduced-motion override for focused tests and hosts;
## null follows ProjectSettings accessibility/reduced_motion (default false).
var reduced_motion_override: Variant = null


func _ready() -> void:
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var master := _load_theme()
	if master != null:
		theme = master
	# Genuinely opaque sewn fabric first: the shipped reward_panel.png may
	# carry transparent alpha, so a solid jewel-toned backing keeps the
	# illustrated market from showing through under the labels (VIS-A).
	var fabric := Panel.new()
	fabric.name = "FabricBacking"
	fabric.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fabric)
	fabric.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fabric.add_theme_stylebox_override("panel", _fabric_style())
	# The imported market art floats on the opaque fabric; a missing or
	# unreadable image falls back to that same solid fabric.
	var backing := Panel.new()
	backing.name = "PanelArt"
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.add_theme_stylebox_override("panel", _panel_style())
	# VIS-B: the authored market image itself becomes an input-inert clipped
	# decoration UNDER the fixed sewn outline (SewnBorder below) and every
	# priced ticket, status label and route-added wearer selector; the opaque
	# static FabricBacking and the static PanelArt copy underneath keep the
	# sewn surface readable whether or not the gentle deterministic drift
	# below is running.
	backing.clip_contents = true
	_install_art_drift(backing)
	backing.add_child(SewnBorder.new())
	visibility_changed.connect(_on_art_visibility_changed)
	title_label = _label(TITLE_TEXT, Vector2(36, 20), Vector2(828, 44), 29, GOLD)
	wallet_label = _label("", Vector2(39, 68), Vector2(822, 32), 22, CREAM)
	status_label = _label("", Vector2(39, 102), Vector2(822, 30), 18, CREAM)
	for i in range(CARD_COUNT):
		card_buttons.append(_button("", Vector2(39, 142 + i * 88), CARD_TICKET_SIZE, CARD_FABRIC, 20))
	patch_button = _button("", Vector2(39, 406), PATCH_TICKET_SIZE, PATCH_FABRIC, 20)
	leave_button = _button(LEAVE_TEXT, Vector2(39, 498), LEAVE_TICKET_SIZE, EXIT_FABRIC, 24)
	_wire_previews()
	_refresh()
	_focus_initial()


## The physical number keys are an alias for the five mounted Buttons: a valid
## press only forwards to that Button's own `pressed` signal, so keyboard, mouse,
## Tab and Enter share one authenticated path and this handler never buys,
## leaves, spends or mints an intent of its own. It stays inert - and leaves the
## key to the rest of the game - when the panel is not open/visible, the GUI
## focus belongs elsewhere, the key is a release/echo/modified/unrelated one, or
## the addressed action is detached, hidden or disabled (sold or unaffordable).
func _input(event: InputEvent) -> void:
	if not _active():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	# is_ancestor_of() needs a real node: with nothing focused (or focus on a
	# control outside this panel) no shortcut belongs to the Peddler.
	if focus_owner == null or (focus_owner != self and not is_ancestor_of(focus_owner)):
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.is_pressed() or key_event.is_echo():
		return
	if key_event.shift_pressed or key_event.alt_pressed or key_event.ctrl_pressed or key_event.meta_pressed:
		return

	var button: Button = null
	match key_event.keycode:
		KEY_1, KEY_KP_1:
			button = card_buttons[0]
		KEY_2, KEY_KP_2:
			button = card_buttons[1]
		KEY_3, KEY_KP_3:
			button = card_buttons[2]
		KEY_4, KEY_KP_4:
			button = patch_button
		KEY_0, KEY_KP_0:
			button = leave_button

	if button == null:
		return
	# Only an authentic, still-mounted, visible and ENABLED action of this panel
	# may receive the key press. A sold or unaffordable row neither emits a
	# synthetic Button.pressed nor swallows the key from the rest of the game.
	if not _attached(button) or button.disabled:
		return
	get_viewport().set_input_as_handled()
	button.pressed.emit()


## A detached copy of the master Theme so the panel never mutates the project
## resource; a missing theme leaves Godot's default font and the per-control
## overrides below, which stay readable.
static func _load_theme() -> Theme:
	if not ResourceLoader.exists(THEME_PATH, "Theme"):
		return null
	var master := load(THEME_PATH) as Theme
	if master == null:
		return null
	return master.duplicate(true) as Theme


## The genuinely opaque sewn fabric behind the imported market art: solid
## deep-jewel paper with a stitched edge, whether or not that art loads. This
## is the one alpha-1 backdrop under every label and ticket (VIS-A).
func _fabric_style() -> StyleBoxFlat:
	return _style(PLUM, THREAD, 5)


func _panel_style() -> StyleBox:
	if ResourceLoader.exists(PANEL_ART, "Texture2D"):
		var texture := ResourceLoader.load(PANEL_ART) as Texture2D
		if texture != null:
			var style := StyleBoxTexture.new()
			style.texture = texture
			style.modulate_color = Color("#5a4272")
			style.set_texture_margin_all(24)
			return style
	return _fabric_style()


## Every sewn ticket face carries a clearly readable border: the default
## width 4 keeps each compact offer visibly edged instead of a flat slab.
func _style(fill: Color, edge: Color, width: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(8)
	return style


## The shipped sewn button art as a gold focus ring, with the flat ring as a
## fallback when that texture is unavailable.
func _focus_style() -> StyleBox:
	if ResourceLoader.exists(BUTTON_ART, "Texture2D"):
		var texture := ResourceLoader.load(BUTTON_ART) as Texture2D
		if texture != null:
			var sewn := StyleBoxTexture.new()
			sewn.texture = texture
			sewn.modulate_color = GOLD
			sewn.draw_center = false
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				sewn.set_texture_margin(side, 8)
				sewn.set_expand_margin(side, 3)
			return sewn
	var ring := _style(Color.TRANSPARENT, GOLD, 4)
	ring.draw_center = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		ring.set_expand_margin(side, 3)
	return ring


func _label(value: String, at: Vector2, extent: Vector2, font_size: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 2)
	add_child(label)
	return label


func _button(value: String, at: Vector2, extent: Vector2, fill: Color, font_size: int) -> Button:
	var button := Button.new()
	button.text = value
	button.position = at
	button.size = extent
	button.custom_minimum_size = extent
	button.focus_mode = Control.FOCUS_ALL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_color_override("font_disabled_color", DIM)
	button.add_theme_stylebox_override("normal", _style(fill, THREAD))
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.06), OXBLOOD))
	button.add_theme_stylebox_override("pressed", _style(fill.darkened(0.10), OXBLOOD))
	button.add_theme_stylebox_override("disabled", _style(Color("#dad1c5"), DIM))
	button.add_theme_stylebox_override("focus", _focus_style())
	add_child(button)
	# Opaque contrasting fabric carries the text; the imported sewn-button
	# image outlines the ticket without painting over a single authored word.
	if ResourceLoader.exists(BUTTON_ART, "Texture2D"):
		var fabric := ResourceLoader.load(BUTTON_ART) as Texture2D
		if fabric != null:
			var edging := Panel.new()
			edging.name = "FabricEdging"
			edging.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var seam := StyleBoxTexture.new()
			seam.texture = fabric
			seam.draw_center = false
			seam.modulate_color = Color(1.0, 0.93, 0.78, 0.8)
			seam.set_texture_margin_all(13)
			edging.add_theme_stylebox_override("panel", seam)
			button.add_child(edging)
			edging.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(SewnBorder.new())
	return button


## The one animated decoration this panel ever shows: the already-authored
## reward_panel.png market image, mounted as an input-inert child UNDER the
## fixed sewn outline, priced tickets, status labels and any route-added
## wearer selector. A missing or unreadable image installs no layer at all,
## keeps the same static readable fabric fallback and never raises an error.
func _install_art_drift(host_panel: Panel) -> void:
	if not ResourceLoader.exists(PANEL_ART, "Texture2D"):
		return
	var texture := ResourceLoader.load(PANEL_ART) as Texture2D
	if texture == null:
		return
	var layer := Panel.new()
	layer.name = "PanelArtDrift"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.focus_mode = Control.FOCUS_NONE
	layer.add_theme_stylebox_override("panel", _panel_style())
	host_panel.add_child(layer)
	_art_drift_base = Vector2.ONE * -ART_MOTION_MARGIN
	layer.position = _art_drift_base
	layer.size = PANEL_SIZE + Vector2.ONE * (ART_MOTION_MARGIN * 2.0)
	layer.custom_minimum_size = layer.size
	layer.pivot_offset = layer.size * 0.5
	_art_drift = layer


## Pure deterministic presentation transform: a slow ~1% scale breath plus a
## few pixels of drift, both exactly at rest at elapsed zero and at every
## full period. No RNG and no wall clock; the caller accumulates the delta.
static func art_motion_transform_at(elapsed: float) -> Dictionary:
	var cycle := fposmod(elapsed, ART_MOTION_PERIOD) / ART_MOTION_PERIOD
	var breath := 0.5 - 0.5 * cos(TAU * cycle)
	var clock := TAU * cycle
	return {
		"scale": 1.0 + ART_MOTION_BREATH * breath,
		"offset": Vector2(sin(clock), sin(2.0 * clock)) * ART_MOTION_PAN,
	}


## Motion runs only while a genuinely mounted, visible panel holds a valid
## OPEN, still-current bound visit with the authored art loaded and reduced
## motion not requested. A consumed, stale or hidden panel stops it here.
func art_motion_active() -> bool:
	return _art_drift != null and is_instance_valid(_art_drift) \
			and _active() and not _reduced_motion_active()


## Current decorative transform: the static baseline whenever motion is
## stopped, otherwise the deterministic transform at the accumulated
## presentation time.
func art_motion_transform() -> Dictionary:
	if not art_motion_active():
		return {"scale": 1.0, "offset": Vector2.ZERO}
	return art_motion_transform_at(_art_motion_elapsed)


## Deterministic presentation-time advance for focused tests; live play
## accumulates the very same clock through _process with the engine delta.
func advance_art_motion(delta: float) -> void:
	if delta <= 0.0 or not art_motion_active():
		return
	_art_motion_elapsed += delta
	_apply_art_motion()


## The setting defaults to off; a nullable explicit override lets tests and
## hosts force the presentation on or off deterministically.
func set_reduced_motion_override(value: Variant) -> void:
	reduced_motion_override = value
	if not art_motion_active():
		_reset_art_motion()


func _reduced_motion_active() -> bool:
	if reduced_motion_override != null:
		return bool(reduced_motion_override)
	return bool(ProjectSettings.get_setting(REDUCED_MOTION_SETTING, false))


## Every stop path (bind(null)/close(), hide, exit-tree, consumed or stale
## visit, reduced motion) restores the exact static baseline position, scale
## and pivot of the decorative image.
func _reset_art_motion() -> void:
	if _art_motion_elapsed == 0.0:
		return
	_art_motion_elapsed = 0.0
	if is_instance_valid(_art_drift):
		_art_drift.position = _art_drift_base
		_art_drift.scale = Vector2.ONE
		_art_drift.pivot_offset = _art_drift.size * 0.5


func _apply_art_motion() -> void:
	if not is_instance_valid(_art_drift):
		return
	var motion := art_motion_transform_at(_art_motion_elapsed)
	_art_drift.pivot_offset = _art_drift.size * 0.5
	_art_drift.scale = Vector2.ONE * float(motion["scale"])
	_art_drift.position = _art_drift_base + motion["offset"]


func _on_art_visibility_changed() -> void:
	if not is_visible_in_tree():
		_reset_art_motion()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_reset_art_motion()


## Accumulated presentation delta alone drives the decoration; it never calls
## the visit, the purchase service, the route or any RNG.
func _process(delta: float) -> void:
	if not art_motion_active():
		_reset_art_motion()
		return
	if delta > 0.0:
		_art_motion_elapsed += delta
		_apply_art_motion()


## Only a genuine valid OPEN Peddler projection may be quoted. A rejected,
## USED or LEFT visit, a malformed stock/state or a shape this panel cannot
## label binds closed with no payable action.
func bind(visit: RunPeddlerVisit) -> void:
	_epoch += 1
	_retire_callbacks()
	_visit = null
	_source = {}
	_submitted = false
	_pending_intent.clear()
	# A different bound visit (or none at all) restarts the ambient art
	# decoration from its exact static baseline.
	_reset_art_motion()
	if visit != null and visit.is_valid() and visit.is_open():
		var state: Dictionary = visit.read_state()
		if _valid_open_state(state):
			_visit = visit
			_source = state.duplicate(true)
	if is_node_ready():
		visible = true
		_refresh()
		_focus_initial()


func close() -> void:
	bind(null)
	hide()


## The authentic read_state() shape this view can present: three distinct party
## heroes, one offered card per hero at its authored owner and whole gold price,
## one patch at its authored whole gold price, and the current wallet.
static func _valid_open_state(state: Variant) -> bool:
	if typeof(state) != TYPE_DICTIONARY:
		return false
	var projection: Dictionary = state
	if projection.get("ok") != true or projection.get("status") != "open":
		return false
	var node_id: Variant = projection.get("node_id")
	if typeof(node_id) != TYPE_STRING or str(node_id).strip_edges().is_empty() \
			or str(node_id) != str(node_id).strip_edges():
		return false
	var ledger: Variant = projection.get("state")
	var stock: Variant = projection.get("stock")
	if typeof(ledger) != TYPE_DICTIONARY or typeof(stock) != TYPE_DICTIONARY:
		return false
	var party: Variant = ledger.get("party_ids")
	if typeof(party) != TYPE_ARRAY \
			or _distinct_ids(party) != CARD_COUNT:
		return false
	var party_set := {}
	for hero in party:
		party_set[hero] = true
	for field in ["deck", "trinkets"]:
		var entries: Variant = ledger.get(field)
		if typeof(entries) != TYPE_ARRAY:
			return false
		for entry in entries:
			if typeof(entry) != TYPE_STRING or str(entry).strip_edges().is_empty():
				return false
	if typeof(ledger.get("gold")) != TYPE_INT or int(ledger["gold"]) < 0:
		return false
	var cards: Variant = stock.get("cards")
	var patches: Variant = stock.get("trinkets")
	if typeof(cards) != TYPE_ARRAY or cards.size() != CARD_COUNT \
			or typeof(patches) != TYPE_ARRAY or patches.size() != 1:
		return false
	var card_ids := {}
	var owners := {}
	for record in cards:
		if typeof(record) != TYPE_DICTIONARY:
			return false
		var offer: Dictionary = record
		var offer_id: Variant = offer.get("id")
		var owner: Variant = offer.get("owner")
		if typeof(offer_id) != TYPE_STRING or str(offer_id).strip_edges().is_empty() \
				or card_ids.has(offer_id):
			return false
		if typeof(owner) != TYPE_STRING or not party_set.has(owner) or owners.has(owner):
			return false
		if typeof(offer.get("price")) != TYPE_INT or int(offer["price"]) < 0 \
				or typeof(offer.get("sold")) != TYPE_BOOL:
			return false
		card_ids[offer_id] = true
		owners[owner] = true
	var patch: Variant = patches[0]
	if typeof(patch) != TYPE_DICTIONARY:
		return false
	var priced_patch: Dictionary = patch
	if typeof(priced_patch.get("id")) != TYPE_STRING \
			or str(priced_patch["id"]).strip_edges().is_empty() \
			or typeof(priced_patch.get("price")) != TYPE_INT \
			or int(priced_patch["price"]) < 0 \
			or typeof(priced_patch.get("sold")) != TYPE_BOOL:
		return false
	return true


## Distinct, non-blank string entries, or -1 when one is malformed or repeated:
## a duplicated or blank hero can never be labelled.
static func _distinct_ids(entries: Array) -> int:
	var seen := {}
	for entry in entries:
		if typeof(entry) != TYPE_STRING or str(entry).strip_edges().is_empty() or seen.has(entry):
			return -1
		seen[entry] = true
	return seen.size()


func _source_current() -> bool:
	if _visit == null or _submitted or not _visit.is_valid() or not _visit.is_open():
		return false
	if _source.is_empty() or not _valid_open_state(_source):
		return false
	return _visit.read_state() == _source


func _active() -> bool:
	return is_inside_tree() and is_visible_in_tree() and _source_current()


## "warden_strike" -> "Warden Strike": the authored ID stays readable on screen
## even when no display-name catalog is consulted.
static func readable_id(item_id: String) -> String:
	return item_id.replace("_", " ").capitalize()


func _gold() -> int:
	return int(_source["state"]["gold"])


func _offer(index: int) -> Dictionary:
	return _source["stock"]["cards"][index]


func _patch_offer() -> Dictionary:
	return _source["stock"]["trinkets"][0]


func _caption(prefix: String, item_id: String, price: int, sold: bool) -> String:
	var line := "%s  ·  %s  ·  %d gold" % [
			prefix, readable_id(item_id), price]
	if sold:
		return line + "  ·  SOLD"
	if _gold() < price:
		return line + "  ·  short %d" % (price - _gold())
	return line


## Line one opens with this row's own visible key label (1/2/3), then the
## source-verified owner; the entire source-quoted price and state stays on
## line one too. Only the catalog display name and the catalog effect may be
## shortened. Both lines are measured against the real Button font rather than
## left to autowrap/clipping.
func _card_caption(index: int) -> String:
	var offer := _offer(index)
	var details := _card_details(index)
	var button := card_buttons[index]
	var font := button.get_theme_font("font")
	var px := button.get_theme_font_size("font_size")
	var width := maxf(0.0, button.size.x - 32.0)
	var prefix := "%s  ·  %s  ·  " % [ACTION_KEY_LABELS[index],
			str(offer["owner"]).capitalize()]
	var suffix := "  ·  %d gold" % int(offer["price"])
	if bool(offer["sold"]):
		suffix += "  ·  SOLD"
	elif _gold() < int(offer["price"]):
		suffix += "  ·  short %d" % (int(offer["price"]) - _gold())
	var name := str(details.get("name", DETAILS_UNAVAILABLE))
	var available_name := width - _row_width(font, prefix + suffix, px)
	var first := prefix + _fit_row_text(name, available_name, font, px) + suffix
	if details.is_empty():
		return first + "\n" + DETAILS_UNAVAILABLE
	var energy := "%d energy  ·  " % int(details["cost"])
	var rule_width := width - _row_width(font, energy, px)
	var rule := _fit_card_rule(str(details["line"]), rule_width, font, px)
	return first + "\n" + energy + rule


func _row_width(font: Font, value: String, px: int) -> float:
	if font == null:
		return 0.0
	return font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


## The on-row projection is intentionally lossy, but a visible ellipsis
## distinguishes it from the complete, unmodified authored tooltip.
func _fit_row_text(value: String, width: float, font: Font, px: int) -> String:
	if font == null or _row_width(font, value, px) <= width:
		return value
	if width <= _row_width(font, ELLIPSIS, px):
		return ELLIPSIS
	var low := 0
	var high := value.length()
	while low < high:
		var middle := int((low + high + 1) / 2)
		if _row_width(font, value.substr(0, middle).strip_edges() + ELLIPSIS, px) <= width:
			low = middle
		else:
			high = middle - 1
	var head := value.substr(0, low).strip_edges()
	var word_end := head.rfind(" ")
	if word_end > 0:
		head = head.substr(0, word_end)
	return head.strip_edges() + ELLIPSIS


## When an authored rule ends in a condition, retain that qualifier alongside
## the mechanic rather than turning conditional damage/Block into an unconditional
## claim. No numbers or effects are reconstructed from the offer's ID.
func _fit_card_rule(line: String, width: float, font: Font, px: int) -> String:
	if font == null or _row_width(font, line, px) <= width:
		return line
	for marker in [" if ", " when ", " while ", " after ", " unless ", " per "]:
		var split := line.find(marker)
		if split > 0:
			var qualification := line.substr(split)
			if _row_width(font, qualification, px) < width:
				var lead := _fit_row_text(line.substr(0, split), width -
						_row_width(font, qualification, px) -
						_row_width(font, ELLIPSIS, px), font, px)
				var result := lead + qualification
				if _row_width(font, result, px) <= width:
					return result
	return _fit_row_text(line, width, font, px)


func _patch_caption() -> String:
	var offer := _patch_offer()
	# The patch row is the fourth action: its caption opens with its own "4"
	# key label exactly as the card rows open with 1/2/3 and Leave with 0.
	var quote := _caption(ACTION_KEY_LABELS[CARD_COUNT], str(offer["id"]),
			int(offer["price"]), bool(offer["sold"]))
	var details := _patch_details()
	if details.is_empty():
		return quote + "\n" + PATCH_DETAILS_UNAVAILABLE
	var font := patch_button.get_theme_font("font")
	var px := patch_button.get_theme_font_size("font_size")
	var slot := "%s  ·  " % str(details["slot"])
	var short := _fit_row_text(str(details["short"]),
			maxf(0.0, patch_button.size.x - 32.0 - _row_width(font, slot, px)), font, px)
	return quote + "\n" + slot + short


func _wallet_caption() -> String:
	return "Wallet  ·  %d gold" % _gold()


## One-shot signal wiring for the display-only preview. These listeners only
## repaint the status band and never mint an intent, so they carry no epoch:
## each recomputes from the currently bound source and silently does nothing
## once that source is gone.
func _wire_previews() -> void:
	for i in range(CARD_COUNT):
		var button := card_buttons[i]
		button.mouse_entered.connect(_on_card_hover.bind(i, true))
		button.mouse_exited.connect(_on_card_hover.bind(i, false))
		button.focus_entered.connect(_on_card_focus.bind(i))
		button.focus_exited.connect(_on_preview_refresh)
	patch_button.mouse_entered.connect(_on_patch_hover.bind(true))
	patch_button.mouse_exited.connect(_on_patch_hover.bind(false))
	patch_button.focus_entered.connect(_on_patch_focus)
	patch_button.focus_exited.connect(_on_preview_refresh)
	# A host route may re-flow this ticket after bind (the mounted Peddler
	# moves and narrows the patch row), and the width-fitted abbreviation is
	# part of this exact source's honest projection: re-fit it whenever the
	# real button geometry changes so a later press still re-reads the very
	# caption that is on screen.
	patch_button.resized.connect(_on_patch_resized)
	leave_button.mouse_entered.connect(_on_plain_hover)
	leave_button.focus_entered.connect(_on_preview_refresh)
	leave_button.focus_exited.connect(_on_preview_refresh)


func _on_card_hover(index: int, entered: bool) -> void:
	if index < 0 or index >= CARD_COUNT:
		return
	if entered:
		_hover_index = index
	elif _hover_index == index:
		_hover_index = -1
	_sync_preview()


## Keeps the sewn patch ticket the honest projection of its bound source even
## after the hosting route resizes its row: the measured abbreviation always
## matches the actual button, so the press audit can never reject a genuine
## open offer merely because its geometry changed after bind.
func _on_patch_resized() -> void:
	if title_label == null or patch_button == null or _source.is_empty():
		return
	if _source_current():
		patch_button.text = _patch_caption()


func _on_plain_hover() -> void:
	_hover_index = -1
	_sync_preview()


func _on_patch_hover(entered: bool) -> void:
	_patch_hover_active = entered
	_sync_preview()


func _on_patch_focus() -> void:
	_sync_preview()


func _on_card_focus(index: int) -> void:
	if index < 0 or index >= CARD_COUNT:
		return
	_sync_preview()


## focus_exited fires before the next control receives focus, so the recompute
## waits a frame for the new focus owner instead of flashing the wrong row.
func _on_preview_refresh() -> void:
	_sync_preview.call_deferred()


## The card row the preview currently describes: the pointer wins while it is
## over an offer, otherwise the keyboard focus ring decides, otherwise none.
func _focused_card() -> int:
	for i in range(CARD_COUNT):
		if is_instance_valid(card_buttons[i]) and card_buttons[i].has_focus():
			return i
	return -1


func _sync_preview() -> void:
	if status_label == null:
		return
	if not _active():
		_hover_index = -1
		_preview_index = -1
		for button in card_buttons:
			if is_instance_valid(button):
				button.tooltip_text = ""
		if is_instance_valid(patch_button):
			patch_button.tooltip_text = ""
		_patch_hover_active = false
		if not _source_current():
			status_label.text = STATUS_CLOSED
		return
	# The pointer wins while it is over any offer: a hovered patch outranks
	# a focused card exactly as a hovered card outranks the patch's focus ring,
	# so a mouse-only player always sees the row actually under the pointer.
	var index := _hover_index
	if index < 0 and not _patch_hover_active:
		index = _focused_card()
	if index >= 0:
		_apply_preview(index)
	elif _patch_hover_active or (patch_button != null and patch_button.has_focus()):
		_apply_patch_preview()
	else:
		_apply_preview(-1)


func _apply_preview(index: int) -> void:
	_preview_index = index if index >= 0 and index < CARD_COUNT else -1
	if status_label == null:
		return
	if _preview_index < 0:
		status_label.text = STATUS_OPEN
		return
	status_label.text = _clamp_status(_card_preview(_preview_index))


func _apply_patch_preview() -> void:
	_preview_index = -1
	if status_label == null:
		return
	status_label.text = _clamp_status(_patch_preview())


## The authored catalogs the seeded Peddler stock generator itself validates
## candidate offers against. They are immutable authored data, so one instance
## is reused for every preview on this panel.
func _preview_catalogs() -> Array:
	if _catalogs.is_empty():
		_catalogs = RunShopStockOffers._peddler_catalogs()
	return _catalogs


## The offered card's own authored record, or {} when the exact offered ID has
## no definition, the definition's owner is not the verified offer owner, or
## the record cannot be stated truthfully (non-integer cost, no effect line).
func _card_details(index: int) -> Dictionary:
	if _source.is_empty() or index < 0 or index >= CARD_COUNT:
		return {}
	var offer := _offer(index)
	var offer_id := str(offer.get("id", ""))
	var offer_owner := str(offer.get("owner", ""))
	if offer_id.is_empty() or offer_owner.is_empty():
		return {}
	var found := RunShopStockOffers._find_card_definition(offer_id, _preview_catalogs())
	if found.is_empty():
		return {}
	var definition: Variant = found.get("def")
	if typeof(definition) != TYPE_DICTIONARY or (definition as Dictionary).is_empty():
		return {}
	var card: Dictionary = definition
	if typeof(card.get("id")) != TYPE_STRING or str(card["id"]) != offer_id:
		return {}
	if typeof(card.get("owner")) != TYPE_STRING or str(card["owner"]) != offer_owner:
		return {}
	if typeof(card.get("cost")) != TYPE_INT or int(card["cost"]) < 0:
		return {}
	var described := CardShortRules.describe(card)
	if described.get("known") != true:
		return {}
	var line := str(described.get("line", "")).strip_edges()
	if line.is_empty():
		return {}
	var display_name := str(card.get("display_name", "")).strip_edges()
	return {
		"id": offer_id,
		"owner": offer_owner,
		"name": display_name if not display_name.is_empty() else readable_id(offer_id),
		"cost": int(card["cost"]),
		"line": line,
		"unknown": described.get("unknown") == true,
	}


## The complete single-line preview: exact offered ID, its authored owner, its
## authored energy cost and the CardShortRules sentences that print the real
## effects (including the honest "other effects not described" sentence).
func _card_preview(index: int) -> String:
	if _source.is_empty() or index < 0 or index >= CARD_COUNT:
		return DETAILS_UNAVAILABLE
	var offer := _offer(index)
	var details := _card_details(index)
	if details.is_empty():
		return "%s  ·  %s  ·  %s" % [str(offer.get("owner", "")).capitalize(),
				readable_id(str(offer.get("id", ""))), DETAILS_UNAVAILABLE]
	return "%s  ·  %s  ·  %s  ·  %d energy  ·  %s" % [
			str(details["owner"]).capitalize(), str(details["name"]), str(details["id"]),
			int(details["cost"]), str(details["line"])]


## The full ability text for one offered card, kept in that card Button's
## tooltip even when the status band can only show a shortened display line.
func _card_tooltip(index: int) -> String:
	if _source.is_empty() or index < 0 or index >= CARD_COUNT:
		return ""
	var offer := _offer(index)
	var details := _card_details(index)
	if details.is_empty():
		return "%s  ·  %s\n%s" % [str(offer.get("owner", "")).capitalize(),
				readable_id(str(offer.get("id", ""))), DETAILS_UNAVAILABLE]
	return "%s  ·  %s\n%s card  ·  %d energy  ·  %d gold\n%s" % [
			str(details["name"]), str(details["id"]), str(details["owner"]).capitalize(),
			int(details["cost"]), int(offer.get("price", 0)), str(details["line"])]


## The single audited patch authority: the complete power/slot map built from
## the same power-only catalogs the live Patch Stall binds, passed through that
## panel's UNCHANGED verified-preview audit. Like the card preview catalogs the
## result is built once per panel because the authored files are immutable; a
## catalog that fails to load yields no authority at all and every patch
## preview fails closed.
func _patch_authority() -> Dictionary:
	if _patch_projection.is_empty():
		var slots: Dictionary = {}
		for record in RunAuthoredPatchDefinitions.load_power_definitions():
			if typeof(record) == TYPE_DICTIONARY and record.has("id") and record.has("slot"):
				slots[str(record["id"])] = str(record["slot"])
		if not slots.is_empty():
			var previews := _trusted_patch_previews(slots)
			if not previews.is_empty():
				_patch_projection = {"slots": slots, "previews": previews}
	return _patch_projection


## The live Patch Stall's own verified-preview path, unchanged: a detached
## read-only instance of that panel exists only to run its audited function
## over the full power/slot map (it is never mounted, owns no state, and the
## audit only reads authored constants and the shipped catalogs). This view
## publishes exactly the power/trigger text the Patch Stall audit proves,
## never a second independently copied description.
func _trusted_patch_previews(slots: Dictionary) -> Dictionary:
	var stall := LivePatchStallPanel.new()
	var previews: Dictionary = stall._trusted_power_previews(slots)
	stall.free()
	return previews


## The one P12 supplement to the ordinary/P8 audit: the unlocked Shared Hem is
## authored in the heirloom catalog that audit's power-only slot map does not
## carry, so the projection completes it only from a canonically VERIFIED
## authored record. The record must match the exact HEIRLOOM_REQUIRED contract
## through the shared patch projection's own validation before any rule text
## is published; a missing, unreadable or duplicated P12 catalog, any
## contradictory field, the withheld HEAD Needle Echo and every unknown ID
## fail closed to no details, so the view keeps saying
## PATCH_DETAILS_UNAVAILABLE instead of guessing a rule. The optional source
## lets tests supply contradictory records without editing the shipped files,
## mirroring the Patch Stall preview seam.
func _verified_heirloom(offer_id: String, catalog_source: Variant = null) -> Dictionary:
	if not RunAuthoredPatchDefinitions.HEIRLOOM_REQUIRED.has(offer_id):
		return {}
	var required: Dictionary = RunAuthoredPatchDefinitions.HEIRLOOM_REQUIRED[offer_id]
	var catalog: Variant = catalog_source
	if catalog == null:
		catalog = JSON.parse_string(FileAccess.get_file_as_string(
				RunAuthoredPatchDefinitions.CATALOG_PATHS[
						RunAuthoredPatchDefinitions.HEIRLOOM_CATALOG_INDEX]))
	if typeof(catalog) != TYPE_ARRAY:
		return {}
	var matched: Dictionary = {}
	for record in catalog:
		if typeof(record) != TYPE_DICTIONARY:
			return {}
		if str(record.get("id", "")) != offer_id:
			continue
		if not matched.is_empty():
			return {}
		matched = record
	if matched.is_empty() or not RunAuthoredPatchDefinitions._valid_heirloom(matched) \
			or str(matched["slot"]) != str(required["slot"]):
		return {}
	return {
		"id": offer_id,
		"slot": str(matched["slot"]),
		"name": str(matched["name"]),
		"short": NEEDLE_ECHO_SHORT if offer_id == NEEDLE_ECHO_ID else SHARED_HEM_SHORT,
		"full": NEEDLE_ECHO_FULL if offer_id == NEEDLE_ECHO_ID else SHARED_HEM_FULL,
	}


## Retain the focused Shared Hem authentication seam for negative regressions.
func _verified_shared_hem(offer_id: String, catalog_source: Variant = null) -> Dictionary:
	if offer_id != SHARED_HEM_ID:
		return {}
	return _verified_heirloom(offer_id, catalog_source)


## The audited patch description reuses the one existing Patch Stall
## verified-preview path: the offered ID must be a real power patch in the
## audited slot catalog, and the trusted projection must have proven that
## exact ID and slot. The one exception is the canonically verified unlocked
## Shared Hem above. Anything both audits reject - an inert starter slot, a
## contradictory or unknown record - yields no details at all, so the view
## fails closed with PATCH_DETAILS_UNAVAILABLE instead of guessing a rule.
func _patch_details() -> Dictionary:
	if not _source_current():
		return {}
	var offer := _patch_offer()
	var offer_id := str(offer.get("id", ""))
	if offer_id.is_empty():
		return {}
	var authority := _patch_authority()
	var slots: Dictionary = authority.get("slots", {})
	var previews: Dictionary = authority.get("previews", {})
	var slot := ""
	var short_text := ""
	var full_text := ""
	if slots.has(offer_id) and previews.has(offer_id):
		slot = str(slots[offer_id])
		var preview: Dictionary = previews[offer_id]
		short_text = str(preview.get("short", ""))
		full_text = str(preview.get("full", ""))
	else:
		# The one P12 supplement: only a canonically verified authored
		# Shared Hem record may complete this projection.
		var verified := _verified_heirloom(offer_id)
		if verified.is_empty():
			return {}
		slot = str(verified["slot"])
		short_text = str(verified["short"])
		full_text = str(verified["full"])
	if not ["HEAD", "ARM", "COAT"].has(slot):
		return {}
	if short_text.is_empty() or full_text.is_empty():
		return {}
	return {
		"id": offer_id,
		"slot": slot,
		"name": readable_id(offer_id),
		"price": int(offer.get("price", 0)),
		"sold": bool(offer.get("sold", false)),
		"short": short_text,
		"full": full_text,
	}


func _patch_preview() -> String:
	if _source.is_empty():
		return PATCH_DETAILS_UNAVAILABLE
	var details := _patch_details()
	var offer := _patch_offer()
	if details.is_empty():
		return "%s  ·  %s  ·  %s" % ["PATCH", readable_id(str(offer.get("id", ""))), PATCH_DETAILS_UNAVAILABLE]
	var slot: String = str(details.get("slot", ""))
	var name: String = str(details.get("name", readable_id(str(details.get("id", "")))))
	var full: String = str(details.get("full", ""))
	var short_text: String = str(details.get("short", ""))
	# The preview shows the short form; the full form stays in the tooltip.
	var line := short_text if not short_text.is_empty() else full
	return "%s  ·  %s  ·  %s  ·  %s" % [slot, name, str(details["id"]), line]


func _patch_tooltip() -> String:
	if _source.is_empty():
		return ""
	var offer := _patch_offer()
	var details := _patch_details()
	if details.is_empty():
		return "PATCH  ·  %s\n%s" % [readable_id(str(offer.get("id", ""))), PATCH_DETAILS_UNAVAILABLE]
	var slot: String = str(details.get("slot", ""))
	var full: String = str(details.get("full", ""))
	# Replacement rule uses the same slot identity.
	var replacement := "A %s slot: a patch already worn in this slot is destroyed for exactly +1 scrap.\nA free %s slot destroys nothing and gains no scrap." % [slot, slot]
	return "%s  ·  %s  ·  %s\n%s\n%d gold\n%s\n%s" % [
		str(details.get("name", readable_id(str(details.get("id", ""))))),
		str(details.get("id", "")),
		slot,
		full,
		int(details.get("price", int(offer.get("price", 0)))),
		PATCH_TORN_WARNING,
		replacement,
	]


## Shortens only the on-screen display when the status band is too narrow for
## the complete preview at its shipped 18px face. The unshortened text stays in
## the card's tooltip, so a cut line is never the only description a player gets.
func _clamp_status(text: String) -> String:
	if status_label == null:
		return text
	var font := status_label.get_theme_font("font")
	if font == null:
		return text
	var width := STATUS_WIDTH
	if status_label.size.x > 0.0:
		width = minf(STATUS_WIDTH, status_label.size.x)
	var font_size := status_label.get_theme_font_size("font_size")
	if _status_width(font, text, font_size) <= width:
		return text
	var low := 0
	var high := text.length()
	while low < high:
		var mid := int((low + high + 1) / 2)
		var candidate := text.substr(0, mid).strip_edges() + ELLIPSIS
		if _status_width(font, candidate, font_size) <= width:
			low = mid
		else:
			high = mid - 1
	if low <= 0:
		return ELLIPSIS
	var head := text.substr(0, low)
	var last_space := head.rfind(" ")
	if last_space > 0:
		head = head.substr(0, last_space)
	return head.strip_edges() + ELLIPSIS


func _status_width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _card_buyable(index: int) -> bool:
	var offer := _offer(index)
	return not bool(offer["sold"]) and _gold() >= int(offer["price"])


func _patch_buyable() -> bool:
	var offer := _patch_offer()
	return not bool(offer["sold"]) and _gold() >= int(offer["price"])


func _retire_callbacks() -> void:
	for button in _connections:
		if is_instance_valid(button) and button.pressed.is_connected(_connections[button]):
			button.pressed.disconnect(_connections[button])
	_connections.clear()


func _attach(button: Button, callback: Callable) -> void:
	button.pressed.connect(callback)
	_connections[button] = callback


func _attached(button: Button) -> bool:
	return is_instance_valid(button) and button.get_parent() == self \
			and button.is_inside_tree() and button.is_visible_in_tree()


func _refresh() -> void:
	if title_label == null:
		return
	_retire_callbacks()
	_hover_index = -1
	_preview_index = -1
	var open := _source_current()
	title_label.text = TITLE_TEXT
	wallet_label.text = _wallet_caption() if open else WALLET_CLOSED
	status_label.text = STATUS_OPEN if open else STATUS_CLOSED
	for i in range(CARD_COUNT):
		var button := card_buttons[i]
		button.text = _card_caption(i) if open else ""
		button.disabled = true if not open else not _card_buyable(i)
		button.set_meta("offer_kind", CARD_KIND if open else "")
		button.set_meta("offer_id", str(_offer(i)["id"]) if open else "")
		# The complete authored ability belongs to the card's own tooltip, so a
		# shortened on-panel line never hides an effect. A closed binding and a
		# fresh rebind drop the previous visit's text instead of keeping it.
		button.tooltip_text = _card_tooltip(i) if open else ""
		button.add_theme_stylebox_override("normal", _style(
				CARD_FABRIC if open else Color("#dad1c5"),
				OXBLOOD if open and not button.disabled else DIM))
		if open:
			_attach(button, _request_buy.bind(i, false, button, _epoch, _visit))
	patch_button.text = _patch_caption() if open else ""
	patch_button.tooltip_text = _patch_tooltip() if open else ""
	patch_button.disabled = true if not open else not _patch_buyable()
	patch_button.set_meta("offer_kind", PATCH_KIND if open else "")
	patch_button.set_meta("offer_id", str(_patch_offer()["id"]) if open else "")
	patch_button.add_theme_stylebox_override("normal", _style(
			PATCH_FABRIC if open else Color("#dad1c5"),
			TEAL if open and not patch_button.disabled else DIM))
	if open:
		_attach(patch_button, _request_buy.bind(0, true, patch_button, _epoch, _visit))
	leave_button.text = LEAVE_TEXT
	leave_button.disabled = not open
	if open:
		_attach(leave_button, _request_leave.bind(_epoch, _visit))
	_wire_focus()
	# Re-derive the band from the current source only: neutral unless a card of
	# this exact generation is still hovered or focused.
	_sync_preview()


func _focusables() -> Array[Button]:
	var list: Array[Button] = []
	for button in card_buttons + [patch_button, leave_button]:
		if not button.disabled:
			list.append(button)
	return list


func _wire_focus() -> void:
	var focusables := _focusables()
	for i in range(focusables.size()):
		focusables[i].focus_next = focusables[i].get_path_to(
				focusables[(i + 1) % focusables.size()])
		focusables[i].focus_previous = focusables[i].get_path_to(
				focusables[(i + focusables.size() - 1) % focusables.size()])


func _focus_initial() -> void:
	if not is_inside_tree() or not _source_current():
		return
	var focusables := _focusables()
	if not focusables.is_empty():
		focusables[0].grab_focus()


## The band may show the neutral hint or a preview computed from THIS source.
## Any other text (a forged or stale line) is refused, so a mutable label can
## never authenticate a press.
func _status_authentic() -> bool:
	if status_label == null:
		return false
	if status_label.text == STATUS_OPEN:
		return true
	if _source.is_empty() or not _valid_open_state(_source):
		return false
	for i in range(CARD_COUNT):
		if status_label.text == _clamp_status(_card_preview(i)):
			return true
	# The patch preview is also authentic when it matches this exact source.
	if status_label.text == _clamp_status(_patch_preview()):
		return true
	return false


## Every displayed control must still be a mounted, honestly labelled projection
## of THIS exact open generation before any press may leave the view.
func _auth(epoch: int, source: RunPeddlerVisit) -> bool:
	if epoch != _epoch or source == null or not is_same(source, _visit) or not _active():
		return false
	if title_label.text != TITLE_TEXT or wallet_label.text != _wallet_caption() \
			or not _status_authentic() or leave_button.text != LEAVE_TEXT:
		return false
	for i in range(CARD_COUNT):
		var button := card_buttons[i]
		if not _attached(button) or button.text != _card_caption(i) \
				or not button.get_meta("offer_kind", "") is String \
				or not button.get_meta("offer_id", "") is String \
				or button.get_meta("offer_kind", "") != CARD_KIND \
				or button.get_meta("offer_id", "") != str(_offer(i)["id"]) \
				or button.disabled != (not _card_buyable(i)):
			return false
	if not _attached(patch_button) or patch_button.text != _patch_caption() \
			or not patch_button.get_meta("offer_kind", "") is String \
			or not patch_button.get_meta("offer_id", "") is String \
			or patch_button.get_meta("offer_kind", "") != PATCH_KIND \
			or patch_button.get_meta("offer_id", "") != str(_patch_offer()["id"]) \
			or patch_button.disabled != (not _patch_buyable()):
		return false
	return _attached(leave_button) and not leave_button.disabled


func _request_buy(index: int, is_patch: bool, button: Button, epoch: int,
		source: RunPeddlerVisit) -> void:
	if not _auth(epoch, source):
		return
	if is_patch:
		if button != patch_button or index != 0:
			return
	elif index < 0 or index >= CARD_COUNT or button != card_buttons[index]:
		return
	if button.disabled:
		return
	var offer := _patch_offer() if is_patch else _offer(index)
	if bool(offer["sold"]) or _gold() < int(offer["price"]):
		return
	_submit({
		"node_id": str(_source["node_id"]),
		"kind": PATCH_KIND if is_patch else CARD_KIND,
		"id": str(offer["id"]),
		"expected_state": _source["state"].duplicate(true),
		"expected_stock": _source["stock"].duplicate(true),
	})


func _request_leave(epoch: int, source: RunPeddlerVisit) -> void:
	if not _auth(epoch, source) or leave_button.disabled:
		return
	_submit({
		"node_id": str(_source["node_id"]),
		"kind": LEAVE_KIND,
		"expected_state": _source["state"].duplicate(true),
		"expected_stock": _source["stock"].duplicate(true),
	})


## Only the exact receipt from a genuine button press can reach the controller.
func consume_intent(intent: Dictionary) -> bool:
	if not _submitted or _pending_intent.is_empty() or intent != _pending_intent:
		return false
	_pending_intent.clear()
	return true


func retry_submission() -> void:
	if not _pending_intent.is_empty():
		return
	_submitted = false
	_refresh()


func _submit(intent: Dictionary) -> void:
	_submitted = true
	_pending_intent = intent.duplicate(true)
	for button in card_buttons + [patch_button, leave_button]:
		button.disabled = true
	_retire_callbacks()
	intent_requested.emit(intent.duplicate(true))
