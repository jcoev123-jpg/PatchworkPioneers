extends SceneTree
## Deterministic headless test for the four authored gothic vitality roadside
## tales appended to data/events/v3_vital_story_events.json (V3-4) and for their
## admission to the shipped RunV3VitalEventRotation and RunEventChoice services.
##
## Expectations below are independent literal copies of the authored brief; the
## catalog under test is never used to generate its own oracle. Every check is
## per-ID: no catalog total, positional index or full ordered ID list is
## asserted, because other lanes append to the same catalog in parallel.

const EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

const FUNDED_GOLD := 100
const FUNDED_SCRAPS := 10
const FUNDED_HP := 12
const FUNDED_MAX_HP := 30

## Independent authored expectations for the four new records.
## Choice rows are [id, text, gold, scraps, hp, max_hp].
const NEW_EVENTS := {
	"v3_plum_accordion_sickroom": {
		"title": "The Plum Accordion Sickroom",
		"description": "A round plum-cloth nurse pumps a concertina as large as a bed, its bone-cream bellows sewn with red healing stitches.",
		"choices": [
			["warm_bellows", "Pay 15 gold to warm the stitched bellows (heal 7 HP)", -15, 0, 7, 0],
			["pump_night_watch", "Pump the heavy concertina for wages (lose 4 HP; gain 18 gold)", 18, 0, -4, 0],
			["leave", "Leave the accordion sleeping", 0, 0, 0, 0],
		],
	},
	"v3_copper_hedgehog_pin_bower": {
		"title": "The Copper Hedgehog Pin Bower",
		"description": "A squat moss hedgehog doll carries a bristling silver pincushion on its back; giant copper safety pins hold a canopy of quilt leaves.",
		"choices": [
			["fasten_heart_pin", "Spend 2 scraps to fasten a lasting heart pin (+2 max HP)", 0, -2, 0, 2],
			["pawn_own_heart_pin", "Unpick a lasting heart pin for 23 gold (lose 2 max HP)", 23, 0, 0, -2],
			["leave", "Leave the copper pins beneath their leaves", 0, 0, 0, 0],
		],
	},
	"v3_teal_swan_needleboat": {
		"title": "The Teal Swan Needleboat",
		"description": "A plump midnight-teal swan puppet glides in a coat-shaped boat, its oversized silver needle beak stitching the torn canal moon.",
		"choices": [
			["repair_moon_sail", "Pay 12 gold and 1 scrap to mend the moon-sail (+5 HP, +1 max HP)", -12, -1, 5, 1],
			["dive_for_silver_thread", "Dive for lost thread (lose 3 HP; gain 2 scraps)", 0, 2, -3, 0],
			["leave", "Let the swan's needleboat drift on", 0, 0, 0, 0],
		],
	},
	"v3_rosebutton_teapot_oracle": {
		"title": "The Rose-Button Teapot Oracle",
		"description": "A round rose-cloth fortune keeper pours glowing tea from a giant button-lidded teapot; steam forms stitched heart-shaped clouds.",
		"choices": [
			["drink_hearth_tea", "Pay 17 gold for hot heart tea (heal 8 HP)", -17, 0, 8, 0],
			["trade_rose_seam", "Unpick 1 max HP for the teapot keeper (gain 21 gold)", 21, 0, 0, -1],
			["leave", "Leave the rose-button lid closed", 0, 0, 0, 0],
		],
	},
}

## Independent literal copies of the two named anchors the brief asks us to
## retain byte-for-byte.
const ANCHOR_RECORDS := {
	"v3_moon_threadfish_lantern": {
		"title": "The Moon-Threadfish Lantern",
		"description": "A rotund midnight-teal fish doll floats beneath a quilted canal bridge, dragging an enormous amber lantern from its ribbon tail.",
		"choices": [
			["mend_glowing_gill", "Pay 11 gold and 1 scrap to mend the lantern gill (+5 HP, +1 max HP)", -11, -1, 5, 1],
			["snag_lightline", "Snag the loose lantern thread (lose 4 HP; gain 2 scraps)", 0, 2, -4, 0],
			["leave", "Watch the threadfish drift into the dark", 0, 0, 0, 0],
		],
	},
	"v3_honeycomb_button_hive": {
		"title": "The Honeycomb Button Hive",
		"description": "A squat moss-and-mustard hive with great brass button holes hums as fat striped cloth bees stitch amber honey into a velvet teacup.",
		"choices": [
			["sip_button_honey", "Pay 19 gold for a cup of warming button honey (+9 HP)", -19, 0, 9, 0],
			["trade_queen_seam", "Give the hive one lasting heart seam (lose 1 max HP; gain 27 gold)", 27, 0, 0, -1],
			["leave", "Leave the buzzing button hive asleep", 0, 0, 0, 0],
		],
	},
}

