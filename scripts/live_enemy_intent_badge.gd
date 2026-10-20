class_name LiveEnemyIntentBadge
extends Control
## View-only sewn-paper announcement. Source positions come from CombatEnemyIntents.

const CREAM := Color("#e9dfcb")
const SLATE := Color("#34444b")
const RUST := Color("#a55f4b")
const MUTED := Color("#777a76")

var source_position := 0
var icon_mode := "none"
var readable_text := "NO ACTION"
var intent_type := ""
var amount := 0
var target_position := 0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(285, 44)
	queue_redraw()


func show_intent(action: Dictionary, slain: bool) -> void:
	# Never affect or advance the scheduler: the caller passes a copied announcement.
	if slain:
		icon_mode = "slain"
		intent_type = ""
		amount = 0
		target_position = 0
		readable_text = "SLAIN"
	elif action.get("type") == "attack":
		icon_mode = "attack"
		intent_type = "attack"
		amount = action.get("amount", 0)
		target_position = action.get("target_position", 0)
		readable_text = "ATTACK %d -> HERO %d" % [amount, target_position]
	elif action.get("type") == "block":
		icon_mode = "block"
		intent_type = "block"
		amount = action.get("amount", 0)
		target_position = 0
		readable_text = "BLOCK +%d" % amount
	else:
		icon_mode = "none"
		intent_type = ""
		amount = 0
		target_position = 0
		readable_text = "NO ACTION"
	_update_visuals()


func _update_visuals() -> void:
	queue_redraw()


func _draw() -> void:
	# Torn-edged paper patch with a hand-stitched perimeter and distinct silhouettes.
	var paper := PackedVector2Array([
		Vector2(3, 5), Vector2(52, 3), Vector2(57, 10),
		Vector2(55, 37), Vector2(49, 42), Vector2(5, 39), Vector2(2, 32)])
	draw_colored_polygon(paper, CREAM.darkened(0.14) if icon_mode == "slain" else CREAM)
	draw_polyline(paper + PackedVector2Array([paper[0]]), SLATE, 2.0, true)
	for x in [12.0, 24.0, 36.0, 48.0]:
		draw_line(Vector2(x, 4), Vector2(x + 3, 9), SLATE, 1.4, true)
		draw_line(Vector2(x, 38), Vector2(x + 3, 33), SLATE, 1.4, true)
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
	elif icon_mode == "slain":
		draw_line(Vector2(18, 12), Vector2(41, 32), MUTED, 4.0, true)
		draw_line(Vector2(41, 12), Vector2(18, 32), MUTED, 4.0, true)
	# Draw text on this noninteractive canvas rather than inserting another Label
	# into the legacy two-Label enemy roster (its other live consumers expect two).
	draw_string(get_theme_default_font(), Vector2(64, 28), readable_text,
		HORIZONTAL_ALIGNMENT_LEFT, 215, 16,
		MUTED if icon_mode in ["slain", "none"] else CREAM)
