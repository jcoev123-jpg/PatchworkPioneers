extends SceneTree
## Real CombatRoundFlow/CombatUnravel integration, with deterministic battle services.

var failures: Array[String] = []
var checks := 0

const HEROES := "res://data/heroes/starter_party.json"
const ENEMIES := "res://data/enemies/starter_enemies.json"
const INTENTS := "res://data/encounters/starter_attacks.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_skips_and_raised_thresholds()
	_test_bleed_threshold_timing()
	_test_bleed_magnitude_and_lethal()
	_test_no_gauge_and_atomic_rejections()
	_test_seeded_replay()
	_test_termite_split_gauges()
	_test_termite_split_round_flow()
	if failures.is_empty():
		print("combat_round_unravel_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_round_unravel_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_authored(path: String) -> Array:
	var text_data := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text_data)
	_check(not text_data.is_empty() and parsed is Array and not parsed.is_empty(),
		"authored JSON is present: " + path)
	if not parsed is Array:
		return []
	for record in parsed:
		if not record is Dictionary:
			continue
		for field in ["max_hp", "enemy_position"]:
			if record.has(field) and record[field] is float:
				record[field] = int(record[field])
		if record.has("pattern"):
			for action in record["pattern"]:
				for field in ["amount", "target_position", "direction"]:
					if action.has(field) and action[field] is float:
						action[field] = int(action[field])
	return parsed


func _fight(seed: int = 724, three: bool = false, with_gauge: bool = true) -> Dictionary:
	var hero_defs := _load_authored(HEROES)
	var enemy_defs := _load_authored(ENEMIES)
	var intent_defs := _load_authored(INTENTS)
	# Preserve real starter actors and intent patterns; amplify the authored
	# attack so its skipped damage cannot hide behind opening Warden Block.
	for action in intent_defs[0]["pattern"]:
		action["amount"] = 7
	intent_defs[1]["pattern"][0]["amount"] = 3
	if three:
		enemy_defs.append({"id": "thread_boss", "max_hp": 30})
		intent_defs.append({"enemy_position": 3, "pattern": [
			{"type": "attack", "amount": 3, "target_position": 2}]})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cards := StarterCards.new().get_starting_deck()
	var deck := CombatDeck.new(cards, rng)
	var party := CombatParty.new(hero_defs)
	var enemies := CombatEnemies.new(enemy_defs)
	var intents := CombatEnemyIntents.new(intent_defs)
	var result := CombatBattleResult.new(party, enemies)
	var gauge: CombatUnravel = null
	if with_gauge:
		gauge = CombatUnravel.new()
		var tiers := {1: "normal", 2: "elite"}
		if three:
			tiers[3] = "boss"
		_check(gauge.bind_roster(enemies, tiers), "exact authoritative roster binds with explicit tiers")
	var flow := CombatRoundFlow.new(deck, party, enemies, intents, result, gauge)
	_check(party.is_valid() and enemies.is_valid() and intents.is_valid()
		and result.get_outcome() == CombatBattleResult.ACTIVE
		and deck.hand.is_empty() and deck.draw_pile.size() == cards.size()
		and intents.get_intents().size() == enemy_defs.size()
		and party.get_hero(1)["hp"] == 40 and enemies.get_enemy(1)["hp"] == 12,
		"real seeded combat/hand/rosters/schedule are valid before execution")
	return {"deck": deck, "party": party, "enemies": enemies,
		"intents": intents, "result": result, "gauge": gauge, "flow": flow}


func _record(fight: Dictionary) -> Array:
	var deck: CombatDeck = fight["deck"]
	var flow: CombatRoundFlow = fight["flow"]
	var party: CombatParty = fight["party"]
	var enemies: CombatEnemies = fight["enemies"]
	var intents: CombatEnemyIntents = fight["intents"]
	var result: CombatBattleResult = fight["result"]
	var gauges: Array = []
	var gauge: CombatUnravel = fight["gauge"]
	if gauge != null:
		for index in range(enemies.get_enemies().size()):
			gauges.append(gauge.get_snapshot(index + 1))
	return [party.get_heroes(), enemies.get_enemies(),
		deck.draw_pile.duplicate(), deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.energy, deck.turn_active, deck._rng.state, intents._turn_index,
		intents.get_intents(), result.get_outcome(), flow._started,
		flow._opening_block._consumed, gauges]


