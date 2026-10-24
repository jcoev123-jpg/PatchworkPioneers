extends "res://tests/live_routed_battle_reentry_test.gd"
## Real connected Rest selection and actual held Strike+ combat input.


func _upgrade_fixture() -> Dictionary:
	for value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var opening_rng := rng.state
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for rest in map.get_node(fight).outgoing:
				if map.get_node(rest).type != "Rest":
					continue
				for next in map.get_node(rest).outgoing:
					if map.get_node(next).type != "Fight":
						continue
					var selector := RunFightEncounterSelection.new()
					rng.state = opening_rng
					map.choose_node(fight)
					var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, selector)
					map.undo_choice(fight, [])
					if selected.get("encounter_id") == "starter_attacks":
						return {"seed": value, "fight": fight, "rest": rest, "next": next}
	return {}


func _upgrade_state() -> Array:
	return [app.run_scraps, app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id, _persistent(), app.run_map.get_floors(), app.party_carryover.read_state(),
		app.rest_upgrade.is_consumed(), app.rest_recovery.is_consumed(),
		app.rest_upgrade._source.duplicate(true), app.rest_upgrade._deck.duplicate(),
		app.rest_upgrade._upgrades.duplicate(true), app.rest_upgrade._valid,
		app._rest_committed_deck.duplicate(), app._rest_committed_heroes.duplicate(true),
		app.rest_heal_button.disabled, app.rest_upgrade_button.disabled,
		app.rest_upgrade_cards.disabled, app.rest_continue_button.disabled, app.route_view]


func _reject_upgrade(callback: Callable, reason: String) -> void:
	var before := _upgrade_state()
	callback.call()
	_check(_upgrade_state() == before, reason + " preserves full state and choice eligibility")


