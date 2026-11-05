extends SceneTree
## S6: real Roadblock wounds and torn gear survive Victory -> Circle Leave -> next Fight.
var failures: Array[String] = []
var checks := 0
const NODE := "s5_scissor_crab_sewing_circle"


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


## Identity-sensitive positions are checked independently of display or array order.
func _rank_map(heroes: Array) -> Dictionary:
	var ranks: Dictionary = {}
	for raw in heroes:
		if not raw is Dictionary or typeof(raw.get("id")) != TYPE_STRING \
				or typeof(raw.get("rank")) != TYPE_INT or ranks.has(raw["id"]):
			return {}
		ranks[raw["id"]] = raw["rank"]
	return ranks


func _rank_permutation(ranks: Dictionary, picks: Array) -> bool:
	if ranks.size() != 4 or picks.size() != 4:
		return false
	var seen: Dictionary = {}
	for id in picks:
		if not ranks.has(id) or typeof(ranks[id]) != TYPE_INT \
				or int(ranks[id]) < 1 or int(ranks[id]) > 4 or seen.has(ranks[id]):
			return false
		seen[ranks[id]] = true
	return seen.size() == 4


## Malformed app-owned rank state must not even mount a Fight or charge a candle.
func _rank_refusals(app: Node) -> void:
	var picks: Array = app._stitched_party_picks.duplicate()
	var valid: Dictionary = {}
	for index in range(4):
		valid[picks[index]] = index + 1
	var bad_ledgers: Array = []
	var duplicate: Dictionary = valid.duplicate()
	duplicate[picks[1]] = 1
	bad_ledgers.append(duplicate)
	var outside: Dictionary = valid.duplicate()
	outside[picks[0]] = 5
	bad_ledgers.append(outside)
	var zero: Dictionary = valid.duplicate()
	zero[picks[0]] = 0
	bad_ledgers.append(zero)
	var nonint: Dictionary = valid.duplicate()
	nonint[picks[0]] = 1.0
	bad_ledgers.append(nonint)
	var foreign: Dictionary = valid.duplicate()
	foreign.erase(picks[0])
	foreign["foreign_doll"] = 1
	bad_ledgers.append(foreign)
	var partial: Dictionary = valid.duplicate()
	partial.erase(picks[3])
	bad_ledgers.append(partial)
	for ledger in bad_ledgers:
		app._stitched_rank_carry = ledger.duplicate(true)
		_check(app._stitched_floor_config().is_empty(),
			"invalid rank ledger denied before full canonical floor input")
	var before_candle: int = app.stitched_roadblock_candle
	var refused: StitchedBattleScreen = await _admit(app)
	_check(refused == null and app.stitched_fight_view == null \
		and app.stitched_roadblock_candle == before_candle and _no_wallet(app) \
		and app._stitched_hp_carry.is_empty() and app.stitched_preview_scraps == 0,
		"malformed ledger blocks genuine title Fight admission without candle/resources")
	app._stitched_rank_carry.clear()
	_check(not app._stitched_floor_config().is_empty(),
		"clearing rejected rank ledger restores canonical floor admission")


