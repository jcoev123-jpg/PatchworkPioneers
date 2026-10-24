class_name RunRouteAtlas
extends Control
## Standalone node request view: RunMap remains the only graph and route authority.
## The view emits requests, never commits a choice or draws from any RNG.
## bind_map(null) clears everything. refresh() always rebuilds from defensive snapshots.
## All positions are local to the 1240 x 600 preview; a parent may center it in 1280 x 720.
##
## The preview is the owner's OPEN BOOK (ART_STYLE "Map"): two cream pages, a stitched
## spine, a running-stitch frame, a page curl and a ribbon bookmark are drawn behind every
## thread and patch, and a drawn pin marks the party's current patch. The optional owner
## map-board image (MAP_BOARD_PATH) replaces the drawn pages when ResourceLoader confirms
## it exists; a missing image keeps the complete drawn book, so no PNG is required.
##
## The left page carries an inert twelve-bead pinned diary. Only the current origin
## and the next three floors appear on the right page; all legal buttons are in its
## first column. Each round patch shows its original aspect-preserved token art
## above its high-contrast caption; Treasure/missing art draws a stitched emblem.
##
## Every patch hover names its authored floor, kind and one-based branch row, and a
## legal patch's Action adds the real 1-4 shortcut it answers to. Raw f##_n# IDs stay
## in metadata and in the route protocol; they never reach player-facing hover text.
##
## Presentation only: a stitch that becomes legal because the party just visited its source
## sews into view with a transparent-to-coloured gradient mask on the existing full path.
## A Line2D gradient REPLACES default_color while installed, so the mask repeats the stitch's
## own legal-thread RGB: opaque behind the sewing front, fully transparent ahead of it.
## The mask never touches points, default_color, metadata or the model, is removed when the
## reveal ends (or the view rebuilds), and every request/refresh path stays synchronous.

const ATLAS_SIZE := Vector2(1240.0, 600.0)
const NODE_SIZE := Vector2(80.0, 80.0)
const FIRST_X := 755.0
const FLOOR_STEP := 150.0
const ORIGIN_X := 636.0
const FIRST_Y := 145.0
const ROW_STEP := 101.0
const CHOSEN_BG := Color("#426458")
const LEGAL_BG := Color("#887244")
const OTHER_BG := Color("#484651")
const CHOSEN_THREAD := Color("#a6e4c5")
const LEGAL_THREAD := Color("#efd6a0")
const OTHER_THREAD := Color("#837886")
const OTHER_BORDER := Color("#938999")
## Owner art path, kept in code so the relay's ART phase can drop in the board image.
const MAP_BOARD_PATH := "res://assets/paper/backgrounds/map_board.png"
## The six authored sewn route tokens: one committed image per exact authored kind.
## Kinds without an entry keep the original drawn paper marker, and so does a token
## whose file cannot be loaded, so a missing PNG never breaks the preview.
const NODE_TOKEN_PATHS := {
	"Fight": "res://assets/paper/ui/map_node_fight.png",
	"Elite": "res://assets/paper/ui/map_node_elite.png",
	"Event": "res://assets/paper/ui/map_node_event.png",
	"Shop": "res://assets/paper/ui/map_node_shop.png",
	"Rest": "res://assets/paper/ui/map_node_rest.png",
	"Boss": "res://assets/paper/ui/map_node_boss.png",
}
## Maximum drawn token image width inside the round patch, above its caption.
const NODE_TOKEN_COLUMN := 48.0
const BOOK_RECT := Rect2(10.0, 20.0, 1220.0, 564.0)
## The two pages are deliberately separated by a gutter no map patch crosses.
const PAGE_LEFT := Rect2(18.0, 28.0, 591.0, 548.0)
const PAGE_RIGHT := Rect2(624.0, 28.0, 598.0, 548.0)
const SPINE_RECT := Rect2(609.0, 24.0, 15.0, 556.0)
const BOOKMARK_RECT := Rect2(609.0, 4.0, 15.0, 132.0)
const CURL_SIZE := 70.0
const STITCH_INSET := 9.0
const PAPER := Color("#ecdfbd")
const PAPER_SHADE := Color("#d8c9a2")
const SPINE_FILL := Color("#b7a276")
const THREAD := Color("#c9b996")
const INK := Color("#4a3f35")
const BOOKMARK_FILL := Color("#a2544a")
const PIN_SIZE := Vector2(24.0, 30.0)
## Normal and presentation-only fast reveal of a newly legal stitch, in seconds.
const REVEAL_DURATION := 0.6
const REVEAL_FAST_DURATION := 0.15
## Authored floor bands; journal and each visible floor heading use the same mapping.
## The visible area caption and the numbered FLOOR heading are chapter headings: they
## select the master Theme's PatchHeading (Londrina Solid Regular) variation, and the
## diary's two display headings resolve that same face through its Theme. The diary's
## facts, status tab and round patch captions keep the readable body face.
const AREA_BANDS := [
	{"name": "Meadow", "first_floor": 1, "last_floor": 3},
	{"name": "Woods", "first_floor": 4, "last_floor": 6},
	{"name": "Marsh", "first_floor": 7, "last_floor": 9},
	{"name": "Peaks", "first_floor": 10, "last_floor": 11},
	{"name": "Boss", "first_floor": 12, "last_floor": 12},
]
## Per-visible-floor area captions are separated from the floor heading and patches.
const AREA_LABEL_TOP := 68.0
const AREA_LABEL_HEIGHT := 24.0
## Next-floor tab sits on the left page above the journey diary; it has no input.
const NEXT_AREA_TAB_RECT := Rect2(46.0, 50.0, 500.0, 38.0)
const NEXT_AREA_TAB_FONT_SIZE := 18
## The diary's two display headings speak the master Theme's display voice. A mounted
## Theme that really defines this variation supplies the face; the committed Londrina
## Solid file (already shipped for PatchHeading) stands in when none does.
const HEADING_VARIATION := "PatchHeading"
const HEADING_FONT_PATH := "res://assets/fonts/LondrinaSolid-Regular.ttf"

