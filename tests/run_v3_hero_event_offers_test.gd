extends SceneTree

const PARTY_A := ["warden", "seamstress", "tinker"]
const PARTY_B := ["lantern_monk", "rag_duelist", "tinker"]
## Design v4 Stitched runs pick four of eight heroes; this roster is the
## four-hero counterpart of PARTY_A used by the admission tests below.
const STITCHED_PARTY := ["warden", "seamstress", "tinker", "lantern_monk"]
const NEW_CHOICES := {
	"v3_warden_copper_chain_ferry": {"brace_ferry_chain": [20, 0], "buy_brass_buckles": [-14, 2], "leave": [0, 0]},
	"v3_seamstress_needle_oracle": {"untangle_oracle_thread": [24, -1], "buy_oracle_silk": [-18, 3], "leave": [0, 0]},
	"v3_tinker_spring_marionette": {"rewind_broken_heart": [32, -2], "salvage_worn_gears": [0, 2], "leave": [0, 0]},
	"v3_lantern_monk_mothlight_ferry": {"guide_moth_passengers": [19, 0], "buy_glowing_wicks": [-12, 2], "leave": [0, 0]},
	"v3_rag_duelist_cape_tribunal": {"mend_judges_cape": [23, -1], "buy_gilt_rapier_guard": [-19, 3], "leave": [0, 0]},
	"v3_scarecrow_raven_orchard": {"guard_raven_harvest": [0, 2], "trade_pitchfork_twine": [29, -2], "leave": [0, 0]},
}
## The six gothic hero stories appended by THIS task. Kept in their own
## task-local matrix (the earlier NEW_CHOICES matrix above is not reused or
## changed) and keyed by authored IDs only.
const BATCH_CHOICES := {
	"v3_warden_pincushion_gate": {
		"hold_pincushion_gate": [22, 0], "buy_quilted_shield_lacing": [-14, 2], "leave": [0, 0]},
	"v3_seamstress_crimson_bell_cord": {
		"rethread_crimson_bell": [27, -2], "salvage_red_bell_thread": [0, 2], "leave": [0, 0]},
	"v3_lantern_monk_mothveil_passage": {
		"guide_mothveil_pilgrims": [18, 0], "buy_amber_lantern_wicks": [-16, 3], "leave": [0, 0]},
	"v3_rag_duelist_cape_windmill": {
		"free_cape_blades": [24, -1], "gather_ribbon_offcuts": [0, 2], "leave": [0, 0]},
	"v3_yarn_ranger_bolas_mooring": {
		"recover_knotted_bolas": [0, 2], "sell_spare_knitting_knots": [20, -1], "leave": [0, 0]},
	"v3_button_golem_buttonlift": {
		"haul_buttonlift": [23, 0], "buy_brass_button_shanks": [-17, 3], "leave": [0, 0]},
}
const CASES := {
	"v3_warden_shield_menders": ["warden", "sell_spare_rivets", 17, -1],
	"v3_seamstress_thread_cart": ["seamstress", "buy_red_thread", -12, 2],
	"v3_tinker_clockwork_wagon": ["tinker", "fix_ratchet", 28, -2],
	"v3_lantern_monk_moth_vigil": ["lantern_monk", "buy_wax", -12, 2],
	"v3_rag_duelist_needle_fair": ["rag_duelist", "trade_ribbon", -10, 2],
	"v3_scarecrow_crow_roost": ["scarecrow", "sell_crow_feathers", 19, -1],
	"v3_yarn_ranger_knit_ford": ["yarn_ranger", "purchase_wool", -14, 2],
	"v3_button_golem_button_press": ["button_golem", "stamp_brass", 31, -2],
	"v3_lantern_monk_evening_beacon": ["lantern_monk", "trim_evening_wick", 16, -1],
	"v3_rag_duelist_scarlet_fair": ["rag_duelist", "buy_fencing_ribbon", -13, 2],
	"v3_warden_moonshield_watch": ["warden", "sell_guard_stitch", 21, -1],
	"v3_seamstress_scarlet_loom": ["seamstress", "trade_loom_thread", 24, -2],
	"v3_tinker_gearhouse_midnight": ["tinker", "tune_gearhouse", 27, -2],
	"v3_scarecrow_blackcrow_post": ["scarecrow", "buy_straw_twines", -13, 2],
	"v3_yarn_ranger_bolas_bridge": ["yarn_ranger", "sell_needlespool", 18, -1],
	"v3_button_golem_bell_foundry": ["button_golem", "buy_brass_thread", -19, 3],
	"v3_warden_buckle_checkpoint": ["warden", "sell_buckle_wire", 27, -2],
	"v3_seamstress_crimson_mending_queue": ["seamstress", "buy_moon_thread", -16, 3],
	"v3_tinker_gear_sideshow": ["tinker", "buy_spring_caps", -12, 2],
	"v3_scarecrow_crow_lantern_post": ["scarecrow", "sell_woven_straw", 23, -2],
	"v3_yarn_ranger_wool_signal_station": ["yarn_ranger", "sell_bolas_knots", 24, -2],
	"v3_button_golem_rivet_bridge": ["button_golem", "buy_brass_bobbins", -17, 3],
	"v3_lantern_monk_mothglass_chapel": ["lantern_monk", "relight_saffron_wick", 22, -1],
	"v3_rag_duelist_velvet_rapier_stage": ["rag_duelist", "buy_fencing_silk", -13, 2],
	"v3_tinker_brass_moth_clinic": ["tinker", "repair_bent_wing", 27, -2],
	"v3_scarecrow_pumpkin_seam_census": ["scarecrow", "register_harvest", 18, -1],
	"v3_yarn_ranger_tangled_willow": ["yarn_ranger", "buy_moss_bolas", -17, 3],
	"v3_button_golem_brass_keyhole": ["button_golem", "push_rivet_door", 29, -2],
	"v3_warden_copper_chain_ferry": ["warden", "buy_brass_buckles", -14, 2],
	"v3_seamstress_needle_oracle": ["seamstress", "untangle_oracle_thread", 24, -1],
	"v3_tinker_spring_marionette": ["tinker", "rewind_broken_heart", 32, -2],
	"v3_lantern_monk_mothlight_ferry": ["lantern_monk", "buy_glowing_wicks", -12, 2],
	"v3_rag_duelist_cape_tribunal": ["rag_duelist", "mend_judges_cape", 23, -1],
	"v3_scarecrow_raven_orchard": ["scarecrow", "trade_pitchfork_twine", 29, -2],
	"v3_warden_pincushion_gate": ["warden", "buy_quilted_shield_lacing", -14, 2],
	"v3_seamstress_crimson_bell_cord": ["seamstress", "rethread_crimson_bell", 27, -2],
	"v3_lantern_monk_mothveil_passage": ["lantern_monk", "buy_amber_lantern_wicks", -16, 3],
	"v3_rag_duelist_cape_windmill": ["rag_duelist", "free_cape_blades", 24, -1],
	"v3_yarn_ranger_bolas_mooring": ["yarn_ranger", "sell_spare_knitting_knots", 20, -1],
	"v3_button_golem_buttonlift": ["button_golem", "buy_brass_button_shanks", -17, 3],
}

var failures: Array[String] = []
var checks := 0
var catalog: Dictionary


func _initialize() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string(RunV3HeroEventOffers.CATALOG_PATH))
	var before := catalog.duplicate(true)
	seed(257)
	var expected_global := randi()
	seed(257)
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = 257
	var state := run_rng.state
	_test_parties_and_receipts()
	_test_new_choice_receipts()
	_test_batch_choice_receipts()
	_test_invalid_parties()
	_test_four_hero_stitched_admission()
	_test_invalid_catalogs()
	_test_isolation()
	_test_actionable_named_examples()
	_test_actionable_party_and_sorted_sampling()
	_test_actionable_exclusions_and_exhaustion()
	_test_actionable_invalid_inputs_and_isolation()
	_test_actionable_preview_anchors()
	_test_actionable_preview_sampling_and_replay()
	_test_actionable_preview_invalids_and_isolation()
	_test_v3_hero_vital_event_gate()
	_test_four_hero_vital_gate_admission()
	_check(_replay(257) == _replay(257), "whole offer/entry/receipt sequence replays exactly")
	_check(_replay_actionable(257) == _replay_actionable(257), "seeded actionable selection and settlement sequence replays exactly")
	_check(_replay_actionable_with_preview(257) == _replay_actionable_with_preview(257), "seeded actionable selection with preview and settlement sequence replays exactly")
	_check(catalog == before, "all operations preserve authored catalog")
	_check(run_rng.state == state and randi() == expected_global, "all paths consume neither unpassed seeded nor global RNG")
	for failure in failures:
		printerr(failure)
	print("run_v3_hero_event_offers_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _by_id(offers: Array, event_id: String) -> Dictionary:
	for record in offers:
		if record["id"] == event_id:
			return record
	return {}


func _test_parties_and_receipts() -> void:
	var reversed := catalog.duplicate(true)
	reversed["events"].reverse()
	for party in [PARTY_A, PARTY_B, ["scarecrow", "yarn_ranger", "button_golem"]]:
		var service := RunV3HeroEventOffers.new(party)
		var reordered := RunV3HeroEventOffers.new(party, reversed)
		_check(service.is_valid() and reordered.is_valid(), "canonical party accepted: " + str(party))
		for event_id in CASES:
			var spec: Array = CASES[event_id]
			var eligible: bool = party.has(spec[0])
			var offer := _by_id(service.get_offers(), event_id)
			_check(not offer.is_empty() == eligible, "individual eligibility: " + event_id + str(party))
			_check(_by_id(reordered.get_offers(), event_id) == offer, "record order independent: " + event_id)
			var visit := service.enter(event_id)
			if not eligible:
				_check(visit == null, "absent hero denies entry: " + event_id)
				continue
			_check(visit is RunEventChoice and visit.is_valid() and not visit.is_claimed(), "real unclaimed visit: " + event_id)
			if visit == null:
				continue
			var wallet := {"gold": 30, "scraps": 3}
			var preview := visit.preview_wallet_choices(wallet)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and not visit.is_claimed(), "genuine affordable preview before claim: " + event_id)
			var previewed := {}
			for entry in preview.get("choices", []):
				if entry is Dictionary and entry.get("choice_id") == spec[1]:
					previewed = entry
			_check(previewed.get("gold_delta") == spec[2] and previewed.get("scraps_delta") == spec[3]
				and previewed.get("affordable") == true
				and previewed.get("wallet") == {"gold": 30 + spec[2], "scraps": 3 + spec[3]},
				"preview quotes the exact affordable signed delta: " + event_id)
			var receipt := visit.choose_with_wallet(spec[1], wallet)
			_check(receipt == {"ok": true, "event_id": event_id, "choice_id": spec[1],
				"wallet": {"gold": 30 + spec[2], "scraps": 3 + spec[3]}}, "exact signed receipt: " + event_id)
			_check(wallet == {"gold": 30, "scraps": 3} and visit.is_claimed() and not visit.is_valid(), "wallet detached and claim latched")
			var settled: Dictionary = receipt["wallet"]
			_check(visit.choose_with_wallet(spec[1], settled) == {"ok": false, "event_id": "", "choice_id": "", "wallet": settled}, "replay cannot settle twice")
			_check(not visit.choose_with_wallet("leave", settled)["ok"], "alternate choice also blocked after claim")
			var poor := service.enter(event_id)
			var empty := {"gold": 0, "scraps": 0}
			for bad_choice in ["stale_choice", "", null, {"id": spec[1]}, spec[1]]:
				_check(poor.choose_with_wallet(bad_choice, empty) == {"ok": false, "event_id": "", "choice_id": "", "wallet": empty}, "unknown/malformed/unaffordable choice refuses unchanged")
				_check(poor.is_valid() and not poor.is_claimed(), "refusal does not consume claim")
			_check(not poor.choose_with_wallet("leave", {"gold": -1, "scraps": 0})["ok"] and not poor.is_claimed(), "invalid wallet does not claim")
			_check(poor.choose_with_wallet("leave", empty)["ok"] and poor.is_claimed(), "same visit recovers with authored Leave")
		for bad_id in ["unknown", "v3_deleted_event", "", null, 1, {"id": "v3_tinker_clockwork_wagon"}]:
			_check(service.enter(bad_id) == null, "entry accepts only eligible catalog IDs")


func _test_new_choice_receipts() -> void:
	for party in [PARTY_A, PARTY_B, ["scarecrow", "yarn_ranger", "button_golem"]]:
		var service := RunV3HeroEventOffers.new(party)
		_check(service.is_valid(), "new choice matrix has a valid party service")
		for event_id in NEW_CHOICES:
			if not party.has(CASES[event_id][0]):
				continue
			for choice_id in NEW_CHOICES[event_id]:
				var delta: Array = NEW_CHOICES[event_id][choice_id]
				var visit := service.enter(event_id)
				_check(visit != null and visit.is_valid(), "new option has an authentic visit: " + event_id)
				if visit == null:
					continue
				var wallet := {"gold": 40, "scraps": 4}
				var projected := {"gold": 40 + delta[0], "scraps": 4 + delta[1]}
				var preview := visit.preview_wallet_choices(wallet)
				var quote := {}
				for entry in preview.get("choices", []):
					if entry.get("choice_id") == choice_id:
						quote = entry
				_check(quote == {"choice_id": choice_id, "gold_delta": delta[0],
					"scraps_delta": delta[1], "affordable": true, "wallet": projected},
					"admitted option previews independent exact deltas: " + event_id + "/" + choice_id)
				var receipt := visit.choose_with_wallet(choice_id, wallet)
				_check(receipt == {"ok": true, "event_id": event_id, "choice_id": choice_id,
					"wallet": projected} and wallet == {"gold": 40, "scraps": 4}
					and visit.is_claimed() and not visit.is_valid(), "admitted option settles once: " + event_id)
				receipt.wallet.gold = 999
				_check(visit.choose_with_wallet(choice_id, projected) == {"ok": false,
					"event_id": "", "choice_id": "", "wallet": projected}, "detached claim cannot replay")
	# The new records obey the same canonical authentication as the old ones.
	for event_id in NEW_CHOICES:
		var record := _by_id(catalog.events, event_id)
		_check(not record.is_empty(), "new forgery fixture exists: " + event_id)
		if record.is_empty():
			continue
		var forged := record.duplicate(true)
		forged.choices[0].outcome.gold = 999
		_reject_catalog({"events": [forged]})


