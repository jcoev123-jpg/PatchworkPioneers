extends SceneTree
## V3-1 focused headless test for CombatButtonGolemFistCards: the scene-free paid resolver for
## Button Golem's two starter Button Fist printings (base and "+").
## Every case drives the REAL authored starter catalog and real seeded CombatDeck / CombatParty /
## CombatEnemies state through the resolver; no live hand, target picker, reward or app wiring is
## assumed here (a later task owns that route).

const FistResolver := preload("res://scripts/combat_button_golem_fist_cards.gd")
const PopResolver := preload("res://scripts/combat_button_golem_pop_cards.gd")
const ThreadResolver := preload("res://scripts/combat_button_golem_thread_cards.gd")
const StarterCatalog := preload("res://data/cards/button_golem_starter_cards.gd")
const PoolCatalog := preload("res://data/cards/button_golem_pool_cards.gd")

## A starter-catalog source that serves caller-supplied records, so a rewritten field or a relinked
## upgrade can be proven inert before any energy, hand, HP, Block, status or RNG state moves.
class ForgedFist extends "res://scripts/combat_button_golem_fist_cards.gd":
	var forged: Dictionary = {}

	func _catalog_definition(card_id: String) -> Dictionary:
		var record: Dictionary = forged.get(card_id, {})
		return record.duplicate(true)

