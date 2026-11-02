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

const ENEMIES_PATH := "res://data/enemies/run_enemies.json"
## Four distinct authored run foes, chosen by ID (never by catalog position or
## a hard-coded catalog total) for the explicitly opted-in four-slot roster.
const FOUR_FOE_IDS := ["button_guard", "spool_stalker", "seam_ripper", "felt_bulwark"]
## Tier-bound gauge for all four occupied slots: 8 / 12 / 16 / 8.
const FOUR_TIERS := {1: "normal", 2: "elite", 3: "boss", 4: "normal"}


func _initialize() -> void:
	_test_needle_pin()
	_test_snag()
	_test_unpick()
	_test_rejections()
	_test_replay()
	_test_four_foe_legal_targets()
	_test_four_foe_rejections()
	_test_four_foe_replay()
	_test_sewn_attack_patches()
	_test_head_weak()
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


func _party(seamstress_position: int = 2) -> CombatParty:
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
	return party


func _fixture(cards: Array[String], seamstress_position: int = 2,
		seed_value: int = 241) -> Dictionary:
	var party := _party(seamstress_position)
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


## Four distinct records authenticated from the shipped run catalog by ID.
func _four_records() -> Array:
	var catalog: Array = RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string(ENEMIES_PATH))
	_check(not catalog.is_empty(), "shipped run_enemies.json enemy catalog loads")
	var selected: Array = []
	for required: String in FOUR_FOE_IDS:
		var matches: Array = catalog.filter(func(entry: Variant) -> bool:
			return entry is Dictionary and entry.get("id") == required)
		_check(matches.size() == 1,
			"authored four-foe source present exactly once: " + required)
		if matches.size() == 1:
			selected.append(matches[0].duplicate(true))
	return selected


## The same resolvers, party and seeded deck as `_fixture`, but over an
## explicitly opted-in four-capacity roster of four genuine authored foes.
func _four_fixture(cards: Array[String], seamstress_position: int = 3,
		seed_value: int = 1307) -> Dictionary:
	var records := _four_records()
	_check(records.size() == 4, "four distinct authenticated enemy records selected")
	var enemies := CombatEnemies.new(records, CombatEnemies.OPT_IN_MAX_ENEMIES)
	var party := _party(seamstress_position)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck_ids: Array[String] = cards.duplicate()
	while deck_ids.size() < 5:
		deck_ids.append("filler_%d" % deck_ids.size())
	var deck := CombatDeck.new(deck_ids, rng)
	var pinned := CombatPinned.new()
	var unravel := CombatUnravel.new()
	_check(enemies.is_valid() and enemies.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES
			and enemies.get_enemies().size() == 4
			and enemies.get_enemies().map(func(foe: Dictionary) -> Variant:
				return foe.get("id")) == FOUR_FOE_IDS
			and enemies.get_enemies().map(func(foe: Dictionary) -> Variant:
				return foe.get("position")) == [1, 2, 3, 4]
			and enemies.get_enemies().all(func(foe: Dictionary) -> bool:
				return foe.get("hp") == foe.get("max_hp") and foe.get("hp") > 0),
			"explicit opt-in roster really holds four living authored slots")
	_check(party.is_valid() and party.get_hero(seamstress_position)["id"] == "seamstress"
			and party.get_hero(seamstress_position)["hp"] == 30,
			"four-foe fixture has genuine living Seamstress at current slot %d" % seamstress_position)
	_check(unravel.bind_roster(enemies, FOUR_TIERS)
			and unravel.get_snapshot(1).threshold == 8
			and unravel.get_snapshot(2).threshold == 12
			and unravel.get_snapshot(3).threshold == 16
			and unravel.get_snapshot(4).threshold == 8,
			"gauge is bound to all four exact original slots and tiers")
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
			and deck.hand.size() == 5 and deck._rng == rng,
			"seeded CombatDeck begins real active five-card turn beside four foes")
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
		"bound_roster": unravel._bound_enemies,
		"patch_latch": null if resolver._patches == null else resolver._patches.latch_snapshot()
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


