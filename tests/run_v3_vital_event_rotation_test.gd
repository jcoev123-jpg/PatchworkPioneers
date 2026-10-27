extends SceneTree
## Deterministic headless regression for RunV3VitalEventRotation, the scene-free
## seeded admission service for the authored V3-4 vitality story Events.
##
## The real catalog is loaded through FileAccess and every assertion is per-ID:
## no absolute catalog total and no ordered ID list is frozen, so future appended
## vitality tales join the pool without breaking this test. The three named
## anchors are checked against an independent copy of their authored records.
## Selection is replayed against an independent RandomNumberGenerator oracle and
## then settled through the real RunEventChoice vitality API.

const EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

## Independent expectations for the three named anchors. Choice rows are
## [id, text, gold, scraps, hp, max_hp]; the production constant is never read
## back as an oracle.
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
}

## Independent authored specification; never built from the shipping JSON.
const VITALITY_BATCH := {
	"v3_cindersilk_ledger": {
		"title": "The Cindersilk Ledger",
		"description": "A stout ink-eyed tax doll records lost stitches by candlelight.",
		"choices": [
			["redeem_cinders", "Burn 5 HP of worn stuffing for 14 gold and 1 scrap", 14, 1, -5, 0],
			["sew_credit", "Pay 22 gold to reinforce your seams (+3 max HP)", -22, 0, 0, 3],
			["leave", "Close the ledger and pass", 0, 0, 0, 0],
		],
	},
	"v3_starlit_needle_mill": {
		"title": "The Starlit Needle Mill",
		"description": "Round night workers wind silver needles into a towering velvet bobbin.",
		"choices": [
			["stitch_splint", "Spend 2 scraps to heal 8 HP and gain 1 max HP", 0, -2, 8, 1],
			["sell_strand", "Lose 2 max HP for 25 gold", 25, 0, 0, -2],
			["leave", "Leave the needle mill turning", 0, 0, 0, 0],
		],
	},
	"v3_rosewindow_sickroom": {
		"title": "The Rosewindow Sickroom",
		"description": "A button-eyed nurse warms stitched rose petals beside a painted glass window.",
		"choices": [
			["pay_poultice", "Pay 15 gold for a rose-petal poultice (+10 HP)", -15, 0, 10, 0],
			["donate_warmth", "Give 4 HP of warm stuffing for 2 scraps", 0, 2, -4, 0],
			["leave", "Leave the petals undisturbed", 0, 0, 0, 0],
		],
	},
	"v3_bronze_pin_oath": {
		"title": "The Bronze Pin Oath",
		"description": "A short velvet oathkeeper offers a glowing pin over a folded midnight quilt.",
		"choices": [
			["swear_oath", "Spend 6 gold, 1 scrap and 2 HP for 2 lasting max HP", -6, -1, -2, 2],
			["break_oath", "Surrender 1 max HP for 23 gold", 23, 0, 0, -1],
			["leave", "Refuse the bronze pin", 0, 0, 0, 0],
		],
	},
	"v3_velvet_stitchwell": {
		"title": "The Velvet Stitchwell",
		"description": "Beneath a moss-green canopy, a moonlit well is lined with neat cloth stitches.",
		"choices": [
			["drink_threadwater", "Offer 1 scrap; heal 6 HP and gain 2 max HP", 0, -1, 6, 2],
			["haul_quilt_rope", "Lose 5 HP hauling the quilt rope; earn 18 gold", 18, 0, -5, 0],
			["leave", "Leave the moonlit well untouched", 0, 0, 0, 0],
		],
	},
	"v3_owlsilk_apothecary": {
		"title": "The Owlsilk Apothecary",
		"description": "A round owl-faced ragdoll doles out amber lantern oil from damask pockets.",
		"choices": [
			["borrow_oil", "Pay 12 gold to mend 8 HP with warm lantern oil", -12, 0, 8, 0],
			["unpick_binding", "Unpick 1 max HP to salvage 1 scrap", 0, 1, 0, -1],
			["leave", "Fold the damask pockets and go", 0, 0, 0, 0],
		],
	},
}

const DENIED_PREVIEW := {"ok": false, "event_id": "", "choices": []}

var failures: Array[String] = []
var checks := 0
var source_document: Dictionary = {}
var source_snapshot: Dictionary = {}
var source_events: Array = []
var source_by_id: Dictionary = {}


