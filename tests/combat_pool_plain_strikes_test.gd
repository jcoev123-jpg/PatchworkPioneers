extends SceneTree
## Deterministic, real-model tests for the four authored plain pool strikes.

const IDS := [
	"warden_brass_buckle", "warden_brass_buckle_plus",
	"seamstress_thread_whip", "seamstress_thread_whip_plus",
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog_contract()
	_test_brass_buckle()
	_test_thread_whip()
	_test_status_damage()
	_test_rejections()
	_test_replay()
	_test_catalog_unchanged()
	for failure in failures:
		printerr(failure)
	print("combat_pool_plain_strikes_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _definition(id: String) -> Dictionary:
	return (WardenPoolCards.new().get_definition(id) if id.begins_with("warden_")
		else SeamstressPoolCards.new().get_definition(id))


func _party(order: Array = ["warden", "seamstress", "tinker"]) -> CombatParty:
	var hp := {"warden": 40, "seamstress": 30, "tinker": 26}
	var defs: Array = []
	for id in order:
		defs.append({"id": id, "max_hp": hp[id]})
	var party := CombatParty.new(defs)
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"fixture has three distinct living real heroes")
	return party


func _enemies(hps: Array[int] = [20, 20, 20]) -> CombatEnemies:
	var defs: Array = []
	for index in hps.size():
		defs.append({"id": "foe_%d" % (index + 1), "max_hp": hps[index]})
	var enemies := CombatEnemies.new(defs)
	_check(enemies.is_valid() and enemies.get_enemies().size() == hps.size(),
		"fixture has valid enemy roster")
	return enemies


func _deck(wanted: Array, seed_value: int = 77123) -> CombatDeck:
	# Only authentic authored starter/pool IDs enter the actual seeded deck.
	var cards: Array[String] = StarterCards.new().get_starting_deck()
	for id in wanted:
		if StarterCards.new().has_card(id):
			_check(cards.has(id), id + " is a real starter card")
		else:
			_check(not _definition(id).is_empty(), id + " is an authored pool definition")
			cards.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == CombatDeck.TURN_DRAW,
		"real seeded CombatDeck draws five with three energy")
	while not _has_copies(deck.hand, wanted) and not deck.draw_pile.is_empty():
		_check(deck.draw_extra(1) == 1, "draw_extra moves a real card")
	_check(_has_copies(deck.hand, wanted), "held cards acquired through real draw only")
	var all_cards: Array[String] = []
	all_cards.append_array(deck.draw_pile)
	all_cards.append_array(deck.hand)
	all_cards.append_array(deck.discard_pile)
	all_cards.sort()
	var expected: Array[String] = cards.duplicate()
	expected.sort()
	_check(all_cards == expected, "draw preserves complete authored card multiset")
	return deck


func _has_copies(hand: Array[String], wanted: Array) -> bool:
	var remaining: Array[String] = hand.duplicate()
	for id in wanted:
		var index := remaining.find(id)
		if index < 0:
			return false
		remaining.remove_at(index)
	return true


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	return {
		"draw": deck.draw_pile.duplicate(true),
		"hand": deck.hand.duplicate(true),
		"discard": deck.discard_pile.duplicate(true),
		"active": deck.turn_active,
		"energy": deck.energy,
		"state_active": deck.combat_state.player_turn_active,
		"state_energy": deck.combat_state.energy,
		"rng_seed": deck._rng.seed,
		"rng_state": deck._rng.state,
		"heroes": party.get_heroes(),
		"foes": enemies.get_enemies(),
		"victory": enemies.is_victorious(),
	}


