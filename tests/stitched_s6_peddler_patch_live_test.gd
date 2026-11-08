extends "res://tests/stitched_s6_full_run_test.gd"
## Paid patch/foreign-part stock must survive real routed controls and V1 replay.
const LiveWitness := preload("res://tests/live_witness.gd")
# Ten stops without a Peddler, then the floor-eleven Peddler; fights first so the wallet is earned.
# The witness seed and route are searched at run time (owner 11-08): the old pinned seed-21 route broke
# whenever a lane retuned a fight on it.
const KINDS := ["!Shop", "!Shop", "!Shop", "!Shop", "!Shop", "!Shop", "!Shop", "!Shop", "!Shop", "!Shop", "Shop"]
const PREFER := ["Fight", "Campfire", "SewingCircle", "Treasure", "Rest"]
const SAVE := "user://stitched_s6_peddler_patch_live.save"


func _button(app: Node, id: String, args: Array = []) -> Button:
	var actions: Array = app.stitched_run_session.visit_actions()
	for index in actions.size():
		if actions[index].id == id and actions[index].arguments == args:
			return app.stitched_run_buttons[index]
	return null


func _run() -> void:
	var witness := await LiveWitness.first_played(self, LiveWitness.candidates(KINDS, 0, 2, PREFER),
		func(app: Node, _played: Dictionary) -> bool:
			var found: StitchedRunSession = app.stitched_run_session
			return found.phase == "visit" and found.pending.service == "Peddler" and found.gold >= 100)
	_check(not witness.is_empty(), "a searched seed and route reach a floor-eleven Peddler with an earned wallet")
	if witness.is_empty():
		_finish(null)
		return
	print("Peddler witness: seed=%d route=%s fights=%s" % [witness.seed, witness.route, witness.played.fights])
	var app: Node = witness.app
	var session: StitchedRunSession = app.stitched_run_session
	_check(session.map.get_floors().size() == 12, "authentic seeded twelve-floor public route")
	_check(session.map.get_route() == witness.route, "the mounted run followed the searched route")
	var fights: Array = witness.played.fights
	_check(fights.size() >= 3 and fights.all(func(fight: Dictionary): return fight.acted > 0 and fight.outcome == "victory"),
		"battle-earned wallet comes from genuine mounted ranked turns: %s" % [fights])
	_check(session.phase == "visit" and session.pending.service == "Peddler"
		and session.map.get_node(session.pending.node_id).floor == 11 and session.gold >= 100
		and session.receipts.size() == 10,
		"real ranked victories fund the eleventh-floor Peddler patch")
	if session.phase != "visit" or session.pending.service != "Peddler":
		_finish(app)
		return
	var part_offer: Dictionary = session.pending.peddler_stock.part.duplicate(true)
	var patch_offer: Dictionary = session.pending.peddler_stock.patch.duplicate(true)
	# The late route can lose the front doll before this Peddler, and a LOST doll cannot
	# wear a patch. Fit the genuine purchase on the first surviving doll instead.
	var target_hero: Dictionary = {}
	for hero in session.heroes:
		if not hero.lost:
			target_hero = hero
			break
	_check(not target_hero.is_empty(), "the earned Peddler still has a living doll for the patch")
	if target_hero.is_empty():
		_finish(app)
		return
	var target_id: String = str(target_hero.id)
	var expected_part: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/parts/enemy_parts.json"))
	var enemy_ids := {}
	if expected_part is Dictionary:
		for raw in expected_part.parts:
			enemy_ids[raw.id] = true
	var authored: Dictionary = RunStitchedPeddlerStock._authored_patches()
	_check(enemy_ids.has(part_offer.id) and session.catalog.has(part_offer.id)
		and part_offer.tier == 1 and part_offer.price == StitchedRunSession.PEDDLER_PRICE
		and part_offer.id != "not_a_part",
		"seeded foreign stock is an authentic tier-I enemy limb at unchanged ten-gold price")
	_check(authored.has(patch_offer.get("id")) and not session.patches.has(patch_offer.get("id"))
		and int(patch_offer.get("price", 0)) == int(authored.get(patch_offer.get("id"), -1)),
		"stock contains a genuine unowned priced ordinary authored power patch")
	var decision_ids: Array = session.visit_actions().map(func(a: Dictionary): return a.id)
	for needed in ["buy_part", "buy_patch", "buy_candle_stub", "bandage", "buy_pins",
		"buy_thimble_tonic", "buy_fresh_stuffing", "leave"]:
		if needed == "bandage" and not decision_ids.has(needed):
			# Bandages are advertised only to genuinely bleeding heroes.
			var bleeding := session.heroes.any(func(h: Dictionary):
				return not h.lost and int(h.statuses.get("bleed", 0)) > 0)
			_check(not bleeding, "bandage is absent only without an eligible bleeding doll")
		else:
			_check(decision_ids.has(needed), "existing public Peddler action survives: " + needed)
	var state := session.snapshot()
	var legal := session.visit_actions()
	var patch_actions := legal.filter(func(a: Dictionary): return a.id == "buy_patch")
	_check(patch_actions.size() == session.heroes.size() * 2,
		"every actual doll and two stitched patch slots have a projected offer")
	for malformed in [[], ["bogus", target_id, 0],
		[patch_offer.id, "forged_hero", 0], [patch_offer.id, target_id, 3]]:
		_check(not session.choose_visit("buy_patch", malformed, state)
			and session.snapshot() == state,
			"forged or stale patch action cannot spend, change RNG or mutate ledgers")
	var forged := state.duplicate(true)
	forged["rng"] = 0
	_check(not session.choose_visit("buy_patch", [patch_offer.id, target_id, 0], forged)
		and session.snapshot() == state, "forged RNG prediction refuses without spend")
	# Foreground restore recomputes the identical sampled stock and visit choices.
	var saved := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(saved != null and saved.snapshot() == state
		and saved.visit_actions() == session.visit_actions(),
		"pending stock, prices, RNG and choices replay exactly under VERSION 1")
	app.stitched_save_path = SAVE
	var actions_count: int = session.visit_actions().size()
	var old_button: Button = _button(app, "buy_patch", [patch_offer.id, target_id, 0])
	_check(old_button != null and not old_button.disabled and old_button.focus_mode == Control.FOCUS_ALL,
		"earned patch row is an enabled, focusable public choice")
	if old_button == null:
		_finish(app)
		return
	app.stitched_run_buttons[actions_count].pressed.emit()
	_check(FileAccess.file_exists(SAVE), "public Save run writes the exact pending stock")
	app.stitched_run_buttons[actions_count + 1].pressed.emit()
	session = app.stitched_run_session
	_check(session != null and session.snapshot() == state
		and session.pending.peddler_stock == state.pending.peddler_stock,
		"public Reload saved run restores the original stock without reroll")
	old_button.pressed.emit()
	_check(session.snapshot() == state, "pre-reload callback cannot claim stock in restored session")
	var buy: Button = _button(app, "buy_patch", [patch_offer.id, target_id, 0])
	_check(buy != null and not buy.disabled and buy.is_visible_in_tree(),
		"restored public patch button remains actionable")
	if buy != null:
		buy.grab_focus()
		_check(buy.has_focus(), "keyboard navigation reaches real patch sale")
		buy.pressed.emit()
	var paid := session.snapshot()
	var wearing := false
	for hero in session.heroes:
		if hero.id == target_id:
			var worn_patches: Array = hero.get("patches", [])
			wearing = not worn_patches.is_empty() and worn_patches[0] == patch_offer.id
	_check(session.phase == "map" and session.gold == state.gold - patch_offer.price
		and session.patches.has(patch_offer.id) and wearing
		and session.receipts.size() == 11 and paid != state,
		"one paid receipt wears the purchased patch, debits exact authored gold and exits Peddler")
	if buy != null:
		buy.pressed.emit()
	_check(session.snapshot() == paid and session.is_consistent(),
		"replayed purchase button cannot charge twice or redraw RNG")
	_check(not session.choose_visit("buy_patch", [patch_offer.id, target_id, 0], paid)
		and session.snapshot() == paid, "duplicate purchase command is refused")
	var reloaded := StitchedRunSave.restore(StitchedRunSave.capture(session))
	var replayed_wear := false
	if reloaded != null:
		for hero in reloaded.heroes:
			if hero.id == target_id:
				var reloaded_patches: Array = hero.get("patches", [])
				replayed_wear = not reloaded_patches.is_empty() \
					and reloaded_patches[0] == patch_offer.id
	var replay_ok := reloaded != null and reloaded.snapshot() == paid and replayed_wear
	_check(replay_ok, "owned and worn patch replay exactly with the full ledger and current RNG")
	if not replay_ok:
		_finish(app)
		return
	var last_node: String = session.choices()[0]
	_check(session.map.get_node(last_node).type == "Boss" and _press_route(app, last_node)
		and session.phase == "battle", "next actual ranked Boss receives the bought patch")
	var carried_wear := false
	for hero in session.heroes:
		if hero.id == target_id:
			var carried_patches: Array = hero.get("patches", [])
			carried_wear = not carried_patches.is_empty() and carried_patches[0] == patch_offer.id
	_check(session.battle != null and carried_wear,
		"bought patch persists beyond Peddler into subsequent live node")
	# An authenticated part service with six spares refuses buy and leaves
	# the original full satchel and wallet untouched.
	var full_satchel: Array = []
	for index in range(6):
		full_satchel.append({"id": part_offer.id, "slot": session.catalog[part_offer.id].slot,
			"tier": 1, "torn": false})
	var part_service := RunStitchedPeddlerPart.open_stitched(
		"part_cap", 100, full_satchel, session.catalog, part_offer.id, 10)
	var part_before := part_service.read_state()
	_check(part_service.is_valid() and not part_service.buy("part_cap", part_before).ok
		and part_service.read_state() == part_before,
		"authentic part stock cannot overfill six-slot satchel or spend gold")
	var patch_owned := RunStitchedPeddlerStock.open_stitched("owned", 200, [patch_offer.id], patch_offer)
	_check(not patch_owned.is_valid(), "already-owned patch cannot be put on sale twice")
	var patch_service := RunStitchedPeddlerStock.open_stitched("poor", 0, [], patch_offer)
	var patch_before := patch_service.read_state()
	_check(patch_service.is_valid()
		and not patch_service.buy_patch(patch_offer.id, "poor", patch_before).ok
		and patch_service.read_state() == patch_before,
		"insufficient earned gold fails without ownership/wallet drift")
	_card_free_source_checks()
	_coat_quote_checks()
	_finish(app)


