extends Node
## Live selection only: targeting owns legality and attack cards own mutation.

signal forecast_updated

var cue: Label
var _battle: Control
var _deck: CombatDeck
var _bindings: Dictionary = {}
var _selected: Control
var _keyboard := false
var _targeting := CombatAttackTargeting.new()
var _catalog := StarterCards.new()
var _play := CombatAttackCards.new()
var _on_hit := CombatOnHitStatuses.new()
var last_event: Dictionary = {}
var _armed: Control
var _queued := false
var _token := 0
var _turn := -1
var _session: Array = []
var _stitched_preview := CombatStitchedTargetPreview.new()
var _choices: Array[int] = []
var _receipt: Dictionary = {}
var _run_map
var _target_ids: Array[String] = []
var current_forecast: Dictionary = {}
var _dragging := false
var _drag_origin := Vector2.ZERO


func _ledger() -> RunRestStitchCards:
	var app = get_parent()
	return RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)


func _stitch_preview(id: String) -> Dictionary:
	if not id.begins_with(RunRestStitchCards.ID_PREFIX):
		return {"playable": false}
	var app = get_parent()
	return _stitched_preview.get_preview(_ledger(), app._stitch_snapshot(), _deck, app.party, app.enemies, id)


func _is_stitched(panel) -> bool:
	return _card_id(panel).begins_with(RunRestStitchCards.ID_PREFIX)


func _cancel_choice() -> void:
	if is_instance_valid(_armed):
		_armed.set_meta("aiming", false)
	_dragging = false
	current_forecast.clear()
	_token += 1
	_queued = false
	_armed = null
	_choices.clear()
	_target_ids.clear()
	_receipt.clear()


func _arm_stitch() -> void:
	_choices.clear()
	_target_ids.clear()
	_receipt = get_parent()._stitch_snapshot()
	_run_map = get_parent().run_map
	get_viewport().gui_release_focus()
	_skip_automatic()


func _skip_automatic() -> void:
	var preview := _stitch_preview(_card_id(_armed))
	if not preview.playable:
		return
	while _choices.size() < 2 and not preview.halves[_choices.size()].requires_selection:
		_choices.append(0)
		_target_ids.append("")


func _choose_stitch(position: int, side: String = "") -> void:
	if _queued or not _eligible(_armed) or _receipt != get_parent()._stitch_snapshot() or _run_map != get_parent().run_map:
		return
	var preview := _stitch_preview(_card_id(_armed))
	if not preview.playable:
		return
	if _choices.size() < 2:
		var half: Dictionary = preview.halves[_choices.size()]
		if (not side.is_empty() and side != half.side) or position not in half.target_positions:
			return
		_choices.append(position)
		var app = get_parent()
		_target_ids.append(app.party.get_hero(position).id if half.side == "ally" else app.enemies.get_enemy(position).id)
		_skip_automatic()
	if _choices.size() == 2:
		_queued = true
		_commit_stitch.call_deferred(_armed, _card_id(_armed), _token, _session.duplicate(), _turn, _choices.duplicate(), _target_ids.duplicate(), _receipt.duplicate(true), _deck, _run_map)
	_refresh()


func _commit_stitch(panel, id: String, token: int, session: Array, turn: int, choices: Array, ids: Array, receipt: Dictionary, deck, map) -> void:
	var app = get_parent()
	if not is_inside_tree() or app == null or app.get_node_or_null("LiveAttackPreview") != self or token != _token or not _queued:
		return
	_queued = false
	if not _bindings.has(panel) or panel != _armed or not _eligible(panel) or _card_id(panel) != id or _bindings[panel].id != id:
		_reject_stitch()
		return
	if app.deck != deck or app.run_map != map or app._stitch_snapshot() != receipt or choices != _choices or ids != _target_ids \
		or session != [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents] \
		or app.enemy_intents == null or app.enemy_intents._turn_index != turn or _turn != turn:
		_reject_stitch()
		return
	var preview := _stitch_preview(id)
	if not preview.playable or choices.size() != 2:
		_reject_stitch()
		return
	for index in range(2):
		var half: Dictionary = preview.halves[index]
		if half.requires_selection:
			if choices[index] not in half.target_positions:
				_reject_stitch()
				return
			var actor: Dictionary = app.party.get_hero(choices[index]) if half.side == "ally" else app.enemies.get_enemy(choices[index])
			if actor.id != ids[index]:
				_reject_stitch()
				return
		elif choices[index] != 0:
			_reject_stitch()
			return
	last_event = CombatStitchedCards.new(_play).play_stitched(deck, app.party, app.enemies, _ledger(), id, choices[0], choices[1])
	if last_event.ok:
		_after_attack()
	else:
		_cancel_choice()
		_refresh()


