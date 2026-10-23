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
    _test_patch_ac1_pincushion_arm_damage_bonus()
    _test_patch_ac2_button_eye_exposed_and_latch()
    _test_patch_ac3_wearer_only_and_unbound()
    _test_patch_ac4_rejections_and_overflow()
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

func _patch_fixture(party: CombatParty, wearer: String = "warden",
        sew_arm: bool = false, sew_head: bool = false) -> Dictionary:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/m04_attack_patches.json"))
    _check(raw is Array and raw.size() >= 2, "patch fixture: authentic m04_attack_patches.json parsed")
    var definitions: Array = []
    for entry: Variant in (raw as Array):
        definitions.append({"id": entry["id"], "slot": entry["slot"]})
    var owned: Array = []
    if sew_head:
        owned.append("button_eye")
    if sew_arm:
        owned.append("pincushion_arm")
    var torn := RunTornMending.new(party.get_heroes())
    var wardrobe := RunPatchWardrobe.new(party.get_heroes(), owned, definitions, 3)
    _check(torn.is_valid() and wardrobe.is_valid(), "patch fixture: authentic wardrobe and torn valid")
    if sew_head:
        var res: Dictionary = wardrobe.sew("button_eye", wearer, "HEAD", "sew_head", wardrobe.get_snapshot())
        _check(res.get("ok", false) and wardrobe.get_snapshot()["worn"][wearer]["HEAD"] == "button_eye",
            "patch fixture: button_eye sewn on " + wearer + " HEAD")
    if sew_arm:
        var res: Dictionary = wardrobe.sew("pincushion_arm", wearer, "ARM", "sew_arm", wardrobe.get_snapshot())
        _check(res.get("ok", false) and wardrobe.get_snapshot()["worn"][wearer]["ARM"] == "pincushion_arm",
            "patch fixture: pincushion_arm sewn on " + wearer + " ARM")
    return {"wardrobe": wardrobe, "torn": torn}

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
    var snap: Dictionary = {
        "hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
        "discard": deck.discard_pile.duplicate(), "energy": deck.energy,
        "active": deck.turn_active, "rng": deck._rng.state,
        "heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
        "tokens": tokens, "gauges": gauges
    }
    if f.has("service") and f["service"].get_patches() != null:
        snap["latch"] = f["service"].get_patches().latch_snapshot()
    elif f.has("patches") and f["patches"] != null:
        snap["latch"] = f["patches"].latch_snapshot()
    return snap

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

func _play_with_service(svc: CombatWardenPoolComboAttacks, f: Dictionary, id: String,
        target: int, cost: int, context: String, patches: CombatPatchAttackRules = null) -> Dictionary:
    var deck: CombatDeck = f["deck"]
    var party: CombatParty = f["party"]
    var enemies: CombatEnemies = f["enemies"]
    var pinned: CombatPinned = f["pinned"]
    var unravel: CombatUnravel = f["unravel"]
    f["service"] = svc
    if patches != null:
        f["patches"] = patches
    var before: Dictionary = _snapshot(f)
    _check(svc.can_play(deck, party, enemies, pinned, unravel, id, target, patches), context + ": legal preflight")
    _check(_snapshot(f) == before, context + ": preflight did not mutate state, RNG, or latch")
    var receipt: Dictionary = svc.play_attack(deck, party, enemies, pinned, unravel, id, target, patches)
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

func _reject_with_service(svc: CombatWardenPoolComboAttacks, f: Dictionary, id: String,
        target: int, reason: String, pinned: CombatPinned, unravel: CombatUnravel,
        patches: CombatPatchAttackRules = null) -> void:
    var deck: CombatDeck = f["deck"]
    var party: CombatParty = f["party"]
    var enemies: CombatEnemies = f["enemies"]
    f["service"] = svc
    if patches != null:
        f["patches"] = patches
    var before: Dictionary = _snapshot(f)
    _check(not svc.can_play(deck, party, enemies, pinned, unravel, id, target, patches),
        reason + ": preflight rejected")
    _check(_snapshot(f) == before, reason + ": preflight preserves full state/RNG/latch")
    var receipt: Dictionary = svc.play_attack(deck, party, enemies, pinned, unravel, id, target, patches)
    _check(receipt.get("ok", true) == false and receipt.get("hits", [1]).is_empty(),
        reason + ": failed closed with no hits")
    _check(_snapshot(f) == before, reason + ": rejected transaction preserves all states/RNG/latch")

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

