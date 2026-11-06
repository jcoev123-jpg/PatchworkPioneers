extends SceneTree
## Deterministic headless test for RunStitchedMothSacrificeEvent.
## Validates the scene-free Stitched Moth Infestation spare-part sacrifice service.
## Covers AC1, AC2, AC3, AC4 and Fix Round 1 defects.

const EVENT_CATALOG_PATH := "res://data/events/stitched_route_effects.json"
const ENEMY_PARTS_PATH := "res://data/parts/enemy_parts.json"
const NODE := "test_moth_node_1"

const PART_CRAB := "scissor_crab_claw_arm"
const PART_WINGS := "moth_swarm_wings"

var failures: Array[String] = []
var checks: int = 0
var catalog_by_id: Dictionary = {}
var raw_event_record: Dictionary = {}
var rng: RandomNumberGenerator


func _initialize() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 20261106
	var initial_rng_state := rng.state

	_load_real_data()

	if failures.is_empty():
		_test_ac1_opening_and_preview()
		_test_ac2_sacrifice_part_consumption_and_receipt()
		_test_ac3_fumigate_and_escape_branches()
		_test_ac4_refusals_bounds_and_invariance()
		_test_fix1_missing_guard_refusals()
		_test_fix1_forged_catalog_validation()
		_test_fix1_malformed_event_and_effects_validation()

	_check(rng.state == initial_rng_state, "AC4: external seeded RNG state must remain unchanged")

	if failures.is_empty():
		print("run_stitched_moth_sacrifice_event_test: PASS (", checks, " checks)")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("run_stitched_moth_sacrifice_event_test: FAIL (", failures.size(), " failures, ", checks, " checks)")
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _spare(id: String, tier: int = 1, slot: String = "arms", torn: bool = false) -> Dictionary:
	return {
		"id": id,
		"tier": tier,
		"slot": slot,
		"torn": torn,
	}


func _load_real_data() -> void:
	# Load parts catalog
	var cat_res := StitchedParts.load_catalog(ENEMY_PARTS_PATH)
	_check(bool(cat_res.get("ok", false)), "enemy parts catalog loads successfully")
	catalog_by_id = cat_res.get("by_id", {})
	_check(catalog_by_id.has(PART_CRAB), "catalog contains " + PART_CRAB)
	_check(catalog_by_id.has(PART_WINGS), "catalog contains " + PART_WINGS)

	# Load event record from real stitched_route_effects.json
	_check(FileAccess.file_exists(EVENT_CATALOG_PATH), "stitched_route_effects.json exists")
	var event_text := FileAccess.get_file_as_string(EVENT_CATALOG_PATH)
	var parsed: Variant = JSON.parse_string(event_text)
	_check(parsed is Dictionary and parsed.has("events"), "route effects parses as valid JSON object")
	if parsed is Dictionary and parsed.get("events") is Array:
		for ev in parsed["events"]:
			if ev is Dictionary and str(ev.get("id", "")) == "moth_infestation":
				raw_event_record = (ev as Dictionary).duplicate(true)
				break
	_check(not raw_event_record.is_empty(), "moth_infestation event found in route effects catalog")
	_check(str(raw_event_record.get("id", "")) == "moth_infestation", "event id is moth_infestation")
	_check(str(raw_event_record.get("title", "")) == "Moth Infestation", "event title is Moth Infestation")


