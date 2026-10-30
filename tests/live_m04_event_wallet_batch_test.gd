extends "res://tests/live_event_treasure_continuation_test.gd"
## Genuine seeded opening routes through all three specials to each generic Event.

const REQUIRED := ["button_trail", "loose_seam", "thimble_well", "frayed_signpost",
	"needle_gate", "quilting_bee", "estate_sale", "lantern_moth_clearing",
	"patchwork_ferry", "spool_clocktower", "ragpicker_cart", "quilt_bridge",
	"button_moon_festival", "v3_raincoat_bridge", "v3_puppet_box_office",
	"v3_mismatched_mittens", "v3_coil_and_crow", "v3_patchwork_lighthouse", "v3_button_orchard"]
## The six V3-4 roadside stories that the shipped catalog always requires.
## Later additive roadside records are optional: the live loader accepts them
## when present (including a legal 2-choice form) and never requires them.
const ORIGINAL_ROADSIDE := ["v3_raincoat_bridge", "v3_puppet_box_office",
	"v3_mismatched_mittens", "v3_coil_and_crow", "v3_patchwork_lighthouse", "v3_button_orchard"]
var gold_purchases := 0
var new_hero_receipts := {}
var fixture_fallback_used := false


func _party_ids() -> Array:
	var ids: Array = []
	var heroes: Array = app.run_heroes if app.run_map != null else CombatParty.new(app._load_party_definitions()).get_heroes()
	for hero in heroes:
		ids.append(hero.id)
	return ids


func _required_ids() -> Array:
	var ids := REQUIRED.duplicate()
	for record in RunV3HeroEventOffers.new(_party_ids()).get_offers():
		ids.append(record.id)
	ids.append("v3_emberglass_campfire")
	return ids


func _combined_catalog(include_party: bool = true) -> Dictionary:
	var events: Array = []
	for path in ["res://data/events/m04_events.json", "res://data/events/v3_roadside_events.json"]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		events.append_array(document.events.duplicate(true))
	var waystation := RunV3ServiceWaystationEventGate.new()
	var emberglass := waystation.get_event_record("v3_emberglass_campfire")
	_check(waystation.is_catalog_valid() and not emberglass.is_empty(),
		"fixture contains authenticated Emberglass record")
	if not emberglass.is_empty():
		events.append(emberglass)
	if include_party:
		events.append_array(RunV3HeroEventOffers.new(_party_ids()).get_offers())
		if not app._fate_pin_seen:
			var auction: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/events/mpw_fate_pin_auction.json"))
			for key in ["hp_cost", "minimum_hp", "gold_cost", "exit_scraps", "offer_count", "visit_weight"]:
				auction[key] = int(auction[key])
			events.append(auction)
	return {"events": events}


func _event_path(map: RunMap, choices: Array, remaining: int) -> Array:
	for id in choices:
		var node := map.get_node(id)
		if node.type not in ["Event", "Treasure", "Campfire", "Unpicker", "Rest"]:
			continue
		var needed := remaining - (1 if node.type == "Event" else 0)
		if needed == 0:
			return [id]
		var tail := _event_path(map, node.outgoing, needed)
		if not tail.is_empty():
			return [id] + tail
	return []


const EVENT_WALLET_HINTS := preload("res://tests/event_wallet_hints.gd")
## Historical seeds are candidates, not permanent Event assignments: both map
## generation and sorted-pool appends can change what a seed genuinely reaches.
## Rebuild each witness through the real map/toll and an independent one-draw
## oracle; the mounted panel below must agree with that oracle's ID and RNG.
const HISTORICAL_WITNESS_SEEDS := [449195, 807198, 4045188, 723106,
	1634832, 9848435, 1405687, 12876289, 611184, 1333364, 1390606,
	2017177, 292590, 2431350, 5158685, 7959444]
## The hero-tied stories added by this batch: each must reach the real routed
## panel through the ordinary required-ID loop below and settle its authored
## signed wallet change at least once.
const NEW_HERO_STORIES := ["v3_warden_buckle_checkpoint",
	"v3_seamstress_crimson_mending_queue", "v3_tinker_gear_sideshow"]
## The six Candlelit Bargain stories promoted into the live M04 catalog. The live
## two-source loader must carry each exactly once so the run map can offer it.
const PROMOTED_CANDLELIT := ["lantern_bobbin_ferry", "thimble_star_reading",
	"moonpatch_archway", "blacklace_swap_table", "crooked_marionette", "dusk_post_bobbin"]


func _generic_route_ids() -> Array:
	var ids := RunM04EventRotation.new(_combined_catalog()).get_generic_event_ids()
	if not app._frayed_debt_seen:
		ids.append("frayed_debt_parcel")
	ids.sort()
	return ids


