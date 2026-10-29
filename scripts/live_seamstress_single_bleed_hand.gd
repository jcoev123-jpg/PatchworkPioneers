extends Node
## Enemy-single Seamstress Bleed cards, mounted beneath LiveAreaAttackAction.
## D2 is paid only by CombatSeamstressPoolBleed; the six authenticated V3
## printings are paid only by CombatSeamstressV3RedThreadCards.

const CARD_IDS := [
	"seamstress_running_stitch", "seamstress_running_stitch_plus",
	"seamstress_hemorrhage_hem", "seamstress_hemorrhage_hem_plus",
	"seamstress_red_thread", "seamstress_red_thread_plus",
]
const V3_IDS := [
	"seamstress_v3_thread_prick", "seamstress_v3_thread_prick_plus",
	"seamstress_v3_needle_rain", "seamstress_v3_needle_rain_plus",
	"seamstress_v3_scarlet_knot", "seamstress_v3_scarlet_knot_plus",
]
const CREAM := Color("#ece0c8")
const INK := Color("#3d3440")
const THREAD := Color("#6e4f6b")
const RUST := Color("#9e6f58")
const INSTRUCTION := "Click or focus and press Enter / Space; choose a living enemy (Escape cancels)"

var _catalog := SeamstressPoolCards.new()
var _service := CombatSeamstressPoolBleed.new()
var _v3_service := CombatSeamstressV3RedThreadCards.new()


## Only authentic catalog printings may enter the mounted target chooser.
func _definition(card_id: String) -> Dictionary:
	if card_id in V3_IDS:
		return _v3_service._catalog_definition(card_id) if _v3_service.is_authentic_card(card_id) else {}
	return _catalog.get_definition(card_id)


func _supported(card_id: String) -> bool:
	return card_id in CARD_IDS or (card_id in V3_IDS and _v3_service.is_authentic_card(card_id))
var _battle: Control
var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies
var _result: CombatBattleResult
var _rng: RandomNumberGenerator
var _intents
var _turn := -1
var _token := 0
var _bindings: Dictionary = {}
var _choice: Dictionary = {}
var _targets: Dictionary = {}
var target_strip: PanelContainer
var _preview: Label
var _overlay: Control
var last_event: Dictionary = {}


func _app():
	return get_parent().get_parent() if get_parent() != null else null


func _process(_delta: float) -> void:
	_sync_battle()


func _input(event: InputEvent) -> void:
	if _choice.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
		_cancel(true)
		get_viewport().set_input_as_handled()


func _turn_index(app) -> int:
	return int(app.enemy_intents._turn_index) if app.enemy_intents != null else -1


func _live() -> bool:
	var app = _app()
	if app == null or not is_inside_tree() or get_parent().get_node_or_null(NodePath(name)) != self:
		return false
	return app.get_node_or_null("LiveAreaAttackAction") == get_parent() 		and app.deck == _deck and app.party == _party and app.enemies == _enemies 		and app.battle_result == _result and app.battle_view == _battle 		and app.run_rng == _rng and app.enemy_intents == _intents 		and _deck != null and _party != null and _enemies != null 		and _result != null and _intents != null and is_instance_valid(_battle) 		and is_instance_valid(app.hand_view) and not app._battle_closed 		and _battle.is_visible_in_tree() and _deck.turn_active 		and _result.can_continue() and _result._party == _party 		and _result._enemies == _enemies and _party.is_valid() 		and not _party.is_defeated() and _enemies.is_valid() 		and not _enemies.is_victorious() and _turn_index(app) == _turn


func _valid_panel(panel, card_id: String) -> bool:
	var app = _app()
	if app == null or not is_instance_valid(panel) or not is_instance_valid(app.hand_view) 			or panel.get_parent() != app.hand_view or not _bindings.has(panel):
		return false
	var index: int = panel.get_index()
	return _bindings[panel].id == card_id and _supported(card_id) 		and index >= 0 and index < _deck.hand.size() 		and _deck.hand[index] == card_id and panel.get_child_count() > 0 		and panel.get_child(0) is Label and panel.get_child(0).text == card_id