## AC1: opening and previewing expose authored alternatives with correct availability.
func _test_ac1_opening_and_preview() -> void:
	var satchel := [
		_spare(PART_CRAB, 1, "arms", false),
		_spare(PART_WINGS, 2, "legs", false),
	]
	var service := RunStitchedMothSacrificeEvent.open_stitched(
		NODE,
		satchel,
		3,
		catalog_by_id,
		raw_event_record
	)
	_check(service.is_valid(), "AC1: service is valid on opening: " + service.get_error())
	_check(service.is_open(), "AC1: service is open on opening")
	_check(not service.is_claimed(), "AC1: service is not claimed on opening")
	_check(service.get_node_id() == NODE, "AC1: node id matches")
	_check(service.get_scraps() == 3, "AC1: scraps balance is 3")
	_check(service.get_satchel().size() == 2, "AC1: satchel has 2 parts")

	# Preview without selecting a spare index
	var unselected_preview := service.preview()
	_check(bool(unselected_preview.get("ok", false)), "AC1: preview returns ok")
	var choices: Array = unselected_preview.get("choices", [])
	_check(choices.size() == 3, "AC1: preview exposes exactly 3 choices")
	if choices.size() != 3:
		return

	var sacrifice_ch: Dictionary = choices[0]
	var fumigate_ch: Dictionary = choices[1]
	var escape_ch: Dictionary = choices[2]

	_check(str(sacrifice_ch.get("id", "")) == "sacrifice_part", "AC1: choice 0 is sacrifice_part")
	_check(int(sacrifice_ch.get("scraps_delta", 0)) == 2, "AC1: sacrifice gives +2 scraps")
	_check(not bool(sacrifice_ch.get("available", true)), "AC1: sacrifice unavailable without selected spare")
	_check(str(sacrifice_ch.get("blocked", "")) == "no spare part selected", "AC1: sacrifice reports unselected block reason")

	_check(str(fumigate_ch.get("id", "")) == "fumigate", "AC1: choice 1 is fumigate")
	_check(int(fumigate_ch.get("scraps_delta", 0)) == -1, "AC1: fumigate spends -1 scrap")
	_check(bool(fumigate_ch.get("available", false)), "AC1: fumigate available with 3 scraps")
	_check(bool(fumigate_ch.get("affordable", false)), "AC1: fumigate affordable with 3 scraps")

	_check(str(escape_ch.get("id", "")) == "escape", "AC1: choice 2 is escape")
	_check(int(escape_ch.get("scraps_delta", 0)) == 0, "AC1: escape delta is 0")
	_check(bool(escape_ch.get("available", false)), "AC1: escape is always available")

	# Preview with selected index 0
	var selected_preview := service.preview(0)
	var sel_choices: Array = selected_preview.get("choices", [])
	var sel_sacrifice: Dictionary = sel_choices[0]
	_check(bool(sel_sacrifice.get("available", false)), "AC1: sacrifice available when spare index 0 selected")
	_check(int(sel_sacrifice.get("selected_index", -1)) == 0, "AC1: selected index is 0")
	_check(sel_sacrifice.get("selected_part", {}).get("id") == PART_CRAB, "AC1: selected part is crab claw")
	_check(int(sel_sacrifice.get("projected_satchel_count", 0)) == 1, "AC1: projected satchel count is 1")
	_check(int(sel_sacrifice.get("projected_scraps", 0)) == 5, "AC1: projected scraps is 5 (3 + 2)")

	# Preview with zero scraps
	var broke_service := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 0, catalog_by_id, raw_event_record)
	var broke_preview := broke_service.preview()
	var broke_fumigate: Dictionary = broke_preview.get("choices", [])[1]
	_check(not bool(broke_fumigate.get("available", true)), "AC1: fumigate unavailable at 0 scraps")
	_check(not bool(broke_fumigate.get("affordable", true)), "AC1: fumigate unaffordable at 0 scraps")
	_check(str(broke_fumigate.get("blocked", "")) == "insufficient scraps", "AC1: fumigate blocked reason recorded")

	# Quote method parity with preview
	var quote_result := service.quote(1)
	_check(int(quote_result.get("choices", [])[0].get("selected_index", -1)) == 1, "AC1: quote(1) exposes selected index 1")


