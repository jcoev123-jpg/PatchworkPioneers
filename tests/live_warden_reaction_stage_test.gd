extends SceneTree
## Mounted read-only Warden reaction stage: genuine paid hand and announced enemy attacks.

const IDS := [
	"warden_draw_fire", "warden_draw_fire_plus",
	"warden_counter_stitch", "warden_counter_stitch_plus",
]
var failures: Array[String] = []
var checks := 0
var app
var stage
var hand_adapter
var catalog := WardenPoolCards.new()


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)


func _frames() -> void:
	await process_frame
	await process_frame


func _snapshot() -> Array:
	return [
		app.deck.draw_pile.duplicate(true), app.deck.hand.duplicate(true),
		app.deck.discard_pile.duplicate(true), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_intents.get_intents(), app.enemy_attacks.duplicate(true),
		app.run_rng.seed, app.run_rng.state, app.deck._rng.state,
		app.battle_result.get_outcome(), app.round_flow._reactions.is_guarding()
			if app.round_flow._reactions != null else false,
		app.round_flow._reactions.get_thorns()
			if app.round_flow._reactions != null else 0,
	]


func _panel(card_id: String) -> Control:
	for node: Node in app.hand_view.get_children():
		if node is Control and node.get_child_count() > 0 and node.get_child(0) is Label \
				and (node.get_child(0) as Label).text == card_id:
			return node as Control
	return null


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _pay(card_id: String) -> bool:
	# Earned pool cards enter the real deck draw, never a synthetic card button.
	app.deck.draw_pile.append(card_id)
	_check(app.deck.draw_extra(1) == 1, "real deck drew " + card_id)
	app._refresh_hand()
	await _frames()
	var panel := _panel(card_id)
	var valid: bool = panel != null and hand_adapter._bindings.has(panel) \
		and panel.is_visible_in_tree() and panel.get_index() < app.deck.hand.size() \
		and app.deck.hand[panel.get_index()] == card_id
	_check(valid, "real Warden held panel and authenticated listener: " + card_id)
	if not valid:
		return false
	panel.grab_focus()
	_check(panel.has_focus(), "keyboard can focus " + card_id)
	var before_energy: int = app.deck.energy
	var before_block: int = int(_warden().get("block", -1))
	var before_rng: int = app.run_rng.state
	var before_heroes: Array = app.party.get_heroes()
	hand_adapter._on_card_input(_key(KEY_ENTER), panel, card_id)
	await _frames()
	var definition: Dictionary = catalog.get_definition(card_id)
	var accepted: bool = app.deck.energy == before_energy - 1 \
		and app.deck.discard_pile.has(card_id) and not app.deck.hand.has(card_id)
	_check(accepted, "authenticated held play spends exactly 1 and discards " + card_id)
	_check(app.run_rng.state == before_rng, "reaction play does not roll run RNG " + card_id)
	var warden_position: int = int(_warden().get("position", 0))
	_check(int(_warden().get("block", -1)) == before_block + int(definition.effects.block),
		"exact catalog Block applied for " + card_id)
	for hero in before_heroes:
		if hero.id != "warden":
			_check(app.party.get_hero(hero.position) == hero,
				"other hero untouched by " + card_id)
	_check(warden_position in definition.from_positions, "played from authored legal seat")
	return accepted


func _warden() -> Dictionary:
	for hero: Dictionary in app.party.get_heroes():
		if hero.get("id") == "warden":
			return hero
	return {}


func _warden_tag() -> PanelContainer:
	for index in range(3):
		if app.party.get_hero(index + 1).get("id") == "warden":
			return stage._hero_reaction_tags[index]
	return null


