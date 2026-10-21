extends SceneTree
## Deterministic detached Rest pair model and physically mounted selector regression.

var failures: Array[String] = []
var checks := 0
var received: Array[Dictionary] = []
var picker: LiveRestStitchPairPicker
var catalog := StarterCards.new()


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)


func _deck() -> Array[String]:
	var file := FileAccess.open("res://data/cards/starter_deck.json", FileAccess.READ)
	_check(file != null, "real starter_deck.json opens")
	var deck: Array[String] = []
	if file == null:
		return deck
	var raw: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if raw is Array:
		deck.assign(raw)
	return deck


func _idx(deck: Array, id: String, nth: int = 0) -> int:
	var found := 0
	for i in range(deck.size()):
		if deck[i] == id:
			if found == nth:
				return i
			found += 1
	return -1


func _take(a: int, b: int, snapshot: Dictionary) -> void:
	received.append({"first": a, "second": b, "source": snapshot.duplicate(true)})


func _frames() -> void:
	await process_frame
	await process_frame


func _click(button: Control) -> void:
	var center := button.get_global_rect().get_center()
	for press in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = center
		event.global_position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = press
		root.push_input(event, true)
	await _frames()


func _key(keycode: Key) -> void:
	for press in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = press
		root.push_input(event, true)
	await _frames()


func _select_mouse(button: OptionButton, target: int) -> void:
	await _click(button)
	var popup := button.get_popup()
	_check(popup.visible, "mouse physically opened OptionButton popup")
	if not popup.visible:
		return
	var font := popup.get_theme_font("font")
	var font_height := font.get_height(popup.get_theme_font_size("font_size"))
	var height := font_height + popup.get_theme_constant("v_separation")
	var margin := popup.get_theme_stylebox("panel").get_content_margin(SIDE_TOP)
	var point := Vector2(popup.position) + Vector2(35, margin + height * (target + 0.5))
	for press in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = press
		root.push_input(event, true)
	await _frames()
	_check(button.selected == target, "physical mouse selected item %d" % target)


func _select_keyboard(button: OptionButton, target: int) -> void:
	button.grab_focus()
	await _key(KEY_SPACE)
	for i in range(target):
		await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(button.selected == target, "physical keyboard selected item %d" % target)


