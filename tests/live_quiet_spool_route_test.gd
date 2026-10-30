extends "res://tests/live_event_treasure_continuation_test.gd"


## Physical pointer hover that never presses, so the routed Event tickets can be
## inspected for their read-only hover text without committing anything.
func _hover(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames()


## AC2: every mounted Event choice panel shows the committed crossroads scene above its
## own opaque slate, behind the paper panel and its usable choices. The choice scene now
## ships its own inert EventBackdrop picture layer, so the app's VisitBackdrop art bed is
## identified by its bind API instead of by that occupied name.
func _live_event_art_bed(panel):
	for child in panel.get_children():
		if child.has_method("bind_visit"):
			return child
	return null


func _check_event_backdrop(panel, label: String) -> int:
	_check_event_tickets(panel, label)
	var bed = _live_event_art_bed(panel)
	var slate = panel.get_node_or_null("SlateBackdrop")
	_check(is_instance_valid(bed) and bed.get_parent() == panel
		and bed.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and bed.focus_mode == Control.FOCUS_NONE,
		label + " mounts one inert Event art bed")
	if not is_instance_valid(bed):
		return panel.get_instance_id()
	var expected := "res://assets/paper/backgrounds/event_crossroads.png"
	_check(VISIT_ART.visit_backdrop_path("Event") == expected and bed.visit_kind == "Event"
		and bed.has_image() == ResourceLoader.exists(expected)
		and (not bed.has_image() or bed.visit_texture.resource_path == expected),
		label + " draws the committed crossroads scene, not the plain slate")
	_check(slate != null and bed.get_index() > slate.get_index()
		and bed.get_index() < panel.paper_panel.get_index(),
		label + " art layer sits above the opaque slate and behind the paper choices")
	var view: Rect2 = bed.view_rect()
	_check(view.size.x > 0.0 and view.size.y > 0.0
		and Rect2(Vector2.ZERO, panel.size).is_equal_approx(view)
		and Rect2(0, 0, 1280, 720).encloses(bed.get_global_rect()),
		label + " art bed fills the whole Event screen")
	var drawn: Rect2 = bed.image_rect()
	var visible: Rect2 = bed.image_crop()
	var pixels: Vector2 = bed.texture_size()
	_check(bed.has_image() and drawn.encloses(view)
		and is_equal_approx(drawn.size.x / drawn.size.y, pixels.x / pixels.y),
		label + " crossroads scene covers the view without stretching")
	_check(visible.position.x >= 0.0 and visible.position.y >= 0.0
		and visible.end.x <= pixels.x + 0.01 and visible.end.y <= pixels.y + 0.01
		and is_equal_approx(visible.size.x * (drawn.size.x / pixels.x), view.size.x),
		label + " crossroads scene crops only the centred window that fills the view")
	# The shipped scene also carries its own inert picture layer; it must sit behind
	# the parchment and above the slate, and it shows only when the committed file
	# resolves (never a new asset, never a stretched frame).
	var art = panel.get_node_or_null("EventBackdrop")
	_check(art is TextureRect and art.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and art.focus_mode == Control.FOCUS_NONE and slate != null
		and art.get_index() > slate.get_index() and art.get_index() < panel.paper_panel.get_index()
		and art.visible == ResourceLoader.exists(expected)
		and art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		label + " keeps the panel's own inert crossroads layer behind the paper")
	return panel.get_instance_id()


## Inspect the real routed panel, including the extra Moth/Dye selector that
## is absent from standalone fixtures. Gameplay assertions below still drive
## actual mouse/keyboard commits and protect every ledger and rejected input.
func _check_event_tickets(panel: LiveEventChoicePanel, label: String) -> void:
	var expected := {
		"quiet_spool": ["Scraps +1", "No change to gold or scraps."],
		"moth_infestation": ["Scraps +2", "Scraps -1", "No change to gold or scraps."],
		"dye_vat": ["Scraps -3", "Scraps +1", "No change to gold or scraps."],
	}
	_check(panel.has_open_event() and panel._selector != null, label + " real offering exists")
	if panel._selector == null:
		return
	var record: Dictionary = panel._selector.get_event()
	_check(panel.choices_container.size_flags_vertical & Control.SIZE_EXPAND == 0,
		label + " choices take content height without expansion")
	_check(panel.description_label.custom_minimum_size == Vector2.ZERO
		and panel.description_label.size_flags_vertical & Control.SIZE_EXPAND == 0
		and panel.description_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		label + " live description wraps naturally without a reserved block")
	_check(panel.description_label.text == record.get("description")
		and panel.title_label.text == record.get("title"), label + " complete authored story mounted")
	_check(panel.description_label.get_index() < panel.choices_container.get_index()
		and panel.bottom_stitches.get_index() > panel.choices_container.get_index(),
		label + " story, choices and bottom stitches in content order")
	_check_centred_column(panel, label)
	var picker_name: String = {"moth_infestation": "MothCardPickerBox", "dye_vat": "DyeVatPickerBox"}.get(record.get("id"), "")
	if not picker_name.is_empty():
		var box := panel.choices_container.get_node_or_null(picker_name)
		_check(box != null and box == panel.choices_container.get_child(0), label + " real selector precedes tickets")
		if box != null:
			var pickers := box.find_children("*", "ItemList", false, false)
			_check(pickers.size() == 1 and pickers[0].is_visible_in_tree(), label + " actual card picker visible")
	var impacts: Array = expected.get(record.get("id"), [])
	var choices: Array = record.get("choices", [])
	var buttons := panel.get_choice_buttons()
	var cues := panel.get_choice_cues()
	_check(not impacts.is_empty() and buttons.size() == impacts.size()
		and choices.size() == impacts.size() and cues.size() == impacts.size(),
		label + " all authored tickets and cues actually mounted")
	if impacts.is_empty() or buttons.size() != impacts.size() or cues.size() != impacts.size() \
		or choices.size() != impacts.size():
		return
	var viewport := Rect2(0, 0, 1280, 720)
	_check(viewport.encloses(panel.paper_panel.get_global_rect()), label + " paper fits viewport")
	for i in range(buttons.size()):
		var button: Button = buttons[i]
		_check(button.text == String(choices[i]["text"]) + "\n" + impacts[i],
			label + " exact authored action and wallet impact " + str(i))
		_check(button.is_visible_in_tree() and viewport.encloses(button.get_global_rect()),
			label + " whole two-line ticket visible " + str(i))
		_check(button.disabled or button.focus_mode == Control.FOCUS_ALL,
			label + " allowed choices remain focusable " + str(i))
		var font := button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		var style := button.get_theme_stylebox("normal")
		_check_event_ticket_skin(button, label + str(i))
		var rect := button.get_global_rect()
		var text_width: float = rect.size.x - style.content_margin_left - style.content_margin_right
		var text_height: float = rect.size.y - style.content_margin_top - style.content_margin_bottom
		# Measure the real mounted ticket: its authored action wraps at its own
		# content width, so the whole wrapped block (action plus wallet impact)
		# must fit that measured area instead of one unwrapped line.
		var wrapped := font.get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER,
			text_width, font_size)
		_check(wrapped.x <= text_width + 0.5 and wrapped.y <= text_height + 0.5,
			label + " wrapped action and impact fit its ticket " + str(i))
		for line in button.text.split("\n"):
			for word in line.split(" ", false):
				_check(font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= text_width,
					label + " every written word fits the ticket width " + str(i))
		_check(cues[i].text == str(i + 1) and cues[i].is_visible_in_tree()
			and rect.encloses(cues[i].get_global_rect())
			and cues[i].get_global_rect().end.x <= rect.position.x + style.content_margin_left,
			label + " number cue visible and clear of caption " + str(i))
		for sibling in panel.choices_container.get_children():
			if sibling != button and sibling is Control and sibling.is_visible_in_tree():
				_check(not rect.intersects(sibling.get_global_rect()),
					label + " ticket clears other choices and selector " + str(i))
		_check(not rect.intersects(panel.bottom_stitches.get_global_rect())
			and not rect.intersects(panel.description_label.get_global_rect()),
			label + " ticket clears description and bottom stitches " + str(i))