func _test_batch_choice_receipts() -> void:
	# Admission, detached-offer, reordered-source and per-choice receipt matrix
	# for the six gothic stories appended by this task. Each party covers both
	# present (admitted) and absent (excluded) batch heroes.
	var listed := {}
	for event_id in BATCH_CHOICES:
		_check(not listed.has(event_id), "batch offer case is listed once: " + event_id)
		listed[event_id] = true
		_check(CASES.has(event_id), "batch offer case has a party anchor: " + event_id)
	var reversed := catalog.duplicate(true)
	reversed["events"].reverse()
	for party in [PARTY_A, PARTY_B, ["scarecrow", "yarn_ranger", "button_golem"]]:
		var service := RunV3HeroEventOffers.new(party)
		var reordered := RunV3HeroEventOffers.new(party, reversed)
		_check(service.is_valid() and reordered.is_valid(),
			"batch admission has a valid canonical and reordered service: " + str(party))
		for event_id in BATCH_CHOICES:
			var spec: Array = CASES[event_id]
			var eligible: bool = party.has(spec[0])
			var offer := _by_id(service.get_offers(), event_id)
			_check(not offer.is_empty() == eligible,
				"batch hero gate admits iff the required hero is present: " + event_id + str(party))
			_check(_by_id(reordered.get_offers(), event_id) == offer,
				"reversed source leaves the batch offer unchanged: " + event_id)
			if eligible:
				_check(offer == _by_id(catalog["events"], event_id),
					"batch detached offer equals the authored record: " + event_id)
			var visit := service.enter(event_id)
			if not eligible:
				_check(visit == null, "batch absent hero denies entry: " + event_id + str(party))
				continue
			_check(visit is RunEventChoice and visit.is_valid() and not visit.is_claimed(),
				"batch present hero opens a real unclaimed visit: " + event_id + str(party))
			if visit == null:
				continue
			_check(visit.get_event() == _by_id(catalog["events"], event_id),
				"batch visit carries the authentic authored snapshot: " + event_id)
			for choice_id in BATCH_CHOICES[event_id]:
				var delta: Array = BATCH_CHOICES[event_id][choice_id]
				var choice_visit := service.enter(event_id)
				_check(choice_visit != null and choice_visit.is_valid(),
					"batch option has an independent fresh visit: " + event_id)
				if choice_visit == null:
					continue
				var wallet := {"gold": 40, "scraps": 4}
				var wallet_before: Dictionary = wallet.duplicate(true)
				var projected := {"gold": 40 + int(delta[0]), "scraps": 4 + int(delta[1])}
				var preview := choice_visit.preview_wallet_choices(wallet)
				var quote := {}
				for entry in preview.get("choices", []):
					if entry.get("choice_id") == choice_id:
						quote = entry
				_check(quote == {"choice_id": choice_id, "gold_delta": delta[0],
					"scraps_delta": delta[1], "affordable": true, "wallet": projected},
					"batch option previews its exact signed delta: " + event_id + "/" + str(choice_id))
				var receipt := choice_visit.choose_with_wallet(choice_id, wallet)
				_check(receipt == {"ok": true, "event_id": event_id, "choice_id": choice_id,
					"wallet": projected} and wallet == wallet_before
					and choice_visit.is_claimed() and not choice_visit.is_valid(),
					"batch option settles exactly once: " + event_id + "/" + str(choice_id))
				receipt.wallet.gold = 999
				_check(choice_visit.choose_with_wallet(choice_id, projected) == {"ok": false,
					"event_id": "", "choice_id": "", "wallet": projected},
					"batch option cannot be claimed twice: " + event_id + "/" + str(choice_id))
	# Stale/forged batch records never authorize entry, even when the required
	# hero is present in the authenticating party.
	for event_id in BATCH_CHOICES:
		var record := _by_id(catalog["events"], event_id)
		_check(not record.is_empty(), "batch forgery fixture exists: " + event_id)
		if record.is_empty():
			continue
		var altered := record.duplicate(true)
		altered.choices[0].outcome.gold = 999
		_reject_catalog({"events": [altered]})
		var renamed := record.duplicate(true)
		renamed["id"] = event_id + "_stale"
		_reject_catalog({"events": [renamed]})
		var swapped_hero := record.duplicate(true)
		swapped_hero["required_hero"] = "tinker"
		if record["required_hero"] != "tinker":
			_reject_catalog({"events": [swapped_hero]})
		var trimmed := record.duplicate(true)
		trimmed["choices"].pop_back()
		_reject_catalog({"events": [trimmed]})
		var forged := record.duplicate(true)
		forged["choices"][0]["outcome"]["scraps"] = 500
		_reject_catalog({"events": [forged]})


func _test_invalid_parties() -> void:
	# A four-distinct-hero roster is no longer invalid: Design v4 Stitched runs
	# pick four of eight (see _test_four_hero_stitched_admission). Only 3- or
	# 4-hero rosters of unique canonical IDs are admitted, so 1, 2, 5 and any
	# duplicate/unknown/blank/non-string member still fail closed.
	for party in [null, {}, "warden", [], ["warden"], ["warden", "seamstress"],
		["warden", "seamstress", "tinker", "lantern_monk", "scarecrow"],
		["warden", "seamstress", "tinker", "lantern_monk", "rag_duelist", "scarecrow"],
		["warden", "warden", "tinker"], ["warden", "warden", "tinker", "lantern_monk"],
		["warden", "unknown", "tinker"], ["warden", "unknown", "tinker", "lantern_monk"],
		["warden", "", "tinker"], ["warden", "seamstress", "tinker", ""],
		["warden", 1, "tinker"], ["warden", "seamstress", "tinker", 1],
		["warden", null, "tinker"], ["warden", "seamstress", "tinker", null],
		["Warden", "seamstress", "tinker"], ["warden", "Seamstress", "tinker", "lantern_monk"]]:
		var service := RunV3HeroEventOffers.new(party)
		var rng := RandomNumberGenerator.new()
		rng.seed = 409
		var state := rng.state
		_check(not service.is_valid() and service.get_offers().is_empty()
			and service.enter("v3_warden_shield_menders") == null
			and service.select_actionable_event(rng, [], {"gold": 30, "scraps": 3}) == {"ok": false, "event": {}}
			and rng.state == state, "invalid party fails closed: " + str(party))
		var rng_prev := RandomNumberGenerator.new()
		rng_prev.seed = 409
		var state_prev := rng_prev.state
		_check(service.select_actionable_event_with_preview(rng_prev, [], {"gold": 30, "scraps": 3}) == {"ok": false, "event": {}, "preview": {}}
			and rng_prev.state == state_prev, "invalid party fails closed with preview: " + str(party))
	# The same four-hero roster the loop above no longer rejects is a valid
	# Design v4 Stitched admission: offers, entry and receipt all work.
	var stitched := RunV3HeroEventOffers.new(STITCHED_PARTY)
	_check(stitched.is_valid() and not stitched.get_offers().is_empty()
		and stitched.enter("v3_warden_shield_menders") != null,
		"four-distinct-hero Stitched party is a valid admission, not an invalid one")


## AC1/AC2/AC3: a Design v4 Stitched roster of four distinct canonical heroes
## must reach the same authentic hero-gated Event offers as a legacy three-hero
## roster, with unchanged one-visit wallet settlement and seeded selection.
func _test_four_hero_stitched_admission() -> void:
	var reversed := catalog.duplicate(true)
	reversed["events"].reverse()
	var service := RunV3HeroEventOffers.new(STITCHED_PARTY)
	var reordered := RunV3HeroEventOffers.new(STITCHED_PARTY, reversed)
	var rank_order := RunV3HeroEventOffers.new(["lantern_monk", "tinker", "warden", "seamstress"])
	_check(service.is_valid() and reordered.is_valid() and rank_order.is_valid(),
		"four distinct canonical hero IDs are admitted regardless of catalog or rank order")
	if not service.is_valid() or not reordered.is_valid() or not rank_order.is_valid():
		return

	# AC1: exactly the shipped records whose required_hero is on this roster.
	# Derived per required_hero from the authored catalog, never a catalog total
	# or a full ordered ID list.
	var expected_ids: Array[String] = []
	for record in catalog["events"]:
		if STITCHED_PARTY.has(record["required_hero"]):
			expected_ids.append(record["id"])
	expected_ids.sort()
	var offered_ids: Array[String] = []
	for offer in service.get_offers():
		offered_ids.append(offer["id"])
		_check(STITCHED_PARTY.has(offer.get("required_hero")),
			"four-hero offer belongs to the roster by required_hero: " + str(offer.get("id")))
	offered_ids.sort()
	_check(offered_ids == expected_ids,
		"four-hero offers are exactly the records whose required_hero is on the roster")
	var rank_ids: Array[String] = []
	for offer in rank_order.get_offers():
		rank_ids.append(offer["id"])
	rank_ids.sort()
	_check(rank_ids == expected_ids, "roster rank order does not change the four-hero offer set")

	# Concrete anchors: present Warden and Lantern Monk records, absent Scarecrow.
	for anchor in [["v3_warden_shield_menders", true],
		["v3_lantern_monk_moth_vigil", true], ["v3_scarecrow_crow_roost", false]]:
		var anchor_id: String = anchor[0]
		var admitted: bool = anchor[1]
		var authored := _by_id(catalog["events"], anchor_id)
		_check(not authored.is_empty(), "four-hero anchor exists in the shipped catalog: " + anchor_id)
		var offer := _by_id(service.get_offers(), anchor_id)
		_check((not offer.is_empty()) == admitted, "four-hero offer presence by required_hero: " + anchor_id)
		_check(_by_id(reordered.get_offers(), anchor_id) == offer,
			"reversed catalog leaves the four-hero offer unchanged: " + anchor_id)
		var anchor_visit := service.enter(anchor_id)
		if not admitted:
			_check(anchor_visit == null, "absent Scarecrow Event denies entry on a four-hero roster: " + anchor_id)
			continue
		_check(anchor_visit is RunEventChoice and anchor_visit.is_valid() and not anchor_visit.is_claimed(),
			"four-hero roster opens a real unclaimed visit: " + anchor_id)
		if anchor_visit == null:
			continue
		_check(offer == authored and anchor_visit.get_event() == authored,
			"four-hero detached offer and visit snapshot are the authentic authored record: " + anchor_id)

	# AC2: v3_lantern_monk_moth_vigil buy_wax settles {30,3} -> {18,5} once.
	var vigil_id := "v3_lantern_monk_moth_vigil"
	var wallet := {"gold": 30, "scraps": 3}
	var preview_visit := service.enter(vigil_id)
	var preview_visit_two := service.enter(vigil_id)
	_check(preview_visit != null and preview_visit_two != null and preview_visit != preview_visit_two,
		"each four-hero enter(id) opens a distinct fresh RunEventChoice")
	if preview_visit == null or preview_visit_two == null:
		return
	_check(preview_visit.is_valid() and not preview_visit.is_claimed()
		and preview_visit_two.is_valid() and not preview_visit_two.is_claimed(),
		"four-hero visits start valid and unclaimed")
	var preview := preview_visit.preview_wallet_choices(wallet)
	_check(preview.get("ok") == true and preview.get("event_id") == vigil_id,
		"four-hero moth vigil previews authentically")
	var buy_quote := _find_choice_quote(preview.get("choices", []), "buy_wax")
	var leave_quote := _find_choice_quote(preview.get("choices", []), "leave")
	_check(buy_quote == {"choice_id": "buy_wax", "gold_delta": -12, "scraps_delta": 2,
		"affordable": true, "wallet": {"gold": 18, "scraps": 5}},
		"four-hero buy_wax previews -12 gold/+2 scraps from {30,3}")
	_check(leave_quote == {"choice_id": "leave", "gold_delta": 0, "scraps_delta": 0,
		"affordable": true, "wallet": {"gold": 30, "scraps": 3}},
		"four-hero Leave previews a zero wallet delta")
	var receipt := preview_visit.choose_with_wallet("buy_wax", wallet)
	_check(receipt == {"ok": true, "event_id": vigil_id, "choice_id": "buy_wax",
		"wallet": {"gold": 18, "scraps": 5}} and wallet == {"gold": 30, "scraps": 3},
		"four-hero buy_wax claim receipt equals the preview and detaches the caller wallet")
	_check(receipt.get("wallet") == buy_quote.get("wallet"),
		"four-hero preview and claim agree on the exact settled wallet")
	_check(preview_visit.is_claimed() and not preview_visit.is_valid(),
		"four-hero accepted claim latches the visit")
	_check(preview_visit.choose_with_wallet("buy_wax", {"gold": 18, "scraps": 5}) == {
		"ok": false, "event_id": "", "choice_id": "", "wallet": {"gold": 18, "scraps": 5}},
		"four-hero accepted choice cannot be replayed")
	_check(not preview_visit.choose_with_wallet("leave", {"gold": 18, "scraps": 5})["ok"],
		"four-hero alternate choice is blocked after the claim")
	var leave_receipt := preview_visit_two.choose_with_wallet("leave", wallet)
	_check(leave_receipt == {"ok": true, "event_id": vigil_id, "choice_id": "leave",
		"wallet": {"gold": 30, "scraps": 3}} and preview_visit_two.is_claimed(),
		"four-hero Leave settles with zero wallet delta on its own visit")

	# Unaffordable hero choices refuse without latching, then Leave recovers.
	var poor_wallet := {"gold": 0, "scraps": 0}
	var poor_visit := service.enter(vigil_id)
	_check(poor_visit != null and poor_visit.is_valid(), "four-hero poor visit opens")
	if poor_visit != null:
		for bad_choice in ["buy_wax", "stale_choice", "", null]:
			_check(poor_visit.choose_with_wallet(bad_choice, poor_wallet) == {
				"ok": false, "event_id": "", "choice_id": "", "wallet": poor_wallet},
				"four-hero unaffordable/stale choice refuses unchanged: " + str(bad_choice))
			_check(poor_visit.is_valid() and not poor_visit.is_claimed(),
				"four-hero refusal does not consume the claim")
		_check(not poor_visit.choose_with_wallet("leave", {"gold": -1, "scraps": 0})["ok"]
			and not poor_visit.is_claimed(), "four-hero invalid wallet does not claim")
		_check(poor_visit.choose_with_wallet("leave", poor_wallet)["ok"] and poor_visit.is_claimed(),
			"four-hero refusal recovers with the authored Leave")

	# AC3: seeded actionable selection over the four-hero roster.
	for wallet_case in [{"gold": 0, "scraps": 0}, {"gold": 30, "scraps": 3}]:
		var candidates := _expected_actionable_ids(STITCHED_PARTY, wallet_case)
		_check(not candidates.is_empty(),
			"four-hero roster has actionable candidates at " + str(wallet_case))
		_check(candidates.has("v3_warden_shield_menders") and candidates.has("v3_lantern_monk_moth_vigil")
			and not candidates.has("v3_scarecrow_crow_roost"),
			"four-hero candidates follow required_hero presence at " + str(wallet_case))
		if wallet_case == {"gold": 0, "scraps": 0}:
			_check(not candidates.has("v3_seamstress_thread_cart"),
				"four-hero {0,0} pool omits the Leave-only seamstress thread cart")
		if wallet_case == {"gold": 30, "scraps": 3}:
			_check(candidates.has("v3_seamstress_thread_cart"),
				"four-hero funded pool includes the now-affordable seamstress thread cart")
		if candidates.is_empty():
			continue
		for seed_val in [5101, 5202, 5303, 5404]:
			var rng_preview := RandomNumberGenerator.new()
			rng_preview.seed = seed_val
			var rng_rev := RandomNumberGenerator.new()
			rng_rev.seed = seed_val
			var rng_ref := RandomNumberGenerator.new()
			rng_ref.seed = seed_val
			var expected_id: String = candidates[rng_ref.randi_range(0, candidates.size() - 1)]
			var expected_record := _by_id(catalog["events"], expected_id)
			var expected_preview := RunEventChoice.new(expected_record).preview_wallet_choices(wallet_case)
			var res_preview := service.select_actionable_event_with_preview(rng_preview, null, wallet_case)
			var res_rev := reordered.select_actionable_event_with_preview(rng_rev, [], wallet_case)
			_check(res_preview == {"ok": true, "event": expected_record, "preview": expected_preview},
				"four-hero with-preview selection matches the sorted candidate draw: "
				+ str(wallet_case) + "/" + str(seed_val))
			_check(res_rev == res_preview,
				"four-hero reversed catalog yields the identical offer and preview: " + str(seed_val))
			_check(rng_preview.state == rng_ref.state and rng_rev.state == rng_ref.state,
				"four-hero with-preview selection consumes exactly one randi_range draw: " + str(seed_val))
			_check(STITCHED_PARTY.has(res_preview["event"].get("required_hero"))
				and _has_affordable_non_leave(res_preview["event"], wallet_case),
				"four-hero selection offers a roster record with an affordable non-Leave choice")
			var rng_bare := RandomNumberGenerator.new()
			rng_bare.seed = seed_val
			var rng_bare_ref := RandomNumberGenerator.new()
			rng_bare_ref.seed = seed_val
			rng_bare_ref.randi_range(0, candidates.size() - 1)
			var res_bare := service.select_actionable_event(rng_bare, null, wallet_case)
			_check(res_bare == {"ok": true, "event": expected_record} and rng_bare.state == rng_bare_ref.state,
				"four-hero bare selection agrees with the with-preview API on one draw: " + str(seed_val))

	# Exclusions filter before sorting and sampling, with one draw on success.
	var exclusions := ["v3_warden_shield_menders", "unknown_stitched_event", "v3_scarecrow_crow_roost"]
	var exclusions_snapshot := exclusions.duplicate()
	var excluded_candidates := _expected_actionable_ids(STITCHED_PARTY, {"gold": 30, "scraps": 3}, exclusions)
	_check(not excluded_candidates.has("v3_warden_shield_menders") and not excluded_candidates.is_empty(),
		"four-hero exclusion removes the party Event but keeps other candidates")
	for seed_val in [5501, 5502, 5503, 5504, 5505, 5506]:
		if excluded_candidates.is_empty():
			break
		var rng_ex := RandomNumberGenerator.new()
		rng_ex.seed = seed_val
		var rng_ex_ref := RandomNumberGenerator.new()
		rng_ex_ref.seed = seed_val
		var expected_ex_id: String = excluded_candidates[
			rng_ex_ref.randi_range(0, excluded_candidates.size() - 1)]
		var res_ex := service.select_actionable_event(rng_ex, exclusions, {"gold": 30, "scraps": 3})
		_check(res_ex == {"ok": true, "event": _by_id(catalog["events"], expected_ex_id)}
			and rng_ex.state == rng_ex_ref.state,
			"four-hero excluded selection never offers the excluded ID: " + str(seed_val))
		_check(res_ex["event"].get("id") != "v3_warden_shield_menders",
			"four-hero excluded ID is absent from the selected record")
	_check(exclusions == exclusions_snapshot, "four-hero selection never mutates caller exclusions")

	# Exhaustion and malformed wallets consume zero caller draws.
	var all_roster_ids: Array[String] = []
	for record in catalog["events"]:
		if STITCHED_PARTY.has(record["required_hero"]):
			all_roster_ids.append(record["id"])
	var rng_zero := RandomNumberGenerator.new()
	rng_zero.seed = 5601
	var state_zero := rng_zero.state
	_check(service.select_actionable_event(rng_zero, all_roster_ids, {"gold": 500, "scraps": 50})
		== {"ok": false, "event": {}} and rng_zero.state == state_zero,
		"fully excluded four-hero pool rejects with zero caller draws")
	_check(service.select_actionable_event_with_preview(rng_zero, [], {"gold": 30})
		== {"ok": false, "event": {}, "preview": {}} and rng_zero.state == state_zero,
		"malformed four-hero wallet rejects with zero caller draws")
	_check(service.select_actionable_event_with_preview(rng_zero, [], {"gold": 30, "scraps": 3, "extra": 0})
		== {"ok": false, "event": {}, "preview": {}} and rng_zero.state == state_zero,
		"three-key four-hero wallet rejects with zero caller draws")

	# AC4: a tampered catalog is still wholly rejected for a four-hero roster.
	var forged := _by_id(catalog["events"], "v3_warden_shield_menders").duplicate(true)
	forged["choices"][0]["outcome"]["gold"] = 999
	var forged_service := RunV3HeroEventOffers.new(STITCHED_PARTY, {"events": [forged]})
	var rng_forged := RandomNumberGenerator.new()
	rng_forged.seed = 5701
	var state_forged := rng_forged.state
	_check(not forged_service.is_valid() and forged_service.get_offers().is_empty()
		and forged_service.enter("v3_warden_shield_menders") == null
		and forged_service.select_actionable_event(rng_forged, [], {"gold": 30, "scraps": 3})
			== {"ok": false, "event": {}} and rng_forged.state == state_forged,
		"four-hero roster rejects a tampered catalog fail-closed with zero caller draws")


