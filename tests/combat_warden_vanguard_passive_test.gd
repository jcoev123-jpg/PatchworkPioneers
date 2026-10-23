extends SceneTree
## Battle-scoped Vanguard passive: authentic Warden Path receipt and
## authoritative paid, discarded Heavy Thimble / Pin and Pound transactions.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_first_attack_and_second_turn()
	_test_multihit_and_lethal()
	_test_old_pin_first_hit()
	_test_patched_attack_and_stale_turn()
	_test_fail_closed()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("combat_warden_vanguard_passive_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _receipt(path: String = "vanguard") -> Dictionary:
	var chooser := RunWardenPathChoice.new()
	_check(chooser.is_valid(), "real Warden authored Path validates")
	var r := chooser.choose(path)
	_check(r.get("ok", false), "real single-choice %s receipt" % path)
	return r


func _fixture(card_ids: Array[String], hps: Array[int] = [70, 70],
		warden_slot: int = 1) -> Dictionary:
	var heroes: Array = [
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	]
	if warden_slot != 1:
		var warden: Dictionary = heroes.pop_front()
		heroes.insert(warden_slot - 1, warden)
	var party := CombatParty.new(heroes)
	var defs: Array = []
	for i in hps.size():
		defs.append({"id": "foe_%d" % (i + 1), "max_hp": hps[i]})
	var enemies := CombatEnemies.new(defs)
	var chooser := RunWardenPathChoice.new()
	var base_cards: Array[String] = chooser.get_base_deck()
	for card_id in card_ids:
		_check(WardenPoolCards.new().has_card(card_id),
			"held heavy card is in the genuine authored pool: " + card_id)
		base_cards.append(card_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 171006
	var deck := CombatDeck.new(base_cards, rng)
	_check(party.is_valid() and enemies.is_valid(), "real three-hero and enemy authorities")
	_check(deck.start_turn() and deck.hand.size() == CombatDeck.TURN_DRAW,
		"real deck starts with the authored 5-card draw")
	for card_id in card_ids:
		_hold(deck, card_id)
	var pins := CombatPinned.new()
	var attacks := CombatWardenPoolHeavyAttacks.new(pins)
	return {"deck": deck, "party": party, "enemies": enemies, "pins": pins,
		"attacks": attacks, "passive": CombatWardenVanguardPassive.new()}


func _hold(deck: CombatDeck, card_id: String) -> void:
	var attempts := 0
	while not deck.hand.has(card_id) and attempts < 25:
		_check(deck.draw_extra(1) == 1, "real deck draws a requested card")
		attempts += 1
	_check(deck.hand.has(card_id), "genuinely held " + card_id)


func _bind(f: Dictionary, receipt: Dictionary) -> bool:
	var passive: CombatWardenVanguardPassive = f["passive"]
	return passive.bind_battle(receipt, f["deck"], f["party"], f["enemies"],
		f["pins"], f["attacks"])


func _start(f: Dictionary) -> bool:
	var p: CombatWardenVanguardPassive = f["passive"]
	return p.begin_player_turn(f["deck"], f["party"], f["enemies"], f["pins"], f["attacks"])


func _available(f: Dictionary) -> bool:
	var p: CombatWardenVanguardPassive = f["passive"]
	return p.is_available(f["deck"], f["party"], f["enemies"], f["pins"], f["attacks"])


func _quote(f: Dictionary, card_id: String, target: int) -> Dictionary:
	var p: CombatWardenVanguardPassive = f["passive"]
	return p.quote_attack(f["deck"], f["party"], f["enemies"], f["pins"],
		f["attacks"], card_id, target)


func _confirm(f: Dictionary, quote: Dictionary, receipt: Dictionary) -> bool:
	var p: CombatWardenVanguardPassive = f["passive"]
	return p.confirm_attack(f["deck"], f["party"], f["enemies"], f["pins"],
		f["attacks"], quote, receipt)


func _play(f: Dictionary, id: String, target: int) -> Dictionary:
	var attacks: CombatWardenPoolHeavyAttacks = f["attacks"]
	return attacks.play_attack(f["deck"], f["party"], f["enemies"], id, target)


func _snapshot(f: Dictionary) -> Dictionary:
	var deck: CombatDeck = f["deck"]
	var pins: CombatPinned = f["pins"]
	var party: CombatParty = f["party"]
	var enemies: CombatEnemies = f["enemies"]
	return {
		"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "energy": deck.energy,
		"active": deck.turn_active, "rng": deck._rng.state,
		"heroes": party.get_heroes(), "enemies": enemies.get_enemies(),
		"pins": pins._pinner_by_position.duplicate(true),
	}


func _test_first_attack_and_second_turn() -> void:
	var f := _fixture(["warden_heavy_thimble", "warden_pin_and_pound"], [80, 80])
	var p: CombatWardenVanguardPassive = f["passive"]
	var deck: CombatDeck = f["deck"]
	var enemies: CombatEnemies = f["enemies"]
	var pins: CombatPinned = f["pins"]
	_check(_bind(f, _receipt()), "Vanguard binds a genuine receipt and shared authorities")
	_check(_start(f), "genuine turn 1 starts once")
	_check(not _start(f), "second begin cannot rearm an active turn")
	var baseline := _snapshot(f)
	_check(_available(f) and p.current_turn() == 1, "read-only turn-1 entitlement")
	var q := _quote(f, "warden_heavy_thimble", 1)
	_check(q.get("ok", false) and q.get("original_enemy_id") == "foe_1",
		"held authored Heavy Thimble preflight quotes the original enemy")
	_check(_snapshot(f) == baseline, "preflight and projection do not mutate combat or RNG")
	_check(not _confirm(f, q, {"ok": true}), "fake success flag without play is rejected")
	_check(_available(f) and _snapshot(f) == baseline, "fake confirmation does not latch or pin")
	_check(enemies.gain_block(1, 6), "real enemy has 6 Block")
	# The quote preceded that change. Invalidating it protects the committed
	# snapshot; the subsequent fresh quote may be confirmed.
	var r_bad := _play(f, "warden_heavy_thimble", 1)
	_check(r_bad.get("ok", false), "real attack after intervening change resolves")
	var snap_after_bad := _snapshot(f)
	_check(not _confirm(f, q, r_bad), "stale preflight cannot confirm changed target")
	_check(_snapshot(f) == snap_after_bad and _available(f) and pins.pinner_for_enemy(1) == "",
		"stale result cannot mutate or latch")
	# A separate fresh battle exercises successful confirmation on the first
	# attempted commit without carrying this consumed card/target across.
	p.retire_battle()
	f = _fixture(["warden_heavy_thimble", "warden_pin_and_pound"], [80, 80])
	p = f["passive"]
	deck = f["deck"]
	enemies = f["enemies"]
	pins = f["pins"]
	_check(_bind(f, _receipt()) and _start(f), "fresh battle binds clean first-turn entitlement")
	_check(enemies.gain_block(1, 6), "real target Block applies before HP damage")
	q = _quote(f, "warden_heavy_thimble", 1)
	_check(q.get("ok", false), "blocked legal attack still quotes")
	var energy_before := deck.energy
	var discard_before := deck.discard_pile.size()
	var rng_before := deck._rng.state
	var r := _play(f, "warden_heavy_thimble", 1)
	_check(r.get("ok", false) and (r.get("hits", []) as Array).size() == 1,
		"authentic Heavy Thimble resolves a confirmed single hit")
	_check(deck.energy == energy_before - 2 and deck.discard_pile.size() == discard_before + 1
		and not deck.hand.has("warden_heavy_thimble"), "paid 2 energy and discarded once")
	_check(enemies.get_enemy(1)["block"] == 0 and enemies.get_enemy(1)["hp"] == 75
		and (r["hits"][0] as Dictionary).get("block_absorbed") == 6,
		"real Block absorbs 6 then HP loses 5")
	_check(deck._rng.state == rng_before, "confirmation path spends no RNG")
	var forged := r.duplicate(true)
	forged["hits"][0]["damage"] = 99
	var committed := _snapshot(f)
	_check(not _confirm(f, q, forged), "tampered successful receipt rejected")
	_check(_snapshot(f) == committed and _available(f), "bad receipt preserves live post-play state")
	_check(_confirm(f, q, r), "real committed paid/discarded/enemy-changing result confirmed")
	_check(pins.pinner_for_enemy(1) == "warden" and not _available(f),
		"first confirmed attack pins surviving original target and latches")
	_check(pins.bonus_for_attack(enemies, 1, "warden") == 0
		and pins.bonus_for_attack(enemies, 1, "seamstress") == 5
		and pins.bonus_for_attack(enemies, 1, "tinker") == 5,
		"same-owner zero, other heroes +5 before modifiers")
	_check(not _confirm(f, q, r), "repeat confirmation cannot re-pin")
	var defender_before: int = int(enemies.get_enemy(1)["hp"])
	var cross := CombatStatusAttacks.new().resolve_vs_enemy(enemies, 1,
		5 + pins.bonus_for_attack(enemies, 1, "seamstress"), {}, {})
	_check(cross.get("ok", false) and cross.get("damage") == 10
		and enemies.get_enemy(1)["hp"] == defender_before - 10,
		"another hero's confirmed damage cashes in +5 exactly once")
	_check(pins.consume_after_attack(1, "seamstress", true)
		and pins.pinner_for_enemy(1) == ""
		and not pins.consume_after_attack(1, "tinker", true),
		"shared Pinned consumes only the first cross-owner confirmed hit")
	_check(not _quote(f, "warden_pin_and_pound", 2).get("ok", false),
		"same-turn later Warden attack cannot quote another Vanguard pin")
	# Simulate an energy-gain effect solely to allow a second genuine heavy
	# card commit in the same turn: the passive latch must remain spent.
	deck.combat_state.energy = CombatState.TURN_ENERGY
	var second := _play(f, "warden_pin_and_pound", 2)
	_check(second.get("ok", false) and (second["hits"] as Array).size() == 2,
		"second Warden heavy resolves through real service after energy restoration")
	_check(not _confirm(f, q, second) and pins.pinner_for_enemy(2) == "",
		"second real attack does not refresh or move spent entitlement")
	_check(deck.end_turn(), "real first turn ends")
	_check(p.end_player_turn(deck, f["party"], enemies, pins, f["attacks"]),
		"passive observes actual ended deck")
	_check(not _start(f) and not _available(f), "end/hover cannot masquerade as a new turn")
	_check(deck.start_turn(), "real deck begins second turn and refills energy")
	_hold(deck, "warden_heavy_thimble")
	_check(_start(f) and p.current_turn() == 2 and _available(f),
		"real second player turn refreshes once")
	q = _quote(f, "warden_heavy_thimble", 2)
	_check(q.get("ok", false), "next turn quotes first held attack on other legal enemy")
	r = _play(f, "warden_heavy_thimble", 2)
	_check(r.get("ok", false) and _confirm(f, q, r), "real second-turn first attack confirms")
	_check(pins.pinner_for_enemy(2) == "warden" and pins.pinner_for_enemy(1) == ""
		and not _available(f), "new turn pins once on original second target")


func _test_multihit_and_lethal() -> void:
	var f := _fixture(["warden_pin_and_pound"], [40, 25])
	var pins: CombatPinned = f["pins"]
	var enemies: CombatEnemies = f["enemies"]
	_check(_bind(f, _receipt()) and _start(f), "multi-hit battle starts")
	var q := _quote(f, "warden_pin_and_pound", 1)
	_check(q.get("ok", false), "multi-hit card held and eligible")
	var r := _play(f, "warden_pin_and_pound", 1)
	var hits: Array = r.get("hits", [])
	_check(r.get("ok", false) and hits.size() == 2, "authentic Pin and Pound hits twice")
	if hits.size() == 2:
		_check(hits[0]["damage"] == 9 and hits[1]["damage"] == 9
			and hits[1]["pinned_bonus"] == 0, "no new Vanguard token between hits")
	_check(pins.pinner_for_enemy(1) == "" and enemies.get_enemy(1)["hp"] == 22,
		"token absent throughout resolver, foe takes 18")
	_check(_confirm(f, q, r) and pins.pinner_for_enemy(1) == "warden",
		"multi-hit complete before single pin is applied")
	_check(not _available(f), "multi-hit consumes only one attack entitlement")
	var lethal := _fixture(["warden_heavy_thimble"], [5, 60])
	_check(_bind(lethal, _receipt()) and _start(lethal), "lethal battle starts")
	_check((lethal["pins"] as CombatPinned).pin_enemy(lethal["enemies"], 1, "warden"),
		"old same-owner pin exists on foe about to be slain")
	q = _quote(lethal, "warden_heavy_thimble", 1)
	r = _play(lethal, "warden_heavy_thimble", 1)
	_check(r.get("ok", false) and (lethal["enemies"] as CombatEnemies).is_slain(1),
		"first real Heavy Thimble kills its original victim")
	_check(_confirm(lethal, q, r) and not _available(lethal)
		and (lethal["pins"] as CombatPinned).pinner_for_enemy(1) == "",
		"lethal first attack spends turn entitlement and never pins corpse")


func _test_old_pin_first_hit() -> void:
	var f := _fixture(["warden_pin_and_pound"], [55, 55])
	var pins: CombatPinned = f["pins"]
	var enemies: CombatEnemies = f["enemies"]
	_check(pins.pin_enemy(enemies, 1, "tinker"), "existing Tinker pin is genuine")
	_check(_bind(f, _receipt()) and _start(f), "shared pre-existing-pin battle starts")
	var q := _quote(f, "warden_pin_and_pound", 1)
	var r := _play(f, "warden_pin_and_pound", 1)
	var hits: Array = r.get("hits", [])
	_check(r.get("ok", false) and hits.size() == 2, "pre-pinned real multi-hit succeeds")
	if hits.size() == 2:
		_check(hits[0]["damage"] == 14 and hits[0]["pinned_bonus"] == 5
			and hits[1]["damage"] == 9 and hits[1]["pinned_bonus"] == 0,
			"prior cross-owner pin cashes once on first hit, before new pin")
	_check(pins.pinner_for_enemy(1) == "", "real resolver consumed pre-existing token")
	_check(_confirm(f, q, r) and pins.pinner_for_enemy(1) == "warden",
		"Vanguard re-pins only after entire two-hit commit")


func _test_patched_attack_and_stale_turn() -> void:
	# The real heavy resolver's M04 patch rider must be replayed too, including
	# its first-attack Exposed latch; no copied/independent patch authority.
	var f := _fixture(["warden_heavy_thimble"], [70, 70])
	var patch := CombatPatchAttackRules.new()
	patch._valid = true
	patch._active = {"warden": ["pincushion_arm", "button_eye"]}
	patch._consumed = {"warden": false, "seamstress": false, "tinker": false}
	var attacks: CombatWardenPoolHeavyAttacks = f["attacks"]
	attacks.set_patches(patch)
	_check(_bind(f, _receipt()) and _start(f), "battle accepts the real shared M04 patch service")
	var q := _quote(f, "warden_heavy_thimble", 1)
	_check(q.get("ok", false), "patched held attack quotes")
	var r := _play(f, "warden_heavy_thimble", 1)
	_check(r.get("ok", false) and r["hits"][0]["damage"] == 12
		and r["hits"][0]["statuses"] == {"exposed": 1}
		and patch.latch_snapshot().get("warden") == true,
		"real resolver deals 11+1 then adds Exposed and consumes M04 latch")
	var post_attack := _snapshot(f)
	_check(_confirm(f, q, r), "Vanguard replays and confirms real patched transaction")
	_check((f["pins"] as CombatPinned).pinner_for_enemy(1) == "warden"
		and patch.latch_snapshot().get("warden") == true,
		"pin is added after patch resolution without refreshing M04 latch")
	var replacement := CombatPatchAttackRules.new()
	replacement._valid = true
	attacks.set_patches(replacement)
	_check(not _available(f) and not _confirm(f, q, r),
		"replacing bound patch authority cannot authenticate old battle")
	_check(patch.latch_snapshot().get("warden") == true
		and (f["pins"] as CombatPinned).pinner_for_enemy(1) == "warden",
		"foreign patches cannot change original committed tokens/latches")

	var turn_f := _fixture(["warden_heavy_thimble"], [60, 60])
	_check(_bind(turn_f, _receipt()) and _start(turn_f), "stale-turn battle starts")
	var ticket := _quote(turn_f, "warden_heavy_thimble", 1)
	_check(ticket.get("ok", false), "genuine preflight ticket belongs to turn 1")
	var deck: CombatDeck = turn_f["deck"]
	var service: CombatWardenVanguardPassive = turn_f["passive"]
	_check(deck.end_turn() and service.end_player_turn(
		deck, turn_f["party"], turn_f["enemies"], turn_f["pins"], turn_f["attacks"]),
		"first real player turn ended without attack")
	_check(deck.start_turn(), "second player turn starts on same deck")
	_hold(deck, "warden_heavy_thimble")
	_check(_start(turn_f) and service.current_turn() == 2, "second turn uses new identity")
	var unchanged := _snapshot(turn_f)
	_check(not _confirm(turn_f, ticket, {"ok": true}) and _snapshot(turn_f) == unchanged,
		"old turn ticket cannot confirm, mutate pins or spend second-turn latch")
	var new_ticket := _quote(turn_f, "warden_heavy_thimble", 1)
	var new_result := _play(turn_f, "warden_heavy_thimble", 1)
	_check(new_ticket.get("ok", false) and new_result.get("ok", false)
		and _confirm(turn_f, new_ticket, new_result),
		"fresh turn quote may confirm real paid attack after stale rejection")


func _test_fail_closed() -> void:
	var f := _fixture(["warden_heavy_thimble"], [40, 40])
	var p: CombatWardenVanguardPassive = f["passive"]
	var before := _snapshot(f)
	_check(not _bind(f, {}), "absent receipt refuses battle")
	_check(not _bind(f, _receipt("bulwark")), "real Bulwark receipt cannot enable Vanguard")
	var tampered := _receipt()
	tampered["passive"]["once_per_turn"] = false
	_check(not _bind(f, tampered), "tampered authored passive rejected")
	var chooser := RunWardenPathChoice.new()
	_check(chooser.choose("vanguard").get("ok", false), "first authored Path claim accepted")
	_check(not _bind(f, chooser.choose("vanguard")), "replayed/second claim receipt rejected")
	_check(_snapshot(f) == before and not _available(f), "bad binds never touch authorities")
	var genuine := _receipt()
	_check(_bind(f, genuine), "legal receipt still binds after refusals")
	_check(not _bind(f, genuine), "duplicate receipt binding to same battle rejected")
	_check(_start(f), "first genuine turn starts")
	_check(not _quote(f, "warden_pin_and_pound", 1).get("ok", false),
		"unheld Warden heavy card cannot preflight")
	_check(not _quote(f, "seamstress_strike", 1).get("ok", false),
		"non-Warden card cannot preflight")
	_check(not _quote(f, "warden_heavy_thimble", 3).get("ok", false),
		"illegal original target fails closed")
	_check(not _quote(f, "warden_heavy_thimble", 0).get("ok", false),
		"missing target fails closed")
	_check(not _confirm(f, {}, {"ok": true}), "confirmation without preflight refuses")
	var deck: CombatDeck = f["deck"]
	var party: CombatParty = f["party"]
	var enemies: CombatEnemies = f["enemies"]
	var pins: CombatPinned = f["pins"]
	var attacks: CombatWardenPoolHeavyAttacks = f["attacks"]
	var zero_energy := _snapshot(f)
	deck.combat_state.energy = 1
	_check(not _quote(f, "warden_heavy_thimble", 1).get("ok", false),
		"unaffordable genuinely held attack refuses")
	_check(_snapshot(f)["hand"] == zero_energy["hand"] and _available(f),
		"unaffordable quote does not spend card or entitlement")
	deck.combat_state.energy = 3
	_check(party.apply_damage(1, 999), "real Warden can be downed")
	var downed := _snapshot(f)
	_check(not _quote(f, "warden_heavy_thimble", 1).get("ok", false)
		and _snapshot(f) == downed, "downed Warden cannot attack or pin")
	# Separate live authority is used for the remainder; downed hero stays down.
	var live := _fixture(["warden_heavy_thimble"], [50, 50])
	_check(_bind(live, _receipt()) and _start(live), "fresh valid retry battle starts")
	var live_p: CombatWardenVanguardPassive = live["passive"]
	var live_deck: CombatDeck = live["deck"]
	var live_enemies: CombatEnemies = live["enemies"]
	var live_pins: CombatPinned = live["pins"]
	var live_attacks: CombatWardenPoolHeavyAttacks = live["attacks"]
	_check(live_enemies.apply_damage(2, 50), "second enemy killed as setup")
	var unchanged := _snapshot(live)
	_check(not _quote(live, "warden_heavy_thimble", 2).get("ok", false)
		and _snapshot(live) == unchanged, "dead target cannot be quoted/pinned")
	var q := _quote(live, "warden_heavy_thimble", 1)
	_check(q.get("ok", false), "legal quote available after dead/illegal/refused inputs")
	_check(not live_p.confirm_attack(deck, party, enemies, pins, attacks, q, {"ok": true}),
		"foreign authority confirmation is rejected")
	var corrupt := q.duplicate(true)
	corrupt["target_position"] = 2
	_check(not _confirm(live, corrupt, {"ok": true}), "wrong target/ticket rejected")
	_check(_snapshot(live) == unchanged and _available(live),
		"preview, foreign and counterfeit confirmations do not mutate or latch")
	var refusal := _play(live, "warden_pin_and_pound", 1)
	_check(not refusal.get("ok", false), "unheld real resolver rejects without spend")
	_check(not _confirm(live, q, refusal) and _snapshot(live) == unchanged,
		"refused attack cannot become a passive confirmation")
	var success := _play(live, "warden_heavy_thimble", 1)
	_check(success.get("ok", false) and _confirm(live, q, success),
		"legal retry genuinely resolves and pins")
	_check(live_p.is_available(deck, party, enemies, pins, attacks) == false,
		"foreign battle cannot borrow live entitlement")
	_check(not _confirm(live, q, success), "duplicate confirmation never refreshes")
	live_p.retire_battle()
	_check(not _confirm(live, q, success) and not _available(live)
		and live_p.current_turn() == 0, "retired battle invalidates tickets and turns")
	var new_f := _fixture(["warden_heavy_thimble"], [45, 45])
	new_f["passive"] = live_p
	_check(_bind(new_f, _receipt()) and _start(new_f), "new battle owns fresh state")
	_check(not _confirm(new_f, q, success), "old battle's successful ticket cannot cross battle")
	var new_q := _quote(new_f, "warden_heavy_thimble", 1)
	var new_r := _play(new_f, "warden_heavy_thimble", 1)
	_check(new_q.get("ok", false) and new_r.get("ok", false)
		and _confirm(new_f, new_q, new_r), "new battle legitimately confirms its own attack")
