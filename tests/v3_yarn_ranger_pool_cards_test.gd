extends SceneTree
## V3-1 Yarn Ranger catalog contract. No live combat/reward/Rest behavior is assumed.
## Extended with deterministic headless combat resolution for Unspool, Snare Net and the knitted
## ally supports (Hood Knit and Knit Shield, base and "+").

const YarnRangerPoolCards = preload("res://data/cards/yarn_ranger_pool_cards.gd")
const YarnRangerStarterCards = preload("res://data/cards/yarn_ranger_starter_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")
const CombatYarnRangerUnspoolCards = preload("res://scripts/combat_yarn_ranger_unspool_cards.gd")
const CombatYarnRangerSnareCards = preload("res://scripts/combat_yarn_ranger_snare_cards.gd")
const CombatYarnRangerKnitCards = preload("res://scripts/combat_yarn_ranger_knit_cards.gd")
const CombatParty = preload("res://scripts/combat_party.gd")
const CombatEnemies = preload("res://scripts/combat_enemies.gd")
const CombatDeck = preload("res://scripts/combat_deck.gd")
const CombatStatuses = preload("res://scripts/combat_statuses.gd")
const CombatStatusTurnBatch = preload("res://scripts/combat_status_turn_batch.gd")

const SNARE_BASE := "yarn_ranger_snare_net"
const SNARE_PLUS := "yarn_ranger_snare_net_plus"
const SNARE_IDS := [SNARE_BASE, SNARE_PLUS]

const KNIT_HOOD := "yarn_ranger_hood_knit"
const KNIT_HOOD_PLUS := "yarn_ranger_hood_knit_plus"
const KNIT_SHIELD := "yarn_ranger_knit_shield"
const KNIT_SHIELD_PLUS := "yarn_ranger_knit_shield_plus"
const KNIT_IDS := [KNIT_HOOD, KNIT_HOOD_PLUS, KNIT_SHIELD, KNIT_SHIELD_PLUS]

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_all_base_and_upgrades()
	_test_special_descriptors()
	_test_detached_results()
	_test_invalid_ids()
	_test_starters_unchanged()
	_test_unspool_combat_behavior()
	_test_snare_net_catalog_contract()
	_test_snare_net_paid_play()
	_test_snare_net_living_slots_and_stacking()
	_test_snare_net_tangled_lifecycle()
	_test_snare_net_refusals()
	_test_knit_catalog_contract()
	_test_knit_paid_block_and_draw()
	_test_knit_draw_supply()
	_test_knit_refusals()
	if failures.is_empty():
		print("v3_yarn_ranger_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_yarn_ranger_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent, named expectations: no global catalog total or insertion-order assertion.
func _cases() -> Dictionary:
	return {
		"yarn_ranger_needle_arrow": {
			"name": "Needle Arrow", "rarity": "common", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 5, "unravel": 1}, "plus_cost": 1,
			"plus_effects": {"damage": 7, "unravel": 2}},
		"yarn_ranger_tangle_bolas": {
			"name": "Tangle Bolas", "rarity": "common", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 2, "tangled": 2}, "plus_cost": 1,
			"plus_effects": {"damage": 3, "tangled": 3}},
		"yarn_ranger_reel_in": {
			"name": "Reel In", "rarity": "common", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [2, 3],
			"effects": {"pull_forward": 1, "tangled": 1}, "plus_cost": 1,
			"plus_effects": {"pull_forward": 1, "tangled": 2}},
		"yarn_ranger_knit_shield": {
			"name": "Knit Shield", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "ally_single", "to": [],
			"effects": {"block": 6, "draw": 1}, "plus_cost": 1,
			"plus_effects": {"block": 8, "draw": 1}},
		"yarn_ranger_purling_barrage": {
			"name": "Purling Barrage", "rarity": "uncommon", "cost": 2,
			"from": [3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 3, "hit_count": 2, "unravel": 1}, "plus_cost": 2,
			"plus_effects": {"damage": 4, "hit_count": 2, "unravel": 2}},
		"yarn_ranger_snare_net": {
			"name": "Snare Net", "rarity": "uncommon", "cost": 2,
			"from": [2, 3], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"tangled": 1, "living_targets_only": true}, "plus_cost": 2,
			"plus_effects": {"tangled": 2, "living_targets_only": true}},
		"yarn_ranger_unspool": {
			"name": "Unspool", "rarity": "uncommon", "cost": 2,
			"from": [2, 3], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"damage": 7, "requires_target_status": "tangled", "living_targets_only": true}, "plus_cost": 2,
			"plus_effects": {"damage": 10, "requires_target_status": "tangled", "living_targets_only": true}},
		"yarn_ranger_endless_skein": {
			"name": "Endless Skein", "rarity": "rare", "cost": 3,
			"from": [2, 3], "target": "enemy_all", "to": [1, 2, 3],
			"effects": {"damage": 4, "tangled": 2, "living_targets_only": true}, "plus_cost": 3,
			"plus_effects": {"damage": 6, "tangled": 3, "living_targets_only": true}},
	}


func _expected_record(base_id: String, spec: Dictionary, upgraded: bool) -> Dictionary:
	var expected: Dictionary = {
		"id": base_id + ("_plus" if upgraded else ""),
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "yarn_ranger",
		"cost": spec["plus_cost"] if upgraded else spec["cost"],
		"from_positions": spec["from"],
		"target_kind": spec["target"],
		"to_positions": spec["to"],
		"effects": spec["plus_effects"] if upgraded else spec["effects"],
		"illustration_path": "res://assets/paper/cards/" + base_id + ".png",
		"starting_copies": 0,
		"rarity": spec["rarity"],
		"reward_eligible": not upgraded,
	}
	if upgraded:
		expected["upgrade_of"] = base_id
	else:
		expected["upgrade_id"] = base_id + "_plus"
	return expected


func _test_all_base_and_upgrades() -> void:
	var catalog := YarnRangerPoolCards.new()
	var cases: Dictionary = _cases()
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	var seen: Dictionary = {}
	var thematic_count: int = 0
	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(not seen.has(base_id), base_id + " is a distinct base identifier")
		seen[base_id] = true
		_check(base_ids.has(base_id), base_id + " is listed as a base")
		_check(base_ids.count(base_id) == 1, base_id + " has one base-list occurrence")
		_check(not base_ids.has(plus_id), plus_id + " is not a base")
		_check(all_ids.has(base_id) and all_ids.has(plus_id), base_id + " both IDs discoverable")
		_check(catalog.has_card(base_id) and catalog.has_card(plus_id), base_id + " both exist")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to its upgrade")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		for upgraded: bool in [false, true]:
			var card_id: String = plus_id if upgraded else base_id
			var record: Dictionary = catalog.get_definition(card_id)
			var expected: Dictionary = _expected_record(base_id, spec, upgraded)
			_check(not record.is_empty(), card_id + " definition exists")
			for field: String in expected:
				_check(record.has(field) and record.get(field) == expected[field],
					card_id + " matches " + field + ": " + str(record.get(field)))
			_check(record.size() == expected.size(), card_id + " has exactly the documented fields")
			_check(record.get("from_positions") is Array and record.get("to_positions") is Array,
				card_id + " has both position arrays")
			_check(record.get("effects") is Dictionary, card_id + " has effect descriptors")
		_check(base_id != plus_id, base_id + " upgrade has distinct stable ID")
		
		# AC2 check
		var effects: Dictionary = spec["effects"]
		if effects.has("tangled") or effects.has("unravel") or effects.has("pull_forward") or effects.has("hit_count") or base_id == "yarn_ranger_unspool" or base_id == "yarn_ranger_knit_shield":
			thematic_count += 1
			
	_check(thematic_count >= 6, "at least six cards express thematic effects")


func _test_special_descriptors() -> void:
	var catalog := YarnRangerPoolCards.new()
	for suffix: String in ["", "_plus"]:
		var bolas: Dictionary = catalog.get_definition("yarn_ranger_tangle_bolas" + suffix)
		_check(bolas.get("effects").has("tangled"), "Tangle Bolas applies tangled" + suffix)
		var reel: Dictionary = catalog.get_definition("yarn_ranger_reel_in" + suffix)
		_check(reel.get("effects").has("pull_forward") and reel.get("effects").has("tangled"),
			"Reel In has pull_forward and tangled" + suffix)
		var unspool: Dictionary = catalog.get_definition("yarn_ranger_unspool" + suffix)
		_check(unspool.get("effects").has("requires_target_status") and unspool.get("effects").get("requires_target_status") == "tangled",
			"Unspool requires tangled status" + suffix)
		_check(unspool.get("effects").get("living_targets_only") == true,
			"Unspool specifies living targets only" + suffix)


func _test_detached_results() -> void:
	var catalog := YarnRangerPoolCards.new()
	var sample: Dictionary = catalog.get_definition("yarn_ranger_needle_arrow")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["unravel"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	var pristine: Dictionary = catalog.get_definition("yarn_ranger_needle_arrow")
	_check(pristine.get("effects") == {"damage": 5, "unravel": 1},
		"effects are deeply detached from catalog")
	_check(pristine.get("from_positions") == [2, 3],
		"FROM arrays are deeply detached from catalog")
	_check(pristine.get("to_positions") == [1, 2, 3],
		"TO arrays are deeply detached from catalog")
	_check(pristine.get("id") == "yarn_ranger_needle_arrow", "metadata is detached")
	var upgraded: Dictionary = catalog.get_definition("yarn_ranger_knit_shield_plus")
	upgraded["effects"]["block"] = 900
	upgraded["from_positions"][0] = 900
	upgraded["to_positions"].append(900)
	_check(catalog.get_definition("yarn_ranger_knit_shield_plus").get("effects") == {"block": 8, "draw": 1},
		"upgrade effects are detached")
	_check(catalog.get_definition("yarn_ranger_knit_shield_plus").get("from_positions") == [1, 2, 3],
		"upgrade FROM is detached")
	_check(catalog.get_definition("yarn_ranger_knit_shield_plus").get("to_positions") == [],
		"empty upgrade TO is detached")
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(base_ids.has("yarn_ranger_needle_arrow") and all_ids.has("yarn_ranger_knit_shield_plus"),
		"ID lists are populated before mutation")
	base_ids.clear()
	all_ids.clear()
	_check(catalog.get_base_ids().has("yarn_ranger_needle_arrow"), "base ID array is a fresh copy")
	_check(catalog.get_all_card_ids().has("yarn_ranger_knit_shield_plus"), "all-ID array is a fresh copy")
	_check(YarnRangerPoolCards.new().get_definition("yarn_ranger_needle_arrow") == pristine,
		"fresh instance retains canonical definition")


func _test_invalid_ids() -> void:
	var catalog := YarnRangerPoolCards.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("yarn_ranger_needle_arrow"),
		"", "yarn_ranger_not_a_card", "yarn_ranger_needle_arrow+", "yarn_ranger_knit_shield_plus_plus"]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(), "invalid id returns no record: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))


