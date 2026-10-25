extends SceneTree

var failures: Array[String] = []
var checks := 0
var requests: Array[String] = []
var seen_help_kinds: Dictionary = {}
## The six committed sewn tokens, written out independently of the view's own table so
## this regression cannot silently inherit an omission from the implementation.
const TOKEN_PATHS := {
	"Unpicker": "res://assets/paper/ui/map_node_unpicker.png",
	"PatchStall": "res://assets/paper/ui/map_node_patch_stall.png",
	"SewingCircle": "res://assets/paper/ui/map_node_sewing_circle.png",
		"Campfire": "res://assets/paper/ui/map_node_campfire.png",
	"Fight": "res://assets/paper/ui/map_node_fight.png",
	"Elite": "res://assets/paper/ui/map_node_elite.png",
	"Event": "res://assets/paper/ui/map_node_event.png",
	"Shop": "res://assets/paper/ui/map_node_shop.png",
	"Rest": "res://assets/paper/ui/map_node_rest.png",
	"Boss": "res://assets/paper/ui/map_node_boss.png",
}
## The master Theme's two faces, written out independently of the master resource:
## headings are Londrina Solid Regular, body text is Patrick Hand.
const HEADING_FONT := "res://assets/fonts/LondrinaSolid-Regular.ttf"
const BODY_FONT := "res://assets/fonts/PatrickHand-Regular.ttf"
## The five authored book areas, written out independently of the view's own table:
## name -> [first floor, last floor].
const AREA_LABELS := {
	"Meadow": [1, 3],
	"Woods": [4, 6],
	"Marsh": [7, 9],
	"Peaks": [10, 11],
	"Boss": [12, 12],
}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _state(map: RunMap, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"floors": map.get_floors(),
		"route": map.get_route(),
		"legal": map.get_legal_choices(),
		"current": map.get_current_node_id(),
		"floor": map.get_current_floor(),
		"complete": map.is_complete(),
		"generated": map.is_generated(),
		"rng": rng.state,
	}


func _expected_style(state: String) -> Color:
	match state:
		"chosen":
			return RunRouteAtlas.CHOSEN_BG
		"legal":
			return RunRouteAtlas.LEGAL_BG
		_:
			return RunRouteAtlas.OTHER_BG


func _expected_thread(state: String) -> Color:
	match state:
		"chosen":
			return RunRouteAtlas.CHOSEN_THREAD
		"legal":
			return RunRouteAtlas.LEGAL_THREAD
		_:
			return RunRouteAtlas.OTHER_THREAD


func _expected_border(state: String) -> Color:
	match state:
		"chosen":
			return RunRouteAtlas.CHOSEN_THREAD
		"legal":
			return RunRouteAtlas.LEGAL_THREAD
		_:
			return RunRouteAtlas.OTHER_BORDER


func _inside(rect: Rect2, outer: Rect2) -> bool:
	return rect.position.x >= outer.position.x and rect.position.y >= outer.position.y \
		and rect.end.x <= outer.end.x and rect.end.y <= outer.end.y


func _font_path(control: Control) -> String:
	var font := control.get_theme_font("font") as Font
	return font.resource_path if font != null else ""


## A mounted chapter heading: the master PatchHeading variation, the exact authored
## pixel size and the real Londrina face resolved through the inherited Theme. No
## per-node Theme is allowed to stand in for the installed master Theme.
func _is_heading(label: Label, font_size: int) -> bool:
	return label.theme == null and label.theme_type_variation == "PatchHeading" \
		and label.has_theme_font_size_override("font_size") \
		and label.get_theme_font_size("font_size") == font_size \
		and _font_path(label) == HEADING_FONT \
		and label.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and label.focus_mode == Control.FOCUS_NONE


## A mounted body-role control: the master Patrick Hand face, never the heading variation.
func _keeps_body_face(control: Control) -> bool:
	return control.theme == null and control.theme_type_variation != "PatchHeading" \
		and _font_path(control) == BODY_FONT


## The shipped Theme's authored PatchHeading face, loaded independently of the view.
func _shipped_heading_face() -> Font:
	var master := load("res://assets/fonts/patchwork_theme.tres") as Theme
	return master.get_font("font", "PatchHeading") if master != null else null


## Independent player-facing wording for one real node record: authored floor, authored
## kind and the one-based branch row. Spelled out here so this regression cannot inherit
## a wording mistake from the view itself.
## Independent authored stop guidance oracle; does not call the atlas presentation helper.
const EXPECTED_HELP := {
	"Unpicker": {"lead": "Choose one: remove a card or leave",
		"detail": "Remove: 75 gold initially, +25 each time",
		"tooltip": "Remove one owned card for 75 gold plus 25 per previous removal, or leave unchanged"},
	"PatchStall": {"lead": "Choose one: buy a patch or leave",
		"detail": "3 priced power patches; choose a wearer; sewing included",
		"tooltip": "Buy one of 3 priced power patches for one chosen hero, sewing included, or leave unchanged"},
	"Campfire": {"lead": "Choose one: heal or leave",
		"detail": "Heal 30% max HP; torn revives at 1 HP first",
		"tooltip": "One action: heal each hero 30% max HP (torn revives at 1 HP first), or leave unchanged"},
	"SewingCircle": {"lead": "Choose one: upgrade or stitch",
		"detail": "Stitch different owners: 3 scraps; or leave",
		"tooltip": "Upgrade one card, stitch two different-owner cards for 3 scraps, or leave unchanged"},
	"Fight": {"lead": "Win: 10–20 gold + 1 scrap",
		"detail": "Choose 1 of 3 cards, or skip",
		"tooltip": "On win: 10–20 gold + 1 scrap; choose 1 of 3 cards or skip"},
	"Elite": {"lead": "Win: 25–35 gold + 2 scraps + patch",
		"detail": "Choose 1 of 3 cards, or skip",
		"tooltip": "On win: 25–35 gold + 2 scraps + patch; choose 1 of 3 cards or skip"},
	"Rest": {"lead": "Choose one: heal, upgrade, stitch or re-sew",
		"detail": "Heal 30% max HP; stitch 3 scraps; re-sew 1 scrap",
		"tooltip": "One action: heal each hero 30% max HP (torn revives at 1 HP first), upgrade one card, stitch two different-owner cards for 3 scraps, or re-sew an equipped patch for 1 scrap"},
	"Shop": {"lead": "Browse 5 cards + 2 patches",
		"detail": "Remove card: 75 gold initially, +25 each time",
		"tooltip": "5 cards + 2 patches; card removal starts at 75 gold, increasing 25 per removal"},
	"Event": {"lead": "2–3 choices when visited",
		"detail": "Outcomes shown on arrival; no guaranteed yield",
		"tooltip": "2–3 choices; outcomes revealed on visit, no guaranteed yield"},
	"Treasure": {"lead": "Treasure stop · contents not yet known",
		"detail": "No fixed reward is specified by the route",
		"tooltip": "Treasure stop; no predetermined reward amount is known"},
	"Boss": {"lead": "Final floor-12 fight",
		"detail": "The last stop on this route",
		"tooltip": "Terminal floor-12 fight"},
}

func _hover_text(node: Dictionary, legal: bool = false) -> String:
	var prefix := "Floor %02d · %s · Branch %d" % [
		int(node["floor"]), str(node["type"]), int(node["position"]) + 1]
	if legal:
		return prefix + " · " + str(EXPECTED_HELP[str(node["type"])]["tooltip"])
	return prefix


# The mounted preview must always show a complete open book: owner art or drawing.
func _verify_book(view: RunRouteAtlas, label: String) -> void:
	if view.uses_board_texture():
		var art := view.board_texture()
		var placed := view.board_texture_rect()
		_check(art is Texture2D and art.get_width() > 0 and art.get_height() > 0
			and placed == Rect2(Vector2.ZERO, view.size)
			and view.drawn_book_geometry().is_empty(),
			label + ": optional owner board image covers the map in place of the drawing")
		return
	var book := view.drawn_book_geometry()
	_check(book.has("left_page") and book.has("right_page") and book.has("spine")
		and book.has("curl") and book.has("bookmark") and book.has("paper"),
		label + ": complete drawn open book behind the map")
	if not (book.has("left_page") and book.has("right_page") and book.has("spine")
			and book.has("curl") and book.has("bookmark")):
		return
	var left: Rect2 = book["left_page"]
	var right: Rect2 = book["right_page"]
	var spine: Rect2 = book["spine"]
	var curl: Rect2 = book["curl"]
	var bookmark: Rect2 = book["bookmark"]
	_check(book["paper"] == RunRouteAtlas.PAPER and left.size.x >= 500.0 and right.size.x >= 500.0
		and left.end.x <= spine.position.x and spine.end.x <= right.position.x,
		label + ": two cream pages sit either side of the spine")
	_check(_inside(left, RunRouteAtlas.BOOK_RECT) and _inside(right, RunRouteAtlas.BOOK_RECT)
		and _inside(spine, RunRouteAtlas.BOOK_RECT) and left.end.x <= right.position.x,
		label + ": pages and spine stay inside the book")
	_check(_inside(curl, right) and is_equal_approx(curl.end.x, right.end.x)
		and is_equal_approx(curl.end.y, right.end.y) and curl.size.x >= 40.0,
		label + ": page curl folds the right page's bottom-right corner")
	_check(bookmark.position.y < RunRouteAtlas.BOOK_RECT.position.y
		and bookmark.position.x >= spine.position.x and bookmark.end.x <= spine.end.x
		and bookmark.end.y > spine.position.y,
		label + ": ribbon bookmark hangs over the spine's top edge")
	_check(float(book["stitch_inset"]) > 0.0
		and float(book["stitch_inset"]) * 2.0 < minf(left.size.x, left.size.y),
		label + ": stitched frame is inset from the torn page edge")
	# Every header and patch must sit on a page, never on the table or the spine.
	for index in range(view.get_child_count()):
		var child: Node = view.get_child(index)
		if not (child is PanelContainer or child is Label):
			continue
		var rect := Rect2(child.position, child.size)
		_check(_inside(rect, left) or _inside(rect, right),
			label + ": " + str(child.name) + " is sewn onto a page")


