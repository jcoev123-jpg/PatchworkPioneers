extends SceneTree
## Mounted read-only comparison regression: genuine seeded RunMap records are the
## oracle. No test-only graph/route authority, enemy roll, stock or reward fixture.

var failures: Array[String] = []
var checks := 0
var requests: Array[String] = []
const NUMBER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]

## Authored guidance independent of the atlas formatter and helper.
const HELP := {
	"Fight": ["Win: 10–20 gold + 1 scrap", "Choose 1 of 3 cards, or skip"],
	"Elite": ["Win: 25–35 gold + 2 scraps + patch", "Choose 1 of 3 cards, or skip"],
	"Campfire": ["Choose one: heal or leave", "Heal 30% max HP; torn revives at 1 HP first"],
	"SewingCircle": ["Choose one: upgrade or stitch", "Stitch different owners: 3 scraps; or leave"],
	"Unpicker": ["Choose one: remove a card or leave", "Remove: 75 gold initially, +25 each time"],
	"PatchStall": ["Choose one: buy a patch or leave",
		"3 priced power patches; choose a wearer; sewing included"],
	"Peddler": ["Choose one: buy 1 of 3 hero cards or 1 patch",
		"All 4 priced on the stock; one purchase, or leave"],
	"Event": ["2–3 choices when visited", "Outcomes shown on arrival; no guaranteed yield"],
	"Treasure": ["Treasure stop · contents not yet known",
		"No fixed reward is specified by the route"],
	"Boss": ["Final floor-12 fight", "The last stop on this route"],
}
const NO_LEAK := ["f01_n", "5 cards", "2 patches", "enemy roster", "guaranteed treasure"]


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, why: String) -> void:
	checks += 1
	if not condition:
		failures.append(why)


func _requested(id: String) -> void:
	requests.append(id)


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _snapshot(map: RunMap, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"floors": map.get_floors(),
		"route": map.get_route(),
		"legal": map.get_legal_choices(),
		"generation": map.get_generation_revision(),
		"current": map.get_current_node_id(),
		"floor": map.get_current_floor(),
		"complete": map.is_complete(),
		"rng": rng.state,
	}


## Deliberately not derived from atlas._rendered_shortcuts.
func _ordered(map: RunMap) -> Array[String]:
	var result: Array[String] = []
	var legal := map.get_legal_choices()
	for floor_nodes in map.get_floors():
		var nodes: Array = floor_nodes.duplicate()
		nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["position"]) < int(b["position"]))
		for record in nodes:
			if legal.has(str(record["id"])):
				result.append(str(record["id"]))
	return result


func _shown(kind: String) -> String:
	return "Peddler" if kind == "Shop" else ("Campfire" if kind == "Rest" else kind)


func _expected_excerpt(value: String) -> String:
	if value.length() <= 49:
		return value
	return value.substr(0, 38).strip_edges() + "… (hover)"


func _threat(record: Dictionary) -> String:
	if record["type"] != "Fight":
		return ""
	var floor_number := int(record["floor"])
	if floor_number <= 4:
		return "Normals x1.0 HP/ATK; hits 5-9"
	if floor_number <= 8:
		return "Normals x1.25 HP/ATK; hits 6-11"
	if floor_number <= 11:
		return "Normals x1.5 HP/ATK; hits 7-13"
	return ""


