extends SceneTree
## Deterministic headless SceneTree test for the lane8 night-road batch: three
## hero-gated vitality bargains appended to data/events/v3_hero_vital_events.json
## (v3_tinker_copper_mangle, v3_yarn_ranger_nightloom_span,
## v3_button_golem_hollow_bell_press). Records are located by ID in the shipped
## catalog (never by pool totals or order) and settled through the real
## RunStitchedHeroVitalSeams adapter; authentication also runs through
## RunV3HeroVitalEventGate.

const SeamsAdapter = preload("res://scripts/run_stitched_hero_vital_seams.gd")

const EVENT_A := "v3_tinker_copper_mangle"
const EVENT_B := "v3_yarn_ranger_nightloom_span"
const EVENT_C := "v3_button_golem_hollow_bell_press"

var checks: int = 0
var failures: Array[String] = []


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _party(protagonist_id: String, protagonist_rank: int, protagonist_hp: int, protagonist_max_hp: int, protagonist_lost: bool = false) -> Array:
	var pool := ["warden", "seamstress", "tinker", "lantern_monk", "rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
	var selected_ids: Array[String] = [protagonist_id]
	for h_id in pool:
		if h_id != protagonist_id and selected_ids.size() < 4:
			selected_ids.append(h_id)
	var party: Array = []
	var ranks: Array[int] = [1, 2, 3, 4]
	ranks.erase(protagonist_rank)
	for i in range(4):
		var hid: String = selected_ids[i]
		if hid == protagonist_id:
			party.append({"id": hid, "rank": protagonist_rank, "hp": protagonist_hp, "max_hp": protagonist_max_hp, "lost": protagonist_lost})
		else:
			var companion_rank: int = ranks.pop_front()
			party.append({"id": hid, "rank": companion_rank, "hp": 25, "max_hp": 25, "lost": false})
	return party


func _find_record(catalog: Dictionary, event_id: String) -> Dictionary:
	for ev_raw: Variant in catalog.get("events", []):
		if ev_raw is Dictionary and String((ev_raw as Dictionary).get("id", "")) == event_id:
			return (ev_raw as Dictionary).duplicate(true)
	return {}


func _choices_by_id(container: Dictionary) -> Dictionary:
	var map := {}
	for c_raw: Variant in container.get("choices", []):
		if c_raw is Dictionary:
			map[String((c_raw as Dictionary).get("id", ""))] = c_raw
	return map


func _initialize() -> void:
	_test_catalog_records_and_gate_authentication()
	_test_event_a_tinker_primary_with_rng_witnesses()
	_test_event_b_ranger_primary()
	_test_event_c_golem_primary()
	_test_alternate_choices()
	_test_wallet_and_floor_refusals()
	_test_absent_and_lost_hero_rejection()
	_test_guard_refusals_no_drift()
	_test_leave_and_snapshot_detachment()
	_test_older_records_still_valid()

	if failures.is_empty():
		print("stitched_s6_hero_vital_night_trade_batch_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("stitched_s6_hero_vital_night_trade_batch_test: FAILED (%d/%d checks failed)" % [failures.size(), checks])
		quit(1)


## AC1: the shipped catalog contains the three new records with the exact approved
## heroes, titles, choice IDs and four-key integer outcomes, each with exactly one
## zero "leave"; the whole catalog still authenticates through the gate.
func _test_catalog_records_and_gate_authentication() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	_check(not catalog.is_empty(), "catalog: shipped catalog loads")
	_check(catalog.get("events", []) is Array and not (catalog.get("events", []) as Array).is_empty(), "catalog: events array non-empty")

	var expected := {
		EVENT_A: {
			"required_hero": "tinker",
			"title": "The Copper Mangle",
			"choices": {
				"tighten_mangle": {"gold": 0, "scraps": -2, "hp": -3, "max_hp": 4},
				"sell_backplate": {"gold": 26, "scraps": 0, "hp": 0, "max_hp": -2},
				"leave": {"gold": 0, "scraps": 0, "hp": 0, "max_hp": 0},
			},
		},
		EVENT_B: {
			"required_hero": "yarn_ranger",
			"title": "The Nightloom Span",
			"choices": {
				"buy_moonloom_hem": {"gold": -18, "scraps": 0, "hp": 0, "max_hp": 3},
				"cut_bridge_lashing": {"gold": 0, "scraps": 3, "hp": -7, "max_hp": 0},
				"leave": {"gold": 0, "scraps": 0, "hp": 0, "max_hp": 0},
			},
		},
		EVENT_C: {
			"required_hero": "button_golem",
			"title": "The Hollow Bell Press",
			"choices": {
				"fit_bell_lining": {"gold": 0, "scraps": -2, "hp": 5, "max_hp": 2},
				"pawn_bell_heart": {"gold": 30, "scraps": 0, "hp": 0, "max_hp": -3},
				"leave": {"gold": 0, "scraps": 0, "hp": 0, "max_hp": 0},
			},
		},
	}
	for event_id: String in expected.keys():
		var record: Dictionary = _find_record(catalog, event_id)
		_check(not record.is_empty(), "catalog: %s present by ID" % event_id)
		if record.is_empty():
			continue
		var spec: Dictionary = expected[event_id]
		_check(record.size() == 5, "catalog: %s has exactly five keys" % event_id)
		_check(record.get("required_hero") == spec["required_hero"], "catalog: %s required_hero is %s" % [event_id, spec["required_hero"]])
		_check(String(record.get("title", "")) == String(spec["title"]), "catalog: %s title matches" % event_id)
		_check(String(record.get("description", "")).length() > 0, "catalog: %s description non-empty" % event_id)
		var choices: Array = record.get("choices", [])
		_check(choices.size() == 3, "catalog: %s has exactly three choices" % event_id)
		var seen := {}
		var leave_count := 0
		for c_raw: Variant in choices:
			var c: Dictionary = c_raw
			_check(c.size() == 3, "catalog: %s choice has exactly three keys" % event_id)
			var cid: String = String(c.get("id", ""))
			_check(not seen.has(cid), "catalog: %s choice id '%s' distinct" % [event_id, cid])
			seen[cid] = true
			var outcome: Dictionary = c.get("outcome", {})
			_check(outcome.size() == 4, "catalog: %s outcome '%s' has exactly four keys" % [event_id, cid])
			var exp: Dictionary = (spec["choices"] as Dictionary).get(cid, {})
			for k in ["gold", "scraps", "hp", "max_hp"]:
				var val: Variant = outcome.get(k)
				_check(typeof(val) == TYPE_INT or (typeof(val) == TYPE_FLOAT and is_finite(val) and floor(val) == val), "catalog: %s outcome %s.%s is integer-valued" % [event_id, cid, k])
				if exp.has(k):
					_check(int(outcome.get(k)) == int(exp[k]), "catalog: %s outcome %s.%s == %d" % [event_id, cid, k, int(exp[k])])
			if cid == "leave":
				leave_count += 1
				_check(int(outcome.get("gold", 1)) == 0 and int(outcome.get("scraps", 1)) == 0 and int(outcome.get("hp", 1)) == 0 and int(outcome.get("max_hp", 1)) == 0, "catalog: %s leave outcome all zero" % event_id)
		_check(leave_count == 1, "catalog: %s has exactly one leave choice" % event_id)

	# The gate constructor validates every shipped record; offers prove authentication.
	var gate := RunV3HeroVitalEventGate.new(["tinker", "yarn_ranger", "button_golem", "warden"])
	_check(gate.is_valid(), "gate: service valid over shipped catalog (all records authenticate)")
	var offered := {}
	for offer: Variant in gate.get_offers():
		offered[String((offer as Dictionary).get("id", ""))] = true
	_check(offered.has(EVENT_A) and offered.has(EVENT_B) and offered.has(EVENT_C), "gate: offers contain all three new event IDs")
	_check(offered.has("v3_warden_buckle_heart_ward"), "gate: offers still contain v3_warden_buckle_heart_ward")

	# Full gate-level enter + settle for Event A through RunV3HeroVitalEventGate.
	var snap := {"gold": 5, "scraps": 2, "hero": {"id": "tinker", "hp": 20, "max_hp": 20}}
	var visit := gate.enter(EVENT_A, snap)
	_check(visit != null and visit.is_valid(), "gate: enter(%s) admits living Tinker" % EVENT_A)
	if visit != null and visit.is_valid():
		var res: Dictionary = visit.choose_with_vitals("tighten_mangle", snap)
		_check(res.get("ok", false) == true, "gate: tighten_mangle settles through the gate")
		_check(res.get("event_id") == EVENT_A and res.get("choice_id") == "tighten_mangle", "gate: receipt event/choice IDs")
		var st: Dictionary = res.get("state", {})
		_check(st.get("gold") == 5 and st.get("scraps") == 0, "gate: wallet settled to 5 gold / 0 scraps")
		_check((st.get("hero", {}) as Dictionary).get("hp") == 17 and (st.get("hero", {}) as Dictionary).get("max_hp") == 24, "gate: hero projected to 17/24")
		_check(visit.is_claimed(), "gate: visit latched claimed")


## AC2/AC4: Event A primary. Tinker at rank 2, 20/20, wallet 5 gold / 2 scraps;
## tighten_mangle settles exactly (-2 scraps, -3 HP, +4 max HP) with projected
## 17/24 and a claim latch; global seed()/randi() witnesses prove no RNG draw.
func _test_event_a_tinker_primary_with_rng_witnesses() -> void:
	var record: Dictionary = _find_record(RunV3HeroVitalEventGate.load_shipped_catalog(), EVENT_A)
	_check(not record.is_empty(), "A: record found by ID")
	var party: Array = _party("tinker", 2, 20, 20, false)
	var wallet := {"gold": 5, "scraps": 2}
	var node_id := "node_lane8_mangle_primary"
	var caller_party: Array = party.duplicate(true)
	var caller_wallet: Dictionary = wallet.duplicate(true)
	var caller_record: Dictionary = record.duplicate(true)

	seed(777001)
	var witness_before: int = randi()
	seed(777001)
	var seeded := RandomNumberGenerator.new()
	seeded.seed = 31337
	var rng_state_before: int = seeded.state

	var visit := SeamsAdapter.open_stitched(node_id, record, party, wallet)
	_check(visit != null and visit.is_valid() and visit.is_open() and not visit.is_claimed(), "A: visit opens")
	_check(visit.get_event_id() == EVENT_A and visit.get_required_hero() == "tinker" and visit.get_node_id() == node_id, "A: event/hero/node IDs")

	var quote: Dictionary = visit.preview_choices()
	_check(quote.get("ok", false) == true, "A: quote ok")
	var q: Dictionary = _choices_by_id(quote)
	var c_tighten: Dictionary = q.get("tighten_mangle", {})
	_check(c_tighten.get("available") == true and c_tighten.get("affordable") == true, "A: tighten_mangle available")
	_check(c_tighten.get("gold_delta") == 0 and c_tighten.get("scraps_delta") == -2 and c_tighten.get("hp_delta") == -3 and c_tighten.get("max_hp_delta") == 4, "A: quote deltas exact")
	_check(c_tighten.get("projected_max_hp") == 24 and c_tighten.get("projected_hp") == 17 and c_tighten.get("effective_hp_delta") == -3, "A: quote projects 17/24")
	_check(c_tighten.get("target_hero_id") == "tinker" and c_tighten.get("target_hero_rank") == 2, "A: quote targets rank-2 tinker")
	_check(c_tighten.get("projected_gold") == 5 and c_tighten.get("projected_scraps") == 0, "A: quote projects wallet 5/0")

	var opening: Dictionary = visit.read_state()
	var opening_copy: Dictionary = opening.duplicate(true)
	var receipt: Dictionary = visit.choose("tighten_mangle", node_id, opening)
	_check(receipt.get("ok", false) == true, "A: claim succeeds")
	_check(receipt.get("choice_id") == "tighten_mangle" and receipt.get("event_id") == EVENT_A, "A: receipt choice/event IDs")
	_check(receipt.get("hero_id") == "tinker" and receipt.get("target_hero_id") == "tinker" and receipt.get("target_hero_rank") == 2, "A: receipt hero identity and rank")
	_check(receipt.get("gold_delta") == 0 and receipt.get("scraps_delta") == -2 and receipt.get("hp_delta") == -3 and receipt.get("max_hp_delta") == 4, "A: receipt signed deltas")
	_check(receipt.get("projected_max_hp") == 24 and receipt.get("projected_hp") == 17 and receipt.get("effective_hp_delta") == -3, "A: receipt projections 17/24 (lasting max HP 24)")
	_check(receipt.get("wallet", {}).get("gold") == 5 and receipt.get("wallet", {}).get("scraps") == 0, "A: wallet exactly 5/0, spent exactly 2 scraps")
	var intents: Dictionary = receipt.get("intents", {})
	_check(intents.get("hero_id") == "tinker" and intents.get("max_hp_delta") == 4 and intents.get("hp_delta") == -3 and intents.get("scraps_delta") == -2, "A: lasting intent receipt")
	_check(visit.is_claimed() and not visit.is_open() and not visit.is_valid(), "A: claim latch set")
	var after_state: Dictionary = visit.read_state()
	_check(after_state.get("claimed") == true and after_state.get("open") == false and after_state.get("version") == 1, "A: state latch version 1")
	_check(after_state.get("wallet") == {"gold": 5, "scraps": 0}, "A: state wallet updated")

	var witness_after: int = randi()
	_check(witness_after == witness_before, "A: global seed()/randi() sequence untouched by open/quote/claim")
	_check(seeded.state == rng_state_before, "A: seeded RandomNumberGenerator state untouched")
	_check(party == caller_party and wallet == caller_wallet and record == caller_record, "A: caller inputs unmodified")
	_check(opening == opening_copy, "A: returned opening snapshot unmodified by claim")


## AC2: Event B primary. Yarn Ranger at rank 3, 18/20, wallet 18 gold;
## buy_moonloom_hem settles exactly (-18 gold, +3 max HP) with projected 18/23.
func _test_event_b_ranger_primary() -> void:
	var record: Dictionary = _find_record(RunV3HeroVitalEventGate.load_shipped_catalog(), EVENT_B)
	_check(not record.is_empty(), "B: record found by ID")
	var party: Array = _party("yarn_ranger", 3, 18, 20, false)
	var wallet := {"gold": 18, "scraps": 0}
	var node_id := "node_lane8_nightloom_primary"
	var visit := SeamsAdapter.open_stitched(node_id, record, party, wallet)
	_check(visit.is_valid() and visit.is_open(), "B: visit opens")
	var q: Dictionary = _choices_by_id(visit.preview_choices())
	var c_buy: Dictionary = q.get("buy_moonloom_hem", {})
	_check(c_buy.get("available") == true, "B: buy_moonloom_hem available at exactly 18 gold")
	_check(c_buy.get("gold_delta") == -18 and c_buy.get("scraps_delta") == 0 and c_buy.get("hp_delta") == 0 and c_buy.get("max_hp_delta") == 3, "B: quote deltas exact")
	_check(c_buy.get("projected_max_hp") == 23 and c_buy.get("projected_hp") == 18 and c_buy.get("projected_gold") == 0, "B: quote projects 18/23 and gold 0")
	_check(c_buy.get("target_hero_id") == "yarn_ranger" and c_buy.get("target_hero_rank") == 3, "B: quote targets rank-3 ranger")
	var opening: Dictionary = visit.read_state()
	var receipt: Dictionary = visit.choose("buy_moonloom_hem", node_id, opening)
	_check(receipt.get("ok", false) == true, "B: claim succeeds")
	_check(receipt.get("gold_delta") == -18 and receipt.get("scraps_delta") == 0 and receipt.get("hp_delta") == 0 and receipt.get("max_hp_delta") == 3, "B: receipt signed deltas")
	_check(receipt.get("projected_max_hp") == 23 and receipt.get("projected_hp") == 18, "B: receipt projects lasting max HP 23, HP 18")
	_check(receipt.get("wallet", {}).get("gold") == 0 and receipt.get("wallet", {}).get("scraps") == 0, "B: spent exactly 18 gold")
	_check(receipt.get("hero_id") == "yarn_ranger" and visit.is_claimed() and not visit.is_open(), "B: hero identity and latch")


## AC2: Event C primary. Button Golem at rank 2, 15/20, wallet 2 scraps;
## fit_bell_lining settles exactly (-2 scraps, +5 HP, +2 max HP) with projected 20/22.
func _test_event_c_golem_primary() -> void:
	var record: Dictionary = _find_record(RunV3HeroVitalEventGate.load_shipped_catalog(), EVENT_C)
	_check(not record.is_empty(), "C: record found by ID")
	var party: Array = _party("button_golem", 2, 15, 20, false)
	var wallet := {"gold": 0, "scraps": 2}
	var node_id := "node_lane8_bellpress_primary"
	var visit := SeamsAdapter.open_stitched(node_id, record, party, wallet)
	_check(visit.is_valid() and visit.is_open(), "C: visit opens")
	var q: Dictionary = _choices_by_id(visit.preview_choices())
	var c_fit: Dictionary = q.get("fit_bell_lining", {})
	_check(c_fit.get("available") == true, "C: fit_bell_lining available at exactly 2 scraps")
	_check(c_fit.get("gold_delta") == 0 and c_fit.get("scraps_delta") == -2 and c_fit.get("hp_delta") == 5 and c_fit.get("max_hp_delta") == 2, "C: quote deltas exact")
	_check(c_fit.get("projected_max_hp") == 22 and c_fit.get("projected_hp") == 20 and c_fit.get("projected_scraps") == 0, "C: quote projects 20/22, scraps 0")
	_check(c_fit.get("target_hero_id") == "button_golem" and c_fit.get("target_hero_rank") == 2, "C: quote targets rank-2 golem")
	var opening: Dictionary = visit.read_state()
	var receipt: Dictionary = visit.choose("fit_bell_lining", node_id, opening)
	_check(receipt.get("ok", false) == true, "C: claim succeeds")
	_check(receipt.get("gold_delta") == 0 and receipt.get("scraps_delta") == -2 and receipt.get("hp_delta") == 5 and receipt.get("max_hp_delta") == 2, "C: receipt signed deltas")
	_check(receipt.get("projected_max_hp") == 22 and receipt.get("projected_hp") == 20 and receipt.get("effective_hp_delta") == 5, "C: receipt projects max HP 22, HP 20")
	_check(receipt.get("wallet", {}).get("gold") == 0 and receipt.get("wallet", {}).get("scraps") == 0, "C: spent exactly 2 scraps")
	_check(receipt.get("hero_id") == "button_golem" and visit.is_claimed(), "C: hero identity and latch")


## AC2: the three alternative decisions settle in separate fresh visits:
## sell_backplate (gold +26, max HP 20 -> 18), cut_bridge_lashing (-7 HP, +3 scraps)
## and pawn_bell_heart (gold +30, max HP 20 -> 17); no negative wallet anywhere.
func _test_alternate_choices() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var rec_a: Dictionary = _find_record(catalog, EVENT_A)
	var rec_b: Dictionary = _find_record(catalog, EVENT_B)
	var rec_c: Dictionary = _find_record(catalog, EVENT_C)

	var visit_a := SeamsAdapter.open_stitched("node_lane8_mangle_alt", rec_a, _party("tinker", 1, 20, 20, false), {"gold": 0, "scraps": 5})
	var r_a: Dictionary = visit_a.choose("sell_backplate", "node_lane8_mangle_alt", visit_a.read_state())
	_check(r_a.get("ok", false) == true, "alt A: sell_backplate succeeds")
	_check(r_a.get("gold_delta") == 26 and r_a.get("scraps_delta") == 0 and r_a.get("hp_delta") == 0 and r_a.get("max_hp_delta") == -2, "alt A: signed deltas")
	_check(r_a.get("projected_max_hp") == 18 and r_a.get("projected_hp") == 18, "alt A: max HP sacrifice 20 -> 18 projected")
	_check(r_a.get("wallet", {}).get("gold") == 26 and r_a.get("wallet", {}).get("scraps") == 5, "alt A: wallet 26/5, never negative")
	_check(r_a.get("wallet", {}).get("gold") >= 0 and r_a.get("wallet", {}).get("scraps") >= 0, "alt A: no negative wallet")

	var visit_b := SeamsAdapter.open_stitched("node_lane8_nightloom_alt", rec_b, _party("yarn_ranger", 4, 18, 20, false), {"gold": 3, "scraps": 0})
	var r_b: Dictionary = visit_b.choose("cut_bridge_lashing", "node_lane8_nightloom_alt", visit_b.read_state())
	_check(r_b.get("ok", false) == true, "alt B: cut_bridge_lashing succeeds")
	_check(r_b.get("gold_delta") == 0 and r_b.get("scraps_delta") == 3 and r_b.get("hp_delta") == -7 and r_b.get("max_hp_delta") == 0, "alt B: signed deltas")
	_check(r_b.get("projected_hp") == 11 and r_b.get("projected_max_hp") == 20, "alt B: -7 HP projected to 11/20")
	_check(r_b.get("wallet", {}).get("gold") == 3 and r_b.get("wallet", {}).get("scraps") == 3, "alt B: +3 scraps settled")

	var visit_c := SeamsAdapter.open_stitched("node_lane8_bellpress_alt", rec_c, _party("button_golem", 3, 20, 20, false), {"gold": 0, "scraps": 1})
	var r_c: Dictionary = visit_c.choose("pawn_bell_heart", "node_lane8_bellpress_alt", visit_c.read_state())
	_check(r_c.get("ok", false) == true, "alt C: pawn_bell_heart succeeds")
	_check(r_c.get("gold_delta") == 30 and r_c.get("scraps_delta") == 0 and r_c.get("hp_delta") == 0 and r_c.get("max_hp_delta") == -3, "alt C: signed deltas")
	_check(r_c.get("projected_max_hp") == 17 and r_c.get("projected_hp") == 17, "alt C: max HP sacrifice 20 -> 17 projected")
	_check(r_c.get("wallet", {}).get("gold") == 30 and r_c.get("wallet", {}).get("scraps") == 1, "alt C: wallet 30/1, never negative")


## AC3: one-short wallets refuse without mutation; max-HP sacrifices that would
## drop below the floor of 10 refuse at initial max_hp 11 and 10; RNG untouched.
func _test_wallet_and_floor_refusals() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var rec_a: Dictionary = _find_record(catalog, EVENT_A)
	var rec_b: Dictionary = _find_record(catalog, EVENT_B)
	var rec_c: Dictionary = _find_record(catalog, EVENT_C)

	seed(888002)
	var witness_before: int = randi()
	seed(888002)

	# Event A one scrap short (cost 2): refusal, no drift, visit stays open.
	var visit_short := SeamsAdapter.open_stitched("node_lane8_mangle_short", rec_a, _party("tinker", 2, 20, 20, false), {"gold": 5, "scraps": 1})
	_check(visit_short.is_valid(), "refusal: one-short visit still opens")
	var before_short: Dictionary = visit_short.read_state()
	var q_short: Dictionary = _choices_by_id(visit_short.preview_choices())
	_check(q_short.get("tighten_mangle", {}).get("available") == false, "refusal: tighten_mangle unavailable at 1 scrap")
	_check(String(q_short.get("tighten_mangle", {}).get("blocked", "")).contains("scraps"), "refusal: blocked reason mentions scraps")
	var r_short: Dictionary = visit_short.choose("tighten_mangle", "node_lane8_mangle_short", before_short)
	_check(r_short.get("ok", false) == false, "refusal: one-short tighten_mangle refused")
	_check(visit_short.is_open() and not visit_short.is_claimed(), "refusal: visit still open after refusal")
	_check(visit_short.read_state() == before_short, "refusal: no state drift after one-short refusal")

	# Event B one gold short (cost 18): refusal, no drift.
	var visit_gshort := SeamsAdapter.open_stitched("node_lane8_nightloom_short", rec_b, _party("yarn_ranger", 3, 18, 20, false), {"gold": 17, "scraps": 0})
	var before_gshort: Dictionary = visit_gshort.read_state()
	var r_gshort: Dictionary = visit_gshort.choose("buy_moonloom_hem", "node_lane8_nightloom_short", before_gshort)
	_check(r_gshort.get("ok", false) == false, "refusal: one-short gold buy_moonloom_hem refused")
	_check(visit_gshort.read_state() == before_gshort and visit_gshort.is_open(), "refusal: no drift after gold refusal")

	# Event A floor: Tinker max_hp 11, sell_backplate (-2) would give 9 < 10.
	var visit_floor_a := SeamsAdapter.open_stitched("node_lane8_mangle_floor", rec_a, _party("tinker", 1, 11, 11, false), {"gold": 0, "scraps": 5})
	var before_floor_a: Dictionary = visit_floor_a.read_state()
	var q_floor_a: Dictionary = _choices_by_id(visit_floor_a.preview_choices())
	_check(q_floor_a.get("sell_backplate", {}).get("available") == false, "refusal: sell_backplate unavailable at max_hp 11")
	var r_floor_a: Dictionary = visit_floor_a.choose("sell_backplate", "node_lane8_mangle_floor", before_floor_a)
	_check(r_floor_a.get("ok", false) == false, "refusal: below-floor max-HP sacrifice refused (11 -> 9)")
	_check(visit_floor_a.read_state() == before_floor_a and visit_floor_a.is_open(), "refusal: no drift after floor refusal A")
	var r_floor_a_leave: Dictionary = visit_floor_a.choose("leave", "node_lane8_mangle_floor", visit_floor_a.read_state())
	_check(r_floor_a_leave.get("ok", false) == true, "refusal: visit still usable for leave after floor refusal")

	# Event C floor: Golem max_hp 10, pawn_bell_heart (-3) would give 7 < 10.
	var visit_floor_c := SeamsAdapter.open_stitched("node_lane8_bellpress_floor", rec_c, _party("button_golem", 2, 10, 10, false), {"gold": 0, "scraps": 1})
	var before_floor_c: Dictionary = visit_floor_c.read_state()
	var r_floor_c: Dictionary = visit_floor_c.choose("pawn_bell_heart", "node_lane8_bellpress_floor", before_floor_c)
	_check(r_floor_c.get("ok", false) == false, "refusal: below-floor max-HP sacrifice refused (10 -> 7)")
	_check(visit_floor_c.read_state() == before_floor_c and visit_floor_c.is_open(), "refusal: no drift after floor refusal C")

	_check(randi() == witness_before, "refusal: global seed()/randi() sequence untouched by refusals")


## AC3: absent or LOST required hero fails closed at open and at choose.
func _test_absent_and_lost_hero_rejection() -> void:
	var rec_a: Dictionary = _find_record(RunV3HeroVitalEventGate.load_shipped_catalog(), EVENT_A)
	var wallet := {"gold": 5, "scraps": 2}

	var absent_party: Array = [
		{"id": "warden", "rank": 1, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "seamstress", "rank": 2, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "lantern_monk", "rank": 3, "hp": 20, "max_hp": 20, "lost": false},
		{"id": "button_golem", "rank": 4, "hp": 20, "max_hp": 20, "lost": false},
	]
	var visit_absent := SeamsAdapter.open_stitched("node_lane8_absent", rec_a, absent_party, wallet)
	_check(not visit_absent.is_valid(), "absent: visit with no Tinker is invalid")
	_check(visit_absent.choose("tighten_mangle", "node_lane8_absent", {}).get("ok", false) == false, "absent: choose on invalid visit refused")

	var visit_lost := SeamsAdapter.open_stitched("node_lane8_lost", rec_a, _party("tinker", 1, 10, 20, true), wallet)
	_check(not visit_lost.is_valid(), "lost: visit with LOST Tinker is invalid")
	_check(visit_lost.choose("tighten_mangle", "node_lane8_lost", {}).get("ok", false) == false, "lost: choose on LOST visit refused")


## AC3: wrong node, stale/missing snapshot and second claim refuse with no drift.
func _test_guard_refusals_no_drift() -> void:
	var rec_a: Dictionary = _find_record(RunV3HeroVitalEventGate.load_shipped_catalog(), EVENT_A)
	var party: Array = _party("tinker", 2, 20, 20, false)
	var wallet := {"gold": 5, "scraps": 2}
	var node_id := "node_lane8_mangle_guards"
	var visit := SeamsAdapter.open_stitched(node_id, rec_a, party, wallet)
	_check(visit.is_valid(), "guards: visit opens")
	var opening: Dictionary = visit.read_state()

	var r_wrong_node: Dictionary = visit.choose("tighten_mangle", "node_lane8_wrong", opening)
	_check(r_wrong_node.get("ok", false) == false, "guards: wrong node ID refused")
	var r_null_state: Dictionary = visit.choose("tighten_mangle", node_id, null)
	_check(r_null_state.get("ok", false) == false, "guards: missing expected state refused")
	var stale: Dictionary = opening.duplicate(true)
	stale["version"] = 999
	var r_stale: Dictionary = visit.choose("tighten_mangle", node_id, stale)
	_check(r_stale.get("ok", false) == false, "guards: stale expected state refused")
	_check(visit.is_open() and not visit.is_claimed() and visit.read_state() == opening, "guards: no drift after guard refusals")

	var receipt: Dictionary = visit.choose("tighten_mangle", node_id, opening)
	_check(receipt.get("ok", false) == true, "guards: valid claim succeeds after refusals")
	var claimed_state: Dictionary = visit.read_state()
	var r_second: Dictionary = visit.choose("leave", node_id, visit.read_state())
	_check(r_second.get("ok", false) == false, "guards: second claim refused")
	_check(visit.read_state() == claimed_state, "guards: no drift after second-claim refusal")


## AC3: unmodified Leave commits once with zero deltas and an unchanged wallet on
## each new event; mutating returned snapshots/receipts never changes authority.
func _test_leave_and_snapshot_detachment() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var cases := [
		[EVENT_A, "tinker", "node_lane8_leave_a"],
		[EVENT_B, "yarn_ranger", "node_lane8_leave_b"],
		[EVENT_C, "button_golem", "node_lane8_leave_c"],
	]
	for case_raw: Variant in cases:
		var c: Array = case_raw
		var rec: Dictionary = _find_record(catalog, String(c[0]))
		var node_id: String = String(c[2])
		var wallet := {"gold": 7, "scraps": 4}
		var visit := SeamsAdapter.open_stitched(node_id, rec, _party(String(c[1]), 2, 20, 20, false), wallet)
		_check(visit.is_valid(), "leave: %s visit opens" % String(c[0]))
		var r_leave: Dictionary = visit.choose("leave", node_id, visit.read_state())
		_check(r_leave.get("ok", false) == true, "leave: %s commits once" % String(c[0]))
		_check(r_leave.get("gold_delta") == 0 and r_leave.get("scraps_delta") == 0 and r_leave.get("hp_delta") == 0 and r_leave.get("max_hp_delta") == 0, "leave: %s all deltas zero" % String(c[0]))
		_check(r_leave.get("wallet", {}) == wallet, "leave: %s wallet unmodified" % String(c[0]))
		_check(r_leave.get("projected_max_hp") == 20 and r_leave.get("projected_hp") == 20, "leave: %s vitals unmodified" % String(c[0]))
		_check(visit.is_claimed() and not visit.is_open(), "leave: %s latched" % String(c[0]))
		_check(visit.choose("leave", node_id, visit.read_state()).get("ok", false) == false, "leave: %s second claim refused" % String(c[0]))

	# Detachment: mutating a returned snapshot or receipt must not change authority.
	var rec_a: Dictionary = _find_record(catalog, EVENT_A)
	var node_d := "node_lane8_detach"
	var party_d: Array = _party("tinker", 3, 20, 20, false)
	var wallet_d := {"gold": 5, "scraps": 2}
	var visit_d := SeamsAdapter.open_stitched(node_d, rec_a, party_d, wallet_d)
	var snap: Dictionary = visit_d.read_state()
	var pristine: Dictionary = snap.duplicate(true)
	snap["wallet"]["gold"] = 999
	snap["party"][0]["hp"] = 1
	snap["claimed"] = true
	snap["version"] = 42
	_check(visit_d.read_state() == pristine, "detach: mutating returned snapshot does not change authority")
	var receipt_d: Dictionary = visit_d.choose("tighten_mangle", node_d, visit_d.read_state())
	_check(receipt_d.get("ok", false) == true, "detach: claim with a fresh snapshot succeeds")
	receipt_d["state"]["wallet"]["gold"] = -1
	receipt_d["state"]["claimed"] = false
	_check(visit_d.read_state().get("wallet", {}).get("gold") == 5 and visit_d.is_claimed(), "detach: mutating receipt does not change authority")


## AC1 regression guard: earlier named records still exist with their stated
## required heroes and choice IDs and remain gate-authentic offers.
func _test_older_records_still_valid() -> void:
	var catalog: Dictionary = RunV3HeroVitalEventGate.load_shipped_catalog()
	var older := {
		"v3_warden_buckle_heart_ward": ["warden", ["reinforce_shield_seam", "sell_rivets", "leave"]],
		"v3_seamstress_crimson_quilt_surgeon": ["seamstress", ["stitch_wound", "donate_red_thread", "leave"]],
		"v3_yarn_ranger_starladder_bolas": ["yarn_ranger", ["buy_knotted_rung", "unpick_bolas_strand", "leave"]],
	}
	for event_id: String in older.keys():
		var spec: Array = older[event_id]
		var record: Dictionary = _find_record(catalog, event_id)
		_check(not record.is_empty(), "older: %s still present" % event_id)
		if record.is_empty():
			continue
		_check(record.get("required_hero") == String(spec[0]), "older: %s required_hero still %s" % [event_id, String(spec[0])])
		var ids: Array = spec[1]
		var q: Dictionary = _choices_by_id(record)
		for cid in ids:
			_check(q.has(String(cid)), "older: %s still offers choice '%s'" % [event_id, String(cid)])
		var leave_outcome: Dictionary = q.get("leave", {}).get("outcome", {})
		_check(int(leave_outcome.get("gold", 1)) == 0 and int(leave_outcome.get("scraps", 1)) == 0 and int(leave_outcome.get("hp", 1)) == 0 and int(leave_outcome.get("max_hp", 1)) == 0, "older: %s leave still all zero" % event_id)

	var gate := RunV3HeroVitalEventGate.new(["warden", "seamstress", "yarn_ranger", "tinker"])
	_check(gate.is_valid(), "older: gate still valid over shipped catalog")
	var offered := {}
	for offer: Variant in gate.get_offers():
		offered[String((offer as Dictionary).get("id", ""))] = true
	_check(offered.has("v3_warden_buckle_heart_ward") and offered.has("v3_seamstress_crimson_quilt_surgeon") and offered.has("v3_yarn_ranger_starladder_bolas"), "older: named records remain gate offers")
