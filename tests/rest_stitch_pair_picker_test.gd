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


func _assert_authored(preview: Dictionary, first_id: String, second_id: String, label: String) -> void:
	_check(not preview.is_empty(), label + " yields a real preview")
	if preview.is_empty():
		return
	for half_name in ["first_half", "second_half"]:
		var id: String = first_id if half_name == "first_half" else second_id
		var half: Dictionary = preview.get(half_name, {})
		var authored := RunRestStitchCards.resolve_card_definition(id)
		_check(not authored.is_empty() and half == authored,
			label + " " + half_name + " matches every shipped definition field")
		for field in ["id", "display_name", "owner", "cost", "from_positions",
				"target_kind", "to_positions", "effects"]:
			_check(half.get(field) == authored.get(field), label + " " + half_name + " " + field)


func _assert_projection(model: RunRestStitchPairOptions, source: Dictionary,
		first_index: int, second_index: int, label: String) -> Dictionary:
	var original_source := source.duplicate(true)
	var service_before := model._service.get_snapshot()
	var was_consumed := model._service.is_consumed()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42832
	var rng_before := rng.state
	seed(42832)
	var next_global := randi()
	seed(42832)
	var predicted := model.preview(first_index, second_index)
	var oracle := RunRestStitchCards.new(
		source["deck"].duplicate(true), source["descriptors"].duplicate(true),
		source["remaining_scraps"], source["next_stitch_id"])
	_check(oracle.is_valid() and oracle.get_snapshot() == source, label + " authentic detached oracle")
	if predicted.is_empty() or not oracle.is_valid():
		_check(false, label + " nonempty legal preview")
		return {}
	var actual := oracle.choose_stitch(first_index, second_index, source.duplicate(true))
	_check(actual.get("ok", false) and predicted.get("projection") == actual,
		label + " complete oracle result including full registry, deck, receipts and cursor")
	_check(predicted["stitched_id"] == actual["stitched_id"]
		and predicted["descriptor"] == actual["descriptor"]
		and predicted["resulting_deck"] == actual["deck"]
		and predicted["remaining_scraps"] == actual["remaining_scraps"]
		and predicted["next_stitch_id"] == actual["next_stitch_id"]
		and predicted["consumed_indices"] == [first_index, second_index]
		and predicted["consumed_ids"] == [source["deck"][first_index], source["deck"][second_index]]
		and predicted["deck_before_count"] == source["deck"].size()
		and predicted["deck_after_count"] == actual["deck"].size()
		and actual["deck"].size() == source["deck"].size() - 1
		and actual["remaining_scraps"] == source["remaining_scraps"] - 3
		and actual["next_stitch_id"] == source["next_stitch_id"] + 1
		and actual["descriptor"]["cost"] == mini(3, maxi(
			predicted["first_half"]["cost"], predicted["second_half"]["cost"]) + 1)
		and not actual["descriptor"]["can_upgrade"] and not actual["descriptor"]["can_stitch"],
		label + " exact instance, canonical descriptor, insertion, cost and economics")
	_check(source == original_source and model._service.get_snapshot() == service_before
		and model._service.is_consumed() == was_consumed
		and rng.state == rng_before and randi() == next_global,
		label + " preview and oracle do not mutate source, real Rest or either RNG")
	return predicted


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
	await _frames()
	if picker != null and not picker.first_tiles.is_empty():
		var is_first: bool = (button == picker.first_selector)
		if is_first and picker.second_tile_scroll.visible:
			picker._return_to_first_choice()
			await _frames()
		var meta: Variant = button.get_item_metadata(target)
		var tile: Button = picker.first_tile_for_index(int(meta)) if is_first else picker.second_tile_for_index(int(meta))
		_check(tile != null and tile.is_visible_in_tree(), "mouse target card tile is mounted")
		if tile != null:
			await _click(tile)
			_check(button.selected == target, "physical mouse selected item %d via tile" % target)
			return
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
	await _frames()
	if picker != null and not picker.first_tiles.is_empty():
		var is_first: bool = (button == picker.first_selector)
		if is_first and picker.second_tile_scroll.visible:
			picker._return_to_first_choice()
			await _frames()
		var meta: Variant = button.get_item_metadata(target)
		var tile: Button = picker.first_tile_for_index(int(meta)) if is_first else picker.second_tile_for_index(int(meta))
		_check(tile != null and tile.is_visible_in_tree(), "keyboard target card tile is mounted")
		if tile != null:
			tile.grab_focus()
			_check(tile.has_focus(), "card tile has keyboard focus")
			await _key(KEY_ENTER)
			_check(button.selected == target, "physical keyboard selected item %d via tile" % target)
			return
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


func _assert_sewn_caption(panel: LiveRestStitchPairPicker, a: int, b: int,
		first_name: String, second_name: String, deck_count: int, scraps_left: int,
		label: String) -> void:
	var forecast := panel._model.preview(a, b)
	_check(not forecast.is_empty() and panel._current_pair() == forecast,
		label + " rendered from the real selected indices and detached forecast")
	if forecast.is_empty():
		return
	var expected := "Sew %s (copy #%d) + %s (copy #%d)\n%d → %d shared cards • 3 scraps spent • %d remaining\nSewn card cannot upgrade or stitch again" % [
		first_name, a + 1, second_name, b + 1, deck_count, deck_count - 1, scraps_left]
	var caption := panel.consequence_label.text
	_check(caption == expected and panel.consequence_label.get_line_count() <= 3,
		label + " shows exact ordered names, one-based copies, deck delta, scrap spend and permanent rule")
	_check(not caption.contains("0-based") and not caption.contains("stitched_")
		and not caption.contains(str(forecast["first_id"]))
		and not caption.contains(str(forecast["second_id"])),
		label + " hides internal identifiers and zero-based terminology")
	_check(forecast["first_index"] == a and forecast["second_index"] == b
		and forecast["deck_before_count"] == deck_count
		and forecast["deck_after_count"] == deck_count - 1
		and forecast["scrap_cost"] == 3 and forecast["remaining_scraps"] == scraps_left,
		label + " visible projection retains exact zero-based oracle indices and economic fields")


## The first/second half must mount that original's own illustration (a final
## "_plus" shares its base picture) on its owner-colour cloth, with no fallback.
func _thumb_ok(p: LiveRestStitchPairPicker, which: String, card_id: String, owner: String) -> void:
	var state := p.thumbnail_state(which)
	var expected_path := LiveRestStitchPairPicker.art_path(card_id)
	_check(expected_path == "res://assets/paper/cards/art/%s.png" % card_id.trim_suffix("_plus"),
		"%s %s resolves only the authored base picture path" % [which, card_id])
	_check(state.get("visible", false) and state.get("texture") != null
		and state.get("path", "") == expected_path,
		"%s half physically shows the %s illustration at %s" % [which, card_id, expected_path])
	_check(not state.get("placeholder_visible", true),
		"%s half does not show the fallback beside real art" % which)
	_check(state.get("owner_color") == LiveRestStitchPairPicker.OWNER_COLORS[owner],
		"%s thumbnail carries the %s owner cloth" % [which, owner])
	_bounds(p.first_thumbnail)
	_bounds(p.second_thumbnail)


## Either the committed authored picture or the readable owner-colour sewn-paper
## fallback, never a broken image. Art committed later must not break this check.
func _thumb_present_or_placeholder(p: LiveRestStitchPairPicker, which: String, card_id: String,
		display_name: String, owner: String) -> void:
	var state := p.thumbnail_state(which)
	if state.get("texture") != null:
		_check(state.get("visible", false)
			and state.get("path", "") == LiveRestStitchPairPicker.art_path(card_id),
			"%s half shows the authored %s picture" % [which, card_id])
	else:
		_check(state.get("placeholder_visible", false) and state.get("path", "") == ""
			and state.get("name", "") == display_name
			and state.get("owner_color") == LiveRestStitchPairPicker.OWNER_COLORS[owner],
			"%s half shows a readable %s owner-colour placeholder" % [which, owner])