func _compare_rows(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		where: String) -> void:
	var initial := _snapshot(map, rng)
	var ordered := _ordered(map)
	_check(ordered.size() >= 1 and ordered.size() <= 4, where + ": legal 1–4 precondition")
	_check(view._rendered_shortcuts == ordered, where + ": exactly the real shortcut order")
	var sheet := view.get_node_or_null("CompareChoices") as Panel
	_check(sheet != null and view.comparison_is_open(),
		where + ": visible comparison on actual mounted atlas")
	if sheet == null:
		return
	var rows: Array[Panel] = []
	for child in sheet.get_children():
		if child is Panel:
			rows.append(child as Panel)
	_check(rows.size() == ordered.size(), where + ": every and only legal branch has a row")
	_check(view.get_node_or_null("JourneyJournal") != null
		and not view.get_node("JourneyJournal").visible, where + ": diary is covered")
	for i in range(mini(rows.size(), ordered.size())):
		var row := rows[i]
		var id := ordered[i]
		var record := map.get_node(id)
		var kind := str(record["type"])
		var shown := _shown(kind)
		_check(HELP.has(shown), where + ": independent stop oracle covers " + shown)
		if not HELP.has(shown):
			continue
		var expected: Array = HELP[shown]
		var lead: String = expected[0]
		var detail: String = expected[1]
		var threat := _threat(record)
		if not threat.is_empty():
			detail += " · " + threat
		var header := "%d · FLOOR %02d · BRANCH %d · %s" % [
			i + 1, int(record["floor"]), int(record["position"]) + 1, shown]
		var identity := row.get_node_or_null("Identity") as Label
		var lead_label := row.get_node_or_null("Lead") as Label
		var detail_label := row.get_node_or_null("Detail") as Label
		_check(identity != null and lead_label != null and detail_label != null,
			where + ": visible identity, lead and detail labels row %d" % i)
		if identity == null or lead_label == null or detail_label == null:
			continue
		_check(row.name == "ComparisonRow%d" % (i + 1)
			and str(row.get_meta("route_id")) == id
			and str(row.get_meta("authored_kind")) == kind,
			where + ": row is genuine authored node " + id)
		_check(identity.text == header, where + ": 1–4/FLOOR/BRANCH/kind match record " + id)
		_check(lead_label.text == _expected_excerpt(lead)
			and detail_label.text == _expected_excerpt(detail),
			where + ": concise help from independent oracle " + id)
		_check(row.tooltip_text.contains(lead) and row.tooltip_text.contains(detail)
			and row.tooltip_text.contains(header)
			and not row.tooltip_text.contains(id),
			where + ": complete tooltip never leaks route ID or loses restrictions " + id)
		_check(row.focus_mode == Control.FOCUS_NONE
			and row.get_node_or_null("Action") == null
			and identity.focus_mode == Control.FOCUS_NONE
			and lead_label.focus_mode == Control.FOCUS_NONE,
			where + ": row is inert, never a new route action")
		for forbidden in NO_LEAK:
			if kind == "Shop" or kind == "Rest" or kind == "Treasure":
				_check(not row.tooltip_text.to_lower().contains(forbidden.to_lower()),
					where + ": no obsolete stock/reward details " + id)
		if kind == "Shop":
			_check(shown == "Peddler" and row.tooltip_text.contains("stock")
				and not identity.text.contains("Shop"),
				where + ": legacy Shop still enters Peddler without price claim")
		if kind == "Rest":
			_check(shown == "Campfire" and not identity.text.contains("Rest"),
				where + ": legacy Rest still enters Campfire")
	_check(rows.is_empty() or rows[0].get_meta("route_id") == ordered.front(),
		where + ": first branch identity")
	_check(rows.is_empty() or rows.back().get_meta("route_id") == ordered.back(),
		where + ": last branch identity")
	_check(view._legal_actions.size() == ordered.size()
		and view._actions_by_id.size() == ordered.size()
		and (view.get_node_or_null("CompareToggle") as Button).focus_mode == Control.FOCUS_NONE,
		where + ": route focus targets unchanged")
	_check(_snapshot(map, rng) == initial, where + ": rendering is fully read-only")


func _key(code: Key, echo: bool = false, shift: bool = false,
		ctrl: bool = false, release_only: bool = false) -> bool:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = not release_only
	key.echo = echo
	key.shift_pressed = shift
	key.ctrl_pressed = ctrl
	root.push_input(key, true)
	var handled := root.is_input_handled()
	await process_frame
	if not release_only:
		var up := InputEventKey.new()
		up.keycode = code
		up.pressed = false
		up.shift_pressed = shift
		up.ctrl_pressed = ctrl
		root.push_input(up, true)
		await process_frame
	return handled


func _mouse(button: Button) -> void:
	var pos := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion, true)
	await process_frame
	for is_down in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = pos
		click.global_position = pos
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_down
		root.push_input(click, true)
		await process_frame


func _readonly(map: RunMap, rng: RandomNumberGenerator, before: Dictionary,
		where: String) -> void:
	_check(requests.is_empty() and _snapshot(map, rng) == before,
		where + ": no request, run mutation, RNG use or route advance")


