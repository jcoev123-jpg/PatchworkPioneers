extends "res://tests/live_elite_reward_continuation_test.gd"
## Physical routed Shop transactions, persistent wardrobe and complete rejection guards.

var wardrobe: RunPatchWardrobe


func _fund_shop_fixture() -> void:
	app.session_gold = 500
	# Capture the explicit test wallet in genuine route controls before transit.
	# Campfire, like the other sewn visits, rejects stale source snapshots.
	app._clear_route_view()
	app._present_connected_route(weakref(app.run_map))
	_check(not app.route_buttons.is_empty() and app._can_choose_connected_route(),
		"funded fixture has a fresh authenticated connected chooser")

const PREVIEW_POWERS := {
	"stitched_badge": {"slot": "HEAD", "effect": "opening_block_bonus", "amount": 3,
		"text": "+3 opening Block for this living wearer (stacks with innate Block)"},
	"spare_spool": {"slot": "ARM", "effect": "healing_card_bonus", "amount": 2,
		"text": "+2 healing on positive-heal cards owned by this living wearer only"},
	"quilted_coat": {"slot": "COAT", "max_hp_bonus": 6, "text": "+6 maximum HP"},
	"button_eye": {"slot": "HEAD", "effect": "first_attack_exposed", "amount": 1,
		"text": "first successful attack each combat also applies Exposed 1"},
	"pincushion_arm": {"slot": "ARM", "effect": "card_attack_bonus", "amount": 1,
		"text": "+1 damage on that wearer's damaging cards"},
	"switchback_button": {"slot": "HEAD", "effect": "different_owner_followup_block", "amount": 2, "once_per_player_turn": true, "text": "Once per player turn, when a different living hero's committed card or stitched half (ordered first then second) immediately precedes this living wearer's committed card or half, this wearer gains 2 Block; same-owner repeats and rejected plays never set it up."},
	"padded_vest": {"slot": "COAT", "max_hp_bonus": 4, "text": "+4 maximum HP"},
	"double_quilt_coat": {"slot": "COAT", "max_hp_bonus": 8, "text": "+8 maximum HP"},
	"scrap_lined_vest": {"slot": "COAT", "max_hp_bonus": 3, "text": "+3 maximum HP"},
	"wool_patch_cloak": {"slot": "COAT", "max_hp_bonus": 5, "text": "+5 maximum HP"},
	"chain_stitched_coat": {"slot": "COAT", "max_hp_bonus": 7, "text": "+7 maximum HP"},
	"reinforced_patchcoat": {"slot": "COAT", "max_hp_bonus": 9, "text": "+9 maximum HP"},
	"thick_felt_mantle": {"slot": "COAT", "max_hp_bonus": 10, "text": "+10 maximum HP"},
	"bloodstitch_bonnet": {"slot": "HEAD", "effect": "card_bleed_bonus", "amount": 1, "text": "+1 Bleed on eligible Bleed cards owned by this living wearer only"},
	"button_glass_visor": {"slot": "HEAD", "effect": "card_exposed_bonus", "amount": 1, "text": "+1 Exposed on eligible Exposed cards owned by this living wearer only"},
	"stern_seam_cap": {"slot": "HEAD", "effect": "card_weak_bonus", "amount": 1, "text": "+1 Weak on eligible Weak cards owned by this living wearer only"},
	"reinforced_browband": {"slot": "HEAD", "effect": "card_block_bonus", "amount": 2, "text": "+2 Block on eligible Block cards owned by this living wearer only"},
	"hemguard_cuff": {"slot": "ARM", "effect": "card_block_bonus", "amount": 2, "text": "+2 Block on eligible Block cards owned by this living wearer only"},
	"red_bobbin_cuff": {"slot": "ARM", "effect": "card_bleed_bonus", "amount": 1, "text": "+1 Bleed on eligible Bleed cards owned by this living wearer only"},
	"loose_thread_glove": {"slot": "ARM", "effect": "card_unravel_bonus", "amount": 1, "text": "+1 Unravel on eligible Unravel cards owned by this living wearer only"},
	"threadguard_wrap": {"slot": "ARM", "effect": "card_block_bonus", "amount": 1, "text": "+1 Block on this living wearer's cards that already grant Block; never on a card without Block."},
	"frayfinder_mitt": {"slot": "ARM", "effect": "first_single_target_half_unravel_attack_bonus", "amount": 2, "minimum_unravel_numerator": 1, "minimum_unravel_denominator": 2, "once_per_player_turn": true, "hit_number": 1, "target_kind": "enemy_single", "text": "+2 attack damage once per player turn on this living wearer's first confirmed single-target hit against an enemy already at half its current Unravel threshold; no bonus on area or later hits."},
	"borrowed_button": {"slot": "COAT", "effect": "other_hero_committed_heal_block", "heal_threshold": 1, "block": 3, "uses_per_combat": 1, "text": "Once per combat, when another living hero's committed card or stitched half restores at least 1 HP to this living wearer, gain 3 Block."},
	"relay_bobbin": {"slot": "HEAD", "effect": "different_hero_pinned_token_shared_energy", "uses_per_combat": 1,
		"text": "Once per combat, if a different living hero consumes a Pinned token placed by this living, untorn wearer (confirmed receipt), gain +1 shared energy, capped at 3."},
	"hearth_lining": {"slot": "COAT", "effect": "earned_quilt_bonus_wearer_heal", "uses_per_combat": 1,
		"text": "Once per combat, at the first EARNED Quilt bonus, heal this living, untorn wearer 2 HP, up to maximum HP."},
}


## Use the acquired patch through the next battle's real held-card input.
func _acquired_attack_check(patch_id: String) -> void:
	_check(app.party != null and app.enemies != null and not app._battle_closed
		and app.party.get_hero(1).id == "warden" and not app.party.is_downed(1),
		"acquired patch reaches a living Warden in a real later battle")
	for id in ["seamstress_prick", "warden_strike"]:
		while not app.deck.hand.has(id) and not app.deck.draw_pile.is_empty():
			_check(app.deck.draw_extra(1) == 1, "draw real owned attack")
		_check(app.deck.hand.has(id), "real deck contains " + id)
	app._refresh_hand()
	await _frames()
	var rng: int = app.run_rng.state
	for id in ["seamstress_prick", "warden_strike"]:
		var cost: int = StarterCards.new().get_definition(id).cost
		var energy: int = app.deck.energy
		var copies: int = app.deck.hand.count(id)
		var discarded: int = app.deck.discard_pile.count(id)
		_check(await _choose(id, false), "physically select acquired-patch attack " + id)
		await _key(KEY_1)
		var event: Dictionary = presenter.last_event
		var damage := 3 if id == "seamstress_prick" else (7 if patch_id == "pincushion_arm" else 6)
		var statuses := {"bleed": 3} if id == "seamstress_prick" else ({"exposed": 1} if patch_id == "button_eye" else {})
		_check(event.get("ok") == true and event.get("hits", []).size() == 1,
			"acquired patch attack actually commits")
		if event.get("ok") == true and event.get("hits", []).size() == 1:
			_check(event.hits[0].damage == damage and event.hits[0].statuses == statuses,
				"only living wearer receives exact authored acquired patch effect")
		_check(app.deck.energy == energy - cost and app.deck.hand.count(id) == copies - 1
			and app.deck.discard_pile.count(id) == discarded + 1 and app.run_rng.state == rng,
			"acquired patch attack spends and discards once without RNG")

