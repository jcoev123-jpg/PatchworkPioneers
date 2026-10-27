extends SceneTree

const PARTY_A := ["warden", "seamstress", "tinker"]
const PARTY_B := ["lantern_monk", "rag_duelist", "tinker"]
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
	_test_invalid_parties()
	_test_invalid_catalogs()
	_test_isolation()
	_check(_replay(257) == _replay(257), "whole offer/entry/receipt sequence replays exactly")
	_check(catalog == before, "all operations preserve authored catalog")
	_check(run_rng.state == state and randi() == expected_global, "all paths consume neither seeded nor global RNG")
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


func _test_invalid_parties() -> void:
	for party in [null, {}, "warden", [], ["warden"], ["warden", "seamstress"],
		["warden", "seamstress", "tinker", "scarecrow"], ["warden", "warden", "tinker"],
		["warden", "unknown", "tinker"], ["warden", "", "tinker"],
		["warden", 1, "tinker"], ["warden", null, "tinker"], ["Warden", "seamstress", "tinker"]]:
		var service := RunV3HeroEventOffers.new(party)
		_check(not service.is_valid() and service.get_offers().is_empty()
			and service.enter("v3_warden_shield_menders") == null, "invalid party fails closed: " + str(party))


func _reject_catalog(source: Variant) -> void:
	var before: Variant = source.duplicate(true) if source is Dictionary or source is Array else source
	var service := RunV3HeroEventOffers.new(PARTY_A, source)
	_check(not service.is_valid() and service.get_offers().is_empty()
		and service.enter("v3_warden_shield_menders") == null, "malformed catalog wholly denied: " + str(source))
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
