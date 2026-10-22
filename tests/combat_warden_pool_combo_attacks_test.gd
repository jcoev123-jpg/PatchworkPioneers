extends SceneTree
## Resolver-level D2-1 regression: real deck, party, enemies, Pinned and bound Unravel.
## Every case is independent and seeded; no live-hand wiring is implied.

var failures: Array[String] = []
var checks: int = 0
var service := CombatWardenPoolComboAttacks.new()

func _initialize() -> void:
    _test_pinning_jab()
    _test_warden_swapped_to_middle()
    _test_seam_breaker()
    _test_cross_hero_status_and_replacement()
    _test_same_owner_and_lethal()
    _test_unravel_thresholds()
    _test_fail_closed()
    _test_independent_seed_replay()
    if failures.is_empty():
        print("combat_warden_pool_combo_attacks_test: PASS (", checks, " checks)")
    else:
        for failure: String in failures:
            printerr(failure)
        print("combat_warden_pool_combo_attacks_test: FAIL (", failures.size(), " failures)")
    quit(0 if failures.is_empty() else 1)

func _check(ok: bool, detail: String) -> void:
    checks += 1
    if not ok:
        failures.append(detail)

func _fixture(cards: Array[String], seed_value: int = 129, warden_position: int = 1,
        tier_at_two: String = "normal", enemy_hp: int = 100) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var ids: Array[String] = cards.duplicate()
    while ids.size() < 5:
        ids.append("warden_strike")
    var deck := CombatDeck.new(ids, rng)
    _check(deck.start_turn() and deck.turn_active and deck.energy == 3, "fixture: real turn with 3 energy")
    for card_id: String in cards:
        _check(deck.hand.has(card_id), "fixture: %s physically held" % card_id)
    var heroes: Array = [
        {"id": "warden", "max_hp": 40},
        {"id": "seamstress", "max_hp": 30},
        {"id": "tinker", "max_hp": 26}
    ]
    if warden_position == 2:
        heroes = [heroes[1], heroes[0], heroes[2]]
    elif warden_position == 3:
        heroes = [heroes[1], heroes[2], heroes[0]]
    var party := CombatParty.new(heroes)
    var enemies := CombatEnemies.new([
        {"id": "foe_front", "max_hp": enemy_hp},
        {"id": "foe_middle", "max_hp": enemy_hp},
        {"id": "foe_back", "max_hp": enemy_hp}
    ])
    var pinned := CombatPinned.new()
    var unravel := CombatUnravel.new()
    _check(party.is_valid() and enemies.is_valid(), "fixture: real valid rosters")
    _check(unravel.bind_roster(enemies, {1: "normal", 2: tier_at_two, 3: "normal"}),
        "fixture: actual Unravel service bound to authoritative roster")
    _check(party.get_hero(warden_position)["id"] == "warden", "fixture: Warden occupies required FROM slot")
    return {"deck": deck, "party": party, "enemies": enemies, "pinned": pinned, "unravel": unravel}

func _snapshot(f: Dictionary) -> Dictionary:
    var deck: CombatDeck = f["deck"]
    var party: CombatParty = f["party"]
    var enemies: CombatEnemies = f["enemies"]
    var pinned: CombatPinned = f["pinned"]
    var unravel: CombatUnravel = f["unravel"]
    var tokens: Array[String] = []
    var gauges: Array[Dictionary] = []
    for pos: int in range(1, 4):
        tokens.append(pinned.pinner_for_enemy(pos))
        gauges.append(unravel.get_snapshot(pos))
    return {
        "hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
        "discard": deck.discard_pile.duplicate(), "energy": deck.energy,
        "active": deck.turn_active, "rng": deck._rng.state,
        "heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
        "tokens": tokens, "gauges": gauges
    }

func _hit(receipt: Dictionary, context: String) -> Dictionary:
    var hits: Array = receipt.get("hits", [])
    _check(receipt.get("ok", false) and hits.size() == 1, context + ": one confirmed hit")
    if hits.size() != 1:
        return {}
    return hits[0] as Dictionary

