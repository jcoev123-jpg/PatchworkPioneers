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
	_test_pinned_brass_buckle()
	_test_pinned_thread_whip()
	_test_pinned_status_damage()
	_test_pinned_rejections_and_retry()
	_test_rejections()
	_test_replay()
	_test_catalog_unchanged()
	_test_worn_pincushion_plain_strikes()
	_test_worn_pincushion_plain_rejections()
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


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		pinned: CombatPinned = null) -> Dictionary:
	var snap: Dictionary = {
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
	if pinned != null:
		snap["pins"] = pinned._pinner_by_position.duplicate(true)
	return snap


func _play(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		id: String, target: int, damage: int, absorbed: int, loss: int,
		gain: int, owner_position: int, label: String, pinned: CombatPinned = null) -> void:
	var owner_id: String = "warden" if id.begins_with("warden_") else "seamstress"
	_check(deck.hand.has(id) and deck.turn_active and deck.energy >= 1,
		label + ": live held hand and energy preconditions")
	_check(party.get_hero(owner_position).get("id") == owner_id
		and not party.is_downed(owner_position), label + ": real owner in current slot")
	_check(not enemies.get_enemy(target).is_empty() and not enemies.is_slain(target),
		label + ": selected original enemy slot is living")
	var before: Dictionary = _snapshot(deck, party, enemies, pinned)
	var before_pinner: String = pinned.pinner_for_enemy(target) if pinned != null else ""
	var result: Dictionary = CombatPoolPlainStrikes.new().play_card(
		deck, party, enemies, id, target, pinned)
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
	var victory: bool = true
	for foe in foes:
		if foe["hp"] > 0:
			victory = false
	expected["victory"] = victory
	if pinned != null:
		var expected_pins: Dictionary = expected["pins"]
		if not before_pinner.is_empty() and before_pinner != owner_id:
			expected_pins.erase(target)
	_check(_snapshot(deck, party, enemies, pinned) == expected,
		label + ": full hand/piles/energy/seed/RNG/rosters unchanged except one strike")


func _reject(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		id: String, target: int, label: String, pinned: CombatPinned = null) -> void:
	var before: Dictionary = _snapshot(deck, party, enemies, pinned)
	_check(CombatPoolPlainStrikes.new().play_card(deck, party, enemies, id, target, pinned)
		== {"ok": false, "hits": [], "block_deltas": {}},
		label + ": fail-closed event")
	_check(_snapshot(deck, party, enemies, pinned) == before,
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


func _test_pinned_brass_buckle() -> void:
	# AC1: Brass Buckle (5 + 5 = 10 raw damage) with foreign pin from seamstress
	var pinned: CombatPinned = CombatPinned.new()
	var deck: CombatDeck = _deck(["warden_brass_buckle"])
	var party: CombatParty = _party()
	var foes: CombatEnemies = _enemies()
	_check(party.gain_block(1, 6) and foes.gain_block(1, 3), "pre-block party 6 and foe 3")
	_check(pinned.pin_enemy(foes, 1, "seamstress"), "pin enemy 1 with seamstress")
	_check(pinned.pin_enemy(foes, 2, "tinker"), "pin enemy 2 with tinker")
	_play(deck, party, foes, "warden_brass_buckle", 1, 10, 3, 7, 4, 1,
		"Brass Buckle gains +5 raw on foreign pin and consumes it", pinned)
	_check(pinned.pinner_for_enemy(1).is_empty(), "enemy 1 pin consumed")
	_check(pinned.pinner_for_enemy(2) == "tinker", "unrelated enemy 2 pin preserved")

	# AC1: Brass Buckle+ (7 + 5 = 12 raw damage) with foreign pin from tinker on shifted Warden
	pinned = CombatPinned.new()
	deck = _deck(["warden_brass_buckle_plus"])
	party = _party(["seamstress", "warden", "tinker"])
	foes = _enemies()
	_check(party.gain_block(2, 2) and foes.gain_block(2, 4), "shifted party 2 and foe 4")
	_check(pinned.pin_enemy(foes, 2, "tinker"), "pin enemy 2 with tinker")
	_play(deck, party, foes, "warden_brass_buckle_plus", 2, 12, 4, 8, 6, 2,
		"Brass Buckle+ gains +5 raw on foreign pin for shifted Warden", pinned)
	_check(pinned.pinner_for_enemy(2).is_empty(), "enemy 2 pin consumed")

	# AC1: Lethal hit with Brass Buckle consumes pin and still awards Warden Block
	pinned = CombatPinned.new()
	deck = _deck(["warden_brass_buckle"])
	party = _party()
	foes = _enemies([5, 20])
	_check(pinned.pin_enemy(foes, 1, "seamstress"), "pin enemy 1 for lethal test")
	_play(deck, party, foes, "warden_brass_buckle", 1, 10, 0, 5, 4, 1,
		"lethal Brass Buckle consumes pin and awards Warden Block", pinned)
	_check(foes.is_slain(1), "enemy 1 is slain by lethal hit")
	_check(pinned.pinner_for_enemy(1).is_empty(), "pin consumed on lethal hit")

	# AC1: Same-owner pin grants NO bonus damage and is NOT consumed
	pinned = CombatPinned.new()
	deck = _deck(["warden_brass_buckle"])
	party = _party()
	foes = _enemies()
	_check(pinned.pin_enemy(foes, 1, "warden"), "pin enemy 1 with warden itself")
	_play(deck, party, foes, "warden_brass_buckle", 1, 5, 0, 5, 4, 1,
		"Brass Buckle against same-owner pin gets no bonus and preserves token", pinned)
	_check(pinned.pinner_for_enemy(1) == "warden", "same-owner pin remains on target")

	# AC1: Instance binding via constructor and set_pinned
	pinned = CombatPinned.new()
	deck = _deck(["warden_brass_buckle"])
	party = _party()
	foes = _enemies()
	_check(pinned.pin_enemy(foes, 1, "seamstress"), "pin enemy 1 with seamstress for binding")
	var bound_resolver: CombatPoolPlainStrikes = CombatPoolPlainStrikes.new(pinned)
	_check(bound_resolver.get_pinned() == pinned, "constructor bound CombatPinned getter agrees")
	var bound_result: Dictionary = bound_resolver.play_card(deck, party, foes, "warden_brass_buckle", 1)
	_check(bound_result["ok"] and bound_result["hits"][0]["damage"] == 10,
		"constructor bound resolver honors pinned token without trailing argument")
	_check(pinned.pinner_for_enemy(1).is_empty(), "bound resolver consumed pin")

	pinned = CombatPinned.new()
	deck = _deck(["warden_brass_buckle"])
	party = _party()
	foes = _enemies()
	_check(pinned.pin_enemy(foes, 1, "seamstress"), "pin enemy 1 for set_pinned")
	var setter_resolver: CombatPoolPlainStrikes = CombatPoolPlainStrikes.new()
	setter_resolver.set_pinned(pinned)
	_check(setter_resolver.get_pinned() == pinned, "set_pinned getter agrees")
	var setter_result: Dictionary = setter_resolver.play_card(deck, party, foes, "warden_brass_buckle", 1)
	_check(setter_result["ok"] and setter_result["hits"][0]["damage"] == 10,
		"set_pinned resolver honors pinned token without trailing argument")


func _test_pinned_thread_whip() -> void:
	# AC2: Thread Whip (6 + 5 = 11 raw damage) with foreign pin from warden
	var pinned: CombatPinned = CombatPinned.new()
	var deck: CombatDeck = _deck(["seamstress_thread_whip"])
	var party: CombatParty = _party(["seamstress", "warden", "tinker"])
	var foes: CombatEnemies = _enemies()
	_check(foes.gain_block(2, 4), "foe slot 2 starts with 4 block")
	_check(pinned.pin_enemy(foes, 2, "warden"), "pin enemy 2 with warden")
	_play(deck, party, foes, "seamstress_thread_whip", 2, 11, 4, 7, 0, 1,
		"Thread Whip gains +5 raw on foreign pin, consumes it, leaves hero Block 0", pinned)
	_check(pinned.pinner_for_enemy(2).is_empty(), "enemy 2 pin consumed")

	# AC2: Thread Whip+ (8 + 5 = 13 raw damage) from position 3 with foreign pin from tinker
	pinned = CombatPinned.new()
	deck = _deck(["seamstress_thread_whip_plus"])
	party = _party(["warden", "tinker", "seamstress"])
	foes = _enemies()
	_check(foes.gain_block(1, 6), "foe slot 1 starts with 6 block")
	_check(pinned.pin_enemy(foes, 1, "tinker"), "pin enemy 1 with tinker")
	_play(deck, party, foes, "seamstress_thread_whip_plus", 1, 13, 6, 7, 0, 3,
		"Thread Whip+ from slot 3 gains +5 raw on foreign pin and leaves hero Block 0", pinned)
	_check(pinned.pinner_for_enemy(1).is_empty(), "enemy 1 pin consumed")

	# AC2: Overkill lethal hit consumes pin
	pinned = CombatPinned.new()
	deck = _deck(["seamstress_thread_whip"])
	party = _party()
	foes = _enemies([3, 20])
	_check(pinned.pin_enemy(foes, 1, "warden"), "pin enemy 1 with warden for overkill")
	_play(deck, party, foes, "seamstress_thread_whip", 1, 11, 0, 3, 0, 2,
		"Thread Whip overkill consumes pin and clamps HP loss", pinned)
	_check(foes.is_slain(1), "enemy 1 slain")
	_check(pinned.pinner_for_enemy(1).is_empty(), "pin consumed on overkill hit")

	# AC2: Same-owner pin grants NO bonus damage and is NOT consumed
	pinned = CombatPinned.new()
	deck = _deck(["seamstress_thread_whip_plus"])
	party = _party()
	foes = _enemies()
	_check(pinned.pin_enemy(foes, 1, "seamstress"), "pin enemy 1 with seamstress herself")
	_play(deck, party, foes, "seamstress_thread_whip_plus", 1, 8, 0, 8, 0, 2,
		"Thread Whip+ against same-owner pin gets no bonus and preserves token", pinned)
	_check(pinned.pinner_for_enemy(1) == "seamstress", "same-owner pin remains on target")

	# AC2: Unpinned target with active CombatPinned returns unchanged unpinned receipts
	pinned = CombatPinned.new()
	deck = _deck(["seamstress_thread_whip"])
	party = _party()
	foes = _enemies()
	_play(deck, party, foes, "seamstress_thread_whip", 1, 6, 0, 6, 0, 2,
		"Thread Whip against unpinned target with CombatPinned present behaves normally", pinned)
	_check(pinned.pinner_for_enemy(1).is_empty(), "no pin on target 1")


func _test_pinned_status_damage() -> void:
	# AC1 & AC2: Weak and Exposed together with foreign pin
	# Example from brief: foreign pin plus Brass Buckle 5 means raw 10;
	# with Weak 1 AND Exposed 1 its final damage is floor(10 * 0.75 * 1.5) = floor(10 * 9 / 8) = 11 before enemy Block.
	var pinned: CombatPinned = CombatPinned.new()
	var deck: CombatDeck = _deck(["warden_brass_buckle"])
	var party: CombatParty = _party()
	var foes: CombatEnemies = _enemies()
	party._heroes[0]["statuses"] = {"weak": 1}
	foes._enemies[0]["statuses"] = {"exposed": 1}
	_check(foes.gain_block(1, 2), "foe block 2")
	_check(pinned.pin_enemy(foes, 1, "seamstress"), "pin enemy 1 with seamstress")
	_play(deck, party, foes, "warden_brass_buckle", 1, 11, 2, 9, 4, 1,
		"Brass Buckle foreign pin Weak 1 + Exposed 1 yields floor(10 * 9/8) = 11", pinned)
	_check(pinned.pinner_for_enemy(1).is_empty(), "pin consumed after status hit")

	# Example from brief: foreign pin plus Thread Whip+ 8 means raw 13;
	# with those statuses its final damage is floor(13 * 0.75 * 1.5) = floor(13 * 9 / 8) = 14.
	pinned = CombatPinned.new()
	deck = _deck(["seamstress_thread_whip_plus"])
	party = _party()
	foes = _enemies()
	party._heroes[1]["statuses"] = {"weak": 1}
	foes._enemies[0]["statuses"] = {"exposed": 1}
	_check(foes.gain_block(1, 3), "foe block 3")
	_check(pinned.pin_enemy(foes, 1, "warden"), "pin enemy 1 with warden")
	_play(deck, party, foes, "seamstress_thread_whip_plus", 1, 14, 3, 11, 0, 2,
		"Thread Whip+ foreign pin Weak 1 + Exposed 1 yields floor(13 * 9/8) = 14", pinned)
	_check(pinned.pinner_for_enemy(1).is_empty(), "pin consumed after status hit")

	# Weak only on Brass Buckle+ (7 + 5 = 12 raw; 12 * 0.75 = 9)
	pinned = CombatPinned.new()
	deck = _deck(["warden_brass_buckle_plus"])
	party = _party()
	foes = _enemies()
	party._heroes[0]["statuses"] = {"weak": 1}
	_check(pinned.pin_enemy(foes, 1, "tinker"), "pin enemy 1 with tinker")
	_play(deck, party, foes, "warden_brass_buckle_plus", 1, 9, 0, 9, 6, 1,
		"Brass Buckle+ foreign pin Weak 1 yields floor(12 * 0.75) = 9", pinned)
	_check(pinned.pinner_for_enemy(1).is_empty(), "pin consumed")

	# Exposed only on Thread Whip (6 + 5 = 11 raw; floor(11 * 1.5) = 16)
	pinned = CombatPinned.new()
	deck = _deck(["seamstress_thread_whip"])
	party = _party()
	foes = _enemies()
	foes._enemies[0]["statuses"] = {"exposed": 1}
	_check(pinned.pin_enemy(foes, 1, "warden"), "pin enemy 1 with warden")
	_play(deck, party, foes, "seamstress_thread_whip", 1, 16, 0, 16, 0, 2,
		"Thread Whip foreign pin Exposed 1 yields floor(11 * 1.5) = 16", pinned)
	_check(pinned.pinner_for_enemy(1).is_empty(), "pin consumed")


func _test_pinned_rejections_and_retry() -> void:
	# AC3: Negative cases with foreign pin established BEFORE preflight.
	# Pin, deck, party, enemy and RNG snapshots must remain strictly identical.
	for scenario in [
		{"name": "pinned: absent held copy", "kind": "absent"},
		{"name": "pinned: inactive turn with held copy", "kind": "inactive"},
		{"name": "pinned: zero energy", "kind": "energy"},
		{"name": "pinned: downed Warden", "kind": "downed"},
		{"name": "pinned: Warden in forbidden back row", "kind": "wrong_pos"},
		{"name": "pinned: target zero", "target": 0},
		{"name": "pinned: target slot three", "target": 3},
		{"name": "pinned: target slot four", "target": 4},
		{"name": "pinned: slain target", "kind": "slain"},
		{"name": "pinned: missing target slot", "kind": "absent_enemy"},
		{"name": "pinned: Warden Block overflow", "kind": "overflow"},
	]:
		var id: String = "warden_brass_buckle"
		var deck: CombatDeck = _deck([id])
		var party: CombatParty = _party()
		var foes: CombatEnemies = _enemies()
		if scenario.get("kind") == "absent_enemy":
			foes = _enemies([20])
		var target: int = scenario.get("target", 2 if scenario.get("kind") == "absent_enemy" else 1)
		var pinned: CombatPinned = CombatPinned.new()
		# Establish foreign pin on the target (or position 1 if out of bounds)
		var pin_pos: int = target if target >= 1 and target <= foes.get_enemies().size() else 1
		_check(pinned.pin_enemy(foes, pin_pos, "seamstress"), "foreign pin set before preflight: " + scenario["name"])

		match scenario.get("kind", ""):
			"absent":
				_check(deck.discard_played(id), "remove held pool copy")
			"inactive":
				_check(deck.combat_state.end_player_turn(), "real state makes turn inactive")
			"energy":
				_check(deck.try_spend_energy(3), "exhaust energy")
			"downed":
				_check(party.apply_damage(1, 40) and party.is_downed(1), "down Warden")
			"wrong_pos":
				party = _party(["seamstress", "tinker", "warden"])
			"slain":
				_check(foes.apply_damage(1, 20) and foes.is_slain(1), "slain target")
			"overflow":
				party._heroes[0]["block"] = CombatParty.MAX_INT - 3

		_reject(deck, party, foes, id, target, scenario["name"], pinned)
		_check(pinned.pinner_for_enemy(pin_pos) == "seamstress",
			"pin strictly preserved after rejection: " + scenario["name"])

	# AC3: A later valid retry CAN still consume the pin!
	var retry_deck: CombatDeck = _deck(["warden_brass_buckle"])
	var retry_party: CombatParty = _party()
	var retry_foes: CombatEnemies = _enemies()
	var retry_pinned: CombatPinned = CombatPinned.new()
	_check(retry_pinned.pin_enemy(retry_foes, 1, "seamstress"), "pin set for retry fixture")
	# First attempt: zero energy fails
	_check(retry_deck.try_spend_energy(3), "drain energy for rejection")
	_reject(retry_deck, retry_party, retry_foes, "warden_brass_buckle", 1,
		"rejection before retry", retry_pinned)
	_check(retry_pinned.pinner_for_enemy(1) == "seamstress", "pin intact after failed attempt")
	# Restore energy for retry
	retry_deck.energy = 3
	retry_deck.combat_state.energy = 3
	_play(retry_deck, retry_party, retry_foes, "warden_brass_buckle", 1, 10, 0, 10, 4, 1,
		"valid retry after rejection consumes foreign pin and adds +5 raw damage", retry_pinned)
	_check(retry_pinned.pinner_for_enemy(1).is_empty(), "pin consumed on successful retry")


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

## Genuine authored ARM metadata and full run wardrobes keep detached combat
## damage projection independent of the Shop ledger and other patch powers.
func _pincushion_context(party: CombatParty, wearer: String,
		owned: bool = true) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_attack_patches.json"))
	_check(raw is Array and raw.size() >= 2, "authored patch metadata available")
	var definitions: Array = []
	for entry in raw:
		definitions.append({"id": entry["id"], "slot": entry["slot"]})
	var torn := RunTornMending.new(party.get_heroes())
	var wardrobe := RunPatchWardrobe.new(party.get_heroes(),
		["pincushion_arm"] if owned else [], definitions, 2)
	_check(torn.is_valid() and wardrobe.is_valid(), "plain patch genuine run ledgers valid")
	if owned:
		var sewn: Dictionary = wardrobe.sew("pincushion_arm", wearer, "ARM",
			"sew_arm", wardrobe.get_snapshot())
		_check(sewn.get("ok", false) and sewn["state"]["worn"][wearer]["ARM"] == "pincushion_arm",
			"valid unique ARM assignment on named real wearer")
	return {"wardrobe": wardrobe, "torn": torn}


func _test_worn_pincushion_plain_strikes() -> void:
	for id in IDS:
		var owner: String = "warden" if id.begins_with("warden_") else "seamstress"
		var owner_pos: int = 1 if owner == "warden" else 2
		var definition: Dictionary = _definition(id)
		var raw: int = definition["effects"]["damage"]
		var block: int = definition["effects"].get("block", 0)
		for mode in ["normal", "weak", "exposed", "pinned", "weak_exposed_pin"]:
			var party := _party()
			var ctx := _pincushion_context(party, owner)
			var resolver := CombatPoolPlainStrikes.new()
			_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn)
				and resolver._patches.damage_bonus(owner) == 1
				and resolver._patches.damage_bonus("tinker") == 0,
				id + " real sewn projection wearer-only")
			var pinned := CombatPinned.new()
			var foes := _enemies([80, 80, 80])
			if mode in ["weak", "weak_exposed_pin"]:
				party._heroes[owner_pos - 1]["statuses"] = {"weak": 1}
			if mode in ["exposed", "weak_exposed_pin"]:
				foes._enemies[0]["statuses"] = {"exposed": 1}
			if mode in ["pinned", "weak_exposed_pin"]:
				var other_owner := "seamstress" if owner == "warden" else "warden"
				_check(pinned.pin_enemy(foes, 1, other_owner),
					id + " foreign-source pin active before damage")
			_check(foes.gain_block(1, 3), id + " enemy starts with actual Block")
			var deck := _deck([id])
			var previous := _snapshot(deck, party, foes, pinned)
			var pinned_bonus: int = 5 if mode in ["pinned", "weak_exposed_pin"] else 0
			var damage: int = CombatStatuses.new().adjusted_attack_damage(
				raw + pinned_bonus + 1, party.get_hero(owner_pos).get("statuses", {}),
				foes.get_enemy(1).get("statuses", {}))
			var absorbed: int = mini(3, damage)
			var loss: int = damage - absorbed
			var result: Dictionary = resolver.play_card(deck, party, foes, id, 1, pinned)
			var expected_blocks: Dictionary = {}
			if block > 0:
				expected_blocks[owner_pos] = block
			_check(result == {"ok": true, "hits": [{
				"position": 1, "damage": damage, "block_absorbed": absorbed,
				"hp_loss": loss, "statuses": {}
			}], "block_deltas": expected_blocks},
				id + " " + mode + " exact wearer bonus before status, pin and Block")
			_check(foes.get_enemy(1)["hp"] == 80 - loss
				and foes.get_enemy(1)["block"] == 3 - absorbed
				and party.get_hero(owner_pos)["block"] == block,
				id + " " + mode + " applies exact HP and unmodified own Block")
			_check(deck.energy == previous["energy"] - definition["cost"]
				and deck.discard_pile.has(id) and deck._rng.state == previous["rng_state"]
				and ctx.wardrobe.get_snapshot()["worn"][owner]["ARM"] == "pincushion_arm",
				id + " " + mode + " spends only authored energy, no RNG or patch mutation")
			_check(pinned.pinner_for_enemy(1).is_empty()
				and party.get_hero(owner_pos).get("statuses", {}) == previous["heroes"][owner_pos - 1].get("statuses", {}),
				id + " " + mode + " consumed foreign pin if any, preserved owner statuses")

	# A patch sewn on another wearer (including a torn wearer) changes nothing.
	for owner in ["warden", "seamstress"]:
		var id := "seamstress_thread_whip" if owner == "warden" else "warden_brass_buckle"
		for mode in ["other", "unsown", "torn"]:
			var party := _party()
			var ctx := _pincushion_context(party, owner, mode != "unsown")
			if mode == "torn":
				var start: Array = ctx.torn.read_state()["heroes"]
				var owner_pos: int = 1 if owner == "warden" else 2
				_check(party.apply_damage(owner_pos, 999) and party.is_downed(owner_pos),
					"other wearer truly downed")
				_check(ctx.torn.observe_battle_end("tear", start, party.get_heroes())["ok"],
					"run torn ledger records wearer down")
				_check(ctx.wardrobe.project_active(ctx.torn.read_state())["active"][owner].is_empty(),
					"torn wearer patch dormant in projection")
			var resolver := CombatPoolPlainStrikes.new()
			_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn)
				and resolver._patches.damage_bonus("warden" if owner == "seamstress" else "seamstress") == 0,
				mode + " real projection lacks other owner's patch")
			var deck := _deck([id])
			var foes := _enemies()
			var result: Dictionary = resolver.play_card(deck, party, foes, id, 1)
			_check(result.get("ok", false)
				and result["hits"][0]["damage"] == _definition(id)["effects"]["damage"],
				id + " " + mode + " never inherits another wearer's +1")


