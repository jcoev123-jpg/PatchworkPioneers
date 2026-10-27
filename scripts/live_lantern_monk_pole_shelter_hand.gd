extends Node
## Scene-mounted, presentation-only Pole Shelter chooser. The paid rules live exclusively
## in CombatLanternMonkPoleShelterCards; this node never mutates a roster to preview.
const IDS := ["lantern_monk_pole_shelter", "lantern_monk_pole_shelter_plus"]
const WAX_IDS := ["lantern_monk_wax_ward", "lantern_monk_wax_ward_plus"]
const DEBUFFS := ["bleed", "weak", "exposed"]
var _service := CombatLanternMonkPoleShelterCards.new()
var _wax_service := CombatLanternMonkWaxWardCards.new()
var _bind_serial := 0
var _wax_finishing := false
var _bindings: Dictionary = {}
var _pending: Dictionary = {}
var _epoch := 0
var choice_panel: PanelContainer
var ally_row: HBoxContainer
var debuff_row: HBoxContainer
var cancel_button: Button
var caption: Label


func _process(_delta: float) -> void:
	_sync_battle()


func _input(event: InputEvent) -> void:
	if not _pending.is_empty() and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()


func _current() -> bool:
	var app = get_parent()
	# The app owns live route/session, result, roster and round-flow authentication.
	return app._combo_battle_current()


func _panel_id(panel: Variant) -> String:
	var app = get_parent()
	if not is_instance_valid(panel) or not panel is PanelContainer \
			or not is_instance_valid(app.hand_view) or app.deck == null:
		return ""
	if panel.get_parent() != app.hand_view or not panel.is_visible_in_tree() \
			or not app.hand_view.is_visible_in_tree() or panel.get_child_count() == 0 \
			or not panel.get_child(0) is Label:
		return ""
	var index: int = panel.get_index()
	if index < 0 or index >= app.deck.hand.size():
		return ""
	var id: String = app.deck.hand[index]
	if (id not in IDS and id not in WAX_IDS) or panel.get_child(0).text != id:
		return ""
	return id


func _sync_battle() -> void:
	if _wax_finishing:
		return
	if not _current():
		_cancel(false)
		_unbind_all()
		return
	var app = get_parent()
	for panel in _bindings.keys():
		if not is_instance_valid(panel) or _panel_id(panel) != _bindings[panel].id \
				or _bindings[panel].index != panel.get_index():
			_unbind(panel)
	for panel in app.hand_view.get_children():
		if _bindings.has(panel):
			continue
		var id := _panel_id(panel)
		if id.is_empty():
			continue
		_bind_serial += 1
		var callback := _card_input.bind(panel, id, panel.get_index(), _bind_serial)
		_bindings[panel] = {"id": id, "index": panel.get_index(), "callback": callback,
			"token": _bind_serial, "context": _snapshot() if id in WAX_IDS else {}}
		panel.gui_input.connect(callback)
		panel.focus_mode = Control.FOCUS_ALL
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if id in WAX_IDS:
			panel.tooltip_text = "%s | Cost 1 | Block %d | self" % [
				"Wax Ward+" if id.ends_with("_plus") else "Wax Ward",
				7 if id.ends_with("_plus") else 5]
		else:
			panel.tooltip_text = "%s | Cost 1 | Block %d | Choose living ally; remove one chosen present Bleed, Weak or Exposed" % [
				"Pole Shelter+" if id.ends_with("_plus") else "Pole Shelter",
				7 if id.ends_with("_plus") else 5]
	if not _pending.is_empty() and not _pending_valid():
		_cancel()


func _unbind(panel: Variant) -> void:
	if not _bindings.has(panel):
		return
	var callback: Callable = _bindings[panel].callback
	if is_instance_valid(panel):
		if panel.gui_input.is_connected(callback):
			panel.gui_input.disconnect(callback)
		panel.focus_mode = Control.FOCUS_NONE
		panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_bindings.erase(panel)
	if _pending.get("panel") == panel:
		_cancel()


func _unbind_all() -> void:
	for panel in _bindings.keys():
		_unbind(panel)


func _target_options(position: int) -> Array[String]:
	var app = get_parent()
	var options: Array[String] = []
	if app.party == null or position < 1 or position > 3:
		return options
	var statuses: Variant = app.party.get_hero(position).get("statuses", {})
	if not statuses is Dictionary:
		return options
	for kind: String in DEBUFFS:
		var count: Variant = statuses.get(kind, 0)
		if count is int and count > 0:
			options.append(kind)
	return options


func _can_target(id: String, position: int) -> bool:
	var app = get_parent()
	if not _current() or position < 1 or position > 3:
		return false
	var options := _target_options(position)
	var choice := options[0] if not options.is_empty() else ""
	return _service._prepare(app.deck, app.party, id, position, choice).get("ok", false)


