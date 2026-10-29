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
	_test_v3_debt_redemption_authored_and_forecasts()
	_test_v3_debt_redemption_cut_debt_and_stitches()
	_test_v3_debt_redemption_wallet_leave_and_replay()
	_test_v3_debt_redemption_refusals_and_invariants()
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


## Builds a real 6-key Unsewing Booth snapshot by preparing RunFrayedDebtParcel
## from an admitted three-hero party and claiming either an uncommon offer or safe_exit.
func _prepare_booth_snapshot(
		ids: Array = LEGACY,
		offer_slot: int = 0,
		gold: int = 40,
		scraps: int = 5,
		prior_removals: int = 2,
		seed_value: int = 352,
		pre_stitch: bool = false) -> Dictionary:
	var context := _context(ids)
	if pre_stitch:
		var first_idx: int = context.deck.find("warden_strike")
		var second_idx: int = context.deck.find("tinker_pop_shot")
		if first_idx < 0 or second_idx < 0:
			first_idx = 0
			second_idx = context.deck.size() - 1
		var stitch_service := RunRestStitchCards.new(context.deck, {}, 7, 1)
		var stitched := stitch_service.choose_stitch(first_idx, second_idx, stitch_service.get_snapshot())
		_check(stitched.ok and not stitched.descriptors.is_empty(), "booth prerequisite stitch succeeds")
		for key in ["deck", "descriptors", "remaining_scraps", "next_stitch_id"]:
			context[key] = stitched[key]
	var parcel := RunFrayedDebtParcel.new()
	var prep := parcel.prepare(context, _rng(seed_value))
	_check(prep.ok and parcel.is_valid(), "booth prerequisite parcel prepared")
	var offers := parcel.get_offers()
	_check(offers.size() == 2, "booth prerequisite parcel offers")
	var parcel_choice: String = RunFrayedDebtParcel.SAFE_EXIT
	if offer_slot >= 0 and offer_slot < offers.size():
		parcel_choice = String(offers[offer_slot].id)
	var claimed := parcel.choose(parcel_choice, parcel.get_source_snapshot())
	_check(claimed.ok and parcel.is_consumed(), "booth prerequisite parcel claimed")
	var deck_ids: Array[String] = []
	deck_ids.assign(claimed.deck)
	return {
		"snapshot": {
			"deck": deck_ids,
			"descriptors": (claimed.descriptors as Dictionary).duplicate(true),
			"next_stitch_id": int(claimed.next_stitch_id),
			"gold": gold,
			"scraps": scraps,
			"prior_removals": prior_removals,
		},
		"parcel_choice": parcel_choice,
		"offers": offers,
	}


func _choices_by_id(choices: Array) -> Dictionary:
	var mapped: Dictionary = {}
	for entry: Variant in choices:
		if entry is Dictionary:
			var d: Dictionary = entry
			var key: String = String(d.get("id", d.get("choice_id", "")))
			if not key.is_empty():
				mapped[key] = d
	return mapped


