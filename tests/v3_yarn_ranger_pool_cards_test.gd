extends SceneTree
## V3-1 Yarn Ranger catalog contract. No live combat/reward/Rest behavior is assumed.
## Extended with deterministic headless combat resolution for Unspool cards.

const YarnRangerPoolCards = preload("res://data/cards/yarn_ranger_pool_cards.gd")
const StarterCards = preload("res://data/cards/starter_cards.gd")
const CombatYarnRangerUnspoolCards = preload("res://scripts/combat_yarn_ranger_unspool_cards.gd")
const CombatParty = preload("res://scripts/combat_party.gd")
const CombatEnemies = preload("res://scripts/combat_enemies.gd")
const CombatDeck = preload("res://scripts/combat_deck.gd")

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_all_base_and_upgrades()
	_test_special_descriptors()
	_test_detached_results()
	_test_invalid_ids()
	_test_starters_unchanged()
	_test_unspool_combat_behavior()
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