func _test_worn_pincushion_plain_rejections() -> void:
	for id in ["warden_brass_buckle", "seamstress_thread_whip_plus"]:
		var owner := "warden" if id.begins_with("warden_") else "seamstress"
		var party := _party()
		var ctx := _pincushion_context(party, owner)
		var resolver := CombatPoolPlainStrikes.new()
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn),
			id + " initial explicit real binding accepted")
		var deck := _deck([id])
		var foes := _enemies()
		var pin := CombatPinned.new()
		_check(pin.pin_enemy(foes, 1, "tinker"), id + " real foreign pin established")
		_check(not resolver.bind_patch_wardrobe(null, ctx.torn)
			and not resolver._patches.is_valid(), id + " failed explicit binding remains invalid")
		var before := _snapshot(deck, party, foes, pin)
		_check(resolver.play_card(deck, party, foes, id, 1, pin)
			== {"ok": false, "hits": [], "block_deltas": {}}
			and _snapshot(deck, party, foes, pin) == before,
			id + " invalid patch binding denies without spending, consuming pin or RNG")
		_check(resolver.bind_patch_wardrobe(ctx.wardrobe, ctx.torn),
			id + " valid rebind restores explicit projected authority")
		_check(deck.try_spend_energy(3), id + " exhausted energy precondition")
		before = _snapshot(deck, party, foes, pin)
		_check(not resolver.play_card(deck, party, foes, id, 1, pin)["ok"]
			and _snapshot(deck, party, foes, pin) == before,
			id + " low energy fails closed with patch and pin")
		deck.energy = 3
		deck.combat_state.energy = 3
		before = _snapshot(deck, party, foes, pin)
		_check(not resolver.play_card(deck, party, foes, id, 3, pin)["ok"]
			and _snapshot(deck, party, foes, pin) == before,
			id + " illegal position fails closed with patch and pin")
