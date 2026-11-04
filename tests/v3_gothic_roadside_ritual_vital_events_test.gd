extends SceneTree
## Deterministic headless regression for the four gothic roadside ritual
## vitality stories appended to data/events/v3_vital_story_events.json.
##
## Expectations are authored independently of the catalog: the shipped JSON is
## read through FileAccess + JSON and every record is located by ID, never by a
## catalog total, position or the full ordered list. Selection replays through
## an independent one-range-draw oracle, and every rejection is proven to
## consume no RNG draw.

const VITAL_EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

const FUNDED_GOLD := 60
const FUNDED_SCRAPS := 6
const FUNDED_HP := 20
const FUNDED_MAX_HP := 30

# Earlier named anchors that must survive this append untouched.
const ANCHOR_IDS := [
	"v3_lantern_quilt_infirmary",
	"v3_button_heart_shrine",
	"v3_mourning_organ_ward",
	"v3_ossuary_spool_chandelier",
]

# Independent authored table. Choice rows are
# [id, text, gold, scraps, hp, max_hp, final_gold, final_scraps, final_hp, final_max_hp]
# where the final tuple is the exact result from the funded snapshot.
const ROADSIDE_EVENTS := {
	"v3_sable_sheep_seam_scales": {
		"title": "The Seam Scales",
		"description": "A stout midnight-blue sheep doll balances two brass weighing pans, one cradling a stitched heart and the other a frayed spool, beneath an amber awning.",
		"choices": [
			["weigh_warm_stuffing", "Spend 2 scraps to balance a warm heart seam (heal 6 HP; gain 1 max HP)", 0, -2, 6, 1, 60, 4, 26, 31],
			["sell_heavy_heart", "Carry the heavy heart pan (lose 4 HP; gain 20 gold)", 20, 0, -4, 0, 80, 6, 16, 30],
			["leave", "Let the sheep's brass scales settle", 0, 0, 0, 0, 60, 6, 20, 30],
		],
	},
	"v3_oxblood_peacock_mourning_fan": {
		"title": "The Peacock's Mourning Fan",
		"description": "A plump oxblood peacock puppet opens a towering black-lace funeral fan, its stitched silver button-eyes glinting above a single candle.",
		"choices": [
			["mend_fan_ribs", "Pay 16 gold to reinforce the mourning fan (+2 max HP)", -16, 0, 0, 2, 44, 6, 20, 32],
			["pluck_brittle_ribs", "Pull sharp fan ribs (lose 5 HP; gain 2 scraps)", 0, 2, -5, 0, 60, 8, 15, 30],
			["leave", "Leave the peacock folding its funeral fan", 0, 0, 0, 0, 60, 6, 20, 30],
		],
	},
	"v3_copper_boar_needle_harp": {
		"title": "The Needle Harp",
		"description": "A chunky rust-felt boar ragdoll plucks a crescent copper harp strung with silver sewing needles, its blunt padded tusks haloed by warm lamplight.",
		"choices": [
			["tune_heart_strings", "Pay 12 gold and 1 scrap to tune the heart strings (heal 4 HP; gain 2 max HP)", -12, -1, 4, 2, 48, 5, 24, 32],
			["play_torn_chord", "Play the torn needle chord (lose 6 HP; gain 23 gold)", 23, 0, -6, 0, 83, 6, 14, 30],
			["leave", "Let the boar's last harp note fade", 0, 0, 0, 0, 60, 6, 20, 30],
		],
	},
	"v3_plum_beetle_lantern_lift": {
		"title": "The Lantern Lift",
		"description": "A squat plum-and-midnight-teal beetle doll braces a quilt-lined iron lift on its shell; tiny brass candle cages sway overhead in the dark.",
		"choices": [
			["ride_quilt_lift", "Spend 1 scrap to ride beneath the warm quilts (heal 9 HP)", 0, -1, 9, 0, 60, 5, 29, 30],
			["haul_cages", "Trade 2 lasting heart stitches hauling candle cages (lose 2 max HP; gain 25 gold)", 25, 0, 0, -2, 85, 6, 20, 28],
			["leave", "Let the lantern lift descend without you", 0, 0, 0, 0, 60, 6, 20, 30],
		],
	},
}

