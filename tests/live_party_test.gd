extends SceneTree

const IDS := ["warden", "seamstress", "tinker"]
const NAMES := ["Warden", "Seamstress", "Tinker"]
const MAX_HP := [40, 30, 26]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _deck_snapshot(deck: CombatDeck) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(),
		deck.discard_pile.duplicate(), deck.energy, deck.turn_active]


func _visible(app) -> void:
	_check(is_instance_valid(app.hero_view) and app.hero_view.is_visible_in_tree(), "hero row visible")
	if not is_instance_valid(app.hero_view):
		return
	_check(app.hero_view != app.hand_view and app.hero_view.get_parent() == app.hand_view.get_parent(),
		"heroes occupy a separate row from hand")
	_check(app.hero_view.get_child_count() == 3 and app.hero_panels.size() == 3, "three mounted hero panels")
	for index in range(3):
		if index >= app.hero_view.get_child_count():
			_check(false, "ordered hero panel missing")
			continue
		var panel = app.hero_view.get_child(index)
		_check(panel is PanelContainer and panel.is_visible_in_tree(), "hero panel visible")
		_check(index < app.hero_panels.size() and app.hero_panels[index] == panel, "panel reference matches mounted order")
		var label = panel.get_child(0) if panel.get_child_count() > 0 else null
		_check(label is Label and label.is_visible_in_tree(), "hero label exists and is visible")
		if label is Label:
			var hero: Dictionary = app.party.get_hero(index + 1)
			var expected := "%d - %s\nHP: %d/%d | Block: %d%s" % [
				index + 1, NAMES[index], hero["hp"], MAX_HP[index], hero["block"],
				"\nDOWNED" if hero["hp"] == 0 else ""]
			_check(label.text == expected, "ordered identity, HP, Block and downed text accurate")


func _fresh(app) -> void:
	_check(app.party is CombatParty and app.party.is_valid(), "Start Run creates valid actual party")
	if app.party == null or not app.party.is_valid():
		return
	var heroes: Array = app.party.get_heroes()
	_check(heroes.size() == 3, "three starting heroes")
	for index in range(3):
		var hero: Dictionary = app.party.get_hero(index + 1)
		_check(hero["id"] == IDS[index] and hero["name"] == NAMES[index] and hero["position"] == index + 1,
			"design identity and implicit position")
		_check(hero["hp"] == MAX_HP[index] and hero["max_hp"] == MAX_HP[index] and hero["block"] == 0,
			"design HP and zero starting Block")
		_check(not app.party.is_downed(index + 1), "starting hero alive")


func _invalid_sources(app) -> void:
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_PARTY_PATH))
	var duplicate := definitions.duplicate(true)
	duplicate[1]["id"] = duplicate[0]["id"]
	var fraction := definitions.duplicate(true)
	fraction[0]["max_hp"] = 40.5
	var bad_name := definitions.duplicate(true)
	bad_name[0]["name"] = ""
	var invalid_id := definitions.duplicate(true)
	invalid_id[0]["id"] = 7
	var negative := definitions.duplicate(true)
	negative[0]["max_hp"] = -1
	var string_hp := definitions.duplicate(true)
	string_hp[0]["max_hp"] = "40"
	var path := "user://live_party_invalid.json"
	for source in ["{", "{}", "[]", JSON.stringify(definitions.slice(0, 2)),
		JSON.stringify(duplicate), JSON.stringify(fraction), JSON.stringify(bad_name),
		JSON.stringify(invalid_id), JSON.stringify(negative), JSON.stringify(string_hp), "[null,null,null]"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "invalid data fixture opened outside repository")
		if file == null:
			continue
		file.store_string(source)
		file.close()
		app.starter_party_path = path
		app.start_button.pressed.emit()
		_check(app.party == null and app.deck == null and app.run_rng == null and app.battle_view == null,
			"invalid definitions fail closed without partial session")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "invalid data retains focused title")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	app.starter_party_path = path # The fixture has now been removed.
	app.start_button.pressed.emit()
	_check(app.party == null and app.deck == null and app.run_rng == null and app.battle_view == null,
		"missing definitions fail closed")
	app.starter_party_path = app.STARTER_PARTY_PATH