## The two authentic Fist printings, with the exact literals each authored record must carry.
const FIST_PRINTINGS := {
	"button_golem_starter_button_fist": {
		"name": "Button Fist", "damage": 5, "block_self": 2,
		"effects": {"damage": 5, "block_self": 2}, "starting_copies": 1,
	},
	"button_golem_starter_button_fist_plus": {
		"name": "Button Fist+", "damage": 7, "block_self": 3,
		"effects": {"damage": 7, "block_self": 3}, "starting_copies": 0,
	},
}

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_authentic_printings()
	_test_foreign_and_forged_definitions()
	_test_paid_hits()
	_test_status_adjusted_hits()
	_test_absorbed_and_lethal_hits()
	_test_refusals()
	_test_family_isolation()
	if failures.is_empty():
		print("combat_button_golem_fist_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("combat_button_golem_fist_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


# ---------------------------------------------------------------------------------------------
# AC1: both genuine printings authenticate from the real starter catalog without spending anything.
# ---------------------------------------------------------------------------------------------

func _test_authentic_printings() -> void:
	var resolver = FistResolver.new()
	var catalog = StarterCatalog.new()
	_check(resolver.is_supported_card("button_golem_starter_button_fist")
		and resolver.is_supported_card("button_golem_starter_button_fist_plus"),
		"both authentic Fist printings are supported")
	# A read-only authentication query must neither spend nor mutate the real battle state.
	var deck := _deck(["button_golem_starter_button_fist"])
	var party := _party(1)
	var enemies := _enemies([40])
	var before := _snapshot(deck, party, enemies)
	for card_id: String in FIST_PRINTINGS:
		var spec: Dictionary = FIST_PRINTINGS[card_id]
		var upgraded: bool = card_id.ends_with("_plus")
		var base_id: String = card_id.trim_suffix("_plus")
		var record: Dictionary = catalog.get_definition(card_id)
		_check(not record.is_empty() and record.get("id") == card_id,
			card_id + " is authentically authored in the real starter catalog")
		_check(record.get("owner") == "button_golem", card_id + " is owned by the Golem")
		_check(record.get("display_name") == spec["name"],
			card_id + " prints its exact name " + str(spec["name"]))
		_check(record.get("cost") is int and record.get("cost") == 1,
			card_id + " costs exactly one energy")
		_check(record.get("target_kind") == "enemy_single" and record.get("to_positions") == [1, 2],
			card_id + " strikes one enemy in slots 1-2")
		_check(record.get("from_positions") == [1, 2], card_id + " plays from hero seats 1-2")
		_check(record.get("effects") == spec["effects"],
			card_id + " prints exactly " + str(spec["effects"]))
		_check(record.get("starting_copies") == spec["starting_copies"],
			card_id + " carries its authored starter copy count")
		_check(record.get("reward_eligible") == false, card_id + " is never a reward card")
		if upgraded:
			_check(record.get("upgrade_of") == base_id and not record.has("upgrade_id"),
				card_id + " still points back at its base")
		else:
			_check(record.get("upgrade_id") == base_id + "_plus" and not record.has("upgrade_of"),
				card_id + " still links to its authored upgrade")

		var printed: Dictionary = resolver.printed_definition(card_id)
		_check(not printed.is_empty() and printed.get("card_id") == card_id,
			card_id + " authenticates as a paid Fist printing")
		_check(printed.get("display_name") == spec["name"],
			card_id + " authenticates the printed name")
		_check(printed.get("cost") == 1, card_id + " authenticates the one-energy cost")
		_check(printed.get("damage") == spec["damage"],
			card_id + " authenticates its printed " + str(spec["damage"]) + " damage")
		_check(printed.get("block_self") == spec["block_self"],
			card_id + " authenticates its printed " + str(spec["block_self"]) + " self Block")
		_check(printed.get("from_positions") == [1, 2] and printed.get("to_positions") == [1, 2],
			card_id + " authenticates both position windows")
		# Detached results: mutating one query cannot rewrite the next.
		printed["to_positions"].append(99)
		printed["damage"] = -1
	_check(resolver.printed_definition("button_golem_starter_button_fist").get("damage") == 5
		and resolver.printed_definition("button_golem_starter_button_fist").get("to_positions") == [1, 2],
		"authenticated printed definitions are detached from later mutation")
	_check(_snapshot(deck, party, enemies) == before,
		"read-only authentication spends no energy and changes no deck, actor or RNG state")


# ---------------------------------------------------------------------------------------------
# AC1/AC3: foreign IDs and forged or relinked records are never authenticated or paid for.
# ---------------------------------------------------------------------------------------------

func _test_foreign_and_forged_definitions() -> void:
	var resolver = FistResolver.new()
	for rejected in ["button_golem_starter_loose_pop", "button_golem_starter_loose_pop_plus",
			"button_golem_starter_threadwheel_roll", "button_golem_starter_seam_resew",
			"button_golem_pop_button", "button_golem_button_knuckle", "button_golem_eyelet_guard",
			"button_golem_starter_button_fist_plus_plus", "button_golem_starter_button_fist+",
			"button_fist", "warden_strike", ""]:
		_check(not resolver.is_supported_card(rejected),
			str(rejected) + " is not a Button Fist printing")
		_check(resolver.printed_definition(rejected).is_empty(),
			str(rejected) + " has no authenticated printed definition")
	for malformed in [null, 0, 3.5, false, [], {},
			StringName("button_golem_starter_button_fist")]:
		_check(not resolver.is_supported_card(malformed),
			"malformed card id is not a Fist printing: " + str(malformed))

	# Every genuine pair is loaded, then exactly one field of exactly one record is rewritten.
	var genuine: Dictionary = {}
	for card_id: String in FIST_PRINTINGS:
		genuine[card_id] = StarterCatalog.new().get_definition(card_id)
	_check(genuine.size() == FIST_PRINTINGS.size() and not genuine.values().has({}),
		"forged-definition fixtures really start from both genuine records")
	var base_id := "button_golem_starter_button_fist"
	var plus_id := "button_golem_starter_button_fist_plus"
	for mutation in [
			{"label": "rewritten damage", "id": base_id, "key": "damage", "value": 9},
			{"label": "rewritten self Block", "id": base_id, "key": "block_self", "value": 9},
			{"label": "rewritten cost", "id": base_id, "key": "cost", "value": 0},
			{"label": "foreign owner", "id": base_id, "key": "owner", "value": "warden"},
			{"label": "relinked base upgrade", "id": base_id, "key": "upgrade_id",
				"value": "button_golem_starter_loose_pop"},
			{"label": "relinked upgraded base", "id": plus_id, "key": "upgrade_of",
				"value": "button_golem_starter_loose_pop"},
			{"label": "wrong target kind", "id": base_id, "key": "target_kind",
				"value": "enemy_all"},
			{"label": "altered seats", "id": plus_id, "key": "to_positions", "value": [1, 2, 3]},
	]:
		var records: Dictionary = {}
		for card_id: String in genuine:
			records[card_id] = (genuine[card_id] as Dictionary).duplicate(true)
		var target_record: Dictionary = records[mutation["id"]]
		if mutation["key"] in ["damage", "block_self"]:
			target_record["effects"][mutation["key"]] = mutation["value"]
		else:
			target_record[mutation["key"]] = mutation["value"]
		var forged = ForgedFist.new()
		forged.forged = records
		var label: String = mutation["label"]
		_check(forged.printed_definition(base_id).is_empty()
			and forged.printed_definition(plus_id).is_empty(),
			label + ": the forged pair is never authenticated")
		_expect_refusal(label + " is refused before payment",
			_deck([base_id]), _party(1), _enemies([40]), base_id, 1, "catalog_mismatch", forged)
	# A present-but-empty forged catalog cannot authenticate either.
	var empty_forged = ForgedFist.new()
	_check(empty_forged.printed_definition(base_id).is_empty(),
		"an empty forged catalog authenticates nothing")


# ---------------------------------------------------------------------------------------------
# AC2: one paid cast per printing from both legal Golem seats, plus exactly-one-copy discard.
# ---------------------------------------------------------------------------------------------

func _test_paid_hits() -> void:
	var cases := 0
	for card_id: String in FIST_PRINTINGS:
		for golem_seat in [1, 2]:
			_play_fist_success(card_id, golem_seat, 3 - golem_seat)
			cases += 1
	_check(cases == 4, "both printings are played from both legal Golem seats")

	# Recasting: exactly one held copy leaves the hand per paid cast, never the pile or the draw.
	var deck := _deck([base_id_of(), base_id_of()])
	_check(deck.hand.count(base_id_of()) == 2, "the recast fixture genuinely holds two copies")
	var party := _party(1)
	var enemies := _enemies([40])
	var before := _snapshot(deck, party, enemies)
	var first = FistResolver.new().play_card(deck, party, enemies, base_id_of(), 1)
	_check(first.get("ok") == true and deck.energy == 2
		and deck.hand == [base_id_of()] and deck.discard_pile == [base_id_of()],
		"one paid cast spends one energy and moves exactly one held copy to discard")
	_check(deck.draw_pile == before["draw"] and deck.turn_active,
		"the paid cast draws no card and does not end the turn")
	_check(deck._rng.state == before["rng_state"] and deck._rng.seed == before["rng_seed"],
		"the paid cast consumes no seeded RNG draw")

	# The Fist owns no Pinned rider: an extant cross-hero token survives it untouched.
	var pin_deck := _deck([base_id_of()])
	var pin_party := _party(1)
	var pin_enemies := _enemies([40])
	var pinned := CombatPinned.new()
	_check(pinned.pin_enemy(pin_enemies, 1, "warden"),
		"pin fixture really carries a cross-hero Pinned token")
	var pin_before: int = pinned.bonus_for_attack(pin_enemies, 1, "button_golem")
	_check(pin_before == 5, "the extant token really would grant the +5 cross-hero bonus")
	var pin_receipt = FistResolver.new().play_card(
		pin_deck, pin_party, pin_enemies, base_id_of(), 1)
	_check(pin_receipt.get("ok") == true and pin_receipt.get("damage") == 5,
		"a Fist strike stays at its printed damage and never adds the pin bonus")
	_check(pinned.bonus_for_attack(pin_enemies, 1, "button_golem") == pin_before
		and pinned.pinner_for_enemy(1) == "warden",
		"the Fist never consumes another helper's Pinned token")


func _play_fist_success(card_id: String, golem_seat: int, target_position: int) -> void:
	var spec: Dictionary = FIST_PRINTINGS[card_id]
	var damage: int = int(spec["damage"])
	var block_self: int = int(spec["block_self"])
	var label := "%s from seat %d onto slot %d" % [card_id, golem_seat, target_position]
	var deck := _deck([card_id])
	_check(deck.hand.count(card_id) == 1, label + ": the exact Fist ID is genuinely held once")
	var party := _party(golem_seat)
	_check(party.get_hero(golem_seat).get("id") == "button_golem"
		and party.get_hero(golem_seat).get("position") == golem_seat,
		label + ": the Golem genuinely sits in that seat")
	_check(party.gain_block(golem_seat, 4), label + ": the Golem starts with four prior Block")
	party._heroes[golem_seat - 1]["buttons_popped"] = 2
	var enemies := _enemies([40, 40])
	var before := _snapshot(deck, party, enemies)
	var receipt = FistResolver.new().play_card(
		deck, party, enemies, card_id, target_position)

	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		label + ": the paid Fist resolves")
	_check(receipt.get("card_id") == card_id and receipt.get("cost") == 1
		and receipt.get("energy_spent") == 1,
		label + ": the receipt reports the card, its cost and one energy spent")
	_check(receipt.get("owner_position") == golem_seat
		and receipt.get("target_position") == target_position,
		label + ": the receipt reports the real owner and target seats")
	_check(receipt.get("printed_damage") == damage and receipt.get("damage") == damage,
		label + ": one unmodified printed hit of " + str(damage) + " is reported")
	_check(receipt.get("block_absorbed") == 0 and receipt.get("hp_loss") == damage,
		label + ": unblocked damage reaches HP")
	_check(receipt.get("block_gained") == block_self,
		label + ": it grants its printed " + str(block_self) + " self Block")
	_check(deck.energy == before["energy"] - 1
		and deck.combat_state.energy == before["state_energy"] - 1,
		label + ": exactly one energy left the deck state")
	_check(deck.hand.is_empty() and deck.discard_pile == [card_id]
		and deck.draw_pile == before["draw"] and deck.turn_active,
		label + ": one held copy moved to discard with no draw and no other deck change")

	var golem: Dictionary = party.get_hero(golem_seat)
	_check(golem.get("block") == 4 + block_self,
		label + ": prior Block is retained and the printed Block is added")
	_check(golem.get("hp") == before["heroes"][golem_seat - 1]["hp"]
		and golem.get("buttons_popped") == 2,
		label + ": the Golem's HP and popped-button count are untouched")
	for other in [1, 2, 3]:
		if other == golem_seat:
			continue
		_check(party.get_hero(other) == before["heroes"][other - 1],
			label + ": hero seat " + str(other) + " is untouched and gains no Block")

	var struck: Dictionary = enemies.get_enemy(target_position)
	_check(struck.get("hp") == 40 - damage and struck.get("block") == 0,
		label + ": the selected enemy lost exactly " + str(damage) + " HP")
	var other_enemy: int = 3 - target_position
	_check(enemies.get_enemy(other_enemy) == before["foes"][other_enemy - 1],
		label + ": the unselected enemy is untouched")
	_check(deck._rng.state == before["rng_state"]
		and deck._rng.seed == before["rng_seed"],
		label + ": the paid Fist consumes no seeded RNG draw")


