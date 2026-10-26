extends SceneTree
## Deterministic headless test for the standalone V3TinkerPoolCards catalog (V3-1).
## Verifies the eight authored v3 Tinker base cards and their eight '+' upgrades field by field,
## deep-copy isolation, fail-closed lookups, base-only reward candidates, no RNG consumption and
## that the existing v2 Tinker pool and starter definitions are untouched. The v3 catalog is
## deliberately NOT wired into combat, rewards, the map or shops yet, so the catalog checks never
## drive a live card; the effect dictionaries are declarative data for the later integration task.
##
## Extended with deterministic headless combat resolution for the four paid Combat Scrap support
## cards (Gear Brace and Spare Screws, base and '+') through CombatTinkerV3ScrapSupportCards:
## printed energy, held-copy proof, self Block, the Tinker-only combat_scrap counter, the real
## seeded shared draw and inert refusals.

const CombatDeck = preload("res://scripts/combat_deck.gd")
const CombatParty = preload("res://scripts/combat_party.gd")
const CombatTinkerV3ScrapSupportCards = preload(
	"res://scripts/combat_tinker_v3_scrap_support_cards.gd")

const SCRAP_GEAR := "tinker_v3_gear_brace"
const SCRAP_GEAR_PLUS := "tinker_v3_gear_brace_plus"
const SCRAP_SCREWS := "tinker_v3_spare_screws"
const SCRAP_SCREWS_PLUS := "tinker_v3_spare_screws_plus"
const SCRAP_IDS: Array[String] = [SCRAP_GEAR, SCRAP_GEAR_PLUS, SCRAP_SCREWS, SCRAP_SCREWS_PLUS]

var failures: Array[String] = []
var checks: int = 0

## Existing v2 Tinker reward IDs that must stay owned by TinkerPoolCards.
const EXISTING_TINKER_POOL_IDS: Array[String] = [
	"tinker_rivet_shot",
	"tinker_spring_trap",
	"tinker_scatter_bolts",
	"tinker_spare_parts",
	"tinker_long_barrel",
	"tinker_spool_launcher",
	"tinker_overclock",
	"tinker_shrapnel_seam",
	"tinker_sight_glass",
	"tinker_ricochet",
	"tinker_bobbin_cannon",
	"tinker_snip_the_seam",
]


func _initialize() -> void:
	var expected: Dictionary = _expected_cards()
	_check(not expected.is_empty(), "authored expectation table is non-empty (precondition)")
	_test_each_card(V3TinkerPoolCards.new(), expected)
	_test_reward_candidates(V3TinkerPoolCards.new(), expected)
	_test_mechanic_contracts(V3TinkerPoolCards.new())
	_test_unknown_and_upgraded_ids(V3TinkerPoolCards.new(), expected)
	_test_mutation_isolation(V3TinkerPoolCards.new())
	_test_existing_catalogs_unchanged()
	_test_no_random_consumption()
	_test_scrap_support_catalog_contract()
	_test_scrap_gear_brace_play()
	_test_scrap_spare_screws_play()
	_test_scrap_draw_supply()
	_test_scrap_accumulation_and_fresh_party()
	_test_scrap_refusals()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("v3_tinker_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_tinker_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent Wind-up Turret payload; deliberately does not call the catalog helper.
func _turret(damage: int) -> Dictionary:
	return {
		"damage": damage,
		"duration_turns": 3,
		"tick": "end_player_turn",
		"target_kind": "enemy_random",
		"living_targets_only": true,
		"rng_source": "run"
	}


## Independent expected table keyed by each of the eight authored base IDs.
## "cost" is the base cost; "plus_cost" the upgraded cost (equal unless overridden).
func _expected_cards() -> Dictionary:
	return {
		"tinker_v3_brass_casing": {
			"name": "Brass Casing", "rarity": "common",
			"cost": 1, "plus_cost": 1,
			"from": [2, 3], "kind": "enemy_single", "to": [1, 2, 3],
			"base": {"damage": 4, "combat_scrap_gain": 1},
			"plus": {"damage": 6, "combat_scrap_gain": 1},
		},
		"tinker_v3_gear_brace": {
			"name": "Gear Brace", "rarity": "common",
			"cost": 1, "plus_cost": 1,
			"from": [1, 2, 3], "kind": "self", "to": [],
			"base": {"block": 5, "combat_scrap_gain": 1},
			"plus": {"block": 7, "combat_scrap_gain": 1},
		},
		"tinker_v3_spare_screws": {
			"name": "Spare Screws", "rarity": "common",
			"cost": 1, "plus_cost": 0,
			"from": [2, 3], "kind": "self", "to": [],
			"base": {"combat_scrap_gain": 2, "draw": 1},
			"plus": {"combat_scrap_gain": 2, "draw": 1},
		},
		"tinker_v3_spring_clamp": {
			"name": "Spring Clamp", "rarity": "common",
			"cost": 1, "plus_cost": 1,
			"from": [2, 3], "kind": "enemy_single", "to": [1, 2, 3],
			"base": {"damage": 3, "weak": 1, "combat_scrap_gain": 1},
			"plus": {"damage": 4, "weak": 1, "combat_scrap_gain": 1},
		},
		"tinker_v3_wind_up_turret": {
			"name": "Wind-up Turret", "rarity": "uncommon",
			"cost": 2, "plus_cost": 2,
			"from": [3], "kind": "self", "to": [],
			"base": {"turret": _turret(3)},
			"plus": {"turret": _turret(4)},
		},
		"tinker_v3_overload": {
			"name": "Overload", "rarity": "uncommon",
			"cost": 1, "plus_cost": 1,
			"from": [2, 3], "kind": "enemy_single", "to": [1, 2, 3],
			"base": {"damage": 2, "damage_per_combat_scrap": 3,
				"consume_all_combat_scrap": true},
			"plus": {"damage": 3, "damage_per_combat_scrap": 4,
				"consume_all_combat_scrap": true},
		},
		"tinker_v3_jury_rig": {
			"name": "Jury-rig", "rarity": "rare",
			"cost": 2, "plus_cost": 1,
			"from": [2, 3], "kind": "self", "to": [],
			"base": {"copy_previous_card": true, "copied_card_cost": 0,
				"once_per_combat": true, "exclude_self": true},
			"plus": {"copy_previous_card": true, "copied_card_cost": 0,
				"once_per_combat": true, "exclude_self": true},
		},
		"tinker_v3_scrapstorm": {
			"name": "Scrapstorm", "rarity": "rare",
			"cost": 2, "plus_cost": 2,
			"from": [3], "kind": "enemy_all", "to": [1, 2, 3],
			"base": {"damage": 3, "combat_scrap_spend_max": 3,
				"bonus_damage_per_combat_scrap": 1, "living_targets_only": true},
			"plus": {"damage": 4, "combat_scrap_spend_max": 3,
				"bonus_damage_per_combat_scrap": 1, "living_targets_only": true},
		},
	}


func _test_each_card(catalog: V3TinkerPoolCards, expected: Dictionary) -> void:
	var seen: Dictionary = {}
	for base_id: String in expected:
		var row: Dictionary = expected[base_id]
		var plus_id: String = base_id + "_plus"
		_check(not seen.has(base_id) and not seen.has(plus_id), base_id + " IDs unique")
		seen[base_id] = true
		seen[plus_id] = true
		_check(catalog.has_card(base_id) and catalog.has_card(plus_id),
			base_id + " has both an addressable base and plus")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " links exactly its plus")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade twice")
		_check(not catalog.has_card(base_id + "_plus_plus"),
			base_id + " has no accidental second upgrade partner")

		var base: Dictionary = catalog.get_definition(base_id)
		var plus: Dictionary = catalog.get_definition(plus_id)
		_check(not base.is_empty() and not plus.is_empty(), base_id + " definitions nonempty")
		if base.is_empty() or plus.is_empty():
			continue

		for is_plus in [false, true]:
			var card: Dictionary = plus if is_plus else base
			var id: String = plus_id if is_plus else base_id
			_check(card.get("id") == id, id + " stable ID")
			_check(card.get("display_name") == row["name"] + ("+" if is_plus else ""),
				id + " display name")
			_check(card.get("owner") == "tinker", id + " Tinker owner")
			_check(card.get("rarity") == row["rarity"], id + " correct rarity")
			_check(card.get("cost") == row["plus_cost" if is_plus else "cost"],
				id + " correct authored cost")
			_check(card.get("from_positions") == row["from"], id + " legal source positions")
			_check(card.get("target_kind") == row["kind"], id + " target kind")
			_check(card.get("to_positions") == row["to"], id + " legal target positions")
			_check(card.get("effects") == row["plus" if is_plus else "base"],
				id + " exact declarative effects")
			_check(card.get("illustration_path")
				== "res://assets/paper/cards/" + base_id + ".png",
				id + " stable placeholder illustration path")
			_check(card.get("starting_copies") == 0, id + " never a starter copy")
			_check(card.get("base_id") == base_id and card.get("upgrade_id") == plus_id
				and card.get("is_upgrade") == is_plus, id + " version metadata")

		# Every non-scaling field survives the upgrade; only cost may differ.
		for field in ["owner", "rarity", "from_positions", "target_kind",
				"to_positions", "illustration_path", "starting_copies", "base_id",
				"upgrade_id"]:
			_check(base.get(field) == plus.get(field), base_id + " retains " + field)