func _play(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		id: String, target: int, damage: int, absorbed: int, loss: int,
		gain: int, owner_position: int, label: String) -> void:
	var owner_id := "warden" if id.begins_with("warden_") else "seamstress"
	_check(deck.hand.has(id) and deck.turn_active and deck.energy >= 1,
		label + ": live held hand and energy preconditions")
	_check(party.get_hero(owner_position).get("id") == owner_id
		and not party.is_downed(owner_position), label + ": real owner in current slot")
	_check(not enemies.get_enemy(target).is_empty() and not enemies.is_slain(target),
		label + ": selected original enemy slot is living")
	var before := _snapshot(deck, party, enemies)
	var result: Dictionary = CombatPoolPlainStrikes.new().play_card(
		deck, party, enemies, id, target)
	var block_deltas: Dictionary = {}
	if gain > 0:
		block_deltas[owner_position] = gain
	_check(result == {"ok": true, "hits": [{
		"position": target, "damage": damage, "block_absorbed": absorbed,
		"hp_loss": loss, "statuses": {},
	}], "block_deltas": block_deltas}, label + ": exact hit and owner Block events")
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] -= 1
	expected["state_energy"] -= 1
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(id))
	var discard: Array = expected["discard"]
	discard.append(id)
	var heroes: Array = expected["heroes"]
	heroes[owner_position - 1]["block"] += gain
	var foes: Array = expected["foes"]
	foes[target - 1]["block"] -= absorbed
	foes[target - 1]["hp"] -= loss
	var victory := true
	for foe in foes:
		if foe["hp"] > 0:
			victory = false
	expected["victory"] = victory
	_check(_snapshot(deck, party, enemies) == expected,
		label + ": full hand/piles/energy/seed/RNG/rosters unchanged except one strike")


func _reject(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		id: String, target: int, label: String) -> void:
	var before: Dictionary = _snapshot(deck, party, enemies)
	_check(CombatPoolPlainStrikes.new().play_card(deck, party, enemies, id, target)
		== {"ok": false, "hits": [], "block_deltas": {}},
		label + ": fail-closed event")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": complete state including RNG identical after rejection")


func _test_catalog_contract() -> void:
	for id in IDS:
		_catalog_before[id] = _definition(id)
	var spec := {
		"warden_brass_buckle": {"owner": "warden", "cost": 1, "from": [1, 2],
			"damage": 5, "block": 4, "eligible": true},
		"warden_brass_buckle_plus": {"owner": "warden", "cost": 1, "from": [1, 2],
			"damage": 7, "block": 6, "eligible": false},
		"seamstress_thread_whip": {"owner": "seamstress", "cost": 1, "from": [1, 2, 3],
			"damage": 6, "block": 0, "eligible": true},
		"seamstress_thread_whip_plus": {"owner": "seamstress", "cost": 1, "from": [1, 2, 3],
			"damage": 8, "block": 0, "eligible": false},
	}
	for id in IDS:
		var record: Dictionary = _definition(id)
		var expected: Dictionary = spec[id]
		_check(not record.is_empty() and record.get("id") == id,
			id + ": actual catalog ID exists")
		_check(record.get("owner") == expected["owner"] and record.get("cost") == expected["cost"]
			and record.get("from_positions") == expected["from"] and
			record.get("to_positions") == [1, 2] and record.get("target_kind") == "enemy_single",
			id + ": catalog owner, cost, FROM/TO and targeting")
		var effects: Dictionary = record.get("effects", {})
		_check(effects.get("damage") == expected["damage"] and
			effects.get("block", 0) == expected["block"] and
			effects.size() == (2 if expected["block"] > 0 else 1),
			id + ": printed damage and only authored Block effect")
		_check(record.get("reward_eligible") == expected["eligible"]
			and (record.get("upgrade_of") == id.trim_suffix("_plus") if not expected["eligible"]
				else record.get("upgrade_id") == id + "_plus"),
			id + ": reward/upgrade metadata remains authored")
		_check(record.get("rarity") == "common" and record.get("starting_copies") == 0,
			id + ": remains a common reward pool card, not a starter")


func _test_brass_buckle() -> void:
	var deck := _deck(["warden_brass_buckle"])
	var party := _party()
	var foes := _enemies()
	_check(party.gain_block(1, 6) and foes.gain_block(1, 3),
		"Warden opening six Block and enemy three Block")
	_play(deck, party, foes, "warden_brass_buckle", 1, 5, 3, 2, 4, 1,
		"Brass Buckle adds 4 to opening Block, hits through enemy Block")

	deck = _deck(["warden_brass_buckle_plus"])
	party = _party(["seamstress", "warden", "tinker"])
	foes = _enemies()
	_check(party.gain_block(2, 2) and foes.gain_block(2, 4),
		"shifted Warden and target slot two start with Block")
	_play(deck, party, foes, "warden_brass_buckle_plus", 2, 7, 4, 3, 6, 2,
		"Brass Buckle+ goes to actual Warden at position two")

	deck = _deck(["warden_brass_buckle_plus"])
	party = _party()
	foes = _enemies([3, 20])
	_play(deck, party, foes, "warden_brass_buckle_plus", 1, 7, 0, 3, 6, 1,
		"lethal Brass Buckle+ still grants Warden Block")
	_check(foes.is_slain(1) and not foes.is_slain(2),
		"overkill clamps HP without shifting enemy position two")


