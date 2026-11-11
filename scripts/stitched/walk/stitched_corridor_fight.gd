class_name StitchedCorridorFight
extends Control
## S11: a fight happens where the walk stopped, in the same 3D corridor and candle light.
## Presentation only. The classic StitchedBattleScreen stays mounted underneath as the
## engine (rules calls, foe turns, receipts, Continue); its busy chrome is tucked away and
## this view shows the simple outside: the party on the left, foes on the right, a name and
## health plate under each, the turn strip with the candle on top, and one bottom bar with
## the acting doll and its four body parts. Everything deeper stays inside the rules.

const SLOT_NAMES := {"head": "HEAD", "arms": "ARM", "torso": "TORSO", "legs": "LEG"}
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
## Owner 11-10: slow, heavy fights. The strike lands quickly, then the attacker holds its
## pose and the struck hold their reaction for a readable beat before easing back to idle.
const HOLD_TIME := 1.35
## Owner 11-10 spotlight step: on a strike the acting figure and its targets step toward the
## eye and each other and grow a touch, so the pair reads as the foreground of the held beat.
const SPOT_STEP := 0.28
const SPOT_GROW := 1.1
## Owner 11-10: a striking pair never closes to less than this along the ranks, or the
## grown front-rank strike pose covers the very target it strikes (Mistral 11-10).
const SPOT_MIN_GAP := 0.62
## Owner 11-09: no hoop behind a round, only a thin outline; a sewn patch's tier shows as
## the outline's colour: plain bone, silver thread, gold thread.
const TIER_OUTLINE := {1: Color("c9b79a"), 2: Color("cfd6ff"), 3: Color("ffcf6e")}
const ICON := 92.0
## Owner 11-09: an S14 ability's own round picture, and the small cloth badge of each patch sewn onto it.
const ABILITY_ART := "res://assets/paper/stitched/abilities/"
const SEWN_ART := "res://assets/paper/stitched/ability_patches/"
const SEWN := 34.0
const PORTRAIT := 100.0
## These painted foe stills already look left toward the dolls. Mirroring them like
## the other foe stills makes their faces, jaws or weapons point away from battle.
const FOES_DRAWN_LEFT := ["thimble_beetle", "thread_biter", "clothespin_crusher", "crochet_hook_harrier"]

## Job 7: a foe painted nearly face-on cannot be turned side-on by mirroring. When its artist has
## drawn "<still>_side.png" (a left-facing still with its own idle strip) the fight shows that
## picture, unmirrored; until then the old still is used.
static func side_art_path(unit_id: String) -> String:
	var still := str(StitchedBattleScreen.ROSTER.art_paths(unit_id).get("idle", ""))
	if still.is_empty() or still.contains("/heroes/"):
		return ""
	return still.get_basename() + "_side.png"


static func has_side_art(unit_id: String) -> bool:
	var path := side_art_path(unit_id)
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return false
	# A side still without an idle loop would freeze the figure; keep the old still instead.
	var base := path.get_basename()
	return ResourceLoader.exists(base + "_idle.png") or ResourceLoader.exists(base + "_idle24_0.png")


static func battle_flip(side: String, unit_id: String) -> bool:
	return side == "foe" and not unit_id in FOES_DRAWN_LEFT and not has_side_art(unit_id)


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
var health_word: Label
var fray_bar: TextureProgressBar
var fray_word: Label
var log_label: Label
var outcome_label: Label
## Owner 11-09: a move's name shows only while it is used; each unit's hover lists its moveset.
var move_banner: Label
var hovered := ""
## Owner combat job 3: the hover card beside a hero ability button, with the real numbers.
var ability_card: NinePatchRect
var ability_card_title: Label
var ability_card_body: Label
var ability_card_slot := ""
const CARD_W := 348.0
## A local cursor only: engine.legal_targets() owns all legality and all commits.
var _keyboard_targets: Array[String] = []
var _keyboard_target := ""
var _keyboard_stamp := ""
var _signature := ""
var _seen_receipts := 0
var _textures: Dictionary = {}
var _beats: Tween
## An invisible mouse shield keeps the next doll from acting during the held beat.
## It intercepts physical clicks, not the public methods used by deterministic tests.
var _beat_input_shield: Control
## Receipts that arrive while a held beat is still playing; they play after it, never over it.
var _queued_receipts: Array = []
## Thrown things and hit effects in flight (picture sprites); gone when their beat ends or is cut short.
var _flying: Array[Sprite3D] = []
## Job 6: held receipt reactions are picture swaps, not new puppet art. The live
## rules/receipts decide the kind; absent pictures use an unmistakable recoil.
var _reaction_kinds: Dictionary = {}
var _reaction_units: Dictionary = {}
var _reaction_shakes: Array[Tween] = []
var _miss_labels: Dictionary = {}
## Job 9: painted-icon and ink-letter outcome cues on the *actual* receipt targets.
var _float_groups: Dictionary = {}
var _float_tweens: Array[Tween] = []
var _beat_homes: Dictionary = {}
var _focus_actor_id := ""
var _focus_target_ids: Array[String] = []
## The rules may advance before the held pose ends; keep the bar and NOW cue on its actor.
var _held_actor_id := ""
var _held_actor_index := -1
## A boss may animate twice in one rolled round, including across separate receipt batches.
var _beat_order_round := -1
var _beat_order_appearances: Dictionary = {}
## Left alone on a turn, a doll speaks over its head (S10 barks, fight lines).
var barks := StitchedWalkBarks.new()
var bark_label: Label
var bark_timer: Timer
var bark_count := 0
var last_bark: Dictionary = {}
var _bark_fade: Tween
## Owner combat job 5: the corner map of the corridor routes, which a hovered foe's
## full details replace during a fight (see _hover and _update_corner_foe).
var corner_map: StitchedCornerMap
var fight_kind := ""
var _foe_hover_lit := ""
var _foe_hover_grow: Tween


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
	_build_ability_card()
	_build_corner_map()
	# Last child wins hit-testing, but draws nothing over the animation.
	_beat_input_shield = Control.new()
	_beat_input_shield.name = "BeatInputShield"
	_beat_input_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_beat_input_shield)
	_beat_input_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_beat_input_shield.hide()
	_seen_receipts = engine.receipts.size()
	refresh()


static var _round_shader: Shader
static var _rounds := {}

## A material that cuts a picture to a circle side wide with a thin outline round its edge.
## The circle is measured on the drawn rect, not the UVs, so cropped and atlas pictures stay
## round. A clear outline only cuts. One material is shared per side and colour.
static func round_material(side: float, outline: Color = TIER_OUTLINE[1]) -> ShaderMaterial:
	var key := "%d|%s" % [roundi(side), outline.to_html()]
	if _rounds.has(key):
		return _rounds[key]
	if _round_shader == null:
		_round_shader = Shader.new()
		_round_shader.code = """shader_type canvas_item;
uniform float side = 92.0;
uniform vec4 outline : source_color = vec4(0.79, 0.72, 0.6, 1.0);
uniform float width = 2.5;
varying vec2 spot;
varying vec4 tint;
void vertex() {
	spot = VERTEX;
	tint = COLOR;
}
void fragment() {
	// COLOR already holds the picture times its tint here.
	float radius = side * 0.5;
	float away = distance(spot, vec2(radius));
	float ring = smoothstep(radius - width - 1.0, radius - width, away) * outline.a;
	vec4 shown = mix(COLOR, vec4(outline.rgb, 1.0) * tint, ring);
	shown.a *= 1.0 - smoothstep(radius - 1.0, radius, away);
	COLOR = shown;
}"""
	var material := ShaderMaterial.new()
	material.shader = _round_shader
	material.set_shader_parameter("side", side)
	material.set_shader_parameter("outline", outline)
	_rounds[key] = material
	return material


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
			# Owner combat job 1: the authored red/green felt marker follows the health plate.
			# Until its dedicated art arrives, reuse the existing bar-frame picture.
			var marker := TextureRect.new()
			marker.name = "TargetMarker"
			marker.position = Vector2(2, 18)
			marker.size = Vector2(146, 26)
			marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			marker.stretch_mode = TextureRect.STRETCH_SCALE
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marker.visible = false
			plate.add_child(marker)
			# Job 2: the strip above HP belongs to status emblems, never the unit name.
			# Keep the hidden name for scripted inspection until the information corner lands.
			var title := _label("", Rect2(8, 1, 134, 22), 16, BONE, HORIZONTAL_ALIGNMENT_CENTER)
			title.name = "Name"
			title.clip_text = true
			title.hide()
			plate.add_child(title)
			var statuses := Control.new()
			statuses.name = "StatusRow"
			statuses.position = Vector2(10, 2)
			statuses.size = Vector2(133, 19)
			statuses.mouse_filter = Control.MOUSE_FILTER_IGNORE
			plate.add_child(statuses)
			for index in range(7):
				var chip := TextureRect.new()
				chip.name = "Status%d" % index
				chip.position = Vector2(index * 19, 0)
				chip.size = Vector2(18, 18)
				chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				chip.visible = false
				statuses.add_child(chip)
				var short := _label("", Rect2(0, 1, 18, 16), 10, BONE, HORIZONTAL_ALIGNMENT_CENTER)
				short.name = "Short"
				chip.add_child(short)
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


## Reuse the canonical combat badge order and authored status pictures on each HP plate.
## Missing status art stays readable on existing felt, never a code-drawn symbol.
func _present_plate_statuses(plate: Control, unit: Dictionary, side: String) -> void:
	var row: Control = plate.get_node("StatusRow")
	var entries := StitchedBattleChrome._badge_entries(unit, side)
	row.visible = not entries.is_empty()
	for index in range(7):
		var chip: TextureRect = row.get_node("Status%d" % index)
		chip.visible = index < mini(7, entries.size())
		if not chip.visible:
			chip.tooltip_text = ""
			continue
		var entry: Dictionary = entries[index]
		if entries.size() > 7 and index == 6:
			entry = {"id": "overflow", "short": "+", "full": "%d more statuses" % (entries.size() - 6), "icon": ""}
		var icon_id := str(entry.get("icon", ""))
		if icon_id.is_empty() and str(entry.get("id", "")) != "overflow":
			icon_id = "status_" + str(entry.get("id", ""))
		var pictured := _texture(ICONS + icon_id + ".png") if not icon_id.is_empty() else null
		chip.texture = pictured if pictured != null else NAME_PLATE
		chip.modulate = Color.WHITE if pictured != null else Color("bba19a")
		(chip.get_node("Short") as Label).text = "" if pictured != null else str(entry.get("short", ""))
		chip.tooltip_text = str(entry.get("full", ""))