# ---------------------------------------------------------------------------------------------
# AC2: one Weak/Exposed/Tangled pre-hit case, expected straight from the shared status rules.
# ---------------------------------------------------------------------------------------------

func _test_status_adjusted_hits() -> void:
	var rules := CombatStatuses.new()
	# card, attacker statuses, defender statuses, the literal shared-rule result.
	var cases := [
		{"card": "button_golem_starter_button_fist", "attacker": {"weak": 1},
			"defender": {}, "literal": 3, "relation": "down"},
		{"card": "button_golem_starter_button_fist_plus", "attacker": {},
			"defender": {"exposed": 1}, "literal": 10, "relation": "up"},
		{"card": "button_golem_starter_button_fist", "attacker": {},
			"defender": {"exposed": 1, "tangled": 2}, "literal": 9, "relation": "up"},
		{"card": "button_golem_starter_button_fist_plus", "attacker": {"weak": 1},
			"defender": {"exposed": 1}, "literal": 7, "relation": "even"},
	]
	for entry: Dictionary in cases:
		var card_id: String = entry["card"]
		var attacker: Dictionary = entry["attacker"]
		var defender: Dictionary = entry["defender"]
		var printed: int = int(FIST_PRINTINGS[card_id]["damage"])
		var label := "%s with %s vs %s" % [card_id, str(attacker), str(defender)]
		var expected: int = rules.adjusted_attack_damage(printed, attacker, defender)
		_check(expected == int(entry["literal"]),
			label + ": the shared status rules give the literal " + str(entry["literal"]))
		# The fixtures must exercise real arithmetic, not four copies of the printed number.
		if entry["relation"] == "down":
			_check(expected < printed, label + ": Weak lowers the printed " + str(printed))
		elif entry["relation"] == "up":
			_check(expected > printed, label + ": the defender's status raises the printed " + str(printed))
		else:
			_check(expected == printed, label + ": Weak and Exposed cancel back to the printed number")
		var deck := _deck([card_id])
		var party := _party(1)
		party._heroes[0]["statuses"] = attacker.duplicate(true)
		var enemies := _enemies_with_statuses(defender)
		_check(enemies.get_enemy(1).get("statuses", {}) == defender,
			label + ": the authoritative enemy carries those pre-hit statuses")
		var before := _snapshot(deck, party, enemies)
		var receipt = FistResolver.new().play_card(deck, party, enemies, card_id, 1)
		_check(receipt.get("ok") == true and receipt.get("damage") == expected
			and receipt.get("hp_loss") == expected,
			label + ": the one hit is the shared status-adjusted " + str(expected))
		_check(receipt.get("block_absorbed") == 0 and receipt.get("printed_damage") == printed,
			label + ": the receipt keeps the printed base and the adjusted hit apart")
		_check(enemies.get_enemy(1).get("hp") == 60 - expected,
			label + ": enemy HP follows the adjusted attack")
		_check(enemies.get_enemy(1).get("statuses", {}) == defender,
			label + ": the hit applies no new status to the enemy")
		_check(party.get_hero(1).get("statuses") == attacker,
			label + ": the hit consumes no status on the attacker")
		_check(party.get_hero(1).get("block") == int(FIST_PRINTINGS[card_id]["block_self"]),
			label + ": the printed self Block is granted after the adjusted hit")
		_check(deck._rng.state == before["rng_state"],
			label + ": no seeded RNG draw")