func _play(f: Dictionary, id: String, target: int, cost: int, context: String) -> Dictionary:
    var deck: CombatDeck = f["deck"]
    var party: CombatParty = f["party"]
    var enemies: CombatEnemies = f["enemies"]
    var pinned: CombatPinned = f["pinned"]
    var unravel: CombatUnravel = f["unravel"]
    var before: Dictionary = _snapshot(f)
    _check(service.can_play(deck, party, enemies, pinned, unravel, id, target), context + ": legal preflight")
    _check(_snapshot(f) == before, context + ": preflight did not mutate even RNG")
    var receipt: Dictionary = service.play_attack(deck, party, enemies, pinned, unravel, id, target)
    _check(receipt.get("ok", false), context + ": paid attack succeeded")
    _check(deck.energy == int(before["energy"]) - cost, context + ": exact energy debit")
    var expected_hand: Array = (before["hand"] as Array).duplicate()
    expected_hand.erase(id)
    var expected_discard: Array = (before["discard"] as Array).duplicate()
    expected_discard.append(id)
    _check(deck.hand == expected_hand and deck.discard_pile == expected_discard,
        context + ": exactly one matching held copy discarded")
    _check(deck.draw_pile == before["draw"] and deck._rng.state == before["rng"],
        context + ": no draw or run RNG mutation on attack")
    _check(party.get_heroes() == before["heroes"], context + ": hero HP/Block untouched")
    return receipt

func _turn(f: Dictionary) -> void:
    var deck: CombatDeck = f["deck"]
    _check(deck.end_turn() and deck.start_turn(), "turn: real deck end/start boundary")
    _check(deck.turn_active and deck.energy == 3, "turn: energy reset to 3")

func _test_pinning_jab() -> void:
    for id: String in ["warden_pinning_jab", "warden_pinning_jab_plus"]:
        var expected_damage: int = 6 if id.ends_with("_plus") else 4
        var f: Dictionary = _fixture([id])
        var enemies: CombatEnemies = f["enemies"]
        var pinned: CombatPinned = f["pinned"]
        _check(enemies.gain_block(1, 2), id + ": block fixture")
        var other_before: Dictionary = enemies.get_enemy(2)
        var result: Dictionary = _play(f, id, 1, 1, id)
        var hit: Dictionary = _hit(result, id)
        _check(hit.get("damage") == expected_damage and hit.get("block_absorbed") == 2
            and hit.get("hp_loss") == expected_damage - 2, id + ": catalog damage and Block->HP")
        _check(enemies.get_enemy(1)["hp"] == 100 - (expected_damage - 2)
            and enemies.get_enemy(1)["block"] == 0, id + ": authoritative HP and Block")
        _check(enemies.get_enemy(2) == other_before, id + ": other original enemy slot untouched")
        _check(hit.get("pin_applied") == true and hit.get("pin_bonus") == 0
            and hit.get("pin_consumed") == false
            and pinned.pinner_for_enemy(1) == "warden", id + ": new Warden Pinned token")
        _check((f["unravel"] as CombatUnravel).get_snapshot(1)["gauge"] == 0,
            id + ": Pinning Jab does not charge Unravel")

