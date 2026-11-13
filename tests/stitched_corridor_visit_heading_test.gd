extends SceneTree
## Visit and event headings share the Walk's left-aligned title rail.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures.append(reason)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var page := StitchedCorridorVisit.new()
	root.add_child(page)
	await process_frame
	_check(page.heading != null, "visit screen creates a heading")
	if page.heading != null:
		_check(is_equal_approx(page.heading.position.x, 28.0), "event title starts at the Walk's x=28 rail")
		_check(page.heading.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "event and stop titles read from left to right")
		_check(page.heading.position.x + page.heading.size.x <= 1280.0, "long stop titles stay within the screen")
	var greeting := "A thimble of wax burns low. The dolls can rest, talk, or trade places."
	page.present("floorboards", "bright", "Campfire", greeting)
	var leave := {"id": "leave", "text": "Leave", "arguments": [], "enabled": true}
	page.lay_out([leave], [], [""])
	_check(page.story.text.contains("nothing to do here but walk on"), "fresh Campfire does not promise unavailable recovery")
	page._say("Leave")
	page._say("")
	_check(page.story.text.contains("nothing to do here but walk on"), "Campfire returns to the honest caption after hover")
	page.present("floorboards", "bright", "Campfire", greeting)
	page.lay_out([leave, {"id": "trim_the_wick", "text": "Trim the wick", "arguments": [], "enabled": true}], [], ["", ""])
	_check(page.story.text == greeting, "Campfire with actual recovery keeps the original choice greeting")
	var unpicker_greeting := "A thin figure with a seam ripper offers to unpick what the dark has sewn in."
	page.present("floorboards", "bright", "Unpicker", unpicker_greeting)
	page.lay_out([leave], [], [""])
	_check(page.story.text.contains("nothing here to unpick"), "empty Unpicker does not promise unavailable work")
	page._say("Leave")
	page._say("")
	_check(page.story.text.contains("nothing here to unpick"), "Unpicker restores honest caption after hover")
	page.present("floorboards", "bright", "Unpicker", unpicker_greeting)
	page.lay_out([leave, {"id": "unpick", "text": "Unpick a seam", "arguments": [], "enabled": true}], [], ["", ""])
	_check(page.story.text == unpicker_greeting, "Unpicker with actual work keeps original story")
	# A named event's dedicated illustration wins when supplied; until then the
	# Choir displays the Seamstress with her needle, not the unrelated hooded keeper.
	page.present("floorboards", "bright", "The Crimson Shadow Choir", "A glove-puppet chorus.",
		["prop_v3_seamstress_crimson_shadow_choir", "stop_event"])
	var choir_art := StitchedCorridorStage.art("prop_v3_seamstress_crimson_shadow_choir")
	var expected_art := choir_art if choir_art != null else StitchedCorridorStage.hero_art("seamstress")
	_check(page._keeper != null and expected_art != null
		and page._keeper.resource_path == expected_art.resource_path,
		"Choir prefers its own art and otherwise uses the Seamstress, never an unrelated event keeper")
	page.present("floorboards", "bright", "Unknown Event", "A stranger waits.",
		["prop_event_that_has_no_specific_picture", "stop_event"])
	_check(page._keeper != null and page._keeper.resource_path == StitchedCorridorStage.art("stop_event").resource_path,
		"other events still use the standard event keeper when no dedicated picture exists")
	# Trade floor art must picture what the choice awards, not what the player pays.
	var coins := StitchedCorridorStage.art("item_coins")
	var bundles := StitchedCorridorStage.art("item_bundle")
	if coins != null and bundles != null:
		var buy := [{"id": "buy_thread", "text": "Buy thread (spend 13 gold; gain 2 scraps)"}]
		var sell := [{"id": "sell_buttons", "text": "Sell buttons (spend 1 scrap; gain 18 gold)"}]
		_check(page._group_art({"actions": [0]}, buy, [""]) == bundles,
			"gold paid for scraps places the earned bundle on the corridor floor")
		_check(page._group_art({"actions": [0]}, sell, [""]) == coins,
			"scraps paid for gold places the earned coins on the corridor floor")
		var spine_thread := [{"id": "buy_spine_thread",
			"text": "Pay 19 gold for three bundles of spine thread (+3 scraps)"}]
		_check(page._group_art({"actions": [0]}, spine_thread, [""]) == bundles,
			"parenthesized scrap reward places earned bundles, not spent gold, on the floor")
	# A long Unsew signature belongs in hover detail, never over the story footer.
	var unsew_page := StitchedCorridorVisit.new()
	root.add_child(unsew_page)
	await process_frame
	unsew_page.present("floorboards", "bright", "Sewing Circle", "A ring of old needles waits.")
	var unsew_actions := [
		{"id": "unsew", "text": "Warden / Unsew Red Lint from Pot Helm Command",
			"arguments": ["warden", "warden_head_pot_helm_command"], "enabled": true},
		{"id": "leave", "text": "Leave Sewing Circle", "arguments": [], "enabled": true},
	]
	var unsew_homes := unsew_page.lay_out(unsew_actions, [{"id": "warden", "name": "Warden"}], ["", ""])
	var unsew_buttons: Array[Button] = []
	for action_index in unsew_actions.size():
		var choice := Button.new()
		choice.text = str(unsew_actions[action_index].text)
		unsew_homes[action_index].add_child(choice)
		unsew_buttons.append(choice)
	unsew_page.dress(unsew_buttons)
	await process_frame
	var unsew_tag := unsew_page.floor_buttons[0].get_node_or_null("WareName") as Label
	_check(unsew_tag != null and unsew_tag.text == "Unsew Red Lint",
		"unsew floor caption names the patch without wrapping the whole signature")
	_check(unsew_tag != null and unsew_tag.get_global_rect().end.y <= StitchedCorridorVisit.STORY_RECT.position.y - 4.0,
		"unsew floor caption clears the bottom stop story")
	unsew_page._look(0, true)
	_check(unsew_page.story.text.contains("Pot Helm Command"),
		"unsew full signature remains readable on item hover")
	unsew_page.queue_free()
	# A crowded Sewing Circle keeps floor wares clickable without stacking
	# unreadable recruitment and patch captions across the middle of the screen.
	var crowded := StitchedCorridorVisit.new()
	root.add_child(crowded)
	await process_frame
	crowded.present("floorboards", "bright", "Sewing Circle", "A ring of old needles waits.")
	var offers: Array = []
	var pictures: Array = []
	for index in 12:
		offers.append({"id": "sew", "text": "Sew long patch %d onto a signature" % index,
			"arguments": [index], "enabled": true})
		pictures.append("")
	var homes: Array = crowded.lay_out(offers, [], pictures)
	var choices: Array[Button] = []
	for index in offers.size():
		var choice := Button.new()
		choice.text = str(offers[index].text)
		homes[index].add_child(choice)
		choices.append(choice)
	crowded.dress(choices)
	await process_frame
	var caption_bounds: Array[Rect2] = []
	var hidden_captions := 0
	for number in crowded.floor_buttons.size():
		var floor_button: Button = crowded.floor_buttons[number]
		var caption := floor_button.get_node_or_null("WareName") as Label
		if caption == null:
			continue
		if not caption.visible:
			hidden_captions += 1
			crowded._look(number, true)
			_check(crowded.story.text.contains("Sew long patch"),
				"a hidden caption retains its full hover/focus description")
			continue
		var bounds: Rect2 = crowded._caption_text_bounds(caption)
		for prior in caption_bounds:
			_check(not prior.grow(2.0).intersects(bounds),
				"crowded Sewing Circle shows no overlapping captions")
		caption_bounds.append(bounds)
	_check(hidden_captions > 0 and caption_bounds.size() > 1,
		"crowded Sewing Circle thins names but keeps several captions visible")
	_check(choices.size() == 12 and crowded.floor_buttons.size() == 12
		and choices.all(func(choice): return is_instance_valid(choice)),
		"thinning captions leaves every Sewing Circle action present")
	crowded.queue_free()
	page.queue_free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("stitched_corridor_visit_heading_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