func _test_thread_whip() -> void:
	var deck := _deck(["seamstress_thread_whip"])
	var party := _party(["seamstress", "warden", "tinker"])
	var foes := _enemies()
	_check(party.gain_block(1, 2) and party.gain_block(2, 6) and
		foes.gain_block(2, 4), "Thread Whip front-owner and all Block preconditions")
	_play(deck, party, foes, "seamstress_thread_whip", 2, 6, 4, 2, 0, 1,
		"Thread Whip from position one changes no ally Block")

	deck = _deck(["seamstress_thread_whip_plus"])
	party = _party(["warden", "tinker", "seamstress"])
	foes = _enemies()
	_check(foes.gain_block(1, 6), "Thread Whip+ enemy has six Block")
	_play(deck, party, foes, "seamstress_thread_whip_plus", 1, 8, 6, 2, 0, 3,
		"Thread Whip+ from position three costs one and changes no statuses")

	deck = _deck(["seamstress_thread_whip"])
	party = _party()
	foes = _enemies()
	_check(foes.apply_damage(1, 20) and foes.is_slain(1),
		"enemy slot one slain without compacting surviving two/three")
	_play(deck, party, foes, "seamstress_thread_whip", 2, 6, 0, 6, 0, 2,
		"Thread Whip targets original slot two after slot one death")
	_check(foes.get_enemy(1)["position"] == 1 and foes.get_enemy(1)["hp"] == 0
		and foes.get_enemy(3)["position"] == 3,
		"slain and untouched original slots retain identity")


func _test_status_damage() -> void:
	var cases := [
		{"id": "warden_brass_buckle", "attack": {"weak": 1},
			"defend": {}, "damage": 3, "block": 4},
		{"id": "warden_brass_buckle_plus", "attack": {},
			"defend": {"exposed": 1}, "damage": 10, "block": 6},
		{"id": "warden_brass_buckle", "attack": {"weak": 1},
			"defend": {"exposed": 1}, "damage": 5, "block": 4},
		{"id": "seamstress_thread_whip", "attack": {"weak": 1},
			"defend": {}, "damage": 4, "block": 0},
		{"id": "seamstress_thread_whip", "attack": {},
			"defend": {"exposed": 1}, "damage": 9, "block": 0},
		{"id": "seamstress_thread_whip_plus", "attack": {"weak": 1},
			"defend": {"exposed": 1}, "damage": 9, "block": 0},
	]
	for scenario in cases:
		var id: String = scenario["id"]
		var deck := _deck([id])
		var party := _party()
		var foes := _enemies()
		var owner_pos := 1 if id.begins_with("warden_") else 2
		party._heroes[owner_pos - 1]["statuses"] = scenario["attack"].duplicate(true)
		foes._enemies[0]["statuses"] = scenario["defend"].duplicate(true)
		_check(foes.gain_block(1, 2), "status case real target Block")
		var damage: int = scenario["damage"]
		_check(CombatStatuses.new().adjusted_attack_damage(
			_definition(id)["effects"]["damage"], scenario["attack"], scenario["defend"]) == damage,
			id + ": independent current CombatStatuses rounding agrees")
		_play(deck, party, foes, id, 1, damage, 2, damage - 2,
			scenario["block"], owner_pos, id + " status case " + str(scenario))
		_check(foes.get_enemy(1)["statuses"] == scenario["defend"]
			and party.get_hero(owner_pos)["statuses"] == scenario["attack"],
			"no status application, passive Bleed, or status aging")


