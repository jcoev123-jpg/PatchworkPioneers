extends SceneTree
## Integration of the existing three services, with independent seeded oracles.

var failures: Array[String] = []
var checks: int = 0
const MAX_INT := 9223372036854775807
const HERO_IDS := ["warden", "seamstress", "tinker"]
const TRINKET_POOL := ["thread_token", "button_charm", "spool_pendant"]
const OWNED_TRINKETS := ["button_charm"]


func _initialize() -> void:
	var definitions := _load_array("res://data/heroes/starter_party.json")
	var starting := _load_array("res://data/cards/starter_deck.json")
	var catalog := StarterCards.new()
	var ids: Array[String] = []
	var deck: Array[String] = []
	for hero in definitions:
		if hero is Dictionary and hero.get("id") is String:
			ids.append(hero["id"])
	for card in starting:
		if card is String:
			deck.append(card)
	var candidates: Array[String] = catalog.get_all_card_ids()
	_check(definitions.size() == 3 and ids == HERO_IDS, "authored Warden/Seamstress/Tinker in order")
	_check(definitions.size() == 3 and definitions[0].get("max_hp") == 40
		and definitions[1].get("max_hp") == 30
		and definitions[2].get("max_hp") == 26, "authored hero HP")
	_check(deck.size() == 12 and deck.count("warden_strike") == 2
		and deck.count("seamstress_prick") == 2 and deck.count("tinker_pop_shot") == 2,
		"one authored twelve-copy shared deck")
	for stable_id in ["warden_strike", "warden_brace", "warden_shield_bash",
			"seamstress_prick", "seamstress_mend", "seamstress_stitch_up",
			"tinker_pop_shot", "tinker_scrap_bomb", "tinker_tune_up"]:
		_check(catalog.has_card(stable_id), "known card exists: " + stable_id)
	_check(candidates.size() >= 3, "catalog can offer at least three entries")
	var valid_deck := true
	for card_id in deck:
		if not catalog.has_card(card_id) or not ids.has(catalog.get_definition(card_id).get("owner")):
			valid_deck = false
	_check(valid_deck, "each starter deck entry is catalog-valid and party-owned")
	if ids == HERO_IDS and definitions.size() == 3 and deck.size() == 12 and valid_deck and candidates.size() >= 3:
		_test_prepare(definitions, ids, deck, candidates, false, 1, [], [])
		_test_prepare(definitions, ids, deck, candidates, true, 2, TRINKET_POOL, OWNED_TRINKETS)
		_test_choices(definitions, ids, deck, candidates)
		_test_weighted_records(definitions, ids, deck)
		_test_weighted_two_survivors(definitions, ids, deck, false)
		_test_weighted_two_survivors(definitions, ids, deck, true)
		_test_weighted_two_survivors_ws(definitions, ids, deck)
		_test_weighted_one_survivor(definitions, ids, deck, false)
		_test_weighted_one_survivor(definitions, ids, deck, true)
		_test_weighted_one_survivor_warden(definitions, ids, deck)
		_test_stitched_rewards(definitions, ids, deck)
		_test_rejections(definitions, ids, deck, candidates)
	else:
		_check(false, "reward suite cannot run vacuously without valid authored fixtures")
	if failures.is_empty():
		print("run_fight_victory_rewards_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_fight_victory_rewards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)


func _load_array(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	_check(f != null, "load " + path)
	if f == null:
		return []
	var decoded = JSON.parse_string(f.get_as_text())
	f.close()
	_check(decoded is Array, path + " contains an array")
	return decoded if decoded is Array else []


func _rng(seed_value: int = 771234) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _fight(definitions: Array, enemy_count: int = 1) -> Dictionary:
	# JSON.parse_string supplies 40.0, 30.0, 26.0; CombatParty's
	# authoritative constructor correctly requires integral int HP.
	var heroes: Array = []
	for authored in definitions:
		var hero: Dictionary = authored.duplicate(true)
		hero["max_hp"] = int(hero["max_hp"])
		heroes.append(hero)
	var party := CombatParty.new(heroes)
	var enemies_def: Array = [{"id": "ragling_probe", "max_hp": 8}]
	if enemy_count == 2:
		enemies_def.append({"id": "scrap_probe", "max_hp": 11})
	var enemies := CombatEnemies.new(enemies_def)
	var battle := CombatBattleResult.new(party, enemies)
	_check(party.is_valid() and not party.is_defeated() and party.get_heroes().size() == 3,
		"fight has three real living actors")
	_check(enemies.is_valid() and enemies.get_enemies().size() == enemy_count
		and not enemies.is_victorious(), "fight has living enemy slots")
	_check(battle.get_outcome() == CombatBattleResult.ACTIVE, "new fight is ACTIVE")
	return {"party": party, "enemies": enemies, "battle": battle}


func _win(fight: Dictionary) -> void:
	var enemies: CombatEnemies = fight["enemies"]
	var battle: CombatBattleResult = fight["battle"]
	for i in range(1, enemies.get_enemies().size() + 1):
		var hp: int = enemies.get_enemy(i)["hp"]
		_check(enemies.apply_damage(i, hp) and enemies.is_slain(i),
			"actual damage slays enemy slot " + str(i))
		if i < enemies.get_enemies().size():
			_check(battle.evaluate() == CombatBattleResult.ACTIVE,
				"victory waits for last real enemy")
	_check(enemies.is_victorious() and not fight["party"].is_defeated(),
		"all enemies at zero and party still lives")
	_check(battle.get_outcome() == CombatBattleResult.ACTIVE,
		"unobserved lethal state cannot be paid")
	_check(battle.evaluate() == CombatBattleResult.VICTORY
		and battle.get_outcome() == CombatBattleResult.VICTORY, "explicit witnessed VICTORY")


## Today's seven-argument call stays the normal-Fight path.
func _session(fight: Dictionary, rng: Variant, ids: Variant, candidates: Variant,
		deck: Variant, gold: Variant, elite: bool, stitched_descriptors: Variant = {},
		next_stitch_id: Variant = 1) -> RunFightVictoryRewards:
	return RunFightVictoryRewards.new(fight["battle"], rng, ids, candidates, deck, gold, elite,
		[], [], stitched_descriptors, next_stitch_id)


func _elite_session(fight: Dictionary, rng: Variant, ids: Variant, candidates: Variant,
		deck: Variant, gold: Variant, trinket_candidates: Variant,
		owned_trinkets: Variant, stitched_descriptors: Variant = {},
		next_stitch_id: Variant = 1) -> RunFightVictoryRewards:
	return RunFightVictoryRewards.new(fight["battle"], rng, ids, candidates, deck, gold, true,
		trinket_candidates, owned_trinkets, stitched_descriptors, next_stitch_id)


## Independent oracle: gold draw, three sorted card-offer draws, then (Elite only)
## one sorted unowned trinket draw. Never calls the reward services.
func _oracle(catalog: StarterCards, ids: Array[String], candidates: Array[String],
		seed_value: int, elite: bool, trinket_candidates: Array = [],
		owned_trinkets: Array = []) -> Dictionary:
	var reference := _rng(seed_value)
	var gold: int = reference.randi_range(25, 35) if elite else reference.randi_range(10, 20)
	var pool: Array[String] = []
	for card_id in candidates:
		if ids.has(catalog.get_definition(card_id).get("owner")):
			pool.append(card_id)
	pool.sort()
	var offers: Array = []
	for n in range(3):
		var index: int = reference.randi_range(0, pool.size() - 1)
		var id: String = pool[index]
		pool.remove_at(index)
		offers.append({"id": id, "owner": catalog.get_definition(id)["owner"]})
	var drop := ""
	if elite:
		var trinket_ids: Array[String] = []
		for trinket_id in trinket_candidates:
			if not owned_trinkets.has(trinket_id):
				trinket_ids.append(trinket_id)
		trinket_ids.sort()
		if not trinket_ids.is_empty():
			drop = trinket_ids[reference.randi_range(0, trinket_ids.size() - 1)]
	return {
		"gold": gold, "offers": offers, "trinket_drop_id": drop,
		"rng_state": reference.state, "next": reference.randi()
	}


func _snapshot(fight: Dictionary, rng: RandomNumberGenerator, deck: Array[String],
		ids: Array[String], candidates: Array[String], gold: int,
		trinket_candidates: Variant = [], owned_trinkets: Variant = []) -> Array:
	return [fight["party"].get_heroes(), fight["enemies"].get_enemies(),
		fight["battle"].get_outcome(), rng.seed, rng.state, deck.duplicate(true),
		ids.duplicate(true), candidates.duplicate(true), gold,
		trinket_candidates.duplicate(true) if trinket_candidates is Array else trinket_candidates,
		owned_trinkets.duplicate(true) if owned_trinkets is Array else owned_trinkets]


func _test_prepare(definitions: Array, ids: Array[String], deck: Array[String],
		candidates: Array[String], elite: bool, count: int,
		trinket_candidates: Array, owned_trinkets: Array) -> void:
	var fight := _fight(definitions, count)
	var rng := _rng(900423)
	var service: RunFightVictoryRewards
	if elite:
		service = _elite_session(fight, rng, ids, candidates, deck, 78,
			trinket_candidates, owned_trinkets)
	else:
		service = _session(fight, rng, ids, candidates, deck, 78, elite)
	_check(service.has_method("prepare") and service.has_method("choose"),
		"public contract prepare/choose present")
	_win(fight)
	var before := _snapshot(fight, rng, deck, ids, candidates, 78,
		trinket_candidates, owned_trinkets)
	var oracle := _oracle(StarterCards.new(), ids, candidates, 900423, elite,
		trinket_candidates, owned_trinkets)
	seed(210412)
	var global_next := randi()
	seed(210412)
	var published: Dictionary = service.prepare()
	_check(randi() == global_next, "prepare never uses global RNG")
	_check(published.get("ok", false), "victory preparation succeeds")
	_check(published.get("gold_award") == oracle["gold"], "gold matches independent first draw")
	_check(published.get("gold_award", 0) >= (25 if elite else 10)
		and published.get("gold_award", 0) <= (35 if elite else 20),
		"payout falls in authored " + ("Elite" if elite else "Fight") + " range")
	_check(published.get("offers", []) == oracle["offers"],
		"three ordered offer draws match independent sorted without-replacement oracle")
	_check(published.get("trinket_drop_id", "<missing>") == oracle["trinket_drop_id"],
		("one sorted unowned trinket drop matches independent fifth draw" if elite
			else "ordinary Fight reports an empty trinket drop"))
	if elite:
		var drop: String = published.get("trinket_drop_id", "")
		_check(trinket_candidates.has(drop) and not owned_trinkets.has(drop)
			and not drop.is_empty(), "Elite drop is a supplied, unowned candidate ID")
	_check(rng.state == oracle["rng_state"],
		"RNG state equals " + ("five" if elite else "four") + " oracle draws")
	_check(rng.randi() == oracle["next"], "next RNG value matches reference oracle")
	var state_before_repeat: int = rng.state
	var snap := _snapshot(fight, rng, deck, ids, candidates, 78,
		trinket_candidates, owned_trinkets)
	var replay := service.prepare()
	_check(replay == published and rng.state == state_before_repeat,
		"second prepare neither rerolls nor advances RNG")
	_check(snap == _snapshot(fight, rng, deck, ids, candidates, 78,
		trinket_candidates, owned_trinkets),
		"repeat prepare preserves full source/model snapshot")
	_check(before[0] == snap[0] and before[1] == snap[1]
		and before[5] == snap[5] and before[6] == snap[6] and before[7] == snap[7]
		and before[8] == snap[8] and before[9] == snap[9] and before[10] == snap[10],
		"successful preparation mutates no actors or original data/gold/trinkets")
	var offers: Array = published.get("offers", [])
	var offered_ids: Array = []
	for offer in offers:
		offered_ids.append(offer.get("id"))
		var card := StarterCards.new().get_definition(offer.get("id", ""))
		_check(not card.is_empty() and ids.has(card.get("owner"))
			and card.get("owner") == offer.get("owner"), "every displayed offer is party-owned catalog card")
	_check(offered_ids.size() == 3 and offered_ids[0] != offered_ids[1]
		and offered_ids[0] != offered_ids[2] and offered_ids[1] != offered_ids[2],
		"offers are exactly three distinct card IDs")
	var unclaimed := service.choose("__foreign_card__")
	_check(not unclaimed["ok"] and unclaimed["trinkets"] == owned_trinkets,
		"prepare alone does not add the Elite drop to the inventory")
	_check(rng.state == state_before_repeat, "rejected post-prepare pick consumes no RNG")
	offers[0]["id"] = "corrupted_id"
	offers.append({"id": "extra"})
	replay["offers"][1]["owner"] = "corrupted_owner"
	published["trinket_drop_id"] = "corrupted_drop"
	_check(service.prepare()["offers"] == oracle["offers"]
		and service.prepare()["trinket_drop_id"] == oracle["trinket_drop_id"],
		"all prepare return values deep-copy cached offers and drop")
	var reversed_cards := candidates.duplicate()
	reversed_cards.reverse()
	var reversed_trinkets := trinket_candidates.duplicate()
	reversed_trinkets.reverse()
	var reversed_owned := owned_trinkets.duplicate()
	reversed_owned.reverse()
	if elite:
		_check(reversed_trinkets != trinket_candidates,
			"reversed trinket input order genuinely differs")
	var other_fight := _fight(definitions, count)
	_win(other_fight)
	var replay_rng := _rng(900423)
	var second: RunFightVictoryRewards
	if elite:
		second = _elite_session(other_fight, replay_rng, ids, reversed_cards, deck, 78,
			reversed_trinkets, reversed_owned)
	else:
		second = _session(other_fight, replay_rng, ids, reversed_cards, deck, 78, elite)
	var fresh := second.prepare()
	_check(fresh["gold_award"] == oracle["gold"] and fresh["offers"] == oracle["offers"]
		and fresh.get("trinket_drop_id", "") == oracle["trinket_drop_id"]
		and replay_rng.state == oracle["rng_state"],
		"independent same-seed session replays exactly with reversed input order")


func _test_choices(definitions: Array, ids: Array[String], deck: Array[String],
		candidates: Array[String]) -> void:
	var catalog_before := {}
	var catalog := StarterCards.new()
	for id in catalog.get_all_card_ids():
		catalog_before[id] = catalog.get_definition(id)
	for index in range(4):
		var elite: bool = index >= 2
		var fight := _fight(definitions, 2)
		_win(fight)
		var rng := _rng(44009)
		var service: RunFightVictoryRewards
		if elite:
			service = _elite_session(fight, rng, ids, candidates, deck, 103,
				TRINKET_POOL, OWNED_TRINKETS)
		else:
			service = _session(fight, rng, ids, candidates, deck, 103, false)
		var expected_owned: Array = OWNED_TRINKETS.duplicate() if elite else []
		var unopened := service.choose("")
		_check(not unopened["ok"] and unopened["gold"] == 103
			and unopened["deck"] == deck and unopened["trinkets"] == expected_owned,
			"unprepared choice cannot pay, append or carry a trinket")
		unopened["trinkets"].append("__return_mutation__")
		var ready := service.prepare()
		_check(ready["ok"] and ready["offers"].size() == 3, "each separate session prepares real offer")
		var oracle := _oracle(StarterCards.new(), ids, candidates, 44009, elite,
			TRINKET_POOL, OWNED_TRINKETS)
		_check(ready.get("trinket_drop_id", "<missing>") == oracle["trinket_drop_id"],
			"card-pick and skip sessions cache the same independent Elite drop")
		if elite:
			_check((ready["trinket_drop_id"] in TRINKET_POOL)
				and not (ready["trinket_drop_id"] in OWNED_TRINKETS)
				and rng.state == oracle["rng_state"],
				"Elite session drew one sorted unowned drop after gold and offers")
		else:
			_check(ready.get("trinket_drop_id") == "" and rng.state == oracle["rng_state"],
				"normal Fight draws no trinket and consumes only four draws")
		var selection: String = "" if index == 3 else ready["offers"][index]["id"]
		var before := _snapshot(fight, rng, deck, ids, candidates, 103,
			TRINKET_POOL, OWNED_TRINKETS)
		var stale := service.choose("__foreign_card__")
		_check(not stale["ok"] and stale["gold"] == 103 and stale["deck"] == deck
			and stale["trinkets"] == expected_owned,
			"foreign selection rejected with no reward and no trinket")
		var actual_but_unoffered := ""
		for candidate in candidates:
			var used := false
			for offer in ready["offers"]:
				if offer["id"] == candidate:
					used = true
			if not used:
				actual_but_unoffered = candidate
				break
		if not actual_but_unoffered.is_empty():
			var stale_authored := service.choose(actual_but_unoffered)
			_check(not stale_authored["ok"] and stale_authored["deck"] == deck
				and stale_authored["trinkets"] == expected_owned,
				"catalog-valid but not-offered card rejected without a trinket")
		_check(before == _snapshot(fight, rng, deck, ids, candidates, 103,
			TRINKET_POOL, OWNED_TRINKETS),
			"invalid selections preserve all state and RNG")
		var claimed := service.choose(selection)
		var expected_deck := deck.duplicate()
		var expected_trinkets: Array = expected_owned.duplicate()
		if index != 3:
			expected_deck.append(selection)
		if elite:
			expected_trinkets.append(ready["trinket_drop_id"])
		_check(claimed["ok"] and claimed["skipped"] == (index == 3)
			and claimed["selected_id"] == selection, "explicit selection or skip claims once")
		_check(claimed["deck"] == expected_deck
			and claimed["gold"] == 103 + ready["gold_award"],
			"exactly one appended card (or none) and one cached gold award")
		_check(claimed["trinkets"] == expected_trinkets,
			"claim returns existing owned IDs plus exactly one cached Elite drop")
		if elite:
			_check(claimed["trinkets"].count(ready["trinket_drop_id"]) == 1
				and claimed["trinkets"].count("button_charm") == 1,
				"the cached drops appears exactly once, never duplicating an owned ID")
		_check(before == _snapshot(fight, rng, deck, ids, candidates, 103,
			TRINKET_POOL, OWNED_TRINKETS),
			"claim leaves input deck, full rosters, candidates, gold and RNG unchanged")
		var shuffled: Array[String] = []
		shuffled.assign(claimed["deck"])
		var battle_deck := CombatDeck.new(shuffled, _rng(23))
		_check(battle_deck.start_turn() and battle_deck.hand.size() == 5
			and battle_deck.energy == 3, "fresh shared CombatDeck draws 5 with 3 energy")
		var inventory := battle_deck.draw_pile.duplicate()
		inventory.append_array(battle_deck.hand)
		inventory.append_array(battle_deck.discard_pile)
		inventory.sort()
		var expected_inventory := expected_deck.duplicate()
		expected_inventory.sort()
		_check(inventory == expected_inventory, "all exact card copies preserved in shuffled CombatDeck")
		claimed["deck"].append("__return_mutation__")
		claimed["gold"] = 999999
		claimed["trinkets"].append("__return_mutation__")
		_check(not service.choose(selection)["ok"] and not service.choose("")["ok"],
			"duplicate pick, second skip, and skip-after-pick cannot pay again")
		var after_repeat := service.choose(selection)
		_check(after_repeat["trinkets"] == expected_owned,
			"repeated claims return a detached unchanged owned-inventory snapshot")
		_check(service.prepare() == ready and rng.state == before[4],
			"post-claim offer read cannot reroll, including after result mutation")
		_check(service.prepare()["trinket_drop_id"] == oracle["trinket_drop_id"],
			"edited cached response and returned inventory never alias internal drop")
	var external_trinkets := TRINKET_POOL.duplicate()
	var external_owned := OWNED_TRINKETS.duplicate()
	var external_fight := _fight(definitions, 2)
	_win(external_fight)
	var external_rng := _rng(777)
	var prepared := _elite_session(external_fight, external_rng, ids, candidates, deck, 20,
		external_trinkets, external_owned)
	var external_oracle := _oracle(StarterCards.new(), ids, candidates, 777, true,
		TRINKET_POOL, OWNED_TRINKETS)
	external_trinkets.clear()
	external_owned.clear()
	var external_result := prepared.prepare()
	_check(external_result["ok"]
		and external_result["trinket_drop_id"] == external_oracle["trinket_drop_id"]
		and external_rng.state == external_oracle["rng_state"],
		"constructor detaches original trinket candidate/owned arrays")
	var external_claim := prepared.choose("")
	var external_expected: Array = OWNED_TRINKETS.duplicate()
	external_expected.append(external_oracle["trinket_drop_id"])
	_check(external_claim["ok"] and external_claim["trinkets"] == external_expected,
		"detached trinket arrays survive caller edits")
	var catalog_after := {}
	for id in catalog.get_all_card_ids():
		catalog_after[id] = catalog.get_definition(id)
	_check(catalog_before == catalog_after, "full authored card catalog remains unchanged")


## Authored D2-1 base records: exactly what the routed run supplies.
func _pool_records() -> Array[Dictionary]:
	return RunPoolCardRewardOffers.get_authored_base_candidates()


func _base_pool_ids(owner: String) -> Array[String]:
	if owner == "warden":
		return WardenPoolCards.new().get_base_ids()
	if owner == "seamstress":
		return SeamstressPoolCards.new().get_base_ids()
	if owner == "tinker":
		return TinkerPoolCards.new().get_pool_card_ids()
	return []


func _pool_definition(owner: String, card_id: String) -> Dictionary:
	if owner == "warden":
		return WardenPoolCards.new().get_definition(card_id)
	if owner == "seamstress":
		return SeamstressPoolCards.new().get_definition(card_id)
	if owner == "tinker":
		return TinkerPoolCards.new().get_definition(card_id)
	return {}


## Independent oracle for the weighted path: one gold draw, then three picks of
## two draws each (tier roll, card roll) from sorted rarity buckets, using
## living-owner priority for each living hero, then the union of living owners'
## remaining cards for any unfilled choices, then the Elite drop.
## Never calls the reward services.
func _weighted_oracle(party: Array[String], records: Array[Dictionary], seed_value: int,
		elite: bool, trinket_candidates: Array = [], owned_trinkets: Array = [],
		living_ids: Variant = null) -> Dictionary:
	var reference := _rng(seed_value)
	var gold: int = reference.randi_range(25, 35) if elite else reference.randi_range(10, 20)
	var tiers: Array[String] = ["common", "uncommon", "rare"]
	var weights := {"common": 60, "uncommon": 30, "rare": 10}

	var living_order: Array[String] = []
	var living_set: Dictionary = {}
	if living_ids is Array:
		for lid: Variant in living_ids:
			if lid is String:
				living_set[lid] = true
		for pid: String in party:
			if living_set.has(pid):
				living_order.append(pid)
	else:
		living_order = party.duplicate()
		for pid: String in party:
			living_set[pid] = true

	var hero_buckets: Dictionary = {}
	for hid: String in living_order:
		hero_buckets[hid] = {"common": [], "uncommon": [], "rare": []}

	for record: Dictionary in records:
		var owner: String = String(record.get("owner", ""))
		var rarity: String = String(record.get("rarity", ""))
		if hero_buckets.has(owner) and hero_buckets[owner].has(rarity):
			(hero_buckets[owner][rarity] as Array).append(record)

	for hid: String in living_order:
		for tier: String in tiers:
			(hero_buckets[hid][tier] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a.get("id", "")) < String(b.get("id", "")))

	var offers: Array = []
	for hid: String in living_order:
		if offers.size() >= 3:
			break
		var buckets: Dictionary = hero_buckets[hid]
		var weight_sum: int = 0
		for tier: String in tiers:
			if not (buckets[tier] as Array).is_empty():
				weight_sum += int(weights[tier])
		var roll: int = reference.randi_range(1, weight_sum)
		var chosen: String = ""
		var running: int = 0
		for tier: String in tiers:
			if (buckets[tier] as Array).is_empty():
				continue
			running += int(weights[tier])
			if roll <= running:
				chosen = tier
				break
		var bucket: Array = buckets[chosen]
		var index: int = reference.randi_range(0, bucket.size() - 1)
		var record: Dictionary = bucket[index]
		bucket.remove_at(index)
		offers.append({"id": String(record["id"]), "owner": String(record["owner"])})

	if offers.size() < 3:
		var union_buckets: Dictionary = {"common": [], "uncommon": [], "rare": []}
		for tier: String in tiers:
			var u_bucket: Array = union_buckets[tier]
			for hid: String in living_order:
				var o_bucket: Array = hero_buckets[hid][tier]
				for record_val: Variant in o_bucket:
					u_bucket.append(record_val)
			u_bucket.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a.get("id", "")) < String(b.get("id", "")))
		while offers.size() < 3:
			var weight_sum: int = 0
			for tier: String in tiers:
				if not (union_buckets[tier] as Array).is_empty():
					weight_sum += int(weights[tier])
			var roll: int = reference.randi_range(1, weight_sum)
			var chosen: String = ""
			var running: int = 0
			for tier: String in tiers:
				if (union_buckets[tier] as Array).is_empty():
					continue
				running += int(weights[tier])
				if roll <= running:
					chosen = tier
					break
			var bucket: Array = union_buckets[chosen]
			var index: int = reference.randi_range(0, bucket.size() - 1)
			var record: Dictionary = bucket[index]
			bucket.remove_at(index)
			offers.append({"id": String(record["id"]), "owner": String(record["owner"])})

	var drop: String = ""
	if elite:
		var trinket_ids: Array[String] = []
		for trinket_id: Variant in trinket_candidates:
			if trinket_id is String and not owned_trinkets.has(trinket_id):
				trinket_ids.append(trinket_id)
		trinket_ids.sort()
		if not trinket_ids.is_empty():
			drop = trinket_ids[reference.randi_range(0, trinket_ids.size() - 1)]

	return {
		"gold": gold, "offers": offers, "trinket_drop_id": drop,
		"rng_state": reference.state, "next": reference.randi()
	}


