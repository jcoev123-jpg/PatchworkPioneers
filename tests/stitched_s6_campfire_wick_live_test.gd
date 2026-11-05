extends SceneTree
## Live S6: mounted legal Roadblock victory -> authenticated Circle Leave ->
## one shared Campfire/Peddler stop -> real Wick candle and mounted next Fight.
const NODE := "s6_stitched_roadblock_campfire"
var failures: Array[String] = []
var checks := 0

const MOUNT_SCRIPT := """extends "res://scripts/app.gd"
var fail_campfire_mount := false
var mount_attempts := 0
var mount_candle: Variant
var mount_state: Dictionary
func _mount_stitched_campfire_event(quote: Dictionary, generation: int) -> Dictionary:
	mount_attempts += 1
	mount_candle = stitched_roadblock_candle
	mount_state = quote["state"].duplicate(true)
	if fail_campfire_mount:
		return {}
	return super._mount_stitched_campfire_event(quote, generation)
func _mount_stitched_campfire(state: Dictionary, generation: int,
		swap_quote: Dictionary) -> Dictionary:
	mount_attempts += 1
	mount_candle = stitched_roadblock_candle
	mount_state = state.duplicate(true)
	if fail_campfire_mount:
		return {}
	return super._mount_stitched_campfire(state, generation, swap_quote)
"""


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures.append(note)


func _resources(app: Node) -> Dictionary:
	return {"hp": app._stitched_hp_carry.duplicate(true),
		"fray": app._stitched_fray_carry.duplicate(true),
		"ranks": app._stitched_rank_carry.duplicate(true),
		"party": app._stitched_party_receipt.duplicate(true),
		"candle": app.stitched_roadblock_candle,
		"gold": app.stitched_preview_gold,
		"bleed": app._stitched_bleed_carry.duplicate(true),
		"gear": app._stitched_gear_overrides.duplicate(true),
		"satchel": app.stitched_preview_satchel.duplicate(true),
		"scraps": app.stitched_preview_scraps,
		"legacy_gold": app.session_gold, "legacy_scraps": app.run_scraps}


func _no_legacy(app: Node) -> bool:
	return app.deck == null and app.run_map == null and app.run_rng == null \
		and app.session_gold == 0 and app.run_scraps == 0 and app.run_deck.is_empty()


func _admit(app: Node) -> StitchedBattleScreen:
	app.stitched_fight_button.pressed.emit()
	await process_frame
	var offer: LiveEventChoicePanel = app.stitched_event_panel
	if offer == null or not offer.has_open_event() or offer.get_choice_buttons().size() != 3:
		return null
	if offer.get_choice_buttons()[0].disabled:
		return null
	offer.get_choice_buttons()[0].pressed.emit()
	await process_frame
	return app.stitched_fight_view


## All foe kills come from the real mounted battle's legal part receipts.
func _victory(stage: StitchedBattleScreen) -> Dictionary:
	if stage == null or stage.battle == null or not stage.battle.is_valid():
		return {}
	var steps := 0
	var abilities := 0
	for turn in range(200):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		var actor: Dictionary = stage.battle.get_unit(stage.battle.current_actor_id())
		var best_score := -10000
		var best_part := ""
		var best_rank := 0
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
				var score := -20
				if str(legal[0]["side"]) == "foe":
					score = int(skill.get("dmg", [0, 0])[1]) * 4 \
						+ int(skill.get("dmg", [0, 0])[0])
				elif str(skill.get("kind", "")) == "heal":
					var ally: Dictionary = stage._unit_at("hero", rank)
					var missing := int(ally.get("max_hp", 0)) - int(ally.get("hp", 0))
					if missing >= 8:
						score = 38 + missing
				if score > best_score:
					best_score = score
					best_part = id
					best_rank = rank
		var result: Dictionary
		if best_part != "":
			result = stage.submit_part(best_part, best_rank)
			if result.get("ok") == true and result.get("action") == "ability":
				abilities += 1
		else:
			result = stage.submit_pass()
		if result.get("ok") != true:
			break
		steps += 1
	return {"outcome": stage.battle.outcome(), "steps": steps,
		"abilities": abilities, "rounds": stage.battle.round_number()}


