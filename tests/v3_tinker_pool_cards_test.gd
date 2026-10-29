extends SceneTree
## Deterministic headless test for the standalone V3TinkerPoolCards catalog (V3-1).
## Verifies the eight authored v3 Tinker base cards and their eight '+' upgrades field by field,
## deep-copy isolation, fail-closed lookups, base-only reward candidates, no RNG consumption and
## that the existing v2 Tinker pool and starter definitions are untouched. The v3 catalog is
## deliberately NOT wired into the mounted hand, rewards, the map or shops yet, so the plain catalog
## checks below never drive a live card through the UI; most effect dictionaries remain declarative data
## for later integration tasks. The one effect that is now callable rules-layer behaviour is Wind-up
## Turret's: CombatTinkerV3TurretCards resolves its paid deployment and its detached three end-of-player-
## turn ticks (see the turret sections at the end of this file). Admitting the two turret IDs to the live
## hand, keeping battle-local pending instances and ticking them on the real end-turn path is still a later,
## separately owned wiring task, so no case here claims live player availability.
##
## Extended with deterministic headless combat resolution for the four paid Combat Scrap support
## cards (Gear Brace and Spare Screws, base and '+') through CombatTinkerV3ScrapSupportCards:
## printed energy, held-copy proof, self Block, the Tinker-only combat_scrap counter, the real
## seeded shared draw and inert refusals.
##
## Extended again with the paid Overload / Overload+ resolver (CombatTinkerV3OverloadCards): the
## printed 2 + 3 / 3 + 4 per-Combat-Scrap raw damage, spending the whole counter, enemy Block before
## HP, and fail-closed preflight.

const CombatDeck = preload("res://scripts/combat_deck.gd")
const CombatParty = preload("res://scripts/combat_party.gd")
const CombatEnemies = preload("res://scripts/combat_enemies.gd")
const CombatTinkerV3ScrapSupportCards = preload(
	"res://scripts/combat_tinker_v3_scrap_support_cards.gd")
const CombatTinkerV3OverloadCards = preload(
	"res://scripts/combat_tinker_v3_overload_cards.gd")
const CombatTinkerV3TurretCards = preload(
	"res://scripts/combat_tinker_v3_turret_cards.gd")
const CombatTinkerV3CasingClampCards = preload(
	"res://scripts/combat_tinker_v3_casing_clamp_cards.gd")

const SCRAP_GEAR := "tinker_v3_gear_brace"
const SCRAP_GEAR_PLUS := "tinker_v3_gear_brace_plus"
const SCRAP_SCREWS := "tinker_v3_spare_screws"
const SCRAP_SCREWS_PLUS := "tinker_v3_spare_screws_plus"
const SCRAP_IDS: Array[String] = [SCRAP_GEAR, SCRAP_GEAR_PLUS, SCRAP_SCREWS, SCRAP_SCREWS_PLUS]

const OVERLOAD := "tinker_v3_overload"
const OVERLOAD_PLUS := "tinker_v3_overload_plus"
const OVERLOAD_IDS: Array[String] = [OVERLOAD, OVERLOAD_PLUS]

const TURRET := "tinker_v3_wind_up_turret"
const TURRET_PLUS := "tinker_v3_wind_up_turret_plus"
const TURRET_IDS: Array[String] = [TURRET, TURRET_PLUS]

const CASING := "tinker_v3_brass_casing"
const CASING_PLUS := "tinker_v3_brass_casing_plus"
const CLAMP := "tinker_v3_spring_clamp"
const CLAMP_PLUS := "tinker_v3_spring_clamp_plus"
const CASING_CLAMP_IDS: Array[String] = [CASING, CASING_PLUS, CLAMP, CLAMP_PLUS]
## The detached pending instance's complete, closed key set (independent of the resolver's own constant).
const TURRET_STATE_KEYS: Array[String] = ["kind", "card_id", "damage", "duration_turns",
	"remaining", "tick", "target_kind", "living_targets_only", "rng_source"]

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
	_test_overload_catalog_contract()
	_test_overload_paid_plays()
	_test_overload_refusals()
	_test_turret_catalog_contract()
	_test_turret_deployments()
	_test_turret_ticks()
	_test_turret_refusals()
	_test_turret_enrage()
	_test_casing_clamp_catalog_contract()
	_test_casing_clamp_paid_plays()
	_test_casing_clamp_second_copy()
	_test_casing_clamp_refusals()
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


## Independent expected raw damage for the two Overload printings: {base, per scrap, exact totals}.
func _overload_table(card_id: String) -> Dictionary:
	if card_id == OVERLOAD:
		return {"base": 2, "per": 3, "scrap": {0: 2, 1: 5, 3: 11}}
	return {"base": 3, "per": 4, "scrap": {0: 3, 1: 7, 3: 15}}


## AC1: the resolver authenticates exactly the authored Overload pair and nothing else.
func _test_overload_catalog_contract() -> void:
	var catalog := V3TinkerPoolCards.new()
	var resolver := CombatTinkerV3OverloadCards.new()
	var expected := {
		OVERLOAD: {
			"display": "Overload", "cost": 1, "from": [2, 3], "kind": "enemy_single",
			"to": [1, 2, 3], "is_upgrade": false,
			"effects": {"damage": 2, "damage_per_combat_scrap": 3,
				"consume_all_combat_scrap": true},
		},
		OVERLOAD_PLUS: {
			"display": "Overload+", "cost": 1, "from": [2, 3], "kind": "enemy_single",
			"to": [1, 2, 3], "is_upgrade": true,
			"effects": {"damage": 3, "damage_per_combat_scrap": 4,
				"consume_all_combat_scrap": true},
		},
	}
	# Independent arithmetic (fixed totals, not a formula copied from the resolver).
	var base_table := _overload_table(OVERLOAD)
	var plus_table := _overload_table(OVERLOAD_PLUS)
	_check(base_table["scrap"] == {0: 2, 1: 5, 3: 11},
		"Overload totals are 2 / 5 / 11 at 0 / 1 / 3 Combat Scrap")
	_check(plus_table["scrap"] == {0: 3, 1: 7, 3: 15},
		"Overload+ totals are 3 / 7 / 15 at 0 / 1 / 3 Combat Scrap")

	for card_id: String in OVERLOAD_IDS:
		var row: Dictionary = expected[card_id]
		var record: Dictionary = catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + " is authored in the v3 Tinker catalog")
		if record.is_empty():
			continue
		_check(record.get("display_name") == row["display"], card_id + " display name")
		_check(record.get("owner") == "tinker", card_id + " is owned by Tinker")
		_check(record.get("cost") == row["cost"], card_id + " prints cost 1")
		_check(record.get("from_positions") == row["from"], card_id + " prints FROM 2-3")
		_check(record.get("target_kind") == row["kind"], card_id + " targets one enemy")
		_check(record.get("to_positions") == row["to"], card_id + " prints TO 1-3")
		_check(record.get("effects") == row["effects"], card_id + " prints its exact effects")
		_check(not record.get("effects", {}).has("scraps")
			and not record.get("effects", {}).has("scrap_cost"),
			card_id + " never reads or spends wallet scraps")
		_check(not record.has("upgrade_of"), card_id + " links with base_id/upgrade_id/is_upgrade")
		_check(record.get("base_id") == OVERLOAD
			and record.get("upgrade_id") == OVERLOAD_PLUS
			and record.get("is_upgrade") == row["is_upgrade"],
			card_id + " preserves the base/+ link")
		_check(resolver.is_supported_card(card_id), card_id + " is a supported Overload card")
		_check(CombatTinkerV3OverloadCards.is_authentic_definition(record, card_id),
			card_id + " passes the definition authenticator")
		_check(CombatTinkerV3OverloadCards.overload_definition(card_id) == record,
			card_id + " resolves to its exact detached catalog record")

	# Detached: mutating a resolved record cannot rewrite what the next resolution returns.
	var sample: Dictionary = CombatTinkerV3OverloadCards.overload_definition(OVERLOAD)
	_check(not sample.is_empty(), "overload resolution fixture loaded")
	if not sample.is_empty():
		sample["effects"]["damage"] = 900
		sample["effects"]["damage_per_combat_scrap"] = 90
		sample["from_positions"].clear()
		sample["cost"] = 0
		_check(CombatTinkerV3OverloadCards.overload_definition(OVERLOAD)
			== catalog.get_definition(OVERLOAD),
			"a mutated Overload definition cannot poison later resolutions")

	# Every other v3 Tinker card (base and plus) is unrelated to this service.
	var unrelated: Array[String] = []
	for base_id in catalog.get_pool_card_ids():
		if not OVERLOAD_IDS.has(base_id):
			unrelated.append(base_id)
		var upgrade_id: String = catalog.get_upgrade_id(base_id)
		if not upgrade_id.is_empty() and not OVERLOAD_IDS.has(upgrade_id):
			unrelated.append(upgrade_id)
	_check(unrelated.has("tinker_v3_brass_casing") and unrelated.has("tinker_v3_scrapstorm_plus"),
		"unrelated-card fixture really contains other authentic v3 Tinker cards (precondition)")
	for other_id: String in unrelated:
		_check(CombatTinkerV3OverloadCards.overload_definition(other_id).is_empty(),
			other_id + " does not resolve as Overload")
		_check(not resolver.is_supported_card(other_id),
			other_id + " is not a supported Overload card")

	# The v2 Tinker pool and foreign spellings are never Overload.
	var forged: Array = ["tinker_spare_parts", "tinker_overclock", "tinker_v3_overload+",
		"tinker_v3_overload_plus_plus", "tinker_v3_overload_", "overload",
		"TINKER_V3_OVERLOAD", "", "tinker_v3_missing_card", StringName(OVERLOAD),
		null, 0, 3.5, false, [], {}]
	for other_id: Variant in forged:
		_check(CombatTinkerV3OverloadCards.overload_definition(other_id).is_empty(),
			"forged or non-string ID never resolves as Overload: " + str(other_id))
		_check(not resolver.is_supported_card(other_id),
			"forged or non-string ID is never a supported Overload: " + str(other_id))

	# Adversarial copies of the real Overload record: each altered contract field is refused.
	var base_record: Dictionary = catalog.get_definition(OVERLOAD)
	_check(not base_record.is_empty()
		and CombatTinkerV3OverloadCards.is_authentic_definition(base_record, OVERLOAD),
		"authenticator positive fixture really is the authored Overload")
	var mutations: Array[Callable] = [
		func(record: Dictionary) -> void: record["effects"]["damage"] = 5,
		func(record: Dictionary) -> void: record["effects"]["damage"] = 2.0,
		func(record: Dictionary) -> void: record["effects"]["damage_per_combat_scrap"] = 4,
		func(record: Dictionary) -> void: record["effects"]["damage_per_combat_scrap"] = "3",
		func(record: Dictionary) -> void: record["effects"]["consume_all_combat_scrap"] = false,
		func(record: Dictionary) -> void: record["effects"]["consume_all_combat_scrap"] = 1,
		func(record: Dictionary) -> void: record["effects"].erase("consume_all_combat_scrap"),
		func(record: Dictionary) -> void: record["effects"]["scraps"] = 1,
		func(record: Dictionary) -> void: record["cost"] = 0,
		func(record: Dictionary) -> void: record["cost"] = 1.0,
		func(record: Dictionary) -> void: record["owner"] = "warden",
		func(record: Dictionary) -> void: record["from_positions"] = [1, 2, 3],
		func(record: Dictionary) -> void: record["to_positions"] = [],
		func(record: Dictionary) -> void: record["target_kind"] = "self",
		func(record: Dictionary) -> void: record["is_upgrade"] = true,
		func(record: Dictionary) -> void: record["upgrade_of"] = OVERLOAD,
		func(record: Dictionary) -> void: record.erase("upgrade_id"),
		func(record: Dictionary) -> void: record.erase("effects"),
	]
	for index in range(mutations.size()):
		var tampered: Dictionary = base_record.duplicate(true)
		mutations[index].call(tampered)
		_check(not CombatTinkerV3OverloadCards.is_authentic_definition(tampered, OVERLOAD),
			"tampered Overload record " + str(index) + " is refused")
	_check(not CombatTinkerV3OverloadCards.is_authentic_definition(
		catalog.get_definition(OVERLOAD_PLUS), OVERLOAD),
		"an upgraded record cannot authenticate as its base ID")
	_check(not CombatTinkerV3OverloadCards.is_authentic_definition(
		catalog.get_definition(OVERLOAD), OVERLOAD_PLUS),
		"a base record cannot authenticate as its upgraded ID")


## AC2: one real held play pays 1, spends the whole Tinker-only counter, discards exactly one copy
## and lands the printed raw damage through enemy Block before HP, at 0 / 1 / 3 Combat Scrap.
func _test_overload_paid_plays() -> void:
	var resolver := CombatTinkerV3OverloadCards.new()
	var seed_value := 401000
	for card_id: String in OVERLOAD_IDS:
		var table := _overload_table(card_id)
		for scrap: int in [0, 1, 3]:
			var raw: int = table["scrap"][scrap]
			_check(raw == table["base"] + table["per"] * scrap,
				card_id + " independently computes " + str(raw) + " at " + str(scrap) + " scrap")
			var seat := 3 if scrap == 1 else 2
			var label := card_id + " from seat " + str(seat) + " with " + str(scrap) + " scrap"
			# A Block recipient: 20 Block absorbs the whole raw hit, so no HP is lost.
			_overload_case(resolver, card_id, seat, scrap, 1, 20, 24, seed_value, label + ", blocked")
			seed_value += 1
			# An HP-loss recipient: only 1 Block, so the rest reaches HP.
			_overload_case(resolver, card_id, seat, scrap, 2, 1, 24, seed_value,
				label + ", partial Block")
			seed_value += 1
		# HP cap: a frail elf cannot lose more HP than it has.
		_overload_case(resolver, card_id, 3, 3, 2, 0, 6, seed_value, card_id + " HP cap")
		seed_value += 1

	# A fresh party has no stored counter at all: absent reads as zero, and the confirmed play still
	# spends it (writing an explicit zero on the Tinker's own record).
	var fresh_party := _scrap_party(2)
	_check(not fresh_party.get_hero(2).has("combat_scrap"),
		"absent-counter fixture really has no stored Combat Scrap")
	var fresh_deck := _scrap_deck([OVERLOAD], 409900, 5)
	var fresh_enemies := _overload_enemies()
	var fresh_result: Dictionary = resolver.play_card(fresh_deck, fresh_party, fresh_enemies,
		OVERLOAD, 1)
	_check(fresh_result.get("ok") == true and fresh_result.get("raw_damage") == 2
		and fresh_result.get("combat_scrap_before") == 0
		and fresh_result.get("combat_scrap_spent") == 0
		and fresh_result.get("combat_scrap_after") == 0,
		"an absent counter plays as zero and spends an explicit zero")
	_check(fresh_party.get_hero(2).get("combat_scrap") == 0
		and fresh_enemies.get_enemy(1).get("hp") == 28,
		"the absent-counter play deals its printed 2 damage and stores a spent zero")


