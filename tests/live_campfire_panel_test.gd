extends SceneTree
## Mounted real-service Campfire tests. This controller, never the view, commits.
const NODE := "f03_camp"
var failures: Array[String] = []
var checks := 0
var authored: Array = []
var panel: LiveCampfirePanel
var intents: Array[Dictionary] = []

class Controller:
	static func submit(source: RunCampfireVisit, intent: Dictionary) -> Dictionary:
		if source == null or intent.get("source_visit") != source:
			return {"ok": false}
		var node: Variant = intent.get("node_id")
		var heroes: Variant = intent.get("expected_heroes")
		match intent.get("action"):
			"heal": return source.choose_heal(node, heroes)
			"leave": return source.leave(node, heroes)
		return {"ok": false}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func _party(hps: Array, maxima: Array = []) -> Array:
	var party: Array = []
	for i in range(3):
		var hero: Dictionary = authored[i].duplicate(true)
		hero["position"] = i + 1
		hero["hp"] = hps[i]
		if maxima.size() == 3:
			hero["max_hp"] = maxima[i]
		hero["block"] = i + 7
		hero["statuses"] = {"bleed": {"stacks": i + 1}}
		hero["metadata"] = {"threads": ["mustard", {"knot": i}]}
		party.append(hero)
	return party


func _settle() -> void:
	for i in range(4):
		await process_frame


func _bind(source: RunCampfireVisit) -> void:
	intents.clear()
	panel.bind(source)
	await _settle()


func _activate(button: Button, keyboard: bool, key: Key = KEY_ENTER) -> void:
	_check(button != null and button.is_inside_tree() and button.is_visible_in_tree()
		and not button.disabled and button.focus_mode == Control.FOCUS_ALL,
		"authentic mouse/keyboard-reachable mounted action")
	if button == null or not button.is_inside_tree() or button.disabled:
		return
	if keyboard:
		button.grab_focus()
		_check(button.has_focus(), "focused key target")
		for down in [true, false]:
			var event := InputEventKey.new()
			event.keycode = key
			event.pressed = down
			root.push_input(event)
			await process_frame
	else:
		var point := button.get_global_rect().get_center()
		_check(Rect2(Vector2.ZERO, Vector2(root.size)).has_point(point),
			"physical mouse target inside viewport")
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
	await _settle()


