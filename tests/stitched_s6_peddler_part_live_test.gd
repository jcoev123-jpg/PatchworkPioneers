extends SceneTree
## Real title -> Roadblock -> victory -> Circle Leave -> three-way Peddler
## -> purchased spare -> next Fight -> next earned Sewing Circle.
const NODE := "s6_stitched_roadblock_peddler"
const HEAD := "warden_head_helmet_rattle"
const PRICE := 10
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _wallet_clean(app: Node) -> bool:
	return app.deck == null and app.run_map == null and app.run_rng == null \
		and app.session_gold == 0 and app.run_scraps == 0 and app.run_deck.is_empty()


func _resources(app: Node) -> Dictionary:
	return {"gold": app.stitched_preview_gold, "satchel": app.stitched_preview_satchel.duplicate(true),
		"hp": app._stitched_hp_carry.duplicate(true),
		"bleed": app._stitched_bleed_carry.duplicate(true),
		"gear": app._stitched_gear_overrides.duplicate(true),
		"scraps": app.stitched_preview_scraps, "candle": app.stitched_roadblock_candle}


func _admit(app: Node) -> StitchedBattleScreen:
	app.stitched_fight_button.pressed.emit()
	await process_frame
	var panel: LiveEventChoicePanel = app.stitched_event_panel
	if panel == null or not panel.has_open_event() or panel.get_choice_buttons().size() != 3:
		return null
	if panel.get_choice_buttons()[0].disabled:
		return null
	panel.get_choice_buttons()[0].pressed.emit()
	await process_frame
	return app.stitched_fight_view


func _victory(stage: StitchedBattleScreen) -> Dictionary:
	if stage == null or stage.battle == null or not stage.battle.is_valid():
		return {}
	var actions := 0
	var abilities := 0
	for turn in range(200):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		var actor: Dictionary = stage.battle.get_unit(stage.battle.current_actor_id())
		var weight := -10000
		var part_id := ""
		var rank_target := 0
		for slot in StitchedParts.SLOTS:
			if not stage._valid_part(actor, actor["parts"][slot]):
				continue
			var part := str(actor["parts"][slot]["id"])
			var skill: Dictionary = StitchedParts.ability_at_tier(
				stage.parts.get(part, {}), int(actor["parts"][slot]["tier"]))
			for rank in range(1, 5):
				var legal: Array = stage.battle._legal_targets(actor, skill, rank)
				if legal.is_empty():
					continue
				var score := -20
				if str(skill.get("kind", "")) == "heal" and bool(skill.get("multi", false)):
					score = 100
				elif str(legal[0]["side"]) == "foe":
					score = int(skill.get("dmg", [0, 0])[1]) * 4 + int(skill.get("dmg", [0, 0])[0])
				elif str(skill.get("kind", "")) == "heal":
					var ally: Dictionary = stage._unit_at("hero", rank)
					var missing := int(ally.get("max_hp", 0)) - int(ally.get("hp", 0))
					if missing >= 8:
						score = 38 + missing
				if score > weight:
					weight = score
					part_id = part
					rank_target = rank
		var receipt: Dictionary = stage.submit_part(part_id, rank_target) if not part_id.is_empty() \
			else stage.submit_pass()
		if receipt.get("ok") != true:
			break
		if receipt.get("action") == "ability":
			abilities += 1
		actions += 1
	return {"outcome": stage.battle.outcome(), "actions": actions, "abilities": abilities}


