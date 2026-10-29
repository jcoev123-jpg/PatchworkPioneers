extends "res://tests/live_rest_stitch_choice_test.gd"
## Earn three scraps and stitch through real controls, then draw the owned
## composite from the next routed Fight's actual deck. No manufactured IDs.
var _stale_card_input: Callable
var captured_forecast: Dictionary = {}
var forecast_before: Array = []


func _capture_forecast() -> void:
	if presenter.current_forecast.get("playable", false):
		_check(_complete_state() == forecast_before, "live forecast spends no cards energy passives or RNG before commit")
		captured_forecast = presenter.current_forecast.duplicate(true)
		_check(presenter.cue.text.contains("Projected"), "real cue displays current ordered forecast")


func _frames() -> void:
	# Two rendered headless frames settle deferred actions and container layout.
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	super._check(condition, message)
	if not condition:
		printerr(message)


func _panel(id: String):
	for panel in app.hand_view.get_children():
		if panel.get_child(0).text == id:
			return panel
	return null


## The real presenter must name both ledger halves, in order, on its detailed
## battle-hand face while keeping the shared cost, two-part tooltip and input.
func _stitched_face(id: String, pair: Array, metadata) -> void:
	var ledger := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)
	_check(ledger.is_valid(), "held composite is backed by the real Rest ledger")
	if not ledger.is_valid():
		return
	var descriptor: Dictionary = ledger.get_snapshot().descriptors.get(id, {})
	_check(descriptor.get("half_ids", []) == pair and int(descriptor.get("cost", -1)) >= 0,
		"real ledger preserves authored half order and shared cost")
	var first: Dictionary = metadata.definition(str(pair[0]))
	var second: Dictionary = metadata.definition(str(pair[1]))
	var first_name: String = str(first.get("display_name", ""))
	var second_name: String = str(second.get("display_name", ""))
	_check(not first.is_empty() and not second.is_empty() and not first_name.is_empty()
		and not second_name.is_empty() and first.get("owner") != second.get("owner"),
		"both authored halves have names and different owners")
	var first_colour: Color = metadata._owner_color(str(first.get("owner", "")))
	var second_colour: Color = metadata._owner_color(str(second.get("owner", "")))
	_check(first_colour != second_colour and first_colour != metadata.INK and second_colour != metadata.INK,
		"each authored half keeps its own distinct owner colour")
	var panel = _panel(id)
	_check(panel != null and is_instance_valid(panel) and metadata._bindings.has(panel),
		"genuine composite panel is bound before any play")
	if panel == null or not is_instance_valid(panel) or not metadata._bindings.has(panel):
		return
	var facts: Dictionary = metadata.get_facts(panel)
	_check(facts.get("halves", []) == pair and facts.get("cost") == descriptor.get("cost"),
		"bound face facts carry the ledger's ordered halves and shared cost")
	var tooltip: String = panel.tooltip_text
	_check(tooltip.begins_with("1. " + first_name + ";") and tooltip.contains("\n2. " + second_name + ";"),
		"two-part tooltip names each authored half in resolution order")
	_check(tooltip.contains(metadata.base_effect_text(str(pair[0])))
		and tooltip.contains(metadata.base_effect_text(str(pair[1]))),
		"each tooltip part keeps that half's complete authored rules")
	# Each half keeps its own terse authored effect, in ledger order, and the
	# mounted composite summary shows first then second without a from/target row.
	var first_line: String = metadata.short_line(str(pair[0]))
	var second_line: String = metadata.short_line(str(pair[1]))
	_check(not first_line.is_empty() and not second_line.is_empty()
		and first_line != second_line,
		"each stitched half keeps a distinct terse effect: " + id)
	for line in [first_line, second_line]:
		_check(not line.contains("BASE") and not line.contains("Unknown"),
			"stitched half face line stays terse: " + id)
		for banned in ["From", "Target", "living", "pick 1", "front", "middle", "back"]:
			_check(not line.contains(banned),
				"stitched half face prints no '%s': %s" % [banned, id])
	_check(str(metadata.get_facts(panel).get("rules", "")) == "1. %s · 2. %s" % [first_line, second_line],
		"composite face summary keeps first then second authored effect: " + id)
	# The real battle hand keeps the detailed, noncompact face: both ordered halves
	# get the renderer's three-line geometry instead of the compact one-row fallback.
	var real_geometry: Dictionary = metadata.get_geometry(panel)
	var real_rows: Array = real_geometry.get("halves", [])
	_check(not bool(real_geometry.get("compact", true)) and panel.size.y >= 160.0,
		"real held stitched panel uses the detailed tall face")
	_check(is_equal_approx(panel.size.y, app.hand_view.custom_minimum_size.y),
		"held card height is the hand row's own authoritative height")
	_check(real_rows.size() == 2, "detailed face keeps one sewn region per authored half")
	if real_rows.size() == 2:
		var first_row: Rect2 = real_rows[0]
		var second_row: Rect2 = real_rows[1]
		var real_bounds := Rect2(Vector2.ZERO, panel.size)
		_check(first_row.size.y >= 30.0 and second_row.size.y >= 30.0,
			"both halves get the renderer's detailed row height, not a compact strip")
		_check(real_bounds.encloses(first_row) and real_bounds.encloses(second_row)
			and first_row.position.y < second_row.position.y,
			"both detailed stitched halves fit the real panel in ledger order")
	# The compact one-row fallback still exists for shorter mounted panels.
	var min_size: Vector2 = panel.custom_minimum_size
	var tall_height: float = panel.size.y
	var draws: int = int(metadata._bindings[panel]["draw_count"])
	panel.custom_minimum_size = Vector2(min_size.x, 96.0)
	await _frames()
	var geometry: Dictionary = metadata.get_geometry(panel)
	_check(panel.size.y < 120.0 and bool(geometry.get("compact", false)),
		"shorter mounted panel falls back to the compact battle-hand face")
	var rows: Array = geometry.get("halves", [])
	var bounds := Rect2(Vector2.ZERO, panel.size)
	_check(rows.size() == 2, "compact face reserves one sewn row per authored half")
	if rows.size() == 2:
		_check(rows[0].position.y < rows[1].position.y and rows[0].end.y <= rows[1].position.y
			and rows[1].end.y <= geometry["footer"].end.y + 0.01
			and rows[0].size.y >= 20.0 and bounds.encloses(rows[0]) and bounds.encloses(rows[1]),
			"both sewn rows fit the real face in first then second order")
	_check(metadata.get_facts(panel).get("halves", []) == pair, "compact face keeps the ledger half order")
	var binding: Dictionary = metadata._bindings[panel]
	_check(binding["id"] == id and panel.draw.is_connected(binding["draw"])
		and panel.draw.get_connections().size() == 1, "compact face keeps the single draw callback")
	_check(int(binding["draw_count"]) > draws, "real CanvasItem actually redrew the compact face")
	_check(panel.gui_input.get_connections().size() == 1 and not panel.get_child(0).visible,
		"compact face keeps one gameplay handler and the hidden identity")
	panel.custom_minimum_size = min_size
	await _frames()
	_check(is_equal_approx(panel.size.y, tall_height) and not bool(metadata.get_geometry(panel).get("compact", true)),
		"real hand layout restores its tall face after the compact check")


## Faces and tooltips take each half's authored catalog name, so a Rest-upgraded
## half keeps its "+" instead of degrading to a base name or a raw ID.
func _authored_upgrade_names() -> void:
	var metadata = app.get_node("LiveSupportHand")._metadata
	var upgraded: Dictionary = metadata.definition("warden_strike_plus")
	_check(upgraded.get("display_name") == "Strike+" and metadata.base_effect_text("warden_strike_plus").begins_with("Strike+; Warden; 1 energy"),
		"authored '+' upgrade half keeps its authored name and cost")
	var deck: Array[String] = ["warden_strike_plus", "seamstress_prick", "tinker_pop_shot"]
	var ledger := RunRestStitchCards.new(deck, {}, 3, 1)
	_check(ledger.is_valid(), "authored upgraded-half fixture is a valid Rest ledger")
	if not ledger.is_valid():
		return
	var made := ledger.choose_stitch(0, 1, ledger.get_snapshot())
	var made_descriptor: Dictionary = made.get("descriptor", {})
	_check(bool(made.get("ok", false))
		and made_descriptor.get("half_ids", []) == ["warden_strike_plus", "seamstress_prick"],
		"real stitched ledger preserves an upgraded first half")
	if not bool(made.get("ok", false)):
		return
	var tooltip: String = metadata.stitched_tooltip(made_descriptor.get("half_ids", []))
	_check(tooltip.begins_with("1. Strike+; Warden; 1 energy") and tooltip.contains("\n2. Prick; Seamstress; 1 energy"),
		"two-part stitched tooltip keeps upgraded and base half names in order")
	_check(tooltip.contains("BASE deal 7 damage") and tooltip.contains("BASE deal 3 damage")
		and not tooltip.contains("BASE deal 6 damage"), "stitched tooltip states each half's own authored effect")
	# The upgraded half keeps its own short-sentence face line beside the base half.
	_check(metadata.short_line("warden_strike_plus") == "Deal 7."
		and metadata.short_line("warden_strike") == "Deal 6."
		and metadata.short_line("seamstress_prick") == "Deal 3. Bleed 3.",
		"stitched halves keep their own terse authored amounts")
	var made_pair: Array = made_descriptor.get("half_ids", [])
	_check(made_pair.size() == 2
		and metadata.short_line(str(made_pair[0])) == "Deal 7."
		and metadata.short_line(str(made_pair[1])) == "Deal 3. Bleed 3.",
		"real stitched pair keeps both terse half effects in order")


func _hover(control: Control) -> void:
	for point in [Vector2(2, 2), control.get_global_rect().get_center()]:
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, true)
		await _frames()


func _snapshot() -> Array:
	return [app.deck.hand.duplicate(), app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(),
		app.deck.energy, app.deck.turn_active, app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_intents.get_intents(), app.enemy_intents._turn_index, app.run_rng.state, app.battle_result.get_outcome()]


