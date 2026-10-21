extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	seed(99119)
	var global_next := randi()
	seed(99119)
	_negatives()
	_map_projection_negative()
	var map_bound := _map_paid_timeline(true)
	_check(map_bound == _map_paid_timeline(true), "independent bound map choice timelines replay")
	var map_unbound := _map_paid_timeline(false)
	_check(map_unbound == _map_paid_timeline(false), "independent unbound map choice timelines replay")
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



func _map_args(f: Dictionary, option: Variant, node: String = "map_new",
		receipt: String = "choice_new") -> Array:
	return [option, node, receipt, f.carry.read_state(),
		null if f.wardrobe == null else f.wardrobe.get_snapshot(),
		f.scraps, true]


func _map_select(f: Dictionary, args: Array) -> Dictionary:
	return RunMapMendChoices.choose(f.carry, args[0], args[1], args[2],
		args[3], args[4], args[5], args[6])


func _map_view(f: Dictionary, scraps: Variant = null, between: Variant = true) -> Dictionary:
	return RunMapMendChoices.project(f.carry, f.carry.read_state(),
		null if f.wardrobe == null else f.wardrobe.get_snapshot(),
		f.scraps if scraps == null else scraps, between)


func _map_reject(f: Dictionary, args: Array, label: String) -> void:
	var before := _snapshot(f)
	var result := _map_select(f, args)
	_check(result == {"ok": false, "heroes": [], "remaining_scraps": args[5]},
		label + " refuses transaction without claiming payment")
	_check(_snapshot(f) == before,
		label + " preserves both ledgers, receipts, purse, gold, deck and RNG")


func _map_projection_negative() -> void:
	var f := _fixture()
	var untouched := _snapshot(f)
	_check(_map_view(f) == {"ok": true, "options": []},
		"healthy authentic roster has zero Mend options")
	_check(_snapshot(f) == untouched, "healthy projection is read-only")
	var no_tear := _map_args(f, {"hero_id": "warden", "position": 1,
		"base_max_hp": 40, "cost": 2, "post_mend_hp": 10, "affordable": true})
	_map_reject(f, no_tear, "fabricated initial Mend")

	_win(f, "map_prior", true, true)
	var good := _map_view(f)
	_check(good.ok and good.options.size() == 2 and good.options[0].affordable,
		"real settled Elite permits actual torn choices")
	untouched = _snapshot(f)
	for context in [false, "true", 1, null]:
		_check(not _map_view(f, null, context).ok and _map_view(f, null, context).options == [],
			"invalid non-map context never projects: " + str(context))
	for purse in [-1, 2.5, true, 1]:
		var view := _map_view(f, purse)
		_check(not view.ok and view.options.is_empty(),
			"invalid/mismatched bound purse cannot forge map choices: " + str(purse))
	var stale: Dictionary = f.carry.read_state()
	stale.heroes[0].statuses = {"weak": 99}
	_check(not RunMapMendChoices.project(f.carry, stale, f.wardrobe.get_snapshot(),
		f.scraps, true).ok, "stale carryover snapshot cannot project")
	var drift: Dictionary = f.wardrobe.get_snapshot()
	drift.worn.tinker.HEAD = ""
	_check(not RunMapMendChoices.project(f.carry, f.carry.read_state(), drift,
		f.scraps, true).ok, "forged wardrobe receipt cannot project")
	_check(_snapshot(f) == untouched, "all invalid projections leave original receipts and RNG untouched")

	var old := _map_args(f, good.options[0])
	_check(f.wardrobe.start_rest("map_rest", f.wardrobe.get_snapshot()).ok,
		"genuine Rest opens before map presentation")
	_check(not _map_view(f).ok, "Rest-open wardrobe suppresses Mend options")
	_map_reject(f, _map_args(f, good.options[0]), "Rest-open adapter")
	_check(f.wardrobe.end_rest("map_rest", f.wardrobe.get_snapshot()).ok,
		"Rest closes without spending or mending")
	_map_reject(f, old, "stale pre-Rest wardrobe receipt")

	var unclaimed := _fixture(false)
	_win(unclaimed, "map_claimed")
	_win(unclaimed, "map_unclaimed", false)
	_check(not _map_view(unclaimed).ok, "committed but unclaimed battle is not a map")
	_map_reject(unclaimed, _map_args(unclaimed, {"hero_id": "tinker", "position": 3,
		"base_max_hp": 23, "cost": 2, "post_mend_hp": 5, "affordable": true}),
		"unclaimed adapter")
	var active := _fixture(false)
	_win(active, "map_first")
	var combat: CombatParty = active.carry.create_next_fight_party()
	var enemies := CombatEnemies.new([{"id": "dummy", "max_hp": 8}])
	_check(combat != null and active.carry.begin_battle(
		"map_live", CombatBattleResult.new(combat, enemies), combat),
		"real active battle exists for map rejection")
	_check(not _map_view(active).ok, "active battle excludes map Mend choices")
	_map_reject(active, _map_args(active, {"hero_id": "tinker", "position": 3,
		"base_max_hp": 23, "cost": 2, "post_mend_hp": 5, "affordable": true}),
		"active-battle adapter")

	var terminal := _fixture(false)
	var t: RunTornMending = terminal.carry.torn
	var before: Array = t.read_state().heroes
	var down: Array = before.duplicate(true)
	for hero in down:
		hero.hp = 0
	_check(t.observe_battle_end("lost_battle", before, down).ok and t.read_state().defeated,
		"real torn ledger terminal defeat precondition")
	_check(not _map_view(terminal).ok, "defeated run cannot project actionable Mend")
	_check(_map_view(terminal).options.is_empty(), "defeated projection never returns choices")


