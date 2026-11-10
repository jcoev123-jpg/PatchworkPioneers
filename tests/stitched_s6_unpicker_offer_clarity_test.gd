extends SceneTree
## S6: the routed Unpicker names each eligible doll's exact quoted FRAY relief and the
## tier of every spare it would unpick. A bounded sweep of seeded RunMaps finds a genuine
## floor-one Unpicker; no node id is hard-coded. The purse, FRAY values and satchel set
## below are TEST-ONLY fixtures, NOT earned play: they are written into a fresh session
## before it is re-sealed, then the real enter / visit_actions / choose_visit path runs.

const SEED_SWEEP := 600
const PARTS_PATH := "res://data/parts/enemy_parts.json"
const PRICE := 75
const YIELD := 2
const ROMAN := ["I", "II", "III"]
## Four distinct dolls in rank order: two eligible (12, 85) and two with nothing to calm.
const FIXTURE_FRAY := [12, 85, 0, 0]
## Six same-catalog enemy spares: [id, tier]. Index 0 is tier II, index 1 tier I.
const FIXTURE_SPARES := [["scissor_crab_claw_arm", 2], ["moth_swarm_wings", 1],
	["felt_bulwark_button_shield", 3], ["scissor_crab_claw_arm", 1],
	["moth_swarm_wings", 2], ["felt_bulwark_button_shield", 1]]

var checks := 0
var failures: Array = []


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _initialize() -> void:
	var witness := _witness()
	_check(not witness.is_empty(), "bounded seed sweep finds a genuine floor-one Unpicker")
	if not witness.is_empty():
		_offer_text(witness)
		_calm_settles(witness, 0)
		_calm_settles(witness, 1)
		_unpick_settles(witness, 0)
		_unpick_settles(witness, 1)
		_leave_settles(witness)
		_unfunded(witness)
	for message in failures:
		printerr("FAIL: " + message)
	print("stitched_s6_unpicker_offer_clarity_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _witness() -> Dictionary:
	for seed_number in range(SEED_SWEEP):
		var session := StitchedRunSession.start(seed_number)
		if session == null:
			continue
		for node_id in session.choices():
			if str(session.map.get_node(node_id).type) == "Unpicker":
				return {"seed": seed_number, "node_id": str(node_id)}
	return {}


## TEST-ONLY resources, NOT earned play: set on a fresh session, then sealed.
func _fixture(witness: Dictionary, gold: int) -> StitchedRunSession:
	var session := StitchedRunSession.start(int(witness.seed))
	if session == null or not session.choices().has(witness.node_id) or session.heroes.size() != 4:
		return null
	session.gold = gold
	session.scraps = 5
	for index in 4:
		session.heroes[index]["fray"] = FIXTURE_FRAY[index]
		session.heroes[index]["lost"] = false
	session.satchel = []
	for row in FIXTURE_SPARES:
		var part_id: String = row[0]
		if not session.catalog.has(part_id):
			return null
		session.satchel.append({"id": part_id, "slot": session.catalog[part_id].slot, "tier": row[1], "torn": false})
	session._seal()
	return session


func _entered(witness: Dictionary, gold: int) -> StitchedRunSession:
	var session := _fixture(witness, gold)
	_check(session != null, "fixture session starts on the witness seed")
	if session == null:
		return null
	_check(session.enter(witness.node_id, session.snapshot()) and session.phase == "visit"
		and session.pending.get("service") == "Unpicker", "the real route enters the Unpicker visit")
	return session if session.phase == "visit" else null


func _fresh_quote(session: StitchedRunSession) -> Dictionary:
	var visit := RunUnpickerVisit.open_stitched(session.pending.node_id, session._roster(), session.gold,
		StitchedRunSession.CALM_PRICE, session.satchel, session.scraps, StitchedRunSession.UNPICK_YIELD)
	return visit.quote()


func _catalog_names() -> Dictionary:
	var names := {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PARTS_PATH))
	if parsed is Dictionary:
		for part in parsed.get("parts", []):
			names[str(part.id)] = str(part.name)
	return names


func _hero(session: StitchedRunSession, hero_id: String) -> Dictionary:
	for hero in session.heroes:
		if hero.id == hero_id:
			return hero
	return {}


func _with_id(actions: Array, action_id: String) -> Array:
	return actions.filter(func(action: Dictionary): return action.id == action_id)


