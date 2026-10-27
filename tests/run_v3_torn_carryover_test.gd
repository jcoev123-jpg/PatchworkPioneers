extends SceneTree
## Scene-free proof that run carryover admits any canonical trio of the eight
## authored heroes, anchored to the original held trio. Oracles are read here
## from the shipped hero JSON, independently of RunV3PartyAdmission.

const LINEUP_A := ["yarn_ranger", "lantern_monk", "button_golem"]
const LINEUP_B := ["scarecrow", "tinker", "rag_duelist"]
const TEAR_LOSS := 3
const MIN_MAX_HP := 10

var failures: Array[String] = []
var checks := 0
var authored := {}


func _initialize() -> void:
	seed(32401)
	var global_next := randi()
	seed(32401)
	authored = _authored()
	_check(not authored.is_empty(), "independent authored hero oracle loads")
	var summaries: Array = []
	for picks in [LINEUP_A, LINEUP_B]:
		var first := _lineup(picks)
		_check(not first.is_empty() and first == _lineup(picks), "lineup %s replays exactly" % str(picks))
		summaries.append(first)
	_check(summaries.size() == 2 and summaries[0] != summaries[1], "two distinct nondefault lineups differ")
	_test_ties()
	_test_base_carryover()
	_test_rejections()
	_test_legacy_trio()
	_check(randi() == global_next, "same global RNG stream never consumed")
	for failure in failures:
		printerr(failure)
	print("run_v3_torn_carryover_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


## {id: {"max_hp", "position", "passive"}} from the shipped JSON. Legacy heroes
## take positions from starter_party.json array order and carry no passive.
func _authored() -> Dictionary:
	var records := {}
	var legacy: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/starter_party.json"))
	var v3: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes/v3_party_roster.json"))
	if not legacy is Array or not v3 is Array:
		return {}
	for index in range(legacy.size()):
		records[legacy[index].id] = {"max_hp": int(legacy[index].max_hp), "position": index + 1, "passive": null}
	for hero in v3:
		records[hero.id] = {"max_hp": int(hero.max_hp), "position": int(hero.default_position),
			"passive": hero.passive}
	return records


## Stable default-position order: ties keep pick order.
func _expected_order(picks: Array) -> Array:
	var order: Array = []
	for id in picks:
		var at := order.size()
		while at > 0 and authored[order[at - 1]].position > authored[id].position:
			at -= 1
		order.insert(at, id)
	return order


func _initial(picks: Array) -> Array:
	var receipt := RunV3PartyAdmission.admit(picks)
	_check(receipt.get("ok") == true, "canonical admission accepts %s" % str(picks))
	var party := CombatParty.new(receipt.get("party", []))
	_check(party.is_valid(), "admitted definitions build a valid CombatParty")
	return party.get_heroes() if party.is_valid() else []


func _check_heroes(heroes: Array, order: Array, label: String) -> void:
	_check(heroes.size() == order.size(), label + " holds exactly three heroes")
	if heroes.size() != order.size():
		return
	for index in range(order.size()):
		var hero: Dictionary = heroes[index]
		var record: Dictionary = authored[order[index]]
		_check(hero.get("id") == order[index] and hero.get("position") == index + 1,
			label + " keeps exact ID and ordered position %d" % (index + 1))
		_check(hero.get("block") == 0, label + " carries no Block at slot %d" % (index + 1))
		if record.passive == null:
			_check(not hero.has("passive"), label + " legacy hero carries no invented passive")
		else:
			_check(hero.get("passive") == record.passive, label + " retains authored passive of " + order[index])


func _reject_snapshot(carry: RunTornCarryover) -> Array:
	return [carry.read_state(), carry.torn.read_state(), carry._receipts.duplicate(true),
		carry._max_hp_by_id.duplicate(true), carry._fight_ids.duplicate()]


## Full transaction for one nondefault lineup. Returns a replay summary.
func _lineup(picks: Array) -> Array:
	var order := _expected_order(picks)
	_check(order != picks, "lineup %s is supplied out of canonical order" % str(picks))
	var initial := _initial(picks)
	if initial.is_empty():
		return []
	_check_heroes(initial, order, "initial snapshot")
	for index in range(initial.size()):
		_check(initial[index].hp == authored[order[index]].max_hp and initial[index].max_hp == initial[index].hp,
			"initial %s at full authored HP" % order[index])
	var request := initial.duplicate(true)
	var carry := RunTornCarryover.new(initial)
	_check(carry.is_valid() and carry.torn.is_valid(), "RunTornCarryover admits canonical %s" % str(order))
	_check(initial == request, "construction leaves the caller roster unchanged")
	if not carry.is_valid():
		return []
	# Detachment: caller roster, read snapshots and hydrated parties never reach the ledger.
	var held := carry.read_state()
	initial[0].max_hp = 99
	initial[0].hp = 99
	held.heroes[1].hp = 1
	var hydrated := carry.create_next_fight_party()
	_check(hydrated != null and hydrated.is_valid(), "initial carry hydrates a CombatParty")
	if hydrated == null:
		return []
	_check(hydrated.get_heroes() == request, "hydrated party equals the original admitted trio")
	_check_heroes(hydrated.get_heroes(), order, "hydrated party")
	hydrated._heroes[2].hp = 1
	hydrated._heroes[0].passive = {}
	var again := carry.create_next_fight_party()
	_check(again != null and again.get_heroes() == request and carry.read_state().heroes == request,
		"mutated caller, snapshot and hydrated party never alter later hydration")
	# The torn hero is the newly chosen V3 hero in the last V3 slot.
	var torn_id := ""
	for id in order:
		if authored[id].passive != null:
			torn_id = id
	var torn_slot := order.find(torn_id) + 1
	var wounded_slot := 1 if torn_slot != 1 else 2
	var status_slot := 3 if torn_slot != 3 else 2
	var party := again
	var enemies := CombatEnemies.new([{"id": "dummy", "max_hp": 8}])
	var result := CombatBattleResult.new(party, enemies)
	_check(result.get_outcome() == CombatBattleResult.ACTIVE and carry.begin_battle("fight_1", result, party),
		"carry witnesses the ACTIVE battle of its hydrated party")
	party._heroes[status_slot - 1].statuses = {"weak": 2, "bleed": 1}
	_check(party.apply_damage(wounded_slot, 5) and party.apply_damage(torn_slot, 999),
		"real damage wounds one hero and downs " + torn_id)
	# Invalid observations before the victory is evaluated cannot mutate anything.
	var before := _reject_snapshot(carry)
	_check(not carry.commit_victory("fight_1", result, party).ok and not carry.apply_reward("fight_1", result, party).ok
		and _reject_snapshot(carry) == before, "unevaluated battle commits nothing")
	_check(enemies.apply_damage(1, 999) and result.evaluate() == CombatBattleResult.VICTORY,
		"actual evaluated surviving victory")
	_check(not carry.commit_victory("other", result, party).ok and _reject_snapshot(carry) == before,
		"foreign node observation is rejected without mutation")
	_check(not carry.apply_reward("fight_1", result, party).ok and _reject_snapshot(carry) == before,
		"tear cannot publish before the victory commits")
	var foreign := CombatParty.new(RunV3PartyAdmission.admit(picks).party)
	_check(not carry.commit_victory("fight_1", result, foreign).ok and _reject_snapshot(carry) == before,
		"a different party object is rejected without mutation")
	_check(carry.commit_victory("fight_1", result, party).ok, "witnessed victory commits")
	_check(carry.apply_reward("fight_1", result, party).ok, "witnessed tear publishes after the claim")
	var state := carry.read_state()
	var heroes: Array = state.get("heroes", [])
	_check_heroes(heroes, order, "post-tear carry")
	if heroes.size() != 3:
		return []
	var torn_record: Dictionary = authored[torn_id]
	_check(heroes[torn_slot - 1].max_hp == maxi(MIN_MAX_HP, torn_record.max_hp - TEAR_LOSS)
		and heroes[torn_slot - 1].hp == 0, torn_id + " loses exactly 3 max HP and stays downed")
	_check(heroes[wounded_slot - 1].max_hp == authored[order[wounded_slot - 1]].max_hp
		and heroes[wounded_slot - 1].hp == authored[order[wounded_slot - 1]].max_hp - 5,
		"wounded survivor keeps cap and real current HP")
	_check(heroes[status_slot - 1].max_hp == authored[order[status_slot - 1]].max_hp
		and heroes[status_slot - 1].get("statuses") == {"weak": 2, "bleed": 1},
		"other hero keeps cap and end-of-battle statuses")
	var counts: Dictionary = carry.torn.read_state().tear_counts
	for id in order:
		_check(counts.get(id) == (1 if id == torn_id else 0), "tear count recorded only for " + torn_id + ": " + id)
	# Replayed observations are inert.
	before = _reject_snapshot(carry)
	_check(not carry.apply_reward("fight_1", result, party).ok and not carry.commit_victory("fight_1", result, party).ok
		and _reject_snapshot(carry) == before, "replayed victory and tear cannot mutate the ledger")
	var next := carry.create_next_fight_party()
	_check(next != null and next.is_valid() and next.get_heroes() == heroes, "torn trio hydrates the next battle")
	if next == null:
		return []
	_check(next.get_heroes() == carry.create_next_fight_party().get_heroes(), "next hydration is repeatable")
	var next_enemies := CombatEnemies.new([{"id": "second_wave", "max_hp": 5}])
	var next_result := CombatBattleResult.new(next, next_enemies)
	_check(carry.begin_battle("fight_2", next_result, next), "next battle is legally witnessed")
	_check(next_enemies.apply_damage(1, 999) and next_result.evaluate() == CombatBattleResult.VICTORY
		and carry.commit_victory("fight_2", next_result, next).ok and carry.apply_reward("fight_2", next_result, next).ok,
		"next battle settles through the same transaction")
	var settled: Array = carry.read_state().heroes
	_check(settled.size() == 3 and settled[torn_slot - 1].max_hp == heroes[torn_slot - 1].max_hp
		and carry.torn.read_state().tear_counts.get(torn_id) == 1, "an already-downed hero is never torn twice")
	return [carry.read_state(), carry.torn.read_state(), next.get_heroes()]


## Equal default positions admit either stable pick order as a canonical start.
func _test_ties() -> void:
	var tied: Array = []
	for id in authored:
		if authored[id].position == 2:
			tied.append(id)
	_check(tied.size() >= 2, "authored roster has a default-position tie to prove")
	if tied.size() < 2:
		return
	var low := ""
	for id in authored:
		if authored[id].position == 1:
			low = id
	for picks in [[tied[0], tied[1], low], [tied[1], tied[0], low]]:
		var order := _expected_order(picks)
		var carry := RunTornCarryover.new(_initial(picks))
		_check(carry.is_valid() and carry.read_state().heroes.size() == 3
			and carry.read_state().heroes[1].id == order[1] and carry.read_state().heroes[2].id == order[2],
			"tie order %s admitted in pick order" % str(order))


## The permissive M03 base accepts wounded or moved rosters, but hydrates only
## when the original held trio is canonical at its authored caps.
func _test_base_carryover() -> void:
	var initial := _initial(LINEUP_A)
	if initial.is_empty():
		return
	var moved := [initial[2].duplicate(true), initial[0].duplicate(true), initial[1].duplicate(true)]
	for index in range(3):
		moved[index].position = index + 1
	moved[0].hp -= 4
	var base := RunPartyCarryover.new(moved)
	var party := base.create_next_fight_party()
	_check(base.is_valid() and party != null and party.get_heroes() == base.get_next_fight_heroes(),
		"base carryover hydrates a moved, wounded canonical V3 trio")
	base._max_hp_by_id[moved[1].id] += 5
	base._heroes[1].max_hp += 5
	_check(base.create_next_fight_party() == null, "base carryover refuses a forged held cap")
	base._max_hp_by_id[moved[1].id] -= 5
	base._heroes[1].max_hp -= 5
	_check(base.create_next_fight_party() != null, "restoring the authored cap restores hydration")
	var forged := moved.duplicate(true)
	forged[2].max_hp += 1
	forged[2].hp = forged[2].max_hp
	var forged_base := RunPartyCarryover.new(forged)
	_check(forged_base.is_valid() and forged_base.create_next_fight_party() == null,
		"base carryover never hydrates a trio admitted at a forged cap")
	var foreign := moved.duplicate(true)
	foreign[0].id = "patch_ghost"
	var foreign_base := RunPartyCarryover.new(foreign)
	_check(foreign_base.create_next_fight_party() == null, "base carryover never hydrates an unknown hero")


func _assert_rejected(heroes: Variant, label: String) -> void:
	var request: Variant = heroes.duplicate(true) if heroes is Array else heroes
	var carry := RunTornCarryover.new(heroes)
	_check(not carry.is_valid() and not carry.torn.is_valid(), label + " rejects the carryover")
	_check(carry.read_state() == {"ok": false, "heroes": [], "completed_fights": [], "completed_rests": [],
		"completed_vital_events": []}
		and carry.torn.read_state().get("heroes") == [] and carry._receipts.is_empty() and carry._initial.is_empty(),
		label + " leaves no partial state")
	_check(carry.create_next_fight_party() == null, label + " never hydrates")
	_check(not RunTornMending.new(heroes).is_valid(), label + " rejects the torn ledger")
	if heroes is Array:
		_check(heroes == request, label + " leaves the request unchanged")


func _test_rejections() -> void:
	var valid := _initial(LINEUP_B)
	if valid.is_empty():
		return
	_check(RunTornCarryover.new(valid.duplicate(true)).is_valid(), "rejection fixture is itself valid")
	var cases := {}
	var unknown := valid.duplicate(true)
	unknown[0].id = "patch_ghost"
	cases["unknown hero"] = unknown
	var wrong_case := valid.duplicate(true)
	wrong_case[1].id = "Scarecrow"
	cases["wrong-case hero"] = wrong_case
	var repeated := valid.duplicate(true)
	repeated[1] = repeated[0].duplicate(true)
	repeated[1].position = 2
	cases["repeated hero"] = repeated
	var low_cap := valid.duplicate(true)
	low_cap[1].max_hp -= 1
	low_cap[1].hp = low_cap[1].max_hp
	cases["wrong canonical HP"] = low_cap
	var forged_cap := valid.duplicate(true)
	forged_cap[2].max_hp = 99
	forged_cap[2].hp = 99
	cases["forged cap"] = forged_cap
	var float_cap := valid.duplicate(true)
	float_cap[0].max_hp = float(float_cap[0].max_hp)
	cases["float cap"] = float_cap
	var wounded := valid.duplicate(true)
	wounded[0].hp -= 1
	cases["wounded start"] = wounded
	var blocked := valid.duplicate(true)
	blocked[1].block = 3
	cases["Block at start"] = blocked
	var reordered := [valid[2].duplicate(true), valid[1].duplicate(true), valid[0].duplicate(true)]
	for index in range(3):
		reordered[index].position = index + 1
	cases["noncanonical starting order"] = reordered
	var misplaced := valid.duplicate(true)
	misplaced[0].position = 2
	misplaced[1].position = 1
	cases["misplaced positions"] = misplaced
	var float_position := valid.duplicate(true)
	float_position[2].position = 3.0
	cases["float position"] = float_position
	var missing_position := valid.duplicate(true)
	missing_position[0].erase("position")
	cases["missing position"] = missing_position
	var forged_passive := valid.duplicate(true)
	for hero in forged_passive:
		if hero.has("passive"):
			hero.passive.effects["forged"] = 1
			break
	cases["forged passive"] = forged_passive
	var stripped_passive := valid.duplicate(true)
	for hero in stripped_passive:
		if hero.has("passive"):
			hero.erase("passive")
			break
	cases["missing passive"] = stripped_passive
	var swapped_passive := valid.duplicate(true)
	swapped_passive[0].passive = authored[LINEUP_A[2]].passive
	cases["another hero's passive"] = swapped_passive
	var bad_status := valid.duplicate(true)
	bad_status[0].statuses = {"bleed": -1}
	cases["malformed status"] = bad_status
	cases["two heroes"] = valid.slice(0, 2)
	var four := valid.duplicate(true)
	four.append(_initial(LINEUP_A)[0])
	cases["four heroes"] = four
	var non_dictionary: Array = []
	for hero in valid:
		non_dictionary.append(hero.duplicate(true))
	non_dictionary[1] = "scarecrow"
	cases["non-Dictionary hero"] = non_dictionary
	for label in cases:
		_assert_rejected(cases[label], label)
	_assert_rejected(null, "null roster")
	_assert_rejected({"heroes": valid}, "non-Array roster")


## The original fixed trio keeps its exact legacy behaviour.
func _test_legacy_trio() -> void:
	var initial := _initial(["tinker", "warden", "seamstress"])
	_check_heroes(initial, ["warden", "seamstress", "tinker"], "legacy trio")
	var carry := RunTornCarryover.new(initial)
	_check(carry.is_valid() and carry.create_next_fight_party() != null, "legacy trio still carries and hydrates")
	var shuffled := [initial[1].duplicate(true), initial[0].duplicate(true), initial[2].duplicate(true)]
	shuffled[0].position = 1
	shuffled[1].position = 2
	_assert_rejected(shuffled, "legacy trio out of canonical order")