## The turn strip under the candle: who acts, in order, at a glance.
func _build_top() -> void:
	candle_icon = TextureRect.new()
	candle_icon.name = "Candle"
	candle_icon.position = Vector2(608, 2)
	candle_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	candle_icon.size = Vector2(64, 64)
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
	move_banner = _label("", Rect2(240, 124, 800, 56), 36, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	move_banner.name = "MoveName"
	move_banner.visible = false
	add_child(move_banner)
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
	portrait.position = Vector2(37, BAR_TOP + 13)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.size = Vector2(PORTRAIT, PORTRAIT)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.material = round_material(PORTRAIT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	actor_name = _label("", Rect2(158, BAR_TOP + 10, 300, 32), 28, AMBER)
	actor_name.name = "ActorName"
	add_child(actor_name)
	# S13: a small thread knot by the name when two or more patches share a thread.
	thread_knot = TextureRect.new()
	thread_knot.name = "ThreadKnot"
	thread_knot.position = Vector2(426, BAR_TOP + 6)
	thread_knot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thread_knot.size = Vector2(40, 40)
	thread_knot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thread_knot.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(thread_knot)
	health_word = _label("HEALTH", Rect2(158, BAR_TOP + 48, 80, 24), 17)
	health_word.name = "HealthWord"
	add_child(health_word)
	health_bar = _bar(Rect2(236, BAR_TOP + 50, 230, 22), BLOOD)
	health_bar.name = "ActorHealth"
	add_child(health_bar)
	health_text = _label("", Rect2(236, BAR_TOP + 47, 230, 26), 15, BONE, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(health_text)
	fray_word = _label("FRAY", Rect2(158, BAR_TOP + 82, 80, 24), 17)
	fray_word.name = "FrayWord"
	fray_word.visible = StitchedRules.fray_enabled
	add_child(fray_word)
	fray_bar = _bar(Rect2(236, BAR_TOP + 84, 230, 22), FRAY)
	fray_bar.name = "ActorFray"
	fray_bar.max_value = 200
	fray_bar.visible = StitchedRules.fray_enabled
	add_child(fray_bar)
	for index in StitchedBattleScreen.SLOTS.size():
		var slot: String = StitchedBattleScreen.SLOTS[index]
		var button := TextureButton.new()
		button.name = "Part_" + slot
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
		button.mouse_entered.connect(func(): _show_ability_card(slot))
		button.mouse_exited.connect(func(): _hide_ability_card(slot))
		button.focus_entered.connect(func(): _show_ability_card(slot))
		button.focus_exited.connect(func(): _hide_ability_card(slot))
		# S13: the part shows as the cloth patch sewn on that limb; its outline tells the tier.
		# Owner 11-09: the abilities are round icons with a thin outline and nothing behind.
		for layer in ["Patch", "Frayed"]:
			var art := TextureRect.new()
			art.name = layer
			art.position = Vector2((114.0 - ICON) / 2.0, 0)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.size = Vector2(ICON, ICON)
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.material = round_material(ICON, TIER_OUTLINE[1] if layer == "Patch" else Color(0, 0, 0, 0))
			button.add_child(art)
		# Job 4: exactly one visible socket on each signature ability, even when empty.
		# Reuse the felt name-plate picture for its circular rim; never draw UI art in code.
		var frame := TextureRect.new()
		frame.name = "SewnFrame"
		frame.position = Vector2(77, 64)
		frame.size = Vector2(SEWN, SEWN)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame.texture = NAME_PLATE
		frame.material = round_material(SEWN)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(frame)
		var sewn := TextureRect.new()
		sewn.name = "Sewn_0"
		sewn.position = frame.position + Vector2(3, 3)
		sewn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sewn.size = Vector2(SEWN - 6, SEWN - 6)
		sewn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sewn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(sewn)
		var slot_label := _label(SLOT_NAMES[slot], Rect2(12, 31, 90, 30), 24, BONE, HORIZONTAL_ALIGNMENT_CENTER)
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
	# Retired Wren hand actions must never appear in live fights, including pre-S14 ones.
	if not StitchedRules.wren_hands:
		return
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
		# Owner 11-10: Re-tie is retired in every live fight, including older
		# non-S14 encounters. Explicit legacy tests can still opt into it.
		if entry[0] == "re_tie" and not StitchedRules.wren_hands:
			continue
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
	# Owner combat job 5: the More tray opens over the corner, so the map steps aside.
	if corner_map != null:
		corner_map.visible = not open
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
		_drop_bar_focus()
	refresh()
	# Block an immediate second click only when an actual ability beat is pending.
	# Wren's free hand action has no held pose and must not block the doll's turn.
	var has_new_ability := false
	for index in range(_seen_receipts, engine.receipts.size()):
		if str(engine.receipts[index].get("action", "")) == "ability":
			has_new_ability = true
			break
	if bool(receipt.get("ok", false)) and str(receipt.get("pending", "")).is_empty() \
			and has_new_ability and not engine._motion_is_reduced() and not battle.is_over():
		_beat_input_shield.show()
	# After refresh: its "Pick a target." line used to hide why a click was refused (Mistral playtest 11-09).
	if not bool(receipt.get("ok", false)) and receipt.has("error"):
		log_label.text = str(receipt.error).capitalize()
	return receipt


## S14 hover: a locked ability says why in plain words, with no ranks or numbers.
static func _plain_lock(reason: String) -> String:
	if reason.is_empty() or reason.begins_with("No active hero"):
		return ""
	if reason.begins_with("TORN"):
		return "Torn: mend it at the Sewing Circle."
	if reason.begins_with("Wrong launch rank"):
		return "Can't be used from this spot."
	if reason.begins_with("Movement/thread lock"):
		return "The thread holds this doll still."
	if reason.begins_with("No legal target"):
		return "No one it can reach."
	return "Can't be used now."


## A settled action leaves the bar buttons behind: a stray Enter must not re-arm
## the focused part or hand for the next doll. Only bar button focus is touched.
func _drop_bar_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return
	for slot in part_buttons:
		if part_buttons[slot] == focused:
			focused.release_focus()
			return
	for action_id in hand_buttons:
		if hand_buttons[action_id] == focused:
			focused.release_focus()
			return


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
	if engine._selected_part.is_empty()and (engine._hand_pending.is_empty() or engine._hand_pending.begins_with("lift:")):
		log_label.text = "Pick an ability first."
		return {"ok": false, "error": "no part chosen"}
	var receipt := _act(engine.submit_target(side, rank))
	# A refused click says plainly who the chosen ability can be picked on.
	if not bool(receipt.get("ok", false)) and str(receipt.get("error", "")) == "illegal target" \
			and not engine._selected_part.is_empty():
		log_label.text = _pickable_line(side)
	return receipt


## Plain words for who the chosen ability can target right now (the lit figures). The
## clicked side is known, so a refused doll or foe of the right kind is told it simply
## cannot take this ability, not that it is the wrong kind of figure (Mistral 11-10).
func _pickable_line(clicked_side: String = "") -> String:
	var actor := battle.get_unit(battle.current_actor_id())
	var ability := engine.slot_ability(actor, engine._selected_part)
	var ability_name := str(ability.get("name", ""))
	if ability_name.is_empty():
		ability_name = "That ability"
	var foes := 0
	var dolls := 0
	for key in engine.legal_targets():
		if key.begins_with("foe_"):
			foes += 1
		else:
			dolls += 1
	if clicked_side == "hero" and dolls > 0:
		return "%s cannot be used on that doll; pick a lit doll." % ability_name
	if clicked_side == "foe" and foes > 0:
		return "%s cannot be used on that foe; pick a lit foe." % ability_name
	if foes > 0 and dolls == 0:
		return "%s can only be used on the foes; pick a lit foe." % ability_name
	if dolls > 0 and foes == 0:
		return "%s can only be used on Wren's dolls; pick a lit doll." % ability_name
	if foes == 0 and dolls == 0:
		return "%s can reach no one from here." % ability_name
	return "%s; pick a lit figure." % ability_name


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
		log_label.text = "Arrows choose a target, then Enter / Space confirms."
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
	_update_corner_foe()


## Owner combat job 5: the right edge above the foes holds the run's route map; hovering
## a foe swaps it for that foe's full details (see _update_corner_foe). The owner's lower
## right corner is the foes' stage and the ability bar, so the corner rides the free strip
## between the top bar and the figures.
func _build_corner_map() -> void:
	corner_map = StitchedCornerMap.new(Rect2(972, 106, 304, 180))
	add_child(corner_map)


## The host run feeds the corner its real route data (rooms, walked path, the
## candle on the room the party stands in) and this fight's kind word.
func present_corner_map(run: StitchedRunSession) -> void:
	if run == null or run.map == null or corner_map == null:
		return
	fight_kind = str(run.pending.get("kind", ""))
	var floors := run.map.get_floors()
	if floors.is_empty():
		return
	# get_current_floor() counts the doors chosen: this fight happens on that floor,
	# so its rooms sit one index below the choice count.
	var floor_index := clampi(run.map.get_current_floor() - 1, 0, floors.size() - 1)
	corner_map.present_floor(floor_index + 1, floors[floor_index], run.map.get_route(),
		run.map.get_current_node_id())


## Owner combat job 5: a hovered foe takes the corner card and the foreground; the
## road map returns as soon as the pointer leaves it. A heap or the fight's end
## never takes the corner.
func _update_corner_foe() -> void:
	if corner_map == null:
		return
	var unit := engine._unit_at("foe", int(hovered.get_slice("_", 1))) if hovered.begins_with("foe_") else {}
	var live := not unit.is_empty() and not bool(unit.get("dead", false)) and not battle.is_over()
	if live:
		corner_map.show_foe(str(unit.get("name", "Foe")), _foe_corner_lines(unit))
	else:
		corner_map.show_map()
	_begin_foe_spotlight(hovered if live else "")


## The hovered foe's own corner lines, every value from the live rules state.
func _foe_corner_lines(unit: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var kind_word := str({"Boss": "Boss", "Elite": "Elite"}.get(fight_kind, "Foe"))
	if bool(unit.get("is_boss", false)):
		kind_word = "Boss"
	lines.append("%s · rank %d" % [str(kind_word), int(unit.get("rank", 0))])
	lines.append("Health %d / %d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 0))])
	var moves := PackedStringArray()
	for ability in unit.get("abilities", []):
		var move := str(ability.get("name", ""))
		if not move.is_empty():
			moves.append(move)
	if not moves.is_empty():
		lines.append("Moves: " + ", ".join(moves))
	var resists: Dictionary = unit.get("resist", {})
	if not resists.is_empty():
		var words := PackedStringArray()
		for group in resists:
			words.append("%s %d%%" % [str(group), int(resists[group])])
		lines.append("Resists " + ", ".join(words))
	var badges := StitchedBattleChrome._badge_entries(unit, "foe")
	var effects := PackedStringArray()
	for entry in badges:
		var full := str(entry.get("full", ""))
		if not full.is_empty():
			effects.append(full)
	lines.append(("Now: " + ", ".join(effects)) if not effects.is_empty() else "Nothing clings to it now")
	return lines


## Owner combat job 5: the hovered foe comes to the foreground — the corridor dims
## around it and it brightens and grows a touch, easing back when the pointer leaves.
## A held attack beat keeps its own spotlight; the hover never cuts into one.
func _begin_foe_spotlight(key: String) -> void:
	if key == _foe_hover_lit:
		return
	if not _foe_hover_lit.is_empty():
		var was := _foe_hover_lit
		_foe_hover_lit = ""
		stage.end_spotlight()
		if _foe_hover_grow != null:
			_foe_hover_grow.kill()
			_foe_hover_grow = null
		var eased: Sprite3D = stage.figure_nodes.get(was)
		if eased != null:
			var ease_back := create_tween()
			ease_back.tween_property(eased, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_SINE)
	if key.is_empty() or engine._motion_is_reduced():
		return
	if _beats != null and _beats.is_running():
		return
	_foe_hover_lit = key
	stage.begin_spotlight([key], [], 0.2)
	var figure: Sprite3D = stage.figure_nodes.get(key)
	if figure != null:
		_foe_hover_grow = create_tween()
		_foe_hover_grow.tween_property(figure, "scale", Vector3.ONE * 1.1, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## A starting or cancelled beat owns the stage: no hover spotlight may linger.
func _clear_foe_spotlight() -> void:
	if _foe_hover_grow != null:
		_foe_hover_grow.kill()
		_foe_hover_grow = null
	if not _foe_hover_lit.is_empty():
		var figure: Sprite3D = stage.figure_nodes.get(_foe_hover_lit) if stage != null else null
		if figure != null:
			figure.scale = Vector3.ONE
		_foe_hover_lit = ""


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
	return _textures[path]


func _figure_art(unit_id: String) -> Texture2D:
	if has_side_art(unit_id):
		var side_still := _texture(side_art_path(unit_id))
		if side_still != null:
			return side_still
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
	var visible_actor := _held_actor_id if not _held_actor_id.is_empty() else battle.current_actor_id()
	var visible_index := int(battle.state_snapshot().get("turn_index", -1))
	if not _held_actor_id.is_empty():
		visible_index = _held_actor_index if _held_actor_index >= 0 else battle.turn_order().find(_held_actor_id)
	ribbon.show_order(entries, visible_actor, battle.is_over(), visible_index)
	ribbon.visible = not battle.is_over()
	var boss := battle.is_boss_encounter()
	# A summoned / displaced fourth foe needs compact spacing; normal 2-3 foe
	# groups can spread out so wide bodies do not bury their neighbours.
	var fourth := engine._unit_at("foe", 4)
	var four_foes := (not fourth.is_empty() and not bool(fourth.get("dead", false))) \
		or not engine._heap_at(4).is_empty()
	for side in ["hero", "foe"]:
		for rank in range(1, 5):
			var key: String = side + "_" + str(rank)
			var unit: Dictionary = engine._unit_at(side, rank)
			var standing := not unit.is_empty() and not bool(unit.get("dead", false)) and not bool(unit.get("lost", false))
			var heap: Dictionary = engine._heap_at(rank) if side == "foe" and not standing else {}
			var where := stage.fight_point(side, rank, four_foes)
			# Owner 11-10: a unit that fell on the blow being held keeps its struck pose on the seat;
			# the scrap heap takes its place when the beat has eased back (see _drain_queued_beats).
			var fallen: Sprite3D = stage.figure_nodes.get(key)
			var fallen_unit := _fallen_foe_at(rank, str(fallen.get_meta("fight_unit", ""))) \
				if side == "foe" and fallen != null and not standing else {}
			if not fallen_unit.is_empty() and _hold_pending() and fallen.visible:
				var held_plate: Control = plates[key]
				(held_plate.get_node("Health") as TextureProgressBar).value = 0.0
				(held_plate.get_node("HealthText") as Label).text = "0/%d" % int(fallen_unit.get("max_hp", 0))
				_present_plate_statuses(held_plate, fallen_unit, side)
				continue
			if standing:
				# A boss encounter also contains ordinary minions; only the true boss grows.
				var tall := HERO_HEIGHT if side == "hero" else (BOSS_HEIGHT if boss and bool(unit.get("is_boss", false)) else FOE_HEIGHT)
				# Most foes are painted looking right; a few already look left and must
				# not be mirrored. Keep each one's art facing the hero ranks.
				# A turn can resolve while the prior hit is held; never replace its live pose,
				# step or scale on the normal battle refresh. A different occupant still places.
				var figure: Sprite3D = stage.figure_nodes.get(key)
				if _beats == null or not _beats.is_running() or figure == null \
						or str(figure.get_meta("fight_unit", "")) != str(unit.id):
					if side == "hero" and bool(unit.get("hanging", false)):
						# Hanging means zero HP with a torn limb, not an upright idle doll.
						# Lie on the floor but keep the doll's idle loop moving in combat.
						var art := _figure_art(str(unit.id))
						figure = stage.place_flat(key, art, where, HERO_HEIGHT * 0.82, -PI / 2.0)
						figure.set_meta("idle_frames", stage.idle_frames(art))
					else:
						figure = stage.place(key, _figure_art(str(unit.id)), where, tall)
					figure.set_meta("fight_unit", str(unit.id))
				figure.flip_h = battle_flip(side, str(unit.id))
			elif not heap.is_empty():
				var pile := stage.place(key, StitchedBattleScreen.SCRAP_TEXTURE, where, HEAP_HEIGHT)
				pile.flip_h = false
				pile.set_meta("fight_unit", "")
			elif stage.figure_nodes.has(key):
				stage.figure_nodes[key].visible = false
				stage.figure_nodes[key].set_meta("fight_unit", "")
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
			elif not heap.is_empty():
				title.text = "Scrap heap"
				hp.max_value = maxf(1.0, float(heap.get("max_hp", heap.get("hp", 1))))
				hp.value = float(heap.get("hp", 0))
				numbers.text = str(int(heap.get("hp", 0)))
			_present_plate_statuses(plate, unit if standing else {}, side)
			hits[key].visible = plate.visible
			var moves := _moveset(unit) if standing else ""
			hits[key].tooltip_text = (_simple_detail(engine.status_detail(side, rank)) + "\n" + moves).strip_edges() \
				if plate.visible else ""
	_sync_keyboard_targets()
	_refresh_bar()
	_shade_figures()
	# Hover details must follow current HP/rank (including a killing receipt),
	# not the snapshot taken when the pointer first entered the foe.
	if hovered.begins_with("foe_"):
		_update_corner_foe()
	_place_overlays()


## S14: each fixed signature ability keeps one visible socket for its add-on patch.
## Existing gold two-patch saves keep both effects and both hover lines, without a second UI socket.
func _sewn_picture(patch_id: String, entry: Dictionary) -> Texture2D:
	var picture := _texture(SEWN_ART + patch_id + ".png")
	if picture == null:
		picture = _texture("res://assets/paper/stitched/patches/" + patch_id + ".png")
	if picture == null:
		picture = _texture(ICONS + "status_" + str(entry.get("effect", "")) + ".png")
	return picture if picture != null else NAME_PLATE


func _show_kit_ability(button: TextureButton, shown: Dictionary, slot: String, torn: bool, hero_turn: bool) -> void:
	var ability := engine.slot_ability(shown, slot) if not shown.is_empty() else {}
	var picture: TextureRect = button.get_node("Patch")
	var id := str(ability.get("id", ""))
	picture.texture = _texture(ABILITY_ART + id + ".png") if not id.is_empty() else null
	picture.material = round_material(ICON, TIER_OUTLINE[1])
	# Without the signature picture, show its own name, never a retired limb label.
	var stand_in: Label = button.get_node("Slot")
	stand_in.text = str(ability.get("name", ""))
	stand_in.add_theme_font_size_override("font_size", 15)
	stand_in.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stand_in.position = Vector2(12, 26)
	stand_in.size = Vector2(90, 62)
	stand_in.visible = picture.texture == null
	var lines: Array[String] = [str(ability.get("name", "")) if not torn else str(ability.get("name", "")) + " (torn)"]
	var catalog: Dictionary = StitchedS14Abilities.patches().get("by_id", {})
	var socketed: Array = battle._s14_sockets.get(str(shown.get("id", "")), {}).get(id, [])
	var frame: TextureRect = button.get_node("SewnFrame")
	var badge: TextureRect = button.get_node("Sewn_0")
	frame.visible = not ability.is_empty()
	frame.modulate = Color("eee1c8", 0.95) if not socketed.is_empty() else Color("c8b8a5", 0.34)
	badge.texture = null
	badge.visible = not socketed.is_empty() and frame.visible
	if badge.visible:
		var first_id := str(socketed[0])
		badge.texture = _sewn_picture(first_id, catalog.get(first_id, {}))
		badge.tooltip_text = str(catalog.get(first_id, {}).get("name", first_id.capitalize()))
	else:
		badge.tooltip_text = "Empty patch slot"
	for patch_id in socketed:
		var key := str(patch_id)
		lines.append("Sewn on: " + str(catalog.get(key, {}).get("name", key.capitalize())))
	button.disabled = not hero_turn or not engine.valid_slot(shown, slot)
	button.tooltip_text = "\n".join(lines).strip_edges()


## Owner combat job 3: the hover card itself, a felt panel above the ability bar.
func _build_ability_card() -> void:
	ability_card = _felt(Rect2(0, 0, CARD_W, 120), Color("241c2af5"))
	ability_card.name = "AbilityCard"
	ability_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_card.visible = false
	add_child(ability_card)
	ability_card_title = _label("", Rect2(14, 8, CARD_W - 28, 26), 19, AMBER)
	ability_card_title.name = "CardTitle"
	ability_card.add_child(ability_card_title)
	ability_card_body = _label("", Rect2(14, 36, CARD_W - 28, 80), 14, BONE)
	ability_card_body.name = "CardBody"
	ability_card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability_card_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	ability_card.add_child(ability_card_body)


## Fills and places the card beside the hovered ability button, above the bar and clear
## of the fight log. Real values come from the live actor and the rules' own helpers.
func _show_ability_card(slot: String) -> void:
	if battle == null or engine == null or battle.is_over() or ability_card == null:
		return
	var actor := battle.get_unit(battle.current_actor_id())
	if actor.is_empty() or str(actor.get("side", "")) != "hero":
		return
	var ability := engine.slot_ability(actor, slot)
	if ability.is_empty():
		return
	ability_card_slot = slot
	var equipped: Dictionary = actor.get("parts", {}).get(slot, {})
	ability_card_title.text = str(ability.get("name", "")) + (" (torn)" if bool(equipped.get("torn", false)) else "")
	var lines := _ability_card_lines(actor, ability)
	ability_card_body.text = "\n".join(lines)
	var height := 42.0 + FONT.get_multiline_string_size(ability_card_body.text, HORIZONTAL_ALIGNMENT_LEFT, CARD_W - 28.0, 14).y + 10.0
	ability_card.size = Vector2(CARD_W, height)
	ability_card_body.size = Vector2(CARD_W - 28, height - 44.0)
	var button: TextureButton = part_buttons.get(slot)
	if button != null:
		var x := clampf(button.position.x + button.size.x / 2.0 - CARD_W / 2.0, 8.0, 1280.0 - CARD_W - 8.0)
		ability_card.position = Vector2(x, maxf(116.0, 492.0 - height))
	ability_card.visible = true


func _hide_ability_card(slot: String = "") -> void:
	if not slot.is_empty() and not ability_card_slot.is_empty() and slot != ability_card_slot:
		return
	ability_card_slot = ""
	if ability_card != null:
		ability_card.visible = false


## The card's lines in plain numbers: kind, damage, crit, hit chance per living foe in
## reach, heal, every effect with its duration, launch and target ranks, and the sewn patch.
func _ability_card_lines(actor: Dictionary, ability: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var kind_words := {"melee": "Melee attack", "ranged": "Ranged attack", "heal": "Heal",
		"guard": "Guard", "buff": "Buff", "debuff": "Debuff", "move": "Move"}
	var side_words := {"enemy": "foes", "ally": "dolls", "self": "self"}
	lines.append(str(kind_words.get(str(ability.get("kind", "")), "Ability")))
	var dmg: Array = ability.get("dmg", [0, 0])
	if int(dmg[1]) > 0:
		var bonus := int(actor.get("dmg_bonus", 0))
		lines.append("Damage %d-%d%s" % [int(dmg[0]), int(dmg[1]), (" +%d" % bonus) if bonus > 0 else ""])
		var crit_chance := StitchedRules.CRIT_BASE + int(ability.get("crit", 0)) + int(actor.get("crit", 0))
		lines.append("Crit %d%% for x1.5 (deals %d)" % [crit_chance, StitchedRules.crit_damage(int(dmg[1]))])
	var side := str(ability.get("target_side", "enemy"))
	if side == "enemy":
		var hit_lines := PackedStringArray()
		var mask := int(ability.get("target_mask", 0))
		for rank in range(1, 5):
			if not StitchedParts.ranks_allowed(mask, rank):
				continue
			var target := engine._unit_at("foe", rank)
			if target.is_empty() or bool(target.get("dead", false)):
				continue
			var chance := StitchedRules.hit_chance(int(ability["acc"]) + int(actor.get("acc", 0)),
				StitchedRules.effective_dodge(target), int(actor.get("miss_streak", 0)))
			hit_lines.append("%d%% vs %s (R%d)" % [chance, str(target.get("name", "foe")), rank])
		if hit_lines.is_empty():
			lines.append("No foe in reach from here now")
		else:
			lines.append("Hit: " + ", ".join(hit_lines))
	else:
		lines.append("Always lands on the %s" % str(side_words.get(side, side)))
	var effects: Dictionary = ability.get("effects", {})
	for key in effects:
		if key == "duration" or key == "fray":
			continue
		var value := int(effects[key])
		match str(key):
			"dodge":
				lines.append("Dodge +%d for %d turn%s" % [value, int(effects["duration"]), "s" if int(effects["duration"]) != 1 else ""])
			"heal":
				lines.append("Heals %d HP" % value)
			"push":
				lines.append("Pushes 1 rank back")
			"pull":
				lines.append("Pulls 1 rank forward")
			"snip":
				lines.append("Snips the thread behind")
			"tear":
				lines.append("Tears a seam open")
			"guard":
				lines.append("Guards an ally for %d turns" % value)
			_:
				lines.append("%s %d turn%s" % [str(key).capitalize(), value, "s" if value != 1 else ""])
	lines.append("Use from R%s" % _rank_span(ability.get("launch", [])))
	lines.append("Hits %s R%s" % [str(side_words.get(side, side)), _rank_span(ability.get("target", []))])
	if bool(ability.get("multi", false)):
		lines.append("Hits every legal target")
	if int(ability.get("self_move", 0)) != 0:
		lines.append("Then steps %s" % ("forward" if int(ability["self_move"]) < 0 else "back"))
	var sewn: Array = battle._s14_sockets.get(str(actor.get("id", "")), {}).get(str(ability.get("id", "")), [])
	if sewn.is_empty():
		lines.append("Patch slot: empty")
	else:
		var catalog: Dictionary = StitchedS14Abilities.patches().get("by_id", {})
		for patch_id in sewn:
			var patch: Dictionary = catalog.get(str(patch_id), {})
			if patch.is_empty():
				continue
			if str(patch.get("effect", "")) == "chain":
				lines.append("Sewn: %s - chains to the next foe" % str(patch.get("name", patch_id)))
			else:
				lines.append("Sewn: %s - %s %d" % [str(patch.get("name", patch_id)), str(patch.get("effect", "")), int(patch.get("amount", 0))])
	return lines


## [1, 2, 3] -> "1-3", [1, 2, 4] -> "1, 2, 4".
static func _rank_span(ranks: Variant) -> String:
	if not ranks is Array or ranks.is_empty():
		return "-"
	var sorted: Array = ranks.duplicate()
	sorted.sort()
	var parts := PackedStringArray()
	var index := 0
	while index < sorted.size():
		var start := int(sorted[index])
		var end := start
		while index + 1 < sorted.size() and int(sorted[index + 1]) == end + 1:
			index += 1
			end = int(sorted[index])
		parts.append(str(start) if start == end else "%d-%d" % [start, end])
		index += 1
	return ", ".join(parts)


func _refresh_bar() -> void:
	var acting_id := _held_actor_id if not _held_actor_id.is_empty() else battle.current_actor_id()
	var acting := battle.get_unit(acting_id)
	var hero_turn := str(acting.get("side", "")) == "hero" and not battle.is_over()
	# Visuals belong to the held actor, but the engine's next turn owns which
	# controls are valid. This keeps scripted and accessibility actions authoritative.
	var live_actor := battle.get_unit(battle.current_actor_id())
	var live_hero_turn := battle.current_side() == "hero" and not battle.is_over()
	# The kit the player can use belongs to the engine's live turn, so during a held
	# pose it shows the next acting doll's real abilities, never empty circles.
	var kit_actor: Dictionary = live_actor if live_hero_turn else {}
	var kit_turn := live_hero_turn
	# Owner 11-10: a foe turn shows the acting foe's own plate on the bar instead of
	# an empty felt strip; the doll kit keeps to the engine's live doll.
	var shown: Dictionary = acting if not acting.is_empty() and not battle.is_over() else {}
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
	var knot := StitchedSewnPatches.set_thread(worn_parts) if hero_turn and not battle._s14 else ""
	thread_knot.texture = _texture(StitchedSewnPatches.knot_path(knot)) if not knot.is_empty() else null
	thread_knot.visible = not knot.is_empty() and not battle.is_over()
	thread_knot.tooltip_text = ("Whole cloth: every patch is sewn with one thread." if StitchedSewnPatches.whole_cloth(worn_parts)
		else "Matching thread: some of these patches sit well together.") if not knot.is_empty() else ""
	fray_bar.tint_progress = BLOOD if int(shown.get("fray", 0)) >= 100 else FRAY
	for slot in part_buttons:
		var button: TextureButton = part_buttons[slot]
		var equipped: Dictionary = kit_actor.get("parts", {}).get(slot, {})
		var part: Dictionary = engine.parts.get(str(equipped.get("id", "")), {})
		var move_label: Label = button.get_node("Move")
		move_label.text = ""
		var torn := bool(equipped.get("torn", false))
		var patch: TextureRect = button.get_node("Patch")
		patch.texture = _texture(StitchedSewnPatches.icon_path(str(part.get("id", "")), slot)) if not part.is_empty() else null
		patch.modulate = Color(0.5, 0.47, 0.47, 0.8) if torn else Color.WHITE
		patch.material = round_material(ICON, TIER_OUTLINE.get(int(equipped.get("tier", 1)), TIER_OUTLINE[1]))
		(button.get_node("Frayed") as TextureRect).texture = _texture(StitchedSewnPatches.ART + "frayed.png") if torn else null
		# With a patch picture the slot word steps aside. Owner 11-09: the move name only shows on hover.
		(button.get_node("Slot") as Label).visible = patch.texture == null
		move_label.visible = false
		var s14 := bool(engine.config.get("s14", false))
		if not part.is_empty():
			# S14: the button performs the fixed signature ability, so hover names that one.
			move_label.text = str((engine._dispatched_ability(shown, equipped) if s14
				else StitchedParts.ability_at_tier(part, int(equipped.get("tier", 1)))).get("name", ""))
			if torn:
				move_label.text = "torn"
		var live_equipped: Dictionary = live_actor.get("parts", {}).get(slot, {})
		button.disabled = not live_hero_turn or not engine._valid_part(live_actor, live_equipped)
		var cue := str(engine._part_cues.get(slot, {}).get("full", "")) if kit_turn else ""
		if s14:
			# Owner 11-09: the hover is the move name, never a slot heading, tier or stat sheet.
			cue = _plain_lock(engine._part_lock_reason(kit_actor, equipped)) if kit_turn and button.disabled else ""
		button.tooltip_text = (move_label.text + "\n" + cue).strip_edges()
		(button.get_node("Sewn_0") as TextureRect).texture = null
		(button.get_node("Sewn_0") as TextureRect).visible = false
		(button.get_node("SewnFrame") as TextureRect).visible = false
		if battle._s14:
			_show_kit_ability(button, kit_actor, slot, torn, kit_turn)
			button.disabled = not live_hero_turn or not engine.valid_slot(live_actor, slot)
	_shade_parts()
	var cut := hero_turn and battle.thread_cuts().has(str(shown.get("id", "")))
	var hand_open := battle.hand_action_open() and not battle.is_over()
	var lifting := engine._hand_pending.begins_with("lift:")
	var lift_id := str(engine._unit_at("hero", int(engine._hand_pending.get_slice(":", 1))).get("id", "")) if lifting else ""
	# Even in Lift's More tray, only the rules-authorized direction is live.
	more_buttons.move_front.disabled = not (battle.hand_action_check("lift", lift_id, -1).is_empty() if lifting
		else live_hero_turn and engine._can_move(-1))
	more_buttons.move_back.disabled = not (battle.hand_action_check("lift", lift_id, 1).is_empty() if lifting
		else live_hero_turn and engine._can_move(1))
	more_buttons.pass.disabled = not live_hero_turn
	if more_buttons.has("re_tie"):
		more_buttons.re_tie.disabled = not cut
	more_buttons.retreat.disabled = not live_hero_turn or battle.is_boss_encounter()
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
		# The engine's live turn owns the kit: a foe's turn hides it, and a foe's held
		# pose leaves the next doll's real kit ready beside the foe's own plate.
		part_buttons[slot].visible = not battle.is_over() and live_hero_turn
	# Owner combat job 3: the hover card follows the live kit; it hides with the buttons.
	if battle.is_over() or not live_hero_turn:
		_hide_ability_card()
	elif not ability_card_slot.is_empty():
		_show_ability_card(ability_card_slot)
	# At the end of the fight the bar keeps only the outcome line and Continue:
	# no empty health plate, no actor name, no More button.
	var over := battle.is_over()
	var fray_shown := StitchedRules.fray_enabled
	var hero_shown := not shown.is_empty()
	portrait.visible = not over and hero_shown
	actor_name.visible = not over and hero_shown
	health_word.visible = not over and hero_shown
	health_bar.visible = not over and hero_shown
	health_text.visible = not over and hero_shown
	fray_word.visible = fray_shown and not over and hero_shown
	fray_bar.visible = fray_shown and not over and hero_shown
	more_button.visible = not over
	# Who did what stays off the screen (the move name flashes up during the move);
	# only Wren's own words remain.
	var shown_lines := PackedStringArray()
	var move_name_next := false
	for line in engine._notice.split("\n", false):
		var said := not (move_name_next or line.begins_with("Round ") or line.begins_with("→ ") or line.contains(" · "))
		move_name_next = line.ends_with(" · Ability")
		if said:
			shown_lines.append(line)
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
	var acting_id := _held_actor_id if not _held_actor_id.is_empty() else battle.current_actor_id()
	var acting := battle.get_unit(acting_id)
	var actor_key := str(acting.get("side", "")) + "_" + str(acting.get("rank", 0)) \
		if not battle.is_over() or not _held_actor_id.is_empty() else ""
	for key in plates:
		var marker: TextureRect = plates[key].get_node("TargetMarker")
		var marked: bool = choosing and targets.has(key) and plates[key].visible and not more_panel.visible
		marker.visible = marked
		if marked:
			var path := "res://assets/paper/stitched/ui/target_marker_green.png" if key.begins_with("hero_") \
				else "res://assets/paper/stitched/ui/target_marker_red.png"
			var art := _texture(path)
			marker.texture = art if art != null else BAR_FRAME
			marker.modulate = Color.WHITE if art != null else (
				Color("68c78b") if key.begins_with("hero_") else Color("e75b54"))
		var tone := Color.WHITE
		# Owner combat job 5: while a foe holds the corner its spotlight owns the tones.
		var foe_spot := not _foe_hover_lit.is_empty() and (_beats == null or not _beats.is_running())
		if foe_spot:
			tone = StitchedCorridorStage.SPOT_LIT if key == _foe_hover_lit else StitchedCorridorStage.SPOT_DIM
		elif choosing:
			tone = Color(1.25, 1.12, 0.95) if targets.has(key) else Color(0.5, 0.48, 0.5)
		if key == hovered and (not choosing or targets.has(key)):
			tone = Color(1.4, 1.25, 1.0)
		if key == _keyboard_target and targets.has(key):
			tone = Color(1.75, 1.45, 0.85)
		if stage.figure_nodes.has(key) and (_beats == null or not _beats.is_running()):
			stage.figure_nodes[key].modulate = tone
		var back: NinePatchRect = plates[key].get_node("Back")
		back.self_modulate = Color(1.8, 1.45, 0.75) if key == _keyboard_target and targets.has(key) else (Color(1.5, 1.2, 0.7) if key == actor_key else (Color(1.2, 1.1, 0.9) if targets.has(key) else Color.WHITE))
		var title: Label = plates[key].get_node("Name")
		title.add_theme_color_override("font_color", AMBER if key == actor_key or targets.has(key) else BONE)


## A long name (the Sewing-Machine Colossus) shrinks until it fits its plate instead of being cut at both ends.
func _fit_name(title: Label) -> void:
	var font_size := 16
	while font_size > 10 and FONT.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 4.0 > title.size.x:
		font_size -= 1
	title.add_theme_font_size_override("font_size", font_size)


## Plates sit under each figure's feet and hit boxes cover the figure; both follow lunges.
func _place_overlays() -> void:
	var boxes: Dictionary = {}
	var spots: Dictionary = {}
	for key in plates:
		var plate: Control = plates[key]
		var feet: Variant = stage.screen_point(key)
		if feet == null or not plate.visible:
			hits[key].visible = false
			continue
		var spot: Vector2 = feet
		plate.position = Vector2(spot.x - plate.size.x / 2.0, minf(spot.y + 2.0, BAR_TOP - 92.0))
		var rect := stage.screen_rect(key)
		if rect.size.x > 0.0:
			boxes[key] = rect
			spots[key] = spot.x
	# Plates are wider than close feet can be; slide them apart so no name sits on another.
	var ordered: Array = []
	for key in plates:
		if plates[key].visible:
			ordered.append(key)
	ordered.sort_custom(func(a, b): return plates[a].position.x < plates[b].position.x)
	var edge := -INF
	for key in ordered:
		var plate: Control = plates[key]
		if plate.position.x < edge + 4.0:
			plate.position.x = minf(edge + 4.0, get_viewport_rect().size.x - plate.size.x - 4.0)
		edge = plate.position.x + plate.size.x
	# Wide art (the boss) overlaps its neighbour's box and the later box used to win the click:
	# playtest 11-09 aimed at the Behemoth and struck the Scissor Crab. Neighbours (either side)
	# split at the midpoint between their feet.
	var keys := boxes.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: String = keys[i]
			var b: String = keys[j]
			var left := a if spots[a] <= spots[b] else b
			var right := b if left == a else a
			var mid: float = (spots[a] + spots[b]) / 2.0
			var lbox: Rect2 = boxes[left]
			var rbox: Rect2 = boxes[right]
			if lbox.end.x <= rbox.position.x:
				continue
			lbox.size.x = maxf(0.0, minf(lbox.end.x, mid) - lbox.position.x)
			rbox = Rect2(Vector2(maxf(rbox.position.x, mid), rbox.position.y),
				Vector2(maxf(0.0, rbox.end.x - maxf(rbox.position.x, mid)), rbox.size.y))
			boxes[left] = lbox
			boxes[right] = rbox
	for key in plates:
		if not boxes.has(key):
			hits[key].visible = false
			continue
		hits[key].position = boxes[key].position
		hits[key].size = boxes[key].size
		hits[key].visible = boxes[key].size.x > 0.0
	# Outcome words follow the moving figures and stay above the health plates.
	for float_key in _float_groups:
		var group: Control = _float_groups[float_key]
		var bounds := stage.screen_rect(float_key)
		if bounds.size.x <= 0.0:
			group.hide()
			continue
		group.show()
		group.position = Vector2(clampf(bounds.get_center().x - group.size.x * 0.5,
			4.0, 1276.0 - group.size.x), clampf(bounds.position.y + bounds.size.y * 0.15 - group.size.y,
			104.0, BAR_TOP - group.size.y - 110.0))
	# The only reaction text is MISS; it follows the actual dodger's 3D projection.
	for key in _miss_labels:
		var label: Label = _miss_labels[key]
		if not label.visible:
			continue
		var rect := stage.screen_rect(key)
		if rect.size.x > 0.0:
			label.position = Vector2(clampf(rect.get_center().x - label.size.x / 2.0,
				0.0, 1280.0 - label.size.x), maxf(125.0, rect.position.y + rect.size.y * 0.35))
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
	if _beat_input_shield.visible:
		# A queued beat may already have advanced the rules to another doll; its
		# input must wait until the visual turn has finished as well.
		if event is InputEventKey and event.pressed:
			get_viewport().set_input_as_handled()
		return
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
		if not _keyboard_target.is_empty()and _keyboard_targets.has(_keyboard_target) \
				and engine.legal_targets().has(_keyboard_target):
			var chosen := _keyboard_target
			click_figure(chosen.get_slice("_", 0), int(chosen.get_slice("_", 1)))
	get_viewport().set_input_as_handled()


## The foe that just fell at this rank, if its own picture still stands there.
func _fallen_foe_at(rank: int, unit_id: String) -> Dictionary:
	if unit_id.is_empty():
		return {}
	for foe in battle.get_foes():
		if str(foe.get("id", "")) == unit_id and bool(foe.get("dead", false)) and int(foe.get("rank", 0)) == rank:
			return foe
	return {}


## Preserve a fallen figure during an ability hold or a confirmed tick-only beat.
func _hold_pending() -> bool:
	if engine._motion_is_reduced():
		return false
	if _beats != null and _beats.is_running():
		return true
	for index in range(_seen_receipts, engine.receipts.size()):
		var entry: Dictionary = engine.receipts[index]
		if not bool(entry.get("ok", false)):
			continue
		if str(entry.get("action", "")) == "ability":
			return true
		if index < engine.turn_cues.size() and not engine.turn_cues[index].is_empty():
			return true
	return false


func _state_signature() -> String:
	return "%d|%s|%s|%s|%s|%d" % [engine.receipts.size(), engine._selected_part, engine._hand_pending,
		battle.current_actor_id(), battle.outcome(), battle.candle()]


func _process(_delta: float) -> void:
	if battle == null or engine == null:
		return
	# Toggles, a dying actor and the end of combat may interrupt an active shot.
	# The camera and figures must not keep an old pose into the next turn.
	if engine._motion_is_reduced():
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
		if _beats == null or not _beats.is_running():
			refresh()
		_arm_barks(float(barks.data.get("idle_delay", 9.0)))
	elif _state_signature() != _signature:
		refresh()
		_arm_barks(float(barks.data.get("idle_delay", 9.0)))
	elif _sync_keyboard_targets():
		_shade_figures()
		_target_hint()
	# Block double actions during held turns, but never cover the finished
	# battle's Continue button. The final blow still plays unless the player
	# explicitly chooses to leave early. Reaction overlays can be created during
	# that last hold, so keep Continue above them and the retired Wren controls.
	_beat_input_shield.visible = not engine._motion_is_reduced() and not battle.is_over() \
		and ((_beats != null and _beats.is_running()) or not _queued_receipts.is_empty())
	if battle.is_over() and continue_button.get_index() != get_child_count() - 1:
		move_child(continue_button, get_child_count() - 1)
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
	if unit.is_empty() or bool(unit.get("lost", false)):
		return ""
	var side := str(unit.get("side", ""))
	var rank := int(unit.get("rank", 0))
	if not side in ["hero", "foe"] or rank < 1 or rank > 4:
		return ""
	var key := "%s_%d" % [side, rank]
	var figure: Sprite3D = stage.figure_nodes.get(key)
	# Owner 11-10: a struck unit that fell on this blow still stands in its held pose until the beat
	# ends; only while its own picture is still on the seat (not the scrap heap that replaces it).
	if bool(unit.get("dead", false)):
		if figure == null or str(figure.get_meta("fight_unit", "")) != unit_id:
			return ""
	elif str(engine._unit_at(side, rank).get("id", "")) != unit_id:
		return ""
	return key if figure != null and figure.visible and figure.texture != null else ""


## The live seats an ability spotlights: the acting figure first, then each target.
## Only a struck opponent takes the red hit flash; an ally being mended stays lit.
func _receipt_spot_keys(receipt: Dictionary) -> Dictionary:
	var lit: Array[String] = []
	var flash: Array[String] = []
	var targets: Array[String] = []
	var actor_id := str(receipt.get("actor", ""))
	var actor_side := str(battle.get_unit(actor_id).get("side", ""))
	var attacker_key := _live_receipt_key(actor_id)
	if not attacker_key.is_empty():
		lit.append(attacker_key)
	for result in receipt.get("results", []):
		var target_id := str(result.get("target", ""))
		var target_key := _live_receipt_key(target_id)
		if target_key.is_empty() or target_key == attacker_key or lit.has(target_key):
			continue
		lit.append(target_key)
		targets.append(target_id)
		if bool(result.get("hit", true)) and str(battle.get_unit(target_id).get("side", "")) != actor_side:
			flash.append(target_key)
	return {"lit": lit, "flash": flash, "targets": targets, "actor": actor_id}


## Called by the genuine receipt tween, never by selection, hover or refresh.
## Owner 11-10: healing and guarding also focus their pair, without a red injury flash.
func _begin_receipt_focus(receipt: Dictionary, order_index: int = -1) -> void:
	_focus_actor_id = ""
	_focus_target_ids.clear()
	_clear_foe_spotlight()
	if engine._motion_is_reduced() or str(receipt.get("action", "")) != "ability":
		return
	var spot := _receipt_spot_keys(receipt)
	# Owner 11-10: a self-aimed mend and a killing blow leave only the actor lit;
	# the corridor still dims around that one figure for the same held beat.
	if spot.lit.is_empty():
		return
	_focus_target_ids = spot.targets
	_held_actor_id = spot.actor
	_held_actor_index = order_index
	# Show the attacker until this pose returns;rules have already advanced to the next doll.
	refresh()
	var focused := stage.start_fight_focus(spot.lit, _beat_span())
	stage.begin_spotlight(spot.lit, spot.flash)
	if focused:
		_focus_actor_id = spot.actor


## One receipt's whole held beat: the strike out, the held pose and the ease back.
func _beat_span() -> float:
	return BEAT_TIME * 0.4 + HOLD_TIME + BEAT_TIME * 0.6


func _cancel_beats() -> void:
	_clear_foe_spotlight()
	if _beats != null:
		_beats.kill()
		_beats = null
	_queued_receipts.clear()
	if _beat_input_shield != null:
		_beat_input_shield.hide()
	_show_move_name("")
	_clear_flying()
	_clear_target_reactions()
	for home_key in _beat_homes:
		var returned: Sprite3D = stage.figure_nodes.get(home_key)
		if returned != null:
			returned.position = _beat_homes[home_key]
			returned.rotation.z = 0.0
	_beat_homes.clear()
	_hide_ability_card()
	stage.cancel_fight_focus()
	# A killed beat must not leave a spotlight-grown figure behind.
	if stage != null:
		for fig in stage.figure_nodes.values():
			fig.scale = Vector3.ONE
	_focus_actor_id = ""
	_focus_target_ids.clear()
	_held_actor_id = ""
	_held_actor_index = -1
	if is_inside_tree():
		refresh()


func _exit_tree() -> void:
	if _beats != null:
		_beats.kill()
		_beats = null
	_queued_receipts.clear()
	_clear_flying()
	_clear_target_reactions()
	_beat_homes.clear()
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
	var own := StitchedBattleScreen.ability_pose_path(side, actor_id, ability_id)
	if not own.is_empty():
		var pictured := _texture(own)
		if pictured != null:
			return pictured
	if side == "hero" and not engine.ability_slot(actor, ability_id).is_empty():
		move = str(engine.slot_ability(actor, engine.ability_slot(actor, ability_id)).get("move", "attack"))
	elif side == "hero":
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
	var height := _figure_height(figure)
	figure.texture = texture
	figure.offset = Vector2.ZERO
	figure.pixel_size = height / float(texture.get_height())


## The finished rules receipt, not the pointer or the image filename, picks the pose.
## A failed attack dodges; a critical or lethal blow is heavy; applied statuses win
## over the ability's ordinary, authored reaction family.
func _receipt_reaction_kind(receipt: Dictionary, result: Dictionary) -> String:
	if not bool(result.get("hit", true)):
		return "dodge"
	if bool(result.get("crit", false)) or bool(result.get("lost", false)) \
			or bool(result.get("hanging", false)) or result.has("heap") \
			or (int(result.get("damage", 0)) > 0 and int(result.get("target_hp", 1)) <= 0) \
			or int(result.get("damage", 0)) >= 8:
		return "heavy"
	for entry in result.get("statuses", []):
		if (bool(entry.get("resisted", false)) or bool(entry.get("refused", false))):
			continue
		if str(entry.get("status", "")) == "stun":
			return "stun"
	for entry in result.get("statuses", []):
		if not bool(entry.get("resisted", false)) and str(entry.get("status", "")) in ["bleed", "rot"]:
			return "shudder"
	var actor_side := str(battle.get_unit(str(receipt.get("actor", ""))).get("side", ""))
	var target_side := str(result.get("target_side", ""))
	if target_side == actor_side and not actor_side.is_empty():
		return "brace"
	return StitchedBattleScreen.ability_reaction(str(receipt.get("ability", "")))


## All six kinds try the dedicated painted sprite first. Until an illustration
## arrives, older enemy hit strips supply a single held cell; movement supplies
## the rest. The target keeps its established silhouette and idle frames.
func _reaction_texture(unit_id: String, kind: String) -> Texture2D:
	var paths := StitchedBattleScreen.ROSTER.art_paths(unit_id)
	var still_path := str(paths.get("idle", ""))
	if still_path.is_empty():
		return null
	var art := _texture(still_path.get_basename() + "_react_" + kind + ".png")
	if art != null:
		return art
	if kind in ["hit", "heavy"]:
		var old := _texture(str(paths.get("hit_loop", "")))
		if old != null:
			var frames: Array = StitchedBattleScreen.ROSTER.Puppet.loop_frames(old, _figure_art(unit_id))
			if not frames.is_empty():
				return frames[0] as Texture2D
			return old
	return null


func _apply_target_reactions(receipt: Dictionary) -> void:
	_clear_target_reactions()
	_show_float_receipt(receipt)
	var actor_key:= _live_receipt_key(str(receipt.get("actor", "")))
	for result in receipt.get("results", []):
		var unit_id := str(result.get("target", ""))
		var key := _live_receipt_key(unit_id)
		if key.is_empty() or _reaction_kinds.has(key):
			continue
		var figure: Sprite3D = stage.figure_nodes.get(key)
		if figure == null:
			continue
		var kind := _receipt_reaction_kind(receipt, result)
		_reaction_kinds[key] = kind
		_reaction_units[key] = unit_id
		# An actor healing itself keeps the doing pose; a helped ally braces.
		if key != actor_key:
			var texture := _reaction_texture(unit_id, kind)
			if texture != null and figure.texture != null:
				var height := _figure_height(figure)
				figure.texture = texture
				figure.offset = Vector2.ZERO
				figure.pixel_size = height / float(texture.get_height())
		if kind in ["heavy", "shudder"] and key != actor_key:
			# The shove has already landed. Shake the painted figure, without
			# changing its rank, rules state or reserved spotlight movement.
			var shake := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
			var baseline_tilt := -0.21 if kind == "heavy" else 0.12
			for pulse in range(4 if kind == "heavy" else 6):
				shake.tween_property(figure, "rotation:z", baseline_tilt + (0.10 if pulse % 2 == 0 else -0.10), 0.065)
			shake.tween_property(figure, "rotation:z", baseline_tilt, 0.08)
			_reaction_shakes.append(shake)
		if kind == "dodge":
			var label: Label = _miss_labels.get(key)
			if label == null:
				label = _label("MISS", Rect2(0, 0, 136, 43), 36, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
				label.name = "Miss_" + key
				add_child(label)
				_miss_labels[key] = label
				# Continue wins on a finished fight; otherwise the shield catches a second click.
				_raise_beat_input_layer()
			label.modulate.a = 1.0
			label.visible = true
			var miss_fade := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
			miss_fade.tween_interval(HOLD_TIME * 0.86)
			miss_fade.tween_property(label, "modulate:a", 0.0, HOLD_TIME * 0.14)
			_float_tweens.append(miss_fade)
	_place_overlays()


func _clear_target_reactions()-> void:
	for shake in _reaction_shakes:
		if shake != null and shake.is_running():
			shake.kill()
	_reaction_shakes.clear()
	for key in _reaction_units:
		var figure: Sprite3D = stage.figure_nodes.get(key) if stage != null else null
		if figure == null or str(figure.get_meta("fight_unit", "")) != str(_reaction_units[key]):
			continue
		var idle: Texture2D = figure.get_meta("still")
		if idle != null:
			figure.texture = idle
			figure.pixel_size = float(figure.get_meta("still_pixel_size", figure.pixel_size))
			figure.offset = Vector2.ZERO
		figure.rotation.z = 0.0
	_reaction_kinds.clear()
	_reaction_units.clear()
	_clear_float_words()
	for label in _miss_labels.values():
		label.hide()


## Receipt-only callouts: no damage, crit, status or patch cue may be guessed from
## the selected ability. Redirected patch notes carry their own "on" unit id.
static func _float_tone(kind: String) -> Color:
	match kind:
		"kill": return Color("ed5149")
		"crit": return Color("ffac54")
		"damage": return Color("e6a061")
		"bleed": return Color("b94e50")
		"rot": return Color("a0bd65")
		"stun": return Color("ead172")
		"heal", "cleanse", "regen": return Color("b4d6ab")
		"guard", "strength": return Color("9ecae5")
		"resist": return Color("d9cfa8")
		_: return Color("e3ae79")


static func _float_add(events: Dictionary, key: String, words: String, family: String,
		icon: String = "", arrow: String = "") -> void:
	if key.is_empty() or words.is_empty():
		return
	if not events.has(key):
		events[key] = []
	events[key].append({"words": words, "family": family, "icon": icon, "arrow": arrow})


func _float_events(receipt: Dictionary) -> Dictionary:
	var events := {}
	if not bool(receipt.get("ok", true)):
		return events
	var patch_book: Dictionary = StitchedS14Abilities.patches().get("by_id", {})
	var shown_patches := {}
	# Passes and skips have no attack results, but may settle turn-start clocks.
	var results: Array = receipt.get("results", []) if str(receipt.get("action", "ability")) == "ability" else []
	for result in results:
		var target_id := str(result.get("target", ""))
		var key := _live_receipt_key(target_id)
		if key.is_empty():
			continue
		if bool(result.get("hit", true)):
			var patch_recipients := {}
			var damage := int(result.get("damage", 0))
			var lost: bool = bool(result.get("lost", false))
			var foe_killed: bool = result.has("heap") or (damage > 0 \
				and int(result.get("target_hp", 1)) == 0 \
				and str(result.get("target_side", "")) == "foe")
			if lost:
				_float_add(events, key, "LOST!", "kill", "float_kill")
			elif foe_killed:
				_float_add(events, key, "UNSTITCHED!", "kill", "float_kill")
			elif bool(result.get("hanging", false)):
				_float_add(events, key, "HANGING", "bleed", "status_hanging")
			# Only a confirmed death-door tear can call out a torn seam.
			# Never label a limb or infer one from an ordinary Bleed status.
			var torn: Dictionary = result.get("tear", {})
			if bool(torn.get("ok", true)) and not str(torn.get("slot", "")).is_empty():
				_float_add(events, key, "SEAM TORN!", "bleed", "status_hanging")
			if damage > 0:
				_float_add(events, key, ("CRIT! " if bool(result.get("crit", false)) else "") \
					+ str(damage), "crit" if bool(result.get("crit", false)) else "damage",
					"float_crit" if bool(result.get("crit", false)) else "")
			for effect in result.get("statuses", []):
				var status := str(effect.get("status", ""))
				if status.is_empty():
					continue
				var on_id := str(effect.get("on", target_id))
				if status == "guard" and not effect.has("on"):
					on_id = str(receipt.get("actor", ""))
				var on_key := _live_receipt_key(on_id)
				if bool(effect.get("resisted", false)) or bool(effect.get("refused", false)):
					_float_add(events, on_key, "RESIST", "resist")
				elif status == "heal":
					# A heal that restored nothing (target already at full HP) says so
					# instead of floating a meaningless "HEAL +0".
					var healed := int(effect.get("amount", 0))
					_float_add(events, on_key, "HEAL +" + str(healed) if healed > 0 else "FULL HP",
						"heal", "status_heal")
				elif status == "steal":
					_float_add(events, on_key, "DRAIN " + str(int(effect.get("amount", 0))),
						"damage", "status_steal")
				elif status == "cleanse":
					_float_add(events, on_key, "CLEANSED", "cleanse", "status_cleanse")
				else:
					var strong := status in ["dodge", "thorns", "riposte", "guard", "regen"]
					var weak := status in ["weak", "exposed", "blind", "mark", "tangled"]
					var family := "strength" if strong else status
					var arrow := "float_up" if strong else ("float_down" if weak else "")
					_float_add(events, on_key, status.to_upper(), family, "status_" + status, arrow)
				var effect_patch := str(effect.get("patch", ""))
				if not effect_patch.is_empty():
					patch_recipients[effect_patch] = on_key
					var signature := on_key + ":" + effect_patch
					if not shown_patches.has(signature):
						shown_patches[signature] = true
						_float_add(events, on_key, str(patch_book.get(effect_patch, {}).get("name",
							effect_patch.replace("_", " ").capitalize())).to_upper(), "strength",
							"patch:" + effect_patch)
			for patch_id in result.get("patches", []):
				var patch := str(patch_id)
				# A redirected helpful effect belongs to the healed/guarded doll,
				# not the foe the underlying signature struck.
				var patch_key := str(patch_recipients.get(patch, key))
				var signature := patch_key + ":" + patch
				if not shown_patches.has(signature):
					shown_patches[signature] = true
					_float_add(events, patch_key, str(patch_book.get(patch, {}).get("name",
						patch.replace("_", " ").capitalize())).to_upper(), "strength", "patch:" + patch)
			# Thorns and Riposte damage the attacker, not the struck unit. Authored
			# Drain heals that same attacker. Use only amounts the rules settled.
			var attacker_key := _live_receipt_key(str(receipt.get("actor", "")))
			for counter in ["thorns", "riposte"]:
				var amount := int(result.get(counter, 0))
				if amount > 0:
					_float_add(events, attacker_key, counter.to_upper() + " -" + str(amount), "damage")
			var drained := int(result.get("drain", 0))
			if drained > 0:
				_float_add(events, attacker_key, "DRAIN +" + str(drained), "heal")
			# A counter that tears the attacker's seam gets the same confirmed callout.
			var attacker_torn: Dictionary = result.get("attacker_tear", {})
			if bool(attacker_torn.get("ok", true)) and not str(attacker_torn.get("slot", "")).is_empty():
				_float_add(events, attacker_key, "SEAM TORN!", "bleed", "status_hanging")
			if bool(result.get("attacker_lost", false)):
				_float_add(events, attacker_key, "LOST!", "kill", "float_kill")
			elif result.has("attacker_heap"):
				_float_add(events, attacker_key, "UNSTITCHED!", "kill", "float_kill")
			elif bool(result.get("attacker_hanging", false)):
				_float_add(events, attacker_key, "HANGING", "bleed", "status_hanging")
		# A dodge uses the existing held MISS label (with its own reaction picture).
	# The battle screen observes settled start-of-turn clocks separately from the
	# attack receipts. It only reports untouched units, never guesses a tick from
	# the damage number on the unit the ability itself just struck.
	for cue in receipt.get("turn_cues", []):
		var on_key := _live_receipt_key(str(cue.get("target", "")))
		if bool(cue.get("lost", false)):
			_float_add(events, on_key, "LOST!", "kill", "float_kill")
		elif bool(cue.get("hanging", false)):
			_float_add(events, on_key, "HANGING", "bleed", "status_hanging")
		var status := str(cue.get("status", ""))
		var amount := int(cue.get("amount", 0))
		if amount > 0 and status in ["bleed", "rot", "regen"]:
			_float_add(events, on_key, status.to_upper() + (" +" if status == "regen" else " -")
				+ str(amount), status, "status_" + status)
		if bool(cue.get("expired", false)) and not status.is_empty():
			_float_add(events, on_key, status.replace("_", " ").to_upper() + " ENDED",
				"cleanse", "status_" + status)
	return events


func _clear_float_words() -> void:
	for tween in _float_tweens:
		if tween != null and tween.is_running():
			tween.kill()
	_float_tweens.clear()
	for group in _float_groups.values():
		if is_instance_valid(group):
			group.queue_free()
	_float_groups.clear()


func _show_float_receipt(receipt: Dictionary) -> void:
	_clear_float_words()
	var events := _float_events(receipt)
	for key in events:
		var cues: Array = events[key]
		var group := Control.new()
		group.name = "Float_" + str(key)
		group.size = Vector2(352, float(cues.size()) * 38.0)
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(group)
		_float_groups[key] = group
		for index in cues.size():
			var cue: Dictionary = cues[index]
			var family := str(cue.family)
			var large := family in ["kill", "crit"]
			var font_size := 36 if family == "kill" else (33 if large else 29)
			var art_name := str(cue.icon)
			var texture: Texture2D = null
			if art_name.begins_with("patch:"):
				var patch_id := art_name.trim_prefix("patch:")
				texture = _texture(SEWN_ART + patch_id + ".png")
				if texture == null:
					texture = _texture("res://assets/paper/stitched/patches/" + patch_id + ".png")
				if texture == null:
					var entry: Dictionary = StitchedS14Abilities.patches().get("by_id", {}).get(patch_id, {})
					texture = _texture(ICONS + "status_" + str(entry.get("effect", "")) + ".png")
			elif not art_name.is_empty():
				texture = _texture(ICONS + art_name + ".png")
			# Both status and stat-arrow pictures are optional. Missing art stays text-only.
			var arrow_name := str(cue.get("arrow", ""))
			var arrow: Texture2D = _texture(ICONS + arrow_name + ".png") if not arrow_name.is_empty() else null
			var width := minf(302.0, FONT.get_string_size(str(cue.words),
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 12.0)
			var start_x := (group.size.x - width - (34.0 if texture != null else 0.0) \
				- (28.0 if arrow != null else 0.0)) / 2.0
			if texture != null:
				var picture := TextureRect.new()
				picture.texture = texture
				picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				picture.position = Vector2(start_x, float(index) * 38.0 + 2.0)
				picture.size = Vector2(32, 32)
				picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
				group.add_child(picture)
				start_x += 34.0
			if arrow != null:
				var direction_icon := TextureRect.new()
				direction_icon.texture = arrow
				direction_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				direction_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				direction_icon.position = Vector2(start_x, float(index) * 38.0 + 4.0)
				direction_icon.size = Vector2(26, 28)
				direction_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				group.add_child(direction_icon)
				start_x += 28.0
			var word := _label(str(cue.words), Rect2(start_x, float(index) * 38.0,
				width, 36.0), font_size, _float_tone(family))
			word.add_theme_constant_override("outline_size", 6)
			word.rotation = -0.035 if index % 2 == 0 else 0.03
			group.add_child(word)
		# Stay present for nearly all of the held strike, then fade without
		# increasing HOLD_TIME or ever holding the next actor's input.
		var fade := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		fade.tween_interval(HOLD_TIME * 0.86)
		fade.tween_property(group, "modulate:a", 0.0, HOLD_TIME * 0.14)
		_float_tweens.append(fade)
	# A final blow can finish before this delayed callback runs. Never put
	# the input shield above the newly visible Continue button.
	_raise_beat_input_layer()


func _raise_beat_input_layer() -> void:
	if battle != null and battle.is_over():
		if _beat_input_shield != null:
			_beat_input_shield.hide()
		if continue_button != null and continue_button.get_parent() == self:
			move_child(continue_button, get_child_count() - 1)
	elif _beat_input_shield != null:
		move_child(_beat_input_shield, get_child_count() - 1)


func _remember_beat_homes(homes: Dictionary) -> void:
	_beat_homes = homes.duplicate(true)


func _play_new_receipts() -> void:
	var fresh := []
	for index in range(_seen_receipts, engine.receipts.size()):
		var entry: Dictionary = engine.receipts[index].duplicate(true)
		if index < engine.turn_cues.size():
			entry["turn_cues"] = engine.turn_cues[index].duplicate(true)
		fresh.append(entry)
	_seen_receipts = engine.receipts.size()
	if engine._motion_is_reduced():
		_cancel_beats()
		# Owner 11-10 reduced motion:the lunges and poses are skipped, but the attack
		# still dims the corridor and brightens the acting pair for the same readable beat.
		if engine._motion_is_reduced() and not battle.is_over():
			_spotlight_without_motion(fresh)
		return
	# Only actual abilities or confirmed tick-only turns earn a held beat.
	# Empty passes, free hand actions and moves never block player input.
	var animated: Array = []
	for entry in fresh:
		if not bool(entry.get("ok", false)):
			continue
		if str(entry.get("action", "")) == "ability" or not _float_events(entry).is_empty():
			animated.append(entry)
	if animated.is_empty():
		return
	# Owner 11-10: a held beat is never cut short. New ability receipts queue
	# behind it, so the next beat starts only after the hold eases back to idle.
	if _beats != null and _beats.is_running():
		_queued_receipts.append_array(animated)
		return
	if stage.fight_focus_active():
		stage.cancel_fight_focus()
	_start_beats(animated)


## Use one occurrence count for the full rolled round, not one per animation batch.
func _receipt_order_index(actor_id: String, rolled_order: Array) -> int:
	if _beat_order_round != battle.round_number():
		_beat_order_round = battle.round_number()
		_beat_order_appearances.clear()
	var seats: Array[int] = []
	for index in rolled_order.size():
		if str(rolled_order[index]) == actor_id:
			seats.append(index)
	if seats.is_empty():
		return -1
	var ordinal := mini(int(_beat_order_appearances.get(actor_id, 0)), seats.size() - 1)
	_beat_order_appearances[actor_id] = int(_beat_order_appearances.get(actor_id, 0)) + 1
	return seats[ordinal]


func _start_beats(batch: Array) -> void:
	_beats = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var rolled_order := battle.turn_order()
	for receipt in batch:
		if not bool(receipt.get("ok", false)):
			continue
		if str(receipt.get("action", "")) != "ability":
			# A pass or forced skip can settle Bleed, Rot, Regen or an expiry.
			# Float only those observed changes, without inventing an attack pose.
			var tick_keys: Array[String] = []
			for tick_key in _float_events(receipt):
				tick_keys.append(str(tick_key))
			if tick_keys.is_empty():
				continue
			var no_flashes: Array[String] = []
			_beats.tween_callback(Callable(stage, "begin_spotlight").bind(tick_keys, no_flashes))
			_beats.tween_callback(Callable(self, "_show_float_receipt").bind(receipt.duplicate(true)))
			_beats.tween_interval(HOLD_TIME)
			_beats.tween_callback(Callable(stage, "end_spotlight"))
			_beats.tween_interval(BEAT_TIME * 0.6)
			_beats.tween_callback(_clear_float_words)
			continue
		var actor_id := str(receipt.get("actor", ""))
		var key := _live_receipt_key(actor_id)
		if key.is_empty():
			continue
		var actor := battle.get_unit(actor_id)
		var figure: Sprite3D = stage.figure_nodes[key]
		var home := figure.position
		var toward := -1.0 if str(actor.side) == "hero" else 1.0
		# A boss's second turn must use its second slot even when another held beat intervenes.
		var held_index := _receipt_order_index(actor_id, rolled_order)
		_beats.tween_callback(Callable(self, "_begin_receipt_focus").bind(receipt.duplicate(true), held_index))
		_beats.tween_callback(Callable(self, "_show_move_name").bind(
			engine._ability_name(actor_id, str(receipt.get("ability", "")))))
		_beats.tween_callback(Callable(self, "_set_receipt_pose").bind(actor_id, str(receipt.get("ability", "")), true))
		_beats.tween_callback(Callable(self, "_throw_and_strike").bind(receipt.duplicate(true)))
		# Owner 11-10 spotlight step: the acting figure and its targets come into the foreground,
		# stepping toward the eye and each other and growing a touch, held with the strike pose.
		var spot := _receipt_spot_keys(receipt)
		var homes := {}
		var steps := {}
		var target_reactions := {}
		for result in receipt.get("results", []):
			var reaction_key := _live_receipt_key(str(result.get("target", "")))
			if not reaction_key.is_empty():
				target_reactions[reaction_key] = _receipt_reaction_kind(receipt, result)
		# Owner 11-10: the pair steps toward each other, but the strike never closes the last
		# SPOT_MIN_GAP of the ranks: a doll lunging at the front foe covers it otherwise.
		var near_gap := INF
		for lit_key in spot.lit:
			if lit_key == key:
				continue
			var other: Sprite3D = stage.figure_nodes.get(lit_key)
			if other == null or not other.visible:
				continue
			near_gap = minf(near_gap, absf(other.position.z - home.z))
		var lunge := LUNGE if near_gap == INF else minf(LUNGE, maxf(0.0, near_gap - SPOT_MIN_GAP))
		for lit_key in spot.lit:
			var lit_figure: Sprite3D = stage.figure_nodes.get(lit_key)
			if lit_figure == null or not lit_figure.visible:
				continue
			var lit_home: Vector3 = lit_figure.position
			homes[lit_key] = lit_home
			var dz := 0.0
			var dy := 0.0
			if lit_key == key:
				dz = toward * lunge
			else:
				var spare := absf(lit_home.z - (home.z + toward * lunge)) - SPOT_MIN_GAP
				dz = signf(home.z - lit_home.z) * clampf(spare, 0.0, LUNGE * 0.5)
				# A struck figure recoils AWAY from the blow, not toward the attacker.
				# Distinct falls/slumps stay legible even before reaction art arrives.
				match str(target_reactions.get(lit_key, "")):
					"heavy":
						dz = toward * 0.28
					"hit":
						dz = toward * 0.11
					"dodge":
						dz = toward * 0.23
					"stun":
						dz = toward * 0.10
						dy = -0.08 # knees buckle and the doll drops
					"shudder":
						dz = toward * 0.07
					"brace":
						dy = 0.07 # helped doll straightens upward
			steps[lit_key] = lit_home + Vector3(SPOT_STEP, dy, dz)
		_beats.tween_callback(Callable(self, "_remember_beat_homes").bind(homes.duplicate(true)))
		var first_step := true
		for lit_key in homes:
			var lit_figure: Sprite3D = stage.figure_nodes[lit_key]
			if first_step:
				_beats.tween_property(lit_figure, "position", steps[lit_key], BEAT_TIME * 0.4) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				first_step = false
			else:
				_beats.parallel().tween_property(lit_figure, "position", steps[lit_key], BEAT_TIME * 0.4) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_beats.parallel().tween_property(lit_figure, "scale", Vector3.ONE * SPOT_GROW, BEAT_TIME * 0.4) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if lit_key != key and target_reactions.has(lit_key):
				var tilt: float = float({"heavy": -0.21, "hit": -0.10, "dodge": 0.16, "stun": -0.29,
					"shudder": 0.12, "brace": -0.10}.get(str(target_reactions[lit_key]), 0.0))
				_beats.parallel().tween_property(lit_figure, "rotation:z", float(tilt), BEAT_TIME * 0.4)
		for result in receipt.get("results", []):
			var target_key := _live_receipt_key(str(result.get("target", "")))
			var struck: Sprite3D = stage.figure_nodes.get(target_key)
			if struck != null and struck != figure and spot.flash.has(target_key):
				_beats.parallel().tween_property(struck, "modulate", Color(1.8, 0.55, 0.5), BEAT_TIME * 0.3)
		# Change the target's painted reaction at impact, then hold that silhouette.
		_beats.tween_callback(Callable(self, "_apply_target_reactions").bind(receipt.duplicate(true)))
		_beats.tween_interval(HOLD_TIME)
		# Owner 11-10: the spotlight eases back together with the figures' return to rank.
		_beats.tween_callback(Callable(stage, "end_spotlight"))
		var first_return := true
		for lit_key in homes:
			var lit_figure: Sprite3D = stage.figure_nodes[lit_key]
			if first_return:
				_beats.tween_property(lit_figure, "position", homes[lit_key], BEAT_TIME * 0.6).set_trans(Tween.TRANS_SINE)
				first_return = false
			else:
				_beats.parallel().tween_property(lit_figure, "position", homes[lit_key], BEAT_TIME * 0.6).set_trans(Tween.TRANS_SINE)
			_beats.parallel().tween_property(lit_figure, "scale", Vector3.ONE, BEAT_TIME * 0.6).set_trans(Tween.TRANS_SINE)
			_beats.parallel().tween_property(lit_figure, "rotation:z", 0.0, BEAT_TIME * 0.6).set_trans(Tween.TRANS_SINE)
		_beats.tween_interval(0.08)
		_beats.tween_callback(_clear_target_reactions)
		_beats.tween_callback(Callable(self, "_set_receipt_pose").bind(actor_id, str(receipt.get("ability", "")), false))
	_beats.tween_callback(Callable(self, "_show_move_name").bind(""))
	_beats.tween_callback(_shade_figures)
	_beats.finished.connect(_drain_queued_beats)


## The whole batch eased back to idle; any receipts that queued behind its holds play now.
func _drain_queued_beats() -> void:
	_beats = null
	_beat_homes.clear()
	_held_actor_id = ""
	_held_actor_index = -1
	if not is_inside_tree()or battle == null or engine == null:
		return
	# Catch up any rank, death or idle art changes deferred during the held beat.
	refresh()
	if engine._motion_is_reduced() or _queued_receipts.is_empty():
		return
	var next := _queued_receipts.duplicate()
	_queued_receipts.clear()
	_start_beats(next)


## Owner 11-10 reduced motion: no lunges, no poses; the newest striking receipt still
## plays its spotlight so the read stays slow, heavy and clear.
func _spotlight_without_motion(fresh: Array) -> void:
	for index in range(fresh.size() - 1, -1, -1):
		var receipt: Dictionary = fresh[index]
		if not bool(receipt.get("ok", false)) or str(receipt.get("action", "")) != "ability":
			continue
		var spot := _receipt_spot_keys(receipt)
		if not spot.lit.is_empty():
			stage.spot_pulse(spot.lit, [], HOLD_TIME)
		return


## Owner 11-09: a thrown thing (scrap bomb, lint, needle...) leaves the hand and flies to each target as
## its own picture, then the hit effect (stuffing, felt, blood...) bursts there. With nothing thrown the
## effect bursts as the lunge lands; a guard or heal shows on whoever it reaches, the user included.
func _throw_and_strike(receipt: Dictionary) -> void:
	var actor_id := str(receipt.get("actor", ""))
	var key := _live_receipt_key(actor_id)
	if key.is_empty():
		return
	var art := StitchedBattleScreen.ability_fx(str(receipt.get("ability", "")))
	var thrown := _texture(str(art.get("object", ""))) if art.has("object") else null
	var burst := _texture(str(art.get("fx", ""))) if art.has("fx") else null
	if thrown == null and burst == null:
		return
	var figure: Sprite3D = stage.figure_nodes[key]
	var foe := str(battle.get_unit(actor_id).get("side", "")) != "hero"
	var flight := BEAT_TIME * 0.4
	for result in receipt.get("results", []):
		var struck: Sprite3D = stage.figure_nodes.get(_live_receipt_key(str(result.get("target", ""))))
		if struck == null:
			continue
		var delay := 0.0
		if struck != figure:
			delay = BEAT_TIME * 0.3
			if thrown != null:
				var piece := _fly_sprite(thrown, figure.position, _figure_height(figure) * 0.3, foe)
				var path := piece.create_tween()
				path.tween_property(piece, "position", struck.position, flight).set_trans(Tween.TRANS_SINE)
				path.tween_callback(_drop_flying.bind(piece))
				delay = flight
		if burst == null or not bool(result.get("hit", true)):
			continue
		var puff := _fly_sprite(burst, struck.position, _figure_height(struck) * 0.7, foe)
		puff.visible = false
		puff.scale = Vector3.ONE * 0.6
		var bloom := puff.create_tween()
		bloom.tween_interval(delay)
		bloom.tween_callback(puff.show)
		bloom.tween_property(puff, "scale", Vector3.ONE * 1.15, BEAT_TIME * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bloom.parallel().tween_property(puff, "modulate:a", 0.0, BEAT_TIME * 0.45).set_delay(BEAT_TIME * 0.15)
		bloom.tween_callback(_drop_flying.bind(puff))


func _figure_height(figure: Sprite3D) -> float:
	return stage.placed_size(figure).y


## One picture in flight, drawn over the dolls; pictures are drawn facing right, so a foe's are flipped.
func _fly_sprite(texture: Texture2D, where: Vector3, size: float, flip: bool) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = "Flying"
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.render_priority = 3
	sprite.flip_h = flip
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.pixel_size = size / float(maxi(texture.get_width(), texture.get_height()))
	sprite.position = where
	stage.figures.get_parent().add_child(sprite)
	_flying.append(sprite)
	return sprite


func _drop_flying(sprite: Sprite3D) -> void:
	_flying.erase(sprite)
	sprite.queue_free()


func _clear_flying() -> void:
	for sprite in _flying:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_flying.clear()


func _show_move_name(move_name: String) -> void:
	move_banner.text = move_name
	move_banner.visible = not move_name.is_empty()


## "Moves: Hook Drag, Peck" - the unit's moveset, for its hover.
func _moveset(unit: Dictionary) -> String:
	var names := PackedStringArray()
	for ability in unit.get("abilities", []):
		names.append(str(ability.get("name", "")))
	for slot in StitchedBattleScreen.SLOTS:
		if battle._s14:
			break
		var worn: Dictionary = unit.get("parts", {}).get(slot, {})
		var part: Dictionary = engine.parts.get(str(worn.get("id", "")), {})
		if not part.is_empty():
			names.append(str(StitchedParts.ability_at_tier(part, int(worn.get("tier", 1))).get("name", "")))
	return "Moves: " + ", ".join(names) if not names.is_empty() else ""


func _unhandled_key_input(event: InputEvent) -> void:
	if _beat_input_shield.visible or not event is InputEventKey or not event.pressed or event.echo:
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
