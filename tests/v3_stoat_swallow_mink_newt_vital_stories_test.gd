extends SceneTree
## Deterministic headless test for the four look-driven gothic roadside vitality
## stories appended to data/events/v3_vital_story_events.json (V3-4) and for
## their admission to the shipped RunV3VitalEventRotation pool.
##
## The catalog is loaded through FileAccess and every assertion is per-ID: no
## catalog total, positional index or frozen ordered ID list is asserted,
## because other lanes append to the same catalog in parallel. Expectations
## below are independent copies of the authored brief, never generated from the
## catalog under test.

const EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

## Funded living-hero snapshot used to prove preview/commit agreement.
const FUNDED_GOLD := 60
const FUNDED_SCRAPS := 8
const FUNDED_HP := 20
const FUNDED_MAX_HP := 40

## Poor snapshot: no currency, and 1/10 HP leaves no margin for any paid,
## HP-debiting or max-HP-cutting branch, so every non-Leave choice must fail
## closed (HP floor and max-HP floor are both exercised).
const POOR_GOLD := 0
const POOR_SCRAPS := 0
const POOR_HP := 1
const POOR_MAX_HP := 10

## Independent authored expectations for the four new records.
## Choice rows are [id, text, gold, scraps, hp, max_hp].
const NEW_EVENTS := {
	"v3_sable_stoat_pin_parlor": {
		"title": "The Sable Stoat Pin Parlour",
		"description": "A plump sable-velvet stoat doll peers over an enormous silver safety-pin clamp beside a rain-dark parlour lamp, its cream button eyes bright in the amber glow.",
		"choices": [
			["rent_pin_cushion", "Pay 12 gold for a cushion of warm stuffing (+7 HP)", -12, 0, 7, 0],
			["sort_sharp_pins", "Sort the stoat's sharp pins (lose 4 HP; gain 17 gold and 1 scrap)", 17, 1, -4, 0],
			["leave", "Leave the pin parlour to its lamplight", 0, 0, 0, 0],
		],
	},
	"v3_silver_swallow_needlebridge": {
		"title": "The Silver Swallow Needlebridge",
		"description": "A round midnight-teal swallow puppet carries a bridge-long curved needle between its padded wings, stitching an oxblood ribbon span above cold fog.",
		"choices": [
			["repair_wing_seam", "Spend 1 scrap to close a torn wing seam (+5 HP, +1 max HP)", 0, -1, 5, 1],
			["trade_old_feathers", "Trade a lasting feather seam for a silver purse (lose 2 max HP; gain 25 gold)", 25, 0, 0, -2],
			["leave", "Let the swallow stitch the bridge alone", 0, 0, 0, 0],
		],
	},
	"v3_bonecream_mink_spool_cart": {
		"title": "The Bone-Cream Mink Spool Cart",
		"description": "A squat bone-cream mink doll braces a wagon-sized brass spool with patched mitten paws, the cart wheels knocking along a moss-black roadside.",
		"choices": [
			["buy_spool_lining", "Pay 16 gold for a lasting spool lining (+2 max HP)", -16, 0, 0, 2],
			["haul_brass_axle", "Haul the heavy axle (lose 5 HP; gain 2 scraps)", 0, 2, -5, 0],
			["leave", "Let the spool cart trundle into the mist", 0, 0, 0, 0],
		],
	},
	"v3_plum_newt_thimble_forge": {
		"title": "The Plum Newt Thimble Forge",
		"description": "A round plum-gingham newt puppet hunches over a house-sized copper thimble furnace, its stitched-X eyes lit by a single ember.",
		"choices": [
			["buy_ember_hem", "Pay 10 gold and 1 scrap for a warm ember hem (+8 HP, +1 max HP)", -10, -1, 8, 1],
			["rake_copper_cinders", "Rake hot cinders (lose 4 HP; gain 19 gold)", 19, 0, -4, 0],
			["leave", "Walk on as the thimble furnace cools", 0, 0, 0, 0],
		],
	},
}

