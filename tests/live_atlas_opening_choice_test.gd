extends "res://tests/live_run_map_entry_test.gd"

## Independent, pinned design facts for the actual mounted player-facing atlas.
const LIVE_HELP := {
	"Unpicker": ["Choose one: remove a card or leave",
		"Remove: 75 gold initially, +25 each time",
		"Remove one owned card for 75 gold plus 25 per previous removal, or leave unchanged"],
	"PatchStall": ["Choose one: buy a patch or leave",
		"3 priced power patches; choose a wearer; sewing included",
		"Buy one of 3 priced power patches for one chosen hero, sewing included, or leave unchanged"],
	"Campfire": ["Choose one: heal or leave",
		"Heal 30% max HP; torn revives at 1 HP first",
		"One action: heal each hero 30% max HP (torn revives at 1 HP first), or leave unchanged"],
	"SewingCircle": ["Choose one: upgrade or stitch",
		"Stitch different owners: 3 scraps; or leave",
		"Upgrade one card, stitch two different-owner cards for 3 scraps, or leave unchanged"],
	"Fight": ["Win: 10–20 gold + 1 scrap", "Choose 1 of 3 cards, or skip",
		"On win: 10–20 gold + 1 scrap; choose 1 of 3 cards or skip"],
	"Elite": ["Win: 25–35 gold + 2 scraps + patch", "Choose 1 of 3 cards, or skip",
		"On win: 25–35 gold + 2 scraps + patch; choose 1 of 3 cards or skip"],
	"Rest": ["Choose one: heal, upgrade, stitch or re-sew",
		"Heal 30% max HP; stitch 3 scraps; re-sew 1 scrap",
		"One action: heal each hero 30% max HP (torn revives at 1 HP first), upgrade one card, stitch two different-owner cards for 3 scraps, or re-sew an equipped patch for 1 scrap"],
	"Shop": ["Browse 5 cards + 2 patches",
		"Remove card: 75 gold initially, +25 each time",
		"5 cards + 2 patches; card removal starts at 75 gold, increasing 25 per removal"],
	"Peddler": ["Choose one: buy 1 of 3 hero cards or 1 patch",
		"All 4 priced on the stock; one purchase, or leave",
		"Buy one of 3 priced party-hero cards (one per hero) or the one priced patch, one purchase per visit, or leave; actual prices appear on the stock"],
	"Event": ["2–3 choices when visited",
		"Outcomes shown on arrival; no guaranteed yield",
		"2–3 choices; outcomes revealed on visit, no guaranteed yield"],
	"Treasure": ["Treasure stop · contents not yet known",
		"No fixed reward is specified by the route",
		"Treasure stop; no predetermined reward amount is known"],
	"Boss": ["Final floor-12 fight", "The last stop on this route",
		"Terminal floor-12 fight"],
}


## A generated legacy Shop patch opens the shipped Peddler visit, so the mounted
## player-facing text uses Peddler's facts while the RunMap record keeps its own type.
func _expected_hover(node: Dictionary, legal: bool) -> String:
	var shown: String = _display_kind(String(node["type"]))
	var prefix := "Floor %02d · %s · Branch %d" % [
		int(node["floor"]), shown, int(node["position"]) + 1]
	var help_kind: String = "Campfire" if node.type == "Rest" else shown
	return prefix + (" · " + str(LIVE_HELP[help_kind][2]) if legal else "")


func _check_ticket(atlas: RunRouteAtlas, id: String, where: String) -> void:
	var ticket := atlas.choice_ticket()
	_check(ticket != null and atlas._map.get_legal_choices().has(id),
		where + ": active ticket belongs to legal actual map node")
	if ticket == null or not atlas._map.get_legal_choices().has(id):
		return
	var node := atlas._map.get_node(id)
	var kind: String = node["type"]
	var shown: String = _display_kind(kind)
	var help_kind: String = "Campfire" if kind == "Rest" else shown
	var facts: Array = LIVE_HELP[help_kind]
	_check(ticket.route_id == id
		and ticket.header_text == "%s · FLOOR %02d · BRANCH %d" % [
			RunRouteAtlas.area_for_floor(int(node["floor"])).to_upper(),
			int(node["floor"]), int(node["position"]) + 1]
		and ticket.lead_text == shown + " · " + str(facts[0])
		and ticket.detail_text == str(facts[1])
		and ticket.visible and ticket.is_visible_in_tree()
		and ticket.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and ticket.focus_mode == Control.FOCUS_NONE
		and not ticket.header_text.contains(id) and not ticket.lead_text.contains(id)
		and RunRouteAtlas.ChoiceTicket.FONT_SIZE >= 18,
		where + ": real area, floor, stop and truthfully limited cost/outcome")
	if kind == "Shop":
		_check(shown == "Peddler"
			and not ticket.lead_text.contains("Browse")
			and not ticket.detail_text.contains("Remove")
			and not ticket.detail_text.contains("removal")
			and not ticket.lead_text.contains("5 cards")
			and not ticket.detail_text.contains("75 gold"),
			where + ": legal Shop ticket never advertises the retired five-card shop or removal")