# ---------------------------------------------------------------------------------------------
# AC2: Block-absorbed and lethal hits both still grant the printed self Block.
# ---------------------------------------------------------------------------------------------

func _test_absorbed_and_lethal_hits() -> void:
	# Fully absorbed: enemy Block eats the whole blow before HP.
	var deck := _deck([base_id_of()])
	var party := _party(2)
	var enemies := _enemies([40])
	_check(enemies.gain_block(1, 20), "absorbed fixture gives the enemy twenty Block")
	var before := _snapshot(deck, party, enemies)
	var absorbed = FistResolver.new().play_card(deck, party, enemies, base_id_of(), 1)
	_check(absorbed.get("ok") == true and absorbed.get("damage") == 5
		and absorbed.get("block_absorbed") == 5 and absorbed.get("hp_loss") == 0,
		"enemy Block absorbs the whole five-damage Fist before HP")
	_check(enemies.get_enemy(1).get("hp") == 40 and enemies.get_enemy(1).get("block") == 15,
		"the fully absorbed hit leaves HP intact and spends five enemy Block")
	_check(party.get_hero(2).get("block") == 2,
		"a fully absorbed Fist still grants the Golem its two self Block")
	_check(party.get_hero(1) == before["heroes"][0] and party.get_hero(3) == before["heroes"][2],
		"only the Golem gains Block on a fully absorbed hit")

	# Lethal: the blow slays the target and the self Block is still granted.
	var killer_deck := _deck([plus_id_of()])
	var killer_party := _party(1)
	var killer_enemies := _enemies([3])
	var killer_before := _snapshot(killer_deck, killer_party, killer_enemies)
	var lethal = FistResolver.new().play_card(
		killer_deck, killer_party, killer_enemies, plus_id_of(), 1)
	_check(lethal.get("ok") == true and lethal.get("damage") == 7
		and lethal.get("block_absorbed") == 0 and lethal.get("hp_loss") == 3,
		"a lethal upgraded Fist reports its printed seven damage and the honest HP loss")
	_check(killer_enemies.is_slain(1) and killer_enemies.get_enemy(1).get("hp") == 0,
		"the lethal hit really slays the selected enemy in place")
	_check(killer_party.get_hero(1).get("block") == 3,
		"a lethal Fist still grants the Golem its three self Block")
	_check(killer_party.get_hero(2) == killer_before["heroes"][1]
		and killer_party.get_hero(3) == killer_before["heroes"][2]
		and killer_enemies.get_enemy(1).get("block") == 0,
		"no ally and no enemy gains Block from a lethal Fist")