func _find_seed(count: int, kind: String = "") -> Dictionary:
	for value in range(1, 251):
		var rng := _rng(value)
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		if map.get_legal_choices().size() != count and count > 0:
			continue
		if not kind.is_empty():
			var present := false
			for id in map.get_legal_choices():
				if str(map.get_node(id)["type"]) == kind:
					present = true
					break
			if not present:
				continue
		return {"map": map, "rng": rng}
	return {}


func _exercise(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		close_button: Button, where: String) -> void:
	view.bind_map(map)
	await process_frame
	var initial := _snapshot(map, rng)
	var legal := _ordered(map)
	_check(legal.size() >= 3 and legal.size() <= 4
		and view.get_node_or_null("CompareToggle") != null, where + ": mounted starting controls")
	if legal.is_empty():
		return
	var button := view.get_node_or_null("CompareToggle") as Button
	_check(button != null and button.visible and button.focus_mode == Control.FOCUS_NONE,
		where + ": Compare is discoverable and cannot steal route keyboard focus")
	_check(not view.comparison_is_open() and view.get_node_or_null("CompareChoices") == null,
		where + ": defaults to actual journal")
	requests.clear()
	seed(99913)
	var global_next := randi()
	seed(99913)
	_check(await _key(KEY_C), where + ": physical C opens comparison")
	_compare_rows(view, map, rng, where + ": C opens")
	var hovering := InputEventMouseMotion.new()
	hovering.position = (view.get_node("CompareChoices/ComparisonRow1") as Panel).get_global_rect().get_center()
	root.push_input(hovering, true)
	await process_frame
	_readonly(map, rng, initial, where + ": hover and C open")
	_check(not await _key(KEY_C, true), where + ": echoed C is ignored")
	_check(not await _key(KEY_C, false, true), where + ": Shift+C is ignored")
	_check(not await _key(KEY_C, false, false, true), where + ": Ctrl+C is ignored")
	_check(not await _key(KEY_C, false, false, false, true), where + ": key release ignored")
	_check(view.comparison_is_open(), where + ": bad key variants did not toggle")
	_readonly(map, rng, initial, where + ": bad keys")
	# Route number keys keep their original one-based slot even while comparing.
	for i in range(legal.size()):
		requests.clear()
		_check(await _key(NUMBER_KEYS[i]), where + ": existing numeric key handled")
		_check(requests == [legal[i]], where + ": numeric emits exact current ID once")
		_check(_snapshot(map, rng) == initial, where + ": numeric does not commit")
	requests.clear()
	close_button.grab_focus()
	await _key(KEY_DOWN)
	_check(root.gui_get_focus_owner() == view._legal_actions[0],
		where + ": Close map Down enters first legal action while comparing")
	close_button.grab_focus()
	await _key(KEY_UP)
	_check(root.gui_get_focus_owner() == view._legal_actions.back(),
		where + ": Close map Up enters last legal action while comparing")
	_readonly(map, rng, initial, where + ": Close map focus circuit")
	# Enter and Space still act on genuine right-page markers.
	var marker := view.get_node("Node_" + legal[0]) as PanelContainer
	var action := marker.get_node("Action") as Button
	action.grab_focus()
	await _key(KEY_ENTER)
	_check(requests == [legal[0]], where + ": focused Enter exact legal ID")
	requests.clear()
	await _key(KEY_SPACE)
	_check(requests == [legal[0]], where + ": focused Space exact legal ID")
	requests.clear()
	await _key(KEY_DOWN)
	_check(view._legal_actions.has(root.gui_get_focus_owner())
		and root.gui_get_focus_owner() != button, where + ": Down still traverses legal buttons")
	await _key(KEY_TAB)
	_check(view._legal_actions.has(root.gui_get_focus_owner())
		and root.gui_get_focus_owner() != button, where + ": Tab never enters Compare")
	_readonly(map, rng, initial, where + ": focus navigation")
	_compare_rows(view, map, rng, where + ": while focusing")
	_check(await _key(KEY_ESCAPE) and not view.comparison_is_open()
		and view.get_node_or_null("CompareChoices") == null
		and view.get_node("JourneyJournal").visible,
		where + ": Escape closes and restores actual diary")
	_readonly(map, rng, initial, where + ": Escape")
	# Mouse button is a separate UI toggle, not a shortcut or route action.
	await _mouse(button)
	_compare_rows(view, map, rng, where + ": mouse opens")
	await _mouse(button)
	_check(not view.comparison_is_open() and view.get_node_or_null("CompareChoices") == null,
		where + ": mouse Back retires old rows")
	_readonly(map, rng, initial, where + ": mouse and hover")
	for times in range(3):
		await _key(KEY_C)
		_check(view.comparison_is_open(), where + ": repeat open %d" % times)
		await _key(KEY_C)
		_check(not view.comparison_is_open() and view.get_node_or_null("CompareChoices") == null,
			where + ": repeat close %d" % times)
	_readonly(map, rng, initial, where + ": repeat toggles")
	_check(randi() == global_next, where + ": no global RNG drawn by UI")
	# Hidden map must reject C, an old callback and any shortcut.
	await _key(KEY_C)
	var old_button_callback: Callable = button.pressed.get_connections()[0].callable
	view.hide()
	await process_frame
	_check(view.get_node_or_null("CompareChoices") == null
		and not view.comparison_is_open(), where + ": hide retires comparison synchronously")
	requests.clear()
	_check(not await _key(KEY_C) and not await _key(KEY_1), where + ": hidden keys ignored")
	old_button_callback.call()
	_readonly(map, rng, initial, where + ": hidden callbacks")
	view.show()
	await process_frame
	close_button.grab_focus()
	_check(await _key(KEY_C), where + ": visible current atlas can reopen")
	_compare_rows(view, map, rng, where + ": reopened after hide")
	# External progress invalidates the still-mounted generation before refresh.
	_check(map.choose_node(legal[0]), where + ": external genuine legal route move")
	var moved := _snapshot(map, rng)
	await process_frame
	_check(view.get_node_or_null("CompareChoices") == null
		and not view.comparison_is_open(), where + ": externally advanced sheet retired")
	requests.clear()
	_check(not await _key(KEY_C) and not await _key(KEY_1),
		where + ": stale map rejects shortcuts and Compare")
	old_button_callback.call()
	_readonly(map, rng, moved, where + ": stale old button callback")
	view.refresh()
	await process_frame
	_check(view.get_node_or_null("CompareChoices") == null,
		where + ": refresh did not keep obsolete sheet")
	await _key(KEY_C)
	_compare_rows(view, map, rng, where + ": advanced legal choices repopulate")
	old_button_callback.call()
	_check(view.comparison_is_open(), where + ": retired button cannot close new sheet")
	_readonly(map, rng, moved, where + ": advanced comparison")
	# Replacing the RunMap object, even with overlapping IDs, retires both the
	# old paper and its mouse callback. A replacement's own new rows stay live.
	var replacement := RunMap.new()
	var replacement_rng := _rng(113)
	_check(replacement.generate(replacement_rng), where + ": replacement real map generated")
	var old_map_button: Callable = (view.get_node("CompareToggle") as Button).pressed.get_connections()[0].callable
	view.bind_map(replacement)
	_check(view.get_node_or_null("CompareChoices") == null,
		where + ": binding a different map retires the old sheet")
	var replacement_before := _snapshot(replacement, replacement_rng)
	await _key(KEY_C)
	_compare_rows(view, replacement, replacement_rng, where + ": new map legal rows")
	requests.clear()
	old_map_button.call()
	_check(view.comparison_is_open(), where + ": previous map callback cannot close replacement sheet")
	_readonly(replacement, replacement_rng, replacement_before, where + ": replacing map")
	view.bind_map(map)
	_check(view.get_node_or_null("CompareChoices") == null
		and not view.comparison_is_open(), where + ": restored old map requires a new sheet")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var view := RunRouteAtlas.new()
	view.position = Vector2(20, 40)
	root.add_child(view)
	view.node_requested.connect(_requested)
	var close_button := Button.new()
	close_button.text = "Close map"
	close_button.position = Vector2(520, 640)
	close_button.size = Vector2(240, 48)
	root.add_child(close_button)
	await process_frame
	var empty := RunMap.new()
	view.bind_map(empty)
	_check(view.get_node_or_null("CompareToggle") == null
		and view.get_node_or_null("CompareChoices") == null,
		"un-generated atlas has no Compare or rows")
	_check(not await _key(KEY_C), "un-generated atlas ignores C")
	view.bind_map(null)
	_check(not await _key(KEY_C), "unbound atlas ignores C")
	for count in [3, 4]:
		var fixture := _find_seed(count)
		_check(not fixture.is_empty(), "bounded seed search finds %d legal openings" % count)
		if fixture.is_empty():
			continue
		var map: RunMap = fixture["map"]
		var rng: RandomNumberGenerator = fixture["rng"]
		await _exercise(view, map, rng, close_button, "%d-branch seeded map" % count)
		# Same seed regenerated TWICE: a node ID alone cannot validate an old sheet.
		var graph_before := map.get_floors()
		var first_id := str(map.get_floors()[0][0]["id"])
		var old_click: Callable = (view.get_node("CompareToggle") as Button).pressed.get_connections()[0].callable
		var old_generation := map.get_generation_revision()
		for regeneration in range(2):
			var same_rng := _rng(int(rng.seed))
			_check(map.generate(same_rng)
				and map.get_generation_revision() == old_generation + regeneration + 1
				and map.get_floors() == graph_before,
				"same-seed generation increments revision, graph stays authentic")
			var before_refresh := _snapshot(map, same_rng)
			await process_frame
			requests.clear()
			_check(not await _key(KEY_C) and not await _key(KEY_1),
				"same-seed stale snapshot blocks C and numeric shortcut")
			old_click.call()
			_readonly(map, same_rng, before_refresh, "old Compare callback after regeneration")
			view.refresh()
			await _key(KEY_C)
			_compare_rows(view, map, same_rng, "same-seed refreshed generation %d" % regeneration)
			await _key(KEY_ESCAPE)
		_check(_ordered(map).has(first_id), "regeneration keeps original opening node legal")
		# Complete the real twelve-floor route and verify the terminal sheet is absent.
		for floor_number in range(1, 13):
			var next := _ordered(map)
			_check(not next.is_empty(), "authentic next legal floor %d" % floor_number)
			if next.is_empty():
				break
			_check(map.choose_node(next[0]), "route commits genuine floor %d" % floor_number)
			view.refresh()
		_check(map.is_complete() and map.get_route().size() == 12
			and view.get_node_or_null("CompareToggle") == null
			and view.get_node_or_null("CompareChoices") == null,
			"Boss completion has no Compare, actions or stale rows")
		requests.clear()
		_check(not await _key(KEY_C) and not await _key(KEY_1),
			"completed floor 12 cannot compare or select another route")
		_check(requests.is_empty(), "Boss completion emits no request")
		view.bind_map(null)
		_check(view.get_child_count() == 0, "null binding fully clears view")
	# Both legacy aliases are exercised on genuinely seeded actionable patches.
	for legacy_kind in ["Shop", "Rest"]:
		var fixture := _find_seed(0, legacy_kind)
		_check(not fixture.is_empty(), "genuine opening legacy " + legacy_kind)
		if fixture.is_empty():
			continue
		var map: RunMap = fixture["map"]
		var rng: RandomNumberGenerator = fixture["rng"]
		view.bind_map(map)
		await _key(KEY_C)
		_compare_rows(view, map, rng, "seeded " + legacy_kind + " projection")
		var found_alias := false
		for id in _ordered(map):
			if str(map.get_node(id)["type"]) == legacy_kind:
				found_alias = true
				var row := view.get_node("CompareChoices/ComparisonRow%d" %
					(_ordered(map).find(id) + 1)) as Panel
				_check(row.get_node("Identity").text.contains(_shown(legacy_kind))
					and str(row.get_meta("authored_kind")) == legacy_kind,
					"authored " + legacy_kind + " projected without altering kind")
		_check(found_alias, "mounted legal " + legacy_kind + " was actually checked")
		view.bind_map(null)
	view.queue_free()
	close_button.queue_free()
	await process_frame
	if failures.is_empty():
		print("run_route_atlas_comparison_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_route_atlas_comparison_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
