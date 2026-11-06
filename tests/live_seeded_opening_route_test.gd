extends "res://tests/live_run_map_entry_test.gd"
const LEGACY_ENTRY := preload("res://tests/legacy_card_app_fixture.gd")
## Shipped scene, physical title/route inputs and independent typed data oracle.

## Written out here, not read from App, so the mounted label cannot agree with a broken map.
const EXPECTED_ROUTE_LABELS := {
	"SewingCircle": "Sewing Circle",
	"Campfire": "Campfire",
	"PatchStall": "Patch Stall",
	"Unpicker": "Unpicker",
	"Fight": "Fight",
	"Elite": "Elite fight",
	"Peddler": "Peddler",
	"Event": "Event",
	"Treasure": "Treasure",
	"Boss": "Boss fight",
}

var fallback_kinds_by_stage := {"opening": {}, "continued": {}}


func _record(app) -> Array:
	var carry := app.party_carryover as RunTornCarryover
	return [_snapshot(app), app.run_heroes.duplicate(true), carry.read_state(),
		carry.torn.read_state(), carry._node, carry._start.duplicate(true),
		app.act_outcome.get_state(), app.fight_selection._selected.duplicate(true),
		app.fight_selection._bound_map, app.session_gold, app.run_scraps,
		app.run_trinkets.duplicate(), app.run_removal_count,
		app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id]


func _activate(button: Button, keyboard: bool) -> void:
	_check(is_instance_valid(button) and not button.disabled and button.is_visible_in_tree(), "real enabled action exists")
	if not is_instance_valid(button):
		return
	if keyboard:
		button.grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(button)


## Reverse Tab must walk the same mounted patch chain back to the start.
func _shift_tab() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.shift_pressed = true
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _button(app, id: String) -> Button:
	for button in app.route_buttons:
		if button.get_meta("route_id") == id:
			return button
	_check(false, "legal route button exists: " + id)
	return null


func _projected_book(app) -> void:
	var before := _record(app)
	var legal: Array = app.run_map.get_legal_choices()
	_check(not legal.is_empty() and app.route_buttons.size() == legal.size(), "nonempty authentic projected chooser")
	var shown: Array = []
	for button in app.route_buttons:
		var id: String = button.get_meta("route_id")
		var node: Dictionary = app.run_map.get_node(id)
		_check(not node.is_empty() and legal.has(id), "projection has genuine legal source")
		if node.is_empty():
			continue
		var kind: String = node.type
		var expected: String = {"Rest": "Campfire", "Shop": "Peddler"}.get(kind, kind)
		shown.append(id)
		_check(button.get_meta("route_kind") == kind and button.get_meta("v3_kind") == expected
			and button.text == EXPECTED_ROUTE_LABELS.get(expected, expected)
			and button.get_meta("route_label") == button.text, "source kind and independent projected caption/metadata")
		if kind == "Rest":
			var expected_help := "Campfire: Heal each hero 30% max HP (torn revives at 1 HP first), or Leave unchanged for free."
			_check(button.tooltip_text == expected_help, "honest source-specific Rest help")
		elif kind == "Shop":
			_check(button.tooltip_text == "Peddler: buy one of three cards or one patch, or Leave for free.", "honest one-choice Peddler help")
		var font: Font = button.get_theme_font("font")
		_check(font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			button.get_theme_font_size("font_size")).x <= button.size.x - 72,
			"full projected caption fits beside projected token")
		_token_fallback(button, expected)
		var stage := "opening" if app.run_map.get_route().is_empty() else "continued"
		fallback_kinds_by_stage[stage][kind] = true
	_check(shown == legal, "projected chooser preserves legal source order")
	var projected := RunV3StopChoiceProjection.project_legal_choices(app.run_map)
	_check(app._authenticated_route_choices(app.run_map, projected) == projected, "real projection authenticates")
	for field in ["id", "type", "v3_kind"]:
		var forged := projected.duplicate(true)
		forged[0][field] = "foreign"
		_check(app._authenticated_route_choices(app.run_map, forged).is_empty(), "forged projection rejected: " + field)
	var foreign := RunMap.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = app.run_seed
	_check(foreign.generate(rng), "foreign map is genuinely generated")
	_check(app._authenticated_route_choices(foreign, projected).is_empty(), "identical-seed foreign map rejected")
	_check(app._authenticated_route_choices(app.run_map, projected.slice(1)).is_empty(), "incomplete projection rejected")
	if projected.size() > 1:
		var reordered := projected.duplicate(true)
		reordered.reverse()
		_check(app._authenticated_route_choices(app.run_map, reordered).is_empty(), "reordered projection rejected")
	_check(_record(app) == before, "projection reads and rejections preserve every authority and RNG")