## Every existing coat's authored max-HP bonus is disclosed by the real quote.
func _coat_quote_checks() -> void:
	var rows := {"quilted_coat": [90, 6], "padded_vest": [75, 4],
		"double_quilt_coat": [100, 8], "scrap_lined_vest": [70, 3],
		"wool_patch_cloak": [85, 5], "chain_stitched_coat": [95, 7],
		"reinforced_patchcoat": [105, 9],"thick_felt_mantle": [110, 10]}
	var authored: Dictionary = RunStitchedPeddlerStock._authored_patches()
	var coat_defs := {}
	for record in JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/m04_coat_patches.json")):
		coat_defs[record.id] = record
	var witnessed := 0
	for id in rows:
		var price: int = rows[id][0]
		var bonus: int = rows[id][1]
		_check(authored.get(id, -1) == price and coat_defs.has(id)
			and int(coat_defs[id].max_hp_bonus) == bonus,
			"authored price and bonus match the brief: " + id)
		var offer := {"id": id, "price": price}
		var rich := RunStitchedPeddlerStock.open_stitched("coat_" + id, price, [], offer)
		var short := RunStitchedPeddlerStock.open_stitched("coat_" + id, price - 1, [], offer)
		_check(rich.is_valid() and short.is_valid(), "authentic coat visits open: " + id)
		if not rich.is_valid() or not short.is_valid():
			continue
		var quote_rich := rich.quote()
		var quote_short := short.quote()
		for q in [quote_rich, quote_short]:
			_check(q.get("ok", false) and q.offer.id == id and q.offer.price == price
				and q.offer.get("slot") == "COAT" and q.offer.get("max_hp_bonus") == bonus
				and q.offer.get("effect_text") == "Equip: +%d max HP" % bonus,
				"quote discloses slot, bonus and equip text: " + id)
		_check(quote_rich.can_buy == true and quote_short.can_buy == false,
			"can_buy unchanged at exact gold and one gold short: " + id)
		_check(rich.read_state().offer == offer and short.read_state().offer == offer,
			"read_state offer stays the bare id/price pair: " + id)
		# Detached: editing the returned snapshots cannot change the visit.
		quote_rich.offer["max_hp_bonus"] = 999
		quote_rich.offer["id"] = "forged"
		var state: Dictionary = rich.read_state()
		state.offer["price"] = 1
		state.owned.append("forged")
		var again := rich.quote()
		_check(again.offer.max_hp_bonus == bonus and again.offer.id == id
			and again.offer.price == price and rich.read_state().offer == offer
			and rich.read_state().owned.is_empty(),
			"quote and read_state snapshots are deep-detached: " + id)
		# Quoting short never buys, heals, equips or grants authority.
		var short_before := short.read_state()
		_check(not short.buy_patch(id, "coat_" + id, short_before).ok
			and short.read_state() == short_before and short.quote().can_buy == false,
			"one gold short stays refused with no spend: " + id)
		witnessed += 1
	_check(witnessed == rows.size(), "all eight coat quotes were exercised")
	# One genuinely affordable purchase charges its price once and rejects replay.
	var buy_offer := {"id": "thick_felt_mantle", "price": 110}
	var service := RunStitchedPeddlerStock.open_stitched("coat_buy", 200, [], buy_offer)
	var before := service.read_state()
	var forged := before.duplicate(true)
	forged["gold"] = 999
	_check(service.is_valid() and not service.buy_patch("thick_felt_mantle", "coat_buy", forged).ok
		and not service.buy_patch("thick_felt_mantle", "other", before).ok
		and service.read_state() == before, "forged or wrong-node buy refuses without spend")
	var receipt := service.buy_patch("thick_felt_mantle", "coat_buy", before)
	_check(receipt.get("ok", false) and receipt.charged_gold == 110 and receipt.price == 110
		and receipt.gold == 90 and receipt.ledger.gold == 90
		and receipt.ledger.owned_patch_ids == ["thick_felt_mantle"]
		and not receipt.has("max_hp_bonus") and not receipt.has("hp"),
		"affordable coat charges its authored price once with the unchanged receipt")
	var after := service.read_state()
	_check(not service.buy_patch("thick_felt_mantle", "coat_buy", after).ok
		and service.read_state() == after and not service.quote().get("ok", false),
		"replayed purchase is refused and a consumed visit no longer quotes")