func _affordable(panel, card_id: String) -> bool:
	if not _live() or not _valid_panel(panel, card_id) 			or not panel.is_visible_in_tree():
		return false
	var definition: Dictionary = _definition(card_id)
	if definition.get("id") != card_id or definition.get("owner") != "seamstress" 			or definition.get("target_kind") != "enemy_single":
		return false
	var from: Array = definition.get("from_positions", [])
	var owners := 0
	var legal_owner := false
	for hero in _party.get_heroes():
		if hero["id"] == "seamstress":
			owners += 1
			legal_owner = hero["hp"] > 0 and from.has(hero["position"])
	if owners != 1 or not legal_owner or _deck.energy < int(definition.get("cost", -1)) 			or int(definition.get("cost", -1)) < 0:
		return false
	if card_id in V3_IDS:
		# Preflight real original living slots before offering an actionable picker.
		for enemy in _enemies.get_enemies():
			var position: int = enemy["position"]
			if definition.get("to_positions", []).has(position) and enemy["hp"] > 0 					and _v3_service._prepare(_deck, _party, _enemies, card_id, position).get("ok", false):
				return true
		return false
	return true


func _sync_battle() -> void:
	var app = _app()
	if app == null or app.deck == null or app.party == null or app.enemies == null 			or app.battle_result == null or app.enemy_intents == null 			or not is_instance_valid(app.battle_view) 			or not is_instance_valid(app.hand_view):
		if _battle != null or not _bindings.is_empty() or not _choice.is_empty():
			_clear()
		return
	if _battle != app.battle_view or _deck != app.deck or _party != app.party 			or _enemies != app.enemies or _result != app.battle_result 			or _rng != app.run_rng or _intents != app.enemy_intents:
		_clear()
		_battle = app.battle_view
		_deck = app.deck
		_party = app.party
		_enemies = app.enemies
		_result = app.battle_result
		_rng = app.run_rng
		_intents = app.enemy_intents
		_turn = _turn_index(app)
		last_event.clear()
		_service = CombatSeamstressPoolBleed.new()
		var carry = app.party_carryover
		if carry is RunTornCarryover and carry._wardrobe != null:
			var wardrobe: RunPatchWardrobe = carry._wardrobe
			var current: Dictionary = wardrobe.get_snapshot() if wardrobe != null else {}
			if wardrobe != null and carry.torn != null and wardrobe.is_valid() and carry.torn.is_valid() \
					and carry.can_bind_wardrobe(wardrobe, carry.torn, current) \
					and current.heroes == app.run_heroes and current.owned == app.run_trinkets \
					and current.cards == app.run_deck and current.scraps == app.run_scraps \
					and current.gold == app.session_gold and current.seed == app.run_seed:
				_service.bind_patch_wardrobe(wardrobe, carry.torn)
			else:
				_service.bind_patch_wardrobe(null, null)
		_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
	elif _turn != _turn_index(app):
		_turn = _turn_index(app)
		_cancel()
	# The battle result must witness this exact roster.
	if not _party.is_valid() or not _enemies.is_valid() 			or _result._party != _party or _result._enemies != _enemies:
		_cancel()
		for panel in _bindings.keys():
			_unbind(panel)
		return
	for panel in _bindings.keys():
		if not _valid_panel(panel, _bindings[panel].id):
			_unbind(panel)
	for panel in app.hand_view.get_children():
		if panel.get_child_count() == 0 or not panel.get_child(0) is Label:
			continue
		var card_id: String = panel.get_child(0).text
		if not _supported(card_id) or _bindings.has(panel):
			continue
		var index: int = panel.get_index()
		if index >= 0 and index < _deck.hand.size() and _deck.hand[index] == card_id:
			_bind(panel, card_id)
	if not _choice.is_empty() and not _selection_valid():
		_cancel()
	if not _bindings.is_empty() and is_instance_valid(app.end_turn_button):
		_focus_chain(app)