func _display_kind(kind: String) -> String:
	if kind == "Rest":
		return "Campfire"
	return "Peddler" if kind == "Shop" else kind


func _marker(app, id: String) -> Button:
	var button := app.route_atlas.get_node_or_null("Node_" + id + "/Action") as Button
	_check(button != null and button.is_visible_in_tree(), "actual highlighted marker mounted")
	return button


func _button(app, id: String) -> Button:
	for button in app.route_buttons:
		if button.get_meta("route_id") == id:
			return button
	_check(false, "legal chooser button exists: " + id)
	return null


func _inert(app, callback: Callable, id: String, reason: String) -> void:
	var before := _snapshot(app)
	var controls: Array = [app.route_view, app.route_atlas, app.route_atlas_overlay,
		app.route_map_button, root.gui_get_focus_owner()]
	callback.call(id)
	_check(_snapshot(app) == before and controls == [app.route_view, app.route_atlas,
		app.route_atlas_overlay, app.route_map_button, root.gui_get_focus_owner()], reason)


## Mounted app opens an honest three-floor viewport, not the full distant map.
func _tokens(atlas: RunRouteAtlas) -> void:
	var expected := {
		"SewingCircle": "res://assets/paper/ui/map_node_sewing_circle.png",
		"Campfire": "res://assets/paper/ui/map_node_campfire.png",
		"Unpicker": "res://assets/paper/ui/map_node_unpicker.png",
	"PatchStall": "res://assets/paper/ui/map_node_patch_stall.png",
		"Fight": "res://assets/paper/ui/map_node_fight.png",
		"Elite": "res://assets/paper/ui/map_node_elite.png",
		"Event": "res://assets/paper/ui/map_node_event.png",
		"Shop": "res://assets/paper/ui/map_node_shop.png",
		"Peddler": "res://assets/paper/ui/map_node_peddler.png",
		"Rest": "res://assets/paper/ui/map_node_rest.png",
		"Boss": "res://assets/paper/ui/map_node_boss.png",
	}
	var floors := atlas._map.get_floors()
	var actual_ids: Dictionary = {}
	var legal_buttons := 0
	var journal := atlas.get_node_or_null("JourneyJournal") as RunRouteAtlas.JourneyJournal
	_check(journal != null and journal.current_floor == 0
		and journal.current_area.is_empty() and journal.next_floor == 1
		and journal.next_area == "Meadow" and journal.visited.is_empty()
		and journal.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"real app mounts left journey journal from actual opening")
	for child in atlas.get_children():
		if not (child is PanelContainer):
			continue
		var id: String = child.get_meta("route_id")
		var actual := atlas._map.get_node(id)
		var shown: String = _display_kind(String(actual.type))
		actual_ids[id] = true
		_check(actual.floor >= 1 and actual.floor <= 3
			and child.get_meta("route_kind") == actual.type
			and child.get_meta("display_kind") == shown
			and Rect2(child.position, child.size).intersects(RunRouteAtlas.PAGE_RIGHT),
			"real app shows only next three floors on the right page " + id)
		var art := child.get_node_or_null("Art") as RunRouteAtlas.NodeToken
		if actual.type == "Rest":
			var caption := child.get_node_or_null("Identity") as Label
			_check(child.get_meta("route_kind") == "Rest" and shown == "Campfire"
				and caption != null and caption.text.ends_with("Campfire")
				and art != null and art.get_meta("art_path") == expected.Campfire,
				"mounted opening legal/future Rest retains source identity and presents Campfire")
		_check(art != null and art.token_kind == shown
			and art.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"real patch carries its sewn stop emblem " + id)
		if expected.has(shown) and ResourceLoader.exists(expected[shown], "Texture2D"):
			_check(art != null and art.token_texture == load(expected[shown]),
				"real app uses original sewn token image for " + id)
		else:
			_check(art != null and art.token_texture == null,
				"real app keeps drawn Treasure or unavailable-art fallback " + id)
		var hover := _expected_hover(actual, atlas._map.get_legal_choices().has(id))
		_check(child.tooltip_text == hover and not child.tooltip_text.contains(id),
			"real opening patch hover names its real floor, kind and branch " + id)
		var action := child.get_node_or_null("Action") as Button
		if atlas._map.get_legal_choices().has(id):
			legal_buttons += 1
			var shortcut: int = atlas._rendered_shortcuts.find(id) + 1
			_check(action != null and action.is_visible_in_tree()
				and shortcut >= 1 and shortcut <= 4
				and action.tooltip_text == "Choose " + hover + " (key %d)" % shortcut
				and not action.tooltip_text.contains(id),
				"real opening has exact canonical legal action " + id)
		else:
			_check(action == null, "future off-floor nodes are inert " + id)
	var node_count := 0
	for floor_number in range(3):
		for node in floors[floor_number]:
			node_count += 1
			_check(actual_ids.has(node["id"]),
				"every authored visible floor 1-3 patch appears on the mounted book")
	var opening_legal := atlas._map.get_legal_choices()
	_check(not opening_legal.is_empty(), "mounted opening has genuine legal patch choices")
	if not opening_legal.is_empty():
		_check_ticket(atlas, opening_legal[0], "opening ticket uses first authentic next stop")
	_check(actual_ids.size() == node_count
		and legal_buttons == atlas._map.get_legal_choices().size(),
		"real app shows exactly the window and all 3-4 opening choices")