func _test_warden_swapped_to_middle() -> void:
    var f: Dictionary = _fixture(["test_adjacent_move", "warden_pinning_jab_plus", "warden_seam_breaker"])
    var deck: CombatDeck = f["deck"]
    var party: CombatParty = f["party"]
    var enemies: CombatEnemies = f["enemies"]
    var move_definition: Dictionary = {
        "id": "test_adjacent_move", "owner": "warden", "cost": 0,
        "action_kind": "adjacent_swap", "direction": 1, "from_positions": [1]
    }
    _check(CombatPositionSwaps.play_move_card(deck, party, "test_adjacent_move", move_definition),
        "swap: actual CombatPositionSwaps move succeeds")
    _check(party.get_hero(1)["id"] == "seamstress"
        and party.get_hero(2)["id"] == "warden", "swap: Warden now authoritative middle hero")
    var jab: Dictionary = _play(f, "warden_pinning_jab_plus", 1, 1, "middle Warden Jab+")
    _check(_hit(jab, "middle Warden Jab+").get("damage") == 6,
        "swap: upgraded Jab still deals 6 from middle")
    _check((f["pinned"] as CombatPinned).pinner_for_enemy(1) == "warden",
        "swap: pin belongs to moved Warden")
    _turn(f)
    var breaker: Dictionary = _play(f, "warden_seam_breaker", 2, 2, "middle Warden Breaker")
    _check(_hit(breaker, "middle Warden Breaker").get("damage") == 7,
        "swap: Seam Breaker hits original enemy slot 2 from middle")
    _check(enemies.get_enemy(2)["hp"] == 93 and enemies.get_enemy(1)["hp"] == 94,
        "swap: both original enemy positions retained")

func _test_seam_breaker() -> void:
    for id: String in ["warden_seam_breaker", "warden_seam_breaker_plus"]:
        var damage: int = 10 if id.ends_with("_plus") else 7
        var amount: int = 6 if id.ends_with("_plus") else 4
        var f: Dictionary = _fixture([id])
        var enemies: CombatEnemies = f["enemies"]
        _check(enemies.gain_block(2, 3), id + ": Block at second original enemy slot")
        var result: Dictionary = _play(f, id, 2, 2, id)
        var hit: Dictionary = _hit(result, id)
        _check(hit.get("position") == 2 and hit.get("damage") == damage
            and hit.get("block_absorbed") == 3 and hit.get("hp_loss") == damage - 3,
            id + ": correct target, damage and block/HP receipt")
        _check(enemies.get_enemy(2)["hp"] == 100 - damage + 3
            and enemies.get_enemy(2)["block"] == 0 and enemies.get_enemy(1)["hp"] == 100,
            id + ": original slot 2 damaged, slot 1 unchanged")
        var gauge: Dictionary = (f["unravel"] as CombatUnravel).get_snapshot(2)
        _check(hit.get("unravel_added") == amount and gauge["gauge"] == amount
            and gauge["threshold"] == 8 and not gauge["skip_pending"],
            id + ": bound gauge received exactly authored charge")
        _check((f["pinned"] as CombatPinned).pinner_for_enemy(2).is_empty(),
            id + ": Breaker never creates a Pinned token")

func _test_cross_hero_status_and_replacement() -> void:
    var f: Dictionary = _fixture(["warden_pinning_jab", "warden_pinning_jab_plus"])
    var party: CombatParty = f["party"]
    var enemies: CombatEnemies = f["enemies"]
    var pinned: CombatPinned = f["pinned"]
    party._heroes[0]["statuses"] = {"weak": 1}
    enemies._enemies[0]["statuses"] = {"exposed": 1}
    _check(enemies.gain_block(1, 3) and pinned.pin_enemy(enemies, 1, "seamstress"),
        "cross: Block and foreign Pinned seeded on real services")
    var first: Dictionary = _play(f, "warden_pinning_jab", 1, 1, "cross-owner Jab")
    var hit: Dictionary = _hit(first, "cross-owner Jab")
    _check(hit.get("pin_bonus") == 5 and hit.get("damage") == 10
        and hit.get("block_absorbed") == 3 and hit.get("hp_loss") == 7,
        "cross: floor((4+5)*0.75*1.5)=10, Block 3, HP loss 7")
    _check(hit.get("pin_consumed") == true and hit.get("pin_applied") == true
        and pinned.pinner_for_enemy(1) == "warden",
        "cross: foreign pin consumed once, then replaced by Warden")
    var second: Dictionary = _play(f, "warden_pinning_jab_plus", 1, 1, "Warden follow-up")
    var follow: Dictionary = _hit(second, "Warden follow-up")
    _check(follow.get("pin_bonus") == 0 and follow.get("pin_consumed") == false
        and follow.get("pin_applied") == true and follow.get("damage") == 6,
        "cross: own token grants no second bonus or consumption; statuses still apply")
    _check(pinned.pinner_for_enemy(1) == "warden" and enemies.get_enemy(1)["hp"] == 87,
        "cross: Warden token persists, both hits applied to authoritative HP")

