extends SceneTree
## P12 is catalogued and earnable after a completed run, but not yet payable
## or combat-wired. Exercises strict authored data, detached offers and profile.

var checks := 0
var failures: Array[String] = []


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _has(records: Array, id: String, slot: String) -> bool:
	var count := 0
	for record in records:
		if record is Dictionary and record.get("id") == id and record.get("slot") == slot:
			count += 1
	return count == 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var texts := []
	var catalogs := []
	for path in RunAuthoredPatchDefinitions.CATALOG_PATHS:
		var raw := FileAccess.get_file_as_string(path)
		_check(not raw.is_empty(), "catalog exists: " + path)
		texts.append(raw)
		catalogs.append(JSON.parse_string(raw))
	_check(catalogs.size() == RunAuthoredPatchDefinitions.CATALOG_PATHS.size(),
		"nonvacuous full authored catalog")
	var full := RunAuthoredPatchDefinitions.project_catalogs(catalogs)
	var locked := RunAuthoredPatchDefinitions.project_eligible_power_catalogs(catalogs, false)
	var unlocked := RunAuthoredPatchDefinitions.project_eligible_power_catalogs(catalogs, true)
	for spec in [{"id": "needle_echo", "slot": "HEAD"},
			{"id": "shared_hem", "slot": "ARM"}]:
		_check(_has(full, spec.id, spec.slot) and _has(unlocked, spec.id, spec.slot),
			"both real definitions validate and eligible IDs project: " + spec.id)
		_check(not _has(locked, spec.id, spec.slot)
			and not _has(RunAuthoredPatchDefinitions.load_power_definitions(), spec.id, spec.slot),
			"first-run locked candidates never leak: " + spec.id)
	_check(not locked.is_empty() and unlocked.size() == locked.size() + 2,
		"both candidates are additive to existing authored power IDs")
	_check(unlocked == RunAuthoredPatchDefinitions.load_eligible_power_definitions(true)
		and unlocked == RunAuthoredPatchDefinitions.eligible_power_definitions_from_json_texts(texts, true),
		"pure record, JSON and disk eligible projections agree")
	_check(RunAuthoredPatchDefinitions.project_eligible_power_catalogs(catalogs, "true").is_empty(),
		"malformed eligibility refuses before publishing powers")
	var original := catalogs.duplicate(true)
	for index in range(2):
		for field in RunAuthoredPatchDefinitions.HEIRLOOM_REQUIRED[original[8][index].id]:
			var bad := original.duplicate(true)
			bad[8][index].erase(field)
			_check(RunAuthoredPatchDefinitions.project_catalogs(bad).is_empty()
				and RunAuthoredPatchDefinitions.project_eligible_power_catalogs(bad, true).is_empty(),
				"missing authored P12 metadata fails closed: " + field)
	_check(catalogs == original, "negative copies never mutate the shipped catalog")
	var samples := [{"id": "shared_hem", "price": 100},
		{"id": "relay_bobbin", "price": 100},
		{"id": "needle_echo", "price": 100},
		{"id": "stitched_badge", "price": 100}]
	var wallet := {"gold": 250, "deck": ["warden_strike"], "inventory": []}
	var wallet_before := wallet.duplicate(true)
	var candidates_before := samples.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 48125
	var state_before := rng.state
	var gated := RunShopStockOffers.filter_patch_candidates(samples, false)
	var eligible := RunShopStockOffers.filter_patch_candidates(samples, true)
	_check(gated.ok and gated.candidates.size() == 1
		and gated.candidates[0].id == "relay_bobbin",
		"locked pre-draw stock filters both Heirlooms and inert starter")
	_check(eligible.ok and eligible.candidates.size() == 3
		and eligible.candidates.any(func(c): return c.id == "needle_echo")
		and eligible.candidates.any(func(c): return c.id == "shared_hem"),
		"eligible pre-draw projection allows both with unchanged ordinary prices")
	var backwards := samples.duplicate(true)
	backwards.reverse()
	_check(RunShopStockOffers.filter_patch_candidates(backwards, true) == eligible,
		"unlocked candidate projection is order-independent and deterministic")
	eligible.candidates[0].price = 1
	_check(RunShopStockOffers.filter_patch_candidates(samples, true).candidates[0].price == 100,
		"projected candidates are detached from caller and later reads")
	for bad in [null, "not array", [{"id": "needle_echo", "price": -1}],
			[{"id": "needle_echo", "price": 100}, {"id": "needle_echo", "price": 100}],
			[{"id": "needle_echo", "price": 99.5}],
			[{"id": "unknown", "price": 100}]]:
		var rejected := RunShopStockOffers.filter_patch_candidates(bad, true)
		_check(not rejected.ok and rejected.candidates.is_empty(),
			"malformed/stale candidate refuses without partial output")
	_check(not RunShopStockOffers.filter_patch_candidates(samples, 1).ok,
		"invalid eligibility flag fails closed")
	_check(rng.state == state_before and wallet == wallet_before and samples == candidates_before,
		"all projection and refusal paths leave RNG, gold, deck and inventory unchanged")

	# The actual Peddler uses the locked power accessor regardless of the
	# prospective profile: these two IDs cannot yet be bought or worn.
	var party := ["warden", "seamstress", "tinker"]
	var cards := [{"id": "warden_strike", "price": 50},
		{"id": "seamstress_prick", "price": 50},
		{"id": "tinker_pop_shot", "price": 50}]
	var real := RunShopStockOffers.generate_peddler_stock(rng, party, cards, samples, [])
	_check(real.ok and real.patches.size() == 1 and real.patches[0].id == "relay_bobbin",
		"live stock uses already-wired patch even when passed Heirloom candidates")

	# App envelope accepts old two-field records and new versioned records,
	# without adding fields to RunDifficulty itself.
	var app: Variant = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	for _i in range(3):
		await process_frame
	var legacy := {"selected_tier": 0, "highest_cleared_tier": -1}
	_check(app.difficulty_state() == legacy and not app.heirloom_unlocked,
		"fresh mounted app starts with strictly two-field difficulty and locked P12")
	_check(app.restore_profile_state(legacy) and not app.heirloom_unlocked
		and app.difficulty_state() == legacy, "legacy profile restores with locked P12")
	var envelope := {"version": 1, "difficulty": legacy.duplicate(true), "heirloom_unlocked": true}
	_check(app.restore_profile_state(envelope) and app.heirloom_unlocked
		and app.difficulty_state() == legacy, "valid new envelope atomically restores eligibility")
	var before: Dictionary = app.profile_state()
	for bad_profile in [{"version": 2, "difficulty": legacy, "heirloom_unlocked": false},
			{"version": 1, "difficulty": {"selected_tier": 2, "highest_cleared_tier": -1},
				"heirloom_unlocked": false},
			{"version": 1, "difficulty": legacy, "heirloom_unlocked": 1},
			{"version": 1, "difficulty": legacy, "heirloom_unlocked": false, "extra": 1},
			{"selected_tier": 0, "highest_cleared_tier": -1, "heirloom_unlocked": true}]:
		_check(not app.restore_profile_state(bad_profile) and app.profile_state() == before,
			"malformed profile rejects atomically and retains unlock and difficulty")
	app.free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("mpw_heirloom_stitchbox_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