## AC1: Pincushion Arm sewn on living Warden adds +1 base damage to all 4 card variants
## before Weak/Exposed rounding; side effects, costs, positions, discard preserved.
func _test_patch_ac1_pincushion_arm_damage_bonus() -> void:
    # a) warden_pinning_jab (base 4 -> 5)
    var f_jab: Dictionary = _fixture(["warden_pinning_jab"])
    var ctx_jab: Dictionary = _patch_fixture(f_jab["party"], "warden", true, false)
    var svc_jab := CombatWardenPoolComboAttacks.new()
    _check(svc_jab.bind_patch_wardrobe(ctx_jab["wardrobe"], ctx_jab["torn"]), "AC1: jab bound wardrobe")
    _check(svc_jab.get_patches().damage_bonus("warden") == 1, "AC1: warden damage bonus is 1")
    _check((f_jab["enemies"] as CombatEnemies).gain_block(1, 2), "AC1: jab block fixture")
    var jab_res: Dictionary = _play_with_service(svc_jab, f_jab, "warden_pinning_jab", 1, 1, "AC1 Pinning Jab")
    var jab_hit: Dictionary = _hit(jab_res, "AC1 Pinning Jab")
    _check(jab_hit.get("damage") == 5 and jab_hit.get("block_absorbed") == 2 and jab_hit.get("hp_loss") == 3,
        "AC1: Pinning Jab base 4 + 1 patch = 5 damage (2 block absorbed, 3 HP loss)")
    _check(f_jab["enemies"].get_enemy(1)["hp"] == 97 and f_jab["enemies"].get_enemy(1)["block"] == 0,
        "AC1: enemy 1 HP 97, block 0")
    _check(jab_hit.get("pin_applied") == true and f_jab["pinned"].pinner_for_enemy(1) == "warden",
        "AC1: Pinning Jab applied pin")

    # b) warden_pinning_jab_plus (base 6 -> 7)
    var f_jab_p: Dictionary = _fixture(["warden_pinning_jab_plus"])
    var ctx_jab_p: Dictionary = _patch_fixture(f_jab_p["party"], "warden", true, false)
    var svc_jab_p := CombatWardenPoolComboAttacks.new()
    _check(svc_jab_p.bind_patch_wardrobe(ctx_jab_p["wardrobe"], ctx_jab_p["torn"]), "AC1: jab+ bound wardrobe")
    _check((f_jab_p["enemies"] as CombatEnemies).gain_block(1, 2), "AC1: jab+ block fixture")
    var jab_p_res: Dictionary = _play_with_service(svc_jab_p, f_jab_p, "warden_pinning_jab_plus", 1, 1, "AC1 Pinning Jab+")
    var jab_p_hit: Dictionary = _hit(jab_p_res, "AC1 Pinning Jab+")
    _check(jab_p_hit.get("damage") == 7 and jab_p_hit.get("block_absorbed") == 2 and jab_p_hit.get("hp_loss") == 5,
        "AC1: Pinning Jab+ base 6 + 1 patch = 7 damage (2 block absorbed, 5 HP loss)")
    _check(f_jab_p["enemies"].get_enemy(1)["hp"] == 95 and f_jab_p["enemies"].get_enemy(1)["block"] == 0,
        "AC1: enemy 1 HP 95, block 0")

    # c) warden_seam_breaker (base 7 -> 8)
    var f_brk: Dictionary = _fixture(["warden_seam_breaker"])
    var ctx_brk: Dictionary = _patch_fixture(f_brk["party"], "warden", true, false)
    var svc_brk := CombatWardenPoolComboAttacks.new()
    _check(svc_brk.bind_patch_wardrobe(ctx_brk["wardrobe"], ctx_brk["torn"]), "AC1: breaker bound wardrobe")
    _check((f_brk["enemies"] as CombatEnemies).gain_block(2, 3), "AC1: breaker block fixture")
    var brk_res: Dictionary = _play_with_service(svc_brk, f_brk, "warden_seam_breaker", 2, 2, "AC1 Seam Breaker")
    var brk_hit: Dictionary = _hit(brk_res, "AC1 Seam Breaker")
    _check(brk_hit.get("damage") == 8 and brk_hit.get("block_absorbed") == 3 and brk_hit.get("hp_loss") == 5,
        "AC1: Seam Breaker base 7 + 1 patch = 8 damage (3 block absorbed, 5 HP loss)")
    _check(f_brk["enemies"].get_enemy(2)["hp"] == 95 and f_brk["enemies"].get_enemy(2)["block"] == 0,
        "AC1: enemy 2 HP 95, block 0")
    _check(brk_hit.get("unravel_added") == 4 and (f_brk["unravel"] as CombatUnravel).get_snapshot(2)["gauge"] == 4,
        "AC1: Seam Breaker added 4 unravel")

    # d) warden_seam_breaker_plus (base 10 -> 11)
    var f_brk_p: Dictionary = _fixture(["warden_seam_breaker_plus"])
    var ctx_brk_p: Dictionary = _patch_fixture(f_brk_p["party"], "warden", true, false)
    var svc_brk_p := CombatWardenPoolComboAttacks.new()
    _check(svc_brk_p.bind_patch_wardrobe(ctx_brk_p["wardrobe"], ctx_brk_p["torn"]), "AC1: breaker+ bound wardrobe")
    _check((f_brk_p["enemies"] as CombatEnemies).gain_block(2, 3), "AC1: breaker+ block fixture")
    var brk_p_res: Dictionary = _play_with_service(svc_brk_p, f_brk_p, "warden_seam_breaker_plus", 2, 2, "AC1 Seam Breaker+")
    var brk_p_hit: Dictionary = _hit(brk_p_res, "AC1 Seam Breaker+")
    _check(brk_p_hit.get("damage") == 11 and brk_p_hit.get("block_absorbed") == 3 and brk_p_hit.get("hp_loss") == 8,
        "AC1: Seam Breaker+ base 10 + 1 patch = 11 damage (3 block absorbed, 8 HP loss)")
    _check(f_brk_p["enemies"].get_enemy(2)["hp"] == 92 and f_brk_p["enemies"].get_enemy(2)["block"] == 0,
        "AC1: enemy 2 HP 92, block 0")
    _check(brk_p_hit.get("unravel_added") == 6 and (f_brk_p["unravel"] as CombatUnravel).get_snapshot(2)["gauge"] == 6,
        "AC1: Seam Breaker+ added 6 unravel")

    # e) Combined foreign Pinned (+5) plus Weak/Exposed case:
    # Pinning Jab: base 4 + 5 (pinned) + 1 (patch) = 10. Weak (0.75) and Exposed (1.5) -> floor(10 * 9 / 8) = 11.
    var f_combo: Dictionary = _fixture(["warden_pinning_jab", "warden_seam_breaker"])
    var party_c: CombatParty = f_combo["party"]
    var enemies_c: CombatEnemies = f_combo["enemies"]
    var pinned_c: CombatPinned = f_combo["pinned"]
    party_c._heroes[0]["statuses"] = {"weak": 1}
    enemies_c._enemies[0]["statuses"] = {"exposed": 1}
    _check(enemies_c.gain_block(1, 3) and pinned_c.pin_enemy(enemies_c, 1, "seamstress"),
        "AC1: block and foreign pin fixture")
    var ctx_c: Dictionary = _patch_fixture(party_c, "warden", true, false)
    var svc_c := CombatWardenPoolComboAttacks.new()
    _check(svc_c.bind_patch_wardrobe(ctx_c["wardrobe"], ctx_c["torn"]), "AC1: combo bound wardrobe")
    var c_res1: Dictionary = _play_with_service(svc_c, f_combo, "warden_pinning_jab", 1, 1, "AC1 combined Jab")
    var c_hit1: Dictionary = _hit(c_res1, "AC1 combined Jab")
    _check(c_hit1.get("pin_bonus") == 5 and c_hit1.get("damage") == 11
        and c_hit1.get("block_absorbed") == 3 and c_hit1.get("hp_loss") == 8,
        "AC1: floor((4+5+1)*9/8)=11, Block 3, HP loss 8")
    _check(c_hit1.get("pin_consumed") == true and c_hit1.get("pin_applied") == true
        and pinned_c.pinner_for_enemy(1) == "warden", "AC1: foreign pin consumed, warden pin applied")
    _check(enemies_c.get_enemy(1)["hp"] == 92, "AC1: enemy 1 HP is 92")

    # Follow-up Seam Breaker with Pincushion Arm, targeting slot 1:
    # Enemy 1 has Exposed 1, Warden has Weak 1, but pin belongs to Warden (pin_bonus = 0):
    # Base damage: 7 (card) + 0 (own pin) + 1 (patch) = 8.
    # Weak + Exposed: floor(8 * 9 / 8) = 9.
    _turn(f_combo)
    var c_res2: Dictionary = _play_with_service(svc_c, f_combo, "warden_seam_breaker", 1, 2, "AC1 follow-up Breaker")
    var c_hit2: Dictionary = _hit(c_res2, "AC1 follow-up Breaker")
    _check(c_hit2.get("pin_bonus") == 0 and c_hit2.get("damage") == 9 and c_hit2.get("hp_loss") == 9,
        "AC1: follow-up floor((7+0+1)*9/8)=9 damage, 9 HP loss")
    _check(enemies_c.get_enemy(1)["hp"] == 83, "AC1: enemy 1 HP is 92 - 9 = 83")

