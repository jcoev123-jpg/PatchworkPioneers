extends SceneTree
## Deterministic headless regression for the four prop-led V3-4 vitality stories
## appended by this lane: the Velvet Handbell Nursery, the Brass-Boot Cobbler,
## the Blacklace Wind-Up Mouse and the Glass-Button Tidepool.
##
## The shipping catalog is loaded through FileAccess/JSON and every record is
## located by ID: no catalog total, index or full ordered ID list is frozen, so
## the other lanes' concurrent additions stay independent. The expected titles,
## descriptions, choice texts and signed outcome tuples below are authored
## independently of the production JSON, never derived from it.

const EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

# Independent authored expectations. Choice rows are
# [id, text, gold, scraps, hp, max_hp].
const NEW_EVENTS := {
	"v3_velvet_handbell_nursery": {
		"title": "The Velvet Handbell Nursery",
		"description": "A plump rose-cloth nurse rocks a cradle made from an enormous velvet handbell, its brass clapper wrapped in warm stitched blankets.",
		"choices": [
			["stitch_crib_hem", "Pay 14 gold to stitch the bell-cradle's warm hem (heal 7 HP; gain 1 max HP)", -14, 0, 7, 1],
			["ring_bell_shift", "Keep the heavy bell ringing through the night (lose 5 HP; gain 2 scraps)", 0, 2, -5, 0],
			["leave", "Leave the little bell asleep", 0, 0, 0, 0],
		],
	},
	"v3_brass_boot_cobbler": {
		"title": "The Brass-Boot Cobbler",
		"description": "A squat button-eyed cobbler threads enormous moonlit shoelaces through a brass boot as tall as a quilt tent.",
		"choices": [
			["lace_heart_sole", "Spend 2 scraps lacing a lasting heart-sole (+3 max HP)", 0, -2, 0, 3],
			["unpick_old_heel", "Sell the lining from an old heel (lose 1 max HP; gain 21 gold)", 21, 0, 0, -1],
			["leave", "Let the brass boot stand untouched", 0, 0, 0, 0],
		],
	},
	"v3_blacklace_windup_mouse": {
		"title": "The Blacklace Wind-Up Mouse",
		"description": "A round stuffed clockwork mouse drags a key larger than its body across black lace, its single amber button eye blinking beside a tiny oil lamp.",
		"choices": [
			["rewind_heart", "Pay 17 gold for a winding-key heart mend (heal 10 HP)", -17, 0, 10, 0],
			["trade_stuffing", "Give 4 HP of soft stuffing to oil the gears (gain 18 gold and 1 scrap)", 18, 1, -4, 0],
			["leave", "Allow the mouse to wind itself down", 0, 0, 0, 0],
		],
	},
	"v3_glass_button_tidepool": {
		"title": "The Glass-Button Tidepool",
		"description": "Beneath a midnight-teal pier, a giant translucent glass button shelters a round coral ragdoll gathering glowing silver thread from the tide.",
		"choices": [
			["sew_pearl_socket", "Pay 12 gold and 1 scrap to stitch a pearl socket (heal 2 HP; gain 2 max HP)", -12, -1, 2, 2],
			["dive_for_thread", "Dive into the cold tide for shining thread (lose 7 HP; gain 3 scraps)", 0, 3, -7, 0],
			["leave", "Leave the quiet tidepool unpicked", 0, 0, 0, 0],
		],
	},
}

# Named older anchors that must survive this append unchanged.
const ANCHOR_TITLES := {
	"v3_lantern_quilt_infirmary": "The Lantern-Quilt Infirmary",
	"v3_button_heart_shrine": "The Button-Heart Shrine",
	"v3_rosebutton_teapot_oracle": "The Rose-Button Teapot Oracle",
}

const FUNDED_GOLD := 50
const FUNDED_SCRAPS := 5
const FUNDED_HP := 20
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


## Seeds the global RNG and returns the next draw on an identical fresh seed,
## so a later randi() call proves that no global draw happened in between.
func _global_rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


func _state(gold: int, scraps: int, hp: int, max_hp: int) -> Dictionary:
	return {"gold": gold, "scraps": scraps, "hero": {"id": "warden", "hp": hp, "max_hp": max_hp}}


func _state_is(state: Variant, gold: int, scraps: int, hp: int, max_hp: int) -> bool:
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


func _matching(event_id: String) -> Array:
	return catalog.filter(func(entry) -> bool:
		return entry is Dictionary and entry.get("id") == event_id)