func _test_reward_candidates(catalog: V3TinkerPoolCards, expected: Dictionary) -> void:
	var candidates: Array[String] = catalog.get_pool_card_ids()
	_check(not candidates.is_empty(), "reward candidates are non-empty (precondition)")
	var unique: Dictionary = {}
	for id in candidates:
		_check(not unique.has(id), id + " reward candidate appears only once")
		unique[id] = true
		_check(expected.has(id), id + " candidate is one of the eight authored bases")
		var definition: Dictionary = catalog.get_definition(id)
		_check(not definition.is_empty() and definition.get("is_upgrade") == false
			and definition.get("owner") == "tinker"
			and definition.get("starting_copies") == 0,
			id + " reward candidate is a base Tinker card, not a plus")
		_check(not id.ends_with("_plus"), id + " reward candidate ID is never a plus")
	for base_id: String in expected:
		_check(candidates.has(base_id), base_id + " eligible as reward candidate")
		_check(not candidates.has(base_id + "_plus"),
			base_id + " plus excluded from reward pool")
	candidates.clear()
	candidates.append("forged_card")
	_check(catalog.get_pool_card_ids().has("tinker_v3_brass_casing"),
		"clearing the returned candidate array does not alter the stored pool")
	_check(not catalog.get_pool_card_ids().has("forged_card"),
		"injecting into the returned candidate array does not alter the stored pool")


func _test_mechanic_contracts(catalog: V3TinkerPoolCards) -> void:
	# Brass Casing: blunderbuss damage plus salvaged Combat Scrap.
	var brass: Dictionary = catalog.get_definition("tinker_v3_brass_casing").get("effects", {})
	var brass_plus: Dictionary = catalog.get_definition("tinker_v3_brass_casing_plus").get("effects", {})
	_check(brass.get("damage") == 4 and brass.get("combat_scrap_gain") == 1,
		"Brass Casing deals 4 and salvages 1 Combat Scrap")
	_check(brass_plus.get("damage") == 6 and brass_plus.get("combat_scrap_gain") == 1,
		"Brass Casing+ deals 6 and still salvages 1 Combat Scrap")

	# Gear Brace: folding gear shield Block plus Combat Scrap.
	_check(catalog.get_definition("tinker_v3_gear_brace").get("effects")
		== {"block": 5, "combat_scrap_gain": 1}, "Gear Brace gives 5 Block and 1 scrap")
	_check(catalog.get_definition("tinker_v3_gear_brace_plus").get("effects")
		== {"block": 7, "combat_scrap_gain": 1}, "Gear Brace+ gives 7 Block and 1 scrap")

	# Spare Screws: gadget-bag recovery, same effects, cheaper upgraded cost.
	var screws: Dictionary = catalog.get_definition("tinker_v3_spare_screws")
	var screws_plus: Dictionary = catalog.get_definition("tinker_v3_spare_screws_plus")
	_check(screws.get("effects") == {"combat_scrap_gain": 2, "draw": 1}
		and screws.get("cost") == 1, "Spare Screws costs 1 for 2 scrap and 1 draw")
	_check(screws_plus.get("effects") == screws.get("effects")
		and screws_plus.get("cost") == 0, "Spare Screws+ keeps effects at cost 0")
	_check(not screws.get("effects").has("combat_scrap_spend")
		and not screws.get("effects").has("scraps"),
		"Spare Screws never models wallet scraps")

	# Spring Clamp: ordinary Weak 1, no invented status.
	var clamp: Dictionary = catalog.get_definition("tinker_v3_spring_clamp").get("effects", {})
	var clamp_plus: Dictionary = catalog.get_definition("tinker_v3_spring_clamp_plus").get("effects", {})
	_check(clamp.get("weak") == 1 and clamp_plus.get("weak") == 1,
		"Spring Clamp applies Weak 1 on both versions")
	_check(clamp.get("damage") == 3 and clamp.get("combat_scrap_gain") == 1,
		"Spring Clamp deals 3 and gains 1 scrap")
	_check(clamp_plus.get("damage") == 4 and clamp_plus.get("combat_scrap_gain") == 1,
		"Spring Clamp+ deals 4 and gains 1 scrap")

	# Wind-up Turret: exactly three end-of-player-turn random living-enemy ticks, run RNG.
	var turret: Dictionary = catalog.get_definition("tinker_v3_wind_up_turret")
	var turret_plus: Dictionary = catalog.get_definition("tinker_v3_wind_up_turret_plus")
	_check(turret.get("target_kind") == "self" and turret.get("to_positions") == [],
		"Wind-up Turret deploys on self without enemy positions")
	_check(turret.get("effects") == {"turret": _turret(3)},
		"Wind-up Turret payload is exactly 3 damage x 3 turns on the run RNG")
	_check(turret_plus.get("effects") == {"turret": _turret(4)},
		"Wind-up Turret+ payload is exactly 4 damage x 3 turns on the run RNG")
	var turret_rule: Dictionary = turret_plus.get("effects", {}).get("turret", {})
	_check(turret_rule.get("duration_turns") == 3
		and turret_rule.get("tick") == "end_player_turn"
		and turret_rule.get("target_kind") == "enemy_random"
		and turret_rule.get("living_targets_only") == true
		and turret_rule.get("rng_source") == "run",
		"Wind-up Turret+ ticks exactly three times against random living enemies with run RNG")

	# Overload: flat damage plus per-scrap damage, then spend every combat scrap only.
	var overload: Dictionary = catalog.get_definition("tinker_v3_overload").get("effects", {})
	var overload_plus: Dictionary = catalog.get_definition("tinker_v3_overload_plus").get("effects", {})
	_check(overload.get("damage") == 2 and overload.get("damage_per_combat_scrap") == 3
		and overload.get("consume_all_combat_scrap") == true,
		"Overload adds 3 per Combat Scrap and consumes all of it")
	_check(overload_plus.get("damage") == 3
		and overload_plus.get("damage_per_combat_scrap") == 4
		and overload_plus.get("consume_all_combat_scrap") == true,
		"Overload+ adds 4 per Combat Scrap and consumes all of it")
	_check(not overload.has("scraps") and not overload.has("scrap_cost"),
		"Overload never reads or spends wallet scraps")

	# Jury-rig: copy the previous other card once per combat for free; plus costs 1.
	for jury_id in ["tinker_v3_jury_rig", "tinker_v3_jury_rig_plus"]:
		var jury: Dictionary = catalog.get_definition(jury_id)
		_check(jury.get("effects", {}) == {"copy_previous_card": true,
			"copied_card_cost": 0, "once_per_combat": true, "exclude_self": true},
			jury_id + " copies the previous other card once per combat at cost 0")
	_check(catalog.get_definition("tinker_v3_jury_rig").get("cost") == 2,
		"Jury-rig costs 2")
	_check(catalog.get_definition("tinker_v3_jury_rig_plus").get("cost") == 1,
		"Jury-rig+ costs 1 with unchanged copy effects")

	# Scrapstorm: up to 3 Combat Scrap, each adding +1 to every living enemy hit.
	var storm: Dictionary = catalog.get_definition("tinker_v3_scrapstorm")
	var storm_plus: Dictionary = catalog.get_definition("tinker_v3_scrapstorm_plus")
	_check(storm.get("target_kind") == "enemy_all" and storm.get("to_positions") == [1, 2, 3],
		"Scrapstorm hits every enemy position")
	_check(storm.get("effects") == {"damage": 3, "combat_scrap_spend_max": 3,
		"bonus_damage_per_combat_scrap": 1, "living_targets_only": true},
		"Scrapstorm deals 3 and spends at most 3 Combat Scrap for +1 each")
	_check(storm_plus.get("effects") == {"damage": 4, "combat_scrap_spend_max": 3,
		"bonus_damage_per_combat_scrap": 1, "living_targets_only": true},
		"Scrapstorm+ deals 4 and keeps the same scrap spend")

	# The catalog is data only: it never holds run/combat state or an RNG.
	_check(not catalog.has_method("resolve"), "catalog exposes no live resolution")
	_check(not catalog.has_method("spend_scraps"), "catalog exposes no wallet spending")