## Search actual seeded stock, never replace its candidate pool or listings.
func _attack_patch_purchases() -> void:
	var slots := RunAuthoredPatchDefinitions.load_definitions()
	for target in ["stitched_badge", "spare_spool", "quilted_coat", "button_eye", "pincushion_arm", "HEAD", "ARM", "COAT"]:
		var fixture: Dictionary = {}
		var next_seed: int = {"stitched_badge": 3841, "spare_spool": 2927, "quilted_coat": 40281, "button_eye": 4640, "pincushion_arm": 18695, "HEAD": 4752, "ARM": 1060, "COAT": 2255}.get(target, 1)
		var found := false
		for attempt in range(240):
			fixture = _sequence_fixture(["Shop", "Fight"], next_seed)
			if fixture.is_empty():
				break
			if not await _routed_win(fixture, false):
				# A re-split floor band can make one authentic seed's opening
				# fight unwinnable for this fixture; move to the next genuine
				# seed instead of abandoning the target. Outcomes are never
				# injected: the stock below is still rolled by the real service.
				next_seed = fixture.seed + 1
				app._return_to_title()
				await _frames()
				continue
			await _click(app.reward_buttons[3])
			await _click(app.continue_button)
			_fund_shop_fixture()
			await _reach(fixture.paths[0], false)
			var id: String = app.peddler_visit.read_state().stock.trinkets[0].id
			var slot: String = app._peddler_wardrobe.get_snapshot().definitions[id]
			found = id == target or (target in RunPatchWardrobe.SLOTS and slot == target
				and id not in ["stitched_badge", "spare_spool", "quilted_coat", "button_eye", "pincushion_arm"])
			if found:
				break
			next_seed = fixture.seed + 1
			app._return_to_title()
			await _frames()
		_check(found, "genuine seeded Peddler stocks " + target)
		if not found:
			return
		wardrobe = app._peddler_wardrobe
		var id: String = app.peddler_visit.read_state().stock.trinkets[0].id
		var callback: Callable = app.peddler_buttons[3].pressed.get_connections()[0].callable
		_candidate_contract_checks()
		_negative_inputs(callback)
		await _purchase(0, target in ["ARM", "COAT", "button_eye"], 0)
		await _reach(fixture.paths[1], false)
		_check(app.party_carryover._wardrobe == wardrobe and app._current_carryover_fight(), "purchased patch reaches real next Fight")
		if id in ["button_eye", "pincushion_arm"]:
			await _acquired_attack_check(id)
		app._return_to_title()
		await _frames()
		_retained_call(callback)
		_check(app.peddler_visit == null and app._peddler_wardrobe == null and app.run_map == null, "title reset rejects old patch Buy")


func _check_preview() -> void:
	_check_patch_action()
	var stock: Array = app.peddler_visit.read_state().stock.trinkets
	var index: int = app.shop_patch_offers.selected
	_check(not stock.is_empty() and index >= 0 and index < stock.size()
		and is_instance_valid(app.shop_patch_preview), "preview has genuine selected stock and mounted label")
	if index < 0 or index >= stock.size() or not is_instance_valid(app.shop_patch_preview):
		return
	var offer: Dictionary = stock[index]
	_check(PREVIEW_POWERS.has(offer.id), "seeded stock contains a named authored candidate")
	if not PREVIEW_POWERS.has(offer.id):
		return
	var expected: Dictionary = PREVIEW_POWERS[offer.id]
	var record: Dictionary = {}
	for path in RunAuthoredPatchDefinitions.CATALOG_PATHS:
		for entry in JSON.parse_string(FileAccess.get_file_as_string(path)):
			if entry.id == offer.id:
				record = entry
	if CombatShopPatchRules.EFFECTS.has(offer.id):
		record = CombatShopPatchRules.EFFECTS[offer.id]
	_check(not record.is_empty() and record.get("slot") == expected.slot
		and wardrobe.get_snapshot().definitions.get(offer.id) == expected.slot,
		"preview oracle slot agrees with shipped record and wardrobe")
	for field in ["effect", "amount", "max_hp_bonus", "once_per_player_turn", "minimum_unravel_numerator", "minimum_unravel_denominator", "hit_number", "target_kind", "heal_threshold", "block", "uses_per_combat"]:
		if expected.has(field):
			_check(record.get(field) == expected[field], "preview oracle matches authored " + field)
	var text := "%s (%s slot)%s\nEffect: %s\nInactive while wearer is torn." % [
		String(offer.id).capitalize(), String(expected.slot).capitalize(),
		" (SOLD)" if offer.sold else "", expected.text]
	_check(app.shop_patch_preview.text == text and app.shop_patch_preview.is_visible_in_tree()
		and app.shop_patch_preview.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"visible autowrapped preview gives exact conditional name, slot and power")
	_check(Rect2(0, 0, 1280, 720).encloses(app.shop_patch_preview.get_global_rect()),
		"preview fits target viewport")



