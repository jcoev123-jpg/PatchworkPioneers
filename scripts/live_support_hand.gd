extends Node
## Input/presentation only. Support and movement services own effects and charges.

const SUPPORT_IDS := ["warden_brace", "tinker_tune_up", "seamstress_mend", "seamstress_stitch_up"]
const ALLY_IDS := ["seamstress_mend", "seamstress_stitch_up"]
var _battle: Control
var _deck: CombatDeck
var _party: CombatParty
var _bindings: Dictionary = {}
var _move_context: Dictionary = {}
var _pending: Dictionary = {}
var _targets: Dictionary = {}
var _token := 0
var _dragging := false
var _drag_origin := Vector2.ZERO
var cancel_button: Button
var energy_label: Label
var energy_orb: Control
var help_label: Label
var _play := CombatStarterSupportPlay.new()
var _metadata = preload("res://scripts/live_hand_card_metadata.gd").new()


class EnergyOrb extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(76, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 34, Color("555d48"))
		draw_arc(center, 34, 0, TAU, 64, Color("ecdfbd"), 2, true)
		for index in range(16):
			var angle := TAU * index / 16.0
			draw_line(center + Vector2.from_angle(angle) * 28,
				center + Vector2.from_angle(angle + 0.07) * 30, Color("c9b996"), 1, true)


func _ready() -> void:
	get_parent().start_run_requested.connect(_sync_battle, CONNECT_DEFERRED)


func _process(_delta: float) -> void:
	_sync_battle()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not _pending.is_empty():
		var source = _pending.panel
		if is_instance_valid(source):
			source.set_meta("aiming", true)
			source.set_meta("aim_point", event.position)
			source.queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _dragging:
		_dragging = false
		if _pending.is_empty() or not _selection_valid():
			_cancel_pending()
			return
		_pending.panel.set_meta("aiming", false)
		if _pending.id in ALLY_IDS:
			if not _pending.get("choosing", false):
				_choose_target()
			if event.position.distance_to(_drag_origin) > 10:
				# Drag release uses exactly the same target receipt and deferred commit.
				for panel in _targets:
					if panel.get_global_rect().has_point(event.position):
						var press := InputEventMouseButton.new()
						press.button_index = MOUSE_BUTTON_LEFT
						press.pressed = true
						_on_target_input(press, panel, _targets[panel].position, _token)
						return
				_cancel_pending()
		else:
			if _pending.panel.get_global_rect().has_point(event.position):
				_activate.call_deferred(_pending.panel, _pending.id, _deck, _party, _battle, _token)
			else:
				_cancel_pending()
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
		_play = CombatStarterSupportPlay.new()
		var carry = app.party_carryover
		if carry is RunTornCarryover and carry._wardrobe != null:
			var state: Dictionary = carry._wardrobe.get_snapshot()
			if app._current_carryover_fight() and carry.can_bind_wardrobe(carry._wardrobe, carry.torn, state):
				_play.bind_patch_wardrobe(carry._wardrobe, carry.torn, state, carry.torn.read_state())
			else:
				# Explicit invalid run authority must never fall back to unbound play.
				_play.bind_patch_wardrobe(null, null)
		_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
		var hud := _battle.find_child("SupportHUD", true, false) as HBoxContainer
		energy_orb = EnergyOrb.new()
		energy_orb.name = "SupportHandEnergyOrb"
		hud.add_child(energy_orb)
		hud.move_child(energy_orb, 0)
		energy_label = Label.new()
		energy_label.name = "SupportHandEnergy"
		energy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		energy_label.add_theme_font_size_override("font_size", 18)
		energy_orb.add_child(energy_label)
		energy_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		help_label = Label.new()
		help_label.name = "SupportHandHelp"
		help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hud.add_child(help_label)
		hud.move_child(help_label, 1)
		cancel_button = Button.new()
		cancel_button.text = "Cancel target (Esc)"
		cancel_button.pressed.connect(_cancel_pending)
		hud.add_child(cancel_button)
		cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cancel_button.hide()
	if not _pending.is_empty() and not _selection_valid():
		_cancel_pending()
	if not _targets_valid():
		_cancel_pending()
	for panel in _targets:
		var cue: Label = _targets[panel].cue
		cue.position = panel.global_position - Vector2(0, 16)
		cue.size = Vector2(panel.size.x, 16)
	energy_label.text = "Energy\n%d" % _deck.energy
	help_label.text = "Up: cards | Click / Enter / Space: play"
	if _pending.get("choosing", false):
		help_label.text = "%s: choose a living ally | Esc: cancel" % StarterCards.new().get_definition(_pending.id).display_name
	for panel in _bindings.keys():
		if not is_instance_valid(panel) or panel.get_parent() != app.hand_view:
			_unbind(panel)
	# Decorate only the exact ordered live cards, without replacing their input panels.
	_metadata.set_app(app)
	_metadata.sync(app.hand_view.get_children(), _deck.hand)
	var actionable: Array[Control] = []
	for panel in app.hand_view.get_children():
		var label := panel.get_child(0) as Label
		if label == null or (label.text not in SUPPORT_IDS and label.text not in M02PositionCards.IDS):
			continue
		actionable.append(panel)
		if _bindings.has(panel):
			continue
		panel.focus_mode = Control.FOCUS_ALL
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.tooltip_text = "Click or focus and press Enter / Space to play\n" + _metadata.base_effect_text(label.text)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(0, 0, 0, 0)
		focus.border_color = Color("ece0c8")
		focus.set_border_width_all(3)
		panel.add_theme_stylebox_override("focus", focus)
		var callback := _on_card_input.bind(panel, label.text, _deck, _party, _battle)
		_bindings[panel] = callback
		if label.text in M02PositionCards.IDS:
			_move_context[panel] = _current_move_context(panel)
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


