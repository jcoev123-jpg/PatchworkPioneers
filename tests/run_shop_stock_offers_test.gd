extends SceneTree
## Headless M04 Shop stock generation: the shipped Warden/Seamstress/Tinker
## party, the real StarterCards catalog, priced candidate pools, an
## independent sorted-pool RNG oracle, a real RunShopPurchases visit and
## fail-closed rejection paths. No live Shop screen is involved.

var failures: Array[String] = []
var checks: int = 0
const SEED: int = 55021
## Trinket IDs and prices are supplied by the caller and are not authored
## content; these fixture IDs only ever appear in this test.
const FIXTURE_TRINKETS := {
	"fixture_pin_badge": 90,
	"fixture_spare_spool": 110,
	"fixture_brass_button": 120,
	"fixture_owned_charm": 85,
}
## Prices for four starter support/draw cards newly authored into the Shop (M04 D2-1).
## These were formerly fixture fallback prices; the actual Shop JSON now carries them.
const FIXTURE_CARD_PRICES := {
	"warden_brace": 40,
	"seamstress_mend": 45,
	"seamstress_stitch_up": 45,
	"tinker_tune_up": 35,
}
const DEFAULT_FIXTURE_PRICE := 50

## Already-playable Tinker common bases admitted to the authored Shop; their
## upgrades remain Rest-only, with these independent expected effects.
const RIVET_SCATTER_SHOP_SPECS := {
	"tinker_rivet_shot": {"price": 50, "from": [2, 3], "target": "enemy_single",
		"effects": {"damage": 4, "exposed": 1}, "plus_effects": {"damage": 6, "exposed": 1}},
	"tinker_scatter_bolts": {"price": 55, "from": [3], "target": "enemy_all",
		"effects": {"damage": 3, "living_targets_only": true},
		"plus_effects": {"damage": 4, "living_targets_only": true}},
}

## Pool card prices for the three hero pools (base cards only, not + upgrades).
const POOL_CARD_PRICES := {
	# Warden pool
	"warden_hold_the_line": 55,
	"warden_pinning_jab": 50,
	"warden_heavy_thimble": 60,
	"warden_patch_guard": 45,
	"warden_quick_darn": 40,
	"warden_brass_buckle": 55,
	"warden_draw_fire": 65,
	"warden_seam_breaker": 70,
	"warden_iron_hem": 70,
	"warden_counter_stitch": 65,
	"warden_bastion_quilt": 90,
	"warden_pin_and_pound": 85,
	# Seamstress pool
	"seamstress_running_stitch": 50,
	"seamstress_needle_pin": 50,
	"seamstress_darning": 55,
	"seamstress_snag": 50,
	"seamstress_thread_whip": 55,
	"seamstress_thimble_tea": 40,
	"seamstress_hemorrhage_hem": 65,
	"seamstress_unpick": 60,
	"seamstress_blanket_stitch": 70,
	"seamstress_field_mend": 75,
	"seamstress_red_thread": 90,
	"seamstress_tailors_trance": 85,
	# Tinker pool
	"tinker_rivet_shot": 50,
	"tinker_spring_trap": 50,
	"tinker_scatter_bolts": 55,
	"tinker_spare_parts": 45,
	"tinker_long_barrel": 70,
	"tinker_spool_launcher": 55,
	"tinker_overclock": 60,
	"tinker_shrapnel_seam": 70,
	"tinker_sight_glass": 65,
	"tinker_ricochet": 65,
	"tinker_bobbin_cannon": 90,
	"tinker_snip_the_seam": 80,
}

