extends Node
## Mounted input/face adapter for held target-free area attacks and self energy
## utilities. Each original resolver owns its mutation; the attack presenter
## alone owns Tinker's first-attack latch.

const SEAMSTRESS_IDS := ["seamstress_blanket_stitch", "seamstress_blanket_stitch_plus"]
const TINKER_IDS := ["tinker_scatter_bolts", "tinker_scatter_bolts_plus",
	"tinker_ricochet", "tinker_ricochet_plus"]
## Target-free area attacks that charge the battle's shared Unravel gauge.
const UNRAVEL_TINKER_IDS := ["tinker_shrapnel_seam", "tinker_shrapnel_seam_plus"]
const ENERGY_TINKER_IDS := ["tinker_overclock", "tinker_overclock_plus"]
const ENERGY_SEAMSTRESS_IDS := ["seamstress_tailors_trance", "seamstress_tailors_trance_plus"]
const ENERGY_IDS := ENERGY_TINKER_IDS + ENERGY_SEAMSTRESS_IDS
const CARD_IDS := SEAMSTRESS_IDS + TINKER_IDS + UNRAVEL_TINKER_IDS + ENERGY_IDS
const INSTRUCTION := "Click or focus and press Enter / Space to play"
const CUE_NAME := "BlanketStitchCue"
const CREAM := Color("#ece0c8")
const INK := Color("#3d3440")
const RUST := Color("#9e6f58")
const SEAMSTRESS := Color("#6e4f6b")
const TINKER := Color("#c49a3a")

## Retained mount handle. This adapter never creates a separate action control.
var button: Button

var _service := CombatSeamstressPoolBleed.new()
var _catalog := SeamstressPoolCards.new()
var _tinker_catalog := TinkerPoolCards.new()
var last_event: Dictionary = {}
var _battle: Control
var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies
var _result: CombatBattleResult
var _rng: RandomNumberGenerator
## Key: the real hand panel, value: {"id": String, "callback": Callable}.
var _bindings: Dictionary = {}
var _pending: Dictionary = {}
var _turn := -1
var _token := 0


func _process(_delta: float) -> void:
	_sync_battle()


func _is_card(card_id: String) -> bool:
	return card_id in CARD_IDS


func _definition(card_id: String) -> Dictionary:
	return _tinker_catalog.get_definition(card_id) if card_id in TINKER_IDS \
		or card_id in UNRAVEL_TINKER_IDS or card_id in ENERGY_TINKER_IDS \
		else _catalog.get_definition(card_id)


## Reuse the starter attack presenter's actual session- and turn-matched latch.
## Never synthesize one on a newly bound panel or for a stale presenter.
func _live_tinker_latch(app) -> CombatTinkerFirstAttack:
	var preview = app.get_node_or_null("LiveAttackPreview")
	if preview == null or not preview.is_inside_tree() \
			or preview._battle != _battle or preview._deck != _deck \
			or preview._session != [app.party, app.enemies, app.battle_result,
				app.run_rng, app.enemy_intents] or preview._turn != _turn \
			or not preview._play is CombatAttackCards:
		return null
	return preview._play._tinker


## The battle's own Pinned set and Unravel gauge, exactly as the mounted
## single-target presenter created them for this session. A gauge card fails
## closed unless that one gauge is bound to this roster and the live round flow
## either shares it already or is about to. This never creates a second gauge,
## a second latch or a substitute roster.
func _live_unravel_authorities(app) -> Dictionary:
	var preview = app.get_node_or_null("LiveAttackPreview")
	if preview == null or not preview.is_inside_tree() \
			or preview._battle != _battle or preview._deck != _deck \
			or preview._session != [app.party, app.enemies, app.battle_result,
				app.run_rng, app.enemy_intents] or preview._turn != _turn:
		return {}
	var unravel: CombatUnravel = preview._unravel
	var pinned: CombatPinned = preview._pinned
	if unravel == null or pinned == null \
			or not is_instance_valid(unravel) or not is_instance_valid(pinned):
		return {}
	if unravel._bound_enemies != _enemies:
		return {}
	var flow: CombatRoundFlow = app.round_flow
	if flow == null or not is_instance_valid(flow) \
			or flow._deck != _deck or flow._party != _party \
			or flow._enemies != _enemies or flow._intents != app.enemy_intents \
			or flow._result != _result:
		return {}
	# Another gauge already bound to this fight is a real conflict, not a
	# fallback: refuse rather than replace or double-charge an authority.
	if flow._unravel != null and flow._unravel != unravel:
		return {}
	return {"unravel": unravel, "pinned": pinned, "flow": flow}


