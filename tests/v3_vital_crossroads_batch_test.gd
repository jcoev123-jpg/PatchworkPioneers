extends SceneTree
## Independent per-record oracles; never freeze the shared catalog's total/order.
## Rows: choice ID, caption, gold, scraps, HP, max HP.
const STORIES := {
	"v3_candle_bell_tollhouse": ["The Candle-Bell Tollhouse",
		"A stout velvet tollkeeper grips a brass bell beside a midnight-teal bridge wrapped in glowing lantern thread.", [
		["buy_guard_seam", "Pay 13 gold and 1 scrap for a guarded seam (+2 max HP)", -13, -1, 0, 2],
		["watch_bell", "Stand the cold bell watch (lose 5 HP; gain 17 gold)", 17, 0, -5, 0],
		["leave", "Pass the bell without a bargain", 0, 0, 0, 0]]],
	"v3_inkfern_apothecary": ["The Inkfern Apothecary",
		"A round button-eyed herbalist tends dark stitched ferns inside a bone-cream tent lit by rose lanterns.", [
		["buy_inkfern_wrap", "Pay 16 gold for an inkfern wrap (+10 HP)", -16, 0, 10, 0],
		["press_fading_fern", "Trade 2 max HP of lasting seam for 3 scraps", 0, 3, 0, -2],
		["leave", "Leave the ferns to the moon", 0, 0, 0, 0]]],
	"v3_silver_stitch_observatory": ["The Silver-Stitch Observatory",
		"A plump star-chart doll winds silver thread around an enormous telescope under a plum quilt sky.", [
		["stitch_starchart", "Spend 3 scraps to mend 3 HP and gain 2 max HP", 0, -3, 3, 2],
		["watch_lonely_star", "Watch the cold star (lose 6 HP; gain 26 gold)", 26, 0, -6, 0],
		["leave", "Fold the chart and depart", 0, 0, 0, 0]]],
	"v3_sable_button_foundry": ["The Sable Button Foundry",
		"A squat soot-coloured buttonsmith works a velvet furnace, its giant brass buttons glowing like small suns.", [
		["temper_button_heart", "Pay 18 gold and 1 scrap for a strong button heart (+3 max HP)", -18, -1, 0, 3],
		["pawn_old_heart", "Pawn the old heart seam (lose 2 max HP; gain 25 gold)", 25, 0, 0, -2],
		["leave", "Let the foundry fire die down", 0, 0, 0, 0]]],
	"v3_briarlace_ferry": ["The Briarlace Ferry",
		"A round velvet ferryman poles a lantern-lit boat through mossy water stitched with thorny lace.", [
		["ford_cold_water", "Ford the cold water (lose 4 HP; gain 8 gold and 2 scraps)", 8, 2, -4, 0],
		["buy_sheltered_crossing", "Pay 15 gold for a sheltered crossing (+7 HP)", -15, 0, 7, 0],
		["leave", "Stay on the safe bank", 0, 0, 0, 0]]],
	"v3_lantern_wisp_clocktower": ["The Lantern-Wisp Clocktower",
		"A button-eyed moth clockkeeper winds luminous brass hands above a tower quilted in deep oxblood and teal.", [
		["mend_broken_hours", "Spend 2 scraps to restore 8 HP and gain 1 max HP", 0, -2, 8, 1],
		["sell_missing_hour", "Sell one lasting hour (lose 1 max HP; gain 21 gold)", 21, 0, 0, -1],
		["leave", "Let the clock strike without you", 0, 0, 0, 0]]],
}
const ANCHORS := {
	"v3_lantern_quilt_infirmary": ["The Lantern-Quilt Infirmary",
		"A round, button-eyed nurse hangs warm quilts beside a midnight-teal lantern.", [
		["buy_bandages", "Pay 12 gold to dress one hero's wounds (+8 HP)", -12, 0, 8, 0],
		["blood_receipt", "Donate 4 HP for a purse of 18 gold", 18, 0, -4, 0],
		["leave", "Leave the lantern burning", 0, 0, 0, 0]]],
	"v3_button_heart_shrine": ["The Button-Heart Shrine",
		"A moss-cloaked doll tends a beating brass button stitched into a chapel wall.", [
		["reinforce_heart", "Spend 2 scraps to sew a lasting heart seam (+3 max HP)", 0, -2, 0, 3],
		["surrender_button", "Give up 2 max HP for 24 gold", 24, 0, 0, -2],
		["leave", "Let the little heart keep ticking", 0, 0, 0, 0]]],
	"v3_nightquilt_watchtower": ["The Nightquilt Watchtower",
		"A stout button-eyed watch doll guards a tower of midnight-teal quilts with a broad quilted lantern-shield.", [
		["keep_night_watch", "Take the night watch (lose 7 HP; earn 23 gold and 1 scrap)", 23, 1, -7, 0],
		["sew_watchtower_hem", "Pay 12 gold and 2 scraps for a lasting watch hem (+3 max HP)", -12, -2, 0, 3],
		["leave", "Pass beneath the shield in peace", 0, 0, 0, 0]]],
}
const AMOUNTS := ["gold", "scraps", "hp", "max_hp"]
var failures: Array[String] = []
var checks := 0
var catalog: Array = []


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _matches(records: Array, id: String) -> Array:
	return records.filter(func(record: Variant) -> bool:
		return record is Dictionary and record.get("id") == id)


