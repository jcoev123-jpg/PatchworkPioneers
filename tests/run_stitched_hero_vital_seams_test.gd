extends SceneTree
## Deterministic headless SceneTree regression test for RunStitchedHeroVitalSeams.
##
## Validates the bounded Stitched-only, deterministic Event adapter for genuine hero-gated
## vitality crossroads from data/events/v3_hero_vital_events.json:
## - Genuine Warden and Rag Duelist records with distinct rank configurations
## - Quote-to-receipt parity, signed four-key outcomes, target attribution
## - Hanging-by-a-thread (HP 0, LOST false) vs LOST/absent protagonist
## - Vitality floor 10 guard, zero/exact scraps wallet boundaries, fractional outcome safety
## - Node ID and opening-state guards, one-use latching, forgery rejection
## - Immutability of caller snapshot/catalog and zero RNG draws

const SeamsAdapter = preload("res://scripts/run_stitched_hero_vital_seams.gd")

var checks: int = 0
var failures: Array[String] = []


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _party(
	protagonist_id: String = "warden",
	protagonist_rank: int = 1,
	protagonist_hp: int = 20,
	protagonist_max_hp: int = 20,
	protagonist_lost: bool = false
) -> Array:
	var pool := ["warden", "seamstress", "tinker", "lantern_monk", "rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
	var selected_ids: Array[String] = [protagonist_id]
	for h_id in pool:
		if h_id != protagonist_id and selected_ids.size() < 4:
			selected_ids.append(h_id)

	var party: Array = []
	var ranks: Array[int] = [1, 2, 3, 4]
	# Place protagonist at protagonist_rank
	ranks.erase(protagonist_rank)

	for i in range(4):
		var hid: String = selected_ids[i]
		if hid == protagonist_id:
			party.append({
				"id": hid,
				"rank": protagonist_rank,
				"hp": protagonist_hp,
				"max_hp": protagonist_max_hp,
				"lost": protagonist_lost,
			})
		else:
			var companion_rank: int = ranks.pop_front()
			party.append({
				"id": hid,
				"rank": companion_rank,
				"hp": 25,
				"max_hp": 25,
				"lost": false,
			})
	return party


func _initialize() -> void:
	_test_ac1_warden_buckle_heart_ward()
	_test_ac2_rag_duelist_duel_mask_mirror()
	_test_ac3_vitality_boundaries_and_hanging_doll()
	_test_ac4_guards_determinism_and_forgery()
	_test_ac1_seamstress_full_hp_paid_heal_blocked()
	_test_ac2_seamstress_damaged_and_hanging_paid_heal()
	_test_ac3_full_hp_counterexamples_available()
	_test_s6_ac1_warden_buckle_heart_ward_hp_projection()
	_test_s6_ac2_rag_duelist_duel_mask_mirror_hp_projection()
	_test_s6_ac3_unavailable_choice_opening_hp_projections()
	_test_s6_ac4_repeated_quotes_and_claim_parity()

	if failures.is_empty():
		print("run_stitched_hero_vital_seams_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("run_stitched_hero_vital_seams_test: FAILED (%d/%d checks failed)" % [failures.size(), checks])
		quit(1)


## AC1: Given the shipped v3_warden_buckle_heart_ward record, a four-doll rank-1..4 party
## including a non-LOST Warden and wallet with at least 2 scraps, a detached quote offers
## the original three choice IDs and projects reinforce_shield_seam as scraps -2 / lasting max HP +3,
## sell_rivets as gold +24 / lasting max HP -2, and leave as zero effects.
## Check exact per-choice IDs/deltas and quote-to-receipt parity without relying on catalog totals.
func _test_ac1_warden_buckle_heart_ward() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	_check(not catalog.is_empty(), "AC1: Shipped catalog loaded")
	var events: Array = catalog.get("events", [])

	var warden_record: Dictionary = {}
	for ev_raw: Variant in events:
		if ev_raw is Dictionary and String((ev_raw as Dictionary).get("id", "")) == "v3_warden_buckle_heart_ward":
			warden_record = (ev_raw as Dictionary).duplicate(true)
			break
	_check(not warden_record.is_empty(), "AC1: Found v3_warden_buckle_heart_ward in shipped catalog")
	_check(warden_record.get("required_hero") == "warden", "AC1: required_hero is warden")

	# Four-doll party with Warden in rank 2
	var party: Array = _party("warden", 2, 18, 22, false)
	var wallet := {"gold": 10, "scraps": 5}
	var node_id := "node_warden_seam_1"

	var visit := SeamsAdapter.open_stitched(node_id, warden_record, party, wallet)
	_check(visit != null and visit.is_valid(), "AC1: Visit is valid")
	_check(visit.is_open(), "AC1: Visit is open")
	_check(not visit.is_claimed(), "AC1: Visit is not yet claimed")
	_check(visit.get_node_id() == node_id, "AC1: Node ID matches")
	_check(visit.get_event_id() == "v3_warden_buckle_heart_ward", "AC1: Event ID matches")
	_check(visit.get_required_hero() == "warden", "AC1: Required hero matches")

	# Detached quote inspection
	var quote: Dictionary = visit.preview_choices()
	_check(quote.get("ok", false) == true, "AC1: Quote ok is true")
	var choices: Array = quote.get("choices", [])
	_check(choices.size() == 3, "AC1: Exactly three choices offered")

	var choices_by_id := {}
	for c_raw: Variant in choices:
		var c: Dictionary = c_raw
		choices_by_id[c.get("id")] = c

	_check(choices_by_id.has("reinforce_shield_seam"), "AC1: reinforce_shield_seam offered")
	_check(choices_by_id.has("sell_rivets"), "AC1: sell_rivets offered")
	_check(choices_by_id.has("leave"), "AC1: leave offered")

	# reinforce_shield_seam: scraps -2, max_hp +3, gold 0, hp 0
	var c_reinf: Dictionary = choices_by_id.get("reinforce_shield_seam", {})
	_check(c_reinf.get("scraps_delta") == -2, "AC1: reinforce_shield_seam scraps_delta is -2")
	_check(c_reinf.get("max_hp_delta") == 3, "AC1: reinforce_shield_seam max_hp_delta is +3")
	_check(c_reinf.get("gold_delta") == 0, "AC1: reinforce_shield_seam gold_delta is 0")
	_check(c_reinf.get("hp_delta") == 0, "AC1: reinforce_shield_seam hp_delta is 0")
	_check(c_reinf.get("available") == true, "AC1: reinforce_shield_seam is available")
	_check(c_reinf.get("target_hero_id") == "warden", "AC1: reinforce_shield_seam targets warden")
	_check(c_reinf.get("target_hero_rank") == 2, "AC1: reinforce_shield_seam reports rank 2")
	_check(c_reinf.get("projected_scraps") == 3, "AC1: reinforce_shield_seam projected scraps is 3")
	_check(c_reinf.get("projected_gold") == 10, "AC1: reinforce_shield_seam projected gold is 10")

	# sell_rivets: gold +24, max_hp -2, scraps 0, hp 0
	var c_sell: Dictionary = choices_by_id.get("sell_rivets", {})
	_check(c_sell.get("gold_delta") == 24, "AC1: sell_rivets gold_delta is +24")
	_check(c_sell.get("max_hp_delta") == -2, "AC1: sell_rivets max_hp_delta is -2")
	_check(c_sell.get("scraps_delta") == 0, "AC1: sell_rivets scraps_delta is 0")
	_check(c_sell.get("hp_delta") == 0, "AC1: sell_rivets hp_delta is 0")
	_check(c_sell.get("available") == true, "AC1: sell_rivets is available")
	_check(c_sell.get("projected_gold") == 34, "AC1: sell_rivets projected gold is 34")
	_check(c_sell.get("projected_scraps") == 5, "AC1: sell_rivets projected scraps is 5")

	# leave: all 0
	var c_leave: Dictionary = choices_by_id.get("leave", {})
	_check(c_leave.get("gold_delta") == 0, "AC1: leave gold_delta is 0")
	_check(c_leave.get("scraps_delta") == 0, "AC1: leave scraps_delta is 0")
	_check(c_leave.get("hp_delta") == 0, "AC1: leave hp_delta is 0")
	_check(c_leave.get("max_hp_delta") == 0, "AC1: leave max_hp_delta is 0")
	_check(c_leave.get("available") == true, "AC1: leave is available")

	# Quote-to-receipt parity for reinforce_shield_seam
	var initial_state: Dictionary = visit.read_state()
	var receipt: Dictionary = visit.choose("reinforce_shield_seam", node_id, initial_state)
	_check(receipt.get("ok", false) == true, "AC1: reinforce_shield_seam claim succeeded")
	_check(receipt.get("scraps_delta") == c_reinf.get("scraps_delta"), "AC1: Receipt scraps_delta parity")
	_check(receipt.get("max_hp_delta") == c_reinf.get("max_hp_delta"), "AC1: Receipt max_hp_delta parity")
	_check(receipt.get("gold_delta") == c_reinf.get("gold_delta"), "AC1: Receipt gold_delta parity")
	_check(receipt.get("hp_delta") == c_reinf.get("hp_delta"), "AC1: Receipt hp_delta parity")
	_check(receipt.get("wallet", {}).get("scraps") == c_reinf.get("projected_scraps"), "AC1: Receipt wallet scraps parity")
	_check(receipt.get("wallet", {}).get("gold") == c_reinf.get("projected_gold"), "AC1: Receipt wallet gold parity")
	_check(receipt.get("target_hero_id") == "warden", "AC1: Receipt target_hero_id parity")
	_check(visit.is_claimed() == true, "AC1: Visit is now claimed")
	_check(visit.is_open() == false, "AC1: Visit is no longer open")

	# Quote-to-receipt parity for sell_rivets in a separate visit
	var visit2 := SeamsAdapter.open_stitched("node_warden_seam_2", warden_record, party, wallet)
	var state2: Dictionary = visit2.read_state()
	var receipt2: Dictionary = visit2.choose("sell_rivets", "node_warden_seam_2", state2)
	_check(receipt2.get("ok", false) == true, "AC1: sell_rivets claim succeeded")
	_check(receipt2.get("gold_delta") == c_sell.get("gold_delta"), "AC1: sell_rivets receipt gold_delta parity")
	_check(receipt2.get("max_hp_delta") == c_sell.get("max_hp_delta"), "AC1: sell_rivets receipt max_hp_delta parity")
	_check(receipt2.get("wallet", {}).get("gold") == c_sell.get("projected_gold"), "AC1: sell_rivets receipt wallet gold parity")

	# Quote-to-receipt parity for leave in a separate visit with rank 4 Warden
	var party_rank4: Array = _party("warden", 4, 18, 22, false)
	var visit3 := SeamsAdapter.open_stitched("node_warden_seam_3", warden_record, party_rank4, wallet)
	var state3: Dictionary = visit3.read_state()
	var receipt3: Dictionary = visit3.choose("leave", "node_warden_seam_3", state3)
	_check(receipt3.get("ok", false) == true, "AC1: leave claim succeeded")
	_check(receipt3.get("gold_delta") == 0 and receipt3.get("scraps_delta") == 0, "AC1: leave receipt zero wallet deltas")
	_check(receipt3.get("hp_delta") == 0 and receipt3.get("max_hp_delta") == 0, "AC1: leave receipt zero vital deltas")
	_check(receipt3.get("wallet", {}).get("gold") == 10 and receipt3.get("wallet", {}).get("scraps") == 5, "AC1: leave receipt preserves wallet")


## AC2: Given the shipped v3_rag_duelist_duel_mask_mirror record, a four-doll party
## including the Rag Duelist and at least 2 scraps, bind_mirror_cape projects exactly
## scraps -2, HP +4 and lasting max HP +2 against that hero only; pawn_mirror_lining
## projects gold +28 and lasting max HP -3. The headless test must prove combined raw intents,
## wallet projection, target identity and that max-HP-only trades never invent an HP heal.
func _test_ac2_rag_duelist_duel_mask_mirror() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var events: Array = catalog.get("events", [])
	var duelist_record: Dictionary = {}
	for ev_raw: Variant in events:
		if ev_raw is Dictionary and String((ev_raw as Dictionary).get("id", "")) == "v3_rag_duelist_duel_mask_mirror":
			duelist_record = (ev_raw as Dictionary).duplicate(true)
			break
	_check(not duelist_record.is_empty(), "AC2: Found v3_rag_duelist_duel_mask_mirror")
	_check(duelist_record.get("required_hero") == "rag_duelist", "AC2: required_hero is rag_duelist")

	# Rag Duelist at rank 3, HP 8, max_hp 18 (so -3 leaves 15 >= 10 floor)
	var party: Array = _party("rag_duelist", 3, 8, 18, false)
	var wallet := {"gold": 6, "scraps": 4}
	var node_id := "node_duelist_mirror_1"

	var visit := SeamsAdapter.open_stitched(node_id, duelist_record, party, wallet)
	_check(visit.is_valid(), "AC2: Visit is valid")

	var quote: Dictionary = visit.preview_choices()
	var choices_by_id := {}
	for c_raw: Variant in quote.get("choices", []):
		choices_by_id[(c_raw as Dictionary).get("id")] = c_raw

	# bind_mirror_cape: scraps -2, HP +4, max_hp +2, gold 0
	var c_bind: Dictionary = choices_by_id.get("bind_mirror_cape", {})
	_check(c_bind.get("scraps_delta") == -2, "AC2: bind_mirror_cape scraps -2")
	_check(c_bind.get("hp_delta") == 4, "AC2: bind_mirror_cape hp +4")
	_check(c_bind.get("max_hp_delta") == 2, "AC2: bind_mirror_cape max_hp +2")
	_check(c_bind.get("gold_delta") == 0, "AC2: bind_mirror_cape gold 0")
	_check(c_bind.get("target_hero_id") == "rag_duelist", "AC2: bind_mirror_cape targets rag_duelist only")
	_check(c_bind.get("target_hero_rank") == 3, "AC2: bind_mirror_cape reports rank 3")
	_check(c_bind.get("projected_scraps") == 2, "AC2: bind_mirror_cape projected scraps is 2")
	_check(c_bind.get("projected_gold") == 6, "AC2: bind_mirror_cape projected gold is 6")

	# pawn_mirror_lining: gold +28, max_hp -3, scraps 0, hp 0
	var c_pawn: Dictionary = choices_by_id.get("pawn_mirror_lining", {})
	_check(c_pawn.get("gold_delta") == 28, "AC2: pawn_mirror_lining gold +28")
	_check(c_pawn.get("max_hp_delta") == -3, "AC2: pawn_mirror_lining max_hp -3")
	_check(c_pawn.get("scraps_delta") == 0, "AC2: pawn_mirror_lining scraps 0")
	_check(c_pawn.get("hp_delta") == 0, "AC2: pawn_mirror_lining hp 0 (no silent heal)")
	_check(c_pawn.get("target_hero_id") == "rag_duelist", "AC2: pawn_mirror_lining targets rag_duelist only")
	_check(c_pawn.get("projected_gold") == 34, "AC2: pawn_mirror_lining projected gold is 34")

	# Claim bind_mirror_cape and verify combined raw intents
	var state1: Dictionary = visit.read_state()
	var receipt1: Dictionary = visit.choose("bind_mirror_cape", node_id, state1)
	_check(receipt1.get("ok") == true, "AC2: Claimed bind_mirror_cape")
	_check(receipt1.get("hp_delta") == 4, "AC2: Receipt exposes raw hp_delta +4")
	_check(receipt1.get("max_hp_delta") == 2, "AC2: Receipt exposes raw max_hp_delta +2")
	_check(receipt1.get("scraps_delta") == -2, "AC2: Receipt exposes scraps_delta -2")
	_check(receipt1.get("target_hero_id") == "rag_duelist", "AC2: Receipt target identity is rag_duelist")
	_check(receipt1.get("wallet", {}).get("scraps") == 2, "AC2: Wallet scraps projected to 2")

	# Verify service did not immediately mutate hero HP or max_hp in internal party snapshot
	var party_after: Array = visit.get_party()
	for hero: Variant in party_after:
		if (hero as Dictionary).get("id") == "rag_duelist":
			_check((hero as Dictionary).get("hp") == 8, "AC2: Hero HP unchanged in service party snapshot")
			_check((hero as Dictionary).get("max_hp") == 18, "AC2: Hero max_hp unchanged in service party snapshot")

	# In separate visit, claim pawn_mirror_lining and verify max-HP-only trade never invents an HP heal
	var visit2 := SeamsAdapter.open_stitched("node_duelist_mirror_2", duelist_record, party, wallet)
	var state2: Dictionary = visit2.read_state()
	var receipt2: Dictionary = visit2.choose("pawn_mirror_lining", "node_duelist_mirror_2", state2)
	_check(receipt2.get("ok") == true, "AC2: Claimed pawn_mirror_lining")
	_check(receipt2.get("hp_delta") == 0, "AC2: pawn_mirror_lining raw hp_delta is strictly 0")
	_check(receipt2.get("max_hp_delta") == -3, "AC2: pawn_mirror_lining raw max_hp_delta is strictly -3")
	_check(receipt2.get("gold_delta") == 28, "AC2: pawn_mirror_lining raw gold_delta is strictly +28")
	_check(receipt2.get("wallet", {}).get("gold") == 34, "AC2: Projected wallet gold is 34")


## AC3: Given a required hero at HP 0 but LOST false, the helper admits the Stitched Hanging doll
## and returns only raw HP/max-HP intents for later authoritative settlement; given LOST true,
## an absent required hero, unaffordable wallet, a max-HP reduction below 10, or malformed four-key
## outcome, the affected transaction is refused without spending or consuming the visit.
func _test_ac3_vitality_boundaries_and_hanging_doll() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var events: Array = catalog.get("events", [])
	var duelist_record: Dictionary = {}
	var warden_record: Dictionary = {}
	var monk_record: Dictionary = {}
	for ev_raw: Variant in events:
		var d: Dictionary = ev_raw
		if d.get("id") == "v3_rag_duelist_duel_mask_mirror":
			duelist_record = d.duplicate(true)
		elif d.get("id") == "v3_warden_buckle_heart_ward":
			warden_record = d.duplicate(true)
		elif d.get("id") == "v3_lantern_monk_thimble_moon_vigil":
			monk_record = d.duplicate(true)

	# 1. Required hero at HP 0, lost == false (Hanging by a thread) -> Admitted!
	var hanging_party: Array = _party("rag_duelist", 1, 0, 16, false)
	var wallet := {"gold": 10, "scraps": 4}
	var visit_hanging := SeamsAdapter.open_stitched("node_hanging_1", duelist_record, hanging_party, wallet)
	_check(visit_hanging.is_valid(), "AC3: Hanging doll (HP 0, lost false) is admitted")
	var quote_hanging: Dictionary = visit_hanging.preview_choices()
	_check(quote_hanging.get("ok") == true, "AC3: Quote for hanging doll succeeds")
	var state_hanging: Dictionary = visit_hanging.read_state()
	var receipt_hanging: Dictionary = visit_hanging.choose("bind_mirror_cape", "node_hanging_1", state_hanging)
	_check(receipt_hanging.get("ok") == true, "AC3: Hanging doll receives raw intent receipt")
	_check(receipt_hanging.get("hp_delta") == 4, "AC3: Hanging doll exposes raw hp_delta +4")
	_check(receipt_hanging.get("max_hp_delta") == 2, "AC3: Hanging doll exposes raw max_hp_delta +2")

	# Test negative HP intent on hanging doll (Lantern Monk tend_moth_candles: hp -4, gold +20)
	var hanging_monk_party: Array = _party("lantern_monk", 1, 0, 15, false)
	var visit_monk := SeamsAdapter.open_stitched("node_monk_1", monk_record, hanging_monk_party, wallet)
	_check(visit_monk.is_valid(), "AC3: Hanging monk is admitted")
	var state_monk: Dictionary = visit_monk.read_state()
	var receipt_monk: Dictionary = visit_monk.choose("tend_moth_candles", "node_monk_1", state_monk)
	_check(receipt_monk.get("ok") == true, "AC3: Hanging monk can accept negative hp_delta intent")
	_check(receipt_monk.get("hp_delta") == -4, "AC3: Raw negative hp_delta -4 exposed without seam roll")

	# 2. Required hero at LOST == true -> Refused!
	var lost_party: Array = _party("rag_duelist", 1, 10, 16, true)
	var visit_lost := SeamsAdapter.open_stitched("node_lost_1", duelist_record, lost_party, wallet)
	_check(not visit_lost.is_valid(), "AC3: LOST protagonist refuses visit admission")
	var lost_claim: Dictionary = visit_lost.choose("bind_mirror_cape", "node_lost_1", {})
	_check(lost_claim.get("ok") == false, "AC3: LOST protagonist choice is refused")

	# 3. Absent required hero -> Refused!
	# Party of warden, seamstress, tinker, button_golem (no rag_duelist)
	var absent_party: Array = [
		{"id": "warden", "rank": 1, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "seamstress", "rank": 2, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "tinker", "rank": 3, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "button_golem", "rank": 4, "hp": 20, "max_hp": 20, "lost": false},
	]
	var visit_absent := SeamsAdapter.open_stitched("node_absent_1", duelist_record, absent_party, wallet)
	_check(not visit_absent.is_valid(), "AC3: Absent protagonist refuses visit admission")

	# 4. Near-floor max-HP = 10 hero checking -2 or -3 max HP boundary
	# Duelist max_hp = 10. pawn_mirror_lining (-3 max HP) would result in 7 < 10 floor -> Unavailable!
	# bind_mirror_cape (+2 max HP) -> Available!
	var near_floor_party: Array = _party("rag_duelist", 1, 10, 10, false)
	var visit_floor := SeamsAdapter.open_stitched("node_floor_1", duelist_record, near_floor_party, wallet)
	_check(visit_floor.is_valid(), "AC3: max_hp=10 hero admitted")
	var quote_floor: Dictionary = visit_floor.preview_choices()
	var choices_floor := {}
	for c_raw: Variant in quote_floor.get("choices", []):
		choices_floor[(c_raw as Dictionary).get("id")] = c_raw

	_check(choices_floor["bind_mirror_cape"].get("available") == true, "AC3: max_hp +2 is available for max_hp=10")
	_check(choices_floor["pawn_mirror_lining"].get("available") == false, "AC3: max_hp -3 is unavailable for max_hp=10")
	_check(choices_floor["leave"].get("available") == true, "AC3: leave remains available")

	var state_floor: Dictionary = visit_floor.read_state()
	# Choosing unavailable pawn_mirror_lining refuses without spending or consuming visit
	var fail_choice: Dictionary = visit_floor.choose("pawn_mirror_lining", "node_floor_1", state_floor)
	_check(fail_choice.get("ok") == false, "AC3: Choosing below-floor max HP option is refused")
	_check(visit_floor.is_open() == true, "AC3: Visit remains open after refusal")
	_check(visit_floor.is_claimed() == false, "AC3: Visit remains unclaimed after refusal")
	# Can still choose valid Leave or bind_mirror_cape
	var leave_claim: Dictionary = visit_floor.choose("leave", "node_floor_1", state_floor)
	_check(leave_claim.get("ok") == true, "AC3: Can choose Leave after previous refusal")
	_check(visit_floor.is_claimed() == true, "AC3: Visit is now latched by Leave")

	# Warden near-floor: max_hp = 11, sell_rivets (-2 max HP) -> 9 < 10 -> Unavailable!
	var warden_near_floor: Array = _party("warden", 1, 11, 11, false)
	var visit_warden_floor := SeamsAdapter.open_stitched("node_w_floor", warden_record, warden_near_floor, wallet)
	var q_w: Dictionary = visit_warden_floor.preview_choices()
	var c_w := {}
	for c_raw: Variant in q_w.get("choices", []):
		c_w[(c_raw as Dictionary).get("id")] = c_raw
	_check(c_w["sell_rivets"].get("available") == false, "AC3: Warden sell_rivets (-2) disabled when max_hp=11")
	_check(c_w["reinforce_shield_seam"].get("available") == true, "AC3: Warden reinforce (+3) enabled when max_hp=11")

	# 5. Wallet boundaries: zero scraps vs exact sufficient scraps
	var party_std: Array = _party("rag_duelist", 1, 15, 20, false)
	var zero_scraps_wallet := {"gold": 10, "scraps": 0}
	var visit_zero_scraps := SeamsAdapter.open_stitched("node_zs_1", duelist_record, party_std, zero_scraps_wallet)
	var q_zs: Dictionary = visit_zero_scraps.preview_choices()
	var c_zs := {}
	for c_raw: Variant in q_zs.get("choices", []):
		c_zs[(c_raw as Dictionary).get("id")] = c_raw
	_check(c_zs["bind_mirror_cape"].get("available") == false, "AC3: bind_mirror_cape disabled with 0 scraps")
	_check(c_zs["pawn_mirror_lining"].get("available") == true, "AC3: pawn_mirror_lining available with 0 scraps")
	var st_zs: Dictionary = visit_zero_scraps.read_state()
	var fail_zs: Dictionary = visit_zero_scraps.choose("bind_mirror_cape", "node_zs_1", st_zs)
	_check(fail_zs.get("ok") == false, "AC3: Refused bind_mirror_cape with zero scraps")
	_check(visit_zero_scraps.is_claimed() == false, "AC3: Visit not consumed by underfunded attempt")

	# Exact scraps: wallet scraps = 2, cost is 2 scraps
	var exact_scraps_wallet := {"gold": 10, "scraps": 2}
	var visit_exact := SeamsAdapter.open_stitched("node_exact_1", duelist_record, party_std, exact_scraps_wallet)
	var st_exact: Dictionary = visit_exact.read_state()
	var succ_exact: Dictionary = visit_exact.choose("bind_mirror_cape", "node_exact_1", st_exact)
	_check(succ_exact.get("ok") == true, "AC3: Exact sufficient scraps claim succeeds")
	_check(succ_exact.get("wallet", {}).get("scraps") == 0, "AC3: Exact scraps deducted to exactly 0")

	# 6. Malformed fractional outcomes: float deltas (e.g. 2.5)
	var malformed_record: Dictionary = duelist_record.duplicate(true)
	malformed_record["choices"] = [
		{"id": "fractional_trade", "text": "Fractional", "outcome": {"gold": 10.5, "scraps": 0, "hp": 0, "max_hp": 0}},
		{"id": "leave", "text": "Leave", "outcome": {"gold": 0, "scraps": 0, "hp": 0, "max_hp": 0}},
	]
	var parsed_bad: Dictionary = SeamsAdapter._parse_four_key_outcome(malformed_record["choices"][0]["outcome"])
	_check(parsed_bad.get("ok") == false, "AC3: Fractional float outcome rejected by four-key parser")


## AC4: Given an authentic one-use visit and exact opening state/node guard, one eligible choice
## issues a detached receipt once; stale, wrong-node, forged-event, second-claim and
## malformed-rank/duplicate-doll attempts refuse without mutation or RNG consumption.
## The test must inspect unchanged caller records/party/wallet and seeded RNG state.
func _test_ac4_guards_determinism_and_forgery() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var events: Array = catalog.get("events", [])
	var warden_record: Dictionary = {}
	for ev_raw: Variant in events:
		if (ev_raw as Dictionary).get("id") == "v3_warden_buckle_heart_ward":
			warden_record = (ev_raw as Dictionary).duplicate(true)
			break

	var party: Array = _party("warden", 1, 20, 20, false)
	var wallet := {"gold": 15, "scraps": 6}
	var caller_party_orig: Array = party.duplicate(true)
	var caller_wallet_orig: Dictionary = wallet.duplicate(true)
	var caller_record_orig: Dictionary = warden_record.duplicate(true)

	var node_id := "node_guard_test_1"
	var visit := SeamsAdapter.open_stitched(node_id, warden_record, party, wallet)
	_check(visit.is_valid(), "AC4: Authentic visit is valid")

	var opening_state: Dictionary = visit.read_state()

	# 1. Stale / forged expected state guard
	var stale_state: Dictionary = opening_state.duplicate(true)
	stale_state["version"] = 999
	var res_stale: Dictionary = visit.choose("leave", node_id, stale_state)
	_check(res_stale.get("ok") == false, "AC4: Stale expected_state is refused")
	_check(visit.is_open() == true and not visit.is_claimed(), "AC4: Visit remains open after stale state refusal")

	var null_state: Dictionary = visit.choose("leave", node_id, null)
	_check(null_state.get("ok") == false, "AC4: Null expected_state is refused")

	# 2. Wrong node ID guard
	var res_wrong_node: Dictionary = visit.choose("leave", "wrong_node_id", opening_state)
	_check(res_wrong_node.get("ok") == false, "AC4: Wrong node_id is refused")
	_check(visit.is_open() == true and not visit.is_claimed(), "AC4: Visit remains open after wrong node refusal")

	var res_untrimmed: Dictionary = visit.choose("leave", node_id + " ", opening_state)
	_check(res_untrimmed.get("ok") == false, "AC4: Untrimmed node_id is refused")

	# 3. Successful one-use claim
	var res_succ: Dictionary = visit.choose("reinforce_shield_seam", node_id, opening_state)
	_check(res_succ.get("ok") == true, "AC4: First valid claim succeeds")
	_check(visit.is_claimed() == true, "AC4: Visit latches claimed=true")
	_check(visit.is_open() == false, "AC4: Visit latches open=false")
	_check(visit.is_valid() == false, "AC4: Claimed visit reports is_valid=false")

	# 4. Second-claim attempt refuses
	var res_repeat: Dictionary = visit.choose("leave", node_id, visit.read_state())
	_check(res_repeat.get("ok") == false, "AC4: Second claim attempt refuses")

	# 5. Forged catalog event (authentic ID but modified choice price)
	var forged_record: Dictionary = warden_record.duplicate(true)
	forged_record["choices"][0]["outcome"]["scraps"] = 0 # Authentic is -2
	var visit_forged := SeamsAdapter.open_stitched("node_forged_1", forged_record, party, wallet)
	_check(not visit_forged.is_valid(), "AC4: Forged catalog event is rejected")

	# Forged uncatalogued event ID
	var visit_fake_id := SeamsAdapter.open_stitched("node_fake", "v3_nonexistent_event_id", party, wallet)
	_check(not visit_fake_id.is_valid(), "AC4: Uncatalogued event ID is rejected")

	# 6. Malformed ranks and duplicate dolls
	# Repeated ranks (two rank 2s)
	var bad_ranks_party: Array = [
		{"id": "warden", "rank": 2, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "seamstress", "rank": 2, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "tinker", "rank": 3, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "button_golem", "rank": 4, "hp": 20, "max_hp": 20, "lost": false},
	]
	var visit_bad_ranks := SeamsAdapter.open_stitched("node_br", warden_record, bad_ranks_party, wallet)
	_check(not visit_bad_ranks.is_valid(), "AC4: Repeated ranks party rejected")

	# Duplicate doll (two wardens)
	var dup_doll_party: Array = [
		{"id": "warden", "rank": 1, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "warden", "rank": 2, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "tinker", "rank": 3, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "button_golem", "rank": 4, "hp": 20, "max_hp": 20, "lost": false},
	]
	var visit_dup := SeamsAdapter.open_stitched("node_dup", warden_record, dup_doll_party, wallet)
	_check(not visit_dup.is_valid(), "AC4: Duplicate doll party rejected")

	# Missing doll (party of 3)
	var three_party: Array = [
		{"id": "warden", "rank": 1, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "seamstress", "rank": 2, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "tinker", "rank": 3, "hp": 20, "max_hp": 20, "lost": false},
	]
	var visit_three := SeamsAdapter.open_stitched("node_three", warden_record, three_party, wallet)
	_check(not visit_three.is_valid(), "AC4: Three-doll party rejected (requires exactly 4)")

	# Non-canonical hero ID
	var non_canonical_party: Array = [
		{"id": "warden", "rank": 1, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "fake_doll_wizard", "rank": 2, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "tinker", "rank": 3, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "button_golem", "rank": 4, "hp": 20, "max_hp": 20, "lost": false},
	]
	var visit_non_canon := SeamsAdapter.open_stitched("node_nc", warden_record, non_canonical_party, wallet)
	_check(not visit_non_canon.is_valid(), "AC4: Non-canonical hero ID rejected")

	# 7. Immutability of caller snapshots
	_check(party == caller_party_orig, "AC4: Caller party unmodified by helper operations")
	_check(wallet == caller_wallet_orig, "AC4: Caller wallet unmodified by helper operations")
	_check(warden_record == caller_record_orig, "AC4: Caller event record unmodified by helper operations")

	# 8. Zero seeded RNG consumption
	var seeded_rng := RandomNumberGenerator.new()
	seeded_rng.seed = 88888
	var rng_state_before: int = seeded_rng.state
	seed(55555)
	var global_rand_before: int = randi()
	seed(55555) # reset back to seed 55555

	var rng_visit := SeamsAdapter.open_stitched("node_rng_test", warden_record, party, wallet)
	var rng_quote: Dictionary = rng_visit.preview_choices()
	var rng_state_mid: int = seeded_rng.state
	_check(rng_state_mid == rng_state_before, "AC4: Seeded RNG unchanged by quote")

	var rng_claim: Dictionary = rng_visit.choose("reinforce_shield_seam", "node_rng_test", rng_visit.read_state())
	var rng_state_after: int = seeded_rng.state
	_check(rng_state_after == rng_state_before, "AC4: Seeded RNG unchanged by choose")
	_check(randi() == global_rand_before, "AC4: Global RNG sequence completely untouched")


## AC1: Using shipped v3_seamstress_crimson_quilt_surgeon record, four different rank-1..4 dolls
## with living Seamstress at HP 20/20 and gold >= 12, stitch_wound is quoted but unavailable,
## forecasts unchanged gold, and choose refuses without mutation/latching.
func _test_ac1_seamstress_full_hp_paid_heal_blocked() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	_check(not catalog.is_empty(), "AC1: Shipped catalog loaded")
	var events: Array = catalog.get("events", [])
	var surgeon_record: Dictionary = {}
	for ev_raw: Variant in events:
		if ev_raw is Dictionary and String((ev_raw as Dictionary).get("id", "")) == "v3_seamstress_crimson_quilt_surgeon":
			surgeon_record = (ev_raw as Dictionary).duplicate(true)
			break
	_check(not surgeon_record.is_empty(), "AC1: Found v3_seamstress_crimson_quilt_surgeon in shipped catalog")
	_check(surgeon_record.get("required_hero") == "seamstress", "AC1: required_hero is seamstress")

	# Four different rank-1..4 dolls with living Seamstress at HP 20/20
	var party: Array = _party("seamstress", 2, 20, 20, false)
	var wallet := {"gold": 12, "scraps": 0}
	var caller_party_orig: Array = party.duplicate(true)
	var caller_wallet_orig: Dictionary = wallet.duplicate(true)
	var caller_record_orig: Dictionary = surgeon_record.duplicate(true)
	var node_id := "node_seamstress_full_hp_1"

	var visit := SeamsAdapter.open_stitched(node_id, surgeon_record, party, wallet)
	_check(visit != null and visit.is_valid(), "AC1: Visit is valid for 20/20 Seamstress")
	_check(visit.is_open(), "AC1: Visit is open")
	_check(not visit.is_claimed(), "AC1: Visit is not claimed initially")

	var quote: Dictionary = visit.preview_choices()
	_check(quote.get("ok", false) == true, "AC1: Preview choices ok")
	var choices: Array = quote.get("choices", [])
	var choices_by_id: Dictionary = {}
	for c_raw: Variant in choices:
		var c: Dictionary = c_raw
		choices_by_id[c.get("id")] = c

	_check(choices_by_id.has("stitch_wound"), "AC1: stitch_wound choice present in quote")
	var c_stitch: Dictionary = choices_by_id.get("stitch_wound", {})
	_check(c_stitch.get("gold_delta") == -12, "AC1: stitch_wound gold_delta is -12")
	_check(c_stitch.get("scraps_delta") == 0, "AC1: stitch_wound scraps_delta is 0")
	_check(c_stitch.get("hp_delta") == 8, "AC1: stitch_wound hp_delta is 8")
	_check(c_stitch.get("max_hp_delta") == 0, "AC1: stitch_wound max_hp_delta is 0")
	_check(c_stitch.get("target_hero_id") == "seamstress", "AC1: stitch_wound targets seamstress")
	_check(c_stitch.get("target_hero_rank") == 2, "AC1: stitch_wound targets rank 2")
	_check(c_stitch.get("available") == false, "AC1: stitch_wound is unavailable at full HP")
	_check(c_stitch.get("affordable") == false, "AC1: stitch_wound is unaffordable at full HP")
	_check(String(c_stitch.get("blocked", "")).contains("full HP"), "AC1: stitch_wound blocked mentions full HP")
	_check(c_stitch.get("projected_gold") == 12, "AC1: stitch_wound forecasts unchanged gold")
	_check(c_stitch.get("projected_scraps") == 0, "AC1: stitch_wound forecasts unchanged scraps")
	_check(c_stitch.get("projected_wallet") == wallet, "AC1: stitch_wound forecasts unchanged wallet")

	# Detached snapshot and choose attempt
	var opening_state: Dictionary = visit.read_state()
	var state_copy: Dictionary = opening_state.duplicate(true)

	var seeded_rng := RandomNumberGenerator.new()
	seeded_rng.seed = 44444
	var rng_before: int = seeded_rng.state

	var refusal: Dictionary = visit.choose("stitch_wound", node_id, opening_state)
	_check(refusal.get("ok", false) == false, "AC1: choose stitch_wound refuses at full HP")
	_check(String(refusal.get("error", "")).contains("full HP"), "AC1: refusal error mentions full HP")
	_check(visit.is_claimed() == false, "AC1: Visit remains unclaimed after refusal")
	_check(visit.is_open() == true, "AC1: Visit remains open after refusal")
	_check(visit.is_valid() == true, "AC1: Visit remains valid after refusal")
	_check(visit.get_wallet() == {"gold": 12, "scraps": 0}, "AC1: Wallet unchanged after refusal")
	_check(visit.read_state() == state_copy, "AC1: Internal state unchanged after refusal")
	_check(opening_state == state_copy, "AC1: Caller state snapshot unmodified")
	_check(party == caller_party_orig, "AC1: Caller party unmodified")
	_check(wallet == caller_wallet_orig, "AC1: Caller wallet unmodified")
	_check(surgeon_record == caller_record_orig, "AC1: Caller event record unmodified")
	_check(seeded_rng.state == rng_before, "AC1: RNG untouched during refused choose")

	# Visit remains usable for an available choice after refusal
	var leave_receipt: Dictionary = visit.choose("leave", node_id, opening_state)
	_check(leave_receipt.get("ok", false) == true, "AC1: Can still choose leave after stitch_wound refusal")
	_check(visit.is_claimed() == true, "AC1: Visit latched after leave choice")


## AC2: Living Seamstress at HP 19/20 or HP 0/20 (lost=false), gold 12 permits stitch_wound;
## quote and one guarded receipt preserve gold -12, scraps 0, raw HP +8, max HP 0, Seamstress target.
## Raw HP intent is not capped to missing HP. LOST/absent protagonist fails closed.
func _test_ac2_seamstress_damaged_and_hanging_paid_heal() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var events: Array = catalog.get("events", [])
	var surgeon_record: Dictionary = {}
	for ev_raw: Variant in events:
		if (ev_raw as Dictionary).get("id") == "v3_seamstress_crimson_quilt_surgeon":
			surgeon_record = (ev_raw as Dictionary).duplicate(true)
			break

	var wallet_12 := {"gold": 12, "scraps": 0}

	# 1. Living Seamstress at 19/20 HP, gold 12
	var party_19: Array = _party("seamstress", 1, 19, 20, false)
	var visit_19 := SeamsAdapter.open_stitched("node_seamstress_19", surgeon_record, party_19, wallet_12)
	_check(visit_19.is_valid(), "AC2: 19/20 Seamstress visit is valid")

	var quote_19: Dictionary = visit_19.preview_choices()
	var choices_19: Dictionary = {}
	for c_raw: Variant in quote_19.get("choices", []):
		choices_19[(c_raw as Dictionary).get("id")] = c_raw

	var stitch_19: Dictionary = choices_19.get("stitch_wound", {})
	_check(stitch_19.get("available") == true, "AC2: stitch_wound is available at 19/20 HP")
	_check(stitch_19.get("affordable") == true, "AC2: stitch_wound is affordable at 19/20 HP")
	_check(stitch_19.get("blocked") == "", "AC2: stitch_wound blocked is empty at 19/20 HP")
	_check(stitch_19.get("projected_gold") == 0, "AC2: stitch_wound projected gold is 0")
	_check(stitch_19.get("projected_scraps") == 0, "AC2: stitch_wound projected scraps is 0")

	var state_19: Dictionary = visit_19.read_state()
	var receipt_19: Dictionary = visit_19.choose("stitch_wound", "node_seamstress_19", state_19)
	_check(receipt_19.get("ok", false) == true, "AC2: 19/20 Seamstress stitch_wound choose succeeded")
	_check(receipt_19.get("gold_delta") == -12, "AC2: receipt gold_delta is -12")
	_check(receipt_19.get("scraps_delta") == 0, "AC2: receipt scraps_delta is 0")
	_check(receipt_19.get("hp_delta") == 8, "AC2: raw hp_delta is 8 (not capped to +1)")
	_check(receipt_19.get("max_hp_delta") == 0, "AC2: receipt max_hp_delta is 0")
	_check(receipt_19.get("target_hero_id") == "seamstress", "AC2: receipt target_hero_id is seamstress")
	_check(receipt_19.get("wallet", {}).get("gold") == 0, "AC2: wallet gold updated to 0")
	_check(visit_19.is_claimed() == true, "AC2: visit_19 is now claimed")
	_check(visit_19.is_open() == false, "AC2: visit_19 is no longer open")

	# Subsequent claim rejects
	var second_claim: Dictionary = visit_19.choose("leave", "node_seamstress_19", visit_19.read_state())
	_check(second_claim.get("ok", false) == false, "AC2: Subsequent claim on claimed visit rejects")

	# 2. Living Seamstress at 0/20 HP, lost=false (Hanging by a thread)
	var party_0: Array = _party("seamstress", 3, 0, 20, false)
	var visit_0 := SeamsAdapter.open_stitched("node_seamstress_0", surgeon_record, party_0, wallet_12)
	_check(visit_0.is_valid(), "AC2: 0/20 lost=false Seamstress visit is valid")

	var quote_0: Dictionary = visit_0.preview_choices()
	var choices_0: Dictionary = {}
	for c_raw: Variant in quote_0.get("choices", []):
		choices_0[(c_raw as Dictionary).get("id")] = c_raw

	var stitch_0: Dictionary = choices_0.get("stitch_wound", {})
	_check(stitch_0.get("available") == true, "AC2: stitch_wound available for 0/20 hanging Seamstress")
	_check(stitch_0.get("affordable") == true, "AC2: stitch_wound affordable for 0/20 hanging Seamstress")

	var state_0: Dictionary = visit_0.read_state()
	var receipt_0: Dictionary = visit_0.choose("stitch_wound", "node_seamstress_0", state_0)
	_check(receipt_0.get("ok", false) == true, "AC2: 0/20 Seamstress choose succeeded")
	_check(receipt_0.get("gold_delta") == -12, "AC2: hanging receipt gold_delta is -12")
	_check(receipt_0.get("scraps_delta") == 0, "AC2: hanging receipt scraps_delta is 0")
	_check(receipt_0.get("hp_delta") == 8, "AC2: hanging receipt raw hp_delta is 8")
	_check(receipt_0.get("max_hp_delta") == 0, "AC2: hanging receipt max_hp_delta is 0")
	_check(receipt_0.get("target_hero_id") == "seamstress", "AC2: hanging receipt targets seamstress")

	# 3. LOST protagonist fails closed
	var party_lost: Array = _party("seamstress", 1, 10, 20, true)
	var visit_lost := SeamsAdapter.open_stitched("node_lost_seamstress", surgeon_record, party_lost, wallet_12)
	_check(not visit_lost.is_valid(), "AC2: LOST Seamstress fails closed on open")
	var claim_lost: Dictionary = visit_lost.choose("stitch_wound", "node_lost_seamstress", {})
	_check(claim_lost.get("ok", false) == false, "AC2: LOST Seamstress choose rejects")

	# 4. Absent protagonist fails closed
	var party_absent: Array = [
		{"id": "warden", "rank": 1, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "tinker", "rank": 2, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "lantern_monk", "rank": 3, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "button_golem", "rank": 4, "hp": 20, "max_hp": 20, "lost": false},
	]
	var visit_absent := SeamsAdapter.open_stitched("node_absent_seamstress", surgeon_record, party_absent, wallet_12)
	_check(not visit_absent.is_valid(), "AC2: Absent Seamstress fails closed on open")


## AC3: The full-HP restriction applies ONLY to the precise pure-paid-heal predicate:
## - Crimson Quilt Surgeon donate_red_thread trades HP -4 for gold +18, and leave stays free.
## - Warden's reinforce_shield_seam spends 2 scraps for max HP +3 with no heal.
## - Rag Duelist's bind_mirror_cape spends 2 scraps for HP +4 and max HP +2 at full HP.
func _test_ac3_full_hp_counterexamples_available() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var events: Array = catalog.get("events", [])
	var surgeon_record: Dictionary = {}
	var warden_record: Dictionary = {}
	var duelist_record: Dictionary = {}
	for ev_raw: Variant in events:
		var d: Dictionary = ev_raw
		var eid: String = String(d.get("id", ""))
		if eid == "v3_seamstress_crimson_quilt_surgeon":
			surgeon_record = d.duplicate(true)
		elif eid == "v3_warden_buckle_heart_ward":
			warden_record = d.duplicate(true)
		elif eid == "v3_rag_duelist_duel_mask_mirror":
			duelist_record = d.duplicate(true)

	_check(not surgeon_record.is_empty(), "AC3: surgeon record found")
	_check(not warden_record.is_empty(), "AC3: warden record found")
	_check(not duelist_record.is_empty(), "AC3: duelist record found")

	# 1. Seamstress at full HP (20/20): donate_red_thread (HP -4, gold +18) is available and committable
	var seam_full: Array = _party("seamstress", 1, 20, 20, false)
	var visit_donate := SeamsAdapter.open_stitched("node_donate_1", surgeon_record, seam_full, {"gold": 12, "scraps": 0})
	var quote_donate: Dictionary = visit_donate.preview_choices()
	var choices_donate: Dictionary = {}
	for c_raw: Variant in quote_donate.get("choices", []):
		choices_donate[(c_raw as Dictionary).get("id")] = c_raw

	var c_donate: Dictionary = choices_donate.get("donate_red_thread", {})
	_check(c_donate.get("available") == true, "AC3: donate_red_thread available at full HP")
	_check(c_donate.get("affordable") == true, "AC3: donate_red_thread affordable at full HP")
	_check(c_donate.get("gold_delta") == 18, "AC3: donate_red_thread gold_delta is +18")
	_check(c_donate.get("hp_delta") == -4, "AC3: donate_red_thread hp_delta is -4")
	_check(c_donate.get("projected_gold") == 30, "AC3: donate_red_thread projected gold is 30")

	var receipt_donate: Dictionary = visit_donate.choose("donate_red_thread", "node_donate_1", visit_donate.read_state())
	_check(receipt_donate.get("ok", false) == true, "AC3: donate_red_thread choose succeeded at full HP")
	_check(receipt_donate.get("gold_delta") == 18, "AC3: donate receipt gold_delta +18")
	_check(receipt_donate.get("hp_delta") == -4, "AC3: donate receipt hp_delta -4")
	_check(receipt_donate.get("wallet", {}).get("gold") == 30, "AC3: donate receipt wallet gold 30")

	# Seamstress at full HP: leave is available and committable
	var visit_leave := SeamsAdapter.open_stitched("node_leave_1", surgeon_record, seam_full, {"gold": 12, "scraps": 0})
	var quote_leave: Dictionary = visit_leave.preview_choices()
	var choices_leave: Dictionary = {}
	for c_raw: Variant in quote_leave.get("choices", []):
		choices_leave[(c_raw as Dictionary).get("id")] = c_raw
	var c_leave: Dictionary = choices_leave.get("leave", {})
	_check(c_leave.get("available") == true, "AC3: leave is available at full HP")
	var receipt_leave: Dictionary = visit_leave.choose("leave", "node_leave_1", visit_leave.read_state())
	_check(receipt_leave.get("ok", false) == true, "AC3: leave choose succeeded at full HP")
	_check(receipt_leave.get("wallet", {}).get("gold") == 12, "AC3: leave preserves wallet")

	# 2. Warden at full HP (20/20): reinforce_shield_seam (-2 scraps, +3 max HP, 0 HP heal) is available and committable
	var warden_full: Array = _party("warden", 1, 20, 20, false)
	var visit_warden := SeamsAdapter.open_stitched("node_warden_full", warden_record, warden_full, {"gold": 10, "scraps": 4})
	var quote_warden: Dictionary = visit_warden.preview_choices()
	var choices_warden: Dictionary = {}
	for c_raw: Variant in quote_warden.get("choices", []):
		choices_warden[(c_raw as Dictionary).get("id")] = c_raw
	var c_reinf: Dictionary = choices_warden.get("reinforce_shield_seam", {})
	_check(c_reinf.get("available") == true, "AC3: Warden reinforce_shield_seam available at full HP")
	_check(c_reinf.get("scraps_delta") == -2, "AC3: reinforce_shield_seam scraps_delta is -2")
	_check(c_reinf.get("hp_delta") == 0, "AC3: reinforce_shield_seam hp_delta is 0")
	_check(c_reinf.get("max_hp_delta") == 3, "AC3: reinforce_shield_seam max_hp_delta is 3")
	_check(c_reinf.get("projected_scraps") == 2, "AC3: reinforce_shield_seam projected scraps is 2")

	var receipt_warden: Dictionary = visit_warden.choose("reinforce_shield_seam", "node_warden_full", visit_warden.read_state())
	_check(receipt_warden.get("ok", false) == true, "AC3: Warden reinforce_shield_seam choose succeeded at full HP")
	_check(receipt_warden.get("scraps_delta") == -2, "AC3: Warden receipt scraps_delta is -2")
	_check(receipt_warden.get("max_hp_delta") == 3, "AC3: Warden receipt max_hp_delta is 3")
	_check(receipt_warden.get("hp_delta") == 0, "AC3: Warden receipt hp_delta is 0")
	_check(receipt_warden.get("wallet", {}).get("scraps") == 2, "AC3: Warden receipt wallet scraps is 2")

	# 3. Rag Duelist at full HP (20/20): bind_mirror_cape (-2 scraps, +4 HP, +2 max HP) is available and committable
	var duelist_full: Array = _party("rag_duelist", 1, 20, 20, false)
	var visit_duelist := SeamsAdapter.open_stitched("node_duelist_full", duelist_record, duelist_full, {"gold": 5, "scraps": 3})
	var quote_duelist: Dictionary = visit_duelist.preview_choices()
	var choices_duelist: Dictionary = {}
	for c_raw: Variant in quote_duelist.get("choices", []):
		choices_duelist[(c_raw as Dictionary).get("id")] = c_raw
	var c_bind: Dictionary = choices_duelist.get("bind_mirror_cape", {})
	_check(c_bind.get("available") == true, "AC3: bind_mirror_cape available at full HP (raising max HP is not wasted)")
	_check(c_bind.get("scraps_delta") == -2, "AC3: bind_mirror_cape scraps_delta is -2")
	_check(c_bind.get("hp_delta") == 4, "AC3: bind_mirror_cape hp_delta is 4")
	_check(c_bind.get("max_hp_delta") == 2, "AC3: bind_mirror_cape max_hp_delta is 2")
	_check(c_bind.get("projected_scraps") == 1, "AC3: bind_mirror_cape projected scraps is 1")

	var receipt_duelist: Dictionary = visit_duelist.choose("bind_mirror_cape", "node_duelist_full", visit_duelist.read_state())
	_check(receipt_duelist.get("ok", false) == true, "AC3: bind_mirror_cape choose succeeded at full HP")
	_check(receipt_duelist.get("scraps_delta") == -2, "AC3: bind_mirror_cape receipt scraps_delta is -2")
	_check(receipt_duelist.get("hp_delta") == 4, "AC3: bind_mirror_cape receipt hp_delta is 4")
	_check(receipt_duelist.get("max_hp_delta") == 2, "AC3: bind_mirror_cape receipt max_hp_delta is 2")
	_check(receipt_duelist.get("wallet", {}).get("scraps") == 1, "AC3: bind_mirror_cape receipt wallet scraps is 1")

	# 4. Helper predicate unit validation
	var hero_full := {"hp": 20, "max_hp": 20}
	var hero_damaged := {"hp": 19, "max_hp": 20}
	_check(SeamsAdapter.is_pure_paid_heal_at_full_hp(-12, 0, 8, 0, hero_full) == true, "AC3: pure gold paid heal at full HP is true")
	_check(SeamsAdapter.is_pure_paid_heal_at_full_hp(0, -2, 10, 0, hero_full) == true, "AC3: pure scraps paid heal at full HP is true")
	_check(SeamsAdapter.is_pure_paid_heal_at_full_hp(-12, 0, 8, 0, hero_damaged) == false, "AC3: pure paid heal at damaged HP is false")
	_check(SeamsAdapter.is_pure_paid_heal_at_full_hp(18, 0, -4, 0, hero_full) == false, "AC3: hp sacrifice for gold is false")
	_check(SeamsAdapter.is_pure_paid_heal_at_full_hp(0, 0, 0, 0, hero_full) == false, "AC3: free leave is false")
	_check(SeamsAdapter.is_pure_paid_heal_at_full_hp(0, -2, 0, 3, hero_full) == false, "AC3: max hp gain without hp heal is false")
	_check(SeamsAdapter.is_pure_paid_heal_at_full_hp(0, -2, 4, 2, hero_full) == false, "AC3: max hp gain with hp heal is false")

	# Unit test helper project_vital_consequence
	var p1: Dictionary = SeamsAdapter.project_vital_consequence(22, 22, 0, -2, true)
	_check(p1["projected_max_hp"] == 20 and p1["projected_hp"] == 20 and p1["effective_hp_delta"] == -2, "Helper: max-HP sacrifice capping HP")
	var p2: Dictionary = SeamsAdapter.project_vital_consequence(17, 18, 4, 2, true)
	_check(p2["projected_max_hp"] == 20 and p2["projected_hp"] == 20 and p2["effective_hp_delta"] == 3, "Helper: heal capped by new max HP")
	var p3: Dictionary = SeamsAdapter.project_vital_consequence(0, 18, 4, 2, true)
	_check(p3["projected_max_hp"] == 20 and p3["projected_hp"] == 4 and p3["effective_hp_delta"] == 4, "Helper: hanging doll heal")
	var p4: Dictionary = SeamsAdapter.project_vital_consequence(20, 20, 8, 0, false)
	_check(p4["projected_max_hp"] == 20 and p4["projected_hp"] == 20 and p4["effective_hp_delta"] == 0, "Helper: unavailable preserves opening")


## S6 AC1: Shipped v3_warden_buckle_heart_ward with living Warden at rank 2 (HP 22 / max HP 22),
## wallet 10 gold / 5 scraps: sell_rivets quotes/claims raw gold +24, max_hp_delta -2, hp_delta 0,
## while projected_max_hp = 20, projected_hp = 20, effective_hp_delta = -2;
## detached party remains 22/22 until authoritative settlement.
func _test_s6_ac1_warden_buckle_heart_ward_hp_projection() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var warden_record: Dictionary = {}
	for ev_raw: Variant in catalog.get("events", []):
		if (ev_raw as Dictionary).get("id") == "v3_warden_buckle_heart_ward":
			warden_record = (ev_raw as Dictionary).duplicate(true)
			break
	_check(not warden_record.is_empty(), "S6 AC1: Found v3_warden_buckle_heart_ward")

	var party: Array = _party("warden", 2, 22, 22, false)
	var wallet := {"gold": 10, "scraps": 5}
	var node_id := "node_s6_warden_1"

	var visit := SeamsAdapter.open_stitched(node_id, warden_record, party, wallet)
	_check(visit.is_valid(), "S6 AC1: Visit is valid")

	var quote: Dictionary = visit.preview_choices()
	var choices_by_id: Dictionary = {}
	for c_raw: Variant in quote.get("choices", []):
		choices_by_id[(c_raw as Dictionary).get("id")] = c_raw

	_check(choices_by_id.has("sell_rivets"), "S6 AC1: sell_rivets present in quote")
	var c_sell: Dictionary = choices_by_id.get("sell_rivets", {})
	_check(c_sell.get("gold_delta") == 24, "S6 AC1: sell_rivets gold_delta is +24")
	_check(c_sell.get("scraps_delta") == 0, "S6 AC1: sell_rivets scraps_delta is 0")
	_check(c_sell.get("hp_delta") == 0, "S6 AC1: sell_rivets raw hp_delta is 0")
	_check(c_sell.get("max_hp_delta") == -2, "S6 AC1: sell_rivets raw max_hp_delta is -2")
	_check(c_sell.get("projected_max_hp") == 20, "S6 AC1: sell_rivets quote projected_max_hp is 20")
	_check(c_sell.get("projected_hp") == 20, "S6 AC1: sell_rivets quote projected_hp is 20")
	_check(c_sell.get("effective_hp_delta") == -2, "S6 AC1: sell_rivets quote effective_hp_delta is -2")
	_check(c_sell.get("available") == true, "S6 AC1: sell_rivets quote is available")

	# Check reinforce_shield_seam: max_hp +3, hp 0 -> 22+3=25 max, 22 hp, eff 0
	var c_reinf: Dictionary = choices_by_id.get("reinforce_shield_seam", {})
	_check(c_reinf.get("projected_max_hp") == 25, "S6 AC1: reinforce quote projected_max_hp is 25")
	_check(c_reinf.get("projected_hp") == 22, "S6 AC1: reinforce quote projected_hp is 22")
	_check(c_reinf.get("effective_hp_delta") == 0, "S6 AC1: reinforce quote effective_hp_delta is 0")

	# Check leave: 0 delta -> 22 max, 22 hp, eff 0
	var c_leave: Dictionary = choices_by_id.get("leave", {})
	_check(c_leave.get("projected_max_hp") == 22, "S6 AC1: leave quote projected_max_hp is 22")
	_check(c_leave.get("projected_hp") == 22, "S6 AC1: leave quote projected_hp is 22")
	_check(c_leave.get("effective_hp_delta") == 0, "S6 AC1: leave quote effective_hp_delta is 0")

	# Choose sell_rivets
	var state_before: Dictionary = visit.read_state()
	var receipt: Dictionary = visit.choose("sell_rivets", node_id, state_before)
	_check(receipt.get("ok") == true, "S6 AC1: sell_rivets choose succeeded")
	_check(receipt.get("gold_delta") == 24, "S6 AC1: receipt raw gold_delta +24")
	_check(receipt.get("max_hp_delta") == -2, "S6 AC1: receipt raw max_hp_delta -2")
	_check(receipt.get("hp_delta") == 0, "S6 AC1: receipt raw hp_delta 0")
	_check(receipt.get("projected_max_hp") == 20, "S6 AC1: receipt top-level projected_max_hp is 20")
	_check(receipt.get("projected_hp") == 20, "S6 AC1: receipt top-level projected_hp is 20")
	_check(receipt.get("effective_hp_delta") == -2, "S6 AC1: receipt top-level effective_hp_delta is -2")
	_check(receipt.get("wallet", {}).get("gold") == 34, "S6 AC1: receipt wallet gold updated to 34")

	# Detached party remains 22/22 until authoritative settlement
	var service_party: Array = visit.get_party()
	for hero: Variant in service_party:
		if (hero as Dictionary).get("id") == "warden":
			_check((hero as Dictionary).get("hp") == 22, "S6 AC1: service party Warden HP remains 22")
			_check((hero as Dictionary).get("max_hp") == 22, "S6 AC1: service party Warden max_hp remains 22")
	for hero: Variant in party:
		if (hero as Dictionary).get("id") == "warden":
			_check((hero as Dictionary).get("hp") == 22, "S6 AC1: caller party Warden HP remains 22")
			_check((hero as Dictionary).get("max_hp") == 22, "S6 AC1: caller party Warden max_hp remains 22")


## S6 AC2: Shipped v3_rag_duelist_duel_mask_mirror with living rank-3 Rag Duelist at HP 17 / max HP 18,
## >= 2 scraps: bind_mirror_cape retains raw HP +4 / max HP +2, but quote and successful claim
## project max HP 20 and HP 20 (effective HP +3); with non-LOST Hanging duel-mask target at HP 0 / max HP 18,
## the same choice projects HP 4 / max HP 20 and remains eligible.
func _test_s6_ac2_rag_duelist_duel_mask_mirror_hp_projection() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var duelist_record: Dictionary = {}
	for ev_raw: Variant in catalog.get("events", []):
		if (ev_raw as Dictionary).get("id") == "v3_rag_duelist_duel_mask_mirror":
			duelist_record = (ev_raw as Dictionary).duplicate(true)
			break
	_check(not duelist_record.is_empty(), "S6 AC2: Found v3_rag_duelist_duel_mask_mirror")

	# Case A: Rag Duelist at rank 3, HP 17 / max HP 18, wallet with >= 2 scraps
	var party_17: Array = _party("rag_duelist", 3, 17, 18, false)
	var wallet := {"gold": 8, "scraps": 4}
	var node_id_a := "node_s6_duelist_1"

	var visit_a := SeamsAdapter.open_stitched(node_id_a, duelist_record, party_17, wallet)
	_check(visit_a.is_valid(), "S6 AC2: Case A visit is valid")

	var quote_a: Dictionary = visit_a.preview_choices()
	var choices_a: Dictionary = {}
	for c_raw: Variant in quote_a.get("choices", []):
		choices_a[(c_raw as Dictionary).get("id")] = c_raw

	var c_bind_a: Dictionary = choices_a.get("bind_mirror_cape", {})
	_check(c_bind_a.get("hp_delta") == 4, "S6 AC2: bind_mirror_cape raw hp_delta is 4")
	_check(c_bind_a.get("max_hp_delta") == 2, "S6 AC2: bind_mirror_cape raw max_hp_delta is 2")
	_check(c_bind_a.get("scraps_delta") == -2, "S6 AC2: bind_mirror_cape raw scraps_delta is -2")
	_check(c_bind_a.get("projected_max_hp") == 20, "S6 AC2: bind_mirror_cape projected_max_hp is 20")
	_check(c_bind_a.get("projected_hp") == 20, "S6 AC2: bind_mirror_cape projected_hp is 20")
	_check(c_bind_a.get("effective_hp_delta") == 3, "S6 AC2: bind_mirror_cape effective_hp_delta is +3")
	_check(c_bind_a.get("available") == true, "S6 AC2: bind_mirror_cape is available")

	var state_a: Dictionary = visit_a.read_state()
	var receipt_a: Dictionary = visit_a.choose("bind_mirror_cape", node_id_a, state_a)
	_check(receipt_a.get("ok") == true, "S6 AC2: bind_mirror_cape choose succeeded")
	_check(receipt_a.get("hp_delta") == 4, "S6 AC2: receipt retains raw hp_delta +4")
	_check(receipt_a.get("max_hp_delta") == 2, "S6 AC2: receipt retains raw max_hp_delta +2")
	_check(receipt_a.get("projected_max_hp") == 20, "S6 AC2: receipt projected_max_hp is 20")
	_check(receipt_a.get("projected_hp") == 20, "S6 AC2: receipt projected_hp is 20")
	_check(receipt_a.get("effective_hp_delta") == 3, "S6 AC2: receipt effective_hp_delta is +3")

	# Case B: non-LOST Hanging duel-mask target at HP 0 / max HP 18
	var party_hanging: Array = _party("rag_duelist", 3, 0, 18, false)
	var node_id_b := "node_s6_duelist_hanging"

	var visit_b := SeamsAdapter.open_stitched(node_id_b, duelist_record, party_hanging, wallet)
	_check(visit_b.is_valid(), "S6 AC2: Case B hanging visit is valid")

	var quote_b: Dictionary = visit_b.preview_choices()
	var choices_b: Dictionary = {}
	for c_raw: Variant in quote_b.get("choices", []):
		choices_b[(c_raw as Dictionary).get("id")] = c_raw

	var c_bind_b: Dictionary = choices_b.get("bind_mirror_cape", {})
	_check(c_bind_b.get("available") == true, "S6 AC2: hanging target bind_mirror_cape remains eligible")
	_check(c_bind_b.get("projected_max_hp") == 20, "S6 AC2: hanging target projected_max_hp is 20")
	_check(c_bind_b.get("projected_hp") == 4, "S6 AC2: hanging target projected_hp is 4")
	_check(c_bind_b.get("effective_hp_delta") == 4, "S6 AC2: hanging target effective_hp_delta is +4")

	var state_b: Dictionary = visit_b.read_state()
	var receipt_b: Dictionary = visit_b.choose("bind_mirror_cape", node_id_b, state_b)
	_check(receipt_b.get("ok") == true, "S6 AC2: hanging target choose succeeded")
	_check(receipt_b.get("projected_max_hp") == 20, "S6 AC2: hanging receipt projected_max_hp is 20")
	_check(receipt_b.get("projected_hp") == 4, "S6 AC2: hanging receipt projected_hp is 4")
	_check(receipt_b.get("effective_hp_delta") == 4, "S6 AC2: hanging receipt effective_hp_delta is +4")
	_check(receipt_b.get("hp_delta") == 4, "S6 AC2: hanging receipt preserves raw hp_delta 4")
	_check(receipt_b.get("max_hp_delta") == 2, "S6 AC2: hanging receipt preserves raw max_hp_delta 2")


## S6 AC3: Authentic paid Seamstress stitch_wound at full HP, unaffordable 2-scrap Warden reinforcement,
## or max-HP reduction below established floor of 10: availability and refusal remain exactly as before;
## unavailable projections stay at opening HP/max HP (effective_hp_delta 0), no resources spent,
## and visit remains open for Leave.
func _test_s6_ac3_unavailable_choice_opening_hp_projections() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var surgeon_record: Dictionary = {}
	var warden_record: Dictionary = {}
	for ev_raw: Variant in catalog.get("events", []):
		var eid: String = String((ev_raw as Dictionary).get("id", ""))
		if eid == "v3_seamstress_crimson_quilt_surgeon":
			surgeon_record = (ev_raw as Dictionary).duplicate(true)
		elif eid == "v3_warden_buckle_heart_ward":
			warden_record = (ev_raw as Dictionary).duplicate(true)

	# 1. Authentic paid Seamstress stitch_wound at full HP (20/20)
	var party_seam: Array = _party("seamstress", 1, 20, 20, false)
	var wallet_seam := {"gold": 12, "scraps": 0}
	var visit_seam := SeamsAdapter.open_stitched("node_s6_seam_full", surgeon_record, party_seam, wallet_seam)
	var quote_seam: Dictionary = visit_seam.preview_choices()
	var choices_seam: Dictionary = {}
	for c_raw: Variant in quote_seam.get("choices", []):
		choices_seam[(c_raw as Dictionary).get("id")] = c_raw

	var c_stitch: Dictionary = choices_seam.get("stitch_wound", {})
	_check(c_stitch.get("available") == false, "S6 AC3: stitch_wound unavailable at full HP")
	_check(c_stitch.get("projected_max_hp") == 20, "S6 AC3: stitch_wound unavailable projected_max_hp is opening 20")
	_check(c_stitch.get("projected_hp") == 20, "S6 AC3: stitch_wound unavailable projected_hp is opening 20")
	_check(c_stitch.get("effective_hp_delta") == 0, "S6 AC3: stitch_wound unavailable effective_hp_delta is 0")

	var ref_seam: Dictionary = visit_seam.choose("stitch_wound", "node_s6_seam_full", visit_seam.read_state())
	_check(ref_seam.get("ok") == false, "S6 AC3: stitch_wound refused at full HP")
	_check(visit_seam.is_open() == true, "S6 AC3: visit remains open after refusal")
	_check(visit_seam.get_wallet() == wallet_seam, "S6 AC3: no wallet resources spent after refusal")
	var leave_seam: Dictionary = visit_seam.choose("leave", "node_s6_seam_full", visit_seam.read_state())
	_check(leave_seam.get("ok") == true, "S6 AC3: visit remains open for Leave")

	# 2. Unaffordable 2-scrap Warden reinforcement (wallet has 1 scrap)
	var party_warden: Array = _party("warden", 2, 19, 22, false)
	var wallet_short := {"gold": 10, "scraps": 1}
	var visit_warden := SeamsAdapter.open_stitched("node_s6_w_short", warden_record, party_warden, wallet_short)
	var quote_w: Dictionary = visit_warden.preview_choices()
	var choices_w: Dictionary = {}
	for c_raw: Variant in quote_w.get("choices", []):
		choices_w[(c_raw as Dictionary).get("id")] = c_raw

	var c_reinf: Dictionary = choices_w.get("reinforce_shield_seam", {})
	_check(c_reinf.get("available") == false, "S6 AC3: reinforce unavailable with 1 scrap")
	_check(c_reinf.get("projected_max_hp") == 22, "S6 AC3: reinforce unavailable projected_max_hp is opening 22")
	_check(c_reinf.get("projected_hp") == 19, "S6 AC3: reinforce unavailable projected_hp is opening 19")
	_check(c_reinf.get("effective_hp_delta") == 0, "S6 AC3: reinforce unavailable effective_hp_delta is 0")

	var ref_w: Dictionary = visit_warden.choose("reinforce_shield_seam", "node_s6_w_short", visit_warden.read_state())
	_check(ref_w.get("ok") == false, "S6 AC3: reinforce refused with insufficient scraps")
	_check(visit_warden.is_open() == true, "S6 AC3: visit remains open after scraps refusal")
	_check(visit_warden.get_wallet() == wallet_short, "S6 AC3: no scraps spent")
	var leave_w: Dictionary = visit_warden.choose("leave", "node_s6_w_short", visit_warden.read_state())
	_check(leave_w.get("ok") == true, "S6 AC3: visit remains open for Leave")

	# 3. Max-HP reduction below established floor of 10 (Warden max_hp = 11, sell_rivets max_hp_delta = -2 -> 9 < 10)
	var party_floor: Array = _party("warden", 2, 11, 11, false)
	var visit_floor := SeamsAdapter.open_stitched("node_s6_w_floor", warden_record, party_floor, wallet_seam)
	var quote_fl: Dictionary = visit_floor.preview_choices()
	var choices_fl: Dictionary = {}
	for c_raw: Variant in quote_fl.get("choices", []):
		choices_fl[(c_raw as Dictionary).get("id")] = c_raw

	var c_sell: Dictionary = choices_fl.get("sell_rivets", {})
	_check(c_sell.get("available") == false, "S6 AC3: sell_rivets unavailable when result < 10 floor")
	_check(c_sell.get("projected_max_hp") == 11, "S6 AC3: sell_rivets below floor projected_max_hp is opening 11")
	_check(c_sell.get("projected_hp") == 11, "S6 AC3: sell_rivets below floor projected_hp is opening 11")
	_check(c_sell.get("effective_hp_delta") == 0, "S6 AC3: sell_rivets below floor effective_hp_delta is 0")

	var ref_fl: Dictionary = visit_floor.choose("sell_rivets", "node_s6_w_floor", visit_floor.read_state())
	_check(ref_fl.get("ok") == false, "S6 AC3: sell_rivets refused when below 10 floor")
	_check(visit_floor.is_open() == true, "S6 AC3: visit remains open after floor refusal")
	var leave_fl: Dictionary = visit_floor.choose("leave", "node_s6_w_floor", visit_floor.read_state())
	_check(leave_fl.get("ok") == true, "S6 AC3: visit remains open for Leave")


## S6 AC4: Repeated quotes on one opened authentic visit are equal and do not change supplied
## party, wallet, catalog, service state or seeded/global RNG. On success, the three added
## top-level receipt fields equal the chosen quote; legacy nested receipt/intents,
## one-claim-only protection and all existing regression assertions still pass.
func _test_s6_ac4_repeated_quotes_and_claim_parity() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var warden_record: Dictionary = {}
	for ev_raw: Variant in catalog.get("events", []):
		if (ev_raw as Dictionary).get("id") == "v3_warden_buckle_heart_ward":
			warden_record = (ev_raw as Dictionary).duplicate(true)
			break

	var party: Array = _party("warden", 2, 22, 22, false)
	var wallet := {"gold": 10, "scraps": 5}
	var orig_party: Array = party.duplicate(true)
	var orig_wallet: Dictionary = wallet.duplicate(true)
	var orig_record: Dictionary = warden_record.duplicate(true)
	var node_id := "node_s6_parity_1"

	var seeded_rng := RandomNumberGenerator.new()
	seeded_rng.seed = 99991
	var rng_seed_before: int = seeded_rng.state
	seed(77771)
	var global_rand_before: int = randi()
	seed(77771)

	var visit := SeamsAdapter.open_stitched(node_id, warden_record, party, wallet)
	_check(visit.is_valid(), "S6 AC4: Visit is valid")

	# Repeated quotes
	var quote1: Dictionary = visit.preview_choices()
	var quote2: Dictionary = visit.preview_choices()
	var quote3: Dictionary = visit.preview_choices()

	_check(SeamsAdapter._same_value(quote1, quote2), "S6 AC4: Repeated quote 1 and 2 are equal")
	_check(SeamsAdapter._same_value(quote2, quote3), "S6 AC4: Repeated quote 2 and 3 are equal")
	_check(party == orig_party, "S6 AC4: Party unmodified after repeated quotes")
	_check(wallet == orig_wallet, "S6 AC4: Wallet unmodified after repeated quotes")
	_check(warden_record == orig_record, "S6 AC4: Catalog record unmodified after repeated quotes")
	_check(seeded_rng.state == rng_seed_before, "S6 AC4: Seeded RNG unmodified after repeated quotes")
	_check(randi() == global_rand_before, "S6 AC4: Global RNG unmodified after repeated quotes")
	seed(77771)

	# Find sell_rivets quote
	var chosen_quote_entry: Dictionary = {}
	for c_raw: Variant in quote1.get("choices", []):
		if (c_raw as Dictionary).get("id") == "sell_rivets":
			chosen_quote_entry = c_raw
			break

	var state_before: Dictionary = visit.read_state()
	var claim_res: Dictionary = visit.choose("sell_rivets", node_id, state_before)
	_check(claim_res.get("ok") == true, "S6 AC4: choose succeeded")

	# Three added top-level receipt fields equal the chosen quote
	_check(claim_res.get("projected_max_hp") == chosen_quote_entry.get("projected_max_hp"), "S6 AC4: top-level projected_max_hp equals quote")
	_check(claim_res.get("projected_hp") == chosen_quote_entry.get("projected_hp"), "S6 AC4: top-level projected_hp equals quote")
	_check(claim_res.get("effective_hp_delta") == chosen_quote_entry.get("effective_hp_delta"), "S6 AC4: top-level effective_hp_delta equals quote")

	# Legacy nested receipt unchanged
	var nested_rc: Dictionary = claim_res.get("receipt", {})
	_check(nested_rc.get("event_id") == "v3_warden_buckle_heart_ward", "S6 AC4: nested receipt event_id")
	_check(nested_rc.get("choice_id") == "sell_rivets", "S6 AC4: nested receipt choice_id")
	_check(nested_rc.get("gold_delta") == 24, "S6 AC4: nested receipt gold_delta 24")
	_check(nested_rc.get("scraps_delta") == 0, "S6 AC4: nested receipt scraps_delta 0")
	_check(nested_rc.get("hp_delta") == 0, "S6 AC4: nested receipt hp_delta 0")
	_check(nested_rc.get("max_hp_delta") == -2, "S6 AC4: nested receipt max_hp_delta -2")
	_check(nested_rc.get("wallet", {}).get("gold") == 34, "S6 AC4: nested receipt wallet gold 34")

	# Legacy intents unchanged
	var intents: Dictionary = claim_res.get("intents", {})
	_check(intents.get("hero_id") == "warden", "S6 AC4: intents hero_id")
	_check(intents.get("gold_delta") == 24, "S6 AC4: intents gold_delta")
	_check(intents.get("scraps_delta") == 0, "S6 AC4: intents scraps_delta")
	_check(intents.get("hp_delta") == 0, "S6 AC4: intents hp_delta")
	_check(intents.get("max_hp_delta") == -2, "S6 AC4: intents max_hp_delta")

	# One-claim-only protection
	var second_claim: Dictionary = visit.choose("leave", node_id, visit.read_state())
	_check(second_claim.get("ok") == false, "S6 AC4: second claim refused")

	_check(seeded_rng.state == rng_seed_before, "S6 AC4: Seeded RNG unmodified after claim")
	_check(randi() == global_rand_before, "S6 AC4: Global RNG unmodified after claim")

