extends SceneTree
## The shipped reward-choice scene, real victory-prepared Fight/Elite receipts,
## original controls and the shared deterministic authored scraps renderer.
const SCENE := preload("res://scenes/run_card_reward_choice_panel.tscn")
const AMBIENT_SCRIPT := preload("res://scripts/live_battle_ambient.gd")
const HEROES := "res://data/heroes/starter_party.json"
const ENEMIES := "res://data/enemies/starter_enemies.json"

var checks := 0
var failures: Array[String] = []
var requests: Array[Dictionary] = []
var panel: LiveRunCardRewardChoicePanel


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _mouse(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click, true)
	await _frames()


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.pressed = pressed
		root.push_input(key, true)
	await _frames()


func _records(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "authored combat fixture exists: " + path)
	if file == null:
		return []
	var entries: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(entries is Array and not entries.is_empty(), "authored combat records load")
	var records: Array = []
	if entries is Array:
		for record in entries:
			_check(record is Dictionary, "authored hero/enemy record")
			if not record is Dictionary:
				continue
			var copy: Dictionary = record.duplicate(true)
			var hp: Variant = copy.get("max_hp")
			var integral: bool = (hp is int and hp > 0) or (hp is float
				and hp > 0.0 and is_finite(hp) and floorf(hp) == hp)
			_check(integral, "fixture max HP is positive integral")
			if integral:
				copy["max_hp"] = int(hp)
			records.append(copy)
	return records