func _prepare(winning_fight_candle: int = -1, spend_reward := false) -> Dictionary:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	var script := GDScript.new()
	script.source_code = MOUNT_SCRIPT
	_check(script.reload() == OK, "Campfire mount-failure subclass compiles")
	app.set_script(script)
	root.add_child(app)
	await process_frame
	_check(app.stitched_campfire_button != null \
		and not app.stitched_campfire_button.visible \
		and app.stitched_campfire_button.disabled \
		and app.stitched_campfire_button.focus_mode == Control.FOCUS_NONE \
		and not app._open_stitched_campfire() and app.stitched_campfire_visit == null \
		and not app._stitched_postvictory_stop_available and _no_legacy(app),
		"fresh title has no Campfire or earned visit")
	var aborted: StitchedBattleScreen = await _admit(app)
	_check(aborted != null and aborted.battle != null and aborted.battle.is_valid(),
		"unwon real Roadblock mounts")
	if aborted == null:
		return {"app": app}
	aborted._action_buttons["exit"].pressed.emit()
	await process_frame
	app._stitched_fight_exit(weakref(aborted))
	app._stitched_fight_exit(null)
	_check(not app._open_stitched_campfire() \
		and not app.stitched_campfire_button.visible \
		and not app.stitched_peddler_button.visible \
		and app.stitched_sewing_panel == null \
		and app._stitched_hp_carry.is_empty(),
		"unwon exit and replay mint no Campfire or Peddler")
	# Lower-candle witness models an earlier spent run, while every subsequent
	# admission, victory and stop is through the mounted app and service.
	if winning_fight_candle >= 0:
		app.stitched_roadblock_candle = winning_fight_candle
	if spend_reward:
		app.stitched_preview_scraps = 1
	var stage: StitchedBattleScreen = await _admit(app)
	var earned_battle: StitchedRules = stage.battle
	var won: Dictionary = _victory(stage)
	_check(won.get("outcome") == "victory" and won.get("steps", 0) > 0 \
		and won.get("abilities", 0) > 0 and stage.battle.get_foes().size() == 3,
		"three real foes defeated through legal mounted part actions")
	if won.get("outcome") != "victory":
		return {"app": app}
	var survivors: Array = []
	var wounded := 0
	var wounds: Dictionary = {}
	for hero in stage.battle.get_heroes():
		if bool(hero.get("lost", false)):
			continue
		survivors.append(hero.duplicate(true))
		wounds[str(hero["id"])] = int(hero["hp"])
		if int(hero["hp"]) < int(hero["max_hp"]):
			wounded += 1
	_check(survivors.size() == 4 and wounded > 0 and wounds.size() == 4,
		"real winning team includes four survivors and actual damaged HP")
	stage._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel != null and app.stitched_sewing_visit != null \
		and app._stitched_hp_carry == wounds and not app.stitched_campfire_button.visible \
		and not app._stitched_postvictory_stop_available,
		"victory alone opens Circle, but not Campfire")
	if app.stitched_sewing_panel == null:
		return {"app": app}
	var circle: Control = app.stitched_sewing_panel
	var state: Dictionary = app._stitched_sewing_quote["state"].duplicate(true)
	var forged := state.duplicate(true)
	forged["version"] = -1
	_check(app._stitched_sewing_leave(forged, weakref(circle)).get("ok") != true \
		and not app._open_stitched_campfire() \
		and app._stitched_hp_carry == wounds,
		"forged Circle Leave cannot mint a stop")
	if spend_reward:
		var upgrade: Button
		for button: Button in circle.find_children("Upgrade_*", "Button", true, false):
			if not button.disabled:
				upgrade = button
				break
		_check(upgrade != null and app.stitched_preview_scraps == 2,
			"poor witness has a real affordable Circle upgrade before Leave")
		if upgrade != null:
			upgrade.pressed.emit()
			await process_frame
		circle = app.stitched_sewing_panel
		_check(app.stitched_preview_scraps == 0, "real Circle purchase spends the available scraps")
	circle.get_node("SewingLeave").pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel == null \
		and app._stitched_postvictory_stop_available \
		and app.stitched_campfire_button.visible \
		and app.stitched_campfire_button.focus_mode == Control.FOCUS_ALL \
		and app.stitched_peddler_button.visible \
		and app.stitched_peddler_button.focus_mode == Control.FOCUS_ALL \
		and app.stitched_peddler_button.focus_next == app.stitched_peddler_button.get_path_to(
			app.stitched_campfire_button) and _no_legacy(app),
		"one authentic Circle Leave offers both keyboard-reachable exclusive visits")
	_check(not app._stitched_sewing_leave(state, weakref(circle)).get("ok") \
		and app._stitched_postvictory_stop_available,
		"stale Circle Leave cannot mint another stop")
	return {"app": app, "survivors": survivors, "wounds": wounds,
		"wounded": wounded, "battle": earned_battle}


