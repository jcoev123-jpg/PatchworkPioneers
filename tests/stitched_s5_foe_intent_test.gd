extends SceneTree
## Mounted StitchedS5 foe-choice projection, using the SAME S2 public battle and live stage.
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _mount(config: Dictionary = {}) -> Dictionary:
	var host := Control.new()
	host.name = "GothicFoeIntentHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var stage := StitchedBattleScreen.new()
	var data := config if not config.is_empty() else StitchedBattleScreen.read_preview()
	_check(stage.begin(data), "valid seeded battle starts through actual StitchedBattleScreen.begin")
	host.add_child(stage)
	return {"host": host, "stage": stage}


# Independent statement of the PRE-EXTRACTION live priority, not an echo of
# the production helper: same wraparound ability loop and first legal rank.
func _old_priority(battle: StitchedRules, actor: Dictionary) -> Dictionary:
	var abilities: Array = actor.get("abilities", [])
	var offset := (battle.round_number() - 1) % maxi(1, abilities.size())
	for step in range(abilities.size()):
		var ability: Dictionary = abilities[(offset + step) % abilities.size()]
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor["rank"])) or not battle._self_move_gate(actor, ability).is_empty():
			continue
		for rank in range(1, 5):
			var targets := battle._legal_targets(actor, ability, rank)
			if not targets.is_empty():
				var affected: Array[int] = []
				for target in targets:
					if not affected.has(int(target["rank"])):
						affected.append(int(target["rank"]))
				affected.sort()
				return {"ability_id": str(ability["id"]), "target_rank": rank,
					"target_side": str(targets[0]["side"]), "affected_ranks": affected,
					"multi": bool(ability["multi"])}
	return {"pass": true}


func _verify_tickets(stage: StitchedBattleScreen) -> void:
	var battle := stage.battle
	var found := 0
	for rank in range(1, 5):
		var foe := stage._unit_at("foe", rank)
		var ticket: NinePatchRect = stage._foe_tickets[rank]
		if foe.is_empty():
			_check(not ticket.visible and not stage._foe_intents.has(rank),
				"empty, fallen or heap rank %d has no misleading ticket" % rank)
			continue
		found += 1
		var expected := _old_priority(battle, foe)
		var intent := StitchedFoeIntent.choose(battle, foe)
		_check(ticket.visible and not intent.is_empty() and stage._foe_intents[rank] == intent,
			"live rank %d displays the authoritative, detached chooser" % rank)
		if expected.has("pass"):
			_check(bool(intent.get("pass", false)) or bool(intent.get("stun", false)),
				"unlaunchable foe rank %d shows PASS or STUN" % rank)
		else:
			_check(not bool(intent.get("pass", true)) and str(intent["ability_id"]) == str(expected["ability_id"])
				and int(intent["target_rank"]) == int(expected["target_rank"])
				and str(intent["target_side"]) == str(expected["target_side"])
				and intent["affected_ranks"] == expected["affected_ranks"]
				and bool(intent["multi"]) == bool(expected["multi"]),
				"rank %d matches independent round-rotated legal choice, target and all targets" % rank)
		_check(ticket.tooltip_text.contains(str(foe["name"])) and
			ticket.tooltip_text.contains("Current intent; may change if ranks or statuses change"),
			"foe rank %d names actual actor and provisionality" % rank)
	_check(found >= 2, "non-vacuous: mounted battle has at least two visible living foe tickets")


