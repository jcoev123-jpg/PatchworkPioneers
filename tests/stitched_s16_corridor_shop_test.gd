extends SceneTree
## Owner 11-09: road stops are a first-person shop on the corridor floor; junction stops are
## only arrows; walking is the hallway or the Up/Down keys, never a WALK ON button.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	return key


func _run() -> void:
	var dolls := ["wren", "bram"]
	_check(StitchedCorridorVisit.group_of({"id": "mend", "arguments": ["wren", "head"]}, dolls) == ["mend", "wren"], "a mend is one thing, for a doll")
	_check(StitchedCorridorVisit.group_of({"id": "swap", "arguments": ["bram", 2, 1]}, dolls) == ["spare|1", "bram"], "a spare is one thing however it is sewn")
	_check(StitchedCorridorVisit.group_of({"id": "leave", "arguments": []}, dolls) == ["leave", ""], "leaving is for no doll")
	_check(StitchedCorridorVisit.group_of({"id": "unpick", "arguments": [3]}, dolls) == ["unpick|3", ""], "each spare to unpick is its own thing")

	var visit := StitchedCorridorVisit.new()
	root.add_child(visit)
	visit.present("floorboards", "bright", "Peddler", "A peddler waits.", ["stop_peddler"])
	var actions := [
		{"id": "buy_candle_stub", "text": "Candle stub / 5 gold", "arguments": [], "enabled": true},
		{"id": "bandage", "text": "Bandage Wren / 5 gold", "arguments": ["wren"], "enabled": true},
		{"id": "bandage", "text": "Bandage Bram / 5 gold", "arguments": ["bram"], "enabled": false},
		{"id": "mend", "text": "Wren / Mend head / 3 scraps", "arguments": ["wren", "head"], "enabled": true},
		{"id": "mend", "text": "Wren / Mend arms / 3 scraps", "arguments": ["wren", "arms"], "enabled": true},
		{"id": "leave", "text": "Leave Peddler", "arguments": [], "enabled": true},
	]
	var homes := visit.lay_out(actions, [{"id": "wren", "name": "Wren"}, {"id": "bram", "name": "Bram"}], ["", "", "", "", "", ""])
	_check(visit.groups.size() == 4 and homes.size() == actions.size(), "six choices lie as four things")
	_check(homes[0] == visit and homes[5] == visit, "a lone choice is made on the floor itself")
	_check(homes[1] != homes[2] and homes[1].get_parent() == homes[2].get_parent() and homes[3] == homes[4], "each doll has its own column in the thing's tray")
	_check(visit.groups[1].words == "Bandage · 5 gold" and visit.groups[2].words == "Mend · 3 scraps", "a thing says only what its choices share")
	_check(visit.groups[3].arrow and not visit.groups[0].arrow, "walking on is an arrow on the floor")
	var buttons: Array[Button] = []
	var pressed: Array = []
	for index in actions.size():
		var button := Button.new()
		button.text = actions[index].text
		button.disabled = not actions[index].enabled
		homes[index].add_child(button)
		button.pressed.connect(func(): pressed.append(index))
		buttons.append(button)
	visit.dress(buttons)
	var save := Button.new()
	save.text = "Save run"
	visit.add_child(save)
	visit.wire_focus([save])
	await process_frame
	await process_frame
	_check(visit.floor_buttons.size() == 4 and visit.floor_buttons[0] == buttons[0] and visit.floor_buttons[3] == buttons[5], "lone choices are their own floor buttons")
	_check(not buttons.has(visit.floor_buttons[1]) and not buttons.has(visit.floor_buttons[2]), "things with several choices open a tray instead")
	for index in buttons.size():
		_check(buttons[index].is_visible_in_tree() == (homes[index] == visit)
			and buttons[index].text == actions[index].text and visit.is_ancestor_of(buttons[index]),
			"only floor choices are visible before a tray is opened; all choices retain their text")
	for number in visit.groups.size():
		var figure: Sprite3D = visit.stage.figure_nodes.get("thing_%d" % number)
		_check(figure != null, "every thing lies in the corridor")
		var seen := visit.floor_buttons[number].get_rect()
		_check(seen.size.x >= 40 and Rect2(0, 0, 1280, 720).intersects(seen), "every floor button covers its thing on screen")
	_check(visit.floor_buttons[0].get_theme_stylebox("normal") is StyleBoxEmpty and visit.floor_buttons[0].get_theme_color("font_color").a == 0.0, "a floor button shows only the thing, never a framed label")
	_check(visit.floor_buttons[0].has_focus(), "the first thing on the floor has focus")
	visit.floor_buttons[0].mouse_entered.emit()
	_check(visit.story.text == "Candle stub · 5 gold", "the words show on the thing looked at")
	visit.floor_buttons[0].mouse_exited.emit()
	_check(visit.story.text == "A peddler waits.", "the stop's own words come back")
	var tray: Control = visit.trays[1]
	_check(not tray.visible and not buttons[1].is_visible_in_tree() and tray.modulate.a == 0.0
		and buttons[1].focus_mode == Control.FOCUS_NONE and buttons[1].mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"a closed tray is invisible, clear and deaf")
	visit.floor_buttons[1].pressed.emit()
	_check(visit.open_group == 1 and tray.visible and buttons[1].is_visible_in_tree()
		and tray.modulate.a == 1.0 and buttons[1].focus_mode == Control.FOCUS_ALL and buttons[1].has_focus(),
		"picking a thing up reveals its dolls and focuses the first that can take it")
	_check(tray.get_global_rect().position.y < 300 and buttons[1].get_node_or_null("Round") != null, "the dolls are round portraits along the top")
	_check(buttons[1].focus_next != NodePath() and save.focus_next != NodePath(), "the open tray joins the focus chain")
	visit.floor_buttons[2].pressed.emit()
	_check(visit.open_group == 2 and not tray.visible and not buttons[1].is_visible_in_tree()
		and tray.modulate.a == 0.0 and visit.trays[2].visible
		and buttons[3].is_visible_in_tree() and visit.trays[2].modulate.a == 1.0,
		"opening another thing hides the previous tray from visible choices")
	_check(buttons[3].position.y > 0.0 and buttons[3].size.x < StitchedCorridorVisit.ROUND, "a doll with several ways shows each way as a small round under its face")
	visit._input(_key(KEY_ESCAPE))
	_check(visit.open_group == -1 and not visit.trays[2].visible
		and not buttons[3].is_visible_in_tree() and visit.trays[2].modulate.a == 0.0
		and visit.floor_buttons[2].has_focus(), "Esc hides the tray and puts the thing back down")
	buttons[1].pressed.emit()
	visit._input(_key(KEY_UP))
	_check(pressed.has(5), "Up walks on by the arrow")
	# A leave arrow between two wares must leave a cursor gap on both sides,
	# even when the original clickable rectangles merely touch edge-to-edge.
	for candidate in visit.floor_buttons:
		candidate.position = Vector2(1050, 100)
	var left := visit.floor_buttons[0]
	var right := visit.floor_buttons[1]
	var arrow := visit.floor_buttons[3]
	left.position = Vector2(180, 420)
	left.size = Vector2(70, 110)
	right.position = Vector2(322, 420)
	right.size = Vector2(70, 110)
	arrow.position = Vector2(250, 390)
	arrow.size = Vector2(72, 115)
	visit._clear_arrow_overlap(arrow)
	_check(not arrow.get_rect().intersects(left.get_rect().grow(4.0))
		and not arrow.get_rect().intersects(right.get_rect().grow(4.0)),
		"leave arrow keeps a four-pixel gap from wares on both sides")
	_check(arrow.size.x >= 30.0 and arrow.size.y >= 30.0,
		"trimmed leave arrow stays clickable")
	# If the overlap eats the arrow's width, the usable part may be below
	# the ware instead. Do not leave the blocker over the whole hit target.
	right.position = Vector2(1050, 100)
	left.position = Vector2(220, 390)
	left.size = Vector2(100, 80)
	arrow.position = Vector2(250, 390)
	arrow.size = Vector2(72, 115)
	visit._clear_arrow_overlap(arrow)
	_check(not arrow.get_rect().intersects(left.get_rect().grow(4.0))
		and arrow.size.x >= 30.0 and arrow.size.y >= 30.0,
		"deep arrow overlap uses a vertical clearance when a horizontal trim cannot fit")
	# Two wares can each leave one tempting cut, yet only their shared
	# upper-left gap fits a full cursor. A greedy trim must not miss it.
	left.position = Vector2(250, 430)
	left.size = Vector2(50, 60)
	right.position = Vector2(310, 390)
	right.size = Vector2(40, 100)
	arrow.position = Vector2(250, 390)
	arrow.size = Vector2(100, 100)
	visit._clear_arrow_overlap(arrow)
	_check(not arrow.get_rect().intersects(left.get_rect().grow(4.0))
		and not arrow.get_rect().intersects(right.get_rect().grow(4.0))
		and arrow.size.x >= 30.0 and arrow.size.y >= 30.0,
		"leave arrow retains a genuinely clear 30px target around multiple wares")
	visit.queue_free()

	# The junction tells only the way, never what waits down it.
	for side in ["left", "ahead", "right"]:
		var words := StitchedCorridorJunction.describe(side)
		for kind in ["Campfire", "Peddler", "Event", "Fight", "Elite", "Boss"]:
			_check(not words.to_lower().contains(kind.to_lower()), "a junction arrow never names its stop")

	# Walking is the hallway itself, or Up and Down.
	var walk := StitchedWalkScreen.new()
	_check(walk.begin(), "seeded walk starts")
	root.add_child(walk)
	await process_frame
	walk.set_reduced_motion(true)
	var before := walk.receipts.size()
	root.push_input(_key(KEY_UP))
	_check(walk.receipts.size() == before + 1 and walk.expected.step == 1, "Up walks one step on")
	root.push_input(_key(KEY_DOWN))
	_check(walk.receipts.size() == before + 2 and walk.expected.step == 1, "Down turns to look back without walking")
	walk.queue_free()
	await process_frame

	print("stitched_s16_corridor_shop_test: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	for failure in failures:
		print("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
