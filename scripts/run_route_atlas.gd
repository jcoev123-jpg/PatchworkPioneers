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
## first column. Each route marker is a hand-sewn angular felt tag (low-corner-radius
## patch, cream stitches crossing its border) that shows its original aspect-preserved
## token art above its high-contrast caption; Treasure/missing art draws a stitched
## emblem, and a focused legal tag wears the same stitched seam inset just inside its
## edge, clear of both the art and the lower caption.
## Beneath every bead the party actually completed, the diary prints that floor's
## stop name, projected through display_kind() from the committed route's real RunMap
## records (a legacy Shop/Rest bead reads Peddler/Campfire); future beads stay blank
## and never leak an upcoming floor's kind.
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
## The authored sewn route tokens: one committed image per exact authored kind.
## Kinds without an entry keep the original drawn paper marker, and so does a token
## whose file cannot be loaded, so a missing PNG never breaks the preview.
const NODE_TOKEN_PATHS := {
	"Unpicker": "res://assets/paper/ui/map_node_unpicker.png",
	"Peddler": "res://assets/paper/ui/map_node_peddler.png",
	"Campfire": "res://assets/paper/ui/map_node_campfire.png",
	"PatchStall": "res://assets/paper/ui/map_node_patch_stall.png",
	"SewingCircle": "res://assets/paper/ui/map_node_sewing_circle.png",
	"Fight": "res://assets/paper/ui/map_node_fight.png",
	"Elite": "res://assets/paper/ui/map_node_elite.png",
	"Event": "res://assets/paper/ui/map_node_event.png",
	"Shop": "res://assets/paper/ui/map_node_shop.png",
	"Rest": "res://assets/paper/ui/map_node_rest.png",
	"Boss": "res://assets/paper/ui/map_node_boss.png",
}
## Maximum drawn token image width inside the sewn tag, above its caption.
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
## Space between the next-area bookmark and the pinned floor trail.
const CHOICE_TICKET_RECT := Rect2(46.0, 94.0, 532.0, 74.0)
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
## Read-only help for the genuine legal patch; all three IDs are transient UI state.
var _choice_ticket: ChoiceTicket = null
var _hovered_choice_id := ""
var _focused_choice_id := ""
## Last map snapshot this view actually rendered, so a repeat refresh never replays.
var _rendered_map: RunMap = null
var _has_snapshot := false
## Optional left-page comparison; never part of the legal Action focus circuit.
var _comparison_sheet: Panel = null
var _compare_button: Button = null
var _comparison_open := false
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


## A sewn angular felt/paper tag: the marker's own low-corner-radius panel, with cream
## stitches crossing its coloured border so it reads as hand-cut cloth rather than a
## round button. Every stitch stays in the border band, so the token art and the lower
## kind/shortcut caption are never covered, and the tag itself takes no input.
class RouteTag extends PanelContainer:
	## Cream thread drawn through the felt, like a running stitch across the seam.
	const THREAD_TICK := Color("#f0e6cf")
	## The tag's own state border colour, so the stitching belongs to the patch.
	var edge_color := RunRouteAtlas.OTHER_BORDER

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	## Stitch thread tinted by the state border, kept light enough to read on every
	## authored felt colour (chosen green, legal tan and inactive grey).
	func stitch_color() -> Color:
		return THREAD_TICK.lerp(edge_color, 0.22)

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var thread := stitch_color()
		# Alternating tick lengths read as a hand-cut edge. Every tick starts at the
		# tag silhouette and stops inside its border band, so neither the token art nor
		# a caption as wide as the tag is ever struck through.
		var index := 0
		var x := 7.0
		while x <= size.x - 7.0:
			var length := 2.2 if index % 2 == 0 else 1.6
			draw_line(Vector2(x, 0.6), Vector2(x, 0.6 + length), thread, 1.4, true)
			draw_line(Vector2(x, size.y - 0.6), Vector2(x, size.y - 0.6 - length),
				thread, 1.4, true)
			index += 1
			x += 10.0
		var y := 7.0
		while y <= size.y - 7.0:
			var length := 2.2 if index % 2 == 0 else 1.6
			draw_line(Vector2(0.6, y), Vector2(0.6 + length, y), thread, 1.4, true)
			draw_line(Vector2(size.x - 0.6, y), Vector2(size.x - 0.6 - length, y),
				thread, 1.4, true)
			index += 1
			y += 10.0
		# One cross stitch sewn through each corner of the tag, clear of the art and
		# of the vertically centred caption band.
		for corner in [Vector2(4.2, 4.2), Vector2(size.x - 4.2, 4.2),
				Vector2(4.2, size.y - 4.2), Vector2(size.x - 4.2, size.y - 4.2)]:
			draw_line(corner + Vector2(-2.2, -2.2), corner + Vector2(2.2, 2.2),
				thread, 1.4, true)
			draw_line(corner + Vector2(2.2, -2.2), corner + Vector2(-2.2, 2.2),
				thread, 1.4, true)