## AC2: Button Eye in HEAD applies Exposed 1 on first confirmed Warden combo attack after damage;
## subsequent combo attacks do not reapply, including when first hit was lethal.
func _test_patch_ac2_button_eye_exposed_and_latch() -> void:
    # 1. Button Eye on Warden: first attack applies Exposed 1 after resolving damage, subsequent does not
    var f1: Dictionary = _fixture(["warden_pinning_jab", "warden_seam_breaker"])
    var ctx1: Dictionary = _patch_fixture(f1["party"], "warden", false, true)
    var svc1 := CombatWardenPoolComboAttacks.new()
    _check(svc1.bind_patch_wardrobe(ctx1["wardrobe"], ctx1["torn"]), "AC2: bound Button Eye")
    _check(svc1.get_patches().exposed_for_first_hit("warden") == {"exposed": 1}, "AC2: first hit exposed active")
    _check(svc1.get_patches().latch_snapshot()["warden"] == false, "AC2: latch not yet consumed")
    _check(f1["enemies"].get_enemy(1).get("statuses", {}).get("exposed", 0) == 0, "AC2: target has 0 exposed before hit")

    var res1: Dictionary = _play_with_service(svc1, f1, "warden_pinning_jab", 1, 1, "AC2 first hit Jab")
    var hit1: Dictionary = _hit(res1, "AC2 first hit Jab")
    _check(hit1.get("damage") == 4, "AC2: first hit deals 4 damage (not boosted by Button Eye Exposed)")
    _check(f1["enemies"].get_enemy(1).get("statuses", {}).get("exposed", 0) == 1,
        "AC2: enemy 1 status counter has exposed 1 after first confirmed hit")
    _check(svc1.get_patches().latch_snapshot()["warden"] == true, "AC2: Button Eye latch consumed")
    _check(svc1.get_patches().exposed_for_first_hit("warden").is_empty(), "AC2: exposed_for_first_hit empty after latch")

    # Second attack in same combat: does not reapply Button Eye
    _turn(f1)
    var res2: Dictionary = _play_with_service(svc1, f1, "warden_seam_breaker", 2, 2, "AC2 second hit Breaker")
    var hit2: Dictionary = _hit(res2, "AC2 second hit Breaker")
    _check(hit2.get("damage") == 7, "AC2: second attack deals exact 7 damage")
    _check(f1["enemies"].get_enemy(2).get("statuses", {}).get("exposed", 0) == 0,
        "AC2: enemy 2 has 0 exposed (Button Eye does not reapply)")
    _check(f1["enemies"].get_enemy(1).get("statuses", {}).get("exposed", 0) == 1,
        "AC2: enemy 1 retains exposed 1")
    _check(svc1.get_patches().latch_snapshot()["warden"] == true, "AC2: latch remains consumed")

    # 2. Confirmed lethal first hit with Button Eye:
    # Target has 3 HP; Pinning Jab deals 4 damage (lethal). Button Eye Exposed 1 is still applied to slain slot.
    var f_lethal: Dictionary = _fixture(["warden_pinning_jab"], 505, 1, "normal", 3)
    var ctx_lethal: Dictionary = _patch_fixture(f_lethal["party"], "warden", false, true)
    var svc_lethal := CombatWardenPoolComboAttacks.new()
    _check(svc_lethal.bind_patch_wardrobe(ctx_lethal["wardrobe"], ctx_lethal["torn"]), "AC2: bound Button Eye lethal")
    var lethal_res: Dictionary = _play_with_service(svc_lethal, f_lethal, "warden_pinning_jab", 1, 1, "AC2 lethal Jab")
    var lethal_hit: Dictionary = _hit(lethal_res, "AC2 lethal Jab")
    _check(lethal_hit.get("damage") == 4 and lethal_hit.get("hp_loss") == 3, "AC2: lethal hit overkill 4, hp_loss 3")
    _check(f_lethal["enemies"].is_slain(1), "AC2: enemy 1 is slain")
    _check(f_lethal["enemies"].get_enemy(1).get("statuses", {}).get("exposed", 0) == 1,
        "AC2: exposed 1 applied to original slain slot")
    _check(svc_lethal.get_patches().latch_snapshot()["warden"] == true,
        "AC2: latch consumed on confirmed lethal first hit")

    # 3. Simultaneous Button Eye (HEAD) and Pincushion Arm (ARM) on Warden:
    var f_both: Dictionary = _fixture(["warden_pinning_jab"])
    var ctx_both: Dictionary = _patch_fixture(f_both["party"], "warden", true, true)
    var svc_both := CombatWardenPoolComboAttacks.new()
    _check(svc_both.bind_patch_wardrobe(ctx_both["wardrobe"], ctx_both["torn"]), "AC2: bound both patches")
    _check(svc_both.get_patches().damage_bonus("warden") == 1, "AC2: both - damage bonus is 1")
    _check(svc_both.get_patches().exposed_for_first_hit("warden") == {"exposed": 1}, "AC2: both - exposed is 1")
    var both_res: Dictionary = _play_with_service(svc_both, f_both, "warden_pinning_jab", 1, 1, "AC2 both patches Jab")
    var both_hit: Dictionary = _hit(both_res, "AC2 both patches Jab")
    _check(both_hit.get("damage") == 5, "AC2: base 4 + 1 pincushion = 5 damage")
    _check(f_both["enemies"].get_enemy(1).get("statuses", {}).get("exposed", 0) == 1,
        "AC2: exposed 1 applied after hit resolves")
    _check(svc_both.get_patches().latch_snapshot()["warden"] == true, "AC2: latch consumed")

