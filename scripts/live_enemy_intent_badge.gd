class_name LiveEnemyIntentBadge
extends Control
## View-only sewn-paper announcement. Source positions come from CombatEnemyIntents.

const CREAM := Color("#e9dfcb")
const SLATE := Color("#34444b")
const RUST := Color("#a55f4b")
const MUTED := Color("#777a76")
## Caption backing: a dark felt plaque stitched under the action text, so cream ink keeps
## its contrast over every authored battle backdrop instead of vanishing into light art.
const CAPTION_FILL := Color("#232c31")
const CAPTION_STITCH := Color("#9c9484")
const CAPTION_INK := CREAM
## Slain and no-action tags stay muted, but still read clearly on that dark plaque.
const CAPTION_INK_MUTED := Color("#c4bba9")
## Target policy: its own rust felt ticket, never painted across the caption. It is
## never smaller than 13 px, so the ticket stays readable beside the action.
const POLICY_FILL := Color("#8d4b3a")
const POLICY_INK := CREAM
const POLICY_FONT := 13
## Bounded caption type: the theme's own body size is the short-action size, and only a
## long authentic caption steps down, no further than this floor.
const CAPTION_MAX_FONT := 18
const CAPTION_MIN_FONT := 11
## The sewn display voice is the master Theme's PatchHeading variation, already shipped as
## Londrina Solid Regular. This badge reuses that face for short captions only; it never
## adds a font asset and never assigns the variation, so every other label keeps its body
## face and the shared Theme stays untouched.
const HEADING_VARIATION := "PatchHeading"
const HEADING_FONT_PATH := "res://assets/fonts/LondrinaSolid-Regular.ttf"
## A caption shown beside a policy ticket is already compact, so it never shrinks below
## this floor: the amount and destination stay readable next to the 13 px ticket.
const COMPACT_MIN_FONT := 14
## Caption layout in badge coordinates, right of the unchanged sewn patch. The targeting
## ticket now spells out "Aim low HP" instead of reading like a health status, so the sewn
## insets are a couple of pixels tighter than before: at the narrowest real 192 px band the
## longest authored debuff caption still fits at the 14 px action floor (its measured ladder
## steps to the tight "Exposed 2→2" form), and the plaque keeps a 1 px stitched seam clear
## of the ticket.
const CAPTION_LEFT := 59.0
const CAPTION_MARGIN := 2.0
const CAPTION_PAD := 3.0
const CAPTION_TOP := 1.0
const CAPTION_BOTTOM := 1.0
const POLICY_PAD := 3.0
const POLICY_GAP := 2.0
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
## Slow, presentation-only opacity breathing of the authored icon; never moves its rect.
const ICON_PULSE_PERIOD := 3.2
const ICON_PULSE_MIN_ALPHA := 0.78
const REDUCED_MOTION_SETTING := "accessibility/reduced_motion"
## Committed HUD icon per announced action mode. Attack and block map to the authored
## attack/defend art; anything without an entry (shove, Unravelled, slain, unknown) keeps
## the drawn sewn glyph, so no PNG is required.
const ICON_DIR := "res://assets/paper/ui/"
const ICON_ART := {
	"attack": "intent_attack.png",
	"block": "intent_defend.png",
	"buff": "intent_buff.png",
	"debuff": "intent_debuff.png",
	"snip_block": "intent_debuff.png",
}

var source_position := 0
var icon_mode := "none"
var readable_text := "NO ACTION"
var intent_type := ""
var amount := 0
var target_position := 0
## Authored debuff status (lowercase) and shove direction of the current announcement.
## They are kept only so a relayout can rebuild the compact policy caption.
var action_status := ""
var shove_direction := 0
## Presentation-only authenticated bonus for this particular attack; cleared on every call.
var enrage_bonus := -1
## Genuine two-hit presentation state, cleared on every call. The badge shows both hits only
## for the exact canonical attack CombatEnemyPhase really resolves as two independent
## packets; hit_damage is the first packet's pre-mitigation damage (odd points go first),
## or -1 while the announcement is a single hit.
var hit_count := 1
var hit_damage := -1
## True only for a trusted living source's next attack; this never spends the token.
var blind_miss := false
## Presentation-only Charge presentation state ("wind_up", "strike", or ""); cleared on every call.
var charge_state := ""
var charge_base_damage := -1
var charge_projected_damage := -1
## Empty unless a valid mounted weighted action supplies its real policy.
var policy_cue := ""
const POLICY_LABELS := {"front": "Front", "lowest_living_hp": "Aim low HP",
	"exposed": "Exposed", "random": "Random"}