## Inert token art or drawn fallback in the top half of a sewn angular tag.
## The caption sits along the lower edge, and the transparent Action covers the face.
class NodeToken extends Control:
	const PAPER_FILL := Color("#d8c9a2")
	const COIN_RADIUS := 6.5

	## Native sewn pictograms share a 48px drawing box in both map views.
	## art_bottom includes the contour stroke and stays above the atlas caption.
	static func fallback_plan(kind: String) -> Dictionary:
		match kind:
			"Peddler":
				return {"emblem": "purse", "glyph": "", "art_bottom": 49.0}
			"Unpicker":
				return {"emblem": "scissors", "glyph": "", "art_bottom": 49.0}
			"PatchStall":
				return {"emblem": "patch", "glyph": "", "art_bottom": 49.0}
			"Campfire":
				return {"emblem": "flame_logs", "glyph": "", "art_bottom": 49.0}
			"SewingCircle":
				return {"emblem": "needle_thread", "glyph": "", "art_bottom": 49.0}
			"Treasure":
				return {"emblem": "badge", "glyph": "▣", "art_bottom": 49.0}
		return {"emblem": "badge", "glyph": "?", "art_bottom": 49.0}

	## Closed felt silhouettes, in local 48x48 coordinates; shared with the connected book.
	static func emblem_contours(emblem: String) -> Array[PackedVector2Array]:
		match emblem:
			"flame_logs":
				return [PackedVector2Array([Vector2(8, 35), Vector2(39, 41), Vector2(40, 36), Vector2(9, 30)]),
					PackedVector2Array([Vector2(8, 41), Vector2(39, 34), Vector2(38, 29), Vector2(7, 36)]),
					PackedVector2Array([Vector2(15, 31), Vector2(12, 23), Vector2(21, 12), Vector2(25, 5),
						Vector2(29, 18), Vector2(34, 14), Vector2(37, 25), Vector2(30, 33), Vector2(22, 34)])]
			"needle_thread":
				return [PackedVector2Array([Vector2(8, 41), Vector2(28, 8), Vector2(34, 5), Vector2(35, 12)])]
			"scissors":
				return [PackedVector2Array([Vector2(22, 27), Vector2(9, 6), Vector2(29, 23)]),
					PackedVector2Array([Vector2(22, 23), Vector2(39, 6), Vector2(28, 29)])]
			"patch":
				return [PackedVector2Array([Vector2(7, 11), Vector2(35, 6), Vector2(42, 36), Vector2(13, 42)])]
		return []

	static func draw_emblem(canvas: CanvasItem, emblem: String, box: Rect2,
			fill: Color, ink: Color, thread: Color) -> void:
		canvas.draw_set_transform(box.position, 0.0, box.size / 48.0)
		for contour in emblem_contours(emblem):
			canvas.draw_colored_polygon(contour, fill)
			var closed := contour.duplicate()
			closed.append(contour[0])
			canvas.draw_polyline(closed, ink, 1.6, true)
			for i in range(contour.size()):
				var from := contour[i].lerp(Vector2(24, 24), 0.12)
				var to := contour[(i + 1) % contour.size()].lerp(Vector2(24, 24), 0.12)
				canvas.draw_dashed_line(from, to, thread, 1.1, 3.0, true)
		match emblem:
			"needle_thread":
				canvas.draw_line(Vector2(30, 12), Vector2(32, 9), ink, 1.6, true)
				var cord := PackedVector2Array([Vector2(32, 10), Vector2(40, 16), Vector2(40, 28),
					Vector2(32, 35), Vector2(24, 33), Vector2(23, 40), Vector2(34, 43)])
				canvas.draw_polyline(cord, ink, 3.0, true)
				canvas.draw_polyline(cord, thread, 1.3, true)
			"scissors":
				for center in [Vector2(15, 35), Vector2(34, 35)]:
					canvas.draw_arc(center, 7.0, 0, TAU, 24, ink, 3.0, true)
					canvas.draw_arc(center, 7.0, 0, TAU, 24, thread, 1.1, true)
				canvas.draw_circle(Vector2(25, 25), 2.0, thread)
			"patch":
				canvas.draw_line(Vector2(17, 17), Vector2(32, 31), ink, 1.6, true)
				canvas.draw_line(Vector2(30, 15), Vector2(19, 33), ink, 1.6, true)
		canvas.draw_set_transform(Vector2.ZERO)

	var token_kind := ""
	var token_texture: Texture2D = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	## Keep art centred in the upper portion of the tag, leaving the lower row for
	## the readable kind and live shortcut number.
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
		var plan := fallback_plan(token_kind)
		if not emblem_contours(str(plan["emblem"])).is_empty():
			draw_emblem(self, str(plan["emblem"]), Rect2(size.x * 0.5 - 24.0, 2.0, 48.0, 48.0),
				PAPER_FILL, RunRouteAtlas.INK, RunRouteAtlas.THREAD)
			return
		var middle := Vector2(size.x * 0.5, 26.0)
		if str(plan["emblem"]) == "purse":
			_draw_coin_purse(middle)
			return
		# Treasure and unknown/missing textures receive a stitched paper emblem.
		draw_circle(middle, 23.0, PAPER_FILL)
		draw_arc(middle, 21.0, 0.0, TAU, 32, RunRouteAtlas.INK, 1.6, true)
		for offset in [-17.0, -5.0, 7.0]:
			draw_line(middle + Vector2(offset, -18), middle + Vector2(offset + 5, -18),
				RunRouteAtlas.THREAD, 2.0, true)
		var font := get_theme_default_font()
		if font != null:
			draw_string(font, middle + Vector2(-10, 9), str(plan["glyph"]),
				HORIZONTAL_ALIGNMENT_CENTER, 20.0, 27, RunRouteAtlas.INK)

	## Peddler's drawn fallback: two cream coins above a tied, ink-outlined purse stitched
	## with the tag's own running thread. It is a pouch silhouette, not a lettered disc, so
	## even beside every other fallback it reads as the Peddler stop.
	func _draw_coin_purse(middle: Vector2) -> void:
		for coin in [middle + Vector2(-8.0, -16.0), middle + Vector2(9.0, -19.0)]:
			draw_circle(coin, COIN_RADIUS, PAPER_FILL)
			draw_arc(coin, COIN_RADIUS, 0.0, TAU, 20, RunRouteAtlas.INK, 1.6, true)
			draw_line(coin + Vector2(-3.2, 0.0), coin + Vector2(3.2, 0.0),
				RunRouteAtlas.THREAD, 1.6, true)
		# The tied neck band the drawstring gathers.
		draw_rect(Rect2(middle.x - 9.0, middle.y - 10.0, 18.0, 6.0), PAPER_FILL)
		draw_rect(Rect2(middle.x - 9.0, middle.y - 10.0, 18.0, 6.0),
			RunRouteAtlas.INK, false, 1.4)
		# A plump pouch below the neck, clearly wider and rounder than any badge disc.
		var pouch := PackedVector2Array([
			middle + Vector2(-9.0, -4.0),
			middle + Vector2(-16.0, 7.0),
			middle + Vector2(-12.0, 20.0),
			middle + Vector2(0.0, 23.0),
			middle + Vector2(12.0, 20.0),
			middle + Vector2(16.0, 7.0),
			middle + Vector2(9.0, -4.0),
		])
		draw_colored_polygon(pouch, PAPER_FILL)
		var outline := pouch.duplicate()
		outline.append(pouch[0])
		draw_polyline(outline, RunRouteAtlas.INK, 1.6, true)
		# Cream running stitches tie the purse to the sewn tag language.
		for row in range(3):
			var y := middle.y + 2.0 + float(row) * 5.0
			draw_line(Vector2(middle.x - 8.0 + float(row) * 1.6, y),
				Vector2(middle.x + 8.0 - float(row) * 1.6, y),
				RunRouteAtlas.THREAD, 1.4, true)