## One funded Overload transaction on real fixtures, plus an identical same-seed replay.
func _overload_case(resolver: CombatTinkerV3OverloadCards, card_id: String, seat: int,
		scrap: int, target: int, target_blocks: int, second_max_hp: int, seed_value: int,
		label: String) -> void:
	var table := _overload_table(card_id)
	var raw: int = table["scrap"][scrap]
	var party := _overload_party(seat, scrap)
	var deck := _scrap_deck([card_id], seed_value, 5)
	var enemies := _overload_enemies(second_max_hp)
	_check(enemies.gain_block(target, target_blocks),
		label + ": the fixture really grants the chosen enemy Block")
	var enemy_before: Dictionary = enemies.get_enemy(target)
	var block_absorbed: int = mini(int(enemy_before["block"]), raw)
	var hp_loss: int = mini(int(enemy_before["hp"]), raw - block_absorbed)
	if target_blocks >= raw:
		_check(block_absorbed == raw and hp_loss == 0,
			label + ": the Block fixture really absorbs the whole raw hit")
	else:
		_check(block_absorbed == int(enemy_before["block"]) and hp_loss > 0,
			label + ": the Block fixture really lets HP loss through")
	var wallet := {"gold": 9, "scraps": 4}
	var wallet_before: Dictionary = wallet.duplicate(true)
	var rng_before: int = deck._rng.state
	var before := _battle_snapshot(deck, party, enemies)
	# The pure preflight accepts the same request and changes nothing.
	var plan: Dictionary = resolver.preflight(deck, party, enemies, card_id, target)
	_check(plan.get("ok") == true and plan.get("reason") == "legal",
		label + ": read-only preflight accepts the funded play")
	_check(plan.get("raw_damage") == raw and plan.get("combat_scrap_before") == scrap,
		label + ": preflight reports the independent raw damage and the counter")
	_check(_battle_snapshot(deck, party, enemies) == before,
		label + ": preflight changed no battle state")
	var result: Dictionary = resolver.play_card(deck, party, enemies, card_id, target)
	_check(result.get("ok") == true and result.get("reason") == "applied",
		label + ": authorized paid play")
	_check(result.get("card_id") == card_id and result.get("cost") == 1,
		label + ": receipt names the authentic card and its one energy")
	_check(result.get("owner_position") == seat and result.get("target_position") == target,
		label + ": receipt reports the real owner seat and the chosen enemy")
	_check(result.get("combat_scrap_before") == scrap and result.get("combat_scrap_spent") == scrap
		and result.get("combat_scrap_after") == 0,
		label + ": receipt reports every held Combat Scrap spent")
	_check(result.get("base_damage") == table["base"]
		and result.get("damage_per_combat_scrap") == table["per"]
		and result.get("damage_from_combat_scrap") == table["per"] * scrap,
		label + ": receipt reports the printed base and per-scrap arithmetic")
	_check(result.get("raw_damage") == raw and result.get("damage") == raw,
		label + ": exactly " + str(raw) + " raw damage before any modifier")
	_check(result.get("block_absorbed") == block_absorbed and result.get("hp_loss") == hp_loss,
		label + ": Block absorbed " + str(block_absorbed) + " before " + str(hp_loss) + " HP")
	_check(result.get("energy_before") == 3 and result.get("energy_after") == 2,
		label + ": receipt reports the exact energy change")
	_check(not result.has("scraps") and not result.has("wallet"),
		label + ": receipt carries no wallet state")
	_check(deck.energy == 2, label + ": exactly one energy was paid")
	_check(deck.hand.count(card_id) == 0 and deck.discard_pile == [card_id],
		label + ": exactly the held copy reached the discard")
	_check(deck._rng.state == rng_before, label + ": no RNG was consumed")
	_check(party.get_hero(seat).get("combat_scrap") == 0
		and party._heroes[seat - 1].get("combat_scrap") == 0,
		label + ": the Tinker's whole counter is spent on his own record")
	for position: int in [1, 2, 3]:
		if position == seat:
			continue
		_check(party.get_hero(position).get("combat_scrap") == 2,
			label + ": teammate seat " + str(position) + " keeps its own counter")
	_check(party.get_hero(seat).get("hp") == 26 and party.get_hero(seat).get("block") == 0,
		label + ": the Tinker's HP and Block are untouched")
	_check(wallet == wallet_before, label + ": the run wallet's scraps are never modified")
	_check(enemies.get_enemy(target).get("hp") == int(enemy_before["hp"]) - hp_loss
		and enemies.get_enemy(target).get("block") == int(enemy_before["block"]) - block_absorbed,
		label + ": only the chosen enemy's Block and HP changed")
	for position: int in range(1, enemies.get_enemies().size() + 1):
		if position == target:
			continue
		_check(enemies.get_enemy(position).get("hp")
			== before["enemies"][position - 1].get("hp"),
			label + ": enemy " + str(position) + " was not hit")
	_check(_battle_snapshot(deck, party, enemies)
		== _expected_overload(before, card_id, seat, target, scrap, raw),
		label + ": exact hand, piles, energy, turn, party, counters, enemy and RNG state")

	# The consumed copy cannot be claimed a second time (aim at a living slot so only the held copy
	# stands between the request and a second hit).
	var after := _battle_snapshot(deck, party, enemies)
	var replay_target: int = target if int(enemies.get_enemy(target)["hp"]) > 0 else (2 if target == 1 else 1)
	var replay: Dictionary = resolver.play_card(deck, party, enemies, card_id, replay_target)
	_check(replay.get("ok") == false and replay.get("reason") == "card_not_held",
		label + ": a second claim of the consumed copy is refused")
	_check(_battle_snapshot(deck, party, enemies) == after,
		label + ": the refused replay changed nothing")

	# Same seed, same fixtures: an identical replay of the whole transaction.
	var replay_party := _overload_party(seat, scrap)
	var replay_deck := _scrap_deck([card_id], seed_value, 5)
	var replay_enemies := _overload_enemies(second_max_hp)
	_check(replay_enemies.gain_block(target, target_blocks), label + ": replay fixture Block")
	var replay_result: Dictionary = resolver.play_card(replay_deck, replay_party, replay_enemies,
		card_id, target)
	_check(replay_result == result, label + ": the same seed replays the identical receipt")
	_check(_battle_snapshot(replay_deck, replay_party, replay_enemies)
		== _battle_snapshot(deck, party, enemies),
		label + ": the same seed replays the identical battle and RNG state")


## AC3: every failed identity, turn, owner, seat, energy, held-copy, target, roster or counter
## precondition is refused with its reason and mutates no deck, party, enemy, counter or RNG state.
func _test_overload_refusals() -> void:
	var resolver := CombatTinkerV3OverloadCards.new()
	var party := _overload_party(2, 3)
	var deck := _scrap_deck([OVERLOAD], 402100, 5)
	var enemies := _overload_enemies()

	_rejected_overload(resolver, null, party, enemies, OVERLOAD, 1, "invalid_request", "null deck")
	_rejected_overload(resolver, deck, null, enemies, OVERLOAD, 1, "invalid_request", "null party")
	_rejected_overload(resolver, deck, party, null, OVERLOAD, 1, "invalid_request",
		"null enemies")

	# An inactive turn is never paid, even with a real copy in hand.
	var inactive := CombatDeck.new([OVERLOAD], _scrap_rng(402101))
	inactive.hand.append(OVERLOAD)
	_check(not inactive.turn_active and inactive.hand.has(OVERLOAD),
		"inactive fixture really holds a copy outside a turn")
	_rejected_overload(resolver, inactive, party, enemies, OVERLOAD, 1, "inactive_turn",
		"inactive turn")

	# Unsupported card identities: other authentic Tinker cards, v2 cards, forged spellings.
	var wrong_ids: Array = ["tinker_v3_brass_casing", "tinker_v3_brass_casing_plus",
		"tinker_v3_spring_clamp", "tinker_v3_gear_brace", "tinker_v3_spare_screws",
		"tinker_v3_scrapstorm", "tinker_spare_parts", "tinker_v3_overload+",
		"tinker_v3_overload_plus_plus", "tinker_v3_overload_", "overload",
		"TINKER_V3_OVERLOAD", "", StringName(OVERLOAD), null, 0, 3.5, false, [], {}]
	for wrong_id: Variant in wrong_ids:
		_rejected_overload(resolver, deck, party, enemies, wrong_id, 1, "unsupported_card",
			"unsupported ID " + str(wrong_id))
	# An authentic Overload+ the hand does not hold is still unheld.
	_rejected_overload(resolver, deck, party, enemies, OVERLOAD_PLUS, 1, "card_not_held",
		"authentic but unheld Overload+")

	# An unaffordable copy is refused without a partial charge.
	var poor := _scrap_deck([OVERLOAD], 402102, 5)
	poor.combat_state.energy = 0
	_check(poor.energy == 0 and poor.hand.has(OVERLOAD),
		"short-energy fixture really holds a copy with no energy")
	_rejected_overload(resolver, poor, party, enemies, OVERLOAD, 1, "insufficient_energy",
		"no energy")

	# Overload prints FROM 2-3: the front seat is not a legal owner.
	var front_party := _overload_party(1, 3)
	var front_deck := _scrap_deck([OVERLOAD], 402103, 5)
	_rejected_overload(resolver, front_deck, front_party, enemies, OVERLOAD, 1,
		"owner_illegal_position", "Overload from seat 1")

	# A party without Tinker never authorizes the play.
	var absent_owner := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "yarn_ranger", "max_hp": 28}])
	_check(absent_owner.is_valid() and absent_owner.get_hero(2).get("id") == "seamstress",
		"absent-owner fixture is a valid party without a Tinker")
	_rejected_overload(resolver, deck, absent_owner, enemies, OVERLOAD, 1, "owner_missing",
		"absent Tinker")

	# A second Tinker identity is a malformed roster, never a second owner.
	var duplicate := _overload_party(2, 3)
	duplicate._heroes[0]["id"] = "tinker"
	_check(duplicate.get_hero(1).get("id") == "tinker"
		and duplicate.get_hero(2).get("id") == "tinker",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected_overload(resolver, deck, duplicate, enemies, OVERLOAD, 1, "invalid_party",
		"duplicate Tinker identity")
	var bad_hp := _overload_party(2, 3)
	bad_hp._heroes[0]["hp"] = 999
	_rejected_overload(resolver, deck, bad_hp, enemies, OVERLOAD, 1, "invalid_party",
		"malformed hero HP")
	var short_party := CombatParty.new([{"id": "tinker", "max_hp": 26}])
	_rejected_overload(resolver, deck, short_party, enemies, OVERLOAD, 1, "invalid_party",
		"invalid one-hero party")

	# A torn (downed) owner may not play.
	var torn_owner := _overload_party(3, 3)
	_check(torn_owner.apply_damage(3, 26) and torn_owner.is_downed(3),
		"torn-owner fixture really has a downed Tinker")
	_rejected_overload(resolver, deck, torn_owner, enemies, OVERLOAD, 2, "owner_downed",
		"downed Tinker")

	# A slain enemy and out-of-range slots are never hit.
	var slain_targets := _overload_enemies()
	_check(slain_targets.apply_damage(1, 30) and slain_targets.is_slain(1),
		"slain-target fixture really has a dead front enemy")
	_rejected_overload(resolver, deck, party, slain_targets, OVERLOAD, 1, "target_slain",
		"slain enemy")
	for slot: int in [0, 4, -1, 99, 3]:
		_rejected_overload(resolver, deck, party, enemies, OVERLOAD, slot, "invalid_target",
			"illegal target slot " + str(slot))

	# A malformed stored counter is never coerced into a legal number.
	var text_counter := _overload_party(2, 3)
	text_counter._heroes[1]["combat_scrap"] = "3"
	_rejected_overload(resolver, deck, text_counter, enemies, OVERLOAD, 1,
		"malformed_combat_scrap", "string Combat Scrap")
	var negative_counter := _overload_party(2, 3)
	negative_counter._heroes[1]["combat_scrap"] = -1
	_rejected_overload(resolver, deck, negative_counter, enemies, OVERLOAD, 1,
		"malformed_combat_scrap", "negative Combat Scrap")
	var float_counter := _overload_party(2, 3)
	float_counter._heroes[1]["combat_scrap"] = 1.0
	_rejected_overload(resolver, deck, float_counter, enemies, OVERLOAD, 1,
		"malformed_combat_scrap", "float Combat Scrap")

	# The printed formula must stay representable.
	var overflow_counter := _overload_party(2, 3)
	overflow_counter._heroes[1]["combat_scrap"] = CombatParty.MAX_INT
	_rejected_overload(resolver, deck, overflow_counter, enemies, OVERLOAD, 1,
		"damage_overflow", "Combat Scrap damage overflow")

	# Invalid or malformed enemy rosters fail closed.
	var empty_roster := CombatEnemies.new([])
	_check(not empty_roster.is_valid(), "empty-roster fixture really is invalid")
	_rejected_overload(resolver, deck, party, empty_roster, OVERLOAD, 1, "invalid_enemies",
		"empty enemy roster")
	var bad_enemy_hp := _overload_enemies()
	bad_enemy_hp._enemies[0]["hp"] = 999
	_rejected_overload(resolver, deck, party, bad_enemy_hp, OVERLOAD, 1, "invalid_enemies",
		"malformed enemy HP")

	# The shared fixture deck, party and roster survived every refusal untouched.
	_check(deck.energy == 3 and deck.hand.has(OVERLOAD) and deck.discard_pile.is_empty()
		and party.get_hero(2).get("combat_scrap") == 3
		and enemies.get_enemy(1).get("hp") == 30 and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("hp") == 24,
		"every refusal left the shared fixture deck, party and enemies untouched")

	# A refused attempt never poisons the next authentic play on the same objects.
	var retry: Dictionary = resolver.play_card(deck, party, enemies, OVERLOAD, 2)
	_check(retry.get("ok") == true and retry.get("raw_damage") == 11,
		"the authentic play then succeeds once with 11 raw damage")
	_check(deck.energy == 2 and deck.discard_pile == [OVERLOAD]
		and party.get_hero(2).get("combat_scrap") == 0
		and enemies.get_enemy(2).get("hp") == 13 and enemies.get_enemy(1).get("hp") == 30,
		"the retry paid once, spent the counter and hit only the chosen enemy")
	_rejected_overload(resolver, deck, party, enemies, OVERLOAD, 2, "card_not_held",
		"a second claim of the same copy")


func _overload_enemies(second_max_hp: int = 24) -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "straw_dummy", "max_hp": 30},
		{"id": "quilt_hog", "max_hp": second_max_hp},
	])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"two-enemy fixture really is a valid living roster")
	return enemies


## A real three-hero party with the Tinker in the named seat and the optional counters set: the
## Tinker holds `scrap`, teammates hold a distinct non-zero counter of their own.
func _overload_party(tinker_position: int, scrap: int) -> CombatParty:
	var party := _scrap_party(tinker_position)
	party._heroes[tinker_position - 1]["combat_scrap"] = scrap
	for index in range(3):
		if index + 1 != tinker_position:
			party._heroes[index]["combat_scrap"] = 2
	_check(party.get_hero(tinker_position).get("combat_scrap") == scrap
		and party._heroes[tinker_position - 1].get("combat_scrap") == scrap,
		"the Tinker fixture really holds " + str(scrap) + " Combat Scrap")
	return party


