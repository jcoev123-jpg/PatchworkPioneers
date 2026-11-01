extends Node
## Observes the app's authoritative roster; owns only presentation, never combat actions.

## Owner-supplied stand-in art, keyed by authoritative actor ID (never name, slot or screen text).
## Each base path has a matching "_attack" pose that only this actor's own committed
## attack play may show, for the short bounded lunge below.
const ART_ROOT := "res://assets/paper/"
## One authored paper scene per battle kind, chosen by the admitted route node type. The
## matching drawn quilt stays the fallback whenever an image is absent or the kind unknown.
const BATTLE_BACKDROP_ROOT := ART_ROOT + "backgrounds/"
const BATTLE_BACKDROPS := {
	"Fight": "battle_meadow.png",
	"Elite": "battle_ruins.png",
	"Boss": "battle_boss.png",
}
## The routed Fight stage advances through four authored areas: the admitted node's own
## integer floor picks the landscape, so floors 1-3 keep the meadow, 4-6 the woods, 7-9
## the marsh and 10-11 the peaks. The Boss floor owns the Boss scene instead.
const FIGHT_AREA_FLOORS := [
	{"name": "Meadow", "last_floor": 3, "file": "battle_meadow.png"},
	{"name": "Woods", "last_floor": 6, "file": "battle_woods.png"},
	{"name": "Marsh", "last_floor": 9, "file": "battle_marsh.png"},
	{"name": "Peaks", "last_floor": 11, "file": "battle_peaks.png"},
]
## A standalone _start_battle has no run map, so it has no floor and stays the meadow.
const STANDALONE_BATTLE_KIND := "Fight"
const STANDALONE_FLOOR := 0
## A routed battle whose node floor is missing or malformed selects no scene at all.
const INVALID_FLOOR := -1
## Owner-supplied art for the three noncombat stops. A missing file keeps the same dark
## slate behind the same controls, so no PNG is required.
const VISIT_BACKDROPS := {
	"Rest": "rest_camp.png",
	"Shop": "shop_stall.png",
	"Event": "event_crossroads.png",
}
const ACTOR_ART := {
	"warden": "heroes/warden",
	"seamstress": "heroes/seamstress",
	"tinker": "heroes/tinker",
	"lantern_monk": "heroes/lantern_monk",
	"rag_duelist": "heroes/rag_duelist",
	"scarecrow": "heroes/scarecrow",
	"yarn_ranger": "heroes/yarn_ranger",
	"button_golem": "heroes/button_golem",
	"ragling": "enemies/ragling",
	"ragling_guard": "enemies/ragling_guard",
	"fray_scavenger": "enemies/fray_scavenger",
	"moth_swarm_broodling": "enemies/moth_swarm_broodling",
	"button_guard": "enemies/button_guard",
	"spool_stalker": "enemies/spool_stalker",
	"seam_ripper": "enemies/seam_ripper",
	"needle_marshal": "enemies/needle_marshal",
	"spool_hexer": "enemies/spool_hexer",
	"patchwork_behemoth": "boss/patchwork_behemoth",
	"scissor_bailiff": "enemies/scissor_bailiff",
	"zipper_hauler": "enemies/zipper_hauler",
	"scissor_crab": "enemies/scissor_crab",
	"thimble_beetle": "enemies/thimble_beetle",
	"zipper_snake": "enemies/zipper_snake",
	"pincushion_hedgehog": "enemies/pincushion_hedgehog",
	"moth_swarm": "enemies/moth_swarm",
	"needle_wasp": "enemies/needle_wasp",
	"shearwing_mantis": "enemies/shearwing_mantis",
	"spoolback_hound": "enemies/spoolback_hound",
	"inkbrush_imp": "enemies/inkbrush_imp",
	"spindle_ram": "enemies/spindle_ram",
	"razor_ribbon_wraith": "enemies/razor_ribbon_wraith",
	"clothespin_crusher": "enemies/clothespin_crusher",
	"crochet_hook_harrier": "enemies/crochet_hook_harrier",
	"thistle_patch_doll": "enemies/thistle_patch_doll",
	"bobbin_bat": "enemies/bobbin_bat",
	"quilt_termite": "enemies/quilt_termite",
	"felt_bulwark": "enemies/felt_bulwark",
	"moth_scribe": "enemies/moth_scribe",
	"pin_skitter": "enemies/pin_skitter",
	"thread_biter": "enemies/thread_biter",
	"sewing_machine_colossus": "enemies/sewing_machine_colossus",
	"needle_briar_guard": "enemies/needle_marshal",
	"spool_snarekeeper": "enemies/spool_hexer",
	"spool_leech": "enemies/spool_hexer",
	"pincushion_matriarch": "enemies/pincushion_hedgehog",
}

## One large stage for both sides: heroes and enemies share this minimum actor height,
## so neither lineup is drawn smaller than the other.
const STAGE_ACTOR_HEIGHT := 180
## The shared art reservation above both lineups: enemies pin their intent ticket in this
## band and heroes keep the same empty room, so the two sides still draw their art at one
## scale with one foot line. The band is only the room a ticket needs; its seat is measured
## from the source's own resting artwork, never from this band's upper edge.
const STAGE_INTENT_BAND := 36.0
## Viewport-safe gap between the viewport's upper edge and every intent ticket, so a whole
## stitched patch reads as pinned inside 1280x720 instead of hanging off the top edge.
const STAGE_INTENT_SAFE_MARGIN := 8.0
## Breathing room between a seated ticket's bottom edge and its actor's resting artwork, so
## the paper patch never sits on the art while the drawing bobs and breathes.
const INTENT_ART_CLEARANCE := 4.0
const STAGE_HEM := Color("2a3431")
const STAGE_THREAD := Color("c9b996")
## One continuous quilt: regular, axis-aligned patches whose edges are shared, so the
## whole stage reads as a single sewn cloth instead of separate tilted felt pieces.
const STAGE_QUILT_COLUMNS := [0.0, 0.17, 0.34, 0.5, 0.66, 0.83, 1.0]
const STAGE_QUILT_ROWS := [0.0, 0.5, 1.0]
const STAGE_QUILT_TONES := [Color("414c48"), Color("4d5a54"), Color("39443f"), Color("4b443f")]
const STAGE_HEM_HEIGHT := 14.0
## Bottom band that pins each actor's short name below (never across) the stand-in art.
const STAGE_TAG_HEIGHT := 26.0
## The already-shipped display face every pinned actor name wears: the master Theme's
## Londrina Solid Regular variation, installed by PatchworkUIShell from the shipped font.
const NAME_TAG_VARIATION := "PatchHeading"
## One readable body size for both mounted name tags, at the VIS 18 px floor, so the
## sewn hero and enemy names read at a glance instead of as small print.
const NAME_TAG_FONT_SIZE := 18
## The stage is laid in: both the authored scene and the drawn quilt fallback are dimmed
## by about one fifth and framed with soft dark edges, so the sewn actors and their pinned
## labels read as the lit subject. The same wash and frame never touch a sibling control.
const STAGE_DIM_ALPHA := 0.2
const STAGE_DIM_INK := Color("12100e")
const STAGE_VIGNETTE_INK := Color("0a0f0e")
const STAGE_VIGNETTE_ALPHA := 0.4
const STAGE_VIGNETTE_STEPS := 8
## How far the soft dark frame reaches in from each edge, as a fraction of the short side.
const STAGE_VIGNETTE_DEPTH := 0.22

var enemies: CombatEnemies
var panel: PanelContainer
var backdrop: Control
var _battle: Control
var _labels: Array[Label] = []
var _hero_tags: Array[Label] = []
## One Warden-owned, read-only sewn cue per hero seat; hidden on every other actor.
var _hero_reaction_tags: Array[PanelContainer] = []
var _badges: Array[LiveEnemyIntentBadge] = []
## One passive contact-hazard label per mounted enemy, separate from its intent.
var _thorns_tags: Array[PanelContainer] = []
## One read-only, enemy-slot-bound status plaque per mounted puppet.
var _status_tags: Array[PanelContainer] = []
## Identity admitted at mounting, not a mutable actor ID borrowed from a later fight.
var _admitted_ids: Array[String] = []
const STATUS_NAMES := ["bleed", "weak", "exposed", "tangled", "riposte"]
var battle_row: HBoxContainer
var _heroes: HBoxContainer
var _hero_parent: Node
var _hero_index := 0
var _hero_flags := 0
var _hero_fonts: Dictionary = {}
var _puppets: Array[Control] = []
var _intent_visible := true
var _art_cache: Dictionary = {}
var _backdrop_kind := ""
var _backdrop_floor := STANDALONE_FLOOR
var _backdrop_key := ""
var _backdrop_cache: Dictionary = {}


## Exact stand-in image paths for one authoritative actor ID; empty when no art is mapped.
static func art_paths(actor_id: String) -> Dictionary:
	if not ACTOR_ART.has(actor_id):
		return {}
	var base: String = ART_ROOT + String(ACTOR_ART[actor_id])
	return {"idle": base + ".png", "attack": base + "_attack.png", "idle_loop": base + "_idle.png",
		"attack_loop": base + "_attack_anim.png", "hit_loop": base + "_hit_anim.png",
		"death_loop": base + "_death_anim.png"}


## The exact sewn fallback kind of one authoritative actor ID: the four M05 normals
## retain their own silhouette when art is unavailable; other IDs use the generic puppet. The
## one authority lives in the mounted Puppet, chosen by ID and never by stage slot.
static func fallback_kind_for(actor_id: String) -> String:
	return Puppet.fallback_kind_for(actor_id)


## The authored battle scene of one route node kind; empty for every other kind.
static func backdrop_path(kind: String) -> String:
	if not BATTLE_BACKDROPS.has(kind):
		return ""
	return BATTLE_BACKDROP_ROOT + String(BATTLE_BACKDROPS[kind])


## The authored Fight area record of one admitted floor; empty outside floors 1-11.
static func fight_area(floor_number: int) -> Dictionary:
	if floor_number < 1:
		return {}
	for area in FIGHT_AREA_FLOORS:
		if floor_number <= int(area["last_floor"]):
			return area
	return {}


static func fight_area_name(floor_number: int) -> String:
	return String(fight_area(floor_number).get("name", ""))


## The authored Fight scene of one admitted floor; empty for a floor outside 1-11, which
## keeps the drawn quilt instead of borrowing another area's landscape.
static func fight_backdrop_path(floor_number: int) -> String:
	var file := String(fight_area(floor_number).get("file", ""))
	return "" if file.is_empty() else BATTLE_BACKDROP_ROOT + file


## The exact scene of one admitted battle: a Fight follows its node's area floor, a
## standalone Fight (floor 0) stays the meadow, and Elite/Boss keep their own scene.
## Stage light per authored backdrop, measured from each painting's own palette and its
## brightest source: [art grade, rim light colour, direction toward the light (screen
## space), ground mist colour]. A stage outside this table keeps the actors unlit.
const STAGE_LIGHTS := {
	"battle_meadow.png": [Color("b4a6b0"), Color("ffc070"), Vector2(0.7, -0.7), Color("8a7c88")],
	"battle_woods.png": [Color("a8a698"), Color("ffd890"), Vector2(0.25, -0.97), Color("7c8872")],
	"battle_marsh.png": [Color("9eaaa6"), Color("ffb860"), Vector2(-0.8, -0.6), Color("7a9088")],
	"battle_peaks.png": [Color("a6a8bc"), Color("d6e0f4"), Vector2(-0.7, -0.7), Color("a0a8b8")],
	"battle_ruins.png": [Color("b49690"), Color("ffae58"), Vector2(0.0, -1.0), Color("8c7470")],
	"battle_boss.png": [Color("a88ca0"), Color("ff9c58"), Vector2(0.8, -0.6), Color("7a5c74")],
}


static func stage_light(kind: String, floor_number: int) -> Array:
	return STAGE_LIGHTS.get(stage_backdrop_path(kind, floor_number).get_file(), [])


static func stage_backdrop_path(kind: String, floor_number: int) -> String:
	if kind != STANDALONE_BATTLE_KIND:
		return backdrop_path(kind)
	if floor_number == STANDALONE_FLOOR:
		return backdrop_path(STANDALONE_BATTLE_KIND)
	return fight_backdrop_path(floor_number)


## Identity of one stage selection. The floor is part of the key, so a new Fight on
## another area refreshes the same stage instead of only comparing its kind.
static func stage_key(kind: String, floor_number: int) -> String:
	return "%s@%d" % [kind, floor_number]


## The authored visit scene of one noncombat stop; empty for every other kind.
static func visit_backdrop_path(kind: String) -> String:
	if not VISIT_BACKDROPS.has(kind):
		return ""
	return BATTLE_BACKDROP_ROOT + String(VISIT_BACKDROPS[kind])


## Cover destination of an image over `view`: as large as the view, aspect preserved.
static func cover_rect(view: Rect2, texture_size: Vector2) -> Rect2:
	return StageBackdrop.cover_rect(view, texture_size)


## The centred source window of `texture_size` that a cover draw shows inside `view`.
static func crop_rect(view: Rect2, texture_size: Vector2) -> Rect2:
	return StageBackdrop.crop_rect(view, texture_size)


