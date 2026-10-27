extends SceneTree
## Mounted, deterministic V3-4 vitality Event parchment contract.
## The inline Event below is independent of every production catalog, and the
## panel is never wired into the run: the run owner settles receipts later.

const PANEL_SCENE := "res://scenes/event_choice_panel.tscn"
const EVENT_ID := "v3_panel_lantern_seam"
const TITLE := "The Lantern Seam Trial"
const DESCRIPTION := "A button-eyed doll offers two seams beneath a brass lantern."
const HEADING := "Seamstress  •  20 / 30 HP   |   20 gold   /   3 scraps"
const SEW_TEXT := "Pay for a stronger healing seam"
const CUT_TEXT := "Unpick a seam for wages"
const LEAVE_TEXT := "Leave the seams untouched"

var panel: LiveEventChoicePanel
var failures: Array[String] = []
var checks: int = 0
var vital: Array[Dictionary] = []
var wallet: Array[Dictionary] = []
var legacy: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(key: Key) -> void:
	for state in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = state
		root.push_input(event, true)
	await _frames()


func _mouse(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for state in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = state
		root.push_input(event, true)
	await _frames()


func _on_vital(result: Dictionary) -> void:
	vital.append(result.duplicate(true))


func _on_wallet(result: Dictionary) -> void:
	wallet.append(result.duplicate(true))


func _on_legacy(event_id: String, choice_id: String) -> void:
	legacy.append({"event_id": event_id, "choice_id": choice_id})


## Fresh inline authored record on every call: no production catalog is read.
func _event() -> Dictionary:
	return {
		"id": EVENT_ID,
		"title": TITLE,
		"description": DESCRIPTION,
		"choices": [
			{"id": "sew_seam", "text": SEW_TEXT,
				"outcome": {"gold": -12, "scraps": -1, "hp": 8, "max_hp": 2}},
			{"id": "cut_hem", "text": CUT_TEXT,
				"outcome": {"gold": 18, "scraps": 2, "hp": -5, "max_hp": -2}},
			{"id": "leave", "text": LEAVE_TEXT,
				"outcome": {"gold": 0, "scraps": 0, "hp": 0, "max_hp": 0}},
		],
	}


func _snapshot(gold := 20, scraps := 3, hp := 20, max_hp := 30) -> Dictionary:
	return {"gold": gold, "scraps": scraps,
		"hero": {"id": "seamstress", "hp": hp, "max_hp": max_hp}}


func _receipt(choice_id: String, gold: int, scraps: int, hp: int, max_hp: int) -> Dictionary:
	return {"ok": true, "event_id": EVENT_ID, "choice_id": choice_id,
		"state": {"gold": gold, "scraps": scraps,
			"hero": {"id": "seamstress", "hp": hp, "max_hp": max_hp}}}


func _deltas(gold: int, scraps: int, hp: int, max_hp: int) -> String:
	return "Gold %+d   |   Scraps %+d   |   HP %+d   |   Max HP %+d" % [gold, scraps, hp, max_hp]


func _ticket(text: String, deltas: String, after: String) -> String:
	return text + "\n" + deltas + "\n" + after


func _index(record: Dictionary, choice_id: String) -> int:
	var choices: Array = record.get("choices", [])
	for i in range(choices.size()):
		if choices[i] is Dictionary and choices[i].get("id") == choice_id:
			return i
	return -1


func _hero_label() -> Label:
	return panel.choices_container.get_parent().get_node_or_null("VitalHero") as Label


## AC1: a real mounted scene shows the authored story, the named authenticated
## hero with exact vitals and wallet, and all four signed deltas plus the exact
## independent after-state on every one of the three sewn tickets.
func _test_open_layout() -> void:
	var record := _event()
	var snapshot := _snapshot()
	var record_before := record.duplicate(true)
	var snapshot_before := snapshot.duplicate(true)
	vital.clear()
	wallet.clear()
	legacy.clear()
	_check(panel.open_event_with_vitals(record, snapshot), "valid vitality offering opens")
	await _frames()
	_check(panel.has_open_event() and panel.visible and panel.is_visible_in_tree(),
		"vitality parchment is really open and visible")
	_check(panel.title_label.text == TITLE, "authored vitality title shown")
	_check(panel.description_label.text == DESCRIPTION, "authored vitality description shown")
	var heading := _hero_label()
	_check(heading != null and heading.is_visible_in_tree(), "named hero heading mounted visible")
	_check(panel.choices_container.get_parent().get_node_or_null("WalletBalance") == null,
		"vitality mode shows no wallet-only caption")
	if heading != null:
		_check(heading.text == HEADING, "heading names the hero with exact HP and wallet")
		_check(heading.theme_type_variation == "PatchHeading",
			"hero heading wears the sewn display face")
	var buttons := panel.get_choice_buttons()
	var cues := panel.get_choice_cues()
	_check(buttons.size() == 3 and cues.size() == 3, "three authored-order sewn tickets and tags")
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(viewport.encloses(panel.paper_panel.get_global_rect()),
		"vitality parchment fits 1280x720")
	if buttons.size() != 3:
		panel.close_event()
		await _frames()
		return
	var expected := [
		_ticket(SEW_TEXT, _deltas(-12, -1, 8, 2), "After: 8 gold | 2 scraps | 28/32 HP"),
		_ticket(CUT_TEXT, _deltas(18, 2, -5, -2), "After: 38 gold | 5 scraps | 15/28 HP"),
		_ticket(LEAVE_TEXT, _deltas(0, 0, 0, 0), "After: 20 gold | 3 scraps | 20/30 HP"),
	]
	var expected_ids := ["sew_seam", "cut_hem", "leave"]
	for i in range(3):
		_check(buttons[i].text == expected[i],
			"exact authored action, four signed deltas and projected after-state " + str(i))
		_check(buttons[i].get_parent() == panel.choices_container
			and buttons[i].is_visible_in_tree(), "real mounted ticket " + str(i))
		_check(panel._bound_choices.get(buttons[i], "") == expected_ids[i],
			"ticket keeps its authored choice binding " + str(i))
		_check(buttons[i].name == "Choice_%d" % i, "stable ticket identity " + str(i))
		_check(not buttons[i].disabled and buttons[i].focus_mode == Control.FOCUS_ALL,
			"affordable ticket enabled and focusable " + str(i))
		_check(buttons[i].get_theme_font_size("font_size") >= 18,
			"ticket text readable at 1280x720 " + str(i))
		_check(viewport.encloses(buttons[i].get_global_rect()), "full ticket onscreen " + str(i))
		_check(cues[i].text == str(i + 1) and cues[i].get_parent() == buttons[i],
			"sewn number tag repeats the authored position " + str(i))
	_check(record == record_before and snapshot == snapshot_before,
		"opening a vitality offer mutates neither the record nor the snapshot")
	panel.close_event()
	await _frames()
	_check(not panel.has_open_event() and panel.get_choice_buttons().is_empty(),
		"close releases the vitality tickets")
	_check(_hero_label() == null and not panel._vital_mode
		and panel._offered_snapshot.is_empty() and panel._vital_previews.is_empty(),
		"close clears every new-mode caption and kept state")


## AC3: one real mouse claim calls choose_with_vitals once, emits one detached
## receipt, never mutates the caller snapshot, and cannot replay.
func _test_mouse_claim_and_detach() -> void:
	var record := _event()
	var snapshot := _snapshot()
	vital.clear()
	wallet.clear()
	legacy.clear()
	_check(panel.open_event_with_vitals(record, snapshot), "mouse claim offering opens")
	await _frames()
	var index := _index(record, "sew_seam")
	_check(index >= 0 and index < panel.get_choice_buttons().size(), "mouse target offered")
	if index < 0 or index >= panel.get_choice_buttons().size():
		panel.close_event()
		return
	var button: Button = panel.get_choice_buttons()[index]
	# Mutating the caller after mounting cannot redirect the detached transaction.
	snapshot["gold"] = 999
	snapshot["scraps"] = 999
	snapshot["hero"]["hp"] = 1
	snapshot["hero"]["max_hp"] = 10
	record["title"] = "forged title"
	record["choices"][index]["outcome"]["gold"] = 999
	await _mouse(button)
	_check(vital.size() == 1, "mouse emits exactly one vitality receipt")
	if vital.size() == 1:
		_check(vital[0] == _receipt("sew_seam", 8, 2, 28, 32),
			"receipt carries the exact detached after-state")
		(vital[0]["state"]["hero"] as Dictionary)["hp"] = -1
		_check(panel._committed_choice == _receipt("sew_seam", 8, 2, 28, 32),
			"emitted receipt is a deep copy of the panel's own record")
	_check(wallet.is_empty() and legacy.is_empty(), "vitality claim emits no legacy/wallet signal")
	_check(panel._selector.is_claimed(), "real selector latched exactly once")
	var buttons := panel.get_choice_buttons()
	for current in buttons:
		_check(current.disabled, "all tickets disabled after the claim")
		current.pressed.emit()
	_check(vital.size() == 1, "repeated pressed signals cannot claim twice")
	panel.close_event()
	await _frames()


## AC3: each physical 1/2/3 key flows through the one real selector on its own
## fresh visit and returns that authored choice's exact receipt.
func _test_keys() -> void:
	var keys := [KEY_1, KEY_2, KEY_3]
	var expected := [
		_receipt("sew_seam", 8, 2, 28, 32),
		_receipt("cut_hem", 38, 5, 15, 28),
		_receipt("leave", 20, 3, 20, 30),
	]
	for i in range(3):
		var snapshot := _snapshot()
		var before := snapshot.duplicate(true)
		vital.clear()
		wallet.clear()
		legacy.clear()
		_check(panel.open_event_with_vitals(_event(), snapshot), "key visit opens #" + str(i + 1))
		await _frames()
		await _key(keys[i])
		_check(vital.size() == 1 and vital[0] == expected[i],
			"physical key %d commits its authored choice once" % [i + 1])
		_check(wallet.is_empty() and legacy.is_empty(), "key %d emits only the vitality signal" % [i + 1])
		_check(snapshot == before, "key %d leaves the caller snapshot untouched" % [i + 1])
		_check(panel._selector.is_claimed(), "key %d latched the real selector" % [i + 1])
		await _key(keys[i])
		_check(vital.size() == 1, "spent key %d cannot replay" % [i + 1])
		panel.close_event()
		await _frames()


## AC3: max HP is applied before current HP, and healing caps at the new max.
func _test_hp_cap() -> void:
	vital.clear()
	_check(panel.open_event_with_vitals(_event(), _snapshot(20, 3, 29, 30)),
		"near-max hero opens the healing seam")
	await _frames()
	var buttons := panel.get_choice_buttons()
	if buttons.is_empty():
		return
	_check(buttons[0].text.ends_with("After: 8 gold | 2 scraps | 32/32 HP"),
		"ticket projects healing capped at the new maximum")
	await _key(KEY_1)
	_check(vital.size() == 1 and vital[0] == _receipt("sew_seam", 8, 2, 32, 32),
		"receipt raises max HP first and caps current HP at 32")
	panel.close_event()
	await _frames()


## AC2: insufficient gold/scraps, lethal HP and a max-HP floor all disable only
## their own ticket by the service preview; a valid Leave still claims.
func _test_unaffordable() -> void:
	# Insufficient gold and scraps: only Leave and the paying-in choice remain.
	vital.clear()
	_check(panel.open_event_with_vitals(_event(), _snapshot(3, 0)),
		"underfunded snapshot opens")
	await _frames()
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 3, "underfunded offering still mounts every ticket")
	if buttons.size() != 3:
		panel.close_event()
		return
	var sew := _index(_event(), "sew_seam")
	var cut := _index(_event(), "cut_hem")
	_check(sew >= 0 and cut >= 0, "underfunded fixture choice order")
	if sew < 0 or cut < 0:
		panel.close_event()
		return
	_check(buttons[sew].text == _ticket(SEW_TEXT, _deltas(-12, -1, 8, 2),
		"Need 9 gold   •   Need 1 scraps"),
		"underfunded seam ticket names exact missing gold and scraps")
	_check(buttons[sew].disabled and buttons[sew].focus_mode == Control.FOCUS_NONE,
		"underfunded seam cannot be selected or focused")
	_check(not buttons[cut].disabled and buttons[leave_index(buttons)].disabled == false,
		"paid-hem ticket and Leave stay selectable")
	var denied: Button = buttons[sew]
	await _mouse(denied)
	await _key(KEY_1)
	denied.pressed.emit()
	panel._on_choice_pressed(panel._selector, "sew_seam", panel._generation, denied)
	_check(vital.is_empty() and panel._selector.is_valid(),
		"mouse, key 1 and forced callbacks cannot claim the denied seam")
	await _key(KEY_3)
	_check(vital.size() == 1 and vital[0] == _receipt("leave", 3, 0, 20, 30),
		"valid Leave still claims the exact unchanged snapshot")
	panel.close_event()
	await _frames()

	# Insufficient scraps alone: the seam is the only denied choice.
	vital.clear()
	_check(panel.open_event_with_vitals(_event(), _snapshot(20, 0)),
		"scrap-poor snapshot opens")
	await _frames()
	buttons = panel.get_choice_buttons()
	if buttons.size() == 3:
		_check(buttons[sew].text == _ticket(SEW_TEXT, _deltas(-12, -1, 8, 2), "Need 1 scraps"),
			"seam ticket names exactly one missing scrap")
		_check(buttons[sew].disabled and buttons[sew].focus_mode == Control.FOCUS_NONE,
			"scrap-poor seam cannot be selected")
		await _mouse(buttons[sew])
		await _key(KEY_1)
		_check(vital.is_empty() and panel._selector.is_valid(),
			"scrap-poor seam consumes no visit")
		_check(not buttons[cut].disabled, "funded hem stays available")
	panel.close_event()
	await _frames()

	# Lethal HP sacrifice: -5 HP from 5 would leave 0, so cut_hem is denied.
	vital.clear()
	_check(panel.open_event_with_vitals(_event(), _snapshot(20, 3, 5, 30)),
		"low-health snapshot opens")
	await _frames()
	buttons = panel.get_choice_buttons()
	if buttons.size() == 3:
		_check(buttons[cut].text == _ticket(CUT_TEXT, _deltas(18, 2, -5, -2), "Need 1 HP"),
			"hem ticket states the exact HP shortfall")
		_check(buttons[cut].disabled and buttons[cut].focus_mode == Control.FOCUS_NONE,
			"lethal hem cannot be selected")
		await _mouse(buttons[cut])
		await _key(KEY_2)
		_check(vital.is_empty() and panel._selector.is_valid(),
			"lethal hem consumes no visit")
		_check(not buttons[sew].disabled, "healing seam stays available at 5 HP")
		_check(not buttons[leave_index(buttons)].disabled, "free Leave stays available at 5 HP")
	panel.close_event()
	await _frames()

	# Max-HP floor: 11 - 2 would fall below 10, so cut_hem is denied.
	vital.clear()
	_check(panel.open_event_with_vitals(_event(), _snapshot(20, 3, 11, 11)),
		"fragile-max snapshot opens")
	await _frames()
	buttons = panel.get_choice_buttons()
	if buttons.size() == 3:
		_check(buttons[cut].text == _ticket(CUT_TEXT, _deltas(18, 2, -5, -2), "Need 1 max HP"),
			"hem ticket states the exact max-HP floor shortfall")
		_check(buttons[cut].disabled and buttons[cut].focus_mode == Control.FOCUS_NONE,
			"max-HP-floor hem cannot be selected")
		await _key(KEY_2)
		_check(vital.is_empty() and panel._selector.is_valid(),
			"max-HP-floor hem consumes no visit")
		_check(not buttons[leave_index(buttons)].disabled, "free Leave stays available at fragile max HP")
	panel.close_event()
	await _frames()

	# Everything priced is denied; Leave remains a valid free claim.
	vital.clear()
	_check(panel.open_event_with_vitals(_event(), _snapshot(0, 0, 11, 11)),
		"destitute snapshot opens")
	await _frames()
	buttons = panel.get_choice_buttons()
	if buttons.size() == 3:
		_check(buttons[0].disabled and buttons[1].disabled and not buttons[2].disabled,
			"only the free Leave ticket remains selectable")
		await _key(KEY_3)
		_check(vital.size() == 1 and vital[0] == _receipt("leave", 0, 0, 11, 11),
			"free Leave claims the exact unchanged destitute snapshot")
	panel.close_event()
	await _frames()


