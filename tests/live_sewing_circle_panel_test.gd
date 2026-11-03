extends SceneTree

const STRIKE := "warden_strike"
const PRICK := "seamstress_prick"
## The one seed this mounted session uses for its global-RNG purity check.
const RNG_SEED := 264
var failures: Array[String] = []
var checks := 0
var intents: Array[Dictionary] = []
var panel: LiveSewingCirclePanel

## The view never calls this controller. Submission is explicitly separate.
class Controller:
	static func submit(visit: RunSewingCircleVisit, intent: Dictionary) -> Dictionary:
		var source: Dictionary = intent.source_snapshot
		match intent.action:
			"upgrade": return visit.choose_upgrade(intent.first_index, intent.visit_id, intent.node_id, source)
			"stitch": return visit.choose_stitch(intent.first_index, intent.second_index, intent.visit_id, intent.node_id, source)
			"leave": return visit.leave(intent.visit_id, intent.node_id, source)
		return {"ok": false}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _make(deck: Array = [STRIKE, STRIKE, PRICK], scraps: int = 7) -> RunSewingCircleVisit:
	return RunSewingCircleVisit.new("circle-264", deck, {}, scraps, 1)


func _settle_layout() -> void:
	for i in range(4):
		await process_frame


func _activate(button: Button, keyboard: bool) -> void:
	_check(button != null and button.is_visible_in_tree() and not button.disabled, "real enabled mounted action")
	if keyboard:
		button.grab_focus()
		_check(button.has_focus(), "keyboard action has focus")
		for down in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.pressed = down
			root.push_input(event)
			await process_frame
	else:
		if panel.choices.is_ancestor_of(button):
			panel.choice_scroll.ensure_control_visible(button)
			await _settle_layout()
			_check(panel.choice_scroll.get_global_rect().has_point(button.get_global_rect().get_center()),
				"mouse target center is genuinely inside the clipped scroll")
		var point := button.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion)
		for down in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = point
			event.pressed = down
			root.push_input(event)
			await process_frame
	await _settle_layout()


## A genuine physical key press pushed through the mounted SceneTree, exactly as
## a player's keyboard would: no direct callback calls and no view-side service.
func _key(keycode: int, pressed: bool = true, echo: bool = false,
		modified: Dictionary = {}) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	event.echo = echo
	event.ctrl_pressed = modified.get("ctrl", false)
	event.alt_pressed = modified.get("alt", false)
	event.shift_pressed = modified.get("shift", false)
	event.meta_pressed = modified.get("meta", false)
	root.push_input(event)
	await _settle_layout()


func _bind(visit: RunSewingCircleVisit) -> void:
	intents.clear()
	panel.bind(visit)
	await _settle_layout()
	_check(visit.is_valid() and not visit.is_consumed(), "authentic open visit prerequisite")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	panel = LiveSewingCirclePanel.new()
	panel.position = Vector2(170, 50)
	panel.bind(_make()) # Binding before mounting is supported.
	root.add_child(panel)
	panel.intent_requested.connect(func(intent: Dictionary): intents.append(intent))
	await _settle_layout()
	_check(panel.upgrade_button.has_focus(), "mount makes the first primary action the keyboard stop")
	# Cosmetic mounts are done: from here the panel may only present state, so a
	# seeded global RNG must read the same after every browse and decision.
	seed(RNG_SEED)
	var seeded_next := randi()
	seed(RNG_SEED)
	await _test_layout()
	await _test_long_authored_upgrade()
	await _test_dark_style()
	await _test_owner_filters()
	_check(panel._effects({"z_other": 9, "bleed": 2, "damage": 3, "a_other": 4})
		== "Deal 3 damage; apply Bleed 2; a other: 4; z other: 9",
		"mixed known and unknown fields preserve values in deterministic reading order")
	_check(panel._effects({"draw": 1, "weak": 1, "heal": 5, "block": 7})
		== "Gain 7 Block; heal 5 HP; apply Weak 1; draw 1 card"
		and panel._effects({}) == "No effects",
		"authored non-damage effects are readable and an empty source stays neutral")
	for keyboard in [false, true]:
		await _test_upgrade(keyboard)
		await _test_stitch(keyboard)
		await _test_pool_upgrade(keyboard)
		await _test_pool_stitch(keyboard)
		await _test_leave(keyboard)
	await _test_shortcuts()
	await _test_confirmation_handoff()
	await _test_rejections()
	await _test_art_motion()
	_check(randi() == seeded_next, "mounted browsing and decisions consume no global RNG")
	panel.queue_free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("live_sewing_circle_panel_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Find a real eligible base with the widest authored upgraded caption; do
## not rely on a fixture-only invented name or a fixed catalog count/order.
func _test_long_authored_upgrade() -> void:
	var longest: Dictionary = {}
	var longest_width := -1.0
	var label_font := panel.status_label.get_theme_font("font")
	for candidate in RunPoolCardRewardOffers.get_authored_base_candidates():
		var id: String = str(candidate.get("id", ""))
		var listed := RunRestCardUpgrade.list_authored_choices([id], {}, 1)
		if not listed.get("ok", false) or listed.choices.size() != 1:
			continue
		var option: Dictionary = listed.choices[0]
		var caption := "Free upgrade: %s | %d energy" % [option.plus_display_name, option.plus_cost]
		var width := label_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		if width > longest_width:
			longest_width = width
			longest = option
	_check(not longest.is_empty() and longest_width > 0.0,
		"nonvacuous longest authentic authored + printing found in live catalog")
	if longest.is_empty():
		return
	var visit := _make([longest.source_id, STRIKE], 3)
	await _bind(visit)
	var source := visit.read_state()
	await _activate(panel.upgrade_button, false)
	var row := _row_at(0)
	if row == null:
		return
	_check(panel.option_buttons.size() == visit.upgrade_options().size()
		and row.get_meta("option") == longest and row.text.contains(longest.display_name),
		"long-name row is the actual mounted source-authentic upgrade option")
	row.grab_focus()
	await _settle_layout()
	panel.choice_scroll.ensure_control_visible(row)
	await _settle_layout()
	_check(panel.choice_scroll.get_global_rect().encloses(row.get_global_rect()),
		"focused longest actual + printing stays completely visible in 350px scroller")
	_assert_visible_action(row, longest, true)
	await _activate(row, false)
	_check(panel.preview().index == 0 and panel.preview_label.text.contains(longest.plus_display_name)
		and intents.is_empty() and visit.read_state() == source,
		"longest authentic upgrade name is mouse-selectable without settlement")
func _test_layout() -> void:
	var deck: Array = []
	for i in range(30):
		deck.append(STRIKE if i % 2 == 0 else PRICK)
	var visit := _make(deck)
	await _bind(visit)
	var source := visit.read_state()
	var viewport := Rect2(0, 0, 1280, 720)
	for control in [panel, panel.upgrade_button, panel.stitch_button, panel.leave_button, panel.confirm_button, panel.choice_scroll, panel.preview_scroll, panel.status_label]:
		_check(viewport.encloses(control.get_global_rect()), "panel/action/scroll fits viewport")
	# Exactly the visit's three canonical decisions are primary actions; every
	# further button belongs to the scrollable occurrence list.
	var primaries: Array[Button] = []
	for child in panel.get_children():
		if child is Button and child != panel.confirm_button:
			primaries.append(child)
	_check(visit.quote().choices == ["upgrade", "stitch", "leave"], "authentic three canonical decisions")
	_check(primaries == [panel.upgrade_button, panel.stitch_button, panel.leave_button], "exactly three primary actions")
	_check(not panel.upgrade_button.disabled and not panel.stitch_button.disabled and not panel.leave_button.disabled,
		"all three actions are live on a genuine open visit")
	_check(panel.status_label.text.contains("3 scraps") and panel.upgrade_button.text.contains("free")
		and panel.stitch_button.text.contains("3 scraps") and panel.leave_button.text.contains("free"), "visible canonical costs")
	# The shortcut mapping is printed on the same four existing actions, and each
	# caption still fits its sewn button at 1280x720.
	_check(panel.upgrade_button.text.contains("1 ") and panel.upgrade_button.text.contains("Upgrade")
		and panel.stitch_button.text.contains("2 ") and panel.stitch_button.text.contains("Stitch")
		and panel.leave_button.text.contains("0 ") and panel.leave_button.text.contains("Leave")
		and panel.confirm_button.text.contains("3 ") and panel.confirm_button.text.contains("Confirm"),
		"number-key mapping is printed on the four existing actions")
	for action in [panel.upgrade_button, panel.stitch_button, panel.leave_button, panel.confirm_button]:
		_check(_fits(action), "shortcut caption fits its existing button at 1280x720")
	# State-to-face contrast is checked on the actual mounted tickets (including
	# hover, focus and disabled) by _test_dark_style, not by old cream-era ink luminance.
	panel.upgrade_button.grab_focus()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab)
	await process_frame
	_check(panel.stitch_button.has_focus(), "Tab reaches next primary action")
	tab = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab)
	await process_frame
	_check(panel.leave_button.has_focus(), "Tab reaches the third primary action")
	_check(not panel.choice_scroll.get_global_rect().intersects(panel.preview_scroll.get_global_rect())
		and not panel.choice_scroll.get_global_rect().intersects(panel.confirm_button.get_global_rect()), "choices and preview stay clear of pinned confirmation")
	await _activate(panel.upgrade_button, false)
	_check(panel.option_buttons.size() == visit.upgrade_options().size() and panel.option_buttons.size() == 30, "nonempty canonical occurrence options")
	var canonical_upgrades: Array = visit.upgrade_options()
	for i in range(panel.option_buttons.size()):
		_check(panel.option_buttons[i].get_meta("option") == canonical_upgrades[i], "exact canonical upgrade metadata")
		# The rendered caption names the authored card, its owner and the
		# one-based copy the zero-based option index addresses.
		var rendered: String = panel.option_buttons[i].text
		_check(rendered.contains(canonical_upgrades[i].display_name)
			and rendered.contains(canonical_upgrades[i].owner)
			and rendered.contains("copy #%d" % (canonical_upgrades[i].index + 1)), "readable occurrence caption")
		_check(_card_ink(panel.option_buttons[i]).contains(canonical_upgrades[i].display_name)
			and _card_ink(panel.option_buttons[i]).contains(canonical_upgrades[i].plus_display_name)
			and _card_ink(panel.option_buttons[i]).contains("copy #%d" % (canonical_upgrades[i].index + 1))
			and _card_ink(panel.option_buttons[i]).contains("%d energy" % canonical_upgrades[i].cost)
			and _card_ink(panel.option_buttons[i]).contains("%d energy" % canonical_upgrades[i].plus_cost),
			"sewn ink exposes original, upgraded name, costs and canonical copy")
		_assert_decorations(panel.option_buttons[i])
		_assert_visible_action(panel.option_buttons[i], canonical_upgrades[i], true)
	_check(panel.size == Vector2(940, 620) and panel.option_buttons.size() >= 2,
		"real mounted panel has at least two upgrade rows to measure")
	for i in range(2):
		_check(panel.choice_scroll.get_global_rect().encloses(panel.option_buttons[i].get_global_rect()),
			"two complete upgrade rows fit the 350-pixel viewport including owner filters")
	_check(viewport.encloses(panel.option_buttons[0].get_global_rect()), "first fully shown mini-card fits viewport")
	for button in panel.option_buttons:
		var clipped := button.get_global_rect().intersection(panel.choice_scroll.get_global_rect())
		_check(not clipped.intersects(panel.confirm_button.get_global_rect())
			and button.size.x <= panel.choice_scroll.size.x and button.size.y >= 140 and button.size.y <= 150,
			"even offscreen copies only paint inside the choice scroll, never Confirm")
	_check(panel.choice_scroll.clip_contents and panel.choice_scroll.size == Vector2(440, 350)
		and panel.preview_scroll.size == Vector2(428, 350), "fixed clipped two-column layout")
	_check(panel.choice_scroll.get_v_scroll_bar().max_value > panel.choice_scroll.size.y, "long deck contained in scroll")
	panel.option_buttons.back().grab_focus()
	await _settle_layout()
	_check(panel.choice_scroll.scroll_vertical > 0, "keyboard focus reveals offscreen copy")
	_assert_visible_action(panel.option_buttons.back(), canonical_upgrades.back(), true)
	_check(visit.read_state() == source and intents.is_empty(), "browse does not change any ledger")


