extends SceneTree
## Deterministic headless test for the three underfloor keepsake vitality
## stories appended to data/events/v3_vital_story_events.json, and for their
## admission to the shipped RunV3VitalEventRotation pool.
##
## Every assertion is per-ID: no catalog total, positional index or frozen
## ordered ID list is asserted, because other lanes append to the same catalog
## in parallel. Expectations below are independent copies of the authored brief,
## never generated from the catalog under test.

const EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

## Funded living-hero snapshot used to prove preview/commit agreement.
const FUNDED_GOLD := 60
const FUNDED_SCRAPS := 6
const FUNDED_HP := 20
const FUNDED_MAX_HP := 30

## Independent authored expectations for the three new records. Choice rows are
## [id, text, gold, scraps, hp, max_hp]; "settled" rows are [choice_id, gold,
## scraps, hp, max_hp] fixed from the funded snapshot, never recomputed.
const NEW_EVENTS := {
	"v3_underbed_glass_eye": {
		"title": "The Underbed Glass Eye",
		"description": "A loose glass eye the size of a soup bowl stares out from under a towering bedstead, wrapped in a child's midnight-blue sock; its amber reflection tightens the dolls' visible stitches.",
		"choices": [
			["polish_eye_socket", "Spend 2 scraps polishing the staring eye (+2 max HP)", 0, -2, 0, 2],
			["pry_reflection", "Pry up its mirrored eyelid (lose 5 HP; gain 21 gold)", 21, 0, -5, 0],
			["leave", "Tuck the glass eye back beneath the bed", 0, 0, 0, 0],
		],
		"settled": {
			"polish_eye_socket": [60, 4, 20, 32],
			"pry_reflection": [81, 6, 15, 30],
			"leave": [60, 6, 20, 30],
		},
	},
	"v3_rainboot_thread_hatch": {
		"title": "The Rainboot Thread Hatch",
		"description": "A colossal moss-green rain boot hangs above a floorboard crack, its oxblood laces sewn into a tiny hatch and a warm button lantern glowing far inside the heel.",
		"choices": [
			["pack_dry_heel", "Pay 13 gold for dry heel stuffing (heal 9 HP)", -13, 0, 9, 0],
			["wrench_boot_nail", "Wrench out the crooked boot nail (lose 4 HP; gain 2 scraps)", 0, 2, -4, 0],
			["leave", "Let the great boot sway above the crack", 0, 0, 0, 0],
		],
		"settled": {
			"pack_dry_heel": [47, 6, 29, 30],
			"wrench_boot_nail": [60, 8, 16, 30],
			"leave": [60, 6, 20, 30],
		},
	},
	"v3_lullaby_brass_keyhole": {
		"title": "The Lullaby Brass Keyhole",
		"description": "A bedroom door rises like a cliff, its huge singing brass keyhole rocking a plush crescent moon while a single oxblood ribbon unspools through the lock.",
		"choices": [
			["hush_keyhole_song", "Pay 17 gold and 1 scrap to hush the lock (heal 5 HP; gain 1 max HP)", -17, -1, 5, 1],
			["trade_heart_thread", "Trade 2 max HP of heart thread for a gilded key (gain 26 gold)", 26, 0, 0, -2],
			["leave", "Leave the little cloth moon singing", 0, 0, 0, 0],
		],
		"settled": {
			"hush_keyhole_song": [43, 5, 25, 31],
			"trade_heart_thread": [86, 6, 20, 28],
			"leave": [60, 6, 20, 30],
		},
	},
}

## Named older anchors that must stay present exactly once and still validate.
const ANCHOR_IDS := [
	"v3_lantern_quilt_infirmary",
	"v3_needlebeak_kingfisher_post",
	"v3_moss_copper_darners_gate",
]