## The shipped cards' printed reach is unchanged by the fourth occupied slot:
## every printed living target 1-3 resolves for real, and slot four is inert.
func _test_four_foe_legal_targets() -> void:
	var authored := SeamstressPoolCards.new()
	for card_id: String in [PIN, PIN_PLUS, SNAG, SNAG_PLUS, UNPICK, UNPICK_PLUS]:
		var definition: Dictionary = authored.get_definition(card_id)
		var effects: Dictionary = definition["effects"]
		_check(definition["to_positions"] == [1, 2, 3],
			card_id + " still prints exactly the three authored enemy target slots")
		for target in [1, 2, 3]:
			var f: Dictionary = _four_fixture([card_id])
			var enemies: CombatEnemies = f["enemies"]
			var gauges: CombatUnravel = f["unravel"]
			var before: Dictionary = _state(f)
			var label := "%s against four foes at slot %d" % [card_id, target]
			var r: Dictionary = _play(f, card_id, target)
			_check(r.get("ok", false),
				label + " is a legal cast beside the authored fourth foe")
			if not r.get("ok", false):
				continue
			if effects.has("damage"):
				var expected: int = int(effects["damage"])
				_check(r["damage"] == expected and r["hp_loss"] == expected
					and r["block_absorbed"] == 0 and r["pinned_bonus"] == 0
					and r["pinner"] == "seamstress" and r["weak_applied"] == 0
					and r["unravel_applied"] == 0
					and _state(f)["gauges"] == before["gauges"],
					label + " deals exactly the authored Needle Pin damage and repins")
				_check(enemies.get_enemy(target)["hp"]
						== before["enemies"][target - 1]["hp"] - expected
					and enemies.get_enemy(target)["block"] == 0
					and enemies.get_enemy(target).get("statuses", {})
						== before["enemies"][target - 1].get("statuses", {}),
					label + " reduces only the selected foe HP")
			elif effects.has("weak"):
				var charge: int = int(effects["unravel"])
				var gauge: Dictionary = gauges.get_snapshot(target)
				_check(r["weak_applied"] == int(effects["weak"])
					and r["unravel_applied"] == charge
					and r["damage"] == 0 and r["hp_loss"] == 0
					and r["block_absorbed"] == 0
					and r["unravel_snapshot"] == gauge
					and gauge["gauge"] == charge
					and enemies.get_enemy(target)["statuses"] == {"weak": int(effects["weak"])}
					and enemies.get_enemy(target)["hp"] == before["enemies"][target - 1]["hp"],
					label + " commits exactly the authored Weak and Unravel receipt")
			else:
				var charge: int = int(effects["unravel"])
				_check(r["unravel_applied"] == charge and r["weak_applied"] == 0
					and r["damage"] == 0 and r["hp_loss"] == 0
					and gauges.get_snapshot(target)["gauge"] == charge
					and r["unravel_snapshot"] == gauges.get_snapshot(target)
					and enemies.get_enemies() == before["enemies"],
					label + " commits exactly the authored Unravel receipt and no other change")
			var after: Array = [enemies.get_enemy(1), enemies.get_enemy(2),
				enemies.get_enemy(3), enemies.get_enemy(4)]
			_check(after.map(func(foe: Dictionary) -> Variant: return foe.get("id"))
					== FOUR_FOE_IDS
				and after.map(func(foe: Dictionary) -> Variant: return foe.get("position"))
					== [1, 2, 3, 4],
				label + " keeps all four authored enemy IDs in their original slots")
			_check(after[3] == before["enemies"][3],
				label + " leaves slot four HP/Block/statuses exactly untouched")
			_check(gauges.get_snapshot(4) == before["gauges"][4]
				and gauges.get_snapshot(4)["gauge"] == 0,
				label + " never charges the fourth foe's Unravel gauge")
			for position in [1, 2, 3]:
				if position != target:
					_check(after[position - 1] == before["enemies"][position - 1],
						label + " leaves unselected slot %d untouched" % position)
			_spent_once(before, f, card_id, label)


