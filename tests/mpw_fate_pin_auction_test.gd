extends SceneTree
var failures: Array[String] = []
var checks := 0

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _wardrobe(hp: int = 40, gold: int = 65, owned: Array = []) -> RunPatchWardrobe:
	var heroes := CombatParty.new([{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}]).get_heroes()
	heroes[0].hp = hp
	return RunPatchWardrobe.new(heroes, owned, RunAuthoredPatchDefinitions.load_definitions(), 0, gold, ["warden_strike"], 343, true)

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 343
	var w := _wardrobe(5)
	_check(w.is_valid(), "real current-run wardrobe")
	var state := rng.state
	var auction := RunFatePinAuction.new(w, rng)
	_check(auction.is_valid(), "authored auction is valid")
	if not auction.is_valid():
		_finish()
		return
	var offers := auction.get_offers()
	_check(offers.size() == 2 and offers[0].id != offers[1].id, "two distinct offers")
	var oracle := RandomNumberGenerator.new()
	oracle.state = state
	var pool := RunFatePinAuction.ordinary_definitions()
	pool.sort_custom(func(a, b): return a.id < b.id)
	var expected: Array = []
	for i in range(2):
		expected.append(pool.pop_at(oracle.randi_range(0, pool.size() - 1)))
	_check(offers == expected and rng.state == oracle.state, "sorted canonical power draw oracle and exact RNG")
	oracle.state = state
	var replay := RunFatePinAuction.new(_wardrobe(5), oracle)
	_check(replay.get_offers() == offers and oracle.state == rng.state, "same seed inventory replay")
	var snapshot := w.get_snapshot()
	var stable_rng := rng.state
	for invalid in [["unknown", "warden", offers[0].slot], ["patch_0", "foreign", offers[0].slot],
		["patch_0", "warden", "FOOT"], ["patch_0", "warden", "ARM" if offers[0].slot != "ARM" else "HEAD"]]:
		_check(not auction.prepare(w, invalid[0], invalid[1], invalid[2], snapshot).ok, "invalid proposal rejects")
		_check(w.get_snapshot() == snapshot and rng.state == stable_rng and auction.is_valid(), "reject preserves all ledgers RNG and claim")
	var stale := snapshot.duplicate(true)
	stale.gold += 1
	_check(not auction.prepare(w, "patch_0", "warden", offers[0].slot, stale).ok, "stale snapshot rejects")
	var paid := auction.prepare(w, "patch_0", "warden", offers[0].slot, snapshot)
	_check(paid.ok and w.get_snapshot() == snapshot, "payment stages detached")
	_check(paid.state.heroes[0].hp == 1 and paid.state.gold == 0 and paid.state.scraps == 0, "5 HP 65 gold boundary exact")
	_check(paid.state.worn.warden[offers[0].slot] == offers[0].id and paid.state.owned == [offers[0].id], "one canonical sewn power")
	var forged := paid.duplicate(true)
	forged.state.gold = 1
	_check(not auction.commit(w, forged) and w.get_snapshot() == snapshot, "forged receipt atomic rejection")
	_check(auction.commit(w, paid), "commit paid receipt")
	_check(not auction.commit(w, paid) and not RunFatePinAuction.new(w, rng).is_valid(), "second claim and persisted operation reject")
	_check(rng.state == stable_rng, "claims and refusals consume no draws")
	for hp in [0, 4, 5]:
		for gold in [64, 65]:
			var bad := _wardrobe(hp, gold)
			var a := RunFatePinAuction.new(bad, rng)
			var before := bad.get_snapshot()
			var before_rng := rng.state
			var result := a.prepare(bad, "patch_0", "warden", a.get_offers()[0].slot, before)
			_check(result.ok == (hp >= 5 and gold >= 65), "payer HP and wallet boundaries")
			_check(before == bad.get_snapshot() and before_rng == rng.state, "boundary proposal is read-only")
	var safe_w := _wardrobe(0, 0)
	var safe := RunFatePinAuction.new(safe_w, rng)
	var safe_before := safe_w.get_snapshot()
	var exit := safe.prepare(safe_w, "safe_exit", "", "", safe_before)
	_check(exit.ok and safe.commit(safe_w, exit), "safe exit without eligible payer or money")
	_check(safe_w.get_snapshot().heroes == safe_before.heroes and safe_w.get_snapshot().gold == 0 \
		and safe_w.get_snapshot().scraps == 1 and safe_w.get_snapshot().owned.is_empty(), "safe exactly one scrap no cost")
	var powers := RunFatePinAuction.ordinary_definitions()
	var owned: Array = []
	for d in powers:
		owned.append(d.id)
	var insufficient := _wardrobe(40, 65, owned)
	state = rng.state
	_check(not RunFatePinAuction.new(insufficient, rng).is_valid() and rng.state == state, "insufficient offers rejects before draw")
	owned.pop_back()
	_check(not RunFatePinAuction.new(_wardrobe(40, 65, owned), rng).is_valid() and rng.state == state, "one offer insufficient before draw")
	# Equip one ordinary same-slot patch, then buy a different, offered patch.
	var replacement := _wardrobe()
	var first: Dictionary = powers[0]
	replacement.refresh_run_context(replacement.get_snapshot().heroes, [first.id], 0, 65, ["warden_strike"], replacement.get_snapshot())
	_check(replacement.sew(first.id, "warden", first.slot, "initial_sew", replacement.get_snapshot()).ok, "replacement precondition sewn")
	var found := false
	for seed_value in range(100):
		rng.seed = seed_value
		var a := RunFatePinAuction.new(replacement, rng)
		for i in range(2):
			if a.get_offers()[i].slot == first.slot:
				var result := a.prepare(replacement, "patch_%d" % i, "warden", first.slot, replacement.get_snapshot())
				_check(result.ok and result.sewing.displaced_id == first.id and result.sewing.scrap_delta == 1, "normal replacement receipt")
				_check(a.commit(replacement, result) and replacement.get_snapshot().scraps == 1 \
					and not replacement.get_snapshot().owned.has(first.id), "displaced patch destroyed for precisely one scrap")
				found = true
				break
		if found:
			break
	_check(found, "replacement exercised")
	_finish()

func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("mpw_fate_pin_auction_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