signal node_requested(id: String)

var _map: RunMap = null
var _revision := 0
var _rendered_generation := 0
var _rendered_graph: Array = []
var _rendered_route: Array[String] = []
var _rendered_legal: Array[String] = []
var _rendered_shortcuts: Array[String] = []
## Only current mounted legal Action buttons; indexed in authored shortcut order.
var _legal_actions: Array[Button] = []
var _actions_by_id: Dictionary = {}
## Last map snapshot this view actually rendered, so a repeat refresh never replays.
var _rendered_map: RunMap = null
var _has_snapshot := false
## Running stitch reveals only; every entry is released by the next refresh or teardown.
var _reveal_masks: Dictionary = {}
var _reveal_tweens: Array[Tween] = []
var _pending_reveals: Array[Line2D] = []
## Presentation-only switch: the same reveal at 0.15 s instead of 0.6 s.
var reveal_fast := false
var _board_texture: Texture2D = null
## Key: token art path, value: Texture2D or null. A negative entry is cached too, so
## a missing token is never probed twice and the drawn marker stays the fallback.
var _node_tokens: Dictionary = {}
## Owner or data may hand the board image in directly; null falls back to the path.
var board_texture_override: Texture2D = null
var board_texture_path := MAP_BOARD_PATH


## Inert token art or drawn fallback in the top half of a circular sewn patch.
## The caption sits along the lower edge, and the transparent Action covers the face.
class NodeToken extends Control:
	var token_kind := ""
	var token_texture: Texture2D = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	## Keep art centred in the upper portion of a circular patch, leaving the
	## lower row for the readable kind and live shortcut number.
	func token_rect() -> Rect2:
		if token_texture == null or size.x <= 0.0 or size.y <= 0.0:
			return Rect2()
		var pixels := Vector2(token_texture.get_width(), token_texture.get_height())
		if pixels.x <= 0.0 or pixels.y <= 0.0:
			return Rect2()
		var fit := minf(minf(RunRouteAtlas.NODE_TOKEN_COLUMN, size.x - 10.0) / pixels.x,
			minf(44.0, size.y - 20.0) / pixels.y)
		var drawn := pixels * fit
		return Rect2(Vector2((size.x - drawn.x) * 0.5, 4.0), drawn)

	func _draw() -> void:
		var rect := token_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			draw_texture_rect(token_texture, rect, false)
			return
		# Treasure and unknown/missing textures receive a stitched paper emblem.
		var middle := Vector2(size.x * 0.5, 26.0)
		draw_circle(middle, 23.0, Color("#d8c9a2"))
		draw_arc(middle, 21.0, 0.0, TAU, 32, RunRouteAtlas.INK, 1.6, true)
		for offset in [-17.0, -5.0, 7.0]:
			draw_line(middle + Vector2(offset, -18), middle + Vector2(offset + 5, -18),
				RunRouteAtlas.THREAD, 2.0, true)
		var font := get_theme_default_font()
		if font != null:
			var glyph := "▣" if token_kind == "Treasure" else "?"
			draw_string(font, middle + Vector2(-10, 9), glyph, HORIZONTAL_ALIGNMENT_CENTER,
				20.0, 27, RunRouteAtlas.INK)

## The Action draws a bone-thread ring WITHIN its round felt patch when focused.
## Arcs leave the lower caption exposed; no filled overlay obscures token art.
class LegalPatchAction extends Button:
	func _init() -> void:
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		if not has_focus():
			return
		var centre := size * 0.5
		# The focus seam is inset at least six pixels from the 80px edge.
		# Leave the lower ~90-degree caption band unobstructed.
		draw_arc(centre, 32.0, 2.32, TAU + 0.82, 52,
			Color("#272f32"), 6.0, true)
		draw_arc(centre, 32.0, 2.32, TAU + 0.82, 52,
			Color("#fff1c6"), 3.5, true)
		for angle in [2.56, 3.3, 4.04, 4.78, 5.52, 6.26]:
			var radial := Vector2(cos(angle), sin(angle))
			var tangent := Vector2(-radial.y, radial.x)
			var point := centre + radial * 32.0
			draw_line(point - radial * 3.0 - tangent * 2.3,
				point + radial * 3.0 + tangent * 2.3, Color("#272f32"), 2.0, true)
			draw_line(point - radial * 3.0 + tangent * 2.3,
				point + radial * 3.0 - tangent * 2.3, Color("#fff1c6"), 2.0, true)


