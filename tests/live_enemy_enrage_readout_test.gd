extends SceneTree
## Mounted, seeded readout regression: real CombatAttackCards hits drive a real
## CombatEnemies roster and the already-mounted app stage; no label is mocked.

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures.append(reason)


func _snapshot(app) -> Array:
	return [app.party.get_heroes(), app.enemies.get_enemies(),
		app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.run_rng.seed, app.run_rng.state, app.enemy_intents._turn_index,
		app.enemy_intents.get_intents(), app.enemy_attacks.duplicate(true)]


func _readout(app, stage, stacks: int, reason: String) -> void:
	var source: Dictionary = app.enemies.get_enemy(1)
	var before := _snapshot(app)
	_check(source.get("enrage") == true and source.get("enrage_stacks", 0) == stacks
		and source.get("hp", 0) > 0, reason + ": genuine living Enrage source and count")
	stage._refresh()
	var plaque: PanelContainer = stage._status_tags[0]
	var label := plaque.get_node("Caption") as Label
	var badge: LiveEnemyIntentBadge = stage._badges[0]
	var bonus := stacks * CombatEnemyKeywordRules.ENRAGE_ATTACK_BONUS_PER_STACK
	_check(plaque.visible and label.text.contains("Enrage %d/3  +%d ATK" % [stacks, bonus])
		and plaque.tooltip_text.contains("confirmed positive-damage hit")
		and plaque.tooltip_text.contains("max 3")
		and plaque.tooltip_text.contains("before Weak/Exposed"),
		reason + ": stage plaque reads stacks and truthful hit rule")
	_check(badge.intent_type == "attack" and badge.amount == 3
		and badge.enrage_bonus == bonus and badge.readable_text.contains("3")
		and badge.readable_text.contains("+%d" % bonus)
		and badge.tooltip_text.contains("Base 3")
		and badge.tooltip_text.contains("+ %d Enrage" % bonus)
		and badge.tooltip_text.contains("= %d attack power BEFORE Weak/Exposed" % (3 + bonus))
		and badge.tooltip_text.contains("Guard redirection and hero Block"),
		reason + ": base 3 stays raw and +%d yields %d pre-status power" % [bonus, 3 + bonus])
	_check(badge.caption_text_area().grow(0.5).encloses(badge.caption_text_rect())
		and Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(badge.get_global_rect()),
		reason + ": powered caption fits sewn ticket inside the 1280x720 stage")
	_check(_snapshot(app) == before,
		reason + ": pure refresh never spends, redraws intent, changes heroes, piles or RNG")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real shipped app scene exists")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	app.run_seed = 27182
	root.add_child(app)
	await process_frame
	var stage = app.get_node("LiveEnemyRoster")
	_check(app._start_battle(), "seeded real standalone battle starts")
	await process_frame
	await process_frame
	_check(app.enemies is CombatEnemies and app.party is CombatParty
		and app.enemy_intents is CombatEnemyIntents and app.run_rng != null
		and is_instance_valid(stage.panel), "real app authorities and stage are mounted")
	if app.enemies == null or app.party == null or app.run_rng == null or not is_instance_valid(stage.panel):
		app.free()
		_finish()
		return

	# Adapt genuine shipped enemy identity into a durable test encounter. The
	# constructor owns the live health, Block and detached actor dictionaries;
	# the card service, not this fixture, owns EVERY subsequent stack transition.
	var old_roster: Array[Dictionary] = app.enemies.get_enemies()
	_check(old_roster.size() >= 2 and not String(old_roster[0].get("id", "")).is_empty(),
		"seeded battle provides real first/second enemy identities")
	if old_roster.size() < 2:
		app.free()
		_finish()
		return
	var first: Dictionary = old_roster[0].duplicate(true)
	first["max_hp"] = 90
	first["enrage"] = true
	first.erase("enrage_stacks")
	first["intent"] = {"target": "front", "actions": [
		{"type": "attack", "amount": 3, "weight": 1}]}
	var second: Dictionary = old_roster[1].duplicate(true)
	second["max_hp"] = 30
	second.erase("enrage")
	second["enrage_stacks"] = 3 # Irrelevant residue is not a real Enrage ability.
	second["intent"] = {"target": "front", "actions": [
		{"type": "attack", "amount": 4, "weight": 1}]}
	var model := CombatEnemies.new([first, second])
	var scheduler := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "attack", "amount": 3, "target_position": 1}]},
		{"enemy_position": 2, "pattern": [{"type": "attack", "amount": 4, "target_position": 1}]}])
	_check(model.is_valid() and scheduler.is_valid()
		and scheduler.bind_battle(model, app.party, app.run_rng),
		"real seeded weighted scheduler binds two original actor slots and attack power base 3")
	if not scheduler.is_bound():
		app.free()
		_finish()
		return
	app.enemies = model
	app.enemy_intents = scheduler
	# Real hand/deck construction, actual seed and legitimate start_turn / energy;
	# all hits below use the same public card service as gameplay.
	var ids: Array[String] = []
	for i in range(9):
		ids.append("warden_strike")
	app.deck = CombatDeck.new(ids, app.run_rng)
	_check(app.deck.start_turn() and app.deck.hand.has("warden_strike")
		and app.deck.energy > 0, "real seeded draw yields legal Warden strikes and energy")
	app._refresh_enemy_roster()
	await process_frame
	await process_frame
	_check(stage.enemies == model and stage._badges.size() == 2
		and scheduler.get_intents().size() == 2
		and scheduler.get_intents()[0].get("amount") == 3,
		"mounted stage and scheduler share exact live roster and base 3")
	_readout(app, stage, 0, "before strikes")
	_check(not stage._status_tags[1].visible
		and stage._badges[1].enrage_bonus == -1
		and stage._badges[1].readable_text.begins_with("Hit 4"),
		"second source cannot borrow first source's metadata or gain bonus")

	var attack := CombatAttackCards.new()
	for hit_index in range(4):
		if not app.deck.turn_active or app.deck.energy == 0:
			_check(app.deck.end_turn() and app.deck.start_turn(),
				"fourth strike starts a real charged turn")
		var before: Dictionary = app.enemies.get_enemy(1)
		var paid_energy: int = app.deck.energy
		var previous_discard: int = app.deck.discard_pile.size()
		var receipt := attack.play_attack(app.deck, app.party, app.enemies, "warden_strike", 1)
		var after: Dictionary = app.enemies.get_enemy(1)
		_check(receipt.get("ok", false) and not receipt.get("hits", []).is_empty()
			and receipt["hits"][0].get("damage", 0) > 0
			and after.get("hp", 0) > 0 and after["hp"] < before["hp"],
			"legal held-card strike %d confirms positive damage on original CombatEnemies source" % (hit_index + 1))
		_check(app.deck.energy < paid_energy
			and app.deck.discard_pile.size() == previous_discard + 1,
			"accepted card %d pays energy and discards exactly once" % (hit_index + 1))
		_check(after.get("enrage_stacks", -1) == mini(hit_index + 1, 3),
			"combat rules, not UI, persist stack %d with cap" % mini(hit_index + 1, 3))
		_readout(app, stage, mini(hit_index + 1, 3),
			"confirmed held hit %d" % (hit_index + 1))

	# Statuses remain in the same existing plaque and a separate Thorns ticket.
	model._enemies[0]["statuses"] = {"bleed": 2, "weak": 1, "exposed": 2,
		"tangled": 1, "riposte": 2}
	model._enemies[0]["thorns"] = 2
	var pure_before := _snapshot(app)
	stage._refresh()
	var tag := stage._status_tags[0].get_node("Caption") as Label
	for status in ["Bleed 2", "Weak 1", "Exposed 2", "Tangled 1", "Riposte 2", "Enrage 3/3"]:
		_check(tag.text.contains(status), "same mounted status plaque preserves " + status)
	_check(stage._status_tags[0].visible and stage._thorns_tags[0].visible
		and stage._badges[0].amount == 3,
		"Thorns separate from same raw attack badge")
	var status_rect: Rect2 = stage._status_tags[0].get_global_rect()
	var thorn_rect: Rect2 = stage._thorns_tags[0].get_global_rect()
	var intent_rect: Rect2 = stage._badges[0].get_global_rect()
	var enemy_rect: Rect2 = stage._status_tags[0].get_parent().get_global_rect()
	_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(status_rect)
		and enemy_rect.grow(0.5).encloses(status_rect)
		and not status_rect.intersects(thorn_rect)
		and not status_rect.intersects(intent_rect),
		"all five statuses plus Enrage fit the same plaque without hiding other tickets")
	_check(_snapshot(app) == pure_before, "mixed-status and Thorns refresh is read-only")
	model._enemies[0]["statuses"] = {}

	# Invalid data fail closed instead of being coerced to an invented bonus.
	for corrupt in [
		{"enrage": false, "enrage_stacks": 3},
		{"enrage": "true", "enrage_stacks": 3},
		{"enrage": 1, "enrage_stacks": 3},
		{"enrage": true, "enrage_stacks": -1},
		{"enrage": true, "enrage_stacks": 1.5},
		{"enrage": true, "enrage_stacks": "2"},
		{"enrage": true, "enrage_stacks": 4},
		{"enrage_stacks": 3},
	]:
		model._enemies[0].erase("enrage")
		model._enemies[0].erase("enrage_stacks")
		for key in corrupt:
			model._enemies[0][key] = corrupt[key]
		var unchanged := _snapshot(app)
		stage._refresh()
		_check(not stage._status_tags[0].visible
			and stage._badges[0].enrage_bonus == -1
			and stage._badges[0].readable_text == "Hit 3: Front"
			and not stage._badges[0].tooltip_text.contains("Enrage"),
			"malformed/false/missing source cannot manufacture Enrage: " + str(corrupt))
		_check(_snapshot(app) == unchanged, "invalid state observation remains read-only")
	model._enemies[0]["enrage"] = true
	model._enemies[0].erase("enrage_stacks")
	_readout(app, stage, 0, "restored absent count")

	# An action change and skip/slain clear previous powered captions and help.
	var badge: LiveEnemyIntentBadge = stage._badges[0]
	var raw_action: Dictionary = scheduler.get_intents()[0]
	for nonattack in [
		{"type": "block", "amount": 2},
		{"type": "buff", "amount": 2},
		{"type": "debuff", "amount": 1, "status": "weak", "target_position": 1},
		{"type": "shove", "amount": 0, "direction": 1, "target_position": 1},
		{"type": "snip_block", "amount": 0, "target_position": 1},
	]:
		var action: Dictionary = nonattack.duplicate(true)
		action["enemy_position"] = 1
		badge.show_intent(raw_action, false, false, "", 2)
		badge.show_intent(action, false, false, "", 2)
		_check(badge.enrage_bonus == -1 and not badge.readable_text.contains("Enrage")
			and not badge.tooltip_text.contains("Enrage"),
			"non-attack %s always resets old powered view" % nonattack.type)
	badge.show_intent(raw_action, false, true, "front", 2)
	_check(badge.readable_text == "UNRAVELLED" and badge.enrage_bonus == -1
		and badge.tooltip_text == "Unravelled: next action is skipped.", "skip clears bonus")
	badge.show_intent(raw_action, true, false, "front", 2)
	_check(badge.readable_text == "SLAIN" and badge.enrage_bonus == -1
		and badge.tooltip_text == "Slain: no action.", "slain clears bonus")
	badge.show_intent(raw_action, false) # Backward-compatible historical caller.
	_check(badge.enrage_bonus == -1 and badge.readable_text == "Hit 3: Front",
		"old four-argument and two-argument calls preserve legacy amount/tooltip")
	stage._refresh()

	# A live-width policy ticket keeps both numbers readable and its stitched
	# caption separate from the target-policy patch, even under the longest label.
	for policy in ["front", "lowest_living_hp", "exposed", "random"]:
		badge.show_intent(raw_action, false, false, policy, 2)
		var text_rect := badge.caption_text_rect()
		var text_room := badge.caption_text_area()
		var policy_rect := badge.policy_rect()
		_check(badge.readable_text.contains("3+4") and badge.enrage_bonus == 4
			and badge.amount == 3 and badge.caption_font_size() >= badge.COMPACT_MIN_FONT
			and text_room.grow(0.5).encloses(text_rect)
			and not text_rect.intersects(policy_rect),
			"enraged attack fits beside %s policy without clipping or changing base" % policy)
	stage._refresh()

	# An actually slain authoritative source loses both plaques and attack intent.
	var living_hp: int = model.get_enemy(1)["hp"]
	_check(model.apply_damage(1, living_hp) and model.is_slain(1),
		"real CombatEnemies damage slays the Enrage source")
	var slain_before := _snapshot(app)
	stage._refresh()
	_check(not stage._status_tags[0].visible
		and stage._badges[0].readable_text == "SLAIN"
		and stage._badges[0].enrage_bonus == -1 and _snapshot(app) == slain_before,
		"slain mounted enemy loses Enrage cue with no refresh mutation")

	# Same-count new roster on the same app battle must unmount stale badges/plaque.
	var old_badge_id: int = stage._badges[0].get_instance_id()
	var other := CombatEnemies.new([
		{"id": "new_plain", "name": "New Plain", "max_hp": 30},
		{"id": "new_second", "name": "New Second", "max_hp": 30}])
	app.enemies = other
	app._refresh_enemy_roster()
	await process_frame
	await process_frame
	_check(stage.enemies == other and stage._badges.size() == 2
		and not is_instance_id_valid(old_badge_id)
		and not stage._status_tags[0].visible and not stage._status_tags[1].visible
		and stage._badges[0].enrage_bonus == -1 and stage._badges[1].enrage_bonus == -1
		and not stage._badges[0].tooltip_text.contains("Enrage"),
		"same-count different battle roster clears all stale Enrage UI and old controls")
	app.return_button.pressed.emit()
	await process_frame
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_enemy_enrage_readout_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