## The hover explains the priority in full words, naming the hero and its *current* HP: this
## cue is about the target, never about the acting enemy's own health or a Weak status.
const POLICY_DESCRIPTIONS := {
	"front": "picks the front living hero",
	"lowest_living_hp": "aims at the living hero with the lowest current HP",
	"exposed": "prioritises an Exposed living hero",
	"random": "uses the run-seeded target choice",
}
## Passive contact rules are supplementary help, never a second announced action.
## These are deliberately conditional: Guard can change the recipient and Block can
## absorb the entire hit. An announced Bleed debuff is a separate action.
const CONTACT_HELP := {
	"drain": "Drain: Only after this living enemy's confirmed attack removes HP from the actual recipient (after Guard redirection and hero Block), heal this enemy by the HP actually lost, up to its missing HP. Fully Blocked hits, skipped attacks, slain sources and previews cannot heal it.",
	"bleed_on_attack": "Bleeding Sting: Only after this living enemy's confirmed attack removes HP from the actual recipient (after Guard redirection and hero Block), apply Bleed 1 to that recipient. Fully Blocked hits, skipped attacks, slain sources and previews cause no sting. This passive is separate from an announced Bleed debuff.",
}


static func rank_caption(pos: int) -> String:
	return {1: "Front", 2: "Middle", 3: "Back"}.get(pos, "Hero %d" % pos)


static func hero_target_label(pos: int) -> String:
	match pos:
		1:
			return "Hero 1 (front)"
		2:
			return "Hero 2 (middle)"
		3:
			return "Hero 3 (back)"
		_:
			return "Hero %d" % pos


## True only for the exact authored attack shape CombatEnemyPhase really resolves as two
## independent packets: an attack with an integer amount, one real hero target and the
## integer hits 2, with no invented keys. Anything else - including malformed hits
## metadata - stays one announced hit, so the view never forges an extra strike.
static func is_two_hit_attack(action: Dictionary) -> bool:
	if action.get("type") != "attack":
		return false
	var amount: Variant = action.get("amount")
	var target: Variant = action.get("target_position")
	var hits: Variant = action.get("hits")
	if not amount is int or amount < 0:
		return false
	if not target is int or target < 1 or target > 3:
		return false
	if not hits is int or hits != 2:
		return false
	for key in action:
		if not (key in ["type", "amount", "target_position", "hits", "enemy_position", "move"]):
			return false
	if action.has("move"):
		var move: Variant = action["move"]
		if not move is String or move not in ["attack2", "attack3"]:
			return false
	if action.has("enemy_position"):
		var source: Variant = action["enemy_position"]
		if not source is int or source < 1 or source > CombatEnemies.OPT_IN_MAX_ENEMIES:
			return false
	return true


## The two pre-mitigation packet damages of a genuine two-hit attack, in the exact order
## CombatEnemyPhase resolves them: an odd point in the total goes to the first packet.
## Empty only for a negative total, which is never a valid announcement.
static func two_hit_damages(total: int) -> Array[int]:
	var packets: Array[int] = []
	if total < 0:
		return packets
	@warning_ignore("integer_division")
	var low := total / 2
	packets.append(low + total % 2)
	packets.append(low)
	return packets


## A Theme's authored PatchHeading face, or null when that Theme merely falls back to its
## own default font. The badge reads this; no Control ever copies the variation.
static func patch_heading_face(source: Theme) -> Font:
	if source == null:
		return null
	if not source.get_font_list(HEADING_VARIATION).has("font"):
		return null
	var face := source.get_font("font", HEADING_VARIATION)
	if face == null or face == source.default_font:
		return null
	return face


## The already-shipped Londrina Solid file that backs PatchHeading. No new asset is loaded,
## and a missing file is simply null so the caption keeps its readable body face.
static func load_heading_font(path: String) -> Font:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Font


## The committed HUD texture selected for the current mode; null draws the sewn glyph.
var icon_texture: Texture2D = null
## Presentation-only art root. A redirected or unavailable root (missing file or import)
## keeps the drawn glyph instead of failing, without changing any authoritative text.
var icon_root := ICON_DIR
## Presentation-only display-face path. A redirected or unavailable file keeps the
## readable body face instead of failing, and it never edits the shared Theme.
var heading_font_path := HEADING_FONT_PATH
## Key: icon art path, value: Texture2D or null. A negative entry is cached too, so an
## unavailable image is never probed twice and the drawn glyph stays the fallback.
var _icon_cache: Dictionary = {}
var _icon_pulse_elapsed := 0.0
var _reduced_motion_override: Variant = null
## The display-face path actually probed, so redraws never reload the shipped font file.
var _heading_probed_path := ""
var _fallback_heading: Font = null
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(BADGE_WIDTH, BADGE_HEIGHT)
	tooltip_text = "No action."
	# The fitted caption depends on the mounted width, so a relayout re-fits the compact
	# policy caption and repaints the tag.
	resized.connect(_relayout)
	set_process(false)
	queue_redraw()