func _run() -> void:
	var raw := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	var parsed: Variant = JSON.parse_string(raw)
	_check(not raw.is_empty() and typeof(parsed) == TYPE_ARRAY,
		"read genuine starter data")
	if typeof(parsed) != TYPE_ARRAY or parsed.size() != 3:
		_check(false, "valid three-hero fixture prerequisite")
		_finish()
		return
	authored = parsed
	root.size = Vector2i(1280, 720)
	panel = LiveCampfirePanel.new()
	panel.position = Vector2(195, 55)
	var early := RunCampfireVisit.new(NODE, _party([35, 18, 0]))
	_check(early.read_state().get("status") == "open", "real open pre-mount visit")
	panel.bind(early)
	root.add_child(panel)
	panel.decision_requested.connect(func(intent: Dictionary): intents.append(intent))
	await _settle()
	_check(panel.heal_button.has_focus(), "pre-mount bind initially focuses Heal")
	# Cosmetic mounting happens before guarding the global RNG.
	seed(266)
	var expected_draw := randi()
	seed(266)
	await _layout_and_previews()
	for fixture in [
		{"action": "heal", "keyboard": false, "key": KEY_ENTER},
		{"action": "heal", "keyboard": true, "key": KEY_ENTER},
		{"action": "leave", "keyboard": true, "key": KEY_SPACE},
		{"action": "leave", "keyboard": false, "key": KEY_ENTER}
	]:
		await _positive(fixture)
	await _keyboard_positive()
	await _keyboard_negative()
	await _fail_closed()
	_check(randi() == expected_draw, "every mounted browse/commit/rejection uses zero global RNG")
	panel.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_campfire_panel_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _layout_and_previews() -> void:
	var window := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(panel.size == Vector2(880, 600) and window.encloses(panel.get_global_rect()),
		"fixed sewn gothic-felt panel contained at 1280x720")
	_check(panel.title_label.text == "CAMPFIRE"
		and panel.title_label.get_theme_font_size("font_size") >= 35
		and panel.get_theme_default_font_size() > 0, "large readable Campfire title")
	_check(panel.hero_labels.size() == 3 and panel.heal_button.text == "Heal"
		and panel.leave_button.text == "Leave", "exactly three ribbons and two actions")
	_check(panel.heal_button.tooltip_text.contains("1 → Heal")
		and panel.leave_button.tooltip_text.contains("2 → Leave"),
		"discoverable shortcut hints in button tooltips, captions unchanged")
	var all_buttons := panel.find_children("*", "Button", true, false)
	_check(all_buttons.size() == 2 and all_buttons.has(panel.heal_button)
		and all_buttons.has(panel.leave_button), "no hidden extra actionable choices")
	for control in [panel.title_label, panel.heal_button, panel.leave_button]:
		_check(window.encloses(control.get_global_rect()), "title/button on screen")
	_check(panel.heal_button.get_global_rect().size.x >= 300
		and panel.leave_button.get_global_rect().size.y >= 60
		and panel.heal_button.get_theme_stylebox("normal") != null
		and panel.heal_button.get_theme_stylebox("focus") != null
		and panel.get_script().source_code.contains("func _draw()"),
		"big button focus and code-drawn fallback in absence of art")
	_check(panel.heal_button.get_theme_color("font_color").get_luminance() > 0.65,
		"contrast for readable cream-on-oxblood action")
	var source := RunCampfireVisit.new(NODE, _party([35, 18, 0]))
	await _preview_fixture(source, [40, 27, 8], "wounded starter, Torn revive first")
	await _preview_fixture(RunCampfireVisit.new(NODE, _party([40, 30, 26])),
		[40, 30, 26], "fully healthy still permitted")
	await _preview_fixture(RunCampfireVisit.new(NODE, _party([0, 0, 1])),
		[13, 10, 8], "two Torn heroes")
	await _preview_fixture(RunCampfireVisit.new(NODE, _party([0, 26, 20], [37, 27, 23])),
		[12, 27, 23], "non-round max HP floored individually")
	# The three original heroes are not a fixed identity allowlist.
	var alternate := _party([5, 6, 7])
	alternate[0]["id"] = "quilt_mage"
	alternate[0]["name"] = "Quilt Mage"
	alternate[1]["id"] = "needle_bard"
	alternate[1]["name"] = "Needle Bard"
	alternate[2]["id"] = "patch_scout"
	alternate[2]["name"] = "Patch Scout"
	await _preview_fixture(RunCampfireVisit.new("another_camp", alternate),
		[17, 15, 14], "alternate source identities retained")
	await _bind(source)
	panel.heal_button.grab_focus()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	root.push_input(tab)
	await process_frame
	_check(panel.leave_button.has_focus(), "Tab reaches Leave, independently of mouse")
	_check(source.read_state().status == "open" and intents.is_empty(),
		"focus/preview never consume true visit")


func _preview_fixture(visit: RunCampfireVisit, expected_hp: Array, label: String) -> void:
	await _bind(visit)
	var source: Dictionary = visit.read_state()
	_check(source.get("ok") == true and source.get("status") == "open"
		and source.get("heroes", []).size() == 3, label + ": real complete service fixture")
	if source.get("status") != "open":
		return
	var oracle: Dictionary = RunRestRecovery.new(source["heroes"]).choose_heal()
	_check(oracle.get("ok") == true and oracle.get("heroes", []).size() == 3,
		label + ": independent service oracle exists")
	if not oracle.get("ok"):
		return
	for i in range(3):
		var before: Dictionary = source["heroes"][i]
		var after: Dictionary = oracle["heroes"][i]
		_check(int(after["hp"]) == expected_hp[i], label + ": expected recovery HP")
		var expected_actor := before.duplicate(true)
		expected_actor["hp"] = expected_hp[i]
		_check(after == expected_actor, label + ": oracle changes HP only")
		var expected_name := str(before.get("name", "")).strip_edges()
		if expected_name.is_empty():
			expected_name = str(before["id"]).replace("_", " ").capitalize()
		var gain := int(after["hp"]) - int(before["hp"])
		var gain_text := "FULL" if gain == 0 else ("(+%d HP)" % gain)
		var note := "  ·  TORN → REVIVED" if int(before["hp"]) == 0 else ""
		var caption := "%s    %d → %d / %d HP  ·  %s%s" % [
			expected_name, before["hp"], after["hp"], before["max_hp"], gain_text, note]
		_check(panel.hero_labels[i].text == caption,
			label + ": truthful source name / HP ribbon " + str(i))
		_check(panel.hero_labels[i].get_theme_font_size("font_size") >= 24
			and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(
				panel.hero_labels[i].get_global_rect()),
			label + ": mounted ribbon readable and visible")
	_check(not panel.heal_button.disabled and not panel.leave_button.disabled,
		label + ": Heal valid regardless of delta, Leave always allowed")
	_check(visit.read_state() == source and intents.is_empty(),
		label + ": preview read-only and no source decision")


