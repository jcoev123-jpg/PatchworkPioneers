extends SceneTree
## S11: a fight plays in the corridor itself: party left, foes right, one bottom bar, and the
## classic battle screen kept underneath as the hidden engine.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


## Owner 11-08: the corridor fight shows no foe intent plates and no puppet hands;
## the living-foe count still matches the fixture.
func _verify_live_intents(fight: StitchedCorridorFight, expected: int) -> void:
	var occupied := 0
	for rank in range(1, 5):
		if not fight.engine._unit_at("foe", rank).is_empty():
			occupied += 1
	_check(occupied == expected, "corridor fight has %d/%d living foes" % [occupied, expected])
	_check(fight.find_children("FoeIntent*", "", true, false).is_empty(),
		"no foe intent plates over the corridor fight")
	_check(not fight.kid_view.get_node("KidHandsLayer").visible,
		"no puppet hands or strings over the corridor fight")


func _verify_inspection(fight: StitchedCorridorFight) -> void:
	var screen := fight.engine
	var pristine := fight.battle.state_snapshot()
	var rng := fight.battle.rng_state()
	var receipts := screen.receipts.duplicate(true)
	var part := screen._selected_part
	var hand_pending := screen._hand_pending
	var hand_budget := fight.battle.hand_action_open()
	fight.refresh()
	fight.refresh()
	_verify_live_intents(fight, 3)
	# A held foe pose still owns NOW, but the hero-only health bar has no empty heading.
	var held_foe := str(screen._unit_at("foe", 1).get("id", ""))
	fight._held_actor_id = held_foe
	fight.refresh()
	var foe_now := false
	for index in range(fight.ribbon.displayed_entries.size()):
		if str(fight.ribbon.displayed_entries[index].get("id", "")) == held_foe:
			foe_now = fight.ribbon.marker_at(index).text == "NOW"
	_check(foe_now and not fight.health_word.visible and not fight.health_bar.visible
		and fight.actor_name.text.is_empty(), "held foe shows NOW without an orphaned hero health label")
	fight._held_actor_id = ""
	fight.refresh()
	# Separate queued batches must advance a two-turn boss to its second ribbon seat.
	var repeated_order := [held_foe, "intervening_hero", held_foe]
	var first_slot := fight._receipt_order_index(held_foe, repeated_order)
	var second_slot := fight._receipt_order_index(held_foe, repeated_order)
	_check(first_slot == 0 and second_slot == 2,
		"two boss receipts across separate batches highlight distinct rolled NOW slots")
	fight._beat_order_round = fight.battle.round_number() - 1
	_check(fight._receipt_order_index(held_foe, repeated_order) == 0,
		"new rolled round resets the boss's held-NOW occurrence counter")
	fight._beat_order_round = -1
	fight._beat_order_appearances.clear()
	_check(fight.battle.state_snapshot() == pristine and fight.battle.rng_state() == rng
		and screen.receipts == receipts and screen._selected_part == part
		and screen._hand_pending == hand_pending and fight.battle.hand_action_open() == hand_budget,
		"idle refresh spends no battle state, RNG, part or hand")