class Puppet extends Control:
	const TAG_FELT := Color("2f2a25")
	const TAG_THREAD := Color("c9b996")
	## Idle presentation only: the drawn artwork breathes about one percent and bobs a
	## couple of pixels, each actor at its own stable phase. The pose lives in the draw
	## transform, so the Control, its pinned name tag and its intent badge never move and
	## every target rectangle stays exactly where combat put it.
	const IDLE_BOB_PIXELS := 1.25
	const IDLE_BREATHE := 0.01
	const IDLE_BOB_RATE := 1.7
	const IDLE_BREATHE_RATE := 1.15
	const IDLE_SLOT_OFFSET := 0.9
	const IDLE_SIDE_OFFSET := 0.55
	## Playback rate of an authored idle loop strip.
	const IDLE_LOOP_FPS := 12.0
	## Web battle textures must fit a conservative 8192-pixel atlas budget; an
	## oversized valid PNG can otherwise sample as a black rectangle on WebGL.
	const LOOP_ATLAS_MAX_WIDTH := 8192
	## Tall artwork stops short of the band top, leaving the column room for its intent
	## ticket and a status plaque above it instead of hiding the plaque.
	const ART_HEIGHT_SHARE := 0.62
	## The drawn fallback's own local extents before the pose transform: body, head, legs
	## and the slot-specific sewn prop, including stroke width.
	const FALLBACK_EXTENTS := Rect2(-26.0, -43.0, 73.0, 85.5)
	## The four authored M05 normals retain their own sewn fallback if their
	## imported images are unavailable; every other ID, including a fabricated
	## one, keeps the generic drawn puppet. The kind follows the bound actor ID only, never
	## the stage slot, so a rebind really changes the puppet an actor draws.
	const FALLBACK_KIND_GENERIC := "generic"
	const FALLBACK_ACTOR_IDS := [
		"felt_bulwark", "moth_scribe", "pin_skitter", "thread_biter",
		"lantern_monk", "rag_duelist", "scarecrow", "yarn_ranger", "button_golem",
	]
	## Muted sewn felt tones of the identity-specific puppets. `cloth` always keeps this
	## actor's own slot felt, so the four still share the stage's handmade palette.
	const NAMED_TONES := {
		"ink": Color("302b29"),
		"face": Color("c9b996"),
		"cream": Color("e6dcc0"),
		"slate": Color("5a626b"),
		"steel": Color("9aa1a5"),
		"rust": Color("8c6550"),
		"olive": Color("555d48"),
		"plum": Color("6c5a72"),
		"saffron": Color("e0a53a"),
		"monk_plum": Color("6b3f6e"),
		"monk_cream": Color("f1e6c8"),
		"crimson": Color("b5323a"),
		"duelist_black": Color("2a2326"),
		"gold": Color("d7b14a"),
		"burlap": Color("b88f5a"),
		"pumpkin": Color("d9752b"),
		"denim": Color("3f5f8a"),
		"moss": Color("5d7a3a"),
		"teal": Color("2f7a7a"),
		"wool": Color("efe9dc"),
		"walnut": Color("7a5236"),
		"brass": Color("c49a3a"),
		"golem_slate": Color("55606e"),
	}
	## One soft oval contact patch on the shared foot line, drawn from the rest pose. It is
	## a few concentric translucent ovals, so the shadow fades at its rim instead of reading
	## as a solid box, and it never bobs with the artwork.
	const SHADOW_INK := Color("0c1110")
	const SHADOW_ALPHA := 0.55
	const SHADOW_RINGS := 3
	const SHADOW_HEIGHT := 12.0
	const SHADOW_WIDTH_RATIO := 0.82
	## A dark low-radius copy of the bound artwork drawn just behind it, so every paper
	## actor separates from the dimmed stage. Drawn shapes only: no control, no input.
	const RIM_INK := Color("111716")
	const RIM_ALPHA := 0.75
	const RIM_RADIUS := 2.5
	const RIM_SCALE := 1.05
	## One committed attack pose per actor: a short lunge in the actor's own facing
	## direction with a little paper stretch, driven by the same per-frame delta as the
	## idle bob so it never creates a tween, a timer or a gameplay wait. The span is
	## bounded here as well as by the listener, so no caller can leave a pose running.
	const ATTACK_MAX_SECONDS := 0.6
	const ATTACK_LUNGE_RATIO := 0.16
	const ATTACK_LUNGE_MAX := 26.0
	const ATTACK_STRETCH := 0.1
	const ATTACK_SQUASH := 0.06
	## One committed HP loss also shakes that actor: a short damped horizontal wobble
	## applied to the same drawing transform as the idle bob and the attack lunge, so the
	## Control, its pinned name tag and every target rectangle keep their exact place. The
	## span is bounded here as well as by the listener, it settles exactly at zero, and it
	## never creates a tween, a timer or a gameplay wait.
	const RECOIL_MAX_SECONDS := 0.6
	const RECOIL_AMPLITUDE_RATIO := 0.08
	const RECOIL_AMPLITUDE_MAX := 10.0
	## A shake is always readable, even when the drawn actor already fills its band. It is
	## still small enough that two neighbouring columns' artwork never touch.
	const RECOIL_MIN_PIXELS := 6.0
	## One full wobble: pushed back first, one damped overshoot, then exactly at rest.
	const RECOIL_WAVES := 2.0
	## One witnessed living-to-zero HP transition eases only this actor's drawn artwork from
	## upright into the existing still fallen tilt. `fallen` itself is authoritative at once,
	## and the easing lives in the same draw transform, so the Control, its pinned tag and
	## every target rectangle never move. The span is bounded here as well as by the listener.
	const FALL_MAX_SECONDS := 0.6
	const FALL_TILT := 0.7

	## Stage lighting: a shared canvas shader grades only the full-opacity artwork, darkens
	## its feet toward the ground and turns the RIM_LIGHT_MARK copy into a flat rim of
	## light; every untextured draw (shadow, tag, fallback) passes through unchanged.
	const RIM_LIGHT_MARK := 0.65
	const RIM_LIGHT_STRENGTH := 0.6
	## Dark gothic grade: how much colour drains toward grey and how deep the feet sink in shadow.
	const GRIM_DESATURATION := 0.35
	const GROUND_SHADE := 0.6
	const MIST_PATH := "res://assets/paper/vfx/ground_mist.png"
	const MIST_ALPHA := 0.3
	const STAGE_LIGHT_SHADER := """shader_type canvas_item;
uniform vec3 light_tint = vec3(1.0);
uniform float ground_shade = 0.0;
uniform float rim_strength = 0.0;
uniform float grim = 0.0;
varying vec4 draw_color;
void vertex() { draw_color = COLOR; }
void fragment() {
	if (TEXTURE_PIXEL_SIZE.x < 0.5) {
		vec4 tex = texture(TEXTURE, UV);
		if (draw_color.a > 0.99) {
			float feet = smoothstep(0.55, 1.0, UV.y) * ground_shade;
			vec3 lit_rgb = tex.rgb * draw_color.rgb;
			lit_rgb = mix(lit_rgb, vec3(dot(lit_rgb, vec3(0.3, 0.59, 0.11))), grim);
			COLOR = vec4(lit_rgb * light_tint * (1.0 - feet), tex.a);
		} else if (abs(draw_color.a - 0.65) < 0.02) {
			COLOR = vec4(draw_color.rgb, tex.a * rim_strength);
		}
	}
}
"""
	static var _light_shader: Shader
	static var _mist_texture: Texture2D
	var lit := false
	var rim_color := Color.WHITE
	var rim_dir := Vector2.ZERO
	var mist_color := Color.WHITE

	var facing := 1.0
	var slot := 1
	var fallen := false
	var felt := Color("719796")
	var actor_id := ""
	## Identity-specific sewn fallback of the bound actor ID; generic for every other actor,
	## so a fabricated or image-backed ID never borrows another creature's silhouette.
	var fallback_kind := FALLBACK_KIND_GENERIC
	## Seconds of idle presentation this instance has run. A fresh puppet starts at rest.
	var idle_phase := 0.0
	var idle_texture: Texture2D
	## Optional authored idle loop: square cells cut from one `<id>_idle.png` strip, each
	## with the figure standing on the cell's bottom edge at the still's own height.
	var idle_frames: Array[Texture2D] = []
	## Authored attack pose, drawn only while this actor performs its own committed hit.
	var attack_texture: Texture2D
	## Optional authored swing: square cells cut from one `<id>_attack_anim.png` strip running
	## from the idle stance to the attack pose, at the attack still's own pixel scale.
	var attack_frames: Array[Texture2D] = []
	## Optional authored reactions (elites and bosses): a flinch played across the recoil and
	## a collapse played across the fall settle, both at the idle still's pixel scale.
	var hit_frames: Array[Texture2D] = []
	var death_frames: Array[Texture2D] = []
	## Seconds left of the one bounded committed attack pose; zero means plain idle.
	var attack_remaining := 0.0
	var attack_span := 0.0
	## Seconds left of the one bounded committed-hit recoil; zero means no shake at all.
	var recoil_remaining := 0.0
	var recoil_span := 0.0
	## Seconds left of the one bounded fall settle; zero means the fallen tilt is already
	## fully settled (and a standing actor is upright).
	var fall_remaining := 0.0
	var fall_span := 0.0
	## The `fallen` value this puppet last presented, so a transition is witnessed once.
	var _fall_seen := false
	## Presenter-supplied stage metrics, so heroes and enemies are drawn at one scale.
	var stage_height := 180.0
	var intent_band := 36.0
	var tag_height := 26.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		# Both sides share one large stage height; the row may grow into free space.
		custom_minimum_size = Vector2(0, stage_height)
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		resized.connect(queue_redraw)

	func _process(delta: float) -> void:
		# A witnessed fall settles first, then the committed attack pose and the hit recoil,
		# so a fallen or finished actor is already back at its plain pose before the idle bob
		# advances.
		advance_fall(delta)
		advance_attack(delta)
		advance_recoil(delta)
		advance_idle(delta)

	## Idle motion advances with real frame time only while the actor stands; a fallen
	## actor keeps the existing still tilt, and nothing is scheduled outside the frame.
	func advance_idle(delta: float) -> void:
		if fallen or delta <= 0.0:
			return
		idle_phase += delta
		queue_redraw()

	## Starts the one short committed attack pose of this actor. A fallen, detached or
	## otherwise absent actor, or a non-positive span, stays at plain idle: presentation
	## never fabricates a lunge that combat did not commit.
	func trigger_attack(seconds: float) -> bool:
		if fallen or not is_inside_tree() or seconds <= 0.0:
			return false
		attack_span = clampf(seconds, 0.001, ATTACK_MAX_SECONDS)
		attack_remaining = attack_span
		queue_redraw()
		return true

	## Ends the committed attack pose immediately, leaving the drawn artwork at rest.
	func cancel_attack() -> void:
		if attack_remaining <= 0.0 and attack_span <= 0.0:
			return
		attack_remaining = 0.0
		attack_span = 0.0
		queue_redraw()

	## The pose settles itself with real frame deltas; a fallen actor never keeps or
	## finishes a lunge, and a completed span leaves no residual offset.
	func advance_attack(delta: float) -> void:
		if attack_remaining <= 0.0:
			return
		if fallen:
			cancel_attack()
			return
		if delta <= 0.0:
			return
		attack_remaining = maxf(0.0, attack_remaining - delta)
		if attack_remaining <= 0.0:
			attack_span = 0.0
		queue_redraw()

	## True only while this actor is really mid-lunge.
	func attacking() -> bool:
		return attack_remaining > 0.0 and not fallen

	## Zero at rest, peaking at one half-way through the pose and back to zero at its end,
	## so the lunge both starts and ends exactly at the idle pose.
	func attack_shape() -> float:
		if not attacking() or attack_span <= 0.0:
			return 0.0
		var progress := clampf(1.0 - attack_remaining / attack_span, 0.0, 1.0)
		return sin(progress * PI)

	## How far this actor lunges forward: a share of its own drawn width, capped so the
	## pose reads as one step toward the other lineup instead of a teleport.
	func attack_forward_pixels() -> float:
		return clampf(actor_art_width() * ATTACK_LUNGE_RATIO, 4.0, ATTACK_LUNGE_MAX)

	## The lunge applied to the drawn transform, in this actor's facing direction.
	func attack_lunge() -> float:
		return facing * attack_forward_pixels() * attack_shape()

	## Paper stretch along the lunge, and the matching squash across it.
	func attack_stretch() -> float:
		return 1.0 + ATTACK_STRETCH * attack_shape()

	func attack_squash() -> float:
		return 1.0 - ATTACK_SQUASH * attack_shape()

	## Starts the one short recoil of an actor that really lost HP. A fallen, detached or
	## otherwise absent actor, or a non-positive span, stays exactly at rest: presentation
	## never fabricates a shake that combat did not commit.
	func trigger_recoil(seconds: float) -> bool:
		if fallen or not is_inside_tree() or seconds <= 0.0:
			return false
		recoil_span = clampf(seconds, 0.001, RECOIL_MAX_SECONDS)
		recoil_remaining = recoil_span
		queue_redraw()
		return true

	## Ends a recoil immediately, leaving the drawn artwork exactly at its idle pose.
	func cancel_recoil() -> void:
		if recoil_remaining <= 0.0 and recoil_span <= 0.0:
			return
		recoil_remaining = 0.0
		recoil_span = 0.0
		queue_redraw()

	## The recoil settles itself with real frame deltas; a fallen actor never keeps one.
	func advance_recoil(delta: float) -> void:
		if recoil_remaining <= 0.0:
			return
		if fallen:
			cancel_recoil()
			return
		if delta <= 0.0:
			return
		recoil_remaining = maxf(0.0, recoil_remaining - delta)
		if recoil_remaining <= 0.0:
			recoil_span = 0.0
		queue_redraw()

	## True only while this actor is really mid-recoil.
	func recoiling() -> bool:
		return recoil_remaining > 0.0 and not fallen

	## Zero at rest, one full damped wobble in between and zero again at the end, so a
	## recoil both starts and finishes exactly at the idle pose.
	func recoil_shape() -> float:
		if not recoiling() or recoil_span <= 0.0:
			return 0.0
		var progress := clampf(1.0 - recoil_remaining / recoil_span, 0.0, 1.0)
		return sin(progress * PI * RECOIL_WAVES) * (1.0 - progress)

	## Starts the one bounded settling of a witnessed fall. `fallen` is already
	## authoritative; only the drawn tilt eases, and a non-positive span or a detached
	## puppet reports false so no caller can leave an animation running.
	func settle_fall(seconds: float) -> bool:
		if not is_inside_tree() or seconds <= 0.0:
			return false
		fall_span = clampf(seconds, 0.001, FALL_MAX_SECONDS)
		fall_remaining = fall_span
		_fall_seen = true
		queue_redraw()
		return true

	## Ends a fall settle immediately, leaving the drawn artwork exactly at the existing
	## still fallen pose (or upright while standing).
	func cancel_fall() -> void:
		if fall_remaining <= 0.0 and fall_span <= 0.0:
			return
		fall_remaining = 0.0
		fall_span = 0.0
		queue_redraw()

	## The settle advances with real frame deltas only. A puppet that becomes fallen without
	## a witnessed settle still eases once, so no actor ever snaps into the fallen pose, and
	## a standing actor drops the settle immediately.
	func advance_fall(delta: float) -> void:
		if not fallen:
			if _fall_seen:
				_fall_seen = false
				cancel_fall()
			return
		if not _fall_seen:
			_fall_seen = true
			if fall_span <= 0.0:
				fall_span = FALL_MAX_SECONDS
				fall_remaining = fall_span
			queue_redraw()
		if fall_remaining <= 0.0 or delta <= 0.0:
			return
		fall_remaining = maxf(0.0, fall_remaining - delta)
		if fall_remaining <= 0.0:
			fall_span = 0.0
		queue_redraw()

	## True only while the drawn artwork is really easing into the fallen pose.
	func settling_fall() -> bool:
		return fall_remaining > 0.0 and fallen

	## Eased progress of a witnessed fall: zero upright, one fully settled. An actor that
	## never settled (or already finished) reports the existing still fallen pose.
	func fall_shape() -> float:
		if fall_span <= 0.0 or fall_remaining <= 0.0:
			return 1.0
		var progress := clampf(1.0 - fall_remaining / fall_span, 0.0, 1.0)
		return progress * progress * (3.0 - 2.0 * progress)

	## The fallen tilt this actor draws now, in its own facing direction. It is the existing
	## still fallen pose once settled and upright otherwise; a standing actor never tilts.
	func fallen_tilt() -> float:
		if not fallen or not death_frames.is_empty():
			return 0.0
		return -FALL_TILT * facing * fall_shape()

	## The rest placement of whichever artwork is drawn now, before the pose transform.
	func rest_drawn_rect() -> Rect2:
		var rect := image_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			return rect
		var band := art_band()
		if band.size.x <= 0.0 or band.size.y <= 0.0:
			return Rect2()
		var scale := fallback_scale()
		return Rect2(fallback_anchor() + FALLBACK_EXTENTS.position * scale,
			FALLBACK_EXTENTS.size * scale)

	## Horizontal room the drawn artwork leaves inside its own art band, so a shake can be
	## kept to its actor's column instead of crossing into a neighbour.
	func recoil_slack() -> float:
		var band := art_band()
		var rest := rest_drawn_rect()
		if band.size.x <= 0.0 or rest.size.x <= 0.0:
			return 0.0
		return maxf(0.0, minf(rest.position.x - band.position.x, band.end.x - rest.end.x))

	## How far this actor is shoved: a share of its own drawn width, capped by the room its
	## artwork has inside the band, and never below a few readable pixels.
	func recoil_back_pixels() -> float:
		var rest := rest_drawn_rect()
		if rest.size.x <= 0.0:
			return 0.0
		var wanted := clampf(rest.size.x * RECOIL_AMPLITUDE_RATIO,
			RECOIL_MIN_PIXELS, RECOIL_AMPLITUDE_MAX)
		return maxf(RECOIL_MIN_PIXELS, minf(wanted, recoil_slack()))

	## The recoil applied to the drawn transform: away from this actor's facing first, then
	## one damped overshoot back toward it.
	func recoil_pixels() -> float:
		return -facing * recoil_back_pixels() * recoil_shape()

	## A stable per-puppet phase from this actor's side and slot; never wall-clock or RNG.
	func idle_offset() -> float:
		return float(slot) * IDLE_SLOT_OFFSET + (0.0 if facing > 0.0 else IDLE_SIDE_OFFSET)

	## The exact sewn fallback kind of one authoritative actor ID. It is a pure function of
	## the ID, so the same actor draws the same puppet in any stage slot.
	static func fallback_kind_for(actor_id: String) -> String:
		return actor_id if actor_id in FALLBACK_ACTOR_IDS else FALLBACK_KIND_GENERIC

	## Vertical bob in pixels for the current phase; a fallen actor does not bob.
	func idle_bob() -> float:
		if fallen:
			return 0.0
		return sin(idle_phase * IDLE_BOB_RATE + idle_offset()) * IDLE_BOB_PIXELS

	## Breathing factor applied only to drawn height: about one percent either way.
	func idle_breath() -> float:
		if fallen:
			return 1.0
		return 1.0 + sin(idle_phase * IDLE_BREATHE_RATE + idle_offset()) * IDLE_BREATHE

	## Space reserved at the edge of the art band for the bob and the breathing swell, so
	## animated artwork never crosses its band.
	func art_safety_inset() -> float:
		return IDLE_BOB_PIXELS + art_band().size.y * IDLE_BREATHE / 2.0 + 1.0

	## The safety inset actually applied to placement: the bob/breathing reserve, capped so
	## a small actor box still keeps a usable band.
	func art_inset() -> float:
		var band := art_band()
		return minf(art_safety_inset(), minf(band.size.x, band.size.y) / 4.0)

	## The one stage-foot line both draw paths share, above the pinned name tag and below
	## the intent band. Textures and the drawn fallback put their bottom edge here, so the
	## lineups read as standing on the quilt instead of floating in the art band.
	func foot_line() -> float:
		return art_band().end.y - art_inset()

	## One pose shared by both draw paths: inward facing, the fallen tilt (eased into by a
	## witnessed fall), the breathing height, the bob and, during a committed attack or a
	## committed hit, the forward lunge with its paper stretch and the horizontal recoil.
	## Applied about `anchor` at `base_scale`, so the Control, its pinned name tag and every
	## target rectangle keep their exact place.
	func idle_transform(anchor: Vector2, base_scale: float) -> Transform2D:
		return Transform2D(fallen_tilt(),
			Vector2(facing * attack_stretch(), idle_breath() * attack_squash()) * base_scale, 0.0,
			anchor + Vector2(attack_lunge() + recoil_pixels(), idle_bob()))

	## Binds one authoritative actor ID and its loaded art; a missing texture keeps the fallback.
	## A rebound slot drops any pose, recoil or fall settle in flight, so one actor never
	## finishes another's lunge, shake or fall.
	func bind_actor(id: String, art: Dictionary) -> void:
		if id != actor_id:
			cancel_attack()
			cancel_recoil()
			cancel_fall()
		_fall_seen = fallen
		actor_id = id
		fallback_kind = fallback_kind_for(id)
		idle_texture = art.get("idle") as Texture2D
		attack_texture = art.get("attack") as Texture2D
		idle_frames = loop_frames(art.get("idle_loop") as Texture2D, idle_texture)
		attack_frames = loop_frames(art.get("attack_loop") as Texture2D, attack_texture)
		hit_frames = loop_frames(art.get("hit_loop") as Texture2D, idle_texture)
		death_frames = loop_frames(art.get("death_loop") as Texture2D, idle_texture)
		queue_redraw()

	func current_texture() -> Texture2D:
		return idle_texture

	## A transparent still must never be replaced by an opaque-canvas strip. Check
	## only eight margin pixels per cell, once at bind time (not during _draw).
	## Four clear samples accommodate legitimate edge overlap by paper artwork.
	static func _clear_cell_margin(image: Image, x_origin: int, width: int, height: int) -> bool:
		var clear := 0
		for point in [Vector2(0.05, 0.05), Vector2(0.5, 0.05), Vector2(0.95, 0.05),
				Vector2(0.05, 0.5), Vector2(0.95, 0.5),
				Vector2(0.05, 0.95), Vector2(0.5, 0.95), Vector2(0.95, 0.95)]:
			if image.get_pixel(x_origin + mini(int(point.x * width), width - 1),
					mini(int(point.y * height), height - 1)).a < 0.5:
				clear += 1
		return clear >= 4

	## Cuts an optional horizontal square-cell strip. Malformed, oversized or
	## opaque-backed strips fail closed to the still; attack stills remain usable.
	static func loop_frames(strip: Texture2D, still: Texture2D) -> Array[Texture2D]:
		var frames: Array[Texture2D] = []
		if strip == null or still == null or strip.get_height() <= 0 \
				or strip.get_width() <= 0 or strip.get_width() > LOOP_ATLAS_MAX_WIDTH \
				or strip.get_width() % strip.get_height() != 0:
			return frames
		var image := strip.get_image()
		var reference := still.get_image()
		if image == null or image.is_empty() or reference == null or reference.is_empty():
			return frames
		if _clear_cell_margin(reference, 0, reference.get_width(), reference.get_height()):
			for index in range(strip.get_width() / strip.get_height()):
				if not _clear_cell_margin(image, index * strip.get_height(),
						strip.get_height(), strip.get_height()):
					return frames
		var cell := float(strip.get_height())
		for index in range(strip.get_width() / strip.get_height()):
			var frame := AtlasTexture.new()
			frame.atlas = strip
			frame.region = Rect2(index * cell, 0.0, cell, cell)
			frames.append(frame)
		return frames

	## The artwork actually painted for the pose image `texture`: a standing actor's still
	## idle image is swapped for the current loop frame, and a committed attack pose for the
	## swing frame matching the lunge (stance, strike at its peak, back to stance); fallen
	## actors keep their own image. Placement and targets still come from the still image.
	func idle_frame(texture: Texture2D) -> Texture2D:
		if texture == attack_texture and attacking() and not attack_frames.is_empty():
			return attack_frames[roundi(attack_shape() * (attack_frames.size() - 1))]
		if texture == idle_texture and fallen and not death_frames.is_empty():
			return death_frames[roundi(fall_shape() * (death_frames.size() - 1))]
		if texture == idle_texture and recoiling() and not hit_frames.is_empty():
			var flinch := clampf(1.0 - recoil_remaining / recoil_span, 0.0, 1.0) if recoil_span > 0.0 else 0.0
			return hit_frames[roundi(flinch * (hit_frames.size() - 1))]
		if idle_frames.is_empty() or texture != idle_texture or fallen:
			return texture
		var index := int((idle_phase + idle_offset()) * IDLE_LOOP_FPS)
		return idle_frames[index % idle_frames.size()]

	## Where `painted` goes for the still's fitted `rect`: a loop frame keeps the still's
	## pixel scale, bottom-centred on the same foot line, so the figure keeps its size.
	func painted_rect(painted: Texture2D, texture: Texture2D, rect: Rect2) -> Rect2:
		if painted == texture or texture.get_height() <= 0:
			return rect
		var drawn := Vector2(painted.get_width(), painted.get_height()) * (rect.size.y / float(texture.get_height()))
		return Rect2(Vector2(rect.get_center().x - drawn.x / 2.0, rect.end.y - drawn.y), drawn)

	## The pinned name band at the bottom of the actor; art never reaches into it.
	func tag_band() -> Rect2:
		var height := clampf(tag_height, 0.0, size.y)
		return Rect2(0.0, size.y - height, size.x, height)

	## The art lives between the shared intent band and the pinned name band.
	func art_band() -> Rect2:
		var top := clampf(intent_band, 0.0, size.y)
		var bottom := maxf(top, size.y - clampf(tag_height, 0.0, size.y))
		return Rect2(0.0, top, size.x, bottom - top)

	## Uniform, aspect-preserving placement inside this input-inert Control. The pose's
	## bob and breathing room is reserved up front and the bottom edge rests on the shared
	## foot line, so animated art stays in its band and the lineups share one ground.
	func image_rect() -> Rect2:
		var texture := current_texture()
		var band := art_band()
		var inset := art_inset()
		var fit_band := band.grow(-inset)
		if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0 \
				or fit_band.size.x <= 0.0 or fit_band.size.y <= 0.0:
			return Rect2()
		var fit := minf(fit_band.size.x / float(texture.get_width()),
			fit_band.size.y * ART_HEIGHT_SHARE / float(texture.get_height()))
		var drawn := Vector2(texture.get_width(), texture.get_height()) * fit
		return Rect2(Vector2(fit_band.get_center().x - drawn.x / 2.0, fit_band.end.y - drawn.y), drawn)

	## The bounding rectangle the drawn pose covers after the current pose transform.
	func posed_image_rect() -> Rect2:
		var rect := pose_rect(pose_texture())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return Rect2()
		return _posed_rect(Rect2(-rect.size / 2.0, rect.size), rect.get_center(), 1.0)

	## Whichever pose artwork this actor draws at this instant: its own authored attack
	## pose during a committed hit, and otherwise the idle image it always drew. An actor
	## without an attack image (or without any supplied art at all) keeps its idle drawing
	## and still performs the same lunge.
	func pose_texture() -> Texture2D:
		if attacking() and attack_texture != null:
			return attack_texture
		return idle_texture

	## Placement of the drawn pose inside the same art band: fitted at its own
	## proportions with its bottom edge on the same foot line as the idle artwork, so the
	## pose can never stretch a shorter attack image or float an actor off the ground.
	func pose_rect(texture: Texture2D) -> Rect2:
		var base := image_rect()
		if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0 \
				or base.size.x <= 0.0 or base.size.y <= 0.0:
			return Rect2()
		var fit := minf(base.size.x / float(texture.get_width()),
			base.size.y / float(texture.get_height()))
		var drawn := Vector2(texture.get_width(), texture.get_height()) * fit
		return Rect2(Vector2(base.get_center().x - drawn.x / 2.0, base.end.y - drawn.y), drawn)

	## The bounding rectangle the drawn fallback covers after the current idle pose.
	func posed_fallback_rect() -> Rect2:
		if art_band().size.x <= 0.0 or art_band().size.y <= 0.0:
			return Rect2()
		return _posed_rect(FALLBACK_EXTENTS, fallback_anchor(), fallback_scale())

	## Whichever actor artwork this puppet draws now, after the current idle pose.
	func posed_actor_rect() -> Rect2:
		return posed_image_rect() if current_texture() != null else posed_fallback_rect()

	## Uniform fallback scale fitted inside the band minus the pose's safety inset, so the
	## drawn puppet cannot cross its band either.
	func fallback_scale() -> float:
		var band := art_band()
		var inset := art_safety_inset()
		var fit := Rect2(band.position + Vector2(inset, inset),
			Vector2(maxf(0.0, band.size.x - inset * 2.0), maxf(0.0, band.size.y - inset * 2.0)))
		var staged := clampf(band.size.y / 130.0, 0.45, 1.8)
		if fit.size.x <= 0.0 or fit.size.y <= 0.0:
			return staged
		return minf(staged, minf(fit.size.y / FALLBACK_EXTENTS.size.y, fit.size.x / FALLBACK_EXTENTS.size.x))

	## The painted fallback's own anchor: horizontally centred, with the local bottom of
	## FALLBACK_EXTENTS resting on the same foot line as every supplied texture.
	func fallback_anchor() -> Vector2:
		return Vector2(size.x / 2.0, foot_line() - FALLBACK_EXTENTS.end.y * fallback_scale())

	## Width of whichever artwork is bound now, used to size the contact shadow.
	func actor_art_width() -> float:
		var rect := image_rect()
		if rect.size.x > 0.0:
			return rect.size.x
		return FALLBACK_EXTENTS.size.x * fallback_scale()

	## The bottom edge of whichever artwork is bound now, before the idle bob is applied.
	func actor_rest_bottom() -> float:
		var rect := image_rect()
		if rect.size.y > 0.0:
			return rect.end.y
		return fallback_anchor().y + FALLBACK_EXTENTS.end.y * fallback_scale()

	## One soft elliptical contact patch under the actor on the foot line. It is computed
	## from the rest pose only, so it stays put while the art breathes and bobs, and it
	## never reaches into the pinned tag band.
	func contact_shadow_rect() -> Rect2:
		var band := art_band()
		if band.size.x <= 0.0 or band.size.y <= 0.0:
			return Rect2()
		var width := clampf(actor_art_width() * SHADOW_WIDTH_RATIO, 16.0, band.size.x - 8.0)
		if width <= 0.0:
			return Rect2()
		var bottom := minf(foot_line() + SHADOW_HEIGHT * 0.5, band.end.y - 0.5)
		var top := maxf(band.position.y, bottom - SHADOW_HEIGHT)
		return Rect2(size.x * 0.5 - width * 0.5, top, width, bottom - top)

	## Points of one axis-aligned oval, so the contact shadow is a soft ellipse, not a box.
	static func oval_points(center: Vector2, radius: Vector2, steps: int = 24) -> PackedVector2Array:
		var points := PackedVector2Array()
		for index in range(steps):
			var angle := TAU * float(index) / float(steps)
			points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
		return points

	func _posed_rect(local: Rect2, anchor: Vector2, base_scale: float) -> Rect2:
		var pose := idle_transform(anchor, base_scale)
		var points: Array[Vector2] = [pose * local.position,
			pose * Vector2(local.end.x, local.position.y), pose * local.end,
			pose * Vector2(local.position.x, local.end.y)]
		var bounds := Rect2(points[0], Vector2.ZERO)
		for index in range(1, points.size()):
			bounds = bounds.expand(points[index])
		return bounds

	## Applies one STAGE_LIGHTS entry, or clears the light for an empty one.
	func set_stage_light(light: Array) -> void:
		lit = light.size() == 4
		if not lit:
			material = null
			queue_redraw()
			return
		if _light_shader == null:
			_light_shader = Shader.new()
			_light_shader.code = STAGE_LIGHT_SHADER
		if _mist_texture == null and ResourceLoader.exists(MIST_PATH, "Texture2D"):
			_mist_texture = load(MIST_PATH) as Texture2D
		var shade := material as ShaderMaterial
		if shade == null:
			shade = ShaderMaterial.new()
			shade.shader = _light_shader
			material = shade
		var tint: Color = light[0]
		shade.set_shader_parameter("light_tint", Vector3(tint.r, tint.g, tint.b))
		shade.set_shader_parameter("ground_shade", GROUND_SHADE)
		shade.set_shader_parameter("grim", GRIM_DESATURATION)
		shade.set_shader_parameter("rim_strength", RIM_LIGHT_STRENGTH)
		rim_color = light[1]
		rim_dir = (light[2] as Vector2).normalized()
		mist_color = light[3]
		queue_redraw()

	func _draw() -> void:
		# Ground the actor first: a fixed contact patch on the foot line, then the dark rim,
		# then the artwork itself, then the pinned tag. Every layer is drawn here, so the
		# shadow and rim add no control and can never take pointer or keyboard input.
		_draw_contact_shadow()
		_draw_silhouette()
		if current_texture() != null:
			_draw_actor(pose_texture())
		else:
			_draw_fallback()
		_draw_tag()

	## A few concentric translucent ovals: soft at the rim and darkest where the feet meet
	## the quilt. Drawn from the rest-pose rectangle, so it never bobs with the artwork.
	func _draw_contact_shadow() -> void:
		var shadow := contact_shadow_rect()
		if shadow.size.x <= 0.0 or shadow.size.y <= 0.0:
			return
		var center := shadow.get_center()
		for ring in range(SHADOW_RINGS):
			var spread := 1.0 - float(ring) / float(SHADOW_RINGS)
			var radius := Vector2(shadow.size.x * 0.5 * spread, shadow.size.y * 0.5 * spread)
			draw_colored_polygon(oval_points(center, radius),
				Color(SHADOW_INK, SHADOW_ALPHA / float(SHADOW_RINGS)))

	## A dark low-radius copy of whichever artwork is drawn, drawn just before it. The copy
	## follows the same attack pose and is scaled about the foot line, so the rim grows up
	## and sideways but never floats the actor off the ground. Draw-only: no target, name or
	## intent changes.
	func _draw_silhouette() -> void:
		var texture := pose_texture() if current_texture() != null else null
		if texture != null:
			var rect := pose_rect(texture)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				return
			var painted := idle_frame(texture)
			var paint_rect := painted_rect(painted, texture, rect)
			var grown := paint_rect.size + Vector2(RIM_RADIUS, RIM_RADIUS) * 2.0
			draw_set_transform_matrix(idle_transform(paint_rect.get_center() - Vector2(0.0, RIM_RADIUS), 1.0))
			draw_texture_rect(painted, Rect2(-grown / 2.0, grown), false, Color(RIM_INK, RIM_ALPHA))
			draw_set_transform(Vector2.ZERO)
			return
		var band := art_band()
		if band.size.x <= 0.0 or band.size.y <= 0.0:
			return
		var scale := fallback_scale()
		var anchor := fallback_anchor()
		anchor.y -= FALLBACK_EXTENTS.end.y * scale * (RIM_SCALE - 1.0)
		draw_set_transform_matrix(idle_transform(anchor, scale * RIM_SCALE))
		_draw_fallback_shapes(true)
		draw_set_transform(Vector2.ZERO)

	## A small pinned felt tag below the art; its name text is drawn by a child Label.
	func _draw_tag() -> void:
		var band := tag_band()
		if band.size.x <= 24.0 or band.size.y <= 8.0:
			return
		var tag := Rect2(band.position + Vector2(10.0, 2.0),
			Vector2(band.size.x - 20.0, band.size.y - 4.0))
		draw_rect(tag, TAG_FELT)
		draw_dashed_line(tag.position, Vector2(tag.end.x, tag.position.y), TAG_THREAD, 1.0, 5.0)
		draw_dashed_line(Vector2(tag.position.x, tag.end.y), tag.end, TAG_THREAD, 1.0, 5.0)
		# Two sewn pins hold the tag to the quilt.
		draw_circle(Vector2(tag.position.x + 7.0, tag.get_center().y), 1.6, TAG_THREAD)
		draw_circle(Vector2(tag.end.x - 7.0, tag.get_center().y), 1.6, TAG_THREAD)

	## Draws the pose artwork (`pose_texture()`) inside the band: the authored attack pose
	## during a committed hit, otherwise the idle image, both resting on the foot line.
	func _draw_actor(texture: Texture2D) -> void:
		if texture == null:
			return
		var rect := pose_rect(texture)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return
		var painted := idle_frame(texture)
		var paint_rect := painted_rect(painted, texture, rect)
		# Heroes face right, enemies left; the fallen actor keeps the drawn tilt treatment.
		if lit and not fallen:
			# The stage light's rim: a flat copy nudged toward the light, peeking out on that side.
			var nudge := rim_dir * clampf(paint_rect.size.y * 0.008, 1.0, 2.5)
			draw_set_transform_matrix(idle_transform(paint_rect.get_center() + nudge, 1.0))
			draw_texture_rect(painted, Rect2(-paint_rect.size / 2.0, paint_rect.size), false,
				Color(rim_color, RIM_LIGHT_MARK))
		draw_set_transform_matrix(idle_transform(paint_rect.get_center(), 1.0))
		draw_texture_rect(painted, Rect2(-paint_rect.size / 2.0, paint_rect.size), false,
			Color("8c8b86") if fallen else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		if lit and _mist_texture != null:
			# Low ground mist over the feet sinks the actor into the painted field.
			var shadow := contact_shadow_rect()
			var mist := Vector2(maxf(shadow.size.x * 1.8, 40.0), maxf(shadow.size.y * 6.0, 28.0))
			draw_texture_rect(_mist_texture, Rect2(shadow.get_center() - mist * Vector2(0.5, 0.75), mist),
				false, Color(mist_color, MIST_ALPHA))

	func _draw_fallback() -> void:
		var band := art_band()
		if band.size.x <= 0.0 or band.size.y <= 0.0:
			return
		draw_set_transform_matrix(idle_transform(fallback_anchor(), fallback_scale()))
		_draw_fallback_shapes(false)
		draw_set_transform(Vector2.ZERO)

	## Body, head, limbs and the slot-specific sewn prop in one local pose. With
	## `silhouette` the same shapes are painted as one dark rim copy behind the actor.
	func _draw_fallback_shapes(silhouette: bool) -> void:
		# The four M05 normals draw their own sewn fallback silhouette and prop from
		# this same filled/rim entry point, so neither path can disagree about the actor.
		# Every other ID, including a fabricated one, keeps the generic puppet below.
		if fallback_kind != FALLBACK_KIND_GENERIC:
			_draw_named_fallback_shapes(silhouette)
			return
		var ink := RIM_INK if silhouette else Color("ecdfbd")
		var cloth := RIM_INK if silhouette else (felt.darkened(0.4) if fallen else felt)
		var face := RIM_INK if silhouette else (Color("c9b996") if not fallen else Color("777a76"))
		var body := PackedVector2Array([Vector2(-20, -13), Vector2(14, -15), Vector2(25, 25), Vector2(-26, 28)])
		draw_colored_polygon(body, cloth)
		draw_polyline(body + PackedVector2Array([body[0]]), ink, 1.5, true)
		draw_line(Vector2(-11, 26), Vector2(-16, 39), cloth, 9)
		draw_line(Vector2(12, 25), Vector2(20, 38), cloth, 9)
		draw_line(Vector2(13, -4), Vector2(34, 8), cloth, 9)
		draw_circle(Vector2(0, -27), 16, face)
		if silhouette:
			return
		draw_dashed_line(Vector2(-16, -8), Vector2(-21, 22), ink, 1, 4)
		draw_circle(Vector2(8, -29), 2, Color("302b29"))
		draw_line(Vector2(10, -21), Vector2(17, -23), Color("302b29"), 2)
		# Slot-specific sewn button patches identify each puppet without textures or RNG.
		for button in range(slot):
			draw_circle(Vector2(-7 + button * 7, 6), 2.5, ink)
		if slot == 1:
			draw_colored_polygon(PackedVector2Array([Vector2(24, 0), Vector2(42, 0), Vector2(40, 24), Vector2(32, 31), Vector2(24, 23)]), Color("555d48"))
		elif slot == 2:
			draw_line(Vector2(32, -16), Vector2(32, 29), ink, 3)
		else:
			draw_rect(Rect2(25, -2, 22, 16), Color("8c6550"))


	## The identity-specific sewn silhouette of the current fallback kind, as filled local
	## polygons. The filled puppet and its dark rim both draw exactly this list, so the two
	## paths can never disagree about the actor's shape. Empty for the generic fallback.
	func fallback_silhouettes() -> Array[Dictionary]:
		match fallback_kind:
			"felt_bulwark":
				return _bulwark_silhouettes()
			"moth_scribe":
				return _moth_scribe_silhouettes()
			"pin_skitter":
				return _pin_skitter_silhouettes()
			"thread_biter":
				return _thread_biter_silhouettes()
			"lantern_monk":
				return _lantern_monk_silhouettes()
			"rag_duelist":
				return _rag_duelist_silhouettes()
			"scarecrow":
				return _scarecrow_silhouettes()
			"yarn_ranger":
				return _yarn_ranger_silhouettes()
			"button_golem":
				return _button_golem_silhouettes()
		return []


	## Paints the current M05 normal's own sewn silhouette, then (only for the filled puppet)
	## its face, teeth and stitched seams. The dark rim passes `silhouette`, so both paths
	## draw exactly the same shape list and the rim can never outline another creature.
	func _draw_named_fallback_shapes(silhouette: bool) -> void:
		var shapes := fallback_silhouettes()
		if shapes.is_empty():
			return
		var ink: Color = NAMED_TONES["ink"]
		for shape in shapes:
			var points: PackedVector2Array = shape["points"]
			if points.size() < 3:
				continue
			draw_colored_polygon(points,
				RIM_INK if silhouette else fallback_tone(String(shape["tone"])))
			if not silhouette:
				var outline := points.duplicate()
				outline.append(points[0])
				draw_polyline(outline, ink, 1.2, true)
		if silhouette:
			return
		match fallback_kind:
			"felt_bulwark":
				_bulwark_details()
			"moth_scribe":
				_moth_scribe_details()
			"pin_skitter":
				_pin_skitter_details()
			"thread_biter":
				_thread_biter_details()
			"lantern_monk":
				_lantern_monk_details()
			"rag_duelist":
				_rag_duelist_details()
			"scarecrow":
				_scarecrow_details()
			"yarn_ranger":
				_yarn_ranger_details()
			"button_golem":
				_button_golem_details()


	## Felt Bulwark: a squat, wide felt slab behind a big sewn round shield held forward.
	func _bulwark_silhouettes() -> Array[Dictionary]:
		var parts: Array[Dictionary] = [
			_fallback_part("cloth", PackedVector2Array([Vector2(-18, 24), Vector2(-7, 26),
				Vector2(-5, 42.5), Vector2(-16, 42.5)])),
			_fallback_part("cloth", PackedVector2Array([Vector2(3, 26), Vector2(14, 24),
				Vector2(16, 42.5), Vector2(5, 42.5)])),
			_fallback_part("cloth", PackedVector2Array([Vector2(-24, 30), Vector2(-21, -8),
				Vector2(15, -10), Vector2(23, 26)])),
			_fallback_part("slate", oval_points(Vector2(34, 3), Vector2(13, 16), 8)),
			_fallback_part("olive", oval_points(Vector2(34, 3), Vector2(5, 7), 8)),
			_fallback_part("face", oval_points(Vector2(-6, -27), Vector2(14, 13), 20)),
		]
		return parts


	## Felt Bulwark's face, stitched felt seams and the shield's own cross-stitch.
	func _bulwark_details() -> void:
		var ink := fallback_tone("ink")
		var seam := fallback_tone("face")
		_draw_stare_eye(Vector2(-11, -29), 2.2)
		_draw_x_eye(Vector2(-1, -30), 2.6)
		draw_line(Vector2(-14, -19), Vector2(1, -18), ink, 2.0, true)
		_draw_teeth(Vector2(-11, -18), 10.0)
		_draw_cross_stitches(Vector2(-17, 0), Vector2(-18, 23), 4, seam)
		_draw_cross_stitches(Vector2(8, 2), Vector2(16, 20), 3, seam)
		draw_dashed_line(Vector2(22, 3), Vector2(46, 3), seam, 1.0, 5.0)
		draw_dashed_line(Vector2(34, -12), Vector2(34, 18), seam, 1.0, 5.0)
		draw_circle(Vector2(34, 3), 2.4, ink)


	## Moth Scribe: tall sewn wings, two felt antennae and a little paper scroll held forward.
	func _moth_scribe_silhouettes() -> Array[Dictionary]:
		var parts: Array[Dictionary] = [
			_fallback_part("cloth", PackedVector2Array([Vector2(-4, -16), Vector2(-24, -40),
				Vector2(-20, -8), Vector2(-6, 0)])),
			_fallback_part("olive", PackedVector2Array([Vector2(-3, -2), Vector2(-22, 6),
				Vector2(-15, 26), Vector2(-3, 14)])),
			_fallback_part("cloth", PackedVector2Array([Vector2(-7, -14), Vector2(6, -16),
				Vector2(9, 22), Vector2(2, 42.5), Vector2(-7, 36), Vector2(-9, 8)])),
			_fallback_part("plum", PackedVector2Array([Vector2(-4, -32), Vector2(-1, -36),
				Vector2(-8, -42), Vector2(-10, -40)])),
			_fallback_part("plum", PackedVector2Array([Vector2(7, -33), Vector2(10, -31),
				Vector2(13, -41), Vector2(11, -42)])),
			_fallback_part("cream", PackedVector2Array([Vector2(15, -10), Vector2(38, -16),
				Vector2(42, -2), Vector2(20, 6)])),
			_fallback_part("face", oval_points(Vector2(2, -24), Vector2(12, 12), 20)),
		]
		return parts


	## Moth Scribe's face, wing veins and the stitched rules of its paper scroll.
	func _moth_scribe_details() -> void:
		var ink := fallback_tone("ink")
		var seam := fallback_tone("face")
		var thread := fallback_tone("cream")
		_draw_stare_eye(Vector2(7, -27), 2.2)
		_draw_droopy_eye(Vector2(-4, -27), 3.0)
		draw_line(Vector2(-2, -17), Vector2(8, -16), ink, 2.0, true)
		_draw_teeth(Vector2(-1, -16), 8.0)
		# The felt wings are sewn, not blank cloth.
		draw_dashed_line(Vector2(-6, -14), Vector2(-21, -36), seam, 1.0, 5.0)
		draw_dashed_line(Vector2(-5, 0), Vector2(-19, 20), seam, 1.0, 5.0)
		# The scroll's stitched rules and a little ink line of writing.
		draw_dashed_line(Vector2(18, -6), Vector2(38, -11), seam, 1.0, 5.0)
		draw_dashed_line(Vector2(19, 1), Vector2(39, -4), seam, 1.0, 5.0)
		draw_line(Vector2(20, -8), Vector2(35, -12), ink, 1.2, true)
		_draw_cross_stitches(Vector2(-6, 12), Vector2(5, 32), 4, thread)


	## Pin Skitter: a low many-legged skitter body thrusting one long sewn pin forward.
	func _pin_skitter_silhouettes() -> Array[Dictionary]:
		var parts: Array[Dictionary] = [
			_fallback_part("olive", PackedVector2Array([Vector2(-19, 10), Vector2(-15, 12),
				Vector2(-24, 42.5), Vector2(-25, 39)])),
			_fallback_part("olive", PackedVector2Array([Vector2(-10, 13), Vector2(-6, 14),
				Vector2(-12, 42.5), Vector2(-14, 42.5)])),
			_fallback_part("olive", PackedVector2Array([Vector2(2, 15), Vector2(6, 14),
				Vector2(4, 42.5), Vector2(2, 42.5)])),
			_fallback_part("olive", PackedVector2Array([Vector2(13, 12), Vector2(17, 10),
				Vector2(21, 42.5), Vector2(19, 42.5)])),
			_fallback_part("cloth", PackedVector2Array([Vector2(-21, 8), Vector2(-15, -8),
				Vector2(8, -12), Vector2(19, 0), Vector2(17, 16), Vector2(-17, 18)])),
			_fallback_part("steel", PackedVector2Array([Vector2(17, 4), Vector2(45, -14),
				Vector2(47, -10), Vector2(19, 8)])),
			_fallback_part("steel", oval_points(Vector2(15, 7), Vector2(4, 4), 12)),
			_fallback_part("face", oval_points(Vector2(11, -19), Vector2(11, 10), 20)),
		]
		return parts


	## Pin Skitter's face, its crooked zigzag mouth and the seam along its pin.
	func _pin_skitter_details() -> void:
		var ink := fallback_tone("ink")
		var seam := fallback_tone("face")
		_draw_stare_eye(Vector2(15, -21), 2.8)
		_draw_droopy_eye(Vector2(5, -19), 2.4)
		var mouth := PackedVector2Array([Vector2(4, -13), Vector2(7, -15), Vector2(10, -13),
			Vector2(13, -15), Vector2(17, -13)])
		draw_polyline(mouth, ink, 1.8, true)
		_draw_teeth(Vector2(5, -13), 11.0)
		draw_dashed_line(Vector2(-16, 6), Vector2(14, 4), seam, 1.0, 5.0)
		_draw_cross_stitches(Vector2(13, 5), Vector2(17, 9), 1, seam)
		draw_line(Vector2(20, 2), Vector2(43, -12), seam, 1.0, true)


	## Thread Biter: a hunched biter with a dark sewn jaw and a trailing thread spool.
	func _thread_biter_silhouettes() -> Array[Dictionary]:
		var parts: Array[Dictionary] = [
			_fallback_part("cloth", PackedVector2Array([Vector2(-15, 24), Vector2(-6, 26),
				Vector2(-4, 42.5), Vector2(-14, 42.5)])),
			_fallback_part("cloth", PackedVector2Array([Vector2(5, 26), Vector2(13, 22),
				Vector2(19, 42.5), Vector2(11, 42.5)])),
			_fallback_part("cloth", PackedVector2Array([Vector2(-20, 16), Vector2(-15, -10),
				Vector2(7, -16), Vector2(18, 2), Vector2(14, 24), Vector2(-11, 28)])),
			_fallback_part("rust", PackedVector2Array([Vector2(-26, -6), Vector2(-17, -8),
				Vector2(-15, 10), Vector2(-25, 12)])),
			_fallback_part("face", oval_points(Vector2(12, -22), Vector2(13, 12), 20)),
			_fallback_part("ink", PackedVector2Array([Vector2(3, -14), Vector2(24, -16),
				Vector2(22, -8), Vector2(5, -8)])),
		]
		return parts


	## Thread Biter's face, its thread-wrapped spool and the loose end trailing behind.
	func _thread_biter_details() -> void:
		var ink := fallback_tone("ink")
		var seam := fallback_tone("face")
		_draw_stare_eye(Vector2(17, -26), 2.5)
		_draw_x_eye(Vector2(7, -25), 2.4)
		_draw_teeth(Vector2(5, -11), 16.0)
		draw_dashed_line(Vector2(-24, 2), Vector2(-18, 2), seam, 1.0, 4.0)
		draw_dashed_line(Vector2(-24, 6), Vector2(-18, 6), seam, 1.0, 4.0)
		draw_dashed_line(Vector2(-22, 12), Vector2(-20, 34), seam, 1.2, 4.0)
		_draw_cross_stitches(Vector2(-13, -4), Vector2(2, 10), 4, seam)
		draw_line(Vector2(4, 14), Vector2(12, 20), ink, 1.2, true)


	## Lantern Monk: squat saffron robe, a raised pole lantern, and two circling moths.
	## Every outer shape is part of both the dark rim and the coloured puppet.
	func _lantern_monk_silhouettes() -> Array[Dictionary]:
		return [
			_fallback_part("monk_plum", PackedVector2Array([Vector2(-18, 22), Vector2(-10, 24),
				Vector2(-10, 42.5), Vector2(-20, 42.5)]), "left_foot"),
			_fallback_part("monk_plum", PackedVector2Array([Vector2(4, 23), Vector2(13, 22),
				Vector2(17, 42.5), Vector2(6, 42.5)]), "right_foot"),
			_fallback_part("saffron", oval_points(Vector2(-4, 12), Vector2(21, 27), 24), "round_robe"),
			_fallback_part("monk_plum", PackedVector2Array([Vector2(-18, 8), Vector2(-6, 0),
				Vector2(1, 25), Vector2(-18, 29)]), "robe_patch"),
			_fallback_part("saffron", PackedVector2Array([Vector2(12, -3), Vector2(29, -19),
				Vector2(33, -15), Vector2(18, 9)]), "raised_sleeve"),
			_fallback_part("walnut", PackedVector2Array([Vector2(33, 17), Vector2(36, 17),
				Vector2(36, -41), Vector2(33, -41)]), "lantern_pole"),
			_fallback_part("monk_plum", PackedVector2Array([Vector2(25, -38), Vector2(35, -43),
				Vector2(44, -37)]), "lantern_roof"),
			_fallback_part("saffron", PackedVector2Array([Vector2(26, -37), Vector2(43, -37),
				Vector2(42, -17), Vector2(28, -17)]), "sewn_lantern"),
			_fallback_part("monk_cream", oval_points(Vector2(35, -28), Vector2(5, 8), 12), "lantern_glow"),
			_fallback_part("monk_cream", oval_points(Vector2(-7, -19), Vector2(15, 14), 20), "round_face"),
			_fallback_part("monk_cream", PackedVector2Array([Vector2(18, -38), Vector2(23, -41),
				Vector2(25, -34), Vector2(21, -32)]), "first_moth"),
			_fallback_part("monk_plum", PackedVector2Array([Vector2(42, -9), Vector2(46, -13),
				Vector2(47, -6), Vector2(43, -5)]), "second_moth"),
		]


	func _lantern_monk_details() -> void:
		var ink := fallback_tone("ink")
		var cream := fallback_tone("monk_cream")
		draw_circle(Vector2(0, -22), 5.0, cream)
		draw_circle(Vector2(1, -22), 3.4, ink) # The lantern-lit oversized button eye.
		_draw_droopy_eye(Vector2(-15, -21), 2.8)
		draw_line(Vector2(-10, -11), Vector2(1, -10), ink, 1.5, true)
		_draw_teeth(Vector2(-8, -10), 6.0)
		_draw_cross_stitches(Vector2(-15, 4), Vector2(-10, 27), 5, cream)
		_draw_cross_stitches(Vector2(29, -35), Vector2(30, -20), 3, ink)
		draw_dashed_line(Vector2(35, -37), Vector2(35, -18), ink, 1.0, 4.0)


	## Rag Duelist: trailing tattered cape, plumed hat and a slim needle rapier.
	func _rag_duelist_silhouettes() -> Array[Dictionary]:
		return [
			_fallback_part("duelist_black", PackedVector2Array([Vector2(-8, 24), Vector2(1, 24),
				Vector2(-1, 42.5), Vector2(-13, 42.5)]), "left_boot"),
			_fallback_part("duelist_black", PackedVector2Array([Vector2(7, 23), Vector2(16, 21),
				Vector2(21, 42.5), Vector2(10, 42.5)]), "right_boot"),
			_fallback_part("crimson", PackedVector2Array([Vector2(-10, -17), Vector2(-26, -7),
				Vector2(-22, 9), Vector2(-26, 29), Vector2(-13, 21), Vector2(-7, 35),
				Vector2(8, 14)]), "tattered_cape"),
			_fallback_part("duelist_black", oval_points(Vector2(0, 7), Vector2(13, 24), 20), "lean_coat"),
			_fallback_part("crimson", PackedVector2Array([Vector2(2, -7), Vector2(18, -7),
				Vector2(19, 18), Vector2(8, 21)]), "coat_lapel"),
			_fallback_part("gold", PackedVector2Array([Vector2(13, -4), Vector2(26, 4),
				Vector2(33, 0), Vector2(23, -9)]), "guard_arm"),
			_fallback_part("gold", PackedVector2Array([Vector2(26, -2), Vector2(34, -3),
				Vector2(34, 2), Vector2(26, 2)]), "rapier_hilt"),
			_fallback_part("steel", PackedVector2Array([Vector2(31, -1), Vector2(47, -13),
				Vector2(46, -8), Vector2(33, 2)]), "needle_rapier"),
			_fallback_part("face", oval_points(Vector2(-1, -22), Vector2(13, 12), 20), "duelist_face"),
			_fallback_part("duelist_black", PackedVector2Array([Vector2(-22, -35), Vector2(14, -35),
				Vector2(20, -31), Vector2(-24, -31)]), "wide_hat_brim"),
			_fallback_part("crimson", PackedVector2Array([Vector2(-14, -35), Vector2(-7, -42),
				Vector2(8, -39), Vector2(11, -34)]), "tilted_hat"),
			_fallback_part("gold", PackedVector2Array([Vector2(1, -37), Vector2(5, -43),
				Vector2(9, -43), Vector2(7, -35)]), "hat_feather"),
		]


	func _rag_duelist_details() -> void:
		var ink := fallback_tone("ink")
		var gold := fallback_tone("gold")
		draw_circle(Vector2(-7, -24), 4.2, fallback_tone("duelist_black"))
		draw_circle(Vector2(-7, -24), 1.4, gold) # Button eyepatch.
		_draw_stare_eye(Vector2(5, -24), 2.4)
		_draw_teeth(Vector2(-4, -13), 7.0)
		draw_line(Vector2(24, -3), Vector2(30, 4), ink, 1.4, true)
		_draw_cross_stitches(Vector2(-20, 2), Vector2(-17, 21), 4, gold)
		_draw_cross_stitches(Vector2(11, 0), Vector2(11, 16), 3, gold)


	## Scarecrow: burlap sack head, crow on the shoulder, straw and pitchfork.
	func _scarecrow_silhouettes() -> Array[Dictionary]:
		return [
			_fallback_part("denim", PackedVector2Array([Vector2(-13, 22), Vector2(-4, 24),
				Vector2(-5, 42.5), Vector2(-16, 42.5)]), "left_trouser"),
			_fallback_part("denim", PackedVector2Array([Vector2(5, 25), Vector2(15, 21),
				Vector2(19, 42.5), Vector2(7, 42.5)]), "right_trouser"),
			_fallback_part("pumpkin", PackedVector2Array([Vector2(-21, -6), Vector2(14, -6),
				Vector2(23, 27), Vector2(-25, 27)]), "stuffed_shirt"),
			_fallback_part("denim", PackedVector2Array([Vector2(-5, -6), Vector2(15, 2),
				Vector2(13, 23), Vector2(-12, 23)]), "denim_patch"),
			_fallback_part("burlap", PackedVector2Array([Vector2(-21, -35), Vector2(6, -40),
				Vector2(16, -25), Vector2(12, -9), Vector2(-17, -11)]), "sack_head"),
			_fallback_part("gold", PackedVector2Array([Vector2(-20, -35), Vector2(-26, -42),
				Vector2(-13, -39), Vector2(-8, -43), Vector2(-2, -37)]), "head_straw"),
			_fallback_part("gold", PackedVector2Array([Vector2(-22, 4), Vector2(-26, -1),
				Vector2(-24, 13), Vector2(-17, 15)]), "sleeve_straw"),
			_fallback_part("duelist_black", PackedVector2Array([Vector2(-23, -10), Vector2(-20, -22),
				Vector2(-13, -23), Vector2(-7, -15), Vector2(-10, -9)]), "shoulder_crow"),
			_fallback_part("gold", PackedVector2Array([Vector2(-12, -18), Vector2(-6, -16),
				Vector2(-13, -14)]), "crow_beak"),
			_fallback_part("walnut", PackedVector2Array([Vector2(31, 42), Vector2(35, 42),
				Vector2(35, -39), Vector2(31, -39)]), "pitchfork_handle"),
			_fallback_part("steel", PackedVector2Array([Vector2(29, -27), Vector2(29, -40),
				Vector2(31, -43), Vector2(33, -30), Vector2(38, -43), Vector2(40, -40),
				Vector2(40, -24)]), "pitchfork_tines"),
		]


	func _scarecrow_details() -> void:
		var ink := fallback_tone("ink")
		var straw := fallback_tone("gold")
		_draw_x_eye(Vector2(-11, -28), 3.2)
		_draw_stare_eye(Vector2(5, -29), 2.4)
		draw_dashed_line(Vector2(-12, -17), Vector2(8, -18), ink, 1.8, 3.0)
		_draw_teeth(Vector2(-10, -17), 17.0)
		_draw_cross_stitches(Vector2(-12, -3), Vector2(9, 19), 5, straw)
		draw_line(Vector2(-16, -12), Vector2(-9, -9), ink, 1.0, true)


	## Yarn Ranger: tiny knitted hood with catlike ears, needle-bow and yarn bola.
	func _yarn_ranger_silhouettes() -> Array[Dictionary]:
		return [
			_fallback_part("moss", PackedVector2Array([Vector2(-12, 24), Vector2(-4, 25),
				Vector2(-5, 42.5), Vector2(-15, 42.5)]), "left_boot"),
			_fallback_part("teal", PackedVector2Array([Vector2(2, 24), Vector2(12, 20),
				Vector2(17, 42.5), Vector2(6, 42.5)]), "right_boot"),
			_fallback_part("moss", oval_points(Vector2(-3, 11), Vector2(16, 24), 22), "ranger_tunic"),
			_fallback_part("teal", PackedVector2Array([Vector2(-18, 5), Vector2(-9, 2),
				Vector2(-6, 26), Vector2(-23, 30)]), "cape_patch"),
			_fallback_part("moss", PackedVector2Array([Vector2(-19, -34), Vector2(-19, -43),
				Vector2(-7, -36)]), "left_hood_ear"),
			_fallback_part("teal", PackedVector2Array([Vector2(2, -38), Vector2(10, -43),
				Vector2(14, -29)]), "right_hood_ear"),
			_fallback_part("moss", oval_points(Vector2(-3, -23), Vector2(16, 17), 20), "knitted_hood"),
			_fallback_part("wool", oval_points(Vector2(-2, -21), Vector2(11, 11), 20), "wool_face"),
			_fallback_part("steel", PackedVector2Array([Vector2(28, -40), Vector2(32, -41),
				Vector2(39, 8), Vector2(35, 12)]), "upper_bow_needle"),
			_fallback_part("steel", PackedVector2Array([Vector2(35, 12), Vector2(39, 8),
				Vector2(30, 36), Vector2(26, 35)]), "lower_bow_needle"),
			_fallback_part("wool", PackedVector2Array([Vector2(30, -37), Vector2(43, -14),
				Vector2(29, 34), Vector2(32, 11)]), "bow_yarn_string"),
			_fallback_part("teal", oval_points(Vector2(-21, 21), Vector2(4, 6), 12), "hip_yarn_bola"),
		]


	func _yarn_ranger_details() -> void:
		var ink := fallback_tone("ink")
		var wool := fallback_tone("wool")
		_draw_stare_eye(Vector2(3, -23), 3.0)
		_draw_x_eye(Vector2(-9, -22), 2.0)
		_draw_teeth(Vector2(-4, -14), 5.0)
		draw_dashed_line(Vector2(-15, -31), Vector2(8, -32), wool, 1.0, 4.0)
		_draw_cross_stitches(Vector2(-12, 9), Vector2(7, 19), 4, wool)
		draw_circle(Vector2(-22, 21), 2.0, wool)
		draw_line(Vector2(-21, 17), Vector2(-24, 23), ink, 1.1, true)


	## Button Golem: the broadest stack, tiny head and immense two-hole button fists.
	func _button_golem_silhouettes() -> Array[Dictionary]:
		return [
			_fallback_part("golem_slate", PackedVector2Array([Vector2(-18, 20), Vector2(-7, 20),
				Vector2(-10, 42.5), Vector2(-24, 42.5)]), "left_column_leg"),
			_fallback_part("golem_slate", PackedVector2Array([Vector2(14, 20), Vector2(25, 20),
				Vector2(31, 42.5), Vector2(17, 42.5)]), "right_column_leg"),
			_fallback_part("walnut", oval_points(Vector2(3, 12), Vector2(27, 28), 28), "broad_button_body"),
			_fallback_part("brass", oval_points(Vector2(4, 4), Vector2(23, 14), 24), "upper_button"),
			_fallback_part("walnut", oval_points(Vector2(3, 22), Vector2(24, 13), 24), "lower_button"),
			_fallback_part("golem_slate", PackedVector2Array([Vector2(-20, -3), Vector2(-26, 3),
				Vector2(-26, 17), Vector2(-17, 17)]), "left_button_arm"),
			_fallback_part("golem_slate", PackedVector2Array([Vector2(22, -4), Vector2(34, -4),
				Vector2(39, 13), Vector2(26, 15)]), "right_button_arm"),
			_fallback_part("brass", oval_points(Vector2(-20, 13), Vector2(6, 12), 16), "left_button_fist"),
			_fallback_part("brass", oval_points(Vector2(39, 8), Vector2(8, 13), 16), "right_button_fist"),
			_fallback_part("walnut", oval_points(Vector2(0, -27), Vector2(9, 9), 20), "tiny_head"),
			_fallback_part("brass", PackedVector2Array([Vector2(-9, -33), Vector2(1, -41),
				Vector2(7, -33)]), "head_seam"),
		]


	func _button_golem_details() -> void:
		var ink := fallback_tone("ink")
		var brass := fallback_tone("brass")
		for center in [Vector2(-4, -29), Vector2(4, -29)]:
			draw_circle(center, 2.0, ink) # Thread-hole eyes.
		for center in [Vector2(-20, 13), Vector2(39, 8)]:
			draw_circle(center + Vector2(0, -4), 1.8, ink)
			draw_circle(center + Vector2(0, 4), 1.8, ink)
		draw_circle(Vector2(-3, 4), 2.3, ink)
		draw_circle(Vector2(10, 4), 2.3, ink)
		draw_circle(Vector2(-3, 22), 2.3, brass)
		draw_circle(Vector2(9, 22), 2.3, brass)
		_draw_cross_stitches(Vector2(-15, -2), Vector2(-11, 25), 4, brass)
		draw_dashed_line(Vector2(-6, -17), Vector2(7, -17), brass, 1.1, 3.0)


	func _fallback_part(tone: String, points: PackedVector2Array, part: String = "") -> Dictionary:
		var shape := {"tone": tone, "points": points}
		if not part.is_empty():
			shape["part"] = part
		return shape


	## One muted sewn tone of the identity-specific puppets; `cloth` keeps this actor's own
	## slot felt, and a fallen actor is drawn dimmed like the generic puppet.
	func fallback_tone(tone: String) -> Color:
		if tone == "cloth":
			return felt.darkened(0.4) if fallen else felt
		var base: Color = NAMED_TONES.get(tone, NAMED_TONES["face"])
		return base.darkened(0.2) if fallen else base


	## One staring stitched button eye. The other eye is crossed out or hooded, so every M05
	## normal reads as its own sewn creature.
	func _draw_stare_eye(center: Vector2, radius: float) -> void:
		draw_circle(center, radius, fallback_tone("ink"))


	func _draw_x_eye(center: Vector2, radius: float) -> void:
		var ink := fallback_tone("ink")
		draw_line(center + Vector2(-radius, -radius), center + Vector2(radius, radius),
			ink, 1.8, true)
		draw_line(center + Vector2(-radius, radius), center + Vector2(radius, -radius),
			ink, 1.8, true)


	func _draw_droopy_eye(center: Vector2, radius: float) -> void:
		var ink := fallback_tone("ink")
		draw_line(center + Vector2(-radius, -radius * 0.5), center + Vector2(radius, 0.0),
			ink, 1.8, true)
		draw_line(center + Vector2(radius * 0.4, 0.0), center + Vector2(radius * 0.4, radius * 0.7),
			ink, 1.4, true)


	## Three tiny crooked felt teeth under a mouth line.
	func _draw_teeth(origin: Vector2, width: float) -> void:
		var cream := fallback_tone("cream")
		for index in range(3):
			var left := origin.x + width * float(index) / 3.0
			var right := origin.x + width * float(index + 1) / 3.0
			var drop := 2.0 + float(index % 2) * 1.2
			draw_colored_polygon(PackedVector2Array([Vector2(left, origin.y),
				Vector2(right, origin.y), Vector2((left + right) * 0.5, origin.y + drop)]), cream)


	## Visible sewn cross-stitches along one seam of the puppet.
	func _draw_cross_stitches(from: Vector2, to: Vector2, count: int, ink: Color) -> void:
		for index in range(count):
			var point := from.lerp(to, (float(index) + 0.5) / float(count))
			draw_line(point + Vector2(-2.0, -2.0), point + Vector2(2.0, 2.0), ink, 1.2, true)
			draw_line(point + Vector2(-2.0, 2.0), point + Vector2(2.0, -2.0), ink, 1.2, true)


## Deterministic battle stage behind the actor row: the authored paper scene of this
## fight when it is available, otherwise one continuous drawn quilt seamed into
## axis-aligned patches. Both keep the same stitched ground hem. Presentation only, so
## it never takes pointer or keyboard input.
class StageBackdrop extends Control:
	## The battle view this stage paints, so the scene covers the whole battle area
	## (including its margins) instead of one actor box.
	var battle_view: Control
	var stage_row: Control
	## The authoritative route kind this battle was admitted as, and its loaded scene.
	var battle_kind := ""
	var stage_texture: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)
		if is_instance_valid(stage_row):
			stage_row.item_rect_changed.connect(queue_redraw)
		if is_instance_valid(battle_view):
			battle_view.item_rect_changed.connect(queue_redraw)

	## Binds the scene selected for one battle kind; a missing image keeps the quilt.
	func bind_battle(kind: String, texture: Texture2D) -> void:
		battle_kind = kind
		stage_texture = texture
		queue_redraw()

	func has_image() -> bool:
		return stage_texture != null and stage_texture.get_width() > 0 \
			and stage_texture.get_height() > 0

	func texture_size() -> Vector2:
		if not has_image():
			return Vector2.ZERO
		return Vector2(stage_texture.get_width(), stage_texture.get_height())

	## The whole battle view this scene fills, in this Control's own coordinates.
	func view_rect() -> Rect2:
		if is_instance_valid(battle_view) and battle_view.is_visible_in_tree():
			var view := battle_view.get_global_rect()
			if view.size.x > 0.0 and view.size.y > 0.0:
				return Rect2(view.position - get_global_rect().position, view.size)
		return Rect2(Vector2.ZERO, size)

	## Cover placement of the bound scene: fills the view, keeping its own proportions.
	func image_rect() -> Rect2:
		return cover_rect(view_rect(), texture_size())

	## The centred part of the source image a cover draw keeps inside the view.
	func image_crop() -> Rect2:
		return crop_rect(view_rect(), texture_size())

	static func cover_rect(view: Rect2, texture_size: Vector2) -> Rect2:
		if view.size.x <= 0.0 or view.size.y <= 0.0 \
				or texture_size.x <= 0.0 or texture_size.y <= 0.0:
			return Rect2()
		var cover := maxf(view.size.x / texture_size.x, view.size.y / texture_size.y)
		var drawn := texture_size * cover
		return Rect2(view.position + (view.size - drawn) / 2.0, drawn)

	static func crop_rect(view: Rect2, texture_size: Vector2) -> Rect2:
		if view.size.x <= 0.0 or view.size.y <= 0.0 \
				or texture_size.x <= 0.0 or texture_size.y <= 0.0:
			return Rect2()
		var cover := maxf(view.size.x / texture_size.x, view.size.y / texture_size.y)
		var visible := view.size / cover
		return Rect2((texture_size - visible) / 2.0, visible)

	## The actor row in this Control's own coordinates, or empty while there is no stage.
	func stage_rect() -> Rect2:
		if not is_instance_valid(stage_row) or not stage_row.is_visible_in_tree():
			return Rect2()
		var row := stage_row.get_global_rect()
		if row.size.x <= 0.0 or row.size.y <= 0.0:
			return Rect2()
		return Rect2(row.position - get_global_rect().position, row.size)

	## The sewn cloth above the hem that marks the ground.
	func quilt_cloth() -> Rect2:
		var row := stage_rect()
		if row.size.x <= 0.0 or row.size.y <= 0.0:
			return Rect2()
		return Rect2(row.position, Vector2(row.size.x, maxf(0.0, row.size.y - STAGE_HEM_HEIGHT)))

	## Every axis-aligned patch of the continuous quilt, left to right, top to bottom.
	func quilt_rects() -> Array[Rect2]:
		var cloth := quilt_cloth()
		var rects: Array[Rect2] = []
		if cloth.size.x <= 0.0 or cloth.size.y <= 0.0:
			return rects
		for row_index in range(STAGE_QUILT_ROWS.size() - 1):
			for column_index in range(STAGE_QUILT_COLUMNS.size() - 1):
				var top: float = cloth.position.y + cloth.size.y * float(STAGE_QUILT_ROWS[row_index])
				var bottom: float = cloth.position.y + cloth.size.y * float(STAGE_QUILT_ROWS[row_index + 1])
				var left: float = cloth.position.x + cloth.size.x * float(STAGE_QUILT_COLUMNS[column_index])
				var right: float = cloth.position.x + cloth.size.x * float(STAGE_QUILT_COLUMNS[column_index + 1])
				rects.append(Rect2(left, top, right - left, bottom - top))
		return rects

	## The stitched seams between neighbouring patches, as two-point thread runs.
	func quilt_seams() -> Array[PackedVector2Array]:
		var seams: Array[PackedVector2Array] = []
		var cloth := quilt_cloth()
		if cloth.size.x <= 0.0 or cloth.size.y <= 0.0:
			return seams
		for index in range(1, STAGE_QUILT_COLUMNS.size() - 1):
			var x: float = cloth.position.x + cloth.size.x * float(STAGE_QUILT_COLUMNS[index])
			seams.append(PackedVector2Array([Vector2(x, cloth.position.y), Vector2(x, cloth.end.y)]))
		for index in range(1, STAGE_QUILT_ROWS.size() - 1):
			var y: float = cloth.position.y + cloth.size.y * float(STAGE_QUILT_ROWS[index])
			seams.append(PackedVector2Array([Vector2(cloth.position.x, y), Vector2(cloth.end.x, y)]))
		return seams

	func quilt_tone(index: int) -> Color:
		return STAGE_QUILT_TONES[index % STAGE_QUILT_TONES.size()]

	func _draw() -> void:
		if has_image():
			_draw_backdrop_image()
		else:
			_draw_quilt()
		# Lay the painted ground in before piling the actors on it: an even dim wash, then
		# soft dark edges. The quiet hem is stitched over both, so the ground line stays
		# crisp and no actor or HUD control is ever tinted by this stage.
		_draw_dim()
		_draw_vignette()
		_draw_ground_hem()

	## The painted ground this stage dims: the whole battle view the scene covers, or the
	## quilt cloth when the drawn fallback is on stage.
	func dim_rect() -> Rect2:
		if has_image():
			return view_rect()
		return quilt_cloth()

	## The even dark wash laid over whichever ground was painted. It lives entirely in this
	## stage's draw pass; actors, meters, labels and hand cards are siblings drawn after it.
	func dim_color() -> Color:
		return Color(STAGE_DIM_INK, STAGE_DIM_ALPHA)

	## Alpha of one vignette layer: strongest at the rim, fading toward the middle.
	func vignette_alpha(step: int) -> float:
		var t := float(step) / float(STAGE_VIGNETTE_STEPS)
		return STAGE_VIGNETTE_ALPHA * pow(1.0 - t, 2.0) / float(STAGE_VIGNETTE_STEPS)

	## Soft dark frame at the stage edges as nested bands, four per step: left, right, top,
	## bottom, outermost first. The middle of the view is never touched.
	func vignette_rects() -> Array[Rect2]:
		var bands: Array[Rect2] = []
		var area := dim_rect()
		if area.size.x <= 0.0 or area.size.y <= 0.0:
			return bands
		var depth := minf(area.size.x, area.size.y) * STAGE_VIGNETTE_DEPTH
		var band_depth := depth / float(STAGE_VIGNETTE_STEPS)
		for step in range(STAGE_VIGNETTE_STEPS):
			var offset := band_depth * float(step)
			bands.append(Rect2(area.position.x + offset, area.position.y, band_depth, area.size.y))
			bands.append(Rect2(area.end.x - offset - band_depth, area.position.y, band_depth, area.size.y))
			bands.append(Rect2(area.position.x, area.position.y + offset, area.size.x, band_depth))
			bands.append(Rect2(area.position.x, area.end.y - offset - band_depth, area.size.x, band_depth))
		return bands

	## The authored paper scene, cover-cropped into the whole battle view.
	func _draw_backdrop_image() -> void:
		draw_texture_rect_region(stage_texture, view_rect(), image_crop())

	## One even dark wash over the ground the stage painted, about one fifth.
	func _draw_dim() -> void:
		var area := dim_rect()
		if area.size.x <= 0.0 or area.size.y <= 0.0:
			return
		draw_rect(area, dim_color())

	## Soft dark frame at the edges: nested translucent bands, darkest at the rim.
	func _draw_vignette() -> void:
		var bands := vignette_rects()
		for step in range(STAGE_VIGNETTE_STEPS):
			var wash := Color(STAGE_VIGNETTE_INK, vignette_alpha(step))
			for edge in range(4):
				var index := step * 4 + edge
				if index >= bands.size():
					return
				draw_rect(bands[index], wash)

	func _draw_quilt() -> void:
		var cloth := quilt_cloth()
		if cloth.size.x <= 0.0 or cloth.size.y <= 0.0:
			return
		# One continuous quilt: every patch is axis-aligned and shares its edges, so no
		# seam can open or tilt across the stage.
		var patches := quilt_rects()
		for index in range(patches.size()):
			draw_rect(patches[index], quilt_tone(index))
		for seam in quilt_seams():
			draw_dashed_line(seam[0], seam[1], STAGE_THREAD, 1.0, 7.0)

	## The single hem of ground the actors stand on, above either quilt or image.
	func hem_rect() -> Rect2:
		var cloth := quilt_cloth()
		if cloth.size.x <= 0.0 or cloth.size.y <= 0.0:
			return Rect2()
		return Rect2(cloth.position.x, cloth.end.y, cloth.size.x, STAGE_HEM_HEIGHT)

	func _draw_ground_hem() -> void:
		var hem := hem_rect()
		if hem.size.x <= 0.0 or hem.size.y <= 0.0:
			return
		draw_rect(hem, STAGE_HEM)
		draw_dashed_line(Vector2(hem.position.x + 10.0, hem.position.y),
			Vector2(hem.end.x - 10.0, hem.position.y), STAGE_THREAD, 2.0, 9.0)
		var x := hem.position.x + 18.0
		while x < hem.end.x - 12.0:
			draw_line(Vector2(x, hem.position.y + 3.0), Vector2(x + 7.0, hem.end.y - 3.0),
				STAGE_THREAD, 1.5, true)
			x += 26.0


