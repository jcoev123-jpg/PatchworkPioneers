extends SceneTree
## Real, detached starter preview + title/village admission regression.
## Oracles enumerate the actual owner catalogs independently of the view.
const PICKER_SCENE := "res://scenes/v3_party_picker.tscn"
const APP_SCENE := "res://scenes/app.tscn"
const IDS := ["warden", "seamstress", "tinker", "lantern_monk",
	"rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
const INSPECT_PATH := "PaperPanel/Margins/Body/InspectionPanel/Inset/Stack/"

var failures: Array[String] = []
var checks := 0
var requests: Array = []
var cancels := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _tile(picker: LiveV3PartyPicker, id: String) -> Button:
	return picker.get_node_or_null("PaperPanel/Margins/Body/HeroGrid/Hero_" + id) as Button


func _move(target: Control) -> void:
	_check(target != null and target.is_visible_in_tree(), "live motion target exists")
	if target == null or not target.is_visible_in_tree():
		return
	var event := InputEventMouseMotion.new()
	event.position = target.get_global_rect().get_center()
	root.push_input(event, true)
	await _frames()


func _click(button: Button) -> void:
	_check(button != null and button.is_visible_in_tree() and not button.disabled, "live click target")
	if button == null or not button.is_visible_in_tree() or button.disabled:
		return
	await _move(button)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await _frames()


func _catalog(id: String) -> Object:
	match id:
		"warden", "seamstress", "tinker": return StarterCards.new()
		"lantern_monk": return LanternMonkStarterCards.new()
		"rag_duelist": return RagDuelistStarterCards.new()
		"scarecrow": return ScarecrowStarterCards.new()
		"yarn_ranger": return YarnRangerStarterCards.new()
		"button_golem": return ButtonGolemStarterCards.new()
	return null


## Derive from get_starting_deck and get_definition, without using the view
## formatter or RunV3PartyAdmission's _starters as an oracle.
func _source(id: String) -> Dictionary:
	var catalog := _catalog(id)
	if catalog == null:
		return {}
	var owned: Array[String] = []
	var order: Array[String] = []
	var counts: Dictionary = {}
	var labels: Dictionary = {}
	for card_id in catalog.get_starting_deck():
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty(), "source starter definition resolves " + str(card_id))
		if definition.is_empty() or definition.get("owner") != id:
			continue
		owned.append(card_id)
		_check(definition.get("id") == card_id and not card_id.ends_with("_plus")
			and not definition.has("upgrade_of"), "authored base identity " + str(card_id))
		_check(typeof(definition.get("cost")) == TYPE_INT and definition["cost"] >= 0
			and typeof(definition.get("display_name")) == TYPE_STRING
			and not definition["display_name"].is_empty(), "authored printed cost and name")
		if not counts.has(card_id):
			order.append(card_id)
			counts[card_id] = 0
			labels[card_id] = "%d EN %s" % [definition["cost"], definition["display_name"]]
		counts[card_id] += 1
		_check(RunRestStitchCards.resolve_card_definition(card_id) == definition,
			"live resolver equals shipped catalog definition " + card_id)
	var pieces: Array[String] = []
	for card_id in order:
		pieces.append(labels[card_id] + (" x%d" % counts[card_id] if counts[card_id] > 1 else ""))
	return {"ids": owned, "text": "STARTER CARDS (4)  •  " + "   |   ".join(pieces),
		"counts": counts}


func _starter(picker: LiveV3PartyPicker) -> Label:
	return picker.get_node(INSPECT_PATH + "InspectionStarters") as Label


func _check_inspection(picker: LiveV3PartyPicker, id: String, source: Dictionary,
		note: String) -> void:
	var label := _starter(picker)
	_check(label.text == source["text"], note + " exact catalog name/cost/copy readout")
	_check(not label.text.contains("+") and not label.text.contains("Unavailable"),
		note + " only resolved base starters")
	var panel := picker.inspection_panel
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 720))
	_check(label.is_visible_in_tree() and label.get_theme_font_size("font_size") >= 14
		and label.get_visible_line_count() == label.get_line_count()
		and label.get_line_count() > 0, note + " legible untruncated starter lines")
	_check(panel.get_global_rect().encloses(label.get_global_rect())
		and bounds.encloses(label.get_global_rect())
		and not label.get_global_rect().intersects(picker.inspection_detail.get_global_rect())
		and not label.get_global_rect().intersects(picker.get_node(
			"PaperPanel/Margins/Body/Foot").get_global_rect()),
		note + " full readout in sewn inspector, away from controls")
	_check(picker.inspection_heading.text.contains(id.replace("_", " ").capitalize())
		or picker.inspection_heading.text.to_lower().contains(id.replace("_", " ")),
		note + " original identity remains visible")
	_check(picker.inspection_facts.text.contains("Max HP:")
		and picker.inspection_facts.text.contains("Preferred:")
		and picker.inspection_facts.text.contains("Passive:"),
		note + " original canonical facts remain visible")


