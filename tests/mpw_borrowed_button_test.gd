extends SceneTree
## Deterministic MPW P6 Borrowed Button contract.
##
## The COAT record is checked in its own M05 catalog while the pre-existing M04
## coats are checked by ID, never by catalog size or position. Every HP change the
## helper observes comes from the real CombatSeamstressPoolHeals transaction on a
## real CombatDeck over the authored starter party; only then is a post-commit
## receipt reported. Live battle/app hooks are owned by other lanes and are not
## claimed here: this test drives the scene-free interface those hooks will call,
## including explicit per-half stitched owners.

const M04_COATS := "res://data/patches/m04_coat_patches.json"
const M05_COATS := "res://data/patches/m05_coat_patches.json"
const STARTER_PARTY := "res://data/heroes/starter_party.json"
const TEA := "seamstress_thimble_tea"
const DARNING := "seamstress_darning"

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_authored_catalog()
	_test_award_once_per_combat()
	_test_new_combat_rearms()
	_test_negative_transitions()
	_test_failed_cast_never_notifies()
	_test_downed_and_torn_wearer()
	_test_torn_healer_still_refused()
	_test_stitched_half_owners()
	_test_real_stitched_commits_share_latch()
	_test_real_stitched_resewn_wearer()
	for failure: String in failures:
		printerr(failure)
	print("mpw_borrowed_button_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _json(path: String) -> Variant:
	var source := FileAccess.get_file_as_string(path)
	_check(not source.is_empty(), path + ": readable")
	return JSON.parse_string(source)


func _records_by_id(path: String) -> Dictionary:
	var parsed: Variant = _json(path)
	var by_id := {}
	if typeof(parsed) != TYPE_ARRAY:
		_check(false, path + ": is an array of records")
		return by_id
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id: Variant = entry.get("id")
		if typeof(id) != TYPE_STRING:
			continue
		_check(not by_id.has(id), path + ": unique record id " + id)
		by_id[id] = entry
	return by_id


func _integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and value == floor(value)


## AC1: the named M05 COAT record and the untouched pre-existing M04 coats.
func _test_authored_catalog() -> void:
	var m05: Variant = _json(M05_COATS)
	_check(m05 is Array, "the M05 COAT catalog is an authored array")
	var copies := 0
	if m05 is Array:
		for entry in m05:
			if entry is Dictionary and entry.get("id") == "borrowed_button":
				copies += 1
	_check(copies == 1, "exactly one borrowed_button record is authored")
	var record: Variant = _records_by_id(M05_COATS).get("borrowed_button", null)
	_check(record is Dictionary, "borrowed_button is present by ID in the M05 COAT catalog")
	if record is Dictionary:
		_check(record.get("id") == "borrowed_button",
			"borrowed_button record keeps its authored ID")
		_check(record.get("slot") == "COAT",
			"borrowed_button is a COAT patch")
		_check(record.get("effect") == "other_hero_committed_heal_block",
			"borrowed_button uses the other-owner committed-heal effect")
		_check(_integral(record.get("heal_threshold")) and record.get("heal_threshold") == 1,
			"borrowed_button requires at least 1 HP actually restored")
		_check(_integral(record.get("block")) and record.get("block") == 3,
			"borrowed_button grants exactly 3 Block")
		_check(_integral(record.get("uses_per_combat")) and record.get("uses_per_combat") == 1,
			"borrowed_button is limited to one use per combat")

	var m04 := _records_by_id(M04_COATS)
	var expected := {"quilted_coat": 6, "padded_vest": 4, "double_quilt_coat": 8}
	for id: String in expected:
		var coat: Variant = m04.get(id, null)
		_check(coat is Dictionary and coat.get("slot") == "COAT"
			and _integral(coat.get("max_hp_bonus"))
			and int(coat.get("max_hp_bonus")) == expected[id],
			"pre-existing M04 coat " + id + " still grants exactly +"
			+ str(expected[id]) + " maximum HP in COAT")
	_check(not m04.has("borrowed_button"),
		"borrowed_button is not appended to the separate M04 COAT catalog")


func _party() -> CombatParty:
	var authored: Variant = _json(STARTER_PARTY)
	_check(authored is Array and (authored as Array).size() == CombatParty.PARTY_SIZE,
		"authored starter party has three heroes")
	if not authored is Array:
		return CombatParty.new([])
	var definitions: Array = []
	for entry in authored:
		var hero: Dictionary = (entry as Dictionary).duplicate(true)
		hero["max_hp"] = int(hero["max_hp"])
		definitions.append(hero)
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "authored starter party builds a valid CombatParty")
	_check(party.get_hero(1)["id"] == "warden" and party.get_hero(1)["hp"] == 40
		and party.get_hero(2)["id"] == "seamstress" and party.get_hero(2)["hp"] == 30
		and party.get_hero(3)["id"] == "tinker" and party.get_hero(3)["hp"] == 26,
		"authored Warden 40 front, Seamstress 30 middle and Tinker 26 back")
	return party