## A real, current commit that failed revalidation retires its stale cue so no
## projection or armed arrow survives the rejection. Obsolete callbacks that
## arrive before this point return without touching a newer choice.
func _reject_stitch() -> void:
	_cancel_choice()
	_refresh()


func _after_attack() -> void:
	var app = get_parent()
	_cancel_choice()
	app._refresh_hand()
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_intents()
	app._observe_battle_result()
	_sync_battle()


func _process(_delta: float) -> void:
	_sync_battle()


func _input(event: InputEvent) -> void:
	_sync_battle()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_choice()
		_selected = null
		_refresh()
		return
	if event is InputEventMouseMotion and _bindings.has(_armed):
		_armed.set_meta("aim_point", event.position)
		_armed.set_meta("aiming", true)
		_armed.queue_redraw()
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _dragging:
		_dragging = false
		if is_instance_valid(_armed):
			_armed.set_meta("aiming", false)
		if _bindings.has(_armed) and not _single(_armed) and _armed.get_global_rect().has_point(event.position):
			if _is_stitched(_armed):
				_choose_stitch(0)
			else:
				_queue_attack(0)
			return
		if event.position.distance_to(_drag_origin) > 10:
			var press := InputEventMouseButton.new()
			press.position = event.position
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			_input(press)
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _bindings.has(_armed) and _is_stitched(_armed):
			var app = get_parent()
			for index in range(app.hero_panels.size()):
				var hero: Control = app.hero_panels[index]
				if hero.is_visible_in_tree() and hero.get_global_rect().has_point(event.position):
					_choose_stitch(index + 1, "ally")
					return
		var roster = get_parent().get_node_or_null("LiveEnemyRoster")
		if roster != null and is_instance_valid(_armed):
			for index in range(roster._labels.size()):
				var label: Label = roster._labels[index]
				if label.is_visible_in_tree() and label.get_global_rect().has_point(event.position):
					if _is_stitched(_armed):
						_choose_stitch(index + 1, "enemy")
					else:
						_queue_attack(index + 1 if _single(_armed) else 0)
					get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ENTER, KEY_SPACE] and _bindings.has(_armed) and not _single(_armed):
		# Only a target-free keyboard selection owns Enter/Space. A real focused
		# control keeps its activation; P clears the inherited battle focus.
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or focus == _armed or not focus.is_visible_in_tree():
			if _is_stitched(_armed):
				if _choices.size() == 2:
					_choose_stitch(0)
			else:
				_queue_attack(0)
			get_viewport().set_input_as_handled()
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_3:
		if _bindings.has(_armed) and _is_stitched(_armed):
			_choose_stitch(event.keycode - KEY_1 + 1)
			get_viewport().set_input_as_handled()
			return
		_queue_attack(event.keycode - KEY_1 + 1)
		return
	if event.keycode != KEY_P:
		return
	var panels: Array[Control] = []
	# Cycle actual held instances, not unique IDs: identical copies own their
	# own input listeners, highlights, and pending selection.
	for panel in get_parent().hand_view.get_children():
		if _bindings.has(panel) and _eligible(panel):
			panels.append(panel)
	if panels.is_empty():
		return
	var index := panels.find(_selected)
	_selected = panels[(index + 1) % panels.size()]
	_armed = _selected
	if not _single(_armed):
		# Attack keyboard selection must not inherit End Turn/Return focus.
		get_viewport().gui_release_focus()
	_token += 1
	_queued = false
	_keyboard = true
	if _is_stitched(_armed):
		_arm_stitch()
	_refresh()
	get_viewport().set_input_as_handled()


func _single(panel) -> bool:
	if _is_stitched(panel):
		return _choices.size() < 2
	return _catalog.get_definition(_card_id(panel)).get("target_kind") == "enemy_single"


func _select(event: InputEvent, panel) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _queued or not _bindings.has(panel) or not _eligible(panel) or _bindings[panel].id != _card_id(panel):
		return
	_token += 1
	_queued = false
	_armed = panel
	_dragging = true
	_drag_origin = panel.get_global_transform() * event.position
	_selected = panel
	_keyboard = true
	if _is_stitched(panel):
		_arm_stitch()
	panel.accept_event()
	_refresh()
	if _is_stitched(panel):
		return


