extends SceneTree
## Deterministic headless contract test for the optional Steeper Quilt tiers.
## Loads the shipped res://data/difficulty/quilt_tiers.json, checks each tier by
## ID and its whole-integer fields, the 0 -> 1 -> 2 unlock predecessors, the
## tier-0 baseline modifiers and the declared ceiling max-HP rounding policy.
## A shared validator then proves that missing, duplicated or extra tiers and
## non-integer or negative modifiers are rejected. This preparatory slice owns
## only the data contract: no runtime scaler, save or presentation is exercised.
## Godot's JSON parser yields a float for every JSON number, so the contract
## requires integral values (no fractional part) and the fixtures prove that
## fractional, string, boolean and null modifiers fail closed.
## Exits 0 on pass and 1 on failure.

const TIERS_PATH := "res://data/difficulty/quilt_tiers.json"
const DOCUMENT_ID := "steeper_quilt"

## Independent copy of the authored tier IDs, never read from the resource.
const REQUIRED_TIER_IDS: Array[int] = [0, 1, 2]

## The one record shape later consumers may rely on.
const TIER_FIELDS: Array[String] = [
	"tier",
	"max_hp_percent_bonus",
	"attack_intent_bonus",
	"requires_cleared_tier",
]

## Authored numbers checked against the design contract, not the file.
## tier id -> [max-HP percentage bonus, flat attack-intent bonus]
const EXPECTED_MODIFIERS := {
	0: [0, 0],
	1: [10, 1],
	2: [20, 2],
}

var failures: Array[String] = []
var checks: int = 0
var source_document: Dictionary = {}
var source_snapshot: Dictionary = {}


func _initialize() -> void:
	_load_source()
	if source_document.is_empty():
		_report()
		return
	_test_document_contract()
	_test_authored_tiers()
	_test_unlock_chain()
	_test_rounding_policy()
	_test_validator_accepts_shipped_table()
	_test_validator_rejects_broken_tables()
	_test_service_contract()
	_check(source_document == source_snapshot, "no validation flow mutates the shipped tiers document")
	_report()