func _fixtures() -> Dictionary:
	var found := {}
	var ids: Array = _generic_route_ids()
	_check(not ids.is_empty(), "fixture oracle has a genuine eligible Event pool")
	if ids.is_empty():
		return found
	ids.sort()
	var required_ids := _required_ids()
	fixture_fallback_used = false
	# Treasure traversal consumes no RNG or wallet; allow it between the six
	# authentic Events rather than requiring a rare six-consecutive-Event route.
	# Revalidate the known genuine witness seeds first (tests/event_wallet_hints.gd,
	# append-only); the bounded search remains a fallback when the route/pool changes.
	var hints: Array = EVENT_WALLET_HINTS.SEEDS.duplicate()
	hints.append_array(HISTORICAL_WITNESS_SEEDS)
	# Accepted genuine witnesses from the earlier lane, retained alongside the
	# newer append-only helper so both sets remain available after the rebase.
	# The final six were re-derived after the Candlelit Bargain batch joined the
	# shipped generic pool, so every required ID still has a genuine six-Event
	# route without relying on the bounded fallback search.
	hints.append_array([35510, 233942, 236527, 292590, 379017, 422169,
		449195, 529380, 610125, 622337, 756725, 802796, 807198, 899240,
		1223721, 1333364, 1363210, 1433081, 1463887, 1610275,
		1634509, 1658568, 1825487, 1892422, 2308951, 2356714,
		2440227, 2757529, 3274715, 3525463, 3933498, 4969863,
		696642, 2703008, 3782438, 5142127, 5281000,
		4084937, 9640103, 8405118, 444032, 4586354, 7946489])
	# Genuine six-Event witnesses re-derived after the six gothic trade tales
	# joined the roadside pool, so every required ID keeps a real route without
	# relying on the bounded fallback search.
	hints.append_array([576647, 822958, 883989, 2535428, 3023381, 4388231])
	# Genuine six-Event witnesses re-derived with the once/run Auction candidate.
	hints.append_array([1571440, 2266626, 2453554, 3103369, 4080424,
		4932458, 5100312, 7382439, 8719337, 9036654])
	# Genuine map/toll witnesses after the Copper-Chain through Raven-Sewn
	# hero stories expanded the sorted pool. Keep all previous candidates.
	hints.append_array([931076, 1667572, 4268604, 4278127, 7006462, 7547920])
	# Genuine map/toll witnesses for the shifted sorted pool after admitting
	# Emberglass; IDs and draws are always revalidated below, not pinned here.
	hints.append_array([236051, 316683, 90763, 200641, 33752])
	for candidate_index in range(hints.size() + 499999):
		var value: int
		if candidate_index < hints.size():
			value = hints[candidate_index]
		else:
			fixture_fallback_used = true
			value = candidate_index - hints.size() + 1
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var path := _event_path(map, map.get_legal_choices(), 6)
		if path.is_empty():
			continue
		var toll := RunNeedleToll.new({"heroes": CombatParty.new(app._load_party_definitions()).get_heroes(),
			"wallet": {"gold": 0, "scraps": 0}, "deck": app._load_starter_deck()}, rng)
		var paid: bool = toll.pay_toll("warden").ok
		_check(paid, "fixture stages real paid toll draws")
		if not paid:
			continue
		var before_draw := rng.state
		var event_id: String = ids[rng.randi_range(0, ids.size() - 1)]
		if not found.has(event_id):
			var events: Array = []
			var transit := {}
			var treasures: Array = []
			for id in path:
				if map.get_node(id).type != "Event":
					treasures.append(id)
				else:
					transit[id] = treasures.duplicate()
					treasures.clear()
					events.append(id)
			found[event_id] = {"seed": value, "path": events.slice(0, 5), "next": events[5], "transit": transit,
				"before_draw": before_draw, "after_draw": rng.state}
		var complete := true
		for required in required_ids:
			complete = complete and found.has(required)
		if complete:
			break
	return found


func _catalog_contract() -> void:
	var document := _combined_catalog(false)
	var snapshot := document.duplicate(true)
	var live: Dictionary = app._load_wallet_event_catalog()
	_check(live == document, "live catalog preserves both detached authored catalogs")
	var rotation := RunM04EventRotation.new(live)
	_check(rotation.is_catalog_valid(), "combined catalog validates for the real rotation")
	var ids := rotation.get_generic_event_ids()
	for id in REQUIRED:
		_check(ids.count(id) == 1, "combined eligible pool contains required ID exactly once: " + id)
	for id in PROMOTED_CANDLELIT:
		_check(ids.count(id) == 1, "live two-source loader carries promoted Candlelit story exactly once: " + id)
	_check(not ids.has("quiet_spool"), "Quiet Spool stays on its dedicated special route")
	var expected: Dictionary = preload("res://tests/v3_roadside_events_test.gd").EXPECTED
	for id in expected:
		var matches := rotation.get_generic_events().filter(func(record): return record.id == id)
		_check(matches.size() == 1, "roadside catalog record is eligible: " + id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.title == expected[id].title and record.description == expected[id].description
			and record.choices.size() == 3, "exact authored roadside presentation: " + id)
		var choice_ids := []
		for choice in record.choices:
			choice_ids.append(choice.id)
			_check(expected[id].outcomes.has(choice.id)
				and int(choice.outcome.gold) == expected[id].outcomes[choice.id].gold
				and int(choice.outcome.scraps) == expected[id].outcomes[choice.id].scraps,
				"exact signed roadside outcome: " + id)
		_check(choice_ids == expected[id].choices, "exact three authored roadside choice IDs: " + id)
	live.events.clear()
	_check(document == snapshot and app._load_wallet_event_catalog() == snapshot,
		"returned combined document cannot mutate source or subsequent load")


