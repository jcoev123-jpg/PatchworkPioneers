extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _heroes() -> Array:
	return [
		{"id": "warden", "name": "Warden", "max_hp": 40},
		{"id": "seamstress", "name": "Seamstress", "max_hp": 30},
		{"id": "tinker", "name": "Tinker", "max_hp": 26}
	]


func _enemies() -> Array:
	return [{"id": "ragling", "name": "Ragling", "max_hp": 12}]


func _view(meter: CombatActorMeter, snapshot: Dictionary, side: String,
		party: CombatParty, enemies: CombatEnemies, rng: RandomNumberGenerator) -> void:
	var original: Dictionary = snapshot.duplicate(true)
	var all_heroes := party.get_heroes()
	var all_enemies := enemies.get_enemies()
	var rng_state := rng.state
	_check(meter.show_actor(snapshot, side), "fresh real combat snapshot must be accepted")
	_check(snapshot == original, "presenter leaves the input dictionary unchanged")
	_check(party.get_heroes() == all_heroes, "presenter does not mutate full party state")
	_check(enemies.get_enemies() == all_enemies, "presenter does not mutate full enemy roster")
	_check(rng.state == rng_state, "presenter consumes no run RNG")


func _visual(meter: CombatActorMeter) -> Dictionary:
	return {
		"visible": meter.visible,
		"heading": meter.actor_heading.text,
		"hp": meter.hp_text.text,
		"hp_value": meter.hp_bar.value,
		"hp_max": meter.hp_bar.max_value,
		"block": meter.block_text.text,
		"block_value": meter.block_bar.value,
		"block_max": meter.block_bar.max_value,
		"statuses": meter.status_text.text,
		"modifier": meter.modifier_explanation.text,
		"modifier_visible": meter.modifier_explanation.visible,
		"modifier_id": meter.modifier_explanation.get_instance_id(),
		"bleed_warning": meter.bleed_warning.text,
		"bleed_visible": meter.bleed_warning.visible,
		"bleed_id": meter.bleed_warning.get_instance_id(),
		"outer_children": meter.get_child_count(),
		"padding_children": meter.get_node("Padding").get_child_count(),
		"content_children": meter.get_node("Padding/Content").get_child_count()
	}


func _assert_actor(meter: CombatActorMeter, heading: String, hp: int, max_hp: int,
		block: int, note: String, expected_status: String = "Statuses: none",
		expected_warning: String = "", expected_explanation: String = "") -> void:
	_check(meter.visible and meter.is_visible_in_tree(), note + ": mounted and visible")
	_check(meter.actor_heading.text == heading, note + ": position/name/death heading")
	_check(meter.hp_text.text == "HP: %d/%d" % [hp, max_hp], note + ": exact HP text")
	_check(meter.block_text.text == "Block: %d" % block, note + ": exact Block text")
	_check(meter.hp_bar.min_value == 0.0 and meter.hp_bar.max_value == float(max_hp)
		and meter.hp_bar.value == float(hp), note + ": exact HP bar")
	_check(meter.block_bar.min_value == 0.0
		and meter.block_bar.max_value == float(maxi(1, maxi(max_hp, block)))
		and meter.block_bar.value == float(block), note + ": uncapped Block bar")
	_check(meter.status_text.text == expected_status, note + ": exact status line")
	_check(not meter.hp_bar.show_percentage and not meter.block_bar.show_percentage,
		note + ": readable separately titled bars")
	_check(meter.actor_heading.is_visible_in_tree() and meter.hp_text.is_visible_in_tree()
		and meter.block_text.is_visible_in_tree() and meter.hp_bar.is_visible_in_tree()
		and meter.block_bar.is_visible_in_tree(), note + ": all five visible child controls")
	_check(meter.status_text.is_visible_in_tree() and meter.status_text.name == "StatusText"
		and meter.status_text.get_parent() == meter.get_node("Padding/Content")
		and meter.status_text.focus_mode == Control.FOCUS_NONE
		and meter.status_text.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		note + ": one inert status label inside existing Content")
	_check(meter.get_node("Padding/Content").get_child_count() == 8
		and meter.get_node("Padding/Content").find_children("ModifierExplanation", "Label", false, false).size() == 1
		and meter.get_node("Padding/Content").find_children("StatusText", "Label", false, false).size() == 1
		and meter.get_node("Padding/Content").find_children("BleedWarning", "Label", false, false).size() == 1,
		note + ": original controls plus exactly one status and one Bleed warning label")
	_check(meter.modifier_explanation.text == expected_explanation
		and meter.modifier_explanation.visible == not expected_explanation.is_empty()
		and (expected_explanation.is_empty() or meter.modifier_explanation.is_visible_in_tree()),
		note + ": exact Weak/Exposed rules or cleared inactive state")
	_check(meter.modifier_explanation.get_parent() == meter.get_node("Padding/Content")
		and meter.modifier_explanation.focus_mode == Control.FOCUS_NONE
		and meter.modifier_explanation.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		note + ": persistent rules label ignores input")
	_check(meter.bleed_warning.text == expected_warning
		and meter.bleed_warning.visible == not expected_warning.is_empty()
		and (expected_warning.is_empty() or meter.bleed_warning.is_visible_in_tree()),
		note + ": exact pending owner-turn Bleed loss or hidden empty warning")
	_check(meter.bleed_warning.get_parent() == meter.get_node("Padding/Content")
		and meter.bleed_warning.focus_mode == Control.FOCUS_NONE
		and meter.bleed_warning.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		note + ": persistent warning is mouse- and keyboard-inert")
	_check(meter.hp_bar.get_theme_stylebox("fill") is StyleBoxFlat
		and meter.block_bar.get_theme_stylebox("fill") is StyleBoxFlat,
		note + ": bars have contrasting fill styles")