## Left-hand travel diary: an inert high-contrast sewn-paper journey and pinned
## twelve-floor progress trail. It never invents a route choice or reads RNG.
class JourneyJournal extends Control:
	var current_floor := 0
	var current_area := ""
	var next_floor := 1
	var next_area := ""
	var complete := false
	var visited: Array[String] = []
	## Cached committed heading face, so redraws never re-probe the shipped font file.
	var _fallback_heading: Font = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	## Read-only face for the two display headings: the nearest inherited Theme that
	## really defines PatchHeading, else the committed Londrina Solid file. It never
	## assigns that variation to this Control, so the body facts keep the body face,
	## and it ignores the global project/default Theme so the fallback stays reachable.
	func heading_font() -> Font:
		var mounted := inherited_theme()
		if mounted != null:
			var face := RunRouteAtlas.patch_heading_face(mounted)
			if face != null:
				return face
		if _fallback_heading == null:
			_fallback_heading = RunRouteAtlas.committed_heading_font()
		return _fallback_heading

	## The nearest Theme mounted on this journal, an ancestor Control or the root Window.
	func inherited_theme() -> Theme:
		var node: Node = self
		while node != null:
			var mounted: Theme = null
			if node is Control:
				mounted = (node as Control).theme
			elif node is Window:
				mounted = (node as Window).theme
			if mounted != null and RunRouteAtlas.patch_heading_face(mounted) != null:
				return mounted
			node = node.get_parent()
		return null

	func _draw() -> void:
		if size.x <= 0.0:
			return
		var frame := Rect2(Vector2.ZERO, size)
		draw_rect(frame, Color("#eee4cb"))
		draw_rect(frame, RunRouteAtlas.INK, false, 2.0)
		draw_dashed_line(Vector2(12, 13), Vector2(size.x - 12, 13),
			RunRouteAtlas.THREAD, 1.5, 7.0)
		var font := get_theme_default_font()
		if font == null:
			return
		# Both diary display headings take the authored PatchHeading voice; every
		# current/next/progress fact and bead numeral below keeps this body face.
		var heading := heading_font()
		if heading == null:
			heading = font
		draw_string(heading, Vector2(22, 49), "THE SEWN JOURNEY",
			HORIZONTAL_ALIGNMENT_LEFT, 480.0, 25, RunRouteAtlas.INK)
		var here := "Trailhead" if current_floor == 0 else current_area
		draw_string(font, Vector2(22, 94),
			"Current: %s  ·  Floor %d/12" % [here, current_floor],
			HORIZONTAL_ALIGNMENT_LEFT, 495.0, 21, RunRouteAtlas.INK)
		var next_text := "Route complete · The final stitch is tied" if complete else (
			"Next: %s  ·  Floor %d/12" % [next_area, next_floor])
		draw_string(font, Vector2(22, 133), next_text,
			HORIZONTAL_ALIGNMENT_LEFT, 495.0, 18, RunRouteAtlas.INK)
		draw_dashed_line(Vector2(22, 155), Vector2(size.x - 22, 155),
			RunRouteAtlas.THREAD, 2.0, 8.0)
		draw_string(heading, Vector2(22, 194), "PINNED FLOOR TRAIL",
			HORIZONTAL_ALIGNMENT_LEFT, 490.0, 17, RunRouteAtlas.INK)
		var beads: Array[Vector2] = []
		for i in range(12):
			beads.append(Vector2(59.0 + float(i % 4) * 132.0,
				235.0 + float(i / 4) * 66.0))
		for i in range(11):
			draw_dashed_line(beads[i], beads[i + 1], RunRouteAtlas.THREAD, 2.0, 7.0)
		for i in range(12):
			var point := beads[i]
			var done := i < current_floor
			draw_circle(point, 17.0, RunRouteAtlas.CHOSEN_BG if done else RunRouteAtlas.PAPER_SHADE)
			draw_arc(point, 17.0, 0.0, TAU, 28,
				RunRouteAtlas.CHOSEN_THREAD if done else RunRouteAtlas.INK, 2.0, true)
			draw_string(font, point + Vector2(-10.0, 5.0), "%02d" % (i + 1),
				HORIZONTAL_ALIGNMENT_CENTER, 20.0, 15,
				Color("#ffffff") if done else RunRouteAtlas.INK)
		# The diary's real pushpin points to the latest committed bead.
		if current_floor > 0:
			var pin := beads[current_floor - 1] + Vector2(0, -23)
			draw_line(pin, pin + Vector2(0, 22), RunRouteAtlas.INK, 2.0)
			draw_circle(pin, 7.0, Color("#bd5149"))
		draw_string(font, Vector2(22, size.y - 20),
			"Stitched route  ·  %d of 12 floors visited" % visited.size(),
			HORIZONTAL_ALIGNMENT_LEFT, 490.0, 16, RunRouteAtlas.INK)


func _add_journal(current_floor: int, chosen: Array[String]) -> void:
	var journal := JourneyJournal.new()
	journal.name = "JourneyJournal"
	journal.set_meta("journey_journal", true)
	journal.current_floor = current_floor
	journal.current_area = area_for_floor(current_floor)
	journal.next_floor = 0 if _map.is_complete() else current_floor + 1
	journal.next_area = area_for_floor(journal.next_floor)
	journal.complete = _map.is_complete()
	journal.visited = chosen.duplicate()
	journal.position = Vector2(46.0, 102.0)
	journal.size = Vector2(532.0, 442.0)
	journal.custom_minimum_size = journal.size
	_inert(journal)
	add_child(journal)


## Inert drawn pushpin over the party's current patch; never takes pointer or focus.
class CurrentPin extends Control:
	const HEAD := Color("#c9605a")
	const HEAD_SHADE := Color("#8f3f3d")
	const NEEDLE := Color("#f0e6cf")

	var pin_id := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var head := Vector2(size.x * 0.5, size.y * 0.38)
		var radius := minf(size.x, size.y) * 0.34
		draw_line(head, Vector2(size.x * 0.5, size.y), NEEDLE, 2.0, true)
		draw_circle(head, radius, HEAD)
		draw_circle(head + Vector2(-radius * 0.35, -radius * 0.35), radius * 0.36, HEAD_SHADE)


func _init() -> void:
	custom_minimum_size = ATLAS_SIZE
	size = ATLAS_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	# _input covers the initial atlas opening even when another Control owns focus.
	set_process_input(true)
	set_process_unhandled_input(false)


func _ready() -> void:
	resized.connect(queue_redraw)


## A map may be bound before the view enters the tree (the overlay does exactly that),
## so queued reveals start on the first processed frame instead of being dropped.
func _process(_delta: float) -> void:
	if _pending_reveals.is_empty():
		set_process(false)
		return
	if not is_inside_tree():
		return
	var queued := _pending_reveals.duplicate()
	_pending_reveals.clear()
	for line in queued:
		var mask: Gradient = _reveal_masks.get(line)
		if is_instance_valid(line) and mask != null:
			_start_reveal_tween(line, mask)
	set_process(false)


## Leaving the tree releases every reveal: no tween may outlive its threads.
func _exit_tree() -> void:
	_teardown_reveal()


