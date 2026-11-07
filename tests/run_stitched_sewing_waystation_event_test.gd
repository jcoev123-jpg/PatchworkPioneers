extends SceneTree
## Deterministic regression suite for RunStitchedSewingWaystationEvent.
## Covers AC1 (real post-toll actionability preview), AC2 (authenticated entrance claim and isolation),
## AC3 (actionless refusal, trade/leave branches, fail-closed validation), and AC4 (catalog integrity).

const WARDEN_PATH := "res://data/parts/warden_parts.json"
const EVENTS_PATH := "res://data/events/v3_service_waystation_events.json"
const NODE := "sewing_circle_node_live_4"

var failures: Array = []
var checks: int = 0
var catalog: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 7052026
	var rng_state_before := rng.state

	if _load_catalog():
		_test_ac1_preview_actionability_and_post_toll_check()
		_test_ac2_authenticated_claim_and_isolation()
		_test_ac3_unaffordable_actionless_trades_and_leave()
		_test_ac3_failures_rejections_and_invalid_inputs()
		_test_ac4_catalog_integrity()

	_check(rng.state == rng_state_before, "Overall: Seeded RNG state must remain completely untouched")
	_finish()


func _finish() -> void:
	for failure: Variant in failures:
		printerr("FAIL: ", str(failure))
	print("run_stitched_sewing_waystation_event_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_catalog() -> bool:
	var warden: Dictionary = StitchedParts.load_catalog(WARDEN_PATH)
	_check(bool(warden.get("ok", false)), "Warden catalog loads successfully")
	if not bool(warden.get("ok", false)):
		return false
	catalog = (warden.get("by_id", {}) as Dictionary).duplicate(true)
	for id: String in [
		"warden_head_pot_helm_bonk",
		"warden_head_helmet_rattle",
		"warden_arms_shield_catch",
		"warden_torso_iron_challenge",
		"warden_legs_rim_toss",
	]:
		_check(catalog.has(id), "Catalog contains required Warden part: " + id)
	return catalog.has("warden_head_pot_helm_bonk") and catalog.has("warden_legs_rim_toss")


func _worn(id: String, tier: int = 1, torn: bool = false) -> Dictionary:
	return {"id": id, "tier": tier, "torn": torn}


func _spare(id: String, slot: String, tier: int = 1, torn: bool = false) -> Dictionary:
	return {"id": id, "slot": slot, "tier": tier, "torn": torn}


func _party(tier: int = 1, torn: bool = false) -> Array:
	var ids := ["hero_a", "hero_b", "hero_c", "hero_d"]
	var heroes: Array = []
	for i in range(4):
		var gear := {
			"head": _worn("warden_head_pot_helm_bonk", tier, torn),
			"arms": _worn("warden_arms_shield_catch", tier, torn),
			"torso": _worn("warden_torso_iron_challenge", tier, torn),
			"legs": _worn("warden_legs_rim_toss", tier, torn),
		}
		heroes.append({
			"id": ids[i],
			"name": "Warden Doll " + ids[i],
			"rank": i + 1,
			"parts": gear,
			"hp": 20 + i,
			"max_hp": 30 + i,
			"fray": 2 * i,
			"candle": 4 - i,
			"patches": i,
			"statuses": {"guard": i},
		})
	return heroes


func _find_choice(choices: Array, choice_id: String) -> Dictionary:
	for ch_raw: Variant in choices:
		if ch_raw is Dictionary and String((ch_raw as Dictionary).get("choice_id", "")) == choice_id:
			return (ch_raw as Dictionary).duplicate(true)
	return {}


# AC1: Real post-toll wallet calculation and actionability scanning.
func _test_ac1_preview_actionability_and_post_toll_check() -> void:
	var heroes := _party(1, false)
	var heroes_snap := JSON.stringify(heroes, "", true)
	var satchel: Array = []
	var mend_cost := 2
	var upgrade_cost := 2

	# Threadmill: gold=12, scraps=2, tier-I untorn Warden part
	# Toll: -12 gold, post-toll wallet: gold=0, scraps=2.
	# Tier-I untorn part can be upgraded for 2 scraps.
	var threadmill_wallet := {"gold": 12, "scraps": 2}
	var wallet_snap_t := JSON.stringify(threadmill_wallet, "", true)
	var event_t := RunStitchedSewingWaystationEvent.new(
		"v3_threadmill_sewing_circle",
		NODE,
		heroes,
		satchel,
		threadmill_wallet,
		catalog,
		mend_cost,
		upgrade_cost
	)
	_check(event_t.is_valid(), "AC1: Threadmill event is valid at creation")
	_check(event_t.is_open(), "AC1: Threadmill event is open")
	_check(not event_t.is_claimed(), "AC1: Threadmill event is unclaimed")

	var preview_t := event_t.preview_choices()
	_check(bool(preview_t.get("ok", false)), "AC1: Threadmill preview succeeds")
	var choices_t: Array = preview_t.get("choices", [])
	_check(choices_t.size() == 3, "AC1: Threadmill preview offers 3 choices")

	var paid_t := _find_choice(choices_t, "borrow_spools")
	_check(bool(paid_t.get("affordable", false)), "AC1: Threadmill borrow_spools is affordable")
	_check(bool(paid_t.get("available", false)), "AC1: Threadmill borrow_spools is available")
	_check(paid_t.get("service_request", {}).get("stop_type") == "SewingCircle", "AC1: Threadmill borrow_spools offers SewingCircle request")
	_check(paid_t.get("wallet", {}).get("gold") == 0 and paid_t.get("wallet", {}).get("scraps") == 2, "AC1: Threadmill post-toll wallet is gold=0, scraps=2")

	var trade_t := _find_choice(choices_t, "untie_scraps")
	_check(bool(trade_t.get("available", false)), "AC1: Threadmill untie_scraps is available")
	_check((trade_t.get("service_request", {}) as Dictionary).is_empty(), "AC1: untie_scraps has empty service_request")

	var leave_t := _find_choice(choices_t, "leave")
	_check(bool(leave_t.get("available", false)), "AC1: Threadmill leave is available")
	_check((leave_t.get("service_request", {}) as Dictionary).is_empty(), "AC1: leave has empty service_request")

	_check(JSON.stringify(heroes, "", true) == heroes_snap, "AC1: Input heroes snapshot was not mutated")
	_check(JSON.stringify(threadmill_wallet, "", true) == wallet_snap_t, "AC1: Input wallet snapshot was not mutated")

	# Moonlace: gold=0, scraps=4, tier-I untorn Warden part
	# Toll: -2 scraps, post-toll wallet: gold=0, scraps=2.
	# Tier-I untorn part can be upgraded for 2 scraps.
	var moonlace_wallet := {"gold": 0, "scraps": 4}
	var wallet_snap_m := JSON.stringify(moonlace_wallet, "", true)
	var event_m := RunStitchedSewingWaystationEvent.new(
		"v3_moonlace_darning_parlor",
		NODE,
		heroes,
		satchel,
		moonlace_wallet,
		catalog,
		mend_cost,
		upgrade_cost
	)
	_check(event_m.is_valid(), "AC1: Moonlace event is valid at creation")
	var preview_m := event_m.preview_choices()
	_check(bool(preview_m.get("ok", false)), "AC1: Moonlace preview succeeds")
	var choices_m: Array = preview_m.get("choices", [])

	var paid_m := _find_choice(choices_m, "sew_at_parlor")
	_check(bool(paid_m.get("affordable", false)), "AC1: Moonlace sew_at_parlor is affordable")
	_check(bool(paid_m.get("available", false)), "AC1: Moonlace sew_at_parlor is available")
	_check(paid_m.get("service_request", {}).get("stop_type") == "SewingCircle", "AC1: Moonlace sew_at_parlor offers SewingCircle request")
	_check(paid_m.get("wallet", {}).get("gold") == 0 and paid_m.get("wallet", {}).get("scraps") == 2, "AC1: Moonlace post-toll wallet is gold=0, scraps=2")

	var trade_m := _find_choice(choices_m, "trade_lace")
	_check(bool(trade_m.get("available", false)), "AC1: Moonlace trade_lace is available")
	_check((trade_m.get("service_request", {}) as Dictionary).is_empty(), "AC1: trade_lace has empty service_request")

	_check(JSON.stringify(moonlace_wallet, "", true) == wallet_snap_m, "AC1: Input Moonlace wallet snapshot was not mutated")

	# Lost hero check: party where the only upgradeable hero is lost must be actionless
	var lost_heroes := _party(3, false)
	lost_heroes[0]["parts"]["head"]["tier"] = 1 # hero_a can upgrade
	lost_heroes[0]["lost"] = true # but hero_a is lost
	# Direct exchange between living dolls is now an action, so only one doll stays living.
	lost_heroes[1]["lost"] = true
	lost_heroes[2]["lost"] = true
	var lost_event := RunStitchedSewingWaystationEvent.new(
		"v3_threadmill_sewing_circle",
		NODE,
		lost_heroes,
		[],
		{"gold": 12, "scraps": 2},
		catalog,
		mend_cost,
		upgrade_cost
	)
	var lost_preview := lost_event.preview_choices()
	var lost_paid := _find_choice(lost_preview.get("choices", []), "borrow_spools")
	_check(not bool(lost_paid.get("available", false)), "AC1: Lost hero with sole upgradeable part is skipped; paid choice is unavailable")


# AC2: Authenticated entrance toll settlement, one-claim latch, deep-copy isolation, RNG untouched.
func _test_ac2_authenticated_claim_and_isolation() -> void:
	var heroes := _party(1, false)
	var satchel: Array = []
	var mend_cost := 2
	var upgrade_cost := 2

	# Threadmill claim: gold=12, scraps=2 -> claim borrow_spools -> gold=0, scraps=2 + request
	var t_event := RunStitchedSewingWaystationEvent.new(
		"v3_threadmill_sewing_circle",
		NODE,
		heroes,
		satchel,
		{"gold": 12, "scraps": 2},
		catalog,
		mend_cost,
		upgrade_cost
	)
	var state_before := t_event.read_state()
	var rng_before := rng.state

	var claim_res := t_event.choose("borrow_spools", NODE, state_before)
	_check(rng.state == rng_before, "AC2: RNG state unchanged after successful claim")
	_check(bool(claim_res.get("ok", false)), "AC2: Claim borrow_spools succeeds")
	_check(claim_res.get("event_id") == "v3_threadmill_sewing_circle", "AC2: Correct event_id returned")
	_check(claim_res.get("choice_id") == "borrow_spools", "AC2: Correct choice_id returned")
	_check(claim_res.get("wallet", {}).get("gold") == 0, "AC2: Settled wallet has gold=0")
	_check(claim_res.get("wallet", {}).get("scraps") == 2, "AC2: Settled wallet has scraps=2")
	_check(claim_res.get("service_request", {}).get("stop_type") == "SewingCircle", "AC2: service_request is SewingCircle")
	_check(t_event.is_claimed(), "AC2: Visit is now claimed")
	_check(not t_event.is_open(), "AC2: Visit is now closed")
	_check(not t_event.is_valid(), "AC2: Claimed visit is no longer valid for new claims")

	# Verify party and satchel unchanged in state
	var state_after := t_event.read_state()
	_check(int(state_after.get("version", 0)) == int(state_before.get("version", 0)) + 1, "AC2: Version incremented on successful claim")
	_check(JSON.stringify(state_after.get("heroes"), "", true) == JSON.stringify(heroes, "", true), "AC2: Heroes parts/HP/fray/candle/patches untouched")
	_check(JSON.stringify(state_after.get("satchel"), "", true) == JSON.stringify(satchel, "", true), "AC2: Satchel untouched")

	# Replay rejection
	var replay_same := t_event.choose("borrow_spools", NODE, state_after)
	_check(not bool(replay_same.get("ok", false)), "AC2: Replay of same choice fails")
	_check(replay_same.get("wallet", {}).get("gold") == 0 and replay_same.get("wallet", {}).get("scraps") == 2, "AC2: Wallet unchanged on replay rejection")
	_check((replay_same.get("service_request", {}) as Dictionary).is_empty(), "AC2: Replay rejection returns empty service_request")

	var replay_alt := t_event.choose("untie_scraps", NODE, state_after)
	_check(not bool(replay_alt.get("ok", false)), "AC2: Alternate choice after claim fails")

	# Moonlace claim: gold=0, scraps=4 -> claim sew_at_parlor -> gold=0, scraps=2 + request
	var m_event := RunStitchedSewingWaystationEvent.new(
		"v3_moonlace_darning_parlor",
		NODE,
		heroes,
		satchel,
		{"gold": 0, "scraps": 4},
		catalog,
		mend_cost,
		upgrade_cost
	)
	var m_state := m_event.read_state()
	var m_claim := m_event.choose("sew_at_parlor", NODE, m_state)
	_check(bool(m_claim.get("ok", false)), "AC2: Moonlace claim succeeds")
	_check(m_claim.get("wallet", {}).get("gold") == 0 and m_claim.get("wallet", {}).get("scraps") == 2, "AC2: Moonlace settled wallet is gold=0, scraps=2")
	_check(m_claim.get("service_request", {}).get("stop_type") == "SewingCircle", "AC2: Moonlace service_request is SewingCircle")

	# Deep-copy isolation test
	var mut_wallet: Dictionary = m_claim.get("wallet", {})
	mut_wallet["gold"] = 999
	_check(m_event.get_wallet().get("gold") == 0, "AC2: Mutating returned wallet copy does not affect internal state")

	var fresh_state := m_event.read_state()
	var fresh_heroes: Array = fresh_state.get("heroes", [])
	fresh_heroes[0]["hp"] = 999
	_check(m_event.get_heroes()[0].get("hp") != 999, "AC2: Mutating returned heroes copy does not affect internal state")


# AC3: Unaffordable toll, actionless paid choice, alternate trade and leave branches.
func _test_ac3_unaffordable_actionless_trades_and_leave() -> void:
	var mend_cost := 2
	var upgrade_cost := 2

	# Subcase 1: Moonlace scraps=2, satchel=[], all tier III untorn.
	# Toll takes 2 scraps -> 0 scraps post-toll. No upgrade, no mend, no swap.
	var tier3_heroes := _party(3, false)
	# Direct wearer-to-wearer exchange now counts as a Sewing Circle action, so the truly actionless
	# fixture keeps a single living doll (the other three are LOST and cannot trade).
	var tier3_solo := _party(3, false)
	for solo_index in [1, 2, 3]:
		tier3_solo[solo_index]["lost"] = true
	var empty_satchel: Array = []
	var m_actionless := RunStitchedSewingWaystationEvent.new(
		"v3_moonlace_darning_parlor",
		NODE,
		tier3_solo,
		empty_satchel,
		{"gold": 0, "scraps": 2},
		catalog,
		mend_cost,
		upgrade_cost
	)
	var prev_al := m_actionless.preview_choices()
	var paid_al := _find_choice(prev_al.get("choices", []), "sew_at_parlor")
	_check(bool(paid_al.get("affordable", false)), "AC3: Moonlace toll itself was affordable in wallet forecast")
	_check(not bool(paid_al.get("available", false)), "AC3: Actionless paid choice is marked available=false")
	_check((paid_al.get("service_request", {}) as Dictionary).is_empty(), "AC3: Actionless paid choice has service_request={}")

	# Refused claim does not latch
	var rng_before := rng.state
	var state_al := m_actionless.read_state()
	var refused_claim := m_actionless.choose("sew_at_parlor", NODE, state_al)
	_check(not bool(refused_claim.get("ok", false)), "AC3: Refused paid claim returns ok=false")
	_check(rng.state == rng_before, "AC3: RNG untouched on refused claim")
	_check(m_actionless.is_open(), "AC3: Refused claim did not close the visit")
	_check(not m_actionless.is_claimed(), "AC3: Refused claim did not latch")
	_check(m_actionless.get_wallet().get("gold") == 0 and m_actionless.get_wallet().get("scraps") == 2, "AC3: Wallet untouched on refusal")

	# trade_lace still awards exactly 10 gold once
	var trade_claim := m_actionless.choose("trade_lace", NODE, state_al)
	_check(bool(trade_claim.get("ok", false)), "AC3: trade_lace succeeds after refused paid claim")
	_check(trade_claim.get("wallet", {}).get("gold") == 10 and trade_claim.get("wallet", {}).get("scraps") == 2, "AC3: trade_lace awards exactly 10 gold")
	_check((trade_claim.get("service_request", {}) as Dictionary).is_empty(), "AC3: trade_lace returns empty service_request")
	_check(m_actionless.is_claimed(), "AC3: trade_lace latches the visit")

	# Fresh visit Leave check
	var m_leave_visit := RunStitchedSewingWaystationEvent.new(
		"v3_moonlace_darning_parlor",
		NODE,
		tier3_solo,
		empty_satchel,
		{"gold": 0, "scraps": 2},
		catalog,
		mend_cost,
		upgrade_cost
	)
	var leave_claim := m_leave_visit.leave(NODE, m_leave_visit.read_state())
	_check(bool(leave_claim.get("ok", false)), "AC3: Leave succeeds on fresh visit")
	_check(leave_claim.get("wallet", {}).get("gold") == 0 and leave_claim.get("wallet", {}).get("scraps") == 2, "AC3: Leave leaves wallet unchanged")
	_check((leave_claim.get("service_request", {}) as Dictionary).is_empty(), "AC3: Leave returns empty service_request")
	_check(m_leave_visit.is_claimed(), "AC3: Leave latches the visit")

	# Witness: with two or more living untorn same-slot wearers, a direct exchange is an action even
	# with an empty satchel and nothing to mend or upgrade.
	var m_direct := RunStitchedSewingWaystationEvent.new(
		"v3_moonlace_darning_parlor",
		NODE,
		tier3_heroes,
		empty_satchel,
		{"gold": 0, "scraps": 2},
		catalog,
		mend_cost,
		upgrade_cost
	)
	var paid_direct := _find_choice(m_direct.preview_choices().get("choices", []), "sew_at_parlor")
	_check(bool(paid_direct.get("available", false)), "AC3: Direct wearer exchange makes the Sewing Circle choice available with an empty satchel")

	# Subcase 2: Threadmill gold=11, scraps=10 cannot fund 12 gold toll
	var t_unaffordable := RunStitchedSewingWaystationEvent.new(
		"v3_threadmill_sewing_circle",
		NODE,
		_party(1, false),
		[],
		{"gold": 11, "scraps": 10},
		catalog,
		mend_cost,
		upgrade_cost
	)
	var prev_unaff := t_unaffordable.preview_choices()
	var paid_unaff := _find_choice(prev_unaff.get("choices", []), "borrow_spools")
	_check(not bool(paid_unaff.get("affordable", false)), "AC3: Threadmill 11 gold is unaffordable")
	_check(not bool(paid_unaff.get("available", false)), "AC3: Unaffordable paid choice is unavailable")
	_check((paid_unaff.get("service_request", {}) as Dictionary).is_empty(), "AC3: Unaffordable paid choice has empty service_request")
	var refuse_unaff := t_unaffordable.choose("borrow_spools", NODE, t_unaffordable.read_state())
	_check(not bool(refuse_unaff.get("ok", false)), "AC3: Unaffordable paid choice cannot be claimed")

	# Subcase 3: Threadmill gold=12, scraps=0, spare compatible non-torn head part -> free swap allows admission!
	var satchel_with_head := [_spare("warden_head_helmet_rattle", "head", 1, false)]
	var t_swap_visit := RunStitchedSewingWaystationEvent.new(
		"v3_threadmill_sewing_circle",
		NODE,
		tier3_heroes,
		satchel_with_head,
		{"gold": 12, "scraps": 0},
		catalog,
		mend_cost,
		upgrade_cost
	)
	var prev_swap := t_swap_visit.preview_choices()
	var paid_swap := _find_choice(prev_swap.get("choices", []), "borrow_spools")
	_check(bool(paid_swap.get("available", false)), "AC3: Zero scraps allows free swap with compatible satchel item")
	_check(paid_swap.get("service_request", {}).get("stop_type") == "SewingCircle", "AC3: Free swap entitles SewingCircle request")
	var claim_swap := t_swap_visit.choose("borrow_spools", NODE, t_swap_visit.read_state())
	_check(bool(claim_swap.get("ok", false)), "AC3: Free swap claim succeeds")
	_check(claim_swap.get("wallet", {}).get("gold") == 0 and claim_swap.get("wallet", {}).get("scraps") == 0, "AC3: Settled wallet is gold=0, scraps=0")
	_check(claim_swap.get("service_request", {}).get("stop_type") == "SewingCircle", "AC3: Settled request is SewingCircle")

	# Subcase 4: Torn worn slot cannot swap; can only mend if post-toll scraps >= mend cost.
	# All worn gear is torn, so no worn part can be swapped out.
	var torn_party := _party(3, true)
	# Satchel has compatible head part
	var satchel_spare := [_spare("warden_head_helmet_rattle", "head", 1, false)]

	# 4a: Threadmill with gold=12, scraps=1 (post-toll scraps=1 < mend_cost 2)
	# Torn head cannot swap, and scraps=1 cannot mend -> actionless!
	var t_torn_insufficient := RunStitchedSewingWaystationEvent.new(
		"v3_threadmill_sewing_circle",
		NODE,
		torn_party,
		satchel_spare,
		{"gold": 12, "scraps": 1},
		catalog,
		mend_cost,
		upgrade_cost
	)
	var prev_torn_ins := t_torn_insufficient.preview_choices()
	var paid_torn_ins := _find_choice(prev_torn_ins.get("choices", []), "borrow_spools")
	_check(not bool(paid_torn_ins.get("available", false)), "AC3: Torn part cannot swap and cannot mend with 1 scrap; unavailable")

	# 4b: Threadmill with gold=12, scraps=2 (post-toll scraps=2 == mend_cost 2)
	# Can mend!
	var t_torn_sufficient := RunStitchedSewingWaystationEvent.new(
		"v3_threadmill_sewing_circle",
		NODE,
		torn_party,
		satchel_spare,
		{"gold": 12, "scraps": 2},
		catalog,
		mend_cost,
		upgrade_cost
	)
	var prev_torn_suf := t_torn_sufficient.preview_choices()
	var paid_torn_suf := _find_choice(prev_torn_suf.get("choices", []), "borrow_spools")
	_check(bool(paid_torn_suf.get("available", false)), "AC3: Torn part can mend with 2 scraps; available")


# AC3 Fail-closed: Bogus event IDs, Campfire/Unpicker, forged content, wrong node, stale state, malformed inputs.
func _test_ac3_failures_rejections_and_invalid_inputs() -> void:
	var valid_heroes := _party(1, false)
	var valid_satchel: Array = []
	var valid_wallet := {"gold": 20, "scraps": 5}
	var mend_cost := 2
	var upgrade_cost := 2

	var rng_before := rng.state

	# Bogus event IDs
	var bogus1 := RunStitchedSewingWaystationEvent.new("bogus_event_id", NODE, valid_heroes, valid_satchel, valid_wallet, catalog, mend_cost, upgrade_cost)
	_check(not bogus1.is_valid(), "Fail-closed: Bogus event ID is invalid")
	_check(not bool(bogus1.read_state().get("ok", false)), "Fail-closed: Bogus event ID read_state fails")

	var bogus2 := RunStitchedSewingWaystationEvent.new("", NODE, valid_heroes, valid_satchel, valid_wallet, catalog, mend_cost, upgrade_cost)
	_check(not bogus2.is_valid(), "Fail-closed: Empty event ID is invalid")

	# Campfire / Unpicker service kinds
	var campfire := RunStitchedSewingWaystationEvent.new("v3_emberglass_campfire", NODE, valid_heroes, valid_satchel, valid_wallet, catalog, mend_cost, upgrade_cost)
	_check(not campfire.is_valid(), "Fail-closed: Campfire event is rejected")

	var unpicker := RunStitchedSewingWaystationEvent.new("v3_inkblack_unpicker_van", NODE, valid_heroes, valid_satchel, valid_wallet, catalog, mend_cost, upgrade_cost)
	_check(not unpicker.is_valid(), "Fail-closed: Unpicker event is rejected")

	# Forged event content dictionary
	var forged_event := {
		"id": "v3_threadmill_sewing_circle",
		"title": "Forged Title",
		"description": "Forged desc",
		"service_choice_id": "borrow_spools",
		"service_kind": "SewingCircle",
		"choices": [
			{"id": "borrow_spools", "text": "Free spools", "outcome": {"gold": 0, "scraps": 0}},
			{"id": "untie_scraps", "text": "Free scraps", "outcome": {"gold": 0, "scraps": 100}},
			{"id": "leave", "text": "Leave", "outcome": {"gold": 0, "scraps": 0}},
		],
	}
	var forged := RunStitchedSewingWaystationEvent.new(forged_event, NODE, valid_heroes, valid_satchel, valid_wallet, catalog, mend_cost, upgrade_cost)
	_check(not forged.is_valid(), "Fail-closed: Forged event content is rejected")

	# Wrong node
	var good_ev := RunStitchedSewingWaystationEvent.new("v3_threadmill_sewing_circle", NODE, valid_heroes, valid_satchel, valid_wallet, catalog, mend_cost, upgrade_cost)
	var state := good_ev.read_state()
	var wrong_node_res := good_ev.choose("borrow_spools", "completely_wrong_node", state)
	_check(not bool(wrong_node_res.get("ok", false)), "Fail-closed: Wrong node fails")
	_check(wrong_node_res.get("error") == "wrong node", "Fail-closed: Error message is 'wrong node'")
	_check(good_ev.is_open(), "Fail-closed: Wrong node does not close visit")

	# Altered / deep-copied stale snapshots
	var stale_state := state.duplicate(true)
	stale_state["version"] = 99
	var stale_res := good_ev.choose("borrow_spools", NODE, stale_state)
	_check(not bool(stale_res.get("ok", false)), "Fail-closed: Stale version fails")
	_check(stale_res.get("error") == "stale or forged state", "Fail-closed: Error message is 'stale or forged state'")

	var forged_state := state.duplicate(true)
	forged_state["wallet"]["gold"] = 9999
	var forged_res := good_ev.choose("borrow_spools", NODE, forged_state)
	_check(not bool(forged_res.get("ok", false)), "Fail-closed: Forged state wallet fails")

	# Malformed party: 3 heroes, 5 heroes, rank out of bounds, duplicate ID
	var three_heroes: Array = valid_heroes.slice(0, 3)
	var bad_party1 := RunStitchedSewingWaystationEvent.new("v3_threadmill_sewing_circle", NODE, three_heroes, valid_satchel, valid_wallet, catalog, mend_cost, upgrade_cost)
	_check(not bad_party1.is_valid(), "Fail-closed: 3 heroes party is invalid")

	var dupe_heroes := valid_heroes.duplicate(true)
	dupe_heroes[1]["id"] = dupe_heroes[0]["id"]
	var bad_party2 := RunStitchedSewingWaystationEvent.new("v3_threadmill_sewing_circle", NODE, dupe_heroes, valid_satchel, valid_wallet, catalog, mend_cost, upgrade_cost)
	_check(not bad_party2.is_valid(), "Fail-closed: Duplicate hero ID is invalid")

	# Malformed satchel: 7 items, bad slot
	var big_satchel: Array = []
	for k in range(7):
		big_satchel.append(_spare("warden_head_helmet_rattle", "head", 1, false))
	var bad_satchel1 := RunStitchedSewingWaystationEvent.new("v3_threadmill_sewing_circle", NODE, valid_heroes, big_satchel, valid_wallet, catalog, mend_cost, upgrade_cost)
	_check(not bad_satchel1.is_valid(), "Fail-closed: Satchel size 7 is invalid")

	# Malformed catalog: empty
	var bad_cat := RunStitchedSewingWaystationEvent.new("v3_threadmill_sewing_circle", NODE, valid_heroes, valid_satchel, valid_wallet, {}, mend_cost, upgrade_cost)
	_check(not bad_cat.is_valid(), "Fail-closed: Empty catalog is invalid")

	# Malformed wallet: negative gold
	var bad_wal1 := RunStitchedSewingWaystationEvent.new("v3_threadmill_sewing_circle", NODE, valid_heroes, valid_satchel, {"gold": -5, "scraps": 0}, catalog, mend_cost, upgrade_cost)
	_check(not bad_wal1.is_valid(), "Fail-closed: Negative gold wallet is invalid")

	# Malformed costs: zero or negative costs
	var bad_cost1 := RunStitchedSewingWaystationEvent.new("v3_threadmill_sewing_circle", NODE, valid_heroes, valid_satchel, valid_wallet, catalog, 0, upgrade_cost)
	_check(not bad_cost1.is_valid(), "Fail-closed: Zero mend cost is invalid")
	var bad_cost2 := RunStitchedSewingWaystationEvent.new("v3_threadmill_sewing_circle", NODE, valid_heroes, valid_satchel, valid_wallet, catalog, mend_cost, -1)
	_check(not bad_cost2.is_valid(), "Fail-closed: Negative upgrade cost is invalid")

	_check(rng.state == rng_before, "Fail-closed: RNG state untouched across all failures and rejections")


# AC4: Shipped JSON catalog integrity and unchanged waystation definitions.
func _test_ac4_catalog_integrity() -> void:
	_check(FileAccess.file_exists(EVENTS_PATH), "AC4: Service waystation events JSON exists")
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "AC4: JSON file can be opened")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var parser := JSON.new()
	_check(parser.parse(text) == OK, "AC4: JSON parses cleanly")
	var data: Dictionary = parser.data as Dictionary
	var events: Array = data.get("events", [])

	var found_ids: Dictionary = {}
	for ev_raw: Variant in events:
		if ev_raw is Dictionary:
			var eid: String = String((ev_raw as Dictionary).get("id", ""))
			found_ids[eid] = (ev_raw as Dictionary)

	# Check presence of required IDs without fixed total or order assertions
	for req_id: String in [
		"v3_emberglass_campfire",
		"v3_threadmill_sewing_circle",
		"v3_inkblack_unpicker_van",
		"v3_briar_button_mending_bench",
		"v3_moonlace_darning_parlor",
	]:
		_check(found_ids.has(req_id), "AC4: Shipped catalog contains event ID: " + req_id)

	# Verify authentic sewing circle details
	var threadmill: Dictionary = found_ids.get("v3_threadmill_sewing_circle", {})
	_check(threadmill.get("service_kind") == "SewingCircle", "AC4: Threadmill service_kind is SewingCircle")
	_check(threadmill.get("service_choice_id") == "borrow_spools", "AC4: Threadmill service_choice_id is borrow_spools")

	var moonlace: Dictionary = found_ids.get("v3_moonlace_darning_parlor", {})
	_check(moonlace.get("service_kind") == "SewingCircle", "AC4: Moonlace service_kind is SewingCircle")
	_check(moonlace.get("service_choice_id") == "sew_at_parlor", "AC4: Moonlace service_choice_id is sew_at_parlor")