func _test_unknown_and_upgraded_ids(catalog: V3TinkerPoolCards, expected: Dictionary) -> void:
	_check(catalog.get_definition("tinker_v3_missing_card").is_empty(),
		"unknown definition rejects")
	_check(catalog.get_definition("").is_empty(), "empty definition ID rejects")
	_check(catalog.get_definition("tinker_v3_").is_empty(), "bare prefix definition rejects")
	_check(not catalog.has_card("tinker_v3_missing_card") and not catalog.has_card(""),
		"unknown/empty IDs rejected")
	_check(not catalog.has_card(null) and not catalog.has_card(123),
		"non-string IDs rejected")
	_check(catalog.get_upgrade_id("tinker_v3_missing_card") == ""
		and catalog.get_upgrade_id("") == "", "unknown/empty upgrade query rejects")
	_check(catalog.get_upgrade_id(null) == "" and catalog.get_upgrade_id(123) == "",
		"non-string upgrade query rejects")
	_check(catalog.get_definition(null).is_empty() and catalog.get_definition(123).is_empty(),
		"non-string definitions reject")
	_check(catalog.get_definition("tinker_pop_shot").is_empty()
		and catalog.get_definition("tinker_rivet_shot").is_empty(),
		"v3 catalog does not shadow starter or v2 Tinker cards")

	for base_id: String in expected:
		var plus_id: String = base_id + "_plus"
		_check(catalog.has_card(plus_id) and not catalog.get_definition(plus_id).is_empty(),
			plus_id + " addressable as its own definition")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " rejects a second upgrade")
		_check(not catalog.has_card(plus_id + "_plus")
			and catalog.get_definition(plus_id + "_plus").is_empty(),
			plus_id + " has no further upgrade definition")
		_check(not catalog.get_pool_card_ids().has(plus_id),
			plus_id + " rejected as a base reward candidate")


func _test_mutation_isolation(catalog: V3TinkerPoolCards) -> void:
	# Mutating top-level fields and nested position arrays of a base definition.
	var altered: Dictionary = catalog.get_definition("tinker_v3_brass_casing")
	altered["id"] = "forgery"
	altered["cost"] = 99
	altered["from_positions"].clear()
	altered["to_positions"].append(99)
	altered["effects"]["damage"] = 999
	altered["effects"]["combat_scrap_gain"] = 50
	var pristine: Dictionary = catalog.get_definition("tinker_v3_brass_casing")
	_check(pristine.get("id") == "tinker_v3_brass_casing" and pristine.get("cost") == 1
		and pristine.get("from_positions") == [2, 3]
		and pristine.get("to_positions") == [1, 2, 3]
		and pristine.get("effects") == {"damage": 4, "combat_scrap_gain": 1},
		"top-level fields, position arrays and effects stay deeply detached")

	# Mutating the nested Turret rule of a plus definition.
	var altered_turret: Dictionary = catalog.get_definition("tinker_v3_wind_up_turret_plus")
	altered_turret["effects"]["turret"]["damage"] = 100
	altered_turret["effects"]["turret"]["duration_turns"] = 99
	altered_turret["effects"]["turret"]["rng_source"] = "second_rng"
	altered_turret["effects"]["turret"]["invented"] = true
	_check(catalog.get_definition("tinker_v3_wind_up_turret_plus").get("effects")
		== {"turret": _turret(4)}, "nested Turret rule stays deeply detached")

	# Mutating a nested condition-style array (Scrapstorm positions) through a separate lookup.
	var altered_storm: Dictionary = catalog.get_definition("tinker_v3_scrapstorm")
	altered_storm["to_positions"].clear()
	altered_storm["effects"]["bonus_damage_per_combat_scrap"] = 100
	_check(catalog.get_definition("tinker_v3_scrapstorm").get("effects")
		== {"damage": 3, "combat_scrap_spend_max": 3,
			"bonus_damage_per_combat_scrap": 1, "living_targets_only": true},
		"separate lookups cannot change Scrapstorm data")

	# Repeated lookups still return the authored payload.
	_check(catalog.get_definition("tinker_v3_jury_rig_plus").get("effects")
		== {"copy_previous_card": true, "copied_card_cost": 0,
			"once_per_combat": true, "exclude_self": true},
		"repeated lookups return the pristine Jury-rig+ payload")


func _test_existing_catalogs_unchanged() -> void:
	var tinker_pool := TinkerPoolCards.new()
	var starter := StarterCards.new()
	var v3 := V3TinkerPoolCards.new()

	for existing_id: String in EXISTING_TINKER_POOL_IDS:
		_check(tinker_pool.has_card(existing_id), "v2 Tinker pool still owns " + existing_id)
		_check(tinker_pool.get_pool_card_ids().has(existing_id),
			"v2 Tinker pool still lists " + existing_id + " as a base")
		_check(not v3.has_card(existing_id), "v3 catalog does not take over " + existing_id)
		_check(not v3.has_card(existing_id + "_plus"),
			"v3 catalog does not take over " + existing_id + "_plus")

	# Representative existing v2 definitions keep their authored data.
	_check(tinker_pool.get_definition("tinker_rivet_shot").get("effects")
		== {"damage": 4, "exposed": 1}, "tinker_rivet_shot effects intact")
	_check(tinker_pool.get_definition("tinker_spring_trap").get("effects").get("pinned", {})
		.get("bonus_damage") == 5, "tinker_spring_trap Pinned rule intact")
	_check(tinker_pool.get_definition("tinker_snip_the_seam_plus").get("effects")
		.get("conditional_damage", {}).get("damage") == 20,
		"tinker_snip_the_seam_plus conditional damage intact")

	# Starter Tinker cards keep their exact authored data and copy counts.
	var pop_shot: Dictionary = starter.get_definition("tinker_pop_shot")
	_check(pop_shot.get("display_name") == "Pop Shot" and pop_shot.get("cost") == 1
		and pop_shot.get("from_positions") == [2, 3]
		and pop_shot.get("to_positions") == [1, 2, 3]
		and pop_shot.get("effects") == {"damage": 5}
		and pop_shot.get("starting_copies") == 2, "starter Pop Shot x2 intact")
	var scrap_bomb: Dictionary = starter.get_definition("tinker_scrap_bomb")
	_check(scrap_bomb.get("cost") == 2 and scrap_bomb.get("target_kind") == "enemy_all"
		and scrap_bomb.get("from_positions") == [3]
		and scrap_bomb.get("effects") == {"damage": 4}
		and scrap_bomb.get("starting_copies") == 1, "starter Scrap Bomb intact")
	var tune_up: Dictionary = starter.get_definition("tinker_tune_up")
	_check(tune_up.get("cost") == 0 and tune_up.get("effects") == {"draw": 1}
		and tune_up.get("starting_copies") == 1, "starter Tune Up intact")

	var deck: Array[String] = starter.get_starting_deck()
	_check(deck.count("tinker_pop_shot") == 2, "starter deck keeps two Pop Shots")
	_check(deck.count("tinker_scrap_bomb") == 1, "starter deck keeps one Scrap Bomb")
	_check(deck.count("tinker_tune_up") == 1, "starter deck keeps one Tune Up")
	for base_id in _expected_cards():
		_check(not starter.has_card(base_id) and not starter.has_card(base_id + "_plus"),
			base_id + " v3 card stays out of the starter catalog")
		_check(not deck.has(base_id), base_id + " v3 card stays out of the starter deck")


func _test_no_random_consumption() -> void:
	seed(814177)
	var expected_next: int = randi()
	seed(814177)
	var fresh := V3TinkerPoolCards.new()
	for base_id in fresh.get_pool_card_ids():
		var card: Dictionary = fresh.get_definition(base_id)
		_check(not card.is_empty(), base_id + " RNG probe reads an actual definition")
		fresh.get_definition(fresh.get_upgrade_id(base_id))
		fresh.get_definition("tinker_v3_missing_card")
		fresh.has_card(base_id)
		fresh.get_upgrade_id("tinker_v3_missing_card")
	_check(randi() == expected_next, "construction and lookups never draw global RNG")

	# A separately seeded RNG keeps its exact state across catalog use.
	var rng := RandomNumberGenerator.new()
	rng.seed = 991733
	var state_before: int = rng.state
	var probe := V3TinkerPoolCards.new()
	for card_id in probe.get_pool_card_ids():
		probe.get_definition(card_id + "_plus")
	probe.get_pool_card_ids()
	_check(rng.state == state_before, "catalog use does not touch an unrelated seeded RNG")