# Tokens remain image-backed when present; missing art and Treasure use the
# same drawn patch emblem, with exact canonical kind and input independent.
func _verify_token_marker(marker: PanelContainer, id: String, view: RunRouteAtlas,
		label: String) -> void:
	var kind: String = marker.get_meta("route_kind")
	var art := marker.get_node_or_null("Art") as RunRouteAtlas.NodeToken
	var caption := marker.get_node_or_null("Identity") as Label
	_check(art != null and caption != null and art.token_kind == kind
		and art.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		label + ": sewn emblem and readable kind caption " + id)
	if art == null:
		return
	var path: String = TOKEN_PATHS.get(kind, "")
	_check(art.get_meta("art_path") == path and art.token_texture == view.node_token_texture(path),
		label + ": canonical art path and cached texture for " + id)
	if not path.is_empty() and ResourceLoader.exists(path, "Texture2D"):
		var texture := load(path) as Texture2D
		var rect := art.token_rect()
		_check(texture != null and art.token_texture == texture
			and rect.size.x > 0.0 and rect.size.y > 0.0
			and is_equal_approx(rect.size.x / rect.size.y,
				float(texture.get_width()) / float(texture.get_height()))
			and _inside(rect, Rect2(Vector2.ZERO, art.size)),
			label + ": visible authored token fits patch without distortion " + id)
	else:
		_check(art.token_texture == null and art.token_rect() == Rect2(),
			label + ": missing token or Treasure uses drawn fallback " + id)
	_check(caption.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM
		and caption.get_theme_font_size("font_size") >= 18
		and _keeps_body_face(caption)
		and not caption.text.contains(id)
		and not caption.text.contains("f0") and not caption.text.contains("f1")
		and not caption.text.contains("_n"),
		label + ": kind and shortcut read below the emblem without raw ID " + id)


func _verify_token_sources(view: RunRouteAtlas, label: String) -> void:
	for kind in TOKEN_PATHS:
		var path: String = TOKEN_PATHS[kind]
		_check(RunRouteAtlas.node_token_path(kind) == path,
			label + ": supported route token has its committed art path " + kind)
		var loaded := view.node_token_texture(path)
		_check(loaded == (load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null)
			and view.has_cached_node_token(path),
			label + ": optional sewn token loads or falls back and caches " + kind)
		_check(view.node_token_texture(path) == loaded,
			label + ": cache keeps same token reference " + kind)
	_check(RunRouteAtlas.node_token_path("Treasure").is_empty()
		and RunRouteAtlas.node_token_path("Unknown").is_empty(),
		label + ": Treasure and unknown kinds have a drawn fallback")
	var failed_path := "res://assets/paper/ui/map_node_missing_route_token.png"
	_check(view.node_token_texture(failed_path) == null
		and view.has_cached_node_token(failed_path), label + ": missing texture cached as null")
	var probe := RunRouteAtlas.new()
	var none: Array[String] = []
	var test_kinds := ["Fight", "Elite", "Event", "Shop", "Rest", "Treasure", "Boss", "SewingCircle", "Campfire", "PatchStall", "Unpicker"]
	for i in range(test_kinds.size()):
		var kind: String = test_kinds[i]
		var id := "f01_n%d" % i
		var shortcut := (i % 4) + 1 if i < 4 else 0
		var probe_legal: Array[String] = []
		if shortcut > 0:
			probe_legal.append(id)
		probe._add_marker(id, kind, Vector2(float(i) * 90.0, 0.0), none, probe_legal, shortcut)
		var marker := probe.get_node_or_null("Node_" + id) as PanelContainer
		_check(marker != null and marker.get_node_or_null("Art") is RunRouteAtlas.NodeToken
			and (marker.get_node_or_null("Action") is Button) == (shortcut > 0)
			and marker.get_node_or_null("Identity") is Label,
			label + ": standalone image-backed or fallback sewn marker for " + kind)
		if marker != null:
			var caption := marker.get_node_or_null("Identity") as Label
			_check(caption != null and caption.get_theme_font_size("font_size") >= 18
				and _keeps_body_face(caption)
				and caption.text == (str(shortcut) + " " if shortcut > 0 else "") + kind
				and not caption.text.contains(id)
				and not caption.text.contains("f01_n")
				and caption.get_combined_minimum_size().x <= marker.size.x
				and caption.get_combined_minimum_size().y <= marker.size.y,
				label + ": standalone readable >=18px body caption for " + kind)
			_verify_token_marker(marker, id, probe, label)
	probe.free()


func _verify_area_labels(view: RunRouteAtlas, visible: Array[int], label: String) -> void:
	var seen: Dictionary = {}
	for child in view.get_children():
		if not (child is Label) or not child.has_meta("area_name"):
			continue
		var area: Label = child
		var floor_number: int = area.get_meta("floor_number")
		var area_name: String = area.get_meta("area_name")
		var band: Array = AREA_LABELS.get(area_name, [])
		_check(visible.has(floor_number) and not seen.has(floor_number)
			and band.size() == 2 and floor_number >= int(band[0])
			and floor_number <= int(band[1]) and area.text == area_name
			and int(area.get_meta("first_floor", -1)) == int(band[0])
			and int(area.get_meta("last_floor", -1)) == int(band[1])
			and _is_heading(area, 20)
			and _inside(Rect2(area.position, area.size), RunRouteAtlas.PAGE_RIGHT),
			label + ": upcoming floor has its correct 20-point PatchHeading area heading %d" % floor_number)
		seen[floor_number] = true
	_check(seen.size() == visible.size(),
		label + ": every visible upcoming floor and no off-window area has a heading")


func _expected_next_area_text(map: RunMap) -> String:
	if map.is_complete():
		return "Route complete · Floor 12/12"
	var floor_number := map.get_current_floor() + 1
	for area_name in AREA_LABELS:
		var span: Array = AREA_LABELS[area_name]
		if floor_number >= int(span[0]) and floor_number <= int(span[1]):
			return "Next: %s · Floor %d/12" % [area_name, floor_number]
	return ""


func _verify_next_area_tab(view: RunRouteAtlas, map: RunMap, tab: Control, label: String) -> void:
	var status := tab as RunRouteAtlas.NextAreaTab
	_check(status != null and status.has_meta("next_area_tab"), label + ": mounted sewn status")
	if status == null:
		return
	_check(status.text == _expected_next_area_text(map)
		and not status.text.contains("Floor 13")
		and status.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and status.focus_mode == Control.FOCUS_NONE
		and _inside(Rect2(status.position, status.size), RunRouteAtlas.PAGE_LEFT)
		and RunRouteAtlas.NEXT_AREA_TAB_FONT_SIZE >= 16,
		label + ": correct next area or terminal line in readable left page")
	# The status sentence is drawn in the body face; it is not a chapter heading.
	_check(_keeps_body_face(status),
		label + ": next-area status tab keeps the body face, not a heading variation")


## The single visible help ticket is attached to the real legal model record,
## entirely inert, and spaced apart from the existing bookmark and twelve beads.
func _verify_choice_ticket(view: RunRouteAtlas, map: RunMap, label: String) -> void:
	var legal := map.get_legal_choices()
	var ticket := view.choice_ticket()
	if legal.is_empty():
		_check(ticket == null and view.get_node_or_null("ChoiceTicket") == null,
			label + ": completed map has no obsolete stop ticket")
		return
	_check(ticket != null and ticket is RunRouteAtlas.ChoiceTicket
		and ticket.visible and ticket.is_visible_in_tree(),
		label + ": one real readable left-page ticket for legal route choices")
	if ticket == null:
		return
	var id := ticket.route_id
	_check(legal.has(id) and map.get_route().has(id) == false,
		label + ": ticket names only a genuine unvisited legal choice")
	if not legal.has(id):
		return
	var node := map.get_node(id)
	var kind := str(node["type"])
	var fact: Dictionary = EXPECTED_HELP.get(kind, {})
	_check(not fact.is_empty(), label + ": legal kind has independent authored consequence " + kind)
	if fact.is_empty():
		return
	var heading := "%s · FLOOR %02d · BRANCH %d" % [
		RunRouteAtlas.area_for_floor(int(node["floor"])).to_upper(),
		int(node["floor"]), int(node["position"]) + 1]
	_check(ticket.header_text == heading and ticket.lead_text == kind + " · " + str(fact["lead"])
		and ticket.detail_text == str(fact["detail"])
		and not ticket.header_text.contains(id) and not ticket.lead_text.contains(id)
		and not ticket.detail_text.contains(id),
		label + ": exact area/floor/branch and type-specific honest stop consequence " + kind)
	var rect := Rect2(ticket.position, ticket.size)
	var diary := view.get_node_or_null("JourneyJournal") as RunRouteAtlas.JourneyJournal
	var tab := view.next_area_tab()
	_check(_inside(rect, RunRouteAtlas.PAGE_LEFT)
		and rect == RunRouteAtlas.CHOICE_TICKET_RECT
		and diary != null and tab != null
		and not rect.intersects(Rect2(diary.position, diary.size))
		and not rect.intersects(Rect2(tab.position, tab.size))
		and ticket.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and ticket.focus_mode == Control.FOCUS_NONE
		and _keeps_body_face(ticket) and RunRouteAtlas.ChoiceTicket.FONT_SIZE >= 18,
		label + ": cream stitched inert ticket clears the next-area tab and twelve-bead diary")
	var face := ticket.get_theme_default_font()
	if face != null:
		for content in [ticket.header_text, ticket.lead_text, ticket.detail_text]:
			_check(face.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1,
				RunRouteAtlas.ChoiceTicket.FONT_SIZE).x <= ticket.size.x - 28.0,
				label + ": authored >=18px line is not clipped: " + kind)
	_check(_state(map, _rng(1))["route"] == map.get_route(),
		label + ": ticket inspection has no route effects")


