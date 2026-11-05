class_name StitchedCandleMeter
extends Control
## One read-only projection of the mounted StitchedRules candle and its supplied band.
## The texture fill, tooltip and focus disclosure never contact battle state or RNG.

const BAR_PATH := "res://assets/paper/ui/hud_bar_frame.png"
const PLATE_PATH := "res://assets/paper/ui/hud_name_plate.png"
const THEME_PATH := "res://themes/gothic_theme.tres"
const BONE := Color("e9ddc7")
const AMBER := Color("e6ad58")
const DIMMED := Color("766b67")

var value := -1
var band_name := ""
var band_effects: Dictionary = {}
var fill: TextureProgressBar
var info: NinePatchRect
var disclosure: NinePatchRect
var disclosure_label: Label
var headline: Label
var _hovered := false
var _focused := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	# Inherit the mounted application's Gothic Theme (keep theme == null).
	_build()
	clear_readout()


func _build() -> void:
	var frame: Texture2D = load(BAR_PATH)
	fill = TextureProgressBar.new()
	fill.name = "CandleFill"
	fill.position = Vector2(0, 1)
	fill.size = Vector2(301, 30)
	fill.min_value = 0
	fill.max_value = 100
	fill.step = 1
	fill.value = 0
	fill.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	fill.texture_under = frame
	fill.texture_progress = frame
	fill.nine_patch_stretch = true
	fill.stretch_margin_left = 12
	fill.stretch_margin_right = 12
	fill.stretch_margin_top = 9
	fill.stretch_margin_bottom = 9
	fill.tint_under = Color("4f4448")
	fill.tint_progress = AMBER
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)

	headline = Label.new()
	headline.name = "CandleReadout"
	headline.position = Vector2(16, 1)
	headline.size = Vector2(270, 29)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	headline.add_theme_font_size_override("font_size", 16)
	headline.add_theme_color_override("font_color", BONE)
	headline.add_theme_color_override("font_shadow_color", Color("120e0d"))
	headline.add_theme_constant_override("shadow_offset_x", 1)
	headline.add_theme_constant_override("shadow_offset_y", 1)
	headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(headline)

	info = NinePatchRect.new()
	info.name = "CandleInfo"
	info.position = Vector2(305, 1)
	info.size = Vector2(35, 30)
	info.texture = load(PLATE_PATH)
	info.patch_margin_left = 8
	info.patch_margin_right = 8
	info.patch_margin_top = 8
	info.patch_margin_bottom = 8
	info.mouse_filter = Control.MOUSE_FILTER_STOP
	info.focus_mode = Control.FOCUS_ALL
	add_child(info)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "?"
	hint.position = Vector2(0, 0)
	hint.size = info.size
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color("352126"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(hint)

	# The left-hand underside of the title is empty; this does not cover the
	# turn ribbon, central stage, foe intents or any of the action tray.
	disclosure = NinePatchRect.new()
	disclosure.name = "CandleDisclosure"
	disclosure.position = Vector2(-625, 36)
	disclosure.size = Vector2(420, 44)
	disclosure.texture = load(PLATE_PATH)
	disclosure.patch_margin_left = 9
	disclosure.patch_margin_right = 9
	disclosure.patch_margin_top = 9
	disclosure.patch_margin_bottom = 9
	disclosure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(disclosure)

	disclosure_label = Label.new()
	disclosure_label.name = "CandleEffects"
	disclosure_label.position = Vector2(12, 2)
	disclosure_label.size = Vector2(396, 40)
	disclosure_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disclosure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	disclosure_label.add_theme_font_size_override("font_size", 12)
	disclosure_label.add_theme_color_override("font_color", Color("352126"))
	disclosure_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disclosure.add_child(disclosure_label)

	info.mouse_entered.connect(_on_hover.bind(true))
	info.mouse_exited.connect(_on_hover.bind(false))
	info.focus_entered.connect(_on_focus.bind(true))
	info.focus_exited.connect(_on_focus.bind(false))


func set_readout(amount: int, band: Dictionary) -> void:
	if amount < 0 or amount > 100 or band.is_empty() or str(band.get("name", "")).is_empty():
		clear_readout()
		return
	value = amount
	band_name = str(band["name"])
	band_effects = band.duplicate(true)
	fill.value = amount
	headline.text = "CANDLE  %d / 100  ·  %s" % [amount, band_name.to_upper()]
	var explanation := _explanation()
	tooltip_text = explanation
	info.tooltip_text = explanation
	disclosure_label.text = _short_explanation()
	visible = true
	_update_disclosure()


func clear_readout() -> void:
	value = -1
	band_name = ""
	band_effects.clear()
	if fill != null:
		fill.value = 0
	if headline != null:
		headline.text = ""
	if info != null:
		info.tooltip_text = ""
	if disclosure_label != null:
		disclosure_label.text = ""
	tooltip_text = ""
	visible = false
	if disclosure != null:
		disclosure.visible = false


func _opening_text() -> String:
	var side := str(band_effects.get("opening_side", ""))
	var chance := int(band_effects.get("opening_percent", 0))
	if side == "hero" and chance > 0:
		return "%d%% chance the party strikes first (not guaranteed)" % chance
	if side == "foe" and chance > 0:
		return "%d%% chance foes strike first (not guaranteed)" % chance
	return "No extra first-strike chance from this band"


func _explanation() -> String:
	return ("%s  ·  Candle %d–%d\n" % [
		band_name.to_upper(), int(band_effects.get("minimum", 0)),
		int(band_effects.get("maximum", 0))] +
		"Fray gained: +%d%% (rounded up)\n" % int(band_effects.get("fray_percent", 0)) +
		"Foe accuracy: +%d ACC\n" % int(band_effects.get("enemy_acc", 0)) +
		"Foe damage: +%d%% (rounded up)\n" % int(band_effects.get("enemy_damage_percent", 0)) +
		"Loot: +%d%%\n" % int(band_effects.get("loot_percent", 0)) +
		"Opening: " + _opening_text())


func _short_explanation() -> String:
	return ("%s (%d–%d) · Fray +%d%% · Loot +%d%%\n" %
		[band_name.to_upper(), int(band_effects.get("minimum", 0)),
		int(band_effects.get("maximum", 0)), int(band_effects.get("fray_percent", 0)),
		int(band_effects.get("loot_percent", 0))] +
		"Foes +%d ACC, +%d%% damage · %s" %
		[int(band_effects.get("enemy_acc", 0)),
		int(band_effects.get("enemy_damage_percent", 0)), _opening_text()])


func _on_hover(entered: bool) -> void:
	_hovered = entered
	_update_disclosure()


func _on_focus(entered: bool) -> void:
	_focused = entered
	_update_disclosure()


func _update_disclosure() -> void:
	if disclosure == null or info == null:
		return
	disclosure.visible = value >= 0 and (_hovered or _focused)
	info.modulate = Color.WHITE if not (_hovered or _focused) else AMBER
