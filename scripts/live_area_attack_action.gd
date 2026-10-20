extends Node
## Presentation and session guards only; CombatAreaAttacks owns the transaction.

var button: Button
var _battle: Control
var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies
var _result: CombatBattleResult
var _rng: RandomNumberGenerator
var _token := 0
var _queued := false
var _callback: Callable
var _play := CombatAreaAttacks.new()


func _ready() -> void:
	get_parent().start_run_requested.connect(_sync_battle, CONNECT_DEFERRED)


func _process(_delta: float) -> void:
	_sync_battle()


func _sync_battle() -> void:
	var app = get_parent()
	if app.deck == null or app.party == null or app.enemies == null or app.battle_result == null \
			or not is_instance_valid(app.battle_view) or not app.deck.hand.has(CombatAreaAttacks.SCRAP_BOMB_ID):
		_clear()
		return
	if _battle != app.battle_view or _deck != app.deck or _party != app.party \
			or _enemies != app.enemies or _result != app.battle_result or _rng != app.run_rng:
		_clear()
		_battle = app.battle_view
		_deck = app.deck
		_party = app.party
		_enemies = app.enemies
		_result = app.battle_result
		_rng = app.run_rng
		_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
		button = Button.new()
		button.name = "ScrapBombAction"
		var definition := StarterCards.new().get_definition(CombatAreaAttacks.SCRAP_BOMB_ID)
		button.text = "%s | Tinker | %d energy (Left: action)" % [definition.display_name, definition.cost]
		button.custom_minimum_size = Vector2(0, 40)
		# A separate row beside the actions avoids widening their existing energy readout.
		var actions: Control = app.end_turn_button.get_parent()
		var column := actions.get_parent()
		column.add_child(button)
		column.move_child(button, actions.get_index())
		_callback = _on_pressed.bind(_token)
		button.pressed.connect(_callback)
		for control in [app.end_turn_button, app.return_button]:
			control.focus_neighbor_left = control.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(app.return_button)
		button.focus_neighbor_bottom = button.get_path_to(app.end_turn_button)
		button.focus_next = button.get_path_to(app.end_turn_button)
		button.focus_previous = button.get_path_to(app.return_button)
	button.disabled = _queued or not _eligible()


func _eligible() -> bool:
	var app = get_parent()
	if not is_instance_valid(button) or not is_instance_valid(_battle):
		return false
	if app.battle_view != _battle or app.deck != _deck or app.party != _party \
			or app.enemies != _enemies or app.battle_result != _result or app.run_rng != _rng:
		return false
	if not button.is_visible_in_tree() or not _battle.is_visible_in_tree() or not _battle.is_ancestor_of(button):
		return false
	if _result._party != _party or _result._enemies != _enemies or not _result.can_continue():
		return false
	if not _deck.turn_active or not _party.is_valid() or not _enemies.is_valid() \
			or _party.is_defeated() or _enemies.is_victorious():
		return false
	var definition := StarterCards.new().get_definition(CombatAreaAttacks.SCRAP_BOMB_ID)
	if not _deck.hand.has(definition.id) or _deck.energy < definition.cost:
		return false
	for hero in _party.get_heroes():
		if hero.id == definition.owner:
			return hero.hp > 0 and hero.position in definition.from_positions
	return false


func _on_pressed(token: int) -> void:
	if token != _token or _queued or not is_instance_valid(button) or button.disabled or not _eligible():
		return
	_queued = true
	button.disabled = true
	# Hand controls may be freed by refresh, outside the GUI input dispatch.
	_activate.call_deferred(token)


func _activate(token: int) -> void:
	if token != _token or not _queued:
		return
	_queued = false
	if _eligible() and _play.play_scrap_bomb(_deck, _party, _enemies):
		get_parent()._refresh_hand()
		get_parent().end_turn_button.grab_focus()
	_sync_battle()


func _clear() -> void:
	_token += 1
	_queued = false
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	if is_instance_valid(button):
		if button.pressed.is_connected(_callback):
			button.pressed.disconnect(_callback)
		var app = get_parent()
		for control in [app.end_turn_button, app.return_button]:
			if is_instance_valid(control):
				control.focus_neighbor_left = NodePath()
		button.get_parent().remove_child(button)
		button.queue_free()
	button = null
	_callback = Callable()
	_battle = null
	_deck = null
	_party = null
	_enemies = null
	_result = null
	_rng = null