## The Action draws a sewn inset seam WITHIN its angular felt tag when focused: a
## double dashed rectangle hugging the inside of the tag silhouette, with a cross
## stitch at each corner. It stays in the tag's border band, so neither the token art
## nor the authored 18-point caption (which can be as wide as the tag) is covered.
class LegalPatchAction extends Button:
	const SEAM_DARK := Color("#272f32")
	const SEAM_LIGHT := Color("#fff1c6")
	const SEAM_DASH := 6.0
	## The Action fills the tag's content rect, so these local insets land just inside
	## the tag silhouette: on the state border, short of every child Control.
	const SEAM_INSET := 1.5

	func _init() -> void:
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	## Inset rectangular seam in this Action's own coordinates.
	func seam_rect() -> Rect2:
		return Rect2(-SEAM_INSET, -SEAM_INSET, size.x + SEAM_INSET * 2.0,
			size.y + SEAM_INSET * 2.0)

	func _draw() -> void:
		if not has_focus():
			return
		var seam := seam_rect()
		if seam.size.x <= 0.0 or seam.size.y <= 0.0:
			return
		var top_left := seam.position
		var top_right := Vector2(seam.end.x, seam.position.y)
		var bottom_right := seam.end
		var bottom_left := Vector2(seam.position.x, seam.end.y)
		# Dark underlay then cream thread: the seam stays visible on every felt colour
		# while both strokes stop inside the 3px border band, clear of the art and of a
		# caption as wide as the tag itself.
		for pass_index in range(2):
			var color := SEAM_DARK if pass_index == 0 else SEAM_LIGHT
			var width := 2.6 if pass_index == 0 else 1.8
			draw_dashed_line(top_left, top_right, color, width, SEAM_DASH)
			draw_dashed_line(top_right, bottom_right, color, width, SEAM_DASH)
			draw_dashed_line(bottom_right, bottom_left, color, width, SEAM_DASH)
			draw_dashed_line(bottom_left, top_left, color, width, SEAM_DASH)
		# Corner cross stitches tie the seam down at the tag's own corners.
		for corner in [top_left, top_right, bottom_right, bottom_left]:
			draw_line(corner + Vector2(-2.0, -2.0), corner + Vector2(2.0, 2.0),
				SEAM_DARK, 3.2, true)
			draw_line(corner + Vector2(2.0, -2.0), corner + Vector2(-2.0, 2.0),
				SEAM_DARK, 3.2, true)
			draw_line(corner + Vector2(-2.0, -2.0), corner + Vector2(2.0, 2.0),
				SEAM_LIGHT, 1.6, true)
			draw_line(corner + Vector2(2.0, -2.0), corner + Vector2(-2.0, 2.0),
				SEAM_LIGHT, 1.6, true)


## One pointer- and focus-inert sewn paper ticket on the real left book page.
## All facts are fixed by stop kind, never by an encounter, reward roll or future RNG.
class ChoiceTicket extends Control:
	const FONT_SIZE := 18
	var route_id := ""
	var header_text := ""
	var lead_text := ""
	var detail_text := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	func set_choice(id: String, header: String, lead: String, detail: String) -> void:
		route_id = id
		header_text = header
		lead_text = lead
		detail_text = detail
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color("#eee4cb"))
		draw_rect(rect, RunRouteAtlas.INK, false, 2.0)
		draw_dashed_line(Vector2(7, 5), Vector2(size.x - 7, 5),
			RunRouteAtlas.THREAD, 1.5, 7.0)
		draw_dashed_line(Vector2(7, size.y - 5), Vector2(size.x - 7, size.y - 5),
			RunRouteAtlas.THREAD, 1.5, 7.0)
		var font := get_theme_default_font()
		if font == null:
			return
		var width := size.x - 28.0
		draw_string(font, Vector2(14, 23), header_text,
			HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE, RunRouteAtlas.INK)
		draw_string(font, Vector2(14, 45), lead_text,
			HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE, RunRouteAtlas.INK)
		draw_string(font, Vector2(14, 66), detail_text,
			HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE, RunRouteAtlas.INK)