func _test_starters_unchanged() -> void:
	var starter := StarterCards.new()
	var pool := YarnRangerPoolCards.new()
	var deck: Array[String] = starter.get_starting_deck()
	var raw: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	var parsed: Variant = JSON.parse_string(raw)
	_check(parsed is Array, "authored starter_deck.json parses as array")
	if not parsed is Array:
		return
	var expected_starters: Dictionary = {
		"warden_strike": {"count": 2, "effects": {"damage": 6}, "owner": "warden"},
		"warden_brace": {"count": 1, "effects": {"block": 7}, "owner": "warden"},
		"warden_shield_bash": {"count": 1, "effects": {"damage": 8, "weak": 1}, "owner": "warden"},
		"seamstress_prick": {"count": 2, "effects": {"damage": 3, "bleed": 2}, "owner": "seamstress"},
		"seamstress_mend": {"count": 1, "effects": {"heal": 5}, "owner": "seamstress"},
		"seamstress_stitch_up": {"count": 1, "effects": {"block": 5}, "owner": "seamstress"},
		"tinker_pop_shot": {"count": 2, "effects": {"damage": 5}, "owner": "tinker"},
		"tinker_scrap_bomb": {"count": 1, "effects": {"damage": 4}, "owner": "tinker"},
		"tinker_tune_up": {"count": 1, "effects": {"draw": 1}, "owner": "tinker"}
	}
	var total_count: int = 0
	for id: String in expected_starters:
		total_count += int(expected_starters[id]["count"])
	_check(deck.size() == total_count and parsed.size() == total_count, "shared starter deck size is unchanged")
	for id: String in expected_starters:
		var starter_record: Dictionary = starter.get_definition(id)
		_check(not starter_record.is_empty(), id + " remains a StarterCards definition")
		_check(starter_record.get("owner") == expected_starters[id]["owner"], id + " owner unchanged")
		_check(starter_record.get("effects") == expected_starters[id]["effects"], id + " printed effects unchanged")
		_check(starter_record.get("starting_copies") == expected_starters[id]["count"],
			id + " catalog multiplicity unchanged")
		_check(deck.count(id) == expected_starters[id]["count"], id + " runtime deck copies unchanged")
		_check(parsed.count(id) == expected_starters[id]["count"], id + " JSON deck copies unchanged")
	_check(deck == parsed, "StarterCards deck and JSON stay identical in membership and order")
	for id: String in pool.get_all_card_ids():
		_check(not starter.has_card(id), id + " has not entered StarterCards")
		_check(not deck.has(id) and not parsed.has(id), id + " is absent from both starter decks")