## Value-only ledger so the direct chooser and every atlas input can be compared.
func _values(app) -> Array:
	var carry = app.party_carryover as RunTornCarryover
	var battle: Variant = null
	if app.deck != null:
		battle = [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
			app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
			app.enemies.get_enemies(), app.enemy_intents.get_intents()]
	return [app.run_map.get_floors(), app.run_map.get_route(),
		app.run_map.get_legal_choices(), app.run_map.get_current_node_id(),
		app.run_rng.state, app.encounter_id, app.run_deck.duplicate(),
		app.run_heroes.duplicate(true), app.session_gold, app.run_scraps,
		app.run_trinkets.duplicate(), app.run_removal_count,
		app.run_stitch_descriptors.duplicate(true), app.run_next_stitch_id,
		carry.read_state() if carry != null else null,
		app.act_outcome.get_state() if app.act_outcome != null else null,
		app._placeholder_route.duplicate(), battle]


## Each legal opening kind must mount its own existing flow, never a no-op.
func _assert_flow(app, kind: String, id: String, rng_state: int) -> void:
	if kind in ["Fight", "Elite"]:
		_check(app.deck != null and app.battle_view != null and app.battle_view.is_visible_in_tree(),
			"typed %s opening mounts the real mounted battle" % kind)
		if app.deck == null:
			return
		var pools: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RunAuthoredBattleEntry.POOLS_PATH))
		_check(pools[kind].has(app.encounter_id), "selected encounter belongs to the actual %s pool" % kind)
		var rng := RandomNumberGenerator.new()
		rng.state = rng_state
		var ids: Array = pools[kind].keys()
		ids.sort()
		_check(app.encounter_id == ids[rng.randi_range(0, ids.size() - 1)],
			"one sorted %s selection draw on the uninterrupted run RNG" % kind)
		# Entry legitimately draws the typed encounter and then shuffles the same
		# RNG for the hand; the mounted deck must match that continuation exactly.
		var reference := CombatDeck.new(app.run_deck, rng)
		var chosen: Dictionary = pools[kind][app.encounter_id]
		var catalog: Array = []
		for path in RunAuthoredBattleEntry.CATALOG_PATHS:
			catalog.append_array(RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(path)))
		var definitions: Array = []
		for enemy_id in chosen.enemy_ids:
			var matches := catalog.filter(func(record): return record.id == enemy_id)
			_check(matches.size() == 1, "unique authored weighted enemy: " + enemy_id)
			if matches.size() == 1:
				definitions.append(matches[0])
		var roster := CombatEnemies.new(definitions)
		var party := CombatParty.new(app.run_heroes)
		var schedule := RunFightEncounterSelection._parse_schedule_text(
			FileAccess.get_file_as_string(chosen.schedule))
		var independent := CombatEnemyIntents.new(schedule)
		_check(roster.is_valid() and party.is_valid()
			and independent.bind_battle(roster, party, rng),
			"authored typed roster, genuine party and run RNG bind first weighted batch")
		_check(app.enemy_intents.is_bound()
			and app.enemy_intents.get_intents() == independent.get_intents(),
			"mounted typed announcement equals independently seeded oracle")
		_check(reference.start_turn(), "independent deck starts from the seeded selection state")
		_check(app.deck.hand == reference.hand and app.deck.draw_pile == reference.draw_pile
			and app.deck.discard_pile == reference.discard_pile
			and app.run_rng.state == rng.state and app.deck._rng == app.run_rng,
			"typed selection and real hand share one uninterrupted seeded stream")
		_check(app.deck.energy == 3 and app.deck.hand.size() == 5 and app.deck.turn_active,
			"real hand opens at three energy and five cards")
		_check(app._current_act_battle() and app._current_carryover_fight()
			and app.act_outcome.get_state().pending_node_id == id,
			"live outcome latch and torn witness bind the actual %s battle" % kind)
		return
	if kind == "Unpicker":
		_check(app.unpicker_view != null and app.unpicker_view.is_visible_in_tree()
			and app.unpicker_visit.is_valid() and app.run_rng.state == rng_state
			and app.route_view == null, "Unpicker mounts authentic visit without RNG")
		return
	if kind in ["Campfire", "Rest"]:
		_check(app.campfire_view != null and app.campfire_view.is_visible_in_tree()
			and app.campfire_visit.read_state().status == RunCampfireVisit.OPEN
			and app.run_rng.state == rng_state and app.route_view == null, "Campfire mounts two-choice visit without RNG")
		return
	if kind == "Shop":
		_check(app.shop_view != null and app.shop_view.is_visible_in_tree()
			and app.peddler_visit != null and app.peddler_visit.is_open()
			and app.peddler_buttons.size() == 4 and app.peddler_heroes.item_count == 3
			and app.peddler_leave_button.is_visible_in_tree() and app.route_view == null,
			"Shop marker mounts one seeded Peddler visit with four buys and Leave")
		var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
		var rng := RandomNumberGenerator.new()
		rng.state = rng_state
		var owners: Array[String] = []
		for hero in app.run_heroes:
			owners.append(hero.id)
		var expected_cards: Array = []
		var catalogs: Array = [StarterCards.new(), WardenPoolCards.new(), SeamstressPoolCards.new(),
			TinkerPoolCards.new(), LanternMonkPoolCards.new(), RagDuelistPoolCards.new(),
			ScarecrowPoolCards.new(), YarnRangerPoolCards.new()]
		for owner in owners:
			var pool: Array = []
			for candidate in authored.cards:
				var card_owner := ""
				var is_pool := false
				for catalog_index in range(catalogs.size()):
					var catalog = catalogs[catalog_index]
					if catalog.has_card(candidate.id):
						card_owner = catalog.get_definition(candidate.id).get("owner", "")
						is_pool = catalog_index > 0
						break
				if card_owner == owner and not (is_pool and candidate.id.ends_with("_plus")):
					pool.append(candidate)
			pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
			_check(not pool.is_empty(), "independent Peddler oracle has authored candidates for this party owner")
			if pool.is_empty():
				return
			var chosen: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
			expected_cards.append({"id": chosen.id, "owner": owner, "price": int(chosen.price), "sold": false})
		var patch_pool: Array = []
		for candidate in authored.trinkets:
			if not app.run_trinkets.has(candidate.id):
				patch_pool.append(candidate)
		patch_pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
		_check(not patch_pool.is_empty(), "independent Peddler oracle has an unowned patch candidate")
		if patch_pool.is_empty():
			return
		var patch: Dictionary = patch_pool[rng.randi_range(0, patch_pool.size() - 1)]
		var expected_stock := {"cards": expected_cards,
			"trinkets": [{"id": patch.id, "price": int(patch.price), "sold": false}]}
		var state: Dictionary = app.peddler_visit.read_state()
		_check(state.ok and state.stock == expected_stock and app.run_rng.state == rng.state,
			"Peddler stock and four-draw RNG state match independent sorted-pool oracle")
		for index in range(3):
			var offer: Dictionary = expected_cards[index]
			_check(app.peddler_buttons[index].get_meta("offer_id") == offer.id
				and app.peddler_buttons[index].text.contains("%d gold" % offer.price),
				"visible owner card choice matches authored ID and quote")
		_check(app.peddler_buttons[3].get_meta("offer_id") == patch.id
			and app.peddler_buttons[3].text.contains("%d gold" % patch.price),
			"visible patch choice matches authored ID and quote")
		_check(app.session_gold == 0 and app.run_deck.size() == 12,
			"Peddler opening changes no run deck or wallet")
		return
	_check(app.route_view != null and app.route_view.is_visible_in_tree()
		and app._placeholder_route == [id] and app.deck == null
		and app.run_rng.state == rng_state and app.encounter_id == "",
		"placeholder marker mounts the actual connected choices without effects")
	_check(not app.route_buttons.is_empty()
		and app.route_buttons.all(func(button: Button) -> bool: return not button.disabled),
		"placeholder offers its real connected route")


