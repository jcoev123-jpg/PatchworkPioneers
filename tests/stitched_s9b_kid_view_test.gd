extends SceneTree
## S9b (design v4 section 9c): the battle screen shows Wren's side view. The stage is the
## kid's-view picture of the fight's house area, his hands hold one string per living doll,
## a snipped doll's string hangs cut, the fear jar reads his fear and the hands shake at 50+,
## and the four hand-action buttons work the run's StitchedRules hand actions. With a real
## renderer it also saves the seeded fight at fear 0 and 60 to user://s9b_kid_view_*.png.

var failures: Array[String] = []
var checks := 0


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _initialize() -> void:
	_run.call_deferred()


func _screen(fear: int, extra: Dictionary = {}) -> StitchedBattleScreen:
	var screen := StitchedBattleScreen.new()
	var config := StitchedBattleScreen.read_preview()
	config["kid_fear"] = fear
	config.merge(extra, true)
	_check(screen.begin(config), "the seeded preview fight opens")
	root.add_child(screen)
	return screen


func _hero_rank(screen: StitchedBattleScreen, hero_id: String) -> int:
	return int(screen.battle.get_unit(hero_id).get("rank", 0))


func _visible_strings(view: StitchedKidView, cut: bool) -> int:
	var count := 0
	for rank in view.strings:
		var string: TextureRect = view.strings[rank]
		if string.visible and bool(string.get_meta("cut", false)) == cut:
			count += 1
	return count