func _test_unspool_combat_behavior() -> void:
	## AC1-AC4: Deterministic headless Unspool/Unspool+ combat behavior.
	var resolver := CombatYarnRangerUnspoolCards.new()
	var catalog := YarnRangerPoolCards.new()

	# Catalog contract checks (AC1 descriptors).
	for card_id in ["yarn_ranger_unspool", "yarn_ranger_unspool_plus"]:
		var def: Dictionary = catalog.get_definition(card_id)
		_check(not def.is_empty(), card_id + " definition exists")
		_check(def.get("id") == card_id, card_id + " id exact")
		_check(def.get("owner") == "yarn_ranger", card_id + " owner")
		_check(def.get("cost") == 2, card_id + " cost 2")
		_check(def.get("from_positions") == [2, 3], card_id + " from [2,3]")
		_check(def.get("to_positions") == [1, 2, 3], card_id + " to [1,2,3]")
		_check(def.get("target_kind") == "enemy_all", card_id + " enemy_all")
		_check(def.get("effects").get("requires_target_status") == "tangled",
			card_id + " requires tangled")
		_check(def.get("effects").get("living_targets_only") == true,
			card_id + " living only")

	# Fixture helpers.
	var party_yr_2 := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "yarn_ranger", "max_hp": 30},
		{"id": "seamstress", "max_hp": 26}
	])
	var party_yr_3 := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 26},
		{"id": "yarn_ranger", "max_hp": 30}
	])

	var enemies_tangled := CombatEnemies.new([
		{"id": "fray_scavenger", "max_hp": 14, "statuses": {"tangled": 2}},
		{"id": "needle_marshal", "max_hp": 28},
		{"id": "patchwork_behemoth", "max_hp": 42, "statuses": {"tangled": 1}}
	])

	# AC1 positive: base card at position 2, eligible targets at 1 and 3.
	var base_rng := _seeded_rng()
	var deck_base := CombatDeck.new(["yarn_ranger_unspool"], base_rng)
	deck_base.combat_state.start_player_turn()
	deck_base.hand.clear()
	deck_base.hand.append("yarn_ranger_unspool")

	var base_rng_state := base_rng.state
	var result_base: Dictionary = resolver.play_card(deck_base, party_yr_2, enemies_tangled, "yarn_ranger_unspool")
	_check(result_base.get("ok") == true, "base Unspool legal cast ok")
	_check(base_rng.state == base_rng_state, "base cast consumes no RNG")
	_check(deck_base.energy == 1, "base energy 3 -> 1")
	_check(not deck_base.hand.has("yarn_ranger_unspool"), "base card discarded")
	var hits_base: Array = result_base.get("hits", [])
	_check(hits_base.size() == 2, "base hits 2 eligible targets")
	_check(hits_base[0].get("position") == 1, "base first hit position 1")
	_check(hits_base[1].get("position") == 3, "base second hit position 3")
	# Base damage 7 + Tangled 2 = 9, no Block on fixtures.
	_check(hits_base[0].get("damage") == 9, "base damage 9 (7+2)")
	_check(hits_base[0].get("block_absorbed") == 0, "base block 0")
	_check(hits_base[0].get("hp_loss") == 9, "base hp loss 9")
	_check(hits_base[1].get("damage") == 9, "base hit 3 damage 9")
	# Exactly one paid copy leaves the hand.
	_check(deck_base.discard_pile == ["yarn_ranger_unspool"], "base cast discards exactly one copy")
	_check(not deck_base.hand.has("yarn_ranger_unspool"), "base copy left the hand")
	# The untangled slot 2 must not be struck by the all-enemy card.
	_check(enemies_tangled.get_enemy(2).get("hp") == 28, "untangled slot 2 stays at full HP")
	# A second attempt with the already-discarded copy must fail without another charge.
	var base_replay: Dictionary = resolver.play_card(deck_base, party_yr_2, enemies_tangled, "yarn_ranger_unspool")
	_check(base_replay.get("ok") == false, "paid copy cannot be replayed")
	_check(deck_base.energy == 1, "replayed paid copy charges no energy")
	_check(deck_base.discard_pile.size() == 1, "replayed paid copy discards nothing")

	# AC1 plus: position 3, same roster.
	var plus_rng := _seeded_rng()
	var deck_plus := CombatDeck.new(["yarn_ranger_unspool_plus"], plus_rng)
	deck_plus.combat_state.start_player_turn()
	deck_plus.hand.clear()
	deck_plus.hand.append("yarn_ranger_unspool_plus")

	var plus_rng_state := plus_rng.state
	var result_plus: Dictionary = resolver.play_card(deck_plus, party_yr_3, enemies_tangled, "yarn_ranger_unspool_plus")
	_check(result_plus.get("ok") == true, "plus Unspool legal cast ok")
	_check(plus_rng.state == plus_rng_state, "plus cast consumes no RNG")
	var hits_plus: Array = result_plus.get("hits", [])
	_check(hits_plus.size() == 2, "plus hits 2 eligible")
	# Plus damage 10 + 2 = 12.
	_check(hits_plus[0].get("damage") == 12, "plus damage 12")
	_check(hits_plus[1].get("damage") == 12, "plus second damage 12")

	# AC2 mixed status: attacker Weak, defender Exposed with Tangled.
	# CombatStatuses floors the Weak/Exposed combination once (base 7 * 9/8 = 7)
	# and only then adds Tangled's +2, for 9. Statuses arrive through the real
	# hero/enemy records, which preserve extra definition fields.
	var party_weak_yr := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "yarn_ranger", "max_hp": 30, "statuses": {"weak": 1}},
		{"id": "seamstress", "max_hp": 26}
	])
	var enemies_weak_tangled := CombatEnemies.new([
		{"id": "patch_imp", "max_hp": 12, "statuses": {"tangled": 1, "exposed": 1}}
	])

	var deck_weak := CombatDeck.new(["yarn_ranger_unspool"], RandomNumberGenerator.new())
	deck_weak.combat_state.start_player_turn()
	deck_weak.hand.clear()
	deck_weak.hand.append("yarn_ranger_unspool")

	var weak_result: Dictionary = resolver.play_card(deck_weak, party_weak_yr, enemies_weak_tangled, "yarn_ranger_unspool")
	_check(weak_result.get("ok") == true, "weak attacker + exposed tangled succeeds")
	var weak_hits: Array = weak_result.get("hits", [])
	_check(weak_hits.size() == 1, "weak fixture one eligible")
	# Base 7, weak: floor to 5 (7*3/4 = 5.25 -> floor 5). Exposed: 7*3/2 = 10.5 -> floor 10.
	# Combined: 7*9/8 = 7.875 -> floor 7. Then +2 = 9.
	_check(weak_hits[0].get("damage") == 9, "weak+exposed+tangled = 9 (floor 7 + 2)")

	# AC3 negative fixtures preserved.
	var dead_enemies := CombatEnemies.new([
		{"id": "fray_scavenger", "max_hp": 14},
		{"id": "needle_marshal", "max_hp": 28}
	])
	dead_enemies.apply_damage(1, 14)
	dead_enemies.apply_damage(2, 28)
	var dead_deck := CombatDeck.new(["yarn_ranger_unspool"], RandomNumberGenerator.new())
	dead_deck.combat_state.start_player_turn()
	dead_deck.hand.clear()
	dead_deck.hand.append("yarn_ranger_unspool")
	var dead_before_energy := dead_deck.energy
	var dead_before_hand := dead_deck.hand.size()
	_check(resolver.play_card(dead_deck, party_yr_2, dead_enemies, "yarn_ranger_unspool").get("ok") == false,
		"dead fixture rejected before spend")
	_check(dead_deck.energy == dead_before_energy, "dead fixture energy unchanged")
	_check(dead_deck.hand.size() == dead_before_hand, "dead fixture hand unchanged")

	# Zero hits on slain and untangled foes even when a living Tangled foe exists.
	var mixed_enemies := CombatEnemies.new([
		{"id": "mix_live", "max_hp": 14, "statuses": {"tangled": 1}},
		{"id": "mix_dead", "max_hp": 12, "statuses": {"tangled": 2}},
		{"id": "mix_plain", "max_hp": 12}
	])
	mixed_enemies.apply_damage(2, 12)
	var mixed_deck := CombatDeck.new(["yarn_ranger_unspool"], RandomNumberGenerator.new())
	mixed_deck.combat_state.start_player_turn()
	mixed_deck.hand.clear()
	mixed_deck.hand.append("yarn_ranger_unspool")
	var mixed_result: Dictionary = resolver.play_card(mixed_deck, party_yr_2, mixed_enemies, "yarn_ranger_unspool")
	_check(mixed_result.get("ok") == true, "mixed roster cast ok")
	var mixed_hits: Array = mixed_result.get("hits", [])
	_check(mixed_hits.size() == 1 and mixed_hits[0].get("position") == 1,
		"only the living Tangled foe is struck")
	_check(mixed_hits[0].get("damage") == 9 and mixed_hits[0].get("hp_loss") == 9,
		"mixed hit is 9 (7+2)")
	_check(mixed_enemies.get_enemy(2).get("hp") == 0
		and mixed_enemies.get_enemy(2).get("statuses") == {"tangled": 2},
		"slain Tangled foe is unchanged")
	_check(mixed_enemies.get_enemy(3).get("hp") == 12, "untangled foe is unchanged")

	# AC2: Block before HP.
	var enemies_block := CombatEnemies.new([
		{"id": "patch_imp", "max_hp": 12, "statuses": {"tangled": 1}},
		{"id": "stitch_foe", "max_hp": 17, "statuses": {"tangled": 1}}
	])
	enemies_block.gain_block(1, 4)
	var deck_block := CombatDeck.new(["yarn_ranger_unspool"], RandomNumberGenerator.new())
	deck_block.combat_state.start_player_turn()
	deck_block.hand.clear()
	deck_block.hand.append("yarn_ranger_unspool")
	var block_result: Dictionary = resolver.play_card(deck_block, party_yr_2, enemies_block, "yarn_ranger_unspool")
	_check(block_result.get("ok") == true, "block fixture succeeds")
	var block_hits: Array = block_result.get("hits", [])
	_check(block_hits[0].get("position") == 1, "block first at 1")
	_check(block_hits[0].get("block_absorbed") == 4, "block 4 absorbed")
	_check(block_hits[0].get("hp_loss") == 5, "hp loss 5 = 9 - 4 (base 7+2=9, block 4)")
	_check(block_hits[1].get("position") == 2, "second block hit at 2")

	# Verify no status mutation or RNG consumption.
	_check(enemies_tangled.get_enemy(1).get("statuses", {}).get("tangled") == 2,
		"tangled counter unchanged after cast")

	# AC3 negative fixtures.
	# No eligible target.
	var no_target_deck := CombatDeck.new(["yarn_ranger_unspool"], RandomNumberGenerator.new())
	no_target_deck.combat_state.start_player_turn()
	no_target_deck.hand.clear()
	no_target_deck.hand.append("yarn_ranger_unspool")
	var no_target_result := resolver.play_card(no_target_deck, party_yr_2,
		CombatEnemies.new([{"id": "f1", "max_hp": 10}]), "yarn_ranger_unspool")
	_check(no_target_result.get("ok") == false, "no eligible target rejected")

	# Wrong card ID.
	var bad_id_result := resolver.play_card(CombatDeck.new(["bad"], RandomNumberGenerator.new()), party_yr_2,
		enemies_tangled, "bad_id")
	_check(bad_id_result.get("ok") == false, "invalid card id rejected")

	# No genuine hand copy.
	var no_hand := CombatDeck.new(["yarn_ranger_unspool"], RandomNumberGenerator.new())
	no_hand.combat_state.start_player_turn()
	no_hand.hand.clear()
	var no_copy_result := resolver.play_card(no_hand, party_yr_2, enemies_tangled, "yarn_ranger_unspool")
	_check(no_copy_result.get("ok") == false, "missing hand copy rejected")

	# Invalid energy.
	var low_energy := CombatDeck.new(["yarn_ranger_unspool"], RandomNumberGenerator.new())
	low_energy.combat_state.start_player_turn()
	low_energy.hand.append("yarn_ranger_unspool")
	low_energy.combat_state.energy = 1
	var low_e_result := resolver.play_card(low_energy, party_yr_2, enemies_tangled, "yarn_ranger_unspool")
	_check(low_e_result.get("ok") == false, "low energy rejected")

	# Replay after rejection must succeed.
	var replay_deck := CombatDeck.new(["yarn_ranger_unspool"], RandomNumberGenerator.new())
	replay_deck.combat_state.start_player_turn()
	replay_deck.hand.clear()
	replay_deck.hand.append("yarn_ranger_unspool")
	var replay_result := resolver.play_card(replay_deck, party_yr_2, enemies_tangled, "yarn_ranger_unspool")
	_check(replay_result.get("ok") == true, "valid retry succeeds after prior rejection")

	# A consumed single copy cannot be replayed.
	_check(not replay_deck.hand.has("yarn_ranger_unspool"), "consumed copy left the hand")
	_check(resolver.play_card(replay_deck, party_yr_2, enemies_tangled,
		"yarn_ranger_unspool").get("ok") == false, "consumed copy cannot be replayed")
	_check(replay_deck.energy == 1, "consumed copy replay charges no energy")

	# AC3: owner position, downed owner, inactive turn, invalid models and malformed
	# status snapshots all reject with a complete no-mutation snapshot.
	var fresh_enemies := CombatEnemies.new([{"id": "fresh", "max_hp": 10, "statuses": {"tangled": 1}}])
	var front_party := CombatParty.new([
		{"id": "yarn_ranger", "max_hp": 30},
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 26}
	])
	var downed_party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 26},
		{"id": "yarn_ranger", "max_hp": 30}
	])
	downed_party.apply_damage(3, 30)
	var inactive_deck := CombatDeck.new(["yarn_ranger_unspool"], _seeded_rng())
	inactive_deck.hand.append("yarn_ranger_unspool")
	var short_party := CombatParty.new([{"id": "warden", "max_hp": 40}])
	var malformed_party := CombatParty.new([
		{"id": "warden", "max_hp": 40},
		{"id": "yarn_ranger", "max_hp": 30, "statuses": "bad"},
		{"id": "seamstress", "max_hp": 26}
	])
	var malformed_enemies := CombatEnemies.new([
		{"id": "bad_one", "max_hp": 10, "statuses": {"tangled": 1}},
		{"id": "bad_two", "max_hp": 10, "statuses": "bad"}
	])
	var rejected_cases: Array[Dictionary] = [
		{"label": "Yarn Ranger in position 1", "deck": _active_deck("yarn_ranger_unspool"),
			"party": front_party, "enemies": fresh_enemies},
		{"label": "downed Yarn Ranger", "deck": _active_deck("yarn_ranger_unspool"),
			"party": downed_party, "enemies": fresh_enemies},
		{"label": "inactive turn", "deck": inactive_deck,
			"party": party_yr_2, "enemies": fresh_enemies},
		{"label": "invalid party model", "deck": _active_deck("yarn_ranger_unspool"),
			"party": short_party, "enemies": fresh_enemies},
		{"label": "invalid enemy model", "deck": _active_deck("yarn_ranger_unspool"),
			"party": party_yr_2, "enemies": CombatEnemies.new([])},
		{"label": "malformed attacker statuses", "deck": _active_deck("yarn_ranger_unspool"),
			"party": malformed_party, "enemies": fresh_enemies},
		{"label": "malformed defender statuses", "deck": _active_deck("yarn_ranger_unspool"),
			"party": party_yr_2, "enemies": malformed_enemies},
	]
	for entry: Dictionary in rejected_cases:
		var before: Dictionary = _combat_snapshot(entry["deck"], entry["party"], entry["enemies"])
		_check(resolver.play_card(entry["deck"], entry["party"], entry["enemies"],
			"yarn_ranger_unspool").get("ok") == false, entry["label"] + " rejected")
		_check(_combat_snapshot(entry["deck"], entry["party"], entry["enemies"]) == before,
			entry["label"] + " leaves hand, discard, energy, party and enemies untouched")


func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261026
	return rng


func _active_deck(card_id: String) -> CombatDeck:
	var deck := CombatDeck.new([card_id], _seeded_rng())
	deck.combat_state.start_player_turn()
	deck.hand.clear()
	deck.hand.append(card_id)
	return deck


func _combat_snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	return {
		"turn": deck.turn_active,
		"energy": deck.energy,
		"hand": deck.hand.duplicate(),
		"draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(),
		"party": party.get_heroes(),
		"enemies": enemies.get_enemies()
	}