func _token_fallback(button: Button, kind: String) -> void:
	var token = button.get_node_or_null("Token")
	_check(token != null, "authentic projected choice has a mounted token")
	if token == null:
		return
	var path: String = {"Campfire": "res://assets/paper/ui/map_node_campfire.png",
		"Peddler": "res://assets/paper/ui/map_node_peddler.png"}.get(kind, RunRouteAtlas.node_token_path(kind))
	_check(token.token_kind == kind and token.art_path == path and token.get_meta("art_path") == path,
		"continued and opening tokens show independently projected kind and art metadata")
	var thread: Color = {"Campfire": Color("#f1c38f"), "Peddler": Color("#e4d59a")}.get(kind, token.thread_colour)
	var felt: Color = {"Campfire": Color("#965a39"), "Peddler": Color("#7d7150")}.get(kind, token.patch_colour)
	# The kind's thread still marks the token and its stitch; the Button face itself
	# is the inherited gothic chrome, so it must carry no local normal override.
	var gothic: Theme = load("res://themes/gothic_theme.tres") as Theme
	_check(token.thread_colour == thread and token.patch_colour == felt
		and button.get_node("Stitch").thread_colour == thread
		and button.get_node("Stitch").get_meta("route_kind") == kind
		and gothic != null and not button.has_theme_stylebox_override("normal")
		and button.get_theme_stylebox("normal") == gothic.get_stylebox("normal", "Button"),
		"projected felt and thread agree on token and stitch with inherited gothic button chrome")
	var original: Texture2D = token.token_texture
	if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
		_check(original == load(path), "present authentic art is loaded first")
	# Force both branches, independently of what the art pipeline has shipped.
	var image := GradientTexture2D.new()
	token.token_texture = image
	_check(not token.uses_drawn_fallback() and token.fallback_plan().is_empty(),
		"present texture takes precedence for every mounted kind")
	token.token_texture = null
	var expected: String = {"Campfire": "flame_logs", "SewingCircle": "needle_thread",
		"Unpicker": "scissors", "PatchStall": "patch"}.get(kind, "")
	var plan: Dictionary = token.fallback_plan()
	_check(token.uses_drawn_fallback(), "explicit missing-texture probe selects fallback")
	if expected.is_empty():
		_check(plan.is_empty(), "legacy and non-stop kinds retain cross-stitch fallback")
	else:
		_check(plan == RunRouteAtlas.NodeToken.fallback_plan(kind)
			and plan.emblem == expected and plan.glyph == "" and plan.art_bottom <= 52.0,
			"distinct non-letter native atlas pictogram: " + kind)
		var rect: Rect2 = token.token_rect()
		var contours := RunRouteAtlas.NodeToken.emblem_contours(expected)
		_check(not contours.is_empty() and rect.grow(-2).has_area(), "native pictogram has actual fitted silhouettes")
		for contour in contours:
			_check(contour.size() >= 3, "sewn silhouette is nonempty")
			for point in contour:
				_check(rect.grow(-2).encloses(Rect2(rect.position + Vector2(2, 2)
					+ point * rect.grow(-2).size / 48.0, Vector2.ZERO).grow(0.5)),
					"sewn contour and stroke fit within fabric border")
	var bounded: Rect2 = token.token_rect()
	_check(bounded.has_area() and Rect2(Vector2.ZERO, button.size).encloses(bounded)
		and bounded.end.x < 72 and token.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and token.focus_mode == Control.FOCUS_NONE, "fallback stays in inert token column clear of route caption")
	for unchanged in ["unknown", "Rest", "Shop", "Peddler", "Fight", "Elite", "Event", "Treasure", "Boss"]:
		token.token_kind = unchanged
		_check(token.fallback_plan().is_empty(), "non-native source keeps original cross stitch: " + unchanged)
	token.token_kind = kind
	token.token_texture = original
	token.queue_redraw()


func _leave_native(app, kind: String, keyboard: bool) -> void:
	match kind:
		"Campfire", "Rest":
			await _activate(app.campfire_leave_button, keyboard)
		"SewingCircle":
			await _activate(app.sewing_leave_button, keyboard)
			await _activate(app.sewing_view.confirm_button, keyboard)
		"PatchStall":
			await _activate(app.patch_stall_view.leave_button, keyboard)


func _clean(app) -> void:
	_check(app.run_map == null and app.run_rng == null and app.fight_selection == null
		and app.party_carryover == null and app.act_outcome == null and app.run_heroes.is_empty()
		and app.run_deck.is_empty() and app.run_trinkets.is_empty() and app.run_scraps == 0
		and app.run_stitch_descriptors.is_empty() and app.run_next_stitch_id == 1
		and app.session_gold == 0 and app.run_removal_count == 0 and app.encounter_id == "",
		"Return clears all seeded resources and services")
	_check(app.route_view == null and app.route_buttons.is_empty() and app.route_atlas == null
		and app.route_atlas_overlay == null and app.route_book_backdrop == null
		and app.battle_view == null and app.rest_view == null
		and app.shop_view == null and app._connected_map == null and app._placeholder_map == null
		and app._carryover_map == null and app._rest_map == null and app._shop_map == null
		and app.title_view.visible and app.start_button.has_focus(), "Return clears every mounted visit and callback source")


func _invalid_starts(app) -> void:
	var path := OS.get_environment("TEMP").path_join("patchwork_seeded_opening_095.json")
	var original: Array = app._load_party_definitions()
	var wrong_owner: Array = original.duplicate(true)
	wrong_owner[1].id = "wrong_owner"
	var fractional: Array = original.duplicate(true)
	fractional[0].max_hp = 40.5
	for fixture in [["starter_deck_path", "[]"], ["starter_deck_path", "not JSON"],
		["starter_party_path", JSON.stringify(wrong_owner)],
		["starter_party_path", JSON.stringify(fractional)], ["starter_party_path", "{}"]]:
		var field: String = fixture[0]
		var previous: String = app.get(field)
		var file := FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "malformed admission fixture is outside repository")
		if file == null:
			continue
		file.store_string(fixture[1])
		file.close()
		app.set(field, path)
		seed(950095)
		var expected := randi()
		seed(950095)
		await _activate(LEGACY_ENTRY.start_button(app), true)
		_check(is_instance_valid(app.party_picker) and app.run_map == null, "invalid-data Start still requires explicit party")
		for id in ["warden", "seamstress", "tinker"]:
			await _activate(app.party_picker._tiles[id], true)
		await _activate(app.party_picker.continue_button, true)
		_check(randi() == expected, "rejected Start does not consume the actual global RNG")
		_clean(app)
		app.set(field, previous)
	DirAccess.remove_absolute(path)
	for field in ["starter_deck_path", "starter_party_path"]:
		var previous: String = app.get(field)
		app.set(field, path)
		await _activate(LEGACY_ENTRY.start_button(app), false)
		_check(is_instance_valid(app.party_picker) and app.run_map == null, "missing-data Start still requires explicit party")
		for id in ["warden", "seamstress", "tinker"]:
			await _activate(app.party_picker._tiles[id], false)
		await _activate(app.party_picker.continue_button, false)
		_clean(app)
		app.set(field, previous)