func _verify_intent_fixtures(fight: StitchedCorridorFight) -> void:
	var screen := fight.engine
	var battle := fight.battle
	var pristine := battle.state_snapshot()
	var rng := battle.rng_state()
	var receipts := screen.receipts.duplicate(true)
	var original: Dictionary = screen._unit_at("foe", 1).duplicate(true)
	var third: Dictionary = screen._unit_at("foe", 3).duplicate(true)
	_check(not original.is_empty() and not third.is_empty()
		and not original.get("abilities", []).is_empty() and screen._unit_at("foe", 4).is_empty(),
		"precondition: actual 4v3 fight has authored foe abilities and a vacant fourth rank")
	if original.is_empty() or third.is_empty() or original.get("abilities", []).is_empty():
		return
	# The same kind of retained combat unit as the S2 post-summon fixture.
	var extra := third.duplicate(true)
	extra["id"] = "ragling"
	extra["name"] = "Ragling"
	extra["rank"] = 4
	battle._units[str(extra["id"])] = extra
	fight.refresh()
	_verify_live_intents(fight, 4)
	_check(fight.stage.figure_nodes.has("foe_4") and fight.stage.figure_nodes["foe_4"].visible,
		"a fourth living unit appears in the mounted 3D corridor with its own ticket")
	var rear_box := fight.stage.screen_rect("foe_4")
	_check(rear_box.size.x > 0.0 and rear_box.position.x >= 0.0 and rear_box.end.x <= 1280.0
		and fight.hits["foe_4"].visible and fight.hits["foe_4"].size.x > 20.0,
		"fourth foe fits inside the corridor and retains a usable click target")
	battle._units.erase(str(extra["id"]))
	fight.refresh()
	_verify_live_intents(fight, 3)
	var actor: Dictionary = battle._units[str(original["id"])]
	battle._units[str(original["id"])] = original.duplicate(true)
	# Dead units and their scrap heaps are not intent-bearing actors.
	var down: Dictionary = battle._units[str(original["id"])]
	down["hp"] = 0
	down["dead"] = true
	var original_heaps := battle._heaps.duplicate(true)
	battle._heaps.append({"rank": 1, "hp": 5, "max_hp": 5})
	fight.refresh()
	_verify_live_intents(fight, 2)
	_check(fight.plates["foe_1"].visible and fight.plates["foe_1"].get_node("Name").text == "Scrap heap",
		"a visible fallen foe still shows its scrap heap")
	battle._heaps = original_heaps
	battle._units[str(original["id"])] = original.duplicate(true)
	fight.refresh()
	_verify_live_intents(fight, 3)
	# A recoverable zero-HP doll visibly falls, then stands when mended.
	var hero: Dictionary = screen._unit_at("hero", 1)
	var hero_id := str(hero.get("id", ""))
	var saved_hero: Dictionary = battle._units[hero_id].duplicate(true)
	battle._units[hero_id]["hp"] = 0
	battle._units[hero_id]["hanging"] = true
	fight.refresh()
	var fallen: Sprite3D = fight.stage.figure_nodes["hero_1"]
	_check(fallen.visible and fallen.billboard == BaseMaterial3D.BILLBOARD_DISABLED
		and fight.plates["hero_1"].get_node("HealthText").text == "HANGING",
		"a zero-HP Hanging doll lies on the floor with its HANGING plate visible")
	_check(fight.stage.screen_rect("hero_1").size.x > 0.0,
		"the fallen doll still projects into the fight")
	var fallen_frames: Array = fallen.get_meta("idle_frames", [])
	_check(fallen_frames.size() > 1, "a Hanging doll keeps its animated idle strip")
	if fallen_frames.size() > 1:
		var old_clock := fight.stage._idle_clock
		var art: Texture2D = fallen.get_meta("still")
		var rate := float(StitchedCorridorStage._idle_rates.get(art.resource_path, StitchedCorridorStage.IDLE_FPS))
		fight.stage._idle_clock = 0.0
		fight.stage._idle_step(fallen, false)
		var first_frame := fallen.texture
		fight.stage._idle_clock = 1.0 / rate
		fight.stage._idle_step(fallen, false)
		_check(first_frame in fallen_frames and fallen.texture in fallen_frames
			and first_frame != fallen.texture and fallen.billboard == BaseMaterial3D.BILLBOARD_DISABLED,
			"the fallen doll moves through its own idle frames without standing up")
		fight.stage._idle_clock = old_clock
	battle._units[hero_id] = saved_hero
	fight.refresh()
	var recovered: Sprite3D = fight.stage.figure_nodes["hero_1"]
	_check(recovered.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y
		and recovered.visible and fight.plates["hero_1"].get_node("HealthText").text != "HANGING",
		"a recovered doll returns upright with its regular health plate")
	_check(battle.state_snapshot() == pristine and battle.rng_state() == rng
		and screen.receipts == receipts and screen._selected_part.is_empty()
		and battle.hand_action_open(), "all detached fixtures restore the genuine 4v3 battle, RNG and hand")


## Repeat the same genuinely mounted offensive action with and without motion.
## Every identity, target and receipt comes from the live engine/UI.
## A click box spans its figure's projected height and stays inside its width.
func _follows(box: Button, rect: Rect2) -> bool:
	var got := box.get_rect()
	return absf(got.position.y - rect.position.y) < 2.0 and absf(got.size.y - rect.size.y) < 2.0 		and got.position.x > rect.position.x - 2.0 and got.end.x < rect.end.x + 2.0 and got.size.x > 20.0