func _bind(panel: Control, card_id: String) -> void:
	var callback := _on_card_input.bind(panel, card_id)
	_bindings[panel] = {"id": card_id, "callback": callback}
	panel.focus_mode = Control.FOCUS_ALL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = CREAM
	focus.set_border_width_all(3)
	panel.add_theme_stylebox_override("focus", focus)
	var definition: Dictionary = _definition(card_id)
	var metadata = _app().get_node("LiveSupportHand")._metadata
	panel.tooltip_text = INSTRUCTION + "\n" + metadata.base_effect_text(card_id)
	panel.gui_input.connect(callback)


## The genuine, pure projection the mounted strip describes. It reads the exact
## per-target status delta the authoritative resolver will commit, so a sewn
## Bloodstitch Bonnet / Red Bobbin Cuff and the Bloodline passive are shown as
## they really are instead of a fixed authored-plus-one guess. An unprojected
## strip (no legal target yet) states no number at all.
func _projected_bleed(definition: Dictionary, legal: Array[int]) -> Dictionary:
	if str(definition.get("id", "")) in V3_IDS:
		return {} # V3 previews report authored effects, never a D2 HP forecast.
	if legal.is_empty():
		return {}
	return _service.forecast_single(
		_deck, _party, _enemies, str(definition.get("id", "")), legal[0])


func _bleed_detail(definition: Dictionary, outcome: Dictionary) -> String:
	var effects: Dictionary = definition.get("effects", {})
	if effects.has("bleed_multiplier"):
		# Hemorrhage doubles whatever the chosen enemy already carries; there is
		# no flat passive or sewn amount to print before that target is known.
		return "Doubles the chosen enemy's CURRENT Bleed (no flat passive or sewn bonus; the preview shows N -> 2N)"
	var authored: int = int(effects.get("bleed", 0))
	var applied: int = authored
	if outcome.get("ok", false):
		applied = int(outcome.get("bleed_after", 0)) - int(outcome.get("bleed_before", 0))
	var summary := "Bleed per the chosen enemy's forecast"
	if outcome.get("ok", false):
		if applied > authored:
			summary = "Bleed %d (authored %d + %d passive/sewn)" % [
				applied, authored, applied - authored]
		else:
			summary = "Bleed %d (authored %d)" % [applied, authored]
	if effects.has("damage"):
		return "%d damage; %s" % [int(effects["damage"]), summary]
	return "%s; Exposed %d" % [summary, int(effects.get("exposed", 0))]


func _rule_text(definition: Dictionary, outcome: Dictionary = {}) -> String:
	if str(definition.get("id", "")) in V3_IDS:
		return "%s | Cost 1 | From %s | One living enemy %s\n%s" % [
			definition.display_name, _positions(definition.from_positions),
			_positions(definition.to_positions), _v3_detail(definition)]
	return "%s | Cost %d | From %s | One living enemy %s\n%s" % [
		str(definition.get("display_name", "")), int(definition.get("cost", -1)),
		_positions(definition.get("from_positions", [])),
		_positions(definition.get("to_positions", [])),
		_bleed_detail(definition, outcome)]


## Printed effect, its one passive Bleed, and the real order of operations.
## This is not a damage forecast: existing statuses can modify a pre-hit strike.
func _v3_detail(definition: Dictionary) -> String:
	var effects: Dictionary = definition.effects
	var bleed: int = int(effects["bleed"])
	var detail := "Bleed %d (%d printed + 1 Seamstress passive) after the hit" % [bleed + 1, bleed]
	if effects.has("weak"):
		return "No attack; Bleed %d (%d printed + 1 Seamstress passive); Weak %d" % [
			bleed + 1, bleed, int(effects.weak)]
	return "BASE %d damage through Block before HP (pre-hit Weak/Exposed/Tangled); %s" % [
		int(effects.damage), detail]