func _positive(fixture: Dictionary) -> void:
	var source_fixture := _party([35, 18, 0])
	var visit := RunCampfireVisit.new(NODE, source_fixture)
	var saved := visit.read_state()
	_check(saved.ok and saved.status == "open"
		and saved.heroes.size() == 3, "positive actual open visit precondition")
	source_fixture[0]["metadata"]["threads"][1]["knot"] = -222
	source_fixture[2]["hp"] = 26
	_check(visit.read_state() == saved, "visit isolated from mutated constructor input")
	await _bind(visit)
	var action: String = fixture["action"]
	var target: Button = panel.heal_button if action == "heal" else panel.leave_button
	await _activate(target, fixture["keyboard"], fixture["key"])
	_check(intents.size() == 1 and visit.read_state() == saved,
		"one UI signal and no pre-controller mutation for " + action)
	if intents.size() != 1:
		return
	var intent := intents[0]
	_check(intent.get("action") == action and intent.get("node_id") == NODE
		and intent.get("source_visit") == visit
		and intent.get("expected_heroes") == saved.heroes,
		"exact bound instance/node/deep full original roster intent " + action)
	var wrong := RunCampfireVisit.new(NODE, saved.heroes)
	_check(Controller.submit(wrong, intent).get("ok") == false
		and wrong.read_state().status == "open", "lookalike visit cannot borrow identity")
	var oracle := RunRestRecovery.new(saved.heroes).choose_heal()
	var result := Controller.submit(visit, intent)
	_check(result.get("ok") == true and result.get("decision") == action
		and result.get("node_id") == NODE, "controller accepted authentic decision once")
	var expected_heroes: Array = oracle.heroes if action == "heal" else saved.heroes
	_check(result.get("heroes") == expected_heroes
		and visit.read_state().heroes == expected_heroes,
		"heal equals independent recovery / Leave changes no hero field")
	var consumed_state := visit.read_state()
	_check(consumed_state.status == ("healed" if action == "heal" else "left"),
		"real service consumed exactly once")
	_check(not Controller.submit(visit, intent).get("ok")
		and visit.read_state() == consumed_state, "controller rejects second receipt")
	panel.heal_button.pressed.emit()
	panel.leave_button.pressed.emit()
	_check(intents.size() == 1 and visit.read_state() == consumed_state,
		"double-click or opposite action never emits")
	intent.expected_heroes[0]["statuses"]["bleed"]["stacks"] = -333
	intent.expected_heroes[1]["metadata"]["threads"][1]["knot"] = -444
	_check(visit.read_state() == consumed_state and saved.heroes[0]["statuses"]["bleed"]["stacks"] == 1,
		"returned intent nested dictionaries deeply detached from authority")


func _reject_without_mutation(visit: RunCampfireVisit, label: String) -> void:
	var before: Dictionary = visit.read_state()
	var count := intents.size()
	panel.heal_button.pressed.emit()
	panel.leave_button.pressed.emit()
	_check(intents.size() == count and visit.read_state() == before,
		label + ": no request and zero service mutation")


