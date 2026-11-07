extends SceneTree
## Design v4 S12: Wren's gifts. Covers the catalog and its unlock tiers, the battle's gift slots
## (one to four, known, unique), every gift's effect and refusals, once-per-fight gifts, the
## seeded 1-of-3 offer after a finished Event, taking and swapping a gift, save replay
## (including a pre-S12 save), the between-runs profile and the app's pick picture.

const FIXTURE := "res://tests/fixtures/stitched_s1a_parts.json"
const PROFILE := "user://s12_wren_gifts_profile_test.json"
const SAVE := "user://s12_wren_gifts_save_test.json"

var checks := 0
var failures: Array[String] = []


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_catalog()
	_slots_config()
	_foe_gifts()
	_doll_gifts()
	_board_gifts()
	_once_per_fight()
	_profile()
	await _session_offer_and_app()
	await _corridor_targets()
	if failures.is_empty():
		print("stitched_s12_wren_gifts_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		print("stitched_s12_wren_gifts_test: FAIL (%d failures)" % failures.size())
		quit(1)


func _ability(id: String, kind: String) -> Dictionary:
	return {
		"id": id, "name": id, "kind": kind, "launch": [1, 2, 3, 4],
		"target": [1, 2, 3, 4], "target_side": "enemy", "acc": 100,
		"dmg": [1, 1], "crit": 0, "effects": {}, "move": "attack",
	}


func _hero(id: String, speed: int, head: String, arms: String, torso: String, legs: String) -> Dictionary:
	return {
		"id": id, "name": id.capitalize(), "max_hp": 40, "speed": speed,
		"dodge": 0, "acc": 0, "prot": 0,
		"parts": {"head": head, "arms": arms, "torso": torso, "legs": legs},
	}


func _config(gifts: Variant, light: int = 100) -> Dictionary:
	var catalog := StitchedParts.load_catalog(FIXTURE)
	var heroes := [
		_hero("warden", 8, "any_head_needle_pin", "warden_arm_shield_bash", "warden_torso_quilt", "warden_legs_stride"),
		_hero("seamstress", 7, "warden_head_button_eye", "warden_arm_brace", "warden_torso_rivet", "any_legs_stitch_step"),
		_hero("tinker", 6, "any_head_needle_pin", "any_arm_red_thread", "warden_torso_rivet", "warden_legs_stride"),
		_hero("monk", 5, "warden_head_button_eye", "warden_arm_brace", "any_torso_felt_coat", "any_legs_stitch_step"),
	]
	var foes: Array = []
	for i in range(3):
		foes.append({
			"id": "foe_%d" % i, "name": "Foe %d" % i, "max_hp": 30,
			"speed": i + 1, "dodge": 0, "acc": 0, "prot": 0,
			"abilities": [_ability("foe_hit", "melee")],
		})
	var config := {"seed": 21, "parts": catalog["parts"], "heroes": heroes, "foes": foes, "candle": light}
	if gifts != null:
		config["gifts"] = gifts
	return config


## A battle carrying the given gifts, stopped on the first doll turn.
func _battle(gifts: Array, light: int = 100) -> StitchedRules:
	var built := StitchedRules.create(_config(gifts, light))
	_check(bool(built["ok"]), "gift battle builds %s: %s" % [gifts, built.get("error", "")])
	if not built["ok"]:
		return null
	var battle: StitchedRules = built["battle"]
	_check(_to_side(battle, "hero"), "gift battle reaches a doll turn")
	return battle


func _to_side(battle: StitchedRules, side: String) -> bool:
	for step in range(60):
		if battle.is_over():
			return false
		if battle.current_side() == side:
			return true
		battle.pass_turn()
	return false


func _next_round(battle: StitchedRules) -> void:
	var round_now := battle.round_number()
	for step in range(60):
		if battle.round_number() != round_now or battle.is_over():
			break
		battle.pass_turn()
	_to_side(battle, "hero")


func _foe_at(battle: StitchedRules, rank: int) -> Dictionary:
	for unit in battle.get_foes():
		if int(unit.rank) == rank and int(unit.hp) > 0:
			return unit
	return {}


func _catalog() -> void:
	var book := StitchedWrenGifts.catalog()
	_check(bool(book.get("ok", false)), "the gift catalog loads: " + str(book.get("error", "")))
	var gifts := 0
	for id in book.get("order", []):
		if not bool(book.by_id[id].basic):
			gifts += 1
	_check(gifts >= 16 and gifts <= 24, "16 to 24 gifts beyond the basics (%d)" % gifts)
	_check(StitchedWrenGifts.basics() == StitchedKidHandActions.IDS, "a run starts with the four basic hands")
	var opening := StitchedWrenGifts.pool_for({})
	_check(opening.size() == 10 and not "point" in opening and not "whisper" in opening, "a first run offers the start gifts only")
	var floor4 := StitchedWrenGifts.pool_for({"best_floor": 4})
	_check("point" in floor4 and "lullaby" in floor4 and not "tip_over" in floor4, "reaching floor 4 opens its gifts")
	var floor8 := StitchedWrenGifts.pool_for({"best_floor": 8})
	_check("tip_over" in floor8 and "quick_stitch" in floor8 and not "nightlight" in floor8, "reaching floor 8 opens its gifts")
	var boss := StitchedWrenGifts.pool_for({"best_floor": 12, "boss_wins": 1})
	_check("whisper" in boss and "nightlight" in boss and boss.size() == gifts, "beating the boss opens every gift")
	_check(StitchedWrenGifts.valid_pool(opening) and not StitchedWrenGifts.valid_pool(["steady"])
		and not StitchedWrenGifts.valid_pool(["tug", "tug"]) and not StitchedWrenGifts.valid_pool(["nope"]),
		"a pool holds known, non-basic, unique gifts")
	var first := StitchedWrenGifts.draw_offer(42, 0, boss, StitchedWrenGifts.basics(), false)
	_check(first.size() == 3 and first == StitchedWrenGifts.draw_offer(42, 0, boss, StitchedWrenGifts.basics(), false),
		"an offer is three gifts, the same for the same seed and index")
	var unique := {}
	for id in first:
		unique[id] = true
	_check(unique.size() == 3 and not "steady" in first, "an offer never repeats or offers a carried gift")
	var differs := false
	for index in range(1, 6):
		differs = differs or StitchedWrenGifts.draw_offer(42, index, boss, StitchedWrenGifts.basics(), false) != first
	_check(differs, "later offers draw different gifts")
	_check(StitchedWrenGifts.draw_offer(7, 0, ["tug", "hug"], ["tug"], true) == ["hug"], "a nearly empty pool offers what is left")


func _slots_config() -> void:
	_check(bool(StitchedRules.create(_config(null)).ok), "a battle without gifts keeps the basics")
	_check(StitchedRules.create(_config(null)).battle.gift_slots() == StitchedKidHandActions.IDS, "the default slots are the basics")
	_check(not bool(StitchedRules.create(_config([])).ok), "Wren carries at least one gift")
	_check(not bool(StitchedRules.create(_config(["steady", "lift", "hug", "tug", "shove"])).ok), "Wren carries at most four gifts")
	_check(not bool(StitchedRules.create(_config(["steady", "steady"])).ok), "a gift is not carried twice")
	_check(not bool(StitchedRules.create(_config(["steady", "made_up"])).ok), "an unknown gift is refused")
	var battle := _battle(["steady", "tug"])
	if battle == null:
		return
	_check(not bool(battle.use_hand_action("hug", "warden", 0).ok), "a gift not in the slots cannot be used")
	_check(battle.hand_action_check("tug", "warden", 0) != "", "a foe gift refuses a doll")
	_check(battle.hand_action_check("steady", "foe_0", 0) != "", "a doll gift refuses a foe")
	_check(battle.hand_action_check("tug", str(_foe_at(battle, 3).get("id", "")), 1) != "", "only Lift takes a direction")
	_check(battle.state_snapshot().hand.gifts == ["steady", "tug"], "the snapshot carries the slots")


func _foe_gifts() -> void:
	var battle := _battle(["flick_button", "snip_string", "shove", "tug"])
	if battle == null:
		return
	var front := _foe_at(battle, 1)
	var hp := int(front.hp)
	var receipt := battle.use_hand_action("flick_button", str(front.id), 0)
	_check(bool(receipt.ok) and int(battle.get_unit(str(front.id)).hp) == hp - 4, "Flick a Button hurts one foe")
	_check(not battle.hand_action_open(), "a gift spends the round's one free hand")
	_next_round(battle)
	receipt = battle.use_hand_action("snip_string", str(front.id), 0)
	_check(bool(receipt.ok) and int(battle.get_unit(str(front.id)).statuses.get("stun", 0)) > 0, "Snip a String stuns a foe")
	_next_round(battle)
	var back := _foe_at(battle, 3)
	_check(not bool(battle.use_hand_action("tug", str(_foe_at(battle, 1).get("id", "")), 0).ok), "a front foe cannot be tugged further")
	receipt = battle.use_hand_action("shove", str(back.id), 0)
	_check(bool(receipt.ok) and int(battle.get_unit(str(back.id)).rank) == 4, "Shove pushes a foe into the empty back rank")
	_next_round(battle)
	receipt = battle.use_hand_action("tug", str(back.id), 0)
	_check(bool(receipt.ok) and int(battle.get_unit(str(back.id)).rank) == 3, "Tug pulls a foe forward into the empty rank")
	_next_round(battle)
	var middle := _foe_at(battle, 2)
	receipt = battle.use_hand_action("tug", str(back.id), 0)
	_check(bool(receipt.ok) and int(battle.get_unit(str(back.id)).rank) == 2
		and int(battle.get_unit(str(middle.id)).rank) == 3, "Tug trades places with the foe in the way")
	var statuses := _battle(["pinch", "point", "tangle_thread", "tip_over"])
	if statuses == null:
		return
	var foe := _foe_at(statuses, 1)
	_check(bool(statuses.use_hand_action("pinch", str(foe.id), 0).ok)
		and int(statuses.get_unit(str(foe.id)).statuses.get("weak", 0)) > 0, "Pinch weakens a foe")
	_next_round(statuses)
	_check(bool(statuses.use_hand_action("point", str(foe.id), 0).ok)
		and int(statuses.get_unit(str(foe.id)).statuses.get("exposed", 0)) > 0, "Point exposes a foe")
	_next_round(statuses)
	_check(bool(statuses.use_hand_action("tangle_thread", str(foe.id), 0).ok)
		and int(statuses.get_unit(str(foe.id)).statuses.get("tangled", 0)) > 0, "Tangle the Thread tangles a foe")
	_next_round(statuses)
	var last := _foe_at(statuses, 3)
	_check(bool(statuses.use_hand_action("tip_over", str(last.id), 0).ok)
		and int(statuses.get_unit(str(last.id)).statuses.get("stun", 0)) > 0
		and int(statuses.get_unit(str(last.id)).rank) == 4, "Tip Over stuns a foe and knocks it back")


func _doll_gifts() -> void:
	var battle := _battle(["hug", "cover_eyes", "brush_off", "knot"])
	if battle == null:
		return
	battle._units["monk"]["hp"] = 20
	_check(battle.hand_action_check("hug", "warden", 0) != "", "a whole doll needs no hug")
	_check(bool(battle.use_hand_action("hug", "monk", 0).ok) and int(battle.get_unit("monk").hp) == 26, "Hug mends a hurt doll")
	_next_round(battle)
	_check(bool(battle.use_hand_action("cover_eyes", "tinker", 0).ok) and battle.eyes_covered("tinker"), "Cover Its Eyes covers a doll")
	_check(int(battle.apply_fray_event("tinker", 10, "event").change) == 0, "a doll with covered eyes takes no fray")
	_check(int(battle.apply_fray_event("warden", 10, "event").change) > 0, "the other dolls still fray")
	_next_round(battle)
	_check(not battle.eyes_covered("tinker"), "covered eyes last one round")
	_check(battle.hand_action_check("brush_off", "warden", 0) != "", "nothing to brush off a clean doll")
	battle._units["warden"]["statuses"]["bleed"] = 3
	battle._units["warden"]["statuses"]["weak"] = 3
	_check(bool(battle.use_hand_action("brush_off", "warden", 0).ok)
		and int(battle.get_unit("warden").statuses.get("bleed", 0)) == 0
		and int(battle.get_unit("warden").statuses.get("weak", 0)) == 0, "Brush Off wipes bleed and weakness away")
	_next_round(battle)
	_check(battle.hand_action_check("knot", "seamstress", 0) != "", "a whole string needs no knot")
	battle._thread_cuts["seamstress"] = true
	_check(bool(battle.use_hand_action("knot", "seamstress", 0).ok) and not battle._thread_cuts.has("seamstress"),
		"Knot ties a snipped string back")
	var mend := _battle(["quick_stitch", "whisper", "lullaby", "steady"])
	if mend == null:
		return
	_check(mend.hand_action_check("quick_stitch", "warden", 0) != "", "an untorn doll needs no quick stitch")
	mend._units["warden"]["parts"]["head"]["torn"] = true
	_check(bool(mend.use_hand_action("quick_stitch", "warden", 0).ok)
		and not bool(mend._units["warden"]["parts"]["head"].get("torn", false)), "Quick Stitch mends a torn part")
	_next_round(mend)
	var whisper_to := "monk" if mend.current_actor_id() != "monk" else "tinker"
	_check(bool(mend.use_hand_action("whisper", whisper_to, 0).ok)
		and mend._order[mend._turn_index + 1] == whisper_to, "Whisper gives a doll the very next turn")
	_next_round(mend)
	for id in ["warden", "seamstress", "tinker", "monk"]:
		mend.apply_fray_event(id, 20, "event")
	var before: Dictionary = {}
	for hero in mend.get_heroes():
		before[hero.id] = int(hero.fray)
	_check(bool(mend.use_hand_action("lullaby", "", 0).ok), "Lullaby takes no doll")
	var calmed := true
	for hero in mend.get_heroes():
		calmed = calmed and int(hero.fray) == maxi(0, int(before[hero.id]) - 6)
	_check(calmed, "Lullaby eases every doll's fray")


func _board_gifts() -> void:
	var dim := _battle(["blow_candle", "nightlight", "steady", "lift"], 50)
	if dim == null:
		return
	_check(dim.hand_action_check("blow_candle", "warden", 0) != "", "Blow on the Wick takes no doll")
	var receipt := dim.use_hand_action("blow_candle", "", 0)
	_check(bool(receipt.ok) and dim.candle() == 60, "Blow on the Wick brightens the candle")
	_check(_battle(["blow_candle"], 100).hand_action_check("blow_candle", "", 0) != "", "a full candle cannot burn brighter")
	_next_round(dim)
	_check(bool(dim.use_hand_action("nightlight", "", 0).ok) and dim.candle_shielded(), "the Nightlight shields the candle")
	_next_round(dim)
	_next_round(dim)
	_check(dim.candle_shielded(), "the Nightlight stays on for the whole fight")


func _once_per_fight() -> void:
	var battle := _battle(["snip_string", "tug"])
	if battle == null:
		return
	var foe := _foe_at(battle, 2)
	_check(bool(battle.use_hand_action("snip_string", str(foe.id), 0).ok) and battle.gift_spent("snip_string"),
		"a once-a-fight gift is spent after use")
	_next_round(battle)
	_next_round(battle)
	var other := _foe_at(battle, 1)
	_check("spent" in battle.hand_action_check("snip_string", str(other.id), 0), "a spent gift rests for the rest of the fight")
	_check(not battle.gift_spent("tug") and battle.hand_action_check("tug", str(_foe_at(battle, 3).id), 0) != "spent",
		"the other gifts still work")
	_check(battle.state_snapshot().hand.spent == ["snip_string"], "the snapshot records the spent gift")


func _profile() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	_check(StitchedWrenGifts.load_profile(PROFILE).best_floor == 0, "a missing profile starts empty")
	var opened := StitchedWrenGifts.record_progress(4, false, PROFILE)
	_check(opened.has("point") and opened.has("lullaby") and not opened.has("tip_over"), "a run to floor 4 opens its gifts")
	_check(StitchedWrenGifts.record_progress(3, false, PROFILE).is_empty(), "a shorter run opens nothing")
	opened = StitchedWrenGifts.record_progress(12, true, PROFILE)
	_check(opened.has("tip_over") and opened.has("nightlight") and opened.has("whisper"), "beating the boss opens the rest")
	_check(StitchedWrenGifts.pool_for(StitchedWrenGifts.load_profile(PROFILE)).size()
		== StitchedWrenGifts.pool_for({"best_floor": 12, "boss_wins": 1}).size(), "the profile file keeps the progress")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))