func _pool_snapshot(fight: Dictionary, rng: RandomNumberGenerator, deck: Array[String],
		ids: Array[String], records: Array[Dictionary], gold: int,
		trinket_candidates: Variant = [], owned_trinkets: Variant = []) -> Array:
	return [fight["party"].get_heroes(), fight["enemies"].get_enemies(),
		fight["battle"].get_outcome(), rng.seed, rng.state, deck.duplicate(true),
		ids.duplicate(true), records.duplicate(true), gold,
		trinket_candidates.duplicate(true) if trinket_candidates is Array else trinket_candidates,
		owned_trinkets.duplicate(true) if owned_trinkets is Array else owned_trinkets]


## The routed run supplies authored base records instead of starter ID strings.
## Both Fight and Elite must settle weighted offers from the same staged stream,
## and later rewards must accept an already-awarded pool ID in the run deck.
func _test_weighted_records(definitions: Array, ids: Array[String], deck: Array[String]) -> void:
	var records := _pool_records()
	_check(records.size() >= 3, "authored D2-1 base records exist for the party")
	for record: Dictionary in records:
		var def_owner := String(record.get("owner", ""))
		var def_id := String(record.get("id", ""))
		_check(_base_pool_ids(def_owner).has(def_id)
			and not def_id.ends_with("_plus")
			and String(record.get("rarity", "")) in ["common", "uncommon", "rare"],
			"authored base record is reward-eligible: " + def_id)
	for elite in [false, true]:
		var label := "Elite" if elite else "Fight"
		var fight := _fight(definitions, 2 if elite else 1)
		_win(fight)
		var rng := _rng(880512)
		var service: RunFightVictoryRewards
		if elite:
			service = _elite_session(fight, rng, ids, records, deck, 78,
				TRINKET_POOL, OWNED_TRINKETS)
		else:
			service = _session(fight, rng, ids, records, deck, 78, false)
		var before := _pool_snapshot(fight, rng, deck, ids, records, 78,
			TRINKET_POOL, OWNED_TRINKETS)
		var oracle := _weighted_oracle(ids, records, 880512, elite,
			TRINKET_POOL, OWNED_TRINKETS)
		var published := service.prepare()
		_check(published.get("ok", false), label + ": weighted records prepare succeeds")
		_check(published.get("gold_award") == oracle["gold"],
			label + ": weighted path keeps the first gold draw exact")
		_check(published.get("offers", []) == oracle["offers"],
			label + ": offers match the independent weighted six-draw oracle")
		_check(published.get("trinket_drop_id", "") == oracle["trinket_drop_id"],
			label + ": Elite drop still follows the weighted selection")
		_check(rng.state == oracle["rng_state"],
			label + ": RNG state equals gold + six picks + " + ("drop" if elite else "no drop"))
		_check(rng.randi() == oracle["next"], label + ": next RNG value matches reference")
		var state_before_repeat := rng.state
		var replay := service.prepare()
		_check(replay == published and rng.state == state_before_repeat,
			label + ": repeated weighted prepare neither rerolls nor advances RNG")
		var after := _pool_snapshot(fight, rng, deck, ids, records, 78,
			TRINKET_POOL, OWNED_TRINKETS)
		_check(before[0] == after[0] and before[1] == after[1] and before[2] == after[2]
			and before[3] == after[3] and before[5] == after[5] and before[6] == after[6]
			and before[7] == after[7] and before[8] == after[8] and before[9] == after[9]
			and before[10] == after[10],
			label + ": weighted preparation mutates no inputs")
		var offers: Array = published.get("offers", [])
		var offered_ids: Array = []
		_check(offers.size() == 3 and offers[0].get("owner") == "warden"
			and offers[1].get("owner") == "seamstress" and offers[2].get("owner") == "tinker",
			label + ": one card from each living hero in party order")
		for offer: Dictionary in offers:
			offered_ids.append(offer.get("id"))
			var owner := String(offer.get("owner", ""))
			var card_id := String(offer.get("id", ""))
			var definition := _pool_definition(owner, card_id)
			_check(not definition.is_empty() and definition.get("id") == card_id
				and definition.get("owner") == owner and ids.has(owner),
				label + ": offer is a party-owned authored pool card: " + card_id)
			_check(_base_pool_ids(owner).has(card_id) and not card_id.ends_with("_plus"),
				label + ": offer is a base (never '+') reward-eligible record: " + card_id)
			_check(not StarterCards.new().has_card(card_id),
				label + ": live weighted offers are not unweighted starter cards")
		_check(offered_ids.size() == 3 and offered_ids[0] != offered_ids[1]
			and offered_ids[0] != offered_ids[2] and offered_ids[1] != offered_ids[2],
			label + ": three distinct weighted offers")
		var expected_deck := deck.duplicate()
		expected_deck.append(offered_ids[0])
		var expected_trinkets: Array = OWNED_TRINKETS.duplicate() if elite else []
		if elite:
			expected_trinkets.append(published["trinket_drop_id"])
		var claimed := service.choose(offered_ids[0])
		_check(claimed.get("ok", false) and not claimed.get("skipped", true)
			and claimed.get("selected_id") == offered_ids[0],
			label + ": weighted pick claims exactly once")
		_check(claimed.get("deck") == expected_deck and claimed.get("gold") == 78 + oracle["gold"]
			and claimed.get("trinkets") == expected_trinkets,
			label + ": weighted claim appends one pool ID, one award, one cached drop")
		# A later reward must accept the pool ID this transaction awarded.
		var later := _fight(definitions, 1)
		_win(later)
		var later_rng := _rng(311)
		var later_service := _session(later, later_rng, ids, records, expected_deck, 10, false)
		var later_prepared := later_service.prepare()
		_check(later_prepared.get("ok", false),
			label + ": later reward accepts a previously awarded pool ID in the deck")
		var previous_pool_base: String = offered_ids[0]
		for owner in HERO_IDS:
			var base_id := ""
			for record: Dictionary in records:
				if record.get("owner") == owner:
					base_id = record.get("id")
					break
			var pre_upgrade_deck := expected_deck.duplicate()
			pre_upgrade_deck.append(base_id)
			var appended_index: int = pre_upgrade_deck.size() - 1
			var upgrade_choices: Dictionary = RunRestCardUpgrade.list_authored_choices(pre_upgrade_deck)
			var permitted_upgrades: Dictionary = upgrade_choices.get("permitted_upgrades", {})
			var upgrade_transaction := RunRestCardUpgrade.new(pre_upgrade_deck, permitted_upgrades)
			var base_index: int = -1
			var choices: Array = upgrade_choices.get("choices", [])
			for choice: Dictionary in choices:
				if choice.get("source_id") == base_id and choice.get("index") == appended_index:
					base_index = choice.get("index")
					break
			_check(base_index != -1, label + ": appended authored pool base appears in upgrade choices for " + owner)
			var valid_upgrade: Dictionary = upgrade_transaction.choose_upgrade(base_index)
			_check(valid_upgrade.get("ok", false), label + ": rest upgrade choice succeeded for " + owner)
			var upgraded_deck: Array = valid_upgrade.get("deck", [])
			_check(upgraded_deck.has(previous_pool_base), label + ": upgraded receipt preserves previously awarded unupgraded pool base")
			_check(upgraded_deck.has(base_id + "_plus"), label + ": upgraded receipt contains exact newly upgraded plus ID")
			
			var upgrade_fight := _fight(definitions, 2 if elite else 1)
			_win(upgrade_fight)
			var upgrade_rng := _rng(312)
			var upgrade_service: RunFightVictoryRewards
			if elite:
				upgrade_service = _elite_session(upgrade_fight, upgrade_rng, ids, records,
					upgraded_deck, 10, TRINKET_POOL, OWNED_TRINKETS)
			else:
				upgrade_service = _session(upgrade_fight, upgrade_rng, ids, records,
					upgraded_deck, 10, false)
			
			var upgrade_oracle := _weighted_oracle(ids, records, 312, elite,
				TRINKET_POOL, OWNED_TRINKETS)
			var upgrade_prepared: Dictionary = upgrade_service.prepare()
			_check(upgrade_prepared.get("ok", false),
				label + ": authentic Rest upgraded '+' members survive into later reward sources for " + owner)
			_check(upgrade_prepared.get("gold_award") == upgrade_oracle["gold"], label + ": upgraded gold matches oracle")
			_check(upgrade_prepared.get("offers", []) == upgrade_oracle["offers"], label + ": upgraded offers match oracle")
			_check(upgrade_prepared.get("trinket_drop_id", "") == upgrade_oracle["trinket_drop_id"], label + ": upgraded drop matches oracle")
			_check(upgrade_rng.state == upgrade_oracle["rng_state"], label + ": upgraded RNG state matches oracle")
			
			var upgrade_offers: Array = upgrade_prepared.get("offers", [])
			var upgrade_offered_ids: Array = []
			for upgrade_offer: Dictionary in upgrade_offers:
				upgrade_offered_ids.append(upgrade_offer.get("id"))
				_check(not String(upgrade_offer.get("id", "")).ends_with("_plus"),
					label + ": offers themselves remain unupgraded base IDs")
			_check(upgrade_offered_ids.size() == 3 and upgrade_offered_ids[0] != upgrade_offered_ids[1]
				and upgrade_offered_ids[0] != upgrade_offered_ids[2] and upgrade_offered_ids[1] != upgrade_offered_ids[2],
				label + ": three distinct legal base offers from upgraded prepare")
				
			var expected_chosen_deck := upgraded_deck.duplicate()
			expected_chosen_deck.append(upgrade_offered_ids[0])
			var expected_chosen_trinkets := OWNED_TRINKETS.duplicate() if elite else []
			if elite:
				expected_chosen_trinkets.append(upgrade_prepared["trinket_drop_id"])
				
			var chosen := upgrade_service.choose(upgrade_offered_ids[0])
			_check(chosen.get("ok", false) and chosen.get("deck") == expected_chosen_deck, label + ": upgraded chosen deck keeps base/+ IDs")
			_check(chosen.get("deck", []).has(previous_pool_base), label + ": chosen deck contains previously held base")
			_check(chosen.get("deck", []).has(base_id + "_plus"), label + ": chosen deck contains new plus ID")
			_check(chosen.get("gold") == 10 + upgrade_oracle["gold"] and chosen.get("trinkets") == expected_chosen_trinkets, label + ": upgraded choose pays exactly once")
			
			var skip_fight := _fight(definitions, 2 if elite else 1)
			_win(skip_fight)
			var skip_rng := _rng(312)
			var skip_service: RunFightVictoryRewards
			if elite:
				skip_service = _elite_session(skip_fight, skip_rng, ids, records,
					upgraded_deck, 10, TRINKET_POOL, OWNED_TRINKETS)
			else:
				skip_service = _session(skip_fight, skip_rng, ids, records,
					upgraded_deck, 10, false)
			skip_service.prepare()
			var skipped := skip_service.choose("")
			_check(skipped.get("ok", false) and skipped.get("deck") == upgraded_deck, label + ": upgraded skipped deck keeps base/+ IDs")
			_check(skipped.get("deck", []).has(previous_pool_base), label + ": skipped deck contains previously held base")
			_check(skipped.get("deck", []).has(base_id + "_plus"), label + ": skipped deck contains new plus ID")
			_check(skipped.get("gold") == 10 + upgrade_oracle["gold"] and skipped.get("trinkets") == expected_chosen_trinkets, label + ": upgraded skip pays exactly once")

		var fake_plus_deck := expected_deck.duplicate()
		fake_plus_deck.append("warden_fake_card_plus")
		var fake_fight := _fight(definitions, 1)
		_win(fake_fight)
		var fake_rng := _rng(315)
		var fake_service := _session(fake_fight, fake_rng, ids, records,
			fake_plus_deck, 10, false)
		var fake_state := fake_rng.state
		_check(not fake_service.prepare().get("ok", true)
			and fake_rng.state == fake_state,
			label + ": counterfeit '+' unawarded pool members still fail closed without RNG use")
	# Replayed seed with reversed records yields identical offers and RNG state
	var reversed_records := _pool_records()
	reversed_records.reverse()
	var rev_fight := _fight(definitions, 1)
	_win(rev_fight)
	var rev_rng := _rng(880512)
	var rev_service := _session(rev_fight, rev_rng, ids, reversed_records, deck, 78, false)
	var rev_oracle := _weighted_oracle(ids, records, 880512, false)
	var rev_pub := rev_service.prepare()
	_check(rev_pub["offers"] == rev_oracle["offers"] and rev_rng.state == rev_oracle["rng_state"],
		"all-alive reversed candidate order yields identical offers and RNG state")
	# Constructor detaches the caller's records array.
	var external := _pool_records()
	var external_fight := _fight(definitions, 1)
	_win(external_fight)
	var external_rng := _rng(4242)
	var detached := _session(external_fight, external_rng, ids, external, deck, 10, false)
	var external_oracle := _weighted_oracle(ids, external, 4242, false)
	external.clear()
	var detached_result := detached.prepare()
	_check(detached_result.get("ok", false)
		and detached_result.get("offers") == external_oracle["offers"]
		and external_rng.state == external_oracle["rng_state"],
		"constructor detaches caller-owned weighted records")