func _battle_snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	var snapshot := _scrap_snapshot(deck, party)
	snapshot["enemies"] = []
	snapshot["enemies_valid"] = false
	if enemies != null:
		snapshot["enemies"] = enemies.get_enemies()
		snapshot["enemies_valid"] = enemies.is_valid()
	return snapshot


## The exact Overload outcome: one energy, the held copy moved to discard, the whole Tinker counter
## spent and the raw hit applied through Block to the chosen enemy only.
func _expected_overload(before: Dictionary, card_id: String, seat: int, target: int,
		scrap: int, raw: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - 1
	expected["state_energy"] = int(expected["state_energy"]) - 1
	var hand: Array = expected["hand"]
	_check(hand.count(card_id) == 1, "expected snapshot: exactly one played copy is held")
	hand.remove_at(hand.find(card_id))
	(expected["discard"] as Array).append(card_id)
	var hero: Dictionary = expected["party"][seat - 1]
	_check(int(hero.get("combat_scrap", -1)) == scrap,
		"expected snapshot: the Tinker really holds " + str(scrap) + " Combat Scrap")
	hero["combat_scrap"] = 0
	var enemy: Dictionary = expected["enemies"][target - 1]
	var absorbed: int = mini(int(enemy["block"]), raw)
	enemy["block"] = int(enemy["block"]) - absorbed
	enemy["hp"] = maxi(0, int(enemy["hp"]) - (raw - absorbed))
	return expected


func _rejected_overload(resolver: CombatTinkerV3OverloadCards, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, card_id: Variant, target: int,
		reason: String, label: String) -> void:
	var before := _battle_snapshot(deck, party, enemies)
	var plan: Dictionary = resolver.preflight(deck, party, enemies, card_id, target)
	_check(plan.get("ok") == false and plan.get("reason") == reason,
		label + ": pure preflight also refuses with " + reason)
	_check(_battle_snapshot(deck, party, enemies) == before,
		label + ": preflight itself changed no state")
	var result: Dictionary = resolver.play_card(deck, party, enemies, card_id, target)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(result.get("reason")) + ")")
	_check(_battle_snapshot(deck, party, enemies) == before,
		label + ": unchanged energy, hand, piles, turn, party, counters, enemies and RNG")


## ---------------------------------------------------------------------------
## Wind-up Turret / Wind-up Turret+: paid deployment and detached end-turn ticks.
## ---------------------------------------------------------------------------


## Independent per-tick damage for the two turret printings (never read back from the resolver).
func _turret_damage(card_id: String) -> int:
	return 4 if card_id == TURRET_PLUS else 3


## AC1 (catalog half): the resolver authenticates exactly the authored Wind-up Turret pair - three
## end-of-player-turn ticks, run RNG, living targets only, the back seat and the self target - and nothing else.
func _test_turret_catalog_contract() -> void:
	var catalog := V3TinkerPoolCards.new()
	var resolver := CombatTinkerV3TurretCards.new()
	var expected := {
		TURRET: {"damage": 3, "is_upgrade": false},
		TURRET_PLUS: {"damage": 4, "is_upgrade": true},
	}
	for card_id: String in TURRET_IDS:
		var row: Dictionary = expected[card_id]
		var damage: int = row["damage"]
		var record: Dictionary = catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + " is authored in the v3 Tinker catalog")
		if record.is_empty():
			continue
		_check(record.get("display_name") == "Wind-up Turret" + ("+" if row["is_upgrade"] else ""),
			card_id + " display name")
		_check(record.get("owner") == "tinker", card_id + " is owned by Tinker")
		_check(record.get("rarity") == "uncommon", card_id + " is uncommon")
		_check(record.get("cost") == 2, card_id + " prints cost 2")
		_check(record.get("from_positions") == [3], card_id + " prints FROM 3")
		_check(record.get("target_kind") == "self", card_id + " targets self")
		_check(record.get("to_positions") == [], card_id + " prints an empty TO line")
		_check(record.get("effects") == {"turret": _turret(damage)},
			card_id + " prints exactly " + str(damage) + " damage x 3 end-turn ticks")
		_check(record.get("starting_copies") == 0, card_id + " is never a starter copy")
		_check(record.get("base_id") == TURRET and record.get("upgrade_id") == TURRET_PLUS
			and record.get("is_upgrade") == row["is_upgrade"],
			card_id + " preserves the base/+ link")
		_check(not record.has("upgrade_of"), card_id + " links with base_id/upgrade_id/is_upgrade")
		_check(resolver.is_supported_card(card_id), card_id + " is a supported turret card")
		_check(CombatTinkerV3TurretCards.is_authentic_definition(record, card_id),
			card_id + " passes the definition authenticator")
		_check(CombatTinkerV3TurretCards.turret_definition(card_id) == record,
			card_id + " resolves to its exact detached catalog record")

	# Detached: mutating a resolved record cannot rewrite what the next resolution returns.
	var sample: Dictionary = CombatTinkerV3TurretCards.turret_definition(TURRET)
	_check(not sample.is_empty(), "turret resolution fixture loaded")
	if not sample.is_empty():
		sample["effects"]["turret"]["damage"] = 900
		sample["effects"]["turret"]["duration_turns"] = 99
		sample["effects"]["turret"]["rng_source"] = "second_rng"
		sample["from_positions"].clear()
		sample["cost"] = 0
		_check(CombatTinkerV3TurretCards.turret_definition(TURRET)
			== catalog.get_definition(TURRET),
			"a mutated turret definition cannot poison later resolutions")

	# Every other v3 Tinker card (base and plus) is unrelated to this service.
	var unrelated: Array[String] = []
	for base_id in catalog.get_pool_card_ids():
		if not TURRET_IDS.has(base_id):
			unrelated.append(base_id)
		var upgrade_id: String = catalog.get_upgrade_id(base_id)
		if not upgrade_id.is_empty() and not TURRET_IDS.has(upgrade_id):
			unrelated.append(upgrade_id)
	_check(unrelated.has("tinker_v3_brass_casing") and unrelated.has("tinker_v3_overload_plus"),
		"unrelated-card fixture really contains other authentic v3 Tinker cards (precondition)")
	for other_id: String in unrelated:
		_check(CombatTinkerV3TurretCards.turret_definition(other_id).is_empty(),
			other_id + " does not resolve as a turret")
		_check(not resolver.is_supported_card(other_id),
			other_id + " is not a supported turret card")

	# The v2 Tinker pool and foreign spellings are never turret printings.
	var forged: Array = ["tinker_spare_parts", "tinker_overclock", "tinker_v3_wind_up_turret+",
		"tinker_v3_wind_up_turret_plus_plus", "tinker_v3_wind_up_turret_", "wind_up_turret",
		"TINKER_V3_WIND_UP_TURRET", "", "tinker_v3_missing_card", StringName(TURRET),
		null, 0, 3.5, false, [], {}]
	for other_id: Variant in forged:
		_check(CombatTinkerV3TurretCards.turret_definition(other_id).is_empty(),
			"forged or non-string ID never resolves as a turret: " + str(other_id))
		_check(not resolver.is_supported_card(other_id),
			"forged or non-string ID is never a supported turret: " + str(other_id))

	# Adversarial copies of the real Turret record: each altered contract field is refused.
	var base_record: Dictionary = catalog.get_definition(TURRET)
	_check(not base_record.is_empty()
		and CombatTinkerV3TurretCards.is_authentic_definition(base_record, TURRET),
		"authenticator positive fixture really is the authored Wind-up Turret")
	var mutations: Array[Callable] = [
		func(record: Dictionary) -> void: record["effects"]["turret"]["damage"] = 5,
		func(record: Dictionary) -> void: record["effects"]["turret"]["damage"] = 3.0,
		func(record: Dictionary) -> void: record["effects"]["turret"]["damage"] = "3",
		func(record: Dictionary) -> void: record["effects"]["turret"]["duration_turns"] = 2,
		func(record: Dictionary) -> void: record["effects"]["turret"]["duration_turns"] = 4,
		func(record: Dictionary) -> void: record["effects"]["turret"]["tick"] = "start_player_turn",
		func(record: Dictionary) -> void: record["effects"]["turret"]["target_kind"] = "enemy_single",
		func(record: Dictionary) -> void: record["effects"]["turret"]["living_targets_only"] = false,
		func(record: Dictionary) -> void: record["effects"]["turret"]["living_targets_only"] = 1,
		func(record: Dictionary) -> void: record["effects"]["turret"]["rng_source"] = "second_rng",
		func(record: Dictionary) -> void: record["effects"]["turret"].erase("living_targets_only"),
		func(record: Dictionary) -> void: record["effects"]["turret"]["invented"] = true,
		func(record: Dictionary) -> void: record["effects"]["damage"] = 3,
		func(record: Dictionary) -> void: record["effects"] = {"turret": {"damage": 3}},
		func(record: Dictionary) -> void: record["effects"] = "turret",
		func(record: Dictionary) -> void: record["cost"] = 0,
		func(record: Dictionary) -> void: record["cost"] = 2.0,
		func(record: Dictionary) -> void: record["owner"] = "warden",
		func(record: Dictionary) -> void: record["from_positions"] = [1, 2, 3],
		func(record: Dictionary) -> void: record["from_positions"] = [2, 3],
		func(record: Dictionary) -> void: record["to_positions"] = [1],
		func(record: Dictionary) -> void: record["target_kind"] = "enemy_single",
		func(record: Dictionary) -> void: record["is_upgrade"] = true,
		func(record: Dictionary) -> void: record["upgrade_of"] = TURRET,
		func(record: Dictionary) -> void: record.erase("upgrade_id"),
		func(record: Dictionary) -> void: record.erase("effects"),
		func(record: Dictionary) -> void: record.erase("to_positions"),
	]
	for index in range(mutations.size()):
		var tampered: Dictionary = base_record.duplicate(true)
		mutations[index].call(tampered)
		_check(not CombatTinkerV3TurretCards.is_authentic_definition(tampered, TURRET),
			"tampered turret record " + str(index) + " is refused")
	_check(not CombatTinkerV3TurretCards.is_authentic_definition(
		catalog.get_definition(TURRET_PLUS), TURRET),
		"an upgraded turret record cannot authenticate as its base ID")
	_check(not CombatTinkerV3TurretCards.is_authentic_definition(
		catalog.get_definition(TURRET), TURRET_PLUS),
		"a base turret record cannot authenticate as its upgraded ID")


## AC1: one real held Wind-up Turret or Wind-up Turret+ spends exactly two shared energy, discards exactly one
## held copy and publishes one independent detached three-beat instance without a hit or an RNG draw.
func _test_turret_deployments() -> void:
	var resolver := CombatTinkerV3TurretCards.new()
	var seed_value := 501000
	for card_id: String in TURRET_IDS:
		var damage := _turret_damage(card_id)
		var label := card_id + " deployment"
		var party := _scrap_party(3)
		var deck := _scrap_deck([card_id], seed_value, 6)
		seed_value += 1
		var enemies := _turret_enemies()
		var enemy_before: Array[Dictionary] = enemies.get_enemies()
		var rng_before: int = deck._rng.state
		var before := _battle_snapshot(deck, party, enemies)
		_check(deck.energy == 3 and deck.hand.count(card_id) == 1,
			label + ": fixture really holds one copy in a three-energy turn")
		var plan: Dictionary = resolver.preflight(deck, party, card_id, 0)
		_check(plan.get("ok") == true and plan.get("reason") == "legal",
			label + ": read-only preflight accepts the funded deployment")
		_check(plan.get("damage") == damage and plan.get("duration_turns") == 3
			and plan.get("owner_position") == 3 and plan.get("target_position") == 3,
			label + ": preflight reports the printed payload and the real owner seat")
		_check(_battle_snapshot(deck, party, enemies) == before,
			label + ": preflight changed no battle state")
		var result: Dictionary = resolver.play_card(deck, party, card_id, 0)
		_check(result.get("ok") == true and result.get("reason") == "deployed",
			label + ": authorized paid deployment")
		_check(result.get("card_id") == card_id and result.get("cost") == 2,
			label + ": receipt names the authentic card and its two energy")
		_check(result.get("owner_position") == 3 and result.get("target_position") == 3,
			label + ": receipt reports the real owner seat as the self recipient")
		_check(result.get("damage") == damage and result.get("duration_turns") == 3
			and result.get("remaining") == 3,
			label + ": receipt reports the printed damage and exactly three pending beats")
		_check(result.get("immediate_damage") == 0 and result.get("rng_consumed") == false,
			label + ": deployment lands no immediate attack and draws no RNG")
		_check(result.get("energy_before") == 3 and result.get("energy_after") == 1,
			label + ": receipt reports the exact energy change")
		_check(not result.has("scraps") and not result.has("wallet"),
			label + ": receipt carries no wallet state")
		_check(deck.energy == 1, label + ": exactly two energy were paid")
		_check(deck.hand.count(card_id) == 0, label + ": the held copy left the hand")
		_check(deck.discard_pile == [card_id],
			label + ": exactly one played copy reached the discard")
		_check(deck._rng.state == rng_before, label + ": deployment consumed no RNG")
		_check(enemies.get_enemies() == enemy_before,
			label + ": deployment dealt no damage to any enemy")
		_check(not party.get_hero(3).has("combat_scrap"),
			label + ": deployment spends no Combat Scrap")
		_check(party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0,
			label + ": the Tinker's HP and Block are untouched")
		var state: Dictionary = result.get("state", {})
		_check(not state.is_empty() and CombatTinkerV3TurretCards.is_pending_instance(state),
			label + ": the deployment publishes one well-formed pending instance")
		var state_keys: Array = state.keys()
		state_keys.sort()
		var expected_keys: Array = TURRET_STATE_KEYS.duplicate()
		expected_keys.sort()
		_check(state_keys == expected_keys,
			label + ": the pending instance carries exactly its closed key set")
		_check(state.get("kind") == "wind_up_turret" and state.get("card_id") == card_id,
			label + ": the pending instance names its authentic source")
		_check(state.get("damage") == damage and state.get("duration_turns") == 3
			and state.get("remaining") == 3,
			label + ": the pending instance stores the printed damage and three beats")
		_check(state.get("tick") == "end_player_turn" and state.get("target_kind") == "enemy_random"
			and state.get("living_targets_only") == true and state.get("rng_source") == "run",
			label + ": the pending instance keeps the authored end-turn/random-living/run-RNG rule")
		_check(_battle_snapshot(deck, party, enemies) == _expected_turret_deploy(before, card_id),
			label + ": exact hand, piles, energy, turn, party, enemy and RNG state")

	# Two genuine copies deploy two independent pending instances from one shared hand.
	var twin_party := _scrap_party(3)
	var twin_deck := _scrap_deck([TURRET, TURRET], 501100, 4)
	twin_deck.combat_state.energy = 5
	_check(twin_deck.hand.count(TURRET) == 2 and twin_deck.energy == 5,
		"twin-deployment fixture really holds two copies with five energy")
	var first: Dictionary = resolver.play_card(twin_deck, twin_party, TURRET, 0)
	var second: Dictionary = resolver.play_card(twin_deck, twin_party, TURRET, 0)
	_check(first.get("ok") == true and second.get("ok") == true,
		"both genuine copied turrets deploy")
	_check(twin_deck.energy == 1 and twin_deck.hand.count(TURRET) == 0
		and twin_deck.discard_pile == [TURRET, TURRET],
		"two deployments paid four energy and discarded both copies")
	var state_a: Dictionary = first.get("state", {})
	var state_b: Dictionary = second.get("state", {})
	_check(not state_a.is_empty() and not state_b.is_empty()
		and int(state_a.get("remaining", -1)) == 3 and int(state_b.get("remaining", -1)) == 3,
		"both pending instances start with three beats")
	if not state_a.is_empty() and not state_b.is_empty():
		state_a["remaining"] = 0
		_check(int(state_b.get("remaining", -1)) == 3,
			"mutating one pending instance never changes the other")
		state_a["remaining"] = 3


