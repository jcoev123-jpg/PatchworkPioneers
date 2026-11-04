extends SceneTree
## Deterministic, scene-free test suite for authentic Tinker Combat Scrap Help rows.
##
## Verifies that CardKeywordGlossary.describe() adds exactly one authentic "Combat Scrap"
## Help row to every genuine V3 Tinker gain and spender card, distinguishes per-combat
## storage from run-wallet scraps, explains each spender's different limit, preserves
## existing keyword order, refuses lookalikes/forgeries/turret/Jury-rig/other heroes,
## returns detached dictionaries, and touches no global or local RNG.

const COMBAT_SCRAP_ROW := "Combat Scrap"

var checks := 0
var failures: Array[String] = []

var v3_tinker_starter := V3TinkerStarterCards.new()
var v3_tinker_pool := V3TinkerPoolCards.new()
var warden_pool := WardenPoolCards.new()
var scarecrow_starter := ScarecrowStarterCards.new()
var seamstress_starter := V3SeamstressStarterCards.new()
var lantern_monk_pool := LanternMonkPoolCards.new()
var rag_duelist_pool := RagDuelistPoolCards.new()

## The 20 authentic V3 Tinker Combat Scrap printings (8 starter, 12 pool).
## Named lookups only; never by catalog count or ordered list.
const GENUINE_TINKER_SCRAP_IDS := [
	{"catalog": "starter", "id": "tinker_v3_cog_shot", "extra_keywords": []},
	{"catalog": "starter", "id": "tinker_v3_cog_shot_plus", "extra_keywords": []},
	{"catalog": "starter", "id": "tinker_v3_casing_ward", "extra_keywords": []},
	{"catalog": "starter", "id": "tinker_v3_casing_ward_plus", "extra_keywords": []},
	{"catalog": "starter", "id": "tinker_v3_scrap_bomb", "extra_keywords": []},
	{"catalog": "starter", "id": "tinker_v3_scrap_bomb_plus", "extra_keywords": []},
	{"catalog": "starter", "id": "tinker_v3_tune_up", "extra_keywords": []},
	{"catalog": "starter", "id": "tinker_v3_tune_up_plus", "extra_keywords": []},
	{"catalog": "pool", "id": "tinker_v3_brass_casing", "extra_keywords": []},
	{"catalog": "pool", "id": "tinker_v3_brass_casing_plus", "extra_keywords": []},
	{"catalog": "pool", "id": "tinker_v3_gear_brace", "extra_keywords": []},
	{"catalog": "pool", "id": "tinker_v3_gear_brace_plus", "extra_keywords": []},
	{"catalog": "pool", "id": "tinker_v3_spare_screws", "extra_keywords": []},
	{"catalog": "pool", "id": "tinker_v3_spare_screws_plus", "extra_keywords": []},
	{"catalog": "pool", "id": "tinker_v3_spring_clamp", "extra_keywords": ["Weak 1"]},
	{"catalog": "pool", "id": "tinker_v3_spring_clamp_plus", "extra_keywords": ["Weak 1"]},
	{"catalog": "pool", "id": "tinker_v3_overload", "extra_keywords": []},
	{"catalog": "pool", "id": "tinker_v3_overload_plus", "extra_keywords": []},
	{"catalog": "pool", "id": "tinker_v3_scrapstorm", "extra_keywords": []},
	{"catalog": "pool", "id": "tinker_v3_scrapstorm_plus", "extra_keywords": []},
]


