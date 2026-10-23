class_name LiveEnemyIntentBadge
extends Control
## View-only sewn-paper announcement. Source positions come from CombatEnemyIntents.

const CREAM := Color("#e9dfcb")
const SLATE := Color("#34444b")
const RUST := Color("#a55f4b")
const MUTED := Color("#777a76")
## Compact sewn tag: the roster mounts it with a viewport-safe margin inside the intent band.
const BADGE_WIDTH := 192.0
const BADGE_HEIGHT := 28.0
## Drawn patch bounds in this badge's own coordinates; the authored patch art spans
## y=3..42, which the draw scales into this inset box so no stitch touches the edge.
const PATCH_WIDTH := 55.0
const PATCH_INSET := 2.0
const PATCH_CONTENT_HEIGHT := 39.0
## The sewn icon area left of the caption: the patch's inner box, inset so no stitch of
## the paper perimeter is covered by an icon.
const ICON_INSET := Vector2(4.0, 2.5)
## Committed HUD icon per announced action mode. Attack and block map to the authored
## attack/defend art; anything without an entry (shove, Unravelled, slain, unknown) keeps
## the drawn sewn glyph, so no PNG is required.
const ICON_DIR := "res://assets/paper/ui/"
const ICON_ART := {
	"attack": "intent_attack.png",
	"block": "intent_defend.png",
	"buff": "intent_buff.png",
	"debuff": "intent_debuff.png",
}

var source_position := 0
var icon_mode := "none"
var readable_text := "NO ACTION"
var intent_type := ""
var amount := 0
var target_position := 0
## Empty unless a valid mounted weighted action supplies its real policy.
var policy_cue := ""
const POLICY_LABELS := {"front": "FRONT", "lowest_living_hp": "LOW HP",
	"exposed": "EXPOSED", "random": "RANDOM"}
## The committed HUD texture selected for the current mode; null draws the sewn glyph.
var icon_texture: Texture2D = null
## Presentation-only art root. A redirected or unavailable root (missing file or import)
## keeps the drawn glyph instead of failing, without changing any authoritative text.
var icon_root := ICON_DIR
## Key: icon art path, value: Texture2D or null. A negative entry is cached too, so an
## unavailable image is never probed twice and the drawn glyph stays the fallback.
var _icon_cache: Dictionary = {}
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(BADGE_WIDTH, BADGE_HEIGHT)
	queue_redraw()


## Complete stitched patch this badge draws, used by mounted layout checks.
func patch_rect() -> Rect2:
	var height := maxf(1.0, size.y - PATCH_INSET * 2.0)
	return Rect2(2.0, PATCH_INSET, PATCH_WIDTH, height)


## The sewn icon area inside the patch, left of the unchanged caption. It is the area the
## drawn glyphs already used, so a committed icon replaces them without moving the tag.
func icon_rect() -> Rect2:
	var patch := patch_rect()
	return Rect2(patch.position + ICON_INSET,
		Vector2(maxf(0.0, patch.size.x - ICON_INSET.x * 2.0),
			maxf(0.0, patch.size.y - ICON_INSET.y * 2.0)))


## Aspect-preserved destination of the selected HUD art inside that sewn icon area.
## Empty whenever the drawn glyph is the fallback.
func icon_texture_rect() -> Rect2:
	var area := icon_rect()
	if icon_texture == null or area.size.x <= 0.0 or area.size.y <= 0.0:
		return Rect2()
	var pixels := Vector2(icon_texture.get_width(), icon_texture.get_height())
	if pixels.x <= 0.0 or pixels.y <= 0.0:
		return Rect2()
	var fit := minf(area.size.x / pixels.x, area.size.y / pixels.y)
	var drawn := pixels * fit
	return Rect2(area.get_center() - drawn * 0.5, drawn)


## The committed HUD icon file of one announced mode; empty keeps the drawn glyph.
static func icon_path_for(mode: String) -> String:
	if not ICON_ART.has(mode):
		return ""
	return ICON_DIR + String(ICON_ART[mode])


## Resolved icon path under this badge's presentation-only art root.
func icon_art_path_for(mode: String) -> String:
	if not ICON_ART.has(mode):
		return ""
	return icon_root + String(ICON_ART[mode])