func _camera_sample(reduced: bool) -> Dictionary:
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(StitchedBattleScreen.read_preview()), "camera precondition: actual seeded preview starts")
	screen.reduced_motion = reduced
	root.add_child(screen)
	await process_frame
	var fight := StitchedCorridorFight.attach(screen, "walls")
	_check(fight != null and fight.engine == screen and fight.battle == screen.battle,
		"camera precondition: real corridor attaches to 4v3 rules")
	await process_frame
	var stage := fight.stage
	var baseline := stage.camera.transform
	var baseline_fov := stage.camera.fov
	var initial_state := screen.battle.state_snapshot()
	var initial_rng := screen.battle.rng_state()
	var initial_receipts := screen.receipts.duplicate(true)
	var actor := screen.battle.get_unit(screen.battle.current_actor_id())
	var picked_slot := ""
	for slot in StitchedBattleScreen.SLOTS:
		if fight.part_buttons[slot].disabled:
			continue
		var worn: Dictionary = actor.get("parts", {}).get(slot, {})
		var part: Dictionary = screen.parts.get(str(worn.get("id", "")), {})
		if part.is_empty():
			continue
		var ability := StitchedParts.ability_at_tier(part, int(worn.get("tier", 1)))
		var damage: Variant = ability.get("dmg", [])
		if str(ability.get("target_side", "")) != "enemy" or not (damage is Array) or damage.size() != 2 or int(damage[1]) <= 0:
			continue
		var choices := 0
		for rank in range(1, 5):
			if not screen.battle._legal_targets(actor, ability, rank).is_empty():
				choices += 1
		if choices >= 2:
			picked_slot = slot
			break
	_check(not actor.is_empty() and screen.battle.get_heroes().size() == 4
		and screen.battle.get_foes().size() == 3 and not picked_slot.is_empty(),
		"camera precondition: 4v3 real units and multi-choice legal offensive part")
	if picked_slot.is_empty():
		screen.free()
		return {}
	fight.refresh()
	fight._hover("foe_1", true)
	fight._hover("foe_1", false)
	var no_choice := fight.click_figure("foe", 4)
	await process_frame
	_check(not bool(no_choice.get("ok", false)) and stage.camera.transform == baseline
		and is_equal_approx(stage.camera.fov, baseline_fov)
		and screen.battle.state_snapshot() == initial_state and screen.battle.rng_state() == initial_rng
		and screen.receipts == initial_receipts and not stage.fight_focus_active(),
		"hover/inspect/refresh and a rejected cast neither spend nor zoom")
	var pending := fight.choose_part(picked_slot)
	_check(str(pending.get("pending", "")) == picked_slot and not screen.legal_targets().is_empty(),
		"camera precondition: selected authored attack waits at the actual target gate")
	var illegal := fight.click_figure("hero", 4)
	await process_frame
	_check(not bool(illegal.get("ok", false)) and screen.battle.state_snapshot() == initial_state
		and screen.battle.rng_state() == initial_rng and screen.receipts == initial_receipts
		and stage.camera.transform == baseline and not stage.fight_focus_active(),
		"illegal hero target with an attack pending is fail-closed and cannot focus")
	var target_key := str(screen.legal_targets().keys()[0])
	var attacker_key := "hero_%d" % int(actor.get("rank", 0))
	_check(fight.hits[target_key].visible and fight.hits[attacker_key].visible,
		"camera precondition: offensive attacker and authentic legal target have live 3D hit projections")
	var attacker_start: Vector3 = stage.figure_nodes[attacker_key].position
	var target_start: Vector3 = stage.figure_nodes[target_key].position
	fight.hits[target_key].pressed.emit()
	_check(screen.receipts.size() > initial_receipts.size()
		and bool(screen.receipts[initial_receipts.size()].get("ok", false))
		and screen.receipts[initial_receipts.size()].get("action", "") == "ability",
		"committed attack passes through the mounted corridor hit button and produces a real receipt")
	var input_shield: Control = fight._beat_input_shield
	_check(input_shield.visible == not reduced and input_shield.mouse_filter == Control.MOUSE_FILTER_STOP
		and input_shield.get_global_rect().has_point(Vector2(679, 651))
		and input_shield.get_index() == fight.get_child_count() - 1,
		"live held beat intercepts next-turn physical clicks; reduced motion never blocks the bar")
	# Headless process frames can be extremely short; sample at the real beat peak.
	await create_timer(0.17).timeout
	if not reduced:
		var now_id := ""
		for index in range(fight.ribbon.displayed_entries.size()):
			if fight.ribbon.marker_at(index).text == "NOW":
				now_id = str(fight.ribbon.displayed_entries[index].get("id", ""))
		_check(fight._held_actor_id == str(actor.id) and fight.actor_name.text == str(actor.name)
			and now_id == str(actor.id),
			"during held attack the bar and NOW ribbon remain on its actual attacker")
		var live := screen.battle.get_unit(screen.battle.current_actor_id())
		var live_key := "%s_%d" % [str(live.get("side", "")), int(live.get("rank", 0))]
		var held_plate: NinePatchRect = fight.plates[attacker_key].get_node("Back")
		var live_plate: NinePatchRect = fight.plates[live_key].get_node("Back")
		_check(held_plate.self_modulate == Color(1.5, 1.2, 0.7)
			and (live_key == attacker_key or live_plate.self_modulate != held_plate.self_modulate),
			"held attacker, not the already-advanced actor, owns the highlighted figure plate")

		var attacker_held: Sprite3D = stage.figure_nodes[attacker_key]
		var target_held: Sprite3D = stage.figure_nodes[target_key]
		_check(attacker_held.position.x > attacker_start.x + 0.1
			and target_held.position.x > target_start.x + 0.1
			and attacker_held.scale.x > 1.05 and target_held.scale.x > 1.05,
			"attacker and target step and grow together before the held reaction")
		var held_position := attacker_held.position
		var held_scale := attacker_held.scale
		var held_texture := attacker_held.texture
		fight.refresh()
		_check(attacker_held.position.is_equal_approx(held_position)
			and attacker_held.scale.is_equal_approx(held_scale)
			and attacker_held.texture == held_texture,
			"battle refresh does not reset a live attack pose, step or scale")
	var lowest_fov:= minf(baseline_fov, stage.camera.fov)
	var pose_path := str(StitchedBattleScreen.ROSTER.art_paths(str(actor.get("id", ""))).get("attack", ""))
	if not reduced and ResourceLoader.exists(pose_path, "Texture2D"):
		_check(stage.figure_nodes[attacker_key].texture == load(pose_path),
			"live corridor attacker holds its shipped authored attack silhouette during focus")
	var projected := false
	var focused := false
	var full_line_sampled := false
	var full_line_clipped: Array[String] = []
	# Owner 11-10: the strike pose now holds under focus; headless process frames can
	# be extremely short, so sample by wall clock instead of a fixed frame count.
	var deadline := Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < deadline:
		await process_frame
		lowest_fov = minf(lowest_fov, stage.camera.fov)
		if stage.fight_focus_active():
			focused = true
		if stage.camera.fov < baseline_fov - 0.6:
			full_line_sampled = true
			for seated_key in stage.figure_nodes:
				var seated: Sprite3D = stage.figure_nodes[seated_key]
				if not seated.visible or seated.texture == null:
					continue
				var bounds := stage.screen_rect(seated_key)
				if bounds.size.x <= 0.0 or bounds.position.x < 0.0 or bounds.end.x > 1280.0:
					if not full_line_clipped.has(seated_key):
						full_line_clipped.append(seated_key)
		if stage.camera.fov < baseline_fov - 0.15:
			var rect_a := stage.screen_rect(attacker_key)
			var rect_b := stage.screen_rect(target_key)
			if rect_a.size.x > 0.0 and rect_b.size.x > 0.0:
				var a: Button = fight.hits[attacker_key]
				var b: Button = fight.hits[target_key]
				# Boxes follow the projection; where two figures overlap they split the overlap.
				projected = a.visible and b.visible and _follows(a, rect_a) and _follows(b, rect_b)
				projected = projected and rect_a.position.x > 0.0 and rect_b.end.x < 1280.0
				projected = projected and rect_a.position.y > 105.0 and rect_b.end.y < StitchedCorridorFight.BAR_TOP
				if projected:
					break
	if reduced:
		_check(not focused and is_equal_approx(lowest_fov, baseline_fov) and not stage.fight_focus_active(),
			"reduced motion leaves the live corridor camera unzoomed")
	else:
		_check(focused and lowest_fov < baseline_fov - 0.6 and projected,
			"committed offensive receipt eases toward both visible figures with exact projected hit regions (active=%s, min_fov=%.2f, projected=%s, actor=%s, target=%s)" % [str(focused), lowest_fov, str(projected), attacker_key, target_key])
		_check(full_line_sampled and full_line_clipped.is_empty(),
			"a focused attack keeps every seated doll and foe on screen, not only the acting pair: %s" % [full_line_clipped])
	# The rest of the synchronous receipts (including automatic foe attacks)
	# may queue multiple beats. All must restore the original side-on pose.
	# Owner 11-10: every queued beat now carries the 1.35s strike hold; wait past the last.
	var beat_receipts := screen.receipts.size() - initial_receipts.size()
	await create_timer(float(maxi(beat_receipts, 1)) * (StitchedCorridorFight.BEAT_TIME + StitchedCorridorFight.HOLD_TIME + 0.08) + 0.5).timeout
	_check(stage.camera.transform == baseline and is_equal_approx(stage.camera.fov, baseline_fov)
		and not stage.fight_focus_active(),
		"queued receipts restore the exact original camera transform and FOV")
	_check(not input_shield.visible, "after the final beat eases back, player input is unblocked")
	if stage.figure_nodes.has(attacker_key) and stage.figure_nodes[attacker_key].visible:
		_check(stage.placed_texture(stage.figure_nodes[attacker_key]) == fight._figure_art(str(actor.get("id", ""))),
			"after the authored pose beat, the real 3D attacker returns to its original picture")
	var first_result := {
		"snapshot": screen.battle.state_snapshot(),
		"rng": screen.battle.rng_state(),
		"receipts": screen.receipts.duplicate(true),
		"targets": screen.legal_targets(),
	}
	# A second genuine UI action cannot inherit the previous focus.
	var before_second := screen.receipts.size()
	if not screen.battle.is_over() and screen.battle.current_side() == "hero":
		var did_second := false
		for slot in StitchedBattleScreen.SLOTS:
			if fight.part_buttons[slot].disabled:
				continue
			var selected := fight.choose_part(slot)
			if selected.get("pending", "") == slot:
				var targets := screen.legal_targets()
				if not targets.is_empty():
					var key := str(targets.keys()[0])
					fight.hits[key].pressed.emit()
			if screen.receipts.size() > before_second:
				did_second = true
				break
		if not did_second:
			fight.more_buttons.pass.pressed.emit()
		_check(screen.receipts.size() > before_second,
			"second real corridor control commits another receipt")
	await process_frame
	if reduced:
		_check(stage.camera.transform == baseline and is_equal_approx(stage.camera.fov, baseline_fov),
			"second receipt never animates in reduced-motion mode")
	elif screen.receipts.size() > before_second and not screen.battle.is_over():
		# Teardown during an active second beat must not retain a tween.
		_check(stage.camera.is_inside_tree(), "second receipt still uses the original mounted camera")
	var result := {
		"first": first_result,
		"snapshot": screen.battle.state_snapshot(),
		"rng": screen.battle.rng_state(),
		"receipts": screen.receipts.duplicate(true),
		"targets": screen.legal_targets(),
	}
	fight.queue_free()
	await process_frame
	_check(not is_instance_valid(fight) or not fight.is_inside_tree(),
		"teardown removes the stage and its in-flight camera tween")
	screen.free()
	return result