func _fail_closed() -> void:
	var invalids: Array[RunCampfireVisit] = [
		RunCampfireVisit.new("  ", _party([35, 18, 0])),
		RunCampfireVisit.new(NODE, _party([0, 0, 0])),
		RunCampfireVisit.new(NODE, []),
	]
	for invalid in invalids:
		_check(not invalid.read_state().ok, "invalid construction genuinely invalid")
		await _bind(invalid)
		_check(panel.heal_button.disabled and panel.leave_button.disabled
			and panel.hero_labels[0].text.is_empty(), "invalid service has no actionable UI")
		_reject_without_mutation(invalid, "invalid visit")
	var consumed := RunCampfireVisit.new(NODE, _party([35, 18, 0]))
	var initial := consumed.read_state()
	_check(consumed.leave(initial.node_id, initial.heroes).ok, "genuinely consumed service fixture")
	await _bind(consumed)
	_check(panel.heal_button.disabled and panel.leave_button.disabled,
		"already consumed visit cannot be rebound")
	_reject_without_mutation(consumed, "consumed visit")
	var original := RunCampfireVisit.new(NODE, _party([35, 18, 0]))
	await _bind(original)
	var source := original.read_state()
	var stale_heal: Callable = panel._connections[panel.heal_button]
	var stale_leave: Callable = panel._connections[panel.leave_button]
	for button in [panel.heal_button, panel.leave_button]:
		button.disabled = true
		var before := original.read_state()
		var callback: Callable = panel._connections[button]
		callback.call()
		_check(intents.is_empty() and original.read_state() == before and not panel._submitted,
			"disabled action rejects its captured callback without spending submission")
		button.disabled = false
	panel.title_label.text = "Sewing Circle"
	_reject_without_mutation(original, "forged title metadata")
	panel.title_label.text = "CAMPFIRE"
	panel.hero_labels[0].text = "Warden 999 HP"
	_reject_without_mutation(original, "forged HP ribbon")
	panel.hero_labels[0].text = panel._hero_text(0)
	panel.heal_button.text = "Buy for 0 gold"
	_reject_without_mutation(original, "forged choice caption")
	panel.heal_button.text = "Heal"
	panel.hide()
	_reject_without_mutation(original, "hidden view")
	panel.show()
	root.remove_child(panel)
	_reject_without_mutation(original, "detached view")
	root.add_child(panel)
	await _settle()
	# Changing the stored source behind the view must invalidate a real open visit.
	original._heroes[1]["statuses"]["bleed"]["stacks"] = 999
	_reject_without_mutation(original, "source nested roster drift")
	original._heroes = source.heroes.duplicate(true)
	original._node_id = "forged_node"
	_reject_without_mutation(original, "source node drift")
	var next := RunCampfireVisit.new("f04_new", _party([0, 12, 17], [37, 27, 23]))
	await _bind(next)
	var next_before := next.read_state()
	_check(panel.hero_labels[0].text.contains("0 → 12 / 37")
		and panel.hero_labels[1].text.contains("12 → 20 / 27"),
		"new visit projects its own HP after rebind")
	stale_heal.call()
	stale_leave.call()
	_check(intents.is_empty() and next.read_state() == next_before
		and original.read_state().node_id == "forged_node",
		"old generation cannot act upon either source")
	# Source changes after a fresh successful bind, without touching UI metadata.
	next._heroes[0]["hp"] = 1
	_reject_without_mutation(next, "source HP changed since bind")
	await _bind(RunCampfireVisit.new("f05", _party([35, 18, 0])))
	var current := panel._visit
	var current_state := current.read_state()
	panel._snapshot["node_id"] = "faked_tile"
	_reject_without_mutation(current, "forged captured node")
	await _bind(current)
	panel._snapshot["heroes"][1]["hp"] = 1
	_reject_without_mutation(current, "different expected snapshot")
	await _bind(current)
	var retired: Callable = panel._connections[panel.heal_button]
	panel.close()
	retired.call()
	_reject_without_mutation(current, "closed panel and retired callback")
	await _bind(current)
	_check(panel.heal_button.has_focus() and panel.heal_button.text == "Heal"
		and current.read_state() == current_state,
		"fresh legitimate rebind reopens action without altering source")
	await _activate(panel.heal_button, false)
	_check(intents.size() == 1 and current.read_state() == current_state,
		"fresh replacement can emit again, with no view-side commit")


