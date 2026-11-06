class_name StitchedBattleScreen
extends Control
## S2's isolated, mounted preview. The StitchedRules session is the only combat authority.
## The shipped card map/hand is neither entered nor replaced by this opt-in screen.

signal exit_requested

const ROSTER := preload("res://scripts/live_enemy_roster.gd")
const CHROME := preload("res://scripts/stitched/stitched_battle_chrome.gd")
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const SLOTS := ["head", "arms", "torso", "legs"]
const STATUS_ORDER := [
	"bleed", "weak", "exposed", "thorns", "tangled", "blind",
	"riposte", "stun", "stun_resist", "mark", "guard",
]
const INK := Color("0d1016")
const PANEL := Color("11151edc")
const PAPER := Color("f0ddc0")
const MUTED := Color("c7b4a1")
const ACCENT := Color("e4b76a")
const ERROR := Color("ffa9a0")
const MAX_FOE_STEPS := 28

var battle: StitchedRules
var config: Dictionary = {}
var parts: Dictionary = {}
var reduced_motion := false
var receipts: Array[Dictionary] = []
var last_receipt: Dictionary = {}
var _selected_part := ""
var _target_ranks: Dictionary = {}
var _seat_buttons: Dictionary = {}
var _puppets: Dictionary = {}
var _figure_hits: Dictionary = {}
var _foot_plates: Dictionary = {}
var _rank_meters: Dictionary = {}
var _status_disclosure: NinePatchRect
var _status_disclosure_label: Label
var _part_buttons: Dictionary = {}
var _part_help_buttons: Dictionary = {}
var _part_cues: Dictionary = {}
var _part_disclosure: NinePatchRect
var _part_disclosure_text: RichTextLabel
var _part_help_dialog: AcceptDialog
var _part_hover_slot := ""
var _part_focus_slot := ""
var _action_buttons: Dictionary = {}
var _utilities_open := false
var _target_buttons: Dictionary = {}
var _labels: Dictionary = {}
var _turn_ribbon: StitchedTurnOrderRibbon
var _candle_meter: StitchedCandleMeter
var _foe_tickets: Dictionary = {}
var _foe_ticket_labels: Dictionary = {}
var _foe_ticket_target_labels: Dictionary = {}
var _foe_intents: Dictionary = {}
var _intent_disclosure: NinePatchRect
var _intent_disclosure_label: Label
var _intent_hover_rank := 0
var _intent_focus_rank := 0
var _notice := ""
var _inspected_seat := ""
var _portrait_font: Font
var _pose_catalog := LiveMovePoseCatalog.new()
var _pose_manifest: Dictionary = {}
var _displayed_actor := ""

static func read_preview() -> Dictionary:
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func begin(data: Dictionary = {}) -> bool:
	if battle != null or is_inside_tree():
		return false
	config = data.duplicate(true) if not data.is_empty() else read_preview()
	if str(config.get("mode", "")) != "stitched" or not config.get("heroes") is Array or not config.get("foes") is Array:
		return false
	# Export presets intentionally omit tests/. An inline validated representative
	# catalog travels with the Web preview instead of depending on test fixtures.
	var catalog: Dictionary = StitchedParts.build_catalog(config.get("parts", []))
	if not bool(catalog.get("ok", false)):
		return false
	var payload := config.duplicate(true)
	payload["parts"] = catalog["parts"]
	var result := StitchedRules.create(payload)
	if not bool(result.get("ok", false)):
		return false
	battle = result["battle"]
	parts = catalog["by_id"]
	reduced_motion = bool(ProjectSettings.get_setting("patchwork/reduced_motion", false))
	return true


func _ready() -> void:
	if battle == null or not battle.is_valid():
		return
	name = "StitchedBattleScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_build_screen()
	_drive_foes()
	_refresh()
	if _action_buttons.has("pass"):
		_action_buttons["pass"].grab_focus()


func _panel(rect: Rect2, tint: Color = PANEL) -> ColorRect:
	var panel := ColorRect.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.color = tint
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel


