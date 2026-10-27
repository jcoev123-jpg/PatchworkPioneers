extends SceneTree
## D2 connected admission: every cast starts from a real five-card CombatDeck
## draw, a mounted hand panel and the battle's one Pinned/Unravel authority.

const COMBOS: Array[String] = [
	"warden_pinning_jab", "warden_pinning_jab_plus",
	"warden_seam_breaker", "warden_seam_breaker_plus",
	"tinker_spool_launcher", "tinker_spool_launcher_plus",
	"tinker_snip_the_seam", "tinker_snip_the_seam_plus",
]
const GODOT_SEED := 183707
const STARTER_ORACLE := preload("res://tests/starter_fight_oracle.gd")
var failures: Array[String] = []
var checks := 0
var app
var live
var targeting := CombatAttackTargeting.new()


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _click(control: Control) -> void:
	_check(is_instance_valid(control) and control.is_visible_in_tree()
		and root.get_visible_rect().has_point(control.get_global_rect().get_center()),
		"physical input target is visible inside 1280x720")
	if not is_instance_valid(control):
		return
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _panel(id: String) -> Control:
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and panel.get_child(0).text == id:
			return panel
	return null


func _copies(values: Array) -> Dictionary:
	var result := {}
	for id in values:
		result[id] = result.get(id, 0) + 1
	return result


func _all_cards() -> Array:
	return app.deck.hand + app.deck.draw_pile + app.deck.discard_pile


func _state() -> Array:
	return [
		app.deck.energy, app.deck.turn_active, app.deck.hand.duplicate(),
		app.deck.draw_pile.duplicate(), app.deck.discard_pile.duplicate(),
		app.party.get_heroes(), app.enemies.get_enemies(),
		live._pinned._pinner_by_position.duplicate(true) if live._pinned != null else null,
		live._unravel._gauges.duplicate(true) if live._unravel != null else null,
		live._unravel._bound_enemies == app.enemies if live._unravel != null else false,
		live._play._tinker._consumed, live._play._tinker._path_bonus,
		app.run_rng.seed, app.run_rng.state, app.enemy_intents._turn_index,
		app.battle_result.get_outcome(), live.last_event.duplicate(true),
		app.run_deck.duplicate(), app.run_scraps, app.session_gold,
		app._quilt_bonus.get_patch_progress() if app._quilt_bonus != null else {},
		app._quilt_bonus.get_switchback_state() if app._quilt_bonus != null else {},
		app.run_trinkets.duplicate(), app.run_heroes.duplicate(true),
		app.party_carryover.read_state() if app.party_carryover != null else null,
		app.party_carryover._wardrobe.get_snapshot() if app.party_carryover != null
			and app.party_carryover._wardrobe != null else null,
		live._play._patches.active_snapshot() if live._play._patches != null else null,
		live._play._patches.latch_snapshot() if live._play._patches != null else null,
	]


## A catalog-recognized earned base joins the persistent shared deck. For a
## plus request, the genuine Rest choice replaces this particular earned copy,
## without granting a second copy or offering a raw plus as a reward.
func _earned_deck_card(id: String, source: Array[String]) -> String:
	var base: String = id.trim_suffix("_plus")
	var offered: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(base)
	_check(not offered.is_empty() and offered.get("id") == base
		and offered.get("owner") == targeting.combo_definition(id).get("owner"),
		"earned pool base exists with correct owner: " + id)
	_check(RunPoolCardRewardOffers.resolve_reward_definition(base + "_plus").is_empty(),
		"raw upgrade is not a reward offer: " + base)
	if offered.is_empty():
		return ""
	# Drive an actual seeded, weighted three-offer reward choice and claim.
	# Search deterministic seeds to find this authored base without changing
	# the production probabilities or inventing an offered plus ID.
	var party_ids: Array[String] = ["warden", "seamstress", "tinker"]
	var generated: Dictionary = {}
	var found := false
	for reward_seed in range(1, 2001):
		var reward_rng := RandomNumberGenerator.new()
		reward_rng.seed = reward_seed
		var candidate: Dictionary = RunPoolCardRewardOffers.generate_for_living_from_authored(
			reward_rng, party_ids, party_ids)
		for item in candidate.get("offers", []):
			if item.get("id") == base:
				generated = candidate
				found = true
				break
		if found:
			break
	_check(found and generated.get("ok", false)
		and generated.get("offers", []).size() == 3,
		"weighted authored reward offers the requested earned base: " + base)
	if not found:
		return ""
	var reward := RunCardRewardChoice.new(generated["offers"], party_ids)
	var claimed: Dictionary = reward.claim(source, base)
	_check(claimed.get("ok", false) and claimed.get("selected_id") == base
		and claimed["deck"].size() == source.size() + 1 and reward.is_claimed()
		and not reward.claim(source, base).get("ok", false),
		"one genuine reward claim adds exactly the chosen base: " + base)
	if not claimed.get("ok", false):
		return ""
	source.assign(claimed["deck"])
	if id == base:
		return base
	var choices := RunRestCardUpgrade.list_authored_choices(source)
	var mapped := false
	for choice in choices.get("choices", []):
		if int(choice.get("index", -1)) == source.size() - 1 \
				and choice.get("source_id") == base and choice.get("plus_id") == id \
				and choice.get("plus_effects") == targeting.combo_definition(id).get("effects"):
			mapped = true
	_check(choices.get("ok", false) and mapped, "real Rest catalog presents earned base's exact plus: " + id)
	if not mapped:
		return ""
	var rest := RunRestCardUpgrade.new(source, choices["permitted_upgrades"])
	var receipt := rest.choose_upgrade(source.size() - 1)
	_check(receipt.get("ok", false) and receipt.get("original_id") == base
		and receipt.get("upgraded_id") == id and rest.is_consumed(),
		"Rest upgrades exactly the earned card: " + id)
	if not receipt.get("ok", false):
		return ""
	_check(not rest.choose_upgrade(source.size() - 1).get("ok", false),
		"same Rest cannot grant a free second copy: " + id)
	source.assign(receipt["deck"])
	_check(source.count(base) == 0 and source.count(id) == 1,
		"upgraded run deck contains only paid plus copy: " + id)
	return id