func _bounds(c: Control) -> void:
	var rect := c.get_global_rect()
	_check(rect.position.x >= 0 and rect.position.y >= 0
		and rect.end.x <= 1280 and rect.end.y <= 720, "visible panel/control fits 1280x720: " + c.name)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var deck := _deck()
	_check(deck.size() >= 12 and deck.count("warden_strike") == 2
		and deck.count("seamstress_prick") == 2 and deck.count("tinker_pop_shot") == 2,
		"all real starter duplicate indices exist")
	if deck.size() < 12:
		_finish()
		return
	var ledger := RunRestStitchCards.new(deck, {}, 3)
	_check(ledger.is_valid() and not ledger.is_consumed(), "genuine eligible Rest ledger")
	var receipt := ledger.get_snapshot()
	var model := RunRestStitchPairOptions.new(ledger, receipt)
	_check(model.is_available(), "model accepts authentic complete receipt")
	var firsts := model.first_options()
	_check(firsts.size() == deck.size(), "every original starter instance is first-half eligible")
	for i in range(deck.size()):
		var id: String = deck[i]
		var def := catalog.get_definition(id)
		_check(firsts[i]["index"] == i and firsts[i]["id"] == id
			and firsts[i]["owner"] == def["owner"] and firsts[i]["cost"] == def["cost"],
			"first option preserves shipped instance and authored definition %d" % i)
		var seconds := model.second_options(i)
		var wanted: Array = []
		for j in range(deck.size()):
			if j != i and catalog.get_definition(deck[j])["owner"] != def["owner"]:
				wanted.append(j)
		var actual: Array = []
		for item in seconds:
			actual.append(item["index"])
		_check(actual == wanted, "each second index is precisely an other-owner original at %d" % i)
	_check(firsts[0]["index"] != firsts[1]["index"] and firsts[4]["index"] != firsts[5]["index"]
		and firsts[8]["index"] != firsts[9]["index"], "duplicates are distinct copies")
	var examples := [
		["seamstress_prick", "tinker_pop_shot", 2],
		["warden_shield_bash", "tinker_scrap_bomb", 3],
		["tinker_tune_up", "seamstress_mend", 2],
	]
	for sample in examples:
		var a := _idx(deck, sample[0])
		var b := _idx(deck, sample[1])
		var preview := model.preview(a, b)
		_check(preview.get("energy_cost") == sample[2] and preview.get("scrap_cost") == 3
			and preview.get("first_id") == sample[0] and preview.get("second_id") == sample[1]
			and preview.get("first_index") == a and preview.get("second_index") == b
			and preview.get("first_owner") == catalog.get_definition(sample[0])["owner"]
			and preview.get("second_owner") == catalog.get_definition(sample[1])["owner"]
			and preview.get("first_name") == catalog.get_definition(sample[0])["display_name"]
			and preview.get("second_name") == catalog.get_definition(sample[1])["display_name"]
			and preview.get("first_cost") == catalog.get_definition(sample[0])["cost"]
			and preview.get("second_cost") == catalog.get_definition(sample[1])["cost"]
			and preview.get("source_snapshot") == receipt and preview.get("source_receipt") == receipt["receipt"],
			"exact authored cost, identity, ordered names, source and three-scrap preview " + sample[0])
		var swapped := model.preview(b, a)
		_check(swapped.get("first_id") == sample[1] and swapped.get("second_id") == sample[0]
			and swapped.get("energy_cost") == sample[2] and swapped.get("display_name") != preview.get("display_name"),
			"reverse order swaps halves without changing cost")
	var prick := _idx(deck, "seamstress_prick")
	var pop := _idx(deck, "tinker_pop_shot")
	_check(model.preview(prick, prick).is_empty()
		and model.preview(0, 1).is_empty() and model.preview(-1, pop).is_empty()
		and model.preview(prick, deck.size()).is_empty()
		and model.preview("4", pop).is_empty(), "invalid indices and same-owner pairs forbidden")
	var intact := receipt.duplicate(true)
	var tampered := model.preview(prick, pop)
	tampered["source_snapshot"]["deck"].clear()
	tampered["first_name"] = "forgery"
	firsts[0]["name"] = "forgery"
	model.source_snapshot()["deck"].clear()
	_check(model.preview(prick, pop)["first_name"] == "Prick" and model.source_snapshot() == intact
		and model.first_options()[0]["name"] == "Strike", "all model outputs deeply detached")
	var rng := RandomNumberGenerator.new()
	rng.seed = 10406
	var state := rng.state
	seed(10406)
	var global_next := randi()
	seed(10406)
	_check(model.is_available() and model.preview(prick, pop).size() > 0
		and ledger.get_snapshot() == intact and not ledger.is_consumed()
		and rng.state == state and randi() == global_next,
		"read-only model leaves exact ledger and local/global RNG untouched")

	for scrap in [0, 2]:
		var poor := RunRestStitchCards.new(deck, {}, scrap)
		var poor_model := RunRestStitchPairOptions.new(poor, poor.get_snapshot())
		_check(not poor_model.is_available() and poor_model.first_options().is_empty()
			and poor_model.second_options(prick).is_empty() and poor_model.preview(prick, pop).is_empty()
			and poor.get_snapshot()["remaining_scraps"] == scrap and not poor.is_consumed(),
			"0/2 scraps excludes every pair and spends nothing")
	var invalid := RunRestStitchCards.new([deck[0], "unrecognized"], {}, 3)
	_check(not RunRestStitchPairOptions.new(invalid, invalid.get_snapshot()).is_available(),
		"invalid service with unrecognized ID rejected")
	for key in ["receipt", "deck", "descriptors", "remaining_scraps", "next_stitch_id"]:
		var forged := receipt.duplicate(true)
		match key:
			"receipt": forged[key] = "forged"
			"deck": forged[key][0] = "warden_brace"
			"descriptors": forged[key]["stitched_999999"] = {}
			"remaining_scraps": forged[key] = 99
			"next_stitch_id": forged[key] = 9
		var stale := RunRestStitchPairOptions.new(ledger, forged)
		_check(not stale.is_available() and stale.first_options().is_empty() and stale.preview(prick, pop).is_empty(),
			"mismatched " + key + " fail closed")
	var replaced := RunRestStitchPairOptions.new(ledger, receipt)
	replaced.bind(RunRestStitchCards.new(deck, {}, 2), receipt)
	_check(not replaced.is_available(), "replaced service refuses old source")
	replaced.bind(ledger, receipt)
	_check(replaced.is_available(), "valid rebind following refusal")

	# Actual preceding Rest transaction yields a stitched ID on a later visit.
	var earlier := RunRestStitchCards.new(deck, {}, 6)
	var made := earlier.choose_stitch(prick, pop, earlier.get_snapshot())
	_check(made.get("ok", false), "genuine first stitched descriptor created")
	if made.get("ok", false):
		var later := RunRestStitchCards.new(made["deck"], made["descriptors"], 3, made["next_stitch_id"])
		var later_model := RunRestStitchPairOptions.new(later, later.get_snapshot())
		var composite_index := _idx(made["deck"], made["stitched_id"])
		var all_first := later_model.first_options()
		_check(later.is_valid() and later_model.is_available(), "later Rest genuine descriptor ledger admitted")
		var has_composite := false
		for entry in all_first:
			if entry["index"] == composite_index:
				has_composite = true
			for possible in later_model.second_options(entry["index"]):
				if possible["index"] == composite_index:
					has_composite = true
		_check(not has_composite and later_model.preview(composite_index, 0).is_empty()
			and later_model.preview(0, composite_index).is_empty(), "stitched card cannot be a half")
	var upgraded := RunRestCardUpgrade.new(deck, {"warden_strike":"warden_strike_plus"}).choose_upgrade(0)
	_check(upgraded.get("ok") == true and upgraded["deck"][0] == "warden_strike_plus", "real Rest upgrade performed")
	var upgrade_ledger := RunRestStitchCards.new(upgraded["deck"], {}, 3)
	var upgrade_model := RunRestStitchPairOptions.new(upgrade_ledger, upgrade_ledger.get_snapshot())
	var plus := upgrade_model.preview(0, prick)
	_check(plus.get("first_name") == "Strike+" and plus.get("first_id") == "warden_strike_plus"
		and plus.get("energy_cost") == 2 and plus.get("first_cost") == 1,
		"upgraded authored original stays eligible and cost is accurate")

	picker = LiveRestStitchPairPicker.new()
	picker.name = "DetachedRestStitchPairPicker"
	picker.position = Vector2(330, 180)
	picker.size = Vector2(600, 355)
	root.add_child(picker)
	await _frames()
	picker.stitch_requested.connect(_take)
	picker.bind(ledger, receipt)
	_bounds(picker)
	_bounds(picker.first_selector)
	_bounds(picker.second_selector)
	_bounds(picker.confirm_button)
	_bounds(picker.summary_label)
	_check(picker.first_selector.item_count == deck.size() and picker.second_selector.item_count == 0
		and picker.confirm_button.disabled, "picker starts without synthetic second selection")
	for i in range(deck.size()):
		_check(picker.first_selector.get_item_metadata(i) == i, "UI first duplicate-instance metadata %d" % i)
	var first_item := 4
	await _select_mouse(picker.first_selector, first_item)
	_check(picker.second_selector.item_count > 0 and picker.confirm_button.disabled,
		"mouse first change filters second and blocks premature submit")
	var second_item := -1
	for i in range(picker.second_selector.item_count):
		if picker.second_selector.get_item_metadata(i) == pop:
			second_item = i
	_check(second_item >= 0, "Pop Shot index appears in Prick's cross-hero list")
	if second_item >= 0:
		await _select_mouse(picker.second_selector, second_item)
		_check(not picker.confirm_button.disabled and picker.summary_label.text.contains("Prick / Pop Shot")
			and picker.summary_label.text.contains("2 energy") and picker.summary_label.text.contains("3 scraps"),
			"visible paper summary has correct joined name, energy and scraps")
		var selected_metadata: int = picker.second_selector.get_item_metadata(second_item)
		picker.second_selector.set_item_metadata(second_item, _idx(deck, "tinker_scrap_bomb"))
		await _click(picker.confirm_button)
		_check(received.is_empty() and picker.confirm_button.disabled,
			"metadata remap to another otherwise-valid index cannot request a phantom visual pair")
		picker.second_selector.set_item_metadata(second_item, selected_metadata)
		picker.second_selector.item_selected.emit(second_item)
		_check(not picker.confirm_button.disabled, "valid second selection recovers after forged row")
		await _click(picker.confirm_button)
	_check(received.size() == 1 and received[0]["first"] == prick and received[0]["second"] == pop
		and received[0]["source"] == receipt, "physical mouse emitted exactly one exact original pair/receipt")
	_check(ledger.get_snapshot() == receipt and not ledger.is_consumed(),
		"mouse choice did not commit deck, receipt, descriptor, scraps or latch")
	var oracle := ledger.choose_stitch(received[0]["first"], received[0]["second"], received[0]["source"])
	var expected := deck.duplicate()
	expected.remove_at(maxi(prick, pop))
	expected.remove_at(mini(prick, pop))
	expected.insert(mini(prick, pop), "stitched_000001")
	_check(oracle.get("ok") == true and oracle.get("remaining_scraps") == 0
		and oracle.get("deck") == expected and oracle.get("descriptor") == oracle["descriptors"]["stitched_000001"]
		and oracle.get("consumed_indices") == [prick, pop] and oracle.get("next_stitch_id") == 2
		and oracle.get("source_receipt") == receipt["receipt"],
		"authoritative oracle once: exact 3-scrap transaction, descriptor and original order")
	var signals_before := received.size()
	await _click(picker.confirm_button)
	_check(received.size() == signals_before and ledger.is_consumed(), "consumed service rejects confirmation replay")
	var fresh := RunRestStitchCards.new(deck, {}, 3)
	picker.bind(fresh, fresh.get_snapshot())
	var old_signal := picker._confirm_callback
	picker.clear()
	old_signal.call()
	_check(received.size() == signals_before and picker.confirm_button.disabled,
		"cleared picker disconnects and invalidates old callback")
	picker.bind(fresh, fresh.get_snapshot())
	_check(not picker.first_selector.disabled, "fresh valid rebind restores eligibility")
	picker.first_selector.select(0)
	picker.first_selector.item_selected.emit(0)
	_check(picker.second_selector.item_count > 0 and picker.second_selector.selected == -1
		and picker.confirm_button.disabled, "first-half switch rebuilds other-owner list without preselection")
	picker.first_selector.select(-1)
	await _select_keyboard(picker.first_selector, first_item)
	var keyboard_second := -1
	for i in range(picker.second_selector.item_count):
		if picker.second_selector.get_item_metadata(i) == pop:
			keyboard_second = i
	_check(keyboard_second >= 0, "keyboard first change exposes Pop Shot")
	if keyboard_second >= 0:
		await _select_keyboard(picker.second_selector, keyboard_second)
		picker.second_selector.grab_focus()
		await _key(KEY_TAB)
		_check(picker.confirm_button.has_focus(), "keyboard Tab reaches confirmation")
		await _key(KEY_ENTER)
	_check(received.size() == signals_before + 1
		and received.back() == {"first":prick,"second":pop,"source":fresh.get_snapshot()},
		"physical keyboard emits same exact pair/receipt, only once")
	_check(fresh.get_snapshot() == receipt and not fresh.is_consumed(),
		"keyboard selection only requests, does not pay")
	var refusal_rng := RandomNumberGenerator.new()
	refusal_rng.seed = 104061
	var local_before := refusal_rng.state
	seed(104061)
	var global_expected := randi()
	seed(104061)
	var before_refusal := fresh.get_snapshot()
	var original_source := fresh._source_snapshot.duplicate(true)
	fresh._source_snapshot["receipt"] = "stale"
	picker._confirm_callback.call()
	_check(received.size() == signals_before + 1 and fresh.get_snapshot() == before_refusal
		and not fresh.is_consumed(), "stale authoritative source refuses without ledger/signal mutation")
	fresh._source_snapshot = original_source
	picker.hide()
	picker._confirm_callback.call()
	_check(received.size() == signals_before + 1, "hidden closed picker refuses retained callback")
	picker.show()
	var retained_old := picker._confirm_callback
	var poor_ui := RunRestStitchCards.new(deck, {}, 2)
	picker.bind(poor_ui, poor_ui.get_snapshot())
	retained_old.call()
	_check(picker.first_selector.disabled and picker.confirm_button.disabled
		and received.size() == signals_before + 1 and poor_ui.get_snapshot()["remaining_scraps"] == 2,
		"service replacement with insufficient purse fails closed and old callbacks inert")
	picker.bind(fresh, fresh.get_snapshot())
	_check(not picker.first_selector.disabled and picker.first_selector.item_count == deck.size(),
		"fresh rebind after stale, closed and replacement refusals is selectable")
	_check(refusal_rng.state == local_before and randi() == global_expected,
		"all stale/hidden/affordability/service replacement refusals consume no local or global RNG")
	var old_bound := picker._confirm_callback
	root.remove_child(picker)
	old_bound.call()
	_check(received.size() == signals_before + 1, "removed picker cannot emit from retained callback")
	picker.free()
	var prebound := LiveRestStitchPairPicker.new()
	prebound.size = Vector2(600, 355)
	prebound.bind(fresh, fresh.get_snapshot())
	root.add_child(prebound)
	await _frames()
	_check(prebound.first_selector.item_count == deck.size()
		and not prebound.first_selector.disabled and prebound.confirm_button.disabled,
		"binding detached component before mounting preserves genuine source and safe initial selection")
	prebound.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("rest_stitch_pair_picker_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks; ", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