## Starved or unsafe visits on a FRESH service:
## [event_id, choice_id, gold, scraps, hp, max_hp, why].
const REFUSAL_CASES := [
	["v3_underbed_glass_eye", "polish_eye_socket", 60, 1, 20, 30, "one scrap short of 2"],
	["v3_underbed_glass_eye", "pry_reflection", 60, 6, 5, 30, "5 HP minus 5 would leave under 1 HP"],
	["v3_rainboot_thread_hatch", "pack_dry_heel", 12, 6, 20, 30, "one gold short of 13"],
	["v3_rainboot_thread_hatch", "wrench_boot_nail", 60, 6, 4, 30, "4 HP minus 4 would leave under 1 HP"],
	["v3_lullaby_brass_keyhole", "hush_keyhole_song", 16, 6, 20, 30, "one gold short of 17"],
	["v3_lullaby_brass_keyhole", "hush_keyhole_song", 60, 0, 20, 30, "no scrap for the 1-scrap lock"],
	["v3_lullaby_brass_keyhole", "trade_heart_thread", 60, 6, 10, 11, "cutting max HP below the floor of 10"],
]

## Stitched party actionable fixtures.
const PARTY_WALLET := {"gold": 60, "scraps": 6}
const PARTY_HEROES := [
	{"id": "warden", "hp": 20, "max_hp": 30},
	{"id": "seamstress", "hp": 20, "max_hp": 30},
	{"id": "tinker", "hp": 20, "max_hp": 30},
	{"id": "lantern_monk", "hp": 20, "max_hp": 30},
]

var failures: Array[String] = []
var checks := 0
var catalog: Array = []


func _initialize() -> void:
	catalog = _load_catalog()
	if catalog.is_empty():
		_report()
		return
	_test_new_event_data()
	_test_anchors_preserved()
	_test_ids_unique()
	_test_funded_previews_and_claims()
	_test_refusals_then_leave()
	_test_full_hp_heal_clamp()
	_test_rotation_admission()
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_underfloor_keepsake_vital_events_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_catalog() -> Array:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "the vitality catalog opens through FileAccess")
	if file == null:
		return []
	var parser := JSON.new()
	var parsed := parser.parse(file.get_as_text())
	file.close()
	_check(parsed == OK and parser.data is Dictionary \
		and (parser.data as Dictionary).get("events") is Array,
		"the vitality catalog parses to {events: [...]}")
	if parsed != OK or not parser.data is Dictionary \
		or not (parser.data as Dictionary).get("events") is Array:
		return []
	var events: Array = (parser.data as Dictionary)["events"]
	_check(not events.is_empty(), "the vitality catalog carries authored records")
	return events


func _matching(listing: Array, event_id: String) -> Array:
	return listing.filter(func(entry) -> bool:
		return entry is Dictionary and entry.get("id") == event_id)


func _record(event_id: String) -> Dictionary:
	var found := _matching(catalog, event_id)
	if found.size() != 1:
		return {}
	return (found[0] as Dictionary).duplicate(true)


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


func _is_integral_amount(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return is_finite(number) and floor(number) == number \
			and absf(number) <= RunEventChoice.MAX_SAFE_FLOAT_INT
	return false


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _test_new_event_data() -> void:
	for event_id in NEW_EVENTS:
		var expected: Dictionary = NEW_EVENTS[event_id]
		var found := _matching(catalog, event_id)
		_check(found.size() == 1, "exactly one authored new record: " + event_id)
		if found.size() != 1:
			continue
		var record: Dictionary = found[0]
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"new record carries exactly id/title/description/choices: " + event_id)
		_check(record.get("title") == expected["title"], "new title is exact: " + event_id)
		_check(record.get("description") == expected["description"],
			"new description is exact: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3,
			"new record carries exactly three choices: " + event_id)
		if not choices is Array:
			continue
		var by_id := {}
		for choice in choices:
			_check(choice is Dictionary and (choice as Dictionary).size() == 3
				and (choice as Dictionary).has("id") and (choice as Dictionary).has("text")
				and (choice as Dictionary).has("outcome"),
				"new choice carries exactly id/text/outcome: " + event_id)
			if not choice is Dictionary or not (choice as Dictionary).get("id") is String:
				continue
			var choice_id: String = choice["id"]
			_check(not by_id.has(choice_id),
				"new choice IDs are distinct: " + event_id + "/" + choice_id)
			by_id[choice_id] = choice
			var outcome: Variant = (choice as Dictionary).get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).size() == 4
				and (outcome as Dictionary).has("gold") and (outcome as Dictionary).has("scraps")
				and (outcome as Dictionary).has("hp") and (outcome as Dictionary).has("max_hp"),
				"new outcome carries exactly four keys: " + event_id + "/" + choice_id)
		var rows: Array = expected["choices"]
		for row in rows:
			var tag: String = event_id + "/" + str(row[0])
			_check(by_id.has(row[0]), "authored choice present: " + tag)
			if not by_id.has(row[0]):
				continue
			var choice_dict: Dictionary = by_id[row[0]]
			_check(choice_dict.get("text") == row[1], "choice text is exact: " + tag)
			var outcome: Variant = choice_dict.get("outcome")
			if not outcome is Dictionary:
				continue
			var keys := ["gold", "scraps", "hp", "max_hp"]
			for i in range(4):
				var raw: Variant = (outcome as Dictionary).get(keys[i])
				_check(_is_integral_amount(raw) and int(raw) == int(row[2 + i]),
					"choice outcome " + keys[i] + " is exact: " + tag)
		var service := RunEventChoice.new(record.duplicate(true))
		_check(service.is_valid() and not service.is_claimed(),
			"new record is presentable to RunEventChoice: " + event_id)