func _queue_attack(position: int) -> void:
	if _queued or not _bindings.has(_armed) or not _eligible(_armed):
		return
	var app = get_parent()
	var preview := _targeting.get_preview(_deck, app.party, app.enemies, _card_id(_armed))
	if not preview.playable or (position not in preview.target_positions if preview.requires_selection else position != 0):
		return
	_queued = true
	_commit.call_deferred(_armed, _card_id(_armed), position, _token,
		app.party, app.enemies, app.battle_result, app.run_rng, _turn)


func _commit(panel, id: String, position: int, token: int, party, enemies, result, rng, turn: int) -> void:
	var app = get_parent()
	if not is_inside_tree() or app == null or app.get_node_or_null("LiveAttackPreview") != self or token != _token or not _queued:
		return
	_queued = false
	if not _bindings.has(panel) or panel != _armed or not _eligible(panel) or _card_id(panel) != id or _bindings[panel].id != id:
		return
	if app.party != party or app.enemies != enemies or app.battle_result != result or app.run_rng != rng \
			or app.enemy_intents == null or app.enemy_intents._turn_index != turn or _turn != turn \
			or _session != [party, enemies, result, rng, app.enemy_intents]:
		return
	var preview := _targeting.get_preview(_deck, party, enemies, id)
	if not preview.playable or (position not in preview.target_positions if preview.requires_selection else position != 0):
		return
	last_event = _resolve_attack(party, enemies, id, position)
	if last_event.ok:
		_after_attack()


func _resolve_attack(party: CombatParty, enemies: CombatEnemies, id: String, position: int, forecast: bool = false) -> Dictionary:
	var owner_statuses: Dictionary = {}
	var owner: String = _catalog.get_definition(id).get("owner", "")
	for hero in party.get_heroes():
		if hero.id == owner:
			# Malformed authoritative status fields must reject rather than coerce.
			if not hero.get("statuses", {}) is Dictionary:
				return {"playable": false, "requires_selection": false, "hits": []} if forecast else {"ok": false, "hits": []}
			owner_statuses = hero.get("statuses", {})
	var enemy_statuses := {}
	for enemy in enemies.get_enemies():
		enemy_statuses[enemy.position] = enemy.get("statuses", {})
	if forecast:
		return _play.forecast_attack(_deck, party, enemies, id, owner_statuses, enemy_statuses)
	return _play.play_attack(_deck, party, enemies, id, position, owner_statuses, enemy_statuses)


func _card_id(panel) -> String:
	if not is_instance_valid(panel) or panel.get_child_count() == 0 or not panel.get_child(0) is Label:
		return ""
	return panel.get_child(0).text


func _eligible(panel) -> bool:
	var app = get_parent()
	if not is_inside_tree() or app == null or not is_instance_valid(panel) or not is_instance_valid(_battle) or _deck == null:
		return false
	if app.deck != _deck or app.battle_view != _battle or not is_instance_valid(app.hand_view):
		return false
	if not _battle.is_ancestor_of(app.hand_view) or not _battle.is_visible_in_tree() or not panel.is_visible_in_tree() or panel.get_parent() != app.hand_view:
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
	return (id in CombatAttackTargeting.ATTACK_IDS or _stitch_preview(id).playable) and index < _deck.hand.size() and _deck.hand[index] == id


func _sync_battle() -> void:
	var app = get_parent()
	if app.deck == null or not is_instance_valid(app.battle_view) or not is_instance_valid(app.hand_view):
		_clear()
		return
	if _battle != app.battle_view or _deck != app.deck:
		_clear()
		_battle = app.battle_view
		_deck = app.deck
		_session = [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents]
		_play = CombatAttackCards.new()
		# Capture the genuine run's sewn wearer projection at battle entry only.
		# An invalid present binding must reject attacks, not fall back to vanilla.
		var carry := app.party_carryover as RunTornCarryover
		if carry != null and carry._wardrobe != null:
			var wardrobe: RunPatchWardrobe = carry._wardrobe
			var current: Dictionary = wardrobe.get_snapshot()
			if carry.can_bind_wardrobe(wardrobe, carry.torn, current) \
					and current.heroes == app.run_heroes and current.owned == app.run_trinkets \
					and current.cards == app.run_deck and current.scraps == app.run_scraps \
					and current.gold == app.session_gold and current.seed == app.run_seed:
				_play.bind_patch_wardrobe(wardrobe, carry.torn)
			else:
				_play.bind_patch_wardrobe(null, null)
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
	if _session != [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents]:
		_cancel_choice()
		_session = [app.party, app.enemies, app.battle_result, app.run_rng, app.enemy_intents]
	if app.enemy_intents != null and _turn != app.enemy_intents._turn_index:
		_turn = app.enemy_intents._turn_index
		_play.start_player_turn()
		_cancel_choice()
	if _bindings.has(_armed) and _is_stitched(_armed) and (_receipt != app._stitch_snapshot() or _run_map != app.run_map):
		_cancel_choice()
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
	if _selected == panel and not _keyboard and _armed != panel:
		_selected = null
		_refresh()