## Independent copies of the two named prior anchors that must stay intact.
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
	"v3_stitchglass_snow_owl": {
		"title": "The Stitchglass Snow Owl",
		"description": "A round bone-cream owl doll spreads enormous quilt-glass wings over a snowy felt hedge; amber button eyes warm the falling silver pins.",
		"choices": [
			["buy_wing_padding", "Pay 16 gold for a lasting feather seam (+2 max HP)", -16, 0, 0, 2],
			["gather_silver_pins", "Gather sharp fallen pins (lose 3 HP; gain 17 gold and 1 scrap)", 17, 1, -3, 0],
			["leave", "Let the owl fold its glass wings", 0, 0, 0, 0],
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
	_test_healing_cap_to_max()
	_test_unfunded_refusals_then_leave()
	_test_floor_rejections()
	_test_rotation_admission()
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stoat_swallow_mink_newt_vital_stories_test: ",
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
	# Every authored choice is previewed and then claimed on a fresh one-visit
	# service from the funded snapshot; the receipt must match the forecast, the
	# caller snapshot and the catalog record must stay untouched, and exactly one
	# claim may be latched. No global RNG draw may happen in any flow.
	for event_id in NEW_EVENTS:
		var rows: Array = NEW_EVENTS[event_id]["choices"]
		for row in rows:
			var choice_id: String = row[0]
			var gold_delta: int = int(row[2])
			var scraps_delta: int = int(row[3])
			var hp_delta: int = int(row[4])
			var max_delta: int = int(row[5])
			var tag: String = event_id + "/" + choice_id
			var exp_gold: int = FUNDED_GOLD + gold_delta
			var exp_scraps: int = FUNDED_SCRAPS + scraps_delta
			var exp_max: int = FUNDED_MAX_HP + max_delta
			var exp_hp: int = mini(FUNDED_HP + hp_delta, exp_max)
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
			var rng_guard := _global_rng_start(81021)
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
				and _vital_state_is(entry.get("state"), exp_gold, exp_scraps, exp_hp, exp_max),
				"funded preview projects the exact bounded state: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and service.is_valid() and not service.is_claimed(),
				"funded preview mutates nothing and stays unclaimed: " + tag)
			if choice_id == "leave":
				_check(entry.get("state") == snapshot_before,
					"free Leave previews an unchanged snapshot: " + tag)
				_check(gold_delta == 0 and scraps_delta == 0 and hp_delta == 0 and max_delta == 0,
					"free Leave carries four zero deltas: " + tag)
			var receipt := service.choose_with_vitals(choice_id, snapshot)
			_check(receipt.size() == 4 and receipt.get("ok") == true
				and receipt.get("event_id") == event_id and receipt.get("choice_id") == choice_id,
				"funded claim names the authored event and choice: " + tag)
			_check(_vital_state_is(receipt.get("state"), exp_gold, exp_scraps, exp_hp, exp_max),
				"funded claim settles the exact bounded state: " + tag)
			_check(receipt.get("state") == entry.get("state"),
				"funded claim matches its preview forecast: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and service.get_event() == record_before,
				"funded claim leaves caller snapshot and catalog detached: " + tag)
			_check(randi() == rng_guard, "funded preview and claim consume no RNG draw: " + tag)
			_check(service.is_claimed() and not service.is_valid(),
				"funded claim latches exactly one visit: " + tag)
			var replay := service.choose_with_vitals(choice_id, snapshot)
			_check(replay.size() == 4 and replay.get("ok") == false
				and replay.get("event_id") == "" and replay.get("choice_id") == ""
				and replay.get("state") == snapshot_before and snapshot == snapshot_before,
				"funded spent visit rejects the replay unchanged: " + tag)
			_check(service.is_claimed(), "replay consumes no second claim: " + tag)


func _test_healing_cap_to_max() -> void:
	# rent_pin_cushion heals 7; from 38/40 the result must cap at the new max.
	var record := _record("v3_sable_stoat_pin_parlor")
	_check(not record.is_empty(), "capped-heal case has its authored record")
	if record.is_empty():
		return
	var service := RunEventChoice.new(record)
	var near_full := _vital_state(60, 8, 38, 40)
	var receipt := service.choose_with_vitals("rent_pin_cushion", near_full)
	_check(receipt.get("ok") == true
		and _vital_state_is(receipt.get("state"), 48, 8, 40, 40),
		"a heal above the new maximum caps HP at the maximum")
	# repair_wing_seam raises max HP before healing: 38/40 -> max 41, hp 43 -> 41.
	var swallow := _record("v3_silver_swallow_needlebridge")
	_check(not swallow.is_empty(), "capped max-HP case has its authored record")
	if swallow.is_empty():
		return
	var swallow_service := RunEventChoice.new(swallow)
	var raised := swallow_service.choose_with_vitals("repair_wing_seam", near_full)
	_check(raised.get("ok") == true
		and _vital_state_is(raised.get("state"), 60, 7, 41, 41),
		"a heal is capped by the raised maximum, not the old one")


func _test_unfunded_refusals_then_leave() -> void:
	# With an empty wallet and a 1/10 hero every non-Leave branch is either
	# unpaid, HP-debiting below 1, or max-HP-cutting below the floor, so both
	# must forecast unaffordable and refuse without latching; the free Leave
	# then settles.
	for event_id in NEW_EVENTS:
		var rows: Array = NEW_EVENTS[event_id]["choices"]
		var state := _vital_state(POOR_GOLD, POOR_SCRAPS, POOR_HP, POOR_MAX_HP)
		var original: Dictionary = state.duplicate(true)
		var record := _record(event_id)
		_check(not record.is_empty(), "poor case has its authored record: " + event_id)
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
				"poor branch forecasts unaffordable with an unchanged state: " + tag)
			var refusal := service.choose_with_vitals(choice_id, state)
			_check(refusal.size() == 4 and refusal.get("ok") == false
				and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
				and refusal.get("state") == original,
				"poor branch refuses with an unchanged detached state: " + tag)
			_check(state == original and record == record_before
				and service.is_valid() and not service.is_claimed(),
				"poor refusal consumes no visit and mutates nothing: " + tag)
		_check(meaningful == 2, "new event has two meaningful branches: " + event_id)
		var leave := service.choose_with_vitals("leave", state)
		_check(leave.get("ok") == true and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave" and leave.get("state") == original
			and service.is_claimed() and not service.is_valid(),
			"free Leave still settles the visit after the refusals: " + event_id)
		var leave_replay := service.choose_with_vitals("leave", state)
		_check(leave_replay.get("ok") == false and leave_replay.get("state") == original
			and state == original,
			"settled poor visit rejects a repeated Leave: " + event_id)
		var unknown := service.choose_with_vitals("not_a_choice", state)
		_check(unknown.get("ok") == false and unknown.get("state") == original
			and state == original,
			"settled poor visit rejects an unknown choice: " + event_id)