func _test_same_owner_and_lethal() -> void:
    var f: Dictionary = _fixture(["warden_seam_breaker"])
    var enemies: CombatEnemies = f["enemies"]
    var pinned: CombatPinned = f["pinned"]
    _check(pinned.pin_enemy(enemies, 1, "warden"), "same-owner: Warden pin set")
    var r: Dictionary = _play(f, "warden_seam_breaker", 1, 2, "same-owner Breaker")
    var h: Dictionary = _hit(r, "same-owner Breaker")
    _check(h.get("damage") == 7 and h.get("pin_bonus") == 0
        and h.get("pin_consumed") == false and pinned.pinner_for_enemy(1) == "warden",
        "same-owner: no bonus or token consumption")
    _check((f["unravel"] as CombatUnravel).get_snapshot(1)["gauge"] == 4,
        "same-owner: Breaker still adds Unravel")
    var lethal: Dictionary = _fixture(["warden_pinning_jab"], 7, 1, "normal", 5)
    var lethal_enemies: CombatEnemies = lethal["enemies"]
    var lethal_pin: CombatPinned = lethal["pinned"]
    _check(lethal_pin.pin_enemy(lethal_enemies, 1, "tinker"), "lethal: foreign token set")
    var death: Dictionary = _play(lethal, "warden_pinning_jab", 1, 1, "lethal cross-owner Jab")
    var death_hit: Dictionary = _hit(death, "lethal cross-owner Jab")
    _check(death_hit.get("pin_bonus") == 5 and death_hit.get("pin_consumed") == true
        and death_hit.get("pin_applied") == false and death_hit.get("hp_loss") == 5,
        "lethal: confirmed overkill consumes foreign pin, adds none")
    _check(lethal_enemies.is_slain(1) and lethal_pin.pinner_for_enemy(1).is_empty(),
        "lethal: original target dead and token cleared")
    _check((lethal["unravel"] as CombatUnravel).get_snapshot(1)["gauge"] == 0,
        "lethal: no postmortem gauge mutation")
    var lethal_breaker: Dictionary = _fixture(["warden_seam_breaker_plus"], 8, 1, "normal", 5)
    var breaker_death: Dictionary = _play(lethal_breaker, "warden_seam_breaker_plus", 1, 2, "lethal Breaker+")
    _check(_hit(breaker_death, "lethal Breaker+").get("hp_loss") == 5,
        "lethal Breaker+: HP clamps to remaining five")
    _check((lethal_breaker["unravel"] as CombatUnravel).get_snapshot(1)["gauge"] == 0
        and (lethal_breaker["enemies"] as CombatEnemies).is_slain(1),
        "lethal Breaker+: no charge on slain target")