## True only for a real, currently held blank stitch panel whose mounted label,
## hand index and bound ID all agree. Never a rules authority: the service
## revalidates the complete play before it commits anything.
func _valid_panel(app, panel) -> bool:
	if not is_instance_valid(panel) or not is_instance_valid(app.hand_view):
		return false
	if panel.get_parent() != app.hand_view or _deck == null:
		return false
	if not _bindings.has(panel):
		return false
	var card_id: String = _bindings[panel]["id"]
	if not _is_card(card_id):
		return false
	var index: int = panel.get_index()
	if index < 0 or index >= _deck.hand.size() or _deck.hand[index] != card_id:
		return false
	if panel.get_child_count() < 1 or not panel.get_child(0) is Label:
		return false
	return panel.get_child(0).text == card_id


func _sync_battle() -> void:
	var app = get_parent()
	if app == null or app.deck == null or app.party == null or app.enemies == null \
			or app.battle_result == null \
			or not is_instance_valid(app.battle_view) or not is_instance_valid(app.hand_view):
		if _battle != null or not _bindings.is_empty() or not _pending.is_empty():
			_clear()
		return
	# A new battle, hand owner or session retires every old binding and receipt.
	if _battle != app.battle_view or _deck != app.deck or _party != app.party \
			or _enemies != app.enemies or _result != app.battle_result or _rng != app.run_rng:
		_clear()
		_battle = app.battle_view
		_deck = app.deck
		_party = app.party
		_enemies = app.enemies
		_result = app.battle_result
		_rng = app.run_rng
		_turn = _turn_index(app)
		last_event.clear()
		_battle.tree_exiting.connect(_clear, CONNECT_ONE_SHOT)
	elif _turn != _turn_index(app):
		_turn = _turn_index(app)
		_cancel()
	# Never claim a panel in a session whose result does not witness these rosters.
	var consistent: bool = app.party.is_valid() and app.enemies.is_valid() \
		and app.battle_result._party == app.party and app.battle_result._enemies == app.enemies
	if not consistent:
		for panel in _bindings.keys():
			_unbind(panel)
		_cancel()
		return
	for panel in _bindings.keys():
		if not _valid_panel(app, panel):
			_unbind(panel)
	for panel in app.hand_view.get_children():
		if panel.get_child_count() < 1 or not panel.get_child(0) is Label:
			continue
		var label := panel.get_child(0) as Label
		if not _is_card(label.text):
			continue
		var index: int = panel.get_index()
		if index < 0 or index >= _deck.hand.size() or _deck.hand[index] != label.text:
			continue
		if _bindings.has(panel):
			_exclusive_energy_input(panel, label.text)
			continue
		_bind(panel, label.text)
	# Up from the action row may enter this hand only while a held area card exists.
	if not _bindings.is_empty():
		_focus_chain()


func _turn_index(app) -> int:
	if app.enemy_intents == null:
		return -1
	var turn_value: Variant = app.enemy_intents._turn_index
	if not turn_value is int:
		return -1
	return turn_value