func _test_floor_rejections() -> void:
	# Explicit HP-floor and max-HP-floor negatives through the new authored
	# deltas, plus a direct 10 max-HP floor refusal at the 0/0/1/10 snapshot.
	var stoat := _record("v3_sable_stoat_pin_parlor")
	var swallow := _record("v3_silver_swallow_needlebridge")
	var mink := _record("v3_bonecream_mink_spool_cart")
	_check(not stoat.is_empty() and not swallow.is_empty() and not mink.is_empty(),
		"floor cases have their authored records")
	if stoat.is_empty() or swallow.is_empty() or mink.is_empty():
		return
	# sort_sharp_pins (hp -4) on a 4 HP hero would fall to 0: refused unchanged.
	var stoat_service := RunEventChoice.new(stoat)
	var low_hp := _vital_state(0, 0, 4, 10)
	var low_hp_before: Dictionary = low_hp.duplicate(true)
	var hp_denial := stoat_service.choose_with_vitals("sort_sharp_pins", low_hp)
	_check(hp_denial.get("ok") == false and hp_denial.get("state") == low_hp_before
		and low_hp == low_hp_before and stoat_service.is_valid()
		and not stoat_service.is_claimed(),
		"an HP debit below the 1 HP floor refuses without claiming")
	var hp_preview := _preview_choice(stoat_service.preview_vital_choices(low_hp), "sort_sharp_pins")
	_check(hp_preview.get("affordable") == false, "the HP-floor branch previews unaffordable")
	# trade_old_feathers (max_hp -2) at the 10 floor would drop to 8: refused.
	var swallow_service := RunEventChoice.new(swallow)
	var floor_snapshot := _vital_state(0, 0, 1, 10)
	var floor_before: Dictionary = floor_snapshot.duplicate(true)
	var max_denial := swallow_service.choose_with_vitals("trade_old_feathers", floor_snapshot)
	_check(max_denial.get("ok") == false and max_denial.get("state") == floor_before
		and floor_snapshot == floor_before and swallow_service.is_valid()
		and not swallow_service.is_claimed(),
		"a max-HP cut below the 10 max-HP floor refuses without claiming")
	var max_preview := _preview_choice(
		swallow_service.preview_vital_choices(floor_snapshot), "trade_old_feathers")
	_check(max_preview.get("affordable") == false, "the max-HP-floor branch previews unaffordable")
	# haul_brass_axle (hp -5) on a 5 HP hero leaves 0: refused.
	var mink_service := RunEventChoice.new(mink)
	var thin := _vital_state(0, 0, 5, 12)
	var thin_before: Dictionary = thin.duplicate(true)
	var thin_denial := mink_service.choose_with_vitals("haul_brass_axle", thin)
	_check(thin_denial.get("ok") == false and thin_denial.get("state") == thin_before
		and thin == thin_before and mink_service.is_valid() and not mink_service.is_claimed(),
		"an HP debit to zero on a nearly-dead hero refuses without claiming")