func _return() -> void:
	await _click(app.return_button)
	_check(app.deck == null and presenter.cue == null and presenter._bindings.is_empty(), "Return clears live selection")


func _hand_fixture() -> Dictionary:
	# Repinned so every tested composite can be drawn without overcrowding the
	# hand below the renderer's 88px minimum for the detailed/compact face checks.
	for value in [28258] + range(1, 50001):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for fight in map.get_legal_choices():
			if map.get_node(fight).type != "Fight":
				continue
			for elite in map.get_node(fight).outgoing:
				if map.get_node(elite).type != "Elite":
					continue
				for rest in map.get_node(elite).outgoing:
					if map.get_node(rest).type != "Rest":
						continue
					for next in map.get_node(rest).outgoing:
						if map.get_node(next).type != "Fight":
							continue
						map.choose_node(fight)
						var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
						if entry.get("encounter_id") == "starter_attacks":
							return {"seed": value, "fight": fight, "elite": [elite], "rest": [rest], "next": next}
						map.undo_choice(fight, [])
	return {}


func _earn(fixture: Dictionary, pair: Array, keyboard: bool,
		sew_wearer: String = "", sew_patch: bool = true, claim_offer: String = "",
		upgrade_claim: bool = false) -> String:
	if not await _routed_win(fixture, false):
		return ""
	# `claim_offer` takes that seeded pool card through the actual opening reward
	# button instead of Skip; both mint exactly the one opening scrap.
	var offered := -1
	for index in range(app.fight_reward_offers.size()):
		if app.fight_reward_offers[index].id == claim_offer:
			offered = index
	_check(claim_offer.is_empty() or offered >= 0, "seeded opening Fight offers the pool card " + claim_offer)
	if not claim_offer.is_empty() and offered < 0:
		return ""
	await _click(app.reward_buttons[3 if claim_offer.is_empty() else offered])
	_check(claim_offer.is_empty() or (app.run_deck.back() == claim_offer and app.run_deck.count(claim_offer) == 1
		and app.run_scraps == 1), "real reward input acquires exactly one pool card and one scrap")
	if upgrade_claim:
		var options := RunRestCardUpgrade.list_authored_choices(app.run_deck,
			app.run_stitch_descriptors, app.run_next_stitch_id)
		_check(options.get("ok", false) and options.permitted_upgrades.has(claim_offer),
			"authored pool upgrade option exists for awarded card")
		if not options.get("ok", false) or not options.permitted_upgrades.has(claim_offer):
			return ""
		var upgrade := RunRestCardUpgrade.new(app.run_deck, options.permitted_upgrades,
			app.run_stitch_descriptors, app.run_next_stitch_id)
		var receipt := upgrade.choose_upgrade(app.run_deck.find(claim_offer))
		_check(receipt.get("ok", false) and upgrade.is_consumed()
			and receipt.get("upgraded_id") == options.permitted_upgrades[claim_offer],
			"canonical Rest upgrade service supplies the plus printing in setup")
		if not receipt.get("ok", false):
			return ""
		app.run_deck.assign(receipt.deck)
		_check(RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors,
			app.run_scraps, app.run_next_stitch_id).is_valid(),
			"upgraded pool deck retains authentic Rest stitch ledger")
	await _click(app.continue_button)
	# The opening reward closes before a genuine run-owned COAT receipt is sewn
	# through the actual wardrobe transaction, so every later visit (Elite pass,
	# Rest admission and the next Fight) carries the same worn patch ledger.
	if not sew_wearer.is_empty() and not _sew_coat(sew_wearer, sew_patch):
		return ""
	await _visit_path(fixture.elite.slice(0, -1), keyboard)
	await _click(_route_action(fixture.elite.back()))
	_check(app.enemies != null and app.run_map.get_current_node_id() == fixture.elite.back(), "actual Elite earns stitch purse")
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 9999), "defeat mounted Elite")
	app._observe_battle_result()
	await _frames()
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	await _visit_path(fixture.rest.slice(0, -1), keyboard)
	await _click(_legacy_rest_control(_route_action(fixture.rest.back())))
	_check(app.run_scraps == 3 and app.rest_stitch != null and app.rest_stitch.is_valid(), "earned three scraps at connected Rest")
	if app.rest_stitch == null or not app.rest_stitch.is_valid():
		return ""
	await _select_stitch(app.rest_stitch_first, app.run_deck.find(pair[0]), keyboard)
	await _select_stitch(app.rest_stitch_second, app.run_deck.find(pair[1]), keyboard)
	await _click(app.rest_stitch_button)
	_check(app.run_scraps == 0 and app.run_stitch_descriptors.size() == 1, "real Rest action allocates composite")
	if app.run_stitch_descriptors.is_empty():
		return ""
	var id: String = app.run_stitch_descriptors.keys()[0]
	_check(app.run_stitch_descriptors[id].half_ids == pair, "authentic ordered half IDs")
	await _click(app.rest_continue_button)
	await _click(_route_action(fixture.next))
	_check(app.deck != null and app.battle_result.can_continue(), "next connected Fight mounted")
	_check(app.deck.turn_active and (app.deck.hand.has(id) or app.deck.draw_pile.has(id)), "active next Fight contains earned composite")
	if not app.deck.turn_active or not (app.deck.hand.has(id) or app.deck.draw_pile.has(id)):
		return ""
	while not app.deck.hand.has(id) and not app.deck.draw_pile.is_empty():
		_check(app.deck.draw_extra(1) == 1, "draw actual owned composite")
	# The detailed face needs the real hand's authored card width (>= 88px).
	# Return only the fixture's own extra draws so an 11-card hand cannot shrink
	# every card below that minimum; the composite and the opening deal stay.
	while app.deck.hand.size() > CombatDeck.TURN_DRAW:
		var extra := ""
		for card_id in app.deck.hand:
			if card_id != id:
				extra = card_id
				break
		if extra.is_empty():
			break
		app.deck.hand.erase(extra)
		app.deck.draw_pile.push_back(extra)
	app._refresh_hand()
	await _frames()
	# A seeded enemy shove may leave Shield Bash's Warden in slot two.
	# Restore his legal front seat before asserting the mounted panel is actionable.
	if claim_offer == "seamstress_thread_whip":
		await _restore_stitch_positions(id)
		app._refresh_hand()
		await _frames()
	_check(_panel(id) != null and presenter._bindings.has(_panel(id)), "held ordered panel bound to production presenter")
	await _stitched_face(id, pair, app.get_node("LiveSupportHand")._metadata)
	if _stale_card_input.is_valid():
		var before := _complete_state()
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		_stale_card_input.call(event)
		await _key(KEY_1)
		_check(_complete_state() == before, "retained freed panel callback rejects after restart")
	return id


## A genuine run-owned COAT receipt: the authored M05 record is sewn through the
## real wardrobe transaction and bound by the actual routed carryover. `sew` false
## keeps the patch genuinely owned but worn by nobody.
func _sew_coat(wearer: String, sew: bool) -> bool:
	var carry := app.party_carryover as RunTornCarryover
	_check(carry != null and carry.is_valid(), "routed carryover exists before the COAT receipt")
	if carry == null or not carry.is_valid() or carry._wardrobe != null:
		_check(false, "an unbound routed carryover owns the first COAT receipt")
		return false
	if not app.run_trinkets.has("borrowed_button"):
		app.run_trinkets.append("borrowed_button")
	# The run's own authored definition projection: the real Elite sewing flow
	# builds its wardrobe from exactly this set, so an owned drop stays valid.
	var definitions: Array = RunAuthoredPatchDefinitions.load_definitions()
	_check(not definitions.is_empty(), "authored patch definitions load for the run")
	if definitions.is_empty():
		return false
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		definitions, app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
	_check(wardrobe.is_valid(), "authentic run context builds a valid patch wardrobe")
	if not wardrobe.is_valid():
		return false
	var defined: Dictionary = wardrobe.get_snapshot().definitions
	_check(defined.get("borrowed_button") == "COAT",
		"run definitions carry the Borrowed Button as an authored COAT")
	if sew:
		var sewn := wardrobe.sew("borrowed_button", wearer, "COAT",
			"lane220_live_borrowed_button", wardrobe.get_snapshot())
		_check(sewn.get("ok", false)
			and sewn.get("receipt", {}).get("patch_id") == "borrowed_button",
			"real COAT sew transaction commits the Borrowed Button")
		if not sewn.get("ok", false):
			return false
	var state: Dictionary = wardrobe.get_snapshot()
	_check(state.owned.has("borrowed_button")
		and (state.worn[wearer].COAT == "borrowed_button") == sew,
		"owned COAT is sewn onto the tested wearer only when requested")
	var bound: bool = carry.can_bind_wardrobe(wardrobe, carry.torn, state) \
		and carry.bind_wardrobe(wardrobe, carry.torn, state)
	_check(bound and carry._wardrobe == wardrobe,
		"actual routed carryover adopts the committed patch wardrobe")
	return bound


func _hero_position(hero_id: String) -> int:
	for hero in app.party.get_heroes():
		if hero.get("id") == hero_id:
			return int(hero.get("position", 0))
	return 0


## A real enemy phase can shove the front hero. Restore only an authored legal
## ordering with a genuine adjacent swap, so both halves keep their FROM slots and
## every hero keeps its own HP and Block.
func _restore_stitch_positions(id: String) -> void:
	if presenter._stitch_preview(id).get("playable", false):
		return
	if _hero_position("seamstress") != 1:
		_check(false, "only an authored front-slot shove can unpick this composite")
		return
	var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
	_check(swap.get("ok", false), "the displaced owner can make a real adjacent swap home")
	if not swap.get("ok", false):
		return
	app.party._heroes.assign(swap.heroes)
	app._refresh_party()
	await _frames()
	_check(presenter._stitch_preview(id).get("playable", false),
		"real adjacent swap restores both authored half positions")