func _test_four_foe_rejections() -> void:
	for card_id: String in [PIN, PIN_PLUS, SNAG, SNAG_PLUS, UNPICK, UNPICK_PLUS]:
		for target in [4, 5]:
			var f: Dictionary = _four_fixture([card_id])
			_reject(f, card_id, target, f["pinned"], f["unravel"],
				card_id + " target %d beyond the printed [1,2,3]" % target)

	for card_id: String in [PIN, PIN_PLUS, SNAG, SNAG_PLUS, UNPICK, UNPICK_PLUS]:
		var f: Dictionary = _four_fixture([card_id])
		_check(f["enemies"].apply_damage(2, 999) and f["enemies"].is_slain(2),
			card_id + " four-foe slain target precondition")
		_reject(f, card_id, 2, f["pinned"], f["unravel"],
			card_id + " at a slain slot beside a fourth foe")

	for card_id: String in [PIN, PIN_PLUS, SNAG, SNAG_PLUS, UNPICK, UNPICK_PLUS]:
		var f: Dictionary = _four_fixture([card_id])
		_check(f["party"].apply_damage(3, 30) and f["party"].is_downed(3),
			card_id + " four-foe downed owner precondition")
		_reject(f, card_id, 1, f["pinned"], f["unravel"],
			card_id + " from a downed Seamstress beside a fourth foe")

	for card_id: String in [PIN, PIN_PLUS, SNAG, SNAG_PLUS, UNPICK, UNPICK_PLUS]:
		var f: Dictionary = _four_fixture([card_id])
		_check(f["deck"].try_spend_energy(3), card_id + " four-foe zero-energy precondition")
		_reject(f, card_id, 1, f["pinned"], f["unravel"],
			card_id + " with insufficient energy beside a fourth foe")

	var five: Array = _four_records()
	for record: Dictionary in _four_records():
		five.append(record.duplicate(true))
	var malformed := CombatEnemies.new(five, CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(not malformed.is_valid() and malformed.get_enemies().is_empty()
			and malformed.get_enemies().size() != CombatEnemies.OPT_IN_MAX_ENEMIES,
			"five-record four-capacity roster is inert, not a legal fifth slot")
	var broken: Dictionary = _four_fixture([PIN])
	broken["enemies"] = malformed
	_reject(broken, PIN, 1, broken["pinned"], broken["unravel"],
		"malformed over-capacity four-foe roster")

	var alien_records: Array = _four_records()
	var alien := CombatEnemies.new(alien_records, CombatEnemies.OPT_IN_MAX_ENEMIES)
	var other_gauge := CombatUnravel.new()
	_check(alien.is_valid() and alien.get_enemies().size() == 4
			and other_gauge.bind_roster(alien, FOUR_TIERS),
			"separate four-foe roster gauge is genuinely bound")
	for card_id: String in [SNAG, SNAG_PLUS, UNPICK, UNPICK_PLUS]:
		var f: Dictionary = _four_fixture([card_id])
		_reject(f, card_id, 1, f["pinned"], other_gauge,
			card_id + " with a gauge bound to another four-foe roster")
	var three_tier := CombatUnravel.new()
	_check(not three_tier.bind_roster(_four_fixture([PIN])["enemies"],
			{1: "normal", 2: "elite", 3: "boss"}),
		"a three-tier gauge cannot bind a four-slot roster")
	var unbound: Dictionary = _four_fixture([UNPICK])
	_reject(unbound, UNPICK, 1, unbound["pinned"], three_tier,
		"Unpick with an unbound four-foe gauge")
	for card_id: String in [PIN, PIN_PLUS]:
		var f: Dictionary = _four_fixture([card_id])
		_reject(f, card_id, 1, null, f["unravel"],
			card_id + " without any Pinned authority beside a fourth foe")

	resolver.bind_patch_rules(CombatPatchAttackRules.new())
	var invalid_patch: Dictionary = _four_fixture([PIN])
	_reject(invalid_patch, PIN, 1, invalid_patch["pinned"], invalid_patch["unravel"],
		"explicit failed patch binding on a four-foe roster")
	resolver.bind_patch_rules(null)
	resolver.bind_head_patch_rules(CombatM05HeadPatchRules.new())
	var invalid_head: Dictionary = _four_fixture([SNAG])
	_reject(invalid_head, SNAG, 1, invalid_head["pinned"], invalid_head["unravel"],
		"explicit unbound HEAD binding on a four-foe roster")
	resolver.bind_head_patch_rules(null)


func _test_four_foe_replay() -> void:
	var left: Dictionary = _four_fixture([PIN, SNAG_PLUS, UNPICK_PLUS], 3, 4471)
	var right: Dictionary = _four_fixture([PIN, SNAG_PLUS, UNPICK_PLUS], 3, 4471)
	var slot_four: Dictionary = left["enemies"].get_enemy(4)
	_check(_state(left) == _state(right)
			or _state(left)["rng"] == _state(right)["rng"],
			"identical seed begins with identical run RNG beside four foes")
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
		return r.get("ok", false)),
		"equal-seed four-foe replay matches every resolved event")
	_check(a == b and a["rng"] == rng_before and b["rng"] == rng_before,
		"equal-seed four-foe replay matches all snapshots without RNG draws")
	_check(a["enemies"].map(func(foe: Dictionary) -> Variant: return foe.get("id"))
			== FOUR_FOE_IDS
		and a["enemies"][3] == slot_four,
		"replayed control casts leave all four IDs and slot four intact")


