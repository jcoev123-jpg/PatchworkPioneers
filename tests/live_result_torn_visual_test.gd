extends SceneTree
## Independent headless scene test of the mounted torn-hero presentation on
## the live result panel: readable TORN badge (>=18 px), muted portrait,
## unchanged text, clean remount, and decorative mouse/focus settings.

const PANEL_SCENE := "res://scenes/run_terminal_result_panel.tscn"

var panel: LiveRunTerminalResultPanel
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load(PANEL_SCENE) as PackedScene
	panel = scene.instantiate() as LiveRunTerminalResultPanel
	_check(panel != null, "AC3: result panel scene instantiates")
	if panel == null:
		print("live_result_torn_visual_test: FAIL (panel null)")
		quit(1)
	root.add_child(panel)
	panel.visible = true
	await _frames()

	# AC1: validated three-hero recap with Warden at 0 HP (torn).
	var torn_warden: Dictionary = {
		"hero_id": "warden",
		"name": "Warden",
		"detail": "0/10 HP · 2 tears · no patches",
		"is_torn": true,
	}
	var living_seamstress: Dictionary = {
		"hero_id": "seamstress",
		"name": "Seamstress",
		"detail": "30/30 HP · 0 tears · HEAD Button Eye",
		"is_torn": false,
	}
	var living_tinker: Dictionary = {
		"hero_id": "tinker",
		"name": "Tinker",
		"detail": "26/26 HP · 0 tears · COAT Quilted Coat",
		"is_torn": false,
	}
	panel._mount_hero_rows([torn_warden, living_seamstress, living_tinker])
	await _frames()

	# Badge inspection: exactly one TORN badge, >=18 px, PatchHeading.
	var warden_row: Control = panel.hero_rows.get_child(0) as Control
	_check(warden_row != null, "AC1: torn Warden row mounted")
	var badge: Label = warden_row.get_node_or_null("RowInset/RowLine/TornBadge") as Label
	_check(badge != null, "AC1: torn badge node present")
	if badge != null:
		_check(badge.text == "TORN", "AC1: badge text is exactly TORN")
		_check(badge.theme_type_variation == "PatchHeading",
			"AC1: badge uses PatchHeading face")
		var font_size := badge.get_theme_font_size("font_size")
		_check(font_size >= 18, "AC1: badge font >= 18 px (got %d)" % font_size)
		_check(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"AC3: badge ignores mouse input")
		_check(badge.focus_mode == Control.FOCUS_NONE,
			"AC3: badge ignores keyboard focus")
		var style_normal := badge.get_theme_stylebox("normal") as StyleBoxFlat
		_check(style_normal != null, "AC1: badge has sewn stylebox")

	# Portrait inspection: visibly muted for torn hero.
	var portrait: TextureRect = warden_row.get_node_or_null("RowInset/HeroPortrait") as TextureRect
	_check(portrait != null, "AC1: torn Warden portrait node present")
	if portrait != null:
		_check(portrait.modulate.is_equal_approx(Color(0.6, 0.6, 0.62, 1.0)),
			"AC1: torn portrait is grey-muted")
		_check(portrait.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"AC3: portrait ignores mouse input")

	# Unchanged authentic row text.
	var detail_label: Label = warden_row.get_node("RowInset/RowLine/HeroDetail") as Label
	_check(detail_label != null and detail_label.text == torn_warden.detail,
		"AC1: torn hero detail text unchanged")

	# AC2: living heroes have no badge and normal portrait tint.
	var seamstress_row: Control = panel.hero_rows.get_child(1) as Control
	_check(seamstress_row.get_node_or_null("RowInset/RowLine/TornBadge") == null,
		"AC2: living Seamstress has no TORN badge")
	var s_portrait: TextureRect = seamstress_row.get_node_or_null("RowInset/HeroPortrait") as TextureRect
	_check(s_portrait != null and s_portrait.modulate.is_equal_approx(Color.WHITE),
		"AC2: living portrait is normal white tint")

	var tinker_row: Control = panel.hero_rows.get_child(2) as Control
	_check(tinker_row.get_node_or_null("RowInset/RowLine/TornBadge") == null,
		"AC2: living Tinker has no TORN badge")

	# Clean torn-to-living remount: no old tint or badge survives.
	panel._clear_hero_rows()
	await _frames()
	var warden_living: Dictionary = {
		"hero_id": "warden",
		"name": "Warden",
		"detail": "40/40 HP · 0 tears · no patches",
		"is_torn": false,
	}
	panel._mount_hero_rows([warden_living, living_seamstress, living_tinker])
	await _frames()

	var remounted_warden: Control = panel.hero_rows.get_child(0) as Control
	_check(remounted_warden.get_node_or_null("RowInset/RowLine/TornBadge") == null,
		"AC2: remounted Warden has no leftover TORN badge")
	var remounted_portrait: TextureRect = remounted_warden.get_node_or_null("RowInset/HeroPortrait") as TextureRect
	_check(remounted_portrait != null and remounted_portrait.modulate.is_equal_approx(Color.WHITE),
		"AC2: remounted portrait has no leftover grey tint")
	_check(panel.find_children("TornBadge", "", true, false).is_empty(),
		"AC2: zero TornBadge nodes survive remount")

	# AC3: styling remains view-only; Return control untouched by presentation.
	_check(panel.return_button != null, "AC3: Return button exists")
	_check(panel.get_node_or_null("PaperPanel/ContentMargin/ResultContent/ReturnButton") == panel.return_button,
		"AC3: Return button path unchanged")
	_check(panel.return_button.mouse_filter == Control.MOUSE_FILTER_STOP,
		"AC3: Return mouse filter unchanged")
	_check(panel.return_button.get_theme_stylebox("normal") != null,
		"AC3: Return stylebox preserved")

	panel.close_result()
	await _frames()
	_check(not panel.has_open_result(), "AC3: close leaves no open result")
	_check(panel.hero_rows.get_child_count() == 0, "AC3: hero rows cleared on close")

	print("live_result_torn_visual_test: ",
		"PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	for failure in failures:
		printerr("  - ", failure)
	quit(0 if failures.is_empty() else 1)