func _reject_unchanged(fight: Dictionary, action: Callable, label: String) -> void:
	var before := _record(fight)
	_check(not action.call(), label + ": rejects")
	_check(_record(fight) == before,
		label + ": no HP, Block, statuses, deck, hand, RNG, intents, result or gauge mutation")


func _test_skips_and_raised_thresholds() -> void:
	var f := _fight(311, true)
	var gauge: CombatUnravel = f["gauge"]
	var flow: CombatRoundFlow = f["flow"]
	var party: CombatParty = f["party"]
	var enemies: CombatEnemies = f["enemies"]
	var intents: CombatEnemyIntents = f["intents"]
	_check(gauge.get_snapshot(1).threshold == 8
		and gauge.get_snapshot(2).threshold == 12
		and gauge.get_snapshot(3).threshold == 16, "normal, elite and boss initial thresholds")
	_check(flow.begin_fight() and party.get_hero(1).block == 6
		and f["deck"].energy == 3 and f["deck"].hand.size() == 5,
		"real first hand opens with Warden Block and five cards")
	_check(gauge.apply_unravel(enemies, 1, 8)
		and gauge.apply_unravel(enemies, 1, 99)
		and gauge.get_snapshot(1) == {"gauge": 8, "threshold": 8,
			"unravelled": true, "skip_pending": true},
		"first source queues exactly one clamped skip despite further Unravel")
	_check(flow.end_turn(), "first enemy phase with a skipped attacker succeeds")
	_check(party.get_hero(1).hp == 40 and party.get_hero(1).block == 0
		and party.get_hero(2).hp == 27
		and enemies.get_enemy(2).block == 3
		and intents._turn_index == 1,
		"skipped attack does no damage/Block loss; living second Block and third attack execute")
	_check(gauge.get_snapshot(1) == {"gauge": 0, "threshold": 12,
			"unravelled": false, "skip_pending": false},
		"first skipped action consumed once, raises normal threshold exactly four")
	_check(flow.end_turn() and party.get_hero(2).hp == 17
		and enemies.get_enemy(2).block == 6 and intents._turn_index == 2,
		"same source's next announced attack executes, guard still Blocks, schedule advances")
	_check(gauge.apply_unravel(enemies, 1, 12)
		and gauge.apply_unravel(enemies, 2, 12)
		and gauge.apply_unravel(enemies, 3, 16),
		"raised normal and original elite/boss break at correct thresholds")
	var before := party.get_heroes()
	_check(flow.end_turn() and party.get_heroes() == before
		and enemies.get_enemy(2).block == 6 and intents._turn_index == 3,
		"multiple simultaneous skips omit only their actions, preserve original slots and advance once")
	_check(gauge.get_snapshot(1).threshold == 16
		and gauge.get_snapshot(2).threshold == 16
		and gauge.get_snapshot(3).threshold == 20
		and gauge.get_snapshot(1).gauge == 0
		and gauge.get_snapshot(2).gauge == 0
		and gauge.get_snapshot(3).gauge == 0
		and not gauge.get_snapshot(3).skip_pending,
		"second normal, first elite and first boss skip each consumed exactly once")