func _verify(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator, label: String) -> void:
	var before := _state(map, rng)
	var floors := map.get_floors()
	_check(floors.size() == 12 and floors[0].size() >= 3 and floors[0].size() <= 4,
		label + ": authoritative seeded graph spans twelve 3-4 node floors")
	if floors.size() != 12:
		return
	var all_nodes: Dictionary = {}
	var all_edges: Dictionary = {}
	for fi in range(floors.size()):
		_check(floors[fi].size() >= 3 and floors[fi].size() <= 4,
			label + ": authoritative authored node count on floor %d" % (fi + 1))
		for node in floors[fi]:
			var id: String = node["id"]
			all_nodes[id] = node
			for target in node["outgoing"]:
				all_edges[id + "->" + str(target)] = true
	_check(view._rendered_graph == floors and view._rendered_route == map.get_route()
		and view._rendered_legal == map.get_legal_choices()
		and view._rendered_generation == map.get_generation_revision(),
		label + ": entire unseen model remains in defensive authority snapshot")
	var current_floor := map.get_current_floor()
	var visible_floors: Array[int] = []
	if not map.is_complete():
		for f in range(current_floor + 1, mini(current_floor + 3, 12) + 1):
			visible_floors.append(f)
	var visible_ids: Dictionary = {}
	var current_id := map.get_current_node_id()
	for f in visible_floors:
		for node in floors[f - 1]:
			visible_ids[node["id"]] = true
	if not current_id.is_empty():
		visible_ids[current_id] = true
	var expected_edges: Dictionary = {}
	for id in visible_ids:
		for to_id in all_nodes[id]["outgoing"]:
			if visible_ids.has(to_id):
				expected_edges[id + "->" + str(to_id)] = true
	var legal := map.get_legal_choices()
	var shortcuts: Array[String] = []
	for f in visible_floors:
		for node in floors[f - 1]:
			if legal.has(node["id"]):
				shortcuts.append(node["id"])
	shortcuts.sort_custom(func(a: String, b: String) -> bool:
		return int(all_nodes[a]["position"]) < int(all_nodes[b]["position"]))
	_check(view._rendered_shortcuts == shortcuts and shortcuts.size() == legal.size()
		and shortcuts.size() <= 4,
		label + ": only true next-floor authored-position options own numeric shortcuts")
	var seen_nodes: Dictionary = {}
	var seen_edges: Dictionary = {}
	var seen_headers: Dictionary = {}
	var seen_pins: Array[String] = []
	var first_marker := 99999
	var last_thread := -1
	var last_marker := -1
	var journal_count := 0
	var tab_count := 0
	var ticket_count := 0
	_check(view.is_inside_tree() and view.size == RunRouteAtlas.ATLAS_SIZE
		and _inside(Rect2(view.position, view.size), Rect2(Vector2.ZERO, Vector2(1280, 720))),
		label + ": actual 1240x600 selector fits 1280x720")
	for index in range(view.get_child_count()):
		var child: Node = view.get_child(index)
		if child is Line2D:
			last_thread = index
			var line: Line2D = child
			var key := str(line.get_meta("from_id")) + "->" + str(line.get_meta("to_id"))
			_check(expected_edges.has(key) and not seen_edges.has(key)
				and line.points.size() == 16 and line.width > 0,
				label + ": only real connected in-window stitch " + key)
			seen_edges[key] = line
			var source: String = line.get_meta("from_id")
			var target: String = line.get_meta("to_id")
			var state := "chosen" if map.get_route().has(source) and map.get_route().has(target) else (
				"legal" if map.get_route().has(source) and legal.has(target) else "other")
			_check(line.get_meta("route_state") == state
				and line.default_color == _expected_thread(state),
				label + ": directed stitch has actual chosen/legal/other colour " + key)
		elif child is PanelContainer:
			first_marker = mini(first_marker, index)
			last_marker = maxi(last_marker, index)
			var marker: PanelContainer = child
			var id: String = marker.get_meta("route_id")
			_check(visible_ids.has(id) and not seen_nodes.has(id),
				label + ": only one actual visible-window patch token " + id)
			seen_nodes[id] = marker
			_check(_inside(Rect2(marker.position, marker.size), RunRouteAtlas.PAGE_RIGHT)
				and not Rect2(marker.position, marker.size).intersects(RunRouteAtlas.SPINE_RECT)
				and marker.size.x >= 72 and marker.size.y >= 72,
				label + ": legible sewn tag fully on right page, away from spine " + id)
			var style := marker.get_theme_stylebox("panel") as StyleBoxFlat
			var state := "chosen" if map.get_route().has(id) else ("legal" if legal.has(id) else "other")
			_check(marker.get_meta("route_kind") == all_nodes[id]["type"]
				and marker.get_meta("route_state") == state
				and marker.get_meta("authored_position") == all_nodes[id]["position"]
				and style.bg_color == _expected_style(state)
				and style.border_color == _expected_border(state)
				and marker is RunRouteAtlas.RouteTag
				and style.corner_radius_top_left >= 0 and style.corner_radius_top_left <= 8
				and style.corner_radius_bottom_right <= 8,
				label + ": angular sewn tag shows exact kind, authored row and state " + id)
			var identity := marker.get_node("Identity") as Label
			var number := shortcuts.find(id) + 1
			var caption := (str(number) + " " if number > 0 else "") + str(all_nodes[id]["type"])
			_check(identity.text == caption and not identity.text.contains(id)
				and not identity.text.contains("f0") and not identity.text.contains("f1")
				and not identity.text.contains("_n")
				and identity.get_combined_minimum_size().x <= marker.size.x
				and identity.get_combined_minimum_size().y <= marker.size.y,
				label + ": high contrast caption and legal number fit " + id)
			# Sewn-tag captions stay readable body-text tags, never chapter headings.
			_check(_keeps_body_face(identity) and identity.get_theme_font_size("font_size") >= 18,
				label + ": sewn tag identity caption keeps its >=18-point body tag " + id)
			_check(marker.tooltip_text == _hover_text(all_nodes[id], legal.has(id))
				and not marker.tooltip_text.contains(id)
				and not marker.tooltip_text.contains("f0") and not marker.tooltip_text.contains("f1")
				and not marker.tooltip_text.contains("_n"),
				label + ": sewn hover names the real floor, kind and branch " + id)
			var action := marker.get_node_or_null("Action") as Button
			_check((action != null) == legal.has(id),
				label + ": only currently reachable next floor has Action " + id)
			if action != null:
				seen_help_kinds[str(all_nodes[id]["type"])] = true
				_check(action.focus_mode == Control.FOCUS_ALL and not action.disabled
					and action.mouse_filter == Control.MOUSE_FILTER_STOP
					and action.tooltip_text == "Choose " + _hover_text(all_nodes[id], legal.has(id))
						+ " (key %d)" % number
					and not action.tooltip_text.contains(id)
					and not action.tooltip_text.contains("f0") and not action.tooltip_text.contains("f1")
					and not action.tooltip_text.contains("_n")
					and action.get_meta("route_id") == id,
					label + ": exact legal Choose hover and real shortcut " + id)
			_verify_token_marker(marker, id, view, label)
		elif child is RunRouteAtlas.JourneyJournal:
			journal_count += 1
			var diary: RunRouteAtlas.JourneyJournal = child
			_check(diary.current_floor == current_floor
				and diary.current_area == RunRouteAtlas.area_for_floor(current_floor)
				and diary.next_floor == (0 if map.is_complete() else current_floor + 1)
				and diary.next_area == RunRouteAtlas.area_for_floor(diary.next_floor)
				and diary.complete == map.is_complete() and diary.visited == map.get_route()
				and _inside(Rect2(diary.position, diary.size), RunRouteAtlas.PAGE_LEFT)
				and diary.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and diary.focus_mode == Control.FOCUS_NONE,
				label + ": authentic left journal, area and pinned visited trail without floor 13")
			# Independent projection of the same route: each committed ID through its own
			# authoritative node record. The view may not infer, preassign or spoiler.
			var route := map.get_route()
			var expected_kinds: Array[String] = []
			for visited_id in route:
				expected_kinds.append(str(map.get_node(visited_id).get("type", "")))
			var sequence: Array[String] = diary.visited_kind_sequence()
			_check(sequence == expected_kinds and diary.visited_kinds == expected_kinds
				and sequence.size() == current_floor and sequence.size() == route.size(),
				label + ": each completed bead owns its authentic visited kind in route order")
			# The caption actually painted under each of the twelve beads: completed floors only.
			var painted: Array[String] = []
			var expected_painted: Array[String] = []
			for bead in range(12):
				painted.append(diary.caption_kind(bead))
				expected_painted.append(expected_kinds[bead] if bead < current_floor else "")
			_check(painted == expected_painted and diary.caption_kind(-1).is_empty()
				and diary.caption_kind(12).is_empty(),
				label + ": only completed beads print a kind, the current and future beads stay blank")
			# VIS body-text floor: every diary fact below the title reads at 18 points or more.
			_check(RunRouteAtlas.JourneyJournal.BEAD_FONT_SIZE >= 18
				and RunRouteAtlas.JourneyJournal.KIND_FONT_SIZE >= 18
				and RunRouteAtlas.JourneyJournal.SECTION_HEADING_FONT_SIZE >= 18
				and RunRouteAtlas.JourneyJournal.FOOTER_FONT_SIZE >= 18,
				label + ": bead numerals, kind captions, second heading and footer keep the 18-point floor")
			var raw_id := false
			for kind in sequence:
				if kind.contains("_n") or kind.begins_with("f0") or kind.begins_with("f1"):
					raw_id = true
			var future_kinds: Dictionary = {}
			for floor_nodes in floors:
				for node in floor_nodes:
					if not route.has(node["id"]):
						future_kinds[str(node["type"])] = true
			for kind in expected_kinds:
				future_kinds.erase(kind)
			var leaked := false
			for kind in sequence:
				if future_kinds.has(kind):
					leaked = true
			_check(not raw_id and not leaked,
				label + ": captions show kinds, never raw node IDs or an unvisited kind")
			if map.is_complete():
				_check(diary.visited_kinds.size() == 12
					and diary.visited_kinds.back() == "Boss"
					and not diary.visited_kinds.has(""),
					label + ": completed twelve-floor route ends with the Boss kind and no floor 13")
			# The exposed sequence is a copy; clearing it cannot erase the diary's record.
			sequence.clear()
			_check(diary.visited_kinds.size() == current_floor,
				label + ": exposed visited-kind sequence is a read-only copy")
			_check(_keeps_body_face(diary),
				label + ": left journey diary stays in the body face, not a heading variation")
			var heading_face := _shipped_heading_face()
			var diary_heading := diary.heading_font()
			_check(heading_face != null and heading_face.resource_path == HEADING_FONT
				and diary_heading == heading_face
				and diary_heading != diary.get_theme_default_font(),
				label + ": both diary display headings take the real Londrina PatchHeading face")
			_check(_font_path(diary) == BODY_FONT,
				label + ": current, next and visited diary facts keep the Patrick Hand body face")
		elif child is RunRouteAtlas.ChoiceTicket:
			ticket_count += 1
		elif child is RunRouteAtlas.NextAreaTab:
			tab_count += 1
			_verify_next_area_tab(view, map, child, label)
		elif child is Label:
			var header: Label = child
			if header.has_meta("floor_number") and not header.has_meta("area_name"):
				var f: int = header.get_meta("floor_number")
				_check(visible_floors.has(f) and not seen_headers.has(f)
					and header.text == "FLOOR %02d" % f,
					label + ": one readable heading for upcoming floor %d" % f)
				_check(_is_heading(header, 18),
					label + ": numbered FLOOR %d is an inert 18-point PatchHeading heading" % f)
				seen_headers[f] = true
			_check(_inside(Rect2(header.position, header.size), RunRouteAtlas.PAGE_RIGHT)
				and header.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				label + ": inert book heading fully inside right page")
		elif child is RunRouteAtlas.CurrentPin:
			var pin: RunRouteAtlas.CurrentPin = child
			seen_pins.append(pin.get_meta("pin_node_id"))
			_check(pin.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and pin.focus_mode == Control.FOCUS_NONE
				and _inside(Rect2(pin.position, pin.size), RunRouteAtlas.PAGE_RIGHT),
				label + ": real current pin rests over right-page origin")
		else:
			_check(false, label + ": unexpected atlas child " + child.name)
	for id in seen_nodes:
		var a: PanelContainer = seen_nodes[id]
		for other_id in seen_nodes:
			if id != other_id:
				var b: PanelContainer = seen_nodes[other_id]
				_check(not Rect2(a.position, a.size).intersects(Rect2(b.position, b.size)),
					label + ": authored rows/columns do not overlap " + id + "/" + other_id)
	for key in seen_edges:
		var line: Line2D = seen_edges[key]
		var parts: PackedStringArray = String(key).split("->")
		var from_marker: PanelContainer = seen_nodes[parts[0]]
		var to_marker: PanelContainer = seen_nodes[parts[1]]
		_check(line.points[0].is_equal_approx(from_marker.position + Vector2(
			RunRouteAtlas.NODE_SIZE.x, RunRouteAtlas.NODE_SIZE.y * 0.5))
			and line.points[12].is_equal_approx(to_marker.position + Vector2(
				0, RunRouteAtlas.NODE_SIZE.y * 0.5)),
			label + ": sewn edge meets exact visible token endpoints " + key)
	_check(seen_nodes.size() == visible_ids.size()
		and seen_edges.size() == expected_edges.size()
		and seen_headers.size() == visible_floors.size(),
		label + ": exact visible window markers, connected links and floor headings")
	_check(last_thread < first_marker and journal_count == 1 and tab_count == 1
		and ticket_count == (0 if legal.is_empty() else 1),
		label + ": threads behind patches; one journey and status tab")
	_check(seen_pins == ([] if current_id.is_empty() else [current_id]),
		label + ": only current visited node wears a physical pin")
	if not current_id.is_empty() and seen_nodes.has(current_id):
		var marker: PanelContainer = seen_nodes[current_id]
		var pin := view.get_node("Pin_current") as RunRouteAtlas.CurrentPin
		_check(Rect2(pin.position, pin.size).intersects(Rect2(marker.position, marker.size)),
			label + ": pin follows the actual visited patch")
	_verify_choice_ticket(view, map, label)
	_verify_area_labels(view, visible_floors, label)
	# The completed route has no upcoming column, so it must not keep stale headings.
	if visible_floors.is_empty():
		var stale_headings := 0
		for child in view.get_children():
			if child is Label:
				stale_headings += 1
		_check(stale_headings == 0,
			label + ": a completed route leaves no stale area or floor heading")
	_verify_book(view, label)
	_check(_state(map, rng) == before,
		label + ": window refresh and examination never mutate model or seeded RNG")