## The eight new M04 D2-1 pool cards added to the authored Shop JSON.
const NEW_POOL_SPECS := {
	"seamstress_snag": {"owner": "seamstress", "price": 50, "cost": 1, "from": [2, 3], "target": "enemy_single", "to": [1, 2, 3], "effects": {"unravel": 3, "weak": 1}, "rarity": "common"},
	"seamstress_unpick": {"owner": "seamstress", "price": 60, "cost": 1, "from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3], "effects": {"unravel": 5}, "rarity": "uncommon"},
	"seamstress_tailors_trance": {"owner": "seamstress", "price": 85, "cost": 1, "from": [2, 3], "target": "self", "to": [], "effects": {"energy": 1, "draw": 2}, "rarity": "rare"},
	"tinker_spare_parts": {"owner": "tinker", "price": 45, "cost": 0, "from": [2, 3], "target": "self", "to": [], "effects": {"block": 3, "draw": 1}, "rarity": "common"},
	"tinker_long_barrel": {"owner": "tinker", "price": 70, "cost": 2, "from": [3], "target": "enemy_single", "to": [1, 2, 3], "effects": {"damage": 12}, "rarity": "common"},
	"tinker_overclock": {"owner": "tinker", "price": 60, "cost": 0, "from": [1, 2, 3], "target": "self", "to": [], "effects": {"gain_energy": 1, "self_hp_loss": 3}, "rarity": "uncommon"},
	"tinker_sight_glass": {"owner": "tinker", "price": 65, "cost": 1, "from": [2, 3], "target": "enemy_single", "to": [1, 2, 3], "effects": {"exposed": 2, "draw": 1}, "rarity": "uncommon"},
	"tinker_bobbin_cannon": {"owner": "tinker", "price": 90, "cost": 3, "from": [3], "target": "enemy_single", "to": [1, 2, 3], "effects": {"damage": 20}, "rarity": "rare"},
}

## The four playable Warden pool base cards newly authored into the Shop (M04 D2-1).
## Rules copied from data/cards/warden_pool_cards.gd; prices are the established
## Warden candidate quotes. Only base IDs are stocked, never _plus upgrades.
const WARDEN_STOCK_SPECS := {
	"warden_heavy_thimble": {"owner": "warden", "price": 60, "cost": 2, "from": [1], "target": "enemy_single", "to": [1, 2], "effects": {"damage": 11}, "rarity": "common"},
	"warden_pin_and_pound": {"owner": "warden", "price": 85, "cost": 2, "from": [1], "target": "enemy_single", "to": [1, 2, 3], "effects": {"damage": 9, "hits": 2}, "rarity": "rare"},
	"warden_draw_fire": {"owner": "warden", "price": 65, "cost": 1, "from": [1], "target": "self", "to": [], "effects": {"block": 6, "guarding": true, "duration": "until_next_turn"}, "rarity": "uncommon"},
	"warden_counter_stitch": {"owner": "warden", "price": 65, "cost": 1, "from": [1, 2], "target": "self", "to": [], "effects": {"block": 5, "thorns": 3, "duration": "until_next_turn"}, "rarity": "uncommon"},
}

## Seven already-playable Seamstress pool bases newly stocked in the real Shop.
## Prices are the established POOL_CARD_PRICES quotes. Check both base and
## Rest-upgraded effects against the independent authored catalog.
const SEAMSTRESS_STOCK_SPECS := {
	"seamstress_running_stitch": {"owner": "seamstress", "price": 50, "cost": 1, "plus_cost": 1, "from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3], "effects": {"damage": 2, "bleed": 3}, "plus_effects": {"damage": 3, "bleed": 4}, "rarity": "common"},
	"seamstress_darning": {"owner": "seamstress", "price": 55, "cost": 1, "plus_cost": 1, "from": [1, 2, 3], "target": "ally_single", "to": [], "effects": {"heal": 4, "block": 3}, "plus_effects": {"heal": 6, "block": 4}, "rarity": "common"},
	"seamstress_thimble_tea": {"owner": "seamstress", "price": 40, "cost": 0, "plus_cost": 0, "from": [2, 3], "target": "ally_single", "to": [], "effects": {"heal": 3}, "plus_effects": {"heal": 4}, "rarity": "common"},
	"seamstress_hemorrhage_hem": {"owner": "seamstress", "price": 65, "cost": 2, "plus_cost": 1, "from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3], "effects": {"bleed_multiplier": 2}, "plus_effects": {"bleed_multiplier": 2}, "rarity": "uncommon"},
	"seamstress_blanket_stitch": {"owner": "seamstress", "price": 70, "cost": 2, "plus_cost": 2, "from": [2, 3], "target": "enemy_all", "to": [1, 2, 3], "effects": {"bleed": 2}, "plus_effects": {"bleed": 3}, "rarity": "uncommon"},
	"seamstress_field_mend": {"owner": "seamstress", "price": 75, "cost": 2, "plus_cost": 2, "from": [2, 3], "target": "party_all", "to": [], "effects": {"heal": 4}, "plus_effects": {"heal": 6}, "rarity": "uncommon"},
	"seamstress_red_thread": {"owner": "seamstress", "price": 90, "cost": 2, "plus_cost": 2, "from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3], "effects": {"bleed": 6, "exposed": 1}, "plus_effects": {"bleed": 8, "exposed": 1}, "rarity": "rare"},
}

## The three M04 D2-2 cross-hero Pinned enabler COMMON base cards stocked in the
## Shop. Rules are copied verbatim from data/cards/{warden,seamstress,tinker}_pool_cards.gd;
## the Tinker definition keeps its explicit nested Pinned contract, and every
## entry is a base ID (never _plus) at the established 50-gold pool quote.
const PINNED_STOCK_SPECS := {
	"warden_pinning_jab": {"owner": "warden", "price": 50, "cost": 1, "from": [1, 2], "target": "enemy_single", "to": [1], "effects": {"damage": 4, "pinned": true}, "rarity": "common"},
	"seamstress_needle_pin": {"owner": "seamstress", "price": 50, "cost": 1, "from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3], "effects": {"damage": 3, "pinned": true}, "rarity": "common"},
	"tinker_spring_trap": {"owner": "tinker", "price": 50, "cost": 1, "from": [2, 3], "target": "enemy_single", "to": [1, 2, 3], "effects": {"damage": 3, "pinned": {"pinner_identity": "source_hero", "trigger": "next_attack_by_different_hero", "bonus_damage": 5, "bonus_timing": "before_weak_exposed", "consume_once": true, "same_hero_consumes": false}}, "rarity": "common"},
}

## The three M04 Unravel setup/payoff bases stocked by this task: the Warden
## Seam Breaker enabler and the Tinker Spool Launcher / Snip the Seam pair.
## Rules are copied verbatim from data/cards/{warden,tinker}_pool_cards.gd; the
## Snip half-threshold condition reads the live CombatUnravel target threshold.
## Only base IDs are stocked, never their _plus upgrades.
const UNRAVEL_STOCK_SPECS := {
	"warden_seam_breaker": {
		"owner": "warden", "price": 70, "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [1, 2], "to": [1, 2],
		"target": "enemy_single",
		"effects": {"damage": 7, "unravel": 4},
		"plus_effects": {"damage": 10, "unravel": 6},
	},
	"tinker_spool_launcher": {
		"owner": "tinker", "price": 55, "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [2, 3], "to": [1, 2, 3],
		"target": "enemy_single",
		"effects": {"damage": 3, "unravel": 3},
		"plus_effects": {"damage": 4, "unravel": 4},
	},
	"tinker_snip_the_seam": {
		"owner": "tinker", "price": 80, "rarity": "rare",
		"cost": 1, "plus_cost": 1, "from": [2, 3], "to": [1, 2, 3],
		"target": "enemy_single",
		"effects": {"damage": 5, "conditional_damage": {
			"damage": 15, "operator": "or",
			"conditions": [
				{"status": "unravelled"},
				{"gauge": "unravel", "comparison": "at_least_half",
					"threshold": "current_target_threshold"},
			],
		}},
		"plus_effects": {"damage": 7, "conditional_damage": {
			"damage": 20, "operator": "or",
			"conditions": [
				{"status": "unravelled"},
				{"gauge": "unravel", "comparison": "at_least_half",
					"threshold": "current_target_threshold"},
			],
		}},
	},
}

## Every pre-existing authored card candidate and its established Shop quote.
## These entries must survive the candidate-pool expansion unchanged.
const EXISTING_SHOP_CARDS := {
	"warden_strike": {"owner": "warden", "price": 50},
	"warden_shield_bash": {"owner": "warden", "price": 65},
	"seamstress_prick": {"owner": "seamstress", "price": 50},
	"tinker_pop_shot": {"owner": "tinker", "price": 50},
	"tinker_scrap_bomb": {"owner": "tinker", "price": 65},
	"warden_hold_the_line": {"owner": "warden", "price": 55},
	"warden_patch_guard": {"owner": "warden", "price": 45},
	"warden_quick_darn": {"owner": "warden", "price": 40},
	"warden_brass_buckle": {"owner": "warden", "price": 55},
	"warden_iron_hem": {"owner": "warden", "price": 70},
	"warden_bastion_quilt": {"owner": "warden", "price": 90},
	"seamstress_thread_whip": {"owner": "seamstress", "price": 55},
	"warden_brace": {"owner": "warden", "price": 40},
	"seamstress_mend": {"owner": "seamstress", "price": 45},
	"seamstress_stitch_up": {"owner": "seamstress", "price": 45},
	"tinker_tune_up": {"owner": "tinker", "price": 35},
}

## Every pre-existing authored trinket candidate and its established price.
const EXISTING_SHOP_TRINKETS := {
	"stitched_badge": 100,
	"spare_spool": 100,
	"quilted_coat": 100,
}

## The v3 base cards appended to the shipped priced Shop catalog.
## IDs, owners and rarities are already authored in the eight hero pool
## catalogs; only the bounded quote is new. Upgrades are never stocked.
const V3_PEDDLER_STOCK_SPECS := {
	"lantern_monk_moth_lure": {"owner": "lantern_monk", "price": 50, "rarity": "common"},
	"rag_duelist_velvet_feint": {"owner": "rag_duelist", "price": 50, "rarity": "common"},
	"scarecrow_re_stuff": {"owner": "scarecrow", "price": 65, "rarity": "uncommon"},
	"yarn_ranger_unspool": {"owner": "yarn_ranger", "price": 65, "rarity": "uncommon"},
	"button_golem_pop_button": {"owner": "button_golem", "price": 50, "rarity": "common"},
	"yarn_ranger_snare_net": {"owner": "yarn_ranger", "price": 65, "rarity": "uncommon"},
}

## The shipped Yarn Ranger Peddler bases, with their authored pool rules.
## All are cost-1/2 commons or uncommons; Snare Net applies Tangled 1 (+2 as +)
## and Unspool deals 7 (10 as +) to Tangled enemies, both as cost-2 enemy_all
## cards from seats 2-3. Knit Shield is the cost-1 ally Block-and-draw base
## stocked by the look-driven Peddler task. Only the base IDs are priced stock;
## the + upgrades stay Rest-only.
const YARN_RANGER_PEDDLER_SPECS := {
	"yarn_ranger_snare_net": {
		"owner": "yarn_ranger", "price": 65, "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [2, 3], "to": [1, 2, 3],
		"target": "enemy_all",
		"effects": {"tangled": 1, "living_targets_only": true},
		"plus_effects": {"tangled": 2, "living_targets_only": true},
	},
	"yarn_ranger_unspool": {
		"owner": "yarn_ranger", "price": 65, "rarity": "uncommon",
		"cost": 2, "plus_cost": 2, "from": [2, 3], "to": [1, 2, 3],
		"target": "enemy_all",
		"effects": {"damage": 7, "requires_target_status": "tangled",
			"living_targets_only": true},
		"plus_effects": {"damage": 10, "requires_target_status": "tangled",
			"living_targets_only": true},
	},
	"yarn_ranger_knit_shield": {
		"owner": "yarn_ranger", "price": 50, "rarity": "common",
		"cost": 1, "plus_cost": 1, "from": [1, 2, 3], "to": [],
		"target": "ally_single",
		"effects": {"block": 6, "draw": 1},
		"plus_effects": {"block": 8, "draw": 1},
	},
}


func _initialize() -> void:
	var party := _load_party()
	var deck := _load_deck()
	var catalog := StarterCards.new()
	_check(party.size() == 3 and party.has("warden") and party.has("seamstress") and party.has("tinker"),
		"real starter party contains the three distinct active heroes")
	var deck_is_authored := deck.size() > 0
	for card_id in deck:
		if not catalog.has_card(card_id):
			deck_is_authored = false
	_check(deck_is_authored, "the authored starter deck holds real catalog cards")
	if party.size() == 3 and deck.size() > 0:
		_test_generated_stock(party, deck, catalog)
		_test_attack_patch_stock(party, catalog)
		_test_seeded_replay(party, catalog)
		_test_owned_fallback(party, deck, catalog)
		_test_purchases(party, deck, catalog)
		_test_rejections(party, catalog)
		_test_authored_shop_pool(party, catalog)
		_test_mixed_pool_generation(party, deck, catalog)
		_test_pool_purchase(party, deck, catalog)
		_test_pool_rejections(party, catalog)
		_test_new_starter_shop_offers_and_purchases(party, deck, catalog)
		_test_new_pool_shop_offers_and_purchases(party, deck, catalog)
		_test_warden_pool_shop_offers_and_purchases(party, deck, catalog)
		_test_seamstress_shop_stock_and_purchases(party, deck, catalog)
		_test_pinned_enabler_shop_offers_and_purchases(party, deck, catalog)
		_test_unravel_trio_shop_offers_and_purchases(party, deck, catalog)
		_test_tinker_attack_shop_stock(party, deck, catalog)
		_test_peddler_cards(party, deck, catalog)
		_test_peddler_stock(party, deck, catalog)
		_test_v3_peddler_party_stock(deck, catalog)
		_test_yarn_ranger_peddler_stock(deck, catalog)
	else:
		_check(false, "preconditions for non-vacuous shop stock tests failed")
	if failures.is_empty():
		print("run_shop_stock_offers_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			print("FAILURE: ", failure)
		print("run_shop_stock_offers_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _test_attack_patch_stock(party: Array[String], catalog: StarterCards) -> void:
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/shop/initial_offers.json"))
	var definitions := RunAuthoredPatchDefinitions.load_definitions()
	_check(not definitions.is_empty(), "all authored patch catalogs validate before stock assertions")
	var p8_ids := {"relay_bobbin": true, "hearth_lining": true}
	var seen := {}
	for definition in definitions:
		var id: String = definition.id
		if p8_ids.has(id):
			continue
		var matches: Array = authored.trinkets.filter(func(entry): return entry.id == id)
		_check(matches.size() == 1 and _whole_price(matches[0].price) == 100,
			"shared patch candidate retained exactly once at 100 gold: " + id)
	for value in range(1, 101):
		var rng := _rng(value)
		var oracle_rng := _rng(value)
		var expected: Dictionary = _oracle(catalog, party, authored.cards, authored.trinkets, [], oracle_rng)
		var actual: Dictionary = RunShopStockOffers.generate(rng, party,
			authored.cards, authored.trinkets, [])
		_check(actual.get("ok") == true and actual.trinkets == expected.trinkets
			and rng.state == oracle_rng.state, "expanded patch pool follows seeded stock oracle")
		for offer in actual.get("trinkets", []):
			seen[offer.id] = true
	for definition in definitions:
		var id: String = definition.id
		if p8_ids.has(id):
			continue
		_check(seen.has(id), "genuine seeded stock admits patch " + id)


func _load_party() -> Array[String]:
	var result: Array[String] = []
	var file := FileAccess.open("res://data/heroes/starter_party.json", FileAccess.READ)
	_check(file != null, "starter_party.json opened")
	if file == null:
		return result
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	_check(data is Array, "starter party is JSON array")
	if data is Array:
		for hero in data:
			if hero is Dictionary and hero.get("id") is String:
				result.append(hero["id"])
	return result


func _load_deck() -> Array[String]:
	var result: Array[String] = []
	var file := FileAccess.open("res://data/cards/starter_deck.json", FileAccess.READ)
	_check(file != null, "starter_deck.json opened")
	if file == null:
		return result
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	_check(data is Array, "starter deck is JSON array")
	if data is Array:
		for id in data:
			if id is String:
				result.append(id)
	return result


func _catalog_snapshot(catalog: StarterCards) -> Dictionary:
	var result := {}
	for card_id in catalog.get_all_card_ids():
		result[card_id] = catalog.get_definition(card_id)
	return result


func _rng(seed_value: int = SEED) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Reads a whole price out of JSON without truncating a fractional value.
func _whole_price(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return int(value) if value >= 0 else -1
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value >= 0.0 and value == floor(value):
		return int(value)
	return -1


## The authored shop pool, used only for the prices it already carries.
func _authored_shop_offers() -> Dictionary:
	var file := FileAccess.open("res://data/shop/initial_offers.json", FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	return data if data is Dictionary else {}


## A priced candidate pool of ONLY starter cards owned by the party (for legacy regression tests).
func _starter_only_pool(catalog: StarterCards, party: Array[String], authored: Dictionary) -> Array:
	var authored_prices := {}
	for entry in authored.get("cards", []):
		if entry is Dictionary and entry.get("id") is String:
			var price := _whole_price(entry.get("price"))
			if price >= 0:
				authored_prices[entry["id"]] = price
	var pool: Array = []
	# Starter cards only
	for card_id in catalog.get_all_card_ids():
		var definition: Dictionary = catalog.get_definition(card_id)
		var owner: String = definition.get("owner", "")
		if not party.has(owner):
			continue
		var price: int = authored_prices.get(card_id, FIXTURE_CARD_PRICES.get(card_id, DEFAULT_FIXTURE_PRICE))
		pool.append({"id": card_id, "owner": owner, "price": price})
	return pool


## A priced candidate pool of real authored cards owned by the party (starter + pool cards).
func _card_pool(catalog: StarterCards, party: Array[String], authored: Dictionary) -> Array:
	var authored_prices := {}
	for entry in authored.get("cards", []):
		if entry is Dictionary and entry.get("id") is String:
			var price := _whole_price(entry.get("price"))
			if price >= 0:
				authored_prices[entry["id"]] = price
	var pool: Array = []
	var warden_pool := WardenPoolCards.new()
	var seamstress_pool := SeamstressPoolCards.new()
	var tinker_pool := TinkerPoolCards.new()
	# Starter cards
	for card_id in catalog.get_all_card_ids():
		var definition: Dictionary = catalog.get_definition(card_id)
		var owner: String = definition.get("owner", "")
		if not party.has(owner):
			continue
		var price: int = authored_prices.get(card_id, FIXTURE_CARD_PRICES.get(card_id, DEFAULT_FIXTURE_PRICE))
		pool.append({"id": card_id, "owner": owner, "price": price})
	# Warden pool base cards
	for card_id in warden_pool.get_base_ids():
		var definition: Dictionary = warden_pool.get_definition(card_id)
		var owner: String = definition.get("owner", "")
		if not party.has(owner):
			continue
		var price: int = POOL_CARD_PRICES.get(card_id, DEFAULT_FIXTURE_PRICE)
		pool.append({"id": card_id, "owner": owner, "price": price})
	# Seamstress pool base cards
	for card_id in seamstress_pool.get_base_ids():
		var definition: Dictionary = seamstress_pool.get_definition(card_id)
		var owner: String = definition.get("owner", "")
		if not party.has(owner):
			continue
		var price: int = POOL_CARD_PRICES.get(card_id, DEFAULT_FIXTURE_PRICE)
		pool.append({"id": card_id, "owner": owner, "price": price})
	# Tinker pool base cards
	for card_id in tinker_pool.get_pool_card_ids():
		var definition: Dictionary = tinker_pool.get_definition(card_id)
		var owner: String = definition.get("owner", "")
		if not party.has(owner):
			continue
		var price: int = POOL_CARD_PRICES.get(card_id, DEFAULT_FIXTURE_PRICE)
		pool.append({"id": card_id, "owner": owner, "price": price})
	return pool


## A priced candidate pool of supplied trinket IDs.
func _trinket_pool(authored: Dictionary) -> Array:
	var pool: Array = []
	for entry in authored.get("trinkets", []):
		if entry is Dictionary and entry.get("id") is String:
			var price := _whole_price(entry.get("price"))
			if price >= 0:
				pool.append({"id": entry["id"], "price": price})
	for trinket_id in FIXTURE_TRINKETS:
		pool.append({"id": trinket_id, "price": FIXTURE_TRINKETS[trinket_id]})
	return pool


func _owned_trinkets() -> Array[String]:
	return ["fixture_owned_charm"]


func _pool_price(pool: Array, id: String) -> int:
	for entry in pool:
		if entry is Dictionary and entry.get("id") == id:
			return int(entry.get("price", -1))
	return -1


func _pool_has_id(pool: Array, id: String) -> bool:
	for entry in pool:
		if entry is Dictionary and entry.get("id") == id:
			return true
	return false


## A copy of the candidate pool with one entry replaced, so a malformed
## candidate is the only possible reason the whole call fails.
func _with_card(pool: Array, index: int, entry: Variant) -> Array:
	var copy := pool.duplicate(true)
	copy[index] = entry
	return copy


func _with_trinket(pool: Array, index: int, entry: Variant) -> Array:
	var copy := pool.duplicate(true)
	copy[index] = entry
	return copy


## A copy of the candidate pool with one extra entry appended, so a malformed
## extra record is the only possible reason the whole call fails.
func _with_appended(pool: Array, entry: Variant) -> Array:
	var copy := pool.duplicate(true)
	copy.append(entry)
	return copy


## An independent copy of the candidate pool in reverse order.
func _reversed(pool: Array) -> Array:
	var copy := pool.duplicate(true)
	copy.reverse()
	return copy


## Every authored hero catalog, starter plus all eight v3 pool catalogs.
func _all_party_catalogs() -> Array:
	return [
		StarterCards.new(),
		WardenPoolCards.new(),
		SeamstressPoolCards.new(),
		TinkerPoolCards.new(),
		LanternMonkPoolCards.new(),
		RagDuelistPoolCards.new(),
		ScarecrowPoolCards.new(),
		YarnRangerPoolCards.new(),
		ButtonGolemPoolCards.new(),
	]


## Resolves a card ID against every authored catalog without assuming a hero.
func _catalog_definition(card_id: String, catalogs: Array) -> Dictionary:
	for catalog: Variant in catalogs:
		if catalog.has_card(card_id):
			return catalog.get_definition(card_id)
	return {}


## An independent implementation of the expected stock: sorted pools, five
## card draws and then two trinket draws, each without replacement.
func _oracle(catalog: StarterCards, party: Array[String], card_pool: Array, trinket_pool: Array,
		owned: Array, rng: RandomNumberGenerator) -> Dictionary:
	var catalogs := _all_party_catalogs()
	var card_ids: Array[String] = []
	for entry in card_pool:
		var card_id: String = entry["id"]
		var owner: String = _catalog_definition(card_id, catalogs).get("owner", "")
		if party.has(owner):
			card_ids.append(card_id)
	card_ids.sort()
	var cards: Array = []
	for _pick in range(5):
		var index: int = rng.randi_range(0, card_ids.size() - 1)
		var card_id: String = card_ids[index]
		card_ids.remove_at(index)
		var definition: Dictionary = _catalog_definition(card_id, catalogs)
		cards.append({"id": card_id, "owner": definition["owner"], "price": _pool_price(card_pool, card_id)})

	var trinket_ids: Array[String] = []
	for entry in trinket_pool:
		var trinket_id: String = entry["id"]
		if not owned.has(trinket_id):
			trinket_ids.append(trinket_id)
	trinket_ids.sort()
	var owned_ids: Array[String] = []
	for entry in trinket_pool:
		if owned.has(entry["id"]):
			owned_ids.append(entry["id"])
	owned_ids.sort()
	var trinkets: Array = []
	for tier in [trinket_ids, owned_ids]:
		while not tier.is_empty() and trinkets.size() < 2:
			var index: int = rng.randi_range(0, tier.size() - 1)
			var trinket_id: String = tier.pop_at(index)
			trinkets.append({"id": trinket_id, "price": _pool_price(trinket_pool, trinket_id)})
	return {"cards": cards, "trinkets": trinkets}


func _test_owned_fallback(party: Array[String], deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var cards := _starter_only_pool(catalog, party, authored)
	var pool: Array = authored.get("trinkets", [])
	_check(pool.size() >= 2, "authored pool supplies two fallback candidates")
	if pool.size() < 2:
		return
	# Two total IDs must succeed with zero, one or both already owned.
	var two := pool.slice(0, 2)
	for owned in [[], [two[0].id], [two[1].id], [two[0].id, two[1].id]]:
		for candidates in [two, _trinket_pool(authored)]:
			var before: Array = candidates.duplicate(true)
			var reversed: Array = candidates.duplicate(true)
			reversed.reverse()
			var rng := _rng()
			var replay_rng := _rng()
			var oracle_rng := _rng()
			var result := RunShopStockOffers.generate(rng, party, cards, candidates, owned)
			var replay := RunShopStockOffers.generate(replay_rng, party, cards, reversed, owned)
			var expected := _oracle(catalog, party, cards, candidates, owned, oracle_rng)
			_check(result.ok and result.cards.size() == 5 and result.trinkets.size() == 2,
				"owned authored stock retains five cards and two trinkets")
			if not result.ok:
				continue
			_check(result.cards == expected.cards and result.trinkets == expected.trinkets,
				"ownership tiers match independent oracle")
			_check(result == replay and rng.state == replay_rng.state and rng.state == oracle_rng.state,
				"ownership fallback replays offers and RNG across reordered pools")
			_check(result.trinkets[0].id != result.trinkets[1].id, "fallback listings remain unique")
			var unowned_count := 0
			for entry in candidates:
				if not owned.has(entry.id):
					unowned_count += 1
			for index in range(mini(unowned_count, 2)):
				_check(not owned.has(result.trinkets[index].id), "unowned tier always precedes owned tier")
			var shop := RunShopPurchases.new(party, deck, owned, 400, result.cards, result.trinkets)
			_check(shop.is_valid(), "fallback stock admits real purchase service")
			for listing in shop.get_stock().get("trinkets", []):
				_check(listing.sold == owned.has(listing.id), "only already-owned fallback listings start sold")
			_check(candidates == before, "fallback leaves candidate inputs unchanged")
	# Validation must include owned candidates even when two unowned ones exist.
	var malformed := _trinket_pool(authored)
	malformed.append({"id": "owned_bad_price", "price": 1.5})
	_reject("malformed owned fallback", _rng(), party, cards, malformed, ["owned_bad_price"])
	_reject("single unowned candidate", _rng(), party, cards, [two[0]], [])


func _test_generated_stock(party: Array[String], deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var card_pool := _starter_only_pool(catalog, party, authored)
	var trinket_pool := _trinket_pool(authored)
	var owned := _owned_trinkets()
	var warden_pool := WardenPoolCards.new()
	var seamstress_pool := SeamstressPoolCards.new()
	var tinker_pool := TinkerPoolCards.new()
	var unowned := 0
	for entry in trinket_pool:
		if not owned.has(entry["id"]):
			unowned += 1
	_check(card_pool.size() >= 5, "at least five party-owned priced card candidates are supplied")
	_check(unowned >= 2, "at least two unowned trinket candidates are supplied")
	_check(card_pool.size() > 5, "the card pool holds more than the five offered cards")
	_check(unowned > 2, "the trinket pool holds more than the two offered trinkets")

	var catalog_before := _catalog_snapshot(catalog)
	var card_pool_before := card_pool.duplicate(true)
	var trinket_pool_before := trinket_pool.duplicate(true)
	var owned_before := owned.duplicate(true)
	var rng := _rng()
	var result: Dictionary = RunShopStockOffers.generate(rng, party, card_pool, trinket_pool, owned)
	_check(result.get("ok", false), "valid pools generate a stock")
	var cards: Array = result.get("cards", [])
	var trinkets: Array = result.get("trinkets", [])
	_check(cards.size() == 5, "exactly five card offers")
	_check(trinkets.size() == 2, "exactly two trinket offers")

	var card_ids: Array[String] = []
	for offer in cards:
		_check(offer is Dictionary and offer.size() == 3, "card offer holds only id, owner and price")
		var card_id: String = offer.get("id", "")
		card_ids.append(card_id)
		# Look up the card definition across all four catalogs.
		var definition: Dictionary = {}
		if catalog.has_card(card_id):
			definition = catalog.get_definition(card_id)
		elif warden_pool.has_card(card_id):
			definition = warden_pool.get_definition(card_id)
		elif seamstress_pool.has_card(card_id):
			definition = seamstress_pool.get_definition(card_id)
		elif tinker_pool.has_card(card_id):
			definition = tinker_pool.get_definition(card_id)
		_check(not definition.is_empty(), "offered card exists in the authored catalog: " + card_id)
		_check(offer.get("owner") == definition.get("owner"), "offer uses the catalog owner: " + card_id)
		_check(party.has(offer.get("owner")), "offered card belongs to the party: " + card_id)
		_check(offer.get("price") == _pool_price(card_pool, card_id),
			"offer keeps the supplied price: " + card_id)
	_check(card_ids.size() == 5 and card_ids[0] != card_ids[1] and card_ids[0] != card_ids[2]
			and card_ids[0] != card_ids[3] and card_ids[0] != card_ids[4]
			and card_ids[1] != card_ids[2] and card_ids[1] != card_ids[3] and card_ids[1] != card_ids[4]
			and card_ids[2] != card_ids[3] and card_ids[2] != card_ids[4] and card_ids[3] != card_ids[4],
		"all five offered card IDs are distinct")

	var trinket_ids: Array[String] = []
	for offer in trinkets:
		_check(offer is Dictionary and offer.size() == 2, "trinket offer holds only id and price")
		var trinket_id: String = offer.get("id", "")
		trinket_ids.append(trinket_id)
		_check(not owned.has(trinket_id), "an already owned trinket is never offered: " + trinket_id)
		_check(offer.get("price") == _pool_price(trinket_pool, trinket_id),
			"trinket offer keeps the supplied price: " + trinket_id)
	_check(trinket_ids.size() == 2 and trinket_ids[0] != trinket_ids[1],
		"the two offered trinket IDs are distinct")
	_check(not trinket_ids.has("fixture_owned_charm"), "the owned trinket in the pool is excluded")

	# The generated stock has to be a real shop visit, not just data.
	var purchases := RunShopPurchases.new(party, deck, owned, 400, cards, trinkets)
	_check(purchases.is_valid(), "generated stock constructs a valid RunShopPurchases visit")
	var stock: Dictionary = purchases.get_stock()
	_check(stock.get("cards", []).size() == 5 and stock.get("trinkets", []).size() == 2,
		"the shop visit holds the seven generated offers")
	for index in range(cards.size()):
		var listed: Dictionary = stock["cards"][index]
		var offered: Dictionary = cards[index]
		_check(listed["id"] == offered["id"] and listed["owner"] == offered["owner"]
			and listed["price"] == offered["price"] and listed["sold"] == false,
			"the shop visit lists the generated card offer unchanged: " + str(offered.get("id", "")))
	for index in range(trinkets.size()):
		var listed: Dictionary = stock["trinkets"][index]
		var offered: Dictionary = trinkets[index]
		_check(listed["id"] == offered["id"] and listed["price"] == offered["price"]
			and listed["sold"] == false,
			"the shop visit lists the generated trinket offer unchanged: " + str(offered.get("id", "")))
	var state: Dictionary = purchases.get_state()
	_check(state.has("deck") and state["deck"] == deck and state.has("trinkets") and state["trinkets"] == owned
		and state.has("gold") and state["gold"] == 400, "the shop visit starts from the supplied run state")

	_check(catalog_before == _catalog_snapshot(catalog), "the whole authored catalog remains untouched")
	_check(card_pool == card_pool_before, "the supplied card pool is unchanged")
	_check(trinket_pool == trinket_pool_before, "the supplied trinket pool is unchanged")
	_check(owned == owned_before, "the supplied owned trinket list is unchanged")

	# A whole JSON price is accepted and normalised to the integer the shop
	# visit requires; a fractional price is rejected instead of truncated.
	var float_pool := card_pool.duplicate(true)
	for entry in float_pool:
		entry["price"] = float(entry["price"])
	var float_result: Dictionary = RunShopStockOffers.generate(_rng(SEED + 7), party, float_pool,
		trinket_pool, owned)
	_check(float_result.get("ok", false), "whole float prices are accepted")
	for offer in float_result.get("cards", []):
		_check(typeof(offer.get("price")) == TYPE_INT, "an accepted price is a whole integer")
		_check(offer.get("price") == _pool_price(card_pool, offer.get("id", "")),
			"a whole float price keeps its value: " + str(offer.get("id", "")))


func _test_seeded_replay(party: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var card_pool := _starter_only_pool(catalog, party, authored)
	var trinket_pool := _trinket_pool(authored)
	var owned := _owned_trinkets()
	owned.append(trinket_pool[0].id)
	var owned_before := owned.duplicate()
	var reordered_owned := owned.duplicate()
	reordered_owned.reverse()
	var reordered_cards := card_pool.duplicate(true)
	reordered_cards.reverse()
	var reordered_trinkets := trinket_pool.duplicate(true)
	reordered_trinkets.reverse()

	var rng_a := _rng()
	var rng_b := _rng()
	var oracle_rng := _rng()
	var first: Dictionary = RunShopStockOffers.generate(rng_a, party, card_pool, trinket_pool, owned)
	var second: Dictionary = RunShopStockOffers.generate(rng_b, party, reordered_cards, reordered_trinkets, reordered_owned)
	_check(owned == owned_before, "distinct owned IDs preserve caller ordering")
	_check(first.get("ok", false) and second.get("ok", false), "both candidate orders generate")
	_check(first.get("cards", []) == second.get("cards", []),
		"a reordered card pool produces the same card offers")
	_check(first.get("trinkets", []) == second.get("trinkets", []),
		"a reordered trinket pool produces the same trinket offers")
	_check(rng_a.state == rng_b.state, "both runs leave the same run RNG state")

	var oracle := _oracle(catalog, party, card_pool, trinket_pool, owned, oracle_rng)
	_check(first.get("cards", []) == oracle["cards"],
		"the card offers match an independent sorted-pool oracle")
	_check(first.get("trinkets", []) == oracle["trinkets"],
		"the trinket offers match an independent sorted-pool oracle")
	_check(rng_a.state == oracle_rng.state, "five card draws and two trinket draws leave the oracle RNG state")
	_check(rng_a.randi() == oracle_rng.randi(), "the next RNG draw still matches the oracle")

	# The global RNG stream is never a source of shop stock.
	seed(91513)
	var expected_global := randi()
	seed(91513)
	RunShopStockOffers.generate(_rng(), party, card_pool, trinket_pool, owned)
	_check(randi() == expected_global, "generation never touches the global RNG")


func _test_purchases(party: Array[String], deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var card_pool := _starter_only_pool(catalog, party, authored)
	var trinket_pool := _trinket_pool(authored)
	var owned := _owned_trinkets()
	var warden_pool := WardenPoolCards.new()
	var seamstress_pool := SeamstressPoolCards.new()
	var tinker_pool := TinkerPoolCards.new()
	var result: Dictionary = RunShopStockOffers.generate(_rng(SEED + 3), party, card_pool, trinket_pool, owned)
	_check(result.get("ok", false), "stock generated for the purchase test")
	if not result.get("ok", false):
		return
	var cards: Array = result["cards"]
	var trinkets: Array = result["trinkets"]
	var purchases := RunShopPurchases.new(party, deck, owned, 400, cards, trinkets)
	_check(purchases.is_valid(), "the generated stock opens a valid shop visit")

	var card_offer: Dictionary = cards[0]
	var trinket_offer: Dictionary = trinkets[0]
	var card_id: String = card_offer["id"]
	var in_any_catalog := catalog.has_card(card_id) or warden_pool.has_card(card_id) \
		or seamstress_pool.has_card(card_id) or tinker_pool.has_card(card_id)
	_check(in_any_catalog, "the bought card offer is an authored card (starter or pool)")

	# One paid card purchase appends exactly one card and charges its price.
	var before_state := purchases.get_state()
	var before_stock := purchases.get_stock()
	var buy_card := purchases.buy("card", card_offer["id"])
	_check(buy_card.get("ok", false), "the offered card can be bought")
	var after_state := purchases.get_state()
	var after_stock := purchases.get_stock()
	_check(after_state["deck"].size() == before_state["deck"].size() + 1, "one card is appended")
	_check(after_state["deck"].back() == card_offer["id"], "the appended card is the offered card")
	_check(after_state["deck"].slice(0, before_state["deck"].size()) == before_state["deck"],
		"the rest of the deck is unchanged")
	_check(after_state["gold"] == before_state["gold"] - card_offer["price"], "the card price is charged")
	_check(after_state["trinkets"] == before_state["trinkets"], "a card purchase adds no trinket")
	_check(after_state["gold"] >= 0, "gold stays non-negative after a card purchase")
	_check(after_stock["cards"][0]["sold"] == true, "the bought card is marked sold")
	var other_cards_unsold := true
	for index in range(1, after_stock["cards"].size()):
		if after_stock["cards"][index]["sold"]:
			other_cards_unsold = false
	_check(other_cards_unsold, "only the bought card is marked sold")
	_check(not after_stock["trinkets"][0]["sold"] and not after_stock["trinkets"][1]["sold"],
		"no trinket is marked sold by a card purchase")

	# One paid trinket purchase appends exactly one trinket and charges its price.
	var mid_state := purchases.get_state()
	var mid_stock := purchases.get_stock()
	var buy_trinket := purchases.buy("trinket", trinket_offer["id"])
	_check(buy_trinket.get("ok", false), "the offered trinket can be bought")
	var bought_state := purchases.get_state()
	var bought_stock := purchases.get_stock()
	_check(bought_state["trinkets"].size() == mid_state["trinkets"].size() + 1, "one trinket is appended")
	_check(bought_state["trinkets"].back() == trinket_offer["id"], "the appended trinket is the offered trinket")
	_check(bought_state["trinkets"].slice(0, mid_state["trinkets"].size()) == mid_state["trinkets"],
		"the owned trinkets are unchanged")
	_check(bought_state["gold"] == mid_state["gold"] - trinket_offer["price"], "the trinket price is charged")
	_check(bought_state["deck"] == mid_state["deck"], "a trinket purchase adds no card")
	_check(bought_state["gold"] >= 0, "gold stays non-negative after a trinket purchase")
	_check(bought_stock["trinkets"][0]["sold"] == true, "the bought trinket is marked sold")
	_check(not bought_stock["trinkets"][1]["sold"], "only the bought trinket is marked sold")
	_check(bought_stock["cards"][0]["sold"] and not bought_stock["cards"][1]["sold"]
		and not bought_stock["cards"][2]["sold"] and not bought_stock["cards"][3]["sold"]
		and not bought_stock["cards"][4]["sold"], "the earlier card sale is unchanged by a trinket purchase")

	# Repeated, unknown and unaffordable purchases change nothing.
	var repeat_state := purchases.get_state()
	var repeat_stock := purchases.get_stock()
	var repeat_card := purchases.buy("card", card_offer["id"])
	_check(not repeat_card.get("ok", true), "a card cannot be bought twice")
	_check(purchases.get_state() == repeat_state and purchases.get_stock() == repeat_stock,
		"a repeated purchase leaves deck, trinkets, gold and stock unchanged")
	var unknown_card := purchases.buy("card", "__not_in_stock__")
	_check(not unknown_card.get("ok", true), "an unknown card is refused")
	var unknown_trinket := purchases.buy("trinket", "__unknown_trinket__")
	_check(not unknown_trinket.get("ok", true), "an unknown trinket is refused")
	var wrong_kind := purchases.buy("trinket", card_offer["id"])
	_check(not wrong_kind.get("ok", true), "a card ID cannot be bought as a trinket")
	_check(purchases.get_state() == repeat_state and purchases.get_stock() == repeat_stock,
		"refused purchases leave deck, trinkets, gold and stock unchanged")

	# A visit without gold refuses every priced offer and keeps gold at zero.
	var poor := RunShopPurchases.new(party, deck, owned, 0, cards, trinkets)
	_check(poor.is_valid(), "a goldless shop visit is still valid")
	var poor_state := poor.get_state()
	var poor_stock := poor.get_stock()
	var denied := poor.buy("card", card_offer["id"])
	_check(not denied.get("ok", true), "an unaffordable card purchase is refused")
	var denied_trinket := poor.buy("trinket", trinket_offer["id"])
	_check(not denied_trinket.get("ok", true), "an unaffordable trinket purchase is refused")
	_check(poor.get_state() == poor_state and poor.get_stock() == poor_stock,
		"an unaffordable purchase leaves deck, trinkets, gold and stock unchanged")
	_check(poor.get_state()["gold"] == 0, "gold never becomes negative")


func _reject(label: String, rng_input: Variant, party_input: Variant, cards_input: Variant,
		trinkets_input: Variant, owned_input: Variant) -> void:
	var state_before: int = rng_input.state if rng_input is RandomNumberGenerator else -1
	var party_before = party_input.duplicate(true) if party_input is Array else party_input
	var cards_before = cards_input.duplicate(true) if cards_input is Array else cards_input
	var trinkets_before = trinkets_input.duplicate(true) if trinkets_input is Array else trinkets_input
	var owned_before = owned_input.duplicate(true) if owned_input is Array else owned_input
	var global_expected := -1
	if not (rng_input is RandomNumberGenerator):
		seed(48213)
		global_expected = randi()
		seed(48213)
	var result: Dictionary = RunShopStockOffers.generate(rng_input, party_input, cards_input,
		trinkets_input, owned_input)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("cards", ["bad"]).is_empty() and result.get("trinkets", ["bad"]).is_empty(),
		label + ": no offers are published")
	if rng_input is RandomNumberGenerator:
		_check(rng_input.state == state_before, label + ": no RNG is consumed")
	if global_expected >= 0:
		_check(randi() == global_expected, label + ": the global RNG is untouched")
	_check(party_input == party_before, label + ": the party is unchanged")
	_check(cards_input == cards_before, label + ": the card candidates are unchanged")
	_check(trinkets_input == trinkets_before, label + ": the trinket candidates are unchanged")
	_check(owned_input == owned_before, label + ": the owned trinkets are unchanged")


func _test_rejections(party: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var card_pool := _starter_only_pool(catalog, party, authored)
	var trinket_pool := _trinket_pool(authored)
	var owned := _owned_trinkets()
	var catalog_before := _catalog_snapshot(catalog)

	_reject("null RNG", null, party, card_pool, trinket_pool, owned)
	_reject("wrong-type RNG", RefCounted.new(), party, card_pool, trinket_pool, owned)

	_reject("party too small", _rng(), party.slice(0, 2), card_pool, trinket_pool, owned)
	_reject("duplicate party", _rng(), [party[0], party[0], party[2]], card_pool, trinket_pool, owned)
	_reject("empty party id", _rng(), [party[0], "", party[2]], card_pool, trinket_pool, owned)
	_reject("whitespace party id", _rng(), [party[0], "  ", party[2]], card_pool, trinket_pool, owned)
	_reject("numeric party id", _rng(), [party[0], 17, party[2]], card_pool, trinket_pool, owned)
	_reject("unknown party id", _rng(), [party[0], party[1], "__unknown_hero__"], card_pool, trinket_pool, owned)
	_reject("null party", _rng(), null, card_pool, trinket_pool, owned)
	_reject("nonarray party", _rng(), "warden", card_pool, trinket_pool, owned)

	_reject("null card pool", _rng(), party, null, trinket_pool, owned)
	_reject("nonarray card pool", _rng(), party, {}, trinket_pool, owned)
	# Each malformed candidate replaces one entry of a full-size pool, so the
	# rejected rule is the only one that can fail the whole call.
	_reject("non-dictionary card candidate", _rng(), party,
		_with_card(card_pool, 0, "warden_strike"), trinket_pool, owned)
	_reject("card candidate without price", _rng(), party,
		_with_card(card_pool, 0, {"id": card_pool[0]["id"], "owner": card_pool[0]["owner"]}), trinket_pool, owned)
	_reject("card candidate without id", _rng(), party,
		_with_card(card_pool, 0, {"owner": card_pool[0]["owner"], "price": 50}), trinket_pool, owned)
	_reject("empty card candidate id", _rng(), party,
		_with_card(card_pool, 0, {"id": "", "price": 50}), trinket_pool, owned)
	_reject("whitespace card candidate id", _rng(), party,
		_with_card(card_pool, 0, {"id": "  ", "price": 50}), trinket_pool, owned)
	_reject("numeric card candidate id", _rng(), party,
		_with_card(card_pool, 0, {"id": 17, "price": 50}), trinket_pool, owned)
	_reject("unknown card candidate", _rng(), party,
		_with_card(card_pool, 0, {"id": "__unknown_card__", "price": 50}), trinket_pool, owned)
	_reject("duplicate card candidate", _rng(), party,
		_with_card(card_pool, 1, {"id": card_pool[0]["id"], "price": 60}), trinket_pool, owned)
	_reject("wrong-owner card candidate", _rng(), party,
		_with_card(card_pool, 0, {"id": card_pool[0]["id"], "owner": "__other_hero__", "price": 50}),
		trinket_pool, owned)
	for price in [-1, 12.5, "50", true, null]:
		_reject("invalid card price " + str(price), _rng(), party,
			_with_card(card_pool, 0, {"id": card_pool[0]["id"], "owner": card_pool[0]["owner"], "price": price}),
			trinket_pool, owned)
	_reject("too few card candidates", _rng(), party, card_pool.slice(0, 4), trinket_pool, owned)
	_reject("empty card pool", _rng(), party, [], trinket_pool, owned)

	# A correctly authored catalog card owned by a hero outside the party is
	# validated and then ignored for selection, never refused merely for being
	# outside the party. Never invent an unauthored card ID.
	var outside_id := ""
	for candidate_id in V3_PEDDLER_STOCK_SPECS:
		var outside_owner: String = V3_PEDDLER_STOCK_SPECS[candidate_id]["owner"]
		if not party.has(outside_owner):
			outside_id = candidate_id
			break
	_check(not outside_id.is_empty(), "a real authored out-of-party card exists")
	if not outside_id.is_empty():
		var outsider_owner: String = V3_PEDDLER_STOCK_SPECS[outside_id]["owner"]
		var with_outsider := _with_card(card_pool, 0,
			{"id": outside_id, "owner": outsider_owner, "price": 50})
		var outside_result := RunShopStockOffers.generate(_rng(SEED + 400), party,
			with_outsider, trinket_pool, owned)
		_check(outside_result.get("ok", false)
			and not outside_result.get("cards", []).any(
				func(offer): return offer.get("id") == outside_id)
			and outside_result.get("cards", []).size() == 5,
			"authored out-of-party card " + outside_id + " is ignored, not refused")

	_reject("null trinket pool", _rng(), party, card_pool, null, owned)
	_reject("nonarray trinket pool", _rng(), party, card_pool, "trinkets", owned)
	_reject("non-dictionary trinket candidate", _rng(), party, card_pool,
		_with_trinket(trinket_pool, 0, "fixture_pin_badge"), owned)
	_reject("trinket candidate without price", _rng(), party, card_pool,
		_with_trinket(trinket_pool, 0, {"id": "fixture_pin_badge"}), owned)
	_reject("trinket candidate without id", _rng(), party, card_pool,
		_with_trinket(trinket_pool, 0, {"price": 50}), owned)
	_reject("empty trinket candidate id", _rng(), party, card_pool,
		_with_trinket(trinket_pool, 0, {"id": "", "price": 50}), owned)
	_reject("numeric trinket candidate id", _rng(), party, card_pool,
		_with_trinket(trinket_pool, 0, {"id": 17, "price": 50}), owned)
	_reject("duplicate trinket candidate", _rng(), party, card_pool,
		_with_trinket(trinket_pool, 1, {"id": trinket_pool[0]["id"], "price": 60}), owned)
	for price in [-1, 12.5, "50", true, null]:
		_reject("invalid trinket price " + str(price), _rng(), party, card_pool,
			_with_trinket(trinket_pool, 0, {"id": trinket_pool[0]["id"], "price": price}), owned)
	_reject("fewer than two total trinkets", _rng(), party, card_pool,
		[{"id": "fixture_owned_charm", "price": 60}], owned)
	_reject("empty trinket pool", _rng(), party, card_pool, [], owned)

	_reject("null owned trinkets", _rng(), party, card_pool, trinket_pool, null)
	_reject("nonarray owned trinkets", _rng(), party, card_pool, trinket_pool, "owned")
	_reject("numeric owned trinket", _rng(), party, card_pool, trinket_pool, [17])
	_reject("empty owned trinket id", _rng(), party, card_pool, trinket_pool, [""])
	seed(48214)
	var expected_global := randi()
	seed(48214)
	for duplicated in [[owned[0], owned[0]], [trinket_pool[0].id, owned[0], trinket_pool[0].id],
			["outside_pool", owned[0], "outside_pool"]]:
		_reject("duplicate owned trinket", _rng(), party, card_pool, trinket_pool, duplicated)
	_check(randi() == expected_global, "duplicate ownership rejection leaves global RNG untouched")

	_check(catalog_before == _catalog_snapshot(catalog), "the whole authored catalog survives every rejection")


## AC1: Mixed pool/starter candidate generation with real pool cards.
func _test_mixed_pool_generation(party: Array[String], deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var card_pool := _card_pool(catalog, party, authored)
	var trinket_pool := _trinket_pool(authored)
	var owned := _owned_trinkets()
	var warden_pool := WardenPoolCards.new()
	var seamstress_pool := SeamstressPoolCards.new()
	var tinker_pool := TinkerPoolCards.new()

	# Verify the three example pool cards are present in the candidate pool.
	_check(_pool_has_id(card_pool, "warden_hold_the_line"), "warden_hold_the_line present in candidate pool")
	_check(_pool_has_id(card_pool, "seamstress_darning"), "seamstress_darning present in candidate pool")
	_check(_pool_has_id(card_pool, "tinker_rivet_shot"), "tinker_rivet_shot present in candidate pool")

	# Generate stock with a seeded RNG.
	var rng := _rng(SEED + 100)
	var result: Dictionary = RunShopStockOffers.generate(rng, party, card_pool, trinket_pool, owned)
	_check(result.get("ok", false), "mixed pool/starter pools generate a stock")
	var cards: Array = result.get("cards", [])
	var trinkets: Array = result.get("trinkets", [])
	_check(cards.size() == 5, "exactly five card offers from mixed pool")
	_check(trinkets.size() == 2, "exactly two trinket offers")

	# Every offered card must be from the candidate pool, have correct owner and price.
	for offer in cards:
		var card_id: String = offer.get("id", "")
		_check(_pool_has_id(card_pool, card_id), "offered card is from candidate pool: " + card_id)
		# Verify owner matches the correct catalog
		var expected_owner: String = ""
		if catalog.has_card(card_id):
			expected_owner = catalog.get_definition(card_id).get("owner", "")
		elif warden_pool.has_card(card_id):
			expected_owner = warden_pool.get_definition(card_id).get("owner", "")
		elif seamstress_pool.has_card(card_id):
			expected_owner = seamstress_pool.get_definition(card_id).get("owner", "")
		elif tinker_pool.has_card(card_id):
			expected_owner = tinker_pool.get_definition(card_id).get("owner", "")
		_check(offer.get("owner") == expected_owner, "offer uses correct catalog owner for " + card_id + ": " + offer.get("owner") + " == " + expected_owner)
		_check(party.has(offer.get("owner")), "offered card belongs to the party: " + card_id)
		_check(offer.get("price") == _pool_price(card_pool, card_id), "offer keeps the supplied price: " + card_id)

	# All five offered card IDs are distinct.
	var card_ids: Array[String] = []
	for offer in cards:
		card_ids.append(offer.get("id", ""))
	_check(card_ids.size() == 5 and card_ids[0] != card_ids[1] and card_ids[0] != card_ids[2]
			and card_ids[0] != card_ids[3] and card_ids[0] != card_ids[4]
			and card_ids[1] != card_ids[2] and card_ids[1] != card_ids[3] and card_ids[1] != card_ids[4]
			and card_ids[2] != card_ids[3] and card_ids[2] != card_ids[4] and card_ids[3] != card_ids[4],
		"all five offered card IDs are distinct")

	# Verify each hero's pool has genuine selectable representation by checking
	# that the pool contains cards from all three heroes.
	var warden_offered := false
	var seamstress_offered := false
	var tinker_offered := false
	for offer in cards:
		if offer.get("owner") == "warden":
			warden_offered = true
		elif offer.get("owner") == "seamstress":
			seamstress_offered = true
		elif offer.get("owner") == "tinker":
			tinker_offered = true
	# At least one card from each hero should be selectable (not guaranteed to appear in 5 draws,
	# but the candidate pool has them all). We verify the candidate pool has representation.
	var warden_in_pool := false
	var seamstress_in_pool := false
	var tinker_in_pool := false
	for entry in card_pool:
		if entry.get("owner") == "warden":
			warden_in_pool = true
		elif entry.get("owner") == "seamstress":
			seamstress_in_pool = true
		elif entry.get("owner") == "tinker":
			tinker_in_pool = true
	_check(warden_in_pool and seamstress_in_pool and tinker_in_pool, "candidate pool has all three hero pool cards")

	# The generated stock has to be a real shop visit, not just data.
	var purchases := RunShopPurchases.new(party, deck, owned, 400, cards, trinkets)
	_check(purchases.is_valid(), "generated mixed stock constructs a valid RunShopPurchases visit")


## AC2: Oracle match, replay, and real purchase of a pool card.
func _test_pool_purchase(party: Array[String], deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var card_pool := _card_pool(catalog, party, authored)
	var trinket_pool := _trinket_pool(authored)
	var owned := _owned_trinkets()
	var warden_pool := WardenPoolCards.new()
	var seamstress_pool := SeamstressPoolCards.new()
	var tinker_pool := TinkerPoolCards.new()

	# Use a fixture with exactly five valid candidate card IDs, at least one from each pool,
	# to guarantee a specific offered base card for RunShopPurchases.buy.
	# We'll construct a minimal candidate pool.
	var minimal_cards: Array = [
		{"id": "warden_hold_the_line", "owner": "warden", "price": 55},
		{"id": "seamstress_darning", "owner": "seamstress", "price": 55},
		{"id": "tinker_rivet_shot", "owner": "tinker", "price": 50},
		{"id": "warden_strike", "owner": "warden", "price": 50},
		{"id": "seamstress_prick", "owner": "seamstress", "price": 50},
	]
	var minimal_trinkets: Array = [
		{"id": "fixture_pin_badge", "price": 90},
		{"id": "fixture_spare_spool", "price": 110},
	]

	# Independent sorted mutable pools and independently seeded RNG.
	var oracle_rng := _rng(SEED + 200)
	var rng_a := _rng(SEED + 200)
	var rng_b := _rng(SEED + 200)

	var card_ids_a: Array[String] = []
	for entry in minimal_cards:
		card_ids_a.append(entry["id"])
	card_ids_a.sort()
	var cards_a: Array = []
	for _pick in range(5):
		var index: int = oracle_rng.randi_range(0, card_ids_a.size() - 1)
		var card_id: String = card_ids_a[index]
		card_ids_a.remove_at(index)
		var owner: String = ""
		if catalog.has_card(card_id):
			owner = catalog.get_definition(card_id).get("owner", "")
		elif warden_pool.has_card(card_id):
			owner = warden_pool.get_definition(card_id).get("owner", "")
		elif seamstress_pool.has_card(card_id):
			owner = seamstress_pool.get_definition(card_id).get("owner", "")
		elif tinker_pool.has_card(card_id):
			owner = tinker_pool.get_definition(card_id).get("owner", "")
		cards_a.append({"id": card_id, "owner": owner, "price": _pool_price(minimal_cards, card_id)})

	var trinket_ids_a: Array[String] = []
	for entry in minimal_trinkets:
		if not owned.has(entry["id"]):
			trinket_ids_a.append(entry["id"])
	trinket_ids_a.sort()
	var trinkets_a: Array = []
	for _pick in range(2):
		var index: int = oracle_rng.randi_range(0, trinket_ids_a.size() - 1)
		var trinket_id: String = trinket_ids_a[index]
		trinket_ids_a.remove_at(index)
		trinkets_a.append({"id": trinket_id, "price": _pool_price(minimal_trinkets, trinket_id)})

	var oracle := {"cards": cards_a, "trinkets": trinkets_a}

	# Run generation with original order.
	var result_a: Dictionary = RunShopStockOffers.generate(rng_a, party, minimal_cards, minimal_trinkets, owned)
	_check(result_a.get("ok", false), "minimal pool generates stock")
	_check(result_a.get("cards") == oracle["cards"], "card offers match independent oracle")
	_check(result_a.get("trinkets") == oracle["trinkets"], "trinket offers match independent oracle")
	_check(rng_a.state == oracle_rng.state, "RNG state matches oracle after five card and two trinket draws")

	# Reverse/reorder inputs and prove the same output.
	var reversed_cards := minimal_cards.duplicate(true)
	reversed_cards.reverse()
	var reversed_trinkets := minimal_trinkets.duplicate(true)
	reversed_trinkets.reverse()
	var result_b: Dictionary = RunShopStockOffers.generate(rng_b, party, reversed_cards, reversed_trinkets, owned)
	_check(result_b.get("ok", false), "reordered minimal pool generates stock")
	_check(result_a == result_b, "reordered inputs produce identical stock")
	_check(rng_a.state == rng_b.state, "reordered inputs leave identical RNG state")

	# Now test a real purchase of an actually offered base pool card.
	# Select a offered card that is from a pool (Warden/Seamstress/Tinker) and NOT a StarterCard.
	var pool_card_offer: Dictionary = {}
	for offer in result_a["cards"]:
		var card_id: String = offer["id"]
		var is_pool_card := warden_pool.has_card(card_id) or seamstress_pool.has_card(card_id) or tinker_pool.has_card(card_id)
		var is_starter_card := catalog.has_card(card_id)
		if is_pool_card and not is_starter_card:
			pool_card_offer = offer
			break
	_check(pool_card_offer != null, "at least one offered card is from a hero pool (not starter)")

	var offered_card_id: String = pool_card_offer["id"]
	var offered_price: int = pool_card_offer["price"]
	# Explicitly assert the purchased card belongs to a hero pool catalog and not StarterCards.
	_check(warden_pool.has_card(offered_card_id) or seamstress_pool.has_card(offered_card_id) or tinker_pool.has_card(offered_card_id),
		"purchased card is from WardenPoolCards, SeamstressPoolCards, or TinkerPoolCards: " + offered_card_id)
	_check(not catalog.has_card(offered_card_id), "purchased card is NOT a StarterCard: " + offered_card_id)

	var purchases := RunShopPurchases.new(party, deck, owned, 400, result_a["cards"], result_a["trinkets"])
	_check(purchases.is_valid(), "minimal stock admits real purchase service")

	var buy_result := purchases.buy("card", offered_card_id)
	_check(buy_result.get("ok", false), "offered pool card can be bought: " + offered_card_id)
	var after_state := purchases.get_state()
	var after_stock := purchases.get_stock()
	_check(after_state["deck"].size() == deck.size() + 1, "one card appended to deck")
	_check(after_state["deck"].back() == offered_card_id, "appended card is the offered pool card: " + offered_card_id)
	_check(after_state["gold"] == 400 - offered_price, "exact supplied price charged: " + str(offered_price))
	_check(after_stock["cards"][0]["sold"] == true, "bought card marked sold")

	# Buying again fails.
	var repeat_buy := purchases.buy("card", offered_card_id)
	_check(not repeat_buy.get("ok", true), "pool card cannot be bought twice")
	_check(purchases.get_state() == after_state and purchases.get_stock() == after_stock, "repeated purchase leaves state unchanged")


## AC3: Additional rejection cases for pool cards.
func _test_pool_rejections(party: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var card_pool := _card_pool(catalog, party, authored)
	var trinket_pool := _trinket_pool(authored)
	var owned := _owned_trinkets()
	var warden_pool := WardenPoolCards.new()
	var seamstress_pool := SeamstressPoolCards.new()
	var tinker_pool := TinkerPoolCards.new()
	var catalog_before := _catalog_snapshot(catalog)

	# Forged owner for a valid pool ID.
	_reject("forged owner on pool card", _rng(), party,
		_with_card(card_pool, 0, {"id": "warden_hold_the_line", "owner": "seamstress", "price": 55}),
		trinket_pool, owned)

	# Unknown ID (truly unknown, not a newly legitimate base pool ID).
	_reject("truly unknown card candidate", _rng(), party,
		_with_card(card_pool, 0, {"id": "__truly_unknown_card__", "price": 50}),
		trinket_pool, owned)

	# Extra duplicate in candidate pool.
	_reject("duplicate pool card candidate", _rng(), party,
		_with_card(card_pool, 1, {"id": "warden_hold_the_line", "price": 60}),
		trinket_pool, owned)

	# Pool upgrade used as a new Shop candidate (should be rejected).
	_reject("pool upgrade card as candidate (warden)", _rng(), party,
		_with_card(card_pool, 0, {"id": "warden_hold_the_line_plus", "price": 55}),
		trinket_pool, owned)
	_reject("pool upgrade card as candidate (seamstress)", _rng(), party,
		_with_card(card_pool, 0, {"id": "seamstress_darning_plus", "price": 55}),
		trinket_pool, owned)
	_reject("pool upgrade card as candidate (tinker)", _rng(), party,
		_with_card(card_pool, 0, {"id": "tinker_rivet_shot_plus", "price": 50}),
		trinket_pool, owned)

	# Foreign party (only 2 heroes).
	_reject("foreign party (two heroes)", _rng(), party.slice(0, 2), card_pool, trinket_pool, owned)

	# Invalid price (negative, fractional, non-numeric).
	for price in [-1, 12.5, "50", true, null]:
		_reject("invalid pool card price " + str(price), _rng(), party,
			_with_card(card_pool, 0, {"id": "warden_hold_the_line", "owner": "warden", "price": price}),
			trinket_pool, owned)

	# Too few valid candidates (only 4).
	_reject("too few card candidates with pool cards", _rng(), party,
		[
			{"id": "warden_hold_the_line", "owner": "warden", "price": 55},
			{"id": "seamstress_darning", "owner": "seamstress", "price": 55},
			{"id": "tinker_rivet_shot", "owner": "tinker", "price": 50},
			{"id": "warden_strike", "owner": "warden", "price": 50},
		], trinket_pool, owned)

	# Ensure existing StarterCards entries (including previously permitted versions) still work.
	var starter_only_cards: Array = []
	for entry in card_pool:
		if catalog.has_card(entry["id"]):
			starter_only_cards.append(entry)
	_check(starter_only_cards.size() >= 5, "starter-only pool still has enough candidates")
	var starter_result := RunShopStockOffers.generate(_rng(SEED + 300), party, starter_only_cards, trinket_pool, owned)
	_check(starter_result.get("ok", false), "starter-only candidate pool still generates")

	_check(catalog_before == _catalog_snapshot(catalog), "catalog survives pool rejection tests")

## The actual shipped JSON, rather than a synthetic wide pool, is the Shop's
## complete priced candidate source. Check IDs independently of list ordering.
func _test_authored_shop_pool(party: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var candidates: Array = authored.get("cards", [])
	var trinkets: Array = authored.get("trinkets", [])
	var specs: Dictionary = {
		"warden_hold_the_line": {"owner": "warden", "price": 55, "cost": 1, "from": [1, 2], "target": "self", "to": [], "effects": {"block": 5, "other_ally_block": 2}, "rarity": "common"},
		"warden_patch_guard": {"owner": "warden", "price": 45, "cost": 1, "from": [1, 2, 3], "target": "ally_single", "to": [], "effects": {"block": 8}, "rarity": "common"},
		"warden_quick_darn": {"owner": "warden", "price": 40, "cost": 0, "from": [1, 2], "target": "self", "to": [], "effects": {"block": 4}, "rarity": "common"},
		"warden_brass_buckle": {"owner": "warden", "price": 55, "cost": 1, "from": [1, 2], "target": "enemy_single", "to": [1, 2], "effects": {"damage": 5, "block": 4}, "rarity": "common"},
		"warden_iron_hem": {"owner": "warden", "price": 70, "cost": 2, "from": [1, 2, 3], "target": "self", "to": [], "effects": {"block": 14}, "rarity": "uncommon"},
		"warden_bastion_quilt": {"owner": "warden", "price": 90, "cost": 3, "from": [1, 2, 3], "target": "party_all", "to": [], "effects": {"block_all": 10}, "rarity": "rare"},
		"seamstress_thread_whip": {"owner": "seamstress", "price": 55, "cost": 1, "from": [1, 2, 3], "target": "enemy_single", "to": [1, 2], "effects": {"damage": 6}, "rarity": "common"}
	}
	var old_prices := {
		"warden_strike": 50, "warden_shield_bash": 65, "seamstress_prick": 50,
		"tinker_pop_shot": 50, "tinker_scrap_bomb": 65
	}
	## Four starter support/draw cards newly authored into the Shop (M04 D2-1).
	## These are base starter IDs, not _plus upgrades; prices are the regression fixture values.
	var new_starter_prices := {
		"warden_brace": {"owner": "warden", "price": 40, "cost": 1, "from": [1, 2, 3], "target": "self", "to": [], "effects": {"block": 7}},
		"seamstress_mend": {"owner": "seamstress", "price": 45, "cost": 1, "from": [2, 3], "target": "ally_single", "to": [], "effects": {"heal": 5}},
		"seamstress_stitch_up": {"owner": "seamstress", "price": 45, "cost": 1, "from": [1, 2, 3], "target": "ally_single", "to": [], "effects": {"block": 5}},
		"tinker_tune_up": {"owner": "tinker", "price": 35, "cost": 0, "from": [1, 2, 3], "target": "none", "to": [], "effects": {"draw": 1}}
	}
	var old_trinkets := {"stitched_badge": 100, "spare_spool": 100, "quilted_coat": 100}
	var count_by_id := {}
	for entry in candidates:
		_check(entry is Dictionary and entry.get("id") is String and entry.get("owner") is String,
			"every authored card candidate has ID and owner")
		if not entry is Dictionary or not entry.get("id") is String:
			continue
		var id: String = entry.id
		count_by_id[id] = int(count_by_id.get(id, 0)) + 1
		_check(not id.ends_with("_plus"), "real Shop candidates exclude upgrades: " + id)
	for id in specs:
		var expected: Dictionary = specs[id]
		_check(count_by_id.get(id, 0) == 1, "required base card occurs once: " + id)
		var found: Dictionary = {}
		for entry in candidates:
			if entry is Dictionary and entry.get("id") == id:
				found = entry
		_check(found.get("owner") == expected.owner and _whole_price(found.get("price")) == expected.price,
			"authored Shop owner and exact fixed gold price: " + id)
		var warden := WardenPoolCards.new()
		var seamstress := SeamstressPoolCards.new()
		var pool: RefCounted = warden if expected.owner == "warden" else seamstress
		var base_ids: Array[String] = warden.get_base_ids() if expected.owner == "warden" else seamstress.get_base_ids()
		var def: Dictionary = pool.get_definition(id)
		_check(base_ids.has(id) and def.get("id") == id and def.get("owner") == expected.owner
			and def.get("reward_eligible") == true and not def.has("upgrade_of")
			and def.get("upgrade_id") == id + "_plus" and def.get("starting_copies") == 0,
			"catalog resolves eligible base ID with no upgrade substitution: " + id)
		_check(def.get("cost") == expected.cost and def.get("from_positions") == expected["from"]
			and def.get("to_positions") == expected["to"] and def.get("target_kind") == expected.target
			and def.get("effects") == expected.effects and def.get("rarity") == expected.rarity,
			"authored combat legality, values and rarity remain playable: " + id)
	for id in old_prices:
		_check(count_by_id.get(id, 0) == 1, "original starter still listed once: " + id)
		for entry in candidates:
			if entry is Dictionary and entry.get("id") == id:
				_check(entry.get("owner") == catalog.get_definition(id).get("owner")
					and _whole_price(entry.get("price")) == old_prices[id],
					"original starter candidate unchanged: " + id)
	for id in new_starter_prices:
		var expected: Dictionary = new_starter_prices[id]
		_check(count_by_id.get(id, 0) == 1, "new starter support listed once: " + id)
		var found: Dictionary = {}
		for entry in candidates:
			if entry is Dictionary and entry.get("id") == id:
				found = entry
		_check(found.get("owner") == expected.owner and _whole_price(found.get("price")) == expected.price,
			"new starter support owner and exact fixed gold price: " + id)
		var def: Dictionary = catalog.get_definition(id)
		_check(def.get("id") == id and def.get("owner") == expected.owner
			and def.get("cost") == expected.cost and def.get("from_positions") == expected["from"]
			and def.get("to_positions") == expected["to"] and def.get("target_kind") == expected.target
			and def.get("effects") == expected.effects and def.get("starting_copies") == 1,
			"new starter support catalog definition matches: " + id)
	for id in count_by_id:
		_check(count_by_id[id] == 1, "no duplicate Shop candidate ID: " + id)
	var trinket_counts := {}
	for entry in trinkets:
		if entry is Dictionary and entry.get("id") is String:
			trinket_counts[entry.id] = int(trinket_counts.get(entry.id, 0)) + 1
	for id in old_trinkets:
		_check(trinket_counts.get(id, 0) == 1, "original trinket survives exactly once: " + id)
		for entry in trinkets:
			if entry is Dictionary and entry.get("id") == id:
				_check(_whole_price(entry.get("price")) == old_trinkets[id],
					"original trinket price unchanged: " + id)
	for id in trinket_counts:
		_check(trinket_counts[id] == 1, "no duplicate Shop trinket: " + id)
	# Replay the actual, unchanged Shop draw algorithm against an independent
	# sorted candidate oracle, not the synthetic starter/mixed fixtures.
	var first_rng := _rng(SEED + 310)
	var oracle_rng := _rng(SEED + 310)
	var replay_rng := _rng(SEED + 310)
	var result: Dictionary = RunShopStockOffers.generate(first_rng, party, candidates, trinkets, [])
	var oracle: Dictionary = _oracle(catalog, party, candidates, trinkets, [], oracle_rng)
	var reversed_cards := candidates.duplicate(true)
	var reversed_trinkets := trinkets.duplicate(true)
	reversed_cards.reverse()
	reversed_trinkets.reverse()
	var replay: Dictionary = RunShopStockOffers.generate(replay_rng, party, reversed_cards, reversed_trinkets, [])
	_check(result.get("ok", false) and result.get("cards", []).size() == 5
		and result.get("trinkets", []).size() == 2, "actual Shop generates five cards and two trinkets")
	_check(result.get("cards", []) == oracle.cards and result.get("trinkets", []) == oracle.trinkets,
		"actual JSON offers match independent sorted seven-draw oracle")
	_check(result == replay and first_rng.state == oracle_rng.state
		and first_rng.state == replay_rng.state and first_rng.randi() == oracle_rng.randi(),
		"actual JSON stock, reorder and next RNG draw replay exactly")
	var seen := {}
	for offer in result.get("cards", []):
		_check(not seen.has(offer.id) and party.has(offer.owner) and not String(offer.id).ends_with("_plus"),
			"five distinct party-owned base offers without upgrades")
		seen[offer.id] = true
		_check(_pool_price(candidates, offer.id) == offer.price, "selected quote is actual authored price")


## AC2: For each of the four new starter support/draw cards, exhibit a seeded
## Shop offer containing that card and then purchase it via RunShopPurchases at
## its exact authored price. The search is a short bounded deterministic scan.
func _test_new_starter_shop_offers_and_purchases(party: Array[String], deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var candidates: Array = authored.get("cards", [])
	var trinkets: Array = authored.get("trinkets", [])
	# The four new starter support cards with their expected owners and prices.
	var new_starter_specs := {
		"warden_brace": {"owner": "warden", "price": 40},
		"seamstress_mend": {"owner": "seamstress", "price": 45},
		"seamstress_stitch_up": {"owner": "seamstress", "price": 45},
		"tinker_tune_up": {"owner": "tinker", "price": 35}
	}
	# Bounded seed range for deterministic search. Each seed yields a 7-draw stock.
	var MAX_SEED_OFFSET := 1000
	for card_id in new_starter_specs:
		var expected_owner: String = new_starter_specs[card_id].owner
		var expected_price: int = new_starter_specs[card_id].price
		var found_seed: int = -1
		var found_result: Dictionary = {}
		# Search a short bounded range of seeds for an offer containing this card.
		for offset in range(MAX_SEED_OFFSET):
			var test_rng := _rng(SEED + 400 + offset)
			var test_result: Dictionary = RunShopStockOffers.generate(test_rng, party, candidates, trinkets, [])
			if not test_result.get("ok", false):
				continue
			var offered_cards: Array = test_result.get("cards", [])
			for offer in offered_cards:
				if offer.get("id") == card_id:
					found_seed = SEED + 400 + offset
					found_result = test_result
					break
			if found_seed >= 0:
				break
		_check(found_seed >= 0, "seeded Shop offer found for " + card_id + " within bounded search")
		if found_seed < 0:
			continue
		# Verify the offered owner and exact price match the authored JSON.
		var matched_offer: Dictionary = {}
		for offer in found_result.get("cards", []):
			if offer.get("id") == card_id:
				matched_offer = offer
				break
		_check(matched_offer.get("owner") == expected_owner,
			card_id + ": offered owner matches authored owner")
		_check(matched_offer.get("price") == expected_price,
			card_id + ": offered price matches authored price " + str(expected_price))
		# Construct a valid affordable RunShopPurchases visit.
		var purchases := RunShopPurchases.new(party, deck, [], 500, found_result["cards"], found_result["trinkets"])
		_check(purchases.is_valid(), card_id + ": generated stock admits real purchase service")
		var before_state: Dictionary = purchases.get_state()
		var before_stock: Dictionary = purchases.get_stock()
		var before_deck: Array = before_state["deck"].duplicate()
		var before_gold: int = before_state["gold"]
		var before_trinkets: Array = before_state["trinkets"].duplicate()
		# Buy the card.
		var buy_result := purchases.buy("card", card_id)
		_check(buy_result.get("ok", false), card_id + ": card purchase succeeds")
		var after_state := purchases.get_state()
		var after_stock := purchases.get_stock()
		# Assert exact gold deduction.
		_check(after_state["gold"] == before_gold - expected_price,
			card_id + ": exact authored price charged (" + str(expected_price) + " gold)")
		# Assert exactly one card appended with the original deck unchanged.
		_check(after_state["deck"].size() == before_deck.size() + 1,
			card_id + ": one card appended to deck")
		_check(after_state["deck"].back() == card_id,
			card_id + ": appended card is the purchased card")
		_check(after_state["deck"].slice(0, before_deck.size()) == before_deck,
			card_id + ": original deck unchanged")
		# Assert no trinket changes.
		_check(after_state["trinkets"] == before_trinkets,
			card_id + ": trinkets unchanged by card purchase")
		# Assert the bought card is marked sold.
		var bought_listing_sold := false
		for listing in after_stock.get("cards", []):
			if listing.get("id") == card_id:
				_check(listing.get("sold") == true, card_id + ": bought card marked sold")
				bought_listing_sold = true
				break
		_check(bought_listing_sold, card_id + ": purchased card listing exists and is sold")
		# Assert all other card listings are unaffected (unsold, same price/owner).
		for listing in after_stock.get("cards", []):
			if listing.get("id") != card_id:
				_check(listing.get("sold") == false, card_id + ": other card listings remain unsold")
				# Find the corresponding before listing.
				var before_listing: Dictionary = {}
				for bl in before_stock.get("cards", []):
					if bl.get("id") == listing.get("id"):
						before_listing = bl
						break
				_check(listing.get("owner") == before_listing.get("owner"),
					card_id + ": other listing owner unchanged")
				_check(listing.get("price") == before_listing.get("price"),
					card_id + ": other listing price unchanged")
		# Assert trinket listings are unaffected.
		for index in range(after_stock.get("trinkets", []).size()):
			var after_trinket: Dictionary = after_stock["trinkets"][index]
			var before_trinket: Dictionary = before_stock["trinkets"][index]
			_check(after_trinket.get("id") == before_trinket.get("id"),
				card_id + ": trinket listing ID unchanged")
			_check(after_trinket.get("price") == before_trinket.get("price"),
				card_id + ": trinket listing price unchanged")
			_check(after_trinket.get("sold") == before_trinket.get("sold"),
				card_id + ": trinket listing sold status unchanged")
		# Verify the receipt matches.
		var receipt: Dictionary = buy_result.get("receipt", {})
		_check(receipt.get("kind") == "card" and receipt.get("id") == card_id and receipt.get("price") == expected_price,
			card_id + ": receipt matches kind, ID and exact price")


## AC1/AC2/AC3: Catalog, bounded seed scan and funded purchase for each
## of the eight new M04 D2-1 pool cards (seamstress and tinker base IDs).
func _test_new_pool_shop_offers_and_purchases(party: Array[String], deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var candidates: Array = authored.get("cards", [])
	var trinkets: Array = authored.get("trinkets", [])
	var seamstress_pool := SeamstressPoolCards.new()
	var tinker_pool := TinkerPoolCards.new()

	# AC1: Catalog checks for the eight new IDs, older cards unchanged, no duplicates.
	var count_by_id := {}
	for entry in candidates:
		if entry is Dictionary and entry.get("id") is String:
			count_by_id[entry.id] = int(count_by_id.get(entry.id, 0)) + 1
	for card_id in NEW_POOL_SPECS:
		var spec: Dictionary = NEW_POOL_SPECS[card_id]
		# Must exist in JSON with exact owner/price.
		var found_json := false
		for entry in candidates:
			if entry is Dictionary and entry.get("id") == card_id:
				found_json = true
				_check(entry.get("owner") == spec["owner"],
					"new pool " + card_id + " authored owner")
				_check(_whole_price(entry.get("price")) == spec["price"],
					"new pool " + card_id + " authored price")
		_check(found_json, "new pool card present in authored JSON: " + card_id)
		# Must be a base ID (not _plus) and a genuine catalog base card.
		_check(not String(card_id).ends_with("_plus"),
			"new pool base ID excludes upgrade: " + card_id)
		var def: Dictionary = {}
		var is_pool_base := false
		if spec["owner"] == "seamstress":
			is_pool_base = seamstress_pool.get_base_ids().has(card_id)
			def = seamstress_pool.get_definition(card_id)
		elif spec["owner"] == "tinker":
			is_pool_base = tinker_pool.get_pool_card_ids().has(card_id)
			def = tinker_pool.get_definition(card_id)
		_check(is_pool_base, "new pool " + card_id + " is authored base pool card")
		_check(def.get("id") == card_id and def.get("owner") == spec["owner"]
			and def.get("rarity") == spec["rarity"] and def.get("cost") == spec["cost"]
			and def.get("from_positions") == spec["from"]
			and def.get("to_positions") == spec["to"]
			and def.get("target_kind") == spec["target"]
			and def.get("effects") == spec["effects"],
			"new pool " + card_id + " catalog behavior matches authored spec")
	# All eight must appear exactly once in the authored JSON.
	for card_id in NEW_POOL_SPECS:
		_check(count_by_id.get(card_id, 0) == 1,
			"new pool base ID occurs exactly once in authored pool: " + card_id)
	# Older named candidates must survive with their previous owner and price.
	for card_id in EXISTING_SHOP_CARDS:
		var previous: Dictionary = EXISTING_SHOP_CARDS[card_id]
		_check(count_by_id.get(card_id, 0) == 1,
			"older named candidate still present exactly once: " + card_id)
		var found_older: Dictionary = {}
		for entry in candidates:
			if entry is Dictionary and entry.get("id") == card_id:
				found_older = entry
		_check(found_older.get("owner") == previous["owner"]
			and _whole_price(found_older.get("price")) == previous["price"],
			"older named candidate keeps previous owner and price: " + card_id)
		var authored_def: Dictionary = catalog.get_definition(card_id)
		if authored_def.is_empty():
			authored_def = seamstress_pool.get_definition(card_id)
		if authored_def.is_empty():
			authored_def = tinker_pool.get_definition(card_id)
		if authored_def.is_empty():
			authored_def = WardenPoolCards.new().get_definition(card_id)
		_check(authored_def.get("owner") == previous["owner"],
			"older named candidate owner still matches its catalog: " + card_id)
	# The authored trinket listings are untouched by the card expansion.
	var trinket_counts := {}
	for entry in trinkets:
		if entry is Dictionary and entry.get("id") is String:
			trinket_counts[entry.id] = int(trinket_counts.get(entry.id, 0)) + 1
	for trinket_id in EXISTING_SHOP_TRINKETS:
		_check(trinket_counts.get(trinket_id, 0) == 1,
			"authored trinket still listed exactly once: " + trinket_id)
		var found_trinket: Dictionary = {}
		for entry in trinkets:
			if entry is Dictionary and entry.get("id") == trinket_id:
				found_trinket = entry
		_check(_whole_price(found_trinket.get("price")) == EXISTING_SHOP_TRINKETS[trinket_id],
			"authored trinket price unchanged: " + trinket_id)
	# No duplicate candidate IDs across the expanded pool.
	for id in count_by_id:
		_check(count_by_id[id] == 1, "no duplicate Shop candidate ID: " + id)

	# AC2: Bounded seed scan until each new card appears in a genuine
	# five-card / two-trinket stock; verify order-independent replay and RNG state.
	var MAX_SEED_OFFSET := 1000
	for card_id in NEW_POOL_SPECS:
		var expected_owner: String = NEW_POOL_SPECS[card_id]["owner"]
		var expected_price: int = NEW_POOL_SPECS[card_id]["price"]
		var found_seed := -1
		var found_result: Dictionary = {}
		for offset in range(MAX_SEED_OFFSET):
			var test_rng := _rng(SEED + 500 + offset)
			var test_result := RunShopStockOffers.generate(test_rng, party, candidates, trinkets, [])
			if not test_result.get("ok", false):
				continue
			for offer in test_result.get("cards", []):
				if offer.get("id") == card_id:
					found_seed = SEED + 500 + offset
					found_result = test_result
					break
			if found_seed >= 0:
				break
		_check(found_seed >= 0, "seeded Shop offer found for new pool " + card_id + " within bounded search")
		if found_seed < 0:
			continue

		# Verify the matched offer uses the authored owner and price.
		var matched_offer := {}
		for offer in found_result.get("cards", []):
			if offer.get("id") == card_id:
				matched_offer = offer
				break
		_check(matched_offer.get("owner") == expected_owner,
			"new pool " + card_id + ": offered owner matches authored owner")
		_check(matched_offer.get("price") == expected_price,
			"new pool " + card_id + ": offered price matches authored price")
		_check(found_result.get("cards", []).size() == 5
			and found_result.get("trinkets", []).size() == 2,
			"new pool " + card_id + ": found stock is a genuine five-card/two-patch visit")

		# The genuine stock must match the existing independent sorted-pool
		# oracle for the same seed, including the next RNG state and draw.
		var oracle_rng := _rng(found_seed)
		var oracle := _oracle(catalog, party, candidates, trinkets, [], oracle_rng)
		var probe_rng := _rng(found_seed)
		var probe_result := RunShopStockOffers.generate(probe_rng, party, candidates, trinkets, [])
		_check(probe_result == found_result and found_result.get("cards", []) == oracle.cards
			and found_result.get("trinkets", []) == oracle.trinkets,
			"new pool " + card_id + ": found stock matches the independent oracle")
		_check(probe_rng.state == oracle_rng.state and probe_rng.randi() == oracle_rng.randi(),
			"new pool " + card_id + ": found stock preserves the next RNG state and draw")

		# Order-independent replay: reverse inputs, same output and same next RNG state.
		var reversed_cards := candidates.duplicate(true)
		reversed_cards.reverse()
		var reversed_trinkets := trinkets.duplicate(true)
		reversed_trinkets.reverse()
		var replay_rng := _rng(found_seed)
		var original_rng := _rng(found_seed)
		var replay_result := RunShopStockOffers.generate(replay_rng, party, reversed_cards, reversed_trinkets, [])
		var original_result := RunShopStockOffers.generate(original_rng, party, candidates, trinkets, [])
		_check(replay_result == original_result and replay_rng.state == original_rng.state,
			"new pool " + card_id + ": reversed input produces identical stock and same RNG state")
		_check(original_result == found_result,
			"new pool " + card_id + ": replayed seed reproduces the found stock")

		# AC3: Real funded purchase with exact gold debit, one appended card,
		# sold flag set, unchanged other listings/trinkets, valid receipt.
		var purchases := RunShopPurchases.new(party, deck, [], 500, found_result["cards"], found_result["trinkets"])
		_check(purchases.is_valid(), "new pool " + card_id + ": generated stock admits real purchase service")
		var before_state := purchases.get_state()
		var before_stock := purchases.get_stock()
		var before_deck: Array = before_state["deck"].duplicate()
		var before_gold: int = before_state["gold"]
		var before_trinkets: Array = before_state["trinkets"].duplicate()

		var buy_result := purchases.buy("card", card_id)
		_check(buy_result.get("ok", false), "new pool " + card_id + ": card purchase succeeds")
		var after_state := purchases.get_state()
		var after_stock := purchases.get_stock()

		_check(after_state["deck"].size() == before_deck.size() + 1,
			"new pool " + card_id + ": exactly one card appended to deck")
		_check(after_state["deck"].back() == card_id,
			"new pool " + card_id + ": appended card is the purchased card")
		_check(after_state["deck"].slice(0, before_deck.size()) == before_deck,
			"new pool " + card_id + ": original deck unchanged")
		_check(after_state["gold"] == before_gold - expected_price,
			"new pool " + card_id + ": exact authored price charged (" + str(expected_price) + " gold)")
		_check(after_state["trinkets"] == before_trinkets,
			"new pool " + card_id + ": trinkets unchanged by card purchase")

		# Sold flag only on bought listing; other listings keep their owner and price.
		var bought_sold := false
		for listing in after_stock.get("cards", []):
			if listing.get("id") == card_id:
				_check(listing.get("sold") == true,
					"new pool " + card_id + ": bought card marked sold")
				bought_sold = true
			else:
				_check(listing.get("sold") == false,
					"new pool " + card_id + ": other card listings remain unsold")
				var matching_before: Dictionary = {}
				for before_listing in before_stock.get("cards", []):
					if before_listing.get("id") == listing.get("id"):
						matching_before = before_listing
						break
				_check(listing.get("owner") == matching_before.get("owner")
					and listing.get("price") == matching_before.get("price"),
					"new pool " + card_id + ": other card listing owner and price unchanged")
		_check(bought_sold, "new pool " + card_id + ": purchased card listing exists and is sold")

		# Trinket listings unchanged.
		for index in range(after_stock.get("trinkets", []).size()):
			_check(after_stock["trinkets"][index]["id"] == before_stock["trinkets"][index]["id"],
				"new pool " + card_id + ": trinket listing ID unchanged")
			_check(after_stock["trinkets"][index]["price"] == before_stock["trinkets"][index]["price"],
				"new pool " + card_id + ": trinket listing price unchanged")
			_check(after_stock["trinkets"][index]["sold"] == before_stock["trinkets"][index]["sold"],
				"new pool " + card_id + ": trinket listing sold status unchanged")

		# Receipt verifies kind, ID, exact price.
		var receipt: Dictionary = buy_result.get("receipt", {})
		_check(receipt.get("kind") == "card" and receipt.get("id") == card_id and receipt.get("price") == expected_price,
			"new pool " + card_id + ": receipt matches kind, ID and exact price")

		# Insufficient funds must reject without mutation.
		var poor := RunShopPurchases.new(party, deck, [], 0, found_result["cards"], found_result["trinkets"])
		_check(poor.is_valid(), "new pool " + card_id + ": goldless visit is valid")
		var poor_state := poor.get_state()
		var poor_stock := poor.get_stock()
		var denied := poor.buy("card", card_id)
		_check(not denied.get("ok", true), "new pool " + card_id + ": unaffordable purchase refused")
		_check(poor.get_state() == poor_state and poor.get_stock() == poor_stock,
			"new pool " + card_id + ": refused purchase leaves state and stock unchanged")

		# Second buy must fail and leave everything unchanged.
		var repeat_buy := purchases.buy("card", card_id)
		_check(not repeat_buy.get("ok", true), "new pool " + card_id + ": second purchase refused")
		_check(purchases.get_state() == after_state and purchases.get_stock() == after_stock,
			"new pool " + card_id + ": repeated purchase leaves state and stock unchanged")


## AC1/AC2/AC3: the four playable Warden pool base cards (Heavy Thimble,
## Pin and Pound, Draw Fire, Counter-stitch) are authored at their established
## quotes, appear in genuine seeded five-card/two-trinket visits that replay,
## and can be bought once through the real RunShopPurchases service.
func _test_warden_pool_shop_offers_and_purchases(party: Array[String], deck: Array[String],
		catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var candidates: Array = authored.get("cards", [])
	var trinkets: Array = authored.get("trinkets", [])
	var warden_pool := WardenPoolCards.new()

	# AC1: each new base ID is authored exactly once at its Warden quote and
	# matches the real playable catalog definition.
	var count_by_id := {}
	for entry in candidates:
		if entry is Dictionary and entry.get("id") is String:
			count_by_id[entry.id] = int(count_by_id.get(entry.id, 0)) + 1
	for card_id in WARDEN_STOCK_SPECS:
		var spec: Dictionary = WARDEN_STOCK_SPECS[card_id]
		_check(not String(card_id).ends_with("_plus"),
			"warden stock candidate is a base ID: " + card_id)
		_check(count_by_id.get(card_id, 0) == 1,
			"warden stock card occurs exactly once in authored pool: " + card_id)
		var found_json := false
		for entry in candidates:
			if entry is Dictionary and entry.get("id") == card_id:
				found_json = true
				_check(entry.get("owner") == spec["owner"],
					"warden stock authored owner: " + card_id)
				_check(_whole_price(entry.get("price")) == spec["price"],
					"warden stock authored price: " + card_id)
		_check(found_json, "warden stock card present in authored JSON: " + card_id)
		_check(warden_pool.get_base_ids().has(card_id),
			"warden stock card is a real Warden pool base ID: " + card_id)
		var def: Dictionary = warden_pool.get_definition(card_id)
		_check(def.get("id") == card_id and def.get("owner") == spec["owner"]
			and def.get("rarity") == spec["rarity"] and def.get("cost") == spec["cost"]
			and def.get("from_positions") == spec["from"]
			and def.get("to_positions") == spec["to"]
			and def.get("target_kind") == spec["target"]
			and def.get("effects") == spec["effects"]
			and def.get("reward_eligible") == true
			and def.get("upgrade_id") == card_id + "_plus"
			and def.get("starting_copies") == 0,
			"warden stock catalog definition matches authored rules: " + card_id)
	# The earlier authored card and trinket records are untouched by the append.
	for card_id in EXISTING_SHOP_CARDS:
		var previous: Dictionary = EXISTING_SHOP_CARDS[card_id]
		_check(count_by_id.get(card_id, 0) == 1,
			"earlier Shop candidate still listed exactly once: " + card_id)
		for entry in candidates:
			if entry is Dictionary and entry.get("id") == card_id:
				_check(entry.get("owner") == previous["owner"]
					and _whole_price(entry.get("price")) == previous["price"],
					"earlier Shop candidate keeps its owner and quote: " + card_id)
	var trinket_counts := {}
	for entry in trinkets:
		if entry is Dictionary and entry.get("id") is String:
			trinket_counts[entry.id] = int(trinket_counts.get(entry.id, 0)) + 1
	for trinket_id in EXISTING_SHOP_TRINKETS:
		_check(trinket_counts.get(trinket_id, 0) == 1,
			"earlier Shop trinket still listed exactly once: " + trinket_id)
		for entry in trinkets:
			if entry is Dictionary and entry.get("id") == trinket_id:
				_check(_whole_price(entry.get("price")) == EXISTING_SHOP_TRINKETS[trinket_id],
					"earlier Shop trinket keeps its price: " + trinket_id)

	# AC2: a bounded deterministic seed sweep finds each new card in a genuine
	# five-card/two-trinket visit; replaying that seed reproduces the stock and
	# the next RNG state.
	var max_seed_offset := 1000
	for card_id in WARDEN_STOCK_SPECS:
		var expected_owner: String = WARDEN_STOCK_SPECS[card_id]["owner"]
		var expected_price: int = WARDEN_STOCK_SPECS[card_id]["price"]
		var found_seed := -1
		var found_result: Dictionary = {}
		for offset in range(max_seed_offset):
			var test_rng := _rng(SEED + 600 + offset)
			var test_result := RunShopStockOffers.generate(test_rng, party, candidates, trinkets, [])
			if not test_result.get("ok", false):
				continue
			for offer in test_result.get("cards", []):
				if offer.get("id") == card_id:
					found_seed = SEED + 600 + offset
					found_result = test_result
					break
			if found_seed >= 0:
				break
		_check(found_seed >= 0,
			"seeded Shop offer found for warden stock card: " + card_id)
		if found_seed < 0:
			continue
		var found_cards: Array = found_result.get("cards", [])
		var found_trinkets: Array = found_result.get("trinkets", [])
		_check(found_cards.size() == 5 and found_trinkets.size() == 2,
			"warden stock " + card_id + ": found visit holds five cards and two trinkets")
		var matched_offer := {}
		var offered_ids: Array[String] = []
		var distinct := {}
		for offer in found_cards:
			var offered_id: String = offer.get("id", "")
			offered_ids.append(offered_id)
			distinct[offered_id] = true
			_check(not offered_id.ends_with("_plus"),
				"warden stock " + card_id + ": no upgrade is ever offered")
			if offered_id == card_id:
				matched_offer = offer
		_check(offered_ids.size() == 5 and distinct.size() == 5,
			"warden stock " + card_id + ": five distinct card offers")
		_check(matched_offer.get("owner") == expected_owner,
			"warden stock " + card_id + ": offered owner matches catalog")
		_check(matched_offer.get("price") == expected_price,
			"warden stock " + card_id + ": offered price matches authored quote")
		# Repeating the found seed reproduces the offers and leaves the same
		# run RNG state, independently checked against the sorted-pool oracle.
		var replay_rng := _rng(found_seed)
		var replay_result := RunShopStockOffers.generate(replay_rng, party, candidates, trinkets, [])
		var oracle_rng := _rng(found_seed)
		var oracle := _oracle(catalog, party, candidates, trinkets, [], oracle_rng)
		_check(replay_result == found_result,
			"warden stock " + card_id + ": repeated seed reproduces the offers")
		_check(replay_result.get("cards", []) == oracle.cards
			and replay_result.get("trinkets", []) == oracle.trinkets,
			"warden stock " + card_id + ": offers match the independent oracle")
		_check(replay_rng.state == oracle_rng.state and replay_rng.randi() == oracle_rng.randi(),
			"warden stock " + card_id + ": replay preserves the next RNG state and draw")

		# AC3: a funded visit buys the exact base ID once at the authored quote.
		var purchases := RunShopPurchases.new(party, deck, [], 500, found_result["cards"],
			found_result["trinkets"])
		_check(purchases.is_valid(),
			"warden stock " + card_id + ": generated stock admits real purchase service")
		var before_state := purchases.get_state()
		var before_stock := purchases.get_stock()
		var buy_result := purchases.buy("card", card_id)
		_check(buy_result.get("ok", false),
			"warden stock " + card_id + ": card purchase succeeds")
		var after_state := purchases.get_state()
		var after_stock := purchases.get_stock()
		_check(after_state["deck"].size() == before_state["deck"].size() + 1,
			"warden stock " + card_id + ": exactly one card appended")
		_check(after_state["deck"].back() == card_id,
			"warden stock " + card_id + ": appended card is the exact base ID")
		_check(after_state["deck"].slice(0, before_state["deck"].size()) == before_state["deck"],
			"warden stock " + card_id + ": original deck unchanged")
		_check(after_state["gold"] == before_state["gold"] - expected_price,
			"warden stock " + card_id + ": exact authored price charged once")
		_check(after_state["trinkets"] == before_state["trinkets"],
			"warden stock " + card_id + ": card purchase adds no trinket")
		var bought_sold := false
		for listing in after_stock.get("cards", []):
			if listing.get("id") == card_id:
				_check(listing.get("sold") == true,
					"warden stock " + card_id + ": bought card marked sold")
				bought_sold = true
			else:
				_check(listing.get("sold") == false,
					"warden stock " + card_id + ": other card listings remain unsold")
		_check(bought_sold,
			"warden stock " + card_id + ": purchased listing exists and is sold")
		var receipt: Dictionary = buy_result.get("receipt", {})
		_check(receipt.get("kind") == "card" and receipt.get("id") == card_id
			and receipt.get("price") == expected_price,
			"warden stock " + card_id + ": receipt matches kind, ID and exact price")

		# An unaffordable attempt is a genuine boundary: one gold short.
		var poor := RunShopPurchases.new(party, deck, [], expected_price - 1,
			found_result["cards"], found_result["trinkets"])
		_check(poor.is_valid(), "warden stock " + card_id + ": near-funds visit is valid")
		var poor_state := poor.get_state()
		var poor_stock := poor.get_stock()
		var denied := poor.buy("card", card_id)
		_check(not denied.get("ok", true),
			"warden stock " + card_id + ": unaffordable purchase refused")
		_check(poor.get_state() == poor_state and poor.get_stock() == poor_stock,
			"warden stock " + card_id + ": refused purchase leaves gold, deck and stock unchanged")

		# A second purchase of the same sold listing refuses without mutation.
		var repeat_buy := purchases.buy("card", card_id)
		_check(not repeat_buy.get("ok", true),
			"warden stock " + card_id + ": second purchase refused")
		_check(purchases.get_state() == after_state and purchases.get_stock() == after_stock,
			"warden stock " + card_id + ": repeated purchase leaves state and stock unchanged")

	# AC3: the _plus upgrades never enter Shop stock for these base IDs.
	for card_id in WARDEN_STOCK_SPECS:
		var upgrade_id: String = card_id + "_plus"
		_check(warden_pool.has_card(upgrade_id), "real upgrade exists: " + upgrade_id)
		_check(_pool_has_id(candidates, upgrade_id) == false,
			"no warden upgrade listing in the authored Shop pool: " + upgrade_id)
		_reject("warden upgrade as Shop candidate " + upgrade_id, _rng(), party,
			_with_card(candidates, 0, {"id": upgrade_id, "price": WARDEN_STOCK_SPECS[card_id]["price"]}),
			trinkets, [])


## AC1/AC2/AC3: all seven Seamstress D2-1 healing/Bleed Shop bases.
## Use the *shipped* catalog and candidate JSON, never synthetic stock or a
## catalog-wide count/index. Independently check each base and its Rest + form.
func _test_seamstress_shop_stock_and_purchases(party: Array[String], deck: Array[String],
		catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var candidates: Array = authored.get("cards", [])
	var trinkets: Array = authored.get("trinkets", [])
	var seamstress := SeamstressPoolCards.new()
	var counts := {}
	for entry in candidates:
		if entry is Dictionary and entry.get("id") is String:
			counts[entry["id"]] = int(counts.get(entry["id"], 0)) + 1

	for card_id in SEAMSTRESS_STOCK_SPECS:
		var spec: Dictionary = SEAMSTRESS_STOCK_SPECS[card_id]
		var expected_price: int = spec["price"]
		var upgrade_id: String = card_id + "_plus"
		_check(POOL_CARD_PRICES.get(card_id, -1) == expected_price,
			"seamstress stock " + card_id + ": established pool price matches fixture")
		_check(counts.get(card_id, 0) == 1,
			"seamstress stock " + card_id + ": exactly one shipped base offer")
		_check(counts.get(upgrade_id, 0) == 0 and not deck.has(card_id) and not deck.has(upgrade_id),
			"seamstress stock " + card_id + ": neither a + listing nor a starter copy")
		var authored_entry := {}
		for entry in candidates:
			if entry is Dictionary and entry.get("id") == card_id:
				authored_entry = entry
				break
		_check(authored_entry.get("owner") == "seamstress"
			and _whole_price(authored_entry.get("price")) == expected_price,
			"seamstress stock " + card_id + ": shipped owner and exact quote")
		var base: Dictionary = seamstress.get_definition(card_id)
		var plus: Dictionary = seamstress.get_definition(upgrade_id)
		_check(seamstress.get_base_ids().has(card_id) and not catalog.has_card(card_id)
			and base.get("id") == card_id and base.get("owner") == "seamstress"
			and base.get("reward_eligible") == true and base.get("starting_copies") == 0
			and base.get("upgrade_id") == upgrade_id and not base.has("upgrade_of"),
			"seamstress stock " + card_id + ": canonical nonstarter reward-eligible base")
		_check(base.get("rarity") == spec["rarity"]
			and base.get("cost") == spec["cost"] and base.get("from_positions") == spec["from"]
			and base.get("target_kind") == spec["target"] and base.get("to_positions") == spec["to"]
			and base.get("effects") == spec["effects"],
			"seamstress stock " + card_id + ": exact base cost, targets and effects")
		_check(plus.get("id") == upgrade_id and plus.get("owner") == "seamstress"
			and plus.get("rarity") == spec["rarity"] and plus.get("cost") == spec["plus_cost"]
			and plus.get("from_positions") == spec["from"]
			and plus.get("target_kind") == spec["target"] and plus.get("to_positions") == spec["to"]
			and plus.get("effects") == spec["plus_effects"]
			and plus.get("upgrade_of") == card_id and plus.get("reward_eligible") == false
			and plus.get("starting_copies") == 0,
			"seamstress stock " + card_id + ": Rest upgrade catalog rules retained")

		# A fixed and bounded series of seeded *actual* five-plus-two visits,
		# not a fabricated favorable listing or a fixed global catalog index.
		var found_seed: int = -1
		var found: Dictionary = {}
		for offset in range(1000):
			var probe_seed: int = SEED + 700 + offset
			var probe := RunShopStockOffers.generate(_rng(probe_seed), party, candidates, trinkets, [])
			if not probe.get("ok", false):
				continue
			for listing in probe.get("cards", []):
				if listing.get("id") == card_id:
					found_seed = probe_seed
					found = probe
					break
			if found_seed >= 0:
				break
		_check(found_seed >= 0, "seamstress stock " + card_id + ": real stock found within 1000 fixed seeds")
		if found_seed < 0:
			continue

		var cards: Array = found.get("cards", [])
		var patches: Array = found.get("trinkets", [])
		_check(cards.size() == 5 and patches.size() == 2,
			"seamstress stock " + card_id + ": five card and two trinket listings")
		var card_ids := {}
		for listing in cards:
			card_ids[listing.get("id")] = true
			_check(not String(listing.get("id", "")).ends_with("_plus"),
				"seamstress stock " + card_id + ": no generated pool upgrade listing")
		_check(card_ids.size() == 5,
			"seamstress stock " + card_id + ": five distinct base cards")
		_check(patches[0].get("id") != patches[1].get("id"),
			"seamstress stock " + card_id + ": two distinct trinkets")
		var selected: Dictionary = {}
		for listing in cards:
			_check(_whole_price(listing.get("price")) == _pool_price(candidates, listing.get("id", "")),
				"seamstress stock " + card_id + ": generated card has authored quote")
			if listing.get("id") == card_id:
				selected = listing
		_check(selected.get("owner") == "seamstress" and selected.get("price") == expected_price,
			"seamstress stock " + card_id + ": canonical selected owner and price")
		# Independent sorted-pool oracle proves seven draws and the next RNG value.
		var stock_rng := _rng(found_seed)
		var oracle_rng := _rng(found_seed)
		var replay_rng := _rng(found_seed)
		var oracle: Dictionary = _oracle(catalog, party, candidates, trinkets, [], oracle_rng)
		var stock: Dictionary = RunShopStockOffers.generate(stock_rng, party, candidates, trinkets, [])
		var cards_reordered := candidates.duplicate(true)
		var trinkets_reordered := trinkets.duplicate(true)
		cards_reordered.reverse()
		trinkets_reordered.reverse()
		var replay: Dictionary = RunShopStockOffers.generate(
			replay_rng, party, cards_reordered, trinkets_reordered, [])
		_check(stock == found and stock.get("cards", []) == oracle["cards"]
			and stock.get("trinkets", []) == oracle["trinkets"],
			"seamstress stock " + card_id + ": independently sorted seeded stock oracle")
		_check(replay == stock and replay_rng.state == stock_rng.state
			and stock_rng.state == oracle_rng.state
			and replay_rng.randi() == stock_rng.randi(),
			"seamstress stock " + card_id + ": input reorder and RNG replay")

		# The paid purchase uses the *actual generated* five-plus-two stock.
		var shop := RunShopPurchases.new(party, deck, [], 500, cards, patches)
		_check(shop.is_valid(), "seamstress stock " + card_id + ": generated visit opens")
		if not shop.is_valid():
			continue
		var before_state: Dictionary = shop.get_state()
		var before_stock: Dictionary = shop.get_stock()
		var paid: Dictionary = shop.buy("card", card_id)
		var after_state: Dictionary = shop.get_state()
		var after_stock: Dictionary = shop.get_stock()
		_check(paid.get("ok", false) and paid.get("receipt", {}) ==
			{"kind": "card", "id": card_id, "price": expected_price},
			"seamstress stock " + card_id + ": paid receipt exactly matches")
		_check(after_state["deck"] == before_state["deck"] + [card_id]
			and after_state["gold"] == before_state["gold"] - expected_price
			and after_state["trinkets"] == before_state["trinkets"]
			and after_state["party_ids"] == before_state["party_ids"],
			"seamstress stock " + card_id + ": exactly one base copy, exact debit and no side effects")
		var expected_stock: Dictionary = before_stock.duplicate(true)
		var found_listing := false
		for listing in expected_stock["cards"]:
			if listing.get("id") == card_id:
				listing["sold"] = true
				found_listing = true
		_check(found_listing and after_stock == expected_stock,
			"seamstress stock " + card_id + ": only purchased card sold; other offers and trinkets intact")
		var repeat: Dictionary = shop.buy("card", card_id)
		_check(not repeat.get("ok", true)
			and shop.get_state() == after_state and shop.get_stock() == after_stock,
			"seamstress stock " + card_id + ": second click refused without mutation")

		var poor := RunShopPurchases.new(party, deck, [], 0, cards, patches)
		_check(poor.is_valid(), "seamstress stock " + card_id + ": genuine goldless visit opens")
		if poor.is_valid():
			var poor_state: Dictionary = poor.get_state()
			var poor_stock: Dictionary = poor.get_stock()
			var denied: Dictionary = poor.buy("card", card_id)
			_check(not denied.get("ok", true) and poor.get_state() == poor_state
				and poor.get_stock() == poor_stock,
				"seamstress stock " + card_id + ": zero gold rejects with all state and stock unchanged")

		# A genuine but upgraded pool candidate remains fail-closed, without
		# drawing the RNG even once or silently shrinking the candidate pool.
		_reject("seamstress + candidate " + upgrade_id, _rng(found_seed), party,
			_with_card(candidates, 0, {"id": upgrade_id, "owner": "seamstress", "price": expected_price}),
			trinkets, [])


## AC1/AC2/AC3: the three M04 D2-2 cross-hero Pinned enabler COMMON base cards
## (Warden Pinning Jab, Seamstress Needle Pin, Tinker Spring Trap) are stocked
## once at their established 50-gold pool quote, can all occupy one genuine
## seeded five-card/two-trinket visit, and each buys exactly its base ID for
## exactly 50 gold through the real RunShopPurchases service.
func _test_pinned_enabler_shop_offers_and_purchases(party: Array[String],
		deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var candidates: Array = authored.get("cards", [])
	var trinkets: Array = authored.get("trinkets", [])
	var warden := WardenPoolCards.new()
	var seamstress := SeamstressPoolCards.new()
	var tinker := TinkerPoolCards.new()
	var counts := {}
	for entry in candidates:
		if entry is Dictionary and entry.get("id") is String:
			counts[entry["id"]] = int(counts.get(entry["id"], 0)) + 1

	# AC1: exactly one priced base listing per Pinned enabler, and the real
	# unreplaced pool definition keeps its authored rules byte for byte.
	for card_id in PINNED_STOCK_SPECS:
		var spec: Dictionary = PINNED_STOCK_SPECS[card_id]
		var expected_price: int = spec["price"]
		var base_ids: Array[String] = []
		var definition: Dictionary = {}
		if spec["owner"] == "warden":
			base_ids = warden.get_base_ids()
			definition = warden.get_definition(card_id)
		elif spec["owner"] == "seamstress":
			base_ids = seamstress.get_base_ids()
			definition = seamstress.get_definition(card_id)
		else:
			base_ids = tinker.get_pool_card_ids()
			definition = tinker.get_definition(card_id)
		_check(not String(card_id).ends_with("_plus"),
			"pinned stock " + card_id + ": base ID only, never an upgrade listing")
		_check(counts.get(card_id, 0) == 1,
			"pinned stock " + card_id + ": listed exactly once in the authored Shop")
		_check(counts.get(card_id + "_plus", 0) == 0,
			"pinned stock " + card_id + ": no _plus upgrade is ever listed")
		var authored_entry: Dictionary = {}
		for entry in candidates:
			if entry is Dictionary and entry.get("id") == card_id:
				authored_entry = entry
				break
		_check(authored_entry.get("owner") == spec["owner"]
			and _whole_price(authored_entry.get("price")) == expected_price,
			"pinned stock " + card_id + ": authored owner and exact 50-gold quote")
		_check(POOL_CARD_PRICES.get(card_id, -1) == expected_price,
			"pinned stock " + card_id + ": quote matches the established pool price")
		var schema_ok: bool = definition.get("starting_copies") == 0 \
			and definition.get("upgrade_id") == card_id + "_plus" \
			and not definition.has("upgrade_of")
		if spec["owner"] == "tinker":
			# TinkerPoolCards keeps its own authored schema (is_upgrade/base_id)
			# instead of reward_eligible; the definition is not normalized.
			schema_ok = schema_ok and definition.get("is_upgrade") == false \
				and definition.get("base_id") == card_id
		else:
			schema_ok = schema_ok and definition.get("reward_eligible") == true
		_check(base_ids.has(card_id) and definition.get("id") == card_id
			and definition.get("owner") == spec["owner"]
			and definition.get("rarity") == spec["rarity"]
			and definition.get("cost") == spec["cost"]
			and definition.get("from_positions") == spec["from"]
			and definition.get("to_positions") == spec["to"]
			and definition.get("target_kind") == spec["target"]
			and definition.get("effects") == spec["effects"]
			and schema_ok,
			"pinned stock " + card_id + ": real common Pinned base catalog rules")
		_check(not deck.has(card_id) and not deck.has(card_id + "_plus"),
			"pinned stock " + card_id + ": not a starter copy, only bought")

	# AC4: a forged owner, a duplicate listing or the _plus upgrade of a new
	# Pinned base still fails closed before any RNG draw.
	for card_id in PINNED_STOCK_SPECS:
		var spec: Dictionary = PINNED_STOCK_SPECS[card_id]
		var forged_owner: String = "seamstress" if spec["owner"] != "seamstress" else "warden"
		_reject("pinned stock " + card_id + " forged owner", _rng(), party,
			_with_card(candidates, 0, {"id": card_id, "owner": forged_owner, "price": spec["price"]}),
			trinkets, [])
		_reject("pinned stock " + card_id + " duplicate listing", _rng(), party,
			_with_card(candidates, 0, {"id": card_id, "owner": spec["owner"], "price": spec["price"]}),
			trinkets, [])
		_reject("pinned stock " + card_id + " _plus candidate", _rng(), party,
			_with_card(candidates, 0, {"id": card_id + "_plus", "owner": spec["owner"], "price": spec["price"]}),
			trinkets, [])

	# AC1: the named earlier Shop entries keep their own ID/owner/price listing.
	var earlier := {}
	for group in [EXISTING_SHOP_CARDS, WARDEN_STOCK_SPECS, SEAMSTRESS_STOCK_SPECS]:
		for card_id in group:
			earlier[card_id] = {"owner": group[card_id]["owner"], "price": group[card_id]["price"]}
	for card_id in earlier:
		var previous: Dictionary = earlier[card_id]
		_check(counts.get(card_id, 0) == 1,
			"pinned stock " + card_id + ": earlier Shop card retained exactly once")
		var entry: Dictionary = {}
		for candidate in candidates:
			if candidate is Dictionary and candidate.get("id") == card_id:
				entry = candidate
				break
		_check(entry.get("owner") == previous["owner"]
			and _whole_price(entry.get("price")) == previous["price"],
			"pinned stock " + card_id + ": earlier Shop owner and quote unchanged")
	var trinket_counts := {}
	for entry in trinkets:
		if entry is Dictionary and entry.get("id") is String:
			trinket_counts[entry["id"]] = int(trinket_counts.get(entry["id"], 0)) + 1
	for trinket_id in EXISTING_SHOP_TRINKETS:
		_check(trinket_counts.get(trinket_id, 0) == 1,
			"pinned stock " + trinket_id + ": authored trinket still listed once")

	# AC2: one compact five-candidate fixture (all three Pinned bases) forces a
	# genuine five-card/two-trinket visit in which all three are stocked.
	var pinned_cards: Array = [
		{"id": "warden_pinning_jab", "owner": "warden", "price": 50},
		{"id": "seamstress_needle_pin", "owner": "seamstress", "price": 50},
		{"id": "tinker_spring_trap", "owner": "tinker", "price": 50},
		{"id": "warden_strike", "owner": "warden", "price": 50},
		{"id": "seamstress_prick", "owner": "seamstress", "price": 50},
	]
	var pinned_trinkets: Array = [
		{"id": "fixture_pin_badge", "price": 90},
		{"id": "fixture_spare_spool", "price": 110},
	]
	var stock_rng := _rng(SEED + 800)
	var oracle_rng := _rng(SEED + 800)
	var stock := RunShopStockOffers.generate(stock_rng, party, pinned_cards, pinned_trinkets, [])
	var expected := _oracle(catalog, party, pinned_cards, pinned_trinkets, [], oracle_rng)
	_check(stock.get("ok", false), "pinned stock: compact five-card fixture generates a visit")
	if not stock.get("ok", false):
		return
	_check(stock.get("cards", []).size() == 5 and stock.get("trinkets", []).size() == 2,
		"pinned stock: genuine five-card/two-trinket visit")
	_check(stock.get("cards", []) == expected.cards and stock.get("trinkets", []) == expected.trinkets,
		"pinned stock: compact visit matches the independent sorted-pool oracle")
	var reversed_cards := pinned_cards.duplicate(true)
	reversed_cards.reverse()
	var reversed_trinkets := pinned_trinkets.duplicate(true)
	reversed_trinkets.reverse()
	var replay_rng := _rng(SEED + 800)
	var replay := RunShopStockOffers.generate(replay_rng, party, reversed_cards, reversed_trinkets, [])
	_check(replay == stock and replay_rng.state == stock_rng.state,
		"pinned stock: reordered candidates replay identical offers and RNG state")
	var distinct := {}
	for offer in stock.get("cards", []):
		distinct[offer.get("id")] = true
		_check(not String(offer.get("id", "")).ends_with("_plus"),
			"pinned stock: no pool upgrade is ever offered")
	_check(distinct.size() == 5, "pinned stock: five distinct card offers")
	for card_id in PINNED_STOCK_SPECS:
		var stocked: Dictionary = {}
		for offer in stock.get("cards", []):
			if offer.get("id") == card_id:
				stocked = offer
		_check(stocked.get("owner") == PINNED_STOCK_SPECS[card_id]["owner"]
			and stocked.get("price") == 50,
			"pinned stock " + card_id + ": eligible and stocked at its authored quote")
		_check(_pool_has_id(candidates, card_id),
			"pinned stock " + card_id + ": present in the shipped candidate pool")

	# AC2: the grown shipped catalog still replays exactly under a fixed seed
	# against the independent oracle, with its next RNG state and draw.
	var full_rng := _rng(SEED + 810)
	var full_oracle_rng := _rng(SEED + 810)
	var full := RunShopStockOffers.generate(full_rng, party, candidates, trinkets, [])
	var full_oracle := _oracle(catalog, party, candidates, trinkets, [], full_oracle_rng)
	_check(full.get("ok", false) and full.get("cards", []) == full_oracle.cards
		and full.get("trinkets", []) == full_oracle.trinkets,
		"pinned stock: full authored catalog replays against the independent oracle")
	_check(full_rng.state == full_oracle_rng.state and full_rng.randi() == full_oracle_rng.randi(),
		"pinned stock: full authored catalog leaves the oracle's next RNG state and draw")

	# AC3: each newly stocked base buys exactly once for exactly 50 gold from a
	# funded fresh visit, appends one physical base copy, marks only its own
	# listing sold, and consumes no run RNG; repeat and goldless buys add nothing.
	for card_id in PINNED_STOCK_SPECS:
		var expected_price: int = PINNED_STOCK_SPECS[card_id]["price"]
		var purchase_rng := _rng(SEED + 820)
		var purchases := RunShopStockOffers.generate(purchase_rng, party, pinned_cards, pinned_trinkets, [])
		var reference_rng := _rng(SEED + 820)
		RunShopStockOffers.generate(reference_rng, party, pinned_cards, pinned_trinkets, [])
		_check(purchases.get("ok", false),
			"pinned stock " + card_id + ": compact stock regenerated for the paid visit")
		if not purchases.get("ok", false):
			continue
		var shop := RunShopPurchases.new(party, deck, [], expected_price,
			purchases["cards"], purchases["trinkets"])
		_check(shop.is_valid(),
			"pinned stock " + card_id + ": exact-fifty-gold visit opens")
		if not shop.is_valid():
			continue
		var before_state: Dictionary = shop.get_state()
		var before_stock: Dictionary = shop.get_stock()
		var copies_before: int = before_state["deck"].count(card_id)
		var paid: Dictionary = shop.buy("card", card_id)
		var after_state: Dictionary = shop.get_state()
		var after_stock: Dictionary = shop.get_stock()
		_check(paid.get("ok", false) and paid.get("receipt", {}) ==
			{"kind": "card", "id": card_id, "price": expected_price},
			"pinned stock " + card_id + ": paid receipt is the exact base ID at 50 gold")
		_check(after_state["deck"] == before_state["deck"] + [card_id]
			and after_state["deck"].count(card_id) == copies_before + 1
			and after_state["deck"].back() == card_id
			and not String(after_state["deck"].back()).ends_with("_plus"),
			"pinned stock " + card_id + ": exactly one physical base copy, never an upgrade")
		_check(after_state["gold"] == before_state["gold"] - expected_price
			and after_state["gold"] == 0,
			"pinned stock " + card_id + ": exactly 50 gold debited, never negative")
		_check(after_state["trinkets"] == before_state["trinkets"]
			and after_state["party_ids"] == before_state["party_ids"],
			"pinned stock " + card_id + ": card purchase touches no trinket or hero")
		var expected_stock: Dictionary = before_stock.duplicate(true)
		var found_listing := false
		for listing in expected_stock["cards"]:
			if listing.get("id") == card_id:
				listing["sold"] = true
				found_listing = true
		_check(found_listing and after_stock == expected_stock,
			"pinned stock " + card_id + ": only that listing sold, other offers intact")

		var repeat: Dictionary = shop.buy("card", card_id)
		_check(not repeat.get("ok", true) and not repeat.has("receipt")
			and shop.get_state() == after_state and shop.get_stock() == after_stock,
			"pinned stock " + card_id + ": repeat buy refused without mutation")

		var poor := RunShopPurchases.new(party, deck, [], 0,
			purchases["cards"], purchases["trinkets"])
		var poor_state: Dictionary = poor.get_state()
		var poor_stock: Dictionary = poor.get_stock()
		var denied: Dictionary = poor.buy("card", card_id)
		_check(poor.is_valid() and not denied.get("ok", true) and not denied.has("receipt")
			and poor.get_state() == poor_state and poor.get_stock() == poor_stock
			and poor_state["deck"] == deck and poor_state["gold"] == 0,
			"pinned stock " + card_id + ": goldless buy refused with no copy or spend")

		_check(purchase_rng.state == reference_rng.state
			and purchase_rng.randi() == reference_rng.randi(),
			"pinned stock " + card_id + ": paid and refused buys consume no run RNG")


## AC1/AC2/AC3: the three M04 Unravel trio Shop bases (Warden Seam Breaker and
## Tinker Spool Launcher / Snip the Seam) are authored exactly once at their
## established quotes, each is individually selectable by a seeded five-card /
## two-trinket stock with its authentic base and Rest-upgrade catalog rules, and
## each buys only its base ID for exactly its quote through RunShopPurchases.
func _test_unravel_trio_shop_offers_and_purchases(party: Array[String], deck: Array[String],
		catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var candidates: Array = authored.get("cards", [])
	var trinkets: Array = authored.get("trinkets", [])
	var warden := WardenPoolCards.new()
	var tinker := TinkerPoolCards.new()
	var counts := {}
	for entry in candidates:
		if entry is Dictionary and entry.get("id") is String:
			counts[entry["id"]] = int(counts.get(entry["id"], 0)) + 1

	# Snip's half-gauge condition reads the live ordinary Unravel thresholds, so
	# pin the authored 8/12/16 and +4-after-break rules that make it meaningful.
	_check(CombatUnravel.THRESHOLD_NORMAL == 8 and CombatUnravel.THRESHOLD_ELITE == 12
		and CombatUnravel.THRESHOLD_BOSS == 16 and CombatUnravel.THRESHOLD_INCREMENT == 4,
		"unravel trio: ordinary Unravel thresholds are 8/12/16 and rise by 4 after a break")

	# AC1: one priced base listing per new ID, backed by the genuine unreplaced
	# catalog definition (base and Rest upgrade), never a _plus Shop entry.
	for card_id in UNRAVEL_STOCK_SPECS:
		var spec: Dictionary = UNRAVEL_STOCK_SPECS[card_id]
		var expected_price: int = spec["price"]
		var upgrade_id: String = card_id + "_plus"
		var base_ids: Array[String] = []
		var base: Dictionary = {}
		var plus: Dictionary = {}
		if spec["owner"] == "warden":
			base_ids = warden.get_base_ids()
			base = warden.get_definition(card_id)
			plus = warden.get_definition(upgrade_id)
		else:
			base_ids = tinker.get_pool_card_ids()
			base = tinker.get_definition(card_id)
			plus = tinker.get_definition(upgrade_id)
		_check(not String(card_id).ends_with("_plus"),
			"unravel trio " + card_id + ": stocked as a base ID only")
		_check(counts.get(card_id, 0) == 1,
			"unravel trio " + card_id + ": listed exactly once in the authored Shop")
		_check(counts.get(upgrade_id, 0) == 0,
			"unravel trio " + card_id + ": no _plus upgrade is ever listed")
		_check(not deck.has(card_id) and not deck.has(upgrade_id),
			"unravel trio " + card_id + ": not an owned starter copy")
		var authored_entry := {}
		for entry in candidates:
			if entry is Dictionary and entry.get("id") == card_id:
				authored_entry = entry
				break
		_check(authored_entry.get("owner") == spec["owner"]
			and _whole_price(authored_entry.get("price")) == expected_price,
			"unravel trio " + card_id + ": authored owner and exact quote")
		_check(POOL_CARD_PRICES.get(card_id, -1) == expected_price,
			"unravel trio " + card_id + ": quote matches the established pool price")
		var schema_ok: bool = base.get("starting_copies") == 0 \
			and base.get("upgrade_id") == upgrade_id and not base.has("upgrade_of")
		if spec["owner"] == "tinker":
			# TinkerPoolCards keeps its own authored schema (is_upgrade/base_id).
			schema_ok = schema_ok and base.get("is_upgrade") == false \
				and base.get("base_id") == card_id
		else:
			schema_ok = schema_ok and base.get("reward_eligible") == true
		_check(base_ids.has(card_id) and base.get("id") == card_id
			and base.get("owner") == spec["owner"]
			and base.get("rarity") == spec["rarity"]
			and base.get("cost") == spec["cost"]
			and base.get("from_positions") == spec["from"]
			and base.get("to_positions") == spec["to"]
			and base.get("target_kind") == spec["target"]
			and base.get("effects") == spec["effects"]
			and schema_ok,
			"unravel trio " + card_id + ": authentic base catalog rules")
		_check(plus.get("id") == upgrade_id and plus.get("owner") == spec["owner"]
			and plus.get("rarity") == spec["rarity"] and plus.get("cost") == spec["plus_cost"]
			and plus.get("from_positions") == spec["from"]
			and plus.get("to_positions") == spec["to"]
			and plus.get("target_kind") == spec["target"]
			and plus.get("effects") == spec["plus_effects"],
			"unravel trio " + card_id + ": Rest upgrade rules retained")

	# AC1: every earlier named Shop card and all three authored trinkets keep
	# their own ID, owner and quote after the base-only append.
	var earlier := {}
	for group in [EXISTING_SHOP_CARDS, NEW_POOL_SPECS, WARDEN_STOCK_SPECS,
			SEAMSTRESS_STOCK_SPECS, PINNED_STOCK_SPECS]:
		for card_id in group:
			earlier[card_id] = {"owner": group[card_id]["owner"],
				"price": group[card_id]["price"]}
	for card_id in earlier:
		var previous: Dictionary = earlier[card_id]
		_check(counts.get(card_id, 0) == 1,
			"unravel trio " + card_id + ": earlier Shop card retained exactly once")
		var entry := {}
		for candidate in candidates:
			if candidate is Dictionary and candidate.get("id") == card_id:
				entry = candidate
				break
		_check(entry.get("owner") == previous["owner"]
			and _whole_price(entry.get("price")) == previous["price"],
			"unravel trio " + card_id + ": earlier Shop owner and quote unchanged")
	var trinket_counts := {}
	for entry in trinkets:
		if entry is Dictionary and entry.get("id") is String:
			trinket_counts[entry["id"]] = int(trinket_counts.get(entry["id"], 0)) + 1
	for trinket_id in EXISTING_SHOP_TRINKETS:
		_check(trinket_counts.get(trinket_id, 0) == 1,
			"unravel trio " + trinket_id + ": authored trinket still listed once")
		var listed := {}
		for entry in trinkets:
			if entry is Dictionary and entry.get("id") == trinket_id:
				listed = entry
				break
		_check(_whole_price(listed.get("price")) == EXISTING_SHOP_TRINKETS[trinket_id],
			"unravel trio " + trinket_id + ": authored trinket quote unchanged")

	# AC2: a bounded deterministic seed sweep proves each new entry is
	# individually selectable in a genuine five-card / two-trinket stock.
	var max_seed_offset := 1000
	for card_id in UNRAVEL_STOCK_SPECS:
		var expected_owner: String = UNRAVEL_STOCK_SPECS[card_id]["owner"]
		var expected_price: int = UNRAVEL_STOCK_SPECS[card_id]["price"]
		var found_seed := -1
		var found: Dictionary = {}
		for offset in range(max_seed_offset):
			var probe_seed: int = SEED + 900 + offset
			var probe := RunShopStockOffers.generate(_rng(probe_seed), party, candidates,
				trinkets, [])
			if not probe.get("ok", false):
				continue
			for listing in probe.get("cards", []):
				if listing.get("id") == card_id:
					found_seed = probe_seed
					found = probe
					break
			if found_seed >= 0:
				break
		_check(found_seed >= 0,
			"unravel trio " + card_id + ": seeded stock selects it within 1000 fixed seeds")
		if found_seed < 0:
			continue
		var cards: Array = found.get("cards", [])
		var patches: Array = found.get("trinkets", [])
		_check(cards.size() == 5 and patches.size() == 2,
			"unravel trio " + card_id + ": five card and two trinket listings")
		var card_ids := {}
		var selected := {}
		for listing in cards:
			card_ids[listing.get("id")] = true
			_check(_whole_price(listing.get("price")) ==
				_pool_price(candidates, listing.get("id", "")),
				"unravel trio " + card_id + ": every listed card keeps its authored quote")
			if listing.get("id") == card_id:
				selected = listing
		_check(card_ids.size() == 5,
			"unravel trio " + card_id + ": five distinct card listings")
		_check(patches[0].get("id") != patches[1].get("id"),
			"unravel trio " + card_id + ": two distinct trinket listings")
		_check(selected.get("owner") == expected_owner
			and selected.get("price") == expected_price,
			"unravel trio " + card_id + ": selected listing is the authored owner and quote")
		# The same seed replays against the independent sorted-pool oracle,
		# including the next RNG state and draw.
		var stock_rng := _rng(found_seed)
		var oracle_rng := _rng(found_seed)
		var replay_rng := _rng(found_seed)
		var oracle: Dictionary = _oracle(catalog, party, candidates, trinkets, [], oracle_rng)
		var stock: Dictionary = RunShopStockOffers.generate(stock_rng, party, candidates,
			trinkets, [])
		var reordered_cards := candidates.duplicate(true)
		var reordered_trinkets := trinkets.duplicate(true)
		reordered_cards.reverse()
		reordered_trinkets.reverse()
		var replay: Dictionary = RunShopStockOffers.generate(replay_rng, party,
			reordered_cards, reordered_trinkets, [])
		_check(stock == found and stock.get("cards", []) == oracle["cards"]
			and stock.get("trinkets", []) == oracle["trinkets"],
			"unravel trio " + card_id + ": seeded stock matches the independent oracle")
		_check(replay == stock and replay_rng.state == stock_rng.state
			and stock_rng.state == oracle_rng.state
			and replay_rng.randi() == stock_rng.randi(),
			"unravel trio " + card_id + ": reorder and RNG replay exactly")

		# AC2: buying the genuinely selected listing spends exactly its quote
		# once, appends only that base card and touches nothing else.
		var shop := RunShopPurchases.new(party, deck, [], expected_price, cards, patches)
		_check(shop.is_valid(),
			"unravel trio " + card_id + ": exact-quote visit opens")
		if not shop.is_valid():
			continue
		var before_state: Dictionary = shop.get_state()
		var before_stock: Dictionary = shop.get_stock()
		var paid: Dictionary = shop.buy("card", card_id)
		var after_state: Dictionary = shop.get_state()
		var after_stock: Dictionary = shop.get_stock()
		_check(paid.get("ok", false) and paid.get("receipt", {}) ==
			{"kind": "card", "id": card_id, "price": expected_price},
			"unravel trio " + card_id + ": paid receipt is the exact base ID and quote")
		_check(after_state["deck"] == before_state["deck"] + [card_id]
			and after_state["deck"].count(card_id) == before_state["deck"].count(card_id) + 1,
			"unravel trio " + card_id + ": only that base card is appended")
		_check(after_state["gold"] == before_state["gold"] - expected_price
			and after_state["gold"] == 0,
			"unravel trio " + card_id + ": quoted gold debited exactly once")
		_check(after_state["trinkets"] == before_state["trinkets"]
			and after_state["party_ids"] == before_state["party_ids"],
			"unravel trio " + card_id + ": purchase touches no trinket or hero")
		var expected_stock: Dictionary = before_stock.duplicate(true)
		var found_listing := false
		for listing in expected_stock["cards"]:
			if listing.get("id") == card_id:
				listing["sold"] = true
				found_listing = true
		_check(found_listing and after_stock == expected_stock,
			"unravel trio " + card_id + ": only the bought listing becomes sold")
		var repeat: Dictionary = shop.buy("card", card_id)
		_check(not repeat.get("ok", true) and not repeat.has("receipt")
			and shop.get_state() == after_state and shop.get_stock() == after_stock,
			"unravel trio " + card_id + ": repeat buy refused without mutation")
		var short := RunShopPurchases.new(party, deck, [], expected_price - 1, cards, patches)
		var short_state: Dictionary = short.get_state()
		var short_stock: Dictionary = short.get_stock()
		var denied: Dictionary = short.buy("card", card_id)
		_check(short.is_valid() and not denied.get("ok", true) and not denied.has("receipt")
			and short.get_state() == short_state and short.get_stock() == short_stock
			and short_state["deck"] == deck,
			"unravel trio " + card_id + ": one gold short refuses with no copy or spend")

	# AC3: a forged owner, duplicate listing or _plus candidate of each new base
	# still fails closed before any seeded draw or caller-pool change.
	for card_id in UNRAVEL_STOCK_SPECS:
		var spec: Dictionary = UNRAVEL_STOCK_SPECS[card_id]
		var forged_owner: String = "tinker" if spec["owner"] == "warden" else "warden"
		_reject("unravel trio " + card_id + ": forged owner", _rng(), party,
			_with_card(candidates, 0,
				{"id": card_id, "owner": forged_owner, "price": spec["price"]}),
			trinkets, [])
		_reject("unravel trio " + card_id + ": duplicate listing", _rng(), party,
			_with_card(candidates, 0,
				{"id": card_id, "owner": spec["owner"], "price": spec["price"]}),
			trinkets, [])
		_reject("unravel trio " + card_id + ": _plus candidate", _rng(), party,
			_with_card(candidates, 0,
				{"id": card_id + "_plus", "owner": spec["owner"], "price": spec["price"]}),
			trinkets, [])



## Rivet Shot and Scatter Bolts are real, priced Shop candidates, while their
## + forms are catalog-only upgrades. Drive the shipped pool and both ledgers.
func _test_tinker_attack_shop_stock(party: Array[String], deck: Array[String],
		catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var candidates: Array = authored.get("cards", [])
	var patches: Array = authored.get("trinkets", [])
	var tinker := TinkerPoolCards.new()
	var counts := {}
	for entry in candidates:
		if entry is Dictionary and entry.get("id") is String:
			counts[entry.id] = int(counts.get(entry.id, 0)) + 1
	# All older entries retain their individual owner and price; no ordered-list
	# or entire-catalog-size expectation depends on other lanes' additions.
	for old_id in EXISTING_SHOP_CARDS:
		var spec: Dictionary = EXISTING_SHOP_CARDS[old_id]
		var matches := candidates.filter(func(entry): return entry.get("id") == old_id)
		_check(matches.size() == 1 and matches[0].get("owner") == spec.owner
			and _whole_price(matches[0].get("price")) == spec.price,
			"Rivet/Scatter admission preserves existing Shop quote: " + old_id)

	for card_id in RIVET_SCATTER_SHOP_SPECS:
		var spec: Dictionary = RIVET_SCATTER_SHOP_SPECS[card_id]
		var upgrade_id: String = card_id + "_plus"
		var quote: int = spec.price
		var matches := candidates.filter(func(entry): return entry.get("id") == card_id)
		_check(counts.get(card_id, 0) == 1 and matches.size() == 1
			and counts.get(upgrade_id, 0) == 0,
			"Tinker " + card_id + ": one Shop base, zero upgrade offers")
		if matches.is_empty():
			continue
		_check(matches[0].get("owner") == "tinker"
			and _whole_price(matches[0].get("price")) == quote
			and POOL_CARD_PRICES.get(card_id, -1) == quote,
			"Tinker " + card_id + ": catalog-owned exact established Shop quote")
		var base: Dictionary = tinker.get_definition(card_id)
		var plus: Dictionary = tinker.get_definition(upgrade_id)
		_check(tinker.get_pool_card_ids().has(card_id) and not catalog.has_card(card_id)
			and not deck.has(card_id) and not deck.has(upgrade_id)
			and base.get("id") == card_id and base.get("base_id") == card_id
			and base.get("upgrade_id") == upgrade_id and base.get("is_upgrade") == false
			and base.get("owner") == "tinker" and base.get("rarity") == "common"
			and base.get("starting_copies") == 0,
			"Tinker " + card_id + ": canonical common reward-only base")
		for definition in [base, plus]:
			var is_plus: bool = definition.get("id") == upgrade_id
			_check(definition.get("id") == (upgrade_id if is_plus else card_id)
				and definition.get("owner") == "tinker" and definition.get("rarity") == "common"
				and definition.get("cost") == 1 and definition.get("from_positions") == spec["from"]
				and definition.get("target_kind") == spec.target
				and definition.get("to_positions") == [1, 2, 3]
				and definition.get("effects") == (spec.plus_effects if is_plus else spec.effects)
				and definition.get("base_id") == card_id and definition.get("upgrade_id") == upgrade_id
				and definition.get("is_upgrade") == is_plus
				and definition.get("starting_copies") == 0,
				"Tinker " + card_id + ": exact base/plus targeting and effects (" + str(is_plus) + ")")

		# Search a bounded fixed range in the actual complete JSON candidate
		# pool; never force the desired ID with a synthetic offer fixture.
		var seed_found: int = -1
		var found: Dictionary = {}
		for offset in range(300):
			var seed_value: int = SEED + 1300 + offset
			var stock: Dictionary = RunShopStockOffers.generate(
				_rng(seed_value), party, candidates, patches, [])
			if not stock.get("ok", false):
				continue
			if stock.cards.any(func(entry): return entry.get("id") == card_id):
				seed_found = seed_value
				found = stock
				break
		_check(seed_found >= 0, "Tinker " + card_id + ": found in bounded genuine seeded stock")
		if seed_found < 0:
			continue
		var card_ids := {}
		for entry in found.cards:
			card_ids[entry.id] = true
			_check(not String(entry.id).ends_with("_plus")
				and _pool_price(candidates, entry.id) == entry.price
				and party.has(entry.owner),
				"Tinker " + card_id + ": every offer is a priced party-owned base")
		var patch_ids := {}
		for entry in found.trinkets:
			patch_ids[entry.id] = true
		_check(found.cards.size() == 5 and card_ids.size() == 5
			and found.trinkets.size() == 2 and patch_ids.size() == 2,
			"Tinker " + card_id + ": five distinct cards and two distinct patches")
		var selected: Dictionary = {}
		for entry in found.cards:
			if entry.id == card_id:
				selected = entry
		_check(selected.get("owner") == "tinker" and selected.get("price") == quote,
			"Tinker " + card_id + ": selected offer has exact owner and quote")
		var original_rng := _rng(seed_found)
		var oracle_rng := _rng(seed_found)
		var replay_rng := _rng(seed_found)
		var original := RunShopStockOffers.generate(original_rng, party, candidates, patches, [])
		var oracle := _oracle(catalog, party, candidates, patches, [], oracle_rng)
		var reversed_cards := candidates.duplicate(true)
		var reversed_patches := patches.duplicate(true)
		reversed_cards.reverse()
		reversed_patches.reverse()
		var replay := RunShopStockOffers.generate(replay_rng, party, reversed_cards, reversed_patches, [])
		_check(original == found and original.cards == oracle.cards
			and original.trinkets == oracle.trinkets and replay == original
			and original_rng.state == oracle_rng.state
			and original_rng.state == replay_rng.state
			and original_rng.randi() == replay_rng.randi(),
			"Tinker " + card_id + ": sorted oracle, reversed candidates and RNG replay")
		var rng_after_stock: int = original_rng.state
		var shop := RunShopPurchases.new(party, deck, [], quote, found.cards, found.trinkets)
		var visit := RunShopVisit.new(deck, quote, 0, [])
		_check(shop.is_valid() and visit.open_visit("shop-" + card_id),
			"Tinker " + card_id + ": real generated purchase and visit ledgers open")
		if not shop.is_valid() or not visit.get_state().removal_available:
			continue
		var before_state := shop.get_state()
		var before_stock := shop.get_stock()
		var unoffered_id := ""
		for entry in candidates:
			if not card_ids.has(entry.id):
				unoffered_id = entry.id
				break
		_check(not unoffered_id.is_empty(), "Tinker " + card_id + ": a real unoffered choice exists")
		var unoffered := shop.buy("card", unoffered_id)
		_check(not unoffered.get("ok", true) and not unoffered.has("receipt")
			and shop.get_state() == before_state and shop.get_stock() == before_stock
			and original_rng.state == rng_after_stock,
			"Tinker " + card_id + ": unoffered choice cannot spend, mutate or draw RNG")
		var bought := shop.buy("card", card_id)
		var after_state := shop.get_state()
		var after_stock := shop.get_stock()
		var expected_stock: Dictionary = before_stock.duplicate(true)
		for entry in expected_stock.cards:
			if entry.id == card_id:
				entry.sold = true
		_check(bought.get("ok", false) and bought.get("receipt", {}) ==
			{"kind": "card", "id": card_id, "price": quote}
			and after_state.deck == before_state.deck + [card_id]
			and after_state.gold == before_state.gold - quote
			and after_state.trinkets == before_state.trinkets
			and after_state.party_ids == before_state.party_ids
			and after_stock == expected_stock and original_rng.state == rng_after_stock,
			"Tinker " + card_id + ": one priced base purchase, only its listing sold")
		_check(visit.reconcile_purchase(bought)
			and visit.get_state().deck == after_state.deck
			and visit.get_state().gold == after_state.gold
			and original_rng.state == rng_after_stock,
			"Tinker " + card_id + ": authentic paid receipt reconciles to run visit")
		var second := shop.buy("card", card_id)
		_check(not second.get("ok", true) and not second.has("receipt")
			and shop.get_state() == after_state and shop.get_stock() == after_stock
			and original_rng.state == rng_after_stock,
			"Tinker " + card_id + ": sold/repeated buy leaves all ledgers and RNG unchanged")
		var poor := RunShopPurchases.new(party, deck, [], quote - 1, found.cards, found.trinkets)
		_check(poor.is_valid(), "Tinker " + card_id + ": one-gold-short visit is valid")
		if poor.is_valid():
			var poor_state := poor.get_state()
			var poor_stock := poor.get_stock()
			var denied := poor.buy("card", card_id)
			_check(not denied.get("ok", true) and not denied.has("receipt")
				and poor.get_state() == poor_state and poor.get_stock() == poor_stock
				and original_rng.state == rng_after_stock,
				"Tinker " + card_id + ": unaffordable buy leaves deck, gold, patches, stock and RNG unchanged")
		_reject("Tinker " + card_id + ": _plus candidate rejected before RNG draw",
			_rng(seed_found), party,
			_with_card(candidates, 0, {"id": upgrade_id, "owner": "tinker", "price": quote}),
			patches, [])


## Peddler: one priced card per party hero, deterministic and fail-closed.
func _test_peddler_cards(party: Array[String], deck: Array[String], catalog: StarterCards) -> void:
	var peddler_cards: Array = [
		{"id": "warden_brace", "owner": "warden", "price": 40},
		{"id": "warden_hold_the_line", "owner": "warden", "price": 55},
		{"id": "seamstress_mend", "owner": "seamstress", "price": 45},
		{"id": "seamstress_darning", "owner": "seamstress", "price": 55},
		{"id": "tinker_tune_up", "owner": "tinker", "price": 35},
		{"id": "tinker_rivet_shot", "owner": "tinker", "price": 50},
	]
	
	# Mixed V3 test
	var v3_party: Array[String] = ["warden", "lantern_monk", "rag_duelist"]
	var v3_peddler_cards: Array = [
		{"id": "warden_brace", "owner": "warden", "price": 40},
		{"id": "warden_hold_the_line", "owner": "warden", "price": 55},
		{"id": "lantern_monk_wick_flicker", "owner": "lantern_monk", "price": 50},
		{"id": "lantern_monk_moth_lure", "owner": "lantern_monk", "price": 50},
		{"id": "rag_duelist_needle_prick", "owner": "rag_duelist", "price": 50},
		{"id": "rag_duelist_needle_lunge", "owner": "rag_duelist", "price": 50},
	]
	
	var v3_party_2: Array[String] = ["seamstress", "scarecrow", "yarn_ranger"]
	var v3_peddler_cards_2: Array = [
		{"id": "seamstress_mend", "owner": "seamstress", "price": 45},
		{"id": "seamstress_darning", "owner": "seamstress", "price": 55},
		{"id": "scarecrow_pitchfork_prick", "owner": "scarecrow", "price": 50},
		{"id": "scarecrow_crow_peck", "owner": "scarecrow", "price": 50},
		{"id": "yarn_ranger_needle_arrow", "owner": "yarn_ranger", "price": 50},
		{"id": "yarn_ranger_tangle_bolas", "owner": "yarn_ranger", "price": 50},
	]

	var v3_rng := _rng(SEED + 9500)
	var v3_rng_oracle := _rng(SEED + 9500)
	var v3_res := RunShopStockOffers.generate_peddler_cards(v3_rng, v3_party, v3_peddler_cards)
	_check(v3_res.get("ok", false), "peddler generates with mixed v3 party 1")
	var expected_v3_cards := _peddler_cards_oracle(v3_party, v3_peddler_cards, v3_rng_oracle)
	_check(v3_res.get("cards", []) == expected_v3_cards, "v3 peddler cards match oracle")
	_check(v3_rng.state == v3_rng_oracle.state, "v3 peddler cards RNG state matches oracle")
	var v3_cards: Array = v3_res.get("cards", [])
	_check(v3_cards.size() == 3, "peddler v3 returns exactly three cards")
	for i in range(3):
		_check(v3_cards[i].get("owner") == v3_party[i], "v3 card " + str(i) + " matches owner")
	for offer in v3_cards:
		var card_id: String = offer.get("id", "")
		_check(_pool_has_id(v3_peddler_cards, card_id), "offered card is from candidate pool: " + card_id)
		var expected_owner: String = ""
		var all_catalogs: Array = RunShopStockOffers._peddler_catalogs()
		var found_def := RunShopStockOffers._find_card_definition(card_id, all_catalogs)
		if not found_def.is_empty():
			expected_owner = found_def["def"].get("owner", "")
		_check(offer.get("owner") == expected_owner, "offer uses correct catalog owner for " + card_id)
		_check(offer.get("price") == _pool_price(v3_peddler_cards, card_id), "offer keeps the supplied price: " + card_id)

	var v3_rng_replay := _rng(SEED + 9500)
	var v3_res_replay := RunShopStockOffers.generate_peddler_cards(v3_rng_replay, v3_party, v3_peddler_cards)
	_check(v3_res_replay.get("cards", []) == v3_res.get("cards", []), "v3 peddler cards seeded replay")

	var v3_rng2 := _rng(SEED + 9501)
	var v3_rng_oracle2 := _rng(SEED + 9501)
	var v3_res2 := RunShopStockOffers.generate_peddler_cards(v3_rng2, v3_party_2, v3_peddler_cards_2)
	_check(v3_res2.get("ok", false), "peddler generates with mixed v3 party 2")
	var expected_v3_cards2 := _peddler_cards_oracle(v3_party_2, v3_peddler_cards_2, v3_rng_oracle2)
	_check(v3_res2.get("cards", []) == expected_v3_cards2, "v3 peddler cards 2 match oracle")
	_check(v3_rng2.state == v3_rng_oracle2.state, "v3 peddler cards 2 RNG state matches oracle")
	var v3_cards2: Array = v3_res2.get("cards", [])
	_check(v3_cards2.size() == 3, "peddler v3 returns exactly three cards")
	for i in range(3):
		_check(v3_cards2[i].get("owner") == v3_party_2[i], "v3 card " + str(i) + " matches owner")
	for offer in v3_cards2:
		var card_id: String = offer.get("id", "")
		_check(_pool_has_id(v3_peddler_cards_2, card_id), "offered card is from candidate pool: " + card_id)
		var expected_owner: String = ""
		var all_catalogs: Array = RunShopStockOffers._peddler_catalogs()
		var found_def := RunShopStockOffers._find_card_definition(card_id, all_catalogs)
		if not found_def.is_empty():
			expected_owner = found_def["def"].get("owner", "")
		_check(offer.get("owner") == expected_owner, "offer uses correct catalog owner for " + card_id)
		_check(offer.get("price") == _pool_price(v3_peddler_cards_2, card_id), "offer keeps the supplied price: " + card_id)

	var v3_rng_replay2 := _rng(SEED + 9501)
	var v3_res_replay2 := RunShopStockOffers.generate_peddler_cards(v3_rng_replay2, v3_party_2, v3_peddler_cards_2)
	_check(v3_res_replay2.get("cards", []) == v3_res2.get("cards", []), "v3 peddler cards 2 seeded replay")

	var v3_reject_plus = v3_peddler_cards.duplicate(true)
	v3_reject_plus.append({"id": "lantern_monk_wick_flicker_plus", "owner": "lantern_monk", "price": 50})
	_reject_peddler_cards("v3 peddler cards plus-only candidate", _rng(SEED), v3_party, v3_reject_plus)

	var v3_reject_unk = v3_peddler_cards.duplicate(true)
	v3_reject_unk.append({"id": "unknown_v3_card", "owner": "lantern_monk", "price": 50})
	_reject_peddler_cards("v3 peddler cards unknown card", _rng(SEED), v3_party, v3_reject_unk)
	
	# A correctly authored card for a hero outside the party is validated and
	# then ignored for selection; it neither shrinks nor rejects party stock.
	var v3_out_of_party: Array = v3_peddler_cards.duplicate(true)
	v3_out_of_party[2] = {"id": "scarecrow_pitchfork_prick", "owner": "scarecrow", "price": 50}
	var v3_oop_rng := _rng(SEED + 9600)
	var v3_oop_oracle_rng := _rng(SEED + 9600)
	var v3_oop_res := RunShopStockOffers.generate_peddler_cards(v3_oop_rng, v3_party, v3_out_of_party)
	_check(v3_oop_res.get("ok", false),
		"peddler cards accept a valid authored out-of-party card")
	var v3_oop_cards: Array = v3_oop_res.get("cards", [])
	_check(v3_oop_cards.size() == 3, "out-of-party card does not consume a party slot")
	for i in range(mini(v3_oop_cards.size(), 3)):
		_check(v3_oop_cards[i].get("owner") == v3_party[i],
			"out-of-party card keeps one offer per party hero in order")
		_check(v3_oop_cards[i].get("id") != "scarecrow_pitchfork_prick",
			"out-of-party card is never offered")
	_check(v3_oop_cards == _peddler_cards_oracle(v3_party, v3_out_of_party, v3_oop_oracle_rng)
		and v3_oop_rng.state == v3_oop_oracle_rng.state,
		"out-of-party card leaves only party pools and the three-draw oracle")

	var v3_reject_spoofed = v3_peddler_cards.duplicate(true)
	v3_reject_spoofed[2] = {"id": "lantern_monk_wick_flicker", "owner": "rag_duelist", "price": 50}
	_reject_peddler_cards("v3 peddler cards spoofed owner", _rng(SEED), v3_party, v3_reject_spoofed)

	var v3_reject_dup = v3_peddler_cards.duplicate(true)
	v3_reject_dup[3] = {"id": "lantern_monk_wick_flicker", "owner": "lantern_monk", "price": 50}
	_reject_peddler_cards("v3 peddler cards duplicate", _rng(SEED), v3_party, v3_reject_dup)

	var v3_reject_missing = [v3_peddler_cards[0], v3_peddler_cards[2]]
	_reject_peddler_cards("v3 peddler cards missing party-owner card", _rng(SEED), v3_party, v3_reject_missing)

	var v3_reject_malformed = v3_peddler_cards.duplicate(true)
	v3_reject_malformed[0] = {"id": "warden_brace", "owner": "warden", "price": -10}
	_reject_peddler_cards("v3 peddler cards malformed price", _rng(SEED), v3_party, v3_reject_malformed)

	# Success: exactly one per hero in party order.
	var rng2 := _rng(SEED + 9000)
	var result2 := RunShopStockOffers.generate_peddler_cards(rng2, party, peddler_cards)
	_check(result2.get("ok", false), "peddler generates with two cards per hero")
	var cards: Array = result2.get("cards", [])
	_check(cards.size() == 3, "peddler returns exactly three cards")
	# Build expected oracle.
	var groups := {"warden": [], "seamstress": [], "tinker": []}
	for entry in peddler_cards:
		var owner: String = entry["owner"]
		groups[owner].append(entry["id"])
	var expected_cards: Array = []
	for hero in party:
		var ids: Array = groups[hero].duplicate()
		ids.sort()
		groups[hero] = ids
	# Reset oracle rng
	var orng := _rng(SEED + 9000)
	for hero in party:
		var ids: Array = groups[hero]
		var idx: int = orng.randi_range(0, ids.size() - 1)
		var chosen: String = ids[idx]
		var price := 0
		for entry in peddler_cards:
			if entry["id"] == chosen:
				price = entry["price"]
		expected_cards.append({"id": chosen, "owner": hero, "price": price})
	_check(cards == expected_cards, "peddler matches per-hero sorted oracle")
	_check(rng2.state == orng.state, "peddler uses three draws and leaves matching RNG state")
	# Reversed input equivalent.
	var reversed := peddler_cards.duplicate(true)
	reversed.reverse()
	var rng3 := _rng(SEED + 9000)
	var result3 := RunShopStockOffers.generate_peddler_cards(rng3, party, reversed)
	_check(result3 == result2, "peddler reversed input produces identical output")
	# One candidate per member succeeds.
	var minimal := [
		{"id": "warden_brace", "owner": "warden", "price": 40},
		{"id": "seamstress_mend", "owner": "seamstress", "price": 45},
		{"id": "tinker_tune_up", "owner": "tinker", "price": 35},
	]
	var rmin := RunShopStockOffers.generate_peddler_cards(_rng(SEED + 9001), party, minimal)
	_check(rmin.get("ok", false) and rmin.get("cards", []).size() == 3, "peddler succeeds with one candidate per hero")
	# Invalid: missing member stock.
	var no_warden := [
		{"id": "seamstress_mend", "owner": "seamstress", "price": 45},
		{"id": "tinker_tune_up", "owner": "tinker", "price": 35},
	]
	var rngw := _rng(SEED + 9002)
	var before_state := rngw.state
	var resw := RunShopStockOffers.generate_peddler_cards(rngw, party, no_warden)
	_check(not resw.get("ok", true) and resw.get("cards", []).is_empty(), "peddler rejects missing hero stock")
	_check(rngw.state == before_state, "peddler missing stock preserves RNG")
	# Invalid party.
	var rngp := _rng(SEED + 9003)
	var beforep := rngp.state
	var resp := RunShopStockOffers.generate_peddler_cards(rngp, [party[0], party[0], party[2]], peddler_cards)
	_check(not resp.get("ok", true), "peddler rejects duplicate party")
	_check(rngp.state == beforep, "peddler duplicate party preserves RNG")
	# Wrong owner.
	var wrong_owner_pool := peddler_cards.duplicate(true)
	wrong_owner_pool[0] = {"id": "warden_brace", "owner": "seamstress", "price": 40}
	var rnwo := _rng(SEED + 9004)
	var beforewo := rnwo.state
	var reswo := RunShopStockOffers.generate_peddler_cards(rnwo, party, wrong_owner_pool)
	_check(not reswo.get("ok", true), "peddler rejects wrong owner")
	_check(rnwo.state == beforewo, "peddler wrong owner preserves RNG")
	# Pool upgrade candidate.
	var upgrade_pool := peddler_cards.duplicate(true)
	upgrade_pool.append({"id": "warden_hold_the_line_plus", "owner": "warden", "price": 55})
	var rnup := _rng(SEED + 9005)
	var beforeup := rnup.state
	var resup := RunShopStockOffers.generate_peddler_cards(rnup, party, upgrade_pool)
	_check(not resup.get("ok", true), "peddler rejects pool upgrade candidate")
	_check(rnup.state == beforeup, "peddler pool upgrade preserves RNG")
	# Negative price.
	var neg_pool := peddler_cards.duplicate(true)
	neg_pool[0] = {"id": "warden_brace", "owner": "warden", "price": -1}
	var rnneg := _rng(SEED + 9006)
	var beforeneg := rnneg.state
	var resneg := RunShopStockOffers.generate_peddler_cards(rnneg, party, neg_pool)
	_check(not resneg.get("ok", true), "peddler rejects negative price")
	_check(rnneg.state == beforeneg, "peddler negative price preserves RNG")
	# Fractional price.
	var frac_pool := peddler_cards.duplicate(true)
	frac_pool[0] = {"id": "warden_brace", "owner": "warden", "price": 12.5}
	var rnfrac := _rng(SEED + 9007)
	var beforefrac := rnfrac.state
	var resfrac := RunShopStockOffers.generate_peddler_cards(rnfrac, party, frac_pool)
	_check(not resfrac.get("ok", true), "peddler rejects fractional price")
	_check(rnfrac.state == beforefrac, "peddler fractional price preserves RNG")
	# Unknown candidate.
	var unk_pool := peddler_cards.duplicate(true)
	unk_pool[0] = {"id": "__unknown_card__", "owner": "warden", "price": 40}
	var rnunk := _rng(SEED + 9008)
	var beforeunk := rnunk.state
	var resunk := RunShopStockOffers.generate_peddler_cards(rnunk, party, unk_pool)
	_check(not resunk.get("ok", true), "peddler rejects unknown candidate")
	_check(rnunk.state == beforeunk, "peddler unknown candidate preserves RNG")
	# Duplicate candidate.
	var dup_pool := peddler_cards.duplicate(true)
	dup_pool[1] = {"id": "warden_brace", "owner": "warden", "price": 55}
	var rndup := _rng(SEED + 9009)
	var beforedup := rndup.state
	var resdup := RunShopStockOffers.generate_peddler_cards(rndup, party, dup_pool)
	_check(not resdup.get("ok", true), "peddler rejects duplicate candidate")
	_check(rndup.state == beforedup, "peddler duplicate candidate preserves RNG")
	# Inputs unchanged.
	_check(peddler_cards.size() == 6, "peddler leaves candidate input unchanged")


## Peddler v3-3: one priced card per party hero plus one priced patch.
## Uses real initial_offers.json patch IDs (stitched_badge, spare_spool, quilted_coat = 100g).
func _test_peddler_stock(party: Array[String], deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var card_pool := _card_pool(catalog, party, authored)
	# Use the three real patch IDs from initial_offers.json at their authored 100g price.
	var real_patches: Array = [
		{"id": "stitched_badge", "price": 100},
		{"id": "spare_spool", "price": 100},
		{"id": "quilted_coat", "price": 100},
	]
	var owned_patches: Array[String] = []

	# AC1: valid three-hero party, real priced candidates, at least one patch.
	var rng := _rng(SEED + 10000)
	var result := RunShopStockOffers.generate_peddler_stock(rng, party, card_pool, real_patches, owned_patches)
	_check(result.get("ok", false), "peddler stock generates with valid inputs")
	var cards: Array = result.get("cards", [])
	var patches: Array = result.get("patches", [])
	_check(cards.size() == 3, "peddler stock returns exactly three cards")
	_check(patches.size() == 1, "peddler stock returns exactly one patch")
	# Every offered card must be from the candidate pool, have correct owner and price.
	for offer in cards:
		var card_id: String = offer.get("id", "")
		_check(_pool_has_id(card_pool, card_id), "offered card is from candidate pool: " + card_id)
		var expected_owner: String = ""
		var all_catalogs: Array = RunShopStockOffers._peddler_catalogs()
		var found_def := RunShopStockOffers._find_card_definition(card_id, all_catalogs)
		if not found_def.is_empty():
			expected_owner = found_def["def"].get("owner", "")
		_check(offer.get("owner") == expected_owner, "offer uses correct catalog owner for " + card_id)
		_check(party.has(offer.get("owner")), "offered card belongs to the party: " + card_id)
		_check(offer.get("price") == _pool_price(card_pool, card_id), "offer keeps the supplied price: " + card_id)
	# One card per hero in party order.
	for i in range(3):
		_check(cards[i].get("owner") == party[i], "card " + str(i) + " owner matches party order: " + party[i])
	# Patch must be from real_patches and keep its price.
	var patch_offer: Dictionary = patches[0]
	_check(_pool_has_id(real_patches, patch_offer.get("id", "")), "offered patch is from candidate pool")
	_check(patch_offer.get("price") == _pool_price(real_patches, patch_offer.get("id", "")), "patch keeps supplied price")

	# AC2: seeded replay and exact RNG state match independent four-draw oracle.
	# V3 peddler stock test
	var v3_party: Array[String] = ["warden", "lantern_monk", "rag_duelist"]
	var v3_peddler_cards: Array = [
		{"id": "warden_brace", "owner": "warden", "price": 40},
		{"id": "warden_hold_the_line", "owner": "warden", "price": 55},
		{"id": "lantern_monk_wick_flicker", "owner": "lantern_monk", "price": 50},
		{"id": "lantern_monk_moth_lure", "owner": "lantern_monk", "price": 50},
		{"id": "rag_duelist_needle_prick", "owner": "rag_duelist", "price": 50},
		{"id": "rag_duelist_needle_lunge", "owner": "rag_duelist", "price": 50},
	]
	var v3_rng := _rng(SEED + 10500)
	var v3_oracle_rng := _rng(SEED + 10500)
	var v3_res := RunShopStockOffers.generate_peddler_stock(v3_rng, v3_party, v3_peddler_cards, real_patches, owned_patches)
	_check(v3_res.get("ok", false), "peddler stock generates with mixed v3 party 1")
	var expected_v3_stock := _peddler_stock_oracle(catalog, v3_party, v3_peddler_cards, real_patches, owned_patches, v3_oracle_rng)
	_check(v3_res.get("cards", []) == expected_v3_stock.get("cards", []), "v3 peddler stock cards match oracle")
	_check(v3_res.get("patches", []) == expected_v3_stock.get("patches", []), "v3 peddler stock patches match oracle")
	_check(v3_rng.state == v3_oracle_rng.state, "v3 peddler stock RNG state matches oracle")

	var v3_rng_b := _rng(SEED + 10500)
	var v3_res_b := RunShopStockOffers.generate_peddler_stock(v3_rng_b, v3_party, v3_peddler_cards, real_patches, owned_patches)
	_check(v3_res_b.get("ok", false), "v3 seeded replay gives valid result")
	_check(v3_res_b.get("cards", []) == v3_res.get("cards", []), "v3 seeded replay gives identical cards")
	_check(v3_res_b.get("patches", []) == v3_res.get("patches", []), "v3 seeded replay gives identical patches")
	_check(v3_rng_b.state == v3_rng.state, "v3 seeded replay matches post-generation RNG state")
	
	for offer in v3_res.get("cards", []):
		var card_id: String = offer.get("id", "")
		_check(_pool_has_id(v3_peddler_cards, card_id), "offered card is from candidate pool: " + card_id)
		var expected_owner: String = ""
		var all_catalogs: Array = RunShopStockOffers._peddler_catalogs()
		var found_def := RunShopStockOffers._find_card_definition(card_id, all_catalogs)
		if not found_def.is_empty():
			expected_owner = found_def["def"].get("owner", "")
		_check(offer.get("owner") == expected_owner, "offer uses correct catalog owner for " + card_id)
		_check(offer.get("price") == _pool_price(v3_peddler_cards, card_id), "offer keeps the supplied price: " + card_id)

	# V3 peddler stock test 2 (Scarecrow / Yarn Ranger)
	var v3_party_2: Array[String] = ["seamstress", "scarecrow", "yarn_ranger"]
	var v3_peddler_cards_2: Array = [
		{"id": "seamstress_mend", "owner": "seamstress", "price": 45},
		{"id": "seamstress_darning", "owner": "seamstress", "price": 55},
		{"id": "scarecrow_pitchfork_prick", "owner": "scarecrow", "price": 50},
		{"id": "scarecrow_crow_peck", "owner": "scarecrow", "price": 50},
		{"id": "yarn_ranger_needle_arrow", "owner": "yarn_ranger", "price": 50},
		{"id": "yarn_ranger_tangle_bolas", "owner": "yarn_ranger", "price": 50},
	]
	var v3_rng2 := _rng(SEED + 10501)
	var v3_oracle_rng2 := _rng(SEED + 10501)
	var v3_res2 := RunShopStockOffers.generate_peddler_stock(v3_rng2, v3_party_2, v3_peddler_cards_2, real_patches, owned_patches)
	_check(v3_res2.get("ok", false), "peddler stock generates with mixed v3 party 2")
	var expected_v3_stock2 := _peddler_stock_oracle(catalog, v3_party_2, v3_peddler_cards_2, real_patches, owned_patches, v3_oracle_rng2)
	_check(v3_res2.get("cards", []) == expected_v3_stock2.get("cards", []), "v3 peddler stock cards 2 match oracle")
	_check(v3_res2.get("patches", []) == expected_v3_stock2.get("patches", []), "v3 peddler stock patches 2 match oracle")
	_check(v3_rng2.state == v3_oracle_rng2.state, "v3 peddler stock 2 RNG state matches oracle")

	var v3_rng2_b := _rng(SEED + 10501)
	var v3_res2_b := RunShopStockOffers.generate_peddler_stock(v3_rng2_b, v3_party_2, v3_peddler_cards_2, real_patches, owned_patches)
	_check(v3_res2_b.get("cards", []) == v3_res2.get("cards", []), "v3 seeded replay 2 gives identical cards")
	_check(v3_res2_b.get("patches", []) == v3_res2.get("patches", []), "v3 seeded replay 2 gives identical patches")
	
	for offer in v3_res2.get("cards", []):
		var card_id: String = offer.get("id", "")
		_check(_pool_has_id(v3_peddler_cards_2, card_id), "offered card is from candidate pool: " + card_id)
		var expected_owner: String = ""
		var all_catalogs: Array = RunShopStockOffers._peddler_catalogs()
		var found_def := RunShopStockOffers._find_card_definition(card_id, all_catalogs)
		if not found_def.is_empty():
			expected_owner = found_def["def"].get("owner", "")
		_check(offer.get("owner") == expected_owner, "offer uses correct catalog owner for " + card_id)
		_check(offer.get("price") == _pool_price(v3_peddler_cards_2, card_id), "offer keeps the supplied price: " + card_id)

	var v3_rng_owned := _rng(SEED + 10502)
	var v3_res_owned := RunShopStockOffers.generate_peddler_stock(v3_rng_owned, v3_party_2, v3_peddler_cards_2, real_patches, ["stitched_badge", "spare_spool", "quilted_coat"])
	_check(v3_res_owned.get("ok", false), "v3 peddler stock generates when all patches owned")
	_check(v3_res_owned.get("patches", []).size() == 1, "v3 peddler stock offers one patch from owned fallback")
	var v3_offered_patch_id: String = v3_res_owned["patches"][0]["id"]
	_check(["stitched_badge", "spare_spool", "quilted_coat"].has(v3_offered_patch_id), "v3 offered patch is from owned fallback pool")

	var v3_stock_reject_plus = v3_peddler_cards.duplicate(true)
	v3_stock_reject_plus.append({"id": "lantern_monk_wick_flicker_plus", "owner": "lantern_monk", "price": 50})
	_reject_peddler_stock("v3 peddler stock plus-only candidate", _rng(SEED), v3_party, v3_stock_reject_plus, real_patches, owned_patches)

	var v3_stock_reject_unk = v3_peddler_cards.duplicate(true)
	v3_stock_reject_unk.append({"id": "unknown_v3_card", "owner": "lantern_monk", "price": 50})
	_reject_peddler_stock("v3 peddler stock unknown card", _rng(SEED), v3_party, v3_stock_reject_unk, real_patches, owned_patches)
	
	# The same valid out-of-party record is ignored, not rejected, by the 3+1
	# stock sampler: validation still happens, selection only keeps the party.
	var v3_stock_out_of_party: Array = v3_peddler_cards.duplicate(true)
	v3_stock_out_of_party[2] = {"id": "scarecrow_pitchfork_prick", "owner": "scarecrow", "price": 50}
	var v3_oop_stock_rng := _rng(SEED + 10600)
	var v3_oop_stock_oracle_rng := _rng(SEED + 10600)
	var v3_oop_stock := RunShopStockOffers.generate_peddler_stock(v3_oop_stock_rng, v3_party,
		v3_stock_out_of_party, real_patches, owned_patches)
	_check(v3_oop_stock.get("ok", false),
		"peddler stock accepts a valid authored out-of-party card")
	var v3_oop_stock_cards: Array = v3_oop_stock.get("cards", [])
	_check(v3_oop_stock_cards.size() == 3 and v3_oop_stock.get("patches", []).size() == 1,
		"out-of-party stock still offers three cards and one patch")
	for i in range(mini(v3_oop_stock_cards.size(), 3)):
		_check(v3_oop_stock_cards[i].get("owner") == v3_party[i]
			and v3_oop_stock_cards[i].get("id") != "scarecrow_pitchfork_prick",
			"out-of-party stock keeps party order and never offers the outsider")
	_check(v3_oop_stock_cards == _peddler_stock_oracle(catalog, v3_party,
		v3_stock_out_of_party, real_patches, owned_patches, v3_oop_stock_oracle_rng).get("cards", [])
		and v3_oop_stock_rng.state == v3_oop_stock_oracle_rng.state,
		"out-of-party stock keeps the four-draw oracle and RNG state")

	var v3_stock_reject_spoofed = v3_peddler_cards.duplicate(true)
	v3_stock_reject_spoofed[2] = {"id": "lantern_monk_wick_flicker", "owner": "rag_duelist", "price": 50}
	_reject_peddler_stock("v3 peddler stock spoofed owner", _rng(SEED), v3_party, v3_stock_reject_spoofed, real_patches, owned_patches)

	var v3_stock_reject_dup = v3_peddler_cards.duplicate(true)
	v3_stock_reject_dup[3] = {"id": "lantern_monk_wick_flicker", "owner": "lantern_monk", "price": 50}
	_reject_peddler_stock("v3 peddler stock duplicate", _rng(SEED), v3_party, v3_stock_reject_dup, real_patches, owned_patches)

	var v3_stock_reject_missing = [v3_peddler_cards[0], v3_peddler_cards[2]]
	_reject_peddler_stock("v3 peddler stock missing party-owner card", _rng(SEED), v3_party, v3_stock_reject_missing, real_patches, owned_patches)

	var v3_stock_reject_malformed = v3_peddler_cards.duplicate(true)
	v3_stock_reject_malformed[0] = {"id": "warden_brace", "owner": "warden", "price": -10}
	_reject_peddler_stock("v3 peddler stock malformed price", _rng(SEED), v3_party, v3_stock_reject_malformed, real_patches, owned_patches)

	var v3_stock_reject_patch = real_patches.duplicate(true)
	v3_stock_reject_patch[0] = {"id": "stitched_badge", "price": -5}
	_reject_peddler_stock("v3 peddler stock invalid patch", _rng(SEED), v3_party, v3_peddler_cards, v3_stock_reject_patch, owned_patches)

	var oracle_rng := _rng(SEED + 10000)
	var rng_a := _rng(SEED + 10000)
	var rng_b := _rng(SEED + 10000)
	var expected := _peddler_stock_oracle(catalog, party, card_pool, real_patches, owned_patches, oracle_rng)
	var result_a := RunShopStockOffers.generate_peddler_stock(rng_a, party, card_pool, real_patches, owned_patches)
	_check(result_a.get("ok", false), "first stock generates")
	_check(result_a == expected, "stock matches independent four-draw sorted-ID oracle")
	_check(rng_a.state == oracle_rng.state, "four draws leave matching RNG state")
	# Reverse candidate orders and confirm identical outputs.
	var reversed_cards := card_pool.duplicate(true)
	reversed_cards.reverse()
	var reversed_patches := real_patches.duplicate(true)
	reversed_patches.reverse()
	var result_b := RunShopStockOffers.generate_peddler_stock(rng_b, party, reversed_cards, reversed_patches, owned_patches)
	_check(result_b == result_a, "reordered inputs produce identical stock")
	_check(rng_b.state == rng_a.state, "reordered inputs leave identical RNG state")

	# AC2: unowned-patch preference, then owned fallback.
	# First test with unowned patches available (already tested above).
	# Now test with all patches owned - should fall back to owned.
	var all_owned := ["stitched_badge", "spare_spool", "quilted_coat"]
	var rng_owned := _rng(SEED + 10001)
	var result_owned := RunShopStockOffers.generate_peddler_stock(rng_owned, party, card_pool, real_patches, all_owned)
	_check(result_owned.get("ok", false), "peddler stock generates when all patches owned")
	_check(result_owned.get("patches", []).size() == 1, "one patch offered from owned fallback")
	# The patch should be one of the owned ones.
	var offered_patch_id: String = result_owned["patches"][0]["id"]
	_check(all_owned.has(offered_patch_id), "offered patch is from owned fallback pool")

	# AC3: empty patch pool fails closed, no RNG spent.
	var rng_empty := _rng(SEED + 10002)
	var state_before := rng_empty.state
	var result_empty := RunShopStockOffers.generate_peddler_stock(rng_empty, party, card_pool, [], owned_patches)
	_check(not result_empty.get("ok", true), "empty patch pool fails closed")
	_check(result_empty.get("cards", []).is_empty() and result_empty.get("patches", []).is_empty(), "empty patch pool returns empty shape")
	_check(rng_empty.state == state_before, "empty patch pool preserves RNG")

	# AC3: duplicate patch IDs fail closed.
	var dup_patches := real_patches.duplicate(true)
	dup_patches.append({"id": "stitched_badge", "price": 100})
	var rng_dup := _rng(SEED + 10003)
	state_before = rng_dup.state
	var result_dup := RunShopStockOffers.generate_peddler_stock(rng_dup, party, card_pool, dup_patches, owned_patches)
	_check(not result_dup.get("ok", true), "duplicate patch IDs fail closed")
	_check(rng_dup.state == state_before, "duplicate patch IDs preserve RNG")

	# AC3: malformed patch price (negative) fails closed.
	var neg_patches := real_patches.duplicate(true)
	neg_patches[0] = {"id": "stitched_badge", "price": -1}
	var rng_neg := _rng(SEED + 10004)
	state_before = rng_neg.state
	var result_neg := RunShopStockOffers.generate_peddler_stock(rng_neg, party, card_pool, neg_patches, owned_patches)
	_check(not result_neg.get("ok", true), "negative patch price fails closed")
	_check(rng_neg.state == state_before, "negative patch price preserves RNG")

	# AC3: malformed patch price (fractional) fails closed.
	var frac_patches := real_patches.duplicate(true)
	frac_patches[0] = {"id": "stitched_badge", "price": 12.5}
	var rng_frac := _rng(SEED + 10005)
	state_before = rng_frac.state
	var result_frac := RunShopStockOffers.generate_peddler_stock(rng_frac, party, card_pool, frac_patches, owned_patches)
	_check(not result_frac.get("ok", true), "fractional patch price fails closed")
	_check(rng_frac.state == state_before, "fractional patch price preserves RNG")

	# AC3: malformed owned IDs (empty string) fails closed.
	var bad_owned := ["", "spare_spool"]
	var rng_bad_owned := _rng(SEED + 10006)
	state_before = rng_bad_owned.state
	var result_bad_owned := RunShopStockOffers.generate_peddler_stock(rng_bad_owned, party, card_pool, real_patches, bad_owned)
	_check(not result_bad_owned.get("ok", true), "malformed owned ID fails closed")
	_check(rng_bad_owned.state == state_before, "malformed owned ID preserves RNG")

	# AC3: duplicate party members fails closed.
	var dup_party := [party[0], party[0], party[2]]
	var rng_dup_party := _rng(SEED + 10007)
	state_before = rng_dup_party.state
	var result_dup_party := RunShopStockOffers.generate_peddler_stock(rng_dup_party, dup_party, card_pool, real_patches, owned_patches)
	_check(not result_dup_party.get("ok", true), "duplicate party fails closed")
	_check(rng_dup_party.state == state_before, "duplicate party preserves RNG")

	# AC3: insufficient per-hero card stock fails closed.
	# Build a card pool with only Warden cards.
	var warden_only := []
	for entry in card_pool:
		if entry.get("owner") == "warden":
			warden_only.append(entry)
	var rng_insuff := _rng(SEED + 10008)
	state_before = rng_insuff.state
	var result_insuff := RunShopStockOffers.generate_peddler_stock(rng_insuff, party, warden_only, real_patches, owned_patches)
	_check(not result_insuff.get("ok", true), "insufficient per-hero card stock fails closed")
	_check(rng_insuff.state == state_before, "insufficient card stock preserves RNG")

	# AC3: null/invalid inputs fail closed.
	_reject_peddler_stock("null RNG", null, party, card_pool, real_patches, owned_patches)
	_reject_peddler_stock("wrong-type RNG", RefCounted.new(), party, card_pool, real_patches, owned_patches)
	_reject_peddler_stock("nonarray party", _rng(), "warden", card_pool, real_patches, owned_patches)
	_reject_peddler_stock("nonarray card pool", _rng(), party, "cards", real_patches, owned_patches)
	_reject_peddler_stock("nonarray patch pool", _rng(), party, card_pool, "patches", owned_patches)
	_reject_peddler_stock("nonarray owned patches", _rng(), party, card_pool, real_patches, "owned")

	# Inputs unchanged.
	_check(card_pool == _card_pool(catalog, party, authored), "card pool unchanged")
	_check(real_patches.size() == 3, "patch pool unchanged")
	_check(owned_patches.is_empty(), "owned patches unchanged")


## V3-3: the shipped priced catalog now prices one base card for every one of
## the eight heroes, so both existing seeded samplers must accept that complete
## catalog for any authentic three-hero party while offering only its stock.
## Correctly authored other-hero records are skipped after validation; every
## malformed record, including an out-of-party one, still fails closed.
func _test_v3_peddler_party_stock(deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var candidates: Array = authored.get("cards", [])
	var patches: Array = []
	for entry in authored.get("trinkets", []):
		if entry is Dictionary and entry.get("id") is String:
			patches.append({"id": entry["id"], "price": _whole_price(entry.get("price"))})
	var catalogs := _all_party_catalogs()
	_check(candidates.size() > 0 and patches.size() >= 2,
		"the shipped v3 stock source carries priced cards and patches")
	if candidates.is_empty() or patches.size() < 2:
		return
	var candidates_before := candidates.duplicate(true)
	var patches_before := patches.duplicate(true)

	# AC1: the five appended base records, checked one by one against their
	# own authored pool catalogs; never a catalog total or a full ID list.
	for card_id in V3_PEDDLER_STOCK_SPECS:
		var spec: Dictionary = V3_PEDDLER_STOCK_SPECS[card_id]
		var matches: Array = candidates.filter(
			func(entry): return entry is Dictionary and entry.get("id") == card_id)
		_check(matches.size() == 1, "shipped v3 stock lists " + card_id + " exactly once")
		if matches.size() != 1:
			continue
		_check(matches[0].get("owner") == spec["owner"],
			card_id + ": shipped owner is " + str(spec["owner"]))
		_check(_whole_price(matches[0].get("price")) == int(spec["price"]),
			card_id + ": shipped quote is " + str(spec["price"]) + " gold")
		var definition: Dictionary = _catalog_definition(card_id, catalogs)
		_check(not definition.is_empty() and definition.get("id") == card_id
			and definition.get("owner") == spec["owner"]
			and definition.get("rarity") == spec["rarity"]
			and definition.get("reward_eligible") == true
			and not definition.has("upgrade_of")
			and not card_id.ends_with("_plus"),
			card_id + ": authentic reward-eligible authored base card")
		var upgrade_id: String = str(definition.get("upgrade_id", ""))
		_check(not upgrade_id.is_empty()
			and candidates.filter(
				func(entry): return entry is Dictionary and entry.get("id") == upgrade_id).is_empty(),
			card_id + ": authored upgrade exists but is never priced stock")

	# AC1: representative earlier card and patch quotes are unchanged.
	for card_id in ["warden_brace", "seamstress_mend", "tinker_pop_shot"]:
		var spec: Dictionary = EXISTING_SHOP_CARDS[card_id]
		var matches: Array = candidates.filter(
			func(entry): return entry is Dictionary and entry.get("id") == card_id)
		_check(matches.size() == 1 and matches[0].get("owner") == spec["owner"]
			and _whole_price(matches[0].get("price")) == int(spec["price"]),
			"earlier priced card keeps its owner and quote: " + card_id)
	for patch_id in EXISTING_SHOP_TRINKETS:
		var matches: Array = patches.filter(func(entry): return entry.get("id") == patch_id)
		_check(matches.size() == 1 and matches[0].get("price") == int(EXISTING_SHOP_TRINKETS[patch_id]),
			"earlier patch offer keeps its quote: " + patch_id)

	# AC1/AC2: the real full catalog feeds both Peddler 3+1 and legacy 5+2 for
	# a legacy party and for mixed/new v3 parties, in party order, deterministically.
	var parties: Array = [
		["warden", "seamstress", "tinker"],
		["warden", "lantern_monk", "rag_duelist"],
		["scarecrow", "yarn_ranger", "button_golem"],
		["tinker", "scarecrow", "button_golem"],
	]
	for index in range(parties.size()):
		var party_ids: Array[String] = []
		party_ids.assign(parties[index])
		var seed_value: int = SEED + 20000 + index
		var label: String = "full catalog party " + str(party_ids)

		var stock_rng := _rng(seed_value)
		var stock_oracle_rng := _rng(seed_value)
		var stock := RunShopStockOffers.generate_peddler_stock(stock_rng, party_ids,
			candidates, patches, [])
		var expected := _peddler_stock_oracle(catalog, party_ids, candidates, patches, [],
			stock_oracle_rng)
		_check(stock.get("ok", false), label + ": Peddler 3+1 stock generates")
		if not stock.get("ok", false):
			continue
		var cards: Array = stock.get("cards", [])
		var offered_patches: Array = stock.get("patches", [])
		_check(cards.size() == 3 and offered_patches.size() == 1,
			label + ": exactly three card offers and one patch")
		for position in range(mini(cards.size(), 3)):
			var offer: Dictionary = cards[position]
			var offer_id: String = str(offer.get("id", ""))
			_check(offer.get("owner") == party_ids[position],
				label + ": card " + str(position) + " follows party order")
			_check(_pool_has_id(candidates, offer_id),
				label + ": " + offer_id + " is an authored priced candidate")
			_check(offer.get("price") == _pool_price(candidates, offer_id),
				label + ": " + offer_id + " keeps its authored quote")
			_check(_catalog_definition(offer_id, catalogs).get("owner") == offer.get("owner"),
				label + ": catalog owner agrees for " + offer_id)
		var patch_id: String = str(offered_patches[0].get("id", ""))
		_check(_pool_has_id(patches, patch_id)
			and offered_patches[0].get("price") == _pool_price(patches, patch_id),
			label + ": offered patch is an authored priced patch")
		_check(cards == expected.get("cards", []) and offered_patches == expected.get("patches", []),
			label + ": full-catalog stock matches the independent oracle")
		_check(stock_rng.state == stock_oracle_rng.state,
			label + ": four draws leave the oracle RNG state")
		_check(RunShopStockOffers.generate_peddler_stock(_rng(seed_value), party_ids,
			_reversed(candidates), _reversed(patches), []) == stock,
			label + ": candidate order cannot change the stock")

		var in_party_cards: Array = candidates.filter(
			func(entry): return party_ids.has(entry.get("owner")))
		_check(in_party_cards.size() >= 3, label + ": the party itself has priced cards")
		_check(RunShopStockOffers.generate_peddler_stock(_rng(seed_value), party_ids,
			in_party_cards, patches, []) == stock,
			label + ": correctly authored other-hero records never change the stock")

		var peddler_rng := _rng(seed_value)
		var peddler_oracle_rng := _rng(seed_value)
		var peddler := RunShopStockOffers.generate_peddler_cards(peddler_rng, party_ids, candidates)
		_check(peddler.get("ok", false)
			and peddler.get("cards", []) == _peddler_cards_oracle(party_ids, candidates,
				peddler_oracle_rng)
			and peddler_rng.state == peddler_oracle_rng.state,
			label + ": Peddler card sampler matches the per-hero oracle over the full catalog")

		var shop_rng := _rng(seed_value)
		var shop_oracle_rng := _rng(seed_value)
		if in_party_cards.size() >= 5:
			var shop := RunShopStockOffers.generate(shop_rng, party_ids, candidates, patches, [])
			var shop_expected := _oracle(catalog, party_ids, candidates, patches, [], shop_oracle_rng)
			_check(shop.get("ok", false) and shop.get("cards", []).size() == 5
				and shop.get("trinkets", []).size() == 2,
				label + ": legacy 5+2 Shop stock generates over the full catalog")
			_check(shop.get("cards", []) == shop_expected["cards"]
				and shop.get("trinkets", []) == shop_expected["trinkets"]
				and shop_rng.state == shop_oracle_rng.state,
				label + ": legacy 5+2 stock matches the independent oracle")
			for offer in shop.get("cards", []):
				_check(party_ids.has(offer.get("owner"))
					and _pool_has_id(candidates, offer.get("id", "")),
					label + ": legacy offer " + str(offer.get("id", "")) + " is a priced party card")
			_check(RunShopStockOffers.generate(_rng(seed_value), party_ids, in_party_cards,
				patches, []) == shop,
				label + ": correctly authored other-hero records never change the legacy stock")
		else:
			# A pure new-hero party is priced with exactly one card per hero, so
			# the legacy five-card Shop still refuses without drawing anything:
			# the Peddler 3+1 stock above is the visit that serves this party.
			var short_state: int = shop_rng.state
			var short := RunShopStockOffers.generate(shop_rng, party_ids, candidates, patches, [])
			_check(not short.get("ok", true) and short.get("cards", []).is_empty()
				and short.get("trinkets", []).is_empty() and shop_rng.state == short_state,
				label + ": legacy 5+2 fails closed without five priced party cards")

	# AC3: with the three-plus priced cards each v3 hero now carries, a mixed
	# new-hero party can reach the legacy five-card Shop. The fail-closed path is
	# still exercised explicitly from a genuinely authored lean pool of one
	# priced card per party hero: no stock, no offers and no RNG draw.
	var lean_party: Array[String] = ["scarecrow", "yarn_ranger", "button_golem"]
	var lean_ids := ["scarecrow_re_stuff", "yarn_ranger_snare_net",
		"button_golem_pop_button"]
	var lean_cards: Array = candidates.filter(
		func(entry): return entry is Dictionary and lean_ids.has(entry.get("id")))
	var lean_rng := _rng(SEED + 21000)
	var lean_state: int = lean_rng.state
	var lean := RunShopStockOffers.generate(lean_rng, lean_party, lean_cards, patches, [])
	_check(lean_cards.size() == lean_ids.size()
		and not lean.get("ok", true) and lean.get("cards", []).is_empty()
		and lean.get("trinkets", []).is_empty() and lean_rng.state == lean_state,
		"legacy 5+2 still fails closed on three priced party cards without a draw")

	# AC2: a real RunPeddlerVisit opens from the sampled mixed-party 3+1 stock
	# and keeps one paid choice or a free Leave.
	var mixed_party: Array[String] = ["scarecrow", "yarn_ranger", "button_golem"]
	var mixed_stock := RunShopStockOffers.generate_peddler_stock(_rng(SEED + 20002),
		mixed_party, candidates, patches, [])
	_check(mixed_stock.get("ok", false), "mixed v3 party stock samples for the live visit")
	if mixed_stock.get("ok", false):
		_test_v3_peddler_visit(mixed_party, deck, mixed_stock)

	# AC3: every malformed record still fails closed, before any RNG draw and
	# without being silently filtered away just because its hero is absent.
	var party_ids: Array[String] = ["warden", "lantern_monk", "rag_duelist"]
	var malformed := {
		"unknown new ID": _with_appended(candidates,
			{"id": "__unknown_v3_card__", "owner": "lantern_monk", "price": 50}),
		"spoofed out-of-party owner": _with_appended(candidates,
			{"id": "button_golem_pop_button", "owner": "warden", "price": 50}),
		"duplicated out-of-party ID": _with_appended(candidates,
			{"id": "scarecrow_re_stuff", "owner": "scarecrow", "price": 65}),
		"negative new quote": _with_appended(candidates,
			{"id": "yarn_ranger_unspool", "owner": "yarn_ranger", "price": -65}),
		"fractional new quote": _with_appended(candidates,
			{"id": "button_golem_pop_button", "owner": "button_golem", "price": 50.5}),
		"pool upgrade record": _with_appended(candidates,
			{"id": "button_golem_pop_button_plus", "owner": "button_golem", "price": 50}),
	}
	for label in malformed:
		_reject_peddler_stock("full catalog " + label, _rng(SEED + 22000), party_ids,
			malformed[label], patches, [])
		_reject_peddler_cards("full catalog " + label, _rng(SEED + 22000), party_ids,
			malformed[label])
		_reject("full catalog " + label, _rng(SEED + 22000), party_ids,
			malformed[label], patches, [])

	# AC3: malformed parties and a party hero with no eligible priced card.
	var malformed_parties := {
		"two-hero party": ["warden", "lantern_monk"],
		"duplicate hero": ["warden", "warden", "rag_duelist"],
		"unknown hero": ["warden", "lantern_monk", "__unknown_hero__"],
	}
	for label in malformed_parties:
		_reject_peddler_stock("full catalog " + label, _rng(SEED + 23000),
			malformed_parties[label], candidates, patches, [])
		_reject_peddler_cards("full catalog " + label, _rng(SEED + 23000),
			malformed_parties[label], candidates)
		_reject("full catalog " + label, _rng(SEED + 23000), malformed_parties[label],
			candidates, patches, [])
	var without_ranger: Array = candidates.filter(
		func(entry): return entry is Dictionary and entry.get("owner") != "yarn_ranger")
	_check(without_ranger.any(func(entry): return entry.get("owner") == "scarecrow")
		and without_ranger.any(func(entry): return entry.get("owner") == "button_golem"),
		"the missing-card fixture still prices the party's other two heroes")
	_reject_peddler_stock("full catalog hero without priced card", _rng(SEED + 23500),
		["scarecrow", "yarn_ranger", "button_golem"], without_ranger, patches, [])
	_reject_peddler_cards("full catalog hero without priced card", _rng(SEED + 23500),
		["scarecrow", "yarn_ranger", "button_golem"], without_ranger)

	_check(candidates == candidates_before and patches == patches_before,
		"the shipped candidate arrays survive every sampler unchanged")


## AC1/AC2: the shipped Yarn Ranger Peddler stock. Each base is checked against
## its own authored pool catalog and the shipped JSON by ID (never a catalog
## total or list order), then an authentic three-hero party including the Yarn
## Ranger samples genuine 3+1 visits across a bounded fixed seed sweep: every
## shipped Yarn Ranger base must be reachable, each visit holds exactly one Yarn
## Ranger card, and every visit matches the independent four-draw oracle.
func _test_yarn_ranger_peddler_stock(deck: Array[String], catalog: StarterCards) -> void:
	var authored := _authored_shop_offers()
	var candidates: Array = authored.get("cards", [])
	var patches: Array = []
	for entry in authored.get("trinkets", []):
		if entry is Dictionary and entry.get("id") is String:
			patches.append({"id": entry["id"], "price": _whole_price(entry.get("price"))})
	var yarn_pool := YarnRangerPoolCards.new()
	var candidates_before := candidates.duplicate(true)
	var patches_before := patches.duplicate(true)
	_check(candidates.size() > 0 and patches.size() >= 2,
		"the shipped stock source carries priced cards and patches for the Yarn Ranger check")
	if candidates.is_empty() or patches.size() < 2:
		return

	# AC1: per-ID facts only. Every shipped Yarn Ranger base is listed exactly
	# once at its authored quote and resolves to its genuine unupgraded pool card.
	for card_id in YARN_RANGER_PEDDLER_SPECS:
		var spec: Dictionary = YARN_RANGER_PEDDLER_SPECS[card_id]
		var upgrade_id: String = card_id + "_plus"
		var matches: Array = candidates.filter(
			func(entry): return entry is Dictionary and entry.get("id") == card_id)
		_check(matches.size() == 1,
			"shipped Yarn Ranger stock lists " + card_id + " exactly once")
		if matches.size() == 1:
			_check(matches[0].get("owner") == spec["owner"]
				and _whole_price(matches[0].get("price")) == int(spec["price"]),
				card_id + ": shipped Yarn Ranger owner and exact authored quote")
			_check(matches[0].size() == 3,
				card_id + ": shipped record carries only id, owner and price")
		_check(not _pool_has_id(candidates, upgrade_id),
			card_id + ": the + upgrade is absent from the shipped candidate list")

		_check(yarn_pool.get_base_ids().has(card_id)
			and not catalog.has_card(card_id),
			card_id + ": genuine Yarn Ranger pool base, not a starter card")
		var base: Dictionary = yarn_pool.get_definition(card_id)
		_check(base.get("id") == card_id and base.get("owner") == spec["owner"]
			and base.get("rarity") == spec["rarity"]
			and base.get("cost") == spec["cost"]
			and base.get("from_positions") == spec["from"]
			and base.get("target_kind") == spec["target"]
			and base.get("to_positions") == spec["to"]
			and base.get("effects") == spec["effects"]
			and base.get("reward_eligible") == true
			and base.get("starting_copies") == 0
			and base.get("upgrade_id") == upgrade_id
			and not base.has("upgrade_of"),
			card_id + ": authentic unupgraded uncommon base definition")
		_check(base.get("illustration_path") == "res://assets/paper/cards/" + card_id + ".png",
			card_id + ": keeps its pre-existing card art path")
		var plus: Dictionary = yarn_pool.get_definition(upgrade_id)
		_check(plus.get("id") == upgrade_id and plus.get("owner") == spec["owner"]
			and plus.get("cost") == spec["plus_cost"]
			and plus.get("from_positions") == spec["from"]
			and plus.get("target_kind") == spec["target"]
			and plus.get("to_positions") == spec["to"]
			and plus.get("effects") == spec["plus_effects"]
			and plus.get("upgrade_of") == card_id
			and plus.get("reward_eligible") == false
			and plus.get("starting_copies") == 0,
			card_id + ": the authored + stays Rest-only")

	# AC2: a bounded fixed seed sweep over one authentic three-hero party that
	# includes the Yarn Ranger. Every visit is checked against the existing
	# independent seeded oracle, which performs exactly three per-hero draws in
	# party order plus one patch draw.
	var party: Array[String] = ["scarecrow", "yarn_ranger", "button_golem"]
	var ranger_seat: int = party.find("yarn_ranger")
	_check(ranger_seat >= 0, "the authentic sweep party includes the Yarn Ranger")
	var reached := {}
	var sweep: int = 128
	var sampled_visits := 0
	for offset in range(sweep):
		var seed_value: int = SEED + 30000 + offset
		var rng := _rng(seed_value)
		var oracle_rng := _rng(seed_value)
		var stock := RunShopStockOffers.generate_peddler_stock(rng, party, candidates,
			patches, [])
		var expected := _peddler_stock_oracle(catalog, party, candidates, patches, [],
			oracle_rng)
		_check(stock.get("ok", false),
			"Yarn Ranger sweep seed " + str(seed_value) + ": Peddler 3+1 stock generates")
		if not stock.get("ok", false):
			continue
		sampled_visits += 1
		var cards: Array = stock.get("cards", [])
		var offered_patches: Array = stock.get("patches", [])
		_check(cards.size() == 3 and offered_patches.size() == 1,
			"Yarn Ranger sweep seed " + str(seed_value) + ": three cards and one patch")
		_check(cards == expected.get("cards", [])
			and offered_patches == expected.get("patches", []),
			"Yarn Ranger sweep seed " + str(seed_value) + ": stock matches the independent oracle")
		_check(rng.state == oracle_rng.state,
			"Yarn Ranger sweep seed " + str(seed_value) + ": same four RNG draws")
		var ranger_cards := 0
		for position in range(cards.size()):
			var offer: Dictionary = cards[position]
			_check(offer.get("owner") == party[position],
				"Yarn Ranger sweep seed " + str(seed_value) + ": offer " + str(position)
					+ " follows party order")
			if offer.get("owner") != "yarn_ranger":
				continue
			ranger_cards += 1
			_check(position == ranger_seat,
				"Yarn Ranger sweep seed " + str(seed_value)
					+ ": the Yarn Ranger card fills its own party seat")
			var ranger_id: String = str(offer.get("id", ""))
			# ID-presence, never a fixed card list: any authored, priced Yarn
			# Ranger base may reach the seat, and nothing else may.
			_check(_pool_has_id(candidates, ranger_id)
				and _catalog_definition(ranger_id, _all_party_catalogs())
					.get("owner") == "yarn_ranger",
				"Yarn Ranger sweep seed " + str(seed_value)
					+ ": the seat offers an authored priced Yarn Ranger base")
			_check(int(offer.get("price")) == _pool_price(candidates, ranger_id)
				and int(offer.get("price")) > 0,
				"Yarn Ranger sweep seed " + str(seed_value)
					+ ": the offered base keeps its authored quote")
			reached[ranger_id] = true
		_check(ranger_cards == 1,
			"Yarn Ranger sweep seed " + str(seed_value)
				+ ": exactly one Yarn Ranger card, never two")
	_check(sampled_visits == sweep,
		"every bounded Yarn Ranger sweep seed samples genuine stock")
	_check(reached.has("yarn_ranger_snare_net"),
		"the bounded sweep reaches the shipped Snare Net offer")
	_check(reached.has("yarn_ranger_unspool"),
		"the bounded sweep reaches the shipped Unspool offer")
	_check(reached.has("yarn_ranger_knit_shield"),
		"the bounded sweep reaches the shipped Knit Shield offer")
	_check(candidates == candidates_before and patches == patches_before,
		"the shipped candidate arrays survive the Yarn Ranger sweep unchanged")


## AC2: one real Peddler visit from truly sampled mixed-party stock.
func _test_v3_peddler_visit(party: Array[String], deck: Array[String],
		stock: Dictionary) -> void:
	var node_id := "peddler_v3_stock"
	var buying := RunPeddlerVisit.new(node_id, party, deck, [], 500, stock)
	_check(buying.is_open(), "mixed v3 stock opens a real Peddler visit")
	if not buying.is_open():
		return
	var open := buying.read_state()
	var card_offer: Dictionary = open["stock"]["cards"][1]
	var bought := buying.choose_purchase(node_id, open["state"], open["stock"],
		"card", card_offer["id"])
	_check(bought.get("ok", false) and bought.get("kind") == "card"
		and bought.get("id") == card_offer["id"] and bought.get("price") == card_offer["price"],
		"mixed v3 visit buys one priced card at its authored quote")
	_check(bought.get("state", {}).get("gold") == 500 - int(card_offer["price"])
		and bought.get("state", {}).get("deck") == deck + [card_offer["id"]],
		"mixed v3 purchase appends only that card and charges it once")
	var spent := buying.read_state()
	var second := buying.choose_purchase(node_id, spent["state"], spent["stock"],
		"card", spent["stock"]["cards"][0]["id"])
	_check(not second.get("ok", true) and buying.read_state() == spent,
		"mixed v3 visit allows no second purchase")
	_check(buying.is_consumed(), "the paid mixed v3 visit is finished")

	var patch_visit := RunPeddlerVisit.new(node_id + "_patch", party, deck, [], 300, stock)
	var patch_open := patch_visit.read_state()
	var patch_offer: Dictionary = patch_open["stock"]["trinkets"][0]
	var patch_bought := patch_visit.choose_purchase(node_id + "_patch", patch_open["state"],
		patch_open["stock"], "trinket", patch_offer["id"])
	_check(patch_bought.get("ok", false) and patch_bought.get("price") == patch_offer["price"]
		and patch_bought.get("state", {}).get("gold") == 300 - int(patch_offer["price"])
		and patch_bought.get("state", {}).get("trinkets") == [patch_offer["id"]],
		"mixed v3 visit buys the one patch at its authored quote")
	_check(not patch_visit.choose_purchase(node_id + "_patch",
		patch_bought.get("state", {}), patch_bought.get("stock", {}), "trinket",
		patch_offer["id"]).get("ok", true),
		"the paid patch cannot be bought twice")

	var leaving := RunPeddlerVisit.new(node_id + "_leave", party, deck, [], 500, stock)
	var leave_open := leaving.read_state()
	var left := leaving.leave(node_id + "_leave", leave_open["state"], leave_open["stock"])
	_check(left.get("ok", false) and left.get("decision") == "leave"
		and left.get("state", {}).get("gold") == 500
		and left.get("state", {}).get("deck") == deck,
		"mixed v3 visit can Leave free of charge")
	_check(leaving.is_consumed() and not leaving.choose_purchase(node_id + "_leave",
		leave_open["state"], leave_open["stock"], "card",
		leave_open["stock"]["cards"][0]["id"]).get("ok", true),
		"mixed v3 Leave ends the visit without a purchase")


## Independent sorted-pool oracle for Peddler stock (3 hero cards + 1 patch).
func _peddler_cards_oracle(party: Array[String], card_pool: Array, rng: RandomNumberGenerator) -> Array:
	var groups := {}
	for hero in party:
		groups[hero] = []
	var card_prices := {}
	for entry in card_pool:
		var card_id: String = entry["id"]
		var owner: String = entry["owner"]
		var price: int = entry["price"]
		if party.has(owner):
			card_prices[card_id] = price
			groups[owner].append(card_id)
	var expected_cards: Array = []
	for hero in party:
		var ids: Array = groups[hero]
		ids.sort()
		var index: int = rng.randi_range(0, ids.size() - 1)
		var chosen: String = ids[index]
		expected_cards.append({"id": chosen, "owner": hero, "price": card_prices[chosen]})
	return expected_cards

func _reject_peddler_cards(label: String, rng_input: Variant, party_input: Variant, cards_input: Variant) -> void:
	var state_before: int = rng_input.state if rng_input is RandomNumberGenerator else -1
	var party_before = party_input.duplicate(true) if party_input is Array else party_input
	var cards_before = cards_input.duplicate(true) if cards_input is Array else cards_input
	var global_expected := -1
	if not (rng_input is RandomNumberGenerator):
		seed(48213)
		global_expected = randi()
		seed(48213)
	var result: Dictionary = RunShopStockOffers.generate_peddler_cards(rng_input, party_input, cards_input)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("cards", ["bad"]).is_empty(), label + ": no offers published")
	if rng_input is RandomNumberGenerator:
		_check(rng_input.state == state_before, label + ": no RNG consumed")
	if global_expected >= 0:
		_check(randi() == global_expected, label + ": global RNG untouched")
	_check(party_input == party_before, label + ": party unchanged")
	_check(cards_input == cards_before, label + ": card candidates unchanged")

func _peddler_stock_oracle(catalog: StarterCards, party: Array[String], card_pool: Array,
		patch_pool: Array, owned: Array[String], rng: RandomNumberGenerator) -> Dictionary:

	# Build eligible card IDs per hero.
	var card_prices := {}
	var eligible_by_hero := {}
	for hero_id in party:
		eligible_by_hero[hero_id] = []
	for entry in card_pool:
		var card_id: String = entry["id"]
		var owner: String = entry["owner"]
		var price: int = entry["price"]
		if party.has(owner):
			card_prices[card_id] = price
			eligible_by_hero[owner].append(card_id)
	for hero_id in party:
		eligible_by_hero[hero_id].sort()

	# Build patch pools.
	var patch_prices := {}
	var eligible_patches: Array[String] = []
	var owned_patches: Array[String] = []
	for entry in patch_pool:
		var patch_id: String = entry["id"]
		var price: int = entry["price"]
		patch_prices[patch_id] = price
		if owned.has(patch_id):
			owned_patches.append(patch_id)
		else:
			eligible_patches.append(patch_id)
	eligible_patches.sort()
	owned_patches.sort()

	# Draw cards: one per hero in party order.
	var cards: Array = []
	for hero_id in party:
		var ids: Array = eligible_by_hero[hero_id]
		var index: int = rng.randi_range(0, ids.size() - 1)
		var chosen: String = ids[index]
		ids.remove_at(index)
		cards.append({"id": chosen, "owner": hero_id, "price": card_prices[chosen]})

	# Draw patch: prefer unowned, fallback to owned.
	var patch_pool_draw: Array[String] = eligible_patches
	if patch_pool_draw.is_empty():
		patch_pool_draw = owned_patches
	var patches: Array = []
	if not patch_pool_draw.is_empty():
		var patch_index: int = _p8_oracle_index(rng, patch_pool_draw)
		var chosen_patch: String = patch_pool_draw[patch_index]
		patches.append({"id": chosen_patch, "price": patch_prices[chosen_patch]})

	return {"ok": true, "cards": cards, "patches": patches}


## Independent ticket expansion rather than the production cumulative draw.
func _p8_oracle_index(rng: RandomNumberGenerator, ids: Array) -> int:
	if not ids.has("relay_bobbin") and not ids.has("hearth_lining"):
		return rng.randi_range(0, ids.size() - 1)
	var tickets: Array[int] = []
	for i in range(ids.size()):
		for ticket in range(10 if ids[i] in ["relay_bobbin", "hearth_lining"] else 100):
			tickets.append(i)
	return tickets[rng.randi_range(0, tickets.size() - 1)]


## Rejection helper for peddler stock tests.
func _reject_peddler_stock(label: String, rng_input: Variant, party_input: Variant,
		cards_input: Variant, patches_input: Variant, owned_input: Variant) -> void:
	var state_before: int = rng_input.state if rng_input is RandomNumberGenerator else -1
	var party_before = party_input.duplicate(true) if party_input is Array else party_input
	var cards_before = cards_input.duplicate(true) if cards_input is Array else cards_input
	var patches_before = patches_input.duplicate(true) if patches_input is Array else patches_input
	var owned_before = owned_input.duplicate(true) if owned_input is Array else owned_input
	var global_expected := -1
	if not (rng_input is RandomNumberGenerator):
		seed(48213)
		global_expected = randi()
		seed(48213)
	var result: Dictionary = RunShopStockOffers.generate_peddler_stock(rng_input, party_input, cards_input, patches_input, owned_input)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("cards", ["bad"]).is_empty() and result.get("patches", ["bad"]).is_empty(), label + ": no offers published")
	if rng_input is RandomNumberGenerator:
		_check(rng_input.state == state_before, label + ": no RNG consumed")
	if global_expected >= 0:
		_check(randi() == global_expected, label + ": global RNG untouched")
	_check(party_input == party_before, label + ": party unchanged")
	_check(cards_input == cards_before, label + ": card candidates unchanged")
	_check(patches_input == patches_before, label + ": patch candidates unchanged")
	_check(owned_input == owned_before, label + ": owned patches unchanged")
