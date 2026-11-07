extends "res://tests/stitched_s6_full_run_test.gd"
## Paid patch/foreign-part stock must survive real routed controls and V1 replay.
const ROUTE := [
	"f01_n0", "f02_n0", "f03_n0", "f04_n0", "f05_n0",
	"f06_n0", "f07_n3", "f08_n1", "f09_n0", "f10_n0", "f11_n0",
]
const SAVE := "user://stitched_s6_peddler_patch_live.save"


func _button(app: Node, id: String, args: Array = []) -> Button:
	var actions: Array = app.stitched_run_session.visit_actions()
	for index in actions.size():
		if actions[index].id == id and actions[index].arguments == args:
			return app.stitched_run_buttons[index]
	return null


func _run() -> void:
	var app: Node = await _new_run(21)
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.map.get_floors().size() == 12, "authentic seeded twelve-floor public route")
	if session == null:
		_finish(app)
		return
	var bosses := 0
	for node_id in ROUTE:
		if session.phase != "map":
			break
		_check(session.choices().has(node_id), "precomputed next node is connected " + node_id)
		if not session.choices().has(node_id):
			break
		var kind: String = session.map.get_node(node_id).type
		_check(_press_route(app, node_id), "press a real map button " + node_id + "/" + kind)
		if session.phase == "battle":
			var stage: StitchedBattleScreen = app.stitched_run_battle
			var result: Dictionary = _win(stage)
			_check(stage.battle.is_over() and result.acted > 0 and stage.battle.outcome() == "victory",
				"battle-earned wallet comes from genuine mounted ranked turns " + node_id)
			if stage.battle.outcome() != "victory":
				break
			stage._action_buttons["exit"].pressed.emit()
			bosses += 1 if kind == "Boss" else 0
		elif kind != "Shop":
			_check(_finish_visit(app), "public stop visit completes " + node_id)
		else:
			break
	_check(session.phase == "visit" and session.pending.service == "Peddler"
		and session.pending.node_id == "f11_n0" and session.gold >= 100
		and session.receipts.size() == 10,
		"real six ranked victories fund the eleventh-floor Peddler patch")
	if session.phase != "visit" or session.pending.service != "Peddler":
		_finish(app)
		return
	var part_offer: Dictionary = session.pending.peddler_stock.part.duplicate(true)
	var patch_offer: Dictionary = session.pending.peddler_stock.patch.duplicate(true)
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
	for malformed in [[], ["bogus", session.heroes[0].id, 0],
		[patch_offer.id, "forged_hero", 0], [patch_offer.id, session.heroes[0].id, 3]]:
		_check(not session.choose_visit("buy_patch", malformed, state)
			and session.snapshot() == state,
			"forged or stale patch action cannot spend, change RNG or mutate ledgers")
	var forged := state.duplicate(true)
	forged["rng"] = 0
	_check(not session.choose_visit("buy_patch", [patch_offer.id, session.heroes[0].id, 0], forged)
		and session.snapshot() == state, "forged RNG prediction refuses without spend")
	# Foreground restore recomputes the identical sampled stock and visit choices.
	var saved := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(saved != null and saved.snapshot() == state
		and saved.visit_actions() == session.visit_actions(),
		"pending stock, prices, RNG and choices replay exactly under VERSION 1")
	app.stitched_save_path = SAVE
	var actions_count: int = session.visit_actions().size()
	var old_button: Button = _button(app, "buy_patch", [patch_offer.id, session.heroes[0].id, 0])
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
	var buy: Button = _button(app, "buy_patch", [patch_offer.id, session.heroes[0].id, 0])
	_check(buy != null and not buy.disabled and buy.is_visible_in_tree(),
		"restored public patch button remains actionable")
	if buy != null:
		buy.grab_focus()
		_check(buy.has_focus(), "keyboard navigation reaches real patch sale")
		buy.pressed.emit()
	var paid := session.snapshot()
	_check(session.phase == "map" and session.gold == state.gold - patch_offer.price
		and session.patches.has(patch_offer.id)
		and session.heroes[0].patches[0] == patch_offer.id
		and session.receipts.size() == 11 and paid != state,
		"one paid receipt wears the purchased patch, debits exact authored gold and exits Peddler")
	if buy != null:
		buy.pressed.emit()
	_check(session.snapshot() == paid and session.is_consistent(),
		"replayed purchase button cannot charge twice or redraw RNG")
	_check(not session.choose_visit("buy_patch", [patch_offer.id, session.heroes[0].id, 0], paid)
		and session.snapshot() == paid, "duplicate purchase command is refused")
	var reloaded := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(reloaded != null and reloaded.snapshot() == paid
		and reloaded.heroes[0].patches[0] == patch_offer.id,
		"owned and worn patch replay exactly with the full ledger and current RNG")
	var last_node: String = session.choices()[0]
	_check(session.map.get_node(last_node).type == "Boss" and _press_route(app, last_node)
		and session.phase == "battle", "next actual ranked Boss receives the bought patch")
	_check(session.battle != null and session.heroes[0].patches[0] == patch_offer.id,
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
	_finish(app)


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
		_check(rows.has(id) and int(rows[id]) == 100, "source row costs exactly 100 gold: " + id)
		_check(authored.has(id) and authored[id] == 100,
			"helper resolves the coat patch at 100 gold: " + id)
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