## Left-hand travel diary: an inert high-contrast sewn-paper journey and pinned
## twelve-floor progress trail. It never invents a route choice or reads RNG.
class JourneyJournal extends Control:
	## The diary's body-text floor (VIS V6): every bead numeral, completed-kind caption, the
	## second display heading and the progress footer reads at least this many points.
	const BEAD_FONT_SIZE := 18
	const KIND_FONT_SIZE := 18
	const SECTION_HEADING_FONT_SIZE := 18
	const FOOTER_FONT_SIZE := 18
	## Diary-local spacing. Three rows of four beads are spread so an 18-point kind caption
	## and the current-floor pin still clear the neighbouring row and the progress footer.
	const SECTION_HEADING_BASELINE := 139.0
	const BEAD_FIRST := Vector2(59.0, 177.0)
	const BEAD_COLUMN_STEP := 132.0
	const BEAD_ROW_STEP := 61.0
	const BEAD_RADIUS := 17.0
	## Baseline of a committed kind below its own bead, and the caption column it centres in.
	const CAPTION_BASELINE := 34.0
	const CAPTION_WIDTH := 116.0

	var current_floor := 0
	var current_area := ""
	var next_floor := 1
	var next_area := ""
	var complete := false
	var visited: Array[String] = []
	## One authentic authored kind per committed floor, in route order, projected by
	## _add_journal through display_kind() from the real RunMap record of each committed
	## ID. It is never inferred from an ID, filled from an unvisited node or consumed
	## by input.
	var visited_kinds: Array[String] = []
	## Cached committed heading face, so redraws never re-probe the shipped font file.
	var _fallback_heading: Font = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	## Read-only copy of the visited-kind captions this diary draws, in route order.
	func visited_kind_sequence() -> Array[String]:
		return visited_kinds.duplicate()

	## The exact caption this diary paints below bead `floor_index` (zero-based): the committed
	## kind for a floor the party already finished, otherwise blank. The current bead and every
	## future bead therefore stay empty, and no unvisited floor is ever projected.
	func caption_kind(floor_index: int) -> String:
		if floor_index < 0 or floor_index >= current_floor:
			return ""
		if floor_index >= visited_kinds.size():
			return ""
		return visited_kinds[floor_index]

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
		draw_string(heading, Vector2(22, 35), "THE SEWN JOURNEY",
			HORIZONTAL_ALIGNMENT_LEFT, 480.0, 25, RunRouteAtlas.INK)
		var here := "Trailhead" if current_floor == 0 else current_area
		draw_string(font, Vector2(22, 69),
			"Current: %s  ·  Floor %d/12" % [here, current_floor],
			HORIZONTAL_ALIGNMENT_LEFT, 495.0, 21, RunRouteAtlas.INK)
		var next_text := "Route complete · The final stitch is tied" if complete else (
			"Next: %s  ·  Floor %d/12" % [next_area, next_floor])
		draw_string(font, Vector2(22, 101), next_text,
			HORIZONTAL_ALIGNMENT_LEFT, 495.0, 18, RunRouteAtlas.INK)
		draw_dashed_line(Vector2(22, 120), Vector2(size.x - 22, 120),
			RunRouteAtlas.THREAD, 2.0, 8.0)
		draw_string(heading, Vector2(22, SECTION_HEADING_BASELINE), "PINNED FLOOR TRAIL",
			HORIZONTAL_ALIGNMENT_LEFT, 490.0, SECTION_HEADING_FONT_SIZE, RunRouteAtlas.INK)
		var beads: Array[Vector2] = []
		for i in range(12):
			beads.append(BEAD_FIRST + Vector2(float(i % 4) * BEAD_COLUMN_STEP,
				float(i / 4) * BEAD_ROW_STEP))
		for i in range(11):
			draw_dashed_line(beads[i], beads[i + 1], RunRouteAtlas.THREAD, 2.0, 7.0)
		for i in range(12):
			var point := beads[i]
			var done := i < current_floor
			draw_circle(point, BEAD_RADIUS,
				RunRouteAtlas.CHOSEN_BG if done else RunRouteAtlas.PAPER_SHADE)
			draw_arc(point, BEAD_RADIUS, 0.0, TAU, 28,
				RunRouteAtlas.CHOSEN_THREAD if done else RunRouteAtlas.INK, 2.0, true)
			draw_string(font, point + Vector2(-10.0, 6.0), "%02d" % (i + 1),
				HORIZONTAL_ALIGNMENT_CENTER, 20.0, BEAD_FONT_SIZE,
				Color("#ffffff") if done else RunRouteAtlas.INK)
			# Completed beads carry their real visit kind below the numbered disc.
			# An unvisited bead keeps that space blank, so no future kind is shown.
			var kind := caption_kind(i)
			if not kind.is_empty():
				draw_string(font, point + Vector2(-CAPTION_WIDTH * 0.5, CAPTION_BASELINE), kind,
					HORIZONTAL_ALIGNMENT_CENTER, CAPTION_WIDTH, KIND_FONT_SIZE, RunRouteAtlas.INK)
		# The diary's real pushpin points to the latest committed bead.
		if current_floor > 0:
			var pin := beads[current_floor - 1] + Vector2(0, -23)
			draw_line(pin, pin + Vector2(0, 22), RunRouteAtlas.INK, 2.0)
			draw_circle(pin, 7.0, Color("#bd5149"))
		draw_string(font, Vector2(22, size.y - 20),
			"Stitched route  ·  %d of 12 floors visited" % visited.size(),
			HORIZONTAL_ALIGNMENT_LEFT, 490.0, FOOTER_FONT_SIZE, RunRouteAtlas.INK)


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
	# Project each committed ID through the authoritative model once, in route order.
	# Only visited records are read; an unvisited floor is never queried for display.
	# The committed kind passes through the same display_kind() projection as markers,
	# hover and choice tickets, so a legacy Shop/Rest bead captions Peddler/Campfire
	# while the authored RunMap record keeps its own raw type and ID.
	var kinds: Array[String] = []
	for id in chosen:
		kinds.append(display_kind(str(_map.get_node(id).get("type", ""))))
	journal.visited_kinds = kinds
	journal.position = Vector2(46.0, 174.0)
	journal.size = Vector2(532.0, 400.0)
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
	visibility_changed.connect(_on_atlas_visibility_changed)