## Genuine starter roster, both real COAT catalogs as authored definitions and one
## real sewing operation. `sew` is optional so the unsewn cases stay genuine too.
func _fixture(wearer: String = "warden", sew: bool = true,
		sew_id: String = "borrowed_button",
		owned: Array = ["borrowed_button"]) -> Dictionary:
	var party := _party()
	if not party.is_valid():
		return {}
	var heroes: Array = party.get_heroes()
	var definitions: Array = []
	for path in [M04_COATS, M05_COATS]:
		var by_id := _records_by_id(path)
		for id in by_id:
			definitions.append({"id": id, "slot": by_id[id]["slot"]})
	var wardrobe := RunPatchWardrobe.new(heroes, owned, definitions, 3, 17,
		["seamstress_thimble_tea"], 4242)
	var torn := RunTornMending.new(heroes)
	_check(wardrobe.is_valid() and torn.is_valid(),
		"real RunPatchWardrobe and RunTornMending are valid")
	if not wardrobe.is_valid() or not torn.is_valid():
		return {}
	if sew:
		var sewn: Dictionary = wardrobe.sew(sew_id, wearer, "COAT",
			"sew_" + sew_id + "_" + wearer, wardrobe.get_snapshot())
		_check(sewn.get("ok") == true
			and wardrobe.get_snapshot()["worn"][wearer]["COAT"] == sew_id,
			"genuine COAT sew of " + sew_id + " onto " + wearer)
	return {"party": party, "wardrobe": wardrobe, "torn": torn}


func _bind(fixture: Dictionary) -> CombatBorrowedButton:
	var helper := CombatBorrowedButton.new()
	_check(not fixture.is_empty(), "fixture authorities exist before binding")
	if fixture.is_empty():
		return helper
	_check(helper.bind_combat(fixture.party, fixture.wardrobe, fixture.torn),
		"helper binds the real party, wardrobe and torn ledger")
	var state: Dictionary = helper.read_state()
	_check(state.get("ok") == true and state.get("awarded") == false
		and state.get("awards") == 0 and state.get("block_awarded") == 0
		and state.get("patch_id") == "borrowed_button",
		"fresh combat instance is bound, unawarded and knows its patch")
	return helper


func _deck(cards: Array[String], seed_value: int = 42, start: bool = true) -> CombatDeck:
	var deck := CombatDeck.new(cards, _rng(seed_value))
	if start:
		_check(deck.start_turn() and deck.turn_active
			and deck.energy == CombatState.TURN_ENERGY,
			"real five-card, three-energy player turn")
	return deck


func _teas() -> Array[String]:
	return [TEA, TEA, TEA, TEA, TEA]


func _snapshot(deck: CombatDeck, party: CombatParty, fixture: Dictionary) -> Dictionary:
	return {
		"heroes": party.get_heroes(),
		"draw": deck.draw_pile.duplicate(),
		"hand": deck.hand.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"turn_active": deck.turn_active,
		"energy": deck.energy,
		"rng": deck._rng.state,
		"wardrobe": fixture.wardrobe.get_snapshot(),
		"torn": fixture.torn.read_state(),
	}


## Only a genuine, successful committed healing card produces an observation here.
func _commit_heal(deck: CombatDeck, party: CombatParty, target: int,
		card_id: String = TEA, expect_restored: bool = true) -> Dictionary:
	_check(deck.turn_active and deck.hand.has(card_id),
		card_id + " is genuinely in the active hand before the commit")
	var before_hp: int = party.get_hero(target)["hp"]
	var maximum: int = party.get_hero(target)["max_hp"]
	var copies_in_hand: int = deck.hand.count(card_id)
	var resolver := CombatSeamstressPoolHeals.new()
	_check(resolver.play_card(deck, party, card_id, target),
		card_id + " commits successfully on slot " + str(target))
	var after_hp: int = party.get_hero(target)["hp"]
	_check((after_hp > before_hp) == expect_restored,
		card_id + " restored HP as expected on slot " + str(target))
	_check(deck.hand.count(card_id) == copies_in_hand - 1
		and deck.discard_pile.has(card_id),
		card_id + ": exactly one held copy moved to the discard pile")
	return {"before_hp": before_hp, "after_hp": after_hp, "max_hp": maximum}


## A refusal must be perfectly inert: no Block, no receipt award, no ledger,
## deck or RNG change anywhere.
func _expect_rejection(helper: CombatBorrowedButton, fixture: Dictionary,
		party: CombatParty, deck: CombatDeck, label: String, args: Array,
		reason: String) -> void:
	var before: Dictionary = _snapshot(deck, party, fixture)
	var result: Dictionary = helper.notify_committed_heal(
		args[0], args[1], args[2], args[3], args[4])
	_check(result.get("ok") == false and result.get("awarded") == false
		and result.get("block") == 0 and result.get("reason") == reason,
		label + ": refused with " + reason)
	_check(_snapshot(deck, party, fixture) == before,
		label + ": refusal leaves party, wardrobe, torn ledger, deck and RNG unchanged")
	_check(helper.read_state().get("awarded") == false,
		label + ": refusal records no award")