func _positions(values: Array) -> String:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return ",".join(result)


func _focus_chain(app) -> void:
	var panels: Array[Control] = []
	for panel in _bindings.keys():
		if is_instance_valid(panel) and panel.is_visible_in_tree():
			panels.append(panel)
	if panels.is_empty():
		return
	for i in range(panels.size()):
		panels[i].focus_next = panels[i].get_path_to(panels[(i + 1) % panels.size()])
		panels[i].focus_previous = panels[i].get_path_to(panels[(i - 1 + panels.size()) % panels.size()])
		panels[i].focus_neighbor_top = panels[i].get_path_to(app.end_turn_button)
		panels[i].focus_neighbor_bottom = panels[i].get_path_to(app.end_turn_button)
	if app.end_turn_button.focus_neighbor_top.is_empty():
		app.end_turn_button.focus_neighbor_top = app.end_turn_button.get_path_to(panels[0])


func _on_card_input(event: InputEvent, panel, card_id: String) -> void:
	if event == null or not _affordable(panel, card_id):
		return
	var click: bool = event is InputEventMouseButton 		and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var accept: bool = event is InputEventKey and panel.has_focus() 		and event.is_action_pressed("ui_accept") and not event.echo
	if not click and not accept:
		return
	panel.accept_event()
	if _choice.get("panel") == panel:
		return
	_cancel()
	var definition: Dictionary = _definition(card_id)
	var positions: Array = definition.get("to_positions", [])
	var legal: Array[int] = []
	for enemy in _enemies.get_enemies():
		if enemy["hp"] > 0 and positions.has(enemy["position"]) 				and (card_id not in V3_IDS or _v3_service._prepare(
					_deck, _party, _enemies, card_id, int(enemy["position"])).get("ok", false)):
			legal.append(enemy["position"])
	if legal.is_empty():
		return
	_token += 1
	_choice = {"panel": panel, "id": card_id, "index": panel.get_index(),
		"token": _token, "deck": _deck, "party": _party, "enemies": _enemies,
		"battle": _battle, "result": _result, "rng": _rng,
		"rng_seed": _rng.seed, "rng_state": _rng.state, "intents": _intents,
		"turn": _turn, "hand": _deck.hand.duplicate(),
		"draw": _deck.draw_pile.duplicate(), "discard": _deck.discard_pile.duplicate(),
		"energy": _deck.energy, "heroes": _party.get_heroes(),
		"roster": _enemies.get_enemies(), "queued": false}
	_mount_strip(definition, legal, _projected_bleed(definition, legal))


func _selection_valid() -> bool:
	if _choice.is_empty() or not _live():
		return false
	var panel = _choice.get("panel")
	var card_id: String = str(_choice.get("id", ""))
	return _choice.token == _token and _choice.deck == _deck 		and _choice.party == _party and _choice.enemies == _enemies 		and _choice.battle == _battle and _choice.result == _result 		and _choice.rng == _rng and _choice.rng_seed == _rng.seed 		and _choice.rng_state == _rng.state and _choice.intents == _intents 		and _choice.turn == _turn and is_instance_valid(panel) 		and panel.get_index() == _choice.index 		and _affordable(panel, card_id) and _choice.hand == _deck.hand 		and _choice.draw == _deck.draw_pile and _choice.discard == _deck.discard_pile 		and _choice.energy == _deck.energy 		and _choice.heroes == _party.get_heroes() 		and _choice.roster == _enemies.get_enemies()


