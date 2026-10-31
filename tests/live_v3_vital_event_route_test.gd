extends "res://tests/live_m04_event_wallet_batch_test.gd"
## Real New Run, four specials, wallet, vitality, and onward routing.
var hp_claims := 0
var cap_claims := 0


func _vital_state() -> Array:
	var carry: RunTornCarryover = app.party_carryover
	return [_wallet_state(), app._vital_event_history.duplicate(),
		carry._max_hp_by_id.duplicate(), carry._receipts.duplicate(true),
		carry._wardrobe.get_snapshot() if carry._wardrobe != null else {}]


func _deny_vital(callback: Callable, why: String) -> void:
	var before := _vital_state()
	if callback.is_valid():
		callback.call()
	_check(_vital_state() == before, why + " preserves all state")


## Independent single-draw oracle: the full shipped story IDs plus the one
## canonical, living-Warden offer. Never call the app's selector.
func _vital_oracle(rng: RandomNumberGenerator, heroes: Array) -> Dictionary:
	var records: Array = RunV3VitalEventRotation.new().get_vital_events()
	var ids: Array = []
	var living_warden := false
	for hero in heroes:
		ids.append(hero.id)
		if hero.id == "warden" and hero.hp > 0:
			living_warden = true
	if living_warden:
		var gate := RunV3HeroVitalEventGate.new(ids)
		_check(gate.is_valid(), "independent oracle authenticates shipped hero vital pack")
		for record in gate.get_offers():
			if record.id == "v3_warden_buckle_heart_ward":
				records.append(record)
	records.sort_custom(func(a, b): return String(a.id) < String(b.id))
	_check(not records.is_empty(), "vital pool contains genuine authored candidates")
	return {"ok": true, "event": records[rng.randi_range(0, records.size() - 1)]}


func _open_sixth(f: Dictionary, negatives: bool, warden_rear: bool = false) -> LiveEventChoicePanel:
	await _reach(f, true, ["rag_duelist", "warden", "tinker"] if warden_rear else ["warden", "seamstress", "tinker"])
	if warden_rear:
		_check(app.run_heroes[1].id == "warden" and app.run_heroes[0].id != "warden",
			"real pick-three places required Warden behind another living hero")
	await _click(_route_action(f.path[4]))
	var wallet: LiveEventChoicePanel = app.wallet_event_panel
	_check(is_instance_valid(wallet) and wallet._wallet_mode, "first generic remains actual wallet story")
	if not is_instance_valid(wallet):
		return null
	var opening_choices: Array = wallet._selector.get_event().choices
	var opening_buttons: Array = wallet.get_choice_buttons()
	# Settle the fifth stop on a genuinely free ticket so the opening wallet
	# (notably its 2 scraps) is intact for the scrap-priced vitality trades.
	# Some stories name Leave differently, so accept any authored zero-cost choice
	# before ever falling back to the first affordable one.
	var settle_index := -1
	for i in range(opening_choices.size()):
		if opening_buttons[i].disabled:
			continue
		var outcome: Dictionary = opening_choices[i].outcome
		if opening_choices[i].id == "leave" \
			or (int(outcome.gold) == 0 and int(outcome.scraps) == 0):
			settle_index = i
			break
	if settle_index < 0:
		for i in range(opening_buttons.size()):
			if not opening_buttons[i].disabled:
				settle_index = i
				break
	var chosen := false
	if settle_index >= 0:
		await _click(opening_buttons[settle_index])
		chosen = true
	_check(chosen and app.wallet_event_panel == null, "fifth Event physically settled before vitality")
	if not chosen:
		return null
	await _traverse_treasures(f, f.next)
	var entry: Callable = _route_action(f.next).pressed.get_connections()[0].callable
	if negatives:
		var catalog: String = app.vital_event_catalog_path
		for invalid in ["res://missing_vital.json", "res://data/heroes/starter_party.json"]:
			app.vital_event_catalog_path = invalid
			_deny_vital(entry, "invalid vitality catalog")
		app.vital_event_catalog_path = catalog
		var heroes: Array = app.run_heroes.duplicate(true)
		for hero in app.run_heroes:
			hero.hp = 0
		_deny_vital(entry, "no living target")
		app.run_heroes = heroes
		var gold: int = app.session_gold
		app.session_gold = -1
		_deny_vital(entry, "negative wallet fails mount without drawing")
		app.session_gold = gold
		_deny_vital(app._open_wallet_event.bind(app.run_map.get_current_node_id(), weakref(app.run_map)),
			"illegal route rolls back staged panel and RNG")
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var expected := _vital_oracle(rng, app.run_heroes)
	await _click(_route_action(f.next))
	var panel: LiveEventChoicePanel = app.wallet_event_panel
	_check(is_instance_valid(panel) and app.route_view == null, "sixth Event genuinely mounts and gates route")
	if not is_instance_valid(panel):
		return null
	_check(panel._vital_mode and panel._selector.get_event() == expected.event
		and app.run_rng.state == rng.state and app._vital_event_history == [expected.event.id],
		"shipped sorted pool uses exactly one run RNG draw")
	var target: Dictionary = {}
	for hero in app.run_heroes:
		if hero.hp > 0 and (not record_id_is_warden(panel) or hero.id == "warden"):
			target = {"id": hero.id, "hp": hero.hp, "max_hp": hero.max_hp}
			break
	_check(not target.is_empty() and panel._offered_snapshot.hero == target,
		"authored target is live and Warden is selected regardless of position")
	if record_id_is_warden(panel):
		_check(app._vital_event_gate != null and app._vital_event_gate.is_valid()
			and app._vital_event_gate.get_event() == expected.event
			and app._vital_event_gate.get_snapshot() == panel._offered_snapshot,
			"real mounted Warden gate binds canonical offer and living hero")
	else:
		_check(app._vital_event_gate == null, "ordinary stories retain their ungated service")
	var style := panel.paper_panel.get_theme_stylebox("panel")
	_check(style is StyleBoxTexture or style is StyleBoxFlat, "sewn parchment or readable fallback mounted")
	_deny_vital(entry, "duplicate route signal")
	return panel


