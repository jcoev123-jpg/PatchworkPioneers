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


func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
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


## Independent, explicit authored contract: protect against a formatter and
## catalog drifting together. Additional catalog entries may coexist.
func _expected_cards() -> Dictionary:
	return {
		"warden_strike": {"from": [1, 2], "to": [1, 2], "kind": "enemy_single",
			"effects": {"damage": 6}, "text": "From: 1-2 (front/middle)\nTarget: pick 1 living enemy 1-2\nDeal 6 damage"},
		"warden_strike_plus": {"from": [1, 2], "to": [1, 2], "kind": "enemy_single",
			"effects": {"damage": 7}, "text": "From: 1-2 (front/middle)\nTarget: pick 1 living enemy 1-2\nDeal 7 damage"},
		"warden_brace": {"from": [1, 2, 3], "to": [], "kind": "self",
			"effects": {"block": 7}, "text": "From: 1-3 (front to back)\nTarget: self\nGain 7 Block"},
		"warden_shield_bash": {"from": [1], "to": [1], "kind": "enemy_single",
			"effects": {"damage": 8, "weak": 1}, "text": "From: 1 (front)\nTarget: pick 1 living enemy 1 (front)\nDeal 8 damage, Weak 1"},
		"seamstress_prick": {"from": [1, 2, 3], "to": [1, 2, 3], "kind": "enemy_single",
			"effects": {"damage": 3, "bleed": 2}, "text": "From: 1-3 (front to back)\nTarget: pick 1 living enemy 1-3\nDeal 3 damage, Bleed 2"},
		"seamstress_mend": {"from": [2, 3], "to": [], "kind": "ally_single",
			"effects": {"heal": 5}, "text": "From: 2-3 (middle/back)\nTarget: 1 living ally 1-3\nChosen ally heals 5 HP"},
		"seamstress_stitch_up": {"from": [1, 2, 3], "to": [], "kind": "ally_single",
			"effects": {"block": 5}, "text": "From: 1-3 (front to back)\nTarget: 1 living ally 1-3\nChosen ally gains 5 Block"},
		"tinker_pop_shot": {"from": [2, 3], "to": [1, 2, 3], "kind": "enemy_single",
			"effects": {"damage": 5}, "text": "From: 2-3 (middle/back)\nTarget: pick 1 living enemy 1-3\nDeal 5 damage"},
		"tinker_scrap_bomb": {"from": [3], "to": [1, 2, 3], "kind": "enemy_all",
			"effects": {"damage": 4}, "text": "From: 3 (back)\nTarget: all living enemies 1-3\nDeal 4 damage EACH"},
		"tinker_tune_up": {"from": [1, 2, 3], "to": [], "kind": "none",
			"effects": {"draw": 1}, "text": "From: 1-3 (front to back)\nTarget: none\nDraw 1 card"},
	}


func _test_all_catalog_rules(base: Dictionary) -> void:
	var catalog := StarterCards.new()
	var expected := _expected_cards()
	var original := base.duplicate(true)
	var authored_before := {}
	for card_id in expected:
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty(), "required catalog ID exists: " + card_id)
		if definition.is_empty():
			continue
		authored_before[card_id] = definition.duplicate(true)
		var case: Dictionary = expected[card_id]
		_check(definition.get("from_positions") == case["from"]
			and definition.get("to_positions") == case["to"]
			and definition.get("target_kind") == case["kind"]
			and definition.get("effects") == case["effects"],
			"independent authored fields and base effects: " + card_id)
		var detached: Dictionary = definition.duplicate(true)
		_check(panel._format_rules(detached) == case["text"],
			"three-line formatter exactly matches authored targeting/effects: " + card_id)
		_check(detached == definition, "formatter never mutates detached catalog card: " + card_id)
	# Mount valid three-offer groups through the same live receipt path. No
	# synthetic service or selection logic, and the final short group reuses
	# two other distinct IDs as legal fillers.
	var ids := expected.keys()
	for offset in range(0, ids.size(), 3):
		var receipt := base.duplicate(true)
		for slot in range(3):
			var id: String = ids[(offset + slot) % ids.size()]
			receipt["offers"][slot] = {"id": id, "owner": catalog.get_definition(id)["owner"]}
		var before := receipt.duplicate(true)
		_check(panel.open_rewards("catalog_preview", "Fight", receipt),
			"valid catalog-backed three-offer variant mounts " + str(offset))
		await _frames()
		_validate(receipt, "Fight", "catalog_preview")
		_check(receipt == before, "preview leaves variant receipt intact " + str(offset))
		panel.close_rewards()
		await _frames()
	_check(base == original, "authoritative prepared receipt unchanged by every variant")
	for card_id in authored_before:
		_check(catalog.get_definition(card_id) == authored_before[card_id],
			"authored catalog unchanged by formatter/mount: " + card_id)