## A real End Turn, then the authentic shared deck must hand the composite back.
func _coat_next_turn(id: String) -> bool:
	for position in range(1, CombatParty.PARTY_SIZE + 1):
		if not app.party.is_downed(position):
			app.party.heal(position, 999)
	app._refresh_party()
	await _frames()
	await _click(app.end_turn_button)
	_check(app.deck != null and app.deck.turn_active, "real End Turn opens the next shared player turn")
	while app.deck.turn_active and not app.deck.hand.has(id) \
			and (app.deck.draw_pile.has(id) or app.deck.discard_pile.has(id)):
		_check(app.deck.draw_extra(1) == 1, "real seeded draw recovers the held composite")
	app._refresh_hand()
	await _frames()
	await _restore_stitch_positions(id)
	_check(app.deck.hand.has(id) and presenter._bindings.has(_panel(id)) and app.deck.energy >= 2,
		"the next real turn holds the two-cost composite again")
	return app.deck.hand.has(id) and app.deck.energy >= 2


## One physical two-half commit of the held composite through the real hand. The
## Mend half selects its ally; the authored self-Brace half is auto-ordered by the
## resolver's own `_skip_automatic`, so no synthetic second target is clicked.
func _coat_play(id: String, heal_target: int) -> bool:
	await _arm(id, false)
	await _pick(heal_target, "ally", false)
	_check(presenter.last_event.get("ok", false)
		and presenter.last_event.get("halves", []).size() == 2,
		"physical two-half COAT composite commits both ordered halves")
	return presenter.last_event.get("ok", false)


## One committed composite plus its exact HP/Block/cost/discard/RNG/latch facts.
## The wearer always takes the second half's authored 7 Block; only the committed
## other-owner heal may add the COAT's single 3-Block award.
func _coat_commit_case(id: String, heal_target: int, brace_target: int,
		expected_award: int, expected_receipts: int, label: String) -> void:
	var target_hp_before: int = int(app.party.get_hero(heal_target).hp)
	var target_max: int = int(app.party.get_hero(heal_target).max_hp)
	var brace_hp_before: int = int(app.party.get_hero(brace_target).hp)
	var block_before: int = int(app.party.get_hero(brace_target).block)
	var energy_before: int = app.deck.energy
	var discard_before: int = app.deck.discard_pile.count(id)
	var rng_before: int = app.run_rng.state
	var button: CombatBorrowedButton = app.get_node("LiveSupportHand")._heal_cards._borrowed_button
	_check(button != null, label + ": the mounted hand owns one COAT notifier")
	if button == null:
		return
	var awards_before: int = int(button.read_state().awards)
	await _coat_play(id, heal_target)
	var receipt: Dictionary = presenter.last_event
	_check(receipt.get("ok", false) and receipt.get("halves", []).size() == 2
		and receipt.halves[0].get("effect") == "ally_heal"
		and receipt.halves[1].get("effect") == "self_block",
		label + ": ordered Mend then self-Brace halves commit as authored support effects")
	_check(int(app.party.get_hero(heal_target).hp) == mini(target_hp_before + 5, target_max),
		label + ": committed Mend half restores exactly five HP to its recipient")
	var expected_brace_hp: int = mini(target_hp_before + 5, target_max) \
		if brace_target == heal_target else brace_hp_before
	_check(int(app.party.get_hero(brace_target).hp) == expected_brace_hp,
		label + ": only the Mend recipient's HP changes")
	_check(int(app.party.get_hero(brace_target).block) == block_before + 7 + expected_award,
		label + ": Brace's own 7 Block plus exactly " + str(expected_award) + " COAT Block")
	_check(app.deck.energy == energy_before - 2 and not app.deck.hand.has(id)
		and app.deck.discard_pile.count(id) == discard_before + 1,
		label + ": exactly one shared two-cost charge and one discard")
	_check(app.run_rng.state == rng_before,
		label + ": the committed heal, Block and COAT award consume no run RNG")
	var state: Dictionary = button.read_state()
	_check(state.get("ok") == true, label + ": the bound COAT authorities are still current")
	_check(int(state.awards) == awards_before + (1 if expected_award > 0 else 0)
		and int(state.block_awarded) == 3 * int(state.awards)
		and state.receipts.size() == expected_receipts,
		label + ": the one shared combat latch records exactly this committed heal")
	if expected_award > 0:
		_check(state.wearer_id == "warden"
			and String(state.receipt_id).begins_with("stitched_half_"),
			label + ": the award names the wounded wearer and the stitched half receipt")


## AC1/AC2/AC3 mounted: the worn COAT follows only a genuinely committed stitched
## heal, shares its one latch across hand refreshes, and never pays twice.
func _coat_stitched_case(id: String, mode: String) -> void:
	var support = app.get_node("LiveSupportHand")
	var heals: CombatSeamstressPoolHeals = support.stitched_heal_authority(
		app.deck, app.party, app.battle_view)
	_check(heals != null and heals == support._heal_cards,
		"mounted hand lends its own battle-bound healing service to the commit")
	_check(support.stitched_heal_authority(app.deck,
			CombatParty.new(app.party.get_heroes()), app.battle_view) == null
		and support.stitched_heal_authority(app.deck, app.party, app.return_button) == null,
		"a foreign party or session can never borrow the COAT latch")
	if heals == null:
		return
	var button: CombatBorrowedButton = heals._borrowed_button
	_check(button != null, "mounted hand owns one bound COAT notifier")
	_check(heals._wardrobe == app.party_carryover._wardrobe,
		"the stitched commit shares the run's authenticated patch wardrobe")
	_check(heals._torn == app.party_carryover.torn,
		"the stitched commit shares the run's authenticated torn ledger")
	if button == null:
		return
	var preview: Dictionary = presenter._stitch_preview(id)
	_check(preview.get("playable", false) and int(preview.get("cost", -1)) == 2,
		"authored Mend/Brace composite is held for its shared two energy")
	if not preview.get("playable", false):
		return
	var warden := _hero_position("warden")
	var heal_target := warden
	if mode == "self":
		heal_target = _hero_position("seamstress")
	_check(warden > 0 and heal_target > 0 and not app.party.is_downed(warden)
		and not app.party.is_downed(heal_target),
		"sewn COAT wearer and committed heal recipient are living")
	if mode == "sewn":
		# A deferred stitched commit that fails revalidation must never heal,
		# spend, discard, roll RNG or spend the COAT latch.
		await _arm(id, false)
		_check(presenter._choices.is_empty() and not presenter._queued,
			"physical composite is armed without a partial commit")
		var stale := _snapshot()
		var stale_event: Dictionary = presenter.last_event.duplicate(true)
		var press := InputEventKey.new()
		press.keycode = KEY_1
		press.pressed = true
		root.push_input(press, true)
		_check(presenter._queued and presenter._choices.size() == 2,
			"a physical first target orders both authored halves")
		app.run_scraps = 1
		await _frames()
		_check(_snapshot() == stale and presenter.last_event == stale_event,
			"stale stitched selection never heals, pays, discards or rolls RNG")
		_check(int(button.read_state().awards) == 0 and button.read_state().receipts.is_empty(),
			"stale selection leaves the one-combat latch completely unspent")
		app.run_scraps = 0
		presenter._cancel_choice()
		app._refresh_hand()
		await _frames()
	# Later halves always target the Warden; only the Mend recipient varies.
	for position in [warden, heal_target]:
		app.party.heal(position, 999)
	app._refresh_party()
	await _frames()
	_check(app.party.apply_damage(warden, 6), "authored opening Block is spent before the COAT check")
	_check(app.party.apply_damage(heal_target, 9 if heal_target == warden else 10),
		"the committed heal's recipient genuinely lost HP")
	app._refresh_party()
	await _frames()
	_check(int(app.party.get_hero(warden).block) == 0,
		"no lingering Block can hide the exact authored award")
	await _coat_commit_case(id, heal_target, warden,
		3 if mode == "sewn" else 0, 1, "stitched " + mode)
	if mode != "sewn":
		return
	_check(int(button.read_state().awards) == 1,
		"the first eligible committed heal paid exactly once")
	# The same battle-scoped latches survive every live hand refresh.
	var awarded_button := button
	for repeat in range(3):
		app._refresh_hand()
		await _frames()
	_check(support._heal_cards == heals and heals._borrowed_button == awarded_button
		and support.stitched_heal_authority(app.deck, app.party, app.battle_view) == heals,
		"one battle-scoped COAT latch and its authorities survive hand refreshes")
	_check(int(button.read_state().awards) == 1
		and button.read_state().wearer_id == "warden",
		"refreshing the hand never re-arms the spent combat latch")
	# A second genuine other-owner heal in the same combat pays no extra Block.
	if not await _coat_next_turn(id):
		return
	warden = _hero_position("warden")
	_check(app.party.apply_damage(warden, 9), "the wearer is wounded again for the second heal")
	app._refresh_party()
	await _frames()
	await _coat_commit_case(id, warden, warden, 0, 2, "second stitched heal")
	_check(int(button.read_state().awards) == 1,
		"a later eligible heal in the same combat pays nothing extra")
	# The same owner healing itself is a real heal, never an other-owner award.
	if not await _coat_next_turn(id):
		return
	var seamstress := _hero_position("seamstress")
	warden = _hero_position("warden")
	_check(seamstress > 0 and app.party.apply_damage(seamstress, 10),
		"the Seamstress is genuinely wounded for her own committed Mend")
	app._refresh_party()
	await _frames()
	await _coat_commit_case(id, seamstress, warden, 0, 3, "self-owner stitched heal")
	_check(int(button.read_state().awards) == 1,
		"an owner's self-heal never awards the COAT Block")


func _coat_cases(fixture: Dictionary) -> void:
	for mode in ["sewn", "self", "unsewn"]:
		seed(105105)
		var global_next := randi()
		seed(105105)
		print("stitched COAT case: ", mode)
		var id := await _earn(fixture, ["seamstress_mend", "warden_brace"], false,
			"warden", mode != "unsewn")
		if id.is_empty():
			return
		await _coat_stitched_case(id, mode)
		await _return()
		_check(randi() == global_next, "worn COAT route and stitched cast preserve global RNG")


