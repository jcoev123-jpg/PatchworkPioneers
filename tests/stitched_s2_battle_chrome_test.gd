extends SceneTree
## S2 mounted chrome contract: real preview data, real buttons and authoritative state.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, note: String) -> void:
	checks += 1
	if not condition:
		failures.append(note)


func _mount() -> Dictionary:
	var host := Control.new()
	host.name = "SewnBattleChromeHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var screen := StitchedBattleScreen.new()
	var data := StitchedBattleScreen.read_preview()
	_check(int(data.get("seed", -1)) == 4952026 and int(data.get("candle", -1)) == 78
		and data.get("heroes", []).size() == 4 and data.get("foes", []).size() == 3,
		"precondition: unmodified 4952026 Stitched four-hero/three-foe preview")
	_check(screen.begin(data), "precondition: mounted S2 screen uses real validated rules")
	host.add_child(screen)
	return {"host": host, "screen": screen}


func _no_mutation(screen: StitchedBattleScreen, state: Dictionary, rng: int, count: int, note: String) -> void:
	_check(screen.battle.state_snapshot() == state and screen.battle.rng_state() == rng
		and screen.receipts.size() == count, note)


func _verify_readout(label: Label, note: String) -> void:
	var font: Font = label.get_theme_font("font")
	var point_size := label.get_theme_font_size("font_size")
	_check(font is FontVariation and (font as FontVariation).base_font == StitchedBattleChrome.RANK_FONT and label.has_theme_font_override("font")
		and point_size >= 15 and label.size.y == 16.0 and label.scale.y == 1.0
		and not label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING,
		note + " has locally bound real 15px-or-larger lettering, no clipping or vertical shrink")
	if font != null:
		var measured := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size)
		_check(measured.x * label.scale.x <= label.size.x - 1.0
			and measured.y >= 15.0 and measured.y <= 16.0
			and label.get_global_rect().size.y == 16.0,
			note + " measured font fits the sixteen-pixel global caption band")


func _fray_full(value: int) -> String:
	return ("FRAY %d/200" % value
		+ " | 100 FRAY: resolve threshold (STEADFAST or UNRAVELLED)."
		+ " | 200 FRAY: COMES APART (HANGING, or LOST if already HANGING).")


func _verify_styles(screen: StitchedBattleScreen) -> void:
	var fabric: Texture2D = load("res://assets/paper/ui/panel_felt.png")
	var button_art: Texture2D = load("res://assets/paper/ui/reward_button.png")
	var tray := screen.get_node_or_null("StitchedActionTray") as NinePatchRect
	_check(tray != null and tray.texture == fabric
		and tray.get_global_rect() == Rect2(12, 557, 1256, 155)
		and screen._candle_meter != null and screen._turn_ribbon != null,
		"authored nine-slice tray remains under controls and below full stage")
	var buttons: Array[BaseButton] = []
	for group in [screen._part_buttons, screen._part_help_buttons,
			screen._target_buttons, screen._action_buttons, screen._seat_buttons]:
		for button in group.values():
			buttons.append(button)
	_check(buttons.size() >= 29 and screen._part_buttons.size() == 4
		and screen._target_buttons.size() == 8 and screen._seat_buttons.size() == 8,
		"precondition: all part/help/target/action/seat controls exist")
	var states := ["normal", "hover", "pressed", "disabled", "focus"]
	for button in buttons:
		var sewn := true
		# The 170px footplate deliberately uses the existing darker authored
		# name image; action/target chrome keeps its original reward-button art.
		var expected_art := StitchedBattleChrome.NAME_PLATE if button.name.begins_with("RankPlate") else button_art
		for state in states:
			var style := button.get_theme_stylebox(state)
			if not style is StyleBoxTexture or style.texture != expected_art:
				sewn = false
		_check(sewn and button.focus_mode == Control.FOCUS_ALL and button.text != "",
			"%s has authored all-state button chrome, identity and keyboard focus" % button.name)
	_check(screen._target_buttons["foe_4"].disabled and
		screen._action_buttons["re_tie"].disabled,
		"empty foe target and unavailable Re-tie retain fail-closed disabled state")
	var pass_button: Button = screen._action_buttons["pass"]
	pass_button.grab_focus()
	_check(pass_button.has_focus() and pass_button.get_theme_stylebox("focus") is StyleBoxTexture,
		"keyboard focus really enters stitched turn-action button")
	pass_button.release_focus()