func _leave_flow(app, kind: String) -> void:
	if kind == "Event" and is_instance_valid(app.quiet_spool_panel):
		_check(app.route_view == null, "Event exit requires completing its pending choice")
		await _click(app.quiet_spool_panel.get_choice_buttons()[1])
	if kind == "PatchStall":
		await _click(app.patch_stall_view.leave_button)
	if kind == "SewingCircle":
		await _click(app.sewing_leave_button)
		_check(not app._sewing_closed and not app.sewing_view.confirm_button.disabled, "Leave previews before explicit confirmation")
		await _click(app.sewing_view.confirm_button)
	if kind == "Unpicker":
		await _click(app.unpicker_leave_button)
	if kind in ["Campfire", "Rest"]:
		await _click(app.campfire_leave_button)
	if kind == "Shop":
		await _click(app.peddler_leave_button)
	var back: Button
	if kind == "Shop":
		back = app.route_back_button
	elif kind in ["Event", "Treasure", "Campfire", "Rest", "Unpicker", "PatchStall", "SewingCircle"]:
		back = app.route_back_button
	else:
		back = app.return_button
	_check(is_instance_valid(back) and back.is_visible_in_tree(),
		"actual %s exit control is mounted" % kind)
	if not is_instance_valid(back):
		return
	await _click(back)
	await process_frame
	_check(app.run_map == null and app.run_rng == null and app.deck == null
		and app.title_view.visible and app.start_button.has_focus()
		and app.route_view == null and app.route_atlas == null,
		"%s exit clears the seeded session and restores the title" % kind)