## Actual paired ink/background contrast on the mounted gothic ticket surfaces.
## Pure luminance of the foreground alone is insufficient for dark-mode UI.
func _contrast(foreground: Color, background: Color) -> float:
	var front := foreground.srgb_to_linear()
	var back := background.srgb_to_linear()
	var a := 0.2126 * front.r + 0.7152 * front.g + 0.0722 * front.b
	var b := 0.2126 * back.r + 0.7152 * back.g + 0.0722 * back.b
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


func _check_ticket(button: Button, name: String) -> void:
	var pairs := {
		"normal": "font_color", "hover": "font_hover_color",
		"pressed": "font_pressed_color", "hover_pressed": "font_hover_pressed_color",
		"disabled": "font_disabled_color",
	}
	for state in pairs:
		var face := button.get_theme_stylebox(state) as StyleBoxFlat
		_check(face != null and _contrast(button.get_theme_color(pairs[state]), face.bg_color) >= 4.5,
			name + " readable against its real " + state + " face")
	var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
	var hover := button.get_theme_stylebox("hover") as StyleBoxFlat
	var pressed := button.get_theme_stylebox("pressed") as StyleBoxFlat
	var disabled := button.get_theme_stylebox("disabled") as StyleBoxFlat
	var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
	_check(normal != null and hover != null and pressed != null and disabled != null and focus != null
		and normal.bg_color != hover.bg_color and pressed.bg_color != hover.bg_color
		and disabled.bg_color != normal.bg_color and focus.border_width_left >= 3
		and _contrast(button.get_theme_color("font_focus_color"), normal.bg_color) >= 4.5,
		name + " has distinguishable hover, pressed, disabled and visible keyboard focus")


func _test_dark_style() -> void:
	var visit := _make()
	await _bind(visit)
	var original := visit.read_state()
	_check(visit.is_valid() and visit.quote().choices == ["upgrade", "stitch", "leave"]
		and original.deck == [STRIKE, STRIKE, PRICK] and original.remaining_scraps == 7,
		"dark UI checked against genuine 7-scrap, duplicate-copy quoted stop")
	var backdrop := panel.get_child(0) as Panel
	var surface := backdrop.get_theme_stylebox("panel") as StyleBoxFlat
	_check(surface != null and surface.bg_color.get_luminance() < 0.2
		and surface.border_color.get_luminance() > surface.bg_color.get_luminance()
		and _contrast(panel.status_label.get_theme_color("font_color"), surface.bg_color) >= 4.5,
		"real mounted frame is dark fabric, gold-seamed, with readable status")
	var heading: Label = null
	var wells: Array[Panel] = []
	for child in panel.get_children():
		if child is Label and child.text.begins_with("SEWING CIRCLE"):
			heading = child
		if child is Panel and child != backdrop:
			wells.append(child)
	_check(heading != null and _contrast(heading.get_theme_color("font_color"), surface.bg_color) >= 4.5,
		"mounted gold heading contrasts with dark fabric")
	var preview_well: StyleBoxFlat = null
	for well in wells:
		if well.position == panel.preview_scroll.position and well.size == panel.preview_scroll.size:
			preview_well = well.get_theme_stylebox("panel") as StyleBoxFlat
	_check(preview_well != null and preview_well.bg_color.get_luminance() > 0.6
		and _contrast(panel.preview_label.get_theme_color("font_color"), preview_well.bg_color) >= 4.5
		and panel.preview_scroll.clip_contents,
		"full rules preview is dark ink on a readable light parchment well")
	for action in [panel.upgrade_button, panel.stitch_button, panel.leave_button, panel.confirm_button]:
		_check_ticket(action, "existing " + action.text)
	await _activate(panel.upgrade_button, false)
	_check(panel.filter_buttons.size() == 3 and panel.option_buttons.size() == 3,
		"visible genuine owner chips and every duplicate upgrade row exist")
	for chip in panel.filter_buttons:
		_check_ticket(chip, "owner chip " + chip.text)
	for row in panel.option_buttons:
		var normal := row.get_theme_stylebox("normal") as StyleBoxFlat
		var hover := row.get_theme_stylebox("hover") as StyleBoxFlat
		_check(normal != null and hover != null and normal.bg_color.get_luminance() < 0.2
			and hover.bg_color.get_luminance() < 0.3,
			"authentic compact row uses dark tickets in normal and hover")
		for label in row.find_children("*", "Label", true, false):
			var background := normal.bg_color
			if label.get_parent() is Panel:
				background = (label.get_parent() as Panel).get_theme_stylebox("panel").bg_color
			_check(_contrast(label.get_theme_color("font_color"), background) >= 4.5,
				"visible card/energy ink contrasts against its sewn ticket or coin")
	await _activate(panel.option_buttons[1], false)
	var selected := panel.option_buttons[1].get_theme_stylebox("normal") as StyleBoxFlat
	_check(panel.option_buttons[1].get_meta("selected") and selected != null
		and selected.border_color.get_luminance() > selected.bg_color.get_luminance()
		and _contrast((panel.option_buttons[1].get_child(1) as Label).get_theme_color("font_color"), selected.bg_color) >= 4.5,
		"second Warden copy gets a bright sewn selection edge and readable identity")
	_check(intents.is_empty() and visit.read_state() == original,
		"hover, style inspection and selection do not spend, settle or emit")
	var broke := _make([STRIKE, STRIKE, PRICK], 2)
	await _bind(broke)
	_check(broke.is_valid() and panel.stitch_button.disabled and not panel.upgrade_button.disabled
		and not panel.leave_button.disabled and panel.stitch_button.text.contains("3 scraps"),
		"genuine unaffordable Stitch remains an explicit, readable disabled price")
	_check_ticket(panel.stitch_button, "physically disabled 3-scrap Stitch")


func _filter_at(owner: String) -> Button:
	for chip in panel.filter_buttons:
		if chip.text == ("All" if owner.is_empty() else owner.capitalize()):
			return chip
	_check(false, "genuine stage must expose owner filter " + owner)
	return null


func _check_filtered(options: Array, owner: String = "") -> void:
	_check(not options.is_empty(), "canonical eligible stage is nonempty")
	var expected: Array = []
	var owners: Array[String] = [""]
	for option in options:
		if not owners.has(option.owner):
			owners.append(option.owner)
		if owner.is_empty() or option.owner == owner:
			expected.append(option)
	_check(not expected.is_empty() and panel.option_buttons.size() == expected.size(),
		"filtered nonempty rows have exact eligible occurrence count")
	for i in range(mini(expected.size(), panel.option_buttons.size())):
		_check(panel.option_buttons[i].get_meta("option") == expected[i]
			and panel._row_indices[panel.option_buttons[i]] == expected[i].index,
			"filtered duplicate keeps canonical metadata, order and original index")
		_assert_visible_action(panel.option_buttons[i], expected[i], panel._mode == "upgrade")
	_check(panel.filter_buttons.size() == owners.size(), "only stage owners plus All offered")
	for i in range(mini(owners.size(), panel.filter_buttons.size())):
		var chip := panel.filter_buttons[i]
		_check(chip.text == ("All" if owners[i].is_empty() else owners[i].capitalize())
			and chip.button_pressed == (owners[i] == owner), "authentic filter caption and selected state")
		var clipped := chip.get_global_rect().intersection(panel.choice_scroll.get_global_rect())
		_check(chip.size.x <= panel.choice_scroll.size.x
			and chip.size.y <= 40 and panel.choice_scroll.get_global_rect().encloses(chip.get_global_rect())
			and not clipped.intersects(panel.preview_scroll.get_global_rect())
			and not clipped.intersects(panel.confirm_button.get_global_rect()),
			"compact chips paint only inside existing choices column")