func _sequence_fixture(kinds: Array, first_seed: int = 1, direct_last: bool = false) -> Dictionary:
	for value in range(first_seed, first_seed + 30000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for first in map.get_legal_choices():
			if map.get_node(first).type != "Fight":
				continue
			var paths := []
			var source: String = first
			for kind in kinds:
				var path := _path_to(map, source, kind)
				if direct_last and paths.size() == kinds.size() - 1:
					path = []
					for next in map.get_node(source).outgoing:
						if map.get_node(next).type == kind:
							path = [next]
							break
				if path.is_empty():
					break
				paths.append(path)
				source = path.back()
			if paths.size() != kinds.size():
				continue
			if direct_last and paths.back().size() != 1:
				continue
			map.choose_node(first)
			var entry := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
			if entry.get("encounter_id") == "starter_attacks":
				return {"seed": value, "fight": first, "paths": paths}
	return {}


func _patch_state() -> Array:
	return [app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.run_trinkets.duplicate(),
		app.session_gold, app.run_scraps, app.run_removal_count, app.run_rng.state,
		app.run_map.get_route(), app.run_map.get_floors(), app.party_carryover.read_state(),
		app.party_carryover.torn.read_state(), app.party_carryover._receipts.duplicate(true),
		app.peddler_visit.read_state(), app.peddler_receipt.duplicate(true), app.peddler_visit.read_state().stock,
		wardrobe.get_snapshot(), app.party_carryover._wardrobe]


func _reject_buy(callback: Callable, reason: String) -> void:
	var before := _patch_state()
	_retained_call(callback)
	_check(_patch_state() == before, reason + " leaves all ledgers, history and RNG unchanged")


func _check_patch_labels() -> void:
	var stock: Array = app.peddler_visit.read_state().stock.trinkets
	var definitions: Dictionary = wardrobe.get_snapshot().definitions
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/shop/initial_offers.json"))
	_check(stock.size() == 2 and app.shop_patch_offers.item_count == stock.size(),
		"mounted Shop labels cover both genuine stock offers")
	var names := {"stitched_badge": "Stitched Badge", "spare_spool": "Spare Spool",
		"quilted_coat": "Quilted Coat"}
	for i in range(stock.size()):
		var offer: Dictionary = stock[i]
		var candidates: Array = authored.trinkets.filter(func(candidate): return candidate.id == offer.id)
		_check(candidates.size() == 1 and offer.price == candidates[0].price,
			"genuine selected stock price agrees with authored catalog")
		_check(definitions.has(offer.id) and definitions[offer.id] in RunPatchWardrobe.SLOTS,
			"real stock has an authoritative wardrobe slot")
		var expected := "%s (%s slot)" % [names.get(offer.id, String(offer.id).capitalize()),
			String(definitions.get(offer.id)).capitalize()]
		_check(app.shop_patch_offers.get_item_text(i) == expected
			and not app.shop_patch_offers.get_item_text(i).contains("_")
			and not app.shop_patch_offers.get_item_text(i).contains("|")
			and app.shop_patch_offers.get_item_metadata(i) == offer.id,
			"exact readable name, explicit genuine slot and authentic ID metadata")
	_check_patch_action()


func _check_patch_action() -> void:
	var stock: Array = app.peddler_visit.read_state().stock.trinkets
	var index: int = app.shop_patch_offers.selected
	_check(index >= 0 and index < stock.size(), "action has an authentic selected offer")
	if index < 0 or index >= stock.size():
		return
	var offer: Dictionary = stock[index]
	var expected := "Buy & sew — %d gold" % offer.price
	if offer.sold:
		expected = "SOLD — %d gold" % offer.price
	elif app.session_gold < offer.price:
		expected += " (insufficient gold)"
	_check(app.shop_patch_buy_button.text == expected
		and app.shop_patch_buy_button.disabled == (offer.sold or app.session_gold < offer.price),
		"selected stock sets exact truthful price/status and enabled state")
	var button: Button = app.shop_patch_buy_button
	var font := button.get_theme_font("font")
	var font_size := button.get_theme_font_size("font_size")
	_check(font != null and font_size >= 18 and button.is_visible_in_tree(),
		"caption clearance uses the mounted readable font")
	var caption := font.get_string_size(expected, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var face := button.get_theme_stylebox(state)
		_check(face.get_content_margin(SIDE_LEFT) >= LiveVisitCardTiles.ACTION_PADDING_X
			and face.get_content_margin(SIDE_RIGHT) >= LiveVisitCardTiles.ACTION_PADDING_X
			and caption.x + face.get_minimum_size().x <= button.size.x
			and caption.y + face.get_minimum_size().y <= button.size.y,
			"exact selected caption clears sewn padding in " + state + ": " + expected)


func _check_equipment_layout() -> void:
	var panel := app.shop_view.get_node_or_null("ShopPatchSewing") as PanelContainer
	_check(panel != null, "real Shop mounts one equipment PanelContainer")
	if panel == null:
		return
	_check(app.shop_view.find_children("ShopPatchSewing", "PanelContainer", false, false).size() == 1,
		"exactly one local equipment backing")
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(style != null and style == app.theme.get_stylebox("panel", "PanelContainer")
		and style.draw_center and style.bg_color.a == 1.0,
		"equipment inherits installed opaque felt panel style")
	var heading := panel.find_child("EquipmentHeading", true, false) as Label
	_check(heading != null and heading.text == "Equipment — sewing included"
		and heading.theme_type_variation == &"PatchHeading", "concise equipment heading explains included sewing")
	var content := heading.get_parent() as VBoxContainer
	var selectors := app.shop_patch_offers.get_parent() as HBoxContainer
	var button: Button = app.shop_patch_buy_button
	_check(content != null and selectors != null and selectors.get_parent() == content
		and selectors.get_children() == [app.shop_patch_offers, app.shop_patch_heroes]
		and button.get_parent() == content and button.get_index() == selectors.get_index() + 1
		and app.shop_patch_preview.get_parent() == content,
		"existing equipment column gives the action its own row after both selectors")
	_check(is_equal_approx(button.size.x, content.size.x)
		and button.size.y >= 48 and button.custom_minimum_size.y >= 48,
		"sewn action fills the equipment content width with comfortable height")
	_check_patch_action()
	var controls: Array[Control] = [app.shop_patch_offers, app.shop_patch_heroes,
		app.shop_patch_buy_button, app.shop_patch_preview]
	for control in controls:
		_check(panel.is_ancestor_of(control) and control.is_visible_in_tree()
			and panel.get_global_rect().encloses(control.get_global_rect())
			and Rect2(0, 0, 1280, 720).encloses(control.get_global_rect())
			and control.get_theme_font_size("font_size") >= 18,
			"readable equipment child contained in local panel and viewport: " + control.name)
	_check(Rect2(0, 0, 1280, 720).encloses(panel.get_global_rect())
		and not panel.get_global_rect().intersects(app.shop_remove_button.get_global_rect())
		and not panel.get_global_rect().intersects(app.peddler_leave_button.get_global_rect()),
		"local felt backing fits viewport clear of adjacent actions")
	for i in range(3):
		var control: Control = controls[i]
		_check(control.size.x >= control.get_minimum_size().x and control.size.y >= control.get_minimum_size().y,
			"equipment caption is not truncated")
	app.shop_remove_button.grab_focus()
	for control in controls.slice(0, 3):
		await _key(KEY_TAB)
		_check(control.has_focus(), "physical Tab reaches each equipment action in order")
	await _key(KEY_TAB)
	_check(app.peddler_leave_button.has_focus(), "physical Tab exits equipment to Continue")
	for control in [app.shop_patch_buy_button, app.shop_patch_heroes, app.shop_patch_offers, app.shop_remove_button]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.shift_pressed = true
		event.pressed = true
		root.push_input(event, true)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event, true)
		await _frames()
		_check(control.has_focus(), "physical reverse Tab traverses equipment actions")


func _activate(control: Control, keyboard: bool) -> void:
	if keyboard:
		control.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(control)


func _reach(path: Array, keyboard: bool) -> void:
	var transit := path.duplicate()
	var destination: String = transit.pop_back()
	await _visit_path(transit, keyboard)
	await _activate(_route_action(destination), keyboard)


func _settle_battle(keyboard: bool, down_position: int = 0, reward_index: int = 3) -> void:
	_check(app.party != null and app.enemies != null and not app._battle_closed,
		"connected combat fixture has real live actors")
	if down_position > 0:
		_check(app.party.apply_damage(down_position, 9999), "genuine combat downs wearer")
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 9999), "defeat genuine mounted enemy")
	app._observe_battle_result()
	await _frames()
	_check(app.reward_buttons.size() == 4, "genuine victory offers reward and Skip")
	if app.reward_buttons.size() == 4:
		await _activate(app.reward_buttons[reward_index], keyboard)
	_check(app.fight_reward_claimed and is_instance_valid(app.continue_button), "reward commits once")