## AC2: both authentic Snare Net printings keep their exact authored reward-catalog line.
func _test_snare_net_catalog_contract() -> void:
	var catalog := YarnRangerPoolCards.new()
	var resolver := CombatYarnRangerSnareCards.new()
	var expected := {
		SNARE_BASE: {
			"display_name": "Snare Net", "cost": 2,
			"effects": {"tangled": 1, "living_targets_only": true},
			"upgrade_id": SNARE_PLUS, "reward_eligible": true,
		},
		SNARE_PLUS: {
			"display_name": "Snare Net+", "cost": 2,
			"effects": {"tangled": 2, "living_targets_only": true},
			"upgrade_of": SNARE_BASE, "reward_eligible": false,
		},
	}
	for card_id: String in SNARE_IDS:
		var definition: Dictionary = catalog.get_definition(card_id)
		var spec: Dictionary = expected[card_id]
		_check(not definition.is_empty(), card_id + " is an authored reward-catalog record")
		_check(definition.get("id") == card_id, card_id + " keeps its exact identifier")
		_check(definition.get("display_name") == spec["display_name"], card_id + " keeps its printed name")
		_check(definition.get("owner") == "yarn_ranger", card_id + " is owned by the Yarn Ranger")
		_check(definition.get("cost") == 2, card_id + " prints two energy")
		_check(definition.get("from_positions") == [2, 3], card_id + " prints FROM seats 2-3")
		_check(definition.get("target_kind") == "enemy_all", card_id + " prints an all-enemy target")
		_check(definition.get("to_positions") == [1, 2, 3], card_id + " prints TO slots 1-3")
		_check(definition.get("effects") == spec["effects"],
			card_id + " prints the exact Tangled/living-only descriptor")
		_check(definition.get("effects").size() == 2, card_id + " carries no extra effect key")
		_check(definition.get("reward_eligible") == spec["reward_eligible"],
			card_id + " keeps its reward-offer flag")
		if spec.has("upgrade_id"):
			_check(definition.get("upgrade_id") == spec["upgrade_id"]
				and not definition.has("upgrade_of"),
				card_id + " links forward to its one upgrade")
		else:
			_check(definition.get("upgrade_of") == spec["upgrade_of"]
				and not definition.has("upgrade_id"),
				card_id + " links back to the base printing")
		_check(resolver.is_supported_card(card_id), card_id + " is authenticated by the resolver")

	# Every other Yarn Ranger pool card, and every non-authentic spelling, is refused.
	var unsupported: Array = catalog.get_all_card_ids()
	for snare_id: String in SNARE_IDS:
		unsupported.erase(snare_id)
	unsupported.append_array(["yarn_ranger_snare_net_plus_plus", "yarn_ranger_snare_net_plus2",
		"snare_net", " yarn_ranger_snare_net", ""])
	for other_id: Variant in unsupported:
		_check(not resolver.is_supported_card(other_id),
			str(other_id) + " is not a Snare Net printing")
	for junk: Variant in [null, 0, 3.5, false, [], {}, StringName(SNARE_BASE)]:
		_check(not resolver.is_supported_card(junk), "non-string ID is never supported: " + str(junk))


## AC1: a genuinely held Snare Net/Snare Net+ from seat 2 or 3 pays twice and binds every living foe.
func _test_snare_net_paid_play() -> void:
	var resolver := CombatYarnRangerSnareCards.new()
	for card_id: String in SNARE_IDS:
		var added: int = 1 if card_id == SNARE_BASE else 2
		for seat in [2, 3]:
			var label: String = card_id + " from seat " + str(seat)
			var party := _snare_party(seat)
			party.gain_block(1, 4)
			_check(party.get_hero(1).get("block") == 4,
				label + ": fixture Warden really carries Block")
			var enemies := _snare_enemies([
				{"max_hp": 14, "hp": 14, "block": 3},
				{"max_hp": 11, "hp": 11},
				{"max_hp": 9, "hp": 9, "statuses": {}},
			])
			var deck := _snare_deck(card_id)
			var held_before: int = deck.hand.count(card_id)
			var discarded_before: int = deck.discard_pile.count(card_id)
			var before := _snare_snapshot(deck, party, enemies)
			var result: Dictionary = resolver.play_card(deck, party, enemies, card_id)
			_check(result.get("ok") == true and result.get("reason") == "applied",
				label + ": authorized paid play")
			_check(result.get("card_id") == card_id and result.get("cost") == 2,
				label + ": receipt names the authentic card and its two energy")
			_check(result.get("owner_position") == seat, label + ": receipt reports the real owner seat")
			_check(result.get("tangled_added") == added,
				label + ": receipt reports the printed Tangled count")
			_check(result.get("target_positions") == [1, 2, 3],
				label + ": receipt lists every living slot in order")
			_check(deck.energy == 1, label + ": exactly two of the three energy were spent")
			_check(deck.hand.count(card_id) == held_before - 1,
				label + ": exactly one held copy left the hand")
			_check(deck.discard_pile.count(card_id) == discarded_before + 1,
				label + ": exactly one authentic copy reached the discard pile")
			for position in [1, 2, 3]:
				_check(enemies.get_enemy(position).get("statuses") == {"tangled": added},
					label + ": enemy " + str(position) + " gained Tangled " + str(added))
			_check(enemies.get_enemy(1).get("block") == 3 and enemies.get_enemy(1).get("hp") == 14,
				label + ": enemy Block and HP are untouched")
			_check(_snare_snapshot(deck, party, enemies)
				== _expected_snare(before, card_id, added, [1, 2, 3]),
				label + ": exact hand, piles, energy, turn, party, enemies and RNG state")
			# A detached receipt is never authority for later state.
			result["tangled_added"] = 99
			result["target_positions"] = [1]
			_check(enemies.get_enemy(3).get("statuses") == {"tangled": added},
				label + ": a mutated receipt cannot change an enemy")


## AC2/AC3: dead slots are skipped and preserved; a recast stacks the real owner-turn counter.
func _test_snare_net_living_slots_and_stacking() -> void:
	var resolver := CombatYarnRangerSnareCards.new()
	# Living front and back with a slain middle slot: the dead slot keeps its position and counters.
	var enemies := _snare_enemies([
		{"max_hp": 20, "hp": 20, "statuses": {"tangled": 2, "weak": 1, "bleed": 3}},
		{"max_hp": 12, "hp": 0, "statuses": {"tangled": 4}},
		{"max_hp": 15, "hp": 15, "statuses": {"exposed": 2}},
	])
	var party := _snare_party(2)
	var deck := _snare_deck(SNARE_BASE, 8123)
	var before := _snare_snapshot(deck, party, enemies)
	var result: Dictionary = resolver.play_card(deck, party, enemies, SNARE_BASE)
	_check(result.get("ok") == true, "mixed roster: the base net binds the living front and back")
	_check(result.get("target_positions") == [1, 3], "mixed roster: the slain middle slot is skipped")
	_check(result.get("tangled_added") == 1, "mixed roster: the base printing adds one")
	_check(enemies.get_enemy(1).get("statuses") == {"tangled": 3, "weak": 1, "bleed": 3},
		"mixed roster: an existing Tangled count stacks and other counters survive")
	_check(enemies.get_enemy(2).get("statuses") == {"tangled": 4}
		and enemies.get_enemy(2).get("hp") == 0,
		"mixed roster: the slain slot keeps its HP, position and counters")
	_check(enemies.get_enemy(3).get("statuses") == {"tangled": 1, "exposed": 2},
		"mixed roster: a bare map gains Tangled and keeps Exposed")
	_check(enemies.get_enemy(1).get("position") == 1 and enemies.get_enemy(2).get("position") == 2
		and enemies.get_enemy(3).get("position") == 3,
		"mixed roster: original enemy positions are preserved")
	_check(_snare_snapshot(deck, party, enemies) == _expected_snare(before, SNARE_BASE, 1, [1, 3]),
		"mixed roster: exact state apart from the two Tangled additions")

	# A two-enemy roster whose rear slot is slain still binds only the front survivor.
	var rear_dead := _snare_enemies([{"max_hp": 10, "hp": 10}, {"max_hp": 10, "hp": 0}])
	var rear_deck := _snare_deck(SNARE_PLUS, 9182)
	var rear_result: Dictionary = resolver.play_card(rear_deck, party, rear_dead, SNARE_PLUS)
	_check(rear_result.get("ok") == true and rear_result.get("target_positions") == [1],
		"rear slain slot: only the front survivor is bound")
	_check(rear_dead.get_enemy(1).get("statuses") == {"tangled": 2},
		"rear slain slot: the upgrade adds two to the living front")
	_check(rear_dead.get_enemy(2).get("hp") == 0 and not rear_dead.get_enemy(2).has("statuses"),
		"rear slain slot: no counter is invented on the dead rear slot")

	# Two held printings across the real turn boundary stack their own printed counts.
	var stack_enemies := _snare_enemies([{"max_hp": 30, "hp": 30}, {"max_hp": 30, "hp": 30}])
	var stack_party := _snare_party(3)
	var stack_deck := _snare_small_deck([SNARE_BASE, SNARE_PLUS, "snare_filler_a", "snare_filler_b"])
	_check(stack_deck.hand.has(SNARE_BASE) and stack_deck.hand.has(SNARE_PLUS),
		"stacking: the genuine hand holds both printings")
	var first: Dictionary = resolver.play_card(stack_deck, stack_party, stack_enemies, SNARE_BASE)
	_check(first.get("ok") == true and stack_deck.energy == 1,
		"stacking: the first cast pays two energy")
	_check(stack_enemies.get_enemy(1).get("statuses") == {"tangled": 1}
		and stack_enemies.get_enemy(2).get("statuses") == {"tangled": 1},
		"stacking: the base cast adds one to each living foe")
	_check(stack_deck.end_turn() and stack_deck.start_turn() and stack_deck.energy == 3,
		"stacking: a second shared turn begins with three energy")
	_check(stack_deck.hand.has(SNARE_PLUS), "stacking: the second printing is genuinely held again")
	var second: Dictionary = resolver.play_card(stack_deck, stack_party, stack_enemies, SNARE_PLUS)
	_check(second.get("ok") == true and second.get("tangled_added") == 2,
		"stacking: the second cast adds its own printed two")
	_check(stack_enemies.get_enemy(1).get("statuses") == {"tangled": 3}
		and stack_enemies.get_enemy(2).get("statuses") == {"tangled": 3},
		"stacking: recasting accumulates instead of replacing or refreshing")
	_check(stack_deck.energy == 1, "stacking: the second cast pays two more energy")
	_check(stack_deck.discard_pile.count(SNARE_PLUS) == 1,
		"stacking: the second copy is discarded exactly once")