## Mouse, Enter and Space on the actual marker must match the direct chooser.
func _legal_openings(app) -> void:
	var cases: Array = []
	for kind in ["Rest", "Shop", "Event", "Treasure", "Elite", "Campfire", "Unpicker"]:
		var found: Array = []
		for value in range(1, 1000):
			var rng := RandomNumberGenerator.new()
			rng.seed = value
			var map := RunMap.new()
			map.generate(rng)
			for id in map.get_legal_choices():
				if map.get_node(id).type == kind:
					found = [kind, value, id]
					break
			if not found.is_empty():
				break
		_check(not found.is_empty(), "bounded real opening exists for " + kind)
		if not found.is_empty():
			cases.append(found)
	for fixture in cases:
		var kind: String = fixture[0]
		var replay: Array = []
		for mode in range(5):
			app.run_seed = fixture[1]
			await _click(app.route_button)
			_check(app.run_map != null and app.route_view != null
				and app.run_map.get_legal_choices().has(fixture[2])
				and app.run_map.get_node(fixture[2]).type == kind,
				"seeded %s opening is a real legal choice" % kind)
			if app.run_map == null:
				continue
			var rng_state: int = app.run_rng.state
			var callback := Callable()
			var cleared: Array = []
			var marker: Button
			if mode == 0:
				marker = _button(app, fixture[2])
			else:
				await _click(app.route_map_button)
				_check(app.route_atlas_overlay != null and app.route_atlas != null
					and app.route_atlas._map == app.run_map,
					"real atlas bound for the legal %s opening" % kind)
				if app.route_atlas == null:
					continue
				callback = app.route_atlas.node_requested.get_connections()[0].callable
				var atlas: RunRouteAtlas = app.route_atlas
				atlas.tree_exiting.connect(func(): cleared.append(atlas._map == null))
				marker = _marker(app, fixture[2])
				var explanation_before := _values(app)
				if marker != null:
					marker.grab_focus()
					_check_ticket(atlas, fixture[2], "live " + kind + " keyboard help")
					var motion := InputEventMouseMotion.new()
					motion.position = marker.get_global_rect().get_center()
					root.push_input(motion, true)
					await process_frame
					_check_ticket(atlas, fixture[2], "live " + kind + " pointer help")
					motion = InputEventMouseMotion.new()
					motion.position = Vector2(10.0, 690.0)
					root.push_input(motion, true)
					await process_frame
					_check_ticket(atlas, fixture[2], "live " + kind + " mouse exit restores focus")
					_check(_values(app) == explanation_before,
						"live " + kind + " guidance leaves deck/wallet/map/RNG unspent")
				_check(marker != null and marker.focus_mode == Control.FOCUS_ALL
					and marker.mouse_filter == Control.MOUSE_FILTER_STOP
					and marker.get_parent().get_meta("route_state") == "legal",
					"newly legal %s marker is clickable and focusable" % kind)
				# The live legal marker keeps its committed token, or a readable drawn face.
				if marker != null:
					var panel := marker.get_parent() as PanelContainer
					var art := panel.get_node_or_null("Art") as RunRouteAtlas.NodeToken
					if kind == "Rest":
						_check(panel.get_meta("route_kind") == "Rest"
							and panel.get_meta("display_kind") == "Campfire"
							and panel.get_node("Identity").text.ends_with("Campfire"),
							"legal opening Rest caption presents Campfire with original route metadata")
					if kind in ["Fight", "Elite", "Event", "Shop", "Rest", "Boss"]:
						var shown: String = _display_kind(kind)
						var art_path := "res://assets/paper/ui/map_node_" + shown.to_lower() + ".png"
						var expected_texture: Texture2D = null
						if ResourceLoader.exists(art_path, "Texture2D"):
							expected_texture = load(art_path) as Texture2D
						_check(art != null and art.token_kind == shown
							and str(art.get_meta("art_path")) == art_path
							and art.token_texture == expected_texture
							and (expected_texture != null or shown == "Peddler"
								or (shown == "Campfire" and RunRouteAtlas.NodeToken.fallback_plan(shown)["glyph"] == "C")),
							"live legal %s marker shows the %s stop's committed sewn token" % [kind, shown])
						if kind == "Shop":
							_check(panel.get_node("Identity").text.ends_with("Peddler")
								and panel.get_meta("route_kind") == "Shop"
								and panel.get_meta("display_kind") == "Peddler"
								and (expected_texture != null
									or RunRouteAtlas.NodeToken.fallback_plan("Peddler")["emblem"] == "purse"),
								"live legal Shop marker keeps its authored type and wears Peddler art or purse")
					else:
						_check(panel.get_node_or_null("Identity") is Label,
							"live legal %s marker keeps its readable drawn identity" % kind)
			if marker == null:
				continue
			if mode == 1:
				await _click(marker)
			elif mode == 4:
				var shortcut: int = app.route_atlas._rendered_shortcuts.find(fixture[2])
				_check(shortcut >= 0 and shortcut < 4, "legal opening has a physical number shortcut")
				for down in [true, false]:
					var event := InputEventKey.new()
					event.keycode = (KEY_1 + shortcut) as Key
					event.physical_keycode = event.keycode
					event.pressed = down
					root.push_input(event, true)
					await process_frame
			else:
				marker.grab_focus()
				_check(marker.has_focus(), "actual atlas marker keyboard focus: " + kind)
				await _key(KEY_ENTER if mode == 2 else KEY_SPACE)
			if callback.is_valid():
				_check(cleared == [true] and app.route_atlas == null,
					"accepting a legal %s marker clears the atlas before disposal" % kind)
			_check(app.run_map.get_route() == [fixture[2]]
				and app.run_map.get_current_node_id() == fixture[2],
				"%s opening commits exactly one selected node" % kind)
			if kind == "Event":
				_check(app.quiet_spool_panel != null and app.route_view == null
					and not app._can_choose_connected_route(), "atlas Event mounts pending authored choice")
				if app.quiet_spool_panel != null:
					await _click(app.quiet_spool_panel.get_choice_buttons()[1])
				_check(app.run_scraps == 0, "atlas Ignore preserves zero-scrap wallet")
			_assert_flow(app, kind, fixture[2], rng_state)
			if mode == 0:
				replay = _values(app)
			else:
				_check(_values(app) == replay,
					"atlas %s input matches the direct chooser ledger and RNG" % kind)
			if callback.is_valid():
				_inert(app, callback, fixture[2], "accepted atlas %s request cannot replay" % kind)
			await _leave_flow(app, kind)
			if callback.is_valid():
				callback.call(fixture[2])
				_check(app.run_map == null and app.title_view.visible
					and app.route_view == null and app.deck == null,
					"accepted %s atlas request cannot reopen the next session" % kind)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.run_seed = 6
	var id := "f01_n0"
	var replay: Array = []
	var stale: Array[Callable] = []
	# Same scene, title resets, same seed: chooser, mouse atlas, Enter atlas, Space atlas.
	for mode in range(4):
		await _click(app.route_button)
		_check(app.run_map != null and app.run_map.get_node(id).type == "Fight",
			"seed has legal opening Fight")
		for callback in stale:
			_inert(app, callback, id, "disposed listener cannot affect restarted session")
		if mode == 0:
			await _click(app.route_buttons[0])
		else:
			await _click(app.route_map_button)
			var atlas: RunRouteAtlas = app.route_atlas
			var cleared: Array = []
			atlas.tree_exiting.connect(func(): cleared.append(atlas._map == null))
			_check(atlas.node_requested.get_connections().size() == 1, "exactly one app listener")
			var callback: Callable = atlas.node_requested.get_connections()[0].callable
			_tokens(atlas)
			var opening_before := _values(app)
			var actual_ids: Array[String] = app.run_map.get_legal_choices()
			_check(actual_ids.size() >= 3, "real opening has three selectable kind-bearing markers")
			if actual_ids.size() >= 2:
				var a := _marker(app, actual_ids[0])
				var b := _marker(app, actual_ids[1])
				a.grab_focus()
				_check_ticket(atlas, actual_ids[0], "mounted first focused stop")
				b.grab_focus()
				_check_ticket(atlas, actual_ids[1], "mounted other focused stop")
				var pointer := InputEventMouseMotion.new()
				pointer.position = a.get_global_rect().get_center()
				root.push_input(pointer, true)
				await process_frame
				_check_ticket(atlas, actual_ids[0], "mounted pointer overrides different focus")
				pointer = InputEventMouseMotion.new()
				pointer.position = Vector2(10.0, 690.0)
				root.push_input(pointer, true)
				await process_frame
				_check_ticket(atlas, actual_ids[1], "mounted pointer exit restores second focus")
			_check(_values(app) == opening_before,
				"real app guidance only changes displayed ticket; no wallet, deck or seeded RNG change")
			for old in stale:
				_inert(app, old, id, "old listener cannot affect new mounted overlay")
			stale.append(callback)
			# Forge each captured identity independently while all other sources stay valid.
			for index in range(5):
				var args: Array = callback.get_bound_arguments()
				args[index] = weakref(app.route_back_button)
				var forged := Callable(app, "_choose_atlas_opening").bindv(args)
				_inert(app, forged, id, "forged captured identity rejected: " + str(index))
			_inert(app, callback, "unknown", "unknown signal rejected")
			_inert(app, callback, "f02_n0", "future signal rejected")
			# Every legal floor-one kind is admitted now; only a kind outside the
			# run's supported floor kinds stays inert without changing any state.
			for opening in app.run_map.get_legal_choices():
				if app.run_map.get_node(opening).type != "Fight":
					_check(_marker(app, opening) != null,
						"newly legal non-Fight marker mounted: " + opening)
			var supported_id := "f01_n1"
			var saved_kind: String = app.run_map._nodes[supported_id].type
			app.run_map._nodes[supported_id].type = "Boss"
			_inert(app, callback, supported_id, "unsupported opening kind rejected")
			app.run_map._nodes[supported_id].type = saved_kind
			app.route_buttons[0].disabled = true
			_inert(app, callback, id, "disabled matching chooser rejects signal")
			app.route_buttons[0].disabled = false
			var original_id = app.route_buttons[0].get_meta("route_id")
			app.route_buttons[0].set_meta("route_id", "forged")
			_inert(app, callback, id, "forged chooser identity rejected")
			app.route_buttons[0].set_meta("route_id", original_id)
			var map = app.run_map
			var foreign := RunMap.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = 6
			_check(foreign.generate(rng), "foreign generated map fixture")
			app.run_map = foreign
			_inert(app, callback, id, "foreign live map rejected")
			app.run_map = map
			atlas.bind_map(foreign)
			_inert(app, callback, id, "foreign atlas binding rejected")
			atlas.bind_map(map)
			_check(map.choose_node(id), "external route progress fixture")
			_inert(app, callback, id, "changed route rejects listener")
			var empty_route: Array[String] = []
			_check(map.undo_choice(id, empty_route), "restore external route fixture")
			app.route_atlas_overlay.remove_child(atlas)
			_inert(app, callback, id, "detached atlas rejected")
			app.route_atlas_overlay.add_child(atlas)
			var overlay = app.route_atlas_overlay
			app.remove_child(overlay)
			_inert(app, callback, id, "detached overlay rejected")
			app.add_child(overlay)
			cleared.clear()
			var marker := _marker(app, id)
			if marker == null:
				break
			if mode == 1:
				await _click(marker)
			else:
				marker.grab_focus()
				_check(marker.has_focus(), "actual atlas marker keyboard focus")
				await _key(KEY_ENTER if mode == 2 else KEY_SPACE)
			_check(cleared == [true] and app.route_atlas == null, "acceptance clears atlas before disposal")
		_check(app.deck != null and app.battle_view != null and app.battle_view.is_visible_in_tree(),
			"actual input mounts routed battle")
		if app.deck == null:
			break
		_check(app.run_map.get_route() == [id] and app.route_view == null
			and app.hand_view.get_child_count() == 5 and app.deck._rng == app.run_rng,
			"exactly one route commit with real hand and shared RNG")
		var state := _snapshot(app)
		if mode == 0:
			replay = state
		else:
			_check(state == replay, "atlas matches direct graph/encounter/party/deck/enemies/RNG")
		for callback in stale:
			_inert(app, callback, id, "disposed callback cannot enter twice or alter battle")
			_inert(app, callback, "f01_n1", "disposed non-Fight signal cannot alter battle")
		await _click(app.return_button)
		await process_frame
	# Every other legal opening kind must work from the same mounted atlas.
	await _legal_openings(app)
	app.run_seed = 6
	# Failed admission must expose a usable chooser and roll back the transaction.
	await _click(app.route_button)
	var before := _snapshot(app)
	await _click(app.route_map_button)
	app.fight_selection._selected[id] = {"success": false}
	await _click(_marker(app, id))
	_check(app.route_atlas == null and app.route_view.is_visible_in_tree()
		and app.route_buttons[0].has_focus() and _snapshot(app) == before,
		"failed atlas startup restores exact chooser/models/RNG")
	app.fight_selection._selected.clear()
	await _click(app.route_buttons[0])
	_check(app.deck != null and _snapshot(app) == replay, "failed atlas entry retries with identical seeded battle")
	await _click(app.return_button)
	# Same graph regenerated on the same object must invalidate a saved listener.
	await _click(app.route_button)
	await _click(app.route_map_button)
	var callback: Callable = app.route_atlas.node_requested.get_connections()[0].callable
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	_check(app.run_map.generate(rng), "same-object regeneration fixture")
	_inert(app, callback, id, "generation mismatch rejects even identical graph")
	app._return_to_title()
	await process_frame
	await _click(app.route_button)
	_inert(app, callback, id, "title reset invalidates old listener")
	await _click(app.route_map_button)
	var back_callback: Callable = app.route_atlas.node_requested.get_connections()[0].callable
	app._cancel_route()
	await process_frame
	await _click(app.route_button)
	_inert(app, back_callback, id, "Back invalidates old listener")
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_atlas_opening_choice_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