## Two living heroes fixture: drop chosen hero to 0 HP, defeat enemies, evaluate VICTORY,
## verify living-owner priority and no card owned by the downed hero.
func _test_weighted_two_survivors(definitions: Array, ids: Array[String], deck: Array[String], elite: bool) -> void:
	var label: String = "Two-survivors Elite" if elite else "Two-survivors Fight"
	var records: Array[Dictionary] = _pool_records()
	var fight: Dictionary = _fight(definitions, 2 if elite else 1)
	var seamstress_hp: int = fight["party"].get_hero(2)["hp"]
	_check(fight["party"].apply_damage(2, seamstress_hp) and fight["party"].is_downed(2),
		label + ": seamstress downed to 0 HP")
	_check(not fight["party"].is_downed(1) and not fight["party"].is_downed(3),
		label + ": warden and tinker remain living")
	_win(fight)
	_check(fight["battle"].get_outcome() == CombatBattleResult.VICTORY, label + ": battle is VICTORY")
	var rng: RandomNumberGenerator = _rng(551201)
	var service: RunFightVictoryRewards
	if elite:
		service = _elite_session(fight, rng, ids, records, deck, 50, TRINKET_POOL, OWNED_TRINKETS)
	else:
		service = _session(fight, rng, ids, records, deck, 50, false)
	var oracle: Dictionary = _weighted_oracle(ids, records, 551201, elite, TRINKET_POOL, OWNED_TRINKETS, ["warden", "tinker"])
	var published: Dictionary = service.prepare()
	_check(published.get("ok", false), label + ": prepare succeeds")
	_check(published.get("gold_award") == oracle["gold"], label + ": gold award matches oracle")
	_check(published.get("offers", []) == oracle["offers"], label + ": offers match two-survivor weighted oracle")
	_check(published.get("trinket_drop_id", "") == oracle["trinket_drop_id"], label + ": trinket drop matches oracle")
	_check(rng.state == oracle["rng_state"], label + ": RNG state matches oracle")
	_check(rng.randi() == oracle["next"], label + ": next RNG value matches oracle")
	var offers: Array = published.get("offers", [])
	_check(offers.size() == 3, label + ": exactly three offers")
	_check(offers[0].get("owner") == "warden" and offers[1].get("owner") == "tinker",
		label + ": first two offers prioritize living warden and tinker in party order")
	_check(offers[2].get("owner") in ["warden", "tinker"],
		label + ": third offer filled from remaining living heroes")
	var offered_ids: Array[String] = []
	for offer: Dictionary in offers:
		var off_id: String = String(offer.get("id", ""))
		var off_owner: String = String(offer.get("owner", ""))
		_check(off_owner != "seamstress", label + ": no card owned by downed seamstress")
		_check(off_owner in ["warden", "tinker"], label + ": card owner is a living hero")
		_check(_base_pool_ids(off_owner).has(off_id) and not off_id.ends_with("_plus"),
			label + ": authored base pool card: " + off_id)
		offered_ids.append(off_id)
	_check(offered_ids[0] != offered_ids[1] and offered_ids[0] != offered_ids[2] and offered_ids[1] != offered_ids[2],
		label + ": three distinct card IDs")
	# Replay with reversed records order
	var reversed_records: Array[Dictionary] = records.duplicate()
	reversed_records.reverse()
	var replay_fight: Dictionary = _fight(definitions, 2 if elite else 1)
	replay_fight["party"].apply_damage(2, seamstress_hp)
	_win(replay_fight)
	var replay_rng: RandomNumberGenerator = _rng(551201)
	var replay_service: RunFightVictoryRewards
	if elite:
		replay_service = _elite_session(replay_fight, replay_rng, ids, reversed_records, deck, 50, TRINKET_POOL, OWNED_TRINKETS)
	else:
		replay_service = _session(replay_fight, replay_rng, ids, reversed_records, deck, 50, false)
	var replay_pub: Dictionary = replay_service.prepare()
	_check(replay_pub["offers"] == oracle["offers"] and replay_rng.state == oracle["rng_state"],
		label + ": reversed record order yields identical offers and RNG state")
	# Test choice: pick first card
	var claimed: Dictionary = service.choose(offered_ids[0])
	_check(claimed.get("ok", false) and claimed.get("deck").has(offered_ids[0]),
		label + ": pick adds chosen card to deck")
	_check(not service.choose(offered_ids[1])["ok"], label + ": duplicate claim rejected")
	_check(not service.choose("")["ok"], label + ": skip after claim rejected")


