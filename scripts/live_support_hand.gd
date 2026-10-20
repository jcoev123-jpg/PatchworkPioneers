extends Node
## Input/presentation only. All card effects and charges belong to the support service.

const SUPPORT_IDS := ["warden_brace", "tinker_tune_up", "seamstress_mend", "seamstress_stitch_up"]
const ALLY_IDS := ["seamstress_mend", "seamstress_stitch_up"]
var _battle: Control
var _deck: CombatDeck
var _party: CombatParty
var _bindings: Dictionary = {}
var _pending: Dictionary = {}
var _targets: Dictionary = {}
var _token := 0
var cancel_button: Button
var energy_label: Label
var _play := CombatStarterSupportPlay.new()
var _metadata = preload("res://scripts/live_hand_card_metadata.gd").new()


func _ready() -> void:
	get_parent().start_run_requested.connect(_sync_battle, CONNECT_DEFERRED)


func _process(_delta: float) -> void:
	_sync_battle()


func _input(event: InputEvent) -> void:
	if not _pending.is_empty() and event.is_action_pressed("ui_cancel"):
		_cancel_pending()
		get_viewport().set_input_as_handled()


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
		cancel_button = Button.new()
		cancel_button.text = "Cancel target (Esc)"
		cancel_button.pressed.connect(_cancel_pending)
		app.end_turn_button.get_parent().add_child(cancel_button)
		cancel_button.hide()
	if not _pending.is_empty() and not _selection_valid():
		_cancel_pending()
	for panel in _targets.keys():
		if panel not in app.hero_panels or _party.is_downed(app.hero_panels.find(panel) + 1):
			_cancel_pending()
			break
	energy_label.text = "Energy: %d | Up: cards | Click / Enter / Space: play" % _deck.energy
	if _pending.get("choosing", false):
		energy_label.text = "Energy: %d | %s\nchoose a living ally | Esc: cancel" % [
			_deck.energy, StarterCards.new().get_definition(_pending.id).display_name]
	for panel in _bindings.keys():
		if not is_instance_valid(panel) or panel.get_parent() != app.hand_view:
			_unbind(panel)
	# Decorate only the exact ordered live cards, without replacing their input panels.
	_metadata.sync(app.hand_view.get_children(), _deck.hand)
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
		panel.tooltip_text = "Click or focus and press Enter / Space to play\n" + _metadata.base_effect_text(label.text)
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
	if event == null or not _eligible(panel, card_id, deck, party, battle):
		return
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var accept: bool = event is InputEventKey and panel.has_focus() and event.is_action_pressed("ui_accept") and not event.echo
	if not click and not accept:
		return
	panel.accept_event()
	if not _pending.is_empty() and _pending.panel == panel:
		return
	_cancel_pending()
	_pending = {"panel": panel, "id": card_id, "choosing": false, "queued": false}
	if card_id in ALLY_IDS and not _selection_valid():
		_cancel_pending()
		return
	# Rebuilding the hand must happen outside the current Control input dispatch.
	_activate.call_deferred(panel, card_id, deck, party, battle, _token)


func _activate(panel, card_id: String, deck: CombatDeck, party: CombatParty, battle, token: int = -1) -> void:
	if token != _token or _pending.is_empty():
		return
	if not _eligible(panel, card_id, deck, party, battle):
		_cancel_pending()
		return
	if card_id in ALLY_IDS:
		if _selection_valid():
			_choose_target()
		else:
			_cancel_pending()
		return
	_cancel_pending()
	if not _play.play_card(deck, party, card_id, 0):
		return
	var app = get_parent()
	app._refresh_party()
	app._refresh_hand()
	_sync_battle()
	app.end_turn_button.grab_focus()


func _selection_valid() -> bool:
	if _pending.is_empty() or not _eligible(_pending.panel, _pending.id, _deck, _party, _battle):
		return false
	if _pending.id not in ALLY_IDS:
		return true
	# Presentation preflight only; the support service revalidates and commits.
	var authored := StarterCards.new().get_definition(_pending.id)
	if not _party.is_valid() or not _deck.turn_active or _deck.energy < authored.cost:
		return false
	for hero in _party.get_heroes():
		if hero.id == authored.owner:
			return hero.hp > 0 and hero.position in authored.from_positions
	return false