func _test_rotation_admission() -> void:
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped vitality rotation validates")
	var listing: Array = rotation.get_vital_events()
	var ids: Array = rotation.get_vital_event_ids()
	var listing_before: Array = listing.duplicate(true)
	_check(not ids.is_empty(), "the vitality rotation offers a non-empty pool")
	var seed_value := 95300
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
		var returned_event: Dictionary = result.get("event")
		if not returned_event.is_empty():
			returned_event["title"] = "MUTATED_BY_TEST"
			returned_event["choices"] = []
			var still := _matching(rotation.get_vital_events(), event_id)
			_check(still.size() == 1 and still[0].get("title") == authored.get("title")
				and (still[0].get("choices") as Array).size() == 3,
				"mutating the returned record never reaches the rotation pool: " + tag)
		seed_value += 1
	for anchor_id in ANCHOR_RECORDS:
		_check(ids.has(anchor_id), "an older named record is still offered: " + anchor_id)
	var exhausted_rng := RandomNumberGenerator.new()
	exhausted_rng.seed = 95700
	var exhausted_before := exhausted_rng.state
	var exhausted := rotation.select_event(exhausted_rng, ids)
	_check(exhausted.get("ok") == false and (exhausted.get("event") as Dictionary).is_empty(),
		"an exhausted pool rejects selection")
	_check(exhausted_rng.state == exhausted_before,
		"an exhausted selection consumes no RNG draw")
	var invalid_rng := RandomNumberGenerator.new()
	invalid_rng.seed = 95800
	var invalid_before := invalid_rng.state
	var invalid := rotation.select_event(invalid_rng, ["v3_sable_stoat_pin_parlor", 3])
	_check(invalid.get("ok") == false and (invalid.get("event") as Dictionary).is_empty(),
		"malformed exclusions reject selection")
	_check(invalid_rng.state == invalid_before,
		"a malformed exclusion request consumes no RNG draw")
	_check(rotation.get_vital_events() == listing_before,
		"every rotation flow leaves the shipped pool unchanged")