func _signature(view: RunRouteAtlas) -> Array:
	var result: Array = []
	for child in view.get_children():
		if child is PanelContainer:
			var marker: PanelContainer = child
			var style: StyleBoxFlat = marker.get_theme_stylebox("panel") as StyleBoxFlat
			var token := marker.get_node_or_null("Art") as RunRouteAtlas.NodeToken
			result.append(["node", marker.get_meta("route_id"), marker.get_meta("route_kind"),
				marker.get_meta("route_state"), marker.position, marker.size, style.bg_color,
				style.border_color, (marker.get_node("Identity") as Label).text,
				"" if token == null else token.token_kind,
				"" if token == null else str(token.get_meta("art_path"))])
		elif child is Line2D:
			var thread: Line2D = child
			result.append(["edge", thread.get_meta("from_id"), thread.get_meta("to_id"),
				thread.get_meta("route_state"), thread.points, thread.default_color])
		elif child is Label:
			if child.has_meta("area_name"):
				result.append(["area", str(child.get_meta("area_name")), (child as Label).text,
					(child as Label).position, (child as Label).size])
			else:
				result.append(["floor", child.get_meta("floor_number"), (child as Label).text,
					(child as Label).position])
		elif child is RunRouteAtlas.JourneyJournal:
			var journal: RunRouteAtlas.JourneyJournal = child
			result.append(["journey", journal.current_floor, journal.current_area,
				journal.next_floor, journal.next_area, journal.complete, journal.visited.duplicate(),
				journal.visited_kinds.duplicate(), journal.position, journal.size])
		elif child is RunRouteAtlas.ChoiceTicket:
			var ticket := child as RunRouteAtlas.ChoiceTicket
			# Transient hovered/focused text is checked by _verify_choice_ticket instead;
			# deterministic scene structure must not depend on pointer location.
			result.append(["ticket", ticket.position, ticket.size])
		elif child is RunRouteAtlas.NextAreaTab:
			result.append(["next_area", (child as RunRouteAtlas.NextAreaTab).text,
				child.position, child.size])
		elif child is RunRouteAtlas.CurrentPin:
			result.append(["pin", child.get_meta("pin_node_id"), child.position, child.size])
	return result


func _crossing_present(view: RunRouteAtlas, map: RunMap, label: String) -> void:
	var floors: Array = map.get_floors()
	if floors.size() < 2 or floors[0].size() < 2 or floors[1].size() < 2:
		_check(false, label + ": map has crossing preconditions")
		return
	var first_id: String = floors[0][0]["id"]
	var second_id: String = floors[0][1]["id"]
	var upper_target: String = floors[1][0]["id"]
	var lower_target: String = floors[1][1]["id"]
	_check(floors[0][0]["outgoing"].has(lower_target) and floors[0][1]["outgoing"].has(upper_target),
		label + ": crossing is present in authoritative map")
	var down: Line2D = null
	var up: Line2D = null
	for child in view.get_children():
		if child is Line2D:
			if child.get_meta("from_id") == first_id and child.get_meta("to_id") == lower_target:
				down = child
			if child.get_meta("from_id") == second_id and child.get_meta("to_id") == upper_target:
				up = child
	_check(down != null and up != null, label + ": both crossing directed links are actually rendered")
	if down != null and up != null:
		_check(down.points[0].y < up.points[0].y and down.points[12].y > up.points[12].y,
			label + ": actual link coordinates geometrically cross")


func _record_request(id: String) -> void:
	requests.append(id)


