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
	app._open_stitched_fight() # Explicit Roadblock regression entry.
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
## legal rank. While the Scissor Crab has not yet landed a Pinch from its round-three
## authored rotation the party leaves the crab alone (front-rank foes, mends or legal
## passes only), so the real Pinch gets its turn; afterwards it finishes the fight before
## that Bleed expires. Every action is a genuine mounted part or legal pass.
func _victory(stage: StitchedBattleScreen) -> Dictionary:
	if stage == null or stage.battle == null or not stage.battle.is_valid():
		return {}
	var steps := 0
	var abilities := 0
	var pinch_hit_round := 0
	for iteration in range(200):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		var round_now := stage.battle.round_number()
		var seen := stage.receipts.size()
		var hold := round_now <= 3 and pinch_hit_round < 3
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
					if hold and _only_crab_targets(legal):
						continue
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
		for index in range(seen, stage.receipts.size()):
			var action: Dictionary = stage.receipts[index]
			if str(action.get("actor", "")) != "scissor_crab" \
					or str(action.get("action", "")) != "ability" \
					or str(action.get("ability", "")) != "pinch":
				continue
			for impact in action.get("results", []):
				if bool(impact.get("hit", false)):
					pinch_hit_round = round_now
	return {"steps": steps, "abilities": abilities, "outcome": stage.battle.outcome(),
		"rounds": stage.battle.round_number()}


## A hold-phase strike is skipped when the Scissor Crab is all it could touch.
func _only_crab_targets(legal: Array) -> bool:
	for target in legal:
		if str(target.get("id", "")) != "scissor_crab":
			return false
	return not legal.is_empty()


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


## A visit snapshot minus its per-visit identity: two fresh, otherwise identical
## runs open different visits on purpose, so only the identity is excluded from
## the exact-replay comparison; every other field is still compared.
func _replay_state(state: Dictionary) -> Dictionary:
	var copy: Dictionary = state.duplicate(true)
	copy.erase("visit_id")
	return copy


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
	# Without a real living Pinch witness the Peddler chain below has no subject;
	# record the failures above, tear the app down and never dereference a null row.
	if pinch.is_empty() or pinch_target.is_empty() or not victory_bleed.has(pinch_target) \
			or int(victory_bleed[pinch_target]) <= 0:
		app.free()
		await process_frame
		return {}
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
	# Malformed candle authority must refuse before creating a visit or
	# consuming the earned stop, even though an authenticated roster exists.
	var saved_candle: int = int(app.stitched_roadblock_candle)
	seed(30071)
	var expected_rng := randi()
	seed(30071)
	for invalid_candle in [-1, 101]:
		app.stitched_roadblock_candle = invalid_candle
		_check(not app._open_stitched_peddler() and app.stitched_peddler_panel == null \
			and app.stitched_peddler_visit == null \
			and app.stitched_peddler_candle_visit == null \
			and app.stitched_peddler_part_visit == null \
			and app._stitched_postvictory_stop_available \
			and app._stitched_peddler_roster == roster \
			and app.stitched_preview_gold == saved_gold \
			and app.stitched_roadblock_candle == invalid_candle,
			"invalid candle admission refuses without debit, authority or RNG spend")
	app.stitched_roadblock_candle = saved_candle
	_check(randi() == expected_rng,
		"invalid Peddler candle admission consumes no RNG")
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
		and app.stitched_roadblock_candle == maxi(0, candle_before - 8) \
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
	# An absent or disabled row has no lawful buy to press: keep the recorded
	# failures and stop before emitting on a missing control.
	if bandage == null or bandage.disabled or leave_button == null or leave_button.disabled:
		app.free()
		await process_frame
		return {}
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
		and app.stitched_roadblock_candle == maxi(0, candle_before - 8) \
		and not app.stitched_peddler_button.visible \
		and app.title_view.is_visible_in_tree() and _no_wallet(app),
		"one bandage spends 10 gold once, cures Bleed and preserves the paid-entry candle balance")
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
	_check(next.config.get("candle") == maxi(0, candle_before - 16),
		"Peddler and next Fight each apply their own eight-point candle node entry")
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
		and app.stitched_roadblock_candle == maxi(0, candle_second - 8) \
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
		and app.stitched_roadblock_candle == maxi(0, candle_second - 8) \
		and _no_wallet(app),
		"Leave adds no cost beyond the paid Peddler entry and preserves all other carry")
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
		"roster": roster, "displayed": _replay_state(displayed),
		"opened_state": _replay_state(opened_state),
		"next_config": next_config, "next_opening": next_opening,
		"next_state": next_state, "third_bleed": third_wounds["bleed"],
		"third_hp": third_wounds["hp"], "third_opening": third_opening,
		"second_quote": _replay_state(second_quote), "second_carry": carry_second,
		"gold": final_gold, "status_contract": status_contract,
	}