func record_id_is_warden(panel: LiveEventChoicePanel) -> bool:
	return panel._selector.get_event().id == "v3_warden_buckle_heart_ward"


func _settle(f: Dictionary, choice_index: int, keyboard: bool, negatives: bool,
		warden_rear: bool = false) -> void:
	var panel := await _open_sixth(f, negatives, warden_rear)
	if panel == null:
		return
	var record := panel._selector.get_event()
	var before := panel._offered_snapshot.duplicate(true)
	var previews := RunEventChoice.new(record).preview_vital_choices(before)
	_check(previews.ok and previews.choices.size() == record.choices.size(), "all authored choices forecast")
	for i in range(record.choices.size()):
		_check(panel.get_choice_buttons()[i].disabled == not previews.choices[i].affordable,
			"live affordability matches exact four-delta service")
		if panel.get_choice_buttons()[i].disabled:
			var state := _vital_state()
			await _click(panel.get_choice_buttons()[i])
			await _key(KEY_1 + i)
			panel.get_choice_buttons()[i].pressed.emit()
			_check(_vital_state() == state and not panel._selector.is_claimed(), "unaffordable mouse keyboard signal inert")
	if choice_index >= record.choices.size() or panel.get_choice_buttons()[choice_index].disabled:
		await _return_title()
		return
	var choice: Dictionary = record.choices[choice_index]
	var receipt := RunEventChoice.new(record).choose_with_vitals(choice.id, before)
	_check(receipt.ok, "real affordable authored claim exists")
	if record_id_is_warden(panel):
		_check((choice.id == "reinforce_shield_seam"
			and int(choice.outcome.gold) == 0 and int(choice.outcome.scraps) == -2
			and int(choice.outcome.hp) == 0 and int(choice.outcome.max_hp) == 3
			and before.scraps >= 2) or (choice.id == "sell_rivets"
			and int(choice.outcome.gold) == 24 and int(choice.outcome.scraps) == 0
			and int(choice.outcome.hp) == 0 and int(choice.outcome.max_hp) == -2)
			or choice.id == "leave", "Warden's mounted tickets retain exact authored trade prices")
	var commit: Callable = panel.vital_choice_committed.get_connections()[0].callable
	_deny_vital(commit.bind(receipt), "matching intent cannot bypass physical claim")
	var heroes: Array = app.run_heroes.duplicate(true)
	var carry: RunTornCarryover = app.party_carryover
	var ledger := carry.torn.read_state()
	var unrelated := [app.run_deck.duplicate(), app.run_trinkets.duplicate(),
		app.run_stitch_descriptors.duplicate(true), app.run_rng.state]
	panel.vital_choice_committed.disconnect(commit)
	if keyboard:
		await _key(KEY_1 + choice_index)
	else:
		await _click(panel.get_choice_buttons()[choice_index])
	_check(panel._selector.is_claimed() and panel._committed_choice == receipt, "physical claim produces exact pending receipt")
	var forged := receipt.duplicate(true)
	forged.state.hero.max_hp += 1
	panel._committed_choice = forged
	_deny_vital(commit.bind(forged), "forged cap rejected by authored recomputation")
	panel._committed_choice = receipt
	app.run_scraps += 1
	_deny_vital(commit.bind(receipt), "stale purse")
	app.run_scraps -= 1
	app.run_heroes[0].hp -= 1
	_deny_vital(commit.bind(receipt), "stale hero")
	app.run_heroes = heroes.duplicate(true)
	var current: String = app.run_map.get_current_node_id()
	app.run_map._nodes[current].type = "Treasure"
	_deny_vital(commit.bind(receipt), "wrong node type")
	app.run_map._nodes[current].type = "Event"
	commit.call(receipt)
	var hp: int = mini(before.hero.hp + int(choice.outcome.hp), before.hero.max_hp + int(choice.outcome.max_hp))
	for hero in heroes:
		if hero.id == before.hero.id:
			hero.hp = hp
			hero.max_hp += int(choice.outcome.max_hp)
	_check(app.wallet_event_panel == null and is_instance_valid(app.route_view)
		and app.run_heroes == heroes and carry.read_state().heroes == heroes
		and carry.torn.read_state().heroes == heroes
		and _wallet() == {"gold": before.gold + int(choice.outcome.gold), "scraps": before.scraps + int(choice.outcome.scraps)},
		"settles exact authored purse HP and permanent cap once")
	_check([app.run_deck, app.run_trinkets, app.run_stitch_descriptors, app.run_rng.state] == unrelated,
		"settlement preserves deck patches and RNG")
	ledger.heroes = heroes
	ledger.completed_vital_events.append(current)
	for actor in heroes:
		ledger.vital_cap_offsets[actor.id] = int(choice.outcome.max_hp) if actor.id == before.hero.id else 0
	_check(carry.torn.read_state() == ledger, "vital receipt preserves tears and all prior receipts")
	var party := carry.create_next_fight_party()
	_check(party != null and party.is_valid() and party.get_heroes() == heroes,
		"next Fight hydrates exact vitality state")
	if int(choice.outcome.hp) != 0:
		hp_claims += 1
	if int(choice.outcome.max_hp) != 0:
		cap_claims += 1
	_deny_vital(commit.bind(receipt), "stale settled signal")
	var carry_before := carry.read_state()
	_check(not carry.apply_vital_event(current, record, receipt, before, carry_before, null)
		and carry.read_state() == carry_before, "duplicate node cannot replay into ledger")
	var rest := RunRestRecovery.new(heroes).choose_heal()
	_check(carry.choose_rest_heal("after_vital_rest").ok and carry.read_state().heroes == rest.heroes,
		"Rest remains valid after vitality")
	await _return_title()
	_check(app._vital_event_history.is_empty() and app._wallet_event_context.is_empty(), "title clears vitality session")


