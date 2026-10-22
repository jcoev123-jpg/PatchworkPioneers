extends SceneTree
## Standalone D2-1 resolver regression. This does NOT assert live hand wiring.

var failures: Array[String] = []
var checks := 0
var resolver := CombatSeamstressPoolControl.new()

const PIN := "seamstress_needle_pin"
const PIN_PLUS := "seamstress_needle_pin_plus"
const SNAG := "seamstress_snag"
const SNAG_PLUS := "seamstress_snag_plus"
const UNPICK := "seamstress_unpick"
const UNPICK_PLUS := "seamstress_unpick_plus"


func _initialize() -> void:
	_test_needle_pin()
	_test_snag()
	_test_unpick()
	_test_rejections()
	_test_replay()
	if failures.is_empty():
		print("combat_seamstress_pool_control_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("combat_seamstress_pool_control_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _fixture(cards: Array[String], seamstress_position: int = 2,
		seed_value: int = 241) -> Dictionary:
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	# Reorder the actual authoritative position-indexed CombatParty actors
	# after construction, rather than telling the resolver an invented slot.
	if seamstress_position != 2:
		var exchanged: Dictionary = party._heroes[seamstress_position - 1]
		party._heroes[seamstress_position - 1] = party._heroes[1]
		party._heroes[1] = exchanged
		party._heroes[seamstress_position - 1]["position"] = seamstress_position
		party._heroes[1]["position"] = 2
	var enemies := CombatEnemies.new([
		{"id": "normal_foe", "max_hp": 18},
		{"id": "elite_foe", "max_hp": 22},
		{"id": "boss_foe", "max_hp": 30}])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck_ids: Array[String] = cards.duplicate()
	while deck_ids.size() < 5:
		deck_ids.append("filler_%d" % deck_ids.size())
	var deck := CombatDeck.new(deck_ids, rng)
	var pinned := CombatPinned.new()
	var unravel := CombatUnravel.new()
	_check(party.is_valid() and enemies.is_valid()
			and party.get_hero(seamstress_position)["id"] == "seamstress"
			and party.get_hero(seamstress_position)["hp"] == 30,
			"fixture has genuine living Seamstress at current slot %d" % seamstress_position)
	_check(unravel.bind_roster(enemies, {1: "normal", 2: "elite", 3: "boss"}),
		"gauge is bound to exact original slots and tiers")
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
			and deck.hand.size() == 5 and deck._rng == rng,
			"seeded CombatDeck begins real active five-card turn")
	for card_id: String in cards:
		_check(deck.hand.has(card_id), "authored play is genuinely held: " + card_id)
	return {"deck": deck, "party": party, "enemies": enemies,
		"pinned": pinned, "unravel": unravel}


func _play(f: Dictionary, card_id: String, target: int) -> Dictionary:
	return resolver.play_card(f["deck"], f["party"], f["enemies"],
		f["pinned"], f["unravel"], card_id, target)


func _state(f: Dictionary) -> Dictionary:
	var deck: CombatDeck = f["deck"]
	var unravel: CombatUnravel = f["unravel"]
	var pinned: CombatPinned = f["pinned"]
	return {
		"draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "turn": deck.turn_active,
		"energy": deck.energy, "rng": deck._rng.state,
		"heroes": f["party"].get_heroes(), "enemies": f["enemies"].get_enemies(),
		"tokens": pinned._pinner_by_position.duplicate(true),
		"gauges": unravel._gauges.duplicate(true),
		"tiers": unravel._tiers_by_position.duplicate(true),
		"bound_roster": unravel._bound_enemies
	}


func _spent_once(before: Dictionary, f: Dictionary, card_id: String, label: String) -> void:
	var after: Dictionary = _state(f)
	_check(after["energy"] == before["energy"] - 1
			and after["hand"].size() == before["hand"].size() - 1
			and after["hand"].count(card_id) == before["hand"].count(card_id) - 1
			and after["discard"].size() == before["discard"].size() + 1
			and after["discard"][-1] == card_id
			and after["draw"] == before["draw"] and after["rng"] == before["rng"]
			and after["heroes"] == before["heroes"],
			label + " spends one energy, discards one copy and preserves RNG/party")