## Presentation-only switch: the same reveal settles in 0.15 s instead of 0.6 s.
func set_reveal_fast(fast: bool) -> void:
	reveal_fast = fast


func reveal_duration() -> float:
	return REVEAL_FAST_DURATION if reveal_fast else REVEAL_DURATION


func is_revealing() -> bool:
	return not _reveal_masks.is_empty() or not _pending_reveals.is_empty()


## Canonical "source->target" keys whose stitch is currently sewing into view.
func revealing_edges() -> Array[String]:
	var keys: Array[String] = []
	for line in _reveal_masks:
		if is_instance_valid(line) and line.has_meta("from_id") and line.has_meta("to_id"):
			keys.append(str(line.get_meta("from_id")) + "->" + str(line.get_meta("to_id")))
	keys.sort()
	return keys


## Directed edges the model currently paints as visited-to-legal stitches.
static func _legal_edge_keys(graph: Array, route: Array, legal: Array) -> Dictionary:
	var keys: Dictionary = {}
	for floor_nodes in graph:
		for node in floor_nodes:
			var source: String = node["id"]
			if not route.has(source):
				continue
			for target in node["outgoing"]:
				if legal.has(target):
					keys[source + "->" + str(target)] = true
	return keys


## The mask is a hard alpha step that moves from the source end to the target end.
## Line2D.gradient REPLACES default_color while it is installed, so both stops carry the
## stitch's own legal-thread RGB: opaque behind the sewing front and fully transparent ahead,
## which keeps the newly sewn pixels the model-selected colour instead of white.
static func _new_reveal_mask(thread_color: Color) -> Gradient:
	var mask := Gradient.new()
	mask.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var sewn := Color(thread_color.r, thread_color.g, thread_color.b, thread_color.a)
	var unsewn := Color(thread_color.r, thread_color.g, thread_color.b, 0.0)
	mask.set_color(0, sewn)
	mask.set_color(1, unsewn)
	mask.set_offset(0, 0.0)
	mask.set_offset(1, 0.0)
	return mask


static func _set_reveal_front(mask: Gradient, progress: float) -> void:
	if mask != null:
		mask.set_offset(1, clampf(progress, 0.0, 1.0))


## Attach a hidden-ahead-of-the-front mask to an existing full-path thread.
func _begin_reveal(line: Line2D) -> void:
	if not is_instance_valid(line):
		return
	var mask := _new_reveal_mask(line.default_color)
	line.gradient = mask
	_reveal_masks[line] = mask
	if is_inside_tree():
		_start_reveal_tween(line, mask)
		return
	if not _pending_reveals.has(line):
		_pending_reveals.append(line)
	set_process(true)


func _start_reveal_tween(line: Line2D, mask: Gradient) -> void:
	if not is_inside_tree() or not is_instance_valid(line):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(func(value: float) -> void: _set_reveal_front(mask, value),
		0.0, 1.0, reveal_duration())
	tween.tween_callback(_finish_reveal.bind(line, mask))
	_reveal_tweens.append(tween)


## Completion drops the temporary mask so default_color stays authoritative.
func _finish_reveal(line: Line2D, mask: Gradient) -> void:
	if not is_instance_valid(line):
		_reveal_masks.erase(line)
		return
	if _reveal_masks.get(line) == mask:
		line.gradient = null
		_reveal_masks.erase(line)


func _teardown_reveal() -> void:
	for tween in _reveal_tweens:
		if is_instance_valid(tween):
			tween.kill()
	_reveal_tweens.clear()
	for line in _reveal_masks:
		if is_instance_valid(line):
			line.gradient = null
	_reveal_masks.clear()
	_pending_reveals.clear()
	set_process(false)


func bind_map(map: RunMap) -> void:
	_map = map
	refresh()


