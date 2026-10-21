extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	seed(99119)
	var global_next := randi()
	seed(99119)
	_negatives()
	var first := _timeline(true)
	_check(first == _timeline(true), "two independent seeded bound timelines replay exactly")
	var unbound := _timeline(false)
	_check(unbound == _timeline(false), "two independent seeded unbound timelines replay exactly")
	_check(randi() == global_next, "same global RNG stream never consumed")
	for failure in failures:
		printerr(failure)
	print("run_torn_carryover_mend_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _fixture(bound: bool = true) -> Dictionary:
	var defs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	for hero in defs:
		hero.max_hp = int(hero.max_hp)
	var party := CombatParty.new(defs)
	_check(party.is_valid(), "authored party valid")
	var carry := RunTornCarryover.new(party.get_heroes())
	var rng := RandomNumberGenerator.new()
	rng.seed = 99117
	var wardrobe: RunPatchWardrobe
	if bound:
		wardrobe = RunPatchWardrobe.new(party.get_heroes(), ["stitched_badge", "spare_spool"],
			JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/initial_patch_slots.json")),
			0, 10, ["warden_strike"], 99117)
		_check(wardrobe.is_valid() and wardrobe.sew("stitched_badge", "tinker", "HEAD", "sew", wardrobe.get_snapshot()).ok,
			"owned patch genuinely sewn before tear")
		_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()), "wardrobe binds authentic initial mender")
	return {"carry": carry, "wardrobe": wardrobe, "rng": rng, "scraps": 0, "gold": 10,
		"deck": ["warden_strike"], "rewards": []}


func _win(f: Dictionary, node: String, settle: bool = true, elite: bool = true, swap: bool = false) -> void:
	var c: RunTornCarryover = f.carry
	var party := c.create_next_fight_party()
	_check(party != null and party.is_valid(), "next real CombatParty exists before " + node)
	if party == null:
		return
	var enemies := CombatEnemies.new([{"id": "dummy", "max_hp": 8}])
	var result := CombatBattleResult.new(party, enemies)
	_check(result.get_outcome() == CombatBattleResult.ACTIVE and c.begin_battle(node, result, party), "witness ACTIVE battle")
	if swap:
		var moved := CombatPositionSwaps.preview_adjacent_swap(party, 1, 1)
		_check(moved.ok, "real movement API supplies changed formation")
		party._heroes.assign(moved.heroes)
	for hero in party.get_heroes():
		if hero.id in ["tinker", "warden"]:
			party._heroes[hero.position - 1].statuses = {"weak": 2, "bleed": 1}
			if hero.hp > 0:
				_check(party.apply_damage(hero.position, 999), "real damage tears selected heroes")
	_check(enemies.apply_damage(1, 999) and result.evaluate() == CombatBattleResult.VICTORY, "actual evaluated surviving victory")
	if not settle:
		_check(c.commit_victory(node, result, party).ok, "unclaimed fixture commits only victory")
		return
	var reward := RunFightVictoryRewards.new(result, f.rng, ["warden", "seamstress", "tinker"],
		["warden_strike", "seamstress_prick", "tinker_pop_shot"], f.deck, f.gold, elite,
		["stitched_badge", "spare_spool"], [])
	_check(reward.prepare().ok, "genuine seeded reward prepared")
	var paid := reward.choose("")
	_check(paid.ok and c.commit_victory(node, result, party).ok and c.apply_reward(node, result, party).ok,
		"reward claimed and witnessed tear published")
	f.gold = paid.gold
	f.deck = paid.deck
	f.rewards.append(paid)
	# Future run-owner purse fixture: award only after the real reward settles.
	# Production mending never awards this currency.
	f.scraps += 2 if elite else 1
	if f.wardrobe != null:
		var w: RunPatchWardrobe = f.wardrobe
		var old := w.get_snapshot()
		_check(w.refresh_run_context(c.read_state().heroes, old.owned, f.scraps, f.gold, f.deck, old), "owner synchronizes settled wallet")