## The only panels this adapter ever claims are the matching real held cards.
func _bind(panel: Control, card_id: String) -> void:
	var callback := _on_card_input.bind(panel, card_id)
	_bindings[panel] = {"id": card_id, "callback": callback}
	panel.focus_mode = Control.FOCUS_ALL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("ece0c8")
	focus.set_border_width_all(3)
	panel.add_theme_stylebox_override("focus", focus)
	panel.tooltip_text = INSTRUCTION + "\n" + _rule_text(card_id)
	# The shared support presenter already recognizes these four IDs. Keep its
	# other cards untouched, but route each self card through this ONE mounted
	# input adapter rather than racing two deferred service transactions.
	_exclusive_energy_input(panel, card_id)
	panel.gui_input.connect(callback)
	_mount_cue(panel, card_id)
	_focus_chain()


func _exclusive_energy_input(panel: Control, card_id: String) -> void:
	if card_id not in ENERGY_IDS:
		return
	var support = get_parent().get_node_or_null("LiveSupportHand")
	if support == null or not support._bindings.has(panel):
		return
	var callback: Callable = support._bindings[panel]
	if panel.gui_input.is_connected(callback):
		panel.gui_input.disconnect(callback)


func _rule_text(card_id: String) -> String:
	var definition: Dictionary = _definition(card_id)
	if definition.get("id") != card_id:
		return "Unknown card rules"
	var effects: Dictionary = definition.get("effects", {})
	if card_id in ENERGY_TINKER_IDS:
		return "%s | Tinker | %d energy | From %s\nSelf: Gain %d energy; take %d self-damage (Block absorbs first), no target choice" % [
			String(definition.get("display_name", card_id)), int(definition.get("cost", -1)),
			_positions(definition.get("from_positions", [])), int(effects.get("gain_energy", 0)),
			int(effects.get("self_hp_loss", 0))]
	if card_id in ENERGY_SEAMSTRESS_IDS:
		return "%s | Seamstress | %d energy | From %s\nSelf: Gain %d energy and draw %d cards (after paying cost), no target choice" % [
			String(definition.get("display_name", card_id)), int(definition.get("cost", -1)),
			_positions(definition.get("from_positions", [])), int(effects.get("energy", 0)),
			int(effects.get("draw", 0))]
	if card_id in TINKER_IDS:
		var detail: String = ("Scatter each living enemy for %d damage once" % int(effects.get("damage", 0))
			if definition.get("target_kind") == "enemy_all" else
			"Ricochet %d random living hits, %d damage each (run RNG)" % [
				int(effects.get("hit_count", 0)), int(effects.get("damage", 0))])
		return "%s | Tinker | %d energy | From %s\nEnemies %s: %s; first attack +3, no target choice" % [
			String(definition.get("display_name", card_id)), int(definition.get("cost", -1)),
			_positions(definition.get("from_positions", [])), _positions(definition.get("to_positions", [])), detail]
	if card_id in UNRAVEL_TINKER_IDS:
		return "%s | Tinker | %d energy | From %s\nAll living enemies %s: %d damage each and Unravel %d per survivor; first attack +3, no target choice" % [
			String(definition.get("display_name", card_id)), int(definition.get("cost", -1)),
			_positions(definition.get("from_positions", [])), _positions(definition.get("to_positions", [])),
			int(effects.get("damage", 0)), int(effects.get("unravel", 0))]
	var bleed: int = int(effects.get("bleed", 0))
	return "%s | %d energy | From %s\nAll living enemies %s: Bleed %d (%d + Seamstress passive 1), no target choice" % [
		String(definition.get("display_name", card_id)), int(definition.get("cost", -1)),
		_positions(definition.get("from_positions", [])), _positions(definition.get("to_positions", [])),
		bleed + 1, bleed]


func _positions(positions: Array) -> String:
	var values: Array[String] = []
	for position in positions:
		values.append(str(position))
	if values.is_empty():
		return "?"
	return ",".join(values)