## An optional bool override follows the other shipped UI art motions.
func set_reduced_motion_override(value: Variant) -> void:
	_reduced_motion_override = value if value is bool else null
	_sync_icon_pulse()


func _reduced_motion() -> bool:
	if _reduced_motion_override is bool:
		return _reduced_motion_override
	return ProjectSettings.get_setting(REDUCED_MOTION_SETTING, false) == true


## A real visible mounted action with actual imported artwork is the only pulse owner.
## Slain, Unravelled, empty actions and sewn fallback glyphs remain static.
func icon_pulse_active() -> bool:
	return is_inside_tree() and is_visible_in_tree() and not _reduced_motion() \
		and not intent_type.is_empty() and icon_texture_rect().has_area()


## Deterministic icon alpha; the authored texture rect, caption, policy and patch do not move.
func icon_pulse_alpha() -> float:
	if not icon_pulse_active():
		return 1.0
	return 1.0 - (1.0 - ICON_PULSE_MIN_ALPHA) * \
		(0.5 - 0.5 * cos(TAU * _icon_pulse_elapsed / ICON_PULSE_PERIOD))


## Testable clock advance, shared with the live SceneTree process path. No RNG or game state.
func advance_icon_pulse(delta: float) -> void:
	if delta <= 0.0 or not icon_pulse_active():
		return
	_icon_pulse_elapsed = fposmod(_icon_pulse_elapsed + delta, ICON_PULSE_PERIOD)
	queue_redraw()


func _sync_icon_pulse() -> void:
	_icon_pulse_elapsed = 0.0
	set_process(icon_pulse_active())
	if is_inside_tree():
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_icon_pulse_elapsed = 0.0
		set_process(false)
	elif what in [NOTIFICATION_VISIBILITY_CHANGED, NOTIFICATION_ENTER_TREE] \
			and is_node_ready():
		_sync_icon_pulse()


func _process(delta: float) -> void:
	if not icon_pulse_active():
		_sync_icon_pulse()
		return
	advance_icon_pulse(delta)


## Re-fit the displayed caption after the mounted width changes, so a compact policy
## caption never clips and can use the widest form that measures inside the new room.
func _relayout() -> void:
	if not policy_cue.is_empty():
		_apply_compact_caption()
	queue_redraw()


## Read-only display face: the nearest mounted Theme that really defines PatchHeading, else
## the committed Londrina Solid file. It never assigns the variation to this badge, so the
## battle's body text keeps the body face and the shipped fallback stays reachable.
func heading_font() -> Font:
	var mounted := inherited_theme()
	if mounted != null:
		var face := patch_heading_face(mounted)
		if face != null:
			return face
	if heading_font_path != _heading_probed_path:
		_heading_probed_path = heading_font_path
		_fallback_heading = load_heading_font(heading_font_path)
	return _fallback_heading


## The nearest Theme mounted on this badge or an ancestor that really defines PatchHeading.
func inherited_theme() -> Theme:
	var node: Node = self
	while node != null:
		var mounted: Theme = null
		if node is Control:
			mounted = (node as Control).theme
		elif node is Window:
			mounted = (node as Window).theme
		if mounted != null and patch_heading_face(mounted) != null:
			return mounted
		node = node.get_parent()
	return null


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


## The strip right of the sewn patch that the caption and its stitched plaques may use.
## The whole tag keeps its mounted size and anchors; only the painted text fits inside.
func caption_area_rect() -> Rect2:
	var width := maxf(0.0, size.x - CAPTION_LEFT - CAPTION_MARGIN)
	var height := maxf(0.0, size.y - CAPTION_TOP - CAPTION_BOTTOM)
	return Rect2(CAPTION_LEFT, CAPTION_TOP, width, height)


## The separate rust-felt ticket of a target-policy cue; empty whenever none is announced,
## and never overlapped by the caption because the caption is fitted around it.
func policy_rect() -> Rect2:
	var area := caption_area_rect()
	var font := policy_font()
	if policy_cue.is_empty() or font == null or area.size.x <= 0.0:
		return Rect2()
	var width := font.get_string_size(policy_cue, HORIZONTAL_ALIGNMENT_LEFT, -1,
		POLICY_FONT).x + POLICY_PAD * 2.0
	var height := minf(font.get_height(POLICY_FONT) + 2.0, area.size.y)
	return Rect2(area.end.x - width, area.position.y + (area.size.y - height) * 0.5,
		width, height)