func _verify_action_icons(screen: StitchedBattleScreen) -> void:
	var keys := ["move_front", "move_back", "re_tie", "pass", "retreat"]
	var names := ["Move front", "Move back", "Re-tie", "Pass turn", "Retreat"]
	var art := ["move", "move", "retie", "pass", "retreat"]
	# The larger native hit bands reserve separate icon and readable text columns.
	var expected := [
		Rect2(260, 642, 150, 32), Rect2(418, 642, 150, 32),
		Rect2(576, 642, 126, 32), Rect2(710, 642, 142, 32),
		Rect2(860, 642, 151, 32),
	]
	var preview: Rect2 = screen._labels["preview"].get_global_rect()
	var figure: Rect2 = screen.get_node("SharedStitchedBackdrop").get_global_rect()
	var references: Array[Rect2] = []
	for control in screen._target_buttons.values():
		references.append(control.get_global_rect())
	for index in range(keys.size()):
		var key: String = keys[index]
		var button: Button = screen._action_buttons[key]
		var path: String = "res://assets/paper/stitched/icons/action_" + art[index] + ".png"
		var icon: Texture2D = load(path)
		var emblem: TextureRect = button.get_node_or_null("ActionEmblem") as TextureRect
		var rect := button.get_global_rect()
		_check(icon != null and icon.get_size() == Vector2(128, 128)
			and emblem != null and emblem.texture == icon
			and emblem.size == Vector2(19, 19) and emblem.position == Vector2(9, 6)
			and emblem.expand_mode == TextureRect.EXPAND_IGNORE_SIZE
			and emblem.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			and emblem.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and emblem.focus_mode == Control.FOCUS_NONE
			and button.focus_mode == Control.FOCUS_ALL and button.text == names[index]
			and button.get_theme_font_size("font_size") >= 16,
			"%s mounts the 128px authored art in a non-interactive 19px button emblem" % key)
		_check(rect == expected[index] and not rect.intersects(preview)
			and not rect.intersects(figure) and rect.position.y >= 642
			and rect.end.y < 679 and Rect2(0, 0, 1280, 720).encloses(rect),
			"%s has its larger mouse rectangle clear of stage, forecast and targets" % key)
		for other in references:
			_check(not rect.intersects(other), "%s cannot overlap any prior action or target" % key)
		references.append(rect)
		var font: Font = button.get_theme_font("font")
		_check(font != null and font.get_string_size(button.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x < rect.size.x - 40.0,
			"%s has room for the authored emblem beside its unclipped readable text" % key)
	var state := screen.battle.state_snapshot()
	var rng := screen.battle.rng_state()
	var receipts := screen.receipts.size()
	for key in keys:
		var button: Button = screen._action_buttons[key]
		screen._action_buttons["pass"].release_focus()
		button.mouse_entered.emit()
		_check(screen._labels["preview"].text.contains(button.text)
			or screen._labels["preview"].tooltip_text.contains(button.text),
			"%s exposes a real hover description in the sewn forecast row" % key)
		button.mouse_exited.emit()
		if not button.disabled:
			button.grab_focus()
			_check(button.has_focus() and screen._labels["preview"].tooltip_text != "",
				"%s keyboard focus reveals full action availability without activation" % key)
			button.release_focus()
	_no_mutation(screen, state, rng, receipts,
		"action icon hover, keyboard focus and tooltip never consume RNG or combat state")


func _verify_meters(screen: StitchedBattleScreen) -> void:
	var heroes: Array = screen.battle.get_heroes()
	var foes: Array = screen.battle.get_foes()
	_check(heroes.size() == 4 and foes.size() == 3,
		"precondition: occupied meter assertions observe four heroes and three foes")
	for side in ["hero", "foe"]:
		var actors: Array = heroes if side == "hero" else foes
		for rank in range(1, 5):
			var key: String = str(side) + "_" + str(rank)
			var expected: Dictionary = {}
			for actor in actors:
				if int(actor["rank"]) == rank and not bool(actor.get("lost", false)) and not bool(actor.get("dead", false)) and (side == "hero" or int(actor["hp"]) > 0):
					expected = actor
					break
			var meters: Dictionary = screen._rank_meters[key]
			var surface: Control = meters["root"]
			var hp: ProgressBar = meters["hp"]
			var present := not expected.is_empty()
			var hp_frame: NinePatchRect = surface.get_node("HPFillSewnFrame")
			var hp_style := hp.get_theme_stylebox("fill") as StyleBoxTexture
			var hp_text: Label = meters["hp_text"]
			_check(surface.visible == present and hp is ProgressBar and
				hp_frame is NinePatchRect and hp_frame.texture == load("res://assets/paper/ui/hud_bar_frame.png") and
				hp_style != null and hp_style.texture == load("res://assets/paper/ui/reward_button.png") and
				not screen._labels[key].visible and
				(screen._labels[key].text.is_empty() or not present),
				"%s rank %d has only its occupied authored-framed meter, not painted duplicate text" % [side, rank])
			if not present:
				continue
			var foot: NinePatchRect = screen._foot_plates[key]
			var name: Button = screen._seat_buttons[key]
			_verify_readout(hp_text, "%s rank %d HP" % [side, rank])
			_check(hp.value == float(expected["hp"]) and
				hp.max_value == float(expected["max_hp"]) and
				hp.tooltip_text.contains("%d/%d" % [int(expected["hp"]), int(expected["max_hp"])]) and
				hp_text.text == ("HP %d" % int(expected["hp"]) if side == "hero" else "HP %d/%d" % [int(expected["hp"]), int(expected["max_hp"])]) and
				hp_text.get_theme_color("font_color") == StitchedBattleChrome.BONE and
				foot.get_global_rect().encloses(surface.get_global_rect()) and
				not name.get_global_rect().intersects(surface.get_global_rect()) and
				not hp_text.get_global_rect().intersects(hp_frame.get_global_rect()) and
				not hp_text.get_global_rect().intersects(hp.get_global_rect()) and
				hp.get_global_rect().size.y >= 6.0,
				"%s rank %d HP fill, bone readout and frame fit distinct plate bands" % [side, rank])
			if side == "hero":
				var fray: ProgressBar = meters["fray"]
				var fray_frame: NinePatchRect = surface.get_node("FrayFillSewnFrame")
				var fray_caption: Label = meters["fray_text"]
				var fray_style := fray.get_theme_stylebox("fill") as StyleBoxTexture
				_verify_readout(fray_caption, "hero rank %d FRAY" % rank)
				_check(fray.max_value == 200.0 and fray.value == float(expected["fray"])
					and fray_caption.text == "FRAY %d" % int(expected["fray"])
					and fray.tooltip_text == _fray_full(int(expected["fray"]))
					and meters["root"].tooltip_text.contains(_fray_full(int(expected["fray"])))
					and fray_frame.texture == load("res://assets/paper/ui/hud_bar_frame.png")
					and fray_style != null and fray_style.texture == load("res://assets/paper/ui/reward_button.png")
					and not fray_caption.get_global_rect().intersects(fray_frame.get_global_rect())
					and not fray_caption.get_global_rect().intersects(hp_text.get_global_rect())
					and foot.get_global_rect().encloses(fray_frame.get_global_rect()),
					"hero rank %d exact FRAY fill/caption and stitched frame stay in separate bands" % rank)


func _test_hanging_and_lost(screen: StitchedBattleScreen) -> void:
	var hero: Dictionary = screen.battle.get_heroes()[0]
	var id := str(hero["id"])
	var original: Dictionary = screen.battle._units[id].duplicate(true)
	var baseline := screen.battle.state_snapshot()
	var rng := screen.battle.rng_state()
	var receipts := screen.receipts.size()
	var key := "hero_" + str(int(hero["rank"]))
	screen.battle._units[id]["hp"] = 0
	screen.battle._units[id]["hanging"] = true
	screen.battle._units[id]["fray"] = 173
	screen._refresh()
	var meters: Dictionary = screen._rank_meters[key]
	var hp_frame: NinePatchRect = meters["root"].get_node("HPFillSewnFrame")
	var fray_frame: NinePatchRect = meters["root"].get_node("FrayFillSewnFrame")
	_check(screen._puppets[key].visible and meters["root"].visible
		and meters["hp"].value == 0.0 and meters["hp_text"].text == "HANGING"
		and meters["hp_text"].get_theme_color("font_color") == StitchedBattleChrome.AMBER
		and hp_frame.self_modulate == Color("ffd18c")
		and meters["fray"].value == 173.0 and meters["fray_text"].text == "FRAY 173"
		and meters["fray"].tooltip_text == _fray_full(173)
		and meters["hp"].tooltip_text.contains("HP 0/")
		and meters["fray_text"].get_theme_color("font_color") == StitchedBattleChrome.AMBER
		and fray_frame.self_modulate == Color("ffd18c")
		and screen.status_detail("hero", int(hero["rank"])).contains("HANGING")
		and meters["root"].tooltip_text.contains(_fray_full(173)),
		"zero-HP HANGING doll retains warned bone/amber captions, framed fills and full status")
	screen.battle._units[id]["lost"] = true
	screen._refresh()
	_check(not screen._rank_meters[key]["root"].visible and
		not screen._puppets[key].visible,
		"LOST hero removes all meter surfaces instead of leaving a ghost bar")
	screen.battle._units[id] = original
	screen._refresh()
	_check(meters["root"].visible and meters["hp_text"].text == "HP %d" % int(original["hp"])
		and meters["fray_text"].text == "FRAY %d" % int(original["fray"])
		and hp_frame.self_modulate == Color.WHITE and fray_frame.self_modulate == Color.WHITE
		and meters["hp_text"].get_theme_color("font_color") == StitchedBattleChrome.BONE
		and meters["fray_text"].get_theme_color("font_color") == StitchedBattleChrome.BONE,
		"restored healthy hero clears hanging/fray warnings and returns to ordinary bone captions")
	_no_mutation(screen, baseline, rng, receipts,
		"restored authority, RNG and receipts unchanged after hanging/LOST presentation probes")


func _badge_active(row: Control) -> Array[Control]:
	var active: Array[Control] = []
	for chip in row.get_children():
		if chip.visible:
			active.append(chip)
	return active


func _test_badges(screen: StitchedBattleScreen) -> void:
	# Real 1280x720 mounted rank meters; slots are allocated once and never
	# replaced on _refresh. All badges are passive descendants of RankMeters.
	var battle := screen.battle
	var baseline := battle.state_snapshot()
	var rng := battle.rng_state()
	var receipts := screen.receipts.size()
	for side in ["hero", "foe"]:
		for rank in range(1, 5):
			var key := "%s_%d" % [side, rank]
			var meters: Dictionary = screen._rank_meters[key]
			var root_meter: Control = meters["root"]
			var row: Control = root_meter.get_node("BadgeRow")
			_check(row.get_child_count() == 6 and row.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and row.focus_mode == Control.FOCUS_NONE and row.get_global_rect().position.y == 486.0
				and row.size == Vector2(164, 18)
				and row.get_global_rect().position.x >= root_meter.global_position.x
				and row.get_global_rect().end.x <= root_meter.global_position.x + 170,
				"%s has stable six-chip rank footprint at global y486..504" % key)
			for chip in row.get_children():
				_check(chip is Control and chip.mouse_filter == Control.MOUSE_FILTER_IGNORE
					and chip.focus_mode == Control.FOCUS_NONE
					and row.get_global_rect().encloses(chip.get_global_rect())
					and chip.get_node("Felt") is NinePatchRect
					and chip.get_node("Felt").texture == StitchedBattleChrome.NAME_PLATE,
					"%s chip is passive, sewn-textured and inside its own rank" % key)
				for child in chip.get_children():
					_check(child.mouse_filter == Control.MOUSE_FILTER_IGNORE
						and child.focus_mode == Control.FOCUS_NONE,
						"%s badge child never takes mouse or keyboard focus" % key)
	_check(not screen._rank_meters["foe_4"]["root"].visible
		and _badge_active(screen._rank_meters["foe_4"]["root"].get_node("BadgeRow")).is_empty(),
		"initial absent foe rank has no ghost chip")
	var hero_id := str(screen._unit_at("hero", 1)["id"])
	var hero_2_id := str(screen._unit_at("hero", 2)["id"])
	var foe_id := str(screen._unit_at("foe", 1)["id"])
	var hero_original: Dictionary = battle._units[hero_id].duplicate(true)
	var hero_2_original: Dictionary = battle._units[hero_2_id].duplicate(true)
	var foe_original: Dictionary = battle._units[foe_id].duplicate(true)
	battle._units[hero_id]["statuses"] = {}
	battle._units[hero_id]["dodge_buff"] = {}
	battle._units[hero_id]["resolve"] = ""
	battle._units[hero_2_id]["statuses"] = {}
	battle._units[hero_2_id]["resolve"] = ""
	battle._units[foe_id]["statuses"] = {}
	screen._refresh()
	var empty_row: Control = screen._rank_meters["hero_1"]["root"].get_node("BadgeRow")
	_check(not empty_row.visible and _badge_active(empty_row).is_empty()
		and empty_row.tooltip_text == "STATUS: none",
		"actual unmodified no-status hero has no badge or fabricated status")

	# Hanging + Steadfast outrank canonical status counters; positives only.
	battle._units[hero_id]["hp"] = 0
	battle._units[hero_id]["hanging"] = true
	battle._units[hero_id]["fray"] = 145
	battle._units[hero_id]["resolve"] = "steadfast"
	battle._units[hero_id]["statuses"] = {
		"bleed": 3, "weak": 2, "exposed": 2, "thorns": 4,
		"tangled": 2, "blind": 1, "riposte": 3, "stun": 1,
		"stun_resist": 1, "mark": 2, "guard": 1, "zeta": 4,
		"alpha": 1, "expired": 0,
	}
	battle._units[hero_id]["dodge_buff"] = {"amount": 6, "turns": 2}
	battle._units[foe_id]["statuses"] = {"mark": 3, "stun": 1, "guard": 0}
	screen._refresh()
	var shown := _badge_active(empty_row)
	var full: Array[Dictionary] = StitchedBattleChrome._badge_entries(battle.get_unit(hero_id), "hero")
	var overflow := full.size() - 5
	_check(full.size() > 6 and shown.size() == 6
		and shown[0].tooltip_text == "HANGING BY A THREAD"
		and shown[1].tooltip_text == "STEADFAST"
		and shown[2].tooltip_text == "BLEED 3"
		and shown[3].tooltip_text == "WEAK 2"
		and shown[4].tooltip_text == "EXPOSED 2"
		and shown[5].get_node("Short").text == "+"
		and shown[5].get_node("Count").text == str(overflow)
		and shown[5].tooltip_text.contains("DODGE +6 / 2 turns")
		and shown[5].tooltip_text.contains("ALPHA 1")
		and shown[5].tooltip_text.contains("ZETA 4")
		and not empty_row.tooltip_text.contains("EXPIRED"),
		"overflow is five ordered real badges + truthful +N and sorted/complete named disclosure")
	_check(shown[0].get_node("Emblem").texture == load("res://assets/paper/stitched/icons/status_hanging.png")
		and shown[1].get_node("Emblem").texture == load("res://assets/paper/stitched/icons/badge_steadfast.png")
		and shown[2].get_node("Emblem").texture == load("res://assets/paper/stitched/icons/status_bleed.png")
		and shown[3].get_node("Short").text == "WK"
		and shown[4].get_node("Short").text == "EX"
		and shown[3].get_node("Felt").texture == StitchedBattleChrome.NAME_PLATE
		and shown[5].get_node("Felt").texture == StitchedBattleChrome.NAME_PLATE,
		"authored Hanging/Steadfast/Bleed icons and bone-on-felt Weak/Exposed/overflow fallbacks")
	_check(screen._rank_meters["hero_1"]["root"].tooltip_text.contains("FRAY 145/200")
		and screen._rank_meters["hero_1"]["root"].tooltip_text.contains("HANGING BY A THREAD")
		and screen._rank_meters["hero_1"]["root"].tooltip_text.contains("ZETA 4")
		and screen._seat_buttons["hero_1"].tooltip_text.contains("BLEED 3")
		and screen.status_detail("hero", 1).contains("DODGE +6 / 2 turns"),
		"rank tooltip, ordinary seat and existing status detail retain full fray/counts")
	var foe_row: Control = screen._rank_meters["foe_1"]["root"].get_node("BadgeRow")
	var foe_chips := _badge_active(foe_row)
	_check(foe_chips.size() == 2 and foe_chips[0].tooltip_text == "STUN 1"
		and foe_chips[0].get_node("Emblem").texture == load("res://assets/paper/stitched/icons/status_stun.png")
		and foe_chips[1].tooltip_text == "MARK 3"
		and foe_chips[1].get_node("Emblem").texture == load("res://assets/paper/stitched/icons/status_mark.png"),
		"foe displays only two positive canonical cross-stitch badges, not zero guard or intent")
	var inspected := battle.state_snapshot()
	var inspected_rng := battle.rng_state()
	screen._seat_buttons["hero_1"].grab_focus()
	screen._seat_buttons["hero_1"].mouse_entered.emit()
	_check(screen._labels["log"].text == screen.status_detail("hero", 1)
		and screen._status_disclosure_label.text.contains("HANGING")
		and battle.state_snapshot() == inspected and battle.rng_state() == inspected_rng
		and screen.receipts.size() == receipts,
		"keyboard and mouse status inspection are complete and non-mutating")
	screen._seat_buttons["hero_1"].mouse_exited.emit()
	screen._action_buttons["pass"].grab_focus()

	for resolved_trait in ["frantic", "hollow", "bitter", "reckless", "cowering"]:
		battle._units[hero_2_id]["resolve"] = resolved_trait
		battle._units[hero_2_id]["fray"] = 125
		screen._refresh()
		var trait_row: Control = screen._rank_meters["hero_2"]["root"].get_node("BadgeRow")
		var trait_chips := _badge_active(trait_row)
		_check(trait_chips.size() == 1
			and trait_chips[0].tooltip_text == "UNRAVELLED — " + resolved_trait.to_upper()
			and trait_chips[0].get_node("Emblem").texture == load("res://assets/paper/stitched/icons/badge_unravelled.png")
			and trait_chips[0].get_node("Count").text == str(StitchedBattleChrome.BADGE_SHORT[resolved_trait])
			and screen._rank_meters["hero_2"]["root"].tooltip_text.contains(resolved_trait.to_upper()),
			"each real UNRAVELLED trait has its own visible identity and authored icon: " + resolved_trait)
	battle._units[hero_2_id]["lost"] = true
	screen._refresh()
	var lost_row: Control = screen._rank_meters["hero_2"]["root"].get_node("BadgeRow")
	_check(not screen._rank_meters["hero_2"]["root"].visible
		and not lost_row.visible and _badge_active(lost_row).is_empty(),
		"LOST hero clears even previously populated resolve chips")
	battle._units[hero_2_id] = hero_2_original.duplicate(true)
	var extra: Dictionary = battle.get_foes()[2].duplicate(true)
	extra["id"] = "badge_fourth_foe"
	extra["rank"] = 4
	extra["statuses"] = {"blind": 2}
	battle._units[str(extra["id"])] = extra
	screen._refresh()
	var fourth: Control = screen._rank_meters["foe_4"]["root"].get_node("BadgeRow")
	_check(battle.get_foes().size() == 4 and _badge_active(fourth).size() == 1
		and _badge_active(fourth)[0].get_node("Emblem").texture == load("res://assets/paper/stitched/icons/status_blind.png"),
		"genuine fourth summoned foe rank receives its own authored Blind chip")
	battle._units.erase(str(extra["id"]))
	battle._units[hero_id] = hero_original
	battle._units[hero_2_id] = hero_2_original
	battle._units[foe_id] = foe_original
	screen._refresh()
	_check(_badge_active(fourth).is_empty()
		and screen._rank_meters["hero_1"]["root"].get_node("BadgeRow").get_child_count() == 6
		and battle.state_snapshot() == baseline and battle.rng_state() == rng
		and screen.receipts.size() == receipts,
		"expired/absent ranks clear on refresh, reuse fixed children and preserve model, RNG and receipts")


func _test_committed_badge_action() -> void:
	# A fresh mounted screen commits a 100%-accurate authored status move via
	# the public submit_part entry (not a status fabricated by the renderer).
	var mounted := _mount()
	var screen: StitchedBattleScreen = mounted["screen"]
	await process_frame
	var battle := screen.battle
	_check(battle != null and battle.is_valid() and battle._units.has("warden"),
		"precondition: genuine seeded Warden is in mounted combat")
	battle._order = ["warden"]
	battle._turn_index = 0
	screen._refresh()
	var before := battle.state_snapshot()
	var prior_receipts := screen.receipts.size()
	_check(screen.select_part("torso") and screen.legal_targets().has("hero_4"),
		"precondition: mounted Quilt Up can legally give an ally Thorns")
	var result := screen.submit_part("warden_torso_quilt", 4)
	var target: Dictionary = battle.get_unit("lantern_monk")
	var real_status := int(target.get("statuses", {}).get("thorns", 0))
	var row: Control = screen._rank_meters["hero_4"]["root"].get_node("BadgeRow")
	var chips := _badge_active(row)
	_check(bool(result.get("ok", false)) and battle.state_snapshot() != before
		and screen.receipts.size() > prior_receipts and real_status > 0
		and chips.size() == 1 and chips[0].tooltip_text == "THORNS %d" % real_status
		and chips[0].get_node("Short").text == "TH",
		"real committed Quilt Up creates authoritative Thorns and updates mounted text fallback")
	var after := battle.state_snapshot()
	var rng := battle.rng_state()
	var receipts := screen.receipts.size()
	for attempt in range(3):
		screen._refresh()
		_check(_badge_active(row).size() == 1 and battle.state_snapshot() == after
			and battle.rng_state() == rng and screen.receipts.size() == receipts,
			"post-commit badge refresh #%d cannot tick statuses or spend RNG/receipts" % attempt)
	mounted["host"].free()
	await process_frame


func _test_controls(screen: StitchedBattleScreen) -> void:
	var state := screen.battle.state_snapshot()
	var rng := screen.battle.rng_state()
	var receipts := screen.receipts.size()
	screen._refresh()
	screen._part_buttons["head"].mouse_entered.emit()
	screen._part_buttons["head"].mouse_exited.emit()
	screen._seat_buttons["hero_1"].focus_entered.emit()
	screen._seat_buttons["hero_1"].focus_exited.emit()
	screen._action_buttons["reduce_motion"].toggled.emit(true)
	screen._action_buttons["reduce_motion"].toggled.emit(false)
	screen._refresh()
	_no_mutation(screen, state, rng, receipts,
		"refresh, hover, focus and reduced-motion toggle never spend/roll/commit")
	_check(screen._action_buttons["re_tie"].disabled and
		screen._target_buttons["foe_4"].disabled, "blocked action and empty target remain disabled")
	screen._action_buttons["re_tie"].pressed.emit()
	screen._target_buttons["foe_4"].pressed.emit()
	_no_mutation(screen, state, rng, receipts, "even forced blocked callbacks cannot mutate battle")
	var selected := ""
	var chosen := ""
	for slot in StitchedBattleScreen.SLOTS:
		if not screen.select_part(slot):
			continue
		for key in screen.legal_targets():
			if not screen._target_buttons[key].disabled:
				selected = slot
				chosen = str(key)
				break
		if not chosen.is_empty():
			break
	_check(not selected.is_empty() and not chosen.is_empty(),
		"precondition: real current hero has a selectable part and legal target")
	if not chosen.is_empty():
		_no_mutation(screen, state, rng, receipts, "part selection and legal-target preview spend no state or RNG")
		screen._target_buttons[chosen].pressed.emit()
		_check(screen.receipts.size() > receipts and screen.battle.state_snapshot() != state
			and screen.receipts[receipts].get("action") == "ability",
			"real mounted target button delegates one legal sewn-part action through existing gate")
		_verify_meters(screen)
		var after := screen.battle.state_snapshot()
		var after_rng := screen.battle.rng_state()
		var after_count := screen.receipts.size()
		screen._refresh()
		_no_mutation(screen, after, after_rng, after_count,
			"post-action meters refresh entirely from authoritative state without RNG or receipts")


func _click(button: BaseButton) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame


func _test_utilities(screen: StitchedBattleScreen) -> void:
	var selected := false
	for slot in StitchedBattleScreen.SLOTS:
		if screen.select_part(slot) and not screen.legal_targets().is_empty():
			selected = true
			break
	_check(selected and not screen.receipts.is_empty(),
		"precondition: utilities preserve a real selected ability, legal targets and committed receipt")
	var state := screen.battle.state_snapshot()
	var rng := screen.battle.rng_state()
	var receipts := screen.receipts.duplicate(true)
	var last := screen.last_receipt.duplicate(true)
	var targets := screen.legal_targets().duplicate(true)
	var log_text: String = screen._labels["log"].text
	var opener: Button = screen._action_buttons["help"]
	var close: Button = screen._action_buttons["close_help"]
	var motion: CheckButton = screen._action_buttons["reduce_motion"]
	var exit_button: Button = screen._action_buttons["exit"]
	_check(opener.is_visible_in_tree() and screen._labels["log"].is_visible_in_tree()
		and screen._labels["log"].size.y >= 100 and not motion.is_visible_in_tree()
		and not exit_button.is_visible_in_tree() and not close.is_visible_in_tree(),
		"normal right tray shows readable log and one utility opener with secondary controls concealed")
	await _click(opener)
	_check(screen._utilities_open and close.has_focus() and not opener.is_visible_in_tree()
		and motion.is_visible_in_tree() and exit_button.is_visible_in_tree()
		and screen._labels["help"].is_visible_in_tree() and not screen._part_disclosure.visible,
		"real mouse opens instructions and settings inside the sewn tray and focuses close")
	var tray_rect := Rect2(1031, 562, 230, 144)
	for utility in [motion, exit_button, close, screen._labels["help"]]:
		_check(tray_rect.encloses(utility.get_global_rect()), "expanded utility remains inside right tray")
		for group in [screen._part_buttons, screen._part_help_buttons, screen._target_buttons]:
			for control in group.values():
				_check(not utility.get_global_rect().intersects(control.get_global_rect()),
					"utility never covers part, inspection or target control")
		for key in ["move_front", "move_back", "re_tie", "pass", "retreat"]:
			_check(not utility.get_global_rect().intersects(screen._action_buttons[key].get_global_rect()),
				"utility never covers turn action")
	var original_motion := screen.reduced_motion
	await _click(motion)
	_check(screen.reduced_motion != original_motion and motion.button_pressed == screen.reduced_motion,
		"real mouse toggle updates motion preference and check state")
	for puppet in screen._puppets.values():
		_check(puppet.is_processing() == not screen.reduced_motion, "motion toggle updates real puppets")
	motion.grab_focus()
	await _key(KEY_SPACE)
	_check(screen.reduced_motion == original_motion and motion.button_pressed == original_motion,
		"keyboard toggles real motion check back to original preference")
	await _key(KEY_ESCAPE)
	_check(not screen._utilities_open and opener.has_focus()
		and screen._labels["log"].visible and screen._labels["log"].text == log_text,
		"Escape dismisses utilities, restores opener focus and retains log text")
	await _key(KEY_ENTER)
	_check(screen._utilities_open and close.has_focus(), "keyboard reopens utility tray")
	await _key(KEY_ENTER)
	_check(not screen._utilities_open and opener.has_focus(), "keyboard close restores opener focus")
	await _click(opener)
	await _click(close)
	_check(not screen._utilities_open and opener.has_focus(), "mouse close restores opener focus")
	screen._seat_buttons["hero_1"].mouse_entered.emit()
	screen._seat_buttons["hero_1"].mouse_exited.emit()
	_check(screen.legal_targets() == targets and not targets.is_empty()
		and screen.receipts == receipts and screen.last_receipt == last,
		"help, motion and inspection preserve exact legal targets and all receipt contents")
	_no_mutation(screen, state, rng, receipts.size(), "utilities and inspection preserve snapshot and RNG")
	_check(screen._target_buttons["foe_4"].disabled and screen._action_buttons["re_tie"].disabled,
		"utilities retain blocked empty target and unavailable Re-tie")
	var exits := [0]
	screen.exit_requested.connect(func(): exits[0] += 1)
	await _click(opener)
	await _click(exit_button)
	_check(exits[0] == 1, "one real Back to title click emits exactly one exit signal")
	_no_mutation(screen, state, rng, receipts.size(), "exit signal does not commit combat")


func _run() -> void:
	var mounted := _mount()
	await process_frame
	var screen: StitchedBattleScreen = mounted["screen"]
	if screen.battle != null and screen.battle.is_valid():
		_verify_styles(screen)
		_verify_action_icons(screen)
		_verify_meters(screen)
		_test_hanging_and_lost(screen)
		_test_badges(screen)
		_test_controls(screen)
		await _test_utilities(screen)
	await _test_committed_badge_action()
	mounted["host"].free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("stitched_s2_battle_chrome_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
