extends SceneTree
## Independent, headless service-layer contract for Crow Flock. No mounted-hand claim is made.
const BASE := "scarecrow_crow_flock"
const PLUS := "scarecrow_crow_flock_plus"
const FEAR := CombatScarecrowCrowFlockCards.FEAR_STATUS_KEY
const WEAK := CombatScarecrowCrowFlockCards.WEAK_STATUS_KEY
const FILLERS: Array[String] = ["twig", "bobbin", "straw", "thread"]
var failures: Array[String] = []
var checks := 0
var service := CombatScarecrowCrowFlockCards.new()

class ForgedCrowFlock extends CombatScarecrowCrowFlockCards:
	var which := ""
	var change := ""
	func _catalog_definition(card_id: String) -> Dictionary:
		var record: Dictionary = super._catalog_definition(card_id)
		if card_id != which:
			return record
		match change:
			"weak":
				record["effects"]["weak"] += 1
			"fear":
				record["effects"]["cannot_buff_next_turn"] = 1
			"effect_extra":
				record["effects"]["damage"] = 1
			"cost":
				record["cost"] = 1
			"target":
				record["target_kind"] = "enemy_single"
			"slots":
				record["to_positions"] = [1, 2]
			"from":
				record["from_positions"] = [1, 2, 3]
			"link":
				record["upgrade_of" if record.has("upgrade_of") else "upgrade_id"] = "other"
			"display":
				record["display_name"] = "Crow Flock?"
			"metadata":
				record["illustration_path"] = "res://fake.png"
			"extra":
				record["unexpected"] = true
			"missing":
				record.erase("rarity")
			"missing_pair":
				return {}
			"wrong_catalog":
				return ScarecrowPoolCards.new().get_definition("scarecrow_harvest_fright")
		return record