func _return_race(id: String) -> void:
	await _click(app.end_turn_button)
	while app.deck.turn_active and not app.deck.hand.has(id) and (app.deck.draw_pile.has(id) or app.deck.discard_pile.has(id)):
		_check(app.deck.draw_extra(1) == 1, "real redraw for Return race")
	app._refresh_hand()
	await _frames()
	_check(app.deck.hand.has(id) and _panel(id) != null and is_instance_valid(_panel(id))
		and presenter._bindings.has(_panel(id)), "Return race has genuine held actionable composite")
	var panel = _panel(id)
	if panel == null or not is_instance_valid(panel) or not presenter._bindings.has(panel):
		return
	_stale_card_input = presenter._bindings[panel].input
	await _arm(id, true)
	await _key(KEY_1)
	var deck: CombatDeck = app.deck
	var party: CombatParty = app.party
	var enemies: CombatEnemies = app.enemies
	var rng: RandomNumberGenerator = app.run_rng
	var before := [deck.hand.duplicate(), deck.draw_pile.duplicate(), deck.discard_pile.duplicate(), deck.energy, party.get_heroes(), enemies.get_enemies(), rng.state]
	var event := InputEventKey.new()
	event.keycode = KEY_1
	event.pressed = true
	root.push_input(event, true)
	_check(presenter._queued, "second target genuinely queued immediately before physical Return")
	for pressed in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = app.return_button.get_global_rect().get_center()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		root.push_input(mouse, true)
	await _frames()
	_check(app.deck == null and presenter._choices.is_empty(), "Return invalidates pending composite")
	_check([deck.hand, deck.draw_pile, deck.discard_pile, deck.energy, party.get_heroes(), enemies.get_enemies(), rng.state] == before, "Return race preserves all surviving old models and RNG")


func _deferred_rejections(id: String) -> void:
	for reason in ["receipt", "panel", "turn", "session", "target"]:
		await _arm(id, false)
		await _key(KEY_1)
		var event := InputEventKey.new()
		event.keycode = KEY_1
		event.pressed = true
		root.push_input(event, true)
		_check(presenter._queued, "real second target queued before deferred " + reason)
		_check(presenter.current_forecast.get("playable", false) and presenter.cue.text.contains("Projected"),
			"live ordered projection is displayed before the deferred commit: " + reason)
		var party: CombatParty = app.party
		var turn: int = app.enemy_intents._turn_index
		var foes: Array = app.enemies.get_enemies()
		match reason:
			"receipt": app.run_scraps = 1
			"panel": app._refresh_hand()
			"turn": app.enemy_intents._turn_index += 1
			"session": app.party = CombatParty.new(app.party.get_heroes())
			"target": app.enemies._enemies[0].id += "_replaced"
		var staged := _complete_state()
		await _frames()
		_check(_complete_state() == staged, "deferred " + reason + " revalidated without mutation")
		_check(presenter.cue != null and not presenter.cue.text.contains("Projected")
			and not presenter.current_forecast.get("playable", false) and presenter._armed == null
			and presenter._choices.is_empty() and presenter._receipt.is_empty(),
			"stale " + reason + " rejection retires the projection and armed cue")
		app.party = party
		app.enemy_intents._turn_index = turn
		app.enemies._enemies.assign(foes)
		app.run_scraps = 0
		app._refresh_hand()
		await _frames()
	await _arm(id, false)
	await _key(KEY_1)
	await _click(app.end_turn_button)
	_check(presenter._armed == null and presenter._choices.is_empty() and app.enemy_intents._turn_index > 0, "actual End Turn invalidates partial target choice")
	while app.deck.turn_active and not app.deck.hand.has(id) and (app.deck.draw_pile.has(id) or app.deck.discard_pile.has(id)):
		_check(app.deck.draw_extra(1) == 1, "redraw composite for legal retry after actual turn")
	app._refresh_hand()
	await _frames()


func _arm(id: String, keyboard: bool) -> void:
	if keyboard:
		for attempt in range(app.deck.hand.size() + 1):
			await _key(KEY_P)
			if presenter._armed == _panel(id):
				break
	else:
		await _click(_panel(id))
	_check(presenter._armed == _panel(id) or presenter.last_event.get("ok", false), "physical input selects composite")


func _pick(position: int, side: String, keyboard: bool) -> void:
	if keyboard:
		await _key(KEY_1 + position - 1)
	elif side == "ally":
		await _click(app.hero_panels[position - 1])
	else:
		await _click(app.get_node("LiveEnemyRoster")._labels[position - 1])


func _complete_state() -> Array:
	return [_snapshot(), app._stitch_snapshot(), presenter._play._tinker._consumed,
		presenter._play._patches._consumed.duplicate(true) if presenter._play._patches != null else null]