# ---------------------------------------------------------------------------------------------
# AC3: every absent, malformed, unpayable or unlawful request is a complete no-op.
# ---------------------------------------------------------------------------------------------

func _test_refusals() -> void:
	# Foreign and malformed IDs, including the sibling Pop/Thread family IDs.
	_expect_refusal("Pop family ID held",
		_deck(["button_golem_starter_loose_pop"]), _party(1), _enemies([40]),
		"button_golem_starter_loose_pop", 1, "unsupported_card")
	_expect_refusal("Thread family ID held",
		_deck(["button_golem_button_knuckle"]), _party(1), _enemies([40]),
		"button_golem_button_knuckle", 1, "unsupported_card")
	_expect_refusal("unknown Fist-like ID",
		_deck([base_id_of()]), _party(1), _enemies([40]),
		"button_golem_starter_button_fist_plus_plus", 1, "unsupported_card")
	_expect_refusal("malformed card id",
		_deck([base_id_of()]), _party(1), _enemies([40]), null, 1, "unsupported_card")

	# Missing held copy and unaffordable energy.
	_expect_refusal("supported Fist not in hand",
		_deck([plus_id_of()]), _party(1), _enemies([40]), base_id_of(), 1, "card_not_held")
	var broke := _deck([base_id_of()])
	_check(broke.try_spend_energy(3) and broke.energy == 0 and broke.hand.size() == 1,
		"energy-short fixture is genuinely broke and still holds the card")
	_expect_refusal("insufficient energy", broke, _party(1), _enemies([40]),
		base_id_of(), 1, "insufficient_energy")
	_expect_refusal("inactive turn", _inactive_deck(base_id_of()), _party(1), _enemies([40]),
		base_id_of(), 1, "inactive_turn")

	# The Golem itself must be the single living body in hero seat 1 or 2.
	var absent := _party_of(["warden", "seamstress", "tinker"])
	_check(absent.is_valid() and absent.get_hero(1).get("id") != "button_golem",
		"absent-Golem fixture really has no Button Golem")
	_expect_refusal("no Button Golem in the party", _deck([base_id_of()]), absent,
		_enemies([40]), base_id_of(), 1, "owner_missing")
	var torn := _party(1)
	_check(torn.apply_damage(1, 400) and torn.is_downed(1),
		"downed-Golem fixture has a genuinely downed Golem")
	_expect_refusal("downed Golem", _deck([base_id_of()]), torn, _enemies([40]),
		base_id_of(), 1, "owner_torn")
	var back := _party_of(["warden", "tinker", "button_golem"])
	_check(back.get_hero(3).get("id") == "button_golem" and not back.is_downed(3),
		"wrong-seat fixture has a living Golem in the back seat")
	_expect_refusal("Golem in the back seat", _deck([base_id_of()]), back, _enemies([40]),
		base_id_of(), 1, "invalid_owner_position")
	var duplicate := _party(1)
	duplicate._heroes[1]["id"] = "button_golem"
	_check(duplicate.get_hero(2).get("id") == "button_golem",
		"duplicate-Golem fixture really carries a second Golem record")
	_expect_refusal("two Button Golems", _deck([base_id_of()]), duplicate, _enemies([40]),
		base_id_of(), 1, "duplicate_owner")

	# The target must be a living enemy inside the printed slots 1-2.
	for bad_target in [0, 3, -1, 99]:
		_expect_refusal("target outside the printed window: " + str(bad_target),
			_deck([base_id_of()]), _party(1), _enemies([40, 40, 40]), base_id_of(), bad_target,
			"invalid_target")
	var slain := _enemies([40, 40])
	_check(slain.apply_damage(1, 400) and slain.is_slain(1),
		"dead-target fixture has a genuinely slain front enemy")
	_expect_refusal("dead selected enemy", _deck([base_id_of()]), _party(1), slain,
		base_id_of(), 1, "invalid_target")

	# Invalid models and malformed authoritative state.
	_expect_refusal("missing deck", null, _party(1), _enemies([40]), base_id_of(), 1,
		"invalid_request")
	_expect_refusal("invalid party", _deck([base_id_of()]), CombatParty.new([]), _enemies([40]),
		base_id_of(), 1, "invalid_roster")
	var malformed_status := _party(1)
	malformed_status._heroes[0]["statuses"] = {"weak": "1"}
	_check(malformed_status.get_hero(1).get("statuses") == {"weak": "1"},
		"malformed-status fixture really stores a string counter")
	_expect_refusal("malformed Golem status map", _deck([base_id_of()]), malformed_status,
		_enemies([40]), base_id_of(), 1, "malformed_statuses")
	var malformed_enemy := _enemies([40])
	malformed_enemy._enemies[0]["statuses"] = {"tangled": 1.5}
	_expect_refusal("malformed enemy status map", _deck([base_id_of()]), _party(1),
		malformed_enemy, base_id_of(), 1, "malformed_statuses")
	var overflowing := _party(1)
	_check(overflowing.gain_block(1, CombatParty.MAX_INT - 1),
		"near-cap fixture holds MAX_INT - 1 Block")
	_expect_refusal("resulting Block above MAX_INT", _deck([base_id_of()]), overflowing,
		_enemies([40]), base_id_of(), 1, "block_overflow")

	# A read-only refusal receipt carries the same compact field set as a success.
	var receipt_deck := _deck([plus_id_of()])
	var receipt_party := _party(3)
	var receipt := FistResolver.new().play_card(
		receipt_deck, receipt_party, _enemies([40]), plus_id_of(), 1)
	for key: String in ["ok", "reason", "card_id", "cost", "owner_position", "target_position",
			"printed_damage", "damage", "block_absorbed", "hp_loss", "block_gained",
			"energy_spent"]:
		_check(receipt.has(key), "refusal receipt carries " + key)