## AC2: each of three successive end-of-player-turn ticks strikes exactly one random LIVING enemy for the
## stored 3 or 4 with Block before HP; a fourth tick is inert, a dead slot is never retargeted or resurrected,
## a sole living target needs no RNG draw, an empty roster forges no hit, and a replayed seed repeats every
## choice and the RNG state.
func _test_turret_ticks() -> void:
	var resolver := CombatTinkerV3TurretCards.new()
	var seed_value := 502000
	for card_id: String in TURRET_IDS:
		var damage := _turret_damage(card_id)
		var party := _scrap_party(3)
		var deck := _scrap_deck([card_id], seed_value, 5)
		seed_value += 1
		var enemies := _turret_enemies()
		var deploy: Dictionary = resolver.play_card(deck, party, card_id, 0)
		_check(deploy.get("ok") == true, card_id + ": the turret is deployed for the tick fixture")
		if deploy.get("ok") != true:
			continue
		var state: Dictionary = deploy.get("state", {})
		var targets: Array[int] = []
		for beat in range(3):
			var label := card_id + " beat " + str(beat + 1)
			var tick: Dictionary = _tick_checked(resolver, state, enemies, deck._rng, label)
			_check(tick.get("ok") == true, label + ": the scheduled end-turn beat fired")
			if tick.get("ok") != true:
				break
			_check(tick.get("damage") == damage,
				label + ": exactly " + str(damage) + " raw damage")
			targets.append(int(tick.get("target_position", 0)))
			state = tick["state"]
			_check(int(state.get("remaining", -1)) == 2 - beat,
				label + ": remaining counter 2/1/0")
		_check(targets.size() == 3, card_id + ": exactly three beats resolved")
		_check(int(state.get("remaining", -1)) == 0, card_id + ": three ticks exhausted the instance")
		_check(CombatTinkerV3TurretCards.is_pending_instance(state),
			card_id + ": the expired instance is still a well-formed pending shape")
		_rejected_turret_tick(resolver, state, enemies, deck._rng, "turret_expired",
			card_id + " fourth tick")

		# A slot that dies mid-sequence is never retargeted or resurrected, and the sole survivor needs no RNG.
		var death_party := _scrap_party(3)
		var death_deck := _scrap_deck([card_id], seed_value, 5)
		seed_value += 1
		var death_enemies := _turret_enemies()
		var death_deploy: Dictionary = resolver.play_card(death_deck, death_party, card_id, 0)
		_check(death_deploy.get("ok") == true, card_id + ": the mid-death fixture deploys")
		if death_deploy.get("ok") != true:
			continue
		var death_state: Dictionary = death_deploy.get("state", {})
		var opening: Dictionary = _tick_checked(resolver, death_state, death_enemies,
			death_deck._rng, card_id + " opening beat")
		_check(opening.get("ok") == true, card_id + ": the opening beat fired")
		if opening.get("ok") != true:
			continue
		death_state = opening["state"]
		for slot in [1, 3]:
			if not death_enemies.is_slain(slot):
				_check(death_enemies.apply_damage(slot, 99),
					card_id + ": the fixture slays slot " + str(slot))
		_check(death_enemies.is_slain(1) and death_enemies.is_slain(3),
			card_id + ": both outer slots really are dead mid-sequence")
		var dead_ids: Array = [str(death_enemies.get_enemy(1).get("id", "")),
			str(death_enemies.get_enemy(3).get("id", ""))]
		for beat in range(2):
			var label := card_id + " survivor beat " + str(beat + 1)
			var rng_before: int = death_deck._rng.state
			var tick: Dictionary = _tick_checked(resolver, death_state, death_enemies,
				death_deck._rng, label)
			_check(tick.get("ok") == true and int(tick.get("target_position", 0)) == 2,
				label + ": the sole living slot is the only target")
			_check(tick.get("rng_consumed") == false and death_deck._rng.state == rng_before,
				label + ": a sole living target needs no RNG draw")
			_check(death_enemies.is_slain(1) and death_enemies.is_slain(3),
				label + ": a dead slot is never resurrected")
			_check(str(death_enemies.get_enemy(1).get("id", "")) == dead_ids[0]
				and str(death_enemies.get_enemy(3).get("id", "")) == dead_ids[1],
				label + ": slain slots keep their authored ids and positions")
			death_state = tick.get("state", death_state)

		# A roster with one living enemy from the start: chosen without any RNG draw.
		var sole_party := _scrap_party(3)
		var sole_deck := _scrap_deck([card_id], seed_value, 5)
		seed_value += 1
		var sole_enemies := _turret_two_enemies()
		_check(sole_enemies.apply_damage(1, 99),
			card_id + ": the sole-target fixture slays slot 1")
		var sole_deploy: Dictionary = resolver.play_card(sole_deck, sole_party, card_id, 0)
		_check(sole_deploy.get("ok") == true, card_id + ": the sole-target fixture deploys")
		if sole_deploy.get("ok") != true:
			continue
		var sole_rng_before: int = sole_deck._rng.state
		var sole_tick: Dictionary = _tick_checked(resolver, sole_deploy.get("state", {}),
			sole_enemies, sole_deck._rng, card_id + " sole target")
		_check(sole_tick.get("ok") == true and int(sole_tick.get("target_position", 0)) == 2,
			card_id + ": the only living slot is chosen")
		_check(sole_tick.get("rng_consumed") == false
			and sole_deck._rng.state == sole_rng_before,
			card_id + ": one living enemy consumes no run RNG")
		_check(sole_enemies.is_slain(1), card_id + ": the dead slot stays dead")

		# No living enemies: the scheduled beat is still spent, but no hit is forged and no RNG is drawn.
		var empty_party := _scrap_party(3)
		var empty_deck := _scrap_deck([card_id], seed_value, 5)
		seed_value += 1
		var empty_enemies := _turret_two_enemies()
		_check(empty_enemies.apply_damage(1, 99) and empty_enemies.apply_damage(2, 99),
			card_id + ": the empty-roster fixture slays every enemy")
		var empty_ids: Array = [str(empty_enemies.get_enemy(1).get("id", "")),
			str(empty_enemies.get_enemy(2).get("id", ""))]
		var empty_deploy: Dictionary = resolver.play_card(empty_deck, empty_party, card_id, 0)
		_check(empty_deploy.get("ok") == true, card_id + ": the empty-roster fixture deploys")
		if empty_deploy.get("ok") != true:
			continue
		var empty_state: Dictionary = empty_deploy.get("state", {})
		var empty_rng_before: int = empty_deck._rng.state
		for beat in range(3):
			var label := card_id + " empty beat " + str(beat + 1)
			var tick: Dictionary = _tick_checked(resolver, empty_state, empty_enemies,
				empty_deck._rng, label)
			_check(tick.get("ok") == true, label + ": the beat is consumed")
			_check(int(tick.get("target_position", -1)) == 0 and tick.get("damage") == 0
				and tick.get("damage_dealt") == 0, label + ": no hit and no damage are forged")
			_check(tick.get("rng_consumed") == false, label + ": no RNG is drawn")
			empty_state = tick.get("state", empty_state)
		_check(empty_deck._rng.state == empty_rng_before,
			card_id + ": three empty beats consumed no run RNG at all")
		_check(empty_enemies.is_defeated()
			and str(empty_enemies.get_enemy(1).get("id", "")) == empty_ids[0]
			and str(empty_enemies.get_enemy(2).get("id", "")) == empty_ids[1],
			card_id + ": no empty beat resurrected or renamed a slain enemy")
		_rejected_turret_tick(resolver, empty_state, empty_enemies, empty_deck._rng,
			"turret_expired", card_id + " empty-roster fourth tick")

		# The same seeded two- and three-enemy sequences replay identically, RNG state included.
		var first_trace: Array = _turret_trace(card_id, 515000, 2)
		var replay_trace: Array = _turret_trace(card_id, 515000, 2)
		_check(first_trace.size() == 4 and replay_trace.size() == 4,
			card_id + ": the two-target trace really covers three beats and an inert fourth")
		_check(first_trace == replay_trace,
			card_id + ": the same seed replays identical two-target choices, damage and RNG state")
		_check(first_trace.size() == 4 and first_trace[3].get("reason") == "turret_expired",
			card_id + ": the replayed fourth beat is inert")
		var three_trace: Array = _turret_trace(card_id, 515100, 3)
		var three_replay: Array = _turret_trace(card_id, 515100, 3)
		_check(three_trace.size() == 4 and three_trace == three_replay,
			card_id + ": the same seed replays the identical three-enemy sequence too")

	# Two independently deployed instances count down independently against the same roster.
	var twin_party := _scrap_party(3)
	var twin_deck := _scrap_deck([TURRET, TURRET], 516000, 4)
	twin_deck.combat_state.energy = 5
	var twin_enemies := _turret_two_enemies()
	var first_deploy: Dictionary = resolver.play_card(twin_deck, twin_party, TURRET, 0)
	var second_deploy: Dictionary = resolver.play_card(twin_deck, twin_party, TURRET, 0)
	_check(first_deploy.get("ok") == true and second_deploy.get("ok") == true,
		"tick-countdown fixture really deploys two instances")
	if first_deploy.get("ok") == true and second_deploy.get("ok") == true:
		var a_state: Dictionary = first_deploy["state"]
		var b_state: Dictionary = second_deploy["state"]
		var tick_a: Dictionary = _tick_checked(resolver, a_state, twin_enemies, twin_deck._rng,
			"twin A first beat")
		a_state = tick_a["state"]
		_check(int(a_state.get("remaining", -1)) == 2
			and int(b_state.get("remaining", -1)) == 3,
			"ticking one instance leaves the other at three beats")
		var tick_b: Dictionary = _tick_checked(resolver, b_state, twin_enemies, twin_deck._rng,
			"twin B first beat")
		b_state = tick_b["state"]
		_check(int(a_state.get("remaining", -1)) == 2
			and int(b_state.get("remaining", -1)) == 2,
			"both instances count down from their own three beats")
		for beat in range(2):
			var tick: Dictionary = _tick_checked(resolver, a_state, twin_enemies,
				twin_deck._rng, "twin A beat " + str(beat + 2))
			a_state = tick["state"]
		_check(int(a_state.get("remaining", -1)) == 0
			and int(b_state.get("remaining", -1)) == 2,
			"an expired instance never expires its neighbour")