func _catalog_failures(entry: Callable) -> void:
	var original: String = app.roadside_event_catalog_path
	app.roadside_event_catalog_path = "res://missing_roadside_catalog.json"
	_reject_wallet(entry, "missing roadside catalog")
	var path := OS.get_environment("TEMP").path_join("patchwork_cycle258_roadside_%d.json" % OS.get_process_id())
	app.roadside_event_catalog_path = path
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(original))
	var broken: Array = [null, {}, {"events": [null]}]
	# Duplicated and malformed roadside records always fail closed, old or new.
	# Deleting a record and reducing it to its legal 2-choice form are only
	# malformed for the six ORIGINAL required roadside stories; later additive
	# records follow the shipped additive contract (see below).
	var additive_shapes: Array = []
	for index in range(source.events.size()):
		var record_id: String = source.events[index].get("id", "")
		var original_required: bool = ORIGINAL_ROADSIDE.has(record_id)
		if original_required:
			var missing := source.duplicate(true)
			missing.events.remove_at(index)
			broken.append(missing)
		else:
			additive_shapes.append({"index": index, "id": record_id})
		var duplicate := source.duplicate(true)
		duplicate.events.append(source.events[index].duplicate(true))
		broken.append(duplicate)
		var malformed := source.duplicate(true)
		malformed.events[index].choices[0].outcome.gold = "invalid"
		broken.append(malformed)
		if original_required:
			var two_choices := source.duplicate(true)
			two_choices.events[index].choices.pop_back()
			broken.append(two_choices)
	var collision := source.duplicate(true)
	collision.events.append(_combined_catalog().events[0].duplicate(true))
	broken.append(collision)
	var hero_collision := source.duplicate(true)
	var hero_offers := RunV3HeroEventOffers.new(_party_ids()).get_offers()
	_check(not hero_offers.is_empty(), "collision fixture has eligible authored hero stories")
	if not hero_offers.is_empty():
		hero_collision.events.append(hero_offers[0])
		broken.append(hero_collision)
	for document in broken:
		var file := FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "negative roadside fixture opens outside repository")
		if file == null:
			break
		file.store_string(JSON.stringify(document))
		file.close()
		_reject_wallet(entry, "malformed, missing, duplicate or colliding roadside catalog")
	for addition in additive_shapes:
		var index: int = addition["index"]
		var record_id: String = addition["id"]
		var omitted := source.duplicate(true)
		omitted.events.remove_at(index)
		var file := FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "optional roadside fixture opens outside repository")
		if file == null:
			break
		file.store_string(JSON.stringify(omitted))
		file.close()
		var before := _wallet_state()
		var omission_rotation := RunM04EventRotation.new(app._load_wallet_event_catalog())
		_check(omission_rotation.is_catalog_valid()
			and not omission_rotation.get_generic_event_ids().has(record_id),
			"additive roadside record may be omitted without failing the catalog: " + record_id)
		var trimmed := source.duplicate(true)
		trimmed.events[index].choices.pop_back()
		file = FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "optional two-choice fixture opens outside repository")
		if file == null:
			break
		file.store_string(JSON.stringify(trimmed))
		file.close()
		var trimmed_rotation := RunM04EventRotation.new(app._load_wallet_event_catalog())
		_check(trimmed_rotation.is_catalog_valid()
			and trimmed_rotation.get_generic_event_ids().count(record_id) == 1,
			"additive roadside record keeps its legal 2-choice form: " + record_id)
		_check(_wallet_state() == before, "additive roadside shapes consume no wallet, route or RNG")
	var additive := source.duplicate(true)
	var extra: Dictionary = source.events[0].duplicate(true)
	extra.id = "future_roadside_event"
	additive.events.append(extra)
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "additive roadside fixture opens outside repository")
	if file != null:
		file.store_string(JSON.stringify(additive))
		file.close()
		var before := _wallet_state()
		var rotation := RunM04EventRotation.new(app._load_wallet_event_catalog())
		_check(rotation.is_catalog_valid() and rotation.get_generic_event_ids().has(extra.id),
			"valid future roadside additions join the pool without a fixed total")
		_check(_wallet_state() == before, "catalog validation consumes no state or RNG")
	DirAccess.remove_absolute(path)
	app.roadside_event_catalog_path = original
	var history: Array = app._wallet_event_history.duplicate()
	app._wallet_event_history = RunM04EventRotation.new(_combined_catalog()).get_generic_event_ids()
	var parcel_seen: bool = app._frayed_debt_seen
	app._frayed_debt_seen = true
	_reject_wallet(entry, "exhausted generic rotation including once-per-run Parcel")
	app._frayed_debt_seen = parcel_seen
	app._wallet_event_history = history