func _threshold_case(tier: String, ids: Array[String], expected: Array[int], target: int,
        threshold: int) -> void:
    var f: Dictionary = _fixture(ids, 300 + threshold, 1, tier)
    var unravel: CombatUnravel = f["unravel"]
    var enemies: CombatEnemies = f["enemies"]
    var running: int = 0
    for i: int in range(ids.size()):
        if i > 0:
            _turn(f)
        var receipt: Dictionary = _play(f, ids[i], target, 2, tier + " charge " + str(i))
        var hit: Dictionary = _hit(receipt, tier + " charge " + str(i))
        running += expected[i]
        var snapshot: Dictionary = unravel.get_snapshot(target)
        _check(hit.get("unravel_added") == expected[i], tier + ": authored charge on receipt")
        _check(snapshot["gauge"] == mini(running, threshold)
            and snapshot["threshold"] == threshold
            and snapshot["skip_pending"] == (running >= threshold)
            and snapshot["unravelled"] == (running >= threshold),
            tier + ": gauge and exactly one pending skip at charge " + str(i))
    _check(not unravel.consume_action_skip(enemies, 3), tier + ": no skip in untouched original slot")
    _turn(f)
    var repeat: Dictionary = _play(f, ids[0], target, 2, tier + " capped charge")
    _check(_hit(repeat, tier + " capped charge").get("unravel_added") == expected[0],
        tier + ": another successful attack while skipped")
    _check(unravel.get_snapshot(target)["gauge"] == threshold
        and unravel.get_snapshot(target)["skip_pending"], tier + ": still one skip, gauge capped")
    _check(unravel.consume_action_skip(enemies, target), tier + ": real skip consumed exactly once")
    var after: Dictionary = unravel.get_snapshot(target)
    _check(after["gauge"] == 0 and after["threshold"] == threshold + 4
        and not after["unravelled"] and not after["skip_pending"],
        tier + ": skip resets gauge and raises threshold by four")
    _check(not unravel.consume_action_skip(enemies, target), tier + ": cannot consume same skip twice")
    _turn(f)
    _play(f, ids[0], target, 2, tier + " post-skip charge")
    _check(unravel.get_snapshot(target)["gauge"] == expected[0]
        and unravel.get_snapshot(target)["threshold"] == threshold + 4,
        tier + ": subsequent hit charges same increased-threshold gauge")

func _test_unravel_thresholds() -> void:
    _threshold_case("normal", ["warden_seam_breaker", "warden_seam_breaker"], [4, 4], 1, 8)
    _threshold_case("elite", ["warden_seam_breaker_plus", "warden_seam_breaker_plus"], [6, 6], 2, 12)
    _threshold_case("boss", ["warden_seam_breaker", "warden_seam_breaker_plus",
        "warden_seam_breaker_plus"], [4, 6, 6], 2, 16)

func _reject(f: Dictionary, id: String, target: int, reason: String,
        pinned: CombatPinned, unravel: CombatUnravel) -> void:
    var deck: CombatDeck = f["deck"]
    var party: CombatParty = f["party"]
    var enemies: CombatEnemies = f["enemies"]
    var before: Dictionary = _snapshot(f)
    _check(not service.can_play(deck, party, enemies, pinned, unravel, id, target),
        reason + ": preflight rejected")
    _check(_snapshot(f) == before, reason + ": preflight preserves full state/RNG")
    var receipt: Dictionary = service.play_attack(deck, party, enemies, pinned, unravel, id, target)
    _check(receipt.get("ok", true) == false and receipt.get("hits", [1]).is_empty(),
        reason + ": failed closed with no hits")
    _check(_snapshot(f) == before, reason + ": rejected transaction preserves all states/RNG")