func _negative_inputs(callback: Callable) -> void:
	var bound: Dictionary = app.peddler_visit.read_state()
	var id: String = bound.stock.trinkets[0].id
	var button: Button = app.peddler_buttons[3]
	for control in [button, app.peddler_heroes]:
		var disabled: bool = control.disabled
		control.disabled = true
		_reject_buy(callback, "disabled control")
		control.disabled = disabled
		control.hide()
		_reject_buy(callback, "hidden control")
		control.show()
	var text := button.text
	button.text = "Counterfeit Patch 1 gold"
	_reject_buy(callback, "forged name and quote")
	button.text = text
	for forged in ["unstocked", String(id).capitalize(), 12, null]:
		button.set_meta("offer_id", forged)
		_reject_buy(callback, "forged offer metadata")
	button.set_meta("offer_id", id)
	app.peddler_heroes.set_item_metadata(0, "foreign")
	_reject_buy(callback, "foreign hero")
	app.peddler_heroes.set_item_metadata(0, app.run_heroes[0].id)
	app.peddler_heroes.select(-1)
	_reject_buy(callback, "missing owner selection")
	app.peddler_heroes.select(0)
	var slot: String = wardrobe._definitions[id]
	for invalid in ["UNKNOWN", "COAT" if slot != "COAT" else "HEAD"]:
		wardrobe._definitions[id] = invalid
		_reject_buy(callback, "drifted authored slot")
	wardrobe._definitions.erase(id)
	_reject_buy(callback, "missing slot")
	wardrobe._definitions[id] = slot
	app.session_gold += 1
	_reject_buy(callback, "drifted wallet")
	app.session_gold -= 1
	app.run_scraps += 1
	_reject_buy(callback, "drifted scraps")
	app.run_scraps -= 1
	app.run_deck.append("warden_strike")
	_reject_buy(callback, "drifted deck")
	app.run_deck.pop_back()
	app.run_heroes[0].hp -= 1
	_reject_buy(callback, "drifted roster")
	app.run_heroes[0].hp += 1
	app.peddler_visit._purchases._state.gold += 1
	_reject_buy(callback, "drifted paid ledger")
	app.peddler_visit._purchases._state.gold -= 1
	wardrobe._gold += 1
	_reject_buy(callback, "drifted wardrobe")
	wardrobe._gold -= 1
	wardrobe._operations.append("foreign-operation")
	_reject_buy(callback, "changed operation history")
	wardrobe._operations.pop_back()
	var rng: int = app.run_rng.state
	app.run_rng.randi()
	_reject_buy(callback, "drifted RNG")
	app.run_rng.state = rng
	var map: RunMap = app.run_map
	var other := RunMap.new()
	other._floor_ids = map._floor_ids.duplicate(true)
	other._nodes = map._nodes.duplicate(true)
	other._route.assign(map.get_route())
	app.run_map = other
	_reject_buy(callback, "foreign same-graph map")
	app.run_map = map
	var node := map.get_current_node_id()
	map._nodes[node].outgoing.append("foreign")
	_reject_buy(callback, "graph drift")
	map._nodes[node].outgoing.pop_back()
	map._route.pop_back()
	_reject_buy(callback, "stale route")
	map._route.append(node)
	app.shop_view.hide()
	_reject_buy(callback, "hidden view")
	app.shop_view.show()
	var view: Control = app.shop_view
	var foreign_view := VBoxContainer.new()
	app.shop_view = foreign_view
	_reject_buy(callback, "replaced view")
	app.shop_view = view
	foreign_view.free()
	var carry: RunTornCarryover = app.party_carryover
	var previous := carry._wardrobe
	carry._wardrobe = RunPatchWardrobe.new()
	_reject_buy(callback, "incompatible carry binding")
	carry._wardrobe = previous


func _purchase(index: int, keyboard: bool, wearer: int = -1) -> void:
	_check(index == 0 and app.peddler_visit != null and app.peddler_visit.is_open(), "single authentic patch offer is open")
	if wearer < 0:
		wearer = 0
	var bound: Dictionary = app.peddler_visit.read_state()
	var offer: Dictionary = bound.stock.trinkets[index]
	var before := _patch_state()
	var w := wardrobe.get_snapshot()
	_check(not offer.sold and app.session_gold >= offer.price, "genuine patch offer is affordable and unsold")
	await _pick(app.peddler_heroes, wearer, keyboard)
	var button: Button = app.peddler_buttons[3]
	var callback: Callable = button.pressed.get_connections()[0].callable
	if keyboard:
		button.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(button)
	var state := wardrobe.get_snapshot()
	var owner: String = app.run_heroes[wearer].id
	var slot: String = state.definitions[offer.id]
	var displaced: String = w.worn[owner][slot]
	var expected_owned: Array = w.owned.duplicate() + [offer.id]
	if displaced != "":
		expected_owned.erase(displaced)
	var expected_worn: Dictionary = w.worn.duplicate(true)
	expected_worn[owner][slot] = offer.id
	_check(state.worn == expected_worn and state.owned == expected_owned and app.run_trinkets == expected_owned
		and state.scraps == w.scraps + (1 if displaced != "" else 0) and app.run_scraps == state.scraps,
		"atomic sewing changes only recipient slot, destroys only displaced patch and grants exact scrap")
	_check(app.session_gold == w.gold - offer.price and state.gold == app.session_gold
		and app.run_deck == w.cards and app.run_rng.state == before[6]
		and state.operation_ids == w.operation_ids + ["peddler:%s" % bound.node_id],
		"one exact debit and fresh operation, unchanged deck and RNG")
	var expected_stock: Dictionary = bound.stock.duplicate(true)
	expected_stock.trinkets[0].sold = true
	_check(app.peddler_receipt == {"ok": true, "node_id": bound.node_id, "decision": "buy",
		"kind": "trinket", "id": offer.id, "price": offer.price, "stock": expected_stock,
		"state": {"party_ids": bound.state.party_ids, "deck": w.cards,
			"trinkets": expected_owned, "gold": state.gold}}, "exact settled service receipt publishes once")
	_check(app.peddler_visit.is_consumed() and app.shop_view == null and app._can_choose_connected_route()
		and app.party_carryover._wardrobe == wardrobe, "paid patch closes UI and authentic wardrobe admits onward route")
	_reject_buy(callback, "retired patch Buy")


