extends SceneTree
## S6: authentically earned Roadblock scraps purchase one quoted, live tier upgrade.
const NODE := "s5_scissor_crab_sewing_circle"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _no_wallet(app: Node) -> bool:
	return app.deck == null and app.run_map == null and app.run_rng == null \
		and app.session_gold == 0 and app.run_scraps == 0 and app.run_deck.is_empty()


func _admit(app: Node) -> StitchedBattleScreen:
	app.stitched_fight_button.pressed.emit()
	await process_frame
	var offer: LiveEventChoicePanel = app.stitched_event_panel
	if offer == null or not offer.has_open_event() or offer.get_choice_buttons().size() != 3:
		return null
	offer.get_choice_buttons()[0].pressed.emit()
	await process_frame
	return app.stitched_fight_view


func _victory(stage: StitchedBattleScreen) -> Dictionary:
	if stage == null or stage.battle == null or not stage.battle.is_valid():
		return {}
	var steps := 0
	var abilities := 0
	for iteration in range(90):
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
					if str(skill.get("kind", "")) == "ranged":
						score += 1
					if rank == 1:
						score += 3
				elif str(skill.get("kind", "")) == "heal":
					var ally: Dictionary = stage._unit_at("hero", rank)
					var missing: int = int(ally.get("max_hp", 0)) - int(ally.get("hp", 0))
					if missing >= 8:
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
		"foes": stage.battle.get_foes().duplicate(true)}


func _find(quote: Dictionary, hero_id: String, slot: String) -> Dictionary:
	for hero in quote.get("heroes", []):
		if str(hero["hero_id"]) != hero_id:
			continue
		for row in hero["slots"]:
			if str(row["slot"]) == slot:
				return row
	return {}