func _initialize() -> void:
	_test_catalog()
	_test_paid_sweeps()
	_test_dead_and_fourth()
	_test_refusals()
	_test_forged_catalog()
	_test_fear_lifecycle()
	_test_seeded_replay()
	for message: String in failures:
		printerr(message)
	print("combat_scarecrow_crow_flock_cards_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _rng(seed_value: int = 6207) -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = seed_value
	return generator


## A real five-card, three-energy player turn with `copies` genuine held printings. `seat` places
## the authoritative Scarecrow; `hps` sizes the real roster (one to CombatEnemies.MAX_ENEMIES).
func _fixture(card_id: String = BASE, seat: int = 2,
		hps: Array[int] = [24, 24, 24], copies: int = 1,
		seed_value: int = 6207) -> Dictionary:
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
	var cards: Array[String] = []
	for i in range(5 - copies):
		cards.append(FILLERS[i])
	for i in range(copies):
		cards.append(card_id)
	var deck := CombatDeck.new(cards, _rng(seed_value))
	_check(deck.start_turn(), "real deck starts a player turn")
	_check(deck.turn_active and deck.energy == 3 and deck.hand.size() == 5
		and deck.hand.count(card_id) == copies and deck.draw_pile.is_empty(),
		"five-draw, three-energy, genuinely held source card copies")
	_check(party.is_valid() and enemies.is_valid() and party.get_hero(seat)["id"] == "scarecrow",
		"real seated Scarecrow and populated valid enemy roster")
	return {"deck": deck, "party": party, "enemies": enemies}


## Complete authoritative snapshot: piles, turn flags, energy, run RNG, party and enemies.
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


func _play(fixture: Dictionary, card_id: Variant, position: int = 0,
		rules: CombatScarecrowCrowFlockCards = null) -> Dictionary:
	var resolver: CombatScarecrowCrowFlockCards = rules if rules != null else service
	return resolver.play_card(fixture["deck"], fixture["party"], fixture["enemies"],
		card_id, position)


## The paid expectation: two energy, one discarded copy and the printed Weak plus Fear on each
## living slot listed in `positions`, with every other field exactly as before.
func _paid_expected(before: Dictionary, card_id: String, weak: int,
		positions: Array) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = before["energy"] - 2
	expected["combat_energy"] = before["combat_energy"] - 2
	expected["hand"].erase(card_id)
	expected["discard"].append(card_id)
	for position: int in positions:
		var foe: Dictionary = expected["enemies"][position - 1]
		foe["statuses"][WEAK] = int(foe["statuses"].get(WEAK, 0)) + weak
		foe["statuses"][FEAR] = true
	return expected


## The printed Weak for a printing, read from the authored catalog (not from the service's table).
func _authored_weak(card_id: String) -> int:
	return int(ScarecrowPoolCards.new().get_definition(card_id)["effects"][WEAK])


func _test_catalog() -> void:
	var catalog := ScarecrowPoolCards.new()
	for card_id in [BASE, PLUS]:
		var plus: bool = card_id == PLUS
		var printing: Dictionary = catalog.get_definition(card_id)
		_check(printing.get("id") == card_id and printing.get("owner") == "scarecrow"
			and printing.get("cost") == 2 and printing.get("target_kind") == "enemy_all"
			and printing.get("from_positions") == [2, 3]
			and printing.get("to_positions") == [1, 2, 3]
			and printing.get("effects") == {WEAK: 2 if plus else 1, FEAR: true}
			and printing.get("starting_copies") == 0 and printing.get("rarity") == "uncommon"
			and printing.get("reward_eligible") == not plus,
			card_id + ": authored two-energy enemy-wide Weak/Fear printing")
		_check(int(printing["effects"][WEAK]) == (2 if plus else 1),
			card_id + ": printed Weak is exactly %d" % (2 if plus else 1))
		_check(CombatScarecrowCrowFlockCards.CARDS[card_id]["weak"] == _authored_weak(card_id),
			card_id + ": service table matches the authored Weak")
		_check(catalog.get_definition(card_id).get("display_name") == "Crow Flock" + ("+" if plus else ""),
			card_id + ": authored display name")
		_check(service.is_supported_card(card_id), card_id + ": authentic supported printing")
	_check(catalog.get_definition(BASE).get("upgrade_id") == PLUS
		and catalog.get_definition(PLUS).get("upgrade_of") == BASE,
		"both authored upgrade links reciprocal")
	for bad in ["scarecrow_crow_flock_plus_plus", "crow_flock", "CROW_FLOCK",
			" scarecrow_crow_flock", "scarecrow_crow_flock ",
			"scarecrow_harvest_fright", "scarecrow_harvest_fright_plus",
			"scarecrow_sack_grin", "scarecrow_sack_grin_plus", "scarecrow_crow_peck",
			"scarecrow_pitchfork_prick", "scarecrow_fork_jab", "warden_strike", ""]:
		_check(not service.is_supported_card(bad), "other card not supported: " + bad)
	for bad_value: Variant in [null, 2, 3.5, true, {}, [], StringName(BASE)]:
		_check(not service.is_supported_card(bad_value), "non-string ID not supported: " + str(bad_value))


## AC1: from either legal seat each printing pays exactly two energy, discards exactly one held copy
## and adds its exact Weak to every living authored slot plus one literal Fear flag, while HP, Block,
## every other status, the party, the other piles and the run RNG stay identical.
func _test_paid_sweeps() -> void:
	for card_id in [BASE, PLUS]:
		for seat in [2, 3]:
			var weak: int = _authored_weak(card_id)
			var fixture := _fixture(card_id, seat)
			var enemies: CombatEnemies = fixture["enemies"]
			enemies._enemies[0]["statuses"] = {"weak": 1, "bleed": 2}
			enemies._enemies[1]["statuses"] = {"weak": 2, "exposed": 1, FEAR: true}
			enemies._enemies[2]["statuses"] = {"tangled": 1, "riposte": 2,
				"dodge_next_attack": 1, "blind_next_attack": 1}
			_check(enemies.gain_block(1, 2) and enemies.gain_block(2, 3),
				"real enemy Block exists before the flock")
			var before := _snapshot(fixture)
			var expected := _paid_expected(before, card_id, weak, [1, 2, 3])
			var result := _play(fixture, card_id)
			_check(result.get("ok") == true and result.get("reason") == "applied"
				and result.get("card_id") == card_id and result.get("cost") == 2
				and result.get("energy_before") == 3 and result.get("energy_after") == 1
				and result.get("owner_position") == seat and result.get("target_position") == 0
				and result.get("targets") == [1, 2, 3] and result.get("weak") == weak,
				"%s seat %d: exact target-free area receipt" % [card_id, seat])
			var applied: Array = result.get("applied", [])
			_check(applied.size() == 3 and applied[0].get("position") == 1
				and applied[0].get("weak_before") == 1
				and applied[0].get("weak_after") == 1 + weak
				and applied[0].get("fear_before") == false
				and applied[0].get("fear_applied") == true
				and applied[1].get("weak_before") == 2
				and applied[1].get("weak_after") == 2 + weak
				and applied[1].get("fear_before") == true
				and applied[2].get("weak_before") == 0
				and applied[2].get("fear_before") == false,
				"%s: per-slot receipts preserve existing Weak and Fear state" % card_id)
			_check(_snapshot(fixture) == expected,
				"%s: complete paid state (piles, statuses, HP, Block, party, RNG)" % card_id)
			_check(fixture["deck"].draw_pile == before["draw"]
				and fixture["deck"].hand.size() == before["hand"].size() - 1
				and fixture["deck"].discard_pile == before["discard"] + [card_id],
				"%s: exactly one discard with no extra draw" % card_id)
			_check(enemies.get_enemies().map(func(enemy): return enemy["position"])
				== [1, 2, 3], "%s: every enemy keeps its fixed slot identity" % card_id)
			for position in [1, 2, 3]:
				var marked: Dictionary = enemies.get_enemy(position)
				_check(marked.get("statuses", {}).get(FEAR) is bool
					and marked.get("statuses", {}).get(FEAR) == true,
					"%s: slot %d carries literal boolean Fear" % [card_id, position])
				_check(CombatStatuses.new().can_apply_buff(marked.get("statuses", {}))
					== {"ok": true, "allowed": false},
					"%s: slot %d cannot buff before its next enemy turn" % [card_id, position])
			_check(enemies.get_enemy(1)["statuses"].get("bleed") == 2
				and enemies.get_enemy(2)["statuses"].get("exposed") == 1
				and enemies.get_enemy(3)["statuses"].get("tangled") == 1
				and enemies.get_enemy(3)["statuses"].get("riposte") == 2
				and enemies.get_enemy(3)["statuses"].get("dodge_next_attack") == 1
				and enemies.get_enemy(3)["statuses"].get("blind_next_attack") == 1,
				"%s: non-Weak statuses are untouched" % card_id)
			var tick: Dictionary = CombatStatusTurnBatch.new().tick_side("enemies",
				enemies.get_enemies())
			_check(tick.get("ok", false), "%s: enemy owner-turn batch is valid" % card_id)
			# Pre-tick Weak was 1+weak / 2+weak / weak, so one owner-turn boundary leaves
			# weak / weak+1 / weak-1 (absent at zero) while the one-turn Fear flag is gone.
			var aged: Array[int] = [weak, weak + 1, maxi(0, weak - 1)]
			for index in range(3):
				var statuses: Dictionary = tick["actors"][index]["statuses"]
				var remaining: int = aged[index]
				var aged_ok: bool = not statuses.has(FEAR)
				if remaining == 0:
					aged_ok = aged_ok and not statuses.has(WEAK)
				else:
					aged_ok = aged_ok and int(statuses.get(WEAK, 0)) == remaining
				_check(aged_ok,
					"%s: slot %d Fear expires at the owner turn; Weak ages separately"
					% [card_id, index + 1])
				_check(CombatStatuses.new().can_apply_buff(statuses)
					== {"ok": true, "allowed": true},
					"%s: slot %d may buff again after expiry" % [card_id, index + 1])
			_check(_snapshot(fixture) == expected,
				"%s: pure lifecycle projection never commits" % card_id)
			_check(not _play(fixture, card_id).get("ok", false)
				and _snapshot(fixture) == expected,
				"%s: replay cannot spend, redraw or re-mark" % card_id)


## AC1: a slain slot and any slot outside the printed window keep their fixed identity and every
## field; a zero-target roster refuses before payment.
func _test_dead_and_fourth() -> void:
	for card_id in [BASE, PLUS]:
		var weak: int = _authored_weak(card_id)
		var fixture := _fixture(card_id, 3)
		var enemies: CombatEnemies = fixture["enemies"]
		_check(enemies.apply_damage(2, 24) and enemies.is_slain(2),
			"second enemy genuinely slain before the flock")
		var before := _snapshot(fixture)
		var expected := _paid_expected(before, card_id, weak, [1, 3])
		var result := _play(fixture, card_id)
		_check(result.get("ok") == true and result.get("targets") == [1, 3]
			and result.get("applied", []).size() == 2
			and result["applied"][1].get("position") == 3,
			card_id + ": only living printed slots are affected")
		_check(_snapshot(fixture) == expected,
			card_id + ": slain slot untouched; complete state, piles and RNG exact")
		_check(enemies.get_enemy(2).get("statuses", {}) == {},
			card_id + ": slain slot gains neither Weak nor Fear")
		# The engine caps combat rosters at three slots today; if that cap is raised, the fourth actor
		# must still be validated but never included in this printing's authored TO [1,2,3].
		if CombatEnemies.MAX_ENEMIES >= 4:
			var fourth := _fixture(card_id, 2, [20, 20, 20, 20])
			var untouched: Dictionary = fourth["enemies"].get_enemy(4)
			var area: Dictionary = _play(fourth, card_id)
			_check(area.get("ok") == true and area.get("targets") == [1, 2, 3]
				and fourth["enemies"].get_enemy(4) == untouched,
				card_id + ": optional fourth slot is untouched")
	# One real enemy works without indexing absent seats.
		var single := _fixture(card_id, 2, [17])
		var only: Dictionary = _play(single, card_id)
		_check(only.get("ok") == true and only.get("targets") == [1]
			and single["enemies"].get_enemy(1)["statuses"] == {WEAK: weak, FEAR: true},
			card_id + ": a one-enemy area still pays for its single living slot")
		# A valid roster whose every authored slot is already slain has nothing to fear.
		var none := _fixture(card_id, 2, [17, 17, 17])
		var none_enemies: CombatEnemies = none["enemies"]
		_check(none_enemies.apply_damage(1, 17) and none_enemies.apply_damage(2, 17)
			and none_enemies.apply_damage(3, 17), "all printed slots genuinely slain")
		_refused(none, card_id, 0, service, card_id + " all-dead roster", "no_living_targets")


func _refused(fixture: Dictionary, card_id: Variant, position: int,
		rules: CombatScarecrowCrowFlockCards, label: String,
		expected_reason: String = "") -> void:
	var before: Dictionary = _snapshot(fixture)
	var outcome: Dictionary = _play(fixture, card_id, position, rules)
	_check(not outcome.get("ok", false), label + ": fails closed")
	if expected_reason != "":
		_check(outcome.get("reason") == expected_reason,
			label + ": refusal reason is " + expected_reason)
	_check(_snapshot(fixture) == before, label + ": no hand/energy/piles/party/enemy/RNG change")


## AC2: representative preflight failures change nothing at all.
func _test_refusals() -> void:
	var nulls := _fixture()
	var before := _snapshot(nulls)
	_check(service.play_card(null, nulls["party"], nulls["enemies"], BASE, 0).get("reason")
		== "invalid_request", "null deck refused")
	_check(service.play_card(nulls["deck"], null, nulls["enemies"], BASE, 0).get("reason")
		== "invalid_request", "null party refused")
	_check(service.play_card(nulls["deck"], nulls["party"], null, BASE, 0).get("reason")
		== "invalid_request", "null enemies refused")
	_check(_snapshot(nulls) == before, "null authorities preserve every authority")

	var inactive := _fixture()
	_check(inactive["deck"].end_turn(), "inactive fixture really ends the shared turn")
	_refused(inactive, BASE, 0, service, "inactive turn", "inactive_turn")

	for broken: Variant in [null, 5, 3.5, true, [], {}, StringName(BASE), "",
			"scarecrow_crow_flock_plus_plus", "CROW_FLOCK", "scarecrow_harvest_fright"]:
		_refused(_fixture(), broken, 0, service, "unsupported card " + str(broken),
			"unsupported_card")

	_refused(_fixture(PLUS), BASE, 0, service, "authentic but unheld base", "card_not_held")
	_refused(_fixture(BASE), PLUS, 0, service, "authentic but unhed plus", "card_not_held")
	var removed := _fixture(BASE)
	removed["deck"].hand.erase(BASE)
	_refused(removed, BASE, 0, service, "removed held copy", "card_not_held")

	var poor := _fixture(BASE)
	_check(poor["deck"].try_spend_energy(2) and poor["deck"].energy == 1,
		"insufficient-energy fixture really spent below the cost")
	_refused(poor, BASE, 0, service, "insufficient energy", "insufficient_energy")

	# Ownership: absent, downed, duplicated or seated outside the printed 2-3 window.
	var absent := _fixture(BASE)
	absent["party"] = CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 25},
	])
	_check(absent["party"].is_valid() and absent["party"].get_hero(2)["id"] == "seamstress",
		"missing-owner fixture is a valid living party without a Scarecrow")
	_refused(absent, BASE, 0, service, "missing owner", "owner_missing")

	var downed := _fixture(BASE, 3)
	_check(downed["party"].apply_damage(3, 32) and downed["party"].is_downed(3),
		"downed-owner fixture really has a zero-HP Scarecrow in seat 3")
	_refused(downed, BASE, 0, service, "downed owner", "owner_downed")

	var duplicate := _fixture(BASE)
	duplicate["party"]._heroes[0]["id"] = "scarecrow"
	_check(duplicate["party"].get_hero(1)["id"] == "scarecrow"
		and duplicate["party"].get_hero(2)["id"] == "scarecrow",
		"duplicate-identity fixture really repeats the owner ID")
	_refused(duplicate, BASE, 0, service, "duplicate owner", "invalid_party")

	_refused(_fixture(BASE, 1), BASE, 0, service, "front-seat owner", "owner_illegal_position")

	var moved := _fixture(BASE, 3)
	moved["party"]._heroes[2]["position"] = 1
	_refused(moved, BASE, 0, service, "owner moved out of its actual seat", "invalid_party")

	var short_party := _fixture(BASE)
	short_party["party"] = CombatParty.new([
		{"id": "scarecrow", "max_hp": 34},
		{"id": "warden", "max_hp": 40},
	])
	_check(not short_party["party"].is_valid(), "short-party fixture is really invalid")
	_refused(short_party, BASE, 0, service, "short party", "invalid_party")

	var bad_hp := _fixture(BASE)
	bad_hp["party"]._heroes[1]["hp"] = 99
	_refused(bad_hp, BASE, 0, service, "over-capped hero HP", "invalid_party")

	var bad_hero_status := _fixture(BASE)
	bad_hero_status["party"]._heroes[0]["statuses"] = {"forged": 1}
	_refused(bad_hero_status, BASE, 0, service, "malformed hero status", "malformed_statuses")

	# Roster shape and every authoritative enemy status map.
	var empty_roster := _fixture(BASE)
	empty_roster["enemies"] = CombatEnemies.new([])
	_check(not empty_roster["enemies"].is_valid(), "empty-roster fixture is really invalid")
	_refused(empty_roster, BASE, 0, service, "empty roster", "invalid_enemies")

	var bad_enemy_hp := _fixture(BASE)
	bad_enemy_hp["enemies"]._enemies[1]["hp"] = 99
	_refused(bad_enemy_hp, BASE, 0, service, "over-capped enemy HP", "invalid_enemies")

	var bad_block := _fixture(BASE)
	bad_block["enemies"]._enemies[2]["block"] = -1
	_refused(bad_block, BASE, 0, service, "negative enemy Block", "invalid_enemies")

	var bad_slot := _fixture(BASE)
	bad_slot["enemies"]._enemies[2]["position"] = 1
	_refused(bad_slot, BASE, 0, service, "malformed enemy seat", "invalid_enemies")

	for malformed: Dictionary in [{[FEAR]: 1}, {[FEAR]: false}, {[FEAR]: "true"},
			{[FEAR]: 1.0}, {"fear": true}, {"Fear": true}, {WEAK: "2"}, {WEAK: -1},
			{WEAK: 1.5}, {"forged": 1}, {"dodge_next_attack": 2}, {"blind_next_attack": -1}]:
		var broken_status := _fixture(BASE)
		broken_status["enemies"]._enemies[2]["statuses"] = malformed.duplicate(true)
		_refused(broken_status, BASE, 0, service, "malformed enemy status " + str(malformed),
			"malformed_statuses")

	var overflow := _fixture(BASE)
	overflow["enemies"]._enemies[0]["statuses"] = {WEAK: CombatEnemies.MAX_INT}
	_refused(overflow, BASE, 0, service, "Weak stack overflow before charge", "malformed_statuses")

	# enemy_all carries no selected target: only the zero sentinel is accepted.
	for position: int in [1, 2, 3, -1, 4]:
		_refused(_fixture(BASE), BASE, position, service,
			"selected target " + str(position), "invalid_target")

	# One genuine play discards exactly one of two held copies.
	var two := _fixture(BASE, 2, [24, 24, 24], 2)
	var first := _play(two, BASE)
	_check(first.get("ok", false) and two["deck"].energy == 1
		and two["deck"].hand.count(BASE) == 1 and two["deck"].discard_pile.count(BASE) == 1
		and two["enemies"].get_enemy(1)["statuses"] == {WEAK: 1, FEAR: true},
		"one charge and one discard even with a second genuine held copy")
	var settled := _snapshot(two)
	_refused(two, BASE, 0, service, "paid replay", "insufficient_energy")
	_check(_snapshot(two) == settled, "paid replay changed nothing")


