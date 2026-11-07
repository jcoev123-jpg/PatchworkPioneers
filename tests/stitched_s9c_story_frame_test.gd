extends SceneTree
## S9c (design v4 section 9c): a seeded New Run opens on one picture of Wren with his dolls,
## the walk HUD reads his fear and its view flickers at 50+ (still under reduced motion),
## Wren speaks when a doll is lost and counts his four dolls when the mimic follows. With a
## real renderer it saves the intro and the scared walk to user://s9c_*.png.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)
		push_error(why)


func _shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for _frame in range(4):
		await process_frame
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png("user://s9c_%s.png" % label)


func _layers_dimmed(walker: StitchedWalkScreen) -> bool:
	return walker.stage.dim < 0.99


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var book := StitchedWrenLines.book()
	_check(not book.is_empty(), "wren_lines.json loads")
	_check(ResourceLoader.exists(str(book.intro.fallback), "Texture2D"), "the intro's fallback picture is installed")

	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = 42
	root.add_child(app)
	await process_frame
	app.start_button.pressed.emit()
	await process_frame
	app.stitched_run_buttons[0].pressed.emit()
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.phase == "map", "Set out starts the seeded run on its map")
	var intro: Control = app.stitched_run_intro
	_check(is_instance_valid(intro) and intro.get_parent() == app.stitched_run_panel, "New Run shows Wren's intro over the map")
	if not is_instance_valid(intro) or session == null:
		_finish(app)
		return
	var art: TextureRect = intro.get_node("WrenIntroArt")
	_check(art.texture != null and str(art.get_meta("art_path")) in [str(book.intro.picture), str(book.intro.fallback)],
		"the intro is one authored picture")
	_check(intro.mouse_filter == Control.MOUSE_FILTER_STOP, "the intro blocks clicks on the map beneath")
	var begin: Button = intro.find_child("WrenIntroBegin", true, false)
	_check(begin != null and begin.has_focus() and not begin in app.stitched_run_buttons,
		"Begin the night has focus and leaves the map's buttons in order")
	var heading: Label = intro.find_child("WrenIntroHeading", true, false)
	_check(heading != null and heading.text == str(book.intro.heading), "the intro names the night")
	var told := ""
	for label in intro.find_children("*", "Label", true, false):
		told += (label as Label).text
	_check(told.contains("Wren") and told.contains("four patchwork dolls"), "the intro tells of Wren and his four dolls")
	await _shot("intro")
	var choices := session.choices()
	begin.pressed.emit()
	await process_frame
	_check(app.stitched_run_intro == null and not is_instance_valid(intro), "Begin the night removes the intro")
	_check(session.choices() == choices and app.stitched_run_buttons[0].has_focus(), "the map is unchanged and takes focus")

	# The walk HUD reads the run's fear.
	var pick := -1
	for index in choices.size():
		if session.map.get_node(choices[index]).type != "Boss":
			pick = index
			break
	app.stitched_run_buttons[pick].pressed.emit()
	await process_frame
	var walker: StitchedWalkScreen = app.stitched_run_walk
	_check(walker != null and session.phase == "walk", "the first room opens the hosted walk")
	if walker == null:
		_finish(app)
		return
	_check(walker.fear() == session.kid_fear() and walker.readout.text.contains("WREN FEAR 0/100"), "the walk HUD reads fear 0")
	_check(not walker.flickering and not walker.is_processing(), "a calm walk does not flicker")
	# A doll lost earlier in the night (+15 each) raises his fear; the walk HUD follows.
	session._kid_fear.apply_observed_event({"kind": "lost"})
	session._seal()
	walker.refresh()
	_check(session.kid_fear() == 15 and walker.readout.text.contains("WREN FEAR 15/100"), "a fear change shows in the walk HUD")
	_check(not walker.flickering, "fear 15 does not flicker")
	for _loss in range(3):
		session._kid_fear.apply_observed_event({"kind": "lost"})
	session._seal()
	walker.refresh()
	_check(session.kid_fear() == 60 and walker.flickering and walker.is_processing(), "the walk view flickers at fear 60")
	var dimmed := false
	for _frame in range(40):
		await process_frame
		dimmed = dimmed or _layers_dimmed(walker)
	_check(dimmed, "the flicker dims the corridor pictures")
	await _shot("walk_fear60")
	walker.set_reduced_motion(true)
	_check(walker.flickering and not walker.is_processing() and not _layers_dimmed(walker),
		"reduced motion stills the flicker at full tone")
	walker.set_reduced_motion(false)
	_check(walker.is_processing(), "the flicker returns with motion")

	# One Doll Too Many: Wren counts his four dolls.
	_check(StitchedWrenLines.mimic().contains("four dolls"), "the mimic line says Wren owns four dolls")
	_check(StitchedWrenLines.mimic("glass").contains("seams") and StitchedWrenLines.mimic("ears").contains("breathing"),
		"eye profiles keep their clues in Wren's words")
	_finish(app)


func _finish(app: Node) -> void:
	app.free()
	# Wren speaks once when a doll is lost in a fight.
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(StitchedBattleScreen.read_preview()), "the preview fight opens")
	root.add_child(screen)
	var actor := screen.battle.current_actor_id()
	var victim: Dictionary = {}
	for hero in screen.battle.get_heroes():
		if str(hero.id) != actor and victim.is_empty():
			victim = hero
	screen.battle._units[str(victim.id)]["lost"] = true
	screen._commit(screen.battle.pass_turn())
	var line := StitchedWrenLines.doll_lost(str(victim.id), str(victim.name))
	_check(not line.is_empty() and line.contains(str(victim.name)), "Wren's loss line names the doll")
	_check(screen._notice.contains(line), "the battle log carries Wren's line when a doll is lost")
	screen._commit(screen.battle.pass_turn())
	_check(not screen._notice.contains(line), "Wren speaks once per lost doll")
	_check(StitchedWrenLines.doll_lost(str(victim.id), "X") == StitchedWrenLines.doll_lost(str(victim.id), "X"),
		"the same doll always draws the same line")
	screen.queue_free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("stitched_s9c_story_frame_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
