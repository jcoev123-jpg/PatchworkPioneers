class_name LiveWardenReactionHand
extends Node
## Live adapter for Warden reaction cards (Draw Fire and Counter-stitch, base and +).
## Binds real drawn reaction cards in the shared hand to app.round_flow.play_warden_reaction_card.

const ALLOWED_CARD_IDS: Array[String] = [
	"warden_draw_fire",
	"warden_draw_fire_plus",
	"warden_counter_stitch",
	"warden_counter_stitch_plus",
]

var _battle: Control
var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies
var _result: CombatBattleResult
var _round_flow: CombatRoundFlow
var _rng: RandomNumberGenerator
var _bindings: Dictionary = {}
var _pending: Dictionary = {}
var _dragging: bool = false
var _drag_origin: Vector2 = Vector2.ZERO
var _token: int = 0
var _turn: int = -1
var _metadata = preload("res://scripts/live_hand_card_metadata.gd").new()


func _ready() -> void:
	_sync_battle()


func _process(_delta: float) -> void:
	_sync_battle()


func _turn_index(app) -> int:
	if app == null or app.enemy_intents == null:
		return -1
	var turn_val: Variant = app.enemy_intents._turn_index
	if not turn_val is int:
		return -1
	return turn_val as int


func _valid_panel(app, panel: Variant) -> bool:
	if not is_instance_valid(panel) or not panel is Control or not is_instance_valid(app.hand_view):
		return false
	var c: Control = panel as Control
	if c.get_parent() != app.hand_view or _deck == null:
		return false
	if not _bindings.has(panel):
		return false
	var card_id: String = str(_bindings[panel]["id"])
	if not ALLOWED_CARD_IDS.has(card_id):
		return false
	var index: int = c.get_index()
	if index < 0 or index >= _deck.hand.size() or _deck.hand[index] != card_id:
		return false
	if c.get_child_count() < 1 or not c.get_child(0) is Label:
		return false
	if (c.get_child(0) as Label).text != card_id:
		return false
	return c.is_visible_in_tree()


func _sync_battle() -> void:
	var app = get_parent()
	if app == null or app.deck == null or app.party == null or app.enemies == null \
			or app.battle_result == null or app.round_flow == null \
			or not is_instance_valid(app.battle_view) or not is_instance_valid(app.hand_view):
		if _battle != null or not _bindings.is_empty() or not _pending.is_empty():
			_clear()
		return

	if _battle != app.battle_view or _deck != app.deck or _party != app.party \
			or _enemies != app.enemies or _result != app.battle_result \
			or _round_flow != app.round_flow or _rng != app.run_rng:
		_clear()
		_battle = app.battle_view
		_deck = app.deck
		_party = app.party
		_enemies = app.enemies
		_result = app.battle_result
		_round_flow = app.round_flow
		_rng = app.run_rng
		_turn = _turn_index(app)
		if is_instance_valid(_battle):
			_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
	elif _turn != _turn_index(app):
		_turn = _turn_index(app)
		_cancel_pending()

	var consistent: bool = app.party.is_valid() and app.enemies.is_valid() \
		and app.battle_result._party == app.party and app.battle_result._enemies == app.enemies
	if not consistent:
		for panel: Variant in _bindings.keys():
			_unbind(panel)
		_cancel_pending()
		return

	for panel: Variant in _bindings.keys():
		if not _valid_panel(app, panel):
			_unbind(panel)

	for panel: Node in app.hand_view.get_children():
		if not panel is Control or panel.get_child_count() < 1 or not panel.get_child(0) is Label:
			continue
		var label := panel.get_child(0) as Label
		var card_id: String = label.text
		if not ALLOWED_CARD_IDS.has(card_id):
			continue
		var index: int = (panel as Control).get_index()
		if index < 0 or index >= _deck.hand.size() or _deck.hand[index] != card_id:
			continue
		if _bindings.has(panel):
			continue
		_bind(panel as Control, card_id)

	if not _bindings.is_empty():
		_focus_chain()


