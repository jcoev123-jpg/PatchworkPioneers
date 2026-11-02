extends SceneTree
## Real mounted App integration: a paid held card is the only source of a pulse.
## All idle changes are picture-local, with authoritative UI and RNG untouched.

const HUD_IMAGES := {
	"energy": "res://assets/paper/ui/hud_energy.png",
	"draw": "res://assets/paper/ui/hud_draw_pile.png",
	"discard": "res://assets/paper/ui/hud_discard_pile.png",
}
var checks := 0
var failures: Array[String] = []
var app
var presenter
var old_setting: Variant


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)


func _frames() -> void:
	await process_frame
	await process_frame


func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = down
		root.push_input(event, true)
	await _frames()


func _panel(id: String) -> Control:
	for panel in app.hand_view.get_children():
		if panel is PanelContainer and panel.get_child(0) is Label and panel.get_child(0).text == id:
			return panel
	return null


func _snapshot() -> Array:
	return [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.seed,
		app.run_rng.state, app.enemy_intents.get_intents(), app.enemy_attacks.duplicate(true),
		app.pile_label.text, app.intent_label.text]


func _ui_rects() -> Array:
	return [presenter.energy_orb.get_global_rect(), presenter.energy_label.get_global_rect(),
		presenter.draw_token.get_global_rect(), presenter.discard_token.get_global_rect(),
		app.pile_label.get_global_rect(), app.hand_view.get_global_rect(),
		app.end_turn_button.get_global_rect()]


func _structure(stage: String) -> void:
	var orb = presenter.energy_orb
	var draw = presenter.draw_token
	var discard = presenter.discard_token
	_check(is_instance_valid(orb) and is_instance_valid(draw) and is_instance_valid(discard),
		stage + " three mounted visuals")
	if not is_instance_valid(orb) or not is_instance_valid(draw) or not is_instance_valid(discard):
		return
	for name in ["SupportHandEnergyOrb", "SupportHandDrawPile", "SupportHandDiscardPile"]:
		_check(app.find_children(name, "Control", true, false).size() == 1,
			stage + " exactly one " + name)
	_check(orb.get_child_count() == 1 and orb.get_child(0) == presenter.energy_label,
		stage + " one original energy Label")
	for token in [orb, draw, discard]:
		_check(token.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and token.focus_mode == Control.FOCUS_NONE
			and token.gui_input.get_connections().is_empty(),
			stage + " image has no pointer/keyboard receiver")
	_check(draw.get_child_count() == 0 and discard.get_child_count() == 0,
		stage + " pictures own no extra input/label nodes")
	_check(draw.get_index() == app.pile_label.get_index() - 1
		and discard.get_index() == app.pile_label.get_index() + 1,
		stage + " stable pile sibling order")
	_check(app.pile_label.get_parent().find_children("*", "Label", true, false).size() == 1,
		stage + " only one pile count")
	_check(presenter.energy_label.text == "%d" % app.deck.energy
		and app.pile_label.text == "Draw: %d | Discard: %d" % [
			app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		stage + " exact live energy and pile counts")
	_check(orb.texture is Texture2D and orb.art_path() == HUD_IMAGES.energy
		and draw.texture is Texture2D and draw.art_path() == HUD_IMAGES.draw
		and discard.texture is Texture2D and discard.art_path() == HUD_IMAGES.discard,
		stage + " actual three authored textures")
	_check(orb.custom_minimum_size == Vector2(76, 76)
		and draw.custom_minimum_size == Vector2(24, 24)
		and discard.custom_minimum_size == Vector2(24, 24),
		stage + " original Control dimensions")
	_check(orb.disc_rect().encloses(orb.picture_rect())
		and Rect2(Vector2.ZERO, draw.size).encloses(draw.picture_rect())
		and Rect2(Vector2.ZERO, discard.size).encloses(discard.picture_rect()),
		stage + " painted destination rectangles within original bounds")


func _tick(delta: float) -> void:
	presenter.advance_hud_motion(delta)


func _still(before: Array, rects: Array, stage: String) -> void:
	_check(_snapshot() == before, stage + " no combat, pile, run RNG or intent mutation")
	_check(_ui_rects() == rects, stage + " all Control and label rectangles stationary")
	_check(presenter.energy_label.text == "%d" % app.deck.energy,
		stage + " energy Label printed exactly")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
			app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		stage + " counts remain truthful")