func _test_anchors_preserved() -> void:
	for anchor_id in ANCHOR_IDS:
		var found := _matching(catalog, anchor_id)
		_check(found.size() == 1, "anchor record still present exactly once: " + anchor_id)
		if found.size() != 1:
			continue
		var service := RunEventChoice.new((found[0] as Dictionary).duplicate(true))
		_check(service.is_valid(), "anchor record still validates: " + anchor_id)


func _test_ids_unique() -> void:
	var seen := {}
	for entry in catalog:
		if not entry is Dictionary or not (entry as Dictionary).get("id") is String:
			continue
		var event_id: String = entry["id"]
		_check(not seen.has(event_id), "no duplicate event ID in catalog: " + event_id)
		seen[event_id] = true
	for event_id in NEW_EVENTS:
		_check(seen.has(event_id), "new event ID is present in the catalog: " + event_id)
	for anchor_id in ANCHOR_IDS:
		_check(seen.has(anchor_id), "anchor event ID is present in the catalog: " + anchor_id)


func _test_funded_previews_and_claims() -> void:
	# Every authored choice is previewed and then claimed on a fresh one-visit
	# service from the funded snapshot; the receipt must match the fixed brief
	# state and its own forecast, and exactly one claim may be latched.
	for event_id in NEW_EVENTS:
		var settled: Dictionary = NEW_EVENTS[event_id]["settled"]
		for row in NEW_EVENTS[event_id]["choices"]:
			var choice_id: String = row[0]
			var tag: String = event_id + "/" + choice_id
			var expected_row: Array = settled[choice_id]
			var record := _record(event_id)
			_check(not record.is_empty(), "funded case has its authored record: " + tag)
			if record.is_empty():
				continue
			var record_before: Dictionary = record.duplicate(true)
			var snapshot := _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
			var snapshot_before: Dictionary = snapshot.duplicate(true)
			var service := RunEventChoice.new(record)
			_check(service.is_valid() and not service.is_claimed(),
				"fresh funded visit is open: " + tag)
			var preview := service.preview_vital_choices(snapshot)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and (preview.get("choices") as Array).size() == 3,
				"funded preview lists all three choices: " + tag)
			var entry := _preview_choice(preview, choice_id)
			_check(entry.get("affordable") == true
				and _vital_state_is(entry.get("state"), int(expected_row[0]),
					int(expected_row[1]), int(expected_row[2]), int(expected_row[3])),
				"funded preview projects the exact fixed state: " + tag)
			_check(snapshot == snapshot_before and record == record_before,
				"funded preview mutates nothing: " + tag)
			var receipt := service.choose_with_vitals(choice_id, snapshot)
			_check(receipt.get("ok") == true and receipt.get("event_id") == event_id
				and receipt.get("choice_id") == choice_id,
				"funded claim names the authored event and choice: " + tag)
			_check(_vital_state_is(receipt.get("state"), int(expected_row[0]),
				int(expected_row[1]), int(expected_row[2]), int(expected_row[3])),
				"funded claim settles the exact fixed state: " + tag)
			_check(receipt.get("state") == entry.get("state"),
				"funded claim matches its preview forecast: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and service.get_event() == record_before,
				"funded claim leaves caller snapshot and catalog detached: " + tag)
			_check(service.is_claimed() and not service.is_valid(),
				"funded claim latches exactly one visit: " + tag)
			var replay := service.choose_with_vitals(choice_id, snapshot)
			_check(replay.get("ok") == false and replay.get("state") == snapshot_before
				and snapshot == snapshot_before and service.is_claimed(),
				"funded spent visit rejects the replay unchanged: " + tag)