## The shared hand metadata presenter (owned by another lane) intentionally paints
## an unadvertised pool ID as "Unknown card". These two IDs are real, authored
## Blanket Stitch copies, so the adapter mounts its own visible, noninteractive
## face over that placeholder. The original first-child ID Label, the panel's
## input routing and every shared control stay exactly as they were.
func _mount_cue(panel: Control, card_id: String) -> void:
	var definition: Dictionary = _definition(card_id)
	if definition.get("id") != card_id:
		return
	var is_tinker: bool = card_id in TINKER_IDS or card_id in UNRAVEL_TINKER_IDS \
		or card_id in ENERGY_TINKER_IDS
	var is_energy: bool = card_id in ENERGY_IDS
	var owner_color: Color = TINKER if is_tinker else SEAMSTRESS
	for existing in panel.get_children():
		if existing.name == CUE_NAME:
			panel.remove_child(existing)
			existing.free()
	var upgraded: bool = card_id.ends_with("_plus")
	var cue := PanelContainer.new()
	cue.name = CUE_NAME
	cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cue.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = CREAM
	style.border_color = owner_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	cue.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.focus_mode = Control.FOCUS_NONE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 4)
	cue.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.focus_mode = Control.FOCUS_NONE
	column.add_theme_constant_override("separation", 1)
	margin.add_child(column)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.focus_mode = Control.FOCUS_NONE
	column.add_child(title_row)
	var name_label := _cue_label(String(definition.get("display_name", card_id)), 14, INK)
	name_label.name = "CardName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)
	var cost_label := _cue_label("%d energy" % int(definition.get("cost", -1)), 11, INK)
	cost_label.name = "Cost"
	cost_label.custom_minimum_size = Vector2(48, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(cost_label)
	var effects: Dictionary = definition.get("effects", {}) if definition.get("effects", {}) is Dictionary else {}
	var bleed: int = int(effects.get("bleed", 0))
	var from_positions: Array = definition.get("from_positions", [])
	var to_positions: Array = definition.get("to_positions", [])
	var variant_label := _cue_label("%s | %s | From %s" % [
		"Upgraded" if upgraded else "Base", "Tinker" if is_tinker else "Seamstress",
		_positions(from_positions)], 9, owner_color)
	variant_label.name = "Variant"
	column.add_child(variant_label)
	var scope: String = "Self (no enemy target)" if is_energy else "%s enemies %s" % [
		"Random living" if is_tinker and definition.get("target_kind") == "enemy_random" else "All",
		_positions(to_positions)]
	var area_label := _cue_label(scope, 11, INK)
	area_label.name = "Area"
	column.add_child(area_label)
	var detail: String = "Bleed %d (%d + passive 1)" % [bleed + 1, bleed]
	if is_tinker:
		detail = ("%d damage each (+3 first attack)" % int(effects.get("damage", 0))
			if definition.get("target_kind") == "enemy_all" else
			"%d hits x %d damage (+3 first attack)" % [
				int(effects.get("hit_count", 0)), int(effects.get("damage", 0))])
	if card_id in ENERGY_TINKER_IDS:
		detail = "Gain %d energy; %d self-damage (Block first)" % [
			int(effects.get("gain_energy", 0)), int(effects.get("self_hp_loss", 0))]
	elif card_id in UNRAVEL_TINKER_IDS:
		detail = "%d damage each, Unravel %d (+3 first attack)" % [
			int(effects.get("damage", 0)), int(effects.get("unravel", 0))]
	elif card_id in ENERGY_SEAMSTRESS_IDS:
		detail = "Gain %d energy; draw %d cards" % [
			int(effects.get("energy", 0)), int(effects.get("draw", 0))]
	var bleed_label := _cue_label(detail, 11, RUST)
	bleed_label.name = "Effect" if is_tinker or is_energy else "Bleed"
	column.add_child(bleed_label)
	var target_label := _cue_label("No target choice", 9, RUST)
	target_label.name = "Target"
	column.add_child(target_label)
	panel.add_child(cue)
	var binding: Dictionary = _bindings[panel]
	binding["cue"] = cue
	binding["cue_name"] = name_label
	binding["cue_cost"] = cost_label
	binding["cue_variant"] = variant_label
	binding["cue_area"] = area_label
	binding["cue_bleed"] = bleed_label
	binding["cue_target"] = target_label


func _cue_label(value: String, point_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.clip_text = true
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	return label


## Visible cue text actually mounted on the real panel, for mounted regressions.
func face_text(panel) -> Dictionary:
	if not _bindings.has(panel):
		return {}
	var binding: Dictionary = _bindings[panel]
	var text := {}
	for key in ["cue_name", "cue_cost", "cue_variant", "cue_area", "cue_bleed", "cue_target"]:
		var label = binding.get(key)
		if is_instance_valid(label):
			text[key.trim_prefix("cue_")] = label.text
	return text


## Keep the held blank stitch panels inside the existing hand focus loop without
## touching the attack or support cards' own navigation.
func _focus_chain() -> void:
	var app = get_parent()
	if app == null or not is_instance_valid(app.end_turn_button):
		return
	var panels: Array[Control] = []
	for panel in _bindings.keys():
		if is_instance_valid(panel):
			panels.append(panel)
	if panels.is_empty():
		return
	for index in range(panels.size()):
		var panel: Control = panels[index]
		panel.focus_next = panel.get_path_to(panels[(index + 1) % panels.size()])
		panel.focus_previous = panel.get_path_to(panels[(index - 1 + panels.size()) % panels.size()])
		panel.focus_neighbor_top = panel.get_path_to(app.end_turn_button)
		panel.focus_neighbor_bottom = panel.get_path_to(app.end_turn_button)
	# Up enters the hand from the action row only when no other card owns that entry.
	if app.end_turn_button.focus_neighbor_top.is_empty():
		app.end_turn_button.focus_neighbor_top = app.end_turn_button.get_path_to(panels[0])


func _unbind(panel) -> void:
	if not _bindings.has(panel):
		return
	var callback: Callable = _bindings[panel]["callback"]
	var cue = _bindings[panel].get("cue")
	if is_instance_valid(panel):
		if panel.gui_input.is_connected(callback):
			panel.gui_input.disconnect(callback)
		if panel.get_parent() != get_parent().hand_view:
			panel.focus_mode = Control.FOCUS_NONE
			panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
			panel.focus_next = NodePath()
			panel.focus_previous = NodePath()
			panel.focus_neighbor_top = NodePath()
			panel.focus_neighbor_bottom = NodePath()
			panel.remove_theme_stylebox_override("focus")
	if is_instance_valid(cue):
		cue.free()
	_bindings.erase(panel)
	if _pending.get("panel") == panel:
		_cancel()


## Mouse click and focused Enter / Space both use the same receipt and the same
## single deferred commit. A duplicate input while one is pending is inert.
func _on_card_input(event: InputEvent, panel, card_id: String) -> void:
	if event == null or not _eligible(panel, card_id):
		return
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var accept: bool = event is InputEventKey and panel.has_focus() \
		and event.is_action_pressed("ui_accept") and not event.echo
	if not click and not accept:
		return
	panel.accept_event()
	if _pending.get("panel") == panel:
		return
	_cancel()
	var receipt := _receipt(panel, card_id)
	_pending = {"panel": panel, "id": card_id, "token": _token, "receipt": receipt}
	_commit.call_deferred(panel, card_id, _token, receipt)


## Battle, deck, party, enemy, result, RNG, turn, panel, index and ID receipt.
func _receipt(panel: Control, card_id: String) -> Dictionary:
	return {"battle": _battle, "deck": _deck, "party": _party, "enemies": _enemies,
		"result": _result, "rng": _rng, "turn": _turn, "panel": panel,
		"index": panel.get_index(), "id": card_id, "intents": get_parent().enemy_intents}


func _receipt_valid(receipt: Dictionary) -> bool:
	var app = get_parent()
	if app == null or not is_inside_tree():
		return false
	if app.get_node_or_null("LiveAreaAttackAction") != self:
		return false
	if receipt.get("battle") != _battle or receipt.get("deck") != _deck \
			or receipt.get("party") != _party or receipt.get("enemies") != _enemies \
			or receipt.get("result") != _result or receipt.get("rng") != _rng:
		return false
	if app.enemy_intents != receipt.get("intents") or app.enemy_intents == null:
		return false
	if app.battle_view != _battle or app.deck != _deck or app.party != _party \
			or app.enemies != _enemies or app.battle_result != _result or app.run_rng != _rng:
		return false
	var panel = receipt.get("panel")
	if not is_instance_valid(panel) or panel.get_index() != receipt.index:
		return false
	return _turn_index(app) == receipt.turn and _turn == receipt.turn


## Complete combat eligibility for one real cast. Presentation preflight only:
## the service independently revalidates and owns every mutation.
func _eligible(panel, card_id: String) -> bool:
	var app = get_parent()
	if app == null or _deck == null or _party == null or _enemies == null \
			or _result == null or not is_instance_valid(_battle):
		return false
	if not _is_card(card_id) or not _valid_panel(app, panel):
		return false
	if _bindings[panel]["id"] != card_id:
		return false
	if not panel.is_visible_in_tree() or not _battle.is_visible_in_tree():
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
		and app.battle_result == _result and app.run_rng == _rng and app.battle_view == _battle


func _commit(panel, card_id: String, token: int, receipt: Dictionary) -> void:
	if not is_inside_tree() or token != _token or _pending.get("token") != token:
		return
	if _pending.get("panel") != panel or _pending.get("id") != card_id:
		return
	_pending.clear()
	if not _receipt_valid(receipt) or not _eligible(panel, card_id):
		_cancel()
		return
	# The existing resolvers revalidate every condition before mutation.
	var event: Dictionary
	if card_id in ENERGY_IDS:
		if not CombatPoolEnergyCards.new().play_card(receipt.deck, receipt.party, card_id, 0):
			_cancel()
			return
		event = {"ok": true, "card_id": card_id, "target_kind": "self"}
	elif card_id in TINKER_IDS:
		var latch: CombatTinkerFirstAttack = _live_tinker_latch(get_parent())
		if latch == null:
			_cancel()
			return
		event = CombatTinkerPoolAttacks.new(latch).play_attack(receipt.deck,
			receipt.party, receipt.enemies, card_id, 0)
	elif card_id in UNRAVEL_TINKER_IDS:
		# Reuse the starter presenter's latch and this battle's single Pinned
		# and Unravel authorities. A missing or foreign gauge refuses the cast.
		var shared_latch: CombatTinkerFirstAttack = _live_tinker_latch(get_parent())
		var authorities: Dictionary = _live_unravel_authorities(get_parent())
		if shared_latch == null or authorities.is_empty():
			_cancel()
			return
		event = CombatTinkerPoolUnravelAttacks.new(shared_latch).play_attack(receipt.deck,
			receipt.party, receipt.enemies, card_id, 0,
			authorities.unravel, authorities.pinned)
		if event.get("ok", false):
			# The real round flow now shares that same gauge, so its turn end
			# consumes the queued skip. Never a second gauge or a reset.
			var flow: CombatRoundFlow = authorities["flow"]
			flow._unravel = authorities["unravel"]
	else:
		event = _service.play_card(receipt.deck, receipt.party, receipt.enemies, card_id, 0)
	if not event.get("ok", false):
		_cancel()
		return
	last_event = event.duplicate(true)
	_after_cast()


## Existing app refresh and terminal observation, in the shared attack order.
func _after_cast() -> void:
	var app = get_parent()
	_cancel()
	app._refresh_hand()
	app._refresh_party()
	app._refresh_enemy_roster()
	app._refresh_intents()
	if app._observe_battle_result() and is_instance_valid(app.end_turn_button):
		app.end_turn_button.grab_focus()
	_sync_battle()


func _cancel() -> void:
	_token += 1
	_pending.clear()


## Battle, hand and title lifecycle changes drop every binding, receipt and hint.
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
	_turn = -1
	last_event.clear()