## FRAY/resolve are an indivisible canonical-ID carry. A poisoned authority
## cannot reach the mounted Fight or draw from its seeded rules.
func _fray_refusals(app: Node) -> void:
	var id: String = str(app._stitched_party_picks[0])
	var original: Dictionary = app._stitched_fray_carry.duplicate(true)
	var wrong: Array = [
		{"fray": -1, "resolve": ""}, {"fray": 200, "resolve": ""},
		{"fray": 3.0, "resolve": ""}, {"fray": "4", "resolve": ""},
		{"fray": 12, "resolve": "stranger"}, {"fray": 12, "resolve": 4},
		{"fray": 45, "resolve": "frantic"}, {"fray": 100, "resolve": ""},
		{"fray": 12}, {"fray": 12, "resolve": "", "other": true},
		{"fray": 12, "resolve": null},
	]
	for item in wrong:
		app._stitched_fray_carry = {}
		app._stitched_fray_carry[id] = item.duplicate(true)
		_check(app._stitched_floor_config().is_empty(),
			"malformed FRAY/mood entry fails floor admission: " + str(item))
	app._stitched_fray_carry = {"foreign_doll": {"fray": 10, "resolve": ""}}
	_check(app._stitched_floor_config().is_empty(),
		"foreign identity FRAY cannot be seated in any rank")
	var candle: int = app.stitched_roadblock_candle
	var before_scraps: int = app.stitched_preview_scraps
	var denied: StitchedBattleScreen = await _admit(app)
	_check(denied == null and app.stitched_roadblock_candle == candle \
		and app._stitched_fray_carry.has("foreign_doll") and _no_wallet(app) \
		and app.stitched_preview_scraps == before_scraps,
		"foreign FRAY fails real Fight admission without spending candle or RNG")
	app._stitched_fray_carry = original
	_check(not app._stitched_floor_config().is_empty(),
		"restored FRAY authority permits canonical floor")


func _victory(stage: StitchedBattleScreen) -> Dictionary:
	if stage == null or stage.battle == null or not stage.battle.is_valid():
		return {}
	var steps := 0
	var abilities := 0
	var legal_swap: Dictionary = {}
	for iteration in range(90):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		var actor: Dictionary = stage.battle.get_unit(stage.battle.current_actor_id())
		# A genuine action receipt, not an edited rank or a fabricated carry.
		if legal_swap.is_empty():
			for direction in [1, -1]:
				var move_receipt: Dictionary = stage.submit_move(direction)
				if move_receipt.get("ok") == true and move_receipt.get("action") == "move" \
						and not str(move_receipt.get("swapped", "")).is_empty():
					legal_swap = move_receipt.duplicate(true)
					steps += 1
					break
			if not legal_swap.is_empty():
				continue
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
	return {"steps": steps, "abilities": abilities, "move": legal_swap,
		"outcome": stage.battle.outcome(),
		"foes": stage.battle.get_foes().duplicate(true)}