func _pick(picker: OptionButton, index: int, keyboard: bool) -> void:
	await _activate(picker, keyboard)
	var popup := picker.get_popup()
	_check(popup.visible, "physical input opens real patch/hero popup")
	if keyboard:
		var focused := popup.get_focused_item()
		_check(focused >= 0 and focused < picker.item_count, "opened popup has a real keyboard focus item")
		for step in range(absi(index - focused)):
			await _key(KEY_DOWN if index > focused else KEY_UP)
		await _key(KEY_ENTER)
	else:
		var point := Vector2(popup.position) + Vector2(popup.size.x * 0.5,
			popup.size.y * (index + 0.5) / picker.item_count)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, true)
		await _frames()
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event, true)
		await _frames()
	_check(picker.selected == index and not popup.visible,
		"physical popup selects exact real item (keyboard=%s expected=%d actual=%d open=%s)" % [
			keyboard, index, picker.selected, popup.visible])


func _poor_and_replacement() -> void:
	var fixture := _sequence_fixture(["Shop"])
	_check(not fixture.is_empty(), "real route supports poor and replacement Peddler")
	for funded in [false, true]:
		if fixture.is_empty() or not await _routed_win(fixture, false):
			return
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		var old_patch := ""
		if funded:
			_fund_shop_fixture()
			var definitions := RunAuthoredPatchDefinitions.load_definitions()
			for prior in definitions:
				app.run_trinkets.assign([prior.id])
				var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
				var rng := RandomNumberGenerator.new()
				rng.state = app.run_rng.state
				var sample := RunShopStockOffers.generate_peddler_stock(rng, ["warden", "seamstress", "tinker"], authored.cards, authored.trinkets, app.run_trinkets)
				if sample.ok and sample.patches[0].id != prior.id and PREVIEW_POWERS[sample.patches[0].id].slot == prior.slot:
					old_patch = prior.id
					break
			_check(not old_patch.is_empty(), "genuine sample offers distinct patch for occupied slot")
			if old_patch.is_empty():
				return
			wardrobe = RunPatchWardrobe.new(app.run_heroes, app.run_trinkets, definitions, app.run_scraps, app.session_gold, app.run_deck, app.run_seed, true)
			_check(wardrobe.sew(old_patch, "warden", wardrobe.get_snapshot().definitions[old_patch], "prior-wear", wardrobe.get_snapshot()).ok, "prior owned patch is authentically sewn")
			_check(app.party_carryover.bind_wardrobe(wardrobe, app.party_carryover.torn, wardrobe.get_snapshot()), "carryover binds prior sewing")
		await _reach(fixture.paths[0], false)
		wardrobe = app._peddler_wardrobe
		if funded:
			await _purchase(0, true, 0)
			_check(not wardrobe.get_snapshot().owned.has(old_patch) and not app.peddler_visit.read_state().state.trinkets.has(old_patch), "destroyed patch cannot resurrect from upstream ledger")
		else:
			var button: Button = app.peddler_buttons[3]
			var callback: Callable = button.pressed.get_connections()[0].callable
			_check(button.disabled and app.session_gold < app.peddler_visit.read_state().stock.trinkets[0].price, "natural wallet cannot afford patch")
			var before := _patch_state()
			await _click(button)
			button.grab_focus()
			await _key(KEY_ENTER)
			button.disabled = false
			_retained_call(callback)
			_check(_patch_state() == before and app.peddler_visit.is_open(), "shortfall refuses mouse, keyboard and forced callback with no mutation")
			await _click(app.peddler_leave_button)
		app._return_to_title()
		await _frames()


func _unsewn_elite_before_shop() -> void:
	var fixture := _sequence_fixture(["Elite", "Shop", "Elite"])
	_check(not fixture.is_empty(), "real path supports skipped Elite sew before Shop and later Elite")
	if fixture.is_empty() or not await _routed_win(fixture, false):
		return
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	_fund_shop_fixture()
	await _reach(fixture.paths[0], false)
	await _settle_battle(false)
	var sewing = app.get_node("LiveElitePatchSewing")
	_check(sewing.wardrobe != null and sewing.hero_buttons.size() == 3
		and app.party_carryover._wardrobe == null,
		"prior Elite really offers sewing but player leaves it unbound")
	await _click(app.continue_button)
	await _reach(fixture.paths[1], false)
	wardrobe = app._peddler_wardrobe
	var available := -1
	for i in range(1):
		if not app.peddler_visit.read_state().stock.trinkets[i].sold:
			available = i
			break
	_check(available >= 0, "later Shop has genuine unowned stock")
	if available >= 0:
		await _purchase(available, false)
	await _reach(fixture.paths[2], false)
	await _settle_battle(false)
	_check(sewing.wardrobe == wardrobe and sewing.hero_buttons.size() == 3
		and sewing._eligible(), "confirmed later Elite adopts bound Shop ledger after earlier skipped sewing")
	await _click(sewing.hero_buttons[2])
	_check(wardrobe.get_snapshot().operation_ids.size() == 2, "Shop and later Elite retain exactly two sew operations")
	await _click(app.continue_button)
	await _click(app.route_back_button)