func _bind(panel: Control, card_id: String) -> void:
	var callback: Callable = _on_card_input.bind(panel, card_id)
	_bindings[panel] = {"id": card_id, "callback": callback}
	panel.focus_mode = Control.FOCUS_ALL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	(panel.get_child(0) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("ece0c8")
	focus.set_border_width_all(3)
	panel.add_theme_stylebox_override("focus", focus)
	panel.tooltip_text = "Click or focus and press Enter / Space to play\n" + _metadata.base_effect_text(card_id)
	panel.gui_input.connect(callback)
	_focus_chain()


func _focus_chain() -> void:
	var app = get_parent()
	if app == null or not is_instance_valid(app.end_turn_button):
		return
	var panels: Array[Control] = []
	for panel: Variant in _bindings.keys():
		if is_instance_valid(panel) and panel is Control and (panel as Control).is_visible_in_tree():
			panels.append(panel as Control)
	if panels.is_empty():
		return
	for index: int in range(panels.size()):
		var panel: Control = panels[index]
		panel.focus_next = panel.get_path_to(panels[(index + 1) % panels.size()])
		panel.focus_previous = panel.get_path_to(panels[(index - 1 + panels.size()) % panels.size()])
		panel.focus_neighbor_top = panel.get_path_to(app.end_turn_button)
		panel.focus_neighbor_bottom = panel.get_path_to(app.end_turn_button)
	if app.end_turn_button.focus_neighbor_top.is_empty():
		app.end_turn_button.focus_neighbor_top = app.end_turn_button.get_path_to(panels[0])


func _unbind(panel: Variant) -> void:
	if not _bindings.has(panel):
		return
	var callback: Callable = _bindings[panel]["callback"]
	if is_instance_valid(panel) and panel is Control:
		var c: Control = panel as Control
		if c.gui_input.is_connected(callback):
			c.gui_input.disconnect(callback)
		var app = get_parent()
		if app == null or c.get_parent() != app.hand_view:
			if c.has_focus():
				c.release_focus()
			c.focus_mode = Control.FOCUS_NONE
			c.mouse_default_cursor_shape = Control.CURSOR_ARROW
			c.focus_next = NodePath()
			c.focus_previous = NodePath()
			c.focus_neighbor_top = NodePath()
			c.focus_neighbor_bottom = NodePath()
			c.remove_theme_stylebox_override("focus")
	_bindings.erase(panel)
	if _pending.get("panel") == panel:
		_cancel_pending()


func _on_card_input(event: InputEvent, panel: Variant, card_id: String) -> void:
	if event == null or not _eligible(panel, card_id):
		return
	var c: Control = panel as Control
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var release: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _dragging
	var accept: bool = event is InputEventKey and c.has_focus() \
		and event.is_action_pressed("ui_accept") and not event.echo
	if not click and not release and not accept:
		return
	c.accept_event()
	if click:
		if not _pending.is_empty() and _pending.get("panel") == panel:
			return
		_cancel_pending()
		_dragging = true
		_drag_origin = c.get_global_transform() * event.position
		var receipt: Dictionary = _receipt(panel, card_id)
		_pending = {"panel": panel, "id": card_id, "token": _token, "receipt": receipt}
		return
	if release:
		_dragging = false
		if _pending.is_empty() or _pending.get("panel") != panel or _pending.get("id") != card_id:
			_cancel_pending()
			return
		var release_pos: Vector2 = c.get_global_transform() * event.position
		if not c.get_global_rect().has_point(release_pos):
			_cancel_pending()
			return
		var receipt: Dictionary = _pending.get("receipt", {}) as Dictionary
		var token: int = int(_pending.get("token", -1))
		_commit.call_deferred(panel, card_id, token, receipt)
		return
	if accept:
		if not _pending.is_empty() and _pending.get("panel") == panel:
			return
		_cancel_pending()
		var receipt: Dictionary = _receipt(panel, card_id)
		_pending = {"panel": panel, "id": card_id, "token": _token, "receipt": receipt}
		_commit.call_deferred(panel, card_id, _token, receipt)
		return


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _dragging:
		_dragging = false
		if _pending.is_empty():
			_cancel_pending()
			return
		var panel: Variant = _pending.get("panel")
		if is_instance_valid(panel) and panel is Control and (panel as Control).get_global_rect().has_point(event.position):
			var card_id: String = str(_pending.get("id", ""))
			var token: int = int(_pending.get("token", -1))
			var receipt: Dictionary = _pending.get("receipt", {}) as Dictionary
			_commit.call_deferred(panel, card_id, token, receipt)
		else:
			_cancel_pending()
	if not _pending.is_empty() and event.is_action_pressed("ui_cancel"):
		_cancel_pending()
		get_viewport().set_input_as_handled()


func _receipt(panel: Variant, card_id: String) -> Dictionary:
	var app = get_parent()
	return {
		"battle": _battle,
		"deck": _deck,
		"party": _party,
		"enemies": _enemies,
		"result": _result,
		"round_flow": _round_flow,
		"rng": _rng,
		"turn": _turn,
		"panel": panel,
		"index": (panel as Control).get_index() if (is_instance_valid(panel) and panel is Control) else -1,
		"id": card_id,
		"intents": app.enemy_intents if app != null else null
	}


func _receipt_valid(receipt: Dictionary) -> bool:
	var app = get_parent()
	if app == null or not is_inside_tree():
		return false
	if app.get_node_or_null("LiveWardenReactionHand") != self:
		return false
	if receipt.get("battle") != _battle or receipt.get("deck") != _deck \
			or receipt.get("party") != _party or receipt.get("enemies") != _enemies \
			or receipt.get("result") != _result or receipt.get("round_flow") != _round_flow \
			or receipt.get("rng") != _rng:
		return false
	if app.enemy_intents != receipt.get("intents") or app.enemy_intents == null:
		return false
	if app.battle_view != _battle or app.deck != _deck or app.party != _party \
			or app.enemies != _enemies or app.battle_result != _result \
			or app.round_flow != _round_flow or app.run_rng != _rng:
		return false
	var panel: Variant = receipt.get("panel")
	if not is_instance_valid(panel) or not panel is Control:
		return false
	if (panel as Control).get_index() != int(receipt.get("index", -1)):
		return false
	return _turn_index(app) == int(receipt.get("turn", -2)) and _turn == int(receipt.get("turn", -2))


func _eligible(panel: Variant, card_id: String) -> bool:
	var app = get_parent()
	if app == null or not is_inside_tree():
		return false
	if _deck == null or _party == null or _enemies == null \
			or _result == null or _round_flow == null or not is_instance_valid(_battle):
		return false
	if not ALLOWED_CARD_IDS.has(card_id):
		return false
	if not _valid_panel(app, panel):
		return false
	if not _bindings.has(panel) or _bindings[panel]["id"] != card_id:
		return false
	var c: Control = panel as Control
	if not c.is_visible_in_tree() or not _battle.is_visible_in_tree():
		return false
	if app._battle_closed or not _deck.turn_active:
		return false
	if not _result.can_continue() or _result._party != _party or _result._enemies != _enemies:
		return false
	if not _party.is_valid() or _party.is_defeated():
		return false
	if not _enemies.is_valid() or _enemies.is_victorious():
		return false
	return app.deck == _deck and app.party == _party and app.enemies == _enemies \
		and app.battle_result == _result and app.run_rng == _rng and app.battle_view == _battle \
		and app.round_flow == _round_flow


func _commit(panel: Variant, card_id: String, token: int, receipt: Dictionary) -> void:
	if not is_inside_tree() or token != _token or _pending.get("token") != token:
		return
	if _pending.get("panel") != panel or _pending.get("id") != card_id:
		return
	_cancel_pending()
	if not _receipt_valid(receipt) or not _eligible(panel, card_id):
		return
	var app = get_parent()
	if app == null or app.round_flow == null:
		return
	var success: bool = app.round_flow.play_warden_reaction_card(card_id)
	if not success:
		_cancel_pending()
		return
	app._refresh_party()
	app._refresh_hand()
	if app.has_method("_refresh_enemy_roster"):
		app._refresh_enemy_roster()
	if app.has_method("_refresh_intents"):
		app._refresh_intents()
	if app._observe_battle_result() and is_instance_valid(app.end_turn_button):
		app.end_turn_button.grab_focus()
	_sync_battle()


func _cancel_pending() -> void:
	_token += 1
	_dragging = false
	_pending.clear()


func _clear() -> void:
	_cancel_pending()
	for panel: Variant in _bindings.keys():
		_unbind(panel)
	_bindings.clear()
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	_battle = null
	_deck = null
	_party = null
	_enemies = null
	_result = null
	_round_flow = null
	_rng = null
	_turn = -1
