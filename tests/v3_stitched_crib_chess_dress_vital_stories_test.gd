extends SceneTree
## Deterministic headless test for the three authored doll-scale vitality
## roadside stories appended to data/events/v3_vital_story_events.json (the
## swinging crib mobile, the midnight chess clock and the satin dress form)
## and for their admission to the shipped RunV3VitalEventRotation and
## RunEventChoice services.
##
## Expectations below are independent literal copies of the authored brief; the
## catalog under test is never used to generate its own oracle. Every check is
## per-ID: no catalog total, positional index or full ordered ID list is
## asserted, because other lanes append to the same catalog in parallel.

const EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

const BASE_GOLD := 40
const BASE_SCRAPS := 4
const BASE_HP := 12
const BASE_MAX_HP := 25

## Independent authored expectations for the three new records.
## Choice rows are [id, text, gold, scraps, hp, max_hp].
const NEW_EVENTS := {
	"v3_swinging_crib_mobile": {
		"title": "The Swinging Crib Mobile",
		"description": "A nursery mobile as wide as a roof turns above the doll-sized passage; four plump cloth horses sway from brass needle hooks while a button-eyed keeper knots the dangling strings.",
		"choices": [
			["tie_horse_strings", "Spend 2 scraps to bind the loose horse strings (heal 8 HP, gain 1 max HP)", 0, -2, 8, 1],
			["collect_horse_bells", "Unhook a jangling horse bell (lose 4 HP, gain 17 gold and 1 scrap)", 17, 1, -4, 0],
			["leave", "Leave the little horses circling in silence", 0, 0, 0, 0],
		],
	},
	"v3_midnight_chess_clock": {
		"title": "The Midnight Chess Clock",
		"description": "Two enormous stitched chess-clock buttons lean across a felt game board; a stout oxblood watchmaker taps their dented brass springs beneath a dim candle.",
		"choices": [
			["reset_clock_spring", "Pay 15 gold to strengthen a ticking heart spring (gain 2 max HP)", -15, 0, 0, 2],
			["wind_broken_hour", "Give up 2 lasting max HP to wind the broken clock (gain 24 gold)", 24, 0, 0, -2],
			["leave", "Let both brass clocks tick toward dawn", 0, 0, 0, 0],
		],
	},
	"v3_satin_dress_form": {
		"title": "The Satin Dress Form",
		"description": "A giant padded dress form blocks the attic path, its velvet waist split at a huge zipper; a tiny silver-eyed seamkeeper offers spare stuffing from the open seam.",
		"choices": [
			["patch_hollow_waist", "Pay 10 gold and 1 scrap for warm waist stuffing (heal 9 HP)", -10, -1, 9, 0],
			["lend_waist_stuffing", "Lend the dress form a handful of your stuffing (lose 5 HP, gain 2 scraps)", 0, 2, -5, 0],
			["leave", "Pull the satin curtain over the empty form", 0, 0, 0, 0],
		],
	},
}

## Independent hardcoded settlement oracle for one funded visit with the opening
## snapshot {gold 40, scraps 4, hero warden HP 12 / max HP 25}. Rows are
## [gold, scraps, hp, max_hp] after that single choice. The max-HP-only spring
## never heals current HP, and no projection dips a purse below zero.
const FUNDED_PROJECTIONS := {
	"v3_swinging_crib_mobile": {
		"tie_horse_strings": [40, 2, 20, 26],
		"collect_horse_bells": [57, 5, 8, 25],
		"leave": [40, 4, 12, 25],
	},
	"v3_midnight_chess_clock": {
		"reset_clock_spring": [25, 4, 12, 27],
		"wind_broken_hour": [64, 4, 12, 23],
		"leave": [40, 4, 12, 25],
	},
	"v3_satin_dress_form": {
		"patch_hollow_waist": [30, 3, 21, 25],
		"lend_waist_stuffing": [40, 6, 7, 25],
		"leave": [40, 4, 12, 25],
	},
}