func _thumbs_cleared(p: LiveRestStitchPairPicker, label: String) -> void:
	for which in ["first", "second"]:
		var state := p.thumbnail_state(which)
		_check(state.get("path", "") == "" and state.get("texture") == null
			and not state.get("visible", true) and not state.get("placeholder_visible", true),
			label + " clears the " + which + " illustration and fallback")


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
	_check(_idx(deck, "warden_strike", 0) != _idx(deck, "warden_strike", 1)
		and _idx(deck, "seamstress_prick", 0) != _idx(deck, "seamstress_prick", 1)
		and _idx(deck, "tinker_pop_shot", 0) != _idx(deck, "tinker_pop_shot", 1),
		"real duplicate originals occupy different source indices")
	# Each legally selectable instance pair must retain both entire shipped
	# definitions, including targeting and nested status/effect fields.
	for i in range(deck.size()):
		for second in model.second_options(i):
			var j: int = second["index"]
			_assert_authored(model.preview(i, j), deck[i], deck[j],
				"eligible source indices %d -> %d" % [i, j])
			_assert_projection(model, receipt, i, j, "all legal indices %d -> %d" % [i, j])
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
		_assert_authored(preview, sample[0], sample[1], "named pair " + sample[0])
		_assert_projection(model, receipt, a, b, "named pair " + sample[0])
		var swapped := _assert_projection(model, receipt, b, a, "reversed " + sample[0])
		_assert_authored(swapped, sample[1], sample[0], "reversed named pair " + sample[0])
		_check(swapped.get("first_id") == sample[1] and swapped.get("second_id") == sample[0]
			and swapped.get("energy_cost") == sample[2] and swapped.get("display_name") != preview.get("display_name"),
			"reverse order swaps halves without changing cost")
	var prick := _idx(deck, "seamstress_prick")
	var pop := _idx(deck, "tinker_pop_shot")
	var second_strike := _idx(deck, "warden_strike", 1)
	var first_strike := _idx(deck, "warden_strike", 0)
	var dup_pair := _assert_projection(model, receipt, prick, second_strike,
		"Prick plus second duplicate Strike only")
	var reverse_dup := _assert_projection(model, receipt, second_strike, prick,
		"reversed duplicate Strike plus Prick")
	_check(not dup_pair.is_empty() and not reverse_dup.is_empty()
		and dup_pair["resulting_deck"][first_strike] == "warden_strike"
		and dup_pair["resulting_deck"].count("warden_strike") == 1
		and dup_pair["resulting_deck"][second_strike] == "stitched_000001"
		and reverse_dup["resulting_deck"] == dup_pair["resulting_deck"]
		and reverse_dup["descriptor"]["half_ids"] == ["warden_strike", "seamstress_prick"]
		and dup_pair["descriptor"]["half_ids"] == ["seamstress_prick", "warden_strike"]
		and reverse_dup["descriptor"]["display_name"] != dup_pair["descriptor"]["display_name"],
		"second original instance alone replaced; reverse leaves insertion index but changes ordered halves")
	_check(model.preview(prick, prick).is_empty()
		and model.preview(0, 1).is_empty() and model.preview(-1, pop).is_empty()
		and model.preview(prick, deck.size()).is_empty()
		and model.preview("4", pop).is_empty(), "invalid indices and same-owner pairs forbidden")
	var intact := receipt.duplicate(true)
	var tampered := model.preview(prick, pop)
	tampered["source_snapshot"]["deck"].clear()
	tampered["first_half"]["effects"]["bleed"] = 999
	tampered["first_half"]["from_positions"].clear()
	tampered["second_half"]["to_positions"].clear()
	tampered["first_name"] = "forgery"
	firsts[0]["name"] = "forgery"
	model.source_snapshot()["deck"].clear()
	_check(model.preview(prick, pop)["first_name"] == "Prick" and model.source_snapshot() == intact
		and model.first_options()[0]["name"] == "Strike"
		and model.preview(prick, pop)["first_half"] == catalog.get_definition("seamstress_prick")
		and model.preview(prick, pop)["second_half"] == catalog.get_definition("tinker_pop_shot"),
		"nested effects, position arrays, receipts and model outputs deeply detached")
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
		var later_source := later.get_snapshot()
		var later_model := RunRestStitchPairOptions.new(later, later_source)
		var later_pair := _assert_projection(later_model, later_source,
			_idx(made["deck"], "warden_strike"), _idx(made["deck"], "seamstress_mend"),
			"prior composite retained and next serial")
		_check(not later_pair.is_empty() and later_pair["stitched_id"] == "stitched_000002"
			and later_pair["projection"]["descriptors"][made["stitched_id"]] == made["descriptor"]
			and later_pair["next_stitch_id"] == 3 and later.get_snapshot() == later_source,
			"later forecast leaves old descriptor and allocator untouched")
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
	_assert_authored(plus, "warden_strike_plus", "seamstress_prick", "upgraded Strike+")
	var upgraded_pop := upgrade_model.preview(0, _idx(upgraded["deck"], "tinker_pop_shot"))
	_assert_authored(upgraded_pop, "warden_strike_plus", "tinker_pop_shot",
		"upgraded Strike+ / Pop Shot")
	_check(upgraded_pop.get("first_half", {}).get("effects", {}).get("damage") == 7,
		"upgraded half shows seven damage, not Strike's six")

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
	_bounds(picker.first_half_label)
	_bounds(picker.second_half_label)
	_check(picker.first_half_label.get_global_rect().end.y <
		picker.second_half_label.get_global_rect().position.y
		and picker.second_half_label.get_global_rect().end.y <
		picker.confirm_button.get_global_rect().position.y,
		"first and second three-line rules never overlap each other or confirm")
	_check(picker.first_selector.item_count == deck.size() and picker.second_selector.item_count == 0
		and picker.confirm_button.disabled, "picker starts without synthetic second selection")
	for i in range(deck.size()):
		_check(picker.first_selector.get_item_metadata(i) == i, "UI first duplicate-instance metadata %d" % i)
	# Both identical Strike instances keep different displayed copy numbers and exact indices.
	for strike_index in [second_strike, first_strike]:
		picker.first_selector.select(strike_index)
		picker.first_selector.item_selected.emit(strike_index)
		var prick_row := _row_in_second(picker, prick)
		_check(prick_row >= 0, "Strike / Prick offers the selected cross-owner instance")
		if prick_row >= 0:
			picker.second_selector.select(prick_row)
			picker.second_selector.item_selected.emit(prick_row)
			_assert_sewn_caption(picker, strike_index, prick, "Strike", "Prick",
				deck.size(), 0, "mounted Strike / Prick duplicate copy #%d" % (strike_index + 1))
	# A separate area/Weak pair must show its independent front-only and
	# all-enemy rules, without inventing Warden's opening Block as an effect.
	var bash_index := _idx(deck, "warden_shield_bash")
	var bomb_index := _idx(deck, "tinker_scrap_bomb")
	picker.first_selector.select(bash_index)
	picker.first_selector.item_selected.emit(bash_index)
	var bomb_row := -1
	for i in range(picker.second_selector.item_count):
		if picker.second_selector.get_item_metadata(i) == bomb_index:
			bomb_row = i
	_check(bomb_row >= 0, "authored Shield Bash / Scrap Bomb can be selected")
	if bomb_row >= 0:
		picker.second_selector.select(bomb_row)
		picker.second_selector.item_selected.emit(bomb_row)
		_check(picker.summary_label.text.contains("Shield Bash / Scrap Bomb • 3 energy • 3 scraps")
			and picker.first_half_label.text ==
				"First: Shield Bash — Warden (2 energy)\nFrom hero positions 1; choose one enemy in positions 1\n8 damage; Weak 1"
			and picker.second_half_label.text ==
				"Second: Scrap Bomb — Tinker (2 energy)\nFrom hero positions 3; all eligible enemies in positions 1-3\n4 damage to each eligible enemy (first Tinker attack this turn: +3 damage)",
			"mounted area/Weak pair displays exact separate legality and conditional attack")
		_check(picker.consequence_label.text == picker._consequence_lines(
			picker._model.preview(bash_index, bomb_index)),
			"nontrivial area pair shows exact deck and scrap consequence")
	# Self-only Brace must not invent an enemy selection or the Warden's
	# unrelated start-of-combat passive; living ally Block is separate.
	for support in ["warden_brace", "seamstress_stitch_up"]:
		var support_index := _idx(deck, support)
		picker.first_selector.select(support_index)
		picker.first_selector.item_selected.emit(support_index)
		var support_pop_row := -1
		for i in range(picker.second_selector.item_count):
			if picker.second_selector.get_item_metadata(i) == pop:
				support_pop_row = i
		_check(support_pop_row >= 0, support + " can display a cross-hero second half")
		if support_pop_row >= 0:
			picker.second_selector.select(support_pop_row)
			picker.second_selector.item_selected.emit(support_pop_row)
			var expected_support := (
				"First: Brace — Warden (1 energy)\nFrom hero positions 1-3; self (no chosen target)\nBlock 7"
				if support == "warden_brace" else
				"First: Stitch Up — Seamstress (1 energy)\nFrom hero positions 1-3; choose one living ally in positions 1-3\nBlock 5")
			_check(picker.first_half_label.text == expected_support,
				support + " shows authored self/living-ally Block, without combat-start passive")
	picker.bind(upgrade_ledger, upgrade_ledger.get_snapshot())
	picker.first_selector.select(0)
	picker.first_selector.item_selected.emit(0)
	var upgrade_pop_row := -1
	for i in range(picker.second_selector.item_count):
		if picker.second_selector.get_item_metadata(i) == _idx(upgraded["deck"], "tinker_pop_shot"):
			upgrade_pop_row = i
	_check(upgrade_pop_row >= 0, "mounted upgraded Strike+ can pair with Pop Shot")
	if upgrade_pop_row >= 0:
		picker.second_selector.select(upgrade_pop_row)
		picker.second_selector.item_selected.emit(upgrade_pop_row)
		_check(picker.first_half_label.text.contains("First: Strike+")
			and picker.first_half_label.text.contains("7 damage")
			and not picker.first_half_label.text.contains("6 damage"),
			"mounted Strike+ uses the authored upgraded damage, not base Strike")
		_thumb_ok(picker, "first", "warden_strike_plus", "warden")
		_check(picker.thumbnail_state("first")["path"].ends_with("/warden_strike.png"),
			"upgraded Strike+ mounts the base Strike picture, not a synthetic _plus image")
	picker.bind(ledger, receipt)
	var ui_rng := RandomNumberGenerator.new()
	ui_rng.seed = 1080701
	var ui_rng_before := ui_rng.state
	seed(1080701)
	var ui_global_next := randi()
	seed(1080701)
	var first_item := prick
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
		_assert_sewn_caption(picker, prick, pop, "Prick", "Pop Shot", 12, 0,
			"mouse-visible Prick / Pop Shot forecast")
		_check(picker.first_half_label.text ==
			"First: Prick — Seamstress (1 energy)\nFrom hero positions 1-3; choose one enemy in positions 1-3\n3 damage; Bleed 2 (+1 Bleed if applied: Seamstress passive)",
			"mouse-visible first half spells out exact authored Bleed and conditional Seamstress bonus")
		_check(picker.second_half_label.text ==
			"Second: Pop Shot — Tinker (1 energy)\nFrom hero positions 2-3; choose one enemy in positions 1-3\n5 damage (first Tinker attack this turn: +3 damage)",
			"mouse-visible second half spells out target, damage and conditional first attack")
		_check(picker.first_half_label.get_line_count() <= 4
			and picker.second_half_label.get_line_count() <= 4,
			"both detailed half readouts stay unclipped at 1280x720")
		_check(picker.first_half_label.get_global_rect().end.x <= picker.first_thumbnail.get_global_rect().position.x
			and picker.second_half_label.get_global_rect().end.x <= picker.second_thumbnail.get_global_rect().position.x,
			"both authored rules end before their illustration gutter")
		_thumb_ok(picker, "first", "seamstress_prick", "seamstress")
		_thumb_ok(picker, "second", "tinker_pop_shot", "tinker")
		_check(picker.thumbnail_state("first")["texture"] != picker.thumbnail_state("second")["texture"],
			"Prick and Pop Shot mount two distinct illustrations")
		# Reversing the ordered selection swaps the two mounted pictures.
		picker.first_selector.select(pop)
		picker.first_selector.item_selected.emit(pop)
		var reverse_row := -1
		for i in range(picker.second_selector.item_count):
			if picker.second_selector.get_item_metadata(i) == prick:
				reverse_row = i
		_check(reverse_row >= 0, "reversed Pop Shot / Prick pair is selectable")
		if reverse_row >= 0:
			picker.second_selector.select(reverse_row)
			picker.second_selector.item_selected.emit(reverse_row)
			_thumb_ok(picker, "first", "tinker_pop_shot", "tinker")
			_thumb_ok(picker, "second", "seamstress_prick", "seamstress")
		picker.first_selector.select(prick)
		picker.first_selector.item_selected.emit(prick)
		second_item = -1
		for i in range(picker.second_selector.item_count):
			if picker.second_selector.get_item_metadata(i) == pop:
				second_item = i
		_check(second_item >= 0, "restored Prick / Pop Shot order is selectable")
		picker.second_selector.select(second_item)
		picker.second_selector.item_selected.emit(second_item)
		var selected_metadata: int = picker.second_selector.get_item_metadata(second_item)
		picker.second_selector.set_item_metadata(second_item, _idx(deck, "tinker_scrap_bomb"))
		await _click(picker.confirm_button)
		_check(received.is_empty() and picker.confirm_button.disabled,
			"metadata remap to another otherwise-valid index cannot request a phantom visual pair")
		_check(picker.first_half_label.text.is_empty() and picker.second_half_label.text.is_empty()
			and picker.consequence_label.text.is_empty()
			and picker.summary_label.text.contains("Not available"),
			"forged row clears stale authored rules as well as disabling confirmation")
		_thumbs_cleared(picker, "metadata rejection")
		picker.first_selector.item_selected.emit(first_item)
		second_item = -1
		for i in range(picker.second_selector.item_count):
			if picker.second_selector.get_item_metadata(i) == pop:
				second_item = i
		if second_item >= 0:
			picker.second_selector.select(second_item)
			picker.second_selector.item_selected.emit(second_item)
		_check(not picker.confirm_button.disabled, "reselecting a genuine pair recovers after forged row")
		await _click(picker.confirm_button)
	_check(received.size() == 1 and received[0]["first"] == prick and received[0]["second"] == pop
		and received[0]["source"] == receipt, "physical mouse emitted exactly one exact original pair/receipt")
	_check(picker.confirm_button.disabled and picker.first_half_label.text.is_empty()
		and picker.second_half_label.text.is_empty() and picker.consequence_label.text.is_empty(), "one-shot request hides resolved pair until rebind")
	_thumbs_cleared(picker, "one-shot request")
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
	# Keyboard uses a different pair: Tune Up draws without a target, then
	# Mend chooses a living ally. The half order is not cosmetic.
	picker.first_selector.select(-1)
	var tune_index := _idx(deck, "tinker_tune_up")
	var mend_index := _idx(deck, "seamstress_mend")
	await _select_keyboard(picker.first_selector, tune_index)
	var keyboard_second := -1
	for i in range(picker.second_selector.item_count):
		if picker.second_selector.get_item_metadata(i) == mend_index:
			keyboard_second = i
	_check(keyboard_second >= 0, "keyboard first change exposes Mend")
	if keyboard_second >= 0:
		await _select_keyboard(picker.second_selector, keyboard_second)
		_check(picker.summary_label.text.contains("Tune Up / Mend • 2 energy • 3 scraps")
			and picker.first_half_label.text ==
				"First: Tune Up — Tinker (0 energy)\nFrom hero positions 1-3; no target to choose\ndraw 1"
			and picker.second_half_label.text ==
				"Second: Mend — Seamstress (1 energy)\nFrom hero positions 2-3; choose one living ally in positions 1-3\nheal 5",
			"keyboard-visible draw and targeted living-ally heal are exact and ordered")
		_thumb_ok(picker, "first", "tinker_tune_up", "tinker")
		_thumb_ok(picker, "second", "seamstress_mend", "seamstress")
		picker.second_selector.grab_focus()
		await _key(KEY_TAB)
		_check(picker.confirm_button.has_focus(), "keyboard Tab reaches confirmation")
		await _key(KEY_ENTER)
	_check(received.size() == signals_before + 1
		and received.back() == {"first":tune_index,"second":mend_index,"source":fresh.get_snapshot()},
		"physical keyboard emits Tune Up / Mend exact indices/receipt, only once")
	_check(fresh.get_snapshot() == receipt and not fresh.is_consumed(),
		"keyboard selection only requests, does not pay")
	_check(ui_rng.state == ui_rng_before and randi() == ui_global_next,
		"mouse/keyboard, previews and authoritative receipt never draw local/global RNG")
	# Re-arm a genuinely selected pair before making its authoritative source
	# stale: this tests removal of *visible* stale rules, not an empty panel.
	picker.bind(fresh, fresh.get_snapshot())
	picker.first_selector.select(prick)
	picker.first_selector.item_selected.emit(prick)
	var stale_pop_row := -1
	for i in range(picker.second_selector.item_count):
		if picker.second_selector.get_item_metadata(i) == pop:
			stale_pop_row = i
	if stale_pop_row >= 0:
		picker.second_selector.select(stale_pop_row)
		picker.second_selector.item_selected.emit(stale_pop_row)
	_check(stale_pop_row >= 0 and not picker.confirm_button.disabled
		and not picker.first_half_label.text.is_empty()
		and not picker.second_half_label.text.is_empty(), "real pair visibly armed before stale receipt")
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
		and not fresh.is_consumed() and picker.confirm_button.disabled
		and picker.first_half_label.text.is_empty() and picker.second_half_label.text.is_empty()
		and picker.consequence_label.text.is_empty(),
		"stale authoritative source refuses without ledger/signal or stale-preview mutation")
	_thumbs_cleared(picker, "stale authoritative source")
	fresh._source_snapshot = original_source
	picker.hide()
	_check(picker.consequence_label.text.is_empty() and picker.confirm_button.disabled,
		"hiding picker clears actionable consequence")
	_thumbs_cleared(picker, "hiding picker")
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
	await _test_thumbnail_fallbacks()
	await _test_keyword_help_picker()
	await _test_mixed_pool_picker()
	await _test_snip_conditional_descriptions()
	await _test_submitted_single_intent_latch()
	_finish()