## A deep copy of the authored catalog entry for the given ID, or {} if absent.
func _record(event_id: String) -> Dictionary:
	for entry in catalog:
		if entry is Dictionary and entry.get("id") == event_id:
			return (entry as Dictionary).duplicate(true)
	return {}


func _load_events() -> Array:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "the vitality catalog opens through FileAccess")
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_result := parser.parse(text)
	_check(parse_result == OK, "the vitality catalog parses through JSON")
	if parse_result != OK or not parser.data is Dictionary:
		return []
	var document: Dictionary = parser.data
	var events: Variant = document.get("events")
	_check(events is Array, "the vitality catalog carries an events array")
	if not events is Array:
		return []
	return (events as Array).duplicate(true)


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _initialize() -> void:
	catalog = _load_events()
	catalog_snapshot = catalog.duplicate(true)
	_check(not catalog.is_empty(), "the vitality catalog carries authored records")
	if not catalog.is_empty():
		_test_new_records_exact()
		_test_new_ids_unique()
		_test_named_anchors_present()
		_test_funded_settlement_and_claims()
		_test_healing_and_max_hp_boundaries()
		_test_refusals_then_leave()
		_test_rotation_admission()
	_check(catalog == catalog_snapshot, "no flow mutates the loaded vitality catalog")
	for failure in failures:
		printerr(failure)
	print("v3_handbell_boot_mouse_tidepool_vital_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _test_new_records_exact() -> void:
	for event_id in NEW_EVENTS:
		var expected: Dictionary = NEW_EVENTS[event_id]
		var matches := _matching(event_id)
		_check(matches.size() == 1, "exactly one authored record for " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"new record has exactly id/title/description/choices: " + event_id)
		var title: Variant = record.get("title")
		var description: Variant = record.get("description")
		_check(title is String and not (title as String).strip_edges().is_empty()
			and title == expected["title"], "new title is exact and nonblank: " + event_id)
		_check(description is String and not (description as String).strip_edges().is_empty()
			and description == expected["description"],
			"new description is exact and nonblank: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3,
			"new record has exactly three choices: " + event_id)
		if not choices is Array:
			continue
		var seen := {}
		var by_id := {}
		for choice in choices:
			_check(choice is Dictionary and choice.size() == 3 and choice.has("id")
				and choice.has("text") and choice.has("outcome"),
				"new choice has exactly id/text/outcome: " + event_id)
			if not choice is Dictionary:
				continue
			var choice_id: Variant = choice.get("id")
			var choice_text: Variant = choice.get("text")
			_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
				"new choice ID is nonblank: " + event_id)
			_check(choice_text is String and not (choice_text as String).strip_edges().is_empty(),
				"new choice text is nonblank: " + event_id)
			if choice_id is String:
				var id_text: String = choice_id
				_check(not seen.has(id_text), "new choice IDs are distinct: " + event_id + "/" + id_text)
				seen[id_text] = true
				by_id[id_text] = choice
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).size() == 4
				and (outcome as Dictionary).has("gold") and (outcome as Dictionary).has("scraps")
				and (outcome as Dictionary).has("hp") and (outcome as Dictionary).has("max_hp"),
				"new outcome has exactly gold/scraps/hp/max_hp: " + event_id)
			if outcome is Dictionary:
				for key in ["gold", "scraps", "hp", "max_hp"]:
					_check(_is_integral_amount((outcome as Dictionary).get(key)),
						"new outcome amount is integral: " + event_id + "/" + str(choice_id) + "/" + key)
		var wanted: Array = expected["choices"]
		_check(seen.size() == wanted.size(), "new choice count matches the authored table: " + event_id)
		for row in wanted:
			var tag: String = event_id + "/" + row[0]
			_check(by_id.has(row[0]), "authored choice present: " + tag)
			if not by_id.has(row[0]):
				continue
			var choice_dict: Dictionary = by_id[row[0]]
			_check(choice_dict.get("text") == row[1], "authored choice text is exact: " + tag)
			var outcome: Variant = choice_dict.get("outcome")
			if not outcome is Dictionary:
				continue
			var outcome_dict: Dictionary = outcome
			var keys := ["gold", "scraps", "hp", "max_hp"]
			for i in range(4):
				var raw: Variant = outcome_dict.get(keys[i])
				_check(_is_integral_amount(raw) and int(raw) == int(row[2 + i]),
					"authored outcome " + keys[i] + " is exact: " + tag)
		# The free way out is always present and exactly zero-effect.
		_check(by_id.has("leave"), "authored record offers Leave: " + event_id)
		if by_id.has("leave"):
			var leave_outcome: Variant = (by_id["leave"] as Dictionary).get("outcome")
			_check(leave_outcome is Dictionary
				and (leave_outcome as Dictionary).size() == 4
				and int((leave_outcome as Dictionary).get("gold")) == 0
				and int((leave_outcome as Dictionary).get("scraps")) == 0
				and int((leave_outcome as Dictionary).get("hp")) == 0
				and int((leave_outcome as Dictionary).get("max_hp")) == 0,
				"authored Leave is a zero-effect exit: " + event_id)
		var service := RunEventChoice.new(record.duplicate(true))
		_check(service.is_valid() and not service.is_claimed(),
			"authored record builds a fresh valid selector: " + event_id)


