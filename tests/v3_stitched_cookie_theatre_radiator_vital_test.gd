extends SceneTree
## Deterministic headless test for the three lasting roadside vitality stories
## appended to data/events/v3_vital_story_events.json (the iron-star cookie
## cutter, the shadow toy theatre and the mosslit radiator cage), and for
## their admission to the shipped RunV3VitalEventRotation pool.
##
## Every assertion is per-ID: no catalog total, positional index or frozen
## ordered ID list is asserted, because other lanes append to the same catalog
## in parallel. Expectations below are independent copies of the authored brief,
## never generated from the catalog under test.

const EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

## Funded living-hero snapshot used to prove preview/commit agreement.
const FUNDED_GOLD := 60
const FUNDED_SCRAPS := 6
const FUNDED_HP := 18
const FUNDED_MAX_HP := 30

## Starved snapshot: no currency, and 1/10 HP leaves no margin for any paid or
## self-harming branch, so every non-Leave choice must fail closed.
const STARVED_GOLD := 0
const STARVED_SCRAPS := 0
const STARVED_HP := 1
const STARVED_MAX_HP := 10

## The three new IDs as an independent list for rotation checks.
const NEW_EVENT_IDS := [
	"v3_ironstar_cookie_cutter",
	"v3_oxblood_shadow_toy_theatre",
	"v3_mosslit_radiator_cage",
]

## Independent authored expectations for the three new records. Choice rows are
## [id, text, gold, scraps, hp, max_hp, funded post-claim gold, scraps, hp, max_hp].
const NEW_EVENTS := {
	"v3_ironstar_cookie_cutter": {
		"title": "The Iron-Star Cutter",
		"description": "A star-shaped tin cutter taller than the dolls hangs in a candlelit kitchen doorway; a round pin-eyed baker has stitched its sharp rim with old apron hems.",
		"choices": [
			["line_the_star", "Line the cutter's points with spare stuffing to strengthen a doll's seam", 0, -2, 0, 3, 60, 4, 18, 33],
			["stamp_own_heart", "Press away a permanent heart-seam to claim the baker's coin", 27, 0, 0, -2, 87, 6, 18, 28],
			["leave", "Leave the tin star swaying in the doorway", 0, 0, 0, 0, 60, 6, 18, 30],
		],
	},
	"v3_oxblood_shadow_toy_theatre": {
		"title": "The Shadow Toy Theatre",
		"description": "A folded oxblood toy theatre fills a corridor nook; stitched silhouettes of missing dolls sway behind a single amber footlight.",
		"choices": [
			["reinforce_curtain", "Buy velvet lining to mend a doll and give it a lasting seam", -18, 0, 6, 1, 42, 6, 24, 31],
			["tear_backdrop", "Tear down the backdrop for spare cloth, taking a sharp cut", 0, 3, -6, 0, 60, 9, 12, 30],
			["leave", "Leave the shadow players to their silent show", 0, 0, 0, 0, 60, 6, 18, 30],
		],
	},
	"v3_mosslit_radiator_cage": {
		"title": "The Mosslit Radiator Cage",
		"description": "A squat brass radiator rattles behind a cage of cross-stitched bars; a round moth-eyed keeper feeds it the loose sleeves of forgotten coats.",
		"choices": [
			["tuck_warm_padding", "Buy warmth and sew the padded lining beneath a doll's coat", -14, -1, 4, 2, 46, 5, 22, 32],
			["drain_hot_coils", "Drain the coils for scrap, burning the doll's stuffing", 0, 2, -5, 0, 60, 8, 13, 30],
			["leave", "Let the radiator click and cool in the dark", 0, 0, 0, 0, 60, 6, 18, 30],
		],
	},
}

## Independent copies of the two named older anchors that must stay intact.
## Choice rows are [id, text, gold, scraps, hp, max_hp].
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
}

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
	_test_starved_refusals_then_leave()
	_test_rotation_admission()
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_cookie_theatre_radiator_vital_test: ", "PASS" if failures.is_empty() else "FAIL",
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
	var document_ok := parsed == OK and parser.data is Dictionary
	var events_variant: Variant = (parser.data as Dictionary).get("events") if parser.data is Dictionary else null
	document_ok = document_ok and events_variant is Array
	_check(document_ok, "the vitality catalog parses to {events: [...]}")
	if not document_ok:
		return []
	var events: Array = events_variant
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
		return is_finite(number) and floor(number) == number and absf(number) <= RunEventChoice.MAX_SAFE_FLOAT_INT
	return false


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


## Seeds the global RNG and returns the next draw on an identical fresh seed,
## so a later randi() call proves no global draw happened in between.
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


