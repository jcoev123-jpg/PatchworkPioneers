extends SceneTree
## S9d: Wren's bedroom is the base. Object hotspots, the night record and the
## dolls' poses; windowed runs also save the night / after-win / after-loss shots.

const TEST_SAVE := "user://s9d_bedroom_test.json"
const SHOT := "user://s9d_bedroom_%s.png"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _ended(phase: String) -> StitchedRunSession:
	var session := StitchedRunSession.start(42)
	session.phase = phase
	if phase == "defeat":
		session.heroes[0].lost = true
		session.heroes[1].hp = 0
		session.heroes[2].fray = 120
		session.heroes[3].fray = 160
	return session


func _record_rules() -> void:
	var fresh := StitchedBedroomRecord.fresh()
	_check(StitchedBedroomRecord.valid(fresh), "first night record is valid")
	_check(StitchedBedroomRecord.after_run(fresh, StitchedRunSession.start(42)) == fresh,
		"a run still on the road does not end a night")
	var lost := StitchedBedroomRecord.after_run(fresh, _ended("defeat"))
	_check(lost.nights == 1 and lost.outcome == "defeat" and lost.dolls.size() == 4,
		"a lost run ends one night and remembers the four dolls")
	_check(lost.dolls.warden.lost and lost.dolls.seamstress.hanging and lost.dolls.tinker.fray == 120,
		"each doll keeps how it came home")
	var won := StitchedBedroomRecord.after_run(lost, _ended("victory"))
	_check(won.nights == 2 and won.outcome == "victory" and not won.dolls.warden.lost,
		"the next night replaces the last party")
	var broken := fresh.duplicate(true)
	broken.dolls = {"not_a_doll": {"fray": 0, "lost": false, "hanging": false}}
	_check(not StitchedBedroomRecord.valid(broken), "unknown dolls are refused")
	DirAccess.remove_absolute(TEST_SAVE)
	_check(StitchedBedroomRecord.load_file(TEST_SAVE) == fresh, "no file is a first night")
	_check(StitchedBedroomRecord.save_file(TEST_SAVE, lost) and StitchedBedroomRecord.load_file(TEST_SAVE) == lost,
		"the record survives a save and load")
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("{\"version\": 1, \"nights\": -3}")
	file.close()
	_check(StitchedBedroomRecord.load_file(TEST_SAVE) == fresh, "a broken file is a first night")
	DirAccess.remove_absolute(TEST_SAVE)