func _test_refusals_then_leave() -> void:
	# Each starved or unsafe case runs on a fresh service: the branch must
	# forecast unaffordable and refuse without latching; an unknown choice also
	# refuses, and the free Leave still settles that same visit.
	for case_row in REFUSAL_CASES:
		var event_id: String = case_row[0]
		var choice_id: String = case_row[1]
		var tag: String = event_id + "/" + choice_id + " (" + case_row[6] + ")"
		var state := _vital_state(int(case_row[2]), int(case_row[3]),
			int(case_row[4]), int(case_row[5]))
		var original: Dictionary = state.duplicate(true)
		var record := _record(event_id)
		_check(not record.is_empty(), "refusal case has its authored record: " + tag)
		if record.is_empty():
			continue
		var service := RunEventChoice.new(record)
		var preview := service.preview_vital_choices(state)
		var entry := _preview_choice(preview, choice_id)
		_check(preview.get("ok") == true and not entry.is_empty()
			and entry.get("affordable") == false and entry.get("state") == original,
			"starved branch forecasts unaffordable with an unchanged state: " + tag)
		var refusal := service.choose_with_vitals(choice_id, state)
		_check(refusal.get("ok") == false and refusal.get("event_id") == ""
			and refusal.get("choice_id") == "" and refusal.get("state") == original,
			"starved branch refuses with an unchanged detached state: " + tag)
		_check(state == original and service.is_valid() and not service.is_claimed(),
			"starved refusal consumes no visit and mutates nothing: " + tag)
		var unoffered := service.choose_with_vitals("not_an_authored_choice", state)
		_check(unoffered.get("ok") == false and unoffered.get("state") == original
			and state == original and not service.is_claimed(),
			"a non-offered choice ID refuses before any claim: " + tag)
		var leave := service.choose_with_vitals("leave", state)
		_check(leave.get("ok") == true and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave" and leave.get("state") == original
			and service.is_claimed() and not service.is_valid(),
			"free Leave still settles the visit after the refusals: " + tag)
		var leave_replay := service.choose_with_vitals("leave", state)
		_check(leave_replay.get("ok") == false and leave_replay.get("state") == original
			and state == original,
			"settled starved visit rejects a repeated Leave: " + tag)


func _test_full_hp_heal_clamp() -> void:
	# A funded full-HP heal caps at the resulting maximum: 30/30 plus 9 HP
	# stays 30, matching the preview forecast exactly.
	var record := _record("v3_rainboot_thread_hatch")
	_check(not record.is_empty(), "clamp case has its authored record")
	if record.is_empty():
		return
	var state := _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, 30, 30)
	var before: Dictionary = state.duplicate(true)
	var service := RunEventChoice.new(record)
	var preview := service.preview_vital_choices(state)
	var entry := _preview_choice(preview, "pack_dry_heel")
	_check(entry.get("affordable") == true
		and _vital_state_is(entry.get("state"), 47, 6, 30, 30),
		"full-HP heal preview clamps at the maximum")
	var receipt := service.choose_with_vitals("pack_dry_heel", state)
	_check(receipt.get("ok") == true
		and _vital_state_is(receipt.get("state"), 47, 6, 30, 30),
		"full-HP heal claim clamps at the maximum")
	_check(receipt.get("state") == entry.get("state") and state == before,
		"full-HP clamp matches its forecast and mutates nothing")