## Starts the real app scene and CombatRoundFlow. The upgraded run deck is
## admitted through the existing next-Fight receipt/shuffle service, then its
## authentic five-card deal is installed into the mounted battle's SAME deck
## identity. No fabricated button, direct hand injection, or free card copy.
func _start(ids: Array[String], seed_value: int = GODOT_SEED) -> bool:
	if app != null:
		app.free()
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	_check(STARTER_ORACLE.pin_guard_block(app, "user://live_pool_combo_guard.json"),
		"shipped Guard Ragling pinned to its own authored Block alternative")
	app.run_seed = seed_value
	var started: bool = app._start_battle()
	await _frames()
	live = app.get_node_or_null("LiveAttackPreview")
	_check(started and live != null and app.deck != null and app.round_flow != null
		and app.battle_result != null and app._combo_battle_current(),
		"real scene mounted a current active combat turn")
	if not started or live == null or app.deck == null:
		return false
	_check(app.deck.hand.size() == 5 and app.deck.energy == 3
		and app.party.get_heroes().size() == 3 and app.deck._rng == app.run_rng,
		"starter battle dealt five shared cards, three energy and three heroes")
	var source: Array[String] = app.run_deck.duplicate()
	var original_size := source.size()
	for id in ids:
		if _earned_deck_card(id, source).is_empty():
			return false
	app.run_deck.assign(source)
	_check(app.run_deck.size() == original_size + ids.size(),
		"reward/Rest changed deck multiplicity only by earned copies")
	var ledger := RunRestStitchCards.new(source, {}, 0, 1)
	_check(ledger.is_valid() and not ledger.get_snapshot().get("receipt", "").is_empty(),
		"claimed and Rest-upgraded run deck has an authentic next-Fight receipt")
	if not ledger.is_valid():
		return false
	var admitted: Dictionary = {}
	var admitted_rng: RandomNumberGenerator
	# A trial's own seeded admission draws five; choose a repeatable seed that
	# legitimately draws EVERY card under test without moving card IDs by hand.
	for entry_seed in range(seed_value, seed_value + 1000):
		var trial_rng := RandomNumberGenerator.new()
		trial_rng.seed = entry_seed
		var next: Dictionary = RunStitchedBattleHandEntry.new().admit_next_fight(
			source, {}, 0, 1, ledger.get_snapshot()["receipt"], trial_rng)
		if not next.get("ok", false):
			continue
		var next_deck: CombatDeck = next["combat_deck"]
		if not next_deck.start_turn():
			continue
		var present := true
		for wanted in _copies(ids):
			if next_deck.hand.count(wanted) < ids.count(wanted):
				present = false
		if present:
			admitted = next
			admitted_rng = trial_rng
			break
	_check(not admitted.is_empty() and admitted_rng != null,
		"seeded next-Fight service deals all owned combo copies in five cards")
	if admitted.is_empty():
		return false
	var admitted_deck: CombatDeck = admitted["combat_deck"]
	_check(admitted["snapshot"]["deck"] == source
		and admitted_deck.energy == 3 and admitted_deck.hand.size() == 5
		and _copies(admitted_deck.hand + admitted_deck.draw_pile) == _copies(source),
		"authenticated next battle neither reseeds nor duplicates the Rest deck")
	# Preserve the live app and round-flow deck identity used by the actual
	# dispatcher. Its contents and shared RNG state come from that legal deal.
	app.run_rng.seed = admitted_rng.seed
	app.run_rng.state = admitted_rng.state
	app.deck.hand.assign(admitted_deck.hand)
	app.deck.draw_pile.assign(admitted_deck.draw_pile)
	app.deck.discard_pile.assign(admitted_deck.discard_pile)
	for id in ids:
		_check(app.deck.hand.has(id), "authentic next-Fight hand holds earned copy: " + id)
	_check(app.deck.hand.size() == 5 and _copies(_all_cards()) == _copies(app.run_deck)
		and app.deck.discard_pile.is_empty() and app.deck._rng == app.run_rng,
		"five-card shared hand and all three piles equal persistent run-deck multiplicity")
	app._refresh_hand()
	await _frames()
	_check(live._pinned != null and live._unravel != null
		and live._unravel._bound_enemies == app.enemies
		and (app.round_flow._unravel == null or app.round_flow._unravel == live._unravel),
		"live preview owns the only gauge before first standalone commit")
	for id in ids:
		var panel := _panel(id)
		_check(panel != null and live._bindings.has(panel)
			and panel.get_parent() == app.hand_view and app.deck.hand[panel.get_index()] == id,
			"actual held panel is uniquely bound to its paid deck slot: " + id)
	return true


func _choose(id: String, position: int, mouse: bool) -> void:
	var panel := _panel(id)
	_check(panel != null and live._bindings.has(panel), "eligible panel exists before cast: " + id)
	if panel == null:
		return
	if mouse:
		await _click(panel)
	else:
		await _key(KEY_ESCAPE)
		var selected := false
		for attempt in range(app.deck.hand.size() + 2):
			await _key(KEY_P)
			if live._armed == panel:
				selected = true
				break
		_check(selected, "keyboard P reaches held card: " + id)
		if not selected:
			return
	_check(live._armed == panel and live._target_preview(id).get("playable", false),
		"live hand arms real card and target preview: " + id)
	if mouse:
		await _click(app.get_node("LiveEnemyRoster")._labels[position - 1])
	else:
		await _key(KEY_1 if position == 1 else KEY_2 if position == 2 else KEY_3)
	await _frames()


