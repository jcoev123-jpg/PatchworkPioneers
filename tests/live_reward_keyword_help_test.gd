extends SceneTree
## Authored keyword text and real prepared Fight/Elite reward panel interactions.
const SCENE := "res://scenes/run_card_reward_choice_panel.tscn"
const HEROES := "res://data/heroes/starter_party.json"
const ENEMIES := "res://data/enemies/starter_enemies.json"

var failures: Array[String] = []
var checks := 0
var panel: LiveRunCardRewardChoicePanel
var requests: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
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


func _mouse(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _defs(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "authored roster opens " + path)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Array and not parsed.is_empty(), "authored roster parsed " + path)
	if not parsed is Array:
		return []
	var result: Array = []
	for raw in parsed:
		var item: Dictionary = (raw as Dictionary).duplicate(true)
		item["max_hp"] = int(item.get("max_hp", 0))
		result.append(item)
	return result


func _prepared(kind: String, seed_value: int, use_pool: bool = true) -> Dictionary:
	var party := CombatParty.new(_defs(HEROES))
	var enemies := CombatEnemies.new(_defs(ENEMIES))
	_check(party.is_valid() and enemies.is_valid(), "genuine combat roster is valid")
	var result := CombatBattleResult.new(party, enemies)
	_check(result.get_outcome() == CombatBattleResult.ACTIVE, "combat starts active")
	for slot in range(1, enemies.get_enemies().size() + 1):
		_check(enemies.apply_damage(slot, enemies.get_enemy(slot).get("hp", 0)),
			"kill real enemy to witness victory")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "witnessed victory")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck: Array[String] = StarterCards.new().get_starting_deck()
	var candidates: Array = RunPoolCardRewardOffers.get_authored_base_candidates() \
		if use_pool else StarterCards.new().get_all_card_ids()
	var service := RunFightVictoryRewards.new(result, rng,
		["warden", "seamstress", "tinker"], candidates, deck, 97,
		kind == "Elite", ["button_charm", "thread_token"], ["button_charm"])
	var receipt: Dictionary = service.prepare()
	_check(receipt.get("ok", false) and receipt.get("offers", []).size() == 3,
		"genuine prepared %s receipt with three offers" % kind)
	return {"rng": rng, "deck": deck, "party": party, "enemies": enemies,
		"result": result, "service": service, "receipt": receipt, "wallet": 97,
		"scraps": 0, "trinkets": ["button_charm"]}


func _snapshot(fixture: Dictionary) -> Dictionary:
	return {"seed": fixture["rng"].seed, "rng": fixture["rng"].state,
		"deck": fixture["deck"].duplicate(true), "gold": fixture["wallet"],
		"scraps": fixture["scraps"], "trinkets": fixture["trinkets"].duplicate(true),
		"party": fixture["party"].get_heroes(), "enemies": fixture["enemies"].get_enemies(),
		"outcome": fixture["result"].get_outcome(),
		"claimed": fixture["service"]._choice.is_claimed(),
		"receipt": fixture["receipt"].duplicate(true),
		"prepared": fixture["service"].prepare(),
		"panel_receipt": panel._receipt.duplicate(true)}