## AC1: Shipped JSON contract and read-only affordability forecast across cursed,
## stitched, no-curse, low-gold, and low-scrap openings without source/RNG mutation.
func _test_v3_debt_redemption_authored_and_forecasts() -> void:
	var file := FileAccess.open(RunV3DebtRedemptionEvent.EVENT_PATH, FileAccess.READ)
	_check(file != null, "V3-4 debt redemption shipped JSON exists")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Dictionary, "V3-4 debt redemption JSON parses as Dictionary")
	if not (parsed is Dictionary):
		return
	var raw_event: Dictionary = parsed
	var loaded := RunV3DebtRedemptionEvent.load_authored_event()
	_check(raw_event == loaded and not loaded.is_empty(), "load_authored_event matches shipped JSON")
	_check(
		raw_event.get("id") == "v3_frayed_debt_redemption"
		and raw_event.get("title") == "The Unsewing Booth"
		and typeof(raw_event.get("description")) == TYPE_STRING
		and String(raw_event["description"]).contains("button-eyed clerk")
		and String(raw_event["description"]).contains("unpicking a loaned crimson seam"),
		"V3-4 debt redemption event identity, title and clerk description"
	)
	_check(raw_event.get("choices") is Array and (raw_event["choices"] as Array).size() == 3,
		"local three-choice contract on v3_frayed_debt_redemption")
	var authored_by_id := _choices_by_id(raw_event.get("choices", []))
	_check(
		authored_by_id.size() == 3
		and authored_by_id.has("cut_debt")
		and authored_by_id.has("sell_offcuts")
		and authored_by_id.has("leave"),
		"all three required choice IDs present by ID"
	)
	if authored_by_id.size() != 3:
		return
	var cut_spec: Dictionary = authored_by_id["cut_debt"]
	var sell_spec: Dictionary = authored_by_id["sell_offcuts"]
	var leave_spec: Dictionary = authored_by_id["leave"]
	_check(
		cut_spec.get("text") == "Pay 18 gold to unpick one Frayed Debt"
		and cut_spec.get("effect_kind") == "remove_curse"
		and cut_spec.get("card_id") == MpwFrayedDebt.CARD_ID
		and int(cut_spec.get("gold", 0)) == -18
		and int(cut_spec.get("scraps", -1)) == 0,
		"cut_debt authored text, remove_curse kind, frayed_debt card_id and -18/0 signed values"
	)
	_check(
		sell_spec.get("text") == "Sell two scrap bundles for 20 gold"
		and sell_spec.get("effect_kind") == "wallet"
		and not sell_spec.has("card_id")
		and int(sell_spec.get("gold", 0)) == 20
		and int(sell_spec.get("scraps", 0)) == -2,
		"sell_offcuts authored text, wallet kind and +20/-2 signed values"
	)
	_check(
		leave_spec.get("text") == "Leave the ledger sealed"
		and leave_spec.get("effect_kind") == "none"
		and not leave_spec.has("card_id")
		and int(leave_spec.get("gold", -1)) == 0
		and int(leave_spec.get("scraps", -1)) == 0,
		"leave authored text, none kind and 0/0 signed values"
	)

	# Funded stitched + parcel-cursed ledger forecast.
	var built := _prepare_booth_snapshot(LEGACY, 0, 18, 2, 3, 401, true)
	var snapshot: Dictionary = built["snapshot"]
	var before := snapshot.duplicate(true)
	var curse_idx: int = (snapshot["deck"] as Array).find(MpwFrayedDebt.CARD_ID)
	_check(curse_idx >= 0 and (snapshot["deck"] as Array).count(MpwFrayedDebt.CARD_ID) == 1
		and not (snapshot["descriptors"] as Dictionary).is_empty(), "cursed stitched fixture ready")

	var rng := _rng(777)
	var rng_state := rng.state
	var service := RunV3DebtRedemptionEvent.new(snapshot)
	_check(service.is_valid() and service.is_prepared() and not service.is_consumed() and not service.is_claimed(),
		"booth service prepared and unclaimed")
	var preview := service.preview_choices()
	_check(preview.get("ok", false) and preview.get("event_id") == "v3_frayed_debt_redemption"
		and preview.get("title") == "The Unsewing Booth"
		and (preview.get("choices", []) as Array).size() == 3, "preview_choices returns all three forecasts")
	var by_id: Dictionary = preview.get("by_id", {})
	var expected_cut_deck: Array = (before["deck"] as Array).duplicate()
	expected_cut_deck.remove_at(curse_idx)
	_check(
		by_id["cut_debt"]["affordable"] == true
		and by_id["cut_debt"]["denied"] == false
		and by_id["cut_debt"]["status"] == "affordable"
		and by_id["cut_debt"]["removed_index"] == curse_idx
		and by_id["cut_debt"]["removed_card_id"] == MpwFrayedDebt.CARD_ID
		and by_id["cut_debt"]["deck"] == expected_cut_deck
		and by_id["cut_debt"]["descriptors"] == before["descriptors"]
		and by_id["cut_debt"]["next_stitch_id"] == before["next_stitch_id"]
		and by_id["cut_debt"]["gold"] == 0
		and by_id["cut_debt"]["scraps"] == 2
		and by_id["cut_debt"]["prior_removals"] == 3,
		"cut_debt forecast quotes -18 gold, first-curse removal, and unchanged descriptors/cursor/prior_removals"
	)
	_check(
		by_id["sell_offcuts"]["affordable"] == true
		and by_id["sell_offcuts"]["denied"] == false
		and by_id["sell_offcuts"]["status"] == "affordable"
		and by_id["sell_offcuts"]["removed_index"] == -1
		and by_id["sell_offcuts"]["deck"] == before["deck"]
		and by_id["sell_offcuts"]["descriptors"] == before["descriptors"]
		and by_id["sell_offcuts"]["next_stitch_id"] == before["next_stitch_id"]
		and by_id["sell_offcuts"]["gold"] == 38
		and by_id["sell_offcuts"]["scraps"] == 0
		and by_id["sell_offcuts"]["prior_removals"] == 3,
		"sell_offcuts forecast quotes +20 gold, -2 scraps, and untouched deck/descriptors"
	)
	_check(
		by_id["leave"]["affordable"] == true
		and by_id["leave"]["denied"] == false
		and by_id["leave"]["status"] == "affordable"
		and by_id["leave"]["snapshot"] == before,
		"leave forecast quotes unchanged state"
	)
	for cid in ["cut_debt", "sell_offcuts", "leave"]:
		var single := service.preview_choice(cid)
		var expected_single: Dictionary = (by_id[cid] as Dictionary).duplicate(true)
		expected_single["ok"] = true
		_check(single == expected_single, "preview_choice(" + cid + ") matches by_id entry")

	# Mutating preview output or caller input never alters service state.
	(preview["choices"] as Array).clear()
	(by_id["cut_debt"]["deck"] as Array).clear()
	(snapshot["deck"] as Array).clear()
	_check(service.get_source_snapshot() == before and service.get_current_snapshot() == before
		and service.is_valid() and not service.is_consumed() and rng.state == rng_state,
		"preview and caller mutations leave service state and RNG untouched")

	# Valid opening with NO curse (from Parcel safe_exit): cut_debt denied, sell_offcuts & leave legal.
	var no_curse_built := _prepare_booth_snapshot(ALTERNATE, 2, 30, 2, 1, 402, false)
	var no_curse_snap: Dictionary = no_curse_built["snapshot"]
	_check(not (no_curse_snap["deck"] as Array).has(MpwFrayedDebt.CARD_ID), "safe_exit deck has no curse")
	var no_curse_visit := RunV3DebtRedemptionEvent.new(no_curse_snap)
	var no_curse_preview := no_curse_visit.preview_choices()
	_check(
		no_curse_visit.is_valid()
		and no_curse_preview.get("ok", false)
		and no_curse_preview["by_id"]["cut_debt"]["affordable"] == false
		and no_curse_preview["by_id"]["cut_debt"]["denied"] == true
		and no_curse_preview["by_id"]["cut_debt"]["status"] == "denied"
		and no_curse_preview["by_id"]["cut_debt"]["reason"] == "missing_curse"
		and no_curse_preview["by_id"]["cut_debt"]["snapshot"] == no_curse_snap
		and no_curse_preview["by_id"]["sell_offcuts"]["affordable"] == true
		and no_curse_preview["by_id"]["leave"]["affordable"] == true,
		"no-curse opening denies cut_debt while keeping sell_offcuts and leave legal"
	)

	# 17 gold with curse and 2 scraps: cut_debt denied; 1 scrap with curse and 18 gold: sell_offcuts denied.
	var low_gold_snap := before.duplicate(true)
	low_gold_snap["gold"] = 17
	var low_gold_preview := RunV3DebtRedemptionEvent.new(low_gold_snap).preview_choices()
	_check(
		low_gold_preview["by_id"]["cut_debt"]["affordable"] == false
		and low_gold_preview["by_id"]["cut_debt"]["reason"] == "insufficient_gold"
		and low_gold_preview["by_id"]["cut_debt"]["snapshot"] == low_gold_snap
		and low_gold_preview["by_id"]["sell_offcuts"]["affordable"] == true
		and low_gold_preview["by_id"]["leave"]["affordable"] == true,
		"17 gold denies cut_debt without mutating projected snapshot"
	)
	var low_scrap_snap := before.duplicate(true)
	low_scrap_snap["scraps"] = 1
	var low_scrap_preview := RunV3DebtRedemptionEvent.new(low_scrap_snap).preview_choices()
	_check(
		low_scrap_preview["by_id"]["cut_debt"]["affordable"] == true
		and low_scrap_preview["by_id"]["sell_offcuts"]["affordable"] == false
		and low_scrap_preview["by_id"]["sell_offcuts"]["reason"] == "insufficient_scraps"
		and low_scrap_preview["by_id"]["sell_offcuts"]["snapshot"] == low_scrap_snap
		and low_scrap_preview["by_id"]["leave"]["affordable"] == true,
		"1 scrap denies sell_offcuts while keeping cut_debt and leave affordable"
	)


