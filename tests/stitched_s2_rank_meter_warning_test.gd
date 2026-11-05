extends SceneTree
## Detached sewn rank-meter contract. Does not instantiate the reserved battle screen.

const FRAME := preload("res://assets/paper/ui/hud_bar_frame.png")
const PLATE := preload("res://assets/paper/ui/hud_name_plate.png")
const FILL := preload("res://assets/paper/ui/reward_button.png")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _present(meters: Dictionary, unit: Dictionary, side: String) -> void:
	var before := unit.duplicate(true)
	StitchedBattleChrome.present_rank(meters, unit, side)
	_check(unit == before, "%s unit snapshot is not modified by presentation" % side)


func _fit(label: Label, note: String) -> void:
	var face: Font = label.get_theme_font("font")
	var size_used := label.get_theme_font_size("font_size")
	_check(face != null and size_used >= 8 and size_used <= 11, note + " inherits and sizes the Gothic font")
	if face != null:
		var width := face.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_used).x
		_check(width <= label.size.x - 1.0, "%s: measured text %.1f fits %.1f px" % [note, width, label.size.x])


func _bounds(meters: Dictionary, note: String) -> void:
	var surface: Control = meters["root"]
	_check(surface.size == Vector2(170, 24), note + " retains the 170x24 rank envelope")
	for child in surface.get_children():
		if child is Control:
			var control := child as Control
			_check(control.position.x >= 0.0 and control.position.y >= 0.0
				and control.position.x + control.size.x * control.scale.x <= 170.0
				and control.position.y + control.size.y * control.scale.y <= 24.0,
				"%s %s fits rank envelope: pos=%s size=%s" % [note, control.name, control.position, control.size])