func _test_rejections() -> void:
	# Every case holds a real card unless the named failure removes it.
	for scenario in [
		{"name": "unsupported held starter card", "id": "warden_strike"},
		{"name": "absent held copy", "kind": "absent"},
		{"name": "inactive turn with held copy", "kind": "inactive"},
		{"name": "zero energy", "kind": "energy"},
		{"name": "downed Warden", "kind": "downed"},
		{"name": "Warden in forbidden back row", "kind": "wrong_pos"},
		{"name": "target zero", "target": 0},
		{"name": "target slot three", "target": 3},
		{"name": "target slot four", "target": 4},
		{"name": "slain target", "kind": "slain"},
		{"name": "missing target slot", "kind": "absent_enemy"},
		{"name": "Warden Block overflow", "kind": "overflow"},
	]:
		var id: String = scenario.get("id", "warden_brass_buckle")
		var deck := _deck(["warden_brass_buckle", "warden_strike"] if
			id == "warden_strike" else ["warden_brass_buckle"])
		var party := _party()
		var foes := _enemies()
		if scenario.get("kind") == "absent_enemy":
			foes = _enemies([20])
		var target: int = scenario.get("target", 2 if scenario.get("kind") == "absent_enemy" else 1)
		match scenario.get("kind", ""):
			"absent":
				_check(deck.discard_played(id), "remove the sole actually held pool copy")
			"inactive":
				_check(deck.combat_state.end_player_turn(), "real state makes turn inactive")
				_check(deck.hand.has(id), "held card remains during inactive fixture")
			"energy":
				_check(deck.try_spend_energy(3), "real deck energy exhausted")
			"downed":
				_check(party.apply_damage(1, 40) and party.is_downed(1),
					"Warden really downed in active slot one")
			"wrong_pos":
				party = _party(["seamstress", "tinker", "warden"])
			"slain":
				_check(foes.apply_damage(1, 20) and foes.is_slain(1),
					"target truly slain in original slot")
			"overflow":
				party._heroes[0]["block"] = CombatParty.MAX_INT - 3
				_check(party.get_hero(1)["block"] == CombatParty.MAX_INT - 3,
					"valid near-MAX_INT Block would overflow by one")
		_reject(deck, party, foes, id, target, scenario["name"])

	# Negative Thread Whip targets and owner cases get the same atomic contract.
	for owner_order in [
		["warden", "seamstress", "tinker"], ["warden", "tinker", "seamstress"]]:
		var deck := _deck(["seamstress_thread_whip_plus"])
		var party := _party(owner_order)
		var foes := _enemies()
		_reject(deck, party, foes, "seamstress_thread_whip_plus", 3,
			"Thread Whip+ cannot select occupied slot three")
		_check(foes.apply_damage(2, 20), "Thread Whip+ slain slot two precondition")
		_reject(deck, party, foes, "seamstress_thread_whip_plus", 2,
			"Thread Whip+ cannot select slain original slot two")
	var whip := _deck(["seamstress_thread_whip"])
	var downed := _party()
	_check(downed.apply_damage(2, 30), "Seamstress truly downed")
	_reject(whip, downed, _enemies(), "seamstress_thread_whip", 1,
		"downed Seamstress cannot play")


func _test_replay() -> void:
	var reference: Dictionary = {}
	for repeat in 2:
		var deck := _deck(["warden_brass_buckle", "seamstress_thread_whip"], 93001)
		var party := _party()
		var foes := _enemies()
		party._heroes[0]["statuses"] = {"weak": 1}
		foes._enemies[0]["statuses"] = {"exposed": 1}
		var initial: Dictionary = _snapshot(deck, party, foes)
		var first: Dictionary = CombatPoolPlainStrikes.new().play_card(
			deck, party, foes, "warden_brass_buckle", 1)
		var second: Dictionary = CombatPoolPlainStrikes.new().play_card(
			deck, party, foes, "seamstress_thread_whip", 2)
		_check(first.get("ok") == true and second.get("ok") == true
			and deck.energy == 1 and deck.discard_pile.has("warden_brass_buckle")
			and deck.discard_pile.has("seamstress_thread_whip"),
			"two independently held catalog cards resolve sequentially")
		_check(deck._rng.state == initial["rng_state"] and deck._rng.seed == initial["rng_seed"],
			"both successful plain strikes consume zero seeded RNG steps")
		var played := {"first": first, "second": second, "final": _snapshot(deck, party, foes)}
		if repeat == 0:
			reference = played
		else:
			_check(played == reference, "same-seed independent replay identical events and full state")


var _catalog_before: Dictionary = {}


func _test_catalog_unchanged() -> void:
	for id in IDS:
		_check(_definition(id) == _catalog_before[id],
			id + " unchanged after all real plays and rejected calls")