## Two survivors with Warden and Seamstress alive, Tinker downed.
func _test_weighted_two_survivors_ws(definitions: Array, ids: Array[String], deck: Array[String]) -> void:
	var label: String = "Two-survivors WS Fight"
	var records: Array[Dictionary] = _pool_records()
	var fight: Dictionary = _fight(definitions, 1)
	var tinker_hp: int = fight["party"].get_hero(3)["hp"]
	_check(fight["party"].apply_damage(3, tinker_hp) and fight["party"].is_downed(3),
		label + ": tinker downed")
	_win(fight)
	var rng: RandomNumberGenerator = _rng(773412)
	var service: RunFightVictoryRewards = _session(fight, rng, ids, records, deck, 25, false)
	var oracle: Dictionary = _weighted_oracle(ids, records, 773412, false, [], [], ["warden", "seamstress"])
	var published: Dictionary = service.prepare()
	_check(published.get("ok", false), label + ": prepare succeeds")
	_check(published.get("offers") == oracle["offers"], label + ": offers match oracle")
	_check(published["offers"][0]["owner"] == "warden" and published["offers"][1]["owner"] == "seamstress",
		label + ": living warden and seamstress prioritized in party order")
	for offer: Dictionary in published["offers"]:
		_check(offer["owner"] != "tinker", label + ": no card from downed tinker")
	var skipped: Dictionary = service.choose("")
	_check(skipped.get("ok", false) and skipped.get("skipped", false) and skipped.get("deck") == deck,
		label + ": skip preserves deck")