func _test_needle_pin() -> void:
	var f: Dictionary = _fixture([PIN, PIN], 1)
	var enemies: CombatEnemies = f["enemies"]
	var party: CombatParty = f["party"]
	var pinned: CombatPinned = f["pinned"]
	party._heroes[0]["statuses"] = {"weak": 1}
	_check(enemies.gain_block(1, 4) and enemies.apply_statuses({1: {"exposed": 1}})
			and pinned.pin_enemy(enemies, 1, "warden"), "cross-hero pin/status/Block prepared")
	var before: Dictionary = _state(f)
	var other: Array[Dictionary] = [enemies.get_enemy(2), enemies.get_enemy(3)]
	var r: Dictionary = _play(f, PIN, 1)
	# (3 + 5) * 0.75 * 1.5 = 9, one floor; Block 4 absorbs first.
	_check(r["ok"] and r["damage"] == 9 and r["block_absorbed"] == 4
			and r["hp_loss"] == 5 and r["pinned_bonus"] == 5
			and r["pinner"] == "seamstress", "Needle Pin uses prior +5 before real Weak/Exposed")
	_check(enemies.get_enemy(1)["hp"] == 13 and enemies.get_enemy(1)["block"] == 0
			and pinned.pinner_for_enemy(1) == "seamstress",
			"surviving enemy is repinned by Seamstress after confirmed hit")
	_check([enemies.get_enemy(2), enemies.get_enemy(3)] == other,
		"other original slots remain untouched")
	_spent_once(before, f, PIN, "Needle Pin with moved Seamstress")

	# Same-hero pin is neither consumed for bonus nor replaced with another ID.
	before = _state(f)
	r = _play(f, PIN, 1)
	_check(r["ok"] and r["pinned_bonus"] == 0 and r["damage"] == 3
			and pinned.pinner_for_enemy(1) == "seamstress",
			"same-hero follow-up adds no bonus and retains Seamstress token")
	_spent_once(before, f, PIN, "second held Needle Pin")

	f = _fixture([PIN_PLUS], 3)
	enemies = f["enemies"]
	pinned = f["pinned"]
	_check(enemies.gain_block(2, 2) and enemies.apply_statuses({2: {"exposed": 1}})
			and pinned.pin_enemy(enemies, 2, "seamstress"), "plus same-hero target prepared")
	before = _state(f)
	r = _play(f, PIN_PLUS, 2)
	_check(r["ok"] and r["damage"] == 6 and r["block_absorbed"] == 2
			and r["hp_loss"] == 4 and r["pinned_bonus"] == 0
			and pinned.pinner_for_enemy(2) == "seamstress",
			"Needle Pin+ base four Exposed -> six, Block before HP, own pin no bonus")
	_spent_once(before, f, PIN_PLUS, "Needle Pin+ moved to back")

	f = _fixture([PIN_PLUS])
	enemies = f["enemies"]
	pinned = f["pinned"]
	_check(enemies.apply_damage(1, 12) and pinned.pin_enemy(enemies, 1, "tinker"),
		"lethal target has six HP and different hero pin")
	other = [enemies.get_enemy(2), enemies.get_enemy(3)]
	before = _state(f)
	r = _play(f, PIN_PLUS, 1)
	_check(r["ok"] and r["damage"] == 9 and r["hp_loss"] == 6
			and enemies.is_slain(1) and pinned.pinner_for_enemy(1) == ""
			and r["pinner"] == "", "lethal confirmed pin bonus consumed with no new pin")
	_check([enemies.get_enemy(2), enemies.get_enemy(3)] == other,
		"lethal play preserves unrelated enemies")
	_spent_once(before, f, PIN_PLUS, "lethal Needle Pin+")


func _test_snag() -> void:
	for record: Dictionary in [
		{"id": SNAG, "position": 2, "amount": 3},
		{"id": SNAG_PLUS, "position": 3, "amount": 4}
	]:
		var card_id: String = record["id"]
		var f: Dictionary = _fixture([card_id], record["position"])
		var enemies: CombatEnemies = f["enemies"]
		_check(enemies.gain_block(1, 6), "Snag target has retained Block")
		var before: Dictionary = _state(f)
		var r: Dictionary = _play(f, card_id, 1)
		var gauge: Dictionary = f["unravel"].get_snapshot(1)
		_check(r["ok"] and r["damage"] == 0 and r["hp_loss"] == 0
				and r["block_absorbed"] == 0 and r["weak_applied"] == 1
				and r["unravel_applied"] == record["amount"],
				card_id + " applies authored Weak and gauge, zero damage")
		_check(gauge["gauge"] == record["amount"] and gauge["threshold"] == 8
				and not gauge["skip_pending"] and r["unravel_snapshot"] == gauge
				and enemies.get_enemy(1)["statuses"] == {"weak": 1}
				and enemies.get_enemy(1)["hp"] == 18 and enemies.get_enemy(1)["block"] == 6
				and enemies.get_enemy(2) == before["enemies"][1]
				and enemies.get_enemy(3) == before["enemies"][2]
				and f["pinned"]._pinner_by_position.is_empty(),
				card_id + " mutates only real selected status/gauge")
		_spent_once(before, f, card_id, card_id)

	var f: Dictionary = _fixture([SNAG_PLUS, SNAG_PLUS, SNAG_PLUS])
	var u: CombatUnravel = f["unravel"]
	for index in range(3):
		var r: Dictionary = _play(f, SNAG_PLUS, 1)
		_check(r["ok"], "successive held Snag+ copy resolves")
	var gauge: Dictionary = u.get_snapshot(1)
	_check(gauge == {"gauge": 8, "threshold": 8,
		"unravelled": true, "skip_pending": true}
		and f["enemies"].get_enemy(1)["statuses"]["weak"] == 3,
		"threshold clamps at eight with exactly one pending skip despite extra charge")
	_check(u.consume_action_skip(f["enemies"], 1)
			and u.get_snapshot(1) == {"gauge": 0, "threshold": 12,
				"unravelled": false, "skip_pending": false}
			and not u.consume_action_skip(f["enemies"], 1),
			"only later enemy action-skip consumption resets gauge and increases threshold")