## Earlier anchors that must remain present byte-for-byte. Choice rows are
## [id, text, gold, scraps, hp, max_hp].
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
	"v3_button_heart_shrine": {
		"title": "The Button-Heart Shrine",
		"description": "A moss-cloaked doll tends a beating brass button stitched into a chapel wall.",
		"choices": [
			["reinforce_heart", "Spend 2 scraps to sew a lasting heart seam (+3 max HP)", 0, -2, 0, 3],
			["surrender_button", "Give up 2 max HP for 24 gold", 24, 0, 0, -2],
			["leave", "Let the little heart keep ticking", 0, 0, 0, 0],
		],
	},
	"v3_needle_thorn_garden": {
		"title": "The Needle-Thorn Garden",
		"description": "Oxblood roses made of fabric bristle with huge blunt sewing needles.",
		"choices": [
			["harvest_thorns", "Endure 6 HP loss to salvage 3 scraps", 0, 3, -6, 0],
			["buy_rose_balm", "Spend 10 gold on rose balm (+6 HP)", -10, 0, 6, 0],
			["leave", "Slip through the unpricked path", 0, 0, 0, 0],
		],
	},
	"v3_lullaby_brass_keyhole": {
		"title": "The Lullaby Brass Keyhole",
		"description": "A bedroom door rises like a cliff, its huge singing brass keyhole rocking a plush crescent moon while a single oxblood ribbon unspools through the lock.",
		"choices": [
			["hush_keyhole_song", "Pay 17 gold and 1 scrap to hush the lock (heal 5 HP; gain 1 max HP)", -17, -1, 5, 1],
			["trade_heart_thread", "Trade 2 max HP of heart thread for a gilded key (gain 26 gold)", 26, 0, 0, -2],
			["leave", "Leave the little cloth moon singing", 0, 0, 0, 0],
		],
	},
}

## One refusal case per real precondition: [event_id, choice_id, snapshot,
## still-affordable sibling choice]. Each branch is one gold short, one scrap
## short, one HP short of surviving the damage, or one below the max-HP floor
## of 10; only the named transaction may be disabled.
const REFUSALS := [
	["v3_satin_dress_form", "patch_hollow_waist",
		{"gold": 9, "scraps": 4, "hero": {"id": "warden", "hp": 12, "max_hp": 25}},
		"lend_waist_stuffing"],
	["v3_swinging_crib_mobile", "tie_horse_strings",
		{"gold": 40, "scraps": 1, "hero": {"id": "warden", "hp": 12, "max_hp": 25}},
		"collect_horse_bells"],
	["v3_swinging_crib_mobile", "collect_horse_bells",
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": 2, "max_hp": 25}},
		"tie_horse_strings"],
	["v3_midnight_chess_clock", "wind_broken_hour",
		{"gold": 40, "scraps": 4, "hero": {"id": "warden", "hp": 11, "max_hp": 11}},
		"reset_clock_spring"],
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
	_test_precondition_refusals()
	_test_rotation_admission()
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_crib_chess_dress_vital_stories_test: ",
		"PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
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
	_check(parsed == OK and parser.data is Dictionary
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


func _global_rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


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
		_check(record.get("id") == event_id, "new record ID is exact: " + event_id)
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
			if outcome is Dictionary:
				for key in ["gold", "scraps", "hp", "max_hp"]:
					_check(_is_integral_amount((outcome as Dictionary).get(key)),
						"new outcome amount is integral: " + event_id + "/" + choice_id + "/" + key)
		var rows: Array = expected["choices"]
		_check(by_id.size() == rows.size(), "new choice count matches the spec: " + event_id)
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
	for anchor_id in ANCHOR_RECORDS:
		var found := _matching(catalog, anchor_id)
		_check(found.size() == 1, "anchor record still present exactly once: " + anchor_id)
		if found.size() != 1:
			continue
		var record: Dictionary = found[0]
		var expected: Dictionary = ANCHOR_RECORDS[anchor_id]
		_check(record.get("title") == expected["title"], "anchor title is exact: " + anchor_id)
		_check(record.get("description") == expected["description"],
			"anchor description is exact: " + anchor_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3,
			"anchor keeps three authored choices: " + anchor_id)
		if not choices is Array:
			continue
		var by_id: Dictionary = {}
		for choice in choices:
			if choice is Dictionary and choice.get("id") is String:
				by_id[choice["id"]] = choice
		var rows: Array = expected["choices"]
		for row in rows:
			var choice_id: String = row[0]
			var tag: String = anchor_id + "/" + choice_id
			_check(by_id.has(choice_id), "anchor choice present: " + tag)
			if not by_id.has(choice_id):
				continue
			var choice_dict: Dictionary = by_id[choice_id]
			_check(choice_dict.get("text") == row[1], "anchor choice text exact: " + tag)
			var outcome: Variant = choice_dict.get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).size() == 4,
				"anchor outcome has exactly four keys: " + tag)
			if not outcome is Dictionary:
				continue
			var outcome_dict: Dictionary = outcome
			var keys := ["gold", "scraps", "hp", "max_hp"]
			for i in range(4):
				var raw: Variant = outcome_dict.get(keys[i])
				_check(_is_integral_amount(raw) and int(raw) == int(row[2 + i]),
					"anchor outcome " + keys[i] + " exact: " + tag)


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
	for anchor_id in ANCHOR_RECORDS:
		_check(seen.has(anchor_id), "anchor event ID is present in the catalog: " + anchor_id)