func _test_bleed_threshold_timing() -> void:
	var f := _fight(509, true)
	var gauge: CombatUnravel = f["gauge"]
	var flow: CombatRoundFlow = f["flow"]
	var enemies: CombatEnemies = f["enemies"]
	var party: CombatParty = f["party"]
	_check(flow.begin_fight(), "Bleed timing battle begins")
	_check(gauge.apply_unravel(enemies, 1, 7)
		and gauge.apply_unravel(enemies, 2, 11)
		and gauge.apply_unravel(enemies, 3, 15)
		and enemies.apply_statuses({1: {"bleed": 1}, 2: {"bleed": 1}, 3: {"bleed": 1}})
		and enemies.gain_block(1, 5) and enemies.gain_block(3, 4),
		"three live tier gauges one below break, each enemy has a real Bleed tick and Block")
	_check(flow.end_turn(), "first Bleed owner turn resolves")
	_check(party.get_hero(1).hp == 39 and party.get_hero(2).hp == 27
		and enemies.get_enemy(1).hp == 11
		and enemies.get_enemy(2).hp == 11
		and enemies.get_enemy(3).hp == 29
		and enemies.get_enemy(1).block == 5
		and enemies.get_enemy(2).block == 3
		and enemies.get_enemy(3).block == 4,
		"all three enemies act before Bleed break; enemy Bleed bypasses own Block")
	for slot in [1, 2, 3]:
		var snapshot := gauge.get_snapshot(slot)
		_check(snapshot.gauge == snapshot.threshold and snapshot.skip_pending
			and snapshot.unravelled,
			"positive enemy Bleed queues only next action at slot %d" % slot)
	var hero_before := party.get_heroes()
	_check(flow.end_turn() and party.get_heroes() == hero_before
		and enemies.get_enemy(2).block == 3,
		"following phase suppresses all pending sources, including Block, without retargeting")
	_check(gauge.get_snapshot(1).threshold == 12 and gauge.get_snapshot(1).gauge == 0
		and gauge.get_snapshot(2).threshold == 16 and gauge.get_snapshot(2).gauge == 0
		and gauge.get_snapshot(3).threshold == 20 and gauge.get_snapshot(3).gauge == 0
		and not gauge.get_snapshot(2).skip_pending
		and enemies.get_enemy(1).get("statuses", {}).is_empty(),
		"all tier skips consumed, one-tick Bleed expired with no additional charges")


func _test_bleed_magnitude_and_lethal() -> void:
	var f := _fight(19)
	var gauge: CombatUnravel = f["gauge"]
	var enemies: CombatEnemies = f["enemies"]
	var flow: CombatRoundFlow = f["flow"]
	_check(flow.begin_fight() and enemies.apply_statuses({1: {"bleed": 6}})
		and enemies.gain_block(1, 9) and gauge.apply_unravel(enemies, 1, 7),
		"surviving Bleed-six source retains nine Block and starts one below threshold")
	_check(flow.end_turn() and enemies.get_enemy(1).hp == 6
		and enemies.get_enemy(1).block == 9 and gauge.get_snapshot(1).gauge == 8
		and gauge.get_snapshot(1).skip_pending,
		"Bleed six bypasses Block but charges exactly ONE gauge, after acting")
	_check(flow.end_turn() and enemies.get_enemy(1).hp == 1
		and enemies.get_enemy(1).block == 9 and gauge.get_snapshot(1).gauge == 1
		and gauge.get_snapshot(1).threshold == 12,
		"pending skip consumed then subsequent surviving Bleed five adds only one fresh gauge")

	var lethal := _fight(20)
	var lethal_enemies: CombatEnemies = lethal["enemies"]
	var lethal_gauge: CombatUnravel = lethal["gauge"]
	var lethal_flow: CombatRoundFlow = lethal["flow"]
	_check(lethal_flow.begin_fight() and lethal_enemies.apply_statuses({1: {"bleed": 15}})
		and lethal_enemies.gain_block(1, 4) and lethal_gauge.apply_unravel(lethal_enemies, 1, 3),
		"lethal Bleed fixture has active battle, surviving companion and shielded source")
	_check(lethal_flow.end_turn() and lethal_enemies.is_slain(1)
		and lethal_enemies.get_enemy(1).hp == 0
		and lethal_enemies.get_enemy(1).block == 4
		and lethal_gauge.get_snapshot(1).gauge == 3
		and not lethal_gauge.get_snapshot(1).skip_pending
		and lethal["result"].get_outcome() == CombatBattleResult.ACTIVE,
		"lethal Bleed kills one, retains Block, never charges postmortem, fight continues")
	_check(lethal_flow.end_turn() and lethal_gauge.get_snapshot(1).gauge == 3
		and lethal_enemies.get_enemy(1).position == 1
		and lethal_enemies.get_enemy(2).block == 6,
		"already dead source remains original slot and cannot gain Unravel on later ticks")

	var final := _fight(21)
	var one_enemies: CombatEnemies = final["enemies"]
	var one_intents: CombatEnemyIntents = CombatEnemyIntents.new([{
		"enemy_position": 1, "pattern": [{"type": "attack", "amount": 7, "target_position": 1}]}])
	# A separate real single-enemy roster/result/schedule verifies lethal victory.
	one_enemies = CombatEnemies.new([{"id": "ragling", "max_hp": 12}])
	var one_result := CombatBattleResult.new(final["party"], one_enemies)
	var one_gauge := CombatUnravel.new()
	_check(one_gauge.bind_roster(one_enemies, {1: "normal"}), "single-enemy lethal roster bound")
	var one_flow := CombatRoundFlow.new(final["deck"], final["party"], one_enemies,
		one_intents, one_result, one_gauge)
	_check(one_flow.begin_fight() and one_enemies.apply_statuses({1: {"bleed": 20}})
		and one_flow.end_turn() and one_result.get_outcome() == CombatBattleResult.VICTORY
		and not final["deck"].turn_active and one_gauge.get_snapshot(1).gauge == 0,
		"last-enemy lethal Bleed latches victory with no postmortem charge or extra hand")


