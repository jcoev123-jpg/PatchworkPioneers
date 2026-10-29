extends SceneTree
## Deterministic headless tests for CombatSeamstressTetherRules (V3-1/V3-2).
## Verifies authored Tether Loop / Tether Stitch (+ upgrades) card authentication,
## pair-link admission, 50% floor-rounded confirmed-hit HP-loss echo in both target
## directions with secondary Block absorption before HP, fail-closed rejection on
## non-Tether/duplicate/slain/out-of-range/replaced pairs, fully blocked hits,
## unconfirmed/stale/inconsistent/replayed receipts, echo-of-echo prevention, and
## zero RNG or deck/turn-lifecycle coupling.

const TetherRulesScript = preload("res://scripts/combat_seamstress_tether_rules.gd")
const V3StarterCatalog = preload("res://data/cards/v3_seamstress_starter_cards.gd")
const V3PoolCatalog = preload("res://data/cards/v3_seamstress_pool_cards.gd")

class ForgedTetherRules extends "res://scripts/combat_seamstress_tether_rules.gd":
	var forged_record: Dictionary = {}

	func _catalog_definition(_card_id: String) -> Dictionary:
		return forged_record.duplicate(true)

const LOOP := "seamstress_v3_tether_loop"
const LOOP_PLUS := "seamstress_v3_tether_loop_plus"
const STITCH := "seamstress_v3_tether_stitch"
const STITCH_PLUS := "seamstress_v3_tether_stitch_plus"
const TETHER_IDS: Array[String] = [LOOP, LOOP_PLUS, STITCH, STITCH_PLUS]

var failures: Array[String] = []
var checks: int = 0
var attacks := CombatStatusAttacks.new()