func _test_owner_filters() -> void:
	seed(RNG_SEED)
	var seeded_next := randi()
	seed(RNG_SEED)
	var deck: Array = []
	for i in range(30):
		deck.append([STRIKE, PRICK, "tinker_pop_shot"][i % 3])
	for keyboard in [false, true]:
		var visit := _make(deck)
		await _bind(visit)
		var source := visit.read_state()
		_check(panel.filter_buttons.is_empty() and panel._owner_filter.is_empty(), "fresh bind resets filters")
		await _activate(panel.upgrade_button, keyboard)
		_check_filtered(visit.upgrade_options())
		_check(panel.option_buttons.size() == 30, "All retains full authentic 30-copy three-owner deck")
		panel.leave_button.grab_focus()
		await _key(KEY_TAB)
		_check(_filter_at("").has_focus(), "Tab from third decision reaches All navigation")
		await _key(KEY_TAB)
		_check(_filter_at("warden").has_focus(), "Tab reaches first owner chip")
		await _key(KEY_ENTER)
		await _key(KEY_ENTER, false)
		_check_filtered(visit.upgrade_options(), "warden")
		_check(_filter_at("warden").has_focus(), "chip refresh preserves selected keyboard focus")
		for owner in ["seamstress", "tinker", "warden"]:
			await _activate(_filter_at(owner), keyboard)
			_check_filtered(visit.upgrade_options(), owner)
			_check(_filter_at(owner).has_focus(), "mouse and keyboard chip preserve focus")
		await _activate(_filter_at(""), keyboard)
		_check_filtered(visit.upgrade_options())
		await _activate(_filter_at("warden"), keyboard)
		var retired_chip: Callable = _filter_at("tinker").pressed.get_connections()[0].callable
		var retired_row: Callable = panel.option_buttons[1].pressed.get_connections()[0].callable
		await _activate(panel.option_buttons[1], keyboard)
		_check(panel.preview().index == 3 and not panel.confirm_button.disabled,
			"filtered second Warden duplicate previews source index 3")
		await _activate(_filter_at("seamstress"), keyboard)
		retired_chip.call()
		retired_row.call()
		await _key(KEY_3)
		_check_filtered(visit.upgrade_options(), "seamstress")
		_check(panel.preview().is_empty() and panel._first == -1 and panel.confirm_button.disabled
			and intents.is_empty() and panel._confirmed.is_empty() and visit.read_state() == source,
			"switch after preview retires rows/chips and Confirm without receipt or ledger drift")
		await _activate(panel.option_buttons[1], keyboard)
		_check(panel.preview().index == 4, "filtered duplicate retains index 4")
		await _activate(panel.confirm_button, keyboard)
		_check(intents.size() == 1, "filtered upgrade emits exactly once")
		if intents.size() != 1:
			return
		var intent := intents[0]
		_check(intent.first_index == 4 and intent.source_snapshot == source
			and panel.take_confirmed(intent) == intent and panel.take_confirmed(intent).is_empty(),
			"filtered upgrade exact source-bound one-shot receipt")
		var result := Controller.submit(visit, intent)
		_check(result.ok and result.deck[4] == "seamstress_prick_plus"
			and result.deck[1] == PRICK, "only selected filtered duplicate upgrades")
		_check_receipt(result, source, 0)
		_check_replay(visit, intent)
		retired_chip.call()
		retired_row.call()
		_check(intents.size() == 1 and panel.filter_buttons.is_empty(), "submitted filters remain retired")

		visit = _make(deck)
		await _bind(visit)
		source = visit.read_state()
		await _activate(panel.stitch_button, keyboard)
		_check_filtered(visit.stitch_first_options())
		for owner in ["seamstress", "tinker", ""]:
			await _activate(_filter_at(owner), keyboard)
			_check_filtered(visit.stitch_first_options(), owner)
			_check(_filter_at(owner).has_focus() and panel._first == -1 and panel._second == -1
				and panel.preview().is_empty() and panel._confirmed.is_empty()
				and panel.confirm_button.disabled and intents.is_empty() and visit.read_state() == source,
				"FIRST filtering restores only chip focus without selecting, spending or emitting")
		await _activate(_filter_at("warden"), keyboard)
		_check_filtered(visit.stitch_first_options(), "warden")
		retired_chip = _filter_at("warden").pressed.get_connections()[0].callable
		retired_row = panel.option_buttons[1].pressed.get_connections()[0].callable
		await _activate(panel.option_buttons[1], keyboard)
		_check(panel._first == 3 and panel._owner_filter.is_empty(), "FIRST to THEN resets to All")
		_check_filtered(visit.stitch_second_options(3))
		_check(panel.filter_buttons.size() == 3 and _filter_at("").button_pressed,
			"THEN exposes All and only two genuine different-owner filters")
		retired_chip.call()
		retired_row.call()
		_check(panel._first == 3 and panel._second == -1, "first-stage chip/row cannot select a THEN half")
		await _activate(_filter_at("tinker"), keyboard)
		_check_filtered(visit.stitch_second_options(3), "tinker")
		await _activate(panel.option_buttons[1], keyboard)
		var pair := visit.stitch_preview(3, 5)
		_check(not pair.is_empty() and panel.preview() == pair, "filtered THEN uses authentic ordered preview")
		retired_chip = _filter_at("tinker").pressed.get_connections()[0].callable
		retired_row = panel.option_buttons[1].pressed.get_connections()[0].callable
		await _activate(_filter_at("seamstress"), keyboard)
		retired_chip.call()
		retired_row.call()
		await _key(KEY_3)
		_check_filtered(visit.stitch_second_options(3), "seamstress")
		_check(panel._first == 3 and panel._second == -1 and panel.preview().is_empty()
			and panel._confirmed.is_empty() and _filter_at("seamstress").has_focus()
			and panel.confirm_button.disabled and intents.is_empty() and visit.read_state() == source,
			"THEN filter retires partner callbacks and Confirm, keeping FIRST and only chip focus without spending")
		await _activate(panel.option_buttons[1], keyboard)
		pair = visit.stitch_preview(3, 4)
		_check(not pair.is_empty() and panel.preview() == pair, "new filtered partner retains original source index")
		await _activate(panel.confirm_button, keyboard)
		_check(intents.size() == 1, "filtered Stitch emits once")
		if intents.size() != 1:
			return
		intent = intents[0]
		_check(intent.first_index == 3 and intent.second_index == 4 and intent.source_snapshot == source
			and panel.take_confirmed(intent) == intent and panel.take_confirmed(intent).is_empty(),
			"filtered Stitch has exact source-bound ordered one-shot receipt")
		result = Controller.submit(visit, intent)
		_check(result.ok and result.transaction == pair.projection and result.deck == pair.resulting_deck
			and result.remaining_scraps == source.remaining_scraps - 3 and result.charged_scraps == 3,
			"filtered Stitch settles the exact original occurrences for exactly three scraps")
		_check_receipt(result, source, 3)
		_check_replay(visit, intent)

	var visit := _make([STRIKE, PRICK, "tinker_pop_shot"])
	await _bind(visit)
	await _activate(panel.stitch_button, false)
	_check_filtered(visit.stitch_first_options())
	await _activate(_filter_at("tinker"), false)
	await _activate(panel.upgrade_button, false)
	_check_filtered(visit.upgrade_options())
	_check(panel._owner_filter.is_empty(), "entering another mode resets owner filter to All")
	var chip_callback: Callable = _filter_at("tinker").pressed.get_connections()[0].callable
	var row_callback: Callable = panel.option_buttons[0].pressed.get_connections()[0].callable
	var source := visit.read_state()
	panel.hide()
	chip_callback.call()
	row_callback.call()
	_check(panel._owner_filter.is_empty() and panel._first == -1 and visit.read_state() == source,
		"hidden chip and row callbacks cannot act")
	panel.show()
	await _activate(panel.leave_button, false)
	chip_callback.call()
	row_callback.call()
	_check(panel._mode == "leave" and panel.filter_buttons.is_empty(), "Leave retires filters and rows")
	var replacement := _make(deck, 2)
	await _bind(replacement)
	var replacement_source := replacement.read_state()
	chip_callback.call()
	row_callback.call()
	await _key(KEY_2)
	_check(panel._mode.is_empty() and panel.filter_buttons.is_empty() and panel.stitch_button.disabled
		and panel.confirm_button.disabled and intents.is_empty() and replacement.read_state() == replacement_source,
		"rebound chip and row cannot bypass low-scrap Stitch")
	await _activate(panel.upgrade_button, false)
	chip_callback = _filter_at("warden").pressed.get_connections()[0].callable
	panel.close()
	chip_callback.call()
	_check(not panel.visible and panel.filter_buttons.is_empty() and intents.is_empty()
		and replacement.read_state() == replacement_source, "closed chip callback is inert")
	await _bind(visit)
	await _activate(panel.upgrade_button, false)
	chip_callback = _filter_at("tinker").pressed.get_connections()[0].callable
	row_callback = panel.option_buttons[0].pressed.get_connections()[0].callable
	var external := visit.leave(source.visit_id, source.node_id, source)
	_check(external.ok, "genuine external settlement before inactive chip callback")
	var settled := visit.read_state()
	chip_callback.call()
	row_callback.call()
	_check(panel.filter_buttons.is_empty() and panel.option_buttons.is_empty()
		and panel.preview().is_empty() and panel.confirm_button.disabled and intents.is_empty()
		and visit.read_state() == settled, "externally consumed visit retires chips without forging an intent")
	_check(randi() == seeded_next, "all owner filtering paths consume no global RNG")
	seed(RNG_SEED)


## Expectations come directly from independently resolved cards, not the panel's
## formatting helpers or loose choice.effects fields.
func _expected_detail(card: Dictionary, index: int) -> String:
	var recipient := ""
	match str(card.target_kind):
		"enemy_single": recipient = "ENEMY TO %s" % str(card.to_positions)
		"enemy_all": recipient = "ALL ENEMIES TO %s" % str(card.to_positions)
		"enemy_random": recipient = "RANDOM ENEMY TO %s" % str(card.to_positions)
		"self": recipient = "TARGET: self"
		"ally_single": recipient = "TARGET: chosen ally"
		"party_all": recipient = "TARGET: all allies"
		"none": recipient = "TARGET: no chosen target"
		_: recipient = "TARGET: %s" % str(card.target_kind)
	return "%s | %s | %s | copy #%d | %d energy\nFROM %s | %s\n%s" % [
		str(card.owner).capitalize(), card.display_name, card.id, index + 1,
		card.cost, str(card.from_positions), recipient, CardShortRules.line(card)]


func _row_at(index: int) -> Button:
	for button in panel.option_buttons:
		if button.get_meta("option").index == index:
			return button
	_check(false, "a genuine catalog instance must have its own physical row #%d" % (index + 1))
	return null


func _test_upgrade(keyboard: bool) -> void:
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	var starter := StarterCards.new()
	var strike := starter.get_definition(STRIKE)
	var strike_plus := starter.get_definition("warden_strike_plus")
	var prick := starter.get_definition(PRICK)
	var prick_plus := starter.get_definition("seamstress_prick_plus")
	_check(strike.cost == 1 and strike.effects == {"damage": 6}
		and strike_plus.cost == 1 and strike_plus.effects == {"damage": 7}
		and prick.cost == 1 and prick.effects == {"damage": 3, "bleed": 2}
		and prick_plus.effects == {"damage": 4, "bleed": 3},
		"independent authored Strike, Strike+, Prick and Prick+ preconditions")
	await _activate(panel.upgrade_button, keyboard)
	_check(panel.option_buttons.size() == 3 and panel.confirm_button.disabled, "upgrade needs explicit occurrence")
	_check(visit.upgrade_options()[1].effects == strike.effects
		and visit.upgrade_options()[1].plus_effects == strike_plus.effects
		and visit.upgrade_options()[2].effects == prick.effects
		and visit.upgrade_options()[2].plus_effects == prick_plus.effects,
		"authentic typed upgrade options carry independent authored effects")
	_check(_compact_ink(panel.option_buttons[2], prick, 2, prick_plus)
		and panel.option_buttons[2].tooltip_text.contains(_expected_detail(prick, 2))
		and panel.option_buttons[2].tooltip_text.contains(_expected_detail(prick_plus, 2)),
		"compact Prick identity retains full canonical before/after Help")
	panel.option_buttons[2].grab_focus()
	await _settle_layout()
	await _activate(panel.option_buttons[2], keyboard)
	_check(panel.preview().index == 2
		and panel.preview_label.text.contains("BEFORE | " + _expected_detail(prick, 2))
		and panel.preview_label.text.contains("AFTER | " + _expected_detail(prick_plus, 2)),
		"real Prick preview explains authentic before and after")
	panel.option_buttons[1].grab_focus()
	await _settle_layout()
	await _activate(panel.option_buttons[1], keyboard)
	_check(panel.preview().index == 1 and panel.preview().effects == {"damage": 6}
		and panel.preview().plus_effects == {"damage": 7}, "genuine upgrade preview for second duplicate")
	_check(panel.option_buttons[1].get_meta("selected") and not panel.option_buttons[0].get_meta("selected"),
		"only the selected duplicate carries a sewn selection highlight")
	var upgrade_ink := _card_ink(panel.option_buttons[1])
	_check(upgrade_ink.contains("Warden") and upgrade_ink.contains(visit.upgrade_options()[1].display_name)
		and upgrade_ink.contains(visit.upgrade_options()[1].plus_display_name)
		and _compact_ink(panel.option_buttons[1], strike, 1, strike_plus)
		and panel.option_buttons[1].tooltip_text.contains(_expected_detail(strike, 1))
		and panel.option_buttons[1].tooltip_text.contains(_expected_detail(strike_plus, 1)),
		"compact Warden occurrence retains independently authored rules in Help")
	_check(panel.preview_label.text.contains("BEFORE | " + _expected_detail(strike, 1))
		and panel.preview_label.text.contains("AFTER | " + _expected_detail(strike_plus, 1))
		and panel.preview_label.text.contains("Only copy #2 changes"),
		"source-true card line and legal slots for selected duplicate")
	await _activate(panel.confirm_button, keyboard)
	_check(intents.size() == 1 and visit.read_state() == source, "UI emits once and never settles")
	if intents.size() != 1:
		return
	var intent := intents[0]
	_check(intent == {"action": "upgrade", "first_index": 1, "second_index": -1,
		"visit_id": source.visit_id, "node_id": source.node_id, "source_snapshot": source}, "mouse/keyboard exact source-bound upgrade intent")
	var result := Controller.submit(visit, intent)
	var oracle := RunRestCardUpgrade.new(source.deck, {STRIKE: "warden_strike_plus"}, {}, 1).choose_upgrade(1)
	_check(result.ok and result.action == "upgrade" and result.transaction == oracle, "exact typed upgrade transaction")
	_check(result.deck == [STRIKE, "warden_strike_plus", PRICK], "only selected duplicate upgraded")
	_check_receipt(result, source, 0)
	_check_replay(visit, intent)
	var after := visit.read_state()
	intent.source_snapshot.deck.clear()
	_check(visit.read_state() == after, "emitted intent detached from authority")


