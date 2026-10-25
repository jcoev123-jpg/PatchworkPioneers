extends SceneTree
## Deterministic headless test for the standalone V3TinkerPoolCards catalog (V3-1).
## Verifies the eight authored v3 Tinker base cards and their eight '+' upgrades field by field,
## deep-copy isolation, fail-closed lookups, base-only reward candidates, no RNG consumption and
## that the existing v2 Tinker pool and starter definitions are untouched. The v3 catalog is
## deliberately NOT wired into combat, rewards, the map or shops yet, so nothing here drives a
## live card; the effect dictionaries are declarative data for the later integration task.


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