## Every one of the nine choices gets its own fresh visit against the funded
## opening snapshot; the exact projected state is compared to the independent
## FUNDED_PROJECTIONS oracle, one claim latches the visit, and the caller's
## record and snapshot are never edited.
func _test_funded_previews_and_claims() -> void:
	for event_id in NEW_EVENTS:
		var projections: Dictionary = FUNDED_PROJECTIONS[event_id]
		var rows: Array = NEW_EVENTS[event_id]["choices"]
		for row in rows:
			var choice_id: String = row[0]
			var gold_delta: int = int(row[2])
			var scraps_delta: int = int(row[3])
			var hp_delta: int = int(row[4])
			var max_delta: int = int(row[5])
			var tag: String = event_id + "/" + choice_id
			_check(projections.has(choice_id), "funded oracle covers the choice: " + tag)
			if not projections.has(choice_id):
				continue
			var oracle: Array = projections[choice_id]
			var record := _record(event_id)
			_check(not record.is_empty(), "funded case has its authored record: " + tag)
			if record.is_empty():
				continue
			var record_before: Dictionary = record.duplicate(true)
			var snapshot := _vital_state(BASE_GOLD, BASE_SCRAPS, BASE_HP, BASE_MAX_HP)
			var snapshot_before: Dictionary = snapshot.duplicate(true)
			var service := RunEventChoice.new(record)
			_check(service.is_valid() and not service.is_claimed(),
				"fresh funded visit is open: " + tag)
			var rng_guard := _global_rng_start(47417)
			var preview := service.preview_vital_choices(snapshot)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and (preview.get("choices") as Array).size() == 3,
				"funded preview lists all three choices: " + tag)
			var entry := _preview_choice(preview, choice_id)
			_check(entry.size() == 7, "funded preview entry has seven fields: " + tag)
			_check(entry.get("choice_id") == choice_id
				and entry.get("gold_delta") == gold_delta
				and entry.get("scraps_delta") == scraps_delta
				and entry.get("hp_delta") == hp_delta
				and entry.get("max_hp_delta") == max_delta,
				"funded preview reports the exact signed deltas: " + tag)
			_check(entry.get("affordable") == true
				and _vital_state_is(entry.get("state"), int(oracle[0]), int(oracle[1]),
					int(oracle[2]), int(oracle[3])),
				"funded preview projects the exact oracle state: " + tag)
			_check(int(oracle[0]) >= 0 and int(oracle[1]) >= 0,
				"funded projection never dips the purse below zero: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and service.is_valid() and not service.is_claimed(),
				"funded preview mutates nothing and stays unclaimed: " + tag)
			var receipt := service.choose_with_vitals(choice_id, snapshot)
			_check(receipt.size() == 4 and receipt.get("ok") == true
				and receipt.get("event_id") == event_id and receipt.get("choice_id") == choice_id,
				"funded claim names the authored event and choice: " + tag)
			_check(_vital_state_is(receipt.get("state"), int(oracle[0]), int(oracle[1]),
					int(oracle[2]), int(oracle[3])),
				"funded claim settles the exact oracle state: " + tag)
			_check(receipt.get("state") == entry.get("state"),
				"funded claim matches its preview forecast: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and service.get_event() == record_before,
				"funded claim leaves caller snapshot and record detached: " + tag)
			_check(randi() == rng_guard, "funded preview and claim consume no RNG draw: " + tag)
			_check(service.is_claimed() and not service.is_valid(),
				"funded claim latches exactly one visit: " + tag)
			var replay := service.choose_with_vitals(choice_id, snapshot)
			_check(replay.size() == 4 and replay.get("ok") == false
				and replay.get("event_id") == "" and replay.get("choice_id") == ""
				and replay.get("state") == snapshot_before and snapshot == snapshot_before,
				"one successful claim blocks a second unchanged: " + tag)
			_check(service.is_claimed(), "replay consumes no second claim: " + tag)