func _state(picker: LiveV3PartyPicker) -> Array:
	return [picker.selected_ids(), picker.continue_button.disabled,
		picker._seat_receipt.duplicate(true), requests.size(), cancels]


func _look(picker: LiveV3PartyPicker, id: String, source: Dictionary,
		note: String) -> void:
	var before := _state(picker)
	await _move(_tile(picker, id))
	_check_inspection(picker, id, source, note)
	_check(_state(picker) == before, note + " previews cannot change selections, gates or signals")


func _on_party(ids: Array[String]) -> void:
	requests.append(ids)


func _on_cancel() -> void:
	cancels += 1


func _app_idle(app) -> Array:
	return [app.run_map, app.run_rng, app.run_deck.duplicate(),
		app.run_heroes.duplicate(true), app.deck, app.session_gold, app.run_scraps,
		app.party_carryover]


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var fixtures: Dictionary = {}
	for id in IDS:
		var source := _source(id)
		_check(source.get("ids", []).size() == 4, id + " four independent starter occurrences")
		_check(source.get("ids", []) == RunV3PartyAdmission._starters(id, null),
			id + " authenticated four match independently read source")
		fixtures[id] = source
	_check(fixtures["warden"]["counts"].get("warden_strike", 0) == 2
		and fixtures["warden"]["text"].contains("Strike x2"),
		"two genuine Warden Strike occurrences")
	_check(RunV3PartyAdmission.admit(["warden", "warden", "tinker"]).ok == false,
		"admission still rejects repeated hero")

	var packed := load(PICKER_SCENE) as PackedScene
	_check(packed != null, "real picker scene loads")
	if packed == null:
		_finish()
		return
	var picker := packed.instantiate() as LiveV3PartyPicker
	root.add_child(picker)
	await _frames()
	picker.party_requested.connect(_on_party)
	picker.cancel_requested.connect(_on_cancel)
	_check(picker.grid.get_child_count() == 8 and picker._open,
		"fresh picker has eight authentic live tiles")
	_check(_starter(picker).text == "" and picker.inspection_heading.text.contains("HOVER OR FOCUS"),
		"no starter kit projected until inspected")
	_check(picker.selected_ids().is_empty() and picker.continue_button.disabled,
		"empty picker not admitted")
	seed(97531)
	var first := randi()
	var next := randi()
	seed(97531)
	_check(randi() == first, "seeded global RNG witness")
	for id in IDS:
		await _look(picker, id, fixtures[id], "real hover " + id)
	await _move(picker.get_node("PaperPanel/Margins/Body/SubTitle"))
	_check(_starter(picker).text == "", "no hover or focus clears starter readout")

	var focus := _tile(picker, "lantern_monk")
	focus.grab_focus()
	await _frames()
	_check(focus.has_focus(), "keyboard tile actually focused")
	_check_inspection(picker, "lantern_monk", fixtures["lantern_monk"], "real focus")
	await _look(picker, "warden", fixtures["warden"], "hover outranks other focus")
	await _move(picker.get_node("PaperPanel/Margins/Body/SubTitle"))
	_check_inspection(picker, "lantern_monk", fixtures["lantern_monk"], "mouse exit restores focus")
	focus.release_focus()
	await _frames()
	_check(_starter(picker).text == "", "clearing focus and hover returns neutral kit")
	_check(picker._starter_caption("unknown_owner") == "STARTER CARDS: Unavailable.",
		"unresolvable starter fails closed without fabricated metadata")

	for i in range(3):
		await _click(_tile(picker, IDS[i]))
		_check(picker.selected_ids().size() == i + 1, "authentic selection stage %d" % i)
		await _look(picker, "button_golem", fixtures["button_golem"],
			"read-only after %d picks" % (i + 1))
		_check(picker.continue_button.disabled == (i < 2), "unchanged three-distinct Continue gate")
	var trio: Array[String] = ["warden", "seamstress", "tinker"]
	var receipt := RunV3PartyAdmission.admit(trio)
	_check(receipt.ok and receipt.deck.size() == 12 and picker._seat_receipt == receipt,
		"selection previews authentic twelve-card run receipt")
	_check(picker.selected_ids() == trio and requests.is_empty() and cancels == 0,
		"preview never emits an action")
	var before_cancel_generation := picker._generation
	picker._cancel_pressed()
	_check(cancels == 1 and requests.is_empty() and not picker._open
		and picker._latched and _starter(picker).text == "", "cancel clears latched kit")
	var motion := InputEventMouseMotion.new()
	picker._inspect_motion(motion, "scarecrow", before_cancel_generation)
	picker._inspect_focus("scarecrow", before_cancel_generation, true)
	_check(_starter(picker).text == "" and picker.selected_ids() == trio,
		"latched callbacks never resurrect a preview or alter selection")
	picker.open_picker()
	await _frames()
	_check(_starter(picker).text == "" and picker.selected_ids().is_empty(),
		"reopen resets all preview and selection state")
	picker._inspect_motion(motion, "warden", before_cancel_generation)
	picker._inspect_focus("warden", before_cancel_generation, true)
	_check(_starter(picker).text == "", "retired generation cannot inspect reopened scene")
	await _look(picker, "yarn_ranger", fixtures["yarn_ranger"], "fresh opening still authentic")
	_check(randi() == next, "every standalone preview and cancel consumes no RNG")
	picker.queue_free()
	await _frames()

	# The same actual scene is created by both real app entry routes, with no
	# synthetic run controller and with no deck or RNG before admission.
	var app = load(APP_SCENE).instantiate()
	root.add_child(app)
	await _frames()
	var idle := _app_idle(app)
	_check(app.start_button != null and app.base_button != null and app.title_view.visible,
		"real title controls mounted")
	seed(31672)
	var expected_rng := randi()
	seed(31672)
	await _click(app.start_button)
	var live: LiveV3PartyPicker = app.party_picker
	_check(is_instance_valid(live) and live.grid.get_child_count() == 8
		and _app_idle(app) == idle, "title Start mounts inspection before any allocation")
	if is_instance_valid(live):
		await _look(live, "rag_duelist", fixtures["rag_duelist"], "live title readout")
		_check(_app_idle(app) == idle, "title inspection cannot allocate run, deck, wallet or RNG")
		await _click(live.cancel_button)
		_check(app.party_picker == null and _app_idle(app) == idle,
			"title Cancel returns without allocation")
	await _click(app.base_button)
	_check(is_instance_valid(app.base_screen) and app.base_screen.is_visible_in_tree(),
		"quilt village mounted from title")
	if is_instance_valid(app.base_screen):
		await _click(app.base_screen.set_out_button)
		live = app.party_picker
		_check(is_instance_valid(live) and _app_idle(app) == idle,
			"real village Set out mounts the same pre-admission picker")
		if is_instance_valid(live):
			await _look(live, "button_golem", fixtures["button_golem"], "live village readout")
			await _click(live.cancel_button)
			_check(app.party_picker == null and app.base_screen.visible
				and _app_idle(app) == idle, "village Cancel preserves empty run")
		app._base_back(weakref(app.base_screen))
		await _frames()
	_check(randi() == expected_rng, "both live opener previews/cancels consume no RNG")
	await _click(app.start_button)
	live = app.party_picker
	if is_instance_valid(live):
		for id in ["rag_duelist", "lantern_monk", "yarn_ranger"]:
			await _click(_tile(live, id))
		var chosen: Array[String] = ["rag_duelist", "lantern_monk", "yarn_ranger"]
		var expected := RunV3PartyAdmission.admit(chosen)
		_check(expected.ok and expected.deck.size() == 12 and not live.continue_button.disabled,
			"authentic new-party request unlocks Continue")
		await _look(live, "warden", fixtures["warden"], "unchosen owner inspection")
		_check(live.selected_ids() == chosen and live._seat_receipt == expected,
			"inspecting unchosen hero cannot admit it")
		await _click(live.continue_button)
		_check(app.party_picker == null and app.run_map != null and app.run_rng != null
			and app.run_deck == expected.deck and app.run_deck.size() == 12,
			"real Continue unchanged authentic twelve-card run allocation")
		_check(app.run_heroes == CombatParty.new(expected.party).get_heroes(),
			"run receives only chosen party and canonical seats")
	app.free()
	await _frames()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("PASS live_v3_party_starter_preview_test: %d assertions" % checks)
		quit(0)
	else:
		for reason in failures:
			printerr("FAIL: " + reason)
		printerr("FAIL live_v3_party_starter_preview_test: %d/%d" % [failures.size(), checks])
		quit(1)