func _reject_catalog(source: Variant) -> void:
	var before: Variant = source.duplicate(true) if source is Dictionary or source is Array else source
	var service := RunV3HeroEventOffers.new(PARTY_A, source)
	var rng := RandomNumberGenerator.new()
	rng.seed = 419
	var state := rng.state
	_check(not service.is_valid() and service.get_offers().is_empty()
		and service.enter("v3_warden_shield_menders") == null
		and service.select_actionable_event(rng, [], {"gold": 30, "scraps": 3}) == {"ok": false, "event": {}}
		and rng.state == state, "malformed catalog wholly denied: " + str(source))
	var rng_prev := RandomNumberGenerator.new()
	rng_prev.seed = 419
	var state_prev := rng_prev.state
	_check(service.select_actionable_event_with_preview(rng_prev, [], {"gold": 30, "scraps": 3}) == {"ok": false, "event": {}, "preview": {}}
		and rng_prev.state == state_prev, "malformed catalog wholly denied with preview: " + str(source))
	_check(source == before, "rejected catalog unchanged")


func _test_invalid_catalogs() -> void:
	for source in [false, 4, [], {}, {"events": null}, {"events": {}}, {"events": []}, {"events": [null]}]:
		_reject_catalog(source)
	var base := _by_id(catalog["events"], "v3_warden_shield_menders")
	_check(not base.is_empty(), "malformed fixtures require real Warden record")
	if base.is_empty():
		return
	_reject_catalog({"events": [base, base.duplicate(true)]})
	# Plausible metadata cannot forge a new authored ID, a different known hero,
	# altered wallet amounts, or a renamed choice with matching hero_choice_ids.
	for kind in ["forged_id", "known_hero", "forged_amount", "forged_choice"]:
		var forged := base.duplicate(true)
		match kind:
			"forged_id": forged["id"] = "forged_event"
			"known_hero": forged["required_hero"] = "tinker"
			"forged_amount": forged["choices"][0]["outcome"]["gold"] = 999
			"forged_choice":
				forged["choices"][0]["id"] = "forged_choice"
				forged["hero_choice_ids"][0] = "forged_choice"
		_reject_catalog({"events": [forged]})
	for field in ["id", "title", "description", "choices", "required_hero", "hero_choice_ids"]:
		var missing := base.duplicate(true)
		missing.erase(field)
		_reject_catalog({"events": [missing]})
	for field in ["id", "title", "description", "required_hero"]:
		for value in ["   ", 5, null]:
			var broken := base.duplicate(true)
			broken[field] = value
			_reject_catalog({"events": [broken]})
	for ids in [null, "hold_the_gate", [], ["hold_the_gate"],
		["hold_the_gate", "hold_the_gate"], ["hold_the_gate", "leave"],
		["hold_the_gate", "stale"], ["hold_the_gate", 2]]:
		var broken := base.duplicate(true)
		broken["hero_choice_ids"] = ids
		_reject_catalog({"events": [broken]})
	var unknown_hero := base.duplicate(true)
	unknown_hero["required_hero"] = "forged_hero"
	_reject_catalog({"events": [unknown_hero]})
	for kind in ["duplicate_choice", "missing_leave", "bad_outcome", "bad_choice"]:
		var broken := base.duplicate(true)
		match kind:
			"duplicate_choice": broken["choices"][1]["id"] = "hold_the_gate"
			"missing_leave": broken["choices"].pop_back()
			"bad_outcome": broken["choices"][0]["outcome"] = {"gold": "999", "scraps": 0}
			"bad_choice": broken["choices"][0] = false
		_reject_catalog({"events": [broken]})
	# Bad metadata must reject even when the party would not see that record.
	var absent := _by_id(catalog["events"], "v3_lantern_monk_moth_vigil").duplicate(true)
	_check(not absent.is_empty(), "ineligible malformed fixture exists")
	absent["hero_choice_ids"] = ["forged"]
	_reject_catalog({"events": [base, absent]})


func _test_isolation() -> void:
	var party := PARTY_A.duplicate()
	var source := catalog.duplicate(true)
	var service := RunV3HeroEventOffers.new(party, source)
	var original := service.get_offers()
	_check(service.is_valid() and not original.is_empty(), "isolation uses valid nonempty adapter")
	party[0] = "lantern_monk"
	source["events"].clear()
	var offers := service.get_offers()
	var forged := _by_id(offers, "v3_warden_shield_menders")
	forged["required_hero"] = "lantern_monk"
	forged["choices"][0]["outcome"]["gold"] = 999
	_check(service.enter(forged) == null, "forged record never authorizes entry")
	_check(service.get_offers() == original, "caller party, catalog and nested offers detached")
	var visit := service.enter("v3_warden_shield_menders")
	_check(visit != null, "isolation visit admitted")
	if visit == null:
		return
	var event := visit.get_event()
	event["choices"].clear()
	_check(visit.choose_with_wallet("hold_the_gate", {"gold": 0, "scraps": 0})["wallet"] == {"gold": 0, "scraps": 2}, "entry uses authentic snapshot despite forged offers")
	_check(service.get_offers() == original, "entry/claim never mutate adapter catalog")


func _has_affordable_non_leave(record: Dictionary, wallet: Dictionary) -> bool:
	var preview := RunEventChoice.new(record).preview_wallet_choices(wallet)
	if not preview.get("ok", false):
		return false
	for choice in preview.get("choices", []):
		if choice is Dictionary and choice.get("choice_id") != "leave" and choice.get("affordable") == true:
			return true
	return false


func _expected_actionable_ids(party: Array, wallet: Dictionary, excluded: Array = [], source_events: Array = []) -> Array[String]:
	var events_list: Array = catalog["events"] if source_events.is_empty() else source_events
	var excluded_map := {}
	for item in excluded:
		excluded_map[item] = true
	var ids: Array[String] = []
	for record in events_list:
		var event_id: String = record["id"]
		if not party.has(record["required_hero"]) or excluded_map.has(event_id):
			continue
		if _has_affordable_non_leave(record, wallet):
			ids.append(event_id)
	ids.sort()
	return ids