## AC3: Tangled keeps its existing +2-on-hit and enemy owner-turn tick, with no new lifecycle.
func _test_snare_net_tangled_lifecycle() -> void:
	var resolver := CombatYarnRangerSnareCards.new()
	var rules := CombatStatuses.new()
	var batch := CombatStatusTurnBatch.new()
	var enemies := _snare_enemies([
		{"max_hp": 20, "hp": 20, "statuses": {"tangled": 2}},
		{"max_hp": 20, "hp": 20},
	])
	var deck := _snare_deck(SNARE_BASE, 3311)
	var result: Dictionary = resolver.play_card(deck, _snare_party(2), enemies, SNARE_BASE)
	_check(result.get("ok") == true, "lifecycle: the net is cast on the real roster")
	_check(enemies.get_enemy(1).get("statuses") == {"tangled": 3},
		"lifecycle: an existing count stacks and is not cleared or refreshed")
	_check(enemies.get_enemy(2).get("statuses") == {"tangled": 1},
		"lifecycle: a bare foe gains its first Tangled count")

	# Tangled's +2 is flat on a later positive-base hit, once, whatever the stack.
	var stacked: Dictionary = enemies.get_enemy(1).get("statuses")
	_check(rules.adjusted_attack_damage(5, {}, stacked) == 7,
		"lifecycle: a positive-base hit gets Tangled's flat +2 once")
	_check(rules.adjusted_attack_damage(5, {}, {"tangled": 9}) == 7,
		"lifecycle: a nine-stack still adds +2, not +18")
	_check(rules.adjusted_attack_damage(0, {}, stacked) == 0,
		"lifecycle: a zero-base hit never borrows Tangled's +2")
	_check(rules.adjusted_attack_damage(5, {"weak": 1}, stacked) == 5,
		"lifecycle: Weak floors first (5 -> 3) and Tangled then adds +2")

	# The existing enemy owner-turn tick still decrements, never clearing early.
	var roster_before: Array[Dictionary] = enemies.get_enemies()
	var first_tick: Dictionary = batch.tick_side("enemies", roster_before)
	_check(first_tick.get("ok") == true, "lifecycle: the owner-turn tick accepts the bound roster")
	var ticked: Array = first_tick["actors"]
	_check(ticked[0]["statuses"] == {"tangled": 2},
		"lifecycle: three remaining turns tick down to two")
	_check(not (ticked[1]["statuses"] as Dictionary).has("tangled"),
		"lifecycle: a one-turn Tangled expires at the owner-turn boundary")
	_check(enemies.get_enemies() == roster_before,
		"lifecycle: the tick projection leaves the authoritative roster untouched")
	var second_tick: Dictionary = batch.tick_side("enemies", ticked)
	_check(second_tick.get("ok") == true
		and (second_tick["actors"] as Array)[0]["statuses"] == {"tangled": 1},
		"lifecycle: later ticks keep using the same owner-turn rule")


## AC3: every invalid request is inert, carries its reason and proves no partial application.
func _test_snare_net_refusals() -> void:
	var resolver := CombatYarnRangerSnareCards.new()
	var party := _snare_party(2)
	var enemies := _snare_enemies([{"max_hp": 12, "hp": 12}, {"max_hp": 12, "hp": 12}])
	var deck := _snare_deck(SNARE_BASE, 4455)

	_rejected_snare(resolver, null, party, enemies, SNARE_BASE, "invalid_request", "null deck")
	_rejected_snare(resolver, deck, null, enemies, SNARE_BASE, "invalid_request", "null party")
	_rejected_snare(resolver, deck, party, null, SNARE_BASE, "invalid_request", "null enemies")

	var inactive := CombatDeck.new([SNARE_BASE, "snare_filler_a"], _snare_rng(12))
	inactive.hand.append(SNARE_BASE)
	_check(not inactive.turn_active and inactive.hand.has(SNARE_BASE),
		"inactive fixture really holds a copy outside a turn")
	_rejected_snare(resolver, inactive, party, enemies, SNARE_BASE, "inactive_turn",
		"inactive turn")

	for unsupported: Variant in ["yarn_ranger_tangle_bolas", "yarn_ranger_tangle_bolas_plus",
			"yarn_ranger_unspool", "yarn_ranger_endless_skein", "yarn_ranger_snare_net_plus_plus",
			"yarn_ranger_snare_net ", "SNARE_NET", "", "warden_strike", 7, null,
			StringName(SNARE_BASE), "yarn_ranger_snare_net_+"]:
		_rejected_snare(resolver, deck, party, enemies, unsupported, "unsupported_card",
			"unsupported or unauthenticated ID " + str(unsupported))

	# An authentic printing the hand does not hold is still unheld.
	_rejected_snare(resolver, deck, party, enemies, SNARE_PLUS, "card_not_held",
		"authentic but unheld printing")

	var no_copy := CombatDeck.new(["snare_filler_a", "snare_filler_b", "snare_filler_c",
		"snare_filler_d", "snare_filler_e"], _snare_rng(77))
	_check(no_copy.start_turn() and not no_copy.hand.has(SNARE_BASE),
		"missing-copy fixture really lacks the card")
	_rejected_snare(resolver, no_copy, party, enemies, SNARE_BASE, "card_not_held",
		"missing held copy")

	var poor := _snare_deck(SNARE_BASE, 5566)
	poor.combat_state.energy = 1
	_check(poor.energy == 1 and poor.hand.has(SNARE_BASE),
		"short-energy fixture really holds a copy with one energy")
	_rejected_snare(resolver, poor, party, enemies, SNARE_BASE, "insufficient_energy",
		"one energy short")

	var short_party := CombatParty.new([{"id": "warden", "max_hp": 40}])
	_rejected_snare(resolver, _snare_deck(SNARE_BASE, 6110), short_party, enemies, SNARE_BASE,
		"invalid_roster", "invalid one-hero party")

	var no_owner := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}])
	_check(no_owner.is_valid() and no_owner.get_hero(2).get("id") == "seamstress",
		"absent-owner fixture is a valid three-hero party with no Yarn Ranger")
	_rejected_snare(resolver, _snare_deck(SNARE_BASE, 6111), no_owner, enemies, SNARE_BASE,
		"owner_missing", "absent Yarn Ranger")

	var front := _snare_party(1)
	_check(front.get_hero(1).get("id") == "yarn_ranger" and not front.is_downed(1),
		"front-seat fixture really has a living Yarn Ranger in seat 1")
	_rejected_snare(resolver, _snare_deck(SNARE_BASE, 6112), front, enemies, SNARE_BASE,
		"owner_illegal_position", "Yarn Ranger in seat 1")

	var torn := _snare_party(3)
	_check(torn.apply_damage(3, 28) and torn.is_downed(3),
		"torn-owner fixture really has a downed Yarn Ranger")
	_rejected_snare(resolver, _snare_deck(SNARE_BASE, 6113), torn, enemies, SNARE_BASE,
		"owner_downed", "downed owner")

	var duplicate := _snare_party(2)
	duplicate._heroes[2]["id"] = "yarn_ranger"
	_check(duplicate.get_hero(2).get("id") == "yarn_ranger"
		and duplicate.get_hero(3).get("id") == "yarn_ranger",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected_snare(resolver, _snare_deck(SNARE_BASE, 6114), duplicate, enemies, SNARE_BASE,
		"invalid_party", "duplicate hero identity")

	var dead := _snare_enemies([{"max_hp": 8, "hp": 0}, {"max_hp": 8, "hp": 0}])
	_check(dead.is_valid() and dead.is_defeated(), "dead-roster fixture really has no living enemy")
	_rejected_snare(resolver, _snare_deck(SNARE_BASE, 6115), party, dead, SNARE_BASE,
		"no_living_target", "no living enemy")

	var bad_party := _snare_party(2)
	bad_party._heroes[1]["statuses"] = "bad"
	_rejected_snare(resolver, _snare_deck(SNARE_BASE, 6116), bad_party, enemies, SNARE_BASE,
		"invalid_party", "malformed party status map")

	for malformed: Variant in ["bad", 4, {"tangled": -1}, {"tangled": "2"}, {"forged": 1},
			{"tangled": 1.5}, {"tangled": true}, {1: 2}]:
		var broken := _snare_enemies([{"max_hp": 10, "hp": 10}, {"max_hp": 10, "hp": 10}])
		broken._enemies[1]["statuses"] = malformed
		_rejected_snare(resolver, _snare_deck(SNARE_BASE, 6117), party, broken, SNARE_BASE,
			"invalid_enemies", "malformed enemy status map " + str(malformed))

	var bad_hp := _snare_enemies([{"max_hp": 10, "hp": 10}])
	bad_hp._enemies[0]["hp"] = 99
	_rejected_snare(resolver, _snare_deck(SNARE_BASE, 6118), party, bad_hp, SNARE_BASE,
		"invalid_enemies", "malformed enemy HP")
	var bad_position := _snare_enemies([{"max_hp": 10, "hp": 10}])
	bad_position._enemies[0]["position"] = 2
	_rejected_snare(resolver, _snare_deck(SNARE_BASE, 6119), party, bad_position, SNARE_BASE,
		"invalid_enemies", "malformed enemy slot index")
	_rejected_snare(resolver, _snare_deck(SNARE_BASE, 6120), party, CombatEnemies.new([]),
		SNARE_BASE, "invalid_roster", "invalid empty enemy roster")

	var overflow := _snare_enemies([{"max_hp": 10, "hp": 10,
		"statuses": {"tangled": CombatStatuses.MAX_INT}}])
	_rejected_snare(resolver, _snare_deck(SNARE_BASE, 6121), party, overflow, SNARE_BASE,
		"status_overflow", "status count overflow")

	# A valid earlier enemy plus an invalid later one proves the roster is preflighted as a whole.
	var partial := _snare_enemies([{"max_hp": 10, "hp": 10, "statuses": {"tangled": 1}},
		{"max_hp": 10, "hp": 10, "statuses": {"tangled": CombatStatuses.MAX_INT}}])
	var partial_deck := _snare_deck(SNARE_BASE, 6122)
	var partial_before := _snare_snapshot(partial_deck, party, partial)
	var partial_result: Dictionary = resolver.play_card(partial_deck, party, partial, SNARE_BASE)
	_check(partial_result.get("ok") == false and partial_result.get("reason") == "status_overflow",
		"partial fixture: the later overflow rejects the whole play")
	_check(_snare_snapshot(partial_deck, party, partial) == partial_before,
		"partial fixture: no earlier enemy, energy, card or RNG was touched")
	_check(partial.get_enemy(1).get("statuses") == {"tangled": 1},
		"partial fixture: the first enemy was not partially bound")

	# A refused attempt never poisons the next authentic play on the same objects.
	var retry_enemies := _snare_enemies([{"max_hp": 14, "hp": 14}])
	var retry_deck := _snare_deck(SNARE_BASE, 6123)
	_rejected_snare(resolver, retry_deck, party, retry_enemies, "yarn_ranger_unspool",
		"unsupported_card", "retry: wrong card first")
	_rejected_snare(resolver, retry_deck, party, retry_enemies, 12, "unsupported_card",
		"retry: non-string ID second")
	var retry_result: Dictionary = resolver.play_card(retry_deck, party, retry_enemies, SNARE_BASE)
	_check(retry_result.get("ok") == true and retry_deck.energy == 1
		and retry_enemies.get_enemy(1).get("statuses") == {"tangled": 1},
		"retry: the authentic play then succeeds exactly once")



func _snare_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real three-hero party (distinct IDs, authored HP scale) with the Yarn Ranger in the named seat.
func _snare_party(ranger_position: int) -> CombatParty:
	var heroes: Array = [
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	]
	var ranger: Dictionary = heroes[ranger_position - 1]
	ranger["id"] = "yarn_ranger"
	ranger["max_hp"] = 28
	var party := CombatParty.new(heroes)
	_check(party.is_valid() and party.get_hero(ranger_position).get("id") == "yarn_ranger"
		and party.get_hero(ranger_position).get("hp") == 28,
		"valid three-hero party with a living Yarn Ranger in seat " + str(ranger_position))
	return party


## Real enemy slots; HP loss and Block come from the model's own state APIs.
func _snare_enemies(specs: Array) -> CombatEnemies:
	var definitions: Array = []
	for index in range(specs.size()):
		var definition := {"id": "snare_fixture_foe_" + str(index + 1),
			"max_hp": int(specs[index]["max_hp"])}
		if specs[index].has("statuses"):
			definition["statuses"] = specs[index]["statuses"]
		definitions.append(definition)
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == specs.size(),
		"fixture builds a real indexed enemy roster")
	for index in range(specs.size()):
		var lost: int = int(specs[index]["max_hp"]) - int(specs[index]["hp"])
		if lost > 0:
			_check(enemies.apply_damage(index + 1, lost),
				"fixture foe " + str(index + 1) + " really lost HP")
		var block := int(specs[index].get("block", 0))
		if block > 0:
			_check(enemies.gain_block(index + 1, block),
				"fixture foe " + str(index + 1) + " really gained Block")
	return enemies