func refresh() -> void:
	# Each rebuild invalidates every previous marker callback, including callbacks
	# retained by a caller after a Control has been detached or freed.
	_revision += 1
	# Snapshot what the party already saw before this rebuild releases it.
	var previous_map := _rendered_map
	var previous_graph := _rendered_graph
	var previous_route := _rendered_route.duplicate()
	var previous_legal := _rendered_legal.duplicate()
	var had_snapshot := _has_snapshot
	# Restore a focused legal choice by ID only; never retain a freed Button.
	var focused_id := ""
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focus_owner != null and _legal_actions.has(focus_owner):
		focused_id = str(focus_owner.get_meta("route_id"))
	# Kill and release every prior reveal before its threads are removed.
	_teardown_reveal()
	_rendered_graph = []
	_rendered_generation = 0
	_rendered_route.clear()
	_rendered_legal.clear()
	_rendered_shortcuts.clear()
	_legal_actions.clear()
	_actions_by_id.clear()
	_rendered_map = null
	_has_snapshot = false
	# Synchronous removal avoids stale, queued-for-deletion duplicates on repeated refresh.
	for child in get_children():
		remove_child(child)
		child.free()
	_board_texture = board_texture_override if board_texture_override != null \
		else load_board_texture(board_texture_path)
	queue_redraw()
	if _map == null or not _map.is_generated():
		return
	var floors: Array = _map.get_floors()
	var chosen: Array[String] = _map.get_route()
	var legal: Array[String] = _map.get_legal_choices()
	_rendered_generation = _map.get_generation_revision()
	_rendered_graph = floors.duplicate(true)
	_rendered_route = chosen.duplicate()
	_rendered_legal = legal.duplicate()
	_rendered_map = _map
	_has_snapshot = true
	# A visited-to-legal stitch is new only when this exact map never showed it before.
	# An unchanged snapshot therefore keeps its already-shown stitches still.
	var previous_edges: Dictionary = {}
	if had_snapshot and previous_map == _map:
		previous_edges = _legal_edge_keys(previous_graph, previous_route, previous_legal)
	var reveal_keys: Dictionary = {}
	if not _map.is_complete():
		var current_edges := _legal_edge_keys(_rendered_graph, _rendered_route, _rendered_legal)
		for key in current_edges:
			if not previous_edges.has(key):
				reveal_keys[key] = true
	# Number only live choices, not all nodes or Dictionary insertion order.
	# Source floor rows are explicitly sorted by their model position.
	for floor_nodes in floors:
		var ordered: Array = floor_nodes.duplicate()
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["position"]) < int(b["position"]))
		for node in ordered:
			var id: String = node["id"]
			if legal.has(id) and not chosen.has(id):
				_rendered_shortcuts.append(id)
	var current_floor := _map.get_current_floor()
	var current_id := _map.get_current_node_id()
	var visible_floors: Array[int] = []
	if not _map.is_complete():
		for floor_number in range(current_floor + 1, mini(current_floor + 3, floors.size()) + 1):
			visible_floors.append(floor_number)
	# Off-window nodes stay in _rendered_graph, not in the visual hit-test geometry.
	var positions: Dictionary = {}
	if not current_id.is_empty():
		var current_node := _map.get_node(current_id)
		if not current_node.is_empty():
			positions[current_id] = _node_position(-1, int(current_node["position"]))
	for column in range(visible_floors.size()):
		var floor_number := visible_floors[column]
		for node in floors[floor_number - 1]:
			positions[String(node["id"])] = _node_position(column, int(node["position"]))
	# Only model edges with BOTH visible endpoints are sewn. No fabricated jump
	# between the journal and future floors, and no off-window invisible hit areas.
	for floor_nodes in floors:
		for node in floor_nodes:
			var source_id: String = node["id"]
			if not positions.has(source_id):
				continue
			for target_id in node["outgoing"]:
				if positions.has(target_id):
					_add_thread(source_id, target_id, positions, chosen, legal, reveal_keys)
	_add_journal(current_floor, chosen)
	_add_next_area_tab()
	_add_area_labels(visible_floors)
	for column in range(visible_floors.size()):
		var floor_number := visible_floors[column]
		var header := Label.new()
		header.name = "Floor%02d" % floor_number
		header.set_meta("floor_number", floor_number)
		header.text = "FLOOR %02d" % floor_number
		header.position = Vector2(FIRST_X + column * FLOOR_STEP - 8.0, 105.0)
		header.size = Vector2(NODE_SIZE.x + 16.0, 28.0)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.theme_type_variation = "PatchHeading"
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", INK)
		_inert(header)
		add_child(header)
		for node in floors[floor_number - 1]:
			var id: String = node["id"]
			_add_marker(id, String(node["type"]), positions[id], chosen, legal,
				_rendered_shortcuts.find(id) + 1)
	# The visited patch anchors real connected stitches at the near edge of page two.
	if not current_id.is_empty() and positions.has(current_id):
		var current_node := _map.get_node(current_id)
		_add_marker(current_id, String(current_node["type"]), positions[current_id],
			chosen, legal, 0)
		_add_pin(current_id, positions[current_id])
	_rebuild_focus_chain(focused_id)


## A missing owner image leaves the complete drawn book instead of failing the preview.
static func load_board_texture(path: String = MAP_BOARD_PATH) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


## Exact authored kind to committed sewn token path; an unknown kind has no token and
## keeps the original drawn paper marker.
static func node_token_path(kind: String) -> String:
	return str(NODE_TOKEN_PATHS.get(kind, ""))


## Cached, optional token load. Missing art stays null (and is cached as such), so the
## marker falls back to its drawn paper face and no file is ever probed twice.
func node_token_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not _node_tokens.has(path):
		var loaded: Texture2D = null
		if ResourceLoader.exists(path, "Texture2D"):
			loaded = load(path) as Texture2D
		_node_tokens[path] = loaded
	return _node_tokens.get(path)


func has_cached_node_token(path: String) -> bool:
	return _node_tokens.has(path)


func uses_board_texture() -> bool:
	return _board_texture != null


func board_texture() -> Texture2D:
	return _board_texture


## The owner board fills the whole preview, exactly like the drawn open book, so the
## same sewn map keeps its pages, spine, curl and bookmark with or without the image.
func board_texture_rect() -> Rect2:
	if _board_texture == null or _board_texture.get_width() <= 0 or _board_texture.get_height() <= 0:
		return Rect2()
	return Rect2(Vector2.ZERO, ATLAS_SIZE)


## Deterministic geometry of the drawn open book; empty when the owner image is mounted.
func drawn_book_geometry() -> Dictionary:
	if uses_board_texture():
		return {}
	return {
		"book": BOOK_RECT,
		"left_page": PAGE_LEFT,
		"right_page": PAGE_RIGHT,
		"spine": SPINE_RECT,
		"curl": curl_rect(),
		"bookmark": BOOKMARK_RECT,
		"stitch_inset": STITCH_INSET,
		"paper": PAPER,
	}


func curl_rect() -> Rect2:
	return Rect2(PAGE_RIGHT.end - Vector2(CURL_SIZE, CURL_SIZE), Vector2(CURL_SIZE, CURL_SIZE))