func _wallet() -> Dictionary:
	return {"gold": app.session_gold, "scraps": app.run_scraps}


func _other_ledgers() -> Array:
	return [app.run_deck.duplicate(), app.run_heroes.duplicate(true),
		app.run_trinkets.duplicate(), app.run_stitch_descriptors.duplicate(true),
		app.run_next_stitch_id, app.run_removal_count, app.party_carryover.read_state(),
		app.party_carryover.torn.read_state(), app.act_outcome.get_state(),
		app.run_map.get_floors(), app.run_rng.state]


func _wallet_state() -> Array:
	return [_wallet(), _other_ledgers(), app.run_map.get_route(),
		app._wallet_event_history.duplicate(), app.wallet_event_panel,
		app._placeholder_route.duplicate(), app.route_view,
		app.wallet_event_panel._committed_choice.duplicate(true)
			if is_instance_valid(app.wallet_event_panel) else {}]


func _reject_wallet(callback: Callable, label: String) -> void:
	var before := _wallet_state()
	if callback.is_valid():
		callback.call()
	_check(_wallet_state() == before, label + " preserves wallet, all ledgers, route and RNG")


func _reach(fixture: Dictionary, funded: bool = true) -> void:
	app.run_seed = fixture.seed
	await _click(app.start_button)
	preload("res://tests/party_choice.gd").choose(app)
	# Title Start mounts the real pick-three screen first (cycle 332); admit the
	# ordinary three-hero party through its tiles and Continue before expecting a map.
	preload("res://tests/party_choice.gd").choose(app)
	await _frames()
	_check(app.run_map != null and app.run_rng != null, "real title Start creates seeded run")
	var service := RunV3HeroEventOffers.new(_party_ids())
	_check(service.is_valid(), "live three-hero party has a valid authored Event service")
	var live: Dictionary = app._load_wallet_event_catalog()
	_check(live == _combined_catalog(), "live catalog matches eligible actual party oracle")
	var live_ids := RunM04EventRotation.new(live).get_generic_event_ids()
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RunV3HeroEventOffers.CATALOG_PATH))
	var absent := 0
	for record in authored.events:
		if _party_ids().has(record.required_hero):
			_check(live_ids.count(record.id) == 1, "present hero story admitted once: " + record.id)
		else:
			absent += 1
			_check(not live_ids.has(record.id), "absent hero story excluded: " + record.id)
	_check(absent > 0, "live exclusion checks cover genuinely absent heroes")
	var detached := live.duplicate(true)
	live.events.clear()
	_check(app._load_wallet_event_catalog() == detached, "live hero offers remain detached")
	for index in range(3):
		await _traverse_treasures(fixture, fixture.path[index])
		await _click(_route_action(fixture.path[index]))
		var panel: LiveEventChoicePanel = app.quiet_spool_panel if index == 0 \
			else (app.moth_panel if index == 1 else app.dye_vat_panel)
		_check(is_instance_valid(panel) and app.route_view == null, "special Event genuinely mounted and gates route")
		if not is_instance_valid(panel):
			return
		await _click(panel.get_choice_buttons()[(0 if funded else 1) if index == 0 \
			else (2 if index == 1 or not funded else 1)])
	_check(app._quiet_spool_completed and app._moth_completed and app._dye_vat_completed
		and _wallet() == {"gold": 0, "scraps": 2 if funded else 0},
		"three authentic special receipts establish exact opening wallet")
	await _traverse_treasures(fixture, fixture.path[3])
	await _click(_route_action(fixture.path[3]))
	_check(is_instance_valid(app.needle_toll_panel), "fourth Event mounts the inserted toll")
	if not is_instance_valid(app.needle_toll_panel):
		return
	await _click(app.needle_toll_panel.get_choice_buttons()[0])
	_check(is_instance_valid(app.needle_toll_panel) and app._needle_toll_outcome.is_paid(),
		"paid toll preserves the wallet before generic affordability tests")
	if is_instance_valid(app.needle_toll_panel):
		var offers: Array = app._needle_toll_outcome.get_offered_ids()
		var buttons: Array = app.needle_toll_panel.get_choice_buttons()
		_check(offers.size() == 2 and buttons.size() == 3,
			"real paid visit mounts both rare tickets and Skip")
		if offers.size() != 2 or buttons.size() != 3:
			return
		for index in range(2):
			var card := RunPoolCardRewardOffers.resolve_reward_definition(offers[index])
			_check(not card.is_empty(), "routed paid offer resolves to an authored card")
			if card.is_empty():
				return
			_check(buttons[index].text == "Claim %s (%s, rare)\nCost %d energy · %s" % [
				card.display_name, card.owner, card.cost, CardShortRules.line(card)]
				and app.needle_toll_panel._bound_choices[buttons[index]] == offers[index]
				and buttons[index].tooltip_text.begins_with(buttons[index].text + "\nSource positions: ")
				and buttons[index].is_visible_in_tree()
				and Rect2(0, 0, 1280, 720).encloses(buttons[index].get_global_rect()),
				"real app payment exposes the exact offered card powers before selection")
		await _click(app.needle_toll_panel.get_choice_buttons()[2])
	_check(app.needle_toll_panel == null and app._needle_toll_completed
		and _wallet() == {"gold": 0, "scraps": 2 if funded else 0},
		"Skip resumes routing with the exact original wallet including zero-wallet negatives")
	await _traverse_treasures(fixture, fixture.path[4])