func _test_rotation_admission() -> void:
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped vitality rotation validates")
	var listing: Array = rotation.get_vital_events()
	var ids: Array = rotation.get_vital_event_ids()
	var listing_before: Array = listing.duplicate(true)
	_check(not ids.is_empty(), "the vitality rotation offers a non-empty pool")
	var seed_value := 94100
	for event_id in NEW_EVENTS:
		var tag: String = "rotation " + event_id
		var authored := _record(event_id)
		_check(ids.count(event_id) == 1, "new ID is eligible exactly once: " + tag)
		var offered := _matching(listing, event_id)
		_check(offered.size() == 1, "new ID is offered exactly once: " + tag)
		if offered.size() == 1:
			_check(offered[0] == authored, "offered new record matches the authored source: " + tag)
		# One-target rotation selection: exclude every other CURRENT ID
		# dynamically, never a fixed pool size or index.
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		var excluded_before: Array = excluded.duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var result := rotation.select_event(rng, excluded)
		_check(result.get("ok") == true
			and (result.get("event") as Dictionary).get("id") == event_id,
			"new ID is selected when every other ID is excluded: " + tag)
		_check(result.get("event") == authored,
			"forced selection returns the authored new record: " + tag)
		_check(rng.state == oracle.state,
			"forced selection consumes exactly one range draw: " + tag)
		var replay := RandomNumberGenerator.new()
		replay.seed = seed_value
		var again := rotation.select_event(replay, excluded)
		_check(again == result and replay.state == rng.state,
			"a same-seed replay repeats the forced selection: " + tag)
		_check(excluded == excluded_before,
			"selection never grows the caller exclusions: " + tag)
		seed_value += 1
	# All-excluded selection must refuse without consuming any RNG draw.
	var all_excluded: Array = ids.duplicate()
	var starved_rng := RandomNumberGenerator.new()
	starved_rng.seed = seed_value
	var idle_rng := RandomNumberGenerator.new()
	idle_rng.seed = seed_value
	var refused := rotation.select_event(starved_rng, all_excluded)
	_check(refused.get("ok") == false and refused.get("event") == {},
		"an all-excluded selection refuses with an empty event")
	_check(starved_rng.state == idle_rng.state,
		"an all-excluded selection consumes no RNG draw")
	# Four-hero Stitched party actionable selector with the funded wallet:
	# exclude every other CURRENT ID dynamically and the target is returned.
	var wallet: Dictionary = PARTY_WALLET.duplicate(true)
	var heroes: Array = PARTY_HEROES.duplicate(true)
	var party_seed := 61003
	for event_id in NEW_EVENTS:
		var tag: String = "party actionable " + event_id
		var party_excluded: Array = ids.duplicate()
		party_excluded.erase(event_id)
		var party_rng := RandomNumberGenerator.new()
		party_rng.seed = party_seed
		var picked := rotation.select_party_actionable_event(party_rng, party_excluded, wallet, heroes)
		_check(picked.get("ok") == true
			and (picked.get("event") as Dictionary).get("id") == event_id,
			"the four-hero actionable selector returns the last eligible target: " + tag)
		var party_replay := RandomNumberGenerator.new()
		party_replay.seed = party_seed
		var picked_again := rotation.select_party_actionable_event(party_replay, party_excluded, wallet, heroes)
		_check(picked_again == picked and party_replay.state == party_rng.state,
			"a same-seed party replay repeats the actionable selection: " + tag)
		_check(wallet == PARTY_WALLET and heroes == PARTY_HEROES,
			"party selection mutates neither wallet nor heroes: " + tag)
		party_seed += 1
	for anchor_id in ANCHOR_IDS:
		_check(ids.has(anchor_id), "an older named record is still offered: " + anchor_id)
	_check(rotation.get_vital_events() == listing_before,
		"every rotation flow leaves the shipped pool unchanged")