# Concrete insufficiencies: each non-Leave branch must refuse without claiming.
const DENIALS := [
	{"event": "v3_sable_sheep_seam_scales", "choice": "weigh_warm_stuffing", "gold": 60, "scraps": 0, "hp": 20, "max_hp": 30},
	{"event": "v3_sable_sheep_seam_scales", "choice": "sell_heavy_heart", "gold": 60, "scraps": 6, "hp": 4, "max_hp": 30},
	{"event": "v3_oxblood_peacock_mourning_fan", "choice": "mend_fan_ribs", "gold": 0, "scraps": 6, "hp": 20, "max_hp": 30},
	{"event": "v3_oxblood_peacock_mourning_fan", "choice": "pluck_brittle_ribs", "gold": 60, "scraps": 6, "hp": 5, "max_hp": 30},
	{"event": "v3_copper_boar_needle_harp", "choice": "tune_heart_strings", "gold": 0, "scraps": 6, "hp": 20, "max_hp": 30},
	{"event": "v3_copper_boar_needle_harp", "choice": "tune_heart_strings", "gold": 60, "scraps": 0, "hp": 20, "max_hp": 30},
	{"event": "v3_copper_boar_needle_harp", "choice": "play_torn_chord", "gold": 60, "scraps": 6, "hp": 6, "max_hp": 30},
	{"event": "v3_plum_beetle_lantern_lift", "choice": "ride_quilt_lift", "gold": 60, "scraps": 0, "hp": 20, "max_hp": 30},
	{"event": "v3_plum_beetle_lantern_lift", "choice": "haul_cages", "gold": 60, "scraps": 6, "hp": 10, "max_hp": 10},
]

# A made-up choice ID that no authored record carries.
const UNKNOWN_CHOICE := "v3_no_such_roadside_seam"

var failures: Array[String] = []
var checks := 0
var catalog: Array = []
var catalog_text := ""


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _initialize() -> void:
	catalog = _load_events(VITAL_EVENTS_PATH)
	_check(not catalog.is_empty(), "vital story catalog is non-empty")
	_test_new_records()
	_test_anchors_persist()
	_test_funded_settlement()
	_test_denials_then_leave()
	_test_unknown_choice_refusal()
	_test_catalog_untouched()
	_test_rotation_admission()
	for failure in failures:
		printerr(failure)
	print("v3_gothic_roadside_ritual_vital_events_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _load_events(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "events file opens: " + path)
	if file == null:
		return []
	catalog_text = file.get_as_text()
	var parser := JSON.new()
	var parse_result := parser.parse(catalog_text)
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


func _is_integral_json_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var num: float = value
		return is_finite(num) and floor(num) == num and absf(num) <= RunEventChoice.MAX_SAFE_FLOAT_INT
	return false


func _test_new_records() -> void:
	for event_id in ROADSIDE_EVENTS:
		var expected: Dictionary = ROADSIDE_EVENTS[event_id]
		var matches := _matching(event_id)
		_check(matches.size() == 1, "new ID appears exactly once: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"new record has exact top-level keys: " + event_id)
		_check(record.get("id") == event_id, "new ID exact: " + event_id)
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
			if not choice is Dictionary or not (choice as Dictionary).get("id") is String:
				continue
			var cid: String = choice["id"]
			_check(not by_id.has(cid), "new choice IDs are distinct: " + event_id + "/" + cid)
			by_id[cid] = choice
			var outcome: Variant = (choice as Dictionary).get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).size() == 4
				and (outcome as Dictionary).has("gold") and (outcome as Dictionary).has("scraps")
				and (outcome as Dictionary).has("hp") and (outcome as Dictionary).has("max_hp"),
				"new outcome has exactly four keys: " + event_id + "/" + cid)
			if outcome is Dictionary:
				for key in ["gold", "scraps", "hp", "max_hp"]:
					_check(_is_integral_json_number((outcome as Dictionary).get(key)),
						"new outcome " + key + " is signed integer: " + event_id + "/" + cid)
		var wanted: Array = expected["choices"]
		_check(by_id.size() == wanted.size(), "new choice count matches expected: " + event_id)
		for row in wanted:
			var tag: String = event_id + "/" + row[0]
			_check(by_id.has(row[0]), "new choice present: " + tag)
			if not by_id.has(row[0]):
				continue
			var choice_dict: Dictionary = by_id[row[0]]
			_check(choice_dict.get("text") == row[1], "new choice text exact: " + tag)
			var outcome: Variant = choice_dict.get("outcome")
			if outcome is Dictionary:
				var keys := ["gold", "scraps", "hp", "max_hp"]
				for i in range(4):
					var raw: Variant = (outcome as Dictionary).get(keys[i])
					_check(_is_integral_json_number(raw) and int(raw) == int(row[2 + i]),
						"new outcome " + keys[i] + " exact: " + tag)
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


