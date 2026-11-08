extends SceneTree
## S6: the actual Roadblock title/Fight/Circle flow earns its second normal foe field.
const FIRST := ["fray_scavenger", "scissor_crab", "moth_scribe"]
const FOLLOWON := ["ragling", "scissor_crab", "moth_scribe"]
const PART_SLOTS := ["head", "arms", "torso", "legs"]
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
		and app.party == null and app.enemies == null \
		and app.session_gold == 0 and app.run_scraps == 0 \
		and app.run_deck.is_empty() and app.run_heroes.is_empty()


func _foe_ids(foes: Array) -> Array:
	var result: Array = []
	for foe in foes:
		result.append(foe.get("id", ""))
	return result


func _offer(app: Node) -> LiveEventChoicePanel:
	app._open_stitched_fight() # Explicit Roadblock regression entry.
	await process_frame
	return app.stitched_event_panel


func _mount(app: Node) -> StitchedBattleScreen:
	var panel: LiveEventChoicePanel = await _offer(app)
	if panel == null or panel.get_choice_buttons().size() != 3:
		return null
	panel.get_choice_buttons()[0].pressed.emit()
	await process_frame
	return app.stitched_fight_view


## The signature action a doll would use from this limb slot in the mounted battle.
## S14 kits are fixed; a torn socket limb has no action. Legacy battles keep the
## worn part's authored ability.
func _slot_ability(stage: StitchedBattleScreen, actor: Dictionary, slot: String) -> Dictionary:
	if stage.battle != null and bool(stage.battle._s14):
		for candidate in actor.get("abilities", []):
			if str(candidate.get("slot", "")) != slot:
				continue
			if actor.get("parts", {}).has(slot) and bool(actor.parts[slot].get("torn", false)):
				return {}
			return candidate
		return {}
	var equipped: Dictionary = actor.get("parts", {}).get(slot, {})
	var id := str(equipped.get("id", ""))
	if id.is_empty() or not stage.parts.has(id):
		return {}
	return StitchedParts.ability_at_tier(stage.parts[id], int(equipped.get("tier", 1)))


func _strike_from_rank(battle: StitchedRules, actor: Dictionary, rank: int) -> bool:
	if battle == null or not bool(battle._s14):
		return false
	for ability in actor.get("abilities", []):
		if str(ability.get("target_side", "")) != "enemy" \
				or int(ability.get("dmg", [0, 0]).back()) <= 0:
			continue
		var slot := str(ability.get("slot", ""))
		if actor.get("parts", {}).has(slot) and bool(actor.parts[slot].get("torn", false)):
			continue
		if not StitchedParts.ranks_allowed(int(ability.get("launch_mask", 0)), rank) \
				or not battle._self_move_gate(actor, ability).is_empty():
			continue
		for target_rank in range(1, 5):
			if not battle._legal_targets(actor, ability, target_rank).is_empty():
				return true
	return false


func _try_move(stage: StitchedBattleScreen, key: String) -> bool:
	var button: Button = stage._action_buttons.get(key)
	if button == null or button.disabled:
		return false
	var before := stage.receipts.size()
	button.pressed.emit()
	return stage.receipts.size() > before


