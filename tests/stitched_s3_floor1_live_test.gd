extends SceneTree
## S3 regression: normal title button -> mounted battle -> legal GUI actions -> title.
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)

func _spawn() -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	return app

func _legal_ability(stage: StitchedBattleScreen) -> bool:
	if stage.battle == null or stage.battle.current_side() != "hero":
		return false
	for slot in StitchedParts.SLOTS:
		if not stage.select_part(slot):
			continue
		for key in stage.legal_targets():
			var side := str(key).split("_")[0]
			var rank := int(str(key).split("_")[1])
			var before := stage.receipts.size()
			var result := stage.submit_target(side, rank)
			if bool(result.get("ok", false)):
				_check(stage.receipts.size() > before and str(stage.receipts[before].get("action")) == "ability",
					"legal part click delegates to the real authority and records a receipt")
				return true
	return false

func _terminal_trace(stage: StitchedBattleScreen) -> Dictionary:
	var started := stage.battle.state_snapshot()
	var started_rng := stage.battle.rng_state()
	var acted := 0
	var witnessed_foe := false
	# Take several sewn actions before the retreat, to prove the battle itself
	# progresses and drives its enemy AI rather than ending through fixture damage.
	for index in range(8):
		if stage.battle.is_over():
			break
		if stage.battle.current_side() != "hero":
			break
		if not _legal_ability(stage):
			var moved := stage.submit_move(-1) if stage._can_move(-1) else stage.submit_pass()
			_check(bool(moved.get("ok", false)), "fallback UI move/pass is a legal hero action")
		acted += 1
		for receipt in stage.receipts:
			var actor_id := str(receipt.get("actor", ""))
			var unit := stage.battle.get_unit(actor_id)
			if str(unit.get("side", "")) == "foe":
				witnessed_foe = true
	_check(acted > 0 and stage.receipts.size() >= acted and stage.battle.state_snapshot() != started,
		"live fight advances turns after actual hero part or movement actions")
	_check(witnessed_foe, "active foes take real ability/pass turns during the trace")
	var non_warden_move := false
	for receipt in stage.receipts:
		if str(receipt.get("action", "")) != "ability":
			continue
		var actor_id := str(receipt.get("actor", ""))
		if not actor_id in ["seamstress", "tinker", "lantern_monk"]:
			continue
		var unit: Dictionary = stage.battle.get_unit(actor_id)
		for slot in StitchedParts.SLOTS:
			var worn: Dictionary = unit.get("parts", {}).get(slot, {})
			var definition: Dictionary = stage.parts.get(str(worn.get("id", "")), {})
			if definition.is_empty():
				continue
			var ability := StitchedParts.ability_at_tier(definition, int(worn.get("tier", 0)))
			if definition.get("owner") == actor_id and ability.get("id") == receipt.get("ability"):
				non_warden_move = true
	_check(non_warden_move, "an authentic named non-Warden move commits through the mounted screen")
	_check(stage.battle.rng_state() != started_rng, "committed actions consume the seeded battle RNG")
	for step in range(80):
		if stage.battle.is_over():
			break
		if stage.battle.current_side() != "hero":
			break
		var receipt := stage.submit_retreat()
		_check(bool(receipt.get("ok", false)), "live retreat commits via the screen's legal handler")
	_check(stage.battle.is_over() and stage.battle.outcome() in ["retreated", "victory", "defeat"],
		"UI trace reaches a real terminal outcome, without fixture damage")
	_check(stage._labels["round"].text.contains(stage.battle.outcome().to_upper()) and
		stage._action_buttons["pass"].disabled,
		"terminal state is displayed and actions are disabled")
	return {"receipts":stage.receipts.duplicate(true),
		"snapshot":stage.battle.state_snapshot(), "outcome":stage.battle.outcome()}

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var warden := StitchedParts.load_catalog("res://data/parts/warden_parts.json")
	_check(bool(warden.get("ok", false)) and warden.get("by_id", {}).has("warden_head_pot_helm_bonk"),
		"Warden authored JSON loads with the canonical head starter")
	if not bool(warden.get("ok", false)):
		for failure in failures:
			printerr(failure)
		quit(1)
		return
	var ids: Dictionary = {}
	var slots: Dictionary = {}
	var expected := {
		"head":["warden_head_pot_helm_bonk","warden_head_helmet_rattle"],
		"arms":["warden_arms_shield_catch","warden_arms_rivet_pummel"],
		"torso":["warden_torso_iron_challenge","warden_torso_buckle_rebound"],
		"legs":["warden_legs_rim_toss","warden_legs_shield_toss"],
	}
	for slot in expected:
		slots[slot] = 0
	for part in warden["parts"]:
		var id := str(part["id"])
		_check(not ids.has(id), "Warden part IDs remain distinct: " + id)
		ids[id] = true
		_check(str(part["owner"]) == "warden" and str(part["slot"]) in StitchedParts.SLOTS,
			"authored part belongs to a matching Warden slot: " + id)
		slots[str(part["slot"])] += 1
		for tier in range(1, 4):
			var ability := StitchedParts.ability_at_tier(part, tier)
			var stat := StitchedParts.stat_at_tier(part, tier)
			_check(not ability.is_empty() and not stat.is_empty() and str(ability.get("name", "")) == str(part.get("name", "")) and
				str(ability.get("move", "")) in StitchedParts.MOVE_POSES and
				int(ability.get("launch_mask", 0)) != 0 and int(ability.get("target_mask", 0)) != 0 and
				StitchedParts.validate_ability(ability).get("ok", false),
				"tier %d has a named, rank-legal sewn move: %s" % [tier,id])
	for slot in expected:
		_check(ids.has(expected[slot][0]) and ids.has(expected[slot][1]),
			"the two required Warden part IDs are present for slot: " + slot)
	_check(not ids.has("warden_legs_iron_taunt"), "the retired Iron Taunt substitution is not in the Warden catalog")
	var shield_toss: Dictionary = {}
	for part in warden["parts"]:
		if str(part.get("id", "")) == "warden_legs_shield_toss":
			shield_toss = part
	_check(not shield_toss.is_empty() and str(shield_toss.get("name", "")) == "Shield Toss" and
		str(shield_toss.get("slot", "")) == "legs", "Shield Toss is the second real legs part")
	for tier in range(1, 4):
		var toss := StitchedParts.ability_at_tier(shield_toss, tier)
		var expected_damage: Array = [[5, 7], [6, 9], [8, 11]][tier - 1]
		_check(str(toss.get("name", "")) == "Shield Toss" and str(toss.get("kind", "")) == "ranged" and
			toss.get("launch", []) == [1, 2] and toss.get("target", []) == [1, 2, 3] and
			str(toss.get("target_side", "")) == "enemy" and toss.get("dmg", []) == expected_damage and
			int(toss.get("effects", {}).get("tangled", 0)) == (2 if tier == 3 else 1) and
			not toss.has("damage_equal_to_owner_block"),
			"tier %d Shield Toss is an independent fixed-damage ranged Stitched move" % tier)
	var replay: Dictionary = {}
	for repetition in range(2):
		var app := _spawn()
		await process_frame
		_check(app.stitched_fight_button != null and app.stitched_fight_button.is_visible_in_tree() and
			app.stitched_fight_button.focus_mode != Control.FOCUS_NONE and
			app.base_button.focus_next == app.base_button.get_path_to(app.stitched_fight_button),
			"ordinary title action is visible and keyboard reachable")
		var config: Dictionary = app._stitched_floor_config()
		var merged := StitchedParts.build_catalog(config.get("parts", []))
		_check(config.get("seed", 0) == 4982026 and config.get("heroes", []).size() == 4 and
			config.get("foes", []).size() == 3 and bool(merged.get("ok", false)) and
			merged.get("by_id", {}).has("scissor_crab_claw_arm") and
			merged.get("by_id", {}).has("moth_swarm_wings") and
			merged.get("by_id", {}).has("felt_bulwark_button_shield"),
			"Floor 01 uses the four-hero roster, three foes and all three validated foe parts")
		var invalid := config.duplicate(true)
		invalid["parts"].append(invalid["parts"][0].duplicate(true))
		var rejected_stage := StitchedBattleScreen.new()
		_check(not StitchedParts.build_catalog(invalid["parts"]).get("ok", true) and
			not rejected_stage.begin(invalid),
			"duplicate part IDs are refused before mounting the screen")
		rejected_stage.free()
		invalid = config.duplicate(true)
		invalid["parts"][0]["ability"]["launch"] = [0,5]
		_check(not StitchedParts.build_catalog(invalid["parts"]).get("ok", true),
			"malformed rank rules refuse an entire catalog")
		# A malformed mounted kit is rejected without a turn, receipt or global RNG draw.
		var malformed_kit: Dictionary = config.duplicate(true)
		malformed_kit["heroes"][1]["parts"]["head"] = {
			"id": "seamstress_mending_knot_hat", "tier": 4, "torn": false,
		}
		var rejected_kit := StitchedBattleScreen.new()
		seed(118277)
		var rejected_rng := randi()
		seed(118277)
		_check(not rejected_kit.begin(malformed_kit) and rejected_kit.battle == null
			and randi() == rejected_rng, "illegal starter tier refuses combat without drawing global RNG")
		rejected_kit.free()
		app._stitched_gear_overrides["tinker"] = {
			"head": {"id": "tinker_head_cog_shot", "tier": 4, "torn": false},
		}
		seed(118278)
		var carried_rng := randi()
		seed(118278)
		_check(app._stitched_floor_config().is_empty() and randi() == carried_rng,
			"malformed carried tier fails closed before a live battle or RNG draw")
		app._stitched_gear_overrides.clear()
		var global_seed := 204915
		seed(global_seed)
		var expected_global := randi()
		seed(global_seed)
		app.stitched_fight_button.pressed.emit()
		await process_frame
		var panel: LiveEventChoicePanel = app.stitched_event_panel
		_check(panel != null and panel.has_open_event() and panel.is_visible_in_tree() \
			and app.stitched_event_gate != null and app.stitched_event_gate.is_valid() \
			and not app.title_view.is_visible_in_tree(),
			"ordinary title opens the authentic Roadblock offer before any battle")
		if panel == null:
			app.free()
			continue
		var choices := panel.get_choice_buttons()
		_check(choices.size() == 3 and not choices[0].disabled and choices[1].disabled \
			and not choices[2].disabled and app.stitched_fight_view == null,
			"Roadblock Fight is available, the zero-wallet toll is disabled, and Leave is available")
		if choices.size() != 3:
			app.free()
			continue
		choices[0].pressed.emit()
		await process_frame
		var stage: StitchedBattleScreen = app.stitched_fight_view
		_check(stage != null and stage.is_visible_in_tree() and not app.title_view.is_visible_in_tree(),
			"clicking ordinary title control mounts Floor 01")
		if stage == null:
			app.free()
			continue
		_check(stage.battle != null and stage.battle.is_valid() and stage.battle.get_heroes().size() == 4 and
			stage.battle.get_foes().size() == 3 and stage._seat_buttons.size() == 8 and
			app.deck == null and app.run_map == null and app.run_rng == null and app.run_deck.is_empty(),
			"real 4v3 four-rank combat starts without a card battle resource")
		_check(randi() == expected_global, "new title fight never uses global RNG")
		var starter_ids := {
			"warden": {
				"head": "warden_head_pot_helm_bonk", "arms": "warden_arms_shield_catch",
				"torso": "warden_torso_iron_challenge", "legs": "warden_legs_rim_toss",
			},
			"seamstress": {
				"head": "seamstress_mending_knot_hat", "arms": "seamstress_thread_prick_needle",
				"torso": "seamstress_shielding_hem_coat", "legs": "seamstress_tether_loop_spools",
			},
			"tinker": {
				"head": "tinker_head_cog_shot", "arms": "tinker_arms_scrap_bomb",
				"torso": "tinker_torso_casing_ward", "legs": "tinker_legs_tune_up",
			},
			"lantern_monk": {
				"head": "lantern_monk_head_moth_wink", "arms": "lantern_monk_arms_wick_spark",
				"torso": "lantern_monk_torso_lamplight_wash", "legs": "lantern_monk_legs_pole_shelter",
			},
		}
		var equipped_ok := true
		for hero_id in starter_ids:
			var unit: Dictionary = stage.battle.get_unit(hero_id)
			var worn: Dictionary = unit.get("parts", {})
			equipped_ok = equipped_ok and unit.get("side") == "hero" and worn.size() == 4
			for slot in StitchedParts.SLOTS:
				var worn_part: Dictionary = worn.get(slot, {})
				var part_id := str(worn_part.get("id", ""))
				var definition: Dictionary = stage.parts.get(part_id, {})
				equipped_ok = equipped_ok and part_id == starter_ids[hero_id][slot] \
					and int(worn_part.get("tier", 0)) == 1 \
					and not bool(worn_part.get("torn", true)) \
					and not definition.is_empty() and definition.get("owner") == hero_id \
					and definition.get("slot") == slot
		_check(equipped_ok, "all four real heroes mount their own four validated tier-I parts")
		_check(stage.parts.has("any_head_needle_pin") and stage.parts.has("felt_bulwark_button_shield") \
			and not stage.parts.has("warden_head_iron_helm"),
			"generic compatibility and foe parts remain available, but retired prototypes do not")
		var snapshot := stage.battle.state_snapshot()
		var rng := stage.battle.rng_state()
		_check(not app._open_stitched_fight() and stage.battle.state_snapshot() == snapshot and
			stage.battle.rng_state() == rng, "repeated entry is refused without RNG/turn effects")
		var current := stage.battle.get_unit(stage.battle.current_actor_id())
		var acting_head := str(current.get("parts", {}).get("head", {}).get("id", ""))
		_check(stage.battle.current_side() == "hero" and not acting_head.is_empty() and
			not bool(stage.submit_part("retired_warden_part", 1).get("ok", false)) and
			not bool(stage.submit_target("foe", 5).get("ok", false)) and
			not bool(stage.submit_part(acting_head, 4).get("ok", false)) and
			not bool(stage.submit_move(0).get("ok", false)) and
			not bool(stage.submit_re_tie().get("ok", false)),
			"invalid IDs, wrong rank, illegal movement, uncut Re-tie fail closed")
		_check(stage.battle.state_snapshot() == snapshot and stage.battle.rng_state() == rng,
			"invalid actions consume no time or RNG")
		if stage.battle.current_side() == "hero":
			var actor_id := stage.battle.current_actor_id()
			var actor: Dictionary = stage.battle._units[actor_id]
			var first := str(actor["parts"]["head"]["id"])
			actor["parts"]["head"]["torn"] = true
			var before := stage.battle.state_snapshot()
			var before_rng := stage.battle.rng_state()
			_check(not stage.select_part("head") and not bool(stage.submit_part(first, 1).get("ok", false)) and
				stage.battle.state_snapshot() == before and stage.battle.rng_state() == before_rng,
				"torn equipment cannot act or spend RNG")
			actor["parts"]["head"]["torn"] = false
			stage._refresh()
		var trace := _terminal_trace(stage)
		if repetition == 0:
			replay = trace
		else:
			_check(trace == replay, "independent equal-seed title fights replay exact receipts, state and outcome")
		var old_stage := stage
		stage._action_buttons["exit"].pressed.emit()
		# The outgoing scene remains alive until queue_free's frame boundary.
		_check(not bool(old_stage.submit_pass().get("ok", false)) and
			not bool(old_stage.submit_target("foe", 1).get("ok", false)),
			"stale controls cannot mutate a closed battle")
		await process_frame
		_check(not is_instance_valid(old_stage) and app.stitched_fight_view == null and
			app.title_view.is_visible_in_tree() and app.deck == null and app.run_map == null,
			"Back frees the battle and restores a clean title")
		app.free()
		await process_frame
	var preview := StitchedBattleScreen.new()
	_check(preview.begin() and preview.battle.get_heroes().size() == 4 and
		preview.battle.get_foes().size() == 3,
		"unchanged S2 preview remains a valid independent fight")
	preview.free()
	for failure in failures:
		printerr(failure)
	print("stitched_s3_floor1_live_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