## AC2: sacrifice_part consumes exactly one satchel entry and awards +2 scraps.
func _test_ac2_sacrifice_part_consumption_and_receipt() -> void:
	# Test with part 0 (scissor_crab_claw_arm, tier 1)
	var part0 := _spare(PART_CRAB, 1, "arms", false)
	var part1 := _spare(PART_WINGS, 2, "legs", false)
	var part2 := _spare(PART_CRAB, 3, "head", true)
	var initial_satchel := [part0, part1, part2]

	var svc := RunStitchedMothSacrificeEvent.open_stitched(NODE, initial_satchel, 4, catalog_by_id, raw_event_record)
	var initial_state := svc.read_state()

	var receipt := svc.choose("sacrifice_part", 0, NODE, initial_state)
	_check(bool(receipt.get("ok", false)), "AC2: sacrifice_part succeeded: " + str(receipt.get("error", "")))
	_check(str(receipt.get("decision", "")) == "sacrifice_part", "AC2: decision recorded")
	_check(int(receipt.get("scraps_before", 0)) == 4, "AC2: scraps_before was 4")
	_check(int(receipt.get("scraps", 0)) == 6, "AC2: scraps is now 6 (+2)")
	_check(int(receipt.get("scraps_delta", 0)) == 2, "AC2: scraps_delta is 2")
	_check(int(receipt.get("removed_index", -1)) == 0, "AC2: removed_index is 0")

	var removed_desc: Dictionary = receipt.get("removed_descriptor", {})
	_check(removed_desc.get("id") == PART_CRAB, "AC2: removed descriptor ID is crab claw")
	_check(int(removed_desc.get("tier", 0)) == 1, "AC2: removed descriptor tier is 1")
	_check(str(removed_desc.get("slot", "")) == "arms", "AC2: removed descriptor preserved slot")
	_check(bool(removed_desc.get("torn", true)) == false, "AC2: removed descriptor preserved torn flag")

	var after_satchel: Array = receipt.get("satchel", [])
	_check(after_satchel.size() == 2, "AC2: remaining satchel has exactly 2 entries")
	if after_satchel.size() == 2:
		_check(after_satchel[0].get("id") == PART_WINGS and int(after_satchel[0].get("tier", 0)) == 2, "AC2: part 1 preserved in order at index 0")
		_check(after_satchel[1].get("id") == PART_CRAB and int(after_satchel[1].get("tier", 0)) == 3 and bool(after_satchel[1].get("torn", false)) == true, "AC2: part 2 preserved in order and fields at index 1")

	_check(not svc.is_open(), "AC2: service closed after sacrifice")
	_check(svc.is_claimed(), "AC2: service claimed after sacrifice")

	# Test with distinct part at index 1 (moth_swarm_wings, tier 2) on a fresh service
	var svc2 := RunStitchedMothSacrificeEvent.open_stitched(NODE, initial_satchel, 1, catalog_by_id, raw_event_record)
	var state2 := svc2.read_state()
	var receipt2 := svc2.sacrifice_part(1, NODE, state2)
	_check(bool(receipt2.get("ok", false)), "AC2: sacrifice_part via dedicated method succeeded")
	_check(int(receipt2.get("scraps", 0)) == 3, "AC2: scraps became 3 (1 + 2)")
	_check(receipt2.get("removed_descriptor", {}).get("id") == PART_WINGS, "AC2: removed descriptor is wings")
	_check(int(receipt2.get("removed_descriptor", {}).get("tier", 0)) == 2, "AC2: removed tier is 2")

	var after_satchel2: Array = receipt2.get("satchel", [])
	_check(after_satchel2.size() == 2, "AC2: exactly one item consumed")
	if after_satchel2.size() == 2:
		_check(after_satchel2[0].get("id") == PART_CRAB and int(after_satchel2[0].get("tier", 0)) == 1, "AC2: item 0 untouched")
		_check(after_satchel2[1].get("id") == PART_CRAB and int(after_satchel2[1].get("tier", 0)) == 3, "AC2: item 2 untouched")

	# Caller satchel was not mutated
	_check(initial_satchel.size() == 3, "AC2: caller satchel input was not mutated")