## AC1: the real routed parchment presents one centred, readable story column
## instead of leaving its title, story and tickets in the left third. The equal
## sewn pads on the ColumnMargin centre the stack, and its live width is the
## bounded readable measure from the mounted scroll viewport; the relay's
## 1280x720 capture confirms the final appearance.
func _check_centred_column(panel: LiveEventChoicePanel, label: String) -> void:
	var column := panel.column_margin
	_check(column != null and panel.event_content.get_parent() == column
		and column.get_parent() == panel.story_scroll,
		label + " story column keeps the existing parchment hierarchy")
	if column == null:
		return
	var pad_left := column.get_theme_constant("margin_left")
	var pad_right := column.get_theme_constant("margin_right")
	_check(pad_left > 0 and pad_left == pad_right,
		label + " equal sewn margins centre the story column")
	_check((column.size_flags_horizontal & Control.SIZE_EXPAND) != 0
		and (panel.event_content.size_flags_horizontal & Control.SIZE_EXPAND) != 0,
		label + " story column fills that measure instead of its caption width")
	var bar := panel.story_scroll.get_v_scroll_bar()
	var bar_width := bar.size.x if bar != null and bar.is_visible_in_tree() else 0.0
	var measure := minf(panel.story_scroll.size.x - bar_width, panel.MAX_COLUMN_WIDTH)
	_check(panel.event_content.size.x >= panel.event_content.get_combined_minimum_size().x
		and absf(panel.event_content.size.x - measure) <= 1.0,
		label + " story column keeps the bounded readable measure without clipping")
	_check(panel.title_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
		and panel.title_label.get_combined_minimum_size().x <= panel.event_content.size.x + 0.5,
		label + " title stays centred in the column, wrapping instead of stretching the paper")
	for ticket in panel.get_choice_buttons():
		_check(ticket.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
			label + " ticket wraps inside the centred story column")


func _check_event_ticket_skin(button: Button, label: String) -> void:
	var faces: Array[Color] = []
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state)
		var face := Color.BLACK
		if ResourceLoader.exists("res://assets/paper/ui/reward_button.png"):
			_check(style is StyleBoxTexture, label + " art-backed " + state)
			if style is StyleBoxTexture:
				var sewn := style as StyleBoxTexture
				_check(sewn.texture != null and sewn.texture.resource_path == "res://assets/paper/ui/reward_button.png"
					and sewn.texture_margin_left > 0 and sewn.texture_margin_right > 0
					and sewn.texture_margin_top > 0 and sewn.texture_margin_bottom > 0,
					label + " exact nine-slice fabric " + state)
				if sewn.texture != null:
					var image := sewn.texture.get_image()
					face = image.get_pixel(image.get_width() / 2, image.get_height() / 2) * sewn.modulate_color
		else:
			_check(style is StyleBoxFlat, label + " readable missing-art face " + state)
			if style is StyleBoxFlat:
				face = (style as StyleBoxFlat).bg_color
		var ink_name: String = "font_color" if state == "normal" else "font_" + state + "_color"
		_check(_ticket_contrast(button.get_theme_color(ink_name), face) >= 4.5, label + " readable " + state)
		faces.append(face)
	_check(faces[0] != faces[1] and faces[0] != faces[2] and faces[0] != faces[3], label + " distinct ticket states")
	var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
	_check(focus != null and not focus.draw_center and focus.border_width_left >= 3,
		label + " visible keyboard ring without covering text")
	if focus != null:
		_check(_ticket_contrast(focus.border_color, faces[0]) >= 3.0, label + " contrasting focus ring")
	_check(_ticket_contrast(button.get_theme_color("font_focus_color"), faces[0]) >= 4.5,
		label + " focus keeps readable ink")
	_check(button.get_theme_stylebox("hover_pressed") == button.get_theme_stylebox("pressed"),
		label + " held press keeps the pressed face")