## AC1/AC2: the mounted Rest gallery names the visit in-world, keeps Heal
## recognizable, directs Choose -> Upgrade and gives every heading the master
## PatchHeading face while metadata and effects stay in the readable body face.
func _check_rest_gallery_labels(gallery) -> void:
	var panel: Control = gallery.gallery_panel()
	var title := panel.find_child("GalleryTitle", true, false) as Label
	var hint := panel.find_child("GalleryHint", true, false) as Label
	_check(title != null and title.is_visible_in_tree() and title.text == "Rest · Card mending",
		"mounted Rest gallery title names the Rest and its card mending")
	_check(title != null and title.theme_type_variation == "PatchHeading"
		and _label_face_path(title) == HEADING_FACE_PATH,
		"mounted Rest gallery title wears the master PatchHeading face")
	_check(hint != null and hint.is_visible_in_tree()
		and hint.text == "Choose a card, then press Upgrade — or take Heal instead."
		and hint.text.contains("Upgrade") and hint.text.contains("Heal")
		and _label_face_path(hint) == BODY_FACE_PATH,
		"mounted Rest gallery hint directs Upgrade and keeps Heal recognizable")
	var headings: Array = panel.find_children("GallerySectionHeading*", "Label", true, false)
	_check(headings.size() == 1 and (headings[0] as Label).text == "Mend a card",
		"mounted Rest section names its in-world card mending action")
	for node in headings:
		var label := node as Label
		_check(label.theme_type_variation == "PatchHeading"
			and _label_face_path(label) == HEADING_FACE_PATH
			and label.is_visible_in_tree(),
			"the Rest section heading wears the master PatchHeading face: " + label.text)
	var section_hints: Array = panel.find_children("GallerySectionHint*", "Label", true, false)
	_check(section_hints.size() == 1 and (section_hints[0] as Label).text.contains("Upgrade")
		and (section_hints[0] as Label).text.contains("Heal")
		and _label_face_path(section_hints[0]) == BODY_FACE_PATH,
		"the Rest section hint directs Upgrade in the body face and names Heal")
	var shown := _gallery_text(panel)
	_check(RETIRED_GALLERY_TEXT.all(func(token): return not shown.contains(token)),
		"mounted Rest gallery drops developer wording from titles, hints and empty states")
	for tile in gallery.upgrade_tiles():
		var face_panel: Control = tile.get_parent()
		var name_label := face_panel.find_child("TileName", true, false) as Label
		var meta_label := face_panel.find_child("TileMeta", true, false) as Label
		var effects_label := face_panel.find_child("TileEffects", true, false) as Label
		_check(name_label != null and name_label.theme_type_variation == "PatchHeading"
			and _label_face_path(name_label) == HEADING_FACE_PATH,
			"every Rest card name wears the master PatchHeading face")
		_check(meta_label != null and _label_face_path(meta_label) == BODY_FACE_PATH
			and meta_label.get_theme_font_size("font_size") >= 15
			and face_panel.get_global_rect().encloses(meta_label.get_global_rect()),
			"every Rest tile keeps its body-face metadata at 15 px or more")
		_check(effects_label != null and _label_face_path(effects_label) == BODY_FACE_PATH
			and effects_label.get_theme_font_size("font_size") >= 16
			and face_panel.get_global_rect().encloses(effects_label.get_global_rect()),
			"every Rest tile keeps its body-face effects at 16 px or more")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _upgrade_fixture()
	_check(not fixture.is_empty(), "seeded Fight -> Rest -> Fight path exists")
	if fixture.is_empty():
		await _finish_upgrade()
		return
	var replay: Array = []
	var stale: Callable
	# Strike mouse/keyboard replay, Heal exclusion, then independent Rest visits
	# for each authored support+ card.
	for session in range(6):
		seed(780078)
		var global_next := randi()
		seed(780078)
		if not await _routed_win(fixture, false):
			break
		await _click(app.reward_buttons[3])
		_check(app.run_deck == catalog.get_starting_deck() and app.run_deck.size() == 12,
			"skip retains exact initial twelve-card starter deck")
		await _click(app.continue_button)
		await _click(_route_action(fixture.rest))
		_check(app.rest_upgrade != null and is_instance_valid(app.rest_upgrade_cards)
			and is_instance_valid(app.rest_upgrade_button), "real connected Rest mounts upgrade service and controls")
		if app.rest_upgrade == null or not is_instance_valid(app.rest_upgrade_cards):
			break
		_bounds(app.rest_view)
		_check(app.run_scraps == 1 and app.rest_stitch_button.disabled, "one earned scrap cannot enable Stitch")
		var choices: OptionButton = app.rest_upgrade_cards
		var visit: RunRestCardUpgrade = app.rest_upgrade
		var button: Button = app.rest_upgrade_button
		var upgrade: Callable = button.pressed.get_connections()[0].callable
		var heal: Callable = app.rest_heal_button.pressed.get_connections()[0].callable
		var next: Callable = app.rest_continue_button.pressed.get_connections()[0].callable
		var source: Array = app.run_deck.duplicate()
		var heroes: Array = app.run_heroes.duplicate(true)
		_check(app.rest_hp_label.text.contains(" -> "), "eligible Upgrade visit initially shows pending Heal forecast")
		var ledger: Dictionary = app.party_carryover.read_state()
		var indices: Array[int] = []
		for index in range(source.size()):
			if source[index] == "warden_strike":
				indices.append(index)
		var canonical := RunRestCardUpgrade.list_authored_choices(source, app.run_stitch_descriptors, app.run_next_stitch_id)
		var rows: Array = canonical.get("choices", [])
		_check(canonical.get("ok") == true and indices.size() == 2
			and choices.item_count == rows.size() and not button.disabled
			and rows.size() >= 5 and visit._upgrades == canonical.get("permitted_upgrades"),
			"real Rest presents the complete canonical indexed choice projection")
		if indices.size() != 2 or rows.size() < 5 or choices.item_count != rows.size():
			break
		for item in range(rows.size()):
			var row: Dictionary = rows[item]
			var index: int = row["index"]
			_check(choices.get_item_metadata(item) == index
				and choices.get_item_text(item) == app._rest_upgrade_text(index)
				and choices.get_item_text(item).contains("#%d" % (index + 1))
				and choices.get_item_text(item).contains(String(row["plus_display_name"]))
				and choices.get_item_text(item).contains(str(row["plus_cost"]) + " energy")
				and choices.get_item_text(item).contains(app._rest_effect_text(row["plus_effects"])),
				"each mounted row matches canonical deck index, name, cost and effect")
		var support_ids := ["warden_brace", "seamstress_mend", "seamstress_stitch_up"]
		for base_id in support_ids:
			var deck_index: int = source.find(base_id)
			var found_support := false
			for row in rows:
				if row.get("index") == deck_index and row.get("source_id") == base_id \
						and row.get("plus_id") == base_id + "_plus":
					found_support = true
			_check(deck_index >= 0 and found_support,
				"Rest exposes genuine support choice: " + base_id)
		# One sewn tile per permitted canonical upgrade row, readable without the
		# masked dropdown: owner, before -> after name, both costs and effects.
		var gallery = _visit_tiles()
		_check(gallery.is_gallery_mounted() and gallery.gallery_kind() == "Rest",
			"real Rest mounts the passive visit card gallery")
		var panel: Control = gallery.gallery_panel()
		_check(is_instance_valid(panel) and panel.is_visible_in_tree()
			and Rect2(0, 0, 1280, 720).encloses(panel.get_global_rect())
			and is_instance_valid(gallery.gallery_scroll()),
			"scrollable Rest gallery fits inside 1280x720")
		_check(gallery.upgrade_tiles().size() == rows.size(),
			"Rest gallery shows exactly every permitted upgrade tile")
		_check(choices.is_visible_in_tree() and not choices.disabled and choices.modulate.a == 0.0
			and choices.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and choices.focus_mode == Control.FOCUS_NONE,
			"masked Rest upgrade dropdown keeps its validated contract but takes no pointer or focus")
		_check_rest_gallery_labels(gallery)
		# Independent authored expectations: exact short combat prose and the
		# canonical amount each half must print, never borrowed from the view.
		var effect_contract := {
			"warden_strike": {"before": "Deal 6.", "after": "Deal 7.",
				"before_amount": 6, "after_amount": 7},
			"warden_brace": {"before": "Gain 7 Block.", "after": "Gain 10 Block.",
				"before_amount": 7, "after_amount": 10},
			"seamstress_mend": {"before": "Heal ally 5 HP.",
				"after": "Heal ally 7 HP.", "before_amount": 5, "after_amount": 7},
			"seamstress_stitch_up": {"before": "Ally gains 5 Block.",
				"after": "Ally gains 7 Block.", "before_amount": 5, "after_amount": 7},
		}
		await _frames()
		# Hovering a tile is a read-only explanation: it never upgrades, spends,
		# consumes the Rest or moves the canonical selection.
		var hover_before := _upgrade_state()
		var hover_selection: int = choices.selected
		await _hover(gallery.upgrade_tiles()[0])
		_check(_upgrade_state() == hover_before and choices.selected == hover_selection,
			"hovering an upgrade tile explains it without upgrading, spending or selecting")
		for item in range(rows.size()):
			var row: Dictionary = rows[item]
			var tile = gallery.upgrade_tiles()[item]
			var details: Dictionary = gallery.tile_details(tile)
			_check(gallery.tile_row(tile) == item and details.card_id == String(row["base_id"]),
				"upgrade tile owns the canonical row and deck copy")
			_check(details.owner_text == String(row["owner"]).capitalize()
				and details.title == "%s → %s" % [String(row["display_name"]), String(row["plus_display_name"])]
				and details.meta == "Deck card #%d • cost %d → %d energy" % [
					int(row["index"]) + 1, int(row["cost"]), int(row["plus_cost"])],
				"upgrade tile shows its owner, before -> after name and both costs")
			_check(details.has_picture, "upgrade tile mounts authored art or the owner emblem")
			# Both halves are joined by exactly one line break and each one prints
			# a complete short sentence: never a positional slice of another
			# renderer, and never a valid effect collapsed into "no effect".
			var halves: PackedStringArray = String(details.effects).split("\n")
			_check(halves.size() == 2 and not halves[0].strip_edges().is_empty()
				and not halves[1].strip_edges().is_empty()
				and not details.effects.contains("no effect")
				and not details.effects.contains("No authored description")
				and not details.effects.contains("From:") and not details.effects.contains("Target:")
				and not details.effects.contains("Positions:")
				and halves[0].ends_with(".") and halves[1].ends_with("."),
				"upgrade tile prints one complete concise effect per authored half")
			# The mounted label itself stays readable inside the sewn frame.
			var tile_panel: Control = tile.get_parent()
			var effects_label := tile_panel.find_child("TileEffects", true, false) as Label
			_check(effects_label != null and effects_label.text == details.effects
				and effects_label.get_theme_font_size("font_size") >= 16
				and effects_label.get_global_rect().size.x > 0.0
				and effects_label.get_global_rect().size.y > 0.0
				and tile_panel.get_global_rect().encloses(effects_label.get_global_rect()),
				"the mounted before/after effect stays legible inside its sewn tile")
			if effect_contract.has(String(row["source_id"])):
				var expected: Dictionary = effect_contract[String(row["source_id"])]
				_check(details.effects == "Before: %s\nAfter: %s" % [expected["before"], expected["after"]],
					"upgrade tile reads the exact authored before/after effect: " + String(row["source_id"]))
				_check(halves[0] != halves[1]
					and halves[0].contains(" %d" % int(expected["before_amount"]))
					and halves[1].contains(" %d" % int(expected["after_amount"])),
					"each half prints its own distinct canonical authored amount: " + String(row["source_id"]))
			# AC2: the tile's hover explains both authored halves under their own
			# Before/After headings, each with its own name, cost and rules.
			var base_definition: Dictionary = RunRestStitchCards.resolve_card_definition(String(row["source_id"]))
			var plus_definition: Dictionary = RunRestStitchCards.resolve_card_definition(String(row["plus_id"]))
			_check(not base_definition.is_empty() and not plus_definition.is_empty(),
				"both authored upgrade halves resolve: " + String(row["source_id"]))
			_check(details.tooltip == tile.tooltip_text and not tile.tooltip_text.is_empty(),
				"upgrade tile exposes its hover explanation on the mounted tile button")
			_check_upgrade_tooltip(tile, base_definition, plus_definition)
			if effect_contract.has(String(row["source_id"])):
				var expected_tooltip: Dictionary = effect_contract[String(row["source_id"])]
				var tooltip_halves: PackedStringArray = String(details.tooltip).split("\nAfter:\n")
				_check(tooltip_halves.size() == 2
					and tooltip_halves[0].contains(str(int(expected_tooltip["before_amount"])))
					and tooltip_halves[1].contains(str(int(expected_tooltip["after_amount"])))
					and tooltip_halves[0] != tooltip_halves[1],
					"hover Before and After halves carry their own distinct authored amount: "
						+ String(row["source_id"]))
		# The Rest half renders the CANONICAL row's effects on the authored
		# definition: a different supplied amount changes the sentence, the
		# source definition is never mutated, and empty/unknown stay honest.
		var authored_strike: Dictionary = RunRestStitchCards.resolve_card_definition("warden_strike")
		_check(authored_strike.get("effects") == {"damage": 6}
			and gallery._effects_text({"damage": 7}, authored_strike) == "Deal 7."
			and gallery._effects_text({"damage": 6}, authored_strike) == "Deal 6."
			and authored_strike.get("effects") == {"damage": 6},
			"Rest half renders the supplied canonical amount on the authored definition without mutating it")
		_check(gallery._effects_text({}, authored_strike) == "no effect"
			and gallery._effects_text({"forged": 1}, authored_strike)
				== "Other authored effects are not described."
			and authored_strike.get("effects") == {"damage": 6},
			"Rest half keeps empty and unknown effects honest instead of guessing")
		# A stale or forged canonical row must stay inert: an honest placeholder
		# with no guessed identity or effect, and no upgrade or spend on input.
		var stale_metadata: Variant = choices.get_item_metadata(1)
		var stale_text: String = choices.get_item_text(1)
		choices.set_item_metadata(1, -1)
		await _frames()
		var placeholder = gallery.upgrade_tiles()[1]
		var placeholder_details: Dictionary = gallery.tile_details(placeholder)
		_check(placeholder_details.card_id.is_empty() and placeholder_details.effects.is_empty()
			and placeholder_details.title == "Unavailable selection"
			and placeholder_details.meta == "This row no longer matches the Rest's canonical choices.",
			"a stale Rest row renders an inert placeholder instead of a guessed card or effect")
		_check(placeholder_details.tooltip == LiveVisitCardTiles.DETAILS_UNAVAILABLE
			and placeholder.tooltip_text == placeholder_details.tooltip
			and not placeholder_details.tooltip.contains("Before:")
			and not placeholder_details.tooltip.contains("After:")
			and not placeholder_details.tooltip.contains("damage"),
			"a stale Rest row tooltip says details are unavailable instead of inventing rules")
		var placeholder_before := _persistent()
		await _click_tile(placeholder)
		_check(_persistent() == placeholder_before and app.rest_upgrade != null
			and not app.rest_upgrade.is_consumed(),
			"physical input on the stale placeholder cannot upgrade or spend")
		choices.set_item_metadata(1, stale_metadata)
		choices.set_item_text(1, stale_text)
		await _frames()
		_check(not gallery.tile_details(gallery.upgrade_tiles()[1]).card_id.is_empty()
			and not gallery.tile_details(gallery.upgrade_tiles()[1]).effects.contains("Unavailable"),
			"restoring the canonical row rebuilds its real sewn tile")
		_check(gallery.upgrade_tiles()[1].tooltip_text.contains("Before:\n")
			and gallery.upgrade_tiles()[1].tooltip_text.contains("\nAfter:\n")
			and not gallery.upgrade_tiles()[1].tooltip_text.contains("unavailable"),
			"restoring the canonical row replaces the stale hover text")
		app.rest_heal_button.grab_focus()
		await _key(KEY_TAB)
		_check(gallery.upgrade_tiles()[0].has_focus(), "Tab reaches the first Rest upgrade tile")
		var target_base: String = ("warden_strike" if session <= 2 else
			["", "", "", "warden_brace", "seamstress_mend", "seamstress_stitch_up"][session])
		var target_deck_index: int = indices[1] if session <= 2 else source.find(target_base)
		var target_row := -1
		for row_idx in range(rows.size()):
			if rows[row_idx].get("index") == target_deck_index:
				target_row = row_idx
		_check(target_row >= 0 and target_deck_index >= 0, "chosen authentic deck instance has visible row")
		if target_row < 0:
			break
		var chosen_plus := String(rows[target_row]["plus_id"])
		_reject_upgrade(next, "premature Continue")
		app._rest_committed_deck.assign(source)
		_reject_upgrade(upgrade, "forged partially committed deck")
		app._rest_committed_deck.clear()
		if stale.is_valid():
			_reject_upgrade(stale, "previous session upgrade")
		_reject_upgrade(app._upgrade_at_rest.bind(RunRestCardUpgrade.new(source, {"warden_strike": "warden_strike_plus"}), button, choices), "foreign visitor")
		_reject_upgrade(app._upgrade_at_rest.bind(visit, app.rest_heal_button, choices), "foreign action")
		var foreign := OptionButton.new()
		_reject_upgrade(app._upgrade_at_rest.bind(visit, button, foreign), "foreign selector")
		foreign.free()
		# Every rejection starts with otherwise-valid mounted controls and preserves all surviving models.
		for invalid in [-1, source.size(), "1", 1.5, source.find("seamstress_prick")]:
			choices.set_item_metadata(1, invalid)
			_reject_upgrade(upgrade, "forged index " + str(invalid))
		choices.set_item_metadata(1, indices[1])
		choices.set_item_text(1, "forged label")
		_reject_upgrade(upgrade, "forged label")
		choices.set_item_text(1, app._rest_upgrade_text(indices[1]))
		for mapping in [{}, {"warden_strike": "unknown"}, {"warden_brace": "warden_strike_plus"}]:
			visit._upgrades = mapping
			_reject_upgrade(upgrade, "unmapped or invalid replacement")
		visit._upgrades = canonical["permitted_upgrades"].duplicate(true)
		var stored_row: Dictionary = app._rest_upgrade_choices[1].duplicate(true)
		app._rest_upgrade_choices[1]["plus_effects"]["forged"] = 99
		_reject_upgrade(upgrade, "forged stored canonical row")
		app._rest_upgrade_choices[1] = stored_row
		visit._valid = false
		_reject_upgrade(upgrade, "invalid visitor")
		visit._valid = true
		visit._consumed = true
		_reject_upgrade(upgrade, "forged consumed visitor")
		_reject_upgrade(next, "forged consumption cannot complete Rest")
		visit._consumed = false
		visit._deck[indices[1]] = "warden_brace"
		_reject_upgrade(upgrade, "forged visitor deck")
		visit._deck.assign(source)
		app.run_deck[indices[0]] = "seamstress_prick"
		_reject_upgrade(upgrade, "changed run deck")
		app.run_deck.assign(source)
		app.run_heroes[0].hp -= 1
		_reject_upgrade(upgrade, "changed party")
		app.run_heroes = heroes.duplicate(true)
		app.session_gold += 1
		_reject_upgrade(upgrade, "changed gold")
		app.session_gold -= 1
		var rng_state: int = app.run_rng.state
		app.run_rng.randi()
		_reject_upgrade(upgrade, "changed run RNG")
		app.run_rng.state = rng_state
		var map: RunMap = app.run_map
		app.run_map = RunMap.new()
		_reject_upgrade(upgrade, "replaced map identity")
		app.run_map = map
		map._route.append(fixture.next)
		_reject_upgrade(upgrade, "changed route")
		map._route.pop_back()
		var edges: Array = map._nodes[fixture.rest].outgoing.duplicate()
		map._nodes[fixture.rest].outgoing.clear()
		_reject_upgrade(upgrade, "changed map edges")
		map._nodes[fixture.rest].outgoing = edges
		for control in [button, choices, app.rest_view]:
			control.hide()
			_reject_upgrade(upgrade, "hidden input or visit")
			control.show()
		button.disabled = true
		_reject_upgrade(upgrade, "disabled action")
		button.disabled = false
		choices.disabled = true
		_reject_upgrade(upgrade, "disabled selector")
		choices.disabled = false
		if session == 2:
			await _click(app.rest_heal_button)
			_check(app.rest_recovery.is_consumed() and app.rest_upgrade_button.disabled, "Heal remains available and excludes Upgrade")
			_reject_upgrade(upgrade, "Upgrade after Heal")
		else:
			# Select the intended deck instance through its real sewn tile.
			var target_tile = _tile_for("upgrade", target_row)
			_check(target_tile != null and gallery.tile_row(target_tile) == target_row,
				"the chosen canonical row owns one sewn upgrade tile")
			if target_tile == null:
				break
			var selection_before := _persistent()
			if session in [0, 3]:
				await _click_tile(target_tile)
			else:
				await _select_tile_by_key(target_tile)
			_check(_persistent() == selection_before, "tile selection alone cannot upgrade or consume the Rest")
			_check(choices.selected == target_row and choices.get_item_metadata(choices.selected) == target_deck_index,
				"physical tile input selects exactly the intended authored deck index")
			_check(gallery.tile_details(target_tile).selected,
				"the chosen occurrence is visibly selected in the gallery")
			var before := _persistent()
			if session in [0, 3]:
				await _click(button)
			else:
				target_tile.grab_focus()
				for step in range(gallery.upgrade_tiles().size() + 2):
					if button.has_focus():
						break
					await _key(KEY_TAB)
				_check(button.has_focus(), "Tab reaches the Upgrade action from the tiles")
				await _key(KEY_ENTER)
			var upgraded := source.duplicate()
			upgraded[target_deck_index] = chosen_plus
			_check(visit.is_consumed() and not app.rest_recovery.is_consumed() and app.run_deck == upgraded,
				"exact selected deck instance upgraded once, without consuming Heal")
			_check(_persistent().slice(2) == before.slice(2) and app.run_heroes == heroes
				and app.party_carryover.read_state() == ledger, "Upgrade preserves heroes, gold, RNG, route, combat and carryover ledger")
			var hp_lines: PackedStringArray = []
			for hero in heroes:
				hp_lines.append("%s: HP %d/%d" % [hero.id.capitalize(), hero.hp, hero.max_hp])
			_check(app.rest_hp_label.text == "\n".join(hp_lines), "Upgrade removes forecast and keeps exact current HP rows")
			app._refresh_rest_hp()
			_check(app.rest_hp_label.text == "\n".join(hp_lines), "refresh cannot restore forecast after Upgrade")
			_check(app.rest_heal_button.disabled and button.disabled and choices.disabled
				and not app.rest_continue_button.disabled, "exclusive consumed upgrade enables Continue")
			await _frames()
			_check(gallery.upgrade_tiles().all(func(tile): return tile.disabled),
				"every upgrade tile disables once the Rest choice is spent")
			_reject_upgrade(upgrade, "duplicate Upgrade")
			_reject_upgrade(heal, "Heal after Upgrade")
			app.run_deck[indices[0]] = "seamstress_prick"
			_reject_upgrade(next, "changed committed deck")
			app.rest_recovery._consumed = true
			_reject_upgrade(next, "forged Heal consumption cannot bypass committed upgrade validation")
			app.rest_recovery._consumed = false
			app.run_deck.assign(upgraded)
			await _click(app.rest_continue_button)
			_check(app.route_view != null and not app.rest_view.visible, "Upgrade Continue opens legal connected chooser")
			_check(app.route_buttons.size() == map.get_legal_choices().size(), "exact legal connected choices remain playable")
			_reject_upgrade(upgrade, "hidden prior Rest")
			var oracle := _oracle(fixture.next)
			await _click(_route_action(fixture.next))
			_check(app.battle_result.get_outcome() == CombatBattleResult.ACTIVE and _mounted_state() == oracle,
				"next real battle uses upgraded deck and unchanged carried party")
			# Draw from the real ongoing deck, never inject a held card.
			while not app.deck.hand.has(chosen_plus) and not app.deck.draw_pile.is_empty():
				_check(app.deck.draw_extra(1) == 1, "real next-battle draw")
			app._refresh_hand()
			await _frames()
			_check(app.deck.hand.has(chosen_plus), "upgraded authored copy actually held in next routed battle")
			if session < 2:
				var combat := _state()
				var target: int = CombatAttackTargeting.new().get_preview(app.deck, app.party, app.enemies, "warden_strike_plus").get("target_positions", [0])[0]
				_check(target > 0, "living legal recipient exists")
				var enemy: Dictionary = app.enemies.get_enemy(target)
				_check(app.party.get_hero(1).get("statuses", {}).is_empty() and enemy.get("statuses", {}).is_empty(), "seven-damage base case has no modifiers")
				if await _choose("warden_strike_plus", session == 1):
					await _key([KEY_1, KEY_2, KEY_3][target - 1])
				var expected_hand: Array = combat.hand.duplicate()
				expected_hand.erase("warden_strike_plus")
				_check(presenter.last_event.ok and presenter.last_event.hits[0].damage == 7,
					"real held-card input resolves exactly seven base damage")
				_check(app.deck.energy == combat.energy - 1 and app.deck.hand == expected_hand
					and app.deck.discard_pile == combat.discard + ["warden_strike_plus"]
					and app.deck.draw_pile == combat.draw and app.run_rng.state == combat.rng,
					"standard single charge/discard preserves remaining piles and RNG")
				_check(app.enemies.get_enemy(target).hp == enemy.hp - maxi(0, 7 - enemy.block), "actual recipient loses exact unblocked damage")
				var state: Array = [_persistent(), app.party_carryover.read_state(), presenter.last_event]
				if session == 0:
					replay = state.duplicate(true)
				else:
					_check(state == replay, "same-seed mouse/keyboard replay matches full next battle and attack")
			else:
				# Cast from the actual mounted shared hand, using the Warden or
				# Seamstress's authored owner/target, never a direct resolver call.
				var support = app.get_node("LiveSupportHand")
				var held: Control = null
				for card_panel in app.hand_view.get_children():
					if card_panel.get_child_count() > 0 and card_panel.get_child(0) is Label \
							and card_panel.get_child(0).text == chosen_plus:
						held = card_panel
						break
				_check(held != null and support._bindings.has(held)
					and support._eligible(held, chosen_plus, app.deck, app.party, app.battle_view),
					"upgraded support is visible and actionable in the real next-Fight hand")
				if session == 4:
					_check(app.party.apply_damage(1, 15), "living Warden genuinely wounded for Mend+")
					app._refresh_party()
				var old_heroes: Array = app.party.get_heroes()
				var old_hand: Array = app.deck.hand.duplicate()
				var old_draw: Array = app.deck.draw_pile.duplicate()
				var old_discard: Array = app.deck.discard_pile.duplicate()
				var old_energy: int = app.deck.energy
				var old_rng: int = app.run_rng.state
				var old_enemies: Array = app.enemies.get_enemies()
				var old_route: Array = app.run_map.get_route()
				var old_wallet: Array = [app.session_gold, app.run_scraps, app.run_deck.duplicate(),
					app.run_heroes.duplicate(true), app.party_carryover.read_state()]
				_check(held != null, "actual held upgraded support panel exists before physical input")
				if held != null:
					if session == 3:
						await _click(held)
					else:
						held.grab_focus()
						await _key(KEY_ENTER)
					await _frames()
					if session in [4, 5]:
						_check(support._pending.get("choosing", false) and support._targets.has(app.hero_panels[0]),
							"Seamstress support+ opens genuine living ally selection")
						app.hero_panels[0].grab_focus()
						await _key(KEY_ENTER)
						await _frames()
				var expected_hand: Array = old_hand.duplicate()
				expected_hand.erase(chosen_plus)
				_check(app.deck.energy == old_energy - 1 and app.deck.hand == expected_hand
					and app.deck.draw_pile == old_draw
					and app.deck.discard_pile == old_discard + [chosen_plus]
					and app.run_rng.state == old_rng,
					"mounted support+ costs exactly one energy, hand card and discard, no RNG")
				var expected_amount: int = 10 if session == 3 else 7
				var new_heroes: Array = app.party.get_heroes()
				_check(new_heroes.size() == 3 and old_heroes.size() == 3,
					"real living three-hero party survives support cast")
				if session == 3:
					_check(new_heroes[0].block == old_heroes[0].block + expected_amount
						and new_heroes[0].hp == old_heroes[0].hp,
						"Brace+ grants authored ten Block to its living Warden owner")
				elif session == 4:
					_check(new_heroes[0].hp == mini(old_heroes[0].max_hp, old_heroes[0].hp + expected_amount)
						and new_heroes[0].block == old_heroes[0].block,
						"Mend+ heals actual living target by seven")
				else:
					_check(new_heroes[0].block == old_heroes[0].block + expected_amount
						and new_heroes[0].hp == old_heroes[0].hp,
						"Stitch Up+ gives actual living ally seven Block")
				_check(new_heroes.slice(1) == old_heroes.slice(1) and app.enemies.get_enemies() == old_enemies
					and app.run_map.get_route() == old_route
					and [app.session_gold, app.run_scraps, app.run_deck, app.run_heroes,
						app.party_carryover.read_state()] == old_wallet,
					"support+ preserves unrelated actors, enemy, route, wallet and carried state")
		stale = upgrade
		await _click(app.return_button if app.battle_view.visible else app.rest_back_button)
		_check(app.rest_upgrade == null and app.rest_upgrade_cards == null and app.rest_upgrade_button == null
			and app._rest_committed_deck.is_empty() and app.run_deck.is_empty() and app.run_map == null,
			"title clears all upgrade state and controls")
		_check(not gallery.is_gallery_mounted() and gallery.upgrade_tiles().is_empty()
			and not is_instance_valid(gallery.gallery_panel()),
			"title discards the Rest gallery, its tiles and its callbacks")
		stale.call()
		_check(app.run_map == null and app.run_deck.is_empty(), "post-title upgrade callback inert")
		_check(randi() == global_next, "complete path consumes no global RNG")
	_check(app._start_battle(), "explicit standalone M01 fixture starts")
	await _frames()
	_check(app.deck != null and app.rest_upgrade == null and app.run_map == null, "restart creates independent battle")
	stale.call()
	_check(not app.run_deck.has("warden_strike_plus"), "stale callback cannot upgrade restarted run")
	await _click(app.return_button)
	await _finish_upgrade()


func _finish_upgrade() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_rest_upgrade_choice_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