func _test_stitch(keyboard: bool) -> void:
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	var expected := visit.stitch_preview(1, 2)
	var starter := StarterCards.new()
	var first_def := starter.get_definition(STRIKE)
	var second_def := starter.get_definition(PRICK)
	_check(not expected.is_empty() and first_def.owner == "warden"
		and second_def.owner == "seamstress" and first_def.owner != second_def.owner
		and first_def.cost == 1 and second_def.cost == 1
		and first_def.effects == {"damage": 6}
		and second_def.effects == {"damage": 3, "bleed": 2},
		"genuine two-owner authored half preconditions")
	_check(expected.first_half == first_def and expected.second_half == second_def
		and expected.energy_cost == mini(3, maxi(first_def.cost, second_def.cost) + 1)
		and expected.energy_cost == 2 and expected.scrap_cost == 3
		and expected.remaining_scraps == 4 and expected.first_index == 1
		and expected.second_index == 2, "independent source-bound Stitch projection, energy cap and spend")
	await _activate(panel.stitch_button, keyboard)
	_check(panel.option_buttons.size() == 3, "canonical first copies including duplicates")
	_check(_compact_ink(panel.option_buttons[1], first_def, 1)
		and _card_ink(panel.option_buttons[1]).contains("FIRST")
		and panel.option_buttons[1].tooltip_text.contains("FIRST | " + _expected_detail(first_def, 1)),
		"compact FIRST identity keeps Warden's full canonical Help")
	_assert_visible_action(panel.option_buttons[1], visit.stitch_first_options()[1], false)
	for i in range(panel.option_buttons.size()):
		_check(panel.option_buttons[i].get_meta("option") == visit.stitch_first_options()[i], "exact canonical stitch first occurrence metadata")
	await _activate(panel.option_buttons[1], keyboard)
	_check(panel.option_buttons.size() == 1 and panel.option_buttons[0].get_meta("option").index == 2, "second stage only different-owner occurrence")
	_check(panel.option_buttons[0].get_meta("option") == visit.stitch_second_options(1)[0], "exact canonical stitch partner metadata")
	_check(panel.preview_label.text.contains("FIRST | " + _expected_detail(first_def, 1))
		and panel.preview_label.text.contains("DIFFERENT owner")
		and panel.preview_label.text.contains("each in their own legal FROM position")
		and _card_ink(panel.option_buttons[0]).contains("Seamstress")
		and _compact_ink(panel.option_buttons[0], second_def, 2)
		and _card_ink(panel.option_buttons[0]).contains("THEN")
		and panel.option_buttons[0].tooltip_text.contains(_expected_detail(second_def, 2)),
		"real FIRST preview and THEN row Help show full catalog rules")
	_assert_decorations(panel.option_buttons[0])
	_assert_visible_action(panel.option_buttons[0], visit.stitch_second_options(1)[0], false)
	await _activate(panel.option_buttons[0], keyboard)
	_check(panel.preview() == expected and panel.preview_label.text.contains("Scraps: 7 -> 4"), "exact detached genuine stitch forecast")
	_check(panel.option_buttons[0].get_meta("selected")
		and panel.preview_label.text.contains("FIRST | " + _expected_detail(first_def, 1))
		and panel.preview_label.text.contains("THEN | " + _expected_detail(second_def, 2))
		and panel.preview_label.text.contains("Energy: 2 (max half + 1, capped at 3)")
		and panel.preview_label.text.contains("Scraps: 7 -> 4 (cost 3)")
		and panel.preview_label.text.contains("Both owners must be alive, each in their own legal FROM position"),
		"highlighted ordered FIRST/THEN full halves keep original owner and play caveat")
	_check(panel.preview_label.text.contains(expected.display_name)
		and panel.preview_label.text.contains("Energy: %d" % expected.energy_cost)
		and panel.preview_label.text.contains("Deck: %d -> %d cards" % [expected.deck_before_count, expected.deck_after_count]),
		"visible genuine stitch forecast")
	_check(panel.option_buttons.size() == 1 and panel.confirm_button.disabled == false, "chosen pair can be confirmed")
	var detached := panel.preview()
	detached.descriptor.clear()
	_check(panel.preview() == expected, "preview query detached")
	await _activate(panel.confirm_button, keyboard)
	_check(intents.size() == 1 and visit.read_state() == source, "stitch intent does not spend")
	if intents.size() != 1:
		return
	var intent := intents[0]
	_check(intent.action == "stitch" and intent.first_index == 1 and intent.second_index == 2 and intent.source_snapshot == source, "equivalent source-bound stitch intent")
	var result := Controller.submit(visit, intent)
	_check(result.ok and result.action == "stitch" and result.transaction == expected.projection, "exact typed stitch receipt")
	_check(result.deck == expected.resulting_deck and result.deck.count(STRIKE) == 1
		and result.descriptors == {expected.stitched_id: expected.descriptor}
		and result.next_stitch_id == 2 and result.remaining_scraps == 4, "two selected copies consumed, duplicate preserved, exact payment and cursor")
	_check_receipt(result, source, 3)
	_check_replay(visit, intent)


## Real reward-pool cards with distinct legal source and recipient positions.
## Every occurrence is checked against the independent catalog resolver.
func _test_pool_upgrade(keyboard: bool) -> void:
	const PIN := "warden_pinning_jab"
	const SNAG := "seamstress_snag"
	const GUARD := "warden_patch_guard"
	var visit := _make([PIN, SNAG, GUARD], 3)
	await _bind(visit)
	var source := visit.read_state()
	var pin := RunRestStitchCards.resolve_card_definition(PIN)
	var pin_plus := RunRestStitchCards.resolve_card_definition(PIN + "_plus")
	var snag := RunRestStitchCards.resolve_card_definition(SNAG)
	var snag_plus := RunRestStitchCards.resolve_card_definition(SNAG + "_plus")
	var guard := RunRestStitchCards.resolve_card_definition(GUARD)
	_check(visit.is_valid() and source.deck == [PIN, SNAG, GUARD]
		and pin.owner == "warden" and snag.owner == "seamstress"
		and pin.cost == 1 and pin_plus.cost == 1 and pin.from_positions == [1, 2]
		and pin.to_positions == [1] and pin.target_kind == "enemy_single"
		and pin.effects == {"damage": 4, "pinned": true}
		and pin_plus.effects == {"damage": 6, "pinned": true}
		and snag.cost == 1 and snag_plus.cost == 1 and snag.from_positions == [2, 3]
		and snag.to_positions == [1, 2, 3] and snag.target_kind == "enemy_single"
		and snag.effects == {"unravel": 3, "weak": 1}
		and snag_plus.effects == {"unravel": 4, "weak": 1}
		and guard.target_kind == "ally_single" and guard.to_positions.is_empty(),
		"nonvacuous authored Pinning Jab, Snag and chosen-ally source preconditions")
	await _activate(panel.upgrade_button, keyboard)
	var upgrades := visit.upgrade_options()
	_check(upgrades.size() >= 3 and panel.option_buttons.size() == upgrades.size()
		and panel.confirm_button.disabled, "catalog-backed occurrence list requires an explicit upgrade choice")
	for option in upgrades:
		var row := _row_at(option.index)
		if row == null:
			return
		var before := RunRestStitchCards.resolve_card_definition(option.source_id)
		var after := RunRestStitchCards.resolve_card_definition(option.plus_id)
		_check(not before.is_empty() and not after.is_empty()
			and source.deck[option.index] == before.id and option.owner == before.owner
			and option.cost == before.cost and option.plus_cost == after.cost
			and option.effects == before.effects and option.plus_effects == after.effects,
			"each authorized pool upgrade row binds exact authentic definitions")
		_check(row.tooltip_text.contains("BEFORE | " + _expected_detail(before, option.index))
			and row.tooltip_text.contains("AFTER | " + _expected_detail(after, option.index))
			and _compact_ink(row, before, option.index, after),
			"compact pool identity retains both full canonical definitions in hover/focus Help")
		_assert_visible_action(row, option, true)
		row.grab_focus()
		await _settle_layout()
		var prior_preview := panel.preview()
		var prior_confirm_disabled := panel.confirm_button.disabled
		var hover := InputEventMouseMotion.new()
		hover.position = row.get_global_rect().get_center()
		root.push_input(hover)
		await process_frame
		_check(intents.is_empty() and visit.read_state() == source
			and panel.preview() == prior_preview
			and panel.confirm_button.disabled == prior_confirm_disabled,
			"hover and keyboard focus on authentic Help are read-only and create no intents")
		await _activate(row, keyboard)
		_check(panel.preview().index == option.index
			and panel.preview_label.text.contains("BEFORE | " + _expected_detail(before, option.index))
			and panel.preview_label.text.contains("AFTER | " + _expected_detail(after, option.index))
			and panel.preview_label.text.contains("Cost: free. Only copy #%d changes." % (option.index + 1)),
			"selected BEFORE/AFTER is the two complete canonical card records")
	_check(not panel.option_buttons[0].tooltip_text.contains("pinned: True")
		and panel.option_buttons[0].tooltip_text.contains(CardShortRules.line(pin))
		and panel.option_buttons[1].tooltip_text.contains(CardShortRules.line(snag)),
		"Pin and Unravel are authored keywords, never raw booleans or invented turn durations")
	_check(not panel.option_buttons[2].tooltip_text.contains("ENEMY TO")
		and panel.option_buttons[2].tooltip_text.contains("TARGET: chosen ally"),
		"support-target Help names the real recipient with no imaginary enemy slots")
	var unknown := pin.duplicate(true)
	unknown.effects["mystery_keyword"] = 19
	_check(CardShortRules.line(unknown).contains(CardShortRules.UNKNOWN_SENTENCE)
		and panel._card_detail(unknown, 0).contains(CardShortRules.UNKNOWN_SENTENCE),
		"unrecognized effect keeps CardShortRules' honest unknown-effect fallback")
	var pin_row := _row_at(0)
	if pin_row == null:
		return
	pin_row.grab_focus()
	await _settle_layout()
	await _activate(pin_row, keyboard)
	await _activate(panel.confirm_button, keyboard)
	_check(intents.size() == 1 and visit.read_state() == source,
		"pool Upgrade still sends one physical intent with no direct spend")
	if intents.size() != 1:
		return
	var intent := intents[0]
	var result := Controller.submit(visit, intent)
	_check(intent.action == "upgrade" and intent.first_index == 0
		and intent.source_snapshot == source and result.ok
		and result.deck == [PIN + "_plus", SNAG, GUARD]
		and result.charged_scraps == 0 and result.remaining_scraps == 3,
		"free pool upgrade replaces only the selected original occurrence")
	_check_receipt(result, source, 0)
	_check_replay(visit, intent)