## AC3: Wearer-only effects; unbound, other-hero worn, or torn Warden never grants bonuses.
func _test_patch_ac3_wearer_only_and_unbound() -> void:
    # 1. No patch binding (unbound service remains baseline)
    var f_unbound: Dictionary = _fixture(["warden_pinning_jab", "warden_seam_breaker"])
    var svc_unbound := CombatWardenPoolComboAttacks.new()
    _check(svc_unbound.get_patches() == null, "AC3: unbound service has null patches")
    var unb_res: Dictionary = _play_with_service(svc_unbound, f_unbound, "warden_pinning_jab", 1, 1, "AC3 unbound Jab")
    var unb_hit: Dictionary = _hit(unb_res, "AC3 unbound Jab")
    _check(unb_hit.get("damage") == 4, "AC3: unbound Jab deals exact baseline 4 damage")
    _check(f_unbound["enemies"].get_enemy(1).get("statuses", {}).get("exposed", 0) == 0,
        "AC3: unbound Jab applies no exposed")

    # 2. Patches worn by another hero (Seamstress wears Button Eye and Pincushion Arm)
    var f_other: Dictionary = _fixture(["warden_pinning_jab", "warden_seam_breaker"])
    var ctx_other: Dictionary = _patch_fixture(f_other["party"], "seamstress", true, true)
    var svc_other := CombatWardenPoolComboAttacks.new()
    _check(svc_other.bind_patch_wardrobe(ctx_other["wardrobe"], ctx_other["torn"]), "AC3: bound wardrobe worn by Seamstress")
    _check(svc_other.get_patches().damage_bonus("warden") == 0, "AC3: Warden gets 0 damage bonus from Seamstress patch")
    _check(svc_other.get_patches().exposed_for_first_hit("warden").is_empty(),
        "AC3: Warden gets no exposed from Seamstress patch")
    var other_res: Dictionary = _play_with_service(svc_other, f_other, "warden_pinning_jab", 1, 1, "AC3 other wearer Jab")
    var other_hit: Dictionary = _hit(other_res, "AC3 other wearer Jab")
    _check(other_hit.get("damage") == 4, "AC3: exact 4 damage dealt to enemy")
    _check(f_other["enemies"].get_enemy(1).get("statuses", {}).get("exposed", 0) == 0,
        "AC3: no exposed applied from Seamstress patch")
    _check(svc_other.get_patches().latch_snapshot()["seamstress"] == false,
        "AC3: Seamstress Button Eye latch untouched by Warden attack")

    # 3. Patches worn by Tinker: Warden gets nothing
    var f_tinker: Dictionary = _fixture(["warden_seam_breaker"])
    var ctx_tinker: Dictionary = _patch_fixture(f_tinker["party"], "tinker", true, true)
    var svc_tinker := CombatWardenPoolComboAttacks.new()
    _check(svc_tinker.bind_patch_wardrobe(ctx_tinker["wardrobe"], ctx_tinker["torn"]), "AC3: bound wardrobe worn by Tinker")
    _check(svc_tinker.get_patches().damage_bonus("warden") == 0, "AC3: Warden gets 0 damage bonus from Tinker patch")
    _check(svc_tinker.get_patches().exposed_for_first_hit("warden").is_empty(), "AC3: Warden gets no exposed from Tinker patch")
    var tinker_res: Dictionary = _play_with_service(svc_tinker, f_tinker, "warden_seam_breaker", 1, 2, "AC3 Tinker wearer Breaker")
    var tinker_hit: Dictionary = _hit(tinker_res, "AC3 Tinker wearer Breaker")
    _check(tinker_hit.get("damage") == 7, "AC3: exact 7 damage dealt by Warden")
    _check(f_tinker["enemies"].get_enemy(1).get("statuses", {}).get("exposed", 0) == 0, "AC3: no exposed applied from Tinker patch")

    # 4. Warden TORN (0 HP in RunTornMending)
    var f_torn: Dictionary = _fixture(["warden_pinning_jab"])
    var ctx_torn: Dictionary = _patch_fixture(f_torn["party"], "warden", true, true)
    var start_heroes: Array = ctx_torn["torn"].read_state()["heroes"]
    _check(f_torn["party"].apply_damage(1, 999) and f_torn["party"].is_downed(1), "AC3: downed Warden")
    _check(ctx_torn["torn"].observe_battle_end("tear_warden", start_heroes, f_torn["party"].get_heroes()).get("ok", false),
        "AC3: torn ledger observed downed Warden")
    var svc_torn := CombatWardenPoolComboAttacks.new()
    _check(svc_torn.bind_patch_wardrobe(ctx_torn["wardrobe"], ctx_torn["torn"]), "AC3: torn wardrobe bound successfully")
    _check(svc_torn.get_patches().damage_bonus("warden") == 0, "AC3: torn Warden projected damage bonus is 0")
    _check(svc_torn.get_patches().exposed_for_first_hit("warden").is_empty(), "AC3: torn Warden projected exposed is empty")
    _check(not svc_torn.can_play(f_torn["deck"], f_torn["party"], f_torn["enemies"], f_torn["pinned"],
        f_torn["unravel"], "warden_pinning_jab", 1), "AC3: downed Warden cannot play")