# The same authored four-hero, three-foe config used by the live title path.
# Invalid starting HP must fail before admission; omitted HP remains full.
func _starting_hp_contract(app: Node) -> void:
	var input: Dictionary = app._stitched_floor_config()
	_check(input.get("heroes", []).size() == 4 and input.get("foes", []).size() == 3,
		"starting HP checks have the genuine complete Roadblock config")
	if input.get("heroes", []).size() != 4:
		return
	var original := StitchedRules.create(input)
	_check(original.get("ok") == true and original.get("battle") != null,
		"omitted HP admits a complete seeded rules session")
	if original.get("ok") != true:
		return
	var id := str(input["heroes"][0]["id"])
	var base: Dictionary = original["battle"].get_unit(id)
	var cap: int = int(base["max_hp"])
	_check(cap > 0 and base["hp"] == cap and not base["hanging"] and not base["lost"],
		"omitted starting HP means full worn-part-adjusted health")
	var replay := StitchedRules.create(input)
	_check(replay.get("ok") == true
		and replay["battle"].state_snapshot() == original["battle"].state_snapshot(),
		"unchanged seeded replay is deterministic without HP")
	for requested_hp in [0, 1, cap]:
		var valid: Dictionary = input.duplicate(true)
		valid["heroes"][0]["hp"] = requested_hp
		var created := StitchedRules.create(valid)
		var twice := StitchedRules.create(valid)
		var correct: bool = created.get("ok") == true and twice.get("ok") == true
		if correct:
			var hero: Dictionary = created["battle"].get_unit(id)
			correct = hero["hp"] == requested_hp and hero["max_hp"] == cap \
				and hero["hanging"] == (requested_hp == 0) and not hero["lost"] \
				and hero["parts"] == base["parts"] \
				and created["battle"].state_snapshot() == twice["battle"].state_snapshot() \
				and created["battle"].rng_state() == twice["battle"].rng_state()
		_check(correct, "legal HP %s retains exact health/Hanging/parts and seeded replay" % requested_hp)
	for bad_hp in [-1, cap + 1, 1.5, 8.0, "8", null, true, {}, []]:
		var invalid: Dictionary = input.duplicate(true)
		invalid["heroes"][0]["hp"] = bad_hp
		var denied := StitchedRules.create(invalid)
		_check(denied.get("ok") != true and denied.get("battle") == null,
			"negative/oversized/noninteger starting HP refused: " + str(bad_hp))
	_check(base["fray"] == 0 and base["resolve"] == "",
		"omitted FRAY/resolve retains zero and empty mood")
	for starting in [
		{"fray": 31, "resolve": ""},
		{"fray": 109, "resolve": "hollow"},
		{"fray": 65, "resolve": "reckless"},
		{"fray": 45, "resolve": "steadfast"},
	]:
		var valid: Dictionary = input.duplicate(true)
		valid["heroes"][0]["fray"] = starting["fray"]
		valid["heroes"][0]["resolve"] = starting["resolve"]
		var first := StitchedRules.create(valid)
		var second := StitchedRules.create(valid)
		_check(first.get("ok") == true and second.get("ok") == true \
			and first["battle"].get_unit(id)["fray"] == starting["fray"] \
			and first["battle"].get_unit(id)["resolve"] == starting["resolve"] \
			and first["battle"].state_snapshot() == second["battle"].state_snapshot(),
			"legal settled FRAY and ongoing Unravelled/Steadfast replay without setup resolve: " + str(starting))
	for malformed in [
		{"fray": -1, "resolve": ""}, {"fray": 200, "resolve": ""},
		{"fray": true, "resolve": ""}, {"fray": 1.0, "resolve": ""},
		{"fray": 51, "resolve": 2}, {"fray": 51, "resolve": "bogus"},
		{"fray": 22, "resolve": "bitter"}, {"fray": 100, "resolve": ""},
	]:
		var invalid: Dictionary = input.duplicate(true)
		invalid["heroes"][0]["fray"] = malformed["fray"]
		invalid["heroes"][0]["resolve"] = malformed["resolve"]
		var rejected := StitchedRules.create(invalid)
		_check(rejected.get("ok") != true and rejected.get("battle") == null,
			"rules reject malformed starting FRAY/resolve before seeded round: " + str(malformed))


