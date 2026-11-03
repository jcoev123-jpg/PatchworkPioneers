extends SceneTree
## Deterministic headless regression for the four gothic prop-led vitality
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
	"v3_ironlace_heron_bell",
]

# Independent authored table. Choice rows: [id, text, gold, scraps, hp, max_hp].
const GOTHIC_EVENTS := {
	"v3_velvet_bat_lantern_loom": {
		"title": "The Velvet Bat Lantern Loom",
		"description": "A round oxblood bat doll pulls a lantern-sized needle through a towering black-lace loom; amber light catches the frayed wing hems.",
		"choices": [
			["stitch_wing_wick", "Pay 14 gold and 1 scrap to line the wing wick (heal 7 HP; gain 1 max HP)", -14, -1, 7, 1],
			["cut_lantern_thread", "Cut the scorching lantern thread (lose 4 HP; gain 19 gold)", 19, 0, -4, 0],
			["leave", "Leave the bat winding its lantern loom", 0, 0, 0, 0],
		],
	},
	"v3_brass_toad_hourglass": {
		"title": "The Brass Toad Hourglass",
		"description": "A squat moss-green toad puppet braces a cracked brass hourglass larger than its head; black sand drips through a blanket of silver stitches.",
		"choices": [
			["reset_heart_sand", "Spend 2 scraps to reset a lasting heart seam (+3 max HP)", 0, -2, 0, 3],
			["carry_hourglass", "Carry the heavy hourglass through briars (lose 5 HP; gain 2 scraps)", 0, 2, -5, 0],
			["leave", "Let the black sand fall in silence", 0, 0, 0, 0],
		],
	},
	"v3_oxblood_rabbit_doorbell": {
		"title": "The Oxblood Rabbit Doorbell",
		"description": "A plump crimson rabbit ragdoll shelters beneath a coffin-shaped porch with an enormous bone-cream doorbell strapped across its shoulders.",
		"choices": [
			["ring_warm_door", "Pay 11 gold to ring for warm stuffing (heal 8 HP)", -11, 0, 8, 0],
			["unpick_bell_strap", "Unpick the rabbit's brass bell-strap (lose 2 max HP; gain 25 gold)", 25, 0, 0, -2],
			["leave", "Leave the doorbell unrung", 0, 0, 0, 0],
		],
	},
	"v3_sable_cat_needle_telescope": {
		"title": "The Sable Cat Needle Telescope",
		"description": "A round black-velvet cat doll peers through a silver needle telescope bolted to a giant thread spool; the moon shines on its mismatched button eyes.",
		"choices": [
			["focus_moon_seam", "Pay 19 gold and 1 scrap to focus a moon seam (heal 4 HP; gain 2 max HP)", -19, -1, 4, 2],
			["haul_glass_lenses", "Haul the heavy telescope lenses (lose 6 HP; gain 3 scraps)", 0, 3, -6, 0],
			["leave", "Let the cat watch the misty moon", 0, 0, 0, 0],
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
	_test_malformed_and_replay()
	_test_rotation_admission()
	for failure in failures:
		printerr(failure)
	print("v3_gothic_prop_vital_stories_test: ",
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
	var seen_event_ids := {}
	for event_id in GOTHIC_EVENTS:
		var expected: Dictionary = GOTHIC_EVENTS[event_id]
		var matches := _matching(event_id)
		_check(matches.size() == 1, "new gothic ID appears exactly once: " + event_id)
		if matches.size() != 1:
			continue
		seen_event_ids[event_id] = true
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
					"new outcome has exactly four keys: " + event_id + "/" + str((choice as Dictionary).get("id")))
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
	_check(seen_event_ids.size() == 4, "four new gothic IDs are distinct")


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
	for event_id in GOTHIC_EVENTS:
		var expected: Dictionary = GOTHIC_EVENTS[event_id]
		for row in (expected["choices"] as Array):
			var choice_id: String = row[0]
			var tag: String = event_id + "/" + choice_id
			var target: Array = _expected_state(row)
			var record := _record(event_id)
			_check(not record.is_empty(), "authored record available: " + tag)
			if record.is_empty():
				continue
			var record_before: Dictionary = record.duplicate(true)

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

			var replay_snapshot: Dictionary = _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
			var replay := commit_service.choose_with_vitals(choice_id, replay_snapshot)
			_check(replay.get("ok") == false and replay.get("event_id") == ""
				and replay.get("state") == replay_snapshot,
				"replay on a spent visit is rejected unchanged: " + tag)


func _test_refusals_then_leave() -> void:
	# Zero wallet, 1 HP, 10 max HP: both non-Leave branches of every record must
	# refuse without claiming or mutating, and Leave must still settle.
	for event_id in GOTHIC_EVENTS:
		var expected: Dictionary = GOTHIC_EVENTS[event_id]
		for row in (expected["choices"] as Array):
			var choice_id: String = row[0]
			if choice_id == "leave":
				continue
			var tag: String = "starved " + event_id + "/" + choice_id
			var record := _record(event_id)
			_check(not record.is_empty(), "starved case has its record: " + tag)
			if record.is_empty():
				continue
			var record_before: Dictionary = record.duplicate(true)
			var state: Dictionary = _vital_state(0, 0, 1, 10)
			var original: Dictionary = state.duplicate(true)
			var service := RunEventChoice.new(record)
			var preview := service.preview_vital_choices(state)
			var entry := _preview_choice(preview, choice_id)
			_check(preview.get("ok") == true and not entry.is_empty()
				and entry.get("affordable") == false and entry.get("state") == original,
				"starved branch is forecast unavailable: " + tag)
			var refusal := service.choose_with_vitals(choice_id, state)
			_check(refusal.size() == 4 and refusal.get("ok") == false
				and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
				and refusal.get("state") == original,
				"starved branch rejects with unchanged detached state: " + tag)
			_check(state == original and record == record_before
				and service.is_valid() and not service.is_claimed(),
				"starved refusal claims and mutates nothing: " + tag)
			var leave := service.choose_with_vitals("leave", state)
			_check(leave.get("ok") == true and leave.get("event_id") == event_id
				and leave.get("choice_id") == "leave" and leave.get("state") == original
				and service.is_claimed() and not service.is_valid(),
				"free Leave settles the same starved visit: " + tag)
			_check(service.choose_with_vitals(choice_id, state).get("ok") == false
				and state == original,
				"spent starved visit rejects the branch replay: " + tag)


func _test_malformed_and_replay() -> void:
	# Unknown / malformed choices never claim the one visit.
	for event_id in GOTHIC_EVENTS:
		var record := _record(event_id)
		if record.is_empty():
			_check(false, "malformed case has its record: " + event_id)
			continue
		var state: Dictionary = _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
		var original: Dictionary = state.duplicate(true)
		for bad_choice in ["", "   ", "not_a_choice", 7, null]:
			var service := RunEventChoice.new(record.duplicate(true))
			var refusal := service.choose_with_vitals(bad_choice, state)
			_check(refusal.size() == 4 and refusal.get("ok") == false
				and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
				and refusal.get("state") == original,
				"malformed choice rejects unchanged: " + event_id + "/" + str(bad_choice))
			_check(state == original and service.is_valid() and not service.is_claimed(),
				"malformed choice claims nothing: " + event_id + "/" + str(bad_choice))
		var bad_snapshot := {"gold": 60, "scraps": 6, "hero": {"id": "warden", "hp": 0, "max_hp": 10}}
		var torn_service := RunEventChoice.new(record.duplicate(true))
		var torn := torn_service.choose_with_vitals("leave", bad_snapshot)
		_check(torn.get("ok") == false and torn_service.is_valid() and not torn_service.is_claimed(),
			"torn hero snapshot rejects without a claim: " + event_id)


func _test_rotation_admission() -> void:
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "shipped vitality rotation validates with this batch appended")
	var listing: Array = rotation.get_vital_events()
	var listing_before: Array = listing.duplicate(true)
	var ids: Array = rotation.get_vital_event_ids()
	var ids_before: Array = ids.duplicate(true)
	var seed_value := 76400
	for event_id in GOTHIC_EVENTS:
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

		# A fresh generator with the same seed and the same exclusions replays it.
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == result.get("event")
			and replay_rng.state == rng.state,
			"same seed replays the same forced selection: " + tag)
		seed_value += 1
	_check(rotation.get_vital_events() == listing_before, "rotation flows leave the shipped pool unchanged")
	_check(rotation.get_vital_event_ids() == ids_before, "rotation ID listing stays unchanged")
	_check(ids_before.size() == ids.size(), "rotation ID listing is a stable detached copy")