## A confirmed routed Fight between two Shops hands its committed reward to the
## very wardrobe the first Shop bound; otherwise every second-Shop action fails.
func _shop_fight_shop() -> void:
	var fixture := _sequence_fixture(["Shop", "Fight", "Shop"])
	_check(not fixture.is_empty(), "real seeded route supports Shop -> Fight -> Shop")
	if fixture.is_empty() or not await _routed_win(fixture, false):
		return
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	_fund_shop_fixture() # Funding only; the route, stock and rewards are real.
	await _reach(fixture.paths[0], false)
	var bound: RunPatchWardrobe = app._peddler_wardrobe
	wardrobe = bound
	_check(bound != null and bound.is_valid(), "first Shop offers a real wardrobe")
	if bound == null:
		return
	var first_id: String = app.peddler_visit.read_state().stock.trinkets[0].id
	await _purchase(0, false)
	_check(app.party_carryover._wardrobe == bound, "first paid patch binds that wardrobe to the run")
	var sewn: Dictionary = bound.get_snapshot()
	var wearer: String = app.run_heroes[0].id
	_check(sewn.worn[wearer][sewn.definitions[first_id]] == first_id,
		"first paid patch is sewn to the chosen wearer before Continue")
	var scraps: int = app.run_scraps
	var purse: int = app.session_gold
	var deck: Array = app.run_deck.duplicate()
	await _reach(fixture.paths[1], false)
	await _settle_battle(false, 0, 0)
	var committed_gold: int = app.session_gold
	var committed_deck: Array = app.run_deck.duplicate()
	var committed_owned: Array = app.run_trinkets.duplicate()
	var committed_heroes: Array = app.run_heroes.duplicate(true)
	_check(committed_gold > purse and app.run_scraps == scraps + 1
		and committed_deck.size() == deck.size() + 1,
		"real Fight victory pays gold, exactly one scrap and one claimed card")
	var at_claim: Dictionary = bound.get_snapshot()
	_check(at_claim.gold == committed_gold and at_claim.scraps == app.run_scraps
		and at_claim.cards == committed_deck and at_claim.owned == committed_owned
		and at_claim.heroes == committed_heroes,
		"the committed reward synchronises the bound wardrobe before the next route")
	await _click(app.continue_button)
	await _reach(fixture.paths[2], false)
	_check(app._peddler_wardrobe == bound and app.party_carryover._wardrobe == bound,
		"second Shop adopts the identical wardrobe object after the rewarded Fight")
	var synced: Dictionary = bound.get_snapshot()
	# The route to the second Shop may pass a Rest or a healing Event, so the heroes the wardrobe must hold are the
	# run's roster now: the same heroes in the same slots with the same max HP, none of them below their claimed HP.
	var kept_roster: bool = app.run_heroes.size() == committed_heroes.size()
	for i in range(mini(app.run_heroes.size(), committed_heroes.size())):
		var now: Dictionary = app.run_heroes[i]
		var then: Dictionary = committed_heroes[i]
		kept_roster = kept_roster and now.id == then.id and now.max_hp == then.max_hp and now.hp >= then.hp
	_check(kept_roster, "the route to the second Shop keeps the claimed roster and never lowers its HP")
	_check(synced.gold == committed_gold and synced.scraps == app.run_scraps
		and synced.cards == committed_deck and synced.owned == committed_owned
		and synced.heroes == app.run_heroes and synced.seed == sewn.seed
		and synced.rest_id == "",
		"reward synchronises the bound wardrobe's exact gold, scraps, deck, ownership and heroes")
	_check(app._peddler_context == app._sewing_context(), "the committed reward keeps every second-Shop action current")
	_check(synced.worn == sewn.worn and synced.operation_ids == sewn.operation_ids
		and synced.definitions == sewn.definitions,
		"reward synchronisation preserves worn slots, definitions and sewing history")
	var rng: int = app.run_rng.state
	var remaining := -1
	for i in range(1):
		if not app.peddler_visit.read_state().stock.trinkets[i].sold:
			remaining = i
			break
	_check(remaining >= 0, "second Shop stocks a genuinely unsold patch")
	if remaining >= 0:
		var second_id: String = app.peddler_visit.read_state().stock.trinkets[remaining].id
		# Stock position is not a wearer identity: two Shops can offer the same
		# slot at index zero. Use another hero so this persistence scenario
		# actually preserves the first sewn patch while adding the second.
		var second_wearer := 1 if remaining == 0 else remaining
		await _purchase(remaining, true, second_wearer)
		var after_sew: Dictionary = bound.get_snapshot()
		_check(after_sew.worn[app.run_heroes[second_wearer].id][after_sew.definitions[second_id]] == second_id
			and after_sew.worn[wearer][after_sew.definitions[first_id]] == first_id
			and after_sew.operation_ids.size() == sewn.operation_ids.size() + 1
			and after_sew.operation_ids.slice(0, sewn.operation_ids.size()) == sewn.operation_ids,
			"second paid patch sews once after the Fight and appends to preserved history")
	_check(app.run_rng.state == rng and app.party_carryover._wardrobe == bound,
		"second paid visit consumes no RNG and keeps same wardrobe")
	await _click(app.route_back_button)


func _purchase_seeded_coat() -> bool:
	var next_seed := 1
	for attempt in range(maxi(40, RunAuthoredPatchDefinitions.load_definitions().size() * 8)):
		var fixture := _sequence_fixture(["Shop"], next_seed)
		_check(not fixture.is_empty(), "seeded Shop coat probe finds a legal connected route")
		if fixture.is_empty() or not await _routed_win(fixture, false):
			return false
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		_fund_shop_fixture()
		await _reach(fixture.paths[0], false)
		wardrobe = app._peddler_wardrobe
		_check(wardrobe != null and wardrobe.is_valid()
			and app.shop_purchases != null, "coat probe mounts genuine Shop and wardrobe")
		if wardrobe == null or app.shop_purchases == null:
			return false
		var coat := -1
		for i in range(app.peddler_visit.read_state().stock.trinkets.size()):
			if app.peddler_visit.read_state().stock.trinkets[i].id == "quilted_coat":
				coat = i
				break
		if coat >= 0:
			await _purchase(coat, false)
			_check(wardrobe.get_snapshot().owned.has("quilted_coat"),
				"real seeded Shop buys and sews the authored Quilted Coat")
			await _click(app.shop_back_button)
			return true
		next_seed = fixture.seed + 1
		await _click(app.shop_back_button)
	return false