func _prepare() -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	_check(app.stitched_peddler_part_visit == null and not app.stitched_peddler_button.visible \
		and not app._open_stitched_peddler() and app.stitched_peddler_panel == null \
		and app.stitched_preview_gold == 0 and _wallet_clean(app),
		"no unwon title may fabricate a Peddler spare")
	var aborted: StitchedBattleScreen = await _admit(app)
	_check(aborted != null and aborted.battle != null and aborted.battle.is_valid(),
		"unwon route mounts an actual Roadblock")
	if aborted == null:
		return app
	aborted._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_peddler_part_visit == null and not app.stitched_peddler_button.visible \
		and app.stitched_sewing_panel == null and app.stitched_preview_gold == 0,
		"retreat earns no Peddler or preview gold")
	var battle: StitchedBattleScreen = await _admit(app)
	var won: Dictionary = _victory(battle)
	_check(won.get("outcome") == "victory" and won.get("actions", 0) > 0 \
		and won.get("abilities", 0) > 0,
		"real mounted part actions defeat the Roadblock")
	if won.get("outcome") != "victory":
		return app
	var living := 0
	for hero in battle.battle.get_heroes():
		if not bool(hero.get("lost", false)):
			living += 1
	_check(living == 4, "authenticated victory has four living selected heroes")
	battle._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel != null and app.stitched_preview_gold == PRICE,
		"victory earns precisely one ten-gold award and the real Circle")
	if app.stitched_sewing_panel == null:
		return app
	var leave: Button = app.stitched_sewing_panel.get_node_or_null("SewingLeave")
	_check(leave != null and not leave.disabled, "real Sewing Circle presents Leave")
	if leave != null:
		leave.pressed.emit()
		await process_frame
	_check(app.stitched_sewing_panel == null and app.stitched_peddler_button.visible \
		and app.stitched_peddler_button.focus_mode == Control.FOCUS_ALL \
		and app._stitched_peddler_living_roster().size() == 4 and _wallet_clean(app),
		"only authenticated Circle Leave opens keyboard-accessible Peddler")
	return app


func _open(app: Node) -> Dictionary:
	var pre_entry_candle: int = int(app.stitched_roadblock_candle)
	app.stitched_peddler_button.pressed.emit()
	await process_frame
	var panel: Control = app.stitched_peddler_panel
	if panel == null:
		_check(false, "earned Peddler mounts a genuine panel")
		return {}
	var part: RunStitchedPeddlerPart = app.stitched_peddler_part_visit
	var bandage: RunStitchedPeddlerBandage = app.stitched_peddler_visit
	var candle: RunPeddlerVisit = app.stitched_peddler_candle_visit
	var state: Dictionary = app._stitched_peddler_part_state.duplicate(true)
	var quote: Dictionary = app._stitched_peddler_part_quote.duplicate(true)
	var bstate: Dictionary = app._stitched_peddler_quote.duplicate(true)
	var cstate: Dictionary = app._stitched_peddler_candle_state.duplicate(true)
	var cquote: Dictionary = app._stitched_peddler_candle_quote.duplicate(true)
	var row: Button = panel.find_child("PeddlerHelmetRattle", true, false)
	var leave: Button = panel.find_child("PeddlerLeave", true, false)
	var cfg: Dictionary = app._stitched_floor_config()
	var canonical := StitchedParts.build_catalog(cfg.get("parts", []))
	var def: Dictionary = canonical.get("by_id", {}).get(HEAD, {})
	var expected_offer: Dictionary = quote.get("offer", {})
	_check(part != null and bandage != null and candle != null \
		and part.is_open() and bandage.is_open() and candle.is_open() \
		and row != null and leave != null and not leave.disabled \
		and panel.theme == load("res://themes/gothic_theme.tres") \
		and panel.find_child("PeddlerFrame", true, false) is NinePatchRect \
		and not app.title_view.is_visible_in_tree() and panel.is_visible_in_tree() \
		and state == part.read_state() and quote == part.quote() \
		and bstate == bandage.read_state() and cstate == candle.read_state() \
		and cquote == candle.quote() and state.get("node_id") == NODE \
		and cstate.get("candle") == maxi(0, pre_entry_candle - 8) \
		and app.stitched_roadblock_candle == cstate.get("candle") \
		and quote.get("node_id") == NODE and quote.get("price") == PRICE \
		and state.get("gold") == app.stitched_preview_gold \
		and state.get("satchel") == app.stitched_preview_satchel \
		and quote.get("state") == state and quote.get("satchel_count") == state.get("satchel", []).size() \
		and quote.get("satchel_max") == RunStitchedPeddlerPart.SATCHEL_CAP \
		and quote.get("choices") == (["buy_part", "leave"] if quote.get("can_buy") == true else ["leave"]) \
		and expected_offer.get("id") == HEAD and expected_offer.get("name") == "Helmet Rattle" \
		and expected_offer.get("name") == def.get("name") \
		and expected_offer.get("slot") == def.get("slot") \
		and expected_offer.get("owner") == def.get("owner") \
		and expected_offer.get("tier") == 1 and expected_offer.get("torn") == false,
		"one live themed panel binds the full exact catalogued Helmet Rattle quote")
	_check(row != null and row.text.contains("Helmet Rattle") \
		and row.text.contains(str(PRICE) + " gold"),
		"the mounted offer is a labelled ten-gold Helmet Rattle, not a placeholder")
	return {"panel": panel, "row": row, "leave": leave, "part": part,
		"bandage": bandage, "candle": candle, "state": state, "quote": quote,
		"bandage_state": bstate, "candle_state": cstate, "candle_quote": cquote,
		"generation": app._stitched_peddler_generation}