func _test_funded_settlement() -> void:
	# Fresh selector per choice; funded living Warden {60 gold, 6 scraps, 20/30 HP}.
	for event_id in ROADSIDE_EVENTS:
		var expected: Dictionary = ROADSIDE_EVENTS[event_id]
		var record := _record(event_id)
		_check(not record.is_empty(), "authored record available: " + event_id)
		if record.is_empty():
			continue
		var record_before: Dictionary = record.duplicate(true)
		for row in (expected["choices"] as Array):
			var choice_id: String = row[0]
			var tag: String = event_id + "/" + choice_id
			var snapshot: Dictionary = _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
			var snapshot_before: Dictionary = snapshot.duplicate(true)
			var run_rng := RandomNumberGenerator.new()
			run_rng.seed = 51017
			var run_rng_state: int = run_rng.state

			var preview_service := RunEventChoice.new(record.duplicate(true))
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
				and _vital_state_is(entry.get("state"), int(row[6]), int(row[7]), int(row[8]), int(row[9])),
				"funded preview projects the exact state: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and preview_service.is_valid() and not preview_service.is_claimed(),
				"preview claims nothing and mutates neither input nor source: " + tag)
			_check(run_rng.state == run_rng_state, "preview consumes no run RNG: " + tag)

			var commit_service := RunEventChoice.new(record.duplicate(true))
			var commit := commit_service.choose_with_vitals(choice_id, snapshot)
			_check(commit.size() == 4 and commit.get("ok") == true
				and commit.get("event_id") == event_id and commit.get("choice_id") == choice_id
				and _vital_state_is(commit.get("state"), int(row[6]), int(row[7]), int(row[8]), int(row[9])),
				"funded commit settles the exact state: " + tag)
			_check(commit.get("state") == entry.get("state"), "commit matches preview: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and commit_service.get_event() == record_before,
				"commit mutates neither input nor source: " + tag)
			_check(run_rng.state == run_rng_state, "commit consumes no run RNG: " + tag)
			_check(commit_service.is_claimed() and not commit_service.is_valid(),
				"commit latches exactly one claim: " + tag)

			var replay_snapshot: Dictionary = _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
			var replay_before: Dictionary = replay_snapshot.duplicate(true)
			var replay := commit_service.choose_with_vitals(choice_id, replay_snapshot)
			_check(replay.get("ok") == false and replay.get("event_id") == ""
				and replay.get("state") == replay_before,
				"replay on a spent visit is rejected unchanged: " + tag)
			var replay_preview := commit_service.preview_vital_choices(replay_snapshot)
			_check(replay_preview.get("ok") == false, "spent visit offers no new preview: " + tag)


func _test_denials_then_leave() -> void:
	for denial in DENIALS:
		var event_id: String = denial["event"]
		var choice_id: String = denial["choice"]
		var tag: String = "denied " + event_id + "/" + choice_id
		var record := _record(event_id)
		_check(not record.is_empty(), "denial case has its record: " + tag)
		if record.is_empty():
			continue
		var record_before: Dictionary = record.duplicate(true)
		var state: Dictionary = _vital_state(int(denial["gold"]), int(denial["scraps"]),
			int(denial["hp"]), int(denial["max_hp"]))
		var original: Dictionary = state.duplicate(true)
		var service := RunEventChoice.new(record)
		var preview := service.preview_vital_choices(state)
		var entry := _preview_choice(preview, choice_id)
		_check(preview.get("ok") == true and not entry.is_empty()
			and entry.get("affordable") == false and entry.get("state") == original,
			"insufficient branch is forecast unavailable: " + tag)
		var refusal := service.choose_with_vitals(choice_id, state)
		_check(refusal.size() == 4 and refusal.get("ok") == false
			and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
			and refusal.get("state") == original,
			"insufficient branch rejects with unchanged detached state: " + tag)
		_check(state == original and record == record_before
			and service.is_valid() and not service.is_claimed(),
			"insufficient refusal claims and mutates nothing: " + tag)
		var leave := service.choose_with_vitals("leave", state)
		_check(leave.get("ok") == true and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave" and leave.get("state") == original
			and service.is_claimed() and not service.is_valid(),
			"free Leave settles the same refused visit: " + tag)
		_check(service.choose_with_vitals(choice_id, state).get("ok") == false
			and state == original,
			"spent visit rejects the refused branch replay: " + tag)