func _validate(receipt: Dictionary, kind: String, node_id: String) -> void:
	_check(panel.has_open_rewards() and panel.is_visible_in_tree(), "actual scene mounted: " + kind)
	_check(panel.title_label.text.contains(kind), "reward title contains kind: " + kind)
	_check(not panel.title_label.text.contains(node_id) and not panel.title_label.text.contains("_"),
		"reward title is human-readable without raw node ID: " + kind)
	_check(panel.gold_label.text == "Pending gold: +%d" % receipt["gold_award"],
		"exact prepared pending gold visible: " + kind)
	_check(panel.trinket_label.visible == (kind == "Elite"), "Elite-only trinket label visibility")
	if kind == "Elite":
		_check(panel.trinket_label.text.contains("Thread Token"), "human-readable patch name visible: " + kind)
		_check(not panel.trinket_label.text.contains(receipt["trinket_drop_id"]) and not panel.trinket_label.text.contains("_"),
			"patch label does not expose raw trinket identifier or underscore")
	else:
		_check(panel.trinket_label.text.is_empty(), "non-Elite trinket label is empty")
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
		var rarity_label := content.get_node("RarityLabel") as Label
		var cost_label := content.get_node("CostLabel") as Label
		var rules_label := content.get_node_or_null("RulesLabel") as Label
		var action := content.get_node("ChooseButton") as Button
		_check(action == actions[index], "real action bound to card " + str(index))
		_check(owner_label.text == offer["owner"].capitalize()
			and name_label.text == definition["display_name"]
			and cost_label.text == "%d energy" % definition["cost"],
			"exact owner, name and cost visible: " + str(index))
		_check(rarity_label != null and (not rarity_label.visible or rarity_label.text.is_empty()),
			"legacy starter offer receives honest no-rarity presentation: " + str(index))
		_check(rarity_label != null and rarity_label.text != "Common",
			"starter offer never receives false Common: " + str(index))
		_assert_no_raw_identifiers(card, offer["id"], node_id, receipt.get("trinket_drop_id", ""))
		var expected := _expected_cards()
		_check(rules_label != null, "RulesLabel exists on live card " + str(index))
		if rules_label != null:
			_check(expected.has(offer["id"]), "prepared card has independent rule expectations " + offer["id"])
			if expected.has(offer["id"]):
				var authored: Dictionary = expected[offer["id"]]
				_check(definition["from_positions"] == authored["from"]
					and definition["to_positions"] == authored["to"]
					and definition["target_kind"] == authored["kind"]
					and definition["effects"] == authored["effects"],
					"authoritative definition matches displayed positional/effect contract " + offer["id"])
				_check(rules_label.text == authored["text"],
					"mounted card shows exact authored rules (including amounts) " + offer["id"])
			_check(rules_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
				and rules_label.get_theme_font_size("font_size") >= 15
				and rules_label.get_line_count() <= 3
				and rules_label.get_visible_line_count() == rules_label.get_line_count(),
				"rules are readable in at most three complete rendered lines " + offer["id"])
			_check(card.get_global_rect().encloses(rules_label.get_global_rect())
				and screen.encloses(rules_label.get_global_rect())
				and cost_label.get_global_rect().end.y <= rules_label.get_global_rect().position.y
				and rules_label.get_global_rect().end.y <= action.get_global_rect().position.y,
				"rules label fits card and never overlaps cost or button " + offer["id"])
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
	_check(panel.title_label.text.contains(kind), "refused overwrite keeps title")
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
	# Full-card paper/label clicks route through the same guarded action.
	requests.clear()
	var full_card := panel.choices_container.get_child(0) as PanelContainer
	var full_name := full_card.get_node("CardMargin/CardContent/NameLabel") as Label
	await _click(full_name)
	_check(requests == [{"node": node_id, "card": original["offers"][0]["id"]}],
		kind + " full-card label click requests exact offer once")
	for button in actions:
		_check(button.disabled, "full-card request disables all choices")
		button.pressed.emit()
	_check(requests.size() == 1, "duplicate pending requests rejected after full-card click")
	panel.acknowledge(false)
	_check(actions.all(func(button: Button) -> bool: return not button.disabled),
		"rejection re-enables after full-card click")
	# Paper-area click on another card.
	requests.clear()
	var second_card := panel.choices_container.get_child(1) as PanelContainer
	var paper_point := second_card.get_global_rect().position + Vector2(6, 6)
	var motion := InputEventMouseMotion.new()
	motion.position = paper_point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = paper_point
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_LEFT
		root.push_input(event, true)
	await _frames()
	_check(requests == [{"node": node_id, "card": original["offers"][1]["id"]}],
		kind + " full-card paper click requests exact offer once")
	panel.acknowledge(false)
	_check(actions.all(func(button: Button) -> bool: return not button.disabled),
		"rejection re-enables after paper click")
	requests.clear()
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
				content.get_node("RarityLabel").text, content.get_node("CostLabel").text,
				content.get_node("RulesLabel").text])
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