func _part_action(app: Node, opened: Dictionary,
		part_state: Dictionary, part_quote: Dictionary,
		source: WeakRef, generation: int) -> Dictionary:
	return app._stitched_peddler_buy_part(
		opened["bandage_state"], opened["candle_state"], opened["candle_quote"],
		part_state, part_quote, source, generation)


func _success() -> void:
	var app: Node = await _prepare()
	if not app.stitched_peddler_button.visible:
		app.free()
		await process_frame
		return
	var initial: Dictionary = _resources(app)
	var opened: Dictionary = await _open(app)
	if opened.is_empty():
		app.free()
		await process_frame
		return
	var panel: Control = opened["panel"]
	var row: Button = opened["row"]
	var part: RunStitchedPeddlerPart = opened["part"]
	var before: Dictionary = _resources(app)
	var state: Dictionary = opened["state"]
	var quote: Dictionary = opened["quote"]
	var generation: int = opened["generation"]
	_check(initial["gold"] == PRICE \
		and before["candle"] == maxi(0, int(initial["candle"]) - 8) \
		and before["gold"] == initial["gold"] \
		and before["hp"] == initial["hp"] and before["bleed"] == initial["bleed"] \
		and before["gear"] == initial["gear"] \
		and before["satchel"] == initial["satchel"] \
		and before["scraps"] == initial["scraps"] \
		and before["satchel"].size() > 0 \
		and before["satchel"].size() < RunStitchedPeddlerPart.SATCHEL_CAP \
		and not row.disabled and row.focus_mode == Control.FOCUS_ALL \
		and quote.get("can_buy") == true,
		"the real nonempty trophy satchel and earned 10 gold permit keyboard Buy")
	seed(522777)
	var expected_rng := randi()
	seed(522777)
	var forged: Dictionary = state.duplicate(true)
	forged["satchel"].append({"id": HEAD, "slot": "head", "tier": 1, "torn": false})
	var cheap: Dictionary = quote.duplicate(true)
	cheap["price"] = 1
	var stale: Dictionary = state.duplicate(true)
	stale["gold"] += 1
	var bad: Array = [
		_part_action(app, opened, forged, quote, weakref(panel), generation),
		_part_action(app, opened, state, cheap, weakref(panel), generation),
		_part_action(app, opened, stale, quote, weakref(panel), generation),
		_part_action(app, opened, state, quote, null, generation),
		_part_action(app, opened, state, quote, weakref(panel), generation - 1),
		part.buy("forged-node", state), part.buy(NODE, forged),
	]
	var saved_hp: Dictionary = app._stitched_hp_carry.duplicate(true)
	var id := str(opened["bandage_state"]["heroes"][0]["id"])
	app._stitched_hp_carry.erase(id)
	bad.append(_part_action(app, opened, state, quote, weakref(panel), generation))
	app._stitched_hp_carry = saved_hp
	app.stitched_preview_gold -= 1
	bad.append(_part_action(app, opened, state, quote, weakref(panel), generation))
	app.stitched_preview_gold += 1
	app.stitched_preview_satchel.append(before["satchel"][0].duplicate(true))
	bad.append(_part_action(app, opened, state, quote, weakref(panel), generation))
	app.stitched_preview_satchel = before["satchel"].duplicate(true)
	panel.set_meta("peddler_generation", generation - 1)
	bad.append(_part_action(app, opened, state, quote, weakref(panel), generation))
	panel.set_meta("peddler_generation", generation)
	var rejected := true
	for receipt in bad:
		if receipt.get("ok", true) != false:
			rejected = false
	_check(rejected and _resources(app) == before and part.read_state() == state \
		and opened["bandage"].is_open() and opened["candle"].is_open() \
		and app.stitched_peddler_panel == panel and randi() == expected_rng,
		"forged/stale quotes, node, panel generation, roster, satchel and gold do not spend or draw RNG")
	row.pressed.emit()
	var after: Dictionary = _resources(app)
	var expected_satchel: Array = before["satchel"].duplicate(true)
	expected_satchel.append({"id": HEAD, "slot": "head", "tier": 1, "torn": false})
	_check(after["gold"] == before["gold"] - PRICE \
		and after["satchel"] == expected_satchel \
		and after["satchel"].slice(0, before["satchel"].size()) == before["satchel"] \
		and after["hp"] == before["hp"] and after["bleed"] == before["bleed"] \
		and after["gear"] == before["gear"] and after["scraps"] == before["scraps"] \
		and after["candle"] == before["candle"] and _wallet_clean(app) \
		and part.is_consumed() and opened["bandage"].is_consumed() \
		and opened["candle"].is_consumed() \
		and app.stitched_peddler_panel == null and app.stitched_peddler_part_visit == null \
		and app.stitched_peddler_visit == null and app.stitched_peddler_candle_visit == null \
		and not app.stitched_peddler_button.visible,
		"one real Buy charges 10, appends one untorn tier-I spare and retires three services")
	var bought_state: Dictionary = part.read_state()
	var replay: Array = [
		part.buy(NODE, state), part.buy(NODE, bought_state), part.leave(NODE, state),
		_part_action(app, opened, state, quote, weakref(panel), generation),
		app._stitched_peddler_buy_candle(opened["bandage_state"],
			opened["candle_state"], opened["candle_quote"], weakref(panel), generation),
		app._stitched_peddler_leave(opened["bandage_state"], weakref(panel)),
	]
	row.pressed.emit()
	var no_replay := true
	for receipt in replay:
		if receipt.get("ok", true) != false:
			no_replay = false
	_check(no_replay and part.read_state() == bought_state and _resources(app) == after,
		"replayed service or old bandage/candle/Leave callbacks cannot double-charge or append")
	await process_frame
	var next: StitchedBattleScreen = await _admit(app)
	_check(next != null and next.battle != null and next.battle.is_valid() \
		and next.config.get("candle") == before["candle"] - 8,
		"the next Fight mounts through the authenticated title route")
	if next != null:
		_check(app.stitched_preview_satchel == expected_satchel \
			and app._stitched_hp_carry == before["hp"] \
			and app._stitched_bleed_carry == before["bleed"],
			"the purchased spare survives authentic Fight admission without changing injuries")
		var won: Dictionary = _victory(next)
		_check(won.get("outcome") == "victory" and won.get("abilities", 0) > 0,
			"next real Fight can be won by mounted part actions")
		if won.get("outcome") == "victory":
			next._action_buttons["exit"].pressed.emit()
			await process_frame
			var circle: RunStitchedSewingSwap = app.stitched_sewing_visit
			var circle_state: Dictionary = circle.read_state() if circle != null else {}
			var circle_satchel: Array = circle_state.get("satchel", [])
			_check(circle != null and circle_state.get("ok") == true \
				and circle_satchel.size() >= expected_satchel.size() \
				and circle_satchel.slice(0, expected_satchel.size()) == expected_satchel \
				and circle_satchel[before["satchel"].size()] == {
					"id": HEAD, "slot": "head", "tier": 1, "torn": false},
				"next authenticated Sewing Circle receives purchased spare in exact prior order")
	app.free()
	await process_frame