## A legal original with no committed illustration must keep the owner-colour
## sewn-paper placeholder with its readable name, and must never leave a
## previous picture behind after any lifecycle reset.
func _test_thumbnail_fallbacks() -> void:
	var fallback_deck: Array[String] = ["seamstress_running_stitch", "warden_strike"]
	var fallback_ledger := RunRestStitchCards.new(fallback_deck, {}, 3)
	_check(fallback_ledger.is_valid(), "genuine no-committed-art ledger is valid")
	var panel := LiveRestStitchPairPicker.new()
	panel.name = "FallbackRestStitchPairPicker"
	panel.position = Vector2(330, 180)
	panel.size = Vector2(600, 355)
	root.add_child(panel)
	await _frames()
	panel.bind(fallback_ledger, fallback_ledger.get_snapshot())
	_thumbs_cleared(panel, "initial bind")
	panel.first_selector.select(0)
	panel.first_selector.item_selected.emit(0)
	_check(not panel.thumbnail_state("first").get("visible", true)
		and not panel.thumbnail_state("second").get("visible", true),
		"first-only selection shows no stale picture on either half")
	panel.second_selector.select(0)
	panel.second_selector.item_selected.emit(0)
	_check(not panel.confirm_button.disabled and panel.first_half_label.text.begins_with("First: Running Stitch"),
		"no-committed-art original still forms a legal presented pair")
	var state := panel.thumbnail_state("first")
	if state.get("texture") != null:
		# Art may be added later; then the half must show it, never a fake absence.
		_check(state["path"] == LiveRestStitchPairPicker.art_path("seamstress_running_stitch")
			and state["visible"], "Running Stitch shows its authored picture when committed")
	else:
		_check(state.get("placeholder_visible", false) and state.get("path", "") == ""
			and state.get("name", "") == "Running Stitch"
			and state.get("owner_color") == LiveRestStitchPairPicker.OWNER_COLORS["seamstress"],
			"Running Stitch falls back to a readable owner-colour sewn-paper placeholder")
	_thumb_ok(panel, "second", "warden_strike", "warden")
	# Changing only the first half clears both pictures before a new second half.
	panel.first_selector.select(1)
	panel.first_selector.item_selected.emit(1)
	_thumbs_cleared(panel, "first-half change before second selection")
	_check(panel.second_selector.item_count == 1, "other-owner Running Stitch becomes the new second list")
	panel.second_selector.select(0)
	panel.second_selector.item_selected.emit(0)
	_thumb_ok(panel, "first", "warden_strike", "warden")
	var reversed_state := panel.thumbnail_state("second")
	if reversed_state.get("texture") != null:
		_check(reversed_state["path"] == LiveRestStitchPairPicker.art_path("seamstress_running_stitch"),
			"reversed fallback half shows authored art when committed")
	else:
		_check(reversed_state.get("placeholder_visible", false)
			and reversed_state.get("name", "") == "Running Stitch",
			"reversed fallback half keeps the readable sewn-paper placeholder")
	panel.clear()
	_thumbs_cleared(panel, "clear")
	var source: Dictionary = fallback_ledger.get_snapshot()
	panel.bind(fallback_ledger, source)
	panel.first_selector.select(0)
	panel.first_selector.item_selected.emit(0)
	panel.second_selector.select(0)
	panel.second_selector.item_selected.emit(0)
	_check(panel.thumbnail_state("second").get("visible", false), "rebind restores the warden illustration")
	panel.hide()
	_thumbs_cleared(panel, "hidden panel")
	panel.show()
	panel.bind(fallback_ledger, source)
	panel.first_selector.select(0)
	panel.first_selector.item_selected.emit(0)
	panel.second_selector.select(0)
	panel.second_selector.item_selected.emit(0)
	var taken: Array[Dictionary] = []
	panel.stitch_requested.connect(func(a, b, s): taken.append({"first": a, "second": b, "source": s}))
	panel._confirm_callback.call()
	_check(taken.size() == 1 and taken[0]["first"] == 0 and taken[0]["second"] == 1
		and taken[0]["source"] == source and not fallback_ledger.is_consumed()
		and fallback_ledger.get_snapshot() == source,
		"one-shot fallback request emits exact intent only; the Rest owner keeps the ledger")
	_thumbs_cleared(panel, "fulfilled one-shot request")
	panel.bind(fallback_ledger, source)
	panel.first_selector.select(0)
	panel.first_selector.item_selected.emit(0)
	panel.second_selector.select(0)
	panel.second_selector.item_selected.emit(0)
	var first_state := panel.thumbnail_state("first")
	_check(panel.thumbnail_state("second").get("visible", false)
		and (first_state.get("path", "") == LiveRestStitchPairPicker.art_path("seamstress_running_stitch")
			or first_state.get("placeholder_visible", false)),
		"re-entry after the one-shot request shows only the current pair's pictures")
	panel.free()