## A genuine seeded turn that really holds at least one copy of the named card.
func _snare_deck(card_id: String, seed_value: int = 51731, copies: int = 2) -> CombatDeck:
	var ids: Array[String] = []
	for _copy in range(copies):
		ids.append(card_id)
	var filler := 0
	while ids.size() < 6:
		ids.append("snare_filler_" + str(filler))
		filler += 1
	var deck := CombatDeck.new(ids, _snare_rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3,
		card_id + ": starts a real three-energy shared turn")
	_check(deck.hand.count(card_id) >= 1, card_id + ": the seeded hand genuinely holds a copy")
	return deck


## A deck small enough that the real five-card draw holds every authored card.
func _snare_small_deck(card_ids: Array) -> CombatDeck:
	var ids: Array[String] = []
	for card_id in card_ids:
		ids.append(str(card_id))
	var deck := CombatDeck.new(ids, _snare_rng(7741))
	_check(deck.start_turn() and deck.hand.size() == ids.size() and deck.energy == 3,
		"small deck draws every authored card into a real turn")
	return deck


## The complete mutable combat state, including the run RNG and null-safe presence flags.
func _snare_snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	var snapshot: Dictionary = {
		"deck_present": deck != null, "party_present": party != null,
		"enemies_present": enemies != null
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
	if enemies != null:
		snapshot["enemies"] = enemies.get_enemies()
		snapshot["enemies_valid"] = enemies.is_valid()
	return snapshot


## The exact post-transaction state: two energy, one discarded copy and Tangled on the given slots.
func _expected_snare(before: Dictionary, card_id: String, added: int,
		positions: Array) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - 2
	expected["state_energy"] = int(expected["state_energy"]) - 2
	var hand: Array = expected["hand"]
	_check(hand.find(card_id) >= 0, "expected snapshot: the played copy is really in the hand")
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	for position: Variant in positions:
		var enemy: Dictionary = expected["enemies"][int(position) - 1]
		if not enemy.has("statuses"):
			enemy["statuses"] = {}
		enemy["statuses"]["tangled"] = int(enemy["statuses"].get("tangled", 0)) + added
	return expected


func _rejected_snare(resolver: CombatYarnRangerSnareCards, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, card_id: Variant, reason: String,
		label: String) -> void:
	var before := _snare_snapshot(deck, party, enemies)
	var result: Dictionary = resolver.play_card(deck, party, enemies, card_id)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(result.get("reason")) + ")")
	_check(_snare_snapshot(deck, party, enemies) == before,
		label + ": unchanged energy, hand, piles, turn, party, enemies, positions and RNG")


## AC1: the four authentic knitted printings keep their exact authored line in the catalog that owns
## them, resolve to that exact record and refuse every other ID or tampered definition.
func _test_knit_catalog_contract() -> void:
	var starter := YarnRangerStarterCards.new()
	var pool := YarnRangerPoolCards.new()
	var resolver := CombatYarnRangerKnitCards.new()
	var expected := {
		KNIT_HOOD: {"catalog": "starter", "block": 4},
		KNIT_HOOD_PLUS: {"catalog": "starter", "block": 6},
		KNIT_SHIELD: {"catalog": "pool", "block": 6},
		KNIT_SHIELD_PLUS: {"catalog": "pool", "block": 8},
	}
	for card_id: String in KNIT_IDS:
		var spec: Dictionary = expected[card_id]
		var own_catalog: Dictionary = starter.get_definition(card_id) \
			if spec["catalog"] == "starter" else pool.get_definition(card_id)
		var other_catalog: Dictionary = pool.get_definition(card_id) \
			if spec["catalog"] == "starter" else starter.get_definition(card_id)
		_check(not own_catalog.is_empty(), card_id + " is authored by its own Yarn catalog")
		_check(other_catalog.is_empty(), card_id + " is not duplicated in the other Yarn catalog")
		_check(own_catalog.get("id") == card_id, card_id + " keeps its exact identifier")
		_check(own_catalog.get("owner") == "yarn_ranger", card_id + " is owned by the Yarn Ranger")
		_check(own_catalog.get("cost") == 1, card_id + " prints one energy")
		_check(own_catalog.get("from_positions") == [1, 2, 3], card_id + " prints FROM seats 1-3")
		_check(own_catalog.get("target_kind") == "ally_single", card_id + " prints a single-ally target")
		_check(own_catalog.get("to_positions") == [], card_id + " prints an empty TO line")
		var effects: Dictionary = own_catalog.get("effects", {})
		_check(effects == {"block": spec["block"], "draw": 1},
			card_id + " prints exactly " + str(spec["block"]) + " Block and one draw")
		_check(effects.size() == 2, card_id + " carries no extra effect key")
		_check(typeof(effects.get("block")) == TYPE_INT and typeof(effects.get("draw")) == TYPE_INT,
			card_id + " prints integer Block and draw values")
		if card_id.ends_with("_plus"):
			_check(own_catalog.get("upgrade_of") == card_id.trim_suffix("_plus")
				and not own_catalog.has("upgrade_id"),
				card_id + " links back to its one base printing")
		else:
			_check(own_catalog.get("upgrade_id") == card_id + "_plus"
				and not own_catalog.has("upgrade_of"),
				card_id + " links forward to its one upgrade")
		_check(resolver.is_supported_card(card_id), card_id + " is a supported knitted card")
		_check(CombatYarnRangerKnitCards.is_authentic_definition(own_catalog, card_id),
			card_id + " passes the definition authenticator")
		var resolved := CombatYarnRangerKnitCards.knit_definition(card_id)
		_check(resolved == own_catalog, card_id + " resolves to its exact detached catalog record")

	# Detached: mutating a resolved record cannot rewrite what the next resolution returns.
	var sample := CombatYarnRangerKnitCards.knit_definition(KNIT_HOOD)
	_check(not sample.is_empty(), "knitted resolution fixture loaded")
	if not sample.is_empty():
		sample["effects"]["block"] = 900
		sample["effects"]["draw"] = 9
		sample["from_positions"].clear()
		sample["cost"] = 0
		_check(CombatYarnRangerKnitCards.knit_definition(KNIT_HOOD)
			== starter.get_definition(KNIT_HOOD),
			"a mutated knitted definition cannot poison later resolutions")

	# Every other Yarn starter/pool card is unrelated, never a knitted card.
	var unrelated: Array = []
	unrelated.append_array(starter.get_all_card_ids())
	unrelated.append_array(pool.get_all_card_ids())
	for card_id: String in KNIT_IDS:
		unrelated.erase(card_id)
	for other_id: Variant in unrelated:
		_check(CombatYarnRangerKnitCards.knit_definition(other_id).is_empty(),
			str(other_id) + " does not resolve as a knitted card")
		_check(not resolver.is_supported_card(other_id),
			str(other_id) + " is not a supported knitted card")
	var forged: Array = ["yarn_ranger_hood_knit+", "yarn_ranger_hood_knit_plus_plus",
		"yarn_ranger_knit_shield_+", "hood_knit", "knit_shield",
		" yarn_ranger_hood_knit", "yarn_ranger_hood_knit ", "KNIT_SHIELD", "",
		"warden_strike", StringName(KNIT_HOOD), null, 0, 3.5, false, [], {}]
	for other_id: Variant in forged:
		_check(CombatYarnRangerKnitCards.knit_definition(other_id).is_empty(),
			"forged or non-string ID never resolves as knitted: " + str(other_id))
		_check(not CombatYarnRangerKnitCards.is_authentic_definition(
			starter.get_definition(KNIT_HOOD), other_id),
			"a knit record cannot authenticate under a forged ID: " + str(other_id))

	# Adversarial copies of a real record: every altered contract field is refused.
	var base_record: Dictionary = starter.get_definition(KNIT_HOOD)
	_check(not base_record.is_empty()
		and CombatYarnRangerKnitCards.is_authentic_definition(base_record, KNIT_HOOD),
		"authenticator positive fixture really is the authored Hood Knit")
	var mutations: Array[Callable] = [
		func(record: Dictionary) -> void: record["effects"]["block"] = 5,
		func(record: Dictionary) -> void: record["effects"]["block"] = 4.0,
		func(record: Dictionary) -> void: record["effects"]["block"] = "4",
		func(record: Dictionary) -> void: record["effects"]["draw"] = 2,
		func(record: Dictionary) -> void: record["effects"]["draw"] = 1.0,
		func(record: Dictionary) -> void: record["effects"].erase("draw"),
		func(record: Dictionary) -> void: record["effects"]["heal"] = 1,
		func(record: Dictionary) -> void: record["effects"] = "block",
		func(record: Dictionary) -> void: record["cost"] = 0,
		func(record: Dictionary) -> void: record["cost"] = 2,
		func(record: Dictionary) -> void: record["cost"] = 1.0,
		func(record: Dictionary) -> void: record["owner"] = "warden",
		func(record: Dictionary) -> void: record["from_positions"] = [2, 3],
		func(record: Dictionary) -> void: record["from_positions"] = ["1", "2", "3"],
		func(record: Dictionary) -> void: record["from_positions"] = "1,2,3",
		func(record: Dictionary) -> void: record["to_positions"] = [1],
		func(record: Dictionary) -> void: record["target_kind"] = "enemy_single",
		func(record: Dictionary) -> void: record["id"] = KNIT_SHIELD,
		func(record: Dictionary) -> void: record.erase("upgrade_id"),
		func(record: Dictionary) -> void: record["upgrade_of"] = KNIT_HOOD,
		func(record: Dictionary) -> void: record.erase("to_positions"),
		func(record: Dictionary) -> void: record.erase("effects"),
	]
	for index in range(mutations.size()):
		var tampered: Dictionary = base_record.duplicate(true)
		mutations[index].call(tampered)
		_check(not CombatYarnRangerKnitCards.is_authentic_definition(tampered, KNIT_HOOD),
			"tampered knitted record " + str(index) + " is refused")
	_check(not CombatYarnRangerKnitCards.is_authentic_definition(
		starter.get_definition(KNIT_HOOD_PLUS), KNIT_HOOD),
		"an upgraded record cannot authenticate as its base ID")
	_check(not CombatYarnRangerKnitCards.is_authentic_definition(
		starter.get_definition(KNIT_HOOD), KNIT_HOOD_PLUS),
		"a base record cannot authenticate as its upgraded ID")
	_check(not CombatYarnRangerKnitCards.is_authentic_definition(
		pool.get_definition(KNIT_SHIELD), KNIT_HOOD),
		"a pool record cannot forge a starter identity")