func _typed(app, heroes: Array, cards: Array, rng_state: int, kind: String) -> void:
	_check(app.deck != null and app.party != null and app.enemies != null
		and app.enemy_intents != null and app.round_flow != null and app.battle_result != null,
		"typed opening mounts all actual combat models")
	if app.deck == null:
		return
	var pools: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RunAuthoredBattleEntry.POOLS_PATH))
	_check(pools[kind].has(app.encounter_id), "selected encounter belongs to actual node type")
	if not pools[kind].has(app.encounter_id):
		return
	var entry: Dictionary = pools[kind][app.encounter_id]
	var schedule := RunFightEncounterSelection._parse_schedule_text(FileAccess.get_file_as_string(entry.schedule))
	_check(app.enemy_intents._definitions == schedule, "exact typed authored schedule mounted")
	var actors: Array = app.enemies.get_enemies()
	_check(actors.size() == entry.enemy_ids.size() and not actors.is_empty(), "complete typed roster mounted")
	var floor_number: int = int(app.run_map.get_node(app.run_map.get_current_node_id()).get("floor", 0))
	var actual_ids: Array = []
	for index in range(actors.size()):
		actual_ids.append(actors[index].id)
		_check(actors[index].position == index + 1, "typed enemy identity and source slot")
	if kind == "Fight":
		_check(BAND_ORACLE.legal_group(actual_ids, floor_number),
			"mounted Fight roster is a legal floor-%d band group" % floor_number)
	else:
		for index in range(actors.size()):
			_check(actors[index].id == entry.enemy_ids[index],
				"typed enemy identity and source slot")
	var catalog: Array = []
	for path in RunAuthoredBattleEntry.CATALOG_PATHS:
		catalog.append_array(RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(path)))
	var definitions: Array = []
	for id in actual_ids:
		var matches := catalog.filter(func(record): return record.id == id)
		_check(matches.size() == 1, "one authored enemy definition: " + id)
		if matches.size() == 1:
			definitions.append(_normal_floor_record(matches[0], floor_number)
				if kind == "Fight" else matches[0])
	_check(actors == CombatEnemies.new(definitions).get_enemies(), "full typed enemy HP, metadata and roster order")
	var expected: Array = heroes.duplicate(true)
	for hero in expected:
		hero.block = 6 if hero.id == "warden" else 0
	_check(app.party.get_heroes() == expected and app.run_heroes == heroes
		and app.run_deck == cards, "all persistent hero fields and deck survive; starting Block is combat only")
	var rng := RandomNumberGenerator.new()
	rng.state = rng_state
	var ids: Array = pools[kind].keys()
	ids.sort()
	_check(app.encounter_id == ids[rng.randi_range(0, ids.size() - 1)], "one sorted typed selection draw")
	if kind == "Fight":
		_check(BAND_ORACLE.group(floor_number, actors.size(), rng) == actual_ids,
			"mounted Fight band group is the exact seeded floor-band draw")
	var reference := CombatDeck.new(cards, rng)
	var independent := CombatEnemyIntents.new(schedule)
	var roster := CombatEnemies.new(definitions)
	var party := CombatParty.new(heroes)
	_check(roster.is_valid() and party.is_valid()
		and independent.bind_battle(roster, party, rng),
		"independent typed roster and party bind seeded weighted first announcement")
	_check(independent.get_intents() == app.enemy_intents.get_intents()
		and app.enemy_intents.is_bound(), "live typed opening announces the independently drawn batch")
	_check(reference.start_turn(), "independent persistent deck starts")
	_check(app.deck.hand == reference.hand and app.deck.draw_pile == reference.draw_pile
		and app.deck.discard_pile == reference.discard_pile and app.run_rng.state == rng.state
		and app.deck._rng == app.run_rng and app.deck.energy == 3,
		"selection and real hand share the uninterrupted run RNG")
	_check(app._current_act_battle() and app._current_carryover_fight()
		and app.act_outcome.get_state().pending_node_id == app.run_map.get_current_node_id(),
		"live outcome and torn witness bind the actual selected battle")


## Object-free description of the mounted opening book, for a seeded replay comparison.
func _book_state(app) -> Array:
	var state: Array = []
	var book = app.route_book_backdrop
	if is_instance_valid(book):
		var area: Label = book.get_node_or_null("AreaCue")
		var cue: Label = book.get_node_or_null("FloorCue")
		state.append([book.uses_board_texture(),
			area.text if area != null else "", cue.text if cue != null else ""])
		var slate: Control = book.get_node("PartySlate")
		for row in slate.get_children():
			if row is Label:
				state.append([row.text, row.get_theme_font_size("font_size"),
					row.get_theme_color("font_color"), row.has_theme_stylebox_override("normal"),
					row.get_node_or_null("SupplyStitch") != null])
			else:
				state.append([row.get_node("HeroName").text, row.get_node("Health").text,
					row.get_node("Portrait").texture != null])
	else:
		state.append(null)
	for button in app.route_buttons:
		var token = button.get_node_or_null("Token")
		var stitch = button.get_node_or_null("Stitch")
		state.append([button.get_meta("route_id"), button.get_meta("route_kind"), button.text,
			button.disabled, token.art_path if token != null else "",
			token.uses_drawn_fallback() if token != null else null,
			button.position, button.size, stitch != null])
	return state