## A genuine prepared receipt whose offers come from the routed weighted path.
func _prepared_pool(is_elite: bool, seed_value: int) -> Dictionary:
	var party := CombatParty.new(_defs(HEROES))
	var enemies := CombatEnemies.new(_defs(ENEMIES))
	_check(party.is_valid() and enemies.is_valid(), "authored living battle rosters for pool receipt")
	var result := CombatBattleResult.new(party, enemies)
	for slot in range(1, enemies.get_enemies().size() + 1):
		_check(enemies.apply_damage(slot, enemies.get_enemy(slot).get("hp", 0)),
			"pool receipt enemy killed")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "pool receipt witnessed victory")
	var deck: Array[String] = StarterCards.new().get_starting_deck()
	var owners: Array[String] = ["warden", "seamstress", "tinker"]
	var records: Array = RunPoolCardRewardOffers.get_authored_base_candidates()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var service := RunFightVictoryRewards.new(result, rng, owners, records, deck, 97,
		is_elite, ["button_charm", "thread_token"], ["button_charm"])
	var receipt := service.prepare()
	_check(receipt.get("ok", false) and (receipt.get("offers", []) as Array).size() == 3,
		"weighted pool receipt prepares three distinct offers")
	for offer: Dictionary in receipt.get("offers", []):
		var definition := _base_pool_definition(String(offer.get("id", "")))
		_check(not definition.is_empty() and definition.get("owner") == offer.get("owner"),
			"weighted receipt offer resolves in its authored base pool: " + String(offer.get("id", "")))
	return {"receipt": receipt, "service": service, "rng": rng, "deck": deck}


## Direct catalog lookup for every reward-eligible D2-1 base card.
func _base_pool_definition(card_id: String) -> Dictionary:
	var warden := WardenPoolCards.new()
	if warden.get_base_ids().has(card_id):
		return warden.get_definition(card_id)
	var seamstress := SeamstressPoolCards.new()
	if seamstress.get_base_ids().has(card_id):
		return seamstress.get_definition(card_id)
	var tinker := TinkerPoolCards.new()
	if tinker.get_pool_card_ids().has(card_id):
		return tinker.get_definition(card_id)
	return {}


func _authored_base_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.append_array(WardenPoolCards.new().get_base_ids())
	ids.append_array(SeamstressPoolCards.new().get_base_ids())
	ids.append_array(TinkerPoolCards.new().get_pool_card_ids())
	return ids