## After a genuine four-survivor Circle Leave the earned IDs are sealed: the
## next Roadblock shows them read-only, and neither the current panel's nor a
## stale forged picker callback can swap a wounded survivor for a free spare.
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
	var picks_before: Array = app._stitched_party_picks.duplicate()
	var receipt_before: Dictionary = app._stitched_party_receipt.duplicate(true)
	var fray_before: Dictionary = app._stitched_fray_carry.duplicate(true)
	var ranks_before: Dictionary = app._stitched_rank_carry.duplicate(true)
	var gear_before: Dictionary = app._stitched_gear_overrides.duplicate(true)
	var roster_before: Array = app._stitched_peddler_roster.duplicate(true)
	var living_before: Array = app._stitched_peddler_living_roster().duplicate(true)
	var gold_before: int = app.stitched_preview_gold
	var satchel_before: Array = app.stitched_preview_satchel.duplicate(true)
	var scraps_before: int = app.stitched_preview_scraps
	var candle_before: int = app.stitched_roadblock_candle
	var stop_before: bool = app._stitched_postvictory_stop_available
	_check(app._stitched_party_locked and picks_before.size() == 4 \
		and receipt_before.get("ok") == true and not living_before.is_empty() \
		and stop_before,
		"the authentic Circle Leave alone seals the four earned IDs and their earned stop")
	app._open_stitched_fight() # Explicit Roadblock regression entry.
	await process_frame
	var picker: LiveEventChoicePanel = app.stitched_event_panel
	_check(picker != null and app._stitched_party_locked \
		and app.stitched_peddler_panel == null,
		"the earned Roadblock reopens read-only without altering any Peddler state")
	if picker == null:
		app.free()
		await process_frame
		return
	var container: Node = picker.find_child("StitchedPartyPicker", true, false)
	var labels: Array = container.find_children("*", "Label", true, false) \
		if container != null else []
	var choices: Array = picker.get_choice_buttons()
	var party: Dictionary = StitchedPartyAdmission.admit(picks_before)
	var read_only_ok: bool = container != null and party.get("ok") == true \
		and choices.size() == 3 and labels.size() == 5 \
		and container.find_children("*", "CheckBox", true, false).is_empty() \
		and app._stitched_party_checkboxes.is_empty() \
		and not is_instance_valid(app._stitched_party_confirm_button) \
		and not is_instance_valid(app._stitched_party_cancel_button) \
		and not choices[0].disabled and not choices[2].disabled \
		and choices[0].focus_mode != Control.FOCUS_NONE \
		and choices[2].focus_mode != Control.FOCUS_NONE
	if read_only_ok:
		for hero in party["heroes"]:
			var found := false
			for display in labels:
				if str(display.text) == "%d  %s" % [hero["rank"], hero["name"]]:
					found = true
			read_only_ok = read_only_ok and found
	_check(read_only_ok,
		"the locked Roadblock shows the four read-only survivors with usable Fight and Leave")
	var spare := ""
	for id in StitchedPartyAdmission.HERO_IDS:
		if not id in picks_before:
			spare = str(id)
			break
	_check(not spare.is_empty(),
		"a legal spare hero exists but must stay excluded from the earned four")
	# Current-panel and stale forged callbacks must all fail closed.
	var source: WeakRef = weakref(picker)
	var gate: RunV3FightEventGate = app.stitched_event_gate
	var generation: int = picker._generation
	seed(52811)
	var rng_expected: int = randi()
	seed(52811)
	app._stitched_picker_changed(false, bled_id, source, gate, generation)
	app._stitched_picker_changed(true, spare, source, gate, generation)
	app._stitched_picker_confirm(source, gate, generation)
	app._stitched_picker_cancel(source, gate, generation)
	app._stitched_picker_changed(false, bled_id, WeakRef.new(), gate, generation + 1)
	app._stitched_picker_confirm(WeakRef.new(), gate, generation + 1)
	app._stitched_picker_cancel(WeakRef.new(), gate, generation + 1)
	_check(app._stitched_party_picks == picks_before \
		and app._stitched_party_draft == picks_before \
		and app._stitched_party_receipt == receipt_before \
		and app.stitched_event_panel == picker and not gate.is_claimed() \
		and app._stitched_bleed_carry == bleed_before \
		and app._stitched_hp_carry == hp_before \
		and app._stitched_fray_carry == fray_before \
		and app._stitched_rank_carry == ranks_before \
		and app._stitched_gear_overrides == gear_before \
		and app._stitched_peddler_roster == roster_before \
		and app._stitched_peddler_living_roster() == living_before \
		and app.stitched_preview_gold == gold_before \
		and app.stitched_preview_satchel == satchel_before \
		and app.stitched_preview_scraps == scraps_before \
		and app.stitched_roadblock_candle == candle_before \
		and app._stitched_postvictory_stop_available == stop_before \
		and randi() == rng_expected and _no_wallet(app),
		"current and stale picker callbacks cannot reseat the locked party or change carry, RNG, resources or stop")
	choices[2].pressed.emit()
	await process_frame
	_check(app.stitched_event_panel == null and app._stitched_party_locked \
		and app._stitched_party_picks == picks_before \
		and app._stitched_party_receipt == receipt_before \
		and app._stitched_bleed_carry == bleed_before \
		and app._stitched_hp_carry == hp_before \
		and app._stitched_fray_carry == fray_before \
		and app._stitched_rank_carry == ranks_before \
		and app._stitched_gear_overrides == gear_before \
		and app._stitched_peddler_roster == roster_before \
		and app.stitched_preview_gold == gold_before \
		and app.stitched_preview_satchel == satchel_before \
		and app.stitched_preview_scraps == scraps_before \
		and app.stitched_roadblock_candle == candle_before \
		and app._stitched_postvictory_stop_available == stop_before \
		and _no_wallet(app),
		"the real read-only Roadblock Leave spends nothing and keeps every earned survivor")
	_check(app.stitched_peddler_button.visible \
		and app.stitched_peddler_button.focus_mode != Control.FOCUS_NONE \
		and app._stitched_peddler_living_roster() == living_before \
		and app._open_stitched_peddler() and app.stitched_peddler_panel != null \
		and app.stitched_peddler_visit != null,
		"the earned Peddler still opens through its real title door after the locked Leave")
	var served: Control = app.stitched_peddler_panel
	var visit: RunStitchedPeddlerBandage = app.stitched_peddler_visit
	var quote: Dictionary = app._stitched_peddler_quote.duplicate(true)
	var quoted_ids: Array = []
	var quoted_bleed := {}
	for hero in quote.get("heroes", []):
		quoted_ids.append(str(hero["id"]))
		var amount := int(hero.get("statuses", {}).get("bleed", 0))
		if amount > 0:
			quoted_bleed[str(hero["id"])] = amount
	_check(served != null and visit != null and visit.is_open() \
		and quote.get("heroes", []).size() == 4 \
		and quoted_ids == picks_before and quoted_bleed == bleed_before \
		and int(quote.get("price", 0)) == PRICE \
		and int(quote.get("gold", -1)) == gold_before,
		"the preserved Peddler quotes the locked four and their carried Bleed")
	var free_leave: Button = served.find_child("PeddlerLeave", true, false) \
		if served != null else null
	_check(free_leave != null and not free_leave.disabled,
		"the preserved Peddler still offers its free Leave")
	if free_leave != null:
		free_leave.pressed.emit()
	_check(app.stitched_peddler_panel == null and app.stitched_peddler_visit == null \
		and app.stitched_preview_gold == gold_before \
		and app._stitched_bleed_carry == bleed_before \
		and app._stitched_hp_carry == hp_before \
		and app._stitched_gear_overrides == gear_before \
		and app.stitched_preview_satchel == satchel_before \
		and app.stitched_preview_scraps == scraps_before \
		and app.stitched_roadblock_candle == maxi(0, candle_before - 8) \
		and _no_wallet(app),
		"the preserved Peddler's Leave retains all carry after the one entry toll")
	app.free()
	await process_frame