## Mounted opening book: page backdrop, Meadow/Floor 01 tabs on the left page and one
## stitched patch per legal first-floor node on that node's authored page slot.
func _opening_book(app) -> void:
	var book = app.route_book_backdrop
	_check(is_instance_valid(book) and book.is_visible_in_tree(), "opening chooser mounts its page backdrop")
	if not is_instance_valid(book):
		return
	_check(book.mouse_filter == Control.MOUSE_FILTER_IGNORE and book.focus_mode == Control.FOCUS_NONE,
		"page backdrop is pointer and keyboard inert")
	var siblings: Array = app.get_children()
	_check(siblings.find(book) >= 0 and siblings.find(app.route_view) > siblings.find(book),
		"page backdrop renders behind every mounted choice")
	_check(book.uses_board_texture() == ResourceLoader.exists(RunRouteAtlas.MAP_BOARD_PATH, "Texture2D"),
		"page backdrop mounts the owner board when it exists")
	var geometry: Dictionary = book.page_geometry()
	var origin: Vector2 = book.global_position
	var page := Rect2(origin + geometry.right_page.position, geometry.right_page.size)
	var left_page := Rect2(origin + geometry.left_page.position, geometry.left_page.size)
	var spine := Rect2(origin + geometry.spine.position, geometry.spine.size)
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(viewport.encloses(app.route_view.get_global_rect()) and page.encloses(app.route_view.get_global_rect()),
		"the patch page fits inside the right page and viewport")
	var area: Label = book.get_node_or_null("AreaCue")
	var area_rect := Rect2(origin + area.position, area.size) if area != null else Rect2()
	_check(area != null and area.is_visible_in_tree() and area.text == "Meadow"
		and area.get_meta("area_name") == "Meadow" and left_page.encloses(area_rect),
		"visible Meadow area caption sits on the left page")
	var cue: Label = book.get_node_or_null("FloorCue")
	var cue_rect := Rect2(origin + cue.position, cue.size) if cue != null else Rect2()
	_check(cue != null and cue.is_visible_in_tree() and cue.text == "Floor 01"
		and cue.get_meta("floor_number") == 1 and left_page.encloses(cue_rect),
		"visible first-floor cue sits on the left page")
	_check(not area_rect.intersects(cue_rect), "the area and floor patches stay separate on the left page")
	_party_slate(app, left_page)
	_check(app.run_map.get_route().is_empty() and app.run_map.get_current_node_id() == ""
		and app.run_map.get_current_floor() == 0,
		"the page tabs never invent a committed route")
	var legal: Array[String] = app.run_map.get_legal_choices()
	var future: Array = []
	for floor_nodes in app.run_map.get_floors().slice(1):
		for node in floor_nodes:
			future.append(node.id)
	var branches = app.route_view.get_node_or_null("Branches")
	_check(branches != null and branches.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and branches.focus_mode == Control.FOCUS_NONE,
		"the drawn start seam is pointer and keyboard inert")
	_check(app.route_view.get_node_or_null("Pin_current") == null
		and book.get_node_or_null("Pin_current") == null,
		"an uncommitted opening draws no committed pin")
	_check(app.route_buttons.size() == legal.size(),
		"exactly one stitched patch per legal opening")
	var seen: Array = []
	var patch_rects: Array[Rect2] = []
	for button in app.route_buttons:
		var kind: String = button.get_meta("route_kind")
		var id: String = button.get_meta("route_id")
		var node: Dictionary = app.run_map.get_node(id)
		var projected: String = {"Rest": "Campfire", "Shop": "Peddler"}.get(kind, kind)
		var path := RunRouteAtlas.node_token_path(projected)
		var token = button.get_node_or_null("Token")
		var stitch = button.get_node_or_null("Stitch")
		seen.append(id)
		_check(legal.has(id) and not future.has(id) and not node.is_empty()
			and String(node.id) == id and String(node.type) == kind
			and button.get_meta("pin_node_id", "") == "",
			"patch is backed by its actual legal first-floor node: " + id)
		# Pinned here, not read from App: each patch sits on its authored node slot.
		var expected_top := 74.0 + float(int(node.position)) * 86.0
		_check(button.get_parent() == app.route_view
			and button.position == Vector2(132.0, expected_top)
			and button.size == Vector2(288.0, 70.0),
			"patch sits on its authored page slot: " + id)
		_check(page.encloses(button.get_global_rect())
			and button.get_global_rect().position.x > spine.end.x,
			"patch clears the spine and stays inside the right page: " + id)
		for placed in patch_rects:
			_check(not placed.intersects(button.get_global_rect()),
				"sewn patches never overlap: " + id)
		patch_rects.append(button.get_global_rect())
		_check(button.text == EXPECTED_ROUTE_LABELS.get(projected, projected) and not button.text.contains(id),
			"readable kind label on the patch: " + id)
		_check(token != null and token.get_parent() == button
			and token.mouse_filter == Control.MOUSE_FILTER_IGNORE and token.focus_mode == Control.FOCUS_NONE,
			"one inert sewn token per legal choice: " + id)
		_check(stitch != null and stitch.get_parent() == button
			and stitch.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and stitch.focus_mode == Control.FOCUS_NONE,
			"one inert stitched edge per legal patch: " + id)
		if token == null:
			continue
		_check(token.art_path == path and token.get_meta("art_path") == path
			and token.token_kind == projected, "token shows its projected kind and art path: " + id)
		var token_rect: Rect2 = token.token_rect()
		_check(token_rect.size.x > 0.0 and button.get_global_rect().encloses(
			Rect2(token.global_position + token_rect.position, token_rect.size)),
			"mounted token art fits inside its button: " + id)
		if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
			_check(token.token_texture != null and token.token_texture == load(path)
				and not token.uses_drawn_fallback()
				and token.get_meta("art_backed") == true, "authored sewn token art mounted: " + id)
		else:
			_check(token.token_texture == null and token.uses_drawn_fallback()
				and token.get_meta("art_backed") == false, "kind without art keeps its drawn token: " + id)
	_check(seen == legal, "patches appear in authored position order")
	var targets: Array = branches.branch_targets if branches != null else []
	_check(targets.size() == app.route_buttons.size(), "one stitched start branch per legal patch")
	for index in range(mini(targets.size(), app.route_buttons.size())):
		var patch: Button = app.route_buttons[index]
		_check(targets[index] == Rect2(patch.position, patch.size),
			"stitched branch ends at its own patch: " + String(patch.get_meta("route_id")))
	_check(app.route_back_button.position.y > app.route_map_button.position.y
		and page.encloses(app.route_back_button.get_global_rect())
		and page.encloses(app.route_map_button.get_global_rect()),
		"the map and Back actions stay reachable at the page foot")