func _args(f: Dictionary, node: String = "map", receipt: String = "mend") -> Array:
	var c: RunTornCarryover = f.carry
	var heroes: Array = c.read_state().heroes
	var position := 0
	for hero in heroes:
		if hero.id == "tinker":
			position = hero.position
	return [node, receipt, "tinker", position, f.scraps, c.read_state(),
		null if f.wardrobe == null else f.wardrobe.get_snapshot(), true]


func _snapshot(f: Dictionary) -> Array:
	var c: RunTornCarryover = f.carry
	return [c.read_state(), c.torn.read_state(), c._receipts.duplicate(true), c._max_hp_by_id.duplicate(true),
		null if f.wardrobe == null else f.wardrobe.get_snapshot(), f.scraps, f.gold,
		f.deck.duplicate(true), f.rewards.duplicate(true), f.rng.state]


func _reject(f: Dictionary, args: Array, label: String) -> void:
	var before := _snapshot(f)
	var result: Dictionary = f.carry.callv("choose_mend", args)
	_check(result == {"ok": false, "heroes": [], "remaining_scraps": args[4]}, label + " rejects")
	_check(_snapshot(f) == before, label + " preserves full ledgers wallet patches receipts and RNG")


func _negatives() -> void:
	var f := _fixture()
	_win(f, "paid")
	_check(f.carry.read_state().heroes[2].hp == 0 and f.scraps == 2, "negative fixture has witnessed tear and earned cost")
	for entry in [[0, "paid"], [0, ""], [1, ""], [2, "foreign"], [2, "seamstress"],
		[2, 3], [3, 1], [3, 0], [3, 3.0], [4, 1], [4, -1], [4, 2.5], [4, 4],
		[5, {}], [6, {}], [7, false], [7, 1]]:
		var args := _args(f)
		args[entry[0]] = entry[1]
		_reject(f, args, "invalid argument " + str(entry))
	var args := _args(f)
	args[2] = "seamstress"
	args[3] = 2
	_reject(f, args, "correct slot living hero")
	args = _args(f)
	args[5].heroes[2].statuses.weak += 1
	_reject(f, args, "stale roster")
	args = _args(f)
	args[6].worn.tinker.HEAD = ""
	_reject(f, args, "forged wardrobe assignments")
	var w: RunPatchWardrobe = f.wardrobe
	args = _args(f)
	_check(w.sew("spare_spool", "seamstress", "ARM", "later", w.get_snapshot()).ok, "real wardrobe advances snapshot")
	_reject(f, args, "stale authentic wardrobe")
	_check(w.start_rest("rest_open", w.get_snapshot()).ok, "real Rest context opens")
	_reject(f, _args(f), "Rest is not map")
	_check(w.end_rest("rest_open", w.get_snapshot()).ok, "real Rest closes")
	var stale := _args(f)
	var mended: Dictionary = f.carry.callv("choose_mend", stale)
	_check(mended.ok, "fresh mend succeeds after all failures")
	f.scraps = mended.remaining_scraps
	_reject(f, stale, "replayed original snapshots")
	_reject(f, _args(f), "reused node and receipt with fresh snapshots")
	_check(f.carry.choose_rest_heal("rest_after").ok, "Rest replays mend receipt")
	_win(f, "later_paid")
	_reject(f, _args(f, "fresh_map", "mend"), "old receipt with new torn hero and funds")
	_reject(f, _args(f, "map", "new_receipt"), "old node with new receipt and funds")
	var unclaimed := _fixture()
	_win(unclaimed, "prior_claim")
	_win(unclaimed, "unclaimed", false)
	_reject(unclaimed, _args(unclaimed), "unclaimed committed battle")
	var active := _fixture()
	_win(active, "earlier_paid")
	var p: CombatParty = active.carry.create_next_fight_party()
	var enemies := CombatEnemies.new([{"id": "dummy", "max_hp": 8}])
	_check(active.carry.begin_battle("active", CombatBattleResult.new(p, enemies), p), "active next battle admitted")
	_reject(active, _args(active), "active battle despite caller map flag")
	var drift := _fixture()
	_win(drift, "drift_paid")
	var old: Dictionary = drift.wardrobe.get_snapshot()
	var wrong: Array = old.heroes.duplicate(true)
	wrong[0].hp = 1
	_check(drift.wardrobe.refresh_run_context(wrong, old.owned, old.scraps, old.gold, old.cards, old), "real wardrobe holds mismatched roster")
	_reject(drift, _args(drift), "fresh wardrobe snapshot with stale roster")
	var unbound := _fixture(false)
	_win(unbound, "unbound_paid", true, true, true)
	for scraps in [-1, 0, 1, 2.5, true]:
		args = _args(unbound)
		args[4] = scraps
		_reject(unbound, args, "unbound invalid caller purse " + str(scraps))
	args = _args(unbound)
	args[6] = {}
	_reject(unbound, args, "wardrobe snapshot without bound owner")
	args = _args(unbound)
	args[2] = "warden"
	args[3] = 2
	var expected: Array = unbound.carry.read_state().heroes
	expected[1].hp = 9
	var selected: Dictionary = unbound.carry.callv("choose_mend", args)
	_check(selected.ok and selected.heroes == expected and selected.remaining_scraps == 0
		and unbound.carry.create_next_fight_party().get_heroes() == expected,
		"different selected hero mends in moved slot with floor(37/4), leaving Tinker torn")