func leave_index(buttons: Array[Button]) -> int:
	for i in range(buttons.size()):
		if panel._bound_choices.get(buttons[i], "") == "leave":
			return i
	return buttons.size() - 1


## AC2/AC3: malformed snapshots fail before mounting anything, an open offer is
## never replaced, and closed/reopened generations stay inert.
func _test_malformed_and_open_guard() -> void:
	var invalids: Array = [
		null,
		{},
		{"gold": 20, "scraps": 3},
		{"gold": 20, "scraps": 3, "hero": {"id": "seamstress", "hp": 20, "max_hp": 30}, "extra": 1},
		{"gold": -1, "scraps": 3, "hero": {"id": "seamstress", "hp": 20, "max_hp": 30}},
		{"gold": 1.0, "scraps": 3, "hero": {"id": "seamstress", "hp": 20, "max_hp": 30}},
		{"gold": 20, "scraps": 3, "hero": {"id": "   ", "hp": 20, "max_hp": 30}},
		{"gold": 20, "scraps": 3, "hero": {"id": "seamstress", "hp": 0, "max_hp": 30}},
		{"gold": 20, "scraps": 3, "hero": {"id": "seamstress", "hp": 31, "max_hp": 30}},
		{"gold": 20, "scraps": 3, "hero": {"id": "seamstress", "hp": 9, "max_hp": 9}},
		{"gold": 20, "scraps": 3, "hero": {"id": "seamstress", "hp": 20.0, "max_hp": 30}},
		{"gold": 20, "scraps": 3, "hero": {"id": "seamstress", "hp": 20, "max_hp": 30, "extra": 1}},
	]
	for invalid in invalids:
		var before: Variant = invalid.duplicate(true) if invalid is Dictionary else invalid
		_check(not panel.open_event_with_vitals(_event(), invalid),
			"malformed vitality snapshot rejected: " + str(invalid))
		_check(not panel.has_open_event() and not panel.visible
			and panel.get_choice_buttons().is_empty() and _hero_label() == null,
			"malformed snapshot mounts no ticket or caption: " + str(invalid))
		_check(invalid == before, "malformed snapshot never mutated: " + str(invalid))
	# Another open offer is refused before it can add anything.
	vital.clear()
	_check(panel.open_event_with_vitals(_event(), _snapshot()), "guard offering opens")
	await _frames()
	var selector := panel._selector
	var generation := panel._generation
	var old_buttons := panel.get_choice_buttons()
	_check(not panel.open_event_with_vitals(_event(), _snapshot()),
		"a second vitality offer cannot replace an open one")
	_check(panel._selector == selector and panel._generation == generation
		and panel.get_choice_buttons() == old_buttons,
		"refused replacement preserves selector, generation and tickets")
	var stale: Callable = old_buttons[0].pressed.get_connections()[0]["callable"]
	panel.close_event()
	await _frames()
	_check(panel.get_choice_buttons().is_empty() and _hero_label() == null,
		"close removes the guarded tickets and hero caption")
	_check(panel.open_event_with_vitals(_event(), _snapshot()), "fresh offering opens after close")
	await _frames()
	var fresh_selector := panel._selector
	var fresh_buttons := panel.get_choice_buttons()
	if is_instance_valid(old_buttons[0]):
		stale.call()
		panel._on_choice_pressed(selector, "sew_seam", generation, old_buttons[0])
	panel._on_choice_pressed(selector, "sew_seam", generation, fresh_buttons[0])
	panel._on_choice_pressed(fresh_selector, "sew_seam", generation, fresh_buttons[0])
	panel._on_choice_pressed(fresh_selector, "unoffered", panel._generation, fresh_buttons[0])
	_check(vital.is_empty() and fresh_selector.is_valid() and not fresh_selector.is_claimed(),
		"stale, old-generation, forged and unoffered callbacks cannot claim")
	if fresh_buttons.size() == 3:
		fresh_buttons[2].pressed.emit()
	_check(vital.size() == 1 and vital[0]["choice_id"] == "leave",
		"fresh real ticket still claims exactly once")
	panel.close_event()
	await _frames()


