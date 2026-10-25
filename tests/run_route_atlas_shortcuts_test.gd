extends SceneTree

var failures: Array[String] = []
var checks := 0
var requests: Array[String] = []
## Real mounted states where the numeric shortcut N is NOT the branch row + 1, so the
## legal hover cannot be derived from the branch number. At least one must be checked.
var shifted_branch_states := 0
var distinct_kind_switches := 0
const NUMBER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _on_requested(id: String) -> void:
	requests.append(id)


func _rng(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	return rng


func _state(map: RunMap, rng: RandomNumberGenerator) -> Dictionary:
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


func _ordered_legal(map: RunMap) -> Array[String]:
	var result: Array[String] = []
	var legal := map.get_legal_choices()
	for floor_nodes in map.get_floors():
		var by_position: Array = floor_nodes.duplicate()
		by_position.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["position"]) < int(b["position"]))
		for node in by_position:
			var id: String = node["id"]
			if legal.has(id):
				result.append(id)
	return result


func _action(view: RunRouteAtlas, id: String) -> Button:
	var marker := _marker(view, id)
	return marker.get_node_or_null("Action") as Button if marker != null else null


func _focused_id(view: RunRouteAtlas) -> String:
	var owner := root.gui_get_focus_owner()
	if owner != null and view._legal_actions.has(owner):
		return str(owner.get_meta("route_id"))
	return ""


func _marker(view: RunRouteAtlas, id: String) -> PanelContainer:
	for child in view.get_children():
		if child is PanelContainer and child.get_meta("route_id") == id:
			return child as PanelContainer
	return null


