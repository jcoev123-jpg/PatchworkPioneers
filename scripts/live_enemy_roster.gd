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

var enemies: CombatEnemies
var panel: PanelContainer
var _battle: Control
var _labels: Array[Label] = []
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
	var facing := 1.0
	var slot := 1
	var fallen := false
	var felt := Color("719796")
	var actor_id := ""
	var idle_texture: Texture2D
	## Held for the future committed attack event; nothing may switch to it yet.
	var attack_texture: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Enemies keep the badge row and terminal labels inside 1280x720; heroes fill their panel.
		custom_minimum_size = Vector2(0, 96 if facing > 0.0 else 42)
		resized.connect(queue_redraw)

	## Binds one authoritative actor ID and its loaded art; a missing texture keeps the fallback.
	func bind_actor(id: String, art: Dictionary) -> void:
		actor_id = id
		idle_texture = art.get("idle") as Texture2D
		attack_texture = art.get("attack") as Texture2D
		queue_redraw()

	func current_texture() -> Texture2D:
		return idle_texture

	## Uniform, aspect-preserving placement inside this input-inert Control.
	func image_rect() -> Rect2:
		var texture := current_texture()
		if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
			return Rect2()
		var fit := minf(size.x / float(texture.get_width()), size.y / float(texture.get_height()))
		var drawn := Vector2(texture.get_width(), texture.get_height()) * fit
		return Rect2((size - drawn) / 2.0, drawn)

	func _draw() -> void:
		var texture := current_texture()
		if texture != null:
			_draw_actor(texture)
			return
		_draw_fallback()

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
		var puppet_scale := clampf((size.y - 6.0) / 80.0, 0.45, 1.2)
		draw_set_transform(Vector2(size.x / 2, size.y / 2), -0.7 * facing if fallen else 0.0, Vector2(facing, 1) * puppet_scale)
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
			and is_instance_valid(battle_row) and is_instance_valid(panel):
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
		puppet.felt = [Color("719796"), Color("93839e"), Color("b49a55")][puppet.slot - 1]
		hero_panel.add_child(puppet)
		_puppets.append(puppet)
	battle_row = HBoxContainer.new()
	battle_row.name = "BattleActorSides"
	battle_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var rows := HBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)
	for enemy in enemies.get_enemies():
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 2)
		rows.add_child(column)
		var label := Label.new()
		label.name = "EnemyState%d" % enemy.position
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# The separate SLAIN badge already announces a fallen source; capping the label at two
		# lines keeps a three-enemy roster inside 1280x720 without changing its full text.
		label.max_lines_visible = 2
		label.custom_minimum_size.x = 0
		label.add_theme_font_size_override("font_size", 18)
		column.add_child(label)
		_labels.append(label)
		var puppet := Puppet.new()
		puppet.name = "EnemyPuppet%d" % enemy.position
		puppet.facing = -1.0
		puppet.slot = enemy.position
		puppet.felt = [Color("b78373"), Color("8b9470"), Color("93839e")][enemy.position - 1]
		column.add_child(puppet)
		_puppets.append(puppet)
		var badge := LiveEnemyIntentBadge.new()
		badge.name = "EnemyIntent%d" % enemy.position
		badge.source_position = enemy.position
		column.add_child(badge)
		_badges.append(badge)
	panel.custom_minimum_size.x = 300
	battle_row.add_child(panel)
	_refresh()


func _refresh() -> void:
	if enemies == null or not is_instance_valid(panel):
		return
	var roster := enemies.get_enemies()
	var announcements: Dictionary = {}
	var app = get_parent()
	if is_instance_valid(app.intent_label):
		app.intent_label.hide()
	for puppet in _puppets:
		if not is_instance_valid(puppet):
			continue
		puppet.fallen = app.party.is_downed(puppet.slot) if puppet.facing > 0 else enemies.is_slain(puppet.slot)
		_bind_puppet_art(app, puppet)
		puppet.queue_redraw()
	if app.enemy_intents != null:
		for action in app.enemy_intents.get_intents():
			announcements[action["enemy_position"]] = action
	for index in range(_labels.size()):
		var enemy: Dictionary = roster[index]
		var position: int = enemy["position"]
		_labels[index].text = "Enemy %d - %s%s" % [position, enemy["name"],
			"\nSLAIN" if enemies.is_slain(position) else ""]
		_badges[index].show_intent(announcements.get(position, {}), enemies.is_slain(position))


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
	_battle = null