func _room_rules() -> void:
	var room := StitchedBedroom.new()
	root.add_child(room)
	room.size = Vector2(1280, 720)
	_check(room.backdrop.texture != null and room.backdrop.texture.resource_path == StitchedBedroom.NIGHT_ART,
		"the first night shows the night picture")
	for id in StitchedBedroom.SPOTS:
		var spot := room.spot(id)
		_check(spot != null and spot.focus_mode == Control.FOCUS_ALL
			and Rect2(spot.position, spot.size) == StitchedBedroom.SPOTS[id], "hotspot over the " + id)
		var lifted := spot.get_theme_stylebox("hover") as StyleBoxTexture
		_check(lifted != null and lifted.texture is AtlasTexture
			and (lifted.texture as AtlasTexture).atlas == room.backdrop.texture
			and lifted.expand_margin_left > 0.0 and lifted.modulate_color.v > 1.0,
			"hover lifts and brightens the %s from the picture itself" % id)
		_check(spot.get_theme_stylebox("normal") is StyleBoxEmpty, "the %s rests in the picture" % id)
		_check((room.labels[id].text == spot.text or id == "window") and not room.labels[id].text.is_empty(),
			"pinned label on the " + id)
	for id in StitchedPartyAdmission.HERO_IDS:
		_check(room.doll_pose(id) == "upright" and room.dolls[id].texture != null
			and Rect2(StitchedBedroom.SPOTS.shelf).grow(8).encloses(Rect2(room.dolls[id].position, room.dolls[id].size)),
			"%s stands on the shelf" % id)
	var ledger := room.inspector
	_check(ledger != null and ledger.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and ledger.focus_mode == Control.FOCUS_NONE, "the last-outing inspector cannot steal mouse or focus")
	_check(ledger.PANEL_RECT.position.x > StitchedBedroom.SPOTS.door.end.x
		and ledger.PANEL_RECT.end.x < StitchedBedroom.SPOTS.candle.position.x
		and ledger.PANEL_RECT.position.y > StitchedBedroom.SPOTS.drawings.end.y,
		"the image-backed readout clears the entrance and active room objects")
	_check(ledger.get_node("FeltPanel") is NinePatchRect
		and (ledger.get_node("FeltPanel") as NinePatchRect).texture != null,
		"readout is backed by authored felt, not painted geometry")
	room.spot("shelf").mouse_entered.emit()
	_check(ledger.visible and ledger.heading.text == "LAST OUTING"
		and ledger.entry_order.size() == StitchedPartyAdmission.HERO_IDS.size(),
		"fresh shelf shows a last-outing entry for every doll")
	for index in range(StitchedPartyAdmission.HERO_IDS.size()):
		var id: String = StitchedPartyAdmission.HERO_IDS[index]
		_check(ledger.entry_order[index] == id and ledger.name_labels.has(id)
			and ledger.status_labels[id].text == "NOT YET GONE OUT"
			and not ledger.status_labels[id].text.contains("FRAY"),
			"first night gives %s a named no-history entry without invented Fray" % id)
	room.spot("shelf").mouse_exited.emit()
	_check(not ledger.visible, "shelf hover departure dismisses the readout")
	room.spot("tin").focus_entered.emit()
	_check(ledger.visible and ledger.entry_order.is_empty()
		and ledger.empty_label.text == "No outing has ended yet",
		"tin explains first night with no fabricated lost dolls")
	room.spot("tin").focus_exited.emit()
	_check(not ledger.visible, "leaving keyboard focus dismisses the tin readout")
	var no_outcome := StitchedBedroomRecord.fresh()
	no_outcome.nights = 2
	_check(StitchedBedroomRecord.valid(no_outcome), "no-outcome record remains a valid empty history")
	room.present(no_outcome)
	room.spot("tin").mouse_entered.emit()
	_check(ledger.empty_label.text == "No outing has ended yet",
		"no recorded outcome never invents a lost doll")
	room.spot("tin").mouse_exited.emit()
	room.spot("shelf").focus_entered.emit()
	_check(ledger.status_labels.warden.text == "NOT YET GONE OUT",
		"no recorded outcome cannot fabricate a played doll")
	room.spot("shelf").focus_exited.emit()
	var narrow := room.door_light_width()
	var record := StitchedBedroomRecord.after_run(StitchedBedroomRecord.fresh(), _ended("defeat"))
	record.deepest = 9
	room.present(record)
	_check(room.door_light_width() > narrow and room.door_light.size.x == room.door_light_width(),
		"the light under the door widens with the deepest floor")
	_check(room.labels.window.text == "Night 2", "the moon counts the nights")
	_check(room.backdrop.texture.resource_path == StitchedBedroom.NIGHT_ART, "a loss stays night")
	_check(room.doll_pose("warden") == "tin" and Rect2(StitchedBedroom.SPOTS.tin).grow(40).has_point(room.dolls.warden.position),
		"a lost doll lies in pieces in the tin")
	_check(room.doll_pose("seamstress") == "side" and is_equal_approx(absf(room.dolls.seamstress.rotation), PI * 0.5),
		"a hanging doll lies on its side")
	_check(room.doll_pose("tinker") == "slumped" and room.dolls.tinker.rotation != 0.0, "fray 100+ slumps")
	_check(room.doll_pose("lantern_monk") == "wall" and room.dolls.lantern_monk.flip_h, "deep fray faces the wall")
	_check(room.doll_pose("scarecrow") == "upright", "dolls that stayed home stand")
	room.spot("shelf").focus_entered.emit()
	_check(ledger.visible and ledger.entry_order.size() == StitchedPartyAdmission.HERO_IDS.size()
		and ledger.status_labels.warden.text == "LOST"
		and ledger.status_labels.seamstress.text == "HANGING BY A THREAD"
		and ledger.status_labels.tinker.text == "FRAY 120/200\nSLUMPED"
		and ledger.status_labels.lantern_monk.text == "FRAY 160/200\nFACING WALL",
		"defeat shelf shows LOST/HANGING and both exact fray/posture bands")
	for id in ["rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]:
		_check(ledger.status_labels[id].text == "STAYED HOME"
			and not ledger.status_labels[id].text.contains("FRAY"),
			"nonparticipant %s stayed home without a fabricated condition" % id)
	room.spot("shelf").focus_exited.emit()
	room.spot("tin").mouse_entered.emit()
	_check(ledger.visible and ledger.entry_order == ["warden"]
		and ledger.status_labels.warden.text == "LOST"
		and not ledger.status_labels.has("seamstress"),
		"tin shows only dolls actually lost; hanging does not count")
	record = StitchedBedroomRecord.after_run(record, _ended("victory"))
	room.present(record)
	_check(room.is_morning() and room.backdrop.texture.resource_path == StitchedBedroom.MORNING_ART,
		"morning light after a win")
	var lifted := room.spot("door").get_theme_stylebox("hover") as StyleBoxTexture
	_check((lifted.texture as AtlasTexture).atlas == room.backdrop.texture, "morning hover crops the morning picture")
	_check(not ledger.visible and ledger.entry_order.is_empty(),
		"present() dismisses stale hover and old entries before reuse")
	room.spot("tin").mouse_entered.emit()
	_check(ledger.entry_order.is_empty()
		and ledger.empty_label.text == "No dolls lost on the last outing",
		"victory updates tin to no last-outing losses")
	room.spot("tin").mouse_exited.emit()
	room.spot("shelf").mouse_entered.emit()
	_check(ledger.status_labels.warden.text == "FRAY 0/200"
		and ledger.status_labels.tinker.text == "FRAY 0/200"
		and not ledger.status_labels.warden.text.contains("LOST")
		and room.doll_pose("warden") == "upright", "victory replaces defeat rather than retaining injuries")
	room.spot("shelf").mouse_exited.emit()
	room.spot("shelf").grab_focus()
	var another_loss := StitchedBedroomRecord.after_run(record, _ended("defeat"))
	room.present(another_loss)
	_check(room.spot("shelf").has_focus() and ledger.visible
		and ledger.status_labels.warden.text == "LOST",
		"re-presenting while shelf keeps keyboard focus refreshes to the latest loss")
	room.present(record)
	_check(ledger.visible and ledger.status_labels.warden.text == "FRAY 0/200",
		"re-presenting another last night replaces loss without an extra focus event")
	room.spot("shelf").release_focus()
	room.present(StitchedBedroomRecord.fresh())
	_check(not ledger.visible and room.backdrop.texture.resource_path == StitchedBedroom.NIGHT_ART
		and room.labels.window.text == "Night 1", "fresh present resets both inspection and night picture")
	room.spot("tin").focus_entered.emit()
	_check(ledger.empty_label.text == "No outing has ended yet" and ledger.entry_order.is_empty(),
		"reset tin never reuses the former loss")
	room.spot("tin").focus_exited.emit()
	room.spot("shelf").focus_entered.emit()
	_check(ledger.status_labels.warden.text == "NOT YET GONE OUT"
		and ledger.status_labels.button_golem.text == "NOT YET GONE OUT",
		"reset shelf has no old fray history")
	room.hide()
	_check(not ledger.visible, "hidden bedroom suppresses its readout")
	room.show()
	_check(not ledger.visible, "reshowing bedroom never resurrects stale focus content")
	room.free()


func _live_base(app: Node) -> void:
	app.base_button.pressed.emit()
	await process_frame
	var view: BaseScreen = app.base_screen
	_check(is_instance_valid(view) and view.has_open_village() and view.bedroom != null,
		"the base opens as Wren's room")
	if view == null or view.bedroom == null:
		return
	var room := view.bedroom
	_check(room.spot("door") == view.set_out_button and room.spot("drawings") == view.guide_button
		and room.spot("tin") == view.parts_button, "door, drawings and tin are the base's own actions")
	_check(view.set_out_button.text == "Set out" and root.gui_get_focus_owner() == view.set_out_button,
		"the door is focused and still says Set out")
	for panel in [view.path_panel, view.tinker_panel, view.warden_panel, view.heroes_house_button, view.camp_house_button]:
		_check(not panel.visible, "card-era village board hidden: " + panel.name)
	var loop := {}
	var at: Control = view.set_out_button
	for step in range(12):
		loop[at] = true
		at = at.get_node(at.focus_next) as Control
	for id in ["shelf", "door", "drawings", "window", "tin"]:
		_check(loop.has(room.spot(id)), "keyboard reaches the " + id)
	_check(not view._difficulty_row.visible, "tonight's darkness waits behind the window")
	room.spot("shelf").grab_focus()
	await process_frame
	_check(root.gui_get_focus_owner() == room.spot("shelf") and room.inspector.visible
		and room.inspector.entry_order.size() == StitchedPartyAdmission.HERO_IDS.size()
		and room.inspector.status_labels.warden.text == "NOT YET GONE OUT",
		"mounted shelf keyboard focus exposes the complete first-night ledger")
	room.spot("tin").grab_focus()
	await process_frame
	_check(root.gui_get_focus_owner() == room.spot("tin") and room.inspector.visible
		and room.inspector.empty_label.text == "No outing has ended yet",
		"mounted tin keyboard focus shows no-history explanation")
	room.spot("shelf").mouse_entered.emit()
	_check(room.inspector.status_labels.has("button_golem")
		and room.inspector.visible, "mounted mouse hover shows the same shelf ledger")
	room.spot("shelf").mouse_exited.emit()
	_check(room.inspector.visible and room.inspector.empty_label.text == "No outing has ended yet",
		"departing shelf hover returns to the focused tin readout")
	room.spot("tin").pressed.emit()
	await process_frame
	_check(view.field_guide.is_open(), "mounted sewing tin still opens its existing part path")
	view.field_guide.close_requested.emit()
	await process_frame
	room.spot("window").pressed.emit()
	_check(view._difficulty_row.visible, "the window opens how dark tonight is")
	room.spot("drawings").pressed.emit()
	_check(view.field_guide.is_open(), "the drawings open the field guide")
	view.field_guide.close_requested.emit()
	await process_frame
	room.spot("shelf").grab_focus()
	await process_frame
	await _shot("night")
	room.spot("shelf").pressed.emit()
	await process_frame
	_check(app.stitched_run_panel != null and not view.visible, "the shelf leads to choosing four dolls")
	app.stitched_run_buttons[0].pressed.emit()
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and not is_instance_valid(app.base_screen), "the door opens onto a run")
	if session == null:
		return
	session.phase = "victory"
	session._seal()
	app._present_stitched_run()
	await process_frame
	_check(app.bedroom_record.nights == 1 and app.bedroom_record.outcome == "victory", "the won night is counted once")
	app._present_stitched_run()
	_check(app.bedroom_record.nights == 1, "redrawing the end page does not count again")
	var back: Button = null
	for button in app.stitched_run_buttons:
		if button.text == "Back to Wren's room":
			back = button
	_check(back != null, "the end of a run leads back to the room")
	if back == null:
		return
	back.pressed.emit()
	await process_frame
	view = app.base_screen
	_check(is_instance_valid(view) and view.has_open_village() and view.bedroom.is_morning(),
		"after a win the room is in morning light")
	view.bedroom.spot("tin").grab_focus()
	await process_frame
	_check(view.bedroom.inspector.visible
		and view.bedroom.inspector.empty_label.text == "No dolls lost on the last outing",
		"mounted victory tin reports no losses after the actual return")
	view.bedroom.spot("shelf").grab_focus()
	await process_frame
	_check(view.bedroom.inspector.status_labels.warden.text == "FRAY 0/200",
		"mounted victory shelf reads the current last-outing record")
	await _shot("after_win")
	view.back_button.pressed.emit()
	await process_frame
	app.bedroom_record = StitchedBedroomRecord.after_run(app.bedroom_record, _ended("defeat"))
	app.base_button.pressed.emit()
	await process_frame
	view = app.base_screen
	_check(is_instance_valid(view) and not view.bedroom.is_morning()
		and view.bedroom.doll_pose("warden") == "tin", "after a loss a doll lies in the tin")
	view.bedroom.spot("tin").grab_focus()
	await process_frame
	_check(view.bedroom.inspector.visible
		and view.bedroom.inspector.entry_order == ["warden"]
		and view.bedroom.inspector.status_labels.warden.text == "LOST",
		"mounted loss tin reveals the actual lost doll by keyboard")
	view.bedroom.spot("shelf").mouse_entered.emit()
	_check(view.bedroom.inspector.status_labels.tinker.text == "FRAY 120/200\nSLUMPED"
		and view.bedroom.inspector.status_labels.lantern_monk.text == "FRAY 160/200\nFACING WALL",
		"mounted loss shelf hover reveals the full correct aftermath")
	await _shot("after_loss")


func _shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SHOT % label)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_check(StitchedBedroom.has_art(), "both bedroom pictures are installed")
	_record_rules()
	_room_rules()
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.run_seed = 42
	app.stitched_walks = false
	app.bedroom_save_path = ""
	root.add_child(app)
	await process_frame
	await process_frame
	await _live_base(app)
	app.queue_free()
	await process_frame
	if failures.is_empty():
		print("stitched_s9d_bedroom_test: PASS (%d checks)" % checks)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		print("stitched_s9d_bedroom_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
