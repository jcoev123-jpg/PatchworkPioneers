extends SceneTree

var failures: Array[String] = []
var checks := 0
var support := CombatStarterSupportPlay.new()


func _initialize() -> void:
	_test_three_real_plays()
	_test_living_roster_and_swaps()
	_test_turn_boundaries_and_rejections()
	_test_seeded_refill_replay()
	_test_stitched_credit_both_owners()
	_test_stitched_downed_and_repeat()
	_test_stitched_rejections_and_reset()
	for failure in failures:
		printerr(failure)
	print("combat_quilt_bonus_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _party() -> CombatParty:
	return CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])


func _deck(cards: Array[String], seed_value: int) -> CombatDeck:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return CombatDeck.new(cards, rng)


func _state(deck: CombatDeck, party: CombatParty) -> Dictionary:
	return {
		"heroes": party.get_heroes(),
		"hand": deck.hand.duplicate(),
		"draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"energy": deck.energy,
		"turn": deck.turn_active,
		"rng": deck._rng.state,
	}


func _blocks(party: CombatParty) -> Dictionary:
	var result := {}
	for hero in party.get_heroes():
		result[hero.id] = hero.block
	return result


func _test_three_real_plays() -> void:
	var cards: Array[String] = ["warden_brace", "seamstress_stitch_up",
		"tinker_tune_up", "warden_strike", "seamstress_prick",
		"tinker_pop_shot", "warden_shield_bash", "tinker_scrap_bomb"]
	var deck: CombatDeck = null
	# A deterministic seeded search selects a genuinely dealt shared hand
	# containing all three authored support cards, without reordering it.
	for seed_value in range(1, 300):
		var candidate := _deck(cards, seed_value)
		if candidate.start_turn() and candidate.hand.has("warden_brace") \
				and candidate.hand.has("seamstress_stitch_up") \
				and candidate.hand.has("tinker_tune_up"):
			deck = candidate
			break
	_check(deck != null, "fixed-seed search dealt the three real cards plus an undrawn pile")
	if deck == null:
		return
	var party := _party()
	var quilt := CombatQuiltBonus.new(party, deck)
	_check(party.is_valid() and deck.turn_active and deck.hand.size() == 5
		and deck.draw_pile.size() == 3 and deck.energy == 3,
		"authoritative party and deck are active with five dealt cards")
	_check(quilt.begin_player_turn(), "first begin accepted after successful deck start")
	_check(quilt.get_patch_progress().patches.keys().size() == 3
		and not quilt.get_patch_progress().awarded, "all three patch slots start unfilled")

	_check(support.play_card(deck, party, "warden_brace"), "legal Warden Brace committed")
	_check(quilt.record_confirmed_play("warden") ==
		{"ok": true, "triggered": false, "drawn": 0}, "first distinct owner does not award")
	var after_warden := _state(deck, party)
	_check(quilt.record_confirmed_play("warden").triggered == false
		and _state(deck, party) == after_warden, "duplicate Warden receipt does nothing")
	_check(_blocks(party) == {"warden": 7, "seamstress": 0, "tinker": 0},
		"no bonus Block after one owner")

	_check(support.play_card(deck, party, "seamstress_stitch_up", 3),
		"legal Stitch Up onto living Tinker committed")
	_check(quilt.record_confirmed_play("seamstress").triggered == false,
		"second distinct living owner does not award")
	_check(_blocks(party) == {"warden": 7, "seamstress": 0, "tinker": 5},
		"only ordinary support card Block after two owners")
	var progress := quilt.get_patch_progress()
	_check(progress.patches.warden.played and progress.patches.seamstress.played
		and not progress.patches.tinker.played and not progress.awarded,
		"ID-keyed progress reflects exactly the confirmed owners")

	_check(support.play_card(deck, party, "tinker_tune_up"),
		"legal zero-cost Tune Up committed and draws its own card")
	var before_bonus := _state(deck, party)
	_check(before_bonus.draw.size() == 2 and before_bonus.hand.size() == 3
		and before_bonus.energy == 1 and before_bonus.discard ==
		["warden_brace", "seamstress_stitch_up", "tinker_tune_up"],
		"Tune Up draws once before Quilt; three real plays discard in order and spend two energy")
	var next_card: String = deck.draw_pile.back()
	var result := quilt.record_confirmed_play("tinker")
	var after_bonus := _state(deck, party)
	_check(result == {"ok": true, "triggered": true, "drawn": 1},
		"third confirmed owner awards exactly one additional shared-deck draw")
	_check(_blocks(party) == {"warden": 10, "seamstress": 3, "tinker": 8},
		"all living heroes gain exactly three stacking Block")
	_check(after_bonus.hand.size() == before_bonus.hand.size() + 1
		and after_bonus.hand.back() == next_card and after_bonus.draw.size() == 1
		and after_bonus.discard == before_bonus.discard
		and after_bonus.energy == before_bonus.energy and after_bonus.rng == before_bonus.rng,
		"Quilt consumes precisely the real next pile card, without energy, discard or RNG drift")
	var awarded_state := _state(deck, party)
	_check(quilt.record_confirmed_play("tinker").triggered == false
		and quilt.record_confirmed_play("warden").triggered == false
		and _state(deck, party) == awarded_state, "post-award duplicates cannot regrant")
	progress = quilt.get_patch_progress()
	_check(progress.awarded and progress.patches.tinker.played
		and progress.patches.warden.color == "#4a5d73"
		and progress.patches.seamstress.color == "#6e4f6b"
		and progress.patches.tinker.color == "#c49a3a",
		"all patches fill with authoritative later-UI felt colors")
	progress.patches.warden.played = false
	progress.patches.warden.color = "changed"
	progress.patches.clear()
	_check(quilt.get_patch_progress().patches.warden.played
		and quilt.get_patch_progress().patches.warden.color == "#4a5d73",
		"mutating detached nested progress never mutates service")