func _test_award_once_per_combat() -> void:
	var fixture := _fixture()
	if fixture.is_empty():
		return
	var party: CombatParty = fixture.party
	var helper := _bind(fixture)
	_check(party.apply_damage(1, 12) and party.get_hero(1)["hp"] == 28,
		"wearer Warden is genuinely wounded below maximum HP")
	_check(party.apply_damage(2, 6) and party.apply_damage(3, 8),
		"both other living heroes are wounded as well")
	_check(party.gain_block(2, 2) and party.gain_block(3, 3),
		"unrelated pre-existing Block belongs to two other heroes")
	var deck := _deck(_teas())
	var commit := _commit_heal(deck, party, 1)
	_check(commit["before_hp"] == 28 and commit["after_hp"] == 31,
		"Thimble Tea by Seamstress restores exactly 3 HP to the other living hero")

	var before_notify := _snapshot(deck, party, fixture)
	var result := helper.notify_committed_heal("receipt_tea_1", "seamstress", "warden",
		commit["before_hp"], commit["after_hp"])
	_check(result.get("ok") == true and result.get("awarded") == true
		and result.get("block") == 3 and result.get("wearer_id") == "warden"
		and result.get("receipt_id") == "receipt_tea_1"
		and result.get("reason") == "awarded",
		"the unique post-commit receipt awards exactly 3 Block to the wearer")
	var expected: Dictionary = before_notify.duplicate(true)
	expected["heroes"][0]["block"] += 3
	_check(_snapshot(deck, party, fixture) == expected,
		"the award changes only the wearer's Block: HP, other heroes, deck, ledgers and RNG hold")
	_check(party.get_hero(2)["block"] == 2 and party.get_hero(3)["block"] == 3,
		"no collateral Block on either other hero")
	var state: Dictionary = helper.read_state()
	_check(state.get("awarded") == true and state.get("awards") == 1
		and state.get("block_awarded") == 3 and state.get("wearer_id") == "warden"
		and state.get("receipt_id") == "receipt_tea_1"
		and state.get("receipts") == ["receipt_tea_1"],
		"read-only awarded state reports exactly one 3-Block payment")

	# A second qualifying heal in the same combat is a real transition, but the
	# one-per-combat latch already paid.
	var second := _commit_heal(deck, party, 1)
	_check(second["before_hp"] == 31 and second["after_hp"] == 34,
		"second committed heal genuinely restores 3 more HP")
	var before_second := _snapshot(deck, party, fixture)
	var again := helper.notify_committed_heal("receipt_tea_2", "seamstress", "warden",
		second["before_hp"], second["after_hp"])
	_check(again.get("ok") == true and again.get("awarded") == false
		and again.get("block") == 0 and again.get("reason") == "already_awarded",
		"a subsequent qualifying heal in the same combat pays nothing")
	_check(_snapshot(deck, party, fixture) == before_second
		and party.get_hero(1)["block"] == 3,
		"the consumed combat keeps its single 3 Block award without drift")

	# Replaying the original receipt cannot fabricate a second payment.
	var replay := helper.notify_committed_heal("receipt_tea_1", "seamstress", "warden",
		second["before_hp"], second["after_hp"])
	_check(replay.get("ok") == false and replay.get("awarded") == false
		and replay.get("reason") == "duplicate_receipt",
		"a replayed receipt identity is refused outright")
	_check(party.get_hero(1)["block"] == 3 and helper.read_state().get("awards") == 1,
		"replaying the receipt leaves the single award untouched")


## AC3: identical seeded fixtures award identically, and a NEW combat instance on
## the same unchanged authorities is allowed to award once again.
func _combat_trace() -> Array:
	var fixture := _fixture()
	if fixture.is_empty():
		return []
	var party: CombatParty = fixture.party
	var helper := _bind(fixture)
	party.apply_damage(1, 12)
	var deck := _deck(_teas(), 9182)
	var commit := _commit_heal(deck, party, 1)
	var result := helper.notify_committed_heal("trace_receipt", "seamstress", "warden",
		commit["before_hp"], commit["after_hp"])
	return [commit, result, helper.read_state(), _snapshot(deck, party, fixture)]


func _test_new_combat_rearms() -> void:
	var first := _combat_trace()
	var second := _combat_trace()
	_check(first.size() == 4 and not first.is_empty(),
		"a seeded combat trace records commit, result, state and party")
	_check(first == second,
		"two otherwise identical seeded fixtures produce the identical award")

	var fixture := _fixture()
	if fixture.is_empty():
		return
	var party: CombatParty = fixture.party
	var helper := _bind(fixture)
	party.apply_damage(1, 12)
	var deck := _deck(_teas(), 77)
	var commit := _commit_heal(deck, party, 1)
	_check(helper.notify_committed_heal("combat_one_receipt", "seamstress", "warden",
		commit["before_hp"], commit["after_hp"]).get("awarded") == true,
		"first combat awards its fresh instance")
	_check(party.get_hero(1)["block"] == 3, "first combat paid exactly 3 Block")

	# Real turn boundary clears Block; the worn patch and its latch stay with
	# their own combat instance.
	_check(deck.end_turn() and party.start_player_turn() and deck.start_turn(),
		"real turn boundary resets Block and refills the shared hand")
	_check(party.get_hero(1)["block"] == 0, "new player turn cleared the old Block")
	party.apply_damage(1, 9)
	var next := _commit_heal(deck, party, 1)
	var retried := helper.notify_committed_heal("combat_one_late", "seamstress", "warden",
		next["before_hp"], next["after_hp"])
	_check(retried.get("awarded") == false and retried.get("reason") == "already_awarded"
		and party.get_hero(1)["block"] == 0,
		"the consumed instance stays spent even after a real later heal")

	var fresh := CombatBorrowedButton.new()
	_check(fresh.bind_combat(party, fixture.wardrobe, fixture.torn),
		"a new combat instance binds the same unchanged authorities")
	var rearmed := fresh.notify_committed_heal("combat_two_receipt", "seamstress", "warden",
		next["before_hp"], next["after_hp"])
	_check(rearmed.get("ok") == true and rearmed.get("awarded") == true
		and rearmed.get("block") == 3 and party.get_hero(1)["block"] == 3,
		"the new combat instance may award once again")
	_check(helper.read_state().get("awards") == 1
		and fresh.read_state().get("awards") == 1,
		"each combat instance owns its own single award")


