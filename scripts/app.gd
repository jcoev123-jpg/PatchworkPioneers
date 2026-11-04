extends Control

var run_difficulty := RunDifficulty.new()
var _run_tier := 0
var _difficulty_completed_map: RunMap
var heirloom_unlocked := false
const PROFILE_VERSION := 1
@export var difficulty_save_path := "user://quilt_difficulty.json"


func difficulty_state() -> Dictionary:
	return run_difficulty.get_state()


## Save/profile boundary: only idle title state can restore this two-field record.
func restore_difficulty_state(state: Variant) -> bool:
	if run_map != null or deck != null or is_instance_valid(base_screen) \
		or not is_instance_valid(title_view) or not title_view.is_visible_in_tree():
		return false
	return run_difficulty.restore_state(state)


## The public RunDifficulty contract stays exactly two fields. Only the app owns
## progression's versioned envelope, and both branches restore atomically.
func profile_state() -> Dictionary:
	return {"version": PROFILE_VERSION, "difficulty": difficulty_state(),
		"heirloom_unlocked": heirloom_unlocked}


func restore_profile_state(raw: Variant) -> bool:
	if not (raw is Dictionary):
		return false
	var difficulty: Variant = raw
	var unlocked := false
	if raw.has("version"):
		if raw.size() != 3 or typeof(raw.get("version")) not in [TYPE_INT, TYPE_FLOAT] \
				or not is_finite(float(raw["version"])) or raw["version"] != PROFILE_VERSION \
				or not raw.has("difficulty") or typeof(raw.get("heirloom_unlocked")) != TYPE_BOOL:
			return false
		difficulty = raw["difficulty"]
		unlocked = raw["heirloom_unlocked"]
	# A separate validator protects the live difficulty and progression flag
	# from partial restoration when the saved tier is malformed or unearned.
	var validator := RunDifficulty.new()
	if not validator.restore_state(difficulty) or not restore_difficulty_state(difficulty):
		return false
	heirloom_unlocked = unlocked
	return true


## Only the running game's root owns the profile file. Embedded app views
## (including previews) retain their own state without writing the profile.
func _load_difficulty_progress() -> void:
	if get_tree().current_scene != self or difficulty_save_path.is_empty() \
		or not FileAccess.file_exists(difficulty_save_path):
		return
	var file := FileAccess.open(difficulty_save_path, FileAccess.READ)
	if file != null:
		restore_profile_state(JSON.parse_string(file.get_as_text()))


func _save_difficulty_progress() -> void:
	if get_tree().current_scene != self or difficulty_save_path.is_empty():
		return
	var file := FileAccess.open(difficulty_save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(profile_state()))
## Root of the game. The hand view delegates all card movement to CombatDeck.

signal start_run_requested

## Presentation only: follows the original visit column without reparenting controls.
## Ownership by the art bed makes Continue/Return retire the surface and its bindings.
class ShopActionBacking extends Panel:
	const SHELL := preload("res://scripts/patchwork_ui_shell.gd")
	const PADDING := 10.0
	var _view: WeakRef

	func bind_view(view: Control) -> void:
		name = "ShopActionBacking"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		var surface := get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat
		surface.bg_color.a = 1.0
		add_theme_stylebox_override("panel", surface)
		var stitches := SHELL.ButtonStitches.new()
		stitches.name = "RailStitches"
		stitches.focus_mode = Control.FOCUS_NONE
		add_child(stitches)
		_view = weakref(view)
		view.item_rect_changed.connect(_sync_rect)
		view.visibility_changed.connect(_sync_rect)
		_sync_rect()

	func _sync_rect() -> void:
		var view := _view.get_ref() as Control
		visible = is_instance_valid(view) and view.is_visible_in_tree()
		if not visible:
			return
		var rect := view.get_global_rect().grow(PADDING)
		global_position = rect.position
		size = rect.size

const TITLE := "Patchwork Pioneers"
const STARTER_DECK_PATH := "res://data/cards/starter_deck.json"
const STARTER_PARTY_PATH := "res://data/heroes/starter_party.json"
const STARTER_ATTACKS_PATH := "res://data/encounters/starter_attacks.json"
const STARTER_ENEMIES_PATH := "res://data/enemies/starter_enemies.json"
const RUN_ENEMIES_PATH := "res://data/enemies/run_enemies.json"
const FIGHT_ROSTERS := {
	"starter_attacks": ["ragling", "ragling_guard"],
	"guard_counterattack": ["button_guard", "fray_scavenger"],
	"ragling_rearline_feint": ["spool_stalker", "seam_ripper"],
}
const FIGHT_ENCOUNTER_PATHS := {
	"starter_attacks": STARTER_ATTACKS_PATH,
	"guard_counterattack": "res://data/encounters/guard_counterattack.json",
	"ragling_rearline_feint": "res://data/encounters/ragling_rearline_feint.json",
}
## One stage height shared with the roster presenter, so both lineups stay the same size.
const STAGE_ROSTER := preload("res://scripts/live_enemy_roster.gd")
const STAGE_ACTOR_HEIGHT := STAGE_ROSTER.STAGE_ACTOR_HEIGHT
## Compact secondary actions: End Turn stays the prominent 240x48 control, while
## Return and the juice-owned Fast toggle share one small sewn corner beside it.
const SECONDARY_ACTION_SIZE := Vector2(128, 40)
## Seam above the battle stage: the sewn intent patches sit at the top of the stage, so a
## small viewport gutter keeps them clear of the screen edge instead of flush against it.
## The expanding stage gives up exactly this height, so the hand and actions keep their
## rows inside 1280x720.
const BATTLE_TOP_SEAM := 16
## One held-card height shared by the hand row and every card panel. 120 px clipped the
## second sewn half of a stitched face; 160 px leaves both halves the noncompact
## three-line geometry (name, owner/source, target + rules) that
## live_hand_card_metadata.card_layout draws, and still fits the 1280x720 rows.
const HAND_CARD_HEIGHT := 160
## One transient, pointer-inert forecast strip for the eight detached combo
## attacks. It is mounted hidden per battle, so the idle lower third keeps the
## exact height it had before this cue existed.
const COMBO_FORECAST_NAME := "ComboForecastCue"
## The pinned Quilt village base between the title and an opening route.
const BASE_SCREEN_SCENE := "res://scenes/base_screen.tscn"
## Opening chooser: one readable label per authored node kind, so the raw node ID stays
## in metadata only. Unknown kinds keep their authored name instead of hiding the stop.
const ROUTE_KIND_LABELS := {
	"SewingCircle": "Sewing Circle",
	"Campfire": "Campfire",
	"PatchStall": "Patch Stall",
	"Unpicker": "Unpicker",
	"Fight": "Fight",
	"Elite": "Elite fight",
	"Rest": "Rest stop",
	"Shop": "Shop",
	"Event": "Event",
	"Treasure": "Treasure",
	"Boss": "Boss fight",
}
## Felt patch and thread colours of each kind's sewn route token, reused by the drawn
## no-art fallback (Treasure owns no committed token image yet).
const ROUTE_KIND_FELT := {
	"Peddler": Color("#7d7150"),
	"SewingCircle": Color("#795e78"),
	"Campfire": Color("#965a39"),
	"PatchStall": Color("#546b5f"),
	"Unpicker": Color("#665784"),
	"Fight": Color("#8a5a4a"),
	"Elite": Color("#9a6248"),
	"Rest": Color("#6d7f63"),
	"Shop": Color("#7d7150"),
	"Event": Color("#6c6478"),
	"Treasure": Color("#9a7c3f"),
	"Boss": Color("#8a4a4a"),
}
const ROUTE_KIND_THREAD := {
	"Peddler": Color("#e4d59a"),
	"SewingCircle": Color("#ead0e7"),
	"Campfire": Color("#f1c38f"),
	"PatchStall": Color("#dbe6c2"),
	"Unpicker": Color("#e1d5fa"),
	"Fight": Color("#e8c9a0"),
	"Elite": Color("#f0d2a0"),
	"Rest": Color("#c6dcc0"),
	"Shop": Color("#e4d59a"),
	"Event": Color("#cfc2e2"),
	"Treasure": Color("#f2dd9a"),
	"Boss": Color("#e8b2ae"),
}
## Book page colours: cream pages, stitched spine and a ribbon bookmark, cut paper style.
const ROUTE_BOOK_PAPER := Color("#ecdfbd")
const ROUTE_BOOK_SHADE := Color("#d8c9a2")
const ROUTE_BOOK_INK := Color("#302b29")
const ROUTE_BOOK_THREAD := Color("#c9b996")
const ROUTE_BOOK_FELT := Color("#4f5a47")
## The authored first area of a run, named on the opening book's left page beside its
## sewn Floor 01 tab. Presentation only: the authored table stays in RunRouteAtlas.
const ROUTE_BOOK_AREA := "Meadow"
## First-floor patch column of the opening book, in coordinates local to the right
## page's RouteBook.choices_rect(): one sewn patch Button per authored node slot, with
## an inert stitched start seam in the free lane on their left.
const ROUTE_PATCH_SIZE := Vector2(288.0, 70.0)
const ROUTE_PATCH_LEFT := 132.0
const ROUTE_PATCH_TOP := 74.0
const ROUTE_PATCH_STEP := 86.0
## Full map and Back sit at the foot of the right page, under every patch row.
const ROUTE_ACTION_HEIGHT := 44.0
const ROUTE_ACTION_TOP := 414.0
const ROUTE_ACTION_GAP := 12.0
## The start seam's x inside the patch column's free lane, and its darker thread, so
## uncommitted branches read on the cream page like the book's own spine stitching.
const ROUTE_SEAM_X := 48.0
const ROUTE_SEAM_THREAD := Color("#7d6a4d")


## The readable stop label for an authored node kind; the only name the player sees.
static func route_kind_label(kind: String) -> String:
	return str(ROUTE_KIND_LABELS.get(kind, kind))


## The page-local top of the patch sewn for one authored node position. Deterministic
## layout only: it reads no map, RNG or combat state.
static func route_patch_top(position: int) -> float:
	return ROUTE_PATCH_TOP + float(maxi(position, 0)) * ROUTE_PATCH_STEP


## Inert sewn route token for one opening choice. The authored kind art is drawn when it
## loads; a kind without art (Treasure) or an unreadable token keeps a drawn felt patch, so
## no PNG is required. Never takes pointer input or keyboard focus: the Button owns the action.
class RouteToken extends Control:
	var token_kind := ""
	var token_texture: Texture2D = null
	var art_path := ""
	var patch_colour := Color("#6c6478")
	var thread_colour := ROUTE_BOOK_THREAD

	func _init() -> void:
		name = "Token"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	## True when the drawn felt fallback replaces the committed art.
	func uses_drawn_fallback() -> bool:
		return token_texture == null

	## Only native stops reuse atlas pictograms; other tokens keep their cross stitch.
	func fallback_plan() -> Dictionary:
		if uses_drawn_fallback() and token_kind in ["Campfire", "SewingCircle", "Unpicker", "PatchStall"]:
			return RunRouteAtlas.NodeToken.fallback_plan(token_kind)
		return {}

	## Aspect-preserved destination of the token inside the button's left column.
	func token_rect() -> Rect2:
		if size.x <= 0.0 or size.y <= 0.0:
			return Rect2()
		var box := minf(size.y - 14.0, 46.0)
		if box <= 0.0:
			return Rect2()
		if token_texture != null and token_texture.get_width() > 0 and token_texture.get_height() > 0:
			var pixels := Vector2(token_texture.get_width(), token_texture.get_height())
			var fit := minf(box / pixels.x, box / pixels.y)
			var drawn := pixels * fit
			return Rect2(Vector2(7.0, (size.y - drawn.y) * 0.5), drawn)
		return Rect2(Vector2(7.0, (size.y - box) * 0.5), Vector2(box, box))

	func _draw() -> void:
		var rect := token_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return
		if not uses_drawn_fallback():
			draw_texture_rect(token_texture, rect, false)
			return
		# Drawn no-art fallback: keep the fabric border around the shared sewn pictogram.
		draw_rect(rect, patch_colour)
		draw_rect(rect, thread_colour, false, 2.0)
		var plan := fallback_plan()
		if not plan.is_empty():
			RunRouteAtlas.NodeToken.draw_emblem(self, str(plan["emblem"]), rect.grow(-2.0),
				thread_colour, RunRouteAtlas.INK, patch_colour.lightened(0.5))
			return
		draw_line(rect.position + Vector2(10.0, 10.0), rect.end - Vector2(10.0, 10.0),
			thread_colour, 2.0, true)
		draw_line(Vector2(rect.position.x + 10.0, rect.end.y - 10.0),
			Vector2(rect.end.x - 10.0, rect.position.y + 10.0), thread_colour, 2.0, true)


## Dashed running stitch sewn inside one opening patch Button. It draws thread lines
## near the felt's edge only: the opaque felt and every hover/pressed/disabled surface
## stay the Button's own styleboxes, so no child paints over the state or its caption.
class RoutePatchStitch extends Control:
	var thread_colour := ROUTE_BOOK_THREAD

	func _init() -> void:
		name = "Stitch"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 28.0 or size.y <= 20.0:
			return
		var frame := Rect2(Vector2(6.0, 5.0), size - Vector2(12.0, 10.0))
		var corners := [frame.position, Vector2(frame.end.x, frame.position.y), frame.end,
			Vector2(frame.position.x, frame.end.y)]
		for index in range(corners.size()):
			draw_dashed_line(corners[index], corners[(index + 1) % corners.size()],
				thread_colour, 1.0, 6.0)
		for corner: Vector2 in corners:
			draw_line(corner + Vector2(-3, -3), corner + Vector2(3, 3), thread_colour, 1.0, true)
			draw_line(corner + Vector2(3, -3), corner + Vector2(-3, 3), thread_colour, 1.0, true)


## Pointer-inert stitched start seam behind the opening patches: one running stitch down
## the page's free left lane and one dashed branch to each mounted patch's left edge. It
## never invents a map node or a pin, so an uncommitted opening shows no committed stop.
## It only reads the target rects it was handed; drawing never touches RunMap or the RNG.
class RouteBranches extends Control:
	var branch_targets: Array[Rect2] = []
	var seam_x := ROUTE_SEAM_X
	var thread_colour := ROUTE_SEAM_THREAD

	func _init() -> void:
		name = "Branches"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if branch_targets.is_empty() or size.x <= seam_x:
			return
		var top := branch_targets[0].get_center().y
		var bottom := top
		for target in branch_targets:
			top = minf(top, target.get_center().y)
			bottom = maxf(bottom, target.get_center().y)
		# The seam is a folded page edge, not a node: a capped running stitch.
		draw_dashed_line(Vector2(seam_x, top - 26.0), Vector2(seam_x, bottom + 26.0),
			thread_colour, 2.0, 9.0)
		for cap_y in [top - 26.0, bottom + 26.0]:
			draw_line(Vector2(seam_x - 8.0, cap_y), Vector2(seam_x + 8.0, cap_y),
				thread_colour, 1.6, true)
		for target in branch_targets:
			var from := Vector2(seam_x, target.get_center().y)
			var to := Vector2(target.position.x - 6.0, from.y)
			draw_dashed_line(from, to, thread_colour, 1.8, 7.0)
			# A sewn knot at the seam and a small thread arrow into the patch.
			draw_line(from + Vector2(-4, -4), from + Vector2(4, 4), thread_colour, 1.4, true)
			draw_line(from + Vector2(4, -4), from + Vector2(-4, 4), thread_colour, 1.4, true)
			draw_line(to + Vector2(-7, -4), to, thread_colour, 1.4, true)
			draw_line(to + Vector2(-7, 4), to, thread_colour, 1.4, true)


## Pointer-inert open book mounted behind the opening chooser: two cream pages, a stitched
## spine, a ribbon bookmark, a page curl and a first-floor tab that names the current floor
## without inventing a committed node. The owner board image (RunRouteAtlas.MAP_BOARD_PATH)
## replaces the drawn pages when it loads; a missing image keeps the complete drawn book, so
## no PNG is required. Presentation only: it never draws randomness or touches RunMap.
class RouteBook extends Control:
	const BOOK := Rect2(18, 14, 1244, 692)
	const LEFT_PAGE := Rect2(152, 56, 470, 588)
	const RIGHT_PAGE := Rect2(650, 56, 460, 588)
	const SPINE := Rect2(626, 50, 18, 600)
	const CURL := 64.0
	const STITCH_INSET := 12.0
	const BOOKMARK := Rect2(618, 22, 34, 122)
	const BOOKMARK_FILL := Color("#a2544a")
	const AREA_TAB := Rect2(206, 62, 210, 48)
	const FLOOR_TAB := Rect2(206, 118, 210, 66)
	const FLOOR_HINT := Rect2(206, 192, 210, 80)
	const FELT_TAB := Color("#8f7a55")
	const HERO_IDLE_PATHS := {
		"warden": "res://assets/paper/heroes/warden.png",
		"seamstress": "res://assets/paper/heroes/seamstress.png",
		"tinker": "res://assets/paper/heroes/tinker.png",
		"lantern_monk": "res://assets/paper/heroes/lantern_monk.png",
		"rag_duelist": "res://assets/paper/heroes/rag_duelist.png",
		"scarecrow": "res://assets/paper/heroes/scarecrow.png",
		"yarn_ranger": "res://assets/paper/heroes/yarn_ranger.png",
		"button_golem": "res://assets/paper/heroes/button_golem.png",
	}

	var board_texture: Texture2D = null

	func _init() -> void:
		name = "RouteBook"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)
		var area := _inert_label("AreaCue", ROUTE_BOOK_AREA, 26)
		area.position = AREA_TAB.position
		area.size = AREA_TAB.size
		area.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		area.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		area.add_theme_color_override("font_color", ROUTE_BOOK_PAPER)
		area.add_theme_constant_override("outline_size", 4)
		area.add_theme_color_override("font_outline_color", ROUTE_BOOK_INK)
		area.set_meta("area_name", ROUTE_BOOK_AREA)
		add_child(area)
		var cue := _inert_label("FloorCue", "Floor 01", 26)
		cue.position = FLOOR_TAB.position
		cue.size = FLOOR_TAB.size
		cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cue.add_theme_color_override("font_color", ROUTE_BOOK_PAPER)
		cue.add_theme_constant_override("outline_size", 4)
		cue.add_theme_color_override("font_outline_color", ROUTE_BOOK_INK)
		cue.set_meta("floor_number", 1)
		add_child(cue)
		var hint := _inert_label("FloorHint", "Journey unavailable", 18)
		hint.position = FLOOR_HINT.position
		hint.size = FLOOR_HINT.size
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", Color("fff3d6"))
		var backing := StyleBoxFlat.new()
		backing.bg_color = Color("42392f")
		backing.set_corner_radius_all(6)
		backing.content_margin_left = 8
		backing.content_margin_right = 8
		hint.add_theme_stylebox_override("normal", backing)
		add_child(hint)
		var stitch := ActionCornerStitch.new()
		stitch.name = "JourneyStitch"
		stitch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hint.add_child(stitch)

	## Detached presentation values only; no map, services or callbacks enter the cue.
	func show_journey(projection: Dictionary) -> void:
		var values := projection.duplicate(true)
		var hint: Label = get_node("FloorHint")
		hint.text = "Journey unavailable"
		if values.is_empty():
			return
		var lines: Array[String] = []
		for stop in values.stops:
			lines.append("%02d · %s" % [stop.floor, stop.kind])
		if lines.is_empty():
			lines.append("Trailhead")
		lines.append("Journey complete" if values.complete else
			"Next: %s · %02d" % [values.next_area, values.next_floor])
		hint.text = "\n".join(lines)

	## Only detached run values enter this view; it has no combat/service references.
	func show_party(snapshot: Dictionary) -> void:
		var values := snapshot.duplicate(true)
		var slate := Control.new()
		slate.name = "PartySlate"
		slate.position = Vector2(190, 276)
		slate.size = Vector2(388, 338)
		slate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slate.focus_mode = Control.FOCUS_NONE
		add_child(slate)
		for index in range(values.heroes.size()):
			var hero: Dictionary = values.heroes[index]
			var row := Control.new()
			row.name = "HeroRow" + str(index)
			row.position = Vector2(0, index * 86)
			row.size = Vector2(slate.size.x, 78)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.focus_mode = Control.FOCUS_NONE
			slate.add_child(row)
			# A sewn paper card lifts each hero off the page drawings behind it.
			var card := Panel.new()
			card.name = "RowCard"
			card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.focus_mode = Control.FOCUS_NONE
			var paper := StyleBoxFlat.new()
			paper.bg_color = Color(0.953, 0.906, 0.784, 0.95)
			paper.border_color = Color("a8997b")
			paper.set_border_width_all(2)
			paper.set_corner_radius_all(6)
			paper.shadow_color = Color(0.11, 0.1, 0.09, 0.35)
			paper.shadow_size = 4
			paper.shadow_offset = Vector2(3, 4)
			card.add_theme_stylebox_override("panel", paper)
			row.add_child(card)
			var stitch := ActionCornerStitch.new()
			stitch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			row.add_child(stitch)
			var portrait := TextureRect.new()
			portrait.name = "Portrait"
			portrait.position = Vector2(10, 6)
			portrait.size = Vector2(64, 66)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.focus_mode = Control.FOCUS_NONE
			var path: String = HERO_IDLE_PATHS.get(hero.id, "")
			if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
				# Head-and-shoulders crop so the doll reads at row size instead of a shrunken full body.
				var full := load(path) as Texture2D
				var side := minf(full.get_width(), full.get_height() * 0.62)
				var bust := AtlasTexture.new()
				bust.atlas = full
				bust.region = Rect2((full.get_width() - side) / 2.0, 4.0, side, side)
				portrait.texture = bust
			row.add_child(portrait)
			if portrait.texture == null:
				var fallback := _inert_label("PortraitFallback", "?", 26)
				fallback.position = portrait.position
				fallback.size = portrait.size
				fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				row.add_child(fallback)
			var caption := _inert_label("HeroName", String(hero.name), 22)
			caption.position = Vector2(86, 8)
			caption.size = Vector2(290, 28)
			row.add_child(caption)
			var health := _inert_label("Health", "HP %d / %d" % [hero.hp, hero.max_hp], 20)
			health.position = Vector2(86, 40)
			health.size = Vector2(290, 28)
			row.add_child(health)
		var resources := _inert_label("Resources", "Deck: %d cards\nGold: %d\nScraps: %d" % [
			values.deck_count, values.gold, values.scraps], 18)
		# Upper-right supply tab on the left page, clear of the board's lower cloth hem.
		# Keep the label under PartySlate so both mounted book paths retain their lookup.
		resources.position = Vector2(244, -206)
		resources.size = Vector2(172, 128)
		resources.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		resources.add_theme_color_override("font_color", Color("fff3d6"))
		var backing := StyleBoxFlat.new()
		backing.bg_color = Color("42392f")
		backing.border_color = Color("c9b996")
		backing.set_border_width_all(1)
		backing.set_corner_radius_all(6)
		backing.content_margin_left = 14
		backing.content_margin_right = 14
		backing.content_margin_top = 12
		backing.content_margin_bottom = 12
		resources.add_theme_stylebox_override("normal", backing)
		slate.add_child(resources)
		var supply_stitch := ActionCornerStitch.new()
		supply_stitch.name = "SupplyStitch"
		supply_stitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		supply_stitch.focus_mode = Control.FOCUS_NONE
		supply_stitch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resources.add_child(supply_stitch)

	func _inert_label(node_name: String, text: String, font_size: int) -> Label:
		var label := Label.new()
		label.name = node_name
		label.text = text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.focus_mode = Control.FOCUS_NONE
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", ROUTE_BOOK_INK)
		return label

	## The page rect that holds the choice column; drawn and owner art share this layout.
	static func choices_rect() -> Rect2:
		return RIGHT_PAGE.grow(-14.0)

	func uses_board_texture() -> bool:
		return board_texture != null

	## Deterministic page geometry, for mounted layout assertions.
	func page_geometry() -> Dictionary:
		return {"book": BOOK, "left_page": LEFT_PAGE, "right_page": RIGHT_PAGE,
			"spine": SPINE, "bookmark": BOOKMARK, "area_tab": AREA_TAB,
			"floor_tab": FLOOR_TAB, "choices": choices_rect()}

	func _draw() -> void:
		if board_texture != null:
			# The owner board carries pages, spine, ribbon and bookmark in one image.
			draw_texture_rect(board_texture, Rect2(Vector2.ZERO, size), false)
		else:
			_draw_drawn_book()
		# The area and first-floor tabs sit on either page pair, so they always read as
		# sewn patches naming where the uncommitted opening begins.
		draw_rect(AREA_TAB, FELT_TAB)
		_stitch_frame(AREA_TAB.grow(-4.0))
		draw_rect(FLOOR_TAB, FELT_TAB)
		_stitch_frame(FLOOR_TAB.grow(-4.0))

	## Complete drawn fallback book: no PNG is required to open this chooser.
	func _draw_drawn_book() -> void:
		draw_rect(BOOK, Color("#241f1a"))
		draw_rect(BOOK.grow(-4.0), ROUTE_BOOK_SHADE)
		draw_rect(LEFT_PAGE, ROUTE_BOOK_PAPER)
		draw_rect(RIGHT_PAGE, ROUTE_BOOK_PAPER)
		draw_rect(SPINE, Color("#b7a276"))
		var stitch_y := int(SPINE.position.y) + 16
		while stitch_y < int(SPINE.end.y) - 8:
			draw_line(Vector2(SPINE.position.x + 4.0, float(stitch_y)),
				Vector2(SPINE.end.x - 4.0, float(stitch_y)), ROUTE_BOOK_THREAD, 1.0, true)
			stitch_y += 26
		_stitch_frame(LEFT_PAGE.grow(-STITCH_INSET))
		_stitch_frame(RIGHT_PAGE.grow(-STITCH_INSET))
		var curl := Rect2(RIGHT_PAGE.end - Vector2(CURL, CURL), Vector2(CURL, CURL))
		draw_colored_polygon(PackedVector2Array([
			Vector2(curl.end.x - CURL, curl.end.y),
			curl.end,
			curl.end - Vector2(CURL * 0.55, CURL * 0.55),
		]), ROUTE_BOOK_SHADE)
		draw_dashed_line(Vector2(curl.end.x - CURL, curl.end.y), curl.end,
			ROUTE_BOOK_THREAD, 1.2, 6.0)
		draw_colored_polygon(PackedVector2Array([
			BOOKMARK.position,
			Vector2(BOOKMARK.end.x, BOOKMARK.position.y),
			BOOKMARK.end,
			Vector2(BOOKMARK.position.x + BOOKMARK.size.x * 0.5, BOOKMARK.end.y - 12.0),
			Vector2(BOOKMARK.position.x, BOOKMARK.end.y),
		]), BOOKMARK_FILL)
		# A running stitch points from the floor tab to the first choices on the right page.
		draw_dashed_line(Vector2(FLOOR_TAB.end.x + 10.0, FLOOR_TAB.get_center().y),
			Vector2(RIGHT_PAGE.position.x + 22.0, FLOOR_TAB.get_center().y),
			ROUTE_BOOK_THREAD, 2.0, 10.0)

	func _stitch_frame(rect: Rect2) -> void:
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]
		for index in range(corners.size()):
			var from: Vector2 = corners[index]
			var to: Vector2 = corners[(index + 1) % corners.size()]
			draw_dashed_line(from, to, ROUTE_BOOK_THREAD, 1.4, 7.0)
		for corner: Vector2 in corners:
			draw_line(corner + Vector2(-4, -4), corner + Vector2(4, 4), ROUTE_BOOK_THREAD, 1.2, true)
			draw_line(corner + Vector2(4, -4), corner + Vector2(-4, 4), ROUTE_BOOK_THREAD, 1.2, true)


## One small sewn felt corner beside the prominent End Turn control.
class ActionCorner extends PanelContainer:
	func _ready() -> void:
		var felt := StyleBoxFlat.new()
		felt.bg_color = Color("42392f")
		felt.border_color = Color("c9b996")
		felt.set_border_width_all(1)
		felt.set_corner_radius_all(8)
		felt.content_margin_left = 10
		felt.content_margin_right = 10
		felt.content_margin_top = 6
		felt.content_margin_bottom = 6
		add_theme_stylebox_override("panel", felt)


## Dashed thread stitching and cross-stitches; never takes pointer or focus.
class ActionCornerStitch extends Control:
	const THREAD := Color("c9b996")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if size.x <= 12.0 or size.y <= 12.0:
			return
		var inset := Rect2(Vector2(4.5, 4.5), size - Vector2(9.0, 9.0))
		var corners := [inset.position, Vector2(inset.end.x, inset.position.y), inset.end,
			Vector2(inset.position.x, inset.end.y)]
		for index in range(corners.size()):
			draw_dashed_line(corners[index], corners[(index + 1) % corners.size()], THREAD, 1.0, 5.0)
		for corner: Vector2 in corners:
			draw_line(corner + Vector2(-3, -3), corner + Vector2(3, 3), THREAD, 1.0, true)
			draw_line(corner + Vector2(3, -3), corner + Vector2(-3, 3), THREAD, 1.0, true)


@export var run_seed: int = 42
@export_file("*.json") var starter_deck_path: String = STARTER_DECK_PATH
@export_file("*.json") var starter_party_path: String = STARTER_PARTY_PATH
@export_file("*.json") var starter_attacks_path: String = STARTER_ATTACKS_PATH
@export_file("*.json") var starter_enemies_path: String = STARTER_ENEMIES_PATH

var title_label: Label
var start_button: Button
var route_button: Button
var base_button: Button
var stitched_fight_button: Button
var stitched_fight_view: StitchedBattleScreen
var stitched_event_panel: LiveEventChoicePanel
var stitched_event_gate: RunV3FightEventGate
var stitched_sewing_panel: Control
var stitched_sewing_visit: RunStitchedSewingSwap
var stitched_sewing_mend_visit: RunStitchedSewingMend
var stitched_sewing_upgrade_visit: RunStitchedSewingUpgrade
var stitched_preview_satchel: Array = []
var stitched_preview_scraps := 0
## Separate from S2's 78-candle standalone preview; lasts for this title session.
var stitched_roadblock_candle := 100
var _stitched_admitted_fight_gate: RunV3FightEventGate
var _stitched_gear_overrides: Dictionary = {}
var _stitched_hp_carry: Dictionary = {}
var _stitched_sewing_quote: Dictionary = {}
var _stitched_mend_quote: Dictionary = {}
var _stitched_upgrade_quote: Dictionary = {}
var _stitched_sewing_catalog: Dictionary = {}
var _stitched_battle_ticket: WeakRef
## The one-use S6 Peddler bandage service, earned by a genuine four-survivor
## Roadblock victory followed by an authenticated Sewing Circle Leave. It has
## its own preview gold, never the legacy run wallet, cards or run RNG.
var stitched_preview_gold := 0
var _stitched_bleed_carry: Dictionary = {}
var stitched_peddler_button: Button
var stitched_peddler_panel: Control
var stitched_peddler_visit: RunStitchedPeddlerBandage
var stitched_peddler_candle_visit: RunPeddlerVisit
var stitched_peddler_part_visit: RunStitchedPeddlerPart
var _stitched_peddler_quote: Dictionary = {}
var _stitched_peddler_candle_state: Dictionary = {}
var _stitched_peddler_candle_quote: Dictionary = {}
var _stitched_peddler_part_state: Dictionary = {}
var _stitched_peddler_part_quote: Dictionary = {}
var _stitched_peddler_generation := 0
var _stitched_peddler_roster: Array = []
## This separate four-hero health authority is earned by the same terminal
## Roadblock + Circle Leave and competes for ONE postvictory stop.
var stitched_campfire_button: Button
var stitched_campfire_panel: Control
var stitched_campfire_visit: RunCampfireVisit
var _stitched_campfire_state: Dictionary = {}
var _stitched_campfire_roster: Array = []
var _stitched_campfire_authorized_roster: Array = []
var _stitched_campfire_generation := 0
# Separate, one-exchange Campfire authority; never shares the recovery visit.
var _stitched_campfire_swap_roster: Array = []
var _stitched_campfire_swap_satchel: Array = []
var _stitched_campfire_swap_gear: Dictionary = {}
var _stitched_campfire_swap_visit: RunStitchedSewingSwap
var _stitched_campfire_swap_state: Dictionary = {}
var _stitched_postvictory_stop_available := false
## This is a detached, authenticated party receipt, not an editable UI request.
const STITCHED_DEFAULT_PICKS := ["warden", "seamstress", "tinker", "lantern_monk"]
var _stitched_party_picks: Array = STITCHED_DEFAULT_PICKS.duplicate()
var _stitched_party_receipt: Dictionary = StitchedPartyAdmission.admit(STITCHED_DEFAULT_PICKS)
var _stitched_party_draft: Array = []
var _stitched_party_checkboxes: Dictionary = {}
var _stitched_party_hint: Label
var _stitched_party_confirm_button: Button
var _stitched_party_cancel_button: Button
const STITCHED_ROADBLOCK_ID := "v3_stitchline_roadblock"
const STITCHED_SEWING_NODE_ID := "s5_scissor_crab_sewing_circle"
const STITCHED_SEWING_MEND_COST := 2
const STITCHED_SEWING_UPGRADE_COST := 2
const STITCHED_ROADBLOCK_CANDLE_COST := 8
const STITCHED_PEDDLER_NODE_ID := "s6_stitched_roadblock_peddler"
const STITCHED_CAMPFIRE_NODE_ID := "s6_stitched_roadblock_campfire"
const STITCHED_PEDDLER_PRICE := 10
const STITCHED_PEDDLER_PART_ID := "warden_head_helmet_rattle"
const STITCHED_PREVIEW_WIN_GOLD := 10
const STITCHED_CLAW_ID := "scissor_crab_claw_arm"
const STITCHED_SACK_ID := "fray_scavenger_sack_arm"
const STITCHED_INKBRUSH_ID := "moth_scribe_inkbrush_arm"
## The title Roadblock's authored trophy order. Each foe is only paid when this exact
## encounter actually killed it; the ids and parts come from the canonical S5 roster.
const STITCHED_ROADBLOCK_FOES := ["scissor_crab", "fray_scavenger", "moth_scribe"]
const STITCHED_TITLE_WALLET := {"gold": 0, "scraps": 0}
var base_screen: BaseScreen
## True only while an uncommitted opening chooser was launched from the Base.
var _route_from_base := false
## The Quilt village's one Path setup; null until a village opens or once cleared.
var run_seamstress_path_choice: RunSeamstressPathChoice
## Detached receipt of the Path this run carries; empty until a successful Set out.
var run_seamstress_path_receipt: Dictionary = {}
## The village's independent Tinker Path setup. Its claimed instance is kept for
## the whole run, because only it can authenticate the battle's Path authority.
var run_tinker_path_choice: RunTinkerPathChoice
## Detached receipt of the Tinker Path this run carries; empty until Set out.
var run_tinker_path_receipt: Dictionary = {}
var run_warden_path_choice: RunWardenPathChoice
var run_warden_path_receipt: Dictionary = {}
## The one validated Tinker setup receipt this village visit produced, detached
## from the setup. Empty until a Tinker option is confirmed.
var _tinker_setup_receipt: Dictionary = {}
## Opening chooser: a plain Control so each first-floor patch Button keeps its own
## authored page slot; a connected route still fills it with a VBoxContainer.
var route_view: Control
var route_back_button: Button
var route_map_button: Button
var route_atlas_overlay: Control
var route_atlas: RunRouteAtlas
var route_atlas_close: Button
## The route chooser's pointer-inert page backdrop.
var route_book_backdrop: Control
## The mounted noncombat visit's pointer-inert art bed; null outside a Rest/Shop visit.
var visit_backdrop: Control
## Key: visit art path, value: Texture2D or null. A missing file is cached too, so a
## visit never probes the same absent image twice.
var _visit_backdrops: Dictionary = {}
var route_buttons: Array[Button] = []
## Key: token art path, value: Texture2D or null. A negative entry is cached too, so a
## missing token is never probed twice and its drawn fallback stays authoritative.
var _route_tokens: Dictionary = {}
var map_mend_buttons: Array[Button] = []
var _map_mend_serial := 0
var _mended_route_context: Array = []
var run_map: RunMap
var fight_encounter_paths: Dictionary = FIGHT_ENCOUNTER_PATHS.duplicate()
var fight_rosters: Dictionary = FIGHT_ROSTERS.duplicate(true)
var run_enemies_path: String = RUN_ENEMIES_PATH
var fight_selection: RunFightEncounterSelection
var encounter_id := ""
var title_view: VBoxContainer
var battle_view: MarginContainer
var hand_view: HBoxContainer
var pile_label: Label
var end_turn_button: Button
var return_button: Button
var deck: CombatDeck
var run_rng: RandomNumberGenerator
var party: CombatParty
var enemies: CombatEnemies
var hero_view: HBoxContainer
var hero_panels: Array[PanelContainer] = []
var enemy_attacks: Array = []
var enemy_intents: CombatEnemyIntents
var intent_label: Label
var enemy_buff_forecast_label: Label
var battle_result: CombatBattleResult
var act_outcome: RunActBattleOutcome
var round_flow: CombatRoundFlow
var victory_gold: RunVictoryGold
## The app is the live caller for the detached combo-attack oracle. Selection is
## the mounted hand's own hover / P behaviour; Pinned, Unravel and the Tinker
## first-attack latch stay the battle-scoped instances owned by LiveAttackPreview.
var combo_cue: Label
var _combo_selected: Control
var _combo_keyboard := false
var _combo_bindings: Dictionary = {}
var _combo_targeting := CombatAttackTargeting.new()
var _combo_preview := CombatPoolComboAttackPreview.new()
# Battle-local receipt bridge for CombatQuiltBonus. It only reports committed
# hand-to-discard transactions of the mounted battle and resets on a new turn.
var _quilt_bonus: CombatQuiltBonus
var _quilt_deck: CombatDeck
var _quilt_party: CombatParty
var _quilt_turn_open := false
var _quilt_hand_snapshot: Array[String] = []
var _quilt_draw_snapshot: Array[String] = []
var _quilt_discard_snapshot: Array[String] = []
var _quilt_card_total := 0
## Last *mounted* physical card occurrences and the authoritative piles at that
## mount. A hand redraw cannot manufacture a draw or a paid discard receipt.
var _hand_motion_deck: CombatDeck
var _hand_motion_battle: Control
var _hand_motion_ids: Array[String] = []
var _hand_motion_draw: Array[String] = []
var _hand_motion_discard: Array[String] = []
var _hand_motion_turn := -1
# The actual mounted panel activated before a presenter commits a paid play.
# This is only a visual witness; CombatDeck and the quilt receipt remain authoritative.
var _hand_motion_source: Control
var _hand_motion_source_card := ""
var _hand_motion_source_hand: Array[String] = []
var hand_motion_history: Array[Dictionary] = []
var session_gold := 0
var run_deck: Array[String] = []
var run_scraps := 0
var run_stitch_descriptors: Dictionary = {}
var run_next_stitch_id := 1
var run_trinkets: Array[String] = []
var fight_reward_trinket := ""
var run_heroes: Array = []
var party_carryover: RunPartyCarryover
var _carryover_map: WeakRef
var _carryover_revision := 0
var _carryover_node := ""
var _carryover_route: Array[String] = []
var _carryover_floors: Array = []
var _carryover_party: CombatParty
var _carryover_result: CombatBattleResult
var continue_button: Button
var rest_view: VBoxContainer
var rest_patch_button: Button
var rest_patch_overlay: Control
var rest_patch_picker: LiveRestPatchResewPicker
var _rest_wardrobe: RunPatchWardrobe
var _rest_patch_context: Array = []
var _rest_patch_serial := 0
var rest_heal_button: Button
var rest_continue_button: Button
var rest_back_button: Button
var rest_hp_label: Label
var rest_recovery: RunRestRecovery
var rest_stitch: RunRestStitchCards
var rest_stitch_first: OptionButton
var rest_stitch_second: OptionButton
var rest_stitch_button: Button
var rest_stitch_guided_button: Button
var rest_stitch_overlay: Control
var rest_stitch_picker: LiveRestStitchPairPicker
var _rest_stitch_source: Dictionary = {}
var _rest_stitch_committed: Dictionary = {}
var rest_upgrade: RunRestCardUpgrade
var rest_upgrade_cards: OptionButton
var rest_upgrade_button: Button
var _rest_upgrade_choices: Array = []
var _rest_deck: Array[String] = []
var _rest_committed_deck: Array[String] = []
var _rest_floors: Array = []
var _rest_revision := 0
var _rest_inventory: Array = []
var _rest_ledger: Dictionary = {}
var _rest_carry: RunPartyCarryover
var _rest_rng: RandomNumberGenerator
var _rest_gold := 0
var _rest_rng_state := 0
var _rest_route: Array[String] = []
var _rest_heroes: Array = []
var _rest_committed_heroes: Array = []
var _rest_map: WeakRef
var shop_view: Control
var shop_cards: OptionButton
var shop_remove_button: Button
var shop_back_button: Button
var shop_continue_button: Button
var shop_label: Label
var shop_visit: RunShopVisit
var shop_purchases: RunShopPurchases
var shop_offers: OptionButton
var shop_buy_button: Button
var shop_patch_offers: OptionButton
var shop_patch_heroes: OptionButton
var shop_patch_buy_button: Button
var shop_patch_preview: Label
var _shop_wardrobe: RunPatchWardrobe
var _shop_patch_context: Array = []
var run_removal_count := 0
var _shop_map: WeakRef
var _shop_route: Array[String] = []
var _connected_map: WeakRef
var _connected_route: Array[String] = []
var _placeholder_map: WeakRef
var _placeholder_route: Array[String] = []
var event_catalog_path := "res://data/events/m04_events.json"
var roadside_event_catalog_path := "res://data/events/v3_roadside_events.json"
const REQUIRED_ROADSIDE_EVENT_IDS := ["v3_raincoat_bridge", "v3_puppet_box_office",
	"v3_mismatched_mittens", "v3_coil_and_crow", "v3_patchwork_lighthouse", "v3_button_orchard"]
var wallet_event_panel: LiveEventChoicePanel
var vital_event_catalog_path := RunV3VitalEventRotation.EVENTS_PATH
var _vital_event_history: Array = []
var _vital_event_gate: RunV3HeroVitalEventGate
var _wallet_event_record: Dictionary = {}
var _wallet_event_context: Array = []
var _wallet_event_history: Array = []
# Only a claimed service gate may turn an Event into an on-node service visit.
var _emberglass_gate: RunV3ServiceWaystationEventGate
var _emberglass_campfire_auth: Array = []
var _inkblack_unpicker_auth: Array = []
var _threadmill_sewing_auth: Array = []
var quiet_spool_panel: LiveEventChoicePanel
var _quiet_spool_outcome: RunQuietSpoolOutcome
var _quiet_spool_context: Array = []
var _quiet_spool_completed := false
var moth_catalog_path := "res://data/events/moth_infestation.json"
var moth_panel: LiveEventChoicePanel
var _moth_outcome: RunMothInfestationOutcome
var _moth_context: Array = []
var _moth_completed := false
var _moth_picker: ItemList
var dye_vat_catalog_path := "res://data/events/dye_vat.json"
var dye_vat_panel: LiveEventChoicePanel
var _dye_vat_outcome: RunDyeVatOutcome
var _dye_vat_context: Array = []
var _dye_vat_completed := false
var _dye_vat_picker: ItemList
var _dye_vat_node := ""
var needle_toll_panel: LiveEventChoicePanel
var _needle_toll_outcome: RunNeedleToll
var _needle_toll_context: Array = []
var _needle_toll_completed := false
var _needle_toll_node := ""
var _needle_toll_rng_start: int = 0
var fate_pin_panel: LiveEventChoicePanel
var _fate_pin_outcome: RunFatePinAuction
var _fate_pin_wardrobe: RunPatchWardrobe
var _fate_pin_context: Array = []
var _fate_pin_seen := false
var frayed_debt_panel: LiveEventChoicePanel
var _frayed_debt_outcome: RunFrayedDebtParcel
var _frayed_debt_context: Array = []
var _frayed_debt_seen := false
var _frayed_debt_receipt: Dictionary = {}
var debt_booth_panel: LiveEventChoicePanel
var _debt_booth_service: RunV3DebtRedemptionEvent
var _debt_booth_context: Array = []
var _debt_booth_node := ""
var _debt_booth_seen := false
var _debt_booth_receipt: Dictionary = {}
var _fate_pin_receipt: Dictionary = {}
var card_reward: RunCardRewardChoice
var fight_rewards: RunFightVictoryRewards
var multi_fight_rewards: RunMultiFightRewards
var fight_reward_offers: Array = []
var fight_reward_gold := 0
var fight_reward_claimed := false
var _reward_map: WeakRef
var reward_buttons: Array[Button] = []
var reward_choice_panel: LiveRunCardRewardChoicePanel
var _reward_return_parent: WeakRef
const INTERIM_REWARD_IDS := ["warden_strike", "seamstress_prick", "tinker_pop_shot"]
var result_label: Label
var _battle_closed := false
# One confirmed paid-card hit may have left the authored Quilt Termite at zero
# HP. The genuine post-card observation boundary consumes this before evaluate().
var _termite_split_hit: Dictionary = {}
var terminal_result_panel: LiveRunTerminalResultPanel
var _terminal_return_connection: Callable
var action_corner: PanelContainer
var action_corner_row: HBoxContainer


func _ready() -> void:
	_build_title()
	_load_difficulty_progress.call_deferred()
	start_run_requested.connect(_start_run)
	var attack_preview := Node.new()
	attack_preview.name = "LiveAttackPreview"
	attack_preview.set_script(preload("res://scripts/live_attack_preview.gd"))
	add_child(attack_preview)
	var riposte_hand := preload("res://scripts/live_rag_duelist_riposte_hand.gd").new()
	riposte_hand.name = "LiveRagDuelistRiposteHand"
	add_child(riposte_hand)
	# One battle-independent listener presents committed HP/Block changes (VIS V5).
	var combat_juice := Node.new()
	combat_juice.name = "LiveCombatJuice"
	combat_juice.set_script(preload("res://scripts/live_combat_juice.gd"))
	add_child(combat_juice)


func _process(_delta: float) -> void:
	_observe_battle_result()
	if is_instance_valid(battle_view) and battle_view.is_visible_in_tree():
		_refresh_intents()
		_refresh_action_focus()
	_sync_combo_forecast()


## Keyboard companion to hand hover: P cycles the formed combo cards exactly as
## the live attack preview cycles attack cards, Esc retires the forecast. When
## another live selection owns P, this handler stays out of its way.
func _input(event: InputEvent) -> void:
	# Observe the genuine GUI destination without installing another card signal
	# listener: unwired cards must still have exactly ZERO input connections.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and _hand_motion_allowed():
		var hovered: Control = get_viewport().gui_get_hovered_control()
		var captured := false
		for panel in hand_view.get_children():
			if panel.gui_input.get_connections().is_empty():
				continue
			if (hovered == panel or (hovered != null and panel.is_ancestor_of(hovered))) \
					and panel.get_global_rect().has_point(event.position):
				_hand_motion_capture_input(event, panel, (panel.get_child(0) as Label).text)
				captured = true
				break
		if not captured:
			# P-selected targeted attacks may be confirmed by clicking an enemy,
			# not by clicking the card again; retain the physically armed panel.
			var preview = get_node_or_null("LiveAttackPreview")
			if preview != null and is_instance_valid(preview._armed) \
					and not preview._armed.gui_input.get_connections().is_empty():
				_hand_motion_capture_input(event, preview._armed, \
						(preview._armed.get_child(0) as Label).text)
	elif event is InputEventKey and event.pressed and not event.echo:
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused != null and focused.get_parent() == hand_view \
				and not focused.gui_input.get_connections().is_empty():
			_hand_motion_capture_input(event, focused, (focused.get_child(0) as Label).text)
		elif event.keycode in [KEY_1, KEY_2, KEY_3, KEY_ENTER, KEY_SPACE]:
			var preview = get_node_or_null("LiveAttackPreview")
			if preview != null and is_instance_valid(preview._armed) \
					and not preview._armed.gui_input.get_connections().is_empty():
				_hand_motion_capture_input(event, preview._armed, \
						(preview._armed.get_child(0) as Label).text)
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		# The optional atlas owns this key before the combat-only card forecast.
		if _handle_atlas_escape(event):
			return
		if _combo_selected != null:
			_combo_selected = null
			_combo_keyboard = false
			_sync_combo_forecast()
		return
	if event.keycode == KEY_P and not _combo_controls_owned_elsewhere():
		_combo_cycle()


## Detached terminal evidence, captured only at the pending-to-settled boundary.
var _terminal_combat_witness: Array = []


func _settle_act_battle() -> bool:
	if act_outcome == null or run_map == null or party == null or battle_result == null \
		or act_outcome._map != run_map or act_outcome._pending_result != battle_result \
		or battle_result._party != party:
		return false
	var witness := [act_outcome, run_map, battle_result, party,
		run_map.get_generation_revision(), run_map.get_route(), run_map.get_floors(),
		party.get_heroes()]
	if not act_outcome.settle_current_battle():
		return false
	witness.append(act_outcome.get_state())
	_terminal_combat_witness = witness
	return true


## Record one already-confirmed paid-card transition that left the authentic
## Quilt Termite at zero HP. Only a living-to-slain change caused by that card
## qualifies: direct model damage, enemy-phase Bleed and Thorns never call here.
func _note_card_damage(enemies_after: CombatEnemies, before: Array, confirmed_card: Dictionary = {}) -> bool:
	if enemies_after == null or enemies_after != enemies or _battle_closed \
			or battle_result == null or not battle_result.can_continue() \
			or enemy_intents == null or round_flow == null or deck == null or party == null:
		return false
	if not enemies.is_valid() or not party.is_valid():
		return false
	var after := enemies_after.get_enemies()
	if before.size() != after.size() or before.size() > CombatEnemies.MAX_ENEMIES:
		return false
	var source := 0
	for index in range(after.size()):
		var previous = before[index]
		var current: Dictionary = after[index]
		if not previous is Dictionary or current.get("position") != index + 1 \
				or previous.get("position") != index + 1 \
				or not previous.get("hp") is int or not current.get("hp") is int:
			return false
		if previous["hp"] > 0 and current["hp"] == 0 \
				and previous.get("id") == CombatEnemies.TERMITE_ID \
				and previous.get(CombatEnemies.SPLIT_FIELD) == true:
			if source != 0:
				return false
			source = index + 1
	# Run this battle's Tether receipt bridge even when no Termite was slain.
	# Neither a forecast nor an unconfirmed card may be passed as a hit.
	if confirmed_card.get("ok", false) and confirmed_card.get("hits") is Array:
		var preview := get_node_or_null("LiveAttackPreview")
		if preview != null and is_instance_valid(preview):
			preview.apply_tether_confirmed_hits(enemies_after, before, confirmed_card)
	if source == 0:
		return false
	_termite_split_hit = {"enemies": enemies_after, "position": source}
	return true


## The one genuine post-card boundary. A pending lethal hand hit is preflighted
## against a detached roster through the existing split primitive, then the
## scheduler and gauge ledgers must accept both children BEFORE any subsystem is
## published. Any stale, malformed or full-roster case leaves the normal death
## untouched and falls through to the ordinary victory/defeat evaluation.
func _settle_pending_termite_split() -> bool:
	if _termite_split_hit.is_empty():
		return true
	var receipt := _termite_split_hit
	_termite_split_hit = {}
	if _battle_closed or enemies == null or receipt.get("enemies") != enemies \
			or enemy_intents == null or round_flow == null or battle_result == null \
			or deck == null or party == null:
		return true
	var flow: CombatRoundFlow = round_flow
	if flow._deck != deck or flow._party != party or flow._enemies != enemies \
			or flow._intents != enemy_intents or flow._result != battle_result:
		return true
	var source: Variant = receipt.get("position")
	var roster := enemies.get_enemies()
	if not source is int or source < 1 or source > roster.size():
		return true
	var probe := CombatEnemies.new(roster, enemies.get_capacity())
	# The constructor normalizes HP to max_hp, so restore the exact live records
	# before the detached splitter sees the just-confirmed zero-HP source.
	probe._enemies.assign(roster.duplicate(true))
	var staged := probe.stage_split_on_death(source)
	if not staged.get("ok", false) or not staged.get("split", false):
		return true
	var after := probe.get_enemies()
	var unravel: CombatUnravel = flow._unravel
	if unravel != null and (not is_instance_valid(unravel) \
			or unravel._bound_enemies != enemies or not flow._valid_unravel_binding()):
		return true
	if not enemy_intents.can_admit_split(enemies, source, after):
		return true
	if unravel != null and not unravel.can_admit_split(enemies, source, after):
		return true
	# Every subsystem accepted the same deterministic transition above, so the
	# published roster is the exact proposal and both ledgers commit atomically.
	var published := enemies.stage_split_on_death(source)
	if not published.get("ok", false) or not published.get("split", false) \
			or published != staged or enemies.get_enemies() != after:
		return true
	if not enemy_intents.admit_split(enemies, source):
		return true
	if unravel != null and not unravel.admit_split(enemies, source):
		return true
	enemy_attacks = enemy_intents.get_intents()
	_refresh_intents()
	_refresh_enemy_roster()
	var meters := get_node_or_null("LiveCombatMeters")
	if meters != null and is_instance_valid(meters):
		meters._sync_battle()
	return true


## Single observation boundary for live updates and resolved phases.
func _observe_battle_result() -> bool:
	if battle_result == null:
		return false
	if party_carryover != null and not _current_carryover_fight():
		return false
	if run_map != null and not _current_act_battle():
		return false
	if not _settle_pending_termite_split():
		return false
	var outcome := battle_result.evaluate()
	if outcome == CombatBattleResult.ACTIVE:
		return true
	if not _battle_closed and outcome == CombatBattleResult.VICTORY and run_map != null and _carryover_route.size() == 1 and run_map.get_node(_carryover_node).get("type") == "Fight":
		if not _commit_fight_carryover():
			return false
	if not _battle_closed and act_outcome != null:
		if not _settle_act_battle():
			return false
	if is_instance_valid(enemy_buff_forecast_label):
		enemy_buff_forecast_label.text = ""
		enemy_buff_forecast_label.hide()
	if not _battle_closed:
		_battle_closed = true
		var hand_juice = get_node_or_null("LiveCombatJuice")
		if hand_juice != null:
			hand_juice.retire_hand_echoes()
		var tether_presenter := get_node_or_null("LiveAttackPreview")
		if tether_presenter != null:
			tether_presenter.retire_tether_battle()
		# A closed session keeps no pending Wind-up Turret for any later fight.
		if round_flow != null:
			round_flow.clear_turrets()
			round_flow.clear_taunt()
		if outcome == CombatBattleResult.VICTORY:
			if run_map == null:
				session_gold = victory_gold.claim_gold(false, run_rng)
		# Enemy phases have already ended the turn; external/card damage may not have.
		if deck.turn_active:
			deck.end_turn()
		$LiveSupportHand._cancel_pending()
		_refresh_hand()
		if outcome == CombatBattleResult.VICTORY and (run_map == null or run_map.get_node(_carryover_node).get("type") in ["Fight", "Elite"]):
			_build_card_reward()
		if party.is_valid():
			_refresh_party()
		_refresh_enemy_roster()
		end_turn_button.disabled = true
		result_label.text = "Battle result: " + outcome
		if act_outcome != null and outcome == CombatBattleResult.DEFEAT:
			result_label.text += " | Run defeat"
		if act_outcome != null and act_outcome.get_state().run_status == RunActBattleOutcome.VICTORY:
			result_label.text += " | Run victory"
		if outcome == CombatBattleResult.VICTORY and (run_map == null or run_map.get_node(_carryover_node).get("type") in ["Fight", "Elite"]):
			result_label.text += " | Pending gold: %d" % fight_reward_gold if run_map != null else " | Gold: %d" % session_gold
		if not fight_reward_trinket.is_empty():
			result_label.text += " | Trinket: " + fight_reward_trinket
		result_label.show()
		if _terminal_result_is_current():
			_mount_terminal_result()
		else:
			return_button.grab_focus()
	return false


## Present only the settled witness for this same mounted routed combat.
func _terminal_result_is_current() -> bool:
	if not _battle_closed or not _current_act_battle() or not _current_carryover_fight() \
		or not is_instance_valid(battle_view) or not battle_view.is_visible_in_tree() \
		or battle_result == null or act_outcome == null or run_map == null:
		return false
	var state := act_outcome.get_state()
	var status: String = state.get("run_status", "")
	if status not in [RunActBattleOutcome.VICTORY, RunActBattleOutcome.DEFEAT] \
		or state.get("pending_node_id") != "" or state.get("settled_node_ids", []).is_empty() \
		or state.settled_node_ids.back() != _carryover_node:
		return false
	if status == RunActBattleOutcome.DEFEAT:
		return battle_result.get_outcome() == CombatBattleResult.DEFEAT
	return battle_result.get_outcome() == CombatBattleResult.VICTORY \
		and run_map.get_current_floor() == RunMap.FLOOR_COUNT \
		and run_map.get_node(_carryover_node).get("type") == "Boss"


func _mount_terminal_result() -> void:
	if is_instance_valid(terminal_result_panel) or not _terminal_result_is_current():
		return
	if _difficulty_completed_map != run_map and run_difficulty.get_selected_tier() == _run_tier:
		var previous_profile := profile_state()
		if run_difficulty.complete_run(act_outcome.get_state().run_status == RunActBattleOutcome.VICTORY):
			# Both genuine terminal outcomes are first-run witnesses; no preview,
			# incomplete fight or repeated terminal mount may grant eligibility.
			if get_tree().current_scene == self:
				heirloom_unlocked = true
			_difficulty_completed_map = run_map
			if profile_state() != previous_profile:
				_save_difficulty_progress()
	var panel := load("res://scenes/run_terminal_result_panel.tscn").instantiate() as LiveRunTerminalResultPanel
	if panel == null:
		return
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not panel.open_result(act_outcome):
		remove_child(panel)
		panel.queue_free()
		return
	terminal_result_panel = panel
	_terminal_return_connection = _return_from_terminal.bind(weakref(panel), act_outcome, run_map)
	panel.return_to_title_requested.connect(_terminal_return_connection)
	# The routed terminal view owns navigation, never the old battle Return.
	return_button.disabled = true
	return_button.release_focus()
	panel.return_button.grab_focus()


func _return_from_terminal(source: WeakRef, latch: RunActBattleOutcome, source_map: RunMap) -> void:
	var panel := source.get_ref() as LiveRunTerminalResultPanel if source != null else null
	if panel == null or panel != terminal_result_panel or latch != act_outcome \
		or source_map != run_map or not panel.has_open_result() \
		or not panel.is_visible_in_tree() or not panel._return_requested \
		or not _terminal_result_is_current():
		return
	_return_to_title()


func _clear_terminal_result() -> void:
	if is_instance_valid(terminal_result_panel):
		if _terminal_return_connection.is_valid() \
			and terminal_result_panel.return_to_title_requested.is_connected(_terminal_return_connection):
			terminal_result_panel.return_to_title_requested.disconnect(_terminal_return_connection)
		terminal_result_panel.close_result()
		remove_child(terminal_result_panel)
		terminal_result_panel.queue_free()
	terminal_result_panel = null
	_terminal_return_connection = Callable()


func _current_act_battle() -> bool:
	if act_outcome == null or act_outcome._map != run_map or not _current_carryover_fight():
		return false
	if _battle_closed:
		return true
	return act_outcome._pending_result == battle_result \
		and act_outcome._pending_node_id == run_map.get_current_node_id() \
		and act_outcome._pending_route == run_map.get_route() \
		and act_outcome._pending_floors == run_map.get_floors()


func _current_carryover_fight() -> bool:
	return party_carryover != null and _carryover_map != null \
		and run_map != null and _carryover_map.get_ref() == run_map \
		and run_map.get_generation_revision() == _carryover_revision \
		and run_map.get_route() == _carryover_route and run_map.get_floors() == _carryover_floors \
		and run_map.get_current_node_id() == _carryover_node \
		and run_map.get_node(_carryover_node).get("type") in ["Fight", "Elite", "Boss"] \
		and party == _carryover_party and battle_result == _carryover_result \
		and battle_result != null and battle_result._party == party and battle_result._enemies == enemies


func _commit_fight_carryover() -> bool:
	if not _current_carryover_fight() or _battle_closed \
		or party_carryover.read_state().completed_fights.has(_carryover_node):
		return false
	var committed := party_carryover.commit_victory(_carryover_node, battle_result, party)
	if not committed.ok:
		return false
	run_heroes = committed.heroes
	return true


func _build_title() -> void:
	var bg := ColorRect.new()
	bg.color = Color("2b3135")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	title_view = box
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 32)
	add_child(box)

	title_label = Label.new()
	title_label.text = TITLE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color("ece0c8"))
	title_label.add_theme_constant_override("outline_size", 12)
	title_label.add_theme_color_override("font_outline_color", Color("1a1d20"))
	box.add_child(title_label)

	start_button = Button.new()
	start_button.text = "Start run"
	start_button.custom_minimum_size = Vector2(240, 56)
	start_button.add_theme_font_size_override("font_size", 28)
	start_button.pressed.connect(func(): start_run_requested.emit())
	box.add_child(start_button)
	route_button = Button.new()
	route_button.text = "Choose a route"
	route_button.custom_minimum_size = Vector2(240, 56)
	route_button.pressed.connect(_open_route)
	box.add_child(route_button)
	base_button = Button.new()
	base_button.text = "Quilt village"
	base_button.custom_minimum_size = Vector2(240, 56)
	base_button.tooltip_text = "Visit the Quilt village"
	base_button.pressed.connect(_open_base)
	box.add_child(base_button)
	stitched_fight_button = Button.new()
	stitched_fight_button.name = "StitchedFightButton"
	stitched_fight_button.text = "Stitched Roadblock"
	stitched_fight_button.tooltip_text = "Face the Stitchline Roadblock before Floor 01 combat"
	stitched_fight_button.custom_minimum_size = Vector2(240, 56)
	stitched_fight_button.pressed.connect(_open_stitched_fight)
	box.add_child(stitched_fight_button)
	# The Peddler stays hidden and unfocusable until a real Roadblock victory
	# and Sewing Circle Leave earn it; it is never part of an unwon title.
	stitched_peddler_button = Button.new()
	stitched_peddler_button.name = "StitchedPeddlerButton"
	stitched_peddler_button.text = "Stitched Peddler"
	stitched_peddler_button.tooltip_text = "Choose a bandage, candle stub or spare body part with Roadblock gold"
	stitched_peddler_button.custom_minimum_size = Vector2(240, 56)
	stitched_peddler_button.visible = false
	stitched_peddler_button.disabled = true
	stitched_peddler_button.focus_mode = Control.FOCUS_NONE
	stitched_peddler_button.pressed.connect(_open_stitched_peddler)
	box.add_child(stitched_peddler_button)
	stitched_campfire_button = Button.new()
	stitched_campfire_button.name = "StitchedCampfireButton"
	stitched_campfire_button.text = "Stitched Campfire"
	stitched_campfire_button.tooltip_text = "Mend heroes or trim up to 50 CANDLE after the Roadblock"
	stitched_campfire_button.custom_minimum_size = Vector2(240, 56)
	stitched_campfire_button.visible = false
	stitched_campfire_button.disabled = true
	stitched_campfire_button.focus_mode = Control.FOCUS_NONE
	stitched_campfire_button.pressed.connect(_open_stitched_campfire)
	box.add_child(stitched_campfire_button)
	start_button.focus_next = start_button.get_path_to(route_button)
	route_button.focus_next = route_button.get_path_to(base_button)
	base_button.focus_next = base_button.get_path_to(stitched_fight_button)
	stitched_fight_button.focus_next = stitched_fight_button.get_path_to(start_button)
	start_button.focus_previous = start_button.get_path_to(stitched_fight_button)
	route_button.focus_previous = route_button.get_path_to(start_button)
	base_button.focus_previous = base_button.get_path_to(route_button)
	stitched_fight_button.focus_previous = stitched_fight_button.get_path_to(base_button)
	start_button.grab_focus.call_deferred()
	box.position -= box.get_combined_minimum_size() / 2.0



## S3's ordinary-title, card-free Stitched encounter. The preview record is only
## the title roster: the three foes themselves come from the canonical S5 enemy
## profiles, so every live Roadblock fight uses the same authored kit as the
## catalog and every enemy trophy is resolved by the same loader.
## The S6 receipt supplies ONLY canonical identity/HP/rank. The S2 preview
## supplies its existing nonidentity base stats at each seated rank. Every
## authored hero's parts are present in the combined catalog, but only the
## four admitted heroes receive worn equipment.
func _stitched_floor_config(requested_receipt: Dictionary = {}) -> Dictionary:
	var party: Dictionary = StitchedPartyAdmission.admit(_stitched_party_picks)
	if party.get("ok") != true or party != _stitched_party_receipt \
			or (not requested_receipt.is_empty() and requested_receipt != party):
		return {}
	var preview := StitchedBattleScreen.read_preview()
	if not preview.get("heroes") is Array or preview["heroes"].size() != 4 \
			or not preview.get("foes") is Array or preview["foes"].size() != 3 \
			or not preview.get("parts") is Array:
		return {}
	var roster := StitchedEnemyCatalog.load_catalog()
	if not bool(roster.get("ok", false)):
		return {}
	var owner_catalogs: Dictionary = {}
	for owner_id in StitchedPartyAdmission.HERO_IDS:
		var loaded := StitchedParts.load_catalog("res://data/parts/%s_parts.json" % owner_id)
		if not bool(loaded.get("ok", false)):
			return {}
		owner_catalogs[owner_id] = loaded
	var foes: Array = []
	var seen_foes: Dictionary = {}
	for entry in preview["foes"]:
		if not entry is Dictionary:
			return {}
		var foe_id := str(entry.get("id", ""))
		if foe_id.is_empty() or seen_foes.has(foe_id):
			return {}
		seen_foes[foe_id] = true
		var foe := StitchedEnemyCatalog.foe_for(roster, foe_id)
		if foe.is_empty():
			return {}
		foes.append(foe)
	var generic: Array = []
	for entry in preview["parts"]:
		if not entry is Dictionary:
			return {}
		if str(entry.get("owner", "")) == "any":
			generic.append(entry)
	var definitions: Array = []
	for owner_id in StitchedPartyAdmission.HERO_IDS:
		for part in owner_catalogs[owner_id]["parts"]:
			if str(part.get("owner", "")) != owner_id:
				return {}
			definitions.append(part)
	definitions.append_array(generic)
	definitions.append_array(roster["parts"])
	# This combined validation also excludes duplicated IDs across all sources.
	var catalog := StitchedParts.build_catalog(definitions)
	if not bool(catalog.get("ok", false)):
		return {}
	# Keep the four existing explicitly authored starter loadouts unchanged.
	var starters := {
		"warden": {
			"head": "warden_head_pot_helm_bonk",
			"arms": "warden_arms_shield_catch",
			"torso": "warden_torso_iron_challenge",
			"legs": "warden_legs_rim_toss",
		},
		"seamstress": {
			"head": "seamstress_mending_knot_hat",
			"arms": "seamstress_thread_prick_needle",
			"torso": "seamstress_shielding_hem_coat",
			"legs": "seamstress_tether_loop_spools",
		},
		"tinker": {
			"head": "tinker_head_cog_shot",
			"arms": "tinker_arms_scrap_bomb",
			"torso": "tinker_torso_casing_ward",
			"legs": "tinker_legs_tune_up",
		},
		"lantern_monk": {
			"head": "lantern_monk_head_moth_wink",
			"arms": "lantern_monk_arms_wick_spark",
			"torso": "lantern_monk_torso_lamplight_wash",
			"legs": "lantern_monk_legs_pole_shelter",
		},
	}
	# New heroes wear the FIRST authored part in each slot, never a generic
	# prototype and never an inferred skill or upgrade.
	for owner_id in StitchedPartyAdmission.HERO_IDS:
		if starters.has(owner_id):
			continue
		var first: Dictionary = {}
		for part in owner_catalogs[owner_id]["parts"]:
			var slot := str(part.get("slot", ""))
			if slot in StitchedParts.SLOTS and not first.has(slot):
				first[slot] = str(part.get("id", ""))
		if first.size() != StitchedParts.SLOTS.size():
			return {}
		starters[owner_id] = first
	for owner_id in StitchedPartyAdmission.HERO_IDS:
		for slot in StitchedParts.SLOTS:
			var part_id: String = starters[owner_id][slot]
			var part: Dictionary = catalog["by_id"].get(part_id, {})
			if part.is_empty() or str(part.get("owner", "")) != owner_id \
					or str(part.get("slot", "")) != slot \
					or StitchedParts.ability_at_tier(part, 1).is_empty() \
					or StitchedParts.validate_ability(StitchedParts.ability_at_tier(part, 1)).get("ok") != true:
				return {}
	var config := preview.duplicate(true)
	var selected_heroes: Array = []
	for index in range(4):
		var identity: Dictionary = party["heroes"][index]
		var source: Variant = preview["heroes"][index]
		if not source is Dictionary or not source.get("parts") is Dictionary \
				or identity.get("rank") != index + 1:
			return {}
		var hero: Dictionary = source.duplicate(true)
		hero["id"] = identity["id"]
		hero["name"] = identity["name"]
		hero["max_hp"] = identity["max_hp"]
		hero["rank"] = identity["rank"]
		var worn: Dictionary = {}
		for slot in StitchedParts.SLOTS:
			worn[slot] = {"id": starters[identity["id"]][slot], "tier": 1, "torn": false}
		hero["parts"] = worn
		selected_heroes.append(hero)
	# A trophy is carried only for the currently selected hero by canonical ID.
	# A compatible foreign trophy is legal; its owner is not the wearer.
	for hero in selected_heroes:
		var carry_value: Variant = _stitched_gear_overrides.get(str(hero["id"]), {})
		if not carry_value is Dictionary:
			return {}
		var carried: Dictionary = carry_value
		for slot in StitchedParts.SLOTS:
			if not carried.has(slot):
				continue
			if not carried[slot] is Dictionary:
				return {}
			var gear: Dictionary = carried[slot]
			var part_id := str(gear.get("id", ""))
			var part: Dictionary = catalog["by_id"].get(part_id, {})
			if part.is_empty() or str(part.get("slot", "")) != slot \
					or not gear.get("tier") is int \
					or int(gear["tier"]) < StitchedParts.MIN_TIER \
					or int(gear["tier"]) > StitchedParts.MAX_TIER \
					or not gear.get("torn") is bool \
					or StitchedParts.ability_at_tier(part, int(gear["tier"])).is_empty():
				return {}
			hero["parts"][slot] = gear.duplicate(true)
	# Project prior terminal-victory health only after the final worn parts are set.
	# Torn equipment contributes no max HP; a lawful swap may lower the cap,
	# but cannot heal a wounded survivor for free.
	for hero in selected_heroes:
		var hero_id := str(hero["id"])
		if not _stitched_hp_carry.has(hero_id):
			continue
		var carried_hp: Variant = _stitched_hp_carry[hero_id]
		if typeof(carried_hp) != TYPE_INT or int(carried_hp) < 0:
			return {}
		var worn_max: int = int(hero["max_hp"])
		for slot in StitchedParts.SLOTS:
			var gear: Dictionary = hero["parts"][slot]
			if not bool(gear["torn"]):
				var definition: Dictionary = catalog["by_id"][str(gear["id"])]
				worn_max += int(StitchedParts.stat_at_tier(definition, int(gear["tier"])).get("max_hp", 0))
		hero["hp"] = mini(int(carried_hp), worn_max)
	# Carried Bleed is a positive integer keyed by canonical hero ID only, and
	# only for heroes this party actually seats. A malformed entry fails the
	# whole admission rather than silently healing a wounded hero.
	for carried_id in _stitched_bleed_carry:
		var carried_value: Variant = _stitched_bleed_carry[carried_id]
		if not str(carried_id) in _stitched_party_picks \
				or typeof(carried_value) != TYPE_INT or int(carried_value) <= 0:
			return {}
	for hero in selected_heroes:
		var hero_id := str(hero["id"])
		if _stitched_bleed_carry.has(hero_id):
			hero["statuses"] = {"bleed": int(_stitched_bleed_carry[hero_id])}
	config["heroes"] = selected_heroes
	config["parts"] = catalog["parts"]
	config["foes"] = foes
	config["seed"] = 4982026
	config["title"] = "Floor 01 · Stitched Crossing"
	config["subtitle"] = "Four heroes against three foes · sewn parts only"
	config["mode"] = "stitched"
	return config


## The Roadblock remains the authority for Fight/toll/Leave. This optional
## control only offers a detached four-of-eight identity selection.
func _stitched_picker_live(source: WeakRef, gate: RunV3FightEventGate,
		generation: int) -> bool:
	var panel := source.get_ref() as LiveEventChoicePanel if source != null else null
	return panel != null and panel == stitched_event_panel and panel.get_parent() == self \
		and panel.is_visible_in_tree() and panel.has_open_event() \
		and panel._wallet_mode and panel._selector != null \
		and not panel._selector.is_claimed() and panel._generation == generation \
		and gate != null and gate == stitched_event_gate and gate.is_valid() \
		and not gate.is_claimed() and not is_instance_valid(stitched_fight_view)


func _stitched_picker_checkbox_ids() -> Array:
	var checked: Array = []
	for id in StitchedPartyAdmission.HERO_IDS:
		var box: CheckBox = _stitched_party_checkboxes.get(id)
		if not is_instance_valid(box):
			return []
		if box.button_pressed:
			checked.append(id)
	return checked


func _stitched_picker_sync() -> void:
	var panel := stitched_event_panel
	if not is_instance_valid(panel):
		return
	var buttons := panel.get_choice_buttons()
	if buttons.size() != 3:
		return
	var receipt := StitchedPartyAdmission.admit(_stitched_party_draft)
	var checked := _stitched_picker_checkbox_ids()
	var matched := checked.size() == _stitched_party_draft.size()
	for id in _stitched_party_draft:
		if not id in checked:
			matched = false
	var valid: bool = matched and receipt.get("ok") == true
	var confirmed: bool = valid and _stitched_party_draft == _stitched_party_picks \
		and receipt == _stitched_party_receipt
	# Incomplete or not-yet-confirmed edits cannot claim the Fight ticket.
	buttons[0].disabled = not confirmed
	buttons[0].focus_mode = Control.FOCUS_NONE if not confirmed else Control.FOCUS_ALL
	_stitched_party_confirm_button.disabled = not valid
	_stitched_party_cancel_button.disabled = confirmed
	if valid:
		var names: Array[String] = []
		for hero in receipt["heroes"]:
			names.append("%d %s" % [hero["rank"], hero["name"]])
		_stitched_party_hint.text = "RANKS · " + "  /  ".join(names) \
			+ ("   · Confirm to use" if not confirmed else "   · Ready to Fight")
	else:
		_stitched_party_hint.text = "Choose exactly four distinct sewn heroes (%d/4)" % checked.size()


func _stitched_picker_changed(pressed: bool, id: String, source: WeakRef,
		gate: RunV3FightEventGate, generation: int) -> void:
	if not _stitched_picker_live(source, gate, generation) \
			or not id in StitchedPartyAdmission.HERO_IDS:
		return
	var box: CheckBox = _stitched_party_checkboxes.get(id)
	if not is_instance_valid(box) or box.button_pressed != pressed:
		return
	if pressed and not id in _stitched_party_draft:
		_stitched_party_draft.append(id)
	elif not pressed and id in _stitched_party_draft:
		_stitched_party_draft.erase(id)
	else:
		return
	_stitched_picker_sync()


func _stitched_picker_confirm(source: WeakRef, gate: RunV3FightEventGate,
		generation: int) -> void:
	if not _stitched_picker_live(source, gate, generation):
		return
	var receipt := StitchedPartyAdmission.admit(_stitched_party_draft)
	var checked := _stitched_picker_checkbox_ids()
	if receipt.get("ok") != true or checked.size() != 4 \
			or _stitched_party_draft.size() != 4:
		return
	for id in _stitched_party_draft:
		if not id in checked:
			return
	# An identical confirmation of the same four heroes in the same rank order
	# keeps the offer already earned; only a real change may invalidate it.
	var party_changed: bool = _stitched_party_draft != _stitched_party_picks \
		or receipt.get("heroes", []) != _stitched_party_receipt.get("heroes", [])
	# Update nothing until the complete canonical receipt has passed.
	_stitched_party_picks = _stitched_party_draft.duplicate()
	_stitched_party_receipt = receipt.duplicate(true)
	# Only currently selected hero IDs retain their previously won parts.
	for id in _stitched_gear_overrides.keys():
		if not id in _stitched_party_picks:
			_stitched_gear_overrides.erase(id)
	for id in _stitched_hp_carry.keys():
		if not id in _stitched_party_picks:
			_stitched_hp_carry.erase(id)
	for id in _stitched_bleed_carry.keys():
		if not id in _stitched_party_picks:
			_stitched_bleed_carry.erase(id)
	# A changed party cannot inherit an earlier victory's Peddler offer; an
	# unchanged one must not lose it without a purchase or a free Leave.
	if party_changed:
		_stitched_peddler_roster.clear()
		_stitched_campfire_roster.clear()
		_stitched_campfire_authorized_roster.clear()
		_stitched_campfire_swap_roster.clear()
		_stitched_campfire_swap_satchel.clear()
		_stitched_campfire_swap_gear.clear()
		_stitched_postvictory_stop_available = false
		_refresh_stitched_peddler_button()
	_stitched_picker_sync()


func _stitched_picker_cancel(source: WeakRef, gate: RunV3FightEventGate,
		generation: int) -> void:
	if not _stitched_picker_live(source, gate, generation):
		return
	_stitched_party_draft = _stitched_party_picks.duplicate()
	for id in StitchedPartyAdmission.HERO_IDS:
		var box: CheckBox = _stitched_party_checkboxes.get(id)
		if is_instance_valid(box):
			box.set_pressed_no_signal(id in _stitched_party_draft)
	_stitched_picker_sync()


func _mount_stitched_party_picker(panel: LiveEventChoicePanel,
		gate: RunV3FightEventGate) -> bool:
	var party := StitchedPartyAdmission.admit(_stitched_party_picks)
	if party.get("ok") != true or party != _stitched_party_receipt \
			or panel.get_choice_buttons().size() != 3:
		return false
	_stitched_party_draft = _stitched_party_picks.duplicate()
	_stitched_party_checkboxes.clear()
	var generation: int = panel._generation
	var source: WeakRef = weakref(panel)
	var container := VBoxContainer.new()
	container.name = "StitchedPartyPicker"
	container.add_theme_constant_override("separation", 6)
	var heading := Label.new()
	heading.text = "SEW YOUR PARTY  ·  Four of Eight"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.theme_type_variation = "PatchHeading"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(heading)
	var grid := GridContainer.new()
	grid.name = "StitchedHeroChoices"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	container.add_child(grid)
	for id in StitchedPartyAdmission.HERO_IDS:
		var checkbox := CheckBox.new()
		checkbox.name = "StitchedPick_" + id
		# These static captions are decorative; admission owns identity and HP.
		var label := str(id).replace("_", " ").capitalize()
		checkbox.text = label
		checkbox.tooltip_text = "Select " + label + " for a four-hero rank"
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.custom_minimum_size = Vector2(120, 30)
		checkbox.focus_mode = Control.FOCUS_ALL
		checkbox.set_pressed_no_signal(id in _stitched_party_draft)
		grid.add_child(checkbox)
		_stitched_party_checkboxes[id] = checkbox
		checkbox.toggled.connect(_stitched_picker_changed.bind(id, source, gate, generation))
	_stitched_party_hint = Label.new()
	_stitched_party_hint.name = "StitchedRankPreview"
	_stitched_party_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stitched_party_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stitched_party_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_stitched_party_hint)
	var actions := HBoxContainer.new()
	actions.name = "StitchedPartyActions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	container.add_child(actions)
	_stitched_party_confirm_button = Button.new()
	_stitched_party_confirm_button.name = "StitchedPartyConfirm"
	_stitched_party_confirm_button.text = "Confirm party"
	_stitched_party_confirm_button.custom_minimum_size = Vector2(160, 38)
	_stitched_party_confirm_button.pressed.connect(
		_stitched_picker_confirm.bind(source, gate, generation))
	actions.add_child(_stitched_party_confirm_button)
	_stitched_party_cancel_button = Button.new()
	_stitched_party_cancel_button.name = "StitchedPartyCancel"
	_stitched_party_cancel_button.text = "Cancel edits"
	_stitched_party_cancel_button.custom_minimum_size = Vector2(160, 38)
	_stitched_party_cancel_button.pressed.connect(
		_stitched_picker_cancel.bind(source, gate, generation))
	actions.add_child(_stitched_party_cancel_button)
	# Insert above the three unmodified authored offer buttons, on their
	# existing scrollable parchment. No new graphic is drawn in code.
	panel.event_content.add_child(container)
	panel.event_content.move_child(container, panel.choices_container.get_index())
	_stitched_picker_sync()
	return true


func _open_stitched_fight() -> bool:
	# The title button admits only the authored Roadblock visit. No combat or
	# run objects exist until a separately authenticated Fight is committed.
	if is_instance_valid(stitched_fight_view) or is_instance_valid(stitched_event_panel) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or stitched_sewing_mend_visit != null or stitched_sewing_upgrade_visit != null \
			or is_instance_valid(stitched_peddler_panel) or stitched_peddler_visit != null \
			or stitched_peddler_candle_visit != null or is_instance_valid(stitched_campfire_panel) \
			or stitched_campfire_visit != null or stitched_event_gate != null or deck != null or run_map != null or run_rng != null \
			or is_instance_valid(base_screen) or is_instance_valid(party_picker) \
			or is_instance_valid(route_view) or is_instance_valid(route_atlas_overlay) \
			or is_instance_valid(battle_view) or _route_from_base \
			or not is_instance_valid(title_view) or not title_view.is_visible_in_tree():
		return false
	var gate := RunV3FightEventGate.new(STITCHED_ROADBLOCK_ID)
	if not gate.is_valid() or gate.get_event_id() != STITCHED_ROADBLOCK_ID:
		return false
	var record: Dictionary = gate.get_event()
	var preview: Dictionary = gate.preview_choices(STITCHED_TITLE_WALLET.duplicate(true))
	if not preview.get("ok", false) or preview.get("event_id") != STITCHED_ROADBLOCK_ID \
			or preview.get("fight_choice_id") != gate.get_fight_choice_id() \
			or not preview.get("choices") is Array:
		return false
	var rows: Array = preview["choices"]
	var authored: Array = record.get("choices", [])
	if rows.size() != 3 or authored.size() != rows.size():
		return false
	var afforded: Dictionary = {}
	for index in range(rows.size()):
		if not rows[index] is Dictionary or not authored[index] is Dictionary:
			return false
		var row: Dictionary = rows[index]
		var choice_id: String = str(row.get("choice_id", ""))
		if choice_id != str(authored[index].get("id", "")) \
				or typeof(row.get("affordable")) != TYPE_BOOL:
			return false
		afforded[choice_id] = row["affordable"]
		var request: Dictionary = row.get("fight_request", {})
		if request != ({"node_type": "Fight"} if choice_id == gate.get_fight_choice_id() else {}):
			return false
	if afforded.get(gate.get_fight_choice_id()) != true \
			or afforded.get("leave") != true or afforded.get("pay_road_toll") != false:
		return false
	var panel := preload("res://scenes/event_choice_panel.tscn").instantiate() as LiveEventChoicePanel
	if panel == null:
		return false
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not panel.open_event_with_wallet(record, STITCHED_TITLE_WALLET.duplicate(true)):
		remove_child(panel)
		panel.queue_free()
		return false
	var buttons := panel.get_choice_buttons()
	if buttons.size() != rows.size():
		panel.close_event()
		remove_child(panel)
		panel.queue_free()
		return false
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var forecast := row.duplicate(true)
		forecast.erase("fight_request")
		if not is_instance_valid(buttons[index]) \
				or buttons[index].disabled == bool(row["affordable"]) \
				or panel._wallet_previews.get(str(row["choice_id"]), {}) != forecast:
			panel.close_event()
			remove_child(panel)
			panel.queue_free()
			return false
	stitched_event_gate = gate
	stitched_event_panel = panel
	if not _mount_stitched_party_picker(panel, gate):
		_retire_stitched_roadblock()
		return false
	panel.wallet_choice_committed.connect(_commit_stitched_roadblock.bind(weakref(panel), gate))
	title_view.hide()
	buttons[0].grab_focus.call_deferred()
	return true


func _commit_stitched_roadblock(receipt: Dictionary, source: WeakRef, gate: RunV3FightEventGate) -> void:
	var panel := source.get_ref() as LiveEventChoicePanel if source != null else null
	if panel == null or panel != stitched_event_panel or panel.get_parent() != self \
			or not panel.is_visible_in_tree() or not panel.has_open_event() \
			or not panel._wallet_mode or panel._offered_wallet != STITCHED_TITLE_WALLET \
			or panel._selector == null or not panel._selector.is_claimed() \
			or gate == null or gate != stitched_event_gate or not gate.is_valid() \
			or panel._selector.get_event() != gate.get_event() \
			or not is_instance_valid(title_view) or title_view.is_visible_in_tree() \
			or deck != null or run_map != null or run_rng != null \
			or is_instance_valid(stitched_fight_view) or is_instance_valid(base_screen) \
			or is_instance_valid(route_view) or is_instance_valid(party_picker):
		return
	# The panel's actual committed choice is the only UI witness. Do not trust
	# any supplied fight_request or node_type (especially Elite or Boss).
	if receipt != panel._committed_choice or receipt.size() != 4 \
			or receipt.get("ok") != true or receipt.get("event_id") != STITCHED_ROADBLOCK_ID \
			or receipt.get("wallet") != STITCHED_TITLE_WALLET:
		return
	var choice_id: Variant = receipt.get("choice_id")
	var preview: Dictionary = gate.preview_choices(STITCHED_TITLE_WALLET.duplicate(true))
	if preview.get("ok") != true:
		return
	var affordable := false
	for row_raw in preview.get("choices", []):
		if row_raw is Dictionary and row_raw.get("choice_id") == choice_id:
			affordable = row_raw.get("affordable") == true
			break
	if not affordable:
		return
	# Only Fight needs a confirmed four. An authentic Leave must stay usable
	# even if the player abandoned an incomplete draft.
	if choice_id == gate.get_fight_choice_id():
		var party := StitchedPartyAdmission.admit(_stitched_party_picks)
		if party.get("ok") != true or party != _stitched_party_receipt \
				or _stitched_party_draft != _stitched_party_picks \
				or _stitched_picker_checkbox_ids().size() != 4:
			return
		for id in _stitched_party_picks:
			if not id in _stitched_picker_checkbox_ids():
				return
	# A new, once-only gate settles the same choice and immutable title wallet.
	# A cloned/forged/stale panel receipt cannot promote a visit into combat.
	var admitted: Dictionary = gate.choose_with_wallet(choice_id, STITCHED_TITLE_WALLET.duplicate(true))
	var fight_ok: bool = admitted.get("ok") == true \
			and admitted.get("event_id") == STITCHED_ROADBLOCK_ID \
			and admitted.get("choice_id") == gate.get_fight_choice_id() \
			and admitted.get("wallet") == STITCHED_TITLE_WALLET \
			and admitted.get("fight_request") == {"node_type": "Fight"}
	_retire_stitched_roadblock()
	if fight_ok:
		# Only the receipt settled by THIS panel may enter the live stage.
		_stitched_admitted_fight_gate = gate
		var mounted := _begin_stitched_battle(admitted, gate)
		_stitched_admitted_fight_gate = null
		if mounted:
			return
	_restore_stitched_title()


func _retire_stitched_roadblock() -> void:
	var panel := stitched_event_panel
	# Drop app authority before removing buttons; queued input is then inert.
	stitched_event_panel = null
	stitched_event_gate = null
	_stitched_party_draft.clear()
	_stitched_party_checkboxes.clear()
	_stitched_party_hint = null
	_stitched_party_confirm_button = null
	_stitched_party_cancel_button = null
	if is_instance_valid(panel):
		panel.close_event()
		if panel.get_parent() == self:
			remove_child(panel)
		panel.queue_free()


func _restore_stitched_title() -> void:
	if is_instance_valid(title_view):
		title_view.show()
		if is_instance_valid(stitched_fight_button):
			stitched_fight_button.grab_focus.call_deferred()


func _begin_stitched_battle(admission: Dictionary, gate: RunV3FightEventGate) -> bool:
	if gate == null or gate != _stitched_admitted_fight_gate \
			or not gate.is_claimed() or admission.get("ok") != true \
			or admission.get("event_id") != STITCHED_ROADBLOCK_ID \
			or admission.get("choice_id") != gate.get_fight_choice_id() \
			or admission.get("wallet") != STITCHED_TITLE_WALLET \
			or admission.get("fight_request") != {"node_type": "Fight"} \
			or stitched_event_gate != null or is_instance_valid(stitched_event_panel) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or stitched_sewing_mend_visit != null or stitched_sewing_upgrade_visit != null \
			or is_instance_valid(stitched_fight_view) or is_instance_valid(stitched_campfire_panel) \
			or stitched_campfire_visit != null or deck != null or run_map != null \
			or run_rng != null or not is_instance_valid(title_view) \
			or title_view.is_visible_in_tree():
		return false
	var data := _stitched_floor_config()
	if data.is_empty():
		return false
	# The charge belongs to this Roadblock entry, never the S2 preview.
	# Project first; a rejected begin cannot consume any candlelight.
	var projected_candle := maxi(0, stitched_roadblock_candle - STITCHED_ROADBLOCK_CANDLE_COST)
	data["candle"] = projected_candle
	var stage := StitchedBattleScreen.new()
	if not stage.begin(data):
		stage.free()
		return false
	stitched_fight_view = stage
	_stitched_battle_ticket = weakref(stage)
	stage.exit_requested.connect(_stitched_fight_exit.bind(weakref(stage)))
	add_child(stage)
	if stage.get_parent() != self or not stage.is_inside_tree():
		_close_stitched_fight()
		return false
	# Debit once, after the real fight is mounted with the projected rules input.
	stitched_roadblock_candle = projected_candle
	return true


func _stitched_fight_exit(source: WeakRef) -> void:
	var stage := source.get_ref() as StitchedBattleScreen if source != null else null
	if stage == null or stage != stitched_fight_view:
		return
	# Neither a forged UI receipt nor an unfinished/retreated battle can mint
	# spoils. This exact stage was created by the claimed Roadblock admission.
	var battle: StitchedRules = stage.battle
	var won: bool = _stitched_battle_ticket != null \
			and _stitched_battle_ticket.get_ref() == stage \
			and battle != null and battle.is_valid() and battle.is_over() \
			and battle.outcome() == "victory" and not stage.receipts.is_empty()
	var heroes: Array = []
	var defeated: Array = []
	var roster: Dictionary = {}
	if won:
		roster = StitchedEnemyCatalog.load_catalog()
		won = bool(roster.get("ok", false))
		if won:
			for foe in battle.get_foes():
				var foe_id := str(foe.get("id", ""))
				if not foe_id in STITCHED_ROADBLOCK_FOES:
					won = false
					continue
				won = won and bool(foe.get("dead", false)) and int(foe.get("hp", -1)) == 0
				defeated.append(foe_id)
			won = won and defeated.size() == STITCHED_ROADBLOCK_FOES.size()
		for hero in battle.get_heroes():
			if not bool(hero.get("lost", false)):
				heroes.append(hero.duplicate(true))
	_close_stitched_fight()
	# Retire combat authority before giving the player another interactive node.
	if won and not heroes.is_empty():
		# This exact, once-only stage is the sole HP source. A lost hero is not
		# carried; failed, retreated and replayed exits leave the ledger untouched.
		for id in _stitched_party_picks:
			_stitched_hp_carry.erase(id)
		for hero in heroes:
			_stitched_hp_carry[str(hero["id"])] = int(hero["hp"])
		# One preview gold award belongs to this authenticated victory exit alone.
		# It never enters the legacy run/title wallets or uses global RNG.
		stitched_preview_gold += STITCHED_PREVIEW_WIN_GOLD
		# Only a positive integer Bleed status survives the fight, carried by
		# canonical hero ID. Anything else is dropped, never guessed.
		_stitched_bleed_carry.clear()
		for hero in heroes:
			var statuses: Variant = hero.get("statuses", {})
			if not statuses is Dictionary:
				continue
			var bleed: Variant = (statuses as Dictionary).get("bleed", 0)
			if typeof(bleed) == TYPE_INT and int(bleed) > 0:
				_stitched_bleed_carry[str(hero["id"])] = int(bleed)
		# A fresh terminal victory supersedes any Peddler offer won earlier.
		_stitched_peddler_roster.clear()
		_stitched_campfire_roster.clear()
		_stitched_campfire_authorized_roster.clear()
		_stitched_campfire_swap_roster.clear()
		_stitched_campfire_swap_satchel.clear()
		_stitched_campfire_swap_gear.clear()
		_stitched_postvictory_stop_available = false
		_refresh_stitched_peddler_button()
		# One preview scrap comes from this authenticated victory exit alone.
		# It never enters the legacy run/title wallets or uses global RNG.
		stitched_preview_scraps += 1
		# Only this encounter's own dead foes pay, and each pays through the one
		# canonical S5 trophy the enemy roster resolved for it.
		for foe_id in STITCHED_ROADBLOCK_FOES:
			if not foe_id in defeated:
				continue
			if stitched_preview_satchel.size() >= RunStitchedSewingSwap.SATCHEL_CAP:
				break
			var trophy := StitchedEnemyCatalog.trophy_for(roster, str(foe_id))
			var part: Dictionary = roster.get("parts_by_id", {}).get(trophy, {})
			if trophy.is_empty() or part.is_empty():
				continue
			stitched_preview_satchel.append({
				"id": trophy, "slot": str(part["slot"]), "tier": 1, "torn": false,
			})
		_open_stitched_sewing(heroes)


func _open_stitched_sewing(heroes: Array) -> bool:
	if is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or stitched_sewing_mend_visit != null or stitched_sewing_upgrade_visit != null \
			or is_instance_valid(stitched_fight_view) or not is_instance_valid(title_view) \
			or not title_view.is_visible_in_tree():
		return false
	var config := _stitched_floor_config()
	if config.is_empty():
		return false
	var catalog := StitchedParts.build_catalog(config["parts"])
	if not bool(catalog.get("ok", false)):
		return false
	var roster := StitchedEnemyCatalog.load_catalog()
	if not bool(roster.get("ok", false)):
		return false
	for foe_id in STITCHED_ROADBLOCK_FOES:
		var trophy := StitchedEnemyCatalog.trophy_for(roster, str(foe_id))
		if trophy.is_empty() or not catalog["by_id"].has(trophy):
			return false
	var visit := RunStitchedSewingSwap.new(
		STITCHED_SEWING_NODE_ID, heroes, stitched_preview_satchel, catalog["by_id"])
	var mend_visit := RunStitchedSewingMend.new(
		STITCHED_SEWING_NODE_ID, heroes, stitched_preview_scraps,
		STITCHED_SEWING_MEND_COST, catalog["by_id"])
	var upgrade_visit := RunStitchedSewingUpgrade.new(
		STITCHED_SEWING_NODE_ID, heroes, stitched_preview_scraps,
		STITCHED_SEWING_UPGRADE_COST, catalog["by_id"])
	if visit.read_state().get("ok") != true or mend_visit.read_state().get("ok") != true \
			or upgrade_visit.read_state().get("ok") != true:
		return false
	var panel := Control.new()
	panel.name = "StitchedSewingCircle"
	panel.theme = load("res://themes/gothic_theme.tres")
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	stitched_sewing_visit = visit
	stitched_sewing_mend_visit = mend_visit
	stitched_sewing_upgrade_visit = upgrade_visit
	_stitched_sewing_catalog = catalog["by_id"].duplicate(true)
	stitched_sewing_panel = panel
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_view.hide()
	_refresh_stitched_sewing()
	return true


func _refresh_stitched_sewing() -> void:
	var panel := stitched_sewing_panel
	var visit := stitched_sewing_visit
	var mend_visit := stitched_sewing_mend_visit
	var upgrade_visit := stitched_sewing_upgrade_visit
	if not is_instance_valid(panel) or visit == null or mend_visit == null or upgrade_visit == null:
		return
	for old_child in panel.get_children():
		panel.remove_child(old_child)
		old_child.queue_free()
	var quote: Dictionary = visit.quote()
	var mend_quote: Dictionary = mend_visit.quote()
	var upgrade_quote: Dictionary = upgrade_visit.quote()
	if quote.get("ok") != true or quote.get("open") != true \
			or mend_quote.get("ok") != true or mend_quote.get("open") != true \
			or upgrade_quote.get("ok") != true or upgrade_quote.get("open") != true \
			or quote["state"]["heroes"] != mend_quote["state"]["heroes"] \
			or quote["state"]["heroes"] != upgrade_quote["state"]["heroes"] \
			or int(mend_quote["scraps"]) != stitched_preview_scraps \
			or int(upgrade_quote["scraps"]) != stitched_preview_scraps \
			or int(upgrade_quote["upgrade_cost"]) != STITCHED_SEWING_UPGRADE_COST:
		return
	_stitched_sewing_quote = quote.duplicate(true)
	_stitched_mend_quote = mend_quote.duplicate(true)
	_stitched_upgrade_quote = upgrade_quote.duplicate(true)
	# All the framing is shipped textile artwork, never code-drawn panels.
	var frame := NinePatchRect.new()
	var art_path := "res://assets/paper/ui/panel_felt.png"
	if ResourceLoader.exists(art_path, "Texture2D"):
		frame.texture = load(art_path)
		frame.patch_margin_left = 24
		frame.patch_margin_right = 24
		frame.patch_margin_top = 24
		frame.patch_margin_bottom = 24
	frame.position = Vector2(120, 40)
	frame.size = Vector2(1040, 640)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var heading := Label.new()
	heading.text = "SEWING CIRCLE  ·  SPOILS OF THE STITCHED ROADBLOCK"
	heading.position = Vector2(165, 78)
	heading.size = Vector2(960, 54)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 27)
	panel.add_child(heading)
	var description := Label.new()
	description.text = "A crab claw, scavenger sack and Scribe inkbrush await the needle. Sew new arms on a living hero without coin."
	description.position = Vector2(170, 143)
	description.size = Vector2(950, 64)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(description)
	var count := Label.new()
	count.text = "SATCHEL %d / %d  ·  SCRAPS %d  ·  Mend: %d / Upgrade tier: %d" % [
		int(quote["satchel_count"]), int(quote["satchel_max"]),
		stitched_preview_scraps, STITCHED_SEWING_MEND_COST, STITCHED_SEWING_UPGRADE_COST]
	count.position = Vector2(183, 224)
	count.size = Vector2(910, 36)
	panel.add_child(count)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(180, 278)
	scroll.size = Vector2(920, 270)
	panel.add_child(scroll)
	var offers := VBoxContainer.new()
	offers.custom_minimum_size.x = 890
	offers.add_theme_constant_override("separation", 8)
	scroll.add_child(offers)
	var first_button: Button
	var expected_state: Dictionary = quote["state"].duplicate(true)
	var mend_state: Dictionary = mend_quote["state"].duplicate(true)
	var upgrade_state: Dictionary = upgrade_quote["state"].duplicate(true)
	for hero_row in quote["heroes"]:
		for slot_row in hero_row["slots"]:
			var worn: Dictionary = slot_row["worn"]
			var hero_name := str(hero_row["name"])
			var blocked := str(slot_row["blocked"])
			# The upgrade service owns all tier, affordability and authored
			# effect projections. Disabled offers stay visible and unfocusable.
			for up_hero in upgrade_quote["heroes"]:
				if str(up_hero["hero_id"]) != str(hero_row["hero_id"]):
					continue
				for up_slot in up_hero["slots"]:
					if str(up_slot["slot"]) != str(slot_row["slot"]):
						continue
					var upgrade_button := Button.new()
					upgrade_button.name = "Upgrade_%s_%s" % [str(hero_row["hero_id"]), str(slot_row["slot"])]
					upgrade_button.custom_minimum_size = Vector2(850, 52)
					upgrade_button.disabled = not bool(up_slot["can_upgrade"])
					upgrade_button.focus_mode = Control.FOCUS_NONE if upgrade_button.disabled else Control.FOCUS_ALL
					var up_reason := str(up_slot["blocked"])
					var next_label := "max" if int(up_slot["next_tier"]) == 0 else str(up_slot["next_tier"])
					upgrade_button.text = "Upgrade %s's %s · tier %d → %s · %d scraps%s" % [
						hero_name, str(up_slot["worn"]["name"]), int(up_slot["current_tier"]),
						next_label, int(up_slot["cost"]),
						(" — " + up_reason) if not up_reason.is_empty() else ""]
					upgrade_button.tooltip_text = "CURRENT stat %s / ability %s\nNEXT stat %s / ability %s" % [
						JSON.stringify(up_slot["current_stat"]), JSON.stringify(up_slot["current_ability"]),
						JSON.stringify(up_slot["next_stat"]), JSON.stringify(up_slot["next_ability"])]
					upgrade_button.pressed.connect(_stitched_sewing_upgrade.bind(
						str(hero_row["hero_id"]), str(slot_row["slot"]), upgrade_state.duplicate(true), weakref(panel)))
					offers.add_child(upgrade_button)
					var effects := Label.new()
					effects.name = "UpgradeEffects_%s_%s" % [str(hero_row["hero_id"]), str(slot_row["slot"])]
					effects.custom_minimum_size = Vector2(850, 0)
					effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					effects.text = "NOW %s  /  NEXT %s" % [
						_stitched_upgrade_effects(up_slot["current_stat"], up_slot["current_ability"]),
						_stitched_upgrade_effects(up_slot["next_stat"], up_slot["next_ability"])
							if int(up_slot["next_tier"]) > 0 else "max tier"]
					offers.add_child(effects)
					if not upgrade_button.disabled and first_button == null:
						first_button = upgrade_button
			# Only quoted torn worn parts get a Mend control. Unaffordable
			# and lost-hero requests remain visible but disabled with a reason.
			if bool(worn["torn"]):
				for mend_hero in mend_quote["heroes"]:
					if str(mend_hero["hero_id"]) != str(hero_row["hero_id"]):
						continue
					for mend_slot in mend_hero["slots"]:
						if str(mend_slot["slot"]) != str(slot_row["slot"]):
							continue
						var mend_button := Button.new()
						mend_button.name = "Mend_%s_%s" % [str(hero_row["hero_id"]), str(slot_row["slot"])]
						mend_button.custom_minimum_size = Vector2(850, 48)
						mend_button.disabled = not bool(mend_slot["can_mend"])
						mend_button.focus_mode = Control.FOCUS_NONE if mend_button.disabled else Control.FOCUS_ALL
						var reason := str(mend_slot["blocked"])
						mend_button.text = "Mend %s's torn %s · %d scraps%s" % [
							hero_name, str(worn["name"]), int(mend_slot["cost"]),
							(" — " + reason) if not reason.is_empty() else ""]
						mend_button.tooltip_text = reason
						mend_button.pressed.connect(_stitched_sewing_mend.bind(
							str(hero_row["hero_id"]), str(slot_row["slot"]), mend_state.duplicate(true), weakref(panel)))
						offers.add_child(mend_button)
						if not mend_button.disabled and first_button == null:
							first_button = mend_button
			if not blocked.is_empty():
				var warning := Label.new()
				warning.text = "%s · %s — %s" % [hero_name, str(worn["name"]), blocked]
				offers.add_child(warning)
			for spare in slot_row["offers"]:
				var button := Button.new()
				button.name = "Swap_%s_%d" % [str(hero_row["hero_id"]), int(spare["satchel_index"])]
				button.custom_minimum_size = Vector2(850, 48)
				button.text = "Sew %s onto %s (replace %s · tier %d)" % [
					str(spare["part"]["name"]), hero_name, str(worn["name"]), int(worn["tier"])]
				button.pressed.connect(_stitched_sewing_swap.bind(
					str(hero_row["hero_id"]), str(slot_row["slot"]),
					int(spare["satchel_index"]), expected_state.duplicate(true), weakref(panel)))
				offers.add_child(button)
				if first_button == null:
					first_button = button
	var leave_button := Button.new()
	leave_button.name = "SewingLeave"
	leave_button.text = "Leave the Circle · Return to title"
	leave_button.position = Vector2(405, 576)
	leave_button.size = Vector2(470, 54)
	leave_button.pressed.connect(_stitched_sewing_leave.bind(expected_state.duplicate(true), weakref(panel)))
	panel.add_child(leave_button)
	if first_button != null:
		first_button.grab_focus()
	else:
		leave_button.grab_focus()


func _stitched_upgrade_effects(stat: Dictionary, ability: Dictionary) -> String:
	# These are authored per-tier values, never a caller-side scaling rule.
	return "stat %s · %s · dmg %s · acc %s · crit %s · effects %s" % [
		JSON.stringify(stat), str(ability.get("id", "none")),
		JSON.stringify(ability.get("dmg", [])), str(ability.get("acc", "-")),
		str(ability.get("crit", "-")), JSON.stringify(ability.get("effects", {}))]


# All three independent services must describe the same real node, equipped party,
# preview balance and displayed snapshots before either can change the visit.
func _stitched_sewing_consistent() -> bool:
	if stitched_sewing_visit == null or stitched_sewing_mend_visit == null \
			or stitched_sewing_upgrade_visit == null:
		return false
	var swap_state: Dictionary = stitched_sewing_visit.read_state()
	var mend_state: Dictionary = stitched_sewing_mend_visit.read_state()
	var upgrade_state: Dictionary = stitched_sewing_upgrade_visit.read_state()
	return swap_state.get("ok") == true and mend_state.get("ok") == true \
		and upgrade_state.get("ok") == true \
		and swap_state.get("open") == true and mend_state.get("open") == true \
		and upgrade_state.get("open") == true \
		and swap_state.get("node_id") == STITCHED_SEWING_NODE_ID \
		and mend_state.get("node_id") == STITCHED_SEWING_NODE_ID \
		and upgrade_state.get("node_id") == STITCHED_SEWING_NODE_ID \
		and swap_state.get("heroes") == mend_state.get("heroes") \
		and swap_state.get("heroes") == upgrade_state.get("heroes") \
		and swap_state.get("satchel") == stitched_preview_satchel \
		and mend_state.get("scraps") == stitched_preview_scraps \
		and upgrade_state.get("scraps") == stitched_preview_scraps \
		and mend_state.get("mend_cost") == STITCHED_SEWING_MEND_COST \
		and upgrade_state.get("upgrade_cost") == STITCHED_SEWING_UPGRADE_COST \
		and _stitched_sewing_quote.get("state") == swap_state \
		and _stitched_mend_quote.get("state") == mend_state \
		and _stitched_upgrade_quote.get("state") == upgrade_state


## A live button may spend scraps only against its displayed service quote,
## exact current node and synced swap/mend authority. Service is the only tier
## mutator; its complete receipt is checked before touching the real run.
func _stitched_sewing_upgrade(hero_id: String, slot: String,
		expected_state: Dictionary, source: WeakRef) -> Dictionary:
	var panel: Control = source.get_ref() as Control if source != null else null
	if not is_instance_valid(panel) or panel != stitched_sewing_panel or not panel.is_visible_in_tree() \
			or is_instance_valid(stitched_fight_view) or not _stitched_sewing_consistent() \
			or _stitched_upgrade_quote.get("state", {}) != expected_state:
		return {"ok": false, "error": "stale Sewing Circle upgrade"}
	var offered: Dictionary = {}
	for hero_row in _stitched_upgrade_quote.get("heroes", []):
		if str(hero_row["hero_id"]) != hero_id:
			continue
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) == slot and bool(slot_row["can_upgrade"]) \
					and int(slot_row["cost"]) == STITCHED_SEWING_UPGRADE_COST:
				offered = slot_row
	if offered.is_empty() or stitched_preview_scraps < STITCHED_SEWING_UPGRADE_COST:
		return {"ok": false, "error": "not a displayed affordable upgrade"}
	var expected_heroes: Array = expected_state["heroes"].duplicate(true)
	var part_id := ""
	var tier_before := 0
	var changed_hero: Dictionary = {}
	for hero in expected_heroes:
		if str(hero["id"]) != hero_id:
			continue
		var worn: Dictionary = hero["parts"].get(slot, {})
		if worn.is_empty() or worn != {
				"id": offered["worn"]["id"],
				"tier": offered["current_tier"], "torn": false}:
			return {"ok": false, "error": "quoted worn part differs"}
		part_id = str(worn["id"])
		tier_before = int(worn["tier"])
		hero["parts"][slot]["tier"] = tier_before + 1
		changed_hero = hero.duplicate(true)
	if changed_hero.is_empty() or int(offered["next_tier"]) != tier_before + 1:
		return {"ok": false, "error": "not a quoted tier progression"}
	var receipt: Dictionary = stitched_sewing_upgrade_visit.upgrade(
		hero_id, slot, STITCHED_SEWING_NODE_ID, expected_state)
	var result: Dictionary = receipt.get("state", {})
	if receipt.get("ok") != true or receipt.get("action") != "upgrade" \
			or receipt.get("node_id") != STITCHED_SEWING_NODE_ID \
			or receipt.get("source_state") != expected_state \
			or receipt.get("hero_id") != hero_id or receipt.get("slot") != slot \
			or receipt.get("part_id") != part_id \
			or receipt.get("tier_before") != tier_before \
			or receipt.get("tier_after") != tier_before + 1 \
			or receipt.get("charged_scraps") != STITCHED_SEWING_UPGRADE_COST \
			or receipt.get("scraps_before") != stitched_preview_scraps \
			or receipt.get("scraps") != stitched_preview_scraps - STITCHED_SEWING_UPGRADE_COST \
			or result.get("open") != true \
			or result.get("version") != int(expected_state["version"]) + 1 \
			or result.get("heroes") != expected_heroes \
			or result != stitched_sewing_upgrade_visit.read_state() \
			or receipt.get("changed_heroes") != [changed_hero] \
			or receipt.get("changed_hero") != changed_hero:
		return {"ok": false, "error": "upgrade receipt rejected"}
	var next_swap := RunStitchedSewingSwap.new(
		STITCHED_SEWING_NODE_ID, expected_heroes, stitched_preview_satchel,
		_stitched_sewing_catalog)
	var next_mend := RunStitchedSewingMend.new(
		STITCHED_SEWING_NODE_ID, expected_heroes, int(receipt["scraps"]),
		STITCHED_SEWING_MEND_COST, _stitched_sewing_catalog)
	if next_swap.read_state().get("ok") != true or next_mend.read_state().get("ok") != true:
		return {"ok": false, "error": "could not rebind after upgrade"}
	stitched_sewing_visit.leave(STITCHED_SEWING_NODE_ID, _stitched_sewing_quote["state"])
	stitched_sewing_mend_visit.leave(STITCHED_SEWING_NODE_ID, _stitched_mend_quote["state"])
	stitched_sewing_visit = next_swap
	stitched_sewing_mend_visit = next_mend
	stitched_preview_scraps = int(receipt["scraps"])
	var carried: Dictionary = _stitched_gear_overrides.get(hero_id, {}).duplicate(true)
	carried[slot] = changed_hero["parts"][slot].duplicate(true)
	_stitched_gear_overrides[hero_id] = carried
	_refresh_stitched_sewing()
	return receipt


func _stitched_sewing_mend(hero_id: String, slot: String,
		expected_state: Dictionary, source: WeakRef) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or panel != stitched_sewing_panel or not panel.is_visible_in_tree() \
			or is_instance_valid(stitched_fight_view) or not _stitched_sewing_consistent() \
			or _stitched_mend_quote.get("state", {}) != expected_state:
		return {"ok": false, "error": "stale Sewing Circle mend"}
	var offered := false
	for hero_row in _stitched_mend_quote.get("heroes", []):
		if str(hero_row["hero_id"]) != hero_id:
			continue
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) == slot \
					and bool(slot_row["can_mend"]) and bool(slot_row["worn"]["torn"]):
				offered = true
	if not offered:
		return {"ok": false, "error": "not a quoted affordable torn part"}
	var receipt: Dictionary = stitched_sewing_mend_visit.mend(
		hero_id, slot, STITCHED_SEWING_NODE_ID, expected_state)
	if receipt.get("ok") != true or receipt.get("source_state") != expected_state \
			or receipt.get("charged_scraps") != STITCHED_SEWING_MEND_COST \
			or receipt.get("scraps") != stitched_preview_scraps - STITCHED_SEWING_MEND_COST:
		return {"ok": false, "error": "mend rejected"}
	# Rebind the swap ledger to the exact mended party, keeping satchel order;
	# close its previous authority so an old state cannot be used again.
	var rebound := RunStitchedSewingSwap.new(
		STITCHED_SEWING_NODE_ID, receipt["state"]["heroes"],
		stitched_preview_satchel, _stitched_sewing_catalog)
	var upgrade_rebound := RunStitchedSewingUpgrade.new(
		STITCHED_SEWING_NODE_ID, receipt["state"]["heroes"], int(receipt["scraps"]),
		STITCHED_SEWING_UPGRADE_COST, _stitched_sewing_catalog)
	if rebound.read_state().get("ok") != true or upgrade_rebound.read_state().get("ok") != true:
		return {"ok": false, "error": "could not rebind swap/upgrade visit"}
	stitched_sewing_visit.leave(STITCHED_SEWING_NODE_ID, _stitched_sewing_quote["state"])
	stitched_sewing_upgrade_visit.leave(STITCHED_SEWING_NODE_ID, _stitched_upgrade_quote["state"])
	stitched_sewing_visit = rebound
	stitched_sewing_upgrade_visit = upgrade_rebound
	stitched_preview_scraps = int(receipt["scraps"])
	for changed in receipt["changed_heroes"]:
		var changed_id := str(changed["id"])
		var carried: Dictionary = _stitched_gear_overrides.get(changed_id, {}).duplicate(true)
		carried[slot] = changed["parts"][slot].duplicate(true)
		_stitched_gear_overrides[changed_id] = carried
	_refresh_stitched_sewing()
	return receipt


func _stitched_sewing_swap(hero_id: String, slot: String, satchel_index: int,
		expected_state: Dictionary, source: WeakRef) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or panel != stitched_sewing_panel or not panel.is_visible_in_tree() \
			or stitched_sewing_visit == null or is_instance_valid(stitched_fight_view) \
			or _stitched_sewing_quote.get("state", {}) != expected_state \
			or not _stitched_sewing_consistent():
		return {"ok": false, "error": "stale Sewing Circle"}
	# Authorise only a currently displayed compatible quote, not arbitrary
	# client-supplied indices or a cloned receipt.
	var matched := false
	for hero_row in _stitched_sewing_quote.get("heroes", []):
		if str(hero_row["hero_id"]) != hero_id:
			continue
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) != slot or not bool(slot_row["can_swap"]):
				continue
			for offered in slot_row["offers"]:
				if int(offered["satchel_index"]) == satchel_index:
					matched = true
	if not matched:
		return {"ok": false, "error": "not an offered compatible part"}
	var receipt: Dictionary = stitched_sewing_visit.swap(
		hero_id, slot, satchel_index, STITCHED_SEWING_NODE_ID, expected_state)
	if receipt.get("ok") != true or receipt.get("source_state") != expected_state:
		return {"ok": false, "error": "swap rejected"}
	# A successful swap changes the authoritative hero snapshot used by Mend.
	# Retire the old mend authority and rebind without awarding or spending scrap.
	var rebound := RunStitchedSewingMend.new(
		STITCHED_SEWING_NODE_ID, receipt["state"]["heroes"], stitched_preview_scraps,
		STITCHED_SEWING_MEND_COST, _stitched_sewing_catalog)
	var upgrade_rebound := RunStitchedSewingUpgrade.new(
		STITCHED_SEWING_NODE_ID, receipt["state"]["heroes"], stitched_preview_scraps,
		STITCHED_SEWING_UPGRADE_COST, _stitched_sewing_catalog)
	if rebound.read_state().get("ok") != true or upgrade_rebound.read_state().get("ok") != true:
		return {"ok": false, "error": "could not rebind mend/upgrade visit"}
	stitched_sewing_mend_visit.leave(STITCHED_SEWING_NODE_ID, _stitched_mend_quote["state"])
	stitched_sewing_upgrade_visit.leave(STITCHED_SEWING_NODE_ID, _stitched_upgrade_quote["state"])
	stitched_sewing_mend_visit = rebound
	stitched_sewing_upgrade_visit = upgrade_rebound
	stitched_preview_satchel = receipt["satchel"].duplicate(true)
	for changed in receipt["changed_heroes"]:
		var changed_id := str(changed["id"])
		var carried: Dictionary = _stitched_gear_overrides.get(changed_id, {}).duplicate(true)
		carried[slot] = changed["parts"][slot].duplicate(true)
		_stitched_gear_overrides[changed_id] = carried
	_refresh_stitched_sewing()
	return receipt


func _stitched_sewing_leave(expected_state: Dictionary, source: WeakRef) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or panel != stitched_sewing_panel or not panel.is_visible_in_tree() \
			or stitched_sewing_visit == null or is_instance_valid(stitched_fight_view) \
			or _stitched_sewing_quote.get("state", {}) != expected_state \
			or not _stitched_sewing_consistent():
		return {"ok": false, "error": "stale Sewing Circle"}
	var mend_expected: Dictionary = _stitched_mend_quote["state"].duplicate(true)
	var upgrade_expected: Dictionary = _stitched_upgrade_quote["state"].duplicate(true)
	var receipt: Dictionary = stitched_sewing_visit.leave(STITCHED_SEWING_NODE_ID, expected_state)
	if receipt.get("ok") != true:
		return {"ok": false, "error": "swap Leave rejected"}
	var mend_receipt: Dictionary = stitched_sewing_mend_visit.leave(
		STITCHED_SEWING_NODE_ID, mend_expected)
	if mend_receipt.get("ok") != true:
		return {"ok": false, "error": "mend Leave rejected"}
	var upgrade_receipt: Dictionary = stitched_sewing_upgrade_visit.leave(
		STITCHED_SEWING_NODE_ID, upgrade_expected)
	if upgrade_receipt.get("ok") != true:
		return {"ok": false, "error": "upgrade Leave rejected"}
	# Only all three authenticated, one-shot terminal receipts can carry equipment.
	# A service's closed state preserves exactly the worn heroes it was given.
	var swap_final: Dictionary = receipt.get("state", {})
	var mend_final: Dictionary = mend_receipt.get("state", {})
	var upgrade_final: Dictionary = upgrade_receipt.get("state", {})
	if receipt.get("action") != "leave" or mend_receipt.get("action") != "leave" \
			or upgrade_receipt.get("action") != "leave" \
			or receipt.get("node_id") != STITCHED_SEWING_NODE_ID \
			or mend_receipt.get("node_id") != STITCHED_SEWING_NODE_ID \
			or upgrade_receipt.get("node_id") != STITCHED_SEWING_NODE_ID \
			or receipt.get("source_state") != expected_state \
			or mend_receipt.get("source_state") != mend_expected \
			or upgrade_receipt.get("source_state") != upgrade_expected \
			or swap_final.get("open") != false or mend_final.get("open") != false \
			or upgrade_final.get("open") != false \
			or swap_final.get("version") != int(expected_state["version"]) + 1 \
			or mend_final.get("version") != int(mend_expected["version"]) + 1 \
			or upgrade_final.get("version") != int(upgrade_expected["version"]) + 1 \
			or swap_final.get("heroes") != mend_final.get("heroes") \
			or swap_final.get("heroes") != upgrade_final.get("heroes") \
			or swap_final.get("heroes") != expected_state.get("heroes") \
			or swap_final.get("satchel") != stitched_preview_satchel \
			or mend_final.get("scraps") != stitched_preview_scraps \
			or upgrade_final.get("scraps") != stitched_preview_scraps \
			or upgrade_receipt.get("charged_scraps") != 0:
		return {"ok": false, "error": "inconsistent Sewing Circle Leave"}
	var next_overrides: Dictionary = _stitched_gear_overrides.duplicate(true)
	for hero in swap_final["heroes"]:
		var hero_id := str(hero["id"])
		var carried: Dictionary = next_overrides.get(hero_id, {}).duplicate(true)
		for slot in StitchedParts.SLOTS:
			var worn: Dictionary = hero["parts"][slot]
			if bool(worn["torn"]):
				# Do not replace lawful swap/mend overrides or unrelated gear.
				carried[slot] = worn.duplicate(true)
		if not carried.is_empty():
			next_overrides[hero_id] = carried
	_stitched_gear_overrides = next_overrides
	_close_stitched_sewing()
	# The Peddler is earned only by this exact terminal victory + Circle Leave.
	_offer_stitched_peddler(swap_final["heroes"])
	_offer_stitched_campfire(swap_final["heroes"])
	return receipt


func _close_stitched_sewing() -> void:
	# Forced UI cleanup must also retire old service objects held by callers.
	# Each close is free, one-shot and consumes neither wallet nor RNG.
	if stitched_sewing_visit != null:
		var swap_state: Dictionary = stitched_sewing_visit.read_state()
		if swap_state.get("ok") == true and swap_state.get("open") == true:
			stitched_sewing_visit.leave(STITCHED_SEWING_NODE_ID, swap_state)
	if stitched_sewing_mend_visit != null:
		var mend_state: Dictionary = stitched_sewing_mend_visit.read_state()
		if mend_state.get("ok") == true and mend_state.get("open") == true:
			stitched_sewing_mend_visit.leave(STITCHED_SEWING_NODE_ID, mend_state)
	if stitched_sewing_upgrade_visit != null:
		var upgrade_state: Dictionary = stitched_sewing_upgrade_visit.read_state()
		if upgrade_state.get("ok") == true and upgrade_state.get("open") == true:
			stitched_sewing_upgrade_visit.leave(STITCHED_SEWING_NODE_ID, upgrade_state)
	var panel := stitched_sewing_panel
	stitched_sewing_panel = null
	stitched_sewing_visit = null
	stitched_sewing_mend_visit = null
	stitched_sewing_upgrade_visit = null
	_stitched_sewing_quote.clear()
	_stitched_mend_quote.clear()
	_stitched_upgrade_quote.clear()
	_stitched_sewing_catalog.clear()
	if is_instance_valid(panel):
		if panel.get_parent() == self:
			remove_child(panel)
		panel.queue_free()
	_restore_stitched_title()


func _close_stitched_fight() -> void:
	if not is_instance_valid(stitched_fight_view):
		stitched_fight_view = null
		_stitched_battle_ticket = null
		return
	var stage := stitched_fight_view
	stitched_fight_view = null
	_stitched_battle_ticket = null
	# Retire the authority *before* queued GUI signals or stale references can
	# invoke any of its action handlers again.
	stage.battle = null
	stage._selected_part = ""
	stage._target_ranks.clear()
	if stage.get_parent() == self:
		remove_child(stage)
	stage.queue_free()
	if is_instance_valid(title_view):
		title_view.show()
		if is_instance_valid(stitched_fight_button):
			stitched_fight_button.grab_focus.call_deferred()


## The winning survivors, by ID and rank, are the only Peddler customers. The
## roster is rebuilt from the app's own carried HP/Bleed, so a reselected or
## unliving party fails closed instead of inheriting an earlier offer.
func _offer_stitched_peddler(survivors: Array) -> void:
	_stitched_peddler_roster.clear()
	if survivors.size() == 4 and _stitched_party_picks.size() == 4:
		var roster: Array = []
		for hero_raw in survivors:
			if not hero_raw is Dictionary:
				roster.clear()
				break
			var hero: Dictionary = hero_raw
			var hero_id := str(hero.get("id", ""))
			var rank: Variant = hero.get("rank")
			var statuses := {}
			if hero_id.is_empty() or not hero_id in _stitched_party_picks \
					or not _stitched_hp_carry.has(hero_id) \
					or typeof(rank) != TYPE_INT or int(rank) < 1 or int(rank) > 4:
				roster.clear()
				break
			if _stitched_bleed_carry.has(hero_id):
				var bleed: Variant = _stitched_bleed_carry[hero_id]
				if typeof(bleed) != TYPE_INT or int(bleed) <= 0:
					roster.clear()
					break
				statuses["bleed"] = int(bleed)
			roster.append({"id": hero_id, "name": str(hero.get("name", hero_id)),
				"rank": int(rank), "statuses": statuses})
		if roster.size() == 4:
			roster.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]))
			_stitched_peddler_roster = roster
	if _stitched_peddler_living_roster().is_empty():
		_stitched_peddler_roster.clear()
	_refresh_stitched_peddler_button()


## Only the actual Circle Leave's four non-lost battle heroes can earn
## Campfire. Record their CURRENT battle rank, worn max HP, HP, and fray.
## Unlike Peddler, a zero-HP Hanging (not lost) hero is valid for Mend.
func _offer_stitched_campfire(survivors: Array) -> void:
	_stitched_campfire_roster.clear()
	_stitched_campfire_authorized_roster.clear()
	_stitched_campfire_swap_roster.clear()
	_stitched_campfire_swap_satchel.clear()
	_stitched_campfire_swap_gear.clear()
	if survivors.size() == 4 and _stitched_party_picks.size() == 4:
		var roster: Array = []
		for value in survivors:
			if not value is Dictionary:
				roster.clear()
				break
			var hero: Dictionary = value
			var id := str(hero.get("id", ""))
			if bool(hero.get("lost", true)) or not id in _stitched_party_picks \
					or not _stitched_hp_carry.has(id) \
					or typeof(_stitched_hp_carry[id]) != TYPE_INT \
					or typeof(hero.get("rank")) != TYPE_INT \
					or typeof(hero.get("hp")) != TYPE_INT \
					or typeof(hero.get("max_hp")) != TYPE_INT \
					or typeof(hero.get("fray")) != TYPE_INT \
					or int(hero["hp"]) != int(_stitched_hp_carry[id]):
				roster.clear()
				break
			roster.append({"id": id, "name": str(hero.get("name", id)),
				"position": int(hero["rank"]), "hp": int(hero["hp"]),
				"max_hp": int(hero["max_hp"]), "fray": int(hero["fray"])})
		if roster.size() == 4:
			roster.sort_custom(func(a, b): return int(a["position"]) < int(b["position"]))
			var authority := RunCampfireVisit.new(
				STITCHED_CAMPFIRE_NODE_ID, roster, RunCampfireVisit.STITCHED,
				stitched_roadblock_candle)
			var state: Dictionary = authority.read_state()
			if state.get("ok") == true and state.get("heroes") == roster \
					and state.get("status") == RunCampfireVisit.STITCHED_OPEN:
				_stitched_campfire_roster = roster.duplicate(true)
				_stitched_campfire_authorized_roster = roster.duplicate(true)
				# Retain the FULL worn parts from the authenticated Circle Leave,
				# not the HP/FRAY-only roster the recovery service needs.
				_stitched_campfire_swap_roster = survivors.duplicate(true)
				_stitched_campfire_swap_roster.sort_custom(
					func(a, b): return int(a["rank"]) < int(b["rank"]))
				_stitched_campfire_swap_satchel = stitched_preview_satchel.duplicate(true)
				_stitched_campfire_swap_gear = _stitched_gear_overrides.duplicate(true)
	_stitched_postvictory_stop_available = not _stitched_campfire_roster.is_empty() \
		or not _stitched_peddler_roster.is_empty()
	_refresh_stitched_peddler_button()


## A detached roster must still match every HP ledger entry and the exact
## authenticated Circle receipt. It may not be rebuilt from title defaults.
func _stitched_campfire_living_roster() -> Array:
	if not _stitched_postvictory_stop_available \
			or _stitched_campfire_roster.size() != 4 \
			or _stitched_campfire_roster != _stitched_campfire_authorized_roster \
			or _stitched_party_picks.size() != 4:
		return []
	var ids := {}
	var roster: Array = []
	for hero_value in _stitched_campfire_roster:
		if not hero_value is Dictionary:
			return []
		var hero: Dictionary = hero_value
		var id := str(hero.get("id", ""))
		if id.is_empty() or ids.has(id) or not id in _stitched_party_picks \
				or typeof(hero.get("hp")) != TYPE_INT \
				or not _stitched_hp_carry.has(id) \
				or _stitched_hp_carry[id] != hero["hp"]:
			return []
		ids[id] = true
		roster.append(hero.duplicate(true))
	if ids.size() != 4:
		return []
	var visit := RunCampfireVisit.new(
		STITCHED_CAMPFIRE_NODE_ID, roster, RunCampfireVisit.STITCHED,
		stitched_roadblock_candle)
	if visit.read_state().get("ok") != true:
		return []
	return roster


## A fully detached, currently lawful rank roster (ranks 1..4, four living
## selected heroes and exactly the carried Bleed statuses), or [] to fail closed.
func _stitched_peddler_living_roster() -> Array:
	if _stitched_peddler_roster.size() != 4 or _stitched_party_picks.size() != 4:
		return []
	var ids := {}
	var ranks := {}
	var roster: Array = []
	for hero_raw in _stitched_peddler_roster:
		if not hero_raw is Dictionary:
			return []
		var hero: Dictionary = hero_raw
		var hero_id := str(hero.get("id", ""))
		var rank: Variant = hero.get("rank")
		if hero_id.is_empty() or not hero_id in _stitched_party_picks or ids.has(hero_id) \
				or not _stitched_hp_carry.has(hero_id) \
				or typeof(_stitched_hp_carry[hero_id]) != TYPE_INT \
				or int(_stitched_hp_carry[hero_id]) <= 0 \
				or typeof(rank) != TYPE_INT or int(rank) < 1 or int(rank) > 4 \
				or ranks.has(int(rank)):
			return []
		var statuses: Variant = hero.get("statuses")
		if not statuses is Dictionary:
			return []
		var carried := {}
		if _stitched_bleed_carry.has(hero_id):
			var bleed: Variant = _stitched_bleed_carry[hero_id]
			if typeof(bleed) != TYPE_INT or int(bleed) <= 0:
				return []
			carried["bleed"] = int(bleed)
		if statuses != carried:
			return []
		ids[hero_id] = true
		ranks[int(rank)] = true
		roster.append({"id": hero_id, "name": str(hero.get("name", hero_id)),
			"rank": int(rank), "statuses": carried})
	if ids.size() != 4 or ranks.size() != 4:
		return []
	roster.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]))
	return roster


## Shows the title Peddler button only while a lawful earned roster waits, and
## keeps it inside the title's keyboard ring only at that moment.
func _refresh_stitched_peddler_button() -> void:
	if not is_instance_valid(stitched_peddler_button) or not is_instance_valid(stitched_campfire_button):
		return
	var peddler_ready: bool = _stitched_postvictory_stop_available \
		and not _stitched_peddler_roster.is_empty() \
		and stitched_peddler_visit == null and stitched_peddler_candle_visit == null \
		and stitched_peddler_part_visit == null \
		and not is_instance_valid(stitched_peddler_panel) \
		and stitched_campfire_visit == null and not is_instance_valid(stitched_campfire_panel)
	var campfire_ready: bool = _stitched_postvictory_stop_available \
		and not _stitched_campfire_roster.is_empty() \
		and stitched_campfire_visit == null and not is_instance_valid(stitched_campfire_panel) \
		and stitched_peddler_visit == null and not is_instance_valid(stitched_peddler_panel)
	stitched_peddler_button.visible = peddler_ready
	stitched_peddler_button.disabled = not peddler_ready
	stitched_peddler_button.focus_mode = Control.FOCUS_ALL if peddler_ready else Control.FOCUS_NONE
	stitched_campfire_button.visible = campfire_ready
	stitched_campfire_button.disabled = not campfire_ready
	stitched_campfire_button.focus_mode = Control.FOCUS_ALL if campfire_ready else Control.FOCUS_NONE
	if not is_instance_valid(title_view) or not title_view.is_inside_tree() \
			or not is_instance_valid(stitched_fight_button) or not is_instance_valid(start_button):
		return
	var first: Control = stitched_peddler_button if peddler_ready else stitched_campfire_button \
		if campfire_ready else start_button
	var last: Control = stitched_campfire_button if campfire_ready else stitched_peddler_button \
		if peddler_ready else stitched_fight_button
	stitched_fight_button.focus_next = stitched_fight_button.get_path_to(first)
	start_button.focus_previous = start_button.get_path_to(last)
	if peddler_ready:
		stitched_peddler_button.focus_previous = stitched_peddler_button.get_path_to(stitched_fight_button)
		stitched_peddler_button.focus_next = stitched_peddler_button.get_path_to(
			stitched_campfire_button if campfire_ready else start_button)
	if campfire_ready:
		stitched_campfire_button.focus_previous = stitched_campfire_button.get_path_to(
			stitched_peddler_button if peddler_ready else stitched_fight_button)
		stitched_campfire_button.focus_next = stitched_campfire_button.get_path_to(start_button)


## The title-accessible Peddler: one quoted bandage, candle stub or canonical
## spare, or a free Leave. Only an earned roster can open it.
func _open_stitched_peddler() -> bool:
	if not _stitched_postvictory_stop_available \
			or is_instance_valid(stitched_campfire_panel) or stitched_campfire_visit != null \
			or is_instance_valid(stitched_peddler_panel) or stitched_peddler_visit != null \
			or stitched_peddler_candle_visit != null or stitched_peddler_part_visit != null \
			or is_instance_valid(stitched_event_panel) or stitched_event_gate != null \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or stitched_sewing_mend_visit != null or stitched_sewing_upgrade_visit != null \
			or deck != null or run_map != null or run_rng != null \
			or is_instance_valid(base_screen) or is_instance_valid(party_picker) \
			or is_instance_valid(route_view) or is_instance_valid(route_atlas_overlay) \
			or is_instance_valid(battle_view) \
			or not is_instance_valid(title_view) or not title_view.is_visible_in_tree():
		return false
	var roster := _stitched_peddler_living_roster()
	if roster.is_empty():
		return false
	var visit := RunStitchedPeddlerBandage.open_stitched(
		STITCHED_PEDDLER_NODE_ID, roster, stitched_preview_gold, STITCHED_PEDDLER_PRICE)
	if not visit.is_valid() or not visit.is_open():
		return false
	var quote := visit.read_state()
	if quote.get("ok") != true or quote.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or quote.get("status") != RunStitchedPeddlerBandage.OPEN \
			or int(quote.get("price", 0)) != STITCHED_PEDDLER_PRICE \
			or int(quote.get("gold", -1)) != stitched_preview_gold:
		return false
	# A distinct opt-in candle ledger shares this single earned Peddler
	# entrance and wallet, never the legacy run/shop economy.
	var candle_visit := RunPeddlerVisit.open_stitched_candle(
		STITCHED_PEDDLER_NODE_ID, stitched_roadblock_candle,
		stitched_preview_gold, STITCHED_PEDDLER_PRICE)
	if not candle_visit.is_valid() or not candle_visit.is_open():
		return false
	var candle_state: Dictionary = candle_visit.read_state()
	var candle_quote: Dictionary = candle_visit.quote()
	if candle_state.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or candle_state.get("status") != RunPeddlerVisit.STITCHED_OPEN \
			or candle_state.get("candle") != stitched_roadblock_candle \
			or candle_state.get("gold") != stitched_preview_gold \
			or candle_state.get("item", {}).get("price") != STITCHED_PEDDLER_PRICE \
			or candle_quote.get("ok") != true \
			or candle_quote.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or candle_quote.get("price") != STITCHED_PEDDLER_PRICE \
			or candle_quote.get("restore") != mini(RunPeddlerVisit.CANDLE_STUB_RESTORE,
				RunPeddlerVisit.CANDLE_MAX - stitched_roadblock_candle) \
			or candle_quote.get("choices", []) != (
				[RunPeddlerVisit.BUY_CANDLE_STUB, RunPeddlerVisit.STITCHED_LEAVE]
				if int(candle_quote.get("restore", 0)) > 0
				and stitched_preview_gold >= STITCHED_PEDDLER_PRICE
				else [RunPeddlerVisit.STITCHED_LEAVE]):
		return false
	# The spare-stock authority is the same validated part catalog used by
	# the real Roadblock and Sewing Circle, never a hand-built UI offer.
	var config := _stitched_floor_config()
	if config.is_empty():
		return false
	var catalog := StitchedParts.build_catalog(config["parts"])
	if catalog.get("ok") != true or not catalog.get("by_id", {}).has(STITCHED_PEDDLER_PART_ID):
		return false
	var part_visit := RunStitchedPeddlerPart.open_stitched(
		STITCHED_PEDDLER_NODE_ID, stitched_preview_gold, stitched_preview_satchel,
		catalog["by_id"], STITCHED_PEDDLER_PART_ID, STITCHED_PEDDLER_PRICE)
	if not part_visit.is_valid() or not part_visit.is_open():
		return false
	var part_state: Dictionary = part_visit.read_state()
	var part_quote: Dictionary = part_visit.quote()
	var offered: Dictionary = part_quote.get("offer", {})
	if part_quote.get("ok") != true or part_quote.get("state") != part_state \
			or part_quote.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or part_quote.get("price") != STITCHED_PEDDLER_PRICE \
			or part_quote.get("gold") != stitched_preview_gold \
			or part_quote.get("satchel_count") != stitched_preview_satchel.size() \
			or part_quote.get("satchel_max") != RunStitchedPeddlerPart.SATCHEL_CAP \
			or part_quote.get("choices") != [
				RunStitchedPeddlerPart.DECISION_BUY, RunStitchedPeddlerPart.DECISION_LEAVE] \
			or part_state.get("satchel") != stitched_preview_satchel \
			or part_state.get("status") != RunStitchedPeddlerPart.STATUS_OPEN \
			or offered.get("id") != STITCHED_PEDDLER_PART_ID \
			or offered.get("name") != "Helmet Rattle" \
			or offered.get("tier") != 1 or offered.get("torn") != false:
		return false
	var generation := _stitched_peddler_generation + 1
	var built := _mount_stitched_peddler(
		visit, quote, candle_state, candle_quote, part_state, part_quote, generation)
	var panel: Control = built.get("panel")
	if panel == null:
		return false
	# All three displayed ledgers belong to one exact panel generation.
	stitched_peddler_visit = visit
	stitched_peddler_candle_visit = candle_visit
	stitched_peddler_part_visit = part_visit
	stitched_peddler_panel = panel
	_stitched_peddler_quote = quote.duplicate(true)
	_stitched_peddler_candle_state = candle_state.duplicate(true)
	_stitched_peddler_candle_quote = candle_quote.duplicate(true)
	_stitched_peddler_part_state = part_state.duplicate(true)
	_stitched_peddler_part_quote = part_quote.duplicate(true)
	_stitched_peddler_generation = generation
	# Selection consumes the common earned stop, not just a purchase/Leave.
	_stitched_postvictory_stop_available = false
	_stitched_campfire_roster.clear()
	_stitched_campfire_swap_roster.clear()
	_stitched_campfire_swap_satchel.clear()
	_stitched_campfire_swap_gear.clear()
	_refresh_stitched_peddler_button()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_view.hide()
	var first: Button = built.get("first")
	if first != null and is_instance_valid(first) and not first.disabled:
		first.grab_focus()
	else:
		panel.grab_focus()
	return true


## Gothic-themed visit board. Framing is shipped textile art; only the existing
## theme supplies button chrome, so nothing is drawn in code.
func _mount_stitched_peddler(visit: RunStitchedPeddlerBandage,
		quote: Dictionary, candle_state: Dictionary, candle_quote: Dictionary,
		part_state: Dictionary, part_quote: Dictionary, generation: int) -> Dictionary:
	if not visit.is_valid() or not visit.is_open() \
			or candle_state.get("ok") != true or candle_quote.get("ok") != true \
			or part_state.get("ok") != true or part_quote.get("ok") != true:
		return {}
	var panel := Control.new()
	panel.name = "StitchedPeddler"
	panel.set_meta("peddler_generation", generation)
	panel.theme = load("res://themes/gothic_theme.tres")
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	var frame := NinePatchRect.new()
	frame.name = "PeddlerFrame"
	var art_path := "res://assets/paper/ui/panel_felt.png"
	if ResourceLoader.exists(art_path, "Texture2D"):
		frame.texture = load(art_path)
		frame.patch_margin_left = 24
		frame.patch_margin_right = 24
		frame.patch_margin_top = 24
		frame.patch_margin_bottom = 24
	frame.position = Vector2(120, 40)
	frame.size = Vector2(1040, 640)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var heading := Label.new()
	heading.text = "STITCHED PEDDLER  ·  BANDAGES, CANDLE & SPARE PART"
	heading.position = Vector2(165, 78)
	heading.size = Vector2(960, 54)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 27)
	panel.add_child(heading)
	var description := Label.new()
	description.text = "Choose one: cure Bleed with a bandage, restore up to 25 light with a candle stub, or buy an untorn tier-I Helmet Rattle spare."
	description.position = Vector2(170, 143)
	description.size = Vector2(950, 64)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(description)
	var wallet := Label.new()
	wallet.name = "PeddlerQuote"
	wallet.text = "PREVIEW GOLD  %d    ·    EACH OFFER  %d    ·    LEAVE FREE" % [
		int(quote["gold"]), int(quote["price"])]
	wallet.position = Vector2(183, 212)
	wallet.size = Vector2(910, 36)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(wallet)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(180, 266)
	scroll.size = Vector2(920, 270)
	panel.add_child(scroll)
	var offers := VBoxContainer.new()
	offers.custom_minimum_size.x = 890
	offers.add_theme_constant_override("separation", 10)
	scroll.add_child(offers)
	var state: Dictionary = quote.duplicate(true)
	var first: Button = null
	var bleeding := 0
	for hero_row in quote["heroes"]:
		var hero_id := str(hero_row["id"])
		var hero_name := str(hero_row.get("name", hero_id))
		var statuses: Dictionary = hero_row["statuses"]
		var bleed := int(statuses.get("bleed", 0))
		var eligible: bool = bleed > 0 and hero_id in quote["eligible"]
		if eligible:
			bleeding += 1
		var affordable: bool = int(quote["gold"]) >= int(quote["price"])
		var button := Button.new()
		button.name = "Bandage_" + hero_id
		button.custom_minimum_size = Vector2(850, 52)
		button.disabled = not eligible or not affordable
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		if eligible:
			button.text = "Bandage %d %s · cures Bleed %d · %d gold" % [
				int(hero_row["rank"]), hero_name, bleed, int(quote["price"])]
			button.tooltip_text = "Spend %d preview gold to cure only %s's Bleed" % [
				int(quote["price"]), hero_name]
		else:
			button.text = "%d %s · not bleeding" % [int(hero_row["rank"]), hero_name]
			button.tooltip_text = "Only a hero carrying Bleed can wear a bandage"
		if eligible and not affordable:
			button.text = "Bandage %d %s · needs %d gold" % [
				int(hero_row["rank"]), hero_name, int(quote["price"])]
			button.tooltip_text = "The quote is %d preview gold; this hero keeps the Bleed" % int(
				quote["price"])
		button.pressed.connect(_stitched_peddler_buy.bind(
			hero_id, state.duplicate(true), weakref(panel)))
		offers.add_child(button)
		if not button.disabled and first == null:
			first = button
	if bleeding == 0:
		var empty := Label.new()
		empty.text = "No survivor is bleeding. Candle stubs and spare parts remain available."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		offers.add_child(empty)
	var candle_button := Button.new()
	candle_button.name = "PeddlerCandleStub"
	candle_button.custom_minimum_size = Vector2(850, 56)
	var candle_now := int(candle_state["candle"])
	var candle_gain := mini(RunPeddlerVisit.CANDLE_STUB_RESTORE,
		RunPeddlerVisit.CANDLE_MAX - candle_now)
	var candle_affordable := int(candle_quote["gold"]) >= int(candle_quote["price"])
	candle_button.disabled = candle_gain <= 0 or not candle_affordable
	candle_button.focus_mode = Control.FOCUS_NONE if candle_button.disabled \
		else Control.FOCUS_ALL
	candle_button.text = "Candle stub · +%d CANDLE (to %d / 100) · %d gold" % [
		candle_gain, candle_now + candle_gain, int(candle_quote["price"])]
	if candle_gain == 0:
		candle_button.text = "Candle full (100 / 100) · no stub needed"
	elif not candle_affordable:
		candle_button.text = "Candle stub · needs %d gold" % int(candle_quote["price"])
	candle_button.tooltip_text = "Buy a candle stub instead of a bandage; +25 CANDLE, capped at 100"
	candle_button.pressed.connect(_stitched_peddler_buy_candle.bind(
		state.duplicate(true), candle_state.duplicate(true),
		candle_quote.duplicate(true), weakref(panel), generation))
	offers.add_child(candle_button)
	if first == null and not candle_button.disabled:
		first = candle_button
	var part_offer: Dictionary = part_quote["offer"]
	var part_button := Button.new()
	part_button.name = "PeddlerHelmetRattle"
	part_button.custom_minimum_size = Vector2(850, 56)
	part_button.disabled = not bool(part_quote["can_buy"])
	part_button.focus_mode = Control.FOCUS_NONE if part_button.disabled else Control.FOCUS_ALL
	part_button.text = "%s · tier %d %s spare · %d gold" % [
		str(part_offer["name"]), int(part_offer["tier"]), str(part_offer["slot"]),
		int(part_quote["price"])]
	if part_button.disabled:
		part_button.text += " · " + str(part_quote["blocked"])
	part_button.tooltip_text = "Buy one canonical untorn %s part for the Sewing Circle" % str(
		part_offer["name"])
	part_button.pressed.connect(_stitched_peddler_buy_part.bind(
		state.duplicate(true), candle_state.duplicate(true), candle_quote.duplicate(true),
		part_state.duplicate(true), part_quote.duplicate(true), weakref(panel), generation))
	offers.add_child(part_button)
	if first == null and not part_button.disabled:
		first = part_button
	var leave_button := Button.new()
	leave_button.name = "PeddlerLeave"
	leave_button.text = "Leave the Peddler · free"
	leave_button.position = Vector2(405, 570)
	leave_button.size = Vector2(470, 54)
	leave_button.pressed.connect(_stitched_peddler_leave.bind(
		state.duplicate(true), weakref(panel)))
	panel.add_child(leave_button)
	if first == null:
		first = leave_button
	return {"panel": panel, "first": first}


## Buys exactly one quoted bandage for one eligible hero and closes the visit.
## A stale, forged, duplicated or unaffordable request changes nothing.
func _stitched_peddler_buy(hero_id: String, expected_snapshot: Dictionary,
		source: WeakRef) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or panel != stitched_peddler_panel \
			or not is_instance_valid(panel) or not panel.is_visible_in_tree() \
			or stitched_peddler_visit == null \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or _stitched_peddler_quote != expected_snapshot \
			or not hero_id in expected_snapshot.get("eligible", []):
		return {"ok": false, "error": "stale Peddler bandage"}
	if int(expected_snapshot.get("price", 0)) != STITCHED_PEDDLER_PRICE \
			or int(expected_snapshot.get("gold", -1)) != stitched_preview_gold \
			or stitched_preview_gold < STITCHED_PEDDLER_PRICE:
		return {"ok": false, "error": "unaffordable Peddler bandage"}
	var expected_heroes: Array = expected_snapshot.get("heroes", []).duplicate(true)
	var matched := false
	for hero in expected_heroes:
		if str(hero.get("id", "")) != hero_id:
			continue
		var statuses: Variant = hero.get("statuses")
		if not statuses is Dictionary or int((statuses as Dictionary).get("bleed", 0)) <= 0:
			return {"ok": false, "error": "the hero is not bleeding"}
		(statuses as Dictionary).erase("bleed")
		matched = true
	if not matched:
		return {"ok": false, "error": "unknown Peddler hero"}
	var receipt: Dictionary = stitched_peddler_visit.choose_bandage(
		hero_id, STITCHED_PEDDLER_NODE_ID, expected_snapshot)
	if receipt.get("ok") != true \
			or receipt.get("decision") != RunStitchedPeddlerBandage.BUY_BANDAGE \
			or receipt.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or receipt.get("hero_id") != hero_id \
			or int(receipt.get("price", 0)) != STITCHED_PEDDLER_PRICE \
			or int(receipt.get("charged_gold", 0)) != STITCHED_PEDDLER_PRICE \
			or int(receipt.get("gold", -1)) != stitched_preview_gold - STITCHED_PEDDLER_PRICE \
			or receipt.get("heroes") != expected_heroes:
		return {"ok": false, "error": "Peddler bandage receipt rejected"}
	stitched_preview_gold = int(receipt["gold"])
	# Only the chosen hero's carried Bleed is cured. HP, equipment, satchel,
	# scraps and candle belong to other owners and stay untouched.
	_stitched_bleed_carry.erase(hero_id)
	_stitched_peddler_roster.clear()
	_close_stitched_peddler()
	return receipt


## One mutually exclusive candle-stub purchase from the exact on-screen visit.
## Check the complete displayed bandage and candle ledgers, this panel's own
## generation and the current earned living party before accepting any debit.
func _stitched_peddler_buy_candle(expected_bandage: Dictionary,
		expected_candle: Dictionary, expected_quote: Dictionary,
		source: WeakRef, generation: int) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or not is_instance_valid(panel) or panel != stitched_peddler_panel \
			or not panel.is_visible_in_tree() \
			or generation != _stitched_peddler_generation \
			or panel.get_meta("peddler_generation", -1) != generation \
			or stitched_peddler_visit == null or not stitched_peddler_visit.is_open() \
			or stitched_peddler_candle_visit == null \
			or not stitched_peddler_candle_visit.is_open() \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_event_panel) or stitched_event_gate != null \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or _stitched_peddler_quote != expected_bandage \
			or stitched_peddler_visit.read_state() != expected_bandage \
			or _stitched_peddler_candle_state != expected_candle \
			or _stitched_peddler_candle_quote != expected_quote \
			or stitched_peddler_candle_visit.read_state() != expected_candle \
			or stitched_peddler_candle_visit.quote() != expected_quote:
		return {"ok": false, "error": "stale Peddler candle"}
	var roster := _stitched_peddler_living_roster()
	if roster.size() != 4 or roster != expected_bandage.get("heroes", []) \
			or expected_bandage.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_bandage.get("status") != RunStitchedPeddlerBandage.OPEN \
			or expected_bandage.get("gold") != stitched_preview_gold \
			or expected_bandage.get("price") != STITCHED_PEDDLER_PRICE \
			or expected_candle.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_candle.get("status") != RunPeddlerVisit.STITCHED_OPEN \
			or expected_candle.get("gold") != stitched_preview_gold \
			or expected_candle.get("candle") != stitched_roadblock_candle \
			or expected_candle.get("item", {}).get("price") != STITCHED_PEDDLER_PRICE \
			or expected_quote.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_quote.get("item") != RunPeddlerVisit.CANDLE_STUB \
			or expected_quote.get("candle") != stitched_roadblock_candle \
			or expected_quote.get("gold") != stitched_preview_gold \
			or expected_quote.get("price") != STITCHED_PEDDLER_PRICE \
			or expected_quote.get("restore") != mini(RunPeddlerVisit.CANDLE_STUB_RESTORE,
				RunPeddlerVisit.CANDLE_MAX - stitched_roadblock_candle) \
			or stitched_preview_gold < STITCHED_PEDDLER_PRICE \
			or stitched_roadblock_candle >= RunPeddlerVisit.CANDLE_MAX:
		return {"ok": false, "error": "unauthorized Peddler candle"}
	var before := stitched_roadblock_candle
	var before_gold := stitched_preview_gold
	var after := mini(RunPeddlerVisit.CANDLE_MAX,
		before + RunPeddlerVisit.CANDLE_STUB_RESTORE)
	var receipt: Dictionary = stitched_peddler_candle_visit.select_stitched(
		RunPeddlerVisit.BUY_CANDLE_STUB, STITCHED_PEDDLER_NODE_ID,
		stitched_peddler_candle_visit.read_state())
	if receipt.get("ok") != true \
			or receipt.get("decision") != RunPeddlerVisit.BUY_CANDLE_STUB \
			or receipt.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or receipt.get("mode") != RunPeddlerVisit.STITCHED \
			or receipt.get("item") != RunPeddlerVisit.CANDLE_STUB \
			or receipt.get("status") != RunPeddlerVisit.STITCHED_USED \
			or receipt.get("consumed") != true \
			or receipt.get("price") != STITCHED_PEDDLER_PRICE \
			or receipt.get("charged_gold") != STITCHED_PEDDLER_PRICE \
			or receipt.get("gold") != before_gold - STITCHED_PEDDLER_PRICE \
			or receipt.get("candle_before") != before \
			or receipt.get("candle") != after \
			or receipt.get("restored") != after - before \
			or receipt.get("state") != stitched_peddler_candle_visit.read_state() \
			or not stitched_peddler_candle_visit.is_consumed():
		return {"ok": false, "error": "Peddler candle receipt rejected"}
	# Retire the other service before publishing the accepted candle receipt.
	var bandage_left: Dictionary = stitched_peddler_visit.leave(
		STITCHED_PEDDLER_NODE_ID, expected_bandage)
	if bandage_left.get("ok") != true \
			or bandage_left.get("decision") != RunStitchedPeddlerBandage.LEAVE \
			or bandage_left.get("charged_gold") != 0 \
			or bandage_left.get("gold") != before_gold \
			or bandage_left.get("heroes") != roster:
		return {"ok": false, "error": "Peddler alternative did not retire"}
	stitched_preview_gold = int(receipt["gold"])
	stitched_roadblock_candle = int(receipt["candle"])
	_stitched_peddler_roster.clear()
	_close_stitched_peddler()
	return receipt


## One canonical spare purchase competes with the bandage and candle for the
## same earned panel. Every displayed quote, service, ledger and live hero must
## still agree before this one-use receipt may debit the preview wallet.
func _stitched_peddler_buy_part(expected_bandage: Dictionary,
		expected_candle: Dictionary, expected_candle_quote: Dictionary,
		expected_part: Dictionary, expected_part_quote: Dictionary,
		source: WeakRef, generation: int) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or not is_instance_valid(panel) or panel != stitched_peddler_panel \
			or not panel.is_visible_in_tree() \
			or generation != _stitched_peddler_generation \
			or panel.get_meta("peddler_generation", -1) != generation \
			or stitched_peddler_visit == null or not stitched_peddler_visit.is_open() \
			or stitched_peddler_candle_visit == null \
			or not stitched_peddler_candle_visit.is_open() \
			or stitched_peddler_part_visit == null \
			or not stitched_peddler_part_visit.is_open() \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_event_panel) or stitched_event_gate != null \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or _stitched_peddler_quote != expected_bandage \
			or _stitched_peddler_candle_state != expected_candle \
			or _stitched_peddler_candle_quote != expected_candle_quote \
			or _stitched_peddler_part_state != expected_part \
			or _stitched_peddler_part_quote != expected_part_quote \
			or stitched_peddler_visit.read_state() != expected_bandage \
			or stitched_peddler_candle_visit.read_state() != expected_candle \
			or stitched_peddler_candle_visit.quote() != expected_candle_quote \
			or stitched_peddler_part_visit.read_state() != expected_part \
			or stitched_peddler_part_visit.quote() != expected_part_quote:
		return {"ok": false, "error": "stale Peddler spare"}
	var living := _stitched_peddler_living_roster()
	if living.size() != 4 or living != expected_bandage.get("heroes", []) \
			or expected_bandage.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_bandage.get("status") != RunStitchedPeddlerBandage.OPEN \
			or expected_bandage.get("gold") != stitched_preview_gold \
			or expected_bandage.get("price") != STITCHED_PEDDLER_PRICE \
			or expected_candle.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_candle.get("status") != RunPeddlerVisit.STITCHED_OPEN \
			or expected_candle.get("gold") != stitched_preview_gold \
			or expected_candle.get("candle") != stitched_roadblock_candle \
			or expected_candle.get("item", {}).get("price") != STITCHED_PEDDLER_PRICE \
			or expected_candle_quote.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_candle_quote.get("item") != RunPeddlerVisit.CANDLE_STUB \
			or expected_candle_quote.get("price") != STITCHED_PEDDLER_PRICE \
			or expected_candle_quote.get("gold") != stitched_preview_gold \
			or expected_candle_quote.get("candle") != stitched_roadblock_candle \
			or expected_part.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_part.get("status") != RunStitchedPeddlerPart.STATUS_OPEN \
			or expected_part.get("gold") != stitched_preview_gold \
			or expected_part.get("satchel") != stitched_preview_satchel \
			or expected_part_quote.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or expected_part_quote.get("state") != expected_part \
			or expected_part_quote.get("price") != STITCHED_PEDDLER_PRICE \
			or expected_part_quote.get("gold") != stitched_preview_gold \
			or expected_part_quote.get("satchel_count") != stitched_preview_satchel.size() \
			or expected_part_quote.get("satchel_max") != RunStitchedPeddlerPart.SATCHEL_CAP \
			or expected_part_quote.get("can_buy") != true \
			or expected_part_quote.get("blocked") != "" \
			or expected_part_quote.get("choices") != [
				RunStitchedPeddlerPart.DECISION_BUY, RunStitchedPeddlerPart.DECISION_LEAVE] \
			or expected_part_quote.get("offer", {}).get("id") != STITCHED_PEDDLER_PART_ID \
			or expected_part_quote.get("offer", {}).get("name") != "Helmet Rattle" \
			or expected_part_quote.get("offer", {}).get("tier") != 1 \
			or expected_part_quote.get("offer", {}).get("torn") != false \
			or stitched_preview_gold < STITCHED_PEDDLER_PRICE:
		return {"ok": false, "error": "unauthorized Peddler spare"}
	var before_gold := stitched_preview_gold
	var before_satchel := stitched_preview_satchel.duplicate(true)
	var wanted := {"id": STITCHED_PEDDLER_PART_ID, "slot": "head",
		"tier": 1, "torn": false}
	var expected_after := before_satchel.duplicate(true)
	expected_after.append(wanted)
	var receipt: Dictionary = stitched_peddler_part_visit.buy(
		STITCHED_PEDDLER_NODE_ID, expected_part)
	if receipt.get("ok") != true \
			or receipt.get("decision") != RunStitchedPeddlerPart.DECISION_BUY \
			or receipt.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or receipt.get("price") != STITCHED_PEDDLER_PRICE \
			or receipt.get("charged_gold") != STITCHED_PEDDLER_PRICE \
			or receipt.get("gold_before") != before_gold \
			or receipt.get("gold") != before_gold - STITCHED_PEDDLER_PRICE \
			or receipt.get("part") != wanted \
			or receipt.get("satchel_index") != before_satchel.size() \
			or receipt.get("satchel") != expected_after \
			or receipt.get("source_state") != expected_part \
			or receipt.get("status") != RunStitchedPeddlerPart.STATUS_BOUGHT \
			or receipt.get("state") != stitched_peddler_part_visit.read_state() \
			or receipt.get("state", {}).get("satchel") != expected_after \
			or receipt.get("state", {}).get("gold") != before_gold - STITCHED_PEDDLER_PRICE \
			or not stitched_peddler_part_visit.is_consumed():
		return {"ok": false, "error": "Peddler spare receipt rejected"}
	# Commit only the new spare and debit. The common teardown retires both
	# other offers, so no old focused button can charge or cure afterward.
	stitched_preview_gold = int(receipt["gold"])
	stitched_preview_satchel = receipt["satchel"].duplicate(true)
	_stitched_peddler_roster.clear()
	_close_stitched_peddler()
	return receipt


## Leaves the Peddler for free, preserving every carried status and resource.
func _stitched_peddler_leave(expected_snapshot: Dictionary, source: WeakRef) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if panel == null or panel != stitched_peddler_panel \
			or not is_instance_valid(panel) or not panel.is_visible_in_tree() \
			or stitched_peddler_visit == null \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or _stitched_peddler_quote != expected_snapshot:
		return {"ok": false, "error": "stale Peddler"}
	var receipt: Dictionary = stitched_peddler_visit.leave(
		STITCHED_PEDDLER_NODE_ID, expected_snapshot)
	if receipt.get("ok") != true \
			or receipt.get("decision") != RunStitchedPeddlerBandage.LEAVE \
			or receipt.get("node_id") != STITCHED_PEDDLER_NODE_ID \
			or int(receipt.get("charged_gold", 1)) != 0 \
			or int(receipt.get("gold", -1)) != stitched_preview_gold \
			or receipt.get("heroes") != expected_snapshot.get("heroes", []):
		return {"ok": false, "error": "Peddler Leave receipt rejected"}
	_stitched_peddler_roster.clear()
	_close_stitched_peddler()
	return receipt


func _close_stitched_peddler() -> void:
	var panel := stitched_peddler_panel
	# Every exit retires all three one-use ledgers; neither an old bandage nor an
	# old candle button may later spend from a superseded panel.
	if stitched_peddler_visit != null and stitched_peddler_visit.is_open():
		stitched_peddler_visit.leave(STITCHED_PEDDLER_NODE_ID,
			stitched_peddler_visit.read_state())
	if stitched_peddler_candle_visit != null:
		stitched_peddler_candle_visit.close()
	if stitched_peddler_part_visit != null and stitched_peddler_part_visit.is_open():
		stitched_peddler_part_visit.leave(STITCHED_PEDDLER_NODE_ID,
			stitched_peddler_part_visit.read_state())
	# Retire app authority before removing controls; queued input is then inert.
	stitched_peddler_panel = null
	stitched_peddler_visit = null
	stitched_peddler_candle_visit = null
	stitched_peddler_part_visit = null
	_stitched_peddler_quote.clear()
	_stitched_peddler_candle_state.clear()
	_stitched_peddler_candle_quote.clear()
	_stitched_peddler_part_state.clear()
	_stitched_peddler_part_quote.clear()
	_stitched_peddler_generation += 1
	if is_instance_valid(panel):
		if panel.get_parent() == self:
			remove_child(panel)
		panel.queue_free()
	if is_instance_valid(title_view):
		title_view.show()
	_refresh_stitched_peddler_button()
	if is_instance_valid(stitched_peddler_button) and stitched_peddler_button.visible:
		stitched_peddler_button.grab_focus.call_deferred()
	elif is_instance_valid(stitched_fight_button):
		stitched_fight_button.grab_focus.call_deferred()


## A second title stop beside the Peddler. Only a one-use authenticated
## Circle receipt can supply the complete current roster for this service.
func _open_stitched_campfire() -> bool:
	if not _stitched_postvictory_stop_available \
			or is_instance_valid(stitched_campfire_panel) or stitched_campfire_visit != null \
			or is_instance_valid(stitched_peddler_panel) or stitched_peddler_visit != null \
			or stitched_peddler_candle_visit != null \
			or is_instance_valid(stitched_event_panel) or stitched_event_gate != null \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or stitched_sewing_mend_visit != null or stitched_sewing_upgrade_visit != null \
			or deck != null or run_map != null or run_rng != null \
			or is_instance_valid(base_screen) or is_instance_valid(party_picker) \
			or is_instance_valid(route_view) or is_instance_valid(route_atlas_overlay) \
			or is_instance_valid(battle_view) \
			or not is_instance_valid(title_view) or not title_view.is_visible_in_tree():
		return false
	var roster: Array = _stitched_campfire_living_roster()
	if roster.size() != 4:
		return false
	var visit := RunCampfireVisit.new(
		STITCHED_CAMPFIRE_NODE_ID, roster, RunCampfireVisit.STITCHED,
		stitched_roadblock_candle)
	var state: Dictionary = visit.read_state()
	if state.get("ok") != true or state.get("mode") != RunCampfireVisit.STITCHED \
			or state.get("status") != RunCampfireVisit.STITCHED_OPEN \
			or state.get("node_id") != STITCHED_CAMPFIRE_NODE_ID \
			or state.get("heroes") != roster \
			or state.get("candle") != stitched_roadblock_candle \
			or state.get("quote") != visit.read_state().get("quote") \
			or state.get("quote", {}).get("choices", []).find(RunCampfireVisit.MEND) == -1 \
			or state.get("quote", {}).get("choices", []).find(RunCampfireVisit.TRIM_THE_WICK) == -1 \
			or state.get("quote", {}).get("choices", []).find(RunCampfireVisit.STITCHED_LEAVE) == -1:
		return false
	# Build a distinct swap service from the FINAL Circle Leave parts and six-slot
	# satchel. Recovery remains the ordinary RunCampfireVisit with its own quote.
	var swap_visit: RunStitchedSewingSwap = null
	var swap_state: Dictionary = {}
	var swap_quote: Dictionary = {}
	var config := _stitched_floor_config()
	var source: Array = _stitched_campfire_swap_roster.duplicate(true)
	var lawful := source.size() == 4 and not config.is_empty() \
		and _stitched_campfire_swap_satchel == stitched_preview_satchel \
		and _stitched_campfire_swap_gear == _stitched_gear_overrides
	if lawful:
		for index in range(4):
			var hero: Dictionary = source[index]
			var recovered: Dictionary = roster[index]
			if str(hero.get("id", "")) != str(recovered["id"]) \
					or int(hero.get("rank", -1)) != int(recovered["position"]) \
					or hero.get("hp") != recovered["hp"] \
					or hero.get("max_hp") != recovered["max_hp"] \
					or hero.get("fray") != recovered["fray"] \
					or not hero.get("parts") is Dictionary \
					or hero["parts"] != config["heroes"][index]["parts"]:
				lawful = false
				break
	if lawful:
		var catalog: Dictionary = StitchedParts.build_catalog(config["parts"])
		if catalog.get("ok") == true:
			var candidate := RunStitchedSewingSwap.new(
				STITCHED_CAMPFIRE_NODE_ID, source, stitched_preview_satchel, catalog["by_id"])
			var candidate_state: Dictionary = candidate.read_state()
			var candidate_quote: Dictionary = candidate.quote()
			if candidate_state.get("ok") == true and candidate_state.get("open") == true \
					and candidate_state.get("node_id") == STITCHED_CAMPFIRE_NODE_ID \
					and candidate_state.get("heroes", []).size() == 4 \
					and candidate_state.get("satchel") == stitched_preview_satchel \
					and candidate_quote.get("state") == candidate_state:
				swap_visit = candidate
				swap_state = candidate_state
				swap_quote = candidate_quote
	var generation := _stitched_campfire_generation + 1
	var mounted := _mount_stitched_campfire(state, generation, swap_quote)
	var panel: Control = mounted.get("panel")
	if panel == null:
		return false
	stitched_campfire_visit = visit
	stitched_campfire_panel = panel
	_stitched_campfire_swap_visit = swap_visit
	_stitched_campfire_swap_state = swap_state.duplicate(true)
	_stitched_campfire_state = state.duplicate(true)
	_stitched_campfire_generation = generation
	# The stop is spent on panel selection, even if the player chooses Leave.
	_stitched_postvictory_stop_available = false
	_stitched_campfire_roster.clear()
	_stitched_peddler_roster.clear()
	_refresh_stitched_peddler_button()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_view.hide()
	var first: Button = mounted.get("first")
	if first != null:
		first.grab_focus()
	return true


func _mount_stitched_campfire(state: Dictionary, generation: int,
		swap_quote: Dictionary) -> Dictionary:
	var panel := Control.new()
	panel.name = "StitchedCampfire"
	panel.set_meta("campfire_generation", generation)
	panel.theme = load("res://themes/gothic_theme.tres")
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	var frame := NinePatchRect.new()
	frame.name = "CampfireFrame"
	var art_path := "res://assets/paper/ui/panel_felt.png"
	if ResourceLoader.exists(art_path, "Texture2D"):
		frame.texture = load(art_path)
		frame.patch_margin_left = 24
		frame.patch_margin_right = 24
		frame.patch_margin_top = 24
		frame.patch_margin_bottom = 24
	frame.position = Vector2(120, 40)
	frame.size = Vector2(1040, 640)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)
	var heading := Label.new()
	heading.name = "CampfireHeading"
	heading.text = "STITCHED CAMPFIRE  ·  TEND THE EMBERS"
	heading.position = Vector2(165, 72)
	heading.size = Vector2(950, 50)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	panel.add_child(heading)
	var quote := Label.new()
	quote.name = "CampfireQuote"
	quote.text = "One earned stop: Mend each hero for 30% max HP, Trim the Wick for up to 50 CANDLE (cap 100), or Leave. All choices free."
	quote.position = Vector2(185, 135)
	quote.size = Vector2(910, 75)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(quote)
	var candle := Label.new()
	candle.name = "CampfireCandle"
	var wick_gain: int = mini(RunCampfireVisit.WICK_CANDLE_RESTORE, \
		RunCampfireVisit.STITCHED_CANDLE_MAX - int(state["candle"]))
	candle.text = "CANDLELIGHT  %d / 100  ·  TRIM +%d → %d / 100" % [
		int(state["candle"]), wick_gain, int(state["candle"]) + wick_gain]
	candle.position = Vector2(250, 215)
	candle.size = Vector2(780, 40)
	candle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(candle)
	for index in range(state["heroes"].size()):
		var hero: Dictionary = state["heroes"][index]
		var maximum: int = int(hero["max_hp"])
		@warning_ignore("integer_division")
		var heal: int = mini(maximum - int(hero["hp"]),
			(maximum * RunCampfireVisit.MEND_HEAL_PERCENT) / 100)
		var row := Label.new()
		row.name = "CampfireHero_%s" % str(hero["id"])
		row.text = "%d  %s  HP %d/%d  FRAY %d  MEND +%d" % [
			int(hero["position"]), str(hero["name"]), int(hero["hp"]),
			maximum, int(hero["fray"]), heal]
		row.position = Vector2(165, 270 + index * 57)
		row.size = Vector2(535, 47)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		panel.add_child(row)
	# Actual per-hero, same-slot catalog offers, in a keyboard-scrollable column.
	# No fabricated tier or spare is ever displayed as actionable.
	var swap_heading := Label.new()
	swap_heading.name = "CampfireSwapHeading"
	swap_heading.text = "EXCHANGE ONE SPARE  ·  FREE"
	swap_heading.position = Vector2(705, 268)
	swap_heading.size = Vector2(430, 36)
	panel.add_child(swap_heading)
	var scroll := ScrollContainer.new()
	scroll.name = "CampfireSwapOffers"
	scroll.position = Vector2(700, 305)
	scroll.size = Vector2(430, 225)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)
	var offers_box := VBoxContainer.new()
	offers_box.name = "CampfireSwapChoices"
	offers_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(offers_box)
	var swap_buttons: Array[Button] = []
	if swap_quote.get("ok") == true and swap_quote.get("open") == true:
		for hero_row in swap_quote.get("heroes", []):
			for slot_row in hero_row.get("slots", []):
				if not bool(slot_row.get("can_swap", false)):
					continue
				for offer in slot_row.get("offers", []):
					var hero_id := str(hero_row["hero_id"])
					var slot := str(slot_row["slot"])
					var satchel_index := int(offer["satchel_index"])
					var button := Button.new()
					button.name = "CampfireSwap_%s_%s_%d" % [hero_id, slot, satchel_index]
					button.text = "%s · %s: %s → %s (T%d%s)" % [
						str(hero_row["name"]), slot,
						str(slot_row["worn"]["name"]), str(offer["part"]["name"]),
						int(offer["part"]["tier"]),
						" torn" if bool(offer["part"]["torn"]) else ""]
					button.custom_minimum_size = Vector2(409, 42)
					button.focus_mode = Control.FOCUS_ALL
					button.pressed.connect(_stitched_campfire_swap_part.bind(
						hero_id, slot, satchel_index, swap_quote["state"].duplicate(true),
						weakref(panel), generation))
					offers_box.add_child(button)
					swap_buttons.append(button)
	if swap_buttons.is_empty():
		var empty := Label.new()
		empty.name = "CampfireNoSwap"
		empty.text = "No lawful untorn, same-slot spare available."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		offers_box.add_child(empty)
	var mend := Button.new()
	mend.name = "CampfireMend"
	mend.text = "Mend · 30% max HP for each · free"
	mend.position = Vector2(185, 550)
	mend.size = Vector2(385, 58)
	mend.focus_mode = Control.FOCUS_ALL
	mend.pressed.connect(_stitched_campfire_choose.bind(
		RunCampfireVisit.MEND, state.duplicate(true), weakref(panel), generation))
	panel.add_child(mend)
	var wick := Button.new()
	wick.name = "CampfireWick"
	wick.text = "Trim the Wick · +%d CANDLE · free" % wick_gain
	wick.position = Vector2(585, 550)
	wick.size = Vector2(315, 58)
	wick.focus_mode = Control.FOCUS_ALL
	wick.pressed.connect(_stitched_campfire_choose.bind(
		RunCampfireVisit.TRIM_THE_WICK, state.duplicate(true), weakref(panel), generation))
	panel.add_child(wick)
	var leave := Button.new()
	leave.name = "CampfireLeave"
	leave.text = "Leave Campfire · free"
	leave.position = Vector2(915, 550)
	leave.size = Vector2(200, 58)
	leave.focus_mode = Control.FOCUS_ALL
	leave.pressed.connect(_stitched_campfire_choose.bind(
		RunCampfireVisit.STITCHED_LEAVE, state.duplicate(true), weakref(panel), generation))
	panel.add_child(leave)
	mend.focus_next = mend.get_path_to(wick)
	wick.focus_previous = wick.get_path_to(mend)
	wick.focus_next = wick.get_path_to(leave)
	leave.focus_previous = leave.get_path_to(wick)
	leave.focus_next = leave.get_path_to(mend)
	mend.focus_previous = mend.get_path_to(leave)
	if not swap_buttons.is_empty():
		# Preserve the existing Mend → Wick → Leave Tab ring (Wick regression).
		# Up from the recovery row enters the scrollable swap list; each offer
		# can then be traversed by keyboard, while recovery Tab remains stable.
		mend.focus_neighbor_top = mend.get_path_to(swap_buttons[0])
		wick.focus_neighbor_top = wick.get_path_to(swap_buttons[0])
		leave.focus_neighbor_top = leave.get_path_to(swap_buttons[0])
		for index in range(swap_buttons.size()):
			var previous: Button = leave if index == 0 else swap_buttons[index - 1]
			var following: Button = mend if index == swap_buttons.size() - 1 else swap_buttons[index + 1]
			swap_buttons[index].focus_previous = swap_buttons[index].get_path_to(previous)
			swap_buttons[index].focus_next = swap_buttons[index].get_path_to(following)
	return {"panel": panel, "first": mend}


## Commit ONE quoted exchange on this specific mounted Campfire panel. The
## recovery visit stays open, with its original HP/FRAY/CANDLE authority.
func _stitched_campfire_swap_part(hero_id: String, slot: String, satchel_index: int,
		expected: Dictionary, source: WeakRef, generation: int) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	var service := _stitched_campfire_swap_visit
	if panel == null or not is_instance_valid(panel) or panel != stitched_campfire_panel \
			or not panel.is_visible_in_tree() or not panel.is_inside_tree() \
			or panel.get_meta("campfire_generation", -1) != generation \
			or generation != _stitched_campfire_generation \
			or service == null or service.read_state().get("open") != true \
			or _stitched_campfire_swap_state != expected \
			or service.read_state() != expected \
			or expected.get("node_id") != STITCHED_CAMPFIRE_NODE_ID \
			or expected.get("heroes") != _stitched_campfire_swap_roster \
			or expected.get("satchel") != stitched_preview_satchel \
			or _stitched_campfire_swap_satchel != stitched_preview_satchel \
			or _stitched_campfire_swap_gear != _stitched_gear_overrides \
			or stitched_campfire_visit == null \
			or stitched_campfire_visit.read_state() != _stitched_campfire_state \
			or _stitched_campfire_state.get("status") != RunCampfireVisit.STITCHED_OPEN \
			or _stitched_campfire_state.get("node_id") != STITCHED_CAMPFIRE_NODE_ID \
			or _stitched_campfire_state.get("heroes") != _stitched_campfire_authorized_roster \
			or _stitched_campfire_state.get("candle") != stitched_roadblock_candle \
			or _stitched_hp_carry.size() != 4 \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_peddler_panel) or stitched_peddler_visit != null \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null:
		return {"ok": false, "error": "stale or forged Campfire exchange"}
	for hero in _stitched_campfire_authorized_roster:
		if not _stitched_hp_carry.has(str(hero["id"])) \
				or _stitched_hp_carry[str(hero["id"])] != hero["hp"]:
			return {"ok": false, "error": "changed survivor authority"}
	var quote: Dictionary = service.quote()
	if quote.get("ok") != true or quote.get("open") != true \
			or quote.get("state") != expected:
		return {"ok": false, "error": "no current exchange quote"}
	var chosen_hero := -1
	var offered := false
	for index in range(quote.get("heroes", []).size()):
		var hero_row: Dictionary = quote["heroes"][index]
		if str(hero_row["hero_id"]) != hero_id:
			continue
		chosen_hero = index
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) != slot or not bool(slot_row["can_swap"]) \
					or bool(slot_row["worn"]["torn"]):
				continue
			for spare_offer in slot_row["offers"]:
				if int(spare_offer["satchel_index"]) == satchel_index \
						and str(spare_offer["part"]["slot"]) == slot:
					offered = true
	if not offered or chosen_hero < 0 or not slot in StitchedParts.SLOTS \
			or satchel_index < 0 or satchel_index >= expected["satchel"].size():
		return {"ok": false, "error": "not an offered same-slot spare"}
	var worn: Dictionary = expected["heroes"][chosen_hero]["parts"][slot]
	var spare: Dictionary = expected["satchel"][satchel_index]
	if bool(worn["torn"]) or str(spare["slot"]) != slot:
		return {"ok": false, "error": "torn or wrong-slot part"}
	var incoming := {"id": str(spare["id"]), "tier": int(spare["tier"]),
		"torn": bool(spare["torn"])}
	var outgoing := {"id": str(worn["id"]), "tier": int(worn["tier"]),
		"torn": bool(worn["torn"]), "slot": slot}
	var after_state: Dictionary = expected.duplicate(true)
	after_state["version"] = int(expected["version"]) + 1
	after_state["heroes"][chosen_hero]["parts"][slot] = incoming.duplicate(true)
	after_state["satchel"][satchel_index] = outgoing.duplicate(true)
	var receipt: Dictionary = service.swap(
		hero_id, slot, satchel_index, STITCHED_CAMPFIRE_NODE_ID, expected)
	var complete := {"ok": true, "error": "", "action": "swap",
		"node_id": STITCHED_CAMPFIRE_NODE_ID, "hero_id": hero_id,
		"slot": slot, "satchel_index": satchel_index,
		"worn_before": worn, "worn_after": incoming,
		"satchel_before": spare, "satchel_after": outgoing,
		"changed_heroes": [after_state["heroes"][chosen_hero]],
		"satchel": after_state["satchel"], "source_state": expected, "state": after_state}
	if receipt != complete or service.read_state() != after_state:
		return {"ok": false, "error": "incomplete Campfire swap receipt"}
	# Close swap only, NOT the separate one-decision recovery service.
	var closed: Dictionary = service.leave(STITCHED_CAMPFIRE_NODE_ID, after_state)
	var closed_state: Dictionary = after_state.duplicate(true)
	closed_state["open"] = false
	closed_state["version"] = int(after_state["version"]) + 1
	if closed != {"ok": true, "error": "", "action": "leave",
			"node_id": STITCHED_CAMPFIRE_NODE_ID, "changed_heroes": [],
			"satchel": closed_state["satchel"], "source_state": after_state,
			"state": closed_state} or service.read_state() != closed_state:
		return {"ok": false, "error": "Campfire exchange did not close"}
	# Only now publish precisely the worn slot and same satchel index.
	var carried: Dictionary = _stitched_gear_overrides.get(hero_id, {}).duplicate(true)
	carried[slot] = incoming.duplicate(true)
	_stitched_gear_overrides[hero_id] = carried
	stitched_preview_satchel = after_state["satchel"].duplicate(true)
	_stitched_campfire_swap_state = closed_state.duplicate(true)
	for button in panel.find_children("CampfireSwap_*", "Button", true, false):
		button.disabled = true
	var heading: Label = panel.find_child("CampfireSwapHeading", true, false)
	if heading != null:
		heading.text = "SPARE EXCHANGED  ·  RECOVERY STILL AVAILABLE"
	var mend: Button = panel.find_child("CampfireMend", true, false)
	if mend != null:
		mend.grab_focus()
	return receipt


## The app accepts only this live panel generation and its WHOLE quoted
## service state; a forged request never publishes a private service result.
func _stitched_campfire_choose(decision: String, expected: Dictionary,
		source: WeakRef, generation: int) -> Dictionary:
	var panel: Control = source.get_ref() if source != null else null
	if not decision in [RunCampfireVisit.MEND, RunCampfireVisit.TRIM_THE_WICK, RunCampfireVisit.STITCHED_LEAVE] \
			or panel == null or not is_instance_valid(panel) \
			or panel != stitched_campfire_panel or not panel.is_visible_in_tree() \
			or panel.get_meta("campfire_generation", -1) != generation \
			or generation != _stitched_campfire_generation \
			or stitched_campfire_visit == null \
			or is_instance_valid(stitched_peddler_panel) or stitched_peddler_visit != null \
			or is_instance_valid(stitched_fight_view) \
			or is_instance_valid(stitched_sewing_panel) or stitched_sewing_visit != null \
			or _stitched_campfire_state != expected \
			or stitched_campfire_visit.read_state() != expected \
			or expected.get("node_id") != STITCHED_CAMPFIRE_NODE_ID \
			or expected.get("status") != RunCampfireVisit.STITCHED_OPEN \
			or expected.get("mode") != RunCampfireVisit.STITCHED \
			or expected.get("heroes", []) != _stitched_campfire_authorized_roster \
			or expected.get("candle") != stitched_roadblock_candle:
		return {"ok": false, "error": "stale or forged Campfire"}
	var before: Array = expected["heroes"].duplicate(true)
	if before.size() != 4 or _stitched_hp_carry.size() != 4:
		return {"ok": false, "error": "missing survivor authority"}
	var after: Array = before.duplicate(true)
	for hero in after:
		var id := str(hero["id"])
		if not _stitched_hp_carry.has(id) or _stitched_hp_carry[id] != hero["hp"]:
			return {"ok": false, "error": "changed survivor HP"}
		if decision == RunCampfireVisit.MEND:
			@warning_ignore("integer_division")
			var heal: int = (int(hero["max_hp"]) * RunCampfireVisit.MEND_HEAL_PERCENT) / 100
			hero["hp"] = mini(int(hero["max_hp"]), int(hero["hp"]) + heal)
	var after_candle: int = int(expected["candle"])
	if decision == RunCampfireVisit.TRIM_THE_WICK:
		after_candle = mini(RunCampfireVisit.STITCHED_CANDLE_MAX,
			after_candle + RunCampfireVisit.WICK_CANDLE_RESTORE)
	var receipt: Dictionary = stitched_campfire_visit.select(
		decision, STITCHED_CAMPFIRE_NODE_ID, before, int(expected["candle"]))
	var committed: Dictionary = stitched_campfire_visit.read_state()
	if receipt != {"ok": true, "decision": decision,
			"node_id": STITCHED_CAMPFIRE_NODE_ID, "heroes": after,
			"candle": after_candle} \
			or committed.get("status") != RunCampfireVisit.STITCHED_DECIDED \
			or committed.get("heroes") != after or committed.get("candle") != after_candle:
		return {"ok": false, "error": "Campfire receipt rejected"}
	# Publish only the chosen ledger after the complete receipt is verified.
	if decision == RunCampfireVisit.MEND:
		for hero in after:
			_stitched_hp_carry[str(hero["id"])] = int(hero["hp"])
	elif decision == RunCampfireVisit.TRIM_THE_WICK:
		stitched_roadblock_candle = after_candle
	_close_stitched_campfire()
	return receipt


func _close_stitched_campfire() -> void:
	var panel := stitched_campfire_panel
	if _stitched_campfire_swap_visit != null:
		var swap_open: Dictionary = _stitched_campfire_swap_visit.read_state()
		if swap_open.get("ok") == true and swap_open.get("open") == true:
			_stitched_campfire_swap_visit.leave(STITCHED_CAMPFIRE_NODE_ID, swap_open)
	_stitched_campfire_swap_visit = null
	_stitched_campfire_swap_state.clear()
	_stitched_campfire_swap_roster.clear()
	_stitched_campfire_swap_satchel.clear()
	_stitched_campfire_swap_gear.clear()
	if stitched_campfire_visit != null:
		var open: Dictionary = stitched_campfire_visit.read_state()
		if open.get("status") == RunCampfireVisit.STITCHED_OPEN:
			stitched_campfire_visit.select(RunCampfireVisit.STITCHED_LEAVE,
				STITCHED_CAMPFIRE_NODE_ID, open["heroes"], open["candle"])
	stitched_campfire_panel = null
	stitched_campfire_visit = null
	_stitched_campfire_state.clear()
	_stitched_campfire_roster.clear()
	_stitched_campfire_authorized_roster.clear()
	_stitched_campfire_generation += 1
	if is_instance_valid(panel):
		if panel.get_parent() == self:
			remove_child(panel)
		panel.queue_free()
	if is_instance_valid(title_view):
		title_view.show()
	_refresh_stitched_peddler_button()
	if is_instance_valid(stitched_fight_button):
		stitched_fight_button.grab_focus.call_deferred()


## Full-screen Quilt village with no run, RNG, deck or currency allocation.
func _open_base() -> bool:
	if deck != null or run_map != null or not is_instance_valid(title_view) \
		or not title_view.is_visible_in_tree() or is_instance_valid(base_screen):
		return false
	var scene := load(BASE_SCREEN_SCENE) as PackedScene
	if scene == null:
		return false
	var view := scene.instantiate() as BaseScreen
	if view == null:
		return false
	base_screen = view
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not view.open_village(session_gold, run_scraps):
		_close_base(view)
		return false
	# One fresh Path setup per village visit. An unreadable authored record keeps
	# the village itself usable but offers no Path options (fail closed).
	var choice := RunSeamstressPathChoice.new()
	run_seamstress_path_choice = choice if choice.is_valid() else null
	if run_seamstress_path_choice != null:
		view.present_path_options(_seamstress_path_options(run_seamstress_path_choice))
	# The Tinker Path is its own board and its own validated offer set. A record
	# that does not validate simply offers no Tinker Path.
	_tinker_setup_receipt = {}
	var tinker := RunTinkerPathChoice.new()
	run_tinker_path_choice = tinker if not tinker.get_offers().is_empty() else null
	if run_tinker_path_choice != null:
		view.present_tinker_path_options(_tinker_path_options(run_tinker_path_choice))
	view.path_choice_requested.connect(_base_path_choice.bind(weakref(view)))
	view.tinker_path_choice_requested.connect(_base_tinker_path_choice.bind(weakref(view)))
	run_warden_path_choice = RunWardenPathChoice.new()
	var warden_options: Array = []
	for path in run_warden_path_choice.get_authored_paths():
		warden_options.append({"id": path.id, "display_name": path.display_name,
			"card_name": path.card.display_name})
	view.present_warden_path_options(warden_options)
	view.warden_path_choice_requested.connect(_base_warden_path_choice.bind(weakref(view)))
	view.set_out_requested.connect(_base_set_out.bind(weakref(view)))
	_present_base_difficulty(view)
	view.difficulty_choice_requested.connect(_base_difficulty_choice.bind(weakref(view)))
	view.back_requested.connect(_base_back.bind(weakref(view)))
	title_view.hide()
	return true


func _base_difficulty_choice(tier: int, source: WeakRef) -> void:
	var view := _live_base(source)
	if view == null or view._set_out_pending or view._back_pending \
		or view._difficulty_request != tier:
		return
	view._difficulty_request = -1
	if run_difficulty.select_tier(tier):
		_save_difficulty_progress()
		_present_base_difficulty(view)


func _present_base_difficulty(view: BaseScreen) -> void:
	view.present_difficulty(run_difficulty.get_available_tiers(), run_difficulty.get_selected_tier())
	for tier in range(view.difficulty_buttons.size()):
		var modifiers := run_difficulty.modifiers_for_tier(tier)
		view.difficulty_buttons[tier].tooltip_text += "\nEnemies: +%d%% max HP (round up), +%d attack intent damage" % [
			modifiers.max_hp_percent_bonus, modifiers.attack_intent_bonus]


## Detached presentation records for the two authored Paths, in authored order.
func _seamstress_path_options(choice: RunSeamstressPathChoice) -> Array:
	var options: Array = []
	for path in choice.get_paths():
		var card: Dictionary = path.get("card", {})
		options.append({
			"id": String(path.get("id", "")),
			"display_name": String(path.get("display_name", "")),
			"card_name": String(card.get("display_name", "")),
		})
	return options


## Detached presentation records for the two authored Tinker Paths, in authored
## order. Read from the same validated offer set the run service uses.
func _tinker_path_options(choice: RunTinkerPathChoice) -> Array:
	var options: Array = []
	for path in choice.get_offers():
		var card: Dictionary = path.get("card", {})
		options.append({
			"id": String(path.get("id", "")),
			"display_name": String(path.get("display_name", "")),
			"card_name": String(card.get("display_name", "")),
		})
	return options


## A Tinker Path pick is only live while it is this app's mounted, visible
## village, the offer set still validates, and no Tinker receipt was committed.
func _base_tinker_path_choice(path_id: String, source: WeakRef) -> void:
	var view := _live_base(source)
	if view == null:
		return
	if not run_tinker_path_receipt.is_empty():
		view.release_tinker_path_choice()
		return
	var choice := run_tinker_path_choice
	if choice == null or choice.get_offers().is_empty() or choice.has_selection():
		view.release_tinker_path_choice()
		return
	var receipt := choice.choose(path_id, StarterCards.new().get_starting_deck())
	if not bool(receipt.get("ok", false)):
		view.release_tinker_path_choice()
		return
	var definition: Dictionary = choice.get_definition(String(receipt.get("path_id", "")))
	_tinker_setup_receipt = receipt.duplicate(true)
	view.mark_tinker_path_selected(String(receipt["path_id"]),
		String(definition.get("display_name", "")))


## The validated Tinker receipt this setup carries, detached from the setup's own
## copy. Nothing is committed until the village really confirmed that Path.
func _selected_tinker_receipt(view: BaseScreen) -> Dictionary:
	if view == null or not bool(_tinker_setup_receipt.get("ok", false)):
		return {}
	if view.selected_tinker_path_id() != String(_tinker_setup_receipt.get("path_id", "")) \
		or run_tinker_path_choice == null or not run_tinker_path_choice.has_selection():
		return {}
	var selection: Dictionary = run_tinker_path_choice.get_selection()
	if String(selection.get("card_id", "")) != String(_tinker_setup_receipt.get("card_id", "")) \
		or String(selection.get("passive_id", "")) != String(_tinker_setup_receipt.get("passive_id", "")):
		return {}
	var definition: Dictionary = run_tinker_path_choice.get_definition(
		String(selection.get("path_id", "")))
	var card: Variant = definition.get("card")
	if not card is Dictionary or String((card as Dictionary).get("id", "")) \
			!= String(_tinker_setup_receipt.get("card_id", "")):
		return {}
	return _tinker_setup_receipt.duplicate(true)


## A Path pick is only live while it is this app's mounted, visible village, the
## setup still offers it once, and no run receipt was committed yet.
func _base_path_choice(path_id: String, source: WeakRef) -> void:
	var view := _live_base(source)
	if view == null:
		return
	if not run_seamstress_path_receipt.is_empty():
		view.release_path_choice()
		return
	var choice := run_seamstress_path_choice
	if choice == null or not choice.is_valid() or choice.is_claimed():
		view.release_path_choice()
		return
	var receipt := choice.choose(path_id, StarterCards.new().get_starting_deck())
	if not bool(receipt.get("ok", false)):
		view.release_path_choice()
		return
	view.mark_path_selected(String(receipt["path_id"]), String(receipt["display_name"]))


## The validated Path this setup carries, detached from the setup's own copy.
func _selected_path_receipt(view: BaseScreen) -> Dictionary:
	if view == null or run_seamstress_path_choice == null \
		or not run_seamstress_path_choice.is_claimed():
		return {}
	var receipt := run_seamstress_path_choice.get_receipt()
	if not bool(receipt.get("ok", false)):
		return {}
	# The committed receipt must be the Path this village actually confirmed.
	if view.selected_path_id() != String(receipt.get("path_id", "")) \
		or view.selected_path_name() != String(receipt.get("display_name", "")):
		return {}
	return receipt


## A Base action is only live while it is this app's mounted, visible village.
func _live_base(source: WeakRef) -> BaseScreen:
	if source == null or not is_instance_valid(base_screen):
		return null
	var view := source.get_ref() as BaseScreen
	if view != base_screen or view.get_parent() != self \
		or not view.is_visible_in_tree() or not view.has_open_village():
		return null
	return view


func _base_warden_path_choice(path_id: String, source: WeakRef) -> void:
	var view := _live_base(source)
	if view == null:
		return
	if not run_warden_path_receipt.is_empty() or run_warden_path_choice == null \
			or not run_warden_path_choice.is_valid():
		view.release_warden_path_choice()
		return
	var receipt := run_warden_path_choice.choose(path_id)
	if not receipt.get("ok", false):
		view.release_warden_path_choice()
		return
	view.mark_warden_path_selected(receipt.path_id, receipt.display_name)


func _selected_warden_receipt(view: BaseScreen) -> Dictionary:
	if view == null or run_warden_path_choice == null:
		return {}
	var receipt := run_warden_path_choice.get_receipt()
	if not RunWardenPathChoice.authenticate_receipt(receipt).get("ok", false) \
			or view.selected_warden_path_id() != receipt.path_id \
			or view.selected_warden_path_name() != receipt.display_name:
		return {}
	return receipt


## No selection means the ordinary opening. A present malformed receipt is
## passed through so CombatRoundFlow's admission refuses it atomically.
func _warden_battle_receipt() -> Variant:
	if run_warden_path_receipt.is_empty():
		return null
	if run_warden_path_choice == null \
			or run_warden_path_choice.get_receipt() != run_warden_path_receipt \
			or not RunWardenPathChoice.authenticate_receipt(run_warden_path_receipt).get("ok", false):
		return {"ok": false}
	return run_warden_path_receipt.duplicate(true)


func _close_base(view: BaseScreen = null) -> void:
	if not is_instance_valid(base_screen):
		base_screen = null
		return
	if view != null and view != base_screen:
		return
	var closing := base_screen
	base_screen = null
	closing.close_village()
	if closing.get_parent() == self:
		remove_child(closing)
	closing.queue_free()


## Set out first mounts the pick-three screen, bound to this village and to this one
## opening; no run, RNG or deck exists until the picker returns a valid party.
func _base_set_out(source: WeakRef) -> void:
	var view := _live_base(source)
	if view == null:
		return
	if deck != null or run_map != null or is_instance_valid(party_picker) or not view._set_out_pending:
		view.release_set_out()
		return
	_party_opening += 1
	party_picker = load("res://scenes/v3_party_picker.tscn").instantiate()
	add_child(party_picker)
	party_picker.party_requested.connect(_admit_base_party.bind(weakref(party_picker), _party_opening, source))
	party_picker.cancel_requested.connect(_cancel_base_party.bind(weakref(party_picker), _party_opening, source))
	# Hidden, the village's own actions are inert while the party is chosen.
	view.hide()


## The village that is waiting on its picker: this app's mounted, open, hidden Base
## whose Set out is still pending.
func _picking_base(source: WeakRef) -> BaseScreen:
	if source == null or not is_instance_valid(base_screen):
		return null
	var view := source.get_ref() as BaseScreen
	if view != base_screen or view.get_parent() != self or not view.has_open_village() \
		or view.visible or not view._set_out_pending:
		return null
	return view


func _cancel_base_party(source: WeakRef, opening: int, base: WeakRef) -> void:
	var view := _picking_base(base)
	if view == null or opening != _party_opening or source.get_ref() != party_picker \
		or not is_instance_valid(party_picker) or not party_picker._latched or party_picker._open:
		return
	_retire_party_picker()
	view.show()
	view.release_set_out()
	view.set_out_button.grab_focus()


## The picker's valid trio opens the route once; only the chosen heroes' Paths ride along.
func _admit_base_party(ids: Array[String], source: WeakRef, opening: int, base: WeakRef) -> void:
	var view := _picking_base(base)
	if view == null or opening != _party_opening or source.get_ref() != party_picker \
		or not is_instance_valid(party_picker) or not party_picker.is_visible_in_tree() \
		or not party_picker._latched or party_picker._open or ids != party_picker.selected_ids() \
		or deck != null or run_map != null:
		return
	var receipt := RunV3PartyAdmission.admit(ids)
	if not receipt.ok or _load_starter_deck().is_empty() or _load_party_definitions().is_empty():
		_cancel_base_party(source, opening, base)
		return
	_open_route(receipt)
	if run_map == null or not is_instance_valid(route_view) or not route_view.is_visible_in_tree():
		_cancel_base_party(source, opening, base)
		return
	# Only a real opening book commits a chosen hero's Path as this run's detached receipt.
	var heroes: Array = receipt.hero_ids
	run_seamstress_path_receipt = _selected_path_receipt(view) if heroes.has("seamstress") else {}
	run_tinker_path_receipt = _selected_tinker_receipt(view) if heroes.has("tinker") else {}
	run_warden_path_receipt = _selected_warden_receipt(view) if heroes.has("warden") else {}
	_route_from_base = true
	_retire_party_picker()
	_close_base(view)


func _base_back(source: WeakRef) -> void:
	var view := _live_base(source)
	if view == null:
		return
	_close_base(view)
	# Back to title abandons this visit's Path setup; nothing of it reaches a run.
	run_seamstress_path_choice = null
	run_seamstress_path_receipt = {}
	run_warden_path_choice = null
	run_warden_path_receipt = {}
	run_tinker_path_choice = null
	run_tinker_path_receipt = {}
	_tinker_setup_receipt = {}
	if is_instance_valid(title_view):
		title_view.show()
	if is_instance_valid(base_button):
		base_button.grab_focus()


var party_picker: LiveV3PartyPicker
var _party_opening := 0
var _party_receipt: Dictionary = {}


func _start_run() -> void:
	if deck != null or run_map != null or is_instance_valid(party_picker) \
		or not title_view.is_visible_in_tree():
		return
	_party_opening += 1
	party_picker = load("res://scenes/v3_party_picker.tscn").instantiate()
	add_child(party_picker)
	party_picker.party_requested.connect(_admit_party.bind(weakref(party_picker), _party_opening))
	party_picker.cancel_requested.connect(_cancel_party.bind(weakref(party_picker), _party_opening))
	title_view.hide()


func _retire_party_picker() -> void:
	_party_opening += 1
	if is_instance_valid(party_picker):
		party_picker._open = false
		party_picker._latched = true
		party_picker.hide()
		remove_child(party_picker)
		party_picker.queue_free()
	party_picker = null


func _cancel_party(source: WeakRef, opening: int) -> void:
	if opening != _party_opening or source.get_ref() != party_picker \
		or not is_instance_valid(party_picker) or not party_picker._latched or party_picker._open:
		return
	_retire_party_picker()
	title_view.show()
	start_button.grab_focus()


func _admit_party(ids: Array[String], source: WeakRef, opening: int) -> void:
	if opening != _party_opening or source.get_ref() != party_picker \
		or not is_instance_valid(party_picker) or not party_picker.is_visible_in_tree() \
		or not party_picker._latched or party_picker._open or ids != party_picker.selected_ids() \
		or deck != null or run_map != null:
		return
	var receipt := RunV3PartyAdmission.admit(ids)
	if not receipt.ok or _load_starter_deck().is_empty() or _load_party_definitions().is_empty():
		_cancel_party(source, opening)
		return
	_open_route(receipt)
	if run_map != null:
		_retire_party_picker()
	else:
		_cancel_party(source, opening)


func _open_route(admission: Dictionary = {}) -> void:
	if is_instance_valid(stitched_event_panel) or is_instance_valid(stitched_fight_view) \
			or stitched_event_gate != null or deck != null or run_map != null \
			or (is_instance_valid(party_picker) and admission.is_empty()):
		return
	if not admission.is_empty() and (not is_instance_valid(party_picker) \
		or party_picker._open or not party_picker._latched \
		or admission != RunV3PartyAdmission.admit(party_picker.selected_ids())):
		return
	var legacy := RunV3PartyAdmission.admit(["warden", "seamstress", "tinker"])
	if not legacy.ok or _load_starter_deck().is_empty() or _load_party_definitions() != legacy.party:
		return
	# A fresh opening starts with no Path receipt; only this Base's Set out commits one.
	run_seamstress_path_receipt = {}
	run_warden_path_receipt = {}
	run_tinker_path_receipt = {}
	_route_from_base = false
	var receipt := admission
	if receipt.is_empty():
		receipt = legacy
	if receipt.get("ok") != true or receipt != RunV3PartyAdmission.admit(receipt.get("hero_ids")):
		return
	var cards: Array[String] = []
	cards.assign(receipt.deck if not admission.is_empty() else _load_starter_deck())
	var initial_party := CombatParty.new(receipt.party)
	if cards.is_empty() or not initial_party.is_valid():
		return
	var carry := RunTornCarryover.new(initial_party.get_heroes())
	if not carry.is_valid() or carry.create_next_fight_party() == null:
		return
	var owners: Array = []
	for hero in initial_party.get_heroes():
		owners.append(hero.id)
	for card in cards:
		if not owners.has(RunRestStitchCards.resolve_card_definition(card).get("owner")):
			return
	_debt_booth_seen = false
	_debt_booth_receipt.clear()
	_party_receipt = receipt.duplicate(true)
	_party_receipt.deck = cards.duplicate()
	run_rng = RandomNumberGenerator.new()
	run_rng.seed = run_seed
	run_map = RunMap.new()
	_run_tier = run_difficulty.get_selected_tier()
	run_map.generate(run_rng)
	fight_selection = RunFightEncounterSelection.new()
	run_deck = cards.duplicate()
	run_heroes = carry.read_state().heroes
	party_carryover = carry
	_carryover_map = weakref(run_map)
	_carryover_revision = run_map.get_generation_revision()
	_carryover_floors = run_map.get_floors()
	act_outcome = RunActBattleOutcome.new(run_map)
	_connected_map = weakref(run_map)
	_connected_route = []
	title_view.hide()
	# A pointer-inert page backdrop is mounted first so the chooser draws over its pages.
	_mount_route_book()
	# The chooser owns the right page's choice rect; every patch is placed on its own
	# authored node slot instead of a stacked list, and stays a direct child because
	# the atlas admission re-checks button.get_parent() == route_view.
	var page := RouteBook.choices_rect()
	route_view = Control.new()
	route_view.name = "OpeningBookChoices"
	route_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	route_view.position = page.position
	route_view.size = page.size
	add_child(route_view)
	# Branches are mounted before the patches, so stitched thread always sews behind them.
	var branches := RouteBranches.new()
	route_view.add_child(branches)
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "Opening route"
	heading.position = Vector2(0.0, 34.0)
	heading.size = Vector2(page.size.x, 30.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.focus_mode = Control.FOCUS_NONE
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", ROUTE_BOOK_INK)
	heading.add_theme_constant_override("outline_size", 4)
	heading.add_theme_color_override("font_outline_color", ROUTE_BOOK_PAPER)
	route_view.add_child(heading)
	var actions: Array[Button] = []
	var branch_targets: Array[Rect2] = []
	for choice in _authenticated_route_choices(run_map, RunV3StopChoiceProjection.project_legal_choices(run_map)):
		var id: String = choice.id
		var node := run_map.get_node(id)
		var button := _route_choice_button(id, String(node.type), true, choice)
		button.position = Vector2(ROUTE_PATCH_LEFT, route_patch_top(int(node.get("position", 0))))
		route_view.add_child(button)
		branch_targets.append(Rect2(button.position, button.size))
		route_buttons.append(button)
		if not button.disabled:
			actions.append(button)
	branches.branch_targets = branch_targets
	route_map_button = _route_book_action("View full map",
		Vector2(ROUTE_PATCH_SIZE.x, ROUTE_ACTION_HEIGHT), "Open the optional full map")
	route_map_button.position = Vector2(ROUTE_PATCH_LEFT, ROUTE_ACTION_TOP)
	route_view.add_child(route_map_button)
	route_map_button.pressed.connect(_open_route_atlas.bind(
		weakref(run_map), weakref(route_view), weakref(route_map_button)))
	actions.append(route_map_button)
	route_back_button = _route_book_action("Back",
		Vector2(ROUTE_PATCH_SIZE.x, ROUTE_ACTION_HEIGHT), "Cancel this opening")
	route_back_button.position = Vector2(ROUTE_PATCH_LEFT,
		ROUTE_ACTION_TOP + ROUTE_ACTION_HEIGHT + ROUTE_ACTION_GAP)
	route_back_button.pressed.connect(_cancel_opening.bind(weakref(run_map), weakref(route_view)))
	route_view.add_child(route_back_button)
	actions.append(route_back_button)
	for index in range(actions.size()):
		actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
		actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])
	actions[0].grab_focus()


## Mount the inert drawn-or-owner page backdrop of the opening chooser once.
func _mount_route_book() -> void:
	if is_instance_valid(route_book_backdrop):
		route_book_backdrop.show_journey(_route_journey_projection())
		return
	var book := RouteBook.new()
	book.show_journey(_route_journey_projection())
	book.board_texture = RunRouteAtlas.load_board_texture(RunRouteAtlas.MAP_BOARD_PATH)
	book.show_party({"heroes": run_heroes.duplicate(true), "deck_count": run_deck.size(),
		"gold": session_gold, "scraps": run_scraps})
	add_child(book)
	route_book_backdrop = book


## Read committed records only. Never derive kinds from IDs or query future nodes.
func _route_journey_projection() -> Dictionary:
	if run_map == null or not run_map.is_generated():
		return {}
	var route := run_map.get_route()
	if route.size() > RunMap.FLOOR_COUNT:
		return {}
	var stops: Array = []
	for index in range(route.size()):
		var node := run_map.get_node(route[index])
		if not node.get("floor") is int or node.floor != index + 1 \
			or (node.get("type") != "Boss" if index + 1 == RunMap.FLOOR_COUNT else
				node.get("type") not in RunMap.NORMAL_TYPES):
			return {}
		if index >= route.size() - 2:
			stops.append({"floor": node.floor, "kind": node.type})
	var complete := route.size() == RunMap.FLOOR_COUNT
	var next_floor := 0 if complete else route.size() + 1
	return {"stops": stops, "complete": complete, "next_floor": next_floor,
		"next_area": RunRouteAtlas.area_for_floor(next_floor)}


## Free the chooser page backdrop synchronously.
func _clear_route_book() -> void:
	if is_instance_valid(route_book_backdrop):
		if route_book_backdrop.get_parent() != null:
			route_book_backdrop.get_parent().remove_child(route_book_backdrop)
		route_book_backdrop.queue_free()
	route_book_backdrop = null


## Cached optional token load; a missing file stays null (and is cached), so the button
## keeps its drawn felt fallback and no path is probed twice.
func _route_token_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not _route_tokens.has(path):
		var loaded: Texture2D = null
		if ResourceLoader.exists(path, "Texture2D"):
			loaded = load(path) as Texture2D
		_route_tokens[path] = loaded
	return _route_tokens.get(path)


## Authenticate the complete read projection against the current map before presentation.
## Detached projected kinds never participate in route admission or dispatch.
func _authenticated_route_choices(source_map: RunMap, projected: Array) -> Array:
	if source_map == null or source_map != run_map:
		return []
	var legal := source_map.get_legal_choices()
	if projected.size() != legal.size():
		return []
	for index in range(legal.size()):
		var source := source_map.get_node(legal[index])
		var choice = projected[index]
		if not choice is Dictionary or source.is_empty() \
			or choice.get("id") != legal[index] or choice.get("type") != source.get("type") \
			or choice.get("v3_kind") != RunV3StopChoiceProjection.v3_kind_for(str(source.get("type"))):
			return []
	return projected.duplicate(true)


## Project the visit's presentation; retain the authenticated source for availability and dispatch.
func _route_choice_button(id: String, kind: String, opening: bool, choice: Dictionary) -> Button:
	# The descriptor is authenticated before mounting; source kind still owns admission.
	var presentation_kind := str(choice.v3_kind)
	var label := route_kind_label(presentation_kind)
	var button := Button.new()
	button.name = "Opening_" + id
	button.text = label
	# Centre the label clear of the sewn token at the left without overriding
	# the root Theme's Button face, colours or focus border.
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = ROUTE_PATCH_SIZE
	button.size = ROUTE_PATCH_SIZE
	button.add_theme_font_size_override("font_size", 20)
	button.set_meta("route_id", id)
	button.set_meta("route_kind", kind)
	button.set_meta("v3_kind", choice.v3_kind)
	button.set_meta("route_label", label)
	if kind in ["SewingCircle", "Campfire", "Rest", "PatchStall", "Unpicker"]:
		button.set_meta("sewing_source", _sewing_context())
	button.disabled = kind not in RunMap.NORMAL_TYPES and (opening or kind != "Boss")
	if button.disabled:
		button.text = label + " (unavailable)"
	else:
		button.tooltip_text = "Choose this %s" % label.to_lower()
		if kind == "Rest":
			button.tooltip_text = "Campfire: Heal each hero 30% max HP (torn revives at 1 HP first), or Leave unchanged for free."
		elif kind == "Shop":
			button.tooltip_text = "Peddler: buy one of three cards or one patch, or Leave for free."
	button.add_child(_route_token(presentation_kind))
	button.add_child(_route_patch_stitch(presentation_kind))
	if opening:
		button.pressed.connect(_choose_route.bind(id, weakref(run_map)))
	return button


## Full map and Back are themed like the patches and sit at the foot of the right page.
func _route_book_action(title: String, action_size: Vector2, tooltip: String) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = action_size
	button.size = action_size
	button.add_theme_font_size_override("font_size", 18)
	button.tooltip_text = tooltip
	return button


## Route/book buttons use the inherited gothic Button face and focus seam.
## Their sewn token art and authored colour-coded marker pieces stay separate.


## The kind's sewn token: committed art when it loads, else its drawn felt fallback.
func _route_token(kind: String) -> RouteToken:
	var art := RouteToken.new()
	art.token_kind = kind
	art.patch_colour = ROUTE_KIND_FELT.get(kind, Color("#6c6478"))
	art.thread_colour = ROUTE_KIND_THREAD.get(kind, ROUTE_BOOK_THREAD)
	art.art_path = RunRouteAtlas.node_token_path(kind)
	art.token_texture = _route_token_texture(art.art_path)
	art.set_meta("route_kind", kind)
	art.set_meta("art_path", art.art_path)
	art.set_meta("art_backed", art.token_texture != null)
	return art


## The patch's stitched edge in its own kind thread, mounted behind the caption.
func _route_patch_stitch(kind: String) -> RoutePatchStitch:
	var stitch := RoutePatchStitch.new()
	stitch.thread_colour = ROUTE_KIND_THREAD.get(kind, ROUTE_BOOK_THREAD)
	stitch.set_meta("route_kind", kind)
	return stitch


func _choose_route(id: String, source_map: WeakRef = null) -> bool:
	if deck != null or run_map == null or not is_instance_valid(route_view) \
			or not route_view.is_visible_in_tree() or not run_map.get_route().is_empty():
		return false
	if source_map != null and source_map.get_ref() != run_map:
		return false
	if not run_map.get_legal_choices().has(id):
		return false
	for button in route_buttons:
		if button.get_meta("route_id") != id:
			continue
		var prior := run_map.get_route()
		var source: WeakRef = weakref(run_map)
		return _dispatch_route(id, source, prior, button)
	return false


## The source record and route, never projected v3 metadata, authorize this alias.
func _opening_rest(id: String, prior: Array[String]) -> bool:
	return run_map != null and prior.is_empty() \
		and run_map.get_node(id).get("type") == "Rest" \
		and run_map.get_node(id).get("floor") == 1


func _dispatch_route(id: String, source: WeakRef, prior: Array[String], button) -> bool:
	if run_map == null or not is_instance_valid(button) \
		or button.get_meta("route_kind", "") != run_map.get_node(id).get("type"):
		return false
	match run_map.get_node(id).get("type"):
		"Unpicker":
			return _choose_unpicker_route(id, source, prior, button)
		"PatchStall":
			return _choose_patch_stall_route(id, source, prior, button)
		"Campfire":
			return _choose_campfire_route(id, source, prior, button)
		"SewingCircle":
			return _choose_sewing_route(id, source, prior, button)
		"Fight", "Elite", "Boss":
			return _choose_battle_route(id, source, prior, button)
		"Rest":
			return _choose_campfire_route(id, source, prior, button)
		"Shop":
			return _choose_shop_route(id, source, prior, button)
		"Event", "Treasure":
			return _choose_placeholder_route(id, source, prior, button)
	return false


## Input is accepted only for the authentic, visible overlay. Invoke the Close
## button's ORIGINAL bound callback, not freshly fabricated source references.
## The event marker prevents a comparison Escape from closing twice if input
## delivery order between the app and standalone atlas ever changes.
func _handle_atlas_escape(key: InputEventKey) -> bool:
	if key.has_meta(RunRouteAtlas.ESCAPE_CONSUMED_META):
		return true
	if key.shift_pressed or key.ctrl_pressed or key.alt_pressed or key.meta_pressed \
			or not is_instance_valid(route_atlas_overlay) or not is_instance_valid(route_atlas) \
			or not is_instance_valid(route_atlas_close) or not is_instance_valid(route_view) \
			or route_atlas_overlay.get_parent() != self \
			or route_atlas.get_parent() != route_atlas_overlay \
			or route_atlas_close.get_parent() != route_atlas_overlay \
			or route_atlas._map != run_map or route_view.visible \
			or not route_atlas.is_visible_in_tree():
		return false
	if route_atlas.comparison_is_open():
		if not route_atlas._toggle_comparison(run_map, route_atlas._revision):
			return false
	else:
		var connections := route_atlas_close.pressed.get_connections()
		if connections.size() != 1 or connections[0].callable.get_object() != self \
				or connections[0].callable.get_method() != "_close_route_atlas":
			return false
		connections[0].callable.call()
		if is_instance_valid(route_atlas_overlay):
			return false
	key.set_meta(RunRouteAtlas.ESCAPE_CONSUMED_META, true)
	get_viewport().set_input_as_handled()
	return true


func _route_atlas_source(source_map: WeakRef, source_view: WeakRef, source_action: WeakRef) -> bool:
	return source_map != null and source_map.get_ref() == run_map and run_map != null \
		and _can_choose_connected_route() \
		and is_instance_valid(route_view) and source_view != null and source_view.get_ref() == route_view \
		and route_view.get_parent() == self and is_instance_valid(route_map_button) \
		and source_action != null and source_action.get_ref() == route_map_button \
		and route_map_button.get_parent() == route_view


func _open_route_atlas(source_map: WeakRef, source_view: WeakRef, source_action: WeakRef) -> void:
	if not _route_atlas_source(source_map, source_view, source_action) \
		or not route_view.is_visible_in_tree() or is_instance_valid(route_atlas_overlay):
		return
	route_atlas_overlay = Control.new()
	route_atlas_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(route_atlas_overlay)
	var background := Panel.new()
	background.name = "GothicAtlasBackdrop"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	route_atlas_overlay.add_child(background)
	route_atlas = RunRouteAtlas.new()
	route_atlas.position = Vector2(20, 20)
	route_atlas.bind_map(run_map)
	route_atlas_overlay.add_child(route_atlas)
	var choices := {}
	for button in route_buttons:
		choices[button.get_meta("route_id")] = weakref(button)
	# Admission clears marker controls; wait until the emitting Button has finished its signal.
	route_atlas.node_requested.connect(_choose_atlas_opening.bind(source_map, source_view,
		source_action, weakref(route_atlas_overlay), weakref(route_atlas),
		run_map.get_generation_revision(), run_map.get_floors(), choices, run_map.get_route()), CONNECT_DEFERRED)
	route_atlas_close = Button.new()
	route_atlas_close.text = "Close map"
	route_atlas_close.tooltip_text = "Return to route choices (Escape)"
	route_atlas_close.position = Vector2(520, 640)
	route_atlas_close.size = Vector2(240, 48)
	route_atlas_overlay.add_child(route_atlas_close)
	route_atlas_close.focus_next = NodePath(".")
	route_atlas_close.focus_previous = NodePath(".")
	route_atlas_close.pressed.connect(_close_route_atlas.bind(source_map, source_view,
		source_action, weakref(route_atlas_overlay)))
	route_view.hide()
	if is_instance_valid(route_book_backdrop):
		route_book_backdrop.hide()
	route_atlas_close.grab_focus()


func _choose_atlas_opening(id: String, source_map: WeakRef, source_view: WeakRef,
		source_action: WeakRef, source_overlay: WeakRef, source_atlas: WeakRef,
		generation: int, graph: Array, choices: Dictionary, prior: Array[String]) -> bool:
	if not _route_atlas_source(source_map, source_view, source_action) \
		or route_view.visible or route_map_button.disabled \
		or not is_instance_valid(route_atlas_overlay) or source_overlay == null \
		or source_overlay.get_ref() != route_atlas_overlay \
		or route_atlas_overlay.get_parent() != self or not route_atlas_overlay.is_visible_in_tree() \
		or not is_instance_valid(route_atlas) or source_atlas == null \
		or source_atlas.get_ref() != route_atlas or route_atlas.get_parent() != route_atlas_overlay \
		or not route_atlas.is_visible_in_tree() or route_atlas._map != run_map:
		return false
	if run_map.get_generation_revision() != generation or run_map.get_floors() != graph \
		or run_map.get_route() != prior \
		or not run_map.get_legal_choices().has(id) or not choices.has(id) \
		or run_map.get_node(id).get("type") not in RunMap.NORMAL_TYPES + ["Boss"]:
		return false
	var button = choices[id].get_ref()
	if not is_instance_valid(button) or not route_buttons.has(button) \
		or button.get_parent() != route_view or button.get_meta("route_id") != id \
		or button.get_meta("route_kind", "") != run_map.get_node(id).get("type") \
		or button.disabled or not button.visible:
		return false
	if (run_map.get_node(id).get("type") in ["SewingCircle", "Campfire", "PatchStall", "Unpicker"] \
		or run_map.get_node(id).get("type") == "Rest") \
		and button.get_meta("sewing_source", {}) != _sewing_context():
		return false
	var rest: bool = run_map.get_node(id).get("type") == "Rest"
	if rest and not _campfire_route_ready(id, source_map, prior, button, true):
		return false
	_clear_route_atlas()
	route_view.show()
	if is_instance_valid(route_book_backdrop):
		route_book_backdrop.show()
	button.grab_focus()
	if rest:
		return _choose_campfire_route(id, source_map, prior, button)
	return _dispatch_route(id, source_map, prior, button)


func _close_route_atlas(source_map: WeakRef, source_view: WeakRef,
		source_action: WeakRef, source_overlay: WeakRef) -> void:
	if not _route_atlas_source(source_map, source_view, source_action) \
		or route_view.visible or not is_instance_valid(route_atlas_overlay) \
		or source_overlay == null or source_overlay.get_ref() != route_atlas_overlay \
		or route_atlas_overlay.get_parent() != self:
		return
	_clear_route_atlas()
	route_view.show()
	if is_instance_valid(route_book_backdrop):
		route_book_backdrop.show()
	route_map_button.grab_focus()


func _clear_route_atlas() -> void:
	if is_instance_valid(route_atlas):
		route_atlas.bind_map(null)
	if is_instance_valid(route_atlas_overlay):
		if route_atlas_overlay.get_parent() != null:
			route_atlas_overlay.get_parent().remove_child(route_atlas_overlay)
		route_atlas_overlay.queue_free()
	route_atlas_overlay = null
	route_atlas = null
	route_atlas_close = null


func _clear_route_view() -> void:
	_clear_route_atlas()
	_clear_route_book()
	map_mend_buttons.clear()
	if is_instance_valid(route_view):
		remove_child(route_view)
		route_view.queue_free()
	route_view = null
	route_back_button = null
	route_map_button = null
	route_buttons.clear()


func _cancel_route() -> void:
	if deck != null or route_view == null:
		return
	_return_to_title()


func _cancel_opening(source_map: WeakRef, source_view: WeakRef) -> void:
	if source_map.get_ref() == run_map and source_view.get_ref() == route_view \
		and run_map != null and run_map.get_route().is_empty() \
		and is_instance_valid(route_view) and route_view.is_visible_in_tree():
		_cancel_route()


func _start_battle(shared_rng: RandomNumberGenerator = null, encounter_definitions: Array = [],
		selected_enemies: CombatEnemies = null) -> bool:
	if deck != null or (shared_rng == null and run_map != null):
		return false
	var cards := _load_starter_deck()
	if cards.is_empty():
		push_warning("Starter deck is invalid or unreadable; run was not started")
		return false
	var selector := CombatEnemyIntents.new(_load_enemy_schedule())
	if not selector.is_valid():
		return false
	if shared_rng != null:
		selector = CombatEnemyIntents.new(encounter_definitions)
	var starting_enemies := CombatEnemies.new(_load_enemy_definitions())
	if not starting_enemies.is_valid():
		return false
	if shared_rng != null:
		if selected_enemies == null:
			return false
		starting_enemies = selected_enemies
	if not selector.is_valid() or not starting_enemies.is_valid() or not _positions_align(selector, starting_enemies):
		push_warning("Starter enemies or schedule are invalid; run was not started")
		return false
	var definitions := _load_party_definitions()
	var starting_party := CombatParty.new(definitions)
	if not starting_party.is_valid():
		push_warning("Starter party definitions are invalid; run was not started")
		return false
	var starting_rng := shared_rng
	if starting_rng == null:
		starting_rng = RandomNumberGenerator.new()
		starting_rng.seed = run_seed
	# An empty deck performs no shuffle. Validate the current binding contract first.
	var starting_deck := CombatDeck.new([], starting_rng)
	var starting_result := CombatBattleResult.new(starting_party, starting_enemies)
	var starting_flow := CombatRoundFlow.new(starting_deck, starting_party,
		starting_enemies, selector, starting_result, null, null, _warden_battle_receipt(), 0)
	if not starting_flow._valid_bindings():
		push_warning("Starter combat bindings are invalid; run was not started")
		return false
	var starting_carryover: RunPartyCarryover
	var starting_outcome: RunActBattleOutcome
	if shared_rng != null:
		starting_outcome = RunActBattleOutcome.new(run_map)
		if not starting_outcome.begin_current_battle(starting_result):
			return false
		starting_carryover = RunTornCarryover.new(starting_party.get_heroes())
		if not starting_carryover.is_valid():
			return false
	var rng_before := starting_rng.state
	starting_deck.draw_pile.assign(cards)
	starting_deck._shuffle_draw_pile()
	# Opt the live fight into the authored weighted intentions and cache the
	# first announced batch before the opening hand can be played.
	if not selector.bind_battle(starting_enemies, starting_party, starting_rng):
		starting_rng.state = rng_before
		push_warning("Starter enemy intentions are invalid; run was not started")
		return false
	if not starting_flow.begin_fight():
		starting_rng.state = rng_before
		push_warning("Starter combat bindings are invalid; run was not started")
		return false
	if starting_carryover != null and not starting_carryover.begin_battle(run_map.get_current_node_id(), starting_result, starting_party):
		starting_rng.state = rng_before
		return false
	enemy_intents = selector
	enemy_attacks = enemy_intents.get_intents()
	party = starting_party
	enemies = starting_enemies
	run_rng = starting_rng
	deck = starting_deck
	run_deck = cards.duplicate()
	battle_result = starting_result
	act_outcome = starting_outcome
	party_carryover = starting_carryover
	if party_carryover != null:
		_carryover_map = weakref(run_map)
		_carryover_revision = run_map.get_generation_revision()
		_carryover_node = run_map.get_current_node_id()
		_carryover_route = run_map.get_route()
		_carryover_floors = run_map.get_floors()
		_carryover_party = party
		_carryover_result = battle_result
	round_flow = starting_flow
	victory_gold = RunVictoryGold.new(battle_result)
	session_gold = 0
	run_scraps = 0
	run_stitch_descriptors.clear()
	run_next_stitch_id = 1
	_battle_closed = false
	title_view.hide()
	_build_battle()
	_refresh_hand()
	_refresh_party()
	_refresh_enemy_roster()
	end_turn_button.grab_focus()
	return true


## Validate before allocating session objects; keep authored order for the seeded shuffle.
func _load_starter_deck() -> Array[String]:
	var file := FileAccess.open(starter_deck_path, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		return []
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Array:
		return []
	var expected := {}
	for card in StarterCards.new().get_starting_deck():
		expected[card] = expected.get(card, 0) + 1
	var actual := {}
	var cards: Array[String] = []
	for card in parser.data:
		if not card is String:
			return []
		actual[card] = actual.get(card, 0) + 1
		cards.append(card)
	if actual != expected:
		return []
	return cards


func _load_party_definitions() -> Array:
	if not FileAccess.file_exists(starter_party_path):
		return []
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(starter_party_path)) != OK:
		return []
	var source = parser.data
	if not source is Array:
		return []
	for definition in source:
		if not definition is Dictionary:
			return []
		var max_hp = definition.get("max_hp")
		# JSON numbers decode as floats; reject fractions before converting for CombatParty.
		if not (max_hp is float or max_hp is int):
			return []
		if not is_finite(float(max_hp)) or max_hp <= 0 or max_hp >= float(CombatParty.MAX_INT):
			return []
		if floor(float(max_hp)) != float(max_hp):
			return []
		for field in ["name", "art_path"]:
			if not definition.get(field) is String or definition[field].is_empty():
				return []
		definition["max_hp"] = int(max_hp)
	return source


func _load_enemy_definitions() -> Array:
	if not FileAccess.file_exists(starter_enemies_path):
		return []
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(starter_enemies_path)) != OK:
		return []
	var source = parser.data
	if not source is Array:
		return []
	for definition in source:
		if not definition is Dictionary or not _normalize_schedule_number(definition, "max_hp"):
			return []
		for field in ["name", "art_path"]:
			if not definition.get(field) is String or definition[field].is_empty():
				return []
	return source


func _positions_align(selector: CombatEnemyIntents, roster: CombatEnemies) -> bool:
	var intents := selector.get_intents()
	if intents.size() != roster.get_enemies().size():
		return false
	for index in range(intents.size()):
		if intents[index].enemy_position != index + 1:
			return false
	return true


func _load_enemy_schedule() -> Array:
	if not FileAccess.file_exists(starter_attacks_path):
		return []
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(starter_attacks_path)) != OK:
		return []
	var source = parser.data
	if not source is Array or source.is_empty():
		return []
	for definition in source:
		if not definition is Dictionary or not _normalize_schedule_number(definition, "enemy_position"):
			return []
		var pattern = definition.get("pattern")
		if not pattern is Array or pattern.is_empty():
			return []
		for action in pattern:
			if not action is Dictionary:
				return []
			var kind = action.get("type")
			if not kind is String or kind not in ["attack", "block", "buff", "debuff", "shove"]:
				return []
			if not _normalize_schedule_number(action, "amount"):
				return []
			if kind in ["attack", "shove", "debuff"] and not _normalize_schedule_number(action, "target_position"):
				return []
			if kind == "shove" and not _normalize_schedule_number(action, "direction", -1):
				return []
	# CombatEnemyIntents validates exact keys, ranges and duplicate source positions.
	return source


func _normalize_schedule_number(record: Dictionary, field: String, minimum: int = 0) -> bool:
	var value = record.get(field)
	if not (value is int or value is float):
		return false
	if not is_finite(float(value)) or floor(float(value)) != float(value):
		return false
	if value < minimum or value >= float(CombatParty.MAX_INT):
		return false
	record[field] = int(value)
	return true


func _build_battle() -> void:
	battle_view = MarginContainer.new()
	battle_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		battle_view.add_theme_constant_override("margin_" + side, 32)
	# The side-view stage owns the top of the screen edge to edge, with only a small sewn
	# seam above it; the hand and action bar keep their own rows so nothing is pushed below
	# the 720 px viewport.
	battle_view.add_theme_constant_override("margin_top", BATTLE_TOP_SEAM)
	battle_view.add_theme_constant_override("margin_bottom", 8)
	add_child(battle_view)
	var column := VBoxContainer.new()
	# Compact rows keep the large actor stage, the hero meters, five cards and the
	# action row inside 1280x720 even when every meter shows status and Bleed lines.
	column.add_theme_constant_override("separation", 2)
	battle_view.add_child(column)
	hero_view = HBoxContainer.new()
	hero_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_view.add_theme_constant_override("separation", 16)
	column.add_child(hero_view)
	for index in range(CombatParty.PARTY_SIZE):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, STAGE_ACTOR_HEIGHT)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# The battle stage shows unboxed actors: drop the shared framed panel here only,
		# so the theme keeps its boxed look on every other screen.
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		hero_view.add_child(panel)
		hero_panels.append(panel)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 22)
		panel.add_child(label)
	intent_label = Label.new()
	intent_label.add_theme_font_size_override("font_size", 22)
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var intent_column := VBoxContainer.new()
	intent_column.add_theme_constant_override("separation", 4)
	column.add_child(intent_column)
	intent_column.add_child(intent_label)
	enemy_buff_forecast_label = Label.new()
	enemy_buff_forecast_label.name = "EnemyBuffForecast"
	enemy_buff_forecast_label.add_theme_font_size_override("font_size", 18)
	enemy_buff_forecast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_column.add_child(enemy_buff_forecast_label)
	_refresh_intents()
	result_label = Label.new()
	result_label.name = "BattleResult"
	result_label.add_theme_font_size_override("font_size", 28)
	result_label.hide()
	column.add_child(result_label)
	var pile_row := HBoxContainer.new()
	pile_row.name = "PileCounts"
	pile_row.add_theme_constant_override("separation", 24)
	# Cards and the compact action stack share the lower band. The orb keeps its
	# full size, while actions use the space beside the hand instead of a third row.
	var tray := HBoxContainer.new()
	tray.name = "BattleLowerTray"
	tray.add_theme_constant_override("separation", 16)
	column.add_child(tray)
	var cards := VBoxContainer.new()
	cards.name = "BattleCardsColumn"
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The fan rotates the outer cards a few pixels beyond the unrotated row.
	cards.add_theme_constant_override("separation", 10)
	tray.add_child(cards)
	var help_slot := VBoxContainer.new()
	help_slot.name = "BattleHandDisclosureSlot"
	help_slot.hide()
	cards.add_child(help_slot)
	var information := HBoxContainer.new()
	information.name = "BattleHandInformation"
	information.add_theme_constant_override("separation", 16)
	cards.add_child(information)
	information.add_child(pile_row)
	enemy_buff_forecast_label.reparent(information)
	enemy_buff_forecast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_label = Label.new()
	pile_row.add_child(pile_label)
	# The transient forecast owns the row directly above the hand, so a shown
	# strip yields stage height without ever moving the card row.
	_mount_combo_cue(cards)
	hand_view = HBoxContainer.new()
	hand_view.name = "SharedHand"
	hand_view.custom_minimum_size.y = HAND_CARD_HEIGHT
	# The stage above owns the free vertical space; the card row keeps its own height.
	hand_view.size_flags_vertical = Control.SIZE_FILL
	hand_view.add_theme_constant_override("separation", 16)
	hand_view.sort_children.connect(_fan_hand, CONNECT_DEFERRED)
	cards.add_child(hand_view)
	var sidebar := VBoxContainer.new()
	sidebar.name = "BattleActionStack"
	sidebar.add_theme_constant_override("separation", 2)
	tray.add_child(sidebar)
	var support_hud := HBoxContainer.new()
	support_hud.name = "SupportHUD"
	support_hud.custom_minimum_size.y = 76
	support_hud.add_theme_constant_override("separation", 16)
	sidebar.add_child(support_hud)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 2)
	sidebar.add_child(actions)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.custom_minimum_size = Vector2(240, 48)
	end_turn_button.pressed.connect(_end_turn.bind(end_turn_button))
	actions.add_child(end_turn_button)
	_build_action_corner(actions)
	_refresh_action_focus()


## Secondary actions share one small sewn felt corner; End Turn stays the large control.
func _build_action_corner(actions: Container) -> void:
	action_corner = ActionCorner.new()
	action_corner.name = "BattleActionCorner"
	action_corner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(action_corner)
	action_corner_row = HBoxContainer.new()
	action_corner_row.name = "BattleActionCornerRow"
	action_corner_row.add_theme_constant_override("separation", 8)
	action_corner.add_child(action_corner_row)
	var stitch := ActionCornerStitch.new()
	stitch.name = "BattleActionCornerStitch"
	action_corner.add_child(stitch)
	return_button = Button.new()
	return_button.text = "Return"
	return_button.custom_minimum_size = SECONDARY_ACTION_SIZE
	return_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return_button.tooltip_text = "Return to title"
	return_button.pressed.connect(_return_from_battle.bind(return_button))
	action_corner_row.add_child(return_button)
	_mount_juice_action(action_corner_row)


## Presentation hook: the battle-independent juice node owns its Fast toggle button.
func _mount_juice_action(corner: HBoxContainer) -> void:
	var juice = get_node_or_null("LiveCombatJuice")
	if juice != null:
		juice.attach_fast_button(corner)


## Rebuilds the forward/reverse Tab loops for every mounted action state: the live
## turn, a won or lost fight, and the routed reward with its Continue control.
func _refresh_action_focus() -> void:
	var actions: Array[Button] = []
	if is_instance_valid(end_turn_button) and not end_turn_button.disabled:
		actions.append(end_turn_button)
	if is_instance_valid(return_button) and not return_button.disabled:
		actions.append(return_button)
	var juice = get_node_or_null("LiveCombatJuice")
	if not _battle_closed and juice != null and is_instance_valid(juice.fast_button) \
			and not juice.fast_button.disabled:
		actions.append(juice.fast_button)
	for button in reward_buttons:
		if is_instance_valid(button) and not button.disabled:
			actions.append(button)
	if is_instance_valid(continue_button) and not continue_button.disabled:
		actions.append(continue_button)
	for index in range(actions.size()):
		actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
		actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])


## Routed rewards are prepared once; the standalone demo keeps its fixed offering.
## Both routed services receive the authored D2-1 base records of party-owned
## heroes, so the live pick is the accepted weighted selector, never a starter
## fallback, plus the run's current Rest stitch ledger so an authentic composite
## already owned at a Rest stays a legal run deck member.
func _build_card_reward() -> void:
	if not _battle_closed or battle_result == null or battle_result.get_outcome() != CombatBattleResult.VICTORY:
		return
	if run_map != null and (not _current_carryover_fight() \
		or run_map.get_node(_carryover_node).get("type") not in ["Fight", "Elite"]):
		return
	if run_map != null and (fight_rewards != null or multi_fight_rewards != null):
		return
	var offers: Array = []
	var party_ids: Array[String] = []
	for hero in party.get_heroes():
		party_ids.append(hero.id)
	var catalog := StarterCards.new()
	var ids: Array = INTERIM_REWARD_IDS
	if run_map != null:
		var records := _reward_candidate_records(party_ids)
		var prepared: Dictionary
		if _carryover_route.size() == 1 and run_map.get_node(_carryover_node).get("type") == "Fight":
			if not party_carryover.read_state().completed_fights.has(_carryover_node):
				return
			fight_rewards = RunFightVictoryRewards.new(battle_result, run_rng, party_ids,
				records, run_deck, session_gold, false, [], [],
				run_stitch_descriptors, run_next_stitch_id)
			prepared = fight_rewards.prepare()
		else:
			var patch_ids := _catalog_trinket_ids()
			if patch_ids.is_empty():
				return
			multi_fight_rewards = RunMultiFightRewards.new(run_map, run_rng, party_carryover,
				run_deck, session_gold, run_trinkets, records, patch_ids,
				run_stitch_descriptors, run_next_stitch_id)
			prepared = multi_fight_rewards.prepare(_carryover_node, battle_result, party)
		if not prepared.ok:
			fight_rewards = null
			multi_fight_rewards = null
			return
		fight_reward_offers = prepared.offers
		fight_reward_gold = prepared.gold_award
		fight_reward_trinket = prepared.trinket_drop_id
		_reward_map = weakref(run_map)
		_mount_reward_choice(prepared)
		return
	for id in ids:
		var definition := catalog.get_definition(id)
		if definition.get("id") != id or not party_ids.has(definition.get("owner")):
			return
		offers.append(definition)
	if run_map == null:
		card_reward = RunCardRewardChoice.new(offers, party_ids)
		if not card_reward.is_valid():
			card_reward = null
			return
	var column := HBoxContainer.new()
	column.name = "CardReward"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_view.add_child(column)
	var heading := Label.new()
	heading.text = "Card reward:"
	column.add_child(heading)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 16)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(choices)
	for index in range(4):
		var id: String = ids[index] if index < 3 else ""
		var button := Button.new()
		button.text = "Skip"
		if not id.is_empty():
			var definition := catalog.get_definition(id)
			button.text = "%s - %s" % [definition.owner.capitalize(), definition.display_name]
			if run_map != null:
				button.text = "%s\n%s" % [definition.owner, id]
		button.custom_minimum_size = Vector2(0, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.add_child(button)
		reward_buttons.append(button)
		button.pressed.connect(_claim_card_reward.bind(id, button, _routed_reward_service() if run_map != null else card_reward))


func _mount_reward_choice(prepared: Dictionary) -> void:
	reward_choice_panel = load("res://scenes/run_card_reward_choice_panel.tscn").instantiate()
	add_child(reward_choice_panel)
	if not reward_choice_panel.open_rewards(_carryover_node,
		run_map.get_node(_carryover_node).type, prepared):
		_clear_reward_choice()
		return
	reward_buttons = reward_choice_panel.get_choice_buttons()
	for button in reward_buttons:
		var callback: Callable = button.pressed.get_connections()[0].callable
		button.pressed.disconnect(callback)
		button.pressed.connect(_forward_reward_choice.bind(weakref(reward_choice_panel), callback))
	# Existing post-claim Elite presentation mounts beside this empty reward slot.
	var slot := HBoxContainer.new()
	slot.name = "CardReward"
	slot.add_child(Label.new())
	hand_view.add_child(slot)
	reward_choice_panel.choice_requested.connect(_request_routed_reward.bind(
		weakref(reward_choice_panel), _routed_reward_service()))
	_reward_return_parent = weakref(return_button.get_parent())
	return_button.reparent(reward_choice_panel)
	return_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	return_button.custom_minimum_size = SECONDARY_ACTION_SIZE
	return_button.position = Vector2(20, 666)
	return_button.size = SECONDARY_ACTION_SIZE
	return_button.focus_next = return_button.get_path_to(reward_buttons[0])
	return_button.focus_previous = return_button.get_path_to(reward_buttons[3])


func _forward_reward_choice(source: WeakRef, callback: Callable) -> void:
	if source != null and source.get_ref() == reward_choice_panel \
		and is_instance_valid(reward_choice_panel) and reward_choice_panel.get_parent() == self \
		and reward_choice_panel.is_visible_in_tree() and callback.is_valid():
		callback.call()


func _request_routed_reward(node_id: String, id: String, source: WeakRef, offering) -> void:
	if not is_instance_valid(reward_choice_panel) or source == null \
		or source.get_ref() != reward_choice_panel or reward_choice_panel.get_parent() != self \
		or not reward_choice_panel.is_visible_in_tree() or not reward_choice_panel._awaiting_ack \
		or reward_choice_panel._accepted:
		return
	var accepted: bool = node_id == _carryover_node and reward_choice_panel._node_id == node_id \
		and _settle_routed_reward(id, offering)
	reward_choice_panel.acknowledge(accepted)
	if accepted:
		reward_choice_panel.paper_panel.hide()
		reward_choice_panel.get_node("SlateBackdrop").hide()
		reward_choice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _clear_reward_choice() -> void:
	if is_instance_valid(reward_choice_panel):
		if is_instance_valid(return_button) and return_button.get_parent() == reward_choice_panel \
			and _reward_return_parent != null and is_instance_valid(_reward_return_parent.get_ref()):
			return_button.reparent(_reward_return_parent.get_ref())
		reward_choice_panel.close_rewards()
		if reward_choice_panel.get_parent() != null:
			reward_choice_panel.get_parent().remove_child(reward_choice_panel)
		reward_choice_panel.queue_free()
	reward_choice_panel = null
	_reward_return_parent = null
	if run_map != null:
		reward_buttons.clear()


## Weighted D2-1 candidates: every authored base (never '+') pool record whose
## hero is in this party. Empty on malformed catalogs, which fails preparation
## closed instead of inventing an unweighted starter offering.
func _reward_candidate_records(party_ids: Array[String]) -> Array:
	var records: Array = []
	for record: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
		var id: Variant = record.get("id")
		var owner: Variant = record.get("owner")
		var rarity: Variant = record.get("rarity")
		if not id is String or not owner is String or not rarity is String:
			return []
		if not party_ids.has(owner):
			continue
		records.append({"id": id, "owner": owner, "rarity": rarity})
	return records


## Elite drops use the existing Shop catalog; no separate reward pool.
func _validated_patch_candidates(entries: Variant) -> Array:
	if not entries is Array or entries.is_empty():
		return []
	var definitions := RunAuthoredPatchDefinitions.load_definitions()
	var authority := RunPatchWearerSummary._authority({})
	if definitions.is_empty() or authority.is_empty():
		return []
	var slots := {}
	for definition in definitions:
		slots[definition.id] = definition.slot
	var seen := {}
	for entry in entries:
		if not entry is Dictionary or not entry.get("id") is String:
			return []
		var id: String = entry.id
		if not slots.has(id) or authority.slots.get(id) != slots[id] or seen.has(id) \
			or not (entry.get("price") is int or entry.get("price") is float) \
			or entry.price != 100:
			return []
		seen[id] = true
	return entries.duplicate(true)


func _catalog_trinket_ids() -> Array:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	if not catalog is Dictionary:
		return []
	var ids: Array = []
	for entry in _validated_patch_candidates(catalog.get("trinkets")):
		ids.append(entry.id)
	return ids


func _routed_reward_service():
	return multi_fight_rewards if multi_fight_rewards != null else fight_rewards


func _settle_routed_reward(id: String, offering) -> bool:
	if offering != _routed_reward_service() or fight_reward_claimed or _reward_map == null \
		or _reward_map.get_ref() != run_map or run_map == null or not _battle_closed \
		or not _current_carryover_fight() \
		or battle_result == null or battle_result._party != party or battle_result._enemies != enemies \
		or battle_result.get_outcome() != CombatBattleResult.VICTORY \
		or party == null or not party.is_valid() or party.is_defeated() \
		or not is_instance_valid(reward_choice_panel) or not reward_choice_panel._awaiting_ack:
		return false
	if fight_reward_offers.size() != 3 or (not id.is_empty() and not fight_reward_offers.any(
		func(offer: Dictionary) -> bool: return offer.id == id)):
		return false
	if offering is RunFightVictoryRewards:
		if offering._battle != battle_result or offering._rng != run_rng \
			or offering._source_deck != run_deck or offering._starting_gold != session_gold \
			or offering._owned_trinket_ids != run_trinkets \
			or offering._stitched_descriptors != run_stitch_descriptors \
			or offering._next_stitch_id != run_next_stitch_id:
			return false
	if offering is RunMultiFightRewards:
		if offering._map != run_map or offering._rng != run_rng or offering._carry != party_carryover \
			or offering.read_state().deck != run_deck or offering.read_state().gold != session_gold \
			or offering.read_state().party.heroes != run_heroes \
			or offering.read_state().trinkets != run_trinkets \
			or offering._stitched_descriptors != run_stitch_descriptors \
			or offering._next_stitch_id != run_next_stitch_id:
			return false
	var torn_carry := party_carryover as RunTornCarryover
	if torn_carry == null or torn_carry.read_state().heroes != run_heroes \
		or torn_carry.preview_reward(_carryover_node, battle_result, party) == null:
		return false
	var result: Dictionary = offering.choose(_carryover_node, id) if offering is RunMultiFightRewards else offering.choose(id)
	if not result.ok:
		return false
	var carried := torn_carry.apply_reward(_carryover_node, battle_result, party)
	if not carried.ok:
		return false
	var settled: Dictionary = result.state if offering is RunMultiFightRewards else result
	run_deck.assign(settled.deck)
	session_gold = settled.gold
	if offering is RunMultiFightRewards:
		run_trinkets.assign(settled.trinkets)
	run_heroes = carried.heroes.duplicate(true)
	run_scraps += 2 if run_map.get_node(_carryover_node).get("type") == "Elite" else 1
	_sync_bound_wardrobe(torn_carry)
	fight_reward_claimed = true
	result_label.text = "Battle result: victory | Gold: %d" % session_gold
	_finish_card_reward(offering)
	$LiveElitePatchSewing.observe_claim(offering, result)
	return true

## A confirmed routed reward publishes new run resources. A wardrobe bound at an
## earlier routed Shop receives exactly those committed values through its own
## snapshot guard, so the same object, worn slots and operation IDs carry on
## while unsolicited ledger drift still fails closed.
func _sync_bound_wardrobe(carry: RunTornCarryover) -> void:
	if carry == null:
		return
	var wardrobe := carry._wardrobe
	if wardrobe == null or not wardrobe.is_valid():
		return
	wardrobe.refresh_run_context(run_heroes, run_trinkets, run_scraps,
		session_gold, run_deck, wardrobe.get_snapshot())


func _claim_card_reward(id: String, button, offering) -> void:
	if offering is RunFightVictoryRewards or offering is RunMultiFightRewards:
		return
	if offering == null or offering != card_reward or not _battle_closed \
			or battle_result == null or battle_result.get_outcome() != CombatBattleResult.VICTORY \
			or not is_instance_valid(button) or button not in reward_buttons \
			or button.disabled or not button.is_visible_in_tree():
		return
	var index := reward_buttons.find(button)
	if id != (INTERIM_REWARD_IDS[index] if index < 3 else ""):
		return
	# Revalidate actual catalog ownership, beyond the transaction's structural checks.
	var party_ids: Array[String] = []
	for hero in party.get_heroes():
		party_ids.append(hero.id)
	var catalog := StarterCards.new()
	for offered_id in INTERIM_REWARD_IDS:
		var definition := catalog.get_definition(offered_id)
		if definition.get("id") != offered_id or not party_ids.has(definition.get("owner")):
			return
	var result: Dictionary = offering.claim(run_deck, id)
	if not result.ok:
		return
	run_deck = result.deck
	_finish_card_reward(offering)


func _finish_card_reward(offering) -> void:
	for action in reward_buttons:
		action.disabled = true
	if run_map != null:
		continue_button = Button.new()
		continue_button.text = "Continue"
		continue_button.custom_minimum_size = Vector2(160, 48)
		return_button.get_parent().add_child(continue_button)
		continue_button.pressed.connect(_continue_to_rest_route.bind(offering, weakref(run_map), continue_button))
		continue_button.position = Vector2(1000, 666)
		continue_button.size = Vector2(240, 48)
		continue_button.focus_next = continue_button.get_path_to(return_button)
		return_button.focus_next = return_button.get_path_to(continue_button)
	_refresh_action_focus()
	return_button.grab_focus()


## The terminal Fight stays separate from persistent run data and future encounters.
func _can_leave_fight() -> bool:
	return _current_carryover_fight() \
		and run_map.get_node(run_map.get_current_node_id()).get("type") in ["Fight", "Elite"] \
		and _battle_closed and battle_result != null \
		and battle_result._party == party and battle_result._enemies == enemies \
		and battle_result.get_outcome() == CombatBattleResult.VICTORY \
		and party != null and party.is_valid() and not party.is_defeated() \
		and _routed_reward_service() != null and fight_reward_claimed \
		and party_carryover != null and party_carryover.read_state().heroes == run_heroes \
		and (multi_fight_rewards == null or (party_carryover.read_state().completed_fights.has(_carryover_node) \
			and party_carryover.read_state().heroes == run_heroes \
			and multi_fight_rewards.read_state().trinkets == run_trinkets)) \
		and RunRestRecovery._is_valid_roster(run_heroes)


func _continue_to_rest_route(offering, source_map: WeakRef, button) -> void:
	if not _can_leave_fight() or offering != _routed_reward_service() or source_map == null \
		or source_map.get_ref() != run_map or not is_instance_valid(button) \
		or button != continue_button or button.disabled or not button.is_visible_in_tree() \
		or is_instance_valid(route_view) or (is_instance_valid(rest_view) and rest_view.visible):
		return
	button.disabled = true
	_clear_reward_choice()
	battle_view.hide()
	_present_connected_route(source_map)


func _present_connected_route(source_map: WeakRef) -> void:
	_connected_map = source_map
	_connected_route = run_map.get_route()
	# Only legitimate visit completion refreshes committed run resources. Rejected
	# input callbacks must never repair a drifted wardrobe or roster.
	var carry := party_carryover as RunTornCarryover
	if carry != null and carry._wardrobe != null and _can_choose_connected_route():
		var wardrobe := carry._wardrobe
		wardrobe.refresh_run_context(run_heroes, run_trinkets, run_scraps,
			session_gold, run_deck, wardrobe.get_snapshot())
	_mount_route_book()
	var book := route_book_backdrop
	var current := run_map.get_node(run_map.get_current_node_id())
	var floor_number := int(current.get("floor", 0))
	var area := RunRouteAtlas.area_for_floor(floor_number)
	book.get_node("AreaCue").text = area
	book.get_node("AreaCue").set_meta("area_name", area)
	book.get_node("FloorCue").text = "Floor %02d" % floor_number
	book.get_node("FloorCue").set_meta("floor_number", floor_number)
	var page := RouteBook.choices_rect()
	route_view = Control.new()
	route_view.name = "ConnectedBookChoices"
	route_view.position = page.position
	route_view.size = page.size
	add_child(route_view)
	var heading := Label.new()
	heading.text = "Choose your next stop"
	heading.size = Vector2(page.size.x, 34)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", ROUTE_BOOK_INK)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_view.add_child(heading)
	var branches := RouteBranches.new()
	route_view.add_child(branches)
	var targets: Array[Rect2] = []
	var prior := run_map.get_route()
	for choice in _authenticated_route_choices(run_map, RunV3StopChoiceProjection.project_legal_choices(run_map)):
		var id: String = choice.id
		var node := run_map.get_node(id)
		var action := _route_choice_button(id, String(node.type), false, choice)
		# Four legal patches fit above up to three direct-child Mend quotes.
		action.custom_minimum_size = Vector2(ROUTE_PATCH_SIZE.x, 54)
		action.size = action.custom_minimum_size
		action.position = Vector2(ROUTE_PATCH_LEFT, 42 + route_buttons.size() * 58)
		action.pressed.connect(_dispatch_route.bind(id, source_map, prior, action))
		route_view.add_child(action)
		route_buttons.append(action)
		targets.append(Rect2(action.position, action.size))
	branches.branch_targets = targets
	var context := _map_mend_context()
	var mends := _project_map_mends()
	if mends.get("ok") == true:
		for option in mends.options:
			var mend := _route_book_action("", Vector2(432, 40), "Mend this torn hero")
			mend.text = "Mend %s (position %d) - %d scraps, to %d HP" % [
				String(option.hero_id).capitalize(), option.position,
				option.cost, option.post_mend_hp]
			mend.set_meta("hero_id", option.hero_id)
			mend.set_meta("hero_position", option.position)
			mend.set_meta("mend_option", option.duplicate(true))
			mend.custom_minimum_size = Vector2(440, 40)
			mend.disabled = option.affordable != true or not _can_choose_connected_route()
			route_view.add_child(mend)
			map_mend_buttons.append(mend)
			mend.pressed.connect(_choose_map_mend.bind(option.hero_id, option.position,
				weakref(mend), weakref(route_view), context))
		if map_mend_buttons.is_empty():
			_append_map_mend_unavailable("Mend unavailable - no torn heroes")
	else:
		_append_map_mend_unavailable("Mend unavailable - invalid source")
	for index in range(map_mend_buttons.size()):
		var mend := map_mend_buttons[index]
		mend.custom_minimum_size = Vector2(432, 40)
		mend.size = mend.custom_minimum_size
		mend.position = Vector2(0, 280 + index * 44)
	_present_route_patch_summary(carry)
	route_map_button = _route_book_action("View full map", Vector2(210, 44), "Open the optional full map")
	route_map_button.position = Vector2(0, 510)
	route_view.add_child(route_map_button)
	route_map_button.pressed.connect(_open_route_atlas.bind(
		weakref(run_map), weakref(route_view), weakref(route_map_button)))
	route_back_button = _route_book_action("Return to title", Vector2(210, 44), "Leave this run")
	route_back_button.position = Vector2(222, 510)
	route_back_button.pressed.connect(_return_from_visit.bind(route_view))
	route_view.add_child(route_back_button)
	var actions: Array[Control] = []
	for button in route_buttons + map_mend_buttons:
		if not button.disabled:
			actions.append(button)
	actions.append(route_view.get_node("PatchSummaryScroll"))
	actions.append(route_map_button)
	actions.append(route_back_button)
	for index in range(actions.size()):
		actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
		actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])
	actions[0].grab_focus()


func _present_route_patch_summary(carry: RunTornCarryover) -> void:
	var scroll := route_view.get_node_or_null("PatchSummaryScroll") as ScrollContainer
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "PatchSummaryScroll"
		scroll.position = Vector2(0, 416)
		scroll.size = Vector2(432, 82)
		scroll.focus_mode = Control.FOCUS_ALL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.tooltip_text = "Sewn patches - scroll to read all wearers"
		scroll.gui_input.connect(func(event: InputEvent):
			if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
				scroll.scroll_vertical += 40 if event.is_action_pressed("ui_down") else -40
				scroll.accept_event())
		route_view.add_child(scroll)
	var readout := HBoxContainer.new()
	readout.name = "PatchWearerSummary"
	readout.add_theme_constant_override("separation", 12)
	scroll.add_child(readout)
	var unavailable := ""
	var summary: Dictionary = {}
	if carry == null:
		unavailable = "Patches unavailable - no carryover"
	elif carry.torn == null:
		unavailable = "Patches unavailable - invalid source"
	elif carry._wardrobe == null:
		# A pre-Shop run legitimately owns nothing yet. Owned patches without a
		# bound wardrobe, or a corrupted ledger, must never look empty.
		if not run_trinkets.is_empty():
			unavailable = "Patches unavailable - no wardrobe bound"
		elif not carry.is_valid() or carry._observer() == null:
			unavailable = "Patches unavailable - invalid source"
		else:
			var empty_message := Label.new()
			empty_message.text = "No patches sewn"
			readout.add_child(empty_message)
			return
	else:
		summary = RunPatchWearerSummary.summarize(carry._wardrobe, carry.torn.read_state())
		if not summary.ok:
			unavailable = "Patches unavailable - invalid source"
	if not unavailable.is_empty():
		var message := Label.new()
		message.text = unavailable
		readout.add_child(message)
		return
	for hero in summary.heroes:
		var status := Label.new()
		status.set_meta("hero_id", hero.id)
		status.custom_minimum_size.x = 132
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.add_theme_font_size_override("font_size", 14)
		status.text = "%s - patches" % hero.id.capitalize()
		for slot in hero.slots:
			var worn: String = "empty"
			if not slot.patch_id.is_empty():
				worn = "%s (%s)" % [slot.patch_id, "active" if slot.active else "inactive"]
				# Only the validated, nonempty text supplied by the service is
				# shown; slot-only patches never gain invented rules.
				if not slot.rules_text.is_empty():
					worn += " - %s" % slot.rules_text
			status.text += "\n%s: %s" % [slot.slot, worn]
		readout.add_child(status)


func _append_map_mend_unavailable(message: String) -> void:
	var unavailable := _route_book_action(message, Vector2(432, 40), message)
	unavailable.disabled = true
	unavailable.custom_minimum_size = Vector2(440, 40)
	route_view.add_child(unavailable)
	map_mend_buttons.append(unavailable)


## The canonical map Mend projection owns hero, slot, cost and post-Mend HP.
## The view only renders those values; an invalid live authority yields nothing
## actionable instead of a re-derived price or healing rule.
func _project_map_mends() -> Dictionary:
	var carry := party_carryover as RunTornCarryover
	if carry == null:
		return {"ok": false, "options": []}
	var wardrobe: Variant = null
	if carry._wardrobe != null:
		wardrobe = carry._wardrobe.get_snapshot()
	return RunMapMendChoices.project(carry, carry.read_state(), wardrobe, run_scraps, true)


func _map_mend_context() -> Array:
	var carry := party_carryover as RunTornCarryover
	if carry == null or run_map == null or run_rng == null:
		return []
	return [run_map, run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route(),
		run_rng, run_rng.state, carry, carry.read_state(), carry.torn.read_state(),
		run_heroes.duplicate(true), run_scraps, session_gold, run_deck.duplicate(),
		run_trinkets.duplicate(), carry._wardrobe,
		null if carry._wardrobe == null else carry._wardrobe.get_snapshot(),
		fight_reward_claimed, _routed_reward_service(), act_outcome.get_state(),
		run_stitch_descriptors.duplicate(true), run_next_stitch_id, run_removal_count, _map_mend_serial]


func _choose_map_mend(hero: Variant, position: Variant, source_action: WeakRef,
		source_view: WeakRef, expected: Array) -> void:
	if not _can_choose_connected_route() or not is_instance_valid(route_view) \
		or source_view == null or source_view.get_ref() != route_view \
		or route_view.get_parent() != self or not route_view.is_visible_in_tree() \
		or source_action == null or not is_instance_valid(source_action.get_ref()) \
		or expected.is_empty() or _map_mend_context() != expected \
		or typeof(hero) != TYPE_STRING or typeof(position) != TYPE_INT:
		return
	var button = source_action.get_ref()
	if button not in map_mend_buttons or button.get_parent() != route_view \
		or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("hero_id", "") != hero or button.get_meta("hero_position", 0) != position:
		return
	var carry := party_carryover as RunTornCarryover
	# Reproject from the live authority: only an exact offered option (identity
	# AND slot) may name a canonical price or post-Mend HP.
	var view := _project_map_mends()
	if carry == null or view.get("ok") != true:
		return
	var option: Dictionary = {}
	for offered in view.options:
		if offered.get("hero_id") == hero and offered.get("position") == position:
			option = offered
			break
	if option.is_empty() or button.get_meta("mend_option", {}) != option:
		return
	var wardrobe: Variant = null
	if carry._wardrobe != null:
		wardrobe = carry._wardrobe.get_snapshot()
	var operation := "map_mend:%d" % _map_mend_serial
	var result := RunMapMendChoices.choose(carry, option, operation, operation + ":receipt",
		carry.read_state(), wardrobe, run_scraps, true)
	if result.get("ok") != true:
		return
	run_heroes = result.heroes
	run_scraps = result.remaining_scraps
	_map_mend_serial += 1
	# The completed visit's original wallet/hero guards describe its own
	# transaction. Preserve admission for this exact subsequent map transaction.
	_mended_route_context = _map_mend_context()
	var source := _connected_map
	_clear_route_view()
	_present_connected_route(source)


## Zero completed fights is legal only for this run's witnessed noncombat prefix.
func _unfought_run() -> bool:
	var carry := party_carryover as RunTornCarryover
	if carry == null or not carry.is_valid() or run_map == null or run_rng == null \
		or _carryover_map == null or _carryover_map.get_ref() != run_map \
		or _carryover_revision != run_map.get_generation_revision() \
		or _carryover_floors != run_map.get_floors() or deck != null or battle_result != null \
		or is_instance_valid(battle_view) or not carry._node.is_empty() \
		or carry.read_state().heroes != run_heroes or not carry.read_state().completed_fights.is_empty() \
		or carry._observer() == null or act_outcome == null or act_outcome._map != run_map \
		or act_outcome.get_state() != {"run_status": RunActBattleOutcome.ACTIVE,
			"pending_node_id": "", "settled_node_ids": []} or act_outcome._pending_result != null:
		return false
	for id in run_map.get_route():
		if run_map.get_node(id).get("type") not in ["Rest", "Shop", "Event", "Treasure", "SewingCircle", "Campfire", "PatchStall", "Unpicker"]:
			return false
		if run_map.get_node(id).get("type") == "Shop":
			var prefix := run_map.get_route().slice(0, run_map.get_route().find(id) + 1)
			var witness: Array = _peddler_witnesses.get(id, [])
			if witness.size() != 7 or witness.slice(0, 4) != [run_map, run_map.get_generation_revision(), run_map.get_floors(), prefix] \
				or not witness[4] is RunPeddlerVisit or not witness[4].is_consumed() \
				or witness[4].read_state() != witness[5] or witness[6].get("ok") != true:
				return false
		if run_map.get_node(id).get("type") == "PatchStall":
			var prefix := run_map.get_route().slice(0, run_map.get_route().find(id) + 1)
			if _patch_stall_visits.get(id, []) != [run_map, run_map.get_generation_revision(), run_map.get_floors(), prefix]:
				return false
		if run_map.get_node(id).get("type") == "Unpicker":
			var prefix := run_map.get_route().slice(0, run_map.get_route().find(id) + 1)
			if _unpicker_visits.get(id, []) != [run_map, run_map.get_generation_revision(), run_map.get_floors(), prefix]:
				return false
		if run_map.get_node(id).get("type") == "Campfire" or (run_map.get_node(id).get("type") == "Rest" \
			and (_campfire_visits.has(id) or _opening_rest(id, run_map.get_route().slice(0, run_map.get_route().find(id))))):
			var prefix := run_map.get_route().slice(0, run_map.get_route().find(id) + 1)
			if _campfire_visits.get(id, []) != [run_map, run_map.get_generation_revision(), run_map.get_floors(), prefix]:
				return false
		elif run_map.get_node(id).get("type") == "Rest":
			var prefix := run_map.get_route().slice(0, run_map.get_route().find(id) + 1)
			if _legacy_rest_visits.get(id, []) != [run_map, run_map.get_generation_revision(), run_map.get_floors(), prefix] \
				and not (run_map.get_current_node_id() == id and _current_completed_rest()):
				return false
		if run_map.get_node(id).get("type") == "SewingCircle":
			var prefix := run_map.get_route().slice(0, run_map.get_route().find(id) + 1)
			if _sewing_visits.get(id, []) != [run_map, run_map.get_generation_revision(), run_map.get_floors(), prefix]:
				return false
	if run_map.get_route().is_empty():
		return not _party_receipt.is_empty() and run_deck == _party_receipt.deck \
			and carry._initial == CombatParty.new(_party_receipt.party).get_heroes() and run_heroes == carry._initial \
			and carry.read_state().completed_rests.is_empty() and LiveWebPlaytestBoot.has_opening_wallet(self) \
			and run_trinkets.is_empty() and run_removal_count == 0 \
			and run_stitch_descriptors.is_empty() and run_next_stitch_id == 1
	return true


## Only the gate's paid, claimed, same-node request may borrow the Campfire
## completion guard; an ordinary Event never becomes a free Rest.
func _emberglass_campfire_active(id: String) -> bool:
	if _emberglass_campfire_auth.size() != 6 or run_map == null:
		return false
	var gate: RunV3ServiceWaystationEventGate = _emberglass_campfire_auth[5]
	var paid_choices := {"v3_emberglass_campfire": "light_the_embers",
		"v3_briar_button_mending_bench": "fuel_button_fire"}
	return gate != null and gate.is_claimed() \
		and paid_choices.get(gate.get_event_id(), "") == gate.get_service_choice_id() \
		and gate.get_service_kind() == "Campfire" \
		and _emberglass_campfire_auth.slice(0, 5) == [run_map,
			run_map.get_generation_revision(), run_map.get_floors(),
			run_map.get_route(), id] \
		and run_map.get_current_node_id() == id \
		and run_map.get_node(id).get("type") == "Event"


## A claimed Inkblack hire grants exactly one on-Event Unpicker, not a new node.
func _inkblack_unpicker_active(id: String) -> bool:
	if _inkblack_unpicker_auth.size() != 6 or run_map == null:
		return false
	var gate: RunV3ServiceWaystationEventGate = _inkblack_unpicker_auth[5]
	return gate != null and gate.is_claimed() \
		and gate.get_event_id() == "v3_inkblack_unpicker_van" \
		and gate.get_service_choice_id() == "hire_unpicker" \
		and gate.get_service_kind() == "Unpicker" \
		and _inkblack_unpicker_auth.slice(0, 5) == [run_map,
			run_map.get_generation_revision(), run_map.get_floors(),
			run_map.get_route(), id] \
		and run_map.get_current_node_id() == id \
		and run_map.get_node(id).get("type") == "Event"


## A claimed Threadmill borrow grants exactly one on-Event Sewing Circle, not a new node.
func _threadmill_sewing_active(id: String) -> bool:
	if _threadmill_sewing_auth.size() != 6 or run_map == null:
		return false
	var gate: RunV3ServiceWaystationEventGate = _threadmill_sewing_auth[5]
	return gate != null and gate.is_claimed() \
		and gate.get_event_id() == "v3_threadmill_sewing_circle" \
		and gate.get_service_choice_id() == "borrow_spools" \
		and gate.get_service_kind() == "SewingCircle" \
		and _threadmill_sewing_auth.slice(0, 5) == [run_map,
			run_map.get_generation_revision(), run_map.get_floors(),
			run_map.get_route(), id] \
		and run_map.get_current_node_id() == id \
		and run_map.get_node(id).get("type") == "Event"


func _can_choose_connected_route() -> bool:
	if is_instance_valid(debt_booth_panel):
		return false
	if is_instance_valid(frayed_debt_panel):
		return false
	if is_instance_valid(fate_pin_panel):
		return false
	if is_instance_valid(needle_toll_panel):
		return false
	if is_instance_valid(quiet_spool_panel) or is_instance_valid(moth_panel) \
		or is_instance_valid(dye_vat_panel) or is_instance_valid(wallet_event_panel):
		return false
	if run_map == null or _connected_map == null or _connected_map.get_ref() != run_map \
		or run_map.get_route() != _connected_route or not RunRestRecovery._is_valid_roster(run_heroes) \
		or act_outcome == null or act_outcome._map != run_map \
		or act_outcome.get_state().run_status != RunActBattleOutcome.ACTIVE \
		or not act_outcome.get_state().pending_node_id.is_empty() or act_outcome._pending_result != null:
		return false
	if party_carryover == null or not party_carryover.is_valid() \
		or party_carryover.read_state().heroes != run_heroes:
		return false
	if not _mended_route_context.is_empty() and _mended_route_context == _map_mend_context():
		return true
	if party_carryover.read_state().completed_fights.is_empty() and not _unfought_run():
		return false
	if run_map.get_route().is_empty():
		return _unfought_run()
	if run_map.get_node(run_map.get_current_node_id()).get("type") == "PatchStall":
		return _patch_stall_closed and _patch_stall_original == _sewing_context() \
			and _patch_stall_visits.get(run_map.get_current_node_id(), []) == [run_map, \
				run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route()] \
			and patch_stall_view == null and not _patch_stall_context.is_empty() \
			and patch_stall_service != null and patch_stall_service.is_consumed() \
			and patch_stall_visit != null and patch_stall_visit.get_state().status == "closed" \
			and _patch_stall_snapshot() == _patch_stall_context
	if run_map.get_node(run_map.get_current_node_id()).get("type") in ["Fight", "Elite"]:
		return _can_leave_fight()
	if run_map.get_node(run_map.get_current_node_id()).get("type") == "Rest" \
		and not _opening_rest(run_map.get_current_node_id(), run_map.get_route().slice(0, -1)) \
		and not _campfire_visits.has(run_map.get_current_node_id()):
		return _current_completed_rest() and is_instance_valid(rest_view) and not rest_view.visible \
			and is_instance_valid(rest_continue_button) and rest_continue_button.disabled
	if run_map.get_node(run_map.get_current_node_id()).get("type") == "Unpicker":
		return _unpicker_closed and _unpicker_original == _sewing_context() \
			and _unpicker_visits.get(run_map.get_current_node_id(), []) == [run_map, \
				run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route()] \
			and is_instance_valid(unpicker_view) and not unpicker_view.visible
	if run_map.get_node(run_map.get_current_node_id()).get("type") == "Campfire" \
		or (run_map.get_node(run_map.get_current_node_id()).get("type") == "Rest" \
			and (_campfire_visits.has(run_map.get_current_node_id()) \
				or _opening_rest(run_map.get_current_node_id(), run_map.get_route().slice(0, -1)))):
		return _campfire_closed and _campfire_original == _sewing_context() \
			and _campfire_visits.get(run_map.get_current_node_id(), []) == [run_map, \
				run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route()] \
			and is_instance_valid(campfire_view) and not campfire_view.visible
	if run_map.get_node(run_map.get_current_node_id()).get("type") == "SewingCircle":
		return _sewing_closed and _sewing_original == _sewing_context() \
			and _sewing_visits.get(run_map.get_current_node_id(), []) == [run_map,
				run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route()] \
			and is_instance_valid(sewing_view) and not sewing_view.visible
	if run_map.get_node(run_map.get_current_node_id()).get("type") in ["Event", "Treasure"]:
		var current_id := run_map.get_current_node_id()
		if _emberglass_campfire_active(current_id):
			return _campfire_closed and _campfire_original == _sewing_context() \
				and _campfire_visits.get(current_id, []) == [run_map,
					run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route()] \
				and is_instance_valid(campfire_view) and not campfire_view.visible
		if _inkblack_unpicker_active(current_id):
			return _unpicker_closed and _unpicker_original == _sewing_context() \
				and _unpicker_visits.get(current_id, []) == [run_map,
					run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route()] \
				and is_instance_valid(unpicker_view) and not unpicker_view.visible
		if _threadmill_sewing_active(current_id) or _sewing_visits.has(current_id):
			return _sewing_closed and _sewing_original == _sewing_context() \
				and _sewing_visits.get(current_id, []) == [run_map,
					run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route()] \
				and is_instance_valid(sewing_view) and not sewing_view.visible
		# A stale claim cannot bypass its own Event. A completed earlier
		# Inkblack visit must not block subsequent ordinary Event receipts.
		if not _inkblack_unpicker_auth.is_empty() and (_inkblack_unpicker_auth.size() != 6 \
			or _inkblack_unpicker_auth[4] == current_id):
			return false
		if not _threadmill_sewing_auth.is_empty() and (_threadmill_sewing_auth.size() != 6 \
			or _threadmill_sewing_auth[4] == current_id):
			return false
		return _placeholder_map != null and _placeholder_map.get_ref() == run_map \
			and not _placeholder_route.is_empty() and run_map.get_route() == _placeholder_route
	return _peddler_closed()


## Stage every combat model before replacing the last mounted battle. The entry
## service shares the run selector/RNG; restore both if later admission fails.
func _choose_battle_route(id: String, source_map: WeakRef, prior: Array[String], button) -> bool:
	if run_difficulty.get_selected_tier() != _run_tier:
		return false
	if not _can_choose_connected_route() or source_map == null or source_map.get_ref() != run_map \
		or run_map.get_route() != prior or not is_instance_valid(route_view) \
		or not route_view.is_visible_in_tree() or not is_instance_valid(button) \
		or button not in route_buttons or button.get_parent() != route_view \
		or button.disabled or not button.is_visible_in_tree() or button.get_meta("route_id") != id \
		or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") not in ["Fight", "Elite", "Boss"] \
		or run_rng == null or fight_selection == null or party_carryover == null \
		or _carryover_map == null or _carryover_map.get_ref() != run_map:
		return false
	var ledger := party_carryover.read_state()
	if not ledger.ok or ledger.heroes != run_heroes or (ledger.completed_fights.is_empty() and not _unfought_run()) \
		or act_outcome.get_state().settled_node_ids.has(id) \
		or ledger.completed_fights.has(id) or run_deck.size() < CombatDeck.TURN_DRAW:
		return false
	# Rest composites are run-owned cards, validated against their full ledger.
	var stitch_ledger := RunRestStitchCards.new(run_deck, run_stitch_descriptors, run_scraps, run_next_stitch_id)
	if not stitch_ledger.is_valid():
		return false
	var snapshot := stitch_ledger.get_snapshot()
	var admitted_ids: Array = _party_receipt.get("hero_ids", [])
	if admitted_ids.size() != CombatParty.PARTY_SIZE:
		return false
	for card in run_deck:
		if run_stitch_descriptors.has(card):
			for owner in run_stitch_descriptors[card].owners:
				if owner not in admitted_ids:
					return false
		elif card != MpwFrayedDebt.CARD_ID and RunRestStitchCards.resolve_card_definition(card).get("owner") not in admitted_ids:
			return false
	var next_party := party_carryover.create_next_fight_party()
	if next_party == null:
		return false
	var rng_before := run_rng.state
	var bound_before := fight_selection._bound_map
	var selected_before := fight_selection._selected.duplicate(true)
	var torn_carry := party_carryover as RunTornCarryover
	if torn_carry == null:
		return false
	var witness_before := [torn_carry._node, torn_carry._result, torn_carry._party, torn_carry._start.duplicate(true)]
	if not run_map.choose_node(id):
		return false
	var entry := RunAuthoredBattleEntry.new().entry_current_battle(run_map, run_rng, fight_selection)
	if entry.get("success", false) and entry.get("node_type") == "Fight":
		# Start from this admission's fresh authored roster, never a prior battle's HP.
		var definitions: Array = entry.enemies.get_enemies()
		var floor_number: Variant = run_map.get_node(id).get("floor")
		for definition in definitions:
			var scaled := RunNormalAttackFloorScaling.scale_normal_max_hp(
				definition.get("max_hp"), floor_number)
			var spec: Variant = definition.get("intent")
			if not scaled.get("ok", false) or CombatEnemyIntents._weighted_slot(
					1, spec).is_empty():
				entry.success = false
				break
			# get_enemies() is detached; keep the authored weighted spec intact
			# except eligible attack amounts, before the first RNG-bound announcement.
			var next_spec: Dictionary = spec.duplicate(true)
			var alternatives: Array = next_spec["actions"]
			for index in range(alternatives.size()):
				var parsed := CombatEnemyIntents.weighted_action(alternatives[index])
				if parsed.is_empty():
					entry.success = false
					break
				var action: Dictionary = parsed["action"]
				if action.get("type") == "attack" and action["amount"] >= 5 \
						and action["amount"] <= 9:
					var attack := RunNormalAttackFloorScaling.scale_normal_attack(
							action["amount"], floor_number)
					if not attack.get("ok", false):
						entry.success = false
						break
					alternatives[index]["amount"] = attack["amount"]
			if not entry.success:
				break
			definition.max_hp = scaled.max_hp
			definition.intent = next_spec
		if entry.success:
			var scaled_enemies := CombatEnemies.new(definitions)
			if not scaled_enemies.is_valid():
				entry.success = false
			else:
				entry.enemies = scaled_enemies
	if entry.get("success", false):
		entry.enemies = CombatEnemies.new(run_difficulty.scale_definitions(entry.enemies.get_enemies()))
	var staged := false
	var next_deck: CombatDeck
	var next_result: CombatBattleResult
	var next_flow: CombatRoundFlow
	if entry.get("success", false):
		# The state immediately before the admission shuffle, so a Path battle
		# performs exactly one shuffle: the final deal with every selected Path card.
		var shuffle_state := run_rng.state
		var admission := RunStitchedBattleHandEntry.new().admit_next_fight(
			run_deck, run_stitch_descriptors, run_scraps, run_next_stitch_id, snapshot.receipt, run_rng)
		if admission.get("ok", false) and admission.snapshot == snapshot:
			next_deck = admission.combat_deck
			# Each selected Path adds its one exclusive card to this battle only,
			# never to the stitchable run ledger. The admission shuffle is rewound so
			# the final deal is the single recorded shuffle of this fight.
			var path_card_ids := _battle_path_card_ids()
			if not path_card_ids.is_empty():
				next_deck = _admit_path_deck(snapshot.deck, path_card_ids, shuffle_state)
			# Bind the genuine roster and party to the run RNG and cache the first
			# announced batch before the hand is dealt. A refusal rolls back below.
			var candidate_intents = entry.get("intents")
			var battle_intents: CombatEnemyIntents = candidate_intents \
				if candidate_intents is CombatEnemyIntents else null
			if next_deck == null or battle_intents == null \
					or not battle_intents.bind_battle(entry.enemies, next_party, run_rng, run_difficulty):
				next_deck = null
			else:
				next_result = CombatBattleResult.new(next_party, entry.enemies)
				next_flow = CombatRoundFlow.new(next_deck, next_party, entry.enemies,
					battle_intents, next_result, null, null, _warden_battle_receipt(), session_gold)
				staged = next_flow.begin_fight()
				if staged:
					staged = torn_carry.begin_battle(id, next_result, next_party)
	if not staged or not act_outcome.begin_current_battle(next_result):
		run_map.undo_choice(id, prior)
		run_rng.state = rng_before
		fight_selection._bound_map = bound_before
		fight_selection._selected = selected_before
		torn_carry._node = witness_before[0]
		torn_carry._result = witness_before[1]
		torn_carry._party = witness_before[2]
		torn_carry._start = witness_before[3]
		return false
	# No fallible model work remains. Detach old controls before mounting fresh ones.
	if round_flow != null:
		round_flow.clear_taunt()
	$LiveSupportHand._cancel_pending()
	_clear_route_view()
	if is_instance_valid(battle_view):
		remove_child(battle_view)
		battle_view.queue_free()
	hero_panels.clear()
	reward_buttons.clear()
	continue_button = null
	card_reward = null
	fight_rewards = null
	multi_fight_rewards = null
	fight_reward_offers.clear()
	fight_reward_gold = 0
	fight_reward_trinket = ""
	fight_reward_claimed = false
	_reward_map = null
	party = next_party
	enemies = entry.enemies
	enemy_intents = entry.intents
	enemy_attacks = enemy_intents.get_intents()
	deck = next_deck
	battle_result = next_result
	round_flow = next_flow
	encounter_id = entry.encounter_id
	victory_gold = RunVictoryGold.new(battle_result)
	_carryover_node = id
	_carryover_revision = run_map.get_generation_revision()
	_carryover_route = run_map.get_route()
	_carryover_floors = run_map.get_floors()
	_carryover_party = party
	_carryover_result = battle_result
	_battle_closed = false
	_build_battle()
	_refresh_hand()
	_refresh_party()
	_refresh_enemy_roster()
	end_turn_button.grab_focus()
	return true


## The exclusive Path cards this run's validated receipts carry, in a stable
## order. Each receipt is revalidated by its canonical service, so a tampered,
## stale or unselected record names no card at all.
func _battle_path_card_ids() -> Array[String]:
	var card_ids: Array[String] = []
	var warden := RunWardenPathChoice.authenticate_receipt(run_warden_path_receipt)
	if warden.get("ok", false):
		card_ids.append(String(warden.card_id))
	var seamstress := _seamstress_battle_card_id()
	if not seamstress.is_empty():
		card_ids.append(seamstress)
	var tinker := _tinker_battle_card_id()
	if not tinker.is_empty() and not card_ids.has(tinker):
		card_ids.append(tinker)
	return card_ids


func _seamstress_battle_card_id() -> String:
	if run_seamstress_path_receipt.is_empty():
		return ""
	var resolver := CombatSeamstressPathCards.new()
	if not resolver.bind_choice(run_seamstress_path_receipt):
		return ""
	return resolver.get_card_id()


## The Tinker card only when the run's detached receipt, the claimed setup and
## the authored record all agree. Any mismatch names no card.
func _tinker_battle_card_id() -> String:
	if not bool(run_tinker_path_receipt.get("ok", false)) or run_tinker_path_choice == null \
		or not run_tinker_path_choice.has_selection():
		return ""
	var selection: Dictionary = run_tinker_path_choice.get_selection()
	var path_id := String(selection.get("path_id", ""))
	var card_id := String(selection.get("card_id", ""))
	if path_id.is_empty() or card_id.is_empty() \
		or String(run_tinker_path_receipt.get("path_id", "")) != path_id \
		or String(run_tinker_path_receipt.get("card_id", "")) != card_id \
		or String(run_tinker_path_receipt.get("passive_id", "")) != String(selection.get("passive_id", "")):
		return ""
	var definition: Dictionary = run_tinker_path_choice.get_definition(path_id)
	var card: Variant = definition.get("card")
	if not card is Dictionary or String((card as Dictionary).get("id", "")) != card_id \
			or String(definition.get("passive_id", "")) != String(selection.get("passive_id", "")):
		return ""
	return card_id


## ONE battle deck for a Path run: the canonical admitted IDs plus every selected
## Path card, shuffled once from the pre-admission run RNG state. An unselected
## run keeps the admission deck and its RNG untouched.
func _admit_path_deck(admitted: Array, path_card_ids: Array, rng_state: int) -> CombatDeck:
	if run_rng == null or path_card_ids.is_empty() or admitted.is_empty():
		return null
	var card_ids: Array[String] = []
	card_ids.assign(admitted)
	for card_id in path_card_ids:
		var id := String(card_id)
		if id.is_empty() or card_ids.has(id):
			return null
		card_ids.append(id)
	run_rng.state = rng_state
	return CombatDeck.new(card_ids, run_rng)


func _choose_placeholder_route(id: String, source_map: WeakRef, prior: Array[String], button) -> bool:
	if not _can_choose_connected_route() or run_rng == null or run_deck.is_empty() \
		or source_map == null or source_map.get_ref() != run_map or run_map.get_route() != prior \
		or not is_instance_valid(route_view) or not route_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button not in route_buttons \
		or button.get_parent() != route_view or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("route_id") != id or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") not in ["Event", "Treasure"]:
		return false
	if run_map.get_node(id).type == "Event":
		# Resolve each once-per-run authored visit before the generic rotation.
		if not _quiet_spool_completed:
			return _open_quiet_spool(id, source_map)
		if not _moth_completed:
			return _open_moth_infestation(id, source_map)
		if not _dye_vat_completed:
			return _open_dye_vat(id, source_map)
		if not _needle_toll_completed:
			return _open_needle_toll(id, source_map)
		return _open_wallet_event(id, source_map)
	if not run_map.choose_node(id):
		return false
	_placeholder_map = source_map
	_placeholder_route = run_map.get_route()
	_clear_route_view()
	_present_connected_route(source_map)
	return true


func _needle_toll_snapshot() -> Array:
	var carry := party_carryover as RunTornCarryover
	if run_map == null or run_rng == null or carry == null or act_outcome == null \
		or not is_instance_valid(needle_toll_panel) or _needle_toll_outcome == null \
		or needle_toll_panel._selector == null:
		return []
	var payers: Array = []
	var picker := needle_toll_panel.needle_payer
	if is_instance_valid(picker):
		for index in range(picker.item_count):
			payers.append([picker.get_item_text(index), picker.get_item_metadata(index), picker.is_item_disabled(index)])
	return [run_map, run_map.get_generation_revision(), run_map.get_floors(),
		run_map.get_route(), run_map.get_current_node_id(), _needle_toll_node,
		run_rng, run_rng.state, run_seed, run_deck.duplicate(), run_heroes.duplicate(true),
		run_trinkets.duplicate(), session_gold, run_scraps, run_removal_count,
		run_stitch_descriptors.duplicate(true), run_next_stitch_id, carry, carry.read_state(),
		carry.torn, carry.torn.read_state(), carry._wardrobe,
		carry._wardrobe.get_snapshot() if carry._wardrobe != null else {},
		act_outcome, act_outcome.get_state(), needle_toll_panel, needle_toll_panel._selector,
		needle_toll_panel._selector.get_event(), _needle_toll_outcome,
		_needle_toll_outcome.get_snapshot(), _needle_toll_outcome.get_source_snapshot(),
		_needle_toll_outcome._rng.state, _needle_toll_rng_start, _needle_toll_completed,
		_quiet_spool_completed, _moth_completed, _dye_vat_completed,
		_wallet_event_history.duplicate(), picker, payers]


func _open_needle_toll(id: String, source: WeakRef) -> bool:
	if _needle_toll_completed or is_instance_valid(needle_toll_panel) \
		or source == null or source.get_ref() != run_map:
		return false
	var rng := RandomNumberGenerator.new()
	rng.state = run_rng.state
	var outcome := RunNeedleToll.new({"heroes": run_heroes,
		"wallet": {"gold": session_gold, "scraps": run_scraps}, "deck": run_deck}, rng)
	var panel := preload("res://scenes/event_choice_panel.tscn").instantiate() as LiveEventChoicePanel
	add_child(panel)
	if not panel.open_needle_toll(outcome):
		panel.free()
		return false
	_mount_event_backdrop(panel)
	if not run_map.choose_node(id):
		panel.free()
		return false
	needle_toll_panel = panel
	_needle_toll_outcome = outcome
	_needle_toll_rng_start = run_rng.state
	_needle_toll_node = id
	_clear_route_view()
	_needle_toll_context = _needle_toll_snapshot()
	panel.choice_committed.connect(_commit_needle_toll.bind(panel, source))
	return true


func _commit_needle_toll(event_id: String, choice_id: String, panel, source: WeakRef) -> void:
	if not is_instance_valid(panel) or panel != needle_toll_panel or panel.get_parent() != self \
		or not panel.is_visible_in_tree() or not panel.has_open_event() \
		or source == null or source.get_ref() != run_map or _needle_toll_context.is_empty() \
		or _needle_toll_snapshot() != _needle_toll_context \
		or run_map.get_current_node_id() != _needle_toll_node \
		or run_map.get_node(_needle_toll_node).get("type") != "Event" \
		or panel._selector == null or not panel._selector.is_claimed() \
		or event_id != RunNeedleToll.EVENT_ID \
		or panel._committed_choice != {"ok": true, "event_id": event_id, "choice_id": choice_id}:
		return
	# Replay the receipt on a detached RNG before publishing any live state.
	var original := _needle_toll_outcome.get_source_snapshot()
	var rng := RandomNumberGenerator.new()
	rng.state = _needle_toll_rng_start
	var staged := RunNeedleToll.new({"heroes": original.heroes,
		"wallet": original.wallet, "deck": original.deck}, rng)
	var receipt: Dictionary
	if _needle_toll_outcome.is_paid():
		if not staged.pay_toll(_needle_toll_outcome._wounded_hero_id).ok \
			or staged.get_snapshot() != _needle_toll_outcome.get_snapshot() or rng.state != run_rng.state:
			return
		receipt = staged.skip_cards() if choice_id == "skip" else staged.claim_card(choice_id)
	elif _needle_toll_outcome.is_open() and not _needle_toll_completed:
		if choice_id == RunNeedleToll.CHOICE_SAFE_EXIT:
			receipt = staged.take_safe_exit()
		elif choice_id == RunNeedleToll.CHOICE_PAY:
			var picker: OptionButton = panel.needle_payer
			if not is_instance_valid(picker) or picker.get_parent() != panel.choices_container.get_parent() \
				or not picker.is_visible_in_tree() or picker.disabled or picker.selected < 0 \
				or picker.is_item_disabled(picker.selected):
				return
			receipt = staged.pay_toll(picker.get_item_metadata(picker.selected))
	if receipt.get("ok") != true or receipt.get("receipt", "").is_empty():
		return
	if staged.is_paid():
		var next := preload("res://scenes/event_choice_panel.tscn").instantiate() as LiveEventChoicePanel
		add_child(next)
		if not next.open_needle_toll(staged):
			next.free()
			return
		if not (party_carryover as RunTornCarryover).apply_needle_toll(staged, party_carryover.read_state()):
			next.free()
			return
		_mount_event_backdrop(next)
		panel.close_event()
		remove_child(panel)
		panel.queue_free()
		needle_toll_panel = next
		_needle_toll_outcome = staged
		run_heroes = receipt.heroes.duplicate(true)
		run_rng.state = rng.state
		_needle_toll_completed = true
		_needle_toll_context = _needle_toll_snapshot()
		next.choice_committed.connect(_commit_needle_toll.bind(next, source))
		return
	run_deck.assign(receipt.deck)
	session_gold = receipt.wallet.gold
	run_scraps = receipt.wallet.scraps
	_needle_toll_completed = true
	_placeholder_map = source
	_placeholder_route = run_map.get_route()
	_clear_needle_toll()
	_present_connected_route(source)


func _clear_needle_toll() -> void:
	_needle_toll_context.clear()
	_needle_toll_outcome = null
	_needle_toll_node = ""
	_needle_toll_rng_start = 0
	if is_instance_valid(needle_toll_panel):
		needle_toll_panel.close_event()
		remove_child(needle_toll_panel)
		needle_toll_panel.queue_free()
	needle_toll_panel = null


func _wallet_event_snapshot() -> Array:
	if run_map == null or run_rng == null or party_carryover == null or act_outcome == null \
		or not is_instance_valid(wallet_event_panel) or wallet_event_panel._selector == null:
		return []
	var carry := party_carryover as RunTornCarryover
	if carry == null:
		return []
	return [run_map, run_map.get_generation_revision(), run_map.get_floors(),
		run_map.get_route(), run_rng, run_rng.state, run_seed, run_deck.duplicate(),
		run_heroes.duplicate(true), run_trinkets.duplicate(), session_gold, run_scraps,
		run_removal_count, run_stitch_descriptors.duplicate(true), run_next_stitch_id,
		carry, carry.read_state(), carry.torn.read_state(), carry._wardrobe,
		carry._wardrobe.get_snapshot() if carry._wardrobe != null else {},
		act_outcome, act_outcome.get_state(), wallet_event_panel,
		wallet_event_panel._selector, wallet_event_panel._selector.get_event(),
		_wallet_event_record.duplicate(true), _wallet_event_history.duplicate(),
		_emberglass_gate, _emberglass_gate.get_event() if _emberglass_gate != null else {},
		_emberglass_gate.is_valid() if _emberglass_gate != null else false,
		wallet_event_panel._offered_wallet.duplicate(true),
		wallet_event_panel._offered_snapshot.duplicate(true), _vital_event_history.duplicate(),
		_vital_event_gate, _vital_event_gate.get_event() if _vital_event_gate != null else {},
		_vital_event_gate.get_snapshot() if _vital_event_gate != null else {},
		_vital_event_gate.is_valid() if _vital_event_gate != null else false,
		_quiet_spool_completed, _moth_completed, _dye_vat_completed]


func _load_wallet_event_catalog() -> Dictionary:
	# Validate before drawing. Required roadside entries fail closed as a pack;
	# unique, valid future additions remain eligible without a fixed pool size.
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(event_catalog_path)) \
		if FileAccess.file_exists(event_catalog_path) else null
	if not document is Dictionary or not RunM04EventRotation.new(document).is_catalog_valid():
		return {}
	var roadside: Variant = JSON.parse_string(FileAccess.get_file_as_string(roadside_event_catalog_path)) \
		if FileAccess.file_exists(roadside_event_catalog_path) else null
	if not roadside is Dictionary or not roadside.get("events") is Array:
		return {}
	var combined: Dictionary = document.duplicate(true)
	var seen := {}
	for record in combined.events:
		if record is Dictionary:
			seen[record.get("id")] = true
	var roadside_ids := {}
	for record in roadside.events:
		var service := RunEventChoice.new(record)
		if not service.is_valid() or seen.has(record.id):
			return {}
		if REQUIRED_ROADSIDE_EVENT_IDS.has(record.id) and record.choices.size() != 3:
			return {}
		var preview := service.preview_wallet_choices({"gold": 0, "scraps": 0})
		if not preview.ok:
			return {}
		for choice in preview.choices:
			if choice.gold_delta == null or choice.scraps_delta == null:
				return {}
		seen[record.id] = true
		roadside_ids[record.id] = true
		combined.events.append(record.duplicate(true))
	for required in REQUIRED_ROADSIDE_EVENT_IDS:
		if not roadside_ids.has(required):
			return {}
	# Admit only the shipped, authenticated Campfire and Inkblack service records.
	# None may replace an existing generic Event ID, even with matching content.
	var waystations := RunV3ServiceWaystationEventGate.new()
	if not waystations.is_catalog_valid():
		return {}
	for service_id in ["v3_emberglass_campfire", "v3_briar_button_mending_bench",
			"v3_inkblack_unpicker_van", "v3_threadmill_sewing_circle"]:
		var service_record := waystations.get_event_record(service_id)
		if service_record.is_empty() or seen.has(service_id) \
			or not RunEventChoice.new(service_record).is_valid():
			return {}
		seen[service_id] = true
		combined.events.append(service_record)
	# The ordinary, roadside and hero-gated generic contracts remain intact.
	# A live run admits only detached, service-authenticated stories for its party.
	if run_map != null or not run_heroes.is_empty():
		if run_map == null or not RunRestRecovery._is_valid_roster(run_heroes):
			return {}
		var ids: Array = []
		for hero in run_heroes:
			ids.append(hero.id)
		var offers := RunV3HeroEventOffers.new(ids)
		if not offers.is_valid():
			return {}
		for record in offers.get_offers():
			if seen.has(record.id):
				return {}
			seen[record.id] = true
			combined.events.append(record.duplicate(true))
	if run_map != null and not _fate_pin_seen:
		var wardrobe := _fate_pin_candidate_wardrobe()
		var auction := RunFatePinAuction.load_record()
		if wardrobe != null and not auction.is_empty() \
			and RunFatePinAuction.eligible_definitions(wardrobe.get_snapshot()).size() >= auction.offer_count:
			combined.events.append(auction)
	return {"events": combined.events}


func _fate_pin_candidate_wardrobe() -> RunPatchWardrobe:
	var carry := party_carryover as RunTornCarryover
	if carry == null:
		return null
	var wardrobe := carry._wardrobe
	if wardrobe == null:
		wardrobe = RunPatchWardrobe.new(run_heroes, run_trinkets,
			RunAuthoredPatchDefinitions.load_definitions(), run_scraps, session_gold, run_deck, run_seed, true)
	var w := wardrobe.get_snapshot()
	if not wardrobe.is_valid() or w.heroes != run_heroes or w.owned != run_trinkets \
		or w.cards != run_deck or w.gold != session_gold or w.scraps != run_scraps \
		or w.seed != run_seed or w.rest_id != "" or not carry.can_bind_wardrobe(wardrobe, carry.torn, w):
		return null
	return wardrobe


func _fate_pin_snapshot() -> Array:
	var carry := party_carryover as RunTornCarryover
	if run_map == null or run_rng == null or carry == null or act_outcome == null \
		or not is_instance_valid(fate_pin_panel) or fate_pin_panel._selector == null \
		or _fate_pin_outcome == null or _fate_pin_wardrobe == null:
		return []
	# Payer selection itself may change; the control and its authenticated rows may not.
	var picker := fate_pin_panel.auction_payer
	var rows: Array = []
	if is_instance_valid(picker):
		for index in range(picker.item_count):
			rows.append([picker.get_item_text(index), picker.get_item_metadata(index), picker.is_item_disabled(index)])
	return [run_map, run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route(),
		run_rng, run_rng.state, run_seed, run_heroes.duplicate(true), run_deck.duplicate(),
		run_trinkets.duplicate(), session_gold, run_scraps, run_removal_count,
		run_stitch_descriptors.duplicate(true), run_next_stitch_id, carry, carry.read_state(),
		carry.torn, carry.torn.read_state(), carry._wardrobe,
		_fate_pin_wardrobe, _fate_pin_wardrobe.get_snapshot(), act_outcome, act_outcome.get_state(),
		fate_pin_panel, fate_pin_panel._selector, fate_pin_panel._selector.get_event(),
		_fate_pin_outcome, _fate_pin_outcome.get_event(), _fate_pin_outcome.get_source(),
		_fate_pin_outcome.get_offers(), _fate_pin_seen, picker, rows,
		_wallet_event_history.duplicate(), _vital_event_history.duplicate()]


func _open_fate_pin_auction(id: String, source: WeakRef, staged_rng: RandomNumberGenerator) -> bool:
	if _fate_pin_seen or is_instance_valid(fate_pin_panel) or not _can_choose_connected_route() \
		or source == null or source.get_ref() != run_map or staged_rng == null \
		or not run_map.get_legal_choices().has(id) or run_map.get_node(id).get("type") != "Event":
		return false
	var wardrobe := _fate_pin_candidate_wardrobe()
	var outcome := RunFatePinAuction.new(wardrobe, staged_rng)
	var panel := preload("res://scenes/event_choice_panel.tscn").instantiate() as LiveEventChoicePanel
	add_child(panel)
	if not panel.open_fate_pin_auction(outcome):
		panel.free()
		return false
	if not run_map.choose_node(id):
		panel.free()
		return false
	_mount_event_backdrop(panel)
	fate_pin_panel = panel
	_fate_pin_outcome = outcome
	_fate_pin_wardrobe = wardrobe
	_fate_pin_seen = true
	run_rng.state = staged_rng.state
	_clear_route_view()
	_fate_pin_context = _fate_pin_snapshot()
	panel.choice_committed.connect(_commit_fate_pin_auction.bind(panel, source))
	return true


func _commit_fate_pin_auction(event_id: String, choice_id: String, panel, source: WeakRef) -> void:
	if not is_instance_valid(panel) or panel != fate_pin_panel or panel.get_parent() != self \
		or not panel.is_visible_in_tree() or not panel.has_open_event() \
		or source == null or source.get_ref() != run_map or _fate_pin_context.is_empty() \
		or _fate_pin_snapshot() != _fate_pin_context \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Event" \
		or event_id != RunFatePinAuction.EVENT_ID or not panel._selector.is_claimed() \
		or panel._committed_choice != {"ok": true, "event_id": event_id, "choice_id": choice_id}:
		return
	var payer: Variant = ""
	var slot: Variant = ""
	if choice_id != "safe_exit":
		var picker: OptionButton = panel.auction_payer
		if not is_instance_valid(picker) or picker.get_parent() != panel.choices_container.get_parent() \
			or not picker.is_visible_in_tree() or picker.disabled or picker.selected < 0 \
			or picker.is_item_disabled(picker.selected):
			return
		payer = picker.get_item_metadata(picker.selected)
		var index := ["patch_0", "patch_1"].find(choice_id)
		if index < 0:
			return
		slot = _fate_pin_outcome.get_offers()[index].slot
	var receipt := _fate_pin_outcome.prepare(_fate_pin_wardrobe, choice_id, payer, slot,
		_fate_pin_outcome.get_source())
	var carry := party_carryover as RunTornCarryover
	if not receipt.ok or not carry.apply_fate_pin_auction(_fate_pin_outcome, _fate_pin_wardrobe, receipt, carry.read_state()):
		return
	run_heroes = receipt.state.heroes.duplicate(true)
	run_trinkets.assign(receipt.state.owned)
	session_gold = receipt.state.gold
	run_scraps = receipt.state.scraps
	_fate_pin_receipt = receipt.duplicate(true)
	_placeholder_map = source
	_placeholder_route = run_map.get_route()
	_clear_fate_pin_panel()
	_present_connected_route(source)


func _clear_fate_pin_panel() -> void:
	_fate_pin_context.clear()
	if is_instance_valid(fate_pin_panel):
		fate_pin_panel.close_event()
		remove_child(fate_pin_panel)
		fate_pin_panel.queue_free()
	fate_pin_panel = null


func _frayed_debt_source() -> Dictionary:
	var ledger := RunRestStitchCards.new(run_deck, run_stitch_descriptors, run_scraps, run_next_stitch_id)
	if not ledger.is_valid():
		return {}
	var context := ledger.get_snapshot()
	context.party_ids = _party_receipt.get("hero_ids", []).duplicate()
	context.visited = _frayed_debt_seen
	return context


## One ticket per eligible ordinary outcome, plus the authored Parcel weight.
## Keep the non-wallet transaction out of RunM04EventRotation's catalog.
func _select_generic_event(document: Dictionary, staged_rng: RandomNumberGenerator) -> Dictionary:
	var rotation := RunM04EventRotation.new(document)
	if not rotation.is_catalog_valid():
		return {"ok": false}
	for event_id in _wallet_event_history:
		if event_id.strip_edges().is_empty():
			return {"ok": false}
	var records := {}
	var tickets: Array[String] = []
	for record in rotation.get_generic_events():
		if not _wallet_event_history.has(record.id):
			records[record.id] = record
			tickets.append(record.id)
	var probe_rng := RandomNumberGenerator.new()
	probe_rng.state = staged_rng.state
	var parcel := RunFrayedDebtParcel.new()
	if not _frayed_debt_seen and parcel.prepare(_frayed_debt_source(), probe_rng).ok:
		var record := RunFrayedDebtParcel.load_authored_event()
		records[record.id] = record
		for ticket in range(int(record.visit_weight)):
			tickets.append(record.id)
	if tickets.is_empty():
		return {"ok": false}
	tickets.sort()
	return {"ok": true, "event": records[tickets[staged_rng.randi_range(0, tickets.size() - 1)]].duplicate(true)}


func _frayed_debt_snapshot() -> Array:
	if run_map == null or run_rng == null or party_carryover == null or act_outcome == null \
		or not is_instance_valid(frayed_debt_panel) or frayed_debt_panel._selector == null \
		or _frayed_debt_outcome == null:
		return []
	var carry := party_carryover as RunTornCarryover
	return [run_map, run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route(),
		run_rng, run_rng.state, run_seed, _frayed_debt_source(), _party_receipt.duplicate(true),
		run_heroes.duplicate(true), run_trinkets.duplicate(), session_gold, run_removal_count,
		carry, carry.read_state(), carry.torn, carry.torn.read_state(), carry._wardrobe,
		carry._wardrobe.get_snapshot() if carry._wardrobe != null else {},
		act_outcome, act_outcome.get_state(), frayed_debt_panel, frayed_debt_panel._selector,
		frayed_debt_panel._selector.get_event(), _frayed_debt_outcome,
		_frayed_debt_outcome.get_source_snapshot(), _frayed_debt_outcome.get_offers(),
		_wallet_event_history.duplicate(), _vital_event_history.duplicate()]


func _open_frayed_debt_parcel(id: String, source: WeakRef, staged_rng: RandomNumberGenerator) -> bool:
	if _frayed_debt_seen or not _can_choose_connected_route() or source == null \
		or source.get_ref() != run_map or staged_rng == null \
		or not run_map.get_legal_choices().has(id) or run_map.get_node(id).get("type") != "Event":
		return false
	var outcome := RunFrayedDebtParcel.new()
	if not outcome.prepare(_frayed_debt_source(), staged_rng).ok:
		return false
	var panel := preload("res://scenes/event_choice_panel.tscn").instantiate() as LiveEventChoicePanel
	add_child(panel)
	if not panel.open_frayed_debt_parcel(outcome) or not run_map.choose_node(id):
		panel.free()
		return false
	_mount_event_backdrop(panel)
	frayed_debt_panel = panel
	_frayed_debt_outcome = outcome
	run_rng.state = staged_rng.state
	_clear_route_view()
	_frayed_debt_context = _frayed_debt_snapshot()
	panel.choice_committed.connect(_commit_frayed_debt_parcel.bind(panel, source))
	return true


func _commit_frayed_debt_parcel(event_id: String, choice_id: String, panel, source: WeakRef) -> void:
	if not is_instance_valid(panel) or panel != frayed_debt_panel or panel.get_parent() != self \
		or not panel.is_visible_in_tree() or not panel.has_open_event() or source == null \
		or source.get_ref() != run_map or _frayed_debt_context.is_empty() \
		or _frayed_debt_snapshot() != _frayed_debt_context \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Event" \
		or event_id != "frayed_debt_parcel" or not panel._selector.is_claimed() \
		or panel._committed_choice != {"ok": true, "event_id": event_id, "choice_id": choice_id}:
		return
	var receipt := _frayed_debt_outcome.choose(choice_id, _frayed_debt_source())
	if not receipt.ok:
		return
	run_deck.assign(receipt.deck)
	run_scraps = receipt.remaining_scraps
	run_stitch_descriptors = receipt.descriptors.duplicate(true)
	run_next_stitch_id = receipt.next_stitch_id
	_frayed_debt_seen = receipt.visited
	_frayed_debt_receipt = receipt.duplicate(true)
	_placeholder_map = source
	_placeholder_route = run_map.get_route()
	_clear_frayed_debt_panel()
	_present_connected_route(source)


func _clear_frayed_debt_panel() -> void:
	_frayed_debt_context.clear()
	_frayed_debt_outcome = null
	if is_instance_valid(frayed_debt_panel):
		frayed_debt_panel.close_event()
		remove_child(frayed_debt_panel)
		frayed_debt_panel.queue_free()
	frayed_debt_panel = null


## A read-only wallet-panel adapter; the six-key redemption service is the only
## source of truth for the accepted cut, sale and free leave. The panel's
## RunEventChoice never mutates the live run.
func _debt_booth_view_record(service: RunV3DebtRedemptionEvent) -> Dictionary:
	var preview := service.preview_choices()
	if not preview.get("ok", false) or preview.get("event_id") != RunV3DebtRedemptionEvent.EVENT_ID:
		return {}
	var choices: Array = []
	for forecast in preview.choices:
		choices.append({"id": forecast.id, "text": forecast.text,
			"outcome": {"gold": forecast.gold_delta, "scraps": forecast.scraps_delta}})
	return {"id": preview.event_id, "title": preview.title,
		"description": preview.description, "choices": choices}


func _debt_booth_source() -> Dictionary:
	return {"deck": run_deck.duplicate(), "descriptors": run_stitch_descriptors.duplicate(true),
		"next_stitch_id": run_next_stitch_id, "gold": session_gold,
		"scraps": run_scraps, "prior_removals": run_removal_count}


func _debt_booth_snapshot() -> Array:
	var carry := party_carryover as RunTornCarryover
	if run_map == null or run_rng == null or carry == null or act_outcome == null \
		or not is_instance_valid(debt_booth_panel) or debt_booth_panel._selector == null \
		or _debt_booth_service == null:
		return []
	return [run_map, run_map.get_generation_revision(), run_map.get_floors(),
		run_map.get_route(), _debt_booth_node, run_rng, run_rng.state, run_seed,
		_debt_booth_source(), _party_receipt.duplicate(true), run_heroes.duplicate(true),
		run_trinkets.duplicate(), carry, carry.read_state(), carry.torn,
		carry.torn.read_state(), carry._wardrobe,
		carry._wardrobe.get_snapshot() if carry._wardrobe != null else {},
		act_outcome, act_outcome.get_state(), debt_booth_panel,
		debt_booth_panel._selector, debt_booth_panel._selector.get_event(),
		debt_booth_panel._offered_wallet.duplicate(true),
		debt_booth_panel._wallet_previews.duplicate(true),
		_debt_booth_service, _debt_booth_service.get_event(),
		_debt_booth_service.get_source_snapshot(), _debt_booth_service.preview_choices(),
		_debt_booth_seen, _wallet_event_history.duplicate(), _vital_event_history.duplicate()]


func _open_debt_booth(id: String, source: WeakRef) -> bool:
	if _debt_booth_seen or is_instance_valid(debt_booth_panel) \
		or not run_deck.has(MpwFrayedDebt.CARD_ID) or not _can_choose_connected_route() \
		or source == null or source.get_ref() != run_map \
		or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") != "Event":
		return false
	var service := RunV3DebtRedemptionEvent.new()
	var opening := _debt_booth_source()
	if not service.prepare(opening).get("ok", false):
		return false
	var view := _debt_booth_view_record(service)
	if view.is_empty():
		return false
	var forecast := service.preview_choices()
	var panel := preload("res://scenes/event_choice_panel.tscn").instantiate() as LiveEventChoicePanel
	add_child(panel)
	if not panel.open_event_with_wallet(view, {"gold": session_gold, "scraps": run_scraps}):
		panel.free()
		return false
	# A view-only wallet adapter must deny exactly the service's unaffordable
	# choices, including both boundary prices. Never rely on a cosmetic label.
	var buttons := panel.get_choice_buttons()
	var valid: bool = buttons.size() == forecast.choices.size()
	if valid:
		for index in range(buttons.size()):
			var row: Dictionary = forecast.choices[index]
			valid = valid and buttons[index].disabled == not row.affordable \
				and panel._wallet_previews.get(row.id, {}).get("affordable") == row.affordable
	if not valid or not run_map.choose_node(id):
		panel.free()
		return false
	_mount_event_backdrop(panel)
	debt_booth_panel = panel
	_debt_booth_service = service
	_debt_booth_node = id
	_clear_route_view()
	_debt_booth_context = _debt_booth_snapshot()
	panel.wallet_choice_committed.connect(_commit_debt_booth.bind(panel, source))
	var enabled: Array[Button] = []
	for button in buttons:
		if not button.disabled:
			enabled.append(button)
	for index in range(enabled.size()):
		enabled[index].focus_next = enabled[index].get_path_to(enabled[(index + 1) % enabled.size()])
		enabled[index].focus_previous = enabled[index].get_path_to(enabled[(index - 1 + enabled.size()) % enabled.size()])
	if not enabled.is_empty():
		enabled[0].grab_focus()
	return true


func _commit_debt_booth(claim: Dictionary, panel, source: WeakRef) -> void:
	if not is_instance_valid(panel) or panel != debt_booth_panel or panel.get_parent() != self \
		or not panel.is_visible_in_tree() or not panel.has_open_event() \
		or not panel._wallet_mode or panel._selector == null or not panel._selector.is_claimed() \
		or panel._committed_choice != claim or source == null or source.get_ref() != run_map \
		or _debt_booth_seen or _debt_booth_context.is_empty() \
		or _debt_booth_snapshot() != _debt_booth_context \
		or run_map.get_current_node_id() != _debt_booth_node \
		or run_map.get_node(_debt_booth_node).get("type") != "Event" \
		or claim.get("event_id") != RunV3DebtRedemptionEvent.EVENT_ID:
		return
	var choice_id: Variant = claim.get("choice_id")
	var expected_view := RunEventChoice.new(_debt_booth_view_record(_debt_booth_service)).choose_with_wallet(
		choice_id, {"gold": session_gold, "scraps": run_scraps})
	var preview := _debt_booth_service.preview_choice(choice_id)
	if not expected_view.get("ok", false) or claim != expected_view \
		or not preview.get("ok", false) or not preview.get("affordable", false) \
		or _debt_booth_source() != _debt_booth_service.get_source_snapshot():
		return
	var receipt := _debt_booth_service.choose(choice_id, _debt_booth_service.get_source_snapshot())
	if not receipt.get("ok", false):
		return
	# Commit the entire canonical stitched/wallet/allocator ledger exactly once.
	run_deck.assign(receipt.deck)
	run_stitch_descriptors = receipt.descriptors.duplicate(true)
	run_next_stitch_id = receipt.next_stitch_id
	session_gold = receipt.gold
	run_scraps = receipt.scraps
	run_removal_count = receipt.prior_removals
	_debt_booth_seen = true
	_debt_booth_receipt = receipt.duplicate(true)
	_placeholder_map = source
	_placeholder_route = run_map.get_route()
	_clear_debt_booth()
	_present_connected_route(source)


func _clear_debt_booth() -> void:
	_debt_booth_context.clear()
	_debt_booth_node = ""
	_debt_booth_service = null
	if is_instance_valid(debt_booth_panel):
		debt_booth_panel.close_event()
		remove_child(debt_booth_panel)
		debt_booth_panel.queue_free()
	debt_booth_panel = null


func _open_wallet_event(id: String, source: WeakRef) -> bool:
	if run_rng == null or run_map == null or source == null or source.get_ref() != run_map \
		or session_gold < 0 or run_scraps < 0 \
		or not _can_choose_connected_route() or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") != "Event":
		return false
	# The Booth is an extra authored visit, not a generic lottery ticket, and
	# cannot displace the first four dedicated opening Events.
	if not _debt_booth_seen and run_deck.has(MpwFrayedDebt.CARD_ID):
		return _open_debt_booth(id, source)
	var vital := _wallet_event_history.size() == 1 and _vital_event_history.is_empty()
	var snapshot := {}
	var vital_gate: RunV3HeroVitalEventGate = null
	var live_warden: Dictionary = {}
	if vital:
		var carry := party_carryover as RunTornCarryover
		if carry == null or carry.read_state().heroes != run_heroes \
			or carry.create_next_fight_party() == null:
			return false
		for hero in run_heroes:
			if hero.hp > 0:
				if snapshot.is_empty():
					snapshot = {"gold": session_gold, "scraps": run_scraps,
						"hero": {"id": hero.id, "hp": hero.hp, "max_hp": hero.max_hp}}
				if hero.id == "warden":
					live_warden = {"gold": session_gold, "scraps": run_scraps,
						"hero": {"id": hero.id, "hp": hero.hp, "max_hp": hero.max_hp}}
		if snapshot.is_empty():
			return false
	# Draw on a detached copy: failed mounting/admission must consume nothing.
	var staged_rng := RandomNumberGenerator.new()
	staged_rng.state = run_rng.state
	var document := _load_wallet_event_catalog()
	if document.is_empty():
		return false
	var selection: Dictionary
	if vital:
		var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(vital_event_catalog_path)) \
			if FileAccess.file_exists(vital_event_catalog_path) else {}
		var rotation := RunV3VitalEventRotation.new(catalog)
		if not rotation.is_catalog_valid():
			return false
		var eligible: Array = rotation.get_vital_events()
		var warden_offers: RunV3HeroVitalEventGate = null
		if not live_warden.is_empty():
			var party_ids: Array = []
			for hero in run_heroes:
				party_ids.append(hero.id)
			warden_offers = RunV3HeroVitalEventGate.new(party_ids)
			if not warden_offers.is_valid():
				return false
			for offered in warden_offers.get_offers():
				if offered.id == "v3_warden_buckle_heart_ward":
					eligible.append(offered)
		# Preserve the entire story rotation: append only the authenticated
		# living-Warden offer, sort by ID and consume one run RNG draw.
		eligible = eligible.filter(func(event): return not _vital_event_history.has(event.id))
		eligible.sort_custom(func(a, b): return String(a.id) < String(b.id))
		if eligible.is_empty():
			return false
		var picked: Dictionary = eligible[staged_rng.randi_range(0, eligible.size() - 1)]
		if picked.id == "v3_warden_buckle_heart_ward":
			snapshot = live_warden
			if warden_offers == null:
				return false
			vital_gate = warden_offers.enter(picked, snapshot)
			if vital_gate == null or not vital_gate.is_valid() \
				or vital_gate.get_event() != picked or vital_gate.get_snapshot() != snapshot:
				return false
		selection = {"ok": true, "event": picked}
	else:
		selection = _select_generic_event(document, staged_rng)
	if not selection.ok:
		return false
	var record: Dictionary = selection.event
	if record.id == "frayed_debt_parcel":
		return _open_frayed_debt_parcel(id, source, staged_rng)
	if record.id == RunFatePinAuction.EVENT_ID:
		return _open_fate_pin_auction(id, source, staged_rng)
	var emberglass_gate: RunV3ServiceWaystationEventGate = null
	if record.id in ["v3_emberglass_campfire", "v3_briar_button_mending_bench",
			"v3_inkblack_unpicker_van", "v3_threadmill_sewing_circle"]:
		var waystations := RunV3ServiceWaystationEventGate.new()
		emberglass_gate = waystations.open_visit(record)
		if emberglass_gate == null or not emberglass_gate.is_valid() \
			or emberglass_gate.get_event() != record or vital:
			return false
	var panel := preload("res://scenes/event_choice_panel.tscn").instantiate() as LiveEventChoicePanel
	add_child(panel)
	var mounted := panel.open_event_with_vitals(record, snapshot) if vital else \
		panel.open_event_with_wallet(record, {"gold": session_gold, "scraps": run_scraps})
	if not mounted:
		panel.free()
		return false
	_mount_event_backdrop(panel)
	if not run_map.choose_node(id):
		panel.free()
		return false
	run_rng.state = staged_rng.state
	if vital:
		_vital_event_history.append(record.id)
	else:
		_wallet_event_history.append(record.id)
	_wallet_event_record = record.duplicate(true)
	_emberglass_gate = emberglass_gate
	_vital_event_gate = vital_gate
	wallet_event_panel = panel
	_clear_route_view()
	_wallet_event_context = _wallet_event_snapshot()
	if vital:
		panel.vital_choice_committed.connect(_commit_vital_event.bind(panel, source))
	else:
		panel.wallet_choice_committed.connect(_commit_wallet_event.bind(panel, source))
	var enabled: Array[Button] = []
	for button in panel.get_choice_buttons():
		if not button.disabled:
			enabled.append(button)
	for index in range(enabled.size()):
		enabled[index].focus_next = enabled[index].get_path_to(enabled[(index + 1) % enabled.size()])
		enabled[index].focus_previous = enabled[index].get_path_to(enabled[(index - 1 + enabled.size()) % enabled.size()])
	if not enabled.is_empty():
		enabled[0].grab_focus()
	return true


func _commit_wallet_event(receipt: Dictionary, panel, source: WeakRef) -> void:
	if not is_instance_valid(panel) or panel != wallet_event_panel or panel.get_parent() != self \
		or not panel.is_visible_in_tree() or not panel.has_open_event() \
		or source == null or source.get_ref() != run_map \
		or _wallet_event_context.is_empty() or _wallet_event_snapshot() != _wallet_event_context \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Event" \
		or not panel._wallet_mode or panel._selector == null or not panel._selector.is_claimed() \
		or panel._committed_choice != receipt:
		return
	# Recompute from the bound authored record and live pre-commit wallet; never
	# trust a signal's wallet or a panel's unauthenticated IDs.
	var expected := RunEventChoice.new(_wallet_event_record).choose_with_wallet(
		receipt.get("choice_id"), {"gold": session_gold, "scraps": run_scraps})
	if not expected.ok or receipt != expected:
		return
	var paid_emberglass := false
	var paid_inkblack := false
	var paid_threadmill := false
	var pending_visit: RunCampfireVisit = null
	var pending_unpicker: RunUnpickerVisit = null
	var pending_sewing: RunSewingCircleVisit = null
	if _wallet_event_record.get("id") in ["v3_emberglass_campfire", "v3_briar_button_mending_bench",
			"v3_inkblack_unpicker_van", "v3_threadmill_sewing_circle"]:
		if _emberglass_gate == null or not _emberglass_gate.is_valid() \
			or _emberglass_gate.get_event() != _wallet_event_record:
			return
		paid_emberglass = _emberglass_gate.get_service_kind() == "Campfire" \
			and receipt.get("choice_id") == _emberglass_gate.get_service_choice_id()
		paid_inkblack = _emberglass_gate.get_event_id() == "v3_inkblack_unpicker_van" \
			and receipt.get("choice_id") == "hire_unpicker" \
			and _emberglass_gate.get_service_kind() == "Unpicker"
		paid_threadmill = _emberglass_gate.get_event_id() == "v3_threadmill_sewing_circle" \
			and receipt.get("choice_id") == "borrow_spools" \
			and _emberglass_gate.get_service_kind() == "SewingCircle"
		if paid_inkblack:
			# Preflight every live ledger using the *post-hire* wallet before the debit.
			if not _inkblack_unpicker_auth.is_empty() or not _emberglass_campfire_auth.is_empty() \
				or not _threadmill_sewing_auth.is_empty():
				return
			pending_unpicker = _preflight_unpicker_visit(run_map.get_current_node_id(),
				expected.wallet.gold)
			if pending_unpicker == null:
				return
		if paid_emberglass:
			# The map already committed this Event node when the parchment opened.
			# Preflight a real Campfire before spending either canonical price.
			var carry := party_carryover as RunTornCarryover
			if carry == null or carry._observer() == null or carry.read_state().heroes != run_heroes \
				or not _emberglass_campfire_auth.is_empty() or not _inkblack_unpicker_auth.is_empty() \
				or not _threadmill_sewing_auth.is_empty():
				return
			pending_visit = RunCampfireVisit.new(run_map.get_current_node_id(), run_heroes)
			if not pending_visit.read_state().ok:
				return
		if paid_threadmill:
			if not _threadmill_sewing_auth.is_empty() or not _inkblack_unpicker_auth.is_empty() \
				or not _emberglass_campfire_auth.is_empty():
				return
			pending_sewing = _preflight_sewing_visit(run_map.get_current_node_id())
			if pending_sewing == null:
				return
		var service := _emberglass_gate.choose_with_wallet(receipt.get("choice_id"),
			{"gold": session_gold, "scraps": run_scraps})
		if not service.get("ok", false) or service.event_id != expected.event_id \
			or service.choice_id != expected.choice_id or service.wallet != expected.wallet \
			or service.service_request != ({"stop_type": "Campfire"} if paid_emberglass else \
				({"stop_type": "Unpicker"} if paid_inkblack else \
				({"stop_type": "SewingCircle"} if paid_threadmill else {}))):
			return
		if paid_emberglass:
			_emberglass_campfire_auth = [run_map, run_map.get_generation_revision(),
				run_map.get_floors(), run_map.get_route(), run_map.get_current_node_id(),
				_emberglass_gate]
		if paid_inkblack:
			_inkblack_unpicker_auth = [run_map, run_map.get_generation_revision(),
				run_map.get_floors(), run_map.get_route(), run_map.get_current_node_id(),
				_emberglass_gate]
		if paid_threadmill:
			_threadmill_sewing_auth = [run_map, run_map.get_generation_revision(),
				run_map.get_floors(), run_map.get_route(), run_map.get_current_node_id(),
				_emberglass_gate]
	session_gold = expected.wallet.gold
	run_scraps = expected.wallet.scraps
	if paid_inkblack or paid_threadmill:
		# The paid visit and any bound wardrobe must see one coherent wallet.
		_sync_bound_wardrobe(party_carryover as RunTornCarryover)
	_placeholder_map = source
	_placeholder_route = run_map.get_route()
	_clear_wallet_event()
	if paid_emberglass:
		_mount_campfire_visit(pending_visit)
	elif paid_inkblack:
		_mount_unpicker_visit(pending_unpicker)
	elif paid_threadmill:
		_mount_sewing_visit(pending_sewing)
	else:
		_present_connected_route(source)


func _commit_vital_event(receipt: Dictionary, panel, source: WeakRef) -> void:
	if not is_instance_valid(panel) or panel != wallet_event_panel or panel.get_parent() != self \
		or not panel.is_visible_in_tree() or not panel.has_open_event() \
		or source == null or source.get_ref() != run_map \
		or _wallet_event_context.is_empty() or _wallet_event_snapshot() != _wallet_event_context \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Event" \
		or not panel._vital_mode or panel._selector == null or not panel._selector.is_claimed() \
		or panel._committed_choice != receipt:
		return
	# The mounted Warden visit must still be the canonical gate's unclaimed
	# offer. Rebind its live opening snapshot to a fresh gate at commit time;
	# a signal or a detached RunEventChoice receipt alone is not authority.
	var expected: Dictionary
	if _wallet_event_record.get("id") == "v3_warden_buckle_heart_ward":
		if _vital_event_gate == null or not _vital_event_gate.is_valid() \
			or _vital_event_gate.get_event() != _wallet_event_record \
			or _vital_event_gate.get_snapshot() != panel._offered_snapshot:
			return
		var party_ids: Array = []
		var warden_snapshot: Dictionary = {}
		for hero in run_heroes:
			party_ids.append(hero.id)
			if hero.id == "warden" and hero.hp > 0:
				warden_snapshot = {"gold": session_gold, "scraps": run_scraps,
					"hero": {"id": hero.id, "hp": hero.hp, "max_hp": hero.max_hp}}
		if warden_snapshot.is_empty() or warden_snapshot != panel._offered_snapshot:
			return
		var fresh := RunV3HeroVitalEventGate.new(party_ids)
		if not fresh.is_valid():
			return
		var bound := fresh.enter(_wallet_event_record, warden_snapshot)
		if bound == null or not bound.is_valid():
			return
		expected = bound.choose_with_vitals(receipt.get("choice_id"))
	else:
		if _vital_event_gate != null:
			return
		expected = RunEventChoice.new(_wallet_event_record).choose_with_vitals(
			receipt.get("choice_id"), panel._offered_snapshot)
	if not expected.get("ok", false) or expected != receipt:
		return
	var carry := party_carryover as RunTornCarryover
	if carry == null or carry.read_state().heroes != run_heroes \
		or not carry.apply_vital_event(run_map.get_current_node_id(),
		_wallet_event_record, expected, panel._offered_snapshot, carry.read_state(),
		carry._wardrobe.get_snapshot() if carry._wardrobe != null else null):
		return
	run_heroes = carry.read_state().heroes
	session_gold = expected.state.gold
	run_scraps = expected.state.scraps
	_placeholder_map = source
	_placeholder_route = run_map.get_route()
	_clear_wallet_event()
	_present_connected_route(source)


func _clear_wallet_event() -> void:
	_wallet_event_context.clear()
	_wallet_event_record.clear()
	if is_instance_valid(wallet_event_panel):
		wallet_event_panel.close_event()
		remove_child(wallet_event_panel)
		wallet_event_panel.queue_free()
	wallet_event_panel = null
	_emberglass_gate = null
	_vital_event_gate = null


func _load_quiet_spool() -> Dictionary:
	if not FileAccess.file_exists(event_catalog_path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(event_catalog_path)) != OK:
		return {}
	var catalog: Variant = parser.data
	if not catalog is Dictionary or not catalog.get("events") is Array:
		return {}
	var matches: Array = catalog.events.filter(func(record):
		return record is Dictionary and record.get("id") == "quiet_spool")
	if matches.size() != 1 or not RunEventChoice.new(matches[0]).is_valid():
		return {}
	var record: Dictionary = matches[0]
	if record.choices.size() != 2:
		return {}
	var ids: Array = []
	for choice in record.choices:
		ids.append(choice.id)
	if not ids.has("watch") or not ids.has("ignore"):
		return {}
	for id in ["watch", "ignore"]:
		var receipt := RunEventChoice.new(record).choose_with_wallet(id, {"gold": 0, "scraps": 0})
		if not receipt.ok or receipt.wallet != {"gold": 0, "scraps": 1 if id == "watch" else 0}:
			return {}
	return record


func _quiet_spool_snapshot() -> Array:
	if run_map == null or run_rng == null or party_carryover == null or act_outcome == null \
		or not is_instance_valid(quiet_spool_panel) or quiet_spool_panel._selector == null:
		return []
	var carry := party_carryover as RunTornCarryover
	if carry == null:
		return []
	return [run_map, run_map.get_generation_revision(), run_map.get_floors(),
		run_map.get_route(), run_rng, run_rng.state, run_seed, run_deck.duplicate(),
		run_heroes.duplicate(true), run_trinkets.duplicate(), session_gold, run_scraps,
		run_removal_count, run_stitch_descriptors.duplicate(true), run_next_stitch_id,
		carry, carry.read_state(), carry.torn.read_state(), carry._wardrobe,
		carry._wardrobe.get_snapshot() if carry._wardrobe != null else {},
		act_outcome, act_outcome.get_state(), quiet_spool_panel, _quiet_spool_outcome,
		quiet_spool_panel._selector, quiet_spool_panel._selector.get_event()]


func _open_quiet_spool(id: String, source: WeakRef) -> bool:
	var record := _load_quiet_spool()
	if record.is_empty() or run_scraps < 0 or run_scraps == 9223372036854775807:
		return false
	var panel := preload("res://scenes/event_choice_panel.tscn").instantiate() as LiveEventChoicePanel
	add_child(panel)
	if not panel.open_event(record):
		panel.free()
		return false
	_mount_event_backdrop(panel)
	if not run_map.choose_node(id):
		panel.free()
		return false
	_clear_route_view()
	quiet_spool_panel = panel
	_quiet_spool_outcome = RunQuietSpoolOutcome.new()
	_quiet_spool_context = _quiet_spool_snapshot()
	panel.choice_committed.connect(_commit_quiet_spool.bind(panel, _quiet_spool_outcome, source))
	var buttons := panel.get_choice_buttons()
	for index in range(buttons.size()):
		buttons[index].focus_next = buttons[index].get_path_to(buttons[(index + 1) % buttons.size()])
		buttons[index].focus_previous = buttons[index].focus_next
	buttons[0].grab_focus()
	return true


func _commit_quiet_spool(event_id: String, choice_id: String, panel,
		outcome: RunQuietSpoolOutcome, source: WeakRef) -> void:
	if not is_instance_valid(panel) or panel != quiet_spool_panel or panel.get_parent() != self \
		or not panel.is_visible_in_tree() or not panel.has_open_event() \
		or outcome == null or outcome != _quiet_spool_outcome or outcome.is_consumed() \
		or source == null or source.get_ref() != run_map \
		or _quiet_spool_context.is_empty() or _quiet_spool_snapshot() != _quiet_spool_context \
		or panel._selector == null or not panel._selector.is_claimed() \
		or panel._committed_choice != {"ok": true, "event_id": event_id, "choice_id": choice_id} \
		or event_id != "quiet_spool" or choice_id not in ["watch", "ignore"]:
		return
	var receipt := outcome.choose(event_id, choice_id, run_scraps)
	if not receipt.ok:
		return
	run_scraps = receipt.scraps
	_quiet_spool_completed = true
	_placeholder_map = source
	_placeholder_route = run_map.get_route()
	_clear_quiet_spool()
	_present_connected_route(source)


func _clear_quiet_spool() -> void:
	_quiet_spool_context.clear()
	_quiet_spool_outcome = null
	if is_instance_valid(quiet_spool_panel):
		quiet_spool_panel.close_event()
		remove_child(quiet_spool_panel)
		quiet_spool_panel.queue_free()
	quiet_spool_panel = null


## The single authored Moth Infestation record, validated before a visit is
## mounted. Its three choices are exactly this transaction's supported branches.
func _load_moth_infestation() -> Dictionary:
	if not FileAccess.file_exists(moth_catalog_path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(moth_catalog_path)) != OK:
		return {}
	var record: Variant = parser.data
	if not record is Dictionary or not RunEventChoice.new(record).is_valid():
		return {}
	var event: Dictionary = record
	if event.get("id") != RunMothInfestationOutcome.EVENT_ID:
		return {}
	var choices: Variant = event.get("choices")
	if not choices is Array or (choices as Array).size() != 3:
		return {}
	var authored: Array = [RunMothInfestationOutcome.CHOICE_SACRIFICE,
		RunMothInfestationOutcome.CHOICE_FUMIGATE, RunMothInfestationOutcome.CHOICE_ESCAPE]
	var ids: Array = []
	for choice in choices:
		if not choice is Dictionary or not (choice as Dictionary).get("outcome") is Dictionary:
			return {}
		ids.append((choice as Dictionary).get("id"))
	if ids != authored:
		return {}
	# The authored outcomes must agree with the scene-free transaction amounts.
	var preview: Dictionary = RunEventChoice.new(event).preview_wallet_choices({"gold": 0, "scraps": 5})
	if preview.get("ok") != true or not preview.get("choices") is Array \
		or (preview.get("choices") as Array).size() != 3:
		return {}
	for index in range(3):
		var forecast: Dictionary = preview.choices[index]
		var expected: int = 0
		if authored[index] == RunMothInfestationOutcome.CHOICE_SACRIFICE:
			expected = RunMothInfestationOutcome.SACRIFICE_SCRAP_GAIN
		elif authored[index] == RunMothInfestationOutcome.CHOICE_FUMIGATE:
			expected = -RunMothInfestationOutcome.FUMIGATE_SCRAP_COST
		if forecast.get("choice_id") != authored[index] or forecast.get("affordable") != true \
			or forecast.get("gold_delta") != 0 or forecast.get("scraps_delta") != expected:
			return {}
	return event


## Index-accurate ordinary entries: authentic authored, non-composite deck slots.
## Composite IDs and counterfeit cards are never offered to the player.
func _moth_ordinary_indices() -> Array[int]:
	var indices: Array[int] = []
	for index in range(run_deck.size()):
		var card_id: String = run_deck[index]
		if card_id.is_empty() or run_stitch_descriptors.has(card_id) \
			or card_id.begins_with(RunRestStitchCards.ID_PREFIX):
			continue
		if RunRestStitchCards.resolve_card_definition(card_id).is_empty():
			continue
		indices.append(index)
	return indices


func _moth_card_text(index: int) -> String:
	return "Deck #%d: %s" % [index + 1, run_deck[index]]


## Mounts the ordinary-card selector above the authored choices. Every item
## carries its actual run-deck index, so duplicate IDs stay distinct occurrences.
func _mount_moth_picker(panel: LiveEventChoicePanel) -> bool:
	var box := VBoxContainer.new()
	box.name = "MothCardPickerBox"
	var prompt := Label.new()
	prompt.name = "MothCardPrompt"
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 19)
	box.add_child(prompt)
	var list := ItemList.new()
	list.name = "MothCardPicker"
	list.focus_mode = Control.FOCUS_ALL
	list.select_mode = ItemList.SELECT_SINGLE
	list.custom_minimum_size = Vector2(0, 88)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in _moth_ordinary_indices():
		list.add_item(_moth_card_text(index))
		list.set_item_metadata(list.item_count - 1, index)
	if list.item_count > 0:
		list.select(0)
	box.add_child(list)
	panel.choices_container.add_child(box)
	panel.choices_container.move_child(box, 0)
	_moth_picker = list
	list.item_selected.connect(_refresh_moth_card_cue.bind(list, prompt))
	list.item_selected.connect(func(_index): _refresh_moth_choices())
	_refresh_moth_card_cue(0, list, prompt)
	return true


func _refresh_moth_card_cue(index: int, list: ItemList, prompt: Label) -> void:
	if not is_instance_valid(list) or not is_instance_valid(prompt) or list != _moth_picker:
		return
	if list.item_count == 0:
		prompt.text = "Feed an ordinary card: none available"
		return
	var selected: PackedInt32Array = list.get_selected_items()
	var row: int = selected[0] if not selected.is_empty() else mini(index, list.item_count - 1)
	if row < 0 or row >= list.item_count:
		return
	prompt.text = "Feed an ordinary card - %s" % list.get_item_text(row)


## Reads the chosen occurrence, revalidated against the live deck and this
## picker's captured items. A composite or forged item never yields an index.
func _moth_selected_index() -> Variant:
	if not is_instance_valid(_moth_picker) or _moth_picker.item_count == 0:
		return null
	var ordinary := _moth_ordinary_indices()
	if ordinary.is_empty() or _moth_picker.item_count != ordinary.size():
		return null
	var selected: PackedInt32Array = _moth_picker.get_selected_items()
	if selected.size() != 1:
		return null
	var row: int = selected[0]
	if row < 0 or row >= ordinary.size():
		return null
	if typeof(_moth_picker.get_item_metadata(row)) != TYPE_INT \
		or _moth_picker.get_item_metadata(row) != ordinary[row] \
		or _moth_picker.get_item_text(row) != _moth_card_text(ordinary[row]):
		return null
	return ordinary[row]


func _moth_picker_item_indices() -> Array:
	var indices: Array = []
	if not is_instance_valid(_moth_picker):
		return indices
	for row in range(_moth_picker.item_count):
		indices.append(_moth_picker.get_item_metadata(row))
	return indices


## Disables exactly the authored branches this run cannot claim, before the
## panel is allowed to latch a choice.
func _refresh_moth_choices() -> void:
	if not is_instance_valid(moth_panel) or not is_instance_valid(_moth_picker):
		return
	if moth_panel._selector == null or moth_panel._selector.is_claimed():
		return
	var buttons := moth_panel.get_choice_buttons()
	if buttons.size() != 3:
		return
	buttons[0].disabled = _moth_selected_index() == null
	buttons[1].disabled = run_scraps < RunMothInfestationOutcome.FUMIGATE_SCRAP_COST
	buttons[2].disabled = false


## Selector first, then the three authored choices, both directions wrapping.
func _moth_focus_order() -> void:
	if not is_instance_valid(moth_panel) or not is_instance_valid(_moth_picker):
		return
	var controls: Array[Control] = [_moth_picker]
	for button in moth_panel.get_choice_buttons():
		controls.append(button)
	if controls.size() < 2:
		return
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(
			controls[(index - 1 + controls.size()) % controls.size()])
	_moth_picker.grab_focus()


func _moth_snapshot() -> Array:
	if run_map == null or run_rng == null or party_carryover == null or act_outcome == null \
		or not is_instance_valid(moth_panel) or not is_instance_valid(_moth_picker) \
		or moth_panel._selector == null:
		return []
	var carry := party_carryover as RunTornCarryover
	if carry == null:
		return []
	return [run_map, run_map.get_generation_revision(), run_map.get_floors(),
		run_map.get_route(), run_rng, run_rng.state, run_seed, run_deck.duplicate(),
		run_stitch_descriptors.duplicate(true), run_next_stitch_id,
		run_heroes.duplicate(true), run_trinkets.duplicate(), session_gold, run_scraps,
		run_removal_count, carry, carry.read_state(), carry.torn.read_state(), carry._wardrobe,
		carry._wardrobe.get_snapshot() if carry._wardrobe != null else {},
		act_outcome, act_outcome.get_state(), moth_panel, _moth_outcome, _moth_completed,
		moth_panel._selector, moth_panel._selector.get_event(), _moth_picker,
		_moth_picker.get_instance_id(), _moth_picker_item_indices(), _moth_picker.item_count]


## The run's second Event presents the accepted Moth Infestation transaction
## through the live connected route. The first Event stays Quiet Spool.
func _open_moth_infestation(id: String, source: WeakRef) -> bool:
	var record := _load_moth_infestation()
	if record.is_empty() or _moth_completed or is_instance_valid(moth_panel):
		return false
	var outcome := RunMothInfestationOutcome.new(run_deck, run_stitch_descriptors,
		run_next_stitch_id, run_scraps)
	if not outcome.is_valid():
		return false
	var panel := preload("res://scenes/event_choice_panel.tscn").instantiate() as LiveEventChoicePanel
	add_child(panel)
	if not panel.open_event(record):
		panel.free()
		return false
	_mount_event_backdrop(panel)
	moth_panel = panel
	if not _mount_moth_picker(panel) or not run_map.choose_node(id):
		_moth_picker = null
		moth_panel = null
		panel.free()
		return false
	_clear_route_view()
	_moth_outcome = outcome
	_moth_context = _moth_snapshot()
	panel.choice_committed.connect(_commit_moth_infestation.bind(panel, outcome, source))
	_refresh_moth_choices()
	_moth_focus_order()
	return true


func _commit_moth_infestation(event_id: String, choice_id: String, panel,
		outcome: RunMothInfestationOutcome, source: WeakRef) -> void:
	if not is_instance_valid(panel) or panel != moth_panel or panel.get_parent() != self \
		or not panel.is_visible_in_tree() or not panel.has_open_event() \
		or outcome == null or outcome != _moth_outcome or outcome.is_consumed() \
		or _moth_completed or source == null or source.get_ref() != run_map \
		or _moth_context.is_empty() or _moth_snapshot() != _moth_context \
		or panel._selector == null or not panel._selector.is_claimed() \
		or panel._committed_choice != {"ok": true, "event_id": event_id, "choice_id": choice_id} \
		or event_id != RunMothInfestationOutcome.EVENT_ID \
		or choice_id not in [RunMothInfestationOutcome.CHOICE_SACRIFICE,
			RunMothInfestationOutcome.CHOICE_FUMIGATE, RunMothInfestationOutcome.CHOICE_ESCAPE]:
		return
	var selected: Variant = null
	if choice_id == RunMothInfestationOutcome.CHOICE_SACRIFICE:
		selected = _moth_selected_index()
		if selected == null:
			return
	var receipt := outcome.choose(event_id, choice_id, selected)
	if receipt.get("ok") != true or receipt.get("event_id") != event_id \
		or receipt.get("choice_id") != choice_id \
		or not receipt.get("descriptors") is Dictionary \
		or typeof(receipt.get("next_stitch_id")) != TYPE_INT \
		or typeof(receipt.get("scraps")) != TYPE_INT or not receipt.get("deck") is Array:
		return
	# The receipt must describe exactly the selected occurrence and wallet.
	var settled: Array = receipt.get("deck")
	var scraps: int = receipt.get("scraps")
	if choice_id == RunMothInfestationOutcome.CHOICE_SACRIFICE:
		var expected := run_deck.duplicate()
		expected.remove_at(int(selected))
		if settled != expected \
			or scraps != run_scraps + RunMothInfestationOutcome.SACRIFICE_SCRAP_GAIN:
			return
	elif choice_id == RunMothInfestationOutcome.CHOICE_FUMIGATE:
		if settled != run_deck or scraps != run_scraps - RunMothInfestationOutcome.FUMIGATE_SCRAP_COST:
			return
	elif settled != run_deck or scraps != run_scraps:
		return
	run_deck.assign(settled)
	run_stitch_descriptors = (receipt.get("descriptors") as Dictionary).duplicate(true)
	run_next_stitch_id = receipt.get("next_stitch_id")
	run_scraps = scraps
	_moth_completed = true
	_placeholder_map = source
	_placeholder_route = run_map.get_route()
	_clear_moth()
	_present_connected_route(source)


## Releases the panel, selector, transaction and every captured binding.
func _clear_moth() -> void:
	_moth_context.clear()
	_moth_outcome = null
	_moth_picker = null
	if is_instance_valid(moth_panel):
		moth_panel.close_event()
		remove_child(moth_panel)
		moth_panel.queue_free()
	moth_panel = null


## The single authored Dye Vat record, validated before a visit is mounted. Its
## three choices are exactly this transaction's supported branches and their
## authored wallet rates must agree with the scene-free service.
func _load_dye_vat() -> Dictionary:
	if not FileAccess.file_exists(dye_vat_catalog_path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(dye_vat_catalog_path)) != OK:
		return {}
	var record: Variant = parser.data
	if not record is Dictionary or not RunEventChoice.new(record).is_valid():
		return {}
	var event: Dictionary = record
	if event.get("id") != RunDyeVatOutcome.EVENT_ID:
		return {}
	var choices: Variant = event.get("choices")
	if not choices is Array or (choices as Array).size() != 3:
		return {}
	var authored: Array = [RunDyeVatOutcome.CHOICE_IMMERSE, RunDyeVatOutcome.CHOICE_SKIM,
		RunDyeVatOutcome.CHOICE_LEAVE]
	var ids: Array = []
	for choice in choices:
		if not choice is Dictionary or not (choice as Dictionary).get("outcome") is Dictionary:
			return {}
		ids.append((choice as Dictionary).get("id"))
	if ids != authored:
		return {}
	# The authored outcomes must agree with the service amounts, and every one of
	# them is gold-neutral.
	var preview: Dictionary = RunEventChoice.new(event).preview_wallet_choices(
		{"gold": 0, "scraps": RunDyeVatOutcome.UPGRADE_SCRAP_COST})
	if preview.get("ok") != true or not preview.get("choices") is Array \
		or (preview.get("choices") as Array).size() != 3:
		return {}
	for index in range(3):
		var forecast: Dictionary = preview.choices[index]
		if forecast.get("choice_id") != authored[index] or forecast.get("affordable") != true \
			or forecast.get("gold_delta") != RunDyeVatOutcome.EXPECTED_GOLD \
			or forecast.get("scraps_delta") != int(RunDyeVatOutcome.EXPECTED_SCRAPS[authored[index]]):
			return {}
	return event


## The service's finalized eligible deck-occurrence projection, labels included.
func _dye_vat_options() -> Array:
	if _dye_vat_outcome == null:
		return []
	return _dye_vat_outcome.get_immerse_options()


func _dye_vat_option_text(option: Dictionary) -> String:
	return "Deck #%d: %s" % [int(option.get("index", 0)) + 1,
		String(option.get("display_name", ""))]


## Mounts the eligible-occurrence selector above the authored choices. Every item
## carries its actual run-deck index, so duplicate IDs stay distinct occurrences.
func _mount_dye_vat_picker(panel: LiveEventChoicePanel) -> bool:
	var box := VBoxContainer.new()
	box.name = "DyeVatPickerBox"
	var prompt := Label.new()
	prompt.name = "DyeVatPrompt"
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 19)
	box.add_child(prompt)
	var list := ItemList.new()
	list.name = "DyeVatPicker"
	list.focus_mode = Control.FOCUS_ALL
	list.select_mode = ItemList.SELECT_SINGLE
	list.custom_minimum_size = Vector2(0, 88)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option in _dye_vat_options():
		list.add_item(_dye_vat_option_text(option))
		list.set_item_metadata(list.item_count - 1, int(option.get("index", -1)))
	if list.item_count > 0:
		list.select(0)
	box.add_child(list)
	panel.choices_container.add_child(box)
	panel.choices_container.move_child(box, 0)
	_dye_vat_picker = list
	list.item_selected.connect(_refresh_dye_vat_card_cue.bind(list, prompt))
	list.item_selected.connect(func(_index): _refresh_dye_vat_choices())
	_refresh_dye_vat_card_cue(0, list, prompt)
	return true


func _refresh_dye_vat_card_cue(index: int, list: ItemList, prompt: Label) -> void:
	if not is_instance_valid(list) or not is_instance_valid(prompt) or list != _dye_vat_picker:
		return
	if list.item_count == 0:
		if run_scraps < RunDyeVatOutcome.UPGRADE_SCRAP_COST:
			prompt.text = "Immerse needs %d scraps (you have %d)" % [
				RunDyeVatOutcome.UPGRADE_SCRAP_COST, run_scraps]
		else:
			prompt.text = "Immerse a pool card - none eligible in this deck"
		return
	var selected: PackedInt32Array = list.get_selected_items()
	var row: int = selected[0] if not selected.is_empty() else mini(index, list.item_count - 1)
	if row < 0 or row >= list.item_count:
		return
	prompt.text = "Immerse one card - %s" % list.get_item_text(row)


## Reads the chosen occurrence, revalidated against the service's current
## projection and the live run deck. A forged item never yields an index.
func _dye_vat_selected_index() -> Variant:
	if not is_instance_valid(_dye_vat_picker) or _dye_vat_outcome == null:
		return null
	var options := _dye_vat_options()
	if options.is_empty() or _dye_vat_picker.item_count != options.size():
		return null
	var selected: PackedInt32Array = _dye_vat_picker.get_selected_items()
	if selected.size() != 1:
		return null
	var row: int = selected[0]
	if row < 0 or row >= options.size():
		return null
	var option: Dictionary = options[row]
	var index := int(option.get("index", -1))
	if typeof(_dye_vat_picker.get_item_metadata(row)) != TYPE_INT \
		or _dye_vat_picker.get_item_metadata(row) != index \
		or _dye_vat_picker.get_item_text(row) != _dye_vat_option_text(option) \
		or index < 0 or index >= run_deck.size() \
		or run_deck[index] != String(option.get("card_id", "")) \
		or String(RunDyeVatOutcome.resolve_authored_pool_upgrade(run_deck[index]).get(
			"upgrade_id", "")) != String(option.get("upgrade_id", "")):
		return null
	return index


func _dye_vat_picker_item_indices() -> Array:
	var indices: Array = []
	if not is_instance_valid(_dye_vat_picker):
		return indices
	for row in range(_dye_vat_picker.item_count):
		indices.append(_dye_vat_picker.get_item_metadata(row))
	return indices


## Disables exactly the authored branches this run cannot claim, before the
## panel is allowed to latch a choice. Skim and Leave stay usable.
func _refresh_dye_vat_choices() -> void:
	if not is_instance_valid(dye_vat_panel) or not is_instance_valid(_dye_vat_picker):
		return
	if dye_vat_panel._selector == null or dye_vat_panel._selector.is_claimed():
		return
	var buttons := dye_vat_panel.get_choice_buttons()
	if buttons.size() != 3:
		return
	buttons[0].disabled = _dye_vat_selected_index() == null
	buttons[1].disabled = false
	buttons[2].disabled = false
	_dye_vat_focus_order(false)


## Selector first, then every currently enabled authored choice, wrapping both
## ways. Disabled branches are skipped so Tab never strands on an unusable row.
func _dye_vat_focus_order(grab: bool) -> void:
	if not is_instance_valid(dye_vat_panel):
		return
	var controls: Array[Control] = []
	if is_instance_valid(_dye_vat_picker) and _dye_vat_picker.item_count > 0:
		controls.append(_dye_vat_picker)
	for button in dye_vat_panel.get_choice_buttons():
		if not button.disabled:
			controls.append(button)
	if controls.is_empty():
		return
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(
			controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(
			controls[(index - 1 + controls.size()) % controls.size()])
	if grab:
		controls[0].grab_focus()


## Full witness of this exact run map, node, visit and ledger. Selection is not
## part of it: only the committed account may authorize a claim.
func _dye_vat_snapshot() -> Array:
	if run_map == null or run_rng == null or party_carryover == null or act_outcome == null \
		or not is_instance_valid(dye_vat_panel) or not is_instance_valid(_dye_vat_picker) \
		or dye_vat_panel._selector == null:
		return []
	var carry := party_carryover as RunTornCarryover
	if carry == null:
		return []
	return [run_map, run_map.get_generation_revision(), run_map.get_floors(),
		run_map.get_route(), run_map.get_current_node_id(), _dye_vat_node,
		run_rng, run_rng.state, run_seed, run_deck.duplicate(),
		run_stitch_descriptors.duplicate(true), run_next_stitch_id,
		run_heroes.duplicate(true), run_trinkets.duplicate(), session_gold, run_scraps,
		run_removal_count, carry, carry.read_state(), carry.torn.read_state(), carry._wardrobe,
		carry._wardrobe.get_snapshot() if carry._wardrobe != null else {},
		act_outcome, act_outcome.get_state(), dye_vat_panel, _dye_vat_outcome,
		_dye_vat_completed, dye_vat_panel._selector, dye_vat_panel._selector.get_event(),
		_dye_vat_picker, _dye_vat_picker.get_instance_id(), _dye_vat_picker_item_indices(),
		_dye_vat_picker.item_count]


## The run's third Event presents the accepted Dye Vat transaction through the
## live connected route. Later Events use the generic wallet rotation.
func _open_dye_vat(id: String, source: WeakRef) -> bool:
	var record := _load_dye_vat()
	if record.is_empty() or _dye_vat_completed or is_instance_valid(dye_vat_panel):
		return false
	var outcome := RunDyeVatOutcome.new(run_deck, run_stitch_descriptors, run_scraps,
		run_next_stitch_id, record)
	if not outcome.is_valid():
		return false
	var panel := preload("res://scenes/event_choice_panel.tscn").instantiate() as LiveEventChoicePanel
	add_child(panel)
	if not panel.open_event(record):
		panel.free()
		return false
	_mount_event_backdrop(panel)
	dye_vat_panel = panel
	_dye_vat_outcome = outcome
	_dye_vat_node = id
	if not _mount_dye_vat_picker(panel) or not run_map.choose_node(id):
		_dye_vat_picker = null
		_dye_vat_outcome = null
		_dye_vat_node = ""
		dye_vat_panel = null
		panel.free()
		return false
	_clear_route_view()
	_dye_vat_context = _dye_vat_snapshot()
	panel.choice_committed.connect(_commit_dye_vat.bind(panel, outcome, source))
	_refresh_dye_vat_choices()
	_dye_vat_focus_order(true)
	return true


func _commit_dye_vat(event_id: String, choice_id: String, panel,
		outcome: RunDyeVatOutcome, source: WeakRef) -> void:
	if not is_instance_valid(panel) or panel != dye_vat_panel or panel.get_parent() != self \
		or not panel.is_visible_in_tree() or not panel.has_open_event() \
		or outcome == null or outcome != _dye_vat_outcome or outcome.is_claimed() \
		or _dye_vat_completed or _dye_vat_node.is_empty() or source == null \
		or source.get_ref() != run_map or run_map.get_current_node_id() != _dye_vat_node \
		or _dye_vat_context.is_empty() or _dye_vat_snapshot() != _dye_vat_context \
		or panel._selector == null or not panel._selector.is_claimed() \
		or panel._committed_choice != {"ok": true, "event_id": event_id, "choice_id": choice_id} \
		or event_id != RunDyeVatOutcome.EVENT_ID \
		or choice_id not in [RunDyeVatOutcome.CHOICE_IMMERSE, RunDyeVatOutcome.CHOICE_SKIM,
			RunDyeVatOutcome.CHOICE_LEAVE]:
		return
	# The panel latches a choice only from its own enabled, visible control, and
	# disables every button afterwards; the receipt below is the final arbiter.
	var buttons: Array[Button] = panel.get_choice_buttons()
	if buttons.size() != 3:
		return
	for choice in panel._selector.get_event().get("choices", []):
		if not choice is Dictionary or not choice.get("outcome") is Dictionary \
			or int(choice.outcome.get("gold", -1)) != RunDyeVatOutcome.EXPECTED_GOLD \
			or int(choice.outcome.get("scraps", 0)) != int(
				RunDyeVatOutcome.EXPECTED_SCRAPS.get(choice.get("id"), 0)):
			return
	var selected: Variant = null
	if choice_id == RunDyeVatOutcome.CHOICE_IMMERSE:
		selected = _dye_vat_selected_index()
		if selected == null:
			return
	var receipt := outcome.choose(event_id, choice_id, selected)
	if receipt.get("ok") != true or receipt.get("event_id") != event_id \
		or receipt.get("choice_id") != choice_id \
		or not receipt.get("deck") is Array \
		or not receipt.get("descriptors") is Dictionary \
		or typeof(receipt.get("next_stitch_id")) != TYPE_INT \
		or typeof(receipt.get("scraps")) != TYPE_INT:
		return
	# The receipt must describe exactly the selected occurrence, the expected
	# scraps delta and the untouched descriptors/cursor.
	var settled: Array = receipt.get("deck")
	var scraps: int = receipt.get("scraps")
	if receipt.get("descriptors") != run_stitch_descriptors \
		or int(receipt.get("next_stitch_id", -1)) != run_next_stitch_id:
		return
	if choice_id == RunDyeVatOutcome.CHOICE_IMMERSE:
		var index := int(selected)
		if index < 0 or index >= run_deck.size() or receipt.get("selected_index") != index \
			or String(receipt.get("replaced_card_id", "")) != run_deck[index]:
			return
		var upgrade_id := String(receipt.get("upgrade_card_id", ""))
		if upgrade_id.is_empty() or upgrade_id != String(
			RunDyeVatOutcome.resolve_authored_pool_upgrade(run_deck[index]).get("upgrade_id", "")):
			return
		var expected := run_deck.duplicate()
		expected[index] = upgrade_id
		if settled != expected or scraps != run_scraps - RunDyeVatOutcome.UPGRADE_SCRAP_COST:
			return
	elif choice_id == RunDyeVatOutcome.CHOICE_SKIM:
		if settled != run_deck or scraps != run_scraps + RunDyeVatOutcome.SKIM_SCRAP_GAIN:
			return
	elif settled != run_deck or scraps != run_scraps + RunDyeVatOutcome.LEAVE_SCRAP_GAIN:
		return
	# Every validated receipt is gold-neutral: each authored choice's gold delta
	# is zero, and the run ledger's gold is never assigned here.
	run_deck.assign(settled)
	run_stitch_descriptors = (receipt.get("descriptors") as Dictionary).duplicate(true)
	run_next_stitch_id = receipt.get("next_stitch_id")
	run_scraps = scraps
	_dye_vat_completed = true
	_placeholder_map = source
	_placeholder_route = run_map.get_route()
	_clear_dye_vat()
	_present_connected_route(source)


## Releases the panel, selector, transaction and every captured binding.
func _clear_dye_vat() -> void:
	_dye_vat_context.clear()
	_dye_vat_outcome = null
	_dye_vat_picker = null
	_dye_vat_node = ""
	if is_instance_valid(dye_vat_panel):
		dye_vat_panel.close_event()
		remove_child(dye_vat_panel)
		dye_vat_panel.queue_free()
	dye_vat_panel = null


var patch_stall_view: LivePatchStallPanel
var patch_stall_visit: RunShopVisit
var patch_stall_service: RunPatchStallVisit
var patch_stall_purchases: RunShopPurchases
var _patch_stall_wardrobe: RunPatchWardrobe
var _patch_stall_original: Dictionary = {}
var _patch_stall_context: Array = []
var _patch_stall_closed := false
var _patch_stall_visits: Dictionary = {}


func _patch_stall_snapshot() -> Array:
	if patch_stall_visit == null or patch_stall_purchases == null or _patch_stall_wardrobe == null \
		or patch_stall_service == null or act_outcome == null:
		return []
	return [_sewing_context(), act_outcome, act_outcome.get_state(), patch_stall_visit,
		patch_stall_visit.get_state(), patch_stall_purchases, patch_stall_purchases.get_state(),
		patch_stall_purchases.get_stock(), patch_stall_purchases.patch_stall_choice_used(),
		_patch_stall_wardrobe, _patch_stall_wardrobe.get_snapshot(), patch_stall_view,
		patch_stall_view.offer_buttons.duplicate() if is_instance_valid(patch_stall_view) else [],
		patch_stall_view.wearer_buttons.duplicate() if is_instance_valid(patch_stall_view) else [],
		patch_stall_view.leave_button if is_instance_valid(patch_stall_view) else null,
		patch_stall_service, patch_stall_service.read_state(), patch_stall_service.quote()]


func _choose_patch_stall_route(id: String, source: WeakRef, prior: Array[String], button) -> bool:
	if not _can_choose_connected_route() or source == null or source.get_ref() != run_map \
		or not is_instance_valid(route_view) or not route_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button not in route_buttons \
		or button.get_parent() != route_view or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("route_id", "") != id or button.get_meta("route_kind", "") != "PatchStall" \
		or run_map.get_route() != prior or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") != "PatchStall" \
		or button.get_meta("sewing_source", {}) != _sewing_context():
		return false
	var carry := party_carryover as RunTornCarryover
	var definitions := RunAuthoredPatchDefinitions.load_definitions()
	if carry == null or definitions.is_empty():
		return false
	var wardrobe := carry._wardrobe
	if wardrobe == null:
		wardrobe = RunPatchWardrobe.new(run_heroes, run_trinkets, definitions,
			run_scraps, session_gold, run_deck, run_seed, true)
	var w := wardrobe.get_snapshot()
	if not wardrobe.is_valid() or w.heroes != run_heroes or w.owned != run_trinkets \
		or w.gold != session_gold or w.scraps != run_scraps or w.cards != run_deck \
		or w.seed != run_seed or w.rest_id != "" or not carry.can_bind_wardrobe(wardrobe, carry.torn, w):
		return false
	var authored: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	if not authored is Dictionary or not authored.get("trinkets") is Array:
		return false
	var visit := RunShopVisit.new(run_deck, session_gold, run_removal_count, run_trinkets,
		run_stitch_descriptors, run_next_stitch_id)
	if not visit.get_state().valid:
		return false
	var rng_before := run_rng.state
	# The live route hands the genuine completed-run unlock flag to the stock
	# service so an unlocked player's real seeded stall can offer the two
	# authored P12 Heirlooms; the rare catalog stays the shipped one the
	# service loads itself, and a locked run keeps the legacy draws.
	var sampled := RunShopPurchases.sample_patch_stall_offers(run_rng, authored.trinkets,
		run_trinkets, null, heirloom_unlocked)
	if not sampled.ok:
		return false
	var ids: Array = []
	for hero in run_heroes:
		ids.append(hero.id)
	var purchases := RunShopPurchases.new(ids, run_deck, run_trinkets, session_gold, [], sampled.offers, "patch_stall")
	if not purchases.is_valid() or not run_map.choose_node(id):
		run_rng.state = rng_before
		return false
	if not visit.open_visit(id):
		run_map.undo_choice(id, prior)
		run_rng.state = rng_before
		return false
	var service := RunPatchStallVisit.new(run_map.get_current_node_id(), ids,
		run_deck, run_trinkets, session_gold, sampled.offers)
	if not service.is_valid():
		run_map.undo_choice(id, prior)
		run_rng.state = rng_before
		return false
	_clear_route_view()
	if is_instance_valid(patch_stall_view):
		patch_stall_view.close()
		patch_stall_view.free()
	patch_stall_visit = visit
	patch_stall_service = service
	patch_stall_purchases = purchases
	_patch_stall_wardrobe = wardrobe
	_patch_stall_closed = false
	patch_stall_view = LivePatchStallPanel.new()
	patch_stall_view.name = "PatchStall"
	patch_stall_view.position = Vector2(190, 45)
	add_child(patch_stall_view)
	patch_stall_view.bind(service)
	patch_stall_view.intent_requested.connect(_patch_stall_action.bind(
		weakref(patch_stall_view), service, service.read_state(), service.quote()))
	_patch_stall_context = _patch_stall_snapshot()
	return true


func _patch_stall_action(intent: Dictionary, source: WeakRef, service: RunPatchStallVisit,
		bound: Dictionary, quoted: Dictionary) -> void:
	_try_patch_stall_action(intent, source, service, bound, quoted)
	# A refused optimistic submission must remain retryable after its authority
	# is restored. Rebinding also retires that rejected generation's callbacks.
	if source != null and is_instance_valid(patch_stall_view) and source.get_ref() == patch_stall_view \
		and patch_stall_view._submitted and service == patch_stall_view._visit \
		and service != null and not service.is_consumed():
		patch_stall_view.bind(service)


func _try_patch_stall_action(intent: Dictionary, source: WeakRef, service: RunPatchStallVisit,
		bound: Dictionary, quoted: Dictionary) -> void:
	if _patch_stall_closed or _patch_stall_context.is_empty() or source == null \
		or not is_instance_valid(patch_stall_view) or source.get_ref() != patch_stall_view \
		or service == null or service != patch_stall_service or service.is_consumed() \
		or patch_stall_view.get_parent() != self or not patch_stall_view.is_visible_in_tree() \
		or _patch_stall_snapshot() != _patch_stall_context \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "PatchStall":
		return
	var view := patch_stall_view
	var service_state := service.read_state()
	var node_id := run_map.get_current_node_id()
	if service_state != bound or service.quote() != quoted or service_state.node_id != node_id \
		or service_state.status != "available" or view._visit != service \
		or view._source != bound or view._quoted != quoted or not view._submitted \
		or not view._connections.is_empty() or not view._valid_receipts(bound, quoted, view._slots):
		return
	var keys := intent.keys()
	keys.sort()
	var required := ["action", "expected_snapshot", "node_id", "visit_id"]
	if intent.get("action") == "buy_patch":
		required.append_array(["patch_id", "wearer_id"])
	elif intent.get("action") != "leave":
		return
	required.sort()
	if keys != required or intent.node_id != node_id or intent.visit_id != bound.visit_id \
		or intent.expected_snapshot != bound.snapshot or view._wearer_index < 0 or view._wearer_index >= 3:
		return
	# Submission disables the whole panel synchronously before emitting. Recheck
	# every physical control and its full source caption at this controller boundary.
	for i in range(3):
		var pin := view.wearer_buttons[i]
		var action := view.offer_buttons[i]
		if not view._attached(pin) or not pin.disabled or pin.text != view._wearer_caption(i) \
			or pin.get_meta("wearer_id", "") != bound.snapshot.party_ids[i] \
			or not view._attached(action) or not action.disabled or action.text != view._offer_caption(i) \
			or action.get_meta("patch_id", "") != quoted.offers[i].id:
			return
	if not view._attached(view.leave_button) or not view.leave_button.disabled \
		or view.leave_button.text != view.LEAVE_CAPTION or view.wallet_label.text != view._wallet_caption():
		return
	var visit := patch_stall_visit
	if intent.action == "buy_patch":
		if not intent.patch_id is String or not intent.wearer_id is String \
			or intent.wearer_id != bound.snapshot.party_ids[view._wearer_index]:
			return
		var offer: Dictionary = {}
		for listing in quoted.offers:
			if listing.id == intent.patch_id:
				offer = listing
		if offer.is_empty() or offer.sold or session_gold < offer.price:
			return
		var receipt := patch_stall_service.preview_purchase(offer.id, service_state.visit_id, node_id, service_state.snapshot)
		if receipt.is_empty():
			return
		var carry := party_carryover as RunTornCarryover
		var w := _patch_stall_wardrobe.get_snapshot()
		if carry == null or not carry.can_bind_wardrobe(_patch_stall_wardrobe, carry.torn, w):
			return
		var result := RunShopPatchSewing.purchase_and_sew(patch_stall_purchases, visit, _patch_stall_wardrobe,
			run_map.get_current_node_id(), offer.id, intent.wearer_id, w.definitions.get(offer.id),
			"patch_stall:%s" % run_map.get_current_node_id(), patch_stall_purchases.get_state(),
			patch_stall_purchases.get_stock(), visit.get_state(), w)
		if not result.ok:
			return
		assert(result.purchase_receipt == receipt, "Atomic purchase must match service preflight")
		var reconciled := patch_stall_service.reconcile_purchase(result.purchase_receipt,
			service_state.visit_id, node_id, service_state.snapshot)
		assert(reconciled, "Successful identical atomic receipt must consume the service")
		run_trinkets.assign(result.wardrobe_state.owned)
		run_scraps = result.wardrobe_state.scraps
		session_gold = result.wardrobe_state.gold
		carry.bind_wardrobe(_patch_stall_wardrobe, carry.torn, result.wardrobe_state)
	else:
		if not patch_stall_service.leave(service_state.visit_id, node_id, service_state.snapshot).ok:
			return
	visit.close_visit()
	_patch_stall_closed = true
	_patch_stall_original = _sewing_context()
	_patch_stall_visits[run_map.get_current_node_id()] = [run_map, run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route()]
	for connection in view.intent_requested.get_connections():
		view.intent_requested.disconnect(connection.callable)
	view.close()
	view.queue_free()
	patch_stall_view = null
	_patch_stall_context = _patch_stall_snapshot()
	_present_connected_route(weakref(run_map))


var campfire_view: LiveCampfirePanel
var campfire_heal_button: Button
var campfire_leave_button: Button
var campfire_visit: RunCampfireVisit
var _campfire_original: Dictionary = {}
var _campfire_closed := false
var _campfire_visits: Dictionary = {}
## Historical legacy Upgrade/Stitch completions need a witness too: they do not heal.
var _legacy_rest_visits: Dictionary = {}


var unpicker_view: LiveUnpickerPanel
var unpicker_remove_button: Button
var unpicker_leave_button: Button
var unpicker_visit: RunUnpickerVisit
var _unpicker_source: Dictionary = {}
var _unpicker_original: Dictionary = {}
var _unpicker_closed := false
var _unpicker_visits: Dictionary = {}


func _choose_unpicker_route(id: String, source: WeakRef, prior: Array[String], button) -> bool:
	if not _can_choose_connected_route() or source == null or source.get_ref() != run_map \
		or not is_instance_valid(route_view) or not route_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button not in route_buttons \
		or button.get_parent() != route_view or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("route_id", "") != id or button.get_meta("route_kind", "") != "Unpicker" \
		or run_map.get_route() != prior or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") != "Unpicker" \
		or button.get_meta("sewing_source", {}) != _sewing_context():
		return false
	var carry := party_carryover as RunTornCarryover
	if carry == null or carry._observer() == null or carry.read_state().heroes != run_heroes:
		return false
	if carry._wardrobe != null:
		var state := carry._wardrobe.get_snapshot()
		if not carry._wardrobe.is_valid() or state.heroes != run_heroes or state.cards != run_deck \
			or state.owned != run_trinkets or state.scraps != run_scraps or state.gold != session_gold \
			or state.seed != run_seed or state.rest_id != "" \
			or not carry.can_bind_wardrobe(carry._wardrobe, carry.torn, state):
			return false
	var visit := RunUnpickerVisit.new(id, run_deck, session_gold, run_removal_count,
		run_stitch_descriptors, run_next_stitch_id)
	if not visit.is_valid() or not run_map.choose_node(id):
		return false
	_clear_route_view()
	_mount_unpicker_visit(visit)
	return true


## Event service preflight is a read-only check of the live run's actual deck,
## stitch allocator, paid wallet and carryover/wardrobe identity.
func _preflight_unpicker_visit(id: String, post_payment_gold: int) -> RunUnpickerVisit:
	if run_map == null or run_map.get_current_node_id() != id or run_rng == null \
		or (is_instance_valid(unpicker_view) and not _unpicker_closed):
		return null
	var carry := party_carryover as RunTornCarryover
	if carry == null or carry._observer() == null or carry.read_state().heroes != run_heroes:
		return null
	if carry._wardrobe != null:
		var state := carry._wardrobe.get_snapshot()
		if not carry._wardrobe.is_valid() or state.heroes != run_heroes or state.cards != run_deck \
			or state.owned != run_trinkets or state.scraps != run_scraps or state.gold != session_gold \
			or state.seed != run_seed or state.rest_id != "" \
			or not carry.can_bind_wardrobe(carry._wardrobe, carry.torn, state):
			return null
	var visit := RunUnpickerVisit.new(id, run_deck, post_payment_gold, run_removal_count,
		run_stitch_descriptors, run_next_stitch_id)
	return visit if visit.is_valid() and visit.read_state().gold == post_payment_gold else null


## Reuse the typed Unpicker's one-use physical panel without choosing a second map node.
func _mount_unpicker_visit(visit: RunUnpickerVisit) -> void:
	if visit == null or not visit.is_valid():
		return
	if is_instance_valid(unpicker_view):
		unpicker_view.free()
	unpicker_visit = visit
	_unpicker_source = visit.read_state()
	_unpicker_closed = false
	unpicker_view = LiveUnpickerPanel.new()
	unpicker_view.name = "Unpicker"
	unpicker_view.position = Vector2(200, 60)
	add_child(unpicker_view)
	unpicker_view.bind(visit)
	unpicker_remove_button = unpicker_view.remove_button
	unpicker_leave_button = unpicker_view.leave_button
	unpicker_view.decision_requested.connect(_unpicker_decision.bind(unpicker_view, visit))
	_unpicker_original = _sewing_context()


func _unpicker_decision(intent: Dictionary, view, visit: RunUnpickerVisit) -> void:
	if _unpicker_closed or _unpicker_original.is_empty() or _unpicker_original != _sewing_context() \
		or visit == null or visit != unpicker_visit or visit.read_state() != _unpicker_source \
		or not is_instance_valid(view) or view != unpicker_view or view.get_parent() != self \
		or not view.is_visible_in_tree() or view._visit != visit or view._source != _unpicker_source \
		or view.wallet_label.text != view._quote_line() \
		or unpicker_remove_button != view.remove_button or unpicker_leave_button != view.leave_button \
		or not view._submitted or run_map == null \
		or run_map.get_current_node_id() != _unpicker_source.get("node_id") \
		or not (run_map.get_node(run_map.get_current_node_id()).get("type") == "Unpicker" \
			or _inkblack_unpicker_active(run_map.get_current_node_id())):
		return
	var id := run_map.get_current_node_id()
	if intent.get("visit_id") != _unpicker_source.visit_id or intent.get("node_id") != id \
		or intent.get("expected_snapshot") != _unpicker_source:
		return
	var staged := RunUnpickerVisit.new(id, run_deck, session_gold, run_removal_count,
		run_stitch_descriptors, run_next_stitch_id)
	if not staged.is_valid() or not staged.matches_mounted_source(_unpicker_source):
		return
	var result: Dictionary
	match intent.get("action"):
		"remove_card":
			var card: Variant = intent.get("selected_card_id")
			if intent.size() != 5 or typeof(card) != TYPE_STRING or card != view._selected_id \
				or not run_deck.has(card) or not view._honest_row(view._selected_button, card, true):
				return
			result = visit.remove_card(card, intent.visit_id, id, intent.expected_snapshot)
		"leave":
			if intent.size() != 4:
				return
			result = visit.leave(intent.visit_id, id, intent.expected_snapshot)
		_:
			return
	if not result.ok or result.source_snapshot != _unpicker_source \
		or result.source_receipt != _unpicker_source.receipt or _unpicker_original != _sewing_context() \
		or result.visit_id != _unpicker_source.visit_id or not result.consumed:
		return
	# Publish the complete authenticated receipt without signals or RNG between fields.
	run_deck.assign(result.deck)
	session_gold = result.gold
	run_removal_count = result.prior_removals
	run_stitch_descriptors = result.descriptors.duplicate(true)
	run_next_stitch_id = result.next_stitch_id
	_sync_bound_wardrobe(party_carryover as RunTornCarryover)
	_unpicker_closed = true
	_unpicker_original = _sewing_context()
	_unpicker_visits[id] = [run_map, run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route()]
	view.close()
	_present_connected_route(weakref(run_map))


## Atlas preflight uses the original mounted chooser while its parent is hidden.
## All model and source checks run before the overlay is retired.
func _campfire_route_ready(id: String, source: WeakRef, prior: Array[String], button,
		atlas: bool = false) -> bool:
	if not _can_choose_connected_route() or source == null or source.get_ref() != run_map \
		or not is_instance_valid(route_view) or (not atlas and not route_view.is_visible_in_tree()) \
		or not is_instance_valid(button) or button not in route_buttons \
		or button.get_parent() != route_view or button.disabled or not button.visible \
		or (not atlas and not button.is_visible_in_tree()) \
		or button.get_meta("route_id", "") != id or button.get_meta("route_kind", "") != run_map.get_node(id).get("type") \
		or run_map.get_route() != prior or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") not in ["Campfire", "Rest"] \
		or button.get_meta("sewing_source", {}) != _sewing_context():
		return false
	var carry := party_carryover as RunTornCarryover
	if carry == null or carry._observer() == null or carry.read_state().heroes != run_heroes:
		return false
	if carry._wardrobe != null:
		var state := carry._wardrobe.get_snapshot()
		if not carry._wardrobe.is_valid() or state.heroes != run_heroes or state.cards != run_deck \
			or state.owned != run_trinkets or state.scraps != run_scraps or state.gold != session_gold \
			or state.seed != run_seed or state.rest_id != "" \
			or not carry.can_bind_wardrobe(carry._wardrobe, carry.torn, state):
			return false
	return RunCampfireVisit.new(id, run_heroes).read_state().ok


func _choose_campfire_route(id: String, source: WeakRef, prior: Array[String], button) -> bool:
	if not _campfire_route_ready(id, source, prior, button):
		return false
	var visit := RunCampfireVisit.new(id, run_heroes)
	if not visit.read_state().ok or not run_map.choose_node(id):
		return false
	_mount_campfire_visit(visit)
	return true


## Shared live visit presenter: a paid Event uses the already-committed node,
## while normal Campfire/Rest admission still chooses its route exactly once.
func _mount_campfire_visit(visit: RunCampfireVisit) -> void:
	_clear_route_view()
	if is_instance_valid(campfire_view):
		remove_child(campfire_view)
		campfire_view.queue_free()
	campfire_visit = visit
	_campfire_closed = false
	campfire_view = LiveCampfirePanel.new()
	campfire_view.name = "Campfire"
	campfire_view.position = Vector2(200, 60)
	add_child(campfire_view)
	campfire_view.bind(visit)
	campfire_heal_button = campfire_view.heal_button
	campfire_leave_button = campfire_view.leave_button
	var snapshot := visit.read_state()
	campfire_view.decision_requested.connect(_campfire_action.bind(campfire_view, visit, snapshot))
	campfire_heal_button.focus_next = campfire_heal_button.get_path_to(campfire_leave_button)
	campfire_leave_button.focus_next = campfire_leave_button.get_path_to(campfire_heal_button)
	campfire_heal_button.focus_previous = campfire_heal_button.focus_next
	campfire_leave_button.focus_previous = campfire_leave_button.focus_next
	_campfire_original = _sewing_context()
	# The panel's authentic preview gain decides the safe default focus: Heal
	# only when the party can recover, Leave for a fully healed party.
	campfire_view._focus_default()


func _campfire_action(intent: Dictionary, view,
		visit: RunCampfireVisit, snapshot: Dictionary) -> void:
	if not _commit_campfire_action(intent, view, visit, snapshot):
		# A refused submission spends neither the service nor the UI's next attempt.
		# Rebinding also retires the callback generation that emitted this request.
		if is_instance_valid(view) and view == campfire_view and visit == campfire_visit \
			and not _campfire_closed and view._submitted and visit.read_state() == snapshot:
			view.bind(visit)


func _commit_campfire_action(intent: Dictionary, view,
		visit: RunCampfireVisit, snapshot: Dictionary) -> bool:
	if _campfire_closed or _campfire_original.is_empty() or _campfire_original != _sewing_context() \
		or visit == null or visit != campfire_visit or not is_instance_valid(view) \
		or view != campfire_view or view.get_parent() != self or not view.is_visible_in_tree() \
		or not view._submitted or view._visit != visit or view._snapshot != snapshot \
		or not view._display_current() or run_map == null \
		or (run_map.get_node(run_map.get_current_node_id()).get("type") not in ["Campfire", "Rest"] \
			and not _emberglass_campfire_active(run_map.get_current_node_id())):
		return false
	var id := run_map.get_current_node_id()
	if intent.size() != 4 or intent.get("action") not in ["heal", "leave"] \
		or intent.get("source_visit") != visit or intent.get("node_id") != id \
		or intent.get("expected_heroes") != snapshot.get("heroes") \
		or snapshot != {"ok": true, "node_id": id, "status": RunCampfireVisit.OPEN, "heroes": run_heroes} \
		or visit.read_state() != snapshot:
		return false
	var carry := party_carryover as RunTornCarryover
	if carry == null or carry._observer() == null or carry.read_state().heroes != run_heroes:
		return false
	if carry._wardrobe != null:
		var state := carry._wardrobe.get_snapshot()
		if not carry._wardrobe.is_valid() or state.heroes != run_heroes or state.cards != run_deck \
			or state.owned != run_trinkets or state.scraps != run_scraps or state.gold != session_gold \
			or state.seed != run_seed or state.rest_id != "" \
			or not carry.can_bind_wardrobe(carry._wardrobe, carry.torn, state):
			return false
	var staged := RunCampfireVisit.new(id, run_heroes)
	var receipt := staged.choose_heal(id, run_heroes) if intent.action == "heal" else staged.leave(id, run_heroes)
	if not receipt.ok or receipt.node_id != id:
		return false
	if intent.action == "heal":
		if carry == null or carry._observer() == null or carry.read_state().completed_rests.has(id):
			return false
		var proposed := carry._observer().apply_rest(id, run_heroes, true)
		if not proposed.ok or proposed.heroes != receipt.heroes:
			return false
		var recovered := carry.choose_rest_heal(id)
		if not recovered.ok or recovered.heroes != receipt.heroes:
			return false
		run_heroes = recovered.heroes.duplicate(true)
	campfire_visit = staged
	_campfire_closed = true
	_campfire_original = _sewing_context()
	_campfire_visits[id] = [run_map, run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route()]
	view.close()
	_present_connected_route(weakref(run_map))
	return true


var sewing_view: LiveSewingCirclePanel
var sewing_visit: RunSewingCircleVisit
var sewing_upgrade_button: Button
var sewing_stitch_button: Button
var sewing_leave_button: Button
var _sewing_source: Dictionary = {}
var _sewing_original: Dictionary = {}
var _sewing_closed := false
var _sewing_visits: Dictionary = {}


## Exact authorities, including identities as well as detached mutable state.
func _sewing_context() -> Dictionary:
	if run_map == null or run_rng == null or party_carryover == null:
		return {}
	var carry := party_carryover as RunTornCarryover
	var wardrobe := carry._wardrobe if carry != null else null
	return {"map": run_map, "revision": run_map.get_generation_revision(),
		"floors": run_map.get_floors(), "route": run_map.get_route(),
		"heroes": run_heroes.duplicate(true), "party": party,
		"live_heroes": party.get_heroes() if party != null else [],
		"carry": party_carryover, "ledger": party_carryover.read_state(),
		"torn": carry.torn.read_state() if carry != null else {},
		"wardrobe": wardrobe, "wardrobe_state": wardrobe.get_snapshot() if wardrobe != null else {},
		"rng": run_rng, "rng_state": run_rng.state, "rng_seed": run_rng.seed, "seed": run_seed,
		"gold": session_gold, "scraps": run_scraps, "patches": run_trinkets.duplicate(),
		"removals": run_removal_count, "deck": run_deck.duplicate(),
		"descriptors": run_stitch_descriptors.duplicate(true), "cursor": run_next_stitch_id}


## Event service preflight is a read-only check of the live run's actual deck,
## stitch allocator, scraps and carryover/wardrobe identity.
func _preflight_sewing_visit(id: String) -> RunSewingCircleVisit:
	if run_map == null or run_map.get_current_node_id() != id or run_rng == null \
		or run_map.get_node(id).get("type") != "Event" \
		or (is_instance_valid(sewing_view) and not _sewing_closed):
		return null
	var carry := party_carryover as RunTornCarryover
	if carry == null or carry._observer() == null or carry.read_state().heroes != run_heroes:
		return null
	if carry._wardrobe != null:
		var state := carry._wardrobe.get_snapshot()
		if not carry._wardrobe.is_valid() or state.heroes != run_heroes or state.cards != run_deck \
			or state.owned != run_trinkets or state.scraps != run_scraps or state.gold != session_gold \
			or state.seed != run_seed or state.rest_id != "" \
			or not carry.can_bind_wardrobe(carry._wardrobe, carry.torn, state):
			return null
	var canonical := RunRestCardUpgrade.list_authored_choices(run_deck, run_stitch_descriptors, run_next_stitch_id)
	if not canonical.ok or not RunRestStitchCards.new(run_deck, run_stitch_descriptors,
			run_scraps, run_next_stitch_id).is_valid():
		return null
	var visit := RunSewingCircleVisit.new(id, run_deck, run_stitch_descriptors,
		run_scraps, run_next_stitch_id)
	return visit if visit.is_valid() else null


func _mount_sewing_visit(visit: RunSewingCircleVisit) -> void:
	if visit == null or not visit.is_valid():
		return
	if is_instance_valid(sewing_view):
		remove_child(sewing_view)
		sewing_view.queue_free()
	_sewing_closed = false
	sewing_visit = visit
	_sewing_source = visit.read_state()
	sewing_view = LiveSewingCirclePanel.new()
	sewing_view.name = "SewingCircle"
	sewing_view.position = Vector2(170, 50)
	sewing_view.bind(visit)
	add_child(sewing_view)
	sewing_upgrade_button = sewing_view.upgrade_button
	sewing_stitch_button = sewing_view.stitch_button
	sewing_leave_button = sewing_view.leave_button
	_sewing_original = _sewing_context()
	sewing_view.intent_requested.connect(_sewing_intent.bind(sewing_view, visit))


func _choose_sewing_route(id: String, source: WeakRef, prior: Array[String], button) -> bool:
	if not _can_choose_connected_route() or source == null or source.get_ref() != run_map \
		or not is_instance_valid(route_view) or not route_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button not in route_buttons \
		or button.get_parent() != route_view or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("route_id", "") != id or button.get_meta("route_kind", "") != "SewingCircle" \
		or run_map.get_route() != prior or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") != "SewingCircle" \
		or button.get_meta("sewing_source", {}) != _sewing_context():
		return false
	var context := _sewing_context()
	var wardrobe = context.wardrobe
	if wardrobe != null:
		var state: Dictionary = context.wardrobe_state
		if not wardrobe.is_valid() or state.heroes != run_heroes or state.cards != run_deck \
			or state.owned != run_trinkets or state.scraps != run_scraps or state.gold != session_gold \
			or state.seed != run_seed or state.rest_id != "" \
			or not context.carry.can_bind_wardrobe(wardrobe, context.carry.torn, state):
			return false
	var canonical := RunRestCardUpgrade.list_authored_choices(run_deck, run_stitch_descriptors, run_next_stitch_id)
	if not canonical.ok or not RunRestStitchCards.new(run_deck, run_stitch_descriptors,
			run_scraps, run_next_stitch_id).is_valid() or context != _sewing_context():
		return false
	var visit := RunSewingCircleVisit.new(id, run_deck, run_stitch_descriptors,
		run_scraps, run_next_stitch_id)
	if not visit.is_valid() or not run_map.choose_node(id):
		return false
	_clear_route_view()
	_mount_sewing_visit(visit)
	return true


func _sewing_intent(intent: Dictionary, view, visit: RunSewingCircleVisit) -> void:
	if _sewing_closed or _sewing_original.is_empty() \
		or not is_instance_valid(view) or view != sewing_view or view.get_parent() != self \
		or not view.is_visible_in_tree() or visit == null or visit != sewing_visit \
		or view._visit != visit or view._source != _sewing_source \
		or visit.read_state() != _sewing_source:
		return
	if _sewing_original != _sewing_context() \
		or run_map.get_current_node_id() != _sewing_source.node_id \
		or (run_map.get_node(_sewing_source.node_id).get("type") != "SewingCircle" \
			and not _threadmill_sewing_active(_sewing_source.node_id)) \
		or intent.get("node_id") != _sewing_source.node_id \
		or intent.get("visit_id") != _sewing_source.visit_id \
		or intent.get("source_snapshot") != _sewing_source:
		view.bind(visit)
		return
	# Authenticate the decision itself: only LiveSewingCirclePanel._confirm may
	# mint the submitted payload, and only that exact payload may settle. A
	# direct listener call with an otherwise source-valid intent is not a
	# player's confirmed choice, so it retires the pending selection and returns.
	if not view._submitted:
		view.bind(visit)
		return
	var confirmed: Dictionary = view.take_confirmed(intent)
	if confirmed.is_empty() or confirmed != intent \
		or confirmed.get("visit_id") != _sewing_source.visit_id \
		or confirmed.get("node_id") != _sewing_source.node_id \
		or confirmed.get("source_snapshot") != _sewing_source:
		view.bind(visit)
		return
	var result: Dictionary = {}
	match intent.get("action"):
		"upgrade": result = visit.choose_upgrade(intent.get("first_index"), _sewing_source.visit_id,
			_sewing_source.node_id, _sewing_source)
		"stitch": result = visit.choose_stitch(intent.get("first_index"), intent.get("second_index"),
			_sewing_source.visit_id, _sewing_source.node_id, _sewing_source)
		"leave": result = visit.leave(_sewing_source.visit_id, _sewing_source.node_id, _sewing_source)
	if not result.get("ok", false):
		view.bind(visit)
		return
	var consumed := visit.read_state()
	var receipt := result.duplicate(true)
	for key in ["ok", "action", "transaction", "source_snapshot", "source_receipt", "charged_scraps"]:
		receipt.erase(key)
	if not visit.is_consumed() or not result.get("consumed", false) or receipt != consumed \
		or result.source_snapshot != _sewing_source or result.source_receipt != _sewing_source.receipt \
		or result.node_id != _sewing_source.node_id or result.visit_id != _sewing_source.visit_id \
		or _sewing_original != _sewing_context():
		return
	# Publish every field from the single-use service receipt without signals or RNG.
	run_deck.assign(result.deck)
	run_stitch_descriptors = result.descriptors.duplicate(true)
	run_scraps = result.remaining_scraps
	run_next_stitch_id = result.next_stitch_id
	_sync_bound_wardrobe(party_carryover as RunTornCarryover)
	_sewing_closed = true
	_sewing_original = _sewing_context()
	_sewing_visits[run_map.get_current_node_id()] = [run_map, run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route()]
	view.close()
	_clear_visit_backdrop()
	_threadmill_sewing_auth.clear()
	_present_connected_route(weakref(run_map))


func _current_completed_rest() -> bool:
	return rest_recovery != null and ((rest_recovery.is_consumed() and _rest_committed_deck.is_empty() \
		and rest_stitch != null and not rest_stitch.is_consumed() \
		and rest_upgrade != null and not rest_upgrade.is_consumed() \
		and _stitch_snapshot() == _rest_stitch_source) or _completed_rest_upgrade() or _completed_rest_stitch()) \
		and run_map != null and _rest_map != null and _rest_map.get_ref() == run_map \
		and not _rest_route.is_empty() and run_map.get_route() == _rest_route \
		and run_map.get_node(run_map.get_current_node_id()).get("type") == "Rest" \
		and not _rest_committed_heroes.is_empty() and run_heroes == _rest_committed_heroes \
		and RunRestRecovery._is_valid_roster(run_heroes)


func _rest_upgrade_context() -> bool:
	return (_rest_wardrobe == null or _rest_patch_current(not rest_view.visible)) \
		and run_map != null and _rest_map != null and _rest_map.get_ref() == run_map \
		and not _rest_route.is_empty() and run_map.get_route() == _rest_route \
		and run_map.get_current_node_id() == _rest_route.back() \
		and run_map.get_node(_rest_route.back()).get("type") == "Rest" \
		and run_map.get_floors() == _rest_floors and run_map.get_generation_revision() == _rest_revision \
		and run_heroes == _rest_heroes and RunRestRecovery._is_valid_roster(run_heroes) \
		and party_carryover != null and party_carryover == _rest_carry \
		and _carryover_map != null and _carryover_map.get_ref() == run_map \
		and party_carryover.read_state() == _rest_ledger and _rest_ledger.get("ok", false) \
		and _rest_ledger.get("heroes") == run_heroes \
		and not _rest_ledger.get("completed_rests", []).has(_rest_route.back()) \
		and run_rng != null and run_rng == _rest_rng and run_rng.state == _rest_rng_state \
		and session_gold == _rest_gold and [run_trinkets, run_removal_count] == _rest_inventory


func _completed_rest_upgrade() -> bool:
	return rest_upgrade != null and rest_upgrade.is_consumed() \
		and rest_recovery != null and not rest_recovery.is_consumed() \
		and not _rest_committed_deck.is_empty() and run_deck == _rest_committed_deck \
		and run_scraps == _rest_stitch_source.remaining_scraps \
		and run_stitch_descriptors == _rest_stitch_source.descriptors \
		and run_next_stitch_id == _rest_stitch_source.next_stitch_id \
		and (rest_stitch == null or not rest_stitch.is_consumed()) \
		and _rest_upgrade_context()


func _upgrade_at_rest(visit: RunRestCardUpgrade, button, choices) -> void:
	if is_instance_valid(rest_patch_overlay) or visit == null or visit != rest_upgrade or visit.is_consumed() \
		or rest_stitch == null or rest_stitch.is_consumed() or _stitch_snapshot() != _rest_stitch_source \
		or rest_recovery == null or rest_recovery.is_consumed() or not rest_recovery._valid \
		or rest_recovery._roster != _rest_heroes or not _rest_upgrade_context() \
		or not _rest_committed_heroes.is_empty() or not _rest_committed_deck.is_empty() or run_deck != _rest_deck \
		or not visit._valid or visit._source != _rest_deck or visit._deck != _rest_deck \
		or not is_instance_valid(rest_view) or rest_view.get_parent() != self or not rest_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != rest_upgrade_button or button.get_parent() != rest_view \
		or button.disabled or not button.is_visible_in_tree() \
		or not is_instance_valid(choices) or choices != rest_upgrade_cards or choices.get_parent() != rest_view \
		or choices.disabled or not choices.is_visible_in_tree():
		return
	# Recompute the canonical authorized projection from the CURRENT deck and
	# stitch ledger. The stored rows and the visitor's mapping must both match it
	# exactly, so forged metadata, an altered ledger or a stale visit cannot spend.
	var canonical: Dictionary = RunRestCardUpgrade.list_authored_choices(
		_rest_deck, run_stitch_descriptors, run_next_stitch_id)
	if canonical.get("ok") != true or not (canonical.get("choices") is Array) \
			or not (canonical.get("permitted_upgrades") is Dictionary) \
			or canonical.choices != _rest_upgrade_choices \
			or canonical.permitted_upgrades != visit._upgrades:
		return
	var rows: Array = canonical.choices
	if choices.item_count != rows.size() or choices.selected < 0 or choices.selected >= rows.size():
		return
	for item in range(rows.size()):
		var row: Dictionary = rows[item]
		var index := int(row.get("index", -1))
		if typeof(choices.get_item_metadata(item)) != TYPE_INT \
			or choices.get_item_metadata(item) != index \
			or choices.is_item_disabled(item) \
			or choices.get_item_text(item) != _rest_upgrade_text(index):
			return
	var selected_row: Dictionary = rows[choices.selected]
	var selected_index := int(selected_row.get("index", -1))
	# Exact copy identity plus the authored base -> '+' mapping this visit holds.
	if selected_index < 0 or selected_index >= _rest_deck.size() \
		or _rest_deck[selected_index] != String(selected_row.get("base_id", "")) \
		or String(selected_row.get("plus_id", "")) != String(visit._upgrades.get(_rest_deck[selected_index], "")):
		return
	var result := visit.choose_upgrade(selected_index)
	if not result.ok:
		return
	run_deck.assign(result.deck)
	_rest_committed_deck = run_deck.duplicate()
	_rest_committed_heroes = run_heroes.duplicate(true)
	_finish_rest_choice()


func _stitch_snapshot() -> Dictionary:
	return RunRestStitchCards.new(run_deck, run_stitch_descriptors, run_scraps, run_next_stitch_id).get_snapshot()


func _rest_stitch_indices() -> Array[int]:
	var indices: Array[int] = []
	for index in range(_rest_deck.size()):
		if not RunRestStitchCards.resolve_card_definition(_rest_deck[index]).is_empty():
			indices.append(index)
	return indices


func _rest_stitch_text(index: int, first: bool) -> String:
	var definition := RunRestStitchCards.resolve_card_definition(_rest_deck[index])
	return "%s card: Deck #%d: %s - %s" % ["First" if first else "Second", index + 1, str(definition.owner).capitalize(), definition.display_name]


func _completed_rest_stitch() -> bool:
	return rest_stitch != null and rest_stitch.is_consumed() \
		and rest_recovery != null and not rest_recovery.is_consumed() \
		and rest_upgrade != null and not rest_upgrade.is_consumed() \
		and not _rest_stitch_committed.is_empty() and _stitch_snapshot() == _rest_stitch_committed \
		and run_deck == _rest_committed_deck and _rest_upgrade_context()


func _stitch_at_rest(visit: RunRestStitchCards, button, first, second) -> void:
	if is_instance_valid(rest_patch_overlay) or visit == null or visit != rest_stitch or not visit.is_valid() or visit.is_consumed() \
		or rest_recovery == null or not rest_recovery._valid or rest_recovery.is_consumed() \
		or rest_recovery._roster != _rest_heroes or rest_upgrade == null or rest_upgrade.is_consumed() \
		or not _rest_committed_deck.is_empty() or not _rest_committed_heroes.is_empty() \
		or not _rest_upgrade_context() or run_deck != _rest_deck \
		or not is_instance_valid(rest_view) or rest_view.get_parent() != self or not rest_view.is_visible_in_tree():
		return
	for pair in [[button, rest_stitch_button], [first, rest_stitch_first], [second, rest_stitch_second]]:
		var control = pair[0]
		if not is_instance_valid(control) or control != pair[1] or control.get_parent() != rest_view \
			or control.disabled or not control.is_visible_in_tree():
			return
	var indices := _rest_stitch_indices()
	for selector in [first, second]:
		if selector.item_count != indices.size() or selector.selected < 0 or selector.selected >= indices.size():
			return
		for item in range(indices.size()):
			if typeof(selector.get_item_metadata(item)) != TYPE_INT or selector.get_item_metadata(item) != indices[item] \
				or selector.is_item_disabled(item) or selector.get_item_text(item) != _rest_stitch_text(indices[item], selector == first):
				return
	var current := _stitch_snapshot()
	if current != _rest_stitch_source or visit.get_snapshot() != current or visit._source_snapshot != current:
		return
	var result := visit.choose_stitch(indices[first.selected], indices[second.selected], current)
	if not result.ok:
		return
	# Synchronous transaction: publish every result field together before enabling Continue.
	run_deck.assign(result.deck)
	run_stitch_descriptors = result.descriptors.duplicate(true)
	run_scraps = result.remaining_scraps
	run_next_stitch_id = result.next_stitch_id
	_rest_stitch_committed = visit.get_snapshot()
	_rest_committed_deck = run_deck.duplicate()
	_rest_committed_heroes = run_heroes.duplicate(true)
	_finish_rest_choice()


func _refresh_rest_stitch_guided() -> void:
	for connection in rest_stitch_guided_button.pressed.get_connections():
		rest_stitch_guided_button.pressed.disconnect(connection.callable)
	rest_stitch_guided_button.disabled = rest_recovery.is_consumed() or rest_upgrade.is_consumed() \
		or RunRestStitchPairOptions.new(rest_stitch, _rest_stitch_source).first_options().is_empty()
	rest_stitch_guided_button.pressed.connect(_open_rest_stitch.bind(rest_stitch, rest_stitch_guided_button))


func _open_rest_stitch(visit: RunRestStitchCards, button) -> void:
	if visit == null or visit != rest_stitch or not is_instance_valid(button) \
		or button != rest_stitch_guided_button or button.disabled or button.get_parent() != rest_view \
		or not button.is_visible_in_tree() or not _rest_upgrade_context() \
		or rest_recovery.is_consumed() or rest_upgrade.is_consumed() \
		or _stitch_snapshot() != _rest_stitch_source \
		or RunRestStitchPairOptions.new(visit, _rest_stitch_source).first_options().is_empty() \
		or is_instance_valid(rest_patch_overlay) or is_instance_valid(rest_stitch_overlay):
		return
	rest_stitch_overlay = Control.new()
	add_child(rest_stitch_overlay)
	rest_stitch_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	rest_stitch_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rest_stitch_picker = LiveRestStitchPairPicker.new()
	rest_stitch_overlay.add_child(rest_stitch_picker)
	rest_stitch_picker.position = Vector2(285, 75)
	rest_stitch_picker.bind(visit, _rest_stitch_source)
	var back := Button.new()
	back.text = "Back to Rest"
	back.name = "DismissStitch"
	back.position = Vector2(315, 590)
	back.size = Vector2(650, 40)
	rest_stitch_overlay.add_child(back)
	back.pressed.connect(_dismiss_rest_stitch.bind(rest_stitch_overlay, back))
	rest_stitch_picker.stitch_requested.connect(_guided_stitch_at_rest.bind(rest_stitch_picker, rest_stitch_overlay, visit))
	var controls := [rest_stitch_picker.first_selector, rest_stitch_picker.second_selector,
		rest_stitch_picker.confirm_button, back]
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
	back.grab_focus()


func _dismiss_rest_stitch(overlay, button) -> void:
	if not is_instance_valid(overlay) or overlay != rest_stitch_overlay or overlay.get_parent() != self \
		or not overlay.is_visible_in_tree() or not is_instance_valid(button) \
		or button != overlay.get_node("DismissStitch") or button.disabled:
		return
	_clear_rest_stitch_overlay()
	rest_stitch_guided_button.grab_focus()


func _clear_rest_stitch_overlay() -> void:
	if is_instance_valid(rest_stitch_picker):
		rest_stitch_picker.clear()
		for connection in rest_stitch_picker.stitch_requested.get_connections():
			rest_stitch_picker.stitch_requested.disconnect(connection.callable)
	if is_instance_valid(rest_stitch_overlay):
		remove_child(rest_stitch_overlay)
		rest_stitch_overlay.queue_free()
	rest_stitch_picker = null
	rest_stitch_overlay = null


func _guided_stitch_at_rest(first_index: int, second_index: int, expected: Dictionary,
		picker, overlay, visit: RunRestStitchCards) -> void:
	if not is_instance_valid(picker) or picker != rest_stitch_picker \
		or not is_instance_valid(overlay) or overlay != rest_stitch_overlay \
		or overlay.get_parent() != self or picker.get_parent() != overlay \
		or not picker.is_visible_in_tree() or visit != rest_stitch or visit == null \
		or is_instance_valid(rest_patch_overlay) or expected != _rest_stitch_source \
		or _stitch_snapshot() != expected or picker.confirm_button.disabled \
		or picker._model._service != visit:
		return
	var pair: Dictionary = picker._current_pair()
	if pair.is_empty() or pair.first_index != first_index or pair.second_index != second_index \
		or pair.source_snapshot != expected:
		return
	var rows: Array[int] = []
	for wanted in [first_index, second_index]:
		var row := -1
		for item in range(rest_stitch_first.item_count):
			if rest_stitch_first.get_item_metadata(item) == wanted:
				row = item
		if row < 0:
			return
		rows.append(row)
	rest_stitch_first.select(rows[0])
	rest_stitch_second.select(rows[1])
	_stitch_at_rest(visit, rest_stitch_button, rest_stitch_first, rest_stitch_second)


func _rest_upgrade_text(index: int) -> String:
	var choice := _rest_upgrade_choice(index)
	if choice.is_empty():
		return ""
	return "Deck #%d: %s -> %s (%d energy; %s)" % [index + 1,
		String(choice.get("display_name", "")), String(choice.get("plus_display_name", "")),
		int(choice.get("plus_cost", 0)), _rest_effect_text(choice.get("plus_effects", {}))]


## The canonical row this visit actually reported for a deck index, else {}.
func _rest_upgrade_choice(index: int) -> Dictionary:
	for entry in _rest_upgrade_choices:
		if typeof(entry) == TYPE_DICTIONARY and entry.get("index") == index:
			return entry
	return {}


## Authored effect fields in a stable order. Nothing is invented: only keys the
## card definition carries are shown, and booleans read as their field name.
func _rest_effect_text(effects: Variant) -> String:
	if not (effects is Dictionary):
		return ""
	var parts: PackedStringArray = []
	var keys: Array = effects.keys()
	keys.sort()
	for key in keys:
		var value: Variant = effects[key]
		var label: String = String(key).replace("_", " ")
		if value is bool:
			if value:
				parts.append(label)
		elif value is int:
			parts.append("%d %s" % [value, label])
		elif value is String:
			parts.append("%s %s" % [label, String(value).replace("_", " ")])
	return ", ".join(parts)


func _finish_rest_choice() -> void:
	_clear_rest_stitch_overlay()
	rest_stitch_guided_button.disabled = true
	_sync_rest_patches()
	rest_heal_button.disabled = true
	rest_stitch_button.disabled = true
	rest_stitch_first.disabled = true
	rest_stitch_second.disabled = true
	rest_upgrade_button.disabled = true
	rest_upgrade_cards.disabled = true
	_refresh_rest_hp()
	rest_continue_button.disabled = false
	rest_continue_button.focus_next = rest_continue_button.get_path_to(rest_back_button)
	rest_continue_button.focus_previous = rest_continue_button.get_path_to(rest_back_button)
	rest_back_button.focus_next = rest_back_button.get_path_to(rest_continue_button)
	rest_back_button.focus_previous = rest_back_button.get_path_to(rest_continue_button)
	rest_back_button.grab_focus()
	if not rest_patch_button.disabled:
		var actions := [rest_continue_button, rest_patch_button, rest_back_button]
		for index in range(actions.size()):
			actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
			actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])


func _rest_patch_snapshot() -> Array:
	var carry := party_carryover as RunTornCarryover
	if carry == null or _rest_wardrobe == null or run_map == null or run_rng == null:
		return []
	return [run_map, run_map.get_route(), run_map.get_floors(), run_map.get_generation_revision(),
		run_rng, run_rng.state, run_seed, carry, carry.read_state(), carry.torn, carry.torn.read_state(),
		carry._wardrobe, _rest_wardrobe, _rest_wardrobe.get_snapshot(),
		run_heroes.duplicate(true), run_deck.duplicate(), run_trinkets.duplicate(), session_gold,
		run_scraps, run_removal_count, _stitch_snapshot(), rest_recovery, rest_recovery.is_consumed(),
		rest_upgrade, rest_upgrade.is_consumed(), rest_stitch, rest_stitch.get_snapshot(), rest_stitch.is_consumed()]


func _rest_patch_current(closed: bool = false) -> bool:
	if _rest_patch_context.is_empty() or _rest_patch_snapshot() != _rest_patch_context:
		return false
	var carry := party_carryover as RunTornCarryover
	var state := _rest_wardrobe.get_snapshot()
	return _rest_map != null and _rest_map.get_ref() == run_map and run_map.get_route() == _rest_route \
		and state.rest_id == ("" if closed else _rest_route.back()) and carry._wardrobe == _rest_wardrobe \
		and state.heroes == run_heroes and state.cards == run_deck and state.owned == run_trinkets \
		and state.scraps == run_scraps and state.gold == session_gold and state.seed == run_seed \
		and carry.can_bind_wardrobe(_rest_wardrobe, carry.torn, state)


func _sync_rest_patches() -> void:
	# Only called after an authorized primary choice commits.
	if _rest_wardrobe == null:
		return
	_rest_wardrobe.refresh_run_context(run_heroes, run_trinkets, run_scraps,
		session_gold, run_deck, _rest_wardrobe.get_snapshot())
	_rest_patch_context = _rest_patch_snapshot()


func _open_rest_patches(button) -> void:
	if not is_instance_valid(button) or button != rest_patch_button or button.disabled \
		or not button.is_visible_in_tree() or not _rest_patch_current() \
		or is_instance_valid(rest_patch_overlay) or is_instance_valid(rest_stitch_overlay):
		return
	rest_patch_overlay = Control.new()
	add_child(rest_patch_overlay)
	rest_patch_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	rest_patch_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rest_patch_picker = LiveRestPatchResewPicker.new()
	rest_patch_overlay.add_child(rest_patch_picker)
	rest_patch_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var close := Button.new()
	close.name = "DismissResew"
	close.text = "Back to Rest"
	close.position = Vector2(960, 12)
	close.size = Vector2(180, 36)
	rest_patch_overlay.add_child(close)
	close.pressed.connect(_dismiss_rest_patches.bind(rest_patch_overlay, close))
	var carry := party_carryover as RunTornCarryover
	rest_patch_picker.present(_rest_wardrobe, carry.torn, _rest_wardrobe.get_snapshot(), _rest_route.back())
	rest_patch_picker.re_sew_requested.connect(_resew_at_rest.bind(rest_patch_picker, _rest_wardrobe, carry))
	var controls := [rest_patch_picker.source_selector, rest_patch_picker.destination_selector,
		rest_patch_picker.confirm_button, close]
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
	close.grab_focus()


func _dismiss_rest_patches(overlay, button) -> void:
	if is_instance_valid(overlay) and overlay == rest_patch_overlay and overlay.is_visible_in_tree() \
		and is_instance_valid(button) and button.get_parent() == overlay and not button.disabled:
		_clear_rest_patch_overlay()
		rest_patch_button.grab_focus()


func _clear_rest_patch_overlay() -> void:
	if is_instance_valid(rest_patch_picker):
		for connection in rest_patch_picker.re_sew_requested.get_connections():
			rest_patch_picker.re_sew_requested.disconnect(connection.callable)
	if is_instance_valid(rest_patch_overlay):
		remove_child(rest_patch_overlay)
		rest_patch_overlay.queue_free()
	rest_patch_overlay = null
	rest_patch_picker = null


func _resew_at_rest(patch_id: String, from_hero: String, to_hero: String,
		node: String, expected: Dictionary, picker, wardrobe, carry) -> void:
	if not is_instance_valid(picker) or picker != rest_patch_picker or not picker.is_visible_in_tree() \
		or not is_instance_valid(rest_patch_overlay) or picker.get_parent() != rest_patch_overlay \
		or not is_instance_valid(rest_view) or not rest_view.is_visible_in_tree() \
		or wardrobe != _rest_wardrobe or carry != party_carryover or not _rest_patch_current() \
		or node != _rest_route.back() or expected != wardrobe.get_snapshot() \
		or not picker._pending or picker._snapshot != expected or picker._node_id != node:
		return
	var selected: int = picker.destination_selector.selected
	if selected < 0 or selected >= picker._destinations.size() \
		or not picker.confirm_button.is_visible_in_tree() \
		or not picker.source_selector.is_visible_in_tree() or not picker.destination_selector.is_visible_in_tree():
		return
	var choice: Dictionary = picker._destinations[selected]
	if [choice.patch_id, choice.from_hero, choice.to_hero] != [patch_id, from_hero, to_hero]:
		return
	var options := RunRestPatchResewOptions.project(wardrobe, carry.torn, expected, node)
	if not options.ok or not options.options.any(func(option): return option.patch_id == patch_id \
		and option.from_hero == from_hero and option.to_hero == to_hero):
		return
	var result: Dictionary = wardrobe.re_sew(patch_id, from_hero, to_hero, node,
		"rest:%s:resew:%d" % [node, _rest_patch_serial], expected)
	if not result.ok:
		return
	_rest_patch_serial += 1
	run_scraps = result.state.scraps
	carry.bind_wardrobe(wardrobe, carry.torn, result.state)
	# Rebase the live purse guard without replacing completed primary receipts.
	if rest_stitch.is_consumed():
		_rest_stitch_committed = _stitch_snapshot()
	else:
		if _rest_committed_deck.is_empty():
			rest_stitch = RunRestStitchCards.new(run_deck, run_stitch_descriptors, run_scraps, run_next_stitch_id)
			for connection in rest_stitch_button.pressed.get_connections():
				rest_stitch_button.pressed.disconnect(connection.callable)
			rest_stitch_button.pressed.connect(_stitch_at_rest.bind(rest_stitch, rest_stitch_button, rest_stitch_first, rest_stitch_second))
			if not rest_recovery.is_consumed():
				rest_stitch_button.disabled = run_scraps < RunRestStitchCards.SCRAP_COST
				rest_stitch_first.disabled = rest_stitch_button.disabled
				rest_stitch_second.disabled = rest_stitch_button.disabled
		# Upgrade changes the deck, so retain its original source deck in this guard.
		_rest_stitch_source = RunRestStitchCards.new(_rest_stitch_source.deck,
			_rest_stitch_source.descriptors, run_scraps, _rest_stitch_source.next_stitch_id).get_snapshot()
	_rest_patch_context = _rest_patch_snapshot()
	rest_view.get_node("RestStitchCost").text = "Stitch two different owners: 3 scraps (owned: %d)" % run_scraps
	_refresh_rest_stitch_guided()
	picker.present(wardrobe, carry.torn, result.state, node, "Re-sewn for 1 scrap.")


func _continue_from_rest(visit: RunRestRecovery, source_map: WeakRef, prior: Array[String], button) -> void:
	if is_instance_valid(rest_patch_overlay) or visit == null or visit != rest_recovery or not _current_completed_rest() \
		or source_map == null or source_map.get_ref() != run_map or prior != _rest_route \
		or not is_instance_valid(rest_view) or not rest_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != rest_continue_button or button.disabled \
		or not button.is_visible_in_tree() or is_instance_valid(route_view):
		return
	if _rest_wardrobe != null:
		if not _rest_patch_current() or not _rest_wardrobe.end_rest(_rest_route.back(), _rest_wardrobe.get_snapshot()).ok:
			return
		_clear_rest_patch_overlay()
		_rest_patch_context = _rest_patch_snapshot()
	_legacy_rest_visits[run_map.get_current_node_id()] = [run_map,
		run_map.get_generation_revision(), run_map.get_floors(), run_map.get_route()]
	button.disabled = true
	_clear_rest_stitch_overlay()
	_clear_visit_backdrop()
	rest_view.hide()
	_present_connected_route(source_map)


func _current_shop_ledger(status: String = "") -> bool:
	if shop_visit == null or run_map == null or _shop_map == null or _shop_map.get_ref() != run_map \
		or run_map.get_route() != _shop_route or _shop_route.is_empty() \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Shop":
		return false
	var ledger := shop_visit.get_state()
	return ledger.valid and ledger.shop_node_id == run_map.get_current_node_id() \
		and ledger.deck == run_deck and ledger.gold == session_gold \
		and ledger.trinkets == run_trinkets and ledger.prior_removals == run_removal_count \
		and ledger.get("descriptors") == run_stitch_descriptors and ledger.get("next_stitch_id") == run_next_stitch_id \
		and (ledger.status == status if not status.is_empty() else ledger.status in ["available", "used"])


func _continue_from_shop(visit: RunShopVisit, source_map: WeakRef, prior: Array[String], button) -> void:
	if visit == null or visit != shop_visit or not _current_shop_ledger() \
		or source_map == null or source_map.get_ref() != run_map or prior != _shop_route \
		or not RunRestRecovery._is_valid_roster(run_heroes) \
		or not is_instance_valid(shop_view) or not shop_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != shop_continue_button or button.disabled \
		or not button.is_visible_in_tree() or is_instance_valid(route_view):
		return
	if not visit.close_visit():
		return
	button.disabled = true
	_clear_visit_backdrop()
	shop_view.hide()
	if is_instance_valid(shop_patch_preview):
		shop_patch_preview.queue_free()
	shop_patch_preview = null
	_present_connected_route(source_map)


func _choose_rest_route(id: String, source_map: WeakRef, prior: Array[String], button) -> bool:
	if not _can_choose_connected_route() or run_rng == null or party_carryover == null \
		or source_map == null or source_map.get_ref() != run_map \
		or run_map.get_route() != prior or not is_instance_valid(route_view) \
		or not route_view.is_visible_in_tree() or not is_instance_valid(button) \
		or button not in route_buttons or button.disabled or not button.is_visible_in_tree() \
		or button.get_meta("route_id") != id or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") != "Rest":
		return false
	var carry := party_carryover as RunTornCarryover
	var wardrobe := carry._wardrobe if carry != null else null
	if wardrobe != null:
		var state := wardrobe.get_snapshot()
		if state.heroes != run_heroes or state.owned != run_trinkets or state.scraps != run_scraps \
			or state.gold != session_gold or state.cards != run_deck or state.seed != run_seed \
			or state.rest_id != "" or state.rest_ids.has(id) \
			or not carry.can_bind_wardrobe(wardrobe, carry.torn, state):
			return false
	# This visit's upgrade transaction is the canonical authored projection of
	# the run deck and stitch ledger. A malformed deck or ledger fails closed
	# before the node is committed, so the selector never shows invented entries.
	var upgrade_choices: Dictionary = RunRestCardUpgrade.list_authored_choices(
		run_deck, run_stitch_descriptors, run_next_stitch_id)
	if upgrade_choices.get("ok") != true or not (upgrade_choices.get("choices") is Array) \
			or not (upgrade_choices.get("permitted_upgrades") is Dictionary):
		return false
	var upgrade_visit := RunRestCardUpgrade.new(run_deck, upgrade_choices.permitted_upgrades,
		run_stitch_descriptors, run_next_stitch_id)
	if not upgrade_visit._valid or upgrade_visit._deck != run_deck:
		return false
	if not run_map.choose_node(id):
		return false
	_clear_rest_stitch_overlay()
	_rest_wardrobe = wardrobe
	_rest_patch_serial = 0
	if wardrobe != null:
		wardrobe.start_rest(id, wardrobe.get_snapshot())
	if is_instance_valid(rest_view):
		remove_child(rest_view)
		rest_view.queue_free()
	rest_continue_button = null
	_rest_committed_heroes.clear()
	_rest_committed_deck.clear()
	rest_stitch = RunRestStitchCards.new(run_deck, run_stitch_descriptors, run_scraps, run_next_stitch_id)
	_rest_stitch_source = _stitch_snapshot()
	_rest_stitch_committed.clear()
	rest_recovery = RunRestRecovery.new(run_heroes)
	rest_upgrade = upgrade_visit
	_rest_upgrade_choices = upgrade_choices.choices.duplicate(true)
	_rest_deck = run_deck.duplicate()
	_rest_floors = run_map.get_floors()
	_rest_revision = run_map.get_generation_revision()
	_rest_gold = session_gold
	_rest_rng = run_rng
	_rest_rng_state = run_rng.state
	_rest_inventory = [run_trinkets.duplicate(), run_removal_count]
	_rest_carry = party_carryover
	_rest_ledger = party_carryover.read_state()
	_rest_heroes = run_heroes.duplicate(true)
	_rest_route = run_map.get_route()
	_rest_map = weakref(run_map)
	_clear_route_view()
	rest_view = VBoxContainer.new()
	rest_view.set_anchors_preset(Control.PRESET_CENTER)
	rest_view.add_theme_constant_override("separation", 8)
	add_child(rest_view)
	_mount_visit_backdrop("Rest", rest_view)
	var heading := Label.new()
	heading.name = "RestTitle"
	heading.text = "Rest camp - Floor %d" % run_map.get_current_floor()
	heading.theme_type_variation = &"PatchHeading"
	rest_view.add_child(heading)
	var party_ribbons := PanelContainer.new()
	party_ribbons.name = "RestPartyRibbons"
	party_ribbons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_ribbons.focus_mode = Control.FOCUS_NONE
	# Reuse the sewn nameplate art; a missing image keeps the same dark backing.
	var ribbon_art := "res://assets/paper/ui/hud_name_plate.png"
	party_ribbons.set_meta("art_path", ribbon_art)
	var ribbon_style := StyleBoxFlat.new()
	ribbon_style.bg_color = Color("42392f")
	ribbon_style.border_color = ROUTE_BOOK_THREAD
	ribbon_style.set_border_width_all(1)
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		ribbon_style.set_content_margin(side, 12)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		ribbon_style.set_content_margin(side, 6)
	party_ribbons.add_theme_stylebox_override("panel", ribbon_style)
	rest_view.add_child(party_ribbons)
	var ribbon_rows := VBoxContainer.new()
	ribbon_rows.name = "HeroRibbons"
	ribbon_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon_rows.add_theme_constant_override("separation", 4)
	party_ribbons.add_child(ribbon_rows)
	for hero in run_heroes:
		var ribbon := NinePatchRect.new()
		ribbon.name = hero.id
		ribbon.set_meta("hero_id", hero.id)
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			ribbon.set_patch_margin(side, 8)
		ribbon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ribbon.modulate = Color("42392f")
		if ResourceLoader.exists(ribbon_art, "Texture2D"):
			ribbon.texture = load(ribbon_art)
		ribbon_rows.add_child(ribbon)
	# PanelContainer overlays the single live Label on the three art ribbons.
	rest_hp_label = Label.new()
	rest_hp_label.name = "HeroStatusLines"
	rest_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rest_hp_label.focus_mode = Control.FOCUS_NONE
	rest_hp_label.add_theme_font_size_override("font_size", 20)
	rest_hp_label.add_theme_color_override("font_color", ROUTE_BOOK_PAPER)
	rest_hp_label.add_theme_constant_override("line_spacing", 4)
	party_ribbons.add_child(rest_hp_label)
	var stitch_label := Label.new()
	stitch_label.name = "RestStitchCost"
	stitch_label.text = "Stitch two different owners: 3 scraps (owned: %d)" % run_scraps
	rest_view.add_child(stitch_label)
	rest_stitch_first = OptionButton.new()
	rest_stitch_second = OptionButton.new()
	for selector in [rest_stitch_first, rest_stitch_second]:
		selector.custom_minimum_size = Vector2(480, 36)
		for index in _rest_stitch_indices():
			selector.add_item(_rest_stitch_text(index, selector == rest_stitch_first))
			selector.set_item_metadata(selector.item_count - 1, index)
		rest_view.add_child(selector)
	if rest_stitch_first.item_count > 0:
		rest_stitch_first.select(0)
		var first_index: int = rest_stitch_first.get_item_metadata(0)
		var first_owner: String = RunRestStitchCards.resolve_card_definition(_rest_deck[first_index]).owner
		for row in range(rest_stitch_second.item_count):
			var second_index: int = rest_stitch_second.get_item_metadata(row)
			if RunRestStitchCards.resolve_card_definition(_rest_deck[second_index]).owner != first_owner:
				rest_stitch_second.select(row)
				break
	rest_heal_button = Button.new()
	rest_heal_button.text = "Heal"
	rest_heal_button.tooltip_text = "Choose one: Heal, Upgrade or Stitch. Heal restores 30% max HP and revives downed heroes."
	rest_heal_button.custom_minimum_size = Vector2(480, 56)
	rest_heal_button.pressed.connect(_heal_at_rest.bind(rest_recovery, rest_heal_button))
	rest_view.add_child(rest_heal_button)
	rest_upgrade_cards = OptionButton.new()
	rest_upgrade_cards.custom_minimum_size = Vector2(640, 40)
	for choice in _rest_upgrade_choices:
		rest_upgrade_cards.add_item(_rest_upgrade_text(int(choice.index)))
		rest_upgrade_cards.set_item_metadata(rest_upgrade_cards.item_count - 1, int(choice.index))
	rest_view.add_child(rest_upgrade_cards)
	rest_upgrade_button = Button.new()
	rest_upgrade_button.text = "Upgrade"
	rest_upgrade_button.tooltip_text = "Choose one: Heal, Upgrade or Stitch. Upgrade the selected card."
	rest_upgrade_button.custom_minimum_size = Vector2(480, 48)
	rest_upgrade_button.disabled = rest_upgrade_cards.item_count == 0
	rest_upgrade_cards.disabled = rest_upgrade_button.disabled
	rest_upgrade_button.pressed.connect(_upgrade_at_rest.bind(rest_upgrade, rest_upgrade_button, rest_upgrade_cards))
	rest_view.add_child(rest_upgrade_button)
	rest_stitch_button = Button.new()
	rest_stitch_button.text = "Stitch (3 scraps)"
	rest_stitch_button.tooltip_text = "Choose one: Heal, Upgrade or Stitch. Stitch two cards from different owners."
	rest_stitch_button.custom_minimum_size = Vector2(480, 40)
	rest_stitch_button.disabled = not rest_stitch.is_valid() or run_scraps < RunRestStitchCards.SCRAP_COST
	rest_stitch_first.disabled = rest_stitch_button.disabled
	rest_stitch_second.disabled = rest_stitch_button.disabled
	rest_stitch_button.pressed.connect(_stitch_at_rest.bind(rest_stitch, rest_stitch_button, rest_stitch_first, rest_stitch_second))
	rest_view.add_child(rest_stitch_button)
	rest_stitch_guided_button = Button.new()
	rest_stitch_guided_button.text = "Guided Stitch (3 scraps)"
	rest_stitch_guided_button.tooltip_text = "Choose one: Heal, Upgrade or Stitch. Preview two cards before stitching."
	rest_view.add_child(rest_stitch_guided_button)
	_refresh_rest_stitch_guided()
	rest_continue_button = Button.new()
	rest_continue_button.text = "Continue"
	rest_continue_button.custom_minimum_size = Vector2(480, 48)
	rest_continue_button.disabled = true
	rest_continue_button.pressed.connect(_continue_from_rest.bind(rest_recovery, _rest_map, _rest_route.duplicate(), rest_continue_button))
	rest_view.add_child(rest_continue_button)
	rest_patch_button = Button.new()
	rest_patch_button.text = "Re-sew (1 scrap)"
	rest_patch_button.disabled = _rest_wardrobe == null
	rest_patch_button.pressed.connect(_open_rest_patches.bind(rest_patch_button))
	rest_view.add_child(rest_patch_button)
	rest_back_button = Button.new()
	rest_back_button.text = "Return"
	rest_back_button.pressed.connect(_return_from_visit.bind(rest_view))
	rest_view.add_child(rest_back_button)
	_focus_visit(rest_view)
	if not rest_upgrade_button.disabled:
		var actions: Array[Control] = [rest_heal_button, rest_upgrade_cards, rest_upgrade_button]
		if not rest_stitch_button.disabled:
			actions.append_array([rest_stitch_first, rest_stitch_second, rest_stitch_button])
		if not rest_stitch_guided_button.disabled:
			actions.append(rest_stitch_guided_button)
		if not rest_patch_button.disabled:
			actions.append(rest_patch_button)
		actions.append(rest_back_button)
		for index in range(actions.size()):
			actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
			actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])
	_rest_patch_context = _rest_patch_snapshot()
	_refresh_rest_hp()
	return true


func _heal_at_rest(visit: RunRestRecovery, button) -> void:
	if is_instance_valid(rest_patch_overlay) or visit == null or visit != rest_recovery or visit.is_consumed() \
		or rest_stitch == null or rest_stitch.is_consumed() or _stitch_snapshot() != _rest_stitch_source \
		or not _rest_upgrade_context() \
		or (rest_upgrade != null and rest_upgrade.is_consumed()) or not _rest_committed_deck.is_empty() \
		or not is_instance_valid(rest_view) or not rest_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != rest_heal_button \
		or button.disabled or not button.is_visible_in_tree() or run_map == null \
		or _rest_map == null or _rest_map.get_ref() != run_map \
		or run_map.get_route() != _rest_route or _rest_route.is_empty() \
		or run_map.get_current_node_id() != _rest_route.back() \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Rest" \
		or run_heroes != _rest_heroes or not RunRestRecovery._is_valid_roster(run_heroes):
		return
	# Preflight both scene-free transactions before consuming either. These
	# synchronous services cannot fail after their complete source validation.
	if not visit._valid or visit._roster != _rest_heroes \
		or party_carryover == null or _carryover_map == null or _carryover_map.get_ref() != run_map:
		return
	var ledger := party_carryover.read_state()
	var current_id: String = run_map.get_current_node_id()
	if not ledger.ok or ledger.heroes != _rest_heroes or ledger.completed_rests.has(current_id) \
		or not RunPartyCarryover._valid_roster(ledger.heroes, true) \
		or not party_carryover._same_identities(ledger.heroes):
		return
	for hero in ledger.heroes:
		if hero.block != 0:
			return
	var committed := party_carryover.choose_rest_heal(current_id)
	var result := visit.choose_heal()
	if not committed.ok or not result.ok or committed.heroes != result.heroes:
		return
	run_heroes = result.heroes.duplicate(true)
	_rest_committed_heroes = run_heroes.duplicate(true)
	_finish_rest_choice()
	rest_back_button.grab_focus()


func _refresh_rest_hp() -> void:
	var preview: Dictionary = {}
	if rest_recovery != null and not rest_recovery.is_consumed() \
		and rest_upgrade != null and not rest_upgrade.is_consumed() \
		and rest_stitch != null and not rest_stitch.is_consumed() \
		and _rest_committed_heroes.is_empty() and _rest_committed_deck.is_empty() \
		and rest_recovery._valid and rest_recovery._roster == _rest_heroes \
		and rest_upgrade._valid and rest_upgrade._source == _rest_deck and rest_upgrade._deck == _rest_deck \
		and rest_stitch.is_valid() and _stitch_snapshot() == _rest_stitch_source \
		and rest_stitch.get_snapshot() == _rest_stitch_source and rest_stitch._source_snapshot == _rest_stitch_source \
		and run_deck == _rest_deck and _rest_upgrade_context():
		preview = RunRestHealPreview.preview(run_heroes)
	var lines: PackedStringArray = []
	for index in range(run_heroes.size()):
		var hero: Dictionary = run_heroes[index]
		var line := "%s  %d/%d HP" % [hero.id.capitalize(), hero.hp, hero.max_hp]
		if preview.get("ok") == true:
			var forecast: Dictionary = preview.forecasts[index]
			if forecast.revived:
				line += "  -  Revive +%d to %d/%d" % [forecast.hp_delta, forecast.hp_after, forecast.max_hp]
			elif forecast.hp_delta == 0:
				line += "  -  Full health"
			else:
				line += "  -  Heal +%d to %d/%d" % [forecast.hp_delta, forecast.hp_after, forecast.max_hp]
		lines.append(line)
	rest_hp_label.text = "\n".join(lines)


var peddler_visit: RunPeddlerVisit
var peddler_buttons: Array[Button] = []
var peddler_leave_button: Button
var peddler_heroes: OptionButton
var peddler_receipt: Dictionary = {}
var _peddler_wardrobe: RunPatchWardrobe
var _peddler_wardrobe_source: RunPatchWardrobe
var _peddler_view_source: WeakRef
var _peddler_context: Dictionary = {}
var _peddler_bound: Dictionary = {}
var _peddler_wardrobe_bound: Dictionary = {}
var _peddler_witnesses: Dictionary = {}


func _peddler_closed() -> bool:
	if run_map == null or peddler_visit == null or not peddler_visit.is_consumed() \
		or shop_view != null or _peddler_context != _sewing_context():
		return false
	var id := run_map.get_current_node_id()
	return _peddler_witnesses.get(id, []) == [run_map, run_map.get_generation_revision(),
		run_map.get_floors(), run_map.get_route(), peddler_visit, peddler_visit.read_state(), peddler_receipt]


func _choose_shop_route(id: String, source_map: WeakRef, prior: Array[String], button) -> bool:
	if not _can_choose_connected_route() or source_map == null or source_map.get_ref() != run_map \
		or run_map.get_route() != prior or not is_instance_valid(route_view) \
		or not route_view.is_visible_in_tree() or not is_instance_valid(button) \
		or button not in route_buttons or button.get_parent() != route_view \
		or button.disabled or not button.is_visible_in_tree() or button.get_meta("route_id") != id \
		or button.get_meta("route_kind") != "Shop" or not run_map.get_legal_choices().has(id) \
		or run_map.get_node(id).get("type") != "Shop" or run_rng == null:
		return false
	var carry := party_carryover as RunTornCarryover
	var definitions := RunAuthoredPatchDefinitions.load_definitions()
	if carry == null or definitions.is_empty():
		return false
	var registry := RunRestStitchCards.new(run_deck, run_stitch_descriptors, run_scraps, run_next_stitch_id)
	if not registry.is_valid():
		return false
	var wardrobe := carry._wardrobe
	if wardrobe == null:
		wardrobe = RunPatchWardrobe.new(run_heroes, run_trinkets, definitions,
			run_scraps, session_gold, run_deck, run_seed, true)
	var w := wardrobe.get_snapshot()
	if not wardrobe.is_valid() or w.heroes != run_heroes or w.owned != run_trinkets \
		or w.cards != run_deck or w.scraps != run_scraps or w.gold != session_gold \
		or w.seed != run_seed or w.rest_id != "" or not carry.can_bind_wardrobe(wardrobe, carry.torn, w):
		return false
	var authored: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	if not authored is Dictionary or not authored.get("cards") is Array or not authored.get("trinkets") is Array:
		return false
	var candidates := _validated_patch_candidates(authored.trinkets)
	if candidates.is_empty():
		return false
	# Only the actual completed-run-unlocked Peddler appends the two
	# fully authenticated P12 powers into its existing one-patch lottery.
	if heirloom_unlocked:
		var eligible_heirlooms := RunAuthoredPatchDefinitions.load_eligible_power_definitions(true)
		for heirloom_id in RunAuthoredPatchDefinitions.HEIRLOOM_IDS:
			var heirloom: Dictionary = RunAuthoredPatchDefinitions.HEIRLOOM_REQUIRED[heirloom_id]
			if not eligible_heirlooms.has({"id": heirloom["id"], "slot": heirloom["slot"]}) \
					or heirloom["shop_price_gold"] != 100:
				return false
			candidates.append({"id": heirloom["id"], "price": heirloom["shop_price_gold"]})
	var canonical_slots := {}
	for definition in definitions:
		canonical_slots[definition.id] = definition.slot
	for candidate in candidates:
		if w.definitions.get(candidate.id) != canonical_slots.get(candidate.id):
			return false
	var ids: Array = []
	for hero in run_heroes:
		ids.append(hero.id)
	# Stage on a detached copy: a refused entry cannot spend the run RNG.
	var staged_rng := RandomNumberGenerator.new()
	staged_rng.state = run_rng.state
	var stock := RunShopStockOffers.generate_peddler_stock(staged_rng, ids,
		authored.cards, candidates, run_trinkets, heirloom_unlocked)
	var visit := RunPeddlerVisit.new(id, ids, run_deck, run_trinkets, session_gold, stock)
	if not visit.is_open() or not run_map.choose_node(id):
		return false
	run_rng.state = staged_rng.state
	_clear_route_view()
	peddler_visit = visit
	_peddler_wardrobe = wardrobe
	_peddler_wardrobe_source = wardrobe
	_peddler_bound = visit.read_state()
	_peddler_wardrobe_bound = w
	peddler_receipt = {}
	shop_view = LivePeddlerPanel.new()
	shop_view.name = "Peddler"
	shop_view.position = Vector2(190, 20)
	add_child(shop_view)
	var panel := shop_view as LivePeddlerPanel
	_peddler_view_source = weakref(panel)
	_mount_visit_backdrop("Shop", panel)
	panel.bind(visit)
	panel.intent_requested.connect(_peddler_intent.bind(visit, _peddler_view_source))
	shop_label = panel.wallet_label
	var wearer_label := panel._label("Patch wearer", Vector2(39, 406),
		Vector2(240, 30), 20, LivePeddlerPanel.CREAM)
	wearer_label.name = "PatchWearerLabel"
	peddler_heroes = OptionButton.new()
	peddler_heroes.position = Vector2(39, 440)
	peddler_heroes.size = Vector2(240, 44)
	for hero in run_heroes:
		peddler_heroes.add_item(hero.id.capitalize())
		peddler_heroes.set_item_metadata(peddler_heroes.item_count - 1, hero.id)
	peddler_heroes.tooltip_text = "Patch wearer: sew onto this hero's matching slot."
	panel.add_child(peddler_heroes)
	panel.patch_button.position = Vector2(295, 406)
	panel.patch_button.custom_minimum_size = Vector2(566, 78)
	panel.patch_button.size = Vector2(566, 78)
	peddler_buttons.assign(panel.card_buttons + [panel.patch_button])
	peddler_leave_button = panel.leave_button
	_wire_peddler_focus()
	peddler_leave_button.grab_focus()
	_peddler_context = _sewing_context()
	return true


func _wire_peddler_focus() -> void:
	var actions: Array[Control] = []
	for action in peddler_buttons.slice(0, 3):
		if not action.disabled:
			actions.append(action)
	actions.append(peddler_heroes)
	if not peddler_buttons[3].disabled:
		actions.append(peddler_buttons[3])
	actions.append(peddler_leave_button)
	for i in range(actions.size()):
		actions[i].focus_next = actions[i].get_path_to(actions[(i + 1) % actions.size()])
		actions[i].focus_previous = actions[i].get_path_to(actions[(i + actions.size() - 1) % actions.size()])


func _peddler_intent(intent: Dictionary, visit: RunPeddlerVisit, source: WeakRef) -> void:
	var panel := source.get_ref() as LivePeddlerPanel
	if panel == null or not panel.consume_intent(intent):
		return
	if not _peddler_intent_current(visit, panel, intent):
		_retry_peddler_submission(panel, visit)
		return
	var bound := _peddler_bound
	var kind: String = intent.get("kind", "")
	var id: String = intent.get("id", "")
	var w := _peddler_wardrobe.get_snapshot()
	var carry := party_carryover as RunTornCarryover
	var receipt: Dictionary
	if kind == "leave":
		if panel.leave_button != peddler_leave_button:
			_retry_peddler_submission(panel, visit)
			return
		receipt = visit.leave(bound.node_id, bound.state, bound.stock)
	else:
		var offers: Array = bound.stock.cards if kind == "card" else bound.stock.trinkets
		var index := -1
		for i in range(offers.size()):
			if offers[i].id == id:
				index = i
		if index < 0:
			_retry_peddler_submission(panel, visit)
			return
		if kind == "trinket":
			var owner := peddler_heroes.selected
			if owner < 0 or owner >= 3:
				_retry_peddler_submission(panel, visit)
				return
			var result := RunShopPatchSewing.purchase_peddler_and_sew(visit, _peddler_wardrobe,
				bound.node_id, id, run_heroes[owner].id, w.definitions.get(id),
				"peddler:%s" % bound.node_id, bound, w)
			if not result.ok:
				_retry_peddler_submission(panel, visit)
				return
			receipt = result.receipt
		else:
			receipt = visit.choose_purchase(bound.node_id, bound.state, bound.stock, kind, id)
			if receipt.ok:
				var refreshed := _peddler_wardrobe.refresh_run_context(run_heroes, run_trinkets,
					run_scraps, receipt.state.gold, receipt.state.deck, w)
				assert(refreshed, "Validated card purchase must refresh wardrobe")
	if not receipt.get("ok", false):
		_retry_peddler_submission(panel, visit)
		return
	if kind != "leave":
		var state := _peddler_wardrobe.get_snapshot()
		run_deck.assign(receipt.state.deck)
		run_trinkets.assign(state.owned)
		session_gold = state.gold
		run_scraps = state.scraps
		var reconciled := carry.bind_wardrobe(_peddler_wardrobe, carry.torn, state)
		assert(reconciled, "Peddler preflight must preserve carryover binding")
	peddler_receipt = receipt.duplicate(true)
	panel.intent_requested.disconnect(_peddler_intent.bind(visit, _peddler_view_source))
	panel.close()
	_clear_visit_backdrop()
	remove_child(shop_view)
	shop_view.queue_free()
	shop_view = null
	peddler_buttons.clear()
	peddler_leave_button = null
	peddler_heroes = null
	shop_continue_button = null
	_peddler_context = _sewing_context()
	_peddler_witnesses[bound.node_id] = [run_map, run_map.get_generation_revision(),
		run_map.get_floors(), run_map.get_route(), visit, visit.read_state(), peddler_receipt.duplicate(true)]
	_present_connected_route(weakref(run_map))


func _retry_peddler_submission(panel: LivePeddlerPanel, visit: RunPeddlerVisit) -> void:
	if panel._visit == visit and visit == peddler_visit and visit.is_open():
		panel.retry_submission()
		if is_instance_valid(peddler_heroes) and peddler_heroes.get_parent() == panel:
			_wire_peddler_focus()


func _peddler_intent_current(visit: RunPeddlerVisit, panel: LivePeddlerPanel, intent: Dictionary) -> bool:
	var bound := _peddler_bound
	var kind: String = intent.get("kind", "")
	if visit == null or visit != peddler_visit or not visit.is_open() or panel != shop_view \
		or not is_instance_valid(shop_view) or not shop_view.is_visible_in_tree() \
		or _peddler_view_source == null or _peddler_view_source.get_ref() != shop_view \
		or _peddler_wardrobe == null or _peddler_wardrobe != _peddler_wardrobe_source \
		or peddler_buttons.size() != 4 \
		or shop_view.get_parent() != self or _peddler_context != _sewing_context() \
		or bound != visit.read_state() or bound != _peddler_bound \
		or run_map.get_current_node_id() != bound.node_id \
		or run_map.get_node(bound.node_id).get("type") != "Shop":
		return false
	if not is_instance_valid(peddler_heroes) or peddler_heroes.get_parent() != shop_view \
		or peddler_heroes.disabled or not peddler_heroes.is_visible_in_tree() \
		or peddler_heroes.item_count != 3 or panel._source != bound \
		or intent.get("node_id") != bound.node_id or intent.get("expected_state") != bound.state \
		or intent.get("expected_stock") != bound.stock or kind not in ["card", "trinket", "leave"]:
		return false
	if intent.size() != (4 if kind == "leave" else 5):
		return false
	for i in range(3):
		if not peddler_heroes.get_item_metadata(i) is String \
			or peddler_heroes.get_item_metadata(i) != run_heroes[i].id \
			or peddler_heroes.get_item_text(i) != String(run_heroes[i].id).capitalize():
			return false
	var w := _peddler_wardrobe.get_snapshot()
	var carry := party_carryover as RunTornCarryover
	if w != _peddler_wardrobe_bound or w.heroes != run_heroes or w.cards != run_deck or w.owned != run_trinkets \
		or w.scraps != run_scraps or w.gold != session_gold or w.seed != run_seed \
		or w.rest_id != "" or not carry.can_bind_wardrobe(_peddler_wardrobe, carry.torn, w):
		return false
	return true


func _shop_offer_text(offer: Dictionary) -> String:
	var definition := RunPoolCardRewardOffers.resolve_reward_definition(offer.id)
	if definition.is_empty():
		return ""
	return "%s | %d gold%s" % [definition.display_name, offer.price, " | SOLD" if offer.sold else ""]


func _shop_owned_text(index: int) -> String:
	if index < 0 or index >= run_deck.size():
		return ""
	var card_id: String = run_deck[index]
	var definition := RunRestStitchCards.resolve_card_definition(card_id)
	if definition.is_empty():
		var registry := RunRestStitchCards.new(run_deck, run_stitch_descriptors, 0, run_next_stitch_id)
		if not registry.is_valid() or not run_stitch_descriptors.has(card_id):
			return ""
		definition = run_stitch_descriptors[card_id]
	return "Deck #%d: %s" % [index + 1, definition.display_name]


func _shop_owned_row_current(index: int) -> bool:
	if not _current_shop_ledger() or not is_instance_valid(shop_cards) \
		or index < 0 or index >= run_deck.size() or index >= shop_cards.item_count:
		return false
	var text := _shop_owned_text(index)
	return not text.is_empty() and shop_cards.get_item_metadata(index) is String \
		and shop_cards.get_item_metadata(index) == run_deck[index] \
		and shop_cards.get_item_text(index) == text


func _select_shop_offer(_index: int) -> void:
	if is_instance_valid(shop_view) and shop_view.is_visible_in_tree():
		_refresh_shop()


func _buy_at_shop(visit: RunShopVisit, purchases: RunShopPurchases, button) -> void:
	if visit == null or visit != shop_visit or purchases == null or purchases != shop_purchases \
		or not _current_shop_ledger() \
		or run_map == null or _shop_map == null or _shop_map.get_ref() != run_map \
		or run_map.get_route() != _shop_route or _shop_route.is_empty() \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Shop" \
		or not is_instance_valid(shop_view) or not shop_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != shop_buy_button or button.disabled \
		or not button.is_visible_in_tree() or not is_instance_valid(shop_offers) \
		or shop_offers.disabled or not shop_offers.is_visible_in_tree():
		return
	var ledger := visit.get_state()
	var state := purchases.get_state()
	if not ledger.valid or ledger.status not in ["available", "used"] or ledger.shop_node_id != run_map.get_current_node_id() \
		or ledger.deck != run_deck or ledger.gold != session_gold or ledger.prior_removals != run_removal_count \
		or state.deck != run_deck or state.gold != session_gold or state.trinkets != ledger.trinkets or ledger.trinkets != run_trinkets:
		return
	var index := shop_offers.selected
	var stock: Array = purchases.get_stock().cards
	if index < 0 or index >= stock.size() or index >= shop_offers.item_count:
		return
	var offer: Dictionary = stock[index]
	if offer.sold or session_gold < offer.price or _shop_offer_text(offer).is_empty() \
		or not shop_offers.get_item_metadata(index) is String or shop_offers.get_item_metadata(index) != offer.id \
		or shop_offers.get_item_text(index) != _shop_offer_text(offer):
		return
	if not _shop_patch_current():
		return
	var result := purchases.buy("card", offer.id)
	if not result.ok:
		return
	if not visit.reconcile_purchase(result):
		return
	run_deck.assign(result.state.deck)
	session_gold = result.state.gold
	_sync_shop_wardrobe()
	_refresh_shop()


func _remove_at_shop(visit: RunShopVisit, button) -> void:
	if visit == null or visit != shop_visit or run_map == null \
		or not _current_shop_ledger() \
		or _shop_map == null or _shop_map.get_ref() != run_map \
		or run_map.get_route() != _shop_route or _shop_route.is_empty() \
		or run_map.get_node(run_map.get_current_node_id()).get("type") != "Shop" \
		or not is_instance_valid(shop_view) or not shop_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != shop_remove_button \
		or button.disabled or not button.is_visible_in_tree() \
		or not is_instance_valid(shop_cards) or shop_cards.disabled or not shop_cards.is_visible_in_tree() \
		or shop_cards.selected < 0:
		return
	var state := visit.get_state()
	if not state.removal_available or state.shop_node_id != run_map.get_current_node_id() \
		or state.deck != run_deck or state.gold != session_gold or state.prior_removals != run_removal_count \
		or state.trinkets != run_trinkets:
		return
	var index := shop_cards.selected
	if not _shop_owned_row_current(index):
		return
	var card_id: String = run_deck[index]
	var expected := RunShopCardRemoval.try_remove_with_stitch_ledger(run_deck,
		run_stitch_descriptors, run_next_stitch_id, session_gold, run_removal_count, card_id)
	if shop_purchases == null or not shop_purchases.can_rebase_removal(state, expected, card_id):
		return
	if not _shop_patch_current():
		return
	var result := visit.remove_card(card_id)
	if result != expected or not shop_purchases.rebase_removal(state, result, card_id):
		return
	run_deck.assign(result.deck)
	run_stitch_descriptors = result.descriptors.duplicate(true)
	run_next_stitch_id = result.next_stitch_id
	session_gold = result.gold
	run_removal_count = result.prior_removals
	_sync_shop_wardrobe()
	_refresh_shop()
	shop_back_button.grab_focus()


func _refresh_shop() -> void:
	var owned_selected := shop_cards.selected
	shop_cards.clear()
	for index in range(run_deck.size()):
		shop_cards.add_item(_shop_owned_text(index))
		shop_cards.set_item_metadata(index, run_deck[index])
	shop_cards.select(clampi(owned_selected, 0, run_deck.size() - 1) if not run_deck.is_empty() else -1)
	shop_label.text = "Gold: %d | Removal: %d gold" % [session_gold, shop_visit.quote()]
	shop_remove_button.disabled = not shop_visit.get_state().removal_available
	shop_cards.disabled = shop_remove_button.disabled
	var selected := maxi(0, shop_offers.selected)
	shop_offers.clear()
	var stock: Array = shop_purchases.get_stock().cards
	for offer in stock:
		shop_offers.add_item(_shop_offer_text(offer))
		shop_offers.set_item_metadata(shop_offers.item_count - 1, offer.id)
	selected = mini(selected, stock.size() - 1)
	shop_offers.select(selected)
	var ledger := shop_visit.get_state()
	var valid_visit: bool = ledger.valid and ledger.status in ["available", "used"]
	shop_offers.disabled = not valid_visit
	shop_buy_button.disabled = not valid_visit or selected < 0 or stock[selected].sold \
		or session_gold < stock[selected].price or _shop_offer_text(stock[selected]).is_empty()
	_refresh_shop_patches()


func _mount_shop_patches() -> void:
	var carry := party_carryover as RunTornCarryover
	_shop_wardrobe = carry._wardrobe if carry != null else null
	if _shop_wardrobe == null:
		var definitions := RunAuthoredPatchDefinitions.load_definitions()
		if not definitions.is_empty():
			_shop_wardrobe = RunPatchWardrobe.new(run_heroes, run_trinkets, definitions,
				run_scraps, session_gold, run_deck, run_seed, true)
	var panel := PanelContainer.new()
	panel.name = "ShopPatchSewing"
	shop_view.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	var heading := Label.new()
	heading.name = "EquipmentHeading"
	heading.text = "Equipment — sewing included"
	heading.theme_type_variation = &"PatchHeading"
	content.add_child(heading)
	var row := HBoxContainer.new()
	content.add_child(row)
	shop_patch_offers = OptionButton.new()
	shop_patch_offers.custom_minimum_size = Vector2(350, 40)
	row.add_child(shop_patch_offers)
	shop_patch_heroes = OptionButton.new()
	row.add_child(shop_patch_heroes)
	for hero in run_heroes:
		shop_patch_heroes.add_item(hero.id.capitalize())
		shop_patch_heroes.set_item_metadata(shop_patch_heroes.item_count - 1, hero.id)
	shop_patch_buy_button = Button.new()
	shop_patch_buy_button.custom_minimum_size.y = 48
	content.add_child(shop_patch_buy_button)
	# Reuse the visit's sewn faces for this nested action, outside its direct-child rail.
	var visit_skin := get_node("LiveVisitCardTiles") as LiveVisitCardTiles
	shop_patch_buy_button.theme_type_variation = LiveVisitCardTiles.ACTION_VARIATION
	shop_patch_buy_button.add_theme_font_size_override("font_size", LiveVisitCardTiles.ACTION_FONT_SIZE)
	for state in LiveVisitCardTiles.ACTION_SKIN_STATES:
		shop_patch_buy_button.add_theme_stylebox_override(state,
			visit_skin._action_face(state, visit_skin.action_fabric()))
	for ink in LiveVisitCardTiles.ACTION_INK_STATES:
		shop_patch_buy_button.add_theme_color_override(ink, LiveVisitCardTiles.ACTION_INK)
	shop_patch_buy_button.add_theme_color_override("font_disabled_color", LiveVisitCardTiles.ACTION_DISABLED_INK)
	shop_patch_preview = Label.new()
	shop_patch_preview.name = "ShopPatchPreview"
	shop_patch_preview.custom_minimum_size.x = 440
	shop_patch_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(shop_patch_preview)
	shop_patch_offers.item_selected.connect(_select_shop_patch.bind(shop_patch_offers))
	shop_patch_buy_button.pressed.connect(_buy_shop_patch.bind(shop_visit, shop_purchases, shop_patch_buy_button))


func _shop_patch_snapshot() -> Array:
	var carry := party_carryover as RunTornCarryover
	if run_map == null or run_rng == null or carry == null or _shop_wardrobe == null \
		or shop_visit == null or shop_purchases == null:
		return []
	return [run_map, run_rng, run_rng.state, run_seed, run_map.get_generation_revision(),
		run_map.get_floors(), run_map.get_route(), party_carryover, party_carryover.read_state(),
		carry.torn.read_state(), carry._wardrobe,
		run_heroes.duplicate(true), run_trinkets.duplicate(), run_scraps, session_gold,
		run_deck.duplicate(), run_removal_count, shop_visit, shop_visit.get_state(),
		shop_purchases, shop_purchases.get_state(), shop_purchases.get_stock(),
		_shop_wardrobe, _shop_wardrobe.get_snapshot(), shop_view, shop_patch_offers, shop_patch_heroes, shop_patch_buy_button]


func _shop_patch_current() -> bool:
	if _shop_wardrobe == null or _shop_patch_context.is_empty() \
		or _shop_patch_snapshot() != _shop_patch_context:
		return false
	var w := _shop_wardrobe.get_snapshot()
	return w.heroes == run_heroes and w.owned == run_trinkets and w.scraps == run_scraps \
		and w.gold == session_gold and w.cards == run_deck and w.seed == run_seed and w.rest_id == ""


func _sync_shop_wardrobe() -> void:
	# Called only after a legitimate committed card purchase/removal.
	if _shop_wardrobe != null:
		_shop_wardrobe.refresh_run_context(run_heroes, run_trinkets, run_scraps,
			session_gold, run_deck, _shop_wardrobe.get_snapshot())
	_shop_patch_context = _shop_patch_snapshot()


func _shop_patch_offer_text(offer: Dictionary) -> String:
	if _shop_wardrobe == null:
		return ""
	var slot: Variant = _shop_wardrobe.get_snapshot().definitions.get(offer.id)
	if slot not in RunPatchWardrobe.SLOTS:
		return ""
	return "%s (%s slot)" % [String(offer.id).capitalize(), String(slot).capitalize()]


func _refresh_shop_patches() -> void:
	if not is_instance_valid(shop_patch_offers):
		return
	var selected := maxi(0, shop_patch_offers.selected)
	shop_patch_offers.clear()
	var stock: Array = shop_purchases.get_stock().trinkets
	for offer in stock:
		var text := _shop_patch_offer_text(offer)
		shop_patch_offers.add_item(text if not text.is_empty() else "Patch unavailable")
		shop_patch_offers.set_item_metadata(shop_patch_offers.item_count - 1, offer.id)
	selected = mini(selected, stock.size() - 1)
	shop_patch_offers.select(selected)
	shop_patch_buy_button.disabled = true
	shop_patch_buy_button.text = "Patch unavailable"
	if selected >= 0 and not _shop_patch_offer_text(stock[selected]).is_empty() \
		and _shop_patch_current() and _current_shop_ledger():
		var offer: Dictionary = stock[selected]
		var quote := "Buy & sew — %d gold" % offer.price
		if offer.sold:
			shop_patch_buy_button.text = "SOLD — %d gold" % offer.price
		elif session_gold < offer.price:
			shop_patch_buy_button.text = "%s (insufficient gold)" % quote
		else:
			shop_patch_buy_button.text = quote
			shop_patch_buy_button.disabled = false
	_refresh_shop_patch_preview()


func _select_shop_patch(_index: int, source) -> void:
	if not is_instance_valid(source) or source != shop_patch_offers \
		or not is_instance_valid(shop_view) or not shop_view.is_visible_in_tree():
		return
	_refresh_shop_patches()


## Read genuine stock and catalog powers only; never stage a sew or consume RNG.
func _refresh_shop_patch_preview() -> void:
	if not is_instance_valid(shop_patch_preview):
		return
	shop_patch_preview.text = "Patch preview unavailable."
	if not _shop_patch_current() or not _current_shop_ledger():
		return
	var index := shop_patch_offers.selected
	var stock: Array = shop_purchases.get_stock().trinkets
	if index < 0 or index >= stock.size() or index >= shop_patch_offers.item_count:
		return
	var offer: Dictionary = stock[index]
	if not shop_patch_offers.get_item_metadata(index) is String \
		or shop_patch_offers.get_item_metadata(index) != offer.id:
		return
	var slot: Variant = _shop_wardrobe.get_snapshot().definitions.get(offer.id)
	var authority := RunPatchWearerSummary._authority({})
	if slot not in RunPatchWardrobe.SLOTS or authority.is_empty() \
		or authority.slots.get(offer.id) != slot:
		return
	var effect := ""
	if CombatShopPatchRules.EFFECTS.has(offer.id):
		var power: Dictionary = CombatShopPatchRules.EFFECTS[offer.id]
		if power.slot == slot:
			if power.effect == "opening_block_bonus":
				effect = "+%d opening Block for this living wearer (stacks with innate Block)" % power.amount
			elif power.effect == "healing_card_bonus":
				effect = "+%d healing on positive-heal cards owned by this living wearer only" % power.amount
	else:
		effect = RunPatchWearerSummary.KNOWN_TEXTS.get(offer.id, "")
	if effect.is_empty():
		return
	shop_patch_preview.text = "%s%s\nEffect: %s\nInactive while wearer is torn." % [
		_shop_patch_offer_text(offer), " (SOLD)" if offer.sold else "", effect]


func _buy_shop_patch(visit: RunShopVisit, purchases: RunShopPurchases, button) -> void:
	if visit == null or visit != shop_visit or purchases == null or purchases != shop_purchases \
		or not _current_shop_ledger() or not _shop_patch_current() \
		or not is_instance_valid(shop_view) or not shop_view.is_visible_in_tree() \
		or not is_instance_valid(button) or button != shop_patch_buy_button \
		or button.disabled or not button.is_visible_in_tree():
		return
	for picker in [shop_patch_offers, shop_patch_heroes]:
		if not is_instance_valid(picker) or picker.disabled or not picker.is_visible_in_tree():
			return
	var index := shop_patch_offers.selected
	var hero_index := shop_patch_heroes.selected
	var stock: Array = purchases.get_stock().trinkets
	if index < 0 or index >= stock.size() or index >= shop_patch_offers.item_count \
		or hero_index < 0 or hero_index >= run_heroes.size() or hero_index >= shop_patch_heroes.item_count:
		return
	var offer: Dictionary = stock[index]
	var hero: Dictionary = run_heroes[hero_index]
	var text := _shop_patch_offer_text(offer)
	if text.is_empty() or not shop_patch_offers.get_item_metadata(index) is String \
		or not shop_patch_heroes.get_item_metadata(hero_index) is String \
		or shop_patch_offers.get_item_metadata(index) != offer.id \
		or shop_patch_offers.get_item_text(index) != text \
		or shop_patch_heroes.get_item_metadata(hero_index) != hero.id \
		or shop_patch_heroes.get_item_text(hero_index) != hero.id.capitalize():
		return
	var expected := _shop_wardrobe.get_snapshot()
	var carry := party_carryover as RunTornCarryover
	if carry == null or not carry.can_bind_wardrobe(_shop_wardrobe, carry.torn, expected):
		return
	var result := RunShopPatchSewing.purchase_and_sew(purchases, visit, _shop_wardrobe,
		run_map.get_current_node_id(), offer.id, hero.id, expected.definitions.get(offer.id),
		"shop:%s:%s" % [run_map.get_current_node_id(), offer.id],
		purchases.get_state(), purchases.get_stock(), visit.get_state(), expected)
	if not result.ok:
		return
	run_trinkets.assign(result.wardrobe_state.owned)
	run_scraps = result.wardrobe_state.scraps
	session_gold = result.wardrobe_state.gold
	carry.bind_wardrobe(_shop_wardrobe, carry.torn, result.wardrobe_state)
	_shop_patch_context = _shop_patch_snapshot()
	_refresh_shop()


## Presentation-only visit scene lookup: a missing file, or a kind without authored art,
## loads nothing and the visit bed keeps its opaque slate.
func visit_backdrop_texture(kind: String) -> Texture2D:
	var path := STAGE_ROSTER.visit_backdrop_path(kind)
	if path.is_empty():
		return null
	if not _visit_backdrops.has(path):
		_visit_backdrops[path] = STAGE_ROSTER._load_art_texture(path)
	return _visit_backdrops[path] as Texture2D


## Mounts the authored art bed of one new Rest/Shop visit as a full-screen sibling placed
## immediately before the visit view: it is never a layout child, so the view keeps its own
## rows, and it never takes pointer or keyboard input.
func _mount_visit_backdrop(kind: String, view: Control) -> void:
	_clear_visit_backdrop()
	if not is_instance_valid(view) or view.get_parent() != self:
		return
	var bed = STAGE_ROSTER.VisitBackdrop.new()
	bed.bind_visit(kind, visit_backdrop_texture(kind))
	add_child(bed)
	move_child(bed, view.get_index())
	visit_backdrop = bed
	if kind == "Shop":
		var backing := ShopActionBacking.new()
		bed.add_child(backing)
		backing.bind_view(view)


## Releases the visit bed with the visit that mounted it; continuation and title return
## both leave no backdrop behind.
func _clear_visit_backdrop() -> void:
	if is_instance_valid(visit_backdrop):
		if visit_backdrop.get_parent() != null:
			visit_backdrop.get_parent().remove_child(visit_backdrop)
		visit_backdrop.queue_free()
	visit_backdrop = null


## Mounts the Event art inside a freshly opened choice panel, directly above its opaque
## slate so a loaded scene shows while a missing file still leaves the slate. It is a
## child of the panel, so closing or returning releases it with the visit.
func _mount_event_backdrop(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	var slate := panel.get_node_or_null("SlateBackdrop")
	var bed = STAGE_ROSTER.VisitBackdrop.new()
	bed.name = "EventBackdrop"
	bed.bind_visit("Event", visit_backdrop_texture("Event"))
	panel.add_child(bed)
	panel.move_child(bed, 0 if slate == null else slate.get_index() + 1)


func _focus_visit(view: VBoxContainer) -> void:
	var actions: Array[Button] = []
	for child in view.get_children():
		if child is Button and not child.disabled:
			actions.append(child)
	for index in range(actions.size()):
		actions[index].focus_next = actions[index].get_path_to(actions[(index + 1) % actions.size()])
		actions[index].focus_previous = actions[index].get_path_to(actions[(index - 1 + actions.size()) % actions.size()])
	view.position -= view.get_combined_minimum_size() / 2.0
	actions[0].grab_focus()


func _return_from_visit(view) -> void:
	if is_instance_valid(view) and view in [route_view, rest_view, shop_view] and view.is_visible_in_tree():
		_return_to_title()


## Cycle 138: the app-side receipt bridge for CombatQuiltBonus. It only reports
## committed hand-to-discard transactions of the mounted battle; the service owns
## every rule.
## One tracker per newly admitted battle, bound to the real CombatParty/CombatDeck.
func _quilt_bind() -> void:
	_quilt_detach()
	if deck == null or party == null or deck.combat_state == null or not party.is_valid():
		return
	_quilt_bonus = CombatQuiltBonus.new(party, deck)
	var carry := party_carryover as RunTornCarryover
	if carry != null and carry._wardrobe != null:
		var state := carry._wardrobe.get_snapshot()
		if carry.can_bind_wardrobe(carry._wardrobe, carry.torn, state) \
				and state.heroes == run_heroes and state.owned == run_trinkets \
				and state.cards == run_deck and state.scraps == run_scraps \
				and state.gold == session_gold and state.seed == run_seed:
			_quilt_bonus.bind_hearth(carry._wardrobe, carry.torn)
	_quilt_deck = deck
	_quilt_party = party
	_quilt_turn_open = deck.turn_active and not _battle_closed \
		and _quilt_bonus.begin_player_turn()
	_quilt_snapshot_piles()


func _quilt_detach() -> void:
	_quilt_bonus = null
	_quilt_deck = null
	_quilt_party = null
	_quilt_turn_open = false
	_quilt_hand_snapshot.clear()
	_quilt_draw_snapshot.clear()
	_quilt_discard_snapshot.clear()
	_quilt_card_total = 0


func _quilt_snapshot_piles() -> void:
	_quilt_hand_snapshot.assign(deck.hand)
	_quilt_draw_snapshot.assign(deck.draw_pile)
	_quilt_discard_snapshot.assign(deck.discard_pile)
	_quilt_card_total = deck.hand.size() + deck.draw_pile.size() + deck.discard_pile.size()


## Called only from a real End Turn that committed a fresh player turn. A new
## hand must never inherit the previous turn's receipts or award latch.
func _quilt_advance_turn() -> void:
	if _quilt_bonus == null or _quilt_deck != deck or _quilt_party != party:
		_quilt_bind()
		return
	_quilt_turn_open = _quilt_bonus.advance_confirmed_turn()
	_quilt_snapshot_piles()


## Compare the hand with this turn's last receipt snapshot. Only a transaction
## that really moved one held copy into the discard pile is reported; a plain
## selection, an added card, End Turn disposal or a stale pile state is not.
func _quilt_sync_hand() -> void:
	if deck == null or party == null or deck.combat_state == null or not party.is_valid():
		_quilt_detach()
		return
	if _quilt_bonus == null or _quilt_deck != deck or _quilt_party != party:
		_quilt_bind()
		return
	if _battle_closed or not deck.turn_active:
		_quilt_bonus.end_player_turn()
		_quilt_turn_open = false
		_quilt_snapshot_piles()
		return
	if not _quilt_turn_open:
		_quilt_turn_open = _quilt_bonus.begin_player_turn()
		_quilt_snapshot_piles()
		return
	if _quilt_reconcile_play():
		# The service may have granted Block and drawn a card: use the existing
		# presenters so the mounted hand, pile counts and meters stay truthful.
		_refresh_party()
	_quilt_snapshot_piles()


func _quilt_reconcile_play() -> bool:
	var played := _quilt_committed_card()
	if played.is_empty():
		return false
	var awarded := false
	for owner_id in _quilt_owners_of(played):
		var receipt := _quilt_bonus.record_confirmed_play(owner_id)
		if receipt is Dictionary and bool(receipt.get("triggered", false)):
			awarded = true
	return awarded


## A committed play removes exactly one held copy from its own slot and may
## append draws at the end of the hand. Duplicate IDs are disambiguated by
## position, and the conserved piles plus the appended tail entry must prove the
## card-to-discard transaction.
func _quilt_committed_card() -> String:
	var previous := _quilt_hand_snapshot
	var current := deck.hand
	if previous.is_empty():
		return ""
	# Nothing moved: this refresh already reconciled the last committed play.
	if current == previous and deck.draw_pile == _quilt_draw_snapshot \
			and deck.discard_pile == _quilt_discard_snapshot:
		return ""
	if current.size() + deck.draw_pile.size() + deck.discard_pile.size() != _quilt_card_total:
		return ""
	if current.size() < previous.size() - 1:
		return ""
	var kept := current.slice(0, previous.size() - 1)
	var found := ""
	var matches := 0
	for index in range(previous.size()):
		var expected := previous.duplicate()
		expected.remove_at(index)
		if expected != kept:
			continue
		# Identical copies are their own case: whichever slot left the hand, the
		# committed card identity is the same. Conflicting IDs stay ambiguous.
		if not found.is_empty() and found != previous[index]:
			return ""
		found = previous[index]
		matches += 1
	if matches == 0:
		return ""
	# A committed play appends its copy to the discard pile last. Draw-before-
	# discard cards can reshuffle earlier same-ID copies out of discard first, so
	# the old discard count cannot survive; the appended tail entry and the
	# conserved totals prove exactly one held copy entered the discard pile.
	if deck.discard_pile.is_empty() or deck.discard_pile.back() != found:
		return ""
	return found


## Both owners of a trusted published stitched descriptor, or the catalog owner
## of an ordinary held card. An unvalidated or forged registry yields nothing.
func _quilt_owners_of(card_id: String) -> Array[String]:
	var owners: Array[String] = []
	if card_id.is_empty():
		return owners
	if run_stitch_descriptors.has(card_id):
		var ledger := RunRestStitchCards.new(run_deck, run_stitch_descriptors,
			run_scraps, run_next_stitch_id)
		if not ledger.is_valid():
			return owners
		var snapshot := ledger.get_snapshot()
		var owned: Array = snapshot.get("deck", [])
		if not owned.has(card_id):
			return owners
		var descriptor = snapshot.get("descriptors", {}).get(card_id)
		if not descriptor is Dictionary:
			return owners
		var listed = descriptor.get("owners")
		if not listed is Array or listed.size() != 2:
			return owners
		for owner in listed:
			if owner is String and owner in CombatQuiltBonus.HERO_IDS \
					and not owners.has(owner):
				owners.append(str(owner))
		return owners
	var definition := RunRestStitchCards.resolve_card_definition(card_id)
	if definition.is_empty():
		definition = M02PositionCards.new().get_definition(card_id)
	if definition.is_empty():
		definition = WardenPoolCards.new().get_definition(card_id)
	if definition.is_empty():
		definition = SeamstressPoolCards.new().get_definition(card_id)
	if definition.is_empty():
		definition = TinkerPoolCards.new().get_definition(card_id)
	if definition.is_empty():
		# A selected Path card is owned by the hero whose Path this run carries.
		# Only the validated receipt can name that owner.
		var path_owner := _path_card_owner(card_id)
		if not path_owner.is_empty():
			owners.append(path_owner)
		return owners
	if definition.is_empty() or definition.get("id") != card_id:
		return owners
	var owner = definition.get("owner")
	if owner is String and owner in CombatQuiltBonus.HERO_IDS:
		owners.append(str(owner))
	return owners


## The owner of a Path card this run's validated receipt carries. An unselected,
## forged or tampered Path record names no owner, so it can earn nothing.
func _path_card_owner(card_id: String) -> String:
	if card_id.is_empty():
		return ""
	if _seamstress_battle_card_id() == card_id:
		return CombatSeamstressPathCards.OWNER_ID
	if _tinker_battle_card_id() == card_id:
		return "tinker"
	return ""


## One battle's saved physical copies, not just the set of distinct card IDs.
## The turn index distinguishes a genuine new five-card deal from a refresh.
func _hand_motion_clear() -> void:
	_hand_motion_deck = null
	_hand_motion_battle = null
	_hand_motion_ids.clear()
	_hand_motion_draw.clear()
	_hand_motion_discard.clear()
	_hand_motion_turn = -1
	_hand_motion_source = null
	_hand_motion_source_card = ""
	_hand_motion_source_hand.clear()
	hand_motion_history.clear()
	var juice = get_node_or_null("LiveCombatJuice")
	if juice != null:
		juice.retire_hand_echoes()


func _hand_motion_allowed() -> bool:
	if deck == null or _battle_closed or not deck.turn_active or not is_instance_valid(hand_view) \
			or not hand_view.is_visible_in_tree() or not is_instance_valid(battle_view) \
			or not battle_view.is_visible_in_tree():
		return false
	if bool(ProjectSettings.get_setting("accessibility/reduced_motion", false)):
		return false
	var support = get_node_or_null("LiveSupportHand")
	return support == null or not (support.reduced_motion_override is bool \
		and bool(support.reduced_motion_override))


## Listen before the real presenters bind their callbacks; they can commit on a
## deferred target choice. No action is taken here, and only a later verified
## CombatDeck hand-to-discard transition can use this physical panel witness.
func _hand_motion_capture_input(event: InputEvent, panel: Control, card_id: String) -> void:
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var preview = get_node_or_null("LiveAttackPreview")
	var keyboard_target: bool = event is InputEventKey and event.pressed and not event.echo \
		and event.keycode in [KEY_1, KEY_2, KEY_3, KEY_ENTER, KEY_SPACE] \
		and preview != null and preview._armed == panel
	var accept: bool = event is InputEventKey and not event.echo \
		and ((panel.has_focus() and event.is_action_pressed("ui_accept")) or keyboard_target)
	if not (click or accept) or not _hand_motion_allowed() \
			or _hand_motion_deck != deck or _hand_motion_battle != battle_view \
			or deck.hand != _hand_motion_ids or panel.get_parent() != hand_view:
		return
	var index := panel.get_index()
	if index < 0 or index >= deck.hand.size() or deck.hand[index] != card_id:
		return
	_hand_motion_source = panel
	_hand_motion_source_card = card_id
	_hand_motion_source_hand.assign(deck.hand)


func _hand_motion_reconcile(committed_id: String) -> Dictionary:
	var entry: Array[int] = []
	var removed := -1
	var receipt := {"entries": entry, "exit": removed}
	if not _hand_motion_allowed():
		return receipt
	if _hand_motion_deck != deck or _hand_motion_battle != battle_view:
		for index in range(deck.hand.size()):
			entry.append(index)
		return {"entries": entry, "exit": -1}
	var turn := int(enemy_intents._turn_index) if enemy_intents != null else -1
	if turn != _hand_motion_turn and turn >= 0:
		for index in range(deck.hand.size()):
			entry.append(index)
		return {"entries": entry, "exit": -1}
	var old_total := _hand_motion_ids.size() + _hand_motion_draw.size() + _hand_motion_discard.size()
	var new_total := deck.hand.size() + deck.draw_pile.size() + deck.discard_pile.size()
	if old_total != new_total:
		return receipt
	var remaining: Array[String] = _hand_motion_ids.duplicate()
	if not committed_id.is_empty() and deck.discard_pile.has(committed_id):
		for index in range(_hand_motion_ids.size()):
			if _hand_motion_ids[index] != committed_id:
				continue
			var candidate: Array[String] = _hand_motion_ids.duplicate()
			candidate.remove_at(index)
			if deck.hand.size() >= candidate.size() \
					and deck.hand.slice(0, candidate.size()) == candidate:
				remaining = candidate
				# CombatDeck removes the first matching ID, but the physical source
				# can be the second copy. Require the captured mounted activation.
				if is_instance_valid(_hand_motion_source) \
						and _hand_motion_source.get_parent() == hand_view \
						and _hand_motion_source_card == committed_id \
						and _hand_motion_source_hand == _hand_motion_ids:
					var source_index := _hand_motion_source.get_index()
					if source_index >= 0 and source_index < _hand_motion_ids.size() \
							and _hand_motion_ids[source_index] == committed_id:
						removed = source_index
				# A single held ID is unambiguous even when a programmatic or
				# P-selected resolver committed without a captured GUI witness.
				if removed < 0 and _hand_motion_ids.count(committed_id) == 1:
					removed = index
				break
	# Every entry must be an appended copy, corroborated by a real pile change.
	# The old prefix survives even a reshuffle in the middle of draw_extra().
	if deck.hand.size() > remaining.size() \
			and deck.hand.slice(0, remaining.size()) == remaining \
			and (deck.draw_pile != _hand_motion_draw \
				or deck.discard_pile != _hand_motion_discard):
		for index in range(remaining.size(), deck.hand.size()):
			entry.append(index)
	return {"entries": entry, "exit": removed}


func _hand_motion_record() -> void:
	_hand_motion_deck = deck
	_hand_motion_battle = battle_view
	_hand_motion_ids.assign(deck.hand)
	_hand_motion_draw.assign(deck.draw_pile)
	_hand_motion_discard.assign(deck.discard_pile)
	_hand_motion_turn = int(enemy_intents._turn_index) if enemy_intents != null else -1
	_hand_motion_source = null
	_hand_motion_source_card = ""
	_hand_motion_source_hand.clear()


func _hand_motion_log(kind: String, card_id: String, index: int) -> void:
	hand_motion_history.append({"kind": kind, "card_id": card_id, "index": index})
	if hand_motion_history.size() > 64:
		hand_motion_history.pop_front()


func _refresh_hand() -> void:
	# Reconcile real committed plays of this battle before the hand is rebuilt,
	# so any awarded Block and extra draw render through the existing refreshes.
	# Snapshot the synchronous, genuine paid transaction before the quilt bridge
	# consumes it or awards its own optional draw.
	var committed := _quilt_committed_card() if _quilt_deck == deck and deck != null \
		and not _battle_closed else ""
	_quilt_sync_hand()
	var motion := _hand_motion_reconcile(committed)
	var old_ids: Array[String] = _hand_motion_ids.duplicate()
	var removed: int = int(motion["exit"])
	if removed >= 0 and removed < hand_view.get_child_count() \
			and removed < old_ids.size():
		var juice = get_node_or_null("LiveCombatJuice")
		var source := hand_view.get_child(removed) as Control
		if juice != null and juice.spawn_hand_discard_echo(source, $LiveSupportHand._metadata):
			_hand_motion_log("discard", old_ids[removed], removed)
	$LiveSupportHand._cancel_pending()
	# Rebuilt panels invalidate every previous combo forecast selection/listener.
	_combo_clear()
	for child in hand_view.get_children():
		child.free()
	for card_id in deck.hand:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Same authoritative height as the row, so no card is ever shorter than the band
		# that gives its two sewn halves the detailed geometry.
		panel.custom_minimum_size.y = HAND_CARD_HEIGHT
		hand_view.add_child(panel)
		var label := Label.new()
		label.text = card_id
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		panel.add_child(label)
	pile_label.text = "Draw: %d | Discard: %d" % [deck.draw_pile.size(), deck.discard_pile.size()]
	# Mount the battle's one real Pinned authority before binding support
	# Heirloom receipts; neither authority is recreated by a hand redraw.
	$LiveAttackPreview._sync_battle()
	$LiveSupportHand._sync_battle()
	if _hand_motion_allowed():
		for index in motion["entries"]:
			if index < hand_view.get_child_count() and index < deck.hand.size():
				var panel := hand_view.get_child(index) as Control
				if $LiveSupportHand._metadata.begin_draw_entry(panel):
					_hand_motion_log("draw", deck.hand[index], index)
	_hand_motion_record()
	_sync_combo_forecast()


## Container layout and card identities stay authoritative; only the visual tilt changes.
func _fan_hand() -> void:
	if not is_instance_valid(hand_view):
		return
	var count := hand_view.get_child_count()
	for index in range(count):
		var panel := hand_view.get_child(index) as Control
		var spread := (float(index) - float(count - 1) * 0.5) / maxf(1.0, float(count - 1) * 0.5)
		panel.pivot_offset = Vector2(panel.size.x * 0.5, panel.size.y + 40)
		panel.rotation = deg_to_rad(spread * 2.0)


## One hidden-until-needed strip beneath the hand. It takes no pointer or focus,
## so a forecast can never intercept a card or enemy click.
func _mount_combo_cue(column: Node) -> void:
	_combo_clear(true)
	combo_cue = Label.new()
	combo_cue.name = COMBO_FORECAST_NAME
	combo_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_cue.focus_mode = Control.FOCUS_NONE
	combo_cue.add_theme_font_size_override("font_size", 18)
	combo_cue.custom_minimum_size.y = 44
	combo_cue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combo_cue.visible = false
	column.add_child(combo_cue)


## Drop the forecast reading, every hand listener and (on teardown) the cue.
func _combo_clear(free_cue: bool = false) -> void:
	_combo_selected = null
	_combo_keyboard = false
	for panel in _combo_bindings.keys():
		_combo_unbind(panel)
	if is_instance_valid(combo_cue):
		combo_cue.text = ""
		combo_cue.visible = false
		if free_cue:
			combo_cue.queue_free()
	if free_cue:
		combo_cue = null


func _combo_unbind(panel) -> void:
	if not _combo_bindings.has(panel):
		return
	var binding: Dictionary = _combo_bindings[panel]
	if is_instance_valid(panel):
		if panel.mouse_entered.is_connected(binding.entered):
			panel.mouse_entered.disconnect(binding.entered)
		if panel.mouse_exited.is_connected(binding.exited):
			panel.mouse_exited.disconnect(binding.exited)
	_combo_bindings.erase(panel)
	if _combo_selected == panel:
		_combo_selected = null
		_combo_keyboard = false


## The held card identity is the real hand slot: same panel parent, visible,
## still at the authoritative hand index and still that exact combo card.
func _combo_panel_id(panel) -> String:
	if not is_instance_valid(panel) or not is_instance_valid(hand_view) or deck == null:
		return ""
	if panel.get_parent() != hand_view or not panel.is_visible_in_tree() \
			or not hand_view.is_visible_in_tree() or panel.get_child_count() == 0 \
			or not panel.get_child(0) is Label:
		return ""
	var index: int = panel.get_index()
	if index < 0 or index >= deck.hand.size():
		return ""
	var id := deck.hand[index]
	if panel.get_child(0).text != id or not _combo_targeting.is_pool_combo_attack(id):
		return ""
	return id


## An active mounted battle on the current route/encounter and player turn. A
## standalone title battle owns no route; a routed one must still be current.
func _combo_battle_current() -> bool:
	if not is_instance_valid(battle_view) or not battle_view.is_visible_in_tree() \
			or not is_instance_valid(hand_view) or _battle_closed:
		return false
	if deck == null or party == null or enemies == null or battle_result == null \
			or round_flow == null or enemy_intents == null or run_rng == null:
		return false
	if not deck.turn_active or not party.is_valid() or not enemies.is_valid() \
			or party.is_defeated() or enemies.is_victorious():
		return false
	if not battle_result.can_continue() or battle_result._party != party \
			or battle_result._enemies != enemies:
		return false
	if round_flow._deck != deck or round_flow._party != party \
			or round_flow._enemies != enemies or round_flow._intents != enemy_intents \
			or round_flow._result != battle_result:
		return false
	if run_map != null:
		return _current_act_battle()
	return party_carryover == null and _carryover_map == null and encounter_id.is_empty()


## The battle-scoped authorities are the presenter's Pinned/Unravel instances
## and the shared Tinker first-attack latch, never freshly constructed defaults.
func _combo_authorities() -> Dictionary:
	var presenter := get_node_or_null("LiveAttackPreview")
	if presenter == null or not is_instance_valid(presenter) or presenter._deck != deck \
			or presenter._battle != battle_view or presenter._pinned == null \
			or presenter._unravel == null or presenter._play == null:
		return {}
	var first = presenter._play._tinker
	if not first is CombatTinkerFirstAttack:
		return {}
	return {"pinned": presenter._pinned, "unravel": presenter._unravel, "first": first}


## Only one forecast/prompt owns the lower third at a time.
func _combo_other_owner() -> bool:
	var presenter := get_node_or_null("LiveAttackPreview")
	if presenter != null and is_instance_valid(presenter):
		if is_instance_valid(presenter.cue) and presenter.cue.is_visible_in_tree():
			return true
		if presenter._selected != null:
			return true
	var support := get_node_or_null("LiveSupportHand")
	if support != null and not support._pending.is_empty():
		return true
	return false


## True while P belongs to the live attack preview: it only consumes P when at
## least one bound, currently eligible attack panel is held.
func _combo_controls_owned_elsewhere() -> bool:
	var presenter := get_node_or_null("LiveAttackPreview")
	if presenter == null or not is_instance_valid(presenter) or not is_instance_valid(hand_view):
		return false
	for panel in hand_view.get_children():
		if presenter._bindings.has(panel) and presenter._eligible(panel):
			return true
	return false


## Hover listeners mirror the live hand without making combo cards castable:
## no gui_input handler, no focus mode and no cursor change are added here.
func _combo_bind_hand() -> void:
	if not is_instance_valid(hand_view) or deck == null:
		_combo_clear()
		return
	for panel in _combo_bindings.keys():
		if not is_instance_valid(panel) or _combo_panel_id(panel) != _combo_bindings[panel].id:
			_combo_unbind(panel)
	for panel in hand_view.get_children():
		if _combo_bindings.has(panel):
			continue
		var id := _combo_panel_id(panel)
		if id.is_empty():
			continue
		var binding := {"id": id, "entered": _combo_enter.bind(panel),
			"exited": _combo_exit.bind(panel)}
		_combo_bindings[panel] = binding
		panel.mouse_entered.connect(binding.entered)
		panel.mouse_exited.connect(binding.exited)


func _combo_enter(panel) -> void:
	if _combo_panel_id(panel).is_empty() or not _combo_battle_current() \
			or _combo_authorities().is_empty() or _combo_other_owner():
		return
	_combo_selected = panel
	_combo_keyboard = false
	_sync_combo_forecast()


func _combo_exit(panel) -> void:
	if _combo_selected == panel and not _combo_keyboard:
		_combo_selected = null
		_sync_combo_forecast()


func _combo_cycle() -> void:
	if not _combo_battle_current() or _combo_authorities().is_empty() \
			or _combo_other_owner() or not is_instance_valid(hand_view):
		return
	var panels: Array[Control] = []
	for panel in hand_view.get_children():
		if _combo_bindings.has(panel) and not _combo_panel_id(panel).is_empty():
			panels.append(panel)
	if panels.is_empty():
		return
	var index := panels.find(_combo_selected)
	_combo_selected = panels[(index + 1) % panels.size()]
	_combo_keyboard = true
	# A forecast-only card must not leave End Turn/Return as the accept target:
	# Space then cannot end the turn while the player believes a card is selected.
	get_viewport().gui_release_focus()
	_sync_combo_forecast()


## Per-frame lifecycle: bind real hand panels, then either forecast the selected
## held combo card through the detached oracle or retire the cue completely.
func _sync_combo_forecast() -> void:
	_combo_bind_hand()
	if not _combo_battle_current():
		_combo_clear()
		return
	if _combo_other_owner():
		_combo_selected = null
		_combo_keyboard = false
	if not is_instance_valid(_combo_selected):
		_combo_selected = null
		_combo_keyboard = false
		_combo_show("")
		return
	var id := _combo_panel_id(_combo_selected)
	var authorities := _combo_authorities()
	if id.is_empty() or authorities.is_empty():
		_combo_selected = null
		_combo_keyboard = false
		_combo_show("")
		return
	var forecast: Dictionary = _combo_preview.get_preview(deck, party, enemies,
		authorities["pinned"], authorities["unravel"], authorities["first"], id, 0)
	var text := _combo_forecast_text(id, forecast)
	if text.is_empty():
		_combo_selected = null
		_combo_keyboard = false
	_combo_show(text)


func _combo_show(text: String) -> void:
	if not is_instance_valid(combo_cue):
		return
	combo_cue.text = text
	combo_cue.visible = not text.is_empty()


## One header plus the oracle's own original slots and hit dictionaries. The
## wording stays a forecast: this cue never spends, discards, casts or claims
## that a combo attack was played.
func _combo_forecast_text(id: String, forecast: Dictionary) -> String:
	var definition: Dictionary = _combo_targeting.combo_definition(id)
	if definition.is_empty():
		return ""
	var reading := "%s | %d energy | Forecast only (nothing played): P / hover selects; Esc cancels" % [
		str(definition.get("display_name", id)), int(definition.get("cost", 0))]
	if not forecast.get("playable", false):
		return reading + "\nForecast unavailable: no legal target, energy, or owner position"
	var details: PackedStringArray = []
	for value in forecast.get("targets", []):
		if not value is Dictionary:
			return ""
		var hit: Dictionary = value
		var detail := "slot %d: %d damage" % [int(hit["position"]), int(hit["damage"])]
		var absorbed := int(hit.get("block_absorbed", 0))
		if absorbed > 0:
			detail += " (%d absorbed)" % absorbed
		detail += " → %d HP, %d Block" % [int(hit["hp_after"]), int(hit["block_after"])]
		if not bool(hit.get("survives", true)):
			detail += ", slain"
		var pin_bonus := int(hit.get("pin_bonus", 0))
		if pin_bonus > 0:
			detail += ", +%d Pinned consumed" % pin_bonus
		if bool(hit.get("pin_applied", false)):
			detail += ", Pins it (%s)" % str(hit.get("pin_owner_after", "")).capitalize()
		elif not str(hit.get("pin_owner_after", "")).is_empty():
			detail += ", Pinned by %s" % str(hit.get("pin_owner_after", "")).capitalize()
		var after: Dictionary = {}
		if hit.get("unravel_after") is Dictionary:
			after = hit["unravel_after"]
		var before: Dictionary = {}
		if hit.get("unravel_before") is Dictionary:
			before = hit["unravel_before"]
		if int(hit.get("unravel_added", 0)) > 0:
			detail += ", Unravel %d→%d/%d" % [int(before.get("gauge", 0)),
				int(after.get("gauge", 0)), int(after.get("threshold", 0))]
		elif not after.is_empty():
			detail += ", gauge %d/%d" % [int(after.get("gauge", 0)), int(after.get("threshold", 0))]
		var skip: Dictionary = {}
		if hit.get("after_action_skip") is Dictionary:
			skip = hit["after_action_skip"]
		if bool(after.get("skip_pending", false)):
			if skip.is_empty():
				detail += ", threshold reached (slain)"
			else:
				detail += ", next action skipped → %d/%d" % [int(skip.get("gauge", 0)),
					int(skip.get("threshold", 0))]
		if bool(hit.get("conditional_empowered", false)):
			detail += ", empowered"
		if int(hit.get("tinker_first_attack_bonus", 0)) > 0:
			detail += ", +%d Tinker first attack" % int(hit.get("tinker_first_attack_bonus", 0))
		details.append(detail)
	if details.is_empty():
		return ""
	return reading + "\nOriginal slots %s — %s" % [
		_combo_slot_text(forecast.get("target_positions", [])), "; ".join(details)]


func _combo_slot_text(positions: Array) -> String:
	var keys: PackedStringArray = []
	for position in positions:
		keys.append(str(int(position)))
	if keys.is_empty():
		return "none"
	if keys.size() > 1 and int(positions.back()) - int(positions.front()) == keys.size() - 1:
		return "%s-%s" % [keys[0], keys[keys.size() - 1]]
	return ", ".join(keys)


func _refresh_party() -> void:
	for index in range(hero_panels.size()):
		var hero := party.get_hero(index + 1)
		var label := hero_panels[index].get_child(0) as Label
		label.text = "%d - %s\nHP: %d/%d | Block: %d%s" % [
			hero["position"], hero["name"], hero["hp"], hero["max_hp"], hero["block"],
			"\nDOWNED" if party.is_downed(index + 1) else ""]


func _refresh_intents() -> void:
	_refresh_enemy_buff_forecast()
	if not is_instance_valid(intent_label):
		return
	var announcements: PackedStringArray = []
	var cues := CombatIntentCues.new().get_cues(enemy_intents, enemies)
	if party == null or not party.is_valid():
		cues.clear()
	for attack in cues:
		if attack.icon_key == "block":
			announcements.append("Enemy %d: %d Block" % [attack.enemy_position, attack.amount])
		elif attack.icon_key == "buff":
			announcements.append("Enemy %d: Buff +%d Block" % [attack.enemy_position, attack.amount])
		elif attack.icon_key == "debuff":
			announcements.append("Enemy %d -> Hero %d: %s %d" % [attack.enemy_position, attack.target_position, attack.status.capitalize(), attack.amount])
		elif attack.icon_key == "shove":
			announcements.append("Enemy %d: Shove Hero %d %s" % [attack.enemy_position, attack.target_position, "back" if attack.direction == 1 else "front"])
		elif attack.icon_key == "summon":
			announcements.append("Enemy %d: Summon Moth Broodling" % attack.enemy_position)
		elif attack.icon_key == "steal_gold":
			announcements.append("Enemy %d: Steal %d gold" % [attack.enemy_position, attack.amount])
		else:
			announcements.append("Enemy %d -> Hero %d (%s): %d damage" % [
				attack["enemy_position"], attack["target_position"],
				party.get_hero(attack["target_position"])["name"], attack["amount"]])
	intent_label.text = "Intent: " + ("none" if announcements.is_empty() else "; ".join(announcements))


func _refresh_enemy_buff_forecast() -> void:
	if not is_instance_valid(enemy_buff_forecast_label):
		return
	var lines: PackedStringArray = []
	if is_instance_valid(battle_view) and battle_view.is_visible_in_tree() \
		and not _battle_closed and battle_result != null \
		and battle_result.get_outcome() == CombatBattleResult.ACTIVE \
		and party != null and enemies != null and not party.is_defeated() and not enemies.is_defeated() \
		and enemy_intents != null and enemy_intents.is_valid() and enemy_attacks == enemy_intents.get_intents():
		for buff in LiveEnemyBuffForecast.new().forecast(party, enemies, enemy_attacks):
			lines.append("%s braces: +%d Block" % [buff.name, buff.after - buff.before])
	enemy_buff_forecast_label.text = "; ".join(lines)
	enemy_buff_forecast_label.visible = not lines.is_empty()


func _end_turn(button = null) -> void:
	if not is_instance_valid(button) or button != end_turn_button or button.disabled or not button.is_visible_in_tree():
		return
	if deck == null or party == null or enemies == null or enemy_intents == null \
			or battle_result == null or round_flow == null:
		return
	if round_flow._deck != deck or round_flow._party != party \
			or round_flow._enemies != enemies or round_flow._intents != enemy_intents \
			or round_flow._result != battle_result:
		return
	if not _observe_battle_result():
		return
	# Reject stale announcements and inactive hands before executing any enemy action.
	if not party.is_valid() or not enemies.is_valid() or enemy_attacks != enemy_intents.get_intents():
		return
	if not deck.turn_active:
		return
	# Accept one activation per input dispatch, including a burst of duplicate presses.
	button.disabled = true
	if not round_flow.end_turn():
		button.disabled = false
		return
	if round_flow.get_gold() != null:
		session_gold = round_flow.get_gold()
	# A committed End Turn opens the next hand: reset before it can earn receipts.
	var attack_presenter := get_node_or_null("LiveAttackPreview")
	if attack_presenter != null:
		attack_presenter.advance_warden_turn()
	_quilt_advance_turn()
	if not _observe_battle_result():
		return
	enemy_attacks = enemy_intents.get_intents()
	_refresh_intents()
	_refresh_hand()
	_refresh_party()
	_refresh_enemy_roster()
	_reenable_end_turn.call_deferred(button)


func _reenable_end_turn(button) -> void:
	if is_instance_valid(button) and button == end_turn_button and _observe_battle_result():
		button.disabled = false


func _refresh_enemy_roster() -> void:
	var presenter := get_node_or_null("LiveEnemyRoster")
	if presenter != null:
		presenter._sync_battle()
		presenter._refresh()


func _return_from_battle(button) -> void:
	if not is_instance_valid(terminal_result_panel) \
		and is_instance_valid(button) and button == return_button and not button.disabled \
		and button.is_visible_in_tree():
		_return_to_title()


func _return_to_title() -> void:
	if is_instance_valid(stitched_sewing_panel):
		_close_stitched_sewing()
	_retire_stitched_roadblock()
	if is_instance_valid(stitched_fight_view):
		_close_stitched_fight()
	_retire_party_picker()
	_party_receipt.clear()
	if is_instance_valid(unpicker_view):
		unpicker_view.free()
	unpicker_view = null
	unpicker_remove_button = null
	unpicker_leave_button = null
	unpicker_visit = null
	_unpicker_source.clear()
	_unpicker_original.clear()
	_unpicker_visits.clear()
	_unpicker_closed = false
	if is_instance_valid(campfire_view):
		remove_child(campfire_view)
		campfire_view.queue_free()
	campfire_view = null
	campfire_heal_button = null
	campfire_leave_button = null
	campfire_visit = null
	_campfire_original.clear()
	if is_instance_valid(patch_stall_view):
		patch_stall_view.close()
		patch_stall_view.free()
	patch_stall_view = null
	patch_stall_visit = null
	patch_stall_service = null
	patch_stall_purchases = null
	_patch_stall_wardrobe = null
	_patch_stall_original.clear()
	_patch_stall_context.clear()
	_patch_stall_visits.clear()
	_patch_stall_closed = false
	_campfire_visits.clear()
	_legacy_rest_visits.clear()
	if shop_view is LivePeddlerPanel:
		var panel := shop_view as LivePeddlerPanel
		for connection in panel.intent_requested.get_connections():
			panel.intent_requested.disconnect(connection.callable)
		panel.close()
	if peddler_visit != null:
		peddler_visit.close()
	peddler_visit = null
	peddler_buttons.clear()
	peddler_leave_button = null
	peddler_heroes = null
	peddler_receipt.clear()
	_peddler_wardrobe = null
	_peddler_wardrobe_source = null
	_peddler_view_source = null
	_peddler_context.clear()
	_peddler_bound.clear()
	_peddler_wardrobe_bound.clear()
	_peddler_witnesses.clear()
	_campfire_closed = false
	if is_instance_valid(sewing_view):
		remove_child(sewing_view)
		sewing_view.queue_free()
	sewing_view = null
	sewing_visit = null
	_sewing_source.clear()
	sewing_upgrade_button = null
	sewing_stitch_button = null
	sewing_leave_button = null
	_sewing_original.clear()
	_sewing_visits.clear()
	_sewing_closed = false
	_threadmill_sewing_auth.clear()
	# Only an uncommitted Base-launched opening returns to the village.
	var restore_base: bool = _route_from_base and run_map != null \
		and run_map.get_route().is_empty()
	_route_from_base = false
	# A fresh title owns no Path: an abandoned or finished run drops its receipt.
	run_warden_path_receipt = {}
	run_warden_path_choice = null
	run_seamstress_path_receipt = {}
	run_seamstress_path_choice = null
	run_tinker_path_receipt = {}
	run_tinker_path_choice = null
	_tinker_setup_receipt = {}
	_close_base()
	_clear_visit_backdrop()
	_clear_quiet_spool()
	_quiet_spool_completed = false
	_clear_moth()
	_moth_completed = false
	_clear_dye_vat()
	_dye_vat_completed = false
	_clear_needle_toll()
	_needle_toll_completed = false
	_clear_fate_pin_panel()
	_clear_frayed_debt_panel()
	_frayed_debt_seen = false
	_clear_debt_booth()
	_debt_booth_seen = false
	_debt_booth_receipt.clear()
	_frayed_debt_receipt.clear()
	_fate_pin_outcome = null
	_fate_pin_wardrobe = null
	_fate_pin_seen = false
	_fate_pin_receipt.clear()
	_clear_wallet_event()
	_emberglass_campfire_auth.clear()
	_inkblack_unpicker_auth.clear()
	_threadmill_sewing_auth.clear()
	_wallet_event_history.clear()
	_vital_event_history.clear()
	_clear_rest_patch_overlay()
	_clear_rest_stitch_overlay()
	rest_stitch_guided_button = null
	_rest_wardrobe = null
	_rest_patch_context.clear()
	rest_patch_button = null
	_rest_patch_serial = 0
	_clear_reward_choice()
	_clear_terminal_result()
	for action in reward_buttons:
		action.disabled = true
	if is_instance_valid(continue_button):
		continue_button.disabled = true
	if is_instance_valid(end_turn_button):
		end_turn_button.disabled = true
	if is_instance_valid(return_button):
		return_button.disabled = true
	if shop_visit != null:
		shop_visit.close_visit()
	if is_instance_valid(shop_view):
		remove_child(shop_view)
		shop_view.queue_free()
	shop_view = null
	shop_cards = null
	shop_remove_button = null
	shop_back_button = null
	shop_continue_button = null
	shop_label = null
	shop_visit = null
	shop_purchases = null
	shop_offers = null
	shop_buy_button = null
	shop_patch_offers = null
	shop_patch_heroes = null
	shop_patch_buy_button = null
	shop_patch_preview = null
	_shop_wardrobe = null
	_shop_patch_context.clear()
	_shop_map = null
	_shop_route.clear()
	_connected_map = null
	_connected_route.clear()
	_placeholder_map = null
	_placeholder_route.clear()
	run_removal_count = 0
	if is_instance_valid(rest_view):
		remove_child(rest_view)
		rest_view.queue_free()
	rest_view = null
	rest_heal_button = null
	rest_continue_button = null
	rest_back_button = null
	rest_hp_label = null
	rest_recovery = null
	rest_stitch = null
	rest_stitch_first = null
	rest_stitch_second = null
	rest_stitch_button = null
	_rest_stitch_source.clear()
	_rest_stitch_committed.clear()
	rest_upgrade = null
	rest_upgrade_cards = null
	rest_upgrade_button = null
	_rest_upgrade_choices.clear()
	_rest_deck.clear()
	_rest_committed_deck.clear()
	_rest_floors.clear()
	_rest_inventory.clear()
	_rest_ledger.clear()
	_rest_carry = null
	_rest_rng = null
	_rest_gold = 0
	_rest_rng_state = 0
	_rest_revision = 0
	_rest_route.clear()
	_rest_heroes.clear()
	_rest_committed_heroes.clear()
	_rest_map = null
	run_heroes.clear()
	party_carryover = null
	_carryover_map = null
	_carryover_revision = 0
	_carryover_node = ""
	_carryover_route.clear()
	_carryover_floors.clear()
	_carryover_party = null
	_carryover_result = null
	continue_button = null
	if round_flow != null:
		round_flow.clear_taunt()
	round_flow = null
	_quilt_detach()
	_hand_motion_clear()
	_combo_clear(true)
	if is_instance_valid(battle_view):
		remove_child(battle_view)
		battle_view.queue_free()
	battle_view = null
	hand_view = null
	pile_label = null
	end_turn_button = null
	return_button = null
	action_corner = null
	action_corner_row = null
	hero_view = null
	hero_panels.clear()
	intent_label = null
	enemy_buff_forecast_label = null
	result_label = null
	battle_result = null
	_terminal_combat_witness.clear()
	act_outcome = null
	victory_gold = null
	card_reward = null
	fight_rewards = null
	multi_fight_rewards = null
	fight_reward_offers.clear()
	fight_reward_gold = 0
	fight_reward_trinket = ""
	fight_reward_claimed = false
	_reward_map = null
	reward_buttons.clear()
	run_deck.clear()
	run_trinkets.clear()
	session_gold = 0
	run_scraps = 0
	run_stitch_descriptors.clear()
	run_next_stitch_id = 1
	_battle_closed = false
	_map_mend_serial = 0
	_mended_route_context.clear()
	enemy_attacks.clear()
	enemy_intents = null
	party = null
	enemies = null
	deck = null
	run_rng = null
	run_map = null
	fight_selection = null
	encounter_id = ""
	_clear_route_view()
	title_view.show()
	# Base-origin openings restore the village; every other Back keeps the title.
	if restore_base and _open_base():
		return
	start_button.grab_focus()
