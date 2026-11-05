extends SceneTree
## S6: the live Roadblock victory -> Sewing Circle Leave -> title Peddler bandage loop.
##
## This drives the real mounted app: a genuine Pinch Bleed, a legal part-action
## victory, the authenticated Circle Leave, the exact quoted one-use Peddler and
## the next real Fight admission. Nothing is fabricated: HP, Bleed and the
## Peddler roster all come from the terminal victory and its service receipts.
const NODE := "s6_stitched_roadblock_peddler"
const PRICE := 10

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _no_wallet(app: Node) -> bool:
	return app.deck == null and app.run_map == null and app.run_rng == null \
		and app.session_gold == 0 and app.run_scraps == 0 and app.run_deck.is_empty()


func _admit(app: Node) -> StitchedBattleScreen:
	app.stitched_fight_button.pressed.emit()
	await process_frame
	var offer: LiveEventChoicePanel = app.stitched_event_panel
	if offer == null or not offer.has_open_event() or offer.get_choice_buttons().size() != 3:
		return null
	var button: Button = offer.get_choice_buttons()[0]
	if button.disabled:
		return null
	button.pressed.emit()
	await process_frame
	return app.stitched_fight_view


## Deterministic line that really defeats all three Roadblock foes with mounted part
## actions: a whole-party mending part first, then the highest authored damage at the lowest
## legal rank. Every other part is left to its authored target rolls.
func _victory(stage: StitchedBattleScreen) -> Dictionary:
	if stage == null or stage.battle == null or not stage.battle.is_valid():
		return {}
	var steps := 0
	var abilities := 0
	for iteration in range(200):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		var actor: Dictionary = stage.battle.get_unit(stage.battle.current_actor_id())
		var best_score := -10000
		var best_id := ""
		var best_rank := 0
		for slot in StitchedParts.SLOTS:
			if not stage._valid_part(actor, actor["parts"][slot]):
				continue
			var id := str(actor["parts"][slot]["id"])
			var definition: Dictionary = stage.parts.get(id, {})
			var skill: Dictionary = StitchedParts.ability_at_tier(
				definition, int(actor["parts"][slot]["tier"]))
			for rank in range(1, 5):
				var legal: Array = stage.battle._legal_targets(actor, skill, rank)
				if legal.is_empty():
					continue
				var score := -20
				if str(legal[0]["side"]) == "foe":
					score = int(skill.get("dmg", [0, 0])[1]) * 4 + int(skill.get("dmg", [0, 0])[0])
				elif str(skill.get("kind", "")) == "heal":
					var ally: Dictionary = stage._unit_at("hero", rank)
					var missing: int = int(ally.get("max_hp", 0)) - int(ally.get("hp", 0))
					if bool(skill.get("multi", false)):
						score = 100 + missing
					elif missing >= 8:
						score = 38 + missing
				if score > best_score:
					best_score = score
					best_id = id
					best_rank = rank
		var receipt: Dictionary
		if not best_id.is_empty():
			receipt = stage.submit_part(best_id, best_rank)
			if receipt.get("ok") == true and receipt.get("action") == "ability":
				abilities += 1
		else:
			receipt = stage.submit_pass()
		if receipt.get("ok") != true:
			break
		steps += 1
	return {"steps": steps, "abilities": abilities, "outcome": stage.battle.outcome(),
		"rounds": stage.battle.round_number()}


## Living survivors' real HP plus every positive carried Bleed, by canonical ID.
func _survivors(battle: StitchedRules) -> Dictionary:
	var hp := {}
	var bleed := {}
	for hero in battle.get_heroes():
		if bool(hero.get("lost", false)):
			continue
		var hero_id := str(hero["id"])
		hp[hero_id] = int(hero["hp"])
		var amount := int(hero.get("statuses", {}).get("bleed", 0))
		if amount > 0:
			bleed[hero_id] = amount
	return {"hp": hp, "bleed": bleed}


## Every real Pinch Bleed this battle landed, from the mounted combat receipts.
func _pinch_hits(receipts: Array) -> Array:
	var hits: Array = []
	for action in receipts:
		if str(action.get("actor", "")) != "scissor_crab" \
				or str(action.get("action", "")) != "ability" \
				or str(action.get("ability", "")) != "pinch":
			continue
		for impact in action.get("results", []):
			for entry in impact.get("statuses", []):
				if str(entry.get("status", "")) == "bleed":
					hits.append({"target": str(impact.get("target", "")),
						"amount": int(entry.get("duration", 0)),
						"target_side": str(impact.get("target_side", ""))})
	return hits


