extends SceneTree
## Headless test for the scene-free P7 Needle Toll transaction.
## Covers the authored record, the safe exit, the exact 7-HP paid boundary and
## same-seed rare offers, one claim/skip, and grouped fail-closed rejections.
## Exits 0 on pass and 1 on failure.

const SEED: int = 20261025

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_authored_record()
	_test_safe_exit_and_replay()
	_test_paid_boundary_and_seed_replay()
	_test_claim_and_skip()
	_test_grouped_refusals_leave_state_and_rng()
	if failures.is_empty():
		print("mpw_needle_toll_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("mpw_needle_toll_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _rng(seed_value: int = SEED) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _deck() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/starter_deck.json"))
	if not (parsed is Array):
		return []
	return (parsed as Array).duplicate()


func _party_ids() -> Array[String]:
	return ["warden", "seamstress", "tinker"]


func _hero_roster(hp_values: Array) -> Array:
	var specs: Array = [
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	]
	var heroes: Array = []
	for index in range(3):
		heroes.append({
			"id": String(specs[index]["id"]),
			"position": index + 1,
			"hp": int(hp_values[index]),
			"max_hp": int(specs[index]["max_hp"]),
			"block": 0,
			"statuses": {},
		})
	return heroes


func _context(hp_values: Array, scraps: int = 4) -> Dictionary:
	return {
		"heroes": _hero_roster(hp_values),
		"wallet": {"gold": 12, "scraps": scraps},
		"deck": _deck(),
	}


func _authored_rare_ids() -> Array[String]:
	var party: Array[String] = _party_ids()
	var ids: Array[String] = []
	for item_raw: Variant in RunPoolCardRewardOffers.get_authored_base_candidates():
		var item: Dictionary = item_raw
		if String(item.get("rarity", "")) == "rare" and party.has(String(item.get("owner", ""))):
			ids.append(String(item.get("id", "")))
	ids.sort()
	return ids


func _assert_rare_offer(offer: Dictionary) -> void:
	var card_id: String = String(offer.get("id", ""))
	var party: Array[String] = _party_ids()
	_check(not card_id.is_empty(), "offer id is non-empty")
	_check(not card_id.ends_with("_plus"), "offer is never a plus card: " + card_id)
	var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(card_id)
	_check(not definition.is_empty(), "offer id resolves to a real definition: " + card_id)
	_check(String(definition.get("id", "")) == card_id, "definition id matches offer: " + card_id)
	_check(String(definition.get("rarity", "")) == "rare", "definition is rare: " + card_id)
	_check(party.has(String(definition.get("owner", ""))), "definition owner is in the active party: " + card_id)
	_check(definition.get("reward_eligible") != false, "definition is a base card: " + card_id)
	_check(String(offer.get("owner", "")) == String(definition.get("owner", "")), "offer owner matches catalog")
	_check(String(offer.get("rarity", "")) == "rare", "offer reports rare")
	_check(_authored_rare_ids().has(card_id), "offer id is an authored rare candidate: " + card_id)


func _test_authored_record() -> void:
	var record: Dictionary = RunNeedleToll.load_authored_event()
	_check(not record.is_empty(), "shipped needle_toll record loads")
	_check(record.get("id") == "needle_toll", "authored id")
	_check(int(record.get("hp_cost", -1)) == 6, "authored hp_cost 6")
	_check(int(record.get("minimum_hp", -1)) == 7, "authored minimum_hp 7")
	_check(int(record.get("exit_scraps", -1)) == 1, "authored exit_scraps 1")
	_check(int(record.get("offer_count", -1)) == 2, "authored offer_count 2")
	_check(record.get("rarity") == "rare", "authored rarity rare")
	_check(record.get("once_per_run") == true, "authored once_per_run")
	_check(int(record.get("visit_weight", -1)) == 1, "authored relative visit_weight 1")
	_check(not String(record.get("title", "")).strip_edges().is_empty(), "presentable title")
	_check(not String(record.get("description", "")).strip_edges().is_empty(), "presentable description")
	var choice_ids: Array = []
	for choice_raw: Variant in record.get("choices", []):
		var choice: Dictionary = choice_raw
		choice_ids.append(String(choice.get("id", "")))
		_check(not String(choice.get("text", "")).strip_edges().is_empty(), "presentable choice copy")
	choice_ids.sort()
	var expected_choices: Array = [RunNeedleToll.CHOICE_PAY, RunNeedleToll.CHOICE_SAFE_EXIT]
	expected_choices.sort()
	_check(choice_ids == expected_choices, "both authored choice ids are present")
	var service := RunNeedleToll.new(_context([40, 30, 26]), _rng())
	_check(service.is_valid(), "shipped record constructs a valid open visit")
	_check(service.get_event().get("id") == "needle_toll", "event copy exposed for presentation")


func _test_safe_exit_and_replay() -> void:
	var rng: RandomNumberGenerator = _rng()
	var service := RunNeedleToll.new(_context([40, 30, 26], 4), rng)
	_check(service.is_valid() and service.is_open(), "fresh visit is open")
	var before: Dictionary = service.get_snapshot()
	var rng_before: int = rng.state
	seed(SEED)
	var expected_global: int = randi()
	seed(SEED)
	var result: Dictionary = service.take_safe_exit()
	_check(result.get("ok") == true, "safe exit succeeds")
	_check(result.get("branch") == "safe_exit", "safe exit branch")
	_check(int(result["wallet"]["scraps"]) == 5, "safe exit grants exactly 1 scrap")
	_check(int(result["wallet"]["scraps"]) - int(before["wallet"]["scraps"]) == 1, "exact scrap delta")
	_check(int(result["wallet"]["gold"]) == 12, "safe exit preserves gold")
	_check(result["heroes"] == before["heroes"], "safe exit preserves every hero")
	_check(result["deck"] == before["deck"], "safe exit preserves the shared deck")
	_check(result.get("offers", []).is_empty() and result.get("offered_ids", []).is_empty(),
			"safe exit presents no card offers")
	_check(randi() == expected_global and rng.state == rng_before, "safe exit draws no RNG")
	_check(service.is_claimed() and not service.is_valid(), "safe exit latches the visit")
	var after: Dictionary = service.get_snapshot()
	var replay: Dictionary = service.take_safe_exit()
	_check(replay.get("ok") == false, "safe exit cannot be claimed again")
	_check(int(service.get_snapshot()["wallet"]["scraps"]) == 5, "replayed exit adds no second scrap")
	_check(service.pay_toll("warden").get("ok") == false, "paid branch is closed after a safe exit")
	_check(service.claim_card("warden_bastion_quilt").get("ok") == false, "claim is closed after safe exit")
	_check(service.get_snapshot() == after and rng.state == rng_before,
			"replay and cross-branch calls change nothing")


func _test_paid_boundary_and_seed_replay() -> void:
	var rng: RandomNumberGenerator = _rng(SEED)
	var service := RunNeedleToll.new(_context([7, 0, 0], 4), rng)
	_check(service.is_valid() and service.is_open(), "paid fixture is a valid open visit")
	_check(service.get_eligible_hero_ids() == ["warden"],
			"only the living 7-HP hero is woundable")
	var before: Dictionary = service.get_snapshot()
	var rng_before: int = rng.state
	var result: Dictionary = service.pay_toll("warden")
	_check(result.get("ok") == true, "paid branch succeeds at the 7-HP boundary")
	_check(result.get("branch") == "paid" and result.get("wounded_hero_id") == "warden", "paid receipt identity")
	_check(int(result.get("hp_cost", 0)) == 6, "paid receipt reports exactly 6 HP")
	var heroes_after: Array = result["heroes"]
	_check(int(heroes_after[0]["hp"]) == 1, "7 HP becomes exactly 1 current HP (never torn)")
	_check(heroes_after[1] == before["heroes"][1] and heroes_after[2] == before["heroes"][2],
			"other heroes keep all their state")
	_check(int(heroes_after[0]["max_hp"]) == int(before["heroes"][0]["max_hp"]), "max HP is unchanged")
	_check(result["wallet"] == before["wallet"], "paid branch does not touch the wallet")
	_check(result["deck"] == before["deck"], "paid branch does not touch the deck")
	_check(service.get_source_snapshot()["heroes"] == before["heroes"],
			"caller-owned source snapshot is never mutated")
	_check(rng.state != rng_before, "paid branch advances the caller's run RNG")
	var offers: Array = result.get("offers", [])
	_check(offers.size() == 2, "paid branch offers exactly two cards")
	var distinct: Dictionary = {}
	for offer_raw: Variant in offers:
		_check(offer_raw is Dictionary, "offer is a Dictionary")
		var offer: Dictionary = offer_raw
		_assert_rare_offer(offer)
		var card_id: String = String(offer.get("id", ""))
		_check(not distinct.has(card_id), "offers are distinct: " + card_id)
		distinct[card_id] = true
	_check(distinct.size() == 2, "two distinct rare offers")
	_check(service.is_paid() and service.get_offered_ids() == result["offered_ids"], "paid stage is staged")
	var paid_snapshot: Dictionary = service.get_snapshot()
	var paid_rng_state: int = rng.state
	_check(service.take_safe_exit().get("ok") == false, "safe exit is closed after payment")
	_check(service.get_snapshot() == paid_snapshot and rng.state == paid_rng_state,
			"cross-branch safe exit changes nothing after payment")

	# Same seed and context replay the exact same offers, wound and receipt.
	var replay_service := RunNeedleToll.new(_context([7, 0, 0], 4), _rng(SEED))
	var replay: Dictionary = replay_service.pay_toll("warden")
	_check(replay.get("ok") == true, "same-seed paid branch succeeds")
	_check(replay.get("offered_ids") == result.get("offered_ids"), "same-seed replay offers the same two IDs")
	_check(replay.get("offers") == result.get("offers"), "same-seed replay offers the same owner/rarity records")
	_check(replay.get("heroes") == result.get("heroes"), "same-seed replay applies the same wound")
	_check(replay.get("receipt") == result.get("receipt"), "same-seed replay produces the same receipt")


func _test_claim_and_skip() -> void:
	var service := RunNeedleToll.new(_context([7, 0, 0]), _rng())
	var paid: Dictionary = service.pay_toll("warden")
	_check(paid.get("ok") == true, "claim fixture paid")
	var offered_ids: Array = paid.get("offered_ids", [])
	_check(offered_ids.size() == 2, "claim fixture has two offers")
	var chosen: String = String(offered_ids[0])
	var expected_deck: Array = paid["deck"].duplicate()
	expected_deck.append(chosen)
	var claim: Dictionary = service.claim_card(chosen)
	_check(claim.get("ok") == true, "claiming an offered card succeeds")
	_check(claim.get("claimed_card_id") == chosen, "claim identifies the selected card")
	_check(claim.get("deck") == expected_deck, "claim adds exactly that card once to the shared deck")
	_check(claim.get("heroes") == paid["heroes"], "claim keeps the paid wound")
	_check(claim.get("wallet") == paid["wallet"], "claim does not touch the wallet")
	_check(claim.get("skipped") == false, "claim is not a skip")
	_check(service.is_claimed(), "claim latches the visit")
	var after_claim: Dictionary = service.get_snapshot()
	_check(service.claim_card(chosen).get("ok") == false, "repeated claim is refused")
	_check(service.skip_cards().get("ok") == false, "skip after a claim is refused")
	_check(service.get_snapshot() == after_claim, "repeated claim changes nothing")

	var skip_service := RunNeedleToll.new(_context([7, 0, 0]), _rng())
	var skip_paid: Dictionary = skip_service.pay_toll("warden")
	_check(skip_paid.get("ok") == true, "skip fixture paid")
	var skip: Dictionary = skip_service.skip_cards()
	_check(skip.get("ok") == true and skip.get("skipped") == true, "skipping a paid offer succeeds")
	_check(skip.get("deck") == skip_paid["deck"], "skip adds no card")
	_check(skip.get("heroes") == skip_paid["heroes"], "skip keeps the paid wound")
	_check(skip.get("claimed_card_id") == "", "skip identifies no card")
	_check(skip_service.is_claimed(), "skip latches the visit")
	_check(skip_service.claim_card(skip_paid["offered_ids"][0]).get("ok") == false,
			"claim after a skip is refused")


func _rare_id_not_offered(offered_ids: Array) -> String:
	var party: Array[String] = _party_ids()
	for item_raw: Variant in RunPoolCardRewardOffers.get_authored_base_candidates():
		var item: Dictionary = item_raw
		if String(item.get("rarity", "")) != "rare" or not party.has(String(item.get("owner", ""))):
			continue
		var card_id: String = String(item.get("id", ""))
		if not offered_ids.has(card_id):
			return card_id
	return "counterfeit_card"


func _test_grouped_refusals_leave_state_and_rng() -> void:
	# Missing RNG, malformed context and a malformed authored record never construct.
	_check(not RunNeedleToll.new(_context([40, 30, 26]), null).is_valid(), "missing RNG is refused")
	_check(not RunNeedleToll.new(null, _rng()).is_valid(), "null context is refused")
	_check(not RunNeedleToll.new({"heroes": [], "wallet": {"gold": 0, "scraps": 0}, "deck": []},
			_rng()).is_valid(), "empty roster context is refused")
	var missing_wallet: Dictionary = {"heroes": _hero_roster([40, 30, 26]), "deck": _deck()}
	_check(not RunNeedleToll.new(missing_wallet, _rng()).is_valid(), "missing wallet context is refused")
	var bad_wallet: Dictionary = _context([40, 30, 26])
	bad_wallet["wallet"] = {"gold": 0, "scraps": -1}
	_check(not RunNeedleToll.new(bad_wallet, _rng()).is_valid(), "negative scraps context is refused")
	var bad_deck: Dictionary = _context([40, 30, 26])
	bad_deck["deck"] = ["warden_strike", 7]
	_check(not RunNeedleToll.new(bad_deck, _rng()).is_valid(), "malformed deck context is refused")
	_check(not RunNeedleToll.new(_context([40, 30, 26]), _rng(), {"id": "needle_toll"}).is_valid(),
			"incomplete authored record is refused")

	# Illegal heroes are refused before any reward draw; rejections never latch.
	var rng: RandomNumberGenerator = _rng()
	var service := RunNeedleToll.new(_context([6, 0, 26]), rng)
	_check(service.is_valid() and service.is_open(), "refusal fixture is a valid open visit")
	var before: Dictionary = service.get_snapshot()
	var rng_before: int = rng.state
	seed(SEED)
	var expected_global: int = randi()
	seed(SEED)
	_check(service.pay_toll("nobody").get("ok") == false, "unknown hero is refused")
	_check(service.pay_toll("seamstress").get("ok") == false, "downed hero is refused")
	_check(service.pay_toll("warden").get("ok") == false, "hero below 7 current HP is refused")
	_check(service.pay_toll(7).get("ok") == false, "non-string hero id is refused")
	_check(service.pay_toll("").get("ok") == false, "blank hero id is refused")
	_check(service.get_snapshot() == before, "illegal hero attempts change no hero/wallet/deck")
	_check(rng.state == rng_before and randi() == expected_global, "illegal hero attempts draw no RNG")
	_check(service.claim_card("warden_bastion_quilt").get("ok") == false, "claim is closed before payment")
	_check(service.skip_cards().get("ok") == false, "skip is closed before payment")
	_check(service.get_snapshot() == before and rng.state == rng_before,
			"pre-payment claim/skip change nothing")
	_check(service.is_open() and service.pay_toll("tinker").get("ok") == true,
			"refused attempts leave the visit usable for a legal hero")

	# A stale or counterfeit card ID is refused without consuming the paid offer.
	var stale_rng: RandomNumberGenerator = _rng()
	var paid_service := RunNeedleToll.new(_context([7, 0, 0]), stale_rng)
	var paid: Dictionary = paid_service.pay_toll("warden")
	_check(paid.get("ok") == true, "stale fixture paid")
	var stale_before: Dictionary = paid_service.get_snapshot()
	var stale_rng_before: int = stale_rng.state
	var not_offered: String = _rare_id_not_offered(paid["offered_ids"])
	_check(not_offered != "counterfeit_card", "a real unoffered rare exists for the stale case")
	_check(paid_service.claim_card(not_offered).get("ok") == false, "real but unoffered card is refused")
	_check(paid_service.claim_card("counterfeit_card").get("ok") == false, "counterfeit card is refused")
	_check(paid_service.claim_card(7).get("ok") == false, "non-string card id is refused")
	_check(paid_service.get_snapshot() == stale_before and stale_rng.state == stale_rng_before,
			"stale claim changes no hero/wallet/deck and draws no RNG")
	_check(paid_service.is_paid(), "stale claim does not latch the paid visit")

	# A used visit, including cross-branch calls, refuses everything without change.
	var used_rng: RandomNumberGenerator = _rng()
	var used := RunNeedleToll.new(_context([40, 30, 26]), used_rng)
	_check(used.take_safe_exit().get("ok") == true, "used fixture exits safely")
	var used_after: Dictionary = used.get_snapshot()
	var used_rng_after: int = used_rng.state
	seed(SEED)
	var used_global: int = randi()
	seed(SEED)
	_check(used.take_safe_exit().get("ok") == false, "used safe exit is refused")
	_check(used.pay_toll("warden").get("ok") == false, "used paid branch is refused")
	_check(used.claim_card("warden_bastion_quilt").get("ok") == false, "used claim is refused")
	_check(used.skip_cards().get("ok") == false, "used skip is refused")
	_check(used.get_snapshot() == used_after and used_rng.state == used_rng_after and randi() == used_global,
			"used-visit refusals change no state and draw no RNG")