func _act(stage: StitchedBattleScreen) -> bool:
	if stage.battle == null or stage.battle.is_over() or stage.battle.current_side() != "hero":
		return false
	var battle: StitchedRules = stage.battle
	var actor: Dictionary = battle.get_unit(battle.current_actor_id())
	var best_slot := ""
	var best_target := ""
	var best_score := -10000.0
	for slot in PART_SLOTS:
		if not actor.get("parts", {}).has(slot) or not stage.select_part(slot):
			continue
		var ability := _slot_ability(stage, actor, slot)
		if ability.is_empty():
			continue
		# The mounted buttons still project the worn part, so a slot may be enabled
		# where the fixed signature cannot launch or is locked by its own move.
		if not StitchedParts.ranks_allowed(int(ability.get("launch_mask", 0)), int(actor.get("rank", 0))) \
				or not battle._self_move_gate(actor, ability).is_empty():
			continue
		for key in stage.legal_targets():
			var pieces := str(key).split("_")
			if pieces.size() != 2:
				continue
			var rank := int(pieces[1])
			# The mounted button lights this rank, and the fixed signature must
			# also accept that rank. Score the ability's real committed targets.
			var targets := battle._legal_targets(actor, ability, rank)
			if targets.is_empty():
				continue
			var score := -1000.0
			if str(ability.get("target_side", "")) == "enemy":
				# Focus the weakest real target so a normal foe stops contributing
				# damage instead of racing a full-health elite.
				for target in targets:
					score += 300.0 - float(target.get("hp", 0)) * 3.0
				score += float(int(ability.get("dmg", [0, 0])[0])
					+ int(ability.get("dmg", [0, 0]).back()))
			elif str(ability.get("kind", "")) == "heal":
				var dying := false
				var missing := 0
				for target in targets:
					if int(target.get("hp", 0)) <= 0 and not bool(target.get("lost", false)):
						dying = true
					missing = maxi(missing, int(target.get("max_hp", 0)) - int(target.get("hp", 0)))
				# Reviving a zero-HP doll is worth a turn; routine topping-up is not,
				# so the party shortens the fight instead of healing chip damage.
				if dying:
					score = 500.0 + missing
			if score > best_score:
				best_score = score
				best_slot = slot
				best_target = str(key)
	# A doll with no legal action at all steps to a rank where it can act.
	if best_slot.is_empty() and bool(battle._s14) \
			and not _strike_from_rank(battle, actor, int(actor.rank)):
		for key in ["move_back", "move_front"]:
			var direction := 1 if key == "move_back" else -1
			if not bool(battle._shift_valid(actor, direction).get("ok", false)):
				continue
			if not _strike_from_rank(battle, actor, int(actor.rank) + direction):
				continue
			if _try_move(stage, key):
				return true
	if best_slot.is_empty():
		var before := stage.receipts.size()
		stage._action_buttons["pass"].pressed.emit()
		return stage.receipts.size() > before
	var part_button: Button = stage._part_buttons[best_slot]
	if part_button.disabled:
		return false
	part_button.pressed.emit()
	var target_button: Button = stage._target_buttons.get(best_target)
	if not is_instance_valid(target_button) or target_button.disabled:
		return false
	var previous := stage.receipts.size()
	target_button.pressed.emit()
	return stage.receipts.size() > previous \
		and stage.receipts[previous].get("action") == "ability"


func _win(stage: StitchedBattleScreen) -> Dictionary:
	var acted := 0
	var start := stage.battle.state_snapshot()
	for turn in range(140):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		if not _act(stage):
			break
		acted += 1
	return {"acted": acted, "start": start, "end": stage.battle.state_snapshot(),
		"outcome": stage.battle.outcome(), "rng": stage.battle.rng_state(),
		"receipts": stage.receipts.duplicate(true)}


func _carry(app: Node) -> Dictionary:
	return {"party": app._stitched_party_picks.duplicate(true),
		"locked": app._stitched_party_locked,
		"gear": app._stitched_gear_overrides.duplicate(true),
		"hp": app._stitched_hp_carry.duplicate(true),
		"ranks": app._stitched_rank_carry.duplicate(true),
		"fray": app._stitched_fray_carry.duplicate(true),
		"bleed": app._stitched_bleed_carry.duplicate(true),
		"satchel": app.stitched_preview_satchel.duplicate(true),
		"scraps": app.stitched_preview_scraps, "gold": app.stitched_preview_gold,
		"candle": app.stitched_roadblock_candle,
		"stop": app._stitched_postvictory_stop_available,
		"wins": app._stitched_roadblock_win_count}