## Independent copy of the documented preview contract, written from the
## authored catalog semantics for EVERY target kind and base-pool effect key.
## It intentionally does not call the panel formatter or its helpers, so a
## formatter that drops authored metadata cannot agree with this oracle.
func _expected_rules(definition: Dictionary) -> String:
	var kind: String = String(definition.get("target_kind", ""))
	var from_positions: Array = definition.get("from_positions", [])
	var from_text := ""
	match from_positions:
		[1]: from_text = "1 (front)"
		[3]: from_text = "3 (back)"
		[1, 2]: from_text = "1-2 (front/middle)"
		[2, 3]: from_text = "2-3 (middle/back)"
		[1, 2, 3]: from_text = "1-3 (front to back)"
	var target_positions: Array = definition.get("to_positions", [])
	var slots := ""
	match target_positions:
		[1]: slots = "1 (front)"
		[1, 2]: slots = "1-2"
		[2, 3]: slots = "2-3"
		[1, 2, 3]: slots = "1-3"
	var target_text := ""
	if kind == "enemy_single":
		target_text = "pick 1 living enemy " + slots
	elif kind == "enemy_all":
		target_text = "all living enemies " + slots
	elif kind == "enemy_random":
		target_text = "1 random living enemy per hit " + slots
	elif kind == "self":
		target_text = "self"
	elif kind == "ally_single":
		target_text = "1 living ally 1-3"
	elif kind == "party_all":
		target_text = "all allies"
	elif kind == "none":
		target_text = "none"
	var effects: Dictionary = definition.get("effects", {})
	var hits: int = int(effects.get("hits", effects.get("hit_count", 1)))
	var until_next_turn: bool = String(effects.get("duration", "")) == "until_next_turn"
	var copy: Array[String] = []
	for key: String in effects:
		if key == "damage":
			var line := "Deal %d damage" % int(effects["damage"])
			if hits > 1:
				line += " ×%d hits" % hits
			elif kind == "enemy_all":
				line += " EACH"
			if bool(effects.get("random_target_each_hit", false)):
				line += " (random target each hit)"
			if effects.has("conditional_damage"):
				var condition: Dictionary = effects["conditional_damage"] if effects["conditional_damage"] is Dictionary else {}
				var terms: Array[String] = []
				for item: Variant in condition.get("conditions", []):
					if not item is Dictionary:
						continue
					var part: Dictionary = item
					if part.has("status"):
						terms.append(String(part["status"]).capitalize())
					elif part.has("gauge"):
						var gauge := String(part["gauge"]).capitalize()
						terms.append(gauge + (" at half"
							if String(part.get("comparison", "")) == "at_least_half"
							else " " + String(part.get("comparison", "")).replace("_", " ")))
				var join_word := " and " if String(condition.get("operator", "or")) == "and" else " or "
				line += (" (%d instead under a condition)" % int(condition.get("damage", 0))) \
					if terms.is_empty() \
					else (" (%d instead if %s)" % [int(condition.get("damage", 0)), join_word.join(terms)])
			copy.append(line)
		elif key == "block":
			if kind == "ally_single":
				copy.append("Chosen ally gains %d Block" % int(effects["block"]))
			elif kind == "self":
				copy.append("Gain %d Block" % int(effects["block"]))
			else:
				copy.append("Gain %d Block" % int(effects["block"]))
		elif key == "block_all":
			copy.append("All allies gain %d Block each" % int(effects["block_all"]))
		elif key == "other_ally_block":
			copy.append("Every other ally gains %d Block" % int(effects["other_ally_block"]))
		elif key == "heal":
			if kind == "ally_single":
				copy.append("Chosen ally heals %d HP" % int(effects["heal"]))
			elif kind == "party_all":
				copy.append("All allies heal %d HP each" % int(effects["heal"]))
			else:
				copy.append("Heal %d HP" % int(effects["heal"]))
		elif key == "draw":
			copy.append("Draw %d card%s" % [int(effects["draw"]), "" if int(effects["draw"]) == 1 else "s"])
		elif key == "weak":
			copy.append("Weak %d" % int(effects["weak"]))
		elif key == "bleed":
			copy.append("Bleed %d%s" % [int(effects["bleed"]), " EACH" if kind == "enemy_all" else ""])
		elif key == "bleed_multiplier":
			copy.append("Bleed ×%d" % int(effects["bleed_multiplier"]))
		elif key == "unravel":
			copy.append("Unravel %d" % int(effects["unravel"]))
		elif key == "exposed":
			copy.append("Exposed %d" % int(effects["exposed"]))
		elif key == "pinned":
			var bonus := 5
			if effects["pinned"] is Dictionary and (effects["pinned"] as Dictionary).get("bonus_damage") is int:
				bonus = int((effects["pinned"] as Dictionary)["bonus_damage"])
			copy.append("Pinned (+%d damage on another hero's next attack, once)" % bonus)
		elif key == "guarding":
			copy.append("Guarding" + (" until next turn" if until_next_turn else ""))
		elif key == "thorns":
			copy.append("Thorns %d%s" % [int(effects["thorns"]),
				" until next turn" if until_next_turn else ""])
		elif key == "energy" or key == "gain_energy":
			copy.append("Gain +%d energy" % int(effects[key]))
		elif key == "self_hp_loss":
			copy.append("%d HP lost" % int(effects["self_hp_loss"]))
		elif key == "conditional_damage" and not effects.has("damage"):
			var orphan: Dictionary = effects["conditional_damage"] if effects["conditional_damage"] is Dictionary else {}
			copy.append("Deal %d damage conditionally" % int(orphan.get("damage", 0)))
	return "From: %s\nTarget: %s\n%s" % [from_text, target_text, ", ".join(copy)]