## AC4: Forged/unusable binding, illegal/unheld/unaffordable card, wrong position/target,
## or Exposed status overflow rejects cleanly with no state or patch latch mutation.
## Proves a later valid attack can still spend its first-hit bonus after rejection.
func _test_patch_ac4_rejections_and_overflow() -> void:
    # 1. Explicitly failed / forged binding fails closed:
    var party1 := CombatParty.new([{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}])
    var torn1 := RunTornMending.new(party1.get_heroes())
    var svc_bad := CombatWardenPoolComboAttacks.new()
    _check(not svc_bad.bind_patch_wardrobe(null, torn1), "AC4: null wardrobe rejected")
    _check(svc_bad.get_patches() != null and not svc_bad.get_patches().is_valid(), "AC4: bad patches is marked invalid")
    var f_bad: Dictionary = _fixture(["warden_pinning_jab"])
    _reject_with_service(svc_bad, f_bad, "warden_pinning_jab", 1, "AC4 invalid explicit binding",
        f_bad["pinned"], f_bad["unravel"])

    # Forged CombatPatchAttackRules passed directly:
    var forged_patches := CombatPatchAttackRules.new()
    _check(not forged_patches.is_valid(), "AC4: un-bound patch service is invalid")
    var f_forged: Dictionary = _fixture(["warden_pinning_jab"])
    _reject_with_service(service, f_forged, "warden_pinning_jab", 1, "AC4 forged patches argument",
        f_forged["pinned"], f_forged["unravel"], forged_patches)

    # 2. Exposed counter overflow preflight:
    # Target enemy 1 has MAX_INT exposed status. Button Eye Exposed cannot fit.
    var f_over: Dictionary = _fixture(["warden_pinning_jab", "warden_seam_breaker"])
    var ctx_over: Dictionary = _patch_fixture(f_over["party"], "warden", false, true)
    var svc_over := CombatWardenPoolComboAttacks.new()
    _check(svc_over.bind_patch_wardrobe(ctx_over["wardrobe"], ctx_over["torn"]), "AC4: bound Button Eye for overflow check")
    f_over["enemies"]._enemies[0]["statuses"] = {"exposed": CombatEnemies.MAX_INT}
    _reject_with_service(svc_over, f_over, "warden_pinning_jab", 1, "AC4 status overflow target",
        f_over["pinned"], f_over["unravel"])
    _check(svc_over.get_patches().latch_snapshot()["warden"] == false,
        "AC4: latch remains false after overflow rejection")

    # Proves a later valid attack can still spend its first-hit bonus after rejection:
    # Enemy 2 has 0 exposed, targetable by Seam Breaker from position 1:
    var valid_res: Dictionary = _play_with_service(svc_over, f_over, "warden_seam_breaker", 2, 2, "AC4 later valid attack")
    var valid_hit: Dictionary = _hit(valid_res, "AC4 later valid attack")
    _check(valid_hit.get("damage") == 7, "AC4: later valid attack deals 7 damage")
    _check(f_over["enemies"].get_enemy(2).get("statuses", {}).get("exposed", 0) == 1,
        "AC4: enemy 2 received exposed 1 on later valid attack")
    _check(svc_over.get_patches().latch_snapshot()["warden"] == true,
        "AC4: latch now consumed after later valid attack")

    # 3. Table of invalid plays with bound patches:
    var f_neg: Dictionary = _fixture(["warden_pinning_jab", "warden_seam_breaker"])
    var ctx_neg: Dictionary = _patch_fixture(f_neg["party"], "warden", true, true)
    var svc_neg := CombatWardenPoolComboAttacks.new()
    _check(svc_neg.bind_patch_wardrobe(ctx_neg["wardrobe"], ctx_neg["torn"]), "AC4: bound patches for negative table")
    _check((f_neg["pinned"] as CombatPinned).pin_enemy(f_neg["enemies"], 1, "seamstress"), "AC4: seeded pin")

    # Unheld card:
    _reject_with_service(svc_neg, f_neg, "warden_pinning_jab_plus", 1, "AC4 unheld card",
        f_neg["pinned"], f_neg["unravel"])
    _check(svc_neg.get_patches().latch_snapshot()["warden"] == false, "AC4: latch unconsumed on unheld card")

    # Unsupported card ID:
    _reject_with_service(svc_neg, f_neg, "warden_unsupported", 1, "AC4 unsupported card",
        f_neg["pinned"], f_neg["unravel"])
    _check(svc_neg.get_patches().latch_snapshot()["warden"] == false, "AC4: latch unconsumed on unsupported card")

    # Jab wrong target slot:
    _reject_with_service(svc_neg, f_neg, "warden_pinning_jab", 2, "AC4 Jab wrong target slot",
        f_neg["pinned"], f_neg["unravel"])
    _check(svc_neg.get_patches().latch_snapshot()["warden"] == false, "AC4: latch unconsumed on wrong target")

    # Breaker wrong target slot (slot 3):
    _reject_with_service(svc_neg, f_neg, "warden_seam_breaker", 3, "AC4 Breaker wrong target slot",
        f_neg["pinned"], f_neg["unravel"])
    _check(svc_neg.get_patches().latch_snapshot()["warden"] == false, "AC4: latch unconsumed on wrong target")

    # Insufficient energy:
    var f_no_e: Dictionary = _fixture(["warden_seam_breaker"])
    var ctx_no_e: Dictionary = _patch_fixture(f_no_e["party"], "warden", true, true)
    var svc_no_e := CombatWardenPoolComboAttacks.new()
    _check(svc_no_e.bind_patch_wardrobe(ctx_no_e["wardrobe"], ctx_no_e["torn"]), "AC4: bound no_e")
    _check((f_no_e["deck"] as CombatDeck).try_spend_energy(2), "AC4: spend 2 energy down to 1")
    _reject_with_service(svc_no_e, f_no_e, "warden_seam_breaker", 1, "AC4 low energy",
        f_no_e["pinned"], f_no_e["unravel"])
    _check(svc_no_e.get_patches().latch_snapshot()["warden"] == false, "AC4: latch unconsumed on low energy")

    # Inactive turn:
    var f_inact: Dictionary = _fixture(["warden_pinning_jab"])
    var ctx_inact: Dictionary = _patch_fixture(f_inact["party"], "warden", true, true)
    var svc_inact := CombatWardenPoolComboAttacks.new()
    _check(svc_inact.bind_patch_wardrobe(ctx_inact["wardrobe"], ctx_inact["torn"]), "AC4: bound inact")
    (f_inact["deck"] as CombatDeck).combat_state.player_turn_active = false
    _reject_with_service(svc_inact, f_inact, "warden_pinning_jab", 1, "AC4 inactive turn",
        f_inact["pinned"], f_inact["unravel"])
    _check(svc_inact.get_patches().latch_snapshot()["warden"] == false, "AC4: latch unconsumed on inactive turn")

    # Warden in back slot (slot 3) using existing bound service:
    var f_back: Dictionary = _fixture(["warden_pinning_jab"], 88, 3)
    _reject_with_service(svc_neg, f_back, "warden_pinning_jab", 1, "AC4 Warden in back slot",
        f_back["pinned"], f_back["unravel"])
    _check(svc_neg.get_patches().latch_snapshot()["warden"] == false, "AC4: latch unconsumed on wrong from position")

    # Slain target:
    var f_dead: Dictionary = _fixture(["warden_seam_breaker"])
    _check((f_dead["enemies"] as CombatEnemies).apply_damage(1, 100), "AC4: target 1 slain")
    _reject_with_service(svc_neg, f_dead, "warden_seam_breaker", 1, "AC4 slain target",
        f_dead["pinned"], f_dead["unravel"])
    _check(svc_neg.get_patches().latch_snapshot()["warden"] == false, "AC4: latch unconsumed on slain target")
