extends SceneTree
## Design v4 S9a: Wren's four free hand actions in the rules core and the run session.
## Covers Steady, Shield the Candle, Hold Back and Lift, the one-per-round budget (also
## after a reload), the seeded fear-50 shaky failure, no Lift across a snipped thread,
## seed replay, and the fear-100 lost-strings turn skip.

const FIXTURE := "res://tests/fixtures/stitched_s1a_parts.json"

var checks := 0
var failures: Array[String] = []


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	_catalog()
	_steady_and_budget()
	_shield_candle()
	_hold_back()
	_lift_and_snips()
	_shaky_hands_and_replay()
	_session_save_and_lost_strings()
	if failures.is_empty():
		print("stitched_s9a_hand_actions_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		print("stitched_s9a_hand_actions_test: FAIL (%d failures)" % failures.size())
		quit(1)


func _ability(id: String, kind: String, effects: Dictionary = {}) -> Dictionary:
	return {
		"id": id, "name": id, "kind": kind, "launch": [1, 2, 3, 4],
		"target": [1, 2, 3, 4], "target_side": "enemy", "acc": 100,
		"dmg": [1, 1], "crit": 0, "effects": effects, "move": "attack",
	}


func _hero(id: String, speed: int, head: String, arms: String, torso: String, legs: String) -> Dictionary:
	return {
		"id": id, "name": id.capitalize(), "max_hp": 40, "speed": speed,
		"dodge": 0, "acc": 0, "prot": 0,
		"parts": {"head": head, "arms": arms, "torso": torso, "legs": legs},
	}


func _battle(seed_value: int, light: int = 100) -> StitchedRules:
	var catalog := StitchedParts.load_catalog(FIXTURE)
	var parts: Array = catalog["parts"]
	var heroes := [
		_hero("warden", 8, "any_head_needle_pin", "warden_arm_shield_bash", "warden_torso_quilt", "warden_legs_stride"),
		_hero("seamstress", 7, "warden_head_button_eye", "warden_arm_brace", "warden_torso_rivet", "any_legs_stitch_step"),
		_hero("tinker", 6, "any_head_needle_pin", "any_arm_red_thread", "warden_torso_rivet", "warden_legs_stride"),
		_hero("monk", 5, "warden_head_button_eye", "warden_arm_brace", "any_torso_felt_coat", "any_legs_stitch_step"),
	]
	var foes: Array = []
	for i in range(3):
		foes.append({
			"id": "foe_%d" % i, "name": "Foe %d" % i, "max_hp": 30,
			"speed": i + 1, "dodge": 0, "acc": 0, "prot": 0,
			"abilities": [_ability("foe_hit", "melee")],
		})
	var built := StitchedRules.create({"seed": seed_value, "parts": parts, "heroes": heroes, "foes": foes, "candle": light})
	_check(bool(built["ok"]), "seeded 4v3 battle builds: " + str(built.get("error", "")))
	return built["battle"] if built["ok"] else null


func _to_side(battle: StitchedRules, side: String) -> bool:
	for step in range(60):
		if battle.is_over():
			return false
		if battle.current_side() == side:
			return true
		battle.pass_turn()
	return false


func _hero_at(battle: StitchedRules, rank: int) -> Dictionary:
	for hero in battle.get_heroes():
		if int(hero.rank) == rank and not bool(hero.lost):
			return hero
	return {}


func _next_round(battle: StitchedRules) -> void:
	var round_now := battle.round_number()
	for step in range(60):
		if battle.round_number() != round_now or battle.is_over():
			break
		battle.pass_turn()
	_to_side(battle, "hero")


func _catalog() -> void:
	var book := StitchedKidHandActions.catalog()
	_check(bool(book.get("ok", false)), "hand_actions.json loads: " + str(book.get("error", "")))
	_check(book.get("order", []) == ["steady", "shield_candle", "hold_back", "lift"], "exactly the four authored hand actions")
	_check(int(book.by_id["steady"]["fray"]) == -8, "Steady is -8 fray in data")
	var fifth: Array = []
	for id in book.order:
		fifth.append(book.by_id[id].duplicate())
	fifth.append({"id": "pinch", "name": "Pinch", "target": "doll", "text": "x"})
	_check(not bool(StitchedKidHandActions.validate({"actions": fifth}).ok), "a fifth hand action is refused")
	_check(not bool(StitchedKidHandActions.validate({"actions": fifth.slice(0, 3)}).ok), "three hand actions are refused")


func _steady_and_budget() -> void:
	var battle := _battle(11)
	if battle == null or not _to_side(battle, "hero"):
		_check(false, "Steady reaches a doll turn")
		return
	var actor := battle.current_actor_id()
	var turn: int = battle.state_snapshot()["turn_index"]
	battle.apply_fray_event("tinker", 20, "event")
	var before := int(battle.get_unit("tinker").fray)
	_check(battle.hand_action_open(), "the round's hand action starts open on a doll turn")
	_check(not StitchedKidHandActions.choices(battle).is_empty(), "choices lists legal hand actions")
	var rng_before := battle.rng_state()
	var receipt := battle.use_hand_action("steady", "tinker", 0, 0)
	_check(bool(receipt.ok) and not bool(receipt.failed), "Steady succeeds at fear 0")
	_check(int(battle.get_unit("tinker").fray) == maxi(0, before - 8), "Steady takes exactly 8 fray")
	_check(battle.rng_state() == rng_before, "a calm hand draws no random number")
	_check(battle.current_actor_id() == actor and battle.state_snapshot()["turn_index"] == turn, "a hand action never spends the doll's turn")
	_check(not battle.hand_action_open() and StitchedKidHandActions.choices(battle).is_empty(), "the hand is spent for the round")
	var again := battle.use_hand_action("steady", "tinker", 0, 0)
	_check(not bool(again.ok), "a second hand action in the same round is refused")
	_check(battle.hand_receipts().size() == 1, "exactly one hand receipt per round")
	_check(not bool(battle.use_hand_action("lift", "ghost", 1, 0).ok), "an unknown doll is refused")
	_check(not bool(battle.use_hand_action("shield_candle", "warden", 0, 0).ok), "spent budget refuses every action")
	_to_side(battle, "foe")
	_check(not bool(battle.use_hand_action("steady", "tinker", 0, 0).ok), "no hand action on a foe turn")
	_next_round(battle)
	_check(battle.hand_action_open(), "the hand opens again next round")
	_check(not bool(battle.use_hand_action("dance", "tinker", 0, 0).ok) and battle.hand_action_open(),
		"an unknown action is refused without spending the hand")
	_check(not bool(battle.use_hand_action("steady", "tinker", 1, 0).ok) and battle.hand_action_open(),
		"only Lift takes a direction")


func _shield_candle() -> void:
	var plain := _battle(12, 10)
	var shielded := _battle(12, 10)
	if plain == null or shielded == null or not _to_side(plain, "hero") or not _to_side(shielded, "hero"):
		_check(false, "Shield the Candle reaches a doll turn")
		return
	var receipt := shielded.use_hand_action("shield_candle", "", 0, 0)
	_check(bool(receipt.ok) and shielded.candle_shielded(), "Shield the Candle shields this round")
	_check(not bool(_battle(12, 10).use_hand_action("shield_candle", "warden", 0, 0).ok), "Shield the Candle takes no doll")
	var gained_plain: int = plain.apply_fray_event("monk", 10, "event").change
	var gained_shielded: int = shielded.apply_fray_event("monk", 10, "event").change
	_check(gained_plain > 10, "a snuffed candle adds fray without the shield (%d)" % gained_plain)
	_check(gained_shielded == 10, "the shielded candle adds no fray (%d)" % gained_shielded)
	_next_round(shielded)
	_check(not shielded.candle_shielded() and int(shielded.apply_fray_event("monk", 10, "event").change) > 10,
		"the shield lasts one round only")


func _hold_back() -> void:
	var battle := _battle(13)
	if battle == null or not _to_side(battle, "hero"):
		_check(false, "Hold Back reaches a doll turn")
		return
	var actor := battle.current_actor_id()
	var rank := int(battle.get_unit(actor).rank)
	var direction := 1 if rank < 4 else -1
	var neighbour := _hero_at(battle, rank + direction)
	_check(bool(battle.use_hand_action("hold_back", str(neighbour.id), 0, 0).ok), "Hold Back pins one doll")
	_check(battle.is_held(str(neighbour.id)), "the held doll is marked for this round")
	_check(not bool(battle.move(direction).ok), "nobody can swap with a held doll")
	_check(not bool(battle._shift_valid(battle._units[str(neighbour.id)], -direction).ok), "a held doll cannot be shoved or pulled")
	_check(not bool(battle._shift_valid(battle._units[actor], direction).ok), "a held doll cannot be displaced by a shoved ally")
	_check(battle.current_actor_id() == actor, "refused moves leave the turn alone")
	_next_round(battle)
	_check(not battle.is_held(str(neighbour.id)), "Hold Back ends with the round")


func _lift_and_snips() -> void:
	var battle := _battle(14)
	if battle == null or not _to_side(battle, "hero"):
		_check(false, "Lift reaches a doll turn")
		return
	var actor := battle.current_actor_id()
	var front := _hero_at(battle, 1)
	var second := _hero_at(battle, 2)
	var receipt := battle.use_hand_action("lift", str(front.id), 1, 0)
	_check(bool(receipt.ok) and int(battle.get_unit(str(front.id)).rank) == 2 and int(battle.get_unit(str(second.id)).rank) == 1,
		"Lift moves one doll one rank, swapping the ally")
	_check(battle.current_actor_id() == actor, "Lift does not use any doll's turn")
	_check(not bool(_battle(14).use_hand_action("lift", str(front.id), 0, 0).ok), "Lift needs a direction")
	_check(StitchedKidHandActions.validate({"actions": []}).ok == false, "an empty catalog is invalid")
	# Snip the rank-2 doll on a foe turn, then try to lift it or across its cut.
	var cut := _battle(15)
	if cut == null or not _to_side(cut, "foe"):
		_check(false, "snip test reaches a foe turn")
		return
	var snipped := _hero_at(cut, 2)
	_check(bool(cut.snip_thread(str(snipped.id)).ok), "a foe snips the rank-2 doll's thread")
	if not _to_side(cut, "hero"):
		_check(false, "snip test reaches a doll turn")
		return
	_check(not bool(cut.use_hand_action("lift", str(snipped.id), 1, 0).ok), "a snipped doll cannot be lifted")
	_check(not bool(cut.use_hand_action("lift", str(snipped.id), -1, 0).ok), "a snipped doll cannot be lifted forward either")
	var across_blocked := false
	for rank in [1, 3]:
		var other := _hero_at(cut, rank)
		var toward: int = 2 - rank
		if not other.is_empty() and not cut.hand_action_check("lift", str(other.id), toward).is_empty():
			across_blocked = true
	_check(across_blocked, "no Lift crosses the snipped thread")
	for choice in StitchedKidHandActions.choices(cut):
		_check(not (choice.action == "lift" and choice.target == str(snipped.id)), "choices never offer lifting the snipped doll")
	_check(cut.hand_action_open(), "refused lifts leave the hand unspent")


func _shaky_hands_and_replay() -> void:
	var calm := _battle(16)
	if calm == null or not _to_side(calm, "hero"):
		_check(false, "shaky test reaches a doll turn")
		return
	var rng_before := calm.rng_state()
	_check(int(calm.use_hand_action("steady", "warden", 0, 49).roll) == 0 and calm.rng_state() == rng_before,
		"fear 49 is below the shake: no roll")
	var failed := 0
	var held := 0
	for seed_value in range(1, 80):
		var a := _battle(seed_value)
		var b := _battle(seed_value)
		if a == null or b == null or not _to_side(a, "hero") or not _to_side(b, "hero"):
			continue
		var target := str(_hero_at(a, 1).id)
		var ra := a.use_hand_action("hold_back", target, 0, 50)
		var rb := b.use_hand_action("hold_back", target, 0, 50)
		_check(int(ra.roll) >= 1 and int(ra.roll) <= 100, "fear 50 draws one seeded 1..100 roll")
		_check(bool(ra.failed) == (int(ra.roll) <= StitchedKidFear.HAND_FAILURE_CHANCE_PERCENT), "shaky hands fail on 1..25 exactly")
		_check(not a.hand_action_open(), "a failed attempt still spends the round's hand")
		_check(a.is_held(target) != bool(ra.failed), "a failed Hold Back changes nothing")
		_check(ra == rb and a.state_snapshot() == b.state_snapshot(), "seed %d replays the same hand roll" % seed_value)
		if bool(ra.failed):
			failed += 1
		else:
			held += 1
	_check(failed > 0 and held > failed, "seeds witness both shaky failures and successes (%d/%d)" % [failed, held])
	var snap: Dictionary = calm.state_snapshot()
	_check(snap.has("hand") and int(snap.hand.round_used) == calm.round_number() and snap.hand.receipts.size() == 1,
		"the battle snapshot carries the hand budget and receipts")


func _session_save_and_lost_strings() -> void:
	var session := StitchedRunSession.start(42)
	if session == null:
		_check(false, "run session starts")
		return
	var fight := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Fight":
			fight = id
			break
	_check(not fight.is_empty() and session.enter(fight, session.snapshot()), "the session opens a real fight")
	if session.battle == null or not _to_side(session.battle, "hero"):
		_check(false, "session fight reaches a doll turn")
		return
	var doll := session.battle.current_actor_id()
	var receipt := session.battle.use_hand_action("steady", doll, 0)
	_check(bool(receipt.ok) and int(receipt.fear) == session.kid_fear(), "the session passes Wren's own fear")
	_check(session.journal.back() == {"action": "battle", "method": "use_hand_action", "arguments": ["steady", doll, 0]},
		"the hand action is journaled exactly once")
	_check(session.is_consistent(), "the session stays sealed after a hand action")
	var document := StitchedRunSave.capture(session)
	var restored := StitchedRunSave.restore(bytes_to_var(var_to_bytes(document)))
	_check(restored != null and restored.snapshot() == session.snapshot(), "a mid-round save restores the hand receipt exactly")
	if restored != null:
		_check(not restored.battle.hand_action_open(), "the reloaded round keeps its one-use budget")
		_check(not bool(restored.battle.use_hand_action("steady", doll, 0).ok), "the reloaded round refuses a second hand action")
	var forged := document.duplicate(true)
	forged.state.battle.erase("hand")
	forged.digest = StitchedRunSave._digest(forged)
	_check(StitchedRunSave.restore(forged) == null, "an old-format save cannot smuggle in a hand action")
	var plain := StitchedRunSession.start(42)
	plain.enter(fight, plain.snapshot())
	plain.battle.pass_turn()
	var legacy := StitchedRunSave.capture(plain)
	legacy.state.battle.erase("hand")
	legacy.digest = StitchedRunSave._digest(legacy)
	_check(StitchedRunSave.restore(legacy) != null, "a pre-S9a mid-battle save still restores")
	# Fear 100: the first doll turn of the next fight is skipped and fear drops to 60.
	var scared := StitchedRunSession.start(42)
	scared._kid_fear = StitchedKidFear.new(100)
	scared._seal()
	_check(scared.enter(fight, scared.snapshot()), "a frightened run still opens the fight")
	for step in range(12):
		if scared.battle.is_over() or not scared._kid_fear.get_fear() == 100:
			break
		scared.battle.pass_turn()
	var skips: Array = []
	for event in scared.battle.turn_events():
		if event.get("action") == "lost_strings":
			skips.append(event)
	_check(skips.size() == 1, "losing the strings skips exactly one doll turn")
	_check(skips.size() == 1 and str(scared.battle.get_unit(str(skips[0].actor)).side) == "hero", "the skipped turn is a doll's")
	_check(scared.kid_fear() == StitchedKidFear.RESET_FEAR_AFTER_LOST_STRINGS, "fear drops to 60 after the lost strings")
	_check(scared.is_consistent(), "the skip is sealed into the session")