func _initialize() -> void:
	_test_ac1_catalog_contracts_and_card_authentication()
	_test_ac1_pair_link_admission_and_rejections()
	_test_ac2_confirmed_hit_echo_both_directions_and_block()
	_test_ac2_odd_rounding_overkill_and_status_isolation()
	_test_ac3_no_phantom_echo_and_replay_protection()
	_test_ac3_replaced_identities_and_termite_split()
	_test_ac4_boundary_determinism_and_no_rng()
	if failures.is_empty():
		print("combat_seamstress_tether_rules_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("combat_seamstress_tether_rules_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _enemies() -> CombatEnemies:
	var roster := CombatEnemies.new([
		{"id": "patch_imp", "max_hp": 20},
		{"id": "stitch_hound", "max_hp": 24},
		{"id": "spool_sentry", "max_hp": 28},
	])
	_check(roster.is_valid() and roster.get_enemies().size() == 3
		and roster.get_enemy(1)["hp"] == 20
		and roster.get_enemy(2)["hp"] == 24
		and roster.get_enemy(3)["hp"] == 28,
		"three-enemy fixture is valid and at full HP")
	return roster


func _expected_tether_specs() -> Dictionary:
	return {
		LOOP: {
			"catalog": "starter",
			"display_name": "Tether Loop",
			"cost": 2,
			"starting_copies": 1,
			"reward_eligible": false,
			"upgrade_id": LOOP_PLUS,
			"illustration_path": "res://assets/paper/cards/seamstress_v3_tether_loop.png",
		},
		LOOP_PLUS: {
			"catalog": "starter",
			"display_name": "Tether Loop+",
			"cost": 1,
			"starting_copies": 0,
			"reward_eligible": false,
			"upgrade_of": LOOP,
			"illustration_path": "res://assets/paper/cards/seamstress_v3_tether_loop.png",
		},
		STITCH: {
			"catalog": "pool",
			"display_name": "Tether Stitch",
			"cost": 2,
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": STITCH_PLUS,
			"illustration_path": "res://assets/paper/cards/seamstress_v3_tether_stitch.png",
		},
		STITCH_PLUS: {
			"catalog": "pool",
			"display_name": "Tether Stitch+",
			"cost": 1,
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": STITCH,
			"illustration_path": "res://assets/paper/cards/seamstress_v3_tether_stitch.png",
		},
	}


## AC1: Catalog lookup and strict card definition authentication for all four Tether printings.
func _test_ac1_catalog_contracts_and_card_authentication() -> void:
	var starter := V3StarterCatalog.new()
	var pool := V3PoolCatalog.new()
	var rules := CombatSeamstressTetherRules.new()
	var specs := _expected_tether_specs()
	_check(specs.size() == 4, "fixture covers all four authored Tether printings")

	for card_id: String in TETHER_IDS:
		var spec: Dictionary = specs[card_id]
		var is_starter: bool = spec["catalog"] == "starter"
		var own_catalog: Variant = starter if is_starter else pool
		var other_catalog: Variant = pool if is_starter else starter
		var record: Dictionary = own_catalog.get_definition(card_id)
		_check(not record.is_empty(), card_id + ": exists in its owning catalog")
		_check(not other_catalog.has_card(card_id), card_id + ": absent from the sibling catalog")
		_check(record.get("id") == card_id, card_id + ": authored id")
		_check(record.get("display_name") == spec["display_name"], card_id + ": authored display_name")
		_check(record.get("owner") == "seamstress", card_id + ": authored owner")
		_check(record.get("cost") == spec["cost"], card_id + ": authored cost")
		_check(record.get("from_positions") == [2, 3], card_id + ": authored from_positions [2, 3]")
		_check(record.get("target_kind") == "enemy_pair", card_id + ": authored target_kind enemy_pair")
		_check(record.get("to_positions") == [1, 2, 3], card_id + ": authored to_positions [1, 2, 3]")
		_check(record.get("effects") == {"tether_share_percent": 50},
			card_id + ": authored effects exactly {tether_share_percent: 50}")
		_check(not (record.get("effects") as Dictionary).has("damage"),
			card_id + ": carries no direct damage rider")
		_check(rules.is_supported_card(card_id), card_id + ": supported by ID")
		_check(rules.is_supported_card(record), card_id + ": supported by canonical definition")
		_check(rules.is_authentic_definition(record), card_id + ": passes is_authentic_definition")
		var fetched: Dictionary = rules.get_tether_definition(card_id)
		_check(fetched == record and not is_same(fetched, record),
			card_id + ": get_tether_definition returns a detached exact copy")
		fetched["effects"]["tether_share_percent"] = 99
		_check(rules.get_tether_definition(card_id).get("effects") == {"tether_share_percent": 50},
			card_id + ": mutating returned definition never alters subsequent lookups")

		# Tampered definitions must fail closed.
		var tampered_list: Array[Dictionary] = []
		for field in ["id", "display_name", "owner", "cost", "from_positions",
				"target_kind", "to_positions", "effects", "illustration_path",
				"starting_copies", "reward_eligible"]:
			var missing := record.duplicate(true)
			missing.erase(field)
			tampered_list.append(missing)
		var wrong_share := record.duplicate(true)
		wrong_share["effects"] = {"tether_share_percent": 100}
		tampered_list.append(wrong_share)
		var float_share := record.duplicate(true)
		float_share["effects"] = {"tether_share_percent": 50.0}
		tampered_list.append(float_share)
		var extra_damage := record.duplicate(true)
		extra_damage["effects"] = {"tether_share_percent": 50, "damage": 2}
		tampered_list.append(extra_damage)
		var extra_duration := record.duplicate(true)
		extra_duration["effects"] = {"tether_share_percent": 50, "duration": 2}
		tampered_list.append(extra_duration)
		var wrong_target := record.duplicate(true)
		wrong_target["target_kind"] = "enemy_single"
		tampered_list.append(wrong_target)
		var wrong_from := record.duplicate(true)
		wrong_from["from_positions"] = [1, 2, 3]
		tampered_list.append(wrong_from)
		var wrong_to := record.duplicate(true)
		wrong_to["to_positions"] = [1, 2]
		tampered_list.append(wrong_to)
		var float_cost := record.duplicate(true)
		float_cost["cost"] = float(record["cost"])
		tampered_list.append(float_cost)

		for bad_def: Dictionary in tampered_list:
			_check(not rules.is_authentic_definition(bad_def)
				and not rules.is_supported_card(bad_def),
				card_id + ": rejects tampered definition " + str(bad_def))

		var forged := ForgedTetherRules.new()
		for bad_def: Dictionary in tampered_list:
			forged.forged_record = bad_def
			_check(not forged.is_supported_card(card_id)
				and forged.get_tether_definition(card_id).is_empty(),
				card_id + ": rejects tampered catalog source")
		forged.forged_record = record
		_check(forged.is_supported_card(card_id)
			and forged.get_tether_definition(card_id) == record,
			card_id + ": accepts untampered catalog source")

	# Non-Tether cards and malformed inputs must be rejected.
	var non_tether_ids: Array = [
		"seamstress_v3_thread_prick", "seamstress_v3_thread_prick_plus",
		"seamstress_v3_mending_knot", "seamstress_v3_mending_knot_plus",
		"seamstress_v3_shielding_hem", "seamstress_v3_shielding_hem_plus",
		"seamstress_v3_needle_rain", "seamstress_v3_needle_rain_plus",
		"seamstress_v3_scarlet_knot", "seamstress_v3_scarlet_knot_plus",
		"seamstress_v3_bobbin_snag", "seamstress_v3_bobbin_snag_plus",
		"seamstress_v3_patchwork_poultice", "seamstress_v3_patchwork_poultice_plus",
		"seamstress_v3_darn_the_tear", "seamstress_v3_darn_the_tear_plus",
		"seamstress_v3_blanket_of_barbs", "seamstress_v3_blanket_of_barbs_plus",
		"seamstress_v3_midnight_loom", "seamstress_v3_midnight_loom_plus",
		"seamstress_prick", "seamstress_running_stitch", "warden_strike",
		"tinker_pop_shot", "", "seamstress_v3_tether_loop_plus_plus",
		null, 0, 50, true, [], {}, StringName(LOOP),
	]
	for bad_card: Variant in non_tether_ids:
		_check(not rules.is_supported_card(bad_card)
			and rules.get_tether_definition(bad_card).is_empty(),
			"non-Tether input rejected: " + str(bad_card))
	for starter_id: String in starter.get_all_card_ids():
		if not TETHER_IDS.has(starter_id):
			var def: Dictionary = starter.get_definition(starter_id)
			_check(not rules.is_supported_card(def) and not rules.is_authentic_definition(def),
				"non-Tether starter definition rejected: " + starter_id)
	for pool_id: String in pool.get_all_card_ids():
		if not TETHER_IDS.has(pool_id):
			var def: Dictionary = pool.get_definition(pool_id)
			_check(not rules.is_supported_card(def) and not rules.is_authentic_definition(def),
				"non-Tether pool definition rejected: " + pool_id)


## AC1: Pair-link admission across all four Tether printings and all legal target pairs,
## plus fail-closed rejection of non-Tether, duplicate, slain, and out-of-range targets.
func _test_ac1_pair_link_admission_and_rejections() -> void:
	var rules := CombatSeamstressTetherRules.new()
	var pairs: Array = [[1, 2], [2, 1], [1, 3], [3, 1], [2, 3], [3, 2]]
	var expected_ids := {1: "patch_imp", 2: "stitch_hound", 3: "spool_sentry"}

	for card_id: String in TETHER_IDS:
		var canonical_def: Dictionary = rules.get_tether_definition(card_id)
		_check(not canonical_def.is_empty(), card_id + ": canonical definition loaded")
		for pair: Array in pairs:
			var first_pos: int = int(pair[0])
			var second_pos: int = int(pair[1])
			var enemies := _enemies()
			var before_roster := enemies.get_enemies()
			var link_from_def := rules.authorize_pair_link(
				enemies, canonical_def, first_pos, second_pos)
			var link_from_id := rules.admit_pair_link(enemies, card_id, [first_pos, second_pos])
			_check(link_from_def.get("ok") == true and link_from_id.get("ok") == true,
				"%s admits living pair (%d, %d)" % [card_id, first_pos, second_pos])
			_check(link_from_def == link_from_id,
				"%s definition and ID admission produce identical link for (%d, %d)" % [
					card_id, first_pos, second_pos])
			_check(link_from_def.get("card_id") == card_id
				and link_from_def.get("card_definition") == canonical_def
				and link_from_def.get("share_percent") == 50
				and link_from_def.get("first_position") == first_pos
				and link_from_def.get("second_position") == second_pos
				and link_from_def.get("first_id") == expected_ids[first_pos]
				and link_from_def.get("second_id") == expected_ids[second_pos]
				and link_from_def.get("positions") == [first_pos, second_pos]
				and link_from_def.get("enemy_ids") == {
					first_pos: expected_ids[first_pos],
					second_pos: expected_ids[second_pos],
				},
				"%s link carries exact positions, IDs, and 50%% share for (%d, %d)" % [
					card_id, first_pos, second_pos])
			_check(rules.is_valid_pair_link(link_from_def),
				"%s admitted link passes is_valid_pair_link" % card_id)
			_check(enemies.get_enemies() == before_roster,
				"%s admission does not mutate enemy roster" % card_id)

	# Rejections: duplicate targets, out-of-range targets, non-int positions.
	var enemies := _enemies()
	var loop_def := rules.get_tether_definition(LOOP)
	for dup_pos in [1, 2, 3]:
		var dup := rules.authorize_pair_link(enemies, loop_def, dup_pos, dup_pos)
		_check(dup.get("ok") == false and dup.get("reason") == "duplicate_target"
			and not rules.is_valid_pair_link(dup),
			"duplicate target (%d, %d) rejected" % [dup_pos, dup_pos])
	for bad_pair: Array in [
		[0, 1], [1, 0], [-1, 2], [2, -1], [1, 4], [4, 1], [0, 4], [3, 99],
		[1.0, 2], [1, 2.0], ["1", 2], [1, "2"], [true, 2], [1, null],
	]:
		var res := rules.authorize_pair_link(enemies, loop_def, bad_pair[0], bad_pair[1])
		_check(res.get("ok") == false and not rules.is_valid_pair_link(res),
			"invalid/out-of-range pair rejected: " + str(bad_pair))
	for bad_array: Variant in [[], [1], [1, 2, 3], [1, 1]]:
		var res := rules.authorize_pair_link(enemies, loop_def, bad_array)
		_check(res.get("ok") == false, "malformed pair array rejected: " + str(bad_array))

	# Shorter rosters: slot 3 on a 2-enemy roster and any pair on a 1-enemy roster.
	var two_enemies := CombatEnemies.new([
		{"id": "patch_imp", "max_hp": 12},
		{"id": "stitch_hound", "max_hp": 16},
	])
	_check(rules.authorize_pair_link(two_enemies, loop_def, 1, 2).get("ok") == true,
		"two-enemy roster admits (1, 2)")
	_check(rules.authorize_pair_link(two_enemies, loop_def, 1, 3).get("ok") == false
		and rules.authorize_pair_link(two_enemies, loop_def, 3, 2).get("ok") == false,
		"two-enemy roster rejects unoccupied position 3")
	var solo_enemy := CombatEnemies.new([{"id": "solo_foe", "max_hp": 15}])
	_check(rules.authorize_pair_link(solo_enemy, loop_def, 1, 2).get("ok") == false
		and rules.authorize_pair_link(solo_enemy, loop_def, 1, 1).get("ok") == false,
		"single-enemy roster cannot form a valid pair link")

	# Slain targets: first slain, second slain, both slain.
	var slain_roster := _enemies()
	_check(slain_roster.apply_damage(2, 24) and slain_roster.is_slain(2),
		"slot 2 is genuinely slain")
	var before_slain := slain_roster.get_enemies()
	_check(rules.authorize_pair_link(slain_roster, loop_def, 1, 2).get("ok") == false
		and rules.authorize_pair_link(slain_roster, loop_def, 1, 2).get("reason") == "target_slain",
		"slain second target rejected")
	_check(rules.authorize_pair_link(slain_roster, loop_def, 2, 3).get("ok") == false
		and rules.authorize_pair_link(slain_roster, loop_def, 2, 3).get("reason") == "target_slain",
		"slain first target rejected")
	_check(rules.authorize_pair_link(slain_roster, loop_def, 1, 3).get("ok") == true,
		"remaining two living positions (1, 3) still admitted")
	_check(slain_roster.apply_damage(1, 20) and slain_roster.is_slain(1),
		"slot 1 is also slain")
	_check(rules.authorize_pair_link(slain_roster, loop_def, 1, 2).get("ok") == false
		and rules.authorize_pair_link(slain_roster, loop_def, 1, 3).get("ok") == false,
		"both-slain or one-living roster rejected")
	_check(slain_roster.get_enemies() == [
		slain_roster.get_enemy(1), before_slain[1], before_slain[2]],
		"slain rejections leave roster untouched")

	# Non-Tether cards and invalid rosters.
	var prick_def := V3StarterCatalog.new().get_definition("seamstress_v3_thread_prick")
	var needle_def := V3PoolCatalog.new().get_definition("seamstress_v3_needle_rain")
	var barbs_def := V3PoolCatalog.new().get_definition("seamstress_v3_blanket_of_barbs")
	for bad_card: Variant in [
		prick_def, needle_def, barbs_def, "seamstress_v3_thread_prick",
		"seamstress_v3_blanket_of_barbs", "warden_strike", "", null, 42,
	]:
		var res := rules.authorize_pair_link(enemies, bad_card, 1, 2)
		_check(res.get("ok") == false and res.get("reason") == "unsupported_card",
			"authorize_pair_link rejects non-Tether card: " + str(bad_card))
	_check(rules.authorize_pair_link(null, loop_def, 1, 2).get("ok") == false,
		"null enemies roster rejected")
	_check(rules.authorize_pair_link(CombatEnemies.new([]), loop_def, 1, 2).get("ok") == false,
		"invalid empty enemies roster rejected")


## AC2: True 50% echo in both target directions across all four Tether printings,
## with secondary Block absorbing before HP (including the exact 7 HP -> 3 echo,
## 2 target Block -> 1 HP benchmark and its reversed direction).
func _test_ac2_confirmed_hit_echo_both_directions_and_block() -> void:
	var pairs: Array = [[1, 2], [2, 1], [1, 3], [3, 1], [2, 3], [3, 2]]
	for card_id: String in TETHER_IDS:
		for pair: Array in pairs:
			var first_pos: int = int(pair[0])
			var second_pos: int = int(pair[1])
			# Test hitting first_pos (echoing to second_pos) and hitting second_pos (echoing to first_pos).
			for hit_first in [true, false]:
				var primary_pos: int = first_pos if hit_first else second_pos
				var partner_pos: int = second_pos if hit_first else first_pos
				var third_pos: int = 6 - first_pos - second_pos
				var rules := CombatSeamstressTetherRules.new()
				var enemies := _enemies()
				_check(enemies.gain_block(partner_pos, 2),
					"partner opens with 2 Block")
				_check(enemies.gain_block(third_pos, 5),
					"unlinked third enemy opens with 5 Block")
				var third_before: Dictionary = enemies.get_enemy(third_pos)
				var partner_before: Dictionary = enemies.get_enemy(partner_pos)
				var primary_ref: Dictionary = enemies._enemies[primary_pos - 1]
				var partner_ref: Dictionary = enemies._enemies[partner_pos - 1]
				var third_ref: Dictionary = enemies._enemies[third_pos - 1]

				var link := rules.authorize_pair_link(enemies, card_id, first_pos, second_pos)
				_check(link.get("ok") == true,
					"%s link authorized for (%d, %d)" % [card_id, first_pos, second_pos])

				var pre_hit: Dictionary = enemies.get_enemy(primary_pos)
				var hit_receipt := attacks.resolve_vs_enemy(enemies, primary_pos, 7, {}, {})
				_check(hit_receipt == {"ok": true, "damage": 7, "block_absorbed": 0, "hp_loss": 7},
					"primary attack commits 7 HP loss")

				var echo := rules.resolve_confirmed_hit_echo(
					enemies, link, primary_pos, pre_hit, hit_receipt)
				_check(echo.get("ok") == true and echo.get("applied") == true
					and echo.get("reason") == "echo_applied",
					"%s echo applied from %d to %d" % [card_id, primary_pos, partner_pos])
				_check(echo.get("card_id") == card_id
					and echo.get("share_percent") == 50
					and echo.get("primary_position") == primary_pos
					and echo.get("partner_position") == partner_pos
					and echo.get("primary_hp_loss") == 7
					and echo.get("echo_damage") == 3
					and echo.get("block_absorbed") == 2
					and echo.get("hp_loss") == 1
					and echo.get("partner_block_before") == 2
					and echo.get("partner_block_after") == 0
					and echo.get("partner_hp_before") == int(partner_before["hp"])
					and echo.get("partner_hp_after") == int(partner_before["hp"]) - 1,
					"%s 7 HP loss -> 3 echo -> 2 Block absorbed + 1 HP lost (%d -> %d)" % [
						card_id, primary_pos, partner_pos])
				_check(enemies.get_enemy(primary_pos)["hp"] == int(pre_hit["hp"]) - 7
					and enemies.get_enemy(primary_pos)["block"] == 0,
					"primary enemy retains only its primary hit loss")
				_check(enemies.get_enemy(partner_pos)["hp"] == int(partner_before["hp"]) - 1
					and enemies.get_enemy(partner_pos)["block"] == 0,
					"partner enemy lost 2 Block and 1 HP")
				_check(enemies.get_enemy(third_pos) == third_before,
					"unlinked third enemy is completely untouched")
				_check(is_same(enemies._enemies[primary_pos - 1], primary_ref)
					and is_same(enemies._enemies[partner_pos - 1], partner_ref)
					and is_same(enemies._enemies[third_pos - 1], third_ref),
					"actor dictionary identities preserved in roster")

	# Two-way sequential exchange on the same linked pair: 1 -> 2, then 2 -> 1.
	var seq_rules := CombatSeamstressTetherRules.new()
	var seq_enemies := _enemies()
	_check(seq_enemies.gain_block(1, 3) and seq_enemies.gain_block(2, 2),
		"sequential exchange Block fixtures prepared")
	var seq_link := seq_rules.authorize_pair_link(
		seq_enemies, seq_rules.get_tether_definition(STITCH_PLUS), 1, 2)
	# First hit: enemy 1 has 3 Block, hit for 10 -> 3 Block absorbed, 7 HP lost -> 3 echo to enemy 2 (2 Block, 1 HP).
	var pre_1 := seq_enemies.get_enemy(1)
	var hit_1 := attacks.resolve_vs_enemy(seq_enemies, 1, 10, {}, {})
	_check(hit_1 == {"ok": true, "damage": 10, "block_absorbed": 3, "hp_loss": 7},
		"sequential hit 1: 10 damage against 3 Block loses 7 HP")
	var echo_1 := seq_rules.resolve_confirmed_hit_echo(seq_enemies, seq_link, 1, pre_1, hit_1)
	_check(echo_1.get("ok") == true and echo_1.get("applied") == true
		and echo_1.get("echo_damage") == 3
		and echo_1.get("block_absorbed") == 2 and echo_1.get("hp_loss") == 1,
		"sequential echo 1 uses actual 7 HP lost (3 echo), not 10 attempted damage")
	_check(seq_enemies.get_enemy(1)["hp"] == 13 and seq_enemies.get_enemy(1)["block"] == 0
		and seq_enemies.get_enemy(2)["hp"] == 23 and seq_enemies.get_enemy(2)["block"] == 0,
		"post-echo 1 HP/Block state exact")
	# Second hit in reverse direction: enemy 2 takes 9 HP loss -> 4 echo to enemy 1 (which now has 1 Block).
	_check(seq_enemies.gain_block(1, 1), "enemy 1 gains 1 Block before reverse hit")
	var pre_2 := seq_enemies.get_enemy(2)
	var hit_2 := attacks.resolve_vs_enemy(seq_enemies, 2, 9, {}, {})
	_check(hit_2 == {"ok": true, "damage": 9, "block_absorbed": 0, "hp_loss": 9},
		"sequential hit 2: enemy 2 loses 9 HP")
	var echo_2 := seq_rules.apply_confirmed_hit_echo(seq_enemies, seq_link, 2, pre_2, hit_2)
	_check(echo_2.get("ok") == true and echo_2.get("applied") == true
		and echo_2.get("echo_damage") == 4
		and echo_2.get("block_absorbed") == 1 and echo_2.get("hp_loss") == 3,
		"sequential echo 2 shares floor(9/2)=4 to enemy 1 (1 Block absorbed, 3 HP lost)")
	_check(seq_enemies.get_enemy(1)["hp"] == 10 and seq_enemies.get_enemy(1)["block"] == 0
		and seq_enemies.get_enemy(2)["hp"] == 14 and seq_enemies.get_enemy(2)["block"] == 0,
		"post-echo 2 HP/Block state exact")


## AC2: Floor rounding across odd/even HP losses, overkill clamping, and isolation from
## Bleed/Weak/Exposed, Thorns, Enrage, and Riposte.
func _test_ac2_odd_rounding_overkill_and_status_isolation() -> void:
	var rules := CombatSeamstressTetherRules.new()
	var floor_cases := {
		1: 0, 2: 1, 3: 1, 4: 2, 5: 2, 6: 3, 7: 3, 8: 4, 9: 4, 11: 5, 15: 7,
	}
	for loss: int in floor_cases:
		var expected_echo: int = floor_cases[loss]
		_check(rules.quote_echo_damage(loss) == expected_echo,
			"quote_echo_damage(%d) == %d" % [loss, expected_echo])
		var enemies := _enemies()
		var link := rules.authorize_pair_link(enemies, LOOP, 1, 2)
		var pre := enemies.get_enemy(1)
		var hit := attacks.resolve_vs_enemy(enemies, 1, loss, {}, {})
		_check(hit["hp_loss"] == loss, "primary hit loses %d HP" % loss)
		var echo := rules.resolve_confirmed_hit_echo(enemies, link, 1, pre, hit)
		_check(echo.get("ok") == true
			and echo.get("applied") == (expected_echo > 0)
			and echo.get("echo_damage") == expected_echo
			and echo.get("hp_loss") == expected_echo
			and enemies.get_enemy(2)["hp"] == 24 - expected_echo,
			"live roster floor rounding for %d HP loss -> %d echo" % [loss, expected_echo])

	# Overkill on primary enemy shares floor(actual_hp_loss / 2), never floor(damage / 2).
	var overkill_enemies := CombatEnemies.new([
		{"id": "frail_imp", "max_hp": 7},
		{"id": "tough_partner", "max_hp": 30},
	])
	_check(overkill_enemies.gain_block(2, 1), "partner has 1 Block for overkill test")
	var overkill_link := rules.authorize_pair_link(overkill_enemies, STITCH, 1, 2)
	var pre_overkill := overkill_enemies.get_enemy(1)
	var overkill_hit := attacks.resolve_vs_enemy(overkill_enemies, 1, 20, {}, {})
	_check(overkill_hit == {"ok": true, "damage": 20, "block_absorbed": 0, "hp_loss": 7}
		and overkill_enemies.is_slain(1),
		"lethal 20-damage hit on 7-HP primary reports 7 actual HP loss")
	var overkill_echo := rules.resolve_confirmed_hit_echo(
		overkill_enemies, overkill_link, 1, pre_overkill, overkill_hit)
	_check(overkill_echo.get("ok") == true and overkill_echo.get("applied") == true
		and overkill_echo.get("echo_damage") == 3
		and overkill_echo.get("block_absorbed") == 1
		and overkill_echo.get("hp_loss") == 2
		and overkill_enemies.get_enemy(2)["hp"] == 28
		and overkill_enemies.get_enemy(2)["block"] == 0,
		"overkill primary hit shares floor(7/2)=3 (not floor(20/2)=10) to living partner")

	# Echo is raw damage on the partner: it does not re-apply partner Exposed/Tangled,
	# and does not fabricate Bleed/Weak/Exposed, Thorns, Enrage, or Riposte.
	var status_enemies := CombatEnemies.new([
		{"id": "primary_foe", "max_hp": 25, "thorns": 4, "enrage": true, "enrage_stacks": 1},
		{"id": "partner_foe", "max_hp": 25, "thorns": 3, "enrage": true, "enrage_stacks": 1},
	])
	status_enemies._enemies[0]["statuses"] = {"bleed": 2, "exposed": 1, "riposte": 2}
	status_enemies._enemies[1]["statuses"] = {
		"bleed": 1, "weak": 1, "exposed": 2, "tangled": 2, "riposte": 3,
	}
	var status_link := rules.authorize_pair_link(status_enemies, LOOP_PLUS, 1, 2)
	var pre_status := status_enemies.get_enemy(1)
	# Base 6 against Exposed 1 on primary -> 9 damage, 9 HP loss -> floor(9/2) = 4 raw echo.
	# Partner's Exposed 2 and Tangled 2 must NOT modify the 4 raw echo damage.
	var status_hit := attacks.resolve_vs_enemy(
		status_enemies, 1, 6, {}, pre_status["statuses"])
	_check(status_hit == {"ok": true, "damage": 9, "block_absorbed": 0, "hp_loss": 9},
		"primary Exposed hit deals 9 HP loss")
	var status_echo := rules.resolve_confirmed_hit_echo(
		status_enemies, status_link, 1, pre_status, status_hit)
	_check(status_echo.get("ok") == true and status_echo.get("applied") == true
		and status_echo.get("echo_damage") == 4
		and status_echo.get("hp_loss") == 4
		and status_enemies.get_enemy(2)["hp"] == 21,
		"partner receives exact raw 4 echo damage without Exposed/Tangled amplification")
	_check(status_enemies.get_enemy(1)["statuses"] == {"bleed": 2, "exposed": 1, "riposte": 2}
		and status_enemies.get_enemy(2)["statuses"] == {
			"bleed": 1, "weak": 1, "exposed": 2, "tangled": 2, "riposte": 3,
		},
		"echo neither fabricates nor mutates statuses on primary or partner")
	_check(status_enemies.get_enemy(1)["enrage_stacks"] == 1
		and status_enemies.get_enemy(2)["enrage_stacks"] == 1
		and status_enemies.get_enemy(1)["thorns"] == 4
		and status_enemies.get_enemy(2)["thorns"] == 3,
		"echo does not trigger Enrage stacks or alter Thorns on either enemy")


## AC3: No phantom echo on fully blocked hits, zero-damage hits, slain partners,
## failed/unconfirmed attacks, stale/uncommitted snapshots, mismatched receipts,
## duplicate/replayed receipts, or echo-of-echo attempts.
func _test_ac3_no_phantom_echo_and_replay_protection() -> void:
	var rules := CombatSeamstressTetherRules.new()

	# 1. Fully blocked hit -> 0 HP loss -> 0 echo, partner untouched.
	var blocked_enemies := _enemies()
	_check(blocked_enemies.gain_block(1, 8) and blocked_enemies.gain_block(2, 3),
		"blocked fixture prepared")
	var blocked_link := rules.authorize_pair_link(blocked_enemies, LOOP, 1, 2)
	var pre_blocked := blocked_enemies.get_enemy(1)
	var partner_before := blocked_enemies.get_enemy(2)
	var blocked_hit := attacks.resolve_vs_enemy(blocked_enemies, 1, 6, {}, {})
	_check(blocked_hit == {"ok": true, "damage": 6, "block_absorbed": 6, "hp_loss": 0},
		"primary hit is completely absorbed by Block")
	var blocked_echo := rules.resolve_confirmed_hit_echo(
		blocked_enemies, blocked_link, 1, pre_blocked, blocked_hit)
	_check(blocked_echo.get("ok") == true and blocked_echo.get("applied") == false
		and blocked_echo.get("reason") == "no_hp_loss"
		and blocked_echo.get("echo_damage") == 0
		and blocked_echo.get("block_absorbed") == 0
		and blocked_echo.get("hp_loss") == 0,
		"fully blocked primary hit produces 0 echo")
	_check(blocked_enemies.get_enemy(2) == partner_before,
		"partner HP and Block untouched on fully blocked primary hit")
	# Replaying the fully blocked receipt is rejected as duplicate.
	var blocked_replay := rules.resolve_confirmed_hit_echo(
		blocked_enemies, blocked_link, 1, pre_blocked, blocked_hit)
	_check(blocked_replay.get("ok") == false
		and blocked_replay.get("reason") == "duplicate_receipt"
		and blocked_enemies.get_enemy(2) == partner_before,
		"replaying a consumed fully-blocked receipt fails closed")

	# 2. Zero-damage confirmed hit -> 0 echo, and replay rejected.
	var zero_enemies := _enemies()
	var zero_link := rules.authorize_pair_link(zero_enemies, STITCH, 1, 2)
	var pre_zero := zero_enemies.get_enemy(1)
	var zero_hit := attacks.resolve_vs_enemy(zero_enemies, 1, 0, {}, {})
	_check(zero_hit == {"ok": true, "damage": 0, "block_absorbed": 0, "hp_loss": 0},
		"zero-damage hit receipt")
	var zero_echo := rules.resolve_confirmed_hit_echo(
		zero_enemies, zero_link, 1, pre_zero, zero_hit)
	_check(zero_echo.get("ok") == true and zero_echo.get("applied") == false
		and zero_echo.get("echo_damage") == 0,
		"zero-damage hit produces 0 echo")
	var zero_replay := rules.resolve_confirmed_hit_echo(
		zero_enemies, zero_link, 1, pre_zero, zero_hit)
	_check(zero_replay.get("ok") == false and zero_replay.get("reason") == "duplicate_receipt",
		"replaying zero-damage receipt is rejected")

	# 3. Partner slain after link was established -> 0 echo, dead partner untouched.
	var partner_dead_enemies := _enemies()
	var partner_dead_link := rules.authorize_pair_link(partner_dead_enemies, LOOP_PLUS, 1, 2)
	_check(attacks.resolve_vs_enemy(partner_dead_enemies, 2, 24, {}, {})["hp_loss"] == 24
		and partner_dead_enemies.is_slain(2),
		"partner at slot 2 is slain after linking")
	var dead_partner_snapshot := partner_dead_enemies.get_enemy(2)
	var pre_surviving := partner_dead_enemies.get_enemy(1)
	var surviving_hit := attacks.resolve_vs_enemy(partner_dead_enemies, 1, 8, {}, {})
	var dead_partner_echo := rules.resolve_confirmed_hit_echo(
		partner_dead_enemies, partner_dead_link, 1, pre_surviving, surviving_hit)
	_check(dead_partner_echo.get("ok") == true and dead_partner_echo.get("applied") == false
		and dead_partner_echo.get("reason") == "partner_slain"
		and dead_partner_echo.get("echo_damage") == 0
		and dead_partner_echo.get("hp_loss") == 0
		and partner_dead_enemies.get_enemy(2) == dead_partner_snapshot,
		"when linked partner is dead, echo amount is 0 and dead partner stays slain")

	# 4. Failed / unconfirmed attack attempt -> fail closed.
	var fail_enemies := _enemies()
	var fail_link := rules.authorize_pair_link(fail_enemies, STITCH_PLUS, 1, 2)
	var pre_fail := fail_enemies.get_enemy(1)
	var before_fail := fail_enemies.get_enemies()
	var failed_receipt := attacks.resolve_vs_enemy(fail_enemies, 1, -1, {}, {})
	_check(failed_receipt.get("ok") == false, "negative damage attack fails")
	var failed_echo := rules.resolve_confirmed_hit_echo(
		fail_enemies, fail_link, 1, pre_fail, failed_receipt)
	_check(failed_echo.get("ok") == false and failed_echo.get("reason") == "unconfirmed_hit"
		and failed_echo.get("echo_damage") == 0
		and fail_enemies.get_enemies() == before_fail,
		"failed primary attack receipt produces no echo and mutates nothing")

	# 5. Uncommitted / preview receipt (primary enemy was never actually damaged).
	var preview_echo := rules.resolve_confirmed_hit_echo(
		fail_enemies, fail_link, 1, pre_fail,
		{"ok": true, "damage": 8, "block_absorbed": 0, "hp_loss": 8})
	_check(preview_echo.get("ok") == false
		and preview_echo.get("reason") == "stale_or_uncommitted_primary"
		and fail_enemies.get_enemies() == before_fail,
		"uncommitted intent/preview receipt fails closed without damaging partner")

	# 6. Duplicate receipt replay (same reference, cloned dictionary, and explicit receipt_id).
	var replay_enemies := _enemies()
	_check(replay_enemies.gain_block(2, 2), "replay partner has 2 Block")
	var replay_link := rules.authorize_pair_link(replay_enemies, LOOP, 1, 2)
	var pre_replay := replay_enemies.get_enemy(1)
	var committed_hit := attacks.resolve_vs_enemy(replay_enemies, 1, 7, {}, {})
	var first_echo := rules.resolve_confirmed_hit_echo(
		replay_enemies, replay_link, 1, pre_replay, committed_hit, "hit_001")
	_check(first_echo.get("ok") == true and first_echo.get("applied") == true
		and first_echo.get("echo_damage") == 3
		and replay_enemies.get_enemy(2)["hp"] == 23
		and replay_enemies.get_enemy(2)["block"] == 0,
		"first committed receipt echoes once")
	var post_first_echo_roster := replay_enemies.get_enemies()

	var same_ref_replay := rules.resolve_confirmed_hit_echo(
		replay_enemies, replay_link, 1, pre_replay, committed_hit)
	_check(same_ref_replay.get("ok") == false
		and same_ref_replay.get("reason") == "duplicate_receipt"
		and same_ref_replay.get("echo_damage") == 0
		and replay_enemies.get_enemies() == post_first_echo_roster,
		"replaying the same receipt Dictionary reference is rejected")

	var cloned_dict_replay := rules.resolve_confirmed_hit_echo(
		replay_enemies, replay_link, 1, pre_replay.duplicate(true),
		committed_hit.duplicate(true))
	_check(cloned_dict_replay.get("ok") == false
		and cloned_dict_replay.get("reason") == "duplicate_receipt"
		and cloned_dict_replay.get("echo_damage") == 0
		and replay_enemies.get_enemies() == post_first_echo_roster,
		"replaying a cloned receipt Dictionary for the same transition is rejected")

	# Even on a new hit, reusing an already-spent receipt_id is rejected before any echo.
	var pre_second := replay_enemies.get_enemy(1)
	var second_hit := attacks.resolve_vs_enemy(replay_enemies, 1, 6, {}, {})
	var post_second_primary := replay_enemies.get_enemies()
	var dup_id_attempt := rules.resolve_confirmed_hit_echo(
		replay_enemies, replay_link, 1, pre_second, second_hit, "hit_001")
	_check(dup_id_attempt.get("ok") == false
		and dup_id_attempt.get("reason") == "duplicate_receipt"
		and replay_enemies.get_enemies() == post_second_primary,
		"reusing an already-consumed receipt_id fails closed")
	var valid_second_echo := rules.resolve_confirmed_hit_echo(
		replay_enemies, replay_link, 1, pre_second, second_hit, "hit_002")
	_check(valid_second_echo.get("ok") == true and valid_second_echo.get("applied") == true
		and valid_second_echo.get("echo_damage") == 3
		and replay_enemies.get_enemy(2)["hp"] == 20,
		"fresh receipt with fresh receipt_id succeeds after rejected duplicate_id attempt")

	# 7. Echo cannot trigger another echo (neither via echo receipt nor via forged 4-key receipt).
	var reecho_enemies := _enemies()
	var reecho_link := rules.authorize_pair_link(reecho_enemies, STITCH, 1, 2)
	var enemy1_pre := reecho_enemies.get_enemy(1)
	var enemy2_pre_echo := reecho_enemies.get_enemy(2)
	var primary_hit := attacks.resolve_vs_enemy(reecho_enemies, 1, 8, {}, {})
	var primary_echo := rules.resolve_confirmed_hit_echo(
		reecho_enemies, reecho_link, 1, enemy1_pre, primary_hit)
	_check(primary_echo.get("ok") == true and primary_echo.get("echo_damage") == 4
		and reecho_enemies.get_enemy(2)["hp"] == 20,
		"primary hit echoes 4 damage onto enemy 2")
	var after_primary_echo := reecho_enemies.get_enemies()
	# Passing the echo receipt itself as a primary receipt fails closed.
	var direct_reecho := rules.resolve_confirmed_hit_echo(
		reecho_enemies, reecho_link, 2, enemy2_pre_echo, primary_echo)
	_check(direct_reecho.get("ok") == false
		and direct_reecho.get("reason") == "invalid_receipt"
		and reecho_enemies.get_enemies() == after_primary_echo,
		"echo receipt cannot be used as a primary attack receipt")
	# Even forging a 4-key receipt from the partner's echo transition is caught and rejected.
	var forged_reecho := rules.resolve_confirmed_hit_echo(
		reecho_enemies, reecho_link, 2, enemy2_pre_echo,
		{"ok": true, "damage": 4, "block_absorbed": 0, "hp_loss": 4})
	_check(forged_reecho.get("ok") == false
		and forged_reecho.get("reason") == "echo_cannot_reecho"
		and reecho_enemies.get_enemies() == after_primary_echo,
		"forged 4-key receipt from partner's echo transition cannot echo back to primary")

	# 8. Receipt / snapshot mismatches and unlinked targets fail closed.
	var mismatch_enemies := _enemies()
	_check(mismatch_enemies.gain_block(1, 3), "mismatch primary has 3 Block")
	var mismatch_link := rules.authorize_pair_link(mismatch_enemies, LOOP, 1, 2)
	var pre_mismatch := mismatch_enemies.get_enemy(1)
	var real_hit := attacks.resolve_vs_enemy(mismatch_enemies, 1, 9, {}, {})
	_check(real_hit == {"ok": true, "damage": 9, "block_absorbed": 3, "hp_loss": 6},
		"real hit absorbed 3 Block and lost 6 HP")
	var post_hit_roster := mismatch_enemies.get_enemies()
	# Forged hp_loss (claiming 9 instead of 6).
	var bad_hp_loss := rules.resolve_confirmed_hit_echo(
		mismatch_enemies, mismatch_link, 1, pre_mismatch,
		{"ok": true, "damage": 9, "block_absorbed": 3, "hp_loss": 9})
	_check(bad_hp_loss.get("ok") == false and bad_hp_loss.get("reason") == "receipt_mismatch"
		and mismatch_enemies.get_enemies() == post_hit_roster,
		"mismatched receipt hp_loss rejected")
	# Forged block_absorbed.
	var bad_block := rules.resolve_confirmed_hit_echo(
		mismatch_enemies, mismatch_link, 1, pre_mismatch,
		{"ok": true, "damage": 9, "block_absorbed": 0, "hp_loss": 6})
	_check(bad_block.get("ok") == false and bad_block.get("reason") == "receipt_mismatch"
		and mismatch_enemies.get_enemies() == post_hit_roster,
		"mismatched receipt block_absorbed rejected")
	# Tampered pre_hit snapshot (wrong pre-hit HP, Block, ID, or position).
	var wrong_pre_hp := pre_mismatch.duplicate(true)
	wrong_pre_hp["hp"] = 19
	_check(rules.resolve_confirmed_hit_echo(
		mismatch_enemies, mismatch_link, 1, wrong_pre_hp, real_hit).get("ok") == false,
		"tampered pre-hit HP rejected")
	var wrong_pre_block := pre_mismatch.duplicate(true)
	wrong_pre_block["block"] = 0
	_check(rules.resolve_confirmed_hit_echo(
		mismatch_enemies, mismatch_link, 1, wrong_pre_block, real_hit).get("ok") == false,
		"tampered pre-hit Block rejected")
	var wrong_pre_id := pre_mismatch.duplicate(true)
	wrong_pre_id["id"] = "impostor_imp"
	_check(rules.resolve_confirmed_hit_echo(
		mismatch_enemies, mismatch_link, 1, wrong_pre_id, real_hit).get("ok") == false,
		"tampered pre-hit ID rejected")
	# Unlinked 3rd enemy hit cannot echo across (1, 2) link.
	var pre_third := mismatch_enemies.get_enemy(3)
	var third_hit := attacks.resolve_vs_enemy(mismatch_enemies, 3, 8, {}, {})
	var post_third_roster := mismatch_enemies.get_enemies()
	var unlinked_echo := rules.resolve_confirmed_hit_echo(
		mismatch_enemies, mismatch_link, 3, pre_third, third_hit)
	_check(unlinked_echo.get("ok") == false
		and unlinked_echo.get("reason") == "unlinked_primary"
		and mismatch_enemies.get_enemies() == post_third_roster,
		"hitting unlinked slot 3 does not echo to linked slots 1 or 2")


## AC3: Replaced enemy identities (including Quilt Termite split_on_death replacement)
## fail closed so a link bound to the original actor never damages a replacement actor.
func _test_ac3_replaced_identities_and_termite_split() -> void:
	var rules := CombatSeamstressTetherRules.new()
	var termite: Dictionary = {}
	var records: Array = RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	for record: Dictionary in records:
		if record.get("id") == CombatEnemies.TERMITE_ID:
			termite = record.duplicate(true)
			break
	_check(not termite.is_empty(), "shipped Quilt Termite record loaded from run_enemies.json")
	var enemies := CombatEnemies.new([
		{"id": "patch_imp", "max_hp": 20},
		termite,
	])
	_check(enemies.is_valid(), "termite pair fixture is valid")
	var link := rules.authorize_pair_link(enemies, LOOP, 1, 2)
	_check(link.get("ok") == true and link.get("second_id") == "quilt_termite",
		"pair link binds slot 2 to quilt_termite")

	# Slay the Quilt Termite and stage its split so slot 2 becomes quilt_termite_half_left.
	_check(attacks.resolve_vs_enemy(enemies, 2, 26, {}, {})["hp_loss"] == 26
		and enemies.is_slain(2),
		"parent Quilt Termite is slain")
	var split_res := enemies.stage_split_on_death(2)
	_check(split_res.get("ok") == true and split_res.get("split") == true
		and enemies.get_enemy(2)["id"] == "quilt_termite_half_left",
		"slot 2 is now occupied by replacement child quilt_termite_half_left")

	# Hitting slot 1 must NOT echo onto the replacement actor at slot 2.
	var pre_imp := enemies.get_enemy(1)
	var imp_hit := attacks.resolve_vs_enemy(enemies, 1, 8, {}, {})
	var post_imp_roster := enemies.get_enemies()
	var echo_to_replaced := rules.resolve_confirmed_hit_echo(
		enemies, link, 1, pre_imp, imp_hit)
	_check(echo_to_replaced.get("ok") == false
		and echo_to_replaced.get("reason") == "partner_identity_mismatch"
		and enemies.get_enemies() == post_imp_roster,
		"echo refuses to damage replacement child actor in partner slot")

	# Hitting the replacement child at slot 2 must NOT echo onto slot 1 using the old parent link.
	var pre_half := enemies.get_enemy(2)
	var half_hit := attacks.resolve_vs_enemy(enemies, 2, 6, {}, {})
	var post_half_roster := enemies.get_enemies()
	var echo_from_replaced := rules.resolve_confirmed_hit_echo(
		enemies, link, 2, pre_half, half_hit)
	_check(echo_from_replaced.get("ok") == false
		and echo_from_replaced.get("reason") == "primary_identity_mismatch"
		and enemies.get_enemies() == post_half_roster,
		"replacement child in primary slot cannot echo through parent's link")


## AC4: Small separate integration boundary (no card-play, deck, or turn-lifecycle
## ownership), RNG immutability, and deterministic replay across fresh instances.
func _test_ac4_boundary_determinism_and_no_rng() -> void:
	var rules := CombatSeamstressTetherRules.new()
	for forbidden_method in [
		"play_card", "play_from_hand", "begin_player_turn",
		"end_player_turn", "tick_turn", "advance_turn",
	]:
		_check(not rules.has_method(forbidden_method),
			"service does not claim card-play or turn-lifecycle method: " + forbidden_method)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261029
	var rng_before: int = rng.state
	seed(987654321)
	var global_expected: int = randi()
	seed(987654321)

	var snapshots: Array = []
	var echo_logs: Array = []
	for run_idx in range(2):
		var local_rules := CombatSeamstressTetherRules.new()
		var local_enemies := _enemies()
		_check(local_enemies.gain_block(1, 1) and local_enemies.gain_block(2, 2)
			and local_enemies.gain_block(3, 4),
			"determinism Block setup")
		var link_a := local_rules.authorize_pair_link(local_enemies, LOOP, 1, 2)
		var pre_a := local_enemies.get_enemy(1)
		var hit_a := attacks.resolve_vs_enemy(local_enemies, 1, 8, {}, {})
		var echo_a := local_rules.resolve_confirmed_hit_echo(
			local_enemies, link_a, 1, pre_a, hit_a)

		var link_b := local_rules.authorize_pair_link(local_enemies, STITCH_PLUS, 2, 3)
		var pre_b := local_enemies.get_enemy(3)
		var hit_b := attacks.resolve_vs_enemy(local_enemies, 3, 11, {}, {})
		var echo_b := local_rules.resolve_confirmed_hit_echo(
			local_enemies, link_b, pre_b, hit_b)

		snapshots.append(local_enemies.get_enemies())
		echo_logs.append([link_a, echo_a, link_b, echo_b])

	_check(snapshots[0] == snapshots[1] and echo_logs[0] == echo_logs[1],
		"independent runs produce identical links, echo receipts, and roster transitions")
	_check(rng.state == rng_before and randi() == global_expected,
		"Tether rules consume zero local or global RNG draws")