func _test_fail_closed() -> void:
    var f: Dictionary = _fixture(["warden_pinning_jab"])
    _check((f["pinned"] as CombatPinned).pin_enemy(f["enemies"], 1, "seamstress"),
        "negative: nonempty pin before snapshots")
    _check((f["unravel"] as CombatUnravel).apply_unravel(f["enemies"], 1, 2),
        "negative: charged gauge before snapshots")
    _reject(f, "warden_pinning_jab_plus", 1, "unheld card", f["pinned"], f["unravel"])
    _reject(f, "warden_unsupported", 1, "unsupported ID", f["pinned"], f["unravel"])
    _reject(f, "warden_pinning_jab", 2, "Jab wrong target slot", f["pinned"], f["unravel"])
    _reject(f, "warden_pinning_jab", 0, "invalid target slot", f["pinned"], f["unravel"])
    _reject(f, "warden_pinning_jab", 1, "null pin service", null, f["unravel"])
    _reject(f, "warden_pinning_jab", 1, "null gauge service", f["pinned"], null)
    _reject(f, "warden_pinning_jab", 1, "unbound gauge", f["pinned"], CombatUnravel.new())
    var foreign: CombatUnravel = CombatUnravel.new()
    _check(foreign.bind_roster(CombatEnemies.new([{"id": "other", "max_hp": 15}]), {1: "normal"}),
        "negative: separate roster gauge bound")
    _reject(f, "warden_pinning_jab", 1, "wrong bound roster", f["pinned"], foreign)
    var no_energy: Dictionary = _fixture(["warden_seam_breaker"])
    _check((no_energy["deck"] as CombatDeck).try_spend_energy(2), "negative: spent fixture energy down to 1")
    _reject(no_energy, "warden_seam_breaker", 1, "insufficient energy", no_energy["pinned"], no_energy["unravel"])
    var inactive: Dictionary = _fixture(["warden_pinning_jab"])
    (inactive["deck"] as CombatDeck).combat_state.player_turn_active = false
    _reject(inactive, "warden_pinning_jab", 1, "inactive turn with held card", inactive["pinned"], inactive["unravel"])
    var downed: Dictionary = _fixture(["warden_pinning_jab"])
    _check((downed["party"] as CombatParty).apply_damage(1, 100), "negative: Warden downed")
    _reject(downed, "warden_pinning_jab", 1, "downed Warden", downed["pinned"], downed["unravel"])
    var back: Dictionary = _fixture(["warden_pinning_jab"], 21, 3)
    _reject(back, "warden_pinning_jab", 1, "Warden in forbidden back slot", back["pinned"], back["unravel"])
    var dead: Dictionary = _fixture(["warden_seam_breaker"])
    _check((dead["enemies"] as CombatEnemies).apply_damage(1, 100), "negative: target 1 slain")
    _reject(dead, "warden_seam_breaker", 1, "slain target with living other slots", dead["pinned"], dead["unravel"])
    var wrong_slot: Dictionary = _fixture(["warden_seam_breaker"])
    _reject(wrong_slot, "warden_seam_breaker", 3, "Breaker wrong target slot", wrong_slot["pinned"], wrong_slot["unravel"])
    var invalid_status: Dictionary = _fixture(["warden_pinning_jab"])
    (invalid_status["party"] as CombatParty)._heroes[0]["statuses"] = {"invalid": 1}
    _reject(invalid_status, "warden_pinning_jab", 1, "invalid authoritative owner status",
        invalid_status["pinned"], invalid_status["unravel"])

func _replay_once(seed_value: int) -> Dictionary:
    var f: Dictionary = _fixture(["warden_pinning_jab", "warden_seam_breaker_plus"], seed_value)
    var enemies: CombatEnemies = f["enemies"]
    var pinned: CombatPinned = f["pinned"]
    _check(enemies.gain_block(1, 2) and pinned.pin_enemy(enemies, 1, "tinker"),
        "replay: independent seed setup with Block/Pinned")
    var rng_before: int = (f["deck"] as CombatDeck)._rng.state
    var first: Dictionary = _play(f, "warden_pinning_jab", 1, 1, "seeded first Jab")
    _turn(f)
    var second: Dictionary = _play(f, "warden_seam_breaker_plus", 2, 2, "seeded second Breaker+")
    return {"first": first, "second": second, "final": _snapshot(f), "rng_at_start": rng_before}

func _test_independent_seed_replay() -> void:
    var one: Dictionary = _replay_once(7788)
    var two: Dictionary = _replay_once(7788)
    _check(one == two, "replay: independent same-seed real decks, rosters, receipts, pins, gauges and RNG identical")
    _check(one["rng_at_start"] == two["rng_at_start"], "replay: injected run RNG state was independently seeded")