## A run on the map with a genuine gift offer, reached by finishing a first-floor Event.
func _event_offer_session() -> StitchedRunSession:
	for seed_number in range(1, 80):
		var session := StitchedRunSession.start(seed_number)
		if session == null:
			continue
		var event := ""
		for id in session.choices():
			if session.map.get_node(id).type == "Event":
				event = id
				break
		if event.is_empty() or not session.enter(event, session.snapshot()):
			continue
		for step in range(8):
			if session.phase != "visit":
				break
			var pick: Dictionary = {}
			for action in session.visit_actions():
				if action.enabled:
					pick = action
					break
			if pick.is_empty() or not session.choose_visit(pick.id, pick.arguments, session.snapshot()):
				break
		if session.phase == "map" and not session.gift_offer.is_empty():
			return session
	return null


func _session_offer_and_app() -> void:
	var fresh := StitchedRunSession.start(5)
	_check(fresh.gift_slots == StitchedWrenGifts.basics() and fresh.gift_offer.is_empty(), "a new run carries the basics, no offer")
	_check(not fresh.set_gift_pool(["steady"]) and fresh.set_gift_pool(["tug", "hug"]) and fresh.gift_pool == ["tug", "hug"],
		"the app may set a valid pool before the first step")
	var session := _event_offer_session()
	_check(session != null, "a finished Event offers gifts")
	if session == null:
		return
	_check(session.gift_offer.size() == 3 and session.gift_offers_made == 1, "the offer holds three gifts")
	_check(not session.set_gift_pool(["tug"]), "the pool is fixed once the run has stepped")
	var twin := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(twin != null and twin.gift_offer == session.gift_offer, "the offer survives a save")
	var offered: String = session.gift_offer[0]
	_check(not session.choose_gift(offered, "", session.snapshot()), "with four slots full a gift must swap one out")
	_check(not session.choose_gift("steady", "lift", session.snapshot()), "only an offered gift can be taken")
	_check(not session.choose_gift(offered, "hug", session.snapshot()), "only a carried gift can be let go")
	var journal_size := session.journal.size()
	_check(session.choose_gift(offered, "hold_back", session.snapshot()), "an offered gift swaps out a basic")
	_check(session.gift_slots == ["steady", "shield_candle", offered, "lift"] and session.gift_offer.is_empty()
		and session.journal.size() == journal_size + 1 and session.is_consistent(), "the swap keeps the slot and is journaled")
	var restored := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(restored != null and restored.snapshot() == session.snapshot(), "a run with a gift saves and replays exactly")
	var fight := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Fight":
			fight = id
			break
	if not fight.is_empty() and session.enter(fight, session.snapshot()) and session.battle != null:
		_check(session.battle.gift_slots() == session.gift_slots, "the next fight carries the new gift")
	# A pre-S12 save has no gifts: it keeps the basics and is never offered more.
	var old := StitchedRunSession.start(9)
	var legacy := StitchedRunSave.capture(old)
	legacy.state.erase("gifts")
	legacy.digest = StitchedRunSave._digest(legacy)
	var reloaded := StitchedRunSave.restore(legacy)
	_check(reloaded != null and reloaded.gift_pool.is_empty() and reloaded.gift_slots == StitchedWrenGifts.basics(),
		"a pre-S12 save restores with the basics and no pool")
	var offer_run := _event_offer_session()
	await _app_pick(offer_run, true)
	await _app_pick(_event_offer_session(), false)