func _expect_refusal(label: String, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, card_id: Variant, target_position: int, reason: String,
		resolver = null) -> void:
	if resolver == null:
		resolver = FistResolver.new()
	var before := _snapshot(deck, party, enemies)
	var receipt: Dictionary = resolver.play_card(deck, party, enemies, card_id, target_position)
	_check(receipt.get("ok") == false, label + ": refused")
	_check(receipt.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(receipt.get("reason")) + ")")
	_check(receipt.get("damage") == 0 and receipt.get("block_absorbed") == 0
		and receipt.get("hp_loss") == 0 and receipt.get("block_gained") == 0
		and receipt.get("energy_spent") == 0,
		label + ": refusal reports no hit, no Block and no payment")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": deck, party, enemies and seeded RNG are unchanged")


# ---------------------------------------------------------------------------------------------
# AC3: the new handler owns only its two IDs; the sibling families keep refusing Button Fist.
# ---------------------------------------------------------------------------------------------

func _test_family_isolation() -> void:
	var fist = FistResolver.new()
	var pop = PopResolver.new()
	var thread = ThreadResolver.new()
	for card_id: String in FIST_PRINTINGS:
		_check(not pop.is_supported_card(card_id),
			card_id + " stays foreign to the Pop Button family")
		_check(not thread.is_supported_card(card_id),
			card_id + " stays foreign to the Thread family")
		_check(fist.is_supported_card(card_id), card_id + " belongs to the Fist family")
	for card_id in ["button_golem_starter_loose_pop", "button_golem_starter_loose_pop_plus",
			"button_golem_pop_button", "button_golem_pop_button_plus",
			"button_golem_button_knuckle", "button_golem_button_knuckle_plus",
			"button_golem_buttonhole_snag", "button_golem_buttonhole_snag_plus"]:
		_check(not fist.is_supported_card(card_id),
			card_id + " is not claimed by the Fist family")