func _test_negative_transitions() -> void:
	# Zero effective heal against a full-HP wearer.
	var fixture := _fixture()
	if fixture.is_empty():
		return
	var party: CombatParty = fixture.party
	var helper := _bind(fixture)
	var deck := _deck(_teas())
	var zero := _commit_heal(deck, party, 1, TEA, false)
	_check(zero["before_hp"] == 40 and zero["after_hp"] == 40,
		"overheal at full HP restores exactly 0 HP")
	_expect_rejection(helper, fixture, party, deck, "full-HP wearer", [
		"neg_zero_heal", "seamstress", "warden", 40, 40], "no_effective_heal")

	# A genuine self-heal by the Seamstress pays the wearer nothing.
	party.apply_damage(2, 8)
	var self_commit := _commit_heal(deck, party, 2)
	_check(self_commit["before_hp"] == 22 and self_commit["after_hp"] == 25,
		"Seamstress genuinely healed herself by 3 HP")
	_expect_rejection(helper, fixture, party, deck, "self-heal", [
		"neg_self", "seamstress", "seamstress", 22, 25], "self_heal")

	# Another hero is healed, but the wearer received nothing.
	party.apply_damage(3, 8)
	var other_commit := _commit_heal(deck, party, 3)
	_check(other_commit["before_hp"] == 18 and other_commit["after_hp"] == 21,
		"Seamstress genuinely healed the Tinker instead")
	_expect_rejection(helper, fixture, party, deck, "other recipient", [
		"neg_other_recipient", "seamstress", "tinker", 18, 21], "no_active_patch")

	# A fabricated transition that no longer matches the committed party.
	party.apply_damage(1, 12)
	var warden_commit := _commit_heal(deck, party, 1)
	_check(warden_commit["before_hp"] == 28 and warden_commit["after_hp"] == 31,
		"wearer genuinely at 31 HP after a real heal")
	_expect_rejection(helper, fixture, party, deck, "stale observation", [
		"neg_stale", "seamstress", "warden", 28, 40], "stale_observation")
	_expect_rejection(helper, fixture, party, deck, "zero-valued transition", [
		"neg_backwards", "seamstress", "warden", 31, 31], "no_effective_heal")
	_expect_rejection(helper, fixture, party, deck, "malformed observation", [
		"neg_malformed", "seamstress", "warden", "28", 31], "malformed_observation")

	# Identities that are not canonical heroes, including a whole stitched card.
	_expect_rejection(helper, fixture, party, deck, "whole stitched card identity", [
		"neg_composite", "seamstress+tinker", "warden", 28, 31], "unknown_healer")
	_expect_rejection(helper, fixture, party, deck, "unknown recipient identity", [
		"neg_ghost", "seamstress", "ghost", 28, 31], "unknown_recipient")
	_expect_rejection(helper, fixture, party, deck, "blank receipt identity", [
		"   ", "seamstress", "warden", 28, 31], "unknown_receipt")
	_check(helper.read_state().get("awarded") == false,
		"none of the refused notifications awarded anything")

	# Owned but unsewn: the patch is in the wardrobe yet worn by nobody.
	var unsewn := _fixture("warden", false)
	if unsewn.is_empty():
		return
	var unsewn_party: CombatParty = unsewn.party
	var unsewn_helper := _bind(unsewn)
	var unsewn_deck := _deck(_teas())
	unsewn_party.apply_damage(1, 7)
	var unsewn_commit := _commit_heal(unsewn_deck, unsewn_party, 1)
	_check(unsewn.wardrobe.get_snapshot()["owned"].has("borrowed_button")
		and unsewn.wardrobe.project_active(unsewn.torn.read_state())["active"]["warden"].is_empty(),
		"owned but unsewn Borrowed Button has no active COAT assignment")
	_expect_rejection(unsewn_helper, unsewn, unsewn_party, unsewn_deck, "unsewn COAT", [
		"neg_unsewn", "seamstress", "warden",
		unsewn_commit["before_hp"], unsewn_commit["after_hp"]], "no_active_patch")
	_check(not unsewn.wardrobe.sew("borrowed_button", "warden", "ARM", "sew_wrong_slot",
		unsewn.wardrobe.get_snapshot()).get("ok"),
		"the wardrobe refuses the COAT record in the ARM slot")

	# The very same patch worn by a different hero: the healed Warden has no patch.
	var misplaced := _fixture("seamstress")
	if misplaced.is_empty():
		return
	var misplaced_party: CombatParty = misplaced.party
	var misplaced_helper := _bind(misplaced)
	var misplaced_deck := _deck(_teas())
	misplaced_party.apply_damage(1, 9)
	var misplaced_commit := _commit_heal(misplaced_deck, misplaced_party, 1)
	_check(misplaced.wardrobe.get_snapshot()["worn"]["seamstress"]["COAT"] == "borrowed_button"
		and misplaced.wardrobe.get_snapshot()["worn"]["warden"]["COAT"] == "",
		"Borrowed Button is genuinely sewn onto the Seamstress, not the Warden")
	_expect_rejection(misplaced_helper, misplaced, misplaced_party, misplaced_deck,
		"patch worn by another hero", ["neg_wrong_wearer", "seamstress", "warden",
		misplaced_commit["before_hp"], misplaced_commit["after_hp"]], "no_active_patch")

	# A different real COAT patch is worn instead: Borrowed Button is not awarded
	# for merely owning any painted coat.
	var other_coat := _fixture("warden", true, "quilted_coat", ["quilted_coat"])
	if other_coat.is_empty():
		return
	var coat_party: CombatParty = other_coat.party
	var coat_helper := _bind(other_coat)
	var coat_deck := _deck(_teas())
	coat_party.apply_damage(1, 10)
	var coat_commit := _commit_heal(coat_deck, coat_party, 1)
	_check(other_coat.wardrobe.get_snapshot()["worn"]["warden"]["COAT"] == "quilted_coat"
		and other_coat.wardrobe.get_snapshot()["owned"].has("quilted_coat"),
		"a different authored COAT patch is genuinely sewn onto the wearer")
	_expect_rejection(coat_helper, other_coat, coat_party, coat_deck,
		"unknown COAT patch", ["neg_other_coat", "seamstress", "warden",
		coat_commit["before_hp"], coat_commit["after_hp"]], "no_active_patch")

	# Block overflow is preflighted and pays nothing.
	var overflow := _fixture()
	if overflow.is_empty():
		return
	var overflow_party: CombatParty = overflow.party
	var overflow_helper := _bind(overflow)
	var overflow_deck := _deck(_teas())
	overflow_party.apply_damage(1, 12)
	_check(overflow_party.gain_block(1, CombatParty.MAX_INT - 2),
		"wearer Block is genuinely near the integer ceiling")
	var overflow_commit := _commit_heal(overflow_deck, overflow_party, 1)
	_expect_rejection(overflow_helper, overflow, overflow_party, overflow_deck,
		"Block overflow", ["neg_overflow", "seamstress", "warden",
		overflow_commit["before_hp"], overflow_commit["after_hp"]], "block_overflow")
	_check(overflow_party.get_hero(1)["block"] == CombatParty.MAX_INT - 2,
		"the overflow refusal granted no Block at all")