func _test_actionable_named_examples() -> void:
	var ferry := _by_id(catalog["events"], "v3_warden_copper_chain_ferry")
	var oracle := _by_id(catalog["events"], "v3_seamstress_needle_oracle")
	var monk_ferry := _by_id(catalog["events"], "v3_lantern_monk_mothlight_ferry")
	_check(not ferry.is_empty() and not oracle.is_empty() and not monk_ferry.is_empty(),
		"named example records exist in shipped catalog")
	if ferry.is_empty() or oracle.is_empty() or monk_ferry.is_empty():
		return

	# Verify exact preview affordability on the two named shipped records at {0, 0} and {18, 1}.
	var zero_wallet := {"gold": 0, "scraps": 0}
	var funded_wallet := {"gold": 18, "scraps": 1}
	var ferry_zero_preview := RunEventChoice.new(ferry).preview_wallet_choices(zero_wallet)
	var oracle_zero_preview := RunEventChoice.new(oracle).preview_wallet_choices(zero_wallet)
	var oracle_funded_preview := RunEventChoice.new(oracle).preview_wallet_choices(funded_wallet)
	_check(ferry_zero_preview == {
		"ok": true,
		"event_id": "v3_warden_copper_chain_ferry",
		"choices": [
			{"choice_id": "brace_ferry_chain", "gold_delta": 20, "scraps_delta": 0, "affordable": true, "wallet": {"gold": 20, "scraps": 0}},
			{"choice_id": "buy_brass_buckles", "gold_delta": -14, "scraps_delta": 2, "affordable": false, "wallet": {"gold": 0, "scraps": 0}},
			{"choice_id": "leave", "gold_delta": 0, "scraps_delta": 0, "affordable": true, "wallet": {"gold": 0, "scraps": 0}},
		],
	}, "v3_warden_copper_chain_ferry at {0,0} has affordable +20/0 non-Leave choice")
	_check(oracle_zero_preview == {
		"ok": true,
		"event_id": "v3_seamstress_needle_oracle",
		"choices": [
			{"choice_id": "untangle_oracle_thread", "gold_delta": 24, "scraps_delta": -1, "affordable": false, "wallet": {"gold": 0, "scraps": 0}},
			{"choice_id": "buy_oracle_silk", "gold_delta": -18, "scraps_delta": 3, "affordable": false, "wallet": {"gold": 0, "scraps": 0}},
			{"choice_id": "leave", "gold_delta": 0, "scraps_delta": 0, "affordable": true, "wallet": {"gold": 0, "scraps": 0}},
		],
	}, "v3_seamstress_needle_oracle at {0,0} is Leave-only")
	_check(oracle_funded_preview == {
		"ok": true,
		"event_id": "v3_seamstress_needle_oracle",
		"choices": [
			{"choice_id": "untangle_oracle_thread", "gold_delta": 24, "scraps_delta": -1, "affordable": true, "wallet": {"gold": 42, "scraps": 0}},
			{"choice_id": "buy_oracle_silk", "gold_delta": -18, "scraps_delta": 3, "affordable": true, "wallet": {"gold": 0, "scraps": 4}},
			{"choice_id": "leave", "gold_delta": 0, "scraps_delta": 0, "affordable": true, "wallet": {"gold": 18, "scraps": 1}},
		],
	}, "v3_seamstress_needle_oracle at {18,1} has both hero choices affordable")

	var subset_forward := RunV3HeroEventOffers.new(PARTY_A, {"events": [ferry, oracle, monk_ferry]})
	var subset_reversed := RunV3HeroEventOffers.new(PARTY_A, {"events": [monk_ferry, oracle, ferry]})
	var full_service := RunV3HeroEventOffers.new(PARTY_A)
	_check(subset_forward.is_valid() and subset_reversed.is_valid() and full_service.is_valid(),
		"subset and full services valid for PARTY_A")
	var exclude_all_but_pair: Array[String] = []
	for offer in full_service.get_offers():
		var id: String = offer["id"]
		if id != "v3_warden_copper_chain_ferry" and id != "v3_seamstress_needle_oracle":
			exclude_all_but_pair.append(id)

	# 1. With zero wallet, only v3_warden_copper_chain_ferry is actionable (exact 1 RNG draw).
	for service_case in [
		[subset_forward, null, "subset_forward"],
		[subset_reversed, [], "subset_reversed"],
		[full_service, exclude_all_but_pair, "full_service_isolated_pair"],
	]:
		var svc: RunV3HeroEventOffers = service_case[0]
		var excl: Variant = service_case[1]
		var label: String = service_case[2]
		var rng := RandomNumberGenerator.new()
		rng.seed = 901
		var oracle_rng := RandomNumberGenerator.new()
		oracle_rng.seed = 901
		var expected_draw := oracle_rng.randi_range(0, 0)
		var wallet_arg := {"gold": 0, "scraps": 0}
		var result := svc.select_actionable_event(rng, excl, wallet_arg)
		_check(expected_draw == 0 and result == {"ok": true, "event": ferry},
			"zero wallet selects only actionable v3_warden_copper_chain_ferry: " + label)
		_check(rng.state == oracle_rng.state,
			"single actionable candidate still consumes exact one randi_range(0,0) draw: " + label)
		_check(wallet_arg == {"gold": 0, "scraps": 0},
			"zero wallet argument untouched by selection: " + label)

	# 2. Excluding v3_warden_copper_chain_ferry at {0, 0} or {17, 0} leaves only Leave-only oracle -> rejects with 0 draws.
	var exclude_all_but_oracle := exclude_all_but_pair.duplicate()
	exclude_all_but_oracle.append("v3_warden_copper_chain_ferry")
	for poor_wallet in [{"gold": 0, "scraps": 0}, {"gold": 17, "scraps": 0}]:
		var rng_sub := RandomNumberGenerator.new()
		rng_sub.seed = 902
		var state_sub := rng_sub.state
		var sub_res := subset_forward.select_actionable_event(rng_sub, ["v3_warden_copper_chain_ferry"], poor_wallet)
		_check(sub_res == {"ok": false, "event": {}} and rng_sub.state == state_sub,
			"Leave-only v3_seamstress_needle_oracle rejected with zero RNG draws in subset: " + str(poor_wallet))
		var rng_full := RandomNumberGenerator.new()
		rng_full.seed = 903
		var state_full := rng_full.state
		var full_res := full_service.select_actionable_event(rng_full, exclude_all_but_oracle, poor_wallet)
		_check(full_res == {"ok": false, "event": {}} and rng_full.state == state_full,
			"Leave-only v3_seamstress_needle_oracle rejected with zero RNG draws in full catalog: " + str(poor_wallet))

	# Direct entry into v3_seamstress_needle_oracle still preserves Leave at {0, 0}.
	var oracle_poor_visit := full_service.enter("v3_seamstress_needle_oracle")
	_check(oracle_poor_visit != null and oracle_poor_visit.is_valid() and not oracle_poor_visit.is_claimed(),
		"v3_seamstress_needle_oracle still opens via enter() when poor")
	if oracle_poor_visit != null:
		_check(not oracle_poor_visit.choose_with_wallet("untangle_oracle_thread", zero_wallet)["ok"]
			and not oracle_poor_visit.choose_with_wallet("buy_oracle_silk", zero_wallet)["ok"]
			and not oracle_poor_visit.is_claimed(),
			"unaffordable hero choices on v3_seamstress_needle_oracle refuse without latching")
		var leave_receipt := oracle_poor_visit.choose_with_wallet("leave", zero_wallet)
		_check(leave_receipt == {"ok": true, "event_id": "v3_seamstress_needle_oracle", "choice_id": "leave", "wallet": {"gold": 0, "scraps": 0}}
			and oracle_poor_visit.is_claimed() and not oracle_poor_visit.is_valid(),
			"Leave remains available and settles cleanly on v3_seamstress_needle_oracle")

	# 3. With {0, 1}, {18, 0} or {18, 1}, v3_seamstress_needle_oracle becomes actionable.
	for threshold_wallet in [{"gold": 0, "scraps": 1}, {"gold": 18, "scraps": 0}, {"gold": 18, "scraps": 1}]:
		var rng_ok := RandomNumberGenerator.new()
		rng_ok.seed = 904
		var ref_rng := RandomNumberGenerator.new()
		ref_rng.seed = 904
		ref_rng.randi_range(0, 0)
		var res_ok := full_service.select_actionable_event(rng_ok, exclude_all_but_oracle, threshold_wallet)
		_check(res_ok == {"ok": true, "event": oracle} and rng_ok.state == ref_rng.state,
			"v3_seamstress_needle_oracle selected with 1 draw once affordable: " + str(threshold_wallet))

	# 4. With {18, 1} and neither ferry nor oracle excluded, both are eligible in lexical order:
	# ["v3_seamstress_needle_oracle", "v3_warden_copper_chain_ferry"].
	var sorted_pair := ["v3_seamstress_needle_oracle", "v3_warden_copper_chain_ferry"]
	var seen_selected := {}
	for seed_val in range(1001, 1015):
		var rng_f := RandomNumberGenerator.new()
		rng_f.seed = seed_val
		var rng_r := RandomNumberGenerator.new()
		rng_r.seed = seed_val
		var rng_full := RandomNumberGenerator.new()
		rng_full.seed = seed_val
		var rng_ref := RandomNumberGenerator.new()
		rng_ref.seed = seed_val
		var pick_idx := rng_ref.randi_range(0, 1)
		var expected_id: String = sorted_pair[pick_idx]
		var expected_rec := _by_id(catalog["events"], expected_id)
		var res_f := subset_forward.select_actionable_event(rng_f, null, funded_wallet)
		var res_r := subset_reversed.select_actionable_event(rng_r, [], funded_wallet)
		var res_full := full_service.select_actionable_event(rng_full, exclude_all_but_pair, funded_wallet)
		_check(res_f == {"ok": true, "event": expected_rec}
			and res_r == res_f and res_full == res_f,
			"funded pair samples uniformly from lexically sorted IDs independent of catalog order: seed " + str(seed_val))
		_check(rng_f.state == rng_ref.state and rng_r.state == rng_ref.state and rng_full.state == rng_ref.state,
			"funded pair consumes exact one randi_range(0,1) draw: seed " + str(seed_val))
		seen_selected[expected_id] = true
	_check(seen_selected.has("v3_seamstress_needle_oracle") and seen_selected.has("v3_warden_copper_chain_ferry"),
		"seeded sampling across {18,1} pair reaches both oracle and ferry")

	# 5. Selected records open fresh RunEventChoice visits via enter(id) and settle once with exact signed deltas.
	var ferry_visit := full_service.enter("v3_warden_copper_chain_ferry")
	_check(ferry_visit != null and ferry_visit.is_valid() and not ferry_visit.is_claimed(),
		"selected ferry opens fresh unclaimed RunEventChoice via enter(id)")
	if ferry_visit != null:
		var w0 := {"gold": 0, "scraps": 0}
		var r_brace := ferry_visit.choose_with_wallet("brace_ferry_chain", w0)
		_check(r_brace == {"ok": true, "event_id": "v3_warden_copper_chain_ferry", "choice_id": "brace_ferry_chain", "wallet": {"gold": 20, "scraps": 0}}
			and w0 == {"gold": 0, "scraps": 0} and ferry_visit.is_claimed() and not ferry_visit.is_valid(),
			"ferry brace_ferry_chain settles +20 gold/0 scraps once without mutating caller wallet")
		_check(ferry_visit.choose_with_wallet("leave", {"gold": 20, "scraps": 0}) == {
			"ok": false, "event_id": "", "choice_id": "", "wallet": {"gold": 20, "scraps": 0}},
			"second claim on ferry visit fails closed")
	var oracle_visit_1 := full_service.enter("v3_seamstress_needle_oracle")
	var oracle_visit_2 := full_service.enter("v3_seamstress_needle_oracle")
	_check(oracle_visit_1 != null and oracle_visit_2 != null and oracle_visit_1 != oracle_visit_2,
		"each enter(id) creates a distinct RunEventChoice instance")
	if oracle_visit_1 != null and oracle_visit_2 != null:
		var w_fund := {"gold": 18, "scraps": 1}
		var r_untangle := oracle_visit_1.choose_with_wallet("untangle_oracle_thread", w_fund)
		_check(r_untangle == {"ok": true, "event_id": "v3_seamstress_needle_oracle", "choice_id": "untangle_oracle_thread", "wallet": {"gold": 42, "scraps": 0}}
			and w_fund == {"gold": 18, "scraps": 1} and oracle_visit_1.is_claimed() and not oracle_visit_2.is_claimed(),
			"oracle untangle_oracle_thread settles +24 gold/-1 scrap on first visit only")
		_check( not oracle_visit_1.choose_with_wallet("buy_oracle_silk", w_fund)["ok"],
			"second claim on first oracle visit fails")
		var r_silk := oracle_visit_2.choose_with_wallet("buy_oracle_silk", w_fund)
		_check(r_silk == {"ok": true, "event_id": "v3_seamstress_needle_oracle", "choice_id": "buy_oracle_silk", "wallet": {"gold": 0, "scraps": 4}}
			and w_fund == {"gold": 18, "scraps": 1} and oracle_visit_2.is_claimed(),
			"second fresh oracle visit settles -18 gold/+3 scraps independently")

	# 6. A party lacking Warden and Seamstress (PARTY_B) never admits or selects ferry or oracle even with funded wallet.
	var party_b_subset := RunV3HeroEventOffers.new(PARTY_B, {"events": [ferry, oracle]})
	_check(party_b_subset.is_valid() and party_b_subset.get_offers().is_empty(),
		"PARTY_B subset with only Warden/Seamstress records has zero eligible offers")
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 905
	var state_b := rng_b.state
	_check(party_b_subset.select_actionable_event(rng_b, null, funded_wallet) == {"ok": false, "event": {}}
		and rng_b.state == state_b,
		"absent required heroes reject selection with zero RNG draws even when wallet is funded")


func _test_actionable_party_and_sorted_sampling() -> void:
	var reversed := catalog.duplicate(true)
	reversed["events"].reverse()
	for party in [PARTY_A, PARTY_B]:
		var service := RunV3HeroEventOffers.new(party)
		var reordered := RunV3HeroEventOffers.new(party, reversed)
		_check(service.is_valid() and reordered.is_valid(),
			"full and reversed services valid for party: " + str(party))
		for wallet in [{"gold": 0, "scraps": 0}, {"gold": 18, "scraps": 1}, {"gold": 30, "scraps": 3}]:
			var expected_ids := _expected_actionable_ids(party, wallet)
			_check(not expected_ids.is_empty(),
				"shipped catalog has actionable events for " + str(party) + " at " + str(wallet))
			if party == PARTY_A and wallet == {"gold": 0, "scraps": 0}:
				_check(expected_ids.has("v3_warden_copper_chain_ferry")
					and not expected_ids.has("v3_seamstress_needle_oracle")
					and not expected_ids.has("v3_lantern_monk_mothlight_ferry"),
					"PARTY_A at {0,0} includes ferry, excludes Leave-only oracle and absent-hero records")
			if party == PARTY_A and wallet == {"gold": 18, "scraps": 1}:
				_check(expected_ids.has("v3_warden_copper_chain_ferry")
					and expected_ids.has("v3_seamstress_needle_oracle")
					and not expected_ids.has("v3_lantern_monk_mothlight_ferry"),
					"PARTY_A at {18,1} includes both ferry and oracle and excludes absent-hero records")
			if party == PARTY_B and wallet == {"gold": 0, "scraps": 0}:
				_check(expected_ids.has("v3_lantern_monk_mothlight_ferry")
					and not expected_ids.has("v3_rag_duelist_cape_tribunal")
					and not expected_ids.has("v3_warden_copper_chain_ferry")
					and not expected_ids.has("v3_seamstress_needle_oracle"),
					"PARTY_B at {0,0} includes mothlight_ferry, excludes Leave-only cape_tribunal and PARTY_A records")
			if party == PARTY_B and wallet == {"gold": 18, "scraps": 1}:
				_check(expected_ids.has("v3_lantern_monk_mothlight_ferry")
					and expected_ids.has("v3_rag_duelist_cape_tribunal")
					and not expected_ids.has("v3_warden_copper_chain_ferry")
					and not expected_ids.has("v3_seamstress_needle_oracle"),
					"PARTY_B at {18,1} includes mothlight_ferry and cape_tribunal, excludes PARTY_A records")
			for seed_val in [101, 202, 303, 404, 505, 606, 707, 808]:
				var rng_norm := RandomNumberGenerator.new()
				rng_norm.seed = seed_val
				var rng_rev := RandomNumberGenerator.new()
				rng_rev.seed = seed_val
				var rng_ref := RandomNumberGenerator.new()
				rng_ref.seed = seed_val
				var idx := rng_ref.randi_range(0, expected_ids.size() - 1)
				var chosen_id: String = expected_ids[idx]
				var expected_record := _by_id(catalog["events"], chosen_id)
				var res_norm := service.select_actionable_event(rng_norm, null, wallet)
				var res_rev := reordered.select_actionable_event(rng_rev, [], wallet)
				_check(res_norm == {"ok": true, "event": expected_record} and res_rev == res_norm,
					"sorted selection matches expected authored record across normal and reversed catalog: "
					+ str(party) + "/" + str(wallet) + "/" + str(seed_val))
				_check(party.has(res_norm["event"].get("required_hero"))
					and _has_affordable_non_leave(res_norm["event"], wallet),
					"selected record belongs to party and has an affordable non-Leave choice")
				_check(rng_norm.state == rng_ref.state and rng_rev.state == rng_ref.state,
					"selection consumes exact one randi_range draw: " + str(seed_val))