## Config-only status contract: a carried Bleed is a positive integer, nothing else.
func _status_contract(base: Dictionary) -> Dictionary:
	var legal: Dictionary = base.duplicate(true)
	legal["heroes"][0]["statuses"] = {"bleed": 2}
	var first := StitchedRules.create(legal)
	var replay := StitchedRules.create(legal)
	var admitted: bool = first.get("ok") == true and replay.get("ok") == true
	if admitted:
		var hero: Dictionary = first["battle"].get_unit(str(legal["heroes"][0]["id"]))
		admitted = hero.get("statuses") == {"bleed": 2} and hero["hp"] == hero["max_hp"] \
			and first["battle"].state_snapshot() == replay["battle"].state_snapshot() \
			and first["battle"].rng_state() == replay["battle"].rng_state()
	_check(admitted, "a positive integer carried Bleed admits and replays at battle setup")
	var refused := true
	var bad_statuses: Array = [
		{"bleed": 0}, {"bleed": -2}, {"bleed": 1.5}, {"bleed": "2"}, {"bleed": true},
		{"weak": 1}, {"bleed": 2, "weak": 1}, "bleed", 2, [], {"bleed": null},
	]
	for bad in bad_statuses:
		var invalid: Dictionary = base.duplicate(true)
		invalid["heroes"][0]["statuses"] = bad
		var created := StitchedRules.create(invalid)
		if created.get("ok") == true or created.get("battle") != null:
			refused = false
	_check(refused, "zero/negative/noninteger/unknown carried statuses are refused at setup")
	return {"ok": admitted, "refused": refused}