func _test_pool_stitch(keyboard: bool) -> void:
	const PIN := "warden_pinning_jab"
	const SNAG := "seamstress_snag"
	var visit := _make([PIN, SNAG], 3)
	await _bind(visit)
	var source := visit.read_state()
	var first := RunRestStitchCards.resolve_card_definition(PIN)
	var second := RunRestStitchCards.resolve_card_definition(SNAG)
	var first_option: Dictionary = {}
	var second_option: Dictionary = {}
	for candidate in visit.stitch_first_options():
		if candidate.id == PIN and candidate.owner == first.owner:
			first_option = candidate
			break
	if not first_option.is_empty():
		for candidate in visit.stitch_second_options(first_option.index):
			if candidate.id == SNAG and candidate.owner == second.owner:
				second_option = candidate
				break
	_check(visit.is_valid() and source.deck == [PIN, SNAG] and source.remaining_scraps == 3
		and not first_option.is_empty() and not second_option.is_empty()
		and first.owner != second.owner and first.cost == 1 and second.cost == 1
		and first.from_positions == [1, 2] and first.to_positions == [1]
		and second.from_positions == [2, 3] and second.to_positions == [1, 2, 3],
		"payable source-authentic two-owner pool stitch and position preconditions")
	if first_option.is_empty() or second_option.is_empty():
		return
	var pair := visit.stitch_preview(first_option.index, second_option.index)
	_check(not pair.is_empty() and pair.first_half == first and pair.second_half == second
		and pair.first_id == PIN and pair.second_id == SNAG
		and pair.energy_cost == 2 and pair.scrap_cost == 3 and pair.remaining_scraps == 0
		and pair.deck_after_count == pair.deck_before_count - 1,
		"true visit projection gives exact 2-energy FIRST/THEN and 3-scrap cost")
	await _activate(panel.stitch_button, keyboard)
	var first_row := _row_at(first_option.index)
	if first_row == null:
		return
	_check(first_row.tooltip_text.contains("FIRST | " + _expected_detail(first, first_option.index))
		and panel.confirm_button.disabled, "FIRST Help shows real Warden positions and Pin")
	_assert_visible_action(first_row, first_option, false)
	first_row.grab_focus()
	await _settle_layout()
	await _activate(first_row, keyboard)
	var second_row := _row_at(second_option.index)
	if second_row == null:
		return
	_check(second_row.tooltip_text.contains("THEN | " + _expected_detail(second, second_option.index))
		and panel.preview_label.text.contains("FIRST | " + _expected_detail(first, first_option.index))
		and panel.confirm_button.disabled, "THEN Help preserves source-order and nonactionable half pair")
	_assert_visible_action(second_row, second_option, false)
	second_row.grab_focus()
	await _settle_layout()
	_check(intents.is_empty() and visit.read_state() == source,
		"focus on THEN Help is read-only")
	await _activate(second_row, keyboard)
	_check(panel.preview() == pair and panel.option_buttons.has(second_row)
		and panel.preview_label.text.contains("FIRST | " + _expected_detail(pair.first_half, first_option.index))
		and panel.preview_label.text.contains("THEN | " + _expected_detail(pair.second_half, second_option.index))
		and panel.preview_label.text.contains("Energy: 2 (max half + 1, capped at 3)")
		and panel.preview_label.text.contains("Scraps: 3 -> 0 (cost 3)")
		and panel.preview_label.text.contains("Deck: 2 -> 1 cards")
		and not panel.confirm_button.disabled,
		"selected fully ordered pool stitch quotes source-bound energy, currency and deck delta")
	await _activate(panel.confirm_button, keyboard)
	_check(intents.size() == 1 and visit.read_state() == source,
		"physical Confirm emits a single source-backed composite intent")
	if intents.size() != 1:
		return
	var intent := intents[0]
	var receipt := Controller.submit(visit, intent)
	_check(intent.action == "stitch" and intent.first_index == first_option.index
		and intent.second_index == second_option.index and intent.source_snapshot == source
		and receipt.ok and receipt.transaction == pair.projection
		and receipt.deck == pair.resulting_deck and receipt.deck.size() == 1
		and receipt.remaining_scraps == 0 and receipt.charged_scraps == 3
		and receipt.descriptors == {pair.stitched_id: pair.descriptor},
		"one real controller settlement preserves exactly ordered halves and single payment")
	_check_receipt(receipt, source, 3)
	_check_replay(visit, intent)


func _check_receipt(result: Dictionary, source: Dictionary, cost: int) -> void:
	_check(result.source_snapshot == source and result.source_receipt == source.receipt
		and result.visit_id == source.visit_id and result.node_id == source.node_id
		and result.consumed and result.valid and result.charged_scraps == cost, "complete typed authenticated receipt")
	# The one legitimate decision changed the ledger, so its own receipt moved on.
	_check(typeof(result.receipt) == TYPE_STRING and not result.receipt.is_empty()
		and result.receipt != source.receipt, "settled ledger carries its own advanced receipt")
	if cost == 0:
		_check(result.remaining_scraps == source.remaining_scraps and result.descriptors == source.descriptors
			and result.next_stitch_id == source.next_stitch_id, "all non-deck ledgers preserved")


func _check_replay(visit: RunSewingCircleVisit, intent: Dictionary) -> void:
	var after := visit.read_state()
	_check(Controller.submit(visit, intent) == {"ok": false} and visit.read_state() == after, "replay exact rejection and no spend")
	panel.confirm_button.pressed.emit()
	panel.leave_button.pressed.emit()
	_check(intents.size() == 1 and visit.read_state() == after, "double activation cannot emit another intent")


func _test_leave(keyboard: bool) -> void:
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	await _activate(panel.leave_button, keyboard)
	_check(intents.is_empty(), "Leave also requires confirmation")
	await _activate(panel.confirm_button, keyboard)
	_check(intents.size() == 1 and visit.read_state() == source, "Leave emits only")
	if intents.size() != 1:
		return
	var result := Controller.submit(visit, intents[0])
	var expected := source.duplicate(true)
	expected.consumed = true
	expected.merge({"ok": true, "action": "leave", "transaction": {}, "source_snapshot": source,
		"source_receipt": source.receipt, "charged_scraps": 0})
	_check(result == expected, "exact Leave receipt preserves complete ledger")
	_check_replay(visit, intents[0])


## Only this panel's own physical Confirm may mint the payload its controller
## settles: the hand-off is exact, detached and one-shot, and rebind/close retire it.
func _test_confirmation_handoff() -> void:
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	var forwarded := {"action": "leave", "first_index": -1, "second_index": -1,
		"visit_id": source.visit_id, "node_id": source.node_id, "source_snapshot": source}
	_check(panel.take_confirmed(forwarded) == {} and panel._confirmed.is_empty(),
		"no direct call can mint a confirmed payload")
	await _activate(panel.leave_button, false)
	_check(panel.take_confirmed(forwarded) == {} and panel._confirmed.is_empty() and intents.is_empty(),
		"an unconfirmed selection mints nothing and emits nothing")
	await _activate(panel.confirm_button, false)
	_check(intents.size() == 1 and panel._submitted and not panel._confirmed.is_empty(),
		"physical Confirm mints exactly one pending payload")
	if intents.size() != 1:
		return
	var confirmed := intents[0]
	var altered_action := confirmed.duplicate(true)
	altered_action.action = "upgrade"
	var altered_index := confirmed.duplicate(true)
	altered_index.first_index = 0
	var altered_snapshot := confirmed.duplicate(true)
	altered_snapshot.source_snapshot.remaining_scraps += 1
	var extra_key := confirmed.duplicate(true)
	extra_key.result = "ok"
	for altered in [altered_action, altered_index, altered_snapshot, extra_key]:
		_check(panel.take_confirmed(altered) == {} and panel._confirmed == confirmed,
			"an altered payload never matches or consumes the pending confirmation")
	var handed := panel.take_confirmed(confirmed)
	_check(handed == confirmed and panel._confirmed.is_empty(),
		"the exact confirmed payload is handed over once")
	_check(panel.take_confirmed(confirmed) == {} and panel._confirmed.is_empty(),
		"a second hand-over gets nothing")
	var second := _make()
	await _bind(second)
	await _activate(panel.upgrade_button, false)
	await _activate(panel.option_buttons[1], false)
	await _activate(panel.confirm_button, false)
	_check(intents.size() == 1 and panel._submitted and not panel._confirmed.is_empty(),
		"a fresh visit mints its own pending payload")
	if intents.size() != 1:
		return
	var pending := intents[0]
	await _bind(_make())
	_check(panel._confirmed.is_empty() and not panel._submitted and panel.take_confirmed(pending) == {},
		"rebind retires an unconsumed confirmed payload")
	await _activate(panel.leave_button, true)
	await _activate(panel.confirm_button, true)
	_check(intents.size() == 1 and not panel._confirmed.is_empty(), "a rebound visit mints its own payload")
	if intents.size() != 1:
		return
	var before_close := intents[0]
	panel.close()
	_check(not panel.visible and panel._confirmed.is_empty() and not panel._submitted
		and panel.take_confirmed(before_close) == {}, "close retires the pending confirmed payload")