## AC1/AC2: a real held copy from any seat pays one energy, pads only the chosen living ally with
## the exact printed Block, draws one real shared card and discards exactly one copy.
func _test_knit_paid_block_and_draw() -> void:
	var resolver := CombatYarnRangerKnitCards.new()
	var cases := [
		{"id": KNIT_HOOD, "block": 4, "seat": 1},
		{"id": KNIT_HOOD_PLUS, "block": 6, "seat": 2},
		{"id": KNIT_SHIELD, "block": 6, "seat": 3},
		{"id": KNIT_SHIELD_PLUS, "block": 8, "seat": 1},
	]
	for index in range(cases.size()):
		var entry: Dictionary = cases[index]
		var card_id: String = entry["id"]
		var seat: int = entry["seat"]
		var expected_block: int = entry["block"]
		var target: int = 1 if seat != 1 else 2
		var label: String = card_id + " from seat " + str(seat) + " onto seat " + str(target)
		var party := _knit_party(seat)
		_check(party.gain_block(target, 2), label + ": fixture ally really carries Block")
		var deck := _knit_deck(card_id, 20261101 + index)
		_check(deck.hand.count(card_id) == 1, label + ": exactly one authentic copy is held")
		_check(deck.energy == 3 and deck.turn_active, label + ": a real three-energy turn is active")
		_check(deck.discard_pile.is_empty(), label + ": the fixture discard starts empty")
		var expected_draw: String = deck.draw_pile.back()
		var target_hp: int = int(party.get_hero(target).get("hp"))
		var rng_before: int = deck._rng.state
		var before := _knit_snapshot(deck, party)
		var result: Dictionary = resolver.play_card(deck, party, card_id, target)
		_check(result.get("ok") == true and result.get("reason") == "applied",
			label + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == 1,
			label + ": receipt names the authentic card and its one energy")
		_check(result.get("owner_position") == seat, label + ": receipt reports the real owner seat")
		_check(result.get("target_position") == target, label + ": receipt reports the chosen ally")
		_check(result.get("block_gained") == expected_block,
			label + ": receipt reports the printed Block")
		_check(result.get("drawn") == 1, label + ": receipt reports one shared draw")
		_check(deck.energy == 2, label + ": exactly one energy was paid")
		_check(deck.hand.count(card_id) == 0, label + ": the held copy left the hand")
		_check(deck.hand.has(expected_draw), label + ": the seeded shared draw reached the hand")
		_check(deck.draw_pile.is_empty(), label + ": the single shared draw emptied the supply")
		_check(deck.discard_pile == [card_id], label + ": exactly one played copy reached the discard")
		_check(deck._rng.state == rng_before,
			label + ": drawing from a nonempty supply consumes no RNG")
		_check(party.get_hero(target).get("block") == 2 + expected_block,
			label + ": the chosen ally gained exactly its printed Block on top of existing Block")
		_check(party.get_hero(target).get("hp") == target_hp,
			label + ": the chosen ally's HP is untouched")
		for position in [1, 2, 3]:
			if position == target:
				continue
			_check(party.get_hero(position).get("block") == 0,
				label + ": seat " + str(position) + " gained no Block")
		_check(party.get_hero(seat).get("id") == "yarn_ranger"
			and party.get_hero(seat).get("hp") == 28,
			label + ": the owner and its HP stay unchanged")
		_check(_knit_snapshot(deck, party) == _expected_knit(before, card_id, target, expected_block),
			label + ": exact hand, piles, energy, turn, party and RNG state")

	# Self is a legal recipient for the knitted supports.
	var self_party := _knit_party(2)
	var self_deck := _knit_deck(KNIT_HOOD, 77123)
	var self_result: Dictionary = resolver.play_card(self_deck, self_party, KNIT_HOOD, 2)
	_check(self_result.get("ok") == true, "self-targeted Hood Knit is legal")
	_check(self_party.get_hero(2).get("block") == 4, "self-targeted Hood Knit grants its four Block")
	_check(self_party.get_hero(1).get("block") == 0 and self_party.get_hero(3).get("block") == 0,
		"self-targeted Hood Knit pads nobody else")
	_check(self_party.get_hero(2).get("hp") == 28, "self-targeted Hood Knit spends no HP")


## AC2: an empty supply is a legal zero draw, and a genuine discard refill can never draw the played
## copy back into its own hand.
func _test_knit_draw_supply() -> void:
	var resolver := CombatYarnRangerKnitCards.new()

	# A one-card deck: the card is drawn at turn start, so the shared supply is genuinely empty.
	var empty_party := _knit_party(1)
	var empty_deck := CombatDeck.new([KNIT_HOOD], _knit_rng(5511))
	_check(empty_deck.start_turn() and empty_deck.hand == [KNIT_HOOD],
		"empty-supply fixture really holds the knitted card with no draw or discard left")
	_check(empty_deck.draw_pile.is_empty() and empty_deck.discard_pile.is_empty(),
		"empty-supply fixture really has empty piles")
	var empty_rng: int = empty_deck._rng.state
	var empty_result: Dictionary = resolver.play_card(empty_deck, empty_party, KNIT_HOOD, 1)
	_check(empty_result.get("ok") == true and empty_result.get("drawn") == 0,
		"an empty shared supply is a legal zero draw")
	_check(empty_deck.energy == 2, "the empty-supply play still pays one energy")
	_check(empty_deck.hand.is_empty(), "the empty-supply play leaves nothing undrawn")
	_check(empty_deck.draw_pile.is_empty(), "the empty-supply play invents no draw pile")
	_check(empty_deck.discard_pile == [KNIT_HOOD],
		"the empty-supply play discards exactly the played copy")
	_check(empty_deck._rng.state == empty_rng, "the empty-supply play consumes no RNG")
	_check(empty_party.get_hero(1).get("block") == 4,
		"the empty-supply play still grants the printed Block")

	# Empty draw pile with two genuine discards: the refill reshuffles them, and the still-held
	# played copy must not be swept into the reshuffle and drawn back.
	var refill_party := _knit_party(3)
	var refill_deck := CombatDeck.new([KNIT_SHIELD_PLUS, "knit_refill_a", "knit_refill_b"],
		_knit_rng(6622))
	_check(refill_deck.start_turn() and refill_deck.hand.size() == 3
		and refill_deck.draw_pile.is_empty(),
		"refill fixture drew all three cards into a real turn")
	refill_deck.hand.clear()
	refill_deck.hand.append(KNIT_SHIELD_PLUS)
	refill_deck.discard_pile.append("knit_refill_a")
	refill_deck.discard_pile.append("knit_refill_b")
	_check(refill_deck.hand == [KNIT_SHIELD_PLUS] and refill_deck.discard_pile.size() == 2,
		"refill fixture really leaves an empty draw pile and two discards")
	var refill_rng: int = refill_deck._rng.state
	var refill_result: Dictionary = resolver.play_card(refill_deck, refill_party,
		KNIT_SHIELD_PLUS, 2)
	_check(refill_result.get("ok") == true and refill_result.get("drawn") == 1,
		"the discard refill supplies exactly one shared draw")
	_check(not refill_deck.hand.has(KNIT_SHIELD_PLUS),
		"the played copy cannot refill itself into its own draw")
	_check(refill_deck.hand.size() == 1
		and (refill_deck.hand[0] == "knit_refill_a" or refill_deck.hand[0] == "knit_refill_b"),
		"the single drawn card is one of the genuine discards")
	_check(refill_deck.draw_pile.size() == 1
		and (refill_deck.draw_pile[0] == "knit_refill_a"
			or refill_deck.draw_pile[0] == "knit_refill_b"),
		"the other genuine discard stays in the reshuffled draw pile")
	_check(refill_deck.discard_pile == [KNIT_SHIELD_PLUS],
		"only the played copy reaches the discard after the draw")
	_check(refill_deck.hand.size() + refill_deck.draw_pile.size()
		+ refill_deck.discard_pile.size() == 3,
		"the refill case conserves all three cards")
	_check(refill_deck._rng.state != refill_rng,
		"the genuine reshuffle is drawn through the already-seeded RNG")
	_check(refill_deck.energy == 2, "the refill play pays one energy")
	_check(refill_party.get_hero(2).get("block") == 8,
		"the refill play grants Knit Shield+'s printed eight Block")
	_check(refill_party.get_hero(1).get("block") == 0
		and refill_party.get_hero(3).get("block") == 0,
		"the refill play pads only the chosen ally")


