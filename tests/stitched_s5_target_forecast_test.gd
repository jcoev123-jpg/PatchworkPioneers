extends SceneTree
## Live S5 target forecast regression: public S2 entry plus valid synthetic part variants.
const BOOT := preload("res://scripts/live_web_playtest_boot.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)

func _choose_foe_part(stage: StitchedBattleScreen) -> String:
	for slot in StitchedBattleScreen.SLOTS:
		if not stage.select_part(slot):
			continue
		var n := 0
		for key in stage.legal_targets():
			if str(key).begins_with("foe_"):
				n += 1
		if n >= 2:
			return slot
	return ""

func _ability(stage: StitchedBattleScreen, slot: String) -> Dictionary:
	var hero := stage.battle.get_unit(stage.battle.current_actor_id())
	var equipped: Dictionary = hero["parts"].get(slot, {})
	if equipped.is_empty():
		return {}
	return StitchedParts.ability_at_tier(stage.parts[str(equipped["id"])], int(equipped["tier"]))

func _expected(actor: Dictionary, ability: Dictionary, target: Dictionary, endpoint: int) -> int:
	var base := endpoint + int(actor.get("dmg_bonus", 0))
	if str(actor.get("resolve", "")) == "steadfast":
		base = StitchedS1BEffects.steadfast_damage(base)
	return StitchedRules.damage_after_modifiers(
		base, actor.get("statuses", {}), target.get("statuses", {}),
		int(target.get("statuses", {}).get("mark", 0)) > 0,
		int(ability.get("mark_damage", 0)), int(target.get("prot", 0))
	)

func _synthetic_config(part_id: String, kind: String, side: String, multi: bool, effects: Dictionary,
	damage: Array = [0, 0], mark_bonus: int = 0) -> Dictionary:
	var data := StitchedBattleScreen.read_preview().duplicate(true)
	var found := false
	for part in data["parts"]:
		if str(part["id"]) != part_id:
			continue
		found = true
		var ability: Dictionary = part["ability"]
		ability["kind"] = kind
		ability["target_side"] = side
		ability["multi"] = multi
		ability["launch"] = [1, 2, 3, 4]
		ability["target"] = [1, 2, 3, 4]
		ability["dmg"] = damage.duplicate()
		ability["mark_damage"] = mark_bonus
		ability["acc"] = 100
		ability["crit"] = 0
		ability["self_move"] = 0
		ability["effects"] = effects
		part["tiers"] = {}
	_check(found, "fixture part exists in authentic source catalog")
	return data

func _mount_config(data: Dictionary) -> StitchedBattleScreen:
	var stage := StitchedBattleScreen.new()
	_check(stage.begin(data), "synthetic part payload validates through the real S2 battle factory")
	if stage.battle == null:
		stage.free()
		return null
	root.add_child(stage)
	await process_frame
	_check(stage.is_visible_in_tree() and stage.battle.current_side() == "hero", "synthetic mounted stage reaches a lawful live hero turn")
	return stage

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var boot := root.get_node_or_null("LiveWebPlaytestBoot")
	_check(boot != null and BOOT.SCREENS.has("stitched_battle"), "public mounted Stitched entry exists")
	if boot == null:
		_finish()
		return
	_check(await boot.enter_preview(app, "stitched_battle"), "public live battle entrance works")
	var stage: StitchedBattleScreen = boot.stitched_view
	if stage == null or stage.battle == null:
		_finish()
		return
	await process_frame
	var battle := stage.battle
	_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3
		and stage._seat_buttons.size() == 8 and stage._target_buttons.size() == 8,
		"non-vacuous authentic seeded 4v3 mounted screen with all rank buttons")
	_check(stage._labels["preview"].size.x == 749 and stage._labels["preview"].position.y == 613
		and stage._labels["preview"].position.y + stage._labels["preview"].size.y
			<= stage._action_buttons["move_front"].position.y
		and stage._action_buttons["move_front"].position.y >= 642
		and stage._turn_ribbon != null and stage._labels["log"] != null,
		"1280x720 compact forecast remains above movement actions, with turn-order ribbon present")
	var slot := _choose_foe_part(stage)
	_check(not slot.is_empty(), "authentic acting hero has a real part covering two legal foe ranks")
	if slot.is_empty():
		app.free()
		_finish()
		return
	var actor_id := battle.current_actor_id()
	var actor: Dictionary = battle._units[actor_id]
	var ability := _ability(stage, slot)
	var keys: Array[String] = []
	for key in stage.legal_targets():
		if str(key).begins_with("foe_"):
			keys.append(str(key))
	keys.sort()
	_check(keys.size() >= 2 and not ability.is_empty(), "two distinct actual legal target ranks are present")
	if keys.size() < 2:
		app.free()
		_finish()
		return
	var all_units := battle._units.duplicate(true)
	var all_heaps := battle._heaps.duplicate(true)
	var a_rank := int(keys[0].split("_")[1])
	var b_rank := int(keys[1].split("_")[1])
	var a := stage._unit_at("foe", a_rank)
	var b := stage._unit_at("foe", b_rank)
	_check(not a.is_empty() and not b.is_empty() and str(a["id"]) != str(b["id"]),
		"two living distinct foes really occupy each legal seat")
	# Independently exercise clamped hit, Dodge buff, Mark, Weak+Exposed,
	# Tangled, PROT cap, part damage bonus and Steadfast on real unit dictionaries.
	actor["miss_streak"] = 2
	actor["resolve"] = "steadfast"
	actor["statuses"] = {"weak": 2}
	a["dodge"] = 9
	a["dodge_buff"] = {"amount": 27, "turns": 2, "skip": false}
	a["prot"] = 15
	a["statuses"] = {"mark": 2, "exposed": 1, "tangled": 1}
	b["dodge"] = 24
	b["dodge_buff"] = {"amount": 10, "turns": 2, "skip": false}
	b["prot"] = 120
	b["statuses"] = {"exposed": 1}
	stage._refresh()
	var snapshot := battle.state_snapshot()
	var rng := battle.rng_state()
	var receipt_count := stage.receipts.size()
	var global_seed := 827361
	seed(global_seed)
	var expected_global := randi()
	seed(global_seed)
	var rows: Array[Dictionary] = []
	for key in keys.slice(0, 2):
		var rank := int(key.split("_")[1])
		var target := stage._unit_at("foe", rank)
		var expected_hit := StitchedRules.hit_chance(
			int(ability["acc"]) + int(actor["acc"]), StitchedRules.effective_dodge(target), int(actor["miss_streak"]))
		var low := _expected(actor, ability, target, int(ability["dmg"][0]))
		var high := _expected(actor, ability, target, int(ability["dmg"][1]))
		var crit := _expected(actor, ability, target, StitchedRules.crit_damage(int(ability["dmg"][1])))
		stage._seat_buttons[key].mouse_entered.emit()
		var actual := StitchedTargetForecast.for_rank(battle, actor, ability, "foe", rank)
		_check(actual.get("targets", []).size() == 1 and int(actual["targets"][0]["rank"]) == rank
			and actual["targets"][0]["name"] == target["name"]
			and int(actual["targets"][0]["hit"]) == expected_hit
			and int(actual["targets"][0]["noncrit_min"]) == low
			and int(actual["targets"][0]["noncrit_max"]) == high
			and int(actual["targets"][0]["crit_damage"]) == crit
			and int(actual["targets"][0]["crit_chance"]) == StitchedRules.CRIT_BASE + int(ability["crit"]) + int(actor["crit"]),
			"rank %d uses independent StitchedRules effective Dodge and post-modifier NON-CRIT bounds" % rank)
		_check(stage._labels["preview"].text.contains(str(target["name"]))
			and stage._labels["preview"].text.contains("HIT %d%%" % expected_hit)
			and stage._labels["preview"].text.contains("NON-CRIT %d–%d" % [low, high])
			and stage._labels["preview"].text.contains("CRIT")
			and stage._labels["log"].text == stage.status_detail("foe", rank)
			and stage._seat_buttons[key].tooltip_text.contains("STATUS:")
			and stage._seat_buttons[key].tooltip_text.contains("NON-CRIT")
			and stage._target_buttons[key].tooltip_text.contains("HIT"),
			"hover %s preserves exact STATUS side log, adds accurate preview and two tooltips" % key)
		rows.append(actual)
		stage._seat_buttons[key].mouse_exited.emit()
		_check(not stage._labels["preview"].text.contains("NON-CRIT")
			and stage._labels["preview"].tooltip_text.is_empty()
			and not stage._seat_buttons[key].tooltip_text.contains("NON-CRIT"),
			"mouse exit removes actionable forecast and tooltip, leaving the part's generic preview")
	_check(int(rows[0]["targets"][0]["hit"]) != int(rows[1]["targets"][0]["hit"])
		and int(rows[0]["targets"][0]["noncrit_max"]) != int(rows[1]["targets"][0]["noncrit_max"]),
		"two actual foe ranks yield distinct hit odds and post-PROT damage")
	var focused_key := keys[1]
	stage._target_buttons[focused_key].grab_focus()
	_check(stage._target_buttons[focused_key].has_focus()
		and stage._labels["preview"].text.contains(str(b["name"]))
		and stage._labels["log"].text == stage.status_detail("foe", b_rank),
		"keyboard focus on bottom target button uses chosen rank and preserves status log")
	stage._action_buttons["pass"].grab_focus()
	_check(not stage._labels["preview"].text.contains("NON-CRIT"),
		"focus exits restore generic part preview")
	# A detached result cannot be used to edit future projections.
	rows[0]["targets"][0]["hit"] = 999
	_check(int(StitchedTargetForecast.for_rank(battle, actor, ability, "foe", a_rank)["targets"][0]["hit"]) != 999,
		"forecast rows are independently detached presentation data")
	stage._refresh()
	_check(battle.state_snapshot() == snapshot and battle.rng_state() == rng
		and stage.receipts.size() == receipt_count and randi() == expected_global,
		"hover/focus/refresh/tooltip probes preserve snapshot, seeded/global RNG and receipts")
	# Blind is a warning, never a fictional guaranteed hit.
	actor["statuses"]["blind"] = 1
	stage._refresh()
	stage._seat_buttons[keys[0]].mouse_entered.emit()
	_check(stage._labels["preview"].text.contains("BLIND: next attack misses"),
		"blind enemy-target preview warns that the next attack is forced to miss")
	stage._seat_buttons[keys[0]].mouse_exited.emit()
	actor["statuses"].erase("blind")
	# Defensive refusal of dead, heap, empty, torn and self-move-blocked seats.
	_check(StitchedTargetForecast.for_rank(battle, actor, ability, "foe", 4).is_empty()
		and StitchedTargetForecast.for_rank(battle, actor, ability, "foe", 0).is_empty()
		and StitchedTargetForecast.for_rank(battle, actor, ability, "foe", 5).is_empty()
		and StitchedTargetForecast.for_rank(battle, actor, ability, "hero", a_rank).is_empty(),
		"empty, wrong-side and out-of-range seats cannot invent an actionable target")
	battle._heaps.append({"id": "heap:test", "rank": 4, "hp": 10, "max_hp": 10, "side": "heap"})
	stage._refresh()
	_check(StitchedTargetForecast.for_rank(battle, actor, ability, "foe", 4).is_empty()
		and not stage.legal_targets().has("foe_4"), "scrap heap is never forecast as a living enemy")
	battle._heaps = all_heaps.duplicate(true)
	a["dead"] = true
	a["hp"] = 0
	stage._refresh()
	_check(not stage.legal_targets().has(keys[0])
		and StitchedTargetForecast.for_rank(battle, actor, ability, "foe", a_rank).is_empty(),
		"dead foe is not targetable, even with an occupied heap rank")
	a["dead"] = false
	a["hp"] = int(all_units[str(a["id"])]["hp"])
	var equipped: Dictionary = actor["parts"][slot]
	equipped["torn"] = true
	stage._refresh()
	stage._seat_buttons[keys[0]].mouse_entered.emit()
	_check(stage._selected_part.is_empty() and not stage.legal_targets().has(keys[0])
		and not stage._labels["preview"].text.contains("NON-CRIT"),
		"torn part clears selection and actionable hover immediately")
	stage._seat_buttons[keys[0]].mouse_exited.emit()
	# Full fixture restore before comparing the actual receipt with the last chosen-rank preview.
	battle._units = all_units.duplicate(true)
	battle._heaps = all_heaps.duplicate(true)
	stage._refresh()
	_check(stage.select_part(slot), "restored part can be selected for authoritative real play")
	var real_actor := battle.get_unit(battle.current_actor_id())
	var real_ability := _ability(stage, slot)
	var rank_receipt := int(keys[0].split("_")[1])
	var expected_receipt := StitchedTargetForecast.for_rank(battle, real_actor, real_ability, "foe", rank_receipt)
	_check(not expected_receipt.is_empty(), "unchanged legal chosen rank produces a nonempty receipt forecast")
	var before_commit := stage.receipts.size()
	stage._target_buttons[keys[0]].mouse_entered.emit()
	_check(stage._labels["preview"].text.contains("HIT %d%%" % int(expected_receipt["targets"][0]["hit"])),
		"live chosen-rank UI shows the exact pre-commit hit chance")
	var receipt := stage.submit_target("foe", rank_receipt)
	_check(bool(receipt.get("ok", false)) and receipt.get("results", []).size() == 1
		and stage.receipts.size() > before_commit
		and receipt["results"][0].get("target") == expected_receipt["targets"][0]["id"]
		and int(receipt["results"][0].get("hit_chance", -1)) == int(expected_receipt["targets"][0]["hit"]),
		"actual StitchedRules.use_part receipt agrees with selected target's forecast and commits once")
	_check(stage._selected_part.is_empty() and not stage._labels["preview"].text.contains("NON-CRIT"),
		"successful turn clears stale target forecast")
	boot.exit_stitched_preview(app)
	await process_frame
	app.free()

	# Second VALID synthetic S2 battle: multi-target ally heals (no attack roll).
	var part_id := str(all_units[actor_id]["parts"][slot]["id"])
	var multi_stage: StitchedBattleScreen = await _mount_config(
		_synthetic_config(part_id, "heal", "ally", true, {"heal": 7}))
	if multi_stage != null:
		var multi_b := multi_stage.battle
		var multi_actor := multi_b.get_unit(multi_b.current_actor_id())
		_check(multi_stage.select_part(slot), "synthetic ally multi heal is usable from real hero rank")
		var multi_rank := int(multi_actor["rank"])
		var multi_ability := _ability(multi_stage, slot)
		var authority: Array = multi_b._legal_targets(multi_actor, multi_ability, multi_rank)
		_check(authority.size() >= 3 and authority.size() == multi_b.get_heroes().size(),
			"valid multi heal covers at least three distinct real allies, including the actor")
		if authority.size() >= 3:
			# Set three distinct, lawful recipients to full, partially injured and
			# Hanging. Keep the current actor at full HP so its turn stays ordinary.
			var full_id := str(multi_actor["id"])
			var other_ids: Array[String] = []
			for target in authority:
				if str(target["id"]) != full_id:
					other_ids.append(str(target["id"]))
			_check(other_ids.size() >= 2, "two other lawful allies exist for injury and Hanging")
			if other_ids.size() >= 2:
				var partial_id := other_ids[0]
				var hanging_id := other_ids[1]
				for target in authority:
					var live: Dictionary = multi_b._units[str(target["id"])]
					live["hp"] = int(live["max_hp"])
					live["hanging"] = false
				multi_b._units[partial_id]["hp"] = int(multi_b._units[partial_id]["max_hp"]) - 3
				multi_b._units[hanging_id]["hp"] = 0
				multi_b._units[hanging_id]["hanging"] = true
				# A temporarily low maximum is a legal current-state projection:
				# prove the authored +7 is capped even when Hanging starts at 0 HP.
				var hanging_unit: Dictionary = multi_b._units[hanging_id]
				var original_max_hp := int(hanging_unit["max_hp"])
				hanging_unit["max_hp"] = 4
				multi_stage._refresh()
				var capped_preview := StitchedTargetForecast.for_rank(
					multi_b, multi_actor, multi_ability, "hero", multi_rank)
				var capped_found := false
				for row in capped_preview.get("targets", []):
					if str(row["id"]) == hanging_id:
						capped_found = int(row.get("heal_amount", -1)) == 4 \
							and int(row.get("hp_after", -1)) == 4 \
							and bool(row.get("hanging_before", false)) \
							and not bool(row.get("hanging_after", true))
				_check(capped_found and str(capped_preview.get("text", "")).contains("HEAL +7")
					and str(capped_preview.get("text", "")).contains("+4 HP → 4/4"),
					"0-HP Hanging doll with live max HP below authored +7 forecasts only capped +4")
				_check(int(hanging_unit["hp"]) == 0 and bool(hanging_unit["hanging"]),
					"capped read-only projection does not actually rescue the Hanging target")
				hanging_unit["max_hp"] = original_max_hp
				# A LOST doll is absent from the authoritative mask even if its
				# remembered rank remains occupied in the units dictionary.
				var lost_unit: Dictionary = multi_b._units[partial_id]
				lost_unit["lost"] = true
				multi_stage._refresh()
				var lost_rank := int(lost_unit["rank"])
				var lost_key := "hero_" + str(lost_rank)
				_check(not multi_stage.legal_targets().has(lost_key)
					and StitchedTargetForecast.for_rank(
						multi_b, multi_actor, multi_ability, "hero", lost_rank).is_empty(),
					"lost allied seat is inactionable and cannot receive invented healing")
				lost_unit["lost"] = false
				multi_stage._refresh()
				var selected_key := "hero_" + str(multi_rank)
				var multi_legal := multi_stage.legal_targets().duplicate(true)
				var multi_state := multi_b.state_snapshot()
				var multi_rng := multi_b.rng_state()
				var multi_receipts := multi_stage.receipts.size()
				var multi_round := multi_b.round_number()
				var multi_part := multi_stage._selected_part
				var multi_actor_id := multi_b.current_actor_id()
				var global_heal_seed := 628173
				seed(global_heal_seed)
				var expected_global_heal := randi()
				seed(global_heal_seed)
				var multi := StitchedTargetForecast.for_rank(
					multi_b, multi_actor, multi_ability, "hero", multi_rank)
				_check(multi_legal.has(selected_key) and multi.get("targets", []).size() == authority.size()
					and multi_part == slot, "multi forecast follows mounted selection and exact legal target membership")
				multi_stage._seat_buttons[selected_key].mouse_entered.emit()
				var concise: String = multi_stage._labels["preview"].text
				var hover_detail: String = multi_stage._seat_buttons[selected_key].tooltip_text
				_check(concise.contains("HEAL +7") and concise.contains("NO HIT ROLL")
					and not concise.contains("HIT %") and not concise.contains("NON-CRIT 0"),
					"compact healing preview retains authored effect, no-hit semantics, and no misleading attack metrics")
				if multi.get("targets", []).size() == authority.size():
					for i in range(authority.size()):
						var ally: Dictionary = authority[i]
						var row: Dictionary = multi["targets"][i]
						var before := int(ally["hp"])
						var maximum := int(ally["max_hp"])
						var after := mini(maximum, before + 7)
						var effective := after - before
						var hanging_before := bool(ally["hanging"])
						var hanging_after := hanging_before if after <= 0 else false
						_check(row["id"] == ally["id"] and row["name"] == ally["name"]
							and row["rank"] == ally["rank"] and row["side"] == "hero"
							and int(row.get("heal_amount", -1)) == effective
							and int(row.get("hp_before", -1)) == before
							and int(row.get("hp_after", -1)) == after
							and int(row.get("max_hp", -1)) == maximum
							and row.get("hanging_before", null) == hanging_before
							and row.get("hanging_after", null) == hanging_after
							and not row.has("hit_chance"),
							"rank %d %s has own exact detached capped HP and Hanging projection" % [ally["rank"], ally["name"]])
						_check(concise.contains("R%d %s +%d HP → %d/%d" % [
								int(ally["rank"]), str(ally["name"]), effective, after, maximum])
							and hover_detail.contains("R%d %s" % [int(ally["rank"]), str(ally["name"])])
							and hover_detail.contains("HP %d/%d → %d/%d · RESTORED +%d HP" % [
								before, maximum, after, maximum, effective])
							and hover_detail.contains("HANGING %s → %s" % [
								"yes" if hanging_before else "no", "yes" if hanging_after else "no"]),
							"live hover summary and complete tooltip name rank %d with before/after and Hanging" % ally["rank"])
					_check(int(multi["targets"][0].get("heal_amount", -1)) >= 0,
						"multi healing rows are typed nonnegative projections")
					var by_id: Dictionary = {}
					for row in multi["targets"]:
						by_id[str(row["id"])] = row
					_check(int(by_id[full_id]["heal_amount"]) == 0
						and int(by_id[partial_id]["heal_amount"]) == 3
						and int(by_id[hanging_id]["heal_amount"]) == mini(7, int(multi_b._units[hanging_id]["max_hp"]))
						and bool(by_id[hanging_id]["hanging_before"])
						and not bool(by_id[hanging_id]["hanging_after"])
						and concise.contains("HANGING ENDS"),
						"full, missing-three and zero-HP Hanging cases project 0, 3 and capped 7 restored HP")
					_check(multi_stage._labels["preview"].get_visible_line_count() <= 3,
						"four-ally healing summary fits the existing three-line 1280x720 preview")
					multi_stage._seat_buttons[selected_key].mouse_exited.emit()
					multi_stage._target_buttons[selected_key].grab_focus()
					var focus_detail: String = multi_stage._target_buttons[selected_key].tooltip_text
					_check(multi_stage._target_buttons[selected_key].has_focus()
						and multi_stage._labels["preview"].text.contains("HEAL +7")
						and focus_detail.contains("HANGING yes → no")
						and focus_detail.contains("RESTORED +0 HP")
						and focus_detail.contains("RESTORED +3 HP"),
						"keyboard focus gives full untruncated per-ally healing tooltip")
					multi_stage._action_buttons["pass"].grab_focus()
					for target in authority:
						if int(target["rank"]) != multi_rank:
							var other_key := "hero_" + str(target["rank"])
							multi_stage._seat_buttons[other_key].mouse_entered.emit()
							_check(multi_stage._labels["preview"].text.contains("HEAL +7")
								and multi_stage._labels["preview"].text.contains(str(target["name"])),
								"inspecting different lawful ally rank preserves multi-heal details")
							multi_stage._seat_buttons[other_key].mouse_exited.emit()
					multi_stage._refresh()
					_check(multi_b.state_snapshot() == multi_state and multi_b.rng_state() == multi_rng
						and multi_b.current_actor_id() == multi_actor_id
						and multi_b.round_number() == multi_round
						and multi_stage._selected_part == multi_part
						and multi_stage.legal_targets() == multi_legal
						and multi_stage.receipts.size() == multi_receipts
						and randi() == expected_global_heal,
						"hover, focus, changing inspected ally and refresh preserve units, actor, masks, receipts and both RNGs")
					# Submit this real mounted legal turn and match EACH status receipt
					# to the prior projection; the only HP writes belong to use_part.
					var healed_receipt := multi_stage.submit_target("hero", multi_rank)
					_check(bool(healed_receipt.get("ok", false))
						and healed_receipt.get("results", []).size() == authority.size()
						and multi_stage.receipts.size() > multi_receipts,
						"real legal multi-heal commits once through mounted StitchedRules action")
					if healed_receipt.get("results", []).size() == authority.size():
						for row in multi["targets"]:
							var found_receipt: Dictionary = {}
							for result in healed_receipt["results"]:
								if str(result["target"]) == str(row["id"]):
									found_receipt = result
							var effect_amount := -1
							for status in found_receipt.get("statuses", []):
								if str(status.get("status", "")) == "heal":
									effect_amount = int(status.get("amount", -1))
							var healed := multi_b.get_unit(str(row["id"]))
							_check(not found_receipt.is_empty() and effect_amount == int(row["heal_amount"])
								and int(healed["hp"]) == int(row["hp_after"])
								and bool(healed["hanging"]) == bool(row["hanging_after"]),
								"actual heal receipt for %s equals prior effective forecast and post-commit HP" % row["name"])
		multi_stage.free()
	# A separate valid multi ENEMY attack must project each foe's unique hit and
	# modifier-adjusted damage; an ally heal cannot prove that property.
	var strike_stage: StitchedBattleScreen = await _mount_config(
		_synthetic_config(part_id, "melee", "enemy", true, {"mark": 1}, [3, 6], 5))
	if strike_stage != null:
		var strike_b := strike_stage.battle
		var strike_actor := strike_b.get_unit(strike_b.current_actor_id())
		strike_actor["statuses"] = {"weak": 1}
		strike_actor["resolve"] = "steadfast"
		var foe_one := strike_stage._unit_at("foe", 1)
		var foe_two := strike_stage._unit_at("foe", 2)
		_check(not foe_one.is_empty() and not foe_two.is_empty(), "multi enemy fixture has two living foe seats")
		foe_one["statuses"] = {"mark": 1, "exposed": 1, "tangled": 1}
		foe_one["prot"] = 99
		foe_one["dodge_buff"] = {"amount": 18, "turns": 2, "skip": false}
		foe_two["statuses"] = {}
		foe_two["prot"] = 0
		foe_two["dodge_buff"] = {}
		strike_stage._refresh()
		_check(strike_stage.select_part(slot), "multi enemy strike is legal at the authentic acting hero rank")
		var strike_ability := _ability(strike_stage, slot)
		var strike_group: Array = strike_b._legal_targets(strike_actor, strike_ability, 1)
		var strike := StitchedTargetForecast.for_rank(strike_b, strike_actor, strike_ability, "foe", 1)
		_check(strike_group.size() >= 2 and strike.get("targets", []).size() == strike_group.size(),
			"multi enemy forecast enumerates all authoritative enemy units")
		strike_stage._target_buttons["foe_1"].mouse_entered.emit()
		for i in range(strike_group.size()):
			var foe: Dictionary = strike_group[i]
			var row: Dictionary = strike["targets"][i]
			var odds := StitchedRules.hit_chance(
				int(strike_ability["acc"]) + int(strike_actor["acc"]),
				StitchedRules.effective_dodge(foe), int(strike_actor["miss_streak"]))
			_check(row["id"] == foe["id"] and int(row["hit"]) == odds
				and int(row["noncrit_min"]) == _expected(strike_actor, strike_ability, foe, 3)
				and int(row["noncrit_max"]) == _expected(strike_actor, strike_ability, foe, 6)
				and strike_stage._labels["preview"].text.contains(str(foe["name"])),
				"multi enemy foe %s has independent hit, capped PROT, mark and damage" % foe["name"])
		_check(strike_stage._labels["preview"].get_visible_line_count() <= 3,
			"multi-target rank forecast fits three 14px text lines above bottom buttons")
		_check(StitchedTargetForecast.for_rank(strike_b, strike_actor, strike_ability, "foe", 4).is_empty(),
			"multi attack cannot offer an actionable empty fourth rank")
		strike_stage._target_buttons["foe_1"].mouse_exited.emit()
		strike_stage.free()
	# Third VALID synthetic variant: self-only Dodge support; blocked self_move gate.
	var self_stage: StitchedBattleScreen = await _mount_config(
		_synthetic_config(part_id, "buff", "self", false, {"dodge": 12, "duration": 2}))
	if self_stage != null:
		var self_b := self_stage.battle
		var self_actor := self_b.get_unit(self_b.current_actor_id())
		_check(self_stage.select_part(slot), "synthetic self-only buff has a legal button")
		var self_rank := int(self_actor["rank"])
		var self_ability := _ability(self_stage, slot)
		var self_data := StitchedTargetForecast.for_rank(self_b, self_actor, self_ability, "hero", self_rank)
		_check(self_data.get("targets", []).size() == 1 and str(self_data.get("text", "")).contains("NO HIT ROLL")
			and str(self_data.get("text", "")).contains("DODGE +12 / 2 turns"),
			"self buff accurately labels Dodge duration with no invented HIT")
		self_actor["statuses"]["tangled"] = 1
		self_stage.parts[part_id]["ability"]["self_move"] = 1
		self_ability = _ability(self_stage, slot)
		_check(not self_b._self_move_gate(self_actor, self_ability).is_empty()
			and StitchedTargetForecast.for_rank(self_b, self_actor, self_ability, "hero", self_rank).is_empty(),
			"mandatory self_move refusal blocks an otherwise legal forecast")
		self_stage._refresh()
		self_stage._seat_buttons["hero_" + str(self_rank)].mouse_entered.emit()
		_check(self_stage._selected_part.is_empty() and not self_stage.legal_targets().has("hero_" + str(self_rank))
			and not self_stage._labels["preview"].text.contains("NO HIT ROLL"),
			"blocked mandatory movement clears the mounted selection, mask and readout")
		self_stage.free()
	_finish()

func _finish() -> void:
	for issue in failures:
		printerr(issue)
	print("stitched_s5_target_forecast_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