## Inert art bed for one mounted noncombat visit (Rest, Shop or Event). It fills the whole
## view with the authored scene through the battle stage's own aspect-cover crop, laid
## over an opaque slate that stays visible when the file is missing, so the same controls
## keep a readable ground with or without art. Draw-only: no pointer or keyboard input,
## and it is mounted as a sibling/backdrop, never as a layout child of the visit controls.
class VisitBackdrop extends Control:
	const SLATE := Color("18242c")
	const VEIL_INK := Color("12100e")
	## A light wash keeps the cream visit labels and felt controls legible over the art.
	const VEIL_ALPHA := 0.26
	var visit_kind := ""
	var visit_texture: Texture2D = null

	func _init() -> void:
		name = "VisitBackdrop"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	## Binds the scene selected for one stop; a missing image keeps the plain slate.
	func bind_visit(kind: String, texture: Texture2D) -> void:
		visit_kind = kind
		visit_texture = texture
		queue_redraw()

	func has_image() -> bool:
		return visit_texture != null and visit_texture.get_width() > 0 \
			and visit_texture.get_height() > 0

	func slate_color() -> Color:
		return SLATE

	func veil_color() -> Color:
		return Color(VEIL_INK, VEIL_ALPHA)

	## The whole screen this visit bed paints, in this Control's own coordinates.
	func view_rect() -> Rect2:
		return Rect2(Vector2.ZERO, size)

	func texture_size() -> Vector2:
		if not has_image():
			return Vector2.ZERO
		return Vector2(visit_texture.get_width(), visit_texture.get_height())

	## Cover placement of the visit scene: fills the view, keeping its own proportions.
	func image_rect() -> Rect2:
		return StageBackdrop.cover_rect(view_rect(), texture_size())

	## The centred part of the source image a cover draw keeps inside the view.
	func image_crop() -> Rect2:
		return StageBackdrop.crop_rect(view_rect(), texture_size())

	func _draw() -> void:
		draw_rect(view_rect(), SLATE)
		if has_image():
			draw_texture_rect_region(visit_texture, image_rect(), image_crop())
		draw_rect(view_rect(), veil_color())