## One survivor fixture: drop two heroes to 0 HP, verify all offers owned by sole living hero.
func _test_weighted_one_survivor(definitions: Array, ids: Array[String], deck: Array[String], elite: bool) -> void:
	var label: String = "One-survivor Elite" if elite else "One-survivor Fight"
	var records: Array[Dictionary] = _pool_records()
	var fight: Dictionary = _fight(definitions, 2 if elite else 1)
	var warden_hp: int = fight["party"].get_hero(1)["hp"]
	var seamstress_hp: int = fight["party"].get_hero(2)["hp"]
	_check(fight["party"].apply_damage(1, warden_hp) and fight["party"].is_downed(1),
		label + ": warden downed to 0 HP")
	_check(fight["party"].apply_damage(2, seamstress_hp) and fight["party"].is_downed(2),
		label + ": seamstress downed to 0 HP")
	_check(not fight["party"].is_downed(3) and fight["party"].get_hero(3)["hp"] > 0,
		label + ": only tinker living")
	_win(fight)
	_check(fight["battle"].get_outcome() == CombatBattleResult.VICTORY, label + ": battle is VICTORY")
	var rng: RandomNumberGenerator = _rng(662304)
	var service: RunFightVictoryRewards
	if elite:
		service = _elite_session(fight, rng, ids, records, deck, 50, TRINKET_POOL, OWNED_TRINKETS)
	else:
		service = _session(fight, rng, ids, records, deck, 50, false)
	var oracle: Dictionary = _weighted_oracle(ids, records, 662304, elite, TRINKET_POOL, OWNED_TRINKETS, ["tinker"])
	var published: Dictionary = service.prepare()
	_check(published.get("ok", false), label + ": prepare succeeds")
	_check(published.get("gold_award") == oracle["gold"], label + ": gold matches oracle")
	_check(published.get("offers", []) == oracle["offers"], label + ": offers match one-survivor weighted oracle")
	_check(published.get("trinket_drop_id", "") == oracle["trinket_drop_id"], label + ": trinket drop matches oracle")
	_check(rng.state == oracle["rng_state"], label + ": RNG state matches oracle")
	_check(rng.randi() == oracle["next"], label + ": next RNG value matches oracle")
	var offers: Array = published.get("offers", [])
	_check(offers.size() == 3, label + ": exactly three offers")
	var offered_ids: Array[String] = []
	for offer: Dictionary in offers:
		var off_id: String = String(offer.get("id", ""))
		var off_owner: String = String(offer.get("owner", ""))
		_check(off_owner == "tinker", label + ": all offers owned by sole living hero tinker")
		_check(_base_pool_ids("tinker").has(off_id) and not off_id.ends_with("_plus"),
			label + ": authored tinker base pool card: " + off_id)
		offered_ids.append(off_id)
	_check(offered_ids[0] != offered_ids[1] and offered_ids[0] != offered_ids[2] and offered_ids[1] != offered_ids[2],
		label + ": three distinct card IDs without replacement")
	var reversed_records: Array[Dictionary] = records.duplicate()
	reversed_records.reverse()
	var replay_fight: Dictionary = _fight(definitions, 2 if elite else 1)
	replay_fight["party"].apply_damage(1, warden_hp)
	replay_fight["party"].apply_damage(2, seamstress_hp)
	_win(replay_fight)
	var replay_rng: RandomNumberGenerator = _rng(662304)
	var replay_service: RunFightVictoryRewards
	if elite:
		replay_service = _elite_session(replay_fight, replay_rng, ids, reversed_records, deck, 50, TRINKET_POOL, OWNED_TRINKETS)
	else:
		replay_service = _session(replay_fight, replay_rng, ids, reversed_records, deck, 50, false)
	var replay_pub: Dictionary = replay_service.prepare()
	_check(replay_pub["offers"] == oracle["offers"] and replay_rng.state == oracle["rng_state"],
		label + ": reversed record order yields identical offers and RNG state")
	var skipped: Dictionary = service.choose("")
	_check(skipped.get("ok", false) and skipped.get("skipped", false) and skipped.get("selected_id") == ""
		and skipped.get("deck") == deck, label + ": skip claims no card")
	_check(not service.choose("")["ok"], label + ": repeated skip rejected")