func _app_pick(session: StitchedRunSession, take: bool) -> void:
	if session == null:
		return
	_check(StitchedRunSave.write_file(SAVE, session), "the offer run saves to disk")
	root.size = Vector2i(1280, 720)
	var app: Node = load("res://scenes/app.tscn").instantiate()
	app.wren_gifts_profile_path = PROFILE
	root.add_child(app)
	await process_frame
	_check(app.load_stitched_run(SAVE), "the app reloads the offer run")
	await process_frame
	var live: StitchedRunSession = app.stitched_run_session
	var pick: Control = app.stitched_run_panel.find_child("WrenGiftPick", true, false) if is_instance_valid(app.stitched_run_panel) else null
	_check(pick != null, "the map shows the gift pick over the route")
	if pick == null:
		app.free()
		return
	var cards := pick.find_child("WrenGiftCards", true, false)
	_check(cards != null and cards.get_child_count() == 3, "the pick shows three gifts")
	for card in cards.get_children():
		var hand := card.find_child("WrenGiftHand", true, false) as TextureRect
		_check(hand != null and hand.texture != null, "each gift shows its hand picture")
		for label in card.find_children("*", "Label", true, false):
			_check(not (label as Label).text.is_valid_float(), "a gift card shows no numbers")
	var offered: String = live.gift_offer[0]
	if take:
		(cards.get_child(0).find_child("WrenGiftTake", true, false) as Button).pressed.emit()
		await process_frame
		pick = app.stitched_run_panel.find_child("WrenGiftPick", true, false)
		cards = pick.find_child("WrenGiftCards", true, false) if pick != null else null
		_check(cards != null and cards.get_child_count() == 4 and live.gift_offer.size() == 3,
			"with full hands the pick asks which gift to let go")
		if cards != null:
			(cards.get_child(1).find_child("WrenGiftTake", true, false) as Button).pressed.emit()
			await process_frame
		_check(live.gift_slots[1] == offered and live.gift_offer.is_empty(), "the chosen gift takes the let-go slot")
	else:
		(pick.find_child("WrenGiftLeave", true, false) as Button).pressed.emit()
		await process_frame
		_check(live.gift_slots == StitchedWrenGifts.basics() and live.gift_offer.is_empty(), "Leave them keeps Wren's hands")
	_check(app.stitched_run_panel.find_child("WrenGiftPick", true, false) == null, "the pick closes after a choice")
	_check(not app.stitched_run_buttons.is_empty() and live.phase == "map", "the route is ready again")
	app.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))


