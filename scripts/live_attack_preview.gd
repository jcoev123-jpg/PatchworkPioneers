extends Node
## Live selection only: targeting owns legality and attack cards own mutation.

var cue: Label
var _battle: Control
var _deck: CombatDeck
var _bindings: Dictionary = {}
var _selected: Control
var _keyboard := false
var _targeting := CombatAttackTargeting.new()
var _catalog := StarterCards.new()
var _play := CombatAttackCards.new()
var last_event: Dictionary = {}
var _armed: Control
var _queued := false
var _token := 0
var _turn := -1


func _process(_delta: float) -> void:
	_sync_battle()


func _input(event: InputEvent) -> void:
	_sync_battle()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var roster = get_parent().get_node_or_null("LiveEnemyRoster")
		if roster != null and is_instance_valid(_armed):
			for index in range(roster._labels.size()):
				var label: Label = roster._labels[index]
				if label.is_visible_in_tree() and label.get_global_rect().has_point(event.position):
					_queue_attack(index + 1)
					get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_3:
		_queue_attack(event.keycode - KEY_1 + 1)
		return
	if event.keycode != KEY_P:
		return
	var panels: Array[Control] = []
	var ids: Array[String] = []
	for panel in _bindings:
		if _eligible(panel):
			var id := _card_id(panel)
			if id not in ids:
				ids.append(id)
				panels.append(panel)
	if panels.is_empty():
		return
	var index := ids.find(_card_id(_selected))
	_selected = panels[(index + 1) % panels.size()]
	_armed = _selected if _single(_selected) else null
	_token += 1
	_queued = false
	_keyboard = true
	_refresh()
	get_viewport().set_input_as_handled()


func _single(panel) -> bool:
	return _catalog.get_definition(_card_id(panel)).get("target_kind") == "enemy_single"


func _select(event: InputEvent, panel) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _bindings.has(panel) or not _eligible(panel) or not _single(panel):
		return
	_token += 1
	_queued = false
	_armed = panel
	_selected = panel
	_keyboard = true
	panel.accept_event()
	_refresh()


func _queue_attack(position: int) -> void:
	if _queued or not _bindings.has(_armed) or not _eligible(_armed) or not _single(_armed):
		return
	var app = get_parent()
	var preview := _targeting.get_preview(_deck, app.party, app.enemies, _card_id(_armed))
	if not preview.playable or position not in preview.target_positions:
		return
	_queued = true
	_commit.call_deferred(_armed, _card_id(_armed), position, _token,
		app.party, app.enemies, app.battle_result, app.run_rng, _turn)


func _commit(panel, id: String, position: int, token: int, party, enemies, result, rng, turn: int) -> void:
	var app = get_parent()
	if token != _token or not _queued:
		return
	_queued = false
	if not _bindings.has(panel) or panel != _armed or not _eligible(panel) or _card_id(panel) != id:
		return
	if app.party != party or app.enemies != enemies or app.battle_result != result or app.run_rng != rng \
			or app.enemy_intents._turn_index != turn:
		return
	last_event = _play.play_attack(_deck, party, enemies, id, position)
	if last_event.ok:
		_armed = null
		_token += 1
		app._refresh_hand()
		app._refresh_enemy_roster()
		_sync_battle()


func _card_id(panel) -> String:
	if not is_instance_valid(panel) or panel.get_child_count() == 0 or not panel.get_child(0) is Label:
		return ""
	return panel.get_child(0).text


func _eligible(panel) -> bool:
	var app = get_parent()
	if not is_instance_valid(panel) or not is_instance_valid(_battle) or _deck == null:
		return false
	if app.deck != _deck or app.battle_view != _battle or not is_instance_valid(app.hand_view):
		return false
	if not _battle.is_visible_in_tree() or not panel.is_visible_in_tree() or panel.get_parent() != app.hand_view:
		return false
	if app.party == null or app.enemies == null or not app.party.is_valid() or not app.enemies.is_valid():
		return false
	if not _deck.turn_active or app.party.is_defeated() or app.enemies.is_victorious():
		return false
	if app.battle_result == null or not app.battle_result.can_continue():
		return false
	if app.battle_result._party != app.party or app.battle_result._enemies != app.enemies:
		return false
	var id := _card_id(panel)
	var index: int = panel.get_index()
	return id in CombatAttackTargeting.ATTACK_IDS and index < _deck.hand.size() and _deck.hand[index] == id