func _ready() -> void:
	# The parent connects its Start Run handler after child _ready, so observe deferred.
	get_parent().start_run_requested.connect(_sync_battle, CONNECT_DEFERRED)


func _process(_delta: float) -> void:
	_sync_battle()
	_refresh()


func _sync_battle() -> void:
	var app = get_parent()
	if app.deck == null or app.party == null or app.enemies == null or not is_instance_valid(app.battle_view) \
			or not is_instance_valid(app.hero_view):
		_clear()
		return
	if _battle == app.battle_view and enemies == app.enemies and _heroes == app.hero_view \
			and is_instance_valid(battle_row) and is_instance_valid(panel) and is_instance_valid(backdrop) \
			and _admitted_ids.size() == enemies.get_enemies().size():
		# A changed admitted kind or Fight area floor rebinds the same one stage
		# instead of adding another; an unchanged selection leaves it alone.
		if stage_key(_battle_kind(app), _battle_floor(app)) != _backdrop_key:
			_bind_backdrop(app)
		return
	_clear()
	_battle = app.battle_view
	_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
	enemies = app.enemies
	_heroes = app.hero_view
	_hero_parent = _heroes.get_parent()
	_hero_index = _heroes.get_index()
	_hero_flags = _heroes.size_flags_horizontal
	_intent_visible = app.intent_label.visible
	if is_instance_valid(app.intent_label):
		app.intent_label.hide()
	for hero_panel in app.hero_panels:
		var label := hero_panel.get_child(0) as Label
		_hero_fonts[label] = label.get_theme_font_size("font_size")
		label.hide() # Preserve app-owned source text; the meter owns the visible readout.
		var puppet := Puppet.new()
		puppet.name = "HeroPuppet%d" % (hero_panel.get_index() + 1)
		puppet.slot = hero_panel.get_index() + 1
		puppet.stage_height = STAGE_ACTOR_HEIGHT
		puppet.intent_band = STAGE_INTENT_BAND
		puppet.tag_height = STAGE_TAG_HEIGHT
		puppet.felt = [Color("719796"), Color("93839e"), Color("b49a55")][puppet.slot - 1]
		hero_panel.add_child(puppet)
		_puppets.append(puppet)
		var tag := _make_name_tag("HeroNameTag%d" % puppet.slot)
		puppet.add_child(tag)
		_hero_tags.append(tag)
		var reaction_tag := _make_warden_reaction_tag(puppet.slot)
		puppet.add_child(reaction_tag)
		_hero_reaction_tags.append(reaction_tag)
	battle_row = HBoxContainer.new()
	battle_row.name = "BattleActorSides"
	battle_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The stage is the row that grows when the window has spare height.
	battle_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_row.add_theme_constant_override("separation", 24)
	_hero_parent.add_child(battle_row)
	_hero_parent.move_child(battle_row, _hero_index)
	_heroes.reparent(battle_row, false)
	_heroes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel = PanelContainer.new()
	panel.name = "EnemyRosterPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = enemies.get_enemies().size() / 3.0
	# Unbox the lineup locally: the shared Theme keeps its framed panel for other screens.
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var rows := HBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)
	for enemy in enemies.get_enemies():
		_admitted_ids.append(enemy.id)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 0)
		rows.add_child(column)
		var puppet := Puppet.new()
		puppet.name = "EnemyPuppet%d" % enemy.position
		puppet.facing = -1.0
		puppet.slot = enemy.position
		puppet.stage_height = STAGE_ACTOR_HEIGHT
		puppet.intent_band = STAGE_INTENT_BAND
		puppet.tag_height = STAGE_TAG_HEIGHT
		puppet.felt = [Color("b78373"), Color("8b9470"), Color("93839e")][enemy.position - 1]
		column.add_child(puppet)
		_puppets.append(puppet)
		# The authoritative target label still covers its whole actor, so aiming anywhere
		# on that enemy selects it; its short name is drawn inside the pinned tag band.
		var label := Label.new()
		label.name = "EnemyState%d" % enemy.position
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.focus_mode = Control.FOCUS_NONE
		# Sewn display lettering on the live stage: the shipped PatchHeading face, kept at
		# the readable 18 px high-contrast ink on the felt tag.
		label.theme_type_variation = NAME_TAG_VARIATION
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 1
		label.custom_minimum_size.x = 0
		label.add_theme_font_size_override("font_size", NAME_TAG_FONT_SIZE)
		# Cream ink with a dark outline stays readable over the pinned tag.
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_outline_color", Color("1a1d20"))
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		puppet.add_child(label)
		_labels.append(label)
		var badge := LiveEnemyIntentBadge.new()
		badge.name = "EnemyIntent%d" % enemy.position
		badge.source_position = enemy.position
		puppet.add_child(badge)
		_badges.append(badge)
		var thorns_tag := _make_thorns_tag(enemy.position)
		puppet.add_child(thorns_tag)
		_thorns_tags.append(thorns_tag)
		var status_tag := _make_status_tag(enemy.position)
		puppet.add_child(status_tag)
		_status_tags.append(status_tag)
		# Refresh current content as well as geometry; a hidden plaque can fit again.
		puppet.resized.connect(_refresh)
	panel.custom_minimum_size.x = 300
	battle_row.add_child(panel)
	# One deterministic stage behind both lineups: the authored scene of this fight when
	# it is available, otherwise the drawn quilt. It is the first child, so it draws
	# before every actor target, HP ribbon, intent badge and hand card.
	backdrop = StageBackdrop.new()
	backdrop.name = "BattleStageBackdrop"
	backdrop.stage_row = battle_row
	backdrop.battle_view = _battle
	_battle.add_child(backdrop)
	_battle.move_child(backdrop, 0)
	_bind_backdrop(app)
	_refresh()