func _later_wallet() -> void:
	var fixture := {}
	for value in range(1, 500000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var path := _event_path(map, map.get_legal_choices(), 7)
		if path.is_empty():
			continue
		var events: Array = []
		var transit := {}
		var treasures: Array = []
		for id in path:
			if map.get_node(id).type != "Event":
				treasures.append(id)
			else:
				transit[id] = treasures.duplicate()
				treasures.clear()
				events.append(id)
		fixture = {"seed": value, "path": events.slice(0, 5), "next": events[5],
			"later": events[6], "transit": transit}
		break
	_check(not fixture.is_empty(), "genuine seven-Event route exists")
	if fixture.is_empty():
		return
	var panel := await _open_sixth(fixture, false)
	if panel == null:
		return
	for button in panel.get_choice_buttons():
		if not button.disabled:
			await _click(button)
			break
	await _traverse_treasures(fixture, fixture.later)
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var ids := _generic_route_ids()
	for id in app._wallet_event_history:
		ids.erase(id)
	var picked: String = ids[rng.randi_range(0, ids.size() - 1)]
	var selection := {"event": {}}
	for record in RunM04EventRotation.new(_combined_catalog()).get_generic_events():
		if record.id == picked:
			selection.event = record
	var health: Array = app.run_heroes.duplicate(true)
	await _click(_route_action(fixture.later))
	panel = app.wallet_event_panel
	_check(is_instance_valid(panel) and panel._wallet_mode and not panel._vital_mode
		and panel._selector.get_event() == selection.event and app.run_rng.state == rng.state,
		"seventh Event returns to genuine seeded wallet rotation")
	if not is_instance_valid(panel):
		return
	for i in range(panel.get_choice_buttons().size()):
		if not panel.get_choice_buttons()[i].disabled:
			var receipt := RunEventChoice.new(selection.event).choose_with_wallet(selection.event.choices[i].id, _wallet())
			await _key(KEY_1 + i)
			_check(app.wallet_event_panel == null and _wallet() == receipt.wallet and app.run_heroes == health,
				"later wallet remains keyboard playable with vitality preserved")
			break
	await _return_title()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var fixtures := _fixtures()
	_check(not fixtures.is_empty(), "real seeded route witnesses exist")
	# Use genuine seeded maps and every affordable choice until both kinds of
	# vitality effect have been witnessed through mouse and number-key dispatch.
	for keyboard in [false, true]:
		var initial_hp := hp_claims
		var initial_caps := cap_claims
		for id in fixtures:
			# These fifth-stop IDs mount their own dedicated visit, not the
			# generic wallet parchment required before a vitality slot.
			if id in ["frayed_debt_parcel", RunFatePinAuction.EVENT_ID]:
				continue
			for index in range(3):
				await _settle(fixtures[id], index, keyboard, hp_claims == 0)
			if hp_claims > initial_hp and cap_claims > initial_caps:
				break
		_check(hp_claims > initial_hp and cap_claims > initial_caps, "mouse/keyboard cover HP and permanent cap outcomes")
	# A naturally seeded sixth Event must reach the Warden twice: pay the 2
	# scraps for +3 permanent cap, then trade -2 cap for +24 gold. The same
	# real button flow proves each exact receipt and onward continuation.
	var warden_fixture: Dictionary = {}
	for id in fixtures:
		if id in ["frayed_debt_parcel", RunFatePinAuction.EVENT_ID]:
			continue
		var candidate: Dictionary = fixtures[id]
		var witness := RandomNumberGenerator.new()
		witness.state = candidate.after_draw
		var party := CombatParty.new(app._load_party_definitions()).get_heroes()
		if _vital_oracle(witness, party).event.id == "v3_warden_buckle_heart_ward":
			warden_fixture = candidate
			break
	_check(not warden_fixture.is_empty(), "genuine seeded map and single RNG draw offer Buckle-Heart")
	if not warden_fixture.is_empty():
		var warden_caps := cap_claims
		for keyboard in [false, true]:
			await _settle(warden_fixture, 0, keyboard, true, true)
			await _settle(warden_fixture, 1, keyboard, true, true)
		_check(cap_claims == warden_caps + 4,
			"mouse and keyboard really settle Buckle-Heart's +3 and -2 cap trades")
	var no_warden := CombatParty.new(app._load_party_definitions()).get_heroes()
	for hero in no_warden:
		if hero.id == "warden":
			hero.hp = 0
	var excluded := RandomNumberGenerator.new()
	excluded.seed = 399
	var before_exclusion := excluded.state
	var excluded_offer := _vital_oracle(excluded, no_warden)
	_check(excluded_offer.event.id != "v3_warden_buckle_heart_ward"
		and excluded.state != before_exclusion, "dead Warden excluded from single-draw pool")
	await _later_wallet()
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_v3_vital_event_route_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