func _catalog_test() -> void:
	var warden := WardenPoolCards.new()
	var seamstress := SeamstressPoolCards.new()
	var tinker := TinkerPoolCards.new()
	var starter := StarterCards.new()
	var cases := [
		[warden, "warden_pinning_jab", ["Pinned"], ["DIFFERENT hero", "+5", "before Weak/Exposed", "expires"]],
		[warden, "warden_draw_fire", ["Guarding"], ["position 1", "other heroes", "next turn"]],
		[warden, "warden_counter_stitch", ["Thorns 3"], ["3 damage", "positions 1-2", "next turn"]],
		[seamstress, "seamstress_running_stitch", ["Bleed 3"], ["3 HP", "decreases by 1", "1 Unravel"]],
		[seamstress, "seamstress_snag", ["Weak 1", "Unravel 3"], ["25%", "8, elite 12, boss 16", "NEXT action", "rises by 4"]],
		[seamstress, "seamstress_red_thread", ["Bleed 6", "Exposed 1"], ["6 HP", "50%", "rounds down"]],
		[tinker, "tinker_spring_trap", ["Pinned"], ["DIFFERENT hero", "+5", "before Weak/Exposed"]],
		[tinker, "tinker_rivet_shot", ["Exposed 1"], ["50%", "minimum 0"]],
		[tinker, "tinker_spool_launcher", ["Unravel 3"], ["gauge", "normal 8"]],
		[starter, "warden_strike", [], []],
	]
	for case in cases:
		var catalog: Variant = case[0]
		var id: String = case[1]
		var ids: Array[String] = catalog.get_all_card_ids() if catalog is StarterCards \
			else (catalog.get_pool_card_ids() if catalog is TinkerPoolCards else catalog.get_base_ids())
		_check(ids.has(id), "required ID present in independent stable catalog " + id)
		var def: Dictionary = catalog.get_definition(id)
		_check(not def.is_empty() and def.get("id") == id, "actual definition " + id)
		if def.is_empty():
			continue
		var original: Dictionary = def.duplicate(true)
		var entries := CardKeywordGlossary.describe(def)
		var actual: Array[String] = []
		var words := ""
		for entry: Dictionary in entries:
			actual.append(String(entry["keyword"]))
			words += String(entry["explanation"]) + " "
		_check(actual == case[2], "fixed keyword order and numeric values for " + id)
		for phrase: String in case[3]:
			_check(words.contains(phrase), "mechanics '%s' for %s" % [phrase, id])
		_check(def == original and catalog.get_definition(id) == original,
			"glossary never mutates catalog or caller definition " + id)
		if not entries.is_empty():
			entries[0]["keyword"] = "Tampered"
			entries[0]["explanation"] = "Tampered"
			_check(CardKeywordGlossary.describe(def)[0]["keyword"] == case[2][0]
				and def == original, "glossary results are detached " + id)
	var reordered := {"id": "warden_strike", "effects": {
		"thorns": 3, "unravel": 3, "junk": 4, "bleed": 2,
		"guarding": true, "weak": 1, "pinned": true, "exposed": 1}}
	var expected := ["Bleed 2", "Weak 1", "Exposed 1", "Pinned",
		"Unravel 3", "Guarding", "Thorns 3"]
	var original := reordered.duplicate(true)
	var actual: Array[String] = []
	for entry: Dictionary in CardKeywordGlossary.describe(reordered):
		actual.append(entry["keyword"])
	_check(actual == expected, "seven combined keywords stable and once each")
	_check(reordered == original, "compound input untouched")
	_check(CardKeywordGlossary.describe({"effects": {"damage": 6, "unknown": 1}}).is_empty(),
		"unrecognized and ordinary effects never invent help")
	_check(CardKeywordGlossary.describe({"effects": {}}).is_empty()
		and CardKeywordGlossary.describe({}).is_empty()
		and CardKeywordGlossary.describe(null).is_empty(),
		"empty and invalid effects produce no help")


