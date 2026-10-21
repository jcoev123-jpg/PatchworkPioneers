extends SceneTree
## Mounted M03 prepared Fight/Elite reward view: presentation and request only.
const SCENE := "res://scenes/run_card_reward_choice_panel.tscn"
const HEROES := "res://data/heroes/starter_party.json"
const ENEMIES := "res://data/enemies/starter_enemies.json"

var panel: LiveRunCardRewardChoicePanel
var failures: Array[String] = []
var checks: int = 0
var requests: Array[Dictionary] = []


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
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _mouse(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_LEFT
		root.push_input(event, true)
	await _frames()


func _on_choice(node_id: String, selected_card_id: String) -> void:
	requests.append({"node": node_id, "card": selected_card_id})


func _defs(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "authored combat fixture opens: " + path)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Array and not parsed.is_empty(), "authored combat array parsed: " + path)
	if not parsed is Array:
		return []
	var definitions: Array = []
	for record in parsed:
		_check(record is Dictionary, "authored roster record dictionary")
		if not record is Dictionary:
			continue
		var copy: Dictionary = record.duplicate(true)
		var hp: Variant = copy.get("max_hp")
		var valid: bool = (hp is int and hp > 0) or (hp is float and hp > 0
			and is_finite(hp) and floorf(hp) == hp)
		_check(valid, "authored roster HP positive integral")
		if valid:
			copy["max_hp"] = int(hp)
		definitions.append(copy)
	return definitions