func _test_new_ids_unique() -> void:
	_check(NEW_EVENTS.size() == 4, "the independent table names exactly four new stories")
	for event_id in NEW_EVENTS:
		var count := 0
		for entry in catalog:
			if entry is Dictionary and entry.get("id") == event_id:
				count += 1
		_check(count == 1, "new ID appears exactly once in the catalog: " + event_id)
	# No duplicated ID anywhere in the catalog (no total or ordering is frozen).
	var seen := {}
	for entry in catalog:
		if not entry is Dictionary:
			continue
		var raw_id: Variant = entry.get("id")
		_check(raw_id is String and not (raw_id as String).strip_edges().is_empty(),
			"every catalog record carries a nonblank ID")
		if not raw_id is String:
			continue
		_check(not seen.has(raw_id), "catalog IDs are unique: " + str(raw_id))
		seen[raw_id] = true


func _test_named_anchors_present() -> void:
	for anchor_id in ANCHOR_TITLES:
		var matches := _matching(anchor_id)
		_check(matches.size() == 1, "named anchor remains present exactly once: " + anchor_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.get("title") == ANCHOR_TITLES[anchor_id],
			"named anchor title is unchanged: " + anchor_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and not (choices as Array).is_empty(),
			"named anchor keeps its authored choices: " + anchor_id)
		_check(RunEventChoice.new(record).is_valid(),
			"named anchor still builds a valid selector: " + anchor_id)


func _test_funded_settlement_and_claims() -> void:
	# Every one of the twelve branches previews and settles its exact signed
	# gold/scraps/HP/max-HP effect from a fresh funded, living hero snapshot.
	for event_id in NEW_EVENTS:
		var rows: Array = (NEW_EVENTS[event_id] as Dictionary)["choices"]
		for row in rows:
			var choice_id: String = row[0]
			var tag: String = event_id + "/" + choice_id
			var gold_delta: int = int(row[2])
			var scraps_delta: int = int(row[3])
			var hp_delta: int = int(row[4])
			var max_hp_delta: int = int(row[5])
			var exp_gold: int = FUNDED_GOLD + gold_delta
			var exp_scraps: int = FUNDED_SCRAPS + scraps_delta
			var exp_max: int = FUNDED_MAX_HP + max_hp_delta
			var exp_hp: int = min(FUNDED_HP + hp_delta, exp_max)
			var expected_state := _state(exp_gold, exp_scraps, exp_hp, exp_max)

			var record := _record(event_id)
			_check(not record.is_empty(), "funded branch has its real catalog record: " + tag)
			if record.is_empty():
				continue
			var record_before: Dictionary = record.duplicate(true)
			var global_state := _global_rng_start(80100 + rows.find(row))

			# Preview on a NEW instance must not latch the visit.
			var preview_service := RunEventChoice.new(record.duplicate(true))
			_check(preview_service.is_valid() and not preview_service.is_claimed(),
				"fresh preview selector starts valid and unclaimed: " + tag)
			var snapshot: Dictionary = _state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
			var snapshot_before: Dictionary = snapshot.duplicate(true)
			var preview := preview_service.preview_vital_choices(snapshot)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and (preview.get("choices") as Array).size() == 3,
				"funded preview succeeds with three choices: " + tag)
			var entry := _preview_choice(preview, choice_id)
			_check(entry == {"choice_id": choice_id, "gold_delta": gold_delta,
				"scraps_delta": scraps_delta, "hp_delta": hp_delta,
				"max_hp_delta": max_hp_delta, "affordable": true, "state": expected_state},
				"funded preview reports exact deltas and projected state: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and preview_service.is_valid() and not preview_service.is_claimed()
				and preview_service.get_event() == record_before,
				"preview neither latches nor mutates input or source: " + tag)
			_check(randi() == global_state, "preview spends no global RNG: " + tag)

			# Settle on a different NEW instance and compare exact results.
			global_state = _global_rng_start(80200 + rows.find(row))
			var commit_service := RunEventChoice.new(record.duplicate(true))
			var input: Dictionary = _state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
			var input_before: Dictionary = input.duplicate(true)
			var commit := commit_service.choose_with_vitals(choice_id, input)
			_check(commit == {"ok": true, "event_id": event_id, "choice_id": choice_id,
				"state": expected_state},
				"funded settlement returns the exact authored result: " + tag)
			_check(commit.get("state") == entry.get("state"),
				"settlement matches its preview forecast: " + tag)
			_check(input == input_before and record == record_before
				and commit_service.get_event() == record_before,
				"settlement mutates neither caller input nor source: " + tag)
			_check(commit_service.is_claimed() and not commit_service.is_valid(),
				"settlement latches exactly one claim: " + tag)
			_check(randi() == global_state, "settlement spends no global RNG: " + tag)

			# Scribbling on the returned states must not reach the caller or source.
			(commit["state"] as Dictionary)["gold"] = 999
			(entry["state"] as Dictionary)["hero"]["hp"] = 999
			_check(input == input_before and record == record_before,
				"returned states are detached from caller and source: " + tag)
			_check(_record(event_id) == record_before,
				"the catalog stays readable and unchanged after settlement: " + tag)

			# A replay after success fails and consumes nothing.
			global_state = _global_rng_start(80300 + rows.find(row))
			var replay_input: Dictionary = _state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
			var replay := commit_service.choose_with_vitals(choice_id, replay_input)
			_check(replay == {"ok": false, "event_id": "", "choice_id": "", "state": replay_input},
				"replay after success is rejected unchanged: " + tag)
			_check(commit_service.is_claimed() and not commit_service.is_valid(),
				"replay consumes no second claim: " + tag)
			_check(commit_service.preview_vital_choices(replay_input) == DENIED_PREVIEW,
				"a claimed visit refuses a second preview: " + tag)
			_check(randi() == global_state, "replay spends no global RNG: " + tag)