func _rejections(id: String) -> void:
	# Each failure begins with a genuine, held, affordable, living-owner card.
	for reason in ["cancel", "rebuild", "energy", "downed", "misplaced", "forged", "unowned", "unheld", "turn", "receipt", "target"]:
		await _arm(id, false)
		await _key(KEY_1)
		_check(presenter._choices.size() == 1, "first required target captured before " + reason)
		var energy: int = app.deck.energy
		var heroes: Array = app.party.get_heroes()
		var enemies: Array = app.enemies.get_enemies()
		var registry: Dictionary = app.run_stitch_descriptors.duplicate(true)
		var hand: Array = app.deck.hand.duplicate()
		match reason:
			"cancel": await _key(KEY_ESCAPE)
			"rebuild": app._refresh_hand()
			"energy": app.deck.combat_state.energy = 0
			"downed": app.party._heroes[1].hp = 0
			"misplaced":
				var swap := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
				_check(swap.ok, "legal owner displacement fixture")
				app.party._heroes.assign(swap.heroes)
			"forged": app.run_stitch_descriptors[id].cost = 0
			"unowned": app.run_stitch_descriptors.clear()
			"unheld": app.deck.hand.erase(id)
			"turn": app.deck.combat_state.player_turn_active = false
			"receipt": app.run_scraps += 1
			"target": app.enemies._enemies[0].position = 3
		var before := _complete_state()
		await _key(KEY_1)
		_check(_complete_state() == before, reason + " rejects without partial effects, spend, RNG or passive drift")
		if reason in ["forged", "unowned"]:
			var stale_panel = _panel(id)
			var stale_metadata = app.get_node("LiveSupportHand")._metadata
			_check(stale_panel != null and stale_metadata.get_facts(stale_panel).get("known", true) == false,
				"stale " + reason + " descriptor rebinds the held card to the honest unknown face")
			_check(stale_panel != null and stale_panel.tooltip_text == "Unknown card",
				"stale " + reason + " descriptor tooltip invents no rules")
		app.deck.combat_state.energy = energy
		app.deck.combat_state.player_turn_active = true
		app.party._heroes.assign(heroes)
		app.enemies._enemies.assign(enemies)
		app.run_stitch_descriptors = registry
		app.deck.hand.assign(hand)
		app.run_scraps = 0
		app._refresh_hand()
		await _frames()
	# First half kills the selected second target: only the transaction can
	# discover this later failure. It must roll back damage AND Bleed/passives.
	var enemies: Array = app.enemies.get_enemies()
	app.enemies._enemies[0].hp = 1
	await _arm(id, false)
	await _key(KEY_1)
	var before := _complete_state()
	await _key(KEY_1)
	_check(not presenter.last_event.get("ok", true) and _complete_state() == before, "second-half killed target atomically rolls back real first-half hit")
	app.enemies._enemies.assign(enemies)
	app._refresh_hand()
	await _frames()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _hand_fixture()
	print("stitched route fixture: ", fixture)
	_check(not fixture.is_empty(), "seeded earned-stitch-to-Fight route exists")
	if fixture.is_empty():
		await _finish_hand()
		return
	_authored_upgrade_names()
	for pair in [["warden_shield_bash", "seamstress_prick"], ["seamstress_mend", "tinker_pop_shot"], ["seamstress_stitch_up", "tinker_scrap_bomb"], ["warden_brace", "tinker_tune_up"], ["tinker_pop_shot", "seamstress_prick"], ["tinker_scrap_bomb", "seamstress_mend"]]:
		var replay: Array = []
		for keyboard in [false, true]:
			print("stitched pair: ", pair, " keyboard=", keyboard)
			seed(105105)
			var global_next := randi()
			seed(105105)
			var id := await _earn(fixture, pair, keyboard)
			if id.is_empty():
				await _finish_hand()
				return
			if pair[0] == "warden_shield_bash":
				await _rejections(id)
				await _deferred_rejections(id)
				# Hemhook can shove the Warden out of the opening slot on the real End Turn.
				# A position-restricted stitch must then reject; restore a legal adjacent
				# party ordering for the subsequent complete two-half transaction oracle.
				if app.party.get_hero(1).get("id") != "warden":
					var displaced: Array[Dictionary] = app.party.get_heroes()
					var displaced_ledger := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)
					var displaced_preview := CombatStitchedTargetPreview.new().get_preview(displaced_ledger, app._stitch_snapshot(), app.deck, app.party, app.enemies, id)
					_check(not displaced_preview.playable, "authored enemy shove makes the front-owner stitch unplayable")
					var restore := CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
					_check(restore.ok and displaced[0].id == "seamstress" and displaced[1].id == "warden", "real enemy shove has two living adjacent heroes that may legally swap back")
					if restore.ok:
						app.party._heroes.assign(restore.heroes)
						app._refresh_party()
						await _frames()
						_check(app.party.get_hero(1).id == "warden" and app.party.get_hero(2).id == "seamstress" and app.party.get_hero(1).hp == displaced[1].hp and app.party.get_hero(2).hp == displaced[0].hp, "restoring legal positions retains each displaced hero's HP")
			_check(app.party.apply_damage(1, 7), "healing has real missing HP")
			app._refresh_party()
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.gain_block(enemy.position, 20), "blocked enemies survive ordered hits")
			if pair in [["tinker_pop_shot", "seamstress_prick"], ["seamstress_mend", "tinker_pop_shot"]]:
				while not app.deck.hand.has("tinker_pop_shot") and not app.deck.draw_pile.is_empty():
					_check(app.deck.draw_extra(1) == 1, "real draw of surviving ordinary Tinker copy")
				app._refresh_hand()
				await _frames()
				_check(app.deck.hand.has("tinker_pop_shot"), "shared passive test has real held ordinary attack")
			var rng := RandomNumberGenerator.new()
			rng.state = app.run_rng.state
			var deck := CombatDeck.new([], rng)
			deck.hand.assign(app.deck.hand)
			deck.draw_pile.assign(app.deck.draw_pile)
			deck.discard_pile.assign(app.deck.discard_pile)
			deck.combat_state.energy = app.deck.energy
			deck.combat_state.player_turn_active = true
			var party := CombatParty.new(app.party.get_heroes())
			party._heroes = app.party.get_heroes()
			var enemies := CombatEnemies.new(app.enemies.get_enemies())
			enemies._enemies = app.enemies.get_enemies()
			var attacks := CombatAttackCards.new()
			attacks.start_player_turn()
			var shared_service = presenter._play
			if pair[0] == "tinker_pop_shot":
				var ordinary := attacks.play_attack(deck, party, enemies, "tinker_pop_shot", 1)
				await _click(_panel("tinker_pop_shot"))
				await _key(KEY_1)
				_check(presenter.last_event == ordinary and ordinary.hits[0].damage == 8, "ordinary attack first consumes shared Tinker bonus")
				await _arm(id, false)
				await _key(KEY_1)
				var old_party: CombatParty = app.party
				var old_result: CombatBattleResult = app.battle_result
				app.party = CombatParty.new(app.party.get_heroes())
				app.battle_result = CombatBattleResult.new(app.party, app.enemies)
				await _frames()
				_check(presenter._armed == null and presenter._choices.is_empty() and presenter._play == shared_service and presenter._play._tinker._consumed, "session change cancels pending choices without resetting consumed passive")
				app.party = old_party
				app.battle_result = old_result
				await _frames()
			var ledger := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)
			var preview := CombatStitchedTargetPreview.new().get_preview(ledger, app._stitch_snapshot(), app.deck, app.party, app.enemies, id)
			_check(preview.playable and preview.halves.size() == 2, "genuine descriptor has two legal half shapes")
			if not preview.playable:
				await _finish_hand()
				return
			var targets: Array[int] = []
			for half in preview.halves:
				targets.append((half.target_positions.back() if targets.size() == 1 else half.target_positions[0]) if half.requires_selection else 0)
			var expected := CombatStitchedCards.new(attacks).play_stitched(deck, party, enemies, ledger, id, targets[0], targets[1])
			_check(expected.ok, "independent scene-free transaction succeeds")
			var metadata = app.get_node("LiveSupportHand")._metadata
			var facts: Dictionary = metadata.get_facts(_panel(id))
			_check(facts.get("halves", []) == pair and facts.cost == preview.cost and not _panel(id).get_child(0).visible, "mounted cream composite has descriptor-backed ordered halves and hidden identity")
			await _hover(_panel(id))
			_check(_panel(id).get_child(0).text == id and presenter.cue.text.contains("%d energy" % preview.cost)
				and presenter.cue.text.begins_with(catalog.get_definition(pair[0]).display_name + " / " + catalog.get_definition(pair[1]).display_name), "unchanged ID label and ordered names/cost in actual cue")
			_check(Rect2(0, 0, 1280, 720).encloses(presenter.cue.get_global_rect()), "stitched cue fits mounted viewport")
			for index in range(2):
				var half: Dictionary = preview.halves[index]
				var legal := str(half.target_positions) if half.requires_selection else "automatic (0), slots " + str(half.affected_positions)
				_check(presenter.cue.text.contains("%d: %s %s" % [index + 1, half.side, legal]), "cue exposes each exact legal per-half target shape")
			forecast_before = _complete_state()
			captured_forecast = {}
			presenter.forecast_updated.connect(_capture_forecast)
			await _arm(id, keyboard)
			for index in range(2):
				if preview.halves[index].requires_selection:
					await _pick(targets[index], preview.halves[index].side, keyboard)
			if keyboard and targets == [0, 0]:
				await _key(KEY_SPACE)
			presenter.forecast_updated.disconnect(_capture_forecast)
			_check(captured_forecast.get("playable", false) and captured_forecast.get("halves", []) == expected.halves, "routed live forecast predicts exact ordered committed effects")
			if captured_forecast.get("playable", false):
				var projected: Dictionary = captured_forecast.projected
				_check([projected.hand, projected.draw_pile, projected.discard_pile, projected.energy, projected.heroes, projected.enemies, projected.rng_state, projected.tinker_consumed] == [app.deck.hand, app.deck.draw_pile, app.deck.discard_pile, app.deck.energy, app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state, presenter._play._tinker._consumed], "live chosen-target projection equals complete actual commit including passive and RNG")
			_check(presenter.last_event == expected, "physical composite event matches exact ordered oracle")
			_check([app.deck.hand, app.deck.draw_pile, app.deck.discard_pile, app.deck.energy, app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state]
				== [deck.hand, deck.draw_pile, deck.discard_pile, deck.energy, party.get_heroes(), enemies.get_enemies(), rng.state], "complete HP/Block/Bleed/deck/energy/RNG transition equals oracle")
			_check(presenter._play._tinker._consumed == attacks._tinker._consumed, "same attack authority consumes exact Tinker bonus")
			_check(presenter._play == shared_service, "composite retains the ordinary attack service across hand rebuild")
			if pair[0] == "seamstress_mend":
				var ordinary := attacks.play_attack(deck, party, enemies, "tinker_pop_shot", 1)
				await _click(_panel("tinker_pop_shot"))
				await _key(KEY_1)
				_check(presenter.last_event == ordinary and ordinary.hits[0].damage == 5, "composite consumes bonus once before ordinary attack")
				_check([app.deck.hand, app.deck.discard_pile, app.deck.energy, app.enemies.get_enemies()] == [deck.hand, deck.discard_pile, deck.energy, enemies.get_enemies()], "mixed composite/ordinary exact state")
			for index in range(3):
				var hero: Dictionary = app.party.get_hero(index + 1)
				_check(app.hero_panels[index].get_child(0).text.contains("HP: %d/%d | Block: %d" % [hero.hp, hero.max_hp, hero.block]), "exact hero HP and Block refreshed")
			for enemy in app.enemies.get_enemies():
				var roster = app.get_node("LiveEnemyRoster")
				var tag: Label = roster._labels[enemy.position - 1]
				_check(tag.text == String(enemy.name),
					"exact enemy name tag agrees with resolved oracle")
				if enemy.hp == 0:
					_check(roster._badges[enemy.position - 1].icon_mode == "slain"
						and roster._badges[enemy.position - 1].readable_text == "SLAIN",
						"a slain enemy announces its death on the intent badge")
				var meter = app.get_node("LiveCombatMeters").row.get_child(2 + enemy.position)
				_check(meter.hp_text.is_visible_in_tree() and meter.hp_text.text == "%d/%d" % [enemy.hp, enemy.max_hp]
					and meter.block_badge.visible == (enemy.block > 0)
					and meter.block_text.text == ("%d" % enemy.block if enemy.block > 0 else ""),
					"exact visible enemy HP and Block display agrees with resolved oracle")
			var trace := [_snapshot(), presenter.last_event.duplicate(true), app._stitch_snapshot()]
			if replay.is_empty():
				replay = trace
			else:
				_check(trace == replay, "seeded mouse/keyboard full-state replay")
			if pair[0] == "warden_shield_bash":
				await _return_race(id)
			else:
				await _return()
			_check(randi() == global_next, "earned route and cast preserve global RNG")
	await _coat_cases(fixture)
	await _pool_case()
	await _scatter_area_cases()
	await _plain_strike_cases()
	await _sight_glass_case()
	await _knit_case(fixture)
	await _finish_hand()


## Seed 2005's opening Fight offers the authored Tinker pool Rivet Shot. It is
## claimed by the real reward button, stitched ahead of the Seamstress's Prick at
## the connected Rest, drawn in the next routed Fight and cast by mouse or keys.
const POOL_FIXTURE := {"seed": 2005, "fight": "f01_n0", "elite": ["f02_n0"], "rest": ["f03_n0"], "next": "f04_n1"}