## A short input-inert name Label pinned inside the puppet's bottom tag band.
func _make_name_tag(tag_name: String) -> Label:
	var tag := Label.new()
	tag.name = tag_name
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.focus_mode = Control.FOCUS_NONE
	# The same sewn display lettering as the enemy tags, inside the 26 px pinned band.
	tag.theme_type_variation = NAME_TAG_VARIATION
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.max_lines_visible = 1
	tag.add_theme_font_size_override("font_size", NAME_TAG_FONT_SIZE)
	tag.add_theme_constant_override("outline_size", 6)
	tag.add_theme_color_override("font_outline_color", Color("1a1d20"))
	tag.anchor_left = 0.0
	tag.anchor_top = 1.0
	tag.anchor_right = 1.0
	tag.anchor_bottom = 1.0
	tag.offset_left = 0.0
	tag.offset_right = 0.0
	tag.offset_top = -STAGE_TAG_HEIGHT
	tag.offset_bottom = 0.0
	return tag


## One compact stitched shield-blue label in the heroes' unused intent band.
## It belongs to the mounted actor, never the app-owned HP/Block ribbon or name.
## PASS keeps ordinary battle click/keyboard routing intact while offering hover help.
func _make_warden_reaction_tag(position: int) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.name = "WardenReactions%d" % position
	tag.mouse_filter = Control.MOUSE_FILTER_PASS
	tag.focus_mode = Control.FOCUS_NONE
	var felt := StyleBoxFlat.new()
	felt.bg_color = Color("293d49")
	felt.border_color = Color("c9b996")
	felt.set_border_width_all(1)
	felt.set_corner_radius_all(3)
	felt.content_margin_left = 4.0
	felt.content_margin_right = 4.0
	felt.content_margin_top = 1.0
	felt.content_margin_bottom = 1.0
	tag.add_theme_stylebox_override("panel", felt)
	var caption := Label.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.theme_type_variation = NAME_TAG_VARIATION
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color("fff0d8"))
	caption.add_theme_constant_override("outline_size", 2)
	caption.add_theme_color_override("font_outline_color", Color("171d23"))
	tag.add_child(caption)
	tag.hide()
	return tag


