extends SceneTree
## Deterministic headless test for this batch of six appended V3-4 vitality
## roadside story events in data/events/v3_vital_story_events.json.
##
## The real document is loaded through FileAccess/JSON and every record is
## located by ID against an independent expectation table. Nothing here asserts
## a catalog total, a full ordered ID list or an absolute append position, so
## other lanes may append their own stories to the same shared pack. Selection
## is exercised through the shipping RunV3VitalEventRotation with an injected
## seeded RandomNumberGenerator, and outcomes settle through the RunEventChoice
## vitality preview/commit transaction.

const VITAL_EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

# Independent authored expectations for this batch. Choice rows are
# [id, text, gold, scraps, hp, max_hp] and are never generated from the catalog.
const NEW_RECORDS := {
	"v3_crowfeather_sickbay": {
		"title": "The Crowfeather Sickbay",
		"description": "A plush midnight crow tends tiny quilts beneath a warm brass lantern while patched travellers shelter from rain.",
		"choices": [
			["pay_crow_nurse", "Pay 13 gold for crow-feather bandages (+8 HP)", -13, 0, 8, 0],
			["trade_warm_stuffing", "Give 3 HP worth of stuffing for 2 scraps", 0, 2, -3, 0],
			["leave", "Leave the quilts folded", 0, 0, 0, 0],
		],
	},
	"v3_copper_spine_shrine": {
		"title": "The Copper-Spine Shrine",
		"description": "A round ragdoll sentinel holds a copper-thread backbone across an oxblood altar of soft sewn cushions.",
		"choices": [
			["brace_spine", "Spend 3 scraps for a lasting copper brace (+3 max HP)", 0, -3, 0, 3],
			["unpick_ribs", "Trade 2 max HP for 20 gold", 20, 0, 0, -2],
			["leave", "Leave the copper brace untouched", 0, 0, 0, 0],
		],
	},
	"v3_bellmoth_hospice": {
		"title": "The Bell-Moth Hospice",
		"description": "A broad button-eyed moth nurse rings a bone-cream bell above a bedside lit by amber lantern oil.",
		"choices": [
			["borrow_glow", "Pay 15 gold for glow treatment (+7 HP, +1 max HP)", -15, 0, 7, 1],
			["barter_wick", "Give 4 HP for 19 gold worth of lantern wicks", 19, 0, -4, 0],
			["leave", "Let the hospice bell fall silent", 0, 0, 0, 0],
		],
	},
	"v3_strawbell_keeper": {
		"title": "The Straw-Bell Keeper",
		"description": "A squat pumpkin-faced keeper gathers fallen straw beneath a moss-coloured bell stitched into the road's canopy.",
		"choices": [
			["stuff_hem", "Spend 2 scraps to restuff a wound (+5 HP)", 0, -2, 5, 0],
			["sell_straw_core", "Trade 1 max HP of stuffing for 12 gold", 12, 0, 0, -1],
			["leave", "Pass beneath the hanging straw bell", 0, 0, 0, 0],
		],
	},
	"v3_teal_dye_washhouse": {
		"title": "The Teal-Dye Washhouse",
		"description": "Round apron-wearing dolls wring indigo quilts above a midnight-teal basin warmed by little copper lamps.",
		"choices": [
			["purchase_cloth", "Pay 11 gold for a healing cloth wrap (+7 HP)", -11, 0, 7, 0],
			["rinse_threads", "Give 3 HP of effort to salvage 1 scrap", 0, 1, -3, 0],
			["leave", "Leave the indigo quilts to dry", 0, 0, 0, 0],
		],
	},
	"v3_oxblood_button_rite": {
		"title": "The Oxblood Button Rite",
		"description": "A patched button priestess sews a shining brass heart into a velvet cushion as the candle wax drips.",
		"choices": [
			["sew_rite", "Spend 1 scrap and 4 HP to gain 2 max HP", 0, -1, -4, 2],
			["cash_oath", "Surrender 2 max HP to take 23 gold", 23, 0, 0, -2],
			["leave", "Keep your own button-heart", 0, 0, 0, 0],
		],
	},
}

