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


func _ready() -> void:
	# The parent connects its Start Run handler after child _ready, so observe deferred.
	get_parent().start_run_requested.connect(_sync_battle, CONNECT_DEFERRED)


func _process(_delta: float) -> void:
	_sync_battle()
	_refresh()


func _sync_battle() -> void:
	var app = get_parent()
	if app.deck == null or app.enemies == null or not is_instance_valid(app.battle_view) \
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
	for hero_panel in app.hero_panels:
		var label := hero_panel.get_child(0) as Label
		_hero_fonts[label] = label.get_theme_font_size("font_size")
		label.add_theme_font_size_override("font_size", 18)
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
	var rows := HBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)
	for enemy in enemies.get_enemies():
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 2)
		rows.add_child(column)
		var label := Label.new()
		label.name = "EnemyState%d" % enemy.position
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		column.add_child(label)
		_labels.append(label)
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
	if app.enemy_intents != null:
		for action in app.enemy_intents.get_intents():
			announcements[action["enemy_position"]] = action
	for index in range(_labels.size()):
		var enemy: Dictionary = roster[index]
		var position: int = enemy["position"]
		_labels[index].text = "Enemy %d - %s\nHP: %d/%d | Block: %d%s" % [
			position, enemy["name"], enemy["hp"], enemy["max_hp"], enemy["block"],
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
	_hero_fonts.clear()
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