## Real precondition refusals: only the named transaction is disabled, the
## failed claim consumes no visit, no purse goes negative, HP and max HP stay
## untouched, and Leave still closes the visit exactly once.
func _test_precondition_refusals() -> void:
	for refusal in REFUSALS:
		var event_id: String = refusal[0]
		var choice_id: String = refusal[1]
		var snapshot: Dictionary = (refusal[2] as Dictionary).duplicate(true)
		var sibling_id: String = refusal[3]
		var tag: String = event_id + "/" + choice_id
		var record := _record(event_id)
		_check(not record.is_empty(), "refusal case has its authored record: " + tag)
		if record.is_empty():
			continue
		var snapshot_before: Dictionary = snapshot.duplicate(true)
		var service := RunEventChoice.new(record)
		_check(service.is_valid() and not service.is_claimed(),
			"refusal visit opens valid: " + tag)
		var preview := service.preview_vital_choices(snapshot)
		var entry := _preview_choice(preview, choice_id)
		_check(preview.get("ok") == true and not entry.is_empty()
			and entry.get("affordable") == false and entry.get("state") == snapshot_before,
			"refused preview forecasts unaffordable with unchanged state: " + tag)
		var sibling := _preview_choice(preview, sibling_id)
		_check(not sibling.is_empty() and sibling.get("affordable") == true,
			"only the refused transaction is disabled: " + tag)
		var leave_entry := _preview_choice(preview, "leave")
		_check(not leave_entry.is_empty() and leave_entry.get("affordable") == true,
			"Leave stays selectable in the refused preview: " + tag)
		var rejection := service.choose_with_vitals(choice_id, snapshot)
		_check(rejection.size() == 4 and rejection.get("ok") == false
			and rejection.get("event_id") == "" and rejection.get("choice_id") == ""
			and rejection.get("state") == snapshot_before,
			"refused claim fails with an unchanged detached state: " + tag)
		var refused_state: Dictionary = rejection.get("state", {})
		_check(int(refused_state.get("gold", -1)) >= 0
			and int(refused_state.get("scraps", -1)) >= 0,
			"refusal never leaves a negative purse: " + tag)
		_check(refused_state.get("hero", {}).get("hp") == snapshot_before["hero"]["hp"]
			and refused_state.get("hero", {}).get("max_hp") == snapshot_before["hero"]["max_hp"],
			"refusal never silently changes HP or max HP: " + tag)
		_check(snapshot == snapshot_before and service.is_valid()
			and not service.is_claimed(),
			"refused claim consumes no visit and mutates nothing: " + tag)
		var leave := service.choose_with_vitals("leave", snapshot)
		_check(leave.get("ok") == true and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave"
			and leave.get("state") == snapshot_before
			and service.is_claimed() and not service.is_valid(),
			"zero-delta Leave closes the otherwise-refused visit: " + tag)
		var second := service.choose_with_vitals("leave", snapshot)
		_check(second.get("ok") == false and service.is_claimed(),
			"Leave is claimable exactly once: " + tag)
		_check(snapshot == snapshot_before,
			"post-Leave caller state stays unchanged: " + tag)