func _keyboard_positive() -> void:
	for fixture in [
		{"action": "heal", "key": KEY_1},
		{"action": "heal", "key": KEY_KP_1},
		{"action": "leave", "key": KEY_2},
		{"action": "leave", "key": KEY_KP_2},
	]:
		var source_fixture := _party([35, 18, 0])
		var visit := RunCampfireVisit.new(NODE, source_fixture)
		var saved := visit.read_state()
		await _bind(visit)
		intents.clear()
		var event_down := InputEventKey.new()
		event_down.keycode = fixture["key"]
		event_down.pressed = true
		root.push_input(event_down)
		await process_frame
		var event_up := InputEventKey.new()
		event_up.keycode = fixture["key"]
		event_up.pressed = false
		root.push_input(event_up)
		await process_frame
		await _settle()
		var action: String = fixture["action"]
		_check(intents.size() == 1 and visit.read_state() == saved,
			"keyboard number key " + str(fixture["key"]) + " emits one intent and no pre-commit for " + action)
		if intents.size() == 1:
			var intent := intents[0]
			_check(intent.get("action") == action and intent.get("node_id") == NODE
				and intent.get("source_visit") == visit
				and intent.get("expected_heroes") == saved.heroes,
				"keyboard intent exact bound instance/node/roster for " + action + " with key " + str(fixture["key"]))
			var oracle := RunRestRecovery.new(saved.heroes).choose_heal()
			var result := Controller.submit(visit, intent)
			_check(result.get("ok") == true and result.get("decision") == action
				and result.get("node_id") == NODE,
				"keyboard-submitted authentic decision accepted once for " + action)
			var expected_heroes: Array = oracle.heroes if action == "heal" else saved.heroes
			_check(result.get("heroes") == expected_heroes
				and visit.read_state().heroes == expected_heroes,
				"keyboard heal equals independent recovery / Leave unchanged")


func _check_key_rejected(visit: RunCampfireVisit, key: Key, label: String, echo: bool = false, modifier: Key = KEY_NONE, pressed: bool = true) -> void:
	var before: Dictionary = visit.read_state() if visit != null else {}
	var count := intents.size()
	
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	event.echo = echo
	event.shift_pressed = (modifier == KEY_SHIFT)
	event.ctrl_pressed = (modifier == KEY_CTRL)
	event.alt_pressed = (modifier == KEY_ALT)
	event.meta_pressed = (modifier == KEY_META)
	root.push_input(event)
	await process_frame
	
	if pressed:
		var event_up := InputEventKey.new()
		event_up.keycode = key
		event_up.pressed = false
		event_up.shift_pressed = event.shift_pressed
		event_up.ctrl_pressed = event.ctrl_pressed
		event_up.alt_pressed = event.alt_pressed
		event_up.meta_pressed = event.meta_pressed
		root.push_input(event_up)
		await process_frame
		
	await _settle()
	_check(intents.size() == count, label + ": inert handling, intent count unchanged")
	if visit != null:
		_check(visit.read_state() == before, label + ": service snapshot unchanged")