func _test_living_roster_and_swaps() -> void:
	var party := _party()
	var deck := _deck(["warden_backstep", "seamstress_stitch_up", "tinker_tune_up",
		"warden_strike", "tinker_pop_shot"], 83)
	_check(deck.start_turn(), "swap fixture starts real deck turn")
	var quilt := CombatQuiltBonus.new(party, deck)
	_check(quilt.begin_player_turn(), "swap tracker begins")
	var movement: Dictionary = M02PositionCards.new().get_definition("warden_backstep")
	_check(movement.get("id") == "warden_backstep"
		and CombatPositionSwaps.play_move_card(deck, party, "warden_backstep", movement),
		"real authored Warden Backstep swaps the two actor records")
	_check(party.get_hero(1).id == "seamstress" and party.get_hero(2).id == "warden",
		"changed positions retain stable owner IDs")
	_check(party.apply_damage(2, 40) and party.is_downed(2),
		"actual damage downs moved Warden while preserving his occupied slot")
	_check(quilt.record_confirmed_play("warden") == {"ok": false, "triggered": false, "drawn": 0},
		"downed Warden receipt rejected")
	_check(support.play_card(deck, party, "seamstress_stitch_up", 1),
		"Seamstress may legally Stitch from new front position")
	_check(quilt.record_confirmed_play("seamstress").triggered == false,
		"first surviving owner fills only her patch")
	_check(support.play_card(deck, party, "tinker_tune_up"),
		"Tinker real confirmed support play succeeds")
	var award := quilt.record_confirmed_play("tinker")
	_check(award.ok and award.triggered and award.drawn == 1,
		"two surviving ID owners suffice and draw one from actual discard refill")
	_check(_blocks(party) == {"warden": 0, "seamstress": 8, "tinker": 3}
		and party.get_hero(2).hp == 0,
		"moved downed Warden gains no Block; living Seamstress and Tinker gain three")
	var progress := quilt.get_patch_progress()
	_check(not progress.patches.warden.living and not progress.patches.warden.played
		and progress.patches.seamstress.living and progress.patches.seamstress.played
		and progress.patches.tinker.living and progress.patches.tinker.played
		and progress.awarded, "patches remain stable under swap and downed exclusion")

	party = _party()
	deck = _deck(["tinker_tune_up", "warden_brace", "seamstress_stitch_up",
		"warden_strike", "tinker_pop_shot"], 26)
	_check(deck.start_turn() and party.apply_damage(1, 40)
		and party.apply_damage(2, 30), "one living hero fixture downed two with real damage")
	quilt = CombatQuiltBonus.new(party, deck)
	_check(quilt.begin_player_turn() and support.play_card(deck, party, "tinker_tune_up"),
		"single living Tinker completes actual zero-cost support")
	_check(quilt.record_confirmed_play("tinker").triggered
		and _blocks(party) == {"warden": 0, "seamstress": 0, "tinker": 3},
		"one living owner suffices; two downed receive nothing")

	# A formerly played owner that subsequently falls is no longer required.
	party = _party()
	deck = _deck(["warden_brace", "seamstress_stitch_up", "tinker_tune_up",
		"warden_strike", "tinker_pop_shot"], 19)
	_check(deck.start_turn(), "previously played-then-downed fixture starts")
	quilt = CombatQuiltBonus.new(party, deck)
	_check(quilt.begin_player_turn() and support.play_card(deck, party, "warden_brace")
		and quilt.record_confirmed_play("warden").ok,
		"Warden receives a real committed play before taking damage")
	_check(party.apply_damage(1, 47) and party.is_downed(1),
		"actual 47-point hit exhausts Brace Block and downs its owner")
	_check(support.play_card(deck, party, "seamstress_stitch_up", 3)
		and quilt.record_confirmed_play("seamstress").ok
		and support.play_card(deck, party, "tinker_tune_up"),
		"remaining living heroes commit real support cards")
	_check(quilt.record_confirmed_play("tinker").triggered
		and _blocks(party) == {"warden": 0, "seamstress": 3, "tinker": 8},
		"formerly played but downed Warden is excluded from grant")
	progress = quilt.get_patch_progress()
	_check(progress.patches.warden.played and not progress.patches.warden.living,
		"former receipt remains visible but downed owner is not needed")

	party = _party()
	deck = _deck(["tinker_tune_up"], 17)
	_check(deck.start_turn() and quilt != null, "all-downed fixture starts an active hand")
	quilt = CombatQuiltBonus.new(party, deck)
	_check(quilt.begin_player_turn() and party.apply_damage(1, 40)
		and party.apply_damage(2, 30) and party.apply_damage(3, 26)
		and party.is_defeated(), "all three are actually downed")
	var empty_before := _state(deck, party)
	_check(not quilt.record_confirmed_play("tinker").ok
		and not quilt.get_patch_progress().awarded
		and _state(deck, party) == empty_before, "zero living owners never triggers")
	_check(not quilt.get_patch_progress().patches.warden.living
		and not quilt.get_patch_progress().patches.seamstress.living
		and not quilt.get_patch_progress().patches.tinker.living,
		"detached progress reports zero living IDs")