## Both backdrop paths must work for the mounted open book: owner art or drawing.
func _exercise_board_art(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		label: String) -> void:
	var before := _state(map, rng)
	var drawn_signature := _signature(view)
	var stored_path := view.board_texture_path
	_check(RunRouteAtlas.MAP_BOARD_PATH == "res://assets/paper/backgrounds/map_board.png",
		label + ": owner board art path is the paper backdrop folder")
	_check(RunRouteAtlas.load_board_texture("res://assets/paper/backgrounds/missing_map_board.png") == null
		and RunRouteAtlas.load_board_texture("") == null,
		label + ": a missing or blank owner board image is not an error")
	# Drawn fallback: force the missing-art path even when the owner image exists.
	view.board_texture_path = "res://assets/paper/backgrounds/missing_map_board.png"
	view.board_texture_override = null
	view.refresh()
	_check(not view.uses_board_texture() and view.board_texture() == null
		and not view.drawn_book_geometry().is_empty(),
		label + ": missing art keeps the complete drawn fallback")
	_verify_book(view, label + " drawn fallback")
	_verify_area_labels(view, [1, 2, 3], label + " drawn fallback")
	_check(_signature(view) == drawn_signature and _state(map, rng) == before,
		label + ": the drawn book leaves nodes, route and RNG alone")
	# Owner art path: the real image when it exists, else the same in-memory image.
	var art := RunRouteAtlas.load_board_texture(RunRouteAtlas.MAP_BOARD_PATH)
	if art == null:
		var image := Image.create(64, 36, false, Image.FORMAT_RGBA8)
		image.fill(Color("#e8dcb6"))
		art = ImageTexture.create_from_image(image)
	view.board_texture_override = art
	view.board_texture_path = RunRouteAtlas.MAP_BOARD_PATH
	view.refresh()
	_check(view.uses_board_texture() and view.board_texture() == art
		and view.drawn_book_geometry().is_empty(),
		label + ": an owner board image replaces the drawing in the same preview")
	_verify_book(view, label + " owner art")
	_verify_area_labels(view, [1, 2, 3], label + " owner art")
	_check(view.board_texture_rect() == Rect2(Vector2.ZERO, view.size),
		label + ": mounted owner board covers the whole map preview")
	_check(_signature(view) == drawn_signature and _state(map, rng) == before,
		label + ": the board image only changes the backdrop, not nodes or route")
	view.board_texture_override = null
	view.board_texture_path = stored_path
	view.refresh()
	_check(_signature(view) == drawn_signature and _state(map, rng) == before,
		label + ": restoring the configured board leaves nodes, route and RNG alone")


func _action(view: RunRouteAtlas, id: String) -> Button:
	for child in view.get_children():
		if child is PanelContainer and child.get_meta("route_id") == id:
			return child.get_node_or_null("Action") as Button
	return null


## Read-only visited-kind captions currently drawn by the mounted left-page diary.
func _journal_kinds(view: RunRouteAtlas) -> Array[String]:
	var journal := view.get_node_or_null("JourneyJournal") as RunRouteAtlas.JourneyJournal
	if journal == null:
		var empty: Array[String] = []
		return empty
	return journal.visited_kind_sequence()


func _click_action(action: Button) -> void:
	_check(action != null and action.is_visible_in_tree(), "mouse target is a mounted actionable button")
	if action == null or not action.is_visible_in_tree():
		return
	var point := action.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "click point lies within viewport")
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _key_action(action: Button, code: Key) -> void:
	_check(action != null and action.is_visible_in_tree(), "keyboard target is a mounted actionable button")
	if action == null or not action.is_visible_in_tree():
		return
	action.grab_focus()
	_check(action.has_focus(), "real legal marker receives focus")
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _exercise_requests(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		label: String) -> void:
	var legal := map.get_legal_choices()
	_check(not legal.is_empty(), label + ": real legal choices before input")
	if legal.is_empty():
		return
	var before := _state(map, rng)
	seed(87001)
	var expected_global := randi()
	seed(87001)
	for id in legal:
		var action := _action(view, id)
		_check(action != null, label + ": expected mounted action " + id)
		if action == null:
			continue
		for mode in ["mouse", "enter", "space"]:
			requests.clear()
			if mode == "mouse":
				await _click_action(action)
			else:
				await _key_action(action, KEY_ENTER if mode == "enter" else KEY_SPACE)
			_check(requests == [id], label + ": " + mode + " emits exactly canonical " + id)
			_check(_state(map, rng) == before, label + ": " + mode + " never changes route/RNG")
	_check(randi() == expected_global, label + ": all inputs avoid global RNG")
	requests.clear()


# ---------------------------------------------------------------------------
# Progressive reveal of newly legal stitches (presentation only).
# ---------------------------------------------------------------------------

func _ordered_legal(map: RunMap) -> Array[String]:
	var result: Array[String] = []
	var legal := map.get_legal_choices()
	for floor_nodes in map.get_floors():
		var by_position: Array = floor_nodes.duplicate()
		by_position.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["position"]) < int(b["position"]))
		for node in by_position:
			var id: String = node["id"]
			if legal.has(id) and not map.get_route().has(id):
				result.append(id)
	return result


## Directed edges the authoritative map paints as visited-to-legal, sorted canonically.
func _legal_edge_keys(map: RunMap) -> Array[String]:
	var keys: Array[String] = []
	var route := map.get_route()
	var legal := map.get_legal_choices()
	for floor_nodes in map.get_floors():
		for node in floor_nodes:
			var source: String = node["id"]
			if not route.has(source):
				continue
			for target in node["outgoing"]:
				if legal.has(target):
					keys.append(source + "->" + str(target))
	keys.sort()
	return keys


func _line_for(view: RunRouteAtlas, key: String) -> Line2D:
	for child in view.get_children():
		if child is Line2D \
				and str(child.get_meta("from_id")) + "->" + str(child.get_meta("to_id")) == key:
			return child as Line2D
	return null


func _no_masks(view: RunRouteAtlas) -> bool:
	return _mask_count(view) == 0


func _mask_count(view: RunRouteAtlas) -> int:
	var count := 0
	for child in view.get_children():
		if child is Line2D and child.gradient != null:
			count += 1
	return count


## Offset of the sewing front: the first sampled position the mask leaves transparent.
func _reveal_front(mask: Gradient) -> float:
	if mask == null:
		return 1.0
	for step in range(1, 101):
		var offset := float(step) / 100.0
		if mask.sample(offset).a < 0.5:
			return offset
	return 1.0


## Behind the front the installed gradient is the only colour Godot draws, because setting
## Line2D.gradient replaces default_color. Those pixels must be the legal thread, not white,
## and everything ahead of the moving front must still be transparent.
func _verify_reveal_colour(line: Line2D, label: String) -> void:
	var key := "unknown"
	if line != null and line.has_meta("from_id") and line.has_meta("to_id"):
		key = str(line.get_meta("from_id")) + "->" + str(line.get_meta("to_id"))
	var mask: Gradient = line.gradient if line != null else null
	_check(mask != null, label + ": sewing stitch still carries its reveal mask: " + key)
	if mask == null:
		return
	var front := _reveal_front(mask)
	var sewn := mask.sample(clampf(front - 0.01, 0.0, 1.0))
	var unsewn := mask.sample(clampf(front + 0.01, 0.0, 1.0))
	var transparent_legal := Color(RunRouteAtlas.LEGAL_THREAD.r, RunRouteAtlas.LEGAL_THREAD.g,
		RunRouteAtlas.LEGAL_THREAD.b, 0.0)
	_check(sewn.is_equal_approx(RunRouteAtlas.LEGAL_THREAD)
		and is_equal_approx(sewn.a, RunRouteAtlas.LEGAL_THREAD.a)
		and not (is_equal_approx(sewn.r, 1.0) and is_equal_approx(sewn.g, 1.0)
			and is_equal_approx(sewn.b, 1.0)),
		label + ": sewn pixels behind the front sample the legal thread colour: " + key)
	_check(unsewn.is_equal_approx(transparent_legal) and is_zero_approx(unsewn.a),
		label + ": pixels ahead of the front stay transparent: " + key)


## Select one real legal node, then confirm only its newly legal stitches are masking.
func _reveal_step(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		label: String) -> Array[String]:
	var legal := map.get_legal_choices()
	_check(not legal.is_empty(), label + ": real legal node before the step")
	if legal.is_empty():
		return []
	var before := _state(map, rng)
	_check(map.choose_node(legal[0]), label + ": real node selected")
	_check(_state(map, rng)["rng"] == before["rng"], label + ": progression spends no run RNG")
	view.refresh()
	var expected := _legal_edge_keys(map)
	_check(not expected.is_empty(), label + ": selected node exposes visited-to-legal stitches")
	_check(view.revealing_edges() == expected, label + ": exactly the new legal stitches reveal")
	var masked := 0
	for child in view.get_children():
		if not (child is Line2D):
			continue
		var line: Line2D = child
		if line.gradient == null:
			continue
		masked += 1
		var key := str(line.get_meta("from_id")) + "->" + str(line.get_meta("to_id"))
		_check(expected.has(key) and line.default_color == RunRouteAtlas.LEGAL_THREAD
			and line.points.size() == 16,
			label + ": masked thread is a new legal stitch on its canonical path: " + key)
		_verify_reveal_colour(line, label)
	_check(masked == expected.size(), label + ": every and only new legal stitch carries a mask")
	_check(_state(map, rng)["rng"] == before["rng"], label + ": refresh during a reveal spends no run RNG")
	return expected