func _pool_case() -> void:
	var pair := ["tinker_rivet_shot", "seamstress_prick"]
	var replay: Array = []
	for keyboard in [false, true]:
		print("pool stitched pair: ", pair, " keyboard=", keyboard)
		seed(105105)
		var global_next := randi()
		seed(105105)
		var id := await _earn(POOL_FIXTURE, pair, keyboard, "", true, pair[0])
		if id.is_empty():
			return
		_check(app.run_stitch_descriptors[id].cost == 2 and app.deck.hand.has(id), "earned pool composite is held at its capped shared cost")
		var ledger := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)
		var preview := CombatStitchedTargetPreview.new().get_preview(ledger, app._stitch_snapshot(), app.deck, app.party, app.enemies, id)
		_check(preview.playable and preview.halves.size() == 2 and preview.halves[0].requires_selection
			and preview.halves[1].requires_selection, "pool half and Prick both need real enemy targets")
		if not preview.playable:
			return
		var first: int = preview.halves[0].target_positions[0]
		var second: int = first if preview.halves[1].target_positions.has(first) else preview.halves[1].target_positions[0]
		_check(second == first and app.enemies.get_enemy(first).hp > 11 and app.enemies.get_enemy(first).block == 0,
			"both halves can strike the same unblocked enemy, which survives them")
		var rng := RandomNumberGenerator.new()
		rng.state = app.run_rng.state
		var deck := CombatDeck.new([], rng)
		deck.hand.assign(app.deck.hand)
		deck.draw_pile.assign(app.deck.draw_pile)
		deck.discard_pile.assign(app.deck.discard_pile)
		deck.combat_state.energy = app.deck.energy
		deck.combat_state.player_turn_active = true
		var party := CombatParty.new(app.party.get_heroes())
		party._heroes = app.party.get_heroes()
		var enemies := CombatEnemies.new(app.enemies.get_enemies())
		enemies._enemies = app.enemies.get_enemies()
		var attacks := CombatAttackCards.new()
		attacks.start_player_turn()
		var expected := CombatStitchedCards.new(attacks).play_stitched(deck, party, enemies, ledger, id, first, second)
		_check(expected.ok and expected.halves.size() == 2, "independent scene-free pool composite succeeds")
		if not expected.ok:
			return
		# Rivet Shot: printed 4 + the unspent Tinker first-attack 3, then Exposed 1;
		# Prick then reads that Exposed for 4 and adds Bleed.
		var rivet: Dictionary = expected.halves[0].hits[0]
		var prick: Dictionary = expected.halves[1].hits[0]
		_check(rivet.position == first and rivet.damage == 7 and rivet.statuses.get("exposed", 0) == 1,
			"pool half lands its authored hit, first-attack bonus and Exposed")
		_check(prick.position == first and prick.damage == 4, "second half reads the pool half's Exposed")
		var hand_before: Array = app.deck.hand.duplicate()
		var energy_before: int = app.deck.energy
		var discard_before: Array = app.deck.discard_pile.duplicate()
		var shared_service = presenter._play
		_check(not shared_service._tinker._consumed, "Tinker bonus is unspent before the physical cast")
		await _arm(id, keyboard)
		await _pick(first, "enemy", keyboard)
		await _pick(second, "enemy", keyboard)
		_check(presenter.last_event == expected, "physical pool composite event equals the exact oracle")
		_check([app.deck.hand, app.deck.draw_pile, app.deck.discard_pile, app.deck.energy, app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state]
			== [deck.hand, deck.draw_pile, deck.discard_pile, deck.energy, party.get_heroes(), enemies.get_enemies(), rng.state], "complete pool composite transition equals oracle")
		_check(app.deck.energy == energy_before - 2 and app.deck.hand.size() == hand_before.size() - 1 and not app.deck.hand.has(id)
			and app.deck.discard_pile.back() == id and app.deck.discard_pile.slice(0, -1) == discard_before, "one energy charge and exactly one composite discard")
		_check(presenter._play == shared_service and shared_service._tinker._consumed, "the live attack service spent the Tinker bonus once")
		var after := _complete_state()
		await _key(KEY_1 + first - 1)
		await _key(KEY_1 + first - 1)
		_check(_complete_state() == after, "repeated input after the cast is inert")
		var trace := [_snapshot(), presenter.last_event.duplicate(true), app._stitch_snapshot()]
		if replay.is_empty():
			replay = trace
		else:
			_check(trace == replay, "seeded mouse/keyboard pool composite replay")
		await _return()
		_check(randi() == global_next, "earned pool route and cast preserve global RNG")


## Seed 3106's opening Fight offers the authored Tinker gadget Sight Glass. It is
## claimed by the real reward button, stitched ahead of the Seamstress's Prick at
## the connected Rest, drawn in the next routed Fight and cast by mouse or keys.
const SIGHT_FIXTURE := {"seed": 3106, "fight": "f01_n2", "elite": ["f02_n3"], "rest": ["f03_n2"], "next": "f04_n3"}


func _sight_glass_case() -> void:
	var pair := ["tinker_sight_glass", "seamstress_prick"]
	var replay: Array = []
	for keyboard in [false, true]:
		print("sight glass stitched pair: ", pair, " keyboard=", keyboard)
		seed(106106)
		var global_next := randi()
		seed(106106)
		var id := await _earn(SIGHT_FIXTURE, pair, keyboard, "", true, pair[0])
		if id.is_empty():
			return
		_check(app.run_stitch_descriptors[id].cost == 2 and app.deck.hand.has(id),
			"earned Sight Glass composite is held at its shared cost two")
		var ledger := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)
		var preview := CombatStitchedTargetPreview.new().get_preview(ledger, app._stitch_snapshot(), app.deck, app.party, app.enemies, id)
		_check(preview.playable and preview.halves.size() == 2 and preview.halves[0].requires_selection
			and preview.halves[1].requires_selection, "Sight Glass half and Prick both need real enemy targets")
		if not preview.playable:
			return
		var living: Array = []
		for enemy in app.enemies.get_enemies():
			if enemy.hp > 0:
				living.append(enemy.position)
		_check(preview.halves[0].target_positions == living, "Sight Glass offers exactly the living enemy slots")
		var first: int = preview.halves[0].target_positions[0]
		var second: int = first if preview.halves[1].target_positions.has(first) else preview.halves[1].target_positions[0]
		_check(second == first and app.enemies.get_enemy(first).hp > 4,
			"Prick can strike the Sight Glass target, which survives it")
		var rng := RandomNumberGenerator.new()
		rng.state = app.run_rng.state
		var deck := CombatDeck.new([], rng)
		deck.hand.assign(app.deck.hand)
		deck.draw_pile.assign(app.deck.draw_pile)
		deck.discard_pile.assign(app.deck.discard_pile)
		deck.combat_state.energy = app.deck.energy
		deck.combat_state.player_turn_active = true
		var party := CombatParty.new(app.party.get_heroes())
		party._heroes = app.party.get_heroes()
		var enemies := CombatEnemies.new(app.enemies.get_enemies())
		enemies._enemies = app.enemies.get_enemies()
		var attacks := CombatAttackCards.new()
		attacks.start_player_turn()
		var expected := CombatStitchedCards.new(attacks).play_stitched(deck, party, enemies, ledger, id, first, second)
		_check(expected.ok and expected.halves.size() == 2, "independent scene-free Sight Glass composite succeeds")
		if not expected.ok:
			return
		# The ordinary gadget is the effect oracle: one loose Sight Glass over the
		# same piles, energy, actors and RNG state applies the same Exposed/draw.
		var loose_rng := RandomNumberGenerator.new()
		loose_rng.state = app.run_rng.state
		var loose := CombatDeck.new([], loose_rng)
		loose.hand.assign([pair[0]])
		loose.draw_pile.assign(app.deck.draw_pile)
		loose.discard_pile.assign(app.deck.discard_pile)
		loose.combat_state.energy = 3
		loose.combat_state.player_turn_active = true
		var loose_enemies := CombatEnemies.new(app.enemies.get_enemies())
		loose_enemies._enemies = app.enemies.get_enemies()
		var ordinary := CombatTinkerPoolGadgets.new().resolve_sight_glass(loose,
			CombatParty.new(app.party.get_heroes()), loose_enemies, pair[0], first)
		var sight: Dictionary = expected.halves[0]
		_check(ordinary.ok and sight == {"ok": true, "effect": "exposed_and_draw", "exposed_applied": ordinary.exposed_applied,
			"draw": 1, "drawn": ordinary.drawn, "target": first} and ordinary.exposed_applied == 2,
			"stitched Sight Glass half equals the ordinary gadget's Exposed and draw")
		var prick: Dictionary = expected.halves[1].hits[0]
		_check(prick.position == first and prick.statuses.get("bleed", 0) > 0
			and enemies.get_enemy(first).get("statuses", {}).get("exposed", 0) == 2,
			"Prick strikes the same foe after Sight Glass's Exposed")
		var hand_before: Array = app.deck.hand.duplicate()
		var energy_before: int = app.deck.energy
		var discard_before: Array = app.deck.discard_pile.duplicate()
		var draw_before: int = app.deck.draw_pile.size()
		var shared_service = presenter._play
		_check(not shared_service._tinker._consumed, "Tinker bonus is unspent before the physical cast")
		await _arm(id, keyboard)
		await _pick(first, "enemy", keyboard)
		await _pick(second, "enemy", keyboard)
		_check(presenter.last_event == expected, "physical Sight Glass composite event equals the exact oracle")
		_check([app.deck.hand, app.deck.draw_pile, app.deck.discard_pile, app.deck.energy, app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state]
			== [deck.hand, deck.draw_pile, deck.discard_pile, deck.energy, party.get_heroes(), enemies.get_enemies(), rng.state],
			"complete Sight Glass composite transition equals oracle")
		_check(app.deck.energy == energy_before - 2 and not app.deck.hand.has(id)
			and app.deck.hand.size() == hand_before.size() - 1 + ordinary.drawn
			and app.deck.discard_pile.back() == id and app.deck.discard_pile.count(id) == 1,
			"one energy charge, one Sight Glass draw and exactly one composite discard")
		_check(draw_before == 0 or app.deck.discard_pile.slice(0, -1) == discard_before,
			"no other card is discarded")
		_check(app.enemies.get_enemy(first).get("statuses", {}).get("exposed", 0) == 2, "live target carries exactly the printed Exposed")
		_check(presenter._play == shared_service and not shared_service._tinker._consumed and not attacks._tinker._consumed,
			"nonattack Sight Glass and Seamstress Prick leave Tinker's first-attack bonus unspent")
		var after := _complete_state()
		await _key(KEY_1 + first - 1)
		await _key(KEY_1 + first - 1)
		_check(_complete_state() == after, "repeated input after the Sight Glass cast is inert")
		var trace := [_snapshot(), presenter.last_event.duplicate(true), app._stitch_snapshot()]
		if replay.is_empty():
			replay = trace
		else:
			_check(trace == replay, "seeded mouse/keyboard Sight Glass composite replay")
		await _return()
		_check(randi() == global_next, "earned Sight Glass route and cast preserve global RNG")