func _run() -> void:
	var gothic: Theme = load("res://themes/gothic_theme.tres")
	_check(gothic != null and gothic.default_font != null, "real Gothic Theme and font load")
	if gothic == null:
		_finish()
		return
	var host := Control.new()
	host.size = Vector2(700, 570)
	host.theme = gothic
	root.add_child(host)
	var hero := StitchedBattleChrome.make_rank_meters(host, "hero", 28.0)
	var foe := StitchedBattleChrome.make_rank_meters(host, "foe", 300.0)
	await process_frame
	var hero_root: Control = hero["root"]
	var hp: ProgressBar = hero["hp"]
	var fray: ProgressBar = hero["fray"]
	var hp_label: Label = hero["hp_text"]
	var fray_label: Label = hero["fray_text"]
	var hp_frame := hero_root.get_node_or_null("HPFillSewnFrame") as NinePatchRect
	var fray_frame := hero_root.get_node_or_null("FrayFillSewnFrame") as NinePatchRect
	_check(hero_root.is_inside_tree() and foe["root"].is_inside_tree()
		and hp_frame != null and fray_frame != null and hp_label != null and fray_label != null,
		"precondition: real mounted Control widgets and authored bar frames exist")
	if hp_frame == null or fray_frame == null or hp_label == null or fray_label == null:
		host.free()
		_finish()
		return
	_bounds(hero, "hero")
	_bounds(foe, "foe")
	_check(hp_frame.texture == FRAME and fray_frame.texture == FRAME
		and foe["root"].get_node("HPFillSewnFrame").texture == FRAME,
		"hero and foe retain existing authored nine-slice bar frames")
	for bar in [hp, fray, foe["hp"]]:
		var background := bar.get_theme_stylebox("background") as StyleBoxTexture
		var fill := bar.get_theme_stylebox("fill") as StyleBoxTexture
		_check(background != null and background.texture == PLATE
			and fill != null and fill.texture == FILL,
			"meter underlay and fill use original nine-slice image resources")
	_check(not foe.has("fray") and not foe["root"].has_node("FrayFill"),
		"foe surface has only an HP meter")

	var unit := {"id": "hero_alpha", "rank": 1, "hp": 12, "max_hp": 17,
		"fray": 45, "hanging": false, "lost": false}
	var opponent := {"id": "foe_beta", "rank": 1, "hp": 9, "max_hp": 21}
	# Prove that even the global seeded RNG stream is not drawn by any render.
	seed(671982)
	var expected_random := randi()
	seed(671982)
	_present(hero, unit, "hero")
	_present(foe, opponent, "foe")
	_check(hero_root.visible and foe["root"].visible
		and hp.value == 12.0 and hp.max_value == 17.0
		and fray.value == 45.0 and fray.max_value == 200.0
		and foe["hp"].value == 9.0 and foe["hp"].max_value == 21.0,
		"authentic snapshots present exact HP and FRAY values and denominators")
	_check(hp_label.text == "HP 12/17" and fray_label.text == "FRAY 45/200"
		and foe["hp_text"].text == "HP 9/21",
		"both sides visibly show their exact meter numerators/denominators")
	_check(hp.tooltip_text == "HP 12/17" and fray.tooltip_text.begins_with("FRAY 45/200")
		and hero_root.tooltip_text.contains("HP 12/17")
		and hero_root.tooltip_text.contains("FRAY 45/200"),
		"mouse-accessible stitched surface exposes both full values")
	_check(hero_root.mouse_filter == Control.MOUSE_FILTER_PASS,
		"full-value tooltip surface accepts hover")
	_fit(hp_label, "normal HP")
	_fit(fray_label, "normal FRAY")
	_fit(foe["hp_text"], "foe HP")

	var base_fill := (fray.get_theme_stylebox("fill") as StyleBoxTexture).modulate_color
	var base_frame := fray_frame.self_modulate
	for sample in [0, 45, 99, 100, 150, 199]:
		unit["fray"] = sample
		_present(hero, unit, "hero")
		_check(fray.value == float(sample) and fray.max_value == 200.0
			and fray_label.text == "FRAY %d/200" % sample,
			"FRAY %d uses the exact 200-point fill and caption" % sample)
		_check(fray.tooltip_text.begins_with("FRAY %d/200" % sample)
			and fray.tooltip_text.contains("100 FRAY: resolve threshold")
			and fray.tooltip_text.contains("200 FRAY: COMES APART")
			and fray.tooltip_text.contains("STEADFAST or UNRAVELLED"),
			"FRAY %d describes risk thresholds without resolving a roll" % sample)
		var sample_style := fray.get_theme_stylebox("fill") as StyleBoxTexture
		_check(sample_style != null and sample_style.texture == FILL
			and (sample_style.modulate_color != base_fill) == (sample >= 100)
			and (fray_frame.self_modulate != base_frame) == (sample >= 100),
			"FRAY %d warning is distinct at 100+ but reverts below 100" % sample)
		_check((fray_label.get_theme_color("font_color") == StitchedBattleChrome.AMBER) == (sample >= 100),
			"FRAY %d uses the correct sewn danger caption treatment" % sample)
		_fit(fray_label, "FRAY %d" % sample)
	unit["fray"] = 45
	_present(hero, unit, "hero")
	_check(fray_frame.self_modulate == base_frame
		and (fray.get_theme_stylebox("fill") as StyleBoxTexture).modulate_color == base_fill
		and fray_label.get_theme_color("font_color") == StitchedBattleChrome.BONE,
		"decreased FRAY clears all warning styling")

	unit["hp"] = 0
	unit["hanging"] = true
	unit["fray"] = 150
	_present(hero, unit, "hero")
	_check(hero_root.visible and hp.value == 0.0 and hp.max_value == 17.0
		and hp_label.text == "HANGING"
		and hp.tooltip_text.contains("HP 0/17")
		and hp.tooltip_text.contains("HANGING BY A THREAD")
		and hp_frame.self_modulate != Color.WHITE,
		"real hanging flag signals HANGING without fabricating HP")
	_fit(hp_label, "HANGING")
	unit["hanging"] = false
	_present(hero, unit, "hero")
	_check(hp.value == 0.0 and hp_label.text == "HP 0/17"
		and not hp.tooltip_text.contains("HANGING")
		and hp_frame.self_modulate == Color.WHITE,
		"zero HP alone does not assert HANGING")
	unit["lost"] = true
	_present(hero, unit, "hero")
	_check(not hero_root.visible and hp.value == 0.0 and fray.value == 0.0
		and hp_label.text.is_empty() and fray_label.text.is_empty()
		and hp.tooltip_text.is_empty() and fray.tooltip_text.is_empty()
		and hero_root.tooltip_text.is_empty()
		and hp_frame.self_modulate == Color.WHITE
		and fray_frame.self_modulate == Color.WHITE,
		"LOST clears all bar, caption, tooltip and warning ghosts")
	_present(hero, {}, "hero")
	_check(not hero_root.visible and hp_label.text.is_empty() and hero_root.tooltip_text.is_empty(),
		"empty rank also clears warning and accessibility state")
	unit["lost"] = false
	unit["hp"] = 9
	unit["fray"] = 0
	_present(hero, unit, "hero")
	_check(hero_root.visible and hp.value == 9.0 and fray.value == 0.0
		and hp_label.text == "HP 9/17" and fray_label.text == "FRAY 0/200"
		and hp_frame.self_modulate == Color.WHITE
		and fray_frame.self_modulate == Color.WHITE,
		"restored living hero has clean healthy styles")
	unit["hp"] = 0
	unit["hanging"] = true
	unit["fray"] = 200
	_present(hero, unit, "hero")
	_check(hero_root.visible and hp.value == 0.0 and fray.value == 200.0
		and hp_label.text == "HANGING" and fray.tooltip_text.contains("COMES APART"),
		"200 FRAY displays authoritative supplied hanging outcome, not a simulated LOST")
	_check(randi() == expected_random, "rendering never changes the global RNG stream")
	_check(hero_root.get_signal_connection_list("gui_input").is_empty(),
		"meter chrome connects no battle actions or receipts")
	host.free()
	await process_frame
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s2_rank_meter_warning_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