## AC3: fumigate (-1 scrap) and escape (0 scrap, 0 satchel change).
func _test_ac3_fumigate_and_escape_branches() -> void:
	var satchel := [
		_spare(PART_CRAB, 1, "arms", false),
		_spare(PART_WINGS, 2, "legs", false),
	]

	# Branch 1: Fumigate with sufficient scraps
	var svc_fumigate := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 5, catalog_by_id, raw_event_record)
	var state_f := svc_fumigate.read_state()
	var receipt_f := svc_fumigate.fumigate(NODE, state_f)
	_check(bool(receipt_f.get("ok", false)), "AC3: fumigate succeeds with scraps: " + str(receipt_f.get("error", "")))
	_check(int(receipt_f.get("scraps_before", 0)) == 5, "AC3: scraps_before was 5")
	_check(int(receipt_f.get("scraps", 0)) == 4, "AC3: scraps after fumigate is 4 (-1)")
	_check(int(receipt_f.get("scraps_delta", 0)) == -1, "AC3: scraps_delta is -1")
	_check(receipt_f.get("satchel", []).size() == 2, "AC3: fumigate leaves satchel unchanged")
	_check(not svc_fumigate.is_open(), "AC3: fumigate closes service")
	_check(svc_fumigate.is_claimed(), "AC3: fumigate claims service")

	# Replay after fumigate is refused
	var replay_f := svc_fumigate.fumigate(NODE, receipt_f.get("state", {}))
	_check(not bool(replay_f.get("ok", true)), "AC3: replay after fumigate refused")

	# Branch 2: Fumigate with zero scraps refused without latching
	var svc_zero := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 0, catalog_by_id, raw_event_record)
	var state_zero := svc_zero.read_state()
	var rej_f := svc_zero.fumigate(NODE, state_zero)
	_check(not bool(rej_f.get("ok", true)), "AC3: zero-scrap fumigate refused")
	_check(svc_zero.is_open(), "AC3: zero-scrap refusal leaves service open (not latched)")
	_check(svc_zero.get_scraps() == 0, "AC3: scraps unchanged on refusal")

	# Correct with escape on the same unlatched service
	var state_zero2 := svc_zero.read_state()
	var esc_after_rej := svc_zero.escape(NODE, state_zero2)
	_check(bool(esc_after_rej.get("ok", false)), "AC3: escape succeeds after fumigate refusal")
	_check(esc_after_rej.get("satchel", []).size() == 2, "AC3: escape satchel intact")

	# Branch 3: Escape leaves both scraps and satchel unchanged
	var svc_escape := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 7, catalog_by_id, raw_event_record)
	var state_e := svc_escape.read_state()
	var receipt_e := svc_escape.choose("escape", NODE, state_e)
	_check(bool(receipt_e.get("ok", false)), "AC3: escape succeeds")
	_check(int(receipt_e.get("scraps", 0)) == 7, "AC3: escape leaves scraps unchanged")
	_check(int(receipt_e.get("scraps_delta", 0)) == 0, "AC3: escape scraps_delta is 0")
	_check(receipt_e.get("satchel", []).size() == 2, "AC3: escape leaves satchel unchanged")
	_check(not svc_escape.is_open(), "AC3: escape closes service permanently")
	_check(svc_escape.is_claimed(), "AC3: escape marks service claimed")