# Three named older anchors that must still exist unchanged.
const ANCHOR_IDS := ["v3_lantern_quilt_infirmary", "v3_wakeful_darning_house", "v3_velvet_moon_ward"]

# Independent expectations for the three anchor records (choice rows are
# [id, text, gold, scraps, hp, max_hp]).
const ANCHOR_RECORDS := {
	"v3_lantern_quilt_infirmary": {
		"title": "The Lantern-Quilt Infirmary",
		"description": "A round, button-eyed nurse hangs warm quilts beside a midnight-teal lantern.",
		"choices": [
			["buy_bandages", "Pay 12 gold to dress one hero's wounds (+8 HP)", -12, 0, 8, 0],
			["blood_receipt", "Donate 4 HP for a purse of 18 gold", 18, 0, -4, 0],
			["leave", "Leave the lantern burning", 0, 0, 0, 0],
		],
	},
	"v3_wakeful_darning_house": {
		"title": "The Wakeful Darning House",
		"description": "A round button-eyed tailor keeps a bone-cream darning room lit until dawn, with warm quilts stacked at the door.",
		"choices": [
			["buy_warm_seam", "Pay 14 gold for a warm seam (+9 HP)", -14, 0, 9, 0],
			["unpick_old_hem", "Trade 2 max HP for 20 gold", 20, 0, 0, -2],
			["leave", "Leave the darning room asleep", 0, 0, 0, 0],
		],
	},
	"v3_velvet_moon_ward": {
		"title": "The Velvet Moon Ward",
		"description": "A rounded lantern-bearing ragdoll nurses a crescent quilt under a plum-coloured button moon.",
		"choices": [
			["share_oil", "Spend 1 scrap and lose 3 HP for 2 max HP", 0, -1, -3, 2],
			["hire_nurse", "Pay 18 gold to recover 9 HP", -18, 0, 9, 0],
			["leave", "Leave the moon ward in peace", 0, 0, 0, 0],
		],
	},
}

# One genuinely insufficient-resource, too-low-HP or too-low-max-HP branch per
# record. Each refusal must leave this same visit open so the free Leave settles.
const REFUSAL_CASES := {
	"v3_crowfeather_sickbay": {
		"choice": "pay_crow_nurse", "gold": 12, "scraps": 4, "hp": 25, "max_hp": 40,
		"label": "insufficient gold",
	},
	"v3_copper_spine_shrine": {
		"choice": "unpick_ribs", "gold": 40, "scraps": 4, "hp": 11, "max_hp": 11,
		"label": "max-HP floor",
	},
	"v3_bellmoth_hospice": {
		"choice": "barter_wick", "gold": 40, "scraps": 4, "hp": 4, "max_hp": 40,
		"label": "too-low HP",
	},
	"v3_strawbell_keeper": {
		"choice": "sell_straw_core", "gold": 40, "scraps": 4, "hp": 10, "max_hp": 10,
		"label": "max-HP floor",
	},
	"v3_teal_dye_washhouse": {
		"choice": "purchase_cloth", "gold": 10, "scraps": 4, "hp": 25, "max_hp": 40,
		"label": "insufficient gold",
	},
	"v3_oxblood_button_rite": {
		"choice": "sew_rite", "gold": 40, "scraps": 4, "hp": 3, "max_hp": 40,
		"label": "too-low HP",
	},
}

const FUNDED_GOLD := 40
const FUNDED_SCRAPS := 4
const FUNDED_HP := 25
const FUNDED_MAX_HP := 40

const DENIED_PREVIEW := {"ok": false, "event_id": "", "choices": []}