func _offer_text(witness: Dictionary) -> void:
	var session := _entered(witness, PRICE)
	if session == null:
		return
	var entered := session.snapshot()
	var rng_state := session.rng.state
	var route := session.map.get_route()
	var actions := session.visit_actions()
	_check(session.visit_actions() == actions and session.snapshot() == entered
		and session.rng.state == rng_state and session.map.get_route() == route
		and session.candle == entered.candle and session.gold == PRICE,
		"reading the actions changes no route, currency, RNG or candle")
	var quote := _fresh_quote(session)
	var outcomes: Array = quote.calm_outcomes
	var calms := _with_id(actions, "calm")
	_check(quote.ok == true and outcomes.size() == 2 and calms.size() == 2,
		"quote and session both name exactly the two eligible dolls")
	if outcomes.size() == 2 and calms.size() == 2:
		_check(outcomes[0].fray_relief == 12 and outcomes[1].fray_relief == 50,
			"the quoted reliefs are 12 and 50 for 12 and 85 FRAY")
		_check(not str(calms[0].text).contains("FRAY") and not str(calms[1].text).contains("FRAY")
			and str(calms[0].text).contains("75 gold") and str(calms[1].text).contains("75 gold"),
			"the calm labels stay FRAY-free in live s14 mode and disclose the 75-gold charge")
		for index in 2:
			var row: Dictionary = outcomes[index]
			var hero := _hero(session, str(row.hero_id))
			_check(not hero.is_empty() and calms[index].text == "Calm %s / %d gold" % [
					hero.name, PRICE]
					and calms[index].arguments == [row.hero_id] and calms[index].arguments == [session.heroes[index].id]
					and calms[index].enabled == true,
				"calm %d shows the quoted relief row with its id, hero argument, order and enabled flag" % index)
		for index in [2, 3]:
			var idle_name: String = str(session.heroes[index].name)
			_check(not calms.any(func(action: Dictionary): return str(action.text).contains(idle_name)),
				"a zero-FRAY doll is not named by any calm action")
	var spares: Array = quote.spares
	var unpicks := _with_id(actions, "unpick")
	var names := _catalog_names()
	_check(spares.size() == 6 and unpicks.size() == 6, "all six satchel spares are offered to unpick")
	if spares.size() == 6 and unpicks.size() == 6:
		for index in 6:
			var spare: Dictionary = spares[index]
			var part_name: String = str(names.get(str(spare.id), ""))
			var expected := "Unpick %s (Tier %s) / +%d scraps" % [part_name, ROMAN[int(spare.tier) - 1], YIELD]
			_check(not part_name.is_empty() and part_name == str(session.catalog[spare.id].name)
					and unpicks[index].text == expected and not str(unpicks[index].text).contains(str(spare.id))
					and unpicks[index].arguments == [spare.index] and unpicks[index].arguments == [index]
					and unpicks[index].enabled == true,
				"unpick %d shows its catalog name, tier and +2 scraps, never the raw id" % index)
		_check(str(unpicks[0].text).contains("Scissor Claw") and str(unpicks[0].text).contains("(Tier II)")
			and str(unpicks[1].text).contains("Tatter Wings") and str(unpicks[1].text).contains("(Tier I)")
			and unpicks[0].arguments == [0] and unpicks[1].arguments == [1],
			"the tier-II spare and the later tier-I spare keep their own names, tiers and indices")
	var leaves := _with_id(actions, "leave")
	_check(leaves.size() == 1 and leaves[0].enabled == true and leaves[0].text == "Leave Unpicker",
		"exactly one enabled Leave remains")


func _calm_settles(witness: Dictionary, hero_index: int) -> void:
	var session := _fixture(witness, PRICE)
	if session == null:
		_check(false, "calm fixture starts")
		return
	var before_enter := session.snapshot()
	_check(session.enter(witness.node_id, before_enter), "calm fixture enters the Unpicker")
	var entered := session.snapshot()
	var target_id: String = session.heroes[hero_index].id
	var prior: int = int(session.heroes[hero_index].fray)
	var matches := _with_id(session.visit_actions(), "calm").filter(
		func(action: Dictionary): return action.arguments == [target_id])
	_check(matches.size() == 1 and prior == FIXTURE_FRAY[hero_index], "the displayed calm action targets the doll")
	if matches.size() != 1:
		return
	var action: Dictionary = matches[0]
	for refused in [["calm", [session.heroes[2].id]], ["calm", [session.heroes[3].id]], ["calm", ["ghost"]],
			["calm", []], ["unpick", [6]], ["unpick", [-1]], ["bogus", []]]:
		_check(not session.choose_visit(refused[0], refused[1], entered) and session.snapshot() == entered,
			"refused decision %s leaves the open visit untouched" % str(refused))
	_check(not session.choose_visit(action.id, action.arguments, before_enter) and session.snapshot() == entered,
		"a stale snapshot cannot choose the displayed calm")
	_check(session.choose_visit(action.id, action.arguments, session.snapshot()), "the displayed calm is chosen")
	_check(session.gold == 0 and session.gold == entered.gold - PRICE, "calm deducts exactly 75 gold")
	for index in 4:
		var hero_id: String = entered.heroes[index].id
		var now := _hero(session, hero_id)
		if hero_id == target_id:
			_check(int(now.fray) == prior - mini(50, prior), "only the chosen doll loses min(50, FRAY)")
		else:
			_check(int(now.fray) == int(entered.heroes[index].fray) and now.hp == entered.heroes[index].hp
				and now.rank == entered.heroes[index].rank and now.lost == entered.heroes[index].lost
				and now.resolve == entered.heroes[index].resolve, "other doll %d is unchanged" % index)
	_check(session.satchel == entered.satchel and session.scraps == entered.scraps and session.candle == entered.candle
		and session.phase == "map", "calm leaves spares, scraps and candle alone and returns to the map")
	_check(session.receipts.size() == entered.receipts.size() + 1 and session.receipts.back().decision == "calm"
		and session.receipts.back().node_id == witness.node_id, "exactly one calm receipt is written")
	var settled := session.snapshot()
	_check(not session.choose_visit(action.id, action.arguments, entered)
		and not session.choose_visit(action.id, action.arguments, settled) and session.snapshot() == settled
		and session.visit_actions().is_empty(), "a replayed calm fails without mutation")