func _check_geometry(stage: StitchedBattleScreen) -> void:
	var authored: Texture2D = load("res://assets/paper/ui/hud_name_plate.png")
	_check(authored != null and stage._foe_tickets.size() == 4 and stage._foe_ticket_labels.size() == 4,
		"four rank tickets reuse an actual imported sewn HUD plate")
	for rank in range(1, 5):
		var ticket: NinePatchRect = stage._foe_tickets[rank]
		var rectangle := ticket.get_global_rect()
		var puppet: Rect2 = stage._puppets["foe_" + str(rank)].get_global_rect()
		_check(ticket.texture == authored and ticket.focus_mode == Control.FOCUS_ALL
			and rectangle.position == Vector2(646 + (rank - 1) * 126, 150)
			and rectangle.size == Vector2(116, 38) and rectangle.end.y <= puppet.position.y
			and rectangle.position.y > 145 and rectangle.end.y < 447
			and rectangle.end.x <= 1280 and stage._foe_ticket_labels[rank].get_parent() == ticket,
			"authored plate rank %d remains focusable above puppet and below rank header" % rank)
	var detail := stage._intent_disclosure.get_global_rect()
	_check(detail.position == Vector2(22, 148) and detail.end.y < 194 and detail.end.x <= 640,
		"two-line focus disclosure stays to the left of foes and clear of puppet faces")
	# Godot's headless dummy renderer cannot retrieve pixels (null texture),
	# so verify the exact screenshot viewport and every authored plate rectangle.
	# Do not generate or write PNG files in this lane.
	_check(root.get_viewport().get_visible_rect().size == Vector2(1280, 720),
		"headless 1280x720 Gothic viewport has the intended visual capture bounds")