func _test_unpick() -> void:
	var f: Dictionary = _fixture([UNPICK, UNPICK_PLUS, UNPICK_PLUS], 1)
	var enemies: CombatEnemies = f["enemies"]
	var pinned: CombatPinned = f["pinned"]
	var u: CombatUnravel = f["unravel"]
	_check(u.get_snapshot(1)["threshold"] == 8
			and u.get_snapshot(2)["threshold"] == 12
			and u.get_snapshot(3)["threshold"] == 16,
			"real normal/elite/boss thresholds start 8/12/16")
	_check(enemies.gain_block(1, 4) and pinned.pin_enemy(enemies, 2, "tinker"),
		"Unpick fixtures preserve existing enemy Block/Pinned")
	var before: Dictionary = _state(f)
	var r: Dictionary = _play(f, UNPICK, 1)
	_check(r["ok"] and r["unravel_applied"] == 5 and u.get_snapshot(1)["gauge"] == 5
			and r["weak_applied"] == 0, "Unpick applies only five gauge")
	_spent_once(before, f, UNPICK, "Unpick base")
	before = _state(f)
	r = _play(f, UNPICK_PLUS, 1)
	_check(r["ok"] and r["unravel_applied"] == 7
			and u.get_snapshot(1)["gauge"] == 8
			and u.get_snapshot(1)["skip_pending"], "Unpick+ completes normal threshold")
	_spent_once(before, f, UNPICK_PLUS, "Unpick+")
	_check(enemies.get_enemies() == before["enemies"]
			and pinned.pinner_for_enemy(2) == "tinker"
			and u.get_snapshot(2)["gauge"] == 0 and u.get_snapshot(3)["gauge"] == 0,
			"Unpick affects no HP/Block/status/token or other gauges")
	_check(u.consume_action_skip(enemies, 1)
			and u.get_snapshot(1)["threshold"] == 12
			and u.get_snapshot(1)["gauge"] == 0,
			"normal after actual skipped action raises threshold four")

	f = _fixture([UNPICK, UNPICK_PLUS], 2)
	u = f["unravel"]
	_check(_play(f, UNPICK, 2)["ok"] and u.get_snapshot(2)["gauge"] == 5,
		"elite gauge progresses after Unpick")
	_check(_play(f, UNPICK_PLUS, 2)["ok"]
			and u.get_snapshot(2)["gauge"] == 12 and u.get_snapshot(2)["skip_pending"],
			"elite threshold twelve reached by both authored variants")
	_check(u.consume_action_skip(f["enemies"], 2)
			and u.get_snapshot(2)["threshold"] == 16,
			"elite actual skip increases threshold to sixteen")

	f = _fixture([UNPICK, UNPICK, UNPICK_PLUS], 3)
	u = f["unravel"]
	for card_id: String in [UNPICK, UNPICK, UNPICK_PLUS]:
		_check(_play(f, card_id, 3)["ok"], "boss legal charge succeeds: " + card_id)
	_check(u.get_snapshot(3)["gauge"] == 16
			and u.get_snapshot(3)["unravelled"] and u.get_snapshot(3)["skip_pending"],
			"boss threshold sixteen clamps combined seventeen")
	_check(u.consume_action_skip(f["enemies"], 3)
			and u.get_snapshot(3)["threshold"] == 20
			and not u.get_snapshot(3)["skip_pending"],
			"boss skip resets gauge and increases threshold by four")