func _trace() -> Dictionary:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	# AC1: a fresh title has no Peddler door at all.
	_check(app.stitched_peddler_button != null \
		and not app.stitched_peddler_button.visible \
		and app.stitched_peddler_button.focus_mode == Control.FOCUS_NONE \
		and not app.stitched_peddler_button.is_visible_in_tree() \
		and app._stitched_peddler_roster.is_empty() \
		and not app._open_stitched_peddler() \
		and app.stitched_peddler_panel == null and app.stitched_peddler_visit == null \
		and app.stitched_preview_gold == 0 and app._stitched_bleed_carry.is_empty() \
		and _no_wallet(app),
		"fresh title exposes no Peddler, preview gold, carried Bleed or legacy wallet")
	var base: Dictionary = app._stitched_floor_config()
	_check(not base.is_empty() and base.get("heroes", []).size() == 4 \
		and not base["heroes"][0].has("statuses"),
		"fresh Roadblock admission has four heroes and no starting status")
	var status_contract: Dictionary = _status_contract(base) if not base.is_empty() else {}
	var base_heroes: Array = base.get("heroes", [])
	var warden_id := str(base_heroes[0].get("id", "")) if not base_heroes.is_empty() else ""
	# The app's own carry is validated too: malformed values fail the whole admission.
	var carry_refused := true
	if not warden_id.is_empty():
		for bad in [0, -1, 1.5, "2", true]:
			app._stitched_bleed_carry[warden_id] = bad
			if not (app._stitched_floor_config() as Dictionary).is_empty():
				carry_refused = false
		app._stitched_bleed_carry.erase(warden_id)
	_check(carry_refused and not warden_id.is_empty(),
		"the app refuses a malformed carried Bleed instead of admitting it")
	# AC3: an aborted fight earns nothing and opens no Circle or Peddler.
	var aborted: StitchedBattleScreen = await _admit(app)
	_check(aborted != null and aborted.battle != null and aborted.battle.is_valid(),
		"the first public title Roadblock is genuinely mounted")
	if aborted == null:
		app.free()
		await process_frame
		return {}
	aborted._action_buttons["exit"].pressed.emit()
	await process_frame
	app._stitched_fight_exit(weakref(aborted))
	app._stitched_fight_exit(null)
	_check(app.stitched_sewing_panel == null and app.stitched_peddler_panel == null \
		and not app.stitched_peddler_button.visible \
		and app._stitched_hp_carry.is_empty() and app._stitched_bleed_carry.is_empty() \
		and app.stitched_preview_gold == 0 and app.stitched_preview_scraps == 0 \
		and _no_wallet(app),
		"an unwon or replayed exit earns no HP, Bleed, gold, Circle or Peddler")
	# AC1/AC2: a real victory carries the Pinch's own Bleed and one gold award.
	var first: StitchedBattleScreen = await _admit(app)
	var won: Dictionary = _victory(first) if first != null else {}
	_check(won.get("outcome") == "victory" and int(won.get("steps", 0)) > 0 \
		and int(won.get("abilities", 0)) > 0,
		"the Roadblock is won through mounted legal part actions")
	if won.get("outcome") != "victory":
		app.free()
		await process_frame
		return {}
	var pinch := _pinch_hits(first.receipts)
	var pinch_target := str(pinch[0].get("target", "")) if not pinch.is_empty() else ""
	_check(not pinch.is_empty() and str(pinch[0].get("target_side", "")) == "hero" \
		and int(pinch[0].get("amount", 0)) == 2,
		"Scissor Crab's real Stitched Pinch lands Bleed 2 on a living hero")
	var won_wounds: Dictionary = _survivors(first.battle)
	var victory_hp: Dictionary = won_wounds["hp"]
	var victory_bleed: Dictionary = won_wounds["bleed"]
	_check(victory_hp.size() == 4 and victory_bleed.has(pinch_target) \
		and int(victory_bleed[pinch_target]) > 0,
		"the real Pinch victim still carries positive Bleed at terminal victory")
	var opening: Dictionary = first.battle.opening_strike().duplicate(true)
	var final_round := first.battle.round_number()
	first._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app._stitched_hp_carry == victory_hp \
		and app._stitched_bleed_carry == victory_bleed,
		"only the authentic terminal victory carries survivor HP and integer Bleed by ID")
	_check(app.stitched_preview_gold == 10 and _no_wallet(app),
		"one true win awards exactly 10 preview gold, never the legacy wallet")
	_check(app.stitched_sewing_panel != null and app.stitched_sewing_visit != null,
		"the authentic victory opens the real Sewing Circle")
	if app.stitched_sewing_panel == null:
		app.free()
		await process_frame
		return {}
	var target_id := pinch_target
	var gold_before: int = app.stitched_preview_gold
	var hp_before: Dictionary = app._stitched_hp_carry.duplicate(true)
	var gear_before: Dictionary = app._stitched_gear_overrides.duplicate(true)
	var satchel_before: Array = app.stitched_preview_satchel.duplicate(true)
	var scraps_before: int = app.stitched_preview_scraps
	var candle_before: int = app.stitched_roadblock_candle
	app.stitched_sewing_panel.get_node("SewingLeave").pressed.emit()
	_check(app.stitched_sewing_panel == null and app.stitched_sewing_visit == null \
		and app.stitched_peddler_button.visible \
		and app.stitched_peddler_button.focus_mode != Control.FOCUS_NONE \
		and app.stitched_preview_gold == gold_before \
		and app._stitched_bleed_carry == victory_bleed \
		and app._stitched_hp_carry == hp_before,
		"Circle Leave exposes a keyboard-reachable Peddler and preserves carried status")
	var roster: Array = app._stitched_peddler_roster.duplicate(true)
	var ranks: Array = []
	var roster_ids: Array = []
	for hero in roster:
		ranks.append(int(hero["rank"]))
		roster_ids.append(str(hero["id"]))
	_check(roster.size() == 4 and ranks == [1, 2, 3, 4] \
		and roster_ids == app._stitched_party_picks,
		"the Peddler roster is the four living selected heroes in rank order")
	# AC1: no Peddler can be opened with an impossible wallet or an unliving roster.
	var saved_gold: int = app.stitched_preview_gold
	app.stitched_preview_gold = -1
	_check(not app._open_stitched_peddler() and app.stitched_peddler_panel == null,
		"a Peddler is never opened without a nonnegative integer wallet")
	app.stitched_preview_gold = saved_gold
	var saved_hp_carry: Dictionary = app._stitched_hp_carry.duplicate(true)
	var last_hero := str(roster[3]["id"])
	app._stitched_hp_carry.erase(last_hero)
	_check(not app._open_stitched_peddler() and app.stitched_peddler_panel == null,
		"a Peddler is impossible unless all four heroes are still living")
	app._stitched_hp_carry = saved_hp_carry
	var saved_bleed: Dictionary = app._stitched_bleed_carry.duplicate(true)
	var forged_id := ""
	for hero in roster:
		if not saved_bleed.has(str(hero["id"])):
			forged_id = str(hero["id"])
			app._stitched_bleed_carry[forged_id] = 2
			break
	_check(not forged_id.is_empty() and not app._open_stitched_peddler()
		and app.stitched_peddler_panel == null,
		"a Peddler roster that disagrees with the carried Bleed fails closed")
	app._stitched_bleed_carry = saved_bleed
	app.stitched_peddler_button.pressed.emit()
	await process_frame
	var panel: Control = app.stitched_peddler_panel
	var visit: RunStitchedPeddlerBandage = app.stitched_peddler_visit
	var displayed: Dictionary = app._stitched_peddler_quote.duplicate(true)
	_check(panel != null and visit != null and visit.is_open() \
		and not app.title_view.is_visible_in_tree() \
		and panel.theme == load("res://themes/gothic_theme.tres") \
		and panel.find_child("PeddlerFrame", true, false) is NinePatchRect \
		and displayed.get("node_id") == NODE and displayed.get("mode") == "stitched" \
		and int(displayed.get("price", 0)) == PRICE \
		and int(displayed.get("gold", -1)) == app.stitched_preview_gold \
		and displayed.get("status") == "open" \
		and target_id in displayed.get("eligible", []),
		"the title Peddler mounts the service's exact quoted, Gothic-themed offer")
	if panel == null or visit == null:
		app.free()
		await process_frame
		return {}
	var bandage: Button = panel.find_child("Bandage_" + target_id, true, false)
	var leave_button: Button = panel.find_child("PeddlerLeave", true, false)
	_check(bandage != null and not bandage.disabled \
		and bandage.text.contains(str(PRICE) + " gold") \
		and leave_button != null and not leave_button.disabled,
		"the eligible hero's bandage and the free Leave are both usable")
	var unbled_id := ""
	var rows_ok := true
	for hero in displayed.get("heroes", []):
		var hero_id := str(hero["id"])
		var row: Button = panel.find_child("Bandage_" + hero_id, true, false)
		if row == null:
			rows_ok = false
			continue
		if hero_id == target_id:
			continue
		if not row.disabled:
			rows_ok = false
		if unbled_id.is_empty() and hero.get("statuses", {}).is_empty():
			unbled_id = hero_id
	_check(rows_ok and not unbled_id.is_empty(),
		"every non-bleeding hero is rendered but cannot be bandaged")
	# AC3: every invalid, stale, duplicated or unaffordable request fails closed.
	var opened_state: Dictionary = visit.read_state()
	var gold_held: int = app.stitched_preview_gold
	var carry_held: Dictionary = app._stitched_bleed_carry.duplicate(true)
	var stale: Dictionary = displayed.duplicate(true)
	stale["gold"] = int(stale["gold"]) + 1
	var cheap: Dictionary = displayed.duplicate(true)
	cheap["price"] = 1
	var used_status: Dictionary = displayed.duplicate(true)
	used_status["status"] = "used"
	var refusals: Array = [
		app._stitched_peddler_buy(target_id, stale, weakref(panel)),
		app._stitched_peddler_buy(target_id, cheap, weakref(panel)),
		app._stitched_peddler_buy(target_id, opened_state, null),
		app._stitched_peddler_buy(unbled_id, displayed, weakref(panel)),
		app._stitched_peddler_buy("nobody", displayed, weakref(panel)),
		app._stitched_peddler_buy("", displayed, weakref(panel)),
		app._stitched_peddler_leave(used_status, weakref(panel)),
		app._stitched_peddler_leave(displayed, null),
		app._stitched_peddler_leave(stale, weakref(panel)),
	]
	var all_refused := true
	for refused in refusals:
		if refused.get("ok", true) != false:
			all_refused = false
	_check(all_refused and visit.read_state() == opened_state \
		and app.stitched_peddler_panel == panel and app.stitched_peddler_visit == visit \
		and app.stitched_preview_gold == gold_held \
		and app._stitched_bleed_carry == carry_held and not app._open_stitched_peddler(),
		"stale, forged, duplicated, untargeted, unpriced and concurrent requests change nothing")
	_check(not RunStitchedPeddlerBandage.open_stitched(
		NODE, displayed["heroes"], PRICE, 0).is_valid() \
		and not RunStitchedPeddlerBandage.open_stitched(
			NODE, displayed["heroes"], PRICE, -PRICE).is_valid() \
		and not RunStitchedPeddlerBandage.open_stitched(
			NODE, displayed["heroes"], PRICE, "10").is_valid(),
		"the Peddler bandage never exists without a positive integer quote")
	# AC2: one lawful bandage spends the quoted gold exactly once.
	bandage.pressed.emit()
	var expected_carry: Dictionary = victory_bleed.duplicate(true)
	expected_carry.erase(target_id)
	_check(app.stitched_peddler_panel == null and app.stitched_peddler_visit == null \
		and app.stitched_preview_gold == gold_before - PRICE \
		and visit.is_consumed() and not visit.is_open() \
		and not app._stitched_bleed_carry.has(target_id) \
		and app._stitched_bleed_carry == expected_carry \
		and app._stitched_hp_carry == hp_before \
		and app._stitched_gear_overrides == gear_before \
		and app.stitched_preview_satchel == satchel_before \
		and app.stitched_preview_scraps == scraps_before \
		and app.stitched_roadblock_candle == candle_before \
		and not app.stitched_peddler_button.visible \
		and app.title_view.is_visible_in_tree() and _no_wallet(app),
		"one bandage spends 10 gold once, cures only its hero and preserves every other resource")
	var consumed_state: Dictionary = visit.read_state()
	var duplicated: Array = [
		visit.choose_bandage(target_id, NODE, opened_state),
		app._stitched_peddler_buy(target_id, displayed, weakref(panel)),
		app._stitched_peddler_leave(displayed, weakref(panel)),
	]
	bandage.pressed.emit()
	var duplicated_ok := true
	for refused in duplicated:
		if refused.get("ok", true) != false:
			duplicated_ok = false
	_check(duplicated_ok and visit.read_state() == consumed_state \
		and app.stitched_preview_gold == gold_before - PRICE \
		and app._stitched_bleed_carry == expected_carry \
		and app.stitched_peddler_panel == null,
		"a duplicated one-shot receipt, replayed button and stale Leave cannot cure or spend twice")
	await process_frame
	# AC2: the cure survives admission into the next real Fight.
	var next: StitchedBattleScreen = await _admit(app)
	_check(next != null and next.battle != null and next.battle.is_valid(),
		"the title Roadblock still mounts a real second Fight after the Peddler")
	if next == null:
		app.free()
		await process_frame
		return {}
	var mounted_wounds: Dictionary = _survivors(next.battle)
	var config_bleed := {}
	for hero in next.config.get("heroes", []):
		var amount := int(hero.get("statuses", {}).get("bleed", 0))
		if amount > 0:
			config_bleed[str(hero["id"])] = amount
	_check(mounted_wounds["hp"] == victory_hp \
		and mounted_wounds["bleed"] == expected_carry \
		and config_bleed == expected_carry \
		and not str(target_id) in config_bleed,
		"the cured hero's Bleed stays cured while survivor HP carries into the next real Fight")
	var next_opening: Dictionary = next.battle.opening_strike().duplicate(true)
	var next_state: Dictionary = next.battle.state_snapshot()
	var next_config: Dictionary = next.config.duplicate(true)
	_check(next.config.get("candle") == candle_before - 8,
		"the next Fight burns only its own authored candle entry cost")
	next._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_preview_gold == gold_before - PRICE \
		and app._stitched_bleed_carry == expected_carry \
		and app._stitched_hp_carry == hp_before and app.stitched_sewing_panel == null \
		and app.stitched_peddler_panel == null and not app.stitched_peddler_button.visible \
		and _no_wallet(app),
		"an aborted next Fight earns nothing, reopens no Peddler and keeps the cure")
	# AC2/AC3: a later true win earns one new offer whose free Leave preserves all.
	var third: StitchedBattleScreen = await _admit(app)
	var third_won: Dictionary = _victory(third) if third != null else {}
	_check(third_won.get("outcome") == "victory",
		"a later real Fight is also won through mounted part actions")
	if third_won.get("outcome") != "victory":
		app.free()
		await process_frame
		return {}
	var third_wounds: Dictionary = _survivors(third.battle)
	var third_opening: Dictionary = third.battle.opening_strike().duplicate(true)
	third._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_preview_gold == 10 \
		and app._stitched_bleed_carry == third_wounds["bleed"] \
		and app._stitched_hp_carry == third_wounds["hp"] \
		and app.stitched_sewing_panel != null,
		"the later victory awards its own 10 preview gold and carries its own wounds")
	if app.stitched_sewing_panel == null:
		app.free()
		await process_frame
		return {}
	var hp_second: Dictionary = app._stitched_hp_carry.duplicate(true)
	var gear_second: Dictionary = app._stitched_gear_overrides.duplicate(true)
	var satchel_second: Array = app.stitched_preview_satchel.duplicate(true)
	var scraps_second: int = app.stitched_preview_scraps
	var candle_second: int = app.stitched_roadblock_candle
	var carry_second: Dictionary = app._stitched_bleed_carry.duplicate(true)
	app.stitched_sewing_panel.get_node("SewingLeave").pressed.emit()
	_check(app.stitched_peddler_button.visible and app._stitched_peddler_roster.size() == 4,
		"a second Circle Leave earns a second lawful Peddler offer")
	app.stitched_peddler_button.pressed.emit()
	await process_frame
	var second_panel: Control = app.stitched_peddler_panel
	var second_visit: RunStitchedPeddlerBandage = app.stitched_peddler_visit
	var second_quote: Dictionary = app._stitched_peddler_quote.duplicate(true)
	var second_leave: Button = null
	if second_panel != null:
		second_leave = second_panel.find_child("PeddlerLeave", true, false)
	_check(second_panel != null and second_visit != null and second_leave != null \
		and not second_leave.disabled \
		and int(second_quote.get("price", 0)) == PRICE \
		and int(second_quote.get("gold", -1)) == 10,
		"the later Peddler quotes the same one-use bandage and a free Leave")
	# An untargeted buy is refused for any hero the quote does not list.
	var untargeted := ""
	for hero in second_quote.get("heroes", []):
		if not str(hero["id"]) in second_quote.get("eligible", []):
			untargeted = str(hero["id"])
			break
	var noneligible_rows_disabled := second_panel != null
	if second_panel != null:
		for hero in second_quote.get("heroes", []):
			if str(hero["id"]) in second_quote.get("eligible", []):
				continue
			var row: Button = second_panel.find_child("Bandage_" + str(hero["id"]), true, false)
			if row == null or not row.disabled:
				noneligible_rows_disabled = false
	var no_target_refused := {"ok": true}
	if second_panel != null and not untargeted.is_empty():
		no_target_refused = app._stitched_peddler_buy(
			untargeted, second_quote, weakref(second_panel))
	_check(second_panel != null and not untargeted.is_empty() \
		and noneligible_rows_disabled and no_target_refused.get("ok", true) == false \
		and app.stitched_preview_gold == 10 \
		and app._stitched_bleed_carry == carry_second \
		and app.stitched_peddler_panel == second_panel,
		"a non-bleeding hero's rendered row is disabled and its buy is refused")
	if second_panel != null and second_leave != null:
		second_leave.pressed.emit()
	_check(app.stitched_peddler_panel == null and app.stitched_peddler_visit == null \
		and not app.stitched_peddler_button.visible \
		and app.stitched_preview_gold == 10 \
		and app._stitched_bleed_carry == carry_second \
		and app._stitched_hp_carry == hp_second \
		and app._stitched_gear_overrides == gear_second \
		and app.stitched_preview_satchel == satchel_second \
		and app.stitched_preview_scraps == scraps_second \
		and app.stitched_roadblock_candle == candle_second \
		and _no_wallet(app),
		"a free Peddler Leave preserves carried Bleed and every other resource")
	if second_visit != null:
		_check(not second_visit.leave(NODE, second_quote).get("ok", true) \
			and app.stitched_preview_gold == 10 \
			and app._stitched_bleed_carry == carry_second,
			"a left Peddler refuses a second Leave without spending or curing")
		var late_target := ""
		var late_eligible: Array = second_quote.get("eligible", [])
		if not late_eligible.is_empty():
			late_target = str(late_eligible[0])
		if not late_target.is_empty():
			_check(not second_visit.choose_bandage(
				late_target, NODE, second_quote).get("ok", true) \
				and app.stitched_preview_gold == 10 \
				and app._stitched_bleed_carry == carry_second,
				"a left Peddler refuses a late bandage without spending or curing")
	var final_gold: int = app.stitched_preview_gold
	app.free()
	await process_frame
	return {
		"pinch": pinch.duplicate(true), "opening": opening, "final_round": final_round,
		"victory_hp": victory_hp, "victory_bleed": victory_bleed,
		"roster": roster, "displayed": displayed, "opened_state": opened_state,
		"next_config": next_config, "next_opening": next_opening,
		"next_state": next_state, "third_bleed": third_wounds["bleed"],
		"third_hp": third_wounds["hp"], "third_opening": third_opening,
		"second_quote": second_quote, "second_carry": carry_second,
		"gold": final_gold, "status_contract": status_contract,
	}