## A genuine Circle Leave also seals the unchanged four: the reopened Roadblock
## offers no editing control at all, and the real Leave keeps the earned Peddler.
func _locked_roster_trace() -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var first: StitchedBattleScreen = await _admit(app)
	var won: Dictionary = _victory(first) if first != null else {}
	_check(won.get("outcome") == "victory",
		"the locked roster scenario wins the real Roadblock")
	if won.get("outcome") != "victory":
		app.free()
		await process_frame
		return
	var wounds: Dictionary = _survivors(first.battle)
	first._action_buttons["exit"].pressed.emit()
	await process_frame
	if app.stitched_sewing_panel == null:
		_check(false, "the locked roster scenario reaches the real Sewing Circle")
		app.free()
		await process_frame
		return
	app.stitched_sewing_panel.get_node("SewingLeave").pressed.emit()
	_check(app.stitched_peddler_button.visible \
		and app._stitched_peddler_roster.size() == 4 \
		and app.stitched_peddler_button.focus_mode != Control.FOCUS_NONE \
		and not wounds["bleed"].is_empty(),
		"the locked roster scenario really earns a focusable Peddler and carried Bleed")
	if not app.stitched_peddler_button.visible or wounds["bleed"].is_empty():
		app.free()
		await process_frame
		return
	var bleed_before: Dictionary = app._stitched_bleed_carry.duplicate(true)
	var hp_before: Dictionary = app._stitched_hp_carry.duplicate(true)
	var picks_before: Array = app._stitched_party_picks.duplicate()
	var receipt_before: Dictionary = app._stitched_party_receipt.duplicate(true)
	var roster_before: Array = app._stitched_peddler_roster.duplicate(true)
	var gold_before: int = app.stitched_preview_gold
	var gear_before: Dictionary = app._stitched_gear_overrides.duplicate(true)
	var satchel_before: Array = app.stitched_preview_satchel.duplicate(true)
	var scraps_before: int = app.stitched_preview_scraps
	var candle_before: int = app.stitched_roadblock_candle
	app._open_stitched_fight() # Explicit Roadblock regression entry.
	await process_frame
	var picker: LiveEventChoicePanel = app.stitched_event_panel
	var container: Node = picker.find_child("StitchedPartyPicker", true, false) \
		if picker != null else null
	var labels: Array = container.find_children("*", "Label", true, false) \
		if container != null else []
	var choices: Array = picker.get_choice_buttons() if picker != null else []
	var party: Dictionary = StitchedPartyAdmission.admit(picks_before)
	var locked_ok: bool = picker != null and app._stitched_party_locked \
		and container != null and party.get("ok") == true \
		and app._stitched_party_draft == picks_before \
		and app._stitched_party_picks == picks_before \
		and app._stitched_party_receipt == receipt_before \
		and labels.size() == 5 \
		and container.find_children("*", "CheckBox", true, false).is_empty() \
		and app._stitched_party_checkboxes.is_empty() \
		and not is_instance_valid(app._stitched_party_confirm_button) \
		and not is_instance_valid(app._stitched_party_cancel_button) \
		and choices.size() == 3 and not choices[0].disabled and not choices[2].disabled \
		and choices[0].focus_mode != Control.FOCUS_NONE \
		and choices[2].focus_mode != Control.FOCUS_NONE
	if locked_ok:
		for hero in party["heroes"]:
			var found := false
			for display in labels:
				if str(display.text) == "%d  %s" % [hero["rank"], hero["name"]]:
					found = true
			locked_ok = locked_ok and found
	_check(locked_ok,
		"the reopened Roadblock shows the locked unchanged four with no checkbox, Confirm or Cancel")
	if picker == null:
		app.free()
		await process_frame
		return
	# The Roadblock Leave is the real player exit back to the title.
	picker.get_choice_buttons()[2].pressed.emit()
	await process_frame
	_check(app.stitched_event_panel == null and app._stitched_party_locked \
		and app._stitched_party_picks == picks_before \
		and app._stitched_party_receipt == receipt_before \
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
		"the locked read-only Leave keeps the title Peddler openable and spends nothing")
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
		and quoted_ids == picks_before \
		and quoted_bleed == bleed_before,
		"the preserved Peddler still quotes the locked four and their carried Bleed")
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
		and app.stitched_roadblock_candle == maxi(0, candle_before - 8) \
		and _no_wallet(app),
		"the preserved Peddler's Leave retains all carry after the one entry toll")
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
		and app.stitched_roadblock_candle == maxi(0, candle_before - 8) \
		and _no_wallet(app),
		"short-wallet Leave incurs no further charge after the eight-candle entry")
	app.free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var one: Dictionary = await _trace()
	var two: Dictionary = await _trace()
	_check(not one.is_empty() and one == two,
		"two fresh identical Roadblock/Victory/Circle/Peddler/Fight traces replay exactly")
	await _reselection_trace()
	await _locked_roster_trace()
	await _unaffordable_trace()
	for failure in failures:
		printerr(failure)
	print("stitched_s6_peddler_bandage_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