# ---------------------------------------------------------------------------------------------
# Fixtures.
# ---------------------------------------------------------------------------------------------

func base_id_of() -> String:
	return "button_golem_starter_button_fist"


func plus_id_of() -> String:
	return "button_golem_starter_button_fist_plus"


## A real three-hero party with the Button Golem genuinely sitting in the requested seat.
func _party(golem_seat: int) -> CombatParty:
	var order: Array = ["warden", "seamstress"]
	order.insert(golem_seat - 1, "button_golem")
	var party := _party_of(order)
	_check(party.get_hero(golem_seat).get("id") == "button_golem"
		and party.get_hero(golem_seat).get("position") == golem_seat,
		"fixture has the Golem living in seat " + str(golem_seat))
	return party


func _party_of(order: Array) -> CombatParty:
	var hp := {"button_golem": 48, "warden": 40, "seamstress": 30, "tinker": 26}
	var definitions: Array = []
	for hero_id: String in order:
		definitions.append({"id": hero_id, "max_hp": hp[hero_id]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_heroes().size() == CombatParty.PARTY_SIZE,
		"fixture has three distinct living heroes")
	return party


func _enemies(hps: Array[int]) -> CombatEnemies:
	var definitions: Array = []
	for index in hps.size():
		definitions.append({"id": "foe_%d" % (index + 1), "max_hp": hps[index]})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == hps.size(),
		"fixture has a valid enemy roster")
	return enemies