func _test_turn_boundaries_and_rejections() -> void:
	var party := _party()
	var deck := _deck(["warden_brace", "seamstress_stitch_up", "tinker_tune_up",
		"warden_strike", "tinker_pop_shot"], 71)
	var quilt := CombatQuiltBonus.new(party, deck)
	var before := _state(deck, party)
	_check(not quilt.begin_player_turn()
		and not quilt.record_confirmed_play("warden").ok
		and _state(deck, party) == before, "missing active begin and inactive deck reject")
	_check(deck.start_turn() and quilt.begin_player_turn(), "valid deck turn and tracker begin")
	before = _state(deck, party)
	_check(not quilt.begin_player_turn()
		and not quilt.record_confirmed_play("stranger").ok
		and not quilt.record_confirmed_play("").ok
		and _state(deck, party) == before,
		"duplicate begin and foreign/empty IDs cannot change deck, energy, RNG or party")
	var original_progress := quilt.get_patch_progress()
	_check(not support.play_card(deck, party, "seamstress_stitch_up", 0),
		"actual illegal Stitch attempt fails target validation")
	_check(_state(deck, party) == before
		and quilt.get_patch_progress() == original_progress,
		"failed transaction is NOT forwarded; no charge, draw, Block or progress")
	_check(support.play_card(deck, party, "warden_brace")
		and quilt.record_confirmed_play("warden").ok
		and support.play_card(deck, party, "seamstress_stitch_up", 3)
		and quilt.record_confirmed_play("seamstress").ok
		and support.play_card(deck, party, "tinker_tune_up"),
		"three different legal support transactions commit")
	_check(quilt.record_confirmed_play("tinker").triggered, "first turn awards once")
	var awarded := _state(deck, party)
	_check(not quilt.record_confirmed_play("warden").triggered
		and _state(deck, party) == awarded, "additional receipts do not double award")
	_check(deck.end_turn(), "real deck ends first turn")
	quilt.end_player_turn()
	before = _state(deck, party)
	_check(not quilt.record_confirmed_play("warden").ok
		and not quilt.begin_player_turn()
		and _state(deck, party) == before, "inactive boundary prohibits receipt and begin")
	_check(party.start_player_turn() and deck.start_turn() and quilt.begin_player_turn(),
		"actual next player turn resets party Block, deck, energy and Quilt latch")
	var reset := quilt.get_patch_progress()
	_check(not reset.awarded and not reset.patches.warden.played
		and not reset.patches.seamstress.played and not reset.patches.tinker.played,
		"all three indicators and single-award latch reset")
	_check(deck.hand.has("warden_brace") and deck.hand.has("seamstress_stitch_up")
		and deck.hand.has("tinker_tune_up"), "seeded discard refill dealt all five real cards")
	_check(support.play_card(deck, party, "warden_brace")
		and quilt.record_confirmed_play("warden").ok
		and support.play_card(deck, party, "seamstress_stitch_up", 3)
		and quilt.record_confirmed_play("seamstress").ok
		and support.play_card(deck, party, "tinker_tune_up"),
		"new turn commits same three living owner cards again")
	_check(quilt.record_confirmed_play("tinker").triggered
		and _blocks(party) == {"warden": 10, "seamstress": 3, "tinker": 8},
		"new turn awards exactly once again after actual Block reset")
	awarded = _state(deck, party)
	_check(not quilt.record_confirmed_play("tinker").triggered
		and _state(deck, party) == awarded, "new turn also latches against double reward")