func _assert_cues(guard: bool, thorns: int, label: String) -> void:
	stage._refresh()
	var tag: PanelContainer = _warden_tag()
	_check(tag != null and stage._hero_reaction_tags.size() == 3, label + " has mounted reaction controls")
	if tag == null:
		return
	var caption := tag.get_node("Caption") as Label
	_check(tag.visible == (guard or thorns > 0), label + " visible only for active service")
	_check(caption.text.contains("GUARD") == guard, label + " correct Guard cue")
	_check(caption.text.contains("THORNS %d" % thorns) == (thorns > 0),
		label + " correct Thorns count")
	if guard:
		_check(tag.tooltip_text.contains("another living hero") and tag.tooltip_text.contains("downed"),
			label + " hover explains actual Guard redirect and skipped downed targets")
	if thorns > 0:
		_check(tag.tooltip_text.contains("genuinely lands") and tag.tooltip_text.contains("skipped"),
			label + " hover explains one confirmed retaliation, not passive enemy Thorns")
	for index in range(3):
		if app.party.get_hero(index + 1).id != "warden":
			_check(not stage._hero_reaction_tags[index].visible,
				label + " other heroes never show the Warden reaction")
	if tag.visible:
		var puppet = stage._puppets[int(_warden().position) - 1]
		_check(tag.position.y >= -0.1 and tag.get_rect().end.y <= puppet.art_band().position.y + 0.1 \
			and tag.position.x >= -0.1 and tag.get_rect().end.x <= puppet.size.x + 0.1,
			label + " readable cue stays in Warden reserved intent band")
		_check(not tag.get_rect().intersects(stage._hero_tags[int(_warden().position) - 1].get_rect()),
			label + " Warden name is never covered")
		_check(stage._hero_tags[int(_warden().position) - 1].text == _warden().name,
			label + " actual Warden actor name stays visible")


func _assert_announced_redirect(label: String) -> bool:
	var any_redirect := false
	var current: Array = app.enemy_intents.get_intents()
	_check(app.enemy_intents.is_bound(), label + " scheduler owns real admitted announcements")
	for index in range(stage._badges.size()):
		var action: Dictionary = current[index]
		var source: Dictionary = app.enemies.get_enemy(index + 1)
		var badge: LiveEnemyIntentBadge = stage._badges[index]
		var expectation := false
		var actual_position := 0
		if source.hp > 0 and action.get("type") == "attack" \
				and action.get("target_position") is int:
			var preview: Dictionary = app.round_flow._reactions.preview_actual_recipient(
				app.party, action.target_position)
			expectation = preview.get("ok") == true and preview.get("eligible") == true \
				and preview.get("redirected") == true
			actual_position = int(preview.get("actual_target_position", 0))
		var hint := badge.tooltip_text.contains("Guard → Warden")
		_check(hint == expectation, label + " preview exactly matches source %d tooltip" % (index + 1))
		if expectation:
			any_redirect = true
			_check(badge.tooltip_text.contains("hero %d" % actual_position),
				label + " redirect names genuine current Warden seat")
			_check(badge.target_position == action.target_position and badge.amount == action.amount,
				label + " original target and printed amount unchanged")
	return any_redirect


func _refresh_is_pure(label: String) -> void:
	var snap: Array = _snapshot()
	var first_tooltips: Array[String] = []
	for badge in stage._badges:
		first_tooltips.append(badge.tooltip_text)
	for repetition in range(4):
		stage._refresh()
		for index in range(stage._badges.size()):
			_check(stage._badges[index].tooltip_text == first_tooltips[index],
				label + " idempotent full tooltip, no stacked hints")
	var tag := _warden_tag()
	if tag != null and tag.visible:
		var motion := InputEventMouseMotion.new()
		motion.position = tag.get_global_rect().get_center()
		root.push_input(motion, true)
		await _frames()
	_check(_snapshot() == snap, label + " refresh/hover cannot touch deck, actors, phase, reactions or RNG")
	seed(230119)
	var expected_global: int = randi()
	seed(230119)
	stage._refresh()
	_check(randi() == expected_global, label + " stage refresh consumes no global RNG")


func _enter(seed: int) -> bool:
	app.run_seed = seed
	_check(app.deck == null, "new battle starts from title")
	# Real routed start: its scheduler is seeded and bound to the admitted enemy roster.
	app.start_run_requested.emit()
	preload("res://tests/party_choice.gd").choose(app)
	await _frames()
	var chosen: Button
	for option: Button in app.route_buttons:
		if is_instance_valid(option) and not option.disabled \
				and option.get_meta("route_kind", "") == "Fight":
			chosen = option
			break
	if chosen == null:
		_check(false, "opening route has an authentic Fight choice")
		return false
	chosen.pressed.emit()
	await _frames()
	var valid: bool = app.deck != null and app.party != null and app.enemies != null \
		and app.round_flow != null and app.enemy_intents != null \
		and app.enemy_intents.is_bound() and is_instance_valid(app.battle_view)
	_check(valid, "routed Fight binds real deck, party, enemy, result and announced intents")
	if valid:
		stage._sync_battle()
		stage._refresh()
		_check(stage._hero_tags.size() == 3 and stage._badges.size() == app.enemies.get_enemies().size(),
			"battle mounts the real hero puppets and enemy intent badges")
	return valid