## Place reaction words in the reserved hero intent band, away from the drawn
## actor, its sewn name and the app-owned meter. No additional stage height.
func _place_warden_reaction_tag(puppet: Puppet, tag: PanelContainer) -> void:
	if not tag.visible:
		return
	var band := Rect2(0.0, 0.0, puppet.size.x, puppet.intent_band).intersection(_visible_slot(puppet))
	var extent := tag.get_combined_minimum_size()
	tag.size = extent
	if not band.encloses(Rect2(band.position, extent)):
		tag.hide()
		return
	tag.position = Vector2(band.position.x + (band.size.x - extent.x) * 0.5,
		band.position.y + (band.size.y - extent.y) * 0.5)


## Sewn rust-felt contact-hazard tag, built once per enemy and input-inert. The
## label is a fallback in its own right; no new art or enemy action is needed.
func _make_thorns_tag(position: int) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.name = "EnemyThorns%d" % position
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.focus_mode = Control.FOCUS_NONE
	var felt := StyleBoxFlat.new()
	felt.bg_color = Color("583328")
	felt.border_color = Color("e0aa82")
	felt.set_border_width_all(2)
	felt.set_corner_radius_all(3)
	felt.content_margin_left = 5.0
	felt.content_margin_right = 5.0
	felt.content_margin_top = 2.0
	felt.content_margin_bottom = 2.0
	tag.add_theme_stylebox_override("panel", felt)
	var caption := Button.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.focus_mode = Control.FOCUS_NONE
	caption.flat = true
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("fff0d8"))
	tag.add_child(caption)
	tag.hide()
	return tag