## AC4 (catalog half): the four scrap supports are exactly the authored v3 Tinker printings, and a
## rewritten, relinked, copied or foreign record can never be paid for as one of them.
func _test_scrap_support_catalog_contract() -> void:
	var catalog := V3TinkerPoolCards.new()
	var resolver := CombatTinkerV3ScrapSupportCards.new()
	var expected := {
		SCRAP_GEAR: {"cost": 1, "from": [1, 2, 3], "block": 5, "scrap": 1,
			"effects": {"block": 5, "combat_scrap_gain": 1}},
		SCRAP_GEAR_PLUS: {"cost": 1, "from": [1, 2, 3], "block": 7, "scrap": 1,
			"effects": {"block": 7, "combat_scrap_gain": 1}},
		SCRAP_SCREWS: {"cost": 1, "from": [2, 3], "block": 0, "scrap": 2,
			"effects": {"combat_scrap_gain": 2, "draw": 1}},
		SCRAP_SCREWS_PLUS: {"cost": 0, "from": [2, 3], "block": 0, "scrap": 2,
			"effects": {"combat_scrap_gain": 2, "draw": 1}},
	}
	for card_id: String in SCRAP_IDS:
		var row: Dictionary = expected[card_id]
		var record: Dictionary = catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + " is authored in the v3 Tinker catalog")
		_check(record.get("owner") == "tinker", card_id + " is owned by Tinker")
		_check(record.get("cost") == row["cost"],
			card_id + " prints cost " + str(row["cost"]))
		_check(record.get("from_positions") == row["from"], card_id + " prints its FROM seats")
		_check(record.get("target_kind") == "self", card_id + " targets self")
		_check(record.get("to_positions") == [], card_id + " prints an empty TO line")
		_check(record.get("effects") == row["effects"], card_id + " prints its exact effects")
		_check(row["effects"].get("combat_scrap_gain") == row["scrap"],
			card_id + " prints the expected Combat Scrap gain")
		_check(not row["effects"].has("scraps") and not row["effects"].has("scrap_cost"),
			card_id + " never models the run wallet")
		_check(resolver.is_supported_card(card_id), card_id + " is a supported scrap card")
		_check(CombatTinkerV3ScrapSupportCards.is_authentic_definition(record, card_id),
			card_id + " passes the definition authenticator")
		_check(CombatTinkerV3ScrapSupportCards.scrap_support_definition(card_id) == record,
			card_id + " resolves to its exact detached catalog record")
		if card_id.ends_with("_plus"):
			_check(record.get("base_id") == card_id.trim_suffix("_plus")
				and record.get("upgrade_id") == card_id
				and record.get("is_upgrade") == true,
				card_id + " links back to its one base printing")
		else:
			_check(record.get("base_id") == card_id
				and record.get("upgrade_id") == card_id + "_plus"
				and record.get("is_upgrade") == false,
				card_id + " links forward to its one upgrade")

	# Detached: mutating a resolved record cannot rewrite what the next resolution returns.
	var sample: Dictionary = CombatTinkerV3ScrapSupportCards.scrap_support_definition(SCRAP_GEAR)
	_check(not sample.is_empty(), "scrap-support resolution fixture loaded")
	if not sample.is_empty():
		sample["effects"]["block"] = 900
		sample["effects"]["combat_scrap_gain"] = 9
		sample["from_positions"].clear()
		sample["cost"] = 0
		_check(CombatTinkerV3ScrapSupportCards.scrap_support_definition(SCRAP_GEAR)
			== catalog.get_definition(SCRAP_GEAR),
			"a mutated scrap-support definition cannot poison later resolutions")

	# Every other v3 Tinker card (base and plus) is unrelated to this service.
	var unrelated: Array[String] = []
	for base_id in catalog.get_pool_card_ids():
		unrelated.append(base_id)
		var upgrade_id: String = catalog.get_upgrade_id(base_id)
		if not upgrade_id.is_empty():
			unrelated.append(upgrade_id)
	for card_id: String in SCRAP_IDS:
		unrelated.erase(card_id)
	_check(unrelated.has("tinker_v3_brass_casing") and unrelated.has("tinker_v3_overload"),
		"unrelated-card fixture really contains other authentic v3 Tinker cards (precondition)")
	for other_id: String in unrelated:
		_check(CombatTinkerV3ScrapSupportCards.scrap_support_definition(other_id).is_empty(),
			other_id + " does not resolve as a scrap support")
		_check(not resolver.is_supported_card(other_id),
			other_id + " is not a supported scrap support")

	# The v2 Tinker pool and foreign spellings are never scrap supports.
	var forged: Array = ["tinker_spare_parts", "tinker_overclock", "tinker_v3_gear_brace+",
		"tinker_v3_gear_brace_plus_plus", "tinker_v3_spare_screws_+", "gear_brace",
		"TINKER_V3_GEAR_BRACE", "", "tinker_v3_missing_card", StringName(SCRAP_GEAR),
		null, 0, 3.5, false, [], {}]
	for other_id: Variant in forged:
		_check(CombatTinkerV3ScrapSupportCards.scrap_support_definition(other_id).is_empty(),
			"forged or non-string ID never resolves as a scrap support: " + str(other_id))
		_check(not resolver.is_supported_card(other_id),
			"forged or non-string ID is never a supported scrap support: " + str(other_id))

	# Adversarial copies of a real record: every altered contract field is refused.
	var base_record: Dictionary = catalog.get_definition(SCRAP_GEAR)
	_check(not base_record.is_empty()
		and CombatTinkerV3ScrapSupportCards.is_authentic_definition(base_record, SCRAP_GEAR),
		"authenticator positive fixture really is the authored Gear Brace")
	var mutations: Array[Callable] = [
		func(record: Dictionary) -> void: record["effects"]["block"] = 6,
		func(record: Dictionary) -> void: record["effects"]["block"] = 5.0,
		func(record: Dictionary) -> void: record["effects"]["block"] = "5",
		func(record: Dictionary) -> void: record["effects"]["combat_scrap_gain"] = 2,
		func(record: Dictionary) -> void: record["effects"]["combat_scrap_gain"] = 1.0,
		func(record: Dictionary) -> void: record["effects"].erase("combat_scrap_gain"),
		func(record: Dictionary) -> void: record["effects"]["draw"] = 1,
		func(record: Dictionary) -> void: record["effects"] = {"block": 5},
		func(record: Dictionary) -> void: record["effects"] = "block",
		func(record: Dictionary) -> void: record["cost"] = 0,
		func(record: Dictionary) -> void: record["cost"] = 2,
		func(record: Dictionary) -> void: record["cost"] = 1.0,
		func(record: Dictionary) -> void: record["owner"] = "warden",
		func(record: Dictionary) -> void: record["from_positions"] = [2, 3],
		func(record: Dictionary) -> void: record["from_positions"] = ["1", "2", "3"],
		func(record: Dictionary) -> void: record["from_positions"] = "1,2,3",
		func(record: Dictionary) -> void: record["to_positions"] = [1],
		func(record: Dictionary) -> void: record["target_kind"] = "ally_single",
		func(record: Dictionary) -> void: record["id"] = SCRAP_GEAR_PLUS,
		func(record: Dictionary) -> void: record["is_upgrade"] = true,
		func(record: Dictionary) -> void: record["base_id"] = SCRAP_GEAR_PLUS,
		func(record: Dictionary) -> void: record.erase("upgrade_id"),
		func(record: Dictionary) -> void: record["upgrade_of"] = SCRAP_GEAR,
		func(record: Dictionary) -> void: record.erase("to_positions"),
		func(record: Dictionary) -> void: record.erase("effects"),
	]
	for index in range(mutations.size()):
		var tampered: Dictionary = base_record.duplicate(true)
		mutations[index].call(tampered)
		_check(not CombatTinkerV3ScrapSupportCards.is_authentic_definition(tampered, SCRAP_GEAR),
			"tampered scrap-support record " + str(index) + " is refused")
	_check(not CombatTinkerV3ScrapSupportCards.is_authentic_definition(
		catalog.get_definition(SCRAP_GEAR_PLUS), SCRAP_GEAR),
		"an upgraded record cannot authenticate as its base ID")
	_check(not CombatTinkerV3ScrapSupportCards.is_authentic_definition(
		catalog.get_definition(SCRAP_GEAR), SCRAP_GEAR_PLUS),
		"a base record cannot authenticate as its upgraded ID")