## A confirmed party reselection must clear only the deselected hero's carried
## Bleed and withdraw the stale Peddler offer; a draft or Cancel clears nothing.
func _reselection_trace() -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var first: StitchedBattleScreen = await _admit(app)
	var won: Dictionary = _victory(first) if first != null else {}
	_check(won.get("outcome") == "victory", "reselection scenario wins the real Roadblock")
	if won.get("outcome") != "victory":
		app.free()
		await process_frame
		return
	first._action_buttons["exit"].pressed.emit()
	await process_frame
	if app.stitched_sewing_panel == null:
		_check(false, "reselection scenario reaches the real Sewing Circle")
		app.free()
		await process_frame
		return
	app.stitched_sewing_panel.get_node("SewingLeave").pressed.emit()
	var bleed_before: Dictionary = app._stitched_bleed_carry.duplicate(true)
	var hp_before: Dictionary = app._stitched_hp_carry.duplicate(true)
	var bled_id := ""
	for id in bleed_before:
		bled_id = str(id)
		break
	_check(not bleed_before.is_empty() and not bled_id.is_empty() \
		and app.stitched_peddler_button.visible,
		"the reselection scenario has a real carried Bleed and an earned Peddler")
	app.stitched_fight_button.pressed.emit()
	await process_frame
	var picker: LiveEventChoicePanel = app.stitched_event_panel
	_check(picker != null and app._stitched_party_checkboxes.has(bled_id) \
		and app.stitched_peddler_panel == null,
		"the Roadblock party picker reopens without altering any Peddler state")
	if picker == null or not app._stitched_party_checkboxes.has(bled_id):
		app.free()
		await process_frame
		return
	var spare := ""
	for id in StitchedPartyAdmission.HERO_IDS:
		if not id in app._stitched_party_picks:
			spare = str(id)
			break
	_check(not spare.is_empty(), "a legal alternative hero exists for the reselection")
	# An unfinished three-hero draft and Cancel leave the carry untouched.
	app._stitched_party_checkboxes[bled_id].button_pressed = false
	_check(app._stitched_bleed_carry == bleed_before \
		and app._stitched_hp_carry == hp_before \
		and app.stitched_peddler_button.visible,
		"an unfinished draft cannot clear carried Bleed or the Peddler")
	app._stitched_party_cancel_button.pressed.emit()
	_check(app._stitched_bleed_carry == bleed_before and app._stitched_hp_carry == hp_before,
		"Cancel restores the confirmed party without clearing any carry")
	# A genuine Confirm clears only the deselected hero and withdraws the offer.
	if not spare.is_empty():
		app._stitched_party_checkboxes[bled_id].button_pressed = false
		app._stitched_party_checkboxes[spare].button_pressed = true
		app._stitched_party_confirm_button.pressed.emit()
		var remaining := true
		for id in bleed_before:
			if str(id) == bled_id:
				continue
			remaining = remaining and app._stitched_bleed_carry.get(id) == bleed_before[id]
		_check(not app._stitched_bleed_carry.has(bled_id) and remaining \
			and not app._stitched_hp_carry.has(bled_id) \
			and app._stitched_party_picks.has(spare) \
			and not app._stitched_party_picks.has(bled_id) \
			and app._stitched_peddler_roster.is_empty() \
			and app._stitched_peddler_living_roster().is_empty() \
			and not app.stitched_peddler_button.visible \
			and not app._open_stitched_peddler(),
			"confirmed reselection clears only the deselected hero's Bleed and withdraws the Peddler")
	picker.get_choice_buttons()[2].pressed.emit()
	await process_frame
	_check(app.stitched_event_panel == null and not app.stitched_peddler_button.visible \
		and not app._open_stitched_peddler() and app.stitched_peddler_panel == null \
		and _no_wallet(app),
		"the reselection Roadblock Leave spends no run resource and reopens no Peddler")
	app.free()
	await process_frame