func _blocked(full: bool) -> void:
	var app: Node = await _prepare()
	if not app.stitched_peddler_button.visible:
		app.free()
		await process_frame
		return
	# Only negative boundary injection after a real earned visit. The extra
	# spares are exact copies of already-authenticated canonical trophies.
	if full:
		while app.stitched_preview_satchel.size() < RunStitchedPeddlerPart.SATCHEL_CAP:
			app.stitched_preview_satchel.append(app.stitched_preview_satchel[0].duplicate(true))
	else:
		app.stitched_preview_gold = PRICE - 1
	var pre_entry: Dictionary = _resources(app)
	var opened: Dictionary = await _open(app)
	if opened.is_empty():
		app.free()
		await process_frame
		return
	var before: Dictionary = _resources(app)
	_check(before["candle"] == maxi(0, int(pre_entry["candle"]) - 8) \
		and before["gold"] == pre_entry["gold"] \
		and before["bleed"] == pre_entry["bleed"] \
		and before["hp"] == pre_entry["hp"] \
		and before["satchel"] == pre_entry["satchel"] \
		and before["scraps"] == pre_entry["scraps"],
		"unavailable spare quote still charges the one eight-candle entry")
	var row: Button = opened["row"]
	var part: RunStitchedPeddlerPart = opened["part"]
	var quote: Dictionary = opened["quote"]
	var declined: Dictionary = _part_action(app, opened, opened["state"], quote,
		weakref(opened["panel"]), opened["generation"])
	_check(not quote.get("can_buy", true) and quote.get("blocked") == (
		"satchel is full" if full else "not enough gold") \
		and row.disabled and row.focus_mode == Control.FOCUS_NONE \
		and not opened["leave"].disabled and declined.get("ok") == false \
		and part.read_state() == opened["state"] and _resources(app) == before,
		"full satchel or low gold disables keyboard Buy and preserves a free Leave")
	opened["leave"].pressed.emit()
	_check(app.stitched_peddler_panel == null and part.is_consumed() \
		and opened["bandage"].is_consumed() and opened["candle"].is_consumed() \
		and _resources(app) == before and _wallet_clean(app),
		"Leave retires all three ledgers without charge or spare")
	_check(not part.buy(NODE, opened["state"]).get("ok", true) \
		and _part_action(app, opened, opened["state"], quote,
			weakref(opened["panel"]), opened["generation"]).get("ok") == false,
		"Buy after free Leave and stale callbacks cannot award a part")
	app.free()
	await process_frame