## AC1: a real held Gear Brace or Gear Brace+ pays one energy, discards exactly one copy, grants
## the printed Block only to the living Tinker at his actual seat and gains exactly one Combat Scrap.
func _test_scrap_gear_brace_play() -> void:
	var resolver := CombatTinkerV3ScrapSupportCards.new()
	var cases := [
		{"id": SCRAP_GEAR, "seat": 1, "block": 5},
		{"id": SCRAP_GEAR_PLUS, "seat": 2, "block": 7},
		{"id": SCRAP_GEAR, "seat": 3, "block": 5},
		{"id": SCRAP_GEAR_PLUS, "seat": 1, "block": 7},
	]
	for index in range(cases.size()):
		var entry: Dictionary = cases[index]
		var card_id: String = entry["id"]
		var seat: int = entry["seat"]
		var printed_block: int = entry["block"]
		var label := card_id + " from seat " + str(seat)
		var party := _scrap_party(seat)
		_check(party.gain_block(seat, 2), label + ": the owner fixture really carries Block")
		var deck := _scrap_deck([card_id], 301100 + index, 6)
		_check(deck.energy == 3 and deck.turn_active,
			label + ": a real three-energy turn is active")
		var blocks_before: Array = [
			party.get_hero(1).get("block"), party.get_hero(2).get("block"),
			party.get_hero(3).get("block"),
		]
		var wallet := {"gold": 9, "scraps": 4}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var rng_before: int = deck._rng.state
		var draw_before: int = deck.draw_pile.size()
		var before := _scrap_snapshot(deck, party)
		var result: Dictionary = resolver.play_card(deck, party, card_id)
		_check(result.get("ok") == true and result.get("reason") == "applied",
			label + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == 1,
			label + ": receipt names the authentic card and its one energy")
		_check(result.get("owner_position") == seat and result.get("target_position") == seat,
			label + ": receipt reports the real owner seat as the self recipient")
		_check(result.get("block_gained") == printed_block,
			label + ": receipt reports the printed Block")
		_check(result.get("draw_requested") == 0 and result.get("drawn") == 0,
			label + ": Gear Brace prints no draw")
		_check(result.get("combat_scrap_before") == 0
			and result.get("combat_scrap_gained") == 1
			and result.get("combat_scrap_after") == 1,
			label + ": receipt reports exactly one Combat Scrap from zero")
		_check(result.get("energy_before") == 3 and result.get("energy_after") == 2,
			label + ": receipt reports the exact energy change")
		_check(not result.has("scraps") and not result.has("wallet"),
			label + ": receipt carries no wallet state")
		_check(deck.energy == 2, label + ": exactly one energy was paid")
		_check(deck.hand.count(card_id) == 0, label + ": the held copy left the hand")
		_check(deck.discard_pile == [card_id],
			label + ": exactly one played copy reached the discard")
		_check(deck.draw_pile.size() == draw_before, label + ": Gear Brace drew nothing")
		_check(deck._rng.state == rng_before, label + ": no RNG was consumed")
		_check(party.get_hero(seat).get("block") == int(blocks_before[seat - 1]) + printed_block,
			label + ": the Tinker gained exactly the printed Block on top of existing Block")
		_check(party.get_hero(seat).get("combat_scrap") == 1,
			label + ": the detached reader shows one Combat Scrap")
		_check(party._heroes[seat - 1].get("combat_scrap") == 1,
			label + ": the authoritative hero record holds one Combat Scrap")
		_check(party.get_hero(seat).get("hp") == 26, label + ": the Tinker's HP is untouched")
		for position: int in [1, 2, 3]:
			if position == seat:
				continue
			_check(party.get_hero(position).get("block") == int(blocks_before[position - 1]),
				label + ": seat " + str(position) + " gained no Block")
			_check(not party.get_hero(position).has("combat_scrap"),
				label + ": seat " + str(position) + " gained no Combat Scrap")
		_check(wallet == wallet_before, label + ": wallet scraps are never modified")
		_check(_scrap_snapshot(deck, party)
			== _expected_scrap_gear(before, card_id, seat, printed_block),
			label + ": exact hand, piles, energy, turn, party, counter and RNG state")

	# Two genuine held copies: the play discards exactly one of them.
	var copy_party := _scrap_party(2)
	var copy_deck := CombatDeck.new([SCRAP_GEAR, SCRAP_GEAR, "v3_scrap_filler_a",
		"v3_scrap_filler_b", "v3_scrap_filler_c", "v3_scrap_filler_d"],
		_scrap_rng(301199))
	_check(copy_deck.start_turn(), "duplicate-copy fixture starts a real turn")
	while copy_deck.hand.count(SCRAP_GEAR) < 2 and copy_deck.draw_pile.has(SCRAP_GEAR):
		var spare_slot := -1
		for hand_index in range(copy_deck.hand.size()):
			if copy_deck.hand[hand_index] != SCRAP_GEAR:
				spare_slot = hand_index
				break
		var pile_index: int = copy_deck.draw_pile.find(SCRAP_GEAR)
		if spare_slot < 0 or pile_index < 0:
			break
		var moved: String = copy_deck.hand[spare_slot]
		copy_deck.draw_pile[pile_index] = moved
		copy_deck.hand[spare_slot] = SCRAP_GEAR
	_check(copy_deck.hand.count(SCRAP_GEAR) == 2,
		"duplicate-copy fixture really holds two copies")
	var copy_result: Dictionary = resolver.play_card(copy_deck, copy_party, SCRAP_GEAR)
	_check(copy_result.get("ok") == true, "a hand with two copies is one legal play")
	_check(copy_deck.hand.count(SCRAP_GEAR) == 1, "exactly one held copy was discarded")
	_check(copy_deck.discard_pile == [SCRAP_GEAR],
		"only the played copy reached the discard")
	_check(copy_party.get_hero(2).get("block") == 5
		and copy_party.get_hero(2).get("combat_scrap") == 1,
		"the duplicate-copy play still grants its printed Block and one Combat Scrap")


## AC2: a real held Spare Screws costs its printed 1 or 0, gains exactly two Combat Scrap, draws
## one genuine shared card before the discard and discards exactly one played copy.
func _test_scrap_spare_screws_play() -> void:
	var resolver := CombatTinkerV3ScrapSupportCards.new()
	var cases := [
		{"id": SCRAP_SCREWS, "seat": 2, "cost": 1},
		{"id": SCRAP_SCREWS, "seat": 3, "cost": 1},
		{"id": SCRAP_SCREWS_PLUS, "seat": 2, "cost": 0},
		{"id": SCRAP_SCREWS_PLUS, "seat": 3, "cost": 0},
	]
	for index in range(cases.size()):
		var entry: Dictionary = cases[index]
		var card_id: String = entry["id"]
		var seat: int = entry["seat"]
		var cost: int = entry["cost"]
		var label := card_id + " from seat " + str(seat)
		var party := _scrap_party(seat)
		var deck := _scrap_deck([card_id], 302100 + index, 5)
		_check(deck.energy == 3 and deck.draw_pile.size() == 1,
			label + ": a real turn leaves exactly one genuine shared card to draw")
		var expected_draw: String = deck.draw_pile.back()
		var rng_before: int = deck._rng.state
		var before := _scrap_snapshot(deck, party)
		var result: Dictionary = resolver.play_card(deck, party, card_id)
		_check(result.get("ok") == true and result.get("reason") == "applied",
			label + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == cost,
			label + ": receipt names the authentic card and its printed cost")
		_check(result.get("owner_position") == seat and result.get("target_position") == seat,
			label + ": receipt reports the real owner seat as the self recipient")
		_check(result.get("block_gained") == 0, label + ": Spare Screws grants no Block")
		_check(result.get("draw_requested") == 1 and result.get("drawn") == 1,
			label + ": receipt reports one shared draw")
		_check(result.get("combat_scrap_before") == 0
			and result.get("combat_scrap_gained") == 2
			and result.get("combat_scrap_after") == 2,
			label + ": receipt reports exactly two Combat Scrap from zero")
		_check(result.get("energy_before") == 3
			and result.get("energy_after") == 3 - cost,
			label + ": receipt reports the exact printed energy")
		_check(not result.has("scraps") and not result.has("wallet"),
			label + ": receipt carries no wallet state")
		_check(deck.energy == 3 - cost, label + ": exactly the printed cost was paid")
		_check(deck.hand.count(card_id) == 0, label + ": the played copy left the hand")
		_check(deck.hand.has(expected_draw),
			label + ": the seeded shared draw reached the hand")
		_check(deck.draw_pile.is_empty(), label + ": the single shared draw emptied the supply")
		_check(deck.discard_pile == [card_id],
			label + ": exactly one played copy reached the discard after the draw")
		_check(deck._rng.state == rng_before,
			label + ": drawing from a nonempty supply consumes no RNG")
		_check(party.get_hero(seat).get("combat_scrap") == 2
			and party._heroes[seat - 1].get("combat_scrap") == 2,
			label + ": the Tinker's own record holds exactly two Combat Scrap")
		_check(party.get_hero(seat).get("block") == 0 and party.get_hero(seat).get("hp") == 26,
			label + ": the Tinker's Block and HP are untouched")
		for position: int in [1, 2, 3]:
			if position == seat:
				continue
			_check(not party.get_hero(position).has("combat_scrap"),
				label + ": seat " + str(position) + " gained no Combat Scrap")
			_check(party.get_hero(position).get("block") == 0,
				label + ": seat " + str(position) + " gained no Block")
		_check(_scrap_snapshot(deck, party)
			== _expected_scrap_screws(before, card_id, seat, cost),
			label + ": exact hand, piles, energy, turn, party, counter and RNG state")


