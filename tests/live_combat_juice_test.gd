extends SceneTree
## Cycle 122 (VIS V5): one mounted, presentation-only listener for committed HP/Block.
## It drives the real title, route, hand, enemy targets and action row; animation
## timing is asserted as effect contract, never as node geometry.

var failures: Array[String] = []
var checks := 0
var app
var juice
var fight_seed := 0
var catalog := StarterCards.new()


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _frames() -> void:
	for frame in range(3):
		await process_frame


func _mouse(control: Control) -> void:
	if not is_instance_valid(control):
		return
	_click_now(control)
	await _frames()


## Press and release without awaiting a frame; the caller watches the result itself.
func _click_now(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _panel(id: String):
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label and panel.get_child(0).text == id:
			return panel
	return null


func _enemy_label(position: int) -> Control:
	var roster = app.get_node("LiveEnemyRoster")
	if not is_instance_valid(roster) or position < 1 or position > roster._labels.size():
		return null
	return roster._labels[position - 1]


func _attacks_in_hand() -> Array:
	var held: Array = []
	for card in app.deck.hand:
		if card in CombatAttackTargeting.ATTACK_IDS:
			held.append(card)
	return held


func _target_position(id: String) -> int:
	var preview: Dictionary = CombatAttackTargeting.new().get_preview(
		app.deck, app.party, app.enemies, id)
	if not preview.get("playable", false):
		return 0
	var positions: Array = preview.get("target_positions", [])
	return int(positions.back()) if not positions.is_empty() else 0


## First affordable single-target attack that really has a legal enemy slot.
func _strike_choice() -> String:
	for card in app.deck.hand:
		var definition := catalog.get_definition(card)
		if definition.is_empty() or definition.get("target_kind") != "enemy_single":
			continue
		if int(definition.get("cost", 99)) > 1:
			continue
		if _target_position(String(card)) > 0:
			return String(card)
	return ""


func _fight_choice() -> String:
	if app.run_map == null:
		return ""
	for id in app.run_map.get_legal_choices():
		if app.run_map.get_node(id).get("type") != "Fight":
			continue
		for button in app.route_buttons:
			if button.get_meta("route_id") == id and not button.disabled:
				return String(id)
	return ""


## Real path: physical Start -> mounted opening route -> a connected Fight node.
func _enter_fight(seed_value: int = 0) -> bool:
	var seeds: Array = [seed_value] if seed_value > 0 else range(1, 25)
	for candidate in seeds:
		app.run_seed = int(candidate)
		await _reset_to_title()
		await _mouse(app.start_button)
		await _frames()
		if app.run_map == null or not is_instance_valid(app.route_view):
			_check(false, "physical Start mounts the opening route")
			return false
		var fight_id := _fight_choice()
		if fight_id.is_empty():
			await _reset_to_title()
			continue
		var button: Button = null
		for route in app.route_buttons:
			if route.get_meta("route_id") == fight_id:
				button = route
		await _mouse(button)
		await _frames()
		if app.deck != null and app.party != null and app.enemies != null \
				and is_instance_valid(app.battle_view):
			fight_seed = int(candidate)
			if _attacks_in_hand().size() >= 2 and not _strike_choice().is_empty() \
					and _has_duplicate(app.deck.hand):
				return true
		await _reset_to_title()
	_check(false, "a seeded live fight offers two held attacks and duplicate card copies")
	return false


## Leaves a mounted fight, a route or the title through the app's own controls.
func _reset_to_title() -> void:
	if app.deck == null and app.run_map == null and is_instance_valid(app.title_view) \
			and app.title_view.is_visible_in_tree():
		return
	app._return_to_title()
	await _frames()


func _leave_fight(check_presenter: bool = true) -> void:
	if not is_instance_valid(app.return_button):
		return
	if app.return_button.disabled:
		app._return_to_title()
	else:
		await _mouse(app.return_button)
	await _frames()
	_check(app.title_view.is_visible_in_tree() and app.deck == null, "Return leaves a clean title")
	if check_presenter and is_instance_valid(juice):
		_check(not juice.bound and juice.overlay == null and juice.history.is_empty()
			and juice.live_cues() == 0 and juice.flight_history.is_empty()
			and juice.live_flights() == 0 and juice.pose_history.is_empty()
			and juice._phase_marker.is_empty(),
			"Return drops the binding and every cue history")


func _state() -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(), app.deck.hand.duplicate(),
		app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(), app.deck.energy,
		app.deck.turn_active, app.run_rng.seed, app.run_rng.state,
		app.enemy_intents.get_intents(), app.enemy_attacks.duplicate(true),
		app.enemy_intents._turn_index, app.battle_result.get_outcome(),
		app.session_gold, app.victory_gold.is_claimed() if app.victory_gold != null else false]


func _actors() -> Dictionary:
	var out := {}
	for hero in app.party.get_heroes():
		out["hero:" + String(hero["id"])] = {"side": "hero", "position": int(hero["position"]),
			"id": String(hero["id"]), "hp": int(hero["hp"]), "block": int(hero["block"])}
	for enemy in app.enemies.get_enemies():
		out["enemy:" + String(enemy["id"])] = {"side": "enemy", "position": int(enemy["position"]),
			"id": String(enemy["id"]), "hp": int(enemy["hp"]), "block": int(enemy["block"])}
	return out