func _test_actionable_exclusions_and_exhaustion() -> void:
	var service := RunV3HeroEventOffers.new(PARTY_A)
	var zero_wallet := {"gold": 0, "scraps": 0}
	var funded_wallet := {"gold": 18, "scraps": 1}

	# Unknown and absent-hero exclusions are ignored without changing the draw.
	var unknown_exclusions := ["unknown_event_id", "v3_nonexistent_visit", "v3_scarecrow_crow_roost", "v3_lantern_monk_moth_vigil"]
	var unknown_before := unknown_exclusions.duplicate()
	var rng_with_unknown := RandomNumberGenerator.new()
	rng_with_unknown.seed = 1201
	var rng_without_unknown := RandomNumberGenerator.new()
	rng_without_unknown.seed = 1201
	var res_with_unknown := service.select_actionable_event(rng_with_unknown, unknown_exclusions, zero_wallet)
	var res_without_unknown := service.select_actionable_event(rng_without_unknown, null, zero_wallet)
	_check(res_with_unknown["ok"] and res_with_unknown == res_without_unknown
		and rng_with_unknown.state == rng_without_unknown.state
		and unknown_exclusions == unknown_before,
		"unknown well-formed exclusions are ignored and do not alter sampling or RNG state")

	# Walk through all actionable events at {0, 0} by accumulating visited IDs.
	var expected_zero := _expected_actionable_ids(PARTY_A, zero_wallet)
	var all_party_offers := service.get_offers()
	_check(expected_zero.size() > 0 and expected_zero.size() < all_party_offers.size(),
		"PARTY_A has both actionable and Leave-only events at {0,0}")
	var visited: Array[String] = []
	var walk_rng := RandomNumberGenerator.new()
	walk_rng.seed = 1301
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = 1301
	for step in range(expected_zero.size()):
		var remaining := _expected_actionable_ids(PARTY_A, zero_wallet, visited)
		var expected_idx := oracle_rng.randi_range(0, remaining.size() - 1)
		var expected_id: String = remaining[expected_idx]
		var visited_snapshot := visited.duplicate()
		var res := service.select_actionable_event(walk_rng, visited, zero_wallet)
		_check(res == {"ok": true, "event": _by_id(catalog["events"], expected_id)}
			and not visited.has(expected_id)
			and visited == visited_snapshot
			and walk_rng.state == oracle_rng.state,
			"visit walk selects unvisited actionable event with 1 draw at step " + str(step))
		visited.append(expected_id)

	# Now only Leave-only events remain unvisited for PARTY_A at {0, 0}: must reject with 0 draws.
	var state_after_zero_exhausted := walk_rng.state
	var exhausted_zero_res := service.select_actionable_event(walk_rng, visited, zero_wallet)
	_check(exhausted_zero_res == {"ok": false, "event": {}}
		and walk_rng.state == state_after_zero_exhausted,
		"exhausted actionable pool rejects rather than offering remaining Leave-only events (0 RNG draws)")

	# Funding the wallet to {18, 1} unlocks the previously Leave-only events (including v3_seamstress_needle_oracle).
	var remaining_funded := _expected_actionable_ids(PARTY_A, funded_wallet, visited)
	_check(remaining_funded.has("v3_seamstress_needle_oracle"),
		"funding wallet after zero-wallet exhaustion unlocks v3_seamstress_needle_oracle")
	for step in range(remaining_funded.size()):
		var pool_now := _expected_actionable_ids(PARTY_A, funded_wallet, visited)
		var idx_now := oracle_rng.randi_range(0, pool_now.size() - 1)
		var id_now: String = pool_now[idx_now]
		var res_now := service.select_actionable_event(walk_rng, visited, funded_wallet)
		_check(res_now == {"ok": true, "event": _by_id(catalog["events"], id_now)}
			and walk_rng.state == oracle_rng.state,
			"funded continuation selects unlocked actionable event at step " + str(step))
		visited.append(id_now)

	# Even with a huge wallet, once every party-owned event is excluded, selection rejects with 0 draws.
	var all_ids: Array[String] = []
	for offer in all_party_offers:
		all_ids.append(offer["id"])
	var state_fully_exhausted := walk_rng.state
	var fully_exhausted_res := service.select_actionable_event(walk_rng, all_ids, {"gold": 500, "scraps": 50})
	_check(fully_exhausted_res == {"ok": false, "event": {}}
		and walk_rng.state == state_fully_exhausted,
		"fully excluded party pool rejects with zero RNG draws")