## Real seeded selected nodes must sew their new legal stitches in, then settle.
func _exercise_reveal(seed_value: int) -> void:
	var rng := _rng(seed_value)
	var map := RunMap.new()
	_check(map.generate(rng), "reveal fixture generated from a real seed")
	var view := RunRouteAtlas.new()
	view.position = Vector2(20, 40)
	root.add_child(view)
	view.node_requested.connect(_record_request)
	await process_frame
	requests.clear()
	seed(99013)
	var expected_global := randi()
	seed(99013)
	var opening := _state(map, rng)
	view.bind_map(map)
	_check(not view.is_revealing() and view.revealing_edges().is_empty() and _no_masks(view),
		"opening snapshot has no visited-to-legal stitch to reveal")
	_check(view.reveal_duration() == RunRouteAtlas.REVEAL_DURATION
		and is_equal_approx(RunRouteAtlas.REVEAL_DURATION, 0.6)
		and is_equal_approx(RunRouteAtlas.REVEAL_FAST_DURATION, 0.15),
		"normal reveal is bounded to 0.6 s and fast mode to 0.15 s")
	_check(_state(map, rng) == opening, "binding an unvisited map starts no reveal or model change")
	_verify(view, map, rng, "reveal opening seed %d" % seed_value)

	# Normal presentation: the first real selected node exposes new legal stitches.
	view.set_reveal_fast(false)
	var first_keys := await _reveal_step(view, map, rng, "seed %d slow reveal" % seed_value)
	_check(first_keys.size() >= 2, "selected node exposes several legal stitches")
	var probe: Line2D = _line_for(view, first_keys[0]) if not first_keys.is_empty() else null
	_check(probe != null and probe.gradient != null
		and probe.get_meta("route_state") == "legal"
		and probe.default_color == RunRouteAtlas.LEGAL_THREAD and probe.points.size() == 16,
		"newly legal stitch keeps canonical state, colour and path under its mask")
	var mask: Gradient = null
	if probe != null:
		mask = probe.gradient
	_check(_reveal_front(mask) <= 0.02, "stitch starts hidden at its source end")
	# Exact graph, geometry and colour checks while the reveal is still animating.
	_verify(view, map, rng, "seed %d mid reveal" % seed_value)
	await create_timer(0.15).timeout
	_check(view.is_revealing(), "stitch is still sewing shortly after progression")
	var first_front := _reveal_front(mask)
	_check(first_front > 0.05 and first_front < 0.95,
		"stitch partially reveals from its source end")
	_check(probe != null and probe.default_color == RunRouteAtlas.LEGAL_THREAD
		and probe.points.size() == 16,
		"partial reveal leaves the canonical colour and geometry alone")
	_verify_reveal_colour(probe, "seed %d mid reveal" % seed_value)
	await create_timer(0.1).timeout
	_check(probe != null and probe.gradient != null
		and _reveal_front(probe.gradient) > first_front,
		"sewing front advances further along the same thread")
	_verify_reveal_colour(probe, "seed %d advanced reveal" % seed_value)
	await create_timer(0.45).timeout
	_check(not view.is_revealing() and _no_masks(view),
		"reveal settles within 0.6 s and drops every temporary mask")
	for key in first_keys:
		var line: Line2D = _line_for(view, key)
		_check(line != null and line.gradient == null
			and line.default_color == RunRouteAtlas.LEGAL_THREAD and line.points.size() == 16,
			"settled stitch keeps its full authoritative colour: " + key)
	_verify(view, map, rng, "seed %d revealed floor" % seed_value)
	# Repeated viewing of an unchanged snapshot never replays the reveal.
	var settled_floors := map.get_floors()
	view.refresh()
	_check(not view.is_revealing() and _no_masks(view),
		"repeated refresh does not replay a settled reveal")
	view.refresh()
	_check(not view.is_revealing() and _no_masks(view)
		and map.get_floors() == settled_floors,
		"second repeat refresh stays inert and leaves the canonical graph alone")

	# Inputs must never wait for the reveal.
	var second_keys := await _reveal_step(view, map, rng, "seed %d input reveal" % seed_value)
	_check(view.is_revealing() and not second_keys.is_empty(),
		"input probe runs on an actively revealing atlas")
	var ordered := _ordered_legal(map)
	var key_down := InputEventKey.new()
	key_down.keycode = KEY_1
	key_down.pressed = true
	root.push_input(key_down, true)
	_check(not ordered.is_empty() and requests == [ordered[0]],
		"numeric shortcut emits its request synchronously during a reveal")
	_check(view.is_revealing(), "a running reveal never delays a keyboard request")
	var key_up := InputEventKey.new()
	key_up.keycode = KEY_1
	key_up.pressed = false
	root.push_input(key_up, true)
	requests.clear()
	var before_click := _state(map, rng)
	var action: Button = _action(view, ordered[0]) if not ordered.is_empty() else null
	_check(action != null, "input probe action is really mounted")
	if action != null:
		await _click_action(action)
		_check(requests == [ordered[0]], "mouse request is admitted during a reveal")
		_check(view.is_revealing(), "a running reveal never delays a mouse request")
	_check(_state(map, rng) == before_click, "inputs during a reveal spend no map or RNG state")
	requests.clear()

	# Teardown and rebind must release the tween and masks before children go.
	view.bind_map(null)
	_check(not view.is_revealing() and view.get_child_count() == 0,
		"null bind mid-reveal releases tween and masks with its threads")
	await process_frame
	await process_frame
	_check(view.get_child_count() == 0 and not view.is_revealing(),
		"no orphan tween or mask resurrects after a null bind")
	view.bind_map(map)
	var rebind_keys := _legal_edge_keys(map)
	_check(view.revealing_edges() == rebind_keys,
		"rebind re-arms exactly the visited-to-legal stitches, without duplicates")
	_verify(view, map, rng, "seed %d rebind reveal" % seed_value)
	var other_rng := _rng(seed_value + 1)
	var other := RunMap.new()
	_check(other.generate(other_rng), "replacement map fixture generated")
	view.bind_map(other)
	_check(not view.is_revealing() and _no_masks(view),
		"replacement bind mid-reveal tears the old mask down")
	_check(_journal_kinds(view).is_empty(),
		"a newly generated replacement map cannot retain the previous visited kinds")
	_verify(view, other, other_rng, "seed %d replacement bind" % seed_value)

	# Fast presentation: the same reveal in 0.15 s.
	view.bind_map(map)
	_check(view.is_revealing(), "progressed map re-arms a reveal on rebind")
	view.set_reveal_fast(true)
	var fast_keys := await _reveal_step(view, map, rng, "seed %d fast reveal" % seed_value)
	_check(view.reveal_duration() == RunRouteAtlas.REVEAL_FAST_DURATION
		and is_equal_approx(RunRouteAtlas.REVEAL_FAST_DURATION, 0.15),
		"fast presentation switch shortens the reveal to 0.15 s")
	_check(not fast_keys.is_empty() and view.revealing_edges() == fast_keys,
		"fast mode reveals each new legal stitch")
	for key in fast_keys:
		_verify_reveal_colour(_line_for(view, key), "seed %d fast reveal" % seed_value)
	await create_timer(0.2).timeout
	_check(not view.is_revealing() and _no_masks(view),
		"fast reveal settles within 0.15 s")
	for key in fast_keys:
		var line: Line2D = _line_for(view, key)
		_check(line != null and line.gradient == null
			and line.default_color == RunRouteAtlas.LEGAL_THREAD and line.points.size() == 16,
			"fast settled stitch keeps its authoritative colour: " + key)
	_verify(view, map, rng, "seed %d fast revealed floor" % seed_value)
	view.set_reveal_fast(false)
	_check(view.reveal_duration() == RunRouteAtlas.REVEAL_DURATION,
		"normal reveal duration is restored")

	# The live overlay binds its map before mounting the view, so a queued reveal
	# must start on the first mounted frame instead of being dropped.
	var queued_rng := _rng(seed_value + 2)
	var queued_map := RunMap.new()
	_check(queued_map.generate(queued_rng), "queued-reveal fixture generated")
	var queued_id: String = queued_map.get_legal_choices()[0]
	_check(queued_map.choose_node(queued_id), "queued-reveal fixture has one visited node")
	var queued_view := RunRouteAtlas.new()
	queued_view.position = Vector2(20, 40)
	queued_view.bind_map(queued_map)
	_check(not queued_view.is_inside_tree() and queued_view.is_revealing()
		and _mask_count(queued_view) == _legal_edge_keys(queued_map).size()
		and _mask_count(queued_view) > 0,
		"binding before mounting queues the reveal like the live overlay does")
	root.add_child(queued_view)
	_check(queued_view.is_revealing(), "queued reveal is retained once the view is mounted")
	await create_timer(0.15).timeout
	_check(queued_view.is_revealing() and not _no_masks(queued_view),
		"queued reveal sews in on the mounted view")
	await create_timer(0.5).timeout
	_check(not queued_view.is_revealing() and _no_masks(queued_view),
		"queued reveal settles within 0.6 s")
	_verify(queued_view, queued_map, queued_rng, "seed %d queued reveal" % seed_value)
	queued_view.queue_free()
	await process_frame

	# A completed run map is inert: no legal stitch exists to reveal.
	var done_rng := _rng(seed_value)
	var done := RunMap.new()
	_check(done.generate(done_rng), "completed-map fixture generated")
	for step in range(12):
		var choices := done.get_legal_choices()
		if choices.is_empty() or not done.choose_node(choices[0]):
			break
	_check(done.is_complete() and done.get_legal_choices().is_empty(), "fixture reaches the boss")
	view.bind_map(done)
	_check(not view.is_revealing() and _no_masks(view),
		"completed maps stay inert with no reveal or mask")
	_verify(view, done, done_rng, "seed %d completed reveal" % seed_value)
	_check(rng.state == opening["rng"], "the whole reveal sequence spends no run RNG")
	_check(randi() == expected_global, "progressive reveals never consume the global RNG")
	view.bind_map(null)
	_check(not view.is_revealing() and view.get_child_count() == 0,
		"final null bind leaves the reveal machinery empty")
	view.queue_free()
	await process_frame