## An attempted or failed cast never even reaches the helper: no receipt exists and
## the latch stays free.
func _test_failed_cast_never_notifies() -> void:
	var fixture := _fixture()
	if fixture.is_empty():
		return
	var party: CombatParty = fixture.party
	var helper := _bind(fixture)
	var deck := _deck([DARNING, DARNING, TEA, TEA, TEA])
	party.apply_damage(1, 10)
	_check(deck.try_spend_energy(3) and deck.energy == 0,
		"Darning is genuinely unaffordable after spending the turn's energy")
	var before: Dictionary = _snapshot(deck, party, fixture)
	var resolver := CombatSeamstressPoolHeals.new()
	_check(not resolver.play_card(deck, party, DARNING, 1),
		"the failed Darning cast is refused before any commit")
	_check(_snapshot(deck, party, fixture) == before,
		"the failed cast leaves party, deck, ledgers and RNG unchanged")
	var state: Dictionary = helper.read_state()
	_check(state.get("awards") == 0 and state.get("receipts").is_empty()
		and party.get_hero(1)["block"] == 0,
		"a failed cast produces no notification and no award")
	# The latch is still free, so a genuine commit afterwards pays once.
	_check(deck.end_turn() and deck.start_turn() and deck.energy == 3,
		"a real turn boundary restores the energy budget")
	_check(deck.hand.has(TEA), "a genuine Thimble Tea copy is in the new hand")
	var commit := _commit_heal(deck, party, 1, TEA)
	_check(helper.notify_committed_heal("after_failed_cast", "seamstress", "warden",
		commit["before_hp"], commit["after_hp"]).get("awarded") == true,
		"the untouched latch still awards the first genuine commit")
	_check(party.get_hero(1)["block"] == 3,
		"the genuine Thimble Tea commit awarded exactly 3 Block")