func _exercise() -> Dictionary:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(catalog.get("ok") == true and _no_legacy_wallet(app),
		"valid S5 enemy catalog and ordinary title with isolated legacy wallet")
	var config: Dictionary = app._stitched_floor_config()
	_check(_foe_ids(config.get("foes", [])) == FIRST and app._stitched_roadblock_win_count == 0,
		"the unearned first title Fight retains the original preview trio and rank order")
	var initial: Dictionary = _carry(app)
	_check(not app._begin_stitched_battle({}, null) and _carry(app) == initial,
		"unclaimed/invalid battle admission cannot advance or charge the Roadblock")
	var leave_panel: LiveEventChoicePanel = await _offer(app)
	_check(leave_panel != null and leave_panel.get_choice_buttons().size() == 3,
		"first genuine title offer is mounted before any fight")
	if leave_panel == null:
		app.free()
		await process_frame
		return {}
	leave_panel.get_choice_buttons()[2].pressed.emit()
	await process_frame
	_check(_carry(app) == initial and app.stitched_fight_view == null,
		"real Roadblock Leave cannot advance selection or award carry")
	var aborted: StitchedBattleScreen = await _mount(app)
	if aborted == null:
		_check(false, "first genuine fight can mount")
		app.free()
		await process_frame
		return {}
	_check(_foe_ids(aborted.battle.get_foes()) == FIRST and aborted.receipts.is_empty(),
		"first mounted seeded combat has the original three canonical foes")
	var aborted_foes := aborted.battle.get_foes().duplicate(true)
	aborted._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app._stitched_roadblock_win_count == 0 and app.stitched_preview_scraps == 0 \
		and app.stitched_preview_satchel.is_empty() and not app._stitched_party_locked \
		and not app._stitched_postvictory_stop_available and _no_legacy_wallet(app),
		"an unfinished authentic battle awards no trophy, stop, victory or party lock")
	var retreated: StitchedBattleScreen = await _mount(app)
	if retreated == null:
		_check(false, "re-admitted mounted retreat witness exists")
		app.free()
		await process_frame
		return {}
	for step in range(100):
		if retreated.battle.is_over():
			break
		if retreated.battle.current_side() != "hero":
			break
		retreated._action_buttons["retreat"].pressed.emit()
	_check(retreated.battle.outcome() == "retreated",
		"mounted Retreat reaches real non-victory terminal outcome")
	retreated._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app._stitched_roadblock_win_count == 0 and app.stitched_preview_gold == 0 \
		and app.stitched_preview_scraps == 0 and app._stitched_hp_carry.is_empty() \
		and not app._stitched_postvictory_stop_available,
		"Retreat cannot advance the foe field or mint carry/stops")
	var first: StitchedBattleScreen = await _mount(app)
	if first == null:
		_check(false, "earning Fight mounts after non-wins")
		app.free()
		await process_frame
		return {}
	var first_foes := first.battle.get_foes()
	var authored := true
	for index in range(3):
		var raw: Dictionary = StitchedEnemyCatalog.foe_for(catalog, FIRST[index])
		authored = authored and first_foes[index]["id"] == FIRST[index] \
			and first_foes[index]["rank"] == index + 1 \
			and first_foes[index]["abilities"] == raw["abilities"]
	_check(authored and first.battle.get_heroes().size() == 4,
		"preview rank 1–3 mounts original canonical authored abilities")
	var win := _win(first)
	var survivors := first.battle.get_heroes().duplicate(true)
	var four_survivors := survivors.size() == 4
	for hero in survivors:
		four_survivors = four_survivors and not bool(hero.get("lost", true))
	_check(win.get("outcome") == "victory" and int(win.get("acted", 0)) > 0 \
		and win.get("receipts", []).size() > 0 and four_survivors,
		"legal mounted hero abilities earn a genuine four-survivor Roadblock victory")
	if win.get("outcome") != "victory" or not four_survivors:
		app.free()
		await process_frame
		return win
	var title_foes: Array = _foe_ids(first.battle.get_foes())
	first._action_buttons["exit"].pressed.emit()
	await process_frame
	var circle: Control = app.stitched_sewing_panel
	_check(circle != null and app._stitched_roadblock_win_count == 1 \
		and app.stitched_preview_gold == 10 and app.stitched_preview_scraps == 1 \
		and app.stitched_preview_satchel.size() == 3 and not app._stitched_party_locked \
		and _no_legacy_wallet(app),
		"only real settled victory increments progression and awards the original three trophies")
	if circle == null:
		app.free()
		await process_frame
		return win
	var first_loot: Array = app.stitched_preview_satchel.duplicate(true)
	var expected_loot := ["scissor_crab", "fray_scavenger", "moth_scribe"]
	for index in range(3):
		_check(first_loot[index]["id"] == StitchedEnemyCatalog.trophy_for(catalog, expected_loot[index]),
			"first win trophy %d comes from canonical foe kit" % index)
	var before_leave: Dictionary = _carry(app)
	var stale_state: Dictionary = app.stitched_sewing_visit.read_state()
	var fake: Dictionary = stale_state.duplicate(true)
	fake["version"] = int(fake["version"]) + 100
	_check(not app._stitched_sewing_leave(fake, weakref(circle)).get("ok") \
		and _carry(app) == before_leave,
		"forged/stale Circle Leave cannot change selection, carried state or reward")
	circle.get_node("SewingLeave").pressed.emit()
	await process_frame
	var earned := _carry(app)
	_check(earned["locked"] and earned["wins"] == 1 and earned["hp"].size() == 4 \
		and earned["ranks"].size() == 4 and earned["fray"].size() == 4 \
		and earned["stop"] and earned["satchel"] == first_loot and _no_legacy_wallet(app),
		"authenticated Circle Leave locks four heroes and retains all earned carry/stops")
	_check(not app._stitched_sewing_leave(stale_state, weakref(circle)).get("ok") \
		and _carry(app) == earned,
		"duplicate stale Leave cannot repeat progression or carry")
	var follow_config: Dictionary = app._stitched_floor_config()
	var follow_valid := _foe_ids(follow_config.get("foes", [])) == FOLLOWON
	for index in range(mini(3, follow_config.get("foes", []).size())):
		var candidate: Dictionary = follow_config["foes"][index]
		var canonical: Dictionary = StitchedEnemyCatalog.foe_for(catalog, FOLLOWON[index])
		follow_valid = follow_valid and candidate == canonical \
			and not bool(candidate.get("is_boss", true)) \
			and candidate.get("turns_per_round") == 1 \
			and not StitchedEnemyCatalog.trophy_for(catalog, FOLLOWON[index]).is_empty()
	_check(follow_valid and follow_config.get("seed") == config.get("seed"),
		"earned next config resolves three valid nonboss canonical S5 kits with unchanged seed")
	var saved_hp: Dictionary = earned["hp"].duplicate(true)
	app._stitched_hp_carry["warden"] = "forged"
	_check(app._stitched_floor_config().is_empty(),
		"invalid carried HP fails closed instead of mounting a foe or gifting a heal")
	app._stitched_hp_carry = saved_hp
	var saved_rank: Dictionary = earned["ranks"].duplicate(true)
	app._stitched_rank_carry["impostor"] = 1
	_check(app._stitched_floor_config().is_empty(),
		"foreign rank replay fails closed without substituting a default hero")
	app._stitched_rank_carry = saved_rank
	_check(_carry(app) == earned and not app._stitched_floor_config().is_empty(),
		"rejecting malformed carry leaves the authenticated ledger intact")
	# The second *real* admission must use the new trio, not only a helper config.
	var follow: StitchedBattleScreen = await _mount(app)
	if follow == null:
		_check(false, "follow-on authentic Fight mounts")
		app.free()
		await process_frame
		return win
	var second_foes := follow.battle.get_foes().duplicate(true)
	var legal_kits := _foe_ids(second_foes) == FOLLOWON
	for index in range(mini(3, second_foes.size())):
		legal_kits = legal_kits and second_foes[index]["rank"] == index + 1 \
			and second_foes[index]["abilities"] == StitchedEnemyCatalog.foe_for(
				catalog, FOLLOWON[index])["abilities"]
	var second_heroes := follow.battle.get_heroes().duplicate(true)
	var carry_ok := second_heroes.size() == 4
	for hero in second_heroes:
		var id := str(hero.get("id", ""))
		carry_ok = carry_ok and id in earned["party"] \
			and hero["rank"] == earned["ranks"].get(id) \
			and hero["hp"] == earned["hp"].get(id) \
			and hero["fray"] == earned["fray"].get(id, {}).get("fray") \
			and hero["resolve"] == earned["fray"].get(id, {}).get("resolve")
		var bleeding: Variant = hero.get("statuses", {}).get("bleed", 0)
		carry_ok = carry_ok and bleeding == earned["bleed"].get(id, 0)
		for slot in PART_SLOTS:
			var before_part: Dictionary = follow_config["heroes"][int(hero["rank"]) - 1]["parts"][slot]
			carry_ok = carry_ok and hero["parts"][slot] == before_part
	var entered: Dictionary = _carry(app)
	_check(legal_kits and carry_ok and follow.is_visible_in_tree() \
		and follow.battle.is_valid() and follow.battle.current_side() == "hero" \
		and entered["candle"] == maxi(0, earned["candle"] - app.STITCHED_ROADBLOCK_CANDLE_COST) \
		and follow.config["candle"] == entered["candle"] \
		and entered["gold"] == earned["gold"] and entered["scraps"] == earned["scraps"] \
		and entered["satchel"] == earned["satchel"] and entered["stop"] == earned["stop"] \
		and entered["locked"] and entered["wins"] == 1 and _no_legacy_wallet(app),
		"second real mounted Fight seats canonical ranks, earned gear/HP/FRAY/resolve/Bleed, one candle debit and existing stops")
	var initial_second := follow.battle.state_snapshot()
	var original_rng := follow.battle.rng_state()
	var action_ok := _act(follow)
	_check(action_ok and follow.receipts.size() > 0 \
		and follow.battle.state_snapshot() != initial_second,
		"follow-on normal foes admit at least one legal mounted hero action")
	var replay := {"first": win, "first_foes": title_foes, "second_foes": _foe_ids(second_foes),
		"second_start": initial_second, "second_rng": original_rng,
		"second_action": follow.battle.state_snapshot(),
		"second_receipts": follow.receipts.duplicate(true),
		"earned": earned, "entered": entered}
	var blocked := _carry(app)
	app._stitched_fight_exit(weakref(app))
	_check(_carry(app) == blocked and app.stitched_fight_view == follow,
		"wrong-source and duplicate exit callbacks cannot claim second victory")
	follow._action_buttons["exit"].pressed.emit()
	await process_frame
	var after_abort: Dictionary = _carry(app)
	_check(app.stitched_fight_view == null and app.stitched_sewing_panel == null \
		and after_abort == entered and _no_legacy_wallet(app),
		"aborted second Fight does not advance selection, mint trophies or erase earned stop/carry")
	app.free()
	await process_frame
	return replay


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var first: Dictionary = await _exercise()
	var replay: Dictionary = await _exercise()
	_check(not first.is_empty() and first == replay,
		"two independently entered same-seed complete Roadblock/Circle/follow-on paths replay exactly")
	for failure in failures:
		printerr(failure)
	print("stitched_s6_followon_foes_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