## AC2: an empty supply is a legal zero draw, and a genuine discard refill can never draw the played
## copy back into its own hand. Both cases are replayed on the same seed for determinism.
func _test_scrap_draw_supply() -> void:
	var resolver := CombatTinkerV3ScrapSupportCards.new()

	# A one-card deck: the card is drawn at turn start, so the shared supply is genuinely empty.
	var empty_party := _scrap_party(2)
	var empty_deck := _scrap_deck([SCRAP_SCREWS], 551100, 0)
	_check(empty_deck.hand == [SCRAP_SCREWS],
		"empty-supply fixture really holds the card with no draw or discard left")
	_check(empty_deck.draw_pile.is_empty() and empty_deck.discard_pile.is_empty(),
		"empty-supply fixture really has empty piles")
	var empty_rng: int = empty_deck._rng.state
	var empty_result: Dictionary = resolver.play_card(empty_deck, empty_party, SCRAP_SCREWS)
	_check(empty_result.get("ok") == true and empty_result.get("drawn") == 0,
		"an empty shared supply is a legal zero draw")
	_check(empty_deck.energy == 2, "the empty-supply play still pays one energy")
	_check(empty_deck.hand.is_empty(), "the empty-supply play leaves nothing undrawn")
	_check(empty_deck.draw_pile.is_empty(), "the empty-supply play invents no draw pile")
	_check(empty_deck.discard_pile == [SCRAP_SCREWS],
		"the empty-supply play discards exactly the played copy")
	_check(empty_deck._rng.state == empty_rng, "the empty-supply play consumes no RNG")
	_check(empty_party.get_hero(2).get("combat_scrap") == 2,
		"the empty-supply play still gains its two Combat Scrap")

	# Empty draw pile with two genuine discards: the refill reshuffles them, and the still-held
	# played copy must not be swept into the reshuffle and drawn back.
	var refill_fixture: Dictionary = _scrap_refill_fixture(6622)
	_check(not refill_fixture.is_empty(), "refill fixture built")
	if refill_fixture.is_empty():
		return
	var refill_deck: CombatDeck = refill_fixture["deck"]
	var refill_party: CombatParty = refill_fixture["party"]
	_check(refill_deck.hand == [SCRAP_SCREWS_PLUS]
		and refill_deck.draw_pile.is_empty() and refill_deck.discard_pile.size() == 2,
		"refill fixture really leaves an empty draw pile and two discards")
	var refill_rng: int = refill_deck._rng.state
	var refill_result: Dictionary = resolver.play_card(refill_deck, refill_party,
		SCRAP_SCREWS_PLUS)
	_check(refill_result.get("ok") == true and refill_result.get("drawn") == 1,
		"the discard refill supplies exactly one shared draw")
	_check(not refill_deck.hand.has(SCRAP_SCREWS_PLUS),
		"the played copy cannot refill itself into its own draw")
	_check(refill_deck.hand.size() == 1
		and (refill_deck.hand[0] == "v3_scrap_refill_a"
			or refill_deck.hand[0] == "v3_scrap_refill_b"),
		"the single drawn card is one of the genuine discards")
	_check(refill_deck.draw_pile.size() == 1
		and (refill_deck.draw_pile[0] == "v3_scrap_refill_a"
			or refill_deck.draw_pile[0] == "v3_scrap_refill_b"),
		"the other genuine discard stays in the reshuffled draw pile")
	_check(refill_deck.discard_pile == [SCRAP_SCREWS_PLUS],
		"only the played copy reaches the discard after the draw")
	_check(refill_deck.hand.size() + refill_deck.draw_pile.size()
		+ refill_deck.discard_pile.size() == 3,
		"the refill case conserves all three cards")
	_check(refill_deck._rng.state != refill_rng,
		"the genuine reshuffle is drawn through the already-seeded RNG")
	_check(refill_deck.energy == 3, "the free Spare Screws+ refill play pays nothing")
	_check(refill_party.get_hero(3).get("combat_scrap") == 2,
		"the refill play gains its two Combat Scrap")
	_check(refill_party.get_hero(3).get("block") == 0,
		"the refill play grants no Block")

	# Same seed, same fixture: an identical replay of the refill draw.
	var replay_fixture: Dictionary = _scrap_refill_fixture(6622)
	_check(not replay_fixture.is_empty(), "replay fixture built")
	if replay_fixture.is_empty():
		return
	var replay_deck: CombatDeck = replay_fixture["deck"]
	var replay_party: CombatParty = replay_fixture["party"]
	var replay_result: Dictionary = resolver.play_card(replay_deck, replay_party,
		SCRAP_SCREWS_PLUS)
	_check(replay_result.get("ok") == true, "the replay refill play also succeeds")
	_check(_scrap_snapshot(replay_deck, replay_party)
		== _scrap_snapshot(refill_deck, refill_party),
		"the same seed replays the identical drawn card, piles, counters and RNG state")


## AC3: consecutive casts sum Combat Scrap on the Tinker only, teammates and the wallet are never
## touched, and a newly constructed party starts from zero instead of inheriting the counter.
func _test_scrap_accumulation_and_fresh_party() -> void:
	var resolver := CombatTinkerV3ScrapSupportCards.new()
	var party := _scrap_party(2)
	var deck := _scrap_deck([SCRAP_GEAR, SCRAP_SCREWS], 303100, 8)
	_check(deck.hand.has(SCRAP_GEAR) and deck.hand.has(SCRAP_SCREWS)
		and deck.energy == 3 and deck.draw_pile.size() >= 1,
		"accumulation fixture really holds both cards in a funded turn with a draw supply")
	var wallet := {"gold": 5, "scraps": 7}
	var wallet_before: Dictionary = wallet.duplicate(true)
	var rng_after_turn: int = deck._rng.state

	var first: Dictionary = resolver.play_card(deck, party, SCRAP_GEAR)
	_check(first.get("ok") == true and first.get("combat_scrap_after") == 1,
		"first cast gains one Combat Scrap")
	_check(party.get_hero(2).get("combat_scrap") == 1 and party.get_hero(2).get("block") == 5,
		"first cast leaves one Combat Scrap and five Block on the Tinker")
	_check(deck.energy == 2, "first cast pays one energy")
	_check(deck._rng.state == rng_after_turn,
		"first cast drew nothing and consumed no RNG")

	var second: Dictionary = resolver.play_card(deck, party, SCRAP_SCREWS)
	_check(second.get("ok") == true, "second cast is legal on the same party and turn")
	_check(second.get("combat_scrap_before") == 1
		and second.get("combat_scrap_gained") == 2
		and second.get("combat_scrap_after") == 3,
		"the second receipt reports the sequential sum")
	_check(party.get_hero(2).get("combat_scrap") == 3
		and party._heroes[1].get("combat_scrap") == 3,
		"Combat Scrap sums to three on the authoritative Tinker record")
	_check(deck.energy == 1 and deck.hand.count(SCRAP_GEAR) == 0
		and deck.hand.count(SCRAP_SCREWS) == 0,
		"both casts paid their printed energy and left the hand")
	_check(deck.discard_pile == [SCRAP_GEAR, SCRAP_SCREWS],
		"both played copies reached the discard in play order")
	_check(deck._rng.state == rng_after_turn,
		"drawing from the nonempty seeded supply consumed no RNG")
	for position: int in [1, 3]:
		_check(not party.get_hero(position).has("combat_scrap"),
			"teammate seat " + str(position) + " never gains Combat Scrap")
		_check(party.get_hero(position).get("block") == 0,
			"teammate seat " + str(position) + " never gains Block")
	_check(wallet == wallet_before, "the run wallet's scraps are never modified")

	# A newly constructed party begins without the optional counter, so nothing is inherited.
	var fresh := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "tinker", "max_hp": 26}, {"id": "seamstress", "max_hp": 30}])
	_check(fresh.is_valid() and fresh.get_hero(2).get("id") == "tinker",
		"fresh-party fixture really is a valid party with a Tinker")
	for position: int in [1, 2, 3]:
		_check(not fresh.get_hero(position).has("combat_scrap"),
			"fresh party seat " + str(position) + " has no stored Combat Scrap")
		_check(fresh.get_hero(position).get("combat_scrap", 0) == 0,
			"fresh party seat " + str(position) + " reads zero Combat Scrap")
	var fresh_deck := _scrap_deck([SCRAP_GEAR], 303101, 6)
	var fresh_result: Dictionary = resolver.play_card(fresh_deck, fresh, SCRAP_GEAR)
	_check(fresh_result.get("ok") == true and fresh_result.get("combat_scrap_before") == 0
		and fresh_result.get("combat_scrap_after") == 1,
		"a fresh party starts its own counter at zero, not the other party's three")
	_check(fresh.get_hero(2).get("combat_scrap") == 1 and party.get_hero(2).get("combat_scrap") == 3,
		"the fresh party's counter never leaks into or out of another party")

	# The same seeded replay yields the same sums and the same RNG state.
	var replay_party := _scrap_party(2)
	var replay_deck := _scrap_deck([SCRAP_GEAR, SCRAP_SCREWS], 303100, 8)
	_check(resolver.play_card(replay_deck, replay_party, SCRAP_GEAR).get("ok") == true,
		"replay first cast succeeds")
	_check(resolver.play_card(replay_deck, replay_party, SCRAP_SCREWS).get("ok") == true,
		"replay second cast succeeds")
	_check(_scrap_snapshot(replay_deck, replay_party) == _scrap_snapshot(deck, party),
		"the same seed replays the identical sequential counter outcome")


