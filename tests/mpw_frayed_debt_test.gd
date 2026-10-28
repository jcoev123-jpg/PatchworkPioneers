extends SceneTree
## Independent P11 data/preparation/choice tests and the real battle draw exhaust. No route claim.

var failures: Array[String] = []
var checks := 0
const LEGACY := ["warden", "seamstress", "tinker"]
const ALTERNATE := ["lantern_monk", "yarn_ranger", "button_golem"]


func _initialize() -> void:
	_test_authored()
	_test_choices()
	_test_replay_and_ownership()
	_test_invalid_preparation()
	_test_stitches()
	_test_stale_and_retry()
	_test_battle_draws()
	for failure in failures:
		printerr(failure)
	print("mpw_frayed_debt_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _rng(seed_value: int = 352) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _context(ids: Array = LEGACY) -> Dictionary:
	var admission := RunV3PartyAdmission.admit(ids)
	_check(admission.ok and not admission.deck.is_empty(), "real selected-party starter deck")
	return {"party_ids": ids.duplicate(), "deck": admission.deck.duplicate(),
		"descriptors": {}, "remaining_scraps": 7, "next_stitch_id": 1, "visited": false}


func _test_authored() -> void:
	var file := FileAccess.open(RunFrayedDebtParcel.EVENT_PATH, FileAccess.READ)
	_check(file != null, "P11 shipped event FileAccess")
	if file == null:
		return
	var event: Variant = JSON.parse_string(file.get_as_text())
	_check(event is Dictionary, "P11 JSON object")
	if not event is Dictionary:
		return
	_check(event.id == "frayed_debt_parcel" and event.once_per_run == true, "stable event once/run")
	_check(event.offer_count == 2 and event.rarity == "uncommon" and event.exit_scraps == 1
		and event.visit_weight == 1, "two uncommon slots, safe scrap and scarce weight")
	_check(event.choices.size() == 3 and event.choices[0].id == "offer_0"
		and event.choices[1].id == "offer_1" and event.choices[2].id == "safe_exit", "exact choice slots")
	var cards := MpwFrayedDebt.new()
	_check(cards.get_card_ids() == ["frayed_debt"] and event.curse_id == "frayed_debt", "one canonical curse ID")
	var definition := cards.get_definition("frayed_debt")
	_check(not definition.is_empty(), "canonical curse exists")
	_check(definition.card_type == "curse" and definition.playable == false and definition.removable == true
		and definition.can_stitch == false and definition.can_upgrade == false and definition.reward_eligible == false
		and definition.starting_copies == 0, "non-playable removable data, no starter/reward copies")
	_check(definition.exhaust_on_first_draw and definition.consumes_draw, "future draw contract data")
	definition.removable = false
	_check(cards.get_definition("frayed_debt").removable, "curse definitions detached")
	_check(cards.get_definition("frayed_debt_plus").is_empty() and cards.get_definition(1).is_empty(), "no aliases/upgrades")
	for party in [LEGACY, ALTERNATE]:
		_check(not _context(party).deck.has("frayed_debt"), "authentic starting decks unchanged")


func _test_choices() -> void:
	for slot in range(3):
		var context := _context()
		var before := context.duplicate(true)
		var rng := _rng()
		var service := RunFrayedDebtParcel.new()
		var prepared := service.prepare(context, rng)
		_check(prepared.ok and service.is_valid() and not service.is_consumed(), "prepare valid service")
		if not prepared.ok:
			continue
		var offers := service.get_offers()
		_check(offers.size() == 2, "two actual offers before claim")
		if offers.size() != 2:
			continue
		var state := rng.state
		var choice: String = offers[slot].id if slot < 2 else RunFrayedDebtParcel.SAFE_EXIT
		var source := service.get_source_snapshot()
		var result := service.choose(choice, source)
		var expected: Array = before.deck.duplicate()
		if slot < 2:
			expected.append(choice)
			expected.append("frayed_debt")
		_check(result.ok and service.is_consumed() and result.visited, "choice consumes parcel once")
		_check(result.deck == expected and result.remaining_scraps == before.remaining_scraps + (1 if slot == 2 else 0),
			"exact card-plus-curse or safe exit deck/wallet delta")
		_check(result.descriptors == before.descriptors and result.next_stitch_id == before.next_stitch_id,
			"stitch ledger/cursor unchanged")
		_check(context == before and rng.state == state and source == service.get_source_snapshot(), "owner source and RNG untouched by choice")
		_check(not result.receipt.is_empty() and result.receipt != source.receipt, "transaction receipt")
		result.deck.clear()
		result.descriptors["forged"] = {}
		result.offers.clear()
		result.source_snapshot.deck.clear()
		var repeated := service.choose(choice, source)
		_check(not repeated.ok and repeated.deck == expected and repeated.descriptors == before.descriptors,
			"detached receipt and repeated claim cannot duplicate or corrupt")
		_check(not service.choose(RunFrayedDebtParcel.SAFE_EXIT, source).ok and rng.state == state, "cross-branch replay inert")


func _test_replay_and_ownership() -> void:
	# Exercise every hero among three-of-eight parties without assuming pool totals.
	for ids in [LEGACY, ALTERNATE, ["rag_duelist", "scarecrow", "warden"]]:
		var context := _context(ids)
		for seed_value in range(12):
			var first := RunFrayedDebtParcel.new()
			var second := RunFrayedDebtParcel.new()
			var rng := _rng(seed_value)
			var replay := _rng(seed_value)
			var trial := _rng(seed_value)
			var candidates := RunPoolCardRewardOffers.get_authored_base_candidates()
			var eligible: Array[String] = []
			for item in candidates:
				if item.rarity == "uncommon" and ids.has(item.owner):
					eligible.append(item.id)
			eligible.sort()
			var expected: Array[String] = []
			for index in range(2):
				var pick := trial.randi_range(0, eligible.size() - 1)
				expected.append(eligible[pick])
				eligible.remove_at(pick)
			candidates.reverse()
			_check(first.prepare(context, rng).ok and second.prepare(context, replay, candidates).ok, "seeded real preparation")
			var offers := first.get_offers()
			_check(offers.size() == 2, "nonempty pair for replay")
			if offers.size() != 2:
				continue
			_check(offers == second.get_offers() and rng.state == replay.state and rng.state == trial.state,
				"sorted catalog seed replay, exactly two draws")
			_check([offers[0].id, offers[1].id] == expected and offers[0].id != offers[1].id, "independent sorted without-replacement oracle")
			for offer in offers:
				_check(ids.has(offer.owner) and offer.rarity == "uncommon" and not offer.id.ends_with("_plus")
					and offer == RunPoolCardRewardOffers.resolve_reward_definition(offer.id), "only authentic selected-party uncommon base")
			var state := rng.state
			offers[0].owner = "forged"
			_check(first.get_offers() == second.get_offers(), "cached offers detached")
			_check(not first.prepare(context, rng).ok and rng.state == state, "no reroll of prepared offers")


func _reject_prepare(context: Variant, candidates: Variant, label: String) -> void:
	var service := RunFrayedDebtParcel.new()
	var rng := _rng()
	var state := rng.state
	var before: Variant = context.duplicate(true) if context is Dictionary else context
	var catalog_before: Variant = candidates.duplicate(true) if candidates is Array else candidates
	var result := service.prepare(context, rng, candidates)
	_check(not result.ok and not service.is_valid() and not service.is_consumed(), label + " rejected")
	_check(rng.state == state and context == before and candidates == catalog_before
		and service.get_offers().is_empty() and service.get_source_snapshot().is_empty(), label + " no partial preparation/mutation")
	_check(service.prepare(_context(), rng).ok, label + " preserves preparation opportunity")


func _test_invalid_preparation() -> void:
	for party in [null, [], ["warden", "tinker"], ["warden", "warden", "tinker"],
		["warden", "tinker", "forged"], ["warden", "tinker", 1]]:
		var context := _context()
		context.party_ids = party
		_reject_prepare(context, null, "invalid party")
	for key in ["deck", "descriptors", "remaining_scraps", "next_stitch_id", "visited"]:
		var context := _context()
		context.erase(key)
		_reject_prepare(context, null, "missing " + key)
	var foreign_deck: Array = _context(ALTERNATE).deck
	for entry in [["deck", []], ["deck", ["forged"]], ["deck", [foreign_deck[0]]],
		["descriptors", {"stitched_000001": {}}], ["remaining_scraps", -1], ["remaining_scraps", 7.0],
		["next_stitch_id", 0], ["next_stitch_id", 1.0], ["next_stitch_id", 9223372036854775807],
		["visited", true], ["visited", 0]]:
		var context := _context()
		context[entry[0]] = entry[1]
		_reject_prepare(context, null, "invalid ledger/visit " + str(entry))
	for catalog in [[], {}, [null], [{"id": "forged", "owner": "warden", "rarity": "uncommon"}]]:
		_reject_prepare(_context(), catalog, "invalid catalog")
	var authored := RunPoolCardRewardOffers.get_authored_base_candidates()
	for key in ["owner", "rarity", "id"]:
		for value in [null, 1, "forged"]:
			var catalog := authored.duplicate(true)
			catalog[0][key] = value
			_reject_prepare(_context(), catalog, "spoofed catalog " + key)
		var catalog := authored.duplicate(true)
		catalog[0].erase(key)
		_reject_prepare(_context(), catalog, "missing catalog " + key)
	var duplicate := authored.duplicate(true)
	duplicate.append(duplicate[0].duplicate())
	_reject_prepare(_context(), duplicate, "duplicate candidates")
	var upgraded := authored.duplicate(true)
	upgraded[0].id += "_plus"
	_reject_prepare(_context(), upgraded, "upgrade candidate")
	var spoofed_owner := authored.duplicate(true)
	spoofed_owner[0].owner = "tinker" if spoofed_owner[0].owner != "tinker" else "warden"
	_reject_prepare(_context(), spoofed_owner, "real but mismatched owner")
	var spoofed_rarity := authored.duplicate(true)
	spoofed_rarity[0].rarity = "rare" if spoofed_rarity[0].rarity != "rare" else "uncommon"
	_reject_prepare(_context(), spoofed_rarity, "real but mismatched rarity")
	var ancillary := authored.duplicate(true)
	ancillary[0]["display_name"] = 3
	_reject_prepare(_context(), ancillary, "unauthenticated ancillary field")
	var insufficient: Array = []
	for record in authored:
		if record.owner == "yarn_ranger":
			insufficient.append(record)
	_reject_prepare(_context(), insufficient, "foreign-only authentic pool")
	var service := RunFrayedDebtParcel.new()
	_check(not service.prepare(_context(), null).ok and not service.is_valid(), "invalid RNG")


func _test_stitches() -> void:
	var context := _context()
	var upgraded := context.duplicate(true)
	upgraded.deck.append("warden_hold_the_line_plus")
	_check(RunRestStitchCards.is_authored_pool_plus("warden_hold_the_line_plus"), "authentic pool upgrade prerequisite")
	_check(RunFrayedDebtParcel.new().prepare(upgraded, _rng()).ok, "canonical pool upgrades allowed in source, never offers")
	var stitch := RunRestStitchCards.new(context.deck, {}, 7, 1)
	var stitched := stitch.choose_stitch(context.deck.find("warden_strike"), context.deck.find("tinker_pop_shot"), stitch.get_snapshot())
	_check(stitched.ok and not stitched.descriptors.is_empty(), "genuine public stitch transaction prerequisite")
	if not stitched.ok:
		return
	for key in ["deck", "descriptors", "remaining_scraps", "next_stitch_id"]:
		context[key] = stitched[key]
	var service := RunFrayedDebtParcel.new()
	_check(service.prepare(context, _rng()).ok, "authentic stitched source admitted")
	var offers := service.get_offers()
	_check(offers.size() == 2, "stitched source offers")
	if offers.size() == 2:
		var result := service.choose(offers[1].id, service.get_source_snapshot())
		_check(result.ok and result.deck.slice(0, context.deck.size()) == context.deck
			and result.descriptors == context.descriptors and result.next_stitch_id == context.next_stitch_id,
			"claim preserves authentic stitched ledger/cursor/order")
		result.descriptors[stitched.stitched_id].first_half.cost = 999
		_check(service.get_source_snapshot().descriptors == context.descriptors, "nested descriptors detached")
	var forged := context.duplicate(true)
	forged.descriptors[stitched.stitched_id].first_half.cost = 999
	_reject_prepare(forged, null, "counterfeit stitch half")
	forged = context.duplicate(true)
	forged.next_stitch_id = 1
	_reject_prepare(forged, null, "stitch allocator collision")
	forged = context.duplicate(true)
	forged.deck.append(stitched.stitched_id)
	_reject_prepare(forged, null, "duplicate stitched occurrence")
	forged = context.duplicate(true)
	forged.party_ids = ALTERNATE.duplicate()
	_reject_prepare(forged, null, "foreign stitch owners")


func _test_stale_and_retry() -> void:
	var context := _context()
	var service := RunFrayedDebtParcel.new()
	var rng := _rng()
	_check(service.prepare(context, rng).ok, "stale tests prepared")
	var source := service.get_source_snapshot()
	var offers := service.get_offers()
	_check(offers.size() == 2 and not source.is_empty(), "real stale-test prerequisites")
	if offers.size() != 2:
		return
	var state := rng.state
	for choice in [null, 0, {}, "forged", "frayed_debt", offers[0].id + "_plus"]:
		_check(not service.choose(choice, source).ok and not service.is_consumed(), "invalid choice preserves claim")
	var unoffered := ""
	for candidate in RunPoolCardRewardOffers.get_authored_base_candidates():
		if candidate.rarity == "uncommon" and LEGACY.has(candidate.owner) \
				and candidate.id != offers[0].id and candidate.id != offers[1].id:
			unoffered = candidate.id
			break
	_check(not unoffered.is_empty(), "genuine unoffered uncommon prerequisite")
	_check(not service.choose(unoffered, source).ok and not service.is_consumed(), "authentic unoffered card rejected")
	for key in source:
		var modified := source.duplicate(true)
		modified.erase(key)
		_check(not service.choose(offers[0].id, modified).ok, "missing snapshot " + key)
	for entry in [["deck", ["warden_strike"]], ["descriptors", {"fake": {}}],
		["remaining_scraps", 8], ["remaining_scraps", 7.0], ["next_stitch_id", 2],
		["party_ids", ALTERNATE], ["visited", true], ["receipt", "forged"]]:
		var modified := source.duplicate(true)
		modified[entry[0]] = entry[1]
		_check(not service.choose(offers[0].id, modified).ok and not service.is_consumed(), "modified source rejected " + str(entry))
	_check(rng.state == state and context == _context() and service.get_source_snapshot() == source, "all refusals preserve owner/RNG/source")
	_check(service.choose(offers[0].id, source).ok, "valid retry after refusals")
	var overflow := _context()
	overflow.remaining_scraps = 9223372036854775807
	var full := RunFrayedDebtParcel.new()
	_check(full.prepare(overflow, rng).ok, "maximum wallet can prepare reward branch")
	state = rng.state
	var full_source := full.get_source_snapshot()
	_check(not full.choose("safe_exit", full_source).ok and not full.is_consumed()
		and rng.state == state and full.get_source_snapshot() == full_source, "overflow before safe-exit award/latch")
	var full_offers := full.get_offers()
	_check(full_offers.size() == 2, "overflow retry offers")
	if full_offers.size() == 2:
		var claimed := full.choose(full_offers[0].id, full_source)
		_check(claimed.ok and claimed.remaining_scraps == 9223372036854775807, "overflow refusal preserves card claim")


## Independent first-turn oracle for a fresh fight built from `cards`: the constructor's Fisher-Yates on a
## same-seed RNG, then five draw slots in which each Frayed Debt uses its slot and is dropped.
func _first_hand_oracle(cards: Array[String], seed_value: int) -> Dictionary:
	var rng := _rng(seed_value)
	var pile: Array[String] = cards.duplicate()
	for index in range(pile.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var saved: String = pile[index]
		pile[index] = pile[other]
		pile[other] = saved
	var hand: Array[String] = []
	var exhausted := 0
	for slot in range(CombatDeck.TURN_DRAW):
		if pile.is_empty():
			break
		var card: String = pile.pop_back()
		if card == MpwFrayedDebt.CARD_ID:
			exhausted += 1
		else:
			hand.append(card)
	return {"hand": hand, "draw": pile, "exhausted": exhausted, "rng": rng.state}


## Play one real seeded fight from a run deck: turns through start_turn and draw_extra until every card has
## been drawn at least once. Returns how many curses were exhausted; the curse must never reach hand/discard.
func _fight(cards: Array[String], seed_value: int, label: String) -> int:
	var deck := CombatDeck.new(cards, _rng(seed_value))
	var oracle := _first_hand_oracle(cards, seed_value)
	_check(deck.start_turn(), label + " real first turn")
	_check(deck.hand == oracle.hand and deck.draw_pile == oracle.draw and deck.exhausted.size() == oracle.exhausted
		and deck._rng.state == oracle.rng, label + " first turn matches the seeded slot oracle")
	for turn in range(cards.size()):
		_check(not deck.hand.has(MpwFrayedDebt.CARD_ID) and not deck.discard_pile.has(MpwFrayedDebt.CARD_ID),
			label + " curse never held or discarded")
		var hand_before := deck.hand.size()
		var received := deck.draw_extra(1)
		_check(received >= 0 and deck.hand.size() == hand_before + received, label + " draw_extra reports cards received")
		_check(deck.end_turn() and deck.start_turn(), label + " real turn cycle")
	var seen: Array[String] = []
	seen.append_array(deck.draw_pile)
	seen.append_array(deck.hand)
	seen.append_array(deck.discard_pile)
	seen.append_array(deck.exhausted)
	seen.sort()
	var expected := cards.duplicate()
	expected.sort()
	_check(seen == expected, label + " every copy is conserved between circulation and exhaust")
	_check(not deck.hand.has(MpwFrayedDebt.CARD_ID) and not deck.discard_pile.has(MpwFrayedDebt.CARD_ID)
		and not deck.draw_pile.has(MpwFrayedDebt.CARD_ID), label + " curse out of circulation after the fight")
	return deck.exhausted.count(MpwFrayedDebt.CARD_ID)


## P11 integration: the actual card-plus-curse claim exhausts in the next seeded battle; safe exit does not.
func _test_battle_draws() -> void:
	for ids in [LEGACY, ALTERNATE]:
		for slot in range(3):
			var context := _context(ids)
			var before := context.duplicate(true)
			var service := RunFrayedDebtParcel.new()
			_check(service.prepare(context, _rng(358 + slot)).ok, "battle claim prepared")
			var offers := service.get_offers()
			_check(offers.size() == 2, "battle claim offers")
			if offers.size() != 2:
				continue
			var choice: String = offers[slot].id if slot < 2 else RunFrayedDebtParcel.SAFE_EXIT
			var result := service.choose(choice, service.get_source_snapshot())
			_check(result.ok, "battle claim chosen")
			if not result.ok:
				continue
			var cards: Array[String] = []
			cards.assign(result.deck)
			var ledger: Array = result.deck.duplicate()
			if slot < 2:
				_check(cards.count(choice) == before.deck.count(choice) + 1 and cards.count(MpwFrayedDebt.CARD_ID) == 1
					and result.remaining_scraps == before.remaining_scraps, "claim: chosen uncommon plus one curse, no scrap")
			else:
				_check(result.deck == before.deck and not cards.has(MpwFrayedDebt.CARD_ID)
					and result.remaining_scraps == before.remaining_scraps + 1, "safe exit: +1 scrap and no curse")
			for seed_value in [5, 358, 9001]:
				var exhausted := _fight(cards, seed_value, "%s slot %d seed %d" % [str(ids), slot, seed_value])
				_check(exhausted == (1 if slot < 2 else 0), "the next battle exhausts exactly the claimed curse")
				_check(result.deck == ledger and context == before, "battle leaves run ownership and the source untouched")
				_check(result.descriptors == before.descriptors and result.next_stitch_id == before.next_stitch_id,
					"stitched ledger and cursor exactly as the receipt requires")
			# A fresh fight from the same persistent deck exhausts again, identically.
			if slot < 2:
				_check(_fight(cards, 358, "fresh fight") == 1 and cards.count(MpwFrayedDebt.CARD_ID) == 1,
					"the removable curse stays owned and exhausts again next fight")