func _reject(f: Dictionary, card_id: String, target: int,
		pinned: CombatPinned, unravel: CombatUnravel, reason: String) -> void:
	var before: Dictionary = _state(f)
	var r: Dictionary = resolver.play_card(
		f["deck"], f["party"], f["enemies"], pinned, unravel, card_id, target)
	_check(not r.get("ok", false), reason + " must reject")
	_check(_state(f) == before, reason + " has no deck/party/enemy/pin/gauge/RNG mutation")


func _test_rejections() -> void:
	var f: Dictionary = _fixture([PIN, SNAG, UNPICK, "seamstress_darning"])
	var p: CombatPinned = f["pinned"]
	var u: CombatUnravel = f["unravel"]
	_check(p.pin_enemy(f["enemies"], 2, "warden"), "reject fixture has existing pin")
	_reject(f, PIN_PLUS, 1, p, u, "unheld authored ID")
	_reject(f, "unknown_card", 1, p, u, "unknown card")
	_reject(f, "seamstress_darning", 1, p, u, "held unsupported pool card")
	_reject(f, PIN, 0, p, u, "illegal target 0")
	_reject(f, PIN, 4, p, u, "unoccupied slot 4")
	_reject(f, PIN, 1, null, u, "missing Pinned authority")
	_reject(f, SNAG, 1, p, null, "missing gauge authority")
	_reject(f, UNPICK, 1, p, CombatUnravel.new(), "unbound gauge")
	var alien := CombatEnemies.new([{"id": "alien", "max_hp": 10}])
	var wrong := CombatUnravel.new()
	_check(wrong.bind_roster(alien, {1: "normal"}), "different roster gauge genuinely bound")
	_reject(f, SNAG, 1, p, wrong, "wrong-roster gauge on Snag")
	_reject(f, UNPICK, 1, p, wrong, "wrong-roster gauge on Unpick")

	f = _fixture([SNAG], 1)
	_reject(f, SNAG, 1, f["pinned"], f["unravel"], "Snag from illegal slot one")
	f = _fixture([PIN])
	_check(f["party"].apply_damage(2, 30) and f["party"].is_downed(2),
		"Seamstress downed fixture")
	_reject(f, PIN, 1, f["pinned"], f["unravel"], "downed Seamstress")
	f = _fixture([PIN])
	_check(f["enemies"].apply_damage(1, 18) and f["enemies"].is_slain(1),
		"dead enemy fixture")
	_reject(f, PIN, 1, f["pinned"], f["unravel"], "slain target")
	f = _fixture([PIN])
	_check(f["deck"].try_spend_energy(3), "depleted-energy fixture")
	_reject(f, PIN, 1, f["pinned"], f["unravel"], "insufficient energy")
	f = _fixture([PIN])
	_check(f["deck"].end_turn() and not f["deck"].turn_active,
		"ended real player turn fixture")
	_reject(f, PIN, 1, f["pinned"], f["unravel"], "inactive turn")
	f = _fixture([SNAG])
	f["enemies"]._enemies[0]["statuses"] = {"weak": CombatEnemies.MAX_INT}
	_reject(f, SNAG, 1, f["pinned"], f["unravel"], "Weak overflow preflight")

	f = _fixture([UNPICK])
	f["party"]._heroes[0]["statuses"] = {"unknown": 1}
	_reject(f, UNPICK, 1, f["pinned"], f["unravel"], "invalid real hero status")


func _test_replay() -> void:
	var left: Dictionary = _fixture([PIN, SNAG_PLUS, UNPICK_PLUS], 3, 985)
	var right: Dictionary = _fixture([PIN, SNAG_PLUS, UNPICK_PLUS], 3, 985)
	for f: Dictionary in [left, right]:
		_check(f["pinned"].pin_enemy(f["enemies"], 1, "warden")
				and f["enemies"].gain_block(1, 2), "independent replay primed")
	_check(_state(left) == _state(right) or
			_state(left)["rng"] == _state(right)["rng"],
			"identical seed begins with identical run RNG")
	var rng_before: int = left["deck"]._rng.state
	var results_left: Array[Dictionary] = [
		_play(left, PIN, 1), _play(left, SNAG_PLUS, 2), _play(left, UNPICK_PLUS, 3)]
	var results_right: Array[Dictionary] = [
		_play(right, PIN, 1), _play(right, SNAG_PLUS, 2), _play(right, UNPICK_PLUS, 3)]
	var a: Dictionary = _state(left)
	var b: Dictionary = _state(right)
	a.erase("bound_roster")
	b.erase("bound_roster")
	_check(results_left == results_right and results_left.all(func(r: Dictionary) -> bool:
		return r["ok"]), "independent equal-seed replay matches every resolved event")
	_check(a == b and a["rng"] == rng_before and b["rng"] == rng_before,
		"independent replay matches all authoritative snapshots without RNG draws")