## Charged choices: event_id -> Array of [choice_id, gold, scraps]. Each branch
## is exercised at a one-unit-short wallet so the debit refuses while the visit
## stays open for a following zero-delta Leave.
const CHARGE_BOUNDARIES := {
	"v3_plum_accordion_sickroom": [["warm_bellows", 15, 0]],
	"v3_copper_hedgehog_pin_bower": [["fasten_heart_pin", 0, 2]],
	"v3_teal_swan_needleboat": [["repair_moon_sail", 12, 1]],
	"v3_rosebutton_teapot_oracle": [["drink_hearth_tea", 17, 0]],
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
	_test_charge_boundary_refusals()
	_test_fatal_hp_loss_refusal()
	_test_invalid_max_hp_loss_refusal()
	_test_bogus_choice_and_replay()
	_test_rotation_admission()
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_plum_accordion_heart_stories_test: ",
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


func _test_funded_previews_and_claims() -> void:
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
			var rng_guard := _global_rng_start(84221)
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


## One-unit-short wallet for each charged choice: refuses without mutation and
## does not close the visit, so a zero-delta Leave still settles on the same
## unclaimed service.
func _test_charge_boundary_refusals() -> void:
	for event_id in CHARGE_BOUNDARIES:
		var record := _record(event_id)
		_check(not record.is_empty(), "charge-boundary event has its record: " + event_id)
		if record.is_empty():
			continue
		for charge in CHARGE_BOUNDARIES[event_id]:
			var choice_id: String = charge[0]
			var cost_gold: int = charge[1]
			var cost_scraps: int = charge[2]
			var tag: String = event_id + "/" + choice_id
			var short_gold: int = FUNDED_GOLD
			var short_scraps: int = FUNDED_SCRAPS
			if cost_gold > 0:
				short_gold = cost_gold - 1
			if cost_scraps > 0:
				short_scraps = cost_scraps - 1
			var poor := _vital_state(short_gold, short_scraps, FUNDED_HP, FUNDED_MAX_HP)
			var poor_before: Dictionary = poor.duplicate(true)
			var service := RunEventChoice.new(record)
			_check(service.is_valid() and not service.is_claimed(),
				"poor-wallet visit is open: " + tag)
			var preview := service.preview_vital_choices(poor)
			var entry := _preview_choice(preview, choice_id)
			_check(preview.get("ok") == true and not entry.is_empty()
				and entry.get("affordable") == false and entry.get("state") == poor_before,
				"charged preview forecasts unaffordable with unchanged state: " + tag)
			var refusal := service.choose_with_vitals(choice_id, poor)
			_check(refusal.size() == 4 and refusal.get("ok") == false
				and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
				and refusal.get("state") == poor_before,
				"charged branch refuses with an unchanged detached state: " + tag)
			_check(poor == poor_before and service.is_valid() and not service.is_claimed(),
				"charged refusal consumes no visit and mutates nothing: " + tag)
			var leave := service.choose_with_vitals("leave", poor)
			_check(leave.get("ok") == true and leave.get("event_id") == event_id
				and leave.get("choice_id") == "leave" and leave.get("state") == poor_before
				and service.is_claimed() and not service.is_valid(),
				"zero-delta Leave closes the otherwise-refused visit: " + tag)
			_check(poor == poor_before, "post-Leave caller state stays unchanged: " + tag)


## hp=4 against the -4 HP pump would land at 0 HP, which is not allowed; the
## refusal must leave the visit open for a zero-delta Leave.
func _test_fatal_hp_loss_refusal() -> void:
	var event_id := "v3_plum_accordion_sickroom"
	var record := _record(event_id)
	_check(not record.is_empty(), "fatal-pump event has its record")
	if record.is_empty():
		return
	var hp4 := _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, 4, FUNDED_MAX_HP)
	var hp4_before: Dictionary = hp4.duplicate(true)
	var service := RunEventChoice.new(record)
	var preview := service.preview_vital_choices(hp4)
	var entry := _preview_choice(preview, "pump_night_watch")
	_check(preview.get("ok") == true and not entry.is_empty()
		and entry.get("affordable") == false and entry.get("state") == hp4_before,
		"a lethal pump_night_watch at hp=4 forecasts unaffordable")
	var refusal := service.choose_with_vitals("pump_night_watch", hp4)
	_check(refusal.size() == 4 and refusal.get("ok") == false
		and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
		and refusal.get("state") == hp4_before,
		"lethal pump_night_watch refuses without mutating state")
	_check(hp4 == hp4_before and service.is_valid() and not service.is_claimed(),
		"lethal refusal leaves the visit open")
	var leave := service.choose_with_vitals("leave", hp4)
	_check(leave.get("ok") == true and leave.get("event_id") == event_id
		and leave.get("choice_id") == "leave" and leave.get("state") == hp4_before
		and service.is_claimed() and not service.is_valid(),
		"zero-delta Leave still closes the visit after a fatal refusal")
	_check(hp4 == hp4_before, "post-Leave caller state stays unchanged after fatal refusal")