func _test_funded_previews_and_claims() -> void:
	# Every authored choice is previewed and then committed on a fresh one-visit
	# service from the funded snapshot; the receipt must match both the forecast
	# and the independently transcribed funded matrix, the caller snapshot and
	# the catalog record must stay untouched, and exactly one claim may be
	# latched before replay and unknown choice IDs are refused. No global RNG
	# draw may happen in any flow.
	for event_id in NEW_EVENTS:
		var rows: Array = NEW_EVENTS[event_id]["choices"]
		for row in rows:
			var choice_id: String = row[0]
			var gold_delta: int = int(row[2])
			var scraps_delta: int = int(row[3])
			var hp_delta: int = int(row[4])
			var max_delta: int = int(row[5])
			var exp_gold: int = int(row[6])
			var exp_scraps: int = int(row[7])
			var exp_hp: int = int(row[8])
			var exp_max: int = int(row[9])
			var tag: String = event_id + "/" + choice_id
			_check(exp_gold == FUNDED_GOLD + gold_delta and exp_scraps == FUNDED_SCRAPS + scraps_delta
				and exp_max == FUNDED_MAX_HP + max_delta and exp_hp <= exp_max,
				"funded matrix is internally consistent: " + tag)
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
			var rng_guard := _global_rng_start(83017)
			var preview := service.preview_vital_choices(snapshot)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and (preview.get("choices") as Array).size() == 3,
				"funded preview lists all three choices: " + tag)
			for entry in preview.get("choices", []):
				_check(entry is Dictionary and (entry as Dictionary).get("affordable") == true,
					"funded preview marks every choice affordable: " + tag)
			var entry := _preview_choice(preview, choice_id)
			_check(entry.size() == 7, "funded preview entry has seven fields: " + tag)
			_check(entry.get("choice_id") == choice_id
				and entry.get("gold_delta") == gold_delta
				and entry.get("scraps_delta") == scraps_delta
				and entry.get("hp_delta") == hp_delta
				and entry.get("max_hp_delta") == max_delta,
				"funded preview reports the exact signed deltas: " + tag)
			_check(entry.get("affordable") == true
				and _vital_state_is(entry.get("state"), exp_gold, exp_scraps, exp_hp, exp_max),
				"funded preview projects the exact independent matrix state: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and service.is_valid() and not service.is_claimed(),
				"funded preview mutates nothing and stays unclaimed: " + tag)
			var receipt := service.choose_with_vitals(choice_id, snapshot)
			_check(receipt.size() == 4 and receipt.get("ok") == true
				and receipt.get("event_id") == event_id and receipt.get("choice_id") == choice_id,
				"funded commit names the authored event and choice: " + tag)
			_check(_vital_state_is(receipt.get("state"), exp_gold, exp_scraps, exp_hp, exp_max),
				"funded commit settles the exact independent matrix state: " + tag)
			_check(receipt.get("state") == entry.get("state"),
				"funded commit matches its preview forecast: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and service.get_event() == record_before,
				"funded commit leaves caller snapshot and catalog detached: " + tag)
			_check(randi() == rng_guard, "funded preview and commit consume no RNG draw: " + tag)
			_check(service.is_claimed() and not service.is_valid(),
				"funded commit latches exactly one visit: " + tag)
			var replay := service.choose_with_vitals(choice_id, snapshot)
			_check(replay.size() == 4 and replay.get("ok") == false
				and replay.get("event_id") == "" and replay.get("choice_id") == ""
				and replay.get("state") == snapshot_before and snapshot == snapshot_before,
				"funded spent visit rejects the replay unchanged: " + tag)
			var unknown := service.choose_with_vitals("not_an_authored_choice", snapshot)
			_check(unknown.size() == 4 and unknown.get("ok") == false
				and unknown.get("event_id") == "" and unknown.get("choice_id") == ""
				and unknown.get("state") == snapshot_before and snapshot == snapshot_before,
				"funded spent visit rejects an unknown choice unchanged: " + tag)
			_check(service.is_claimed(), "replay and unknown refuse a second claim: " + tag)