## The horizontal room left for the action caption once the policy ticket is excluded.
func caption_text_area() -> Rect2:
	var area := caption_area_rect()
	var right := area.end.x - CAPTION_PAD
	var tag := policy_rect()
	if tag.size.x > 0.0:
		right = tag.position.x - POLICY_GAP
	var left := area.position.x + CAPTION_PAD
	return Rect2(left, area.position.y, maxf(0.0, right - left), area.size.y)


## Largest bounded caption size whose measured text fits that room with the effective Font.
## Short actions get the theme's own body size; only a long authentic caption steps down,
## never below its floor.
func caption_font_size() -> int:
	var font := caption_font()
	var room := caption_text_area()
	var floor_size := caption_floor_font()
	if font == null or room.size.x <= 0.0:
		return floor_size
	for size_px in range(CAPTION_MAX_FONT, floor_size - 1, -1):
		if font.get_string_size(readable_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x \
				<= room.size.x:
			return size_px
	return floor_size


## The one Font the caption is really measured and painted with. A short authentic phrase
## takes the sewn heading face when its own glyph bounds fit the fitted room at the full
## short-action size; a longer phrase keeps the readable body face instead of a clipped or
## shrunken heading, so its amount, target and direction are never lost.
func caption_font() -> Font:
	var body := get_theme_default_font()
	var heading := heading_font()
	if heading == null or heading == body:
		return body
	var room := caption_text_area()
	if room.size.x > 0.0 and heading.get_string_size(readable_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, CAPTION_MAX_FONT).x <= room.size.x:
		return heading
	return body


## The one Font of the small 13 px policy ticket: the readable body face, so the ticket
## keeps its unchanged compact measurement and geometry beside the heading caption. The
## measured rect and the painted label both use this Font, never a second choice.
func policy_font() -> Font:
	return get_theme_default_font()


## The smallest size this caption may use. A compact caption shown beside a policy ticket
## keeps the 14 px action floor; a full caption keeps the wider bounded range.
func caption_floor_font() -> int:
	return COMPACT_MIN_FONT if not policy_cue.is_empty() else CAPTION_MIN_FONT


## Compact, unambiguous action forms in preference order: exact amount, target number and
## shove direction. Empty whenever no policy ticket is shown, so a no-policy badge keeps
## its full caption exactly as before.
func compact_caption_forms() -> Array[String]:
	var forms: Array[String] = []
	if policy_cue.is_empty():
		return forms
	match intent_type:
		"attack":
			if enrage_bonus >= 0:
				if hit_count == 2:
					forms.append("Hit %d+%d A-2 → %d" % [amount, enrage_bonus, target_position])
					forms.append("Hit %d+%d A-2" % [amount, enrage_bonus])
					forms.append("%d+%dA-2→%d" % [amount, enrage_bonus, target_position])
					forms.append("%d+%dA-2" % [amount, enrage_bonus])
				else:
					forms.append("Hit %d+%d→%d" % [amount, enrage_bonus, target_position])
					forms.append("Hit %d+%d" % [amount, enrage_bonus])
					forms.append("%d+%d" % [amount, enrage_bonus])
			elif hit_count == 2:
				# The ticket already names the aim; A-2 keeps the base total and both
				# independently resolved packets readable at the compact 14 px floor.
				forms.append("Hit %d A-2 → %d" % [amount, target_position])
				forms.append("Hit %d A-2" % amount)
				forms.append("%dA-2→%d" % [amount, target_position])
				forms.append("%dA-2" % amount)
			elif charge_state == "wind_up":
				forms.append("WIND UP → %d" % target_position)
				forms.append("WIND UP→%d" % target_position)
				forms.append("WIND UP")
			elif charge_state == "strike":
				forms.append("CHARGE %d → %d" % [amount, target_position])
				forms.append("CHARGE %d→%d" % [amount, target_position])
				forms.append("CHARGE %d" % amount)
			else:
				forms.append("Hit %d → %d" % [amount, target_position])
				forms.append("Hit %d→%d" % [amount, target_position])
		"debuff":
			var label := "Blind" if action_status == "blind_next_attack" else action_status.capitalize()
			forms.append("%s %d → %d" % [label, amount, target_position])
			forms.append("%s %d→%d" % [label, amount, target_position])
		"shove":
			var long_dir := "back" if shove_direction == 1 else "forward"
			var short_dir := "back" if shove_direction == 1 else "fwd"
			forms.append("Shove %d %s" % [target_position, long_dir])
			forms.append("Shove %d %s" % [target_position, short_dir])
		"snip_block":
			forms.append("Snip Block→%d" % target_position)
			forms.append("Snip→%d" % target_position)
	return forms


## The compact form actually displayed: the first one measured to fit beside the ticket at
## the action floor, otherwise the shortest one. Each candidate is measured with the same
## effective Face caption_font() will paint it with. Only called while a ticket is shown;
## the full action, amount, target and rule stay in tooltip_text.
func _apply_compact_caption() -> void:
	var forms := compact_caption_forms()
	if forms.is_empty():
		return
	var chosen := forms[forms.size() - 1]
	var room := caption_text_area()
	if room.size.x > 0.0:
		for form in forms:
			readable_text = form
			var font := caption_font()
			if font != null and font.get_string_size(form, HORIZONTAL_ALIGNMENT_LEFT, -1,
					COMPACT_MIN_FONT).x <= room.size.x:
				chosen = form
				break
	readable_text = chosen


## High-contrast ink on the dark plaque; inert states keep a muted but still legible cream.
func caption_ink() -> Color:
	return CAPTION_INK_MUTED if icon_mode in ["slain", "none"] else CAPTION_INK


## Where the fitted caption is really painted, in this badge's own coordinates, measured
## with the same effective Font the draw path uses.
func caption_text_rect() -> Rect2:
	var font := caption_font()
	var room := caption_text_area()
	if font == null or room.size.x <= 0.0:
		return Rect2()
	var size_px := caption_font_size()
	var width := font.get_string_size(readable_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var ascent := font.get_ascent(size_px)
	var descent := font.get_descent(size_px)
	var baseline := room.position.y + (room.size.y + ascent - descent) * 0.5
	return Rect2(room.position.x, baseline - ascent, width, ascent + descent)


## The dark stitched plaque actually painted behind the caption, hugging the fitted text so
## the tag still reads as a sewn label rather than a bar across the actor's stage.
func caption_rect() -> Rect2:
	var area := caption_area_rect()
	var text := caption_text_rect()
	if text.size.x <= 0.0 or area.size.x <= 0.0:
		return area
	var left := maxf(area.position.x, text.position.x - CAPTION_PAD)
	var right := minf(area.end.x, text.end.x + CAPTION_PAD)
	# A policy ticket keeps its own felt edge: the plaque stops one pixel short of it so
	# the two sewn pieces never merge into one bar.
	var tag := policy_rect()
	if tag.size.x > 0.0:
		right = minf(right, tag.position.x - 1.0)
	return Rect2(left, area.position.y, right - left, area.size.y)


## Where the policy ticket's own caption is painted, for mounted fit checks.
func policy_text_rect() -> Rect2:
	var font := policy_font()
	var tag := policy_rect()
	if font == null or tag.size.x <= 0.0:
		return Rect2()
	var ascent := font.get_ascent(POLICY_FONT)
	var descent := font.get_descent(POLICY_FONT)
	var baseline := tag.position.y + (tag.size.y + ascent - descent) * 0.5
	return Rect2(tag.position.x + POLICY_PAD, baseline - ascent,
		font.get_string_size(policy_cue, HORIZONTAL_ALIGNMENT_LEFT, -1, POLICY_FONT).x,
		ascent + descent)


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


## Set only after the roster authenticates this refresh's announced source.
var move_name := ""


func append_verified_move_name(title: String) -> void:
	if title.is_empty() or not move_name.is_empty() or intent_type.is_empty():
		return
	move_name = title
	tooltip_text += "\nMove: " + title


func show_intent(action: Dictionary, slain: bool, skip_pending: bool = false,
		policy: String = "", source_enrage_stacks: int = -1,
		contact_traits: Dictionary = {}, source_blind: bool = false,
		charge_context: Dictionary = {}, summon_context: Dictionary = {}) -> void:
	# Never affect or advance the scheduler: the caller passes a copied announcement.
	move_name = ""
	# Only targeted, active, authored actions receive the small policy tag.
	policy_cue = ""
	action_status = ""
	shove_direction = 0
	enrage_bonus = -1
	hit_count = 1
	hit_damage = -1
	blind_miss = false
	charge_state = ""
	charge_base_damage = -1
	charge_projected_damage = -1
	if not slain and not skip_pending and charge_context is Dictionary \
			and charge_context.get("valid") == true \
			and charge_context.get("state") in ["wind_up", "strike"]:
		var base: Variant = charge_context.get("base_amount")
		var proj: Variant = charge_context.get("projected_damage")
		if base is int and base > 0 and proj is int and proj > 0:
			charge_state = String(charge_context["state"])
			charge_base_damage = base
			charge_projected_damage = proj
	if not slain and not skip_pending and action.get("type") in ["attack", "debuff", "shove", "snip_block"] \
			and action.get("target_position") in [1, 2, 3] and POLICY_LABELS.has(policy):
		policy_cue = POLICY_LABELS[policy]
	var tip := ""
	if slain:
		icon_mode = "slain"
		intent_type = ""
		amount = 0
		target_position = 0
		readable_text = "SLAIN"
		tip = "Slain: no action."
	elif skip_pending:
		icon_mode = "unravelled"
		intent_type = ""
		amount = 0
		target_position = 0
		readable_text = "UNRAVELLED"
		tip = "Unravelled: next action is skipped."
	elif action.get("type") == "attack":
		icon_mode = "attack"
		intent_type = "attack"
		amount = action.get("amount", 0)
		target_position = action.get("target_position", 0)
		# Two independent packets exist only when the copied announcement really authors
		# the canonical integer hits 2; the scheduler is never re-read or re-rolled here.
		var two_hit := is_two_hit_attack(action)
		if two_hit:
			hit_count = 2
		var enraged := source_enrage_stacks >= 0 \
			and source_enrage_stacks <= CombatEnemyKeywordRules.ENRAGE_MAX_STACKS
		if enraged:
			enrage_bonus = source_enrage_stacks * CombatEnemyKeywordRules.ENRAGE_ATTACK_BONUS_PER_STACK
		var packets: Array[int] = []
		if two_hit:
			packets = two_hit_damages(amount + (enrage_bonus if enraged else 0))
			hit_damage = packets[0]
		if two_hit and enraged:
			readable_text = "Hit %d (2 hits) +%d Enrage" % [amount, enrage_bonus]
			tip = ("%dA-2: two hits — Base %d + %d Enrage (%d/3 stacks) = %d total attack power BEFORE Weak/Exposed adjustment, Guard redirection and hero Block. That total is split into %d + %d base damage, both packets aimed at %s; the +%d Enrage is added to the total once, never +%d per packet. Each packet is resolved independently against Block, so this is not guaranteed to deal %d HP of damage." % [
				amount, amount, enrage_bonus, source_enrage_stacks, amount + enrage_bonus,
				packets[0], packets[1], hero_target_label(target_position), enrage_bonus,
				enrage_bonus, (amount + enrage_bonus) * 2])
		elif two_hit:
			readable_text = "Hit %d (2 hits): %s" % [amount, rank_caption(target_position)]
			tip = ("%dA-2: two hits — the announced %d attack is split into %d + %d base damage, both packets aimed at %s. Each packet is resolved independently against Block (and may change after Guard or hero statuses), so this is not guaranteed to deal %d HP of damage." % [
				amount, amount, packets[0], packets[1], hero_target_label(target_position),
				amount * 2])
		elif enraged:
			readable_text = "Hit %d +%d Enrage" % [amount, enrage_bonus]
			tip = "Base %d aimed at %s + %d Enrage (%d/3 stacks) = %d attack power BEFORE Weak/Exposed adjustment, Guard redirection and hero Block; not guaranteed HP loss." % [
				amount, hero_target_label(target_position), enrage_bonus,
				source_enrage_stacks, amount + enrage_bonus]
		elif charge_state == "wind_up":
			readable_text = "WIND UP: %s" % rank_caption(target_position)
			tip = "Wind Up aimed at %s: this action deals 0 damage now and prepares a strike at floor(%d * 2.5) = %d before status/Block mitigation." % [
				hero_target_label(target_position), charge_base_damage, charge_projected_damage]
		elif charge_state == "strike":
			readable_text = "CHARGE %d: %s" % [amount, rank_caption(target_position)]
			tip = "Charge strike: %d damage (2.5x base %d) aimed at %s before status/Block mitigation; actual loss may be reduced by Block/Weak/Exposed or redirects." % [
				amount, charge_base_damage, hero_target_label(target_position)]
		else:
			readable_text = "Hit %d: %s" % [amount, rank_caption(target_position)]
			tip = "%d damage aimed at %s." % [amount, hero_target_label(target_position)]
	elif action.get("type") == "steal_gold":
		icon_mode = "steal_gold"
		intent_type = "steal_gold"
		amount = action.get("amount", 0)
		target_position = 0
		readable_text = "Steal %d gold" % amount
		tip = "Steal %d gold from the run wallet, down to zero. No hero target, HP damage or Block consumption." % amount
	elif action.get("type") == "snip_block":
		icon_mode = "snip_block"
		intent_type = "snip_block"
		amount = 0
		target_position = action.get("target_position", 0)
		readable_text = "Snip Block: %s" % rank_caption(target_position)
		tip = "Snip Block on %s: remove all Block; no direct HP damage." % hero_target_label(target_position)
	elif action.get("type") == "summon":
		icon_mode = "summon"
		intent_type = "summon"
		amount = 0
		target_position = 0
		readable_text = "Summon Broodling"
		# The caller supplies the currently bound roster's real limit and eligibility.
		# Never promise a birth from a standalone or untrusted announcement.
		var capacity: Variant = summon_context.get("capacity")
		var occupied: Variant = summon_context.get("occupied")
		var can_spawn: Variant = summon_context.get("can_spawn")
		if capacity is int and capacity in [CombatEnemies.MAX_ENEMIES,
				CombatEnemies.OPT_IN_MAX_ENEMIES] and occupied is int \
				and occupied >= 1 and occupied <= capacity and can_spawn is bool:
			if can_spawn and occupied < capacity:
				tip = "Summon: one 8 HP Moth Broodling will be born into slot %d (maximum %d enemies). It does not attack on its birth turn; its attack 5 is announced for the following turn." % [occupied + 1, capacity]
			else:
				tip = "Summon: no Broodling is born (maximum %d enemies; no free slot or already summoned). An 8 HP Broodling's attack 5 is announced for the following turn, not its birth turn." % capacity
		else:
			tip = "Summon attempt: an 8 HP Moth Broodling can be born only with a free enemy slot and an unused summon. Its attack 5 is announced for the following turn, not its birth turn."
	elif action.get("type") == "block":
		icon_mode = "block"
		intent_type = "block"
		amount = action.get("amount", 0)
		target_position = 0
		readable_text = "Block +%d" % amount
		tip = "%d Block on the acting enemy." % amount
	elif action.get("type") in ["buff", "debuff", "shove"]:
		intent_type = action.type
		icon_mode = intent_type
		amount = action.amount
		target_position = action.get("target_position", 0)
		if intent_type == "buff":
			readable_text = "Buff +%d Block" % amount
			tip = "%d Block on the acting enemy." % amount
		elif intent_type == "debuff":
			readable_text = "%s %d: %s" % [action.status.capitalize(), amount, rank_caption(target_position)]
			var status_name := String(action.get("status", "")).to_lower()
			action_status = status_name
			# The three authored debuffs explain their own rule in full: the affected hero,
			# the amount, the turn duration, Bleed's Block bypass and the rounded damage of
			# Weak and Exposed. Only attack damage and the Bleed tick are described here.
			if status_name == "blind_next_attack":
				readable_text = "Blind 1: %s" % rank_caption(target_position)
				tip = "Blind 1 to %s — that hero\'s next attempted attack misses once. The token is consumed only by a legal paid attack, not by a preview or a nonattack card." % hero_target_label(target_position)
			elif status_name == "bleed":
				tip = "Bleed %d to %s — that hero loses %d HP at its turn end, ignoring Block; Bleed then decreases by 1 (from %d to %d)." % [
					amount, hero_target_label(target_position), amount, amount, maxi(0, amount - 1)]
			elif status_name == "weak":
				tip = "Weak %d to %s — for %d turn%s, -25%% outgoing attack damage; damage is rounded down, minimum 0." % [
					amount, hero_target_label(target_position), amount, "" if amount == 1 else "s"]
			elif status_name == "exposed":
				tip = "Exposed %d to %s — for %d turn%s, +50%% incoming attack damage; damage is rounded down, minimum 0." % [
					amount, hero_target_label(target_position), amount, "" if amount == 1 else "s"]
			else:
				tip = "%s %d to %s." % [
					status_name.capitalize(), amount, hero_target_label(target_position)]
		else:
			var push_dir := "push back" if action.direction == 1 else "push front"
			shove_direction = action.direction if action.direction is int else 0
			readable_text = "Shove %s %s" % [rank_caption(target_position), "back" if action.direction == 1 else "forward"]
			tip = "Push %s %s." % [push_dir.trim_prefix("push "), hero_target_label(target_position)]
	else:
		icon_mode = "none"
		intent_type = ""
		amount = 0
		target_position = 0
		readable_text = "NO ACTION"
		tip = "No action."
	# A living, authenticated source's attack cannot hurt its target while Blind is
	# waiting. Keep the real attack/packet details as conditional hover context,
	# but make the sewn caption itself announce the entire missed attempt.
	# An unarmed charge wind-up is a telegraph/skip that deals 0 now; Blind is
	# preserved for the armed charged attack rather than claimed as missed.
	if intent_type == "attack" and source_blind:
		if charge_state == "wind_up":
			tip = "Wind Up aimed at %s: this action deals 0 damage now and prepares a strike at floor(%d * 2.5) = %d before status/Block mitigation. Blind remains for the later charged attack." % [
				hero_target_label(target_position), charge_base_damage, charge_projected_damage]
		else:
			blind_miss = true
			readable_text = "BLIND · MISS"
			var packet_note := " Neither of the two authored hit packets resolves." if hit_count == 2 else ""
			tip = "Blind: the entire next attempted attack aimed at %s will MISS.%s No hero HP or Block is lost to this attack; this preview does not consume Blind.\nWithout Blind: %s" % [
				hero_target_label(target_position), packet_note, tip]
			# The long target policy is still in the hover, but its separate ticket
			# yields the finite 192x28 caption space to the essential MISS warning.
			policy_cue = ""
	if (not policy_cue.is_empty() or blind_miss) and POLICY_DESCRIPTIONS.has(policy):
		tip += "\nTarget policy (%s): %s." % [POLICY_LABELS[policy].to_upper(), POLICY_DESCRIPTIONS[policy]]
	if not slain:
		for keyword in ["drain", "bleed_on_attack"]:
			var enabled: Variant = contact_traits.get(keyword, false)
			if enabled is bool and enabled == true:
				tip += "\nPassive (not the announced action): " + String(CONTACT_HELP[keyword])
	tooltip_text = tip
	# A policy ticket shares this same sewn band, so the displayed action switches to its
	# measured compact form; the tooltip above keeps the full amount, target and rule.
	if not policy_cue.is_empty():
		_apply_compact_caption()
	_update_visuals()


func _update_visuals() -> void:
	# Every transition re-selects the icon, so a preceding action's texture is cleared
	# (assigned null) before the new mode draws.
	icon_texture = icon_texture_for(icon_mode)
	_sync_icon_pulse()


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
		draw_texture_rect(icon_texture, icon, false, Color(1.0, 1.0, 1.0, icon_pulse_alpha()))
	else:
		draw_set_transform(Vector2(0.0, patch.position.y - 3.0 * scale_y), 0, Vector2(1.0, scale_y))
		_draw_glyph()
		draw_set_transform(Vector2.ZERO)
	# Draw text on this noninteractive canvas rather than inserting another Label
	# into the legacy two-Label enemy roster (its other live consumers expect two).
	_draw_caption()


## The stitched caption tag: a dark felt plaque with cream ink, plus the separate
## rust-felt ticket that carries a target-policy cue. All of it is painted here, so the
## badge still mounts no child control and never takes pointer or keyboard input.
func _draw_caption() -> void:
	var font := caption_font()
	var size_px := caption_font_size()
	var text := caption_text_rect()
	if font == null or text.size.x <= 0.0:
		return
	var plaque := caption_rect()
	# Torn-cornered felt plaque, cut like the sewn paper patch beside it.
	draw_colored_polygon(PackedVector2Array([
		plaque.position + Vector2(2.0, 0.0),
		Vector2(plaque.end.x - 1.0, plaque.position.y),
		Vector2(plaque.end.x, plaque.position.y + 3.0),
		Vector2(plaque.end.x - 2.0, plaque.end.y),
		Vector2(plaque.position.x + 3.0, plaque.end.y - 1.0),
		plaque.position + Vector2(0.0, 4.0)]), CAPTION_FILL)
	# Hand stitches along the top and bottom seams, matching the patchwork paper.
	var stitch := Color(CAPTION_STITCH, 0.8)
	for x in range(int(plaque.position.x) + 7, int(plaque.end.x) - 5, 12):
		draw_line(Vector2(x, plaque.position.y + 2.0), Vector2(x + 3.0, plaque.position.y + 5.0),
			stitch, 1.2, true)
		draw_line(Vector2(x, plaque.end.y - 5.0), Vector2(x + 3.0, plaque.end.y - 2.0),
			stitch, 1.2, true)
	draw_string(font, Vector2(text.position.x, text.end.y - font.get_descent(size_px)),
		readable_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, caption_ink())
	# Miniature rust-felt ticket to the right of the caption: the policy stays its own
	# readable label instead of being painted across the announced action.
	var tag := policy_rect()
	if tag.size.x <= 0.0 or tag.size.y <= 0.0:
		return
	draw_rect(tag, POLICY_FILL)
	draw_line(Vector2(tag.position.x + 2.0, tag.position.y + 1.0),
		Vector2(tag.end.x - 2.0, tag.position.y + 1.0), CREAM, 1.0)
	var policy := policy_font()
	if policy == null:
		return
	var policy_text := policy_text_rect()
	draw_string(policy, Vector2(policy_text.position.x,
		policy_text.end.y - policy.get_descent(POLICY_FONT)), policy_cue,
		HORIZONTAL_ALIGNMENT_LEFT, -1, POLICY_FONT, POLICY_INK)


## Drawn sewn-glyph fallback in the patch's own scaled art coordinates. Used for every
## mode without a loaded committed icon, so the badge stays readable without any PNG.
func _draw_glyph() -> void:
	if icon_mode == "steal_gold":
		draw_string(get_theme_default_font(), Vector2(20, 31), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, RUST)
	elif icon_mode == "attack":
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
	elif icon_mode in ["debuff", "snip_block"]:
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