func _eight_live_casts() -> void:
	for id in COMBOS:
		for mouse in [true, false]:
			if not await _start([id]):
				return
			var definition := targeting.combo_definition(id)
			_check(not definition.is_empty() and definition.get("id") == id
				and definition.get("from_positions", []).has(
					1 if id.begins_with("warden") else 3)
				and definition.get("to_positions", []).has(1),
				"catalog owner/from/to is legal for mounted formation: " + id)
			var before := _state()
			var forecast: Dictionary = live._combo_preview(id)
			_check(forecast.get("playable", false) and forecast.get("targets", []).size() > 0
				and forecast.get("target_positions", []).has(1),
				"live target preview selects genuine living enemy slot one: " + id)
			if not forecast.get("playable", false):
				continue
			var expected: Dictionary = forecast["targets"][0]
			var base_damage: int = int(definition["effects"]["damage"])
			var first_bonus: int = 3 if id.begins_with("tinker") else 0
			_check(int(expected["damage"]) == base_damage + first_bonus,
				"independent authored damage plus separate first-Tinker-attack latch: " + id)
			_check(expected["target_hp_before"] == app.enemies.get_enemy(1)["hp"]
				and expected["target_block_before"] == app.enemies.get_enemy(1)["block"],
				"forecast begins from actual enemy HP/Block: " + id)
			await _choose(id, 1, mouse)
			var event: Dictionary = live.last_event
			_check(event.get("ok", false) and event.get("hits", []).size() == 1
				and event["hits"][0].get("damage") == expected["damage"],
				"real %s commit has one exact authored hit: %s" % [
					"mouse" if mouse else "keyboard", id])
			_check(app.deck.energy == int(before[0]) - int(definition["cost"])
				and app.deck.hand.count(id) == 0
				and app.deck.discard_pile.count(id) == int((before[4] as Array).count(id)) + 1
				and app.deck.draw_pile == before[3],
				"one printed-cost payment, one discard, no other pile change: " + id)
			_check(app.enemies.get_enemy(1)["hp"] == expected["hp_after"]
				and app.enemies.get_enemy(1)["block"] == expected["block_after"]
				and live._pinned.pinner_for_enemy(1) == expected["pin_owner_after"]
				and live._unravel.get_snapshot(1) == expected["unravel_after"],
				"committed enemy, Pin and Unravel match precommit forecast: " + id)
			_check(live._play._tinker._consumed == id.begins_with("tinker")
				and app.run_rng.state == before[13]
				and app.run_deck == before[17]
				and _copies(_all_cards()) == _copies(app.run_deck),
				"real Tinker latch, seeded RNG and persistent deck stay coherent: " + id)
			_check(not live._queued and app.round_flow._unravel == live._unravel,
				"deferred cast settled once against shared round authority: " + id)


func _pin_and_status() -> void:
	if not await _start(["warden_pinning_jab", "tinker_spool_launcher"]):
		return
	_check(app.enemies.gain_block(1, 60), "Pinned cross-hero target survives")
	# Weak on the next owner, Exposed on the enemy: +5 must enter BEFORE the
	# single final floor(9/8) arithmetic, not after either status multiplier.
	app.party._heroes[2]["statuses"] = {"weak": 2}
	app.enemies._enemies[0]["statuses"] = {"exposed": 2}
	await _choose("warden_pinning_jab", 1, true)
	_check(live._pinned.pinner_for_enemy(1) == "warden", "Warden-owned Pin survives a live Jab")
	var forecast: Dictionary = live._combo_preview("tinker_spool_launcher")
	_check(forecast.get("playable", false) and forecast["targets"][0]["pin_bonus"] == 5
		and forecast["targets"][0]["tinker_first_attack_bonus"] == 3
		and forecast["targets"][0]["damage"] == 12,
		"Tinker Weak and target Exposed floor (3+3+5)*9/8 to 12")
	await _choose("tinker_spool_launcher", 1, false)
	_check(live.last_event.get("ok", false) and live.last_event["hits"][0]["damage"] == 12
		and live._pinned.pinner_for_enemy(1).is_empty() and live._play._tinker._consumed,
		"different-owner live hit consumes Pin once and first-attack latch")
	if not await _start(["warden_pinning_jab", "warden_seam_breaker"]):
		return
	_check(app.enemies.gain_block(1, 50), "same-owner target survives two casts")
	await _choose("warden_pinning_jab", 1, false)
	var pin_before: String = live._pinned.pinner_for_enemy(1)
	await _choose("warden_seam_breaker", 1, true)
	_check(live.last_event.get("ok", false)
		and live.last_event["hits"][0]["pin_bonus"] == 0
		and pin_before == "warden" and live._pinned.pinner_for_enemy(1) == "warden",
		"same owner's committed hit never claims or consumes its own Pin")


