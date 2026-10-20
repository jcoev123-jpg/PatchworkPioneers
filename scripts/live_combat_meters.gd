extends Node
## Reads fresh snapshots only; retained references identify the current presentation.

var row: HBoxContainer
var _battle: Control
var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies


func _ready() -> void:
	get_parent().start_run_requested.connect(_sync_battle, CONNECT_DEFERRED)


func _process(_delta: float) -> void:
	_sync_battle()


func _sync_battle() -> void:
	var app = get_parent()
	if app.deck == null or app.party == null or app.enemies == null \
			or not is_instance_valid(app.battle_view):
		_clear()
		return
	if not app.battle_view.is_visible_in_tree() or not app.party.is_valid() or not app.enemies.is_valid():
		_clear()
		return
	if _battle != app.battle_view or _deck != app.deck or _party != app.party or _enemies != app.enemies:
		_clear()
		_battle = app.battle_view
		_deck = app.deck
		_party = app.party
		_enemies = app.enemies
		_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
		row = HBoxContainer.new()
		row.name = "CombatMeters"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		var column := app.hero_view.get_parent() as VBoxContainer
		# Reserve room for the bars while leaving the existing target panels actionable.
		column.add_theme_constant_override("separation", 8)
		column.add_child(row)
		column.move_child(row, app.intent_label.get_index())
		for side in ["hero", "enemy"]:
			var count: int = CombatParty.PARTY_SIZE if side == "hero" else _enemies.get_enemies().size()
			for position in range(1, count + 1):
				var meter := CombatActorMeter.new()
				meter.name = "%s%d" % [side, position]
				meter.custom_minimum_size = Vector2(224, 100)
				meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var padding := meter.get_node("Padding") as MarginContainer
				for edge in ["left", "right", "top", "bottom"]:
					padding.add_theme_constant_override("margin_" + edge, 6)
				meter.get_node("Padding/Content").add_theme_constant_override("separation", 2)
				for label in [meter.actor_heading, meter.hp_text, meter.block_text]:
					label.add_theme_font_size_override("font_size", 14)
				for bar in [meter.hp_bar, meter.block_bar]:
					bar.custom_minimum_size = Vector2(200, 10)
				row.add_child(meter)
	for meter in row.get_children():
		var side := "hero" if meter.get_index() < CombatParty.PARTY_SIZE else "enemy"
		var position: int = meter.get_index() + 1 if side == "hero" else meter.get_index() - CombatParty.PARTY_SIZE + 1
		meter.show_actor(_party.get_hero(position) if side == "hero" else _enemies.get_enemy(position), side)


func _clear() -> void:
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	if is_instance_valid(row):
		row.get_parent().remove_child(row)
		row.queue_free()
	row = null
	_battle = null
	_deck = null
	_party = null
	_enemies = null