func _candidate_contract_checks() -> void:
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/shop/initial_offers.json"))
	var pool: Array = authored.trinkets
	var definitions := RunAuthoredPatchDefinitions.load_definitions()
	_check(not definitions.is_empty() and not pool.is_empty(), "real candidate authorities load")
	var rng: RandomNumberGenerator = app.run_rng
	_check(rng != null, "candidate contract exercised during a real seeded visit")
	var rng_state: int = rng.state
	_check(app._validated_patch_candidates(pool) == pool, "complete shipped pool validates")
	var ids: Array = app._catalog_trinket_ids()
	for definition in definitions:
		if definition.id in ["relay_bobbin", "hearth_lining"]:
			continue # P8 rare patches use a separate stock mechanism (deferred)
		_check(ids.count(definition.id) == 1, "shared Elite pool has authored ID once: " + definition.id)
	for bad in [null, [], ["button_eye"], [{"id": 7, "price": 100}],
		[{"id": "foreign_patch", "price": 100}], [{"id": "", "price": 100}],
		[{"id": "button_eye", "price": 99}], [{"id": "button_eye", "price": "100"}],
		[{"id": "button_eye", "price": 100}, {"id": "button_eye", "price": 100}]]:
		var before: Variant = bad.duplicate(true) if bad is Array else bad
		_check(app._validated_patch_candidates(bad).is_empty() and bad == before,
			"malformed patch pool rejected atomically")
	_check(app.run_rng == rng and rng.state == rng_state,
		"candidate reads and rejection never consume run RNG")
	var detached: Array = app._validated_patch_candidates(pool)
	detached[0].id = "foreign_patch"
	_check(pool[0].id != "foreign_patch", "validated pool is detached from caller")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	await _attack_patch_purchases()
	await _poor_and_replacement()
	await _unsewn_elite_before_shop()
	await _shop_fight_shop()
	await _elite_before_peddler()
	await _badge_fights()
	await _finish_patches()


func _badge_service_checks() -> void:
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/heroes/starter_party.json"))
	for hero in definitions:
		hero.max_hp = int(hero.max_hp)
	var heroes := CombatParty.new(definitions).get_heroes()
	var slots: Array = JSON.parse_string(FileAccess.get_file_as_string(
		CombatShopPatchRules.SLOTS_CATALOG))
	for owned in [[], ["stitched_badge"]]:
		var carry := RunTornCarryover.new(heroes)
		var clothes := RunPatchWardrobe.new(heroes, owned, slots, 0)
		_check(carry.bind_wardrobe(clothes, carry.torn, clothes.get_snapshot()),
			"scene-free unowned/unsewn wardrobe genuinely binds")
		var before := [carry.read_state(), carry.torn.read_state(), clothes.get_snapshot()]
		var party := carry.create_next_fight_party()
		_check(party != null and party.has_meta("shop_patch_projection"), "bound party carries optional projection")
		if party == null:
			continue
		var rules: CombatShopPatchRules = party.get_meta("shop_patch_projection").rules
		for hero in party.get_heroes():
			_check(rules.opening_block_bonus(hero.id) == 0, "unowned/unsewn grants no Badge bonus")
		_check([carry.read_state(), carry.torn.read_state(), clothes.get_snapshot()] == before,
			"party creation never mutates persistent ledgers")
		var fight := _badge_flow(party)
		var projection: Dictionary = party.get_meta("shop_patch_projection")
		var mismatched := projection.duplicate(true)
		mismatched.heroes[1].hp -= 1
		for invalid in [[], {}, {"rules": 3}, {"rules": CombatShopPatchRules.new(), "heroes": heroes}, mismatched]:
			party.set_meta("shop_patch_projection", invalid)
			var state := _badge_flow_state(fight)
			_check(not fight.flow.begin_fight() and _badge_flow_state(fight) == state,
				"invalid optional projection rejects before deck, RNG, actors or one-shot mutations")
		party.set_meta("shop_patch_projection", projection)
		_check(fight.flow.begin_fight() and party.get_hero(1).block == 6
			and party.get_hero(2).block == 0 and party.get_hero(3).block == 0,
			"unowned/unsewn battle begins with base Block only after rejected starts")
		if not owned.is_empty():
			_check(clothes.sew("stitched_badge", "warden", "HEAD", "after-projection", clothes.get_snapshot()).ok,
				"wardrobe can sew after old party projection was made")
			_check(rules.opening_block_bonus("warden") == 0
				and carry.create_next_fight_party().get_meta("shop_patch_projection").rules.opening_block_bonus("warden") == 3,
				"battle projection stays detached while next factory freshly binds current sewing")
		var another := carry.create_next_fight_party()
		party.get_meta("shop_patch_projection").heroes[0].hp -= 1
		_check(another.get_meta("shop_patch_projection").heroes == heroes
			and carry.create_next_fight_party().get_meta("shop_patch_projection").heroes == heroes,
			"each factory projection is detached from other parties and ledgers")
		clothes._heroes[0].hp -= 1
		var stale := [carry.read_state(), carry.torn.read_state(), clothes.get_snapshot()]
		_check(carry.create_next_fight_party() == null
			and [carry.read_state(), carry.torn.read_state(), clothes.get_snapshot()] == stale,
			"stale wardrobe rejects party creation without repairing either ledger")
		clothes._heroes[0].hp += 1
		carry.torn._heroes[0].hp -= 1
		var torn_stale := [carry.read_state(), carry.torn.read_state(), clothes.get_snapshot()]
		_check(carry.create_next_fight_party() == null
			and [carry.read_state(), carry.torn.read_state(), clothes.get_snapshot()] == torn_stale,
			"torn drift rejects without mutating either ledger")
	var unbound := RunTornCarryover.new(heroes).create_next_fight_party()
	_check(unbound != null and not unbound.has_meta("shop_patch_projection"), "unbound runs retain absent projection")
	var vanilla := _badge_flow(unbound)
	_check(vanilla.flow.begin_fight() and unbound.get_hero(1).block == 6,
		"unbound combat preserves existing opening Block")


func _badge_flow(party: CombatParty) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 107
	var deck := CombatDeck.new(StarterCards.new().get_starting_deck(), rng)
	var enemies := CombatEnemies.new([{"id": "opening_probe", "max_hp": 20}])
	var intents := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "block", "amount": 0}]}])
	var result := CombatBattleResult.new(party, enemies)
	return {"party": party, "deck": deck, "enemies": enemies, "intents": intents,
		"result": result, "rng": rng, "flow": CombatRoundFlow.new(deck, party, enemies, intents, result)}


func _badge_flow_state(f: Dictionary) -> Array:
	return [f.party.get_heroes(), f.enemies.get_enemies(), f.deck.draw_pile.duplicate(),
		f.deck.hand.duplicate(), f.deck.discard_pile.duplicate(), f.deck.energy, f.deck.turn_active,
		f.rng.state, f.intents.get_intents(), f.intents._turn_index, f.result.get_outcome(),
		f.flow._started, f.flow._opening_block._consumed]