## Run-ledger projection, intentionally shared with the existing starter service.
func _sewn_fixture(assignments: Array, torn_seamstress: bool = false) -> Dictionary:
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(),
		["button_eye", "pincushion_arm"], [
			{"id": "button_eye", "slot": "HEAD"},
			{"id": "pincushion_arm", "slot": "ARM"}], 4)
	var torn := RunTornMending.new(party.get_heroes())
	_check(wardrobe.is_valid() and torn.is_valid(), "genuine valid run patch ledgers")
	for record in assignments:
		_check(wardrobe.sew(record.id, record.hero, record.slot,
			"sew_" + record.id, wardrobe.get_snapshot()).ok,
			"genuine sewn patch " + record.id)
	if torn_seamstress:
		var ended: Array = party.get_heroes()
		ended[1]["hp"] = 0
		_check(torn.observe_battle_end("torn_seamstress", party.get_heroes(), ended).ok,
			"torn ledger records Seamstress tear")
	var starter := CombatAttackCards.new()
	_check(starter.bind_patch_wardrobe(wardrobe, torn) and starter._patches.is_valid(),
		"starter service binds authentic projection")
	resolver.bind_patch_rules(starter._patches)
	_check(resolver._patches == starter._patches, "single exact first-hit latch shared")
	return {"starter": starter, "wardrobe": wardrobe, "torn": torn}



## True HEAD authority uses RunPatchWardrobe sewing receipts and the same
## RunTornMending ledger as a routed battle, not a synthetic bonus object.
func _head_fixture(wearer: String = "seamstress") -> Dictionary:
	var start := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}]).get_heroes()
	var wardrobe := RunPatchWardrobe.new(start, ["stern_seam_cap"],
		[{"id": "stern_seam_cap", "slot": "HEAD"}], 2)
	var torn := RunTornMending.new(start)
	_check(wardrobe.is_valid() and torn.is_valid(), "genuine M05 HEAD run ledgers start valid")
	_check(wardrobe.sew("stern_seam_cap", wearer, "HEAD", "cap_sewn",
		wardrobe.get_snapshot()).get("ok", false), "authentic HEAD sewing receipt for " + wearer)
	var head := CombatM05HeadPatchRules.new()
	_check(head.bind_wardrobe(wardrobe, torn) and head.read_projection().get("ok", false),
		"fresh genuine HEAD projection binds " + wearer)
	resolver.bind_head_patch_rules(head)
	return {"head": head, "wardrobe": wardrobe, "torn": torn}