func _unravel_turns() -> void:
	if not await _start(["tinker_spool_launcher"]):
		return
	_check(app.enemies.gain_block(1, 40)
		and live._unravel.get_snapshot(1)["threshold"] == 8,
		"normal starter enemy's authentic first threshold is eight")
	_check(live._unravel.apply_unravel(app.enemies, 1, 5),
		"surviving normal enemy precharges to five")
	await _choose("tinker_spool_launcher", 1, true)
	var pending: Dictionary = live._unravel.get_snapshot(1)
	_check(live.last_event.get("ok", false) and pending["gauge"] == 8
		and pending["threshold"] == 8 and pending["skip_pending"],
		"mounted Spool reaches full normal threshold and schedules skip")
	var hp: int = app.party.get_hero(1)["hp"]
	var enemy_hp: int = app.enemies.get_enemy(1)["hp"]
	var previous_turn: int = app.enemy_intents._turn_index
	# A surviving Bleed tick charges exactly one after that skipped action.
	app.enemies._enemies[0]["statuses"] = {"bleed": 3}
	await _click(app.end_turn_button)
	var after: Dictionary = live._unravel.get_snapshot(1)
	_check(app.enemy_intents._turn_index == previous_turn + 1
		and app.party.get_hero(1)["hp"] == hp
		and app.enemies.get_enemy(1)["hp"] == enemy_hp - 3,
		"genuine enemy phase skipped Ragling's announced attack, then ticked Bleed")
	_check(after["threshold"] == 12 and after["gauge"] == 1
		and not after["skip_pending"] and app.round_flow._unravel == live._unravel,
		"one skipped action raises threshold by four; Bleed gives exactly +1")
	_check(live._unravel.apply_unravel(app.enemies, 1, 11),
		"same surviving enemy charges second threshold of twelve")
	await _click(app.end_turn_button)
	after = live._unravel.get_snapshot(1)
	_check(after["threshold"] == 16 and after["gauge"] == 1
		and not after["skip_pending"],
		"second actual enemy phase consumes just one skip and increases threshold again")
	# Explicit tier-bound battle-local fixtures exercise elite and boss scales
	# without depending on concurrently owned M05 run-enemy rotation files.
	for tier in ["elite", "boss"]:
		if not await _start(["tinker_spool_launcher"]):
			return
		var tiers := {1: tier, 2: "normal"}
		_check(live._unravel.bind_roster(app.enemies, tiers)
			and (app.round_flow._unravel == null or app.round_flow._unravel == live._unravel),
			"same mounted authority accepts deterministic %s tier fixture" % tier)
		var first: int = 12 if tier == "elite" else 16
		_check(live._unravel.get_snapshot(1)["threshold"] == first,
			"%s opens at authored threshold %d" % [tier, first])
		_check(app.enemies.gain_block(1, 50)
			and live._unravel.apply_unravel(app.enemies, 1, first - 3),
			"tier target survives while three short")
		await _choose("tinker_spool_launcher", 1, true)
		_check(live.last_event.get("ok", false)
			and live._unravel.get_snapshot(1)["skip_pending"],
			"%s live Spool reaches its threshold" % tier)
		await _click(app.end_turn_button)
		_check(live._unravel.get_snapshot(1)["threshold"] == first + 4
			and not live._unravel.get_snapshot(1)["skip_pending"],
			"%s genuine end turn consumes skip and escalates by four" % tier)


func _snip_conditions() -> void:
	for id in ["tinker_snip_the_seam", "tinker_snip_the_seam_plus"]:
		if not await _start([id]):
			return
		_check(app.enemies.gain_block(1, 50), "normal Snip target survives for exact effect")
		var base: Dictionary = live._combo_preview(id)
		_check(base.get("playable", false)
			and not base["targets"][0]["conditional_empowered"]
			and base["targets"][0]["damage"] == (
				8 if id == "tinker_snip_the_seam" else 10),
			"unempowered Snip prints base damage plus Tinker +3: " + id)
		_check(live._unravel.apply_unravel(app.enemies, 1, 4),
			"half of current normal threshold reached")
		var empowered: Dictionary = live._combo_preview(id)
		_check(empowered.get("playable", false)
			and empowered["targets"][0]["conditional_empowered"]
			and empowered["targets"][0]["damage"] == (
				18 if id == "tinker_snip_the_seam" else 23),
			"half-threshold Snip prints conditional damage plus Tinker +3: " + id)
		await _choose(id, 1, false)
		_check(live.last_event.get("ok", false)
			and live.last_event["hits"][0]["damage"] == empowered["targets"][0]["damage"]
			and app.enemies.get_enemy(1)["hp"] == empowered["targets"][0]["hp_after"],
			"live held Snip commits empowered base or + exactly: " + id)


func _rejections() -> void:
	var id := "warden_pinning_jab"
	for scenario in ["wrong_to", "energy", "downed", "wrong_from", "dead_target",
			"stale_target_id", "swapped_hand", "swapped_panel", "closed", "invalid_gauge",
			"invalid_pin", "expired_turn"]:
		if not await _start([id]):
			return
		var panel := _panel(id)
		await _click(panel)
		_check(live._armed == panel, "real hand panel armed before rejection: " + scenario)
		if scenario == "wrong_to":
			var initial := _state()
			live._queue_attack(2)
			await _frames()
			_check(_state() == initial and not live._queued,
				"non-authored destination refuses without spending")
			continue
		live._queue_attack(1)
		_check(live._queued, "queued genuine target before stale mutation: " + scenario)
		match scenario:
			"energy":
				app.deck.combat_state.energy = 0
			"downed":
				app.party.apply_damage(1, 999)
			"wrong_from":
				var heroes: Array = app.party.get_heroes()
				heroes[0]["position"] = 3
				heroes[1]["position"] = 1
				heroes[2]["position"] = 2
				app.party._heroes.assign([heroes[1], heroes[2], heroes[0]])
			"dead_target":
				app.enemies.apply_damage(1, 999)
			"stale_target_id":
				app.enemies._enemies[0]["id"] = "ragling_guard"
			"swapped_hand":
				app.deck.hand[panel.get_index()] = "warden_seam_breaker"
			"swapped_panel":
				app._refresh_hand()
			"closed":
				app._battle_closed = true
			"invalid_gauge":
				live._unravel = CombatUnravel.new()
			"invalid_pin":
				live._pinned._pinner_by_position[1] = "intruder"
			"expired_turn":
				app.enemy_intents._turn_index += 1
		var prior := _state()
		await _frames()
		_check(_state() == prior and not live.last_event.get("ok", false),
			"failed deferred cast preserves energy, all piles, actors, pin, gauge and RNG: " + scenario)
	# Two requests against the exact same panel before the deferred boundary
	# must still produce only one payment/hit/discard.
	if not await _start([id]):
		return
	await _click(_panel(id))
	var before := _state()
	live._queue_attack(1)
	live._queue_attack(1)
	await _frames()
	_check(live.last_event.get("ok", false)
		and app.deck.energy == int(before[0]) - 1
		and app.deck.discard_pile.count(id) == 1
		and app.deck.hand.count(id) == 0
		and app.run_rng.state == before[13],
		"duplicate deferred panel activation commits exactly once")



