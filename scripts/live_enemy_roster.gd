extends Node
## Observes the app's authoritative roster; owns only presentation, never combat actions.

var enemies: CombatEnemies
var panel: PanelContainer
var _battle: Control
var _labels: Array[Label] = []


func _ready() -> void:
	# The parent connects its Start Run handler after child _ready, so observe deferred.
	get_parent().start_run_requested.connect(_sync_battle, CONNECT_DEFERRED)


func _process(_delta: float) -> void:
	_sync_battle()
	_refresh()


func _sync_battle() -> void:
	var app = get_parent()
	if app.deck == null or not is_instance_valid(app.battle_view):
		_clear()
		return
	if _battle == app.battle_view:
		return
	_clear()
	_battle = app.battle_view
	_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
	enemies = app.enemies
	panel = PanelContainer.new()
	panel.name = "EnemyRosterPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 24)
	panel.add_child(rows)
	for enemy in enemies.get_enemies():
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		rows.add_child(label)
		_labels.append(label)
	var column: Node = app.hero_view.get_parent()
	column.add_child(panel)
	column.move_child(panel, app.hero_view.get_index() + 1)
	_refresh()


func _refresh() -> void:
	if enemies == null:
		return
	for index in range(_labels.size()):
		var enemy := enemies.get_enemy(index + 1)
		_labels[index].text = "Enemy %d - %s\nHP: %d/%d | Block: %d%s" % [
			enemy.position, enemy.name, enemy.hp, enemy.max_hp, enemy.block,
			"\nSLAIN" if enemies.is_slain(index + 1) else ""]


func _clear() -> void:
	enemies = null
	_labels.clear()
	if is_instance_valid(panel):
		panel.get_parent().remove_child(panel)
		panel.queue_free()
	panel = null
	_battle = null