func _source_valid(panel: Variant, id: String, index: int) -> bool:
	var app = get_parent()
	return _current() and _bindings.has(panel) and _bindings[panel].id == id \
		and _bindings[panel].index == index and is_instance_valid(panel) \
		and panel.get_index() == index and _panel_id(panel) == id


## Snapshot identity *and* mutable values. A later callback cannot inherit the next
## fight, redraw, enemy/hero alteration, turn, card copy, energy or RNG stream.
func _snapshot() -> Dictionary:
	var app = get_parent()
	return {
		"view": app.battle_view, "deck": app.deck, "state": app.deck.combat_state,
		"party": app.party, "enemies": app.enemies, "result": app.battle_result,
		"flow": app.round_flow, "intents": app.enemy_intents, "rng": app.run_rng,
		"map": app.run_map, "carry": app.party_carryover, "encounter": app.encounter_id,
		"turn": app.enemy_intents._turn_index, "intent_records": app.enemy_intents.get_intents(),
		"hand": app.deck.hand.duplicate(), "draw": app.deck.draw_pile.duplicate(),
		"discard": app.deck.discard_pile.duplicate(), "energy": app.deck.energy,
		"active": app.deck.turn_active, "seed": app.run_rng.seed,
		"rng_state": app.run_rng.state, "heroes": app.party.get_heroes(),
		"enemy_records": app.enemies.get_enemies(), "gold": app.session_gold,
		"closed": app._battle_closed,
	}


func _pending_valid() -> bool:
	if _pending.is_empty() or not _source_valid(_pending.panel, _pending.id, _pending.index):
		return false
	if _pending.epoch != _epoch or not is_instance_valid(choice_panel):
		return false
	if _snapshot() != _pending.context:
		return false
	if _pending.get("target", 0) != 0:
		var target: int = _pending.target
		if not _can_target(_pending.id, target) or _target_options(target) != _pending.options:
			return false
	return true


func _card_input(event: InputEvent, panel: Variant, id: String, index: int, token: int) -> void:
	if _wax_finishing or not _source_valid(panel, id, index) or _bindings[panel].token != token:
		return
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var key: bool = event is InputEventKey and panel.has_focus() \
			and event.pressed and not event.echo and event.is_action_pressed("ui_accept")
	if not click and not key:
		return
	panel.accept_event()
	if not _pending.is_empty():
		return
	if id in WAX_IDS:
		_play_wax(panel, id, index, token)
		return
	var possible := false
	for position in range(1, 4):
		if _can_target(id, position):
			possible = true
	if not possible:
		return
	_open(panel, id, index)


## Wax Ward is a self-only card: no target chooser and no explicit seat argument.
## A binding's original context and token cannot be reused after a redraw or turn.
func _play_wax(panel: Variant, id: String, index: int, token: int) -> void:
	if not _source_valid(panel, id, index) or _bindings[panel].token != token:
		return
	if _bindings[panel].context != _snapshot():
		_focus_action()
		return
	var app = get_parent()
	if not _wax_service._prepare(app.deck, app.party, id, 0).get("ok", false):
		_focus_action()
		return
	# Retire this listener before the paid service. Duplicate presses and old
	# callbacks cannot inherit another copy in the newly drawn hand.
	_unbind(panel)
	var receipt: Dictionary = _wax_service.play_card(app.deck, app.party, id)
	if receipt.get("ok", false):
		# A panel cannot be freed while Godot is delivering its gui_input.
		# Settle the UI once, on the deferred frame, with replay blocked meanwhile.
		_wax_finishing = true
		call_deferred("_finish_wax_play")
	else:
		_focus_action()


func _finish_wax_play() -> void:
	if not _wax_finishing:
		return
	var app = get_parent()
	app._refresh_party()
	app._refresh_hand()
	app._refresh_intents()
	app._observe_battle_result()
	_wax_finishing = false
	_focus_action()


func _style() -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("302b26")
	skin.border_color = Color("c9b996")
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(8)
	skin.content_margin_left = 16
	skin.content_margin_right = 16
	skin.content_margin_top = 10
	skin.content_margin_bottom = 10
	return skin


func _button(parent: Node, label: String, name: String) -> Button:
	var button := Button.new()
	button.name = name
	button.text = label
	button.add_theme_font_size_override("font_size", 20)
	button.custom_minimum_size = Vector2(180, 45)
	button.focus_mode = Control.FOCUS_ALL
	parent.add_child(button)
	return button


func _focus_row(row: HBoxContainer) -> void:
	var active: Array[Button] = []
	for child in row.get_children():
		if child is Button and not child.disabled:
			active.append(child)
	for i in range(active.size()):
		active[i].focus_next = active[i].get_path_to(active[(i + 1) % active.size()])
		active[i].focus_previous = active[i].get_path_to(active[(i + active.size() - 1) % active.size()])
		active[i].focus_neighbor_left = active[i].focus_previous
		active[i].focus_neighbor_right = active[i].focus_next
	if not active.is_empty():
		active[0].grab_focus()