## A deterministic real opening Fight with a connected next Fight. The reward,
## persistent earned cards and sewing are completed between those two battles.
var _sewn_fixture: Dictionary = {}


func _connected_fights() -> Dictionary:
	if not _sewn_fixture.is_empty():
		return _sewn_fixture
	for value in range(1, 300):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for first in map.get_legal_choices():
			if map.get_node(first).type != "Fight":
				continue
			for second in map.get_node(first).outgoing:
				if map.get_node(second).type != "Fight":
					continue
				map.choose_node(first)
				var entry := RunAuthoredBattleEntry.new().entry_current_battle(
					map, rng, RunFightEncounterSelection.new())
				if entry.get("encounter_id") == "starter_attacks":
					_sewn_fixture = {"seed": value, "first": first, "second": second}
					return _sewn_fixture
				map.undo_choice(first, [])
	return {}


func _route_button(id: String) -> Button:
	for button in app.route_buttons:
		if button.get_meta("route_id", "") == id:
			return button
	return null


## A real next-Fight receipt determines this five-card deal. As in _start,
## mount that legal deal on the identity already owned by App/RoundFlow.
func _mount_sewn_hand(ids: Array[String]) -> bool:
	var source: Array[String] = app.run_deck.duplicate()
	var ledger := RunRestStitchCards.new(source, {}, 0, 1)
	_check(ledger.is_valid() and not ledger.get_snapshot().get("receipt", "").is_empty(),
		"sewn run's earned shared deck has valid next-Fight hand receipt")
	if not ledger.is_valid():
		return false
	var admitted: Dictionary = {}
	var admitted_rng: RandomNumberGenerator
	for entry_seed in range(GODOT_SEED, GODOT_SEED + 1000):
		var trial_rng := RandomNumberGenerator.new()
		trial_rng.seed = entry_seed
		var next := RunStitchedBattleHandEntry.new().admit_next_fight(
			source, {}, 0, 1, ledger.get_snapshot()["receipt"], trial_rng)
		if not next.get("ok", false):
			continue
		var next_deck: CombatDeck = next["combat_deck"]
		if not next_deck.start_turn():
			continue
		var present := true
		for wanted in _copies(ids):
			if next_deck.hand.count(wanted) < ids.count(wanted):
				present = false
		if present:
			admitted = next
			admitted_rng = trial_rng
			break
	_check(not admitted.is_empty() and admitted_rng != null,
		"real seeded owned run cards share an admitted five-card hand")
	if admitted.is_empty():
		return false
	var next_deck: CombatDeck = admitted["combat_deck"]
	app.run_rng.seed = admitted_rng.seed
	app.run_rng.state = admitted_rng.state
	app.deck.hand.assign(next_deck.hand)
	app.deck.draw_pile.assign(next_deck.draw_pile)
	app.deck.discard_pile.assign(next_deck.discard_pile)
	_check(app.deck.energy == 3 and app.deck.hand.size() == 5
		and _copies(_all_cards()) == _copies(source) and app.deck._rng == app.run_rng,
		"real mounted sewn fight retains shared deck, 3 energy, 5 draw and RNG")
	app._refresh_hand()
	await _frames()
	for id in ids:
		var panel := _panel(id)
		_check(panel != null and live._bindings.has(panel)
			and app.deck.hand[panel.get_index()] == id,
			"sewn battle mounts the genuinely earned base/Rest plus panel " + id)
	return true