func _test_starved_refusals_then_leave() -> void:
	# With an empty wallet and a 1/10 hero every non-Leave branch is either
	# unpaid, lethal or below the max-HP floor, so all six must forecast
	# unaffordable and refuse without latching; the free Leave then settles
	# and cannot be replayed. A non-offered choice ID must also refuse before
	# any claim.
	for event_id in NEW_EVENTS:
		var rows: Array = NEW_EVENTS[event_id]["choices"]
		var state := _vital_state(STARVED_GOLD, STARVED_SCRAPS, STARVED_HP, STARVED_MAX_HP)
		var original: Dictionary = state.duplicate(true)
		var record := _record(event_id)
		_check(not record.is_empty(), "starved case has its authored record: " + event_id)
		if record.is_empty():
			continue
		var record_before: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(record)
		var meaningful := 0
		for row in rows:
			var choice_id: String = row[0]
			if choice_id == "leave":
				continue
			meaningful += 1
			var tag: String = event_id + "/" + choice_id
			var preview := service.preview_vital_choices(state)
			var entry := _preview_choice(preview, choice_id)
			_check(preview.get("ok") == true and not entry.is_empty()
				and entry.get("affordable") == false and entry.get("state") == original,
				"starved branch forecasts unaffordable with an unchanged state: " + tag)
			var refusal := service.choose_with_vitals(choice_id, state)
			_check(refusal.size() == 4 and refusal.get("ok") == false
				and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
				and refusal.get("state") == original,
				"starved branch refuses with an unchanged detached state: " + tag)
			_check(state == original and record == record_before
				and service.is_valid() and not service.is_claimed(),
				"starved refusal consumes no visit and mutates nothing: " + tag)
		_check(meaningful == 2, "new event has two meaningful branches: " + event_id)
		var unoffered := service.choose_with_vitals("not_an_authored_choice", state)
		_check(unoffered.size() == 4 and unoffered.get("ok") == false
			and unoffered.get("state") == original and state == original
			and service.is_valid() and not service.is_claimed(),
			"a non-offered choice ID refuses before any claim: " + event_id)
		var leave := service.choose_with_vitals("leave", state)
		_check(leave.get("ok") == true and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave" and leave.get("state") == original
			and service.is_claimed() and not service.is_valid(),
			"free Leave still settles the visit after the refusals: " + event_id)
		var leave_replay := service.choose_with_vitals("leave", state)
		_check(leave_replay.get("ok") == false and leave_replay.get("state") == original
			and state == original,
			"settled starved visit rejects a repeated Leave: " + event_id)


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
	for anchor_id in ANCHOR_RECORDS:
		_check(ids.has(anchor_id), "an older named record is still offered: " + anchor_id)
	# Prove seeded selection without coupling to unrelated appends: exclude
	# every OTHER shipped event ID so only the three new stories are eligible.
	var excluded: Array = []
	for shipped_id in ids:
		if not NEW_EVENT_IDS.has(shipped_id):
			excluded.append(shipped_id)
	var seed_value := 77431
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var oracle := RandomNumberGenerator.new()
	oracle.seed = seed_value
	oracle.randi_range(0, 2)
	var result := rotation.select_event(rng, excluded)
	_check(result.get("ok") == true, "restricted seeded selection succeeds")
	var chosen_event: Dictionary = result.get("event")
	_check(not chosen_event.is_empty() and NEW_EVENT_IDS.has(chosen_event.get("id")),
		"restricted seeded selection picks one of the three new stories")
	_check(rng.state == oracle.state,
		"restricted selection consumes exactly one range draw")
	if result.get("ok") == true and not chosen_event.is_empty():
		var chosen_service := RunEventChoice.new(chosen_event)
		_check(chosen_service.is_valid() and not chosen_service.is_claimed(),
			"selected new record is presentable to RunEventChoice")
		_check(chosen_event == _record(chosen_event.get("id")),
			"selected new record matches the authored source")
		var replay := RandomNumberGenerator.new()
		replay.seed = seed_value
		var again := rotation.select_event(replay, excluded)
		_check(again == result and replay.state == rng.state,
			"a same-seed replay repeats the restricted selection")
	# All three new stories lack an affordable non-Leave choice for the
	# starved snapshot, so the actionable selector must reject before any draw.
	var starved := _vital_state(STARVED_GOLD, STARVED_SCRAPS, STARVED_HP, STARVED_MAX_HP)
	var starved_rng := RandomNumberGenerator.new()
	starved_rng.seed = seed_value
	var untouched := RandomNumberGenerator.new()
	untouched.seed = seed_value
	var refusal := rotation.select_actionable_event(starved_rng, excluded, starved)
	_check(refusal.size() == 2 and refusal.get("ok") == false
		and (refusal.get("event") as Dictionary).is_empty(),
		"starved actionable selection rejects without an event")
	_check(starved_rng.state == untouched.state,
		"starved actionable rejection consumes no RNG draw")
	_check(rotation.get_vital_events() == listing_before,
		"every rotation flow leaves the shipped pool unchanged")