func _traverse_treasures(fixture: Dictionary, target: String) -> void:
	for id in fixture.transit[target]:
		var before := [_wallet(), _other_ledgers()]
		var kind: String = app.run_map.get_node(id).type
		await _click(_route_action(id))
		if kind in ["Campfire", "Rest"]:
			await _click(app.campfire_leave_button)
		elif kind == "Unpicker":
			await _click(app.unpicker_leave_button)
		_check(app.run_map.get_current_node_id() == id and kind in ["Treasure", "Campfire", "Unpicker", "Rest"]
			and [_wallet(), _other_ledgers()] == before, "legal free transit changes only the route")


func _return_title() -> void:
	if not is_instance_valid(app.route_view):
		app._return_to_title()
	else:
		await _click(app.route_back_button)
	await _frames()
	_check(app.run_map == null and app.wallet_event_panel == null
		and app._wallet_event_history.is_empty(), "title clears generic session and history")


func _named(fixture: Dictionary, event_id: String, keyboard: bool) -> Array:
	await _reach(fixture)
	var button := _route_action(fixture.path[4])
	var entry: Callable = button.pressed.get_connections()[0].callable
	var rng := RandomNumberGenerator.new()
	rng.state = fixture.before_draw
	_check(app.run_rng.state == rng.state, "live seeded map and paid toll match independent fixture RNG")
	var ids := _generic_route_ids()
	ids.sort()
	var expected_id: String = ids[rng.randi_range(0, ids.size() - 1)]
	var before: Array = _other_ledgers()
	await _click(button)
	var panel: LiveEventChoicePanel = app.wallet_event_panel
	_check(is_instance_valid(panel) and app.route_view == null, "later Event mounts actual wallet panel")
	if not is_instance_valid(panel):
		return []
	var paper_style := panel.paper_panel.get_theme_stylebox("panel")
	if ResourceLoader.exists("res://assets/paper/ui/reward_panel.png", "Texture2D"):
		_check(paper_style is StyleBoxTexture, "real routed Event mounts sewn paper")
		if paper_style is StyleBoxTexture:
			_check(paper_style.texture != null and paper_style.texture.resource_path
				== "res://assets/paper/ui/reward_panel.png", "routed paper uses shipped reward fabric")
	else:
		_check(paper_style is StyleBoxFlat, "real routed Event retains flat fallback")
	var record := panel._selector.get_event()
	_check(record.id == event_id and record.id == expected_id and app.run_rng.state == rng.state
		and rng.state == fixture.after_draw
		and app._wallet_event_history == [event_id], "named Event uses exactly one deterministic draw: " + event_id)
	before[10] = rng.state
	_check(_other_ledgers() == before and _wallet() == {"gold": 0, "scraps": 2},
		"opening consumes only the selection draw")
	_check(panel._wallet_mode and panel._offered_wallet == _wallet()
		and panel.get_choice_buttons().size() == record.choices.size()
		and panel.title_label.text == record.title and panel.description_label.text == record.description,
		"mounted offering preserves actual authored title, story and choice count")
	# Live typography: the real app-mounted Event sews its dynamic caption and
	# number tags in the Theme's display face, while the story and tickets keep
	# the inherited body face and their exact authored/forecast text.
	var heading_face := "res://assets/fonts/LondrinaSolid-Regular.ttf"
	var body_face := "res://assets/fonts/PatrickHand-Regular.ttf"
	var caption := panel.choices_container.get_parent().get_node_or_null("WalletBalance") as Label
	_check(caption != null and caption.text == "Wallet  •  %d gold   /   %d scraps" % [_wallet()["gold"], _wallet()["scraps"]]
		and (caption.get_theme_font("font") as Font).resource_path == heading_face,
		"live wallet caption states exact balances in the display face")
	_check((panel.description_label.get_theme_font("font") as Font).resource_path == body_face
		and (panel.get_choice_buttons()[0].get_theme_font("font") as Font).resource_path == body_face,
		"live story and tickets keep the body face")
	for cue in panel.get_choice_cues():
		_check((cue.get_theme_font("font") as Font).resource_path == heading_face,
			"live sewn tag wears the display face")
	_reject_wallet(entry, "duplicate route input while panel open")
	var commit: Callable = panel.wallet_choice_committed.get_connections()[0].callable
	_reject_wallet(commit.bind({"ok": true, "event_id": event_id, "choice_id": "forged",
		"wallet": {"gold": 999, "scraps": 999}}), "forged signal before physical claim")
	var selected := -1
	for index in range(record.choices.size()):
		var choice: Dictionary = record.choices[index]
		var gold: int = int(choice.outcome.gold)
		var scraps: int = int(choice.outcome.scraps)
		var affordable := 0 + gold >= 0 and 2 + scraps >= 0
		var control: Button = panel.get_choice_buttons()[index]
		_check(control.disabled == not affordable and control.text.contains(choice.text), "authored affordability on visible ticket")
		if affordable:
			_check(control.tooltip_text.contains("After: %d gold | %d scraps" % [gold, 2 + scraps]),
				"visible forecast gives exact authored balance")
			if selected < 0 or scraps < 0:
				selected = index
	_check(selected >= 0, "named Event has a genuine affordable choice")
	if selected < 0:
		return []
	var chosen: Dictionary = record.choices[selected]
	var expected := {"gold": int(chosen.outcome.gold), "scraps": 2 + int(chosen.outcome.scraps)}
	if event_id == "v3_seamstress_thread_cart":
		_check(record.required_hero == "seamstress" and _party_ids().has("seamstress")
			and chosen.id == "sew_bunting" and int(chosen.outcome.scraps) < 0,
			"hero receipt exercises a genuine affordable scrap-cost authored choice")
	if NEW_HERO_STORIES.has(event_id):
		new_hero_receipts[event_id] = true
		var authored_choices := {}
		for choice in record.choices:
			authored_choices[choice.id] = choice
		var hero_ids: Variant = record.get("hero_choice_ids")
		_check(record.required_hero is String and _party_ids().has(record.required_hero),
			"new hero story is admitted by its genuinely present hero: " + event_id)
		_check(hero_ids is Array and (hero_ids as Array).size() == 2
			and authored_choices.has((hero_ids as Array)[0])
			and authored_choices.has((hero_ids as Array)[1]),
			"new hero story presents its two authored hero choices: " + event_id)
		_check(chosen.id != "leave" and expected != {"gold": 0, "scraps": 2},
			"new hero story commits a non-zero authored wallet change: " + event_id)
	var pressed: Callable = panel.get_choice_buttons()[selected].pressed.get_connections()[0].callable
	if keyboard:
		panel.get_choice_buttons()[selected].grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(panel.get_choice_buttons()[selected])
	if event_id == "v3_emberglass_campfire" and chosen.id == "light_the_embers":
		_check(app.wallet_event_panel == null and is_instance_valid(app.campfire_view)
			and app.campfire_visit.read_state().status == RunCampfireVisit.OPEN
			and app.run_map.get_current_node_id() == fixture.path[4],
			"Emberglass paid choice mounts an actual same-node Campfire")
		await _click(app.campfire_leave_button)
	_check(app.wallet_event_panel == null and is_instance_valid(app.route_view)
		and _wallet() == expected and _other_ledgers() == before,
		"physical choice publishes exact wallet once with all other ledgers unchanged: " + event_id)
	_check(not pressed.is_valid(), "disposed panel invalidates retained physical callback")
	_reject_wallet(pressed, "repeated physical choice")
	_reject_wallet(commit.bind({"ok": true, "event_id": event_id, "choice_id": chosen.id,
		"wallet": expected}), "replayed owner receipt")
	_reject_wallet(entry, "completed route replay")
	var result := [_wallet(), app.run_map.get_route(), str(app.run_rng.state), record, chosen.id]
	await _traverse_treasures(fixture, fixture.next)
	await _click(_route_action(fixture.next))
	_check(app.run_map.get_current_node_id() == fixture.next, "settlement admits genuine connected successor")
	var second: LiveEventChoicePanel = app.wallet_event_panel
	_check(is_instance_valid(second), "successor mounts vitality offering")
	if not is_instance_valid(second):
		return []
	var second_record := second._selector.get_event()
	var remaining := RunV3VitalEventRotation.new().get_vital_event_ids()
	var second_id: String = remaining[rng.randi_range(0, remaining.size() - 1)]
	_check(second_record.id == second_id and second_record.id != event_id
		and app._wallet_event_history == [event_id] and app._vital_event_history == [second_id] and app.run_rng.state == rng.state,
		"next one-draw selection excludes actual visited generic history")
	var paid := -1
	for index in range(second_record.choices.size()):
		if not second.get_choice_buttons()[index].disabled and (paid < 0 \
			or int(second_record.choices[index].outcome.gold) < 0):
			paid = index
	_check(paid >= 0 and not second.get_choice_buttons()[paid].disabled,
		"authentic first sale funds the second choice")
	if paid < 0:
		return []
	var paid_choice: Dictionary = second_record.choices[paid]
	if int(paid_choice.outcome.gold) < 0:
		gold_purchases += 1
	var paid_wallet := {"gold": expected.gold + int(paid_choice.outcome.gold),
		"scraps": expected.scraps + int(paid_choice.outcome.scraps)}
	var paid_before := _other_ledgers()
	var vital_receipt := RunEventChoice.new(second_record).choose_with_vitals(paid_choice.id, second._offered_snapshot)
	_check(vital_receipt.ok and second._vital_mode, "second choice has authenticated vitality forecast")
	var proposal: RunTornMending = app.party_carryover._observer()
	_check(proposal.apply_vital_event(fixture.next, second_record, vital_receipt,
		second._offered_snapshot, proposal.read_state()).ok, "independent ledger accepts authored vitality")
	paid_before[1] = proposal.read_state().heroes
	paid_before[6].heroes = proposal.read_state().heroes
	paid_before[6].completed_vital_events = proposal.read_state().completed_vital_events
	paid_before[7] = proposal.read_state()
	if keyboard:
		await _key(KEY_1 + paid)
	else:
		await _click(second.get_choice_buttons()[paid])
	_check(_wallet() == paid_wallet and _other_ledgers() == paid_before
		and app.wallet_event_panel == null and app.route_view != null,
		"second receipt applies exact authored delta to earned wallet once")
	result.append([second_record, paid_wallet, str(app.run_rng.state)])
	await _return_title()
	return result


