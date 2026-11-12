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


func _mouse_move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	root.push_input(event, true)
	await process_frame


## Real GUI action events, not direct focus traversal or synthetic button presses.
func _key(key: Key, shifted: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.shift_pressed = shifted
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _count_hotspot_press(counter: Dictionary, id: String) -> void:
	counter[id] = int(counter.get(id, 0)) + 1


## Compare both independent overlays with the ended record, not the doll pose.
## Existing instances must survive all presentations; no third child may stack.
func _check_marks(room: StitchedBedroom, instances: Dictionary, expected: Dictionary, stage: String) -> void:
	for id in StitchedPartyAdmission.HERO_IDS:
		var portrait: TextureRect = room.dolls[id]
		var arm: TextureRect = room.torn_marks.get(id)
		var leg: TextureRect = room.leg_torn_marks.get(id)
		var slots: Array = expected.get(id, [])
		var actual: Array = room.record.get("dolls", {}).get(id, {}).get("torn_slots", [])
		_check(actual == slots, "%s: %s actual recorded slots match the fixture" % [stage, id])
		if arm == null or leg == null:
			_check(false, "%s: %s has both overlays" % [stage, id])
			continue
		_check(arm.visible == ("arms" in slots) and leg.visible == ("legs" in slots),
			"%s: %s shows only its recorded arm and leg tears" % [stage, id])
		_check(arm.get_parent() == portrait and leg.get_parent() == portrait
			and arm != leg and portrait.get_child_count() == 2,
			"%s: %s owns exactly two distinct reusable marks" % [stage, id])
		_check(arm.texture != null and leg.texture != null
			and arm.texture.resource_path == StitchedBedroom.TORN_ART
			and leg.texture.resource_path == StitchedBedroom.TORN_ART,
			"%s: %s reuses the existing authored frayed cloth" % [stage, id])
		_check(arm.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and leg.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and arm.focus_mode == Control.FOCUS_NONE and leg.focus_mode == Control.FOCUS_NONE,
			"%s: %s marks cannot intercept clicks or focus" % [stage, id])
		_check(Rect2(Vector2.ZERO, portrait.size).encloses(Rect2(arm.position, arm.size))
			and Rect2(Vector2.ZERO, portrait.size).encloses(Rect2(leg.position, leg.size))
			and arm.position != leg.position and arm.size.x > 0.0 and leg.size.x > 0.0,
			"%s: %s arm and leg cloth stay separate inside its local portrait" % [stage, id])
		if instances.has(id):
			_check(arm.get_instance_id() == instances[id]["arms"]
				and leg.get_instance_id() == instances[id]["legs"],
				"%s: %s mark identities survive repeated presentations" % [stage, id])


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
	var unfinished := StitchedRunSession.start(42)
	unfinished.heroes[0].parts.arms.torn = true
	_check(StitchedBedroomRecord.after_run(fresh, unfinished) == fresh,
		"a run still on the road does not end a night even with a torn arm")
	var lost := StitchedBedroomRecord.after_run(fresh, _ended("defeat"))
	_check(lost.nights == 1 and lost.outcome == "defeat" and lost.dolls.size() == 4,
		"a lost run ends one night and remembers the four dolls")
	_check(lost.dolls.warden.lost and lost.dolls.seamstress.hanging and lost.dolls.tinker.fray == 120,
		"each doll keeps how it came home")
	var won := StitchedBedroomRecord.after_run(lost, _ended("victory"))
	_check(won.nights == 2 and won.outcome == "victory" and not won.dolls.warden.lost,
		"the next night replaces the last party")
	var torn_session := StitchedRunSession.start(42)
	_check(torn_session.heroes.size() == StitchedPartyAdmission.RANK_COUNT
		and str(torn_session.heroes[0].id) == "warden"
		and str(torn_session.heroes[1].id) == "seamstress"
		and str(torn_session.heroes[2].id) == "tinker",
		"seeded outing contains the actual first four participating dolls")
	for hero in torn_session.heroes:
		_check(int(hero.hp) > 0 and hero.parts.has("arms") and hero.parts.has("legs"),
			"worn limbs exist on a positive-HP outing participant")
	torn_session.heroes[0].parts.arms.torn = true
	torn_session.heroes[1].parts.legs.torn = true
	torn_session.heroes[2].parts.arms.torn = true
	torn_session.heroes[2].parts.legs.torn = true
	torn_session.heroes[0].fray = 177
	torn_session.phase = "victory"
	var torn_record := StitchedBedroomRecord.after_run(fresh, torn_session)
	_check(torn_record.nights == 1 and torn_record.outcome == "victory"
		and torn_record.deepest == clampi(torn_session.map.get_current_floor(), 0, StitchedBedroomRecord.FLOORS)
		and torn_record.dolls.size() == torn_session.heroes.size()
		and torn_record.dolls.warden.fray == 177,
		"one completed torn night preserves outcome, depth, fray and real participants")
	_check(torn_record.dolls.warden.get("torn_slots", []) == ["arms"]
		and torn_record.dolls.seamstress.get("torn_slots", []) == ["legs"]
		and torn_record.dolls.tinker.get("torn_slots", []) == ["arms", "legs"]
		and not torn_record.dolls.lantern_monk.has("torn_slots")
		and not torn_record.dolls.has("scarecrow"),
		"actual worn tears are captured in stable slot order; intact/stayed home stay intact")
	var detached := StitchedBedroomRecord.after_run(torn_record, StitchedRunSession.start(42))
	_check(detached == torn_record and detached.nights == 1,
		"unfinished next outing neither counts nor changes torn history")
	detached.dolls.warden.torn_slots.clear()
	_check(torn_record.dolls.warden.torn_slots == ["arms"],
		"returning an unchanged history still deep-copies recorded tears")
	torn_session.heroes[0].parts.arms.torn = false
	_check(torn_record.dolls.warden.torn_slots == ["arms"],
		"source run mutations cannot rewrite a completed last outing")
	# Zero HP is HANGING, not LOST; real worn tears must survive the record.
	var hanging_session := StitchedRunSession.start(42)
	for hero in hanging_session.heroes:
		_check(int(hero.hp) > 0 and not hero.lost, "hanging fixture starts with living participants")
		hero.hp = 0
	hanging_session.heroes[0].parts.arms.torn = true
	hanging_session.heroes[0].fray = 170
	hanging_session.heroes[1].parts.legs.torn = true
	hanging_session.heroes[1].fray = 110
	hanging_session.heroes[2].parts.arms.torn = true
	hanging_session.heroes[2].parts.legs.torn = true
	hanging_session.phase = "defeat"
	var hanging_record := StitchedBedroomRecord.after_run(fresh, hanging_session)
	_check(hanging_record.dolls.size() == StitchedPartyAdmission.RANK_COUNT
		and hanging_record.dolls.warden.hanging and not hanging_record.dolls.warden.lost
		and hanging_record.dolls.warden.torn_slots == ["arms"]
		and hanging_record.dolls.seamstress.torn_slots == ["legs"]
		and hanging_record.dolls.tinker.torn_slots == ["arms", "legs"]
		and hanging_record.dolls.lantern_monk.hanging
		and not hanging_record.dolls.lantern_monk.has("torn_slots"),
		"actual zero-HP but non-LOST heroes record all hanging tear combinations")
	_check(StitchedBedroomDollInspector.status_for(hanging_record, "warden")
		== "HANGING BY A THREAD\nTORN ARM"
		and StitchedBedroomDollInspector.status_for(hanging_record, "seamstress")
		== "HANGING BY A THREAD\nTORN LEG"
		and StitchedBedroomDollInspector.status_for(hanging_record, "tinker")
		== "HANGING BY A THREAD\nTORN ARM, LEG"
		and StitchedBedroomDollInspector.status_for(hanging_record, "lantern_monk")
		== "HANGING BY A THREAD",
		"real hanging survivors retain both the HANGING and their exact recorded limb labels")
	var broken := fresh.duplicate(true)
	broken.dolls = {"not_a_doll": {"fray": 0, "lost": false, "hanging": false}}
	_check(not StitchedBedroomRecord.valid(broken), "unknown dolls are refused")
	DirAccess.remove_absolute(TEST_SAVE)
	_check(StitchedBedroomRecord.load_file(TEST_SAVE) == fresh, "no file is a first night")
	_check(StitchedBedroomRecord.save_file(TEST_SAVE, lost) and StitchedBedroomRecord.load_file(TEST_SAVE) == lost,
		"the record survives a save and load")
	_check(StitchedBedroomRecord.save_file(TEST_SAVE, torn_record)
		and StitchedBedroomRecord.load_file(TEST_SAVE) == torn_record,
		"the same v1 save/load round trip preserves all three torn-slot combinations")
	var legacy := lost.duplicate(true)
	_check(StitchedBedroomRecord.valid(legacy) and not legacy.dolls.tinker.has("torn_slots"),
		"older v1 aftermath has no optional tear field")
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_check(StitchedBedroomRecord.load_file(TEST_SAVE) == legacy,
		"legacy v1 JSON without torn_slots loads with all its old conditions intact")
	for malformed in [["torso"], ["head"], ["arms", "arms"], [42], ["legs", false], "arms", 42]:
		var invalid := torn_record.duplicate(true)
		invalid.dolls.warden["torn_slots"] = malformed
		_check(not StitchedBedroomRecord.valid(invalid)
			and not StitchedBedroomRecord.save_file(TEST_SAVE, invalid),
			"unknown, repeated or malformed optional torn_slots fail closed: %s" % str(malformed))
		file = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
		file.store_string(JSON.stringify(invalid))
		file.close()
		_check(StitchedBedroomRecord.load_file(TEST_SAVE) == fresh,
			"tampered v1 JSON cannot load fabricated torn slots: %s" % str(malformed))
	var file_empty_slots := torn_record.duplicate(true)
	file_empty_slots.dolls.warden.torn_slots = []
	_check(StitchedBedroomRecord.valid(file_empty_slots),
		"optional empty tear list is valid and does not fabricate an injury")
	file = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(torn_record.duplicate(true).merged({"version": 20}, true)))
	file.close()
	_check(StitchedBedroomRecord.load_file(TEST_SAVE) == fresh,
		"incorrect bedroom record versions fail closed")
	file = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("not json!!")
	file.close()
	_check(StitchedBedroomRecord.load_file(TEST_SAVE) == fresh, "invalid JSON fails closed")
	file = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
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
		_check(room.labels[id].get_theme_font_size("font_size") >= 20
			and room.labels[id].get_theme_constant("outline_size") >= 4
			and room.labels[id].get_theme_color("font_outline_color").a > 0.0,
			"the %s caption remains legible on the painted room" % id)
	var mark_instances := {}
	for id in StitchedPartyAdmission.HERO_IDS:
		_check(room.doll_pose(id) == "upright" and room.dolls[id].texture != null
			and Rect2(StitchedBedroom.SPOTS.shelf).grow(8).encloses(Rect2(room.dolls[id].position, room.dolls[id].size)),
			"%s stands on the shelf" % id)
		var arm: TextureRect = room.torn_marks.get(id)
		var leg: TextureRect = room.leg_torn_marks.get(id)
		if arm != null and leg != null:
			mark_instances[id] = {"arms": arm.get_instance_id(), "legs": leg.get_instance_id()}
	_check_marks(room, mark_instances, {}, "first night")
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
	_check_marks(room, mark_instances, {}, "unfinished history")
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
	_check_marks(room, mark_instances, {}, "lost without torn slots")
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
		and ledger.status_labels.tinker.text == "SLUMPED"
		and ledger.status_labels.lantern_monk.text == "FACING WALL",
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
	# Surviving tears and high Fray share the same authored shelf readout.
	var torn_session := StitchedRunSession.start(42)
	torn_session.phase = "defeat"
	torn_session.heroes[0].parts.arms.torn = true
	torn_session.heroes[0].fray = 165
	torn_session.heroes[1].parts.legs.torn = true
	torn_session.heroes[2].parts.arms.torn = true
	torn_session.heroes[2].parts.legs.torn = true
	torn_session.heroes[3].fray = 110
	var torn_record := StitchedBedroomRecord.after_run(StitchedBedroomRecord.fresh(), torn_session)
	_check(StitchedBedroomRecord.valid(torn_record) and torn_record.dolls.warden.fray == 165
		and torn_record.dolls.warden.torn_slots == ["arms"]
		and not torn_record.dolls.warden.lost and not torn_record.dolls.warden.hanging
		and torn_record.dolls.lantern_monk.fray == 110,
		"completed actual torn/frayed survivor fixture has the intended living preconditions")
	_check(StitchedBedroomDollInspector.status_for(torn_record, "warden") == "TORN ARM\nFACING WALL"
		and StitchedBedroomDollInspector.status_for(torn_record, "seamstress") == "TORN LEG"
		and StitchedBedroomDollInspector.status_for(torn_record, "tinker") == "TORN ARM, LEG"
		and StitchedBedroomDollInspector.status_for(torn_record, "lantern_monk") == "SLUMPED"
		and StitchedBedroomDollInspector.status_for(torn_record, "scarecrow") == "STAYED HOME",
		"direct readout combines real Warden arm and deep Fray without mislabelling other dolls")
	room.present(torn_record)
	for id in ["warden", "seamstress", "tinker"]:
		_check(room.doll_pose(id) == "side"
			and room.dolls[id].texture != null
			and is_equal_approx(room.dolls[id].rotation, -PI * 0.5)
			and not room.dolls[id].flip_h
			and room.dolls[id].get_meta("pose") == "side",
			"surviving %s with real torn limb lies on its existing shelf portrait" % id)
	_check(room.doll_pose("lantern_monk") == "slumped"
		and room.doll_pose("scarecrow") == "upright",
		"intact frayed and never-selected dolls keep original shelf poses")
	var living_slots := {"warden": ["arms"], "seamstress": ["legs"], "tinker": ["arms", "legs"]}
	_check_marks(room, mark_instances, living_slots, "living limb tears")
	room.present(torn_record)
	room.present(torn_record)
	_check_marks(room, mark_instances, living_slots, "repeated living presentation")
	room.spot("shelf").focus_entered.emit()
	_check(ledger.visible and ledger.status_labels.warden.text == "TORN ARM\nFACING WALL"
		and ledger.status_labels.seamstress.text == "TORN LEG"
		and ledger.status_labels.tinker.text == "TORN ARM, LEG"
		and ledger.status_labels.lantern_monk.text == "SLUMPED"
		and ledger.status_labels.scarecrow.text == "STAYED HOME",
		"shelf keyboard readout preserves both Warden tear and deep Fray, other true injuries and intact Fray")
	room.spot("shelf").focus_exited.emit()
	room.spot("shelf").mouse_entered.emit()
	_check(ledger.visible and ledger.status_labels.warden.text == "TORN ARM\nFACING WALL"
		and ledger.status_labels.tinker.text == "TORN ARM, LEG"
		and ledger.status_labels.lantern_monk.text == "SLUMPED",
		"existing shelf hover presents the same qualitative injuries as focus")
	room.spot("shelf").mouse_exited.emit()
	room.spot("tin").focus_entered.emit()
	_check(ledger.entry_order.is_empty() and ledger.empty_label.text == "No dolls lost on the last outing",
		"a living torn survivor never appears in the tin")
	room.spot("tin").focus_exited.emit()
	# Vary only a real completed v1 aftermath, never the live run or scene rules.
	for band in [99, 100, 149, 150]:
		var boundary := torn_record.duplicate(true)
		boundary.dolls.warden.fray = band
		var cue := "TORN ARM" + ("\nFACING WALL" if band >= 150 else
			"\nSLUMPED" if band >= 100 else "")
		_check(StitchedBedroomRecord.valid(boundary)
			and boundary.dolls.warden.torn_slots == ["arms"]
			and StitchedBedroomDollInspector.status_for(boundary, "warden") == cue,
			"living arm-torn Warden Fray %d direct boundary cue is exact" % band)
		room.present(boundary)
		room.spot("shelf").focus_entered.emit()
		_check(ledger.status_labels.warden.text == cue
			and ledger.status_labels.tinker.text == "TORN ARM, LEG"
			and room.doll_pose("warden") == "side"
			and not ledger.status_labels.warden.text.contains("FRAY"),
			"living torn Warden Fray %d mounted focus keeps its exact tear and cue" % band)
		room.spot("shelf").focus_exited.emit()
		room.spot("shelf").mouse_entered.emit()
		_check(ledger.visible and ledger.status_labels.warden.text == cue,
			"living torn Warden Fray %d mounted hover agrees with focus" % band)
		room.spot("shelf").mouse_exited.emit()
	var untorn := torn_record.duplicate(true)
	untorn.dolls.warden.erase("torn_slots")
	_check(StitchedBedroomRecord.valid(untorn)
		and StitchedBedroomDollInspector.status_for(untorn, "warden") == "FACING WALL",
		"intact high-Fray Warden keeps its original unsupplemented posture label")
	room.present(untorn)
	room.spot("shelf").focus_entered.emit()
	_check(ledger.status_labels.warden.text == "FACING WALL"
		and room.doll_pose("warden") == "wall"
		and ledger.status_labels.tinker.text == "TORN ARM, LEG",
		"no-tear mounted comparison retains existing Fray and both real Tinker tears")
	room.spot("shelf").focus_exited.emit()
	room.present(torn_record)
	var outranked := torn_record.duplicate(true)
	outranked.dolls.warden.lost = true
	outranked.dolls.seamstress.hanging = true
	outranked.dolls.seamstress.fray = 170
	room.present(outranked)
	_check(room.doll_pose("warden") == "tin" and room.doll_pose("seamstress") == "side"
		and room.dolls.warden.get_meta("pose") == "tin",
		"LOST beats torn; HANGING keeps its side pose when also torn")
	room.spot("shelf").focus_entered.emit()
	_check(ledger.status_labels.warden.text == "LOST\nTORN ARM"
		and ledger.status_labels.seamstress.text == "HANGING BY A THREAD\nTORN LEG",
		"LOST retains its real torn arm; hanging preserves its recorded torn leg")
	_check_marks(room, mark_instances, living_slots, "arm-torn Warden in smaller LOST tin")
	room.spot("shelf").focus_exited.emit()
	room.spot("tin").mouse_entered.emit()
	_check(ledger.entry_order == ["warden"] and ledger.status_labels.warden.text == "LOST\nTORN ARM"
		and not ledger.status_labels.has("tinker"),
		"tin hover exposes Warden's real arm tear; living torn Tinker is not LOST")
	room.spot("tin").mouse_exited.emit()
	# Real participant parts -> after_run() -> bedroom -> both inspector hotspots:
	# losing a doll does not erase separately recorded arm/leg evidence.
	var lost_torn_session := StitchedRunSession.start(42)
	for hero in lost_torn_session.heroes:
		_check(int(hero.hp) > 0 and hero.parts.has("arms") and hero.parts.has("legs"),
			"real LOST tear fixtures begin with two actual worn limbs")
	lost_torn_session.heroes[0].lost = true
	lost_torn_session.heroes[0].parts.arms.torn = true
	lost_torn_session.heroes[1].lost = true
	lost_torn_session.heroes[1].parts.legs.torn = true
	lost_torn_session.heroes[2].lost = true
	lost_torn_session.heroes[2].parts.arms.torn = true
	lost_torn_session.heroes[2].parts.legs.torn = true
	lost_torn_session.phase = "defeat"
	var lost_torn_record := StitchedBedroomRecord.after_run(record, lost_torn_session)
	_check(lost_torn_record.dolls.warden.lost
		and lost_torn_record.dolls.warden.torn_slots == ["arms"]
		and lost_torn_record.dolls.seamstress.torn_slots == ["legs"]
		and lost_torn_record.dolls.tinker.torn_slots == ["arms", "legs"]
		and not lost_torn_record.dolls.lantern_monk.lost,
		"finished LOST session retains arm-only, leg-only and both-tear actual parts")
	room.present(lost_torn_record)
	var lost_slots := {"warden": ["arms"], "seamstress": ["legs"], "tinker": ["arms", "legs"]}
	_check_marks(room, mark_instances, lost_slots, "three smaller LOST tin dolls")
	for id in ["warden", "seamstress", "tinker"]:
		_check(room.doll_pose(id) == "tin" and room.dolls[id].size.y < StitchedBedroom.DOLL_HEIGHT,
			"real LOST %s takes the scaled tin portrait with authentic overlays" % id)
	room.spot("shelf").focus_entered.emit()
	_check(ledger.entry_order.size() == StitchedPartyAdmission.HERO_IDS.size()
		and ledger.status_labels.warden.text == "LOST\nTORN ARM"
		and ledger.status_labels.seamstress.text == "LOST\nTORN LEG"
		and ledger.status_labels.tinker.text == "LOST\nTORN ARM, LEG"
		and ledger.status_labels.lantern_monk.text == "UPRIGHT"
		and not ledger.status_labels.warden.text.contains("HEAD"),
		"all eight shelf statuses distinguish actual LOST torn slots without inventing a head tear")
	room.spot("shelf").focus_exited.emit()
	room.spot("tin").mouse_entered.emit()
	_check(ledger.entry_order == ["warden", "seamstress", "tinker"]
		and ledger.status_labels.warden.text == "LOST\nTORN ARM"
		and ledger.status_labels.seamstress.text == "LOST\nTORN LEG"
		and ledger.status_labels.tinker.text == "LOST\nTORN ARM, LEG"
		and not ledger.status_labels.has("lantern_monk"),
		"tin hover lists only genuinely LOST dolls with exactly their recorded injuries")
	room.spot("tin").mouse_exited.emit()
	room.present(lost_torn_record)
	room.present(lost_torn_record)
	_check_marks(room, mark_instances, lost_slots, "repeated LOST night keeps both marks stable")
	var malformed_history := lost_torn_record.duplicate(true)
	malformed_history.dolls.warden.torn_slots = ["head"]
	_check(not StitchedBedroomRecord.valid(malformed_history),
		"malformed recorded head tear is not an allowed limb slot")
	room.present(malformed_history)
	_check(room.record == StitchedBedroomRecord.fresh(),
		"invalid bedroom snapshots fall back to the clean first night")
	_check_marks(room, mark_instances, {}, "invalid torn slot must not leak from prior LOST")
	# A genuinely completed zero-HP outing must follow record -> room -> inspector,
	# not a manually synthesized hanging flag.
	var hanging_session := StitchedRunSession.start(42)
	for hero in hanging_session.heroes:
		hero.hp = 0
		hero.lost = false
	hanging_session.heroes[0].parts.arms.torn = true
	hanging_session.heroes[0].fray = 170
	hanging_session.heroes[1].parts.legs.torn = true
	hanging_session.heroes[1].fray = 110
	hanging_session.heroes[2].parts.arms.torn = true
	hanging_session.heroes[2].parts.legs.torn = true
	hanging_session.phase = "defeat"
	var hanging_record := StitchedBedroomRecord.after_run(record, hanging_session)
	room.present(hanging_record)
	room.spot("shelf").focus_entered.emit()
	_check(ledger.status_labels.warden.text == "HANGING BY A THREAD\nTORN ARM"
		and ledger.status_labels.seamstress.text == "HANGING BY A THREAD\nTORN LEG"
		and ledger.status_labels.tinker.text == "HANGING BY A THREAD\nTORN ARM, LEG"
		and ledger.status_labels.lantern_monk.text == "HANGING BY A THREAD"
		and hanging_record.dolls.warden.hanging and not hanging_record.dolls.warden.lost,
		"mounted shelf reports each real hanging tear without treating an untorn hanging doll as torn")
	_check_marks(room, mark_instances, living_slots, "real hanging limb tears")
	for id in StitchedPartyAdmission.HERO_IDS:
		_check(room.doll_pose(id) == ("side" if id in ["warden", "seamstress", "tinker", "lantern_monk"] else "upright"),
			"real hanging %s retains its side pose without entering the tin" % id)
	room.spot("shelf").focus_exited.emit()
	room.spot("tin").mouse_entered.emit()
	_check(ledger.entry_order.is_empty() and ledger.empty_label.text == "No dolls lost on the last outing",
		"genuine hanging-at-zero dolls still never enter LOST-only tin")
	room.spot("tin").mouse_exited.emit()
	var legacy := record.duplicate(true)
	_check(StitchedBedroomRecord.save_file(TEST_SAVE, legacy),
		"older v1 unmodified record saves through the bedroom file boundary")
	var loaded_legacy := StitchedBedroomRecord.load_file(TEST_SAVE)
	DirAccess.remove_absolute(TEST_SAVE)
	_check(loaded_legacy == legacy and not loaded_legacy.dolls.tinker.has("torn_slots"),
		"the legacy fixture reloads without inventing a missing tear")
	room.present(loaded_legacy)
	_check(room.doll_pose("tinker") == "slumped"
		and room.doll_pose("lantern_monk") == "wall",
		"legacy v1 record without optional tear keys retains old fray poses")
	_check_marks(room, mark_instances, {}, "legacy v1 has no tear keys")
	room.spot("shelf").mouse_entered.emit()
	_check(ledger.status_labels.tinker.text == "SLUMPED"
		and ledger.status_labels.lantern_monk.text == "FACING WALL",
		"legacy v1 shelf labels remain unchanged")
	room.spot("shelf").mouse_exited.emit()
	room.spot("tin").mouse_entered.emit()
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
	_check(ledger.status_labels.warden.text == "UPRIGHT"
		and ledger.status_labels.tinker.text == "UPRIGHT"
		and not ledger.status_labels.warden.text.contains("LOST")
		and room.doll_pose("warden") == "upright", "victory replaces defeat rather than retaining injuries")
	_check_marks(room, mark_instances, {}, "intact victory clears last night's torn and LOST overlays")
	room.spot("shelf").mouse_exited.emit()
	room.spot("shelf").grab_focus()
	var another_loss := StitchedBedroomRecord.after_run(record, _ended("defeat"))
	room.present(another_loss)
	_check(room.spot("shelf").has_focus() and ledger.visible
		and ledger.status_labels.warden.text == "LOST",
		"re-presenting while shelf keeps keyboard focus refreshes to the latest loss")
	room.present(record)
	_check(ledger.visible and ledger.status_labels.warden.text == "UPRIGHT",
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
	_check_marks(room, mark_instances, {}, "fresh re-presentation")
	# Both precise fray band thresholds remain physical poses and record data,
	# even though the felt inspector never prints a raw numerical Fray value.
	var bands_session := StitchedRunSession.start(42)
	for index in range(StitchedPartyAdmission.RANK_COUNT):
		bands_session.heroes[index].fray = [99, 100, 149, 150][index]
	bands_session.phase = "victory"
	var bands := StitchedBedroomRecord.after_run(StitchedBedroomRecord.fresh(), bands_session)
	room.present(bands)
	room.spot("shelf").mouse_entered.emit()
	for index in range(StitchedPartyAdmission.RANK_COUNT):
		var id: String = StitchedPartyAdmission.HERO_IDS[index]
		var expected_pose: String = ["upright", "slumped", "slumped", "wall"][index]
		var expected_label: String = ["UPRIGHT", "SLUMPED", "SLUMPED", "FACING WALL"][index]
		_check(bands.dolls[id].fray == [99, 100, 149, 150][index]
			and room.doll_pose(id) == expected_pose
			and ledger.status_labels[id].text == expected_label
			and not ledger.status_labels[id].text.contains("FRAY"),
			"exact 99/100/149/150 Fray thresholds preserve pose and qualitative label for %s" % id)
	room.spot("shelf").mouse_exited.emit()
	room.present(StitchedBedroomRecord.fresh())
	room.hide()
	_check(not ledger.visible, "hidden bedroom suppresses its readout")
	room.show()
	_check(not ledger.visible, "reshowing bedroom never resurrects stale focus content")
	room.free()


## Mounted App -> BaseScreen -> adopted Wren hotspots. Every arrow is a
## root-pushed key press/release; never a hand-set focus_neighbor traversal.
func _directional_base(view: BaseScreen, app: Node) -> void:
	var room := view.bedroom
	var record_before: Dictionary = app.bedroom_record.duplicate(true)
	var wallet_before: String = view.wallet_label.text
	var seed_before: int = app.run_seed
	var counts := {}
	for id in StitchedBedroom.SPOTS:
		var button := room.spot(id)
		counts[id] = 0
		_check(is_instance_valid(button) and button.get_parent() == room.room
			and button.is_visible_in_tree(), "live %s is the painted room control" % id)
		button.pressed.connect(_count_hotspot_press.bind(counts, id))
	var links := {
		"door": {"left": "shelf", "right": "drawings", "bottom": "tin"},
		"drawings": {"left": "door", "right": "window", "bottom": "candle"},
		"window": {"left": "drawings", "bottom": "candle"},
		"candle": {"top": "window", "left": "drawings"},
		"shelf": {"right": "door", "bottom": "tin"},
		"tin": {"top": "shelf", "right": "door"},
	}
	for id in links:
		var source: Button = room.spot(id)
		for direction in links[id]:
			var target: Button = room.spot(links[id][direction])
			var path: NodePath = source.get("focus_neighbor_" + direction)
			_check(not path.is_empty() and source.get_node_or_null(path) == target,
				"post-adoption %s %s reaches live %s" % [id, direction, links[id][direction]])
	_check(root.gui_get_focus_owner() == room.spot("door"), "real entry starts at the adopted door")

	var arrows := [
		[KEY_RIGHT, "drawings"], [KEY_RIGHT, "window"], [KEY_DOWN, "candle"],
		[KEY_UP, "window"], [KEY_LEFT, "drawings"], [KEY_LEFT, "door"],
		[KEY_LEFT, "shelf"], [KEY_DOWN, "tin"], [KEY_UP, "shelf"],
	]
	for next_step in arrows:
		await _key(next_step[0])
		var expected: String = next_step[1]
		_check(root.gui_get_focus_owner() == room.spot(expected),
			"real directional key focuses adopted %s" % expected)
		if expected == "shelf":
			_check(room.inspector.visible and room.inspector.entry_order.size() == StitchedPartyAdmission.HERO_IDS.size(),
				"direction into shelf shows only the existing passive first-night ledger")
		elif expected == "tin":
			_check(room.inspector.visible and room.inspector.empty_label.text == "No outing has ended yet",
				"direction into tin shows the existing passive no-history inspector")
		else:
			_check(not room.inspector.visible, "leaving shelf/tin by arrow dismisses its inspector")
	room.spot("door").grab_focus()
	await _key(KEY_DOWN)
	_check(root.gui_get_focus_owner() == room.spot("tin") and room.inspector.visible,
		"door down directly reaches the live tin and its passive inspector")
	room.spot("door").grab_focus()
	await process_frame
	_check(not room.inspector.visible, "leaving tin for door dismisses the inspector")

	# Refreshes and record presentations must not revert to a queued-for-free
	# pre-adoption button, and must leave the host's Tab order independent.
	view.present_bedroom(StitchedBedroomRecord.fresh())
	view._wire_focus()
	await _key(KEY_RIGHT)
	_check(root.gui_get_focus_owner() == room.spot("drawings"),
		"post-present and post-host-focus-refresh arrows retain the adopted drawings")
	var forward := {}
	room.spot("door").grab_focus()
	for index in range(12):
		await _key(KEY_TAB)
		var owner := root.gui_get_focus_owner()
		if owner != null:
			for id in ["door", "shelf", "drawings", "window", "tin"]:
				if owner == room.spot(id):
					forward[id] = true
			if owner == view.back_button:
				forward["back"] = true
	for id in ["door", "shelf", "drawings", "window", "tin", "back"]:
		_check(forward.has(id), "real Tab still reaches %s" % id)
	var reverse := {}
	room.spot("door").grab_focus()
	for index in range(12):
		await _key(KEY_TAB, true)
		var owner := root.gui_get_focus_owner()
		if owner != null:
			for id in ["door", "shelf", "drawings", "window", "tin"]:
				if owner == room.spot(id):
					reverse[id] = true
			if owner == view.back_button:
				reverse["back"] = true
	for id in ["door", "shelf", "drawings", "window", "tin", "back"]:
		_check(reverse.has(id), "real Shift-Tab still reaches %s" % id)

	# Window activation by keyboard reveals only the pre-existing legal row.
	room.spot("window").grab_focus()
	await _key(KEY_ENTER)
	_check(view._difficulty_row.visible, "window accepts normal keyboard activation")
	var legal: Button = null
	for button in view.difficulty_buttons:
		if not button.disabled:
			legal = button
	_check(legal != null, "mounted host has an unlocked difficulty control")
	if legal != null:
		var reached := false
		room.spot("door").grab_focus()
		for index in range(14):
			await _key(KEY_TAB)
			if root.gui_get_focus_owner() == legal:
				reached = true
		_check(reached, "real Tab reaches the legal difficulty choice")
		reached = false
		for index in range(14):
			await _key(KEY_TAB, true)
			if root.gui_get_focus_owner() == legal:
				reached = true
		_check(reached, "real Shift-Tab reaches the legal difficulty choice")
	room.spot("window").grab_focus()
	await _key(KEY_ENTER)
	_check(not view._difficulty_row.visible, "window toggles its original difficulty row closed")

	for id in counts:
		_check(counts[id] == (2 if id == "window" else 0),
			"directions/Tab never press %s; only two deliberate window activations" % id)
	_check(app.stitched_run_session == null and app.stitched_run_panel == null
		and not view.field_guide.is_open() and view.has_open_village()
		and app.bedroom_record == record_before and view.wallet_label.text == wallet_before
		and app.run_seed == seed_before,
		"focus-only navigation preserves live run, record, seed and wallet")

	# Existing guide consumes its own arrows and restores the Drawings source.
	room.spot("drawings").grab_focus()
	await _key(KEY_ENTER)
	_check(view.field_guide.is_open() and counts["drawings"] == 1,
		"keyboard activation on drawings opens exactly one existing field guide")
	var guide := view.field_guide
	_check(guide.is_ancestor_of(root.gui_get_focus_owner()), "guide takes focus from the bedroom")
	for direction in [KEY_RIGHT, KEY_DOWN, KEY_LEFT, KEY_UP]:
		await _key(direction)
		_check(guide.is_ancestor_of(root.gui_get_focus_owner()),
			"direction in the guide cannot steal focus back to room")
	await _key(KEY_ESCAPE)
	_check(not guide.is_open() and root.gui_get_focus_owner() == room.spot("drawings"),
		"Escape closes guide and returns focus to actual drawings hotspot")

	# Tin's original Parts path nests an atlas; Escape returns via its
	# original modal and finally to the adopted Tin button.
	room.spot("tin").grab_focus()
	await _key(KEY_ENTER)
	_check(guide.is_open() and guide._atlas_is_open() and counts["tin"] == 1,
		"normal tin activation opens the original part atlas once")
	for direction in [KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN]:
		await _key(direction)
		_check(guide.is_ancestor_of(root.gui_get_focus_owner()),
			"direction inside part atlas stays in its modal")
	await _key(KEY_ESCAPE)
	_check(guide.is_open() and not guide._atlas_is_open(),
		"first Escape only closes part atlas")
	await _key(KEY_ESCAPE)
	_check(not guide.is_open() and root.gui_get_focus_owner() == room.spot("tin"),
		"second Escape closes guide and restores live tin hotspot")
	_check(counts["door"] == 0 and counts["shelf"] == 0 and counts["candle"] == 0,
		"navigation and both modal visits never press a route or candle")

	# Real pointer movement still hovers the lifted image and passive readout.
	room.spot("door").grab_focus()
	await process_frame
	await _mouse_move(room.spot("shelf").get_global_rect().get_center())
	_check(room.inspector.visible and room.inspector.entry_order.size() == StitchedPartyAdmission.HERO_IDS.size(),
		"mounted pointer over shelf reveals the passive doll ledger")
	await _mouse_move(room.spot("tin").get_global_rect().get_center())
	_check(room.inspector.visible and room.inspector.empty_label.text == "No outing has ended yet",
		"pointer moving to tin replaces shelf with no-history inspector")
	await _mouse_move(Vector2(700, 610))
	_check(not room.inspector.visible and counts["shelf"] == 0 and counts["tin"] == 1,
		"moving pointer away dismisses inspector without pressing any hotspot")

	# A hidden base is not a keyboard route: re-show it for the original
	# mounted run and aftermath assertions below.
	var before := counts.duplicate()
	view.hide()
	await process_frame
	for direction in [KEY_RIGHT, KEY_DOWN, KEY_ENTER]:
		await _key(direction)
	_check(not guide.is_open() and view.has_open_village()
		and app.stitched_run_session == null and counts == before,
		"hidden bedroom cannot activate a route or steal keyboard input")
	view.show()
	view._wire_focus()
	room.spot("door").grab_focus()
	await _key(KEY_RIGHT)
	_check(root.gui_get_focus_owner() == room.spot("drawings"),
		"reshown base immediately restores live directional neighbors")


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
	await _directional_base(view, app)
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
	await _key(KEY_ENTER)
	_check(app.stitched_run_panel != null and not view.visible,
		"normal keyboard activation of the shelf leads to choosing four dolls")
	app.stitched_run_buttons[0].pressed.emit()
	await process_frame
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and not is_instance_valid(app.base_screen), "the door opens onto a run")
	if session == null:
		return
	# Mutate the actual worn parts on the live selected party before the normal
	# win sealing and end-of-run callback; no test-only bedroom injection.
	_check(session.heroes.size() == StitchedPartyAdmission.RANK_COUNT
		and session.heroes[0].id == "warden" and session.heroes[1].id == "seamstress",
		"mounted run has the actual selected Wren dolls")
	_check(int(session.heroes[0].hp) > 0 and int(session.heroes[1].hp) > 0
		and session.heroes[0].parts.has("arms") and session.heroes[1].parts.has("legs")
		and session.heroes[3].id == "lantern_monk",
		"mounted torn participants are alive and wear the real selected limbs")
	session.heroes[0].parts.arms.torn = true
	session.heroes[1].parts.legs.torn = true
	session.heroes[2].parts.arms.torn = true
	session.heroes[2].parts.legs.torn = true
	session.heroes[0].fray = 165
	session.heroes[3].fray = 110
	session.phase = "victory"
	session._seal()
	app._present_stitched_run()
	await process_frame
	_check(app.bedroom_record.nights == 1 and app.bedroom_record.outcome == "victory"
		and app.bedroom_record.dolls.warden.get("torn_slots", []) == ["arms"]
		and app.bedroom_record.dolls.seamstress.get("torn_slots", []) == ["legs"]
		and app.bedroom_record.dolls.tinker.get("torn_slots", []) == ["arms", "legs"]
		and app.bedroom_record.dolls.warden.fray == 165
		and app.bedroom_record.dolls.lantern_monk.fray == 110,
		"real run completion counts once and captures three living torn conditions")
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
	_check(view.bedroom.spot("shelf").has_focus() and view.bedroom.inspector.visible
		and view.bedroom.inspector.status_labels.warden.text == "TORN ARM\nFACING WALL"
		and view.bedroom.inspector.status_labels.seamstress.text == "TORN LEG"
		and view.bedroom.inspector.status_labels.tinker.text == "TORN ARM, LEG"
		and view.bedroom.inspector.status_labels.lantern_monk.text == "SLUMPED",
		"real return shelf keyboard inspection reads the live torn and intact history")
	var inspector := view.bedroom.inspector
	var panel_rect := inspector.get_global_rect()
	var warden_label: Label = inspector.status_labels.warden
	_check(inspector.get_child_count() == 2 and inspector.entry_order.size() == 8
		and warden_label.get_line_count() == 2
		and panel_rect.encloses(warden_label.get_global_rect())
		and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(panel_rect),
		"real combined two-line readout fits the existing 1280x720 felt with no new controls")
	_check(view.bedroom.record == app.bedroom_record
		and view.bedroom.doll_pose("warden") == "side"
		and view.bedroom.doll_pose("seamstress") == "side"
		and view.bedroom.doll_pose("tinker") == "side"
		and view.bedroom.dolls.warden.texture != null
		and is_equal_approx(view.bedroom.dolls.warden.rotation, -PI * 0.5)
		and view.bedroom.doll_pose("lantern_monk") == "slumped",
		"actual mounted record drives the original rotated shelf portraits")
	_check_marks(view.bedroom, {}, {"warden": ["arms"], "seamstress": ["legs"],
		"tinker": ["arms", "legs"]}, "mounted actual victory return")
	view.bedroom.spot("door").grab_focus()
	await process_frame
	await _mouse_move(view.bedroom.spot("shelf").get_global_rect().get_center())
	_check(view.bedroom.inspector.visible
		and view.bedroom.inspector.status_labels.warden.text == "TORN ARM\nFACING WALL"
		and view.bedroom.inspector.status_labels.tinker.text == "TORN ARM, LEG"
		and view.bedroom.inspector.status_labels.lantern_monk.text == "SLUMPED",
		"real mouse motion over returned shelf shows identical combined conditions")
	await _mouse_move(view.bedroom.spot("tin").get_global_rect().get_center())
	_check(view.bedroom.inspector.visible and view.bedroom.inspector.entry_order.is_empty()
		and view.bedroom.inspector.empty_label.text == "No dolls lost on the last outing",
		"real mouse hover over returned tin never mistakes torn living dolls for losses")
	await _mouse_move(Vector2(700, 610))
	await _shot("after_win")
	view.back_button.pressed.emit()
	await process_frame
	app.bedroom_record = StitchedBedroomRecord.after_run(app.bedroom_record, _ended("defeat"))
	app.base_button.pressed.emit()
	await process_frame
	view = app.base_screen
	_check(is_instance_valid(view) and not view.bedroom.is_morning()
		and view.bedroom.doll_pose("warden") == "tin", "after a loss a doll lies in the tin")
	_check_marks(view.bedroom, {}, {}, "mounted intact LOST after torn victory")
	view.bedroom.spot("tin").grab_focus()
	await process_frame
	_check(view.bedroom.inspector.visible
		and view.bedroom.inspector.entry_order == ["warden"]
		and view.bedroom.inspector.status_labels.warden.text == "LOST",
		"mounted loss tin reveals the actual lost doll by keyboard")
	view.bedroom.spot("shelf").mouse_entered.emit()
	_check(view.bedroom.inspector.status_labels.tinker.text == "SLUMPED"
		and view.bedroom.inspector.status_labels.lantern_monk.text == "FACING WALL",
		"mounted loss shelf hover reveals the full correct aftermath")
	await _shot("after_loss")
	var closed_record: Dictionary = app.bedroom_record.duplicate(true)
	var closed_wallet: String = view.wallet_label.text
	var closed_presses := {}
	for id in StitchedBedroom.SPOTS:
		closed_presses[id] = 0
		view.bedroom.spot(id).pressed.connect(_count_hotspot_press.bind(closed_presses, id))
	view.close_village()
	await process_frame
	for key in [KEY_RIGHT, KEY_DOWN, KEY_ENTER]:
		await _key(key)
	_check(not view.has_open_village() and not view.is_visible_in_tree()
		and not view.field_guide.is_open() and app.bedroom_record == closed_record
		and view.wallet_label.text == closed_wallet,
		"closed base remains inert and preserves its saved record and wallet")
	for id in closed_presses:
		_check(closed_presses[id] == 0, "closed room cannot activate %s by key" % id)


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