func _refill_trace(seed_value: int) -> Array:
	var party := _party()
	var deck := _deck(["warden_brace", "seamstress_stitch_up", "tinker_tune_up",
		"warden_strike", "tinker_pop_shot"], seed_value)
	var quilt := CombatQuiltBonus.new(party, deck)
	_check(deck.start_turn() and quilt.begin_player_turn()
		and deck.hand.size() == 5 and deck.draw_pile.is_empty(),
		"replay starts with all real cards held, forcing seeded discard reshuffle")
	var trace: Array = [_state(deck, party)]
	_check(support.play_card(deck, party, "warden_brace")
		and quilt.record_confirmed_play("warden").ok, "replay Brace committed")
	trace.append([_state(deck, party), quilt.get_patch_progress()])
	_check(support.play_card(deck, party, "seamstress_stitch_up", 3)
		and quilt.record_confirmed_play("seamstress").ok, "replay Stitch committed")
	trace.append([_state(deck, party), quilt.get_patch_progress()])
	var prior_rng: int = deck._rng.state
	_check(support.play_card(deck, party, "tinker_tune_up"),
		"replay Tune Up draws from actual shuffled discard")
	_check(deck._rng.state != prior_rng and deck.draw_pile.size() == 1,
		"real seeded two-card refill changes RNG and leaves the other drawn card")
	trace.append(_state(deck, party))
	_check(quilt.record_confirmed_play("tinker") ==
		{"ok": true, "triggered": true, "drawn": 1},
		"Quilt consumes remaining shuffled discard card")
	trace.append([_state(deck, party), quilt.get_patch_progress()])
	_check(deck.draw_pile.is_empty() and deck.discard_pile == ["tinker_tune_up"],
		"refilled pile empties and Tune remains discarded exactly once")
	_check(quilt.record_confirmed_play("seamstress").triggered == false,
		"stitched-like second confirmed receipt after trigger does not double-award")
	trace.append([_state(deck, party), quilt.get_patch_progress()])
	return trace


func _test_seeded_refill_replay() -> void:
	for seed_value in [11, 97, 4444]:
		var first := _refill_trace(seed_value)
		var second := _refill_trace(seed_value)
		_check(first.size() == 6 and second.size() == 6 and first == second,
			"identical seed and successful receipts replay hand, piles, energy, Block, patch state and RNG")