## One real enemy carrying authored pre-hit status data from construction.
func _enemies_with_statuses(statuses: Dictionary) -> CombatEnemies:
	var definition := {"id": "foe_1", "max_hp": 60}
	if not statuses.is_empty():
		definition["statuses"] = statuses.duplicate(true)
	var enemies := CombatEnemies.new([definition])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 1,
		"fixture has one valid status-carrying enemy")
	return enemies


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real seeded CombatDeck that starts the shared three-energy turn with the named cards held.
## Foreign authored cards are allowed so refusal fixtures can genuinely hold them.
func _deck(ids: Array, seed_value: int = 4171793) -> CombatDeck:
	var cards: Array[String] = []
	for id: Variant in ids:
		_check(_authored_card(id), str(id) + " is an authentic authored card")
		cards.append(str(id))
	var deck := CombatDeck.new(cards, _rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == mini(cards.size(), CombatDeck.TURN_DRAW),
		"seeded real CombatDeck starts a three-energy turn")
	return deck


func _authored_card(card_id: Variant) -> bool:
	return FistResolver.new().is_supported_card(card_id) \
		or StarterCatalog.new().has_card(card_id) \
		or PoolCatalog.new().has_card(card_id)


func _inactive_deck(card_id: String) -> CombatDeck:
	var deck := CombatDeck.new([card_id], _rng(4171793))
	_check(not deck.turn_active and deck.energy == 0 and deck.hand.is_empty(),
		"inactive-turn fixture really has not started its turn")
	return deck


## Detached before/after state for refusals: hand, piles, energy, turn, seeded RNG and both rosters.
func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	var snapshot: Dictionary = {}
	if deck != null:
		snapshot["draw"] = deck.draw_pile.duplicate(true)
		snapshot["hand"] = deck.hand.duplicate(true)
		snapshot["discard"] = deck.discard_pile.duplicate(true)
		snapshot["turn"] = deck.turn_active
		snapshot["energy"] = deck.energy
		if deck.combat_state != null:
			snapshot["state_turn"] = deck.combat_state.player_turn_active
			snapshot["state_energy"] = deck.combat_state.energy
		if deck._rng != null:
			snapshot["rng_state"] = deck._rng.state
			snapshot["rng_seed"] = deck._rng.seed
	if party != null:
		snapshot["party_valid"] = party.is_valid()
		snapshot["heroes"] = party.get_heroes()
	if enemies != null:
		snapshot["foes"] = enemies.get_enemies()
		snapshot["victory"] = enemies.is_victorious()
	return snapshot