## Boss status affects the flagged unit, not every foe sharing its encounter.
func _verify_boss_minion_scale(fight: StitchedCorridorFight) -> void:
	var battle := fight.battle
	var front := fight.engine._unit_at("foe", 1)
	var id := str(front.get("id", ""))
	var original: Dictionary = battle._units[id].duplicate(true)
	var original_encounter := battle._boss_encounter
	battle._units[id]["is_boss"] = true
	battle._boss_encounter = true
	fight.refresh()
	var boss_figure: Sprite3D = fight.stage.figure_nodes["foe_1"]
	var minion_figure: Sprite3D = fight.stage.figure_nodes["foe_2"]
	_check(is_equal_approx(fight.stage.placed_size(boss_figure).y, StitchedCorridorFight.BOSS_HEIGHT)
		and is_equal_approx(fight.stage.placed_size(minion_figure).y, StitchedCorridorFight.FOE_HEIGHT),
		"in a boss encounter only the actual boss is tall; its ordinary companion stays regular-sized")
	battle._units[id] = original
	battle._boss_encounter = original_encounter
	fight.refresh()
	_check(is_equal_approx(fight.stage.placed_size(fight.stage.figure_nodes["foe_1"]).y,
		StitchedCorridorFight.FOE_HEIGHT), "the normal fight restores the front foe's ordinary size")


