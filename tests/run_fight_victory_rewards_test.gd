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
		deck: Variant, gold: Variant, elite: bool) -> RunFightVictoryRewards:
	return RunFightVictoryRewards.new(fight["battle"], rng, ids, candidates, deck, gold, elite)


func _elite_session(fight: Dictionary, rng: Variant, ids: Variant, candidates: Variant,
		deck: Variant, gold: Variant, trinket_candidates: Variant,
		owned_trinkets: Variant) -> RunFightVictoryRewards:
	return RunFightVictoryRewards.new(fight["battle"], rng, ids, candidates, deck, gold, true,
		trinket_candidates, owned_trinkets)


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
	# Proving the next value against the oracle consumes it; record the state first
	# so the repeated prepare below cannot be excused by an already-advanced RNG.
	_check(rng.state == oracle["rng_state"],
		"RNG state equals " + ("five" if elite else "four") + " oracle draws")
	_check(rng.randi() == oracle["next"], "next RNG value matches reference oracle")
	# Above next draw was for oracle proof; repeated prepare must consume none.
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
	# A rejected pick after preparation must not have handed over the drop yet.
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
	# Same seed and data in a different input order must replay exactly.
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
		# Real CombatDeck must account for every copied card after a five-card draw.
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
	# Constructor detaches supplier-owned trinket arrays from later caller edits.
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
## two draws each (tier roll, card roll) from sorted rarity buckets, then the
## Elite drop. Never calls the reward services.
func _weighted_oracle(party: Array[String], records: Array[Dictionary], seed_value: int,
		elite: bool, trinket_candidates: Array = [], owned_trinkets: Array = []) -> Dictionary:
	var reference := _rng(seed_value)
	var gold: int = reference.randi_range(25, 35) if elite else reference.randi_range(10, 20)
	var tiers: Array[String] = ["common", "uncommon", "rare"]
	var weights := {"common": 60, "uncommon": 30, "rare": 10}
	var buckets: Dictionary = {"common": [], "uncommon": [], "rare": []}
	for record: Dictionary in records:
		var owner := String(record.get("owner", ""))
		var rarity := String(record.get("rarity", ""))
		if party.has(owner) and buckets.has(rarity):
			(buckets[rarity] as Array).append(record)
	for tier: String in tiers:
		(buckets[tier] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("id", "")) < String(b.get("id", "")))
	var offers: Array = []
	for pick in range(3):
		var weight_sum := 0
		for tier: String in tiers:
			if not (buckets[tier] as Array).is_empty():
				weight_sum += int(weights[tier])
		var roll: int = reference.randi_range(1, weight_sum)
		var chosen := ""
		var running := 0
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
	var drop := ""
	if elite:
		var trinket_ids: Array[String] = []
		for trinket_id in trinket_candidates:
			if not owned_trinkets.has(trinket_id):
				trinket_ids.append(trinket_id)
		trinket_ids.sort()
		drop = trinket_ids[reference.randi_range(0, trinket_ids.size() - 1)]
	return {"gold": gold, "offers": offers, "trinket_drop_id": drop,
		"rng_state": reference.state, "next": reference.randi()}


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
		var upgraded_deck := expected_deck.duplicate()
		upgraded_deck.append("warden_hold_the_line_plus")
		var upgrade_fight := _fight(definitions, 1)
		_win(upgrade_fight)
		var upgrade_rng := _rng(312)
		var upgrade_service := _session(upgrade_fight, upgrade_rng, ids, records,
			upgraded_deck, 10, false)
		var upgrade_state := upgrade_rng.state
		_check(not upgrade_service.prepare().get("ok", true)
			and upgrade_rng.state == upgrade_state,
			label + ": unawarded pool '+' upgrades still fail closed without RNG use")
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


func _reject(label: String, fight: Dictionary, rng_input: Variant, party_input: Variant,
		pool_input: Variant, deck_input: Variant, gold_input: Variant,
		elite: bool = false, trinket_candidates: Variant = [],
		owned_trinkets: Variant = []) -> void:
	var ids_before = party_input.duplicate(true) if party_input is Array else party_input
	var pool_before = pool_input.duplicate(true) if pool_input is Array else pool_input
	var deck_before = deck_input.duplicate(true) if deck_input is Array else deck_input
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
			gold_input, trinket_candidates, owned_trinkets)
	else:
		service = _session(fight, rng_input, party_input, pool_input, deck_input,
			gold_input, false)
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
	# Failing overflow must not consume even the would-be first draw.
	var near_max := _rng(902)
	var ref := _rng(902)
	var first: int = ref.randi_range(10, 20)
	_reject("actual-draw overflow", win, near_max, ids, candidates, deck, MAX_INT - first + 1)
	# Elite trinket lists: invalid, duplicate, blank, malformed and all-owned
	# pools all fail closed before any RNG clone or draw.
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
	# Input arrays copied at construction: later caller edits cannot alter pending choice.
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
	# A rejection leaves no partial transaction: a fresh valid Elite session
	# (same seed as the normal prepare case) still pays exactly one trinket.
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