## No handpicked catalog totals or fabricated reward receipts.
func _prepared(elite: bool, seed_value: int) -> Dictionary:
	var party := CombatParty.new(_records(HEROES))
	var enemies := CombatEnemies.new(_records(ENEMIES))
	_check(party.is_valid() and enemies.is_valid(), "real authored combat rosters")
	var result := CombatBattleResult.new(party, enemies)
	for slot in range(1, enemies.get_enemies().size() + 1):
		_check(enemies.apply_damage(slot, enemies.get_enemy(slot).get("hp", 0)),
			"victory fixture defeats an existing enemy")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "real victory witnessed")
	var catalog := StarterCards.new()
	var deck: Array[String] = catalog.get_starting_deck()
	var owned: Array[String] = ["button_charm"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var owners: Array[String] = ["warden", "seamstress", "tinker"]
	var trinket_pool: Array[String] = ["button_charm", "thread_token"]
	var service := RunFightVictoryRewards.new(result, rng,
		owners, catalog.get_all_card_ids(), deck,
		97, elite, trinket_pool, owned)
	var receipt: Dictionary = service.prepare()
	var offers: Array = receipt.get("offers", [])
	var ids := {}
	for offer in offers:
		ids[String(offer.get("id", ""))] = true
	_check(receipt.get("ok") == true and offers.size() == 3 and ids.size() == 3,
		"real prepared receipt has three distinct eligible cards")
	_check(receipt.get("gold_award", -1) >= (25 if elite else 10)
		and receipt.get("gold_award", 100) <= (35 if elite else 20)
		and receipt.get("trinket_drop_id", "?") == ("thread_token" if elite else ""),
		"real Fight/Elite gold and patch receipt")
	return {"receipt": receipt, "party": party, "enemies": enemies,
		"battle": result, "rng": rng, "deck": deck, "owned": owned, "service": service}


func _state(fixture: Dictionary) -> Dictionary:
	return {"seed": fixture["rng"].seed, "rng": fixture["rng"].state,
		"deck": fixture["deck"].duplicate(true), "owned": fixture["owned"].duplicate(true),
		"party": fixture["party"].get_heroes(), "enemies": fixture["enemies"].get_enemies(),
		"outcome": fixture["battle"].get_outcome(),
		"claimed": fixture["service"]._choice.is_claimed(),
		"receipt": fixture["service"].prepare()}


func _layer() -> Control:
	return panel.get_node_or_null("PaperPanel/RewardAmbient") as Control


func _assert_retired(ambient: Control, stage: String) -> void:
	_check(not ambient.visible and not ambient.is_processing()
		and String(ambient.get("profile")).is_empty()
		and is_zero_approx(float(ambient.get("_time"))), stage + ": renderer retired")


func _check_controls(buttons: Array[Button], rects: Array[Rect2],
		labels: Array[String], enabled: Array[bool], stage: String) -> void:
	var current := panel.get_choice_buttons()
	_check(current.size() == 4 and buttons.size() == 4,
		stage + ": original 3 Choose + Skip objects retained")
	if current.size() != 4:
		return
	for i in range(4):
		_check(current[i] == buttons[i] and current[i].get_global_rect() == rects[i]
			and current[i].text == labels[i] and current[i].disabled == enabled[i],
			stage + ": action identity/position/text/enabled unchanged " + str(i))
		_check(current[i].focus_mode == Control.FOCUS_ALL,
			stage + ": original keyboard focus eligibility " + str(i))


func _visit(fixture: Dictionary, kind: String) -> void:
	var node_id := "ambient_" + kind
	var ambient := _layer()
	var before := _state(fixture)
	requests.clear()
	_check(panel.open_rewards(node_id, kind, fixture["receipt"]),
		kind + ": real receipt admitted on shipped scene")
	await _frames()
	var actions := panel.get_choice_buttons()
	_check(actions.size() == 4 and panel.choices_container.get_child_count() == 3,
		kind + ": original visible three cards and Skip")
	if actions.size() != 4:
		panel.close_rewards()
		return
	var rects: Array[Rect2] = []
	var labels: Array[String] = []
	var enabled: Array[bool] = []
	for button in actions:
		rects.append(button.get_global_rect())
		labels.append(button.text)
		enabled.append(button.disabled)
	_check(ambient.visible and ambient.is_visible_in_tree()
		and ambient.is_processing() and String(ambient.get("profile")) == "scraps"
		and bool(ambient.get("fast")) and bool(ambient.get("_visit_dressing"))
		and ambient.call("visible_budget") == 7,
		kind + ": one live seven-motif scraps visit renderer")
	_check(ambient.modulate.a == 1.0 and ambient.self_modulate.a <= 0.42,
		kind + ": renderer uses low authored alpha")
	_check(ambient.size.x > 40.0 and ambient.size.y > 40.0,
		kind + ": mounted renderer covers readable quilt")
	var first: Array = ambient.call("motif_metadata")
	_check(first.size() == 7, kind + ": seven physically placed felt motes")
	ambient.call("_process", 6.25)
	var second: Array = ambient.call("motif_metadata")
	_check(second.size() == 7 and first != second
		and float(ambient.get("_time")) >= 6.25,
		kind + ": two fixed phases produce different deterministic placements")
	var added: Array = ambient.call("added_metadata")
	_check(not added.is_empty(), kind + ": fluff/wisp/vignette authored mark metadata")
	_check_controls(actions, rects, labels, enabled, kind + " after drift")
	_check(panel._receipt == fixture["receipt"] and _state(fixture) == before
		and requests.is_empty(), kind + ": ambient did not alter receipt/gameplay/RNG")
	# Scene controls, rather than a synthetic callback, must still receive mouse.
	await _mouse(actions[0])
	_check(requests == [{"node": node_id, "card": fixture["receipt"]["offers"][0]["id"]}]
		and panel._awaiting_ack, kind + ": real mouse Choose emits exactly once")
	_assert_retired(ambient, kind + " awaiting ACK")
	ambient.call("_process", 12.0)
	_check(requests.size() == 1 and _state(fixture) == before,
		kind + ": inactive ambience cannot settle or duplicate a choice")
	panel.acknowledge(false)
	_check(not panel._awaiting_ack and not panel._accepted
		and ambient.visible and is_zero_approx(float(ambient.get("_time"))),
		kind + ": rejected ACK restores same offer and restarts neutral ambience")
	_check_controls(actions, rects, labels, enabled, kind + " after rejection")
	# An accepted action latches but leaves all settlement to the caller.
	await _mouse(actions[3])
	_check(requests.size() == 2 and requests[1] == {"node": node_id, "card": ""},
		kind + ": physical Skip emits exactly once with empty card ID")
	panel.acknowledge(true)
	_assert_retired(ambient, kind + " accepted")
	_check(_state(fixture) == before, kind + ": accept/Skip remains presentation only")
	panel.close_rewards()
	_assert_retired(ambient, kind + " closed")
	_check(not panel.has_open_rewards() and not panel.visible, kind + ": closed panel")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	panel = SCENE.instantiate() as LiveRunCardRewardChoicePanel
	_check(panel != null, "actual shipped reward panel script")
	if panel == null:
		_finish()
		return
	root.add_child(panel)
	panel.choice_requested.connect(func(n: String, c: String) -> void:
		requests.append({"node": n, "card": c}))
	await _frames()
	var ambient := _layer()
	_check(ambient != null, "actual scene mounts one ambient inside PaperPanel")
	if ambient == null:
		_finish()
		return
	var occurrences := 0
	for child in panel.paper_panel.get_children():
		if child.get_script() == AMBIENT_SCRIPT:
			occurrences += 1
	_check(occurrences == 1 and panel.paper_panel.get_child(0) == ambient
		and panel.paper_panel.get_child(1) == panel.get_node("PaperPanel/ContentMargin"),
		"one renderer after opaque quilt but before existing text/cards/actions")
	_check(ambient.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and ambient.focus_mode == Control.FOCUS_NONE,
		"renderer has no mouse or keyboard target")
	for entry in [["felt_texture", AMBIENT_SCRIPT.FELT_PATH],
			["fluff_texture", AMBIENT_SCRIPT.FLUFF_PATH],
			["wisp_texture", AMBIENT_SCRIPT.WISP_PATH],
			["light_texture", AMBIENT_SCRIPT.LIGHT_PATH]]:
		var expected_path: String = entry[1]
		var texture := ambient.get(entry[0]) as Texture2D
		_check(not ResourceLoader.exists(expected_path) or (texture != null
			and texture.resource_path == expected_path),
			"renderer loads existing image if installed: " + expected_path)
	_assert_retired(ambient, "initial")
	var fight := _prepared(false, 18203)
	var elite := _prepared(true, 18203)
	if not fight["receipt"].get("ok") or not elite["receipt"].get("ok"):
		_finish()
		return
	var invalid: Dictionary = fight["receipt"].duplicate(true)
	invalid["offers"][1]["id"] = invalid["offers"][0]["id"]
	_check(not panel.open_rewards("invalid", "Fight", invalid),
		"invalid duplicate receipt fails closed")
	_assert_retired(ambient, "invalid open")
	panel.set_reduced_motion_override(false)
	var original_global: Variant = ProjectSettings.get_setting(panel.REDUCED_MOTION_SETTING, false)
	ProjectSettings.set_setting(panel.REDUCED_MOTION_SETTING, false)
	await _visit(fight, "Fight")
	await _visit(elite, "Elite")
	_check(panel.open_rewards("hide", "Fight", fight["receipt"]), "hide fixture opens")
	await _frames()
	ambient.call("_process", 7.0)
	panel.hide()
	_assert_retired(ambient, "hidden while open")
	panel.show()
	_check(ambient.visible and is_zero_approx(float(ambient.get("_time"))),
		"show reuses existing renderer at zero")
	panel.close_rewards()
	ProjectSettings.set_setting(panel.REDUCED_MOTION_SETTING, true)
	_check(panel.open_rewards("global", "Elite", elite["receipt"]),
		"reduced motion does not block Elite choices")
	await _frames()
	ambient.call("_process", 8.0)
	_check(not ambient.is_processing() and is_zero_approx(float(ambient.get("_time")))
		and panel.get_choice_buttons().size() == 4 and not panel.is_processing(),
		"global reduced motion pauses neutral and keeps all buttons")
	panel.set_reduced_motion_override(false)
	ambient.call("_process", 8.0)
	_check(not ambient.is_processing() and is_zero_approx(float(ambient.get("_time"))),
		"false panel override cannot bypass true global preference")
	panel.set_reduced_motion_override(true)
	_assert_retired(ambient, "panel override true")
	panel.set_reduced_motion_override(null)
	_check(ambient.visible and not ambient.is_processing()
		and is_zero_approx(float(ambient.get("_time"))),
		"clearing local override restores globally paused neutral marks")
	ProjectSettings.set_setting(panel.REDUCED_MOTION_SETTING, false)
	await _frames()
	_check(ambient.is_processing(), "global preference off resumes authored ambience")
	# No PNG changes: remove an optional in-memory reference, confirm fallback works.
	var old_fluff: Variant = ambient.get("fluff_texture")
	ambient.set("fluff_texture", null)
	ambient.queue_redraw()
	await _frames()
	_check(panel.get_choice_buttons().size() == 4 and panel.gold_label.text.begins_with("Pending gold:")
		and panel.trinket_label.visible and ambient.get("fluff_texture") == null,
		"missing optional fluff art leaves cream cards and Elite patch receipt functional")
	ambient.set("fluff_texture", old_fluff)
	panel.close_rewards()
	# Physical keyboard choice still uses same binding and ACK timing.
	requests.clear()
	_check(panel.open_rewards("keyboard", "Fight", fight["receipt"]), "keyboard fixture opens")
	await _frames()
	await _key(KEY_1)
	_check(requests == [{"node": "keyboard", "card": fight["receipt"]["offers"][0]["id"]}]
		and panel._awaiting_ack, "real keyboard shortcut selects original first offer")
	panel.acknowledge(true)
	_assert_retired(ambient, "keyboard accepted")
	panel.close_rewards()
	ProjectSettings.set_setting(panel.REDUCED_MOTION_SETTING, original_global)
	panel.set_reduced_motion_override(null)
	var spare := SCENE.instantiate() as LiveRunCardRewardChoicePanel
	root.add_child(spare)
	await _frames()
	_check(spare.open_rewards("exit", "Fight", fight["receipt"]), "exit fixture opens")
	var departing := spare.get_node("PaperPanel/RewardAmbient") as Control
	_check(departing.is_processing() == not bool(original_global), "exit fixture owns active/paused renderer")
	spare.free()
	_check(not is_instance_valid(spare), "exit frees single renderer with panel")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("PASS live_reward_ambient_motion_test (%d checks)" % checks)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
		print("FAIL live_reward_ambient_motion_test (%d/%d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