func _failures(fixture: Dictionary) -> void:
	await _reach(fixture, false)
	var button := _route_action(fixture.path[4])
	var entry: Callable = button.pressed.get_connections()[0].callable
	var catalog_path: String = app.event_catalog_path
	app.event_catalog_path = "res://missing_event_catalog.json"
	_reject_wallet(entry, "missing catalog rejects without draw")
	app.event_catalog_path = catalog_path
	_catalog_failures(entry)
	var heroes: Array = app.run_heroes.duplicate(true)
	var unknown := heroes.duplicate(true)
	unknown[0].id = "unknown_hero"
	for invalid in [[], [null, null, null], [heroes[0], heroes[0], heroes[2]], unknown]:
		app.run_heroes = invalid.duplicate(true)
		_check(app._load_wallet_event_catalog().is_empty(), "malformed or duplicate live party rejects catalog")
		_reject_wallet(entry, "malformed or duplicate live party")
	app.run_heroes = heroes
	app.session_gold = -1
	_reject_wallet(entry, "failed wallet panel mount rolls back selection draw")
	app.session_gold = 0
	_reject_wallet(app._open_wallet_event.bind(app.run_map.get_current_node_id(), weakref(app.run_map)),
		"visited map admission rolls back staged draw and panel")
	button.disabled = true
	_reject_wallet(entry, "disabled route")
	button.disabled = false
	await _click(button)
	var panel: LiveEventChoicePanel = app.wallet_event_panel
	_check(is_instance_valid(panel), "negative fixtures have actual mounted offering")
	if not is_instance_valid(panel):
		return
	var record := panel._selector.get_event()
	var denied := -1
	var allowed := -1
	for index in range(record.choices.size()):
		if panel.get_choice_buttons()[index].disabled:
			denied = index
		else:
			allowed = index
	_check(denied >= 0 and allowed >= 0, "zero wallet provides actual unaffordable and affordable choices")
	if denied < 0 or allowed < 0:
		return
	var denied_button: Button = panel.get_choice_buttons()[denied]
	var before := _wallet_state()
	await _click(denied_button)
	await _key(KEY_1 + denied)
	denied_button.pressed.emit()
	_check(_wallet_state() == before and not panel._selector.is_claimed(), "unaffordable mouse, keyboard and signal consume nothing")
	var commit: Callable = panel.wallet_choice_committed.get_connections()[0].callable
	var receipt := RunEventChoice.new(record).choose_with_wallet(record.choices[allowed].id, _wallet())
	_check(receipt.ok, "forgery test uses a real affordable authored receipt")
	# Even matching receipts cannot bypass physical panel ownership.
	_reject_wallet(commit.bind(receipt), "authentic-shaped receipt without panel claim")
	var original_map: RunMap = app.run_map
	var foreign := RunMap.new()
	var foreign_rng := RandomNumberGenerator.new()
	foreign_rng.seed = fixture.seed
	foreign.generate(foreign_rng)
	app.run_map = foreign
	_reject_wallet(commit.bind(receipt), "foreign map")
	app.run_map = original_map
	# Stage the panel's genuine claim while keeping owner publication disconnected,
	# then challenge the owner with forged balances, wrong routes and stale wallets.
	panel.wallet_choice_committed.disconnect(commit)
	await _click(panel.get_choice_buttons()[allowed])
	_check(panel._selector.is_claimed() and panel._committed_choice == receipt, "real callback produced exact pending receipt")
	app.run_map = foreign
	_reject_wallet(commit.bind(receipt), "foreign map after actual claim")
	app.run_map = original_map
	var forged := receipt.duplicate(true)
	forged.wallet.gold += 1
	_reject_wallet(commit.bind(forged), "forged wallet after actual claim")
	panel._committed_choice = forged.duplicate(true)
	_reject_wallet(commit.bind(forged), "forged panel receipt still fails authored wallet recomputation")
	panel._committed_choice = receipt.duplicate(true)
	var current: String = original_map.get_current_node_id()
	original_map._nodes[current].type = "Treasure"
	_reject_wallet(commit.bind(receipt), "wrong route type after actual claim")
	original_map._nodes[current].type = "Event"
	var route: Array = original_map._route.duplicate()
	original_map._route.pop_back()
	_reject_wallet(commit.bind(receipt), "stale route after actual claim")
	original_map._route.assign(route)
	app.run_scraps += 1
	_reject_wallet(commit.bind(receipt), "stale wallet after actual claim")
	app.run_scraps -= 1
	commit.call(receipt)
	_check(app.wallet_event_panel == null and _wallet() == receipt.wallet and app.route_view != null,
		"restored authentic pending receipt can settle once")
	_reject_wallet(commit.bind(receipt), "duplicate settled receipt")
	await _return_title()