# AC1/AC2: the tab across a genuine legal 12-floor route, teardown and reseeding.
func _exercise_status_tab(view: RunRouteAtlas) -> void:
	var rng := _rng(1234)
	var map := RunMap.new()
	_check(map.generate(rng), "status tab fixture generated from a real seed")
	var before := _state(map, rng)
	view.bind_map(map)
	var opening := view.next_area_tab()
	_check(opening != null and opening.text == "Next: Meadow · Floor 1/12"
		and map.get_current_floor() == 0,
		"opening tab prompts the authored Meadow floor 1 at current floor 0")
	_check(_state(map, rng) == before,
		"mounting the status tab changes no map graph, route, legal choice or RNG state")
	# AC1: zero committed choices caption no bead at all, and a repeat refresh keeps it so.
	var opening_journal := view.get_node_or_null("JourneyJournal") as RunRouteAtlas.JourneyJournal
	_check(opening_journal != null and opening_journal.visited.is_empty()
		and opening_journal.visited_kinds.is_empty()
		and opening_journal.visited_kind_sequence().is_empty(),
		"an unvisited route shows numbered beads but no visited-kind caption")
	view.refresh()
	view.refresh()
	_check(_journal_kinds(view).is_empty()
		and (view.get_node_or_null("JourneyJournal") as RunRouteAtlas.JourneyJournal) != null,
		"repeated refresh never duplicates or invents a caption on the empty trail")
	var required := {
		3: "Next: Woods · Floor 4/12",
		6: "Next: Marsh · Floor 7/12",
		9: "Next: Peaks · Floor 10/12",
		11: "Next: Boss · Floor 12/12",
	}
	for floor_number in range(1, 13):
		var legal := map.get_legal_choices()
		_check(not legal.is_empty(), "status tab floor %d offers real legal choices" % floor_number)
		if legal.is_empty():
			break
		var step_before := _state(map, rng)
		_check(map.choose_node(legal[0]), "status tab commits a real legal node on floor %d" % floor_number)
		_check(_state(map, rng)["rng"] == step_before["rng"],
			"real progression under the status tab spends no run RNG")
		view.refresh()
		var tab := view.next_area_tab()
		_check(map.get_current_floor() == floor_number,
			"real current floor is %d after the commit" % floor_number)
		_check(tab != null and tab.text == _expected_next_area_text(map),
			"refreshed tab tracks the real next floor after floor %d" % floor_number)
		if required.has(floor_number):
			_check(tab != null and tab.text == required[floor_number],
				"authored boundary text after floor %d: " % floor_number + str(required[floor_number]))
		if tab != null:
			_check(not tab.text.contains("Floor 13"),
				"no floor 13 caption after floor %d" % floor_number)
	_check(map.is_complete() and map.get_current_floor() == 12
		and map.get_legal_choices().is_empty(), "genuine legal route reaches the boss")
	view.refresh()
	_check(view.next_area_tab() != null
		and view.next_area_tab().text == "Route complete · Floor 12/12",
		"completed route shows the terminal caption instead of a playable prompt")
	# AC2: twelve authentic captions, floor 12 is the Boss, and a refresh is idempotent.
	var completed_kinds := _journal_kinds(view)
	_check(completed_kinds.size() == 12 and completed_kinds.back() == "Boss"
		and not completed_kinds.has(""),
		"completed legal route captions twelve authentic kinds ending at the Boss")
	view.refresh()
	_check(_journal_kinds(view) == completed_kinds,
		"an unchanged refresh keeps exactly the same completed captions without duplicates")
	view.bind_map(null)
	_check(view.next_area_tab() == null and view.get_child_count() == 0,
		"null bind removes the next-area tab with the map children")
	var empty := RunMap.new()
	view.bind_map(empty)
	_check(view.next_area_tab() == null
		and view.get_node_or_null("JourneyJournal") == null,
		"an ungenerated map keeps no prior area, floor caption or visited history")
	view.bind_map(map)
	_check(view.next_area_tab() != null
		and view.next_area_tab().text == "Route complete · Floor 12/12",
		"rebinding the completed map recomputes its terminal caption from scratch")
	var fresh_rng := _rng(4321)
	var fresh := RunMap.new()
	_check(fresh.generate(fresh_rng), "fresh status tab fixture generated")
	view.bind_map(fresh)
	_check(view.next_area_tab() != null
		and view.next_area_tab().text == "Next: Meadow · Floor 1/12",
		"a freshly generated map returns to the floor-1 Meadow prompt")
	var fresh_journal := view.get_node_or_null("JourneyJournal") as RunRouteAtlas.JourneyJournal
	_check(fresh_journal != null and fresh_journal.visited.is_empty()
		and fresh_journal.visited_kinds.is_empty() and _journal_kinds(view).is_empty(),
		"a freshly generated map cannot retain the previous run's visited kinds")
	var frozen := _state(fresh, fresh_rng)
	view.refresh()
	_check(_state(fresh, fresh_rng) == frozen
		and view.next_area_tab() != null
		and view.next_area_tab().text == "Next: Meadow · Floor 1/12",
		"refreshing the status tab leaves the seeded map and RNG untouched")
	view.bind_map(null)


