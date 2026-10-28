extends SceneTree
## Cycle 364: the routed Razor Ribbon Wraith revives once at half HP after its
## first lethal blow, through card damage and owner-turn Bleed alike.

const HEROES_PATH := "res://data/heroes/starter_party.json"
const WRAITH_ID := "razor_ribbon_wraith"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog_record()
	_test_damage_lifecycle()
	_test_rejections()
	_test_snapshot_persistence()
	_test_bleed_proposal()
	_test_round_flow_bleed()
	_test_round_flow_damage_then_bleed()
	_test_round_flow_refusal()
	_test_replay()
	if failures.is_empty():
		print("combat_v3_revive_once_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_v3_revive_once_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## The Wraith exactly as the live floor-band entry service loads it.
func _wraith() -> Dictionary:
	var material := RunAuthoredBattleEntry._floor_band_material(null)
	var record: Dictionary = material.get("records", {}).get(WRAITH_ID, {}).duplicate(true)
	if record.get("max_hp") is float:
		record["max_hp"] = int(record["max_hp"])
	return record


func _ordinary(id: String = "ragling", hp: int = 12) -> Dictionary:
	return {"id": id, "name": id, "max_hp": hp}


func _heroes() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(HEROES_PATH))
	for hero in parsed:
		hero["max_hp"] = int(hero["max_hp"])
	return parsed