## AC3: every failed identity, turn, owner, seat, energy, held-copy, target, roster or turret-state
## precondition is refused with its reason and mutates no deck, party, enemy, pending counter or RNG state.
func _test_turret_refusals() -> void:
	var resolver := CombatTinkerV3TurretCards.new()
	var party := _scrap_party(3)
	var deck := _scrap_deck([TURRET], 517000, 5)
	var enemies := _turret_two_enemies()

	_rejected_turret_play(resolver, null, party, TURRET, 0, "invalid_request", "null deck")
	_rejected_turret_play(resolver, deck, null, TURRET, 0, "invalid_request", "null party")

	# An inactive turn is never paid, even with a real copy in hand.
	var inactive := CombatDeck.new([TURRET], _scrap_rng(517001))
	inactive.hand.append(TURRET)
	_check(not inactive.turn_active and inactive.hand.has(TURRET),
		"inactive turret fixture really holds a copy outside a turn")
	_rejected_turret_play(resolver, inactive, party, TURRET, 0, "inactive_turn", "inactive turn")

	# A missing run RNG is never replaced by an invented one.
	var unseeded := _scrap_deck([TURRET], 517002, 5)
	unseeded._rng = null
	_rejected_turret_play(resolver, unseeded, party, TURRET, 0, "inactive_turn", "missing run RNG")

	# Unsupported card identities: other authentic Tinker cards, v2 cards and forged spellings.
	var wrong_ids: Array = ["tinker_v3_brass_casing", "tinker_v3_gear_brace", "tinker_v3_overload",
		"tinker_v3_scrapstorm", "tinker_spare_parts", "tinker_v3_wind_up_turret+",
		"tinker_v3_wind_up_turret_plus_plus", "tinker_v3_wind_up_turret_", "wind_up_turret",
		"TINKER_V3_WIND_UP_TURRET", "", StringName(TURRET), null, 0, 3.5, false, [], {}]
	for wrong_id: Variant in wrong_ids:
		_rejected_turret_play(resolver, deck, party, wrong_id, 0, "unsupported_card",
			"unsupported ID " + str(wrong_id))
	# An authentic turret the hand does not hold is still unheld.
	_rejected_turret_play(resolver, deck, party, TURRET_PLUS, 0, "card_not_held",
		"authentic but unheld Wind-up Turret+")

	# Unaffordable copies are refused without a partial charge.
	for energy in [0, 1]:
		var poor := _scrap_deck([TURRET], 517010 + energy, 5)
		poor.combat_state.energy = energy
		_check(poor.energy == energy and poor.hand.has(TURRET),
			"short-energy fixture really holds a copy with " + str(energy) + " energy")
		_rejected_turret_play(resolver, poor, party, TURRET, 0, "insufficient_energy",
			str(energy) + " energy")

	# Wind-up Turret prints FROM 3: only the back seat may deploy it.
	for seat in [1, 2]:
		var front_party := _scrap_party(seat)
		var front_deck := _scrap_deck([TURRET], 517020 + seat, 5)
		_rejected_turret_play(resolver, front_deck, front_party, TURRET, 0,
			"owner_illegal_position", "Wind-up Turret from seat " + str(seat))

	# A party without Tinker never authorizes the play.
	var absent_owner := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "yarn_ranger", "max_hp": 28}])
	_check(absent_owner.is_valid() and absent_owner.get_hero(3).get("id") == "yarn_ranger",
		"absent-owner fixture is a valid party without a Tinker")
	_rejected_turret_play(resolver, deck, absent_owner, TURRET, 0, "owner_missing",
		"absent Tinker")

	# A second Tinker identity is a malformed roster, never a second owner.
	var duplicate := _scrap_party(3)
	duplicate._heroes[0]["id"] = "tinker"
	_check(duplicate.get_hero(1).get("id") == "tinker"
		and duplicate.get_hero(3).get("id") == "tinker",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected_turret_play(resolver, deck, duplicate, TURRET, 0, "invalid_party",
		"duplicate Tinker identity")

	# A downed back-seat Tinker may not deploy.
	var torn_owner := _scrap_party(3)
	_check(torn_owner.apply_damage(3, 26) and torn_owner.is_downed(3),
		"torn-owner fixture really has a downed Tinker")
	_rejected_turret_play(resolver, deck, torn_owner, TURRET, 0, "owner_downed", "downed Tinker")

	# Malformed rosters fail closed.
	var short_party := CombatParty.new([{"id": "tinker", "max_hp": 26}])
	_rejected_turret_play(resolver, deck, short_party, TURRET, 0, "invalid_party",
		"invalid one-hero party")
	var bad_hp := _scrap_party(3)
	bad_hp._heroes[0]["hp"] = 999
	_rejected_turret_play(resolver, deck, bad_hp, TURRET, 0, "invalid_party", "malformed hero HP")
	var bad_block := _scrap_party(3)
	bad_block._heroes[0]["block"] = -1
	_rejected_turret_play(resolver, deck, bad_block, TURRET, 0, "invalid_party",
		"malformed hero Block")
	var bad_position := _scrap_party(3)
	bad_position._heroes[0]["position"] = 2
	_rejected_turret_play(resolver, deck, bad_position, TURRET, 0, "invalid_party",
		"malformed hero slot index")
	var bad_identity := _scrap_party(3)
	bad_identity._heroes[0]["id"] = ""
	_rejected_turret_play(resolver, deck, bad_identity, TURRET, 0, "invalid_party",
		"empty hero identity")

	# These cards print target_kind self: any enemy or out-of-range recipient is an invalid request.
	for slot in [1, 2, 3, 4, -1, 99]:
		_rejected_turret_play(resolver, deck, party, TURRET, slot, "invalid_target",
			"enemy target slot " + str(slot))

	# A consumed copy cannot be deployed twice.
	var repeat_deck := _scrap_deck([TURRET], 517030, 5)
	var repeat_party := _scrap_party(3)
	_check(resolver.play_card(repeat_deck, repeat_party, TURRET, 0).get("ok") == true,
		"duplicate-deploy fixture really deploys once")
	_rejected_turret_play(resolver, repeat_deck, repeat_party, TURRET, 0, "card_not_held",
		"second deploy of the consumed copy")

	# The shared fixture deck and party survived every refusal untouched.
	_check(deck.energy == 3 and deck.hand.has(TURRET) and deck.discard_pile.is_empty()
		and party.get_hero(3).get("hp") == 26 and party.get_hero(3).get("block") == 0
		and not party.get_hero(3).has("combat_scrap"),
		"every deployment refusal left the shared fixture deck and party untouched")

	# A refused attempt never poisons the next authentic deployment.
	_rejected_turret_play(resolver, deck, party, TURRET, 1, "invalid_target",
		"retry: wrong target first")
	_rejected_turret_play(resolver, deck, party, TURRET_PLUS, 0, "card_not_held",
		"retry: unheld plus second")
	var retry: Dictionary = resolver.play_card(deck, party, TURRET, 0)
	_check(retry.get("ok") == true and deck.energy == 1 and deck.discard_pile == [TURRET]
		and retry.get("state", {}).get("remaining") == 3,
		"retry: the authentic deployment then succeeds exactly once")

	# ---- tick refusals -------------------------------------------------------------------
	var tick_deck := _scrap_deck([TURRET], 517040, 5)
	var tick_deploy: Dictionary = resolver.play_card(tick_deck, _scrap_party(3), TURRET, 0)
	_check(tick_deploy.get("ok") == true, "tick-refusal fixture really deploys one turret")
	var live_state: Dictionary = tick_deploy.get("state", {})
	_check(CombatTinkerV3TurretCards.is_pending_instance(live_state),
		"tick-refusal fixture really holds a well-formed pending instance")

	_rejected_turret_tick(resolver, live_state, null, _scrap_rng(517041), "invalid_enemies",
		"null enemies")
	_rejected_turret_tick(resolver, live_state, CombatEnemies.new([]), _scrap_rng(517042),
		"invalid_enemies", "empty enemy roster")
	_rejected_turret_tick(resolver, live_state, enemies, null, "invalid_rng", "missing run RNG")
	var bad_roster := _turret_two_enemies()
	bad_roster._enemies[0]["hp"] = 999
	_rejected_turret_tick(resolver, live_state, bad_roster, _scrap_rng(517043),
		"invalid_enemies", "malformed enemy HP")
	var bad_block_roster := _turret_two_enemies()
	bad_block_roster._enemies[1]["block"] = -1
	_rejected_turret_tick(resolver, live_state, bad_block_roster, _scrap_rng(517044),
		"invalid_enemies", "malformed enemy Block")
	var bad_position_roster := _turret_two_enemies()
	bad_position_roster._enemies[1]["position"] = 3
	_rejected_turret_tick(resolver, live_state, bad_position_roster, _scrap_rng(517045),
		"invalid_enemies", "malformed enemy slot index")

	# Malformed or tampered pending instances are refused without touching the roster or the RNG.
	var tampered_states: Array = [null, [], "turret", 3, {}]
	var float_remaining: Dictionary = live_state.duplicate(true)
	float_remaining["remaining"] = 3.0
	var no_damage: Dictionary = live_state.duplicate(true)
	no_damage.erase("damage")
	var extra_key: Dictionary = live_state.duplicate(true)
	extra_key["invented"] = true
	var wrong_kind: Dictionary = live_state.duplicate(true)
	wrong_kind["kind"] = "enemy_summon"
	var unknown_card: Dictionary = live_state.duplicate(true)
	unknown_card["card_id"] = "tinker_v3_overload"
	var flipped_damage: Dictionary = live_state.duplicate(true)
	flipped_damage["damage"] = 4  # the base printing stores 3
	var float_damage: Dictionary = live_state.duplicate(true)
	float_damage["damage"] = 3.0
	var long_duration: Dictionary = live_state.duplicate(true)
	long_duration["duration_turns"] = 4
	var long_remaining: Dictionary = live_state.duplicate(true)
	long_remaining["remaining"] = 4
	var text_remaining: Dictionary = live_state.duplicate(true)
	text_remaining["remaining"] = "3"
	var late_tick: Dictionary = live_state.duplicate(true)
	late_tick["tick"] = "start_player_turn"
	var enemy_targeted: Dictionary = live_state.duplicate(true)
	enemy_targeted["target_kind"] = "enemy_single"
	var all_targets: Dictionary = live_state.duplicate(true)
	all_targets["living_targets_only"] = false
	var second_rng: Dictionary = live_state.duplicate(true)
	second_rng["rng_source"] = "second_rng"
	var expired_early: Dictionary = live_state.duplicate(true)
	expired_early["remaining"] = 0
	tampered_states.append_array([float_remaining, no_damage, extra_key, wrong_kind, unknown_card,
		flipped_damage, float_damage, long_duration, long_remaining, text_remaining,
		late_tick, enemy_targeted, all_targets, second_rng])
	for index in range(tampered_states.size()):
		_rejected_turret_tick(resolver, tampered_states[index], enemies, _scrap_rng(517050 + index),
			"invalid_turret", "tampered instance " + str(index))
	_rejected_turret_tick(resolver, expired_early, enemies, _scrap_rng(517070),
		"turret_expired", "expired instance")

	# The genuine instance still ticks after every refusal.
	var live_tick: Dictionary = _tick_checked(resolver, live_state, enemies, _scrap_rng(517080),
		"post-refusal tick")
	_check(live_tick.get("ok") == true and int(live_tick.get("remaining", -1)) == 2,
		"the genuine pending instance still ticks once after every refusal")


## A real three-enemy roster with Block on every slot: 3 HP-worth of Block-first evidence for either damage
## figure, and a 1-HP front-of-Block target that can die during the ticks.
func _turret_enemies() -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "straw_dummy", "max_hp": 30},
		{"id": "quilt_hog", "max_hp": 24},
		{"id": "pincushion", "max_hp": 1},
	])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3,
		"three-enemy turret fixture really is a valid living roster")
	_check(enemies.gain_block(1, 2) and enemies.gain_block(2, 2) and enemies.gain_block(3, 2),
		"three-enemy turret fixture really carries Block on every slot")
	return enemies


## A real two-enemy roster with Block on both slots, used for the deterministic replayed sequences.
func _turret_two_enemies() -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "straw_dummy", "max_hp": 30},
		{"id": "quilt_hog", "max_hp": 24},
	])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"two-enemy turret fixture really is a valid living roster")
	_check(enemies.gain_block(1, 2) and enemies.gain_block(2, 2),
		"two-enemy turret fixture really carries Block on both slots")
	return enemies


## One real end-of-player-turn tick checked against independent arithmetic: the chosen slot must be living, the
## stored damage must land through Block before HP on that slot only, the counter must fall by exactly one, the
## caller's instance must stay untouched and the returned next state must be detached from it.
func _tick_checked(resolver: CombatTinkerV3TurretCards, state: Dictionary,
		enemies: CombatEnemies, rng: RandomNumberGenerator, label: String) -> Dictionary:
	var before_enemies: Array[Dictionary] = enemies.get_enemies()
	var living: Array[int] = []
	for enemy in before_enemies:
		if int(enemy.get("hp", 0)) > 0:
			living.append(int(enemy.get("position", 0)))
	var remaining_before: int = int(state.get("remaining", -1))
	var damage: int = int(state.get("damage", 0))
	var original: Dictionary = state.duplicate(true)
	var rng_before: int = rng.state
	var result: Dictionary = resolver.tick_turret(state, enemies, rng)
	_check(result.get("ok") == true and result.get("reason") == "ticked", label + ": tick accepted")
	_check(state == original, label + ": the caller's instance was not mutated")
	_check(result.get("stored_damage") == damage, label + ": the receipt reports the stored damage")
	_check(result.get("remaining_before") == remaining_before
		and result.get("remaining") == remaining_before - 1,
		label + ": exactly one scheduled beat was consumed")
	_check(result.get("expired") == (remaining_before - 1 == 0),
		label + ": expiry is published exactly on the last beat")
	_check((result.get("living_positions", []) as Array) == living,
		label + ": receipt lists exactly the living slots")
	var target: int = int(result.get("target_position", -1))
	if living.is_empty():
		_check(target == 0, label + ": no enemy is named")
		_check(result.get("damage") == 0 and result.get("damage_dealt") == 0,
			label + ": no damage is forged")
		_check(result.get("rng_consumed") == false and rng.state == rng_before,
			label + ": no RNG is drawn")
		_check(enemies.get_enemies() == before_enemies, label + ": the roster is untouched")
	else:
		_check(living.has(target), label + ": the chosen slot was living")
		if living.has(target):
			var chosen: Dictionary = before_enemies[target - 1]
			var absorbed: int = mini(int(chosen.get("block", 0)), damage)
			var hp_loss: int = mini(int(chosen.get("hp", 0)), damage - absorbed)
			_check(result.get("damage") == damage,
				label + ": exactly " + str(damage) + " raw damage")
			_check(result.get("block_absorbed") == absorbed and result.get("hp_loss") == hp_loss,
				label + ": Block absorbed " + str(absorbed) + " before " + str(hp_loss) + " HP")
			_check(int(result.get("damage_dealt", -1)) == absorbed + hp_loss,
				label + ": the receipt accounts for every point dealt")
			_check(str(result.get("target_id", "")) == str(chosen.get("id", "")),
				label + ": the receipt names the struck enemy")
			_check(result.get("rng_consumed") == (rng.state != rng_before),
				label + ": the receipt reports the real RNG use")
			if living.size() >= 2:
				_check(rng.state != rng_before and result.get("rng_consumed") == true,
					label + ": multiple living targets draw the supplied run RNG")
			else:
				_check(rng.state == rng_before and result.get("rng_consumed") == false
					and target == living[0],
					label + ": a sole living target is chosen without a needless RNG draw")
			var after_enemies: Array[Dictionary] = enemies.get_enemies()
			_check(after_enemies.size() == before_enemies.size(),
				label + ": the roster keeps its size")
			for index in range(after_enemies.size()):
				var expected_hp: int = int(before_enemies[index].get("hp", 0))
				var expected_block: int = int(before_enemies[index].get("block", 0))
				if index + 1 == target:
					expected_block -= absorbed
					expected_hp -= hp_loss
				_check(str(after_enemies[index].get("id", ""))
					== str(before_enemies[index].get("id", "")),
					label + ": enemy " + str(index + 1) + " keeps its id")
				_check(int(after_enemies[index].get("position", 0)) == index + 1,
					label + ": enemy " + str(index + 1) + " keeps its slot")
				_check(int(after_enemies[index].get("hp", -1)) == expected_hp
					and int(after_enemies[index].get("block", -1)) == expected_block,
					label + ": only the chosen enemy's Block and HP changed")
				if int(before_enemies[index].get("hp", 0)) == 0:
					_check(int(after_enemies[index].get("hp", -1)) == 0,
						label + ": a slain slot is never resurrected")
	var next_state: Dictionary = result.get("state", {})
	_check(not next_state.is_empty()
		and CombatTinkerV3TurretCards.is_pending_instance(next_state),
		label + ": the next state stays a well-formed pending instance")
	_check(int(next_state.get("remaining", -1)) == remaining_before - 1,
		label + ": the next state counts the consumed beat")
	_check(next_state.get("card_id") == state.get("card_id")
		and int(next_state.get("damage", 0)) == damage,
		label + ": the next state keeps its authentic card and damage")
	next_state["remaining"] = 99
	_check(int(state.get("remaining", -1)) == remaining_before,
		label + ": the next state is detached from the caller's instance")
	next_state["remaining"] = remaining_before - 1
	return result


## One complete seeded turret sequence on a real battle fixture: deploy, three end-turn beats and an inert
## fourth, recording every choice and the real RNG state so a replay can be compared exactly.
func _turret_trace(card_id: String, seed_value: int, enemy_count: int) -> Array:
	var resolver := CombatTinkerV3TurretCards.new()
	var party := _scrap_party(3)
	var deck := _scrap_deck([card_id], seed_value, 5)
	var enemies := _turret_enemies() if enemy_count == 3 else _turret_two_enemies()
	var deploy: Dictionary = resolver.play_card(deck, party, card_id, 0)
	var trace: Array = []
	if deploy.get("ok") != true:
		return trace
	var state: Dictionary = deploy.get("state", {})
	for beat in range(4):
		var rng_before: int = deck._rng.state
		var result: Dictionary = resolver.tick_turret(state, enemies, deck._rng)
		trace.append({
			"ok": result.get("ok"),
			"reason": result.get("reason"),
			"target": result.get("target_position"),
			"target_id": result.get("target_id"),
			"damage": result.get("damage"),
			"block_absorbed": result.get("block_absorbed"),
			"hp_loss": result.get("hp_loss"),
			"remaining": result.get("remaining"),
			"rng_consumed": result.get("rng_consumed"),
			"rng_before": rng_before,
			"rng_after": deck._rng.state,
			"enemies": enemies.get_enemies(),
		})
		if result.get("ok") == true:
			state = result["state"]
	return trace