func _hero_leave(fixture: Dictionary, event_id: String) -> void:
	await _reach(fixture, false)
	await _click(_route_action(fixture.path[4]))
	var panel: LiveEventChoicePanel = app.wallet_event_panel
	_check(is_instance_valid(panel), "hero Leave has a real fifth-Event panel")
	if not is_instance_valid(panel):
		return
	var record := panel._selector.get_event()
	_check(record.id == event_id and _party_ids().has(record.get("required_hero")),
		"hero Leave is bound to a present hero's authored story")
	var leave := -1
	for index in range(record.choices.size()):
		if record.choices[index].id == "leave":
			leave = index
	_check(leave >= 0, "authored hero story provides Leave")
	if leave < 0:
		return
	var before := [_wallet(), _other_ledgers(), app.run_rng.state]
	await _key(KEY_1 + leave)
	_check(app.wallet_event_panel == null and is_instance_valid(app.route_view)
		and [_wallet(), _other_ledgers(), app.run_rng.state] == before,
		"hero Leave settles zero receipt and restores connected route")
	await _traverse_treasures(fixture, fixture.next)
	await _click(_route_action(fixture.next))
	_check(app.run_map.get_current_node_id() == fixture.next and is_instance_valid(app.wallet_event_panel),
		"hero Leave permits genuine legal successor Event")
	await _return_title()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	_catalog_contract()
	seed(227227)
	var global_next := randi()
	seed(227227)
	var fixtures := _fixtures()
	_check(not fixture_fallback_used, "shipped seed hints cover every required Event without bounded fallback")
	for id in _required_ids():
		_check(fixtures.has(id), "bounded genuine seeded route exists for " + id)
		if not fixtures.has(id):
			continue
		var first := await _named(fixtures[id], id, false)
		var replay := await _named(fixtures[id], id, true)
		_check(not first.is_empty() and first == replay, "same seed mouse/keyboard replay matches exact Event, wallet, route and RNG")
	if fixtures.has("button_trail"):
		await _failures(fixtures.button_trail)
	if fixtures.has("v3_mismatched_mittens"):
		await _failures(fixtures.v3_mismatched_mittens)
	var hero_id := "v3_seamstress_thread_cart"
	_check(fixtures.has(hero_id), "hero paid/Leave/refusal witness exists")
	if fixtures.has(hero_id):
		await _failures(fixtures[hero_id])
		await _hero_leave(fixtures[hero_id], hero_id)
	for new_id in NEW_HERO_STORIES:
		_check(new_hero_receipts.has(new_id),
			"new hero story reached the real routed panel and settled once: " + new_id)
	_check(gold_purchases > 0, "real generic sales fund real gold-cost choices")
	_check(randi() == global_next, "all selection, choices and rejections preserve global RNG")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_m04_event_wallet_batch_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