func _start_sewn(ids: Array[String], patch_id: String, wearer: String,
		torn: bool = false) -> bool:
	var fixture := _connected_fights()
	_check(not fixture.is_empty(), "generated map offers connected real Fights")
	if fixture.is_empty():
		return false
	if app != null:
		app.free()
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	app.run_seed = fixture.seed
	await _click(app.route_button)
	var first := _route_button(fixture.first)
	_check(first != null and not first.disabled, "real opening route Fight is selectable")
	if first == null:
		return false
	await _click(first)
	_check(app.deck != null and app.encounter_id == "starter_attacks"
		and app.party.is_valid(), "connected predecessor has live party and deck")
	if app.deck == null:
		return false
	if torn:
		var torn_slot := 1 if wearer == "warden" else 3 if wearer == "tinker" else 2
		_check(app.party.apply_damage(torn_slot, 999)
			and app.party.is_downed(torn_slot), "genuine predecessor tears patch wearer")
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_damage(enemy.position, 999), "predecessor enemy defeated")
	app._observe_battle_result()
	await _frames()
	_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY
		and app.reward_buttons.size() == 4, "real Fight settles before sewing")
	if app.reward_buttons.size() != 4:
		return false
	await _click(app.reward_buttons[3])
	await _click(app.continue_button)
	_check(app.route_view != null and app.route_view.is_visible_in_tree()
		and app.party_carryover is RunTornCarryover,
		"connected next-Fight route retains authentic tear ledger")
	if app.route_view == null or not app.party_carryover is RunTornCarryover:
		return false
	var source: Array[String] = app.run_deck.duplicate()
	for id in ids:
		if _earned_deck_card(id, source).is_empty():
			return false
	app.run_deck.assign(source)
	var catalog_path := ("res://data/patches/m05_arm_support_patches.json"
		if patch_id == "loose_thread_glove" else "res://data/patches/m04_attack_patches.json")
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	var found: Array = []
	if records is Array:
		for record in records:
			if record is Dictionary and record.get("id") == patch_id:
				found.append(record)
	var slot := "HEAD" if patch_id == "button_eye" else "ARM"
	var effect := ("card_unravel_bonus" if patch_id == "loose_thread_glove" else
		"first_attack_exposed" if patch_id == "button_eye" else "card_attack_bonus")
	_check(found.size() == 1 and found[0].get("slot") == slot
		and found[0].get("effect") == effect and found[0].get("amount") == 1,
		"authored unique ARM/HEAD patch catalog power " + patch_id)
	if found.size() != 1:
		return false
	app.run_trinkets.append(patch_id)
	var carry := app.party_carryover as RunTornCarryover
	_check(carry.is_valid() and carry.torn.is_valid()
		and carry.read_state().heroes == app.run_heroes,
		"sewing uses current real run-owned living/torn roster")
	var wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		[{"id": patch_id, "slot": slot}], app.run_scraps,
		app.session_gold, app.run_deck, app.run_seed, true)
	_check(wardrobe.is_valid(), "genuine wardrobe created from run-owned reward and cards")
	if not wardrobe.is_valid():
		return false
	var sewn := wardrobe.sew(patch_id, wearer, slot, "live_combo_sew",
		wardrobe.get_snapshot())
	var current: Dictionary = wardrobe.get_snapshot()
	_check(sewn.get("ok", false) and sewn.receipt.patch_id == patch_id
		and sewn.receipt.hero_id == wearer and sewn.receipt.slot == slot
		and carry.can_bind_wardrobe(wardrobe, carry.torn, current)
		and carry.bind_wardrobe(wardrobe, carry.torn, current),
		"actual unique sew receipt binds to persistent carryover before next Fight")
	if not sewn.get("ok", false) or carry._wardrobe != wardrobe:
		return false
	var projected := wardrobe.project_active(carry.torn.read_state())
	_check(projected.get("ok", false) and projected.worn[wearer][slot] == patch_id
		and projected.active[wearer] == ([] if torn else [patch_id]),
		"sewn projection only activates when owner is living")
	var next_fight := _route_button(fixture.second)
	_check(next_fight != null and not next_fight.disabled,
		"connected second Fight available with sewn run receipt")
	if next_fight == null:
		return false
	await _click(next_fight)
	live = app.get_node_or_null("LiveAttackPreview")
	_check(app.route_view == null and app.deck != null and live != null
		and app._combo_battle_current() and app.round_flow != null,
		"real sewn run enters next mounted Fight")
	if app.deck == null or live == null:
		return false
	var rules: CombatPatchAttackRules = live._play._patches
	_check(rules != null and rules.is_valid()
		and rules.active_snapshot() == projected.active
		and rules.latch_snapshot().get(wearer) == false
		and live._warden_combo.get_patches() == rules
		and app.deck._rng == app.run_rng,
		"one battle-bound patch projection feeds starter, Warden and Tinker")
	if rules == null or not rules.is_valid():
		return false
	return await _mount_sewn_hand(ids)


func _quote_row(quote: Dictionary, position: int) -> Dictionary:
	for row in quote.get("targets", []):
		if row.get("position") == position:
			return row
	return {}


## All four positive-Unravel base/+ cards, both physical input modes; separate
## ARM patch cases also cover +1 damage without inventing a gauge charge.
func _sewn_hit(id: String, patch_id: String, wearer: String, mouse: bool,
		near_skip: bool = false) -> void:
	if not await _start_sewn([id], patch_id, wearer):
		_check(false, "genuine sewn combo fixture ready: " + id)
		return
	var owner: String = targeting.combo_definition(id)["owner"]
	var authored: Dictionary = targeting.combo_definition(id)["effects"]
	_check(app.enemies.gain_block(1, 60), "patched hit target survives")
	var charge: int = int(authored.get("unravel", 0))
	if patch_id == "loose_thread_glove" and wearer == owner and charge > 0:
		charge += 1
	if near_skip and charge > 0:
		_check(live._unravel.apply_unravel(app.enemies, 1, 8 - charge),
			"genuine bound normal gauge charged just short of patched threshold")
	var original := _state()
	var quote: Dictionary = live._combo_preview(id)
	var row: Dictionary = _quote_row(quote, 1)
	var extra_damage := 1 if patch_id == "pincushion_arm" and owner == wearer else 0
	var expected_damage: int = int(authored["damage"]) + extra_damage + (
		3 if owner == "tinker" else 0)
	_check(quote.get("playable", false) and not row.is_empty()
		and row.get("damage") == expected_damage
		and row.get("unravel_added") == charge
		and row.get("unravel_before") == live._unravel.get_snapshot(1),
		"worn live quote exact authored damage, Tinker first attack and glove " + id)
	_check(live._combo_preview(id) == quote and _state() == original,
		"twice detached sewn forecast never spends, consumes latch or advances RNG")
	if row.is_empty():
		return
	await _choose(id, 1, mouse)
	var event: Dictionary = live.last_event
	var hit: Dictionary = event.get("hits", [{}])[0]
	var actual_charge: int = int(hit.get("unravel_added", hit.get("unravel", 0)))
	_check(event.get("ok", false) and event.get("hits", []).size() == 1
		and hit.get("damage") == row["damage"] and actual_charge == charge
		and app.deck.energy == int(original[0]) - int(targeting.combo_definition(id)["cost"])
		and app.deck.discard_pile.count(id) == (original[4] as Array).count(id) + 1
		and not app.deck.hand.has(id),
		"real paid worn cast exactly matches damage/charge, cost and one discard " + id)
	_check(app.enemies.get_enemy(1)["hp"] == row["hp_after"]
		and app.enemies.get_enemy(1)["block"] == row["block_after"]
		and live._unravel.get_snapshot(1) == row["unravel_after"]
		and live._pinned.pinner_for_enemy(1) == row["pin_owner_after"]
		and app.round_flow._unravel == live._unravel,
		"same real enemy HP/Block/Pin/gauge and round authority as sewn quote " + id)
	_check(app.run_rng.state == original[13] and app.run_deck == original[17]
		and app.run_scraps == original[18] and app.session_gold == original[19]
		and app.run_trinkets == original[22] and app.run_heroes == original[23]
		and app.party_carryover._wardrobe.get_snapshot() == original[25],
		"committed cast preserves sewn receipt, wallet, persistent deck and RNG " + id)
	if near_skip and charge > 0:
		var pending: Dictionary = live._unravel.get_snapshot(1)
		_check(pending["gauge"] == 8 and pending["skip_pending"],
			"authentic patched hit triggers exact normal threshold eight")
		var before_turn: int = app.enemy_intents._turn_index
		var before_hp: int = app.party.get_hero(1)["hp"]
		await _click(app.end_turn_button)
		var after_turn: Dictionary = live._unravel.get_snapshot(1)
		_check(app.enemy_intents._turn_index == before_turn + 1
			and app.party.get_hero(1)["hp"] == before_hp
			and after_turn["threshold"] == 12 and after_turn["gauge"] == 0
			and not after_turn["skip_pending"]
			and app.round_flow._unravel == live._unravel,
			"real End Turn consumes patched skip and resets bound gauge to twelve")