func _mount_strip(definition: Dictionary, legal: Array[int], outcome: Dictionary) -> void:
	# A nonblocking overlay covers the stage; only its stitched patch and
	# actual target buttons receive pointer events. Never claim enemy panels.
	_overlay = Control.new()
	_overlay.name = "SeamstressBleedChoiceOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target_strip = PanelContainer.new()
	target_strip.name = "SeamstressBleedTargetStrip"
	target_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	target_strip.anchor_left = 0.5
	target_strip.anchor_right = 0.5
	target_strip.offset_left = -335
	target_strip.offset_right = 335
	target_strip.offset_top = 138
	target_strip.offset_bottom = 277
	var patch := StyleBoxFlat.new()
	patch.bg_color = CREAM
	patch.border_color = THREAD
	patch.set_border_width_all(3)
	patch.set_corner_radius_all(7)
	patch.content_margin_left = 12
	patch.content_margin_right = 12
	patch.content_margin_top = 8
	patch.content_margin_bottom = 8
	target_strip.add_theme_stylebox_override("panel", patch)
	_overlay.add_child(target_strip)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	target_strip.add_child(column)
	var heading := Label.new()
	heading.name = "Rule"
	heading.text = _rule_text(definition, outcome)
	heading.add_theme_color_override("font_color", INK)
	heading.add_theme_font_size_override("font_size", 12)
	column.add_child(heading)
	var row := HBoxContainer.new()
	row.name = "EnemyChoices"
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var chain: Array[Button] = []
	for enemy in _enemies.get_enemies():
		var position: int = enemy["position"]
		if not definition.get("to_positions", []).has(position):
			continue
		var button := Button.new()
		button.name = "Enemy%d" % position
		button.text = "Enemy %d: %s" % [position,
			"Slain" if position not in legal else str(enemy.get("name", enemy["id"]))]
		button.disabled = position not in legal
		button.custom_minimum_size = Vector2(125, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_disabled_color", RUST)
		button.add_theme_font_size_override("font_size", 13)
		button.focus_mode = Control.FOCUS_ALL if not button.disabled else Control.FOCUS_NONE
		row.add_child(button)
		if not button.disabled:
			_targets[position] = button
			button.pressed.connect(_on_target_pressed.bind(position, str(enemy["id"]), _token))
			button.mouse_entered.connect(_show_preview.bind(position, _token))
			button.focus_entered.connect(_show_preview.bind(position, _token))
			chain.append(button)
	var cancel_button := Button.new()
	cancel_button.name = "Cancel"
	cancel_button.text = "Cancel (Esc)"
	cancel_button.custom_minimum_size = Vector2(100, 30)
	cancel_button.pressed.connect(_cancel.bind(true))
	row.add_child(cancel_button)
	chain.append(cancel_button)
	_preview = Label.new()
	_preview.name = "OutcomePreview"
	_preview.add_theme_color_override("font_color", THREAD)
	_preview.add_theme_font_size_override("font_size", 12)
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.custom_minimum_size.y = 18
	column.add_child(_preview)
	for i in range(chain.size()):
		chain[i].focus_next = chain[i].get_path_to(chain[(i + 1) % chain.size()])
		chain[i].focus_previous = chain[i].get_path_to(chain[(i - 1 + chain.size()) % chain.size()])
	if not chain.is_empty():
		chain[0].grab_focus()
		if not _targets.is_empty():
			_show_preview(legal[0], _token)


func _show_preview(position: int, token: int) -> void:
	if token != _token or not is_instance_valid(_preview):
		return
	_preview.text = ""
	if not _targets.has(position) or not is_instance_valid(_targets[position]) \
			or _targets[position].disabled or not _selection_valid():
		return
	if str(_choice.id) in V3_IDS:
		var card: Dictionary = _definition(str(_choice.id))
		if not card.is_empty() and _v3_service._prepare(
				_deck, _party, _enemies, str(_choice.id), position).get("ok", false):
			_preview.text = _v3_detail(card) + " | Selected enemy %d" % position
		return
	var outcome: Dictionary = _service.forecast_single(
		_deck, _party, _enemies, str(_choice.id), position)
	if not outcome.get("ok", false):
		return
	var now := "Now: 0 damage"
	if outcome.damage > 0:
		now = "Now: %d damage (%d Block, %d HP)" % [
			outcome.damage, outcome.block_absorbed, outcome.hp_loss]
	_preview.text = "%s  |  Bleed: %d -> %d (future)" % [
		now, outcome.bleed_before, outcome.bleed_after]
	if outcome.exposed_before != outcome.exposed_after:
		_preview.text += "\nExposed: %d -> %d" % [
			outcome.exposed_before, outcome.exposed_after]


func _on_target_pressed(position: int, enemy_id: String, token: int) -> void:
	if token != _token or not _selection_valid() or _choice.get("queued", false) 			or not _targets.has(position) 			or not is_instance_valid(_targets[position]) 			or _targets[position].disabled:
		return
	var enemy: Dictionary = _enemies.get_enemy(position)
	var definition: Dictionary = _definition(str(_choice.id))
	if enemy.get("id") != enemy_id or enemy.get("hp", 0) <= 0 			or not definition.get("to_positions", []).has(position):
		_cancel()
		return
	_choice.queued = true
	_commit.call_deferred(position, enemy_id, token)


func _commit(position: int, enemy_id: String, token: int) -> void:
	if token != _token or not _choice.get("queued", false) or not _selection_valid():
		_cancel()
		return
	var enemy: Dictionary = _enemies.get_enemy(position)
	var definition: Dictionary = _definition(str(_choice.id))
	if not _targets.has(position) or enemy.get("id") != enemy_id 			or enemy.get("hp", 0) <= 0 			or not definition.get("to_positions", []).has(position):
		_cancel()
		return
	var card_id: String = _choice.id
	var event: Dictionary = _v3_service.play_card(_deck, _party, _enemies, card_id, position) 		if card_id in V3_IDS else _service.play_card(_deck, _party, _enemies, card_id, position)
	_cancel()
	if not event.get("ok", false):
		return
	last_event = event.duplicate(true)
	var app = _app()
	app._refresh_hand()
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_intents()
	if app._observe_battle_result() and is_instance_valid(app.end_turn_button):
		app.end_turn_button.grab_focus()
	elif is_instance_valid(app.end_turn_button):
		app.end_turn_button.grab_focus()
	_sync_battle()


func _cancel(restore_focus: bool = false) -> void:
	var panel = _choice.get("panel")
	_token += 1
	_choice.clear()
	_targets.clear()
	if is_instance_valid(_overlay):
		_overlay.free()
	_overlay = null
	target_strip = null
	_preview = null
	if restore_focus and is_instance_valid(panel) and panel.is_inside_tree() 			and panel.is_visible_in_tree():
		panel.grab_focus()


func _unbind(panel) -> void:
	if not _bindings.has(panel):
		return
	var callback: Callable = _bindings[panel].callback
	if is_instance_valid(panel):
		if panel.gui_input.is_connected(callback):
			panel.gui_input.disconnect(callback)
		if panel.get_parent() != _app().hand_view:
			panel.focus_mode = Control.FOCUS_NONE
			panel.focus_next = NodePath()
			panel.focus_previous = NodePath()
			panel.focus_neighbor_top = NodePath()
			panel.focus_neighbor_bottom = NodePath()
			panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
			panel.remove_theme_stylebox_override("focus")
	_bindings.erase(panel)
	if _choice.get("panel") == panel:
		_cancel()


func _clear() -> void:
	_cancel()
	for panel in _bindings.keys():
		_unbind(panel)
	_bindings.clear()
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_clear):
		_battle.tree_exiting.disconnect(_clear)
	_battle = null
	_deck = null
	_party = null
	_enemies = null
	_result = null
	_rng = null
	_intents = null
	_turn = -1
	_service = CombatSeamstressPoolBleed.new()
	last_event.clear()


func _exit_tree() -> void:
	_clear()