func _admission_refusals(app: Node) -> void:
	var before := _resources(app)
	var roster: Array = app._stitched_campfire_roster.duplicate(true)
	var swap_roster: Array = app._stitched_campfire_swap_roster.duplicate(true)
	var generation: int = app._stitched_campfire_generation
	seed(53301)
	var expected_rng := randi()
	seed(53301)
	for invalid in [-1, 101, 8.0, "8", null, true]:
		app.stitched_roadblock_candle = invalid
		var invalid_before := _resources(app)
		_check(not app._open_stitched_campfire() and _resources(app) == invalid_before
			and app.mount_attempts == 0 and app._stitched_postvictory_stop_available,
			"invalid original candle rejects before projection or mounting: %s" % str(invalid))
	app.stitched_roadblock_candle = before["candle"]
	app._stitched_postvictory_stop_available = false
	_check(not app._open_stitched_campfire() and _resources(app) == before,
		"unearned admission cannot debit the candle")
	app._stitched_postvictory_stop_available = true
	app._stitched_campfire_roster[0]["hp"] -= 1
	_check(not app._open_stitched_campfire() and _resources(app) == before
		and app._stitched_postvictory_stop_available, "forged earned roster cannot spend")
	app._stitched_campfire_roster = roster.duplicate(true)
	var occupied := Control.new()
	app.add_child(occupied)
	app.stitched_campfire_panel = occupied
	_check(not app._open_stitched_campfire() and _resources(app) == before
		and app._stitched_postvictory_stop_available, "occupied panel cannot admit or spend")
	app.stitched_campfire_panel = null
	occupied.free()
	app.fail_campfire_mount = true
	_check(not app._open_stitched_campfire() and app.mount_attempts == 1
		and app.mount_candle == before["candle"]
		and app.mount_state["candle"] == maxi(0, int(before["candle"]) - 8)
		and _resources(app) == before and app.stitched_campfire_visit == null
		and app.stitched_campfire_panel == null and app._stitched_campfire_swap_visit == null
		and app._stitched_campfire_state.is_empty()
		and app._stitched_campfire_generation == generation
		and app._stitched_campfire_roster == roster
		and app._stitched_campfire_swap_roster == swap_roster
		and app._stitched_postvictory_stop_available and randi() == expected_rng,
		"exercised mount failure retains original candle, RNG, ticket, roster and unpublished services")
	app.fail_campfire_mount = false