## AC4: every failed identity, turn, owner, seat, energy, held-copy, target or shape precondition
## is refused with its reason and mutates no deck, party, counter or RNG state.
func _test_scrap_refusals() -> void:
	var resolver := CombatTinkerV3ScrapSupportCards.new()
	var party := _scrap_party(2)
	var deck := _scrap_deck([SCRAP_GEAR], 304100, 6)

	_rejected_scrap(resolver, null, party, SCRAP_GEAR, 0, "invalid_request", "null deck")
	_rejected_scrap(resolver, deck, null, SCRAP_GEAR, 0, "invalid_request", "null party")

	# An inactive turn is never paid, even with a real copy in hand.
	var inactive := CombatDeck.new([SCRAP_GEAR], _scrap_rng(304101))
	inactive.hand.append(SCRAP_GEAR)
	_check(not inactive.turn_active and inactive.hand.has(SCRAP_GEAR),
		"inactive fixture really holds a copy outside a turn")
	_rejected_scrap(resolver, inactive, party, SCRAP_GEAR, 0, "inactive_turn", "inactive turn")

	# Unsupported card identities: other authentic Tinker cards, v2 cards, forged spellings and
	# non-strings.
	var wrong_ids: Array = ["tinker_v3_brass_casing", "tinker_v3_brass_casing_plus",
		"tinker_v3_spring_clamp", "tinker_v3_overload", "tinker_v3_wind_up_turret",
		"tinker_spare_parts", "tinker_v3_gear_brace+", "tinker_v3_gear_brace_plus_plus",
		"tinker_v3_spare_screws_+", "gear_brace", "TINKER_V3_GEAR_BRACE", "",
		StringName(SCRAP_GEAR), null, 0, 3.5, false, [], {}]
	for wrong_id: Variant in wrong_ids:
		_rejected_scrap(resolver, deck, party, wrong_id, 0, "unsupported_card",
			"unsupported ID " + str(wrong_id))
	# An authentic scrap support the hand does not hold is still unheld.
	_rejected_scrap(resolver, deck, party, SCRAP_SCREWS, 0, "card_not_held",
		"authentic but unheld Spare Screws")
	_rejected_scrap(resolver, deck, party, SCRAP_GEAR_PLUS, 0, "card_not_held",
		"authentic but unheld Gear Brace+")

	# An unaffordable copy is refused without a partial charge.
	var poor := _scrap_deck([SCRAP_GEAR], 304102, 6)
	poor.combat_state.energy = 0
	_check(poor.energy == 0 and poor.hand.has(SCRAP_GEAR),
		"short-energy fixture really holds a copy with no energy")
	_rejected_scrap(resolver, poor, party, SCRAP_GEAR, 0, "insufficient_energy", "no energy")
	# Spare Screws+ prints zero and stays legal without energy.
	var free_party := _scrap_party(2)
	var free_deck := _scrap_deck([SCRAP_SCREWS_PLUS], 304103, 5)
	free_deck.combat_state.energy = 0
	var free_result: Dictionary = resolver.play_card(free_deck, free_party, SCRAP_SCREWS_PLUS)
	_check(free_result.get("ok") == true and free_deck.energy == 0,
		"Spare Screws+ is legal at zero energy and pays nothing")
	_check(free_party.get_hero(2).get("combat_scrap") == 2,
		"the zero-cost play still gains its two Combat Scrap")

	# A party without Tinker never authorizes the play.
	var absent_owner := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "yarn_ranger", "max_hp": 28}])
	_check(absent_owner.is_valid() and absent_owner.get_hero(2).get("id") == "seamstress",
		"absent-owner fixture is a valid party without a Tinker")
	_rejected_scrap(resolver, deck, absent_owner, SCRAP_GEAR, 0, "owner_missing",
		"absent Tinker")

	# A second Tinker identity is a malformed roster, never a second owner.
	var duplicate := _scrap_party(2)
	duplicate._heroes[0]["id"] = "tinker"
	_check(duplicate.get_hero(1).get("id") == "tinker"
		and duplicate.get_hero(2).get("id") == "tinker",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected_scrap(resolver, deck, duplicate, SCRAP_GEAR, 0, "invalid_party",
		"duplicate Tinker identity")

	# A torn (downed) owner may not play.
	var torn_owner := _scrap_party(3)
	_check(torn_owner.apply_damage(3, 26) and torn_owner.is_downed(3),
		"torn-owner fixture really has a downed Tinker")
	_rejected_scrap(resolver, deck, torn_owner, SCRAP_GEAR, 0, "owner_downed", "downed Tinker")

	# Spare Screws prints FROM seats 2-3: the front seat is not a legal owner.
	var front_party := _scrap_party(1)
	var front_deck := _scrap_deck([SCRAP_SCREWS], 304104, 5)
	_rejected_scrap(resolver, front_deck, front_party, SCRAP_SCREWS, 0,
		"owner_illegal_position", "Spare Screws from seat 1")
	var front_plus_deck := _scrap_deck([SCRAP_SCREWS_PLUS], 304105, 5)
	_rejected_scrap(resolver, front_plus_deck, front_party, SCRAP_SCREWS_PLUS, 0,
		"owner_illegal_position", "Spare Screws+ from seat 1")

	# These cards print target_kind self: every nonzero recipient slot is an invalid request.
	for slot: int in [1, 2, 3, 4, -1, 99]:
		_rejected_scrap(resolver, deck, party, SCRAP_GEAR, slot, "invalid_target",
			"illegal target slot " + str(slot))

	# Block and counter capacity are proven before any payment.
	var block_overflow := _scrap_party(2)
	block_overflow._heroes[1]["block"] = CombatParty.MAX_INT - 1
	_check(block_overflow.get_hero(2).get("block") == CombatParty.MAX_INT - 1,
		"Block-overflow fixture really sits one Block below the integer limit")
	_rejected_scrap(resolver, deck, block_overflow, SCRAP_GEAR, 0, "block_overflow",
		"Block overflow")
	var counter_overflow := _scrap_party(2)
	counter_overflow._heroes[1]["combat_scrap"] = CombatParty.MAX_INT
	_rejected_scrap(resolver, deck, counter_overflow, SCRAP_GEAR, 0,
		"combat_scrap_overflow", "Combat Scrap overflow")

	# A malformed stored counter is never coerced into a legal number.
	var text_counter := _scrap_party(2)
	text_counter._heroes[1]["combat_scrap"] = "3"
	_rejected_scrap(resolver, deck, text_counter, SCRAP_GEAR, 0, "malformed_combat_scrap",
		"string Combat Scrap")
	var negative_counter := _scrap_party(2)
	negative_counter._heroes[1]["combat_scrap"] = -1
	_rejected_scrap(resolver, deck, negative_counter, SCRAP_GEAR, 0,
		"malformed_combat_scrap", "negative Combat Scrap")
	var float_counter := _scrap_party(2)
	float_counter._heroes[1]["combat_scrap"] = 1.0
	_rejected_scrap(resolver, deck, float_counter, SCRAP_GEAR, 0, "malformed_combat_scrap",
		"float Combat Scrap")

	# Invalid or malformed rosters fail closed.
	var short_party := CombatParty.new([{"id": "tinker", "max_hp": 26}])
	_rejected_scrap(resolver, deck, short_party, SCRAP_GEAR, 0, "invalid_party",
		"invalid one-hero party")
	var bad_hp := _scrap_party(2)
	bad_hp._heroes[0]["hp"] = 999
	_rejected_scrap(resolver, deck, bad_hp, SCRAP_GEAR, 0, "invalid_party", "malformed hero HP")
	var bad_block := _scrap_party(2)
	bad_block._heroes[0]["block"] = -1
	_rejected_scrap(resolver, deck, bad_block, SCRAP_GEAR, 0, "invalid_party",
		"malformed hero Block")
	var bad_position := _scrap_party(2)
	bad_position._heroes[0]["position"] = 3
	_rejected_scrap(resolver, deck, bad_position, SCRAP_GEAR, 0, "invalid_party",
		"malformed hero slot index")
	var bad_identity := _scrap_party(2)
	bad_identity._heroes[0]["id"] = ""
	_rejected_scrap(resolver, deck, bad_identity, SCRAP_GEAR, 0, "invalid_party",
		"empty hero identity")

	# A consumed copy cannot be played twice.
	var repeat_party := _scrap_party(3)
	var repeat_deck := _scrap_deck([SCRAP_SCREWS_PLUS], 304106, 5)
	_check(resolver.play_card(repeat_deck, repeat_party, SCRAP_SCREWS_PLUS).get("ok") == true,
		"duplicate-play fixture really casts once")
	_check(repeat_deck.energy == 3 and repeat_deck.discard_pile == [SCRAP_SCREWS_PLUS],
		"duplicate-play fixture really paid nothing and discarded the copy")
	_rejected_scrap(resolver, repeat_deck, repeat_party, SCRAP_SCREWS_PLUS, 0,
		"card_not_held", "duplicate play of the consumed copy")

	# A refused attempt never poisons the next authentic play on the same objects.
	var retry_deck := _scrap_deck([SCRAP_GEAR_PLUS], 304107, 6)
	var retry_party := _scrap_party(1)
	_rejected_scrap(resolver, retry_deck, retry_party, SCRAP_GEAR, 0, "card_not_held",
		"retry: authentic but unheld first")
	_rejected_scrap(resolver, retry_deck, retry_party, SCRAP_GEAR_PLUS, 2, "invalid_target",
		"retry: illegal target second")
	var retry_result: Dictionary = resolver.play_card(retry_deck, retry_party, SCRAP_GEAR_PLUS, 0)
	_check(retry_result.get("ok") == true and retry_deck.energy == 2
		and retry_party.get_hero(1).get("block") == 7
		and retry_party.get_hero(1).get("combat_scrap") == 1,
		"retry: the authentic play then succeeds exactly once")

	# The shared fixture deck survived every refusal untouched.
	_check(deck.energy == 3 and deck.hand.has(SCRAP_GEAR) and deck.discard_pile.is_empty()
		and party.get_hero(2).get("block") == 0
		and not party.get_hero(2).has("combat_scrap"),
		"every refusal left the shared fixture deck and party untouched")


func _scrap_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real three-hero party (distinct IDs) with the living Tinker in the named seat. A fresh
## CombatParty never carries the optional combat_scrap key.
func _scrap_party(tinker_position: int) -> CombatParty:
	var roster: Array = []
	var others: Array[String] = ["warden", "seamstress"]
	var next_other := 0
	for index in range(3):
		if index + 1 == tinker_position:
			roster.append({"id": "tinker", "max_hp": 26})
		else:
			roster.append({"id": others[next_other], "max_hp": 40 - next_other * 6})
			next_other += 1
	var party := CombatParty.new(roster)
	_check(party.is_valid() and party.get_hero(tinker_position).get("id") == "tinker"
		and party.get_hero(tinker_position).get("hp") == 26,
		"valid three-hero party with a living Tinker in seat " + str(tinker_position))
	_check(not party.get_hero(tinker_position).has("combat_scrap")
		and party.get_hero(tinker_position).get("combat_scrap", 0) == 0,
		"a real fresh party begins at zero Combat Scrap in seat " + str(tinker_position))
	return party


## A genuine seeded CombatDeck already in a real turn, guaranteed to hold one or more copies of
## each named card while keeping `supply` further filler cards in the shared draw pile. Swaps only
## move real cards between the real hand and the real draw pile.
func _scrap_deck(held_ids: Array, seed_value: int, supply: int) -> CombatDeck:
	var ids: Array[String] = []
	for card_id in held_ids:
		ids.append(str(card_id))
	for index in range(supply):
		ids.append("v3_scrap_filler_" + str(index))
	var deck := CombatDeck.new(ids, _scrap_rng(seed_value))
	_check(deck.start_turn() and deck.energy == 3,
		"fixture starts a real three-energy shared turn for " + str(held_ids))
	var hand_slot := 0
	for card_id: String in held_ids:
		if deck.hand.has(card_id):
			continue
		var source: int = deck.draw_pile.find(card_id)
		if source < 0:
			continue
		while hand_slot < deck.hand.size() and deck.hand[hand_slot] in held_ids:
			hand_slot += 1
		if hand_slot >= deck.hand.size():
			continue
		var swap: String = deck.hand[hand_slot]
		deck.draw_pile[source] = swap
		deck.hand[hand_slot] = card_id
		hand_slot += 1
	for card_id: String in held_ids:
		_check(deck.hand.has(card_id), "fixture hand really holds " + card_id)
	_check(deck.discard_pile.is_empty(), "fixture discard starts empty")
	return deck


## Empty draw pile with two genuine discards behind a held zero-cost Spare Screws+.
func _scrap_refill_fixture(seed_value: int) -> Dictionary:
	var deck := CombatDeck.new([SCRAP_SCREWS_PLUS, "v3_scrap_refill_a",
		"v3_scrap_refill_b"], _scrap_rng(seed_value))
	if not deck.start_turn():
		return {}
	deck.hand.clear()
	deck.hand.append(SCRAP_SCREWS_PLUS)
	deck.discard_pile.append("v3_scrap_refill_a")
	deck.discard_pile.append("v3_scrap_refill_b")
	return {"deck": deck, "party": _scrap_party(3)}


func _scrap_snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
	var snapshot: Dictionary = {
		"deck_present": deck != null, "party_present": party != null
	}
	if deck != null:
		snapshot["turn"] = deck.turn_active
		snapshot["energy"] = deck.energy
		snapshot["state_energy"] = deck.combat_state.energy
		snapshot["state_turn"] = deck.combat_state.player_turn_active
		snapshot["hand"] = deck.hand.duplicate()
		snapshot["draw"] = deck.draw_pile.duplicate()
		snapshot["discard"] = deck.discard_pile.duplicate()
		snapshot["rng_state"] = deck._rng.state if deck._rng != null else -1
	if party != null:
		snapshot["party"] = party.get_heroes()
		snapshot["party_valid"] = party.is_valid()
	return snapshot


## The exact Gear Brace outcome: one energy, the held copy moved to discard, the printed Block on
## the owner's record and one more Combat Scrap on that same hero only.
func _expected_scrap_gear(before: Dictionary, card_id: String, seat: int,
		block: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - 1
	expected["state_energy"] = int(expected["state_energy"]) - 1
	var hand: Array = expected["hand"]
	_check(hand.count(card_id) == 1, "expected snapshot: exactly one played copy is held")
	hand.remove_at(hand.find(card_id))
	(expected["discard"] as Array).append(card_id)
	var hero: Dictionary = expected["party"][seat - 1]
	hero["block"] = int(hero["block"]) + block
	hero["combat_scrap"] = int(hero.get("combat_scrap", 0)) + 1
	return expected


## The exact Spare Screws outcome: the printed cost, one real shared draw (when available), the
## held copy moved to discard and two more Combat Scrap on the owner only.
func _expected_scrap_screws(before: Dictionary, card_id: String, seat: int,
		cost: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - cost
	expected["state_energy"] = int(expected["state_energy"]) - cost
	var hand: Array = expected["hand"]
	_check(hand.count(card_id) == 1, "expected snapshot: exactly one played copy is held")
	hand.remove_at(hand.find(card_id))
	var draw: Array = expected["draw"]
	if not draw.is_empty():
		hand.append(draw.pop_back())
	(expected["discard"] as Array).append(card_id)
	var hero: Dictionary = expected["party"][seat - 1]
	hero["combat_scrap"] = int(hero.get("combat_scrap", 0)) + 2
	return expected


func _rejected_scrap(resolver: CombatTinkerV3ScrapSupportCards, deck: CombatDeck,
		party: CombatParty, card_id: Variant, target: int, reason: String,
		label: String) -> void:
	var before := _scrap_snapshot(deck, party)
	var result: Dictionary = resolver.play_card(deck, party, card_id, target)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(result.get("reason")) + ")")
	_check(_scrap_snapshot(deck, party) == before,
		label + ": unchanged energy, hand, piles, turn, party, counters and RNG")