## Independent player-facing wording for one real node record: authored floor, authored
## kind and the one-based branch row. Spelled out here so the mounted shortcuts regression
## cannot inherit a wording mistake from the view itself.
## Independent authored stop guidance oracle; does not call the atlas presentation helper.
const EXPECTED_HELP := {
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


func _verify_labels(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		where: String) -> Array[String]:
	var before := _state(map, rng)
	var ordered := _ordered_legal(map)
	var current_floor := map.get_current_floor()
	var window: Array[int] = []
	if not map.is_complete():
		for f in range(current_floor + 1, mini(current_floor + 3, 12) + 1):
			window.append(f)
	var expected: Dictionary = {}
	for f in window:
		for node in map.get_floors()[f - 1]:
			expected[node["id"]] = node
	if not map.get_current_node_id().is_empty():
		expected[map.get_current_node_id()] = map.get_node(map.get_current_node_id())
	_check(view.is_inside_tree() and view.is_visible_in_tree()
		and view.size == Vector2(1240, 600)
		and view.position + view.size <= Vector2(1280, 720),
		where + ": mounted route fits 1280x720")
	_check(ordered.size() <= 4 and ordered == view._rendered_shortcuts
		and ordered.size() == map.get_legal_choices().size(),
		where + ": shortcuts exactly match legal authored-position ordering")
	var button_count := 0
	var marker_count := 0
	for child in view.get_children():
		if not (child is PanelContainer):
			continue
		var marker := child as PanelContainer
		marker_count += 1
		var id: String = marker.get_meta("route_id")
		_check(expected.has(id), where + ": no off-window clickable or hidden node " + id)
		if not expected.has(id):
			continue
		var identity := marker.get_node("Identity") as Label
		var action := marker.get_node_or_null("Action") as Button
		var index := ordered.find(id)
		var expected_caption := (str(index + 1) + " " if index >= 0 else "") + String(expected[id]["type"])
		_check(identity.text == expected_caption and not identity.text.contains(id)
			and identity.get_combined_minimum_size().x <= marker.size.x
			and identity.get_combined_minimum_size().y <= marker.size.y,
			where + ": next-floor number and kind fit round patch " + id)
		_check(marker.get_meta("route_state") == ("legal" if index >= 0 else
			("chosen" if map.get_route().has(id) else "other")),
			where + ": exact actual legal/chosen/inactive state " + id)
		var hover := _hover_text(expected[id], index >= 0)
		_check(marker.tooltip_text == hover and not marker.tooltip_text.contains(id),
			where + ": sewn floor, kind and branch hover on the real patch " + id)
		if index >= 0:
			button_count += 1
			_check(action is RunRouteAtlas.LegalPatchAction
				and action.has_theme_stylebox_override("focus")
				and action.get_theme_stylebox("focus") is StyleBoxEmpty,
				where + ": round patch owns the stitched inset focus treatment " + id)
			_check(action != null and action.focus_mode == Control.FOCUS_ALL
				and action.is_visible_in_tree() and not action.disabled
				and action.tooltip_text == "Choose " + hover + " (key %d)" % (index + 1)
				and not action.tooltip_text.contains(id)
				and action.get_meta("route_id") == id,
				where + ": legal Choose hover names its real shortcut " + id)
			if index != int(expected[id]["position"]):
				shifted_branch_states += 1
		else:
			_check(action == null and identity.text == String(expected[id]["type"]),
				where + ": future and current patches cannot request a choice " + id)
	_check(view._legal_actions.size() == ordered.size()
		and view._actions_by_id.size() == ordered.size(),
		where + ": mounted focus chain has precisely legal choices")
	for i in range(ordered.size()):
		var action := _action(view, ordered[i])
		var next := _action(view, ordered[(i + 1) % ordered.size()])
		var previous := _action(view, ordered[(i - 1 + ordered.size()) % ordered.size()])
		_check(action != null and next != null and previous != null
			and action.get_node_or_null(action.focus_next) == next
			and action.get_node_or_null(action.focus_previous) == previous,
			where + ": authored focus links exclude all inert patches at index %d" % i)
	_check(view.choice_ticket() != null or ordered.is_empty(),
		where + ": legal choices display an initial inert consequence ticket")
	if not ordered.is_empty():
		_assert_ticket(view, map, ordered[0] if view.choice_ticket().route_id == ordered[0] else view.choice_ticket().route_id,
			where + ": initial ticket")
	_check(button_count == ordered.size() and marker_count == expected.size(),
		where + ": all and only N legal Action buttons, with no off-window node")
	_check(_state(map, rng) == before,
		where + ": display leaves complete seed graph, route and RNG unchanged")
	return ordered


# Deliver physical SceneTree events instead of invoking RunRouteAtlas._input directly.
# Return the press event's handled flag, before a release clears it.
func _key(code: Key, echo: bool = false, shifted: bool = false) -> bool:
	var down := InputEventKey.new()
	down.keycode = code
	down.pressed = true
	down.echo = echo
	down.shift_pressed = shifted
	root.push_input(down, true)
	var handled := root.is_input_handled()
	await process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	up.shift_pressed = shifted
	root.push_input(up, true)
	await process_frame
	return handled


func _assert_key(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		code: Key, expected: String, where: String, echo: bool = false) -> void:
	_check(view.is_inside_tree(), where + ": tested view is mounted")
	var before := _state(map, rng)
	requests.clear()
	seed(77113)
	var global_next := randi()
	seed(77113)
	var handled := await _key(code, echo)
	_check(requests == ([expected] if not expected.is_empty() else []),
		where + ": exactly the expected node_requested signal, never duplicate")
	_check(handled == not expected.is_empty(),
		where + ": only admitted shortcuts claim keyboard input")
	_check(_state(map, rng) == before, where + ": key never chooses route or draws from model RNG")
	_check(randi() == global_next, where + ": key never draws from global RNG")


func _mouse_press(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _assert_ticket(view: RunRouteAtlas, map: RunMap, id: String, where: String) -> void:
	var ticket := view.choice_ticket()
	_check(ticket != null and map.get_legal_choices().has(id),
		where + ": exact live legal choice has an inert ticket")
	if ticket == null or not map.get_legal_choices().has(id):
		return
	var record := map.get_node(id)
	var kind := str(record["type"])
	var facts: Dictionary = EXPECTED_HELP.get(kind, {})
	_check(not facts.is_empty(), where + ": legal kind is authored")
	if facts.is_empty():
		return
	_check(ticket.route_id == id
		and ticket.header_text == "%s · FLOOR %02d · BRANCH %d" % [
			RunRouteAtlas.area_for_floor(int(record["floor"])).to_upper(),
			int(record["floor"]), int(record["position"]) + 1]
		and ticket.lead_text == kind + " · " + str(facts["lead"])
		and ticket.detail_text == str(facts["detail"])
		and not ticket.header_text.contains(id) and not ticket.lead_text.contains(id)
		and ticket.visible and ticket.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and ticket.focus_mode == Control.FOCUS_NONE
		and RunRouteAtlas.ChoiceTicket.FONT_SIZE >= 18,
		where + ": exact real choice area, branch and truthful consequence with no raw ID")


## Actual mouse motion selects a different legal kind without any map transaction.
## When the pointer departs, the still-focused action regains the ticket.
func _assert_pointer_switch(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		ordered: Array[String], where: String) -> void:
	var source := ""
	var target := ""
	for first in ordered:
		for second in ordered:
			if first != second and map.get_node(first)["type"] != map.get_node(second)["type"]:
				source = first
				target = second
				break
		if not target.is_empty():
			break
	if target.is_empty():
		return
	distinct_kind_switches += 1
	var before := _state(map, rng)
	seed(98231)
	var next_global := randi()
	seed(98231)
	requests.clear()
	var focus_button := _action(view, source)
	var hover_button := _action(view, target)
	_check(focus_button != null and hover_button != null,
		where + ": two distinct legal kinds really mounted")
	if focus_button == null or hover_button == null:
		return
	focus_button.grab_focus()
	_assert_ticket(view, map, source, where + ": focused initial kind")
	var motion := InputEventMouseMotion.new()
	motion.position = hover_button.get_global_rect().get_center()
	root.push_input(motion, true)
	await process_frame
	_assert_ticket(view, map, target, where + ": pointer takes precedence over focus")
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(10.0, 690.0)
	root.push_input(motion, true)
	await process_frame
	_assert_ticket(view, map, source, where + ": pointer exit restores focused explanation")
	_action(view, target).grab_focus()
	_assert_ticket(view, map, target, where + ": new focus updates kind")
	_check(requests.is_empty() and _state(map, rng) == before and randi() == next_global,
		where + ": pointer and focus guidance consume no route or local/global RNG")


func _assert_navigation(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		ordered: Array[String], unrelated: Button, close: Button, where: String) -> void:
	_check(ordered.size() >= 2, where + ": real multi-patch navigation precondition")
	if ordered.size() < 2:
		return
	var before := _state(map, rng)
	requests.clear()
	seed(171903)
	var next_global := randi()
	seed(171903)
	unrelated.grab_focus()
	_check(unrelated.has_focus(), where + ": unrelated focus precondition")
	await _key(KEY_DOWN)
	_check(unrelated.has_focus() and requests.is_empty(),
		where + ": arrow cannot steal unrelated app focus")
	close.grab_focus()
	_check(close.has_focus() and close.get_parent() == view.get_parent(),
		where + ": sibling Close map owns entry focus")
	await _key(KEY_UP)
	_check(_focused_id(view) == ordered[ordered.size() - 1],
		where + ": Up from Close map enters at last legal patch")
	close.grab_focus()
	await _key(KEY_DOWN)
	_check(_focused_id(view) == ordered[0],
		where + ": Down from Close map enters at first legal patch")
	_check(requests.is_empty(), where + ": entering from Close never requests a route")
	var first := _action(view, ordered[0])
	_check(first != null and first.is_visible_in_tree(),
		where + ": first legal Action is mounted")
	if first == null:
		return
	first.grab_focus()
	_check(_focused_id(view) == ordered[0], where + ": first patch genuinely has keyboard focus")
	_assert_ticket(view, map, ordered[0], where + ": keyboard ticket")
	for i in range(ordered.size()):
		await _key(KEY_DOWN)
		_check(_focused_id(view) == ordered[(i + 1) % ordered.size()],
			where + ": Down follows authored order, wrapping after the last patch %d" % i)
		_assert_ticket(view, map, ordered[(i + 1) % ordered.size()],
			where + ": Down ticket")
		_check(requests.is_empty(), where + ": Down never emits a request")
	await _key(KEY_UP)
	_check(_focused_id(view) == ordered[ordered.size() - 1],
		where + ": Up wraps backward from the first patch")
	await _key(KEY_TAB)
	_check(_focused_id(view) == ordered[0], where + ": real Tab wraps to first legal patch")
	await _key(KEY_TAB, false, true)
	_check(_focused_id(view) == ordered[ordered.size() - 1],
		where + ": real Shift+Tab wraps to last legal patch")
	for i in range(ordered.size() - 1, 0, -1):
		await _key(KEY_TAB, false, true)
		_check(_focused_id(view) == ordered[i - 1],
			where + ": reverse Tab follows only legal controls %d" % i)
	_check(requests.is_empty(), where + ": Tab and reverse Tab only change focus")
	await _key(KEY_ENTER)
	_check(requests == [ordered[0]], where + ": Enter presses exact focused original ID once")
	requests.clear()
	var second := _action(view, ordered[1])
	second.grab_focus()
	await _key(KEY_SPACE)
	_check(requests == [ordered[1]], where + ": Space presses exact focused original ID once")
	requests.clear()
	await _mouse_press(_action(view, ordered[0]))
	_check(requests == [ordered[0]], where + ": pointer click still presses the legal patch once")
	_check(_state(map, rng) == before,
		where + ": all focus, keyboard and pointer paths preserve route and seeded RNG")
	_check(randi() == next_global, where + ": focus and activation never draw global RNG")


func _assert_held_key(map: RunMap, rng: RandomNumberGenerator, id: String) -> void:
	var before := _state(map, rng)
	requests.clear()
	var down := InputEventKey.new()
	down.keycode = KEY_1
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	for repeat in range(3):
		var echo := InputEventKey.new()
		echo.keycode = KEY_1
		echo.pressed = true
		echo.echo = true
		root.push_input(echo, true)
		await process_frame
	var up := InputEventKey.new()
	up.keycode = KEY_1
	up.pressed = false
	root.push_input(up, true)
	await process_frame
	_check(requests == [id], "one held numeric key emits once despite three repeat events")
	_check(_state(map, rng) == before, "held key and repeats leave full run state intact")


## Focus motion cannot submit a route; activation goes through Button.pressed.
func _assert_focus_key(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		code: Key, expected_id: String, where: String, shifted: bool = false) -> void:
	var before := _state(map, rng)
	requests.clear()
	seed(448819)
	var next_global := randi()
	seed(448819)
	await _key(code, false, shifted)
	_check(_focused_id(view) == expected_id,
		where + ": focus follows real authored legal Action, expected " + expected_id)
	_assert_ticket(view, map, expected_id, where + ": focus explanation")
	_check(requests.is_empty(), where + ": motion never emits node_requested")
	_check(_state(map, rng) == before, where + ": motion never commits map or draws run RNG")
	_check(randi() == next_global, where + ": motion never draws global RNG")


func _assert_activate_focus(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		code: Key, expected_id: String, where: String) -> void:
	_check(_focused_id(view) == expected_id and _action(view, expected_id) != null,
		where + ": key starts from a genuine focused legal Button")
	var before := _state(map, rng)
	requests.clear()
	seed(448819)
	var next_global := randi()
	seed(448819)
	await _key(code)
	_check(requests == [expected_id],
		where + ": Enter/Space presses exactly the focused original ID once")
	_check(_state(map, rng) == before, where + ": activation is only a request")
	_check(randi() == next_global, where + ": activation does not draw global RNG")


func _assert_mouse_action(view: RunRouteAtlas, map: RunMap, rng: RandomNumberGenerator,
		id: String, where: String) -> void:
	var action := _action(view, id)
	_check(action != null and action.is_visible_in_tree(),
		where + ": pointer targets a mounted legal Action")
	if action == null:
		return
	var before := _state(map, rng)
	requests.clear()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = action.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	_check(requests == [id], where + ": mouse click presses original legal node once")
	_check(_state(map, rng) == before, where + ": mouse request is presentation-only")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var view := RunRouteAtlas.new()
	view.position = Vector2(20, 40)
	root.add_child(view)
	view.node_requested.connect(_on_requested)
	var other_focus := Button.new()
	other_focus.text = "Unrelated focus"
	other_focus.position = Vector2(0, 0)
	root.add_child(other_focus)
	# Match the live optional overlay: Close map initially owns focus, with
	# its own Tab loop. Arrow entry works without editing app.gd.
	var close_focus := Button.new()
	close_focus.text = "Close map"
	close_focus.position = Vector2(520, 640)
	close_focus.size = Vector2(240, 48)
	close_focus.focus_next = NodePath(".")
	close_focus.focus_previous = NodePath(".")
	root.add_child(close_focus)
	await process_frame
	other_focus.grab_focus()
	_check(other_focus.has_focus() and not view.has_focus(),
		"initial numeric request works with focus on non-atlas Control")

	var ungenerated := RunMap.new()
	view.bind_map(ungenerated)
	_check(view.get_child_count() == 0, "ungenerated map has no markers")
	await _assert_key(view, ungenerated, _rng(1), KEY_1, "", "ungenerated key")
	view.bind_map(null)
	await _assert_key(view, ungenerated, _rng(1), KEY_1, "", "null map key")

	var saw_narrow := false
	for seed_value in [6, 42]:
		var rng := _rng(seed_value)
		var map := RunMap.new()
		_check(map.generate(rng), "real seeded map generated %d" % seed_value)
		view.bind_map(map)
		var first_legal := _verify_labels(view, map, rng, "seed %d opening" % seed_value)
		_check(first_legal.size() >= 3, "opening has three or four real choices")
		_check(_focused_id(view).is_empty(), "atlas bind does not steal unrelated focus")
		close_focus.grab_focus()
		_check(close_focus.has_focus(), "overlay Close map owns initial keyboard focus")
		await _assert_focus_key(view, map, rng, KEY_DOWN, first_legal[0],
			"Close map Down enters first legal patch")
		for i in range(1, first_legal.size()):
			await _assert_focus_key(view, map, rng, KEY_DOWN, first_legal[i],
				"Down authored legal order index %d" % i)
		await _assert_focus_key(view, map, rng, KEY_DOWN, first_legal[0],
			"Down wraps only legal patches")
		await _assert_focus_key(view, map, rng, KEY_UP, first_legal.back(),
			"Up reverse wraps only legal patches")
		for i in range(first_legal.size() - 2, -1, -1):
			await _assert_focus_key(view, map, rng, KEY_UP, first_legal[i],
				"Up reverse authored legal order index %d" % i)
		await _assert_focus_key(view, map, rng, KEY_TAB, first_legal[1],
			"Tab advances through legal buttons")
		await _assert_activate_focus(view, map, rng, KEY_ENTER, first_legal[1],
			"Enter focused nonfirst legal")
		await _assert_focus_key(view, map, rng, KEY_TAB, first_legal[2],
			"Tab reaches later legal Action")
		await _assert_activate_focus(view, map, rng, KEY_SPACE, first_legal[2],
			"Space focused later legal")
		await _assert_focus_key(view, map, rng, KEY_TAB, first_legal[(2 + 1) % first_legal.size()],
			"Tab continues in legal order")
		await _assert_focus_key(view, map, rng, KEY_TAB, first_legal[(2 + 2) % first_legal.size()],
			"Tab loops among legal patches")
		await _assert_focus_key(view, map, rng, KEY_TAB, first_legal[(2 + 1) % first_legal.size()],
			"Shift+Tab walks backwards", true)
		await _assert_mouse_action(view, map, rng, first_legal.back(),
			"mouse still clicks a legal round patch")
		_action(view, first_legal.back()).grab_focus()
		view.refresh()
		_assert_ticket(view, map, first_legal.back(), "same-map focus ticket survives refresh")
		_check(_focused_id(view) == first_legal.back(),
			"same-map refresh restores legal focus by original ID, not old Button reference")
		for i in range(first_legal.size()):
			await _assert_key(view, map, rng, NUMBER_KEYS[i], first_legal[i],
				"seed %d initial shortcut %d" % [seed_value, i + 1])
		if not first_legal.is_empty():
			await _assert_held_key(map, rng, first_legal[0])
		await _assert_navigation(view, map, rng, first_legal, other_focus, close_focus,
			"seed %d mounted opening" % seed_value)
		await _assert_pointer_switch(view, map, rng, first_legal,
			"seed %d pointer opening" % seed_value)
		await _assert_key(view, map, rng, KEY_5, "", "unassigned key 5")
		await _assert_key(view, map, rng, KEY_1, "", "auto-repeat suppressed", true)
		if first_legal.size() < 4:
			saw_narrow = true
			await _assert_key(view, map, rng, KEY_4, "", "opening number 4 absent")

		var first_action := (_marker(view, first_legal[0]).get_node_or_null("Action") as Button) if not first_legal.is_empty() else null
		_check(first_action != null, "callback fixture is a real opening button")
		var stale: Callable = first_action.pressed.get_connections()[0].callable if first_action != null else Callable()
		var stale_hover: Callable = first_action.mouse_entered.get_connections()[0].callable if first_action != null else Callable()
		var stale_focus: Callable = first_action.focus_entered.get_connections()[1].callable if first_action != null else Callable()
		view.hide()
		await process_frame
		_check(_focused_id(view).is_empty(),
			"hidden atlas releases old legal focus")
		requests.clear()
		await _key(KEY_ENTER)
		_check(requests.is_empty(), "Enter cannot activate a hidden route atlas")
		await _assert_key(view, map, rng, KEY_1, "", "hidden mounted atlas")
		view.show()
		await process_frame
		await _assert_key(view, map, rng, KEY_1, first_legal[0], "reshown valid atlas")

		# An external legal move makes the displayed shortcut list stale.
		var previous := _state(map, rng)
		_check(map.choose_node(first_legal[0]), "external legal route move succeeds")
		var advanced := _state(map, rng)
		_check(advanced["route"].size() == previous["route"].size() + 1
			and advanced["rng"] == previous["rng"],
			"external move only advances authoritative route")
		await _assert_key(view, map, rng, KEY_1, "", "stale external route")
		requests.clear()
		if stale.is_valid():
			stale.call()
		_check(requests.is_empty() and _state(map, rng) == advanced,
			"retained marker callback rejects external move")

		view.refresh()
		var current_ticket := view.choice_ticket()
		var current_ticket_id := current_ticket.route_id if current_ticket != null else ""
		if stale_hover.is_valid():
			stale_hover.call()
		if stale_focus.is_valid():
			stale_focus.call()
		_check(view.choice_ticket() != null and view.choice_ticket().route_id == current_ticket_id,
			"old hover and focus callbacks cannot rewrite advanced-map advice")
		_check(_focused_id(view).is_empty() or _ordered_legal(map).has(_focused_id(view)),
			"route refresh never preserves a newly nonlegal focused node")
		var fresh := _verify_labels(view, map, rng, "seed %d advanced" % seed_value)
		await _assert_pointer_switch(view, map, rng, fresh,
			"seed %d pointer connected" % seed_value)
		_check(not fresh.is_empty(), "new floor exposes real outgoing destinations")
		if fresh.size() < 4:
			saw_narrow = true
			await _assert_key(view, map, rng, KEY_4, "", "connected narrow floor has no fourth shortcut")
		for i in range(fresh.size()):
			await _assert_key(view, map, rng, NUMBER_KEYS[i], fresh[i],
				"seed %d connected shortcut %d" % [seed_value, i + 1])

		# Same map and seed can recreate identical labels but MUST invalidate requests.
		var old_marker := _marker(view, fresh[0])
		var old_action := old_marker.get_node_or_null("Action") as Button if old_marker != null else null
		var old_cb: Callable = old_action.pressed.get_connections()[0].callable if old_action != null else Callable()
		var old_revision := map.get_generation_revision()
		var identical_rng := _rng(seed_value)
		_check(map.generate(identical_rng) and map.get_generation_revision() == old_revision + 1,
			"identical seed regenerates with distinct generation revision")
		var regenerated := _state(map, identical_rng)
		_check(regenerated["floors"] == previous["floors"], "same-seed graph replay is identical")
		await _assert_key(view, map, identical_rng, KEY_1, "", "unrefreshed regenerated atlas")
		if old_action != null:
			old_action.grab_focus()
			requests.clear()
			await _key(KEY_SPACE)
			_check(requests.is_empty(), "regenerated map rejects stale focused Button Space")
		requests.clear()
		if old_cb.is_valid():
			old_cb.call()
		_check(requests.is_empty() and _state(map, identical_rng) == regenerated,
			"stale button callback rejected across same-seed regeneration")
		view.refresh()
		current_ticket = view.choice_ticket()
		current_ticket_id = current_ticket.route_id if current_ticket != null else ""
		if stale_hover.is_valid():
			stale_hover.call()
		if stale_focus.is_valid():
			stale_focus.call()
		_check(view.choice_ticket() != null and view.choice_ticket().route_id == current_ticket_id,
			"old callbacks cannot rewrite regenerated-map advice")
		_check(_focused_id(view).is_empty() or _ordered_legal(map).has(_focused_id(view)),
			"regeneration restores only live legal focus")
		var replay_legal := _verify_labels(view, map, identical_rng, "seed %d regenerated" % seed_value)
		await _assert_key(view, map, identical_rng, KEY_1, replay_legal[0],
			"refreshed same-seed map accepts new callback")
		requests.clear()
		if old_cb.is_valid():
			old_cb.call()
		_check(requests.is_empty(), "refresh invalidates retained old generation callback")

		# Follow a real route through the boss; no number keys remain at completion.
		for floor_number in range(1, 13):
			var legal := _ordered_legal(map)
			_check(not legal.is_empty(), "floor %d has reachable next node" % floor_number)
			if legal.is_empty():
				break
			var before_step := _state(map, identical_rng)
			_check(map.choose_node(legal[0]), "floor %d chooses only a legal model node" % floor_number)
			_check(identical_rng.state == before_step["rng"], "route advancement does not draw RNG")
			view.refresh()
			var now := _verify_labels(view, map, identical_rng,
				"seed %d after floor %d" % [seed_value, floor_number])
			if floor_number < 12:
				_check(not now.is_empty(), "upcoming floor has live shortcuts")
				if now.size() < 4:
					saw_narrow = true
					await _assert_key(view, map, identical_rng, KEY_4, "",
						"floor %d absent shortcut 4" % floor_number)
				await _assert_key(view, map, identical_rng, KEY_1, now[0],
					"floor %d newly refreshed shortcut" % floor_number)
			else:
				_check(map.is_complete() and now.is_empty(), "boss completion has zero legal shortcuts")
				_check(view.choice_ticket() == null and view.get_node_or_null("ChoiceTicket") == null,
					"completed boss removes inert choice ticket")
				_check(view._legal_actions.is_empty() and view._actions_by_id.is_empty()
					and _focused_id(view).is_empty(),
					"completed map has no focusable or actionable marker")
				await _assert_key(view, map, identical_rng, KEY_1, "", "completed atlas ignores 1")
				await _assert_key(view, map, identical_rng, KEY_4, "", "completed atlas ignores 4")

		var finished := _state(map, identical_rng)
		view.bind_map(null)
		_check(view.choice_ticket() == null and view.get_node_or_null("ChoiceTicket") == null,
			"null binding removes read-only ticket")
		await _assert_key(view, map, identical_rng, KEY_1, "", "null after completion")
		_check(_state(map, identical_rng) == finished, "null binding leaves former map unchanged")

	_check(saw_narrow, "at least one real connected state offers fewer than four destinations")
	_check(distinct_kind_switches > 0, "real mouse/focus switches across distinct legal authored kinds")
	_check(shifted_branch_states >= 1,
		"real legal hover was checked where the shortcut differs from branch + 1 (%d states)" % shifted_branch_states)
	view.queue_free()
	other_focus.queue_free()
	close_focus.queue_free()
	await process_frame
	if failures.is_empty():
		print("run_route_atlas_shortcuts_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_route_atlas_shortcuts_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