## AC4: the legacy opening path keeps its own two-line tickets, signal shape and
## mode, and a vitality claim leaves no state behind for it.
func _test_legacy_untouched() -> void:
	legacy.clear()
	vital.clear()
	wallet.clear()
	var record := {
		"id": "v3_panel_legacy",
		"title": "A Plain Paper Visit",
		"description": "No hero is offered to this plain Event.",
		"choices": [
			{"id": "alpha", "text": "Take the plain path", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "beta", "text": "Wait by the door", "outcome": {"gold": 0, "scraps": 0}},
		],
	}
	_check(panel.open_event(record), "legacy Event opens through the old API")
	await _frames()
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 2 and _hero_label() == null and not panel._vital_mode
		and panel._offered_snapshot.is_empty() and panel._vital_previews.is_empty(),
		"legacy Event mounts no hero heading or vitality state")
	if buttons.size() == 2:
		_check(buttons[0].text == "Take the plain path\nNo change to gold or scraps.",
			"legacy ticket keeps its authored action and zero-change line")
		_check(not buttons[0].text.contains("HP"), "legacy ticket shows no vitality deltas")
		buttons[0].pressed.emit()
	_check(legacy == [{"event_id": "v3_panel_legacy", "choice_id": "alpha"}]
		and vital.is_empty() and wallet.is_empty(),
		"legacy path emits only its original two-ID signal")
	panel.close_event()
	await _frames()