## AC4: negative tests, forged/missing index, stale state, wrong node, bounds.
func _test_ac4_refusals_bounds_and_invariance() -> void:
	var satchel := [
		_spare(PART_CRAB, 1, "arms", false),
		_spare(PART_WINGS, 3, "legs", false),
	]
	var svc := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, raw_event_record)
	var valid_state := svc.read_state()

	# 1. Wrong node
	var res_wrong_node := svc.choose("sacrifice_part", 0, "wrong_node_id", valid_state)
	_check(not bool(res_wrong_node.get("ok", true)), "AC4: wrong node refused")
	_check(svc.is_open(), "AC4: service still open after wrong node")

	# 2. Stale expected state
	var stale_state := valid_state.duplicate(true)
	stale_state["scraps"] = 999
	var res_stale := svc.choose("sacrifice_part", 0, NODE, stale_state)
	_check(not bool(res_stale.get("ok", true)), "AC4: stale expected state refused")
	_check(svc.is_open(), "AC4: service still open after stale state")

	# 3. Missing index
	var res_missing_idx := svc.choose("sacrifice_part", null, NODE, valid_state)
	_check(not bool(res_missing_idx.get("ok", true)), "AC4: missing index refused")

	# 4. Out of bounds index (negative)
	var res_neg_idx := svc.choose("sacrifice_part", -1, NODE, valid_state)
	_check(not bool(res_neg_idx.get("ok", true)), "AC4: negative index refused")

	# 5. Out of bounds index (>= size)
	var res_high_idx := svc.choose("sacrifice_part", 5, NODE, valid_state)
	_check(not bool(res_high_idx.get("ok", true)), "AC4: out-of-bounds index refused")

	# 6. Forged uncatalogued part in satchel during sacrifice
	var forged_satchel := [
		{"id": "forged_nonexistent_part", "tier": 1, "slot": "arms", "torn": false}
	]
	var svc_forged := RunStitchedMothSacrificeEvent.open_stitched(NODE, forged_satchel, 2, catalog_by_id, raw_event_record)
	_check(not svc_forged.is_valid(), "AC4: opening with uncatalogued part fails closed")

	# 7. Empty satchel
	var svc_empty := RunStitchedMothSacrificeEvent.open_stitched(NODE, [], 2, catalog_by_id, raw_event_record)
	_check(svc_empty.is_valid(), "AC4: opening with empty satchel is valid: " + svc_empty.get_error())
	var state_empty := svc_empty.read_state()
	var empty_sacrifice := svc_empty.sacrifice_part(0, NODE, state_empty)
	_check(not bool(empty_sacrifice.get("ok", true)), "AC4: sacrifice with empty satchel refused")
	_check(svc_empty.is_open(), "AC4: empty satchel refusal does not latch")

	# 8. Satchel capacity limit (7 items > SATCHEL_CAP of 6)
	var big_satchel: Array = []
	for i in range(7):
		big_satchel.append(_spare(PART_CRAB, 1))
	var svc_big := RunStitchedMothSacrificeEvent.open_stitched(NODE, big_satchel, 2, catalog_by_id, raw_event_record)
	_check(not svc_big.is_valid(), "AC4: satchel size 7 is rejected on opening")

	# Satchel capacity limit (6 items == SATCHEL_CAP)
	var max_satchel: Array = []
	for i in range(6):
		max_satchel.append(_spare(PART_CRAB, 1))
	var svc_max := RunStitchedMothSacrificeEvent.open_stitched(NODE, max_satchel, 2, catalog_by_id, raw_event_record)
	_check(svc_max.is_valid(), "AC4: satchel size 6 opens successfully: " + svc_max.get_error())

	# 9. Malformed catalog
	var bad_cat := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, {"ok": false}, raw_event_record)
	_check(not bad_cat.is_valid(), "AC4: malformed catalog fails closed")

	# 10. Malformed event record
	var bad_rec := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, {"id": "wrong_event"})
	_check(not bad_rec.is_valid(), "AC4: wrong event record fails closed")

	# 11. Malformed scraps (negative)
	var bad_scraps := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, -5, catalog_by_id, raw_event_record)
	_check(not bad_scraps.is_valid(), "AC4: negative scraps fails closed")

	# 12. Duplicate claim (replay refusal)
	var replay_test_svc := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, raw_event_record)
	var rep_state := replay_test_svc.read_state()
	var rep_receipt := replay_test_svc.sacrifice_part(0, NODE, rep_state)
	_check(bool(rep_receipt.get("ok", false)), "AC4: initial sacrifice succeeds")
	var dup_attempt := replay_test_svc.sacrifice_part(0, NODE, rep_receipt.get("state", {}))
	_check(not bool(dup_attempt.get("ok", true)), "AC4: duplicate claim refused")
	var dup_escape := replay_test_svc.escape(NODE, rep_receipt.get("state", {}))
	_check(not bool(dup_escape.get("ok", true)), "AC4: duplicate escape after claim refused")


