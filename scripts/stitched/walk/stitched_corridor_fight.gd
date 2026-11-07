class_name StitchedCorridorFight
extends Control
## S11: a fight happens where the walk stopped, in the same 3D corridor and candle light.
## Presentation only. The classic StitchedBattleScreen stays mounted underneath as the
## engine (rules calls, foe turns, receipts, Continue); its busy chrome is tucked away and
## this view shows the simple outside: the party on the left, foes on the right, a name and
## health plate under each, the turn strip with the candle on top, and one bottom bar with
## the acting doll and its four body parts. Everything deeper stays inside the rules.

const SLOT_NAMES := {"head": "HEAD", "arms": "ARM", "torso": "TORSO", "legs": "LEG"}
const HOOP := preload("res://assets/paper/stitched/icons/portrait_frame.png")
const FELT := preload("res://assets/paper/ui/panel_felt.png")
const NAME_PLATE := preload("res://assets/paper/ui/hud_name_plate.png")
const BAR_FRAME := preload("res://assets/paper/ui/hud_bar_frame.png")
const FONT := preload("res://assets/fonts/PatrickHand-Regular.ttf")
const ICONS := "res://assets/paper/stitched/icons/"
const BONE := Color("f0ddc0")
const AMBER := Color("e4b76a")
const BLOOD := Color("b5423c")
const FRAY := Color("d7a560")
const HERO_HEIGHT := 1.15
const FOE_HEIGHT := 1.2
const BOSS_HEIGHT := 1.7
const HEAP_HEIGHT := 0.55
const BAR_TOP := 588.0
const LUNGE := 0.35
const BEAT_TIME := 0.32

var engine: StitchedBattleScreen
var battle: StitchedRules
var area := "floorboards"
var stage: StitchedCorridorStage
## Wren's authored hands, strings and fear jar live above the corridor, below hit targets.
var kid_view: StitchedKidView
var chrome: Control
var plates: Dictionary = {}
var hits: Dictionary = {}
var part_buttons: Dictionary = {}
var more_buttons: Dictionary = {}
## Wren's hand: four small hands at the bar's right end, the slots later gifts will fill.
var hand_buttons: Dictionary = {}
var more_panel: NinePatchRect
var more_grid: GridContainer
var more_button: Button
var continue_button: Button
var candle_icon: TextureRect
var ribbon: StitchedTurnOrderRibbon
var portrait: TextureRect
var actor_name: Label
var thread_knot: TextureRect
var health_bar: TextureProgressBar
var health_text: Label
var fray_bar: TextureProgressBar
var log_label: Label
var outcome_label: Label
var hovered := ""
## A local cursor only: engine.legal_targets() owns all legality and all commits.
var _keyboard_targets: Array[String] = []
var _keyboard_target := ""
var _keyboard_stamp := ""
var _signature := ""
var _seen_receipts := 0
var _textures: Dictionary = {}
var _beats: Tween
var _focus_actor_id := ""
var _focus_target_ids: Array[String] = []
## Left alone on a turn, a doll speaks over its head (S10 barks, fight lines).
var barks := StitchedWalkBarks.new()
var bark_label: Label
var bark_timer: Timer
var bark_count := 0
var last_bark: Dictionary = {}
var _bark_fade: Tween


## Mounts the corridor view over a ready battle screen and tucks the classic chrome away.
static func attach(screen: StitchedBattleScreen, area_name: String) -> StitchedCorridorFight:
	if screen == null or screen.battle == null or not screen.is_inside_tree():
		return null
	var fight := StitchedCorridorFight.new()
	fight.engine = screen
	fight.battle = screen.battle
	fight.area = area_name if StitchedCorridorStage.AREA_KEYS.has(area_name) else "floorboards"
	var tucked := Control.new()
	tucked.name = "ClassicChrome"
	tucked.visible = false
	tucked.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in screen.get_children():
		child.reparent(tucked, false)
	screen.add_child(tucked)
	tucked.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fight.chrome = tucked
	screen.add_child(fight)
	return fight


func _ready() -> void:
	name = "CorridorFight"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	stage = StitchedCorridorStage.new()
	add_child(stage)
	stage.build(area, 2)
	stage.fight_view(true)
	# Mount a fresh projection: the old battle screen's KidView belongs to hidden chrome.
	kid_view = StitchedKidView.new()
	add_child(kid_view)
	kid_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kid_view.meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Owner 11-08: no puppet hands or strings over the corridor fight; the fear jar stays.
	kid_view.get_node("KidHandsLayer").visible = false
	_build_plates()
	_build_top()
	_build_bar()
	_build_more()
	_build_bark()
	_seen_receipts = engine.receipts.size()
	refresh()