## Physical number keys are only an alias for the four mounted Buttons. A valid
## press must land on the very same Button.pressed path as a mouse or Tab/Enter
## press, so each confirmed action below is compared with the authenticated
## source-bound intent and the real controller receipt.
func _test_shortcuts() -> void:
	seed(RNG_SEED)
	var seeded_next := randi()
	seed(RNG_SEED)
	# Keys 1/2/0 open the existing modes and never commit anything themselves.
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	_check(panel.upgrade_button.has_focus() and panel._active(),
		"authentic open visit on a focused mounted panel precedes the shortcuts")
	await _key(KEY_1)
	_check(panel._mode == "upgrade" and not panel.option_buttons.is_empty()
		and panel.confirm_button.disabled and intents.is_empty()
		and visit.read_state() == source, "key 1 opens Upgrade only and never commits")
	await _key(KEY_2)
	_check(panel._mode == "stitch" and panel._first == -1
		and panel.confirm_button.disabled and intents.is_empty()
		and visit.read_state() == source, "key 2 opens Stitch only and never commits")
	await _key(KEY_0)
	_check(panel._mode == "leave" and not panel.confirm_button.disabled
		and intents.is_empty() and visit.read_state() == source,
		"key 0 opens Leave only and never commits")

	# Upgrade: 1 selects the mode, the existing row navigation picks the exact
	# duplicate, and 3 presses the same Confirm the mouse/Enter route uses.
	visit = _make()
	await _bind(visit)
	source = visit.read_state()
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	await _key(KEY_1)
	_check(panel._mode == "upgrade" and panel.option_buttons.size() == 3
		and panel.confirm_button.disabled, "key 1 still requires an exact occurrence")
	var row := _row_at(1)
	if row == null:
		return
	await _activate(row, true)
	_check(panel.preview().index == 1 and not panel.confirm_button.disabled,
		"existing Tab/Enter row navigation still selects the real duplicate")
	await _key(KEY_3)
	_check(intents.size() == 1 and visit.read_state() == source,
		"key 3 confirms the chosen occurrence once without settling")
	if intents.size() != 1:
		return
	var upgrade_intent := intents[0]
	_check(upgrade_intent == {"action": "upgrade", "first_index": 1, "second_index": -1,
		"visit_id": source.visit_id, "node_id": source.node_id, "source_snapshot": source},
		"key 3 emits the same source-bound upgrade intent as mouse/Enter")
	_check(panel.take_confirmed(upgrade_intent) == upgrade_intent
		and panel.take_confirmed(upgrade_intent) == {},
		"key 3 mints the same one-shot Confirm hand-off as mouse/Enter")
	var upgrade := Controller.submit(visit, upgrade_intent)
	var oracle := RunRestCardUpgrade.new(source.deck, {STRIKE: "warden_strike_plus"}, {}, 1).choose_upgrade(1)
	_check(upgrade.ok and upgrade.action == "upgrade" and upgrade.transaction == oracle
		and upgrade.deck == [STRIKE, "warden_strike_plus", PRICK],
		"key 3 yields one authorized upgrade receipt")
	_check_receipt(upgrade, source, 0)
	_check_replay(visit, upgrade_intent)
	for key in [KEY_1, KEY_2, KEY_0, KEY_3]:
		await _key(key)
	_check(intents.size() == 1 and visit.is_consumed(),
		"no further key acts on the consumed visit")

	# Stitch: 2 opens the canonical FIRST list, the existing rows pick the ordered
	# different-owner pair, and 3 confirms exactly that pair for 3 scraps.
	visit = _make()
	await _bind(visit)
	source = visit.read_state()
	var pair := visit.stitch_preview(1, 2)
	_check(not pair.is_empty() and pair.energy_cost == 2 and pair.scrap_cost == 3,
		"independent payable ordered-pair prerequisite")
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	await _key(KEY_2)
	_check(panel._mode == "stitch" and panel.option_buttons.size() == 3
		and panel.confirm_button.disabled, "key 2 opens the canonical FIRST list")
	var first_row := _row_at(1)
	if first_row == null:
		return
	await _activate(first_row, true)
	var second_row := _row_at(2)
	if second_row == null:
		return
	await _activate(second_row, true)
	_check(panel.preview() == pair and not panel.confirm_button.disabled,
		"existing rows still select the ordered different-owner pair")
	await _key(KEY_3)
	_check(intents.size() == 1 and visit.read_state() == source,
		"key 3 confirms the shown pair once without spending")
	if intents.size() != 1:
		return
	var stitch_intent := intents[0]
	_check(stitch_intent.action == "stitch" and stitch_intent.first_index == 1
		and stitch_intent.second_index == 2 and stitch_intent.source_snapshot == source,
		"key 3 emits the exact ordered source-bound stitch intent")
	var stitch := Controller.submit(visit, stitch_intent)
	_check(stitch.ok and stitch.transaction == pair.projection
		and stitch.deck == pair.resulting_deck and stitch.remaining_scraps == 4
		and stitch.charged_scraps == 3,
		"keyboard stitch pays 3 scraps for exactly the shown authenticated halves")
	_check_receipt(stitch, source, 3)
	_check_replay(visit, stitch_intent)

	# Leave: 0 stages it and 3 commits the free one-use visit.
	visit = _make()
	await _bind(visit)
	source = visit.read_state()
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	await _key(KEY_0)
	_check(panel._mode == "leave" and not panel.confirm_button.disabled
		and intents.is_empty(), "key 0 stages free Leave")
	await _key(KEY_3)
	_check(intents.size() == 1 and visit.read_state() == source, "key 3 confirms Leave once")
	if intents.size() != 1:
		return
	var expected := source.duplicate(true)
	expected.consumed = true
	expected.merge({"ok": true, "action": "leave", "transaction": {}, "source_snapshot": source,
		"source_receipt": source.receipt, "charged_scraps": 0})
	var leave := Controller.submit(visit, intents[0])
	_check(leave == expected and leave.deck == source.deck
		and leave.remaining_scraps == source.remaining_scraps,
		"free one-use Leave keeps the deck and scraps unchanged")
	_check_replay(visit, intents[0])

	# 3 before a valid selection does nothing at all.
	visit = _make()
	await _bind(visit)
	source = visit.read_state()
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	await _key(KEY_3)
	_check(intents.is_empty() and panel.confirm_button.disabled
		and visit.read_state() == source, "3 with no mode selected does nothing")
	await _key(KEY_1)
	await _key(KEY_3)
	_check(intents.is_empty() and panel.preview().is_empty()
		and panel.confirm_button.disabled and visit.read_state() == source,
		"3 before an upgrade row is selected does nothing")
	await _key(KEY_2)
	await _key(KEY_3)
	_check(intents.is_empty() and panel._first == -1 and panel._second == -1
		and panel.confirm_button.disabled and visit.read_state() == source,
		"3 before a Stitch pair is selected does nothing")

	# A disabled action keeps its disabled shortcut: 2 under 3 scraps, and 2 with
	# no different-owner pair, while the free decisions stay reachable.
	visit = _make([STRIKE, STRIKE, PRICK], 2)
	await _bind(visit)
	source = visit.read_state()
	_check(panel.stitch_button.disabled, "two scraps leave Stitch disabled")
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	await _key(KEY_2)
	_check(panel._mode == "" and panel.option_buttons.is_empty() and intents.is_empty()
		and visit.read_state() == source, "an unaffordable Stitch ignores key 2")
	await _key(KEY_1)
	_check(panel._mode == "upgrade", "free Upgrade still opens under key 1")
	await _key(KEY_0)
	_check(panel._mode == "leave" and not panel.confirm_button.disabled,
		"free Leave still opens under key 0 beside the disabled Stitch")
	await _key(KEY_3)
	_check(intents.size() == 1 and Controller.submit(visit, intents[0]).get("ok") == true,
		"a disabled Stitch does not block the genuine Leave receipt")
	var no_pair := _make([STRIKE, STRIKE], 7)
	await _bind(no_pair)
	_check(panel.stitch_button.disabled, "no different-owner pair leaves Stitch disabled")
	await _key(KEY_2)
	_check(panel._mode == "" and intents.is_empty(),
		"no-pair Stitch ignores key 2")

	# Hidden panel, another panel's focus, releases, echo and modified keys are
	# all inert, and a real press still works afterwards.
	visit = _make()
	await _bind(visit)
	source = visit.read_state()
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	panel.hide()
	await _settle_layout()
	await _key(KEY_1)
	_check(not panel.visible and panel._mode == "" and intents.is_empty()
		and visit.read_state() == source, "a hidden panel ignores its shortcuts")
	panel.show()
	await _settle_layout()
	var outside := Control.new()
	outside.focus_mode = Control.FOCUS_ALL
	root.add_child(outside)
	await _settle_layout()
	outside.grab_focus()
	await _settle_layout()
	_check(root.gui_get_focus_owner() == outside, "another panel genuinely owns GUI focus")
	for key in [KEY_1, KEY_2, KEY_0, KEY_3]:
		await _key(key)
	_check(panel._mode == "" and intents.is_empty() and visit.read_state() == source,
		"shortcuts never take keyboard input from another panel")
	outside.queue_free()
	await _settle_layout()
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	_check(panel.upgrade_button.has_focus() and not panel.upgrade_button.disabled,
		"the panel is genuinely keyboard-live before the event guards")
	for key in [KEY_1, KEY_2, KEY_0, KEY_3]:
		await _key(key, false)
	_check(panel._mode == "" and intents.is_empty() and visit.read_state() == source,
		"key releases do nothing")
	await _key(KEY_1, true, true)
	_check(panel._mode == "" and intents.is_empty(), "auto-repeat echo does nothing")
	for modified in [{"ctrl": true}, {"alt": true}, {"shift": true}, {"meta": true}]:
		await _key(KEY_0, true, false, modified)
	_check(panel._mode == "" and intents.is_empty() and visit.read_state() == source,
		"modified keys do nothing")
	for key in [KEY_9, KEY_4, KEY_5, KEY_MINUS]:
		await _key(key)
	_check(panel._mode == "" and intents.is_empty() and visit.read_state() == source,
		"unmapped keys do nothing")
	await _key(KEY_1)
	_check(panel._mode == "upgrade" and not panel.option_buttons.is_empty(),
		"a real key press still works after the ignored events")

	# A rebind retires a staged shortcut selection, and the old payload cannot
	# settle the replacement visit.
	var pending := _make()
	await _bind(pending)
	var pending_source := pending.read_state()
	await _key(KEY_0)
	_check(panel._mode == "leave" and not panel.confirm_button.disabled,
		"a genuine staged Leave precedes the rebind")
	var rebound := _make()
	await _bind(rebound)
	var rebound_source := rebound.read_state()
	await _key(KEY_3)
	_check(intents.is_empty() and panel.confirm_button.disabled and panel.preview().is_empty()
		and rebound.read_state() == rebound_source, "rebind retires the staged Leave for key 3")
	var retired := {"action": "leave", "first_index": -1, "second_index": -1,
		"visit_id": pending_source.visit_id, "node_id": pending_source.node_id,
		"source_snapshot": pending_source}
	_check(Controller.submit(rebound, retired) == {"ok": false}
		and rebound.read_state() == rebound_source,
		"the rebound visit rejects the retired shortcut payload")
	_check(randi() == seeded_next, "keyboard routes consume no global RNG")
	seed(RNG_SEED)


func _test_rejections() -> void:
	for fixture in [[0, [STRIKE, PRICK]], [2, [STRIKE, PRICK]], [7, [STRIKE, STRIKE]]]:
		var visit := _make(fixture[1], fixture[0])
		await _bind(visit)
		var source := visit.read_state()
		_check(panel.stitch_button.disabled and not panel.upgrade_button.disabled and not panel.leave_button.disabled, "poor/no-pair keeps free decisions")
		_check(panel.option_buttons.is_empty() and panel.preview().is_empty()
			and panel.preview_label.text == "Choose Upgrade or Leave, then confirm."
			and panel.confirm_button.disabled, "unavailable Stitch has a neutral unselected preview")
		_check(panel.status_label.text.contains("Insufficient") if fixture[0] < 3 else panel.status_label.text.contains("No different-owner"), "reason visibly explained")
		panel.stitch_button.pressed.emit()
		panel.confirm_button.pressed.emit()
		_check(intents.is_empty() and visit.read_state() == source, "disabled/forged activation no mutation")
		var bad := {"action": "stitch", "first_index": 0, "second_index": 1, "visit_id": source.visit_id, "node_id": source.node_id, "source_snapshot": source}
		_check(Controller.submit(visit, bad) == {"ok": false} and visit.read_state() == source, "poor/no-pair exact rejection receipt")
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	await _activate(panel.upgrade_button, false)
	var prior_row: Button = panel.option_buttons[1]
	var retired_row: Callable = prior_row.pressed.get_connections()[0].callable
	await _activate(panel.stitch_button, false)
	var stage_rows: int = panel._rows_epoch
	retired_row.call()
	_check(not is_instance_valid(prior_row) or (prior_row.get_parent() == null
		and prior_row.is_queued_for_deletion()), "retired Help is detached from active scroll and focus")
	_check(panel._rows_epoch == stage_rows and panel._first == -1 and panel.preview().is_empty()
		and panel.confirm_button.disabled and visit.read_state() == source,
		"mode switch retires old occurrence callback without substituting a legal stitch index")
	await _activate(panel.option_buttons[0], false)
	var retired_partner: Callable = panel.option_buttons[0].pressed.get_connections()[0].callable
	await _activate(panel.stitch_button, false)
	retired_partner.call()
	_check(panel._first == -1 and panel._second == -1 and panel.confirm_button.disabled,
		"restarting Stitch retires old first-stage callbacks")
	var hidden_options := panel.option_buttons.size()
	panel.hide()
	var hidden_mode: Callable = panel.upgrade_button.pressed.get_connections()[0].callable
	hidden_mode.call()
	_check(not panel.visible and panel._mode == "stitch" and panel.option_buttons.size() == hidden_options
		and panel.confirm_button.disabled, "hidden controls cannot recreate or authorize options")
	panel.show()
	await _activate(panel.upgrade_button, false)
	var stale_select: Callable = panel.option_buttons[1].pressed.get_connections()[0].callable
	panel._select(99, panel._epoch)
	_check(panel.confirm_button.disabled and panel.preview().is_empty() and visit.read_state() == source, "bad occurrence cannot confirm or spend")
	await _activate(panel.option_buttons[1], false)
	var stale_confirm: Callable = panel.confirm_button.pressed.get_connections()[0].callable
	await _activate(panel.confirm_button, false)
	_check(intents.size() == 1, "captured genuine pending intent")
	if intents.is_empty():
		return
	var old := intents[0].duplicate(true)
	var replacement := _make()
	await _bind(replacement)
	var replacement_source := replacement.read_state()
	stale_select.call()
	stale_confirm.call()
	_check(intents.is_empty() and panel.preview().is_empty() and panel.confirm_button.disabled, "rebind retires callbacks and selection")
	_check(Controller.submit(replacement, old) == {"ok": false} and replacement.read_state() == replacement_source and visit.read_state() == source, "rebound intent rejects with both ledgers unchanged")
	for indices in [[-1, 2], [0, 0], [0, 1], [99, 2]]:
		var bad := old.duplicate(true)
		bad.action = "stitch"
		bad.first_index = indices[0]
		bad.second_index = indices[1]
		_check(Controller.submit(visit, bad) == {"ok": false} and visit.read_state() == source, "bad/same-owner selection exact rejection")
	var forged := old.duplicate(true)
	forged.source_snapshot.remaining_scraps += 1
	_check(Controller.submit(visit, forged) == {"ok": false} and visit.read_state() == source, "tampered source no-spend")
	panel.close()
	stale_select.call()
	stale_confirm.call()
	_check(not panel.visible and panel.preview().is_empty() and intents.is_empty()
		and replacement.read_state() == replacement_source, "close retires callbacks without mutation")
	await _bind(replacement)
	await _activate(panel.leave_button, true)
	var pending_confirm: Callable = panel.confirm_button.pressed.get_connections()[0].callable
	var external := replacement.leave(replacement_source.visit_id, replacement_source.node_id, replacement_source)
	_check(external.ok, "genuine external settlement prerequisite")
	var settled := replacement.read_state()
	pending_confirm.call()
	_check(intents.is_empty() and replacement.read_state() == settled and panel.confirm_button.disabled
		and panel.option_buttons.is_empty() and panel.preview().is_empty()
		and panel.preview_label.text == "Choose Upgrade, Stitch or Leave, then confirm.",
		"consumed authority retires stale preview and disables confirmation without spend")
	var invalid := RunSewingCircleVisit.new("circle-invalid", ["not_a_card"], {}, 3, 1)
	_check(not invalid.is_valid(), "malformed visit cannot produce genuine options")
	panel.bind(invalid)
	await _settle_layout()
	_check(panel.option_buttons.is_empty() and panel.preview().is_empty()
		and panel.confirm_button.disabled and panel.upgrade_button.disabled
		and panel.stitch_button.disabled and panel.leave_button.disabled
		and panel.preview_label.text == "Choose Upgrade, Stitch or Leave, then confirm.",
		"invalid source binding retires all active choice Help and Confirm")


