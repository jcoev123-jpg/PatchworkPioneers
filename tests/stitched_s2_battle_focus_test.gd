extends SceneTree
## S7: a real mounted Stitched screen drives the live receipt-to-painted-stage camera.
const ROSTER := preload("res://scripts/live_enemy_roster.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _mount() -> StitchedBattleScreen:
	var host := Control.new()
	host.name = "FocusThemedHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var screen := StitchedBattleScreen.new()
	var preview := StitchedBattleScreen.read_preview()
	_check(preview.get("heroes", []).size() == 4 and preview.get("foes", []).size() == 3,
		"precondition: actual 4v3 shipped S2 preview")
	_check(screen.begin(preview), "precondition: real stitched combat service begins")
	host.add_child(screen)
	screen.set_process(false) # Manual focus clock: no sleeps or presentation races.
	screen._stage_backdrop.set_process(false)
	_check(screen.battle.get_heroes().size() == 4 and screen.battle.get_foes().size() == 3,
		"mounted battle remains a real seeded 4v3")
	return screen


func _frozen(screen: StitchedBattleScreen) -> Dictionary:
	return {
		"state": screen.battle.state_snapshot(),
		"rng": screen.battle.rng_state(),
		"order": screen.battle.turn_order(),
		"actor": screen.battle.current_actor_id(),
		"legal": screen.legal_targets(),
		"receipts": screen.receipts.duplicate(true),
	}


func _unchanged(screen: StitchedBattleScreen, before: Dictionary, message: String) -> void:
	_check(screen.battle.state_snapshot() == before["state"]
		and screen.battle.rng_state() == before["rng"]
		and screen.battle.turn_order() == before["order"]
		and screen.battle.current_actor_id() == before["actor"]
		and screen.legal_targets() == before["legal"]
		and screen.receipts == before["receipts"], message)


func _fixed(screen: StitchedBattleScreen) -> Dictionary:
	var rects := {}
	for group in [screen._figure_hits, screen._target_buttons, screen._seat_buttons,
			screen._foot_plates, screen._action_buttons, screen._part_buttons,
			screen._part_help_buttons]:
		for key in group:
			rects[str(group[key].get_instance_id())] = group[key].get_global_rect()
	for meter in screen._rank_meters.values():
		rects[str(meter["root"].get_instance_id())] = meter["root"].get_global_rect()
	for control in [screen._turn_ribbon, screen._candle_meter,
			screen._stage_art_view, screen._stage_backdrop]:
		rects[str(control.get_instance_id())] = control.get_global_rect()
	return rects



# Only input/HUD mounts are fixed under camera focus. S7's new intent plaques
# follow actual painted poses after each public refresh; verify that separate
# live geometry contract instead of freezing their obsolete overhead positions.
func _verify_intent_anchors(screen: StitchedBattleScreen, expected: int) -> void:
	var visible_count := 0
	for rank in range(1, 5):
		var puppet: Control = screen._puppets["foe_" + str(rank)]
		var ticket: StitchedFoeIntentPlate = screen._foe_tickets[rank]
		if not puppet.visible:
			_check(not ticket.visible, "vacated foe rank %d clears plaque" % rank)
			continue
		visible_count += 1
		var art: Rect2 = puppet.posed_actor_rect()
		var painted := Rect2(puppet.get_global_transform() * art.position, art.size)
		var plaque := ticket.get_global_rect()
		_check(art.size.x > 0.0 and ticket.visible
			and absf(plaque.get_center().x - painted.get_center().x) <= 9.0
			and painted.position.y - plaque.end.y >= 6.0
			and painted.position.y - plaque.end.y <= 100.0
			and plaque.size.y <= 68.0
			and not plaque.intersects(screen._foot_plates["foe_" + str(rank)].get_global_rect()),
			"foe rank %d has its own live painted anchor, free of the fixed footplate" % rank)
	_check(visible_count == expected, "non-vacuous foe intent geometry count")


func _camera_math(screen: StitchedBattleScreen, expected: float, message: String) -> void:
	var backdrop = screen._stage_backdrop
	var transform: Transform2D = backdrop.focus_transform()
	_check(absf(backdrop.focus_zoom() - expected) < 0.0002
		and absf(transform.x.x - expected) < 0.0002
		and absf(transform.y.y - expected) < 0.0002,
		message + " zoom envelope")
	var world: Transform2D = backdrop.get_global_transform()
	_check((world * backdrop.art_focus_transform() * world.affine_inverse()).is_equal_approx(transform),
		message + " backdrop artwork has shared world camera")
	for puppet in screen._puppets.values():
		if not puppet.visible:
			continue
		var puppet_world: Transform2D = puppet.get_global_transform()
		_check((puppet_world * puppet.art_focus_transform() * puppet_world.affine_inverse()).is_equal_approx(transform),
			message + " all occupied ROSTER.Puppet paintings share camera")


func _sample(screen: StitchedBattleScreen, delta: float, expected: float,
		before: Dictionary, fixed: Dictionary, label: String) -> void:
	screen._advance_focus(delta)
	_camera_math(screen, expected, label)
	_unchanged(screen, before, label + " does not spend/roll/reorder/rewrite")
	_check(_fixed(screen) == fixed, label + " leaves every hit, intent, seat and HUD rect fixed")


func _selected_damage_target(screen: StitchedBattleScreen) -> String:
	var actor := screen.battle.get_unit(screen.battle.current_actor_id())
	for slot in StitchedBattleScreen.SLOTS:
		var equipped: Dictionary = actor.get("parts", {}).get(slot, {})
		var definition: Dictionary = screen.parts.get(str(equipped.get("id", "")), {})
		if definition.is_empty():
			continue
		var ability: Dictionary = StitchedParts.ability_at_tier(definition, int(equipped.get("tier", 1)))
		if str(ability.get("target_side", "")) != "enemy" or int(ability.get("dmg", [0, 0])[1]) <= 0:
			continue
		if not screen.select_part(slot):
			continue
		for key in screen.legal_targets():
			if str(key).begins_with("foe_") and screen._figure_hits[key].visible:
				return str(key)
	return ""


func _figure_press(screen: StitchedBattleScreen, key: String) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	screen._figure_hits[key].gui_input.emit(event)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var screen := _mount()
	var backdrop = screen._stage_backdrop
	var neutral := _fixed(screen)
	_verify_intent_anchors(screen, 3)
	_check(backdrop is ROSTER.StageBackdrop and backdrop.has_image()
		and backdrop.stage_texture.resource_path == ROSTER.stage_backdrop_path("Fight", 0)
		and backdrop.get_global_rect() == Rect2(0, 60, 1280, 500)
		and screen._stage_art_view.clip_contents and backdrop.clip_contents,
		"AC1 authored art is fitted to clipped y60..560 without moving input mounts")
	var occupied := 0
	for puppet in screen._puppets.values():
		_check(puppet is ROSTER.Puppet and puppet.stage_focus == backdrop
			and puppet.get_parent() == screen._stage_art_view
			and puppet.global_position.y == -6.0,
			"AC1 real puppets are linked to the shared painter at unchanged rest positions")
		if puppet.visible:
			occupied += 1
	_check(occupied == 7, "AC1 four heroes and three foe artworks are really visible")
	# The seed can start on a hero; foe batches are exercised after real
	# hero turns below, rather than assuming an opening foe action.
	_check(screen.battle.current_side() == "hero",
		"precondition: mounted deterministic preview is ready for a real hero action")
	screen._cancel_stage_focus()
	_camera_math(screen, 1.0, "neutral stage")
	var target_key := _selected_damage_target(screen)
	_check(not target_key.is_empty(), "precondition: current hero has a genuinely damaging legal target")
	if not target_key.is_empty():
		var frozen_before_invalid := _frozen(screen)
		_figure_press(screen, "foe_4")
		_check(not bool(screen.submit_target("foe", 0).get("ok", false))
			and not bool(screen.submit_part("not_a_part", 1).get("ok", false)),
			"AC4 empty/invalid figure and invalid part remain denied")
		_unchanged(screen, frozen_before_invalid, "AC4 denied figure never changes rules")
		var acting_id := screen.battle.current_actor_id()
		var start_receipts := screen.receipts.size()
		_figure_press(screen, target_key)
		_check(screen.receipts.size() > start_receipts
			and screen.receipts[start_receipts].get("actor", "") == acting_id
			and screen.receipts[start_receipts].get("action", "") == "ability",
			"AC2 actually pressed lit figure commits exactly one hero part ability")
		_check(screen._damage_capable_receipt(screen.receipts[start_receipts]),
			"AC2 committed receipt belongs to authored damage-capable part")
		_check(not backdrop.focus_anchors.is_empty()
			and str(backdrop.focus_ids[0]) == acting_id
			and str(backdrop.focus_ids[1]) == str(screen.receipts[start_receipts]["results"][0]["target"]),
			"AC2 committed hero attack owns its own pre-refresh target binding")
		if not backdrop.focus_anchors.is_empty():
			var attacker: Control = backdrop.focus_anchors[0]
			var target: Control = backdrop.focus_anchors[1]
			var midpoint: Vector2 = (attacker.get_global_transform() * attacker.rest_drawn_rect().get_center()
				+ target.get_global_transform() * target.rest_drawn_rect().get_center()) * 0.5
			_check(backdrop.focus_center.distance_to(midpoint) < 0.01,
				"AC2 focus midpoint uses resting painted artwork, not controls or recoil")
			var frozen := _frozen(screen)
			var fixed := _fixed(screen)
			_sample(screen, 0.0, 1.0, frozen, fixed, "start")
			_sample(screen, 0.075, 1.15, frozen, fixed, "half in")
			_sample(screen, 0.075, 1.30, frozen, fixed, "full in")
			_sample(screen, 0.25, 1.30, frozen, fixed, "hold")
			_sample(screen, 0.25, 1.30, frozen, fixed, "hold end")
			_sample(screen, 0.10, 1.15, frozen, fixed, "half out")
			_sample(screen, 0.10, 1.0, frozen, fixed, "out")
			_check(backdrop.focus_anchors.is_empty() or backdrop.focus_zoom() == 1.0,
				"AC3 ended focus returns to identity, or begins queued next beat at identity")
			# Any follow-on real foe receipts remain ordered behind the hero shot.
			_check(screen._focus_queue.size() <= screen.MAX_PENDING_FOCUS,
				"AC2 real follow-on foe attacks remain bounded")
	# Accepted ability guard/buff and rejected actions are not camera events.
	screen._cancel_stage_focus()
	var non_damage := {"ok": true, "action": "move", "actor": "warden", "results": []}
	var no_action := {"ok": true, "action": "ability", "actor": "missing_actor", "results": []}
	screen._enqueue_attack_focus(non_damage)
	screen._enqueue_attack_focus(no_action)
	_check(screen._focus_queue.is_empty() and backdrop.focus_anchors.is_empty(),
		"AC4 moves and empty/no-action intents create no fake attack focus")
	# Bind a genuine fourth foe fixture (not an image or dummy control) to its
	# pre-existing rank; the frame remains stationary during a shared camera beat.
	var original: Dictionary = screen.battle.get_foes()[2]
	var extra: Dictionary = screen.battle._units[str(original["id"])].duplicate(true)
	extra["id"] = "ragling"
	extra["name"] = "Ragling"
	extra["rank"] = 4
	var before_extra := _frozen(screen)
	screen.battle._units[extra["id"]] = extra
	screen._refresh()
	_check(screen.battle.get_foes().size() == 4 and screen._puppets["foe_4"].visible,
		"AC1 fourth genuine foe can occupy reserved rank 4")
	_verify_intent_anchors(screen, 4)
	_check(backdrop.start_focus(screen._puppets["hero_1"], screen._puppets["foe_4"], false),
		"AC2 shared visual camera accepts visible fourth-rank bound pawns")
	var before_focus_4v4 := _frozen(screen)
	var fixed_4v4 := _fixed(screen)
	_sample(screen, 0.15, 1.30, before_focus_4v4, fixed_4v4, "4v4 focused")
	screen._puppets["foe_4"].visible = false
	screen._advance_focus(0.0)
	_check(backdrop.focus_anchors.is_empty() and backdrop.focus_zoom() == 1.0,
		"AC3 hidden target cancels 4v4 camera immediately")
	screen._puppets["foe_4"].visible = true
	screen._refresh()
	# A true rebind is never allowed to inherit the old focus.
	backdrop.start_focus(screen._puppets["hero_1"], screen._puppets["foe_4"], false)
	screen._puppets["foe_4"].actor_id = "not_the_bound_foe"
	screen._advance_focus(0.0)
	_check(backdrop.focus_anchors.is_empty(), "AC3 rebound actor cancels its old focus")
	screen._refresh()
	backdrop.start_focus(screen._puppets["hero_1"], screen._puppets["foe_4"], false)
	screen.set_reduced_motion(true)
	_check(backdrop.focus_anchors.is_empty() and screen._focus_queue.is_empty(),
		"AC3 S2 reduced-motion toggle immediately clears camera")
	screen.set_reduced_motion(false)
	backdrop.start_focus(screen._puppets["hero_1"], screen._puppets["foe_4"], false)
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	screen._advance_focus(0.0)
	_check(backdrop.focus_anchors.is_empty() and backdrop.focus_zoom() == 1.0,
		"AC3 accessibility reduced-motion cancels camera")
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	backdrop.start_focus(screen._puppets["hero_1"], screen._puppets["foe_4"], false)
	ProjectSettings.set_setting("patchwork/reduced_motion", true)
	screen._advance_focus(0.0)
	_check(backdrop.focus_anchors.is_empty(), "AC3 project motion setting cancels camera")
	ProjectSettings.set_setting("patchwork/reduced_motion", false)
	screen.battle._units.erase(extra["id"])
	screen._refresh()
	_check(screen.battle.state_snapshot() == before_extra["state"]
		and screen.battle.rng_state() == before_extra["rng"]
		and not screen._puppets["foe_4"].visible,
		"AC4 genuine 4v4 visual fixture restores original 4v3 authoritative battle")
	screen._cancel_stage_focus()
	_verify_intent_anchors(screen, 3)
	_check(_fixed(screen) == neutral and backdrop.focus_zoom() == 1.0,
		"AC3 all stationary geometry and neutral camera restore after attacks")
	# Advance only through *accepted real hero Pass actions* so the existing
	# synchronous AI commits its normal foe receipts, never test-only fake moves.
	var foe_attacks := 0
	var foe_batches := 0
	var pass_only := 0
	for turn in range(10):
		if screen.battle.current_side() != "hero" or screen.battle.is_over():
			break
		var count := screen.receipts.size()
		var reply := screen.submit_pass()
		_check(bool(reply.get("ok", false)) and screen.receipts.size() > count
			and str(screen.receipts[count].get("action", "")) == "pass",
			"AC4 real Pass spends one action, not a fabricated attack focus")
		var this_batch := 0
		for i in range(count + 1, screen.receipts.size()):
			var receipt: Dictionary = screen.receipts[i]
			if str(receipt.get("actor_side", "")) == "foe" and screen._damage_capable_receipt(receipt):
				foe_attacks += 1
				this_batch += 1
		if this_batch == 0:
			pass_only += 1
			_check(not screen._damage_capable_receipt(screen.receipts[count]),
				"AC4 Pass cannot queue a new attack even when an earlier foe focus persists")
		else:
			foe_batches += 1
			_check(not backdrop.focus_anchors.is_empty()
				or not screen._focus_queue.is_empty(),
				"AC2 real foe ability receipts enter presentation queue")
		if foe_attacks >= 2:
			break
	_check(foe_attacks >= 2 and (foe_batches > 0) and pass_only >= 0,
		"AC2 at least two authentic foe ability receipts processed, ordered and bounded")
	_check(screen._focus_queue.size() <= screen.MAX_PENDING_FOCUS,
		"AC2 multiple foe receipts cannot overflow bounded focus queue")
	screen._cancel_stage_focus()
	screen.get_parent().queue_free()
	await process_frame
	# The blinded, real damaging part still attempts an attack. A miss has
	# zero actual damage but must receive exactly the same authored focus.
	var miss_stage := _mount()
	miss_stage._cancel_stage_focus()
	var miss_key := _selected_damage_target(miss_stage)
	_check(not miss_key.is_empty() and not miss_stage._target_buttons[miss_key].disabled,
		"AC4 a second actual legal keyboard rank and damage part are available")
	if not miss_key.is_empty():
		var miss_actor_id := miss_stage.battle.current_actor_id()
		miss_stage.battle._units[miss_actor_id]["statuses"]["blind"] = 1
		miss_stage._refresh()
		var before_miss := miss_stage.receipts.size()
		miss_stage._target_buttons[miss_key].pressed.emit()
		var miss_receipt: Dictionary = miss_stage.receipts[before_miss] if miss_stage.receipts.size() > before_miss else {}
		var hits: Array = miss_receipt.get("results", [])
		_check(bool(miss_receipt.get("ok", false)) and hits.size() > 0
			and not bool(hits[0].get("hit", true)) and int(hits[0].get("damage", -1)) == 0
			and miss_stage._damage_capable_receipt(miss_receipt),
			"AC4 a real blinded miss commits exactly one damage-capable attempted attack")
		_check(not miss_stage._stage_backdrop.focus_anchors.is_empty()
			and str(miss_stage._stage_backdrop.focus_ids[0]) == miss_actor_id,
			"AC2 miss still focuses a genuine attacker and target")
		var miss_frozen := _frozen(miss_stage)
		var miss_fixed := _fixed(miss_stage)
		_sample(miss_stage, 0.15, 1.30, miss_frozen, miss_fixed, "authentic miss")
		miss_stage._cancel_stage_focus()
		_check(miss_stage._stage_backdrop.focus_zoom() == 1.0,
			"AC3 missed attack cancels back to identity")
	miss_stage.get_parent().queue_free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("stitched_s2_battle_focus_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
