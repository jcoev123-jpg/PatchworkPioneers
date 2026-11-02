extends SceneTree
## Art-only movement on the real Fight/Elite reward scene; no sleep-based animation.
const SCENE := "res://scenes/run_card_reward_choice_panel.tscn"
const HEROES := "res://data/heroes/starter_party.json"
const ENEMIES := "res://data/enemies/starter_enemies.json"

var panel: LiveRunCardRewardChoicePanel
var failures: Array[String] = []
var checks := 0
var requests: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, reason: String) -> void:
	checks += 1
	if not condition:
		failures.append(reason)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _records(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "read genuine roster: " + path)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Array and not parsed.is_empty(), "parse roster: " + path)
	if not parsed is Array:
		return []
	var definitions: Array = []
	for raw in parsed:
		if not raw is Dictionary:
			continue
		var row: Dictionary = raw.duplicate(true)
		var hp: Variant = row.get("max_hp")
		if hp is float and is_finite(hp) and floorf(hp) == hp:
			row["max_hp"] = int(hp)
		definitions.append(row)
	return definitions


func _receipt(elite: bool) -> Dictionary:
	# Same witnessed-victory source that the real app prepares.
	var party := CombatParty.new(_records(HEROES))
	var enemies := CombatEnemies.new(_records(ENEMIES))
	_check(party.is_valid() and enemies.is_valid(), "valid authored combatants")
	var result := CombatBattleResult.new(party, enemies)
	for slot in range(1, enemies.get_enemies().size() + 1):
		_check(enemies.apply_damage(slot, enemies.get_enemy(slot).get("hp", 0)),
			"enemy defeated for witnessed reward")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "witnessed victory")
	var cards := StarterCards.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31988 if elite else 31987
	var service := RunFightVictoryRewards.new(result, rng,
		["warden", "seamstress", "tinker"], cards.get_all_card_ids(),
		cards.get_starting_deck(), 97, elite, ["button_charm", "thread_token"],
		["button_charm"])
	var receipt := service.prepare()
	_check(receipt.get("ok") == true and receipt.get("offers", []).size() == 3,
		"real prepared three-offer reward")
	_check(receipt.get("gold_award", 0) >= (25 if elite else 10)
		and receipt.get("gold_award", 0) <= (35 if elite else 20)
		and (not elite or receipt.get("trinket_drop_id") == "thread_token"),
		"Fight/Elite authorized award and patch")
	return {"prepared": receipt, "rng": rng, "service": service,
		"party": party, "enemies": enemies}


func _art(index: int) -> LiveRunCardRewardChoicePanel._CardIllustration:
	if index < 0 or index >= panel._card_panels.size():
		return null
	return panel._card_panels[index].get_node_or_null(
		"CardMargin/CardContent/CardArt") as LiveRunCardRewardChoicePanel._CardIllustration


func _inject_images() -> void:
	var image := Image.create(32, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color("#786a62"))
	var texture := ImageTexture.create_from_image(image)
	for index in range(3):
		var art := _art(index)
		_check(art != null, "each real card includes an illustration window")
		if art == null:
			continue
		art.picture = texture
		art.mode = art.MODE_CARD_ART
		art.queue_redraw()
	panel._sync_motion_processing()


func _geometry() -> Array:
	var result: Array = []
	for card in panel._card_panels:
		var content := card.get_node("CardMargin/CardContent")
		for node in [card, content.get_node("CardArt"),
				content.get_node("CardHeader/OwnerPatch/OwnerLabel"),
				content.get_node("CardHeader/HelpButton"),
				content.get_node("NameLabel"),
				content.get_node("MetadataRow/CostButton"),
				content.get_node("MetadataRow/PositionPips"),
				content.get_node("MetadataRow/RarityLabel"),
				content.get_node("EffectsScroll/RulesLabel"),
				content.get_node("ChooseButton")]:
			result.append({"node": node, "rect": node.get_global_rect(),
				"position": node.position, "rotation": node.rotation,
				"scale": node.scale})
	for node in [panel.skip_button, panel.paper_panel, panel.gold_label, panel.trinket_label]:
		result.append({"node": node, "rect": node.get_global_rect(),
			"position": node.position, "rotation": node.rotation,
			"scale": node.scale})
	return result


func _unchanged(before: Array, label: String) -> void:
	for entry in before:
		var node: Control = entry["node"]
		_check(is_instance_valid(node) and node.get_global_rect() == entry["rect"]
			and node.position == entry["position"] and node.rotation == entry["rotation"]
			and node.scale == entry["scale"],
			label + " fixed control " + node.name)