## Within its own puppet art band, below the intent band, above the
## name tag and outside the HP ribbon; target geometry is never changed.
func _place_thorns_tag(puppet: Puppet, tag: PanelContainer, occupied: Array[Rect2]) -> void:
	_place_secondary_tag(puppet, tag, occupied, false)


## A cold blue sewn plaque, distinct from the rusty Thorns hazard and paper intent.
## PASS permits hover help while the stage's existing selection listener still sees clicks.
func _make_status_tag(position: int) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.name = "EnemyStatuses%d" % position
	tag.mouse_filter = Control.MOUSE_FILTER_PASS
	tag.focus_mode = Control.FOCUS_NONE
	var felt := StyleBoxFlat.new()
	felt.bg_color = Color("283c49")
	felt.border_color = Color("a9c8d0")
	felt.set_border_width_all(1)
	felt.set_corner_radius_all(3)
	felt.content_margin_left = 5.0
	felt.content_margin_right = 5.0
	felt.content_margin_top = 2.0
	felt.content_margin_bottom = 2.0
	tag.add_theme_stylebox_override("panel", felt)
	var caption := Label.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.focus_mode = Control.FOCUS_NONE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", Color("f1e9d3"))
	caption.add_theme_constant_override("outline_size", 2)
	caption.add_theme_color_override("font_outline_color", Color("111a25"))
	tag.add_child(caption)
	tag.hide()
	return tag


## Two strictly boolean authored contact passives; the live view separately authenticates
## which current actor record it may pass here. Never coerce a string or a number.
static func _contact_traits(enemy: Dictionary) -> Dictionary:
	var result := {}
	for keyword in ["drain", "bleed_on_attack"]:
		var flag: Variant = enemy.get(keyword, false)
		if flag is bool and flag == true:
			result[keyword] = true
	return result


## All displayed names, stacks and explanatory help come from the same live record.
## A malformed optional field is simply empty; rendering never normalizes gameplay data.
func _status_copy(enemy: Dictionary, contact_traits: Dictionary = {},
		survival_traits: Dictionary = {}) -> Dictionary:
	var source: Variant = enemy.get("statuses", {})
	var visible: Array[String] = []
	var help: Array[String] = []
	var explanations := {
		"bleed": "deals {n} direct HP loss at owner-turn end, then decreases by 1",
		"weak": "outgoing attack damage is reduced by 25%",
		"exposed": "incoming attack damage increases by 50%",
		"tangled": "cannot move or be moved by its own side; adds +2 to attacks with positive base damage for its remaining owner turns",
		"riposte": "returns {n} counterdamage on each confirmed hit; expires at this owner's turn end ({n} is damage, not turn duration)",
	}
	var row: Array[String] = []
	for keyword in STATUS_NAMES:
		if not source is Dictionary:
			break
		var amount: Variant = source.get(keyword)
		if not amount is int or amount <= 0:
			continue
		var title: String = keyword.capitalize()
		row.append("%s %d" % [title, amount])
		help.append("%s %d: %s." % [title, amount,
			String(explanations[keyword]).replace("{n}", str(amount))])
		if row.size() == 2:
			visible.append("  ·  ".join(row))
			row.clear()
	if not row.is_empty():
		visible.append("  ·  ".join(row))
	var stacks := _enrage_stacks(enemy)
	if stacks >= 0:
		visible.append("Enrage %d/3  +%d ATK" % [stacks,
			stacks * CombatEnemyKeywordRules.ENRAGE_ATTACK_BONUS_PER_STACK])
		help.append("Enrage %d/%d: +%d outgoing attack power. Gain one stack per confirmed positive-damage hit (even through Block), max 3; +2 attack per stack before Weak/Exposed, hero Guard and Block." % [
			stacks, CombatEnemyKeywordRules.ENRAGE_MAX_STACKS,
			stacks * CombatEnemyKeywordRules.ENRAGE_ATTACK_BONUS_PER_STACK])
	var passive_row: Array[String] = []
	for keyword in ["drain", "bleed_on_attack"]:
		if contact_traits.get(keyword, false) == true:
			passive_row.append("Drain" if keyword == "drain" else "Bleeding Sting")
			help.append(String(LiveEnemyIntentBadge.CONTACT_HELP[keyword]))
	if not passive_row.is_empty():
		visible.append("  ·  ".join(passive_row))
	if survival_traits.has("revival"):
		var revival: String = survival_traits["revival"]
		visible.append("Revive ready" if revival == "ready" else "Revive spent")
		if revival == "ready":
			help.append("Revive ready: the first lethal HP loss revives this Wraith at %d HP (half max HP, rounded up), in its original slot. Only once." % CombatEnemies.revive_hp(enemy["max_hp"]))
		else:
			help.append("Revive spent: this Wraith has already revived once; its next lethal HP loss is final.")
	if survival_traits.get("split") == true:
		visible.append("Splits if room")
		help.append("Splits if room: only a confirmed paid-card lethal hit can replace this Quilt Termite with two %d-HP Half Quilt Termites, and only while an enemy slot is available (fewer than %d foes). Bleed and the enemy phase do not trigger a split." % [CombatEnemies.revive_hp(enemy["max_hp"]), CombatEnemies.MAX_ENEMIES])
	if visible.is_empty():
		return {}
	return {"caption": "\n".join(visible), "help": "\n".join(help)}


## Survival warnings are never inferred from an ID alone: this is called only
## for a living, ID-matched puppet in the currently mounted authoritative roster.
## Its strings describe the model's latch and post-paid-card staging conditions;
## reading these flags never stages a split or settles HP.
static func _survival_traits(enemy: Dictionary, occupied_slots: int) -> Dictionary:
	var hp: Variant = enemy.get("hp")
	var maximum: Variant = enemy.get("max_hp")
	if not hp is int or not maximum is int or hp <= 0 or maximum <= 0 or hp > maximum:
		return {}
	if enemy.get("id") == "razor_ribbon_wraith" \
			and enemy.get("name") == "Razor Ribbon Wraith" and maximum >= 27 \
			and enemy.get(CombatEnemies.REVIVE_FIELD) is bool \
			and enemy[CombatEnemies.REVIVE_FIELD] == true \
			and CombatEnemies.valid_revive_flags(enemy):
		return {"revival": "ready" if CombatEnemies.revive_pending(enemy) else "spent"}
	if occupied_slots < CombatEnemies.MAX_ENEMIES \
			and enemy.get("id") == CombatEnemies.TERMITE_ID \
			and enemy.get(CombatEnemies.SPLIT_FIELD) is bool \
			and enemy[CombatEnemies.SPLIT_FIELD] == true \
			and CombatEnemies.valid_split_flags(enemy) \
			and CombatEnemies._termite_parent_attack(enemy, int(enemy.get("position", 0))) >= 0:
		return {"split": true}
	return {}


## A validated, source-owned Enrage count, or -1 for absent/invalid metadata.
## An absent count is zero only for the actual true-flagged living enemy.
static func _enrage_stacks(enemy: Dictionary) -> int:
	var hp: Variant = enemy.get("hp")
	if not hp is int or hp <= 0:
		return -1
	var flag: Variant = enemy.get("enrage", false)
	if not flag is bool or not flag:
		return -1
	var count: Variant = enemy.get("enrage_stacks", 0)
	if not count is int or count < 0 or count > CombatEnemyKeywordRules.ENRAGE_MAX_STACKS:
		return -1
	return count


## Read only the literal one-shot enemy Blind token. Invalid/missing metadata is not
## interpreted as a miss; CombatEnemyPhase owns rejection and consumption.
static func _has_attack_blind(enemy: Dictionary) -> bool:
	var statuses: Variant = enemy.get("statuses", {})
	if not statuses is Dictionary:
		return false
	var count: Variant = statuses.get("blind_next_attack", 0)
	return count is int and count == 1


## Derive a strictly read-only Charge presentation context only for an admitted living
## legitimate charge foe with its matching pending state and authentic attack.
static func _charge_context(trusted_source: bool, enemy: Dictionary, action: Dictionary) -> Dictionary:
	if not trusted_source:
		return {}
	if enemy.get("charge", false) != true:
		return {}
	if not CombatEnemyIntents.valid_charge_actor(enemy):
		return {}
	if action.get("type") != "attack":
		return {}
	var base_amount := CombatEnemyIntents.charge_attack_amount(enemy)
	if base_amount <= 0:
		return {}
	var target_pos: Variant = action.get("target_position")
	if not target_pos is int or target_pos < 1 or target_pos > CombatParty.PARTY_SIZE:
		return {}
	var action_amount: Variant = action.get("amount")
	if not action_amount is int or action_amount < 0:
		return {}
	@warning_ignore("integer_division")
	var projected_damage: int = base_amount * 5 / 2
	var has_pending: bool = enemy.has("charge_pending")
	if not has_pending:
		if action_amount != 0:
			return {}
		return {
			"valid": true,
			"state": "wind_up",
			"base_amount": base_amount,
			"projected_damage": projected_damage,
			"target_position": target_pos,
		}
	else:
		var pending: Variant = enemy.get("charge_pending")
		if not pending is Dictionary or pending.size() != 2:
			return {}
		if pending.get("amount") != base_amount:
			return {}
		if pending.get("target_position") != target_pos:
			return {}
		if action_amount != projected_damage:
			return {}
		return {
			"valid": true,
			"state": "strike",
			"base_amount": base_amount,
			"projected_damage": projected_damage,
			"target_position": target_pos,
		}


## Top-right in this puppet's art band, avoiding its separate Thorns and intent
## badges. The plaque stays inside the actor column and never covers the name/HP hem.
func _place_status_tag(puppet: Puppet, tag: PanelContainer, occupied: Array[Rect2]) -> void:
	_place_secondary_tag(puppet, tag, occupied, true)


## All bounds are in the source puppet's coordinates, clipped to the visible viewport.
func _visible_slot(puppet: Puppet) -> Rect2:
	var viewport := puppet.get_global_transform().affine_inverse() * puppet.get_viewport_rect()
	return Rect2(Vector2.ZERO, puppet.size).intersection(viewport)


## Intent owns its seat first. Secondary plaques fit around it and the unposed art;
## none may escape the source slot or cover the pinned name or meters below it.
func _reflow_plaques(puppet: Puppet, badge: LiveEnemyIntentBadge,
		thorns: PanelContainer, status: PanelContainer) -> void:
	_place_intent_ticket(puppet, badge)
	var occupied: Array[Rect2] = [puppet.rest_drawn_rect()]
	if badge.visible:
		occupied.append(badge.get_rect())
	_place_thorns_tag(puppet, thorns, occupied)
	_place_status_tag(puppet, status, occupied)


func _place_secondary_tag(puppet: Puppet, tag: PanelContainer,
		occupied: Array[Rect2], align_right: bool) -> void:
	if not tag.visible:
		return
	var band := puppet.art_band().intersection(_visible_slot(puppet))
	var extent := tag.get_combined_minimum_size()
	# Shrink from the previous content's size as well as growing for new text.
	tag.size = extent
	var xs: Array[float] = [band.position.x + 2.0, band.end.x - extent.x - 2.0]
	if align_right:
		xs.reverse()
	var ys: Array[float] = [band.position.y + 3.0]
	for rect in occupied:
		xs.append(rect.position.x - extent.x - 3.0)
		xs.append(rect.end.x + 3.0)
		ys.append(rect.end.y + 3.0)
		ys.append(rect.position.y - extent.y - 3.0)
	for y in ys:
		for x in xs:
			var candidate := Rect2(Vector2(x, y), extent)
			if not band.has_area() or not band.encloses(candidate):
				continue
			var clear := true
			for rect in occupied:
				if candidate.intersects(rect.grow(2.0)):
					clear = false
					break
			if clear:
				tag.position = candidate.position
				occupied.append(candidate)
				return
	tag.hide()