func _trace() -> Dictionary:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	_check(app._stitched_gear_overrides.is_empty() and app._stitched_hp_carry.is_empty()
		and app._stitched_rank_carry.is_empty() and app._stitched_fray_carry.is_empty() \
		and app.stitched_preview_scraps == 0 and _no_wallet(app),
		"fresh title has no carried health, parts, scraps or legacy resources")
	_starting_hp_contract(app)
	await _rank_refusals(app)
	await _fray_refusals(app)
	# No non-victory route may open the Circle or invent a torn-gear carry.
	var aborted: StitchedBattleScreen = await _admit(app)
	_check(aborted != null and aborted.battle != null and aborted.battle.is_valid(),
		"first public title Roadblock is genuinely mounted")
	if aborted == null:
		app.free()
		await process_frame
		return {}
	aborted._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel == null and app._stitched_gear_overrides.is_empty()
		and app._stitched_hp_carry.is_empty() and app._stitched_rank_carry.is_empty() \
		and app.stitched_preview_scraps == 0,
		"unwon exit grants neither Circle nor HP/gear override")
	var first: StitchedBattleScreen = await _admit(app)
	if first == null:
		_check(false, "won battle needs authenticated Fight admission")
		app.free()
		await process_frame
		return {}
	var won := _victory(first)
	var move: Dictionary = won.get("move", {})
	var victory_ranks: Dictionary = _rank_map(first.battle.get_heroes())
	var starting_ranks: Dictionary = _rank_map(app._stitched_party_receipt.get("heroes", []))
	_check(move.get("ok") == true and move.get("action") == "move" \
		and move.get("from") != move.get("to") and str(move.get("swapped", "")) in app._stitched_party_picks \
		and _rank_permutation(victory_ranks, app._stitched_party_picks) \
		and victory_ranks != starting_ranks,
		"genuine submit_move swaps selected allies and produces distinct surviving ending ranks")
	_check(won.get("outcome") == "victory" and int(won.get("steps", 0)) > 0
		and int(won.get("abilities", 0)) > 0 and won.get("foes", []).size() == 3 \
		and victory_ranks.size() == 4,
		"all three foes defeated via mounted legal combat actions")
	if won.get("outcome") != "victory":
		first._action_buttons["exit"].pressed.emit()
		await process_frame
		app.free()
		await process_frame
		return {}
	# Witness damage from the real combat receipts, not a fabricated HP edit.
	var battle_foe_ids: Array = []
	for foe in first.battle.get_foes():
		battle_foe_ids.append(str(foe["id"]))
	var battle_hero_ids: Array = []
	for hero in first.battle.get_heroes():
		battle_hero_ids.append(str(hero["id"]))
	var live_hits := 0
	var enemy_fray_events := 0
	for action in first.receipts:
		if str(action.get("actor", "")) not in battle_foe_ids:
			continue
		for impact in action.get("results", []):
			if str(impact.get("target", "")) in battle_hero_ids \
					and int(impact.get("damage", 0)) > 0:
				live_hits += 1
			if impact.get("fray_event", {}).get("change", 0) > 0 \
					or impact.get("enemy_crit_fray", {}).get("change", 0) > 0:
				enemy_fray_events += 1
	var victory_bleed: Dictionary = {}
	for hero in first.battle.get_heroes():
		var bleed: Variant = hero.get("statuses", {}).get("bleed", 0)
		if typeof(bleed) == TYPE_INT and int(bleed) > 0:
			victory_bleed[str(hero["id"])] = bleed
	var victory_hp: Dictionary = {}
	var victory_fray: Dictionary = {}
	var frayed_survivors := 0
	var wounded_survivors := 0
	for hero in first.battle.get_heroes():
		if bool(hero.get("lost", false)):
			continue
		victory_hp[str(hero["id"])] = int(hero["hp"])
		victory_fray[str(hero["id"])] = {"fray": int(hero["fray"]), "resolve": str(hero["resolve"])}
		if int(hero["fray"]) > 0:
			frayed_survivors += 1
		if int(hero["hp"]) < int(hero["max_hp"]):
			wounded_survivors += 1
	_check(live_hits > 0 and wounded_survivors > 0 and not victory_hp.is_empty(),
		"foe hits visibly damaged at least one survivor through actual combat")
	_check(enemy_fray_events > 0 and frayed_survivors > 0 and victory_fray.size() == 4,
		"authored Roadblock foe actions naturally inflict nonzero FRAY on a surviving hero")
	# Only a surviving hero's torn flag is controlled AFTER genuine victory.
	var hero_id := ""
	var original_parts: Dictionary = {}
	for hero in first.battle.get_heroes():
		if not bool(hero.get("lost", false)):
			hero_id = str(hero["id"])
			original_parts = hero["parts"].duplicate(true)
			first.battle._units[hero_id]["parts"]["arms"]["torn"] = true
			break
	_check(not hero_id.is_empty() and original_parts.size() == StitchedParts.SLOTS.size()
		and original_parts["arms"]["id"] != "", "real surviving combat hero is torn only after victory")
	if hero_id.is_empty():
		app.free()
		await process_frame
		return {}
	var torn: Dictionary = original_parts["arms"].duplicate(true)
	torn["torn"] = true
	var intact: Dictionary = original_parts.duplicate(true)
	intact["arms"] = torn.duplicate(true)
	first._action_buttons["exit"].pressed.emit()
	await process_frame
	var panel: Control = app.stitched_sewing_panel
	_check(app._stitched_rank_carry == victory_ranks \
		and app._stitched_bleed_carry == victory_bleed \
		and app._stitched_fray_carry == victory_fray \
		and app._stitched_hp_carry == victory_hp and not victory_hp.is_empty(),
		"only authentic terminal-victory survivor HP enters app-owned ID carry")
	var swap: RunStitchedSewingSwap = app.stitched_sewing_visit
	var mend: RunStitchedSewingMend = app.stitched_sewing_mend_visit
	_check(panel != null and swap != null and mend != null
		and app.stitched_fight_view == null and app.stitched_preview_scraps == 1
		and app.stitched_preview_satchel.size() == 3 and _no_wallet(app),
		"win mints one genuine scrap and three trophies, then mounts both Circle services")
	if panel == null or swap == null or mend == null:
		app.free()
		await process_frame
		return {}
	var displayed: Dictionary = app._stitched_sewing_quote["state"].duplicate(true)
	var mend_displayed: Dictionary = app._stitched_mend_quote["state"].duplicate(true)
	var part_in_circle: Dictionary = {}
	for hero in displayed["heroes"]:
		if str(hero["id"]) == hero_id:
			part_in_circle = hero["parts"]
	_check(part_in_circle == intact and displayed["heroes"] == mend_displayed["heroes"]
		and displayed["satchel"] == app.stitched_preview_satchel,
		"both live services display the same torn arm and other unchanged slots")
	var disabled: Button = panel.find_child("Mend_%s_arms" % hero_id, true, false) as Button
	_check(disabled != null and disabled.disabled and disabled.text.contains("insufficient scraps"),
		"one genuine scrap cannot silently repair torn arms")
	var before_ranks: Dictionary = app._stitched_rank_carry.duplicate(true)
	var before_bleed: Dictionary = app._stitched_bleed_carry.duplicate(true)
	var before_fray: Dictionary = app._stitched_fray_carry.duplicate(true)
	var before_hp: Dictionary = app._stitched_hp_carry.duplicate(true)
	var before_overrides: Dictionary = app._stitched_gear_overrides.duplicate(true)
	var before_satchel: Array = app.stitched_preview_satchel.duplicate(true)
	var stale: Dictionary = displayed.duplicate(true)
	stale["version"] = -1
	seed(61544)
	var expected_rng := randi()
	seed(61544)
	_check(not app._stitched_sewing_leave(stale, weakref(panel)).get("ok")
		and not app._stitched_sewing_leave(displayed, null).get("ok")
		and not swap.leave("wrong-node", displayed).get("ok")
		and not mend.leave("wrong-node", mend_displayed).get("ok")
		and app._stitched_gear_overrides == before_overrides
		and app._stitched_hp_carry == before_hp and app._stitched_rank_carry == before_ranks \
		and app._stitched_bleed_carry == before_bleed \
		and app._stitched_fray_carry == before_fray
		and swap.read_state() == displayed and mend.read_state() == mend_displayed
		and app.stitched_preview_scraps == 1 and app.stitched_preview_satchel == before_satchel
		and randi() == expected_rng and _no_wallet(app),
		"stale/forged/wrong-node Leave denied without resources, authority, gear or RNG changes")
	var leave: Button = panel.get_node("SewingLeave")
	leave.pressed.emit()
	var carried: Dictionary = app._stitched_gear_overrides.duplicate(true)
	var leave_ok: bool = app.stitched_sewing_panel == null and app.stitched_sewing_visit == null
	leave_ok = leave_ok and app.stitched_sewing_mend_visit == null
	leave_ok = leave_ok and not swap.read_state()["open"] and not mend.read_state()["open"]
	leave_ok = leave_ok and int(swap.read_state()["version"]) == int(displayed["version"]) + 1
	leave_ok = leave_ok and int(mend.read_state()["version"]) == int(mend_displayed["version"]) + 1
	leave_ok = leave_ok and swap.read_state()["heroes"] == mend.read_state()["heroes"]
	leave_ok = leave_ok and carried.get(hero_id, {}).get("arms") == torn
	leave_ok = leave_ok and app.stitched_preview_scraps == 1
	leave_ok = leave_ok and app.stitched_preview_satchel == before_satchel and _no_wallet(app)
	_check(leave_ok, "one displayed Leave closes both receipts and carries precise still-torn arm")
	var closed: Dictionary = carried.duplicate(true)
	leave.pressed.emit()
	_check(not app._stitched_sewing_leave(displayed, weakref(panel)).get("ok")
		and not swap.leave(NODE, displayed).get("ok")
		and not mend.leave(NODE, mend_displayed).get("ok")
		and app._stitched_gear_overrides == closed
		and app._stitched_hp_carry == before_hp and app._stitched_rank_carry == before_ranks \
		and app._stitched_bleed_carry == before_bleed \
		and app._stitched_fray_carry == before_fray and app.stitched_preview_scraps == 1,
		"old displayed callbacks and closed receipts cannot replay a carry or spend")
	await process_frame
	var config: Dictionary = app._stitched_floor_config()
	var expected_parts: Dictionary = {}
	for hero in config.get("heroes", []):
		if str(hero["id"]) == hero_id:
			expected_parts = hero["parts"]
	var config_hp: Dictionary = {}
	var config_fray: Dictionary = {}
	for hero in config.get("heroes", []):
		if victory_hp.has(str(hero["id"])):
			config_hp[str(hero["id"])] = int(hero.get("hp", -1))
			config_fray[str(hero["id"])] = {"fray": hero.get("fray"), "resolve": hero.get("resolve")}
	_check(_rank_map(config.get("heroes", [])) == victory_ranks \
		and config_hp == victory_hp and config_fray == victory_fray \
		and frayed_survivors > 0 and not config_hp.is_empty(),
		"after worn gear projection, all same-loadout survivors keep exact witnessed HP")
	var same_parts := expected_parts.size() == StitchedParts.SLOTS.size()
	for slot in StitchedParts.SLOTS:
		same_parts = same_parts and expected_parts.get(slot) == intact.get(slot)
	_check(same_parts and config.get("seed") == 4982026 and config.get("foes", []).size() == 3,
		"next authenticated floor input retains torn ID/tier/flag and all untouched slots")
	var second: StitchedBattleScreen = await _admit(app)
	_check(second != null and second.battle != null and second.battle.is_valid(),
		"real second Fight is mounted by title Roadblock button, not a fixture")
	var trace: Dictionary = {}
	if second != null and second.battle != null:
		var mounted_ranks: Dictionary = _rank_map(second.battle.get_heroes())
		var mounted_bleed: Dictionary = {}
		for hero in second.battle.get_heroes():
			var bleed: Variant = hero.get("statuses", {}).get("bleed", 0)
			if typeof(bleed) == TYPE_INT and int(bleed) > 0:
				mounted_bleed[str(hero["id"])] = bleed
		_check(mounted_ranks == victory_ranks and mounted_ranks.size() == 4 \
			and mounted_bleed == victory_bleed,
			"new mounted battle preserves every victory ID/rank and carried Bleed")
		var mounted_hp: Dictionary = {}
		var mounted_fray: Dictionary = {}
		var mounted_wounds := 0
		for hero in second.battle.get_heroes():
			var id := str(hero["id"])
			if victory_hp.has(id):
				mounted_hp[id] = int(hero["hp"])
				mounted_fray[id] = {"fray": hero["fray"], "resolve": hero["resolve"]}
				if int(hero["hp"]) < int(hero["max_hp"]):
					mounted_wounds += 1
		_check(mounted_hp == config_hp and mounted_fray == victory_fray \
			and mounted_wounds > 0 \
			and second.config.get("candle") == app.stitched_roadblock_candle,
			"new live Fight mounts exact wounded survivor HP without free healing or candle mismatch")
		var unit: Dictionary = second.battle.get_unit(hero_id)
		var arms: Dictionary = unit.get("parts", {}).get("arms", {})
		var correct := arms == torn and not second._valid_part(unit, arms)
		for slot in ["head", "torso", "legs"]:
			correct = correct and unit.get("parts", {}).get(slot) == intact.get(slot)
		_check(correct, "new real battle has torn original arm disabled, intact parts unchanged")
		var witness_turn := false
		var illegal_no_spend := false
		var legal_intact := false
		for turn in range(30):
			if second.battle.is_over() or second.battle.current_side() != "hero":
				break
			if second.battle.current_actor_id() == hero_id:
				witness_turn = true
				var snapshot: Dictionary = second.battle.state_snapshot()
				var rng_before: int = second.battle.rng_state()
				var count_before := second.receipts.size()
				var denied: Dictionary = second.submit_part(str(torn["id"]), 1)
				illegal_no_spend = denied.get("ok") != true and not second.select_part("arms") \
					and second.battle.state_snapshot() == snapshot \
					and second.battle.rng_state() == rng_before \
					and second.receipts.size() == count_before
				legal_intact = second._valid_part(second.battle.get_unit(hero_id), intact["head"])
				break
			second.submit_pass()
		_check(witness_turn and illegal_no_spend and legal_intact,
			"actual next hero turn refuses torn ability without action/RNG spend; intact ability remains legal")
		trace = {"parts": unit["parts"].duplicate(true), "config": expected_parts.duplicate(true),
			"ranks": mounted_ranks.duplicate(true), "bleed": mounted_bleed.duplicate(true),
			"fray": mounted_fray.duplicate(true), "natural_fray_events": enemy_fray_events,
			"move": move.duplicate(true),
			"opening": second.battle.opening_strike(), "hp": mounted_hp.duplicate(true),
			"scraps": app.stitched_preview_scraps,
			"satchel": app.stitched_preview_satchel.duplicate(true),
			"candle": app.stitched_roadblock_candle}
		second._action_buttons["exit"].pressed.emit()
		await process_frame
		_check(app.stitched_sewing_panel == null and app._stitched_gear_overrides == closed
			and app._stitched_hp_carry == before_hp and app._stitched_rank_carry == before_ranks \
			and app._stitched_bleed_carry == before_bleed \
			and app._stitched_fray_carry == before_fray \
			and app.stitched_preview_scraps == 1 and _no_wallet(app),
			"unfinished second Fight cannot heal/corrupt carry, repair gear or mint reward")
	# Replayed/forged exits from a retired stage cannot change the authenticated HP.
	app._stitched_fight_exit(weakref(second))
	app._stitched_fight_exit(null)
	_check(app._stitched_hp_carry == before_hp and app._stitched_rank_carry == before_ranks \
		and app._stitched_bleed_carry == before_bleed \
		and app._stitched_fray_carry == before_fray and _no_wallet(app),
		"stale and null battle exit callbacks cannot replace survivor HP")
	# A draft or cancelled party edit retains HP. Only a genuine Confirm drops
	# the deselected survivor, without touching the other three IDs.
	app.stitched_fight_button.pressed.emit()
	await process_frame
	var picker: LiveEventChoicePanel = app.stitched_event_panel
	_check(picker != null and app._stitched_party_checkboxes.has(hero_id),
		"authenticated Roadblock mounts a fresh party picker after abandoned Fight")
	if picker != null and app._stitched_party_checkboxes.has(hero_id):
		var spare_id := ""
		for id in StitchedPartyAdmission.HERO_IDS:
			if not id in app._stitched_party_picks:
				spare_id = str(id)
				break
		_check(not spare_id.is_empty(), "legal alternative hero exists for reselection")
		var original: Dictionary = app._stitched_hp_carry.duplicate(true)
		var original_fray: Dictionary = app._stitched_fray_carry.duplicate(true)
		app._stitched_party_checkboxes[hero_id].button_pressed = false
		_check(app._stitched_hp_carry == original and app._stitched_rank_carry == before_ranks \
			and app._stitched_fray_carry == original_fray \
			and app._stitched_party_picks.has(hero_id),
			"unfinished three-hero draft cannot clear stored HP")
		app._stitched_party_cancel_button.pressed.emit()
		_check(app._stitched_hp_carry == original and app._stitched_rank_carry == before_ranks \
			and app._stitched_fray_carry == original_fray \
			and app._stitched_party_picks.has(hero_id),
			"Cancel restores confirmed party without modifying any HP")
		if not spare_id.is_empty():
			app._stitched_party_checkboxes[hero_id].button_pressed = false
			app._stitched_party_checkboxes[spare_id].button_pressed = true
			app._stitched_party_confirm_button.pressed.emit()
			var remaining := true
			for id in original:
				if str(id) != hero_id:
					remaining = remaining and app._stitched_hp_carry.get(id) == original[id]
			var canonical_ranks: Dictionary = _rank_map(app._stitched_party_receipt.get("heroes", []))
			var fresh_fray: Dictionary = {}
			for entry in app._stitched_floor_config().get("heroes", []):
				fresh_fray[str(entry["id"])] = {"fray": entry.get("fray", 0), "resolve": entry.get("resolve", "")}
			var remaining_fray := true
			for old_id in original_fray:
				if str(old_id) != hero_id:
					remaining_fray = remaining_fray and app._stitched_fray_carry.get(old_id) == original_fray[old_id]
			_check(not app._stitched_hp_carry.has(hero_id) and remaining \
				and not app._stitched_fray_carry.has(hero_id) and remaining_fray \
				and fresh_fray.get(spare_id) == {"fray": 0, "resolve": ""} \
				and app._stitched_rank_carry.is_empty() \
				and _rank_map(app._stitched_floor_config().get("heroes", [])) == canonical_ranks \
				and canonical_ranks.size() == 4 and app._stitched_party_picks.has(spare_id) \
				and not app._stitched_party_picks.has(hero_id),
				"confirmed reselection clears only deselected ID's wounded HP")
		picker.get_choice_buttons()[2].pressed.emit()
		await process_frame
		_check(app.stitched_event_panel == null and _no_wallet(app),
			"reselection Roadblock Leave spends no run resources")
	app.free()
	await process_frame
	return trace