## Confirming the SAME four heroes in the same rank order must not withdraw the
## offer earned at Circle Leave: only a genuine reselection (tested above) may.
func _unchanged_confirm_trace() -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var first: StitchedBattleScreen = await _admit(app)
	var won: Dictionary = _victory(first) if first != null else {}
	_check(won.get("outcome") == "victory",
		"the unchanged party scenario wins the real Roadblock")
	if won.get("outcome") != "victory":
		app.free()
		await process_frame
		return
	var wounds: Dictionary = _survivors(first.battle)
	first._action_buttons["exit"].pressed.emit()
	await process_frame
	if app.stitched_sewing_panel == null:
		_check(false, "the unchanged party scenario reaches the real Sewing Circle")
		app.free()
		await process_frame
		return
	app.stitched_sewing_panel.get_node("SewingLeave").pressed.emit()
	_check(app.stitched_peddler_button.visible \
		and app._stitched_peddler_roster.size() == 4 \
		and not wounds["bleed"].is_empty(),
		"the unchanged party scenario really earns a Peddler offer and carried Bleed")
	if not app.stitched_peddler_button.visible or wounds["bleed"].is_empty():
		app.free()
		await process_frame
		return
	var bleed_before: Dictionary = app._stitched_bleed_carry.duplicate(true)
	var hp_before: Dictionary = app._stitched_hp_carry.duplicate(true)
	var roster_before: Array = app._stitched_peddler_roster.duplicate(true)
	var gold_before: int = app.stitched_preview_gold
	var gear_before: Dictionary = app._stitched_gear_overrides.duplicate(true)
	var satchel_before: Array = app.stitched_preview_satchel.duplicate(true)
	var scraps_before: int = app.stitched_preview_scraps
	var candle_before: int = app.stitched_roadblock_candle
	app.stitched_fight_button.pressed.emit()
	await process_frame
	var picker: LiveEventChoicePanel = app.stitched_event_panel
	var confirm_enabled: bool = is_instance_valid(app._stitched_party_confirm_button) \
		and not app._stitched_party_confirm_button.disabled
	_check(picker != null and confirm_enabled \
		and app._stitched_party_draft == app._stitched_party_picks,
		"the reopened Roadblock picker offers an enabled Confirm for the unchanged four")
	if picker == null or not confirm_enabled:
		app.free()
		await process_frame
		return
	# The unchanged confirmation itself must keep the earned offer intact.
	app._stitched_party_confirm_button.pressed.emit()
	_check(app._stitched_peddler_roster == roster_before \
		and app.stitched_peddler_button.visible \
		and not app.stitched_peddler_button.disabled \
		and app._stitched_bleed_carry == bleed_before \
		and app._stitched_hp_carry == hp_before \
		and not app._stitched_peddler_living_roster().is_empty(),
		"confirming the unchanged four preserves the Peddler roster and carried Bleed")
	# The Roadblock Leave is the real player exit back to the title.
	picker.get_choice_buttons()[2].pressed.emit()
	await process_frame
	_check(app.stitched_event_panel == null \
		and app._stitched_peddler_roster == roster_before \
		and app.stitched_peddler_button.is_visible_in_tree() \
		and not app.stitched_peddler_button.disabled \
		and app.stitched_peddler_button.focus_mode != Control.FOCUS_NONE \
		and app._stitched_peddler_living_roster() == roster_before \
		and app._stitched_bleed_carry == bleed_before \
		and app._stitched_hp_carry == hp_before \
		and app.stitched_preview_gold == gold_before \
		and app._stitched_gear_overrides == gear_before \
		and app.stitched_preview_satchel == satchel_before \
		and app.stitched_preview_scraps == scraps_before \
		and app.stitched_roadblock_candle == candle_before \
		and _no_wallet(app),
		"unchanged Confirm plus Roadblock Leave keeps the title Peddler openable and spends nothing")
	# Openability is proven through the real title door, not just a flag.
	app.stitched_peddler_button.pressed.emit()
	await process_frame
	var panel: Control = app.stitched_peddler_panel
	var quote: Dictionary = app._stitched_peddler_quote.duplicate(true)
	var quoted_bleed := {}
	var quoted_ids: Array = []
	for hero in quote.get("heroes", []):
		quoted_ids.append(str(hero["id"]))
		var amount := int(hero.get("statuses", {}).get("bleed", 0))
		if amount > 0:
			quoted_bleed[str(hero["id"])] = amount
	_check(panel != null and app.stitched_peddler_visit != null \
		and app.stitched_peddler_visit.is_open() \
		and int(quote.get("price", 0)) == PRICE \
		and int(quote.get("gold", -1)) == gold_before \
		and quote.get("heroes", []).size() == 4 \
		and quoted_ids == app._stitched_party_picks \
		and quoted_bleed == bleed_before,
		"the preserved Peddler still quotes the unchanged four and their carried Bleed")
	var leave: Button = panel.find_child("PeddlerLeave", true, false) if panel != null else null
	_check(leave != null and not leave.disabled,
		"the preserved Peddler still offers its free Leave")
	if leave != null:
		leave.pressed.emit()
	_check(app.stitched_peddler_panel == null and app.stitched_peddler_visit == null \
		and app.stitched_preview_gold == gold_before \
		and app._stitched_bleed_carry == bleed_before \
		and app._stitched_hp_carry == hp_before \
		and app._stitched_gear_overrides == gear_before \
		and app.stitched_preview_satchel == satchel_before \
		and app.stitched_preview_scraps == scraps_before \
		and app.stitched_roadblock_candle == candle_before \
		and _no_wallet(app),
		"the preserved Peddler's free Leave preserves carried Bleed and every resource")
	app.free()
	await process_frame


