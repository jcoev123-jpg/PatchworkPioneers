extends "res://tests/live_rest_route_entry_test.gd"
## Mounted route/combat/reward/Shop inputs; only funded gold/count are injected.


class RejectingMap extends RunMap:
	var attempts := 0
	func choose_node(_id: String) -> bool:
		attempts += 1
		return false


func _stock_oracle() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	var ids: Array[String] = []
	for hero in app.run_heroes:
		ids.append(hero.id)
	var expected := RunShopStockOffers.generate(rng, ids, authored.cards, authored.trinkets, [])
	_check(expected.ok, "real authored pools produce oracle stock")
	for category in ["cards", "trinkets"]:
		for offer in expected[category]:
			offer.sold = false
	return {"stock": {"cards": expected.cards, "trinkets": expected.trinkets}, "state": rng.state}


func _fixture() -> Dictionary:
	for value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for id in map.get_legal_choices():
			if map.get_node(id).type != "Fight":
				continue
			var shop := false
			var unsupported := false
			for next in map.get_node(id).outgoing:
				shop = shop or map.get_node(next).type == "Shop"
				unsupported = unsupported or map.get_node(next).type not in ["Rest", "Shop", "Event", "Treasure"]
			if shop and unsupported:
				map.choose_node(id)
				var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
				if selected.get("encounter_id") == "starter_attacks":
					return {"seed": value, "fight": id}
	return {}


func _shop_state() -> Array:
	return [_persistent(), app.run_removal_count, app.shop_visit.get_state()]


## The one passive gallery scene child that mounts sewn tiles beside a visit.
func _visit_tiles():
	return app.get_node("LiveVisitCardTiles")


## Every tile of one group currently painting the SELECTED cue.
func _selected_tiles(gallery, group: String) -> Array:
	var source: Array = gallery.offer_tiles() if group == "offer" \
		else (gallery.removal_tiles() if group == "removal" else gallery.upgrade_tiles())
	var result: Array = []
	for tile in source:
		if gallery.tile_details(tile).get("selected", false):
			result.append(tile)
	return result


## AC1/AC2: a real click and a real Enter move the one visible SELECTED cue
## between the canonical rows with no wallet, deck, map or RNG effect; the
## masked selectors keep their whole data contract without a dropdown row; and
## the shared face gives a long wrapped card a whole, unclipped tag.
func _check_selection_cue(gallery) -> void:
	var before := _shop_state()
	await _click_tile(_tile_for("offer", 3))
	_check(app.shop_offers.selected == 3 and _shop_state() == before,
		"real offer click selects the fourth listing with no run effect")
	_check(_selected_tiles(gallery, "offer") == [_tile_for("offer", 3)],
		"exactly the clicked offer tile shows the SELECTED cue")
	await _select_tile_by_key(_tile_for("offer", 0))
	_check(app.shop_offers.selected == 0 and _shop_state() == before,
		"real offer Enter selects the first listing with no run effect")
	_check(_selected_tiles(gallery, "offer") == [_tile_for("offer", 0)]
		and not gallery.tile_details(_tile_for("offer", 3)).selected,
		"moving selection clears the prior cue and marks only the new tile")
	var cue: Dictionary = gallery.build_card_face({
		"card_id": "warden_strike", "art_id": "warden_strike", "owner": "warden",
		"title": "Stitched Overlong Recursive Seamstress Repair Volley of the Warden's Twin Needles",
		"meta": "Deck card #12 • copy 3 of 4 • removal costs 100 gold",
		"effects": "Deal 6 damage to the front position and gain 7 Block.\nBefore: chosen ally heals 5 HP\nAfter: chosen ally heals 7 HP and gains 5 Block\nPinned: exhausts at end of turn"})
	root.add_child(cue["tile"])
	await _frames()
	# Let the probe face take its own readable minimum size, exactly as the
	# gallery lays it out, instead of forcing a box that would clip by design.
	var needed: Vector2 = cue["tile"].get_combined_minimum_size()
	cue["tile"].size = Vector2(maxf(520.0, needed.x), maxf(240.0, needed.y))
	await _frames()
	cue["selected_label"].visible = true
	await _frames()
	var tag: Control = cue["selected_label"]
	_check(tag.is_visible_in_tree() and tag.text == "SELECTED" and tag.size.x > 0.0 and tag.size.y > 0.0
		and cue["panel"].get_global_rect().encloses(tag.get_global_rect())
		and not tag.get_global_rect().intersects(cue["effects_label"].get_global_rect())
		and not tag.get_global_rect().intersects(cue["picture"].get_global_rect())
		and cue["title_label"].text.begins_with("Stitched Overlong")
		and cue["effects_label"].text.contains("Pinned: exhausts at end of turn"),
		"a long wrapped card keeps one whole SELECTED tag inside its sewn frame, clear of art, name and effects")
	cue["tile"].free()


