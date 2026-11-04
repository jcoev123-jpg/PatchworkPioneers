extends SceneTree
## Cycle 151: the pinned Quilt village base between the title and a run.
## Proves the third sewn title action opens a full-screen Base with no run
## allocation, that Set out opens the existing seeded opening chooser exactly
## like direct "Choose a route", and that stale/hidden Base signals are inert.

const APP_SCENE := "res://scenes/app.tscn"
const BASE_SCENE := "res://scenes/base_screen.tscn"
const STARTER_DECK_PATH := "res://data/cards/starter_deck.json"
const SEAMSTRESS_PATHS_PATH := "res://data/heroes/seamstress_paths.json"
const TINKER_PATHS_PATH := "res://data/heroes/tinker_paths.json"
const BASE_BACKDROP := "res://assets/paper/backgrounds/base_village.png"
const PartyChoice := preload("res://tests/party_choice.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _click(button: Button) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree(), "mouse target is mounted")
	if not is_instance_valid(button):
		return
	var point := button.get_global_rect().get_center()
	_check(root.get_visible_rect().has_point(point), "mouse target inside viewport")
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


## Real pointer movement without a click and without changing focus.
func _move_mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame


func _hover(button: Button) -> void:
	_check(is_instance_valid(button) and button.is_visible_in_tree(), "hover target is mounted")
	if not is_instance_valid(button):
		return
	await _move_mouse(button.get_global_rect().get_center())


func _unhover() -> void:
	await _move_mouse(Vector2(8, 8))


## Authored JSON numbers arrive as floats; a validated receipt normalizes them.
func _norm(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number:
			return int(number)
		return value
	if value is Array:
		var out_list: Array = []
		for item in value:
			out_list.append(_norm(item))
		return out_list
	if value is Dictionary:
		var out_dict: Dictionary = {}
		for key in value:
			out_dict[key] = _norm(value[key])
		return out_dict
	return value


## The exact authored Path record, read here independently of the run service.
func _authored_path(path_id: String) -> Dictionary:
	return _authored_record(SEAMSTRESS_PATHS_PATH, path_id)


## The exact authored Tinker Path record, read independently of the run service.
func _authored_tinker_path(path_id: String) -> Dictionary:
	if not FileAccess.file_exists(TINKER_PATHS_PATH):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(TINKER_PATHS_PATH)) != OK:
		return {}
	if not parser.data is Dictionary:
		return {}
	var rows: Variant = (parser.data as Dictionary).get("paths")
	if not rows is Array:
		return {}
	for record in rows:
		if record is Dictionary and String(record.get("id", "")) == path_id:
			return _norm(record)
	return {}


func _authored_record(path: String, path_id: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	if not parser.data is Array:
		return {}
	for record in parser.data:
		if record is Dictionary and String(record.get("id", "")) == path_id:
			return _norm(record)
	return {}


## The receipt one Path must produce: its authored record plus the canonical
## twelve-card starter deck with exactly that Path card appended.
func _expected_receipt(path_id: String) -> Dictionary:
	var authored := _authored_path(path_id)
	var card: Dictionary = authored.get("card", {})
	var deck: Array = []
	for card_id in StarterCards.new().get_starting_deck():
		deck.append(card_id)
	deck.append(String(card.get("id", "")))
	return {
		"ok": true,
		"owner": "seamstress",
		"path_id": path_id,
		"display_name": String(authored.get("display_name", "")),
		"passive": authored.get("passive", {}),
		"card": card,
		"deck": deck,
	}


## An independent seed-42 opening: state generated without the app.
func _seeded_oracle() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var generated := RunMap.new()
	generated.generate(rng)
	return [rng.state, generated.get_floors(), generated.get_route(), generated.get_legal_choices()]


## The Path button for one authored ID, or null.
func _path_button(view: BaseScreen, path_id: String) -> Button:
	for button in view.path_buttons:
		if is_instance_valid(button) and String(button.get_meta("path_id", "")) == path_id:
			return button
	return null


## Physically Tab to one authored Path option and confirm it with Enter.
func _key_select_path(view: BaseScreen, path_id: String) -> void:
	var target := _path_button(view, path_id)
	_check(target != null, "keyboard Path option is mounted: " + path_id)
	if target == null:
		return
	for attempt in range(view.path_buttons.size() + view.tinker_buttons.size()
			+ view.warden_buttons.size() + view.difficulty_buttons.size() + 5):
		if target.has_focus():
			break
		await _key(KEY_TAB)
	_check(target.has_focus(), "physical Tab reaches the Path option: " + path_id)
	if not target.has_focus():
		return
	await _key(KEY_ENTER)


## Click one authored Path option with the mouse.
func _mouse_select_path(view: BaseScreen, path_id: String) -> void:
	var target := _path_button(view, path_id)
	_check(target != null, "mouse Path option is mounted: " + path_id)
	if target == null:
		return
	await _click(target)


## Everything the title state owns; opening and leaving the Base must not touch it.
func _title_snapshot(app) -> Array:
	return [app.run_seed, app.session_gold, app.run_scraps, app.run_deck.duplicate(),
		app.run_heroes.duplicate(true), app.run_map, app.deck, app.run_rng,
		app.fight_selection, app.encounter_id, app.party_carryover,
		app.run_seamstress_path_receipt.duplicate(true),
		app.run_tinker_path_receipt.duplicate(true), app.run_warden_path_receipt.duplicate(true)]


## The seeded opening-route model shared by both entry paths.
func _route_snapshot(app) -> Array:
	var state: Array = [app.run_seed, app.session_gold, app.run_scraps, app.run_deck.duplicate(),
		app.run_heroes.duplicate(true), app.run_map.get_generation_revision(),
		app.run_map.get_floors(), app.run_map.get_route(), app.run_map.get_legal_choices(),
		app.run_rng.state, app.party_carryover.read_state(), app.deck, app.encounter_id]
	for button in app.route_buttons:
		state.append([button.get_meta("route_id"), button.text, button.disabled])
	state.append([app.route_back_button.text, app.route_map_button.text])
	return state


## The app's own signal handler, captured so an old Base can try to replay it.
func _app_binding(app, source: Signal) -> Callable:
	for connection in source.get_connections():
		var callable: Callable = connection.callable
		if callable.get_object() == app:
			return callable
	return Callable()


## A whole fresh app session for one authored Path: real title action, real
## village pick (mouse or keyboard), real Set out and the real opening book.
func _fresh_path_run(path_id: String, use_mouse: bool, enter_fight: bool) -> void:
	var scene := load(APP_SCENE) as PackedScene
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	var expected := _expected_receipt(path_id)
	var other_id := "unpicker" if path_id == "bloodline" else "bloodline"
	var card_id := String((expected["card"] as Dictionary).get("id", ""))
	var starter: Array[String] = RunV3PartyAdmission.admit(["warden", "seamstress", "tinker"]).deck
	_check(not _authored_path(path_id).is_empty() and not (expected["card"] as Dictionary).is_empty()
		and not card_id.is_empty() and app.run_seamstress_path_receipt.is_empty()
		and app.title_view.is_visible_in_tree(),
		"authored Path record is readable and the session boots clean: " + path_id)

	await _click(app.base_button)
	_check(is_instance_valid(app.base_screen) and app.base_screen.has_open_village(),
		"fresh session opens the real village: " + path_id)
	if not is_instance_valid(app.base_screen):
		app.free()
		return
	var view: BaseScreen = app.base_screen
	var shown: Array = view.path_options()
	_check(shown.size() == 2 and String(shown[0].get("id", "")) == "bloodline"
		and String(shown[1].get("id", "")) == "unpicker",
		"both authored Paths are offered in authored order")
	for index in range(shown.size()):
		var option: Dictionary = shown[index]
		var authored := _authored_path(String(option.get("id", "")))
		_check(String(option.get("display_name", "")) == String(authored.get("display_name", ""))
			and not String(option.get("display_name", "")).is_empty()
			and String(view.path_buttons[index].text) == String(option.get("display_name", "")),
			"village Path option shows its authored name: " + String(option.get("id", "")))
	_check(app.run_seamstress_path_choice != null and app.run_seamstress_path_choice.is_valid()
		and not app.run_seamstress_path_choice.is_claimed(),
		"the village holds one unclaimed run-setup Path choice")
	var stale: Callable = _app_binding(app, view.path_choice_requested)
	_check(stale.is_valid(), "the app really handles the Base Path signal")

	# Unknown admissions are rejected before any claim and spend no RNG at all.
	seed(166166)
	var expected_global := randi()
	seed(166166)
	for unknown in ["not_an_authored_path", "", "bloodline\n"]:
		stale.call(unknown)
		_check(view.selected_path_id() == "" and app.run_seamstress_path_receipt.is_empty()
			and not app.run_seamstress_path_choice.is_claimed()
			and not view.path_buttons[0].disabled and not view.path_buttons[1].disabled,
			"unknown Path request is refused and claims nothing: " + str(unknown))
	_check(randi() == expected_global, "refused Path requests spend no global RNG")

	# AC4: a refused request never poisons a later truthful preview.
	var after_refusal := VillagePathPreview.seamstress(shown[0])
	await _hover(view.path_buttons[0])
	_check(not after_refusal.is_empty()
		and view.path_hint_label.text == String(after_refusal.get("hint", ""))
		and view.path_hint_label.text.contains(String(shown[0].get("card_name", "")))
		and view.selected_path_id() == "" and not app.run_seamstress_path_choice.is_claimed(),
		"a valid authored option still previews after a refused one: " + path_id)
	await _unhover()
	_check(view.path_hint_label.text == "Choose one Path for this run",
		"the preview clears again before the pick: " + path_id)

	if use_mouse:
		await _mouse_select_path(view, path_id)
	else:
		await _key_select_path(view, path_id)
	_check(view.selected_path_id() == path_id
		and view.selected_path_name() == String(expected["display_name"]),
		"the village shows the actual selected Path: " + path_id)
	_check(view.path_status_label.is_visible_in_tree()
		and view.path_status_label.text.contains(String(expected["display_name"])),
		"the selected Path is readable on the village board: " + path_id)
	_check(app.run_seamstress_path_receipt.is_empty(), "a pick alone commits no run receipt")
	_check(app.run_seamstress_path_choice.is_claimed()
		and app.run_seamstress_path_choice.get_receipt() == expected,
		"the setup's one valid Path claim is the authored receipt")
	_check(view.path_buttons[0].disabled and view.path_buttons[1].disabled
		and view.set_out_button.has_focus(), "a confirmed Path leaves only the sewn actions")
	# Repeated, alternate and directly-invoked requests cannot overwrite the pick.
	for again in [path_id, other_id, path_id]:
		stale.call(again)
	_check(view.selected_path_id() == path_id
		and app.run_seamstress_path_choice.get_receipt() == expected
		and app.run_seamstress_path_receipt.is_empty(),
		"repeated or alternate Path requests cannot overwrite the pick")
	_check(not view.mark_path_selected(other_id, String(_authored_path(other_id).get("display_name", "")))
		and view.selected_path_id() == path_id,
		"the view itself cannot replace a confirmed Path")

	seed(166167)
	expected_global = randi()
	seed(166167)
	await _click(view.set_out_button)
	# Cycle 345: Set out first mounts the pick-three screen; no run exists before it returns.
	_check(is_instance_valid(app.party_picker) and app.party_picker.is_visible_in_tree()
		and app.run_map == null and app.run_rng == null and app.run_seamstress_path_receipt.is_empty(),
		"Set out first mounts the party picker with no run: " + path_id)
	PartyChoice.choose(app)
	_check(is_instance_valid(app.route_view) and app.route_view.is_visible_in_tree()
		and app.base_screen == null and app.party_picker == null,
		"Set out reaches the real opening book: " + path_id)
	_check(app.run_seamstress_path_receipt == expected,
		"the run carries the validated Path receipt: " + path_id)
	_check(randi() == expected_global, "Set out with a Path spends no global RNG")

	var oracle := _seeded_oracle()
	_check(app.run_rng != null and app.run_rng.state == oracle[0]
		and app.run_map.get_floors() == oracle[1] and app.run_map.get_route() == oracle[2]
		and app.run_map.get_legal_choices() == oracle[3],
		"the seeded opening model is the independent seed-42 oracle: " + path_id)
	_check(app.run_deck == starter and app.run_deck.size() == 12 and not app.run_deck.has(card_id),
		"the playable twelve-card deck is unchanged by the Path: " + path_id)
	_check((app.run_seamstress_path_receipt["deck"] as Array).size() == 13
		and String(app.run_seamstress_path_receipt["deck"][12]) == card_id,
		"the proposed thirteenth Path card stays inside the receipt: " + path_id)
	_check(app.deck == null and app.battle_result == null and app.session_gold == 0
		and app.run_scraps == 0 and app.run_heroes.size() == 3,
		"no combat, reward or currency is created by the Path: " + path_id)

	# Detached: mutating the run's receipt copy cannot reach the setup's own copy.
	var stored: Dictionary = app.run_seamstress_path_receipt
	stored["path_id"] = "tampered"
	(stored["card"] as Dictionary)["display_name"] = "Tampered stitch"
	(stored["deck"] as Array).append("tampered_card")
	_check(app.run_seamstress_path_choice != null
		and app.run_seamstress_path_choice.get_receipt() == expected,
		"the committed receipt is detached from its setup: " + path_id)
	app.run_seamstress_path_receipt["path_id"] = path_id
	(app.run_seamstress_path_receipt["card"] as Dictionary)["display_name"] \
		= String((expected["card"] as Dictionary)["display_name"])
	(app.run_seamstress_path_receipt["deck"] as Array).pop_back()
	_check(app.run_seamstress_path_receipt == expected,
		"the run receipt is the authored record again: " + path_id)

	# A post-run request (the Base is gone) can neither overwrite it nor re-open anything.
	var opening := _route_snapshot(app)
	stale.call(other_id)
	_check(app.run_seamstress_path_receipt == expected and _route_snapshot(app) == opening
		and app.base_screen == null, "post-run Path requests stay inert: " + path_id)

	if enter_fight:
		# The receipt is run-scoped: it survives a real routed battle and its Return.
		var fight_button: Button = null
		for button in app.route_buttons:
			if not button.disabled \
				and String(button.get_meta("route_kind", "")) in ["Fight", "Elite"]:
				fight_button = button
				break
		_check(fight_button != null, "the seeded opening offers a real fight: " + path_id)
		if fight_button != null:
			await _click(fight_button)
			_check(app.deck != null and app.battle_result != null
				and is_instance_valid(app.battle_view) and app.battle_view.is_visible_in_tree()
				and app.run_seamstress_path_receipt == expected,
				"the Path receipt survives into the live battle: " + path_id)
			var total := 0
			var path_cards := 0
			var leaked := false
			for pile in [app.deck.draw_pile, app.deck.hand, app.deck.discard_pile]:
				total += (pile as Array).size()
				path_cards += (pile as Array).count(card_id)
				for other in ["seamstress_leech_stitch", "seamstress_fray"]:
					if other != card_id:
						leaked = leaked or (pile as Array).has(other)
			_check(total == 13 and path_cards == 1 and not leaked,
				"the live hand, draw and discard hold the twelve authored cards plus exactly this Path card: " + path_id)
			await _click(app.return_button)
			await process_frame
			_check(app.title_view.is_visible_in_tree() and app.deck == null
				and app.run_map == null and app.run_seamstress_path_receipt.is_empty()
				and app.run_seamstress_path_choice == null
				and app.run_tinker_path_receipt.is_empty()
				and app.run_tinker_path_choice == null,
				"Return from the live run leaves a fresh title with no Path: " + path_id)
			app.free()
			await process_frame
			return

	# Abandoning the opening restores the village with no receipt; Back leaves a clean title.
	await _click(app.route_back_button)
	await process_frame
	_check(is_instance_valid(app.base_screen) and app.base_screen.has_open_village()
		and app.run_seamstress_path_receipt.is_empty() and app.run_map == null and app.deck == null,
		"abandoning the opening restores a receipt-free village: " + path_id)
	var restored: BaseScreen = app.base_screen
	_check(restored.selected_path_id() == "" and restored.path_buttons.size() == 2
		and not restored.path_buttons[0].disabled and not restored.path_buttons[1].disabled,
		"the restored village offers a fresh unclaimed Path setup: " + path_id)
	await _click(restored.back_button)
	await process_frame
	_check(app.base_screen == null and app.title_view.is_visible_in_tree()
		and app.run_seamstress_path_receipt.is_empty() and app.run_seamstress_path_choice == null
		and app.run_tinker_path_receipt.is_empty() and app.run_tinker_path_choice == null
		and app.run_map == null and app.deck == null and app.run_rng == null
		and app.run_deck.is_empty(), "Back to title leaves no Path or run behind: " + path_id)
	app.free()
	await process_frame


## AC1/AC2/AC4: the preview formatter prints exactly the validated authored
## records, keeps PASSIVE and CARD apart, and invents nothing it cannot verify.
func _check_preview_formatter() -> void:
	var seamstress := RunSeamstressPathChoice.new()
	_check(seamstress.is_valid() and not seamstress.is_claimed()
		and seamstress.get_paths().size() == 2,
		"the preview check starts from the genuine unclaimed Seamstress setup")
	var bloodline := VillagePathPreview.seamstress(
		{"id": "bloodline", "display_name": "Bloodline", "card_name": "Leech Stitch"})
	var unpicker := VillagePathPreview.seamstress(
		{"id": "unpicker", "display_name": "Unpicker", "card_name": "Fray"})
	var sharpshot := VillagePathPreview.tinker(
		{"id": "sharpshot", "display_name": "Sharpshot", "card_name": "Scope"})
	var clockwork := VillagePathPreview.tinker(
		{"id": "clockwork", "display_name": "Clockwork", "card_name": "Wind-up"})
	for pair in [[bloodline, "bloodline"], [unpicker, "unpicker"]]:
		var preview: Dictionary = pair[0]
		var record := _authored_path(String(pair[1]))
		var card: Dictionary = record.get("card", {})
		_check(not record.is_empty() and not preview.is_empty() and bool(preview.get("ok", false))
			and String(preview.get("display_name", "")) == String(record.get("display_name", ""))
			and String(preview.get("card_name", "")) == String(card.get("display_name", ""))
			and String(preview.get("hint", "")).contains(String(card.get("display_name", ""))),
			"a Seamstress preview matches its authored record: " + String(pair[1]))
		var tooltip := String(preview.get("tooltip", ""))
		_check(tooltip.contains("PASSIVE: ") and tooltip.contains("CARD: ")
			and tooltip.contains(String(preview.get("passive_text", "")))
			and tooltip.contains(String(preview.get("card_text", "")))
			and not String(preview.get("passive_text", "")).contains(String(card.get("display_name", "")))
			and not String(preview.get("passive_text", "")).is_empty()
			and not String(preview.get("card_text", "")).is_empty(),
			"the tooltip states the PASSIVE and CARD rules separately: " + String(pair[1]))
		var card_text := String(preview.get("card_text", ""))
		_check(card_text.contains(String(card.get("display_name", "")))
			and card_text.contains("cost %d energy" % int(card.get("cost", -1)))
			and card_text.contains("from positions 1-3")
			and card_text.contains("target enemy 1-3"),
			"the card line prints its authored cost, positions and target: " + String(pair[1]))
	_check(String(bloodline.get("passive_text", "")).contains("Bleed +1")
		and String(bloodline.get("passive_text", "")).contains("not another stack")
		and not String(bloodline.get("passive_text", "")).contains("Unravel")
		and String(bloodline.get("card_text", "")).contains("Bleed 3")
		and String(bloodline.get("card_text", "")).contains("weakest living ally")
		and String(bloodline.get("card_text", "")).contains("2 HP")
		and String(bloodline.get("card_text", "")).contains("missing HP")
		and String(bloodline.get("hint", "")).contains("Bleed +1"),
		"Bloodline previews Bleed +1 and Leech Stitch's own effect")
	_check(String(unpicker.get("passive_text", "")).contains("Replaces")
		and String(unpicker.get("passive_text", "")).contains("Bleed +1")
		and String(unpicker.get("passive_text", "")).contains("+2 Unravel")
		and String(unpicker.get("card_text", "")).contains("Unravel 4")
		and String(unpicker.get("card_text", "")).contains("Bleed 1")
		and not String(unpicker.get("passive_text", "")).contains("Bleed 3")
		and String(unpicker.get("hint", "")).contains("+2 Unravel"),
		"Unpicker previews the passive it replaces and Fray's own effect")
	for pair in [[sharpshot, "sharpshot"], [clockwork, "clockwork"]]:
		var preview: Dictionary = pair[0]
		var record := _authored_tinker_path(String(pair[1]))
		var card: Dictionary = record.get("card", {})
		var positions := "from positions 2-3" if String(pair[1]) == "clockwork" else "from position 3"
		var tooltip := String(preview.get("tooltip", ""))
		_check(not record.is_empty() and not preview.is_empty() and bool(preview.get("ok", false))
			and String(preview.get("display_name", "")) == String(record.get("display_name", ""))
			and String(preview.get("card_name", "")) == String(card.get("display_name", ""))
			and String(preview.get("hint", "")).contains(String(card.get("display_name", "")))
			and tooltip.contains("PASSIVE: ") and tooltip.contains("CARD: "),
			"a Tinker preview matches its authored record: " + String(pair[1]))
		_check(String(preview.get("card_text", "")).contains("cost %d energy" % int(card.get("cost", -1)))
			and String(preview.get("card_text", "")).contains(positions)
			and String(preview.get("card_text", "")).contains("no target"),
			"the Tinker card line prints cost, positions and no target: " + String(pair[1]))
	_check(String(sharpshot.get("passive_text", "")).contains("first attack")
		and String(sharpshot.get("passive_text", "")).contains("+3")
		and String(sharpshot.get("passive_text", "")).contains("existing passive")
		and String(sharpshot.get("card_text", "")).contains("next attack this turn")
		and String(sharpshot.get("card_text", "")).contains("+4")
		and String(sharpshot.get("hint", "")).contains("First attack +3"),
		"Sharpshot previews the first-attack +3 and Scope's +4")
	_check(String(clockwork.get("passive_text", "")).contains("printed cost 2 or more")
		and String(clockwork.get("passive_text", "")).contains("1 less")
		and not String(clockwork.get("passive_text", "")).contains("Wind-up")
		and String(clockwork.get("card_text", "")).contains("+1 energy next turn"),
		"Clockwork previews the printed-cost discount and Wind-up's energy")
	# Unknown, foreign or renamed options never acquire an invented rule.
	var refused: Array = [
		VillagePathPreview.seamstress({"id": "bloodline", "display_name": "Bloodline", "card_name": "Fray"}),
		VillagePathPreview.seamstress({"id": "bloodline", "display_name": "Unpicker", "card_name": "Leech Stitch"}),
		VillagePathPreview.seamstress({"id": "not_an_authored_path", "display_name": "Bloodline", "card_name": "Leech Stitch"}),
		VillagePathPreview.seamstress({"id": "bloodline", "display_name": "Bloodline", "card_name": ""}),
		VillagePathPreview.seamstress({"id": "", "display_name": "", "card_name": ""}),
		VillagePathPreview.tinker({"id": "sharpshot", "display_name": "Sharpshot", "card_name": "Wind-up"}),
		VillagePathPreview.tinker({"id": "bloodline", "display_name": "Bloodline", "card_name": "Leech Stitch"}),
		VillagePathPreview.seamstress({"id": "SharpShot", "display_name": "Sharpshot", "card_name": "Scope"}),
		VillagePathPreview.seamstress(null),
		VillagePathPreview.seamstress("bloodline"),
		VillagePathPreview.seamstress([{"id": "bloodline"}])]
	var invented := false
	for entry in refused:
		var result: Dictionary = entry
		invented = invented or not result.is_empty() \
			or not String(result.get("tooltip", "")).is_empty() \
			or not String(result.get("hint", "")).is_empty()
	_check(not invented, "unknown, foreign or mismatched options invent no passive or card rule")
	seed(171171)
	var expected_global := randi()
	seed(171171)
	_check(VillagePathPreview.seamstress({"id": "bloodline", "display_name": "Bloodline",
		"card_name": "Leech Stitch"}) == bloodline, "repeated previews are identical")
	_check(randi() == expected_global, "previewing spends no global RNG")
	var tinker := RunTinkerPathChoice.new()
	var offers_before: Array = tinker.get_offers()
	_check(not seamstress.is_claimed() and seamstress.get_receipt().is_empty()
		and offers_before.size() == 2 and not tinker.has_selection()
		and tinker.get_offers() == offers_before,
		"previewing claims no Path and leaves both authored choices untouched")
	bloodline["passive_text"] = "tampered"
	_check(String(VillagePathPreview.seamstress({"id": "bloodline", "display_name": "Bloodline",
		"card_name": "Leech Stitch"}).get("passive_text", "")) != "tampered",
		"each preview is detached from the returned records")


## Exercise the genuine title-mounted Base, not a detached helper or invented run.
## All eight sets use the exact admission oracle and occurrence indices.
func _check_deck_gallery(app, view: BaseScreen) -> void:
	var before := _title_snapshot(app)
	var tier_before: Dictionary = app.difficulty_state().duplicate(true)
	var path_before := [view.selected_path_id(), view.selected_tinker_path_id(),
		view.selected_warden_path_id()]
	var tier_caption_before: Array[String] = []
	for button in view.difficulty_buttons:
		tier_caption_before.append(button.text)
	var choices_before := [app.run_seamstress_path_choice, app.run_tinker_path_choice,
		app.run_warden_path_choice]
	var signals := [0, 0, 0, 0, 0, 0]
	view.path_choice_requested.connect(func(_id: String): signals[0] += 1)
	view.tinker_path_choice_requested.connect(func(_id: String): signals[1] += 1)
	view.warden_path_choice_requested.connect(func(_id: String): signals[2] += 1)
	view.difficulty_choice_requested.connect(func(_tier: int): signals[3] += 1)
	view.set_out_requested.connect(func(): signals[4] += 1)
	view.back_requested.connect(func(): signals[5] += 1)
	seed(388612)
	var next_global := randi()
	seed(388612)
	var house := Rect2(778, 240, 190, 150)
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(view.deck_button != null and view.deck_button.is_visible_in_tree()
		and not view.deck_button.disabled and house.encloses(view.deck_button.get_global_rect())
		and viewport.encloses(view.deck_button.get_global_rect()),
		"Deck house has a sewn action inside its actual painted house")
	for control in view.path_buttons + view.tinker_buttons + view.warden_buttons 			+ [view.back_button, view.set_out_button]:
		_check(not view.deck_button.get_global_rect().intersects(control.get_global_rect()),
			"Deck action never overlays another mounted action")
	await _click(view.deck_button)
	var gallery: VillageStarterKitGallery = view.deck_gallery
	_check(gallery != null and gallery.is_open() and gallery.is_visible_in_tree(),
		"mouse click opens the actual mounted Deck gallery before a run")
	_check(gallery.hero_order == RunV3PartyAdmission.HERO_IDS
		and gallery.hero_buttons.size() == RunV3PartyAdmission.HERO_IDS.size()
		and gallery.card_buttons.size() == RunV3PartyAdmission.STARTERS_PER_HERO,
		"every canonical hero selector and four occurrence controls are mounted")
	var canon := RunV3PartyAdmission._canonical_records()
	_check(canon.size() == RunV3PartyAdmission.HERO_IDS.size(), "all eight shipped hero records validate")
	_check(view.deck_button.get_child_count() == 1
		and view.deck_button.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Deck house action uses the original sewn-control visual language")
	var detail_scroll := gallery.detail_label.get_parent() as ScrollContainer
	_check(detail_scroll != null and viewport.encloses(detail_scroll.get_global_rect())
		and detail_scroll.size.x >= 400.0 and detail_scroll.size.y >= 130.0
		and viewport.encloses(gallery.get_node("SewnGalleryPaper").get_global_rect())
		and viewport.encloses(gallery.close_button.get_global_rect()),
		"readable sewn sheet, large scrollable facts and Close fit the 1280x720 viewport")
	var witnessed := {"warden": false, "rag_duelist": false, "scarecrow": false,
		"button_golem": false}
	for hero_id in RunV3PartyAdmission.HERO_IDS:
		var button: Button = gallery.hero_buttons[hero_id]
		_check(button.is_visible_in_tree() and viewport.encloses(button.get_global_rect())
			and button.text == canon[hero_id]["definition"]["name"],
			"canonical mounted hero choice: " + hero_id)
		await _click(button)
		var starters := RunV3PartyAdmission._starters(hero_id, null)
		var projected := gallery.get_occurrences(hero_id)
		_check(starters.size() == RunV3PartyAdmission.STARTERS_PER_HERO
			and projected.size() == starters.size() and gallery.selected_hero_id == hero_id,
			"four distinct occurrence positions in authored order: " + hero_id)
		var catalog := RunV3PartyAdmission._shipped_catalog(hero_id)
		for index in range(starters.size()):
			var authored: Dictionary = catalog.get_definition(starters[index])
			_check(projected[index] == authored and authored["owner"] == hero_id,
				"gallery occurrence retains all catalog fields without deduplication: "
					+ hero_id + " #" + str(index))
			_check(gallery.card_buttons[index].is_visible_in_tree()
				and viewport.encloses(gallery.card_buttons[index].get_global_rect())
				and gallery.card_buttons[index].text.contains(authored["display_name"])
				and gallery.card_buttons[index].text.contains("%d EN" % authored["cost"]),
				"readable starter occurrence button names the real card and cost")
			await _click(gallery.card_buttons[index])
			var detail := gallery.detail_label.text
			_check(gallery.selected_occurrence == index and gallery.selected_card() == authored
				and detail.contains(authored["display_name"]) and detail.contains("ID: " + starters[index])
				and detail.contains("OWNER: " + hero_id)
				and detail.contains("COST: %d ENERGY" % authored["cost"])
				and detail.contains("TARGET KIND: " + authored["target_kind"]),
				"mounted card detail includes canonical identity, owner, cost and target kind")
			for field in ["from_positions", "to_positions"]:
				var positions: Array[String] = []
				for value in authored[field]:
					positions.append(str(value))
				_check(detail.contains(("FROM: " if field == "from_positions" else "TO: ")
					+ (", ".join(positions) if not positions.is_empty() else "—")),
					"full authored card position slots printed: " + starters[index])
			for key in authored["effects"]:
				_check(detail.contains("%s: %s" % [str(key), JSON.stringify(authored["effects"][key])]),
					"unmodified authored effect descriptor: " + starters[index] + ":" + str(key))
			if hero_id == "warden" and authored["target_kind"] == "enemy_single":
				witnessed["warden"] = true
			if hero_id == "rag_duelist" and authored["target_kind"] == "self":
				witnessed["rag_duelist"] = true
			if hero_id == "scarecrow" and authored["target_kind"] == "enemy_back":
				witnessed["scarecrow"] = true
			if hero_id == "button_golem" and authored["target_kind"] == "ally_single":
				witnessed["button_golem"] = true
	_check(not witnessed.values().has(false), "authentic Warden and three differently targeted V3 cards")
	gallery.hero_buttons["warden"].grab_focus()
	await _key(KEY_TAB)
	_check(gallery.hero_buttons["seamstress"].has_focus(),
		"gallery Tab reaches the next canonical hero, not a hidden Base control")
	gallery.hero_buttons["button_golem"].grab_focus()
	await _key(KEY_TAB)
	_check(gallery.card_buttons[0].has_focus(),
		"gallery keyboard focus continues into actual occurrence controls")
	var wheel := InputEventMouseButton.new()
	wheel.position = detail_scroll.get_global_rect().get_center()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel, true)
	await process_frame
	_check(gallery.is_open() and detail_scroll.is_visible_in_tree(),
		"scrolling the real authored-detail region does not dismiss the gallery")
	# The modal is the sole active action surface: even synthetic stale Base
	# button callbacks cannot choose a Path, a tier, Back or Set out.
	view.set_out_button.pressed.emit()
	view.back_button.pressed.emit()
	view.path_buttons[0].pressed.emit()
	view.tinker_buttons[0].pressed.emit()
	view.warden_buttons[0].pressed.emit()
	view.difficulty_buttons[0].pressed.emit()
	view.deck_button.pressed.emit()
	_check(gallery.is_open() and app.base_screen == view and app.party_picker == null,
		"stale Base button callbacks cannot open the run or dismiss the modal")
	await _key(KEY_ESCAPE)
	_check(not gallery.is_open() and not gallery.visible and view.deck_button.has_focus(),
		"Escape closes gallery and restores focus to the Deck house")
	var last_detail := gallery.detail_label.text
	gallery.hero_buttons["warden"].pressed.emit()
	gallery.card_buttons[2].pressed.emit()
	gallery.close_button.pressed.emit()
	_check(gallery.detail_label.text == last_detail and gallery.selected_hero_id.is_empty()
		and gallery.selected_occurrence == -1 and not gallery.visible,
		"hidden stale hero/card/Close callbacks are inert")
	# Reopen by a genuinely focused Tab/Enter, then use physical Close and Space.
	view.back_button.grab_focus()
	await _key(KEY_TAB)
	_check(view.heroes_house_button.has_focus(), "Tab from Back reaches Heroes house")
	await _key(KEY_TAB)
	_check(view.camp_house_button.has_focus(), "Tab from Heroes reaches Camp tent")
	await _key(KEY_TAB)
	_check(view.deck_button.has_focus(), "Tab from Camp reaches the real Deck house")
	await _key(KEY_ENTER)
	_check(gallery.is_open() and gallery.hero_buttons["warden"].has_focus(),
		"Enter opens a fresh canonical gallery")
	await _click(gallery.close_button)
	_check(not gallery.is_open() and view.deck_button.has_focus(),
		"mouse Close returns keyboard focus to the Deck house")
	await _key(KEY_SPACE)
	_check(gallery.is_open(), "Space activates the same Deck house without a mouse")
	await _key(KEY_ESCAPE)
	_check(not gallery.is_open() and view.deck_button.has_focus(),
		"second Escape dismisses the selection without a run")
	_check(_title_snapshot(app) == before and app.difficulty_state() == tier_before
		and [view.selected_path_id(), view.selected_tinker_path_id(),
			view.selected_warden_path_id()] == path_before
		and [app.run_seamstress_path_choice, app.run_tinker_path_choice,
			app.run_warden_path_choice] == choices_before,
		"hero, card, mouse, keyboard and scroll inspection change no run, wallet, route or Paths")
	var tier_caption_after: Array[String] = []
	for button in view.difficulty_buttons:
		tier_caption_after.append(button.text)
	_check(tier_caption_after == tier_caption_before and signals == [0, 0, 0, 0, 0, 0],
		"all six Base action signals and the selected difficulty are untouched")
	_check(randi() == next_global, "gallery and all its input consume no global RNG")
	view.set_out_button.grab_focus()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load(APP_SCENE) as PackedScene
	_check(scene != null, "real app scene loads")
	var base_scene := load(BASE_SCENE) as PackedScene
	_check(base_scene != null, "real Base scene loads")
	if scene == null or base_scene == null:
		_finish()
		return
	# AC1/AC2/AC4: the formatter itself, before any scene is mounted.
	_check_preview_formatter()
	# The village itself is presentation-only: it refuses malformed host data and
	# never resolves a Path ID, authored record or deck on its own.
	var standalone := base_scene.instantiate() as BaseScreen
	root.add_child(standalone)
	await process_frame
	_check(not standalone.present_path_options("bloodline")
		and not standalone.present_path_options([{"id": "", "display_name": "Bloodline",
			"card_name": "Leech Stitch"}])
		and not standalone.present_path_options([{"id": "bloodline", "display_name": "",
			"card_name": ""}])
		and not standalone.present_path_options([{"id": "bloodline", "display_name": "Bloodline"},
			{"id": "bloodline", "display_name": "Again"}]),
		"the view refuses malformed or duplicate Path options")
	_check(not standalone.present_tinker_path_options("sharpshot")
		and not standalone.present_tinker_path_options([{"id": "", "display_name": "Sharpshot",
			"card_name": "Scope"}])
		and not standalone.present_tinker_path_options([{"id": "sharpshot", "display_name": "",
			"card_name": ""}])
		and not standalone.present_tinker_path_options([{"id": "sharpshot", "display_name": "Sharpshot"},
			{"id": "sharpshot", "display_name": "Again"}]),
		"the view refuses malformed or duplicate Tinker options")
	_check(standalone.path_buttons.is_empty() and standalone.tinker_buttons.is_empty()
		and not standalone.path_panel.visible and not standalone.tinker_panel.visible
		and not standalone.has_open_village(), "refused options build nothing on a closed village")
	_check(standalone.open_village(3, 4), "a standalone village still opens")
	# AC4: host options the formatter cannot verify keep the plain host tooltip,
	# invent no rule, and never block a later truthful preview.
	_check(standalone.present_path_options([
		{"id": "bloodline", "display_name": "Bloodline", "card_name": "Fray"},
		{"id": "not_an_authored_path", "display_name": "Stray", "card_name": "Nothing"}])
		and standalone.path_buttons.size() == 2,
		"the view still mounts host options it cannot preview")
	_check(standalone.path_buttons[0].tooltip_text == "Seamstress Path: Bloodline · card Fray"
		and standalone.path_buttons[1].tooltip_text == "Seamstress Path: Stray · card Nothing",
		"an unverifiable option keeps the plain host tooltip")
	await _hover(standalone.path_buttons[0])
	_check(standalone.path_hint_label.text == "Choose one Path for this run",
		"an unverifiable option invents no passive or card hint")
	await _unhover()
	_check(standalone.present_tinker_path_options([
		{"id": "sharpshot", "display_name": "Sharpshot", "card_name": "Wind-up"},
		{"id": "clockwork", "display_name": "Clockwork", "card_name": "Scope"}])
		and standalone.tinker_buttons.size() == 2,
		"the Tinker board mounts unverifiable host options too")
	_check(standalone.tinker_buttons[0].tooltip_text == "Tinker Path: Sharpshot · card Wind-up"
		and standalone.tinker_buttons[1].tooltip_text == "Tinker Path: Clockwork · card Scope",
		"an unverifiable Tinker option keeps the plain host tooltip")
	await _hover(standalone.tinker_buttons[0])
	_check(standalone.tinker_hint_label.text == "Choose one Tinker Path for this run",
		"an unverifiable Tinker option invents no rule")
	await _unhover()
	_check(standalone.present_path_options([
		{"id": "bloodline", "display_name": "Bloodline", "card_name": "Leech Stitch"},
		{"id": "unpicker", "display_name": "Unpicker", "card_name": "Fray"}])
		and standalone.path_buttons.size() == 2
		and standalone.path_buttons[0].text == "Bloodline"
		and standalone.path_buttons[1].text == "Unpicker"
		and standalone.selected_path_id() == "",
		"the view presents exactly the authored names it was given")
	_check(standalone.path_buttons[0].tooltip_text.contains("PASSIVE: ")
		and standalone.path_buttons[0].tooltip_text.contains("CARD: Leech Stitch")
		and standalone.path_buttons[1].tooltip_text.contains("CARD: Fray"),
		"authored options preview fully again after an unverifiable attempt")
	await _hover(standalone.path_buttons[1])
	_check(standalone.path_hint_label.text == String(VillagePathPreview.seamstress(
		{"id": "unpicker", "display_name": "Unpicker", "card_name": "Fray"}).get("hint", ""))
		and standalone.path_hint_label.text.contains("+2 Unravel"),
		"a valid option previews normally after an unverifiable one")
	await _unhover()
	_check(standalone.path_hint_label.text == "Choose one Path for this run"
		and standalone.selected_path_id() == "",
		"leaving that preview claims nothing")
	_check(standalone.mark_path_selected("bloodline", "Bloodline")
		and standalone.selected_path_id() == "bloodline"
		and standalone.path_buttons[0].disabled and standalone.path_buttons[1].disabled
		and not standalone.mark_path_selected("unpicker", "Unpicker")
		and standalone.selected_path_id() == "bloodline"
		and not standalone.release_path_choice(),
		"a confirmed Path in the view cannot be replaced or released")
	_check(standalone.present_tinker_path_options([
		{"id": "sharpshot", "display_name": "Sharpshot", "card_name": "Scope"},
		{"id": "clockwork", "display_name": "Clockwork", "card_name": "Wind-up"}])
		and standalone.tinker_buttons.size() == 2
		and standalone.tinker_buttons[0].text == "Sharpshot"
		and standalone.tinker_buttons[1].text == "Clockwork"
		and standalone.selected_tinker_path_id() == "",
		"the view presents exactly the authored Tinker names it was given")
	_check(standalone.mark_tinker_path_selected("clockwork", "Clockwork")
		and standalone.selected_tinker_path_id() == "clockwork"
		and standalone.tinker_buttons[0].disabled and standalone.tinker_buttons[1].disabled
		and not standalone.mark_tinker_path_selected("sharpshot", "Sharpshot")
		and standalone.selected_tinker_path_id() == "clockwork"
		and not standalone.release_tinker_path_choice()
		and standalone.selected_path_id() == "bloodline",
		"a confirmed Tinker Path cannot be replaced and leaves the Seamstress board alone")
	standalone.close_village()
	_check(standalone.selected_path_id() == "" and standalone.selected_tinker_path_id() == "",
		"closing the view clears both shown Paths")
	root.remove_child(standalone)
	standalone.free()
	await process_frame
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame

	# --- AC1: a third focused, stitched title action and a run-free Base ------
	_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(),
		"ordinary title boot keeps its own focus")
	var title_children: Array = app.title_view.get_children()
	_check(is_instance_valid(app.base_button) and app.base_button.is_visible_in_tree()
		and app.base_button.text == "Quilt village", "third title action is the Quilt village")
	_check(title_children.find(app.base_button) == title_children.find(app.route_button) + 1,
		"Quilt village follows Choose a route")
	_check(app.base_button.get_child_count() == 1
		and app.base_button.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"village action is sewn, never a bare control")
	var focus_style := app.base_button.get_theme_stylebox("focus") as StyleBoxFlat
	_check(focus_style != null and focus_style.border_width_top >= 3
		and focus_style.border_color.a == 1.0, "village action shows an opaque keyboard focus ring")
	var pristine := _title_snapshot(app)
	seed(151151)
	var expected_global := randi()
	seed(151151)
	await _key(KEY_TAB)
	_check(app.route_button.has_focus(), "Tab still reaches Choose a route first")
	await _key(KEY_TAB)
	_check(app.base_button.has_focus(), "physical Tab reaches Quilt village")
	await _key(KEY_ENTER)
	_check(is_instance_valid(app.base_screen) and app.base_screen.is_visible_in_tree(),
		"physical Enter opens a full-screen Base")
	if not is_instance_valid(app.base_screen):
		app.free()
		_finish()
		return
	var view: BaseScreen = app.base_screen
	_check(view.has_open_village(), "Base reports its open village state")
	_check(_title_snapshot(app) == pristine and app.run_map == null and app.deck == null
		and app.run_rng == null and app.run_deck.is_empty() and app.run_heroes.is_empty()
		and app.session_gold == 0 and app.run_scraps == 0 and app.fight_selection == null,
		"Base allocates no run, RNG, deck, heroes or currency")
	_check(not app.title_view.is_visible_in_tree(), "Base replaces the title")
	_check(randi() == expected_global, "opening the Base spends no global RNG")
	var viewport := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(view.get_global_rect().encloses(viewport), "Base covers the whole 1280x720 screen")
	_check(view.set_out_button.is_visible_in_tree() and view.set_out_button.has_focus()
		and view.set_out_button.text == "Set out", "Set out is mounted and focused")
	_check(view.back_button.is_visible_in_tree() and view.back_button.text == "Back to title",
		"Back to title is mounted")
	_check(view.set_out_button.get_child_count() == 1 and view.back_button.get_child_count() == 1
		and view.set_out_button.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE
		and view.back_button.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"both Base actions are sewn, keyboard-reachable controls")
	await _check_deck_gallery(app, view)
	# Visible village: houses and tents with pinned names, a central spool, stitched paths.
	var buildings: Array = view.village_buildings()
	var labels: Array[String] = []
	var kinds: Array[String] = []
	for building in buildings:
		labels.append(String(building.get("label", "")))
		kinds.append(String(building.get("kind", "")))
		var rect: Rect2 = building.get("rect", Rect2())
		_check(rect.size.x > 0.0 and rect.size.y > 0.0
			and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(rect),
			"drawn building stays on the quilt: " + String(building.get("label", "")))
	_check(buildings.size() >= 4 and labels.has("Heroes") and labels.has("Camp")
		and kinds.has("house") and kinds.has("tent"), "houses and tents are drawn and named")
	var spool: Rect2 = view.village_spool()
	_check(spool.size.x > 0.0 and spool.size.y > 0.0
		and absf(spool.get_center().x - 640.0) < 1.0, "central spool sits mid-village")
	var paths: Array = view.village_paths()
	_check(paths.size() >= 2, "stitched paths join the village")
	for path in paths:
		_check((path as PackedVector2Array).size() >= 2, "path is a real stitched link")
	# Optional owner image: loader is gated and cover math keeps proportions.
	_check(view.backdrop_path() == BASE_BACKDROP, "owner village backdrop path is authored")
	_check(BaseScreen.load_base_backdrop("res://assets/paper/backgrounds/fabricated_missing_village.png") == null
		and BaseScreen.load_base_backdrop("") == null,
		"a missing village image loads no texture and cannot fail boot")
	var probe := ImageTexture.create_from_image(Image.create_empty(400, 300, false, Image.FORMAT_RGBA8))
	var cover: Rect2 = view.cover_rect_for(probe)
	_check(cover.encloses(viewport), "a supplied village image covers the whole screen")
	_check(is_equal_approx(cover.size.x / cover.size.y, 400.0 / 300.0),
		"a supplied village image keeps its own proportions")
	if view.has_backdrop_texture():
		_check(view.backdrop_texture() is Texture2D and view.backdrop_rect().encloses(viewport),
			"the mounted village image is drawn as a cover")
	# --- AC1: both authored Paths on the mounted Heroes board ---------------
	var shown: Array = view.path_options()
	_check(shown.size() == 2 and String(shown[0].get("id", "")) == "bloodline"
		and String(shown[1].get("id", "")) == "unpicker",
		"the Heroes board offers both authored Seamstress Paths")
	for index in range(shown.size()):
		var option: Dictionary = shown[index]
		var authored := _authored_path(String(option.get("id", "")))
		_check(not authored.is_empty()
			and String(option.get("display_name", "")) == String(authored.get("display_name", ""))
			and String(view.path_buttons[index].text) == String(authored.get("display_name", ""))
			and String(option.get("card_name", ""))
				== String((authored.get("card", {}) as Dictionary).get("display_name", ""))
			and view.path_buttons[index].is_visible_in_tree()
			and not view.path_buttons[index].disabled,
			"readable authored Path option: " + String(option.get("id", "")))
	var panel_rect: Rect2 = view.path_panel.get_global_rect()
	_check(view.path_panel.visible and panel_rect.size.x > 0.0 and panel_rect.size.y > 0.0
		and viewport.encloses(panel_rect), "the Path board stays on the 1280x720 quilt")
	var heroes_house := Rect2()
	for building in view.village_buildings():
		if String(building.get("label", "")) == "Heroes":
			heroes_house = building.get("rect", Rect2())
	_check(heroes_house.size.y > 0.0 and panel_rect.position.y >= heroes_house.end.y
		and absf(panel_rect.get_center().x - heroes_house.get_center().x) < heroes_house.size.x,
		"the Path board is pinned under the Heroes house")
	_check(not panel_rect.intersects(view.set_out_button.get_global_rect())
		and not panel_rect.intersects(view.back_button.get_global_rect()),
		"the Path board never covers Set out or Back to title")
	_check(_title_snapshot(app) == pristine, "presenting both Paths spends no run state")
	# The independent Tinker board offers its own two authored options.
	var tinker_shown: Array = view.tinker_path_options()
	_check(tinker_shown.size() == 2 and String(tinker_shown[0].get("id", "")) == "sharpshot"
		and String(tinker_shown[1].get("id", "")) == "clockwork"
		and view.tinker_buttons.size() == 2,
		"the Tinker board offers both authored Tinker Paths in authored order")
	for index in range(tinker_shown.size()):
		_check(String(view.tinker_buttons[index].text)
			== String(tinker_shown[index].get("display_name", ""))
			and view.tinker_buttons[index].is_visible_in_tree()
			and not view.tinker_buttons[index].disabled,
			"readable authored Tinker option: " + String(tinker_shown[index].get("id", "")))
	var tinker_rect: Rect2 = view.tinker_panel.get_global_rect()
	_check(view.tinker_panel.visible and tinker_rect.size.x > 0.0 and tinker_rect.size.y > 0.0
		and viewport.encloses(tinker_rect),
		"the Tinker board stays on the 1280x720 quilt")
	_check(not tinker_rect.intersects(panel_rect)
		and not tinker_rect.intersects(view.set_out_button.get_global_rect())
		and not tinker_rect.intersects(view.back_button.get_global_rect()),
		"the Tinker board covers neither the Seamstress board nor the sewn actions")
	_check(view.selected_tinker_path_id() == "",
		"the Tinker board starts with no Path chosen")
	# --- AC1/AC2/AC3: real hover preview of both mounted boards, no pick -----
	var preview_state := _title_snapshot(app)
	seed(171172)
	var hover_global := randi()
	seed(171172)
	var path_requests := [0]
	var tinker_requests := [0]
	view.path_choice_requested.connect(func(_path_id: String): path_requests[0] += 1)
	view.tinker_path_choice_requested.connect(func(_path_id: String): tinker_requests[0] += 1)
	for index in range(shown.size()):
		var option: Dictionary = shown[index]
		var button: Button = view.path_buttons[index]
		var card: Dictionary = (_authored_path(String(option["id"])).get("card", {}) as Dictionary)
		var preview := VillagePathPreview.seamstress(option)
		_check(not preview.is_empty() and button.tooltip_text == String(preview.get("tooltip", ""))
			and button.tooltip_text.contains("PASSIVE: ")
			and button.tooltip_text.contains("CARD: " + String(card.get("display_name", ""))),
			"the mounted Seamstress tooltip is the authored passive-and-card preview: "
				+ String(option["id"]))
		await _hover(button)
		_check(view.path_hint_label.text == String(preview.get("hint", ""))
			and view.path_hint_label.text.contains(String(card.get("display_name", "")))
			and view.selected_path_id() == "",
			"real pointer hover previews without choosing: " + String(option["id"]))
		await _unhover()
		_check(view.path_hint_label.text == "Choose one Path for this run",
			"leaving a Seamstress option restores its prompt: " + String(option["id"]))
	for index in range(tinker_shown.size()):
		var option: Dictionary = tinker_shown[index]
		var button: Button = view.tinker_buttons[index]
		var card: Dictionary = (_authored_tinker_path(String(option["id"])).get("card", {}) as Dictionary)
		var preview := VillagePathPreview.tinker(option)
		_check(not preview.is_empty() and button.tooltip_text == String(preview.get("tooltip", ""))
			and button.tooltip_text.contains("PASSIVE: ")
			and button.tooltip_text.contains("CARD: " + String(card.get("display_name", ""))),
			"the mounted Tinker tooltip is the authored passive-and-card preview: "
				+ String(option["id"]))
		await _hover(button)
		_check(view.tinker_hint_label.text == String(preview.get("hint", ""))
			and view.tinker_hint_label.text.contains(String(card.get("display_name", "")))
			and view.path_hint_label.text == "Choose one Path for this run"
			and view.selected_tinker_path_id() == "" and view.selected_path_id() == "",
			"real Tinker hover previews its own board only: " + String(option["id"]))
		await _unhover()
		_check(view.tinker_hint_label.text == "Choose one Tinker Path for this run",
			"leaving a Tinker option restores its prompt: " + String(option["id"]))
	_check(path_requests[0] == 0 and tinker_requests[0] == 0,
		"hover previews request no Path at all")
	_check(randi() == hover_global, "hover previews spend no global RNG")
	_check(_title_snapshot(app) == preview_state and view.selected_path_id() == ""
		and view.selected_tinker_path_id() == ""
		and app.run_seamstress_path_choice != null
		and not app.run_seamstress_path_choice.is_claimed()
		and app.run_tinker_path_choice != null
		and not app.run_tinker_path_choice.has_selection(),
		"previewing changes no seeded run, deck, gold, scraps or Path claim")
	# Real keyboard focus cycle includes all three mounted hero boards.
	seed(171173)
	var focus_global := randi()
	seed(171173)
	await _key(KEY_TAB)
	_check(view.difficulty_buttons[0].has_focus() and view.difficulty_buttons[1].disabled
		and view.difficulty_buttons[2].disabled, "Tab reaches earned tier and skips locked tiers")
	await _key(KEY_TAB)
	_check(view.back_button.has_focus(), "Tab reaches Back to title")
	await _key(KEY_TAB)
	_check(view.heroes_house_button.has_focus(), "Tab reaches Heroes house")
	await _key(KEY_TAB)
	_check(view.camp_house_button.has_focus(), "Tab reaches Camp tent")
	await _key(KEY_TAB)
	_check(view.deck_button.has_focus(), "Tab reaches the Deck house")
	await _key(KEY_TAB)
	_check(view.guide_button.has_focus() and not view.field_guide.is_open(),
		"Tab reaches the focusable Battle guide without opening it")
	await _key(KEY_TAB)
	_check(view.path_buttons[0].has_focus()
		and view.path_hint_label.text
			== String(VillagePathPreview.seamstress(shown[0]).get("hint", "")),
		"Tab focus previews the first authored Path")
	await _key(KEY_TAB)
	_check(view.path_buttons[1].has_focus()
		and view.path_hint_label.text
			== String(VillagePathPreview.seamstress(shown[1]).get("hint", "")),
		"Tab focus previews the second authored Path")
	await _key(KEY_TAB)
	_check(view.tinker_buttons[0].has_focus()
		and view.tinker_hint_label.text
			== String(VillagePathPreview.tinker(tinker_shown[0]).get("hint", "")),
		"Tab focus previews the first Tinker Path")
	await _key(KEY_TAB)
	_check(view.tinker_buttons[1].has_focus()
		and view.tinker_hint_label.text
			== String(VillagePathPreview.tinker(tinker_shown[1]).get("hint", "")),
		"Tab focus previews the second Tinker Path")
	for index in range(view.warden_buttons.size()):
		await _key(KEY_TAB)
		_check(view.warden_buttons[index].has_focus()
			and view.warden_hint_label.text == String(VillagePathPreview.warden(
				view.warden_path_options()[index]).get("hint", "")),
			"Tab previews each mounted Warden option")
	await _key(KEY_TAB)
	_check(view.set_out_button.has_focus()
		and view.path_hint_label.text == "Choose one Path for this run"
		and view.tinker_hint_label.text == "Choose one Tinker Path for this run"
		and view.warden_hint_label.text == "Choose one Warden Path for this run",
		"leaving all boards restores their prompts")
	for control in [view.warden_buttons[1], view.warden_buttons[0],
			view.tinker_buttons[1], view.tinker_buttons[0], view.path_buttons[1],
			view.path_buttons[0], view.guide_button, view.deck_button, view.camp_house_button,
			view.heroes_house_button, view.back_button, view.difficulty_buttons[0], view.set_out_button]:
		for down in [true, false]:
			var reverse := InputEventKey.new()
			reverse.keycode = KEY_TAB
			reverse.shift_pressed = true
			reverse.pressed = down
			root.push_input(reverse, true)
			await process_frame
		_check(control.has_focus(), "reverse Tab traverses every mounted village choice")
	_check(path_requests[0] == 0 and tinker_requests[0] == 0,
		"keyboard focus previews request no Path either")
	_check(randi() == focus_global, "keyboard previews spend no global RNG")
	# Keyboard pick of Bloodline: the host validates it and the village shows it.
	var path_binding: Callable = _app_binding(app, view.path_choice_requested)
	_check(path_binding.is_valid(), "the app really handles the Base Path signal")
	await _key_select_path(view, "bloodline")
	_check(view.selected_path_id() == "bloodline" and view.selected_path_name() == "Bloodline"
		and view.path_status_label.text.contains("Bloodline")
		and view.path_buttons[0].disabled and view.path_buttons[1].disabled,
		"a keyboard pick shows the actual selected Path and closes the other option")
	_check(app.run_seamstress_path_choice != null
		and app.run_seamstress_path_choice.get_receipt() == _expected_receipt("bloodline")
		and app.run_seamstress_path_receipt.is_empty(),
		"a confirmed Path is validated by RunSeamstressPathChoice but commits no receipt yet")
	# AC3: a confirmed Path keeps its sewn hint and status through stale previews.
	_check(view.path_hint_label.text == "Path sewn for this run",
		"a confirmed Path keeps its sewn hint")
	view.path_buttons[0].mouse_exited.emit()
	view.path_buttons[0].focus_exited.emit()
	view.path_buttons[1].mouse_exited.emit()
	_check(view.path_hint_label.text == "Path sewn for this run"
		and view.path_status_label.text.contains("Bloodline")
		and view.selected_path_id() == "bloodline",
		"stale preview exits never reset a confirmed Path")
	await _hover(view.path_buttons[0])
	_check(view.path_hint_label.text == "Path sewn for this run"
		and view.selected_path_id() == "bloodline",
		"a late hover cannot replace a confirmed Path's hint")
	await _unhover()
	await _hover(view.tinker_buttons[0])
	_check(view.tinker_hint_label.text
			== String(VillagePathPreview.tinker(tinker_shown[0]).get("hint", ""))
		and view.path_hint_label.text == "Path sewn for this run",
		"the independent Tinker board still previews while the Seamstress Path is sewn")
	await _unhover()
	_check(view.tinker_hint_label.text == "Choose one Tinker Path for this run"
		and view.path_hint_label.text == "Path sewn for this run",
		"leaving the Tinker preview leaves the sewn Seamstress Path alone")
	path_binding.call("bloodline")
	path_binding.call("unpicker")
	_check(view.selected_path_id() == "bloodline"
		and app.run_seamstress_path_choice.get_receipt()["path_id"] == "bloodline",
		"repeated or alternate Path callbacks cannot overwrite the pick")
	# The confirmed Seamstress Path narrows the sewn loop to Back, the still-open
	# Tinker and Warden options and Set out.
	await _key(KEY_TAB)
	_check(view.difficulty_buttons[0].has_focus(), "Tier remains reachable after Path selection")
	await _key(KEY_TAB)
	_check(view.back_button.has_focus(), "Tab reaches Back to title")
	await _key(KEY_TAB)
	_check(view.camp_house_button.has_focus() and view.heroes_house_button.disabled,
		"Tab skips the confirmed Heroes Path but still reaches Camp")
	await _key(KEY_TAB)
	_check(view.deck_button.has_focus(), "Tab reaches Deck after a Path is chosen")
	await _key(KEY_TAB)
	_check(view.guide_button.has_focus() and not view.field_guide.is_open(),
		"Battle guide stays keyboard reachable after a Path is chosen")
	await _key(KEY_TAB)
	_check(view.tinker_buttons[0].has_focus(), "Tab reaches the still-open first Tinker Path")
	await _key(KEY_TAB)
	_check(view.tinker_buttons[1].has_focus(), "Tab reaches the still-open second Tinker Path")
	for button in view.warden_buttons:
		await _key(KEY_TAB)
		_check(button.has_focus(), "Tab reaches each still-open Warden Path")
	await _key(KEY_TAB)
	_check(view.set_out_button.has_focus(), "Tab wraps back to Set out")
	seed(151152)
	var back_global := randi()
	seed(151152)
	await _click(view.back_button)
	await process_frame
	_check(app.base_screen == null and not is_instance_valid(app.base_screen)
		and app.title_view.is_visible_in_tree() and app.base_button.has_focus(),
		"mouse Back restores the title and the village action focus")
	_check(_title_snapshot(app) == pristine and app.run_seamstress_path_receipt.is_empty()
		and app.run_seamstress_path_choice == null,
		"Back spends no run, RNG, deck, currency or Path receipt")
	_check(randi() == back_global, "closing the Base spends no global RNG")

	# --- AC2: a mouse Path pick, a refused Set out and the real opening ------
	await _click(app.base_button)
	_check(is_instance_valid(app.base_screen) and app.base_screen.is_visible_in_tree(),
		"mouse opens the village again")
	view = app.base_screen
	_check(_title_snapshot(app) == pristine and view.has_open_village()
		and view.selected_path_id() == "" and view.path_buttons.size() == 2
		and not view.path_buttons[0].disabled and not view.path_buttons[1].disabled,
		"reopening the village offers a fresh unselected Path setup")
	await _mouse_select_path(view, "unpicker")
	_check(view.selected_path_id() == "unpicker" and view.selected_path_name() == "Unpicker"
		and view.path_status_label.text.contains("Unpicker")
		and view.set_out_button.has_focus(),
		"a mouse pick shows the actual selected Path")
	var invalid_before := _title_snapshot(app)
	app.starter_deck_path = "res://missing-base-village-deck.json"
	await _click(view.set_out_button)
	_check(is_instance_valid(app.party_picker) and app.run_map == null and not view.visible,
		"invalid-data Set out still asks for the party first")
	PartyChoice.choose(app)
	_check(app.party_picker == null and app.run_map == null and app.deck == null and app.run_rng == null
		and _title_snapshot(app) == invalid_before, "invalid Set out creates no run or RNG")
	_check(app.run_seamstress_path_receipt.is_empty() and app.base_screen == view
		and view.is_visible_in_tree() and not view.set_out_button.disabled
		and not view.back_button.disabled,
		"failed Set out commits no Path receipt and leaves the Base actionable")
	_check(view.selected_path_id() == "unpicker", "failed Set out keeps the confirmed Path")
	app.starter_deck_path = STARTER_DECK_PATH

	# --- AC2: Set out opens the real seeded chooser exactly like the title ---
	var stale_binding := _app_binding(app, view.set_out_requested)
	_check(stale_binding.is_valid(), "the app really handles the Base Set out signal")
	await _check_base_picker_guards(app, view, stale_binding)
	await _click(view.set_out_button)
	_check(is_instance_valid(app.party_picker) and app.run_map == null,
		"Set out mounts the picker before the chooser")
	PartyChoice.choose(app)
	_check(is_instance_valid(app.route_view) and app.route_view.is_visible_in_tree(),
		"Set out opens the opening-route chooser")
	_check(app.base_screen == null, "Base hides only after the route was created")
	_check(app.run_seamstress_path_receipt == _expected_receipt("unpicker"),
		"Set out commits the validated detached Path receipt")
	_check(app.run_deck == RunV3PartyAdmission.admit(["warden", "seamstress", "tinker"]).deck
		and not app.run_deck.has("seamstress_fray")
		and (app.run_seamstress_path_receipt["deck"] as Array).size() == 13,
		"the playable deck stays twelve cards while the proposal stays in the receipt")
	_check(app.deck == null and app.run_map != null and app.run_map.get_route().is_empty()
		and app.run_map.get_generation_revision() == 1,
		"exactly one seeded map with no combat or committed node")
	var base_route := _route_snapshot(app)
	_check(app.run_deck == RunV3PartyAdmission.admit(["warden", "seamstress", "tinker"]).deck and app.run_heroes.size() == 3
		and app.session_gold == 0 and app.run_scraps == 0 and app.run_seed == 42,
		"Base preserves the authored deck, three heroes, seed and currency")
	_check(app.route_buttons.size() == app.run_map.get_legal_choices().size(),
		"one mounted action per legal opening")
	_check(is_instance_valid(app.route_book_backdrop) and app.route_book_backdrop.is_visible_in_tree()
		and app.route_book_backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Set out mounts the book-backed opening chooser")
	for button in app.route_buttons:
		var id: String = button.get_meta("route_id")
		_check(app.run_map.get_legal_choices().has(id)
			and app.run_map.get_node(id).get("type") == button.get_meta("route_kind")
			and button.text == {"Rest": "Campfire", "Shop": "Peddler", "SewingCircle": "Sewing Circle",
				"PatchStall": "Patch Stall", "Elite": "Elite fight", "Boss": "Boss fight"}.get(button.get_meta("route_kind"), String(button.get_meta("route_kind")))
			and not button.text.contains(id) and button.is_visible_in_tree(),
			"legal mounted opening type label: " + id)
	# A replayed Base callback cannot replace or re-open the live chooser.
	var chooser_before := _route_snapshot(app)
	var receipt_before: Dictionary = app.run_seamstress_path_receipt.duplicate(true)
	stale_binding.call()
	path_binding.call("bloodline")
	_check(_route_snapshot(app) == chooser_before and app.route_view.is_visible_in_tree(),
		"replayed freed Base Set out cannot overwrite the run")
	_check(app.run_seamstress_path_receipt == receipt_before,
		"a post-Set out Path callback cannot overwrite the committed receipt")
	# Back from a Base-launched, uncommitted chooser returns to the village.
	app.route_back_button.grab_focus()
	await _key(KEY_ENTER)
	await process_frame
	_check(is_instance_valid(app.base_screen) and app.base_screen.is_visible_in_tree()
		and app.base_screen.has_open_village() and not app.title_view.is_visible_in_tree(),
		"keyboard Back from the Base-launched chooser restores the Quilt village")
	_check(app.run_map == null and app.run_rng == null and app.run_deck.is_empty()
		and app.party_carryover == null and app.route_view == null and app.deck == null
		and app.route_book_backdrop == null,
		"restored Base releases the whole opening model")
	_check(app.run_seamstress_path_receipt.is_empty()
		and app.run_seamstress_path_choice != null
		and not app.run_seamstress_path_choice.is_claimed(),
		"an abandoned opening drops its Path receipt and holds a fresh setup")
	_check(_title_snapshot(app) == pristine, "restored Base spends nothing")
	view = app.base_screen
	_check(view.set_out_button.has_focus(), "restored Base focuses Set out again")
	_check(view.selected_path_id() == "" and view.path_buttons.size() == 2
		and not view.path_buttons[0].disabled and not view.path_buttons[1].disabled
		and view.path_status_label.text == "No Path chosen yet",
		"restored Base offers both Paths again with nothing chosen")

	# --- AC3: a hidden Base cannot choose a Path or start a run -------------
	var hidden_binding := _app_binding(app, view.set_out_requested)
	var hidden_path_binding := _app_binding(app, view.path_choice_requested)
	_check(hidden_binding.is_valid() and hidden_path_binding.is_valid(),
		"restored Base has exactly the app handlers")
	view.hide()
	hidden_binding.call()
	view.set_out_button.pressed.emit()
	hidden_path_binding.call("bloodline")
	view.path_choice_requested.emit("unpicker")
	_check(app.run_map == null and app.deck == null and app.route_view == null
		and app.base_screen == view, "hidden Base signals cannot create a run")
	_check(view.selected_path_id() == "" and app.run_seamstress_path_receipt.is_empty()
		and not app.run_seamstress_path_choice.is_claimed(),
		"hidden Base Path signals cannot choose a Path")
	view.show()
	_check(not view.set_out_button.disabled and not view.path_buttons[0].disabled
		and not view.path_buttons[1].disabled and view.path_buttons.size() == 2,
		"shown Base stays actionable after the probe")
	await _click(view.back_button)
	await process_frame
	_check(app.base_screen == null and app.title_view.is_visible_in_tree(),
		"Back to title closes the village")
	_check(not is_instance_valid(view), "Back really frees the old village")
	hidden_path_binding.call("bloodline")
	path_binding.call("unpicker")
	_check(app.run_seamstress_path_receipt.is_empty() and app.run_seamstress_path_choice == null
		and app.run_map == null and app.deck == null and app.base_screen == null
		and app.title_view.is_visible_in_tree(), "freed Base Path callbacks stay inert")

	# --- AC2: direct Choose a route is unchanged and seeded identically ------
	await _click(app.route_button)
	_check(is_instance_valid(app.route_view) and app.run_map != null,
		"direct Choose a route still opens the chooser")
	var direct_route := _route_snapshot(app)
	_check(direct_route[3] == StarterCards.new().get_starting_deck()
		and direct_route.slice(0, 3) == base_route.slice(0, 3)
		and direct_route.slice(4, 10) == base_route.slice(4, 10)
		and direct_route.slice(11) == base_route.slice(11),
		"Base and direct route share seeded map, party and controls; each keeps its authorized deck")
	_check(app.run_map.get_generation_revision() == 1 and app.run_rng != null,
		"direct route allocates one map and one run RNG")
	await _click(app.route_back_button)
	await process_frame
	_check(app.run_map == null and app.run_rng == null and app.deck == null
		and app.title_view.is_visible_in_tree() and app.start_button.has_focus(),
		"direct route Back still returns to the title, never to the Base")
	_check(app.base_screen == null and _title_snapshot(app) == pristine
		and app.run_seamstress_path_receipt.is_empty()
		and app.run_seamstress_path_choice == null,
		"direct route Back spends nothing and leaves no Path")

	app.free()
	await process_frame

	# --- AC1/AC2/AC3: each authored Path in its own fresh mounted session ----
	await _fresh_path_run("bloodline", true, true)
	await _fresh_path_run("unpicker", false, false)
	await _chosen_party_run()
	_finish()


## Cycle 345 AC3: the Base picker allocates nothing until a valid trio; cancel, hidden,
## malformed, duplicate and replayed callbacks are inert and the Base recovers intact.
func _check_base_picker_guards(app, view: BaseScreen, set_out_binding: Callable) -> void:
	var before := _title_snapshot(app)
	var path_before := view.selected_path_id()
	seed(345345)
	var expected_global := randi()
	seed(345345)
	await _click(view.set_out_button)
	var picker = app.party_picker
	_check(is_instance_valid(picker) and picker.is_visible_in_tree() and not view.visible
		and _title_snapshot(app) == before and app.run_map == null and app.run_rng == null,
		"AC1: Base Set out mounts one picker and allocates no run or RNG")
	var admit_binding := _app_binding(app, picker.party_requested)
	var cancel_binding := _app_binding(app, picker.cancel_requested)
	_check(admit_binding.is_valid() and cancel_binding.is_valid(), "the app handles the Base picker signals")
	# A hidden village cannot open a second picker.
	set_out_binding.call()
	view.set_out_button.pressed.emit()
	var pickers := 0
	for child in app.get_children():
		if child is LiveV3PartyPicker:
			pickers += 1
	_check(pickers == 1 and app.party_picker == picker, "a replayed Set out cannot mount a second picker")
	# Unlatched, malformed and duplicate requests are refused without spending anything.
	for ids in [["warden", "seamstress", "tinker"], ["warden", "warden", "tinker"],
			["warden", "seamstress"], ["warden", "seamstress", "not_a_hero"]]:
		var typed: Array[String] = []
		typed.assign(ids)
		admit_binding.call(typed)
		_check(app.run_map == null and app.party_picker == picker and not view.visible
			and _title_snapshot(app) == before, "AC3: refused picker request allocates nothing: " + str(ids))
	# A hidden picker's Continue cannot commit; its cancel still recovers the Base.
	for id in ["warden", "seamstress", "tinker"]:
		picker._tiles[id].pressed.emit()
	picker.hide()
	picker.continue_button.pressed.emit()
	_check(app.run_map == null and app.deck == null and _title_snapshot(app) == before,
		"AC3: a hidden picker's Continue allocates no run")
	cancel_binding.call()
	_check(app.party_picker == null and view.is_visible_in_tree() and not view.set_out_button.disabled
		and not view.back_button.disabled and view.set_out_button.has_focus()
		and view.selected_path_id() == path_before and _title_snapshot(app) == before,
		"AC3: cancel returns to an actionable Base with its setup and wallet intact")
	# A real Cancel press on a fresh opening also recovers, and old bindings stay inert.
	await _click(view.set_out_button)
	var second = app.party_picker
	_check(is_instance_valid(second) and second != picker, "a later Set out mounts a fresh picker")
	await _click(second.cancel_button)
	await process_frame
	_check(app.party_picker == null and view.is_visible_in_tree() and _title_snapshot(app) == before,
		"AC3: the picker's Cancel button returns to the Base")
	var legacy: Array[String] = ["warden", "seamstress", "tinker"]
	admit_binding.call(legacy)
	cancel_binding.call()
	_check(app.run_map == null and app.party_picker == null and view.is_visible_in_tree()
		and _title_snapshot(app) == before and randi() == expected_global,
		"AC3: stale picker callbacks are inert and spend no RNG")


## Cycle 345 AC1/AC2: a non-default trio from the village opens the canonical
## seeded route; only a chosen hero's Path rides along into the Fight.
func _chosen_party_run() -> void:
	var app = (load(APP_SCENE) as PackedScene).instantiate()
	root.add_child(app)
	await process_frame
	await _click(app.base_button)
	var view: BaseScreen = app.base_screen
	_check(view != null, "fresh session opens the village for a chosen party")
	if view == null:
		app.free()
		return
	await _mouse_select_path(view, "bloodline")
	var warden_paths: Array = app.run_warden_path_choice.get_authored_paths()
	_check(not warden_paths.is_empty(), "the village offers a Warden Path")
	var warden_card := ""
	if not warden_paths.is_empty():
		warden_card = String(warden_paths[0].card.id)
		_app_binding(app, view.warden_path_choice_requested).call(String(warden_paths[0].id))
	_check(view.selected_path_id() == "bloodline" and not view.selected_warden_path_id().is_empty(),
		"the village holds a Seamstress and a Warden Path")
	var ids: Array[String] = ["rag_duelist", "seamstress", "lantern_monk"]
	var expected := RunV3PartyAdmission.admit(ids)
	_check(expected.ok and expected.hero_ids != ["warden", "seamstress", "tinker"],
		"the chosen trio is a legal non-default party")
	await _click(view.set_out_button)
	_check(is_instance_valid(app.party_picker) and app.run_map == null, "Set out asks for the party first")
	PartyChoice.choose(app, ids)
	_check(is_instance_valid(app.route_view) and app.route_view.is_visible_in_tree()
		and app.base_screen == null and app.party_picker == null, "the chosen party opens the route")
	if app.run_map == null:
		app.free()
		return
	var oracle := _seeded_oracle()
	_check(app.run_rng.state == oracle[0] and app.run_map.get_floors() == oracle[1]
		and app.run_map.get_legal_choices() == oracle[3]
		and app.route_buttons.size() == oracle[3].size(),
		"AC1: the chosen party opens the canonical seeded route")
	var heroes_ok: bool = app.run_heroes.size() == 3
	for index in range(mini(3, app.run_heroes.size())):
		var hero: Dictionary = app.run_heroes[index]
		var definition: Dictionary = expected.party[index]
		heroes_ok = heroes_ok and String(hero.get("id", "")) == String(definition.id) \
			and int(hero.get("max_hp", -1)) == int(definition.max_hp) \
			and int(hero.get("hp", -1)) == int(definition.max_hp) \
			and int(hero.get("position", -1)) == index + 1
	_check(heroes_ok, "AC1: run heroes are the chosen trio with canonical HP and positions")
	_check(app.run_deck == expected.deck and app._party_receipt.hero_ids == expected.hero_ids,
		"AC1: the run deck is the chosen trio's starter deck")
	_check(app.run_seamstress_path_receipt == _expected_receipt("bloodline")
		and app.run_warden_path_receipt.is_empty() and app.run_tinker_path_receipt.is_empty(),
		"AC2: the chosen Seamstress keeps her Path; the unchosen Warden's Path is dropped")
	var fight_button: Button = null
	for button in app.route_buttons:
		if not button.disabled and String(button.get_meta("route_kind", "")) == "Fight":
			fight_button = button
			break
	_check(fight_button != null, "the seeded opening offers a Fight")
	if fight_button != null:
		await _click(fight_button)
		var seamstress_card := String((_expected_receipt("bloodline")["card"] as Dictionary).get("id", ""))
		var cards: Array = []
		if app.deck != null:
			for pile in [app.deck.draw_pile, app.deck.hand, app.deck.discard_pile]:
				cards.append_array(pile)
		var party_ids: Array = []
		if app.party != null:
			for hero in app.party.get_heroes():
				party_ids.append(String(hero.id))
		_check(app.deck != null and party_ids == expected.hero_ids
			and cards.size() == expected.deck.size() + 1 and cards.count(seamstress_card) == 1
			and (warden_card.is_empty() or not cards.has(warden_card))
			and app._party_receipt.hero_ids == expected.hero_ids,
			"AC2: the Fight holds exactly the chosen party, its deck and the chosen Path card")
	app.free()
	await process_frame


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_base_screen_entry_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