## The exact turret deployment outcome: two energy paid and the held copy moved to discard; no HP, Block,
## counter or enemy change.
func _expected_turret_deploy(before: Dictionary, card_id: String) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - 2
	expected["state_energy"] = int(expected["state_energy"]) - 2
	var hand: Array = expected["hand"]
	_check(hand.count(card_id) == 1, "expected snapshot: exactly one deployed copy is held")
	hand.remove_at(hand.find(card_id))
	(expected["discard"] as Array).append(card_id)
	return expected


func _rejected_turret_play(resolver: CombatTinkerV3TurretCards, deck: CombatDeck,
		party: CombatParty, card_id: Variant, target: int, reason: String, label: String) -> void:
	var before := _scrap_snapshot(deck, party)
	var plan: Dictionary = resolver.preflight(deck, party, card_id, target)
	_check(plan.get("ok") == false and plan.get("reason") == reason,
		label + ": pure preflight also refuses with " + reason)
	_check(_scrap_snapshot(deck, party) == before,
		label + ": preflight itself changed no state")
	var result: Dictionary = resolver.play_card(deck, party, card_id, target)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(result.get("reason")) + ")")
	_check(_scrap_snapshot(deck, party) == before,
		label + ": unchanged energy, hand, piles, turn, party and RNG")


func _rejected_turret_tick(resolver: CombatTinkerV3TurretCards, state: Variant,
		enemies: CombatEnemies, rng: RandomNumberGenerator, reason: String, label: String) -> void:
	var state_before: Dictionary = {}
	if state is Dictionary:
		state_before = (state as Dictionary).duplicate(true)
	var enemy_before: Array = []
	if enemies != null:
		enemy_before = enemies.get_enemies()
	var rng_before: int = rng.state if rng != null else -1
	var result: Dictionary = resolver.tick_turret(state, enemies, rng)
	_check(result.get("ok") == false, label + ": refused")
	_check(result.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(result.get("reason")) + ")")
	if state is Dictionary:
		_check(state == state_before, label + ": the instance was not mutated")
	if enemies != null:
		_check(enemies.get_enemies() == enemy_before, label + ": the roster was not touched")
	if rng != null:
		_check(rng.state == rng_before, label + ": the RNG was not drawn")


## The authored catalog Spoolback Hound (enrage: true), with JSON's float max_hp normalized as the app does.
func _catalog_hound() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary and entry.get("id") == "spoolback_hound":
				var hound: Dictionary = entry.duplicate(true)
				hound["max_hp"] = int(hound["max_hp"])
				return hound
	return {}


## A fresh, genuinely paid three-beat instance of one printing.
func _enrage_turret(card_id: String) -> Dictionary:
	var deploy: Dictionary = CombatTinkerV3TurretCards.new().play_card(
		_scrap_deck([card_id], 503000, 5), _scrap_party(3), card_id, 0)
	_check(deploy.get("ok") == true, card_id + ": the Enrage fixture turret is a genuine paid deployment")
	return deploy.get("state", {})


## A real roster from `definitions`; slot 1 is brought to `hp`, given `block` and, when `stacks` >= 0, an
## explicit stored Enrage count.
func _hound_roster(definitions: Array, hp: int, block: int, stacks: int) -> CombatEnemies:
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid(), "Enrage fixture roster is valid")
	var max_hp: int = int(enemies.get_enemy(1).get("max_hp", 0))
	_check((hp == max_hp or enemies.apply_damage(1, max_hp - hp)) and (block == 0 or enemies.gain_block(1, block))
		and (stacks < 0 or enemies.set_enrage_stacks(1, stacks)), "Enrage fixture slot 1 is prepared")
	return enemies


## Cycle 363: every Wind-up Turret shot is a confirmed hit for the catalog Spoolback Hound's Enrage.
func _test_turret_enrage() -> void:
	var hound := _catalog_hound()
	_check(hound.get("enrage") == true and hound.get("max_hp") == 28,
		"Enrage fixture: the catalog Spoolback Hound carries enrage true and 28 max HP")
	var resolver := CombatTinkerV3TurretCards.new()
	var plain_keys: Array = resolver.tick_turret(_enrage_turret(TURRET_IDS[0]), _turret_two_enemies(),
		_scrap_rng(503100)).keys()
	plain_keys.sort()
	for card_id: String in TURRET_IDS:
		var damage := _turret_damage(card_id)
		# Fully Block-absorbed, partly blocked, HP-damaging, overkill and capped shots on a lone Hound.
		for case in [["block-absorbed", 28, damage + 2, -1], ["partly blocked", 28, 1, 1],
				["hp-damaging", 28, 0, 0], ["overkill", 2, 0, 2], ["capped", 28, 0, 3]]:
			var label: String = card_id + " " + str(case[0])
			var enemies := _hound_roster([hound], case[1], case[2], case[3])
			var stacks_before: int = maxi(0, int(case[3]))
			var tick := _tick_checked(resolver, _enrage_turret(card_id), enemies, _scrap_rng(503200), label)
			var expected: int = mini(stacks_before + 1, CombatEnemyKeywordRules.ENRAGE_MAX_STACKS)
			var after := enemies.get_enemy(1)
			_check(after.get("enrage_stacks") == expected,
				label + ": the shot commits exactly one Enrage stack, capped at three")
			_check(after.get("enrage") == true and after.get("id") == "spoolback_hound"
				and after.get("max_hp") == 28 and after.get("position") == 1,
				label + ": the Hound keeps its authored identity and Enrage flag")
			var keys: Array = tick.keys()
			keys.sort()
			_check(keys == plain_keys, label + ": the tick receipt keeps exactly its existing keys")
			if case[0] == "overkill":
				_check(after.get("hp") == 0 and tick.get("hp_loss") == 2, label + ": overkill clamps at the pre-hit HP")
			else:
				_check(CombatEnemyPhase._enrage_attack_bonus(enemies, 1) == expected * 2,
					label + ": the Hound's next attack gains +2 per stored stack")
		# One instance's three beats each add one stack; a fourth beat is inert.
		var chain := _hound_roster([hound], 28, 0, -1)
		var state := _enrage_turret(card_id)
		for beat in range(3):
			var tick := _tick_checked(resolver, state, chain, _scrap_rng(503300), card_id + " chain " + str(beat + 1))
			state = tick.get("state", {})
			_check(chain.get_enemy(1).get("enrage_stacks") == beat + 1
				and chain.get_enemy(1).get("hp") == 28 - damage * (beat + 1),
				card_id + " chain beat " + str(beat + 1) + ": one stack per shot")
		_rejected_turret_tick(resolver, state, chain, _scrap_rng(503301), "turret_expired",
			card_id + " chain fourth tick")
		# A non-Enrage foe, absent or explicitly false, never gains a stack key.
		for plain in [{"id": "straw_dummy", "max_hp": 30}, {"id": "straw_dummy", "max_hp": 30, "enrage": false}]:
			var foes := CombatEnemies.new([plain])
			_tick_checked(resolver, _enrage_turret(card_id), foes, _scrap_rng(503400), card_id + " non-Enrage foe")
			_check(not foes.get_enemy(1).has("enrage_stacks"), card_id + ": a non-Enrage foe gains no Enrage stack")
	# Two turrets in one end-turn boundary: one stack per shot.
	var both := _hound_roster([hound], 28, 0, -1)
	var first := _enrage_turret(TURRET_IDS[0])
	var second := _enrage_turret(TURRET_IDS[1])
	_tick_checked(resolver, first, both, _scrap_rng(503500), "two turrets first shot")
	_tick_checked(resolver, second, both, _scrap_rng(503500), "two turrets second shot")
	_check(both.get_enemy(1).get("enrage_stacks") == 2 and both.get_enemy(1).get("hp") == 21,
		"two independent turrets each add one stack to the same Hound")
	# Random targeting, RNG use and expiry are identical to a roster whose Hound has no Enrage.
	for seed_value in [503600, 503601, 503602]:
		var calm := hound.duplicate(true)
		calm.erase("enrage")
		var live := CombatEnemies.new([hound, {"id": "quilt_hog", "max_hp": 24}])
		var control := CombatEnemies.new([calm, {"id": "quilt_hog", "max_hp": 24}])
		var live_rng := _scrap_rng(seed_value)
		var control_rng := _scrap_rng(seed_value)
		var live_state := _enrage_turret(TURRET_IDS[1])
		var control_state := live_state.duplicate(true)
		var hits := 0
		for beat in range(3):
			var label := "seed " + str(seed_value) + " beat " + str(beat + 1)
			var tick := _tick_checked(resolver, live_state, live, live_rng, label + " Enrage roster")
			var oracle := _tick_checked(resolver, control_state, control, control_rng, label + " control roster")
			_check(tick.get("target_position") == oracle.get("target_position")
				and live_rng.state == control_rng.state and tick.get("rng_consumed") == oracle.get("rng_consumed")
				and tick.get("remaining") == oracle.get("remaining"),
				label + ": Enrage changes no target choice, RNG draw or expiry")
			if tick.get("target_position") == 1:
				hits += 1
			live_state = tick.get("state", {})
			control_state = oracle.get("state", {})
		_check(int(live.get_enemy(1).get("enrage_stacks", 0)) == hits and not live.get_enemy(2).has("enrage_stacks")
			and not control.get_enemy(1).has("enrage_stacks"),
			"seed " + str(seed_value) + ": only shots on the Hound add stacks; other foes gain none")
	# A Hound slain before the shot is never retargeted and gains nothing.
	var slain := CombatEnemies.new([hound, {"id": "quilt_hog", "max_hp": 24}])
	_check(slain.apply_damage(1, 28) and slain.is_slain(1), "slain Hound fixture")
	var slain_state := _enrage_turret(TURRET_IDS[0])
	for beat in range(3):
		var tick := _tick_checked(resolver, slain_state, slain, _scrap_rng(503700), "slain Hound beat " + str(beat + 1))
		_check(tick.get("target_position") == 2, "slain Hound beat " + str(beat + 1) + ": the living foe is hit")
		slain_state = tick.get("state", {})
	_check(not slain.get_enemy(1).has("enrage_stacks") and slain.get_enemy(1).get("hp") == 0,
		"a slain Hound gains no stack and stays slain")
	# Malformed Enrage metadata on any living candidate refuses the tick before anything changes.
	for bad in [{"enrage": "yes"}, {"enrage": 1}, {"enrage_stacks": 4}, {"enrage_stacks": -1},
			{"enrage_stacks": "2"}, {"enrage_stacks": 2.0}]:
		for slot in [1, 2]:
			var records: Array = [hound.duplicate(true), {"id": "quilt_hog", "max_hp": 24}]
			records[slot - 1].merge(bad, true)
			var foes := CombatEnemies.new(records)
			_rejected_turret_tick(resolver, _enrage_turret(TURRET_IDS[0]), foes, _scrap_rng(503800), "invalid_enrage",
				"malformed " + str(bad) + " on slot " + str(slot))


## ---------------------------------------------------------------------------
## Brass Casing / Brass Casing+ and Spring Clamp / Spring Clamp+: paid single-target attacks.
## ---------------------------------------------------------------------------


## Independent printed damage, Weak and Combat Scrap for the four casing/clamp printings.
func _casing_clamp_table(card_id: String) -> Dictionary:
	match card_id:
		CASING:
			return {"damage": 4, "weak": 0, "scrap": 1, "is_upgrade": false}
		CASING_PLUS:
			return {"damage": 6, "weak": 0, "scrap": 1, "is_upgrade": true}
		CLAMP:
			return {"damage": 3, "weak": 1, "scrap": 1, "is_upgrade": false}
		CLAMP_PLUS:
			return {"damage": 4, "weak": 1, "scrap": 1, "is_upgrade": true}
	return {}