func _initialize() -> void:
	seed(90210)
	var expected_global := randi()
	seed(90210)

	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 123456789
	var expected_local := local_rng.randi()
	local_rng.seed = 123456789

	_test_authentic_tinker_help()
	_test_turret_and_jury_rig_no_scrap_help()
	_test_other_heroes_no_scrap_help()
	_test_mismatch_refusals()
	_test_detachment_and_idempotence()

	_check(randi() == expected_global, "global RNG state preserved, no draws")
	_check(local_rng.randi() == expected_local, "local RNG state preserved, no draws")

	for failure: String in failures:
		printerr(failure)
	print("v3_tinker_combat_scrap_help_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _definition(catalog: String, card_id: String) -> Dictionary:
	if catalog == "starter":
		return v3_tinker_starter.get_definition(card_id)
	return v3_tinker_pool.get_definition(card_id)


func _row_keywords(rows: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for row in rows:
		result.append(str(row.get("keyword", "")))
	return result


func _has_combat_scrap_row(definition: Variant) -> bool:
	for row in CardKeywordGlossary.describe(definition):
		if str(row.get("keyword", "")) == COMBAT_SCRAP_ROW:
			return true
	return false


func _test_authentic_tinker_help() -> void:
	for entry in GENUINE_TINKER_SCRAP_IDS:
		var catalog: String = str(entry["catalog"])
		var card_id: String = str(entry["id"])
		var extra_kw: Array = entry["extra_keywords"]
		var def := _definition(catalog, card_id)

		_check(not def.is_empty(), "genuine Tinker definition found: " + card_id)
		if def.is_empty():
			continue

		var original := def.duplicate(true)
		var rows: Array[Dictionary] = CardKeywordGlossary.describe(def)

		# Total rows = extra_keywords.size() + 1 (the single Combat Scrap row)
		var expected_count: int = extra_kw.size() + 1
		_check(rows.size() == expected_count,
			"%s has exactly %d Help rows (got %d)" % [card_id, expected_count, rows.size()])

		var keywords := _row_keywords(rows)
		_check(keywords.count(COMBAT_SCRAP_ROW) == 1,
			"%s has exactly one Combat Scrap row" % card_id)

		# Existing keyword order is preserved: extra keywords come first in author order
		for i in range(extra_kw.size()):
			_check(keywords[i] == str(extra_kw[i]),
				"%s preserves keyword %s at index %d" % [card_id, str(extra_kw[i]), i])
		_check(keywords.back() == COMBAT_SCRAP_ROW,
			"%s has Combat Scrap row appended after existing keywords" % card_id)

		# Check Help explanation contents
		var scrap_row: Dictionary = {}
		for r in rows:
			if str(r.get("keyword", "")) == COMBAT_SCRAP_ROW:
				scrap_row = r
				break
		_check(not scrap_row.is_empty(), "found scrap row for " + card_id)

		var text := str(scrap_row.get("explanation", ""))
		_check(text == CardKeywordGlossary.COMBAT_SCRAP_EXPLANATION,
			"explanation matches COMBAT_SCRAP_EXPLANATION for " + card_id)
		_check(text.contains("combat-local counter") or text.contains("during battle"),
			"explains per-combat storage: " + card_id)
		_check(text.contains("never the run's wallet scraps currency"),
			"distinguishes from wallet scraps currency: " + card_id)
		_check(text.contains("cannot be spent outside combat") or text.contains("resets after each battle"),
			"explains counter does not persist: " + card_id)
		_check(text.contains("Overload") and text.contains("all held Combat Scrap"),
			"explains Overload consumes all Combat Scrap: " + card_id)
		_check(text.contains("Scrapstorm") and text.contains("up to 3 Combat Scrap"),
			"explains Scrapstorm spends up to 3 Combat Scrap: " + card_id)
		_check(text.contains("retains any remaining surplus"),
			"explains Scrapstorm retains surplus scrap: " + card_id)

		_check(def == original, "input record not mutated by describe: " + card_id)


func _test_turret_and_jury_rig_no_scrap_help() -> void:
	# Wind-up Turret and Jury-rig author other keys and must NOT receive Combat Scrap Help
	for other_id in [
		"tinker_v3_wind_up_turret", "tinker_v3_wind_up_turret_plus",
		"tinker_v3_jury_rig", "tinker_v3_jury_rig_plus"
	]:
		var def := v3_tinker_pool.get_definition(other_id)
		_check(not def.is_empty(), "definition exists: " + other_id)
		_check(not _has_combat_scrap_row(def), "%s receives no Combat Scrap Help row" % other_id)
		_check(not CardShortRules.is_authored_combat_scrap(def),
			"%s fails is_authored_combat_scrap" % other_id)


func _test_other_heroes_no_scrap_help() -> void:
	var candidates: Array[Dictionary] = [
		warden_pool.get_definition("warden_draw_fire"),
		scarecrow_starter.get_definition("scarecrow_crow_dive"),
		seamstress_starter.get_definition("seamstress_v3_tether_loop"),
		lantern_monk_pool.get_definition("lantern_monk_moth_cloud"),
		rag_duelist_pool.get_definition("rag_duelist_cape_guard"),
	]
	for card in candidates:
		var card_id := str(card.get("id", ""))
		_check(not _has_combat_scrap_row(card), "%s has no Combat Scrap Help row" % card_id)
		_check(not CardShortRules.is_authored_combat_scrap(card),
			"%s is not authored combat scrap" % card_id)


func _test_mismatch_refusals() -> void:
	# 1. Non-dictionary inputs
	_check(CardKeywordGlossary.describe(null).is_empty(), "null returns empty array")
	_check(CardKeywordGlossary.describe({}).is_empty(), "empty dict returns empty array")
	_check(CardKeywordGlossary.describe(42).is_empty(), "int returns empty array")
	_check(CardKeywordGlossary.describe("tinker_v3_cog_shot").is_empty(), "string returns empty array")
	_check(CardKeywordGlossary.describe([]).is_empty(), "array returns empty array")

	# 2. Mutated copies of genuine cards
	var genuine_shot := v3_tinker_starter.get_definition("tinker_v3_cog_shot")
	var genuine_overload := v3_tinker_pool.get_definition("tinker_v3_overload")
	var genuine_storm := v3_tinker_pool.get_definition("tinker_v3_scrapstorm")

	var probes := [
		["wrong owner", genuine_shot.duplicate(true), "owner", "warden"],
		["wrong owner seamstress", genuine_overload.duplicate(true), "owner", "seamstress"],
		["empty owner", genuine_shot.duplicate(true), "owner", ""],
		["forged id", genuine_shot.duplicate(true), "id", "tinker_v3_forged_shot"],
		["deleted id", genuine_shot.duplicate(true), "id", null],
		["wrong cost shot", genuine_shot.duplicate(true), "cost", 0],
		["wrong cost overload", genuine_overload.duplicate(true), "cost", 2],
		["wrong cost storm", genuine_storm.duplicate(true), "cost", 1],
		["wrong target shot", genuine_shot.duplicate(true), "target_kind", "self"],
		["wrong target overload", genuine_overload.duplicate(true), "target_kind", "enemy_all"],
		["wrong target storm", genuine_storm.duplicate(true), "target_kind", "enemy_single"],
		["wrong from_positions overload", genuine_overload.duplicate(true), "from_positions", [1]],
		["wrong from_positions storm", genuine_storm.duplicate(true), "from_positions", [1, 2]],
		["wrong to_positions shot", genuine_shot.duplicate(true), "to_positions", [1]],
		["extra top-level field", genuine_shot.duplicate(true), "forged_field", true],
		["extra effect key shot", genuine_shot.duplicate(true), "effects",
			{"damage": 5, "combat_scrap_gain": 1, "weak": 1}],
		["extra effect key overload", genuine_overload.duplicate(true), "effects",
			{"damage": 2, "damage_per_combat_scrap": 3, "consume_all_combat_scrap": true, "block": 5}],
		["extra effect key storm", genuine_storm.duplicate(true), "effects",
			{"damage": 3, "combat_scrap_spend_max": 3, "bonus_damage_per_combat_scrap": 1,
			"living_targets_only": true, "bleed": 1}],
		["altered scrap gain 0", genuine_shot.duplicate(true), "effects",
			{"damage": 5, "combat_scrap_gain": 0}],
		["altered scrap gain negative", genuine_shot.duplicate(true), "effects",
			{"damage": 5, "combat_scrap_gain": -1}],
		["altered damage_per_scrap", genuine_overload.duplicate(true), "effects",
			{"damage": 2, "damage_per_combat_scrap": 1, "consume_all_combat_scrap": true}],
		["consume_all_combat_scrap false", genuine_overload.duplicate(true), "effects",
			{"damage": 2, "damage_per_combat_scrap": 3, "consume_all_combat_scrap": false}],
		["altered spend max", genuine_storm.duplicate(true), "effects",
			{"damage": 3, "combat_scrap_spend_max": 5, "bonus_damage_per_combat_scrap": 1,
			"living_targets_only": true}],
		["altered bonus per scrap", genuine_storm.duplicate(true), "effects",
			{"damage": 3, "combat_scrap_spend_max": 3, "bonus_damage_per_combat_scrap": 2,
			"living_targets_only": true}],
	]

	for probe_entry in probes:
		var label: String = str(probe_entry[0])
		var probe: Dictionary = probe_entry[1]
		var field: String = str(probe_entry[2])
		var val: Variant = probe_entry[3]
		if val == null:
			probe.erase(field)
		else:
			probe[field] = val
		var before := probe.duplicate(true)

		_check(not CardShortRules.is_authored_combat_scrap(probe),
			"%s fails is_authored_combat_scrap" % label)
		_check(not _has_combat_scrap_row(probe),
			"%s receives no Combat Scrap Help row" % label)
		_check(probe == before, "%s probe not mutated by inspection" % label)

	# 3. Same-shaped copied dictionary but uncanonical ID
	var copied := genuine_shot.duplicate(true)
	copied["id"] = "tinker_v3_lookalike_shot"
	_check(not CardShortRules.is_authored_combat_scrap(copied),
		"lookalike ID fails is_authored_combat_scrap")
	_check(not _has_combat_scrap_row(copied),
		"lookalike ID receives no Combat Scrap Help row")


func _test_detachment_and_idempotence() -> void:
	for entry in GENUINE_TINKER_SCRAP_IDS:
		var catalog: String = str(entry["catalog"])
		var card_id: String = str(entry["id"])
		var def := _definition(catalog, card_id)

		var first_call := CardKeywordGlossary.describe(def)
		var second_call := CardKeywordGlossary.describe(def)

		# Idempotent: repeated calls produce identical results
		_check(first_call == second_call, "repeated describe() calls are identical: " + card_id)

		# Detached: mutating the returned row array or row dictionary does not affect next call
		first_call[0]["keyword"] = "MUTATED_KEYWORD"
		first_call[0]["explanation"] = "MUTATED_EXPLANATION"
		first_call.clear()

		var third_call := CardKeywordGlossary.describe(def)
		_check(third_call == second_call,
			"describe() returns detached rows, mutation does not leak: " + card_id)
		_check(third_call[0]["keyword"] != "MUTATED_KEYWORD",
			"row keyword not corrupted: " + card_id)