func _test_head_weak() -> void:
	for variant in [SNAG, SNAG_PLUS]:
		var ctx := _head_fixture()
		var authored: Dictionary = SeamstressPoolCards.new().get_definition(variant)
		var f := _fixture([variant, UNPICK], 3 if variant == SNAG_PLUS else 2)
		var enemies: CombatEnemies = f.enemies
		_check(authored.cost == 1 and authored.from_positions == [2, 3]
			and authored.to_positions == [1, 2, 3]
			and authored.effects.weak == 1
			and authored.effects.unravel == (3 if variant == SNAG else 4),
			"both Snags have exact authorial cost/from/to/effects")
		_check(enemies.gain_block(1, 6)
			and enemies.apply_statuses({1: {"bleed": 2, "exposed": 1}}),
			"head Snag precondition retains target Block and unrelated statuses")
		var before: Dictionary = _state(f)
		var projected := resolver.snag_weak_preview(variant)
		_check(projected == {"ok": true, "weak": 2} and _state(f) == before,
			"HEAD +1 Weak read-only preview is exactly two: " + variant)
		var event := _play(f, variant, 1)
		var gauge: Dictionary = f.unravel.get_snapshot(1)
		var charge: int = 3 if variant == SNAG else 4
		_check(event.get("ok", false) and event.weak_applied == 2
			and event.unravel_applied == charge and event.unravel_snapshot == gauge
			and event.damage == 0 and event.hp_loss == 0,
			"real HEAD Snag receipt commits Weak 2 and exactly authored Unravel")
		_check(enemies.get_enemy(1).statuses == {"bleed": 2, "exposed": 1, "weak": 2}
			and enemies.get_enemy(1).hp == 18 and enemies.get_enemy(1).block == 6
			and enemies.get_enemy(2) == before.enemies[1]
			and enemies.get_enemy(3) == before.enemies[2]
			and gauge.gauge == charge and gauge.threshold == 8
			and f.pinned._pinner_by_position.is_empty(),
			"HEAD Snag changes only selected Weak/gauge, not attacks/Block/other statuses or enemies")
		_spent_once(before, f, variant, "genuinely patched " + variant)
		_check(ctx.head.read_projection().ok and ctx.head.get_bonus("seamstress", variant, "weak") == 1,
			"confirmed play never consumes a run HEAD patch or changes the run ledger")
		resolver.bind_head_patch_rules(null)

	# An ordinary cast still gets authored Weak 1 with no optional HEAD.
	var plain := _fixture([SNAG])
	var plain_before := _state(plain)
	_check(resolver.snag_weak_preview(SNAG) == {"ok": true, "weak": 1},
		"missing HEAD binding explicitly means vanilla Weak 1")
	var ordinary := _play(plain, SNAG, 1)
	_check(ordinary.get("ok", false) and ordinary.weak_applied == 1
		and ordinary.unravel_applied == 3 and plain.enemies.get_enemy(1).statuses == {"weak": 1},
		"genuinely unpatched legal cast stays Weak 1 with Unravel 3")
	_spent_once(plain_before, plain, SNAG, "unpatched Snag")

	var wrong := _head_fixture("warden")
	var other := _fixture([SNAG_PLUS])
	_check(wrong.head.get_bonus("seamstress", SNAG_PLUS, "weak") == 0
		and resolver.snag_weak_preview(SNAG_PLUS).weak == 1,
		"cap sewn to another living owner cannot empower Seamstress")
	var other_before := _state(other)
	var other_event := _play(other, SNAG_PLUS, 1)
	_check(other_event.get("ok", false) and other_event.weak_applied == 1
		and other_event.unravel_applied == 4
		and other.enemies.get_enemy(1).statuses == {"weak": 1},
		"wrong wearer's cap leaves real Snag+ as Weak 1")
	_spent_once(other_before, other, SNAG_PLUS, "wrong-wearer HEAD cast")

	# HEAD never adds Weak to non-Weak cards, even when sewn to owner.
	var valid := _head_fixture()
	for id in [PIN, UNPICK]:
		var f := _fixture([id])
		var snapshot := _state(f)
		_check(valid.head.get_bonus("seamstress", id, "weak") == 0,
			"Needle Pin and Unpick do not author Weak and cannot gain it")
		var event := _play(f, id, 1)
		_check(event.get("ok", false) and event.weak_applied == 0
			and f.enemies.get_enemy(1).get("statuses", {}).get("weak", 0) == 0,
			"non-Weak cards commit normally and never award HEAD Weak")
		_spent_once(snapshot, f, id, "unaffected " + id)

	# A changed genuine run ledger makes the attached HEAD stale: reject the
	# entire cast before energy, piles, statuses, gauge or RNG can move.
	var stale_f := _fixture([SNAG])
	_check(valid.wardrobe.start_rest("new_rest", valid.wardrobe.get_snapshot()).ok,
		"real Rest ledger transition invalidates cached combat HEAD")
	_check(not valid.head.read_projection().ok
		and not resolver.head_binding_valid()
		and not resolver.snag_weak_preview(SNAG).get("ok", false),
		"stale HEAD projection fails closed even for read-only forecast")
	_reject(stale_f, SNAG, 1, stale_f.pinned, stale_f.unravel, "stale explicit HEAD")

	resolver.bind_head_patch_rules(CombatM05HeadPatchRules.new())
	var unbound := _fixture([SNAG_PLUS])
	_check(not resolver.head_binding_valid(), "explicit unbound HEAD is invalid, not absent")
	_reject(unbound, SNAG_PLUS, 1, unbound.pinned, unbound.unravel, "invalid explicit HEAD")
	resolver.bind_head_patch_rules(null)

	var torn := _head_fixture()
	var source: Array = torn.torn.read_state().heroes
	var ending: Array = source.duplicate(true)
	ending[1].hp = 0
	_check(torn.torn.observe_battle_end("real_seamstress_tear", source, ending).ok,
		"real battle tear recorded by RunTornMending")
	var sewn: Dictionary = torn.wardrobe.get_snapshot()
	_check(torn.wardrobe.refresh_run_context(torn.torn.read_state().heroes,
		sewn.owned, sewn.scraps, sewn.gold, sewn.cards, sewn),
		"real wardrobe refresh agrees with torn hero's run state")
	_check(torn.head.read_projection().ok == false
		and torn.head.get_bonus("seamstress", SNAG, "weak") == 0,
		"unrebound torn projection cannot leak any HEAD power")
	resolver.bind_head_patch_rules(null)
	var downed := _fixture([SNAG])
	_check(downed.party.apply_damage(2, 30) and downed.party.is_downed(2),
		"true combat downing makes a Snag actor ineligible")
	_reject(downed, SNAG, 1, downed.pinned, downed.unravel, "downed Seamstress with torn cap")