func _report() -> void:
	for failure: String in failures:
		printerr(failure)
	print("mpw_quilt_tiers_data_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## A whole JSON number. The parser hands every number back as a float, so an
## authored integer is a finite float with no fractional part.
func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return is_finite(value) and floor(value) == value
	return false


func _load_source() -> void:
	var raw := FileAccess.get_file_as_string(TIERS_PATH)
	_check(not raw.is_empty(), "shipped quilt tiers resource exists and is non-empty: " + TIERS_PATH)
	if raw.is_empty():
		return
	var parser := JSON.new()
	_check(parser.parse(raw) == OK, "shipped quilt tiers resource parses through JSON")
	_check(parser.data is Dictionary, "the quilt tiers resource is a JSON object")
	if not parser.data is Dictionary:
		return
	source_document = (parser.data as Dictionary).duplicate(true)
	source_snapshot = source_document.duplicate(true)


func _tier_matches(tiers: Array, tier_id: int) -> Array:
	var found: Array = []
	for raw: Variant in tiers:
		if not raw is Dictionary:
			continue
		var value: Variant = (raw as Dictionary).get("tier")
		if _is_integer_number(value) and int(value) == tier_id:
			found.append(raw)
	return found


func _test_document_contract() -> void:
	_check(source_document.get("id") == DOCUMENT_ID, "the document is the authored Steeper Quilt catalog")
	var tiers: Variant = source_document.get("tiers")
	_check(tiers is Array, "the document declares a tiers array")
	if not tiers is Array:
		return
	var listing: Array = tiers
	_check(not listing.is_empty(), "the tiers array is not empty")
	for tier_id: int in REQUIRED_TIER_IDS:
		_check(_tier_matches(listing, tier_id).size() == 1,
			"exactly one authored record for tier %d" % tier_id)
	var extra_ids: Array = []
	for raw: Variant in listing:
		if not raw is Dictionary:
			continue
		var value: Variant = (raw as Dictionary).get("tier")
		if not _is_integer_number(value) or not REQUIRED_TIER_IDS.has(int(value)):
			extra_ids.append(value)
	_check(extra_ids.is_empty(), "no extra tier IDs beyond 0, 1 and 2: " + str(extra_ids))


func _test_authored_tiers() -> void:
	var listing: Array = source_document.get("tiers", [])
	for tier_id: int in REQUIRED_TIER_IDS:
		var matches := _tier_matches(listing, tier_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var missing: Array[String] = []
		for field: String in TIER_FIELDS:
			if not record.has(field):
				missing.append(field)
		_check(missing.is_empty(), "tier %d declares every typed field (missing %s)" % [tier_id, str(missing)])
		_check(record.size() == TIER_FIELDS.size(),
			"tier %d declares only the four contract fields" % tier_id)

		var hp_bonus: Variant = record.get("max_hp_percent_bonus")
		var intent_bonus: Variant = record.get("attack_intent_bonus")
		var hp_ok := _is_integer_number(hp_bonus)
		var intent_ok := _is_integer_number(intent_bonus)
		_check(hp_ok, "tier %d max_hp_percent_bonus is a whole integer" % tier_id)
		_check(intent_ok, "tier %d attack_intent_bonus is a whole integer" % tier_id)
		if not (hp_ok and intent_ok):
			continue
		var expected: Array = EXPECTED_MODIFIERS[tier_id]
		_check(int(hp_bonus) == int(expected[0]),
			"tier %d adds %d%% enemy max HP (authored %s)" % [tier_id, int(expected[0]), str(hp_bonus)])
		_check(int(intent_bonus) == int(expected[1]),
			"tier %d adds %d attack-intent damage (authored %s)"
				% [tier_id, int(expected[1]), str(intent_bonus)])
		_check(int(hp_bonus) >= 0 and int(intent_bonus) >= 0,
			"tier %d modifiers are non-negative" % tier_id)
		if tier_id == 0:
			_check(int(hp_bonus) == 0 and int(intent_bonus) == 0,
				"tier 0 keeps the unmodified BAL baseline")


func _test_unlock_chain() -> void:
	var listing: Array = source_document.get("tiers", [])
	for tier_id: int in REQUIRED_TIER_IDS:
		var matches := _tier_matches(listing, tier_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.has("requires_cleared_tier"),
			"tier %d declares the preceding cleared tier" % tier_id)
		if not record.has("requires_cleared_tier"):
			continue
		var requires: Variant = record["requires_cleared_tier"]
		if tier_id == 0:
			_check(requires == null, "tier 0 is available by default with no predecessor")
		else:
			_check(_is_integer_number(requires) and int(requires) == tier_id - 1,
				"tier %d requires a tier-%d victory" % [tier_id, tier_id - 1])
			_check(_is_integer_number(requires)
				and _tier_matches(listing, int(requires)).size() == 1,
				"tier %d predecessor names exactly one authored earlier tier" % tier_id)


func _test_rounding_policy() -> void:
	_check(source_document.get("max_hp_rounding") == "ceil",
		"the resource declares the ceiling max-HP rounding policy")
	var rule := String(source_document.get("max_hp_rounding_rule", "")).to_lower()
	_check(rule.contains("ceil"), "the rounding rule states the ceiling operation")
	_check(rule.contains("max_hp") and rule.contains("100"),
		"the rounding rule states the percentage formula it rounds")


# --- The single contract validator later consumers can share. ----------------

## An authored whole-number field; appends a problem and returns null when the
## field is missing or is not a finite whole number (fractional, text, bool).
func _integer_field(record: Dictionary, field: String, label: String,
		problems: Array[String]) -> Variant:
	if not record.has(field):
		problems.append(label + " is missing " + field)
		return null
	var value: Variant = record[field]
	if not _is_integer_number(value):
		problems.append(label + " " + field + " must be a whole integer")
		return null
	return int(value)


## Every rule this preparatory slice promises: the exact tier set, the four
## typed fields, non-negative whole-number modifiers, the default tier 0
## baseline, the 0 -> 1 -> 2 predecessor chain and the ceiling HP policy.
func _validate_catalog(document: Variant) -> Array[String]:
	var problems: Array[String] = []
	if not document is Dictionary:
		problems.append("the quilt tier catalog must be a JSON object")
		return problems
	var catalog: Dictionary = document
	if String(catalog.get("id", "")) != DOCUMENT_ID:
		problems.append("the catalog id must be " + DOCUMENT_ID)
	if String(catalog.get("max_hp_rounding", "")) != "ceil":
		problems.append("the catalog must declare max_hp_rounding ceil")
	var rule := String(catalog.get("max_hp_rounding_rule", "")).to_lower()
	if not rule.contains("ceil") or not rule.contains("max_hp"):
		problems.append("the catalog must state the ceiling max-HP rounding rule")

	var raw_tiers: Variant = catalog.get("tiers")
	if not raw_tiers is Array:
		problems.append("the catalog must declare a tiers array")
		return problems
	var listing: Array = raw_tiers
	var seen: Dictionary = {}
	for index in range(listing.size()):
		var raw: Variant = listing[index]
		var label := "tiers[%d]" % index
		if not raw is Dictionary:
			problems.append(label + " must be an object")
			continue
		var record: Dictionary = raw
		var tier_value: Variant = _integer_field(record, "tier", label, problems)
		var hp_value: Variant = _integer_field(record, "max_hp_percent_bonus", label, problems)
		var intent_value: Variant = _integer_field(record, "attack_intent_bonus", label, problems)
		var missing: Array[String] = []
		for field: String in TIER_FIELDS:
			if not record.has(field):
				missing.append(field)
		if not missing.is_empty() or record.size() != TIER_FIELDS.size():
			problems.append(label + " must declare exactly the four tier fields")
		if tier_value == null or hp_value == null or intent_value == null:
			continue

		var tier_id := int(tier_value)
		var hp_bonus := int(hp_value)
		var intent_bonus := int(intent_value)
		if tier_id < 0:
			problems.append(label + " tier must not be negative")
		if seen.has(tier_id):
			problems.append(label + " duplicates tier id " + str(tier_id))
		else:
			seen[tier_id] = true
		if hp_bonus < 0:
			problems.append(label + " max_hp_percent_bonus must not be negative")
		if intent_bonus < 0:
			problems.append(label + " attack_intent_bonus must not be negative")

		if not record.has("requires_cleared_tier"):
			problems.append(label + " must declare requires_cleared_tier")
			continue
		var requires: Variant = record["requires_cleared_tier"]
		if tier_id == 0:
			if requires != null:
				problems.append(label + " tier 0 must unlock by default")
			if hp_bonus != 0 or intent_bonus != 0:
				problems.append(label + " tier 0 must keep the zero baseline modifiers")
		else:
			if not _is_integer_number(requires):
				problems.append(label + " requires_cleared_tier must be a whole integer")
			elif int(requires) != tier_id - 1:
				problems.append(label + " must require cleared tier " + str(tier_id - 1))

	for tier_id: int in REQUIRED_TIER_IDS:
		if not seen.has(tier_id):
			problems.append("missing tier id " + str(tier_id))
	for tier_id: Variant in seen:
		if not REQUIRED_TIER_IDS.has(int(tier_id)):
			problems.append("unexpected tier id " + str(tier_id))
	return problems


func _test_validator_accepts_shipped_table() -> void:
	var problems := _validate_catalog(source_document)
	_check(problems.is_empty(), "the shared validator accepts the shipped authored table: " + str(problems))


func _case_document() -> Dictionary:
	return source_document.duplicate(true)


func _drop_tier(document: Dictionary, tier_id: int) -> Dictionary:
	var kept: Array = []
	for raw: Variant in document.get("tiers", []):
		if raw is Dictionary and _is_integer_number((raw as Dictionary).get("tier")) \
				and int((raw as Dictionary).get("tier")) == tier_id:
			continue
		kept.append(raw)
	document["tiers"] = kept
	return document


## The single authored record for a tier inside a detached fixture.
func _fixture_tier(document: Dictionary, tier_id: int) -> Dictionary:
	for raw: Variant in document.get("tiers", []):
		if not raw is Dictionary:
			continue
		var value: Variant = (raw as Dictionary).get("tier")
		if _is_integer_number(value) and int(value) == tier_id:
			return raw
	return {}


## Mutates a detached fixture in place (Dictionary is a reference type); the
## _rejected check proves the fixture really differs from the shipped table.
func _set_fixture_field(document: Dictionary, tier_id: int, field: String, value: Variant) -> void:
	var record := _fixture_tier(document, tier_id)
	record[field] = value


func _rejected(document: Variant, label: String) -> void:
	var problems := _validate_catalog(document)
	_check(not problems.is_empty(), "the validator rejects " + label)
	if document is Dictionary:
		_check(document != source_document, "the fixture for " + label + " really differs from the shipped table")


func _test_validator_rejects_broken_tables() -> void:
	# Absent, duplicated and extra tiers.
	var missing := _drop_tier(_case_document(), 2)
	_rejected(missing, "a missing tier 2")
	var duplicate := _case_document()
	var duplicated_record := _fixture_tier(duplicate, 1).duplicate(true)
	(duplicate["tiers"] as Array).append(duplicated_record)
	_rejected(duplicate, "a duplicated tier 1")
	var extra := _case_document()
	var extra_record := _fixture_tier(extra, 2).duplicate(true)
	extra_record["tier"] = 3
	extra_record["requires_cleared_tier"] = 2
	(extra["tiers"] as Array).append(extra_record)
	_rejected(extra, "an extra tier 3")

	# Non-integer and negative modifiers.
	var fractional_hp := _case_document()
	_set_fixture_field(fractional_hp, 1, "max_hp_percent_bonus", 10.5)
	_rejected(fractional_hp, "a fractional max-HP percentage")
	var fractional_intent := _case_document()
	_set_fixture_field(fractional_intent, 1, "attack_intent_bonus", 1.5)
	_rejected(fractional_intent, "a fractional attack-intent bonus")
	var text_modifier := _case_document()
	_set_fixture_field(text_modifier, 1, "max_hp_percent_bonus", "10")
	_rejected(text_modifier, "a text max-HP percentage")
	var bool_modifier := _case_document()
	_set_fixture_field(bool_modifier, 2, "attack_intent_bonus", true)
	_rejected(bool_modifier, "a boolean attack-intent bonus")
	var null_modifier := _case_document()
	_set_fixture_field(null_modifier, 2, "max_hp_percent_bonus", null)
	_rejected(null_modifier, "a null max-HP percentage")
	var negative_hp := _case_document()
	_set_fixture_field(negative_hp, 1, "max_hp_percent_bonus", -10)
	_rejected(negative_hp, "a negative max-HP percentage")
	var negative_intent := _case_document()
	_set_fixture_field(negative_intent, 2, "attack_intent_bonus", -2)
	_rejected(negative_intent, "a negative attack-intent bonus")

	# Malformed record shape.
	var missing_field := _case_document()
	_fixture_tier(missing_field, 1).erase("attack_intent_bonus")
	_rejected(missing_field, "a tier without its attack-intent field")
	var extra_field := _case_document()
	_set_fixture_field(extra_field, 1, "max_hp_flat_bonus", 1)
	_rejected(extra_field, "a tier with an untyped extra field")
	var text_tier_id := _case_document()
	_set_fixture_field(text_tier_id, 2, "tier", "2")
	_rejected(text_tier_id, "a text tier ID")
	var negative_tier_id := _case_document()
	_set_fixture_field(negative_tier_id, 2, "tier", -1)
	_rejected(negative_tier_id, "a negative tier ID")

	# Broken unlock predecessors and a non-baseline tier 0.
	var wrong_predecessor := _case_document()
	_set_fixture_field(wrong_predecessor, 2, "requires_cleared_tier", 0)
	_rejected(wrong_predecessor, "a tier 2 that skips tier 1")
	var free_tier_one := _case_document()
	_set_fixture_field(free_tier_one, 1, "requires_cleared_tier", null)
	_rejected(free_tier_one, "a tier 1 without a predecessor")
	var locked_tier_zero := _case_document()
	_set_fixture_field(locked_tier_zero, 0, "requires_cleared_tier", 1)
	_rejected(locked_tier_zero, "a tier 0 locked behind a victory")
	var text_predecessor := _case_document()
	_set_fixture_field(text_predecessor, 1, "requires_cleared_tier", "0")
	_rejected(text_predecessor, "a text predecessor")
	var steeper_tier_zero := _case_document()
	_set_fixture_field(steeper_tier_zero, 0, "max_hp_percent_bonus", 10)
	_rejected(steeper_tier_zero, "a tier 0 that alters the baseline")

	# Broken catalog envelope and rounding declaration.
	var no_rounding := _case_document()
	no_rounding.erase("max_hp_rounding")
	_rejected(no_rounding, "a catalog without the rounding policy")
	var round_rounding := _case_document()
	round_rounding["max_hp_rounding"] = "round"
	_rejected(round_rounding, "a non-ceiling rounding policy")
	var no_rounding_rule := _case_document()
	no_rounding_rule.erase("max_hp_rounding_rule")
	_rejected(no_rounding_rule, "a catalog without the rounding rule text")
	var non_array_tiers := _case_document()
	non_array_tiers["tiers"] = {}
	_rejected(non_array_tiers, "a non-array tiers field")
	var non_object_record := _case_document()
	(non_object_record["tiers"] as Array).append("tier 3")
	_rejected(non_object_record, "a non-object tier record")
	_rejected("not a catalog", "a non-object document")

func _test_service_contract() -> void:
	var service := RunDifficulty.new()

	# AC1: fresh state defaults and only tier 0 available.
	var state := service.get_state()
	_check(state.get("highest_cleared_tier") == -1, "service default highest_cleared_tier is -1")
	_check(state.get("selected_tier") == 0, "service default selected_tier is 0")
	var available := service.get_available_tiers()
	_check(available.has(0), "tier 0 available on fresh state")
	_check(not available.has(1), "tier 1 not available initially")
	_check(not available.has(2), "tier 2 not available initially")

	# Refuse unearned tier selection.
	_check(service.select_tier(1) == false, "select_tier(1) refused on fresh state")
	_check(service.select_tier(2) == false, "select_tier(2) refused on fresh state")
	_check(service.get_selected_tier() == 0, "selection unchanged after refused choices")

	# Modifier lookup for tier 0.
	var mods0 := service.get_modifiers()
	_check(mods0.get("max_hp_percent_bonus") == 0, "tier 0 modifier max_hp_percent_bonus is 0")
	_check(mods0.get("attack_intent_bonus") == 0, "tier 0 modifier attack_intent_bonus is 0")

	# AC2: positive progression through wins.
	_check(service.select_tier(0) == true, "select_tier(0) accepted")
	_check(service.complete_run(true) == true, "win on selected tier 0 succeeds")
	_check(service.get_highest_cleared_tier() == 0, "highest_cleared_tier advances to 0 after win")

	# After clearing 0, tier 1 unlocks; tier 2 remains locked.
	available = service.get_available_tiers()
	_check(available.has(0), "tier 0 still available after win")
	_check(available.has(1), "tier 1 available after clearing 0")
	_check(not available.has(2), "tier 2 still locked after only tier 0 cleared")

	# Select tier 1, win again.
	_check(service.select_tier(1) == true, "select_tier(1) accepted after unlock")
	_check(service.complete_run(true) == true, "win on selected tier 1 succeeds")
	_check(service.get_highest_cleared_tier() == 1, "highest_cleared_tier advances to 1")

	# After clearing 1, tier 2 unlocks.
	available = service.get_available_tiers()
	_check(available.has(2), "tier 2 available after clearing 1")

	_check(service.select_tier(2) == true, "select_tier(2) accepted after unlock")
	_check(service.complete_run(true) == true, "win on tier 2 succeeds")
	_check(service.get_highest_cleared_tier() == 2, "highest stays at 2 after top-tier win")

	# Loss does not advance unlocks.
	service.select_tier(0)
	var before_highest := service.get_highest_cleared_tier()
	_check(service.complete_run(false) == true, "loss call succeeds but does not advance")
	_check(service.get_highest_cleared_tier() == before_highest, "highest unchanged after loss")

	# Repeated lower-tier win does not skip ahead.
	service.select_tier(0)
	_check(service.complete_run(true) == true, "repeated tier-0 win succeeds")
	_check(service.get_highest_cleared_tier() == 2, "repeated tier-0 win does not lower ceiling")

	# AC3: detached modifier lookup for each tier without mutating JSON.
	for tier_id in REQUIRED_TIER_IDS:
		service.select_tier(tier_id)
		var mods := service.get_modifiers()
		var expected: Array = EXPECTED_MODIFIERS[tier_id]
		_check(mods.get("max_hp_percent_bonus") == expected[0],
			"tier %d max_hp_percent_bonus equals authored %d" % [tier_id, expected[0]])
		_check(mods.get("attack_intent_bonus") == expected[1],
			"tier %d attack_intent_bonus equals authored %d" % [tier_id, expected[1]])

	# Prove the service does not touch the authored document.
	_check(source_document == source_snapshot, "service queries do not mutate the authored JSON document")

	# AC4: snapshot and restore.
	service.select_tier(1)
	service.complete_run(true)
	var snapshot := service.get_state()

	# Restore on a fresh service.
	var fresh := RunDifficulty.new()
	_check(fresh.restore_state(snapshot) == true, "valid snapshot restores precisely")
	_check(fresh.get_highest_cleared_tier() == 2, "restored highest_cleared_tier is 2")
	_check(fresh.get_selected_tier() == 1, "restored selected_tier is 1")
	_check(fresh.get_available_tiers().has(1) and fresh.get_available_tiers().has(2),
		"restored available tiers include 1 and 2")

	# Invalid/nonintegral snapshot refused atomically.
	_check(fresh.restore_state({"highest_cleared_tier": 1.5, "selected_tier": 1}) == false,
		"fractional highest_cleared_tier refused")
	_check(fresh.get_highest_cleared_tier() == 2, "invalid restore does not alter state (highest stays 2)")

	var bad_unearned := {"highest_cleared_tier": 0, "selected_tier": 2}
	_check(fresh.restore_state(bad_unearned) == false, "unearned tier 2 with only 0 cleared refused")
	_check(fresh.get_selected_tier() == 1, "invalid restore does not alter selection")

	# Out-of-range and extra-key snapshots refused.
	_check(fresh.restore_state({"highest_cleared_tier": -2, "selected_tier": 0}) == false,
		"negative highest beyond -1 refused")

	# AC4 / P9 ceiling: highest_cleared_tier above the authored tier 2 is refused.
	var before_high := fresh.get_state()
	_check(fresh.restore_state({"highest_cleared_tier": 3, "selected_tier": 0}) == false,
		"highest_cleared_tier 3 above the tier-2 ceiling refused")
	_check(fresh.get_state() == before_high,
		"rejected highest_cleared_tier 3 leaves state identical")
	var before_float := fresh.get_state()
	_check(fresh.restore_state({"highest_cleared_tier": 3.0, "selected_tier": 0}) == false,
		"integral-float highest_cleared_tier 3.0 above the ceiling refused")
	_check(fresh.get_state() == before_float,
		"rejected integral-float highest_cleared_tier 3.0 leaves state identical")
	var before_high_selected := fresh.get_state()
	_check(fresh.restore_state({"highest_cleared_tier": 3, "selected_tier": 2}) == false,
		"out-of-range highest_cleared_tier with selected tier 2 refused")
	_check(fresh.get_state() == before_high_selected,
		"rejected out-of-range highest with tier 2 leaves state identical")
	_check(fresh.restore_state({"highest_cleared_tier": 0, "selected_tier": 0, "extra": true}) == false,
		"extra key in snapshot refused")

	# Invalid non-object/state with missing keys refused.
	_check(fresh.restore_state([1, 2]) == false, "non-object restore refused")
	_check(fresh.restore_state({"selected_tier": 0}) == false, "missing highest_cleared_tier refused")

	# Determinism: independent RNG untouched; repeated identical inputs reproduce state.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var before := rng.state

	var s1 := RunDifficulty.new()
	var s2 := RunDifficulty.new()
	s1.select_tier(0)
	s1.complete_run(true)
	s2.select_tier(0)
	s2.complete_run(true)

	var after := rng.state
	_check(before == after, "independent RNG unchanged by service operations")
	_check(s1.get_state() == s2.get_state(), "identical service inputs reproduce the same state")

	# Confirm non-object tier selection is refused.
	_check(service.select_tier(1.5) == false, "fractional tier selection refused")
	_check(service.get_selected_tier() == 1, "fractional selection does not alter state")