## AC2: Choosing cut_debt removes only the first authentic Frayed Debt copy,
## charges 18 gold (not Unpicker's 75+25*prior_removals), and preserves all other
## deck occurrences, scraps, stitched descriptors, allocator cursor, and prior_removals.
func _test_v3_debt_redemption_cut_debt_and_stitches() -> void:
	# Single-curse stitched + parcel-earned deck at exact 18-gold boundary and high prior_removals.
	var built := _prepare_booth_snapshot(LEGACY, 1, 18, 4, 5, 512, true)
	var snapshot: Dictionary = built["snapshot"]
	var before := snapshot.duplicate(true)
	var rng := _rng(512)
	var rng_state := rng.state
	var service := RunV3DebtRedemptionEvent.new()
	var prep := service.prepare(snapshot)
	_check(prep.ok and service.is_valid() and not service.is_consumed(), "cut_debt stitched visit prepared")

	var curse_index: int = (before["deck"] as Array).find(MpwFrayedDebt.CARD_ID)
	var expected_deck: Array[String] = []
	expected_deck.assign(before["deck"])
	expected_deck.remove_at(curse_index)

	var receipt := service.choose(RunV3DebtRedemptionEvent.CHOICE_CUT_DEBT, before)
	_check(
		receipt.get("ok", false)
		and receipt.get("consumed", false)
		and receipt.get("claimed", false)
		and service.is_consumed()
		and not service.is_valid()
		and receipt.get("event_id") == "v3_frayed_debt_redemption"
		and receipt.get("choice_id") == "cut_debt"
		and receipt.get("effect_kind") == "remove_curse"
		and receipt.get("removed_index") == curse_index
		and receipt.get("removed_card_id") == MpwFrayedDebt.CARD_ID
		and receipt.get("gold_delta") == -18
		and receipt.get("scraps_delta") == 0,
		"cut_debt settles once with explicit removal receipt"
	)
	_check(
		receipt["deck"] == expected_deck
		and not (receipt["deck"] as Array).has(MpwFrayedDebt.CARD_ID)
		and receipt["descriptors"] == before["descriptors"]
		and receipt["next_stitch_id"] == before["next_stitch_id"]
		and receipt["gold"] == 0
		and receipt["scraps"] == 4
		and receipt["prior_removals"] == 5
		and receipt["source_snapshot"] == before
		and snapshot == before
		and rng.state == rng_state
		and not String(receipt.get("receipt", "")).is_empty(),
		"cut_debt charges 18 gold and leaves scraps, stitched descriptors, cursor, prior_removals, source and RNG unchanged"
	)
	# Next battle with the cleansed deck exhausts 0 curses.
	var cleansed_cards: Array[String] = []
	cleansed_cards.assign(receipt["deck"])
	_check(_fight(cleansed_cards, 512, "cleansed booth deck") == 0,
		"cleansed deck no longer draws or exhausts Frayed Debt in combat")

	# Two-curse deck: prepare a second authentic curse via a second RunFrayedDebtParcel visit
	# and place the two curses at distinct non-adjacent positions to prove first-match-only removal.
	var second_parcel := RunFrayedDebtParcel.new()
	_check(second_parcel.prepare(_context(LEGACY), _rng(613)).ok, "second parcel prepared for duplicate-curse fixture")
	var second_offers := second_parcel.get_offers()
	var second_claim := second_parcel.choose(second_offers[0].id, second_parcel.get_source_snapshot())
	_check(second_claim.ok and (second_claim.deck as Array).count(MpwFrayedDebt.CARD_ID) == 1,
		"second parcel yields authentic uncommon plus Frayed Debt")

	var two_curse_deck: Array[String] = []
	two_curse_deck.assign(before["deck"])
	two_curse_deck.append(String(second_offers[0].id))
	two_curse_deck.append(String((second_claim.deck as Array).back()))
	_check(two_curse_deck.count(MpwFrayedDebt.CARD_ID) == 2, "two authentic Frayed Debt copies in deck")
	var first_curse_pos := two_curse_deck.find(MpwFrayedDebt.CARD_ID)
	var second_curse_pos := two_curse_deck.rfind(MpwFrayedDebt.CARD_ID)
	_check(first_curse_pos >= 0 and second_curse_pos > first_curse_pos + 1, "two distinct non-adjacent curse indices")

	var two_curse_snap := {
		"deck": two_curse_deck.duplicate(),
		"descriptors": (before["descriptors"] as Dictionary).duplicate(true),
		"next_stitch_id": int(before["next_stitch_id"]),
		"gold": 45,
		"scraps": 3,
		"prior_removals": 2,
	}
	var two_curse_before := two_curse_snap.duplicate(true)
	var two_curse_visit := RunV3DebtRedemptionEvent.new(two_curse_snap)
	var two_curse_receipt := two_curse_visit.choose("cut_debt", two_curse_before)
	var expected_after_first: Array[String] = two_curse_deck.duplicate()
	expected_after_first.remove_at(first_curse_pos)
	_check(
		two_curse_receipt.ok
		and two_curse_receipt.removed_index == first_curse_pos
		and two_curse_receipt.deck == expected_after_first
		and (two_curse_receipt.deck as Array).count(MpwFrayedDebt.CARD_ID) == 1
		and (two_curse_receipt.deck as Array).find(MpwFrayedDebt.CARD_ID) == second_curse_pos - 1
		and two_curse_receipt.gold == 27
		and two_curse_receipt.scraps == 3
		and two_curse_receipt.prior_removals == 2
		and two_curse_receipt.descriptors == two_curse_before.descriptors
		and two_curse_receipt.next_stitch_id == two_curse_before.next_stitch_id,
		"cut_debt with two curses removes only the first matching occurrence and preserves the second copy in order"
	)

	# Standard Unpicker regression: RunShopCardRemoval still charges 75 + 25 * prior_removals and increments prior_removals.
	var shop_res := RunShopCardRemoval.try_remove_with_stitch_ledger(
		two_curse_receipt.deck,
		two_curse_receipt.descriptors,
		two_curse_receipt.next_stitch_id,
		200,
		two_curse_receipt.prior_removals,
		MpwFrayedDebt.CARD_ID
	)
	_check(
		shop_res.ok
		and shop_res.price == 75 + 25 * 2
		and shop_res.gold == 75
		and shop_res.prior_removals == 3
		and not (shop_res.deck as Array).has(MpwFrayedDebt.CARD_ID),
		"standard Unpicker removal price (75 + 25*prior_removals) and counter increment remain unchanged"
	)