func _sewn_first_hit(owner: String) -> void:
	var first_id := "warden_pinning_jab" if owner == "warden" else "tinker_spool_launcher"
	var second_id := "warden_seam_breaker" if owner == "warden" else "tinker_snip_the_seam"
	if not await _start_sewn([first_id, second_id], "button_eye", owner):
		return
	_check(app.enemies.gain_block(1, 70), "two HEAD-worn attacks retain surviving target")
	var rules: CombatPatchAttackRules = live._play._patches
	var before := _state()
	var first := _quote_row(live._combo_preview(first_id), 1)
	_check(not first.is_empty() and not rules.latch_snapshot()[owner]
		and _state() == before, "Button Eye detached hover does not spend first-hit latch " + owner)
	if first.is_empty():
		return
	await _choose(first_id, 1, true)
	_check(live.last_event.get("ok", false) and rules.latch_snapshot()[owner]
		and app.enemies.get_enemy(1)["statuses"].get("exposed", 0) == 1
		and live.last_event["hits"][0]["damage"] == first["damage"]
		and live.last_event["hits"][0].get("statuses", {}).get("exposed", 0) == 1,
		"first real HEAD-worn hit applies Exposed once only " + owner)
	var subsequent: Dictionary = live._combo_preview(second_id)
	var second := _quote_row(subsequent, 1)
	var midway := _state()
	_check(not second.is_empty() and live._combo_preview(second_id) == subsequent
		and _state() == midway and rules.latch_snapshot()[owner],
		"next worn forecast keeps spent HEAD latch and existing Exposed " + owner)
	if second.is_empty():
		return
	await _choose(second_id, 1, false)
	_check(live.last_event.get("ok", false)
		and live.last_event["hits"][0]["damage"] == second["damage"]
		and app.enemies.get_enemy(1)["statuses"].get("exposed", 0) == 1
		and live.last_event["hits"][0].get("statuses", {}).get("exposed", 0) == 0
		and rules.latch_snapshot()[owner]
		and app.enemies.get_enemy(1)["hp"] == second["hp_after"]
		and app.enemies.get_enemy(1)["block"] == second["block_after"]
		and app.round_flow._unravel == live._unravel,
		"second confirmed hit receives existing Exposed but does not re-award " + owner)


func _sewn_refusals() -> void:
	for id in ["warden_pinning_jab", "tinker_snip_the_seam",
			"warden_pinning_jab_plus", "tinker_snip_the_seam_plus"]:
		var owner: String = targeting.combo_definition(id)["owner"]
		if not await _start_sewn([id], "loose_thread_glove", owner):
			return
		var quote: Dictionary = live._combo_preview(id)
		var row := _quote_row(quote, 1)
		_check(not row.is_empty() and row["unravel_added"] == 0,
			"glove cannot add Unravel to unprinted attack effect " + id)
		await _choose(id, 1, true)
		var hit: Dictionary = live.last_event.get("hits", [{}])[0]
		_check(live.last_event.get("ok", false)
			and int(hit.get("unravel_added", hit.get("unravel", 0))) == 0,
			"unprinted Jab/Snip charge stays zero after physical cast " + id)
	for id in ["warden_seam_breaker", "tinker_spool_launcher"]:
		if not await _start_sewn([id], "loose_thread_glove", "seamstress"):
			return
		var quote: Dictionary = live._combo_preview(id)
		var row := _quote_row(quote, 1)
		var before := _state()
		_check(not row.is_empty() and row["unravel_added"] ==
			int(targeting.combo_definition(id)["effects"]["unravel"])
			and _state() == before, "another hero's sewn glove gives no quote bonus " + id)
		await _choose(id, 1, false)
		var hit: Dictionary = live.last_event.get("hits", [{}])[0]
		_check(live.last_event.get("ok", false)
			and int(hit.get("unravel_added", hit.get("unravel", 0))) ==
			int(targeting.combo_definition(id)["effects"]["unravel"]),
			"unrelated wearer glove gives no paid bonus " + id)
	for id in ["warden_seam_breaker", "tinker_spool_launcher"]:
		var owner: String = targeting.combo_definition(id)["owner"]
		if not await _start_sewn([id], "loose_thread_glove", owner, true):
			return
		var before := _state()
		var quote: Dictionary = live._combo_preview(id)
		_check(not quote.get("playable", false)
			and live._play._patches.active_snapshot()[owner].is_empty(),
			"torn wearer's glove dormant and their owned card unplayable " + id)
		var panel := _panel(id)
		await _click(panel)
		live._queue_attack(1)
		await _frames()
		_check(_state() == before and not live.last_event.get("ok", false),
			"torn wearer refuses queued physical hit without any spend " + id)
	for id in ["warden_seam_breaker", "tinker_spool_launcher"]:
		var owner: String = targeting.combo_definition(id)["owner"]
		if not await _start_sewn([id], "loose_thread_glove", owner):
			return
		var panel := _panel(id)
		await _click(panel)
		live._queue_attack(1)
		_check(live._queued, "genuine worn hand queued before authority invalidates " + id)
		live._play._patches._valid = false
		var before := _state()
		await _frames()
		_check(not live._combo_preview(id).get("playable", false)
			and _state() == before and not live.last_event.get("ok", false),
			"invalid explicit worn authority denies both quote and queued commit " + id)



