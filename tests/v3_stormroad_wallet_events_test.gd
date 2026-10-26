extends SceneTree
## Deterministic headless test for the six V3-4 stormroad wallet Events appended
## to data/events/m04_events.json.
##
## The expected stories below are an independent copy of the authored contract;
## the production catalog is never read back as its own oracle. Only per-ID
## membership is asserted: no catalog total, no complete ordered ID list and no
## absolute index. The test covers:
##   - the raw JSON records (exact id/title/description and three choices with
##     visible text and signed gold/scraps outcomes, a genuine free Leave, no
##     required_hero) appended after the older v3_amber_hem_undertaker tail;
##   - the shipped app catalog loader and the default RunM04EventRotation both
##     admitting each story, with the older anchors untouched and quiet_spool
##     still special;
##   - a seeded forced selection per story (every other eligible ID excluded) that
##     draws exactly once and returns a detached record;
##   - the real sewn Event panel scene, driven by keyboard and signal, settling
##     each trade once when funded, exactly at the boundary, refusing every
##     shortfall without charging or claiming, then accepting the free Leave and
##     refusing replay;
##   - the RunEventChoice service's own funded, shortfall and replay behaviour.

const EVENTS_PATH := "res://data/events/m04_events.json"
const ROADSIDE_EVENTS_PATH := "res://data/events/v3_roadside_events.json"
const PANEL_SCENE := "res://scenes/event_choice_panel.tscn"
const SPECIAL_ID := "quiet_spool"
const TAIL_ANCHOR_ID := "v3_amber_hem_undertaker"
const SEED_BASE := 287000