# Commit only an actual hero Pass through the live screen. The automatic foe
# driver will resolve the imminent actor; compare its first receipt with the
# ticket read immediately BEFORE that pass.
func _verify_receipt(stage: StitchedBattleScreen) -> void:
	var battle := stage.battle
	var witnessed := false
	for step in range(15):
		if battle.is_over() or battle.current_side() != "hero":
			break
		var snapshot := battle.state_snapshot()
		var order: Array = snapshot["order"]
		var next_index := int(snapshot["turn_index"]) + 1
		var next_id := str(order[next_index]) if next_index < order.size() else ""
		var next_actor := battle.get_unit(next_id)
		var before := stage.receipts.size()
		var expected := StitchedFoeIntent.choose(battle, next_actor)
		var hero_result := stage.submit_pass()
		_check(bool(hero_result.get("ok", false)), "public hero Pass spends exactly a hero turn")
		if str(next_actor.get("side", "")) != "foe" or bool(expected.get("pass", true)):
			continue
		var actual: Dictionary = {}
		for i in range(before + 1, stage.receipts.size()):
			var item: Dictionary = stage.receipts[i]
			if str(item.get("actor", "")) == next_id:
				actual = item
				break
		_check(not actual.is_empty() and str(actual.get("action", "")) == "ability"
			and str(actual.get("ability", "")) == str(expected["ability_id"]),
			"unchanged pre-foe ticket matches actual next committed ability ID")
		if not actual.is_empty():
			var targets: Array[int] = []
			for result in actual.get("results", []):
				var target := battle.get_unit(str(result.get("target", "")))
				if not target.is_empty() and not targets.has(int(target["rank"])):
					targets.append(int(target["rank"]))
			targets.sort()
			_check(targets == expected["affected_ranks"]
				and (actual.get("results", []).size() >= 2 if bool(expected["multi"]) else actual.get("results", []).size() == 1),
				"automatic foe receipt resolves exact displayed single/all valid ranks")
		witnessed = true
		break
	_check(witnessed, "non-vacuous: committed a real hero Pass immediately before an ability foe turn")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var mounted := _mount()
	var host: Control = mounted["host"]
	var stage: StitchedBattleScreen = mounted["stage"]
	await process_frame
	var battle := stage.battle
	if battle == null:
		_check(false, "real S2 battle exists")
		host.free()
		_finish()
		return
	_check(host.theme != null and battle.is_valid()
		and battle.get_heroes().size() == 4 and battle.get_foes().size() == 3
		and battle.current_side() == "hero", "seeded 4v3 screen mounted in Gothic theme with a hero turn")
	_check_geometry(stage)
	_verify_tickets(stage)
	_check(not stage._foe_tickets[4].visible, "initial fourth foe rank is empty, not a ghost ability")
	var sample: Dictionary = battle.get_foes()[0]
	var sample_id := str(sample["id"])
	var sample_rank := int(sample["rank"])
	var actor: Dictionary = battle._units[sample_id]
	var original_units := battle._units.duplicate(true)
	var original_heaps := battle._heaps.duplicate(true)
	var next_ability := StitchedFoeIntent.choose(battle, sample)
	if not bool(next_ability.get("pass", true)):
		next_ability["affected_ranks"].append(99)
		_check(not StitchedFoeIntent.choose(battle, sample)["affected_ranks"].has(99),
			"helper returns detached affected ranks, not battle state aliases")

	# The accepted hero-target forecast and the foe tickets coexist: inspecting
	# a foe intent never edits STATUS log, selected rank or the part projection.
	var chosen := false
	for slot in StitchedBattleScreen.SLOTS:
		if stage.select_part(slot):
			chosen = true
			break
	_check(chosen, "precondition: real acting hero has a usable sewn part")
	var preview_before := str(stage._labels["preview"].text)
	var log_before := str(stage._labels["log"].text)
	var selection_before := stage._selected_part
	var legal_before := stage.legal_targets()
	var state_before := battle.state_snapshot()
	var rng_before := battle.rng_state()
	var order_before := battle.turn_order()
	var receipts_before := stage.receipts.duplicate(true)
	var current_before := battle.current_actor_id()
	var round_before := battle.round_number()
	seed(5122026)
	var expected_global := randi()
	seed(5122026)
	for turn in range(3):
		stage._refresh()
		var ticket: NinePatchRect = stage._foe_tickets[sample_rank]
		ticket.mouse_entered.emit()
		_check(stage._intent_disclosure.visible and
			stage._intent_disclosure_label.text == ticket.tooltip_text and
			ticket.tooltip_text.contains(str(sample["name"])),
			"mouse hover reveals exact full authoritative foe/ability/target/warning")
		ticket.mouse_exited.emit()
		ticket.grab_focus()
		_check(ticket.has_focus() and stage._intent_disclosure.visible
			and stage._intent_disclosure_label.text == ticket.tooltip_text,
			"keyboard focus has the same full non-truncated disclosure as mouse tooltip")
		stage._action_buttons["pass"].grab_focus()
	_check(not stage._intent_disclosure.visible and stage._labels["preview"].text == preview_before
		and stage._labels["log"].text == log_before and stage._selected_part == selection_before
		and stage.legal_targets() == legal_before and stage.receipts == receipts_before,
		"intents leave selected part, target legality, target forecast and seat log untouched")
	_check(state_before == battle.state_snapshot() and rng_before == battle.rng_state()
		and order_before == battle.turn_order() and current_before == battle.current_actor_id()
		and round_before == battle.round_number() and randi() == expected_global,
		"refresh, hover and focus spend no local/global RNG, turn, action or combat state")

	# Rank/target changes reproject against the live legality authority.
	var hero_one: Dictionary = battle._units[str(battle.get_heroes()[0]["id"])]
	hero_one["lost"] = true
	stage._refresh()
	_check(int(stage._foe_intents[sample_rank]["target_rank"]) == 2
		and stage._foe_tickets[sample_rank].tooltip_text.contains("rank 2"),
		"lost front hero makes first legal target rank 2, never a phantom rank 1")
	hero_one["lost"] = false
	# Original first ability is disabled: fall through to authored next ability.
	actor["abilities"][0]["launch_mask"] = 1 << 4
	stage._refresh()
	_check(str(stage._foe_intents[sample_rank]["ability_id"]) == str(actor["abilities"][1]["id"])
		and not bool(stage._foe_intents[sample_rank]["pass"]),
		"first disabled ability falls back to next usable authored kit entry")
	actor["abilities"][1]["launch_mask"] = 1 << 4
	stage._refresh()
	_check(bool(stage._foe_intents[sample_rank]["pass"])
		and stage._foe_tickets[sample_rank].get_node("IntentText").text.contains("PASS")
		and not stage._foe_tickets[sample_rank].tooltip_text.contains("Target:"),
		"all abilities blocked produces PASS without an illegal target")
	actor["abilities"] = original_units[sample_id]["abilities"].duplicate(true)
	actor["statuses"]["stun"] = 1
	stage._refresh()
	_check(bool(stage._foe_intents[sample_rank]["stun"])
		and stage._foe_tickets[sample_rank].get_node("IntentText").text.contains("STUN")
		and not stage._foe_tickets[sample_rank].tooltip_text.contains("Target:"),
		"next-turn stun skip is not promised as an attack")
	actor["statuses"].erase("stun")
	# Reposition an existing foe and change its identity display name.
	var swap: Dictionary = battle._units[str(battle.get_foes()[2]["id"])]
	var other_rank := int(swap["rank"])
	swap["rank"] = sample_rank
	actor["rank"] = other_rank
	actor["name"] = "Repaired Foe"
	stage._refresh()
	_check(stage._foe_tickets[other_rank].visible
		and stage._foe_tickets[other_rank].tooltip_text.contains("Repaired Foe")
		and stage._foe_intents[other_rank]["foe_id"] == sample_id,
		"rank swap rebinds to new public name and position without stale labels")
	battle._round += 1
	stage._refresh()
	_verify_tickets(stage)
	_check(stage._foe_intents[other_rank] == StitchedFoeIntent.choose(battle, battle.get_unit(sample_id)),
		"round rotation recalculates from authored next ability, not a stored preview")
	battle._units = original_units.duplicate(true)
	battle._heaps = original_heaps.duplicate(true)
	stage._refresh()

	# Death and heap replacement hide tickets instead of targeting scrap.
	battle._units[sample_id]["dead"] = true
	battle._units[sample_id]["hp"] = 0
	battle._heaps.append({"id": "heap:test", "side": "heap", "rank": sample_rank,
		"hp": 5, "max_hp": 5, "foe_id": sample_id})
	stage._refresh()
	_check(not stage._foe_tickets[sample_rank].visible
		and StitchedFoeIntent.choose(battle, battle.get_unit(sample_id)).is_empty(),
		"dead foe replaced with scrap heap has no ticket or selectable intent")
	battle._units = original_units.duplicate(true)
	battle._heaps = original_heaps.duplicate(true)
	stage._refresh()
	_verify_receipt(stage)
	host.free()

	# Valid authored multi-target S2 variant, not a fake battle catalog.
	var multi_config: Dictionary = StitchedBattleScreen.read_preview().duplicate(true)
	for foe in multi_config["foes"]:
		for ability in foe["abilities"]:
			if str(ability["target_side"]) == "enemy":
				ability["multi"] = true
	var multi_mount := _mount(multi_config)
	var multi_host: Control = multi_mount["host"]
	var multi_stage: StitchedBattleScreen = multi_mount["stage"]
	await process_frame
	_verify_tickets(multi_stage)
	var multi_witness := 0
	for foe in multi_stage.battle.get_foes():
		var intent := StitchedFoeIntent.choose(multi_stage.battle, foe)
		if bool(intent.get("multi", false)):
			multi_witness += 1
			_check(intent["affected_ranks"].size() >= 2
				and multi_stage._foe_tickets[int(foe["rank"])].tooltip_text.contains("ALL legal HERO ranks")
				and multi_stage._foe_ticket_labels[int(foe["rank"])].text.contains("ALL H"),
				"authored multi ability displays all living legal HERO ranks")
	_check(multi_witness >= 2, "non-vacuous: two or more seeded foes have real multi-target abilities")
	_verify_receipt(multi_stage)
	multi_host.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_foe_intent_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
