extends Node
## Observes the app's authoritative roster; owns only presentation, never combat actions.

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


class Puppet extends Control:
	var facing := 1.0
	var slot := 1
	var fallen := false
	var felt := Color("719796")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 40)
		resized.connect(queue_redraw)

	func _draw() -> void:
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