func _label(text: String, rect: Rect2, font_size: int = 18, color: Color = PAPER, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if _portrait_font != null:
		label.add_theme_font_override("font", _portrait_font)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(title: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", ACCENT)
	button.add_theme_color_override("font_focus_color", ACCENT)
	CHROME.style_button(button)
	button.pressed.connect(callback)
	add_child(button)
	return button


func _sewn_panel(rect: Rect2, tint: Color = Color("29232ce8")) -> NinePatchRect:
	var panel := NinePatchRect.new()
	panel.texture = load("res://assets/paper/ui/panel_felt.png") as Texture2D
	panel.position = rect.position
	panel.size = rect.size
	panel.modulate = tint
	panel.patch_margin_left = 18
	panel.patch_margin_right = 18
	panel.patch_margin_top = 14
	panel.patch_margin_bottom = 14
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel


func _build_screen() -> void:
	var font_path := "res://assets/fonts/LondrinaSolid-Regular.ttf"
	if ResourceLoader.exists(font_path):
		_portrait_font = load(font_path) as Font
	_panel(Rect2(0, 0, 1280, 720), INK)
	var stage_path := ROSTER.stage_backdrop_path("Fight", 0)
	if ResourceLoader.exists(stage_path, "Texture2D"):
		var backdrop := TextureRect.new()
		backdrop.name = "SharedStitchedBackdrop"
		backdrop.texture = load(stage_path)
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.position = Vector2(0, 60)
		backdrop.size = Vector2(1280, 500)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(backdrop)
	_panel(Rect2(0, 60, 1280, 500), Color(0.045, 0.05, 0.075, 0.28))
	_sewn_panel(Rect2(12, 10, 1256, 82))
	CHROME.action_tray(self, Rect2(12, 557, 1256, 155))
	_sewn_panel(Rect2(19, 562, 221, 144))
	_sewn_panel(Rect2(246, 562, 780, 144))
	_sewn_panel(Rect2(1031, 562, 230, 144))
	_label("STITCHED  /  " + str(config.get("title", "A frayed fray")), Rect2(26, 13, 420, 28), 26, ACCENT)
	_labels["round"] = _label("", Rect2(454, 13, 190, 28), 21)
	_labels["order"] = _label("TURN ORDER", Rect2(454, 46, 99, 42), 17, MUTED)
	_turn_ribbon = StitchedTurnOrderRibbon.new()
	_turn_ribbon.name = "StitchedTurnOrderRibbon"
	_turn_ribbon.position = Vector2(557, 46)
	_turn_ribbon.size = Vector2(690, 42)
	add_child(_turn_ribbon)
	_candle_meter = StitchedCandleMeter.new()
	_candle_meter.name = "StitchedCandleMeter"
	_candle_meter.position = Vector2(651, 10)
	_candle_meter.size = Vector2(340, 33)
	add_child(_candle_meter)
	_labels["candle"] = _candle_meter.headline
	_label("HEROES  ·  back 4 to front 1", Rect2(25, 105, 530, 30), 17, ACCENT)
	_label("FOES  ·  front 1 to back 4", Rect2(710, 105, 545, 30), 17, ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_labels["hero"] = _label("", Rect2(27, 564, 202, 25), 18, ACCENT)
	_labels["stats"] = _label("", Rect2(27, 590, 204, 86), 13)
	_labels["stats"].vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_labels["thread"] = _label("", Rect2(27, 679, 204, 24), 12, ERROR)
	_label("SEWN ABILITIES  ·  PICK A PART, THEN A LIT FIGURE", Rect2(259, 561, 758, 18), 14, ACCENT)
	for index in range(4):
		var slot: String = SLOTS[index]
		var x := 260 + index * 188
		_part_buttons[slot] = _button(slot.capitalize(), Rect2(x, 581, 152, 30),
			func(): select_part(slot))
		_part_buttons[slot].name = "Worn" + slot.capitalize()
		_part_buttons[slot].add_theme_font_size_override("font_size", 12)
		_part_buttons[slot].clip_text = true
		_part_buttons[slot].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_part_help_buttons[slot] = _button("?", Rect2(x + 154, 581, 29, 30),
			func(): _open_part_help(slot))
		_part_help_buttons[slot].name = "Inspect" + slot.capitalize()
		_part_help_buttons[slot].add_theme_font_size_override("font_size", 14)
		_bind_part_inspection(_part_buttons[slot], slot)
		_bind_part_inspection(_part_help_buttons[slot], slot)
	_labels["preview"] = _label("", Rect2(262, 613, 749, 26), 12, MUTED)
	_labels["preview"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_labels["preview"].vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_action_buttons["move_front"] = _button("Move front", Rect2(260, 642, 136, 29), func(): submit_move(-1))
	_action_buttons["move_back"] = _button("Move back", Rect2(403, 642, 136, 29), func(): submit_move(1))
	_action_buttons["re_tie"] = _button("Re-tie", Rect2(546, 642, 136, 29), func(): submit_re_tie())
	_action_buttons["pass"] = _button("Pass turn", Rect2(689, 642, 150, 29), func(): submit_pass())
	_action_buttons["retreat"] = _button("Retreat", Rect2(846, 642, 165, 29), func(): submit_retreat())
	for index in range(4):
		var rank := index + 1
		var hero_key := "hero_" + str(rank)
		var foe_key := "foe_" + str(rank)
		_target_buttons[hero_key] = _button("Ally %d" % rank,
			Rect2(260 + index * 92, 675, 88, 29), func(): submit_target("hero", rank))
		_bind_seat_signals(_target_buttons[hero_key], hero_key)
		_target_buttons[foe_key] = _button("Foe %d" % rank,
			Rect2(642 + index * 92, 675, 88, 29), func(): submit_target("foe", rank))
		_bind_seat_signals(_target_buttons[foe_key], foe_key)
	_labels["log"] = _label("Choose a sewn part or another turn action.", Rect2(1041, 567, 207, 104), 13, MUTED)
	_labels["log"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_labels["log"].vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_build_part_disclosure()
	_labels["help"] = _label("Pick a part, then a lit target.\nMove, Re-tie or Pass a turn.\nRetreat risks candlelight.", Rect2(1043, 567, 208, 42), 12, PAPER)
	_action_buttons["help"] = _button("Help & settings", Rect2(1043, 675, 208, 29), func(): _set_utilities_open(true))
	var toggle := CheckButton.new()
	toggle.text = "Reduce motion"
	toggle.position = Vector2(1043, 611)
	toggle.size = Vector2(208, 27)
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.button_pressed = reduced_motion
	toggle.add_theme_font_size_override("font_size", 14)
	CHROME.style_button(toggle)
	toggle.toggled.connect(set_reduced_motion)
	add_child(toggle)
	_action_buttons["reduce_motion"] = toggle
	_action_buttons["exit"] = _button("Back to title", Rect2(1043, 642, 208, 29), func(): exit_requested.emit())
	_action_buttons["close_help"] = _button("Close help", Rect2(1043, 675, 208, 29), func(): _set_utilities_open(false))
	_set_utilities_open(false, false)
	# Equally spaced back-to-front ranks on one quilt, with a clear centre aisle.
	# Each 170px slot centres its own fitted authored figure and underfoot plaque.
	# Draw back ranks first; targeting still follows the actual occupied art.
	for side in ["hero", "foe"]:
		for rank in range(4, 0, -1):
			var centre := (541.0 - (rank - 1) * 150.0) if side == "hero" else (
				739.0 + (rank - 1) * 150.0)
			_seat(side, rank, centre - 85.0)
	_build_foe_intent_tickets()
	_build_status_disclosure()
	# Pose manifest is optional: it only selects authored pixels, never a game action.
	var pose_file := FileAccess.open(LiveMovePoseCatalog.MANIFEST_PATH, FileAccess.READ)
	if pose_file != null:
		var data: Variant = JSON.parse_string(pose_file.get_as_text())
		if data is Dictionary:
			_pose_manifest = data


func _set_utilities_open(value: bool, restore_focus: bool = true) -> void:
	_utilities_open = value
	_labels["log"].visible = not value
	_labels["help"].visible = value
	_action_buttons["help"].visible = not value
	for key in ["reduce_motion", "exit", "close_help"]:
		_action_buttons[key].visible = value
	_present_part_disclosure()
	if value:
		_action_buttons["close_help"].grab_focus()
	elif restore_focus:
		_action_buttons["help"].grab_focus()


func _seat(side: String, rank: int, x: float) -> void:
	var key := side + "_" + str(rank)
	var puppet := ROSTER.Puppet.new()
	puppet.name = "StageFigure" + side.capitalize() + str(rank)
	puppet.position = Vector2(x, -6)
	puppet.size = Vector2(170, 508)
	puppet.stage_height = 508
	puppet.intent_band = 0
	puppet.tag_height = 0
	puppet.slot = rank
	puppet.facing = 1.0 if side == "hero" else -1.0
	add_child(puppet)
	_puppets[key] = puppet
	# Only the authored painted-figure rectangle catches pointer input. The
	# shared Puppet stays read-only; this independent hit surface commits only
	# through the existing legal target gate. It is also a keyboard focus stop.
	var hit := Control.new()
	hit.name = "FigureTarget" + side.capitalize() + str(rank)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.focus_mode = Control.FOCUS_ALL
	hit.visible = false
	hit.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			submit_target(side, rank)
			hit.accept_event())
	_bind_seat_signals(hit, key)
	add_child(hit)
	_figure_hits[key] = hit
	# Enlarged art-backed plate: each 170px patch has two readable 148px
	# text rows. The patches' sewn edges may meet, but text rows never do.
	var foot_x := x
	var plate := _sewn_panel(Rect2(foot_x, 505, 170, 50), Color("88777fae"))
	_foot_plates[key] = plate
	var tag := _button("", Rect2(foot_x + 11, 506, 148, 23),
		func(): submit_target(side, rank))
	tag.name = "RankPlate" + side.capitalize() + str(rank)
	tag.flat = false
	tag.add_theme_font_size_override("font_size", 16)
	tag.clip_text = true
	tag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bind_seat_signals(tag, key)
	_seat_buttons[key] = tag
	# Only heap-only ranks need a separate second-row label. Living ranks
	# use the sewn HP/FRAY meter captions below, never a duplicate status overlay.
	_labels[key] = _label("", Rect2(foot_x + 11, 530, 148, 22), 15, PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	_labels[key].clip_text = true
	_labels[key].add_theme_color_override("font_outline_color", Color("25181d"))
	_labels[key].add_theme_constant_override("outline_size", 2)
	_labels[key].visible = false
	_rank_meters[key] = CHROME.make_rank_meters(self, side, foot_x)


func _build_status_disclosure() -> void:
	_status_disclosure = _sewn_panel(Rect2(22, 139, 592, 52), Color("ac9696"))
	_status_disclosure.name = "FullRankStatus"
	_status_disclosure.visible = false
	_status_disclosure.z_index = 4
	_status_disclosure_label = Label.new()
	_status_disclosure_label.position = Vector2(14, 5)
	_status_disclosure_label.size = Vector2(564, 42)
	_status_disclosure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_disclosure_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_disclosure_label.add_theme_font_size_override("font_size", 12)
	_status_disclosure_label.add_theme_color_override("font_color", PAPER)
	_status_disclosure_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_disclosure.add_child(_status_disclosure_label)


func _refresh_figure_hits() -> void:
	for key in _puppets:
		var puppet: Control = _puppets[key]
		var hit: Control = _figure_hits[key]
		var side := str(key).split("_")[0]
		var rank := int(str(key).split("_")[1])
		var detail := status_detail(side, rank)
		var occupied := puppet.visible
		var art_rect: Rect2 = puppet.posed_actor_rect() if occupied else Rect2()
		hit.visible = occupied and art_rect.size.x > 0.0 and art_rect.size.y > 0.0
		hit.position = puppet.position + art_rect.position
		hit.size = art_rect.size
		hit.tooltip_text = detail
		var legal := _target_ranks.has(key)
		# The plate remains focusable for full status inspection even when not
		# a legal target; submit_target remains the sole fail-closed action gate.
		_seat_buttons[key].disabled = not _foot_plates[key].visible
		_seat_buttons[key].tooltip_text = detail



func _update_figure_lights() -> void:
	for key in _puppets:
		var puppet: Control = _puppets[key]
		var legal := _target_ranks.has(key)
		puppet.modulate = Color(1.40, 1.25, 0.98) if _inspected_seat == key else (
			Color(1.25, 1.15, 0.89) if legal else Color.WHITE)
		_foot_plates[key].modulate = Color("c6a56b") if legal else Color("88777fae")


func _present_status_disclosure() -> void:
	if _status_disclosure == null:
		return
	var key := _inspected_seat
	_status_disclosure.visible = not key.is_empty() and _seat_buttons.has(key)
	_status_disclosure_label.text = _seat_detail_for(key) if _status_disclosure.visible else ""


func _build_foe_intent_tickets() -> void:
	# One presentation-only control per physical foe rank, centred at the
	# accepted 150px intervals. Every ticket rebinds by authoritative foe ID.
	for rank in range(1, 5):
		var ticket := StitchedFoeIntentPlate.new()
		ticket.name = "FoeIntentRank%d" % rank
		ticket.position = Vector2(664 + (rank - 1) * 150, 140)
		add_child(ticket)
		_foe_tickets[rank] = ticket
		_foe_ticket_labels[rank] = ticket.primary
		_foe_ticket_target_labels[rank] = ticket.secondary
		ticket.mouse_entered.connect(func(): _foe_intent_enter(rank, false))
		ticket.mouse_exited.connect(func(): _foe_intent_exit(rank, false))
		ticket.focus_entered.connect(func(): _foe_intent_enter(rank, true))
		ticket.focus_exited.connect(func(): _foe_intent_exit(rank, true))
	# Full names and all affected ranks remain readable by pointer and
	# keyboard. This independent image-backed panel never drives combat.
	_intent_disclosure = NinePatchRect.new()
	_intent_disclosure.name = "FoeIntentDisclosure"
	_intent_disclosure.position = Vector2(22, 140)
	_intent_disclosure.size = Vector2(635, 80)
	_intent_disclosure.texture = load("res://assets/paper/ui/hud_name_plate.png") as Texture2D
	_intent_disclosure.self_modulate = Color("62464a")
	_intent_disclosure.patch_margin_left = 22
	_intent_disclosure.patch_margin_right = 22
	_intent_disclosure.patch_margin_top = 13
	_intent_disclosure.patch_margin_bottom = 13
	_intent_disclosure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_disclosure.visible = false
	_intent_disclosure.z_index = 3
	add_child(_intent_disclosure)
	_intent_disclosure_label = Label.new()
	_intent_disclosure_label.name = "FullIntent"
	_intent_disclosure_label.position = Vector2(15, 6)
	_intent_disclosure_label.size = Vector2(605, 68)
	_intent_disclosure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intent_disclosure_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intent_disclosure_label.add_theme_font_size_override("font_size", 15)
	_intent_disclosure_label.add_theme_color_override("font_color", PAPER)
	_intent_disclosure_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_disclosure.add_child(_intent_disclosure_label)


func _foe_intent_enter(rank: int, focused: bool) -> void:
	if not _foe_tickets[rank].visible:
		return
	if focused:
		_intent_focus_rank = rank
	else:
		_intent_hover_rank = rank
	_present_foe_intent_disclosure()


func _foe_intent_exit(rank: int, focused: bool) -> void:
	if focused and _intent_focus_rank == rank:
		_intent_focus_rank = 0
	if not focused and _intent_hover_rank == rank:
		_intent_hover_rank = 0
	_present_foe_intent_disclosure()


func _present_foe_intent_disclosure() -> void:
	if _intent_disclosure == null:
		return
	var rank := _intent_focus_rank if _intent_focus_rank != 0 else _intent_hover_rank
	var ticket: StitchedFoeIntentPlate = _foe_tickets.get(rank)
	_intent_disclosure.visible = ticket != null and ticket.visible
	var full := ticket.tooltip_text if _intent_disclosure.visible else ""
	_intent_disclosure_label.text = full
	if _intent_disclosure.visible:
		var font: Font = _intent_disclosure_label.get_theme_font("font")
		if font != null:
			for font_size in [15, 14, 13, 12, 11]:
				_intent_disclosure_label.add_theme_font_size_override("font_size", font_size)
				if font.get_multiline_string_size(full, HORIZONTAL_ALIGNMENT_LEFT,
						_intent_disclosure_label.size.x, font_size).y <= _intent_disclosure_label.size.y:
					break
	for seat_rank in _foe_tickets:
		_foe_tickets[seat_rank].set_inspected(seat_rank == rank and _intent_disclosure.visible)


func _refresh_foe_intents() -> void:
	_foe_intents.clear()
	for rank in range(1, 5):
		var ticket: StitchedFoeIntentPlate = _foe_tickets[rank]
		var foe := _unit_at("foe", rank)
		var intent := StitchedFoeIntent.choose(battle, foe)
		if intent.is_empty() or not _heap_at(rank).is_empty():
			ticket.clear_intent()
			if _intent_focus_rank == rank:
				_intent_focus_rank = 0
			if _intent_hover_rank == rank:
				_intent_hover_rank = 0
			continue
		_foe_intents[rank] = intent
		ticket.present_intent(intent, rank)
	_present_foe_intent_disclosure()


func _bind_seat_signals(control: Control, key: String) -> void:
	control.mouse_entered.connect(func(): _inspect_seat(key))
	control.mouse_exited.connect(func(): _clear_seat_inspection(key))
	control.focus_entered.connect(func(): _inspect_seat(key))
	control.focus_exited.connect(func(): _clear_seat_inspection(key))


func _unit_at(side: String, rank: int) -> Dictionary:
	if battle == null:
		return {}
	for unit in battle.get_heroes() if side == "hero" else battle.get_foes():
		if int(unit["rank"]) == rank and not bool(unit["lost"]) and not bool(unit["dead"]) and (side == "hero" or int(unit.get("hp", 0)) > 0):
			return unit
	return {}


func _heap_at(rank: int) -> Dictionary:
	if battle == null:
		return {}
	for heap in battle.get_heaps():
		if int(heap["rank"]) == rank:
			return heap
	return {}


func _status_tokens(unit: Dictionary) -> Array[String]:
	var tokens: Array[String] = []
	if unit.is_empty():
		return tokens
	var statuses: Variant = unit.get("statuses", {})
	if statuses is Dictionary:
		for key in STATUS_ORDER:
			if statuses.has(key) and int(statuses[key]) > 0:
				tokens.append("%s %d" % [str(key).replace("_", " ").to_upper(), int(statuses[key])])
		var extras: Array[String] = []
		for key in statuses:
			var name := str(key)
			if not name in STATUS_ORDER and int(statuses[key]) > 0:
				extras.append(name)
		extras.sort()
		for name in extras:
			tokens.append("%s %d" % [name.replace("_", " ").to_upper(), int(statuses[name])])
	var dodge_buff: Variant = unit.get("dodge_buff", {})
	if dodge_buff is Dictionary:
		var amount := int(dodge_buff.get("amount", 0))
		var turns := int(dodge_buff.get("turns", 0))
		if amount > 0 and turns > 0:
			tokens.append("DODGE +%d / %d turns" % [amount, turns])
	if bool(unit.get("hanging", false)):
		tokens.append("HANGING")
	return tokens


func status_detail(side: String, rank: int) -> String:
	if rank < 1 or rank > 4 or not side in ["hero", "foe"]:
		return ""
	var unit := _unit_at(side, rank)
	if not unit.is_empty():
		var header := "R%d %s · HP %d/%d" % [rank, str(unit.get("name", "")), int(unit.get("hp", 0)), int(unit.get("max_hp", 0))]
		if side == "hero" or int(unit.get("fray", 0)) > 0:
			header += " · FRAY %d/200" % int(unit.get("fray", 0))
		var tokens := _status_tokens(unit)
		return header + "\nSTATUS: " + (", ".join(tokens) if not tokens.is_empty() else "none")
	var heap := _heap_at(rank) if side == "foe" else {}
	if not heap.is_empty():
		return "R%d Scrap heap · SCRAP %d HP\nSTATUS: none" % [rank, int(heap.get("hp", 0))]
	return "R%d %s · EMPTY\nSTATUS: none" % [rank, side.capitalize()]


func _default_log_text() -> String:
	return _notice if not _notice.is_empty() else "Choose a sewn ability, a move, or Pass.\nEach committed action uses the seeded battle rules."


func _seat_detail_for(key: String) -> String:
	var parts_key := key.split("_")
	if parts_key.size() != 2:
		return _default_log_text()
	var detail := status_detail(str(parts_key[0]), int(parts_key[1]))
	return detail if not detail.is_empty() else _default_log_text()


func _inspect_seat(key: String) -> void:
	if not _seat_buttons.has(key):
		return
	_inspected_seat = key
	if _labels.has("log"):
		_labels["log"].text = _seat_detail_for(key)
		_labels["log"].tooltip_text = _seat_detail_for(key)
	_present_status_disclosure()
	_present_forecast()
	_update_figure_lights()


func _clear_seat_inspection(key: String = "") -> void:
	if key.is_empty() or _inspected_seat == key:
		_inspected_seat = ""
		if _labels.has("log"):
			_labels["log"].text = _default_log_text()
			_labels["log"].tooltip_text = _default_log_text()
		_present_status_disclosure()
		_present_forecast()
		_update_figure_lights()


func _art_for(id: String) -> Dictionary:
	var paths := ROSTER.art_paths(id)
	var images: Dictionary = {}
	for kind in paths:
		var path: String = paths[kind]
		if ResourceLoader.exists(path, "Texture2D"):
			images[kind] = load(path)
	return images


func _sync_puppet(key: String, unit: Dictionary) -> void:
	var puppet: Variant = _puppets[key]
	var id := str(unit.get("id", ""))
	if puppet.actor_id != id:
		puppet.bind_actor(id, _art_for(id))
	if not unit.is_empty():
		puppet.fallen = bool(unit.get("dead", false)) or bool(unit.get("lost", false))
		# The active hero keeps the same physical foot line as every other rank.
		# Legality/hover now highlights authored pixels without lifting their feet.
		puppet.scale = Vector2.ONE
	else:
		puppet.fallen = false
		puppet.scale = Vector2.ONE
	puppet.visible = not id.is_empty()
	puppet.set_process(not reduced_motion)
	puppet.queue_redraw()


func _refresh() -> void:
	if battle == null or not battle.is_valid():
		if _candle_meter != null:
			_candle_meter.clear_readout()
		return
	var acting := battle.get_unit(battle.current_actor_id())
	var hero_turn := battle.current_side() == "hero" and not battle.is_over()
	_labels["round"].text = "ROUND %d  ·  %s" % [battle.round_number(), battle.outcome().to_upper()]
	# Project authoritative round slots without reading a turn pointer or rolling.
	var entries: Array[Dictionary] = []
	for id in battle.turn_order():
		entries.append(battle.get_unit(str(id)))
	_turn_ribbon.show_order(entries, battle.current_actor_id(), battle.is_over())
	var band: Dictionary = battle.candle_band()
	_candle_meter.set_readout(battle.candle(), band)
	_labels["hero"].text = str(acting.get("name", "Battle ended"))
	if acting.is_empty():
		_labels["stats"].text = "Outcome: " + battle.outcome().capitalize()
	else:
		_labels["stats"].text = "R%d · %s  HP %d/%d\nFray %d/200 · Speed %d\nDodge %d · ACC %+d\nPROT %d%% · %s" % [
			int(acting["rank"]), str(acting["side"]).capitalize(), int(acting["hp"]), int(acting["max_hp"]),
			int(acting["fray"]), int(acting["speed"]), int(acting["dodge"]), int(acting["acc"]),
			int(acting["prot"]), str(acting.get("resolve", "none")) if not str(acting.get("resolve", "")).is_empty() else "steady"]
	var cuts: Dictionary = battle.thread_cuts()
	var cut_names := PackedStringArray()
	for id in cuts:
		cut_names.append(str(id))
	_labels["thread"].text = "THREAD CUT: " + (", ".join(cut_names) if not cut_names.is_empty() else "none")
	for side in ["hero", "foe"]:
		for rank in range(1, 5):
			var key: String = str(side) + "_" + str(rank)
			var unit := _unit_at(side, rank)
			_sync_puppet(key, unit)
			var button: Button = _seat_buttons[key]
			var heap := _heap_at(rank) if side == "foe" and unit.is_empty() else {}
			var occupied := not unit.is_empty() or not heap.is_empty()
			CHROME.present_rank(_rank_meters[key], unit, side)
			_foot_plates[key].visible = occupied
			button.visible = occupied
			# RankMeters owns the only occupied HP/fray row. Preserve the same
			# label solely for the heap HP readout; an empty rank paints nothing.
			_labels[key].visible = unit.is_empty() and not heap.is_empty()
			button.text = "R%d  %s" % [rank, str(unit.get("name", "Scrap heap" if not heap.is_empty() else "—"))]
			button.tooltip_text = status_detail(side, rank)
			_labels[key].text = "SCRAP %d HP" % int(heap.get("hp", 0)) if not heap.is_empty() and unit.is_empty() else ""
	_refresh_foe_intents()
	_target_ranks.clear()
	var actor_key := str(acting.get("id", "")) if hero_turn else ""
	if _displayed_actor != actor_key:
		_displayed_actor = actor_key
		_part_hover_slot = ""
		_part_focus_slot = ""
	_part_cues.clear()
	for slot in SLOTS:
		var button: Button = _part_buttons[slot]
		var help: Button = _part_help_buttons[slot]
		var equipped: Dictionary = acting.get("parts", {}).get(slot, {}) if hero_turn else {}
		var can_use := hero_turn and _valid_part(acting, equipped)
		var reason := _part_lock_reason(acting, equipped) if hero_turn else "No active hero"
		var cue := StitchedPartActionCues.format_action(acting if hero_turn else {},
			slot, equipped, parts, can_use, reason)
		_part_cues[slot] = cue
		button.disabled = not can_use
		button.text = str(cue["title"])
		button.tooltip_text = str(cue["full"])
		help.disabled = not hero_turn
		help.tooltip_text = "Inspect " + str(cue["full"])
		if slot == _selected_part and not can_use:
			_selected_part = ""
	_present_part_disclosure()
	if hero_turn and not _selected_part.is_empty():
		var selected: Dictionary = acting["parts"][_selected_part]
		var ability: Dictionary = StitchedParts.ability_at_tier(parts[str(selected["id"])], int(selected["tier"]))
		for rank in range(1, 5):
			var targets: Array = battle._legal_targets(acting, ability, rank)
			if not targets.is_empty():
				var side := "hero" if str(targets[0]["side"]) == "hero" else "foe"
				if not StitchedTargetForecast.for_rank(battle, acting, ability, side, rank).is_empty():
					_target_ranks[side + "_" + str(rank)] = true
	_refresh_figure_hits()
	_update_figure_lights()
	for key in _target_buttons:
		_target_buttons[key].disabled = not _target_ranks.has(key)
	_action_buttons["move_front"].disabled = not hero_turn or not _can_move(-1)
	_action_buttons["move_back"].disabled = not hero_turn or not _can_move(1)
	_action_buttons["re_tie"].disabled = not hero_turn or not cuts.has(str(acting.get("id", "")))
	_action_buttons["pass"].disabled = not hero_turn
	_action_buttons["retreat"].disabled = not hero_turn or battle.is_boss_encounter()
	_labels["log"].text = _seat_detail_for(_inspected_seat) if not _inspected_seat.is_empty() else _default_log_text()
	_labels["log"].tooltip_text = _labels["log"].text
	_present_status_disclosure()
	_present_forecast()


func _build_part_disclosure() -> void:
	# Reuse the sewn image ticket over the existing log area, never the target
	# forecast or any active controls. Long help can scroll independently.
	_part_disclosure = NinePatchRect.new()
	_part_disclosure.name = "WornPartDisclosure"
	_part_disclosure.texture = load("res://assets/paper/ui/hud_name_plate.png") as Texture2D
	_part_disclosure.position = Vector2(1036, 562)
	_part_disclosure.size = Vector2(222, 78)
	_part_disclosure.patch_margin_left = 20
	_part_disclosure.patch_margin_right = 20
	_part_disclosure.patch_margin_top = 12
	_part_disclosure.patch_margin_bottom = 12
	_part_disclosure.mouse_filter = Control.MOUSE_FILTER_PASS
	_part_disclosure.visible = false
	add_child(_part_disclosure)
	_part_disclosure_text = RichTextLabel.new()
	_part_disclosure_text.name = "FullWornPart"
	_part_disclosure_text.position = Vector2(9, 6)
	_part_disclosure_text.size = Vector2(202, 66)
	_part_disclosure_text.add_theme_color_override("default_color", PAPER)
	_part_disclosure_text.add_theme_font_size_override("normal_font_size", 12)
	_part_disclosure_text.scroll_active = true
	_part_disclosure_text.fit_content = false
	_part_disclosure_text.selection_enabled = true
	_part_disclosure_text.mouse_filter = Control.MOUSE_FILTER_STOP
	_part_disclosure_text.focus_mode = Control.FOCUS_NONE
	_part_disclosure.add_child(_part_disclosure_text)
	_part_help_dialog = AcceptDialog.new()
	_part_help_dialog.name = "WornPartFullHelp"
	_part_help_dialog.title = "Worn sewn ability"
	_part_help_dialog.min_size = Vector2i(640, 360)
	add_child(_part_help_dialog)


func _bind_part_inspection(button: Button, slot: String) -> void:
	button.mouse_entered.connect(func(): _part_inspect_enter(slot, false))
	button.mouse_exited.connect(func(): _part_inspect_exit(slot, false))
	button.focus_entered.connect(func(): _part_inspect_enter(slot, true))
	button.focus_exited.connect(func(): _part_inspect_exit(slot, true))


func _part_inspect_enter(slot: String, focused: bool) -> void:
	if not _part_help_buttons.has(slot) or _part_help_buttons[slot].disabled:
		return
	if focused:
		_part_focus_slot = slot
	else:
		_part_hover_slot = slot
	_present_part_disclosure()
	_present_forecast()


func _part_inspect_exit(slot: String, focused: bool) -> void:
	if focused and _part_focus_slot == slot:
		_part_focus_slot = ""
	elif not focused and _part_hover_slot == slot:
		_part_hover_slot = ""
	_present_part_disclosure()
	_present_forecast()


func _part_inspected_slot() -> String:
	return _part_focus_slot if not _part_focus_slot.is_empty() else _part_hover_slot


func _present_part_disclosure() -> void:
	if _part_disclosure == null:
		return
	var slot := _part_inspected_slot()
	var cue: Dictionary = _part_cues.get(slot, {})
	_part_disclosure.visible = not _utilities_open and not cue.is_empty() and not _part_help_buttons[slot].disabled
	if not _part_disclosure.visible:
		_part_disclosure_text.text = ""
		return
	var full := str(cue["full"])
	if _part_disclosure_text.text != full:
		_part_disclosure_text.text = full
	_part_disclosure_text.tooltip_text = full
	_part_disclosure.tooltip_text = full


func _open_part_help(slot: String) -> void:
	if not _part_help_buttons.has(slot) or _part_help_buttons[slot].disabled:
		return
	var cue: Dictionary = _part_cues.get(slot, {})
	if cue.is_empty():
		return
	_part_help_dialog.title = str(cue["title"])
	_part_help_dialog.dialog_text = str(cue["full"])
	_part_help_dialog.popup_centered()


func _part_lock_reason(actor: Dictionary, equipped: Dictionary) -> String:
	if battle == null or actor.is_empty() or battle.is_over() or battle.current_side() != "hero":
		return "No active hero"
	var id := str(equipped.get("id", ""))
	if id.is_empty():
		return "Unfilled — no worn part"
	if not parts.has(id):
		return "Unknown worn part"
	if bool(equipped.get("torn", false)):
		return "TORN — mend at Sewing Circle"
	var ability := StitchedParts.ability_at_tier(parts[id], int(equipped.get("tier", 1)))
	if ability.is_empty():
		return "No ability on worn part"
	if not StitchedParts.ranks_allowed(int(ability.get("launch_mask", 0)), int(actor.get("rank", 0))):
		return "Wrong launch rank (current R%d)" % int(actor.get("rank", 0))
	var blocked: Dictionary = battle._self_move_gate(actor, ability)
	if not blocked.is_empty():
		return "Movement/thread lock: " + str(blocked.get("error", "self-move blocked"))
	for rank in range(1, 5):
		if not battle._legal_targets(actor, ability, rank).is_empty():
			return ""
	return "No legal target (rank or thread restrictions)"


func _valid_part(actor: Dictionary, equipped: Dictionary) -> bool:
	var id := str(equipped.get("id", ""))
	if id.is_empty() or bool(equipped.get("torn", false)) or not parts.has(id):
		return false
	var ability: Dictionary = StitchedParts.ability_at_tier(parts[id], int(equipped["tier"]))
	if ability.is_empty() or not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor["rank"])) or not battle._self_move_gate(actor, ability).is_empty():
		return false
	for rank in range(1, 5):
		if not battle._legal_targets(actor, ability, rank).is_empty():
			return true
	return false


func _can_move(direction: int) -> bool:
	if battle == null or battle.current_side() != "hero":
		return false
	var actor := battle.get_unit(battle.current_actor_id())
	return not actor.is_empty() and bool(battle._shift_valid(actor, direction).get("ok", false))


func _preview_text(actor: Dictionary, ability: Dictionary) -> String:
	var rank_labels: Array[String] = []
	for rank in range(1, 5):
		var targets: Array = battle._legal_targets(actor, ability, rank)
		if targets.is_empty():
			continue
		var side := str(targets[0].get("side", ""))
		if not StitchedTargetForecast.for_rank(battle, actor, ability, side, rank).is_empty():
			rank_labels.append(str(rank))
	if rank_labels.is_empty():
		return str(ability["name"]) + " · no legal targets"
	return str(ability["name"]) + " · legal ranks " + ", ".join(rank_labels) + " · hover or focus a lit rank for its forecast."


func _present_forecast() -> void:
	if not _labels.has("preview") or battle == null:
		return
	var generic := "Select a legal part to see its range, hit chance and damage. No RNG spent."
	var acting := battle.get_unit(battle.current_actor_id())
	var ability: Dictionary = {}
	if battle.current_side() == "hero" and not battle.is_over() and not _selected_part.is_empty():
		var equipped: Dictionary = acting.get("parts", {}).get(_selected_part, {})
		if _valid_part(acting, equipped):
			ability = StitchedParts.ability_at_tier(parts[str(equipped["id"])], int(equipped["tier"]))
	if not ability.is_empty():
		generic = _preview_text(acting, ability)
	var forecast: Dictionary = {}
	if not ability.is_empty() and _target_ranks.has(_inspected_seat):
		var key_parts := _inspected_seat.split("_")
		if key_parts.size() == 2:
			forecast = StitchedTargetForecast.for_rank(battle, acting, ability, str(key_parts[0]), int(key_parts[1]))
	var inspected_slot := _part_inspected_slot()
	var cue: Dictionary = _part_cues.get(inspected_slot, {})
	# Lit-rank hit/damage is always more important than an ability's help digest.
	_labels["preview"].text = str(forecast.get("text", cue.get("digest", generic)))
	_labels["preview"].tooltip_text = str(forecast.get("tooltip", cue.get("full", "")))
	for key in _seat_buttons:
		var detail := _seat_detail_for(key)
		var tip := str(forecast.get("tooltip", "")) if key == _inspected_seat else ""
		_seat_buttons[key].tooltip_text = detail + ("\n\n" + tip if not tip.is_empty() else "")
		if _figure_hits.has(key):
			_figure_hits[key].tooltip_text = _seat_buttons[key].tooltip_text
		if _target_buttons.has(key):
			_target_buttons[key].tooltip_text = detail + ("\n\n" + tip if not tip.is_empty() else "")


func select_part(slot: String) -> bool:
	var actor := battle.get_unit(battle.current_actor_id()) if battle != null else {}
	if battle == null or battle.current_side() != "hero" or not slot in SLOTS or not _valid_part(actor, actor.get("parts", {}).get(slot, {})):
		return false
	_selected_part = slot
	_refresh()
	return true


func legal_targets() -> Dictionary:
	return _target_ranks.duplicate(true)


func submit_target(side: String, rank: int) -> Dictionary:
	var key := side + "_" + str(rank)
	if not _target_ranks.has(key) or _selected_part.is_empty():
		return {"ok": false, "error": "target is not legal"}
	var actor := battle.get_unit(battle.current_actor_id())
	if actor.is_empty() or not actor["parts"].has(_selected_part):
		return {"ok": false, "error": "no acting part"}
	return submit_part(str(actor["parts"][_selected_part]["id"]), rank)


func submit_part(part_id: String, rank: int) -> Dictionary:
	var actor := battle.get_unit(battle.current_actor_id()) if battle != null else {}
	if battle == null or battle.current_side() != "hero" or rank < 1 or rank > 4:
		return {"ok": false, "error": "not an active hero rank"}
	var equipped: Dictionary = battle._equipment(actor, part_id)
	if not _valid_part(actor, equipped):
		return {"ok": false, "error": "part unavailable or torn"}
	var ability: Dictionary = StitchedParts.ability_at_tier(parts[part_id], int(equipped["tier"]))
	if battle._legal_targets(actor, ability, rank).is_empty():
		return {"ok": false, "error": "illegal target"}
	return _commit(battle.use_part(part_id, rank))


func submit_move(direction: int) -> Dictionary:
	if not _can_move(direction):
		return {"ok": false, "error": "move blocked"}
	return _commit(battle.move(direction))


func submit_re_tie() -> Dictionary:
	if battle == null or battle.current_side() != "hero" or not battle.thread_cuts().has(battle.current_actor_id()):
		return {"ok": false, "error": "thread is intact"}
	return _commit(battle.re_tie())


func submit_pass() -> Dictionary:
	if battle == null or battle.current_side() != "hero":
		return {"ok": false, "error": "not a hero turn"}
	return _commit(battle.pass_turn())


func submit_retreat() -> Dictionary:
	if battle == null or battle.current_side() != "hero" or battle.is_boss_encounter():
		return {"ok": false, "error": "retreat unavailable"}
	return _commit(battle.retreat())


func _commit(receipt: Dictionary) -> Dictionary:
	if not bool(receipt.get("ok", false)):
		return receipt
	_record(receipt)
	_selected_part = ""
	_drive_foes()
	_refresh()
	return receipt


func _drive_foes() -> void:
	if battle == null:
		return
	var iterations := 0
	while not battle.is_over() and battle.current_side() == "foe" and iterations < MAX_FOE_STEPS:
		iterations += 1
		var actor := battle.get_unit(battle.current_actor_id())
		var receipt: Dictionary = {}
		var choice := StitchedFoeIntent.choose(battle, actor)
		if not choice.is_empty() and not bool(choice["pass"]):
			receipt = battle.use_foe_ability(str(choice["ability_id"]), int(choice["target_rank"]))
		# A refusal is exceptional. Preserve the original rank-by-rank safe
		# fallback, including the ability rotation, without adding RNG or turns.
		if not bool(receipt.get("ok", false)) and not choice.is_empty() and not bool(choice["pass"]):
			var authored: Array = actor.get("abilities", [])
			var offset := (battle.round_number() - 1) % maxi(1, authored.size())
			for step in range(authored.size()):
				var ability: Dictionary = authored[(offset + step) % authored.size()]
				if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor["rank"])) or not battle._self_move_gate(actor, ability).is_empty():
					continue
				for rank in range(1, 5):
					if battle._legal_targets(actor, ability, rank).is_empty():
						continue
					receipt = battle.use_foe_ability(str(ability["id"]), rank)
					if bool(receipt.get("ok", false)):
						break
				if bool(receipt.get("ok", false)):
					break
		if not bool(receipt.get("ok", false)):
			receipt = battle.pass_turn()
		if not bool(receipt.get("ok", false)):
			break
		_record(receipt)


func _record(receipt: Dictionary) -> void:
	last_receipt = receipt.duplicate(true)
	receipts.append(last_receipt.duplicate(true))
	var actor_id := str(receipt.get("actor", ""))
	var action := str(receipt.get("action", ""))
	var log := "%s · %s" % [actor_id.replace("_", " ").capitalize(), action.replace("_", " ").capitalize()]
	if action == "ability":
		log += "\n" + str(receipt.get("ability", ""))
		for result in receipt.get("results", []):
			log += "\n→ " + str(result.get("target", "")) + "  " + str(result.get("damage", result.get("hit", "")))
	_notice = log + "\nRound %d · %s" % [battle.round_number(), battle.outcome().capitalize()]
	_inspected_seat = ""
	if reduced_motion:
		return
	var actor := battle.get_unit(actor_id)
	if not actor.is_empty():
		var actor_key := str(actor["side"]) + "_" + str(actor["rank"])
		if _puppets.has(actor_key):
			var puppet: Variant = _puppets[actor_key]
			if action == "ability":
				_apply_named_pose(puppet, actor_id, str(receipt.get("ability", "")), str(actor["side"]))
				puppet.trigger_attack(0.32)
	for result in receipt.get("results", []):
		var target := battle.get_unit(str(result.get("target", "")))
		if target.is_empty():
			continue
		var key := str(target["side"]) + "_" + str(target["rank"])
		if _puppets.has(key):
			_puppets[key].trigger_recoil(0.28)


func _apply_named_pose(puppet: Variant, id: String, ability_id: String, side: String) -> void:
	var actor := battle.get_unit(id)
	var move := "attack"
	if side == "hero":
		for part in actor.get("parts", {}).values():
			var item: Dictionary = parts.get(str(part["id"]), {})
			var ability: Dictionary = StitchedParts.ability_at_tier(item, int(part["tier"]))
			if str(ability.get("id", "")) == ability_id:
				move = str(ability.get("move", "attack"))
				break
	else:
		for ability in actor.get("abilities", []):
			if str(ability["id"]) == ability_id:
				move = str(ability.get("move", "attack"))
				break
	var group := "heroes" if side == "hero" else "enemies"
	var entry: Dictionary = _pose_manifest.get(group, {}).get(id, {}).get(move, {})
	var path := str(entry.get("art", ""))
	if path.begins_with("res://") and ResourceLoader.exists(path, "Texture2D"):
		puppet.attack_texture = load(path)
	else:
		var fallback := str(ROSTER.art_paths(id).get("attack", ""))
		puppet.attack_texture = load(fallback) if ResourceLoader.exists(fallback, "Texture2D") else null


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	for puppet in _puppets.values():
		if reduced_motion:
			puppet.cancel_attack()
			puppet.cancel_recoil()
			puppet.cancel_fall()
		puppet.set_process(not reduced_motion)
	if battle != null:
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _utilities_open:
			_set_utilities_open(false)
			get_viewport().set_input_as_handled()
			return
		_selected_part = ""
		_inspected_seat = ""
		_refresh()
		get_viewport().set_input_as_handled()