func _label(text: String, rect: Rect2, font_size: int, color: Color = BONE,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("1a1012"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _bar(rect: Rect2, tint: Color) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.texture_under = BAR_FRAME
	bar.texture_progress = BAR_FRAME
	bar.nine_patch_stretch = true
	bar.stretch_margin_left = 10
	bar.stretch_margin_right = 10
	bar.stretch_margin_top = 7
	bar.stretch_margin_bottom = 7
	bar.tint_under = Color("3a3034")
	bar.tint_progress = tint
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _felt(rect: Rect2, tint: Color = Color("2a2230f0")) -> NinePatchRect:
	var felt := NinePatchRect.new()
	felt.texture = FELT
	felt.patch_margin_left = 40
	felt.patch_margin_right = 40
	felt.patch_margin_top = 40
	felt.patch_margin_bottom = 40
	felt.position = rect.position
	felt.size = rect.size
	felt.self_modulate = tint
	felt.mouse_filter = Control.MOUSE_FILTER_STOP
	return felt


func _button(title: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 20)
	StitchedBattleScreen.CHROME.style_button(button)
	button.pressed.connect(callback)
	return button


## A name and health plate under every figure, and a see-through hit box over it.
func _build_plates() -> void:
	var empty := StyleBoxEmpty.new()
	for side in ["hero", "foe"]:
		for rank in range(1, 5):
			var key: String = side + "_" + str(rank)
			var plate := Control.new()
			plate.name = "Plate_" + key
			plate.size = Vector2(150, 44)
			plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var back := NinePatchRect.new()
			back.name = "Back"
			back.texture = NAME_PLATE
			back.patch_margin_left = 14
			back.patch_margin_right = 14
			back.patch_margin_top = 14
			back.patch_margin_bottom = 14
			back.size = plate.size
			back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			plate.add_child(back)
			var title := _label("", Rect2(8, 1, 134, 22), 16, BONE, HORIZONTAL_ALIGNMENT_CENTER)
			title.name = "Name"
			title.clip_text = true
			plate.add_child(title)
			var hp := _bar(Rect2(10, 24, 130, 14), BLOOD)
			hp.name = "Health"
			plate.add_child(hp)
			var numbers := _label("", Rect2(10, 21, 130, 18), 12, BONE, HORIZONTAL_ALIGNMENT_CENTER)
			numbers.name = "HealthText"
			plate.add_child(numbers)
			add_child(plate)
			plates[key] = plate
			var hit := Button.new()
			hit.name = "Hit_" + key
			hit.flat = true
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				hit.add_theme_stylebox_override(state, empty)
			hit.focus_mode = Control.FOCUS_NONE
			hit.mouse_entered.connect(func(): _hover(key, true))
			hit.mouse_exited.connect(func(): _hover(key, false))
			hit.pressed.connect(func(): click_figure(side, rank))
			add_child(hit)
			hits[key] = hit


## The turn strip under the candle: who acts, in order, at a glance.
func _build_top() -> void:
	candle_icon = TextureRect.new()
	candle_icon.name = "Candle"
	candle_icon.position = Vector2(608, 2)
	candle_icon.size = Vector2(64, 64)
	candle_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	candle_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	candle_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(candle_icon)
	ribbon = StitchedTurnOrderRibbon.new()
	ribbon.name = "TurnStrip"
	ribbon.position = Vector2(295, 66)
	ribbon.size = Vector2(690, 42)
	add_child(ribbon)
	log_label = _label("", Rect2(190, 540, 900, 44), 19, BONE, HORIZONTAL_ALIGNMENT_CENTER)
	log_label.name = "FightLine"
	add_child(log_label)
	outcome_label = _label("", Rect2(240, 250, 800, 90), 64, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	outcome_label.name = "Outcome"
	outcome_label.visible = false
	add_child(outcome_label)


## One bottom bar: the acting doll, its health and fray, and its four body parts.
func _build_bar() -> void:
	var bar := _felt(Rect2(16, BAR_TOP, 1248, 126))
	bar.name = "BottomBar"
	add_child(bar)
	portrait = TextureRect.new()
	portrait.name = "Portrait"
	portrait.position = Vector2(44, BAR_TOP + 20)
	portrait.size = Vector2(86, 86)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	var hoop := TextureRect.new()
	hoop.name = "PortraitHoop"
	hoop.texture = HOOP
	hoop.position = Vector2(30, BAR_TOP + 6)
	hoop.size = Vector2(114, 114)
	hoop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hoop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hoop)
	actor_name = _label("", Rect2(158, BAR_TOP + 10, 300, 32), 28, AMBER)
	actor_name.name = "ActorName"
	add_child(actor_name)
	# S13: a small thread knot by the name when two or more patches share a thread.
	thread_knot = TextureRect.new()
	thread_knot.name = "ThreadKnot"
	thread_knot.position = Vector2(426, BAR_TOP + 6)
	thread_knot.size = Vector2(40, 40)
	thread_knot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thread_knot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thread_knot.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(thread_knot)
	add_child(_label("HEALTH", Rect2(158, BAR_TOP + 48, 80, 24), 17))
	health_bar = _bar(Rect2(236, BAR_TOP + 50, 230, 22), BLOOD)
	health_bar.name = "ActorHealth"
	add_child(health_bar)
	health_text = _label("", Rect2(236, BAR_TOP + 47, 230, 26), 15, BONE, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(health_text)
	add_child(_label("FRAY", Rect2(158, BAR_TOP + 82, 80, 24), 17))
	fray_bar = _bar(Rect2(236, BAR_TOP + 84, 230, 22), FRAY)
	fray_bar.name = "ActorFray"
	fray_bar.max_value = 200
	add_child(fray_bar)
	for index in StitchedBattleScreen.SLOTS.size():
		var slot: String = StitchedBattleScreen.SLOTS[index]
		var button := TextureButton.new()
		button.name = "Part_" + slot
		button.texture_normal = HOOP
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.position = Vector2(500 + index * 122, BAR_TOP + 6)
		button.size = Vector2(114, 114)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(func(): choose_part(slot))
		button.mouse_entered.connect(func(): _shade_parts())
		button.mouse_exited.connect(func(): _shade_parts())
		button.focus_entered.connect(func(): _shade_parts())
		button.focus_exited.connect(func(): _shade_parts())
		# S13: the part shows as the cloth patch sewn on that limb; its border tells the tier.
		for layer in ["Patch", "Border", "Frayed"]:
			var art := TextureRect.new()
			art.name = layer
			art.position = Vector2(14, 14)
			art.size = Vector2(86, 86)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(art)
		var slot_label := _label(SLOT_NAMES[slot], Rect2(12, 26, 90, 30), 24, BONE, HORIZONTAL_ALIGNMENT_CENTER)
		slot_label.name = "Slot"
		button.add_child(slot_label)
		var move_label := _label("", Rect2(16, 54, 82, 36), 13, BONE, HORIZONTAL_ALIGNMENT_CENTER)
		move_label.name = "Move"
		move_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		move_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_child(move_label)
		add_child(button)
		part_buttons[slot] = button
	more_button = _button("More", Rect2(1012, BAR_TOP + 22, 108, 40), func(): set_more_open(not more_panel.visible))
	more_button.name = "More"
	add_child(more_button)
	continue_button = _button("Continue", Rect2(1012, BAR_TOP + 70, 230, 40), finish)
	continue_button.name = "Continue"
	add_child(continue_button)
	_build_hands()


func _build_hands() -> void:
	var slots := engine.hand_slots()
	for index in slots.size():
		var action_id: String = slots[index]
		var entry := StitchedWrenGifts.gift(action_id)
		var button := TextureButton.new()
		button.name = "Hand_" + action_id
		button.texture_normal = _texture(StitchedWrenGifts.icon_path(action_id))
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.position = Vector2(1132 + (index % 2) * 60, BAR_TOP + 8 + (index / 2) * 58)
		button.size = Vector2(56, 56)
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = "Wren: %s\n%s" % [str(entry.get("name", action_id.capitalize())), _plain(str(entry.get("text", "")))]
		button.pressed.connect(func(): choose_hand(action_id))
		for hover_signal in [button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited]:
			hover_signal.connect(func(): _shade_parts())
		add_child(button)
		hand_buttons[action_id] = button


## Drops a closing ": -8 fray." style clause so no hidden number shows on hover.
static func _plain(text: String) -> String:
	var cut := text.rfind(":")
	if cut > 0 and RegEx.create_from_string(r"\d").search(text.substr(cut)) != null:
		return text.substr(0, cut) + "."
	return text


## The rarely needed choices live behind More: stepping, passing and fleeing.
func _build_more() -> void:
	more_panel = _felt(Rect2(880, 312, 384, 270))
	more_panel.name = "MorePanel"
	more_panel.visible = false
	add_child(more_panel)
	more_grid = GridContainer.new()
	more_grid.columns = 2
	more_grid.position = Vector2(22, 22)
	more_grid.size = Vector2(340, 226)
	more_grid.add_theme_constant_override("h_separation", 8)
	more_grid.add_theme_constant_override("v_separation", 6)
	more_panel.add_child(more_grid)
	var actions := [
		["move_front", "Step front", func(): _act(engine.submit_move(-1))],
		["move_back", "Step back", func(): _act(engine.submit_move(1))],
		["pass", "Wait", func(): _act(engine.submit_pass())],
		["re_tie", "Re-tie thread", func(): _act(engine.submit_re_tie())],
		["retreat", "Flee", func(): _act(engine.submit_retreat())],
	]
	for entry in actions:
		add_more(entry[0], entry[1], entry[2])


## Adds one more choice to the More panel (the host adds Save run here).
func add_more(key: String, title: String, callback: Callable) -> Button:
	var button := _button(title, Rect2(0, 0, 166, 34), callback)
	button.name = "More_" + key
	button.custom_minimum_size = Vector2(166, 34)
	button.add_theme_font_size_override("font_size", 17)
	more_grid.add_child(button)
	more_buttons[key] = button
	return button


func set_more_open(open: bool) -> void:
	if open:
		_clear_keyboard_target()
	more_panel.visible = open
	if open and not more_buttons.is_empty():
		for key in more_buttons:
			if not more_buttons[key].disabled:
				more_buttons[key].grab_focus()
				break


func choose_hand(action_id: String) -> Dictionary:
	_clear_keyboard_target()
	return _act(engine.choose_hand_action(action_id))


func _act(receipt: Dictionary) -> Dictionary:
	if bool(receipt.get("ok", false)) and not str(receipt.get("pending", "")).is_empty():
		set_more_open(false)
	elif bool(receipt.get("ok", false)):
		set_more_open(false)
	elif receipt.has("error"):
		log_label.text = str(receipt.error).capitalize()
	refresh()
	return receipt


## Picks a body part; a part with a single possible target acts at once.
func choose_part(slot: String) -> Dictionary:
	_clear_keyboard_target()
	if engine._selected_part == slot:
		engine._selected_part = ""
		engine._refresh()
		refresh()
		return {"ok": true, "cleared": true}
	engine._hand_pending = ""
	if not engine.select_part(slot):
		return {"ok": false, "error": "part unavailable"}
	var targets := engine.legal_targets()
	if targets.size() == 1:
		var key: String = targets.keys()[0]
		return click_figure(key.get_slice("_", 0), int(key.get_slice("_", 1)))
	refresh()
	return {"ok": true, "pending": slot}


func click_figure(side: String, rank: int) -> Dictionary:
	if engine._selected_part.is_empty() and (engine._hand_pending.is_empty() or engine._hand_pending.begins_with("lift:")):
		log_label.text = "Pick a body part first."
		return {"ok": false, "error": "no part chosen"}
	return _act(engine.submit_target(side, rank))


func finish() -> void:
	if battle.is_over():
		engine.exit_requested.emit()


## All candidate keys come from the current engine projection; only a living unit
## or an actual targetable scrap heap is represented. No rules are recomputed here.
func _sync_keyboard_targets() -> bool:
	var pending := not engine._selected_part.is_empty() or (
		not engine._hand_pending.is_empty() and not engine._hand_pending.begins_with("lift:"))
	var keys: Array[String] = []
	if pending and not battle.is_over() and not more_panel.visible:
		var authorized := engine.legal_targets()
		for side in ["hero", "foe"]:
			for rank in range(1, 5):
				var key: String = side + "_" + str(rank)
				if not authorized.has(key):
					continue
				var unit := engine._unit_at(side, rank)
				if not unit.is_empty() and not bool(unit.get("dead", false)) and not bool(unit.get("lost", false)):
					keys.append(key)
				elif side == "foe" and not engine._heap_at(rank).is_empty():
					keys.append(key)
	var stamp := "%s|%s|%s|%s" % [
		battle.current_actor_id(), engine._selected_part, engine._hand_pending, ",".join(keys)] if pending and not battle.is_over() and not more_panel.visible else ""
	if _keyboard_stamp == stamp:
		return false
	_keyboard_stamp = stamp
	_keyboard_targets = keys
	_keyboard_target = ""
	return true


func _clear_keyboard_target() -> void:
	_keyboard_targets.clear()
	_keyboard_target = ""
	_keyboard_stamp = ""


## The existing FightLine is the only new instruction surface.
func _target_hint() -> void:
	if _keyboard_targets.is_empty() or more_panel.visible:
		return
	if _keyboard_target.is_empty():
		log_label.text = "Arrows choose a target · Enter / Space confirms."
		return
	var side := _keyboard_target.get_slice("_", 0)
	var rank := int(_keyboard_target.get_slice("_", 1))
	var unit := engine._unit_at(side, rank)
	var title := str(unit.get("name", "Scrap heap"))
	log_label.text = "%s R%d · %s · Arrows change · Enter / Space confirms." % [
		"Doll" if side == "hero" else "Foe", rank, title]


func _hover(key: String, inside: bool) -> void:
	hovered = key if inside else ("" if hovered == key else hovered)
	_shade_figures()


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
	return _textures[path]


func _figure_art(unit_id: String) -> Texture2D:
	return _texture(str(StitchedBattleScreen.ROSTER.art_paths(unit_id).get("idle", "")))


## Re-reads the battle and lays everything out again. Cheap; called whenever anything changes.
func refresh() -> void:
	if battle == null or not is_inside_tree():
		return
	_signature = _state_signature()
	var band := str(battle.candle_band().get("name", "dim"))
	stage.set_candle(band)
	candle_icon.texture = _texture(ICONS + "candle_" + band + ".png")
	candle_icon.tooltip_text = "The candle burns " + band + "."
	var entries: Array[Dictionary] = []
	for id in battle.turn_order():
		entries.append(battle.get_unit(str(id)))
	ribbon.show_order(entries, battle.current_actor_id(), battle.is_over())
	var boss := battle.is_boss_encounter()
	for side in ["hero", "foe"]:
		for rank in range(1, 5):
			var key: String = side + "_" + str(rank)
			var unit: Dictionary = engine._unit_at(side, rank)
			var standing := not unit.is_empty() and not bool(unit.get("dead", false)) and not bool(unit.get("lost", false))
			var heap: Dictionary = engine._heap_at(rank) if side == "foe" and not standing else {}
			var where := stage.fight_point(side, rank)
			if standing:
				var tall := HERO_HEIGHT if side == "hero" else (BOSS_HEIGHT if boss else FOE_HEIGHT)
				# Doll and foe art is all drawn facing right; foes turn round to face the party.
				stage.place(key, _figure_art(str(unit.id)), where, tall).flip_h = side == "foe"
			elif not heap.is_empty():
				stage.place(key, StitchedBattleScreen.SCRAP_TEXTURE, where, HEAP_HEIGHT).flip_h = false
			elif stage.figure_nodes.has(key):
				stage.figure_nodes[key].visible = false
			var plate: Control = plates[key]
			plate.visible = standing or not heap.is_empty()
			var title: Label = plate.get_node("Name")
			var hp: TextureProgressBar = plate.get_node("Health")
			var numbers: Label = plate.get_node("HealthText")
			if standing:
				title.text = str(unit.get("name", ""))
				hp.max_value = maxf(1.0, float(unit.get("max_hp", 1)))
				hp.value = float(unit.get("hp", 0))
				numbers.text = "%d/%d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 0))]
				if bool(unit.get("hanging", false)):
					numbers.text = "HANGING"
			elif not heap.is_empty():
				title.text = "Scrap heap"
				hp.max_value = maxf(1.0, float(heap.get("max_hp", heap.get("hp", 1))))
				hp.value = float(heap.get("hp", 0))
				numbers.text = str(int(heap.get("hp", 0)))
			hits[key].visible = plate.visible
			hits[key].tooltip_text = _simple_detail(engine.status_detail(side, rank)) if plate.visible else ""
	_sync_keyboard_targets()
	_refresh_bar()
	_shade_figures()
	_place_overlays()


func _refresh_bar() -> void:
	var acting := battle.get_unit(battle.current_actor_id())
	var hero_turn := battle.current_side() == "hero" and not battle.is_over()
	var shown: Dictionary = acting if hero_turn else {}
	actor_name.text = str(shown.get("name", ""))
	var art := _figure_art(str(shown.get("id", ""))) if not shown.is_empty() else null
	if art != null:
		var bust := AtlasTexture.new()
		bust.atlas = art
		var side := minf(art.get_width(), art.get_height() * 0.55)
		bust.region = Rect2((art.get_width() - side) / 2.0, 0, side, side)
		portrait.texture = bust
	else:
		portrait.texture = null
	health_bar.max_value = maxf(1.0, float(shown.get("max_hp", 1)))
	health_bar.value = float(shown.get("hp", 0))
	health_text.text = "%d / %d" % [int(shown.get("hp", 0)), int(shown.get("max_hp", 0))] if not shown.is_empty() else ""
	fray_bar.value = float(shown.get("fray", 0))
	var worn_parts: Dictionary = shown.get("parts", {})
	var knot := StitchedSewnPatches.set_thread(worn_parts) if hero_turn else ""
	thread_knot.texture = _texture(StitchedSewnPatches.knot_path(knot)) if not knot.is_empty() else null
	thread_knot.visible = not knot.is_empty()
	thread_knot.tooltip_text = ("Whole cloth: every patch is sewn with one thread." if StitchedSewnPatches.whole_cloth(worn_parts)
		else "Matching thread: some of these patches sit well together.") if not knot.is_empty() else ""
	fray_bar.tint_progress = BLOOD if int(shown.get("fray", 0)) >= 100 else FRAY
	for slot in part_buttons:
		var button: TextureButton = part_buttons[slot]
		var equipped: Dictionary = shown.get("parts", {}).get(slot, {})
		var part: Dictionary = engine.parts.get(str(equipped.get("id", "")), {})
		var move_label: Label = button.get_node("Move")
		move_label.text = ""
		var torn := bool(equipped.get("torn", false))
		var patch: TextureRect = button.get_node("Patch")
		patch.texture = _texture(StitchedSewnPatches.icon_path(str(part.get("id", "")), slot)) if not part.is_empty() else null
		patch.modulate = Color(0.5, 0.47, 0.47, 0.8) if torn else Color.WHITE
		(button.get_node("Border") as TextureRect).texture = _texture(
			StitchedSewnPatches.border_path(int(equipped.get("tier", 1)))) if not part.is_empty() and not torn else null
		(button.get_node("Frayed") as TextureRect).texture = _texture(StitchedSewnPatches.ART + "frayed.png") if torn else null
		# With a patch picture the slot word steps aside and the move name sits along the hem.
		var pictured := patch.texture != null
		(button.get_node("Slot") as Label).visible = not pictured
		move_label.position = Vector2(8, 80) if pictured else Vector2(16, 54)
		move_label.size = Vector2(98, 30) if pictured else Vector2(82, 36)
		if not part.is_empty():
			move_label.text = str(StitchedParts.ability_at_tier(part, int(equipped.get("tier", 1))).get("name", ""))
			if torn:
				move_label.text = "torn"
		button.disabled = not hero_turn or not engine._valid_part(shown, equipped)
		button.tooltip_text = str(engine._part_cues.get(slot, {}).get("full", "")) if hero_turn else ""
	_shade_parts()
	var cut := hero_turn and battle.thread_cuts().has(str(shown.get("id", "")))
	var hand_open := battle.hand_action_open() and not battle.is_over()
	var lifting := engine._hand_pending.begins_with("lift:")
	var lift_id := str(engine._unit_at("hero", int(engine._hand_pending.get_slice(":", 1))).get("id", "")) if lifting else ""
	# Even in Lift's More tray, only the rules-authorized direction is live.
	more_buttons.move_front.disabled = not (battle.hand_action_check("lift", lift_id, -1).is_empty() if lifting
		else hero_turn and engine._can_move(-1))
	more_buttons.move_back.disabled = not (battle.hand_action_check("lift", lift_id, 1).is_empty() if lifting
		else hero_turn and engine._can_move(1))
	more_buttons.pass.disabled = not hero_turn
	more_buttons.re_tie.disabled = not cut
	more_buttons.retreat.disabled = not hero_turn or battle.is_boss_encounter()
	for action_id in hand_buttons:
		hand_buttons[action_id].disabled = not hand_open or battle.gift_spent(action_id)
		hand_buttons[action_id].visible = not battle.is_over()
	more_button.disabled = battle.is_over()
	if battle.is_over():
		set_more_open(false)
	continue_button.visible = battle.is_over()
	outcome_label.visible = battle.is_over()
	outcome_label.text = battle.outcome().to_upper()
	for slot in part_buttons:
		part_buttons[slot].visible = not battle.is_over()
	var lines := engine._notice.split("\n", false)
	var shown_lines := PackedStringArray()
	for line in lines:
		if not line.begins_with("Round "):
			shown_lines.append(line.replace("→ ", ""))
	if not engine._hand_pending.is_empty():
		var at_foe := StitchedBattleScreen.hand_target_side(engine._hand_pending.get_slice(":", 0)) == "foe"
		log_label.text = "Wren reaches out: pick one of the foes." if at_foe else "Wren reaches out: pick one of the dolls."
	elif not engine._selected_part.is_empty():
		log_label.text = "Pick a target."
	else:
		log_label.text = "  ·  ".join(shown_lines.slice(maxi(0, shown_lines.size() - 3)))
	_target_hint()


func _shade_parts() -> void:
	for slot in part_buttons:
		var button: TextureButton = part_buttons[slot]
		var tone := Color.WHITE
		if button.disabled:
			tone = Color(0.45, 0.42, 0.42, 0.85)
		elif slot == engine._selected_part:
			tone = Color(1.35, 1.12, 0.75)
		elif button.is_hovered() or button.has_focus():
			tone = Color(1.18, 1.08, 0.95)
		button.modulate = tone
	for action_id in hand_buttons:
		var hand: TextureButton = hand_buttons[action_id]
		var tone := Color.WHITE
		if hand.disabled:
			tone = Color(0.45, 0.42, 0.42, 0.85)
		elif engine._hand_pending.get_slice(":", 0) == action_id:
			tone = Color(1.35, 1.12, 0.75)
		elif hand.is_hovered() or hand.has_focus():
			tone = Color(1.18, 1.08, 0.95)
		hand.modulate = tone


## Lit figures are the ones that matter now: the actor, legal targets, the hovered one.
func _shade_figures() -> void:
	var targets := engine.legal_targets()
	var choosing := not targets.is_empty()
	var acting := battle.get_unit(battle.current_actor_id())
	var actor_key := str(acting.get("side", "")) + "_" + str(acting.get("rank", 0)) if not battle.is_over() else ""
	for key in plates:
		var tone := Color.WHITE
		if choosing:
			tone = Color(1.25, 1.12, 0.95) if targets.has(key) else Color(0.5, 0.48, 0.5)
		if key == hovered and (not choosing or targets.has(key)):
			tone = Color(1.4, 1.25, 1.0)
		if key == _keyboard_target and targets.has(key):
			tone = Color(1.75, 1.45, 0.85)
		if stage.figure_nodes.has(key):
			stage.figure_nodes[key].modulate = tone
		var back: NinePatchRect = plates[key].get_node("Back")
		back.self_modulate = Color(1.8, 1.45, 0.75) if key == _keyboard_target and targets.has(key) else (Color(1.5, 1.2, 0.7) if key == actor_key else (Color(1.2, 1.1, 0.9) if targets.has(key) else Color.WHITE))
		var title: Label = plates[key].get_node("Name")
		title.add_theme_color_override("font_color", AMBER if key == actor_key or targets.has(key) else BONE)


## Plates sit under each figure's feet and hit boxes cover the figure; both follow lunges.
func _place_overlays() -> void:
	for key in plates:
		var plate: Control = plates[key]
		var feet: Variant = stage.screen_point(key)
		if feet == null or not plate.visible:
			hits[key].visible = false
			continue
		var spot: Vector2 = feet
		plate.position = Vector2(spot.x - plate.size.x / 2.0, minf(spot.y + 2.0, BAR_TOP - 92.0))
		var rect := stage.screen_rect(key)
		hits[key].position = rect.position
		hits[key].size = rect.size
		hits[key].visible = rect.size.x > 0.0
	_refresh_wren()


## Read the stage's *current* 3D projection, not the hidden classic 2D hit boxes.
## This hook also runs while a lunge moves the figures and when session fear changes
## without a combat receipt. It does not issue any rule command or draw any new art.
func _refresh_wren() -> void:
	if kid_view == null or battle == null or engine == null:
		return
	var heroes := battle.get_heroes()
	var tops: Dictionary = {}
	for hero in heroes:
		if bool(hero.get("lost", false)):
			continue
		var rank := int(hero.get("rank", 0))
		if rank < 1 or rank > 4:
			continue
		var rect := stage.screen_rect("hero_%d" % rank)
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			tops[rank] = Vector2(rect.get_center().x, rect.position.y)
	kid_view.show_state(engine.kid_fear(), heroes, tops, battle.thread_cuts(),
		engine._motion_is_reduced())


func _build_bark() -> void:
	bark_label = _label("", Rect2(0, 0, 380, 60), 21, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	bark_label.name = "DollBark"
	bark_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bark_label.hide()
	add_child(bark_label)
	bark_timer = Timer.new()
	bark_timer.one_shot = true
	bark_timer.timeout.connect(_on_bark_timer)
	add_child(bark_timer)
	_arm_barks(float(barks.data.get("idle_delay", 9.0)))


## Waiting on the player's turn is the only time the dolls fill the silence.
func _arm_barks(delay: float) -> void:
	if bark_timer == null or not bark_timer.is_inside_tree():
		return
	if battle == null or battle.is_over() or battle.current_side() != "hero":
		bark_timer.stop()
		return
	bark_timer.start(delay)


func _on_bark_timer() -> void:
	bark()
	_arm_barks(float(barks.data.get("repeat_delay", 13.0)))


## One standing doll says a line chosen from how the fight is going. Returns the pick.
func bark() -> Dictionary:
	if battle == null or battle.is_over():
		return {}
	var said := barks.pick_fight(battle, bark_count, str(last_bark.get("line", "")))
	if said.is_empty():
		return said
	bark_count += 1
	last_bark = said
	bark_label.text = "\"%s\"" % said.line
	var rect := stage.screen_rect("hero_" + str(said.rank))
	var head := Vector2(rect.get_center().x, rect.position.y) if rect.size.x > 0.0 else Vector2(320, 200)
	bark_label.position = Vector2(clampf(head.x - bark_label.size.x / 2.0, 8.0, 1272.0 - bark_label.size.x),
		maxf(132.0, head.y - bark_label.size.y - 4.0))
	bark_label.show()
	if _bark_fade != null:
		_bark_fade.kill()
	var hold := float(barks.data.get("show_time", 4.5))
	_bark_fade = create_tween()
	if engine._motion_is_reduced():
		bark_label.modulate.a = 1.0
		_bark_fade.tween_interval(hold)
	else:
		bark_label.modulate.a = 0.0
		_bark_fade.tween_property(bark_label, "modulate:a", 1.0, 0.4)
		_bark_fade.tween_interval(hold)
		_bark_fade.tween_property(bark_label, "modulate:a", 0.0, 0.8)
	_bark_fade.tween_callback(bark_label.hide)
	return said


## The player is back: the doll stops mid-sentence and the wait starts over.
func hush() -> void:
	if _bark_fade != null:
		_bark_fade.kill()
		_bark_fade = null
	if bark_label != null:
		bark_label.hide()
	_arm_barks(float(barks.data.get("idle_delay", 9.0)))


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		hush()
	if not event is InputEventKey or not event.pressed or event.echo or battle == null or battle.is_over():
		return
	if not event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return
	# Only pending rank targeting owns these keys. Native controls (including Lift's
	# directional More actions and the finished Continue) retain their own input.
	if more_panel.visible or (engine._selected_part.is_empty() and
			(engine._hand_pending.is_empty() or engine._hand_pending.begins_with("lift:"))):
		return
	_sync_keyboard_targets()
	if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		if not _keyboard_targets.is_empty():
			var direction := -1 if event.keycode in [KEY_LEFT, KEY_UP] else 1
			var index := _keyboard_targets.find(_keyboard_target)
			if index < 0:
				index = 0 if direction > 0 else _keyboard_targets.size() - 1
			else:
				index = posmod(index + direction, _keyboard_targets.size())
			_keyboard_target = _keyboard_targets[index]
			_shade_figures()
			_target_hint()
	else:
		# Re-read the live authority immediately before committing. A changed actor,
		# vanished rank or revised legal set never spends a turn, hand or RNG.
		_sync_keyboard_targets()
		if not _keyboard_target.is_empty() and _keyboard_targets.has(_keyboard_target) \
				and engine.legal_targets().has(_keyboard_target):
			var chosen := _keyboard_target
			click_figure(chosen.get_slice("_", 0), int(chosen.get_slice("_", 1)))
	get_viewport().set_input_as_handled()


func _state_signature() -> String:
	return "%d|%s|%s|%s|%s|%d" % [engine.receipts.size(), engine._selected_part, engine._hand_pending,
		battle.current_actor_id(), battle.outcome(), battle.candle()]


func _process(_delta: float) -> void:
	if battle == null or engine == null:
		return
	# Toggles, a dying actor and the end of combat may interrupt an active shot.
	# The camera and figures must not keep an old pose into the next turn.
	if engine._motion_is_reduced() or battle.is_over():
		if (_beats != null and _beats.is_running()) or stage.fight_focus_active():
			_cancel_beats()
	elif stage.fight_focus_active():
		var actor_present := not _live_receipt_key(_focus_actor_id).is_empty()
		var targets_present := false
		for id in _focus_target_ids:
			if not _live_receipt_key(id).is_empty():
				targets_present = true
				break
		if not actor_present or not targets_present:
			stage.cancel_fight_focus()
	if engine.receipts.size() != _seen_receipts:
		refresh()
		_play_new_receipts()
		_arm_barks(float(barks.data.get("idle_delay", 9.0)))
	elif _state_signature() != _signature:
		refresh()
		_arm_barks(float(barks.data.get("idle_delay", 9.0)))
	elif _sync_keyboard_targets():
		_shade_figures()
		_target_hint()
	_place_overlays()


## Each new action gets a short beat: the actor lunges toward the other side, its targets flinch.
## The classic hover detail, minus the hidden-mechanic numbers (fray stays a bar, never a count).
static func _simple_detail(detail: String) -> String:
	var plain := RegEx.create_from_string(r"\s*·?\s*FRAY\s*\d+\s*/\s*\d+").sub(detail, "", true)
	return plain.replace("STATUS: none", "").strip_edges()


## A key is valid only when the receipt's real unit still occupies that rank.
## A heap or a later replacement at the same rank is NOT the struck unit.
func _live_receipt_key(unit_id: String) -> String:
	var unit := battle.get_unit(unit_id)
	if unit.is_empty() or bool(unit.get("dead", false)) or bool(unit.get("lost", false)):
		return ""
	var side := str(unit.get("side", ""))
	var rank := int(unit.get("rank", 0))
	if not side in ["hero", "foe"] or rank < 1 or rank > 4:
		return ""
	if str(engine._unit_at(side, rank).get("id", "")) != unit_id:
		return ""
	var key := "%s_%d" % [side, rank]
	var figure: Sprite3D = stage.figure_nodes.get(key)
	return key if figure != null and figure.visible and figure.texture != null else ""


## Called by the genuine receipt tween, never by selection, hover or refresh.
func _begin_receipt_focus(receipt: Dictionary) -> void:
	_focus_actor_id = ""
	_focus_target_ids.clear()
	if engine._motion_is_reduced() or battle.is_over() or not engine._damage_capable_receipt(receipt):
		return
	var actor_id := str(receipt.get("actor", ""))
	var attacker_key := _live_receipt_key(actor_id)
	if attacker_key.is_empty():
		return
	var keys: Array[String] = [attacker_key]
	for result in receipt.get("results", []):
		var target_id := str(result.get("target", ""))
		var target_key := _live_receipt_key(target_id)
		if not target_key.is_empty() and target_key != attacker_key and not keys.has(target_key):
			keys.append(target_key)
			_focus_target_ids.append(target_id)
	if keys.size() < 2:
		return
	if stage.start_fight_focus(keys, BEAT_TIME + 0.08):
		_focus_actor_id = actor_id


func _cancel_beats() -> void:
	if _beats != null:
		_beats.kill()
		_beats = null
	stage.cancel_fight_focus()
	_focus_actor_id = ""
	_focus_target_ids.clear()
	if is_inside_tree():
		refresh()


func _exit_tree() -> void:
	if _beats != null:
		_beats.kill()
		_beats = null
	if stage != null:
		stage.cancel_fight_focus()


## The same authored move-pose lookup as the retained battle driver.
## A pose changes only a Sprite3D texture; the projected silhouette stays at
## the figure's existing height and the original idle art returns at beat end.
func _receipt_pose_texture(actor_id: String, ability_id: String) -> Texture2D:
	var actor := battle.get_unit(actor_id)
	if actor.is_empty():
		return null
	var move := "attack"
	var side := str(actor.get("side", ""))
	if side == "hero":
		for worn in actor.get("parts", {}).values():
			var definition: Dictionary = engine.parts.get(str(worn.get("id", "")), {})
			if definition.is_empty():
				continue
			var ability := StitchedParts.ability_at_tier(definition, int(worn.get("tier", 1)))
			if str(ability.get("id", "")) == ability_id:
				move = str(ability.get("move", "attack"))
				break
	else:
		for ability in actor.get("abilities", []):
			if str(ability.get("id", "")) == ability_id:
				move = str(ability.get("move", "attack"))
				break
	var group := "heroes" if side == "hero" else "enemies"
	var authored: Dictionary = engine._pose_manifest.get(group, {}).get(actor_id, {}).get(move, {})
	var art_path := str(authored.get("art", ""))
	if not art_path.is_empty():
		var texture := _texture(art_path)
		if texture != null:
			return texture
	return _texture(str(StitchedBattleScreen.ROSTER.art_paths(actor_id).get("attack", "")))


func _set_receipt_pose(actor_id: String, ability_id: String, attack_pose: bool) -> void:
	var key := _live_receipt_key(actor_id)
	if key.is_empty():
		return
	var figure: Sprite3D = stage.figure_nodes[key]
	var texture := _receipt_pose_texture(actor_id, ability_id) if attack_pose else _figure_art(actor_id)
	if texture == null or figure.texture == null:
		return
	var height := figure.pixel_size * float(figure.texture.get_height())
	figure.texture = texture
	figure.pixel_size = height / float(texture.get_height())


func _play_new_receipts() -> void:
	var fresh := engine.receipts.slice(_seen_receipts)
	_seen_receipts = engine.receipts.size()
	if engine._motion_is_reduced() or battle.is_over():
		_cancel_beats()
		return
	if fresh.is_empty():
		return
	if _beats != null or stage.fight_focus_active():
		_cancel_beats()
	_beats = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	for receipt in fresh:
		if str(receipt.get("action", "")) != "ability" or not bool(receipt.get("ok", false)):
			continue
		var actor_id := str(receipt.get("actor", ""))
		var key := _live_receipt_key(actor_id)
		if key.is_empty():
			continue
		var actor := battle.get_unit(actor_id)
		var figure: Sprite3D = stage.figure_nodes[key]
		var home := figure.position
		var toward := -1.0 if str(actor.side) == "hero" else 1.0
		_beats.tween_callback(Callable(self, "_begin_receipt_focus").bind(receipt.duplicate(true)))
		_beats.tween_callback(Callable(self, "_set_receipt_pose").bind(actor_id, str(receipt.get("ability", "")), true))
		_beats.tween_property(figure, "position:z", home.z + toward * LUNGE, BEAT_TIME * 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		for result in receipt.get("results", []):
			var target_key := _live_receipt_key(str(result.get("target", "")))
			var struck: Sprite3D = stage.figure_nodes.get(target_key)
			if struck != null and struck != figure and bool(result.get("hit", true)):
				_beats.parallel().tween_property(struck, "modulate", Color(1.8, 0.55, 0.5), BEAT_TIME * 0.3)
		_beats.tween_property(figure, "position:z", home.z, BEAT_TIME * 0.6).set_trans(Tween.TRANS_SINE)
		_beats.tween_interval(0.08)
		_beats.tween_callback(Callable(self, "_set_receipt_pose").bind(actor_id, str(receipt.get("ability", "")), false))
	_beats.tween_callback(_shade_figures)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var slots := {KEY_1: "head", KEY_2: "arms", KEY_3: "torso", KEY_4: "legs"}
	var hand_keys := [KEY_Q, KEY_W, KEY_E, KEY_R]
	var carried := engine.hand_slots()
	if slots.has(event.keycode):
		choose_part(slots[event.keycode])
	elif event.keycode in hand_keys and hand_keys.find(event.keycode) < carried.size():
		var gift_id: String = carried[hand_keys.find(event.keycode)]
		if hand_buttons.has(gift_id) and not hand_buttons[gift_id].disabled:
			choose_hand(gift_id)
	elif event.keycode == KEY_ESCAPE:
		_clear_keyboard_target()
		if more_panel.visible:
			set_more_open(false)
		else:
			engine._selected_part = ""
			engine._hand_pending = ""
			engine._refresh()
			refresh()
	elif event.keycode == KEY_M:
		set_more_open(not more_panel.visible)
	elif event.keycode in [KEY_ENTER, KEY_SPACE] and battle.is_over():
		finish()
	else:
		return
	get_viewport().set_input_as_handled()