func _keyboard_negative() -> void:
	var visit := RunCampfireVisit.new(NODE, _party([35, 18, 0]))
	await _bind(visit)
	
	# Modified keys must be inert.
	for modifier_key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		await _check_key_rejected(visit, KEY_1, "modified key " + str(modifier_key), false, modifier_key)
	
	# Echo/release/unrelated keys must be inert.
	for k in [KEY_1, KEY_2, KEY_KP_1, KEY_KP_2]:
		await _check_key_rejected(visit, k, "pressed echo key " + str(k), true)
		await _check_key_rejected(visit, k, "released key " + str(k), false, KEY_NONE, false)
		
	await _check_key_rejected(visit, KEY_3, "unrelated key KEY_3")
	
	# Invalid/consumed bindings
	var invalid_visit := RunCampfireVisit.new("  ", _party([35, 18, 0]))
	await _bind(invalid_visit)
	await _check_key_rejected(invalid_visit, KEY_1, "invalid visit")
	
	var consumed := RunCampfireVisit.new(NODE, _party([35, 18, 0]))
	consumed.leave(consumed.read_state().node_id, consumed.read_state().heroes)
	await _bind(consumed)
	await _check_key_rejected(consumed, KEY_1, "consumed visit")
	
	# Hidden panel
	await _bind(visit)
	panel.hide()
	await _check_key_rejected(visit, KEY_1, "hidden panel")
	panel.show()
	await _settle()
	
	# Detached panel
	root.remove_child(panel)
	await _check_key_rejected(visit, KEY_1, "detached panel")
	root.add_child(panel)
	await _settle()
	
	# Button disabled
	panel.heal_button.disabled = true
	await _check_key_rejected(visit, KEY_1, "disabled button")
	panel.heal_button.disabled = false
	
	# Source snapshot / node drift
	var before_drift := visit.read_state()
	visit._heroes[1]["statuses"]["bleed"]["stacks"] = 999
	await _check_key_rejected(visit, KEY_1, "source roster drift")
	visit._heroes = before_drift.heroes.duplicate(true)
	
	visit._node_id = "forged_node"
	await _check_key_rejected(visit, KEY_1, "source node drift")
	visit._node_id = NODE
	
	# Already submitted
	await _bind(visit)
	var submitted_down := InputEventKey.new()
	submitted_down.keycode = KEY_1
	submitted_down.pressed = true
	root.push_input(submitted_down)
	await process_frame
	var submitted_up := InputEventKey.new()
	submitted_up.keycode = KEY_1
	submitted_up.pressed = false
	root.push_input(submitted_up)
	await process_frame
	await _settle()
	
	await _check_key_rejected(visit, KEY_1, "already submitted visit")
	
	# Rebound visits and retired callbacks
	await _bind(visit)
	var stale_heal: Callable = panel._connections[panel.heal_button]
	var next := RunCampfireVisit.new("f04_new", _party([0, 12, 17], [37, 27, 23]))
	await _bind(next)
	
	var count_before_stale := intents.size()
	stale_heal.call()
	await _settle()
	_check(intents.size() == count_before_stale, "retired callback after keyboard rebind")
	
	var visit_before := visit.read_state()
	var next_before := next.read_state()
	var next_down := InputEventKey.new()
	next_down.keycode = KEY_1
	next_down.pressed = true
	root.push_input(next_down)
	await process_frame
	var next_up := InputEventKey.new()
	next_up.keycode = KEY_1
	next_up.pressed = false
	root.push_input(next_up)
	await process_frame
	await _settle()
	
	_check(intents.size() == count_before_stale + 1, "real number key routes to current visit")
	var next_intent: Dictionary = intents[-1]
	_check(next_intent.get("action") == "heal" and next_intent.get("source_visit") == next, "intent bound to current visit")
	_check(visit.read_state() == visit_before, "retired visit unmutated by input to current visit")
	var next_oracle := RunRestRecovery.new(next_before.heroes).choose_heal()
	var next_result := Controller.submit(next, next_intent)
	_check(next_result.get("ok") == true and next.read_state().heroes == next_oracle.heroes, "keyboard commit on rebound visit applied correct HP")
	_check(not Controller.submit(next, next_intent).get("ok"), "no duplicate/replay on rebound visit")

	# After negative attempts, prove one valid key still commits while replay/RNG remains unchanged
	await _bind(visit)
	var count_before_genuine := intents.size()
	var genuine_down := InputEventKey.new()
	genuine_down.keycode = KEY_2
	genuine_down.pressed = true
	root.push_input(genuine_down)
	await process_frame
	var genuine_up := InputEventKey.new()
	genuine_up.keycode = KEY_2
	genuine_up.pressed = false
	root.push_input(genuine_up)
	await process_frame
	await _settle()
	
	_check(intents.size() == count_before_genuine + 1, "genuine action still works after rejected keyboard input")
	var genuine_intent: Dictionary = intents[-1]
	_check(genuine_intent.get("action") == "leave", "final genuine action is leave")
	var genuine_result := Controller.submit(visit, genuine_intent)
	_check(genuine_result.get("ok") == true and genuine_result.get("decision") == "leave" and visit.read_state().status == "left", "final genuine KEY_2 commit accepted")
	_check(visit.read_state().heroes == visit_before.heroes, "Leave roster unchanged")
	_check(not Controller.submit(visit, genuine_intent).get("ok"), "final genuine action rejects replay")