func _knit_case(fixture: Dictionary) -> void:
	var replay: Array = []
	for keyboard in [false, true]:
		app.run_seed = fixture.seed
		await _click(app.start_button)
		preload("res://tests/party_choice.gd").choose(app, ["warden", "seamstress", "yarn_ranger"])
		await _frames()
		_check(app.run_map != null and app.run_rng != null and app.run_heroes[2].id == "yarn_ranger"
			and app.run_deck.has("yarn_ranger_hood_knit"), "real pick-three admits Ranger and authored starting deck")
		if app.run_map == null:
			return
		# Earn the same three-scrap purse from genuine mounted Fight/Elite rewards.
		for node_id in [fixture.fight, fixture.elite.back()]:
			await _click(_route_action(node_id))
			_check(app.deck != null and app.battle_result.can_continue(), "Ranger route mounts a real battle")
			for enemy in app.enemies.get_enemies():
				_check(app.enemies.apply_damage(enemy.position, 9999), "settle mounted Ranger fixture battle")
			app._observe_battle_result()
			await _frames()
			await _click(app.reward_buttons[3])
			await _click(app.continue_button)
		await _click(_legacy_rest_control(_route_action(fixture.rest.back())))
		_check(app.rest_stitch != null and app.run_scraps == 3, "Ranger reaches legitimate earned Rest stitch")
		if app.rest_stitch == null:
			return
		await _select_stitch(app.rest_stitch_first, app.run_deck.find("yarn_ranger_hood_knit"), keyboard)
		await _select_stitch(app.rest_stitch_second, app.run_deck.find("warden_brace"), keyboard)
		await _click(app.rest_stitch_button)
		_check(app.run_stitch_descriptors.size() == 1 and app.run_scraps == 0, "Rest sews genuine cross-owner knit composite")
		if app.run_stitch_descriptors.is_empty():
			return
		var id: String = app.run_stitch_descriptors.keys()[0]
		var receipt: Dictionary = app._stitch_snapshot().duplicate(true)
		await _click(app.rest_continue_button)
		await _click(_route_action(fixture.next))
		_check(app.deck != null and app.battle_result.can_continue() and app._stitch_snapshot() == receipt, "next routed Fight retains exact knit ledger")
		while not app.deck.hand.has(id) and not app.deck.draw_pile.is_empty():
			_check(app.deck.draw_extra(1) == 1, "draw genuinely sewn Ranger composite")
		app._refresh_hand()
		await _frames()
		_check(app.deck.hand.has(id) and _panel(id) != null, "knit composite actually mounted in shared hand")
		var ledger := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors, app.run_scraps, app.run_next_stitch_id)
		var preview := CombatStitchedTargetPreview.new().get_preview(ledger, receipt, app.deck, app.party, app.enemies, id)
		_check(preview.playable and preview.first_half.side == "ally" and preview.first_half.target_positions == [1, 2, 3], "mounted knit offers each living ally")
		if not preview.playable:
			return
		_check(not app.deck.draw_pile.is_empty() or not app.deck.discard_pile.is_empty(), "knit witness has a real shared draw available")
		await _arm(id, keyboard)
		app.run_scraps += 1
		var stale_before := _complete_state()
		await _pick(2, "ally", keyboard)
		_check(_complete_state() == stale_before, "stale knit receipt refuses Block, draw, spend and RNG atomically")
		app.run_scraps -= 1
		app._refresh_hand()
		await _frames()
		var before := _complete_state()
		var hand_before: Array = app.deck.hand.duplicate()
		var block_before: Array = [app.party.get_hero(1).block, app.party.get_hero(2).block, app.party.get_hero(3).block]
		var energy_before: int = app.deck.energy
		var oracle := _knit_draw_oracle(app.deck)
		await _arm(id, keyboard)
		_check(_complete_state() == before, "arming knit spends nothing")
		await _pick(2, "ally", keyboard)
		_check(presenter.last_event == {"ok": true, "halves": [
			{"ok": true, "effect": "block_and_draw", "amount": 4, "draw": 1, "drawn": 1},
			{"ok": true, "effect": "self_block", "amount": 7}]}, "physical knit ally selection commits both complete ordered halves")
		hand_before.erase(id)
		hand_before.append_array(oracle.drawn)
		_check(app.deck.hand == hand_before and app.deck.draw_pile == oracle.draw and app.deck.discard_pile == oracle.discard + [id]
			and app.run_rng.state == oracle.rng and app.deck.energy == energy_before - 2, "mounted knit draws one real card and pays/discards composite once")
		_check([app.party.get_hero(1).block, app.party.get_hero(2).block, app.party.get_hero(3).block]
			== [block_before[0] + 7, block_before[1] + 4, block_before[2]] and app._stitch_snapshot() == receipt, "only chosen ally gains knit Block; other half and retained ledger exact")
		var trace := [_snapshot(), presenter.last_event.duplicate(true), receipt]
		replay.append(trace)
		await _return()
	_check(replay[0] == replay[1], "mounted knit mouse/keyboard seeded replay")


func _knit_draw_oracle(deck: CombatDeck) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.state = deck._rng.state
	var draw: Array = deck.draw_pile.duplicate()
	var discard: Array = deck.discard_pile.duplicate()
	if draw.is_empty():
		draw = discard.duplicate()
		discard.clear()
		for index in range(draw.size() - 1, 0, -1):
			var other := rng.randi_range(0, index)
			var saved = draw[index]
			draw[index] = draw[other]
			draw[other] = saved
	var drawn: Array = []
	if not draw.is_empty():
		drawn.append(draw.pop_back())
	return {"draw": draw, "discard": discard, "drawn": drawn, "rng": rng.state}


func _finish_hand() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_stitched_hand_play_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

## Opening Fight reward -> authentic Rest stitch -> held hand. The plus setup
## uses the canonical upgrade transaction before Rest, not a forged descriptor.
const BUCKLE_FIXTURE := {"seed": 3354, "fight": "f01_n0", "elite": ["f02_n3"],
	"rest": ["f03_n2"], "next": "f04_n2"}
const WHIP_FIXTURE := {"seed": 1219, "fight": "f01_n0", "elite": ["f02_n1"],
	"rest": ["f03_n1"], "next": "f04_n1"}


func _plain_strike_cases() -> void:
	for base_id in ["warden_brass_buckle", "seamstress_thread_whip"]:
		var fixture: Dictionary = BUCKLE_FIXTURE if base_id.begins_with("warden_") else WHIP_FIXTURE
		var partner: String = "seamstress_prick" if base_id.begins_with("warden_") else "warden_shield_bash"
		for plus in [false, true]:
			var plain_id: String = base_id + ("_plus" if plus else "")
			var pair := [plain_id, partner]
			var replay: Array = []
			for keyboard in [false, true]:
				print("mounted plain strike: ", pair, " keyboard=", keyboard)
				seed(903377)
				var global_next := randi()
				seed(903377)
				var id := await _earn(fixture, pair, keyboard, "", true, base_id, plus)
				if id.is_empty():
					_check(false, "mounted earned pool composite setup " + plain_id)
					return
				await _restore_stitch_positions(id)
				var ledger := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors,
					app.run_scraps, app.run_next_stitch_id)
				var preview := CombatStitchedTargetPreview.new().get_preview(ledger,
					app._stitch_snapshot(), app.deck, app.party, app.enemies, id)
				_check(ledger.is_valid() and preview.get("playable", false) and preview.halves.size() == 2
					and preview.halves[0].card_id == plain_id and preview.halves[1].card_id == partner
					and preview.halves[0].target_positions == [1, 2],
					"mounted canonical pool half offers only original enemy slots 1-2: " + plain_id)
				if not preview.get("playable", false):
					return
				var a := 2
				var b := 1
				_check(app.enemies.get_enemy(a).hp > 0 and app.enemies.get_enemy(b).hp > 0
					and app.deck.hand.has(id) and app.deck.energy >= preview.cost,
					"real mounted living targets, held composite and paid energy preconditions")
				var rng := RandomNumberGenerator.new()
				rng.state = app.run_rng.state
				var deck := CombatDeck.new([], rng)
				deck.hand.assign(app.deck.hand)
				deck.draw_pile.assign(app.deck.draw_pile)
				deck.discard_pile.assign(app.deck.discard_pile)
				deck.combat_state.energy = app.deck.energy
				deck.combat_state.player_turn_active = true
				var party := CombatParty.new(app.party.get_heroes())
				party._heroes = app.party.get_heroes()
				var enemies := CombatEnemies.new(app.enemies.get_enemies())
				enemies._enemies = app.enemies.get_enemies()
				var attacks := CombatAttackCards.new()
				attacks.start_player_turn()
				var expected := CombatStitchedCards.new(attacks).play_stitched(deck, party, enemies,
					ledger, id, a, b)
				_check(expected.get("ok", false) and expected.halves.size() == 2,
					"independent paid composite resolver succeeds for " + plain_id)
				if not expected.get("ok", false):
					return
				var first: Dictionary = expected.halves[0]
				var second: Dictionary = expected.halves[1]
				var printed_damage := 7 if plus else 5
				var printed_block := 6 if plus else 4
				if not base_id.begins_with("warden_"):
					printed_damage = 8 if plus else 6
				_check(first.hits.size() == 1 and second.hits.size() == 1
					and first.hits[0].position == a and second.hits[0].position == b
					and first.hits[0].damage == printed_damage,
					"ordered first hit has printed 5/7 Buckle or 6/8 Whip damage")
				var expected_block: Dictionary = {_hero_position("warden"): printed_block} if base_id.begins_with("warden_") else {}
				_check(first.block_deltas == expected_block,
					"Brass Buckle grants exactly 4/6 Warden Block, Whip grants none")
				var before_hand: Array = app.deck.hand.duplicate()
				var before_discard: Array = app.deck.discard_pile.duplicate()
				var before_energy: int = app.deck.energy
				var before_warden_block: int = app.party.get_hero(_hero_position("warden")).block
				var stale = presenter._bindings[_panel(id)].input
				await _arm(id, keyboard)
				await _pick(a, "enemy", keyboard)
				await _pick(b, "enemy", keyboard)
				_check(presenter.last_event == expected,
					"physical mouse/keyboard ordered two-target receipt equals independent resolver")
				_check([app.deck.hand, app.deck.draw_pile, app.deck.discard_pile,
					app.deck.energy, app.party.get_heroes(), app.enemies.get_enemies(), app.run_rng.state]
					== [deck.hand, deck.draw_pile, deck.discard_pile, deck.energy,
					party.get_heroes(), enemies.get_enemies(), rng.state],
					"live ordered hits, passives, Block/statuses, piles and seeded RNG equal resolver")
				_check(app.deck.energy == before_energy - preview.cost and before_hand.count(id) == 1
					and not app.deck.hand.has(id) and app.deck.hand.size() == before_hand.size() - 1
					and app.deck.discard_pile == before_discard + [id],
					"one capped composite energy debit, no duplicate commit, one discard")
				_check(app.party.get_hero(_hero_position("warden")).block ==
					before_warden_block + (printed_block if base_id.begins_with("warden_") else 0),
					"live Warden Block obeys printed additive gain")
				var after := _complete_state()
				await _key(KEY_1)
				await _key(KEY_2)
				if stale.is_valid():
					var event := InputEventMouseButton.new()
					event.button_index = MOUSE_BUTTON_LEFT
					event.pressed = true
					stale.call(event)
				await _frames()
				_check(_complete_state() == after, "replayed keys and stale panel callback cannot recommit")
				var trace := [_snapshot(), presenter.last_event.duplicate(true), app._stitch_snapshot()]
				if replay.is_empty():
					replay = trace
				else:
					_check(trace == replay, "seeded mouse/keyboard full mounted plain-strike replay")
				await _return()
				_check(randi() == global_next, "mounted plain strike preserves global RNG")