## A truly torn ledger and a truly downed party member: the sewn patch keeps its
## assignment but stops paying.
func _test_downed_and_torn_wearer() -> void:
	var fixture := _fixture()
	if fixture.is_empty():
		return
	var wardrobe: RunPatchWardrobe = fixture.wardrobe
	var torn: RunTornMending = fixture.torn
	var start: Array = torn.read_state()["heroes"]
	var torn_end: Array = start.duplicate(true)
	torn_end[0]["hp"] = 0
	_check(torn.observe_battle_end("fight_borrowed_button_tear", start, torn_end).get("ok") == true,
		"a real battle end tears the Warden in the run ledger")
	var context: Dictionary = wardrobe.get_snapshot()
	_check(wardrobe.refresh_run_context(torn.read_state()["heroes"], context["owned"],
		context["scraps"], context["gold"], context["cards"], context),
		"the wardrobe adopts the torn roster and keeps the sewn COAT")
	var projection: Dictionary = wardrobe.project_active(torn.read_state())
	_check(projection.get("ok") == true
		and projection["worn"]["warden"]["COAT"] == "borrowed_button"
		and projection["active"]["warden"].is_empty(),
		"the torn wearer keeps the COAT sewn but has no active patch")

	var definitions: Array = []
	for hero: Dictionary in torn.read_state()["heroes"]:
		definitions.append({"id": hero["id"], "max_hp": hero["max_hp"]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "the next battle's party accepts the torn roster")
	_check(party.apply_damage(1, CombatParty.MAX_INT) and party.get_hero(1)["hp"] == 0,
		"that Warden is genuinely downed in the party")
	_check(party.apply_damage(2, 9) and party.get_hero(2)["hp"] == 21,
		"the living Seamstress is wounded for the attempted rescue")
	var helper := CombatBorrowedButton.new()
	_check(helper.bind_combat(party, wardrobe, torn),
		"the helper binds the torn combat authorities")
	var deck := _deck(_teas())
	_expect_rejection(helper, {"party": party, "wardrobe": wardrobe, "torn": torn},
		party, deck, "downed/torn wearer", ["neg_torn_wearer", "seamstress", "warden", 0, 3],
		"downed_recipient")

	# A downed healer cannot rescue anyone.
	var healer_fixture := _fixture()
	if healer_fixture.is_empty():
		return
	var healer_party: CombatParty = healer_fixture.party
	var healer_helper := _bind(healer_fixture)
	var healer_deck := _deck(_teas())
	healer_party.apply_damage(1, 10)
	_check(healer_party.apply_damage(2, CombatParty.MAX_INT)
		and healer_party.is_downed(2), "the Seamstress healer is genuinely downed")
	_expect_rejection(healer_helper, healer_fixture, healer_party, healer_deck,
		"downed healer", ["neg_down_healer", "seamstress", "warden", 30, 31],
		"downed_healer")


## A healer torn at a previous battle end stays 0 HP in the run ledger, while the
## next CombatParty admits that same hero at its reduced maximum HP. Seat liveness
## alone must not pay the wearer: the reward belongs to a genuinely untorn healer.
func _test_torn_healer_still_refused() -> void:
	var fixture := _fixture()
	if fixture.is_empty():
		return
	var wardrobe: RunPatchWardrobe = fixture.wardrobe
	var torn: RunTornMending = fixture.torn
	var start: Array = torn.read_state()["heroes"]
	var torn_end: Array = start.duplicate(true)
	torn_end[1]["hp"] = 0
	_check(torn.observe_battle_end("fight_borrowed_button_torn_healer", start, torn_end).get("ok") == true,
		"a real battle end tears the Seamstress healer in the run ledger")
	var torn_state: Dictionary = torn.read_state()
	_check(torn_state["heroes"][1]["id"] == "seamstress"
		and torn_state["heroes"][1]["hp"] == 0
		and torn_state["heroes"][1]["max_hp"] == 27
		and torn_state["tear_counts"]["seamstress"] == 1,
		"the torn Seamstress keeps 0 HP and loses exactly 3 maximum HP in the run ledger")
	var context: Dictionary = wardrobe.get_snapshot()
	_check(wardrobe.refresh_run_context(torn_state["heroes"], context["owned"],
		context["scraps"], context["gold"], context["cards"], context),
		"the wardrobe adopts the torn roster and keeps the sewn Borrowed Button")

	# The fresh battle party is built from the torn ledger's own max HP values, so
	# the torn Seamstress starts it party-alive despite being run-torn.
	var definitions: Array = []
	for hero: Dictionary in torn_state["heroes"]:
		definitions.append({"id": hero["id"], "max_hp": hero["max_hp"]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "the next battle's party accepts the torn roster")
	_check(party.get_hero(1)["id"] == "warden" and party.get_hero(1)["hp"] == 40
		and party.get_hero(2)["id"] == "seamstress" and party.get_hero(2)["hp"] == 27
		and not party.is_downed(2),
		"the run-torn Seamstress starts the fresh party alive at 27 HP")
	var helper := CombatBorrowedButton.new()
	_check(helper.bind_combat(party, wardrobe, torn),
		"the helper binds the fresh battle party to the torn ledgers")
	_check(helper.read_state().get("ok") == true,
		"the torn-healer combat binding is current and authoritative")
	_check(party.apply_damage(1, 12) and party.get_hero(1)["hp"] == 28,
		"the living Borrowed Button Warden is genuinely wounded")

	var torn_fixture := {"party": party, "wardrobe": wardrobe, "torn": torn}
	var deck := _deck(_teas())
	var commit := _commit_heal(deck, party, 1)
	_check(commit["before_hp"] == 28 and commit["after_hp"] == 31,
		"the run-torn Seamstress still commits a real 3 HP Thimble Tea heal")
	_expect_rejection(helper, torn_fixture, party, deck, "run-torn healer", [
		"neg_torn_healer", "seamstress", "warden",
		commit["before_hp"], commit["after_hp"]], "torn_healer")
	_check(party.get_hero(1)["block"] == 0,
		"the run-torn healer's committed heal awards zero Block to the wearer")
	_check(helper.read_state().get("awards") == 0,
		"the run-torn healer leaves the once-per-combat latch unspent")
	# A distinct receipt cannot retry the very same torn healer into a payment.
	var retry_before: Dictionary = _snapshot(deck, party, torn_fixture)
	var retry := helper.notify_committed_heal("neg_torn_healer_retry", "seamstress",
		"warden", commit["before_hp"], commit["after_hp"])
	_check(retry.get("ok") == false and retry.get("awarded") == false
		and retry.get("block") == 0 and retry.get("reason") == "torn_healer",
		"a distinct receipt from the same run-torn healer is still refused")
	_check(_snapshot(deck, party, torn_fixture) == retry_before,
		"the retried torn-healer refusal leaves party, wardrobe, torn ledger, deck and RNG unchanged")
	_check(party.get_hero(1)["block"] == 0 and helper.read_state().get("awarded") == false,
		"no torn-healer path ever pays the wearer")


## AC4: a two-owner stitched play reports one notification per authenticated half,
## each with its own owner identity; the whole card is never one anonymous healer.
func _test_stitched_half_owners() -> void:
	var fixture := _fixture()
	if fixture.is_empty():
		return
	var party: CombatParty = fixture.party
	var helper := _bind(fixture)
	var deck := _deck(_teas())
	party.apply_damage(1, 10)
	party.apply_damage(2, 8)

	# Half A belongs to the Seamstress and heals only herself: refused, and the
	# combat latch is untouched for the second half.
	var half_a := _commit_heal(deck, party, 2)
	_check(half_a["before_hp"] == 22 and half_a["after_hp"] == 25,
		"half A's owner genuinely healed that owner by 3 HP")
	_expect_rejection(helper, fixture, party, deck, "self-owner half A", [
		"stitched_half_a", "seamstress", "seamstress", 22, 25], "self_heal")

	# The whole stitched card has no owner of its own.
	_expect_rejection(helper, fixture, party, deck, "anonymous stitched card", [
		"stitched_whole_card", "stitched_seamstress_tinker", "warden", 30, 33],
		"unknown_healer")

	# Half B belongs to the Tinker and really restores HP to the wearer.
	var half_b := _commit_heal(deck, party, 1)
	_check(half_b["before_hp"] == 30 and half_b["after_hp"] == 33,
		"half B's committed heal genuinely restored 3 HP to the wearer")
	var result := helper.notify_committed_heal("stitched_half_b", "tinker", "warden",
		half_b["before_hp"], half_b["after_hp"])
	_check(result.get("ok") == true and result.get("awarded") == true
		and result.get("block") == 3 and party.get_hero(1)["block"] == 3,
		"the independently owned half B awards its own 3 Block")
	_check(result.get("receipt_id") == "stitched_half_b",
		"the award is tied to half B's own receipt, not the whole card")

	# Repeating half B's receipt, or re-attributing the same heal to half A's
	# owner, cannot buy a second payment.
	var before_replay := _snapshot(deck, party, fixture)
	var replay := helper.notify_committed_heal("stitched_half_b", "tinker", "warden",
		half_b["before_hp"], half_b["after_hp"])
	_check(replay.get("ok") == false and replay.get("reason") == "duplicate_receipt",
		"replaying half B's receipt is refused")
	var reattributed := helper.notify_committed_heal("stitched_half_b_owner_a", "seamstress",
		"warden", half_b["before_hp"], half_b["after_hp"])
	_check(reattributed.get("awarded") == false
		and reattributed.get("reason") == "already_awarded",
		"the other half's owner cannot claim a second payment for the same combat")
	_check(_snapshot(deck, party, fixture) == before_replay
		and party.get_hero(1)["block"] == 3,
		"stitched replays leave the party, ledgers, deck and RNG untouched")


## The real atomic Rest resolver and ordinary pool healer must share one notifier.
## Neither can re-arm the other by re-binding the same combat authorities.
func _real_stitched_context(reverse: bool = false) -> Dictionary:
	var fixture := _fixture()
	if fixture.is_empty():
		return {}
	var rest := RunRestStitchCards.new(
		["warden_brace" if reverse else "seamstress_mend",
		 "seamstress_mend" if reverse else "warden_brace"], {}, 3)
	_check(rest.is_valid(), "real Rest stitching ledger is valid")
	var sewn := rest.choose_stitch(0, 1, rest.get_snapshot())
	_check(sewn.get("ok") == true and sewn.get("consumed_ids", []).size() == 2,
		"genuine Rest choice removes both originals and creates stitched ID")
	if not sewn.get("ok", false):
		return {}
	var deck := _deck([sewn.stitched_id, TEA, TEA], 211613)
	_check(deck.hand.has(sewn.stitched_id) and deck.hand.count(TEA) == 2,
		"shared battle hand genuinely holds stitched card and ordinary Tea")
	var heals := CombatSeamstressPoolHeals.new()
	_check(heals.bind_patch_wardrobe(fixture.wardrobe, fixture.torn),
		"ordinary healing service has valid combat wardrobe/torn binding")
	var stitched := CombatStitchedCards.new()
	_check(stitched.bind_patch_wardrobe(fixture.wardrobe, fixture.torn),
		"stitched resolver shares the same authentic patch ledgers")
	stitched.bind_borrowed_button(heals)
	var enemies_data: Array = _json("res://data/enemies/starter_enemies.json")
	for record in enemies_data:
		record.max_hp = int(record.max_hp)
	var enemies := CombatEnemies.new(enemies_data)
	_check(enemies.is_valid() and rest.preview_play(sewn.stitched_id,
		fixture.party.get_heroes()).ok, "enemy roster and stitched owners genuinely valid")
	return {"fixture": fixture, "party": fixture.party, "rest": rest,
		"deck": deck, "enemies": enemies, "heals": heals,
		"stitched": stitched, "id": sewn.stitched_id}


func _test_real_stitched_commits_share_latch() -> void:
	for reverse in [false, true]:
		for ordinary_first in [false, true]:
			var c := _real_stitched_context(reverse)
			if c.is_empty():
				continue
			_check(c.party.apply_damage(1, 12) and c.party.get_hero(1).hp == 28,
				"real other-owner wearer wounded before two card commits")
			var shared: CombatBorrowedButton = c.heals._borrowed_button
			var heal_target: int = 1
			var a: int = 0 if reverse else heal_target
			var b: int = heal_target if reverse else 0
			if ordinary_first:
				_check(c.heals.play_card(c.deck, c.party, TEA, heal_target),
					"ordinary Tea commits first and authenticates P6")
			else:
				var first: Dictionary = c.stitched.play_stitched(
					c.deck, c.party, c.enemies, c.rest, c.id, a, b)
				_check(first.get("ok") == true and first.halves.size() == 2,
					"real stitched Mend/Brace commits both ordered halves first")
			_check(shared.read_state().awards == 1 and c.party.get_hero(1).block >= 3,
				"first authentic heal consumes the one-combat 3-Block latch")
			var receipt: String = shared.read_state().receipt_id
			_check(c.heals.bind_patch_wardrobe(c.fixture.wardrobe, c.fixture.torn)
				and c.heals._borrowed_button == shared,
				"same-combat ledger rebind preserves the exact notifier instance")
			if ordinary_first:
				var second: Dictionary = c.stitched.play_stitched(
					c.deck, c.party, c.enemies, c.rest, c.id, a, b)
				_check(second.get("ok") == true and second.halves.size() == 2,
					"genuine stitched heal follows ordinary committed Tea")
			else:
				_check(c.heals.play_card(c.deck, c.party, TEA, heal_target),
					"ordinary Tea follows genuine stitched heal in same combat")
			_check(c.party.get_hero(1).hp == 36 and c.party.get_hero(1).block == 10,
				"one 3-Block P6 award plus authored 7 Brace after two actual heals")
			_check(c.deck.energy == 1 and c.deck.discard_pile.size() == 2
				and c.deck.discard_pile.count(c.id) == 1
				and c.deck.discard_pile.count(TEA) == 1,
				"two real committed cards each discarded once; stitched energy paid once")
			_check(shared.read_state().awards == 1 and shared.read_state().receipts.size() == 2
				and c.heals._heal_receipt_number == 2,
				"both ordered source kinds share one sequence and only one P6 payment")
			var before: Dictionary = _snapshot(c.deck, c.party, c.fixture)
			var replay: Dictionary = shared.notify_committed_heal(receipt,
				"seamstress", "warden", 28, 33)
			_check(replay.reason == "duplicate_receipt"
				and _snapshot(c.deck, c.party, c.fixture) == before
				and shared.read_state().awards == 1,
				"replaying either source's original receipt cannot award again")


func _test_real_stitched_resewn_wearer() -> void:
	var c := _real_stitched_context()
	if c.is_empty():
		return
	var wardrobe: RunPatchWardrobe = c.fixture.wardrobe
	_check(wardrobe.start_rest("p6_resew_rest", wardrobe.get_snapshot()).ok,
		"real Rest is opened before re-sewing Borrowed Button")
	_check(wardrobe.re_sew("borrowed_button", "warden", "tinker",
		"p6_resew_rest", "move_p6_to_tinker", wardrobe.get_snapshot()).ok,
		"Borrowed Button genuinely re-sewn from Warden to Tinker")
	_check(wardrobe.end_rest("p6_resew_rest", wardrobe.get_snapshot()).ok,
		"real Rest closes with P6 on new wearer")
	_check(c.heals.bind_patch_wardrobe(wardrobe, c.fixture.torn)
		and c.stitched.bind_patch_wardrobe(wardrobe, c.fixture.torn),
		"new combat reauthenticates actual re-sewn wardrobe")
	_check(c.party.apply_damage(3, 9) and c.party.get_hero(3).hp == 17,
		"new wearer Tinker genuinely wounded and living")
	var before: Dictionary = _snapshot(c.deck, c.party, c.fixture)
	var outcome: Dictionary = c.stitched.play_stitched(
		c.deck, c.party, c.enemies, c.rest, c.id, 3, 0)
	_check(outcome.get("ok") == true and outcome.halves.size() == 2,
		"actual Rest-stitched Seamstress Mend heals newly sewn Tinker")
	_check(c.party.get_hero(3).hp == 22 and c.party.get_hero(3).block == 3
		and c.party.get_hero(1).block == 7,
		"only the new active COAT wearer gains 3 P6 Block; Brace stays with Warden")
	_check(c.heals._borrowed_button.read_state().awards == 1
		and c.heals._borrowed_button.read_state().wearer_id == "tinker"
		and c.heals._borrowed_button.read_state().receipts.size() == 1,
		"re-sewn wearer's first authentic other-owner heal spends one latch")
	_check(c.deck.energy == before.energy - 2 and c.deck.discard_pile.count(c.id) == 1,
		"re-sewing does not alter one-cost and one-discard stitched transaction")