## AC3: every invalid request is inert, carries its reason and proves no mutation of deck, party,
## piles or RNG.
func _test_knit_refusals() -> void:
	var resolver := CombatYarnRangerKnitCards.new()
	var party := _knit_party(2)
	var deck := _knit_deck(KNIT_HOOD, 8811)

	_rejected_knit(resolver, null, party, KNIT_HOOD, 1, "invalid_request", "null deck")
	_rejected_knit(resolver, deck, null, KNIT_HOOD, 1, "invalid_request", "null party")

	# Wrong IDs: unrelated authentic cards, forged spellings and non-strings.
	var wrong_ids: Array = ["yarn_ranger_needle_nock", "yarn_ranger_snare_net",
		"yarn_ranger_hood_knit+", "yarn_ranger_hood_knit_plus_plus",
		"yarn_ranger_knit_shield_plus_plus", "yarn_ranger_knit_shield ", "KNIT_SHIELD", "",
		"warden_strike", StringName(KNIT_HOOD), null, 0, 3.5, false, [], {}]
	for wrong_id: Variant in wrong_ids:
		_rejected_knit(resolver, deck, party, wrong_id, 1, "unsupported_card",
			"unsupported ID " + str(wrong_id))
	# An authentic knitted printing the hand does not hold is still unheld.
	_rejected_knit(resolver, deck, party, KNIT_SHIELD, 1, "card_not_held",
		"authentic but unheld Knit Shield")
	_rejected_knit(resolver, deck, party, KNIT_HOOD_PLUS, 1, "card_not_held",
		"authentic but unheld Hood Knit+")

	# An inactive turn is never paid, even with a real copy in hand.
	var inactive := CombatDeck.new([KNIT_HOOD, "knit_filler_a"], _knit_rng(8812))
	inactive.hand.append(KNIT_HOOD)
	_check(not inactive.turn_active and inactive.hand.has(KNIT_HOOD),
		"inactive fixture really holds a copy outside a turn")
	_rejected_knit(resolver, inactive, party, KNIT_HOOD, 1, "inactive_turn", "inactive turn")

	# A downed owner may not play.
	var torn_owner := _knit_party(3)
	_check(torn_owner.apply_damage(3, 28) and torn_owner.is_downed(3),
		"torn-owner fixture really has a downed Yarn Ranger")
	_rejected_knit(resolver, deck, torn_owner, KNIT_HOOD, 1, "owner_downed", "downed owner")

	# A downed recipient may not be padded.
	var torn_target := _knit_party(2)
	_check(torn_target.apply_damage(1, 40) and torn_target.is_downed(1),
		"torn-target fixture really has a downed front ally")
	_rejected_knit(resolver, deck, torn_target, KNIT_HOOD, 1, "target_downed",
		"downed recipient")

	# An unaffordable copy is refused without a partial charge.
	var poor := _knit_deck(KNIT_HOOD, 8813)
	poor.combat_state.energy = 0
	_check(poor.energy == 0 and poor.hand.has(KNIT_HOOD),
		"short-energy fixture really holds a copy with no energy")
	_rejected_knit(resolver, poor, party, KNIT_HOOD, 1, "insufficient_energy", "no energy")

	# Illegal target slots: only seats 1-3 are real recipients.
	for slot: int in [0, 4, -1, 99]:
		_rejected_knit(resolver, deck, party, KNIT_HOOD, slot, "invalid_target",
			"illegal recipient slot " + str(slot))

	# Block overflow is refused before any payment.
	var overflow := _knit_party(2)
	overflow._heroes[1]["block"] = CombatParty.MAX_INT - 1
	_check(overflow.get_hero(2).get("block") == CombatParty.MAX_INT - 1,
		"overflow fixture really sits one Block below the integer limit")
	_rejected_knit(resolver, deck, overflow, KNIT_HOOD, 2, "block_overflow", "Block overflow")

	# Invalid or malformed rosters fail closed.
	var short_party := CombatParty.new([{"id": "warden", "max_hp": 40}])
	_rejected_knit(resolver, deck, short_party, KNIT_HOOD, 1, "invalid_roster",
		"invalid one-hero party")
	var absent_owner := CombatParty.new([{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 26}])
	_check(absent_owner.is_valid() and absent_owner.get_hero(2).get("id") == "seamstress",
		"absent-owner fixture is a valid party without a Yarn Ranger")
	_rejected_knit(resolver, deck, absent_owner, KNIT_HOOD, 1, "owner_missing",
		"absent Yarn Ranger")
	var duplicate := _knit_party(2)
	duplicate._heroes[2]["id"] = "yarn_ranger"
	_check(duplicate.get_hero(2).get("id") == "yarn_ranger"
		and duplicate.get_hero(3).get("id") == "yarn_ranger",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected_knit(resolver, deck, duplicate, KNIT_HOOD, 1, "invalid_party",
		"duplicate hero identity")
	var bad_hp := _knit_party(2)
	bad_hp._heroes[0]["hp"] = 999
	_rejected_knit(resolver, deck, bad_hp, KNIT_HOOD, 1, "invalid_party", "malformed hero HP")
	var bad_block := _knit_party(2)
	bad_block._heroes[0]["block"] = -1
	_rejected_knit(resolver, deck, bad_block, KNIT_HOOD, 1, "invalid_party",
		"malformed hero Block")
	var bad_position := _knit_party(2)
	bad_position._heroes[0]["position"] = 3
	_rejected_knit(resolver, deck, bad_position, KNIT_HOOD, 1, "invalid_party",
		"malformed hero slot index")
	var bad_identity := _knit_party(2)
	bad_identity._heroes[0]["id"] = ""
	_rejected_knit(resolver, deck, bad_identity, KNIT_HOOD, 1, "invalid_party",
		"empty hero identity")

	# A consumed copy cannot be played twice.
	var repeat_party := _knit_party(3)
	var repeat_deck := _knit_deck(KNIT_SHIELD, 8814)
	_check(resolver.play_card(repeat_deck, repeat_party, KNIT_SHIELD, 1).get("ok") == true,
		"duplicate-play fixture really casts once")
	_check(repeat_deck.energy == 2 and repeat_deck.discard_pile == [KNIT_SHIELD],
		"duplicate-play fixture really spent one energy and discarded the copy")
	_rejected_knit(resolver, repeat_deck, repeat_party, KNIT_SHIELD, 1, "card_not_held",
		"duplicate play of the consumed copy")

	# A refused attempt never poisons the next authentic play on the same objects.
	var retry_deck := _knit_deck(KNIT_HOOD_PLUS, 8815)
	var retry_party := _knit_party(1)
	_rejected_knit(resolver, retry_deck, retry_party, KNIT_SHIELD, 1, "card_not_held",
		"retry: authentic but unheld first")
	_rejected_knit(resolver, retry_deck, retry_party, KNIT_HOOD_PLUS, 0, "invalid_target",
		"retry: illegal slot second")
	var retry_result: Dictionary = resolver.play_card(retry_deck, retry_party,
		KNIT_HOOD_PLUS, 3)
	_check(retry_result.get("ok") == true and retry_deck.energy == 2
		and retry_party.get_hero(3).get("block") == 6,
		"retry: the authentic play then succeeds exactly once")


func _knit_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real three-hero party (distinct IDs, authored HP scale) with the Yarn Ranger in the named seat.
func _knit_party(ranger_position: int) -> CombatParty:
	var heroes: Array = [
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	]
	var ranger: Dictionary = heroes[ranger_position - 1]
	ranger["id"] = "yarn_ranger"
	ranger["max_hp"] = 28
	var party := CombatParty.new(heroes)
	_check(party.is_valid() and party.get_hero(ranger_position).get("id") == "yarn_ranger"
		and party.get_hero(ranger_position).get("hp") == 28,
		"valid three-hero party with a living Yarn Ranger in seat " + str(ranger_position))
	return party


## A genuine seeded six-card turn: five cards drawn and one left in the shared draw pile. The fixture
## then guarantees the hand holds exactly one copy under test while keeping a real card to draw.
func _knit_deck(card_id: String, seed_value: int) -> CombatDeck:
	var ids: Array[String] = [card_id]
	for index in range(5):
		ids.append("knit_filler_" + str(index))
	var deck := CombatDeck.new(ids, _knit_rng(seed_value))
	_check(deck.start_turn() and deck.energy == 3,
		card_id + ": starts a real three-energy shared turn")
	_check(deck.draw_pile.size() == 1, card_id + ": one genuine shared card remains to draw")
	if deck.hand.count(card_id) == 0:
		var found: int = deck.draw_pile.find(card_id)
		if found >= 0:
			var replacement: String = deck.hand[0]
			deck.draw_pile[found] = replacement
			deck.hand[0] = card_id
	_check(deck.hand.count(card_id) == 1,
		card_id + ": the fixture hand genuinely holds exactly one copy")
	return deck


## The complete mutable knitted-play state, including the run RNG and null-safe presence flags.
func _knit_snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
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


## The exact post-transaction state for a play that drew from a nonempty supply: one energy, the
## held copy moved to discard, one card drawn and the printed Block on the chosen seat only.
func _expected_knit(before: Dictionary, card_id: String, target: int,
		block: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - 1
	expected["state_energy"] = int(expected["state_energy"]) - 1
	var hand: Array = expected["hand"]
	_check(hand.count(card_id) == 1, "expected snapshot: exactly one played copy is held")
	hand.remove_at(hand.find(card_id))
	var draw: Array = expected["draw"]
	_check(not draw.is_empty(), "expected snapshot: a genuine shared draw supply exists")
	hand.append(draw.pop_back())
	(expected["discard"] as Array).append(card_id)
	var heroes: Array = expected["party"]
	heroes[target - 1]["block"] = int(heroes[target - 1]["block"]) + block
	return expected


func _rejected_knit(resolver: CombatYarnRangerKnitCards, deck: CombatDeck,
		party: CombatParty, card_id: Variant, target: int, reason: String,
		label: String) -> void:
	var before := _knit_snapshot(deck, party)
	var result: Dictionary = resolver.play_card(deck, party, card_id, target)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(result.get("reason")) + ")")
	_check(_knit_snapshot(deck, party) == before,
		label + ": unchanged energy, hand, piles, turn, party, blocks, HP and RNG")