## One survivor with Warden sole survivor.
func _test_weighted_one_survivor_warden(definitions: Array, ids: Array[String], deck: Array[String]) -> void:
	var label: String = "One-survivor Warden Fight"
	var records: Array[Dictionary] = _pool_records()
	var fight: Dictionary = _fight(definitions, 1)
	var seamstress_hp: int = fight["party"].get_hero(2)["hp"]
	var tinker_hp: int = fight["party"].get_hero(3)["hp"]
	_check(fight["party"].apply_damage(2, seamstress_hp) and fight["party"].apply_damage(3, tinker_hp),
		label + ": seamstress and tinker downed")
	_win(fight)
	var rng: RandomNumberGenerator = _rng(884523)
	var service: RunFightVictoryRewards = _session(fight, rng, ids, records, deck, 25, false)
	var oracle: Dictionary = _weighted_oracle(ids, records, 884523, false, [], [], ["warden"])
	var published: Dictionary = service.prepare()
	_check(published.get("ok", false), label + ": prepare succeeds")
	_check(published.get("offers") == oracle["offers"], label + ": offers match oracle")
	for offer: Dictionary in published["offers"]:
		_check(offer["owner"] == "warden", label + ": all offers owned by living warden")


## An authentic Rest composite is issued by the canonical Rest transaction, then
## carried into a won Fight/Elite exactly as the routed run does.
func _stitched_ledger(deck: Array[String]) -> Dictionary:
	var source := RunRestStitchCards.new(deck, {}, RunRestStitchCards.SCRAP_COST, 1)
	_check(source.is_valid(), "funded authentic Rest ledger admits a stitch")
	if not source.is_valid():
		return {}
	var first: int = deck.find("seamstress_prick")
	var second: int = deck.find("tinker_pop_shot")
	_check(first >= 0 and second >= 0 and first != second,
		"authored cross-owner originals are owned instances")
	if first < 0 or second < 0 or first == second:
		return {}
	var made: Dictionary = source.choose_stitch(first, second, source.get_snapshot())
	_check(made.get("ok", false) and made.get("stitched_id") == "stitched_000001"
		and made.get("next_stitch_id") == 2 and made.get("remaining_scraps") == 0,
		"canonical Rest transaction issues one composite and advances the cursor")
	if not made.get("ok", false):
		return {}
	return {"deck": made["deck"].duplicate(), "descriptors": made["descriptors"].duplicate(true),
		"next_stitch_id": made["next_stitch_id"], "id": made["stitched_id"]}


func _stitched_snapshot(fight: Dictionary, rng: RandomNumberGenerator, ledger: Dictionary,
		ids: Array[String], records: Array[Dictionary], gold: int) -> Array:
	return [fight["party"].get_heroes(), fight["enemies"].get_enemies(),
		fight["battle"].get_outcome(), rng.seed, ledger["deck"].duplicate(),
		ledger["descriptors"].duplicate(true), ledger["next_stitch_id"],
		records.duplicate(true), ids.duplicate(true), gold]


