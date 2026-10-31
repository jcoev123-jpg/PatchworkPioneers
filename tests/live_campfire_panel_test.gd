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
	_check(panel.heal_button.has_focus()
		and root.gui_get_focus_owner() == panel.heal_button,
		"pre-mount bind initially focuses Heal for a recovering party")
	intents.clear()
	await _activate(panel.heal_button, true, KEY_ENTER)
	_check(intents.size() == 1 and intents[0].get("action") == "heal"
		and intents[0].get("source_visit") == early
		and intents[0].get("node_id") == NODE,
		"default Heal focus commits through one real keyboard activation")
	var early_receipt: Dictionary = Controller.submit(early, intents[0])
	_check(early_receipt.get("ok") == true and early_receipt.get("decision") == "heal"
		and early.read_state().status == "healed",
		"default keyboard Heal consumed exactly once")
	_check(not Controller.submit(early, intents[0]).get("ok"),
		"default keyboard Heal receipt is once-only")
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
	await _default_focus()
	# Two seeded spans, so the focus sections neither hide nor weaken the
	# original browse/commit/rejection RNG guard.
	_check(randi() == expected_draw,
		"layout, previews, mouse/Enter/Space and number keys use zero global RNG")
	seed(266)
	await _focus_outside_ignored()
	await _focused_shortcuts()
	await _keyboard_negative()
	await _fail_closed()
	await _rest_art_ambient()
	_check(randi() == expected_draw,
		"every mounted browse/commit/rejection and rest-art motion uses zero global RNG")
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
	_check(panel.hero_labels.size() == 3 and panel.heal_button.text == "1 Heal · 30%"
		and panel.leave_button.text == "0 Leave · free",
		"exactly three ribbons and two actions, Leave shows its primary 0")
	_check(panel.heal_button.tooltip_text.contains("1 → Heal")
		and panel.leave_button.tooltip_text.contains("0 → Leave")
		and panel.leave_button.tooltip_text.contains("2 also works"),
		"tooltips advertise the primary 0 shortcut and the retained 2 alias")
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
		[40, 30, 26], "fully healthy party with a zero-gain preview")
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
	var any_gain := false
	for i in range(3):
		if int(expected_hp[i]) > int(source["heroes"][i]["hp"]):
			any_gain = true
	_check(panel.heal_button.disabled == (not any_gain) and not panel.leave_button.disabled,
		label + ": Heal enabled exactly when the preview genuinely recovers HP")
	var expected_default: Button = panel.heal_button if any_gain else panel.leave_button
	_check(expected_default.has_focus()
		and root.gui_get_focus_owner() == expected_default,
		label + ": authentic preview gain picks the actual default focus")
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
	panel.heal_button.text = "1 Heal · 30%"
	panel.leave_button.text = "0 Leave · free!"
	_reject_without_mutation(original, "forged leave caption")
	panel.leave_button.text = "0 Leave · free"
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
	_check(panel.heal_button.has_focus() and panel.heal_button.text == "1 Heal · 30%"
		and current.read_state() == current_state,
		"fresh legitimate rebind reopens action without altering source")
	await _activate(panel.heal_button, false)
	_check(intents.size() == 1 and current.read_state() == current_state,
		"fresh replacement can emit again, with no view-side commit")