func _test_unknown_choice_refusal() -> void:
	for event_id in ROADSIDE_EVENTS:
		var tag: String = "unknown " + event_id
		var record := _record(event_id)
		_check(not record.is_empty(), "unknown-choice case has its record: " + tag)
		if record.is_empty():
			continue
		var snapshot: Dictionary = _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
		var original: Dictionary = snapshot.duplicate(true)
		var service := RunEventChoice.new(record)
		var preview := service.preview_vital_choices(snapshot)
		_check(_preview_choice(preview, UNKNOWN_CHOICE).is_empty()
			and preview.get("ok") == true,
			"preview offers no unknown choice: " + tag)
		var refusal := service.choose_with_vitals(UNKNOWN_CHOICE, snapshot)
		_check(refusal.size() == 4 and refusal.get("ok") == false
			and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
			and refusal.get("state") == original,
			"unknown choice rejects with the unchanged snapshot: " + tag)
		_check(snapshot == original and service.is_valid() and not service.is_claimed(),
			"unknown choice claims and mutates nothing: " + tag)
		var leave := service.choose_with_vitals("leave", snapshot)
		_check(leave.get("ok") == true and leave.get("event_id") == event_id
			and leave.get("state") == original and service.is_claimed(),
			"free Leave settles the same unclaimed visit: " + tag)
		_check(service.choose_with_vitals(UNKNOWN_CHOICE, snapshot).get("ok") == false
			and snapshot == original,
			"spent visit rejects the unknown choice replay: " + tag)


func _test_catalog_untouched() -> void:
	var file := FileAccess.open(VITAL_EVENTS_PATH, FileAccess.READ)
	_check(file != null, "events file reopens for the immutability check")
	if file == null:
		return
	var reread := file.get_as_text()
	file.close()
	_check(reread == catalog_text, "event catalog JSON is unchanged by settlement")
	_check(catalog == _load_events(VITAL_EVENTS_PATH), "parsed event catalog is unchanged by settlement")


func _test_rotation_admission() -> void:
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "shipped vitality rotation validates with this batch appended")
	var listing: Array = rotation.get_vital_events()
	var listing_before: Array = listing.duplicate(true)
	var ids: Array = rotation.get_vital_event_ids()
	var ids_before: Array = ids.duplicate(true)
	var seed_value := 51037
	for anchor_id in ANCHOR_IDS:
		_check(ids.has(anchor_id), "rotation retains earlier named entry: " + anchor_id)
	for event_id in ROADSIDE_EVENTS:
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
		_check(rng.state == oracle.state,
			"forced selection consumes exactly one randi_range draw: " + tag)
		_check(result.get("event") == authored, "forced selection returns the authored record: " + tag)
		var selected := RunEventChoice.new(result.get("event"))
		_check(selected.is_valid() and not selected.is_claimed(),
			"selected event is an unclaimed valid visit: " + tag)

		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == result.get("event"),
			"same seed replays the same forced selection: " + tag)
		seed_value += 1

	# Fail-closed checks: invalid RNG or malformed/over-broad exclusions
	# must reject before any draw of the caller's generator.
	var guard_rng := RandomNumberGenerator.new()
	guard_rng.seed = 51091
	var guard_state: int = guard_rng.state
	var bad_rng := rotation.select_event("not-a-generator", [])
	_check(bad_rng.get("ok") == false and (bad_rng.get("event") as Dictionary).is_empty(),
		"invalid RNG rejects with an empty event")
	var bad_excluded := rotation.select_event(guard_rng, "not-an-array")
	_check(bad_excluded.get("ok") == false, "non-array exclusions reject")
	var bad_element := rotation.select_event(guard_rng, [12345])
	_check(bad_element.get("ok") == false, "non-String exclusion element rejects")
	var empty_pool := rotation.select_event(guard_rng, ids)
	_check(empty_pool.get("ok") == false, "excluding every ID rejects the empty pool")
	_check(guard_rng.state == guard_state,
		"fail-closed rejections consume no RNG draw")
	_check(rotation.get_vital_events() == listing_before, "rotation flows leave the shipped pool unchanged")
	_check(rotation.get_vital_event_ids() == ids_before, "rotation ID listing stays unchanged")
	_check(ids_before.size() == ids.size(), "rotation ID listing is a stable detached copy")