## Presentation-only lookup: an unknown mode or an unavailable image loads nothing.
func icon_texture_for(mode: String) -> Texture2D:
	var path := icon_art_path_for(mode)
	if path.is_empty():
		return null
	if not _icon_cache.has(path):
		_icon_cache[path] = load_icon_texture(path)
	return _icon_cache[path] as Texture2D


## The HUD art this badge draws now; empty while the sewn glyph is the fallback.
func icon_art_path() -> String:
	return "" if icon_texture == null else icon_texture.resource_path


static func load_icon_texture(path: String) -> Texture2D:
	# A missing import or file keeps the drawn glyph instead of failing boot.
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


func show_intent(action: Dictionary, slain: bool, skip_pending: bool = false,
		policy: String = "") -> void:
	# Never affect or advance the scheduler: the caller passes a copied announcement.
	# Only targeted, active, authored actions receive the small policy tag.
	policy_cue = ""
	if not slain and not skip_pending and action.get("type") in ["attack", "debuff", "shove"] \
			and action.get("target_position") in [1, 2, 3] and POLICY_LABELS.has(policy):
		policy_cue = POLICY_LABELS[policy]
	if slain:
		icon_mode = "slain"
		intent_type = ""
		amount = 0
		target_position = 0
		readable_text = "SLAIN"
	elif skip_pending:
		icon_mode = "unravelled"
		intent_type = ""
		amount = 0
		target_position = 0
		readable_text = "UNRAVELLED"
	elif action.get("type") == "attack":
		icon_mode = "attack"
		intent_type = "attack"
		amount = action.get("amount", 0)
		target_position = action.get("target_position", 0)
		readable_text = "ATK %d > H%d" % [amount, target_position]
	elif action.get("type") == "block":
		icon_mode = "block"
		intent_type = "block"
		amount = action.get("amount", 0)
		target_position = 0
		readable_text = "BLOCK +%d" % amount
	elif action.get("type") in ["buff", "debuff", "shove"]:
		intent_type = action.type
		icon_mode = intent_type
		amount = action.amount
		target_position = action.get("target_position", 0)
		if intent_type == "buff":
			readable_text = "BUFF +%d BLK" % amount
		elif intent_type == "debuff":
			readable_text = "%s %d > H%d" % [action.status.to_upper(), amount, target_position]
		else:
			readable_text = "H%d %s" % [target_position, "PUSH BACK" if action.direction == 1 else "PUSH FRONT"]
	else:
		icon_mode = "none"
		intent_type = ""
		amount = 0
		target_position = 0
		readable_text = "NO ACTION"
	_update_visuals()


func _update_visuals() -> void:
	# Every transition re-selects the icon, so a preceding action's texture is cleared
	# (assigned null) before the new mode draws.
	icon_texture = icon_texture_for(icon_mode)
	queue_redraw()