func _wick(winning_fight_candle: int = -1, campfire_candle: int = -1) -> Dictionary:
	var setup: Dictionary = await _prepare(winning_fight_candle)
	var app: Node = setup["app"]
	if setup.get("survivors", []).size() != 4 or not app.stitched_campfire_button.visible:
		_check(false, "winning four-hero Circle Leave must earn Campfire")
		app.free()
		await process_frame
		return {}
	# A capped-at-100 fixture keeps the earned victory ticket and real roster;
	# the current authoritative run candle is projected into the service on open.
	if campfire_candle >= 0:
		app.stitched_roadblock_candle = campfire_candle
	_admission_refusals(app)
	var before: Dictionary = _resources(app)
	var roster: Array = app._stitched_campfire_roster.duplicate(true)
	_check(roster.size() == 4 and before["hp"].size() == 4
		and before["candle"] >= 0 and before["candle"] <= 100
		and before["hp"] == setup["wounds"],
		"non-vacuous real four-hero victory snapshot precedes Wick")
	if int(before["candle"]) >= 100:
		# An isolated service at 100 cannot offer Wick; actual entry below pays
		# eight first and therefore offers Wick to restore the missing eight.
		var full_visit := RunCampfireVisit.new(NODE, roster, RunCampfireVisit.STITCHED, 100)
		var full_state: Dictionary = full_visit.read_state()
		_check(full_state.get("quote", {}).get("choices", []).has(RunCampfireVisit.TRIM_THE_WICK) == false
			and full_state.get("quote", {}).get("choices", []).has(RunCampfireVisit.STITCHED_LEAVE)
			and full_visit.select(RunCampfireVisit.TRIM_THE_WICK, NODE, roster, 100).get("ok") == false
			and full_visit.read_state() == full_state,
			"full CANDLE service refuses unoffered Wick without closing")
	var entrance := before.duplicate(true)
	before["candle"] = maxi(0, int(before["candle"]) - 8)
	before["scraps"] -= 1
	app.stitched_campfire_button.pressed.emit()
	await process_frame
	var event_panel: Control = app.stitched_campfire_panel
	var paid: Button = event_panel.find_child("Emberglass_light_the_embers", true, false)
	_check(paid != null and not paid.disabled and app.stitched_campfire_visit == null,
		"earned Campfire first shows the affordable authored Emberglass Event")
	if paid != null:
		paid.pressed.emit()
	await process_frame
	_check(_resources(app) == before and not app._open_stitched_campfire()
		and _resources(app) == before,
		"Campfire Event entry debits eight and paid service one scrap from %s" % str(entrance["candle"]))
	var panel: Control = app.stitched_campfire_panel
	var visit: RunCampfireVisit = app.stitched_campfire_visit
	if panel == null or visit == null:
		_check(false, "earned Campfire must mount panel and real service")
		app.free()
		await process_frame
		return {}
	var expected: Dictionary = app._stitched_campfire_state.duplicate(true)
	_check(app.mount_candle == before["candle"]
		and app.mount_state == expected and expected["candle"] == before["candle"],
		"panel builder sees projected state while the original ledger is still unspent")
	var generation: int = app._stitched_campfire_generation
	var mend: Button = panel.find_child("CampfireMend", true, false)
	var wick: Button = panel.find_child("CampfireWick", true, false)
	var tales: Button = panel.find_child("CampfireTales", true, false)
	var leave: Button = panel.find_child("CampfireLeave", true, false)
	var label: Label = panel.find_child("CampfireCandle", true, false)
	var frame: NinePatchRect = panel.find_child("CampfireFrame", true, false)
	var gain: int = mini(50, 100 - int(before["candle"]))
	var restored: int = int(before["candle"]) + gain
	_check(frame != null and frame.texture != null
		and panel.theme == load("res://themes/gothic_theme.tres")
		and mend != null and wick != null and leave != null and label != null
		and mend.focus_mode == Control.FOCUS_ALL
		and wick.focus_mode == Control.FOCUS_ALL and leave.focus_mode == Control.FOCUS_ALL
		and not mend.disabled and not wick.disabled and not leave.disabled
		and mend.focus_next == mend.get_path_to(tales if tales != null else wick)
		and (tales == null or (tales.focus_previous == tales.get_path_to(mend)
			and tales.focus_next == tales.get_path_to(wick)))
		and wick.focus_previous == wick.get_path_to(tales if tales != null else mend)
		and wick.focus_next == wick.get_path_to(leave)
		and leave.focus_previous == leave.get_path_to(wick)
		and leave.focus_next == leave.get_path_to(mend)
		and wick.text.contains("+%d CANDLE" % gain)
		and label.text.begins_with("CANDLELIGHT  %d / 100" % int(before["candle"]))
		and label.text.contains("TRIM +%d" % gain)
		and label.text.contains("%d / 100" % restored)
		and expected == visit.read_state()
		and expected.get("node_id") == NODE
		and expected.get("heroes") == roster
		and expected.get("candle") == before["candle"]
		and expected.get("quote", {}).get("choices", []).has(RunCampfireVisit.TRIM_THE_WICK)
		and panel.is_visible_in_tree()and not app.title_view.is_visible_in_tree()
		and not app._stitched_postvictory_stop_available
		and not app.stitched_campfire_button.visible
		and not app.stitched_peddler_button.visible,
		"themed panel offers mouse and keyboard Wick, Mend and Leave; both stops consumed")
	var wrong_node := expected.duplicate(true)
	wrong_node["node_id"] = "forged"
	var wrong_roster := expected.duplicate(true)
	wrong_roster["heroes"][0]["fray"] += 1
	var wrong_candle := expected.duplicate(true)
	wrong_candle["candle"] = int(before["candle"]) - 1
	var wrong_quote := expected.duplicate(true)
	wrong_quote["quote"]["choices"].erase(RunCampfireVisit.TRIM_THE_WICK)
	seed(521049)
	var expected_rng := randi()
	seed(521049)
	var refusals := [
		app._stitched_campfire_choose(RunCampfireVisit.TRIM_THE_WICK, wrong_node, weakref(panel), generation),
		app._stitched_campfire_choose(RunCampfireVisit.TRIM_THE_WICK, wrong_roster, weakref(panel), generation),
		app._stitched_campfire_choose(RunCampfireVisit.TRIM_THE_WICK, wrong_candle, weakref(panel), generation),
		app._stitched_campfire_choose(RunCampfireVisit.TRIM_THE_WICK, wrong_quote, weakref(panel), generation),
		app._stitched_campfire_choose(RunCampfireVisit.TRIM_THE_WICK, expected, null, generation),
		app._stitched_campfire_choose(RunCampfireVisit.TRIM_THE_WICK, expected, weakref(panel), generation - 1),
		app._stitched_campfire_choose(RunCampfireVisit.TELL_TALES, wrong_quote, weakref(panel), generation),
		visit.select(RunCampfireVisit.TRIM_THE_WICK, "forged", roster, before["candle"]),
		visit.select(RunCampfireVisit.TRIM_THE_WICK, NODE, wrong_roster["heroes"], before["candle"]),
		visit.select(RunCampfireVisit.TRIM_THE_WICK, NODE, roster, -1),
	]
	var forged_panel := Control.new()
	app.add_child(forged_panel)
	refusals.append(app._stitched_campfire_choose(
		RunCampfireVisit.TRIM_THE_WICK, expected, weakref(forged_panel), generation))
	forged_panel.queue_free()
	panel.set_meta("campfire_generation", generation - 1)
	refusals.append(app._stitched_campfire_choose(
		RunCampfireVisit.TRIM_THE_WICK, expected, weakref(panel), generation))
	panel.set_meta("campfire_generation", generation)
	panel.hide()
	refusals.append(app._stitched_campfire_choose(
		RunCampfireVisit.TRIM_THE_WICK, expected, weakref(panel), generation))
	panel.show()
	app.stitched_roadblock_candle = int(before["candle"]) - 1
	refusals.append(app._stitched_campfire_choose(
		RunCampfireVisit.TRIM_THE_WICK, expected, weakref(panel), generation))
	app.stitched_roadblock_candle = before["candle"]
	var first_id := str(roster[0]["id"])
	app._stitched_hp_carry[first_id] = -1
	refusals.append(app._stitched_campfire_choose(
		RunCampfireVisit.TRIM_THE_WICK, expected, weakref(panel), generation))
	app._stitched_hp_carry[first_id] = before["hp"][first_id]
	var all_refused := true
	for receipt in refusals:
		all_refused = all_refused and receipt.get("ok") == false
	_check(all_refused and visit.read_state() == expected
		and _resources(app) == before and randi() == expected_rng,
		"wrong/stale panel, generation, node, quote, roster, candle, ledger and unoffered action fail closed without spend or RNG")
	var service_before: Dictionary = visit.read_state()
	wick.pressed.emit()
	var after: Dictionary = _resources(app)
	var only_candle := before.duplicate(true)
	only_candle["candle"] = restored
	_check(after == only_candle and restored == mini(100, int(before["candle"]) + 50)
		and app.stitched_roadblock_candle == restored
		and app.stitched_campfire_panel == null and app.stitched_campfire_visit == null
		and not app._open_stitched_campfire() and not app._open_stitched_peddler()
		and not app.stitched_campfire_button.visible and not app.stitched_peddler_button.visible
		and _no_legacy(app),
		"one authentic Wick changes only candle by capped amount and retires shared stop")
	_check(service_before.get("status") == RunCampfireVisit.STITCHED_OPEN
		and visit.read_state().get("status") == RunCampfireVisit.STITCHED_DECIDED
		and visit.read_state().get("candle") == restored
		and visit.read_state().get("heroes") == roster
		and not visit.select(RunCampfireVisit.TRIM_THE_WICK, NODE, roster, before["candle"]).get("ok")
		and not app._stitched_campfire_choose(
			RunCampfireVisit.TRIM_THE_WICK, expected, weakref(panel), generation).get("ok")
		and not app._stitched_campfire_choose(
			RunCampfireVisit.STITCHED_LEAVE, expected, weakref(panel), generation).get("ok")
		and not app._stitched_campfire_choose(
			RunCampfireVisit.MEND, expected, weakref(panel), generation).get("ok")
		and _resources(app) == after,
		"receipt is decided once; Wick replay and stale Leave callback cannot publish again")
	await process_frame
	var next: StitchedBattleScreen = await _admit(app)
	_check(next != null and next.battle != null and next.battle.is_valid()
		and next.is_visible_in_tree(),
		"actual next Fight is mounted from title through Roadblock")
	if next != null and next.battle != null:
		var fight_entrance := maxi(0, restored - 8)
		var next_hp := {}
		for hero in next.battle.get_heroes():
			next_hp[str(hero["id"])] = int(hero["hp"])
		_check(next.config.get("candle") == fight_entrance
			and next.battle.candle() == fight_entrance
			and next.battle.state_snapshot().get("candle") == fight_entrance
			and app.stitched_roadblock_candle == fight_entrance
			and next_hp == before["hp"]
			and app._stitched_bleed_carry == before["bleed"]
			and app._stitched_gear_overrides == before["gear"]
			and app.stitched_preview_gold == before["gold"]
			and app.stitched_preview_scraps == before["scraps"]
			and app.stitched_preview_satchel == before["satchel"]
			and _no_legacy(app),
			"next real battle rules/config use Wick-restored candle less ordinary 8 charge; all other state untouched")
		next._action_buttons["exit"].pressed.emit()
		await process_frame
		_check(not app._stitched_postvictory_stop_available
			and not app._open_stitched_campfire() and not app.stitched_campfire_button.visible,
			"unwon second exit does not mint a new stop")
	var trace := {"before": entrance["candle"], "charged": before["candle"], "restored": restored, "gain": gain}
	app.free()
	await process_frame
	return trace