func _ticket_contrast(first: Color, second: Color) -> float:
	var values: Array[float] = []
	for color in [first, second]:
		var linear: Array[float] = []
		for channel in [color.r, color.g, color.b]:
			linear.append(channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4))
		values.append(0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2])
	return (maxf(values[0], values[1]) + 0.05) / (minf(values[0], values[1]) + 0.05)


func _effects() -> Array:
	var carry := app.party_carryover as RunTornCarryover
	return [app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.session_gold,
		app.run_scraps, app.run_trinkets.duplicate(), app.run_removal_count,
		app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id,
		app.run_rng.state, carry.read_state(), carry.torn.read_state(),
		carry._wardrobe.get_snapshot() if carry._wardrobe != null else {},
		app.act_outcome.get_state(), _state() if app.deck != null else {},
		app.peddler_visit.read_state() if app.peddler_visit != null else {},
		app.peddler_visit.read_state().state if app.peddler_visit != null else {}]


func _event_state() -> Array:
	return [_effects(), app.run_map.get_floors(), app.run_map.get_route(),
		app._quiet_spool_completed, app.quiet_spool_panel, app._quiet_spool_outcome,
		app._quiet_spool_outcome.is_consumed() if app._quiet_spool_outcome != null else false,
		app._moth_completed, app.moth_panel, app._moth_outcome,
		app._moth_outcome.is_consumed() if app._moth_outcome != null else false,
		app._moth_picker, app._moth_context.duplicate(),
		app._moth_picker.get_instance_id() if is_instance_valid(app._moth_picker) else 0,
		app._moth_picker_item_indices(),
		app._moth_picker.get_selected_items() if is_instance_valid(app._moth_picker) else PackedInt32Array()]


func _reject_event(callback: Callable, reason: String) -> void:
	var before := _event_state()
	if callback.is_valid():
		callback.call()
	_check(_event_state() == before, reason + " preserves entire run, map, ownership and RNG")


## Real seeded route: starter Fight, then three consecutive Events and a Rest.
func _moth_fixture() -> Dictionary:
	var kinds: Array = ["Fight", "Event", "Event", "Event", "Rest"]
	for value in range(1, 30000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var path := _find_path(map, map.get_legal_choices(), kinds)
		if path.is_empty():
			continue
		map.choose_node(path[0])
		var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng,
			RunFightEncounterSelection.new())
		if selected.get("encounter_id") == "starter_attacks":
			return {"seed": value, "fight": path[0], "path": path.slice(1)}
	return {}


## Wins the real opening Fight, skips its reward and completes the run's first
## Event through the mounted Quiet Spool choice.
func _reach_second_event(fixture: Dictionary) -> bool:
	app.run_seed = fixture.seed
	if not await _routed_win(fixture, false):
		return false
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	await _click(_route_action(fixture.path[0]))
	_check(app.quiet_spool_panel != null and app.quiet_spool_panel.title_label.text == "The Quiet Spool",
		"first Event remains the Quiet Spool")
	if not is_instance_valid(app.quiet_spool_panel):
		return false
	await _click(app.quiet_spool_panel.get_choice_buttons()[1])
	_check(app.run_map.get_current_node_id() == fixture.path[0] and app.route_view != null,
		"Quiet Spool completion restores the connected chooser")
	return true