## Structural qualifier keys that never render their own clause; every other
## authored effect key must produce one, and the oracle above must cover it.
func _covered_effect_keys() -> Array[String]:
	return ["damage", "block", "block_all", "other_ally_block", "heal", "draw", "weak",
		"bleed", "bleed_multiplier", "unravel", "exposed", "pinned", "guarding", "thorns",
		"energy", "gain_energy", "self_hp_loss", "conditional_damage", "hits", "hit_count",
		"random_target_each_hit", "rng_source", "living_targets_only", "duration"]


## Explicit authored phrases the mounted preview must show, so a shared
## omission in formatter and oracle cannot pass unnoticed.
func _required_rule_phrases(card_id: String) -> Array[String]:
	match card_id:
		"warden_bastion_quilt":
			return ["all allies", "10 Block each"]
		"warden_hold_the_line":
			return ["Every other ally gains 2 Block"]
		"seamstress_darning":
			return ["Chosen ally heals 4 HP", "Chosen ally gains 3 Block"]
		"seamstress_stitch_up":
			return ["Chosen ally gains 5 Block"]
		"tinker_sight_glass":
			return ["Exposed 2", "Draw 1 card"]
		"seamstress_red_thread":
			return ["Bleed 6", "Exposed 1"]
		"tinker_overclock":
			return ["+1 energy", "3 HP lost"]
		"tinker_ricochet":
			return ["Deal 4 damage", "×3 hits", "random target each hit"]
	return []