func _refresh() -> void:
	current_forecast = {}
	if not is_instance_valid(cue):
		return
	if not _bindings.has(_selected) or not _eligible(_selected):
		_selected = null
		cue.text = "" if _bindings.is_empty() else "Attack preview: hover an attack | P: cycle held attacks"
		return
	var app = get_parent()
	var id := _card_id(_selected)
	if _is_stitched(_selected):
		var stitched := _stitch_preview(id)
		if not stitched.playable:
			cue.text = "Unavailable stitched card"
			return
		var names: PackedStringArray = []
		for half in stitched.halves:
			names.append(_catalog.get_definition(half.card_id).display_name)
		var details: PackedStringArray = []
		for index in range(2):
			var half: Dictionary = stitched.halves[index]
			details.append("%d: %s %s" % [index + 1, half.side, str(half.target_positions) if half.requires_selection else "automatic (0), slots " + str(half.affected_positions)])
		var controls := "Half %d: 1-3 / click hero or enemy" % mini(_choices.size() + 1, 2)
		if _selected == _armed and _choices.size() == 2:
			controls = "Enter / Space / click card: cast"
		cue.text = "%s | %d energy | %s\n%s; Esc: cancel" % [" / ".join(names), stitched.cost, "; ".join(details), controls]
		if _selected == _armed and _choices.size() == 2 and _receipt == app._stitch_snapshot() and _run_map == app.run_map:
			current_forecast = CombatStitchedEffectForecast.new().get_forecast(_ledger(), _receipt, _deck, app.party, app.enemies, id, _choices[0], _choices[1], CombatStitchedCards.new(_play))
			if current_forecast.playable:
				var outcomes: PackedStringArray = []
				for index in range(2):
					var half: Dictionary = current_forecast.halves[index]
					var effects: PackedStringArray = []
					for hit in half.get("hits", []):
						effects.append("enemy %d: %d damage" % [hit.position, hit.damage])
					if half.has("effect"):
						effects.append("%s %d" % [half.effect.replace("_", " ").capitalize(), half.amount])
					outcomes.append("%d: %s" % [index + 1, ", ".join(effects)])
				cue.text = "%s | %d energy\nProjected %s" % [" / ".join(names), stitched.cost, "; ".join(outcomes)]
				forecast_updated.emit()
			else:
				cue.text = "Unavailable stitched outcome; Esc: cancel"
		return
	var definition := _catalog.get_definition(id)
	var preview := _resolve_attack(app.party, app.enemies, id, 0, true)
	var targets: PackedStringArray = []
	# Only attach on-hit counters to recipients accepted by the authoritative
	# forecast. The adapter describes a *conditional* confirmed hit, not a
	# future mutation or a promise that the player will cast this card.
	var additions: Dictionary = _on_hit.status_for_confirmed_hit(id, true) if preview.playable else {}
	if preview.playable and _play._patches != null:
		var patch_statuses: Dictionary = _play._patches.exposed_for_first_hit(definition.get("owner", ""))
		for status in patch_statuses:
			additions[status] = additions.get(status, 0) + patch_statuses[status]
	for hit in preview.hits:
		var detail := "%d: %d damage" % [hit.position, hit.damage]
		var enemy: Dictionary = app.enemies.get_enemy(hit.position)
		var current: Dictionary = enemy.get("statuses", {})
		for status in additions:
			var amount: int = additions[status]
			var previous: int = current.get(status, 0)
			detail += " (%s %d → %d on confirmed hit)" % [status.capitalize(), previous, previous + amount]
		targets.append(detail)
	var description := "Unavailable: no legal targets or energy"
	if preview.playable:
		description = ("Choose one enemy slot: " if preview.requires_selection else "All enemies in slots: ") + "; ".join(targets)
	var controls := "P / click card; 1-3 / click enemy" if _single(_selected) else "P: select; Enter / Space / click card: cast"
	cue.text = "%s | %d energy | %s\n%s" % [definition.display_name, definition.cost, controls, description]


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
		_cancel_choice()


func _clear() -> void:
	_cancel_choice()
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
	_session = []
	_play = CombatAttackCards.new() # Return/title retires the prior battle's wearer latch.
	_selected = null