func _test_healing_and_max_hp_boundaries() -> void:
	# Healing is capped by the projected maximum: 38 + 10 caps at 40.
	var mouse := _record("v3_blacklace_windup_mouse")
	_check(not mouse.is_empty(), "mouse record present for the capped-heal case")
	if not mouse.is_empty():
		var mouse_service := RunEventChoice.new(mouse)
		var nearly_full: Dictionary = _state(FUNDED_GOLD, FUNDED_SCRAPS, 38, 40)
		var nearly_full_before: Dictionary = nearly_full.duplicate(true)
		var capped := mouse_service.choose_with_vitals("rewind_heart", nearly_full)
		_check(capped.get("ok") == true
			and _state_is(capped.get("state"), 33, 5, 40, 40),
			"rewind_heart caps a 10 HP heal at the 40 max HP")
		_check(nearly_full == nearly_full_before and mouse_service.is_claimed(),
			"a capped heal preserves the caller state and spends one visit")

	# A lasting max-HP gain alone never heals current HP: 20 stays 20, max 43.
	var boot := _record("v3_brass_boot_cobbler")
	_check(not boot.is_empty(), "brass boot record present for the max-gain case")
	if not boot.is_empty():
		var boot_service := RunEventChoice.new(boot)
		var raised: Dictionary = _state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
		var up := boot_service.choose_with_vitals("lace_heart_sole", raised)
		_check(up.get("ok") == true
			and _state_is(up.get("state"), 50, 3, 20, 43),
			"lace_heart_sole raises max HP to 43 without healing current HP")
		_check(boot_service.is_claimed(),
			"the lasting heart-sole still spends exactly one visit")


