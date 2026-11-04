extends SceneTree
## S6 mainline: real Roadblock -> legal part-action victory -> Circle Leave ->
## one mutually-exclusive Peddler candle stub -> next authenticated Fight.
const NODE := "s6_stitched_roadblock_peddler"
const PRICE := 10
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _no_legacy_wallet(app: Node) -> bool:
	return app.deck == null and app.run_map == null and app.run_rng == null \
		and app.session_gold == 0 and app.run_scraps == 0 \
		and app.run_deck.is_empty() and app.run_heroes.is_empty()


func _resources(app: Node) -> Dictionary:
	return {
		"gold": app.stitched_preview_gold,
		"candle": app.stitched_roadblock_candle,
		"bleed": app._stitched_bleed_carry.duplicate(true),
		"hp": app._stitched_hp_carry.duplicate(true),
		"gear": app._stitched_gear_overrides.duplicate(true),
		"satchel": app.stitched_preview_satchel.duplicate(true),
		"scraps": app.stitched_preview_scraps,
	}


func _admit(app: Node) -> StitchedBattleScreen:
	app.stitched_fight_button.pressed.emit()
	await process_frame
	var offer: LiveEventChoicePanel = app.stitched_event_panel
	if offer == null or not offer.has_open_event() or offer.get_choice_buttons().size() != 3:
		return null
	var fight: Button = offer.get_choice_buttons()[0]
	if fight.disabled:
		return null
	fight.pressed.emit()
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
		var high := -10000
		var part := ""
		var target := 0
		for slot in StitchedParts.SLOTS:
			if not stage._valid_part(actor, actor["parts"][slot]):
				continue
			var id := str(actor["parts"][slot]["id"])
			var skill: Dictionary = StitchedParts.ability_at_tier(
				stage.parts.get(id, {}), int(actor["parts"][slot]["tier"]))
			for rank in range(1, 5):
				var legal: Array = stage.battle._legal_targets(actor, skill, rank)
				if legal.is_empty():
					continue
				var weight := -20
				if str(legal[0]["side"]) == "foe":
					weight = int(skill.get("dmg", [0, 0])[1]) * 4 \
						+ int(skill.get("dmg", [0, 0])[0])
				elif str(skill.get("kind", "")) == "heal":
					var ally: Dictionary = stage._unit_at("hero", rank)
					var missing := int(ally.get("max_hp", 0)) - int(ally.get("hp", 0))
					if missing >= 8:
						weight = 38 + missing
				if weight > high:
					high = weight
					part = id
					target = rank
		var result: Dictionary
		if part != "":
			result = stage.submit_part(part, target)
			if result.get("ok") == true and result.get("action") == "ability":
				abilities += 1
		else:
			result = stage.submit_pass()
		if result.get("ok") != true:
			break
		actions += 1
	return {"outcome": stage.battle.outcome(), "actions": actions,
		"abilities": abilities}


## An unwon Fight never earns the Peddler. Extra real aborted entries burn
## candle in the normal route, furnishing a non-capped +25 purchase witness.
func _prepare(extra_aborts: int) -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	_check(app.stitched_preview_gold == 0 and app.stitched_roadblock_candle == 100 \
		and not app.stitched_peddler_button.visible \
		and not app._open_stitched_peddler() and app.stitched_peddler_panel == null,
		"fresh title has no fabricated gold or Peddler")
	for index in range(extra_aborts + 1):
		var aborted: StitchedBattleScreen = await _admit(app)
		_check(aborted != null and aborted.battle != null \
			and aborted.battle.is_valid(), "unwon Fight mounts authentic battle")
		if aborted == null:
			return app
		aborted._action_buttons["exit"].pressed.emit()
		await process_frame
		_check(app.stitched_sewing_panel == null \
			and not app.stitched_peddler_button.visible \
			and app.stitched_preview_gold == 0 \
			and app.stitched_roadblock_candle == 100 - (index + 1) * 8,
			"unwon exit awards no Peddler or gold and still charges entry candle")
	var stage: StitchedBattleScreen = await _admit(app)
	var won: Dictionary = _victory(stage)
	_check(won.get("outcome") == "victory" \
		and int(won.get("actions", 0)) > 0 \
		and int(won.get("abilities", 0)) > 0,
		"three real Roadblock foes fall to legal mounted part actions")
	if won.get("outcome") != "victory":
		return app
	var heroes: Array = stage.battle.get_heroes()
	var living := 0
	for hero in heroes:
		if not bool(hero.get("lost", false)):
			living += 1
	_check(living == 4 and stage.battle.get_foes().size() == 3,
		"real victory carries four living heroes, not a fabricated roster")
	stage._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel != null and app.stitched_preview_gold == 10 \
		and app.stitched_roadblock_candle == 100 - (extra_aborts + 2) * 8,
		"earned 10 preview gold is published only after terminal victory")
	if app.stitched_sewing_panel == null:
		return app
	var leave: Button = app.stitched_sewing_panel.get_node_or_null("SewingLeave")
	_check(leave != null and not leave.disabled, "authentic Circle Leave exists")
	if leave != null:
		leave.pressed.emit()
		await process_frame
	_check(app.stitched_sewing_panel == null \
		and app._stitched_peddler_roster.size() == 4 \
		and app.stitched_peddler_button.visible \
		and app.stitched_peddler_button.focus_mode == Control.FOCUS_ALL \
		and _no_legacy_wallet(app),
		"Circle Leave exposes earned keyboard Peddler without touching legacy wallets")
	return app