func _return() -> void:
	if is_instance_valid(app.return_button):
		app.return_button.pressed.emit()
	await _frames()
	_check(app.deck == null and stage._hero_reaction_tags.is_empty(),
		"title clears old stage cues and actor mounts")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	if scene == null:
		_check(false, "app scene loads")
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	stage = app.get_node_or_null("LiveEnemyRoster")
	hand_adapter = app.get_node_or_null("LiveWardenReactionHand")
	if stage == null or hand_adapter == null:
		_check(false, "both live stage and paid Warden hand are present")
		app.free()
		_finish()
		return
	_check(app.deck == null and stage._hero_reaction_tags.is_empty(), "fresh title has no battle cue")
	for card_id in IDS:
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty() and definition.get("cost") == 1 \
			and definition.get("owner") == "warden", "catalog contains authored paid form " + card_id)
	# Individually prove base/+ Block and mode count through authenticated mounted hand.
	for index in range(IDS.size()):
		var card_id: String = IDS[index]
		if not await _enter(42 + index):
			break
		var warden_pos := int(_warden().get("position", 0))
		_check(warden_pos == 1, "admitted Warden starts at front")
		if card_id == "warden_counter_stitch_plus":
			var preview: Dictionary = CombatPositionSwaps.preview_adjacent_swap(app.party, 1, 1)
			_check(preview.get("ok") == true, "legal adjacent hero swap to middle")
			if preview.get("ok"):
				app.party._heroes.assign(preview["heroes"])
				app._refresh_party()
				stage._refresh()
			_check(_warden().get("position") == 2, "Warden lives in Counter-stitch legal middle seat")
		_assert_cues(false, 0, "unarmed " + card_id)
		if await _pay(card_id):
			var definition: Dictionary = catalog.get_definition(card_id)
			var guard: bool = definition.effects.has("guarding")
			var thorns: int = int(definition.effects.get("thorns", 0))
			_check(app.round_flow._reactions != null \
				and app.round_flow._reactions.is_guarding() == guard \
				and app.round_flow._reactions.get_thorns() == thorns,
				"admitted service has exact card-granted modes: " + card_id)
			_assert_cues(guard, thorns, card_id)
			await _refresh_is_pure(card_id)
			# Poison the immutable admission identity only transiently to prove fail-closed.
			var binding: CombatParty = app.round_flow._battle_party
			app.round_flow._battle_party = null
			_assert_cues(false, 0, "stale flow " + card_id)
			app.round_flow._battle_party = binding
			_assert_cues(guard, thorns, "restored flow " + card_id)
			var before: Array = _snapshot()
			app.end_turn_button.pressed.emit()
			await _frames()
			if app.deck != null and app.deck.turn_active:
				_check(not app.round_flow._reactions.is_guarding() and app.round_flow._reactions.get_thorns() == 0,
					"reaction expires after real completed enemy phase and new player turn")
				_assert_cues(false, 0, "expired " + card_id)
			else:
				_check(false, "enemy phase remains active for expiration witness")
			_check(app.run_rng != null and before.size() > 0, "real RNG remains attached through turn")
		await _return()
	# Coexistence, authentic redirection, insufficient energy and downed-target exclusion.
	# Seed search is bounded and checks the real preannounced bound scheduler.
	var found := false
	for seed in range(1, 50):
		if not await _enter(seed):
			break
		var candidate := false
		for action: Dictionary in app.enemy_intents.get_intents():
			if action.get("type") == "attack" and action.get("target_position") in [2, 3]:
				candidate = true
		if candidate:
			found = true
			break
		await _return()
	_check(found, "bounded routed seed search finds a living ally-targeted announced attack")
	if found:
		_assert_cues(false, 0, "fresh coexistence battle")
		var starting_state: Array = _snapshot()
		var first := "warden_draw_fire"
		app.deck.draw_pile.append(first)
		_check(app.deck.draw_extra(1) == 1, "failed-play fixture draws real Draw Fire")
		app._refresh_hand()
		await _frames()
		var neg_panel := _panel(first)
		if neg_panel != null:
			var old_energy: int = app.deck.energy
			app.deck.combat_state.energy = 0
			var refused: Array = _snapshot()
			hand_adapter._on_card_input(_key(KEY_ENTER), neg_panel, first)
			await _frames()
			_check(_snapshot() == refused and not stage._hero_reaction_tags[0].visible,
				"unaffordable live play remains held, unarmed and unspent")
			app.deck.combat_state.energy = old_energy
			var cancel_snap: Array = _snapshot()
			var held_down := InputEventMouseButton.new()
			held_down.button_index = MOUSE_BUTTON_LEFT
			held_down.pressed = true
			hand_adapter._on_card_input(held_down, neg_panel, first)
			_check(not hand_adapter._pending.is_empty(), "authentic held card is pending before cancel")
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			escape.pressed = true
			hand_adapter._input(escape)
			await _frames()
			_check(hand_adapter._pending.is_empty() and _snapshot() == cancel_snap,
				"cancelled actual hand input clears pending without costs, mode or RNG")
			neg_panel.grab_focus()
			hand_adapter._on_card_input(_key(KEY_ENTER), neg_panel, first)
			await _frames()
		_check(app.round_flow._reactions != null and app.round_flow._reactions.is_guarding(),
			"real accepted Draw Fire arms service before announced redirect")
		_assert_cues(true, 0, "guarded telegraph")
		_check(_assert_announced_redirect("guarded telegraph"),
			"a real living source's announced ally attack explicitly redirects")
		_check(await _pay("warden_counter_stitch"), "coexisting Counter-stitch pays through real hand")
		_assert_cues(true, 3, "coexisting reactions")
		await _refresh_is_pure("coexisting and redirecting")
		# An already downed announced target must be skipped rather than redirected.
		var down_target := 0
		for action: Dictionary in app.enemy_intents.get_intents():
			if action.get("type") == "attack" and action.get("target_position") in [2, 3]:
				down_target = action.target_position
				break
		if down_target > 0:
			_check(app.party.apply_damage(down_target, CombatParty.MAX_INT / 2),
				"fixture downs announced ally without assigning a new intent")
			stage._refresh()
			for badge in stage._badges:
				_check(not badge.tooltip_text.contains("Guard → Warden") \
					or badge.target_position != down_target,
					"downed printed target never falsely redirects")
		# A formerly announced source that is now slain cannot advertise a hit.
		var slain_slot := 0
		for index in range(app.enemy_intents.get_intents().size()):
			if app.enemy_intents.get_intents()[index].get("type") == "attack":
				slain_slot = index + 1
				break
		if slain_slot > 0:
			var dying: Dictionary = app.enemies.get_enemy(slain_slot)
			_check(app.enemies.apply_damage(slain_slot, int(dying.hp) + int(dying.block)),
				"authentic announced attack source can be slain")
			stage._refresh()
			_check(not stage._badges[slain_slot - 1].tooltip_text.contains("Guard → Warden"),
				"slain source never telegraphs a Guard redirect")
		# An optional service that is missing cannot be reconstructed for display.
		var saved_reactions: CombatWardenGuardReactions = app.round_flow._reactions
		app.round_flow._reactions = null
		_assert_cues(false, 0, "missing admitted reaction service")
		for badge in stage._badges:
			_check(not badge.tooltip_text.contains("Guard → Warden"),
				"no redirect remains without admitted reaction service")
		app.round_flow._reactions = saved_reactions
		app.round_flow._battle_result = null
		_assert_cues(false, 0, "stale battle result binding")
		for badge in stage._badges:
			_check(not badge.tooltip_text.contains("Guard → Warden"), "stale binding clears tooltip")
		app.round_flow._battle_result = app.battle_result
		await _return()
	# Downed Warden cannot continue displaying borrowed Guard or Thorns.
	if await _enter(59):
		if await _pay("warden_draw_fire"):
			_check(app.party.apply_damage(1, CombatParty.MAX_INT / 2), "Warden deliberately downed")
			_assert_cues(false, 0, "downed Warden")
		await _return()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_warden_reaction_stage_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