func _badge_fights() -> void:
	_badge_service_checks()
	var fixture := {}
	# Current verified connected route; search its genuine stock and advance
	# deterministically when the Badge is absent after authored pool/map changes.
	var next_seed := 5087
	var badge := -1
	# Find a real generated route whose real stock contains the Badge. Never
	# replace stock or patch definitions to manufacture a positive case.
	for attempt in range(maxi(40, RunAuthoredPatchDefinitions.load_definitions().size() * 8)):
		fixture = _sequence_fixture(["Shop", "Fight", "Fight"], next_seed, true)
		_check(not fixture.is_empty(), "generated route supports Badge and inactive follow-up Fight")
		if fixture.is_empty() or not await _routed_win(fixture, false):
			return
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		_fund_shop_fixture()
		await _reach(fixture.paths[0], false)
		for i in range(1):
			if app.peddler_visit.read_state().stock.trinkets[i].id == "stitched_badge":
				badge = i
		next_seed = fixture.seed + 1
		app._return_to_title()
		await _frames()
		if badge >= 0:
			break
	_check(badge >= 0, "real seeded Shop stock guarantees a purchasable Stitched Badge")
	if badge < 0:
		return
	for wearer in [0, 1]:
		var replay: Array = []
		for keyboard in [false, true]:
			if not await _routed_win(fixture, false):
				return
			await _activate(app.reward_buttons[3], keyboard)
			await _activate(app.continue_button, keyboard)
			_fund_shop_fixture()
			await _reach(fixture.paths[0], keyboard)
			wardrobe = app._peddler_wardrobe
			await _purchase(badge, keyboard, wearer)
			var paid := [app.run_heroes.duplicate(true), app.run_deck.duplicate(),
				app.run_trinkets.duplicate(), app.session_gold, app.run_scraps]
			_check([app.run_heroes, app.run_deck, app.run_trinkets, app.session_gold, app.run_scraps] == paid,
				"leaving a paid Shop preserves persistent heroes, deck, ownership and currency")
			# The route callback must fail closed on a stale bound wardrobe.
			var transit: Array = fixture.paths[1].duplicate()
			var destination: String = transit.pop_back()
			await _visit_path(transit, keyboard)
			# A transit Rest or Event may legitimately heal or pay before the Badge fight.
			var persistent := [app.run_heroes.duplicate(true), app.run_deck.duplicate(),
				app.run_trinkets.duplicate(), app.session_gold, app.run_scraps]
			var action: Button = _route_action(destination)
			var callback: Callable = action.pressed.get_connections()[0].callable
			wardrobe._heroes[wearer].hp -= 1
			_reject_entry(callback, "stale wardrobe rejects real Fight entry")
			var stale := _patch_state()
			_check(app.party_carryover.create_next_fight_party() == null and _patch_state() == stale,
				"stale factory leaves run RNG and every persistent ledger unchanged")
			wardrobe._heroes[wearer].hp += 1
			var oracle := _oracle(destination)
			await _activate(action, keyboard)
			_check(app.party != null and app.round_flow._started and _mounted_state() == oracle,
				"real mounted Fight starts with exact seeded entry state")
			for hero in app.party.get_heroes():
				var expected := (6 if hero.id == "warden" else 0) + (3 if hero.position == wearer + 1 else 0)
				_check(hero.block == expected, "Badge adds exactly 3 only to its wearer at first entry")
			_check([app.run_heroes, app.run_deck, app.run_trinkets, app.session_gold, app.run_scraps] == persistent,
				"opening Badge preserves persistent heroes, deck, ownership and currency")
			var live := {"party": app.party, "enemies": app.enemies, "deck": app.deck,
				"rng": app.run_rng, "intents": app.enemy_intents, "result": app.battle_result,
				"flow": app.round_flow}
			var trace := [_badge_flow_state(live)]
			var duplicate := _badge_flow_state(live)
			_check(not app.round_flow.begin_fight() and _badge_flow_state(live) == duplicate,
				"duplicate begin cannot stack Badge, change actors or consume RNG")
			_check(app.round_flow.end_turn(), "real Badge battle advances through enemy phase")
			for hero in app.party.get_heroes():
				_check(hero.block == 0, "normal next-turn reset removes all opening Block")
			trace.append(_badge_flow_state(live))
			var badge_owner: String = persistent[0][wearer].id
			var current_wearer: Dictionary = app.party.get_heroes().filter(func(hero): return hero.id == badge_owner)[0]
			await _settle_battle(keyboard, current_wearer.position)
			await _activate(app.continue_button, keyboard)
			await _reach(fixture.paths[2], keyboard)
			var down: Dictionary = app.party.get_heroes().filter(func(hero): return hero.id == badge_owner)[0]
			_check(down.hp == 0 and down.block == 0
				and wardrobe.get_snapshot().worn[down.id].HEAD == "stitched_badge",
				"next mounted Fight grants zero to genuinely downed inactive Badge wearer")
			trace.append(_mounted_state())
			trace.append([app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.run_trinkets.duplicate(),
				app.session_gold, app.run_scraps, wardrobe.get_snapshot()])
			if keyboard:
				_check(trace == replay, "Badge mouse/keyboard replay agrees on full combat and persistent state")
			else:
				replay = trace
			await _settle_battle(keyboard)
			await _activate(app.continue_button, keyboard)
			await _activate(app.route_back_button, keyboard)


func _finish_patches() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_shop_patch_sewing_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _elite_before_peddler() -> void:
	var fixture := _sequence_fixture(["Elite", "Shop", "Fight"])
	_check(not fixture.is_empty(), "real Elite -> Peddler -> Fight fixture exists")
	if fixture.is_empty() or not await _routed_win(fixture, false):
		return
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	_fund_shop_fixture()
	await _reach(fixture.paths[0], false)
	await _settle_battle(false)
	var sewing = app.get_node("LiveElitePatchSewing")
	_check(sewing.hero_buttons.size() == 3, "real earlier Elite offers three owners")
	await _click(sewing.hero_buttons[0])
	wardrobe = sewing.wardrobe
	var worn: Dictionary = wardrobe.get_snapshot().worn
	await _click(app.continue_button)
	await _reach(fixture.paths[1], false)
	_check(app._peddler_wardrobe == wardrobe and wardrobe.get_snapshot().worn == worn, "Peddler adopts exact bound Elite wardrobe")
	await _purchase(0, false, 1)
	worn = wardrobe.get_snapshot().worn
	await _reach(fixture.paths[2], false)
	_check(app.party_carryover._wardrobe == wardrobe and wardrobe.get_snapshot().worn == worn and app._current_carryover_fight(),
		"prior Elite and Peddler sewing persist together into real Fight")
	await _settle_battle(false, 2)
	var active := wardrobe.project_active(app.party_carryover.torn.read_state())
	_check(active.ok and active.active.seamstress.is_empty() and wardrobe.get_snapshot().worn == worn,
		"genuine tear suppresses purchased wearer's powers while retaining assignments")
	var projected: CombatParty = app.party_carryover.create_next_fight_party()
	_check(projected != null and projected.get_hero(2).hp == 0
		and projected.get_hero(2).max_hp == app.run_heroes[1].max_hp,
		"next party excludes torn purchased wearer's coat cap bonus")
	app._return_to_title()
	await _frames()