func _tile_for(group: String, row: int):
	var gallery = _visit_tiles()
	var source: Array = gallery.offer_tiles() if group == "offer" \
		else (gallery.removal_tiles() if group == "removal" else gallery.upgrade_tiles())
	for tile in source:
		if gallery.tile_row(tile) == row:
			return tile
	return null


## Real pointer selection: the tile must be scrolled into the visible gallery
## first, exactly as a player reaches a lower card.
func _click_tile(tile) -> void:
	_check(tile != null, "physical tile click requires a mounted tile")
	if tile == null:
		return
	_visit_tiles().gallery_scroll().ensure_control_visible(tile)
	await _frames()
	await _click(tile)


## Real keyboard selection: focus the tile, then Enter activates it.
func _select_tile_by_key(tile) -> void:
	_check(tile != null, "keyboard tile selection requires a mounted tile")
	if tile == null:
		return
	tile.grab_focus()
	await _frames()
	_check(tile.has_focus(), "keyboard focus reaches the mounted tile")
	await _key(KEY_ENTER)


## AC2: the physical Shop visit displays its committed stall scene behind the same usable
## controls, with a cover crop and no pointer or keyboard capture.
func _check_shop_backdrop() -> int:
	var bed = app.visit_backdrop
	_check(is_instance_valid(bed) and bed.get_parent() == app
		and bed.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and bed.focus_mode == Control.FOCUS_NONE,
		"Shop visit mounts one inert full-screen art bed")
	if not is_instance_valid(bed):
		return 0
	var expected := "res://assets/paper/backgrounds/shop_stall.png"
	_check(VISIT_ART.visit_backdrop_path("Shop") == expected and bed.visit_kind == "Shop"
		and bed.has_image() == ResourceLoader.exists(expected)
		and (not bed.has_image() or bed.visit_texture.resource_path == expected),
		"Shop visit draws its own committed stall scene")
	_check(bed.get_index() < app.shop_view.get_index(),
		"Shop art bed is drawn behind the usable Shop controls")
	var view: Rect2 = bed.view_rect()
	_check(view.size.x > 0.0 and view.size.y > 0.0
		and Rect2(Vector2.ZERO, app.size).is_equal_approx(view)
		and Rect2(0, 0, 1280, 720).encloses(bed.get_global_rect()),
		"Shop art bed fills the whole 1280x720 visit, not one control box")
	var drawn: Rect2 = bed.image_rect()
	var visible: Rect2 = bed.image_crop()
	var pixels: Vector2 = bed.texture_size()
	_check(bed.has_image() and drawn.encloses(view)
		and is_equal_approx(drawn.size.x / drawn.size.y, pixels.x / pixels.y),
		"Shop stall scene covers the view without stretching")
	_check(visible.position.x >= 0.0 and visible.position.y >= 0.0
		and visible.end.x <= pixels.x + 0.01 and visible.end.y <= pixels.y + 0.01
		and is_equal_approx(visible.size.x * (drawn.size.x / pixels.x), view.size.x),
		"Shop stall scene crops only the centred window that fills the view")
	return bed.get_instance_id()