## A map may be bound before the view enters the tree (the overlay does exactly that),
## so queued reveals start on the first processed frame instead of being dropped.
func _process(_delta: float) -> void:
	# External route progress/regeneration also removes obsolete advice before a refresh.
	if is_instance_valid(_choice_ticket) and not _snapshot_is_current():
		_choice_ticket.hide()
	if _comparison_open and (not is_visible_in_tree() or not _snapshot_is_current()):
		_clear_comparison()
		if is_instance_valid(_compare_button) and not _snapshot_is_current():
			_compare_button.hide()
	if _pending_reveals.is_empty():
		set_process(is_instance_valid(_choice_ticket))
		return
	if not is_inside_tree():
		return
	var queued := _pending_reveals.duplicate()
	_pending_reveals.clear()
	for line in queued:
		var mask: Gradient = _reveal_masks.get(line)
		if is_instance_valid(line) and mask != null:
			_start_reveal_tween(line, mask)
	set_process(is_instance_valid(_choice_ticket))


## Leaving the tree releases every reveal: no tween may outlive its threads.
func _exit_tree() -> void:
	_clear_comparison()
	_teardown_reveal()


func _on_atlas_visibility_changed() -> void:
	if not is_visible_in_tree():
		_clear_comparison()


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
	# Retire any open comparison and its old generation before replacing the UI.
	_clear_comparison()
	_compare_button = null
	# Kill and release every prior reveal before its threads are removed.
	_teardown_reveal()
	_rendered_graph = []
	_rendered_generation = 0
	_rendered_route.clear()
	_rendered_legal.clear()
	_rendered_shortcuts.clear()
	_legal_actions.clear()
	_actions_by_id.clear()
	_choice_ticket = null
	_hovered_choice_id = ""
	_focused_choice_id = ""
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
	if not _rendered_shortcuts.is_empty():
		_add_choice_ticket()
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
	if _choice_ticket != null:
		_show_choice_ticket(_rendered_shortcuts[0])
	_rebuild_focus_chain(focused_id)
	if not _rendered_shortcuts.is_empty():
		_add_compare_button()


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


