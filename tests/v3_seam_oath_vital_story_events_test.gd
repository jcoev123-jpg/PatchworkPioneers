extends SceneTree
## Deterministic headless regression for the four gothic seam-oath vitality
## roadside stories appended to data/events/v3_vital_story_events.json.
##
## Expectations here are authored independently of the catalog: the real JSON is
## loaded through FileAccess + JSON and every record is located by ID, never by
## catalog total, position or the full ordered list.

const VITAL_EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

const FUNDED_GOLD := 60
const FUNDED_SCRAPS := 6
const FUNDED_HP := 24
const FUNDED_MAX_HP := 40

# Earlier named anchors that must survive this append untouched.
const ANCHOR_IDS := [
	"v3_lantern_quilt_infirmary",
	"v3_button_heart_shrine",
	"v3_gloam_marionette_pipe_organ",
]

# Independent authored table. Choice rows: [id, text, gold, scraps, hp, max_hp].
const SEAM_OATH_EVENTS := {
	"v3_ironlace_heron_bell": {
		"title": "The Ironlace Heron Bell",
		"description": "A tall ink-blue heron ragdoll with a silver needle beak rings a cracked iron mourning bell through damp candle fog.",
		"choices": [
			["ring_iron_bell", "Pull the bell rope (lose 5 HP; gain 2 max HP)", 0, 0, -5, 2],
			["buy_quiet_wax", "Pay 13 gold for warm bell-wax balm (+8 HP)", -13, 0, 8, 0],
			["leave", "Let the iron bell fall silent", 0, 0, 0, 0],
		],
	},
	"v3_oxblood_mole_pinwheel": {
		"title": "The Oxblood Mole Pinwheel",
		"description": "A stout button-eyed mole cranks a giant rusted needle pinwheel above an oxblood quilt burrow lit by one amber lamp.",
		"choices": [
			["turn_pinwheel", "Spend 2 scraps to stitch a stronger seam (+3 max HP)", 0, -2, 0, 3],
			["mine_rust_pins", "Pull the sharp old pins (lose 6 HP; gain 22 gold)", 22, 0, -6, 0],
			["leave", "Leave the mole winding its wheel", 0, 0, 0, 0],
		],
	},
	"v3_sable_fox_candle_cage": {
		"title": "The Sable Fox Candle Cage",
		"description": "A round sable fox puppet holds an oversized brass birdcage of guttering candles; red stitches glow along its velvet muzzle.",
		"choices": [
			["buy_caged_light", "Pay 20 gold and 1 scrap for a warm seam (+7 HP; +1 max HP)", -20, -1, 7, 1],
			["trade_wick_thread", "Unpick the candle wicks (lose 4 HP; gain 2 scraps)", 0, 2, -4, 0],
			["leave", "Let the fox shutter its candle cage", 0, 0, 0, 0],
		],
	},
	"v3_bonewhite_finch_sundial": {
		"title": "The Bonewhite Finch Sundial",
		"description": "A plump bone-cream finch doll balances a cracked brass sundial on its back, casting a needle-thin shadow across the fog.",
		"choices": [
			["rewind_sundial", "Pay 16 gold to set the healing dial (+10 HP)", -16, 0, 10, 0],
			["borrow_sun_needle", "Surrender 2 max HP for the finch's purse (+28 gold)", 28, 0, 0, -2],
			["leave", "Pass before the last shadow turns", 0, 0, 0, 0],
		],
	},
}