func _expected(id: String, row: Array) -> Dictionary:
	var choices: Array = []
	for choice in row[2]:
		# Match the JSON parser's numeric representation, with integrality checked separately.
		choices.append({"id": choice[0], "text": choice[1], "outcome": {
			"gold": float(choice[2]), "scraps": float(choice[3]),
			"hp": float(choice[4]), "max_hp": float(choice[5])}})
	return {"id": id, "title": row[0], "description": row[1], "choices": choices}


func _state(gold: int = 60, scraps: int = 6, hp: int = 20, maximum: int = 30) -> Dictionary:
	return {"gold": gold, "scraps": scraps, "hero": {"id": "warden", "hp": hp, "max_hp": maximum}}


func _initialize() -> void:
	var file := FileAccess.open("res://data/events/v3_vital_story_events.json", FileAccess.READ)
	_check(file != null, "shipping JSON opens")
	if file != null:
		var parser := JSON.new()
		var error := parser.parse(file.get_as_text())
		file.close()
		_check(error == OK and parser.data is Dictionary, "shipping JSON parses")
		if error == OK and parser.data is Dictionary:
			var records: Variant = parser.data.get("events")
			_check(records is Array and not records.is_empty(), "nonempty events array")
			if records is Array:
				catalog = records
	if not catalog.is_empty():
		var before := catalog.duplicate(true)
		_check_records(ANCHORS)
		_check_records(STORIES)
		for id in STORIES:
			var matches := _matches(catalog, id)
			if matches.size() != 1:
				continue
			var record: Dictionary = matches[0]
			_test_rotation(record)
			_test_choices(record, STORIES[id][2])
		_check(catalog == before, "all tests preserve source records")
	for failure in failures:
		printerr(failure)
	print("v3_vital_crossroads_batch_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check_records(table: Dictionary) -> void:
	for id in table:
		var matches := _matches(catalog, id)
		_check(matches.size() == 1, "source ID present once: " + id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record == _expected(id, table[id]), "exact authored record and key sets: " + id)
		var seen := {}
		for choice in record.get("choices", []):
			_check(not seen.has(choice["id"]), "distinct choice ID: " + id)
			seen[choice["id"]] = true
			for key in AMOUNTS:
				var value: Variant = choice["outcome"].get(key)
				# Godot's JSON parser represents JSON integer literals as floats.
				_check(typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT
					and is_finite(value) and floor(value) == value), "integral delta: " + id + "/" + key)


func _test_rotation(record: Dictionary) -> void:
	var id: String = record["id"]
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "default catalog valid: " + id)
	var ids := rotation.get_vital_event_ids()
	_check(ids.count(id) == 1, "eligible once: " + id)
	var listing := rotation.get_vital_events()
	var offered := _matches(listing, id)
	_check(offered.size() == 1 and offered[0] == record, "listing matches source: " + id)
	if offered.size() == 1:
		offered[0]["choices"][0]["outcome"]["gold"] = 999
	_check(_matches(rotation.get_vital_events(), id) == [record], "listing is deeply detached: " + id)
	var excluded := ids.duplicate()
	excluded.erase(id)
	var before := excluded.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 359
	var oracle := RandomNumberGenerator.new()
	oracle.seed = 359
	oracle.randi_range(0, 0)
	var selected := rotation.select_event(rng, excluded)
	_check(selected == {"ok": true, "event": record}, "forced selection: " + id)
	_check(rng.state == oracle.state, "exactly one range draw: " + id)
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = 359
	_check(rotation.select_event(replay_rng, excluded) == selected and replay_rng.state == rng.state,
		"seeded selection replay: " + id)
	if selected.get("event") is Dictionary and not selected["event"].is_empty():
		selected["event"]["choices"][0]["outcome"]["gold"] = 999
		selected["event"]["title"] = "changed"
	_check(_matches(rotation.get_vital_events(), id) == [record]
		and _matches(catalog, id) == [record], "selection deeply detached: " + id)
	excluded.append(id)
	var rng_before := rng.state
	_check(rotation.select_event(rng, excluded) == {"ok": false, "event": {}}, "exhausted refusal: " + id)
	_check(rng.state == rng_before, "exhaustion consumes no RNG: " + id)
	excluded.erase(id)
	_check(excluded == before, "selection preserves caller exclusions: " + id)