func _run() -> void:
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_check(is_instance_valid(app.start_button), "real Start Run button exists")
	if not is_instance_valid(app.start_button):
		app.free()
		_finish()
		return
	_check(app.party == null and app.hero_view == null and app.hero_panels.is_empty(), "title boots without party UI")
	_check(app.start_button.is_visible_in_tree() and app.start_button.has_focus(), "title boots focused")
	app._end_turn()
	_check(app.party == null and app.deck == null, "inactive End Turn cannot create a party")
	_invalid_sources(app)
	var source: Array[String] = []
	source.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var first_trace: Array = []
	for session in range(2):
		app.start_button.pressed.emit()
		_fresh(app)
		_check(app.deck != null and app.run_rng != null and is_instance_valid(app.end_turn_button)
			and is_instance_valid(app.return_button), "real session and battle actions created")
		if app.party == null or app.deck == null or not is_instance_valid(app.end_turn_button) or not is_instance_valid(app.return_button):
			app.free()
			_finish()
			return
		await process_frame
		if session == 0:
			if "--inject-missing-panel" in OS.get_cmdline_user_args():
				app.hero_view.get_child(0).free()
			if "--inject-wrong-text" in OS.get_cmdline_user_args():
				app.hero_view.get_child(0).get_child(0).text = "wrong"
		_visible(app)
		if not failures.is_empty():
			app.free()
			_finish()
			return
		_check(app.end_turn_button.has_focus(), "battle retains keyboard focus")
		var party: CombatParty = app.party
		var rng := RandomNumberGenerator.new()
		rng.seed = app.run_seed
		var reference := CombatDeck.new(source, rng)
		_check(reference.start_turn(), "reference starts actual turn")
		_check(party.apply_damage(1, 7) and party.gain_block(1, 9) and party.gain_block(2, 4), "live party gains damage and Block")
		_check(party.apply_damage(3, 26) and party.is_downed(3), "live hero is actually downed")
		app._refresh_party()
		_visible(app)
		var before := party.get_heroes()
		for position in [-1, 0, 4]:
			_check(not party.apply_damage(position, 5) and not party.heal(position, 5)
				and not party.gain_block(position, 5) and party.get_hero(position).is_empty(), "invalid target rejected")
		_check(not party.apply_damage(1, -1) and not party.heal(1, -1) and not party.gain_block(1, -1), "negative amounts rejected")
		_check(not party.heal(3, 1) and not party.gain_block(3, 1) and not party.apply_damage(3, 1), "downed targets rejected")
		_check(party.get_heroes() == before, "invalid targets and amounts cannot mutate live party")
		var deck_before := _deck_snapshot(app.deck)
		var rng_before: int = app.run_rng.state
		app.start_button.pressed.emit()
		_check(app.party == party and party.get_heroes() == before and _deck_snapshot(app.deck) == deck_before
			and app.run_rng.state == rng_before, "duplicate Start Run preserves party, deck and RNG")
		var trace: Array = []
		for turn in range(12):
			_check(_deck_snapshot(app.deck) == _deck_snapshot(reference) and app.run_rng.state == rng.state,
				"live hand, energy and RNG follow unchanged deterministic deck")
			trace.append(_deck_snapshot(app.deck))
			_check(app.deck.try_spend_energy(2) and reference.try_spend_energy(2), "live shared energy can be spent")
			_check(not app.deck.try_spend_energy(2) and not app.deck.start_turn(), "no-spend and duplicate turn rejected")
			_check(party.gain_block(1, 3), "Block added before real End Turn")
			app.end_turn_button.pressed.emit()
			_check(reference.end_turn() and reference.start_turn(), "reference advances")
			_check(app.party == party, "End Turn retains party instance")
			for position in range(1, 4):
				var hero := party.get_hero(position)
				_check(hero["block"] == 0 and hero["hp"] == before[position - 1]["hp"]
					and hero["position"] == position, "End Turn resets Block, retains HP and positions")
			_check(party.is_downed(3), "End Turn retains downed state")
			_visible(app)
		_check(_deck_snapshot(app.deck) == _deck_snapshot(reference), "final End Turn retains deck and energy behavior")
		if session == 0:
			first_trace = trace
		else:
			_check(trace == first_trace, "fresh session replays twelve deterministic hands")
		_check(app.deck.end_turn() and party.gain_block(1, 8), "create real inactive deck with existing Block")
		before = party.get_heroes()
		deck_before = _deck_snapshot(app.deck)
		rng_before = app.run_rng.state
		app.end_turn_button.pressed.emit()
		_check(party.get_heroes() == before and _deck_snapshot(app.deck) == deck_before
			and app.run_rng.state == rng_before, "rejected inactive End Turn preserves all live state")
		var old_party: WeakRef = weakref(party)
		var view_id: int = app.hero_view.get_instance_id()
		party = null
		app.return_button.pressed.emit()
		await process_frame
		_check(app.party == null and app.hero_view == null and app.hero_panels.is_empty(), "Return to Title clears party and panel references")
		_check(old_party.get_ref() == null and not is_instance_id_valid(view_id), "old party released and panels freed")
		_check(app.deck == null and app.run_rng == null and app.battle_view == null, "Return to Title clears session")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "Return to Title restores focus")
		app._end_turn()
		app._return_to_title()
		_check(app.party == null and app.hero_panels.is_empty(), "inactive actions retain cleared party")
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_party_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
