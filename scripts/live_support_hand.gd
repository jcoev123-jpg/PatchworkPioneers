extends Node
## Input/presentation only. All card effects and charges belong to the support service.

const SUPPORT_IDS := ["warden_brace", "tinker_tune_up"]
var _battle: Control
var _deck: CombatDeck
var _party: CombatParty
var _bindings: Dictionary = {}
var _pending: Dictionary = {}
var energy_label: Label
var _play := CombatStarterSupportPlay.new()


func _ready() -> void:
	get_parent().start_run_requested.connect(_sync_battle, CONNECT_DEFERRED)


func _process(_delta: float) -> void:
	_sync_battle()


func _sync_battle() -> void:
	var app = get_parent()
	if app.deck == null or not is_instance_valid(app.battle_view):
		_clear()
		return
	if _battle != app.battle_view or _deck != app.deck or _party != app.party:
		_clear()
		_battle = app.battle_view
		_deck = app.deck
		_party = app.party
		_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
		energy_label = Label.new()
		energy_label.name = "SupportHandEnergy"
		app.end_turn_button.get_parent().add_child(energy_label)
	energy_label.text = "Energy: %d | Up: cards | Click / Enter / Space: play" % _deck.energy
	for panel in _bindings.keys():
		if not is_instance_valid(panel) or panel.get_parent() != app.hand_view:
			_unbind(panel)
	var actionable: Array[Control] = []
	for panel in app.hand_view.get_children():
		var label := panel.get_child(0) as Label
		if label == null or label.text not in SUPPORT_IDS:
			continue
		actionable.append(panel)
		if _bindings.has(panel):
			continue
		panel.focus_mode = Control.FOCUS_ALL
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.tooltip_text = "Click or focus and press Enter / Space to play"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hint := Label.new()
		hint.text = "Click / Enter / Space"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(hint)
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(0, 0, 0, 0)
		focus.border_color = Color("ece0c8")
		focus.set_border_width_all(3)
		panel.add_theme_stylebox_override("focus", focus)
		var callback := _on_card_input.bind(panel, label.text, _deck, _party, _battle)
		_bindings[panel] = callback
		panel.gui_input.connect(callback)
	# Keep the existing End/Return Tab cycle; Up enters the card row, Down exits it.
	if not actionable.is_empty():
		for button in [app.end_turn_button, app.return_button]:
			button.focus_neighbor_top = button.get_path_to(actionable[0])
		for index in range(actionable.size()):
			var panel := actionable[index]
			panel.focus_next = panel.get_path_to(actionable[(index + 1) % actionable.size()])
			panel.focus_previous = panel.get_path_to(actionable[(index - 1 + actionable.size()) % actionable.size()])
			panel.focus_neighbor_bottom = panel.get_path_to(app.end_turn_button)
	else:
		app.end_turn_button.focus_neighbor_top = NodePath()
		app.return_button.focus_neighbor_top = NodePath()


func _eligible(panel, card_id: String, deck: CombatDeck, party: CombatParty, battle) -> bool:
	var app = get_parent()
	if not is_instance_valid(panel) or not is_instance_valid(battle):
		return false
	if not _bindings.has(panel) or card_id not in SUPPORT_IDS:
		return false
	if app.deck != deck or app.party != party or app.battle_view != battle:
		return false
	if deck != _deck or party != _party or battle != _battle:
		return false
	if not panel.is_visible_in_tree() or not battle.is_visible_in_tree() or panel.get_parent() != app.hand_view:
		return false
	var index: int = panel.get_index()
	return index < deck.hand.size() and deck.hand[index] == card_id \
		and panel.get_child(0) is Label and panel.get_child(0).text == card_id


func _on_card_input(event: InputEvent, panel, card_id: String, deck: CombatDeck, party: CombatParty, battle) -> void:
	if event == null or not _eligible(panel, card_id, deck, party, battle) or _pending.has(panel):
		return
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var accept: bool = event is InputEventKey and panel.has_focus() and event.is_action_pressed("ui_accept") and not event.echo
	if not click and not accept:
		return
	panel.accept_event()
	_pending[panel] = true
	# Rebuilding the hand must happen outside the current Control input dispatch.
	_activate.call_deferred(panel, card_id, deck, party, battle)


func _activate(panel, card_id: String, deck: CombatDeck, party: CombatParty, battle) -> void:
	if not _pending.has(panel):
		return
	_pending.erase(panel)
	if not _eligible(panel, card_id, deck, party, battle):
		return
	if not _play.play_card(deck, party, card_id, 0):
		return
	var app = get_parent()
	app._refresh_party()
	app._refresh_hand()
	_sync_battle()
	app.end_turn_button.grab_focus()


func _unbind(panel) -> void:
	if is_instance_valid(panel) and panel.gui_input.is_connected(_bindings[panel]):
		panel.gui_input.disconnect(_bindings[panel])
	_bindings.erase(panel)
	_pending.erase(panel)


func _clear() -> void:
	for panel in _bindings.keys():
		_unbind(panel)
	_pending.clear()
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	if is_instance_valid(energy_label):
		energy_label.queue_free()
	energy_label = null
	_battle = null
	_deck = null
	_party = null