func _changed(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var changed: Array[Dictionary] = []
	for key in before:
		if not after.has(key):
			continue
		var was: Dictionary = before[key]
		var now: Dictionary = after[key]
		var hp_delta: int = int(now["hp"]) - int(was["hp"])
		var block_delta: int = int(now["block"]) - int(was["block"])
		if hp_delta == 0 and block_delta == 0:
			continue
		changed.append({"side": now["side"], "position": now["position"], "id": now["id"],
			"hp": hp_delta, "block": block_delta})
	return changed


func _signature(records: Array) -> Array:
	var out: Array = []
	for record in records:
		out.append("%s:%d:%s:%d:%d" % [record["side"], int(record["position"]), record["id"],
			int(record["hp"]), int(record["block"])])
	out.sort()
	return out


## Every committed change announced once, and no cue without a matching real change.
func _assert_cues_match(announced: Array, changed: Array, message: String) -> void:
	_check(_signature(announced) == _signature(changed), message)



func _card_counts(cards: Array) -> Dictionary:
	var counts := {}
	for card in cards:
		var id := String(card)
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


func _has_duplicate(cards: Array) -> bool:
	for amount in _card_counts(cards).values():
		if int(amount) >= 2:
			return true
	return false


func _receipt_counts(receipts: Array) -> Dictionary:
	var ids: Array = []
	for receipt in receipts:
		ids.append(String(receipt["card_id"]))
	return _card_counts(ids)


func _discard_gains(before: Array, after: Array) -> Dictionary:
	var first := _card_counts(before)
	var second := _card_counts(after)
	var gained := {}
	for id in second:
		var amount: int = int(second[id]) - int(first.get(id, 0))
		if amount > 0:
			gained[id] = amount
	return gained


func _assert_flight_art(id: String, duration_limit: float) -> void:
	_check(juice.live_flights() > 0 and not juice._flights.is_empty(),
		"a committed discard has a mounted, moving scrap")
	if juice._flights.is_empty():
		return
	var flight: Dictionary = juice._flights.back()
	var scrap = flight.get("scrap")
	_check(is_instance_valid(scrap) and flight.get("target") == app.pile_label
		and is_instance_valid(app.pile_label) and app.pile_label.is_visible_in_tree(),
		"the flying card targets the real visible discard readout")
	if not is_instance_valid(scrap):
		return
	var name_label := scrap.get_node_or_null("FlightCardName") as Label
	var felt := scrap.get_node_or_null("OwnerFelt") as ColorRect
	var stitches: Array = scrap.get_children().filter(func(node: Node) -> bool:
		return node is Label and String(node.text).contains("×"))
	var ink := Color("#282525")
	_check(name_label != null and name_label.text == id.replace("_", " ").capitalize(),
		"flight face spells the committed card ID")
	_check(name_label != null and name_label.get_theme_color("font_color") == ink,
		"flight face uses readable dark ink")
	_check(felt != null and felt.color == juice._owner_color(id),
		"flight face shows its owner's felt palette")
	_check(stitches.size() == 2, "flight face has two visible cross-stitch seams")
	_check(scrap.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and scrap.focus_mode == Control.FOCUS_NONE
		and name_label != null and name_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and name_label.focus_mode == Control.FOCUS_NONE
		and felt != null and felt.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and felt.focus_mode == Control.FOCUS_NONE
		and juice.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"flying scrap and its contents cannot steal pointer or keyboard focus")
	_check(scrap.get_parent() == juice.overlay and flight["tween"].is_running()
		and float(juice.flight_history.back()["duration"]) <= duration_limit,
		"visible scrap has a running bounded animation on the existing overlay")


func _wait_cues(known: int) -> bool:
	for attempt in range(120):
		if juice.history.size() > known:
			return true
		await process_frame
	return false


func _roster():
	return app.get_node_or_null("LiveEnemyRoster")


## The authored owner hero of one card ID, read from the shipped catalog and matched to
## the authoritative party ID (never to a slot, panel or screen position).
func _owner_of(card_id: String) -> String:
	var authored := String(catalog.get_definition(card_id).get("owner", ""))
	if authored.is_empty():
		return ""
	for hero in app.party.get_heroes():
		if String(hero["id"]) == authored:
			return authored
	return ""


func _hero_puppet(actor_id: String) -> Control:
	var roster = _roster()
	if roster == null or actor_id.is_empty():
		return null
	for puppet in roster._puppets:
		if puppet.facing > 0.0 and puppet.actor_id == actor_id:
			return puppet
	return null


## Every mounted actor target, pinned name, intent badge and action control rectangle a
## committed pose must never move.
func _presentation() -> Dictionary:
	var out := {}
	var roster = _roster()
	if roster == null or not is_instance_valid(roster.panel):
		return out
	for puppet in roster._puppets:
		out["puppet:" + String(puppet.name)] = puppet.get_global_rect()
	for tag in roster._hero_tags:
		out["tag:" + String(tag.name)] = [tag.get_global_rect(), tag.text]
	for label in roster._labels:
		out["label:" + String(label.name)] = [label.get_global_rect(), label.text]
	for badge in roster._badges:
		out["badge:" + String(badge.name)] = [badge.get_global_rect(), badge.readable_text]
	out["panel"] = roster.panel.get_global_rect()
	out["hand"] = app.hand_view.get_global_rect()
	out["end_turn"] = app.end_turn_button.get_global_rect()
	out["return"] = app.return_button.get_global_rect()
	return out


## AC1/AC2: one committed card hit performs the owning hero's own authored attack pose
## for one bounded span, then returns exactly to its resting artwork. Target/name/intent
## geometry and every combat value stay exactly as combat left them.
func _assert_committed_pose(card_id: String, owner: String, target: int, changed: Array,
		presentation: Dictionary, puppet: Control, rest_pose: Rect2, rest_phase: float) -> void:
	_check(not juice.pose_history.is_empty(), "a committed hit records one pose receipt")
	if juice.pose_history.is_empty():
		return
	var pose: Dictionary = juice.pose_history.back()
	_check(String(pose["side"]) == "hero" and String(pose["id"]) == owner
		and String(pose["card_id"]) == card_id and pose["anchor"] == "presentation",
		"the pose names the committed card's own current hero, not a guess")
	var hero_position := 0
	for hero in app.party.get_heroes():
		if String(hero["id"]) == owner:
			hero_position = int(hero["position"])
	_check(int(pose["position"]) == hero_position and hero_position >= 1,
		"the pose source is that hero's authoritative position")
	_check(int(pose["target_position"]) == target
		and String(pose["target_id"]) == String(app.enemies.get_enemy(target)["id"]),
		"the pose names the exact enemy the committed hit landed on")
	_check(changed.size() == 1 and int(pose["hp"]) == int(changed[0]["hp"])
		and int(pose["block"]) == int(changed[0]["block"]),
		"the pose repeats the true committed HP/Block loss, never a preview value")
	_check(not bool(pose["fast"]) and float(pose["duration"]) > 0.0
		and float(pose["duration"]) <= 0.6,
		"a normal committed pose is bounded to at most 0.6 s")
	_check(is_instance_valid(puppet) and puppet.attacking()
		and is_equal_approx(puppet.attack_span, float(pose["duration"]))
		and puppet.attack_span <= 0.6,
		"the owning hero puppet really performs that bounded lunge")
	_check(_presentation() == presentation,
		"the committed pose moves no actor target, pinned name, intent badge or action")
	if not is_instance_valid(puppet):
		return
	_check(puppet.attack_texture != null and puppet.pose_texture() == puppet.attack_texture
		and puppet.attack_texture.resource_path == puppet.idle_texture.resource_path.trim_suffix(".png") + "_attack.png",
		"the pose draws that hero's own authored attack image")
	var settled := _state()
	puppet._process(puppet.ATTACK_MAX_SECONDS)
	_check(not puppet.attacking() and puppet.pose_texture() == puppet.current_texture(),
		"the committed pose ends by itself within 0.6 s and returns to idle art")
	puppet.idle_phase = rest_phase
	_check(puppet.posed_actor_rect() == rest_pose,
		"the finished pose puts the hero's artwork back exactly where it rested")
	_check(_state() == settled,
		"settling the pose mutates no HP, deck, energy, RNG, intent or settlement value")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var listeners: Array = []
	for child in app.get_children():
		if child.name == "LiveCombatJuice":
			listeners.append(child)
	_check(listeners.size() == 1, "exactly one battle-independent LiveCombatJuice node")
	if listeners.size() != 1:
		app.free()
		_finish()
		return
	juice = listeners[0]
	_check(juice.get_parent() == app and not juice.bound and juice.overlay == null
		and juice.history.is_empty() and juice.live_cues() == 0,
		"title has no battle binding, overlay, snapshot or cue")
	_check(juice.pose_history.is_empty() and juice._phase_marker.is_empty(),
		"the title owns no pose receipt and no stale turn boundary")
	_check(not is_instance_valid(juice.fast_button), "no Fast toggle before a battle mounts")
	await _commit_attack()
	await _keyboard_pose()
	await _non_damaging_play()
	await _ambiguous_cast()
	await _end_turn()
	await _hidden_discard_destination()
	await _closed_battle()
	await _fast_mode()
	await _teardown_and_reentry()
	await _settlement_parity()
	if is_instance_valid(app):
		app.free()
	_finish()


func _assert_presenter_mounted() -> void:
	_check(juice.bound and juice.bind_serial >= 1, "the listener binds after the real fight mounts")
	_check(juice.history.is_empty() and juice.live_cues() == 0
		and juice.flight_history.is_empty() and juice.live_flights() == 0,
		"mounting a fight fabricates no combat or card-flight cue")
	_check(is_instance_valid(juice.fast_button) and juice.fast_button.is_visible_in_tree()
		and juice.fast_button.get_parent() == app.action_corner_row
		and app.action_corner.is_ancestor_of(juice.fast_button)
		and app.action_corner.is_ancestor_of(app.return_button)
		and not app.action_corner.is_ancestor_of(app.end_turn_button),
		"Fast keeps its real Button in the compact sewn corner beside Return")
	_check(app.find_children("FastAnimationsButton", "Button", true, false).size() == 1,
		"exactly one Fast animations toggle")


## AC1: a legal held attack's committed target HP/Block delta, drawn once, pointer-inert.
## AC1/AC2 pose: the owning hero puppet lunges with its own attack pose and returns.
func _commit_attack() -> void:
	if not await _enter_fight():
		return
	_assert_presenter_mounted()
	var id := _strike_choice()
	var position := _target_position(id)
	_check(not id.is_empty() and position > 0, "a held attack has a really legal enemy slot")
	var panel = _panel(id)
	_check(panel != null, "the live hand really holds " + id)
	if panel == null or position <= 0:
		await _leave_fight()
		return
	var owner := _owner_of(id)
	var owner_puppet := _hero_puppet(owner)
	_check(not owner.is_empty() and String(catalog.get_definition(id).get("owner", "")) == owner
		and is_instance_valid(owner_puppet) and not owner_puppet.fallen,
		"the committed card has one authored, living hero owner with a mounted puppet")
	var presentation := _presentation()
	var poses_before: int = juice.pose_history.size()
	var rest_pose: Rect2 = owner_puppet.posed_actor_rect() if is_instance_valid(owner_puppet) else Rect2()
	var rest_phase: float = owner_puppet.idle_phase if is_instance_valid(owner_puppet) else 0.0
	_check(not is_instance_valid(owner_puppet) or not owner_puppet.attacking(),
		"every hero puppet is at plain idle before the committed hit")
	# Real Block on the target, so one committed hit shows both HP and Block deltas.
	_check(app.enemies.gain_block(position, 2), "target holds real Block before the strike")
	await _frames()
	var known: int = juice.history.size()
	var before := _actors()
	var hand_before: Array = app.deck.hand.duplicate()
	var discard_before: Array = app.deck.discard_pile.duplicate()
	var flights_before: int = juice.flight_history.size()
	_check(juice._held_sources.size() == hand_before.size(),
		"each held card copy has a mounted cached source before committing")
	seed(8123)
	var global_next := randi()
	seed(8123)
	var motion := InputEventMouseMotion.new()
	motion.position = panel.get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames()
	_check(juice.flight_history.size() == flights_before, "hover alone creates no flight")
	await _mouse(panel)
	_check(juice.flight_history.size() == flights_before and app.deck.hand == hand_before,
		"a queued target/preview has no discard flight")
	_check(juice.pose_history.size() == poses_before, "a queued target/preview fabricates no hero pose")
	await _mouse(_enemy_label(position))
	await _frames()
	_check(randi() == global_next, "committed play through the listener draws no global RNG")
	var after := _actors()
	_check(hand_before.size() == app.deck.hand.size() + 1
		and _discard_gains(discard_before, app.deck.discard_pile) == _card_counts([id])
		and juice.flight_history.size() == flights_before + 1
		and _receipt_counts(juice.flight_history.slice(flights_before)) == _card_counts([id]),
		"one genuinely consumed held copy and gained discard yields exactly one receipt")
	if juice.flight_history.size() > flights_before:
		_assert_flight_art(id, 0.6)
	var changed := _changed(before, after)
	_check(changed.size() == 1 and changed[0]["side"] == "enemy"
		and int(changed[0]["position"]) == position and int(changed[0]["block"]) == -2,
		"the committed strike changes exactly the real target's HP and Block")
	_check(juice.pose_history.size() == poses_before + 1,
		"one committed held enemy hit starts exactly one hero attack pose")
	if juice.pose_history.size() == poses_before + 1:
		_assert_committed_pose(id, owner, position, changed, presentation,
			owner_puppet, rest_pose, rest_phase)
	var announced: Array = juice.history.slice(known)
	_check(announced.size() == 1, "one committed strike announces exactly one cue")
	if announced.size() == 1:
		_assert_cues_match(announced, changed, "the cue repeats the true target HP/Block delta")
		var cue: Dictionary = announced[0]
		_check(cue["anchor"] == "presentation", "cue anchors to the current actor presentation")
		_check(not cue["fast"] and float(cue["duration"]) <= 0.6,
			"normal cue lasts at most 0.6 s")
		_check(String(cue["text"]).contains("%d HP" % int(cue["hp"]))
			and String(cue["text"]).contains("Block %d" % int(cue["block"])),
			"float text names the exact HP and Block deltas")
	_check(juice.live_cues() > 0, "the cue is really on screen right after the hit")
	var roster = app.get_node("LiveEnemyRoster")
	var puppet = roster.panel.find_child("EnemyPuppet%d" % position, true, false) as Control
	_check(is_instance_valid(puppet) and juice._cues.back().get("target") == puppet,
		"the cue is anchored to the target enemy's live presentation")
	await _assert_inert_cues()
	# A missing presentation falls back to the matching live combat meter.
	if is_instance_valid(puppet):
		puppet.hide()
		roster._labels[position - 1].hide()
		_check(app.enemies.gain_block(position, 1), "a real committed Block change for the fallback")
		await _frames()
		var fallback: Dictionary = juice.history.back()
		_check(fallback["anchor"] == "meter" and int(fallback["block"]) == 1,
			"a missing presentation falls back to the live combat meter")
		var meter = app.get_node("LiveCombatMeters").row.get_child(CombatParty.PARTY_SIZE + position - 1)
		_check(juice._cues.back().get("target") == meter,
			"the fallback cue is anchored to that actor's own meter")
		puppet.show()
		roster._labels[position - 1].show()
		await _frames()
	# A wholly missing presentation drops the snapshot instead of inventing a cue.
	var meters = app.get_node("LiveCombatMeters")
	for slot in app.hero_panels:
		slot.hide()
	_check(is_instance_valid(meters.row), "live meter row exists for the missing-presentation case")
	if is_instance_valid(meters.row):
		meters.row.hide()
		var missing_before: int = juice.history.size()
		_check(app.enemies.gain_block(position, 1), "a committed change while every presentation is hidden")
		await _frames()
		_check(juice.history.size() == missing_before and juice.live_cues() == 0,
			"a missing presentation fabricates no cue")
		var stored: Dictionary = juice._snapshot.get("enemy:" + String(app.enemies.get_enemy(position)["id"]), {})
		_check(int(stored.get("block", -1)) == int(app.enemies.get_enemy(position)["block"]),
			"a missing presentation rebaselines instead of replaying the gap")
		for slot in app.hero_panels:
			slot.show()
		meters.row.show()
		await _frames()
	# The listener keeps polling: the same committed state never announces again.
	known = juice.history.size()
	var settled := _state()
	var settled_poses: int = juice.pose_history.size()
	app._refresh_party()
	app._refresh_intents()
	app._refresh_enemy_roster()
	for repeat in range(6):
		app._process(0.0)
	await _frames()
	_check(juice.history.size() == known, "refresh and repeated polling never duplicate a cue")
	_check(juice.pose_history.size() == settled_poses,
		"refresh and repeated polling never replay a committed pose")
	_check(_state() == settled, "presentation polling preserves completely unchanged state")
	await _mouse(_enemy_label(position))
	await _mouse(_enemy_label(position))
	await _frames()
	_check(juice.pose_history.size() == settled_poses and juice.flight_history.size() == flights_before + 1,
		"duplicate target clicks after the committed hit fabricate no second pose")
	# A failed card play (no energy) must not fabricate a cue.
	var energy: int = app.deck.energy
	app.deck.combat_state.energy = 0
	var held := _attacks_in_hand()
	_check(not held.is_empty() and _panel(String(held[0])) != null,
		"a held attack remains for the rejected-play check")
	var failed_state := _state()
	var poses_before_failure: int = juice.pose_history.size()
	await _mouse(_panel(String(held[0])))
	await _mouse(_enemy_label(_target_position(String(held[0])) if _target_position(String(held[0])) > 0 else 1))
	await _frames()
	_check(juice.history.size() == known, "a rejected card play fabricates no cue")
	_check(juice.pose_history.size() == poses_before_failure,
		"a rejected card play fabricates no hero attack pose")
	_check(juice.flight_history.size() == flights_before + 1,
		"no-energy rejected play adds no discard flight")
	_check(_state() == failed_state, "a rejected card play changes no combat value")
	app.deck.combat_state.energy = energy
	await _leave_fight()


## AC1: the same committed pose follows a real keyboard card play (P arms the held
## attack, the target digit commits it), so the trigger is not tied to the pointer.
func _keyboard_pose() -> void:
	if not await _enter_fight(fight_seed):
		return
	_assert_presenter_mounted()
	var id := _strike_choice()
	var position := _target_position(id)
	var panel = _panel(id)
	_check(not id.is_empty() and position > 0 and panel != null,
		"a held attack is really playable for the keyboard pose")
	if panel == null or position <= 0:
		await _leave_fight()
		return
	var owner := _owner_of(id)
	var puppet := _hero_puppet(owner)
	var presentation := _presentation()
	var poses_before: int = juice.pose_history.size()
	var rest_pose: Rect2 = puppet.posed_actor_rect() if is_instance_valid(puppet) else Rect2()
	var rest_phase: float = puppet.idle_phase if is_instance_valid(puppet) else 0.0
	var preview = app.get_node_or_null("LiveAttackPreview")
	_check(is_instance_valid(preview), "the mounted live attack preview owns card selection")
	if not is_instance_valid(preview):
		await _leave_fight()
		return
	var armed := false
	for attempt in range(app.deck.hand.size() + 2):
		await _key(KEY_P)
		if String(preview._card_id(preview._armed)) == id:
			armed = true
			break
	_check(armed, "P really arms the held attack for a keyboard play")
	if not armed:
		await _leave_fight()
		return
	var before := _actors()
	await _key([KEY_1, KEY_2, KEY_3][position - 1])
	await _frames()
	_check(_actors() != before, "the keyboard target digit commits a real attack")
	_check(juice.pose_history.size() == poses_before + 1,
		"a genuinely committed keyboard card play triggers exactly one pose")
	if juice.pose_history.size() == poses_before + 1:
		_assert_committed_pose(id, owner, position, _changed(before, _actors()),
			presentation, puppet, rest_pose, rest_phase)
	await _leave_fight()


## AC3: an area cast is never one unambiguous held hit, whether it changes several actors
## or legally damages only one surviving enemy: it keeps its committed HP cue and card
## flight but never fabricates a single-source hero pose.
func _ambiguous_cast() -> void:
	if not await _enter_fight(fight_seed):
		return
	_assert_presenter_mounted()
	app.deck.hand.assign(["tinker_scrap_bomb"])
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	var panel = _panel("tinker_scrap_bomb")
	_check(panel != null and panel.gui_input.get_connections().size() == 1,
		"the controlled held area card is mounted on the real shared hand")
	if panel == null:
		await _leave_fight()
		return
	var preview = app.get_node_or_null("LiveAttackPreview")
	var armed := false
	if is_instance_valid(preview):
		for attempt in range(app.deck.hand.size() + 2):
			await _key(KEY_P)
			if String(preview._card_id(preview._armed)) == "tinker_scrap_bomb":
				armed = true
				break
	_check(armed, "P really arms the held area card")
	if not armed:
		await _leave_fight()
		return
	var poses_before: int = juice.pose_history.size()
	var cues_before: int = juice.history.size()
	var hand_before: Array = app.deck.hand.duplicate()
	var discard_before: Array = app.deck.discard_pile.duplicate()
	var before := _actors()
	await _key(KEY_SPACE)
	await _frames()
	var changed := _changed(before, _actors())
	_check(changed.size() >= 2 and hand_before.size() == app.deck.hand.size() + 1
		and _discard_gains(discard_before, app.deck.discard_pile) == _card_counts(
			["tinker_scrap_bomb"]),
		"the area cast really commits one held copy and hits more than one actor")
	_check(juice.history.size() > cues_before,
		"the area cast still announces its own committed HP cues")
	_check(juice.pose_history.size() == poses_before,
		"a multi-actor area cast fabricates no single-source attack pose")
	# A real enemy_all cast can legally damage exactly ONE surviving enemy. The listener
	# must still fail closed: the card's authored target kind is enemy_all, never the
	# number of actors its commit happened to change. Keep one enemy alive with enough
	# HP to survive the bomb, then commit the same held card from the real keyboard hand.
	var living: Array = []
	for enemy in app.enemies.get_enemies():
		if int(enemy["hp"]) > 0:
			living.append(enemy)
	living.sort_custom(func(a, b) -> bool: return int(a["hp"]) > int(b["hp"]))
	_check(living.size() >= 2, "the fight still has several living enemies to clear")
	if living.size() < 2:
		await _leave_fight()
		return
	var survivor := int(living[0]["position"])
	for enemy in living:
		if int(enemy["position"]) == survivor:
			continue
		app.enemies.apply_damage(int(enemy["position"]),
			int(enemy["hp"]) + int(enemy["block"]))
	app._refresh_enemy_roster()
	app._refresh_party()
	app.deck.hand.assign(["tinker_scrap_bomb"])
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	_check(not app._battle_closed and not app.enemies.is_slain(survivor)
		and int(app.enemies.get_enemy(survivor)["hp"]) > 4,
		"the single area recipient survives the 4-damage bomb")
	if app._battle_closed or app.enemies.is_slain(survivor):
		await _leave_fight()
		return
	var survivor_puppet := _hero_puppet(_owner_of("tinker_scrap_bomb"))
	_check(is_instance_valid(survivor_puppet) and not survivor_puppet.attacking(),
		"Tinker's mounted puppet is at plain idle before the single-survivor cast")
	var single_preview = app.get_node_or_null("LiveAttackPreview")
	var armed_single := false
	if is_instance_valid(single_preview):
		for attempt in range(app.deck.hand.size() + 2):
			await _key(KEY_P)
			if String(single_preview._card_id(single_preview._armed)) == "tinker_scrap_bomb":
				armed_single = true
				break
	_check(armed_single, "P really arms the held area card for the single-survivor cast")
	if not armed_single:
		await _leave_fight()
		return
	var single_before := _actors()
	var single_poses_before: int = juice.pose_history.size()
	var single_cues_before: int = juice.history.size()
	var single_flights_before: int = juice.flight_history.size()
	var single_hand_before: Array = app.deck.hand.duplicate()
	var single_discard_before: Array = app.deck.discard_pile.duplicate()
	await _key(KEY_SPACE)
	await _frames()
	var single_changed := _changed(single_before, _actors())
	_check(single_changed.size() == 1 and String(single_changed[0]["side"]) == "enemy"
		and int(single_changed[0]["position"]) == survivor
		and (int(single_changed[0]["hp"]) < 0 or int(single_changed[0]["block"]) < 0),
		"the single-survivor area cast changes only that one enemy's HP or Block")
	_check(not app._battle_closed and not app.enemies.is_slain(survivor),
		"the single-survivor area cast really leaves the battle open")
	_check(single_hand_before.size() == app.deck.hand.size() + 1
		and _discard_gains(single_discard_before, app.deck.discard_pile) == _card_counts(
			["tinker_scrap_bomb"]),
		"the single-survivor area cast really discards its held copy")
	_check(juice.history.size() > single_cues_before,
		"the single-survivor area cast still announces its committed HP cue")
	_check(juice.flight_history.size() == single_flights_before + 1
		and _receipt_counts(juice.flight_history.slice(single_flights_before)) == _card_counts(
			["tinker_scrap_bomb"]) and juice.live_flights() > 0,
		"the single-survivor area cast still flies its discarded card")
	_check(juice.pose_history.size() == single_poses_before,
		"a single-survivor area cast fabricates no single-source attack pose")
	_check(not is_instance_valid(survivor_puppet) or not survivor_puppet.attacking(),
		"no hero puppet lunges for a single-survivor area cast")
	await _leave_fight()


## AC3: a non-damaging held play commits one card and one real effect, yet no enemy lost
## HP or Block, so no attack pose is fabricated for it.
func _non_damaging_play() -> void:
	if not await _enter_fight(fight_seed):
		return
	_assert_presenter_mounted()
	app.deck.hand.assign(["warden_brace"])
	app.deck.combat_state.energy = 3
	app._refresh_hand()
	await _frames()
	var panel = _panel("warden_brace")
	_check(panel != null and panel.gui_input.get_connections().size() == 1,
		"the controlled held self card is mounted with its real input binding")
	if panel == null:
		await _leave_fight()
		return
	var poses_before: int = juice.pose_history.size()
	var cues_before: int = juice.history.size()
	var hand_before: Array = app.deck.hand.duplicate()
	var discard_before: Array = app.deck.discard_pile.duplicate()
	var before := _actors()
	await _mouse(panel)
	await _frames()
	var changed := _changed(before, _actors())
	_check(hand_before.size() == app.deck.hand.size() + 1
		and _discard_gains(discard_before, app.deck.discard_pile) == _card_counts(["warden_brace"]),
		"the non-damaging play really commits one held copy")
	_check(changed.size() == 1 and String(changed[0]["side"]) == "hero"
		and int(changed[0]["block"]) > 0,
		"the non-damaging play changes only its own hero's Block")
	_check(juice.history.size() > cues_before,
		"a non-damaging play still announces its own committed Block cue")
	_check(juice.pose_history.size() == poses_before,
		"a non-damaging card play fabricates no attack pose")
	await _leave_fight()


## AC3: a committed hit that closes the battle leaves no stale or fabricated pose, and
## the closed battle never starts another one on later frames.
func _closed_battle() -> void:
	if not await _enter_fight(fight_seed):
		return
	_assert_presenter_mounted()
	var id := _strike_choice()
	var position := _target_position(id)
	_check(not id.is_empty() and position > 0, "a held attack exists for the closing hit")
	if position <= 0:
		await _leave_fight()
		return
	var owner := _owner_of(id)
	var puppet := _hero_puppet(owner)
	# Leave exactly one living enemy at one HP and no Block, so the real strike closes it.
	for enemy in app.enemies.get_enemies():
		if int(enemy["position"]) != position:
			app.enemies.apply_damage(int(enemy["position"]),
				int(enemy["hp"]) + int(enemy["block"]))
	app.enemies.apply_damage(position,
		maxi(0, int(app.enemies.get_enemy(position)["hp"])
			+ int(app.enemies.get_enemy(position)["block"]) - 1))
	app._refresh_enemy_roster()
	app._refresh_party()
	await _frames()
	_check(not app._battle_closed and not app.enemies.is_slain(position)
		and int(app.enemies.get_enemy(position)["hp"]) == 1,
		"the fixture leaves exactly one living enemy at one HP")
	var poses_before: int = juice.pose_history.size()
	await _mouse(_panel(id))
	await _mouse(_enemy_label(position))
	await _frames()
	_check(app._battle_closed and app.battle_result.get_outcome() == CombatBattleResult.VICTORY,
		"the closing committed hit really ends the fight")
	_check(juice.pose_history.size() == poses_before,
		"a hit that closes the battle fabricates no stale pose")
	_check(not is_instance_valid(puppet) or not puppet.attacking(),
		"no mounted hero keeps a lunge after the battle closes")
	await _leave_fight()


func _assert_inert_cues() -> void:
	_check(not juice._cues.is_empty(), "a live cue is recorded")
	if juice._cues.is_empty():
		return
	var entry: Dictionary = juice._cues.back()
	var flash = entry.get("flash")
	var float_label = entry.get("float")
	_check(is_instance_valid(flash) and is_instance_valid(float_label), "flash and float are mounted")
	if not is_instance_valid(flash) or not is_instance_valid(float_label):
		return
	_check(flash.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and float_label.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and juice.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"flash, float and overlay never intercept the pointer")
	_check(flash.focus_mode == Control.FOCUS_NONE and float_label.focus_mode == Control.FOCUS_NONE,
		"flash and float never take keyboard focus")
	var motion := InputEventMouseMotion.new()
	motion.position = float_label.get_global_rect().get_center()
	root.push_input(motion, true)
	await process_frame
	var hovered := root.gui_get_hovered_control()
	_check(hovered != flash and hovered != float_label and hovered != juice.overlay,
		"a real hit test passes through the cue to the battle underneath")


## AC2: a real End Turn announces exactly the committed HP/Block changes.
func _end_turn() -> void:
	if not await _enter_fight(fight_seed):
		return
	_assert_presenter_mounted()
	var known: int = juice.history.size()
	var poses_before: int = juice.pose_history.size()
	var before := _actors()
	var baseline_flights: int = juice.flight_history.size()
	_check(app.deck.draw_extra(1) == 1, "the real deck can draw one additional held copy")
	app._refresh_hand()
	await _frames()
	_check(juice.flight_history.size() == baseline_flights and juice._held_sources.size() == app.deck.hand.size(),
		"extra drawn card and refreshed hand produce no fake flight")
	var old_hand: Array = app.deck.hand.duplicate()
	var old_discard: Array = app.deck.discard_pile.duplicate()
	_check(_has_duplicate(old_hand), "the End Turn really holds multiple copies of a duplicate ID")
	await _mouse(app.end_turn_button)
	await _frames()
	var after := _actors()
	var gained := _discard_gains(old_discard, app.deck.discard_pile)
	_check(gained == _card_counts(old_hand),
		"real End Turn moved each old held ID and its duplicate count to discard")
	_check(juice.flight_history.size() == baseline_flights + old_hand.size()
		and _receipt_counts(juice.flight_history.slice(baseline_flights)) == gained,
		"End Turn flies every truly discarded card copy, duplicates included")
	_check(juice.live_flights() > 0, "End Turn scraps appear over the mounted battle")
	var changed := _changed(before, after)
	_check(not changed.is_empty(), "the real End Turn committed HP/Block changes")
	var announced: Array = juice.history.slice(known)
	_assert_cues_match(announced, changed,
		"End Turn announces one cue per committed actor and none for unchanged actors")
	_check(not announced.is_empty() and announced.size() == changed.size(),
		"End Turn never invents or repeats a cue")
	for cue in announced:
		_check(String(cue["anchor"]) in ["presentation", "meter"],
			"End Turn cue anchored to the current presentation")
	# Nothing changed after the phase: polling must stay silent.
	known = juice.history.size()
	var settled := _state()
	for repeat in range(6):
		app._process(0.0)
	await _frames()
	_check(juice.history.size() == known and _state() == settled
		and juice.flight_history.size() == baseline_flights + old_hand.size(),
		"post-phase refresh and polling add no HP/Block or discard replay")
	_check(juice.pose_history.size() == poses_before,
		"a real End Turn enemy phase fabricates no card attack pose")
	# A legitimate refill takes cards OUT of discard. It is not a new discard.
	var prior_flights: int = juice.flight_history.size()
	var prior_deck: Array = app.deck.hand + app.deck.draw_pile + app.deck.discard_pile
	_check(app.deck.turn_active and not app.deck.discard_pile.is_empty(),
		"there is an active real turn and a nonempty discard for refill")
	var refill: int = app.deck.draw_extra(app.deck.draw_pile.size() + 1)
	_check(refill > 0, "real CombatDeck draws far enough to reshuffle")
	app._refresh_hand()
	await _frames()
	var new_deck: Array = app.deck.hand + app.deck.draw_pile + app.deck.discard_pile
	prior_deck.sort()
	new_deck.sort()
	_check(prior_deck == new_deck and juice.flight_history.size() == prior_flights,
		"a genuine draw/discard reshuffle preserves cards without phantom flights")
	await _leave_fight()


## Discard commits with a hidden destination stay valid gameplay but cannot fly.
func _hidden_discard_destination() -> void:
	if not await _enter_fight(fight_seed):
		return
	var id := _strike_choice()
	var position := _target_position(id)
	_check(not id.is_empty() and position > 0, "a legal held play exists for hidden-target check")
	if position <= 0:
		await _leave_fight()
		return
	var original_hand: Array = app.deck.hand.duplicate()
	var original_discard: Array = app.deck.discard_pile.duplicate()
	app.pile_label.hide()
	await _frames()
	await _mouse(_panel(id))
	await _mouse(_enemy_label(position))
	await _frames()
	_check(original_hand.size() == app.deck.hand.size() + 1
		and _discard_gains(original_discard, app.deck.discard_pile) == _card_counts([id]),
		"a hidden destination does not cancel or invent the real card transaction")
	_check(juice.flight_history.is_empty() and juice.live_flights() == 0,
		"no card flight is fabricated when its discard readout is hidden")
	app.pile_label.show()
	await _frames()
	_check(juice.flight_history.is_empty(), "reappearing discard counter cannot replay a missed cue")
	await _leave_fight()


## AC3: mouse and Tab/Space reach a fast mode that really shortens the effect.
func _fast_mode() -> void:
	if not await _enter_fight(fight_seed):
		return
	var button: Button = juice.fast_button
	_check(not juice.fast_animations and juice.duration_seconds() <= 0.6
		and button.text == "Fast: Off", "normal mode by default")
	var before_toggle := _state()
	await _mouse(button)
	_check(juice.fast_animations and juice.duration_seconds() <= 0.15
		and button.text == "Fast: On", "mouse reaches a fast mode of at most 0.15 s")
	_check(_state() == before_toggle, "toggling fast changes no combat state")
	_check(not app.end_turn_button.disabled, "fast mode never locks the End Turn action")
	# A real attack in fast mode commits normally and keeps its cue for at most 0.15 s.
	var id := _strike_choice()
	var position := _target_position(id)
	var known: int = juice.history.size()
	var known_flights: int = juice.flight_history.size()
	var poses_before: int = juice.pose_history.size()
	await _mouse(_panel(id))
	_click_now(_enemy_label(position))
	var fast_started := false
	for attempt in range(8):
		await process_frame
		if juice.history.size() > known:
			fast_started = true
			break
	_check(fast_started and juice.live_cues() > 0,
		"fast mode still announces the committed hit on screen")
	var announced: Array = juice.history.slice(known)
	_check(announced.size() == 1 and bool(announced[0]["fast"])
		and float(announced[0]["duration"]) <= 0.15, "fast cues are recorded at 0.15 s or less")
	_check(juice.pose_history.size() == poses_before + 1
		and bool(juice.pose_history.back()["fast"])
		and float(juice.pose_history.back()["duration"]) <= 0.15,
		"a fast committed hit poses the owning hero for at most 0.15 s")
	var pose_puppet: Control = _hero_puppet(String(juice.pose_history.back()["id"])) \
		if juice.pose_history.size() > poses_before else null
	_check(not is_instance_valid(pose_puppet) or pose_puppet.attack_span <= 0.15,
		"the mounted fast pose is bounded by the fast span")
	_check(juice.flight_history.size() == known_flights + 1
		and juice.live_flights() == 1
		and _receipt_counts(juice.flight_history.slice(known_flights)) == _card_counts([id])
		and bool(juice.flight_history.back()["fast"]),
		"fast-mode play emits one actual discard flight")
	if juice.live_flights() > 0:
		_assert_flight_art(id, 0.15)
	var flight_sprite = juice._flights.back().get("scrap") if not juice._flights.is_empty() else null
	var cue_nodes: Array = []
	if not juice._cues.is_empty():
		cue_nodes = [juice._cues.back().get("float"), juice._cues.back().get("flash")]
	_check(juice.live_cues() > 0, "the fast cue really starts on screen")
	await create_timer(0.25).timeout
	_check(juice.live_cues() == 0 and juice.live_flights() == 0,
		"hit and flying card finish within 0.25 s in Fast mode")
	_check(not is_instance_valid(pose_puppet) or not pose_puppet.attacking(),
		"the fast hero pose really ends within 0.25 s")
	_check(not is_instance_valid(flight_sprite), "the fast card's scrap is really freed")
	for node in cue_nodes:
		_check(not is_instance_valid(node), "a finished cue frees its nodes")
	# Keyboard: End Turn still tabs to Return, then the toggle; Space switches back.
	app.end_turn_button.grab_focus()
	await _key(KEY_TAB)
	_check(app.return_button.has_focus(), "End Turn still tabs to Return")
	await _key(KEY_TAB)
	_check(button.has_focus(), "Tab reaches the Fast animations toggle")
	var before_key := _state()
	await _key(KEY_SPACE)
	_check(not juice.fast_animations and juice.duration_seconds() <= 0.6
		and button.text == "Fast: Off", "Space returns to normal-speed cues")
	_check(_state() == before_key, "keyboard toggling changes no combat state")
	# Normal mode gameplay is not gated by the previous fast cue either.
	var normal_state := _state()
	var held := _attacks_in_hand()
	_check(not held.is_empty(), "a second attack is still held after the toggle")
	if not held.is_empty() and _target_position(String(held[0])) > 0:
		await _mouse(_panel(String(held[0])))
		await _mouse(_enemy_label(_target_position(String(held[0]))))
		await _frames()
		_check(_state() != normal_state, "a normal-speed attack still commits immediately")
	await _leave_fight()


## AC3: Return drops every cue and snapshot; a fresh fight rebinds exactly once.
func _teardown_and_reentry() -> void:
	if not await _enter_fight(fight_seed):
		return
	var id := _strike_choice()
	var known: int = juice.history.size()
	await _mouse(_panel(id))
	await _mouse(_enemy_label(_target_position(id)))
	await _frames()
	var live := await _wait_cues(known)
	_check(live and juice.live_cues() > 0 and juice.live_flights() > 0
		and juice.flight_history.size() == 1, "a hit and one card flight are live before Return")
	_check(juice.pose_history.size() == 1, "a live committed pose is recorded before Return")
	var posed: Control = _hero_puppet(String(juice.pose_history.back()["id"])) \
		if not juice.pose_history.is_empty() else null
	_check(is_instance_valid(posed) and posed.attacking(),
		"the owning hero is really mid-lunge before Return")
	var serial: int = juice.bind_serial
	var overlay_id: int = juice.overlay.get_instance_id()
	var sprite_ids: Array = []
	for entry in juice._flights:
		var scrap = entry.get("scrap")
		if is_instance_valid(scrap):
			sprite_ids.append(scrap.get_instance_id())
	for entry in juice._cues:
		for key in ["float", "flash"]:
			var node = entry.get(key)
			if is_instance_valid(node):
				sprite_ids.append(node.get_instance_id())
	await _mouse(app.return_button)
	await _frames()
	_check(app.deck == null and juice.overlay == null and juice.live_cues() == 0
		and juice.live_flights() == 0 and juice.flight_history.is_empty()
		and juice._held_before.is_empty() and juice._discard_before.is_empty()
		and juice._draw_before.is_empty() and juice._held_sources.is_empty()
		and juice.history.is_empty() and juice.pose_history.is_empty()
		and juice._phase_marker.is_empty() and not juice.bound and juice._snapshot.is_empty(),
		"Return clears the snapshot, overlay and every cue")
	_check(not is_instance_valid(posed) or not posed.attacking(),
		"Return ends the mounted pose instead of leaving a stale lunge")
	_check(not is_instance_id_valid(overlay_id), "the old overlay is really freed")
	_check(juice.history.is_empty(), "Return clears the committed cue log")
	var all_freed := true
	for instance_id in sprite_ids:
		if is_instance_id_valid(int(instance_id)):
			all_freed = false
	_check(all_freed, "old cue nodes are freed on teardown")
	_check(not is_instance_valid(juice.fast_button) or not juice.fast_button.is_visible_in_tree(),
		"the old action row toggle is gone with its battle")
	if not await _enter_fight(fight_seed):
		return
	_check(juice.bind_serial == serial + 1, "a fresh fight rebinds exactly once")
	_check(juice.history.is_empty() and juice.live_cues() == 0
		and juice.flight_history.is_empty() and juice.live_flights() == 0
		and juice.pose_history.is_empty(),
		"fresh reentry starts without any stale hit, card flight or hero pose")
	_check(app.find_children("FastAnimationsButton", "Button", true, false).size() == 1,
		"fresh reentry mounts exactly one Fast animations toggle")
	await _leave_fight()


## AC1: identical combat, deck, RNG and settlement with and without the presenter.
func _settlement_parity() -> void:
	var seed_value: int = fight_seed
	app.free()
	juice = null
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var with_juice := await _scripted_trace(seed_value)
	app.free()
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var listener = app.get_node_or_null("LiveCombatJuice")
	_check(listener != null, "the real scene mounts the listener")
	if listener != null:
		app.remove_child(listener)
		listener.free()
	var without := await _scripted_trace(seed_value)
	_check(not with_juice.is_empty() and with_juice == without,
		"identical combat, deck, RNG and settlement without the presenter")
	await _leave_fight(false)


func _scripted_trace(seed_value: int) -> Array:
	var trace: Array = []
	if not await _enter_fight(seed_value):
		return trace
	trace.append(_state())
	var id := _strike_choice()
	var position := _target_position(id)
	if id.is_empty() or position <= 0:
		return trace
	await _mouse(_panel(id))
	await _mouse(_enemy_label(position))
	await _frames()
	trace.append(_state())
	await _mouse(app.end_turn_button)
	await _frames()
	trace.append(_state())
	# The real settlement boundary: the last enemy falls, the app settles gold and
	# prepares this fight's reward, exactly as a committed lethal card would.
	for enemy in app.enemies.get_enemies():
		if int(enemy["hp"]) + int(enemy["block"]) > 0:
			app.enemies.apply_damage(int(enemy["position"]), int(enemy["hp"]) + int(enemy["block"]))
	app._observe_battle_result()
	await _frames()
	_check(app._battle_closed and app.battle_result.get_outcome() == CombatBattleResult.VICTORY,
		"scripted parity run really settles a victory")
	_check(is_instance_valid(app.reward_choice_panel) and not app.fight_reward_offers.is_empty(),
		"scripted parity run prepares the real fight reward")
	trace.append([_state(), app.fight_reward_gold, app.fight_reward_offers.size(),
		app.fight_reward_claimed, is_instance_valid(app.reward_choice_panel),
		app.result_label.text if is_instance_valid(app.result_label) else ""])
	return trace


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_combat_juice_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
