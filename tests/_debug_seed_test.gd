extends SceneTree
## Debug script to check what seeds produce in the fixture logic.

var app
var _fate_pin_seen := false
var _frayed_debt_seen := false
var checks := 0

func _initialize() -> void:
	get_root().size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	# Wait for the scene to be ready
	await process_frame
	_debug()
	quit(0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		printerr("FAIL: " + message)

func _party_ids() -> Array:
	var ids: Array = []
	var heroes: Array = app.run_heroes if app.run_map != null else CombatParty.new(app._load_party_definitions()).get_heroes()
	for hero in heroes:
		ids.append(hero.id)
	return ids

func _combined_catalog(include_party: bool = true) -> Dictionary:
	var events: Array = []
	for path in ["res://data/events/m04_events.json", "res://data/events/v3_roadside_events.json"]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		events.append_array(document.events.duplicate(true))
	if include_party:
		events.append_array(RunV3HeroEventOffers.new(_party_ids()).get_offers())
		if not _fate_pin_seen:
			var auction: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/events/mpw_fate_pin_auction.json"))
			for key in ["hp_cost", "minimum_hp", "gold_cost", "exit_scraps", "offer_count", "visit_weight"]:
				auction[key] = int(auction[key])
			events.append(auction)
	return {"events": events}

func _generic_route_ids() -> Array:
	var ids: Array = RunM04EventRotation.new(_combined_catalog()).get_generic_event_ids()
	if not _frayed_debt_seen:
		ids.append("frayed_debt_parcel")
	ids.sort()
	return ids

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

func _debug() -> void:
	var ids: Array = _generic_route_ids()
	print("=== Pool size: ", ids.size(), " ===")
	print("=== Party IDs: ", _party_ids(), " ===")

	# Find specific event indices
	for target in ["fate_pin_auction", "v3_warden_moonshield_watch", "v3_warden_cinder_shield_parade",
		"v3_warden_shield_menders", "v3_warden_buckle_checkpoint", "v3_warden_copper_chain_ferry",
		"v3_warden_pincushion_gate", "v3_seamstress_thread_cart", "v3_seamstress_scarlet_loom",
		"v3_seamstress_crimson_mending_queue", "v3_seamstress_crimson_bell_cord",
		"v3_seamstress_needle_oracle", "v3_seamstress_ribbon_heart_gallery",
		"v3_tinker_clockwork_wagon", "v3_tinker_gearhouse_midnight",
		"v3_tinker_gear_sideshow", "v3_tinker_brass_moth_clinic",
		"v3_tinker_spring_marionette", "v3_tinker_thunder_spool_dock"]:
		var idx = ids.find(target)
		print("  ", target, " at index ", idx)

	# Check the 3 new seeds
	var new_seeds = [517263, 684678, 874243]
	for seed in new_seeds:
		_check_seed(seed, ids)

	# Also check some existing seeds to see what they produce
	var existing_seeds = [35510, 50329, 277144, 422169, 456282, 680308, 775148, 946019, 1310530, 1333364,
		1382871, 1658568, 2171560, 2191238, 2803694, 3302493, 3757807, 3948847, 4058874,
		6931154, 5498452, 8144128, 5498865, 7777327, 3695046, 524, 3052, 8220, 14506, 31459,
		35009, 37910, 39758, 54852, 58239, 61825, 76402, 101822, 102172, 113833, 134631,
		159691, 191149, 195865, 203773, 211313, 282731, 294857, 356025, 59512, 171159,
		300770, 342403, 172076, 19942, 465258, 52253, 92094, 54971, 262, 1633, 6513,
		71703, 116353, 125617, 233422, 240821, 376208]
	for seed in existing_seeds:
		_check_seed(seed, ids)

func _check_seed(seed: int, ids: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var map := RunMap.new()
	if not map.generate(rng):
		print("  seed ", seed, ": map generation FAILED")
		return
	var path := _event_path(map, map.get_legal_choices(), 6)
	if path.is_empty():
		print("  seed ", seed, ": no 6-Event path found")
		return
	var toll := RunNeedleToll.new({"heroes": CombatParty.new(app._load_party_definitions()).get_heroes(),
		"wallet": {"gold": 0, "scraps": 0}, "deck": app._load_starter_deck()}, rng)
	var paid: bool = toll.pay_toll("warden").ok
	if not paid:
		print("  seed ", seed, ": toll payment FAILED")
		return
	var before_draw := rng.state
	var event_id: String = ids[rng.randi_range(0, ids.size() - 1)]
	print("  seed ", seed, ": drew ", event_id, " (idx ", ids.find(event_id), ") before_draw=", before_draw, " after_draw=", rng.state)