## Card-free Stitched patch price source, resolved through the real helper.
func _card_free_source_checks() -> void:
	var source_path := RunStitchedPeddlerStock.PATCH_SOURCE
	_check(source_path == "res://data/shop/stitched_patch_offers.json",
		"Peddler patch prices come from the Stitched-only source")
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	_check(document is Dictionary and not document.has("cards") and document.get("trinkets") is Array
		and not document.trinkets.is_empty(), "Stitched patch source has trinkets and no cards field")
	if not document is Dictionary or not document.get("trinkets") is Array:
		return
	var rows := {}
	for item in document.trinkets:
		rows[item.get("id")] = item.get("price")
	var coats := {"scrap_lined_vest": 3, "padded_vest": 4, "wool_patch_cloak": 5, "quilted_coat": 6,
		"chain_stitched_coat": 7, "double_quilt_coat": 8, "reinforced_patchcoat": 9,
		"thick_felt_mantle": 10}
	var expected_price := {"scrap_lined_vest": 70, "padded_vest": 75, "wool_patch_cloak": 85,
		"quilted_coat": 90, "chain_stitched_coat": 95, "double_quilt_coat": 100,
		"reinforced_patchcoat": 105, "thick_felt_mantle": 110}
	var retired := ["stitched_badge", "spare_spool", "button_eye", "pincushion_arm",
		"switchback_button", "bloodstitch_bonnet", "button_glass_visor", "stern_seam_cap",
		"reinforced_browband", "hemguard_cuff", "red_bobbin_cuff", "loose_thread_glove",
		"threadguard_wrap", "frayfinder_mitt", "borrowed_button", "relay_bobbin", "hearth_lining"]
	var authored: Dictionary = RunStitchedPeddlerStock._authored_patches()
	var coat_defs := {}
	for record in JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/patches/m04_coat_patches.json")):
		coat_defs[record.id] = record
	for id in coats:
		_check(coat_defs.has(id) and coat_defs[id].slot == "COAT"
			and int(coat_defs[id].max_hp_bonus) == int(coats[id]),
			"authored max-HP coat definition exists: " + id)
		_check(rows.has(id) and int(rows[id]) == expected_price[id],
			"source row costs exactly %d gold: %s" % [expected_price[id], id])
		_check(authored.has(id) and authored[id] == expected_price[id],
			"helper resolves the coat patch at %d gold: %s" % [expected_price[id], id])
	for id in retired:
		_check(not rows.has(id), "retired card-era relic is not in the Peddler source: " + id)
		_check(not authored.has(id), "retired card-era relic is not Peddler stock: " + id)
	var parts: Variant = JSON.parse_string(FileAccess.get_file_as_string(RunStitchedPeddlerStock.PART_SOURCE))
	var catalog := {}
	var part_ids: Array = []
	for raw in parts.parts:
		catalog[raw.id] = {"slot": raw.slot}
		part_ids.append(raw.id)
	part_ids.sort()
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = 20261106
	second.seed = 20261106
	var one := RunStitchedPeddlerStock.sample(first, catalog, [], 10)
	var two := RunStitchedPeddlerStock.sample(second, catalog, [], 10)
	_check(one.get("ok", false) and one == two and first.state == second.state,
		"equal seeds reproduce the same part, patch and RNG state")
	_check(one.get("ok", false) and part_ids.has(one.part.id) and one.part.tier == 1
		and one.part.price == 10 and authored.has(one.patch.get("id"))
		and int(one.patch.price) == int(authored[one.patch.id]),
		"sample picks a catalogued tier-I part and a priced ordinary patch")
	if not one.get("ok", false) or one.patch.is_empty():
		return
	var owned_state := RandomNumberGenerator.new()
	owned_state.seed = 20261106
	var skipped := RunStitchedPeddlerStock.sample(owned_state, catalog, [one.patch.id], 10)
	_check(skipped.get("ok", false) and skipped.patch.get("id") != one.patch.id
		and not authored.is_empty() and authored.has(skipped.patch.get("id")),
		"an already-owned patch is never offered")
	var all_owned: Array = authored.keys()
	var drained := RandomNumberGenerator.new()
	drained.seed = 20261106
	var reference := RandomNumberGenerator.new()
	reference.seed = 20261106
	reference.randi_range(0, part_ids.size() - 1)
	var empty := RunStitchedPeddlerStock.sample(drained, catalog, all_owned, 10)
	_check(empty.get("ok", false) and empty.patch.is_empty() and part_ids.has(empty.part.id)
		and drained.state == reference.state,
		"all authored patches owned still sells the part with an empty patch offer and one draw")
	var spent := RandomNumberGenerator.new()
	spent.seed = 20261106
	var before_state := spent.state
	_check(not RunStitchedPeddlerStock.sample(spent, {}, [], 10).get("ok", false)
		and not RunStitchedPeddlerStock.sample(spent, catalog, [7], 10).get("ok", false)
		and spent.state == before_state, "invalid catalogs or ledgers refuse without an RNG draw")


func _finish(app: Node) -> void:
	if app != null:
		app.free()
	await process_frame
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	for fail in failures:
		printerr(fail)
	print("stitched_s6_peddler_patch_live_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