func _party_slate(app, page: Rect2) -> void:
	var book = app.route_book_backdrop
	var slates: Array = book.find_children("PartySlate", "Control", true, false)
	_check(slates.size() == 1 and app.run_heroes.size() == 3 and not app.run_deck.is_empty(),
		"one slate with a genuine initialized party and deck")
	if slates.size() != 1:
		return
	var slate: Control = slates[0]
	var rows := slate.find_children("HeroRow*", "Control", false, false)
	_check(rows.size() == app.run_heroes.size(), "exactly one sewn row per run hero")
	var expected_names := ["Warden", "Seamstress", "Tinker"]
	var paths := ["res://assets/paper/heroes/warden.png", "res://assets/paper/heroes/seamstress.png",
		"res://assets/paper/heroes/tinker.png"]
	var previous: Rect2 = book.get_node("FloorHint").get_global_rect()
	for index in range(mini(rows.size(), app.run_heroes.size())):
		var row: Control = rows[index]
		var hero: Dictionary = app.run_heroes[index]
		var caption: Label = row.get_node("HeroName")
		var health: Label = row.get_node("Health")
		_check(hero.name == expected_names[index] and caption.text == hero.name
			and health.text == "HP %d / %d" % [hero.hp, hero.max_hp],
			"mounted name and current/max HP match independent run hero")
		_check(row.get_global_rect().position.y >= previous.end.y,
			"hero rows follow the tabs and never overlap")
		previous = row.get_global_rect()
		var portrait: TextureRect = row.get_node("Portrait")
		_check(portrait.expand_mode == TextureRect.EXPAND_IGNORE_SIZE
			and portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			and portrait.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
			"portrait preserves its aspect ratio with mipmapped filtering")
		if ResourceLoader.exists(paths[index], "Texture2D"):
			var bust := portrait.texture as AtlasTexture
			_check(bust != null and bust.atlas == load(paths[index]) and bust.region.has_area(),
				"committed idle portrait is mounted as a head-and-shoulders crop")
		else:
			_check(portrait.texture == null and row.get_node_or_null("PortraitFallback") != null
				and not caption.text.is_empty(), "missing portrait retains readable fallback and name")
	var resources: Label = slate.get_node("Resources")
	_check(resources.text == "Deck: %d cards\nGold: %d\nScraps: %d" % [
		app.run_deck.size(), app.session_gold, app.run_scraps],
		"supply tab uses authoritative deck and both wallet counts on separate lines")
	_supply_style(resources)
	var controls: Array = [slate]
	controls.append_array(slate.find_children("*", "Control", true, false))
	for control in controls:
		_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE and control.focus_mode == Control.FOCUS_NONE
			and control.is_visible_in_tree() and page.encloses(control.get_global_rect()),
			"every slate control is inert and enclosed by the left page: " + str(control.name))
		if control is Label:
			_check(not control.text.contains("res://") and not control.text.contains("f01_")
				and not control.text.contains("warden_") and not control.text.contains("seamstress_")
				and not control.text.contains("tinker_"), "slate labels show no authored paths or IDs")


func _supply_style(resources: Label) -> void:
	_check(resources.has_theme_stylebox_override("normal"), "supply tab owns its opaque backing")
	var backing := resources.get_theme_stylebox("normal") as StyleBoxFlat
	_check(backing != null, "supply backing is a padded StyleBoxFlat")
	if backing == null:
		return
	var ink := resources.get_theme_color("font_color")
	var contrast := (ink.srgb_to_linear().get_luminance() + 0.05) / (backing.bg_color.srgb_to_linear().get_luminance() + 0.05)
	_check(backing.bg_color.a == 1.0 and ink.a == 1.0 and contrast >= 4.5
		and resources.get_theme_font_size("font_size") >= 18,
		"opaque supply backing and body text have strong contrast")
	_check(backing.content_margin_left >= 12 and backing.content_margin_right >= 12
		and backing.content_margin_top >= 10 and backing.content_margin_bottom >= 10
		and backing.border_width_left > 0 and backing.border_width_right > 0
		and backing.border_width_top > 0 and backing.border_width_bottom > 0,
		"supply text has padding inside its bordered backing")
	var stitch := resources.get_node_or_null("SupplyStitch") as Control
	_check(stitch != null, "supply tab has a sewn edge")
	if stitch != null:
		_check(stitch.mouse_filter == Control.MOUSE_FILTER_IGNORE and stitch.focus_mode == Control.FOCUS_NONE,
			"supply stitching is inert")
	_check(resources.mouse_filter == Control.MOUSE_FILTER_IGNORE and resources.focus_mode == Control.FOCUS_NONE,
		"supply label is pointer and keyboard inert")