func _choose_target() -> void:
	_pending.choosing = true
	cancel_button.show()
	var panels: Array[Control] = []
	var app = get_parent()
	for index in range(app.hero_panels.size()):
		var panel: Control = app.hero_panels[index]
		if _party.is_downed(index + 1):
			continue
		panels.append(panel)
		panel.focus_mode = Control.FOCUS_ALL
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cue := Label.new()
		cue.text = "Choose ally: Click / Enter / Space"
		cue.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(cue)
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(0, 0, 0, 0)
		focus.border_color = Color("ece0c8")
		focus.set_border_width_all(3)
		panel.add_theme_stylebox_override("focus", focus)
		var callback := _on_target_input.bind(panel, index + 1, _token)
		_targets[panel] = {"callback": callback, "cue": cue}
		panel.gui_input.connect(callback)
	for index in range(panels.size()):
		var panel := panels[index]
		panel.focus_next = panel.get_path_to(panels[(index + 1) % panels.size()])
		panel.focus_previous = panel.get_path_to(panels[(index - 1 + panels.size()) % panels.size()])
		panel.focus_neighbor_bottom = panel.get_path_to(cancel_button)
	if not panels.is_empty():
		panels[0].grab_focus()
	_sync_battle()


func _on_target_input(event: InputEvent, panel, position: int, token: int) -> void:
	if event == null or token != _token or not _targets.has(panel) or not _selection_valid():
		return
	if get_parent().hero_panels.find(panel) + 1 != position:
		return
	if _pending.get("queued", false) or not panel.is_visible_in_tree() or _party.is_downed(position):
		return
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var accept: bool = event is InputEventKey and panel.has_focus() and event.is_action_pressed("ui_accept") and not event.echo
	if not click and not accept:
		return
	panel.accept_event()
	_pending.queued = true
	_resolve_target.call_deferred(position, token)


func _resolve_target(position: int, token: int) -> void:
	if token != _token or not _selection_valid() or not _pending.get("queued", false):
		return
	var id: String = _pending.id
	_cancel_pending()
	if _play.play_card(_deck, _party, id, position):
		var app = get_parent()
		app._refresh_party()
		app._refresh_hand()
		_sync_battle()
		app.end_turn_button.grab_focus()


func _cancel_pending() -> void:
	_token += 1
	var source = _pending.get("panel")
	_pending.clear()
	for panel in _targets:
		if is_instance_valid(panel):
			if panel.gui_input.is_connected(_targets[panel].callback):
				panel.gui_input.disconnect(_targets[panel].callback)
			panel.focus_mode = Control.FOCUS_NONE
			panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
			panel.focus_next = NodePath()
			panel.focus_previous = NodePath()
			panel.focus_neighbor_bottom = NodePath()
			panel.remove_theme_stylebox_override("focus")
			_targets[panel].cue.free()
	_targets.clear()
	if is_instance_valid(cancel_button):
		cancel_button.hide()
	if is_instance_valid(source) and source.is_inside_tree() and source.is_visible_in_tree():
		source.grab_focus()


func _unbind(panel) -> void:
	if is_instance_valid(panel) and panel.gui_input.is_connected(_bindings[panel]):
		panel.gui_input.disconnect(_bindings[panel])
	_bindings.erase(panel)
	if _pending.get("panel") == panel:
		_cancel_pending()


func _clear() -> void:
	_metadata.clear()
	_cancel_pending()
	for panel in _bindings.keys():
		_unbind(panel)
	_pending.clear()
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	if is_instance_valid(energy_label):
		energy_label.queue_free()
	energy_label = null
	if is_instance_valid(cancel_button):
		cancel_button.queue_free()
	cancel_button = null
	_battle = null
	_deck = null
	_party = null