## A Peddler whose wallet is one gold short must disclose the quote, disable
## every bandage row, refuse a direct buy and still allow the free Leave.
func _unaffordable_trace() -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var first: StitchedBattleScreen = await _admit(app)
	var won: Dictionary = _victory(first) if first != null else {}
	_check(won.get("outcome") == "victory", "unaffordable scenario wins the real Roadblock")
	if won.get("outcome") != "victory":
		app.free()
		await process_frame
		return
	first._action_buttons["exit"].pressed.emit()
	await process_frame
	if app.stitched_sewing_panel == null:
		_check(false, "unaffordable scenario reaches the real Sewing Circle")
		app.free()
		await process_frame
		return
	app.stitched_sewing_panel.get_node("SewingLeave").pressed.emit()
	var carry_before: Dictionary = app._stitched_bleed_carry.duplicate(true)
	var hp_before: Dictionary = app._stitched_hp_carry.duplicate(true)
	var gear_before: Dictionary = app._stitched_gear_overrides.duplicate(true)
	var satchel_before: Array = app.stitched_preview_satchel.duplicate(true)
	var scraps_before: int = app.stitched_preview_scraps
	var candle_before: int = app.stitched_roadblock_candle
	# One gold less than the earned quote: only the real economy's own wallet is short.
	app.stitched_preview_gold = PRICE - 1
	app.stitched_peddler_button.pressed.emit()
	await process_frame
	var panel: Control = app.stitched_peddler_panel
	var visit: RunStitchedPeddlerBandage = app.stitched_peddler_visit
	var quote: Dictionary = app._stitched_peddler_quote.duplicate(true)
	_check(panel != null and visit != null and not carry_before.is_empty() \
		and int(quote.get("price", 0)) == PRICE \
		and int(quote.get("gold", -1)) == PRICE - 1 \
		and quote.get("eligible", []).size() > 0,
		"an unaffordable quote still discloses its exact price and bleeding targets")
	var target := str(quote.get("eligible", [""])[0]) if quote.get("eligible", []).size() > 0 else ""
	var row: Button = panel.find_child("Bandage_" + target, true, false) if panel != null else null
	var refused: Dictionary = app._stitched_peddler_buy(
		target, quote, weakref(panel)) if panel != null else {"ok": true}
	_check(row != null and row.disabled and refused.get("ok", true) == false \
		and app.stitched_preview_gold == PRICE - 1 \
		and app._stitched_bleed_carry == carry_before \
		and app.stitched_peddler_panel == panel,
		"an unaffordable bandage row is disabled and a direct buy fails without spending")
	var leave: Button = panel.find_child("PeddlerLeave", true, false) if panel != null else null
	_check(leave != null and not leave.disabled \
		and app._stitched_peddler_leave(quote, weakref(panel)).get("ok") == true \
		and app.stitched_peddler_panel == null and app.stitched_peddler_visit == null \
		and app.stitched_preview_gold == PRICE - 1 \
		and app._stitched_bleed_carry == carry_before \
		and app._stitched_hp_carry == hp_before \
		and app._stitched_gear_overrides == gear_before \
		and app.stitched_preview_satchel == satchel_before \
		and app.stitched_preview_scraps == scraps_before \
		and app.stitched_roadblock_candle == candle_before \
		and _no_wallet(app),
		"the short wallet's free Leave changes no status, resource or wallet gold")
	app.free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var one: Dictionary = await _trace()
	var two: Dictionary = await _trace()
	_check(not one.is_empty() and one == two,
		"two fresh identical Roadblock/Victory/Circle/Peddler/Fight traces replay exactly")
	await _reselection_trace()
	await _unchanged_confirm_trace()
	await _unaffordable_trace()
	for failure in failures:
		printerr(failure)
	print("stitched_s6_peddler_bandage_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