func _sync_battle() -> void:
	var app = get_parent()
	if app.deck == null or not is_instance_valid(app.battle_view) or not is_instance_valid(app.hand_view):
		_clear()
		return
	if _battle != app.battle_view or _deck != app.deck:
		_clear()
		_battle = app.battle_view
		_deck = app.deck
		_play = CombatAttackCards.new()
		last_event = {}
		_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
		cue = Label.new()
		cue.name = "AttackPreviewCue"
		cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cue.add_theme_font_size_override("font_size", 18)
		cue.custom_minimum_size.y = 44
		cue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var column: Node = app.hand_view.get_parent()
		column.add_child(cue)
		column.move_child(cue, app.hand_view.get_index())
	if app.enemy_intents != null and _turn != app.enemy_intents._turn_index:
		_turn = app.enemy_intents._turn_index
		_play.start_player_turn()
		_token += 1
		_queued = false
		_armed = null
	for panel in _bindings.keys():
		if not _eligible(panel) or _bindings[panel].id != _card_id(panel):
			_unbind(panel)
	for panel in app.hand_view.get_children():
		if not _eligible(panel) or _bindings.has(panel):
			continue
		# Labels ignore input; the real card panel receives selection.
		panel.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var entered := _hover.bind(panel)
		var exited := _leave.bind(panel)
		var input := _select.bind(panel)
		_bindings[panel] = {"id": _card_id(panel), "entered": entered, "exited": exited, "input": input}
		if _single(panel):
			panel.gui_input.connect(input)
			panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.mouse_entered.connect(entered)
		panel.mouse_exited.connect(exited)
	_refresh()


func _hover(panel: Control) -> void:
	if not _bindings.has(panel) or not _eligible(panel) or _bindings[panel].id != _card_id(panel):
		return
	_selected = panel
	_keyboard = false
	_refresh()


func _leave(panel: Control) -> void:
	if _selected == panel and not _keyboard:
		_selected = null
		_refresh()


func _refresh() -> void:
	if not is_instance_valid(cue):
		return
	if not _bindings.has(_selected) or not _eligible(_selected):
		_selected = null
		cue.text = "" if _bindings.is_empty() else "Attack preview: hover an attack | P: cycle held attacks"
		return
	var app = get_parent()
	var id := _card_id(_selected)
	var definition := _catalog.get_definition(id)
	var preview := _targeting.get_preview(app.deck, app.party, app.enemies, id)
	var targets: PackedStringArray = []
	for position in preview.target_positions:
		targets.append(str(position))
	var description := "Unavailable: no legal targets"
	if preview.playable:
		description = ("Choose one enemy slot: " if preview.requires_selection else "All enemies in slots: ") + ", ".join(targets)
	cue.text = "%s | %d energy | P / click card; 1-3 / click enemy\n%s" % [definition.display_name, definition.cost, description]


func _unbind(panel) -> void:
	var binding: Dictionary = _bindings[panel]
	if is_instance_valid(panel):
		if panel.gui_input.is_connected(binding.input):
			panel.gui_input.disconnect(binding.input)
		if panel.mouse_entered.is_connected(binding.entered):
			panel.mouse_entered.disconnect(binding.entered)
		if panel.mouse_exited.is_connected(binding.exited):
			panel.mouse_exited.disconnect(binding.exited)
	_bindings.erase(panel)
	if _selected == panel:
		_selected = null
	if _armed == panel:
		_armed = null
		_token += 1
		_queued = false


func _clear() -> void:
	_token += 1
	_queued = false
	_armed = null
	_turn = -1
	for panel in _bindings.keys():
		_unbind(panel)
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	if is_instance_valid(cue):
		cue.queue_free()
	cue = null
	_battle = null
	_deck = null
	_selected = null