## The mounted card must show the real authored pool card it resolves to.
func _validate_pool(receipt: Dictionary, kind: String, node_id: String) -> void:
	_check(panel.has_open_rewards() and panel.is_visible_in_tree(), "pool reward mounted: " + kind)
	_check(panel.title_label.text.contains(kind), "pool title contains kind: " + kind)
	_check(not panel.title_label.text.contains(node_id) and not panel.title_label.text.contains("_"),
		"pool title is human-readable without raw node ID: " + kind)
	_check(panel.gold_label.text == "Pending gold: +%d" % receipt["gold_award"],
		"exact prepared pool pending gold visible: " + kind)
	_check(panel.trinket_label.visible == (kind == "Elite"), "Elite-only pool trinket label visibility")
	if kind == "Elite":
		_check(panel.trinket_label.text.contains("Thread Token"), "human-readable pool patch name visible: " + kind)
		_check(not panel.trinket_label.text.contains(receipt["trinket_drop_id"]) and not panel.trinket_label.text.contains("_"),
			"pool patch label does not expose raw trinket identifier or underscore")
	else:
		_check(panel.trinket_label.text.is_empty(), "non-Elite pool trinket label is empty")
	var actions := panel.get_choice_buttons()
	_check(actions.size() == 4 and panel.choices_container.get_child_count() == 3,
		"pool reward shows three genuine cards and Skip")
	if actions.size() != 4:
		return
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	for index in range(3):
		var offer: Dictionary = receipt["offers"][index]
		var card_id := String(offer.get("id", ""))
		var owner := String(offer.get("owner", ""))
		var definition := _base_pool_definition(card_id)
		_check(not definition.is_empty() and definition.get("owner") == owner,
			"prepared pool offer backed by its authored catalog: " + card_id)
		if definition.is_empty():
			continue
		_check(_authored_base_ids().has(card_id) and not card_id.ends_with("_plus"),
			"only reward-eligible base pool cards are offered: " + card_id)
		var card := panel.choices_container.get_child(index) as PanelContainer
		_check(card != null and card.name == "Card_%d" % index, "stable pool card index")
		if card == null:
			continue
		var content := card.get_node("CardMargin/CardContent") as VBoxContainer
		var owner_label := content.get_node("OwnerLabel") as Label
		var name_label := content.get_node("NameLabel") as Label
		var rarity_label := content.get_node("RarityLabel") as Label
		var cost_label := content.get_node("CostLabel") as Label
		var rules_label := content.get_node("RulesLabel") as Label
		var action := content.get_node("ChooseButton") as Button
		_check(action == actions[index], "real pool action bound to card " + str(index))
		_check(owner_label.text == owner.capitalize()
			and name_label.text == definition["display_name"]
			and cost_label.text == "%d energy" % definition["cost"],
			"exact authored pool owner, name and cost visible: " + card_id)
		var expected_rarity: String = String(definition.get("rarity", "")).capitalize()
		_check(rarity_label != null and rarity_label.visible and rarity_label.text == expected_rarity,
			"RarityLabel matches authored rarity: %s (%s)" % [expected_rarity, card_id])
		var sewn_box := rarity_label.get_theme_stylebox("normal") as StyleBoxFlat
		_check(sewn_box != null and sewn_box.border_width_left >= 1,
			"RarityLabel has visible sewn accent border: " + card_id)
		_check(sewn_box != null and sewn_box.border_color != panel.OWNER_COLORS[owner],
			"RarityLabel sewn border color distinguishable from owner: " + card_id)
		_check(sewn_box != null and sewn_box.bg_color != panel.OWNER_COLORS[owner],
			"RarityLabel sewn tag color distinguishable from owner: " + card_id)
		_assert_no_raw_identifiers(card, card_id, node_id, receipt.get("trinket_drop_id", ""))
		_check(rules_label.text == _expected_rules(definition),
			"pool card rules match its authored catalog definition: " + card_id)
		var rule_lines := rules_label.text.split("\n")
		_check(rule_lines.size() == 3 and rule_lines[0].begins_with("From: ")
			and rule_lines[1].begins_with("Target: ")
			and not rule_lines[0].substr(6).strip_edges().is_empty()
			and not rule_lines[1].substr(8).strip_edges().is_empty()
			and not rule_lines[2].strip_edges().is_empty(),
			"pool card shows nonblank from, target and effect text: " + card_id)
		var effects: Dictionary = definition.get("effects", {})
		for effect_key: String in effects:
			_check(_covered_effect_keys().has(effect_key),
				"authored pool effect key is rendered: %s (%s)" % [effect_key, card_id])
			var value: Variant = effects[effect_key]
			if value is int:
				_check(rules_label.text.contains(str(value)),
					"authored pool value %d visible for %s" % [int(value), card_id])
		for phrase: String in _required_rule_phrases(card_id):
			_check(rules_label.text.contains(phrase),
				"authored rule phrase '%s' visible for %s" % [phrase, card_id])
		_check(rules_label.get_visible_line_count() == rules_label.get_line_count()
			and rules_label.get_theme_font_size("font_size") >= 15,
			"pool rules fully rendered and readable: " + card_id)
		_check(card.get_global_rect().encloses(rules_label.get_global_rect())
			and screen.encloses(rules_label.get_global_rect())
			and screen.encloses(card.get_global_rect()) and screen.encloses(action.get_global_rect()),
			"pool card, rules and action fit the card and 1280x720 viewport: " + card_id)
		for label: Label in [owner_label, name_label, rarity_label, cost_label, rules_label]:
			_check(card.get_global_rect().encloses(label.get_global_rect())
				and screen.encloses(label.get_global_rect()),
				"pool label stays visible on the card and in 1280x720: " + card_id)
		var style := card.get_theme_stylebox("panel") as StyleBoxFlat
		_check(style != null and style.border_color == panel.OWNER_COLORS[owner],
			"authored pool owner palette visible: " + card_id)
	_check(actions[3] == panel.skip_button and actions[3].text.contains("Skip"),
		"fourth pool action is Skip, never a card")
	_check(screen.encloses(panel.skip_button.get_global_rect())
		and panel.skip_button.is_visible_in_tree() and not panel.skip_button.disabled,
		"pool Skip control stays visible in 1280x720")


func _exercise_pool(fixture: Dictionary, kind: String) -> void:
	var node_id := "floor_02_elite" if kind == "Elite" else "floor_01_fight"
	var receipt: Dictionary = fixture["receipt"]
	var prepared_before: Dictionary = fixture["service"].prepare()
	var rng_state: int = fixture["rng"].state
	requests.clear()
	_check(panel.open_rewards(node_id, kind, receipt), kind + " weighted receipt opens the real panel")
	await _frames()
	_validate_pool(receipt, kind, node_id)
	var actions := panel.get_choice_buttons()
	if actions.size() != 4:
		panel.close_rewards()
		return
	# Full-card click on a pool card label routes through the same guard.
	requests.clear()
	var pool_card := panel.choices_container.get_child(0) as PanelContainer
	var pool_name := pool_card.get_node("CardMargin/CardContent/NameLabel") as Label
	await _click(pool_name)
	_check(requests == [{"node": node_id, "card": receipt["offers"][0]["id"]}],
		"pool full-card label click requests exact offer once")
	panel.acknowledge(false)
	_check(actions.all(func(button: Button) -> bool: return not button.disabled),
		"pool rejection re-enables after full-card click")
	requests.clear()
	var target: int = 1 if kind == "Fight" else 2
	await _mouse(actions[target])
	_check(requests == [{"node": node_id, "card": receipt["offers"][target]["id"]}],
		"physical mouse pick requests exactly the weighted pool ID")
	panel.acknowledge(false)
	_check(actions.all(func(button: Button) -> bool: return not button.disabled),
		"rejection re-enables the same pool offers")
	_validate_pool(receipt, kind, node_id)
	actions[3].grab_focus()
	await _frames()
	_check(actions[3].has_focus(), "pool Skip focused before Space")
	await _key(KEY_SPACE)
	_check(requests.size() == 2 and requests[1] == {"node": node_id, "card": ""},
		"physical keyboard Skip requests the empty skip ID once")
	panel.acknowledge(true)
	_check(panel._accepted, "accepted pool claim stays latched")
	for button in actions:
		_check(button.disabled, "accepted pool claim locks every action")
	_check(fixture["service"].prepare() == prepared_before and fixture["rng"].state == rng_state,
		"panel never rerolls or settles the weighted reward transaction")
	panel.close_rewards()
	await _frames()
	_check(not panel.has_open_rewards() and panel.get_choice_buttons().is_empty(),
		"weighted pool reward closes cleanly")