const EXPECTED := {
	"v3_stormglass_seam_survey": {
		"title": "The Stormglass Seam Survey",
		"description": "A one-eyed ragdoll surveyor pins weathered maps beneath a lamp of midnight glass.",
		"choices": [
			{"id": "copy_atlas", "text": "Copy a storm atlas for the road (+11 gold)", "gold": 11, "scraps": 0},
			{"id": "buy_waterproof_thread", "text": "Buy waterproof seam thread (-14 gold, +2 scraps)", "gold": -14, "scraps": 2},
			{"id": "shelter", "text": "Shelter from the storm and leave", "gold": 0, "scraps": 0},
		],
	},
	"v3_ironbutton_tidepool": {
		"title": "The Ironbutton Tidepool",
		"description": "Tin-button shells rattle against a quilted seawall beneath a cold button moon.",
		"choices": [
			{"id": "gather_seathread", "text": "Gather washed-up sea-thread (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "sell_rigging", "text": "Trade one spare rigging scrap (+17 gold, -1 scrap)", "gold": 17, "scraps": -1},
			{"id": "leave_shore", "text": "Leave the tidepool undisturbed", "gold": 0, "scraps": 0},
		],
	},
	"v3_needle_moon_bakery": {
		"title": "The Needle-Moon Bakery",
		"description": "A velvet ragdoll baker pulls bread-shaped pincushions from a glowing thimble oven.",
		"choices": [
			{"id": "carry_baskets", "text": "Carry the quilted bread baskets (+12 gold)", "gold": 12, "scraps": 0},
			{"id": "buy_oven_twines", "text": "Buy oven-proof twine (-13 gold, +2 scraps)", "gold": -13, "scraps": 2},
			{"id": "walk_on", "text": "Walk past the warm windows", "gold": 0, "scraps": 0},
		],
	},
	"v3_velvet_kite_roost": {
		"title": "The Velvet Kite Roost",
		"description": "Button-eyed cloth kites snag in a blackthorn tree beside the candlelit road.",
		"choices": [
			{"id": "retie_kites", "text": "Retie two kite tails (-2 scraps, +29 gold)", "gold": 29, "scraps": -2},
			{"id": "salvage_knots", "text": "Gather fallen kite knots (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "leave_kites", "text": "Leave the kites to the wind", "gold": 0, "scraps": 0},
		],
	},
	"v3_mossbutton_weather_station": {
		"title": "The Mossbutton Weather Station",
		"description": "A moss-green button-doll keeps a storm vane spinning atop a patched roof.",
		"choices": [
			{"id": "repair_vane", "text": "Repair the wind vane (-1 scrap, +19 gold)", "gold": 19, "scraps": -1},
			{"id": "buy_stormward", "text": "Buy stormward thread (-16 gold, +2 scraps)", "gold": -16, "scraps": 2},
			{"id": "pass_station", "text": "Leave the weather station", "gold": 0, "scraps": 0},
		],
	},
	"v3_ragdoll_bell_foundry": {
		"title": "The Ragdoll Bell Foundry",
		"description": "Toy foundry workers hammer tiny brass bells in a furnace-lit felt workshop.",
		"choices": [
			{"id": "polish_clappers", "text": "Polish the bell clappers (-2 scraps, +31 gold)", "gold": 31, "scraps": -2},
			{"id": "sweep_ribbons", "text": "Sweep up brass ribbons (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "leave_foundry", "text": "Leave the foundry before nightfall", "gold": 0, "scraps": 0},
		],
	},
}

## Older stories that must stay selectable and unchanged: title and each choice's
## [gold, scraps] outcome, written out independently of the catalog.
const ANCHORS := {
	"button_trail": {
		"title": "The Button Trail",
		"deltas": {"follow": [0, 1], "leave": [-12, 2], "sell_buttons": [18, -1]},
	},
	"v3_amber_hem_undertaker": {
		"title": "The Amber-Hem Undertaker",
		"deltas": {"repair_velvet_hem": [18, -1], "buy_lantern_wick": [-15, 2], "offer_respect": [0, 0]},
	},
	"v3_raincoat_bridge": {
		"title": "The Raincoat Bridge",
		"deltas": {"salvage_hems": [0, 1], "trade_fare": [-12, 2], "take_detour": [0, 0]},
	},
}

var failures: Array[String] = []
var checks := 0
var app: Node
var commits: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(key: int) -> void:
	for state in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key as Key
		event.pressed = state
		root.push_input(event, true)
	await _frames()


func _on_commit(result: Dictionary) -> void:
	commits.append(result.duplicate(true))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var sources: Dictionary = _test_source_records()
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var live: Dictionary = app._load_wallet_event_catalog()
	_check(not live.is_empty(), "the shipped app catalog loader admits the combined catalogs")
	var live_rotation := RunM04EventRotation.new(live)
	var default_rotation := RunM04EventRotation.new()
	_check(live_rotation.is_catalog_valid(), "the app-loaded catalog validates as a rotation")
	_check(default_rotation.is_catalog_valid(), "the default shipped rotation validates")
	_test_admission(live_rotation, default_rotation, sources)
	var index := 0
	for event_id in EXPECTED:
		var record: Dictionary = _test_forced_selection(live_rotation, event_id, SEED_BASE + index)
		index += 1
		if record.is_empty():
			continue
		await _test_live_panel(record, EXPECTED[event_id])
		_test_service_flows(record, EXPECTED[event_id])
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("v3_stormroad_wallet_events_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _parse_events(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, path + " opens through FileAccess")
	if file == null:
		return []
	var parser := JSON.new()
	var parsed := parser.parse(file.get_as_text())
	file.close()
	_check(parsed == OK and parser.data is Dictionary, path + " parses as a JSON object")
	if parsed != OK or not parser.data is Dictionary:
		return []
	var events: Variant = (parser.data as Dictionary).get("events")
	_check(events is Array, path + " has an events array")
	return events if events is Array else []


## Direct JSON inspection of the six appended records. Returns the source record
## of each new ID so later steps can compare the selector's copies to it.
func _test_source_records() -> Dictionary:
	var events: Array = _parse_events(EVENTS_PATH)
	var roadside: Array = _parse_events(ROADSIDE_EVENTS_PATH)
	var sources: Dictionary = {}
	var positions: Dictionary = {}
	for i in range(events.size()):
		var entry: Variant = events[i]
		if entry is Dictionary and (entry as Dictionary).get("id") is String:
			var key: String = (entry as Dictionary)["id"]
			positions[key] = i if not positions.has(key) else -1
	_check(positions.has(TAIL_ANCHOR_ID) and positions[TAIL_ANCHOR_ID] >= 0,
		"the older tail story " + TAIL_ANCHOR_ID + " is present exactly once")
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var matches: Array = events.filter(func(entry): return entry is Dictionary and entry.get("id") == event_id)
		_check(matches.size() == 1, "exactly one authored record for " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		sources[event_id] = record
		if positions.has(TAIL_ANCHOR_ID) and positions.has(event_id):
			_check(positions[event_id] > positions[TAIL_ANCHOR_ID],
				event_id + " is appended after the older tail " + TAIL_ANCHOR_ID)
		_check(record.keys().size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices") and not record.has("required_hero"),
			"authored record carries exactly id/title/description/choices: " + event_id)
		_check(record.get("title") == contract["title"], "authored title: " + event_id)
		_check(record.get("description") == contract["description"], "authored description: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3, "exactly three authored choices: " + event_id)
		if not choices is Array or (choices as Array).size() != 3:
			continue
		var expected_choices: Array = contract["choices"]
		var seen_ids: Dictionary = {}
		var free_count := 0
		for i in range(3):
			var choice: Variant = (choices as Array)[i]
			var want: Dictionary = expected_choices[i]
			_check(choice is Dictionary, "choice is an object: %s #%d" % [event_id, i])
			if not choice is Dictionary:
				continue
			var label: String = event_id + " / " + str(want["id"])
			_check((choice as Dictionary).keys().size() == 3, "choice carries exactly id/text/outcome: " + label)
			_check(choice.get("id") == want["id"], "authored choice ID in order: " + label)
			_check(choice.get("text") == want["text"], "authored visible choice text: " + label)
			seen_ids[choice.get("id")] = true
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).keys().size() == 2, "wallet-only outcome: " + label)
			if not outcome is Dictionary:
				continue
			var gold: Variant = (outcome as Dictionary).get("gold")
			var scraps: Variant = (outcome as Dictionary).get("scraps")
			_check((gold is float or gold is int) and (scraps is float or scraps is int), "numeric outcome: " + label)
			if not (gold is float or gold is int) or not (scraps is float or scraps is int):
				continue
			_check(float(gold) == floor(float(gold)) and int(gold) == want["gold"], "exact signed gold: " + label)
			_check(float(scraps) == floor(float(scraps)) and int(scraps) == want["scraps"], "exact signed scraps: " + label)
			if int(gold) == 0 and int(scraps) == 0:
				free_count += 1
		_check(seen_ids.size() == 3, "three distinct choice IDs: " + event_id)
		_check(free_count == 1, "exactly one genuine no-cost Leave: " + event_id)
		var last_choice: Dictionary = (choices as Array)[2]
		_check(_deltas(record).get(last_choice.get("id")) == [0, 0], "the third choice is the free Leave: " + event_id)
	_check(sources.size() == EXPECTED.size(), "every new story was found in the authored catalog")
	# Older anchors keep their authored shape in their own source file.
	for anchor_id in ANCHORS:
		var pool: Array = roadside if anchor_id == "v3_raincoat_bridge" else events
		var anchor_matches: Array = pool.filter(func(entry): return entry is Dictionary and entry.get("id") == anchor_id)
		_check(anchor_matches.size() == 1, "older anchor present exactly once in its source file: " + anchor_id)
		if anchor_matches.size() == 1:
			_check_anchor_record(anchor_matches[0], anchor_id, "source file")
	return sources


func _check_anchor_record(record: Dictionary, anchor_id: String, where: String) -> void:
	var anchor: Dictionary = ANCHORS[anchor_id]
	_check(record.get("title") == anchor["title"], "anchor title unchanged (" + where + "): " + anchor_id)
	_check(_deltas(record) == _expected_anchor_deltas(anchor_id),
		"anchor choice IDs and signed outcomes unchanged (" + where + "): " + anchor_id)


func _expected_anchor_deltas(anchor_id: String) -> Dictionary:
	var result: Dictionary = {}
	var table: Dictionary = ANCHORS[anchor_id]["deltas"]
	for choice_id in table:
		result[choice_id] = [int(table[choice_id][0]), int(table[choice_id][1])]
	return result


func _deltas(record: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var choices: Variant = record.get("choices")
	if not choices is Array:
		return result
	for choice in choices:
		if not choice is Dictionary or not choice.get("outcome") is Dictionary:
			continue
		result[choice.get("id")] = [int(choice["outcome"].get("gold", 0)), int(choice["outcome"].get("scraps", 0))]
	return result


func _test_admission(live_rotation: RunM04EventRotation, default_rotation: RunM04EventRotation, sources: Dictionary) -> void:
	for rotation in [live_rotation, default_rotation]:
		var label: String = "app loader" if rotation == live_rotation else "default rotation"
		var listing: Array = rotation.get_generic_events()
		var ids: Array = rotation.get_generic_event_ids()
		for event_id in EXPECTED:
			_check(ids.count(event_id) == 1, label + " lists once: " + event_id)
			var matches: Array = listing.filter(func(entry): return entry.get("id") == event_id)
			_check(matches.size() == 1, label + " exposes one record: " + event_id)
			if matches.size() == 1 and sources.has(event_id):
				_check(matches[0] == sources[event_id], label + " copies the authored record: " + event_id)
		for anchor_id in ANCHORS:
			_check(ids.count(anchor_id) == 1, label + " keeps the older anchor selectable: " + anchor_id)
			var anchor_matches: Array = listing.filter(func(entry): return entry.get("id") == anchor_id)
			if anchor_matches.size() == 1:
				_check_anchor_record(anchor_matches[0], anchor_id, label)
		_check(not ids.has(SPECIAL_ID), label + " keeps quiet_spool special")


## Excludes every other eligible ID, so the seeded draw must pick this story with
## exactly one randi_range() draw, and the returned record is detached.
func _test_forced_selection(rotation: RunM04EventRotation, event_id: String, seed_value: int) -> Dictionary:
	var excluded: Array = rotation.get_generic_event_ids()
	_check(excluded.has(event_id) and excluded.size() > 1, "a pool with competitors admits " + event_id)
	excluded.erase(event_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var oracle := RandomNumberGenerator.new()
	oracle.seed = seed_value
	oracle.randi_range(0, 0)
	var result: Dictionary = rotation.select_event(rng, excluded)
	_check(result.get("ok") == true, "forced selection succeeds: " + event_id)
	var record: Dictionary = result.get("event", {})
	_check(record.get("id") == event_id, "forced selection returns the story: " + event_id)
	_check(rng.state == oracle.state, "forced selection consumes exactly one draw: " + event_id)
	if record.get("id") != event_id:
		return {}
	var snapshot: Dictionary = record.duplicate(true)
	record["title"] = "MUTATED"
	(record["choices"] as Array).clear()
	var again_rng := RandomNumberGenerator.new()
	again_rng.seed = seed_value
	var again: Dictionary = rotation.select_event(again_rng, excluded)
	_check(again.get("event") == snapshot, "the selected record is detached from the rotation: " + event_id)
	_check(again_rng.state == oracle.state, "a replayed selection ends in the same RNG state: " + event_id)
	return snapshot


func _open_panel(record: Dictionary, wallet: Dictionary) -> LiveEventChoicePanel:
	var panel := (load(PANEL_SCENE) as PackedScene).instantiate() as LiveEventChoicePanel
	root.add_child(panel)
	await _frames()
	commits.clear()
	panel.wallet_choice_committed.connect(_on_commit)
	_check(panel.open_event_with_wallet(record, wallet), "the real panel mounts the wallet Event: " + str(record.get("id")))
	await _frames()
	return panel


func _close_panel(panel: LiveEventChoicePanel) -> void:
	panel.close_event()
	panel.free()
	await _frames()


func _is_debit(choice: Dictionary) -> bool:
	return choice["gold"] < 0 or choice["scraps"] < 0


func _wallet_after(wallet: Dictionary, choice: Dictionary) -> Dictionary:
	return {"gold": wallet["gold"] + choice["gold"], "scraps": wallet["scraps"] + choice["scraps"]}


## Drives the real sewn panel scene by keyboard (1/2/3) and by its pressed signal.
func _test_live_panel(record: Dictionary, contract: Dictionary) -> void:
	var event_id: String = record["id"]
	var expected_choices: Array = contract["choices"]
	var leave_index := -1
	for i in range(expected_choices.size()):
		if expected_choices[i]["gold"] == 0 and expected_choices[i]["scraps"] == 0:
			leave_index = i
	_check(leave_index >= 0, "the contract lists a free Leave: " + event_id)
	if leave_index < 0:
		return

	# Funded wallet: every option is enabled and settles its exact deltas once.
	var funded := {"gold": 100, "scraps": 10}
	for i in range(expected_choices.size()):
		var choice: Dictionary = expected_choices[i]
		var label: String = event_id + " / " + str(choice["id"])
		var panel: LiveEventChoicePanel = await _open_panel(record, funded)
		var buttons: Array[Button] = panel.get_choice_buttons()
		_check(buttons.size() == 3, "the panel mounts three tickets: " + event_id)
		if buttons.size() != 3:
			await _close_panel(panel)
			continue
		for j in range(3):
			_check(buttons[j].text.begins_with(str(expected_choices[j]["text"])),
				"ticket shows the authored text: %s #%d" % [event_id, j])
			_check(not buttons[j].disabled, "funded ticket is enabled: %s #%d" % [event_id, j])
		_check(panel.title_label.text == contract["title"], "panel shows the authored title: " + event_id)
		_check(panel.description_label.text == contract["description"], "panel shows the authored story: " + event_id)
		await _key(KEY_1 + i)
		_check(commits.size() == 1, "one keyboard press commits once: " + label)
		if commits.size() == 1:
			_check(commits[0].get("event_id") == event_id and commits[0].get("choice_id") == choice["id"],
				"receipt names the story and choice: " + label)
			_check(commits[0].get("wallet") == _wallet_after(funded, choice), "exact signed settlement: " + label)
		for button in buttons:
			_check(button.disabled, "every ticket closes after the claim: " + label)
		for j in range(3):
			buttons[j].pressed.emit()
			await _key(KEY_1 + j)
		_check(commits.size() == 1, "replay cannot settle or spend again: " + label)
		await _close_panel(panel)

	# Exact boundary: a wallet holding precisely the cost still pays, down to zero.
	for i in range(expected_choices.size()):
		var choice: Dictionary = expected_choices[i]
		if not _is_debit(choice):
			continue
		var label: String = event_id + " / " + str(choice["id"])
		var exact := {"gold": maxi(0, -int(choice["gold"])), "scraps": maxi(0, -int(choice["scraps"]))}
		var panel: LiveEventChoicePanel = await _open_panel(record, exact)
		var buttons: Array[Button] = panel.get_choice_buttons()
		if buttons.size() != 3:
			_check(false, "the exact-cost panel mounts three tickets: " + label)
			await _close_panel(panel)
			continue
		_check(not buttons[i].disabled, "an exactly affordable trade stays enabled: " + label)
		buttons[i].pressed.emit()
		_check(commits.size() == 1 and commits[0].get("wallet") == _wallet_after(exact, choice),
			"an exactly funded trade settles its authored deltas: " + label)
		await _close_panel(panel)

	# Shortfalls: one unit short in each debited currency, then a fully empty wallet.
	var shortfalls: Array = [{"gold": 0, "scraps": 0}]
	for choice in expected_choices:
		if choice["gold"] < 0:
			shortfalls.append({"gold": -int(choice["gold"]) - 1, "scraps": 10})
		if choice["scraps"] < 0:
			shortfalls.append({"gold": 100, "scraps": -int(choice["scraps"]) - 1})
	for wallet in shortfalls:
		var wallet_label: String = event_id + " at " + str(wallet)
		var panel: LiveEventChoicePanel = await _open_panel(record, wallet)
		var buttons: Array[Button] = panel.get_choice_buttons()
		if buttons.size() != 3:
			_check(false, "the shortfall panel mounts three tickets: " + wallet_label)
			await _close_panel(panel)
			continue
		var blocked: Array[int] = []
		for i in range(3):
			var choice: Dictionary = expected_choices[i]
			var affordable: bool = wallet["gold"] + choice["gold"] >= 0 and wallet["scraps"] + choice["scraps"] >= 0
			_check(buttons[i].disabled == not affordable,
				"affordability matches the wallet for %s #%d" % [wallet_label, i])
			if not affordable:
				blocked.append(i)
		_check(not blocked.is_empty(), "this wallet really leaves a trade unaffordable: " + wallet_label)
		_check(not buttons[leave_index].disabled, "the free Leave stays enabled: " + wallet_label)
		for i in blocked:
			buttons[i].pressed.emit()
			await _key(KEY_1 + i)
		_check(commits.is_empty(), "disabled trades never settle or charge: " + wallet_label)
		_check(panel.has_open_event() and not buttons[leave_index].disabled,
			"a refused trade does not consume the one-visit choice: " + wallet_label)
		await _key(KEY_1 + leave_index)
		_check(commits.size() == 1 and commits[0].get("choice_id") == expected_choices[leave_index]["id"]
			and commits[0].get("wallet") == wallet, "the free Leave settles without a charge: " + wallet_label)
		for i in blocked:
			buttons[i].pressed.emit()
			await _key(KEY_1 + i)
		buttons[leave_index].pressed.emit()
		_check(commits.size() == 1, "replay after the Leave cannot spend: " + wallet_label)
		await _close_panel(panel)


## The service itself: shortfall rejects without claiming, the Leave works, and
## nothing can be replayed afterwards.
func _test_service_flows(record: Dictionary, contract: Dictionary) -> void:
	var event_id: String = record["id"]
	var expected_choices: Array = contract["choices"]
	var empty := {"gold": 0, "scraps": 0}
	var funded := {"gold": 100, "scraps": 10}
	for choice in expected_choices:
		var label: String = event_id + " / " + str(choice["id"])
		var funded_service := RunEventChoice.new(record)
		var paid: Dictionary = funded_service.choose_with_wallet(choice["id"], funded)
		_check(paid.get("ok") == true and paid.get("wallet") == _wallet_after(funded, choice),
			"service settles the exact signed deltas: " + label)
		_check(funded_service.is_claimed(), "a settled choice is claimed: " + label)
		_check(funded_service.choose_with_wallet(choice["id"], funded).get("ok") == false,
			"service replay is rejected: " + label)
		var poor_service := RunEventChoice.new(record)
		var denied: Dictionary = poor_service.choose_with_wallet(choice["id"], empty)
		if _is_debit(choice):
			_check(denied.get("ok") == false and denied.get("wallet") == empty,
				"service refuses an empty wallet and returns it unchanged: " + label)
			_check(not poor_service.is_claimed() and poor_service.is_valid(),
				"a refused trade leaves the visit unclaimed: " + label)
			var forecast: Dictionary = poor_service.preview_wallet_choices(empty)
			var affordable_rows: Array = (forecast.get("choices", []) as Array).filter(
				func(row): return row.get("choice_id") == choice["id"] and row.get("affordable") == false)
			_check(affordable_rows.size() == 1, "service forecast marks the trade unaffordable: " + label)
			for other in expected_choices:
				if _is_debit(other):
					_check(poor_service.choose_with_wallet(other["id"], empty).get("ok") == false,
						"no debit settles from an empty wallet: " + label + " vs " + str(other["id"]))
			var leave := poor_service.choose_with_wallet(_leave_id(expected_choices), empty)
			_check(leave.get("ok") == true and leave.get("wallet") == empty,
				"the free Leave succeeds after a refusal: " + label)
			_check(poor_service.choose_with_wallet(choice["id"], funded).get("ok") == false,
				"nothing can be spent after the Leave: " + label)
		else:
			_check(denied.get("ok") == true and denied.get("wallet") == _wallet_after(empty, choice),
				"a no-debit choice settles from an empty wallet: " + label)


func _leave_id(choices: Array) -> String:
	for choice in choices:
		if choice["gold"] == 0 and choice["scraps"] == 0:
			return choice["id"]
	return ""
