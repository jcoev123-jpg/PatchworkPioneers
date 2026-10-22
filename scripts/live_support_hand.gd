extends Node
## Input/presentation only. Support and movement services own effects and charges.

const SUPPORT_IDS := ["warden_brace", "tinker_tune_up", "seamstress_mend", "seamstress_stitch_up"]
const ALLY_IDS := ["seamstress_mend", "seamstress_stitch_up", "warden_patch_guard", "warden_patch_guard_plus"]
const TABLE_ID := "SupportTableBacking"
## Visible idle cue only: the complete mouse/keyboard instructions live in TABLE_HELP_DETAIL,
## which the cue exposes as a real hover tooltip instead of stretching across the footer.
const TABLE_HELP := "Help"
const TABLE_HELP_DETAIL := "Click, drag or focus a card and press Enter / Space to play it. " \
	+ "Up / Down or Tab moves between cards. Esc or Cancel clears a chosen target."
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
var footer_spring: Control
var backing: Control
var _hud: Control
var _play := CombatStarterSupportPlay.new()
var _block_cards := CombatWardenPoolBlockCards.new()
var _energy_cards := CombatPoolEnergyCards.new()
var _metadata = preload("res://scripts/live_hand_card_metadata.gd").new()


## Presentation only: one stitched felt sewing table drawn behind the mounted piles, hand,
## energy spool and action row. It is a sibling placed just before the battle column, so it
## draws behind every real control, never joins the hand container and never changes any
## container's minimum size. It takes no pointer or keyboard input.
class FeltTableBacking extends Control:
	const FELT_DEEP := Color("302b26")
	const HEM := Color("56483d")
	const THREAD := Color("c9b996")
	const PATCHES := [Color("42392f"), Color("473e34"), Color("39312a"), Color("443a31")]
	const INSET := 4.0
	var band := Rect2()
	var draw_count := 0
	var _content: Array[Control] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(refresh_band)

	## Follow one real mounted control, so the table is always sized from live layout.
	func attach(control: Control) -> void:
		if control == null or control in _content:
			return
		_content.append(control)
		control.item_rect_changed.connect(refresh_band)
		refresh_band()

	## Re-measure the sewn bar from the attached controls; redraw only on a real change.
	func refresh_band() -> void:
		var measured := _measure_band()
		if measured == band:
			return
		band = measured
		queue_redraw()

	func _measure_band() -> Rect2:
		var frame := Rect2(Vector2.ZERO, size)
		if not is_inside_tree() or frame.size.x <= 0.0 or frame.size.y <= 0.0:
			return Rect2()
		var lower := Rect2()
		var found := false
		for control in _content:
			if not is_instance_valid(control) or not control.is_visible_in_tree():
				continue
			var rect := _local_rect(control)
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				continue
			lower = rect if not found else lower.merge(rect)
			found = true
		if not found:
			return Rect2()
		# The bar spans the full table width and clamps to the battle area, so it can never
		# reach up into the actor stage or draw past the viewport's bottom edge.
		var top := clampf(lower.position.y, frame.position.y, frame.end.y)
		var bottom := clampf(lower.end.y, top, frame.end.y)
		return Rect2(frame.position.x, top, frame.size.x, bottom - top)

	func _local_rect(control: Control) -> Rect2:
		var rect := control.get_global_rect()
		return Rect2(rect.position - get_global_rect().position, rect.size)

	## Test hook: does this Control's real rect sit inside the sewn table?
	func covers(control: Control) -> bool:
		if not is_instance_valid(control) or band.size.x <= 0.0 or band.size.y <= 0.0:
			return false
		return band.encloses(_local_rect(control))

	## Test hook: does the sewn table reach into this Control's real rect?
	func overlaps(control: Control) -> bool:
		if not is_instance_valid(control) or band.size.x <= 0.0 or band.size.y <= 0.0:
			return false
		return band.intersects(_local_rect(control))

	func _draw() -> void:
		if band.size.x < 24.0 or band.size.y < 24.0:
			return
		draw_count += 1
		draw_rect(band, FELT_DEEP)
		var cloth := band.grow_individual(-INSET, -INSET, -INSET, -INSET)
		# Uneven sewn panels read as one quilted cloth without any texture file.
		var count := 6
		for index in range(count):
			var from := cloth.position.x + cloth.size.x * float(index) / float(count)
			var to := cloth.position.x + cloth.size.x * float(index + 1) / float(count)
			draw_rect(Rect2(from, cloth.position.y, to - from - 2.0, cloth.size.y), PATCHES[index % PATCHES.size()])
		draw_rect(Rect2(cloth.position, Vector2(cloth.size.x, 3.0)), HEM)
		draw_rect(Rect2(cloth.position.x, cloth.end.y - 3.0, cloth.size.x, 3.0), HEM)
		for y in [cloth.position.y, cloth.end.y]:
			draw_dashed_line(Vector2(cloth.position.x, y), Vector2(cloth.end.x, y), THREAD, 1.0, 6.0)
		for index in range(1, count):
			var x := cloth.position.x + cloth.size.x * float(index) / float(count)
			draw_dashed_line(Vector2(x, cloth.position.y), Vector2(x, cloth.end.y), THREAD, 1.0, 5.0)
			for y in [cloth.position.y + 9.0, cloth.end.y - 9.0]:
				draw_line(Vector2(x - 3.0, y - 3.0), Vector2(x + 3.0, y + 3.0), THREAD, 1.2, true)
				draw_line(Vector2(x - 3.0, y + 3.0), Vector2(x + 3.0, y - 3.0), THREAD, 1.2, true)