func _test_refusals_then_leave() -> void:
	# One genuine shortage per resource class. Each refusal must not claim, not
	# mutate the caller state or source and not spend RNG; the SAME service must
	# then commit the free Leave once, after which every replay fails.
	var cases := [
		{"event": "v3_velvet_handbell_nursery", "choice": "stitch_crib_hem",
			"state": _state(0, 5, 20, 40), "label": "handbell gold"},
		{"event": "v3_blacklace_windup_mouse", "choice": "rewind_heart",
			"state": _state(0, 5, 20, 40), "label": "mouse gold"},
		{"event": "v3_brass_boot_cobbler", "choice": "lace_heart_sole",
			"state": _state(50, 0, 20, 40), "label": "boot scraps"},
		{"event": "v3_glass_button_tidepool", "choice": "sew_pearl_socket",
			"state": _state(50, 0, 20, 40), "label": "tidepool scraps"},
		{"event": "v3_velvet_handbell_nursery", "choice": "ring_bell_shift",
			"state": _state(50, 5, 5, 40), "label": "handbell hp"},
		{"event": "v3_blacklace_windup_mouse", "choice": "trade_stuffing",
			"state": _state(50, 5, 4, 40), "label": "mouse hp"},
		{"event": "v3_glass_button_tidepool", "choice": "dive_for_thread",
			"state": _state(50, 5, 7, 40), "label": "tidepool hp"},
		{"event": "v3_brass_boot_cobbler", "choice": "unpick_old_heel",
			"state": _state(50, 5, 10, 10), "label": "boot max-hp floor"},
	]
	for case_data in cases:
		var event_id: String = case_data["event"]
		var choice_id: String = case_data["choice"]
		var tag: String = case_data["label"] + " " + event_id + "/" + choice_id
		var state: Dictionary = (case_data["state"] as Dictionary).duplicate(true)
		var original: Dictionary = state.duplicate(true)
		var record := _record(event_id)
		_check(not record.is_empty(), "refusal case has its real catalog record: " + tag)
		if record.is_empty():
			continue
		var record_before: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(record.duplicate(true))
		var global_state := _global_rng_start(80300)

		var preview := service.preview_vital_choices(state)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id,
			"a short-resource hero can still preview the event: " + tag)
		var entry := _preview_choice(preview, choice_id)
		_check(entry.get("affordable") == false and entry.get("state") == original,
			"the costly branch is forecast unavailable with the unchanged state: " + tag)
		var refusal := service.choose_with_vitals(choice_id, state)
		_check(refusal == {"ok": false, "event_id": "", "choice_id": "", "state": original},
			"the costly branch refuses with a detached unchanged state: " + tag)
		_check(state == original and record == record_before
			and service.is_valid() and not service.is_claimed(),
			"refusal claims nothing and mutates neither input nor source: " + tag)
		_check(randi() == global_state, "refusal spends no global RNG: " + tag)
		(refusal["state"] as Dictionary)["gold"] = 999
		_check(state == original, "the refusal state is detached from the caller: " + tag)

		# The SAME instance can still take the free way out, exactly once.
		global_state = _global_rng_start(80400)
		var leave := service.choose_with_vitals("leave", state)
		_check(leave == {"ok": true, "event_id": event_id, "choice_id": "leave",
			"state": original},
			"free Leave settles the same visit after the refusal: " + tag)
		_check(service.is_claimed() and not service.is_valid(),
			"the Leave latches the one visit: " + tag)
		var leave_replay := service.choose_with_vitals("leave", state)
		var choice_replay := service.choose_with_vitals(choice_id, state)
		_check(leave_replay == {"ok": false, "event_id": "", "choice_id": "", "state": original}
			and choice_replay == {"ok": false, "event_id": "", "choice_id": "", "state": original}
			and state == original,
			"spent visit rejects Leave and the costly branch replay: " + tag)
		_check(randi() == global_state, "Leave and replay spend no global RNG: " + tag)


func _test_rotation_admission() -> void:
	# The shipping rotation validates and admits all four IDs, each exactly once,
	# with no duplicate, and offers the authored records detached and unchanged.
	var catalog_before: Array = catalog.duplicate(true)
	var anchors_before: Dictionary = {}
	for anchor_id in ANCHOR_TITLES:
		anchors_before[anchor_id] = _record(anchor_id)
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped vitality rotation validates with this batch")
	var listing: Array = rotation.get_vital_events()
	var ids: Array = rotation.get_vital_event_ids()
	_check(not ids.is_empty(), "the vitality rotation offers a non-empty pool")
	var listing_before: Array = listing.duplicate(true)
	for event_id in NEW_EVENTS:
		var tag: String = "rotation " + event_id
		var authored := _record(event_id)
		var offered := listing.filter(func(entry) -> bool:
			return entry is Dictionary and entry.get("id") == event_id)
		_check(offered.size() == 1, "the new ID is offered exactly once: " + tag)
		if offered.size() == 1:
			_check(offered[0] == authored,
				"the offered record matches the authored catalog record: " + tag)
		var id_hits := ids.filter(func(value) -> bool:
			return value == event_id)
		_check(id_hits.size() == 1, "the new ID appears once in the eligible ID pool: " + tag)
		_check(rotation.get_vital_events() == listing_before,
			"listing the rotation never mutates the pool: " + tag)
	_check(catalog == catalog_before, "rotation admission never mutates the loaded catalog")
	for anchor_id in ANCHOR_TITLES:
		_check(_record(anchor_id) == anchors_before[anchor_id],
			"the named anchor stays readable and unchanged: " + anchor_id)