func _assert_cleared(meter: CombatActorMeter, note: String) -> void:
	_check(not meter.visible and not meter.is_visible_in_tree(), note + ": invalid actor hidden")
	_check(meter.actor_heading.text.is_empty() and meter.hp_text.text.is_empty()
		and meter.block_text.text.is_empty() and meter.status_text.text.is_empty()
		and meter.modifier_explanation.text.is_empty() and not meter.modifier_explanation.visible
		and meter.bleed_warning.text.is_empty() and not meter.bleed_warning.visible,
		note + ": all old text, including stale statuses, cleared")
	_check(meter.hp_bar.value == 0 and meter.hp_bar.max_value == 1
		and meter.block_bar.value == 0 and meter.block_bar.max_value == 1,
		note + ": no old bar value or range remains")
	_check(meter.get_node("Padding/Content").get_child_count() == 8
		and meter.get_node("Padding/Content").find_children("ModifierExplanation", "Label", false, false).size() == 1
		and meter.get_node("Padding/Content").find_children("StatusText", "Label", false, false).size() == 1
		and meter.get_node("Padding/Content").find_children("BleedWarning", "Label", false, false).size() == 1,
		note + ": invalid source does not append or leak either label")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var stage := Control.new()
	stage.name = "MountedStage"
	root.add_child(stage)
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	var meter := CombatActorMeter.new()
	meter.position = Vector2(18, 18)
	stage.add_child(meter)
	await process_frame

	var party := CombatParty.new(_heroes())
	var enemies := CombatEnemies.new(_enemies())
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"non-vacuous valid Warden/Seamstress/Tinker party")
	_check(enemies.is_valid() and enemies.get_enemies().size() == 1,
		"non-vacuous valid Ragling roster")
	_check(party.get_hero(1).get("id") == "warden"
		and party.get_hero(2).get("name") == "Seamstress"
		and party.get_hero(3).get("max_hp") == 26
		and enemies.get_enemy(1).get("id") == "ragling",
		"named actors have the exact requested real combat preconditions")
	_check(meter.has_method("show_actor") and meter.is_inside_tree()
		and meter.get_parent() == stage, "required public API and mounted instance exist")
	_check(not meter.visible, "new meter does not pretend an actor exists")

	var expected_heroes := party.get_heroes()
	var expected_enemies := enemies.get_enemies()
	_check(party.gain_block(1, 6), "real starting Warden Block operation succeeds")
	expected_heroes[0]["block"] = 6
	_check(party.get_heroes() == expected_heroes, "exact full party state after Block 6")
	_view(meter, party.get_hero(1), "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden", 40, 40, 6, "starting Warden")
	await process_frame
	_check(meter.position.x >= 0 and meter.position.y >= 0
		and meter.size.x > 0 and meter.size.y > 0
		and meter.position.x + meter.size.x <= 1280
		and meter.position.y + meter.size.y <= 720,
		"visible meter rectangle fits the 1280x720 target canvas")
	_check(meter.hp_bar.size.x > 0 and meter.block_bar.size.x > 0
		and meter.hp_bar.size.y > 0 and meter.block_bar.size.y > 0,
		"bars have nonempty mounted rectangles")

	# The warning is a read-only owner-turn-end forecast, not Block or incoming attack.
	var shielded_bleed := party.get_hero(1)
	shielded_bleed["statuses"] = {"bleed": 3, "weak": 1, "exposed": 2}
	var shielded_before := shielded_bleed.duplicate(true)
	var rule := CombatStatuses.new()
	var shielded_tick := rule.end_owner_turn(shielded_bleed["hp"],
		shielded_bleed["block"], shielded_bleed["statuses"].duplicate(true))
	_check(shielded_tick["ok"] and shielded_tick["bleed_hp_loss"] == 3
		and shielded_tick["hp"] == 37 and shielded_tick["block"] == 6,
		"pure owner tick predicts 3 lost HP with Warden Block 6 unchanged")
	_view(meter, shielded_bleed, "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden", 40, 40, 6, "shielded Bleed plus other statuses",
		"Statuses: Bleed 3 · Weak 1 · Exposed 2", "Bleed next: -3 HP (bypasses Block)",
		"Weak: -25% attack damage\nExposed: +50% attack damage taken")
	var warning_id := meter.bleed_warning.get_instance_id()
	var modifier_id := meter.modifier_explanation.get_instance_id()
	var shielded_visual := _visual(meter)
	_view(meter, shielded_bleed, "hero", party, enemies, rng)
	_check(_visual(meter) == shielded_visual
		and meter.bleed_warning.get_instance_id() == warning_id
		and shielded_bleed == shielded_before,
		"positive warning is stable across repeated reads and does not mutate snapshots")
	var lethal_bleed := enemies.get_enemy(1)
	lethal_bleed["hp"] = 2
	lethal_bleed["statuses"] = {"bleed": 3, "weak": 2}
	var lethal_before := lethal_bleed.duplicate(true)
	var lethal_tick := rule.end_owner_turn(2, 0, lethal_bleed["statuses"].duplicate(true))
	_check(lethal_tick["ok"] and lethal_tick["bleed_hp_loss"] == 2
		and lethal_tick["hp"] == 0 and lethal_tick["block"] == 0,
		"lethal enemy tick clamps the forecast to living HP")
	_view(meter, lethal_bleed, "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling", 2, 12, 0, "lethal enemy Bleed",
		"Statuses: Bleed 3 · Weak 2", "Bleed next: -2 HP (bypasses Block) — LETHAL",
		"Weak: -25% attack damage")
	_check(lethal_bleed == lethal_before and meter.bleed_warning.get_instance_id() == warning_id,
		"enemy warning uses the same label without applying lethal damage")
	var weak_only := party.get_hero(1)
	weak_only["statuses"] = {"weak": 2}
	_view(meter, weak_only, "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden", 40, 40, 6, "real Weak-2 hero",
		"Statuses: Weak 2", "", "Weak: -25% attack damage")
	var exposed_only := enemies.get_enemy(1)
	exposed_only["statuses"] = {"exposed": 1}
	_view(meter, exposed_only, "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling", 12, 12, 0, "real Exposed-1 enemy",
		"Statuses: Exposed 1", "", "Exposed: +50% attack damage taken")
	_check(meter.modifier_explanation.get_instance_id() == modifier_id,
		"all snapshots share the one persistent rules label")
	_view(meter, party.get_hero(1), "hero", party, enemies, rng)
	var starting_visual := _visual(meter)
	_view(meter, party.get_hero(1), "hero", party, enemies, rng)
	_check(_visual(meter) == starting_visual, "second identical refresh is fully idempotent")

	_check(party.apply_damage(1, 4), "real damage of 4 hits Warden Block first")
	expected_heroes[0]["block"] = 2
	_check(party.get_heroes() == expected_heroes, "full party snapshot after Block absorbs 4")
	_view(meter, party.get_hero(1), "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden", 40, 40, 2, "Warden partially blocked hit")
	_check(party.apply_damage(1, 5), "real overflow damage succeeds")
	expected_heroes[0]["block"] = 0
	expected_heroes[0]["hp"] = 37
	_check(party.get_heroes() == expected_heroes, "full party snapshot after HP overflow")
	_view(meter, party.get_hero(1), "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden", 37, 40, 0, "Warden 3 HP lost")

	# A newly selected actor retains its actual 1-based position, not the old name.
	_view(meter, party.get_hero(2), "hero", party, enemies, rng)
	_assert_actor(meter, "2. Seamstress", 30, 30, 0, "different living hero")
	_view(meter, party.get_hero(3), "hero", party, enemies, rng)
	_assert_actor(meter, "3. Tinker", 26, 26, 0, "third hero")

	_view(meter, enemies.get_enemy(1), "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling", 12, 12, 0, "starting enemy")
	_check(enemies.get_enemies() == expected_enemies, "initial enemy full state unchanged")
	_check(enemies.gain_block(1, 4), "real Ragling Block operation succeeds")
	expected_enemies[0]["block"] = 4
	_check(enemies.get_enemies() == expected_enemies, "full enemy snapshot after Block 4")
	_view(meter, enemies.get_enemy(1), "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling", 12, 12, 4, "protected Ragling")
	_check(enemies.apply_damage(1, 6), "real enemy damage absorbed before HP")
	expected_enemies[0]["hp"] = 10
	expected_enemies[0]["block"] = 0
	_check(enemies.get_enemies() == expected_enemies, "exact enemy roster after Block 4 absorbs 6")
	_view(meter, enemies.get_enemy(1), "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling", 10, 12, 0, "Ragling loses 2 HP")

	# Block can exceed max HP. A progress bar's presentation scale cannot cap it.
	_check(enemies.gain_block(1, 17), "Ragling can gain Block exceeding max HP")
	expected_enemies[0]["block"] = 17
	_check(enemies.get_enemies() == expected_enemies, "full enemy state has uncapped Block 17")
	_view(meter, enemies.get_enemy(1), "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling", 10, 12, 17, "uncapped Block above HP")

	_check(party.apply_damage(1, 100), "real Warden lethal overflow damage succeeds")
	expected_heroes[0]["hp"] = 0
	_check(party.is_downed(1) and party.get_heroes() == expected_heroes,
		"downed hero retains original position and full state is exact")
	_view(meter, party.get_hero(1), "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden — DOWNED", 0, 40, 0, "downed hero")
	var downed_with_status := party.get_hero(1)
	downed_with_status["statuses"] = {"bleed": 3, "weak": 1, "exposed": 2}
	_view(meter, downed_with_status, "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden — DOWNED", 0, 40, 0, "downed hero with stack",
		"Statuses: Bleed 3 · Weak 1 · Exposed 2")
	_check(enemies.apply_damage(1, 27), "real Ragling lethal damage after Block 17 succeeds")
	expected_enemies[0]["hp"] = 0
	expected_enemies[0]["block"] = 0
	_check(enemies.is_slain(1) and enemies.get_enemies() == expected_enemies,
		"slain enemy retains position and exact full state")
	_view(meter, enemies.get_enemy(1), "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling — SLAIN", 0, 12, 0, "slain enemy")
	var slain_with_status := enemies.get_enemy(1)
	slain_with_status["statuses"] = {"weak": 2, "exposed": 1}
	_view(meter, slain_with_status, "enemy", party, enemies, rng)
	_assert_actor(meter, "1. Ragling — SLAIN", 0, 12, 0, "slain with live-looking counts",
		"Statuses: Weak 2 · Exposed 1")

	var no_cap_party := CombatParty.new(_heroes())
	_check(no_cap_party.gain_block(1, 51), "hero Block also exceeds maximum HP")
	_view(meter, no_cap_party.get_hero(1), "hero", party, enemies, rng)
	_assert_actor(meter, "1. Warden", 40, 40, 51, "Block 51 across new session")
	_check(no_cap_party.get_hero(1).get("block") == 51, "view never limits source Block")

	# Display data belongs only to the supplied snapshot, never to either roster.
	var deck := CombatDeck.new(["warden_brace", "seamstress_prick", "tinker_jab"], rng)
	_check(deck.start_turn() and deck.hand.size() == 3, "real deck state for presentation no-mutation check")
	var deck_before := [deck.hand.duplicate(), deck.draw_pile.duplicate(),
		deck.discard_pile.duplicate(), deck.energy, deck.turn_active]
	var state_before := [party.get_heroes(), enemies.get_enemies(), no_cap_party.get_heroes(), rng.state]
	seed(72911)
	var next_global_random := randi()
	seed(72911)
	var status_id := meter.status_text.get_instance_id()
	var samples: Array[Dictionary] = [
		{"statuses": {}, "text": "Statuses: none"},
		{"statuses": {"bleed": 0, "weak": 0, "exposed": 0}, "text": "Statuses: none"},
		{"statuses": {"bleed": 3}, "text": "Statuses: Bleed 3"},
		{"statuses": {"weak": 1}, "text": "Statuses: Weak 1"},
		{"statuses": {"exposed": 2}, "text": "Statuses: Exposed 2"},
		{"statuses": {"bleed": 3, "weak": 1}, "text": "Statuses: Bleed 3 · Weak 1"},
		{"statuses": {"bleed": 3, "exposed": 2}, "text": "Statuses: Bleed 3 · Exposed 2"},
		{"statuses": {"weak": 1, "exposed": 2}, "text": "Statuses: Weak 1 · Exposed 2"},
		{"statuses": {"exposed": 2, "bleed": 3, "weak": 1}, "text": "Statuses: Bleed 3 · Weak 1 · Exposed 2"},
		{"statuses": {"bleed": 0, "weak": 4, "exposed": 0}, "text": "Statuses: Weak 4"}
	]
	for side in ["hero", "enemy"]:
		var source: Dictionary = no_cap_party.get_hero(1) if side == "hero" else enemies.get_enemy(1)
		var expected_heading := "1. Warden" if side == "hero" else "1. Ragling — SLAIN"
		var expected_hp := 40 if side == "hero" else 0
		var expected_max := 40 if side == "hero" else 12
		var expected_block := 51 if side == "hero" else 0
		for sample in samples:
			var snapshot := source.duplicate(true)
			snapshot["statuses"] = sample["statuses"].duplicate(true)
			_view(meter, snapshot, side, party, enemies, rng)
			var expected_warning := ""
			if expected_hp > 0 and sample["statuses"].get("bleed", 0) > 0:
				var tick := rule.end_owner_turn(expected_hp, expected_block,
					sample["statuses"].duplicate(true))
				_check(tick["ok"] and tick["block"] == expected_block
					and tick["bleed_hp_loss"] == mini(expected_hp, sample["statuses"]["bleed"]),
					"status permutation matches copied pure rule with unchanged Block")
				expected_warning = "Bleed next: -%d HP (bypasses Block)%s" % [
					tick["bleed_hp_loss"], " — LETHAL" if tick["hp"] == 0 else ""]
			var expected_explanation: Array[String] = []
			if expected_hp > 0:
				if sample["statuses"].get("weak", 0) > 0:
					expected_explanation.append("Weak: -25% attack damage")
				if sample["statuses"].get("exposed", 0) > 0:
					expected_explanation.append("Exposed: +50% attack damage taken")
			_assert_actor(meter, expected_heading, expected_hp, expected_max, expected_block,
				"%s status permutation %s" % [side, str(sample["statuses"])], sample["text"],
				expected_warning, "\n".join(expected_explanation))
			var visual := _visual(meter)
			_view(meter, snapshot, side, party, enemies, rng)
			_check(_visual(meter) == visual and meter.status_text.get_instance_id() == status_id
				and meter.modifier_explanation.get_instance_id() == modifier_id,
				"repeated identical status refresh is stable, with exactly one label")
	_check([party.get_heroes(), enemies.get_enemies(), no_cap_party.get_heroes(), rng.state] == state_before
		and [deck.hand, deck.draw_pile, deck.discard_pile, deck.energy, deck.turn_active] == deck_before,
		"all status permutations preserve every roster, deck pile, energy, turn state and seeded RNG")
	_check(randi() == next_global_random, "status rendering never consumes the global RNG stream")
	_view(meter, no_cap_party.get_hero(1), "hero", party, enemies, rng)
	_check(meter.status_text.text == "Statuses: none", "missing statuses explicitly clears prior positive counters")

	var valid := no_cap_party.get_hero(1)
	var invalids: Array[Dictionary] = [
		{},
		{"name": "Ghost", "position": 1, "max_hp": 5, "hp": 5},
		{"name": "", "position": 1, "max_hp": 5, "hp": 5, "block": 0},
		{"name": "  ", "position": 1, "max_hp": 5, "hp": 5, "block": 0},
		{"name": 3, "position": 1, "max_hp": 5, "hp": 5, "block": 0},
		{"name": "Ghost", "position": 0, "max_hp": 5, "hp": 5, "block": 0},
		{"name": "Ghost", "position": 4, "max_hp": 5, "hp": 5, "block": 0},
		{"name": "Ghost", "position": 1.0, "max_hp": 5, "hp": 5, "block": 0},
		{"name": "Ghost", "position": 1, "max_hp": 0, "hp": 0, "block": 0},
		{"name": "Ghost", "position": 1, "max_hp": 5.0, "hp": 5, "block": 0},
		{"name": "Ghost", "position": 1, "max_hp": 5, "hp": -1, "block": 0},
		{"name": "Ghost", "position": 1, "max_hp": 5, "hp": 6, "block": 0},
		{"name": "Ghost", "position": 1, "max_hp": 5, "hp": 5.0, "block": 0},
		{"name": "Ghost", "position": 1, "max_hp": 5, "hp": 5, "block": -1},
		{"name": "Ghost", "position": 1, "max_hp": 5, "hp": 5, "block": 1.0}
	]
	# Every malformed *present* status map clears even a previously positive label.
	for bad_status in [null, [], 3, "bleed", {"bleed": -1}, {"weak": 1.0},
		{"exposed": true}, {"bleed": "3"}, {"poison": 1},
		{"bleed": 1, "poison": 0}, {1: 2}, {"exposed": null}]:
		var malformed := valid.duplicate(true)
		malformed["statuses"] = bad_status
		invalids.append(malformed)
	var positive := valid.duplicate(true)
	positive["statuses"] = {"bleed": 3, "weak": 1, "exposed": 2}
	var rng_before_invalid := rng.state
	var party_before_invalid := party.get_heroes()
	var enemy_before_invalid := enemies.get_enemies()
	for invalid in invalids:
		_check(meter.show_actor(positive, "hero") and meter.status_text.text == "Statuses: Bleed 3 · Weak 1 · Exposed 2"
			and not meter.bleed_warning.text.is_empty() and meter.modifier_explanation.visible,
			"restore all positive stacks before negative case")
		_check(not meter.show_actor(invalid, "hero"), "malformed source must fail closed: " + str(invalid))
		_assert_cleared(meter, "malformed source")
	for bad_side in ["", "ally", "HERO", "Enemy"]:
		_check(meter.show_actor(positive, "hero") and meter.status_text.text == "Statuses: Bleed 3 · Weak 1 · Exposed 2"
			and not meter.bleed_warning.text.is_empty() and meter.modifier_explanation.visible,
			"restore positive stacks before invalid side")
		_check(not meter.show_actor(valid, bad_side), "unknown side must fail closed: " + bad_side)
		_assert_cleared(meter, "unknown side")
	_check(positive["statuses"] == {"bleed": 3, "weak": 1, "exposed": 2},
		"valid status source dictionary was never changed by presentation or rejection")
	_check(party.get_heroes() == party_before_invalid
		and enemies.get_enemies() == enemy_before_invalid
		and rng.state == rng_before_invalid
		and [deck.hand, deck.draw_pile, deck.discard_pile, deck.energy, deck.turn_active] == deck_before,
		"all negative refreshes leave complete combat states and RNG untouched")

	# Deterministic replay of every displayed text and bar value.
	var first_replay: Array[Dictionary] = []
	var second_replay: Array[Dictionary] = []
	for output in [first_replay, second_replay]:
		var replay_party := CombatParty.new(_heroes())
		var replay_enemies := CombatEnemies.new(_enemies())
		for index in range(4):
			match index:
				0:
					_check(replay_party.gain_block(1, 6), "replay gain Block")
					_view(meter, replay_party.get_hero(1), "hero", party, enemies, rng)
				1:
					_check(replay_party.apply_damage(1, 9), "replay Block-before-HP hit")
					_view(meter, replay_party.get_hero(1), "hero", party, enemies, rng)
				2:
					_check(replay_enemies.gain_block(1, 4), "replay enemy Block")
					_view(meter, replay_enemies.get_enemy(1), "enemy", party, enemies, rng)
				3:
					_check(replay_enemies.apply_damage(1, 6), "replay enemy damage")
					_view(meter, replay_enemies.get_enemy(1), "enemy", party, enemies, rng)
			output.append(_visual(meter))
	_check(first_replay.size() == 4 and first_replay == second_replay,
		"deterministic second run matches all text, bars, visibility and child counts")
	_check(rng.state == rng_before_invalid, "full deterministic replay consumes no RNG")

	stage.queue_free()
	if failures.is_empty():
		print("combat_actor_meter_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_actor_meter_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