func _other_choice(buy_candle: bool) -> void:
	var app: Node = await _prepare()
	if not app.stitched_peddler_button.visible:
		app.free()
		await process_frame
		return
	var pre_entry: Dictionary = _resources(app)
	var opened: Dictionary = await _open(app)
	if opened.is_empty():
		app.free()
		await process_frame
		return
	var before: Dictionary = _resources(app)
	_check(before["candle"] == maxi(0, int(pre_entry["candle"]) - 8) \
		and before["gold"] == pre_entry["gold"] \
		and before["satchel"] == pre_entry["satchel"] \
		and before["bleed"] == pre_entry["bleed"],
		"competing services share one already-paid Peddler entry")
	var action: Button = opened["panel"].find_child("PeddlerCandleStub", true, false)
	if not buy_candle:
		var eligible: Array = opened["bandage_state"].get("eligible", [])
		_check(not eligible.is_empty(), "real fight supplies a bleeding bandage target")
		if not eligible.is_empty():
			action = opened["panel"].find_child("Bandage_" + str(eligible[0]), true, false)
	_check(action != null and not action.disabled, "other competing service is usable")
	if action != null and not action.disabled:
		action.pressed.emit()
	var after: Dictionary = _resources(app)
	_check(after["gold"] == before["gold"] - PRICE \
		and after["satchel"] == before["satchel"] \
		and opened["part"].is_consumed() \
		and app.stitched_peddler_panel == null \
		and app.stitched_peddler_part_visit == null \
		and (after["candle"] > before["candle"] if buy_candle else
			after["bleed"] != before["bleed"]),
		"bandage or candle buys only its own effect and closes the part alternative")
	var replay: Dictionary = _part_action(app, opened, opened["state"], opened["quote"],
		weakref(opened["panel"]), opened["generation"])
	_check(replay.get("ok") == false and _resources(app) == after \
		and not opened["part"].buy(NODE, opened["state"]).get("ok", true),
		"other service purchase prevents part replay or double charge")
	app.free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _success()
	await _blocked(true)
	await _blocked(false)
	await _other_choice(false)
	await _other_choice(true)
	for failure in failures:
		printerr(failure)
	print("stitched_s6_peddler_part_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