## A composite already owned at Rest is one ordinary run deck member: both Fight
## and Elite still prepare the normal seeded reward, pick and Skip keep it exactly
## once, and every malformed ledger fails closed before any RNG draw or payout.
func _test_stitched_rewards(definitions: Array, ids: Array[String], deck: Array[String]) -> void:
	var records: Array[Dictionary] = _pool_records()
	var ledger := _stitched_ledger(deck)
	if ledger.is_empty():
		return
	var composite: String = ledger["id"]
	var source_deck: Array = ledger["deck"].duplicate()
	var source_descriptors: Dictionary = ledger["descriptors"].duplicate(true)
	_check(ledger["deck"].count(composite) == 1 and ledger["deck"].size() == deck.size() - 1
		and ledger["descriptors"].has(composite),
		"authentic composite replaces exactly the two consumed originals")
	for elite in [false, true]:
		var label: String = "Elite" if elite else "Fight"
		var count: int = 2 if elite else 1
		var fight := _fight(definitions, count)
		_win(fight)
		var rng := _rng(615223)
		var service: RunFightVictoryRewards
		if elite:
			service = _elite_session(fight, rng, ids, records, ledger["deck"], 64,
				TRINKET_POOL, OWNED_TRINKETS, ledger["descriptors"], ledger["next_stitch_id"])
		else:
			service = _session(fight, rng, ids, records, ledger["deck"], 64, false,
				ledger["descriptors"], ledger["next_stitch_id"])
		var before := _stitched_snapshot(fight, rng, ledger, ids, records, 64)
		var oracle := _weighted_oracle(ids, records, 615223, elite, TRINKET_POOL, OWNED_TRINKETS)
		var published := service.prepare()
		_check(published.get("ok", false),
			label + ": authentic composite prepares the normal seeded reward")
		_check(published.get("gold_award") == oracle["gold"]
			and published.get("offers") == oracle["offers"]
			and published.get("trinket_drop_id", "") == oracle["trinket_drop_id"],
			label + ": composite deck keeps the exact gold, offers and drop")
		_check(rng.state == oracle["rng_state"],
			label + ": composite deck consumes exactly the normal staged draws")
		var held_state: int = rng.state
		_check(service.prepare() == published and rng.state == held_state,
			label + ": repeated composite prepare never rerolls")
		_check(_stitched_snapshot(fight, rng, ledger, ids, records, 64) == before,
			label + ": preparation mutates no actors, deck, ledger, records or gold")
		var offered: String = published["offers"][0]["id"]
		var expected_deck: Array = ledger["deck"].duplicate()
		expected_deck.append(offered)
		var claimed := service.choose(offered)
		_check(claimed.get("ok", false) and claimed.get("deck") == expected_deck
			and claimed.get("gold") == 64 + oracle["gold"],
			label + ": composite deck still claims one offered card and one award")
		_check(claimed.get("deck").count(composite) == 1,
			label + ": claimed deck keeps the composite exactly once")
		_check(not service.choose(offered).get("ok") and not service.choose("").get("ok"),
			label + ": composite reward cannot pay twice")
		_check(service.prepare() == published and rng.state == held_state,
			label + ": settled composite reward replays nothing")
		_check(rng.randi() == oracle["next"], label + ": next RNG value matches the oracle")
		var skip_fight := _fight(definitions, count)
		_win(skip_fight)
		var skip_rng := _rng(615223)
		var skip_service: RunFightVictoryRewards
		if elite:
			skip_service = _elite_session(skip_fight, skip_rng, ids, records, ledger["deck"], 64,
				TRINKET_POOL, OWNED_TRINKETS, ledger["descriptors"], ledger["next_stitch_id"])
		else:
			skip_service = _session(skip_fight, skip_rng, ids, records, ledger["deck"], 64, false,
				ledger["descriptors"], ledger["next_stitch_id"])
		var skip_published := skip_service.prepare()
		var skipped := skip_service.choose("")
		var expected_skip_trinkets: Array = OWNED_TRINKETS.duplicate() if elite else []
		if elite:
			expected_skip_trinkets.append(skip_published["trinket_drop_id"])
		_check(skip_published.get("ok", false) and skipped.get("ok", false)
			and skipped.get("skipped", false) and skipped.get("deck") == ledger["deck"]
			and skipped.get("deck").count(composite) == 1
			and skipped.get("gold") == 64 + skip_published["gold_award"]
			and skipped.get("trinkets") == expected_skip_trinkets,
			label + ": explicit Skip keeps the composite once and pays exactly once")
		_check(ledger["deck"] == source_deck and ledger["descriptors"] == source_descriptors,
			label + ": settlements never rewrite the source run ledger")

	# Malformed ledgers must reject before any draw, payout or ledger edit.
	var win := _fight(definitions)
	_win(win)
	var tampered_effect: Dictionary = source_descriptors.duplicate(true)
	tampered_effect[composite]["first_half"]["effects"]["damage"] = 999
	_reject("stitched tampered half effect", win, _rng(), ids, records, source_deck, 100,
		false, [], [], tampered_effect, ledger["next_stitch_id"])
	var tampered_cost: Dictionary = source_descriptors.duplicate(true)
	tampered_cost[composite]["cost"] = 0
	_reject("stitched tampered shared cost", win, _rng(), ids, records, source_deck, 100,
		false, [], [], tampered_cost, ledger["next_stitch_id"])
	var swapped: Dictionary = source_descriptors.duplicate(true)
	var first_half: Dictionary = swapped[composite]["first_half"].duplicate(true)
	swapped[composite]["first_half"] = swapped[composite]["second_half"].duplicate(true)
	swapped[composite]["second_half"] = first_half
	_reject("stitched swapped authored halves", win, _rng(), ids, records, source_deck, 100,
		false, [], [], swapped, ledger["next_stitch_id"])
	var forged_owners: Dictionary = source_descriptors.duplicate(true)
	forged_owners[composite]["owners"] = ["warden", "warden"]
	_reject("stitched same-owner half pair", win, _rng(), ids, records, source_deck, 100,
		false, [], [], forged_owners, ledger["next_stitch_id"])
	var orphan: Dictionary = source_descriptors.duplicate(true)
	var orphan_copy: Dictionary = source_descriptors[composite].duplicate(true)
	orphan_copy["id"] = "stitched_000002"
	orphan["stitched_000002"] = orphan_copy
	_reject("stitched registry entry without a deck member", win, _rng(), ids, records,
		source_deck, 100, false, [], [], orphan, 3)
	var forged_deck: Array = source_deck.duplicate()
	forged_deck.append("stitched_000009")
	_reject("stitched_ prefix ID outside the registry", win, _rng(), ids, records,
		forged_deck, 100, false, [], [], source_descriptors, ledger["next_stitch_id"])
	var duplicate_deck: Array = source_deck.duplicate()
	duplicate_deck.append(composite)
	_reject("duplicate stitched deck copy", win, _rng(), ids, records, duplicate_deck, 100,
		false, [], [], source_descriptors, ledger["next_stitch_id"])
	_reject("stitched cursor before the owned serial", win, _rng(), ids, records, source_deck,
		100, false, [], [], source_descriptors, 1)
	var numeric_registry: Dictionary = source_descriptors.duplicate(true)
	numeric_registry[7] = source_descriptors[composite].duplicate(true)
	_reject("stitched numeric registry key", win, _rng(), ids, records, source_deck, 100,
		false, [], [], numeric_registry, ledger["next_stitch_id"])
	_reject("stitched null descriptors", win, _rng(), ids, records, source_deck, 100,
		false, [], [], null, ledger["next_stitch_id"])
	_reject("stitched wrong descriptor type", win, _rng(), ids, records, source_deck, 100,
		false, [], [], "stitched_000001", ledger["next_stitch_id"])
	_reject("stitched array descriptors", win, _rng(), ids, records, source_deck, 100,
		false, [], [], [source_descriptors[composite]], ledger["next_stitch_id"])
	_reject("stitched string cursor", win, _rng(), ids, records, source_deck, 100,
		false, [], [], source_descriptors, "2")
	_check(tampered_effect != source_descriptors and tampered_cost != source_descriptors
		and swapped != source_descriptors and forged_owners != source_descriptors
		and orphan != source_descriptors and numeric_registry != source_descriptors,
		"every malformed ledger fixture genuinely differs from the canonical ledger")
	_check(forged_deck != source_deck and duplicate_deck != source_deck,
		"both malformed deck fixtures genuinely differ from the canonical deck")
	# The same valid composite still rewards normally after every rejection.
	var retry_fight := _fight(definitions)
	_win(retry_fight)
	var retry_rng := _rng(615223)
	var retry := _session(retry_fight, retry_rng, ids, records, ledger["deck"], 64, false,
		ledger["descriptors"], ledger["next_stitch_id"])
	var retry_oracle := _weighted_oracle(ids, records, 615223, false, [], [])
	var retried := retry.prepare()
	_check(retried.get("ok", false) and retried.get("offers") == retry_oracle["offers"]
		and retried.get("gold_award") == retry_oracle["gold"]
		and retry_rng.state == retry_oracle["rng_state"],
		"fresh valid composite transaction succeeds after every rejection")
	# A stitched deck without its ledger keeps failing closed: the new inputs are
	# optional for legacy ordinary decks, never a way to admit an unknown member.
	_reject("stitched deck without its ledger", win, _rng(), ids, records, source_deck, 100)
	# Constructor copies the ledger: a caller edit after construction cannot
	# rewrite what this reward source admitted.
	var frozen_descriptors: Dictionary = source_descriptors.duplicate(true)
	var frozen_fight := _fight(definitions)
	_win(frozen_fight)
	var frozen_rng := _rng(615223)
	var frozen := _session(frozen_fight, frozen_rng, ids, records, ledger["deck"], 64, false,
		frozen_descriptors, ledger["next_stitch_id"])
	frozen_descriptors.clear()
	var frozen_oracle := _weighted_oracle(ids, records, 615223, false, [], [])
	var frozen_prepared := frozen.prepare()
	_check(frozen_prepared.get("ok", false)
		and frozen_prepared.get("offers") == frozen_oracle["offers"]
		and frozen_prepared.get("gold_award") == frozen_oracle["gold"]
		and frozen_rng.state == frozen_oracle["rng_state"],
		"constructor freezes the composite ledger beside the run deck")


func _test_pool_rejections(definitions: Array, ids: Array[String], deck: Array[String]) -> void:
	var records := _pool_records()
	var win := _fight(definitions)
	_win(win)
	_reject("weighted missing rarity", win, _rng(), ids,
		records.slice(0, 5) + [{"id": "warden_hold_the_line", "owner": "warden"}], deck, 100)
	_reject("weighted unknown rarity", win, _rng(), ids,
		records.slice(0, 5) + [{"id": "fixture_card", "owner": "warden",
			"rarity": "legendary"}], deck, 100)
	_reject("weighted blank owner", win, _rng(), ids,
		records.slice(0, 5) + [{"id": "fixture_card", "owner": "", "rarity": "common"}], deck, 100)
	_reject("weighted duplicate record", win, _rng(), ids,
		records + [records[0].duplicate(true)], deck, 100)
	_reject("weighted pool '+' candidate", win, _rng(), ids,
		records + [{"id": "warden_hold_the_line_plus", "owner": "warden",
			"rarity": "common"}], deck, 100)
	_reject("mixed records and IDs", win, _rng(), ids,
		records.slice(0, 5) + ["warden_strike"], deck, 100)
	_reject("numeric weighted record", win, _rng(), ids, records.slice(0, 5) + [7], deck, 100)
	_reject("short weighted party", win, _rng(), ids.slice(0, 2), records, deck, 100)
	_reject("party ID mismatch", win, _rng(), ["warden", "seamstress", "wrong_hero"], records, deck, 100)
	var no_warden: Array[Dictionary] = []
	for r: Dictionary in records:
		if r.get("owner") != "warden":
			no_warden.append(r)
	_reject("lack of living hero cards", win, _rng(), ids, no_warden, deck, 100)
	_reject("fewer than 3 living candidates", win, _rng(), ids, records.slice(0, 2), deck, 100)
	var all_down := _fight(definitions)
	for pos in range(1, 4):
		all_down["party"].apply_damage(pos, all_down["party"].get_hero(pos)["hp"])
	_reject("all heroes downed", all_down, _rng(), ids, records, deck, 100)


func _reject(label: String, fight: Dictionary, rng_input: Variant, party_input: Variant,
		pool_input: Variant, deck_input: Variant, gold_input: Variant,
		elite: bool = false, trinket_candidates: Variant = [],
		owned_trinkets: Variant = [], stitched_descriptors: Variant = {},
		next_stitch_id: Variant = 1) -> void:
	var ids_before = party_input.duplicate(true) if party_input is Array else party_input
	var pool_before = pool_input.duplicate(true) if pool_input is Array else pool_input
	var deck_before = deck_input.duplicate(true) if deck_input is Array else deck_input
	var descriptors_before = (stitched_descriptors.duplicate(true)
		if stitched_descriptors is Dictionary else stitched_descriptors)
	var trinkets_before = (trinket_candidates.duplicate(true)
		if trinket_candidates is Array else trinket_candidates)
	var owned_before = (owned_trinkets.duplicate(true)
		if owned_trinkets is Array else owned_trinkets)
	var actors_before := [fight["party"].get_heroes(), fight["enemies"].get_enemies(),
		fight["battle"].get_outcome()]
	var state_before: int = rng_input.state if rng_input is RandomNumberGenerator else -1
	var service: RunFightVictoryRewards
	if elite:
		service = _elite_session(fight, rng_input, party_input, pool_input, deck_input,
			gold_input, trinket_candidates, owned_trinkets, stitched_descriptors,
			next_stitch_id)
	else:
		service = _session(fight, rng_input, party_input, pool_input, deck_input,
			gold_input, false, stitched_descriptors, next_stitch_id)
	var failed := service.prepare()
	_check(not failed.get("ok", true) and failed.get("gold_award", -1) == 0
		and failed.get("offers", [1]).is_empty()
		and failed.get("trinket_drop_id", "<missing>") == "",
		label + ": no prepared payout/offers/drop")
	var expected_inventory: Array = owned_before if owned_before is Array else []
	var paid := service.choose("")
	_check(not paid["ok"] and paid["trinkets"] == expected_inventory,
		label + ": no unopened claim or trinket inventory change")
	_check(not service.choose("warden_strike")["ok"], label + ": no rejected claim")
	_check([fight["party"].get_heroes(), fight["enemies"].get_enemies(),
		fight["battle"].get_outcome()] == actors_before, label + ": no actor or result mutation")
	_check(ids_before == party_input and pool_before == pool_input and deck_before == deck_input
		and trinkets_before == trinket_candidates and owned_before == owned_trinkets,
		label + ": original ordered inputs unchanged")
	_check(descriptors_before == stitched_descriptors,
		label + ": original stitch ledger unchanged")
	if rng_input is RandomNumberGenerator:
		_check(rng_input.state == state_before, label + ": run RNG untouched")
	_check(not service.prepare()["ok"], label + ": repeated failure remains inert")