func _test_stitched_credit_both_owners() -> void:
	var cards: Array[String] = ["warden_brace", "seamstress_stitch_up",
		"tinker_tune_up", "warden_strike", "seamstress_prick",
		"tinker_pop_shot"]
	var deck: CombatDeck = null
	for seed_value in range(1, 300):
		var candidate := _deck(cards, seed_value)
		if candidate.start_turn() and candidate.hand.has("warden_brace"):
			deck = candidate
			break
	_check(deck != null, "stitched basic: seeded hand contains Warden Brace")
	if deck == null:
		return
	var party := _party()
	var quilt := CombatQuiltBonus.new(party, deck)
	_check(quilt.begin_player_turn(), "stitched basic: tracker begins")
	_check(support.play_card(deck, party, "warden_brace"), "stitched basic: real Warden Brace commits")
	_check(quilt.record_confirmed_play("warden") == {"ok": true, "triggered": false, "drawn": 0},
		"stitched basic: Warden receipt fills only his square")
	var before := _state(deck, party)
	_check(_blocks(party) == {"warden": 7, "seamstress": 0, "tinker": 0},
		"stitched basic: only ordinary Warden Block before stitched")
	var next_card: String = deck.draw_pile.back()
	var result := quilt.record_confirmed_stitched_play("seamstress", "tinker")
	var after := _state(deck, party)
	_check(result == {"ok": true, "triggered": true, "drawn": 1},
		"stitched basic: different-owner stitched receipt awards once")
	_check(_blocks(party) == {"warden": 10, "seamstress": 3, "tinker": 3},
		"stitched basic: every living hero gains exactly 3 Block")
	_check(after.hand.size() == before.hand.size() + 1
		and after.hand.back() == next_card
		and after.draw.size() == before.draw.size() - 1
		and after.discard == before.discard
		and after.energy == before.energy
		and after.rng == before.rng,
		"stitched basic: one authentic pile card drawn, no energy/discard/RNG drift")
	var progress := quilt.get_patch_progress()
	_check(progress.awarded
		and progress.patches.warden.played
		and progress.patches.seamstress.played
		and progress.patches.tinker.played,
		"stitched basic: all three owner squares filled")


func _test_stitched_downed_and_repeat() -> void:
	var cards: Array[String] = ["warden_brace", "seamstress_stitch_up", "tinker_tune_up",
		"warden_strike", "seamstress_prick", "tinker_pop_shot"]
	var deck := _deck(cards, 83)
	var party := _party()
	_check(party.apply_damage(1, 40) and party.is_downed(1), "stitched downed: Warden downed")
	_check(deck.start_turn(), "stitched downed: deck starts")
	var quilt := CombatQuiltBonus.new(party, deck)
	_check(quilt.begin_player_turn(), "stitched downed: tracker begins")
	_check(quilt.record_confirmed_play("seamstress") == {"ok": true, "triggered": false, "drawn": 0},
		"stitched downed: Seamstress credited without award")
	var before := _state(deck, party)
	var next_card: String = deck.draw_pile.back()
	var result := quilt.record_confirmed_stitched_play("seamstress", "tinker")
	var after := _state(deck, party)
	_check(result == {"ok": true, "triggered": true, "drawn": 1},
		"stitched downed: living pair completes and awards once")
	_check(_blocks(party) == {"warden": 0, "seamstress": 3, "tinker": 3},
		"stitched downed: only living heroes gain 3 Block")
	_check(after.hand.size() == before.hand.size() + 1
		and after.hand.back() == next_card
		and after.draw.size() == before.draw.size() - 1
		and after.discard == before.discard
		and after.energy == before.energy
		and after.rng == before.rng,
		"stitched downed: one authentic draw and no drift")
	var progress := quilt.get_patch_progress()
	_check(progress.awarded
		and not progress.patches.warden.living and not progress.patches.warden.played
		and progress.patches.seamstress.played and progress.patches.tinker.played,
		"stitched downed: downed Warden excluded; living pair filled")
	var awarded_state := _state(deck, party)
	var repeat := quilt.record_confirmed_stitched_play("seamstress", "tinker")
	_check(repeat == {"ok": true, "triggered": false, "drawn": 0}
		and _state(deck, party) == awarded_state
		and _blocks(party) == {"warden": 0, "seamstress": 3, "tinker": 3},
		"stitched downed: repeated valid pair does not double-award")
	var reordered := quilt.record_confirmed_stitched_play("tinker", "seamstress")
	_check(reordered.triggered == false, "stitched downed: reordered credited pair grants nothing")