func _rest_art_ambient() -> void:
	var art: Texture2D = panel.rest_art_texture
	_check(art != null and art.resource_path == "res://assets/paper/backgrounds/rest_camp.png",
		"mounted panel loads the already-present authored rest art")
	_check(panel.find_children("*", "TextureRect", true, false).is_empty()
		and panel.find_children("*", "Button", true, false).size() == 2,
		"decoration lives in the panel canvas, never as an input-receiving node")
	if art == null:
		return
	var baseline := {"scale": 1.0, "offset": Vector2.ZERO}
	_check(LiveCampfirePanel.rest_art_transform_at(0.0) == baseline
		and LiveCampfirePanel.rest_art_transform_at(
			LiveCampfirePanel.REST_ART_BREATH_PERIOD * LiveCampfirePanel.REST_ART_PAN_PERIOD) == baseline,
		"presentation motion is smooth repetition from and back to the static baseline")
	var frame := Rect2(Vector2(6, 6), panel.size - Vector2(12, 12))
	for dims in [Vector2(640, 400), Vector2(880, 600), Vector2(1152, 648), Vector2(2200, 900)]:
		var covered := true
		var inside := true
		for step in range(28):
			var elapsed := LiveCampfirePanel.REST_ART_BREATH_PERIOD \
				* LiveCampfirePanel.REST_ART_PAN_PERIOD * float(step) / 27.0
			var crop := LiveCampfirePanel.rest_art_crop(dims, frame,
				LiveCampfirePanel.rest_art_transform_at(elapsed))
			if crop.is_empty():
				covered = false
				inside = false
				continue
			var dest: Rect2 = crop["rect"]
			var region: Rect2 = crop["region"]
			if dest != frame:
				covered = false
			if region.position.x < 1.0 or region.position.y < 1.0 \
					or region.end.x > dims.x - 1.0 or region.end.y > dims.y - 1.0:
				inside = false
		_check(covered, "art crop covers the whole sewn frame for image " + str(dims))
		_check(inside, "no image edge is revealed across the full motion cycle for " + str(dims))
	var visit := RunCampfireVisit.new(NODE, _party([35, 18, 0]))
	var saved := visit.read_state()
	intents.clear()
	panel.bind(visit)
	var start := panel.rest_art_transform()
	_check(start == baseline, "freshly bound mounted visit starts at the exact static baseline")
	var heal_rect := panel.heal_button.get_global_rect()
	var leave_rect := panel.leave_button.get_global_rect()
	var title_rect := panel.title_label.get_global_rect()
	var hero_rects: Array[Rect2] = []
	for i in range(3):
		hero_rects.append(panel.hero_labels[i].get_global_rect())
	panel.advance_rest_art(2.0)
	var moved := panel.rest_art_transform()
	var moved_offset: Vector2 = moved["offset"]
	_check(float(moved["scale"]) > 1.0
		and float(moved["scale"]) - 1.0 <= LiveCampfirePanel.REST_ART_BREATH
		and moved_offset != Vector2.ZERO
		and moved_offset.length() <= LiveCampfirePanel.REST_ART_PAN.length(),
		"elapsed presentation time moves only the restrained decorative transform")
	_check(panel.heal_button.get_global_rect() == heal_rect
		and panel.leave_button.get_global_rect() == leave_rect
		and panel.title_label.get_global_rect() == title_rect
		and panel.hero_labels[0].get_global_rect() == hero_rects[0]
		and panel.hero_labels[1].get_global_rect() == hero_rects[1]
		and panel.hero_labels[2].get_global_rect() == hero_rects[2],
		"buttons, forecasts and their hit rectangles stay stationary under motion")
	_check(visit.read_state() == saved and intents.is_empty(),
		"elapsed motion consumes no visit, roster or intent")
	await _settle()
	# ProjectSettings accessibility/reduced_motion (default false), restored afterward.
	var prior: Variant = ProjectSettings.get_setting("accessibility/reduced_motion", false)
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	await _bind(RunCampfireVisit.new(NODE, _party([35, 18, 0])))
	_check(panel.is_visible_in_tree() and not panel.heal_button.disabled
		and not panel.leave_button.disabled and panel.heal_button.has_focus()
		and panel.title_label.text == "CAMPFIRE"
		and panel.hero_labels[0].text == panel._hero_text(0),
		"reduced motion still mounts the readable focused actionable panel")
	panel.advance_rest_art(5.0)
	_check(panel.rest_art_transform() == baseline,
		"accessibility/reduced_motion keeps the authored art exactly static")
	ProjectSettings.set_setting("accessibility/reduced_motion", prior)
	_check(not panel._reduced_motion_active(), "prior reduced-motion setting restored afterward")
	# Nullable explicit override for focused tests.
	await _bind(RunCampfireVisit.new(NODE, _party([35, 18, 0])))
	panel.advance_rest_art(3.0)
	_check(panel.rest_art_transform() != baseline, "motion is genuinely live before the override")
	panel.set_reduced_motion_override(true)
	_check(panel.rest_art_transform() == baseline,
		"explicit reduced-motion override restores the exact static baseline")
	panel.advance_rest_art(4.0)
	_check(panel.rest_art_transform() == baseline,
		"no motion accumulates while the explicit override is true")
	panel.set_reduced_motion_override(null)
	_check(panel.rest_art_transform() == baseline,
		"lifted override restarts only from the static baseline")
	panel.advance_rest_art(2.0)
	_check(panel.rest_art_transform() != baseline,
		"motion resumes only through fresh presentation time after the override lifts")
	# Missing art keeps today's readable static panel without errors.
	var saved_art: Texture2D = panel.rest_art_texture
	panel.rest_art_texture = null
	panel.queue_redraw()
	await _settle()
	await _bind(RunCampfireVisit.new(NODE, _party([35, 18, 0])))
	panel.advance_rest_art(5.0)
	_check(panel.rest_art_transform() == baseline,
		"missing art keeps the exact static baseline transform")
	_check(panel.is_visible_in_tree() and panel.title_label.text == "CAMPFIRE"
		and panel.hero_labels[0].text == panel._hero_text(0)
		and panel.hero_labels[1].text == panel._hero_text(1)
		and panel.hero_labels[2].text == panel._hero_text(2)
		and not panel.heal_button.disabled and not panel.leave_button.disabled
		and panel.heal_button.has_focus(),
		"missing art retains today's readable focused static panel")
	panel.rest_art_texture = saved_art
	# close() stops and restores; rebinding another visit restarts from baseline.
	var closing := RunCampfireVisit.new(NODE, _party([35, 18, 0]))
	intents.clear()
	panel.bind(closing)
	panel.advance_rest_art(6.0)
	_check(panel.rest_art_transform() != baseline, "art is genuinely moving before close")
	panel.close()
	await _settle()
	_check(panel.rest_art_transform() == baseline
		and not panel.is_visible_in_tree() and panel.heal_button.disabled
		and panel.leave_button.disabled and panel.hero_labels[0].text.is_empty(),
		"close() stops and restores the exact static transform on a closed panel")
	panel.advance_rest_art(7.0)
	_check(panel.rest_art_transform() == baseline,
		"no old motion resumes on the closed panel")
	var reopened := RunCampfireVisit.new("f07_reopen", _party([12, 18, 21], [37, 27, 23]))
	intents.clear()
	panel.bind(reopened)
	_check(panel.is_visible_in_tree() and not panel.leave_button.disabled
		and panel.rest_art_transform() == baseline,
		"rebinding another visit reopens actionable from the exact static baseline")
	panel.hide()
	await _settle()
	_check(panel.rest_art_transform() == baseline,
		"a hidden panel restores the static baseline")
	panel.advance_rest_art(3.0)
	_check(panel.rest_art_transform() == baseline,
		"hidden panels accumulate no motion")
	panel.show()
	_check(panel.rest_art_transform() == baseline,
		"the shown panel resumes only from the static baseline")
	await _settle()
	# One genuine decision still submits exactly one intent while the art animates.
	var deciding := RunCampfireVisit.new(NODE, _party([35, 18, 0]))
	var deciding_before := deciding.read_state()
	intents.clear()
	panel.bind(deciding)
	panel.advance_rest_art(4.0)
	var deciding_heal_rect := panel.heal_button.get_global_rect()
	var deciding_leave_rect := panel.leave_button.get_global_rect()
	await _activate(panel.heal_button, false)
	_check(intents.size() == 1 and intents[0].get("action") == "heal"
		and intents[0].get("source_visit") == deciding
		and intents[0].get("node_id") == NODE
		and intents[0].get("expected_heroes") == deciding_before.heroes,
		"one real mouse intent submits while the art animates")
	_check(deciding.read_state() == deciding_before,
		"ambient motion never commits the visit itself")
	var deciding_oracle: Dictionary = RunRestRecovery.new(deciding_before.heroes).choose_heal()
	var deciding_receipt := Controller.submit(deciding, intents[0])
	_check(deciding_receipt.get("ok") == true and deciding_receipt.get("decision") == "heal"
		and deciding_receipt.get("heroes") == deciding_oracle.get("heroes")
		and deciding.read_state().heroes == deciding_oracle.heroes,
		"the heal receipt stays revive-first floor(30%) capped after the visual addition")
	_check(not Controller.submit(deciding, intents[0]).get("ok"),
		"the same heal receipt remains once-only")
	_check(panel.heal_button.get_global_rect() == deciding_heal_rect
		and panel.leave_button.get_global_rect() == deciding_leave_rect,
		"real hit rectangles are unchanged after the decision")
	# The focused 0 Leave shortcut still submits exactly one free Leave at full health.
	var keyed := RunCampfireVisit.new(NODE, _party([40, 30, 26]))
	var keyed_before := keyed.read_state()
	intents.clear()
	panel.bind(keyed)
	await _settle()
	_check(panel.leave_button.has_focus() and panel.heal_button.disabled
		and not panel.leave_button.disabled,
		"full-health party stays focused on the free Leave under motion")
	await _press(KEY_0)
	_check(intents.size() == 1 and intents[0].get("action") == "leave"
		and intents[0].get("source_visit") == keyed
		and intents[0].get("node_id") == NODE
		and intents[0].get("expected_heroes") == keyed_before.heroes,
		"the physical 0 Leave shortcut submits exactly one intent under motion")
	var keyed_receipt := Controller.submit(keyed, intents[0])
	_check(keyed_receipt.get("ok") == true and keyed_receipt.get("decision") == "leave"
		and keyed_receipt.get("heroes") == keyed_before.heroes
		and keyed.read_state().heroes == keyed_before.heroes
		and keyed.read_state().status == "left",
		"the free Leave receipt stays free after the visual addition")
	_check(not Controller.submit(keyed, intents[0]).get("ok"),
		"the same Leave receipt remains once-only")


