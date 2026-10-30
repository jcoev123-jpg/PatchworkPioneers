extends SceneTree
## Independent, headless service-layer contract. No mounted-hand claim is made.
const BASE := "scarecrow_harvest_fright"
const PLUS := "scarecrow_harvest_fright_plus"
const FILLERS: Array[String] = ["twig", "bobbin", "straw", "thread"]
var failures: Array[String] = []
var checks := 0
var service := CombatScarecrowHarvestFrightCards.new()

class ForgedHarvest extends CombatScarecrowHarvestFrightCards:
	var which := ""
	var change := ""
	func _catalog_definition(card_id: String) -> Dictionary:
		var record: Dictionary = super._catalog_definition(card_id)
		if card_id != which:
			return record
		match change:
			"damage":
				record["effects"]["damage"] += 1
			"fear":
				record["effects"]["cannot_buff_next_turn"] = 1
			"link":
				record["upgrade_of"] = "other"
			"metadata":
				record["illustration_path"] = "res://fake.png"
			"extra":
				record["unexpected"] = true
			"missing":
				record.erase("reward_eligible")
			"missing_pair":
				return {}
		return record

func _initialize() -> void:
	_test_catalog()
	_test_paid_sweeps()
	_test_survival_and_dead()
	_test_refusals()
	_test_forged()
	_test_seeded_replay()
	for message: String in failures:
		printerr(message)
	print("combat_scarecrow_harvest_fright_cards_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _rng(seed_value: int = 441) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator

func _fixture(card_id: String = BASE, seat: int = 2,
		hps: Array[int] = [21, 21, 21], seed_value: int = 441) -> Dictionary:
	var ids := ["warden", "tinker", "seamstress"]
	ids[seat - 1] = "scarecrow"
	var definitions: Array = []
	for id in ids:
		definitions.append({"id": id, "max_hp": 32, "statuses": {}})
	var party := CombatParty.new(definitions)
	var enemies_data: Array = []
	for i in range(hps.size()):
		enemies_data.append({"id": "foe_%d" % (i + 1), "max_hp": hps[i],
			"statuses": {}, "art_path": "res://assets/paper/enemies/test.png"})
	var enemies := CombatEnemies.new(enemies_data)
	var cards: Array[String] = FILLERS.duplicate()
	cards.append(card_id)
	var deck := CombatDeck.new(cards, _rng(seed_value))
	_check(deck.start_turn(), "real deck starts player turn")
	_check(deck.turn_active and deck.energy == 3 and deck.hand.size() == 5
		and deck.hand.count(card_id) == 1 and deck.draw_pile.is_empty(),
		"five-draw, three-energy, genuinely held source card")
	_check(party.is_valid() and enemies.is_valid() and party.get_hero(seat)["id"] == "scarecrow",
		"real seated Scarecrow and populated valid enemies")
	return {"deck": deck, "party": party, "enemies": enemies}

func _snapshot(fixture: Dictionary) -> Dictionary:
	var deck: CombatDeck = fixture["deck"]
	var party: CombatParty = fixture["party"]
	var enemies: CombatEnemies = fixture["enemies"]
	return {"draw": deck.draw_pile.duplicate(), "hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(), "exhausted": deck.exhausted.duplicate(),
		"energy": deck.energy, "turn": deck.turn_active,
		"combat_energy": deck.combat_state.energy,
		"combat_turn": deck.combat_state.player_turn_active,
		"rng": deck._rng.state, "heroes": party.get_heroes(),
		"enemies": enemies.get_enemies()}

func _play(fixture: Dictionary, card_id: Variant, target: int = 0,
		rules: CombatScarecrowHarvestFrightCards = null) -> Dictionary:
	var resolver: CombatScarecrowHarvestFrightCards = rules if rules != null else service
	return resolver.play_card(fixture["deck"], fixture["party"], fixture["enemies"],
		card_id, target)

func _paid_expected(before: Dictionary, card_id: String) -> Dictionary:
	var result: Dictionary = before.duplicate(true)
	result["energy"] = before["energy"] - 3
	result["combat_energy"] = before["combat_energy"] - 3
	result["hand"].erase(card_id)
	result["discard"].append(card_id)
	return result

func _test_catalog() -> void:
	var catalog := ScarecrowPoolCards.new()
	for card_id in [BASE, PLUS]:
		var printing: Dictionary = catalog.get_definition(card_id)
		_check(printing.get("id") == card_id and printing.get("owner") == "scarecrow"
			and printing.get("target_kind") == "enemy_all" and printing.get("cost") == 3
			and printing.get("from_positions") == [1, 2, 3]
			and printing.get("to_positions") == [1, 2, 3]
			and printing.get("effects") == {"damage": 6 if card_id == PLUS else 4,
				"weak": 3 if card_id == PLUS else 2,
				"cannot_buff_next_turn": true},
			card_id + ": authored enemy-wide damage/Weak/Fear with no invented status")
		_check(service.is_supported_card(card_id), card_id + ": authentic supported printing")
		_check(printing.get("starting_copies") == 0 and printing.get("rarity") == "rare"
			and printing.get("reward_eligible") == (card_id == BASE),
			card_id + ": rare reward-only and no starter copy")
	_check(catalog.get_definition(BASE).get("upgrade_id") == PLUS
		and catalog.get_definition(PLUS).get("upgrade_of") == BASE,
		"both authored upgrade links reciprocal")
	for bad in ["scarecrow_crow_flock", "scarecrow_harvest_fright_plus_plus",
			"harvest_fright", "", "warden_strike"]:
		_check(not service.is_supported_card(bad), "other card not supported: " + bad)
	_check(not service.is_supported_card(null) and not service.is_supported_card(3)
		and not service.is_supported_card(StringName(BASE)), "nonstring IDs rejected")

func _test_paid_sweeps() -> void:
	for card_id in [BASE, PLUS]:
		var plus: bool = card_id == PLUS
		var weak: int = 3 if plus else 2
		var damage: int = 6 if plus else 4
		var fixture := _fixture(card_id, 3)
		var party: CombatParty = fixture["party"]
		var enemies: CombatEnemies = fixture["enemies"]
		party._heroes[2]["statuses"] = {"weak": 1, "dodge_next_attack": 1,
			"cannot_buff_next_turn": true}
		enemies._enemies[0]["statuses"] = {"blind_next_attack": 1}
		enemies._enemies[1]["statuses"] = {"exposed": 2, "weak": 4,
			"cannot_buff_next_turn": true}
		enemies._enemies[2]["statuses"] = {"tangled": 1, "dodge_next_attack": 1}
		_check(enemies.gain_block(1, 1) and enemies.gain_block(2, 4),
			"real enemy Block was applied before hit")
		var before: Dictionary = _snapshot(fixture)
		var expected: Dictionary = _paid_expected(before, card_id)
		# Weak attacker reduces 4->3 and 6->4; Weak+Exposed floors 9/8:
		# 4->4 and 6->6; Tangled adds two after Weak's 3/4 floor.
		var attacks: Array[int] = [4 if plus else 3, 6 if plus else 4,
			6 if plus else 5]
		var blocks: Array[int] = [1, 4, 0]
		var expected_hits: Array[Dictionary] = []
		for i in range(3):
			var foe: Dictionary = expected["enemies"][i]
			var hp_before: int = foe["hp"]
			var block_before: int = foe["block"]
			var absorbed: int = mini(blocks[i], attacks[i])
			var lost: int = attacks[i] - absorbed
			foe["hp"] -= lost
			foe["block"] -= absorbed
			var statuses: Dictionary = foe["statuses"]
			statuses["weak"] = int(statuses.get("weak", 0)) + weak
			statuses["cannot_buff_next_turn"] = true
			expected_hits.append({"position": i + 1, "base_damage": damage,
				"damage": attacks[i], "block_absorbed": absorbed, "hp_loss": lost,
				"hp_before": hp_before, "hp_after": foe["hp"],
				"block_before": block_before, "block_after": foe["block"],
				"weak_applied": weak, "fear_applied": true})
		var result: Dictionary = _play(fixture, card_id)
		_check(result == {"ok": true, "reason": "applied", "card_id": card_id,
			"cost": 3, "energy_spent": 3, "energy_before": 3,
			"energy_after": 0, "owner_position": 3,
			"target_position": 0, "targets": [1, 2, 3], "hits": expected_hits},
			card_id + ": exact independent Block-before-HP hit receipts")
		_check(_snapshot(fixture) == expected,
			card_id + ": COMPLETE paid state (piles, statuses, HP, Block, hero, RNG)")
		_check(CombatStatuses.new().can_apply_buff(enemies.get_enemy(2)["statuses"])
			== {"ok": true, "allowed": false}, card_id + ": surviving foe buff denied")
		var tick: Dictionary = CombatStatusTurnBatch.new().tick_side("enemies",
			enemies.get_enemies())
		_check(tick["ok"] and not tick["actors"][1]["statuses"].has("cannot_buff_next_turn")
			and tick["actors"][1]["statuses"]["weak"] == 3 + weak
			and tick["actors"][2]["statuses"]["weak"] == weak - 1,
			card_id + ": Fear expires at owner end; stacked Weak ages independently")
		_check(CombatStatuses.new().can_apply_buff(tick["actors"][1]["statuses"])
			== {"ok": true, "allowed": true}, card_id + ": buff allowed after Fear expiry")
		_check(_snapshot(fixture) == expected, card_id + ": pure lifecycle projection never commits")
		_check(not _play(fixture, card_id).get("ok", false)
			and _snapshot(fixture) == expected,
			card_id + ": replay cannot spend or redraw")

func _test_survival_and_dead() -> void:
	for card_id in [BASE, PLUS]:
		var damage: int = 6 if card_id == PLUS else 4
		var fixture := _fixture(card_id)
		var enemies: CombatEnemies = fixture["enemies"]
		enemies._enemies[0]["hp"] = 2
		enemies._enemies[1]["statuses"] = {"weak": 8}
		_check(enemies.apply_damage(2, 21), "second enemy pre-slain")
		enemies._enemies[2]["statuses"] = {"bleed": 2, "riposte": 3}
		var before: Dictionary = _snapshot(fixture)
		var expected: Dictionary = _paid_expected(before, card_id)
		expected["enemies"][0]["hp"] = 0
		expected["enemies"][2]["hp"] = 21 - damage
		expected["enemies"][2]["statuses"]["weak"] = 3 if card_id == PLUS else 2
		expected["enemies"][2]["statuses"]["cannot_buff_next_turn"] = true
		var result: Dictionary = _play(fixture, card_id)
		_check(result.get("ok") == true and result.get("targets") == [1, 3]
			and result["hits"].size() == 2,
			card_id + ": two living printed targets retain original positions")
		_check(result["hits"][0] == {"position": 1, "base_damage": damage,
			"damage": damage, "block_absorbed": 0, "hp_loss": 2,
			"hp_before": 2, "hp_after": 0, "block_before": 0, "block_after": 0,
			"weak_applied": 0, "fear_applied": false},
			card_id + ": lethal hit adds no persistent status")
		_check(result["hits"][1]["weak_applied"] == (3 if card_id == PLUS else 2)
			and result["hits"][1]["fear_applied"],
			card_id + ": living third slot gets only its own Fear and Weak")
		_check(_snapshot(fixture) == expected,
			card_id + ": slain slot untouched; all state, piles and RNG exact")
	# One enemy works, without indexing absent seats; zero targets never spends.
	var single := _fixture(BASE, 1, [17])
	var result: Dictionary = _play(single, BASE)
	_check(result.get("ok") and result.get("targets") == [1]
		and single["enemies"].get_enemy(1)["hp"] == 13,
		"one-enemy area attack succeeds with stable slot")
	var none := _fixture(BASE, 1, [17])
	none["enemies"].apply_damage(1, 17)
	_refused(none, BASE, 0, service, "no living targets")
	# The engine currently caps combat rosters at three; if extended, the fourth
	# actor must be validated but never be included in this printing's TO [1,2,3].
	if CombatEnemies.MAX_ENEMIES >= 4:
		var fourth := _fixture(BASE, 2, [20, 20, 20, 20])
		var snapshot: Dictionary = _snapshot(fourth)
		var attack: Dictionary = _play(fourth, BASE)
		_check(attack.get("ok") and attack.get("targets") == [1, 2, 3]
			and fourth["enemies"].get_enemy(4) == snapshot["enemies"][3],
			"optional fourth slot is untouched")

func _refused(fixture: Dictionary, card_id: Variant, position: int,
		rules: CombatScarecrowHarvestFrightCards, label: String) -> void:
	var before: Dictionary = _snapshot(fixture)
	var outcome: Dictionary = _play(fixture, card_id, position, rules)
	_check(not outcome.get("ok", false), label + ": fails closed")
	_check(_snapshot(fixture) == before, label + ": no hand/energy/piles/party/enemy/RNG change")

func _test_refusals() -> void:
	_refused(_fixture(BASE), PLUS, 0, service, "authentic but unheld variant")
	_refused(_fixture(BASE), BASE, 2, service, "nonzero enemy_all target")
	_refused(_fixture(BASE), "scarecrow_crow_flock", 0, service, "unsupported effect")
	_refused(_fixture(BASE), null, 0, service, "nonstring ID")
	var down := _fixture(BASE)
	down["party"]._heroes[1]["hp"] = 0
	_refused(down, BASE, 0, service, "downed owner")
	var absent := _fixture(BASE)
	absent["party"]._heroes[1]["id"] = "lantern_monk"
	_refused(absent, BASE, 0, service, "missing owner")
	var duplicate := _fixture(BASE)
	duplicate["party"]._heroes[0]["id"] = "scarecrow"
	_refused(duplicate, BASE, 0, service, "duplicate owner")
	var wrong := _fixture(BASE)
	wrong["party"]._heroes[1]["position"] = 3
	_refused(wrong, BASE, 0, service, "malformed seat")
	var low := _fixture(BASE)
	_check(low["deck"].try_spend_energy(1), "insufficient energy fixture paid one")
	_refused(low, BASE, 0, service, "insufficient energy")
	var unheld := _fixture(BASE)
	unheld["deck"].hand.erase(BASE)
	_refused(unheld, BASE, 0, service, "removed held card")
	var inactive := _fixture(BASE)
	_check(inactive["deck"].end_turn(), "inactive fixture genuinely ended")
	_refused(inactive, BASE, 0, service, "inactive turn")
	var status := _fixture(BASE)
	status["enemies"]._enemies[2]["statuses"] = {"cannot_buff_next_turn": 1}
	_refused(status, BASE, 0, service, "malformed Fear in late slot")
	var status_hero := _fixture(BASE)
	status_hero["party"]._heroes[0]["statuses"] = {"weak": -1}
	_refused(status_hero, BASE, 0, service, "malformed hero status")
	var overflow := _fixture(BASE)
	overflow["enemies"]._enemies[2]["statuses"] = {"weak": CombatEnemies.MAX_INT}
	_refused(overflow, BASE, 0, service, "Weak stack overflow before charge")
	var roster := _fixture(BASE)
	roster["enemies"]._enemies[2]["position"] = 1
	_refused(roster, BASE, 0, service, "malformed late enemy seat")
	var broken := _fixture(BASE)
	broken["enemies"]._enemies[2]["block"] = -1
	_refused(broken, BASE, 0, service, "malformed enemy Block")
	# Preserve genuine additional hand copy on one paid play.
	var duplicate_copy := _fixture(BASE)
	duplicate_copy["deck"].hand.append(BASE)
	var paid: Dictionary = _play(duplicate_copy, BASE)
	_check(paid.get("ok") and duplicate_copy["deck"].hand.count(BASE) == 1
		and duplicate_copy["deck"].discard_pile.count(BASE) == 1,
		"one charge and one discard even with duplicate held copy")

func _test_forged() -> void:
	for variant in [BASE, PLUS]:
		for altered in ["damage", "fear", "link", "metadata", "extra", "missing", "missing_pair"]:
			var forgery := ForgedHarvest.new()
			forgery.which = PLUS if variant == BASE else BASE
			forgery.change = altered
			_check(not forgery.is_supported_card(variant),
				"forged reciprocal catalog rejects support: " + altered)
			_refused(_fixture(variant), variant, 0, forgery,
				"forged partner " + variant + " " + altered)
			forgery.which = variant
			_refused(_fixture(variant), variant, 0, forgery,
				"forged held printing " + variant + " " + altered)

func _test_seeded_replay() -> void:
	var first := _fixture(PLUS, 1, [18, 22, 16], 333)
	var second := _fixture(PLUS, 1, [18, 22, 16], 333)
	_check(_snapshot(first) == _snapshot(second), "identical pre-play seed")
	_check(_play(first, PLUS) == _play(second, PLUS), "identical paid hit receipts")
	_check(_snapshot(first) == _snapshot(second), "identical complete post-play replay")