func _help_in_fixture(fixture: Dictionary, kind: String) -> void:
	var receipt: Dictionary = fixture["receipt"]
	if not receipt.get("ok", false):
		return
	var slot := -1
	for i in range(3):
		var definition := RunPoolCardRewardOffers.resolve_reward_definition(receipt["offers"][i]["id"])
		if not CardKeywordGlossary.describe(definition).is_empty():
			slot = i
			break
	_check(slot >= 0, "seeded %s receipt really contains a keyword offer" % kind)
	if slot < 0:
		return
	var node_id := "reward_%s" % kind.to_lower()
	_check(panel.open_rewards(node_id, kind, receipt), "mounted genuine %s receipt" % kind)
	await _frames()
	if not panel.has_open_rewards():
		return
	var before := _snapshot(fixture)
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 4 and panel.choices_container.get_child_count() == 3,
		"mounted three authored choices and Skip")
	var card := panel.choices_container.get_child(slot) as PanelContainer
	var help := card.get_node_or_null("HelpCorner/HelpButton") as Button
	_check(help != null and help.text == "Help" and help.focus_mode == Control.FOCUS_ALL,
		"keyword offer gets styled Help control")
	if help == null:
		panel.close_rewards()
		return
	_check(help.get_theme_stylebox("normal") is StyleBoxFlat
		and help.get_node_or_null("FocusStitch") != null, "Help has sewn button/focus style")
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	var choose := card.get_node("CardMargin/CardContent/ChooseButton") as Button
	_check(screen.encloses(help.get_global_rect())
		and card.get_global_rect().encloses(help.get_global_rect()),
		"Help tab lies inside its card and the 1280x720 screen")
	_check(not help.get_global_rect().intersects(choose.get_global_rect()),
		"Help tab cannot cover Choose input geometry")
	var old_generation := panel._generation
	var old_pressed: Callable = help.pressed.get_connections()[0]["callable"]
	await _mouse(help)
	var overlay := panel.get_node_or_null("KeywordHelpOverlay") as PanelContainer
	_check(overlay != null and panel._help_overlay == overlay, "actual mouse opens in-panel Help")
	if overlay == null:
		panel.close_rewards()
		return
	_check(overlay.get_theme_stylebox("panel") is StyleBoxFlat,
		"parchment/felt popup styled, not default grey")
	_check(screen.encloses(overlay.get_global_rect())
		and not overlay.get_global_rect().intersects(panel.skip_button.get_global_rect()),
		"Help popup fits 1280x720 and leaves Skip unobscured")
	var definition := RunPoolCardRewardOffers.resolve_reward_definition(receipt["offers"][slot]["id"])
	var title := overlay.get_node("HelpContent/HelpTitle") as Label
	_check(title.text.contains(definition["display_name"]) and not title.text.contains("_"),
		"popup uses current authored human card name")
	var list := overlay.get_node("HelpContent/KeywordScroll/KeywordLines") as VBoxContainer
	var entries := CardKeywordGlossary.describe(definition)
	_check(list.get_child_count() == entries.size() and entries.size() > 0,
		"only matching offered keywords in popup")
	for i in range(entries.size()):
		var label := list.get_child(i) as Label
		_check(label.text.contains(entries[i]["keyword"])
			and label.text.contains(entries[i]["explanation"]),
			"full readable explanation for actual %s keyword %d" % [kind, i])
	var close := overlay.get_node("HelpContent/CloseHelpButton") as Button
	_check(close.has_focus(), "mouse Help opens focused Close")
	_check(screen.encloses(close.get_global_rect())
		and overlay.get_global_rect().encloses(close.get_global_rect()),
		"Close help is visible within felt popup and viewport")
	_check(_snapshot(fixture) == before and requests.is_empty()
		and not panel._awaiting_ack and not panel._accepted,
		"mouse inspection preserves RNG/receipt/deck/wallet/models and emits nothing")
	# Headless dummy rendering has no readable viewport texture; inspect the
	# mounted 1280x720 layout without writing PNG or art files.
	_check(root.size == Vector2i(1280, 720) and overlay.is_visible_in_tree()
		and overlay.get_global_rect().has_point(root.size * 0.5),
		"reward/help overlay is visible in the actual 1280x720 viewport")
	await _key(KEY_ESCAPE)
	_check(panel._help_overlay == null and help.has_focus(),
		"Escape closes and restores invoking Help focus")
	buttons[slot].grab_focus()
	await _key(KEY_RIGHT)
	_check(help.has_focus(), "keyboard-only Right from Choose focuses its own Help")
	await _key(KEY_ENTER)
	_check(panel._help_overlay != null, "keyboard Enter reopens focused Help")
	await _frames()
	var close_two := panel._help_overlay.get_node("HelpContent/CloseHelpButton") as Button
	await _key(KEY_SPACE)
	_check(panel._help_overlay == null and help.has_focus(),
		"keyboard Space activates focused Close and returns focus")
	await _key(KEY_ENTER)
	_check(panel._help_overlay != null, "third Help opens for direct mouse Close")
	var close_three := panel._help_overlay.get_node("HelpContent/CloseHelpButton") as Button
	await _mouse(close_three)
	_check(panel._help_overlay == null and help.has_focus(),
		"mouse Close restores Help focus")
	_check(_snapshot(fixture) == before and requests.is_empty(),
		"all inspections remain read-only with zero requests")
	# Inspecting Help may precede a real choice. A user click, never Help,
	# causes exactly one request even if repeated before acknowledgement.
	await _mouse(help)
	var chosen_id: String = receipt["offers"][slot]["id"]
	buttons[slot].pressed.emit()
	buttons[slot].pressed.emit()
	_check(panel._help_overlay == null and requests == [{"node": node_id, "card": chosen_id}],
		"Choose disposes Help and emits exactly one real offer: %s; overlay=%s" % [str(requests), str(panel._help_overlay)])
	_check(panel._awaiting_ack and not panel._accepted, "Choose waits for caller acknowledgement")
	_check(_snapshot(fixture) == before, "Choose request leaves prepared service unclaimed")
	panel.acknowledge(false)
	_check(not buttons[slot].disabled, "rejected request re-enables original offered card")
	await _mouse(help)
	buttons[3].grab_focus()
	await _key(KEY_SPACE)
	_check(panel._help_overlay == null and requests.size() == 2
		and requests[1] == {"node": node_id, "card": ""},
		"Skip dismisses help and emits empty card ID exactly once: %s; overlay=%s" % [str(requests), str(panel._help_overlay)])
	panel.acknowledge(true)
	_check(panel._accepted and buttons.all(func(b: Button) -> bool: return b.disabled),
		"accepted Skip remains latched")
	_check(_snapshot(fixture) == before, "requests and Help leave service, receipt, RNG and models unchanged")
	panel.close_rewards()
	_check(not panel.has_open_rewards() and panel._help_overlay == null,
		"close disposes Help and receipt")
	_check(not panel.open_rewards("", kind, receipt) and panel._help_overlay == null,
		"invalid receipt request cannot display stale Help")
	_check(panel.open_rewards(node_id, kind, receipt), "closed panel can reopen the same genuine receipt")
	await _frames()
	old_pressed.call()
	panel._on_help_pressed(old_generation, node_id, slot, chosen_id, help)
	_check(panel._help_overlay == null and panel._receipt == receipt and not panel._awaiting_ack,
		"stale generation callback cannot reveal prior offer or request")
	_check(requests.size() == 2, "old Help never emits a choice on reopened receipt")
	panel.close_rewards()
	await _frames()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_catalog_test()
	var scene := load(SCENE) as PackedScene
	_check(scene != null, "live reward scene loads")
	if scene == null:
		_finish()
		return
	panel = scene.instantiate() as LiveRunCardRewardChoicePanel
	_check(panel != null, "live scene mounts actual reward script")
	if panel == null:
		_finish()
		return
	root.add_child(panel)
	panel.choice_requested.connect(func(n: String, id: String) -> void:
		requests.append({"node": n, "card": id}))
	await _frames()
	for kind in ["Fight", "Elite"]:
		requests.clear()
		# Find a deterministic genuine prepared reward with at least one applicable
		# keyword; never synthesize or replace offer IDs in its receipt.
		var fixture := {}
		for seed_value in range(18203, 18243):
			var candidate := _prepared(kind, seed_value)
			for offer: Dictionary in candidate["receipt"].get("offers", []):
				var definition := RunPoolCardRewardOffers.resolve_reward_definition(offer["id"])
				if not CardKeywordGlossary.describe(definition).is_empty():
					fixture = candidate
					break
			if not fixture.is_empty():
				break
		_check(not fixture.is_empty(), "genuine seeded %s has a keyword reward" % kind)
		if not fixture.is_empty():
			await _help_in_fixture(fixture, kind)
	# A valid starter offer without keyword does not produce a Help tab.
	requests.clear()
	var no_keyword := _prepared("Fight", 4120, false)
	var found := false
	for offset in range(4120, 4260):
		var test_receipt := _prepared("Fight", offset, false)
		for i in range(3):
			if test_receipt["receipt"]["offers"][i]["id"] == "warden_strike":
				no_keyword = test_receipt
				found = true
				break
		if found:
			break
	_check(found, "genuine starter reward eventually offers no-keyword Strike")
	if found and panel.open_rewards("starter_no_help", "Fight", no_keyword["receipt"]):
		await _frames()
		for i in range(3):
			if no_keyword["receipt"]["offers"][i]["id"] == "warden_strike":
				_check(panel.choices_container.get_child(i).get_node_or_null("HelpButton") == null,
					"real mounted no-keyword Strike has no Help control")
		_check(requests.is_empty(), "no-keyword Help inspection does not request reward")
		panel.close_rewards()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_reward_keyword_help_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	if is_instance_valid(panel):
		panel.free()
	quit(0 if failures.is_empty() else 1)