## A foe gift in the corridor fight lights foes to pick; a doll gift lights dolls.
func _corridor_targets() -> void:
	var config: Dictionary = StitchedBattleScreen.read_preview()
	config["gifts"] = ["tug", "flick_button", "steady", "nightlight"]
	var screen := StitchedBattleScreen.new()
	screen.begin(config)
	root.add_child(screen)
	await process_frame
	var fight := StitchedCorridorFight.attach(screen, "walls")
	for step in range(20):
		if screen.battle.current_side() == "hero":
			break
		screen.battle.pass_turn()
		fight.refresh()
	_check(bool(screen.choose_hand_action("tug").get("ok", false)), "corridor: Tug waits for a foe")
	fight.refresh()
	var lit: Array = screen.legal_targets().keys()
	_check(not lit.is_empty() and lit.all(func(key): return str(key).begins_with("foe_")), "corridor: Tug lights foes only")
	screen.choose_hand_action("tug")
	_check(bool(screen.choose_hand_action("steady").get("ok", false)), "corridor: Steady waits for a doll")
	fight.refresh()
	lit = screen.legal_targets().keys()
	_check(not lit.is_empty() and lit.all(func(key): return str(key).begins_with("hero_")), "corridor: Steady lights dolls only")
	screen.queue_free()
	await process_frame