func _shot(screen: StitchedBattleScreen, label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for _frame in range(4):
		await process_frame
	var image := root.get_texture().get_image()
	_check(image != null and image.get_width() == 1280, "the %s fight renders a 1280-wide frame" % label)
	if image != null:
		image.save_png("user://s9b_kid_view_%s.png" % label)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var book := StitchedKidView.art()
	_check(not book.is_empty(), "kid_view_art.json loads")
	# Every picture the book names is an installed, imported image.
	var named: Array = [book.get("hands"), book.get("thread"), book.get("thread_cut"), book.get("fear_jar"),
		book.get("fear_ink"), book.get("boss", {}).get("path")]
	for area in book.get("areas", []):
		named.append(area.get("path"))
	named.append_array(book.get("icons", {}).values())
	for path in named:
		_check(ResourceLoader.exists(str(path), "Texture2D"), "kid view picture installed: %s" % path)
	# House areas deepen with the floor; the boss is under the old bed.
	var areas: Array = book.get("areas", [])
	_check(StitchedKidView.backdrop_path(1, "Fight") == str(areas[0].path), "floor 1 is Wren's bedroom")
	_check(StitchedKidView.backdrop_path(3, "Elite") == str(areas[0].path), "floor 3 is still the bedroom, Elite too")
	_check(StitchedKidView.backdrop_path(4, "Fight") == str(areas[1].path), "floor 4 is the hallway")
	_check(StitchedKidView.backdrop_path(9, "Fight") == str(areas[2].path), "floor 9 is the stairs")
	_check(StitchedKidView.backdrop_path(11, "Elite") == str(areas[3].path), "floor 11 is the cellar")
	_check(StitchedKidView.backdrop_path(12, "Boss") == str(book.boss.path), "the boss fight is under the old bed")
	_check(StitchedKidView.backdrop_path(0, "Fight") == str(areas[0].path), "a preview with no floor uses the bedroom")

	# Fear 0: calm hands, one whole string per living doll, the jar reads 0.
	var calm := _screen(0)
	var view := calm.kid_view
	var rng := calm.battle.rng_state()
	_check(view != null and view.get_parent() == calm, "the kid view is mounted on the battle screen")
	_check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.hands.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the kid view never catches clicks meant for the dolls")
	_check(view.get_index() > calm._stage_art_view.get_index(), "the hands hang in front of the painted dolls")
	_check(calm._stage_backdrop.stage_texture.resource_path == StitchedKidView.backdrop_path(1, "Fight"),
		"the stage is the kid's side view, not the old meadow")
	_check(view.hands.visible and view.hands.texture != null, "Wren's hands are on screen")
	var living := 0
	for hero in calm.battle.get_heroes():
		if not bool(hero.get("lost", false)):
			living += 1
	_check(living > 0 and _visible_strings(view, false) == living, "one whole string per living doll")
	_check(_visible_strings(view, true) == 0, "no cut strings before any snip")
	for rank in view.strings:
		var string: TextureRect = view.strings[rank]
		if string.visible:
			var hit: Control = calm._figure_hits["hero_" + str(rank)]
			var top: Vector2 = string.get_meta("doll_top")
			_check(hit.visible and absf(top.y - hit.position.y) < 0.5, "string %d reaches its doll's painted head" % rank)
	_check(not view.shaking and not view.is_processing(), "calm hands are still at fear 0")
	_check(int(view.meter_fill.value) == 0 and view.meter_label.text.contains("0 / 100"), "the fear jar reads 0")
	_check(calm.battle.rng_state() == rng, "showing the kid view draws no RNG")
	await _shot(calm, "fear0")

	# Hand-action buttons work the battle's rules and never spend the doll's turn.
	_check(calm._hand_buttons.size() == 4, "four hand-action buttons")
	for action_id in calm._hand_buttons:
		_check(not calm._hand_buttons[action_id].disabled, "%s is offered while the hand is free" % action_id)
	var actor := calm.battle.current_actor_id()
	var shield: Dictionary = calm.choose_hand_action("shield_candle")
	_check(bool(shield.get("ok", false)) and calm.battle.candle_shielded(), "Shield the Candle shields this round")
	_check(calm.battle.current_actor_id() == actor, "a hand action never spends the doll's turn")
	_check(calm._hand_buttons["steady"].disabled, "the hand is spent for the rest of the round")
	_check(not bool(calm.choose_hand_action("steady").get("ok", true)), "a second hand action this round is refused")
	_check(int(shield.get("roll", -1)) == 0, "calm hands draw no shake roll")
	calm.queue_free()

	var steady := _screen(0)
	var heroes: Array = steady.battle.get_heroes()
	var pick: Dictionary = heroes[0]
	_check(bool(steady.choose_hand_action("steady").get("ok", false)) and steady._hand_pending == "steady",
		"Steady waits for a doll")
	_check(steady.legal_targets().has("hero_%d" % int(pick.rank)), "the dolls light up as Steady targets")
	var steadied: Dictionary = steady.submit_target("hero", int(pick.rank))
	_check(bool(steadied.get("ok", false)) and str(steadied.get("hand_action", "")) == "steady"
		and str(steadied.get("actor", "")) == str(pick.id), "Steady lands on the picked doll")
	_check(steady._hand_pending.is_empty() and steady._labels["log"].text.contains("Wren"), "the log tells what Wren did")
	steady.queue_free()

	var hold := _screen(0)
	var held: Dictionary = hold.battle.get_heroes()[1]
	hold.choose_hand_action("hold_back")
	_check(bool(hold.submit_target("hero", int(held.rank)).get("ok", false)) and hold.battle.is_held(str(held.id)),
		"Hold Back pins the picked doll's string")
	hold.queue_free()

	var lift := _screen(0)
	var lifted_id := ""
	var direction := 0
	for hero in lift.battle.get_heroes():
		for way in [-1, 1]:
			if lifted_id.is_empty() and lift.battle.hand_action_check("lift", str(hero.id), way).is_empty():
				lifted_id = str(hero.id)
				direction = way
	_check(not lifted_id.is_empty(), "some doll can be lifted in the preview fight")
	var before := _hero_rank(lift, lifted_id)
	lift.choose_hand_action("lift")
	var waiting: Dictionary = lift.submit_target("hero", before)
	_check(str(waiting.get("pending", "")) == "lift:%d" % before, "Lift then waits for a direction")
	var lifted: Dictionary = lift.submit_move(direction)
	_check(bool(lifted.get("ok", false)) and str(lifted.get("hand_action", "")) == "lift"
		and _hero_rank(lift, lifted_id) == before + direction, "Move front / back lifts the doll one rank")
	lift.queue_free()

	# A snipped doll's string hangs cut until it is re-tied.
	var snip := _screen(0)
	var snipped: Dictionary = snip.battle.get_heroes()[0]
	snip.battle._thread_cuts[str(snipped.id)] = int(snipped.rank)
	snip._refresh()
	var cut_string: TextureRect = snip.kid_view.strings[int(snipped.rank)]
	_check(cut_string.visible and bool(cut_string.get_meta("cut", false)), "the snipped doll's string hangs cut")
	_check(cut_string.texture == snip.kid_view._thread_cut and cut_string.size.y <= StitchedKidView.CUT_LENGTH,
		"a cut string is the short frayed thread picture")
	_check(_visible_strings(snip.kid_view, true) == 1, "only the snipped doll's string is cut")
	snip.queue_free()

	# Fear 60: the jar fills, the hands shake, and a hand action draws its shake roll.
	var scared := _screen(60)
	_check(scared.kid_view.shaking and scared.kid_view.is_processing(), "Wren's hands shake at fear 60")
	_check(int(scared.kid_view.meter_fill.value) == 60 and scared.kid_view.meter_label.text.contains("SHAKING"),
		"the fear jar reads 60 and says the hands shake")
	await _shot(scared, "fear60")
	scared.set_reduced_motion(true)
	_check(scared.kid_view.shaking and not scared.kid_view.is_processing(), "reduce motion stills the shaking hands")
	var shaky: Dictionary = scared.choose_hand_action("shield_candle")
	_check(bool(shaky.get("ok", false)) and int(shaky.get("roll", 0)) >= 1, "a shaking hand action draws its seeded roll")
	scared.queue_free()

	# The live run feeds the session's fear through kid_fear_source.
	var live := StitchedBattleScreen.new()
	_check(live.begin(StitchedBattleScreen.read_preview()), "a second preview opens")
	live.kid_fear_source = func(): return 75
	root.add_child(live)
	_check(live.kid_fear() == 75 and int(live.kid_view.meter_fill.value) == 75, "the live fear source drives the jar")
	live.queue_free()

	await process_frame
	if failures.is_empty():
		print("stitched_s9b_kid_view_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			print("FAIL: " + failure)
		print("stitched_s9b_kid_view_test: FAIL (%d failures)" % failures.size())
		quit(1)