var failures: Array[String] = []
var checks := 0
var catalog: Array = []
var catalog_snapshot: Array = []


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _is_integral_amount(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return is_finite(number) and floor(number) == number \
			and absf(number) <= RunEventChoice.MAX_SAFE_FLOAT_INT
	return false


## Seeds the global RNG and returns the next draw on an identical fresh seed, so
## a later randi() call can prove that no global draw happened in between.
func _global_rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


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


func _matches(listing: Array, event_id: String) -> Array:
	var found: Array = []
	for entry in listing:
		if entry is Dictionary and entry.get("id") == event_id:
			found.append(entry)
	return found


## A detached deep copy of the loaded catalog record for the given ID, or {}.
func _record(event_id: String) -> Dictionary:
	for entry in catalog:
		if entry is Dictionary and entry.get("id") == event_id:
			return (entry as Dictionary).duplicate(true)
	return {}


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _load_catalog() -> void:
	var file := FileAccess.open(VITAL_EVENTS_PATH, FileAccess.READ)
	_check(file != null, "vitality story catalog opens through FileAccess")
	if file == null:
		return
	var parser := JSON.new()
	var parsed := parser.parse(file.get_as_text())
	file.close()
	_check(parsed == OK and parser.data is Dictionary
		and (parser.data as Dictionary).get("events") is Array,
		"vitality story catalog parses to {events: [...]}")
	if parsed != OK or not parser.data is Dictionary:
		return
	var events: Variant = (parser.data as Dictionary).get("events")
	if not events is Array:
		return
	catalog = (events as Array).duplicate(true)
	catalog_snapshot = (events as Array).duplicate(true)


func _initialize() -> void:
	_load_catalog()
	if catalog.is_empty():
		_report()
		return
	_test_record_shapes()
	_test_anchor_records_unchanged()
	_test_rotation_admission()
	_test_funded_choices()
	_test_refusals_then_leave()
	_check(catalog == catalog_snapshot,
		"the loaded vitality catalog is unchanged by every flow")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_vital_second_story_batch_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _test_record_shapes() -> void:
	_check(NEW_RECORDS.size() == 6, "this batch authors six new story event IDs")
	for event_id in NEW_RECORDS:
		var matches := _matches(catalog, event_id)
		_check(matches.size() == 1, "exactly one authored record for: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var expected: Dictionary = NEW_RECORDS[event_id]
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"record has exact top-level keys: " + event_id)
		_check(record.get("title") == expected["title"], "title exact: " + event_id)
		_check(record.get("description") == expected["description"], "description exact: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3,
			"record has exactly three choices: " + event_id)
		if not choices is Array:
			continue
		var seen := {}
		var by_id := {}
		for choice in choices:
			_check(choice is Dictionary and (choice as Dictionary).size() == 3
				and (choice as Dictionary).has("id") and (choice as Dictionary).has("text")
				and (choice as Dictionary).has("outcome"),
				"choice has only id/text/outcome keys: " + event_id)
			if not choice is Dictionary:
				continue
			var choice_id: Variant = (choice as Dictionary).get("id")
			if not choice_id is String:
				continue
			_check(not seen.has(choice_id), "choice IDs are distinct: " + event_id + "/" + choice_id)
			seen[choice_id] = true
			by_id[choice_id] = choice
			var outcome: Variant = (choice as Dictionary).get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).size() == 4
				and (outcome as Dictionary).has("gold") and (outcome as Dictionary).has("scraps")
				and (outcome as Dictionary).has("hp") and (outcome as Dictionary).has("max_hp"),
				"outcome has exactly four keys: " + event_id + "/" + choice_id)
		var wanted: Array = expected["choices"]
		_check(seen.size() == wanted.size(), "authored choice count matches: " + event_id)
		for row in wanted:
			var tag: String = event_id + "/" + row[0]
			_check(by_id.has(row[0]), "authored choice present: " + tag)
			if not by_id.has(row[0]):
				continue
			var choice_dict: Dictionary = by_id[row[0]]
			_check(choice_dict.get("text") == row[1], "choice text exact: " + tag)
			if not choice_dict.get("outcome") is Dictionary:
				continue
			var outcome_dict: Dictionary = choice_dict["outcome"]
			var keys := ["gold", "scraps", "hp", "max_hp"]
			for i in range(4):
				var raw: Variant = outcome_dict.get(keys[i])
				_check(_is_integral_amount(raw) and int(raw) == int(row[2 + i]),
					"outcome " + keys[i] + " exact: " + tag)
		_check(by_id.has("leave"), "record offers a Leave choice: " + event_id)
		if by_id.has("leave"):
			var leave_outcome: Variant = (by_id["leave"] as Dictionary).get("outcome")
			_check(leave_outcome is Dictionary
				and int((leave_outcome as Dictionary).get("gold")) == 0
				and int((leave_outcome as Dictionary).get("scraps")) == 0
				and int((leave_outcome as Dictionary).get("hp")) == 0
				and int((leave_outcome as Dictionary).get("max_hp")) == 0,
				"Leave choice is a free no-op: " + event_id)
		var service := RunEventChoice.new(record.duplicate(true))
		_check(service.is_valid() and not service.is_claimed(),
			"record builds a valid vitality selector: " + event_id)
	# IDs are unique across the whole loaded pack (per-ID, never a total).
	var seen_ids := {}
	for entry in catalog:
		_check(entry is Dictionary and entry.get("id") is String, "catalog entry carries a string ID")
		if not entry is Dictionary or not entry.get("id") is String:
			continue
		var existing_id: String = entry["id"]
		_check(not seen_ids.has(existing_id), "no duplicate catalog event ID: " + existing_id)
		seen_ids[existing_id] = true