## The actual Retreat UI also retires its battle authority without minting a
## victory, even though a legitimate retreat raises FRAY inside that battle.
func _retreat_no_carry() -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var stage: StitchedBattleScreen = await _admit(app)
	_check(stage != null and stage.battle != null and stage.battle.is_valid(),
		"retreat probe mounts an authentic title Roadblock")
	if stage != null and stage.battle != null:
		var attempt_count := 0
		while not stage.battle.is_over() and attempt_count < 8:
			if stage.battle.current_side() != "hero":
				break
			var action: Dictionary = stage.submit_retreat()
			_check(action.get("ok") == true and action.get("action") == "retreat",
				"retreat attempt comes from the mounted battle UI")
			attempt_count += 1
		_check(stage.battle.outcome() == "retreated" and attempt_count > 0,
			"seeded mounted retreat eventually ends without a victory")
		if stage.battle.outcome() == "retreated":
			var rules: StitchedRules = stage.battle
			var rng_before: int = rules.rng_state()
			stage._action_buttons["exit"].pressed.emit()
			await process_frame
			_check(app.stitched_fight_view == null and app.stitched_sewing_panel == null \
				and app._stitched_fray_carry.is_empty() \
				and app._stitched_hp_carry.is_empty() \
				and app._stitched_rank_carry.is_empty() \
				and app._stitched_bleed_carry.is_empty() \
				and app.stitched_preview_scraps == 0 and app.stitched_preview_gold == 0 \
				and rules.rng_state() == rng_before and _no_wallet(app),
				"real retreated exit cannot grant FRAY/HP/ranks/spoils or draw RNG at settlement")
	app.free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _retreat_no_carry()
	var one: Dictionary = await _trace()
	var two: Dictionary = await _trace()
	_check(not one.is_empty() and one == two,
		"two fresh identical public Roadblock/Victory/Leave/Fight traces reproduce same carried gear and opening")
	for failure in failures:
		printerr(failure)
	print("stitched_s6_torn_carry_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