## The whole mounted vitality flow is deterministic and draws no RNG.
func _test_rng() -> void:
	seed(20261027)
	var expected := randi()
	seed(20261027)
	vital.clear()
	_check(panel.open_event_with_vitals(_event(), _snapshot()), "RNG probe offering opens")
	await _frames()
	var buttons := panel.get_choice_buttons()
	if not buttons.is_empty():
		panel._on_choice_pressed(panel._selector, "unoffered", panel._generation, buttons[0])
		await _key(KEY_1)
	panel.close_event()
	await _frames()
	_check(randi() == expected, "vitality preview, claim and close consume zero RNG")
	_check(vital.size() == 1 and vital[0]["choice_id"] == "sew_seam",
		"RNG probe still claims exactly once")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load(PANEL_SCENE) as PackedScene
	_check(scene != null, "real panel scene loads")
	if scene == null:
		_finish()
		return
	panel = scene.instantiate() as LiveEventChoicePanel
	_check(panel != null, "real scene has the expected panel script")
	if panel == null:
		_finish()
		return
	root.add_child(panel)
	panel.vital_choice_committed.connect(_on_vital)
	panel.wallet_choice_committed.connect(_on_wallet)
	panel.choice_committed.connect(_on_legacy)
	await _frames()
	_check(not panel.visible and not panel.has_open_event(), "initially closed")
	_check(panel.has_method("open_event_with_vitals") and panel.has_method("open_event")
		and panel.has_method("close_event"), "required public lifecycle methods exist")
	await _test_open_layout()
	await _test_mouse_claim_and_detach()
	await _test_keys()
	await _test_hp_cap()
	await _test_unaffordable()
	await _test_malformed_and_open_guard()
	await _test_legacy_untouched()
	await _test_rng()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_v3_vital_event_panel_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	if is_instance_valid(panel):
		panel.free()
	quit(0 if failures.is_empty() else 1)