## Live Moth results on the second genuine Event: exact sacrifice occurrence and
## scrap gain, exact fumigation cost, composite refusal and later no-effect Events.
func _moth_outcomes() -> void:
	var fixture := _moth_fixture()
	_check(not fixture.is_empty(), "seeded real Fight -> three Events -> Rest")
	if fixture.is_empty():
		return
	if not await _reach_second_event(fixture):
		return
	# --- Feed: remove precisely the selected occurrence of a duplicate ID.
	seed(720072)
	var global_next := randi()
	seed(720072)
	# Move one authentic copy so removing the chosen occurrence is observable.
	var reordered: Array = app.run_deck.duplicate()
	var moved: String = reordered[1]
	reordered.remove_at(1)
	reordered.append(moved)
	app.run_deck.assign(reordered)
	var scraps: int = app.run_scraps
	var descriptors: Dictionary = app.run_stitch_descriptors.duplicate(true)
	var cursor: int = app.run_next_stitch_id
	var gold: int = app.session_gold
	var heroes: Array = app.run_heroes.duplicate(true)
	var rng: int = app.run_rng.state
	var entry: Callable = _route_action(fixture.path[1]).pressed.get_connections()[0].callable
	# A malformed authored record fails before the node or panel is touched.
	var broken := OS.get_environment("TEMP").path_join("moth_route_invalid.json")
	for malformed in ["{}", "not JSON", '{"id":"moth_infestation"}',
		'{"id":"moth_infestation","title":"Moth","description":"M","choices":[{"id":"escape","text":"E","outcome":{"gold":0,"scraps":0}},{"id":"escape","text":"E","outcome":{"gold":0,"scraps":0}}]}',
		'{"id":"moth_infestation","title":"Moth","description":"M","choices":[{"id":"sacrifice_card","text":"F","outcome":{"gold":0,"scraps":2}},{"id":"fumigate","text":"F","outcome":{"gold":0,"scraps":-1}},{"id":"leave","text":"E","outcome":{"gold":0,"scraps":0}}]}',
		'{"id":"moth_infestation","title":"Moth","description":"M","choices":[{"id":"sacrifice_card","text":"F","outcome":{"gold":0,"scraps":3}},{"id":"fumigate","text":"F","outcome":{"gold":0,"scraps":-1}},{"id":"escape","text":"E","outcome":{"gold":0,"scraps":0}}]}']:
		var file := FileAccess.open(broken, FileAccess.WRITE)
		_check(file != null, "external malformed Moth fixture writable")
		if file == null:
			continue
		file.store_string(malformed)
		file.close()
		app.moth_catalog_path = broken
		var route_before: Array = app.run_map.get_route()
		var state_before := _event_state()
		await _click(_route_action(fixture.path[1]))
		_check(app.moth_panel == null and app.run_map.get_route() == route_before
			and _event_state() == state_before and is_instance_valid(app.route_view),
			"malformed authored Moth record rejects before entry")
	DirAccess.remove_absolute(broken)
	app.moth_catalog_path = "res://data/events/moth_infestation.json"
	await _click(_route_action(fixture.path[1]))
	var panel: LiveEventChoicePanel = app.moth_panel
	_check(panel != null and panel.has_open_event() and app.route_view == null
		and not app._can_choose_connected_route(), "second Event mounts the Moth panel and blocks routing")
	if panel == null:
		return
	_check(panel.title_label.text == "Moth Infestation", "Moth record selected by stable authored ID")
	var moth_panel_id: int = _check_event_backdrop(panel, "second Event")
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 3 and buttons[0].text == "Feed one ordinary card to the moths (+2 scraps)\nScraps +2"
		and buttons[1].text == "Fumigate the deck (spend 1 scrap)\nScraps -1"
		and buttons[2].text == "Escape before the moths spread\nNo change to gold or scraps.", "three authored Moth choices")
	_check(app._moth_picker.has_focus(), "the index selector owns initial keyboard focus")
	var picker: ItemList = app._moth_picker
	var ordinary: Array = app._moth_ordinary_indices()
	_check(is_instance_valid(picker) and picker.item_count == ordinary.size(),
		"selector offers exactly the ordinary deck slots")
	if not is_instance_valid(picker) or picker.item_count != ordinary.size():
		return
	for row in range(picker.item_count):
		_check(picker.get_item_metadata(row) == ordinary[row]
			and picker.get_item_text(row) == "Deck #%d: %s" % [ordinary[row] + 1, app.run_deck[ordinary[row]]],
			"selector row is index-accurate: " + str(row))
	var copies: Array = []
	for row in range(picker.item_count):
		if app.run_deck[picker.get_item_metadata(row)] == moved:
			copies.append(row)
	_check(copies.size() == 2 and picker.get_item_metadata(copies[0]) != picker.get_item_metadata(copies[1]),
		"duplicate IDs stay two distinct occurrences")
	if copies.size() != 2:
		return
	var chosen_row: int = copies[1]
	var chosen: int = picker.get_item_metadata(chosen_row)
	var expected: Array = app.run_deck.duplicate()
	expected.remove_at(chosen)
	var first_copy: Array = app.run_deck.duplicate()
	first_copy.remove_at(int(picker.get_item_metadata(copies[0])))
	_check(expected != first_copy, "fixture distinguishes the two identical copies")
	var commit: Callable = panel.choice_committed.get_connections()[0].callable
	var feed_click: Callable = buttons[0].pressed.get_connections()[0].callable
	var before := _event_state()
	_reject_event(commit.bind("moth_infestation", "sacrifice_card"), "forged unclaimed Feed signal")
	_reject_event(commit.bind("moth_infestation", "escape"), "forged unclaimed Escape signal")
	_check(_event_state() == before, "forged Moth signals change nothing")
	# Keyboard: arrows pick the later duplicate, Tab reaches Feed, Enter commits.
	picker.grab_focus()
	for step in range(chosen_row):
		await _key(KEY_DOWN)
	_check(picker.get_selected_items().size() == 1 and picker.get_selected_items()[0] == chosen_row,
		"physical arrow keys select the later duplicate row")
	_check(picker.get_item_metadata(picker.get_selected_items()[0]) == chosen,
		"keyboard selection keeps its exact deck index")
	await _key(KEY_TAB)
	_check(buttons[0].has_focus(), "Tab reaches Feed from the selector")
	await _key(KEY_ENTER)
	_check(app.moth_panel == null and app._moth_completed and app.route_view != null,
		"Feed disposes the Moth panel and restores the chooser")
	_check(not is_instance_id_valid(moth_panel_id),
		"Feed frees the second Event art bed with its panel")
	_check(app.run_deck == expected and app.run_scraps == scraps + 2,
		"Feed removes precisely the selected occurrence and grants exactly 2 scraps")
	_check(app.run_stitch_descriptors == descriptors and app.run_next_stitch_id == cursor
		and app.session_gold == gold and app.run_heroes == heroes and app.run_rng.state == rng,
		"Feed preserves descriptors, cursor, gold, heroes and RNG")
	_check(app.run_deck.count(moved) == reordered.count(moved) - 1,
		"Feed consumes one copy of the duplicated authored card")
	var settled := _event_state()
	for callback in [commit.bind("moth_infestation", "sacrifice_card"), feed_click, entry]:
		_reject_event(callback, "replayed Moth input after Feed")
	_check(_event_state() == settled, "duplicate or stale Moth input changes nothing")
	_check(randi() == global_next, "Feed preserves the actual global RNG")
	# The run's third Event is the accepted Dye Vat visit; a no-spend Leave still
	# advances exactly one node with the same deck.
	var third_deck: Array = app.run_deck.duplicate()
	var third_route: Array = app.run_map.get_route()
	await _click(_route_action(fixture.path[2]))
	_check(app.moth_panel == null and app.quiet_spool_panel == null
		and is_instance_valid(app.dye_vat_panel)
		and app.dye_vat_panel.title_label.text == "The Dye Vat"
		and app.run_map.get_route() == third_route + [fixture.path[2]] and app.route_view == null,
		"third Event mounts the Dye Vat and blocks onward routing")
	if is_instance_valid(app.dye_vat_panel):
		var dye_buttons: Array[Button] = app.dye_vat_panel.get_choice_buttons()
		_check(dye_buttons.size() == 3
			and dye_buttons[0].tooltip_text.contains("it becomes its authored + version")
			and dye_buttons[0].tooltip_text.contains("Scraps -3")
			and dye_buttons[2].tooltip_text.ends_with("No change to gold or scraps."),
			"live Dye Vat tickets explain the upgrade and the zero-change exit on hover")
		await _click(app.dye_vat_panel.get_choice_buttons()[2])
		_check(app.dye_vat_panel == null and app._dye_vat_completed and app.route_view != null
			and app.run_deck == third_deck,
			"a no-spend Dye Vat Leave keeps the deck and restores routing")
	app._return_to_title()
	await _frames()
	_check(app.moth_panel == null and app._moth_context.is_empty() and not app._moth_completed,
		"title resets Moth eligibility")
	# --- Fumigate: exactly one scrap, no card removed.
	seed(720073)
	global_next = randi()
	seed(720073)
	var funded := _placeholder_fixture("", "Event")
	_check(not funded.is_empty(), "seeded Fight -> two Events fixture exists")
	if funded.is_empty():
		return
	if not await _reach_second_event(funded):
		return
	scraps = app.run_scraps
	descriptors = app.run_stitch_descriptors.duplicate(true)
	cursor = app.run_next_stitch_id
	gold = app.session_gold
	heroes = app.run_heroes.duplicate(true)
	rng = app.run_rng.state
	var funded_deck: Array = app.run_deck.duplicate()
	_check(scraps >= 1, "the real Fight reward funds one Fumigate")
	await _click(_route_action(funded.path[1]))
	panel = app.moth_panel
	_check(panel != null, "funded run's second Event mounts Moth")
	if panel == null:
		return
	_check_event_backdrop(panel, "funded second Event")
	buttons = panel.get_choice_buttons()
	_check(not buttons[1].disabled, "one-scrap Fumigate is claimable")
	await _click(buttons[1])
	_check(app.moth_panel == null and app._moth_completed and app.run_scraps == scraps - 1
		and app.run_deck == funded_deck, "Fumigate spends exactly one scrap and removes no card")
	_check(app.run_stitch_descriptors == descriptors and app.run_next_stitch_id == cursor
		and app.session_gold == gold and app.run_heroes == heroes and app.run_rng.state == rng,
		"Fumigate preserves descriptors, cursor, gold, heroes and RNG")
	_check(randi() == global_next, "Fumigate preserves the actual global RNG")
	app._return_to_title()
	await _frames()
	# --- A zero-scrap run cannot claim Fumigate.
	seed(720074)
	global_next = randi()
	seed(720074)
	app.run_seed = 8
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	var opening := _route_action("f01_n1")
	_check(app.run_map.get_node("f01_n1").get("type") == "Event" and is_instance_valid(opening),
		"zero-scrap opening has a real first Event")
	if not is_instance_valid(opening):
		return
	await _click(opening)
	_check(app.quiet_spool_panel != null, "opening run's first Event is Quiet Spool")
	await _click(app.quiet_spool_panel.get_choice_buttons()[1])
	_check(app.run_scraps == 0 and app._quiet_spool_completed, "Ignore leaves a zero-scrap wallet")
	var next_event := _route_action("f02_n0")
	_check(app.run_map.get_node("f01_n1").get("outgoing", []).has("f02_n0")
		and app.run_map.get_node("f02_n0").get("type") == "Event"
		and is_instance_valid(next_event), "zero-scrap Moth entry remains genuinely connected")
	if not is_instance_valid(next_event):
		return
	await _click(next_event)
	panel = app.moth_panel
	_check(panel != null, "opening run's second Event mounts Moth")
	if panel == null:
		return
	_check_event_backdrop(panel, "opening second Event")
	var poor_deck: Array = app.run_deck.duplicate()
	buttons = panel.get_choice_buttons()
	_check(buttons[1].disabled and not buttons[0].disabled and not buttons[2].disabled,
		"zero-scrap Fumigate is disabled while Feed and Escape remain")
	before = _event_state()
	await _click(buttons[1])
	_reject_event(panel.choice_committed.get_connections()[0].callable.bind(
		"moth_infestation", "fumigate"), "forged Fumigate without its cost")
	_check(_event_state() == before and not panel._selector.is_claimed(),
		"zero-scrap Fumigate cannot claim, spend, remove or route")
	await _click(buttons[2])
	_check(app.moth_panel == null and app.run_scraps == 0 and app.run_deck == poor_deck
		and app.route_view != null, "zero-scrap Escape changes nothing and unlocks successors")
	_check(randi() == global_next, "zero-scrap Moth rejection preserves the actual global RNG")
	app._return_to_title()
	await _frames()
	# --- A genuine composite is never offered and cannot be fed to the moths.
	seed(720075)
	global_next = randi()
	seed(720075)
	var mixed := _placeholder_fixture("", "Event")
	_check(not mixed.is_empty(), "seeded Fight -> two Events fixture exists for the composite case")
	if mixed.is_empty():
		return
	if not await _reach_second_event(mixed):
		return
	var stitch := RunRestStitchCards.new(app.run_deck, {}, RunRestStitchCards.SCRAP_COST, 1)
	var stitched: Dictionary = stitch.choose_stitch(0, 4, stitch.get_snapshot())
	_check(stitched.ok, "genuine stitched ledger fixture")
	if not stitched.ok:
		return
	app.run_deck.assign(stitched.deck)
	app.run_stitch_descriptors = stitched.descriptors.duplicate(true)
	app.run_next_stitch_id = stitched.next_stitch_id
	app.run_scraps = stitched.remaining_scraps
	var composite: int = app.run_deck.find("stitched_000001")
	_check(composite >= 0, "the composite occupies a real deck slot")
	await _click(_route_action(mixed.path[1]))
	panel = app.moth_panel
	_check(panel != null, "mixed ordinary/composite ledger still presents Moth")
	if panel == null:
		return
	_check_event_backdrop(panel, "mixed second Event")
	picker = app._moth_picker
	var mixed_deck: Array = app.run_deck.duplicate()
	var mixed_scraps: int = app.run_scraps
	descriptors = app.run_stitch_descriptors.duplicate(true)
	cursor = app.run_next_stitch_id
	_check(picker.item_count == app.run_deck.size() - 1
		and not app._moth_picker_item_indices().has(composite),
		"selector admits every ordinary slot and never a composite")
	var saved_meta: Variant = picker.get_item_metadata(0)
	picker.set_item_metadata(0, composite)
	picker.select(0)
	var forged := _event_state()
	_reject_event(panel.choice_committed.get_connections()[0].callable.bind(
		"moth_infestation", "sacrifice_card"), "forged composite Feed selection")
	_check(app.moth_panel == panel and app.run_deck == mixed_deck
		and app.run_scraps == mixed_scraps and app.run_stitch_descriptors == descriptors
		and app.run_next_stitch_id == cursor and _event_state() == forged,
		"composite selection cannot spend, remove a card or unlock routing")
	picker.set_item_metadata(0, saved_meta)
	var mixed_index: int = picker.get_item_metadata(0)
	_check(mixed_index != composite and app.run_deck[mixed_index] != "stitched_000001",
		"restored selector points at an ordinary slot")
	var mixed_expected: Array = app.run_deck.duplicate()
	mixed_expected.remove_at(mixed_index)
	await _click(panel.get_choice_buttons()[0])
	_check(app.moth_panel == null and app.run_deck == mixed_expected
		and app.run_deck.has("stitched_000001") and app.run_stitch_descriptors == descriptors
		and app.run_next_stitch_id == cursor and app.run_scraps == mixed_scraps + 2,
		"mixed-ledger Feed removes the selected ordinary slot and preserves the composite")
	_check(randi() == global_next, "composite Moth input preserves the actual global RNG")
	app._return_to_title()
	await _frames()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var stale: Array[Callable] = []
	for won in [false, true]:
		var fixture := _placeholder_fixture("", "Event") if won else {"seed": 8, "path": ["f01_n1", "f02_n0"]}
		_check(not fixture.is_empty(), "real seeded Event fixture exists")
		if fixture.is_empty():
			continue
		for choice_index in range(2):
			var replay: Array = []
			for mode in range(2):
				seed(1110111)
				var global_next := randi()
				seed(1110111)
				if won:
					if not await _routed_win(fixture, false):
						break
					await _click(app.reward_buttons[3])
					await _click(app.continue_button)
				else:
					app.run_seed = fixture.seed
					await _click(app.start_button)
					preload("res://tests/party_choice.gd").choose(app)
				var before_stale := _event_state()
				for callback in stale:
					if callback.is_valid():
						callback.call()
				_check(_event_state() == before_stale, "fresh same-seed run rejects old bindings")
				var id: String = fixture.path[0]
				var next_id: String = fixture.path[1]
				_check(app.run_map.get_legal_choices().has(id)
					and app.run_map.get_node(id).get("type") == "Event"
					and app.run_map.get_node(id).get("outgoing", []).has(next_id)
					and app.run_map.get_node(next_id).get("type") == "Event",
					"genuine connected zero-Fight two-Event witness")
				var action := _route_action(id)
				_check(is_instance_valid(action) and not action.disabled
					and not action.pressed.get_connections().is_empty(),
					"first real Event control is mounted and bound before callback")
				if not is_instance_valid(action) or action.disabled or action.pressed.get_connections().is_empty():
					break
				var entry: Callable = action.pressed.get_connections()[0].callable
				# Invalid authored records fail before choosing the node or mounting anything.
				var path := OS.get_environment("TEMP").path_join("quiet_spool_route_invalid.json")
				for malformed in ["{}", "not JSON", '{"events":[{"id":"quiet_spool"}]}',
					'{"events":[{"id":"quiet_spool","title":"bad","description":"bad","choices":[{"id":"watch","text":"Watch"},{"id":"ignore","text":"Ignore"}]}]}']:
					var file := FileAccess.open(path, FileAccess.WRITE)
					_check(file != null, "external malformed fixture writable")
					file.store_string(malformed)
					file.close()
					app.event_catalog_path = path
					_reject_event(entry, "malformed authored record")
				DirAccess.remove_absolute(path)
				_reject_event(entry, "missing authored catalog")
				app.event_catalog_path = "res://data/events/m04_events.json"
				var prior: Array = app.run_map.get_route()
				var effects := _effects()
				var scraps: int = app.run_scraps
				_check(won or scraps == 0, "title opening starts with zero scraps")
				await _click(action)
				var panel: LiveEventChoicePanel = app.quiet_spool_panel
				_check(panel != null and panel.has_open_event(), "first connected Event mounts real authored panel")
				if panel == null:
					break
				_check(app.route_view == null and app.route_buttons.is_empty() and not app._can_choose_connected_route(), "no onward controls before choice")
				_check(app.run_map.get_route() == prior + [id] and _effects() == effects, "entry changes only selected route")
				_check(panel.title_label.text == "The Quiet Spool", "record selected by stable authored ID")
				var event_panel_id: int = _check_event_backdrop(panel, "first Event")
				var buttons := panel.get_choice_buttons()
				_check(buttons.size() == 2 and buttons[0].text == "Watch the thread unwind\nScraps +1" and buttons[1].text == "Leave the spool alone\nNo change to gold or scraps.", "authored Watch and Ignore controls")
				_check(buttons[0].tooltip_text == "Watch the thread unwind\nGold +0   |   Scraps +1\nAuthored outcome; your run's wallet is not checked here."
					and buttons[1].tooltip_text == "Leave the spool alone\nGold +0   |   Scraps +0\nNo change to gold or scraps.",
					"live routed tickets explain their exact authored outcome on hover")
				var hover_state := _event_state()
				await _hover(buttons[0])
				await _hover(buttons[1])
				_check(root.gui_get_hovered_control() == buttons[1]
					and buttons[0].tooltip_text.contains("Scraps +1")
					and buttons[1].tooltip_text.contains("No change to gold or scraps."),
					"hovering the routed tickets reveals their outcome and commits nothing")
				_check(_event_state() == hover_state, "hover leaves the whole live run untouched")
				_check(buttons[0].has_focus(), "Watch receives initial keyboard focus")
				for button in buttons:
					_check(Rect2(0, 0, 1280, 720).encloses(button.get_global_rect()), "choice fits viewport")
				var commit: Callable = panel.choice_committed.get_connections()[0].callable
				_reject_event(commit.bind("quiet_spool", "watch"), "forged uncommitted signal")
				_reject_event(entry, "duplicate entry while pending")
				_reject_event(app._choose_placeholder_route.bind(id, weakref(app.run_map), app.run_map.get_route(), buttons[0]), "placeholder bypass")
				var selected: Button = buttons[choice_index]
				var click: Callable = selected.pressed.get_connections()[0].callable
				selected.disabled = true
				_reject_event(click, "disabled choice callback")
				selected.disabled = false
				selected.hide()
				_reject_event(click, "hidden choice callback")
				selected.show()
				app.session_gold += 1
				_reject_event(commit.bind("quiet_spool", "watch"), "drifted wallet")
				app.session_gold -= 1
				if mode == 0:
					await _click(selected)
				else:
					buttons[0].grab_focus()
					if choice_index == 1:
						await _key(KEY_TAB)
					_check(selected.has_focus(), "Tab reaches intended choice")
					await _key(KEY_ENTER if choice_index == 0 else KEY_SPACE)
				_check(app.quiet_spool_panel == null and app._quiet_spool_completed and app.route_view != null, "commit disposes panel and restores chooser")
				_check(not is_instance_id_valid(event_panel_id),
					"commit frees the Event art bed with its panel")
				_check(app.run_scraps == scraps + (1 if choice_index == 0 else 0), "exact one-scrap Watch or zero-scrap Ignore receipt")
				# Compare every other resource independently of the intended wallet delta.
				var settled_scraps: int = app.run_scraps
				app.run_scraps = scraps
				_check(_effects() == effects, "choice preserves heroes, deck, gold, ownership and RNG")
				app.run_scraps = settled_scraps
				for callback in [commit.bind("quiet_spool", "watch"), commit.bind("quiet_spool", "ignore"), click, entry]:
					_reject_event(callback, "replay after completion")
					stale.append(callback)
				await _check_chooser()
				var timeline := [_effects(), app.run_map.get_route(), app.run_map.get_legal_choices()]
				if mode == 0:
					replay = timeline
				else:
					_check(timeline == replay, "independent same-seed input modes reproduce outcome")
				await _click(_route_action(fixture.path[1]))
				_check(app.run_map.get_current_node_id() == fixture.path[1], "completed Event allows actual next node")
				# The run's second Event is the accepted Moth Infestation visit.
				if app.run_map.get_node(fixture.path[1]).type == "Event":
					_check(app.moth_panel != null and app.moth_panel.has_open_event() and app.route_view == null
						and not app._can_choose_connected_route(), "second Event mounts the authored Moth panel")
				var moth_panel: LiveEventChoicePanel = app.moth_panel
				if moth_panel != null:
					var moth_panel_id: int = _check_event_backdrop(moth_panel, "second Event")
					var moth_before := _event_state()
					var moth_effects := _effects()
					var moth_deck: Array = app.run_deck.duplicate()
					var moth_scraps: int = app.run_scraps
					var moth_buttons := moth_panel.get_choice_buttons()
					_check(moth_buttons.size() == 3 and moth_buttons[0].text == "Feed one ordinary card to the moths (+2 scraps)\nScraps +2"
						and moth_buttons[1].text == "Fumigate the deck (spend 1 scrap)\nScraps -1"
						and moth_buttons[2].text == "Escape before the moths spread\nNo change to gold or scraps.", "three authored Moth controls")
					_check(moth_buttons[0].tooltip_text == "Feed one ordinary card to the moths (+2 scraps)\nGold +0   |   Scraps +2\nAuthored outcome; your run's wallet is not checked here."
						and moth_buttons[1].tooltip_text == "Fumigate the deck (spend 1 scrap)\nGold +0   |   Scraps -1\nAuthored outcome; your run's wallet is not checked here."
						and moth_buttons[2].tooltip_text == "Escape before the moths spread\nGold +0   |   Scraps +0\nNo change to gold or scraps.",
						"live Moth tickets explain the removal, the cost and the zero change on hover")
					var picker: ItemList = app._moth_picker
					_check(is_instance_valid(picker) and picker.item_count == app._moth_ordinary_indices().size(),
						"index-accurate ordinary selector covers the live deck")
					_check(moth_buttons[1].disabled == (moth_scraps < 1),
						"Fumigate is claimable exactly when one scrap is available")
					_check(not moth_buttons[0].disabled and not moth_buttons[2].disabled,
						"Feed and Escape stay available")
					var moth_commit: Callable = moth_panel.choice_committed.get_connections()[0].callable
					var escape: Callable = moth_commit.bind("moth_infestation", "escape")
					var moth_click: Callable = moth_buttons[2].pressed.get_connections()[0].callable
					_reject_event(escape, "forged unclaimed Moth signal")
					_reject_event(entry, "duplicate Moth entry request")
					if moth_buttons[1].disabled:
						await _click(moth_buttons[1])
						_check(_event_state() == moth_before and not moth_panel._selector.is_claimed(),
							"zero-scrap Fumigate input cannot claim, spend or remove")
						_reject_event(moth_commit.bind("moth_infestation", "fumigate"),
							"unaffordable Fumigate cannot settle")
					await _click(moth_buttons[2])
					_check(app.moth_panel == null and app._moth_completed and app.route_view != null,
						"Escape disposes the Moth panel and restores the chooser")
					_check(not is_instance_id_valid(moth_panel_id),
						"Escape frees the second Event art bed with its panel")
					_check(_effects() == moth_effects and app.run_deck == moth_deck
						and app.run_scraps == moth_scraps, "Escape preserves every resource and the route")
					for callback in [escape, moth_click, entry]:
						_reject_event(callback, "replay after Moth completion")
						stale.append(callback)
				_check(randi() == global_next, "entry, rejection and outcome preserve actual global RNG")
				app._return_to_title()
				await _frames()
				_check(app.quiet_spool_panel == null and app._quiet_spool_context.is_empty() and not app._quiet_spool_completed, "title invalidates completed binding")
				_check(app.moth_panel == null and app._moth_context.is_empty() and app._moth_picker == null
					and not app._moth_completed, "title invalidates completed Moth binding")
	# Abandon an unresolved visit, then prove its live callbacks cannot reach a new one.
	app.run_seed = 6
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	await _click(_route_action("f01_n1"))
	var old_panel: LiveEventChoicePanel = app.quiet_spool_panel
	var abandoned: Callable = old_panel.choice_committed.get_connections()[0].callable
	var abandoned_click: Callable = old_panel.get_choice_buttons()[0].pressed.get_connections()[0].callable
	_check(_live_event_art_bed(old_panel) != null,
		"abandoned first Event really mounted its art bed")
	app._return_to_title()
	await _frames()
	_check(app.find_children("EventBackdrop", "Control", true, false).is_empty(),
		"title return releases the abandoned Event art bed")
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	await _click(_route_action("f01_n1"))
	_reject_event(abandoned.bind("quiet_spool", "watch"), "abandoned signal in fresh seeded visit")
	_reject_event(abandoned_click, "abandoned choice in fresh seeded visit")
	# A real panel commit with a stale run wallet must reject, even though the
	# panel itself accepted the choice. It cannot repair or spend the drift.
	var pending: LiveEventChoicePanel = app.quiet_spool_panel
	var outcome: RunQuietSpoolOutcome = app._quiet_spool_outcome
	app.session_gold += 1
	var drifted := _event_state()
	await _click(pending.get_choice_buttons()[0])
	_check(pending._selector.is_claimed() and not outcome.is_consumed(), "actual panel signal reaches stale-context rejection")
	_check(_event_state() == drifted and app.route_view == null, "stale wallet cannot settle or traverse")
	app._return_to_title()
	await _frames()
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	await _click(_route_action("f01_n1"))
	await _click(app.quiet_spool_panel.get_choice_buttons()[1])
	_check(app.run_scraps == 0, "fresh Ignore has independent outcome")
	app._return_to_title()
	await _frames()
	await _moth_outcomes()
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_quiet_spool_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