func _finish(app: Node) -> void:
	if is_instance_valid(app):
		app.free()
	await process_frame
	for message in failures:
		printerr(message)
	print("stitched_s6_sewing_upgrade_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	_check(app.stitched_preview_scraps == 0 and app.stitched_preview_satchel.is_empty()
		and app.stitched_sewing_upgrade_visit == null and _no_wallet(app),
		"title starts without earned scraps or a purchasable upgrade")
	var unfinished: StitchedBattleScreen = await _admit(app)
	_check(unfinished != null and unfinished.battle != null and unfinished.battle.is_valid(),
		"authenticated title Fight is actually admitted")
	if unfinished == null:
		await _finish(app)
		return
	unfinished._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_preview_scraps == 0 and app.stitched_sewing_panel == null
		and app.stitched_sewing_upgrade_visit == null and _no_wallet(app),
		"unwon Fight creates neither a Circle nor upgrade currency")
	var first: StitchedBattleScreen = await _admit(app)
	if first == null:
		_check(false, "first legitimate earning Fight mounts")
		await _finish(app)
		return
	var win_one := _victory(first)
	_check(win_one.get("outcome") == "victory" and int(win_one.get("steps", 0)) > 0
		and int(win_one.get("abilities", 0)) > 0 and win_one.get("foes", []).size() == 3,
		"first scrap is earned by actual hero abilities and defeated Roadblock foes")
	if win_one.get("outcome") != "victory":
		await _finish(app)
		return
	# A torn witness is set in the real battle roster, as in the accepted Mend
	# live regression. No wallet or victory receipt is fabricated.
	var torn_id := ""
	for hero in first.battle.get_heroes():
		if not bool(hero.get("lost", false)):
			torn_id = str(hero["id"])
			first.battle._units[torn_id]["parts"]["arms"]["torn"] = true
			break
	_check(not torn_id.is_empty(), "real winning roster has a worn arms witness")
	first._action_buttons["exit"].pressed.emit()
	await process_frame
	var panel: Control = app.stitched_sewing_panel
	var upgrade: RunStitchedSewingUpgrade = app.stitched_sewing_upgrade_visit
	if panel == null or upgrade == null:
		_check(false, "first authentic win mounts the live Circle upgrade service")
		await _finish(app)
		return
	var one: Dictionary = upgrade.read_state()
	var poor: Button = panel.find_child("Upgrade_%s_head" % torn_id, true, false) as Button
	var torn: Button = panel.find_child("Upgrade_%s_arms" % torn_id, true, false) as Button
	_check(one.get("ok") == true and one.get("open") == true
		and one.get("scraps") == 1 and one.get("upgrade_cost") == 2
		and poor != null and poor.disabled and poor.focus_mode == Control.FOCUS_NONE
		and poor.text.contains("insufficient scraps")
		and torn != null and torn.disabled and torn.focus_mode == Control.FOCUS_NONE
		and torn.text.contains("torn") and _no_wallet(app),
		"one win shows disabled poor and torn upgrades with explicit reasons")
	seed(539101)
	var poor_rng := randi()
	seed(539101)
	_check(not app._stitched_sewing_upgrade(torn_id, "head", one, weakref(panel)).get("ok")
		and not upgrade.upgrade(torn_id, "head", "wrong-node", one).get("ok")
		and upgrade.read_state() == one and app.stitched_preview_scraps == 1
		and randi() == poor_rng and _no_wallet(app),
		"no unwon/free spending, wrong-node requests and RNG remain inert")
	panel.get_node("SewingLeave").pressed.emit()
	await process_frame
	_check(app.stitched_sewing_upgrade_visit == null and not upgrade.read_state()["open"]
		and app.stitched_preview_scraps == 1 and _no_wallet(app),
		"first free Leave retires upgrade authority but saves the earned scrap")
	var second: StitchedBattleScreen = await _admit(app)
	if second == null:
		_check(false, "second authentic earning Fight mounts")
		await _finish(app)
		return
	var win_two := _victory(second)
	_check(win_two.get("outcome") == "victory" and int(win_two.get("abilities", 0)) > 0
		and int(win_two.get("steps", 0)) > 0 and win_two.get("foes", []).size() == 3,
		"second scrap requires a second true battle with abilities and dead foes")
	if win_two.get("outcome") != "victory":
		await _finish(app)
		return
	second._action_buttons["exit"].pressed.emit()
	await process_frame
	panel = app.stitched_sewing_panel
	upgrade = app.stitched_sewing_upgrade_visit
	if panel == null or upgrade == null or app.stitched_sewing_visit == null \
			or app.stitched_sewing_mend_visit == null:
		_check(false, "two real victories mount three synchronized visits")
		await _finish(app)
		return
	var before: Dictionary = upgrade.read_state()
	var quote: Dictionary = upgrade.quote()
	var swap_old: RunStitchedSewingSwap = app.stitched_sewing_visit
	var mend_old: RunStitchedSewingMend = app.stitched_sewing_mend_visit
	var satchel_before: Array = app.stitched_preview_satchel.duplicate(true)
	var hp_before: Dictionary = app._stitched_hp_carry.duplicate(true)
	var bleed_before: Dictionary = app._stitched_bleed_carry.duplicate(true)
	var candle_before: int = app.stitched_roadblock_candle
	var gold_before: int = app.stitched_preview_gold
	var gear_before: Dictionary = app._stitched_gear_overrides.duplicate(true)
	var hero_id := ""
	var slot := ""
	var offer: Dictionary = {}
	# Prefer a real attack on an intact head, otherwise any live quoted slot.
	for row in quote.get("heroes", []):
		var head := _find(quote, str(row["hero_id"]), "head")
		if bool(head.get("can_upgrade", false)):
			hero_id = str(row["hero_id"])
			slot = "head"
			offer = head
			break
	if offer.is_empty():
		for row in quote.get("heroes", []):
			for candidate in row["slots"]:
				if bool(candidate["can_upgrade"]):
					hero_id = str(row["hero_id"])
					slot = str(candidate["slot"])
					offer = candidate
					break
			if not offer.is_empty():
				break
	_check(not offer.is_empty() and before.get("scraps") == 2
		and before.get("upgrade_cost") == 2 and quote.get("state") == before
		and before.get("heroes") == swap_old.read_state().get("heroes")
		and before.get("heroes") == mend_old.read_state().get("heroes"),
		"two real wins yield a compatible quoted part at exactly two scraps")
	if offer.is_empty():
		await _finish(app)
		return
	var part_id := str(offer["worn"]["id"])
	var tier := int(offer["current_tier"])
	var entry: Dictionary = app._stitched_sewing_catalog.get(part_id, {})
	var button: Button = panel.find_child("Upgrade_%s_%s" % [hero_id, slot], true, false) as Button
	var effects: Label = panel.find_child("UpgradeEffects_%s_%s" % [hero_id, slot], true, false) as Label
	_check(not entry.is_empty() and tier >= 1 and tier < 3
		and offer["next_tier"] == tier + 1 and offer["cost"] == 2
		and offer["current_stat"] == StitchedParts.stat_at_tier(entry, tier)
		and offer["next_stat"] == StitchedParts.stat_at_tier(entry, tier + 1)
		and offer["current_ability"] == StitchedParts.ability_at_tier(entry, tier)
		and offer["next_ability"] == StitchedParts.ability_at_tier(entry, tier + 1)
		and button != null and not button.disabled and button.focus_mode != Control.FOCUS_NONE
		and effects != null and effects.text.contains(JSON.stringify(offer["current_stat"]))
		and effects.text.contains(JSON.stringify(offer["next_stat"]))
		and button.tooltip_text.contains(JSON.stringify(offer["next_ability"])),
		"visible affordable button and current/next tiers exactly mirror authored full-catalog effects")
	var forged: Dictionary = before.duplicate(true)
	forged["scraps"] = 99
	seed(539207)
	var no_spend_rng := randi()
	seed(539207)
	_check(not app._stitched_sewing_upgrade("impostor", slot, before, weakref(panel)).get("ok")
		and not app._stitched_sewing_upgrade(hero_id, "bogus", before, weakref(panel)).get("ok")
		and not app._stitched_sewing_upgrade(hero_id, slot, forged, weakref(panel)).get("ok")
		and not upgrade.upgrade(hero_id, slot, "wrong-node", before).get("ok")
		and not upgrade.upgrade(hero_id, slot, NODE, forged).get("ok")
		and upgrade.read_state() == before and app.stitched_preview_scraps == 2
		and app.stitched_preview_satchel == satchel_before
		and app._stitched_gear_overrides == gear_before and randi() == no_spend_rng
		and _no_wallet(app), "forged, wrong hero/slot/node and stale price cannot mutate state/RNG")
	if button == null:
		await _finish(app)
		return
	var expected_heroes: Array = before["heroes"].duplicate(true)
	var changed_part: Dictionary = {}
	for hero in expected_heroes:
		if str(hero["id"]) == hero_id:
			hero["parts"][slot]["tier"] = tier + 1
			changed_part = hero["parts"][slot].duplicate(true)
	seed(539301)
	var purchase_rng := randi()
	seed(539301)
	button.pressed.emit()
	var after: Dictionary = upgrade.read_state()
	_check(not changed_part.is_empty() and changed_part["id"] == part_id
		and after["heroes"] == expected_heroes and after["version"] == before["version"] + 1
		and after["scraps"] == 0 and app.stitched_preview_scraps == 0
		and app._stitched_gear_overrides.get(hero_id, {}).get(slot) == changed_part
		and app.stitched_sewing_visit.read_state()["heroes"] == expected_heroes
		and app.stitched_sewing_mend_visit.read_state()["heroes"] == expected_heroes
		and app.stitched_sewing_mend_visit.read_state()["scraps"] == 0
		and not swap_old.read_state()["open"] and not mend_old.read_state()["open"]
		and app.stitched_preview_satchel == satchel_before
		and app._stitched_hp_carry == hp_before and app._stitched_bleed_carry == bleed_before
		and app.stitched_roadblock_candle == candle_before and app.stitched_preview_gold == gold_before
		and randi() == purchase_rng and _no_wallet(app),
		"one click raises only quoted worn part by one tier and pays once; other visits rebind")
	var now_disabled: Button = panel.find_child("Upgrade_%s_%s" % [hero_id, slot], true, false) as Button
	_check(now_disabled != null and now_disabled.disabled
		and now_disabled.focus_mode == Control.FOCUS_NONE
		and now_disabled.text.contains("insufficient scraps"),
		"spent scrap visibly disables subsequent upgrades")
	seed(539402)
	var replay_rng := randi()
	seed(539402)
	_check(not app._stitched_sewing_upgrade(hero_id, slot, before, weakref(panel)).get("ok")
		and not upgrade.upgrade(hero_id, slot, NODE, before).get("ok")
		and not app._stitched_sewing_upgrade(hero_id, slot, after, weakref(null)).get("ok")
		and upgrade.read_state() == after and app.stitched_preview_scraps == 0
		and app.stitched_preview_satchel == satchel_before and randi() == replay_rng,
		"old, replayed and detached-panel requests never charge or upgrade twice")
	panel.get_node("SewingLeave").pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel == null and app.stitched_sewing_upgrade_visit == null
		and app.stitched_sewing_visit == null and app.stitched_sewing_mend_visit == null
		and not upgrade.read_state()["open"]
		and not app._stitched_sewing_upgrade(hero_id, slot, after, weakref(panel)).get("ok")
		and app.stitched_preview_scraps == 0 and app._stitched_hp_carry == hp_before
		and app._stitched_bleed_carry == bleed_before and app.stitched_preview_gold == gold_before
		and app.stitched_preview_satchel == satchel_before and _no_wallet(app),
		"free Leave retires all three authorities and preserves unrelated carry and trophies")
	# The optional Peddler visit must not strip an already purchased tier.
	if app.stitched_peddler_button != null and app.stitched_peddler_button.visible:
		app.stitched_peddler_button.pressed.emit()
		await process_frame
		if app.stitched_peddler_panel != null:
			app.stitched_peddler_panel.get_node("PeddlerLeave").pressed.emit()
			await process_frame
	_check(app._stitched_gear_overrides.get(hero_id, {}).get(slot) == changed_part
		and app.stitched_peddler_panel == null and _no_wallet(app),
		"optional Peddler transition leaves upgraded part untouched")
	var next: StitchedBattleScreen = await _admit(app)
	_check(next != null and next.battle != null and next.battle.is_valid(),
		"new authenticated Roadblock Fight mounts after Circle/Peddler Leave")
	if next != null and next.battle != null and next.battle.is_valid():
		var unit: Dictionary = next.battle.get_unit(hero_id)
		var worn: Dictionary = unit.get("parts", {}).get(slot, {})
		var expected_skill: Dictionary = StitchedParts.ability_at_tier(next.parts.get(part_id, {}), tier + 1)
		var executed := false
		for attempt in range(16):
			if next.battle.is_over() or next.battle.current_side() != "hero":
				break
			var actor: Dictionary = next.battle.get_unit(next.battle.current_actor_id())
			if str(actor.get("id", "")) != hero_id:
				if next.submit_pass().get("ok") != true:
					break
				continue
			for rank in range(1, 5):
				if next.battle._legal_targets(actor, expected_skill, rank).is_empty():
					continue
				var used: Dictionary = next.submit_part(part_id, rank)
				executed = used.get("ok") == true and used.get("action") == "ability"
				break
			break
		_check(worn == changed_part and next._valid_part(unit, worn)
			and expected_skill == offer["next_ability"] and executed and _no_wallet(app),
			"next staged real Fight equips exact paid tier and executes the authored upgraded ability")
		if not next.battle.is_over():
			next._action_buttons["exit"].pressed.emit()
			await process_frame
	_check(app.stitched_preview_scraps == 0 and app.stitched_sewing_panel == null
		and _no_wallet(app), "unwon follow-on Fight never refunds an upgrade")
	await _finish(app)