## AC1/AC2: authentic Snip the Seam base/+ conditional REPLACEMENT damage is
## described from the authored structure in both half positions, ordinary attacks
## gain no conditional sentence, and the read-only preview leaves the ledger and
## RNG untouched.
func _test_snip_conditional_descriptions() -> void:
	var snip_deck: Array[String] = [
		"tinker_snip_the_seam",       # 0 base
		"tinker_snip_the_seam_plus",  # 1 plus
		"warden_strike",              # 2 ordinary Warden attack
		"seamstress_prick",           # 3 ordinary Seamstress attack
	]
	var snip_ledger := RunRestStitchCards.new(snip_deck, {}, 3)
	_check(snip_ledger.is_valid() and not snip_ledger.is_consumed(),
		"authentic Snip base/+ ledger is valid before display")
	var snip_receipt := snip_ledger.get_snapshot()
	var snip_model := RunRestStitchPairOptions.new(snip_ledger, snip_receipt)
	_check(snip_model.is_available(), "Snip base/+ ledger model available")
	# The authored definitions keep their real replacement numbers; the display
	# must never invent a summed value or infer from the card ID.
	var base_def := RunRestStitchCards.resolve_card_definition("tinker_snip_the_seam")
	var plus_def := RunRestStitchCards.resolve_card_definition("tinker_snip_the_seam_plus")
	var base_condition: Dictionary = base_def.get("effects", {}).get("conditional_damage", {})
	var plus_condition: Dictionary = plus_def.get("effects", {}).get("conditional_damage", {})
	_check(base_def.get("effects", {}).get("damage") == 5 and base_condition.get("damage") == 15
		and base_condition.get("operator") == "or" and base_condition.get("conditions", []).size() == 2,
		"base Snip authors 5 damage and an OR conditional 15")
	_check(plus_def.get("effects", {}).get("damage") == 7 and plus_condition.get("damage") == 20
		and plus_condition.get("operator") == "or" and plus_condition.get("conditions", []).size() == 2,
		"plus Snip authors 7 damage and an OR conditional 20")
	_check(base_condition["conditions"][0] == {"status": "unravelled"}
		and base_condition["conditions"][1] == {"gauge": "unravel", "comparison": "at_least_half",
			"threshold": "current_target_threshold"},
		"authored Snip predicates are Unravelled OR at_least_half current threshold")

	var base_effect := "5 damage, or 15 instead if Unravelled or Unravel is at least half its current threshold (first Tinker attack this turn: +3 damage)"
	var plus_effect := "7 damage, or 20 instead if Unravelled or Unravel is at least half its current threshold (first Tinker attack this turn: +3 damage)"

	# Model half_lines describe both orders using the real authored definitions.
	var base_first := snip_model.preview(0, 2)
	_check(not base_first.is_empty() and base_first["first_half"] == base_def
		and base_first["second_half"] == RunRestStitchCards.resolve_card_definition("warden_strike"),
		"Snip base / Strike preview uses authentic authored halves")
	if not base_first.is_empty():
		var first_line := LiveRestStitchPairPicker.new()._half_lines("First", base_first["first_half"])
		_check(first_line ==
			"First: Snip the Seam — Tinker (1 energy)\nFrom hero positions 2-3; choose one enemy in positions 1-3\n" + base_effect,
			"_half_lines renders authored 5-vs-15 replacement for the first half")
		_check(not first_line.contains("5+15") and not first_line.contains("5 + 15")
			and not first_line.contains("20") and not first_line.contains("7 damage"),
			"first-half Snip text never sums or borrows the other form")
		var second_line := LiveRestStitchPairPicker.new()._half_lines("Second", base_first["second_half"])
		_check(second_line.contains("6 damage") and not second_line.contains("instead")
			and not second_line.contains("Unravelled") and not second_line.contains("threshold"),
			"ordinary Warden Strike half gains no conditional clause")
	var base_second := snip_model.preview(2, 0)
	_check(not base_second.is_empty() and base_second["second_half"] == base_def,
		"Strike / Snip base preview keeps Snip as the second half")
	if not base_second.is_empty():
		var rev_line := LiveRestStitchPairPicker.new()._half_lines("Second", base_second["second_half"])
		_check(rev_line ==
			"Second: Snip the Seam — Tinker (1 energy)\nFrom hero positions 2-3; choose one enemy in positions 1-3\n" + base_effect,
			"_half_lines renders the same authored replacement when Snip is second")
	var plus_first := snip_model.preview(1, 2)
	if not plus_first.is_empty():
		var plus_line := LiveRestStitchPairPicker.new()._half_lines("First", plus_first["first_half"])
		_check(plus_line.contains("7 damage, or 20 instead") and not plus_line.contains("5 damage"),
			"plus Snip renders its own 7-vs-20 replacement")
		_check(not plus_line.contains("7+20") and not plus_line.contains("7 + 20"),
			"plus Snip text never sums the two damages")

	# Mount the real picker and confirm the visible preview text both ways.
	var snip_picker := LiveRestStitchPairPicker.new()
	snip_picker.name = "SnipRestStitchPairPicker"
	snip_picker.position = Vector2(330, 180)
	root.add_child(snip_picker)
	await _frames()
	snip_picker.bind(snip_ledger, snip_receipt)
	var ui_rng := RandomNumberGenerator.new()
	ui_rng.seed = 135791
	var ui_rng_before := ui_rng.state
	seed(135791)
	var ui_global_next := randi()
	seed(135791)
	# Base Snip first: visible half and the 3-scrap preview.
	snip_picker.first_selector.select(_row_in_first(snip_picker, 0))
	snip_picker.first_selector.item_selected.emit(_row_in_first(snip_picker, 0))
	var strike_row := _row_in_second(snip_picker, 2)
	_check(strike_row >= 0, "Warden Strike is a legal second-half partner")
	if strike_row >= 0:
		snip_picker.second_selector.select(strike_row)
		snip_picker.second_selector.item_selected.emit(strike_row)
		_check(snip_picker.first_half_label.text ==
			"First: Snip the Seam — Tinker (1 energy)\nFrom hero positions 2-3; choose one enemy in positions 1-3\n" + base_effect,
			"mounted first-half preview shows authored conditional replacement")
		_check(snip_picker.second_half_label.text ==
			"Second: Strike — Warden (1 energy)\nFrom hero positions 1-2; choose one enemy in positions 1-2\n6 damage",
			"mounted ordinary Strike half stays damage-only")
		_check(not snip_picker.confirm_button.disabled
			and snip_picker.summary_label.text.contains("Snip the Seam / Strike")
			and snip_picker.summary_label.text.contains("3 scraps"),
			"mounted Snip/Strike preview names the pair and 3-scrap cost before confirm")
		_check(snip_picker.first_half_label.get_line_count() <= 4,
			"mounted Snip first-half rule fits the paper strip without clipping")
	# Reverse: ordinary Strike first, Snip base second.
	snip_picker.first_selector.select(_row_in_first(snip_picker, 2))
	snip_picker.first_selector.item_selected.emit(_row_in_first(snip_picker, 2))
	var snip_second_row := _row_in_second(snip_picker, 0)
	_check(snip_second_row >= 0, "Snip base is a legal second-half partner for Strike")
	if snip_second_row >= 0:
		snip_picker.second_selector.select(snip_second_row)
		snip_picker.second_selector.item_selected.emit(snip_second_row)
		_check(snip_picker.second_half_label.text ==
			"Second: Snip the Seam — Tinker (1 energy)\nFrom hero positions 2-3; choose one enemy in positions 1-3\n" + base_effect,
			"mounted second-half Snip shows the same authored replacement")
		_check(snip_picker.first_half_label.text ==
			"First: Strike — Warden (1 energy)\nFrom hero positions 1-2; choose one enemy in positions 1-2\n6 damage",
			"mounted ordinary Strike first half stays damage-only")
		_check(snip_picker.second_half_label.get_line_count() <= 4,
			"mounted Snip second-half rule fits the paper strip without clipping")
	# Plus form second: authored 7-vs-20.
	snip_picker.first_selector.select(_row_in_first(snip_picker, 2))
	snip_picker.first_selector.item_selected.emit(_row_in_first(snip_picker, 2))
	var plus_row := _row_in_second(snip_picker, 1)
	_check(plus_row >= 0, "Snip+ is a legal second-half partner for Strike")
	if plus_row >= 0:
		snip_picker.second_selector.select(plus_row)
		snip_picker.second_selector.item_selected.emit(plus_row)
		_check(snip_picker.second_half_label.text ==
			"Second: Snip the Seam+ — Tinker (1 energy)\nFrom hero positions 2-3; choose one enemy in positions 1-3\n" + plus_effect,
			"mounted upgraded Snip+ shows its own authored 7-vs-20 replacement")
	# Invariants: the choice previews nothing and consumes no ledger or RNG.
	_check(snip_ledger.get_snapshot() == snip_receipt and not snip_ledger.is_consumed(),
		"Snip previews leave the real Rest ledger and 3-scrap purse untouched")
	_check(ui_rng.state == ui_rng_before and randi() == ui_global_next,
		"Snip previews and mounted selection draw no local or global RNG")
	var snip_projection := snip_model.preview(0, 2)
	_check(snip_projection.get("scrap_cost") == 3 and snip_projection.get("remaining_scraps") == 0
		and snip_projection.get("energy_cost") == 2,
		"detached Snip/Strike preview charges exactly 3 scraps on commit projection")
	snip_picker.free()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("rest_stitch_pair_picker_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks; ", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


## Drive the supplied mounted picker, not the earlier global starter picker.
func _select_live_tile(button: OptionButton, row: int, keyboard: bool = false) -> void:
	var panel := button.get_parent() as LiveRestStitchPairPicker
	_check(panel != null and row >= 0 and row < button.item_count,
		"tile activation has a real mounted picker and legal source row")
	if panel == null or row < 0 or row >= button.item_count:
		return
	var is_first := button == panel.first_selector
	if is_first and panel.second_tile_scroll.visible:
		panel._return_to_first_choice()
		await _frames()
	var index: int = button.get_item_metadata(row)
	var tile: Button = panel.first_tile_for_index(index) if is_first else panel.second_tile_for_index(index)
	_check(tile != null and tile.is_visible_in_tree(), "chosen original tile is mounted and visible")
	if tile == null:
		return
	if keyboard:
		tile.grab_focus()
		_check(tile.has_focus(), "chosen original tile receives keyboard focus")
		await _key(KEY_ENTER)
	else:
		tile.pressed.emit()
		await _frames()
	_check(button.selected == row, "mounted tile action synchronizes original selector row")


## Independent expected tooltip rows from the original resolver descriptors.
func _expected_keyword_help(definition: Dictionary) -> String:
	var rows: Array[String] = []
	for entry in CardKeywordGlossary.describe(definition):
		rows.append("%s — %s" % [entry["keyword"], entry["explanation"]])
	return "\n".join(rows)


func _assert_keyword_help(panel: LiveRestStitchPairPicker, first_id: String,
		second_id: String, label: String) -> void:
	var first := RunRestStitchCards.resolve_card_definition(first_id)
	var second := RunRestStitchCards.resolve_card_definition(second_id)
	_check(not first.is_empty() and not second.is_empty(), label + " resolves both originals")
	if first.is_empty() or second.is_empty():
		return
	var first_help := _expected_keyword_help(first)
	var second_help := _expected_keyword_help(second)
	var combined: Array[String] = []
	if not first_help.is_empty():
		combined.append("First — %s\n%s" % [first["display_name"], first_help])
	if not second_help.is_empty():
		combined.append("Second — %s\n%s" % [second["display_name"], second_help])
	_check(panel.first_half_label.tooltip_text == first_help
		and panel.second_half_label.tooltip_text == second_help,
		label + " has exact separate ordered original glossary records")
	_check(panel._first_thumb["backing"].tooltip_text == first_help
		and panel.first_thumbnail.tooltip_text == first_help
		and panel._second_thumb["backing"].tooltip_text == second_help
		and panel.second_thumbnail.tooltip_text == second_help,
		label + " both illustration and text hover regions expose their own Help")
	_check(not panel.confirm_button.disabled
		and panel.confirm_button.tooltip_text == "\n\n".join(combined),
		label + " focusable Confirm contains only the two current ordered Help groups")


func _assert_keyword_help_clear(panel: LiveRestStitchPairPicker, label: String) -> void:
	_check(panel.first_half_label.tooltip_text.is_empty()
		and panel.second_half_label.tooltip_text.is_empty()
		and panel.confirm_button.tooltip_text.is_empty()
		and panel._first_thumb["backing"].tooltip_text.is_empty()
		and panel.first_thumbnail.tooltip_text.is_empty()
		and panel._second_thumb["backing"].tooltip_text.is_empty()
		and panel.second_thumbnail.tooltip_text.is_empty(),
		label + " removes both half, illustration and Confirm tooltips")


func _row_in_first(p: LiveRestStitchPairPicker, deck_index: int) -> int:
	for i in range(p.first_selector.item_count):
		if p.first_selector.get_item_metadata(i) == deck_index:
			return i
	return -1


func _row_in_second(p: LiveRestStitchPairPicker, deck_index: int) -> int:
	for i in range(p.second_selector.item_count):
		if p.second_selector.get_item_metadata(i) == deck_index:
			return i
	return -1


## Real mounted 3-scrap pool halves: keyword hover, keyboard Help and lifecycle.
func _test_keyword_help_picker() -> void:
	var cards: Array[String] = [
		"warden_pinning_jab", "seamstress_snag",
		"warden_pinning_jab_plus", "seamstress_snag_plus",
		"warden_strike", "tinker_pop_shot"]
	var ledger := RunRestStitchCards.new(cards, {}, 3)
	_check(ledger.is_valid() and not ledger.is_consumed(), "keyword test has valid real 3-scrap originals")
	var source := ledger.get_snapshot()
	var jab := RunRestStitchCards.resolve_card_definition(cards[0])
	var snag := RunRestStitchCards.resolve_card_definition(cards[1])
	var jab_rows := CardKeywordGlossary.describe(jab)
	var snag_rows := CardKeywordGlossary.describe(snag)
	var plus_rows := CardKeywordGlossary.describe(RunRestStitchCards.resolve_card_definition(cards[3]))
	_check(jab_rows.size() == 1 and jab_rows[0]["keyword"] == "Pinned"
		and str(jab_rows[0]["explanation"]).contains("DIFFERENT hero")
		and str(jab_rows[0]["explanation"]).contains("+5 damage before Weak/Exposed")
		and str(jab_rows[0]["explanation"]).contains("consumes this pin"),
		"authentic Pinning Jab glossary states different-owner +5 and consumption")
	_check(snag_rows.size() == 2 and snag_rows[0]["keyword"] == "Weak 1"
		and snag_rows[1]["keyword"] == "Unravel 3"
		and str(snag_rows[0]["explanation"]).contains("25% less attack damage")
		and str(snag_rows[0]["explanation"]).contains("rounds down (minimum 0)")
		and str(snag_rows[1]["explanation"]).contains("normal 8, elite 12, boss 16")
		and str(snag_rows[1]["explanation"]).contains("skips its NEXT action")
		and str(snag_rows[1]["explanation"]).contains("resets to 0")
		and str(snag_rows[1]["explanation"]).contains("rises by 4"),
		"authentic Snag glossary orders Weak then Unravel with exact break/rounding rules")
	_check(plus_rows.size() == 2 and plus_rows[0]["keyword"] == "Weak 1"
		and plus_rows[1]["keyword"] == "Unravel 4",
		"authentic Snag+ glossary describes four Unravel, not three")
	var panel := LiveRestStitchPairPicker.new()
	panel.position = Vector2(330, 180)
	root.add_child(panel)
	await _frames()
	panel.stitch_requested.connect(_take)
	panel.bind(ledger, source)
	_check(panel.first_selector.item_count == cards.size() and panel.confirm_button.disabled,
		"genuine keyword ledger mounts first-stage selectable originals")
	_assert_keyword_help_clear(panel, "initial mounted bind")
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 221144
	var local_before := local_rng.state
	seed(221144)
	var global_next := randi()
	seed(221144)
	var signal_count := received.size()
	await _select_live_tile(panel.first_selector, _row_in_first(panel, 0))
	_check(panel.second_selector.item_count > 0 and panel.confirm_button.disabled
		and panel.first_half_label.text.is_empty() and panel.second_half_label.text.is_empty(),
		"one selected half cannot advertise a complete pair")
	_assert_keyword_help_clear(panel, "incomplete first selection")
	await _select_live_tile(panel.second_selector, _row_in_second(panel, 1))
	_check(panel._current_pair().get("first_index") == 0
		and panel._current_pair().get("second_index") == 1
		and panel._current_pair().get("energy_cost") == 2
		and panel._current_pair().get("remaining_scraps") == 0,
		"genuine Jab/Snag maintains source indices, two energy and three-scrap price")
	_check(panel.first_half_label.text ==
		"First: Pinning Jab — Warden (1 energy)\nFrom hero positions 1-2; choose one enemy in positions 1\n4 damage; Pinned"
		and panel.second_half_label.text ==
		"Second: Snag — Seamstress (1 energy)\nFrom hero positions 2-3; choose one enemy in positions 1-3\nUnravel 3; Weak 1",
		"Jab/Snag original card faces remain exactly short authored lines")
	_assert_keyword_help(panel, cards[0], cards[1], "base Jab then Snag")
	_check(not panel.first_half_label.tooltip_text.contains("Weak 1 —")
		and not panel.first_half_label.tooltip_text.contains("Unravel 3 —")
		and not panel.second_half_label.tooltip_text.contains("Pinned —"),
		"each half's hover avoids the other half's keyword rows")
	_check(panel.first_half_label.mouse_filter != Control.MOUSE_FILTER_IGNORE
		and panel.second_half_label.mouse_filter != Control.MOUSE_FILTER_IGNORE
		and panel.first_thumbnail.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"hoverable text and art regions can receive pointer Help")
	var chosen_a := panel._selected_first_index
	var chosen_b := panel._selected_second_index
	var second_tile := panel.second_tile_for_index(1)
	_check(second_tile != null and second_tile.is_visible_in_tree(), "real second tile can receive keyboard focus")
	if second_tile != null:
		second_tile.grab_focus()
		await _key(KEY_TAB)
		_check(panel.confirm_button.has_focus(), "Tab reaches genuine Confirm for combined Help")
		_assert_keyword_help(panel, cards[0], cards[1], "focused Confirm")
	_check(panel._selected_first_index == chosen_a and panel._selected_second_index == chosen_b,
		"keyboard focus and Help do not change selected source indices")
	# Reverse through the actual keyboard tile activation path.
	await _select_live_tile(panel.first_selector, _row_in_first(panel, 1), true)
	_assert_keyword_help_clear(panel, "reverse first-only selection")
	await _select_live_tile(panel.second_selector, _row_in_second(panel, 0), true)
	_check(panel.first_half_label.text.begins_with("First: Snag — Seamstress")
		and panel.second_half_label.text.begins_with("Second: Pinning Jab — Warden"),
		"reversed originals swap short half faces")
	_assert_keyword_help(panel, cards[1], cards[0], "reversed Snag then Jab")
	await _select_live_tile(panel.first_selector, _row_in_first(panel, 2))
	_assert_keyword_help_clear(panel, "upgraded first-only selection")
	await _select_live_tile(panel.second_selector, _row_in_second(panel, 3))
	_check(panel.first_half_label.text ==
		"First: Pinning Jab+ — Warden (1 energy)\nFrom hero positions 1-2; choose one enemy in positions 1\n6 damage; Pinned"
		and panel.second_half_label.text ==
		"Second: Snag+ — Seamstress (1 energy)\nFrom hero positions 2-3; choose one enemy in positions 1-3\nUnravel 4; Weak 1",
		"real upgraded halves retain six damage and Unravel four card-face rules")
	_assert_keyword_help(panel, cards[2], cards[3], "upgraded Jab+ then Snag+")
	_check(not panel.second_half_label.tooltip_text.contains("Unravel 3 —")
		and panel.second_half_label.tooltip_text.contains("Unravel 4 —"),
		"upgraded second half clears previous Unravel three Help")
	await _select_live_tile(panel.first_selector, _row_in_first(panel, 4))
	await _select_live_tile(panel.second_selector, _row_in_second(panel, 5))
	_check(CardKeywordGlossary.describe(RunRestStitchCards.resolve_card_definition(cards[4])).is_empty()
		and CardKeywordGlossary.describe(RunRestStitchCards.resolve_card_definition(cards[5])).is_empty(),
		"ordinary Strike and Pop Shot genuinely have no keyword Help")
	_assert_keyword_help(panel, cards[4], cards[5], "unkeyworded pair")
	_assert_keyword_help_clear(panel, "unkeyworded pair does not fabricate Help")
	panel._return_to_first_choice()
	_assert_keyword_help_clear(panel, "cancel back to first choice")
	panel.clear()
	_assert_keyword_help_clear(panel, "explicit clear")
	panel.bind(ledger, source)
	_assert_keyword_help_clear(panel, "valid rebind before pair")
	await _select_live_tile(panel.first_selector, _row_in_first(panel, 0))
	await _select_live_tile(panel.second_selector, _row_in_second(panel, 1))
	_assert_keyword_help(panel, cards[0], cards[1], "restored pair before invalid row")
	var row := _row_in_second(panel, 1)
	panel.second_selector.set_item_metadata(row, 5)
	await _click(panel.confirm_button)
	_check(panel.confirm_button.disabled and received.size() == signal_count,
		"forged second option fails closed without emitting intent")
	_assert_keyword_help_clear(panel, "invalid metadata selection")
	var poor := RunRestStitchCards.new(cards, {}, 2)
	panel.bind(poor, poor.get_snapshot())
	_check(panel.first_selector.disabled and panel.confirm_button.disabled,
		"insufficient scraps disables mounted Stitch")
	_assert_keyword_help_clear(panel, "insufficient scraps")
	panel.bind(ledger, source)
	_assert_keyword_help_clear(panel, "rebound valid ledger")
	await _select_live_tile(panel.first_selector, _row_in_first(panel, 0))
	await _select_live_tile(panel.second_selector, _row_in_second(panel, 1))
	_assert_keyword_help(panel, cards[0], cards[1], "valid current pair before request")
	_check(ledger.get_snapshot() == source and not ledger.is_consumed()
		and received.size() == signal_count and local_rng.state == local_before
		and randi() == global_next,
		"all preview, hover, keyboard, rejection and rebinding preserve receipt, deck, scraps, intent and RNG")
	await _click(panel.confirm_button)
	_check(received.size() == signal_count + 1
		and received.back() == {"first": 0, "second": 1, "source": source}
		and ledger.get_snapshot() == source and not ledger.is_consumed(),
		"existing Confirm emits one ordered request and makes no detached transaction")
	_check(panel.confirm_button.disabled, "one-shot request disables Confirm")
	_assert_keyword_help_clear(panel, "submitted intent")
	panel.bind(ledger, source)
	_assert_keyword_help_clear(panel, "post-submission rebind")
	panel.free()


func _test_mixed_pool_picker() -> void:
	# AC1: Mixed ledger with duplicate starters, pool bases, pool plus, and pre-existing stitched card
	var mixed_deck: Array[String] = [
		"warden_strike",             # 0: starter duplicate #1
		"warden_strike",             # 1: starter duplicate #2
		"seamstress_prick",          # 2: starter duplicate #1
		"seamstress_prick",          # 3: starter duplicate #2
		"tinker_pop_shot",           # 4: starter
		"warden_pinning_jab",        # 5: authored pool base (Warden)
		"warden_pinning_jab",        # 6: authored pool duplicate (Warden)
		"seamstress_snag",           # 7: authored pool base (Seamstress)
		"tinker_rivet_shot",         # 8: authored pool base (Tinker)
		"tinker_ricochet",           # 9: authored pool base with enemy_random (Tinker)
		"seamstress_field_mend",     # 10: authored pool base with party_all (Seamstress)
		"warden_pinning_jab_plus",   # 11: authored pool plus (Warden)
		"seamstress_snag_plus",      # 12: authored pool plus (Seamstress)
		"tinker_rivet_shot_plus",    # 13: authored pool plus (Tinker)
		"tinker_ricochet_plus",      # 14: authored pool plus (Tinker)
		"seamstress_field_mend_plus",# 15: authored pool plus (Seamstress)
		"stitched_000001",           # 16: pre-existing authentic stitched composite
	]
	var seed_service := RunRestStitchCards.new(["warden_strike", "tinker_pop_shot"], {}, 3, 1)
	var seed_result := seed_service.choose_stitch(0, 1, seed_service.get_snapshot())
	_check(seed_result.get("ok", false), "pre-existing seed stitched card created")
	var descriptors: Dictionary = {
		"stitched_000001": seed_result["descriptor"]
	}
	var scraps := 5
	var next_stitch_id := 2
	var mixed_ledger := RunRestStitchCards.new(mixed_deck, descriptors, scraps, next_stitch_id)
	_check(mixed_ledger.is_valid() and not mixed_ledger.is_consumed(),
		"genuine mixed ledger with starters, pool bases, pool plus and existing stitched card is valid")

	var mixed_receipt := mixed_ledger.get_snapshot()
	var mixed_model := RunRestStitchPairOptions.new(mixed_ledger, mixed_receipt)
	_check(mixed_model.is_available(), "mixed model accepts genuine receipt")
	var firsts := mixed_model.first_options()
	_check(firsts.size() == mixed_deck.size() - 1,
		"first options include every ordinary occurrence and exclude stitched card")
	for item in firsts:
		var idx: int = item["index"]
		var id: String = item["id"]
		_check(id != "stitched_000001", "first option never includes stitched card at index %d" % idx)
		_check(mixed_deck[idx] == id, "first option maintains exact deck index %d for %s" % [idx, id])
		var def := RunRestStitchCards.resolve_card_definition(id)
		_check(item["owner"] == def["owner"] and item["name"] == def["display_name"]
			and item["cost"] == def["cost"], "first option metadata matches authored definition for %s" % id)
		var seconds := mixed_model.second_options(idx)
		_check(not seconds.is_empty(), "every ordinary card has cross-owner partners at %d" % idx)
		for sec in seconds:
			var s_idx: int = sec["index"]
			var s_id: String = sec["id"]
			_check(s_idx != idx, "second option never matches first index at %d" % idx)
			_check(s_id != "stitched_000001", "second option never includes stitched card")
			var s_def := RunRestStitchCards.resolve_card_definition(s_id)
			_check(sec["owner"] != item["owner"], "second option enforces different hero from %s" % item["owner"])
			_check(sec["owner"] == s_def["owner"] and sec["name"] == s_def["display_name"]
				and sec["cost"] == s_def["cost"], "second option matches authored definition for %s" % s_id)

	# Distinct duplicate occurrences:
	_check(mixed_deck[0] == mixed_deck[1] and mixed_deck[0] == "warden_strike", "duplicate starter check")
	_check(mixed_deck[5] == mixed_deck[6] and mixed_deck[5] == "warden_pinning_jab", "duplicate pool base check")
	var first_strike_partners := mixed_model.second_options(0)
	var second_strike_partners := mixed_model.second_options(1)
	_check(first_strike_partners.size() == second_strike_partners.size(),
		"duplicate originals share partner counts but separate indices")
	_check(mixed_model.second_options(16).is_empty(), "stitched card has no second options")
	_check(mixed_model.preview(16, 0).is_empty() and mixed_model.preview(0, 16).is_empty(),
		"preview refuses already-stitched card as first or second half")

	# AC2: Cross-owner pool/starter, pool/pool, plus/starter, plus/pool selections:
	var pairs_to_test := [
		[5, 2, "pool base / starter (Pinning Jab / Prick)"],
		[5, 7, "pool base / pool base (Pinning Jab / Snag)"],
		[11, 4, "pool plus / starter (Pinning Jab+ / Pop Shot)"],
		[11, 9, "pool plus / pool base (Pinning Jab+ / Ricochet)"],
		[12, 13, "pool plus / pool plus (Snag+ / Rivet Shot+)"],
		[10, 0, "pool party_all / starter (Field Mend / Strike)"],
		[14, 5, "pool plus enemy_random / pool base (Ricochet+ / Pinning Jab)"],
	]
	for p in pairs_to_test:
		var a: int = p[0]
		var b: int = p[1]
		var desc: String = p[2]
		var prev := _assert_projection(mixed_model, mixed_receipt, a, b, desc)
		_assert_authored(prev, mixed_deck[a], mixed_deck[b], desc)
		var d_a := RunRestStitchCards.resolve_card_definition(mixed_deck[a])
		var d_b := RunRestStitchCards.resolve_card_definition(mixed_deck[b])
		var expected_cost := mini(3, maxi(d_a["cost"], d_b["cost"]) + 1)
		_check(prev["energy_cost"] == expected_cost, desc + " cost calculation min(3, max+1)")
		_check(prev["remaining_scraps"] == scraps - 3, desc + " charges exactly 3 scraps")
		_check(prev["first_half"] == d_a and prev["second_half"] == d_b, desc + " preserves authored halves")
		var rev := _assert_projection(mixed_model, mixed_receipt, b, a, desc + " (reversed)")
		_assert_authored(rev, mixed_deck[b], mixed_deck[a], desc + " (reversed)")
		_check(rev["energy_cost"] == expected_cost, desc + " reversed cost matches")
		_check(rev["first_id"] == mixed_deck[b] and rev["second_id"] == mixed_deck[a], desc + " reversed halves")

	# AC3: Mounted LiveRestStitchPairPicker bound to mixed visit:
	var ui := LiveRestStitchPairPicker.new()
	ui.name = "MixedPoolRestStitchPairPicker"
	ui.position = Vector2(330, 180)
	ui.size = Vector2(600, 355)
	root.add_child(ui)
	await _frames()
	ui.stitch_requested.connect(_take)
	ui.bind(mixed_ledger, mixed_receipt)

	_bounds(ui)
	_bounds(ui.first_selector)
	_bounds(ui.second_selector)
	_bounds(ui.confirm_button)
	_bounds(ui.summary_label)
	_bounds(ui.first_half_label)
	_bounds(ui.second_half_label)

	# 1. Warden Pinning Jab (4 damage; Pinned) and Pinning Jab+ (6 damage; Pinned)
	var jab_row := _row_in_first(ui, 5)
	_check(jab_row >= 0, "Pinning Jab selectable in first selector")
	ui.first_selector.select(jab_row)
	ui.first_selector.item_selected.emit(jab_row)
	var prick_partner_row := _row_in_second(ui, 2)
	_check(prick_partner_row >= 0, "Prick partner selectable")
	ui.second_selector.select(prick_partner_row)
	ui.second_selector.item_selected.emit(prick_partner_row)
	_check(ui.first_half_label.text ==
		"First: Pinning Jab — Warden (1 energy)\nFrom hero positions 1-2; choose one enemy in positions 1\n4 damage; Pinned",
		"Pinning Jab displays authored rules: owner, cost, from 1-2, target 1, 4 damage; Pinned")
	_assert_sewn_caption(ui, 5, 2, "Pinning Jab", "Prick", mixed_deck.size(), scraps - 3,
		"mixed owned pool / starter forecast with two scraps remaining")
	_check(ui.first_half_label.get_line_count() <= 4, "Pinning Jab unclipped")

	var jab_plus_row := _row_in_first(ui, 11)
	_check(jab_plus_row >= 0, "Pinning Jab+ selectable in first selector")
	ui.first_selector.select(jab_plus_row)
	ui.first_selector.item_selected.emit(jab_plus_row)
	prick_partner_row = _row_in_second(ui, 2)
	ui.second_selector.select(prick_partner_row)
	ui.second_selector.item_selected.emit(prick_partner_row)
	_check(ui.first_half_label.text ==
		"First: Pinning Jab+ — Warden (1 energy)\nFrom hero positions 1-2; choose one enemy in positions 1\n6 damage; Pinned",
		"Pinning Jab+ displays authored upgraded rules: 6 damage; Pinned")
	_check(ui.first_half_label.get_line_count() <= 4, "Pinning Jab+ unclipped")

	# 2. Seamstress Snag (Unravel 3; Weak 1) and Snag+ (Unravel 4; Weak 1)
	var snag_row := _row_in_first(ui, 7)
	_check(snag_row >= 0, "Snag selectable in first selector")
	ui.first_selector.select(snag_row)
	ui.first_selector.item_selected.emit(snag_row)
	var strike_partner_row := _row_in_second(ui, 0)
	ui.second_selector.select(strike_partner_row)
	ui.second_selector.item_selected.emit(strike_partner_row)
	_check(ui.first_half_label.text ==
		"First: Snag — Seamstress (1 energy)\nFrom hero positions 2-3; choose one enemy in positions 1-3\nUnravel 3; Weak 1",
		"Snag displays authored rules: owner, cost, from 2-3, target 1-3, Unravel 3; Weak 1")
	_check(ui.first_half_label.get_line_count() <= 4, "Snag unclipped")

	var snag_plus_row := _row_in_first(ui, 12)
	ui.first_selector.select(snag_plus_row)
	ui.first_selector.item_selected.emit(snag_plus_row)
	strike_partner_row = _row_in_second(ui, 0)
	ui.second_selector.select(strike_partner_row)
	ui.second_selector.item_selected.emit(strike_partner_row)
	_check(ui.first_half_label.text ==
		"First: Snag+ — Seamstress (1 energy)\nFrom hero positions 2-3; choose one enemy in positions 1-3\nUnravel 4; Weak 1",
		"Snag+ displays authored upgraded rules: Unravel 4; Weak 1")
	_check(ui.first_half_label.get_line_count() <= 4, "Snag+ unclipped")

	# 3. Tinker Rivet Shot (4 damage; Exposed 1) and Rivet Shot+ (6 damage; Exposed 1)
	ui.first_selector.select(_row_in_first(ui, 0)) # Strike
	ui.first_selector.item_selected.emit(_row_in_first(ui, 0))
	var rivet_row := _row_in_second(ui, 8)
	_check(rivet_row >= 0, "Rivet Shot selectable in second selector")
	ui.second_selector.select(rivet_row)
	ui.second_selector.item_selected.emit(rivet_row)
	_check(ui.second_half_label.text ==
		"Second: Rivet Shot — Tinker (1 energy)\nFrom hero positions 2-3; choose one enemy in positions 1-3\n4 damage; Exposed 1 (first Tinker attack this turn: +3 damage)",
		"Rivet Shot displays authored rules: 4 damage; Exposed 1 with Tinker attack passive")
	_check(ui.second_half_label.get_line_count() <= 4, "Rivet Shot unclipped")

	var rivet_plus_row := _row_in_second(ui, 13)
	ui.second_selector.select(rivet_plus_row)
	ui.second_selector.item_selected.emit(rivet_plus_row)
	_check(ui.second_half_label.text ==
		"Second: Rivet Shot+ — Tinker (1 energy)\nFrom hero positions 2-3; choose one enemy in positions 1-3\n6 damage; Exposed 1 (first Tinker attack this turn: +3 damage)",
		"Rivet Shot+ displays authored upgraded rules: 6 damage; Exposed 1")
	_check(ui.second_half_label.get_line_count() <= 4, "Rivet Shot+ unclipped")

	# 4. Tinker Ricochet (enemy_random in 1-3, 4 damage to a random living enemy three times using run RNG)
	var ricochet_row := _row_in_second(ui, 9)
	_check(ricochet_row >= 0, "Ricochet selectable in second selector")
	ui.second_selector.select(ricochet_row)
	ui.second_selector.item_selected.emit(ricochet_row)
	_check(ui.second_half_label.text ==
		"Second: Ricochet — Tinker (1 energy)\nFrom hero positions 2-3; random living enemy in positions 1-3\n4 damage to a random living enemy three times using run RNG (first Tinker attack this turn: +3 damage)",
		"Ricochet displays authored rules: enemy_random, 4 damage 3 hits run RNG and passive")
	_check(ui.second_half_label.get_line_count() <= 4, "Ricochet unclipped")

	var ricochet_plus_row := _row_in_second(ui, 14)
	ui.second_selector.select(ricochet_plus_row)
	ui.second_selector.item_selected.emit(ricochet_plus_row)
	_check(ui.second_half_label.text ==
		"Second: Ricochet+ — Tinker (1 energy)\nFrom hero positions 2-3; random living enemy in positions 1-3\n6 damage to a random living enemy three times using run RNG (first Tinker attack this turn: +3 damage)",
		"Ricochet+ displays authored upgraded rules: 6 damage 3 hits run RNG")
	_check(ui.second_half_label.get_line_count() <= 4, "Ricochet+ unclipped")

	# 5. Seamstress Field Mend (party_all, heal every ally 4)
	var field_mend_row := _row_in_second(ui, 10)
	_check(field_mend_row >= 0, "Field Mend selectable in second selector")
	ui.second_selector.select(field_mend_row)
	ui.second_selector.item_selected.emit(field_mend_row)
	_check(ui.second_half_label.text ==
		"Second: Field Mend — Seamstress (2 energy)\nFrom hero positions 2-3; all allies\nheal every ally 4",
		"Field Mend displays authored rules: party_all, heal every ally 4")
	_check(ui.second_half_label.get_line_count() <= 4, "Field Mend unclipped")

	var field_mend_plus_row := _row_in_second(ui, 15)
	ui.second_selector.select(field_mend_plus_row)
	ui.second_selector.item_selected.emit(field_mend_plus_row)
	_check(ui.second_half_label.text ==
		"Second: Field Mend+ — Seamstress (2 energy)\nFrom hero positions 2-3; all allies\nheal every ally 6",
		"Field Mend+ displays authored upgraded rules: heal every ally 6")
	_check(ui.second_half_label.get_line_count() <= 4, "Field Mend+ unclipped")
	_thumb_ok(ui, "first", "warden_strike", "warden")
	# Field Mend+ has no committed illustration yet: its authored upgraded text
	# stays beside the owner-colour fallback (or real art once committed).
	_check(ui.second_half_label.text.contains("Field Mend+")
		and ui.second_half_label.text.contains("heal every ally 6"),
		"placeholder half keeps the authored upgraded Field Mend+ rule text")
	_thumb_present_or_placeholder(ui, "second", "seamstress_field_mend_plus", "Field Mend+", "seamstress")

	# Keyboard focus and confirmation on representative pool selection:
	ui.second_selector.grab_focus()
	await _key(KEY_TAB)
	_check(ui.confirm_button.has_focus(), "keyboard Tab reaches confirmation button on pool selection")
	var sigs_before := received.size()
	await _key(KEY_ENTER)
	_check(received.size() == sigs_before + 1 and received.back()["first"] == 0
		and received.back()["second"] == 15 and received.back()["source"] == mixed_receipt,
		"keyboard confirmation emits exact indices for Strike / Field Mend+ without mutating visit")
	_check(mixed_ledger.get_snapshot() == mixed_receipt and not mixed_ledger.is_consumed(),
		"mounted request only emits intent; Rest ledger remains untouched")
	ui.free()

	# AC4: Insufficient scraps, forged/stale receipts, invalid indices, same-owner pairs, stitched cards, consumed visit:
	for scrap_val in [0, 2]:
		var poor := RunRestStitchCards.new(mixed_deck, descriptors, scrap_val, next_stitch_id)
		var poor_m := RunRestStitchPairOptions.new(poor, poor.get_snapshot())
		_check(not poor_m.is_available() and poor_m.first_options().is_empty()
			and poor_m.second_options(5).is_empty() and poor_m.preview(5, 7).is_empty()
			and poor.get_snapshot()["remaining_scraps"] == scrap_val and not poor.is_consumed(),
			"mixed ledger with %d scraps excludes all pairs and spends nothing" % scrap_val)

	# Nonexistent/invalid indices, same-owner pairs, and stitched card as half:
	_check(mixed_model.preview(-1, 5).is_empty(), "negative index rejected")
	_check(mixed_model.preview(5, mixed_deck.size()).is_empty(), "out of bounds index rejected")
	_check(mixed_model.preview(5, 5).is_empty(), "same index twice rejected")
	_check(mixed_model.preview("5", 7).is_empty(), "string index rejected")
	_check(mixed_model.preview(0, 5).is_empty(), "same owner Warden/Warden pair rejected")
	_check(mixed_model.preview(7, 10).is_empty(), "same owner Seamstress/Seamstress pair rejected")
	_check(mixed_model.preview(8, 9).is_empty(), "same owner Tinker/Tinker pair rejected")
	_check(mixed_model.preview(16, 5).is_empty() and mixed_model.preview(5, 16).is_empty(),
		"pre-existing stitched card cannot be used as stitch input")

	# Forged or stale receipts:
	for key in ["receipt", "deck", "descriptors", "remaining_scraps", "next_stitch_id"]:
		var forged := mixed_receipt.duplicate(true)
		match key:
			"receipt": forged[key] = "forged"
			"deck": forged[key][0] = "warden_brace"
			"descriptors": forged[key]["stitched_999999"] = {}
			"remaining_scraps": forged[key] = 99
			"next_stitch_id": forged[key] = 9
		var stale := RunRestStitchPairOptions.new(mixed_ledger, forged)
		_check(not stale.is_available() and stale.first_options().is_empty() and stale.preview(5, 7).is_empty(),
			"mixed ledger with tampered " + key + " fails closed")

	# Consumed visit rejection:
	var commit_oracle := RunRestStitchCards.new(mixed_deck, descriptors, scraps, next_stitch_id)
	var committed := commit_oracle.choose_stitch(5, 7, commit_oracle.get_snapshot())
	_check(committed.get("ok", false) and commit_oracle.is_consumed(), "commit oracle consumed successfully")
	var consumed_m := RunRestStitchPairOptions.new(commit_oracle, commit_oracle.get_snapshot())
	_check(not consumed_m.is_available() and consumed_m.first_options().is_empty()
		and consumed_m.second_options(5).is_empty() and consumed_m.preview(5, 7).is_empty(),
		"consumed mixed visit offers no choices")

	# Deterministic RNG invariance check:
	var neg_rng := RandomNumberGenerator.new()
	neg_rng.seed = 991823
	var neg_state := neg_rng.state
	seed(991823)
	var neg_global := randi()
	seed(991823)
	_check(neg_rng.state == neg_state and randi() == neg_global,
		"negative checks on mixed ledger consume no local or global RNG")


## AC3: After submission, the picker latches as submitted and cannot emit a second
## intent or re-arm selection on the same binding without a fresh bind.
func _test_submitted_single_intent_latch() -> void:
	var test_deck := _deck()
	var scraps := 4
	var test_service := RunRestStitchCards.new(test_deck, {}, scraps)
	_check(test_service.is_valid() and not test_service.is_consumed(),
		"genuine >=3-scrap service is valid")
	var snapshot: Dictionary = test_service.get_snapshot()

	var p := LiveRestStitchPairPicker.new()
	p.name = "SubmittedLatchSingleIntentPicker"
	p.position = Vector2(330, 180)
	p.size = Vector2(600, 355)
	root.add_child(p)
	await _frames()

	var intent_log: Array[Dictionary] = []
	p.stitch_requested.connect(func(first: int, second: int, source: Dictionary):
		intent_log.append({"first": first, "second": second, "source": source})
	)

	p.bind(test_service, snapshot)
	await _frames()
	_check(not p.is_submitted(), "picker starts unsubmitted")
	_check(not p.first_tiles.is_empty() and not p.first_selector.disabled,
		"picker tiles and legacy selector available initially")

	var first_idx := _idx(test_deck, "seamstress_prick")
	var second_idx := _idx(test_deck, "tinker_pop_shot")
	var first_tile := p.first_tile_for_index(first_idx)
	_check(first_tile != null and not first_tile.disabled, "first tile is enabled")
	await _click(first_tile)
	await _frames()

	var second_tile := p.second_tile_for_index(second_idx)
	_check(second_tile != null and not second_tile.disabled, "second tile is enabled")
	await _click(second_tile)
	await _frames()

	_check(not p.confirm_button.disabled, "confirm button enabled for selected pair")

	var rng := RandomNumberGenerator.new()
	rng.seed = 882244
	var rng_before := rng.state
	seed(882244)
	var global_before := randi()
	seed(882244)

	# Confirm once without committing the service
	await _click(p.confirm_button)
	await _frames()

	_check(intent_log.size() == 1, "exactly one intent emitted on initial confirmation")
	_check(intent_log[0]["first"] == first_idx and intent_log[0]["second"] == second_idx
		and intent_log[0]["source"] == snapshot, "emitted intent carries chosen indices and snapshot")
	_check(p.is_submitted(), "picker is latched as submitted")
	_check(not test_service.is_consumed(), "service remains uncommitted/unconsumed")
	_check(test_service.get_snapshot() == snapshot, "service snapshot unmutated")
	_check(p.confirm_button.disabled and p.confirm_button.focus_mode == Control.FOCUS_NONE,
		"confirm button disabled and non-focusable after submission")
	_check(p.first_selector.disabled and p.first_selector.focus_mode == Control.FOCUS_NONE,
		"first selector disabled after submission")
	_check(p.second_selector.disabled and p.second_selector.focus_mode == Control.FOCUS_NONE,
		"second selector disabled after submission")
	for tile in p.first_tiles:
		_check(tile.disabled and tile.focus_mode == Control.FOCUS_NONE,
			"first tile disabled and focus none after submission")
	for tile in p.second_tiles:
		_check(tile.disabled and tile.focus_mode == Control.FOCUS_NONE,
			"second tile disabled and focus none after submission")

	# Try selecting another genuine pair and confirming with mouse/Enter and legacy callbacks
	var alt_first := _idx(test_deck, "warden_strike")
	var alt_second := _idx(test_deck, "seamstress_mend")
	var alt_first_tile := p.first_tile_for_index(alt_first)
	if alt_first_tile != null:
		await _click(alt_first_tile)
		alt_first_tile.pressed.emit()
		p.select_first_tile(alt_first)
		p._focus_tile(alt_first_tile)
		_check(not alt_first_tile.has_focus(), "submitted first tile cannot receive focus")
		await _key(KEY_ENTER)
		await _frames()

	var alt_first_row := _row_in_first(p, alt_first)
	if alt_first_row >= 0:
		p.first_selector.select(alt_first_row)
		p.first_selector.item_selected.emit(alt_first_row)
	if p._first_callback.is_valid():
		p._first_callback.call(alt_first_row)

	var alt_second_tile := p.second_tile_for_index(alt_second)
	if alt_second_tile != null:
		await _click(alt_second_tile)
		alt_second_tile.pressed.emit()
		p.select_second_tile(alt_second)
		p._focus_tile(alt_second_tile)
		_check(not alt_second_tile.has_focus(), "submitted second tile cannot receive focus")
		await _key(KEY_ENTER)
		await _frames()

	var alt_second_row := _row_in_second(p, alt_second)
	if alt_second_row >= 0:
		p.second_selector.select(alt_second_row)
		p.second_selector.item_selected.emit(alt_second_row)
	if p._second_callback.is_valid():
		p._second_callback.call(0)

	await _click(p.confirm_button)
	p.confirm_button.pressed.emit()
	if not p.confirm_button.disabled and p.confirm_button.focus_mode != Control.FOCUS_NONE:
		p.confirm_button.grab_focus()
	_check(not p.confirm_button.has_focus(), "submitted confirm button cannot receive focus")
	await _key(KEY_ENTER)
	if p._confirm_callback.is_valid():
		p._confirm_callback.call()
	await _frames()

	# Assert only one unchanged index/snapshot intent, unchanged service/deck/wallet/RNG
	_check(intent_log.size() == 1,
		"single-intent guarantee: intent log still has exactly 1 intent after all re-activation attempts")
	_check(intent_log[0]["first"] == first_idx and intent_log[0]["second"] == second_idx
		and intent_log[0]["source"] == snapshot, "intent remains unchanged original pair/snapshot")
	_check(not test_service.is_consumed(), "service remains unconsumed")
	_check(test_service.get_snapshot() == snapshot, "service/deck/descriptors unmutated")
	_check(test_service.get_snapshot()["remaining_scraps"] == scraps, "wallet scraps unmutated")
	_check(rng.state == rng_before and randi() == global_before, "local and global RNG unchanged")

	# Selection becomes available after a fresh bind
	p.bind(test_service, snapshot)
	await _frames()
	_check(not p.is_submitted(), "latch reset after fresh bind")
	_check(not p.first_selector.disabled, "first selector re-enabled after fresh bind")
	var fresh_first := p.first_tile_for_index(alt_first)
	_check(fresh_first != null and not fresh_first.disabled, "first tile re-enabled on fresh bind")
	await _click(fresh_first)
	await _frames()

	var fresh_second := p.second_tile_for_index(alt_second)
	_check(fresh_second != null and not fresh_second.disabled, "second tile re-enabled on fresh bind")
	await _click(fresh_second)
	await _frames()

	_check(not p.confirm_button.disabled, "confirm re-enabled after fresh bind and selection")
	await _click(p.confirm_button)
	await _frames()

	_check(intent_log.size() == 2, "fresh binding allows emitting a second intent")
	_check(intent_log[1]["first"] == alt_first and intent_log[1]["second"] == alt_second
		and intent_log[1]["source"] == snapshot, "second intent has newly chosen pair")

	p.free()