func _open(app: Node) -> Dictionary:
	app.stitched_peddler_button.pressed.emit()
	await process_frame
	var panel: Control = app.stitched_peddler_panel
	if panel == null:
		_check(false, "earned Peddler panel actually mounts")
		return {}
	var bandage: RunStitchedPeddlerBandage = app.stitched_peddler_visit
	var candle: RunPeddlerVisit = app.stitched_peddler_candle_visit
	var row: Button = panel.find_child("PeddlerCandleStub", true, false)
	var leave: Button = panel.find_child("PeddlerLeave", true, false)
	var bandage_state: Dictionary = app._stitched_peddler_quote.duplicate(true)
	var state: Dictionary = app._stitched_peddler_candle_state.duplicate(true)
	var quote: Dictionary = app._stitched_peddler_candle_quote.duplicate(true)
	_check(bandage != null and bandage.is_open() and candle != null \
		and candle.is_open() and row != null and leave != null and not leave.disabled \
		and panel.is_visible_in_tree() \
		and panel.theme == load("res://themes/gothic_theme.tres") \
		and panel.find_child("PeddlerFrame", true, false) is NinePatchRect \
		and state == candle.read_state() and quote == candle.quote() \
		and state.get("node_id") == NODE \
		and state.get("item", {}).get("price") == PRICE \
		and quote.get("restore") == mini(25, 100 - int(quote.get("candle", 0))) \
		and quote.get("gold") == app.stitched_preview_gold \
		and quote.get("candle") == app.stitched_roadblock_candle \
		and bandage_state.get("heroes", []).size() == 4 \
		and bandage_state.get("node_id") == NODE \
		and not app.title_view.is_visible_in_tree(),
		"real gothic Peddler displays the exact two service quotes on one panel")
	return {"panel": panel, "bandage": bandage, "candle": candle,
		"button": row, "leave": leave, "bandage_state": bandage_state,
		"state": state, "quote": quote,
		"generation": app._stitched_peddler_generation}