func _refresh() -> void:
	if enemies == null or not is_instance_valid(panel):
		return
	var roster := enemies.get_enemies()
	var announcements: Dictionary = {}
	var app = get_parent()
	var unravel := _bound_unravel(app)
	var reactions := _bound_reactions(app)
	if is_instance_valid(app.intent_label):
		app.intent_label.hide()
	for puppet in _puppets:
		if not is_instance_valid(puppet):
			continue
		puppet.fallen = app.party.is_downed(puppet.slot) if puppet.facing > 0 else enemies.is_slain(puppet.slot)
		_bind_puppet_art(app, puppet)
		puppet.queue_redraw()
	for index in range(_hero_tags.size()):
		var hero: Dictionary = app.party.get_hero(index + 1)
		_hero_tags[index].text = String(hero.get("name", "")) if hero.get("name") is String else ""
		var reaction_tag := _hero_reaction_tags[index]
		var cue := reaction_tag.get_node("Caption") as Label
		var warden_here: bool = hero.get("id") == "warden" and hero.get("hp") is int \
			and hero["hp"] > 0 and not app.party.is_downed(index + 1) \
			and _battle == app.battle_view and _heroes == app.hero_view
		var names: Array[String] = []
		var help: Array[String] = []
		if warden_here and reactions != null:
			if reactions.is_guarding():
				names.append("GUARD")
				help.append("Guard: enemy attacks aimed at another living hero redirect to this living Warden, then normal Block and HP apply. An already downed announced target is skipped, not redirected.")
			if reactions.get_thorns() > 0:
				names.append("THORNS %d" % reactions.get_thorns())
				help.append("Counter-stitch Thorns %d: retaliates once when an enemy attack genuinely lands on Warden (including a Guard redirect). Missed, skipped or other-hero attacks do not trigger retaliation. Expires at the next player turn." % reactions.get_thorns())
		cue.add_theme_font_size_override("font_size", 12 if names.size() > 1 else 14)
		cue.text = "\n".join(names)
		reaction_tag.tooltip_text = "\n".join(help)
		reaction_tag.visible = not names.is_empty()
		_place_warden_reaction_tag(_puppets[index] as Puppet, reaction_tag)
	if app.enemy_intents != null:
		for action in app.enemy_intents.get_intents():
			announcements[action["enemy_position"]] = action
	for index in range(_labels.size()):
		var enemy: Dictionary = roster[index]
		var position: int = enemy["position"]
		# Short pinned name tag; the meter and the SLAIN badge own HP/Block/death readouts.
		_labels[index].text = String(enemy["name"]) if enemy.get("name") is String else ""
		var tag := _thorns_tags[index]
		var amount = enemy.get("thorns", 0)
		var show_hazard: bool = position == index + 1 and enemy.get("hp") is int \
			and enemy["hp"] > 0 and amount is int and amount > 0 \
			and enemies == app.enemies and _battle == app.battle_view
		var caption := tag.get_node("Caption") as Button
		caption.text = "Thorns %d" % amount if show_hazard else ""
		tag.visible = show_hazard
		var badge := _badges[index]
		var action: Dictionary = announcements.get(position, {})
		var live_source: bool = position == index + 1 and enemy.get("hp") is int \
			and enemy["hp"] > 0 and enemies == app.enemies and _battle == app.battle_view \
			and roster.size() == _badges.size() and badge.source_position == position \
			and action.get("enemy_position") == position
		# Contact passives are allowed only from this current admitted battle flow,
		# its weighted scheduler and the puppet bound to the same actual actor ID.
		# A stale slot, replaced roster, closed fight or unbound preview gets no trait.
		var puppet := _puppets[CombatParty.PARTY_SIZE + index] as Puppet
		var trusted_source: bool = live_source \
			and app.enemy_intents != null and app.enemy_intents.is_bound() \
			and app.enemy_intents._enemies == enemies \
			and enemy.get("id") is String and not String(enemy["id"]).is_empty() \
			and puppet.actor_id == enemy["id"] \
			and _admitted_ids.size() == roster.size() \
			and _admitted_ids[index] == enemy["id"]
		# Unravelled's optional service is required for contact cues, but a
		# real mounted Blind token must remain visible when that service is absent.
		var trusted_contact: bool = trusted_source and unravel != null
		var contact_traits: Dictionary = _contact_traits(enemy) if trusted_contact else {}
		var trusted_survival: bool = position == index + 1 and enemy.get("hp") is int \
			and enemy["hp"] > 0 and enemies == app.enemies and _battle == app.battle_view \
			and roster.size() == _status_tags.size() \
			and _admitted_ids.size() == roster.size() \
			and enemy.get("id") is String and _admitted_ids[index] == enemy["id"] \
			and puppet.actor_id == enemy["id"]
		var survival_traits: Dictionary = _survival_traits(enemy, roster.size()) if trusted_survival else {}
		var status_tag := _status_tags[index]
		var status_copy: Dictionary = _status_copy(enemy, contact_traits, survival_traits) if show_hazard or (
			position == index + 1 and enemy.get("hp") is int and enemy["hp"] > 0
			and enemies == app.enemies and _battle == app.battle_view) else {}
		var status_label := status_tag.get_node("Caption") as Label
		status_label.text = String(status_copy.get("caption", ""))
		status_tag.tooltip_text = String(status_copy.get("help", ""))
		status_tag.visible = not status_copy.is_empty()
		var pending := false
		if unravel != null and not enemies.is_slain(position):
			pending = unravel.get_snapshot(position).get("skip_pending", false)
		# Target policy and full action wording are unchanged by a contact passive.
		var policy := ""
		if live_source and unravel != null and app.enemy_intents != null \
				and app.enemy_intents.is_bound():
			policy = CombatEnemyIntents.policy_for(enemies, position)
		var enrage_stacks := _enrage_stacks(enemy) if live_source else -1
		# Blind belongs to this exact living source, not another occupant of its
		# slot or a stale cached announcement. This read cannot consume the token.
		var attack_blind := trusted_source and _has_attack_blind(enemy)
		var charge_context := _charge_context(trusted_source, enemy, action)
		badge.show_intent(action, enemies.is_slain(position), pending, policy,
			enrage_stacks, contact_traits, attack_blind, charge_context)
		# Only a live, source-owned, already-announced attack can preview an actual
		# redirect. Keep the printed target, amount and policy ticket untouched.
		if reactions != null and live_source and not pending and not badge.blind_miss and badge.charge_state != "wind_up" \
				and app.enemy_intents != null and app.enemy_intents.is_bound() \
				and app.enemy_intents._enemies == enemies \
				and _admitted_ids.size() == roster.size() \
				and _admitted_ids[index] == enemy.get("id") and puppet.actor_id == enemy.get("id") \
				and action.get("type") == "attack" and badge.intent_type == "attack":
			var announced: Variant = action.get("target_position")
			if announced is int and announced >= 1 and announced <= CombatParty.PARTY_SIZE:
				var recipient: Dictionary = reactions.preview_actual_recipient(app.party, announced)
				if recipient.get("ok") == true and recipient.get("eligible") == true \
						and recipient.get("redirected") == true:
					var actual: int = recipient.get("actual_target_position", 0)
					if actual >= 1 and actual <= CombatParty.PARTY_SIZE \
							and app.party.get_hero(actual).get("id") == "warden":
						badge.tooltip_text += "\nGuard → Warden (hero %d): this announced attack is redirected from hero %d; normal Block/HP apply." % [actual, announced]
		_reflow_plaques(puppet, badge, tag, status_tag)


## Presentation only: seat one already-mounted ticket on its own source's resting artwork.
## Never use posed bounds, attack textures or transient transforms, so a lunge, recoil or
## fall never drags the ticket. The whole ticket stays inside its source column and inside
## the viewport; when the safe gap cannot fit, hide it instead of overlapping the actor.
func _place_intent_ticket(puppet: Puppet, badge: LiveEnemyIntentBadge) -> void:
	if not is_instance_valid(puppet) or not is_instance_valid(badge):
		return
	var art := puppet.rest_drawn_rect()
	# Before the container lays the column out (or while the source is off-screen) there is
	# no resting art to pin to: hide the ticket for that frame instead of drawing it loose.
	var viewport := puppet.get_global_transform().affine_inverse() * puppet.get_viewport_rect()
	var slot := _visible_slot(puppet).intersection(
		Rect2(0.0, 0.0, puppet.size.x, puppet.tag_band().position.y))
	var top := maxf(slot.position.y, viewport.position.y + STAGE_INTENT_SAFE_MARGIN)
	var height := badge.custom_minimum_size.y
	# The small seam gap must cover the resting actor's full bob/breathing envelope;
	# the silhouette rim is only a drawn outline, not another animation offset.
	var clearance := maxf(INTENT_ART_CLEARANCE, puppet.art_safety_inset())
	badge.visible = art.has_area() and slot.has_area() \
		and slot.size.x >= badge.custom_minimum_size.x \
		and art.position.y - clearance - height >= top \
		and slot.end.y - top >= height
	if not badge.visible:
		return
	var width := maxf(badge.custom_minimum_size.x, slot.size.x)
	# Centre the ticket on its own resting art; the no-room check above makes
	# the vertical placement exact and prevents top clamping onto the actor.
	var left := slot.position.x
	var right := maxf(left, slot.end.x - width)
	badge.position = Vector2(clampf(art.get_center().x - width * 0.5, left, right),
		art.position.y - clearance - height)
	badge.size = Vector2(width, height)


## Only the admission-owned service of the active, still-identical fight is readable.
## Neither the stage nor its badges may synthesize a replacement gauge.
func _bound_unravel(app) -> CombatUnravel:
	if app._battle_closed or app.deck == null or app.party == null or app.enemies == null \
			or app.enemy_intents == null or app.battle_result == null:
		return null
	var flow: CombatRoundFlow = app.round_flow
	if flow == null or not is_instance_valid(flow) or not flow._started \
			or flow._deck != app.deck or flow._party != app.party \
			or flow._enemies != app.enemies or flow._intents != app.enemy_intents \
			or flow._result != app.battle_result \
			or flow._battle_deck != app.deck or flow._battle_party != app.party \
			or flow._battle_enemies != app.enemies or flow._battle_intents != app.enemy_intents \
			or flow._battle_result != app.battle_result:
		return null
	var service: CombatUnravel = flow._unravel
	if service == null or not is_instance_valid(service) \
			or service._bound_enemies != app.enemies or not flow._valid_unravel_binding():
		return null
	return service


## Only the admitted current round flow owns the live reaction service.
## Use the same immutable deck/party/enemy/intent/result identity gates as
## _bound_unravel: no fallback service, copied flag or hero.statuses proxy.
func _bound_reactions(app) -> CombatWardenGuardReactions:
	if app._battle_closed or app.deck == null or app.party == null or app.enemies == null \
			or app.enemy_intents == null or app.battle_result == null \
			or not is_instance_valid(_battle) or _battle != app.battle_view \
			or enemies != app.enemies or _heroes != app.hero_view:
		return null
	var flow: CombatRoundFlow = app.round_flow
	if flow == null or not is_instance_valid(flow) or not flow._started \
			or flow._deck != app.deck or flow._party != app.party \
			or flow._enemies != app.enemies or flow._intents != app.enemy_intents \
			or flow._result != app.battle_result \
			or flow._battle_deck != app.deck or flow._battle_party != app.party \
			or flow._battle_enemies != app.enemies or flow._battle_intents != app.enemy_intents \
			or flow._battle_result != app.battle_result \
			or app.battle_result._party != app.party or app.battle_result._enemies != app.enemies \
			or not app.battle_result.can_continue():
		return null
	var service: CombatWardenGuardReactions = flow._reactions
	if service == null or not is_instance_valid(service) \
			or not flow._valid_reactions_binding() or not service.is_patch_binding_valid():
		return null
	return service


## Presentation-only resolution: the live actor ID chooses the stand-in resources, fail-closed.
func art_for(actor_id: String) -> Dictionary:
	if not ACTOR_ART.has(actor_id):
		return {}
	if _art_cache.has(actor_id):
		return _art_cache[actor_id]
	var paths: Dictionary = art_paths(actor_id)
	var art := {"idle": _load_art_texture(String(paths.get("idle", ""))),
		"attack": _load_art_texture(String(paths.get("attack", ""))),
		"idle_loop": _load_art_texture(String(paths.get("idle_loop", ""))),
		"attack_loop": _load_art_texture(String(paths.get("attack_loop", ""))),
		"hit_loop": _load_art_texture(String(paths.get("hit_loop", ""))),
		"death_loop": _load_art_texture(String(paths.get("death_loop", "")))}
	_art_cache[actor_id] = art
	return art


## Follows the authoritative ID at each slot, so a legal position swap also swaps the images.
func _bind_puppet_art(app, puppet) -> void:
	var definition: Dictionary = {}
	if puppet.facing > 0.0:
		if app.party != null:
			definition = app.party.get_hero(puppet.slot)
	elif enemies != null:
		definition = enemies.get_enemy(puppet.slot)
	var actor_id: String = definition.get("id") if definition.get("id") is String else ""
	if actor_id == puppet.actor_id:
		return
	puppet.bind_actor(actor_id, art_for(actor_id))


## The one mounted, still-standing and visible hero puppet bound to this authoritative
## actor ID. Identity comes from the bound ID, never from a slot or a screen position;
## a missing or duplicated owner resolves nothing, so presentation never invents a source.
func hero_puppet(actor_id: String) -> Control:
	return puppet_for("hero", actor_id)


## The one mounted puppet of `side` bound to this authoritative actor ID, for a hit
## reaction that must never land on the wrong actor. Identity comes from the bound side and
## ID, never from a slot or a screen position; an unknown side, a stale ID or an ambiguous
## duplicate binding resolves nothing.
func puppet_for(side: String, actor_id: String) -> Control:
	return _bound_puppet(side, actor_id, true)


## The one mounted, still visible puppet of `side` bound to this authoritative actor ID,
## including one that is already fallen because of the very hit being presented. This is a
## presentation-only identity lookup: it never admits a fallen actor for targeting or any
## gameplay rule, which keep puppet_for()'s standing-only contract, and it fails closed for
## an unknown side, a stale ID or an ambiguous duplicate binding.
func presented_puppet(side: String, actor_id: String) -> Control:
	return _bound_puppet(side, actor_id, false)


## Eases the one mounted puppet of this authoritative actor into its existing fallen pose
## after a witnessed living-to-zero HP transition. `fallen` itself is already authoritative,
## so the lookup deliberately includes fallen puppets; it still fails closed for an unknown
## side, a stale ID or an ambiguous duplicate binding.
func settle_fall(side: String, actor_id: String, seconds: float) -> bool:
	var puppet := _bound_puppet(side, actor_id, false)
	if puppet == null:
		return false
	return puppet.settle_fall(seconds)


## The one mounted, still visible puppet of `side` bound to this authoritative actor ID.
## `standing_only` keeps the fail-closed targeting rule; a fall reaction passes false.
func _bound_puppet(side: String, actor_id: String, standing_only: bool) -> Control:
	if actor_id.is_empty() or (side != "hero" and side != "enemy"):
		return null
	var face := 1.0 if side == "hero" else -1.0
	var found: Control = null
	for puppet in _puppets:
		if not is_instance_valid(puppet) or not is_equal_approx(puppet.facing, face):
			continue
		if standing_only and puppet.fallen:
			continue
		if puppet.actor_id != actor_id:
			continue
		if found != null:
			return null
		found = puppet
	if found == null or not found.is_inside_tree() or not found.is_visible_in_tree():
		return null
	return found


## Ends every in-flight committed attack pose, hit recoil and fall settle (battle teardown
## or a rebind), so no mounted actor is left mid-lunge, mid-shake or mid-fall and the
## artwork returns exactly to its own rest or fallen pose.
func cancel_poses() -> void:
	for puppet in _puppets:
		if is_instance_valid(puppet):
			puppet.cancel_attack()
			puppet.cancel_recoil()
			puppet.cancel_fall()


## The admitted battle's own route kind. Only a standalone _start_battle (no run map at
## all) is the normal Fight stage; a missing or malformed node stays unknown, so it keeps
## the drawn quilt instead of borrowing another scene.
func _battle_kind(app) -> String:
	if app == null or app.run_map == null:
		return STANDALONE_BATTLE_KIND
	var current: String = app.run_map.get_current_node_id()
	if current.is_empty():
		return ""
	var node = app.run_map.get_node(current)
	if not node is Dictionary:
		return ""
	var kind = node.get("type")
	if not kind is String or not BATTLE_BACKDROPS.has(kind):
		return ""
	return kind


## Binds this battle's single stage to exactly the scene its admitted kind and, for a
## routed Fight, its node floor select.
func _bind_backdrop(app) -> void:
	_backdrop_kind = _battle_kind(app)
	_backdrop_floor = _battle_floor(app)
	_backdrop_key = stage_key(_backdrop_kind, _backdrop_floor)
	if is_instance_valid(backdrop) and backdrop is StageBackdrop:
		backdrop.bind_battle(_backdrop_kind,
			stage_texture(stage_backdrop_path(_backdrop_kind, _backdrop_floor)))
	var light := stage_light(_backdrop_kind, _backdrop_floor)
	for puppet in _puppets:
		if is_instance_valid(puppet) and puppet is Puppet:
			puppet.set_stage_light(light)


## The admitted node's own integer floor. A standalone battle has no map and reports the
## standalone floor; a routed node with a missing or malformed floor stays invalid, so it
## keeps the drawn quilt instead of borrowing another area's scene.
func _battle_floor(app) -> int:
	if app == null or app.run_map == null:
		return STANDALONE_FLOOR
	var current: String = app.run_map.get_current_node_id()
	if current.is_empty():
		return INVALID_FLOOR
	var node = app.run_map.get_node(current)
	if not node is Dictionary:
		return INVALID_FLOOR
	var floor_number = node.get("floor")
	if not floor_number is int or int(floor_number) < 1:
		return INVALID_FLOOR
	return int(floor_number)


## Presentation-only scene lookup for one kind; a standalone kind selects its own scene.
func backdrop_texture(kind: String) -> Texture2D:
	return stage_texture(stage_backdrop_path(kind, STANDALONE_FLOOR))


## Cached presentation-only lookup for one exact authored path; an empty path or missing
## file loads nothing.
func stage_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not _backdrop_cache.has(path):
		_backdrop_cache[path] = _load_art_texture(path)
	return _backdrop_cache[path] as Texture2D


static func _load_art_texture(path: String) -> Texture2D:
	# A missing import or file keeps the drawn fallback instead of failing boot.
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


func _clear() -> void:
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	# A closed or replaced battle never keeps a mounted actor mid-lunge or mid-shake.
	cancel_poses()
	# Return the app-owned controls before disposing of our temporary container.
	if is_instance_valid(_heroes) and is_instance_valid(_hero_parent):
		if _heroes.get_parent() != _hero_parent:
			_heroes.reparent(_hero_parent, false)
		_hero_parent.move_child(_heroes, mini(_hero_index, _hero_parent.get_child_count() - 1))
		_heroes.size_flags_horizontal = _hero_flags
	_heroes = null
	_hero_parent = null
	for label in _hero_fonts:
		if is_instance_valid(label):
			label.add_theme_font_size_override("font_size", _hero_fonts[label])
			label.show()
	_hero_fonts.clear()
	for puppet in _puppets:
		if is_instance_valid(puppet):
			puppet.get_parent().remove_child(puppet)
			puppet.queue_free()
	_puppets.clear()
	if is_instance_valid(_battle) and is_instance_valid(get_parent().intent_label):
		get_parent().intent_label.visible = _intent_visible
	enemies = null
	_labels.clear()
	_hero_tags.clear()
	_hero_reaction_tags.clear()
	_badges.clear()
	_thorns_tags.clear()
	_status_tags.clear()
	_admitted_ids.clear()
	if is_instance_valid(panel):
		if panel.get_parent() != null:
			panel.get_parent().remove_child(panel)
		panel.queue_free()
	panel = null
	if is_instance_valid(battle_row):
		if battle_row.get_parent() != null:
			battle_row.get_parent().remove_child(battle_row)
		battle_row.queue_free()
	battle_row = null
	# The stage belongs to this battle only; a later fight builds a fresh one.
	if is_instance_valid(backdrop):
		if backdrop.get_parent() != null:
			backdrop.get_parent().remove_child(backdrop)
		backdrop.queue_free()
	backdrop = null
	_backdrop_kind = ""
	_backdrop_floor = STANDALONE_FLOOR
	_backdrop_key = ""
	_battle = null