func _test_pool_replay(first: Dictionary) -> void:
	var second := _prepared_pool(false, 18203)
	_check(second["receipt"].get("offers") == first["receipt"].get("offers"),
		"same seeded stream prepares identical weighted pool offers")
	var presentations: Array = []
	for fixture in [first, second]:
		_check(panel.open_rewards("replay_node", "Fight", fixture["receipt"]),
			"seeded weighted receipt reopens")
		await _frames()
		var ui: Array = []
		for index in range(3):
			var content := panel.choices_container.get_child(index).get_node("CardMargin/CardContent")
			ui.append([content.get_node("OwnerLabel").text, content.get_node("NameLabel").text,
				content.get_node("RarityLabel").text, content.get_node("CostLabel").text,
				content.get_node("RulesLabel").text])
		presentations.append(ui)
		panel.close_rewards()
		await _frames()
	_check(presentations.size() == 2 and presentations[0] == presentations[1],
		"same-seed weighted receipts present identical pool card text")


## Every authored reward-eligible base card must mount, while upgrades and
## mislabelled/unknown pool-shaped IDs stay rejected.
func _test_all_pool_cards(base: Dictionary) -> void:
	var ids := _authored_base_ids()
	_check(ids.size() >= 3, "authored reward pools expose base cards")
	# The three defect cards must really be mounted by the loop below.
	for required in ["warden_bastion_quilt", "tinker_overclock", "tinker_ricochet"]:
		_check(ids.has(required), "defect card is an authored reward-eligible base card: " + required)
	requests.clear()
	for offset in range(0, ids.size(), 3):
		var receipt := base.duplicate(true)
		for slot in range(3):
			var card_id: String = ids[(offset + slot) % ids.size()]
			receipt["offers"][slot] = {"id": card_id,
				"owner": String(_base_pool_definition(card_id).get("owner", ""))}
		var before := receipt.duplicate(true)
		_check(panel.open_rewards("pool_preview", "Fight", receipt),
			"authored base pool cards mount " + str(offset))
		if not panel.has_open_rewards():
			continue
		await _frames()
		_validate_pool(receipt, "Fight", "pool_preview")
		_check(receipt == before, "pool preview leaves its receipt intact " + str(offset))
		panel.close_rewards()
		await _frames()
	for plus_id in ["warden_hold_the_line_plus", "seamstress_needle_pin_plus", "tinker_rivet_shot_plus"]:
		var owner := String(_base_pool_definition(plus_id.trim_suffix("_plus")).get("owner", ""))
		var receipt := base.duplicate(true)
		receipt["offers"][0] = {"id": plus_id, "owner": owner}
		_check(not panel.open_rewards("pool_preview", "Fight", receipt),
			"pool upgrade is never a reward offer: " + plus_id)
		_check(not panel.visible and not panel.has_open_rewards(),
			"rejected pool upgrade mounts no controls: " + plus_id)
	var mislabelled := base.duplicate(true)
	mislabelled["offers"][1] = {"id": "warden_hold_the_line", "owner": "tinker"}
	_check(not panel.open_rewards("pool_preview", "Fight", mislabelled),
		"pool offer with a wrong owner rejects")
	var foreign := base.duplicate(true)
	foreign["offers"][2] = {"id": "warden_bogus_pool_card", "owner": "warden"}
	_check(not panel.open_rewards("pool_preview", "Fight", foreign),
		"unknown pool-shaped ID rejects instead of resolving")
	_check(requests.is_empty(), "pool mount suite never emits a request")