## The augmented shipped catalog must validate, admit the three new IDs plus the
## named anchors, hand out deep-detached records, select from a dynamically
## computed eligible list with a seeded RNG, and consume no RNG on invalid
## exclusions or a fully excluded selection.
func _test_rotation_admission() -> void:
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped vitality rotation validates")
	var listing: Array = rotation.get_vital_events()
	var ids: Array = rotation.get_vital_event_ids()
	var listing_before: Array = listing.duplicate(true)
	_check(not ids.is_empty(), "the vitality rotation offers a non-empty pool")
	for event_id in NEW_EVENTS:
		var tag: String = "rotation " + event_id
		var authored := _record(event_id)
		_check(ids.count(event_id) == 1, "new ID is eligible exactly once: " + tag)
		var offered := _matching(listing, event_id)
		_check(offered.size() == 1, "new ID is offered exactly once: " + tag)
		if offered.size() == 1:
			_check(offered[0] == authored,
				"offered new record matches the authored source: " + tag)
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		var rng := RandomNumberGenerator.new()
		rng.seed = 75733
		var oracle := RandomNumberGenerator.new()
		oracle.seed = 75733
		oracle.randi_range(0, 0)
		var result := rotation.select_event(rng, excluded)
		_check(result.get("ok") == true
			and (result.get("event") as Dictionary).get("id") == event_id,
			"new ID is selected when every other ID is excluded: " + tag)
		_check(result.get("event") == authored,
			"forced selection returns the authored new record: " + tag)
		_check(rng.state == oracle.state,
			"forced selection consumes exactly one range draw: " + tag)
	for anchor_id in ANCHOR_RECORDS:
		_check(ids.count(anchor_id) == 1,
			"earlier anchor is still eligible exactly once: " + anchor_id)
	# A full-pool seeded draw replays against an independent oracle over the
	# dynamically computed eligible list (never a baked index or count).
	var full_rng := RandomNumberGenerator.new()
	full_rng.seed = 19087
	var full_oracle := RandomNumberGenerator.new()
	full_oracle.seed = 19087
	var expected_id: Variant = ids[full_oracle.randi_range(0, ids.size() - 1)]
	var picked := rotation.select_event(full_rng)
	_check(picked.get("ok") == true and picked.get("event", {}).get("id") == expected_id,
		"a seeded full-pool draw matches the independent oracle")
	_check(full_rng.state == full_oracle.state,
		"a seeded full-pool draw consumes exactly one range draw")
	# Deep detachment: mutating a returned listing or selection never reaches
	# the rotation or the shipped catalog.
	if not listing.is_empty():
		var first: Dictionary = listing[0]
		first["title"] = "MUTATED"
		listing.append({"id": "injected"})
		_check(rotation.get_vital_events() == listing_before,
			"mutating a returned listing never reaches the rotation")
	var only_form: Array = ids.duplicate()
	only_form.erase("v3_satin_dress_form")
	var forced := rotation.select_event(RandomNumberGenerator.new(), only_form)
	_check(forced.get("ok") == true
		and (forced.get("event") as Dictionary).get("id") == "v3_satin_dress_form",
		"a second forced draw still selects the authored new record")
	var selected: Dictionary = forced.get("event", {})
	var selected_before: Dictionary = selected.duplicate(true)
	selected["title"] = "MUTATED"
	(selected["choices"] as Array).clear()
	var again := rotation.select_event(RandomNumberGenerator.new(), only_form)
	_check(again.get("event") == selected_before,
		"a returned event is deep-detached from the rotation")
	# Invalid exclusions and a fully excluded selection reject without any RNG
	# draw.
	var guard_rng := RandomNumberGenerator.new()
	guard_rng.seed = 30011
	var guard_state := guard_rng.state
	_check(rotation.select_event(guard_rng, 42).get("ok") == false,
		"a non-array exclusion rejects")
	_check(rotation.select_event(guard_rng, ["v3_swinging_crib_mobile", 7]).get("ok") == false,
		"an exclusion with a non-string entry rejects")
	_check(rotation.select_event(guard_rng, ids.duplicate()).get("ok") == false,
		"excluding every ID rejects the selection")
	_check(guard_rng.state == guard_state,
		"invalid exclusions and empty eligibility consume no RNG draw")