func _keyboard_positive() -> void:
	for fixture in [
		{"action": "heal", "key": KEY_1},
		{"action": "heal", "key": KEY_KP_1},
		{"action": "leave", "key": KEY_2},
		{"action": "leave", "key": KEY_KP_2},
		{"action": "leave", "key": KEY_0},
		{"action": "leave", "key": KEY_KP_0},
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


## The authentic zero-versus-positive preview gain alone decides the default
## focus for the pre-mount and rebind paths; focusing alone never consumes a
## visit, roster or RNG, and both real buttons stay explicitly selectable.
func _default_focus() -> void:
	# Zero-gain full trio: authentic source and preview HPs are exactly [40,30,26].
	var full := RunCampfireVisit.new(NODE, _party([40, 30, 26]))
	var full_before: Dictionary = full.read_state()
	_check(full_before.get("ok") == true and full_before.get("status") == "open"
		and full_before.heroes.size() == 3, "full trio genuine open visit")
	var full_oracle: Dictionary = RunRestRecovery.new(full_before.heroes).choose_heal()
	_check(full_oracle.get("ok") == true
		and [int(full_oracle.heroes[0].hp), int(full_oracle.heroes[1].hp),
			int(full_oracle.heroes[2].hp)] == [40, 30, 26],
		"authentic zero-gain preview HPs stay exactly [40,30,26]")
	var pre: LiveCampfirePanel = LiveCampfirePanel.new()
	pre.position = Vector2(200, 60)
	var pre_intents: Array[Dictionary] = []
	pre.decision_requested.connect(func(intent: Dictionary): pre_intents.append(intent))
	pre.bind(full)
	root.add_child(pre)
	await _settle()
	_check(pre.is_visible_in_tree() and pre.leave_button.has_focus()
		and root.gui_get_focus_owner() == pre.leave_button
		and not pre.leave_button.disabled,
		"zero-gain pre-mount bind focuses the real enabled Leave button")
	_check(pre.heal_button.disabled and pre.heal_button.is_visible_in_tree()
		and pre.heal_button.text == "1 Heal · 30%",
		"zero-gain Heal stays visible but disabled at full HP")
	_check(full.read_state() == full_before and pre_intents.is_empty(),
		"zero-gain default focus alone consumes no visit")
	# No input path onto the disabled Heal may forge a decision or spend anything.
	var pre_zero := pre_intents.size()
	var pre_point := pre.heal_button.get_global_rect().get_center()
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = pre_point
		click.pressed = down
		root.push_input(click)
		await process_frame
	await _settle()
	pre.heal_button.grab_focus()
	_check(pre.heal_button.has_focus(),
		"disabled Heal remains a real control inside the focus chain")
	for key in [KEY_ENTER, KEY_SPACE, KEY_1, KEY_KP_1]:
		for down in [true, false]:
			var event := InputEventKey.new()
			event.keycode = key
			event.pressed = down
			root.push_input(event)
			await process_frame
		await _settle()
	pre.heal_button.pressed.emit()
	await _settle()
	_check(pre_intents.size() == pre_zero and full.read_state() == full_before
		and not pre._submitted and not pre.leave_button.disabled,
		"mouse, Enter/Space, physical 1/KP1 and direct signal on the disabled Heal emit nothing")
	intents.clear()
	await _activate(pre.leave_button, true, KEY_ENTER)
	_check(pre_intents.size() == 1 and intents.is_empty()
		and full.read_state() == full_before,
		"default focused Leave emits one and only one current intent")
	if pre_intents.size() == 1:
		var leave_intent: Dictionary = pre_intents[0]
		_check(leave_intent.get("action") == "leave" and leave_intent.get("node_id") == NODE
			and leave_intent.get("source_visit") == full
			and leave_intent.get("expected_heroes") == full_before.heroes,
			"default Leave intent is the authentic bound instance/node/roster")
		var leave_result: Dictionary = Controller.submit(full, leave_intent)
		_check(leave_result.get("ok") == true and leave_result.get("decision") == "leave"
			and leave_result.get("heroes") == full_before.heroes
			and full.read_state().heroes == full_before.heroes,
			"default Leave at full HP leaves all three HPs unchanged")
		_check(full.read_state().status == "left"
			and not Controller.submit(full, leave_intent).get("ok"),
			"default Leave consumes its visit exactly once")
	pre.queue_free()
	await _settle()
	# The same full-HP Leave completes through the primary 0 shortcut on a
	# separately mounted Campfire while the spent panel stays inert.
	var keyed := RunCampfireVisit.new(NODE, _party([40, 30, 26]))
	var keyed_before: Dictionary = keyed.read_state()
	var keyed_panel: LiveCampfirePanel = LiveCampfirePanel.new()
	var keyed_intents: Array[Dictionary] = []
	keyed_panel.decision_requested.connect(func(intent: Dictionary): keyed_intents.append(intent))
	keyed_panel.bind(keyed)
	root.add_child(keyed_panel)
	await _settle()
	_check(keyed_panel.is_visible_in_tree() and keyed_panel.leave_button.has_focus()
		and not keyed_panel.leave_button.disabled and keyed_panel.heal_button.disabled,
		"keyed full-HP bind focuses the enabled Leave with Heal disabled")
	await _activate(keyed_panel.leave_button, true, KEY_0)
	_check(keyed_intents.size() == 1 and keyed.read_state() == keyed_before
		and intents.is_empty(),
		"physical 0 on the focused full-HP Leave emits one intent and nothing for the spent panel")
	if keyed_intents.size() == 1:
		var keyed_intent: Dictionary = keyed_intents[0]
		_check(keyed_intent.get("action") == "leave" and keyed_intent.get("source_visit") == keyed
			and keyed_intent.get("node_id") == NODE
			and keyed_intent.get("expected_heroes") == keyed_before.heroes,
			"keyed full-HP 0 intent is the authentic bound instance/node/roster")
		var keyed_result: Dictionary = Controller.submit(keyed, keyed_intent)
		_check(keyed_result.get("ok") == true and keyed_result.get("decision") == "leave"
			and keyed_result.get("heroes") == keyed_before.heroes
			and keyed.read_state().heroes == keyed_before.heroes
			and keyed.read_state().status == "left",
			"keyed full-HP Leave settles once and changes no hero field")
		_check(not Controller.submit(keyed, keyed_intent).get("ok"),
			"keyed full-HP 0 receipt is once-only")
	keyed_panel.queue_free()
	await _settle()
	# After mounting, a full-health rebind keeps Heal disabled: only the
	# genuine Leave can act, and no input path may forge a Heal decision.
	var full_heal := RunCampfireVisit.new(NODE, _party([40, 30, 26]))
	var heal_before: Dictionary = full_heal.read_state()
	await _bind(full_heal)
	_check(panel.leave_button.has_focus()
		and root.gui_get_focus_owner() == panel.leave_button,
		"full-health rebind after mount defaults to Leave")
	_check(panel.heal_button.disabled and panel.heal_button.is_visible_in_tree()
		and not panel.leave_button.disabled,
		"rebind keeps the zero-gain Heal disabled while Leave stays enabled")
	var stale_default: Callable = panel._connections[panel.leave_button]
	var zero_count := intents.size()
	var heal_point := panel.heal_button.get_global_rect().get_center()
	for down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = heal_point
		click.pressed = down
		root.push_input(click)
		await process_frame
	await _settle()
	panel.heal_button.grab_focus()
	for key in [KEY_ENTER, KEY_SPACE, KEY_1, KEY_KP_1]:
		for down in [true, false]:
			var event := InputEventKey.new()
			event.keycode = key
			event.pressed = down
			root.push_input(event)
			await process_frame
		await _settle()
	panel.heal_button.pressed.emit()
	await _settle()
	_check(intents.size() == zero_count and full_heal.read_state() == heal_before
		and not panel._submitted,
		"rebound disabled Heal admits no mouse, Enter/Space, 1/KP1 or signal decision")
	# The real Leave still emits one legitimate intent and commits once.
	await _activate(panel.leave_button, false)
	_check(intents.size() == zero_count + 1 and full_heal.read_state() == heal_before,
		"the genuine Leave emits one intent without committing")
	if intents.size() == zero_count + 1:
		var leave_intent: Dictionary = intents[-1]
		_check(leave_intent.get("action") == "leave" and leave_intent.get("source_visit") == full_heal
			and leave_intent.get("node_id") == NODE
			and leave_intent.get("expected_heroes") == heal_before.heroes,
			"rebound Leave intent is the authentic bound instance/node/roster")
		var leave_result: Dictionary = Controller.submit(full_heal, leave_intent)
		_check(leave_result.get("ok") == true and leave_result.get("decision") == "leave"
			and leave_result.get("heroes") == heal_before.heroes
			and full_heal.read_state().status == "left",
			"the genuine Leave at full HP consumes its visit exactly once")
		_check(not Controller.submit(full_heal, leave_intent).get("ok"),
			"rebound full-HP Leave receipt is once-only")
	# Independently of the view, the service still accepts an explicit full-HP Heal.
	var full_service := RunCampfireVisit.new(NODE, _party([40, 30, 26]))
	var service_before: Dictionary = full_service.read_state()
	var service_receipt: Dictionary = full_service.choose_heal(service_before.node_id, service_before.heroes)
	_check(service_receipt.get("ok") == true and service_receipt.get("decision") == "heal"
		and service_receipt.get("heroes") == service_before.heroes
		and full_service.read_state().status == RunCampfireVisit.HEALED,
		"explicitly invoked full-HP Heal remains valid for non-view callers")
	_check(not full_service.choose_heal(service_before.node_id, service_before.heroes).get("ok"),
		"explicit full-HP Heal receipt is once-only")
	# Positive-gain parties, including a Torn hero and a one-positive mix, focus Heal.
	var wounded := RunCampfireVisit.new(NODE, _party([35, 18, 0]))
	var wounded_before: Dictionary = wounded.read_state()
	var wounded_oracle: Dictionary = RunRestRecovery.new(wounded_before.heroes).choose_heal()
	_check([int(wounded_oracle.heroes[0].hp), int(wounded_oracle.heroes[1].hp),
		int(wounded_oracle.heroes[2].hp)] == [40, 27, 8],
		"authentic wounded preview recovers to exactly [40,27,8]")
	await _bind(wounded)
	_check(panel.heal_button.has_focus()
		and root.gui_get_focus_owner() == panel.heal_button
		and not panel.heal_button.disabled,
		"positive-gain rebind focuses the real Heal button")
	stale_default.call()
	_check(intents.is_empty() and wounded.read_state() == wounded_before
		and full_heal.read_state().status == "left",
		"retired full-generation Leave callback cannot act after rebind")
	var torn_only := RunCampfireVisit.new(NODE, _party([0, 30, 26]))
	var torn_before: Dictionary = torn_only.read_state()
	await _bind(torn_only)
	_check(panel.heal_button.has_focus() and not panel.heal_button.disabled,
		"a Torn hero guarantees a positive preview and an enabled focused Heal")
	var mixed := RunCampfireVisit.new(NODE, _party([40, 30, 20]))
	var mixed_before: Dictionary = mixed.read_state()
	await _bind(mixed)
	_check(panel.heal_button.has_focus() and not panel.heal_button.disabled,
		"mixed roster with one positive gain focuses an enabled Heal")
	# Full -> wounded -> full rebinding moves the default both ways.
	var full_again := RunCampfireVisit.new(NODE, _party([40, 30, 26]))
	var again_before: Dictionary = full_again.read_state()
	await _bind(full_again)
	_check(panel.leave_button.has_focus()
		and root.gui_get_focus_owner() == panel.leave_button,
		"full -> wounded -> full rebinding returns the default to Leave")
	_check(wounded.read_state() == wounded_before
		and torn_only.read_state() == torn_before
		and mixed.read_state() == mixed_before
		and full_again.read_state() == again_before and intents.is_empty(),
		"focus-only rebinding consumes no visit, roster or intent")


## One real physical key press: down, frame, up, frame, settle.
func _press(key: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = down
		root.push_input(event)
		await process_frame
	await _settle()


## floor(30% of max HP) in integer arithmetic, independent of the panel.
func _heal_amount(hero: Dictionary) -> int:
	@warning_ignore("integer_division")
	return (int(hero["max_hp"]) * 3) / 10


func _recovered_hp(hero: Dictionary) -> int:
	return mini(int(hero["max_hp"]), maxi(1, int(hero["hp"])) + _heal_amount(hero))


## A visible open Campfire must not steal 1/2 from another screen's focused
## control: no intent, no service state change and no global RNG draw.
func _focus_outside_ignored() -> void:
	var external := Button.new()
	external.text = "Map"
	external.position = Vector2(24, 656)
	external.size = Vector2(180, 48)
	external.focus_mode = Control.FOCUS_ALL
	root.add_child(external)
	await _settle()
	_check(external.is_inside_tree() and external.is_visible_in_tree()
		and not external.disabled and external.focus_mode == Control.FOCUS_ALL,
		"separate enabled external Button mounted at 1280x720")
	_check(not panel.is_ancestor_of(external)
		and not panel.get_global_rect().intersects(external.get_global_rect()),
		"external control sits outside the Campfire subtree and panel")
	var visit := RunCampfireVisit.new(NODE, _party([35, 18, 0]))
	var saved := visit.read_state()
	_check(saved.get("ok") == true and saved.get("status") == "open"
		and saved.get("heroes", []).size() == 3, "focus-outside open Campfire precondition")
	await _bind(visit)
	_check(panel.is_visible_in_tree() and panel.heal_button.has_focus(),
		"open Campfire starts focused for comparison")
	external.grab_focus()
	await _settle()
	var owner := root.gui_get_focus_owner()
	_check(external.has_focus() and owner == external and not panel.is_ancestor_of(owner),
		"external enabled control truly owns GUI focus")
	# Probe the same guarded global stream, then restore it for the end guard.
	seed(266)
	var expected_focus_draw := randi()
	seed(266)
	for key in [KEY_1, KEY_2, KEY_KP_1, KEY_KP_2, KEY_0, KEY_KP_0]:
		await _press(key)
		var label := "focus-outside key " + str(key)
		_check(intents.is_empty(), label + ": no decision signal")
		_check(visit.read_state() == saved and not panel._submitted,
			label + ": no Campfire state change")
		_check(not panel.heal_button.disabled and not panel.leave_button.disabled,
			label + ": both Campfire actions stay available")
		_check(external.has_focus() and root.gui_get_focus_owner() == external,
			label + ": external focus retained")
	_check(randi() == expected_focus_draw, "focus-outside number keys draw no global RNG")
	seed(266)
	external.queue_free()
	await _settle()
	_check(visit.read_state() == saved and intents.is_empty(),
		"removing the external control commits nothing")


func _focused_shortcuts() -> void:
	for fixture in [
		{"action": "heal", "key": KEY_1, "focus": "heal"},
		{"action": "heal", "key": KEY_KP_1, "focus": "heal"},
		{"action": "leave", "key": KEY_2, "focus": "leave"},
		{"action": "leave", "key": KEY_KP_2, "focus": "leave"},
		{"action": "leave", "key": KEY_0, "focus": "leave"},
		{"action": "leave", "key": KEY_KP_0, "focus": "leave"},
	]:
		await _focused_shortcut(fixture["focus"], fixture["key"], fixture["action"])
	# Either Campfire control owns the shortcuts, not only its own action.
	await _focused_shortcut("leave", KEY_1, "heal")
	await _focused_shortcut("heal", KEY_2, "leave")
	# 0 is Leave on either focused control and never invokes Heal.
	await _focused_shortcut("heal", KEY_0, "leave")
	await _focused_shortcut("heal", KEY_KP_0, "leave")


## The focused Campfire still accepts each number key exactly once with an
## authentic source-bound intent, settled by the independent service oracle.
func _focused_shortcut(focus_role: String, key: Key, action: String) -> void:
	var label := "focused %s shortcut %s -> %s" % [focus_role, key, action]
	var source_fixture := _party([35, 18, 0])
	var visit := RunCampfireVisit.new(NODE, source_fixture)
	var saved := visit.read_state()
	_check(saved.get("ok") == true and saved.get("status") == "open"
		and saved.get("heroes", []).size() == 3, label + ": real open visit precondition")
	await _bind(visit)
	var target: Button = panel.heal_button if focus_role == "heal" else panel.leave_button
	target.grab_focus()
	await _settle()
	_check(target.has_focus() and root.gui_get_focus_owner() == target
		and panel.is_ancestor_of(target), label + ": Campfire control owns GUI focus")
	var count := intents.size()
	await _press(key)
	_check(intents.size() == count + 1, label + ": exactly one intent from one key press")
	if intents.size() != count + 1:
		return
	var intent: Dictionary = intents[-1]
	_check(intent.get("action") == action and intent.get("node_id") == NODE
		and intent.get("source_visit") == visit
		and intent.get("expected_heroes") == saved.heroes,
		label + ": authentic bound instance/node/full roster intent")
	_check(visit.read_state() == saved and panel._submitted,
		label + ": view submits once without committing the service")
	await _press(key)
	_check(intents.size() == count + 1 and visit.read_state() == saved,
		label + ": repeated or released key is inert")
	var oracle: Dictionary = RunRestRecovery.new(saved.heroes).choose_heal()
	var expected: Array = saved.heroes.duplicate(true)
	if action == "heal":
		for i in range(3):
			expected[i]["hp"] = _recovered_hp(saved.heroes[i])
		_check(int(saved.heroes[2]["hp"]) == 0
			and int(expected[2]["hp"]) == 1 + _heal_amount(saved.heroes[2]),
			label + ": torn hero revives to 1 HP before floor(30%) is added")
		_check(int(saved.heroes[0]["hp"]) + _heal_amount(saved.heroes[0])
			> int(saved.heroes[0]["max_hp"])
			and int(expected[0]["hp"]) == int(saved.heroes[0]["max_hp"]),
			label + ": healing is capped at max HP")
		for i in range(3):
			_check(int(oracle.heroes[i]["hp"]) == int(expected[i]["hp"]),
				label + ": independent recovery oracle matches hero " + str(i))
	var result := Controller.submit(visit, intent)
	_check(result.get("ok") == true and result.get("decision") == action
		and result.get("node_id") == NODE, label + ": route owner accepts the receipt once")
	_check(result.get("heroes") == (oracle.heroes if action == "heal" else saved.heroes)
		and visit.read_state().heroes == expected,
		label + ": heal equals independent recovery / Leave changes no hero field")
	_check(visit.read_state().status
		== (RunCampfireVisit.HEALED if action == "heal" else RunCampfireVisit.LEFT),
		label + ": real service consumed exactly once")
	_check(not Controller.submit(visit, intent).get("ok"), label + ": replayed intent rejected")


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
		await _check_key_rejected(visit, KEY_0, "modified leave key " + str(modifier_key), false, modifier_key)
	
	# Echo/release/unrelated keys must be inert.
	for k in [KEY_1, KEY_2, KEY_KP_1, KEY_KP_2, KEY_0, KEY_KP_0]:
		await _check_key_rejected(visit, k, "pressed echo key " + str(k), true)
		await _check_key_rejected(visit, k, "released key " + str(k), false, KEY_NONE, false)
		
	await _check_key_rejected(visit, KEY_3, "unrelated key KEY_3")
	
	# Invalid/consumed bindings
	var invalid_visit := RunCampfireVisit.new("  ", _party([35, 18, 0]))
	await _bind(invalid_visit)
	await _check_key_rejected(invalid_visit, KEY_1, "invalid visit")
	await _check_key_rejected(invalid_visit, KEY_0, "invalid visit 0")
	await _check_key_rejected(invalid_visit, KEY_KP_0, "invalid visit keypad 0")
	
	var consumed := RunCampfireVisit.new(NODE, _party([35, 18, 0]))
	consumed.leave(consumed.read_state().node_id, consumed.read_state().heroes)
	await _bind(consumed)
	await _check_key_rejected(consumed, KEY_1, "consumed visit")
	await _check_key_rejected(consumed, KEY_0, "consumed visit 0")
	await _check_key_rejected(consumed, KEY_KP_0, "consumed visit keypad 0")
	
	# Hidden panel
	await _bind(visit)
	panel.hide()
	await _check_key_rejected(visit, KEY_1, "hidden panel")
	await _check_key_rejected(visit, KEY_0, "hidden panel 0")
	await _check_key_rejected(visit, KEY_KP_0, "hidden panel keypad 0")
	panel.show()
	await _settle()
	
	# Detached panel
	root.remove_child(panel)
	await _check_key_rejected(visit, KEY_1, "detached panel")
	await _check_key_rejected(visit, KEY_0, "detached panel 0")
	await _check_key_rejected(visit, KEY_KP_0, "detached panel keypad 0")
	root.add_child(panel)
	await _settle()
	
	# Button disabled
	panel.heal_button.disabled = true
	await _check_key_rejected(visit, KEY_1, "disabled button")
	panel.heal_button.disabled = false
	panel.leave_button.grab_focus()
	_check(panel.leave_button.has_focus(), "leave-shortcut negative owns Campfire focus")
	panel.leave_button.disabled = true
	await _check_key_rejected(visit, KEY_0, "disabled leave button 0")
	await _check_key_rejected(visit, KEY_KP_0, "disabled leave button keypad 0")
	await _check_key_rejected(visit, KEY_2, "disabled leave button alias 2")
	await _check_key_rejected(visit, KEY_KP_2, "disabled leave button alias keypad 2")
	panel.leave_button.disabled = false
	
	# Source snapshot / node drift
	var before_drift := visit.read_state()
	visit._heroes[1]["statuses"]["bleed"]["stacks"] = 999
	await _check_key_rejected(visit, KEY_1, "source roster drift")
	await _check_key_rejected(visit, KEY_0, "source roster drift 0")
	visit._heroes = before_drift.heroes.duplicate(true)
	
	visit._node_id = "forged_node"
	await _check_key_rejected(visit, KEY_1, "source node drift")
	await _check_key_rejected(visit, KEY_0, "source node drift 0")
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
	await _check_key_rejected(visit, KEY_0, "already submitted visit 0")
	await _check_key_rejected(visit, KEY_KP_0, "already submitted visit keypad 0")
	await _check_key_rejected(visit, KEY_2, "already submitted visit alias 2")
	await _check_key_rejected(visit, KEY_KP_2, "already submitted visit alias keypad 2")
	
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