# AC1/AC2: the diary's two display headings resolve the mounted PatchHeading face, and
# a detached diary without such a Theme still draws the shipped Londrina fallback.
func _verify_journal_headings() -> void:
	var master := load("res://assets/fonts/patchwork_theme.tres") as Theme
	var master_heading: Font = master.get_font("font", "PatchHeading") if master != null else null
	_check(master_heading != null and master_heading.resource_path == HEADING_FONT
		and master.get_font_list("PatchHeading").has("font")
		and RunRouteAtlas.HEADING_FONT_PATH == HEADING_FONT,
		"journal heading fixture names the shipped Londrina PatchHeading face")
	# The resolver must inspect a Theme's authored faces, not accept its default font.
	_check(RunRouteAtlas.patch_heading_face(master) == master_heading
		and RunRouteAtlas.patch_heading_face(null) == null
		and RunRouteAtlas.patch_heading_face(Theme.new()) == null,
		"heading resolver reads only a Theme's real PatchHeading face")
	var detached := RunRouteAtlas.JourneyJournal.new()
	_check(not detached.is_inside_tree() and detached.get_parent() == null
		and detached.theme == null and detached.inherited_theme() == null,
		"detached diary inherits no Theme that could supply PatchHeading")
	var fallback := detached.heading_font()
	_check(fallback != null and fallback is FontFile
		and fallback.resource_path == HEADING_FONT,
		"detached diary headings resolve the committed Londrina Solid file")
	_check(detached.heading_font() == fallback and _font_path(detached) == BODY_FONT,
		"detached diary still keeps its facts in Patrick Hand and caches the fallback")
	# An inherited Theme that really authors PatchHeading wins over any fallback.
	var themed := RunRouteAtlas.JourneyJournal.new()
	themed.theme = master
	_check(themed.heading_font() == master_heading
		and themed.heading_font().resource_path == HEADING_FONT,
		"an inherited PatchHeading Theme supplies the diary display face")
	# A mounted Theme without the variation cannot pass its default font off as headings.
	themed.theme = Theme.new()
	_check(themed.heading_font() == fallback
		and themed.heading_font().resource_path == HEADING_FONT
		and themed.heading_font() != themed.get_theme_default_font(),
		"a Theme without PatchHeading keeps the committed heading face, not the body face")
	themed.free()
	detached.free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	# App mounts this view under PatchworkUIShell's installed master Theme, so install that
	# same Theme here. A bare variation string would prove nothing: the mounted labels must
	# resolve the genuine Londrina heading face through the inherited Theme.
	var master_theme := load("res://assets/fonts/patchwork_theme.tres") as Theme
	var master_heading: Font = master_theme.get_font("font", "PatchHeading") if master_theme != null else null
	var master_body: Font = master_theme.default_font if master_theme != null else null
	_check(master_theme != null and master_theme.is_type_variation("PatchHeading", "Label")
		and master_heading != null and master_heading.resource_path == HEADING_FONT
		and master_body != null and master_body.resource_path == BODY_FONT,
		"shipped master Theme still supplies the PatchHeading Londrina heading and Patrick Hand body")
	if master_theme != null:
		root.theme = master_theme
	_verify_journal_headings()
	var first := RunRouteAtlas.new()
	first.position = Vector2(20, 40)
	root.add_child(first)
	first.node_requested.connect(_record_request)
	await process_frame
	_check(first.is_inside_tree(), "read-only Control actually mounted in window")

	var empty := RunMap.new()
	first.bind_map(empty)
	_check(first.get_child_count() == 0, "ungenerated map displays no invented markers")
	first.bind_map(null)
	_check(first.get_child_count() == 0, "null map is empty and inert")
	# Token mapping, optional loading/caching and both marker branches, on the mounted view.
	_verify_token_sources(first, "token sources")

	for seed_value in [6, 42]:
		var rng := _rng(seed_value)
		var replay_rng := _rng(seed_value)
		var map := RunMap.new()
		var replay := RunMap.new()
		_check(map.generate(rng) and replay.generate(replay_rng), "both real maps generated for seed %d" % seed_value)
		var other := RunRouteAtlas.new()
		other.position = Vector2(20, 40)
		root.add_child(other)
		await process_frame
		# Guard the same global RNG stream that a bad view could accidentally consume.
		seed(10121 + seed_value)
		var expected_global := randi()
		seed(10121 + seed_value)
		var before := _state(map, rng)
		first.bind_map(map)
		other.bind_map(replay)
		_verify(first, map, rng, "opening seed %d" % seed_value)
		_verify(other, replay, replay_rng, "opening replay seed %d" % seed_value)
		_crossing_present(first, map, "seed %d crossing" % seed_value)
		if seed_value == 6:
			_exercise_board_art(first, map, rng, "seed %d board" % seed_value)
		_check(_state(map, rng) == before and rng.state == replay_rng.state
			and _signature(first) == _signature(other),
			"identical seed renders byte-for-byte comparable children and never alters graph/route/RNG")
		_check(randi() == expected_global, "atlas does not consume global RNG for seed %d" % seed_value)
		other.hide()
		await _exercise_requests(first, map, rng, "seed %d opening" % seed_value)
		var original_signature := _signature(first)
		var read_graph := map.get_floors()
		var original_floors := map.get_floors()
		read_graph[0][0]["type"] = "Forged"
		read_graph[0][0]["outgoing"].clear()
		read_graph.clear()
		var read_node := map.get_node(original_floors[0][0]["id"])
		read_node["type"] = "Forged"
		read_node["outgoing"].clear()
		var read_choices := map.get_legal_choices()
		read_choices.clear()
		read_choices.append("forged")
		_check(map.get_floors() == original_floors and _signature(first) == original_signature,
			"external graph/node/legal snapshots cannot mutate map or already-rendered atlas")
		for repeat in range(3):
			var old := _state(map, rng)
			first.refresh()
			_check(_signature(first) == original_signature and _state(map, rng) == old,
				"repeated refresh keeps same view, map and supplied RNG")
			_verify(first, map, rng, "repeat opening seed %d" % seed_value)

		var first_floor: Array = map.get_floors()[0]
		_check(not first_floor.is_empty() and map.get_legal_choices().size() == first_floor.size(),
			"real initial choices match complete opening floor")
		var before_bad := _state(map, rng)
		_check(not map.choose_node(map.get_floors()[2][0]["id"]) and not map.choose_node("unknown"),
			"real RunMap rejects floor skip and unknown node")
		_check(_state(map, rng) == before_bad, "bad opening never changes map or RNG")
		first.refresh()
		_verify(first, map, rng, "rejected opening seed %d" % seed_value)

		var old_action := _action(first, map.get_legal_choices()[0])
		_check(old_action != null, "old legal callback exists before advancing")
		var stale: Callable = old_action.pressed.get_connections()[0].callable if old_action != null else Callable()
		for floor_number in range(1, 13):
			var legal := map.get_legal_choices()
			var replay_legal := replay.get_legal_choices()
			_check(not legal.is_empty() and legal == replay_legal,
				"both maps offer identical legal path on floor %d" % floor_number)
			if legal.is_empty():
				break
			var chosen: String = legal[0]
			var previous := _state(map, rng)
			_check(map.choose_node(chosen) and replay.choose_node(chosen),
				"real legal step committed on floor %d" % floor_number)
			if stale.is_valid():
				requests.clear()
				stale.call()
				_check(requests.is_empty(), "external progression blocks prior marker callback")
			_check(map.get_route().size() == floor_number
				and map.get_current_node_id() == chosen and rng.state == previous["rng"],
				"only RunMap legal choice advances floor and spends no RNG")
			first.refresh()
			other.refresh()
			_verify(first, map, rng, "seed %d floor %d" % [seed_value, floor_number])
			_check(_action(first, chosen) == null, "selected node loses action after progression")
			if floor_number < 12 and floor_number in [1, 6]:
				await _exercise_requests(first, map, rng, "seed %d floor %d" % [seed_value, floor_number])
			_check(_signature(first) == _signature(other) and _state(map, rng) == _state(replay, replay_rng),
				"same seeded replay produces identical nodes, threads, highlights, graph and RNG")
			var route_copy := map.get_route()
			route_copy.clear()
			route_copy.append("forged")
			var legal_copy := map.get_legal_choices()
			legal_copy.clear()
			legal_copy.append("forged")
			if stale.is_valid():
				requests.clear()
				stale.call()
				_check(requests.is_empty(), "external progression blocks prior marker callback")
			_check(map.get_route().size() == floor_number
				and not map.get_route().has("forged") and not map.get_legal_choices().has("forged"),
				"route/legal defensive snapshots isolated after every move")
			var before_invalid := _state(map, rng)
			var captions_before_reject := _journal_kinds(first)
			_check(not map.choose_node(chosen) and not map.choose_node("unrecognized"),
				"repeat and unknown route choices rejected on floor %d" % floor_number)
			_check(_state(map, rng) == before_invalid, "rejected move is exactly inert")
			first.refresh()
			_check(_state(map, rng) == before_invalid and _signature(first) == _signature(other),
				"rejection/refresh cannot alter chosen and legal presentation")
			_check(_journal_kinds(first) == captions_before_reject
				and _journal_kinds(first).size() == floor_number,
				"a rejected choice appends no visited-kind caption on floor %d" % floor_number)
		_check(map.is_complete() and map.get_route().size() == 12
			and map.get_legal_choices().is_empty(), "Boss floor 12 complete, no next highlight")
		var end_state := _state(map, rng)
		_check(not map.choose_node(map.get_route().back()) and _state(map, rng) == end_state,
			"completed map rejects replay and leaves RNG intact")
		first.refresh()
		_verify(first, map, rng, "seed %d completed" % seed_value)

		# Pointer/keyboard events are dispatched to the mounted view. It must stay inert.
		var pointer := InputEventMouseButton.new()
		pointer.position = first.position + Vector2(60, 170)
		pointer.button_index = MOUSE_BUTTON_LEFT
		pointer.pressed = true
		Input.parse_input_event(pointer)
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
		_check(_state(map, rng) == end_state and requests.is_empty() and not first.has_focus(),
			"finished map mouse/keyboard is inert and has no node buttons")
		first.bind_map(replay)
		requests.clear()
		if stale.is_valid():
			stale.call()
		_check(requests.is_empty(), "old callback rejects rebind")
		_verify(first, replay, replay_rng, "second map rebound")
		var replay_trace := _signature(other)
		_check(_signature(first) == replay_trace, "new map rebind has only its own node/edge state")
		first.bind_map(null)
		requests.clear()
		if stale.is_valid():
			stale.call()
		_check(requests.is_empty(), "old callback rejects null binding")
		_check(first.get_child_count() == 0 and _state(map, rng) == end_state,
			"null rebind immediately clears children, does not change former map")
		first.refresh()
		_check(first.get_child_count() == 0, "null repeat refresh never resurrects stale graph")
		first.bind_map(map)
		_check(_signature(first) == replay_trace, "rebind after clear restores exact owned graph")
		other.queue_free()
		await process_frame
		first.bind_map(null)

	# Distinct second-map graph replacement before any route is selected.
	var a := RunMap.new()
	var b := RunMap.new()
	var a_rng := _rng(6)
	var b_rng := _rng(42)
	_check(a.generate(a_rng) and b.generate(b_rng), "two distinct seeds exist for rebind")
	first.bind_map(a)
	var a_signature := _signature(first)
	first.bind_map(b)
	_verify(first, b, b_rng, "second seed replaces all original markers/threads")
	var b_signature := _signature(first)
	_check(a.get_floors() != b.get_floors() and a_signature != b_signature,
		"second graph has distinct real kind/edge content, stale first graph absent")
	first.bind_map(a)
	_check(_signature(first) == a_signature, "same first map is restorable without duplicates")
	var old_button := _action(first, a.get_legal_choices()[0])
	_check(old_button != null, "regeneration fixture has mounted legal button")
	var old_callback: Callable = old_button.pressed.get_connections()[0].callable if old_button != null else Callable()
	var prior_generation := a.get_generation_revision()
	var prior_state := _state(a, a_rng)
	requests.clear()
	first._request_node("unknown", a, first._revision)
	first._request_node(a.get_floors()[3][0]["id"], a, first._revision)
	_check(requests.is_empty() and _state(a, a_rng) == prior_state,
		"unknown and nonlegal direct request callbacks reject without RNG use")
	var identical_rng := _rng(6)
	_check(a.generate(identical_rng) and a.get_floors() == prior_state.floors
		and a.get_generation_revision() == prior_generation + 1,
		"same seed regeneration recreates identical atlas data with fresh generation identity")
	var regenerated := _state(a, identical_rng)
	if old_callback.is_valid():
		old_callback.call()
	_check(requests.is_empty() and _state(a, identical_rng) == regenerated,
		"old callback rejects same-seed regeneration even when IDs and route are unchanged")
	first.refresh()
	_verify(first, a, identical_rng, "same-seed regenerated view")
	if old_callback.is_valid():
		old_callback.call()
	_check(requests.is_empty(), "refresh invalidates all prior generation callbacks")
	first.bind_map(b)
	if old_callback.is_valid():
		old_callback.call()
	_check(requests.is_empty(), "rebind rejects retained callback from old map")
	first.bind_map(null)
	if old_callback.is_valid():
		old_callback.call()
	first._request_node("f01_n0", null, first._revision)
	_check(requests.is_empty() and first.get_child_count() == 0,
		"last null rejects stale and null callbacks, clears edges, headers and markers")
	# AC1/AC2: exact next-area/floor captions across a genuine legal route, plus teardown.
	_exercise_status_tab(first)
	# Progressive reveal of newly legal stitches on a real seeded route.
	await _exercise_reveal(6)
	first.queue_free()
	await process_frame
	for kind in EXPECTED_HELP:
		_check(seen_help_kinds.has(kind),
			"real generated legal route exposed consequence guidance for " + kind)
	if failures.is_empty():
		print("run_route_atlas_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_route_atlas_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