var failures: Array[String] = []
var checks := 0
var catalog: Array = []


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _initialize() -> void:
	catalog = _load_events(VITAL_EVENTS_PATH)
	_check(not catalog.is_empty(), "vital story catalog is non-empty")
	_test_new_records()
	_test_anchors_persist()
	_test_settlement_and_claims()
	_test_refusals_then_leave()
	_test_rotation_admission()
	for failure in failures:
		printerr(failure)
	print("v3_seam_oath_vital_story_events_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _load_events(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "events file opens: " + path)
	if file == null:
		return []
	var parser := JSON.new()
	var parse_result := parser.parse(file.get_as_text())
	file.close()
	_check(parse_result == OK and parser.data is Dictionary
		and (parser.data as Dictionary).get("events") is Array,
		"events file parses to {events: [...]}: " + path)
	if parse_result != OK or not parser.data is Dictionary \
		or not (parser.data as Dictionary).get("events") is Array:
		return []
	return (parser.data as Dictionary)["events"]


func _matching(event_id: String) -> Array:
	return catalog.filter(func(entry: Variant) -> bool:
		return entry is Dictionary and (entry as Dictionary).get("id") == event_id)


func _record(event_id: String) -> Dictionary:
	var matches := _matching(event_id)
	if matches.size() != 1:
		return {}
	return (matches[0] as Dictionary).duplicate(true)


func _vital_state(gold: int, scraps: int, hp: int, max_hp: int) -> Dictionary:
	return {"gold": gold, "scraps": scraps, "hero": {"id": "warden", "hp": hp, "max_hp": max_hp}}


func _vital_state_is(state: Variant, gold: int, scraps: int, hp: int, max_hp: int) -> bool:
	if not state is Dictionary:
		return false
	var dict: Dictionary = state
	if dict.size() != 3 or not dict.get("hero") is Dictionary:
		return false
	var hero: Dictionary = dict["hero"]
	return (hero.size() == 3 and hero.get("id") == "warden"
		and typeof(dict.get("gold")) == TYPE_INT and int(dict["gold"]) == gold
		and typeof(dict.get("scraps")) == TYPE_INT and int(dict["scraps"]) == scraps
		and typeof(hero.get("hp")) == TYPE_INT and int(hero["hp"]) == hp
		and typeof(hero.get("max_hp")) == TYPE_INT and int(hero["max_hp"]) == max_hp)


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and (entry as Dictionary).get("choice_id") == choice_id:
			return entry
	return {}


func _is_integral_json_number(value: Variant, allow_negative: bool = false) -> bool:
	if typeof(value) == TYPE_INT:
		return allow_negative or int(value) >= 0
	if typeof(value) == TYPE_FLOAT:
		var num: float = value
		return (is_finite(num) and floor(num) == num
			and num <= RunEventChoice.MAX_SAFE_FLOAT_INT
			and num >= (-RunEventChoice.MAX_SAFE_FLOAT_INT if allow_negative else 0.0))
	return false


func _expected_state(row: Array) -> Array:
	var gold: int = FUNDED_GOLD + int(row[2])
	var scraps: int = FUNDED_SCRAPS + int(row[3])
	var max_hp: int = FUNDED_MAX_HP + int(row[5])
	var hp: int = mini(FUNDED_HP + int(row[4]), max_hp)
	return [gold, scraps, hp, max_hp]


func _test_new_records() -> void:
	for event_id in SEAM_OATH_EVENTS:
		var expected: Dictionary = SEAM_OATH_EVENTS[event_id]
		var matches := _matching(event_id)
		_check(matches.size() == 1, "new seam-oath ID appears exactly once: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"new record has exact top-level keys: " + event_id)
		_check(record.get("title") == expected["title"], "new title exact: " + event_id)
		_check(record.get("description") == expected["description"], "new description exact: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3, "new record has three choices: " + event_id)
		if not choices is Array:
			continue
		var by_id: Dictionary = {}
		for choice in (choices as Array):
			_check(choice is Dictionary and (choice as Dictionary).size() == 3
				and (choice as Dictionary).has("id") and (choice as Dictionary).has("text")
				and (choice as Dictionary).has("outcome"),
				"new choice has id/text/outcome keys: " + event_id)
			if choice is Dictionary and (choice as Dictionary).get("id") is String:
				var cid: String = choice["id"]
				_check(not by_id.has(cid), "new choice IDs are distinct: " + event_id + "/" + cid)
				by_id[cid] = choice
			if choice is Dictionary and (choice as Dictionary).get("outcome") is Dictionary:
				var outcome: Dictionary = choice["outcome"]
				_check(outcome.size() == 4 and outcome.has("gold") and outcome.has("scraps")
					and outcome.has("hp") and outcome.has("max_hp"),
					"new outcome has exactly four keys: " + event_id + "/" + str(choice.get("id")))
		var wanted: Array = expected["choices"]
		_check(by_id.size() == wanted.size(), "new choice count matches expected: " + event_id)
		for row in wanted:
			var tag: String = event_id + "/" + row[0]
			_check(by_id.has(row[0]), "new choice present: " + tag)
			if not by_id.has(row[0]):
				continue
			var choice_dict: Dictionary = by_id[row[0]]
			_check(choice_dict.get("text") == row[1], "new choice text exact: " + tag)
			if choice_dict.get("outcome") is Dictionary:
				var outcome: Dictionary = choice_dict["outcome"]
				var keys := ["gold", "scraps", "hp", "max_hp"]
				for i in range(4):
					var raw: Variant = outcome.get(keys[i])
					_check(_is_integral_json_number(raw, true) and int(raw) == int(row[2 + i]),
						"new outcome " + keys[i] + " exact: " + tag)
		_check(by_id.has("leave"), "new record offers a Leave choice: " + event_id)
		if by_id.has("leave"):
			var leave_outcome: Variant = (by_id["leave"] as Dictionary).get("outcome")
			_check(leave_outcome is Dictionary
				and int((leave_outcome as Dictionary).get("gold")) == 0
				and int((leave_outcome as Dictionary).get("scraps")) == 0
				and int((leave_outcome as Dictionary).get("hp")) == 0
				and int((leave_outcome as Dictionary).get("max_hp")) == 0,
				"new Leave choice is zero-effect: " + event_id)
		var service := RunEventChoice.new(record.duplicate(true))
		_check(service.is_valid() and not service.is_claimed(),
			"new record builds a valid unclaimed selector: " + event_id)


func _test_anchors_persist() -> void:
	for anchor_id in ANCHOR_IDS:
		var matches := _matching(anchor_id)
		_check(matches.size() == 1, "earlier anchor still present once: " + anchor_id)
		if matches.size() == 1:
			var anchor: Dictionary = matches[0]
			_check(anchor.get("id") == anchor_id and anchor.get("title") is String
				and not (anchor["title"] as String).is_empty()
				and anchor.get("description") is String
				and not (anchor["description"] as String).is_empty()
				and anchor.get("choices") is Array,
				"earlier anchor record is intact: " + anchor_id)


func _test_settlement_and_claims() -> void:
	# Fresh selector per choice; funded living Warden {60 gold, 6 scraps, 24/40 HP}.
	for event_id in SEAM_OATH_EVENTS:
		var expected: Dictionary = SEAM_OATH_EVENTS[event_id]
		for row in (expected["choices"] as Array):
			var choice_id: String = row[0]
			var tag: String = event_id + "/" + choice_id
			var target: Array = _expected_state(row)
			var record := _record(event_id)
			_check(not record.is_empty(), "authored record available: " + tag)
			if record.is_empty():
				continue
			var record_before: Dictionary = record.duplicate(true)
			var rng := RandomNumberGenerator.new()
			rng.seed = 76100
			var rng_state_before := rng.state

			var preview_service := RunEventChoice.new(record.duplicate(true))
			var snapshot: Dictionary = _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
			var snapshot_before: Dictionary = snapshot.duplicate(true)
			var preview := preview_service.preview_vital_choices(snapshot)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and (preview.get("choices") as Array).size() == 3,
				"preview ok with three choices: " + tag)
			var entry := _preview_choice(preview, choice_id)
			_check(not entry.is_empty() and entry.get("choice_id") == choice_id
				and entry.get("gold_delta") == int(row[2])
				and entry.get("scraps_delta") == int(row[3])
				and entry.get("hp_delta") == int(row[4])
				and entry.get("max_hp_delta") == int(row[5]),
				"preview reports exact signed deltas: " + tag)
			_check(entry.get("affordable") == true
				and _vital_state_is(entry.get("state"), target[0], target[1], target[2], target[3]),
				"funded preview projects the exact state: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and preview_service.is_valid() and not preview_service.is_claimed(),
				"preview mutates neither input nor source: " + tag)

			var commit_service := RunEventChoice.new(record.duplicate(true))
			var commit := commit_service.choose_with_vitals(choice_id, snapshot)
			_check(commit.size() == 4 and commit.get("ok") == true
				and commit.get("event_id") == event_id and commit.get("choice_id") == choice_id
				and _vital_state_is(commit.get("state"), target[0], target[1], target[2], target[3]),
				"funded commit settles the exact state: " + tag)
			_check(commit.get("state") == entry.get("state"), "commit matches preview: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and commit_service.get_event() == record_before,
				"commit mutates neither input nor source: " + tag)
			_check(commit_service.is_claimed() and not commit_service.is_valid(),
				"commit latches exactly one claim: " + tag)
			_check(rng.state == rng_state_before, "preview and commit spend no seeded RNG: " + tag)

			var replay_snapshot: Dictionary = _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
			var replay := commit_service.choose_with_vitals(choice_id, replay_snapshot)
			_check(replay.get("ok") == false and replay.get("event_id") == ""
				and replay.get("state") == replay_snapshot,
				"replay on a spent visit is rejected unchanged: " + tag)

	# Leave is free on its own fresh selector.
	var leave_record := _record("v3_ironlace_heron_bell")
	_check(not leave_record.is_empty(), "leave record available")
	if not leave_record.is_empty():
		var leave_service := RunEventChoice.new(leave_record)
		var leave_snapshot: Dictionary = _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
		var leave_before: Dictionary = leave_snapshot.duplicate(true)
		var leave := leave_service.choose_with_vitals("leave", leave_snapshot)
		_check(leave.get("ok") == true and leave.get("choice_id") == "leave"
			and leave.get("state") == leave_before and leave_snapshot == leave_before
			and leave_service.is_claimed(),
			"free Leave settles the funded snapshot unchanged")
		_check(leave_service.choose_with_vitals("leave", leave_snapshot).get("ok") == false,
			"Leave replay on a spent visit is rejected")


func _test_refusals_then_leave() -> void:
	# One representative shortage per class; each refusal must not claim, must
	# leave the snapshot and source untouched, then the free Leave must settle.
	var cases := [
		{"event": "v3_ironlace_heron_bell", "choice": "buy_quiet_wax",
			"state": _vital_state(12, 6, 24, 40), "label": "lack of gold"},
		{"event": "v3_oxblood_mole_pinwheel", "choice": "turn_pinwheel",
			"state": _vital_state(60, 1, 24, 40), "label": "lack of scraps"},
		{"event": "v3_ironlace_heron_bell", "choice": "ring_iron_bell",
			"state": _vital_state(60, 6, 5, 40), "label": "HP debit to zero"},
		{"event": "v3_bonewhite_finch_sundial", "choice": "borrow_sun_needle",
			"state": _vital_state(60, 6, 10, 10), "label": "max HP floor"},
	]
	for case_data in cases:
		var event_id: String = case_data["event"]
		var choice_id: String = case_data["choice"]
		var tag: String = (case_data["label"] as String) + " " + event_id + "/" + choice_id
		var state: Dictionary = (case_data["state"] as Dictionary).duplicate(true)
		var original: Dictionary = state.duplicate(true)
		var record := _record(event_id)
		_check(not record.is_empty(), "refusal case has its record: " + tag)
		if record.is_empty():
			continue
		var record_before: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(record)
		var rng := RandomNumberGenerator.new()
		rng.seed = 76200
		var rng_state_before := rng.state

		var preview := service.preview_vital_choices(state)
		var entry := _preview_choice(preview, choice_id)
		_check(preview.get("ok") == true and not entry.is_empty()
			and entry.get("affordable") == false and entry.get("state") == original,
			"refused branch is forecast unavailable: " + tag)
		var refusal := service.choose_with_vitals(choice_id, state)
		_check(refusal.size() == 4 and refusal.get("ok") == false
			and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
			and refusal.get("state") == original,
			"refused branch rejects with unchanged detached state: " + tag)
		_check(state == original and record == record_before
			and service.is_valid() and not service.is_claimed(),
			"refusal claims and mutates nothing: " + tag)

		var leave := service.choose_with_vitals("leave", state)
		_check(leave.get("ok") == true and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave" and leave.get("state") == original
			and service.is_claimed() and not service.is_valid(),
			"free Leave settles the same visit after refusal: " + tag)
		_check(rng.state == rng_state_before, "refusal and Leave spend no seeded RNG: " + tag)
		_check(service.choose_with_vitals("leave", state).get("ok") == false
			and service.choose_with_vitals(choice_id, state).get("ok") == false
			and state == original,
			"spent visit rejects Leave and branch replay: " + tag)


func _test_rotation_admission() -> void:
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "shipped vitality rotation validates with this batch appended")
	var listing: Array = rotation.get_vital_events()
	var listing_before: Array = listing.duplicate(true)
	var ids: Array = rotation.get_vital_event_ids()
	var seed_value := 76300
	for event_id in SEAM_OATH_EVENTS:
		var tag: String = "rotation " + event_id
		var authored := _record(event_id)
		_check(not authored.is_empty(), "authored record is readable: " + tag)
		_check(ids.count(event_id) == 1, "new ID is eligible exactly once: " + tag)
		var offered: Array = listing.filter(func(entry: Variant) -> bool:
			return entry is Dictionary and (entry as Dictionary).get("id") == event_id)
		_check(offered.size() == 1, "new ID is offered exactly once: " + tag)
		if offered.size() == 1:
			_check((offered[0] as Dictionary) == authored,
				"offered record matches the authored source: " + tag)

		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var result := rotation.select_event(rng, excluded)
		_check(result.get("ok") == true
			and (result.get("event") as Dictionary).get("id") == event_id,
			"new ID is selected when every other ID is excluded: " + tag)
		_check(result.get("event") == authored, "forced selection returns the authored record: " + tag)
		_check(rng.state == oracle.state, "forced selection consumes exactly one range draw: " + tag)
		var selected := RunEventChoice.new(result.get("event"))
		_check(selected.is_valid() and not selected.is_claimed(),
			"selected event is an unclaimed valid visit: " + tag)
		seed_value += 1
	_check(rotation.get_vital_events() == listing_before,
		"rotation flows leave the shipped pool unchanged")