func _open(panel: PanelContainer, id: String, index: int) -> void:
	_epoch += 1
	_pending = {"panel": panel, "id": id, "index": index, "epoch": _epoch,
		"context": _snapshot(), "target": 0}
	choice_panel = PanelContainer.new()
	choice_panel.name = "PoleShelterChoices"
	choice_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	choice_panel.position = Vector2(210, 310)
	choice_panel.custom_minimum_size = Vector2(860, 0)
	choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_panel.add_theme_stylebox_override("panel", _style())
	get_parent().add_child(choice_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	choice_panel.add_child(stack)
	caption = Label.new()
	caption.name = "PoleShelterForecast"
	caption.text = "%s  |  Cost 1 energy  |  Block %d  — Choose a living ally (Tab / arrows / Enter / Space)" % [
		"Pole Shelter+" if id.ends_with("_plus") else "Pole Shelter",
		7 if id.ends_with("_plus") else 5]
	caption.add_theme_font_size_override("font_size", 20)
	stack.add_child(caption)
	ally_row = HBoxContainer.new()
	ally_row.name = "PoleShelterAllies"
	ally_row.add_theme_constant_override("separation", 8)
	stack.add_child(ally_row)
	for position in range(1, 4):
		var hero: Dictionary = get_parent().party.get_hero(position)
		var button := _button(ally_row, "%d · %s" % [position, hero.get("name", hero.get("id", ""))],
			"Ally%d" % position)
		button.disabled = not _can_target(id, position)
		button.tooltip_text = "Block %d; remove a chosen present Bleed, Weak or Exposed" % [
			7 if id.ends_with("_plus") else 5]
		button.pressed.connect(_choose_ally.bind(position, _epoch))
	debuff_row = HBoxContainer.new()
	debuff_row.name = "PoleShelterDebuffs"
	debuff_row.add_theme_constant_override("separation", 8)
	stack.add_child(debuff_row)
	cancel_button = _button(stack, "Cancel (Esc)", "PoleShelterCancel")
	cancel_button.pressed.connect(_cancel)
	_focus_row(ally_row)


func _choose_ally(position: int, epoch: int) -> void:
	if epoch != _epoch or not _pending_valid() or not _can_target(_pending.id, position):
		_cancel()
		return
	_pending.target = position
	_pending.options = _target_options(position)
	var hero: Dictionary = get_parent().party.get_hero(position)
	caption.text = "%s -> %s  |  Cost 1  |  Block %d  |  Choose present debuff to remove" % [
		"Pole Shelter+" if _pending.id.ends_with("_plus") else "Pole Shelter",
		hero.get("name", hero.get("id", "")), 7 if _pending.id.ends_with("_plus") else 5]
	for child in debuff_row.get_children():
		child.free()
	if _pending.options.is_empty():
		_commit(position, "", epoch)
		return
	for kind: String in _pending.options:
		var count: int = hero.get("statuses", {}).get(kind, 0)
		var button := _button(debuff_row, "Remove %s (%d)" % [kind.capitalize(), count], kind.capitalize())
		button.pressed.connect(_choose_debuff.bind(kind, position, epoch))
	_focus_row(debuff_row)


func _choose_debuff(kind: String, position: int, epoch: int) -> void:
	if epoch != _epoch or not _pending_valid() or _pending.target != position \
			or not _pending.options.has(kind):
		_cancel()
		return
	_commit(position, kind, epoch)


func _commit(position: int, kind: String, epoch: int) -> void:
	if epoch != _epoch or not _pending_valid() or _pending.target != position \
			or (kind != "" and not _pending.options.has(kind)) \
			or (kind == "" and not _pending.options.is_empty()) \
			or not _service._prepare(get_parent().deck, get_parent().party, _pending.id, position, kind).get("ok", false):
		_cancel()
		return
	var app = get_parent()
	var id: String = _pending.id
	# Consume this panel's one-shot receipt before invoking the authoritative service.
	_cancel(false)
	var receipt: Dictionary = _service.play_card(app.deck, app.party, id, position, kind)
	if not receipt.get("ok", false):
		_focus_action()
		return
	app._refresh_party()
	app._refresh_hand()
	app._refresh_intents()
	app._observe_battle_result()
	_focus_action()


func _focus_action() -> void:
	var app = get_parent()
	if is_instance_valid(app.end_turn_button) and app.end_turn_button.is_visible_in_tree() \
			and not app.end_turn_button.disabled:
		app.end_turn_button.grab_focus()
	elif is_instance_valid(app.return_button) and app.return_button.is_visible_in_tree():
		app.return_button.grab_focus()


func _cancel(restore_focus: bool = true) -> void:
	var had_choice := not _pending.is_empty()
	_epoch += 1
	_pending.clear()
	if is_instance_valid(choice_panel):
		choice_panel.queue_free()
	choice_panel = null
	ally_row = null
	debuff_row = null
	cancel_button = null
	caption = null
	if had_choice and restore_focus:
		_focus_action()