## Fix Round 1: Mandatory node and state guard checks on all 3 choices.
func _test_fix1_missing_guard_refusals() -> void:
	var satchel := [
		_spare(PART_CRAB, 1, "arms", false),
		_spare(PART_WINGS, 2, "legs", false),
	]

	# 1. sacrifice_part guard refusals
	var svc_sac := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 4, catalog_by_id, raw_event_record)
	var sac_state := svc_sac.read_state()
	var stale_sac_state := sac_state.duplicate(true)
	stale_sac_state["scraps"] = 999

	# Omitted node
	var r1 := svc_sac.sacrifice_part(0)
	_check(not bool(r1.get("ok", true)), "Fix1: sacrifice_part with omitted node refused")
	_check(svc_sac.is_open() and not svc_sac.is_claimed(), "Fix1: service remains open after omitted node")

	var r1b := svc_sac.choose("sacrifice_part", 0)
	_check(not bool(r1b.get("ok", true)), "Fix1: choose('sacrifice_part', 0) with omitted guards refused")

	# Omitted state
	var r2 := svc_sac.sacrifice_part(0, NODE)
	_check(not bool(r2.get("ok", true)), "Fix1: sacrifice_part with omitted state refused")
	_check(svc_sac.is_open(), "Fix1: service remains open after omitted state")

	# Wrong node
	var r3 := svc_sac.sacrifice_part(0, "other_node", sac_state)
	_check(not bool(r3.get("ok", true)), "Fix1: sacrifice_part with wrong node refused")
	_check(svc_sac.is_open(), "Fix1: service remains open after wrong node")

	# Stale state
	var r4 := svc_sac.sacrifice_part(0, NODE, stale_sac_state)
	_check(not bool(r4.get("ok", true)), "Fix1: sacrifice_part with stale state refused")
	_check(svc_sac.is_open(), "Fix1: service remains open after stale state")

	# Valid guarded call succeeds once
	var r_valid_sac := svc_sac.sacrifice_part(0, NODE, sac_state)
	_check(bool(r_valid_sac.get("ok", false)), "Fix1: valid guarded sacrifice_part succeeds once")
	_check(svc_sac.is_claimed() and not svc_sac.is_open(), "Fix1: service closes after valid sacrifice")

	# 2. fumigate guard refusals
	var svc_fum := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 4, catalog_by_id, raw_event_record)
	var fum_state := svc_fum.read_state()
	var stale_fum_state := fum_state.duplicate(true)
	stale_fum_state["scraps"] = 999

	# Omitted node
	var rf1 := svc_fum.fumigate()
	_check(not bool(rf1.get("ok", true)), "Fix1: fumigate with omitted node refused")
	_check(svc_fum.is_open() and not svc_fum.is_claimed(), "Fix1: service remains open after omitted node fumigate")

	var rf1b := svc_fum.choose("fumigate")
	_check(not bool(rf1b.get("ok", true)), "Fix1: choose('fumigate') with omitted guards refused")

	# Omitted state
	var rf2 := svc_fum.fumigate(NODE)
	_check(not bool(rf2.get("ok", true)), "Fix1: fumigate with omitted state refused")
	_check(svc_fum.is_open(), "Fix1: service remains open after omitted state fumigate")

	# Wrong node
	var rf3 := svc_fum.fumigate("other_node", fum_state)
	_check(not bool(rf3.get("ok", true)), "Fix1: fumigate with wrong node refused")
	_check(svc_fum.is_open(), "Fix1: service remains open after wrong node fumigate")

	# Stale state
	var rf4 := svc_fum.fumigate(NODE, stale_fum_state)
	_check(not bool(rf4.get("ok", true)), "Fix1: fumigate with stale state refused")
	_check(svc_fum.is_open(), "Fix1: service remains open after stale state fumigate")

	# Valid guarded fumigate succeeds once
	var rf_valid := svc_fum.fumigate(NODE, fum_state)
	_check(bool(rf_valid.get("ok", false)), "Fix1: valid guarded fumigate succeeds once")
	_check(svc_fum.is_claimed() and not svc_fum.is_open(), "Fix1: service closes after valid fumigate")

	# 3. escape guard refusals
	var svc_esc := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 4, catalog_by_id, raw_event_record)
	var esc_state := svc_esc.read_state()
	var stale_esc_state := esc_state.duplicate(true)
	stale_esc_state["scraps"] = 999

	# Omitted node
	var re1 := svc_esc.escape()
	_check(not bool(re1.get("ok", true)), "Fix1: escape with omitted node refused")
	_check(svc_esc.is_open() and not svc_esc.is_claimed(), "Fix1: service remains open after omitted node escape")

	var re1b := svc_esc.choose("escape")
	_check(not bool(re1b.get("ok", true)), "Fix1: choose('escape') with omitted guards refused")

	var re1c := svc_esc.leave()
	_check(not bool(re1c.get("ok", true)), "Fix1: leave with omitted guards refused")

	# Omitted state
	var re2 := svc_esc.escape(NODE)
	_check(not bool(re2.get("ok", true)), "Fix1: escape with omitted state refused")
	_check(svc_esc.is_open(), "Fix1: service remains open after omitted state escape")

	# Wrong node
	var re3 := svc_esc.escape("other_node", esc_state)
	_check(not bool(re3.get("ok", true)), "Fix1: escape with wrong node refused")
	_check(svc_esc.is_open(), "Fix1: service remains open after wrong node escape")

	# Stale state
	var re4 := svc_esc.escape(NODE, stale_esc_state)
	_check(not bool(re4.get("ok", true)), "Fix1: escape with stale state refused")
	_check(svc_esc.is_open(), "Fix1: service remains open after stale state escape")

	# Valid guarded escape succeeds once
	var re_valid := svc_esc.escape(NODE, esc_state)
	_check(bool(re_valid.get("ok", false)), "Fix1: valid guarded escape succeeds once")
	_check(svc_esc.is_claimed() and not svc_esc.is_open(), "Fix1: service closes after valid escape")