func _test_stitched_rejections_and_reset() -> void:
	var party := _party()
	var deck := _deck(["warden_brace", "seamstress_stitch_up", "tinker_tune_up",
		"warden_strike", "tinker_pop_shot"], 71)
	var quilt := CombatQuiltBonus.new(party, deck)
	var before := _state(deck, party)
	var progress_before := quilt.get_patch_progress()
	_check(not quilt.record_confirmed_stitched_play("warden", "seamstress").ok
		and _state(deck, party) == before
		and quilt.get_patch_progress() == progress_before,
		"stitched reject: inactive turn rejects without changes")
	_check(deck.start_turn() and quilt.begin_player_turn(), "stitched reject: turn begins")
	before = _state(deck, party)
	progress_before = quilt.get_patch_progress()
	_check(not quilt.record_confirmed_stitched_play("warden", "warden").ok
		and _state(deck, party) == before
		and quilt.get_patch_progress() == progress_before,
		"stitched reject: duplicate ID rejects")
	_check(not quilt.record_confirmed_stitched_play("warden", "stranger").ok
		and not quilt.record_confirmed_stitched_play("", "tinker").ok
		and _state(deck, party) == before
		and quilt.get_patch_progress() == progress_before,
		"stitched reject: unknown/empty IDs reject")

	var downed_party := _party()
	_check(downed_party.apply_damage(1, 40), "stitched reject: down Warden")
	var downed_deck := _deck(["tinker_tune_up", "warden_strike", "tinker_pop_shot"], 17)
	var downed_quilt := CombatQuiltBonus.new(downed_party, downed_deck)
	_check(downed_deck.start_turn() and downed_quilt.begin_player_turn(),
		"stitched reject: downed fixture turns")
	before = _state(downed_deck, downed_party)
	progress_before = downed_quilt.get_patch_progress()
	_check(not downed_quilt.record_confirmed_stitched_play("warden", "tinker").ok
		and _state(downed_deck, downed_party) == before
		and downed_quilt.get_patch_progress() == progress_before,
		"stitched reject: downed owner rejects without changes")

	var overflow_party := _party()
	var overflow_deck := _deck(["warden_brace", "seamstress_stitch_up", "tinker_tune_up",
		"warden_strike", "tinker_pop_shot"], 19)
	var overflow_quilt := CombatQuiltBonus.new(overflow_party, overflow_deck)
	_check(overflow_deck.start_turn() and overflow_quilt.begin_player_turn(),
		"stitched reject: overflow fixture turns")
	_check(overflow_quilt.record_confirmed_play("tinker").ok,
		"stitched reject: tinker credited before overflow pair")
	_check(overflow_party.gain_block(1, CombatParty.MAX_INT - 2),
		"stitched reject: overflow block seed")
	before = _state(overflow_deck, overflow_party)
	progress_before = overflow_quilt.get_patch_progress()
	_check(not overflow_quilt.record_confirmed_stitched_play("warden", "seamstress").ok
		and _state(overflow_deck, overflow_party) == before
		and overflow_quilt.get_patch_progress() == progress_before
		and not overflow_quilt.get_patch_progress().patches.warden.played
		and not overflow_quilt.get_patch_progress().patches.seamstress.played,
		"stitched reject: failed reward leaves no partial owner progress")

	var reset_party := _party()
	var reset_deck := _deck(["warden_brace", "seamstress_stitch_up", "tinker_tune_up",
		"warden_strike", "seamstress_prick", "tinker_pop_shot"], 26)
	var reset_quilt := CombatQuiltBonus.new(reset_party, reset_deck)
	_check(reset_deck.start_turn() and reset_quilt.begin_player_turn(), "reset fixture starts")
	_check(reset_quilt.record_confirmed_play("warden").ok, "reset: warden credited")
	var reset_result := reset_quilt.record_confirmed_stitched_play("seamstress", "tinker")
	_check(reset_result == {"ok": true, "triggered": true, "drawn": 1}, "reset: stitched awards")
	_check(not reset_quilt.record_confirmed_stitched_play("seamstress", "tinker").triggered,
		"reset: repeat grants nothing")
	_check(reset_deck.end_turn(), "reset: end deck turn")
	reset_quilt.end_player_turn()
	_check(reset_party.start_player_turn() and reset_deck.start_turn() and reset_quilt.begin_player_turn(),
		"reset: new player turn starts")
	var reset_progress := reset_quilt.get_patch_progress()
	_check(not reset_progress.awarded and not reset_progress.patches.warden.played
		and not reset_progress.patches.seamstress.played
		and not reset_progress.patches.tinker.played,
		"reset: award latch and squares reset")