## AC3: Separate fresh visits for sell_offcuts (+20 gold, -2 scraps) and leave
## (no change), including a no-curse deck, with one-claim latches, replay-stable
## detached receipts, and zero RNG consumption.
func _test_v3_debt_redemption_wallet_leave_and_replay() -> void:
	# Fresh visit for sell_offcuts on a cursed stitched deck.
	var cursed: Dictionary = _prepare_booth_snapshot(LEGACY, 0, 11, 2, 1, 701, true)["snapshot"]
	var cursed_before: Dictionary = cursed.duplicate(true)
	var rng := _rng(701)
	var rng_state := rng.state
	var trade_visit := RunV3DebtRedemptionEvent.new(cursed)
	var trade_receipt := trade_visit.choose(RunV3DebtRedemptionEvent.CHOICE_SELL_OFFCUTS, cursed_before)
	_check(
		trade_receipt.ok
		and trade_visit.is_consumed()
		and not trade_visit.is_valid()
		and trade_receipt.choice_id == "sell_offcuts"
		and trade_receipt.effect_kind == "wallet"
		and trade_receipt.removed_index == -1
		and trade_receipt.removed_card_id == ""
		and trade_receipt.gold_delta == 20
		and trade_receipt.scraps_delta == -2
		and trade_receipt.gold == 31
		and trade_receipt.scraps == 0
		and trade_receipt.prior_removals == 1
		and trade_receipt.deck == cursed_before.deck
		and trade_receipt.descriptors == cursed_before.descriptors
		and trade_receipt.next_stitch_id == cursed_before.next_stitch_id
		and cursed == cursed_before
		and rng.state == rng_state,
		"sell_offcuts exchanges 2 scraps for 20 gold and leaves deck, curse, descriptors, cursor and RNG untouched"
	)

	# Fresh visit for sell_offcuts on a valid deck with NO curse.
	var no_curse: Dictionary = _prepare_booth_snapshot(ALTERNATE, 2, 5, 4, 0, 702, false)["snapshot"]
	var no_curse_before: Dictionary = no_curse.duplicate(true)
	var no_curse_trade := RunV3DebtRedemptionEvent.new(no_curse)
	var no_curse_trade_receipt := no_curse_trade.choose("sell_offcuts", no_curse_before)
	_check(
		no_curse_trade_receipt.ok
		and no_curse_trade.is_consumed()
		and no_curse_trade_receipt.gold == 25
		and no_curse_trade_receipt.scraps == 2
		and no_curse_trade_receipt.deck == no_curse_before.deck
		and no_curse == no_curse_before,
		"sell_offcuts succeeds on a fresh visit even when deck contains no Frayed Debt"
	)

	# Fresh visits for leave (both with curse and without curse, including empty wallet 0 gold / 0 scraps).
	for base_snap in [cursed_before, no_curse_before]:
		var empty_wallet: Dictionary = base_snap.duplicate(true)
		empty_wallet["gold"] = 0
		empty_wallet["scraps"] = 0
		var leave_before: Dictionary = empty_wallet.duplicate(true)
		var leave_visit := RunV3DebtRedemptionEvent.new(empty_wallet)
		var leave_receipt := leave_visit.choose(RunV3DebtRedemptionEvent.CHOICE_LEAVE, leave_before)
		_check(
			leave_receipt.ok
			and leave_visit.is_consumed()
			and not leave_visit.is_valid()
			and leave_receipt.choice_id == "leave"
			and leave_receipt.effect_kind == "none"
			and leave_receipt.snapshot == leave_before
			and leave_receipt.source_snapshot == leave_before
			and empty_wallet == leave_before
			and rng.state == rng_state,
			"leave claims once with zero state change and zero RNG use"
		)

	# Deterministic replay: identical inputs produce identical receipts and hashes across all three choices.
	var replay_source: Dictionary = _prepare_booth_snapshot(LEGACY, 0, 25, 3, 2, 703, true)["snapshot"]
	for choice_id in ["cut_debt", "sell_offcuts", "leave"]:
		var first_service := RunV3DebtRedemptionEvent.new(replay_source)
		var second_service := RunV3DebtRedemptionEvent.new(replay_source.duplicate(true))
		_check(first_service.preview_choices() == second_service.preview_choices(),
			"deterministic forecast replay for " + choice_id)
		var first_res := first_service.choose(choice_id, replay_source)
		var second_res := second_service.choose(choice_id, replay_source)
		_check(first_res.ok and first_res == second_res and not String(first_res.receipt).is_empty(),
			"identical receipts and hashes on same inputs for " + choice_id)
		# Mutate first_res thoroughly and verify first_service stays intact.
		(first_res["deck"] as Array).clear()
		(first_res["descriptors"] as Dictionary)["forged"] = {}
		(first_res["snapshot"] as Dictionary).clear()
		(first_res["source_snapshot"] as Dictionary).clear()
		_check(
			first_service.get_source_snapshot() == second_service.get_source_snapshot()
			and first_service.get_current_snapshot() == second_service.get_current_snapshot(),
			"mutating returned receipt never modifies service snapshots for " + choice_id
		)


