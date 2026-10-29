extends SceneTree

const PARTY_A := ["warden", "seamstress", "tinker"]
const PARTY_B := ["lantern_monk", "rag_duelist", "tinker"]
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
	_test_invalid_catalogs()
	_test_isolation()
	_test_actionable_named_examples()
	_test_actionable_party_and_sorted_sampling()
	_test_actionable_exclusions_and_exhaustion()
	_test_actionable_invalid_inputs_and_isolation()
	_check(_replay(257) == _replay(257), "whole offer/entry/receipt sequence replays exactly")
	_check(_replay_actionable(257) == _replay_actionable(257), "seeded actionable selection and settlement sequence replays exactly")
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
	for party in [null, {}, "warden", [], ["warden"], ["warden", "seamstress"],
		["warden", "seamstress", "tinker", "scarecrow"], ["warden", "warden", "tinker"],
		["warden", "unknown", "tinker"], ["warden", "", "tinker"],
		["warden", 1, "tinker"], ["warden", null, "tinker"], ["Warden", "seamstress", "tinker"]]:
		var service := RunV3HeroEventOffers.new(party)
		var rng := RandomNumberGenerator.new()
		rng.seed = 409
		var state := rng.state
		_check(not service.is_valid() and service.get_offers().is_empty()
			and service.enter("v3_warden_shield_menders") == null
			and service.select_actionable_event(rng, [], {"gold": 30, "scraps": 3}) == {"ok": false, "event": {}}
			and rng.state == state, "invalid party fails closed: " + str(party))


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
