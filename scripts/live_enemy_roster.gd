extends Node
## Observes the app's authoritative roster; owns only presentation, never combat actions.

## Owner-supplied stand-in art, keyed by authoritative actor ID (never name, slot or screen text).
## Each base path has a matching "_attack" pose that only a committed animation event may show.
const ART_ROOT := "res://assets/paper/"
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


## Exact stand-in image paths for one authoritative actor ID; empty when no art is mapped.
static func art_paths(actor_id: String) -> Dictionary:
	if not ACTOR_ART.has(actor_id):
		return {}
	var base: String = ART_ROOT + String(ACTOR_ART[actor_id])
	return {"idle": base + ".png", "attack": base + "_attack.png"}


class Puppet extends Control:
	const TAG_FELT := Color("2f2a25")
	const TAG_THREAD := Color("c9b996")

	var facing := 1.0
	var slot := 1
	var fallen := false
	var felt := Color("719796")
	var actor_id := ""
	var idle_texture: Texture2D
	## Held for the future committed attack event; nothing may switch to it yet.
	var attack_texture: Texture2D
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

	## Binds one authoritative actor ID and its loaded art; a missing texture keeps the fallback.
	func bind_actor(id: String, art: Dictionary) -> void:
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

	## Uniform, aspect-preserving placement inside this input-inert Control.
	func image_rect() -> Rect2:
		var texture := current_texture()
		var band := art_band()
		if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0 \
				or band.size.x <= 0.0 or band.size.y <= 0.0:
			return Rect2()
		var fit := minf(band.size.x / float(texture.get_width()), band.size.y / float(texture.get_height()))
		var drawn := Vector2(texture.get_width(), texture.get_height()) * fit
		return Rect2(band.position + (band.size - drawn) / 2.0, drawn)

	func _draw() -> void:
		var texture := current_texture()
		if texture != null:
			_draw_actor(texture)
		else:
			_draw_fallback()
		_draw_tag()

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

	func _draw_actor(texture: Texture2D) -> void:
		var rect := image_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return
		# Heroes face right, enemies left; the fallen actor keeps the drawn tilt treatment.
		draw_set_transform(rect.get_center(), -0.7 * facing if fallen else 0.0, Vector2(facing, 1.0))
		draw_texture_rect(texture, Rect2(-rect.size / 2.0, rect.size), false,
			Color("8c8b86") if fallen else Color.WHITE)
		draw_set_transform(Vector2.ZERO)

	func _draw_fallback() -> void:
		var ink := Color("ecdfbd")
		var band := art_band()
		if band.size.x <= 0.0 or band.size.y <= 0.0:
			return
		var puppet_scale := clampf(band.size.y / 130.0, 0.45, 1.8)
		draw_set_transform(Vector2(size.x / 2, band.position.y + band.size.y / 2),
			-0.7 * facing if fallen else 0.0, Vector2(facing, 1) * puppet_scale)
		var cloth := felt.darkened(0.4) if fallen else felt
		var body := PackedVector2Array([Vector2(-20, -13), Vector2(14, -15), Vector2(25, 25), Vector2(-26, 28)])
		draw_colored_polygon(body, cloth)
		draw_polyline(body + PackedVector2Array([body[0]]), ink, 1.5, true)
		draw_dashed_line(Vector2(-16, -8), Vector2(-21, 22), ink, 1, 4)
		draw_line(Vector2(-11, 26), Vector2(-16, 39), cloth, 9)
		draw_line(Vector2(12, 25), Vector2(20, 38), cloth, 9)
		draw_line(Vector2(13, -4), Vector2(34, 8), cloth, 9)
		draw_circle(Vector2(0, -27), 16, Color("c9b996") if not fallen else Color("777a76"))
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
		draw_set_transform(Vector2.ZERO)


## Deterministic quilt stage drawn behind the actor row: one continuous cloth seamed
## into axis-aligned patches, plus a stitched hem for the ground. Presentation only,
## so it never takes pointer or keyboard input.
class StageBackdrop extends Control:
	var stage_row: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)
		if is_instance_valid(stage_row):
			stage_row.item_rect_changed.connect(queue_redraw)

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
		# A single hem of cross-thread stitches marks the ground the actors stand on.
		var hem := Rect2(cloth.position.x, cloth.end.y, cloth.size.x, STAGE_HEM_HEIGHT)
		draw_rect(hem, STAGE_HEM)
		draw_dashed_line(Vector2(hem.position.x + 10.0, hem.position.y),
			Vector2(hem.end.x - 10.0, hem.position.y), STAGE_THREAD, 2.0, 9.0)
		var x := hem.position.x + 18.0
		while x < hem.end.x - 12.0:
			draw_line(Vector2(x, hem.position.y + 3.0), Vector2(x + 7.0, hem.end.y - 3.0),
				STAGE_THREAD, 1.5, true)
			x += 26.0


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
	# One deterministic quilt stage behind both lineups, drawn before any actor.
	backdrop = StageBackdrop.new()
	backdrop.name = "BattleStageBackdrop"
	backdrop.stage_row = battle_row
	_battle.add_child(backdrop)
	_battle.move_child(backdrop, 0)
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


static func _load_art_texture(path: String) -> Texture2D:
	# A missing import or file keeps the drawn fallback instead of failing boot.
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


func _clear() -> void:
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
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
	# The quilt stage belongs to this battle only; a later fight builds a fresh one.
	if is_instance_valid(backdrop):
		if backdrop.get_parent() != null:
			backdrop.get_parent().remove_child(backdrop)
		backdrop.queue_free()
	backdrop = null
	_battle = null