## AC4: Refusals for missing curse, 17 gold, 1 scrap, overflow, malformed ledgers,
## altered event/price/effect/card_id, forged curse catalog, stale expected snapshot,
## unknown choice, and double-commit leave source, unclaimed visits, and RNG intact.
func _test_v3_debt_redemption_refusals_and_invariants() -> void:
	var base: Dictionary = _prepare_booth_snapshot(LEGACY, 0, 25, 3, 1, 801, true)["snapshot"]
	var rng := _rng(801)
	var rng_state := rng.state

	# 1. Missing curse on cut_debt: refuses without latching, then sell_offcuts succeeds on the same visit.
	var no_curse: Dictionary = _prepare_booth_snapshot(LEGACY, 2, 50, 2, 1, 802, true)["snapshot"]
	var no_curse_before: Dictionary = no_curse.duplicate(true)
	var no_curse_visit := RunV3DebtRedemptionEvent.new(no_curse)
	var denied_cut := no_curse_visit.choose("cut_debt", no_curse_before)
	_check(
		not denied_cut.ok
		and not denied_cut.consumed
		and no_curse_visit.is_valid()
		and not no_curse_visit.is_consumed()
		and denied_cut.snapshot == no_curse_before
		and no_curse == no_curse_before,
		"missing curse refuses cut_debt without latching or mutating state"
	)
	var recovered_trade := no_curse_visit.choose("sell_offcuts", no_curse_before)
	_check(recovered_trade.ok and no_curse_visit.is_consumed() and recovered_trade.gold == 70 and recovered_trade.scraps == 0,
		"unclaimed visit stays valid after missing-curse refusal and settles sell_offcuts")

	# 2. Insufficient gold (17 gold) on cut_debt: refuses without latching, then leave succeeds on the same visit.
	var gold_17: Dictionary = base.duplicate(true)
	gold_17["gold"] = 17
	var gold_17_before: Dictionary = gold_17.duplicate(true)
	var gold_17_visit := RunV3DebtRedemptionEvent.new(gold_17)
	var denied_gold := gold_17_visit.choose("cut_debt", gold_17_before)
	_check(
		not denied_gold.ok
		and not denied_gold.consumed
		and gold_17_visit.is_valid()
		and not gold_17_visit.is_consumed()
		and denied_gold.snapshot == gold_17_before
		and gold_17 == gold_17_before,
		"17 gold refuses cut_debt without partial debit or curse removal"
	)
	var recovered_leave := gold_17_visit.choose("leave", gold_17_before)
	_check(recovered_leave.ok and gold_17_visit.is_consumed() and recovered_leave.snapshot == gold_17_before,
		"unclaimed visit stays valid after 17-gold refusal and settles leave")

	# 3. Insufficient scraps (1 scrap) on sell_offcuts: refuses without latching, then cut_debt succeeds on the same visit.
	var scrap_1: Dictionary = base.duplicate(true)
	scrap_1["scraps"] = 1
	var scrap_1_before: Dictionary = scrap_1.duplicate(true)
	var scrap_1_visit := RunV3DebtRedemptionEvent.new(scrap_1)
	var denied_scrap := scrap_1_visit.choose("sell_offcuts", scrap_1_before)
	_check(
		not denied_scrap.ok
		and not denied_scrap.consumed
		and scrap_1_visit.is_valid()
		and not scrap_1_visit.is_consumed()
		and denied_scrap.snapshot == scrap_1_before
		and scrap_1 == scrap_1_before,
		"1 scrap refuses sell_offcuts without partial debit"
	)
	var recovered_cut := scrap_1_visit.choose("cut_debt", scrap_1_before)
	_check(recovered_cut.ok and scrap_1_visit.is_consumed() and recovered_cut.gold == 7 and recovered_cut.scraps == 1,
		"unclaimed visit stays valid after 1-scrap refusal and settles cut_debt")

	# 4. Gold overflow on sell_offcuts: refuses without latching, then cut_debt succeeds.
	var overflow_snap: Dictionary = base.duplicate(true)
	overflow_snap["gold"] = RunV3DebtRedemptionEvent.MAX_INT - 19
	var overflow_before: Dictionary = overflow_snap.duplicate(true)
	var overflow_visit := RunV3DebtRedemptionEvent.new(overflow_snap)
	_check(not overflow_visit.preview_choice("sell_offcuts").affordable, "overflow sell_offcuts denied in preview")
	var denied_overflow := overflow_visit.choose("sell_offcuts", overflow_before)
	_check(not denied_overflow.ok and overflow_visit.is_valid() and not overflow_visit.is_consumed(),
		"gold overflow refuses sell_offcuts without latching")
	_check(overflow_visit.choose("cut_debt", overflow_before).ok, "overflow visit still settles cut_debt")

	# 5. Malformed ledgers on prepare: every invalid snapshot fails closed and preserves preparation opportunity.
	var bad_snapshots: Array = [
		null,
		[],
		{},
	]
	for key in ["deck", "descriptors", "next_stitch_id", "gold", "scraps", "prior_removals"]:
		var missing: Dictionary = base.duplicate(true)
		missing.erase(key)
		bad_snapshots.append(missing)
	var extra_key: Dictionary = base.duplicate(true)
	extra_key["extra"] = true
	bad_snapshots.append(extra_key)
	for mutation in [
		["deck", []],
		["deck", ["forged_card"]],
		["deck", [123]],
		["descriptors", {"stitched_000001": {}}],
		["next_stitch_id", 0],
		["next_stitch_id", 1], # collides with owned stitched_000001 in `base`
		["next_stitch_id", 2.0],
		["next_stitch_id", RunV3DebtRedemptionEvent.MAX_INT],
		["gold", -1],
		["gold", 25.0],
		["scraps", -1],
		["scraps", 3.0],
		["prior_removals", -1],
		["prior_removals", 1.0],
	]:
		var bad: Dictionary = base.duplicate(true)
		bad[mutation[0]] = mutation[1]
		bad_snapshots.append(bad)
	var tampered_stitch: Dictionary = base.duplicate(true)
	tampered_stitch["descriptors"]["stitched_000001"]["cost"] = 99
	bad_snapshots.append(tampered_stitch)
	var four_hero_snap: Dictionary = base.duplicate(true)
	(four_hero_snap["deck"] as Array).append("lantern_monk_strike")
	bad_snapshots.append(four_hero_snap)

	for candidate in bad_snapshots:
		var candidate_before: Variant = candidate.duplicate(true) if candidate is Dictionary else (candidate.duplicate(true) if candidate is Array else candidate)
		var service := RunV3DebtRedemptionEvent.new()
		var prep := service.prepare(candidate)
		_check(
			not prep.ok
			and not service.is_valid()
			and not service.is_prepared()
			and not service.is_consumed()
			and service.get_source_snapshot().is_empty()
			and not service.preview_choices().ok
			and candidate == candidate_before,
			"malformed snapshot rejected on prepare without mutation"
		)
		_check(service.prepare(base).ok and service.is_valid(), "failed prepare leaves instance reusable for valid snapshot")

	# 6. Altered event records (effect_kind, price, card_id, choice list, identity) and forged MpwFrayedDebt definitions.
	var canonical_event := RunV3DebtRedemptionEvent.load_authored_event()
	var forged_events: Array = [
		{},
		{"id": "other_event", "title": "The Unsewing Booth", "description": canonical_event.description, "choices": canonical_event.choices.duplicate(true)},
		{"id": canonical_event.id, "title": "Wrong Title", "description": canonical_event.description, "choices": canonical_event.choices.duplicate(true)},
		{"id": canonical_event.id, "title": canonical_event.title, "description": "An empty booth.", "choices": canonical_event.choices.duplicate(true)},
	]
	for mod in [
		[0, "effect_kind", "wallet"],
		[0, "card_id", "warden_strike"],
		[0, "card_id", "stitched_000001"],
		[0, "card_id", "forged_curse"],
		[0, "gold", -17],
		[0, "gold", -75],
		[0, "gold", 0],
		[0, "scraps", -1],
		[1, "effect_kind", "remove_curse"],
		[1, "gold", 21],
		[1, "scraps", -1],
		[1, "card_id", "frayed_debt"],
		[2, "effect_kind", "wallet"],
		[2, "gold", 1],
		[2, "scraps", 1],
	]:
		var ev: Dictionary = canonical_event.duplicate(true)
		ev["choices"][mod[0]][mod[1]] = mod[2]
		forged_events.append(ev)
	var two_choices: Dictionary = canonical_event.duplicate(true)
	(two_choices["choices"] as Array).pop_back()
	forged_events.append(two_choices)

	var valid_visit := RunV3DebtRedemptionEvent.new(base)
	var base_before: Dictionary = base.duplicate(true)
	for bad_event in forged_events:
		_check(not RunV3DebtRedemptionEvent.new(base, bad_event).is_valid(), "altered event record rejected on init")
		_check(not valid_visit.preview_choices(bad_event).ok, "altered event record rejected on preview")
		var res := valid_visit.choose("cut_debt", base_before, bad_event)
		_check(not res.ok and valid_visit.is_valid() and not valid_visit.is_consumed()
			and valid_visit.get_source_snapshot() == base_before, "altered event record rejected on choose without latching")

	var canonical_curse := MpwFrayedDebt.new().get_definition(MpwFrayedDebt.CARD_ID)
	for curse_mod in [
		["id", "forged_curse"],
		["card_type", "attack"],
		["playable", true],
		["removable", false],
		["can_upgrade", true],
		["can_stitch", true],
		["reward_eligible", true],
		["starting_copies", 1],
		["exhaust_on_first_draw", false],
		["consumes_draw", false],
	]:
		var forged_curse: Dictionary = canonical_curse.duplicate(true)
		forged_curse[curse_mod[0]] = curse_mod[1]
		_check(not RunV3DebtRedemptionEvent.new(base, null, forged_curse).is_valid(),
			"forged curse definition rejected on init: " + str(curse_mod[0]))
		_check(not valid_visit.preview_choices(null, forged_curse).ok,
			"forged curse definition rejected on preview: " + str(curse_mod[0]))
		var res := valid_visit.choose("cut_debt", base_before, null, forged_curse)
		_check(not res.ok and valid_visit.is_valid() and not valid_visit.is_consumed(),
			"forged curse definition rejected on choose without latching: " + str(curse_mod[0]))

	# 7. Unrecognized choices and stale/mismatched expected_snapshot on valid_visit.
	for bad_choice in [null, 0, {}, "", "forged", "frayed_debt", "safe_exit", "remove_curse", "offer_0"]:
		var res := valid_visit.choose(bad_choice, base_before)
		_check(not res.ok and valid_visit.is_valid() and not valid_visit.is_consumed(),
			"unrecognized choice rejected without latching: " + str(bad_choice))

	_check(not valid_visit.choose("cut_debt", null).ok and valid_visit.is_valid(), "null expected_snapshot rejected")
	for key in base_before:
		var missing: Dictionary = base_before.duplicate(true)
		missing.erase(key)
		_check(not valid_visit.choose("cut_debt", missing).ok and valid_visit.is_valid(),
			"expected_snapshot missing " + str(key) + " rejected")
	for stale_mod in [
		["deck", ["warden_strike"]],
		["descriptors", {}],
		["next_stitch_id", 9],
		["gold", 24],
		["gold", 25.0],
		["scraps", 2],
		["scraps", 3.0],
		["prior_removals", 0],
		["prior_removals", 1.0],
		["extra_field", 1],
	]:
		var stale: Dictionary = base_before.duplicate(true)
		stale[stale_mod[0]] = stale_mod[1]
		_check(not valid_visit.choose("cut_debt", stale).ok and valid_visit.is_valid() and not valid_visit.is_consumed(),
			"stale expected_snapshot rejected without latching: " + str(stale_mod[0]))

	# 8. After all refusals on valid_visit, a legal cut_debt succeeds once, and double-commit / cross-branch replay fails.
	var committed := valid_visit.choose("cut_debt", base_before)
	_check(committed.ok and valid_visit.is_consumed() and not valid_visit.is_valid()
		and committed.gold == 7 and not (committed.deck as Array).has(MpwFrayedDebt.CARD_ID),
		"unclaimed visit still settles cut_debt after all negative checks")
	var committed_snapshot: Dictionary = committed.snapshot.duplicate(true)
	for replay_choice in ["cut_debt", "sell_offcuts", "leave"]:
		for replay_expected in [base_before, committed_snapshot]:
			var replay_res := valid_visit.choose(replay_choice, replay_expected)
			_check(
				not replay_res.ok
				and replay_res.consumed
				and replay_res.snapshot == committed_snapshot
				and valid_visit.get_current_snapshot() == committed_snapshot
				and valid_visit.get_source_snapshot() == base_before,
				"double-commit rejected and preserves first committed state: " + replay_choice
			)
	_check(not valid_visit.preview_choices().ok and not valid_visit.prepare(base_before).ok,
		"consumed visit rejects preview and re-prepare")
	_check(rng.state == rng_state and base == base_before, "all negative and replay checks leave RNG and caller source untouched")