func _test_no_gauge_and_atomic_rejections() -> void:
	var old := _fight(991, false, false)
	var bound := _fight(991)
	var old_flow: CombatRoundFlow = old["flow"]
	var bound_flow: CombatRoundFlow = bound["flow"]
	_check(old_flow.begin_fight() and bound_flow.begin_fight()
		and _record(old).slice(0, 13) == _record(bound).slice(0, 13),
		"five-argument-compatible ungauged opening matches a bound zero-gauge fight")
	for turn in range(3):
		_check(old_flow.end_turn() and bound_flow.end_turn()
			and _record(old).slice(0, 13) == _record(bound).slice(0, 13),
			"unbound round %d preserves HP, Block, hand, discard, intent and seeded RNG" % turn)

	var foreign := _fight(100)
	var incorrect := _fight(100, false, false)
	incorrect["gauge"] = foreign["gauge"]
	incorrect["flow"] = CombatRoundFlow.new(incorrect["deck"], incorrect["party"],
		incorrect["enemies"], incorrect["intents"], incorrect["result"], incorrect["gauge"])
	_reject_unchanged(incorrect, incorrect["flow"].begin_fight, "wrong roster at begin")
	_check(incorrect["flow"]._unravel._bound_enemies == foreign["enemies"],
		"wrong binding remains foreign and was never silently rebound")

	var missing := _fight(101)
	var missing_flow: CombatRoundFlow = missing["flow"]
	var missing_gauge: CombatUnravel = missing["gauge"]
	missing_gauge._gauges.erase(2)
	_reject_unchanged(missing, missing_flow.begin_fight, "missing original slot at begin")

	var broken := _fight(102)
	var broken_flow: CombatRoundFlow = broken["flow"]
	var broken_gauge: CombatUnravel = broken["gauge"]
	_check(broken_flow.begin_fight() and broken_gauge.apply_unravel(broken["enemies"], 1, 8),
		"pending skip is real before end-turn rejection")
	broken_gauge._gauges[2] = {"gauge": 12, "threshold": 12}
	_reject_unchanged(broken, broken_flow.end_turn, "malformed original slot at end")

	var wrong_end := _fight(103)
	var wrong_flow: CombatRoundFlow = wrong_end["flow"]
	var wrong_gauge: CombatUnravel = wrong_end["gauge"]
	_check(wrong_flow.begin_fight() and wrong_gauge.apply_unravel(wrong_end["enemies"], 1, 8),
		"bound skip before mid-fight foreign-roster swap")
	wrong_gauge._bound_enemies = foreign["enemies"]
	_reject_unchanged(wrong_end, wrong_flow.end_turn, "wrong roster at end")

	var phase_bad := _fight(104)
	var phase_flow: CombatRoundFlow = phase_bad["flow"]
	var phase_gauge: CombatUnravel = phase_bad["gauge"]
	var phase_enemies: CombatEnemies = phase_bad["enemies"]
	_check(phase_flow.begin_fight()
		and phase_gauge.apply_unravel(phase_enemies, 1, 8)
		and phase_enemies.gain_block(2, CombatEnemies.MAX_INT),
		"skipped source precedes later overflowing Block source")
	_reject_unchanged(phase_bad, phase_flow.end_turn,
		"invalid effective phase after skipped source")

	var status_bad := _fight(105)
	var status_flow: CombatRoundFlow = status_bad["flow"]
	var status_gauge: CombatUnravel = status_bad["gauge"]
	_check(status_flow.begin_fight() and status_gauge.apply_unravel(status_bad["enemies"], 1, 8),
		"pending skip before invalid owner status")
	status_bad["party"]._heroes[2]["statuses"] = {"bleed": -1}
	_reject_unchanged(status_bad, status_flow.end_turn, "invalid owner tick")

	var inactive := _fight(106)
	var inactive_flow: CombatRoundFlow = inactive["flow"]
	_check(inactive_flow.begin_fight() and inactive["gauge"].apply_unravel(inactive["enemies"], 1, 8)
		and inactive["deck"].end_turn(), "externally closed hand fixture")
	_reject_unchanged(inactive, inactive_flow.end_turn, "inactive hand")

	var hero_bleed := _fight(107)
	var hero_flow: CombatRoundFlow = hero_bleed["flow"]
	var hero_gauge: CombatUnravel = hero_bleed["gauge"]
	_check(hero_flow.begin_fight(), "hero Bleed control begins")
	hero_bleed["party"]._heroes[1]["statuses"] = {"bleed": 2}
	_check(hero_flow.end_turn() and hero_bleed["party"].get_hero(2).hp == 28
		and hero_gauge.get_snapshot(1).gauge == 0
		and hero_gauge.get_snapshot(2).gauge == 0,
		"hero owner Bleed still ticks HP but never charges enemy Unravel")

	var terminal := _fight(108)
	var terminal_flow: CombatRoundFlow = terminal["flow"]
	var terminal_enemies: CombatEnemies = terminal["enemies"]
	var terminal_gauge: CombatUnravel = terminal["gauge"]
	_check(terminal_flow.begin_fight() and terminal_gauge.apply_unravel(terminal_enemies, 1, 8)
		and terminal_enemies.apply_damage(1, 12)
		and terminal_enemies.apply_damage(2, 12)
		and terminal["result"].evaluate() == CombatBattleResult.VICTORY,
		"pending skip and card-driven terminal victory exist before end attempt")
	_reject_unchanged(terminal, terminal_flow.end_turn,
		"terminal fight cannot consume queued skip or advance RNG")