## AC1 (catalog half): the resolver authenticates exactly the four authored casings/clamps and nothing else.
func _test_casing_clamp_catalog_contract() -> void:
	var catalog := V3TinkerPoolCards.new()
	var resolver := CombatTinkerV3CasingClampCards.new()
	var expected := {
		CASING: {
			"display": "Brass Casing", "damage": 4, "weak": 0,
			"effects": {"damage": 4, "combat_scrap_gain": 1},
		},
		CASING_PLUS: {
			"display": "Brass Casing+", "damage": 6, "weak": 0,
			"effects": {"damage": 6, "combat_scrap_gain": 1},
		},
		CLAMP: {
			"display": "Spring Clamp", "damage": 3, "weak": 1,
			"effects": {"damage": 3, "weak": 1, "combat_scrap_gain": 1},
		},
		CLAMP_PLUS: {
			"display": "Spring Clamp+", "damage": 4, "weak": 1,
			"effects": {"damage": 4, "weak": 1, "combat_scrap_gain": 1},
		},
	}
	# Independent arithmetic: the exact printed numbers, never a formula copied back from the resolver.
	for card_id: String in CASING_CLAMP_IDS:
		var table := _casing_clamp_table(card_id)
		var row: Dictionary = expected[card_id]
		_check(not table.is_empty() and table["damage"] == row["damage"]
			and table["weak"] == row["weak"] and table["scrap"] == 1,
			card_id + " independently prints its damage, Weak and one Combat Scrap")
		var record: Dictionary = catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + " is authored in the v3 Tinker catalog")
		if record.is_empty():
			continue
		_check(record.get("display_name") == row["display"], card_id + " display name")
		_check(record.get("owner") == "tinker", card_id + " is owned by Tinker")
		_check(record.get("cost") == 1, card_id + " prints cost 1")
		_check(record.get("from_positions") == [2, 3], card_id + " prints FROM 2-3")
		_check(record.get("target_kind") == "enemy_single", card_id + " targets one enemy")
		_check(record.get("to_positions") == [1, 2, 3], card_id + " prints TO 1-3")
		_check(record.get("effects") == row["effects"], card_id + " prints its exact effects")
		_check(record.get("effects").get("combat_scrap_gain") == 1,
			card_id + " prints exactly one Combat Scrap")
		_check(not record.get("effects", {}).has("scraps")
			and not record.get("effects", {}).has("scrap_cost"),
			card_id + " never reads or spends wallet scraps")
		_check(not record.has("upgrade_of"), card_id + " links with base_id/upgrade_id/is_upgrade")
		var base_id: String = CLAMP if card_id.begins_with(CLAMP) else CASING
		_check(record.get("base_id") == base_id and record.get("upgrade_id") == base_id + "_plus"
			and record.get("is_upgrade") == table["is_upgrade"],
			card_id + " preserves its base/+ link")
		_check(resolver.is_supported_card(card_id), card_id + " is a supported casing/clamp card")
		_check(CombatTinkerV3CasingClampCards.is_authentic_definition(record, card_id),
			card_id + " passes the definition authenticator")
		_check(CombatTinkerV3CasingClampCards.casing_clamp_definition(card_id) == record,
			card_id + " resolves to its exact detached catalog record")

	# Detached: mutating a resolved record cannot rewrite what the next resolution returns.
	var sample: Dictionary = CombatTinkerV3CasingClampCards.casing_clamp_definition(CLAMP)
	_check(not sample.is_empty(), "casing/clamp resolution fixture loaded")
	if not sample.is_empty():
		sample["effects"]["damage"] = 900
		sample["effects"]["weak"] = 9
		sample["from_positions"].clear()
		sample["cost"] = 0
		_check(CombatTinkerV3CasingClampCards.casing_clamp_definition(CLAMP)
			== catalog.get_definition(CLAMP),
			"a mutated casing/clamp definition cannot poison later resolutions")

	# Every other v3 Tinker card (base and plus) is unrelated to this service.
	var unrelated: Array[String] = []
	for base_id in catalog.get_pool_card_ids():
		if not CASING_CLAMP_IDS.has(base_id):
			unrelated.append(base_id)
		var upgrade_id: String = catalog.get_upgrade_id(base_id)
		if not upgrade_id.is_empty() and not CASING_CLAMP_IDS.has(upgrade_id):
			unrelated.append(upgrade_id)
	_check(unrelated.has("tinker_v3_gear_brace") and unrelated.has("tinker_v3_scrapstorm_plus"),
		"unrelated-card fixture really contains other authentic v3 Tinker cards (precondition)")
	for other_id: String in unrelated:
		_check(CombatTinkerV3CasingClampCards.casing_clamp_definition(other_id).is_empty(),
			other_id + " does not resolve as a casing/clamp attack")
		_check(not resolver.is_supported_card(other_id),
			other_id + " is not a supported casing/clamp card")

	# The v2 Tinker pool and foreign spellings are never casing/clamp printings.
	var forged: Array = ["tinker_rivet_shot", "tinker_pop_shot", "tinker_v3_brass_casing+",
		"tinker_v3_brass_casing_plus_plus", "tinker_v3_spring_clamp_", "brass_casing",
		"TINKER_V3_BRASS_CASING", "", "tinker_v3_missing_card", StringName(CASING),
		null, 0, 3.5, false, [], {}]
	for other_id: Variant in forged:
		_check(CombatTinkerV3CasingClampCards.casing_clamp_definition(other_id).is_empty(),
			"forged or non-string ID never resolves as a casing/clamp attack: " + str(other_id))
		_check(not resolver.is_supported_card(other_id),
			"forged or non-string ID is never a supported casing/clamp card: " + str(other_id))

	# Adversarial copies of the real Brass Casing record: each altered contract field is refused.
	var base_record: Dictionary = catalog.get_definition(CASING)
	_check(not base_record.is_empty()
		and CombatTinkerV3CasingClampCards.is_authentic_definition(base_record, CASING),
		"authenticator positive fixture really is the authored Brass Casing")
	var mutations: Array[Callable] = [
		func(record: Dictionary) -> void: record["effects"]["damage"] = 5,
		func(record: Dictionary) -> void: record["effects"]["damage"] = 4.0,
		func(record: Dictionary) -> void: record["effects"]["damage"] = "4",
		func(record: Dictionary) -> void: record["effects"]["combat_scrap_gain"] = 2,
		func(record: Dictionary) -> void: record["effects"]["combat_scrap_gain"] = 1.0,
		func(record: Dictionary) -> void: record["effects"].erase("combat_scrap_gain"),
		func(record: Dictionary) -> void: record["effects"]["weak"] = 1,
		func(record: Dictionary) -> void: record["effects"]["scraps"] = 1,
		func(record: Dictionary) -> void: record["effects"] = "damage",
		func(record: Dictionary) -> void: record["cost"] = 0,
		func(record: Dictionary) -> void: record["cost"] = 2,
		func(record: Dictionary) -> void: record["cost"] = 1.0,
		func(record: Dictionary) -> void: record["owner"] = "warden",
		func(record: Dictionary) -> void: record["from_positions"] = [1, 2, 3],
		func(record: Dictionary) -> void: record["from_positions"] = ["2", "3"],
		func(record: Dictionary) -> void: record["to_positions"] = [],
		func(record: Dictionary) -> void: record["target_kind"] = "self",
		func(record: Dictionary) -> void: record["id"] = CASING_PLUS,
		func(record: Dictionary) -> void: record["is_upgrade"] = true,
		func(record: Dictionary) -> void: record["base_id"] = CASING_PLUS,
		func(record: Dictionary) -> void: record.erase("upgrade_id"),
		func(record: Dictionary) -> void: record["upgrade_of"] = CASING,
		func(record: Dictionary) -> void: record.erase("to_positions"),
		func(record: Dictionary) -> void: record.erase("effects"),
	]
	for index in range(mutations.size()):
		var tampered: Dictionary = base_record.duplicate(true)
		mutations[index].call(tampered)
		_check(not CombatTinkerV3CasingClampCards.is_authentic_definition(tampered, CASING),
			"tampered casing/clamp record " + str(index) + " is refused")
	# Spring Clamp's Weak is part of the printed effects: removing or changing it is a foreign record.
	var clamp_record: Dictionary = catalog.get_definition(CLAMP)
	for clamp_mutation: Callable in [
			func(record: Dictionary) -> void: record["effects"]["weak"] = 0,
			func(record: Dictionary) -> void: record["effects"]["weak"] = 2,
			func(record: Dictionary) -> void: record["effects"]["weak"] = 1.0,
			func(record: Dictionary) -> void: record["effects"].erase("weak")]:
		var tampered_clamp: Dictionary = clamp_record.duplicate(true)
		clamp_mutation.call(tampered_clamp)
		_check(not CombatTinkerV3CasingClampCards.is_authentic_definition(tampered_clamp, CLAMP),
			"a Spring Clamp record without exactly Weak 1 is refused")
	_check(not CombatTinkerV3CasingClampCards.is_authentic_definition(
		catalog.get_definition(CASING_PLUS), CASING),
		"an upgraded record cannot authenticate as its base ID")
	_check(not CombatTinkerV3CasingClampCards.is_authentic_definition(
		catalog.get_definition(CASING), CASING_PLUS),
		"a base record cannot authenticate as its upgraded ID")
	_check(not CombatTinkerV3CasingClampCards.is_authentic_definition(
		catalog.get_definition(CLAMP), CASING),
		"a Spring Clamp record cannot authenticate as Brass Casing")


## A real three-enemy roster whose original slots 1-3 are all living.
func _casing_clamp_enemies() -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "straw_dummy", "max_hp": 30},
		{"id": "quilt_hog", "max_hp": 24},
		{"id": "moth_swarm", "max_hp": 18},
	])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3,
		"three-enemy fixture really is a valid living roster")
	return enemies


## AC2: each of the four held printings pays one energy, discards one copy, lands the printed raw hit
## through Block before HP, adds Weak 1 only for Spring Clamp (also when fully Blocked) and adds one
## Combat Scrap to the living Tinker only.
func _test_casing_clamp_paid_plays() -> void:
	var resolver := CombatTinkerV3CasingClampCards.new()
	var cases := [
		{"id": CASING, "seat": 2, "target": 1, "blocks": 0, "scrap": 0},
		{"id": CASING, "seat": 3, "target": 3, "blocks": 1, "scrap": 2},
		{"id": CASING_PLUS, "seat": 2, "target": 2, "blocks": 2, "scrap": 1},
		{"id": CASING_PLUS, "seat": 3, "target": 1, "blocks": 0, "scrap": 0},
		{"id": CLAMP, "seat": 2, "target": 3, "blocks": 0, "scrap": 0},
		{"id": CLAMP, "seat": 3, "target": 1, "blocks": 20, "scrap": 2},
		{"id": CLAMP_PLUS, "seat": 2, "target": 2, "blocks": 2, "scrap": 0},
		{"id": CLAMP_PLUS, "seat": 3, "target": 3, "blocks": 20, "scrap": 1},
	]
	var seed_value := 601000
	for entry: Dictionary in cases:
		var card_id: String = entry["id"]
		var table := _casing_clamp_table(card_id)
		var raw: int = table["damage"]
		var weak: int = table["weak"]
		var seat: int = entry["seat"]
		var target: int = entry["target"]
		var target_blocks: int = entry["blocks"]
		var scrap: int = entry["scrap"]
		var label := card_id + " from seat " + str(seat) + " at enemy " + str(target)
		var party := _overload_party(seat, scrap)
		var deck := _scrap_deck([card_id], seed_value, 5)
		var enemies := _casing_clamp_enemies()
		if target_blocks > 0:
			_check(enemies.gain_block(target, target_blocks),
				label + ": the fixture really grants the chosen enemy Block")
		var enemy_before: Dictionary = enemies.get_enemy(target)
		var block_absorbed: int = mini(int(enemy_before["block"]), raw)
		var hp_loss: int = mini(int(enemy_before["hp"]), raw - block_absorbed)
		if target_blocks >= raw:
			_check(block_absorbed == raw and hp_loss == 0,
				label + ": the Block fixture really absorbs the whole raw hit")
		else:
			_check(block_absorbed == int(enemy_before["block"]) and hp_loss > 0,
				label + ": the Block fixture really lets HP loss through")
		var wallet := {"gold": 9, "scraps": 4}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var rng_before: int = deck._rng.state
		var before := _battle_snapshot(deck, party, enemies)
		# The pure preflight accepts the same request and changes nothing.
		var plan: Dictionary = resolver.preflight(deck, party, enemies, card_id, target)
		_check(plan.get("ok") == true and plan.get("reason") == "legal",
			label + ": read-only preflight accepts the funded play")
		_check(plan.get("raw_damage") == raw and plan.get("weak") == weak
			and plan.get("combat_scrap_before") == scrap,
			label + ": preflight reports the printed damage, Weak and counter")
		_check(_battle_snapshot(deck, party, enemies) == before,
			label + ": preflight changed no battle state")
		var result: Dictionary = resolver.play_card(deck, party, enemies, card_id, target)
		_check(result.get("ok") == true and result.get("reason") == "applied",
			label + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == 1,
			label + ": receipt names the authentic card and its one energy")
		_check(result.get("owner_position") == seat and result.get("target_position") == target,
			label + ": receipt reports the real owner seat and the chosen enemy")
		_check(result.get("raw_damage") == raw and result.get("damage") == raw,
			label + ": exactly " + str(raw) + " unmodified printed raw damage")
		_check(result.get("block_absorbed") == block_absorbed and result.get("hp_loss") == hp_loss,
			label + ": Block absorbed " + str(block_absorbed) + " before " + str(hp_loss) + " HP")
		_check(result.get("combat_scrap_before") == scrap
			and result.get("combat_scrap_gained") == 1
			and result.get("combat_scrap_after") == scrap + 1,
			label + ": receipt reports exactly one Combat Scrap from " + str(scrap))
		_check(result.get("weak") == weak and result.get("statuses")
			== ({"weak": weak} if weak > 0 else {}),
			label + ": receipt reports the printed Weak only")
		_check(result.get("enemy_weak_before") == 0 and result.get("enemy_weak_after") == weak,
			label + ": the enemy Weak stack changes only by the printed amount")
		_check(result.get("energy_before") == 3 and result.get("energy_after") == 2,
			label + ": receipt reports the exact energy change")
		_check(not result.has("scraps") and not result.has("wallet"),
			label + ": receipt carries no wallet state")
		_check(deck.energy == 2, label + ": exactly one energy was paid")
		_check(deck.hand.count(card_id) == 0 and deck.discard_pile == [card_id],
			label + ": exactly the held copy reached the discard")
		_check(deck._rng.state == rng_before, label + ": no RNG was consumed")
		_check(party.get_hero(seat).get("combat_scrap") == scrap + 1
			and party._heroes[seat - 1].get("combat_scrap") == scrap + 1,
			label + ": the Tinker's authoritative record gained exactly one Combat Scrap")
		for position: int in [1, 2, 3]:
			if position == seat:
				continue
			_check(party.get_hero(position).get("combat_scrap") == 2,
				label + ": teammate seat " + str(position) + " keeps its own counter")
			_check(party.get_hero(position).get("hp") == before["party"][position - 1]["hp"],
				label + ": teammate seat " + str(position) + " keeps its HP")
		_check(party.get_hero(seat).get("hp") == 26 and party.get_hero(seat).get("block") == 0,
			label + ": the Tinker's HP and Block are untouched")
		_check(enemies.get_enemy(target).get("hp") == int(enemy_before["hp"]) - hp_loss
			and enemies.get_enemy(target).get("block")
				== int(enemy_before["block"]) - block_absorbed,
			label + ": only the chosen enemy's Block and HP changed")
		_check(enemies.get_enemy(target).get("statuses", {}).get("weak", 0) == weak,
			label + ": the chosen enemy carries exactly the printed Weak")
		for position: int in range(1, enemies.get_enemies().size() + 1):
			if position == target:
				continue
			_check(enemies.get_enemy(position) == before["enemies"][position - 1],
				label + ": enemy " + str(position) + " is completely untouched")
		if weak > 0:
			# The existing status rules give the Weak token its 25% reduction (8 -> 6).
			_check(CombatStatuses.new().adjusted_attack_damage(8,
				enemies.get_enemy(target).get("statuses", {}), {}) == 6,
				label + ": the applied Weak reduces that enemy's attack by 25%")
		_check(wallet == wallet_before, label + ": the run wallet's scraps are never modified")
		_check(_battle_snapshot(deck, party, enemies)
			== _expected_casing_clamp(before, card_id, seat, target, raw, weak),
			label + ": exact hand, piles, energy, turn, party, counters, enemy, Weak and RNG state")
		seed_value += 1

	# Weak is additive on the same enemy and leaves unrelated statuses alone.
	var stack_party := _overload_party(2, 1)
	var stack_deck := _scrap_deck([CLAMP], 601900, 5)
	var stack_enemies := _casing_clamp_enemies()
	_check(stack_enemies.apply_statuses({2: {"weak": 2, "exposed": 1}}),
		"stacked-status fixture really seeds Weak 2 and Exposed 1")
	var stack_before := _battle_snapshot(stack_deck, stack_party, stack_enemies)
	var stack_result: Dictionary = resolver.play_card(stack_deck, stack_party, stack_enemies, CLAMP, 2)
	_check(stack_result.get("ok") == true and stack_result.get("enemy_weak_before") == 2
		and stack_result.get("enemy_weak_after") == 3,
		"Spring Clamp adds exactly one Weak stack on top of an existing stack")
	_check(stack_enemies.get_enemy(2).get("statuses") == {"weak": 3, "exposed": 1},
		"Spring Clamp leaves the unrelated Exposed stack untouched")
	_check(_battle_snapshot(stack_deck, stack_party, stack_enemies)
		== _expected_casing_clamp(stack_before, CLAMP, 2, 2, 3, 1),
		"the stacked-status play matches the exact expected battle state")

	# Brass Casing never adds Weak, even to an enemy that already carries it.
	var brass_party := _overload_party(3, 0)
	var brass_deck := _scrap_deck([CASING], 601901, 5)
	var brass_enemies := _casing_clamp_enemies()
	_check(brass_enemies.apply_statuses({1: {"weak": 2}}),
		"Brass fixture really seeds an existing Weak stack")
	var brass_result: Dictionary = resolver.play_card(brass_deck, brass_party, brass_enemies, CASING, 1)
	_check(brass_result.get("ok") == true and brass_result.get("weak") == 0
		and brass_result.get("enemy_weak_before") == 2 and brass_result.get("enemy_weak_after") == 2,
		"Brass Casing adds no Weak of its own")
	_check(brass_enemies.get_enemy(1).get("statuses") == {"weak": 2},
		"Brass Casing leaves the enemy's existing Weak stack alone")