func _draw() -> void:
	if _map == null or not _map.is_generated():
		return
	if uses_board_texture():
		# The owner board supplies pages, spine, curl and bookmark in one image.
		draw_texture_rect(_board_texture, board_texture_rect(), false)
		return
	# A soft table shadow under the sewn book keeps the cream pages readable.
	draw_rect(Rect2(BOOK_RECT.position + Vector2(7.0, 9.0), BOOK_RECT.size),
		Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(BOOK_RECT, PAPER_SHADE)
	draw_rect(PAGE_LEFT, PAPER)
	draw_rect(PAGE_RIGHT, PAPER)
	# Gutter shading so the two pages read as one folded book, not a loose sheet.
	draw_rect(Rect2(PAGE_LEFT.end.x - 16.0, PAGE_LEFT.position.y, 16.0, PAGE_LEFT.size.y),
		Color(0.35, 0.30, 0.22, 0.12))
	draw_rect(Rect2(PAGE_RIGHT.position.x, PAGE_RIGHT.position.y, 16.0, PAGE_RIGHT.size.y),
		Color(0.35, 0.30, 0.22, 0.12))
	draw_rect(SPINE_RECT, SPINE_FILL)
	# Running stitches down the spine.
	var stitch_y := int(SPINE_RECT.position.y) + 16
	while stitch_y < int(SPINE_RECT.end.y) - 8:
		draw_line(Vector2(SPINE_RECT.position.x + 4.0, float(stitch_y)),
			Vector2(SPINE_RECT.end.x - 4.0, float(stitch_y)), THREAD, 1.0, true)
		stitch_y += 26
	# Stitched frame on both pages, inset from the torn paper edge.
	_stitch_frame(PAGE_LEFT.grow(-STITCH_INSET))
	_stitch_frame(PAGE_RIGHT.grow(-STITCH_INSET))
	# Page curl folded up from the bottom-right corner of the right page.
	var curl := curl_rect()
	draw_colored_polygon(PackedVector2Array([
		Vector2(curl.end.x - CURL_SIZE, curl.end.y),
		curl.end,
		curl.end - Vector2(CURL_SIZE * 0.55, CURL_SIZE * 0.55),
	]), PAPER_SHADE)
	draw_dashed_line(Vector2(curl.end.x - CURL_SIZE, curl.end.y), curl.end,
		THREAD, 1.2, 6.0)
	# Ribbon bookmark hanging over the spine's top edge.
	draw_colored_polygon(PackedVector2Array([
		BOOKMARK_RECT.position,
		Vector2(BOOKMARK_RECT.end.x, BOOKMARK_RECT.position.y),
		BOOKMARK_RECT.end,
		Vector2(BOOKMARK_RECT.position.x + BOOKMARK_RECT.size.x * 0.5,
			BOOKMARK_RECT.end.y - 12.0),
		Vector2(BOOKMARK_RECT.position.x, BOOKMARK_RECT.end.y),
	]), BOOKMARK_FILL)
	draw_dashed_line(BOOKMARK_RECT.position + Vector2(4.0, 6.0),
		Vector2(BOOKMARK_RECT.position.x + 4.0, BOOKMARK_RECT.end.y - 18.0), THREAD, 1.0, 5.0)


func _stitch_frame(rect: Rect2) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]
	for index in range(corners.size()):
		var from: Vector2 = corners[index]
		var to: Vector2 = corners[(index + 1) % corners.size()]
		draw_dashed_line(from, to, THREAD, 1.4, 7.0)
	for corner: Vector2 in corners:
		draw_line(corner + Vector2(-4, -4), corner + Vector2(4, 4), THREAD, 1.2, true)
		draw_line(corner + Vector2(4, -4), corner + Vector2(-4, 4), THREAD, 1.2, true)


## The centred caption band of one area, spanning exactly its floor columns.
static func area_label_rect(band: Dictionary) -> Rect2:
	# The static reference is the width of one patch's column; placement is
	# relative to the currently displayed floor, never absolute floor twelve.
	return Rect2(FIRST_X, AREA_LABEL_TOP, NODE_SIZE.x, AREA_LABEL_HEIGHT)


## Print only the area heading above each floor actually inside the viewport.
func _add_area_labels(visible_floors: Array[int]) -> void:
	for column in range(visible_floors.size()):
		var floor_number := visible_floors[column]
		var area_name := area_for_floor(floor_number)
		var label := Label.new()
		label.name = "Area%s%02d" % [area_name, floor_number]
		label.text = area_name
		label.set_meta("area_name", area_name)
		label.set_meta("floor_number", floor_number)
		for band in AREA_BANDS:
			if String(band["name"]) == area_name:
				label.set_meta("first_floor", int(band["first_floor"]))
				label.set_meta("last_floor", int(band["last_floor"]))
		label.position = Vector2(FIRST_X + column * FLOOR_STEP - 8.0, AREA_LABEL_TOP)
		label.size = Vector2(NODE_SIZE.x + 16.0, AREA_LABEL_HEIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.theme_type_variation = "PatchHeading"
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", INK)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", PAPER)
		_inert(label)
		add_child(label)