func _test_seeded_replay() -> void:
	var first: Array = []
	for repeat_index in range(2):
		var f := _fight(711, true)
		var flow: CombatRoundFlow = f["flow"]
		var gauge: CombatUnravel = f["gauge"]
		var enemies: CombatEnemies = f["enemies"]
		_check(flow.begin_fight() and gauge.apply_unravel(enemies, 1, 8)
			and enemies.apply_statuses({2: {"bleed": 2}}), "seeded run initial state is live")
		var snapshots: Array = [_record(f)]
		for round_index in range(4):
			_check(flow.end_turn(), "seeded replay round %d succeeds" % round_index)
			if round_index == 1:
				_check(gauge.apply_unravel(enemies, 3, 16),
					"replay applies real boss gauge between turns")
			snapshots.append(_record(f))
		_check(snapshots[0][7] is int and snapshots[-1][8] == 4
			and snapshots[-1][0][0].hp < 40 and snapshots[-1][13].size() == 3,
			"replay actually advances damage, scheduler, gauges and RNG state")
		if repeat_index == 0:
			first = snapshots.duplicate(true)
		else:
			_check(snapshots == first,
				"fresh same-seed full actor/deck/intent/gauge snapshots and RNG state replay exactly")


func _termite_source() -> Dictionary:
	var parsed := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	for record in parsed:
		if record.get("id") == CombatEnemies.TERMITE_ID:
			return record.duplicate(true)
	return {}