func _success(record: Dictionary, row: Array, snapshot: Dictionary) -> void:
	var tag: String = record["id"] + "/" + row[0]
	var original := snapshot.duplicate(true)
	var source := record.duplicate(true)
	var maximum: int = snapshot["hero"]["max_hp"] + row[5]
	var expected := _state(snapshot["gold"] + row[2], snapshot["scraps"] + row[3],
		mini(snapshot["hero"]["hp"] + row[4], maximum), maximum)
	var service := RunEventChoice.new(record)
	_check(service.is_valid() and not service.is_claimed(), "valid fresh visit: " + tag)
	var preview := service.preview_vital_choices(snapshot)
	_check(preview.get("ok") == true and preview.get("event_id") == record["id"]
		and preview.get("choices", []).size() == 3, "preview has three choices: " + tag)
	var entries: Array = preview.get("choices", []).filter(func(entry: Dictionary) -> bool:
		return entry.get("choice_id") == row[0])
	_check(entries.size() == 1, "preview choice exists once: " + tag)
	if entries.size() == 1:
		_check(entries[0] == {"choice_id": row[0], "gold_delta": row[2], "scraps_delta": row[3],
			"hp_delta": row[4], "max_hp_delta": row[5], "affordable": true, "state": expected},
			"exact preview deltas and max-first capped state: " + tag)
	_check(service.is_valid() and not service.is_claimed() and snapshot == original,
		"preview is read only: " + tag)
	var receipt := service.choose_with_vitals(row[0], snapshot)
	_check(receipt == {"ok": true, "event_id": record["id"], "choice_id": row[0], "state": expected},
		"exact successful receipt: " + tag)
	_check(service.is_claimed() and not service.is_valid(), "one claim latched: " + tag)
	_check(service.choose_with_vitals(row[0], snapshot) == {
		"ok": false, "event_id": "", "choice_id": "", "state": original}, "replay denied: " + tag)
	_check(service.preview_vital_choices(snapshot) == {"ok": false, "event_id": "", "choices": []},
		"claimed preview denied: " + tag)
	if receipt.get("state") is Dictionary and receipt["state"].has("hero"):
		receipt["state"]["hero"]["hp"] = 999
	_check(snapshot == original and record == source and service.get_event() == source,
		"caller and source preserved, receipt detached: " + tag)


func _refusal(record: Dictionary, choice_id: String, snapshot: Dictionary) -> void:
	var tag: String = record["id"] + "/" + choice_id
	var original := snapshot.duplicate(true)
	var source := record.duplicate(true)
	var service := RunEventChoice.new(record)
	_check(service.is_valid(), "valid refusal fixture: " + tag)
	if choice_id != "unknown":
		var preview := service.preview_vital_choices(snapshot)
		var entries: Array = preview.get("choices", []).filter(func(entry: Dictionary) -> bool:
			return entry.get("choice_id") == choice_id)
		_check(preview.get("ok") == true and entries.size() == 1, "refused preview present: " + tag)
		if entries.size() == 1:
			_check(entries[0].get("affordable") == false and entries[0].get("state") == original,
				"unaffordable preview leaves state unchanged: " + tag)
	var result := service.choose_with_vitals(choice_id, snapshot)
	_check(result == {"ok": false, "event_id": "", "choice_id": "", "state": original},
		"refusal preserves state: " + tag)
	_check(service.is_valid() and not service.is_claimed(), "refusal leaves visit open: " + tag)
	result["state"]["hero"]["hp"] = 999
	_check(snapshot == original and record == source and service.get_event() == source,
		"refusal detached and source unchanged: " + tag)
	_check(service.choose_with_vitals("leave", snapshot) == {
		"ok": true, "event_id": record["id"], "choice_id": "leave", "state": original},
		"free Leave after refusal on same visit: " + tag)
	_check(service.is_claimed() and not service.is_valid()
		and service.choose_with_vitals("leave", snapshot).get("ok") == false and snapshot == original,
		"Leave consumes one claim without mutation: " + tag)


func _test_choices(record: Dictionary, rows: Array) -> void:
	# Settlement has no RNG argument: guard the global generator against hidden use.
	seed(359)
	var next_draw := randi()
	seed(359)
	for row in rows:
		_success(record, row, _state())
		for index in range(4):
			var delta: int = row[index + 2]
			if delta >= 0:
				continue
			var exact := _state()
			var short := _state()
			match index:
				0, 1:
					exact[AMOUNTS[index]] = -delta
					short[AMOUNTS[index]] = -delta - 1
				2:
					exact["hero"]["hp"] = -delta + 1
					short["hero"]["hp"] = -delta
					_refusal(record, row[0], _state(60, 6, 1))
				3:
					exact["hero"] = {"id": "warden", "hp": 10, "max_hp": 10 - delta}
					short["hero"] = {"id": "warden", "hp": 10, "max_hp": 9 - delta}
			_success(record, row, exact)
			_refusal(record, row[0], short)
		if row[4] > 0 or row[5] != 0:
			_success(record, row, _state(60, 6, 29, 30))
	# Every story has a paid/dangerous path refused by this empty wallet/1-HP state.
	var paid: Array = rows[0]
	_refusal(record, paid[0], _state(0, 0, 1))
	_refusal(record, "unknown", _state())
	_check(randi() == next_draw, "all previews, successes, refusals and replays preserve RNG: " + record["id"])