func _timeline(bound: bool) -> Array:
	var f := _fixture(bound)
	var history := []
	for cycle in range(8):
		_win(f, "fight_%d" % cycle, true, cycle != 0, cycle == 0)
		if cycle == 0:
			# Two ordinary paid Fights earn the first two scraps; already torn
			# actors incur no additional seam during the second battle.
			_win(f, "second_fight", true, false)
		var c: RunTornCarryover = f.carry
		var before := _snapshot(f)
		var prior := c.read_state()
		var expected: Array = prior.heroes.duplicate(true)
		var cap: int = maxi(10, 26 - 3 * (cycle + 1))
		_check(expected[2].id == "tinker" and expected[2].hp == 0 and expected[2].max_hp == cap,
			"genuine repeated tears reach floor ten")
		if bound:
			_check(f.wardrobe.project_active(c.torn.read_state()).active.tinker == [], "torn patch is suspended")
		expected[2].hp = maxi(1, floori(cap / 4.0))
		var result: Dictionary = c.callv("choose_mend", _args(f, "map_%d" % cycle, "mend_%d" % cycle))
		_check(result.ok and result.heroes == expected and result.remaining_scraps == f.scraps - 2,
			"one selected hero restored with exact floor HP and one spend; other heroes slots statuses unchanged")
		f.scraps = result.remaining_scraps
		_check(c.read_state().heroes == expected and c.read_state().completed_fights == prior.completed_fights
			and c.read_state().completed_rests == prior.completed_rests, "mend awards no battle or Rest")
		_check(f.gold == before[6] and f.deck == before[7] and f.rewards == before[8] and f.rng.state == before[9],
			"no gold deck reward or RNG changes")
		if bound:
			var w: RunPatchWardrobe = f.wardrobe
			var after := w.get_snapshot()
			_check(after.heroes == expected and after.scraps == f.scraps
				and w.project_active(c.torn.read_state()).active.tinker == ["stitched_badge"], "wardrobe commits heroes purse and reactivates patch")
			for key in ["worn", "owned", "definitions", "gold", "cards", "seed", "rest_id", "rest_ids", "operation_ids"]:
				_check(after[key] == before[4][key], "wardrobe preserves " + key)
		var next := c.create_next_fight_party()
		_check(next != null and next.is_valid() and next.get_heroes() == expected, "public next-party hydration reconstructs all fields after mend")
		result.heroes[2].statuses.clear()
		result.heroes[2].hp = 0
		_check(c.read_state().heroes == expected and next.get_heroes() == expected, "returned mend heroes detached from carry and party")
		history.append(_snapshot(f))
		history.append(next.get_heroes())
		if cycle == 3:
			_check(c.choose_rest_heal("middle_rest").ok and c.create_next_fight_party() != null,
				"mixed battle mend and Rest replay stays admissible")
	return history