func _unpick_settles(witness: Dictionary, spare_index: int) -> void:
	var session := _entered(witness, PRICE)
	if session == null:
		return
	var entered := session.snapshot()
	var matches := _with_id(session.visit_actions(), "unpick").filter(
		func(action: Dictionary): return action.arguments == [spare_index])
	_check(matches.size() == 1, "the displayed unpick action targets satchel index %d" % spare_index)
	if matches.size() != 1:
		return
	var action: Dictionary = matches[0]
	_check(not session.choose_visit(action.id, [session.satchel.size()], entered) and session.snapshot() == entered,
		"an unoffered satchel index cannot be unpicked")
	_check(session.choose_visit(action.id, action.arguments, session.snapshot()), "the displayed unpick is chosen")
	var expected: Array = entered.satchel.duplicate(true)
	expected.remove_at(spare_index)
	_check(session.satchel == expected and session.scraps == entered.scraps + YIELD
		and session.gold == entered.gold and session.candle == entered.candle,
		"unpick removes exactly the displayed index and credits exactly 2 scraps")
	for index in 4:
		var now := _hero(session, entered.heroes[index].id)
		_check(int(now.fray) == int(entered.heroes[index].fray) and now.hp == entered.heroes[index].hp,
			"unpick leaves doll %d's FRAY and HP alone" % index)
	_check(session.phase == "map" and session.receipts.size() == entered.receipts.size() + 1
		and session.receipts.back().decision == "unpick", "exactly one unpick receipt is written")
	var settled := session.snapshot()
	_check(not session.choose_visit(action.id, action.arguments, entered)
		and not session.choose_visit(action.id, action.arguments, settled) and session.snapshot() == settled,
		"a replayed unpick fails without mutation")


func _leave_settles(witness: Dictionary) -> void:
	var session := _entered(witness, PRICE)
	if session == null:
		return
	var entered := session.snapshot()
	var leaves := _with_id(session.visit_actions(), "leave")
	_check(leaves.size() == 1, "one Leave is offered")
	if leaves.size() != 1:
		return
	_check(session.choose_visit("leave", leaves[0].arguments, session.snapshot()), "free Leave is chosen")
	_check(session.gold == entered.gold and session.scraps == entered.scraps and session.satchel == entered.satchel
		and session.candle == entered.candle and session.phase == "map", "free Leave changes no wallet or part")
	for index in 4:
		var now := _hero(session, entered.heroes[index].id)
		_check(int(now.fray) == int(entered.heroes[index].fray), "Leave leaves doll %d's FRAY alone" % index)
	_check(session.receipts.size() == entered.receipts.size() + 1 and session.receipts.back().decision == "leave",
		"exactly one Leave receipt is written")
	var settled := session.snapshot()
	_check(not session.choose_visit("leave", [], entered) and not session.choose_visit("leave", [], settled)
		and session.snapshot() == settled, "a replayed Leave fails without mutation")


func _unfunded(witness: Dictionary) -> void:
	var session := _entered(witness, 0)
	if session == null:
		return
	var entered := session.snapshot()
	var actions := session.visit_actions()
	_check(_with_id(actions, "calm").is_empty() and _with_id(actions, "unpick").size() == 6
		and _with_id(actions, "leave").size() == 1, "an empty purse offers no calm but still offers spares and Leave")
	_check(not session.choose_visit("calm", [session.heroes[1].id], entered) and session.snapshot() == entered,
		"an unfunded calm cannot be forced")
	_check(session.choose_visit("unpick", [0], session.snapshot()) and session.gold == 0
		and session.scraps == entered.scraps + YIELD and session.satchel.size() == 5,
		"an unfunded purse still unpicks the displayed spare for 2 scraps")