## Fix Round 1: Forged by_id catalog validation.
func _test_fix1_forged_catalog_validation() -> void:
	var forged_desc := {"id": "forged_part", "tier": 1, "slot": "arms", "torn": false}
	var forged_satchel := [forged_desc]

	# Synthetic {by_id: {forged_part: {id: "forged_part"}}} must fail closed
	var synthetic_by_id := {
		"by_id": {
			"forged_part": {"id": "forged_part"}
		}
	}
	var svc_syn := RunStitchedMothSacrificeEvent.open_stitched(NODE, forged_satchel, 2, synthetic_by_id, raw_event_record)
	_check(not svc_syn.is_valid(), "Fix1: synthetic {by_id: {forged_part}} catalog fails closed")
	_check(not svc_syn.is_open(), "Fix1: service is not open with synthetic by_id")

	# Bare dictionary {forged_part: {id: "forged_part"}} must fail closed
	var bare_synthetic := {
		"forged_part": {"id": "forged_part"}
	}
	var svc_bare := RunStitchedMothSacrificeEvent.open_stitched(NODE, forged_satchel, 2, bare_synthetic, raw_event_record)
	_check(not svc_bare.is_valid(), "Fix1: bare synthetic catalog fails closed")

	# Empty by_id dictionary must fail closed
	var empty_by_id := {"by_id": {}}
	var svc_empty_cat := RunStitchedMothSacrificeEvent.open_stitched(NODE, forged_satchel, 2, empty_by_id, raw_event_record)
	_check(not svc_empty_cat.is_valid(), "Fix1: empty by_id catalog fails closed")

	# Key mismatch in by_id must fail closed
	var genuine_claw: Dictionary = catalog_by_id[PART_CRAB].duplicate(true)
	var mismatched_by_id := {
		"by_id": {
			"mismatched_key": genuine_claw
		}
	}
	var svc_mismatch := RunStitchedMothSacrificeEvent.open_stitched(NODE, [_spare(PART_CRAB, 1)], 2, mismatched_by_id, raw_event_record)
	_check(not svc_mismatch.is_valid(), "Fix1: key mismatch in catalog by_id fails closed")

	# Genuine StitchedParts.load_catalog(...).by_id remains accepted
	var genuine_by_id: Dictionary = StitchedParts.load_catalog(ENEMY_PARTS_PATH).get("by_id", {})
	var svc_genuine := RunStitchedMothSacrificeEvent.open_stitched(NODE, [_spare(PART_CRAB, 1)], 2, genuine_by_id, raw_event_record)
	_check(svc_genuine.is_valid(), "Fix1: genuine catalog by_id is accepted: " + svc_genuine.get_error())
	var gen_state := svc_genuine.read_state()
	var gen_receipt := svc_genuine.sacrifice_part(0, NODE, gen_state)
	_check(bool(gen_receipt.get("ok", false)), "Fix1: sacrifice succeeds with genuine by_id catalog")