func _finish() -> void:
	ProjectSettings.set_setting("accessibility/reduced_motion", old_setting)
	if is_instance_valid(app):
		app.free()
	for failure in failures:
		printerr(failure)
	print("live_battle_hud_motion_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	old_setting = ProjectSettings.get_setting("accessibility/reduced_motion", false)
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	root.size = Vector2i(1280, 720)
	for key in HUD_IMAGES:
		_check(ResourceLoader.exists(HUD_IMAGES[key], "Texture2D")
			and load(HUD_IMAGES[key]) is Texture2D, "real authored art exists: " + key)
	var packed := load("res://scenes/app.tscn") as PackedScene
	_check(packed != null, "real App scene loads")
	if packed == null:
		_finish()
		return
	app = packed.instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveSupportHand")
	_check(app.deck == null, "title has no live motion witness")
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var opening := -1
	for candidate in range(120):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var trial := CombatDeck.new(cards, rng)
		trial.start_turn()
		if trial.hand.has("warden_brace") and trial.hand.has("tinker_tune_up"):
			opening = candidate
			break
	_check(opening >= 0, "nonvacuous paid Brace and free Tune Up opening found")
	if opening < 0:
		_finish()
		return
	app.run_seed = opening
	_check(app._start_battle(), "real battle started through shipped App fixture")
	await _frames()
	var ready: bool = app.deck is CombatDeck and app.party is CombatParty 		and is_instance_valid(app.battle_view) and app.battle_view.is_visible_in_tree() 		and _panel("warden_brace") != null and app.deck.turn_active
	_check(ready, "visible authentic held positive-cost card")
	if not ready:
		_finish()
		return
	_check(app.deck.energy == 3 and app.deck.hand.size() == 5,
		"real active fight starts with three energy and five shared cards")
	_structure("first mount")
	_tick(0.0)
	_check(presenter._hud_pulse_time < 0.0 and presenter.energy_orb.picture_scale == 1.0,
		"first binding cannot create a payment receipt")
	var before := _snapshot()
	var rects := _ui_rects()
	# The two different phases actually move the originals, without moving boxes.
	var draw_start: float = presenter.draw_token.picture_offset_y
	var discard_start: float = presenter.discard_token.picture_offset_y
	_tick(0.45)
	_check(absf(presenter.draw_token.picture_offset_y - draw_start) > 0.05
		and absf(presenter.discard_token.picture_offset_y - discard_start) > 0.05
		and absf(presenter.draw_token.picture_offset_y) <= 1.36
		and absf(presenter.discard_token.picture_offset_y) <= 1.36
		and not is_equal_approx(presenter.draw_token.picture_offset_y, presenter.discard_token.picture_offset_y),
		"two independent ~5s pile phases produce gentle local motion")
	_check(Rect2(Vector2.ZERO, presenter.draw_token.size).encloses(presenter.draw_token.picture_rect())
		and Rect2(Vector2.ZERO, presenter.discard_token.size).encloses(presenter.discard_token.picture_rect()),
		"bobbed pictures never leave their original 24px boxes")
	_still(before, rects, "presentation-only bob")
	seed(987654)
	var expected_global: int = randi()
	seed(987654)
	_tick(1.0)
	_check(randi() == expected_global, "presentation tick never consumes global RNG")
	_still(before, rects, "presentation-only long tick")
	# Real pointer input, not direct service calls: cost and discard must settle first.
	await _click(_panel("warden_brace"))
	_check(app.deck.energy == 2 and app.deck.hand.size() == 4
		and app.deck.discard_pile.count("warden_brace") == 1,
		"real mounted held Brace paid one energy and discarded")
	_check(presenter.energy_label.text == "2", "the original numeric Label prints paid energy")
	var paid_rects := _ui_rects()
	_tick(0.035)
	_check(presenter._hud_pulse_time >= 0.0
		and presenter.energy_orb.picture_scale > 1.0
		and presenter.energy_orb.picture_scale <= 1.06
		and presenter.energy_orb.disc_rect().encloses(presenter.energy_orb.picture_rect()),
		"post-commit witness briefly scales only the inset authored spool")
	_check(_ui_rects() == paid_rects, "image pulse never changes post-commit rectangles")
	before = _snapshot()
	# Replaying stale/original card after payment must fail closed and not restart pulse.
	var stale := _panel("warden_brace")
	if stale != null:
		presenter._activate(stale, "warden_brace", app.deck, app.party, app.battle_view)
	_tick(0.3)
	_still(before, paid_rects, "stale/refused action and elapsed pulse")
	_check(presenter._hud_pulse_time < 0.0 and presenter.energy_orb.picture_scale == 1.0,
		"single paid receipt returns to exact baseline after 0.26s")
	# The same opening has an authentic 0-cost Tune Up. It consumes a held
	# copy and draws one, but never pays energy, so it must not pulse.
	var zero_panel := _panel("tinker_tune_up")
	_check(zero_panel != null, "authentic zero-cost Tune Up remains held")
	if zero_panel != null:
		var free_before: int = app.deck.energy
		await _click(zero_panel)
		_tick(0.035)
		_check(app.deck.energy == free_before
			and app.deck.discard_pile.count("tinker_tune_up") == 1
			and presenter._hud_pulse_time < 0.0
			and presenter.energy_orb.picture_scale == 1.0,
			"real free held card is committed without an energy pulse")
	# A directly changed energy counter, with no committed hand removal, is NOT play.
	var saved_energy: int = app.deck.energy
	app.deck.combat_state.energy = 0
	_tick(0.01)
	_check(presenter._hud_pulse_time < 0.0 and presenter.energy_orb.picture_scale == 1.0,
		"unaffordable energy manipulation has no phantom card receipt")
	app.deck.combat_state.energy = saved_energy
	_tick(0.0)
	# Genuine 0-energy refusal through mounted input.
	var remaining: Control = null
	for panel in app.hand_view.get_children():
		if panel.get_child(0).text == "seamstress_mend":
			remaining = panel
			break
	if remaining != null:
		app.deck.combat_state.energy = 0
		var refused_before := _snapshot()
		await _click(remaining)
		_check(_snapshot() == refused_before and presenter._hud_pulse_time < 0.0,
			"zero-energy held input is rejected with no mutation or pulse")
		app.deck.combat_state.energy = saved_energy
	_tick(0.0)
	# Reduced motion setting and override each freeze all three pictures immediately.
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	_tick(0.03)
	_check(presenter.energy_orb.picture_scale == 1.0
		and presenter.draw_token.picture_offset_y == 0.0
		and presenter.discard_token.picture_offset_y == 0.0
		and presenter._hud_pulse_time < 0.0, "ProjectSettings reduced motion resets everything")
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	presenter.reduced_motion_override = true
	_tick(1.0)
	_check(presenter.draw_token.picture_offset_y == 0.0
		and presenter.discard_token.picture_offset_y == 0.0,
		"explicit reduced-motion override freezes bob")
	presenter.reduced_motion_override = false
	_tick(0.0)
	_check(presenter._hud_motion_enabled and presenter._hud_pulse_time < 0.0,
		"reenabled motion re-arms same-fight baseline without old receipt")
	_tick(0.5)
	_check(absf(presenter.draw_token.picture_offset_y) > 0.05
		and absf(presenter.discard_token.picture_offset_y) > 0.05,
		"reenabled fight has quiet motion again")
	presenter.reduced_motion_override = null
	# Hidden or absent art must always hold the original still picture/fallback.
	app.battle_view.hide()
	_tick(0.05)
	_check(presenter._hud_pulse_time < 0.0
		and presenter.draw_token.picture_offset_y == 0.0
		and presenter.discard_token.picture_offset_y == 0.0, "hidden battle freezes and clears receipt")
	app.battle_view.show()
	_tick(0.0)
	presenter.ui_art_root = "res://assets/paper/ui/missing-hud-test/"
	presenter._sync_battle()
	_tick(0.5)
	_check(presenter.energy_orb.texture == null and presenter.draw_token.texture == null
		and presenter.discard_token.texture == null
		and presenter.energy_orb.picture_scale == 1.0
		and presenter.draw_token.picture_offset_y == 0.0
		and presenter.discard_token.picture_offset_y == 0.0,
		"absent image holds exactly static sewn fallback on the same nodes")
	presenter.ui_art_root = presenter.UI_ART_DIR
	presenter._sync_battle()
	_tick(0.0)
	_structure("restored art")
	var old_orb: Control = presenter.energy_orb
	presenter._clear()
	_check(presenter._hud_pulse_time < 0.0 and presenter._hud_motion_clock == 0.0
		and presenter.energy_orb == null and presenter.draw_token == null,
		"clear removes mounted nodes and retires animation state")
	await _frames()
	presenter._sync_battle()
	_tick(0.0)
	_check(presenter.energy_orb != old_orb and presenter.energy_orb.picture_scale == 1.0
		and presenter._hud_pulse_time < 0.0, "same-fight rebind cannot replay old spend")
	_structure("same-fight rebind")
	# Real next-turn transition replenishes three energy but is not an energy spend.
	app.end_turn_button.pressed.emit()
	await _frames()
	_tick(0.03)
	if app.deck != null and app.deck.turn_active:
		_check(app.deck.energy == 3 and presenter._hud_pulse_time < 0.0
			and presenter.energy_orb.picture_scale == 1.0,
			"actual End Turn/new draw resets baseline, not a pulse")
	else:
		_check(false, "starter encounter survives a real turn to test energy refill")
	# Return really detaches this battle; a new battle gets only its own visual nodes.
	app.return_button.pressed.emit()
	await _frames()
	_check(app.deck == null and presenter.energy_orb == null
		and app.find_children("SupportHandDrawPile", "Control", true, false).is_empty(),
		"real Return clears every animation and token")
	app.run_seed = opening
	_check(app._start_battle(), "fresh fight reopens through real App")
	await _frames()
	_tick(0.0)
	_check(presenter._hud_pulse_time < 0.0 and presenter.energy_orb.picture_scale == 1.0
		and app.deck.energy == 3, "different fight starts baseline, no inherited spend")
	_structure("new fight")
	_finish()