func _draw() -> void:
	var patch := patch_rect()
	# Uniform-height fit of the authored patch art: the stitched outline, icon and
	# caption all stay inside the visible tag instead of overflowing the top edge.
	var scale_y := patch.size.y / PATCH_CONTENT_HEIGHT
	draw_set_transform(Vector2(0.0, patch.position.y - 3.0 * scale_y), 0, Vector2(1.0, scale_y))
	# Torn-edged paper patch with a hand-stitched perimeter and distinct silhouettes.
	var paper := PackedVector2Array([
		Vector2(3, 5), Vector2(52, 3), Vector2(57, 10),
		Vector2(55, 37), Vector2(49, 42), Vector2(5, 39), Vector2(2, 32)])
	draw_colored_polygon(paper, CREAM.darkened(0.14) if icon_mode == "slain" else CREAM)
	draw_polyline(paper + PackedVector2Array([paper[0]]), SLATE, 2.0, true)
	for x in [12.0, 24.0, 36.0, 48.0]:
		draw_line(Vector2(x, 4), Vector2(x + 3, 9), SLATE, 1.4, true)
		draw_line(Vector2(x, 38), Vector2(x + 3, 33), SLATE, 1.4, true)
	# The committed HUD icon fills the sewn icon area at its own proportions. A mode with
	# no available image (shove, Unravelled, slain, unknown) keeps the drawn sewn glyph.
	draw_set_transform(Vector2.ZERO)
	var icon := icon_texture_rect()
	if icon.size.x > 0.0 and icon.size.y > 0.0:
		draw_texture_rect(icon_texture, icon, false)
	else:
		draw_set_transform(Vector2(0.0, patch.position.y - 3.0 * scale_y), 0, Vector2(1.0, scale_y))
		_draw_glyph()
		draw_set_transform(Vector2.ZERO)
	# Draw text on this noninteractive canvas rather than inserting another Label
	# into the legacy two-Label enemy roster (its other live consumers expect two).
	draw_string(get_theme_default_font(), Vector2(62, patch.end.y - 5.0), readable_text,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 64, 14,
		MUTED if icon_mode in ["slain", "none"] else CREAM)
	# Miniature rust-felt ticket in the upper-right strip, clear of the old caption.
	if not policy_cue.is_empty():
		var font := get_theme_default_font()
		var text_width := font.get_string_size(policy_cue, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var x := maxf(64.0, size.x - text_width - 9.0)
		var tag := Rect2(x - 4.0, 0.5, text_width + 8.0, 10.0)
		draw_rect(tag, SLATE)
		draw_line(Vector2(tag.position.x + 2.0, tag.position.y + 1.0),
			Vector2(tag.end.x - 2.0, tag.position.y + 1.0), RUST, 1.0)
		draw_string(font, Vector2(x, 8.5), policy_cue,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, CREAM)


## Drawn sewn-glyph fallback in the patch's own scaled art coordinates. Used for every
## mode without a loaded committed icon, so the badge stays readable without any PNG.
func _draw_glyph() -> void:
	if icon_mode == "attack":
		# Rust-red diagonal spearhead, visibly different from the shield.
		draw_line(Vector2(15, 31), Vector2(40, 11), RUST, 4.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(29, 8), Vector2(46, 6), Vector2(42, 23)]), RUST)
		draw_line(Vector2(13, 25), Vector2(22, 34), SLATE, 3.0, true)
	elif icon_mode == "block":
		var shield := PackedVector2Array([
			Vector2(14, 11), Vector2(29, 6), Vector2(44, 11),
			Vector2(41, 27), Vector2(29, 36), Vector2(17, 27)])
		draw_colored_polygon(shield, SLATE)
		draw_polyline(shield + PackedVector2Array([shield[0]]), RUST, 2.0, true)
		draw_line(Vector2(29, 11), Vector2(29, 30), CREAM, 2.0, true)
		draw_line(Vector2(21, 19), Vector2(37, 19), CREAM, 2.0, true)
	elif icon_mode == "buff":
		draw_circle(Vector2(29, 22), 12, SLATE)
		draw_line(Vector2(20, 22), Vector2(38, 22), RUST, 4)
		draw_line(Vector2(29, 13), Vector2(29, 31), RUST, 4)
	elif icon_mode == "debuff":
		draw_colored_polygon(PackedVector2Array([Vector2(29, 8), Vector2(44, 33), Vector2(14, 33)]), RUST)
		draw_line(Vector2(29, 15), Vector2(29, 25), CREAM, 3)
	elif icon_mode == "shove":
		draw_line(Vector2(12, 22), Vector2(44, 22), RUST, 4)
		draw_line(Vector2(34, 12), Vector2(44, 22), RUST, 4)
		draw_line(Vector2(34, 32), Vector2(44, 22), RUST, 4)
	elif icon_mode == "unravelled":
		# Two separated loose thread ends and crossed scissors, never an attack spear.
		draw_dashed_line(Vector2(12, 29), Vector2(28, 15), RUST, 2.5, 4.0)
		draw_dashed_line(Vector2(29, 28), Vector2(45, 13), RUST, 2.5, 4.0)
		draw_line(Vector2(20, 13), Vector2(40, 33), SLATE, 2.5, true)
		draw_line(Vector2(40, 13), Vector2(20, 33), SLATE, 2.5, true)
		draw_arc(Vector2(17, 12), 4.0, 0.0, TAU, 12, RUST, 2.0)
		draw_arc(Vector2(42, 33), 4.0, 0.0, TAU, 12, RUST, 2.0)
	elif icon_mode == "slain":
		draw_line(Vector2(18, 12), Vector2(41, 32), MUTED, 4.0, true)
		draw_line(Vector2(41, 12), Vector2(18, 32), MUTED, 4.0, true)