func _test_anchor_records_unchanged() -> void:
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "shipped vitality rotation validates with this batch appended")
	var listing: Array = rotation.get_vital_events()
	for anchor_id in ANCHOR_IDS:
		var matches := _matches(catalog, anchor_id)
		_check(matches.size() == 1, "anchor record still present once: " + anchor_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var expected: Dictionary = ANCHOR_RECORDS[anchor_id]
		_check(record.get("title") == expected["title"], "anchor title unchanged: " + anchor_id)
		_check(record.get("description") == expected["description"],
			"anchor description unchanged: " + anchor_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3,
			"anchor keeps three choices: " + anchor_id)
		if not choices is Array:
			continue
		var by_id := {}
		for choice in choices:
			if choice is Dictionary and choice.get("id") is String:
				by_id[choice["id"]] = choice
		var wanted: Array = expected["choices"]
		_check(by_id.size() == wanted.size(), "anchor choice count unchanged: " + anchor_id)
		for row in wanted:
			var tag: String = anchor_id + "/" + row[0]
			_check(by_id.has(row[0]), "anchor choice present: " + tag)
			if not by_id.has(row[0]):
				continue
			var choice_dict: Dictionary = by_id[row[0]]
			_check(choice_dict.get("text") == row[1], "anchor choice text unchanged: " + tag)
			if not choice_dict.get("outcome") is Dictionary:
				continue
			var outcome_dict: Dictionary = choice_dict["outcome"]
			var keys := ["gold", "scraps", "hp", "max_hp"]
			for i in range(4):
				var raw: Variant = outcome_dict.get(keys[i])
				_check(_is_integral_amount(raw) and int(raw) == int(row[2 + i]),
					"anchor outcome " + keys[i] + " unchanged: " + tag)
		var offered := _matches(listing, anchor_id)
		_check(offered.size() == 1 and offered[0] == record,
			"anchor is offered once from the rotation and matches the source: " + anchor_id)


func _test_rotation_admission() -> void:
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "default rotation admits this batch")
	var listing: Array = rotation.get_vital_events()
	var listing_before: Array = listing.duplicate(true)
	var ids: Array = rotation.get_vital_event_ids()
	var sorted_ids: Array = ids.duplicate()
	sorted_ids.sort()
	_check(ids == sorted_ids, "rotation eligibility is sorted by event ID")
	var seed_value := 88000
	for event_id in NEW_RECORDS:
		var tag: String = "rotation " + event_id
		var authored := _record(event_id)
		_check(not authored.is_empty(), "authored record available: " + tag)
		_check(ids.count(event_id) == 1, "new ID is eligible exactly once: " + tag)
		var offered := _matches(listing, event_id)
		_check(offered.size() == 1, "new ID is offered exactly once: " + tag)
		if offered.size() == 1:
			_check(offered[0] == authored, "offered record matches the authored source: " + tag)
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
			"new ID is selected when every other eligible ID is excluded: " + tag)
		_check(result.get("event") == authored, "forced selection returns the authored record: " + tag)
		_check(rng.state == oracle.state, "forced selection consumes exactly one range draw: " + tag)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("event") == result.get("event"),
			"the same seed and exclusions replay the same record: " + tag)
		_check(replay_rng.state == rng.state, "replay ends in identical RNG state: " + tag)
		_check(rotation.get_vital_events() == listing_before,
			"forced selection never mutates the rotation pool: " + tag)
		seed_value += 1
	# Exhausted eligibility rejects without consuming a draw.
	var guard := RandomNumberGenerator.new()
	guard.seed = 88999
	var guard_state := guard.state
	var exhausted := rotation.select_event(guard, ids)
	_check(exhausted.get("ok") == false, "excluding every eligible ID rejects")
	_check((exhausted.get("event") as Dictionary).is_empty(),
		"exhausted eligibility returns no event")
	_check(guard.state == guard_state, "exhausted eligibility consumes no RNG")
	_check(rotation.get_vital_events() == listing_before,
		"rejected and forced selections leave the pool unchanged")
	_check(catalog == catalog_snapshot, "rotation admission leaves the authored catalog unchanged")


