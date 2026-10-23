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
	"ragling": "enemies/ragling",
	"ragling_guard": "enemies/ragling_guard",
	"fray_scavenger": "enemies/fray_scavenger",
	"button_guard": "enemies/button_guard",
	"spool_stalker": "enemies/spool_stalker",
	"seam_ripper": "enemies/seam_ripper",
	"needle_marshal": "enemies/needle_marshal",
	"spool_hexer": "enemies/spool_hexer",
	"patchwork_behemoth": "boss/patchwork_behemoth",
}

## One large stage for both sides: heroes and enemies share this minimum actor height,
## so neither lineup is drawn smaller than the other.
const STAGE_ACTOR_HEIGHT := 180
## Band above the art on both sides: enemies keep their intent badge there, heroes keep
## the same empty band so the two lineups render their art at identical scale.
const STAGE_INTENT_BAND := 36.0
## Viewport-safe gap between the stage's upper edge and every intent badge, so the whole
## stitched patch reads as pinned inside 1280x720 instead of hanging off the top edge.
const STAGE_INTENT_SAFE_MARGIN := 8.0
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
var _badges: Array[LiveEnemyIntentBadge] = []
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
	return {"idle": base + ".png", "attack": base + "_attack.png"}


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
	## The drawn fallback's own local extents before the pose transform: body, head, legs
	## and the slot-specific sewn prop, including stroke width.
	const FALLBACK_EXTENTS := Rect2(-26.0, -43.0, 73.0, 85.5)
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

	var facing := 1.0
	var slot := 1
	var fallen := false
	var felt := Color("719796")
	var actor_id := ""
	## Seconds of idle presentation this instance has run. A fresh puppet starts at rest.
	var idle_phase := 0.0
	var idle_texture: Texture2D
	## Authored attack pose, drawn only while this actor performs its own committed hit.
	var attack_texture: Texture2D
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
		if not fallen:
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
		idle_texture = art.get("idle") as Texture2D
		attack_texture = art.get("attack") as Texture2D
		queue_redraw()

	func current_texture() -> Texture2D:
		return idle_texture

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
		var fit := minf(fit_band.size.x / float(texture.get_width()), fit_band.size.y / float(texture.get_height()))
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
			var grown := rect.size + Vector2(RIM_RADIUS, RIM_RADIUS) * 2.0
			draw_set_transform_matrix(idle_transform(rect.get_center() - Vector2(0.0, RIM_RADIUS), 1.0))
			draw_texture_rect(texture, Rect2(-grown / 2.0, grown), false, Color(RIM_INK, RIM_ALPHA))
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
		# Heroes face right, enemies left; the fallen actor keeps the drawn tilt treatment.
		draw_set_transform_matrix(idle_transform(rect.get_center(), 1.0))
		draw_texture_rect(texture, Rect2(-rect.size / 2.0, rect.size), false,
			Color("8c8b86") if fallen else Color.WHITE)
		draw_set_transform(Vector2.ZERO)

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
			and is_instance_valid(battle_row) and is_instance_valid(panel) and is_instance_valid(backdrop):
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
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 1
		label.custom_minimum_size.x = 0
		label.add_theme_font_size_override("font_size", 16)
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
		# Intent stays above the enemy actor but below the viewport's upper edge, inside
		# the shared stage band: the patch never touches the screen edge or the art.
		badge.anchor_right = 1.0
		badge.offset_left = 0.0
		badge.offset_right = 0.0
		badge.offset_top = STAGE_INTENT_SAFE_MARGIN
		badge.offset_bottom = STAGE_INTENT_BAND
		_badges.append(badge)
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
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.max_lines_visible = 1
	tag.add_theme_font_size_override("font_size", 16)
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


func _refresh() -> void:
	if enemies == null or not is_instance_valid(panel):
		return
	var roster := enemies.get_enemies()
	var announcements: Dictionary = {}
	var app = get_parent()
	var unravel := _bound_unravel(app)
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
	if app.enemy_intents != null:
		for action in app.enemy_intents.get_intents():
			announcements[action["enemy_position"]] = action
	for index in range(_labels.size()):
		var enemy: Dictionary = roster[index]
		var position: int = enemy["position"]
		# Short pinned name tag; the meter and the SLAIN badge own HP/Block/death readouts.
		_labels[index].text = String(enemy["name"]) if enemy.get("name") is String else ""
		var pending := false
		if unravel != null and not enemies.is_slain(position):
			pending = unravel.get_snapshot(position).get("skip_pending", false)
		_badges[index].show_intent(announcements.get(position, {}), enemies.is_slain(position), pending)


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


## Presentation-only resolution: the live actor ID chooses the stand-in resources, fail-closed.
func art_for(actor_id: String) -> Dictionary:
	if not ACTOR_ART.has(actor_id):
		return {}
	if _art_cache.has(actor_id):
		return _art_cache[actor_id]
	var paths: Dictionary = art_paths(actor_id)
	var art := {"idle": _load_art_texture(String(paths.get("idle", ""))),
		"attack": _load_art_texture(String(paths.get("attack", "")))}
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
	_badges.clear()
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