func _neutral(label: String) -> void:
	_check(panel._card_elapsed == 0.0, label + " presentation clock reset")
	for i in range(3):
		var art := _art(i)
		_check(art != null and art.picture_offset == Vector2.ZERO
			and art.picture_degrees == 0.0 and panel._card_lifts[i] == 0.0,
			label + " all card images reset to neutral " + str(i))


func _on_request(node_id: String, card_id: String) -> void:
	requests.append({"node": node_id, "card": card_id})


func _exercise(fixture: Dictionary, kind: String) -> void:
	var receipt: Dictionary = fixture["prepared"]
	var pristine := receipt.duplicate(true)
	var rng_state: int = fixture["rng"].state
	var node_id := "card_motion_" + kind
	requests.clear()
	_check(panel.open_rewards(node_id, kind, receipt), kind + " mounted opens")
	_check(panel._card_panels.size() == 3 and panel.get_choice_buttons().size() == 4,
		kind + " real three offers, three Choose and Skip")
	if panel._card_panels.size() != 3:
		return
	await _frames()
	_inject_images()
	panel.get_choice_buttons()[0].release_focus()
	panel._on_card_mouse_exited(0)
	panel._on_card_focus_exited(0)
	panel._reset_card_motion()
	_neutral(kind + " initial")
	var bounds := _geometry()
	_check(_art(0).clip_contents and _art(0).mouse_filter == Control.MOUSE_FILTER_IGNORE
		and _art(0).focus_mode == Control.FOCUS_NONE,
		"clipped CardArt never captures pointer or keyboard")
	_check(panel._card_panels[0].get_node("CardMargin/CardContent/CardHeader/HelpButton").text
		== "Details" and panel.get_choice_buttons()[0].text.contains("Choose")
		and panel.skip_button.text.contains("Skip"),
		"Details/Choose/Skip still mounted with readable names")
	panel._process(0.8)
	var samples: Array[Vector2] = []
	for i in range(3):
		var art := _art(i)
		samples.append(art.picture_offset)
		_check(absf(art.picture_offset.y) <= 2.0001
			and absf(art.picture_degrees) <= 1.0001,
			kind + " idle drift and tilt bound " + str(i))
	_check(not samples[0].is_equal_approx(samples[1])
		and not samples[1].is_equal_approx(samples[2]),
		kind + " staggered card phases differ")
	_unchanged(bounds, kind + " idle")
	# Real card pointer-entered handler versus keyboard focus on the next Choose.
	panel._card_panels[0].mouse_entered.emit()
	panel._process(0.5)
	_check(panel._card_lifts[0] > 0.0 and panel._card_lifts[0] <= 4.0
		and panel._card_lifts[1] == 0.0,
		kind + " pointer hover lifts only its painted image")
	panel._card_panels[0].mouse_exited.emit()
	panel._process(0.5)
	_check(panel._card_lifts[0] == 0.0, kind + " pointer exit settles")
	panel.get_choice_buttons()[1].grab_focus()
	await _frames()
	panel._process(0.5)
	_check(panel._card_focused[1] and panel._card_lifts[1] > 0.0
		and panel._card_lifts[1] <= 4.0,
		kind + " keyboard focus lifts only the second illustration")
	panel.get_choice_buttons()[1].release_focus()
	panel._process(0.5)
	_check(panel._card_lifts[1] == 0.0, kind + " keyboard exit settles")
	_unchanged(bounds, kind + " pointer and keyboard")
	for i in range(3):
		_check(absf(_art(i).picture_offset.y) <= 6.0001
			and absf(_art(i).picture_degrees) <= 1.0001,
			kind + " focused image total movement is bounded")
	# Missing image and emblem: existing drawn, completely static patch.
	var absent := _art(2)
	absent.picture = null
	absent.mode = absent.MODE_NONE
	panel._process(0.65)
	_check(absent.is_paper_patch() and absent.picture_offset == Vector2.ZERO
		and absent.picture_degrees == 0.0, kind + " no image remains paper fallback")
	# Hidden clocks must not run and must not accumulate a future jump.
	panel.hide()
	_neutral(kind + " hidden")
	panel._process(6.0)
	_neutral(kind + " hidden advance")
	panel.show()
	_neutral(kind + " revealed")
	panel._process(0.3)
	_check(panel._card_elapsed > 0.0 and _art(0).picture_offset != Vector2.ZERO,
		kind + " visibility restores only fresh presentation time")
	_unchanged(bounds, kind + " after hide/show")
	var chosen := 1 if kind == "Elite" else 0
	var selected_id := String(receipt["offers"][chosen]["id"])
	panel.get_choice_buttons()[chosen].pressed.emit()
	_check(requests.size() == 1 and requests[0] == {"node": node_id, "card": selected_id},
		kind + " emits one original prepared node/card request")
	_neutral(kind + " pending acknowledgement")
	panel._process(4.0)
	_neutral(kind + " pending frame")
	panel.get_choice_buttons()[chosen].pressed.emit()
	panel.get_choice_buttons()[3].pressed.emit()
	_check(requests.size() == 1, kind + " duplicate and pending Skip rejected")
	panel.acknowledge(false)
	_check(not panel._awaiting_ack and not panel._accepted,
		kind + " rejected acknowledgement re-enables receipt")
	panel._process(0.25)
	_check(panel._card_elapsed > 0.0, kind + " rejection resumes a fresh clock")
	panel.get_choice_buttons()[chosen].pressed.emit()
	_check(requests.size() == 2 and requests[1] == requests[0],
		kind + " original receipt can retry once after rejection")
	panel.acknowledge(true)
	_neutral(kind + " accepted")
	panel._process(3.0)
	_neutral(kind + " accepted frame")
	panel.get_choice_buttons()[chosen].pressed.emit()
	_check(requests.size() == 2, kind + " accepted reward cannot be replayed")
	var old_generation: int = panel._generation
	var old_button := panel.get_choice_buttons()[chosen]
	panel.close_rewards()
	_check(not panel.is_processing() and panel._card_elapsed == 0.0,
		kind + " close stops all presentation")
	_check(panel.open_rewards(node_id + "_new", kind, receipt),
		kind + " new legitimate reward opens cleanly")
	_neutral(kind + " reopen before first tick")
	panel._on_choice_pressed(old_generation, node_id, selected_id, old_button)
	_check(requests.size() == 2, kind + " stale old-generation callback rejected")
	panel.close_rewards()
	_check(receipt == pristine and fixture["rng"].state == rng_state
		and not fixture["service"]._choice.is_claimed(),
		kind + " view never mutates receipt, RNG or settlement")
	_unchanged([], "no-op")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var saved: Variant = ProjectSettings.get_setting(
		"accessibility/reduced_motion", false)
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	var packed := load(SCENE) as PackedScene
	_check(packed != null, "real reward scene resource loads")
	if packed == null:
		_finish(saved)
		return
	panel = packed.instantiate() as LiveRunCardRewardChoicePanel
	_check(panel != null, "live reward script mounted")
	if panel == null:
		_finish(saved)
		return
	root.add_child(panel)
	panel.choice_requested.connect(_on_request)
	await _frames()
	var fight := _receipt(false)
	var elite := _receipt(true)
	if not fight["prepared"].get("ok", false) or not elite["prepared"].get("ok", false):
		_finish(saved)
		return
	for kind in ["Fight", "Elite"]:
		await _exercise(elite if kind == "Elite" else fight, kind)
	# Both reduction paths must prevent motion even with actual loaded art.
	for mode in ["project", "override"]:
		ProjectSettings.set_setting("accessibility/reduced_motion", mode == "project")
		panel.set_reduced_motion_override(true if mode == "override" else null)
		_check(panel.open_rewards("reduced_" + mode, "Fight", fight["prepared"]),
			mode + " opens legitimate reduced-motion offer")
		_inject_images()
		panel._sync_camp_motion()
		panel._process(2.5)
		_neutral(mode + " never animates")
		_check(not panel.is_processing(), mode + " disables all animation loops")
		panel.close_rewards()
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	panel.set_reduced_motion_override(false)
	_check(panel.open_rewards("teardown", "Elite", elite["prepared"]),
		"teardown mounts actual Elite reward")
	_inject_images()
	panel._process(0.5)
	_check(panel._card_elapsed > 0.0, "teardown starts actual art motion")
	panel.free()
	_check(not is_instance_valid(panel), "free releases live presentation loop")
	_finish(saved)


func _finish(saved: Variant) -> void:
	ProjectSettings.set_setting("accessibility/reduced_motion", saved)
	for message in failures:
		printerr(message)
	print("live_reward_card_motion_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