func _test_sewn_attack_patches() -> void:
	for variant in [PIN, PIN_PLUS]:
		var ctx := _sewn_fixture([
			{"id": "button_eye", "hero": "seamstress", "slot": "HEAD"},
			{"id": "pincushion_arm", "hero": "seamstress", "slot": "ARM"}])
		var f := _fixture([variant, SNAG, UNPICK], 2)
		var enemy: CombatEnemies = f.enemies
		_check(enemy.gain_block(1, 5) and enemy.apply_statuses({1: {"exposed": 1}})
			and f.pinned.pin_enemy(enemy, 1, "warden"),
			"patched Pin target has Block, Exposed and cross-owner pin")
		f.party._heroes[1]["statuses"] = {"weak": 1}
		var before := _state(f)
		var expected: int = 10 if variant == PIN else 11
		var projected := resolver.needle_patch_preview()
		_check(projected.ok and projected.damage_bonus == 1
			and projected.statuses == {"exposed": 1}
			and _state(f) == before, "patch projection pure before confirmed attack")
		var hit := _play(f, variant, 1)
		_check(hit.ok and hit.damage == expected and hit.pinned_bonus == 5
			and hit.block_absorbed == 5 and hit.hp_loss == expected - 5
			and enemy.get_enemy(1)["hp"] == 18 - (expected - 5)
			and enemy.get_enemy(1)["statuses"].exposed == 2,
			"patched " + variant + " adds ARM before pin/Weak/Exposed rounding")
		_check(f.pinned.pinner_for_enemy(1) == "seamstress"
			and ctx.starter._patches.latch_snapshot().seamstress,
			"confirmed Needle Pin repins and consumes shared first-hit latch")
		_spent_once(before, f, variant, "patched " + variant)
		_check(resolver.needle_patch_preview().statuses.is_empty(),
			"Button Eye cannot trigger twice in battle")
		resolver.bind_patch_rules(null)

	var ctx := _sewn_fixture([
		{"id": "button_eye", "hero": "seamstress", "slot": "HEAD"},
		{"id": "pincushion_arm", "hero": "seamstress", "slot": "ARM"}])
	var f := _fixture([SNAG, UNPICK, PIN], 2)
	var before := _state(f)
	_check(_play(f, SNAG, 1).ok and _play(f, UNPICK, 2).ok,
		"patched wearer can cast nondamaging Snag and Unpick")
	_check(ctx.starter._patches.latch_snapshot().seamstress == false
		and f.enemies.get_enemy(1).hp == before.enemies[0].hp
		and f.enemies.get_enemy(2).hp == before.enemies[1].hp
		and f.enemies.get_enemy(1).statuses == {"weak": 1}
		and f.unravel.get_snapshot(1).gauge == 3
		and f.unravel.get_snapshot(2).gauge == 5,
		"nonattacks charge statuses/gauge, not damage or Button Eye")
	_check(_play(f, PIN, 1).ok and f.enemies.get_enemy(1).statuses.exposed == 1
		and ctx.starter._patches.latch_snapshot().seamstress,
		"first Needle Pin after controls applies post-hit Exposed")
	resolver.bind_patch_rules(null)

	ctx = _sewn_fixture([
		{"id": "button_eye", "hero": "seamstress", "slot": "HEAD"},
		{"id": "pincushion_arm", "hero": "seamstress", "slot": "ARM"}])
	f = _fixture([PIN, "seamstress_prick"], 2)
	_check(ctx.starter.play_attack(f.deck, f.party, f.enemies, "seamstress_prick", 1).ok,
		"genuinely held Prick is a confirmed starter attack")
	_check(ctx.starter._patches.latch_snapshot().seamstress,
		"starter Prick spends SAME Seamstress first-hit latch")
	var next := _play(f, PIN, 2)
	_check(next.ok and next.damage == 4
		and f.enemies.get_enemy(2).get("statuses", {}).get("exposed", 0) == 0,
		"later Needle Pin still gets ARM but not repeat Exposed")
	resolver.bind_patch_rules(null)

	for kind in ["other", "torn"]:
		ctx = _sewn_fixture([
			{"id": "button_eye", "hero": "warden" if kind == "other" else "seamstress", "slot": "HEAD"},
			{"id": "pincushion_arm", "hero": "tinker" if kind == "other" else "seamstress", "slot": "ARM"}],
			kind == "torn")
		f = _fixture([PIN_PLUS], 2)
		var before_patch := _state(f)
		var outcome := _play(f, PIN_PLUS, 1)
		_check(outcome.ok and outcome.damage == 4
			and f.enemies.get_enemy(1).get("statuses", {}).is_empty()
			and not ctx.starter._patches.latch_snapshot().seamstress,
			kind + " wearer cannot empower Seamstress Needle Pin+")
		_spent_once(before_patch, f, PIN_PLUS, kind + " unempowered Needle Pin+")
		resolver.bind_patch_rules(null)

	ctx = _sewn_fixture([
		{"id": "button_eye", "hero": "seamstress", "slot": "HEAD"},
		{"id": "pincushion_arm", "hero": "seamstress", "slot": "ARM"}])
	f = _fixture([PIN, SNAG], 2)
	for reason in ["unheld", "energy", "position", "slain", "overflow"]:
		var rejected := _fixture([PIN, SNAG], 2)
		match reason:
			"unheld":
				rejected.deck.hand.erase(PIN)
			"energy":
				_check(rejected.deck.try_spend_energy(3), "real zero energy fixture")
			"position":
				rejected.party._heroes[1]["position"] = 4
			"slain":
				_check(rejected.enemies.apply_damage(1, 18), "slain foe precondition")
			"overflow":
				rejected.enemies._enemies[0]["statuses"] = {"exposed": CombatEnemies.MAX_INT}
		var snapshot := _state(rejected)
		_check(not _play(rejected, PIN, 1).get("ok", false)
			and _state(rejected) == snapshot
			and not ctx.starter._patches.latch_snapshot().seamstress,
			"rejected " + reason + " preserves all actors, deck, statuses and latch")
	var invalid := CombatPatchAttackRules.new()
	resolver.bind_patch_rules(invalid)
	var before_invalid := _state(f)
	_check(not _play(f, PIN, 1).get("ok", false)
		and not _play(f, SNAG, 1).get("ok", false)
		and _state(f) == before_invalid, "explicit failed patch binding is fail-closed")
	resolver.bind_patch_rules(null)