## ART v3: the already-authored sewn panel image is this stop's only animated
## decoration. One input-inert, clipped, faint copy of reward_panel.png breathes
## and drifts behind the fixed cream felt, labels, scrollers, buttons and focus
## rectangles; nothing else ever moves, and every stop path restores the exact
## static baseline. The whole session runs with the panel's own _process off,
## so only the forced deterministic deltas below can accumulate.
func _test_art_motion() -> void:
	var baseline := {"scale": 1.0, "offset": Vector2.ZERO}
	var art: Texture2D = panel.panel_art_texture
	_check(art != null and art.resource_path == LiveSewingCirclePanel.PANEL_ART,
		"mounted Sewing Circle loads the already-present authored panel art")
	_check(Rect2(0, 0, 1280, 720).encloses(panel.get_global_rect())
		and panel.size == Vector2(940, 620),
		"the framed 940x620 panel stays inside the 1280x720 viewport")
	var backing: Control = panel.get_child(0)
	_check(backing is Panel and backing.clip_contents
		and panel._art_drift != null and panel._art_drift.get_parent() == backing
		and panel._art_drift.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and panel._art_drift.focus_mode == Control.FOCUS_NONE,
		"animated art is a clipped, input-inert layer under the first-child felt backing")
	if art == null or panel._art_drift == null:
		return
	# Pure presentation transform: exact static baseline at zero and at every
	# shared period, a ~1% breath on 7 s and a 3 x 2 px drift on 11 s at most.
	_check(LiveSewingCirclePanel.art_motion_transform_at(0.0) == baseline
		and LiveSewingCirclePanel.art_motion_transform_at(LiveSewingCirclePanel.PANEL_ART_BREATH_PERIOD
			* LiveSewingCirclePanel.PANEL_ART_PAN_PERIOD) == baseline,
		"presentation motion is exactly at rest at elapsed zero and at every shared period")
	var breath_peak: Dictionary = LiveSewingCirclePanel.art_motion_transform_at(3.5)
	var pan_peak: Dictionary = LiveSewingCirclePanel.art_motion_transform_at(2.75)
	var pan_rest: Dictionary = LiveSewingCirclePanel.art_motion_transform_at(5.5)
	var pan_peak_offset: Vector2 = pan_peak["offset"]
	var pan_rest_offset: Vector2 = pan_rest["offset"]
	_check(absf(float(breath_peak["scale"]) - 1.012) < 0.0005
		and absf(pan_peak_offset.x - LiveSewingCirclePanel.PANEL_ART_PAN.x) < 0.001
		and absf(float(LiveSewingCirclePanel.art_motion_transform_at(7.0)["scale"]) - 1.0) < 0.0001
		and absf(pan_rest_offset.x) < 0.001,
		"approximately 1% scale breath and 2-4 px drift on repeatable periods")
	_check(LiveSewingCirclePanel.art_motion_transform_at(4.0) == LiveSewingCirclePanel.art_motion_transform_at(4.0)
		and LiveSewingCirclePanel.art_motion_transform_at(4.0) != LiveSewingCirclePanel.art_motion_transform_at(5.0),
		"the presentation transform is deterministic and reproducible")
	var layer_rect := Rect2(panel._art_drift_base, panel._art_drift.size)
	var frame := Rect2(Vector2.ZERO, panel.size)
	var no_edge := true
	for step in range(221):
		var motion := LiveSewingCirclePanel.art_motion_transform_at(float(step) * 0.5)
		var scale: float = motion["scale"]
		var offset: Vector2 = motion["offset"]
		var half := layer_rect.size * (scale - 1.0) * 0.5
		var drawn := Rect2(layer_rect.position + offset - half, layer_rect.size * scale)
		if not drawn.encloses(frame):
			no_edge = false
	_check(no_edge,
		"the drifting copy stays oversized and clipped for the whole cycle, so no image edge is exposed")
	# Deterministic presentation-delta test on the mounted 1280x720 panel.
	panel.set_process(false)
	var visit := _make()
	await _bind(visit)
	var source := visit.read_state()
	var quote := visit.quote()
	await _activate(panel.upgrade_button, false)
	_check(panel.art_motion_active() and panel.art_motion_transform() == baseline
		and panel._art_drift.scale == Vector2.ONE
		and panel._art_drift.position == panel._art_drift_base,
		"a freshly bound authentic visit starts at the exact static baseline")
	var focused: Control = root.gui_get_focus_owner()
	var panel_rect := panel.get_global_rect()
	var status_rect := panel.status_label.get_global_rect()
	var preview_rect := panel.preview_label.get_global_rect()
	var choice_rect := panel.choice_scroll.get_global_rect()
	var preview_scroll_rect := panel.preview_scroll.get_global_rect()
	var upgrade_rect := panel.upgrade_button.get_global_rect()
	var stitch_rect := panel.stitch_button.get_global_rect()
	var leave_rect := panel.leave_button.get_global_rect()
	var confirm_rect := panel.confirm_button.get_global_rect()
	var row_rect := panel.option_buttons[0].get_global_rect()
	var scroll_offset := panel.choice_scroll.scroll_vertical
	panel.advance_art_motion(2.0)
	var moved := panel.art_motion_transform()
	var moved_offset: Vector2 = moved["offset"]
	_check(moved == LiveSewingCirclePanel.art_motion_transform_at(2.0) and moved != baseline
		and float(moved["scale"]) > 1.0
		and float(moved["scale"]) - 1.0 <= LiveSewingCirclePanel.PANEL_ART_BREATH
		and moved_offset != Vector2.ZERO
		and moved_offset.length() <= LiveSewingCirclePanel.PANEL_ART_PAN.length(),
		"accumulated presentation delta alone drives the restrained decorative transform")
	panel.advance_art_motion(2.0)
	_check(panel.art_motion_transform() == LiveSewingCirclePanel.art_motion_transform_at(4.0)
		and panel.art_motion_transform() != moved,
		"presentation time accumulates deterministically from the forced deltas")
	var applied := panel.art_motion_transform()
	var applied_offset: Vector2 = applied["offset"]
	_check(panel._art_drift.scale == Vector2.ONE * float(applied["scale"])
		and panel._art_drift.position == panel._art_drift_base + applied_offset,
		"only the decorative layer's own position and scale follow the transform")
	_check(panel.get_global_rect() == panel_rect
		and panel.status_label.get_global_rect() == status_rect
		and panel.preview_label.get_global_rect() == preview_rect
		and panel.choice_scroll.get_global_rect() == choice_rect
		and panel.preview_scroll.get_global_rect() == preview_scroll_rect
		and panel.upgrade_button.get_global_rect() == upgrade_rect
		and panel.stitch_button.get_global_rect() == stitch_rect
		and panel.leave_button.get_global_rect() == leave_rect
		and panel.confirm_button.get_global_rect() == confirm_rect
		and panel.option_buttons[0].get_global_rect() == row_rect
		and panel.size == Vector2(940, 620)
		and panel.upgrade_button.position == Vector2(24, 62)
		and panel.confirm_button.position == Vector2(24, 556),
		"the 940x620 panel, labels, scrollers, buttons and hit rectangles never move")
	_check(root.gui_get_focus_owner() == focused and focused == panel.option_buttons[0]
		and panel.choice_scroll.scroll_vertical == scroll_offset
		and visit.read_state() == source and visit.quote() == quote
		and not visit.is_consumed() and intents.is_empty(),
		"motion never moves focus or scroll and never reads, spends or consumes the visit")
	# ProjectSettings accessibility/reduced_motion (default false), restored after.
	var prior: Variant = ProjectSettings.get_setting(LiveSewingCirclePanel.REDUCED_MOTION_SETTING, false)
	ProjectSettings.set_setting(LiveSewingCirclePanel.REDUCED_MOTION_SETTING, true)
	panel.advance_art_motion(5.0)
	_check(panel.art_motion_transform() == baseline and panel._art_drift.scale == Vector2.ONE
		and panel._art_drift.position == panel._art_drift_base,
		"accessibility/reduced_motion keeps the authored art exactly static at its baseline")
	ProjectSettings.set_setting(LiveSewingCirclePanel.REDUCED_MOTION_SETTING, prior)
	_check(not panel._reduced_motion_active(), "prior reduced-motion setting restored afterward")
	# Nullable explicit override for focused tests and hosts.
	panel.set_reduced_motion_override(true)
	_check(not panel.art_motion_active() and panel.art_motion_transform() == baseline
		and panel._art_drift.position == panel._art_drift_base,
		"an explicit reduced-motion override restores the exact static baseline immediately")
	panel.advance_art_motion(4.0)
	_check(panel.art_motion_transform() == baseline,
		"no presentation time accumulates while the explicit override is true")
	panel.set_reduced_motion_override(false)
	_check(panel.art_motion_active() and panel.art_motion_transform() == baseline,
		"lifting the override resumes only from the static baseline")
	panel.advance_art_motion(2.0)
	_check(panel.art_motion_transform() == LiveSewingCirclePanel.art_motion_transform_at(2.0),
		"motion resumes only through fresh presentation time after the override lifts")
	ProjectSettings.set_setting(LiveSewingCirclePanel.REDUCED_MOTION_SETTING, true)
	panel.set_reduced_motion_override(null)
	_check(panel._reduced_motion_active() and panel.art_motion_transform() == baseline,
		"a lifted override follows the ProjectSettings reduced-motion request again")
	ProjectSettings.set_setting(LiveSewingCirclePanel.REDUCED_MOTION_SETTING, prior)
	# Hide / show keeps the panel and its choices exactly where they are.
	panel.advance_art_motion(2.0)
	_check(panel.art_motion_transform() != baseline, "art is genuinely moving before hiding")
	panel.hide()
	await _settle_layout()
	_check(panel.art_motion_transform() == baseline and panel._art_drift.position == panel._art_drift_base,
		"a hidden panel restores the exact static baseline")
	panel.advance_art_motion(3.0)
	_check(panel.art_motion_transform() == baseline, "a hidden panel accumulates no motion")
	panel.show()
	_check(panel.art_motion_transform() == baseline and panel._art_drift.scale == Vector2.ONE,
		"the shown panel resumes only from the static baseline")
	await _settle_layout()
	# bind(null), close() and a fresh rebind all restart from the baseline.
	panel.advance_art_motion(2.0)
	_check(panel.art_motion_transform() != baseline, "art is genuinely moving before bind(null)")
	panel.bind(null)
	_check(not panel.art_motion_active() and panel.art_motion_transform() == baseline
		and panel._art_drift.position == panel._art_drift_base,
		"bind(null) stops and restores the exact static baseline")
	panel.advance_art_motion(7.0)
	_check(panel.art_motion_transform() == baseline, "a panel without a source accumulates no motion")
	var closing := _make()
	await _bind(closing)
	panel.advance_art_motion(3.0)
	_check(panel.art_motion_transform() != baseline, "art is genuinely moving before close()")
	panel.close()
	await _settle_layout()
	_check(not panel.is_visible_in_tree() and not panel.art_motion_active()
		and panel.art_motion_transform() == baseline
		and panel._art_drift.position == panel._art_drift_base
		and panel.upgrade_button.disabled and panel.confirm_button.disabled,
		"close() stops and restores the exact static baseline on a closed panel")
	panel.advance_art_motion(7.0)
	_check(panel.art_motion_transform() == baseline,
		"no old motion resumes on the closed panel")
	await _bind(_make())
	_check(panel.art_motion_active() and panel.art_motion_transform() == baseline
		and panel._art_drift.scale == Vector2.ONE,
		"a new authentic bind restarts the art from the exact static baseline")
	panel.advance_art_motion(3.0)
	_check(panel.art_motion_transform() != baseline, "art moves on the rebound authentic visit")
	await _bind(_make())
	_check(panel.art_motion_transform() == baseline and panel._art_drift.position == panel._art_drift_base,
		"rebinding yet another visit restarts the art at the static baseline")
	# Equal accumulated delta yields one identical transform regardless of how
	# it was grouped, and the shared period returns exactly to the baseline.
	await _activate(panel.upgrade_button, false)
	panel.advance_art_motion(1.0)
	panel.advance_art_motion(3.0)
	var grouped := panel.art_motion_transform()
	await _bind(_make())
	await _activate(panel.upgrade_button, false)
	panel.advance_art_motion(4.0)
	_check(panel.art_motion_transform() == grouped
		and grouped == LiveSewingCirclePanel.art_motion_transform_at(4.0),
		"equal accumulated delta yields the same transform independent of step grouping")
	panel.advance_art_motion(LiveSewingCirclePanel.PANEL_ART_BREATH_PERIOD
		* LiveSewingCirclePanel.PANEL_ART_PAN_PERIOD - 4.0)
	_check(panel.art_motion_transform() == baseline,
		"the motion returns exactly to the static baseline at every shared period")
	# Invalid, consumed, stale and self-submitted sources never animate.
	var invalid := RunSewingCircleVisit.new("circle-motion-invalid", ["not_a_card"], {}, 3, 1)
	_check(not invalid.is_valid(), "malformed visit prerequisite")
	panel.bind(invalid)
	await _settle_layout()
	panel.advance_art_motion(4.0)
	_check(not panel.art_motion_active() and panel.art_motion_transform() == baseline
		and panel._art_drift.position == panel._art_drift_base,
		"an invalid visit never animates the authored art")
	var already := _make()
	var already_state := already.read_state()
	_check(already.leave(already_state.visit_id, already_state.node_id, already_state).ok,
		"already-used real visit prerequisite")
	panel.bind(already)
	await _settle_layout()
	panel.advance_art_motion(4.0)
	_check(not panel.art_motion_active() and panel.art_motion_transform() == baseline,
		"a consumed visit never animates the authored art")
	var stale := _make()
	await _bind(stale)
	panel.advance_art_motion(1.0)
	_check(panel.art_motion_transform() != baseline, "art moves while the bound visit is genuinely open")
	var stale_state := stale.read_state()
	_check(stale.leave(stale_state.visit_id, stale_state.node_id, stale_state).ok,
		"external owner really consumed the animated visit")
	panel.advance_art_motion(1.0)
	_check(not panel.art_motion_active() and panel.art_motion_transform() == baseline
		and panel._art_drift.position == panel._art_drift_base,
		"an externally consumed source stops the art at the static baseline")
	# The panel's own used Confirm is also a stop path, and the very same
	# mouse and number-key routes keep emitting one authentic intent while the
	# art is genuinely moving.
	var moving := _make()
	await _bind(moving)
	var moving_source := moving.read_state()
	panel.advance_art_motion(2.5)
	await _activate(panel.leave_button, false)
	await _activate(panel.confirm_button, false)
	_check(intents.size() == 1 and intents[0].action == "leave"
		and intents[0].source_snapshot == moving_source
		and panel._submitted and not panel.art_motion_active()
		and panel.art_motion_transform() == baseline
		and panel._art_drift.position == panel._art_drift_base,
		"a real mouse Leave still confirms one source-bound intent and stops the art at baseline")
	await _bind(_make())
	panel.advance_art_motion(2.0)
	panel.upgrade_button.grab_focus()
	await _settle_layout()
	await _key(KEY_0)
	await _key(KEY_3)
	_check(intents.size() == 1 and intents[0].action == "leave",
		"number keys 0 and 3 still confirm one Leave while the art animates")
	# Missing optional artwork keeps today's static readable fallback.
	var saved_art: Texture2D = panel.panel_art_texture
	panel.panel_art_texture = null
	await _bind(_make())
	panel.advance_art_motion(5.0)
	_check(not panel.art_motion_active() and panel.art_motion_transform() == baseline,
		"missing optional art keeps the exact static baseline transform")
	_check(backing is Panel and backing.get_theme_stylebox("panel") != null
		and panel.is_visible_in_tree() and not panel.upgrade_button.disabled
		and not panel.stitch_button.disabled and not panel.leave_button.disabled
		and panel.status_label.text.contains("3 scraps"),
		"missing art retains today's readable, actionable static sewn panel")
	panel.panel_art_texture = saved_art
	await _bind(_make())
	panel.advance_art_motion(2.0)
	_check(panel.art_motion_active()
		and panel.art_motion_transform() == LiveSewingCirclePanel.art_motion_transform_at(2.0),
		"restored authored art animates again from the static baseline")
	panel.set_process(true)