func _split_peer(id: String) -> Dictionary:
	return {"id": id, "name": id, "max_hp": 12,
		"intent": {"target": "front", "actions": [
			{"type": "attack", "amount": 2, "weight": 1}]}}


func _termite_gauge_fixture(count: int = 2, seed_value: int = 733) -> Dictionary:
	var source := _termite_source()
	var records: Array = [source]
	for index in range(1, count):
		records.append(_split_peer("split_peer_%d" % index))
	var enemies := CombatEnemies.new(records)
	var gauge := CombatUnravel.new()
	var tiers := {}
	for index in range(count):
		tiers[index + 1] = "normal"
	if source.is_empty() or not enemies.is_valid() or not gauge.bind_roster(enemies, tiers):
		return {}
	return {"enemies": enemies, "gauge": gauge, "rng": RandomNumberGenerator.new()}


func _split_snapshots(enemies: CombatEnemies, gauge: CombatUnravel) -> Array:
	var snaps: Array = []
	for index in range(enemies.get_enemies().size()):
		snaps.append(gauge.get_snapshot(index + 1))
	return snaps


func _test_termite_split_gauges() -> void:
	var f := _termite_gauge_fixture(2, 733)
	_check(not f.is_empty(),
		"precondition: a real two-foe Termite fight binds its authoritative gauges")
	if f.is_empty():
		return
	var enemies: CombatEnemies = f.enemies
	var gauge: CombatUnravel = f.gauge
	_check(gauge.apply_unravel(enemies, 1, 8) and gauge.apply_unravel(enemies, 2, 3),
		"precondition: source carries a queued skip and the peer has its own charge")
	var peer_before := gauge.get_snapshot(2)
	_check(not gauge.can_admit_split(enemies, 1),
		"AC3: a nonlethal roster admits no split gauges")
	_check(enemies.stage_split_on_death(1) == {"ok": true, "split": false}
		and gauge.get_snapshot(1).skip_pending,
		"AC3: nonlethal staging is inert and keeps the old charge and skip")
	_check(enemies.apply_damage(1, 26) and enemies.is_slain(1),
		"precondition: lethal damage leaves the Termite at zero HP")
	var staged := enemies.stage_split_on_death(1)
	_check(staged.get("ok", false) and staged.get("split", false)
		and staged.get("positions") == [1, 3],
		"precondition: the existing splitter publishes the two half actors")
	var proposed := enemies.get_enemies()
	_check(gauge.can_admit_split(enemies, 1, proposed),
		"AC2: gauge preflight accepts both new actors before publication")
	_check(gauge.admit_split(enemies, 1),
		"AC2: three fresh positions publish one gauge each")
	var clean := {"gauge": 0, "threshold": 8, "unravelled": false, "skip_pending": false}
	_check(_split_snapshots(enemies, gauge) == [clean, peer_before, clean],
		"AC2: both halves start clean at the base tier threshold; no charge or skip transfers")
	_check(gauge._tiers_by_position == {1: "normal", 2: "normal", 3: "normal"},
		"AC2: both halves keep the source's authored normal tier")
	var after := _split_snapshots(enemies, gauge)
	_check(not gauge.can_admit_split(enemies, 1)
		and not gauge.admit_split(enemies, 1)
		and _split_snapshots(enemies, gauge) == after,
		"AC3: a duplicate split receipt cannot create grandchildren or extra gauges")
	var broken := _termite_gauge_fixture(2, 734)
	broken.enemies.apply_damage(1, 26)
	broken.enemies.stage_split_on_death(1)
	broken.enemies._enemies[2]["hp"] = 0
	var broken_before := _split_snapshots(broken.enemies, broken.gauge)
	_check(not broken.gauge.can_admit_split(broken.enemies, 1)
		and not broken.gauge.admit_split(broken.enemies, 1)
		and _split_snapshots(broken.enemies, broken.gauge) == broken_before,
		"AC3: a malformed half refuses admission and leaves every gauge untouched")
	var full := _termite_gauge_fixture(3, 735)
	full.enemies.apply_damage(1, 26)
	var full_before := _split_snapshots(full.enemies, full.gauge)
	_check(full.enemies.stage_split_on_death(1) == {"ok": true, "split": false}
		and not full.gauge.can_admit_split(full.enemies, 1)
		and not full.gauge.admit_split(full.enemies, 1)
		and _split_snapshots(full.enemies, full.gauge) == full_before,
		"AC3: a full three-slot roster keeps the normal death and existing gauges")
	var replay: Array = []
	for repeat_index in range(2):
		var fight := _termite_gauge_fixture(2, 736)
		fight.enemies.apply_damage(1, 26)
		fight.enemies.stage_split_on_death(1)
		_check(fight.gauge.admit_split(fight.enemies, 1),
			"same-seed split gauge admission succeeds")
		var snap := _split_snapshots(fight.enemies, fight.gauge)
		if repeat_index == 0:
			replay = snap
		else:
			_check(snap == replay,
				"AC3: same-seed gauge admission replays exactly")