func _leave_wick() -> void:
	var setup: Dictionary = await _prepare()
	var app: Node = setup["app"]
	if setup.get("survivors", []).size() != 4 or not app.stitched_campfire_button.visible:
		_check(false, "Leave witness requires a genuine earned Campfire")
		app.free()
		await process_frame
		return
	var before: Dictionary = _resources(app)
	var entrance := before.duplicate(true)
	before["candle"] = maxi(0, int(before["candle"]) - 8)
	before["scraps"] -= 1
	app.stitched_campfire_button.pressed.emit()
	await process_frame
	var event_panel: Control = app.stitched_campfire_panel
	var paid: Button = event_panel.find_child("Emberglass_light_the_embers", true, false)
	_check(paid != null and not paid.disabled and app.stitched_campfire_visit == null,
		"earned Campfire first shows the affordable authored Emberglass Event")
	if paid != null:
		paid.pressed.emit()
	await process_frame
	_check(_resources(app) == before and not app._open_stitched_campfire()
		and _resources(app) == before,
		"Campfire Event entry debits eight and paid service one scrap from %s" % str(entrance["candle"]))
	var panel: Control = app.stitched_campfire_panel
	var visit: RunCampfireVisit = app.stitched_campfire_visit
	_check(panel != null and visit != null, "Leave witness mounts the authenticated panel")
	if panel != null and visit != null:
		var expected: Dictionary = app._stitched_campfire_state.duplicate(true)
		var generation: int = app._stitched_campfire_generation
		var leave: Button = panel.find_child("CampfireLeave", true, false)
		_check(leave != null and not leave.disabled and leave.focus_mode == Control.FOCUS_ALL,
			"Leave is enabled beside Wick")
		if leave != null:
			leave.pressed.emit()
		_check(_resources(app) == before
			and visit.read_state().get("status") == RunCampfireVisit.STITCHED_DECIDED
			and visit.read_state().get("candle") == before["candle"]
			and not visit.select(RunCampfireVisit.TRIM_THE_WICK, NODE,
				expected["heroes"], expected["candle"]).get("ok")
			and not app._stitched_campfire_choose(RunCampfireVisit.TRIM_THE_WICK,
				expected, weakref(panel), generation).get("ok")
			and not app._open_stitched_campfire() and not app._open_stitched_peddler()
			and not app.stitched_campfire_button.visible and not app.stitched_peddler_button.visible,
			"Campfire Leave cannot raise candle, replay Wick or open another stop")
	app.free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var cap: Dictionary = await _wick()
	_check(not cap.is_empty() and cap.get("restored") == 100
		and cap.get("gain", -1) > 0 and cap.get("gain", 100) < 50,
		"capped witness restores only room remaining up to 100")
	var noncap: Dictionary = await _wick(56)
	_check(not noncap.is_empty() and noncap.get("gain") == 50
		and noncap.get("restored", 100) < 100,
		"noncapped witness restores exactly 50 without reaching ceiling")
	var already_full: Dictionary = await _wick(-1, 100)
	_check(not already_full.is_empty() and already_full.get("before") == 100
		and already_full.get("restored") == 100 and already_full.get("charged") == 92 and already_full.get("gain") == 8,
		"100-point entered node pays eight then offers Wick +8 back to cap")
	for boundary in [8, 0]:
		var low: Dictionary = await _wick(-1, boundary)
		_check(not low.is_empty() and low.get("before") == boundary
			and low.get("charged") == 0 and low.get("restored") == 50,
			"low/zero entry floors at zero and Wick restores exactly fifty")
	await _leave_wick()
	for failure in failures:
		printerr(failure)
	print("stitched_s6_campfire_wick_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