## Measured against the shipped font: a printed shortcut must fit the sewn
## button it names, at the same 18px size the screen uses.
func _fits(button: Button) -> bool:
	var font := button.get_theme_font("font")
	if font == null or button.text.is_empty():
		return false
	var font_size := button.get_theme_font_size("font_size")
	if font_size < 18:
		return false
	var width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return width <= button.size.x - 16.0 and button.size.y >= font.get_height(font_size) * 1.4


## Inspect visible label nodes, not the Button's retained accessibility text.
func _card_ink(button: Button) -> String:
	var lines: PackedStringArray = []
	for node in button.find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	return "\n".join(lines)


func _compact_ink(button: Button, card: Dictionary, index: int, after: Dictionary = {}) -> bool:
	var summary := "Free upgrade: %s | %d energy" % [after.display_name, after.cost] if not after.is_empty() else \
		"%s | Stitch pair: %d scraps" % ["FIRST" if panel._first < 0 else "THEN", RunRestStitchCards.SCRAP_COST]
	return not card.is_empty() and _card_ink(button) == "%s | copy #%d\n%s\n%d energy\n%s" % [
		str(card.owner).capitalize(), index + 1, card.display_name, card.cost, summary]


## The full Button caption is intentionally transparent; assert the actual
## Label glyph geometry against its painted ticket/row, not its hidden text.
## This covers exact, source-authentic Upgrade, FIRST and THEN snapshots,
## including rows rebuilt after owner filtering or scrolled into focus.
func _assert_visible_action(button: Button, option: Dictionary, upgrade: bool) -> void:
	var labels := button.find_children("*", "Label", true, false)
	_check(labels.size() == 4, "mounted row has four real visible ink labels")
	if labels.size() != 4:
		return
	var identity: Label = labels[0]
	var name: Label = labels[1]
	var energy: Label = labels[2]
	var outcome: Label = labels[3]
	var expected_result := "Free upgrade: %s | %d energy" % [option.plus_display_name, option.plus_cost] if upgrade else \
		"%s | Stitch pair: %d scraps" % ["FIRST" if panel._first < 0 else "THEN", RunRestStitchCards.SCRAP_COST]
	_check(identity.text == "%s | copy #%d" % [str(option.owner).capitalize(), option.index + 1]
		and name.text == str(option.get("display_name", option.get("name", "")))
		and energy.text == "%d energy" % option.cost
		and outcome.text == expected_result,
		"visible identity, energy and free/3-scrap outcome are from the actual bound option")
	var row_ink := button.get_global_rect().grow(-4)
	var ticket := energy.get_parent() as Panel
	_check(ticket != null and row_ink.encloses(outcome.get_global_rect())
		and row_ink.encloses(name.get_global_rect())
		and row_ink.encloses(identity.get_global_rect()),
		"actual identity, complete name and result labels remain inset in painted row")
	if ticket != null:
		_check(ticket.get_global_rect().grow(-2).encloses(energy.get_global_rect())
			and row_ink.encloses(ticket.get_global_rect()),
			"18px current-energy label remains inset in its painted ticket")
	for label: Label in labels:
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		if font == null:
			_check(false, "action label has a real mounted font")
			continue
		var glyphs := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, label.size.x, font_size)
		_check(font_size >= 18 and label.get_line_count() > 0
			and glyphs.x <= label.size.x + 1.0 and glyphs.y <= label.size.y + 1.0
			and label.get_line_count() * font.get_height(font_size) <= label.size.y + 1.0,
			"18px+ visible multiline font glyphs fit label width and height: " + label.text)
func _assert_decorations(button: Button) -> void:
	_check(button.focus_mode == Control.FOCUS_ALL and button.mouse_filter == Control.MOUSE_FILTER_STOP,
		"canonical option Button alone owns click and keyboard focus")
	var children := button.find_children("*", "Control", true, false)
	_check(children.size() >= 5, "real sewn labels, seam and cost coin exist")
	for child in children:
		var control: Control = child
		_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE and control.focus_mode == Control.FOCUS_NONE,
			"every decorative descendant ignores pointer and cannot take focus")
		_check(Rect2(Vector2.ZERO, button.size).has_point(control.position) or control.get_parent() != button,
			"each top-level ink decoration starts within its canonical card")
	var labels := button.find_children("*", "Label", true, false)
	_check(labels.size() == 4, "compact identity, name, cost and summary replace repeated rules")
	for label: Label in labels:
		var font_size := label.get_theme_font_size("font_size")
		_check(font_size >= 18 and button.get_global_rect().encloses(label.get_global_rect())
			and label.get_line_count() * label.get_theme_font("font").get_height(font_size) <= label.size.y,
			"all visible card ink uses body-size text and fits inside the compact row")
		for other: Label in labels:
			if other != label:
				_check(not label.get_global_rect().intersects(other.get_global_rect()),
					"compact identity, title, cost and summary never overlap")
