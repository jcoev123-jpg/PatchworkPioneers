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
	_check(visit.floor_buttons[0].get_theme_stylebox("normal") is StyleBoxEmpty and visit.floor_buttons[0].get_theme_color("font_color").a == 0.0, "a floor button has no framed text of its own")
	_check(visit.floor_buttons[0].get_node("WareName").text == "Candle stub"
		and visit.floor_buttons[1].get_node("WareName").text == "Bandage"
		and visit.floor_buttons[2].get_node("WareName").text == "Mend"
		and visit.floor_buttons[3].get_node_or_null("WareName") == null,
		"floor labels name each ware without a visible price or an extra exit label")
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

	# A crowded Peddler places the later wares deeper into the corridor. Their
	# labels must clear the bodies of the larger wares in the foreground.
	var crowded := StitchedCorridorVisit.new()
	root.add_child(crowded)
	crowded.present("floorboards", "bright", "Peddler", "A crowded stall.", ["stop_peddler"])
	var ware_actions: Array = []
	for id in ["buy_candle_stub", "bandage", "buy_patch", "buy_pins", "buy_thimble_tonic",
			"buy_fresh_stuffing", "buy_dye", "buy_starch", "buy_spare_spool"]:
		ware_actions.append({"id": id, "text": id.replace("_", " "), "arguments": [], "enabled": true})
	var ware_homes := crowded.lay_out(ware_actions, [], ["", "", "", "", "", "", "", "", ""])
	var ware_buttons: Array[Button] = []
	for index in ware_actions.size():
		var ware := Button.new()
		ware.text = ware_actions[index].text
		ware_homes[index].add_child(ware)
		ware_buttons.append(ware)
	crowded.dress(ware_buttons)
	await process_frame
	await process_frame
	var front_midpoint := INF
	for index in range(5):
		var bounds := crowded.stage.screen_rect("thing_%d" % index)
		front_midpoint = minf(front_midpoint, bounds.get_center().y)
	for index in range(5, crowded.groups.size()):
		var tag := crowded.floor_buttons[index].get_node("WareName") as Label
		_check(tag != null and tag.get_global_rect().end.y < front_midpoint - 8.0,
			"second-row Peddler labels stay above foreground wares (item %d)" % index)
		if str(crowded.groups[index].key) == "buy_fresh_stuffing":
			_check(tag.position.y <= crowded.floor_buttons[index].size.y - 18.0,
				"Peddler Fresh stuffing caption clears the front-row patch frame without moving its ware")
		if str(crowded.groups[index].key) == "buy_spare_spool":
			_check(is_equal_approx(tag.position.x, -6.0),
				"Peddler's spare spool caption has extra clearance from the exit arrow")
	crowded.queue_free()

	# Fresh stuffing needs extra caption clearance only from the rear row.
	# A sparse Peddler may put that same ware in front, where it stays put.
	var sparse := StitchedCorridorVisit.new()
	root.add_child(sparse)
	sparse.present("floorboards", "bright", "Peddler", "Few wares remain.", ["stop_peddler"])
	var sparse_actions := [{"id": "buy_fresh_stuffing", "text": "Fresh stuffing / 10 gold", "arguments": [], "enabled": true},
		{"id": "leave", "text": "Leave Peddler", "arguments": [], "enabled": true}]
	var sparse_homes := sparse.lay_out(sparse_actions, [], ["", ""])
	var sparse_buttons: Array[Button] = []
	for index in sparse_actions.size():
		var button := Button.new()
		button.text = str(sparse_actions[index].text)
		sparse_homes[index].add_child(button)
		sparse_buttons.append(button)
	sparse.dress(sparse_buttons)
	await process_frame
	await process_frame
	var sparse_caption := sparse.floor_buttons[0].get_node("WareName") as Label
	_check(is_equal_approx(sparse_caption.position.y, sparse.floor_buttons[0].size.y - 6.0),
		"front-row Fresh stuffing keeps the standard caption height")
	sparse.queue_free()

	# A deep Peddler has distinct offers for the same ware. The keyed offers
	# still need the spool offset, but unreadable captions must not pile up.
	var dense := StitchedCorridorVisit.new()
	root.add_child(dense)
	dense.present("floorboards", "bright", "Peddler", "Many spools for sale.", ["stop_peddler"])
	var dense_actions: Array = []
	var dense_pictures: Array = []
	for index in range(18):
		dense_actions.append({"id": "buy_spare_spool", "text": "Spare spool / 10 gold",
			"arguments": [index], "enabled": true})
		dense_pictures.append("")
	dense_actions.append({"id": "leave", "text": "Leave Peddler", "arguments": [], "enabled": true})
	dense_pictures.append("")
	var dense_homes := dense.lay_out(dense_actions, [], dense_pictures)
	var dense_buttons: Array[Button] = []
	for index in dense_actions.size():
		var button := Button.new()
		button.text = dense_actions[index].text
		dense_homes[index].add_child(button)
		dense_buttons.append(button)
	dense.dress(dense_buttons)
	await process_frame
	await process_frame
	_check(dense.groups.size() == 19, "individually keyed spool offers remain separately clickable")
	var shown_captions: Array[Rect2] = []
	var shown_count := 0
	for index in range(18):
		var tag := dense.floor_buttons[index].get_node("WareName") as Label
		_check(str(dense.groups[index].key) == "buy_spare_spool|%d" % index
			and is_equal_approx(tag.position.x, -6.0),
			"individually keyed spool %d keeps the exit-arrow clearance" % index)
		if tag.visible:
			shown_count += 1
			var bounds := dense._caption_text_bounds(tag)
			for previous in shown_captions:
				_check(not previous.grow(2.0).intersects(bounds),
					"dense Peddler captions do not paint over each other (item %d)" % index)
			shown_captions.append(bounds)
	_check(shown_count > 0 and shown_count < 18,
		"crowded captions thin out without hiding every name")
	dense.floor_buttons[12].mouse_entered.emit()
	_check(dense.story.text == "Spare spool · 10 gold"
		and dense.floor_buttons[12].visible and not dense.floor_buttons[12].disabled,
		"a thinned caption still has a clickable ware and readable hover details")
	dense.queue_free()

	# A lost doll's disabled purchase variants must not project duplicate wares
	# onto the floor, while unavailable stock for living dolls remains inspectable.
	var orphaned := StitchedCorridorVisit.new()
	root.add_child(orphaned)
	orphaned.present("floorboards", "bright", "Peddler", "A peddler waits.", ["stop_peddler"])
	var orphaned_actions := [
		{"id": "buy_patch", "text": "Scrap Lined Vest / 20 gold", "arguments": ["scrap_lined_vest", "warden", 0], "enabled": true},
		{"id": "buy_patch", "text": "Scrap Lined Vest / Seamstress / button 1 / 20 gold", "arguments": ["scrap_lined_vest", "seamstress", 0], "enabled": false},
		{"id": "buy_patch", "text": "Scrap Lined Vest / Seamstress / button 2 / 20 gold", "arguments": ["scrap_lined_vest", "seamstress", 1], "enabled": false},
		{"id": "buy_pins", "text": "Pins / 10 gold", "arguments": ["warden"], "enabled": true},
		{"id": "buy_pins", "text": "Pins / Seamstress / 10 gold", "arguments": ["seamstress"], "enabled": false},
		{"id": "buy_candle_stub", "text": "Candle stub / 10 gold", "arguments": [], "enabled": false},
		{"id": "leave", "text": "Leave Peddler", "arguments": [], "enabled": true},
	]
	var orphaned_homes := orphaned.lay_out(orphaned_actions, [{"id": "warden", "name": "Warden"}],
		["", "", "", "", "", "", ""])
	var orphaned_buttons: Array[Button] = []
	for index in orphaned_actions.size():
		var button := Button.new()
		button.text = str(orphaned_actions[index].text)
		button.disabled = not bool(orphaned_actions[index].enabled)
		orphaned_homes[index].add_child(button)
		orphaned_buttons.append(button)
	orphaned.dress(orphaned_buttons)
	await process_frame
	await process_frame
	_check(orphaned.groups.size() == 4 and orphaned.floor_buttons.size() == 4
		and orphaned._homes.size() == orphaned_actions.size(),
		"lost-doll purchase choices share wares instead of adding ghost floor items")
	_check(orphaned.groups[0].actions == [0, 1, 2] and orphaned.groups[1].actions == [3, 4],
		"all living and lost doll choices stay grouped with their matching ware")
	for number in orphaned.floor_buttons.size():
		_check(orphaned.floor_buttons[number].visible
			and orphaned.stage.figure_nodes.has("thing_%d" % number),
			"one visible floor item per actual Peddler ware (%d)" % number)
	for index in [1, 2, 4]:
		var disabled_choice := orphaned_buttons[index]
		_check(disabled_choice.visible and disabled_choice.disabled
			and orphaned._homes[index] == disabled_choice.get_parent()
			and not disabled_choice.is_visible_in_tree(),
			"lost-doll choice %d remains an unavailable, closed-tray control" % index)
		orphaned.reveal(disabled_choice)
		_check(disabled_choice.is_visible_in_tree() and disabled_choice.disabled,
			"lost-doll choice %d can still be inspected after opening its shared ware" % index)
		orphaned.close_tray()
	_check(orphaned.floor_buttons[2].visible and orphaned.floor_buttons[2].disabled,
		"ordinary unavailable stock remains visible and inspectable")
	orphaned.queue_free()

	# Event exits must use the floor arrow even if their prose talks about coins,
	# or has no navigation word (album, fortune, observatory). Unaffordable
	# event trades should not leave a dead object on the floor.
	var event := StitchedCorridorVisit.new()
	root.add_child(event)
	event.present("floorboards", "bright", "The Moss Garden", "Roses bloom.", ["stop_event"])
	var event_actions := [
		{"id": "gather_garden_trim", "text": "Collect rose hems", "arguments": [], "enabled": true},
		{"id": "sell_rose_ribbon", "text": "Trade a scrap for coins", "arguments": [], "enabled": false},
		{"id": "leave_garden", "text": "Close the moss gate", "arguments": [], "enabled": true},
		{"id": "leave", "text": "Fold the giant album shut", "arguments": [], "enabled": true},
	]
	var event_homes := event.lay_out(event_actions, [], ["", "", "", ""])
	var event_buttons: Array[Button] = []
	for index in event_actions.size():
		var button := Button.new()
		button.text = event_actions[index].text
		button.disabled = not event_actions[index].enabled
		event_homes[index].add_child(button)
		event_buttons.append(button)
	event.dress(event_buttons)
	var arrow_art := StitchedCorridorStage.art("floor_arrow")
	_check(event.groups[2].arrow and event.groups[3].arrow
		and event.groups[2].art == arrow_art and event.groups[3].art == arrow_art,
		"all event exits are arrows, irrespective of their wording or unrelated object words")
	_check(not event.groups[1].available and not event_buttons[1].visible
		and not event.stage.figure_nodes.has("thing_1")
		and event.stage.figure_nodes.has("thing_0"),
		"an unaffordable event trade has neither a clickable control nor a dead coin pile")
	_check(event._is_arrow("leave_stars", "Close the observatory hatch")
		and event._is_arrow("watch_sails", "Watch the sails turn and leave")
		and event._is_arrow("pass_by", "Wave the caravan onward")
		and event._is_arrow("walk_round_gate", "Walk around the silent gate")
		and event._is_arrow("decline_trade", "Decline the trade")
		and not event._is_arrow("watch_bell", "Watch the cold bell (gain 17 gold)")
		and not event._is_arrow("turn_button_clock", "Turn the button clock for gold")
		and not event._is_arrow("gather_garden_trim", "Collect rose hems"),
		"scanned no-cost event exits are arrows without classifying rewarded actions as exits")
	_check(event._group_art({"actions": [0]},
		[{"id": "pass_by", "text": "Wave the caravan onward"}], [""]) == arrow_art,
		"an exit with no navigation words on its label uses arrow artwork, not a parcel")
	# The Moonpatch Archway's long purchase text used to wrap into the
	# bottom story; the floor tag must reserve both its lines above it.
	event.groups[0].words = "Purchase two spools (spend 15 gold; gain 2 scraps)"
	event._place_items()
	var long_tag := event.floor_buttons[0].get_node_or_null("WareName") as Label
	_check(long_tag != null and event.floor_buttons[0].position.y + long_tag.position.y
		+ long_tag.size.y <= StitchedCorridorVisit.STORY_RECT.position.y - 4.0,
		"long event floor labels stay wholly above the story (%s, %s; story top %s)" % [event.floor_buttons[0].position, long_tag.get_rect() if long_tag != null else Rect2(), StitchedCorridorVisit.STORY_RECT.position.y])
	event.queue_free()

	# The right-hand choice in a two-offer Event can have a long label.
	# It must stay left of the corner route map, not paint over its rooms.
	var two_offers := StitchedCorridorVisit.new()
	root.add_child(two_offers)
	two_offers.present("floorboards", "bright", "The Clockwork Teacup Parade", "Teacups march.", ["stop_event"])
	var offer_actions := [
		{"id": "collect_thread", "text": "Collect the spilled glowing thread (+2 scraps)", "arguments": [], "enabled": true},
		{"id": "polish_joints", "text": "Polish the parade's spoon joints (spend 2 scraps; gain 25 gold)", "arguments": [], "enabled": false},
	]
	var offer_homes := two_offers.lay_out(offer_actions, [], ["", ""])
	var offer_buttons: Array[Button] = []
	for offer in offer_actions.size():
		var choice := Button.new()
		choice.text = offer_actions[offer].text
		choice.disabled = not offer_actions[offer].enabled
		offer_homes[offer].add_child(choice)
		offer_buttons.append(choice)
	two_offers.dress(offer_buttons)
	await process_frame
	await process_frame
	var right_tag := two_offers.floor_buttons[1].get_node("WareName") as Label
	var left_tag := two_offers.floor_buttons[0].get_node("WareName") as Label
	_check(right_tag != null and right_tag.position.x < -24.0
		and right_tag.get_global_rect().end.x <= 998.0
		and not right_tag.get_global_rect().intersects(left_tag.get_global_rect())
		and right_tag.get_global_rect().end.y <= StitchedCorridorVisit.STORY_RECT.position.y - 4.0,
		"right-hand Event choice stays clear of route map, companion choice and bottom story (right %s, left %s, y %s)" % [right_tag.get_global_rect(), left_tag.get_global_rect(), StitchedCorridorVisit.STORY_RECT.position.y])
	_check(offer_buttons[1].text == offer_actions[1].text,
		"moving the long floor caption preserves its full choice text")
	_check(right_tag.modulate == StitchedCorridorVisit.DIM and left_tag.modulate == Color.WHITE,
		"unaffordable event choices have dim captions, while reachable choices stay fully lit")
	_check(left_tag.text == "Collect the spilled glowing thread"
		and right_tag.text == "Polish the parade's spoon joints"
		and left_tag.get_theme_font_size("font_size") == 17
		and right_tag.get_theme_font_size("font_size") == 17,
		"event floor captions use legible action names; prices remain in the full buttons")
	_check(right_tag.size.x >= 290.0 and left_tag.size.x >= 290.0
		and offer_buttons[0].text == offer_actions[0].text,
		"readable event caption width leaves quoted costs on the buttons")
	two_offers.queue_free()

	# Needle Gate's cost-free 'pass' is the exit arrow, not a third
	# floor ware squeezed into the same caption lane as its two trades.
	var needle_gate := StitchedCorridorVisit.new()
	root.add_child(needle_gate)
	needle_gate.present("floorboards", "bright", "The Needle Gate", "Crossed needles.", ["stop_event"])
	var gate_actions := [
		{"id": "examine", "text": "Spend 1 scrap to unpick the gate and claim 12 gold", "arguments": [], "enabled": false},
		{"id": "pass", "text": "Pass without stopping", "arguments": [], "enabled": true},
		{"id": "cut_bindings", "text": "Cut the binding threads (spend 2 scraps; gain 28 gold)", "arguments": [], "enabled": false},
	]
	var gate_homes := needle_gate.lay_out(gate_actions, [], ["", "", ""])
	var gate_buttons: Array[Button] = []
	for index in gate_actions.size():
		var button := Button.new()
		button.text = gate_actions[index].text
		button.disabled = not gate_actions[index].enabled
		gate_homes[index].add_child(button)
		gate_buttons.append(button)
	needle_gate.dress(gate_buttons)
	await process_frame
	await process_frame
	var gate_left := needle_gate.floor_buttons[0].get_node("WareName") as Label
	var gate_right := needle_gate.floor_buttons[2].get_node("WareName") as Label
	_check(needle_gate.groups[1].arrow and needle_gate.floor_buttons[1].get_node_or_null("WareName") == null
		and gate_buttons[1].text == "Pass without stopping",
		"Needle Gate's no-cost pass is a real exit arrow with its original accessible action")
	_check(not gate_left.get_global_rect().intersects(gate_right.get_global_rect())
		and gate_right.get_global_rect().end.x <= 750.0,
		"Needle Gate's two trade captions do not overlap each other or the map")
	needle_gate.queue_free()

	# Empty Moth visits quote disabled sacrifices and fumigation.Those controls
	# must stay on the mounted page across Save/Reload and title Continue, unlike
	# the Garden's no-scraps coin pile.
	var moth := StitchedCorridorVisit.new()
	root.add_child(moth)
	moth.present("floorboards", "bright", "Moth Infestation", "Moths stir.", ["prop_moth_infestation", "stop_event"])
	var moth_actions := [
		{"id": "sacrifice_part", "text": "Feed a spare part to the moths", "arguments": [0], "enabled": false},
		{"id": "fumigate", "text": "Fumigate the satchel (spend 1 scrap)", "arguments": [], "enabled": false},
		{"id": "escape", "text": "Escape before the moths spread", "arguments": [], "enabled": true},
	]
	var moth_homes := moth.lay_out(moth_actions, [], ["", "", ""])
	var moth_buttons: Array[Button] = []
	for index in moth_actions.size():
		var choice := Button.new()
		choice.text = moth_actions[index].text
		choice.disabled = not moth_actions[index].enabled
		moth_homes[index].add_child(choice)
		moth_buttons.append(choice)
	moth.dress(moth_buttons)
	_check(moth_buttons.all(func(button): return button.is_visible_in_tree()),
		"empty Moth retains every quoted control, including disabled choices")
	_check(moth_buttons[0].disabled and moth_buttons[1].disabled and not moth_buttons[2].disabled,
		"empty Moth preserves the refusal states of both unaffordable choices")
	_check(moth.stage.figure_nodes.has("thing_0") and moth.stage.figure_nodes.has("thing_1")
		and moth.stage.figure_nodes.has("thing_2"),
		"empty Moth displays the disabled options and its escape floor arrow")
	_check(moth.groups[2].arrow and moth.groups[2].art == arrow_art,
		"the Moth's cost-free escape uses the departure arrow, not a parcel")
	var escaped := []
	moth_buttons[2].pressed.connect(func(): escaped.append(true))
	moth._input(_key(KEY_UP))
	_check(escaped.size() == 1, "Up activates the Moth's exit, even when the other choices are disabled")
	moth.queue_free()

	# An undrawn named event prop must borrow a matching figure rather than the
	# unrelated generic keeper. The authored prop wins once it is imported.
	var parade := StitchedCorridorVisit.new()
	root.add_child(parade)
	parade.present("walls", "bright", "The Cinder Shield Parade", "A guard braces a shield.",
		["prop_v3_warden_cinder_shield_parade", "stop_event"])
	var parade_art := StitchedCorridorStage.art("prop_v3_warden_cinder_shield_parade")
	var parade_expected := parade_art if parade_art != null else StitchedCorridorStage.hero_art("warden")
	_check(parade_expected != null and parade._keeper == parade_expected,
		"the cinder parade uses its authored prop or a pot-helmeted Warden, never the hooded keeper")
	parade.queue_free()

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