func _slate_snapshot_fallback(app) -> void:
	# Exercise missing art without changing or assuming absence of any committed asset.
	var snapshot := {"heroes": app.run_heroes.duplicate(true), "deck_count": app.run_deck.size(),
		"gold": app.session_gold, "scraps": app.run_scraps}
	_check(snapshot.heroes.size() == 3, "snapshot fallback uses a genuine started party")
	var expected_hp: int = snapshot.heroes[0].hp - 1
	snapshot.heroes[0].id = "unillustrated_hero"
	snapshot.heroes[0].hp = expected_hp
	var book = app.RouteBook.new()
	book.show_party(snapshot)
	snapshot.heroes[0].name = "mutated caller"
	snapshot.heroes[0].hp = 0
	snapshot.gold = 999
	snapshot.scraps = 999
	snapshot.deck_count = 999
	var row: Control = book.get_node("PartySlate/HeroRow0")
	_check(row.get_node("Portrait").texture == null and row.get_node_or_null("PortraitFallback") != null
		and row.get_node("HeroName").text == app.run_heroes[0].name
		and row.get_node("Health").text == "HP %d / %d" % [expected_hp, app.run_heroes[0].max_hp],
		"missing art keeps name and non-full current HP after nested caller mutation")
	_check(book.get_node("PartySlate/Resources").text == "Deck: %d cards\nGold: %d\nScraps: %d" % [
		app.run_deck.size(), app.session_gold, app.run_scraps]
		and app.run_heroes[0].hp == app.run_heroes[0].max_hp,
		"snapshot presentation and caller mutations leave run authorities unchanged")
	_check(not book.uses_board_texture(), "detached fallback book uses drawn pages")
	_supply_style(book.get_node("PartySlate/Resources"))
	book.free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await _invalid_starts(app)
	var cases: Array = []
	for kind in ["Fight", "Elite", "Rest", "Shop", "Event", "Treasure", "Unpicker", "Campfire", "SewingCircle", "PatchStall"]:
		var found: Array = []
		for value in range(1, 1000):
			var rng := RandomNumberGenerator.new()
			rng.seed = value
			var map := RunMap.new()
			map.generate(rng)
			for id in map.get_legal_choices():
				if map.get_node(id).type != kind:
					continue
				# Require a genuine continued Sewing Circle as well as the onward Fight;
				# the other seeded fixtures cover the remaining continued native badges.
				if kind == "SewingCircle" and not map.get_node(id).outgoing.any(
					func(next): return map.get_node(next).type == "SewingCircle"):
					continue
				if kind in ["Fight", "Elite"]:
					found = [kind, value, id, ""]
					break
				for next in map.get_node(id).outgoing:
					if map.get_node(next).type == "Fight":
						found = [kind, value, id, next]
						break
				if not found.is_empty():
					break
			if not found.is_empty():
				break
		_check(not found.is_empty(), "bounded genuine connected Fight fixture for " + kind)
		if not found.is_empty():
			cases.append(found)
	for required in ["Fight", "Elite", "Rest", "Shop", "Event", "Treasure", "Unpicker", "Campfire", "SewingCircle", "PatchStall"]:
		_check(cases.any(func(row): return row[0] == required), "required opening fixture exists: " + required)
	var stale: Array[Callable] = []
	for fixture in cases:
		var replay: Array = []
		var replay_book: Array = []
		for mode in range(2):
			app.run_seed = fixture[1]
			await _activate(LEGACY_ENTRY.start_button(app), mode == 1)
			_check(is_instance_valid(app.party_picker) and app.run_map == null, "physical Start mounts picker before allocating run")
			for id in ["warden", "seamstress", "tinker"]:
				await _activate(app.party_picker._tiles[id], mode == 1)
			await _activate(app.party_picker.continue_button, mode == 1)
			_check(app.run_map != null and app.route_view != null, "physical Start opens initialized chooser")
			if app.run_map == null:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = fixture[1]
			var map := RunMap.new()
			_check(map.generate(rng), "independent map generated")
			_check(app.run_map.get_floors() == map.get_floors() and app.run_map.get_floors().size() == 12
				and app.run_rng.state == rng.state and app.run_deck == RunV3PartyAdmission.admit(["warden", "seamstress", "tinker"]).deck
				and app.run_heroes == CombatParty.new(app._load_party_definitions()).get_heroes()
				and app.run_deck.size() == 12 and app.party_carryover is RunTornCarryover,
				"Start publishes canonical seeded map, twelve cards and three heroes before combat")
			_opening_book(app)
			_projected_book(app)
			_slate_snapshot_fallback(app)
			# Every mounted patch is reachable in authored order by Tab and back by
			# reverse Tab, without spending any route or RNG state.
			var first_patch: Button = app.route_buttons[0]
			first_patch.grab_focus()
			await _key(KEY_TAB)
			_check(app.route_buttons.size() > 1 and root.gui_get_focus_owner() == app.route_buttons[1],
				"Tab walks to the next sewn patch")
			await _shift_tab()
			_check(root.gui_get_focus_owner() == first_patch,
				"reverse Tab returns to the first sewn patch")
			var book_id := 0
			var slate_id: int = app.route_book_backdrop.get_node("PartySlate").get_instance_id()
			if is_instance_valid(app.route_book_backdrop):
				book_id = app.route_book_backdrop.get_instance_id()
			var book_state := _book_state(app)
			var before := _record(app)
			for callback in stale:
				callback.call()
			preload("res://tests/legacy_card_app_fixture.gd").enable(app)
			app.start_run_requested.emit()
			app._open_route()
			_check(_record(app) == before, "duplicate Start and stale Back/Return callbacks are inert")
			_check(app.route_book_backdrop.get_instance_id() == book_id
				and _book_state(app) == book_state, "repeat Start preserves the single slate")
			_party_slate(app, Rect2(app.route_book_backdrop.global_position
				+ app.route_book_backdrop.page_geometry().left_page.position,
				app.route_book_backdrop.page_geometry().left_page.size))
			await _activate(app.route_map_button, mode == 1)
			_check(app.route_atlas != null and not app.route_book_backdrop.is_visible_in_tree(),
				"full map hides the entire opening slate")
			await _activate(app.route_atlas_close, mode == 1)
			_check(_record(app) == before and _book_state(app) == book_state
				and app.route_book_backdrop.is_visible_in_tree() and app.route_map_button.has_focus(),
				"closing full map restores unchanged slate, ledgers, RNG and action focus")
			_check(not app._choose_route("unknown") and not app._choose_route("f02_n0")
				and not app._choose_route(fixture[2], weakref(map)) and _record(app) == before,
				"unknown, future and foreign requests reject atomically")
			if mode == 0:
				replay = before
				replay_book = book_state
			else:
				# Object identities differ between sessions; compare authoritative values.
				_check(before.slice(1, 8) == replay.slice(1, 8), "fresh seed replays every initial ledger")
				_check(book_state == replay_book, "fresh seed replays the same opening book and tokens")
			for button in app.route_buttons:
				_check(not button.disabled, "every actual legal opening enabled")
			stale.append(app.route_back_button.pressed.get_connections()[0].callable)
			var heroes: Array = app.run_heroes.duplicate(true)
			var cards: Array = app.run_deck.duplicate()
			var shared = app.run_rng
			var carry = app.party_carryover
			var latch = app.act_outcome
			var start_rng: int = shared.state
			var kind: String = fixture[0]
			var action := _button(app, fixture[2])
			var route_kind: String = action.get_meta("route_kind")
			action.set_meta("route_kind", "foreign")
			action.set_meta("v3_kind", route_kind)
			var forged_before := _record(app)
			_check(not app._choose_route(fixture[2]) and _record(app) == forged_before,
				"detached v3 kind cannot authorize a false source kind")
			action.set_meta("route_kind", route_kind)
			action.set_meta("v3_kind", {"Rest": "Campfire", "Shop": "Peddler"}.get(route_kind, route_kind))
			stale.append(action.pressed.get_connections()[0].callable)
			action.disabled = true
			var disabled_before := _record(app)
			_check(not app._choose_route(fixture[2]) and _record(app) == disabled_before, "disabled otherwise-legal opening rejects without mutation")
			action.disabled = false
			if kind in ["Fight", "Elite"]:
				var selector = app.fight_selection
				for choice in [{"success": false}, {"success": true, "node_type": kind, "encounter_id": "missing", "definitions": []}]:
					selector._selected[fixture[2]] = choice
					var rejected := _record(app)
					_check(not app._choose_route(fixture[2]) and _record(app) == rejected
						and app.fight_selection == selector, "malformed typed entry rolls back map, selection, RNG, ledgers and chooser")
				selector._selected.clear()
				var original = app.party_carryover
				app.party_carryover = RunTornCarryover.new([])
				var invalid: Array = _snapshot(app)
				_check(not app._choose_route(fixture[2]) and _snapshot(app) == invalid, "invalid non-null torn ledger rejects without spending")
				app.party_carryover = original
			await _activate(_button(app, fixture[2]), mode == 1)
			_check(app.run_map.get_route() == [fixture[2]], "opening commits exactly the selected node")
			_check(app.route_book_backdrop == null or app.route_book_backdrop.get_instance_id() != book_id, "committing the opening disposes its book, with a fresh book for immediate connected choices")
			await process_frame
			_check(book_id != 0 and not is_instance_id_valid(book_id), "the disposed opening book is freed")
			_check(not is_instance_id_valid(slate_id), "route choice frees the opening party slate")
			if kind in ["Campfire", "SewingCircle", "PatchStall"]:
				await _leave_native(app, kind, mode == 1)
			elif kind == "Rest":
				_check(app.campfire_view is LiveCampfirePanel and app.campfire_view.is_visible_in_tree()
					and app.rest_view == null and app.campfire_visit.read_state().status == RunCampfireVisit.OPEN,
					"authentic opening Rest mounts sewn Campfire before any battle")
				# Before any battle the party is fully healed: the zero-gain Heal is
				# disabled and inert, and the enabled focused Leave is the only commit.
				_check(app.campfire_heal_button.disabled and app.campfire_heal_button.is_visible_in_tree()
					and not app.campfire_leave_button.disabled
					and app.campfire_leave_button.has_focus(),
					"full-HP opening Campfire disables Heal and focuses the enabled Leave")
				app.campfire_view._connections[app.campfire_heal_button].call()
				_check(app.campfire_visit.read_state().status == RunCampfireVisit.OPEN
					and not app._campfire_closed and not app.campfire_view._submitted,
					"disabled zero-gain Heal emits no decision and spends nothing")
				var camp_action: Button = app.campfire_leave_button
				stale.append(app.campfire_view.decision_requested.get_connections()[0].callable.bind({
					"action": "leave", "source_visit": app.campfire_visit,
					"node_id": fixture[2], "expected_heroes": heroes.duplicate(true)}))
				await _activate(camp_action, mode == 1)
				_check(app.run_deck == cards and app.run_heroes == heroes and app._campfire_closed
					and app.party_carryover.read_state().completed_rests.is_empty()
					and shared.state == start_rng, "exact full-HP Leave receipt without deck or RNG drift")
			elif kind == "Unpicker":
				_check(app.unpicker_visit.is_valid() and app.unpicker_view.is_visible_in_tree(), "real seeded Unpicker mounted")
				var source: Dictionary = app.unpicker_visit.read_state()
				stale.append(app.unpicker_view.decision_requested.get_connections()[0].callable.bind({
					"action": "leave", "visit_id": source.visit_id, "node_id": source.node_id,
					"expected_snapshot": source.duplicate(true)}))
				await _activate(app.unpicker_leave_button, mode == 1)
			elif kind == "Shop":
				_check(app.peddler_visit != null and app.peddler_visit.is_open() and app.shop_view.is_visible_in_tree(),
					"real seeded Shop visit mounted before any battle")
				var peddler_source: Dictionary = app.peddler_visit.read_state()
				stale.append(app.shop_view.intent_requested.get_connections()[0].callable.bind({
					"kind": "leave", "node_id": peddler_source.node_id,
					"expected_state": peddler_source.state, "expected_stock": peddler_source.stock}))
				var shop_before := _record(app)
				for choice in app.peddler_buttons:
					choice.pressed.get_connections()[0].callable.call()
				_check(app.shop_visit == null and app.shop_remove_button == null,
					"Peddler exposes no legacy removal ledger or action")
				_check(_record(app) == shop_before, "zero-gold Shop cannot spend or remove")
				await _activate(app.peddler_leave_button, mode == 1)
			elif kind in ["Event", "Treasure"]:
				if kind == "Event":
					_check(app.route_view == null and app.quiet_spool_panel != null, "first Event requires authored choice")
					await _activate(app.quiet_spool_panel.get_choice_buttons()[1], mode == 1)
				_check(app.route_view != null and app._placeholder_route == [fixture[2]]
					and app.run_heroes == heroes and app.run_deck == cards and shared.state == start_rng,
					"placeholder has no effects and mounts actual connected choices")
			if kind not in ["Fight", "Elite"]:
				_projected_book(app)
				var obsolete := RunV3StopChoiceProjection.project_legal_choices(map)
				_check(not obsolete.is_empty() and app._authenticated_route_choices(app.run_map, obsolete).is_empty(),
					"authentic opening projection becomes stale after route movement")
				_check(app.run_map.get_legal_choices().has(fixture[3])
					and app.run_map.get_node(fixture[3]).type == "Fight", "next Fight is an actual connected node")
				start_rng = shared.state
				await _activate(_button(app, fixture[3]), mode == 1)
				_check(app.run_map.get_route() == [fixture[2], fixture[3]], "noncombat opening progresses one connected floor")
				kind = "Fight"
			_typed(app, heroes, cards, start_rng, kind)
			_check(app.run_rng == shared and app.party_carryover == carry and app.act_outcome == latch,
				"same RNG, torn ledger and outcome latch retained through first combat")
			# Witness a real model victory, then claim through the mounted reward action.
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.apply_damage(enemy.position, 999), "victory fixture damages each real typed enemy")
			app._observe_battle_result()
			# Let the mounted reward panel finish container layout and deferred focus.
			await process_frame
			await process_frame
			_check(app._battle_closed and app.reward_buttons.size() == 4,
				"first typed battle exposes real rewards after every opening kind")
			if app.reward_buttons.size() == 4:
				await _activate(app.reward_buttons[3], mode == 1)
				_check(app.fight_reward_claimed and app.party_carryover.read_state().completed_fights.has(app.run_map.get_current_node_id())
					and app.run_deck == cards and app.run_scraps == (2 if kind == "Elite" else 1)
					and app.session_gold >= (25 if kind == "Elite" else 10)
					and app.session_gold <= (35 if kind == "Elite" else 20)
					and app.run_trinkets.size() == (1 if kind == "Elite" else 0),
					"first typed reward settles the same carryover once with correct type, resources and skipped deck")
			await _activate(app.return_button, mode == 1)
			_clean(app)
			# Return directly from a no-battle visit, then replay the same seeded title.
			await _activate(LEGACY_ENTRY.start_button(app), mode == 0)
			_check(is_instance_valid(app.party_picker) and app.run_map == null, "replayed Start first mounts picker")
			for id in ["warden", "seamstress", "tinker"]:
				await _activate(app.party_picker._tiles[id], mode == 0)
			await _activate(app.party_picker.continue_button, mode == 0)
			if fixture[0] not in ["Fight", "Elite"]:
				await _activate(_button(app, fixture[2]), mode == 0)
				if fixture[0] == "Unpicker":
					await _activate(app.unpicker_leave_button, mode == 1)
				await _leave_native(app, fixture[0], mode == 1)
				if fixture[0] == "Event":
					await _activate(app.quiet_spool_panel.get_choice_buttons()[1], mode == 1)
				if fixture[0] == "Shop":
					await _activate(app.peddler_leave_button, mode == 1)
				var back: Button = app.route_back_button
				await _activate(back, mode == 1)
			else:
				var cancelled_book: int = app.route_book_backdrop.get_instance_id()
				var cancelled_slate: int = app.route_book_backdrop.get_node("PartySlate").get_instance_id()
				await _activate(app.route_back_button, mode == 1)
				_check(not is_instance_id_valid(cancelled_book) and not is_instance_id_valid(cancelled_slate),
					"Back frees the book and its party slate")
			_clean(app)
	for stage in ["opening", "continued"]:
		for kind in ["Rest", "Campfire", "SewingCircle", "Unpicker", "PatchStall"]:
			_check(fallback_kinds_by_stage[stage].has(kind), "genuine mounted fallback coverage: " + stage + " " + kind)
	_check(fallback_kinds_by_stage.opening.has("Shop"), "genuine opening Peddler fallback coverage; connected Shop is exercised by continuation tests")
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_seeded_opening_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