## Mouse-only compare control: focus stays with Close map or the selected legal tag.
## The sole signal connection is guarded by the exact map object and view revision.
func _add_compare_button() -> void:
	var button := Button.new()
	button.name = "CompareToggle"
	button.text = "Compare choices"
	button.tooltip_text = "Compare all legal next stops (C)"
	button.position = Vector2(431.0, 187.0)
	button.size = Vector2(139.0, 32.0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER
	paper.border_color = INK
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(5)
	for state_name in ["normal", "hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state_name, paper)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(_toggle_comparison.bind(_map, _revision))
	add_child(button)
	_compare_button = button


## A retained mouse callback from a previous refresh/generation is forever inert.
## No comparison control calls _request_node or emits node_requested.
func _toggle_comparison(source_map: RunMap, revision: int) -> bool:
	if source_map == null or source_map != _map or revision != _revision:
		return false
	if not is_inside_tree() or not is_visible_in_tree() \
			or not _snapshot_is_current() or _rendered_shortcuts.is_empty() \
			or not is_instance_valid(_compare_button):
		_clear_comparison()
		return false
	if _comparison_open:
		_clear_comparison()
	else:
		_open_comparison()
	return true


func comparison_is_open() -> bool:
	return _comparison_open and is_instance_valid(_comparison_sheet) \
		and _comparison_sheet.visible and is_visible_in_tree() and _snapshot_is_current()


## Retire rows synchronously, not queue_free: a same-frame stale hover or click
## cannot find them, and repeated openings never accumulate sheets or callbacks.
func _clear_comparison() -> void:
	_comparison_open = false
	if is_instance_valid(_comparison_sheet):
		if _comparison_sheet.get_parent() == self:
			remove_child(_comparison_sheet)
		_comparison_sheet.free()
	_comparison_sheet = null
	var journal := get_node_or_null("JourneyJournal") as Control
	if journal != null:
		journal.show()
	if is_instance_valid(_compare_button):
		_compare_button.text = "Compare choices"
		_compare_button.tooltip_text = "Compare all legal next stops (C)"


## Only text already authored for legal nodes is shown. Longer lines visibly offer
## their full deterministic rules in the row tooltip instead of silently clipping.
static func _compare_excerpt(value: String, limit: int = 49) -> String:
	if value.length() <= limit:
		return value
	return value.substr(0, limit - 11).strip_edges() + "… (hover)"


func _compare_label(parent: Control, title: String, value: String,
		at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.name = title
	label.text = value
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	_inert(label)
	parent.add_child(label)
	return label


## The left-page sheet contains at most four inert rows, in exactly the marker
## shortcut order. Every fact comes from get_node() and the existing ticket helpers;
## no off-route node, encounter/reward roll or persistent party data is consulted.
func _open_comparison() -> void:
	_clear_comparison()
	if not _snapshot_is_current() or _rendered_shortcuts.size() > 4:
		return
	var sheet := Panel.new()
	sheet.name = "CompareChoices"
	sheet.position = Vector2(46.0, 174.0)
	sheet.size = Vector2(532.0, 400.0)
	sheet.custom_minimum_size = sheet.size
	sheet.focus_mode = Control.FOCUS_NONE
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#eee4cb")
	paper.border_color = INK
	paper.set_border_width_all(2)
	sheet.add_theme_stylebox_override("panel", paper)
	# Reuse the diary's existing stitched-paper drawing (no generated art).
	var sewn_backing := NextAreaTab.new()
	sewn_backing.name = "StitchedPaper"
	sewn_backing.size = sheet.size
	_inert(sewn_backing)
	sheet.add_child(sewn_backing)
	_compare_label(sheet, "Heading", "COMPARE NEXT STOPS",
		Vector2(16, 12), Vector2(355, 31), 24)
	_compare_label(sheet, "Hint", "Read only · select on the right page (1–4)",
		Vector2(16, 42), Vector2(495, 19), 15)
	for index in range(_rendered_shortcuts.size()):
		var id := _rendered_shortcuts[index]
		var record := _map.get_node(id)
		if record.is_empty():
			sheet.free()
			return
		var kind := str(record.get("type", ""))
		var shown := display_kind(kind)
		var facts := stop_consequence(help_kind(kind))
		var lead := str(facts.get("lead", "No fixed stop outcome"))
		var detail := str(facts.get("detail", "Visit to learn more"))
		var threat := normal_fight_threat(record)
		if not threat.is_empty():
			detail += " · " + threat
		var row := Panel.new()
		row.name = "ComparisonRow%d" % (index + 1)
		row.position = Vector2(12, 67 + index * 81)
		row.size = Vector2(508, 77)
		row.custom_minimum_size = row.size
		row.focus_mode = Control.FOCUS_NONE
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.set_meta("route_id", id)
		row.set_meta("authored_kind", kind)
		var row_paper := StyleBoxFlat.new()
		row_paper.bg_color = Color("#f6edd8") if index % 2 == 0 else Color("#e6d7b8")
		row_paper.border_color = THREAD
		row_paper.set_border_width_all(1)
		row.add_theme_stylebox_override("panel", row_paper)
		var header := "%d · FLOOR %02d · BRANCH %d · %s" % [
			index + 1, int(record["floor"]), int(record["position"]) + 1, shown]
		_compare_label(row, "Identity", header,
			Vector2(10, 2), Vector2(485, 24), 18)
		_compare_label(row, "Lead", _compare_excerpt(lead),
			Vector2(10, 26), Vector2(485, 23), 16)
		_compare_label(row, "Detail", _compare_excerpt(detail),
			Vector2(10, 48), Vector2(485, 24), 15)
		row.tooltip_text = "%s\n%s\n%s\n%s" % [
			header, lead, detail, str(facts.get("tooltip", ""))]
		sheet.add_child(row)
	add_child(sheet)
	_comparison_sheet = sheet
	_comparison_open = true
	var journal := get_node_or_null("JourneyJournal") as Control
	if journal != null:
		journal.hide()
	_compare_button.text = "Back to diary"
	_compare_button.tooltip_text = "Restore the sewn journey (C or Escape)"
	# The floating mouse button stays reachable above the comparison paper.
	move_child(_compare_button, get_child_count() - 1)


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


## The stop the player actually enters for one authored route kind. A generated legacy
## Shop/Rest patches open Peddler/Campfire visits, so their sewn markers, hover and
## tickets use those names while authored RunMap records keep their own type and ID.
## Native kinds keep their own name.
## The existing v3 alias rule supplies the projected name; this is presentation only,
## never a node mutation or a second competing alias table.
static func display_kind(kind: String) -> String:
	return RunV3StopChoiceProjection.v3_kind_for(kind)


## Kind whose deterministic stop guidance describes the visit actually entered. The
## marker keeps its authored identity in metadata; Help uses the projected rules.
static func help_kind(kind: String) -> String:
	return display_kind(kind)


## Player-facing sewn route wording for one REAL RunMap node record: its authored
## floor, kind and one-based branch row. The f##_n# ID is never read to guess either
## value, so a renamed ID could not change the words. A missing record keeps the
## authored kind alone, which is what a standalone marker without a bound map has.
## Only deterministic, authored stop rules belong here. Unknown kinds have no advice.
## The detailed Rest alternative is tooltip-only so the small ticket stays legible.
static func stop_consequence(kind: String) -> Dictionary:
	match kind:
		"Unpicker":
			return {"lead": "Choose one: remove a card or leave",
				"detail": "Remove: 75 gold initially, +25 each time",
				"tooltip": "Remove one owned card for 75 gold plus 25 per previous removal, or leave unchanged"}
		"PatchStall":
			return {"lead": "Choose one: buy a patch or leave",
				"detail": "3 priced power patches; choose a wearer; sewing included",
				"tooltip": "Buy one of 3 priced power patches for one chosen hero, sewing included, or leave unchanged"}
		"Campfire":
			return {"lead": "Choose one: heal or leave",
				"detail": "Heal 30% max HP; torn revives at 1 HP first",
				"tooltip": "One action: heal each hero 30% max HP (torn revives at 1 HP first), or leave unchanged"}
		"SewingCircle":
			return {"lead": "Choose one: upgrade or stitch",
				"detail": "Stitch different owners: 3 scraps; or leave",
				"tooltip": "Upgrade one card, stitch two different-owner cards for 3 scraps, or leave unchanged"}
		"Fight":
			return {"lead": "Win: 10–20 gold + 1 scrap",
				"detail": "Choose 1 of 3 cards, or skip",
				"tooltip": "On win: 10–20 gold + 1 scrap; choose 1 of 3 cards or skip"}
		"Elite":
			return {"lead": "Win: 25–35 gold + 2 scraps + patch",
				"detail": "Choose 1 of 3 cards, or skip",
				"tooltip": "On win: 25–35 gold + 2 scraps + patch; choose 1 of 3 cards or skip"}
		"Rest":
			return {"lead": "Choose one: heal, upgrade, stitch or re-sew",
				"detail": "Heal 30% max HP; stitch 3 scraps; re-sew 1 scrap",
				"tooltip": "One action: heal each hero 30% max HP (torn revives at 1 HP first), upgrade one card, stitch two different-owner cards for 3 scraps, or re-sew an equipped patch for 1 scrap"}
		"Shop":
			return {"lead": "Browse 5 cards + 2 patches",
				"detail": "Remove card: 75 gold initially, +25 each time",
				"tooltip": "5 cards + 2 patches; card removal starts at 75 gold, increasing 25 per removal"}
		"Peddler":
			return {"lead": "Choose one: buy 1 of 3 hero cards or 1 patch",
				"detail": "All 4 priced on the stock; one purchase, or leave",
				"tooltip": "Buy one of 3 priced party-hero cards (one per hero) or the one priced patch, one purchase per visit, or leave; actual prices appear on the stock"}
		"Event":
			return {"lead": "2–3 choices when visited",
				"detail": "Outcomes shown on arrival; no guaranteed yield",
				"tooltip": "2–3 choices; outcomes revealed on visit, no guaranteed yield"}
		"Treasure":
			return {"lead": "Treasure stop · contents not yet known",
				"detail": "No fixed reward is specified by the route",
				"tooltip": "Treasure stop; no predetermined reward amount is known"}
		"Boss":
			return {"lead": "Final floor-12 fight",
				"detail": "The last stop on this route",
				"tooltip": "Terminal floor-12 fight"}
	return {}


## Normal Fight guidance only: use the same authoritative scaler as routed combat,
## including its strict floor/type gates and truncated 5/9 attack bounds. The HP
## multiplier is measured with a divisible base HP, not independently reimplemented.
## Neither an encounter roster nor a route ID is involved in this preview.
static func normal_fight_threat(node: Dictionary) -> String:
	if node.get("type") != "Fight" or typeof(node.get("floor")) != TYPE_INT:
		return ""
	var floor_number: int = node["floor"]
	var low := RunNormalAttackFloorScaling.scale_normal_attack(5, floor_number)
	var high := RunNormalAttackFloorScaling.scale_normal_attack(9, floor_number)
	var hp := RunNormalAttackFloorScaling.scale_normal_max_hp(4, floor_number)
	if not low.get("ok", false) or not high.get("ok", false) or not hp.get("ok", false):
		return ""
	return "Normals x%s HP/ATK; hits %d-%d" % [
		str(float(hp["max_hp"]) / 4.0), int(low["amount"]), int(high["amount"])]


static func node_hover_text(node: Dictionary, fallback_kind: String = "",
		show_consequence: bool = false) -> String:
	if node.is_empty() or not (node.has("floor") and node.has("position")):
		return display_kind(fallback_kind)
	var kind := str(node.get("type", fallback_kind))
	var prefix := "Floor %02d · %s · Branch %d" % [
		int(node["floor"]), display_kind(kind), int(node["position"]) + 1]
	if show_consequence:
		var facts := stop_consequence(help_kind(kind))
		if not facts.is_empty():
			var threat := normal_fight_threat(node)
			return prefix + " · " + str(facts["tooltip"]) + (" · " + threat if not threat.is_empty() else "")
	return prefix


## The ticket is created once per snapshot; neither it nor its children accept input.
func _add_choice_ticket() -> void:
	var ticket := ChoiceTicket.new()
	ticket.name = "ChoiceTicket"
	ticket.position = CHOICE_TICKET_RECT.position
	ticket.size = CHOICE_TICKET_RECT.size
	ticket.custom_minimum_size = CHOICE_TICKET_RECT.size
	_inert(ticket)
	add_child(ticket)
	_choice_ticket = ticket
	set_process(true)


## Exposed for read-only checks; never returns stale information as current.
func choice_ticket() -> ChoiceTicket:
	if not _snapshot_is_current() or _rendered_shortcuts.is_empty():
		if is_instance_valid(_choice_ticket):
			_choice_ticket.hide()
		return null
	return _choice_ticket if is_instance_valid(_choice_ticket) else null


func _show_choice_ticket(id: String) -> void:
	if not _snapshot_is_current() or not _rendered_shortcuts.has(id) \
			or not is_instance_valid(_choice_ticket):
		return
	var record := _map.get_node(id)
	if record.is_empty():
		return
	var kind := str(record.get("type", ""))
	var shown := display_kind(kind)
	var facts := stop_consequence(help_kind(kind))
	if facts.is_empty():
		return
	var header := "%s · FLOOR %02d · BRANCH %d" % [
		area_for_floor(int(record["floor"])).to_upper(), int(record["floor"]),
		int(record["position"]) + 1]
	var threat := normal_fight_threat(record)
	_choice_ticket.set_choice(id, header, shown + " · " + str(facts["lead"]),
		str(facts["detail"]) + (" · " + threat if not threat.is_empty() else ""))
	_choice_ticket.show()


## Callbacks retained from an old revision/map cannot change the new ticket.
## If the live graph advanced without a refresh, its old help is hidden.
func _choice_callback_valid(id: String, source_map: RunMap, revision: int) -> bool:
	if source_map != _map or revision != _revision:
		return false
	if not _snapshot_is_current():
		if is_instance_valid(_choice_ticket):
			_choice_ticket.hide()
		return false
	return _rendered_shortcuts.has(id) and _actions_by_id.has(id)


func _hover_choice(id: String, source_map: RunMap, revision: int) -> void:
	if not _choice_callback_valid(id, source_map, revision):
		return
	_hovered_choice_id = id
	_show_choice_ticket(id)


func _leave_choice_hover(id: String, source_map: RunMap, revision: int) -> void:
	if not _choice_callback_valid(id, source_map, revision):
		return
	if _hovered_choice_id == id:
		_hovered_choice_id = ""
	_restore_choice_ticket()


func _focus_choice(id: String, source_map: RunMap, revision: int) -> void:
	if not _choice_callback_valid(id, source_map, revision):
		return
	_focused_choice_id = id
	if _hovered_choice_id.is_empty():
		_show_choice_ticket(id)


func _leave_choice_focus(id: String, source_map: RunMap, revision: int) -> void:
	if not _choice_callback_valid(id, source_map, revision):
		return
	if _focused_choice_id == id:
		_focused_choice_id = ""
	_restore_choice_ticket()


func _restore_choice_ticket() -> void:
	if not _snapshot_is_current() or _rendered_shortcuts.is_empty():
		return
	var id := _hovered_choice_id
	if id.is_empty():
		id = _focused_choice_id if _rendered_shortcuts.has(_focused_choice_id) \
			else _rendered_shortcuts[0]
	_show_choice_ticket(id)


func _add_marker(id: String, kind: String, at: Vector2,
		chosen: Array[String], legal: Array[String], shortcut: int) -> void:
	var marker := RouteTag.new()
	marker.name = "Node_" + id
	marker.set_meta("route_id", id)
	# Authored kind and ID stay the route protocol; only the player-facing face of a
	# legacy Shop/Rest patch projects to the Peddler/Campfire stop it actually opens.
	marker.set_meta("route_kind", kind)
	var shown := display_kind(kind)
	marker.set_meta("display_kind", shown)
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
	# An angular hand-cut tag, not a round button: barely rounded corners, and the
	# RouteTag overlay sews cream stitches across this border band.
	paper.corner_radius_top_left = 6
	paper.corner_radius_top_right = 4
	paper.corner_radius_bottom_left = 4
	paper.corner_radius_bottom_right = 6
	paper.content_margin_left = 3.0
	paper.content_margin_right = 3.0
	paper.content_margin_top = 3.0
	paper.content_margin_bottom = 3.0
	marker.add_theme_stylebox_override("panel", paper)
	marker.edge_color = paper.border_color
	marker.position = at
	marker.custom_minimum_size = NODE_SIZE
	marker.size = NODE_SIZE
	var record: Dictionary = _map.get_node(id) if _map != null else {}
	var hover := node_hover_text(record, kind, state == "legal")
	marker.tooltip_text = hover
	_inert(marker)
	var art := NodeToken.new()
	art.name = "Art"
	art.token_kind = shown
	var token_path := node_token_path(shown)
	art.token_texture = node_token_texture(token_path)
	art.set_meta("route_kind", kind)
	art.set_meta("display_kind", shown)
	art.set_meta("art_path", token_path)
	art.position = Vector2(3.0, 3.0)
	art.size = NODE_SIZE - Vector2(6.0, 6.0)
	_inert(art)
	marker.add_child(art)
	var caption := Label.new()
	caption.name = "Identity"
	caption.text = (str(shortcut) + " " if state == "legal" and shortcut > 0 else "") + shown
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	caption.add_theme_font_size_override("font_size", 18)
	caption.add_theme_color_override("font_color", Color("#fff8e9"))
	caption.add_theme_constant_override("outline_size", 3)
	caption.add_theme_color_override("font_outline_color", Color("#292a2b"))
	_inert(caption)
	marker.add_child(caption)
	if state == "legal":
		var action := LegalPatchAction.new()
		action.name = "Action"
		action.flat = true
		# The LegalPatchAction draws its own inset sewn seam; the theme's rectangular
		# focus box is suppressed so the tag silhouette stays clean.
		for state_name in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			action.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
		action.focus_mode = Control.FOCUS_ALL
		action.mouse_filter = Control.MOUSE_FILTER_STOP
		action.position = Vector2(2, 2)
		action.size = NODE_SIZE - Vector2(4, 4)
		action.tooltip_text = "Choose %s (key %d)" % [hover, shortcut]
		action.set_meta("route_id", id)
		action.pressed.connect(_request_node.bind(id, _map, _revision))
		action.mouse_entered.connect(_hover_choice.bind(id, _map, _revision))
		action.mouse_exited.connect(_leave_choice_hover.bind(id, _map, _revision))
		action.focus_entered.connect(_focus_choice.bind(id, _map, _revision))
		action.focus_exited.connect(_leave_choice_focus.bind(id, _map, _revision))
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
			_focus_choice(str(restore.get_meta("route_id")), _map, _revision)


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
	return _has_snapshot and _rendered_map == _map \
		and _map != null and _map.is_generated() and not _map.is_complete() \
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
	if key.keycode == KEY_C:
		if not (key.shift_pressed or key.ctrl_pressed or key.alt_pressed or key.meta_pressed) \
				and _toggle_comparison(_map, _revision):
			get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_ESCAPE and _comparison_open:
		_clear_comparison()
		get_viewport().set_input_as_handled()
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