## A corridor rebuild or direct figure clear must cancel the pending fade before
## freeing the materials and Sprite3Ds that its tween is still targeting.
func _verify_spotlight_teardown() -> void:
	var stage := StitchedCorridorStage.new()
	root.add_child(stage)
	stage.build("walls", 2)
	var lit: Array[String] = ["hero_1"]
	for reset in ["build", "junction", "clear"]:
		stage.place("hero_1", StitchedCorridorStage.hero_art("warden"), Vector3.ZERO, 1.15)
		stage.begin_spotlight(lit, [], 0.01)
		stage.end_spotlight(1.0)
		_check(stage._spot_tween != null and stage.figure_nodes["hero_1"].render_priority == 2,
			"%s precondition: active return fade keeps the acting doll foremost" % reset)
		match reset:
			"build":
				stage.build("walls", 2)
			"junction":
				stage.build_junction("walls", ["forward"])
			"clear":
				stage.clear_figures()
		_check(stage._spot_tween == null and stage.figure_nodes.is_empty()
			and is_equal_approx(stage.environment.ambient_light_energy, StitchedCorridorStage.AMBIENT_BASE),
			"%s resets spotlight before freeing tween targets" % reset)
	stage.queue_free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(StitchedBattleScreen.read_preview()), "precondition: preview battle starts")
	root.add_child(screen)
	await process_frame
	var old_children := screen.get_child_count()
	var fight := StitchedCorridorFight.attach(screen, "walls")
	_check(fight != null, "the corridor view mounts over the engine")
	await process_frame
	# The live flag is off even in pre-S14 fights; legacy hand behavior below is
	# exercised only with an explicit test-only opt-in, never in shipped play.
	_check(not StitchedRules.wren_hands and fight.hand_buttons.is_empty(),
		"retired Wren hand buttons are absent from the live pre-S14 fight bar")
	_check(not fight.more_buttons.has("re_tie"),
		"retired Re-tie is absent from the pre-S14 live More menu")
	StitchedRules.wren_hands = true
	fight._build_hands()
	fight.refresh()
	_check(screen.get_child_count() == 2 and fight.chrome.get_child_count() == old_children
		and not fight.chrome.visible, "the classic chrome is tucked away whole, not torn out")
	_check(screen.is_visible_in_tree() and screen._action_buttons.has("exit"), "the engine itself stays live")
	_check(fight.stage.fighting and fight.stage.camera.fov == StitchedCorridorStage.FIGHT_FOV, "the corridor turns to the fight view")
	# Owner 11-10: the retired meter stays hidden even on a pre-S14 battle.
	if not StitchedRules.fray_enabled:
		var original_s14 := screen.battle._s14
		screen.battle._s14 = false
		fight.refresh()
		_check(not fight.fray_word.visible and not fight.fray_bar.visible,
			"pre-S14 live corridor shows neither the retired FRAY word nor its meter")
		_check(not screen.status_detail("hero", 1).contains("FRAY"),
			"legacy inspection cannot disclose the retired FRAY count")
		var old_meter: Dictionary = screen._rank_meters.get("hero_1", {})
		_check(not old_meter.is_empty() and not old_meter["fray"].visible
			and not old_meter["fray_text"].visible,
			"legacy rank meter cannot show retired FRAY when globally disabled")
		screen.battle._s14 = original_s14
		fight.refresh()
	_verify_live_intents(fight, 3)
	_verify_inspection(fight)
	_verify_intent_fixtures(fight)
	_verify_boss_minion_scale(fight)
	# The live spotlight must welcome an ally heal, rather than painting that doll red.
	var healer: Dictionary = screen.battle.get_heroes()[0]
	var helped: Dictionary = screen.battle.get_heroes()[1]
	var heal_receipt := {"ok": true, "action": "ability", "actor": str(healer.id),
		"results": [{"target": str(helped.id), "hit": true, "damage": 0, "heal": 4}]}
	var heal_spot := fight._receipt_spot_keys(heal_receipt)
	var healer_key := "hero_%d" % int(healer.rank)
	var helped_key := "hero_%d" % int(helped.rank)
	_check(heal_spot.lit.has(healer_key) and heal_spot.lit.has(helped_key)
		and heal_spot.flash.is_empty(), "healing an ally lights both dolls without a red hit flash")
	var before_heal_preview := screen.battle.state_snapshot()
	fight._begin_receipt_focus(heal_receipt)
	await create_timer(0.2).timeout
	_check(fight.stage.environment.ambient_light_energy < StitchedCorridorStage.AMBIENT_BASE
		and fight.stage.figure_nodes[healer_key].modulate.r > 1.05
		and fight.stage.figure_nodes[helped_key].modulate.r > 1.05,
		"mounted non-damaging ally heal dims the corridor and brightens both dolls")
	fight.stage.end_spotlight(0.2)
	_check(fight.stage.figure_nodes[healer_key].render_priority == 2
		and fight.stage.figure_nodes[helped_key].render_priority == 1,
		"spotlit healing pair stays in front as the return fade begins, the actor over its target")
	await create_timer(0.25).timeout
	_check(fight.stage.figure_nodes[healer_key].render_priority == 0
		and fight.stage.figure_nodes[helped_key].render_priority == 0,
		"healing pair returns to ordinary draw order when the fade finishes")
	fight.stage.cancel_fight_focus()
	fight.refresh()
	_check(screen.battle.state_snapshot() == before_heal_preview,
		"healing spotlight only presents a receipt and never changes battle rules")
	var heroes := 0
	var foes := 0
	for key in fight.plates:
		if fight.plates[key].visible:
			if key.begins_with("hero"):
				heroes += 1
			else:
				foes += 1
	_check(heroes == 4 and foes == 3, "a name plate for each of 4 dolls and 3 foes")
	var hero_spot: Vector2 = fight.stage.screen_point("hero_1")
	var foe_spot: Vector2 = fight.stage.screen_point("foe_1")
	_check(hero_spot.x < 640.0 and foe_spot.x > 640.0, "the party stands left, the foes right")
	_check(fight.stage.screen_point("hero_4").x < hero_spot.x and fight.stage.screen_point("foe_3").x > foe_spot.x,
		"front ranks face each other in the middle")
	for key in fight.plates:
		if fight.plates[key].visible:
			var plate: Control = fight.plates[key]
			_check(plate.position.y + plate.size.y <= StitchedCorridorFight.BAR_TOP and plate.position.x > -60.0
				and plate.position.x < 1280.0, key + " plate stays on screen above the bar")
			_check(fight.hits[key].size.x > 20.0 and fight.hits[key].size.y > 40.0, key + " can be clicked")
	# Playtest 11-09: a click on the boss struck the crab whose wider box lay on top of it.
	var shown := fight.hits.keys().filter(func(k): return fight.hits[k].visible)
	for i in shown.size():
		for j in range(i + 1, shown.size()):
			var a: Rect2 = fight.hits[shown[i]].get_rect()
			var b: Rect2 = fight.hits[shown[j]].get_rect()
			_check(a.intersection(b).size.x < 1.0, "%s and %s click boxes never overlap" % [shown[i], shown[j]])
	_check(fight.stage.figure_nodes["foe_1"].flip_h and not fight.stage.figure_nodes["hero_1"].flip_h,
		"foes turn round to face the party")
	for key in fight.hits:
		_check(not fight.hits[key].tooltip_text.contains("FRAY") and not fight.hits[key].tooltip_text.contains("/200"),
			key + " hover shows no fray count: " + fight.hits[key].tooltip_text)
	_check(StitchedCorridorFight._simple_detail("R3 Tinker · HP 29/29 · FRAY 0/200
STATUS: none") == "R3 Tinker · HP 29/29",
		"hover detail keeps name and health only: " + StitchedCorridorFight._simple_detail("R3 Tinker · HP 29/29 · FRAY 0/200
STATUS: none"))
	_check(fight.part_buttons.size() == 4 and fight.candle_icon.texture != null, "four body parts and the candle")
	var hidden_numbers := ["fray", "candle", "fear", "whirr"]
	for label in fight.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			for word in hidden_numbers:
				_check(not (label.text.to_lower().contains(word) and label.text.to_lower().contains(":")),
					"no readout for " + word + ": " + label.text)
	_check(not fight.continue_button.visible, "Continue waits for the fight to end")
	# Wren's hand sits on the bar as four small hands, not behind More.
	_check(fight.hand_buttons.size() == 4, "four of Wren's hands on the bar")
	for action_id in StitchedKidHandActions.IDS:
		var hand: TextureButton = fight.hand_buttons[action_id]
		_check(hand.texture_normal != null and hand.visible and not fight.more_buttons.has(action_id),
			action_id + " is a picture on the bar, not a More choice")
		_check(hand.position.x + hand.size.x <= 1264.0 and hand.position.y >= StitchedCorridorFight.BAR_TOP
			and hand.position.y + hand.size.y <= StitchedCorridorFight.BAR_TOP + 126.0, action_id + " fits inside the bar")
		_check(not RegEx.create_from_string(r"\d").search(hand.tooltip_text), action_id + " hover shows no number: " + hand.tooltip_text)
		_check(not hand.get_global_rect().intersects(fight.more_button.get_global_rect()), action_id + " clears More")
	_check(StitchedCorridorFight._plain("Wren cups a doll: -8 fray.") == "Wren cups a doll.", "the fray number is cut from the hover")
	if screen.battle.hand_action_open():
		_check(not fight.hand_buttons.steady.disabled, "the hand is free at the round's start")
		fight.hand_buttons.steady.pressed.emit()
		_check(screen._hand_pending == "steady" and fight.hand_buttons.steady.modulate.r > 1.0, "Steady waits for a doll and glows")
		var before_hand := screen.receipts.size()
		fight.click_figure("hero", 1)
		await process_frame
		_check(screen.receipts.size() > before_hand and not screen.battle.hand_action_open(), "Wren steadies a doll from the bar")
		for action_id in StitchedKidHandActions.IDS:
			_check(fight.hand_buttons[action_id].disabled, action_id + " rests once the hand is spent this round")
		_verify_live_intents(fight, 3)
	# Left alone on a turn, a standing doll speaks over its own head.
	for kind in ["fight_idle", "fight_hurt", "fight_dark", "fight_boss", "fight_winning", "fight_losing"]:
		_check(not fight.barks.data.contexts.get(kind, []).is_empty(), "fight lines for " + kind)
	_check(not fight.bark_label.visible and (fight.bark_timer.is_stopped() == (screen.battle.current_side() != "hero")),
		"the dolls start quiet with the wait armed on the player's turn")
	var said := fight.bark()
	_check(not said.is_empty() and fight.bark_label.visible and fight.bark_label.text.contains(said.line)
		and said.side == "hero" and str(screen.battle.get_unit(said.speaker).get("side", "")) == "hero",
		"a doll in the party speaks a fight line: " + str(said))
	_check(fight.bark_label.position.y >= 132.0 and fight.bark_label.position.y + fight.bark_label.size.y < StitchedCorridorFight.BAR_TOP,
		"the line sits between the turn strip and the bar")
	var again := StitchedWalkBarks.new().pick_fight(screen.battle, 0)
	_check(again.line == said.line and again.speaker == said.speaker, "the same turn picks the same first line")
	var second := fight.bark()
	_check(second.line != said.line or fight.barks.data.contexts[second.context].size() == 1, "no fight line twice in a row")
	fight.hush()
	_check(not fight.bark_label.visible, "the player's touch hushes the doll")
	_check(StitchedWalkBarks.fight_context(screen.battle) in ["fight_idle", "fight_boss", "fight_losing", "fight_dark"],
		"a fresh fight is not called hurt or won: " + StitchedWalkBarks.fight_context(screen.battle))
	# Play the whole fight through the corridor view only.
	var acted := 0
	var guard := 0
	while not screen.battle.is_over() and guard < 200:
		guard += 1
		if screen.battle.current_side() != "hero":
			break
		var done := false
		for slot in StitchedBattleScreen.SLOTS:
			if fight.part_buttons[slot].disabled:
				continue
			var before := screen.receipts.size()
			var picked := fight.choose_part(slot)
			if picked.get("pending", "") == slot:
				var key: String = screen.legal_targets().keys()[0]
				fight.click_figure(key.get_slice("_", 0), int(key.get_slice("_", 1)))
			if screen.receipts.size() > before:
				done = true
				acted += 1
				break
			screen._selected_part = ""
		if not done:
			screen.submit_pass()
		await process_frame
		if not screen.battle.is_over():
			var remaining := 0
			for rank in range(1, 5):
				if not screen._unit_at("foe", rank).is_empty():
					remaining += 1
			_verify_live_intents(fight, remaining)
	_check(acted >= 3, "dolls act through the round part buttons (%d)" % acted)
	_check(screen.battle.is_over(), "the fight ends")
	await process_frame
	_check(fight._seen_receipts == screen.receipts.size(), "every action reaches the corridor view %d/%d" % [fight._seen_receipts, screen.receipts.size()])
	_check(fight.continue_button.visible and fight.outcome_label.visible, "Continue appears at the end")
	_check(not fight.hand_buttons.lift.visible, "Wren's hands step aside for Continue")
	_check(fight.bark_timer.is_stopped() and fight.bark().is_empty(), "the dolls fall quiet once the fight is over")
	var exited := [false]
	screen.exit_requested.connect(func(): exited[0] = true)
	fight.finish()
	_check(exited[0], "Continue hands the result back like the classic exit")
	var extra := fight.add_more("save", "Save run", func(): pass)
	_check(extra.get_parent() == fight.more_grid, "the host can add choices behind More")
	screen.free()
	var normal: Dictionary = await _camera_sample(false)
	var reduced: Dictionary = await _camera_sample(true)
	_check(not normal.is_empty() and not reduced.is_empty(),
		"both genuine 4v3 camera-mode samples completed")
	if not normal.is_empty() and not reduced.is_empty():
		_check(normal.first == reduced.first and normal.snapshot == reduced.snapshot
			and normal.rng == reduced.rng and normal.receipts == reduced.receipts
			and normal.targets == reduced.targets,
			"normal/reduced seeded corridor actions produce identical rules, receipts, targets and RNG")
	_verify_spotlight_teardown()
	StitchedRules.wren_hands = false
	for failure in failures:
		printerr(failure)
	print("stitched_s11_corridor_fight_test: ","PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