func _assert_no_raw_identifiers(card_panel: PanelContainer, card_id: String, node_id: String, trinket_id: String) -> void:
	var labels: Array[Label] = [panel.title_label, panel.gold_label, panel.trinket_label]
	var content := card_panel.get_node("CardMargin/CardContent")
	for child in content.get_children():
		if child is Label:
			labels.append(child)
	for label: Label in labels:
		if label.visible and not label.text.is_empty():
			_check(not label.text.contains(card_id),
				"visible label %s never contains raw card id %s" % [label.name, card_id])
			_check(not label.text.contains(node_id),
				"visible label %s never contains raw node id %s" % [label.name, node_id])
			if not trinket_id.is_empty():
				_check(not label.text.contains(trinket_id),
					"visible label %s never contains raw trinket id %s" % [label.name, trinket_id])


func _test_three_tier_rarities(base: Dictionary) -> void:
	var common_cand := {}
	var uncommon_cand := {}
	var rare_cand := {}
	for cand in RunPoolCardRewardOffers.get_authored_base_candidates():
		var r: String = cand.get("rarity", "")
		var o: String = cand.get("owner", "")
		if r == "common" and o == "warden" and common_cand.is_empty():
			common_cand = cand
		elif r == "uncommon" and o == "tinker" and uncommon_cand.is_empty():
			uncommon_cand = cand
		elif r == "rare" and o == "seamstress" and rare_cand.is_empty():
			rare_cand = cand
	_check(not common_cand.is_empty() and not uncommon_cand.is_empty() and not rare_cand.is_empty(),
		"authored catalog provides distinct candidates across all three rarities and heroes")
	if common_cand.is_empty() or uncommon_cand.is_empty() or rare_cand.is_empty():
		return

	var receipt: Dictionary = base.duplicate(true)
	receipt["offers"] = [
		{"id": common_cand["id"], "owner": common_cand["owner"]},
		{"id": uncommon_cand["id"], "owner": uncommon_cand["owner"]},
		{"id": rare_cand["id"], "owner": rare_cand["owner"]},
	]
	var node_id := "floor_01_fight"
	requests.clear()
	_check(panel.open_rewards(node_id, "Fight", receipt), "three-tier rarity receipt mounts successfully")
	await _frames()
	_validate_pool(receipt, "Fight", node_id)

	var expected_tiers := ["Common", "Uncommon", "Rare"]
	var card_cands := [common_cand, uncommon_cand, rare_cand]
	for i in range(3):
		var card := panel.choices_container.get_child(i) as PanelContainer
		var content := card.get_node("CardMargin/CardContent") as VBoxContainer
		var rarity_label := content.get_node("RarityLabel") as Label
		_check(rarity_label != null and rarity_label.visible and rarity_label.text == expected_tiers[i],
			"card %d displays exact stitched rarity %s" % [i, expected_tiers[i]])
		var sewn_box := rarity_label.get_theme_stylebox("normal") as StyleBoxFlat
		_check(sewn_box != null and sewn_box.border_width_left >= 1,
			"card %d rarity has visible sewn accent border" % i)
		_check(sewn_box != null and sewn_box.bg_color == panel.RARITY_COLORS[card_cands[i]["rarity"]],
			"card %d rarity tag uses distinct palette" % i)

	var buttons := panel.get_choice_buttons()
	await _mouse(buttons[2])
	_check(requests == [{"node": node_id, "card": rare_cand["id"]}],
		"physical click emits exact opaque node_id and rare card_id")
	panel.acknowledge(true)
	panel.close_rewards()
	await _frames()


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
	await _test_all_catalog_rules(original_fight)
	_malformed(original_fight)
	await _replay_and_stale(original_fight)
	var pool_fight := _prepared_pool(false, 18203)
	var pool_elite := _prepared_pool(true, 18203)
	_check(pool_fight["receipt"].get("ok", false) and pool_elite["receipt"].get("ok", false),
		"live weighted Fight and Elite receipts exist")
	if pool_fight["receipt"].get("ok", false) and pool_elite["receipt"].get("ok", false):
		await _exercise_pool(pool_fight, "Fight")
		await _exercise_pool(pool_elite, "Elite")
		await _test_pool_replay(pool_fight)
		await _test_all_pool_cards(original_fight)
		await _test_three_tier_rarities(original_fight)
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