## Patch damage joins cross-owner Pin before Weak/Exposed rounding. Conditional
## Snip still sees the real half-threshold without inventing Unravel.
func _sewn_status_interactions() -> void:
	if not await _start_sewn(["warden_pinning_jab", "tinker_spool_launcher"],
			"pincushion_arm", "tinker"):
		return
	_check(app.enemies.gain_block(1, 70),
		"patched Pinned/Weak/Exposed enemy survives")
	app.party._heroes[2]["statuses"] = {"weak": 2}
	app.enemies._enemies[0]["statuses"] = {"exposed": 2}
	await _choose("warden_pinning_jab", 1, true)
	_check(live._pinned.pinner_for_enemy(1) == "warden",
		"real Warden Jab pins cross-owner target")
	var before := _state()
	var quote: Dictionary = live._combo_preview("tinker_spool_launcher")
	var row := _quote_row(quote, 1)
	_check(not row.is_empty() and row["pin_bonus"] == 5
		and row["tinker_first_attack_bonus"] == 3 and row["damage"] == 13
		and row["unravel_added"] == 3 and _state() == before,
		"worn Spool floors (3+3+5+1)*3/4*3/2 to 13")
	await _choose("tinker_spool_launcher", 1, false)
	_check(live.last_event.get("ok", false)
		and live.last_event["hits"][0]["damage"] == 13
		and live._pinned.pinner_for_enemy(1).is_empty()
		and live._play._tinker._consumed
		and app.enemies.get_enemy(1)["hp"] == row.get("hp_after")
		and live._unravel.get_snapshot(1) == row.get("unravel_after"),
		"patched cross-owner Pin consumed once with exact floored hit")
	if not await _start_sewn(["tinker_snip_the_seam_plus"],
			"pincushion_arm", "tinker"):
		return
	_check(app.enemies.gain_block(1, 70)
		and live._unravel.apply_unravel(app.enemies, 1, 4),
		"real sewn Snip+ reaches half normal threshold")
	var snip_before := _state()
	var snip_quote: Dictionary = live._combo_preview("tinker_snip_the_seam_plus")
	var snip_row := _quote_row(snip_quote, 1)
	_check(not snip_row.is_empty() and snip_row["conditional_empowered"]
		and snip_row["damage"] == 24 and snip_row["unravel_added"] == 0
		and _state() == snip_before,
		"worn empowered Snip+ is 20+3+1 with no Unravel")
	await _choose("tinker_snip_the_seam_plus", 1, true)
	_check(live.last_event.get("ok", false)
		and live.last_event["hits"][0]["damage"] == 24
		and int(live.last_event["hits"][0].get("unravel", 0)) == 0
		and live._unravel.get_snapshot(1) == snip_row.get("unravel_after")
		and app.enemies.get_enemy(1)["hp"] == snip_row.get("hp_after"),
		"real empowered Snip+ honors sewn damage and forecast")


func _sewn_cases() -> void:
	for id in ["warden_seam_breaker", "warden_seam_breaker_plus",
			"tinker_spool_launcher", "tinker_spool_launcher_plus"]:
		for mouse in [true, false]:
			await _sewn_hit(id, "loose_thread_glove",
				"warden" if id.begins_with("warden") else "tinker", mouse,
				mouse and id in ["warden_seam_breaker", "tinker_spool_launcher"])
	for id in ["warden_seam_breaker", "warden_seam_breaker_plus",
			"tinker_spool_launcher", "tinker_spool_launcher_plus"]:
		await _sewn_hit(id, "pincushion_arm",
			"warden" if id.begins_with("warden") else "tinker", true)
	for owner in ["warden", "tinker"]:
		await _sewn_first_hit(owner)
	await _sewn_refusals()
	await _sewn_status_interactions()
	# The next App instance must not inherit a previous battle's worn authority.
	if await _start(["warden_seam_breaker"]):
		_check(live._play._patches == null
			and live._warden_combo.get_patches() == null
			and _quote_row(live._combo_preview("warden_seam_breaker"), 1)["unravel_added"] == 4,
			"new unworn battle starts with clean patch authority and legacy charge")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _eight_live_casts()
	await _pin_and_status()
	await _unravel_turns()
	await _snip_conditions()
	await _rejections()
	await _sewn_cases()
	if app != null:
		app.free()
	print("live_pool_combo_hand_test: %d checks, %d failures" % [checks, failures.size()])
	for issue in failures:
		printerr("FAIL: " + issue)
	quit(0 if failures.is_empty() else 1)