## Fix Round 1: Malformed event record, missing fields, and contradictory deltas validation.
func _test_fix1_malformed_event_and_effects_validation() -> void:
	var satchel := [_spare(PART_CRAB, 1)]

	# 1. Missing title
	var rec_no_title: Dictionary = raw_event_record.duplicate(true)
	rec_no_title.erase("title")
	var svc_no_title := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_no_title)
	_check(not svc_no_title.is_valid(), "Fix1: event missing title fails closed")
	var rej1 := svc_no_title.choose("escape", NODE, svc_no_title.read_state())
	_check(not bool(rej1.get("ok", true)), "Fix1: choose on missing title refuses without claim")
	_check(not svc_no_title.is_claimed(), "Fix1: unlatched on missing title")

	# 2. Missing description
	var rec_no_desc: Dictionary = raw_event_record.duplicate(true)
	rec_no_desc.erase("description")
	var svc_no_desc := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_no_desc)
	_check(not svc_no_desc.is_valid(), "Fix1: event missing description fails closed")

	# 3. Missing actions
	var rec_no_act: Dictionary = raw_event_record.duplicate(true)
	rec_no_act.erase("actions")
	var svc_no_act := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_no_act)
	_check(not svc_no_act.is_valid(), "Fix1: event missing actions fails closed")

	# 4. Wrong action (not 'unpick')
	var rec_wrong_act: Dictionary = raw_event_record.duplicate(true)
	rec_wrong_act["actions"] = {"sacrifice_part": "repair"}
	var svc_wrong_act := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_wrong_act)
	_check(not svc_wrong_act.is_valid(), "Fix1: event with wrong action fails closed")

	# 5. Choice missing text
	var rec_no_txt: Dictionary = raw_event_record.duplicate(true)
	rec_no_txt["choices"][0].erase("text")
	var svc_no_txt := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_no_txt)
	_check(not svc_no_txt.is_valid(), "Fix1: choice missing text fails closed")

	# 6. Choice missing stitched_effect
	var rec_no_eff: Dictionary = raw_event_record.duplicate(true)
	rec_no_eff["choices"][0].erase("stitched_effect")
	var svc_no_eff := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_no_eff)
	_check(not svc_no_eff.is_valid(), "Fix1: choice missing stitched_effect fails closed")

	# 7. Contradictory sacrifice scraps delta (5 instead of 2)
	var rec_bad_sac: Dictionary = raw_event_record.duplicate(true)
	rec_bad_sac["choices"][0]["stitched_effect"]["scraps"] = 5
	var svc_bad_sac := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_bad_sac)
	_check(not svc_bad_sac.is_valid(), "Fix1: contradictory sacrifice scraps delta fails closed")

	# 8. Contradictory fumigate scraps delta (0 instead of -1)
	var rec_bad_fum: Dictionary = raw_event_record.duplicate(true)
	rec_bad_fum["choices"][1]["stitched_effect"]["scraps"] = 0
	var svc_bad_fum := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_bad_fum)
	_check(not svc_bad_fum.is_valid(), "Fix1: contradictory fumigate scraps delta fails closed")

	# 9. Contradictory escape scraps delta (2 instead of 0)
	var rec_bad_esc: Dictionary = raw_event_record.duplicate(true)
	rec_bad_esc["choices"][2]["stitched_effect"]["scraps"] = 2
	var svc_bad_esc := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_bad_esc)
	_check(not svc_bad_esc.is_valid(), "Fix1: contradictory escape scraps delta fails closed")

	# 10. Contradictory target ("hero" instead of "party")
	var rec_bad_tgt: Dictionary = raw_event_record.duplicate(true)
	rec_bad_tgt["choices"][0]["stitched_effect"]["target"] = "hero"
	var svc_bad_tgt := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_bad_tgt)
	_check(not svc_bad_tgt.is_valid(), "Fix1: target 'hero' on moth event fails closed")

	# 11. Contradictory candle delta (10 instead of 0)
	var rec_bad_cnd: Dictionary = raw_event_record.duplicate(true)
	rec_bad_cnd["choices"][0]["stitched_effect"]["candle"] = 10
	var svc_bad_cnd := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_bad_cnd)
	_check(not svc_bad_cnd.is_valid(), "Fix1: non-zero candle delta fails closed")

	# 12. Contradictory fray delta (20 instead of 0)
	var rec_bad_fry: Dictionary = raw_event_record.duplicate(true)
	rec_bad_fry["choices"][0]["stitched_effect"]["fray"] = 20
	var svc_bad_fry := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_bad_fry)
	_check(not svc_bad_fry.is_valid(), "Fix1: non-zero fray delta fails closed")

	# 13. Bare record with choice IDs only and no title/text/effect
	var rec_bare := {
		"id": "moth_infestation",
		"choices": [{"id": "sacrifice_part"}, {"id": "fumigate"}, {"id": "escape"}]
	}
	var svc_bare := RunStitchedMothSacrificeEvent.open_stitched(NODE, satchel, 2, catalog_by_id, rec_bare)
	_check(not svc_bare.is_valid(), "Fix1: bare choice-IDs-only record fails closed")
	var rej_bare := svc_bare.choose("escape", NODE, svc_bare.read_state())
	_check(not bool(rej_bare.get("ok", true)), "Fix1: choose on bare record refused")