func _test_termite_split_round_flow() -> void:
	var source := _termite_source()
	var enemies := CombatEnemies.new([source])
	var party := CombatParty.new(_load_authored(HEROES))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9182
	var deck := CombatDeck.new(StarterCards.new().get_starting_deck(), rng)
	var intents := CombatEnemyIntents.new([
		{"enemy_position": 1, "pattern": [{"type": "block", "amount": 0}]}])
	_check(not source.is_empty() and enemies.is_valid() and party.is_valid()
		and intents.is_valid() and intents.bind_battle(enemies, party, rng),
		"precondition: a genuine one-foe Termite Fight binds its weighted schedule")
	var result := CombatBattleResult.new(party, enemies)
	var gauge := CombatUnravel.new()
	_check(gauge.bind_roster(enemies, {1: "normal"}),
		"precondition: the fight binds its gauge ledger")
	var flow := CombatRoundFlow.new(deck, party, enemies, intents, result, gauge)
	_check(flow.begin_fight() and flow._valid_bindings(),
		"precondition: the real round flow starts over the authentic Termite")
	_check(enemies.apply_damage(1, source.max_hp) and enemies.is_slain(1)
		and enemies.stage_split_on_death(1).get("split", false),
		"precondition: the existing splitter replaces the dead source and appends its half")
	var proposed := enemies.get_enemies()
	_check(intents.can_admit_split(enemies, 1, proposed)
		and gauge.can_admit_split(enemies, 1, proposed),
		"AC2: scheduler and gauge preflight both accept the proposed roster")
	_check(intents.admit_split(enemies, 1) and gauge.admit_split(enemies, 1),
		"AC2: both ledgers publish the two new actors together")
	_check(flow._valid_bindings() and result.get_outcome() == CombatBattleResult.ACTIVE,
		"AC2: the genuine round flow remains legally playable, not a stale two-slot fight")
	var rng_before := rng.state
	_check(flow.end_turn(), "AC2: the next enemy phase with both halves executes")
	_check(intents._turn_index == 1 and deck.turn_active
		and rng.state == rng_before,
		"AC2: both halves announce legal single actions without a new seeded draw")
	_check(enemies.get_enemies().size() == 2 and not enemies.is_victorious(),
		"AC2: two living halves keep the fight active after the enemy phase")
	_check(enemies.apply_damage(1, 13) and not enemies.is_victorious(),
		"AC2: killing only the first half cannot claim victory")
	_check(enemies.apply_damage(2, 13) and enemies.is_victorious()
		and enemies.get_enemies().size() == 2,
		"AC2: legitimate victory arrives only after both halves die, with no third split")