func _map_paid_timeline(bound: bool) -> Array:
	var f := _fixture(bound)
	var history := []
	_win(f, "map_fight", true, false, true)
	var first := _map_view(f)
	_check(f.scraps == 1 and first.ok and first.options.size() == 2,
		"genuine swapped Fight earns one scrap with two actual torn actors")
	_check(first.options[0] == {"hero_id": "warden", "position": 2,
		"base_max_hp": 37, "cost": 2, "post_mend_hp": 9, "affordable": false}
		and first.options[1] == {"hero_id": "tinker", "position": 3,
		"base_max_hp": 23, "cost": 2, "post_mend_hp": 5, "affordable": false},
		"swapped Warden at position two has 37 max / 9 Mend HP and disabled 1-scrap choice")
	var zero := _fixture(false)
	_win(zero, "map_zero", true, false, true)
	var zero_view := _map_view(zero, 0)
	_check(zero_view.ok and zero_view.options.size() == 2
		and not zero_view.options[0].affordable and not zero_view.options[1].affordable,
		"unbound 0 scraps shows genuine disabled options")
	_map_reject(f, _map_args(f, first.options[0], "low_node", "low_receipt"),
		"1 scrap disabled selection")
	var zero_args := _map_args(zero, zero_view.options[0], "zero_node", "zero_receipt")
	zero_args[5] = 0
	_map_reject(zero, zero_args, "0 scraps disabled selection")
	if bound:
		_check(f.wardrobe.project_active(f.carry.torn.read_state()).active.tinker == [],
			"genuine sewn patch is inactive on torn wearer before a paid Mend")
	_win(f, "map_elite_a", true, true)
	_win(f, "map_elite_b", true, true)
	var prior := _snapshot(f)
	var projected := _map_view(f)
	_check(f.scraps == 5 and projected.ok and projected.options.size() == 2
		and projected.options[0].affordable and projected.options[1].affordable,
		"settled Fight plus two Elites leave exactly five scraps and both choices enabled")
	_check(projected.options[0].hero_id == "warden" and projected.options[0].position == 2
		and projected.options[1].hero_id == "tinker",
		"line order derives from current true slots after combat swap")
	var independent := _map_view(f)
	projected.options[0].post_mend_hp = 999
	projected.options[0].hero_id = "seamstress"
	projected.options.clear()
	_check(_map_view(f) == independent and _snapshot(f) == prior,
		"returned projection is detached and no hidden currency or RNG changed")

	var warden: Dictionary = independent.options[0]
	var tinker: Dictionary = independent.options[1]
	var bogus := warden.duplicate(true)
	bogus.cost = 1
	_map_reject(f, _map_args(f, bogus), "forged cheaper price")
	bogus = warden.duplicate(true)
	bogus.position = 1
	_map_reject(f, _map_args(f, bogus), "forged old Warden slot")
	bogus = warden.duplicate(true)
	bogus.post_mend_hp = 10
	_map_reject(f, _map_args(f, bogus), "forged healing amount")
	var stale := _map_args(f, tinker)
	stale[3].heroes[1].statuses.weak = 100
	_map_reject(f, stale, "stale hero snapshot")
	if bound:
		stale = _map_args(f, tinker)
		stale[4].receipt = "forged"
		_map_reject(f, stale, "stale wardrobe receipt")
	var nonmap := _map_args(f, tinker)
	nonmap[6] = false
	_map_reject(f, nonmap, "non-map selection")
	var warden_before := _map_args(f, warden)
	var snapshot: Dictionary = f.carry.read_state()
	var expected: Array = snapshot.heroes.duplicate(true)
	expected[2].hp = 5
	var result := _map_select(f, _map_args(f, tinker, "map_tinker", "mend_tinker"))
	_check(result.ok and result.heroes == expected and result.remaining_scraps == 3,
		"real delegated Tinker Mend spends exactly two and only changes torn wearer's HP")
	f.scraps = result.remaining_scraps
	_check(f.carry.read_state().heroes == expected and f.carry.torn.read_state().completed_mends.has("mend_tinker"),
		"successful receipt published by authoritative torn ledger")
	if bound:
		_check(f.wardrobe.get_snapshot().scraps == 3 and f.wardrobe.get_snapshot().heroes == expected
			and f.wardrobe.project_active(f.carry.torn.read_state()).active.tinker == ["stitched_badge"],
			"actual bound wardrobe spends once and reactivates Tinker's sewn HEAD patch")
		for key in ["owned", "worn", "definitions", "gold", "cards", "seed", "rest_id", "rest_ids", "operation_ids"]:
			_check(f.wardrobe.get_snapshot()[key] == prior[4][key],
				"paid Mend preserves wardrobe " + key)
	_check(f.gold == prior[6] and f.deck == prior[7] and f.rewards == prior[8]
		and f.rng.state == prior[9], "Mend does not touch gold, deck, rewards or RNG")
	_map_reject(f, _map_args(f, _map_view(f).options[0], "map_tinker", "other_receipt"),
		"reused map node")
	_map_reject(f, _map_args(f, _map_view(f).options[0], "another_map", "mend_tinker"),
		"reused Mend receipt")
	_map_reject(f, warden_before, "stale affordable option with changed wallet")
	var next := _map_view(f)
	_check(next.ok and next.options.size() == 1 and next.options[0].hero_id == "warden"
		and next.options[0].position == 2 and next.options[0].post_mend_hp == 9
		and next.options[0].affordable, "fresh projection retains only moved Warden with true remaining purse")
	var after_tinker: Array = f.carry.read_state().heroes
	after_tinker[1].hp = 9
	var mend_warden := _map_select(f, _map_args(f, next.options[0], "map_warden", "mend_warden"))
	_check(mend_warden.ok and mend_warden.heroes == after_tinker
		and mend_warden.remaining_scraps == 1, "Warden mends in swapped slot for exact 9 HP, 2 scraps")
	f.scraps = mend_warden.remaining_scraps
	_check(f.carry.create_next_fight_party().get_heroes() == after_tinker,
		"future party hydration preserves current positions, metadata, statuses and both repairs")
	_check(_map_view(f) == {"ok": true, "options": []},
		"fully recovered party projects no Mend option")
	mend_warden.heroes[1].statuses.clear()
	_check(f.carry.read_state().heroes == after_tinker, "delegated response is deeply detached")
	history.append(_snapshot(f))
	history.append(after_tinker)
	return history