## AC2: a forged or mismatched catalog pairing can never pay, whichever printing is held.
func _test_forged_catalog() -> void:
	for variant in [BASE, PLUS]:
		var partner: String = PLUS if variant == BASE else BASE
		for altered in ["weak", "fear", "effect_extra", "cost", "target", "slots", "from",
				"link", "display", "metadata", "extra", "missing", "missing_pair",
				"wrong_catalog"]:
			var forgery := ForgedCrowFlock.new()
			forgery.which = variant
			forgery.change = altered
			_check(not forgery.is_supported_card(variant),
				"forged held printing rejected: %s %s" % [variant, altered])
			_refused(_fixture(variant), variant, 0, forgery,
				"forged held printing " + altered, "catalog_mismatch")
			forgery.which = partner
			_check(not forgery.is_supported_card(variant),
				"forged reciprocal partner rejected: %s %s" % [variant, altered])
			_refused(_fixture(variant), variant, 0, forgery,
				"forged reciprocal partner " + altered, "catalog_mismatch")


## AC3: authentic reapplication re-arms the same one-turn flag after the enemy owner turn and
## stacks only Weak; Fear never becomes a count.
func _test_fear_lifecycle() -> void:
	for card_id in [BASE, PLUS]:
		var weak: int = _authored_weak(card_id)
		var fixture := _fixture(card_id, 2, [30, 30, 30], 2)
		var enemies: CombatEnemies = fixture["enemies"]
		# Budget a second authentic cast on the same real shared player turn.
		fixture["deck"].combat_state.energy = 4
		var first := _play(fixture, card_id)
		_check(first.get("ok", false), card_id + ": first authentic cast commits")
		var armed: Dictionary = enemies.get_enemy(1)
		_check(armed.get("statuses") == {WEAK: weak, FEAR: true}
			and armed["statuses"][FEAR] is bool,
			card_id + ": one literal Fear flag beside the printed Weak")
		_check(CombatStatuses.new().can_apply_buff(armed["statuses"])
			== {"ok": true, "allowed": false},
			card_id + ": buff denied before its next enemy turn")
		# The enemy owner-turn boundary is the only thing that expires Fear; commit the pure batch
		# proposal field by field exactly as CombatRoundFlow does after the enemy phase.
		var tick: Dictionary = CombatStatusTurnBatch.new().tick_side("enemies",
			enemies.get_enemies())
		_check(tick.get("ok", false), card_id + ": enemy owner-turn batch is valid")
		for index in range(enemies._enemies.size()):
			var next: Dictionary = tick["actors"][index]
			enemies._enemies[index]["hp"] = next["hp"]
			enemies._enemies[index]["block"] = next["block"]
			enemies._enemies[index]["statuses"] = next["statuses"]
		var expired: Dictionary = enemies.get_enemy(1)
		_check(not expired.get("statuses", {}).has(FEAR),
			card_id + ": literal Fear expires at that owner turn")
		_check(CombatStatuses.new().can_apply_buff(expired["statuses"])
			== {"ok": true, "allowed": true}, card_id + ": buff allowed after expiry")
		var again := _play(fixture, card_id)
		var rearmed: Dictionary = enemies.get_enemy(1)
		var expected_weak: int = maxi(0, weak - 1) + weak
		_check(again.get("ok", false), card_id + ": a second authentic copy re-arms the flag")
		_check(rearmed.get("statuses") == {WEAK: expected_weak, FEAR: true}
			and rearmed["statuses"][FEAR] is bool and rearmed["statuses"].size() == 2,
			card_id + ": reapplication stacks Weak but keeps one literal Fear")
		_check(CombatStatuses.new().can_apply_buff(rearmed["statuses"])
			== {"ok": true, "allowed": false}, card_id + ": re-armed Fear denies buffs again")
		_check(fixture["deck"].energy == 0 and fixture["deck"].hand.count(card_id) == 0
			and fixture["deck"].discard_pile.count(card_id) == 2,
			card_id + ": two casts paid four energy and discarded two copies")


func _test_seeded_replay() -> void:
	var first := _fixture(PLUS, 3, [18, 22, 16], 1, 333)
	var second := _fixture(PLUS, 3, [18, 22, 16], 1, 333)
	_check(_snapshot(first) == _snapshot(second), "identical pre-play seeded state")
	_check(_play(first, PLUS) == _play(second, PLUS), "identical paid area receipts")
	_check(_snapshot(first) == _snapshot(second), "identical complete post-play replay")