## Inert sewn-paper status tab: cream paper, dark ink caption and a small running-stitch
## border. It draws itself so it needs no new image or font, and never takes input.
class NextAreaTab extends Control:
	var text := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var paper := Rect2(Vector2.ZERO, size)
		draw_rect(paper, RunRouteAtlas.PAPER)
		draw_rect(paper, RunRouteAtlas.INK, false, 1.5)
		draw_dashed_line(Vector2(5.0, 5.0), Vector2(size.x - 5.0, 5.0),
			RunRouteAtlas.THREAD, 1.0, 5.0)
		draw_dashed_line(Vector2(5.0, size.y - 5.0), Vector2(size.x - 5.0, size.y - 5.0),
			RunRouteAtlas.THREAD, 1.0, 5.0)
		var font := get_theme_default_font()
		if font == null or text.is_empty():
			return
		var font_size := RunRouteAtlas.NEXT_AREA_TAB_FONT_SIZE
		var baseline := (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		draw_string(font, Vector2(12.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 20.0, font_size, RunRouteAtlas.INK)


## Total authored floors, derived from the AREA_BANDS table rather than a second ladder.
static func total_floors() -> int:
	if AREA_BANDS.is_empty():
		return 0
	return int(AREA_BANDS[AREA_BANDS.size() - 1]["last_floor"])


## Authored area name whose floor span contains the given floor, or "" when none does.
static func area_for_floor(floor_number: int) -> String:
	for band in AREA_BANDS:
		if floor_number >= int(band["first_floor"]) and floor_number <= int(band["last_floor"]):
			return String(band["name"])
	return ""


## A Theme's authored PatchHeading face, or null when that Theme merely falls back to
## its own default font. The diary reads this; no Control ever copies the variation.
static func patch_heading_face(source: Theme) -> Font:
	if source == null:
		return null
	if not source.get_font_list(HEADING_VARIATION).has("font"):
		return null
	var face := source.get_font("font", HEADING_VARIATION)
	if face == null or face == source.default_font:
		return null
	return face


## The already-shipped Londrina Solid file that backs PatchHeading. No new asset is
## loaded, and a missing file is simply null so the diary keeps its readable body face.
static func committed_heading_font() -> Font:
	if not ResourceLoader.exists(HEADING_FONT_PATH):
		return null
	return load(HEADING_FONT_PATH) as Font


## Presentation-only caption for a generated map: the area and floor the NEXT legal
## choice visits, or the terminal line once floor 12 is complete. Never a floor 13.
static func next_area_caption(map: RunMap) -> String:
	if map == null or not map.is_generated():
		return ""
	var total := total_floors()
	var current := map.get_current_floor()
	if map.is_complete():
		return "Route complete · Floor %d/%d" % [total, total]
	var next_floor := current + 1
	var area := area_for_floor(next_floor)
	if area.is_empty():
		return ""
	return "Next: %s · Floor %d/%d" % [area, next_floor, total]


## The mounted inert status tab, or null when no generated map is bound.
func next_area_tab() -> NextAreaTab:
	return get_node_or_null("NextArea") as NextAreaTab


func _add_next_area_tab() -> void:
	var caption := next_area_caption(_map)
	if caption.is_empty():
		return
	var tab := NextAreaTab.new()
	tab.name = "NextArea"
	tab.text = caption
	tab.set_meta("next_area_tab", true)
	tab.position = NEXT_AREA_TAB_RECT.position
	tab.size = NEXT_AREA_TAB_RECT.size
	tab.custom_minimum_size = NEXT_AREA_TAB_RECT.size
	_inert(tab)
	add_child(tab)


func _node_position(floor_index: int, row_index: int) -> Vector2:
	var x := ORIGIN_X if floor_index < 0 else FIRST_X + floor_index * FLOOR_STEP
	return Vector2(x, FIRST_Y + row_index * ROW_STEP)

func _add_thread(source: String, target: String, positions: Dictionary,
		chosen: Array[String], legal: Array[String], reveal_keys: Dictionary) -> void:
	var line := Line2D.new()
	line.name = "Thread_%s_%s" % [source, target]
	line.set_meta("from_id", source)
	line.set_meta("to_id", target)
	var start: Vector2 = positions[source] + Vector2(NODE_SIZE.x, NODE_SIZE.y * 0.5)
	var end: Vector2 = positions[target] + Vector2(0.0, NODE_SIZE.y * 0.5)
	var offset: Vector2 = end - start
	var normal := Vector2(-offset.y, offset.x).normalized()
	var path := PackedVector2Array()
	for i in range(13):
		var t := float(i) / 12.0
		var wobble := 0.0 if i == 0 or i == 12 else (1.6 if i % 2 == 0 else -1.6)
		path.append(start.lerp(end, t) + normal * wobble)
	# A small threaded arrow stitch indicates left-to-right direction.
	path.append(end + Vector2(-6.0, -3.5))
	path.append(end)
	path.append(end + Vector2(-6.0, 3.5))
	line.points = path
	line.width = 1.7
	line.antialiased = true
	var state := "other"
	if chosen.has(source) and chosen.has(target):
		state = "chosen"
	elif chosen.has(source) and legal.has(target):
		state = "legal"
	line.set_meta("route_state", state)
	match state:
		"chosen":
			line.default_color = CHOSEN_THREAD
		"legal":
			line.default_color = LEGAL_THREAD
		_:
			line.default_color = OTHER_THREAD
	add_child(line)
	if state == "legal" and reveal_keys.has(source + "->" + target):
		_begin_reveal(line)


## Player-facing sewn route wording for one REAL RunMap node record: its authored
## floor, kind and one-based branch row. The f##_n# ID is never read to guess either
## value, so a renamed ID could not change the words. A missing record keeps the
## authored kind alone, which is what a standalone marker without a bound map has.
static func node_hover_text(node: Dictionary, fallback_kind: String = "") -> String:
	if node.is_empty() or not (node.has("floor") and node.has("position")):
		return fallback_kind
	var kind := str(node.get("type", fallback_kind))
	return "Floor %02d · %s · Branch %d" % [int(node["floor"]), kind, int(node["position"]) + 1]


func _add_marker(id: String, kind: String, at: Vector2,
		chosen: Array[String], legal: Array[String], shortcut: int) -> void:
	var marker := PanelContainer.new()
	marker.name = "Node_" + id
	marker.set_meta("route_id", id)
	marker.set_meta("route_kind", kind)
	var state := "chosen" if chosen.has(id) else ("legal" if legal.has(id) else "other")
	marker.set_meta("route_state", state)
	marker.set_meta("authored_position", int(_map.get_node(id).get("position", -1)) if _map != null else -1)
	var paper := StyleBoxFlat.new()
	paper.bg_color = OTHER_BG
	paper.border_color = OTHER_BORDER
	match state:
		"chosen":
			paper.bg_color = CHOSEN_BG
			paper.border_color = CHOSEN_THREAD
		"legal":
			paper.bg_color = LEGAL_BG
			paper.border_color = LEGAL_THREAD
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(40)
	paper.content_margin_left = 3.0
	paper.content_margin_right = 3.0
	paper.content_margin_top = 3.0
	paper.content_margin_bottom = 3.0
	marker.add_theme_stylebox_override("panel", paper)
	marker.position = at
	marker.custom_minimum_size = NODE_SIZE
	marker.size = NODE_SIZE
	var record: Dictionary = _map.get_node(id) if _map != null else {}
	var hover := node_hover_text(record, kind)
	marker.tooltip_text = hover
	_inert(marker)
	var art := NodeToken.new()
	art.name = "Art"
	art.token_kind = kind
	var token_path := node_token_path(kind)
	art.token_texture = node_token_texture(token_path)
	art.set_meta("route_kind", kind)
	art.set_meta("art_path", token_path)
	art.position = Vector2(3.0, 3.0)
	art.size = NODE_SIZE - Vector2(6.0, 6.0)
	_inert(art)
	marker.add_child(art)
	var caption := Label.new()
	caption.name = "Identity"
	caption.text = (str(shortcut) + " " if state == "legal" and shortcut > 0 else "") + kind
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	caption.add_theme_font_size_override("font_size", 11 if kind == "Treasure" else 12)
	caption.add_theme_color_override("font_color", Color("#fff8e9"))
	caption.add_theme_constant_override("outline_size", 3)
	caption.add_theme_color_override("font_outline_color", Color("#292a2b"))
	_inert(caption)
	marker.add_child(caption)
	if state == "legal":
		var action := LegalPatchAction.new()
		action.name = "Action"
		action.flat = true
		# A circular hand-sewn seam replaces the theme's rectangular focus box.
		for state_name in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			action.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
		action.focus_mode = Control.FOCUS_ALL
		action.mouse_filter = Control.MOUSE_FILTER_STOP
		action.position = Vector2(2, 2)
		action.size = NODE_SIZE - Vector2(4, 4)
		action.tooltip_text = "Choose %s (key %d)" % [hover, shortcut]
		action.set_meta("route_id", id)
		action.pressed.connect(_request_node.bind(id, _map, _revision))
		marker.add_child(action)
		_actions_by_id[id] = action
	add_child(marker)


## Explicit circular Tab order; no inert, current or future marker joins the chain.
func _rebuild_focus_chain(focused_id: String) -> void:
	_legal_actions.clear()
	for id in _rendered_shortcuts:
		var action: Button = _actions_by_id.get(id)
		if is_instance_valid(action) and not action.disabled:
			_legal_actions.append(action)
	for index in range(_legal_actions.size()):
		var action := _legal_actions[index]
		action.focus_next = action.get_path_to(_legal_actions[(index + 1) % _legal_actions.size()])
		action.focus_previous = action.get_path_to(
			_legal_actions[(index - 1 + _legal_actions.size()) % _legal_actions.size()])
	if not focused_id.is_empty() and is_visible_in_tree() and not _legal_actions.is_empty():
		var restore: Button = _actions_by_id.get(focused_id, _legal_actions[0])
		if is_instance_valid(restore):
			restore.grab_focus()


## An arrow enters from the overlay's Close map button (or no focus), then
## cycles through this atlas alone. Other interface controls keep their focus.
func _step_legal_focus(step: int) -> bool:
	if not _snapshot_is_current() or _legal_actions.is_empty():
		return false
	var owner := get_viewport().gui_get_focus_owner()
	var index := _legal_actions.find(owner)
	if owner != null and index < 0:
		if not (owner is Button and owner.text == "Close map"
				and owner.get_parent() == get_parent()):
			return false
	# No prior legal focus: Down enters at the first patch, Up at the last.
	var next_index := (index + step + _legal_actions.size()) % _legal_actions.size() \
		if index >= 0 else (0 if step > 0 else _legal_actions.size() - 1)
	_legal_actions[next_index].grab_focus()
	return _legal_actions[next_index].has_focus()


func _snapshot_is_current() -> bool:
	return _map != null and _map.is_generated() and not _map.is_complete() \
		and _map.get_generation_revision() == _rendered_generation \
		and _map.get_floors() == _rendered_graph \
		and _map.get_route() == _rendered_route \
		and _map.get_legal_choices() == _rendered_legal


## The drawn pin names the party's current patch; it is decoration only.
func _add_pin(id: String, at: Vector2) -> void:
	var pin := CurrentPin.new()
	pin.name = "Pin_current"
	pin.pin_id = id
	pin.set_meta("pin_node_id", id)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.focus_mode = Control.FOCUS_NONE
	pin.position = at + Vector2(NODE_SIZE.x * 0.5 - PIN_SIZE.x * 0.5, -PIN_SIZE.y + 16.0)
	pin.custom_minimum_size = PIN_SIZE
	pin.size = PIN_SIZE
	add_child(pin)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo or not is_inside_tree() or not is_visible_in_tree():
		return
	if key.keycode == KEY_UP or key.keycode == KEY_DOWN:
		if _step_legal_focus(-1 if key.keycode == KEY_UP else 1):
			get_viewport().set_input_as_handled()
		return
	var index := -1
	match key.keycode:
		KEY_1:
			index = 0
		KEY_2:
			index = 1
		KEY_3:
			index = 2
		KEY_4:
			index = 3
	if index < 0 or index >= _rendered_shortcuts.size():
		return
	if _request_node(_rendered_shortcuts[index], _map, _revision):
		get_viewport().set_input_as_handled()


func _request_node(id: String, source_map: RunMap, revision: int) -> bool:
	# A stale callback is invalid even if the old Control has been removed.
	# Check model snapshots too: external progress and regeneration can happen
	# before a caller refreshes the view.
	if source_map == null or _map != source_map or revision != _revision:
		return false
	if not _map.is_generated() or _map.is_complete():
		return false
	if _map.get_generation_revision() != _rendered_generation:
		return false
	if _map.get_floors() != _rendered_graph or _map.get_route() != _rendered_route:
		return false
	var legal := _map.get_legal_choices()
	if legal != _rendered_legal or not legal.has(id):
		return false
	node_requested.emit(id)
	return true


func _inert(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.focus_mode = Control.FOCUS_NONE