## The tile face is the reward card's own. Cover all three authored render
## priorities with a controlled synthetic ID: the card illustration, then the
## owner emblem, then the drawn paper patch, and never assume art is absent.
func _check_tile_art(gallery) -> void:
	var authored: Dictionary = gallery.build_card_face({
		"card_id": "warden_strike", "art_id": "warden_strike", "owner": "warden",
		"title": "Strike", "meta": "probe", "effects": "probe"})
	root.add_child(authored["tile"])
	authored["tile"].size = Vector2(520, 200)
	await _frames()
	_check(authored["picture"].has_picture()
		and authored["picture"].picture.resource_path == "res://assets/paper/cards/art/warden_strike.png",
		"a tile for an illustrated card reuses the reward card's authored picture")
	authored["tile"].free()
	var emblem: Dictionary = gallery.build_card_face({
		"card_id": "zz_synthetic_missing_art", "art_id": "zz_synthetic_missing_art", "owner": "warden",
		"title": "Synthetic probe", "meta": "probe", "effects": "probe"})
	root.add_child(emblem["tile"])
	emblem["tile"].size = Vector2(520, 200)
	await _frames()
	_check(emblem["picture"].has_picture()
		and emblem["picture"].picture.resource_path == "res://assets/paper/cards/emblem_warden.png",
		"a card without its own art falls back to the owning hero's stitched emblem")
	emblem["tile"].free()
	var drawn: Dictionary = gallery.build_card_face({
		"card_id": "zz_synthetic_missing_art", "art_id": "zz_synthetic_missing_art",
		"owner": "synthetic_owner", "title": "Synthetic probe", "meta": "probe", "effects": "probe"})
	root.add_child(drawn["tile"])
	drawn["tile"].size = Vector2(520, 200)
	await _frames()
	_check(not drawn["picture"].has_picture() and drawn["title_label"].text == "Synthetic probe"
		and drawn["tile"].get_global_rect().size.x > 0.0 and drawn["tile"].get_global_rect().size.y > 0.0,
		"a card with neither picture nor emblem still mounts the drawn paper fallback")
	drawn["tile"].free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "seeded real graph offers Shop and unsupported choices after starter Fight")
	if fixture.is_empty():
		_finish_shop()
		return
	var stale: Array[Callable] = []
	var replay: Array = []
	# Normal insufficient funds, funded mouse, funded keyboard with escalated quote,
	# and same-seed normal restart/skip.
	for session in range(4):
		seed(400040)
		var global_next := randi()
		seed(400040)
		if not await _routed_win(fixture, false):
			break
		if session != 1:
			await _click(app.reward_buttons[3])
		else:
			app.reward_buttons[0].grab_focus()
			await _key(KEY_ENTER)
		_check(app.fight_reward_claimed and is_instance_valid(app.continue_button), "reward claim/skip exposes live Continue")
		if not is_instance_valid(app.continue_button):
			break
		var before := _persistent()
		for callback in stale:
			callback.call()
		_check(_persistent() == before and app.shop_visit == null, "old visit callbacks cannot spend or reopen in fresh combat")
		await _click(app.continue_button)
		var shop: Button
		var shown: Array[String] = []
		before = _persistent()
		for button in app.route_buttons:
			var id: String = button.get_meta("route_id")
			var kind: String = app.run_map.get_node(id).type
			shown.append(id)
			_check(button.disabled == (kind not in ["Rest", "Shop", "Event", "Treasure", "Fight", "Elite", "Boss"]), "only supported connected controls enabled")
			if kind == "Shop":
				shop = button
			if button.disabled:
				await _click(button)
				button.grab_focus()
				await _key(KEY_ENTER)
				button.pressed.emit()
		_check(shown == app.run_map.get_legal_choices() and shop != null, "real connected Shop button is mounted")
		_check(_persistent() == before, "unsupported physical and retained signal input is inert")
		if shop == null:
			break
		var route_callback: Callable = shop.pressed.get_connections()[0].callable
		var back_callback: Callable = app.route_back_button.pressed.get_connections()[0].callable
		var prior: Array[String] = app.run_map.get_route()
		var id: String = shop.get_meta("route_id")
		var parent: String = app.run_map.get_current_node_id()
		var outgoing: Array = app.run_map._nodes[parent].outgoing.duplicate()
		app.run_map._nodes[parent].outgoing.erase(id)
		route_callback.call()
		_check(_persistent() == before and app.shop_view == null, "disconnected mounted Shop rejects before map commit")
		app.run_map._nodes[parent].outgoing = outgoing
		app._choose_shop_route(id, weakref(RunMap.new()), prior, shop)
		app._choose_shop_route("f12_n0", weakref(app.run_map), prior, shop)
		var empty_route: Array[String] = []
		app._choose_shop_route(id, weakref(app.run_map), empty_route, shop)
		shop.disabled = true
		route_callback.call()
		shop.disabled = false
		app.run_map._nodes[id].type = "Rest"
		route_callback.call()
		app.run_map._nodes[id].type = "Shop"
		_check(_persistent() == before and app.shop_visit == null, "wrong identity, ID, route, disabled button and node type reject")
		var saved_gold: int = app.session_gold
		app.session_gold = -1
		var invalid_before := _persistent()
		route_callback.call()
		_check(_persistent() == invalid_before and app.shop_visit == null, "invalid ledger cannot commit a route choice")
		app.session_gold = saved_gold
		var saved_rng: RandomNumberGenerator = app.run_rng
		app.run_rng = null
		var missing_before := [app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.session_gold,
			app.run_removal_count, app.run_map.get_floors(), app.run_map.get_route()]
		route_callback.call()
		_check(app.run_rng == null and app.shop_visit == null and app.shop_purchases == null
			and missing_before == [app.run_heroes, app.run_deck, app.session_gold,
			app.run_removal_count, app.run_map.get_floors(), app.run_map.get_route()], "absent RNG rejects without partial entry")
		app.run_rng = saved_rng
		# Published roster drift now fails before entering another run node.
		var heroes: Array = app.run_heroes.duplicate(true)
		app.run_heroes[0].id = "unknown_shop_owner"
		_check(not app._can_choose_connected_route(), "published roster drift fails carryover admission")
		invalid_before = _persistent()
		route_callback.call()
		_check(_persistent() == invalid_before and app.shop_visit == null, "roster drift cannot advance route or consume RNG")
		# Align the held fixture too so the original stock rejection remains reachable.
		app.party_carryover._heroes[0].id = "unknown_shop_owner"
		_check(app._can_choose_connected_route(), "unknown catalog owner passes roster admission before stock rejection")
		invalid_before = _persistent()
		route_callback.call()
		_check(_persistent() == invalid_before and app.shop_visit == null and app.shop_purchases == null,
			"rejected stock leaves roster, deck, gold, route and RNG untouched")
		app.run_heroes = heroes
		app.party_carryover._heroes = heroes.duplicate(true)
		# Force choose_node to reject only after admission and valid generation.
		var original_map: RunMap = app.run_map
		var rejecting := RejectingMap.new()
		rejecting._nodes = original_map._nodes.duplicate(true)
		rejecting._floor_ids = original_map._floor_ids.duplicate(true)
		rejecting._route.assign(prior)
		rejecting._generation_revision = original_map.get_generation_revision()
		app.run_map = rejecting
		app._carryover_map = weakref(rejecting)
		app.act_outcome._map = rejecting
		app._connected_map = weakref(rejecting)
		app._reward_map = weakref(rejecting)
		invalid_before = _persistent()
		_check(not app._choose_shop_route(id, weakref(rejecting), prior, shop) and rejecting.attempts == 1,
			"valid generated stock reaches rejecting map choice")
		_check(_persistent() == invalid_before and app.shop_visit == null and app.shop_purchases == null,
			"rejected map choice restores RNG and publishes no ledger or stock")
		app.run_map = original_map
		app._carryover_map = weakref(original_map)
		app.act_outcome._map = original_map
		app._connected_map = weakref(original_map)
		app._reward_map = weakref(original_map)
		# A connected whitespace node reaches open_visit, which rejects its ID.
		original_map._nodes[" "] = original_map._nodes[id].duplicate(true)
		original_map._nodes[parent].outgoing.append(" ")
		# Align the deliberately altered graph binding to reach visit rollback,
		# rather than failing the stale-battle guard before stock generation.
		app._carryover_floors = original_map.get_floors()
		shop.set_meta("route_id", " ")
		_check(app._can_choose_connected_route() and original_map.get_legal_choices().has(" ")
			and original_map.get_node(" ").type == "Shop" and _stock_oracle().stock.cards.size() == 5,
			"whitespace fixture admits connected Shop with valid generated stock before visit opening")
		invalid_before = _persistent()
		_check(not app._choose_shop_route(" ", weakref(original_map), prior, shop), "visit opening rejects whitespace ID")
		_check(_persistent() == invalid_before and app.shop_visit == null and app.shop_purchases == null,
			"failed visit opening rolls back committed map and generated RNG")
		original_map._nodes.erase(" ")
		original_map._nodes[parent].outgoing = outgoing
		app._carryover_floors = original_map.get_floors()
		shop.set_meta("route_id", id)
		if session in [1, 2]:
			app.session_gold = 200
			app.run_removal_count = 1 if session == 2 else 0
		if session == 2:
			shop.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(shop)
		_check(app.shop_view != null and app.shop_visit != null, "physical Shop entry mounts real ledger and view")
		if app.shop_view == null or app.shop_visit == null:
			break
		var bed_id: int = _check_shop_backdrop()
		var visit: RunShopVisit = app.shop_visit
		var state := visit.get_state()
		_check(app.run_map.get_route() == [fixture.fight, id] and state.visited_ids == [id]
			and state.shop_node_id == id and state.removal_available, "Shop records exact ID and route once")
		var price: int = 75 + 25 * app.run_removal_count
		_check(app.shop_label.text == "Gold: %d | Removal: %d gold" % [app.session_gold, price], "visible gold and authoritative escalating quote")
		_check(app.shop_cards.item_count == app.run_deck.size(), "compact OptionButton includes every owned copy")
		for index in range(app.run_deck.size()):
			_check(app.shop_cards.get_item_text(index) == app.run_deck[index], "owned ID order is visible")
		_check(app.shop_purchases.is_valid() and app.shop_offers.item_count == 5, "routed Shop includes valid card buying stock")
		for control in [app.shop_view, app.shop_label, app.shop_offers, app.shop_buy_button, app.shop_cards, app.shop_remove_button, app.shop_continue_button, app.shop_back_button]:
			_check(control.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "Shop control fits 1280x720")
		var gallery = _visit_tiles()
		_check(gallery.is_gallery_mounted() and gallery.gallery_kind() == "Shop",
			"real Shop mounts the passive visit card gallery")
		var panel: Control = gallery.gallery_panel()
		_check(is_instance_valid(panel) and panel.is_visible_in_tree()
			and Rect2(0, 0, 1280, 720).encloses(panel.get_global_rect())
			and is_instance_valid(gallery.gallery_scroll()),
			"scrollable Shop gallery fits inside 1280x720")
		_check(gallery.offer_tiles().size() == 5, "Shop gallery shows all five offer tiles")
		_check(gallery.removal_tiles().size() == app.run_deck.size(),
			"Shop gallery shows exactly one removal tile per owned occurrence")
		var scroll: ScrollContainer = gallery.gallery_scroll()
		var scroll_start: int = scroll.scroll_vertical
		scroll.ensure_control_visible(gallery.removal_tiles().back())
		await _frames()
		_check(scroll.scroll_vertical > scroll_start
			and Rect2(0, 0, 1280, 720).encloses(gallery.removal_tiles().back().get_global_rect()),
			"the scrollable gallery reaches a lower owned card inside 1280x720")
		for control in [app.shop_offers, app.shop_cards]:
			_check(control.is_visible_in_tree() and not control.disabled and control.modulate.a == 0.0
				and control.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and control.focus_mode == Control.FOCUS_NONE,
				"masked Shop dropdown keeps its validated contract but takes no pointer or focus")
		var layouts: Array = [gallery.masked_selector_layout("offer"),
			gallery.masked_selector_layout("removal")]
		for layout in layouts:
			_check(not layout.is_empty() and layout.original_custom_minimum.y >= 48.0
				and layout.masked_min_height <= LiveVisitCardTiles.MASKED_ROW_MIN_HEIGHT
				and layout.visible_in_tree and not layout.disabled and layout.item_count > 0
				and layout.selected >= 0 and layout.pointer_ignore and layout.focus_none,
				"masked Shop dropdown keeps its data contract but takes no left-column dropdown row")
		for button in [app.shop_buy_button, app.shop_remove_button,
				app.shop_continue_button, app.shop_back_button]:
			_check(button.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(button.get_global_rect())
				and not app.shop_offers.get_global_rect().intersects(button.get_global_rect())
				and not app.shop_cards.get_global_rect().intersects(button.get_global_rect()),
				"real Shop action stays readable and clear of the collapsed selector rows")
		if session == 0:
			app.shop_view.visible = false
			await _frames()
			_check(app.shop_offers.custom_minimum_size == Vector2(440, 48)
				and app.shop_offers.modulate.a == 1.0
				and app.shop_offers.focus_mode != Control.FOCUS_NONE
				and app.shop_offers.mouse_filter != Control.MOUSE_FILTER_IGNORE
				and app.shop_offers.get_combined_minimum_size().y >= 24.0,
				"tearing the gallery down restores the canonical Shop dropdown exactly")
			app.shop_view.visible = true
			await _frames()
			_check(gallery.is_gallery_mounted() and gallery.gallery_kind() == "Shop"
				and app.shop_offers.custom_minimum_size == Vector2.ZERO
				and app.shop_offers.modulate.a == 0.0,
				"a re-synced Shop visit masks and collapses its selectors again")
		var stock: Array = app.shop_purchases.get_stock().cards
		for index in range(gallery.offer_tiles().size()):
			var tile = gallery.offer_tiles()[index]
			var details: Dictionary = gallery.tile_details(tile)
			var listing: Dictionary = stock[index]
			var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(listing.id)
			_check(gallery.tile_row(tile) == index and details.card_id == listing.id
				and details.title == String(definition.get("display_name", listing.id))
				and details.meta.begins_with("%d gold" % int(listing.price)) and details.has_picture,
				"offer tile shows its authored name, quoted price and art/emblem")
		for index in range(app.run_deck.size()):
			var tile = gallery.removal_tiles()[index]
			var details: Dictionary = gallery.tile_details(tile)
			var owned: String = app.run_deck[index]
			var definition: Dictionary = RunRestStitchCards.resolve_card_definition(owned)
			_check(gallery.tile_row(tile) == index and details.card_id == owned
				and details.title == String(definition.get("display_name", owned))
				and details.meta.begins_with("Deck card #%d" % (index + 1)),
				"removal tile carries the exact owned occurrence index and authored name")
		before = _shop_state()
		await _click_tile(_tile_for("offer", 2))
		_check(_shop_state() == before and app.shop_offers.selected == 2,
			"offer tile click selects that listing with zero ledger effect")
		await _select_tile_by_key(_tile_for("offer", 1))
		_check(_shop_state() == before and app.shop_offers.selected == 1,
			"offer tile keyboard selection has zero ledger effect")
		if session == 0:
			await _check_tile_art(gallery)
			await _check_selection_cue(gallery)
		before = _shop_state()
		route_callback.call()
		back_callback.call()
		_check(_shop_state() == before and app.shop_view.visible, "duplicate entry and stale route Back cannot mutate or close Shop")
		var remove_callback: Callable = app.shop_remove_button.pressed.get_connections()[0].callable
		var live_map: RunMap = app.run_map
		var other := RunMap.new()
		var other_rng := RandomNumberGenerator.new()
		other_rng.seed = fixture.seed
		other.generate(other_rng)
		_check(other.choose_node(fixture.fight) and other.choose_node(id), "replacement map has identical legal Shop route")
		app.run_map = other
		var wrong_before := _shop_state()
		remove_callback.call()
		_check(_shop_state() == wrong_before, "same-route replacement map cannot spend")
		app.run_map = live_map
		app._remove_at_shop(RunShopVisit.new(app.run_deck, app.session_gold, 0), app.shop_remove_button)
		app._remove_at_shop(visit, app.shop_back_button)
		app.session_gold += 1
		var changed_before := _shop_state()
		remove_callback.call()
		_check(_shop_state() == changed_before, "gold mismatched with ledger cannot spend")
		app.session_gold -= 1
		app.run_removal_count += 1
		changed_before = _shop_state()
		remove_callback.call()
		_check(_shop_state() == changed_before, "count mismatched with ledger cannot spend")
		app.run_removal_count -= 1
		app.run_deck.append("warden_strike")
		changed_before = _shop_state()
		remove_callback.call()
		_check(_shop_state() == changed_before, "deck mismatched with ledger cannot spend")
		app.run_deck.pop_back()
		var selected: int = app.shop_cards.selected
		var original_id: String = app.shop_cards.get_item_text(selected)
		var different_id := ""
		for owned in app.run_deck:
			if owned != original_id:
				different_id = owned
				break
		_check(not different_id.is_empty(), "mismatched fixture is a different owned ID")
		for invalid in ["unknown_card", different_id]:
			app.shop_cards.set_item_text(selected, invalid)
			remove_callback.call()
			_check(_shop_state() == before, "unknown or mismatched owned ID cannot spend")
		app.shop_cards.set_item_text(selected, original_id)
		if session in [0, 3]:
			_check(app.session_gold < price, "natural victory gold cannot afford removal")
			await _click(app.shop_remove_button)
			app.shop_remove_button.grab_focus()
			await _key(KEY_ENTER)
			_check(_shop_state() == before and not app.shop_remove_button.disabled
				and app.shop_cards.selected == selected, "insufficient funds retain selection, state and available option")
			if session == 0:
				replay = before.duplicate(true)
			else:
				_check(before == replay, "same-seed restart reproduces complete combat, inventory, ledger, route and RNG")
		else:
			# Later duplicate: every owned occurrence has its own sewn tile.
			var duplicate_index := -1
			for index in range(1, app.run_deck.size()):
				if app.run_deck[index] == app.run_deck[0]:
					duplicate_index = index
			_check(duplicate_index > 0, "owned fixture contains duplicate copies")
			if duplicate_index < 0:
				break
			var duplicate_tile = _tile_for("removal", duplicate_index)
			before = _shop_state()
			if session == 1:
				await _click_tile(duplicate_tile)
			else:
				await _select_tile_by_key(duplicate_tile)
			_check(app.shop_cards.selected == duplicate_index,
				"physical tile input chooses the later duplicate occurrence")
			_check(_shop_state() == before, "choosing the later duplicate spends nothing")
			_check(gallery.tile_details(duplicate_tile).selected,
				"the chosen owned occurrence is visibly selected")
			var expected_deck: Array = app.run_deck.duplicate()
			expected_deck.remove_at(0)
			var gold: int = app.session_gold
			var count: int = app.run_removal_count
			if session == 1:
				await _click(app.shop_remove_button)
			else:
				duplicate_tile.grab_focus()
				var reach: int = gallery.removal_tiles().size() + 3
				for step in range(reach):
					if app.shop_remove_button.has_focus():
						break
					await _key(KEY_TAB)
				_check(app.shop_remove_button.has_focus(), "Tab reaches Remove from the owned-card tiles")
				await _key(KEY_ENTER)
			_check(app.run_deck == expected_deck and app.session_gold == gold - price
				and app.run_removal_count == count + 1, "funded input removes FIRST duplicate and charges exact quote once")
			_check(visit.get_state().deck == expected_deck and visit.get_state().gold == app.session_gold
				and visit.get_state().prior_removals == count + 1 and app.shop_remove_button.disabled,
				"run mirrors used ledger exactly and disables removal")
			await _frames()
			_check(gallery.removal_tiles().all(func(tile): return tile.disabled),
				"every owned-card tile disables with the spent Shop removal")
			var after := _shop_state()
			remove_callback.call()
			app.shop_remove_button.pressed.emit()
			await _click(app.shop_remove_button)
			_check(_shop_state() == after, "repeat mouse and retained callback cannot remove or charge twice")
			_check(after[0][0] == before[0][0] and after[0][3] == before[0][3]
				and after[0][4] == before[0][4], "removal preserves heroes, seeded RNG and route")
		var tile_callback: Callable = gallery.offer_tiles()[0].pressed.get_connections()[0].callable
		stale = [route_callback, back_callback, remove_callback, tile_callback,
			app.shop_continue_button.pressed.get_connections()[0].callable,
			app.shop_back_button.pressed.get_connections()[0].callable]
		if session % 2 == 0:
			app.shop_back_button.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(app.shop_back_button)
		_check(app.visit_backdrop == null and not is_instance_id_valid(bed_id),
			"Return releases the Shop art bed with its visit")
		for callback in stale:
			callback.call()
		_check(visit.get_state().status == "closed" and app.title_view.visible and app.shop_visit == null
			and app.shop_view == null and app.shop_cards == null and app.shop_remove_button == null
			and app.shop_back_button == null and app.run_map == null and app.run_deck.is_empty()
			and app.shop_continue_button == null
			and app.shop_purchases == null and app.shop_offers == null and app.shop_buy_button == null
			and app.session_gold == 0 and app.run_removal_count == 0, "skip/Return closes ledger, clears run and rejects stale inputs")
		_check(not gallery.is_gallery_mounted() and not is_instance_valid(gallery.gallery_panel())
			and gallery.offer_tiles().is_empty() and gallery.removal_tiles().is_empty()
			and gallery.gallery_kind() == "",
			"Return discards the Shop gallery, its tiles and its callbacks")
		_check(randi() == global_next, "complete physical route/Shop leaves global RNG untouched")
	_finish_shop()


func _finish_shop() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_shop_route_entry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