func _test_funded_choices() -> void:
	# Every authored branch (including Leave) previews and settles its exact signed
	# effects from one funded living hero. Max HP is applied first, so a heal that
	# overshoots is capped and a max-HP cut pulls current HP down with it.
	for event_id in NEW_RECORDS:
		var record := _record(event_id)
		_check(not record.is_empty(), "batch record available for settlement: " + event_id)
		if record.is_empty():
			continue
		var record_before: Dictionary = record.duplicate(true)
		var global_state := _global_rng_start(88100 + NEW_RECORDS.keys().find(event_id))
		var rows: Array = NEW_RECORDS[event_id]["choices"]
		for row in rows:
			var choice_id: String = row[0]
			var tag: String = event_id + "/" + choice_id
			var gold_delta: int = int(row[2])
			var scraps_delta: int = int(row[3])
			var hp_delta: int = int(row[4])
			var max_delta: int = int(row[5])
			var exp_gold: int = FUNDED_GOLD + gold_delta
			var exp_scraps: int = FUNDED_SCRAPS + scraps_delta
			var exp_max: int = FUNDED_MAX_HP + max_delta
			var exp_hp: int = min(FUNDED_HP + hp_delta, exp_max)

			var snapshot := _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
			var snapshot_before: Dictionary = snapshot.duplicate(true)
			var preview_service := RunEventChoice.new(record.duplicate(true))
			var preview := preview_service.preview_vital_choices(snapshot)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and (preview.get("choices") as Array).size() == 3,
				"funded preview lists three choices: " + tag)
			var entry := _preview_choice(preview, choice_id)
			_check(entry.size() == 7, "preview entry has seven keys: " + tag)
			_check(entry.get("choice_id") == choice_id
				and entry.get("gold_delta") == gold_delta
				and entry.get("scraps_delta") == scraps_delta
				and entry.get("hp_delta") == hp_delta
				and entry.get("max_hp_delta") == max_delta,
				"preview reports the exact signed deltas: " + tag)
			_check(entry.get("affordable") == true
				and _vital_state_is(entry.get("state"), exp_gold, exp_scraps, exp_hp, exp_max),
				"funded preview projects the exact state: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and preview_service.is_valid() and not preview_service.is_claimed()
				and preview_service.get_event() == record_before,
				"preview mutates neither snapshot nor record and keeps the visit open: " + tag)

			var commit_service := RunEventChoice.new(record.duplicate(true))
			var commit := commit_service.choose_with_vitals(choice_id, snapshot)
			_check(commit.size() == 4 and commit.get("ok") == true
				and commit.get("event_id") == event_id and commit.get("choice_id") == choice_id
				and _vital_state_is(commit.get("state"), exp_gold, exp_scraps, exp_hp, exp_max),
				"funded commit settles the exact state: " + tag)
			_check(commit.get("state") == entry.get("state"),
				"funded commit matches its preview forecast: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and commit_service.get_event() == record_before,
				"funded commit mutates neither snapshot nor record: " + tag)
			_check(commit_service.is_claimed() and not commit_service.is_valid(),
				"funded commit latches exactly one claim: " + tag)

			var replay_input := _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
			var replay := commit_service.choose_with_vitals(choice_id, replay_input)
			_check(replay.size() == 4 and replay.get("ok") == false
				and replay.get("event_id") == "" and replay.get("choice_id") == ""
				and replay.get("state") == replay_input,
				"a spent visit rejects the replay with an unchanged detached state: " + tag)
			_check(commit_service.is_claimed() and not commit_service.is_valid()
				and commit_service.get_event() == record_before,
				"a rejected replay does not consume a second claim: " + tag)
			_check(record == record_before and _record(event_id) == record_before,
				"no settlement path mutates the authored record: " + tag)
		_check(randi() == global_state,
			"preview and settlement spend no global RNG: " + event_id)