func _current_move_context(panel) -> Array:
	var app = get_parent()
	return [app.deck, app.party, app.battle_view, app.enemies, app.battle_result,
		app.run_rng, app.enemy_intents, app.enemy_intents._turn_index if app.enemy_intents != null else -1, panel.get_index()]


func _eligible(panel, card_id: String, deck: CombatDeck, party: CombatParty, battle) -> bool:
	var app = get_parent()
	if not is_instance_valid(panel) or not is_instance_valid(battle):
		return false
	if not _bindings.has(panel) or (card_id not in SUPPORT_IDS and card_id not in M02PositionCards.IDS):
		return false
	if app.deck != deck or app.party != party or app.battle_view != battle:
		return false
	if deck != _deck or party != _party or battle != _battle:
		return false
	if not panel.is_visible_in_tree() or not battle.is_visible_in_tree() or panel.get_parent() != app.hand_view:
		return false
	if card_id in M02PositionCards.IDS:
		if app.enemy_intents == null or _move_context.get(panel, []) != _current_move_context(panel):
			return false
		if app._battle_closed or not deck.turn_active or app.battle_result == null \
			or not app.battle_result.can_continue() or app.battle_result._party != party \
			or app.battle_result._enemies != app.enemies or not party.is_valid() \
			or app.enemies == null or not app.enemies.is_valid() \
			or party.is_defeated() or app.enemies.is_victorious():
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
	_pending = {"panel": panel, "id": card_id, "choosing": false, "queued": false, "context": _current_move_context(panel)}
	if card_id in ALLY_IDS and not _selection_valid():
		_cancel_pending()
		return
	if click:
		_dragging = true
		_drag_origin = panel.get_global_transform() * event.position
	# Ally selection can arm immediately; target-free mouse casts wait for release.
	if accept or card_id in ALLY_IDS:
		_activate.call_deferred(panel, card_id, deck, party, battle, _token)


func _activate(panel, card_id: String, deck: CombatDeck, party: CombatParty, battle, token: int = -1) -> void:
	if token != _token or _pending.is_empty():
		return
	if not _eligible(panel, card_id, deck, party, battle):
		_cancel_pending()
		return
	if card_id in ALLY_IDS:
		if _pending.get("choosing", false):
			return
		if _selection_valid():
			_choose_target()
		else:
			_cancel_pending()
		return
	_cancel_pending()
	if card_id in M02PositionCards.IDS:
		if CombatPositionSwaps.play_move_card(deck, party, card_id, M02PositionCards.new().get_definition(card_id)):
			var app = get_parent()
			app._refresh_party()
			app._refresh_intents()
			app._refresh_hand()
			_sync_battle()
			app.end_turn_button.grab_focus()
		return
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
	if _pending.get("context", []) != _current_move_context(_pending.panel):
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
		cue.text = "Choose ally"
		# A caption above the existing actor never expands or overprints its state.
		cue.top_level = true
		cue.add_theme_font_size_override("font_size", 12)
		cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(cue)
		var focus := StyleBoxFlat.new()
		focus.bg_color = Color(0, 0, 0, 0)
		focus.border_color = Color("ece0c8")
		focus.set_border_width_all(3)
		panel.add_theme_stylebox_override("focus", focus)
		var callback := _on_target_input.bind(panel, index + 1, _token)
		_targets[panel] = {"callback": callback, "cue": cue,
			"position": index + 1, "hero_id": _party.get_hero(index + 1).id}
		panel.gui_input.connect(callback)
	for index in range(panels.size()):
		var panel := panels[index]
		panel.focus_next = panel.get_path_to(panels[(index + 1) % panels.size()])
		panel.focus_previous = panel.get_path_to(panels[(index - 1 + panels.size()) % panels.size()])
		panel.focus_neighbor_bottom = panel.get_path_to(cancel_button)
	if not panels.is_empty():
		panels[0].grab_focus()
	_sync_battle()


func _targets_valid() -> bool:
	for panel in _targets:
		var target: Dictionary = _targets[panel]
		if not is_instance_valid(panel) or get_parent().hero_panels.find(panel) + 1 != target.position:
			return false
		var hero := _party.get_hero(target.position)
		if hero.get("id") != target.hero_id or hero.get("hp", 0) <= 0:
			return false
	return true


func _on_target_input(event: InputEvent, panel, position: int, token: int) -> void:
	if event == null or token != _token or not _targets.has(panel):
		return
	if not _selection_valid() or not _targets_valid():
		_cancel_pending()
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
	_pending.target = {"position": position, "hero_id": _targets[panel].hero_id}
	_resolve_target.call_deferred(position, token)


func _resolve_target(position: int, token: int) -> void:
	if token != _token or not _pending.get("queued", false):
		return
	if not _selection_valid() or not _targets_valid() \
		or _pending.target.position != position \
		or _party.get_hero(position).get("id") != _pending.target.hero_id:
		_cancel_pending()
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
	_dragging = false
	if is_instance_valid(_pending.get("panel")):
		_pending.panel.set_meta("aiming", false)
	_token += 1
	var source = _pending.get("panel")
	_pending.clear()
	for panel in _targets:
		if is_instance_valid(panel):
			if panel.gui_input.is_connected(_targets[panel].callback):
				panel.gui_input.disconnect(_targets[panel].callback)
			if panel.has_focus():
				panel.release_focus()
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
	_move_context.erase(panel)
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
	if is_instance_valid(energy_orb):
		energy_orb.queue_free()
	energy_orb = null
	energy_label = null
	if is_instance_valid(help_label):
		help_label.queue_free()
	help_label = null
	if is_instance_valid(cancel_button):
		cancel_button.queue_free()
	cancel_button = null
	_battle = null
	_deck = null
	_party = null
	_play = null