func _fight(seed_value: int, defs: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cards := StarterCards.new().get_starting_deck()
	var deck := CombatDeck.new(cards, rng)
	var party := CombatParty.new(_heroes())
	var enemies := CombatEnemies.new(defs)
	var intents: Array = []
	for index in range(defs.size()):
		intents.append({"enemy_position": index + 1, "pattern": [{"type": "block", "amount": 1}]})
	var scheduler := CombatEnemyIntents.new(intents)
	var result := CombatBattleResult.new(party, enemies)
	var flow := CombatRoundFlow.new(deck, party, enemies, scheduler, result)
	_check(flow.begin_fight() and deck.turn_active, "the revive fixture opens a real active turn")
	return {"deck": deck, "party": party, "enemies": enemies, "result": result, "flow": flow}


func _snapshot(fight: Dictionary) -> Dictionary:
	return {"enemies": fight["enemies"].get_enemies(), "heroes": fight["party"].get_heroes(),
		"hand": fight["deck"].hand.duplicate(), "rng": fight["deck"]._rng.state,
		"energy": fight["deck"].combat_state.energy, "turn": fight["deck"].turn_active}


func _test_catalog_record() -> void:
	var wraith := _wraith()
	_check(wraith.get("revive_once") == true and wraith.get("max_hp") == 27,
		"the live entry Wraith carries the boolean revive_once and keeps 27 HP")
	var actions: Array = wraith.get("intent", {}).get("actions", [])
	_check(wraith.get("intent", {}).get("target") == "lowest_living_hp" and actions.size() == 3
		and actions[0].get("status") == "bleed" and actions[2].get("type") == "attack",
		"the Wraith keeps its weighted Bleed / Exposed / attack intent")
	var material := RunAuthoredBattleEntry._floor_band_material(null)
	var banded := false
	for key in material.get("pools", {}):
		if material["pools"][key].has(WRAITH_ID):
			banded = true
	_check(banded, "the Wraith stays in a live ordinary floor band")
	for record in material.get("records", {}).values():
		if record.get("id") != WRAITH_ID:
			_check(not record.has("revive_once"), "no other routed actor revives: " + str(record.get("id")))


func _test_damage_lifecycle() -> void:
	var wraith := _wraith()
	wraith["statuses"] = {"bleed": 2, "weak": 1}
	var enemies := CombatEnemies.new([_ordinary(), wraith])
	_check(enemies.is_valid() and enemies.get_enemy(2)["hp"] == 27, "the Wraith enters at full 27 HP in slot 2")
	_check(enemies.apply_damage(2, 26) and enemies.get_enemy(2)["hp"] == 1
		and not enemies.get_enemy(2).has("revived"), "a nonlethal hit spends no revival")
	_check(enemies.gain_block(2, 5) and enemies.apply_damage(2, 5) and enemies.get_enemy(2)["hp"] == 1
		and not enemies.get_enemy(2).has("revived"), "a blow fully absorbed by Block spends no revival")
	var before := enemies.get_enemy(2)
	_check(enemies.apply_damage(2, 40), "the first lethal blow is accepted")
	var after := enemies.get_enemy(2)
	_check(after["hp"] == 14 and after["revived"] == true and after["position"] == 2
		and not enemies.is_slain(2), "the first lethal blow leaves the Wraith at exactly 14 HP in slot 2")
	_check(after["statuses"] == before["statuses"] and after["block"] == 0 and after["intent"] == before["intent"]
		and after["id"] == WRAITH_ID and after["max_hp"] == 27, "revival keeps statuses, intent and metadata")
	_check(enemies.get_enemy(1)["hp"] == 12, "revival never touches the other foe")
	_check(enemies.apply_damage(1, 12) and enemies.is_slain(1) and not enemies.is_victorious(),
		"an ordinary foe dies normally and the revived Wraith prevents victory")
	_check(not enemies.heal(1, 5) and enemies.is_slain(1), "healing never resurrects the ordinary foe")
	_check(enemies.apply_damage(2, 14) and enemies.is_slain(2) and enemies.get_enemy(2)["hp"] == 0,
		"the second lethal blow is final")
	_check(enemies.is_victorious(), "victory arrives only after the second Wraith death")
	_check(not enemies.heal(2, 10) and not enemies.apply_damage(2, 5) and enemies.get_enemy(2)["hp"] == 0,
		"a dead Wraith cannot be healed, hit or revived again")
	var exact := CombatEnemies.new([_wraith()])
	_check(exact.apply_damage(1, 27) and exact.get_enemy(1)["hp"] == 14 and not exact.is_victorious(),
		"an exactly lethal blow on the only foe revives without a premature victory")


func _test_rejections() -> void:
	for bad in ["yes", 1, 1.0, null]:
		var wraith := _wraith()
		wraith["revive_once"] = bad
		_check(not CombatEnemies.new([wraith]).is_valid(), "a malformed revive_once is refused: " + str(bad))
	var latch := _wraith()
	latch["revived"] = "true"
	_check(not CombatEnemies.new([latch]).is_valid(), "a malformed revived latch is refused")
	var orphan := _ordinary()
	orphan["revived"] = true
	_check(not CombatEnemies.new([orphan]).is_valid(), "a revived latch without revive_once is refused")
	var enemies := CombatEnemies.new([_wraith(), _ordinary()])
	enemies._enemies[0]["revive_once"] = 1
	var before := enemies._enemies.duplicate(true)
	_check(not enemies.apply_damage(1, 30) and enemies._enemies == before,
		"a live malformed flag refuses the hit with nothing written")
	var plain := CombatEnemies.new([_ordinary()])
	_check(plain.apply_damage(1, 50) and plain.is_slain(1) and plain.is_victorious(),
		"an ordinary foe never revives")


func _test_snapshot_persistence() -> void:
	var enemies := CombatEnemies.new([_wraith()])
	enemies.apply_damage(1, 30)
	var snap := enemies.get_enemies()
	var copy := CombatEnemies.new(snap)
	copy._enemies.assign(snap.duplicate(true))
	_check(copy.get_enemy(1)["revived"] == true and copy.get_enemy(1)["hp"] == 14,
		"a detached snapshot keeps the spent revival")
	_check(copy.apply_damage(1, 99) and copy.is_slain(1) and copy.is_victorious(),
		"a snapshot copy cannot revive the Wraith a second time")


func _test_bleed_proposal() -> void:
	var wraith := _wraith()
	var roster: Array = CombatEnemies.new([wraith, _ordinary()]).get_enemies()
	roster[0]["hp"] = 3
	roster[0]["statuses"] = {"bleed": 4}
	roster[1]["hp"] = 2
	roster[1]["statuses"] = {"bleed": 4}
	var tick := CombatStatusTurnBatch.new().tick_side("enemies", roster)
	_check(tick["ok"] and tick["actors"][0]["hp"] == 0 and tick["events"][0].get("revives") == true,
		"a lethal owner-turn Bleed proposal flags the Wraith's pending revival")
	_check(not tick["events"][1].has("revives") and tick["actors"][1]["hp"] == 0,
		"an ordinary foe's lethal Bleed carries no revival")
	_check(roster[0]["hp"] == 3, "the proposal never writes its input")
	roster[0]["revived"] = true
	tick = CombatStatusTurnBatch.new().tick_side("enemies", roster)
	_check(tick["ok"] and not tick["events"][0].has("revives"), "a spent revival is never proposed again")
	roster[0]["revive_once"] = "true"
	_check(not CombatStatusTurnBatch.new().tick_side("enemies", roster)["ok"],
		"a malformed revive flag refuses the whole owner-turn proposal")


## AC2: lethal owner-turn Bleed is committed by the existing End Turn and settled
## by the same once-only contract.
func _test_round_flow_bleed() -> void:
	var fight := _fight(36401, [_wraith()])
	var enemies: CombatEnemies = fight["enemies"]
	enemies._enemies[0]["hp"] = 2
	enemies._enemies[0]["statuses"] = {"bleed": 3, "exposed": 2}
	_check(fight["flow"].end_turn(), "End Turn accepts the lethal Bleed beat")
	var wraith := enemies.get_enemy(1)
	_check(wraith["hp"] == 14 and wraith["revived"] == true and wraith["position"] == 1,
		"lethal owner-turn Bleed revives the Wraith at 14 HP in slot 1")
	_check(wraith["statuses"] == {"bleed": 2, "exposed": 1}, "the Bleed tick still decays every status")
	_check(fight["result"].evaluate() == CombatBattleResult.ACTIVE and fight["deck"].turn_active,
		"no victory is declared and a new player turn opens")
	enemies._enemies[0]["hp"] = 2
	_check(fight["flow"].end_turn() and enemies.is_slain(1)
		and fight["result"].evaluate() == CombatBattleResult.VICTORY,
		"a second lethal Bleed is final and wins the fight")
	var control := _fight(36401, [_ordinary()])
	control["enemies"]._enemies[0]["hp"] = 2
	control["enemies"]._enemies[0]["statuses"] = {"bleed": 3}
	_check(control["flow"].end_turn() and control["enemies"].is_slain(1)
		and control["result"].evaluate() == CombatBattleResult.VICTORY,
		"the same lethal Bleed kills an ordinary foe outright")


func _test_round_flow_damage_then_bleed() -> void:
	var fight := _fight(36402, [_wraith(), _ordinary()])
	var enemies: CombatEnemies = fight["enemies"]
	_check(enemies.apply_damage(1, 27) and enemies.get_enemy(1)["hp"] == 14,
		"a lethal card blow in a live fight revives the Wraith")
	_check(fight["flow"].end_turn() and enemies.get_enemy(1)["revived"] == true,
		"the revival latch survives a real End Turn")
	enemies._enemies[0]["hp"] = 1
	enemies._enemies[0]["statuses"] = {"bleed": 1}
	_check(fight["flow"].end_turn() and enemies.is_slain(1) and enemies.get_enemy(2)["hp"] == 12
		and fight["result"].evaluate() == CombatBattleResult.ACTIVE,
		"after a blow revival, a lethal Bleed is final while the other foe fights on")


func _test_round_flow_refusal() -> void:
	var fight := _fight(36403, [_wraith(), _ordinary()])
	var enemies: CombatEnemies = fight["enemies"]
	enemies._enemies[0]["hp"] = 2
	enemies._enemies[0]["statuses"] = {"bleed": 3}
	enemies._enemies[1]["revive_once"] = "yes"
	var before := _snapshot(fight)
	var raw := enemies._enemies.duplicate(true)
	_check(not fight["flow"].end_turn(), "End Turn refuses a roster with a malformed revive flag")
	_check(enemies._enemies == raw and _snapshot(fight) == before,
		"the refused End Turn leaves party, enemies, hand, energy, phase and RNG unchanged")


func _test_replay() -> void:
	var first: Array = []
	for run in range(2):
		var fight := _fight(36404, [_wraith(), _ordinary()])
		var enemies: CombatEnemies = fight["enemies"]
		enemies.apply_damage(1, 30)
		enemies._enemies[0]["statuses"] = {"bleed": 2}
		fight["flow"].end_turn()
		fight["flow"].end_turn()
		var snap := _snapshot(fight)
		if run == 0:
			first = [snap]
		else:
			_check(snap == first[0], "the same seed replays the same revival, statuses, hand and RNG")