## Seeded first Fight's real reward UI offers Scatter. The opening claim earns
## the base copy; the optional canonical upgrade service creates the + printing
## before the connected Rest stitches it with a different owner's real Brace.
const SCATTER_FIXTURE := {"seed": 1943, "fight": "f01_n0",
	"elite": ["f02_n0"], "rest": ["f03_n0"], "next": "f04_n3"}


func _scatter_area_cases() -> void:
	for plus in [false, true]:
		var area_id := "tinker_scatter_bolts_plus" if plus else "tinker_scatter_bolts"
		for reverse in [false, true]:
			var pair := ["warden_brace", area_id] if reverse else [area_id, "warden_brace"]
			var replay: Array = []
			for keyboard in [false, true]:
				print("mounted earned Scatter: ", pair, " keyboard=", keyboard)
				seed(80714)
				var global_next := randi()
				seed(80714)
				var id := await _earn(SCATTER_FIXTURE, pair, keyboard, "", true,
					"tinker_scatter_bolts", plus)
				if id.is_empty():
					_check(false, "opening reward/Rest/next Fight genuinely held Scatter " + area_id)
					return
				await _restore_stitch_positions(id)
				var ledger := RunRestStitchCards.new(app.run_deck, app.run_stitch_descriptors,
					app.run_scraps, app.run_next_stitch_id)
				var preview := CombatStitchedTargetPreview.new().get_preview(ledger,
					app._stitch_snapshot(), app.deck, app.party, app.enemies, id)
				var area_index: int = 1 if reverse else 0
				var slots: Array[int] = []
				for enemy in app.enemies.get_enemies():
					if enemy.hp > 0:
						slots.append(enemy.position)
				_check(ledger.is_valid() and app.deck.hand.has(id) and app.deck.energy >= 2
					and _hero_position("tinker") == 3 and slots.size() >= 2
					and preview.get("playable", false) and preview.halves.size() == 2,
					"real reward, upgraded printing, living back Tinker, held area and two foes")
				if not preview.get("playable", false):
					await _return()
					continue
				_check(app.run_stitch_descriptors[id].half_ids == pair
					and preview.cost == 2
					and preview.halves[area_index].target_kind == "enemy_all"
					and not preview.halves[area_index].requires_selection
					and preview.halves[area_index].target_positions.is_empty()
					and preview.halves[area_index].affected_positions == slots
					and not preview.halves[1 - area_index].requires_selection,
					"mounted stitched preview exposes zero selected targets and exact living slots")
				var receipt: Dictionary = app._stitch_snapshot()
				# A stale optimistic Rest receipt and a forged canonical record
				# cannot authorize a zero-target play through the actual hand.
				var stale_snapshot: Dictionary = receipt.duplicate(true)
				stale_snapshot.remaining_scraps += 1
				var refused_before := _complete_state()
				var rejected := CombatStitchedTargetPreview.new().get_preview(
					ledger, stale_snapshot, app.deck, app.party, app.enemies, id)
				_check(not rejected.get("playable", false)
					and _complete_state() == refused_before,
					"stale optimistic receipt rejects without touching live resources")
				var real_descriptors: Dictionary = app.run_stitch_descriptors.duplicate(true)
				app.run_stitch_descriptors[id]["first_half" if not reverse else "second_half"]["effects"]["damage"] = 99
				refused_before = _complete_state()
				await _click(_panel(id))
				_check(_complete_state() == refused_before,
					"physical forged Scatter half click cannot spend or damage")
				app.run_stitch_descriptors = real_descriptors
				app._refresh_hand()
				await _frames()
				# Authoritative Block/Exposed and wearer Weak travel through the
				# ordinary pool math, not a bespoke stitched damage calculation.
				_check(app.enemies.gain_block(slots[0], 3),
					"genuine enemy Block precondition in connected next Fight")
				_check(app.enemies.apply_statuses({slots[1]: {"exposed": 1}}),
					"genuine second enemy Exposed in connected next Fight")
				var wearer: int = _hero_position("tinker")
				app.party._heroes[wearer - 1]["statuses"] = {"weak": 1}
				app._refresh_party()
				app._refresh_enemy_roster()
				await _frames()
				var rng := RandomNumberGenerator.new()
				rng.state = app.run_rng.state
				var deck := CombatDeck.new([], rng)
				deck.hand.assign(app.deck.hand)
				deck.draw_pile.assign(app.deck.draw_pile)
				deck.discard_pile.assign(app.deck.discard_pile)
				deck.combat_state.energy = app.deck.energy
				deck.combat_state.player_turn_active = true
				var party := CombatParty.new(app.party.get_heroes())
				party._heroes = app.party.get_heroes()
				var enemies := CombatEnemies.new(app.enemies.get_enemies())
				enemies._enemies = app.enemies.get_enemies()
				var attacks := CombatAttackCards.new()
				attacks.start_player_turn()
				_check(not presenter._play._tinker._consumed,
					"connected next Fight leaves Tinker first-attack opportunity unspent")
				var expected := CombatStitchedCards.new(attacks).play_stitched(deck, party,
					enemies, ledger, id, 0, 0)
				_check(expected.get("ok", false) and expected.halves.size() == 2,
					"detached stitched oracle resolves both authentic reward halves")
				if not expected.get("ok", false):
					await _return()
					continue
				var oracle_rng := RandomNumberGenerator.new()
				oracle_rng.state = app.run_rng.state
				var pool_deck := CombatDeck.new([area_id], oracle_rng)
				_check(pool_deck.start_turn() and pool_deck.hand.has(area_id),
					"independent ordinary pool card genuinely drawn into held oracle")
				var pool_party := CombatParty.new(app.party.get_heroes())
				pool_party._heroes = app.party.get_heroes()
				var pool_enemies := CombatEnemies.new(app.enemies.get_enemies())
				pool_enemies._enemies = app.enemies.get_enemies()
				var ordinary := CombatTinkerPoolAttacks.new().play_attack(
					pool_deck, pool_party, pool_enemies, area_id, 0)
				_check(ordinary.get("ok", false) and ordinary.hits.size() == slots.size()
					and expected.halves[area_index] == ordinary
					and enemies.get_enemies() == pool_enemies.get_enemies(),
					"staged area and detached ordinary pool hit same original living slots with Weak/Block/Exposed")
				var before := _complete_state()
				var hand_before: Array = app.deck.hand.duplicate()
				var draw_before: Array = app.deck.draw_pile.duplicate()
				var discard_before: Array = app.deck.discard_pile.duplicate()
				var energy_before: int = app.deck.energy
				var rng_before: int = app.run_rng.state
				var shared = presenter._play
				await _arm(id, keyboard)
				if keyboard and presenter._armed != null:
					await _key(KEY_SPACE)
				_check(presenter.last_event == expected,
					"real mouse/keyboard zero-target hand input commits both ordered Scatter halves")
				_check([app.deck.hand, app.deck.draw_pile, app.deck.discard_pile,
					app.deck.energy, app.party.get_heroes(), app.enemies.get_enemies(),
					app.run_rng.state] == [deck.hand, deck.draw_pile, deck.discard_pile,
					deck.energy, party.get_heroes(), enemies.get_enemies(), rng.state],
					"complete mounted outcome equals detached stitched transaction")
				_check(app.enemies.get_enemies() == pool_enemies.get_enemies()
					and app.deck.energy == energy_before - 2
					and app.deck.draw_pile == draw_before and app.run_rng.state == rng_before
					and app.deck.hand.size() == hand_before.size() - 1
					and not app.deck.hand.has(id)
					and app.deck.discard_pile == discard_before + [id]
					and presenter._play == shared and shared._tinker._consumed
					and app._stitch_snapshot() == receipt,
					"ordinary area damage, no draw/RNG drift, one shared payment/discard and Tinker latch")
				var trace := [_snapshot(), presenter.last_event.duplicate(true), app._stitch_snapshot()]
				if replay.is_empty():
					replay = trace
				else:
					_check(trace == replay, "same seeded mouse/keyboard reward-to-Fight replay for " + area_id)
				await _return()
				_check(randi() == global_next, "earned stitched Scatter consumes no global RNG")