func _test_rejections(definitions: Array, ids: Array[String], deck: Array[String],
		candidates: Array[String]) -> void:
	var active := _fight(definitions, 2)
	_reject("ACTIVE", active, _rng(), ids, candidates, deck, 100)
	active["enemies"].apply_damage(1, 8)
	active["enemies"].apply_damage(2, 11)
	_check(active["battle"].get_outcome() == CombatBattleResult.ACTIVE,
		"slain-but-unobserved battle still has ACTIVE gate")
	_reject("unobserved lethal", active, _rng(), ids, candidates, deck, 100)
	var defeat := _fight(definitions)
	for pos in range(1, 4):
		defeat["party"].apply_damage(pos, defeat["party"].get_hero(pos)["hp"])
	_check(defeat["battle"].evaluate() == CombatBattleResult.DEFEAT, "observed real defeat")
	_reject("DEFEAT", defeat, _rng(), ids, candidates, deck, 100)
	var unresolved := _fight(definitions)
	for pos in range(1, 4):
		unresolved["party"].apply_damage(pos, unresolved["party"].get_hero(pos)["hp"])
	unresolved["enemies"].apply_damage(1, 8)
	_check(unresolved["battle"].evaluate() == CombatBattleResult.UNRESOLVED, "observed real tie")
	_reject("UNRESOLVED", unresolved, _rng(), ids, candidates, deck, 100)
	var win := _fight(definitions)
	_win(win)
	_reject("null RNG", win, null, ids, candidates, deck, 100)
	_reject("wrong RNG type", win, RefCounted.new(), ids, candidates, deck, 100)
	_reject("short party", win, _rng(), ids.slice(0, 2), candidates, deck, 100)
	_reject("duplicate party", win, _rng(), ["warden", "warden", "tinker"], candidates, deck, 100)
	_reject("unknown party", win, _rng(), ["warden", "seamstress", "bogus"], candidates, deck, 100)
	_reject("wrong party type", win, _rng(), ["warden", 4, "tinker"], candidates, deck, 100)
	_reject("null party", win, _rng(), null, candidates, deck, 100)
	_reject("null candidates", win, _rng(), ids, null, deck, 100)
	_reject("insufficient candidates", win, _rng(), ids, candidates.slice(0, 2), deck, 100)
	_reject("duplicate candidate", win, _rng(), ids, candidates + [candidates[0]], deck, 100)
	_reject("unknown candidate", win, _rng(), ids, candidates + ["_bogus_"], deck, 100)
	_reject("numeric candidate", win, _rng(), ids, candidates + [99], deck, 100)
	_reject("empty candidate", win, _rng(), ids, candidates + [""], deck, 100)
	_reject("null deck", win, _rng(), ids, candidates, null, 100)
	_reject("empty deck", win, _rng(), ids, candidates, [], 100)
	_reject("bad deck ID", win, _rng(), ids, candidates, deck + ["__bad__"], 100)
	_reject("numeric deck ID", win, _rng(), ids, candidates, deck + [99], 100)
	_reject("negative gold", win, _rng(), ids, candidates, deck, -1)
	_reject("fractional gold", win, _rng(), ids, candidates, deck, 10.5)
	_reject("non-number gold", win, _rng(), ids, candidates, deck, "100")
	_reject("overflowing gold", win, _rng(), ids, candidates, deck, MAX_INT)
	var near_max := _rng(902)
	var ref := _rng(902)
	var first: int = ref.randi_range(10, 20)
	_reject("actual-draw overflow", win, near_max, ids, candidates, deck, MAX_INT - first + 1)
	var elite_active := _fight(definitions, 2)
	_reject("Elite ACTIVE", elite_active, _rng(), ids, candidates, deck, 100, true,
		TRINKET_POOL, OWNED_TRINKETS)
	_reject("Elite DEFEAT", defeat, _rng(), ids, candidates, deck, 100, true,
		TRINKET_POOL, OWNED_TRINKETS)
	_reject("Elite UNRESOLVED", unresolved, _rng(), ids, candidates, deck, 100, true,
		TRINKET_POOL, OWNED_TRINKETS)
	_reject("Elite null trinket pool", win, _rng(), ids, candidates, deck, 100, true,
		null, OWNED_TRINKETS)
	_reject("Elite wrong trinket pool type", win, _rng(), ids, candidates, deck, 100, true,
		"thread_token", OWNED_TRINKETS)
	_reject("Elite numeric trinket candidate", win, _rng(), ids, candidates, deck, 100, true,
		["thread_token", 7], OWNED_TRINKETS)
	_reject("Elite blank trinket candidate", win, _rng(), ids, candidates, deck, 100, true,
		["thread_token", ""], OWNED_TRINKETS)
	_reject("Elite duplicate trinket candidate", win, _rng(), ids, candidates, deck, 100, true,
		["thread_token", "thread_token"], OWNED_TRINKETS)
	_reject("Elite null owned trinkets", win, _rng(), ids, candidates, deck, 100, true,
		TRINKET_POOL, null)
	_reject("Elite wrong owned type", win, _rng(), ids, candidates, deck, 100, true,
		TRINKET_POOL, "button_charm")
	_reject("Elite numeric owned trinket", win, _rng(), ids, candidates, deck, 100, true,
		TRINKET_POOL, [7])
	_reject("Elite blank owned trinket", win, _rng(), ids, candidates, deck, 100, true,
		TRINKET_POOL, [""])
	_reject("Elite duplicate owned trinket", win, _rng(), ids, candidates, deck, 100, true,
		TRINKET_POOL, ["button_charm", "button_charm"])
	_reject("Elite all-owned pool", win, _rng(), ids, candidates, deck, 100, true,
		TRINKET_POOL, TRINKET_POOL)
	_reject("Elite empty pool", win, _rng(), ids, candidates, deck, 100, true,
		[], OWNED_TRINKETS)
	_reject("Elite malformed card pool", win, _rng(), ids, candidates.slice(0, 2), deck, 100, true,
		TRINKET_POOL, OWNED_TRINKETS)
	_reject("Elite overflowing gold", win, _rng(), ids, candidates, deck, MAX_INT, true,
		TRINKET_POOL, OWNED_TRINKETS)
	var external_deck := deck.duplicate()
	var external_party := ids.duplicate()
	var external_pool := candidates.duplicate()
	var rng := _rng(809)
	var prepared := _session(win, rng, external_party, external_pool, external_deck, 10, false)
	var oracle := _oracle(StarterCards.new(), ids, candidates, 809, false)
	external_party.clear()
	external_pool.clear()
	external_deck.clear()
	var result := prepared.prepare()
	_check(result["ok"] and result["offers"] == oracle["offers"]
		and result["gold_award"] == oracle["gold"] and rng.state == oracle["rng_state"],
		"constructor detaches original party/candidate/deck arrays")
	_check(prepared.choose("")["deck"] == deck, "detached original source deck survives caller edits")
	seed(56323)
	var global_first := randi()
	seed(56323)
	_reject("global RNG isolation", win, _rng(), ids, candidates + ["bad"], deck, 5)
	_check(randi() == global_first, "failed preparation never draws global RNG")
	var retry_fight := _fight(definitions, 2)
	_win(retry_fight)
	var retry_rng := _rng(900423)
	var retry := _elite_session(retry_fight, retry_rng, ids, candidates, deck, 78,
		TRINKET_POOL, OWNED_TRINKETS)
	var retry_oracle := _oracle(StarterCards.new(), ids, candidates, 900423, true,
		TRINKET_POOL, OWNED_TRINKETS)
	var retried := retry.prepare()
	_check(retried["ok"] and retried["gold_award"] == retry_oracle["gold"]
		and retried["offers"] == retry_oracle["offers"]
		and retried["trinket_drop_id"] == retry_oracle["trinket_drop_id"]
		and retry_rng.state == retry_oracle["rng_state"],
		"fresh valid Elite transaction succeeds after every rejection")
	var retry_claim := retry.choose("")
	var retry_inventory: Array = OWNED_TRINKETS.duplicate()
	retry_inventory.append(retry_oracle["trinket_drop_id"])
	_check(retry_claim["ok"] and retry_claim["trinkets"] == retry_inventory
		and retry_claim["gold"] == 78 + retry_oracle["gold"],
		"retried Elite skip awards the same one cached trinket and gold")
	_test_pool_rejections(definitions, ids, deck)