## Return a genuine prepared receipt from previously evaluated victory,
## plus the authoritative service and models to snapshot against UI side effects.
func _prepared(is_elite: bool, seed_value: int) -> Dictionary:
	var party := CombatParty.new(_defs(HEROES))
	var enemies := CombatEnemies.new(_defs(ENEMIES))
	_check(party.is_valid() and enemies.is_valid(), "authored living battle rosters")
	var result := CombatBattleResult.new(party, enemies)
	_check(result.get_outcome() == CombatBattleResult.ACTIVE, "battle begins active")
	for slot in range(1, enemies.get_enemies().size() + 1):
		var enemy := enemies.get_enemy(slot)
		_check(enemies.apply_damage(slot, enemy.get("hp", 0)), "authored enemy killed")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "service sees witnessed victory")
	var catalog := StarterCards.new()
	var cards: Array[String] = catalog.get_all_card_ids()
	var deck: Array[String] = catalog.get_starting_deck()
	var owners: Array[String] = ["warden", "seamstress", "tinker"]
	var owned: Array[String] = ["button_charm"]
	var trinket_pool: Array[String] = ["button_charm", "thread_token"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var service := RunFightVictoryRewards.new(result, rng, owners, cards, deck, 97,
		is_elite, trinket_pool, owned)
	var receipt := service.prepare()
	_check(receipt.get("ok", false) and (receipt.get("offers", []) as Array).size() == 3,
		"actual prepared three-offer service receipt")
	_check(receipt.get("gold_award", 0) >= (25 if is_elite else 10)
		and receipt.get("gold_award", 0) <= (35 if is_elite else 20),
		"actual receipt has correct pending award band")
	_check(receipt.get("trinket_drop_id") == ("thread_token" if is_elite else ""),
		"actual prepared Elite-only unowned trinket")
	return {"receipt": receipt, "rng": rng, "service": service, "deck": deck,
		"gold": 97, "owned": owned, "party": party, "enemies": enemies, "result": result}


func _snapshot(fixture: Dictionary) -> Dictionary:
	return {
		"rng": fixture["rng"].state,
		"seed": fixture["rng"].seed,
		"deck": fixture["deck"].duplicate(true),
		"gold": fixture["gold"],
		"owned": fixture["owned"].duplicate(true),
		"party": fixture["party"].get_heroes(),
		"enemies": fixture["enemies"].get_enemies(),
		"battle": fixture["result"].get_outcome(),
		"claimed": fixture["service"]._choice.is_claimed(),
		"prepared": fixture["service"].prepare(),
	}


func _validate(receipt: Dictionary, kind: String, node_id: String) -> void:
	_check(panel.has_open_rewards() and panel.is_visible_in_tree(), "actual scene mounted: " + kind)
	_check(panel.title_label.text.contains(kind) and panel.title_label.text.contains(node_id),
		"node and kind visible: " + kind)
	_check(panel.gold_label.text == "Pending gold: +%d" % receipt["gold_award"],
		"exact prepared pending gold visible: " + kind)
	_check(panel.trinket_label.visible == (kind == "Elite"), "Elite-only trinket label visibility")
	_check(panel.trinket_label.text == ("Prepared trinket: " + receipt["trinket_drop_id"]
		if kind == "Elite" else ""), "exact prepared trinket text")
	var paper := panel.paper_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(paper != null and paper.bg_color.get_luminance() > 0.55
		and paper.border_width_left >= 4, "cream stitched paper")
	var slate := panel.get_node("SlateBackdrop") as ColorRect
	_check(slate != null and slate.color.get_luminance() < 0.3, "dark slate backing")
	_check(panel.top_stitches.text.contains("×") and panel.bottom_stitches.text.contains("×"),
		"visible hand-drawn stitches")
	var actions := panel.get_choice_buttons()
	_check(actions.size() == 4 and panel.choices_container.get_child_count() == 3,
		"three genuine card panels and one Skip")
	if actions.size() != 4:
		return
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(screen.encloses(panel.paper_panel.get_global_rect()), "paper within 1280x720")
	var catalog := StarterCards.new()
	for index in range(3):
		var offer: Dictionary = receipt["offers"][index]
		var definition: Dictionary = catalog.get_definition(offer["id"])
		_check(not definition.is_empty() and definition["owner"] == offer["owner"],
			"prepared offer backed by authored catalog " + str(index))
		var card := panel.choices_container.get_child(index) as PanelContainer
		_check(card != null and card.name == "Card_%d" % index, "stable mounted card index")
		if card == null:
			continue
		var content := card.get_node("CardMargin/CardContent") as VBoxContainer
		var owner_label := content.get_node("OwnerLabel") as Label
		var name_label := content.get_node("NameLabel") as Label
		var id_label := content.get_node("IdLabel") as Label
		var cost_label := content.get_node("CostLabel") as Label
		var action := content.get_node("ChooseButton") as Button
		_check(action == actions[index], "real action bound to card " + str(index))
		_check(owner_label.text == offer["owner"].capitalize()
			and name_label.text == definition["display_name"]
			and id_label.text == offer["id"] and cost_label.text == "%d energy" % definition["cost"],
			"exact owner, name, ID and cost visible: " + str(index))
		_check(name_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
			and name_label.size_flags_vertical == Control.SIZE_EXPAND_FILL,
			"long valid display name supports robust wrapping")
		var style := card.get_theme_stylebox("panel") as StyleBoxFlat
		_check(style != null and style.border_color == panel.OWNER_COLORS[offer["owner"]],
			"authored owner palette visible")
		_check(screen.encloses(card.get_global_rect()) and screen.encloses(action.get_global_rect()),
			"card and actionable button fully within viewport")
	for index in range(4):
		var button: Button = actions[index]
		_check(button.focus_mode == Control.FOCUS_ALL and button.is_visible_in_tree()
			and not button.disabled, "four enabled focusable actions " + str(index))
		_check(screen.encloses(button.get_global_rect()), "action fully within viewport " + str(index))
		_check(button.get_theme_stylebox("normal") is StyleBoxFlat
			and button.get_theme_stylebox("focus") is StyleBoxFlat,
			"procedural normal and obvious focus styles " + str(index))
	_check(actions[3] == panel.skip_button and actions[3].text.contains("Skip"),
		"fourth action Skip, not a card")


func _test_long_name_wrap() -> void:
	var card := panel.choices_container.get_child(0) as PanelContainer
	var name_label := card.get_node("CardMargin/CardContent/NameLabel") as Label
	var original := name_label.text
	name_label.text = "A Patient Stitcher Carefully Repairs Every Loose Thread Along The Long Patchwork Trail"
	await _frames()
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(name_label.get_line_count() >= 3 and name_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"long authored-style name wraps across multiple visible lines")
	_check(card.get_global_rect().encloses(name_label.get_global_rect())
		and screen.encloses(name_label.get_global_rect())
		and screen.encloses(panel.skip_button.get_global_rect()),
		"wrapped name and Skip remain inside card and 1280x720 viewport")
	name_label.text = original
	await _frames()


func _exercise(fixture: Dictionary, kind: String, physical: int) -> void:
	var receipt: Dictionary = fixture["receipt"]
	var node_id := "floor_02_elite" if kind == "Elite" else "floor_01_fight"
	var before := _snapshot(fixture)
	requests.clear()
	_check(panel.open_rewards(node_id, kind, receipt), kind + " scene opens service receipt")
	await _frames()
	_validate(receipt, kind, node_id)
	await _test_long_name_wrap()
	var actions := panel.get_choice_buttons()
	if actions.size() != 4:
		panel.close_rewards()
		return
	_check(actions[0].has_focus(), kind + " first action receives keyboard focus")
	_check(not panel.open_rewards("replacement", kind, receipt), "cannot replace active prepared reward")
	_check(panel.title_label.text.contains(node_id), "refused overwrite keeps node")
	# Caller mutation cannot change the displayed choice or callback binding.
	var original := receipt.duplicate(true)
	receipt["offers"][0]["id"] = "forged"
	receipt["offers"][1]["owner"] = "forged"
	receipt["gold_award"] = 999
	receipt["trinket_drop_id"] = "forged"
	_validate(original, kind, node_id)
	_check(panel._receipt == original, "detached nested prepared receipt unchanged")
	# Forced invisible and disabled Button signals must fail closed.
	actions[0].hide()
	actions[0].pressed.emit()
	actions[0].show()
	actions[0].disabled = true
	actions[0].pressed.emit()
	actions[0].disabled = false
	panel.hide()
	actions[0].pressed.emit()
	panel.show()
	_check(requests.is_empty(), "hidden/disabled/closed-parent actions cannot request")
	var gen := panel._generation
	panel._on_choice_pressed(gen, node_id, "unoffered", actions[0])
	panel._on_choice_pressed(gen, node_id, original["offers"][1]["id"], actions[0])
	var rogue := Button.new()
	panel.choices_container.add_child(rogue)
	panel._on_choice_pressed(gen, node_id, original["offers"][0]["id"], rogue)
	rogue.queue_free()
	_check(requests.is_empty() and not panel._awaiting_ack,
		"forged card/button bindings reject without consuming offer")
	# Physical pointer on Fight, physical Enter on Elite.
	var selected_index := 1 if kind == "Fight" else 2
	if physical == 0:
		await _mouse(actions[selected_index])
	else:
		actions[selected_index].grab_focus()
		await _frames()
		_check(actions[selected_index].has_focus(), "Enter choice actually focused")
		await _key(KEY_ENTER)
	_check(requests == [{"node": node_id, "card": original["offers"][selected_index]["id"]}],
		"physical action makes exactly one node/card request")
	for button in actions:
		_check(button.disabled, "request disables all choices while pending")
		button.pressed.emit()
	_check(requests.size() == 1, "duplicate pending physical/signal requests rejected")
	panel.acknowledge(false)
	_check(actions.all(func(button: Button) -> bool: return not button.disabled),
		"explicit rejection permits retry of SAME offers")
	_validate(original, kind, node_id)
	# Physically press Space on Skip after rejection.
	actions[3].grab_focus()
	await _frames()
	_check(actions[3].has_focus(), "Skip focused before Space")
	await _key(KEY_SPACE)
	_check(requests.size() == 2 and requests[1] == {"node": node_id, "card": ""},
		"physical Space requests empty Skip ID once")
	panel.acknowledge(true)
	_check(panel._accepted and not panel._awaiting_ack, "accepted acknowledgement latched")
	for button in actions:
		_check(button.disabled, "accepted acknowledgement locks all four actions")
		button.pressed.emit()
	panel.acknowledge(false)
	panel.acknowledge(true)
	_check(requests.size() == 2 and actions.all(func(button: Button) -> bool: return button.disabled),
		"duplicate acknowledgements and actions cannot replay")
	_check(_snapshot(fixture) == before, "all ledger, battle and injected RNG state untouched")
	panel.close_rewards()
	_check(not panel.has_open_rewards() and not panel.visible
		and panel.get_choice_buttons().is_empty(), "close clears all active actions")
	await _frames()


func _malformed(base: Dictionary) -> void:
	var invalids: Array[Dictionary] = []
	var wrong_ok := base.duplicate(true)
	wrong_ok["ok"] = false
	invalids.append(wrong_ok)
	for missing in ["ok", "gold_award", "offers", "trinket_drop_id"]:
		var value := base.duplicate(true)
		value.erase(missing)
		invalids.append(value)
	for reward in [0, 9, 21, "15"]:
		var value := base.duplicate(true)
		value["gold_award"] = reward
		invalids.append(value)
	for invalid_offers in [[], base["offers"].slice(0, 2), base["offers"] + [base["offers"][0]], "invalid"]:
		var value := base.duplicate(true)
		value["offers"] = invalid_offers
		invalids.append(value)
	for invalid in [
			{"id": "bogus", "owner": "warden"},
			{"id": base["offers"][1]["id"], "owner": base["offers"][1]["owner"]},
			{"id": base["offers"][0]["id"], "owner": "alien"},
			{"id": base["offers"][0]["id"], "owner": 5},
			{"id": 5, "owner": "warden"},
			{"owner": "warden"}, "not_a_dictionary"]:
		var value := base.duplicate(true)
		value["offers"][0] = invalid
		invalids.append(value)
	var no_trinket := base.duplicate(true)
	no_trinket["trinket_drop_id"] = "fabric_drop"
	invalids.append(no_trinket)
	requests.clear()
	for index in range(invalids.size()):
		var input := invalids[index]
		var preserved := input.duplicate(true)
		_check(not panel.open_rewards("node", "Fight", input), "bad offer fails closed " + str(index))
		_check(not panel.visible and panel.get_choice_buttons().is_empty()
			and not panel.has_open_rewards(), "bad offer mounts no controls " + str(index))
		_check(input == preserved and requests.is_empty(), "bad offer makes no mutations " + str(index))
	for kind in ["Boss", "", 4]:
		_check(not panel.open_rewards("node", kind, base), "invalid node type rejects " + str(kind))
	for node_id in ["", "  ", 5]:
		_check(not panel.open_rewards(node_id, "Fight", base), "invalid node identity rejected")
	var bad_elite := base.duplicate(true)
	bad_elite["gold_award"] = 30
	_check(not panel.open_rewards("node", "Elite", bad_elite),
		"Elite without supplied trinket rejects instead of synthesizing drop")
	_check(requests.is_empty(), "malformed suite never emits requests")


func _replay_and_stale(base: Dictionary) -> void:
	var independent: Array = []
	var first_generation := -1
	var old_callback: Callable
	var first_button: Button
	requests.clear()
	for pass_index in range(2):
		_check(panel.open_rewards("same_node", "Fight", base), "fresh independent replay opens")
		# Exercise retained callback while old Button is queued (not yet freed).
		if pass_index == 1 and old_callback.is_valid() and is_instance_valid(first_button):
			old_callback.call()
			panel._on_choice_pressed(first_generation, "same_node", base["offers"][0]["id"], first_button)
			_check(requests.is_empty(), "prior closed/reopened callable cannot emit")
			_check(panel._generation != first_generation
				and panel._receipt == base and not panel._awaiting_ack,
				"new offer intact after stale callback")
		await _frames()
		var buttons := panel.get_choice_buttons()
		if buttons.size() != 4:
			panel.close_rewards()
			break
		if pass_index == 0:
			first_generation = panel._generation
			first_button = buttons[0]
			var connections := first_button.pressed.get_connections()
			_check(connections.size() == 1, "real first callback captured")
			if not connections.is_empty():
				old_callback = connections[0]["callable"]
		var ui: Array = []
		for index in range(3):
			var content := panel.choices_container.get_child(index).get_node("CardMargin/CardContent")
			ui.append([content.get_node("OwnerLabel").text, content.get_node("NameLabel").text,
				content.get_node("IdLabel").text, content.get_node("CostLabel").text])
		independent.append(ui)
		buttons[0].pressed.emit()
		_check(requests.size() == 1 and requests[0] == {"node": "same_node",
			"card": base["offers"][0]["id"]}, "fresh presentation emits one current request")
		panel.acknowledge(true)
		panel.close_rewards()
		requests.clear()
		if pass_index == 1:
			await _frames()
	_check(independent.size() == 2 and independent[0] == independent[1],
		"two independent seeded presentations produce identical full card text")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var loaded := load(SCENE) as PackedScene
	_check(loaded != null, "actual .tscn loads")
	if loaded == null:
		_finish()
		return
	panel = loaded.instantiate() as LiveRunCardRewardChoicePanel
	_check(panel != null, "real panel scene uses required script class")
	if panel == null:
		_finish()
		return
	root.add_child(panel)
	panel.choice_requested.connect(_on_choice)
	await _frames()
	_check(panel.has_method("open_rewards") and panel.has_method("close_rewards")
		and panel.has_method("acknowledge") and panel.has_method("get_choice_buttons"),
		"all four required public methods exist")
	_check(not panel.visible and panel.get_choice_buttons().is_empty(), "initial panel closed")
	var fight := _prepared(false, 18203)
	var elite := _prepared(true, 18203)
	if not fight["receipt"].get("ok", false) or not elite["receipt"].get("ok", false):
		_finish()
		return
	var original_fight: Dictionary = fight["receipt"].duplicate(true)
	await _exercise(fight, "Fight", 0)
	await _exercise(elite, "Elite", 1)
	_malformed(original_fight)
	await _replay_and_stale(original_fight)
	# Fresh global seeded stream must also survive panel interactions.
	seed(3941)
	var expected := randi()
	seed(3941)
	_check(panel.open_rewards("rng_node", "Fight", original_fight), "global RNG test opens")
	panel.get_choice_buttons()[0].pressed.emit()
	panel.acknowledge(false)
	panel.get_choice_buttons()[3].pressed.emit()
	panel.acknowledge(true)
	panel.close_rewards()
	_check(randi() == expected, "global seeded RNG receives zero view draws")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_run_card_reward_choice_panel_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	if is_instance_valid(panel):
		panel.free()
	quit(0 if failures.is_empty() else 1)