func _success(extra_aborts: int) -> Dictionary:
	var app: Node = await _prepare(extra_aborts)
	if app.stitched_preview_gold != PRICE or not app.stitched_peddler_button.visible:
		app.free()
		await process_frame
		return {}
	var before: Dictionary = _resources(app)
	var opened: Dictionary = await _open(app)
	if opened.is_empty():
		app.free()
		await process_frame
		return {}
	var panel: Control = opened["panel"]
	var candle: RunPeddlerVisit = opened["candle"]
	var bandage: RunStitchedPeddlerBandage = opened["bandage"]
	var button: Button = opened["button"]
	var state: Dictionary = opened["state"]
	var quote: Dictionary = opened["quote"]
	var bandage_state: Dictionary = opened["bandage_state"]
	var generation: int = opened["generation"]
	var expected_gain := mini(25, 100 - int(before["candle"]))
	_check(not button.disabled and button.focus_mode == Control.FOCUS_ALL \
		and button.text.contains(str(PRICE) + " gold") \
		and expected_gain > 0 and before["gold"] == PRICE,
		"earned, non-full ten-gold candle stub is keyboard-reachable")
	seed(15517)
	var expected_rng := randi()
	seed(15517)
	var wrong_quote := quote.duplicate(true)
	wrong_quote["price"] = 1
	var wrong_state := state.duplicate(true)
	wrong_state["candle"] = 99
	var wrong_bandage := bandage_state.duplicate(true)
	wrong_bandage["gold"] = 999
	var rejected: Array = [
		app._stitched_peddler_buy_candle(wrong_bandage, state, quote,
			weakref(panel), generation),
		app._stitched_peddler_buy_candle(bandage_state, wrong_state, quote,
			weakref(panel), generation),
		app._stitched_peddler_buy_candle(bandage_state, state, wrong_quote,
			weakref(panel), generation),
		app._stitched_peddler_buy_candle(bandage_state, state, quote, null, generation),
		app._stitched_peddler_buy_candle(bandage_state, state, quote,
			weakref(panel), generation - 1),
		candle.select_stitched(RunPeddlerVisit.BUY_CANDLE_STUB, "forged", state),
		candle.select_stitched(RunPeddlerVisit.BUY_CANDLE_STUB, NODE, wrong_state),
	]
	var held_hp: Dictionary = app._stitched_hp_carry.duplicate(true)
	var one_id := str(bandage_state["heroes"][0]["id"])
	app._stitched_hp_carry.erase(one_id)
	rejected.append(app._stitched_peddler_buy_candle(bandage_state, state, quote,
		weakref(panel), generation))
	app._stitched_hp_carry = held_hp.duplicate(true)
	app._stitched_hp_carry[one_id] = 0
	rejected.append(app._stitched_peddler_buy_candle(bandage_state, state, quote,
		weakref(panel), generation))
	app._stitched_hp_carry = held_hp
	app.stitched_roadblock_candle = int(before["candle"]) - 1
	rejected.append(app._stitched_peddler_buy_candle(bandage_state, state, quote,
		weakref(panel), generation))
	app.stitched_roadblock_candle = before["candle"]
	app.stitched_preview_gold -= 1
	rejected.append(app._stitched_peddler_buy_candle(bandage_state, state, quote,
		weakref(panel), generation))
	app.stitched_preview_gold = before["gold"]
	var all_refused := true
	for receipt in rejected:
		if receipt.get("ok", true) != false:
			all_refused = false
	_check(all_refused and candle.read_state() == state \
		and bandage.read_state() == bandage_state \
		and app.stitched_peddler_panel == panel and _resources(app) == before \
		and randi() == expected_rng,
		"forged node/quote/state, stale generation/panel, changed roster/candle/wallet reject without RNG or spend")
	button.pressed.emit()
	var after: Dictionary = _resources(app)
	_check(after["gold"] == before["gold"] - PRICE \
		and after["candle"] == mini(100, int(before["candle"]) + 25) \
		and int(after["candle"]) - int(before["candle"]) == expected_gain \
		and after["bleed"] == before["bleed"] and after["hp"] == before["hp"] \
		and after["gear"] == before["gear"] \
		and after["satchel"] == before["satchel"] \
		and after["scraps"] == before["scraps"] and _no_legacy_wallet(app) \
		and app.stitched_peddler_panel == null \
		and app.stitched_peddler_visit == null \
		and app.stitched_peddler_candle_visit == null \
		and candle.is_consumed() and bandage.is_consumed() \
		and not app.stitched_peddler_button.visible,
		"one legal stub charges exactly ten, restores capped light and retires both choices")
	var used: Dictionary = candle.read_state()
	var repeats: Array = [
		candle.select_stitched(RunPeddlerVisit.BUY_CANDLE_STUB, NODE, state),
		bandage.choose_bandage(str(bandage_state.get("eligible", [""])[0])
			if bandage_state.get("eligible", []).size() > 0 else "",
			NODE, bandage_state),
		app._stitched_peddler_buy_candle(bandage_state, state, quote,
			weakref(panel), generation),
		app._stitched_peddler_leave(bandage_state, weakref(panel)),
	]
	button.pressed.emit()
	var refused_replays := true
	for replay in repeats:
		if replay.get("ok", true) != false:
			refused_replays = false
	_check(refused_replays and candle.read_state() == used \
		and _resources(app) == after and _no_legacy_wallet(app),
		"same and cross-choice replay cannot buy twice or change the ledger")
	await process_frame
	var next: StitchedBattleScreen = await _admit(app)
	_check(next != null and next.battle != null and next.battle.is_valid(),
		"the next Fight is a freshly authenticated mounted battle")
	if next != null:
		var expected_entry := maxi(0, int(after["candle"]) - 8)
		_check(next.config.get("candle") == expected_entry \
			and next.battle.candle() == expected_entry \
			and next.battle.state_snapshot().get("candle") == expected_entry \
			and app.stitched_roadblock_candle == expected_entry \
			and next.battle.get_heroes().size() == 4 \
			and app._stitched_bleed_carry == before["bleed"] \
			and app._stitched_hp_carry == before["hp"] \
			and app._stitched_gear_overrides == before["gear"] \
			and _no_legacy_wallet(app),
			"next authentic Fight sees purchased candle minus only normal eight-point entry charge")
		next._action_buttons["exit"].pressed.emit()
		await process_frame
	var result := {"before": before["candle"], "after": after["candle"],
		"gain": expected_gain, "gold": after["gold"], "entry": app.stitched_roadblock_candle}
	app.free()
	await process_frame
	return result