class EnergyOrb extends Control:
	## The spool is drawn inset from the control rect, so the whole disc keeps a clear
	## margin inside the 76 px footer box and never crowds the battle area's bottom edge.
	const INSET := 8.0
	const DISK := Color("555d48")
	const RIM := Color("ecdfbd")
	const THREAD := Color("c9b996")
	var draw_count := 0

	func _ready() -> void:
		custom_minimum_size = Vector2(76, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		resized.connect(queue_redraw)

	## Radius of the drawn fabric disc: always inside the control rect, never the rect itself.
	func disc_radius() -> float:
		return maxf(minf(size.x, size.y) * 0.5 - INSET, 8.0)

	## Test hook: the sewn disc in this control's local space.
	func disc_rect() -> Rect2:
		var radius := disc_radius()
		return Rect2(size * 0.5 - Vector2(radius, radius), Vector2(radius, radius) * 2.0)

	func _draw() -> void:
		var center := size * 0.5
		var radius := disc_radius()
		draw_count += 1
		draw_circle(center, radius, DISK)
		draw_arc(center, radius, 0, TAU, 64, RIM, 2, true)
		for index in range(16):
			var angle := TAU * index / 16.0
			draw_line(center + Vector2.from_angle(angle) * (radius - 6),
				center + Vector2.from_angle(angle + 0.07) * (radius - 4), THREAD, 1, true)


## Decorative only: a sewn thread border inside the Help patch. It is a child of the real
## hoverable Label, ignores the mouse and takes no focus, so hovering still reaches the
## Label's tooltip rather than this inert drawing.
class HelpStitch extends Control:
	const THREAD := Color("c9b996")
	const EDGE := 3.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var cloth := Rect2(Vector2(EDGE, EDGE), size - Vector2(EDGE, EDGE) * 2.0)
		if cloth.size.x < 12.0 or cloth.size.y < 8.0:
			return
		var corners := [cloth.position, Vector2(cloth.end.x, cloth.position.y),
			cloth.end, Vector2(cloth.position.x, cloth.end.y)]
		for index in range(corners.size()):
			draw_dashed_line(corners[index], corners[(index + 1) % corners.size()], THREAD, 1.0, 4.0)
			var point: Vector2 = corners[index]
			draw_line(point + Vector2(-2, -2), point + Vector2(2, 2), THREAD, 1.2, true)
			draw_line(point + Vector2(-2, 2), point + Vector2(2, -2), THREAD, 1.2, true)


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


## True only for the five resolved Warden pure-Block pool records and their '+' forms.
## The resolver's kind table is the authority, so a future catalog entry cannot be
## admitted by a stale local list.
func _is_block_card(card_id: String) -> bool:
	var base_id := card_id.trim_suffix("_plus")
	return CombatWardenPoolBlockCards.SUPPORTED_KINDS.has(base_id) \
		and (card_id == base_id or card_id == base_id + "_plus")


func _is_energy_card(card_id: String) -> bool:
	return CombatPoolEnergyCards.SUPPORTED_IDS.has(card_id)

func _is_actionable(card_id: String) -> bool:
	return card_id in SUPPORT_IDS or card_id in M02PositionCards.IDS or _is_block_card(card_id) or _is_energy_card(card_id)


## One entry point keeps starter support and pool Block cards on the same commit path.
func _play_held(deck: CombatDeck, party: CombatParty, card_id: String, position: int) -> bool:
	if _is_block_card(card_id):
		if _block_cards == null:
			return false
		return bool(_block_cards.play_card(deck, party, card_id, position).get("ok", false))
	if _is_energy_card(card_id):
		if _energy_cards == null:
			return false
		return bool(_energy_cards.play_card(deck, party, card_id, 0))
	return _play != null and _play.play_card(deck, party, card_id, position)


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
		_block_cards = CombatWardenPoolBlockCards.new()
		_energy_cards = CombatPoolEnergyCards.new()
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
		# A small sewn patch: the visible cue is one short word, the complete instructions
		# stay on a real hoverable tooltip and never occupy a stretch row of the footer.
		help_label.text = TABLE_HELP
		help_label.mouse_filter = Control.MOUSE_FILTER_STOP
		help_label.mouse_default_cursor_shape = Control.CURSOR_HELP
		help_label.focus_mode = Control.FOCUS_NONE
		help_label.tooltip_text = TABLE_HELP_DETAIL
		help_label.custom_minimum_size = Vector2(64, 34)
		help_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		help_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		help_label.add_theme_font_size_override("font_size", 15)
		help_label.add_theme_color_override("font_color", Color("ecdfbd"))
		var patch := StyleBoxFlat.new()
		patch.bg_color = Color("42392f")
		patch.border_color = Color("c9b996")
		patch.set_border_width_all(1)
		patch.set_corner_radius_all(6)
		patch.content_margin_left = 10
		patch.content_margin_right = 10
		patch.content_margin_top = 5
		patch.content_margin_bottom = 5
		help_label.add_theme_stylebox_override("normal", patch)
		var stitch := HelpStitch.new()
		stitch.name = "SupportHandHelpStitch"
		help_label.add_child(stitch)
		hud.add_child(help_label)
		hud.move_child(help_label, 1)
		# Inert spring: the cue itself no longer stretches, and the accepted End Turn / Return
		# row keeps its far-right placement. Hidden while a target message needs the room.
		footer_spring = Control.new()
		footer_spring.name = "SupportHandFooterSpring"
		footer_spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		footer_spring.focus_mode = Control.FOCUS_NONE
		footer_spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hud.add_child(footer_spring)
		hud.move_child(footer_spring, 2)
		cancel_button = Button.new()
		cancel_button.text = "Cancel target (Esc)"
		cancel_button.pressed.connect(_cancel_pending)
		hud.add_child(cancel_button)
		cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cancel_button.hide()
		_hud = hud
		_mount_table(app)
	if not _pending.is_empty() and not _selection_valid():
		_cancel_pending()
	if not _targets_valid():
		_cancel_pending()
	for panel in _targets:
		var cue: Label = _targets[panel].cue
		cue.position = panel.global_position - Vector2(0, 16)
		cue.size = Vector2(panel.size.x, 16)
	energy_label.text = "Energy\n%d" % _deck.energy
	# Idle: one short sewn cue, no stretch. Targeting: the full card-name prompt takes the row.
	var choosing: bool = _pending.get("choosing", false)
	var help_text: String = TABLE_HELP
	if choosing:
		help_text = "%s: choose a living ally | Esc: cancel" % _metadata.definition(_pending.id).get("display_name", _pending.id)
	if help_label.text != help_text:
		help_label.text = help_text
	var help_flags: int = Control.SIZE_EXPAND_FILL if choosing else Control.SIZE_SHRINK_BEGIN
	if help_label.size_flags_horizontal != help_flags:
		help_label.size_flags_horizontal = help_flags
	if is_instance_valid(footer_spring) and footer_spring.visible == choosing:
		footer_spring.visible = not choosing
	# The felt table follows the real lower controls, including every resize.
	if is_instance_valid(backing):
		backing.refresh_band()
	for panel in _bindings.keys():
		if not is_instance_valid(panel) or panel.get_parent() != app.hand_view:
			_unbind(panel)
	# Decorate only the exact ordered live cards, without replacing their input panels.
	_metadata.set_app(app)
	_metadata.sync(app.hand_view.get_children(), _deck.hand)
	var actionable: Array[Control] = []
	for panel in app.hand_view.get_children():
		var label := panel.get_child(0) as Label
		if label == null or not _is_actionable(label.text):
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


func _mount_table(app) -> void:
	# Exactly one table per battle: a stale one from an earlier mount is dropped first.
	for stale in _battle.find_children(TABLE_ID, "Control", true, false):
		stale.free()
	backing = FeltTableBacking.new()
	backing.name = TABLE_ID
	_battle.add_child(backing)
	# Place it immediately before the battle column, so the accepted actor-stage backdrop and
	# every existing control keep their own sibling order and draw on top of the table.
	var column := _hud.get_parent() as Control
	if column != null and column.get_parent() == _battle:
		_battle.move_child(backing, column.get_index())
	var pile_row = app.pile_label.get_parent() if is_instance_valid(app.pile_label) else null
	for content in [pile_row, app.pile_label, app.hand_view, _hud, app.end_turn_button]:
		if content is Control:
			backing.attach(content)


func _current_move_context(panel) -> Array:
	var app = get_parent()
	return [app.deck, app.party, app.battle_view, app.enemies, app.battle_result,
		app.run_rng, app.enemy_intents, app.enemy_intents._turn_index if app.enemy_intents != null else -1, panel.get_index()]


func _eligible(panel, card_id: String, deck: CombatDeck, party: CombatParty, battle) -> bool:
	var app = get_parent()
	if not is_instance_valid(panel) or not is_instance_valid(battle):
		return false
	if not _bindings.has(panel) or not _is_actionable(card_id):
		return false
	if app.deck != deck or app.party != party or app.battle_view != battle:
		return false
	if deck != _deck or party != _party or battle != _battle:
		return false
	if not panel.is_visible_in_tree() or not battle.is_visible_in_tree() or panel.get_parent() != app.hand_view:
		return false
	if _is_block_card(card_id):
		# Presentation preflight only: the pool resolver revalidates and commits.
		if app._battle_closed or not deck.turn_active or app.battle_result == null \
			or not app.battle_result.can_continue() or app.battle_result._party != party \
			or app.battle_result._enemies != app.enemies or not party.is_valid() \
			or app.enemies == null or not app.enemies.is_valid() \
			or party.is_defeated() or app.enemies.is_victorious():
			return false
	if _is_energy_card(card_id):
		# Presentation preflight only: the pool resolver revalidates and commits.
		if app._battle_closed or not deck.turn_active or app.battle_result == null \
			or not app.battle_result.can_continue() or app.battle_result._party != party \
			or app.battle_result._enemies != app.enemies or not party.is_valid() \
			or app.enemies == null or not app.enemies.is_valid() \
			or party.is_defeated() or app.enemies.is_victorious():
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
	if not _play_held(deck, party, card_id, 0):
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
	var authored: Dictionary = _metadata.definition(_pending.id)
	if not _party.is_valid() or not _deck.turn_active or _deck.energy < int(authored.get("cost", -1)):
		return false
	for hero in _party.get_heroes():
		if hero.id == authored.get("owner", ""):
			return hero.hp > 0 and hero.position in authored.get("from_positions", [])
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
	if _play_held(_deck, _party, id, position):
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
	if is_instance_valid(footer_spring):
		footer_spring.queue_free()
	footer_spring = null
	if is_instance_valid(cancel_button):
		cancel_button.queue_free()
	cancel_button = null
	if is_instance_valid(backing):
		backing.queue_free()
	backing = null
	_hud = null
	_battle = null
	_deck = null
	_party = null
	_play = null
	_block_cards = null
	_energy_cards = null