func _initialize() -> void:
	_load_source()
	if source_document.is_empty():
		_report()
		return
	_test_source_coverage()
	_test_anchor_records()
	_test_every_record_presentable()
	_test_detached_listing()
	_test_seeded_selection()
	_test_reordered_catalog()
	_test_exclusions()
	_test_invalid_requests()
	_test_invalid_catalogs()
	_test_future_addition()
	_test_needle_thorn_garden_settlement()
	_test_button_heart_shrine_settlement()
	_test_infirmary_and_shared_validation()
	_test_vitality_batch()
	_check(source_document == source_snapshot, "the shipped vitality document is unchanged by every flow")
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("run_v3_vital_event_rotation_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_source() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "the vitality catalog opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_check(not text.is_empty(), "the vitality catalog is non-empty")
	var parser := JSON.new()
	var parsed := parser.parse(text)
	_check(parsed == OK, "the vitality catalog parses through JSON")
	if parsed != OK or not parser.data is Dictionary:
		return
	source_document = (parser.data as Dictionary).duplicate(true)
	var events: Variant = source_document.get("events")
	_check(events is Array, "the vitality catalog carries an events array")
	if not events is Array:
		source_document = {}
		return
	source_events = (events as Array).duplicate(true)
	_check(not source_events.is_empty(), "the vitality catalog has authored records")
	for record in source_events:
		if not record is Dictionary:
			continue
		var event_id: Variant = (record as Dictionary).get("id")
		if event_id is String and not source_by_id.has(event_id):
			source_by_id[event_id] = record
	source_snapshot = source_document.duplicate(true)


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


## Seeds the global RNG and returns the next draw on an identical fresh seed,
## so a later randi() call can prove that no global draw happened in between.
func _global_rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


func _matches(listing: Array, event_id: String) -> Array:
	var found: Array = []
	for record in listing:
		if record is Dictionary and record.get("id") == event_id:
			found.append(record)
	return found


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _selection_shape_ok(result: Variant) -> bool:
	if not result is Dictionary:
		return false
	var dict: Dictionary = result
	return (dict.size() == 2 and dict.has("ok") and dict.get("ok") is bool
		and dict.has("event") and dict.get("event") is Dictionary)


func _record_copy(event_id: String) -> Dictionary:
	if not source_by_id.has(event_id):
		return {}
	return (source_by_id[event_id] as Dictionary).duplicate(true)


func _without(events: Array, drop_id: String) -> Array:
	var kept: Array = []
	for record in events:
		if record is Dictionary and record.get("id") == drop_id:
			continue
		kept.append(record)
	return kept


func _replaced(events: Array, target_id: String, replacement: Variant) -> Array:
	var out: Array = []
	for record in events:
		if record is Dictionary and record.get("id") == target_id:
			out.append(replacement)
		else:
			out.append(record)
	return out


## Forces one authentic record through the public selector by excluding every
## other eligible ID, and independently replays the single permitted draw.
func _force_selected(rotation: RunV3VitalEventRotation, target_id: String, seed_value: int) -> Dictionary:
	var excluded: Array = rotation.get_vital_event_ids()
	excluded.erase(target_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var oracle := RandomNumberGenerator.new()
	oracle.seed = seed_value
	oracle.randi_range(0, 0)
	var result := rotation.select_event(rng, excluded)
	_check(result.get("ok") == true, "a forced vitality selection succeeds: " + target_id)
	var event: Dictionary = result.get("event", {})
	_check(event.get("id") == target_id, "the forced vitality selection returns " + target_id)
	_check(rng.state == oracle.state, "the forced vitality selection consumes one range draw: " + target_id)
	return event


func _test_source_coverage() -> void:
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped vitality catalog validates")
	var listing: Array = rotation.get_vital_events()
	var ids: Array = rotation.get_vital_event_ids()
	_check(not ids.is_empty(), "the vitality rotation offers a non-empty pool")
	_check(ids.size() == listing.size(), "the ID listing matches the record listing length")
	var seen: Dictionary = {}
	for record in listing:
		_check(record is Dictionary, "every vitality listing entry is an object")
		if not record is Dictionary:
			continue
		var raw_id: Variant = record.get("id")
		_check(raw_id is String and not (raw_id as String).strip_edges().is_empty(),
			"every offered vitality ID is a nonblank string")
		var event_id: String = raw_id
		_check(not seen.has(event_id), "offered vitality IDs are unique: " + event_id)
		seen[event_id] = true
	# Every authored source ID is offered exactly once with the authored record,
	# and the pool never invents an ID the source does not carry.
	for source_record in source_events:
		if not source_record is Dictionary:
			continue
		var source_id: Variant = (source_record as Dictionary).get("id")
		if not source_id is String:
			continue
		var found := _matches(listing, source_id)
		_check(found.size() == 1, "every authored vitality record is offered once: " + source_id)
		if found.size() == 1:
			_check(found[0] == source_record, "the offered record matches the authored source: " + source_id)
	for event_id in ids:
		_check(_matches(source_events, event_id).size() == 1,
			"every offered ID comes from the authored source: " + str(event_id))
	var sorted_ids: Array = ids.duplicate()
	sorted_ids.sort()
	_check(ids == sorted_ids, "the vitality ID listing is sorted")
	var without_null := RunV3VitalEventRotation.new(null)
	_check(without_null.is_catalog_valid()
		and without_null.get_vital_event_ids() == ids,
		"omitting the fixture argument reads the same shipped catalog")


func _test_anchor_records() -> void:
	var rotation := RunV3VitalEventRotation.new()
	var listing: Array = rotation.get_vital_events()
	for event_id in ANCHOR_RECORDS:
		var found := _matches(listing, event_id)
		_check(found.size() == 1, "exactly one offered anchor record: " + event_id)
		if found.size() != 1:
			continue
		var record: Dictionary = found[0]
		var expected: Dictionary = ANCHOR_RECORDS[event_id]
		_check(record.get("title") == expected["title"], "anchor title is exact: " + event_id)
		_check(record.get("description") == expected["description"],
			"anchor description is exact: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3,
			"anchor keeps three authored choices: " + event_id)
		if not choices is Array:
			continue
		var by_id: Dictionary = {}
		for choice in choices:
			if choice is Dictionary and choice.get("id") is String:
				by_id[choice["id"]] = choice
		var rows: Array = expected["choices"]
		for row in rows:
			var choice_id: String = row[0]
			var tag: String = event_id + "/" + choice_id
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


func _test_every_record_presentable() -> void:
	var rotation := RunV3VitalEventRotation.new()
	var listing: Array = rotation.get_vital_events()
	var guard := RandomNumberGenerator.new()
	guard.seed = 318318
	var guard_state := guard.state
	for record in listing:
		var event_id: String = record["id"]
		var service := RunEventChoice.new(record)
		_check(service.is_valid() and not service.is_claimed(),
			"every offered record is a valid RunEventChoice: " + event_id)
		var authored: Variant = record.get("choices")
		_check(authored is Array and (authored as Array).size() >= 2
			and (authored as Array).size() <= 3,
			"every offered record has two or three choices: " + event_id)
		if not authored is Array:
			continue
		var authored_by_id: Dictionary = {}
		for choice in authored:
			_check(choice is Dictionary, "every offered choice is an object: " + event_id)
			if not choice is Dictionary:
				continue
			var choice_id: Variant = (choice as Dictionary).get("id")
			_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
				"every offered choice has a nonblank ID: " + event_id)
			if not choice_id is String:
				continue
			_check(not authored_by_id.has(choice_id),
				"offered choice IDs are distinct: " + event_id + "/" + choice_id)
			authored_by_id[choice_id] = choice
			var outcome: Variant = (choice as Dictionary).get("outcome")
			_check(outcome is Dictionary, "every offered outcome is an object: "
				+ event_id + "/" + choice_id)
			if not outcome is Dictionary:
				continue
			var outcome_dict: Dictionary = outcome
			_check(outcome_dict.size() == 4 and outcome_dict.has("gold")
				and outcome_dict.has("scraps") and outcome_dict.has("hp")
				and outcome_dict.has("max_hp"),
				"every offered outcome has exactly four keys: " + event_id + "/" + choice_id)
			for key in ["gold", "scraps", "hp", "max_hp"]:
				_check(_is_integral_amount(outcome_dict.get(key)),
					"every offered outcome amount is integral: " + event_id + "/" + choice_id + "/" + key)
		# RunEventChoice's own preview parser must accept every authored outcome.
		var preview := service.preview_vital_choices(_vital_state(50, 5, 30, 40))
		_check(preview.get("ok") == true and preview.get("event_id") == event_id,
			"every offered record forecasts its vitality choices: " + event_id)
		var entries: Variant = preview.get("choices")
		_check(entries is Array and (entries as Array).size() == authored_by_id.size(),
			"the vitality preview lists every authored choice: " + event_id)
		if not entries is Array:
			continue
		for entry in entries:
			_check(entry is Dictionary, "every preview entry is an object: " + event_id)
			if not entry is Dictionary:
				continue
			var choice_id: String = entry["choice_id"]
			var authored_choice: Dictionary = authored_by_id.get(choice_id, {})
			_check(not authored_choice.is_empty(), "preview names an authored choice: "
				+ event_id + "/" + choice_id)
			if authored_choice.is_empty():
				continue
			var authored_outcome: Dictionary = authored_choice["outcome"]
			_check(entry.get("gold_delta") is int and entry.get("gold_delta") == int(authored_outcome["gold"]),
				"preview parses authored gold: " + event_id + "/" + choice_id)
			_check(entry.get("scraps_delta") is int
				and entry.get("scraps_delta") == int(authored_outcome["scraps"]),
				"preview parses authored scraps: " + event_id + "/" + choice_id)
			_check(entry.get("hp_delta") is int and entry.get("hp_delta") == int(authored_outcome["hp"]),
				"preview parses authored hp: " + event_id + "/" + choice_id)
			_check(entry.get("max_hp_delta") is int
				and entry.get("max_hp_delta") == int(authored_outcome["max_hp"]),
				"preview parses authored max_hp: " + event_id + "/" + choice_id)
			_check(entry.get("affordable") is bool, "preview reports affordability: "
				+ event_id + "/" + choice_id)
	_check(guard.state == guard_state, "the per-record validity pass never touches a run RNG")


func _test_detached_listing() -> void:
	var rotation := RunV3VitalEventRotation.new()
	var baseline: Array = rotation.get_vital_events()
	var baseline_snapshot: Array = baseline.duplicate(true)
	var baseline_ids: Array = rotation.get_vital_event_ids()
	_check(not baseline.is_empty(), "the listing is available before detachment checks")
	if baseline.is_empty():
		return
	var first: Dictionary = baseline[0]
	first["title"] = "MUTATED"
	first["choices"] = [{"id": "fake", "text": "fake",
		"outcome": {"gold": 0, "scraps": 0, "hp": 0, "max_hp": 0}}]
	baseline.append({"id": "injected"})
	var ids_copy: Array = rotation.get_vital_event_ids()
	ids_copy.append("injected")
	_check(rotation.get_vital_events() == baseline_snapshot,
		"mutating a returned record listing never reaches the rotation")
	_check(rotation.get_vital_event_ids() == baseline_ids,
		"mutating a returned ID listing never reaches the rotation")
	var fresh := RunV3VitalEventRotation.new()
	_check(fresh.get_vital_events() == baseline_snapshot,
		"a fresh rotation rebuilds the same records")
	var selected := _force_selected(rotation, "v3_needle_thorn_garden", 31802)
	_check(not selected.is_empty(), "a detached selection record is available")
	if not selected.is_empty():
		var snapshot: Dictionary = selected.duplicate(true)
		selected["title"] = "MUTATED"
		(selected["choices"] as Array).clear()
		selected["injected"] = true
		var again := _force_selected(rotation, "v3_needle_thorn_garden", 31802)
		_check(again == snapshot, "a returned event is detached from the rotation")
		_check(again == source_by_id.get("v3_needle_thorn_garden", {}),
			"a returned event still matches the authored source")
	_check(source_document == source_snapshot, "listing detachment never reaches the shipped source")


func _test_seeded_selection() -> void:
	var rotation := RunV3VitalEventRotation.new()
	var ids: Array = rotation.get_vital_event_ids()
	_check(ids.size() >= 3, "the vitality pool has enough events for a seeded draw")
	if ids.size() < 3:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var oracle := RandomNumberGenerator.new()
	oracle.seed = 424242
	var expected_id: Variant = ids[oracle.randi_range(0, ids.size() - 1)]
	var result := rotation.select_event(rng)
	_check(_selection_shape_ok(result), "a vitality selection returns exactly {ok, event}")
	_check(result.get("ok") == true, "a seeded vitality selection succeeds")
	var event: Dictionary = result.get("event", {})
	_check(event.get("id") == expected_id, "the selection matches an independent seeded RNG oracle")
	_check(ids.has(event.get("id")), "the selection belongs to the eligible pool")
	_check(rng.state == oracle.state, "one successful selection consumes exactly one range draw")
	var replay := RandomNumberGenerator.new()
	replay.seed = 424242
	var again := rotation.select_event(replay)
	_check(again.get("ok") == true and again.get("event", {}).get("id") == expected_id,
		"an identical seed and state replay the same vitality event")
	_check(replay.state == rng.state, "a replayed selection ends in identical RNG state")
	for seed_value in range(1, 33):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		var oracle_probe := RandomNumberGenerator.new()
		oracle_probe.seed = seed_value
		var oracle_id: Variant = ids[oracle_probe.randi_range(0, ids.size() - 1)]
		var picked := rotation.select_event(probe)
		_check(picked.get("ok") == true, "seed %d selects a vitality event" % seed_value)
		_check(picked.get("event", {}).get("id") == oracle_id,
			"seed %d matches the independent oracle" % seed_value)
		_check(probe.state == oracle_probe.state,
			"seed %d ends in the oracle RNG state" % seed_value)


func _test_reordered_catalog() -> void:
	var shipped := RunV3VitalEventRotation.new()
	var reversed_events: Array = source_events.duplicate(true)
	reversed_events.reverse()
	var reversed_snapshot: Array = reversed_events.duplicate(true)
	var reversed := RunV3VitalEventRotation.new({"events": reversed_events})
	_check(reversed.is_catalog_valid(), "a reverse-ordered vitality fixture validates")
	_check(reversed_events == reversed_snapshot,
		"constructing a vitality rotation never mutates the injected catalog")
	_check(reversed.get_vital_event_ids() == shipped.get_vital_event_ids(),
		"JSON order never changes the sorted eligible vitality IDs")
	for seed_value in [7, 99, 424242, 1000003]:
		var first_rng := RandomNumberGenerator.new()
		first_rng.seed = seed_value
		var second_rng := RandomNumberGenerator.new()
		second_rng.seed = seed_value
		var first := shipped.select_event(first_rng)
		var second := reversed.select_event(second_rng)
		_check(first.get("ok") == true and second.get("ok") == true,
			"both vitality orderings select with seed %d" % seed_value)
		_check(first.get("event", {}).get("id") == second.get("event", {}).get("id"),
			"JSON order is not a hidden random input (seed %d)" % seed_value)
		_check(first_rng.state == second_rng.state,
			"JSON order never changes the RNG state (seed %d)" % seed_value)


func _test_exclusions() -> void:
	var rotation := RunV3VitalEventRotation.new()
	var all_ids: Array = rotation.get_vital_event_ids()
	_check(all_ids.size() > 2, "the vitality pool has enough events to exercise exclusions")
	if all_ids.size() <= 2:
		return
	var first_id: String = all_ids[0]
	var last_id: String = all_ids[all_ids.size() - 1]
	var remaining: Array = all_ids.duplicate()
	remaining.erase(first_id)
	remaining.erase(last_id)
	for seed_value in range(11, 21):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var result := rotation.select_event(rng, [first_id, last_id])
		_check(result.get("ok") == true, "a vitality selection with exclusions succeeds")
		var picked_id: Variant = result.get("event", {}).get("id")
		_check(remaining.has(picked_id),
			"exclusions remove exactly the supplied vitality IDs (seed %d)" % seed_value)
		_check(picked_id != first_id and picked_id != last_id,
			"an excluded vitality ID is never selected (seed %d)" % seed_value)
	# A single eligible record still selects with exactly the one documented draw.
	var target_id := "v3_needle_thorn_garden"
	var only_target: Array = all_ids.duplicate()
	only_target.erase(target_id)
	var forced_rng := RandomNumberGenerator.new()
	forced_rng.seed = 31337
	var forced_oracle := RandomNumberGenerator.new()
	forced_oracle.seed = 31337
	forced_oracle.randi_range(0, 0)
	var forced := rotation.select_event(forced_rng, only_target)
	_check(forced.get("ok") == true and forced.get("event", {}).get("id") == target_id,
		"a single eligible vitality event is chosen")
	_check(forced_rng.state == forced_oracle.state,
		"a single eligible vitality event consumes the one documented range draw")
	# Unknown IDs are ignored: they can never enter the pool.
	var unknown_rng := RandomNumberGenerator.new()
	unknown_rng.seed = 555
	var plain_rng := RandomNumberGenerator.new()
	plain_rng.seed = 555
	var with_unknown := rotation.select_event(unknown_rng, ["future_event_not_in_catalog"])
	var plain := rotation.select_event(plain_rng)
	_check(with_unknown.get("event", {}).get("id") == plain.get("event", {}).get("id"),
		"an unknown vitality exclusion is ignored")
	_check(unknown_rng.state == plain_rng.state, "an unknown vitality exclusion does not change the draw")
	# Selection never mutates the caller's exclusion list, accepted or rejected.
	var excluded_input := [first_id, last_id]
	var excluded_snapshot: Array = excluded_input.duplicate(true)
	var accepted_rng := RandomNumberGenerator.new()
	accepted_rng.seed = 808
	var accepted := rotation.select_event(accepted_rng, excluded_input)
	_check(accepted.get("ok") == true and excluded_input == excluded_snapshot,
		"a successful vitality selection never mutates the exclusion list")
	var malformed_input := [first_id, "   "]
	var malformed_snapshot: Array = malformed_input.duplicate(true)
	var malformed_state := accepted_rng.state
	var malformed := rotation.select_event(accepted_rng, malformed_input)
	_check(malformed.get("ok") == false and malformed_input == malformed_snapshot
		and accepted_rng.state == malformed_state,
		"a rejected vitality exclusion list is neither mutated nor drawn from")
	# Exclusion order and duplicates express the same set.
	var order_rng := RandomNumberGenerator.new()
	order_rng.seed = 606
	var duplicate_rng := RandomNumberGenerator.new()
	duplicate_rng.seed = 606
	var ordered := rotation.select_event(order_rng, [first_id, last_id])
	var duplicated := rotation.select_event(duplicate_rng, [last_id, first_id, first_id])
	_check(ordered.get("event", {}).get("id") == duplicated.get("event", {}).get("id"),
		"vitality exclusion order never affects the selection")
	_check(order_rng.state == duplicate_rng.state, "duplicate vitality exclusions never affect the draw")
	# An empty exclusion array selects the whole pool, as an untouched oracle does.
	var empty_rng := RandomNumberGenerator.new()
	empty_rng.seed = 707
	var empty_oracle := RandomNumberGenerator.new()
	empty_oracle.seed = 707
	var expected_empty: Variant = all_ids[empty_oracle.randi_range(0, all_ids.size() - 1)]
	var empty_result := rotation.select_event(empty_rng, [])
	_check(empty_result.get("ok") == true
		and empty_result.get("event", {}).get("id") == expected_empty,
		"an empty vitality exclusion array selects from the whole pool")
	_check(empty_rng.state == empty_oracle.state,
		"an empty vitality exclusion array consumes one draw")
	# Excluding everything rejects without a draw.
	var guard := RandomNumberGenerator.new()
	guard.seed = 909
	var guard_state := guard.state
	var none := rotation.select_event(guard, all_ids)
	_check(none.get("ok") == false, "excluding every vitality event rejects")
	_check((none.get("event") as Dictionary).is_empty(),
		"an exhausted vitality eligible set returns no event")
	_check(guard.state == guard_state, "an exhausted vitality eligible set consumes no RNG")


func _test_invalid_requests() -> void:
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped rotation is valid for invalid-request checks")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234567
	var state_before := rng.state
	var bad_rng_values := [null, 5, 3.5, "rng", {}, [], RefCounted.new()]
	for bad_value in bad_rng_values:
		var result := rotation.select_event(bad_value)
		_check(result.get("ok") == false, "a wrong vitality RNG rejects: " + str(bad_value))
		_check((result.get("event") as Dictionary).is_empty(),
			"a wrong vitality RNG returns no event")
		_check(rng.state == state_before, "a wrong vitality RNG consumes no RNG")
	var bad_exclusions := [
		"v3_needle_thorn_garden", 7, {}, true, [1], [null], [{}], [true], [""], ["   "],
		[["v3_needle_thorn_garden"]],
	]
	for bad_list in bad_exclusions:
		var result := rotation.select_event(rng, bad_list)
		_check(result.get("ok") == false,
			"a malformed vitality exclusion list rejects: " + str(bad_list))
		_check((result.get("event") as Dictionary).is_empty(),
			"a malformed vitality exclusion list returns no event")
		_check(rng.state == state_before,
			"a malformed vitality exclusion list consumes no RNG")
	# Rejections leave the RNG exactly where a clean oracle starts.
	var ids: Array = rotation.get_vital_event_ids()
	var oracle := RandomNumberGenerator.new()
	oracle.seed = 1234567
	var expected_id: Variant = ids[oracle.randi_range(0, ids.size() - 1)]
	var recovered := rotation.select_event(rng)
	_check(recovered.get("ok") == true, "a valid vitality call still works after rejections")
	_check(recovered.get("event", {}).get("id") == expected_id,
		"vitality rejections leave the RNG state untouched")
	_check(rng.state == oracle.state, "vitality rejections and the recovery call match the oracle state")


func _test_invalid_catalogs() -> void:
	var cases: Array = []
	cases.append({"name": "a bare object", "document": {}})
	cases.append({"name": "events is not an array", "document": {"events": "v3_needle_thorn_garden"}})
	cases.append({"name": "an empty events array", "document": {"events": []}})
	cases.append({"name": "a non-object event", "document": {"events": ["v3_needle_thorn_garden"]}})
	cases.append({"name": "a missing required record",
		"document": {"events": _without(source_events, "v3_button_heart_shrine")}})
	var duplicated: Array = source_events.duplicate(true)
	duplicated.append(_record_copy("v3_needle_thorn_garden"))
	cases.append({"name": "a duplicated event ID", "document": {"events": duplicated}})
	var blank_id := _record_copy("v3_needle_thorn_garden")
	blank_id["id"] = "   "
	cases.append({"name": "a blank event ID",
		"document": {"events": _replaced(source_events, "v3_needle_thorn_garden", blank_id)}})
	var missing_id := _record_copy("v3_needle_thorn_garden")
	missing_id.erase("id")
	cases.append({"name": "a record without an ID",
		"document": {"events": _replaced(source_events, "v3_needle_thorn_garden", missing_id)}})
	var blank_title := _record_copy("v3_needle_thorn_garden")
	blank_title["title"] = " "
	cases.append({"name": "a non-presentable record",
		"document": {"events": _replaced(source_events, "v3_needle_thorn_garden", blank_title)}})
	var four_choices := _record_copy("v3_needle_thorn_garden")
	(four_choices["choices"] as Array).append({"id": "extra", "text": "Extra",
		"outcome": {"gold": 0, "scraps": 0, "hp": 0, "max_hp": 0}})
	cases.append({"name": "too many choices",
		"document": {"events": _replaced(source_events, "v3_needle_thorn_garden", four_choices)}})
	var wallet_only := _record_copy("v3_needle_thorn_garden")
	var wallet_choice: Dictionary = (wallet_only["choices"] as Array)[0]
	wallet_choice["outcome"] = {"gold": 0, "scraps": 3}
	cases.append({"name": "a wallet-only outcome",
		"document": {"events": _replaced(source_events, "v3_needle_thorn_garden", wallet_only)}})
	var extra_key := _record_copy("v3_needle_thorn_garden")
	var extra_choice: Dictionary = (extra_key["choices"] as Array)[0]
	extra_choice["outcome"] = {"gold": 0, "scraps": 3, "hp": -6, "max_hp": 0, "curse": 1}
	cases.append({"name": "an extra outcome key",
		"document": {"events": _replaced(source_events, "v3_needle_thorn_garden", extra_key)}})
	var fractional := _record_copy("v3_needle_thorn_garden")
	var fractional_choice: Dictionary = (fractional["choices"] as Array)[0]
	fractional_choice["outcome"] = {"gold": 0, "scraps": 3, "hp": -6.5, "max_hp": 0}
	cases.append({"name": "a fractional outcome amount",
		"document": {"events": _replaced(source_events, "v3_needle_thorn_garden", fractional)}})
	var missing_key := _record_copy("v3_needle_thorn_garden")
	var missing_choice: Dictionary = (missing_key["choices"] as Array)[0]
	missing_choice["outcome"] = {"gold": 0, "scraps": 3, "hp": -6}
	cases.append({"name": "a missing outcome key",
		"document": {"events": _replaced(source_events, "v3_needle_thorn_garden", missing_key)}})
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for entry in cases:
		var state_before := rng.state
		var rotation := RunV3VitalEventRotation.new(entry["document"])
		_check(not rotation.is_catalog_valid(), "catalog fixture rejects: " + entry["name"])
		_check(rotation.get_vital_events().is_empty(),
			"an invalid catalog exposes no vitality pool: " + entry["name"])
		_check(rotation.get_vital_event_ids().is_empty(),
			"an invalid catalog exposes no vitality IDs: " + entry["name"])
		var result := rotation.select_event(rng)
		_check(result.get("ok") == false, "an invalid catalog rejects selection: " + entry["name"])
		_check((result.get("event") as Dictionary).is_empty(),
			"an invalid catalog returns no event: " + entry["name"])
		_check(rng.state == state_before, "an invalid catalog consumes no RNG: " + entry["name"])
	_check(source_document == source_snapshot, "invalid catalog fixtures never mutate the shipped source")


func _test_future_addition() -> void:
	var future := {
		"id": "v3_future_quilt_well",
		"title": "The Future Quilt Well",
		"description": "A well of stitched water waits for a later release.",
		"choices": [
			{"id": "drink", "text": "Drink deep (+4 HP)",
				"outcome": {"gold": 0, "scraps": 0, "hp": 4, "max_hp": 0}},
			{"id": "leave", "text": "Leave the well covered",
				"outcome": {"gold": 0, "scraps": 0, "hp": 0, "max_hp": 0}},
		],
	}
	var events: Array = source_events.duplicate(true)
	events.append(future)
	var rotation := RunV3VitalEventRotation.new({"events": events})
	_check(rotation.is_catalog_valid(), "a well-formed future vitality addition keeps the pool valid")
	_check(_matches(rotation.get_vital_events(), "v3_future_quilt_well").size() == 1,
		"a well-formed future vitality addition joins the pool")
	for source_record in source_events:
		if source_record is Dictionary and source_record.get("id") is String:
			_check(_matches(rotation.get_vital_events(), source_record["id"]).size() == 1,
				"a future addition never drops the authored record: " + source_record["id"])
	var excluded: Array = []
	for event_id in rotation.get_vital_event_ids():
		if event_id != "v3_future_quilt_well":
			excluded.append(event_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var oracle := RandomNumberGenerator.new()
	oracle.seed = 5150
	oracle.randi_range(0, 0)
	var picked := rotation.select_event(rng, excluded)
	_check(picked.get("ok") == true and picked.get("event", {}).get("id") == "v3_future_quilt_well",
		"a future vitality addition is selectable, not only listed")
	_check(rng.state == oracle.state, "a future vitality selection consumes one draw")
	var service := RunEventChoice.new(picked.get("event", {}))
	_check(service.is_valid(), "a selected future vitality record is presentable")
	_check(service.choose_with_vitals("drink", _vital_state(10, 0, 20, 20)).get("ok") == true,
		"a future vitality record settles through RunEventChoice")
	_check(source_document == source_snapshot, "future catalog fixtures never mutate the shipped source")


func _test_vitality_batch() -> void:
	for event_id in VITALITY_BATCH:
		var spec: Dictionary = VITALITY_BATCH[event_id]
		var expected := {"id": event_id, "title": spec["title"],
			"description": spec["description"], "choices": []}
		for row in spec["choices"]:
			expected["choices"].append({"id": row[0], "text": row[1],
				# Godot JSON parses authored numbers as floats; previews below
				# independently require the service's native integer deltas.
				"outcome": {"gold": float(row[2]), "scraps": float(row[3]),
					"hp": float(row[4]), "max_hp": float(row[5])}})
		_check(_matches(source_events, event_id).size() == 1,
			"batch ID occurs exactly once in the shipped source: " + event_id)
		_check(_record_copy(event_id) == expected, "batch authored record is exact: " + event_id)
		var rotation := RunV3VitalEventRotation.new()
		_check(rotation.is_catalog_valid() and rotation.get_vital_event_ids().has(event_id),
			"shipping rotation admits batch ID: " + event_id)
		var record := _force_selected(rotation, event_id, 34201)
		_check(not record.is_empty() and record == expected, "forced batch record is exact: " + event_id)
		if record.is_empty():
			continue
		record["title"] = "MUTATED"
		record["choices"][0]["outcome"]["hp"] = 999
		var replay := _force_selected(rotation, event_id, 34201)
		_check(replay == expected and _record_copy(event_id) == expected,
			"same-seed replay and nested offer detachment: " + event_id)
		record = replay
		var rng := RandomNumberGenerator.new()
		rng.seed = 34202
		var rng_before := rng.state
		for exclusions in [[event_id, null], rotation.get_vital_event_ids()]:
			var before: Array = exclusions.duplicate(true)
			_check(rotation.select_event(rng, exclusions) == {"ok": false, "event": {}},
				"batch malformed/exhausted selection fails closed: " + event_id)
			_check(exclusions == before and rng.state == rng_before,
				"batch selection rejection preserves exclusions and RNG: " + event_id)
		var global_next := _global_rng_start(34203)
		for row in spec["choices"]:
			# Every authored branch, including Leave, gets a fresh one-visit service.
			_batch_success(record, row, _vital_state(40, 5, 20, 30))
			# Full health exercises healing against the projected maximum, maximum
			# reductions clamping current HP, and growth alone granting no healing.
			_batch_success(record, row, _vital_state(40, 5, 30, 30))
			if row[2] < 0:
				_batch_refusal(record, row, _vital_state(0, 5, 20, 30))
			if row[3] < 0:
				_batch_refusal(record, row, _vital_state(40, 0, 20, 30))
			if row[4] < 0:
				_batch_refusal(record, row, _vital_state(40, 5, -int(row[4]), 30))
				_batch_success(record, row, _vital_state(40, 5, 1 - int(row[4]), 30))
			if row[5] < 0:
				_batch_refusal(record, row, _vital_state(40, 5, 10, 10))
				_batch_success(record, row, _vital_state(40, 5, 10, 10 - int(row[5])))
			if row[2] < 0 or row[3] < 0 or row[4] < 0 or row[5] < 0:
				_batch_refusal(record, row, _vital_state(0, 0, 1, 10))
		_check(rng.state == rng_before and randi() == global_next,
			"batch transactions consume neither caller nor global RNG: " + event_id)
		_check(record == expected, "batch transactions preserve the selected record: " + event_id)


func _batch_success(record: Dictionary, row: Array, state: Dictionary) -> void:
	var tag: String = record["id"] + "/" + row[0] + " " + str(state)
	var before := state.duplicate(true)
	var service := RunEventChoice.new(record)
	_check(service.is_valid() and not service.is_claimed(), "fresh batch visit: " + tag)
	var expected := _vital_state(state["gold"] + int(row[2]), state["scraps"] + int(row[3]),
		mini(state["hero"]["hp"] + int(row[4]), state["hero"]["max_hp"] + int(row[5])),
		state["hero"]["max_hp"] + int(row[5]))
	var preview := service.preview_vital_choices(state)
	_check(preview.get("ok") == true and preview.get("event_id") == record["id"]
		and preview.get("choices", []).size() == 3, "batch preview contains all choices: " + tag)
	var entry := _preview_choice(preview, row[0])
	_check(entry == {"choice_id": row[0], "gold_delta": row[2], "scraps_delta": row[3],
		"hp_delta": row[4], "max_hp_delta": row[5], "affordable": true, "state": expected},
		"batch exact independent preview deltas and projection: " + tag)
	_check(service.is_valid() and not service.is_claimed() and state == before,
		"batch preview does not claim or mutate input: " + tag)
	# Mutate a nested forecast before settling to demonstrate detachment.
	if entry.get("state") is Dictionary:
		entry["state"]["hero"]["hp"] = 999
	var receipt := service.choose_with_vitals(row[0], state)
	_check(receipt == {"ok": true, "event_id": record["id"], "choice_id": row[0], "state": expected},
		"batch exact settlement receipt: " + tag)
	_check(state == before and service.is_claimed() and not service.is_valid(),
		"batch settlement preserves input and claims once: " + tag)
	for next_id in [row[0], "leave", record["choices"][0]["id"], record["choices"][1]["id"]]:
		_check(service.choose_with_vitals(next_id, state) ==
			{"ok": false, "event_id": "", "choice_id": "", "state": before},
			"batch repeat and alternate choices cannot settle: " + tag)
	_check(service.preview_vital_choices(state) == DENIED_PREVIEW,
		"batch claimed preview is denied: " + tag)
	if receipt.get("state") is Dictionary:
		receipt["state"]["hero"]["max_hp"] = 999
	_check(state == before, "batch receipt is detached from caller: " + tag)


func _batch_refusal(record: Dictionary, row: Array, state: Dictionary) -> void:
	var tag: String = record["id"] + "/" + row[0] + " " + str(state)
	var before := state.duplicate(true)
	var service := RunEventChoice.new(record)
	_check(service.is_valid(), "batch refusal has a valid authentic visit: " + tag)
	var preview := service.preview_vital_choices(state)
	_check(preview.get("ok") == true, "batch poor living hero can preview: " + tag)
	var entry := _preview_choice(preview, row[0])
	_check(entry == {"choice_id": row[0], "gold_delta": row[2], "scraps_delta": row[3],
		"hp_delta": row[4], "max_hp_delta": row[5], "affordable": false, "state": before},
		"batch unaffordable preview keeps exact deltas and unchanged state: " + tag)
	var refusal := service.choose_with_vitals(row[0], state)
	_check(refusal == {"ok": false, "event_id": "", "choice_id": "", "state": before},
		"batch costly choice refuses atomically: " + tag)
	_check(service.is_valid() and not service.is_claimed() and state == before,
		"batch refusal consumes nothing: " + tag)
	_check(_preview_choice(service.preview_vital_choices(state), "leave").get("affordable") == true,
		"batch free Leave remains available: " + tag)
	_check(service.choose_with_vitals("leave", state) ==
		{"ok": true, "event_id": record["id"], "choice_id": "leave", "state": before},
		"batch Leave settles after refusal: " + tag)
	_check(service.is_claimed() and not service.is_valid() and state == before,
		"batch Leave claims once without changing input: " + tag)
	_check(service.choose_with_vitals("leave", state) ==
		{"ok": false, "event_id": "", "choice_id": "", "state": before},
		"batch poor Leave cannot repeat: " + tag)


func _test_needle_thorn_garden_settlement() -> void:
	var rotation := RunV3VitalEventRotation.new()
	var record := _force_selected(rotation, "v3_needle_thorn_garden", 31801)
	_check(record == source_by_id.get("v3_needle_thorn_garden", {}),
		"the forced Needle-Thorn Garden record matches the authored source")
	if record.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var rng_state := rng.state
	var global_state := _global_rng_start(73000)
	# Harvest: 6 current HP for 3 scraps, with a preview/commit agreement.
	var state := _vital_state(40, 0, 20, 40)
	var state_before := state.duplicate(true)
	var service := RunEventChoice.new(record)
	var preview := service.preview_vital_choices(state)
	_check(preview.get("ok") == true and preview.get("event_id") == "v3_needle_thorn_garden",
		"Needle-Thorn Garden previews its vitality choices")
	var entry := _preview_choice(preview, "harvest_thorns")
	_check(entry.size() == 7, "the harvest preview carries seven fields")
	_check(entry.get("gold_delta") == 0 and entry.get("scraps_delta") == 3
		and entry.get("hp_delta") == -6 and entry.get("max_hp_delta") == 0,
		"the harvest preview reports the authored deltas")
	_check(entry.get("affordable") == true
		and _vital_state_is(entry.get("state"), 40, 3, 14, 40),
		"the funded harvest preview projects 3 scraps and 14 HP")
	_check(state == state_before, "the harvest preview leaves the caller snapshot unchanged")
	_check(service.is_valid() and not service.is_claimed(),
		"the harvest preview leaves the visit open")
	_check(rng.state == rng_state, "the harvest preview spends no seed")
	var receipt := service.choose_with_vitals("harvest_thorns", state)
	_check(receipt.size() == 4 and receipt.get("ok") == true
		and receipt.get("event_id") == "v3_needle_thorn_garden"
		and receipt.get("choice_id") == "harvest_thorns",
		"the harvest claim names the authored event and choice")
	_check(_vital_state_is(receipt.get("state"), 40, 3, 14, 40),
		"the harvest claim costs 6 HP and grants 3 scraps")
	_check(receipt.get("state") == entry.get("state"),
		"the harvest commit matches its preview forecast")
	_check(state == state_before, "the harvest claim leaves the caller snapshot unchanged")
	_check(service.is_claimed() and not service.is_valid(),
		"the harvest claim latches the one-visit receipt")
	_check(rng.state == rng_state, "the harvest claim spends no seed")
	_check(service.preview_vital_choices(state) == DENIED_PREVIEW,
		"a consumed vitality visit refuses a second preview")
	var replay_state := _vital_state(40, 0, 20, 40)
	var replay := service.choose_with_vitals("harvest_thorns", replay_state)
	_check(replay.get("ok") == false and replay.get("event_id") == ""
		and replay.get("choice_id") == "" and replay.get("state") == replay_state,
		"the harvest receipt cannot be replayed")
	_check(service.is_claimed() and rng.state == rng_state,
		"a harvest replay consumes no second receipt and no seed")
	# A 6-HP debit must leave at least 1 HP: 6 HP refuses, 7 HP leaves exactly 1.
	var edge := RunEventChoice.new(record)
	var edge_state := _vital_state(40, 0, 6, 40)
	var edge_before := edge_state.duplicate(true)
	var edge_preview := edge.preview_vital_choices(edge_state)
	var edge_entry := _preview_choice(edge_preview, "harvest_thorns")
	_check(edge_entry.get("affordable") == false and edge_entry.get("state") == edge_before,
		"the harvest is unaffordable at 6 HP")
	var refusal := edge.choose_with_vitals("harvest_thorns", edge_state)
	_check(refusal.size() == 4 and refusal.get("ok") == false
		and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
		and refusal.get("state") == edge_before,
		"the harvest is refused with an unchanged detached snapshot at 6 HP")
	_check(edge_state == edge_before and edge.is_valid() and not edge.is_claimed(),
		"the 6-HP refusal preserves the visit and the caller state")
	_check(rng.state == rng_state, "the 6-HP refusal spends no seed")
	var exact := edge.choose_with_vitals("harvest_thorns", _vital_state(40, 0, 7, 40))
	_check(exact.get("ok") == true and _vital_state_is(exact.get("state"), 40, 3, 1, 40),
		"the 7-HP harvest settles at the 1-HP floor")
	_check(edge.is_claimed() and rng.state == rng_state,
		"the 1-HP harvest latches once and spends no seed")
	# Rose balm: 10 gold for 6 HP, capped at max HP.
	var balm := RunEventChoice.new(record)
	var balm_state := _vital_state(10, 0, 39, 40)
	var balm_before := balm_state.duplicate(true)
	var balm_preview := balm.preview_vital_choices(balm_state)
	var balm_entry := _preview_choice(balm_preview, "buy_rose_balm")
	_check(balm_entry.get("affordable") == true
		and _vital_state_is(balm_entry.get("state"), 0, 0, 40, 40),
		"rose balm forecasts its gold cost and the healing cap")
	var balm_receipt := balm.choose_with_vitals("buy_rose_balm", balm_state)
	_check(balm_receipt.get("ok") == true
		and balm_receipt.get("state") == balm_entry.get("state")
		and _vital_state_is(balm_receipt.get("state"), 0, 0, 40, 40),
		"rose balm commits the previewed capped healing")
	_check(balm_state == balm_before and balm.is_claimed() and rng.state == rng_state,
		"rose balm preserves the caller state, latches once and spends no seed")
	var poor := RunEventChoice.new(record)
	var poor_state := _vital_state(9, 0, 20, 40)
	var poor_before := poor_state.duplicate(true)
	var poor_entry := _preview_choice(poor.preview_vital_choices(poor_state), "buy_rose_balm")
	_check(poor_entry.get("affordable") == false and poor_entry.get("state") == poor_before,
		"rose balm is unaffordable at 9 gold")
	var poor_refusal := poor.choose_with_vitals("buy_rose_balm", poor_state)
	_check(poor_refusal.get("ok") == false and poor_refusal.get("state") == poor_before
		and poor_state == poor_before and poor.is_valid() and not poor.is_claimed(),
		"the 9-gold rose balm refusal preserves the wallet and the visit")
	var left := poor.choose_with_vitals("leave", poor_state)
	_check(left.get("ok") == true and left.get("state") == poor_before
		and poor.is_claimed(),
		"free leave still settles after a rose balm refusal")
	_check(rng.state == rng_state, "Needle-Thorn Garden settlement spends no seed")
	_check(randi() == global_state, "Needle-Thorn Garden settlement spends no global RNG")


func _test_button_heart_shrine_settlement() -> void:
	var rotation := RunV3VitalEventRotation.new()
	var record := _force_selected(rotation, "v3_button_heart_shrine", 31803)
	_check(record == source_by_id.get("v3_button_heart_shrine", {}),
		"the forced Button-Heart Shrine record matches the authored source")
	if record.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9002
	var rng_state := rng.state
	var global_state := _global_rng_start(73001)
	# Reinforcement: 2 scraps for +3 max HP, with no free current-HP healing.
	var state := _vital_state(40, 2, 20, 40)
	var state_before := state.duplicate(true)
	var service := RunEventChoice.new(record)
	var preview := service.preview_vital_choices(state)
	var entry := _preview_choice(preview, "reinforce_heart")
	_check(entry.get("gold_delta") == 0 and entry.get("scraps_delta") == -2
		and entry.get("hp_delta") == 0 and entry.get("max_hp_delta") == 3,
		"reinforcement previews its authored deltas")
	_check(entry.get("affordable") == true
		and _vital_state_is(entry.get("state"), 40, 0, 20, 43),
		"reinforcement spends 2 scraps and adds 3 max HP without healing current HP")
	var receipt := service.choose_with_vitals("reinforce_heart", state)
	_check(receipt.get("ok") == true and receipt.get("event_id") == "v3_button_heart_shrine"
		and receipt.get("choice_id") == "reinforce_heart",
		"reinforcement claims the authored event and choice")
	_check(_vital_state_is(receipt.get("state"), 40, 0, 20, 43),
		"the reinforcement settlement leaves current HP unchanged")
	_check(receipt.get("state") == entry.get("state"),
		"the reinforcement commit matches its preview forecast")
	_check(state == state_before and service.is_claimed() and rng.state == rng_state,
		"reinforcement preserves the caller state, latches once and spends no seed")
	var replay := service.choose_with_vitals("reinforce_heart", state)
	_check(replay.get("ok") == false and replay.get("state") == state_before
		and service.is_claimed(),
		"the reinforcement receipt cannot be replayed")
	# A max-HP increase alone must never top up current HP: 40/40 becomes 40/43.
	var full := RunEventChoice.new(record)
	var full_receipt := full.choose_with_vitals("reinforce_heart", _vital_state(0, 2, 40, 40))
	_check(full_receipt.get("ok") == true
		and _vital_state_is(full_receipt.get("state"), 0, 0, 40, 43),
		"a max-HP increase never heals a full-health hero")
	# Insufficient scraps refuses without consuming the visit, then leave still works.
	var poor := RunEventChoice.new(record)
	var poor_state := _vital_state(40, 1, 20, 40)
	var poor_before := poor_state.duplicate(true)
	var poor_entry := _preview_choice(poor.preview_vital_choices(poor_state), "reinforce_heart")
	_check(poor_entry.get("affordable") == false and poor_entry.get("state") == poor_before,
		"reinforcement is unaffordable with 1 scrap")
	var refusal := poor.choose_with_vitals("reinforce_heart", poor_state)
	_check(refusal.get("ok") == false and refusal.get("state") == poor_before
		and poor_state == poor_before and poor.is_valid() and not poor.is_claimed(),
		"the 1-scrap reinforcement refusal preserves the wallet and the visit")
	var left := poor.choose_with_vitals("leave", poor_state)
	_check(left.get("ok") == true and left.get("state") == poor_before
		and poor.is_claimed(),
		"free leave still settles after a reinforcement refusal")
	# Surrender: +24 gold for -2 max HP, clamping current HP to the new maximum.
	var surrender := RunEventChoice.new(record)
	var cut_state := _vital_state(0, 0, 40, 40)
	var cut_preview := _preview_choice(surrender.preview_vital_choices(cut_state), "surrender_button")
	_check(cut_preview.get("affordable") == true
		and _vital_state_is(cut_preview.get("state"), 24, 0, 38, 38),
		"surrender previews the max-HP cut and the current-HP clamp")
	var cut := surrender.choose_with_vitals("surrender_button", cut_state)
	_check(cut.get("ok") == true and cut.get("state") == cut_preview.get("state")
		and _vital_state_is(cut.get("state"), 24, 0, 38, 38),
		"the surrender commit matches its preview")
	var below_max := RunEventChoice.new(record)
	var below := below_max.choose_with_vitals("surrender_button", _vital_state(0, 0, 10, 40))
	_check(below.get("ok") == true and _vital_state_is(below.get("state"), 24, 0, 10, 38),
		"a below-max hero keeps current HP through the surrender")
	# The 10 max-HP floor refuses: 11 - 2 would be 9.
	var floor := RunEventChoice.new(record)
	var floor_state := _vital_state(0, 0, 11, 11)
	var floor_before := floor_state.duplicate(true)
	var floor_entry := _preview_choice(floor.preview_vital_choices(floor_state), "surrender_button")
	_check(floor_entry.get("affordable") == false and floor_entry.get("state") == floor_before,
		"surrender is unaffordable when it would take max HP below 10")
	var floor_refusal := floor.choose_with_vitals("surrender_button", floor_state)
	_check(floor_refusal.get("ok") == false and floor_refusal.get("state") == floor_before
		and floor_state == floor_before and floor.is_valid() and not floor.is_claimed(),
		"the max-HP floor refusal preserves the state and the visit")
	var at_floor := RunEventChoice.new(record)
	var at_floor_receipt := at_floor.choose_with_vitals("surrender_button", _vital_state(0, 0, 12, 12))
	_check(at_floor_receipt.get("ok") == true
		and _vital_state_is(at_floor_receipt.get("state"), 24, 0, 10, 10),
		"surrender is allowed exactly down to 10 max HP")
	_check(rng.state == rng_state, "Button-Heart Shrine settlement spends no seed")
	_check(randi() == global_state, "Button-Heart Shrine settlement spends no global RNG")


func _test_infirmary_and_shared_validation() -> void:
	var rotation := RunV3VitalEventRotation.new()
	var record := _force_selected(rotation, "v3_lantern_quilt_infirmary", 31804)
	_check(record == source_by_id.get("v3_lantern_quilt_infirmary", {}),
		"the forced Lantern-Quilt Infirmary record matches the authored source")
	if record.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9003
	var rng_state := rng.state
	var global_state := _global_rng_start(73002)
	# Buy bandages costs 12 gold for +8 HP, capped at max HP.
	var service := RunEventChoice.new(record)
	var state := _vital_state(12, 0, 35, 40)
	var state_before := state.duplicate(true)
	var preview := _preview_choice(service.preview_vital_choices(state), "buy_bandages")
	_check(preview.get("affordable") == true
		and _vital_state_is(preview.get("state"), 0, 0, 40, 40),
		"bandages forecast the authored gold cost and healing cap")
	var receipt := service.choose_with_vitals("buy_bandages", state)
	_check(receipt.get("ok") == true and receipt.get("state") == preview.get("state")
		and _vital_state_is(receipt.get("state"), 0, 0, 40, 40),
		"bandages commit the previewed capped healing")
	_check(state == state_before and service.is_claimed() and rng.state == rng_state,
		"bandages preserve the caller state, latch once and spend no seed")
	# A gold debit at 11 gold is refused without consuming the visit.
	var poor := RunEventChoice.new(record)
	var poor_state := _vital_state(11, 0, 20, 40)
	var poor_before := poor_state.duplicate(true)
	var poor_preview := _preview_choice(poor.preview_vital_choices(poor_state), "buy_bandages")
	_check(poor_preview.get("affordable") == false and poor_preview.get("state") == poor_before,
		"bandages are unaffordable at 11 gold")
	var refusal := poor.choose_with_vitals("buy_bandages", poor_state)
	_check(refusal.get("ok") == false and refusal.get("state") == poor_before
		and poor_state == poor_before and poor.is_valid() and not poor.is_claimed(),
		"the 11-gold bandage refusal preserves the wallet and the visit")
	var left := poor.choose_with_vitals("leave", poor_state)
	_check(left.get("ok") == true and left.get("state") == poor_before,
		"free leave still settles after a bandage refusal")
	# blood_receipt costs 4 current HP and must leave at least 1.
	var blood := RunEventChoice.new(record)
	var edge_state := _vital_state(40, 0, 4, 40)
	var edge_before := edge_state.duplicate(true)
	var edge_refusal := blood.choose_with_vitals("blood_receipt", edge_state)
	_check(edge_refusal.get("ok") == false and edge_refusal.get("state") == edge_before
		and edge_state == edge_before and blood.is_valid() and not blood.is_claimed(),
		"a 4-HP blood donation is refused at 4 HP")
	var edge := blood.choose_with_vitals("blood_receipt", _vital_state(40, 0, 5, 40))
	_check(edge.get("ok") == true and _vital_state_is(edge.get("state"), 58, 0, 1, 40),
		"a 4-HP blood donation at 5 HP leaves exactly 1 HP")
	# Existing snapshot validation is unchanged: a Torn hero and extra keys fail closed.
	var torn := RunEventChoice.new(record)
	var torn_state := _vital_state(40, 0, 0, 40)
	var torn_before := torn_state.duplicate(true)
	_check(torn.preview_vital_choices(torn_state) == DENIED_PREVIEW,
		"a Torn hero snapshot is denied by the vitality preview")
	var torn_claim := torn.choose_with_vitals("leave", torn_state)
	_check(torn_claim.get("ok") == false and torn_claim.get("state") == {}
		and torn_state == torn_before and torn.is_valid() and not torn.is_claimed(),
		"a Torn hero claim fails closed without consuming the visit")
	var extra := RunEventChoice.new(record)
	var extra_state := _vital_state(40, 0, 20, 40)
	extra_state["bonus"] = 1
	var extra_before := extra_state.duplicate(true)
	_check(extra.preview_vital_choices(extra_state) == DENIED_PREVIEW,
		"an extra snapshot key is denied by the vitality preview")
	var extra_claim := extra.choose_with_vitals("leave", extra_state)
	_check(extra_claim.get("ok") == false and extra_claim.get("state") == {}
		and extra_state == extra_before,
		"an extra snapshot key is denied by the vitality commit")
	_check(rng.state == rng_state, "Infirmary and shared snapshot checks spend no seed")
	_check(randi() == global_state, "Infirmary and shared snapshot checks spend no global RNG")