func _blocked(full: bool) -> void:
	var app: Node = await _prepare(0)
	if app.stitched_preview_gold != PRICE or not app.stitched_peddler_button.visible:
		app.free()
		await process_frame
		return
	# Negative-only boundary injection after a real earned victory: no positive
	# purchase or victory is fabricated; the public quote must disable the buy.
	if full:
		app.stitched_roadblock_candle = 100
	else:
		app.stitched_preview_gold = PRICE - 1
	var before: Dictionary = _resources(app)
	var opened: Dictionary = await _open(app)
	if opened.is_empty():
		app.free()
		await process_frame
		return
	var panel: Control = opened["panel"]
	var button: Button = opened["button"]
	var candle: RunPeddlerVisit = opened["candle"]
	var bandage: RunStitchedPeddlerBandage = opened["bandage"]
	var state: Dictionary = opened["state"]
	seed(71509)
	var expected_rng := randi()
	seed(71509)
	var failed: Dictionary = app._stitched_peddler_buy_candle(
		opened["bandage_state"], state, opened["quote"],
		weakref(panel), opened["generation"])
	_check(button.disabled and button.focus_mode == Control.FOCUS_NONE \
		and failed.get("ok") == false and candle.read_state() == state \
		and _resources(app) == before and bandage.is_open(),
		"full or unaffordable candle disables buy and refuses direct invocation")
	opened["leave"].pressed.emit()
	_check(app.stitched_peddler_panel == null \
		and app.stitched_peddler_candle_visit == null \
		and candle.is_consumed() and bandage.is_consumed() \
		and _resources(app) == before and _no_legacy_wallet(app) \
		and randi() == expected_rng,
		"free Leave closes both alternatives, keeps all resources and draws no RNG")
	_check(not candle.select_stitched(RunPeddlerVisit.BUY_CANDLE_STUB,
		NODE, state).get("ok", true) \
		and app._stitched_peddler_buy_candle(opened["bandage_state"], state,
			opened["quote"], weakref(panel), opened["generation"]).get("ok") == false,
		"Leave rejects later candle purchases and stale callbacks")
	app.free()
	await process_frame


func _bandage_cross_choice() -> void:
	var app: Node = await _prepare(0)
	if app.stitched_preview_gold != PRICE or not app.stitched_peddler_button.visible:
		app.free()
		await process_frame
		return
	var opened: Dictionary = await _open(app)
	if opened.is_empty():
		app.free()
		await process_frame
		return
	var eligibility: Array = opened["bandage_state"].get("eligible", [])
	_check(not eligibility.is_empty(), "real combat left a bleeding target for the alternative bandage")
	if eligibility.is_empty():
		opened["leave"].pressed.emit()
		app.free()
		await process_frame
		return
	var before: Dictionary = _resources(app)
	var target := str(eligibility[0])
	var row: Button = opened["panel"].find_child("Bandage_" + target, true, false)
	_check(row != null and not row.disabled, "alternative bandage remains enabled")
	if row != null:
		row.pressed.emit()
	var after: Dictionary = _resources(app)
	_check(after["gold"] == before["gold"] - PRICE \
		and after["candle"] == before["candle"] \
		and not after["bleed"].has(target) \
		and after["hp"] == before["hp"] and after["gear"] == before["gear"] \
		and after["scraps"] == before["scraps"] \
		and after["satchel"] == before["satchel"] \
		and opened["candle"].is_consumed() \
		and app.stitched_peddler_panel == null and _no_legacy_wallet(app),
		"bandage choice cures only Bleed and retires candle without extra charge")
	_check(not opened["candle"].select_stitched(
		RunPeddlerVisit.BUY_CANDLE_STUB, NODE, opened["state"]).get("ok", true) \
		and app._stitched_peddler_buy_candle(opened["bandage_state"],
			opened["state"], opened["quote"], weakref(opened["panel"]),
			opened["generation"]).get("ok") == false \
		and _resources(app) == after,
		"bandage-first cross-choice callback and service replay are inert")
	app.free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var uncapped: Dictionary = await _success(2)
	_check(not uncapped.is_empty() and uncapped.get("gain") == 25 \
		and uncapped.get("entry") == 85,
		"legal repeated entry produces an uncapped +25 stub and next entry at 85")
	var capped: Dictionary = await _success(0)
	_check(not capped.is_empty() and capped.get("before") == 84 \
		and capped.get("after") == 100 and capped.get("gain") == 16 \
		and capped.get("entry") == 92,
		"near-full candle caps +25 at 100, then the real Fight enters at 92")
	await _blocked(true)
	await _blocked(false)
	await _bandage_cross_choice()
	for failure in failures:
		printerr(failure)
	print("stitched_s6_peddler_candle_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