func _test_actionable_invalid_inputs_and_isolation() -> void:
	var party := PARTY_A.duplicate()
	var source := catalog.duplicate(true)
	var service := RunV3HeroEventOffers.new(party, source)
	var original_offers := service.get_offers()
	var valid_wallet := {"gold": 18, "scraps": 1}
	var valid_exclusions := ["v3_warden_shield_menders"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 1401
	var state := rng.state

	# Omitted wallet (1-arg and 2-arg calls) fails closed with 0 draws.
	_check(service.select_actionable_event(rng) == {"ok": false, "event": {}} and rng.state == state,
		"omitted wallet and exclusions rejected with 0 draws")
	_check(service.select_actionable_event(rng, []) == {"ok": false, "event": {}} and rng.state == state,
		"omitted wallet with valid exclusions rejected with 0 draws")

	# Malformed RNG inputs fail closed.
	for bad_rng in [null, 0, 257, "rng", {}, [], RefCounted.new(), service]:
		_check(service.select_actionable_event(bad_rng, valid_exclusions, valid_wallet) == {"ok": false, "event": {}},
			"malformed RNG rejected: " + str(bad_rng))
	_check(rng.state == state, "malformed RNG checks leave caller RNG untouched")

	# Malformed wallet inputs fail closed with 0 draws.
	for bad_wallet in [
		null, {}, {"gold": 10}, {"scraps": 1},
		{"gold": 10, "scraps": 1, "extra": 0},
		{"gold": -1, "scraps": 0}, {"gold": 0, "scraps": -1}, {"gold": -5, "scraps": -2},
		{"gold": 10.0, "scraps": 0}, {"gold": 0, "scraps": 1.0}, {"gold": 18.5, "scraps": 1},
		{"gold": "18", "scraps": 1}, {"gold": 18, "scraps": "1"},
		{"gold": true, "scraps": 1}, {"gold": 18, "scraps": false},
		{"gold": null, "scraps": 1}, {"gold": 18, "scraps": null},
		[], ["gold", "scraps"], "wallet", 18, false,
	]:
		var before_bad: Variant = bad_wallet.duplicate(true) if bad_wallet is Dictionary or bad_wallet is Array else bad_wallet
		var res := service.select_actionable_event(rng, valid_exclusions, bad_wallet)
		_check(res == {"ok": false, "event": {}} and rng.state == state and bad_wallet == before_bad,
			"malformed wallet rejected with 0 draws: " + str(bad_wallet))

	# Malformed excluded_ids inputs fail closed with 0 draws.
	for bad_exclusions in [
		"", "v3_warden_copper_chain_ferry", {}, {"id": "v3_warden_copper_chain_ferry"}, 1, false,
		[""], ["   "], ["\t\n"], [null], [123], [true], [{}], [[]],
		["v3_warden_copper_chain_ferry", ""],
		["v3_warden_copper_chain_ferry", "   "],
		["v3_warden_copper_chain_ferry", null],
		["v3_warden_copper_chain_ferry", 9],
		["v3_warden_copper_chain_ferry", {"id": "v3_seamstress_needle_oracle"}],
	]:
		var before_excl: Variant = bad_exclusions.duplicate(true) if bad_exclusions is Dictionary or bad_exclusions is Array else bad_exclusions
		var res := service.select_actionable_event(rng, bad_exclusions, valid_wallet)
		_check(res == {"ok": false, "event": {}} and rng.state == state and bad_exclusions == before_excl,
			"malformed excluded_ids rejected with 0 draws: " + str(bad_exclusions))

	# Detached copy and non-mutation proof on successful selection.
	var sel_rng := RandomNumberGenerator.new()
	sel_rng.seed = 1409
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = 1409
	var caller_wallet := {"gold": 18, "scraps": 1}
	var caller_exclusions := ["v3_warden_shield_menders", "unknown_ignored_id"]
	var selected := service.select_actionable_event(sel_rng, caller_exclusions, caller_wallet)
	_check(selected["ok"] == true and selected["event"] is Dictionary and not selected["event"].is_empty(),
		"isolation selection succeeds")
	var selected_id: String = selected["event"]["id"]
	var canonical_selected := _by_id(catalog["events"], selected_id)
	_check(selected["event"] == canonical_selected,
		"selected event matches canonical authored record")
	_check(caller_wallet == {"gold": 18, "scraps": 1}
		and caller_exclusions == ["v3_warden_shield_menders", "unknown_ignored_id"],
		"selection never mutates caller wallet or exclusions")

	# Mutate the returned selection dictionary heavily.
	selected["ok"] = false
	selected["event"]["id"] = "forged_selected_id"
	selected["event"]["title"] = "Forged Title"
	selected["event"]["required_hero"] = "scarecrow"
	selected["event"]["choices"][0]["outcome"]["gold"] = 99999
	selected["event"]["choices"].clear()

	_check(service.enter(selected["event"]) == null and service.enter("forged_selected_id") == null,
		"mutated selected dictionary or forged ID cannot authorize enter()")
	_check(service.get_offers() == original_offers,
		"mutating selected record never mutates service offers")
	var reselected := service.select_actionable_event(replay_rng, ["v3_warden_shield_menders", "unknown_ignored_id"], {"gold": 18, "scraps": 1})
	_check(reselected == {"ok": true, "event": canonical_selected} and replay_rng.state == sel_rng.state,
		"re-selection with same seed returns intact authored copy")
	var visit := service.enter(selected_id)
	_check(visit != null and visit.is_valid() and not visit.is_claimed() and visit.get_event() == canonical_selected,
		"enter(selected_id) opens a fresh unclaimed visit with intact authored record")


func _replay(value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	var state := rng.state
	var service := RunV3HeroEventOffers.new(PARTY_B)
	var receipts: Array = [service.get_offers()]
	var wallet := {"gold": 30, "scraps": 3}
	for event_id in ["v3_lantern_monk_moth_vigil", "v3_rag_duelist_needle_fair", "v3_tinker_clockwork_wagon",
		"v3_lantern_monk_evening_beacon", "v3_rag_duelist_scarlet_fair", "v3_tinker_gear_sideshow",
		"v3_lantern_monk_mothglass_chapel", "v3_rag_duelist_velvet_rapier_stage",
		"v3_tinker_brass_moth_clinic"]:
		var visit := service.enter(event_id)
		_check(visit != null and visit.is_valid(), "replay has genuine admitted visit")
		if visit == null:
			continue
		var receipt := visit.choose_with_wallet(CASES[event_id][1], wallet)
		_check(receipt["ok"], "replay actually settles")
		wallet = receipt["wallet"]
		receipts.append(receipt)
		receipts.append(visit.choose_with_wallet("leave", wallet))
	_check(rng.state == state, "replay preserves run RNG")
	return receipts


func _replay_actionable(value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	var service := RunV3HeroEventOffers.new(PARTY_A)
	var visited: Array[String] = []
	var wallet := {"gold": 0, "scraps": 0}
	var trace: Array = []
	for _step in range(6):
		var selection := service.select_actionable_event(rng, visited, wallet)
		_check(selection["ok"], "seeded actionable replay selects an event")
		if not selection["ok"]:
			break
		var event_id: String = selection["event"]["id"]
		visited.append(event_id)
		var visit := service.enter(event_id)
		_check(visit != null and visit.is_valid() and not visit.is_claimed(),
			"seeded actionable replay opens fresh visit")
		if visit == null:
			break
		var preview := visit.preview_wallet_choices(wallet)
		var chosen_id := ""
		for choice in preview.get("choices", []):
			if choice.get("choice_id") != "leave" and choice.get("affordable") == true:
				chosen_id = choice["choice_id"]
				break
		_check(chosen_id != "", "seeded actionable replay finds affordable non-Leave choice")
		var receipt := visit.choose_with_wallet(chosen_id, wallet)
		_check(receipt["ok"] and visit.is_claimed() and not visit.is_valid(),
			"seeded actionable replay settles chosen affordable option once")
		wallet = receipt["wallet"]
		trace.append({"selected": selection, "receipt": receipt, "rng_state": str(rng.state)})
	return trace


func _replay_actionable_with_preview(value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = value
	var service := RunV3HeroEventOffers.new(PARTY_A)
	var visited: Array[String] = []
	var wallet := {"gold": 0, "scraps": 0}
	var trace: Array = []
	for _step in range(6):
		var outcome := service.select_actionable_event_with_preview(rng, visited, wallet)
		_check(outcome["ok"], "seeded actionable with preview replay selects an event")
		if not outcome["ok"]:
			break
		var event_id: String = outcome["event"]["id"]
		visited.append(event_id)
		var preview: Dictionary = outcome["preview"]
		_check(preview.get("ok", false) and preview.get("event_id") == event_id,
			"preview matches event in replay")
		var chosen_id := ""
		var chosen_wallet := {}
		for choice in preview.get("choices", []):
			if choice.get("choice_id") != "leave" and choice.get("affordable") == true:
				chosen_id = choice["choice_id"]
				chosen_wallet = choice["wallet"]
				break
		_check(chosen_id != "", "replay finds affordable non-Leave choice in preview")
		var visit := service.enter(event_id)
		_check(visit != null and visit.is_valid() and not visit.is_claimed(),
			"replay opens fresh authentic visit via enter(id)")
		if visit == null:
			break
		var receipt := visit.choose_with_wallet(chosen_id, wallet)
		_check(receipt["ok"] and receipt["wallet"] == chosen_wallet
			and visit.is_claimed() and not visit.is_valid(),
			"replay settlement receipt matches forecast and latches claim")
		wallet = receipt["wallet"]
		trace.append({"outcome": outcome, "receipt": receipt, "rng_state": str(rng.state)})
	return trace


func _find_choice_quote(choices: Array, choice_id: String) -> Dictionary:
	for c in choices:
		if c is Dictionary and c.get("choice_id") == choice_id:
			return c
	return {}


func _test_actionable_preview_anchors() -> void:
	# AC1 & AC2: Warden ferry anchor (v3_warden_copper_chain_ferry).
	var warden_party := PARTY_A
	var service_warden := RunV3HeroEventOffers.new(warden_party)
	_check(service_warden.is_valid(), "Warden party service valid")
	var ferry_id := "v3_warden_copper_chain_ferry"
	var canonical_ferry := _by_id(catalog["events"], ferry_id)
	_check(not canonical_ferry.is_empty(), "canonical Warden ferry found")

	var excluded_except_ferry: Array[String] = []
	for offer in service_warden.get_offers():
		if offer["id"] != ferry_id:
			excluded_except_ferry.append(offer["id"])

	# AC1: Wallet {0, 0}
	var rng_w0 := RandomNumberGenerator.new()
	rng_w0.seed = 3001
	var ref_rng_w0 := RandomNumberGenerator.new()
	ref_rng_w0.seed = 3001
	ref_rng_w0.randi_range(0, 0)
	var wallet_w0 := {"gold": 0, "scraps": 0}
	var wallet_w0_copy := wallet_w0.duplicate(true)
	var res_w0 := service_warden.select_actionable_event_with_preview(rng_w0, excluded_except_ferry, wallet_w0)
	_check(res_w0.get("ok") == true, "AC1: Warden ferry selected with preview at {0,0}")
	_check(rng_w0.state == ref_rng_w0.state, "AC1: exactly one randi_range(0,0) draw consumed")
	_check(wallet_w0 == wallet_w0_copy, "AC1: caller wallet untouched")
	_check(res_w0.get("event") == canonical_ferry, "AC1: returned event matches canonical authored record")
	var prev_w0: Dictionary = res_w0.get("preview", {})
	_check(prev_w0.get("ok") == true and prev_w0.get("event_id") == ferry_id, "AC1: preview ok with matching event_id")
	var choices_w0: Array = prev_w0.get("choices", [])
	_check(choices_w0.size() == 3, "AC1: preview contains all 3 choices")
	var brace_w0 := _find_choice_quote(choices_w0, "brace_ferry_chain")
	var buy_w0 := _find_choice_quote(choices_w0, "buy_brass_buckles")
	var leave_w0 := _find_choice_quote(choices_w0, "leave")
	_check(brace_w0 == {
		"choice_id": "brace_ferry_chain",
		"gold_delta": 20,
		"scraps_delta": 0,
		"affordable": true,
		"wallet": {"gold": 20, "scraps": 0},
	}, "AC1: brace_ferry_chain yields +20 gold and is affordable at {0,0}")
	_check(buy_w0 == {
		"choice_id": "buy_brass_buckles",
		"gold_delta": -14,
		"scraps_delta": 2,
		"affordable": false,
		"wallet": {"gold": 0, "scraps": 0},
	}, "AC1: buy_brass_buckles costs 14 gold, grants 2 scraps, is unaffordable at {0,0}")
	_check(leave_w0 == {
		"choice_id": "leave",
		"gold_delta": 0,
		"scraps_delta": 0,
		"affordable": true,
		"wallet": {"gold": 0, "scraps": 0},
	}, "AC1: Leave changes neither and is affordable at {0,0}")

	# AC2: Funded wallet {14, 0} on Warden ferry.
	var rng_w14 := RandomNumberGenerator.new()
	rng_w14.seed = 3002
	var wallet_w14 := {"gold": 14, "scraps": 0}
	var wallet_w14_copy := wallet_w14.duplicate(true)
	var offers_before := service_warden.get_offers()
	var res_w14 := service_warden.select_actionable_event_with_preview(rng_w14, excluded_except_ferry, wallet_w14)
	_check(res_w14.get("ok") == true, "AC2: Warden ferry selected at {14,0}")
	_check(wallet_w14 == wallet_w14_copy, "AC2: caller wallet unchanged by offering")
	_check(service_warden.get_offers() == offers_before, "AC2: service offers unchanged by preview")
	var prev_w14: Dictionary = res_w14.get("preview", {})
	var choices_w14: Array = prev_w14.get("choices", [])
	var brace_w14 := _find_choice_quote(choices_w14, "brace_ferry_chain")
	var buy_w14 := _find_choice_quote(choices_w14, "buy_brass_buckles")
	var leave_w14 := _find_choice_quote(choices_w14, "leave")
	_check(brace_w14 == {
		"choice_id": "brace_ferry_chain",
		"gold_delta": 20,
		"scraps_delta": 0,
		"affordable": true,
		"wallet": {"gold": 34, "scraps": 0},
	}, "AC2: brace_ferry_chain offered and affordable at {14,0}")
	_check(buy_w14 == {
		"choice_id": "buy_brass_buckles",
		"gold_delta": -14,
		"scraps_delta": 2,
		"affordable": true,
		"wallet": {"gold": 0, "scraps": 2},
	}, "AC2: buy_brass_buckles affordable and projects {0,2} at {14,0}")
	_check(leave_w14 == {
		"choice_id": "leave",
		"gold_delta": 0,
		"scraps_delta": 0,
		"affordable": true,
		"wallet": {"gold": 14, "scraps": 0},
	}, "AC2: Leave offered and affordable at {14,0}")

	# AC2: Separate genuine service.enter(id) visits settle once matching preview or leave without debit.
	var visit_buy := service_warden.enter(ferry_id)
	_check(visit_buy != null and visit_buy.is_valid() and not visit_buy.is_claimed(), "AC2: fresh visit opens via enter()")
	if visit_buy != null:
		var receipt_buy := visit_buy.choose_with_wallet("buy_brass_buckles", wallet_w14)
		_check(receipt_buy == {
			"ok": true,
			"event_id": ferry_id,
			"choice_id": "buy_brass_buckles",
			"wallet": {"gold": 0, "scraps": 2},
		}, "AC2: paid choice settles for exact projected receipt")
		_check(visit_buy.is_claimed() and not visit_buy.is_valid(), "AC2: claim latched")
		_check(visit_buy.choose_with_wallet("leave", {"gold": 0, "scraps": 2}).get("ok") == false,
			"AC2: cannot claim twice on same visit")

	var visit_leave := service_warden.enter(ferry_id)
	_check(visit_leave != null and visit_leave.is_valid() and not visit_leave.is_claimed(), "AC2: second fresh visit opens")
	if visit_leave != null:
		var receipt_leave := visit_leave.choose_with_wallet("leave", wallet_w14)
		_check(receipt_leave == {
			"ok": true,
			"event_id": ferry_id,
			"choice_id": "leave",
			"wallet": {"gold": 14, "scraps": 0},
		}, "AC2: Leave settles without debit")
		_check(visit_leave.is_claimed() and not visit_leave.is_valid(), "AC2: Leave latches claim")

	# AC2: Yarn Ranger mooring anchor (v3_yarn_ranger_bolas_mooring).
	var ranger_party := ["scarecrow", "yarn_ranger", "button_golem"]
	var service_ranger := RunV3HeroEventOffers.new(ranger_party)
	_check(service_ranger.is_valid(), "Yarn Ranger party service valid")
	var mooring_id := "v3_yarn_ranger_bolas_mooring"
	var canonical_mooring := _by_id(catalog["events"], mooring_id)
	_check(not canonical_mooring.is_empty(), "canonical Yarn Ranger mooring found")

	var excluded_except_mooring: Array[String] = []
	for offer in service_ranger.get_offers():
		if offer["id"] != mooring_id:
			excluded_except_mooring.append(offer["id"])

	# At {gold: 0, scraps: 0}: recover_knotted_bolas is free (+2 scraps), sell_spare_knitting_knots is unaffordable.
	var rng_yr0 := RandomNumberGenerator.new()
	rng_yr0.seed = 3003
	var res_yr0 := service_ranger.select_actionable_event_with_preview(rng_yr0, excluded_except_mooring, {"gold": 0, "scraps": 0})
	_check(res_yr0.get("ok") == true, "AC2: Yarn Ranger mooring selected at {0,0}")
	_check(res_yr0.get("event") == canonical_mooring, "AC2: mooring event matches canonical")
	var choices_yr0: Array = res_yr0.get("preview", {}).get("choices", [])
	var recover_yr0 := _find_choice_quote(choices_yr0, "recover_knotted_bolas")
	var sell_yr0 := _find_choice_quote(choices_yr0, "sell_spare_knitting_knots")
	var leave_yr0 := _find_choice_quote(choices_yr0, "leave")
	_check(recover_yr0 == {
		"choice_id": "recover_knotted_bolas",
		"gold_delta": 0,
		"scraps_delta": 2,
		"affordable": true,
		"wallet": {"gold": 0, "scraps": 2},
	}, "AC2: recover_knotted_bolas awards 2 scraps free at {0,0}")
	_check(sell_yr0 == {
		"choice_id": "sell_spare_knitting_knots",
		"gold_delta": 20,
		"scraps_delta": -1,
		"affordable": false,
		"wallet": {"gold": 0, "scraps": 0},
	}, "AC2: sell_spare_knitting_knots (+20 gold, -1 scrap) unaffordable at 0 scraps")
	_check(leave_yr0.get("affordable") == true, "AC2: Leave affordable at {0,0}")

	# Check actual visit settlement at {0, 0}: sell refuses without claim, recover succeeds.
	var visit_yr_poor := service_ranger.enter(mooring_id)
	_check(visit_yr_poor != null and visit_yr_poor.is_valid(), "AC2: fresh mooring visit opens")
	if visit_yr_poor != null:
		var refuse_sell := visit_yr_poor.choose_with_wallet("sell_spare_knitting_knots", {"gold": 0, "scraps": 0})
		_check(refuse_sell.get("ok") == false and visit_yr_poor.is_valid() and not visit_yr_poor.is_claimed(),
			"AC2: unaffordable sale refused without claiming visit")
		var claim_recov := visit_yr_poor.choose_with_wallet("recover_knotted_bolas", {"gold": 0, "scraps": 0})
		_check(claim_recov == {
			"ok": true,
			"event_id": mooring_id,
			"choice_id": "recover_knotted_bolas",
			"wallet": {"gold": 0, "scraps": 2},
		} and visit_yr_poor.is_claimed(), "AC2: recover settles matching preview")

	# At {gold: 0, scraps: 1}: sell_spare_knitting_knots becomes affordable!
	var rng_yr1 := RandomNumberGenerator.new()
	rng_yr1.seed = 3004
	var res_yr1 := service_ranger.select_actionable_event_with_preview(rng_yr1, excluded_except_mooring, {"gold": 0, "scraps": 1})
	_check(res_yr1.get("ok") == true, "AC2: Yarn Ranger mooring selected at {0,1}")
	var choices_yr1: Array = res_yr1.get("preview", {}).get("choices", [])
	var sell_yr1 := _find_choice_quote(choices_yr1, "sell_spare_knitting_knots")
	_check(sell_yr1 == {
		"choice_id": "sell_spare_knitting_knots",
		"gold_delta": 20,
		"scraps_delta": -1,
		"affordable": true,
		"wallet": {"gold": 20, "scraps": 0},
	}, "AC2: sell_spare_knitting_knots affordable once 1 scrap is held")
	var visit_yr_funded := service_ranger.enter(mooring_id)
	_check(visit_yr_funded != null and visit_yr_funded.is_valid(), "AC2: funded mooring visit opens")
	if visit_yr_funded != null:
		var claim_sell := visit_yr_funded.choose_with_wallet("sell_spare_knitting_knots", {"gold": 0, "scraps": 1})
		_check(claim_sell == {
			"ok": true,
			"event_id": mooring_id,
			"choice_id": "sell_spare_knitting_knots",
			"wallet": {"gold": 20, "scraps": 0},
		} and visit_yr_funded.is_claimed(), "AC2: funded sale settles matching preview quote")

	# AC2 & AC3: Absent-hero Scarecrow roost anchor (v3_scarecrow_crow_roost).
	var roost_id := "v3_scarecrow_crow_roost"
	var canonical_roost := _by_id(catalog["events"], roost_id)
	_check(not canonical_roost.is_empty(), "canonical Scarecrow roost found")

	# Party without Scarecrow: PARTY_A = ["warden", "seamstress", "tinker"].
	var service_no_scarecrow := RunV3HeroEventOffers.new(PARTY_A)
	_check(service_no_scarecrow.is_valid(), "PARTY_A service valid")
	_check(_by_id(service_no_scarecrow.get_offers(), roost_id).is_empty(),
		"AC2: Scarecrow roost never offered to party without scarecrow")
	_check(service_no_scarecrow.enter(roost_id) == null,
		"AC2: party without scarecrow denied entry to Scarecrow roost")

	# Injected catalog containing only Scarecrow roost with party lacking Scarecrow.
	var injected_roost_service := RunV3HeroEventOffers.new(PARTY_A, {"events": [canonical_roost]})
	_check(injected_roost_service.is_valid() and injected_roost_service.get_offers().is_empty(),
		"AC2: injected Scarecrow roost gives 0 eligible offers for PARTY_A")
	var rng_no_scare := RandomNumberGenerator.new()
	rng_no_scare.seed = 3005
	var state_no_scare := rng_no_scare.state
	var res_no_scare := injected_roost_service.select_actionable_event_with_preview(rng_no_scare, null, {"gold": 50, "scraps": 5})
	_check(res_no_scare == {"ok": false, "event": {}, "preview": {}} and rng_no_scare.state == state_no_scare,
		"AC2: party without scarecrow never offered Scarecrow roost even with funded wallet (0 RNG draws)")


func _test_actionable_preview_sampling_and_replay() -> void:
	# AC3: Lexicographical order, exactly 1 caller-RNG draw, reversed catalog invariance.
	var reversed := catalog.duplicate(true)
	reversed["events"].reverse()
	for party in [PARTY_A, PARTY_B]:
		var service := RunV3HeroEventOffers.new(party)
		var reordered := RunV3HeroEventOffers.new(party, reversed)
		_check(service.is_valid() and reordered.is_valid(), "services valid for sampling test")
		for wallet in [{"gold": 0, "scraps": 0}, {"gold": 18, "scraps": 1}, {"gold": 30, "scraps": 3}]:
			var expected_ids := _expected_actionable_ids(party, wallet)
			_check(not expected_ids.is_empty(), "actionable candidates exist for " + str(party))
			for seed_val in [2101, 2202, 2303, 2404]:
				var rng_norm := RandomNumberGenerator.new()
				rng_norm.seed = seed_val
				var rng_rev := RandomNumberGenerator.new()
				rng_rev.seed = seed_val
				var rng_ref := RandomNumberGenerator.new()
				rng_ref.seed = seed_val
				var idx := rng_ref.randi_range(0, expected_ids.size() - 1)
				var chosen_id: String = expected_ids[idx]
				var expected_record := _by_id(catalog["events"], chosen_id)
				var expected_preview := RunEventChoice.new(expected_record).preview_wallet_choices(wallet)

				var res_norm := service.select_actionable_event_with_preview(rng_norm, null, wallet)
				var res_rev := reordered.select_actionable_event_with_preview(rng_rev, [], wallet)

				_check(res_norm == {
					"ok": true,
					"event": expected_record,
					"preview": expected_preview,
				}, "AC3: normal catalog select_actionable_event_with_preview matches expected offer and preview: " + str(seed_val))
				_check(res_rev == res_norm, "AC3: reversed catalog yields identical offer and preview: " + str(seed_val))
				_check(rng_norm.state == rng_ref.state and rng_rev.state == rng_ref.state,
					"AC3: consumes exact one randi_range draw: " + str(seed_val))


func _test_actionable_preview_invalids_and_isolation() -> void:
	var service := RunV3HeroEventOffers.new(PARTY_A)
	var valid_wallet := {"gold": 18, "scraps": 1}
	var valid_exclusions := ["v3_warden_shield_menders"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 4001
	var state := rng.state

	# Omitted wallet (1-arg and 2-arg calls) fails closed with 0 draws.
	_check(service.select_actionable_event_with_preview(rng) == {"ok": false, "event": {}, "preview": {}}
		and rng.state == state, "omitted wallet and exclusions rejected with 0 draws")
	_check(service.select_actionable_event_with_preview(rng, []) == {"ok": false, "event": {}, "preview": {}}
		and rng.state == state, "omitted wallet with valid exclusions rejected with 0 draws")

	# Malformed RNG inputs fail closed without draws.
	for bad_rng in [null, 0, 257, "rng", {}, [], RefCounted.new(), service]:
		_check(service.select_actionable_event_with_preview(bad_rng, valid_exclusions, valid_wallet) == {
			"ok": false, "event": {}, "preview": {}}, "malformed RNG rejected: " + str(bad_rng))
	_check(rng.state == state, "malformed RNG checks leave test RNG untouched")

	# Malformed wallet inputs fail closed with 0 draws.
	for bad_wallet in [
		null, {}, {"gold": 10}, {"scraps": 1},
		{"gold": 10, "scraps": 1, "extra": 0},
		{"gold": -1, "scraps": 0}, {"gold": 0, "scraps": -1}, {"gold": -5, "scraps": -2},
		{"gold": 10.0, "scraps": 0}, {"gold": 0, "scraps": 1.0}, {"gold": 18.5, "scraps": 1},
		{"gold": "18", "scraps": 1}, {"gold": 18, "scraps": "1"},
		{"gold": true, "scraps": 1}, {"gold": 18, "scraps": false},
		{"gold": null, "scraps": 1}, {"gold": 18, "scraps": null},
		[], ["gold", "scraps"], "wallet", 18, false,
	]:
		var before_bad: Variant = bad_wallet.duplicate(true) if bad_wallet is Dictionary or bad_wallet is Array else bad_wallet
		var res := service.select_actionable_event_with_preview(rng, valid_exclusions, bad_wallet)
		_check(res == {"ok": false, "event": {}, "preview": {}} and rng.state == state and bad_wallet == before_bad,
			"malformed wallet rejected with 0 draws: " + str(bad_wallet))

	# Malformed excluded_ids inputs fail closed with 0 draws.
	for bad_exclusions in [
		"", "v3_warden_copper_chain_ferry", {}, {"id": "v3_warden_copper_chain_ferry"}, 1, false,
		[""], ["   "], ["\t\n"], [null], [123], [true], [{}], [[]],
		["v3_warden_copper_chain_ferry", ""],
		["v3_warden_copper_chain_ferry", "   "],
		["v3_warden_copper_chain_ferry", null],
		["v3_warden_copper_chain_ferry", 9],
		["v3_warden_copper_chain_ferry", {"id": "v3_seamstress_needle_oracle"}],
	]:
		var before_excl: Variant = bad_exclusions.duplicate(true) if bad_exclusions is Dictionary or bad_exclusions is Array else bad_exclusions
		var res := service.select_actionable_event_with_preview(rng, bad_exclusions, valid_wallet)
		_check(res == {"ok": false, "event": {}, "preview": {}} and rng.state == state and bad_exclusions == before_excl,
			"malformed excluded_ids rejected with 0 draws: " + str(bad_exclusions))

	# Exhausted actionable pool fails closed with 0 draws.
	var all_offers := service.get_offers()
	var all_ids: Array[String] = []
	for off in all_offers:
		all_ids.append(off["id"])
	var state_exh := rng.state
	var res_exh := service.select_actionable_event_with_preview(rng, all_ids, valid_wallet)
	_check(res_exh == {"ok": false, "event": {}, "preview": {}} and rng.state == state_exh,
		"fully excluded actionable pool rejected with 0 draws")

	# Leave-only candidate at {0, 0} rejected with 0 draws.
	var exclude_all_but_oracle: Array[String] = []
	for off in all_offers:
		if off["id"] != "v3_seamstress_needle_oracle":
			exclude_all_but_oracle.append(off["id"])
	var state_leave_only := rng.state
	var res_leave_only := service.select_actionable_event_with_preview(rng, exclude_all_but_oracle, {"gold": 0, "scraps": 0})
	_check(res_leave_only == {"ok": false, "event": {}, "preview": {}} and rng.state == state_leave_only,
		"Leave-only candidate rejected with 0 draws")

	# Detached copy and non-mutation isolation.
	var sel_rng := RandomNumberGenerator.new()
	sel_rng.seed = 4501
	var replay_rng := RandomNumberGenerator.new()
	replay_rng.seed = 4501
	var caller_wallet := {"gold": 18, "scraps": 1}
	var caller_exclusions := ["v3_warden_shield_menders"]
	var selected := service.select_actionable_event_with_preview(sel_rng, caller_exclusions, caller_wallet)
	_check(selected["ok"] == true, "selection with preview succeeds")
	var selected_id: String = selected["event"]["id"]
	var canonical_selected := _by_id(catalog["events"], selected_id)
	_check(selected["event"] == canonical_selected, "selected event matches canonical record")
	_check(caller_wallet == {"gold": 18, "scraps": 1} and caller_exclusions == ["v3_warden_shield_menders"],
		"caller wallet and exclusions untouched")

	# Mutate the returned event and preview dictionaries heavily.
	selected["ok"] = false
	selected["event"]["id"] = "forged_id"
	selected["event"]["choices"].clear()
	selected["preview"]["ok"] = false
	selected["preview"]["choices"].clear()

	_check(service.enter(selected["event"]) == null and service.enter("forged_id") == null,
		"mutated selected event or forged ID cannot authorize enter()")
	_check(service.get_offers() == all_offers, "mutating selected copy never mutates service offers")

	var reselected := service.select_actionable_event_with_preview(replay_rng, ["v3_warden_shield_menders"], {"gold": 18, "scraps": 1})
	_check(reselected["ok"] == true and reselected["event"] == canonical_selected
		and reselected["preview"] == RunEventChoice.new(canonical_selected).preview_wallet_choices({"gold": 18, "scraps": 1})
		and replay_rng.state == sel_rng.state,
		"re-selection with same seed produces pristine canonical record and preview")


const VITAL_HERO_SPECS := {
	"v3_warden_buckle_heart_ward": {
		"hero": "warden",
		"trades": {
			"reinforce_shield_seam": [0, -2, 0, 3],
			"sell_rivets": [24, 0, 0, -2],
			"leave": [0, 0, 0, 0],
		},
	},
	"v3_seamstress_crimson_quilt_surgeon": {
		"hero": "seamstress",
		"trades": {
			"stitch_wound": [-12, 0, 8, 0],
			"donate_red_thread": [18, 0, -4, 0],
			"leave": [0, 0, 0, 0],
		},
	},
	"v3_tinker_copper_needle_greenhouse": {
		"hero": "tinker",
		"trades": {
			"buy_gear_balm": [-10, 0, 6, 0],
			"harvest_barbed_gears": [0, 3, -6, 0],
			"leave": [0, 0, 0, 0],
		},
	},
	"v3_lantern_monk_thimble_moon_vigil": {
		"hero": "lantern_monk",
		"trades": {
			"moonlight_seam": [-16, 0, 0, 2],
			"tend_moth_candles": [20, 0, -4, 0],
			"leave": [0, 0, 0, 0],
		},
	},
	"v3_rag_duelist_velvet_straw_mender": {
		"hero": "rag_duelist",
		"trades": {
			"mend_cape": [0, -2, 10, 0],
			"sell_cape_padding": [22, 0, -5, 0],
			"leave": [0, 0, 0, 0],
		},
	},
}


func _vital_state(hero_id: String, gold: int = 50, scraps: int = 5, hp: int = 20, max_hp: int = 30) -> Dictionary:
	return {
		"gold": gold,
		"scraps": scraps,
		"hero": {
			"id": hero_id,
			"hp": hp,
			"max_hp": max_hp,
		},
	}


func _test_v3_hero_vital_event_gate() -> void:
	# Load and check the new catalog file directly.
	var vital_catalog_raw := FileAccess.get_file_as_string(RunV3HeroVitalEventGate.CATALOG_PATH)
	_check(not vital_catalog_raw.is_empty(), "shipped v3_hero_vital_events.json loads")
	var vital_catalog: Dictionary = JSON.parse_string(vital_catalog_raw)
	_check(vital_catalog.has("events") and vital_catalog["events"] is Array, "vital catalog has events array")
	var catalog_events: Array = vital_catalog.get("events", [])

	# AC4: Authenticity and own-ID presence (never assert total catalog size).
	for event_id: String in VITAL_HERO_SPECS:
		var found := _by_id(catalog_events, event_id)
		_check(not found.is_empty(), "vital hero event exists by own-ID: " + event_id)
		if found.is_empty():
			continue
		var spec: Dictionary = VITAL_HERO_SPECS[event_id]
		_check(found.get("required_hero") == spec["hero"], "vital event required_hero: " + event_id)
		_check(not String(found.get("title", "")).strip_edges().is_empty(), "vital event title nonblank: " + event_id)
		_check(not String(found.get("description", "")).strip_edges().is_empty(), "vital event description nonblank: " + event_id)
		var choices: Array = found.get("choices", [])
		_check(choices.size() == 3, "vital event has exactly 3 choices: " + event_id)
		var seen_ids := {}
		for choice: Variant in choices:
			_check(choice is Dictionary, "choice is dictionary: " + event_id)
			if not choice is Dictionary:
				continue
			var cid: String = choice.get("id", "")
			_check(spec["trades"].has(cid), "recognized choice ID: " + event_id + "/" + cid)
			_check(not seen_ids.has(cid), "unique choice ID: " + event_id + "/" + cid)
			seen_ids[cid] = true
			_check(not String(choice.get("text", "")).strip_edges().is_empty(), "choice text nonblank: " + event_id + "/" + cid)
			var expected_deltas: Array = spec["trades"][cid]
			var out: Dictionary = choice.get("outcome", {})
			_check(int(out.get("gold")) == expected_deltas[0]
				and int(out.get("scraps")) == expected_deltas[1]
				and int(out.get("hp")) == expected_deltas[2]
				and int(out.get("max_hp")) == expected_deltas[3],
				"choice exact deltas match: " + event_id + "/" + cid)

	# AC1: Offers for valid parties (PARTY_A and PARTY_B).
	var gate_a := RunV3HeroVitalEventGate.new(PARTY_A)
	var gate_b := RunV3HeroVitalEventGate.new(PARTY_B)
	_check(gate_a.is_valid() and gate_b.is_valid(), "gates valid for canonical parties")

	var offers_a := gate_a.get_offers()
	var offers_b := gate_b.get_offers()

	_check(_by_id(offers_a, "v3_warden_buckle_heart_ward").size() > 0, "PARTY_A offers warden vital event")
	_check(_by_id(offers_a, "v3_seamstress_crimson_quilt_surgeon").size() > 0, "PARTY_A offers seamstress vital event")
	_check(_by_id(offers_a, "v3_tinker_copper_needle_greenhouse").size() > 0, "PARTY_A offers tinker vital event")
	_check(_by_id(offers_a, "v3_lantern_monk_thimble_moon_vigil").is_empty(), "PARTY_A excludes lantern_monk vital event")
	_check(_by_id(offers_a, "v3_rag_duelist_velvet_straw_mender").is_empty(), "PARTY_A excludes rag_duelist vital event")

	_check(_by_id(offers_b, "v3_lantern_monk_thimble_moon_vigil").size() > 0, "PARTY_B offers lantern_monk vital event")
	_check(_by_id(offers_b, "v3_rag_duelist_velvet_straw_mender").size() > 0, "PARTY_B offers rag_duelist vital event")
	_check(_by_id(offers_b, "v3_tinker_copper_needle_greenhouse").size() > 0, "PARTY_B offers tinker vital event")
	_check(_by_id(offers_b, "v3_warden_buckle_heart_ward").is_empty(), "PARTY_B excludes warden vital event")
	_check(_by_id(offers_b, "v3_seamstress_crimson_quilt_surgeon").is_empty(), "PARTY_B excludes seamstress vital event")

	# Invalid parties fail closed. Four distinct heroes are valid (see
	# _test_four_hero_vital_gate_admission); wrong sizes, duplicates, unknown IDs
	# and non-string members still reject.
	for bad_party in [null, {}, "warden", [], ["warden"], ["warden", "seamstress"],
		["warden", "seamstress", "tinker", "lantern_monk", "scarecrow"],
		["warden", "seamstress", "tinker", "lantern_monk", "scarecrow", "rag_duelist"],
		["warden", "warden", "tinker"], ["warden", "warden", "tinker", "lantern_monk"],
		["warden", "unknown", "tinker"], ["warden", "unknown", "tinker", "lantern_monk"],
		["warden", "", "tinker"], ["warden", "", "tinker", "lantern_monk"],
		["warden", 1, "tinker"], ["warden", 1, "tinker", "lantern_monk"],
		["Warden", "seamstress", "tinker", "lantern_monk"]]:
		var bad_gate := RunV3HeroVitalEventGate.new(bad_party)
		_check(not bad_gate.is_valid() and bad_gate.get_offers().is_empty()
			and bad_gate.enter("v3_warden_buckle_heart_ward", _vital_state("warden")) == null,
			"invalid party fails closed: " + str(bad_party))

	# AC1: Entering a visit requires living snapshot for that same hero.
	var warden_snapshot := _vital_state("warden", 50, 5, 20, 30)
	var admitted_visit := gate_a.enter("v3_warden_buckle_heart_ward", warden_snapshot)
	_check(admitted_visit != null and admitted_visit.is_valid() and not admitted_visit.is_claimed(),
		"admitted visit valid and unclaimed")

	# Wrong hero in party.
	var wrong_hero_snapshot := _vital_state("tinker", 50, 5, 20, 30)
	_check(gate_a.enter("v3_warden_buckle_heart_ward", wrong_hero_snapshot) == null,
		"refuse admission when hero snapshot does not match required_hero")

	# Missing required hero (not in party).
	var missing_hero_snapshot := _vital_state("scarecrow", 50, 5, 20, 30)
	_check(gate_a.enter("v3_warden_buckle_heart_ward", missing_hero_snapshot) == null,
		"refuse admission for hero not in party")

	# Torn hero (0 HP).
	var torn_snapshot := _vital_state("warden", 50, 5, 0, 30)
	_check(gate_a.enter("v3_warden_buckle_heart_ward", torn_snapshot) == null,
		"refuse admission for Torn hero (0 HP)")

	# Invalid HP boundaries.
	_check(gate_a.enter("v3_warden_buckle_heart_ward", _vital_state("warden", 50, 5, -1, 30)) == null,
		"refuse admission for negative HP")
	_check(gate_a.enter("v3_warden_buckle_heart_ward", _vital_state("warden", 50, 5, 35, 30)) == null,
		"refuse admission when HP exceeds max_HP")
	_check(gate_a.enter("v3_warden_buckle_heart_ward", _vital_state("warden", 50, 5, 5, 9)) == null,
		"refuse admission when max_HP < 10 floor")

	# Unoffered event ID for PARTY_A.
	_check(gate_a.enter("v3_lantern_monk_thimble_moon_vigil", _vital_state("lantern_monk")) == null,
		"refuse admission to unoffered event")
	_check(gate_a.enter("v3_nonexistent_event", warden_snapshot) == null,
		"refuse admission to unknown event")

	# AC2: All five events preview and commit exact four-key signed deltas.
	for event_id: String in VITAL_HERO_SPECS:
		var spec: Dictionary = VITAL_HERO_SPECS[event_id]
		var hero_id: String = spec["hero"]
		var gate: RunV3HeroVitalEventGate = gate_a if PARTY_A.has(hero_id) else gate_b
		for choice_id: String in spec["trades"]:
			var base_snap := _vital_state(hero_id, 50, 5, 20, 30)
			var snap_copy := base_snap.duplicate(true)
			var visit := gate.enter(event_id, base_snap)
			_check(visit != null and visit.is_valid(), "open fresh visit for AC2: " + event_id + "/" + choice_id)
			if visit == null:
				continue
			var deltas: Array = spec["trades"][choice_id]
			var expected_max: int = base_snap["hero"]["max_hp"] + deltas[3]
			var expected_hp: int = mini(base_snap["hero"]["hp"] + deltas[2], expected_max)
			var expected_state := _vital_state(hero_id,
				base_snap["gold"] + deltas[0],
				base_snap["scraps"] + deltas[1],
				expected_hp,
				expected_max)

			# Preview forecast.
			var preview := visit.preview_vital_choices(base_snap)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"preview ok: " + event_id + "/" + choice_id)
			var preview_entry := {}
			for entry: Variant in preview.get("choices", []):
				if entry is Dictionary and entry.get("choice_id") == choice_id:
					preview_entry = entry
					break
			_check(preview_entry == {
				"choice_id": choice_id,
				"gold_delta": deltas[0],
				"scraps_delta": deltas[1],
				"hp_delta": deltas[2],
				"max_hp_delta": deltas[3],
				"affordable": true,
				"state": expected_state,
			}, "forecast equals exact four-key deltas and state: " + event_id + "/" + choice_id)
			_check(not visit.is_claimed() and visit.is_valid() and base_snap == snap_copy,
				"preview is non-claiming and snapshot unchanged")

			# Claim commitment.
			var receipt := visit.choose_with_vitals(choice_id, base_snap)
			_check(receipt == {
				"ok": true,
				"event_id": event_id,
				"choice_id": choice_id,
				"state": expected_state,
			}, "affordable forecast equals claim receipt: " + event_id + "/" + choice_id)
			_check(visit.is_claimed() and not visit.is_valid() and base_snap == snap_copy,
				"claim latches visit and input snapshot remains detached")

			# Replay refusal.
			var replay := visit.choose_with_vitals(choice_id, expected_state)
			_check(replay == {"ok": false, "event_id": "", "choice_id": "", "state": expected_state},
				"replay refuses after single claim latched: " + event_id + "/" + choice_id)
			_check(visit.choose_with_vitals("leave", expected_state).get("ok") == false,
				"alternative choice also refuses once claimed")

	# AC2: Math detail — increasing max HP alone does not heal.
	var warden_buff_snap := _vital_state("warden", 50, 5, 20, 30)
	var warden_buff_visit := gate_a.enter("v3_warden_buckle_heart_ward", warden_buff_snap)
	var buff_receipt := warden_buff_visit.choose_with_vitals("reinforce_shield_seam", warden_buff_snap)
	_check(buff_receipt.get("ok") == true
		and buff_receipt["state"]["hero"]["max_hp"] == 33
		and buff_receipt["state"]["hero"]["hp"] == 20,
		"increasing max HP alone does not heal current HP")

	# AC2: Math detail — max HP cut pulls current HP down if current HP > new max HP.
	var warden_cut_snap := _vital_state("warden", 50, 5, 30, 30)
	var warden_cut_visit := gate_a.enter("v3_warden_buckle_heart_ward", warden_cut_snap)
	var cut_receipt := warden_cut_visit.choose_with_vitals("sell_rivets", warden_cut_snap)
	_check(cut_receipt.get("ok") == true
		and cut_receipt["state"]["hero"]["max_hp"] == 28
		and cut_receipt["state"]["hero"]["hp"] == 28,
		"max HP cut clamps current HP to new lower max")

	# AC3: Unaffordable payments refuse without consuming visit; recovery path succeeds.
	# 1. Insufficient gold (stitch_wound costs 12 gold).
	var poor_gold_snap := _vital_state("seamstress", 5, 5, 20, 30)
	var poor_gold_copy := poor_gold_snap.duplicate(true)
	var visit_poor_gold := gate_a.enter("v3_seamstress_crimson_quilt_surgeon", poor_gold_snap)
	var res_poor_gold := visit_poor_gold.choose_with_vitals("stitch_wound", poor_gold_snap)
	_check(res_poor_gold.get("ok") == false and visit_poor_gold.is_valid() and not visit_poor_gold.is_claimed()
		and poor_gold_snap == poor_gold_copy, "insufficient gold refuses without consuming visit")
	var recov_gold := visit_poor_gold.choose_with_vitals("leave", poor_gold_snap)
	_check(recov_gold.get("ok") == true and visit_poor_gold.is_claimed() and not visit_poor_gold.is_valid(),
		"subsequently choosing Leave recovers and claims visit exactly once")

	# 2. Insufficient scraps (reinforce_shield_seam costs 2 scraps).
	var poor_scraps_snap := _vital_state("warden", 50, 1, 20, 30)
	var poor_scraps_copy := poor_scraps_snap.duplicate(true)
	var visit_poor_scraps := gate_a.enter("v3_warden_buckle_heart_ward", poor_scraps_snap)
	var res_poor_scraps := visit_poor_scraps.choose_with_vitals("reinforce_shield_seam", poor_scraps_snap)
	_check(res_poor_scraps.get("ok") == false and visit_poor_scraps.is_valid() and not visit_poor_scraps.is_claimed()
		and poor_scraps_snap == poor_scraps_copy, "insufficient scraps refuses without consuming visit")
	var recov_scraps := visit_poor_scraps.choose_with_vitals("leave", poor_scraps_snap)
	_check(recov_scraps.get("ok") == true and visit_poor_scraps.is_claimed(), "recovery via Leave succeeds after scraps refusal")

	# 3. HP=1 payment (donate_red_thread loses 4 HP; must leave at least 1 living HP).
	var hp1_snap := _vital_state("seamstress", 50, 5, 1, 30)
	var hp1_copy := hp1_snap.duplicate(true)
	var visit_hp1 := gate_a.enter("v3_seamstress_crimson_quilt_surgeon", hp1_snap)
	var res_hp1 := visit_hp1.choose_with_vitals("donate_red_thread", hp1_snap)
	_check(res_hp1.get("ok") == false and visit_hp1.is_valid() and not visit_hp1.is_claimed()
		and hp1_snap == hp1_copy, "HP=1 payment refuses without consuming visit")
	# Also test HP=4 payment that would leave exactly 0 HP.
	var hp4_snap := _vital_state("seamstress", 50, 5, 4, 30)
	var visit_hp4 := gate_a.enter("v3_seamstress_crimson_quilt_surgeon", hp4_snap)
	_check(visit_hp4.choose_with_vitals("donate_red_thread", hp4_snap).get("ok") == false
		and visit_hp4.is_valid(), "HP payment resulting in 0 HP refuses without consuming visit")
	var recov_hp1 := visit_hp1.choose_with_vitals("leave", hp1_snap)
	_check(recov_hp1.get("ok") == true and visit_hp1.is_claimed(), "recovery via Leave succeeds after HP refusal")

	# 4. max_HP=10 cut (sell_rivets cuts 2 max HP; floor is 10).
	var floor_max_snap := _vital_state("warden", 50, 5, 10, 10)
	var floor_max_copy := floor_max_snap.duplicate(true)
	var visit_floor_max := gate_a.enter("v3_warden_buckle_heart_ward", floor_max_snap)
	var res_floor_max := visit_floor_max.choose_with_vitals("sell_rivets", floor_max_snap)
	_check(res_floor_max.get("ok") == false and visit_floor_max.is_valid() and not visit_floor_max.is_claimed()
		and floor_max_snap == floor_max_copy, "max_HP cut below floor 10 refuses without consuming visit")
	var recov_floor := visit_floor_max.choose_with_vitals("leave", floor_max_snap)
	_check(recov_floor.get("ok") == true and visit_floor_max.is_claimed(), "recovery via Leave succeeds after max_HP floor refusal")

	# AC4: Forgery detection, detached data, and RNG isolation.
	var warden_record := _by_id(catalog_events, "v3_warden_buckle_heart_ward")
	_check(not warden_record.is_empty(), "canonical warden record found")

	var forged_record := warden_record.duplicate(true)
	forged_record["choices"][0]["outcome"]["gold"] = 999
	_check(gate_a.enter(forged_record, warden_snapshot) == null,
		"forged record with altered outcome cannot bind")

	var forged_id_record := warden_record.duplicate(true)
	forged_id_record["id"] = "v3_forged_vital_event"
	_check(gate_a.enter(forged_id_record, warden_snapshot) == null,
		"forged record with unknown ID cannot bind")

	var forged_catalog := {"events": [forged_record]}
	var forged_gate := RunV3HeroVitalEventGate.new(PARTY_A, forged_catalog)
	_check(not forged_gate.is_valid(), "mutated catalog wholly rejected")

	# Detached data integrity.
	var fresh_gate := RunV3HeroVitalEventGate.new(PARTY_A)
	var initial_offers := fresh_gate.get_offers()
	var mutated_offers := fresh_gate.get_offers()
	mutated_offers.clear()
	_check(fresh_gate.get_offers().size() == initial_offers.size(), "mutating returned offers does not mutate gate")

	var visit_iso := fresh_gate.enter("v3_warden_buckle_heart_ward", warden_snapshot)
	_check(visit_iso != null, "visit opened for isolation test")
	if visit_iso != null:
		var initial_snap := visit_iso.get_snapshot()
		var mutated_snap := visit_iso.get_snapshot()
		mutated_snap["gold"] = 99999
		_check(visit_iso.get_snapshot() == initial_snap, "mutating get_snapshot does not mutate visit state")
		var receipt_iso := visit_iso.choose_with_vitals("leave")
		_check(receipt_iso.get("ok") == true, "leave succeeds on isolation visit")
		receipt_iso["state"]["gold"] = 88888
		_check(visit_iso.get_snapshot()["gold"] != 88888, "mutating receipt does not mutate visit state")


## AC1/AC3: a Design v4 Stitched roster of four distinct canonical heroes must be
## admitted by the existing hero-vital Event gate, expose exactly the authored
## records whose required_hero is on the roster (including the fourth hero's),
## and settle the named Lantern Monk trade exactly once.
func _test_four_hero_vital_gate_admission() -> void:
	var catalog_events: Array = JSON.parse_string(
		FileAccess.get_file_as_string(RunV3HeroVitalEventGate.CATALOG_PATH)).get("events", [])
	var gate := RunV3HeroVitalEventGate.new(STITCHED_PARTY)
	var ranked := RunV3HeroVitalEventGate.new(["lantern_monk", "tinker", "warden", "seamstress"])
	_check(gate.is_valid() and ranked.is_valid(),
		"four-hero Stitched party passes the hero-vital gate regardless of rank order")
	if not gate.is_valid() or not ranked.is_valid():
		return

	# Offered IDs are derived per required_hero from the shipped catalog, never a
	# fixed catalog total or full ordered ID list.
	var expected_ids: Array[String] = []
	for record: Dictionary in catalog_events:
		if STITCHED_PARTY.has(record.get("required_hero")):
			expected_ids.append(record["id"])
	expected_ids.sort()
	var offered_ids: Array[String] = []
	for offer: Dictionary in gate.get_offers():
		offered_ids.append(offer["id"])
		_check(STITCHED_PARTY.has(offer.get("required_hero")),
			"four-hero vital offer belongs to the roster by required_hero: " + str(offer.get("id")))
	offered_ids.sort()
	_check(offered_ids == expected_ids,
		"four-hero vital offers are exactly the roster's authored records")
	var ranked_ids: Array[String] = []
	for offer: Dictionary in ranked.get_offers():
		ranked_ids.append(offer["id"])
	ranked_ids.sort()
	_check(ranked_ids == expected_ids, "rank order does not change the four-hero vital offer set")

	# The fourth hero's authenticated record is offered; the absent Rag Duelist's is not.
	var vigil_id := "v3_lantern_monk_thimble_moon_vigil"
	_check(offered_ids.has(vigil_id), "four-hero gate offers the fourth hero's moon vigil")
	_check(not offered_ids.has("v3_rag_duelist_velvet_straw_mender"),
		"four-hero gate excludes the absent Rag Duelist's record")
	var authored := _by_id(catalog_events, vigil_id)
	_check(not authored.is_empty() and authored.get("required_hero") == "lantern_monk",
		"moon vigil is the shipped Lantern Monk record")
	_check(_by_id(gate.get_offers(), vigil_id) == authored,
		"four-hero offered record equals the authored moon vigil")

	# Living fourth hero admits; Torn and wrong-hero snapshots do not.
	var snap := _vital_state("lantern_monk", 20, 2, 15, 30)
	var visit := gate.enter(vigil_id, snap)
	_check(visit != null and visit.is_valid() and not visit.is_claimed(),
		"living fourth hero opens an unclaimed moon vigil visit")
	_check(gate.enter(vigil_id, _vital_state("lantern_monk", 20, 2, 0, 30)) == null,
		"Torn Lantern Monk (0 HP) is refused admission")
	_check(gate.enter(vigil_id, _vital_state("warden", 20, 2, 15, 30)) == null,
		"wrong-hero snapshot is refused admission")
	_check(gate.enter(vigil_id, _vital_state("scarecrow", 20, 2, 15, 30)) == null,
		"off-party hero snapshot is refused admission")
	if visit == null:
		return

	# The authored trades keep exactly the documented signed outcomes.
	var moonlight := {}
	var tend := {}
	for choice: Dictionary in authored.get("choices", []):
		if choice.get("id") == "moonlight_seam":
			moonlight = choice["outcome"]
		elif choice.get("id") == "tend_moth_candles":
			tend = choice["outcome"]
	_check(moonlight.size() == 4 and int(moonlight.get("gold", 0)) == -16
		and int(moonlight.get("scraps", 0)) == 0 and int(moonlight.get("hp", 0)) == 0
		and int(moonlight.get("max_hp", 0)) == 2,
		"moonlight_seam keeps its exact four signed keys")
	_check(tend.size() == 4 and int(tend.get("gold", 0)) == 20
		and int(tend.get("scraps", 0)) == 0 and int(tend.get("hp", 0)) == -4
		and int(tend.get("max_hp", 0)) == 0,
		"tend_moth_candles keeps its exact four signed keys")

	# Preview and settle the fourth hero's trade once, exactly.
	var expected_state := _vital_state("lantern_monk", 4, 2, 15, 32)
	var snap_copy := snap.duplicate(true)
	var preview := visit.preview_vital_choices(snap)
	_check(preview.get("ok") == true and preview.get("event_id") == vigil_id,
		"four-hero moon vigil previews authentically")
	var quote := {}
	for entry: Dictionary in preview.get("choices", []):
		if entry.get("choice_id") == "moonlight_seam":
			quote = entry
	_check(quote == {"choice_id": "moonlight_seam", "gold_delta": -16, "scraps_delta": 0,
		"hp_delta": 0, "max_hp_delta": 2, "affordable": true, "state": expected_state},
		"moonlight_seam previews gold 20 -> 4, scraps 2, HP 15/max 30 -> 32")
	_check(not visit.is_claimed() and snap == snap_copy,
		"four-hero preview is non-claiming and leaves the snapshot detached")
	var receipt := visit.choose_with_vitals("moonlight_seam", snap)
	_check(receipt == {"ok": true, "event_id": vigil_id, "choice_id": "moonlight_seam",
		"state": expected_state} and snap == snap_copy,
		"moonlight_seam settles once exactly as previewed without mutating the input")
	_check(visit.is_claimed() and not visit.is_valid(), "four-hero claim latches the visit")
	_check(visit.choose_with_vitals("moonlight_seam", expected_state) == {
		"ok": false, "event_id": "", "choice_id": "", "state": expected_state},
		"four-hero replay refuses without a second settlement")
	_check(not visit.choose_with_vitals("leave", expected_state)["ok"],
		"alternate choice is blocked once the four-hero visit is claimed")