func _test_refusals_then_leave() -> void:
	# Each record has one genuinely unaffordable or dangerous branch: it must be
	# forecast unavailable, refuse without consuming the visit, leave the caller
	# snapshot/source/RNG untouched, and then the free Leave must settle exactly
	# once on that SAME visit with every later replay rejected.
	for event_id in REFUSAL_CASES:
		var case_data: Dictionary = REFUSAL_CASES[event_id]
		var choice_id: String = case_data["choice"]
		var label: String = case_data["label"]
		var tag: String = label + " " + event_id + "/" + choice_id
		var state := _vital_state(int(case_data["gold"]), int(case_data["scraps"]),
			int(case_data["hp"]), int(case_data["max_hp"]))
		var original: Dictionary = state.duplicate(true)
		var record := _record(event_id)
		_check(not record.is_empty(), "refusal case has its authored record: " + tag)
		if record.is_empty():
			continue
		var record_before: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(record)
		var global_state := _global_rng_start(88200)
		var preview := service.preview_vital_choices(state)
		var entry := _preview_choice(preview, choice_id)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id
			and not entry.is_empty() and entry.get("affordable") == false
			and entry.get("state") == original,
			"refused branch is forecast unavailable with unchanged state: " + tag)
		var refusal := service.choose_with_vitals(choice_id, state)
		_check(refusal.size() == 4 and refusal.get("ok") == false
			and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
			and refusal.get("state") == original,
			"refused branch rejects with an unchanged detached state: " + tag)
		_check(state == original and record == record_before
			and service.get_event() == record_before
			and service.is_valid() and not service.is_claimed(),
			"refusal consumes no visit and mutates nothing: " + tag)
		(refusal["state"] as Dictionary)["gold"] = 999
		_check(state == original, "refusal state is detached from the caller: " + tag)

		var leave := service.choose_with_vitals("leave", state)
		_check(leave.get("ok") == true and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave" and leave.get("state") == original
			and service.is_claimed() and not service.is_valid(),
			"free Leave settles the same visit after the refusal: " + tag)
		_check(service.preview_vital_choices(state) == DENIED_PREVIEW,
			"a consumed visit refuses a second preview: " + tag)
		var leave_replay := service.choose_with_vitals("leave", state)
		var branch_replay := service.choose_with_vitals(choice_id, state)
		_check(leave_replay.get("ok") == false and branch_replay.get("ok") == false
			and leave_replay.get("state") == original and branch_replay.get("state") == original
			and state == original,
			"the settled visit rejects Leave and branch replay: " + tag)
		_check(service.is_claimed() and record == record_before
			and service.get_event() == record_before,
			"replays leave the claim latched and the record untouched: " + tag)
		_check(randi() == global_state, "refusal, Leave and replay spend no global RNG: " + tag)

	_check(catalog == catalog_snapshot,
		"refusal and Leave flows leave the authored catalog unchanged")