## max_hp=11 against the -2 max-HP pawn_own_heart_pin would leave 9 (< floor
## 10), which is not allowed; refusal must leave the visit open for Leave.
func _test_invalid_max_hp_loss_refusal() -> void:
	var event_id := "v3_copper_hedgehog_pin_bower"
	var record := _record(event_id)
	_check(not record.is_empty(), "invalid-max event has its record")
	if record.is_empty():
		return
	var low_max := _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, 11, 11)
	var low_max_before: Dictionary = low_max.duplicate(true)
	var service := RunEventChoice.new(record)
	var preview := service.preview_vital_choices(low_max)
	var entry := _preview_choice(preview, "pawn_own_heart_pin")
	_check(preview.get("ok") == true and not entry.is_empty()
		and entry.get("affordable") == false and entry.get("state") == low_max_before,
		"a below-floor max-HP loss at max_hp=11 forecasts unaffordable")
	var refusal := service.choose_with_vitals("pawn_own_heart_pin", low_max)
	_check(refusal.size() == 4 and refusal.get("ok") == false
		and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
		and refusal.get("state") == low_max_before,
		"below-floor max-HP loss refuses without mutating state")
	_check(low_max == low_max_before and service.is_valid() and not service.is_claimed(),
		"below-floor refusal leaves the visit open")
	var leave := service.choose_with_vitals("leave", low_max)
	_check(leave.get("ok") == true and leave.get("event_id") == event_id
		and leave.get("choice_id") == "leave" and leave.get("state") == low_max_before
		and service.is_claimed() and not service.is_valid(),
		"zero-delta Leave still closes the visit after a below-floor refusal")
	_check(low_max == low_max_before,
		"post-Leave caller state stays unchanged after below-floor refusal")


## Unknown choice IDs refuse without latching, and a claimed visit refuses every
## later claim; neither path touches the caller state or RNG.
func _test_bogus_choice_and_replay() -> void:
	var event_id := "v3_teal_swan_needleboat"
	var record := _record(event_id)
	_check(not record.is_empty(), "bogus-choice event has its record")
	if record.is_empty():
		return
	var state := _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
	var state_before: Dictionary = state.duplicate(true)
	var service := RunEventChoice.new(record)
	var rng_guard := _global_rng_start(86753)
	for bogus in ["", "   ", "not_a_choice", "LEAVE", 42]:
		var refusal := service.choose_with_vitals(bogus, state)
		_check(refusal.get("ok") == false and refusal.get("event_id") == ""
			and refusal.get("choice_id") == ""
			and refusal.get("state") == state_before,
			"bogus choice refuses with an unchanged state: " + str(bogus))
		_check(service.is_valid() and not service.is_claimed(),
			"bogus choice does not latch the visit: " + str(bogus))
	_check(state == state_before, "bogus attempts leave caller state untouched")
	var claim := service.choose_with_vitals("repair_moon_sail", state)
	_check(claim.get("ok") == true and claim.get("event_id") == event_id
		and claim.get("choice_id") == "repair_moon_sail",
		"the authored claim succeeds after the bogus attempts")
	var replay := service.choose_with_vitals("repair_moon_sail", state)
	_check(replay.get("ok") == false and replay.get("state") == state_before
		and service.is_claimed(),
		"post-claim replay refuses and keeps the latch")
	_check(randi() == rng_guard, "bogus and replay flows consume no RNG draw")


func _test_rotation_admission() -> void:
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped vitality rotation validates")
	var listing: Array = rotation.get_vital_events()
	var ids: Array = rotation.get_vital_event_ids()
	var listing_before: Array = listing.duplicate(true)
	_check(not ids.is_empty(), "the vitality rotation offers a non-empty pool")
	var seed_value := 96100
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
		if result.get("ok") == true and result.get("event") is Dictionary:
			(result["event"] as Dictionary)["title"] = "mutated"
		_check(rotation.get_vital_events() == listing_before,
			"mutating a selected record never reaches the rotation pool: " + tag)
		seed_value += 1
	for anchor_id in ANCHOR_RECORDS:
		_check(ids.has(anchor_id), "an older named record is still offered: " + anchor_id)
	var exhausted_rng := RandomNumberGenerator.new()
	exhausted_rng.seed = 96500
	var exhausted_before := exhausted_rng.state
	var exhausted := rotation.select_event(exhausted_rng, ids)
	_check(exhausted.get("ok") == false and (exhausted.get("event") as Dictionary).is_empty(),
		"an exhausted pool rejects selection")
	_check(exhausted_rng.state == exhausted_before,
		"an exhausted selection consumes no RNG draw")
	var invalid_rng := RandomNumberGenerator.new()
	invalid_rng.seed = 96600
	var invalid_before := invalid_rng.state
	var invalid := rotation.select_event(invalid_rng, ["v3_plum_accordion_sickroom", 3])
	_check(invalid.get("ok") == false and (invalid.get("event") as Dictionary).is_empty(),
		"malformed exclusions reject selection")
	_check(invalid_rng.state == invalid_before,
		"a malformed exclusion request consumes no RNG draw")
	_check(rotation.get_vital_events() == listing_before,
		"every rotation flow leaves the shipped pool unchanged")