## AC2 (second half): a second genuine held copy is a separate paid action, never bundled into the first.
func _test_casing_clamp_second_copy() -> void:
	var resolver := CombatTinkerV3CasingClampCards.new()
	var party := _overload_party(2, 0)
	var deck := _casing_clamp_duplicate_deck(601950)
	var enemies := _casing_clamp_enemies()
	var rng_before: int = deck._rng.state
	_check(deck.hand.count(CASING) == 2 and deck.energy == 3,
		"second-copy fixture really holds two copies on a real three-energy turn")
	var first: Dictionary = resolver.play_card(deck, party, enemies, CASING, 1)
	_check(first.get("ok") == true and first.get("combat_scrap_after") == 1,
		"the first copy is one paid action and gains one Combat Scrap")
	_check(deck.energy == 2 and deck.hand.count(CASING) == 1
		and deck.discard_pile == [CASING]
		and enemies.get_enemy(1).get("hp") == 26 and party.get_hero(2).get("combat_scrap") == 1,
		"the first play spends one energy, discards one copy and hits once")
	var after_first := _battle_snapshot(deck, party, enemies)
	var second: Dictionary = resolver.play_card(deck, party, enemies, CASING, 1)
	_check(second.get("ok") == true and second.get("combat_scrap_after") == 2,
		"the second held copy is played through its own paid action")
	_check(deck.energy == 1 and deck.hand.count(CASING) == 0
		and deck.discard_pile == [CASING, CASING]
		and enemies.get_enemy(1).get("hp") == 22 and party.get_hero(2).get("combat_scrap") == 2,
		"the second play spends another energy, discards the other copy and hits once")
	_check(deck._rng.state == rng_before, "neither copy play consumed the seeded RNG")
	_check(_battle_snapshot(deck, party, enemies)
		== _expected_casing_clamp(after_first, CASING, 2, 1, 4, 0),
		"the second play matches the exact expected battle state")
	var third: Dictionary = resolver.play_card(deck, party, enemies, CASING, 1)
	_check(third.get("ok") == false and third.get("reason") == "card_not_held",
		"no third claim is possible without another held copy")
	_check(deck.energy == 1 and party.get_hero(2).get("combat_scrap") == 2,
		"the refused third claim spends nothing")


## AC3: every failed identity, turn, owner, seat, energy, held-copy, target, roster, status or counter
## precondition is refused with its reason and mutates no deck, party, enemy, counter or RNG state.
func _test_casing_clamp_refusals() -> void:
	var resolver := CombatTinkerV3CasingClampCards.new()
	var party := _overload_party(2, 3)
	var deck := _scrap_deck([CASING], 602100, 5)
	var enemies := _casing_clamp_enemies()
	var wallet := {"gold": 9, "scraps": 4}
	var wallet_before: Dictionary = wallet.duplicate(true)

	_rejected_casing_clamp(resolver, null, party, enemies, CASING, 1, "invalid_request", "null deck")
	_rejected_casing_clamp(resolver, deck, null, enemies, CASING, 1, "invalid_request", "null party")
	_rejected_casing_clamp(resolver, deck, party, null, CASING, 1, "invalid_request", "null enemies")

	# An inactive turn is never paid, even with a real copy in hand.
	var inactive := CombatDeck.new([CASING], _scrap_rng(602101))
	inactive.hand.append(CASING)
	_check(not inactive.turn_active and inactive.hand.has(CASING),
		"inactive fixture really holds a copy outside a turn")
	_rejected_casing_clamp(resolver, inactive, party, enemies, CASING, 1, "inactive_turn",
		"inactive turn")

	# Unsupported card identities: other authentic Tinker cards, v2 cards, forged spellings.
	var wrong_ids: Array = ["tinker_v3_gear_brace", "tinker_v3_spare_screws",
		"tinker_v3_overload", "tinker_v3_scrapstorm", "tinker_v3_wind_up_turret",
		"tinker_pop_shot", "tinker_rivet_shot", "tinker_v3_brass_casing+",
		"tinker_v3_brass_casing_plus_plus", "tinker_v3_brass_casing_", "brass_casing",
		"TINKER_V3_BRASS_CASING", "", StringName(CASING), null, 0, 3.5, false, [], {}]
	for wrong_id: Variant in wrong_ids:
		_rejected_casing_clamp(resolver, deck, party, enemies, wrong_id, 1, "unsupported_card",
			"unsupported ID " + str(wrong_id))
	# An authentic Spring Clamp the shared hand does not hold is still unheld.
	_rejected_casing_clamp(resolver, deck, party, enemies, CLAMP, 1, "card_not_held",
		"authentic but unheld Spring Clamp")

	# An unaffordable copy is refused without a partial charge.
	var poor := _scrap_deck([CASING], 602102, 5)
	poor.combat_state.energy = 0
	_check(poor.energy == 0 and poor.hand.has(CASING),
		"short-energy fixture really holds a copy with no energy")
	_rejected_casing_clamp(resolver, poor, party, enemies, CASING, 1, "insufficient_energy",
		"no energy")

	# Both printings are FROM 2-3: the front seat is not a legal owner.
	var front_party := _overload_party(1, 3)
	var front_deck := _scrap_deck([CASING], 602103, 5)
	_rejected_casing_clamp(resolver, front_deck, front_party, enemies, CASING, 1,
		"owner_illegal_position", "Brass Casing from seat 1")

	# A party without Tinker never authorizes the play.
	var absent_owner := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "yarn_ranger", "max_hp": 28}])
	_check(absent_owner.is_valid() and absent_owner.get_hero(2).get("id") == "seamstress",
		"absent-owner fixture is a valid party without a Tinker")
	_rejected_casing_clamp(resolver, deck, absent_owner, enemies, CASING, 1, "owner_missing",
		"absent Tinker")

	# Duplicate or malformed hero records never grant authority.
	var duplicate := _overload_party(2, 3)
	duplicate._heroes[0]["id"] = "tinker"
	_check(duplicate.get_hero(1).get("id") == "tinker"
		and duplicate.get_hero(2).get("id") == "tinker",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected_casing_clamp(resolver, deck, duplicate, enemies, CASING, 1, "invalid_party",
		"duplicate Tinker identity")
	var bad_hp := _overload_party(2, 3)
	bad_hp._heroes[0]["hp"] = 999
	_rejected_casing_clamp(resolver, deck, bad_hp, enemies, CASING, 1, "invalid_party",
		"malformed hero HP")
	var bad_position := _overload_party(2, 3)
	bad_position._heroes[0]["position"] = 3
	_rejected_casing_clamp(resolver, deck, bad_position, enemies, CASING, 1, "invalid_party",
		"malformed hero position")
	var short_party := CombatParty.new([{"id": "tinker", "max_hp": 26}])
	_rejected_casing_clamp(resolver, deck, short_party, enemies, CASING, 1, "invalid_party",
		"invalid one-hero party")

	# A torn (downed) owner may not play.
	var torn_owner := _overload_party(3, 3)
	_check(torn_owner.apply_damage(3, 26) and torn_owner.is_downed(3),
		"torn-owner fixture really has a downed Tinker")
	_rejected_casing_clamp(resolver, deck, torn_owner, enemies, CASING, 2, "owner_downed",
		"downed Tinker")

	# A slain enemy and out-of-range slots are never hit; slots never compact.
	var slain_targets := _casing_clamp_enemies()
	_check(slain_targets.apply_damage(1, 30) and slain_targets.is_slain(1),
		"slain-target fixture really has a dead front enemy")
	_rejected_casing_clamp(resolver, deck, party, slain_targets, CASING, 1, "target_slain",
		"slain enemy")
	for slot: int in [0, 4, -1, 99]:
		_rejected_casing_clamp(resolver, deck, party, enemies, CASING, slot, "invalid_target",
			"illegal target slot " + str(slot))

	# A malformed stored counter is never coerced into a legal number.
	var text_counter := _overload_party(2, 3)
	text_counter._heroes[1]["combat_scrap"] = "3"
	_rejected_casing_clamp(resolver, deck, text_counter, enemies, CASING, 1,
		"malformed_combat_scrap", "string Combat Scrap")
	var negative_counter := _overload_party(2, 3)
	negative_counter._heroes[1]["combat_scrap"] = -1
	_rejected_casing_clamp(resolver, deck, negative_counter, enemies, CASING, 1,
		"malformed_combat_scrap", "negative Combat Scrap")
	var float_counter := _overload_party(2, 3)
	float_counter._heroes[1]["combat_scrap"] = 1.0
	_rejected_casing_clamp(resolver, deck, float_counter, enemies, CASING, 1,
		"malformed_combat_scrap", "float Combat Scrap")

	# The printed one-scrap gain must stay representable.
	var overflow_counter := _overload_party(2, 3)
	overflow_counter._heroes[1]["combat_scrap"] = CombatParty.MAX_INT
	_rejected_casing_clamp(resolver, deck, overflow_counter, enemies, CASING, 1,
		"combat_scrap_overflow", "Combat Scrap counter overflow")

	# Invalid or malformed enemy rosters fail closed.
	var empty_roster := CombatEnemies.new([])
	_check(not empty_roster.is_valid(), "empty-roster fixture really is invalid")
	_rejected_casing_clamp(resolver, deck, party, empty_roster, CASING, 1, "invalid_enemies",
		"empty enemy roster")
	var bad_enemy_hp := _casing_clamp_enemies()
	bad_enemy_hp._enemies[0]["hp"] = 999
	_rejected_casing_clamp(resolver, deck, party, bad_enemy_hp, CASING, 1, "invalid_enemies",
		"malformed enemy HP")
	var duplicate_enemy := _casing_clamp_enemies()
	duplicate_enemy._enemies[1]["id"] = duplicate_enemy._enemies[0]["id"]
	_rejected_casing_clamp(resolver, deck, party, duplicate_enemy, CASING, 1, "invalid_enemies",
		"duplicate enemy identity")

	# Malformed status data anywhere in the roster is refused before the hit or the counter changes.
	for bad_statuses: Variant in [{"weak": "1"}, {"weak": -1}, {"weak": 1.0},
			{"invented": 1}, {"weak": 1, "invented": 1}, "weak", []]:
		var bad_status_roster := _casing_clamp_enemies()
		bad_status_roster._enemies[1]["statuses"] = bad_statuses
		_rejected_casing_clamp(resolver, deck, party, bad_status_roster, CASING, 1,
			"invalid_statuses", "malformed enemy statuses " + str(bad_statuses))
	# The printed Weak addition itself must stay representable.
	var weak_overflow := _casing_clamp_enemies()
	weak_overflow._enemies[0]["statuses"] = {"weak": CombatParty.MAX_INT}
	_rejected_casing_clamp(resolver, _scrap_deck([CLAMP], 602104, 5), party, weak_overflow, CLAMP, 1,
		"status_overflow", "Weak stack overflow")

	_check(wallet == wallet_before, "every refusal left the run wallet's scraps untouched")

	# The shared fixture deck, party and roster survived every refusal untouched.
	_check(deck.energy == 3 and deck.hand.has(CASING) and deck.discard_pile.is_empty()
		and party.get_hero(2).get("combat_scrap") == 3
		and enemies.get_enemy(1).get("hp") == 30 and enemies.get_enemy(1).get("block") == 0
		and enemies.get_enemy(2).get("hp") == 24 and not enemies.get_enemy(1).has("statuses"),
		"every refusal left the shared fixture deck, party and enemies untouched")

	# A refused attempt never poisons the next authentic play on the same objects.
	var retry: Dictionary = resolver.play_card(deck, party, enemies, CASING, 2)
	_check(retry.get("ok") == true and retry.get("raw_damage") == 4,
		"the authentic play then succeeds once with 4 raw damage")
	_check(deck.energy == 2 and deck.discard_pile == [CASING]
		and party.get_hero(2).get("combat_scrap") == 4
		and enemies.get_enemy(2).get("hp") == 20 and enemies.get_enemy(1).get("hp") == 30,
		"the retry paid once, gained one scrap and hit only the chosen enemy")
	_rejected_casing_clamp(resolver, deck, party, enemies, CASING, 2, "card_not_held",
		"a second claim of the same copy")


## A genuine seeded shared hand already holding two copies of Brass Casing, with four filler cards left
## in the draw pile so no refill can interfere.
func _casing_clamp_duplicate_deck(seed_value: int) -> CombatDeck:
	var deck := CombatDeck.new([CASING, CASING, "v3_casing_filler_a",
		"v3_casing_filler_b", "v3_casing_filler_c", "v3_casing_filler_d"],
		_scrap_rng(seed_value))
	_check(deck.start_turn(), "duplicate-copy fixture starts a real turn")
	while deck.hand.count(CASING) < 2 and deck.draw_pile.has(CASING):
		var spare_slot := -1
		for hand_index in range(deck.hand.size()):
			if deck.hand[hand_index] != CASING:
				spare_slot = hand_index
				break
		var pile_index: int = deck.draw_pile.find(CASING)
		if spare_slot < 0 or pile_index < 0:
			break
		var moved: String = deck.hand[spare_slot]
		deck.draw_pile[pile_index] = moved
		deck.hand[spare_slot] = CASING
	return deck


## The exact casing/clamp outcome: one energy, the held copy moved to discard, one Combat Scrap on the
## owner only, the raw hit through Block and (for Spring Clamp) one added Weak stack on the target.
func _expected_casing_clamp(before: Dictionary, card_id: String, seat: int, target: int,
		raw: int, weak: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - 1
	expected["state_energy"] = int(expected["state_energy"]) - 1
	var hand: Array = expected["hand"]
	_check(hand.count(card_id) == 1, "expected snapshot: exactly one played copy is held")
	hand.remove_at(hand.find(card_id))
	(expected["discard"] as Array).append(card_id)
	var hero: Dictionary = expected["party"][seat - 1]
	hero["combat_scrap"] = int(hero.get("combat_scrap", 0)) + 1
	var enemy: Dictionary = expected["enemies"][target - 1]
	var absorbed: int = mini(int(enemy["block"]), raw)
	enemy["block"] = int(enemy["block"]) - absorbed
	enemy["hp"] = maxi(0, int(enemy["hp"]) - (raw - absorbed))
	if weak > 0:
		var statuses: Dictionary = enemy.get("statuses", {})
		statuses["weak"] = int(statuses.get("weak", 0)) + weak
		enemy["statuses"] = statuses
	return expected


func _rejected_casing_clamp(resolver: CombatTinkerV3CasingClampCards, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, card_id: Variant, target: int,
		reason: String, label: String) -> void:
	var before := _battle_snapshot(deck, party, enemies)
	var plan: Dictionary = resolver.preflight(deck, party, enemies, card_id, target)
	_check(plan.get("ok") == false and plan.get("reason") == reason,
		label + ": pure preflight also refuses with " + reason)
	_check(_battle_snapshot(deck, party, enemies) == before,
		label + ": preflight itself changed no state")
	var result: Dictionary = resolver.play_card(deck, party, enemies, card_id, target)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(result.get("reason")) + ")")
	_check(_battle_snapshot(deck, party, enemies) == before,
		label + ": unchanged energy, hand, piles, turn, party, counters, enemies, statuses and RNG")

