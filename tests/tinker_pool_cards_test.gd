extends SceneTree
## D2-1 standalone, deterministic Tinker reward-only definitions and upgrades.

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	var catalog := TinkerPoolCards.new()
	var expected: Array[Dictionary] = _expected_cards()
	_check(not expected.is_empty(), "authored expectation table available")
	_test_each_card(catalog, expected)
	_test_candidate_membership(catalog, expected)
	_test_deep_copy_and_unknown(catalog)
	_test_starter_unchanged(catalog, expected)
	_test_no_random_consumption()
	if failures.is_empty():
		print("tinker_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("tinker_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _pin() -> Dictionary:
	return {"pinner_identity": "source_hero",
		"trigger": "next_attack_by_different_hero",
		"bonus_damage": 5, "bonus_timing": "before_weak_exposed",
		"consume_once": true, "same_hero_consumes": false}


func _snip(damage: int) -> Dictionary:
	return {"damage": damage, "operator": "or",
		"conditions": [
			{"status": "unravelled"},
			{"gauge": "unravel", "comparison": "at_least_half",
				"threshold": "current_target_threshold"}]}


## Independent expected base/plus effects; an entire dictionary equality check
## catches accidentally scaling Exposed, hit count, draws, own HP loss, etc.
func _expected_cards() -> Array[Dictionary]:
	return [
		{"id": "tinker_rivet_shot", "name": "Rivet Shot", "rarity": "common",
			"cost": 1, "from": [2, 3], "kind": "enemy_single", "to": [1, 2, 3],
			"base": {"damage": 4, "exposed": 1}, "plus": {"damage": 6, "exposed": 1}},
		{"id": "tinker_spring_trap", "name": "Spring Trap", "rarity": "common",
			"cost": 1, "from": [2, 3], "kind": "enemy_single", "to": [1, 2, 3],
			"base": {"damage": 3, "pinned": _pin()}, "plus": {"damage": 4, "pinned": _pin()}},
		{"id": "tinker_scatter_bolts", "name": "Scatter Bolts", "rarity": "common",
			"cost": 1, "from": [3], "kind": "enemy_all", "to": [1, 2, 3],
			"base": {"damage": 3, "living_targets_only": true},
			"plus": {"damage": 4, "living_targets_only": true}},
		{"id": "tinker_spare_parts", "name": "Spare Parts", "rarity": "common",
			"cost": 0, "from": [2, 3], "kind": "self", "to": [],
			"base": {"block": 3, "draw": 1}, "plus": {"block": 4, "draw": 1}},
		{"id": "tinker_long_barrel", "name": "Long Barrel", "rarity": "common",
			"cost": 2, "from": [3], "kind": "enemy_single", "to": [1, 2, 3],
			"base": {"damage": 12}, "plus": {"damage": 16}},
		{"id": "tinker_spool_launcher", "name": "Spool Launcher", "rarity": "common",
			"cost": 1, "from": [2, 3], "kind": "enemy_single", "to": [1, 2, 3],
			"base": {"damage": 3, "unravel": 3}, "plus": {"damage": 4, "unravel": 4}},
		{"id": "tinker_overclock", "name": "Overclock", "rarity": "uncommon",
			"cost": 0, "from": [1, 2, 3], "kind": "self", "to": [],
			"base": {"gain_energy": 1, "self_hp_loss": 3},
			"plus": {"gain_energy": 1, "self_hp_loss": 3}},
		{"id": "tinker_shrapnel_seam", "name": "Shrapnel Seam", "rarity": "uncommon",
			"cost": 2, "from": [3], "kind": "enemy_all", "to": [1, 2, 3],
			"base": {"damage": 5, "unravel": 2, "living_targets_only": true},
			"plus": {"damage": 7, "unravel": 3, "living_targets_only": true}},
		{"id": "tinker_sight_glass", "name": "Sight Glass", "rarity": "uncommon",
			"cost": 1, "from": [2, 3], "kind": "enemy_single", "to": [1, 2, 3],
			"base": {"exposed": 2, "draw": 1}, "plus": {"exposed": 2, "draw": 1}},
		{"id": "tinker_ricochet", "name": "Ricochet", "rarity": "uncommon",
			"cost": 1, "from": [2, 3], "kind": "enemy_random", "to": [1, 2, 3],
			"base": {"damage": 4, "hit_count": 3, "random_target_each_hit": true,
				"rng_source": "run", "living_targets_only": true},
			"plus": {"damage": 6, "hit_count": 3, "random_target_each_hit": true,
				"rng_source": "run", "living_targets_only": true}},
		{"id": "tinker_bobbin_cannon", "name": "Bobbin Cannon", "rarity": "rare",
			"cost": 3, "from": [3], "kind": "enemy_single", "to": [1, 2, 3],
			"base": {"damage": 20}, "plus": {"damage": 26}},
		{"id": "tinker_snip_the_seam", "name": "Snip the Seam", "rarity": "rare",
			"cost": 1, "from": [2, 3], "kind": "enemy_single", "to": [1, 2, 3],
			"base": {"damage": 5, "conditional_damage": _snip(15)},
			"plus": {"damage": 7, "conditional_damage": _snip(20)}}
	]


func _test_each_card(catalog: TinkerPoolCards, expected: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	for row in expected:
		var base_id: String = row["id"]
		var plus_id: String = base_id + "_plus"
		_check(not seen.has(base_id) and not seen.has(plus_id), base_id + " IDs unique")
		seen[base_id] = true
		seen[plus_id] = true
		_check(catalog.has_card(base_id) and catalog.has_card(plus_id),
			base_id + " both versions individually addressable")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " upgrade link")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade twice")
		var base: Dictionary = catalog.get_definition(base_id)
		var plus: Dictionary = catalog.get_definition(plus_id)
		_check(not base.is_empty() and not plus.is_empty(), base_id + " definitions nonempty")
		for is_plus in [false, true]:
			var card: Dictionary = plus if is_plus else base
			var id: String = plus_id if is_plus else base_id
			_check(card.get("id") == id, id + " stable ID")
			_check(card.get("display_name") == row["name"] + ("+" if is_plus else ""),
				id + " display name")
			_check(card.get("owner") == "tinker", id + " Tinker owner")
			_check(card.get("rarity") == row["rarity"], id + " correct rarity")
			_check(card.get("cost") == row["cost"], id + " cost unchanged by upgrade")
			_check(card.get("from_positions") == row["from"], id + " legal source positions")
			_check(card.get("target_kind") == row["kind"], id + " target kind")
			_check(card.get("to_positions") == row["to"], id + " legal target positions")
			_check(card.get("effects") == row["plus" if is_plus else "base"],
				id + " exact typed damage/status/utility effects")
			_check(card.get("illustration_path") == "res://assets/paper/cards/" + base_id + ".png",
				id + " stable placeholder illustration path")
			_check(card.get("starting_copies") == 0, id + " never a starter copy")
			_check(card.get("base_id") == base_id and card.get("upgrade_id") == plus_id
				and card.get("is_upgrade") == is_plus, id + " version metadata")
		# Equality of all nonscaling fields, independently of the authored table.
		for field in ["owner", "rarity", "cost", "from_positions", "target_kind",
				"to_positions", "illustration_path", "starting_copies"]:
			_check(base.get(field) == plus.get(field), base_id + " retains " + field)
	# Explicitly guard the nontrivial semantics, not only dictionary equality.
	var pin: Dictionary = catalog.get_definition("tinker_spring_trap")["effects"]["pinned"]
	_check(pin.get("pinner_identity") == "source_hero" and pin.get("bonus_damage") == 5
		and pin.get("trigger") == "next_attack_by_different_hero"
		and pin.get("same_hero_consumes") == false and pin.get("consume_once") == true
		and pin.get("bonus_timing") == "before_weak_exposed", "Pinned pinner + consumption rule")
	var ricochet: Dictionary = catalog.get_definition("tinker_ricochet_plus")["effects"]
	_check(ricochet.get("hit_count") == 3 and ricochet.get("random_target_each_hit") == true
		and ricochet.get("rng_source") == "run" and ricochet.get("living_targets_only") == true,
		"Ricochet+ three independent living-target seeded-run draws")
	var snip: Dictionary = catalog.get_definition("tinker_snip_the_seam_plus")["effects"]["conditional_damage"]
	_check(snip.get("damage") == 20 and snip.get("operator") == "or"
		and snip.get("conditions") == _snip(20)["conditions"],
		"Snip+ empowered OR predicate uses Unravelled or >= half current threshold")


func _test_candidate_membership(catalog: TinkerPoolCards, expected: Array[Dictionary]) -> void:
	var candidates: Array[String] = catalog.get_pool_card_ids()
	_check(not candidates.is_empty(), "base reward candidates are nonempty")
	var unique: Dictionary = {}
	for id in candidates:
		_check(not unique.has(id), id + " reward candidate appears only once")
		unique[id] = true
		var def: Dictionary = catalog.get_definition(id)
		_check(not def.is_empty() and def.get("is_upgrade") == false
			and def.get("starting_copies") == 0 and def.get("owner") == "tinker",
			id + " reward candidate is a base Tinker card, not a plus")
	for row in expected:
		var base_id: String = row["id"]
		_check(candidates.has(base_id), base_id + " eligible as reward candidate")
		_check(not candidates.has(base_id + "_plus"), base_id + " plus excluded from reward pool")
	candidates.clear()
	_check(catalog.get_pool_card_ids().has("tinker_rivet_shot"),
		"clearing returned candidate array does not alter stored pool")


func _test_deep_copy_and_unknown(catalog: TinkerPoolCards) -> void:
	_check(catalog.get_definition("tinker_missing_card").is_empty(),
		"unknown definition rejects")
	_check(not catalog.has_card("tinker_missing_card") and not catalog.has_card(""),
		"unknown/empty IDs rejected")
	_check(catalog.get_upgrade_id("tinker_missing_card") == ""
		and catalog.get_upgrade_id("") == "", "unknown/empty upgrade query rejects")
	var altered: Dictionary = catalog.get_definition("tinker_snip_the_seam")
	altered["id"] = "forgery"
	altered["from_positions"].clear()
	altered["to_positions"].append(99)
	altered["effects"]["conditional_damage"]["conditions"][0]["status"] = "bad"
	altered["effects"]["conditional_damage"]["conditions"].append({"invented": true})
	altered["effects"]["damage"] = 999
	var pristine: Dictionary = catalog.get_definition("tinker_snip_the_seam")
	_check(pristine.get("id") == "tinker_snip_the_seam"
		and pristine.get("from_positions") == [2, 3]
		and pristine.get("to_positions") == [1, 2, 3]
		and pristine.get("effects") == {"damage": 5, "conditional_damage": _snip(15)},
		"nested predicate dictionaries/arrays and positions are deeply detached")
	var pin: Dictionary = catalog.get_definition("tinker_spring_trap_plus")
	pin["effects"]["pinned"]["trigger"] = "any_hero"
	_check(catalog.get_definition("tinker_spring_trap_plus")["effects"]["pinned"] == _pin(),
		"nested pinned metadata deeply detached")
	var another: Dictionary = catalog.get_definition("tinker_ricochet_plus")
	another["effects"]["hit_count"] = 100
	_check(catalog.get_definition("tinker_ricochet_plus")["effects"]["hit_count"] == 3,
		"separate lookups cannot change multi-hit metadata")


func _test_starter_unchanged(catalog: TinkerPoolCards, expected: Array[Dictionary]) -> void:
	var raw: String = FileAccess.get_file_as_string("res://data/cards/starter_deck.json")
	_check(not raw.is_empty(), "real unchanged starter_deck.json readable")
	var data: Variant = JSON.parse_string(raw)
	_check(data is Array, "starter deck parses as an array")
	if not data is Array:
		return
	var deck: Array = data
	_check(deck.size() == 12, "real shared starter deck retains twelve copies")
	var counts: Dictionary = {
		"warden_strike": 2, "warden_brace": 1, "warden_shield_bash": 1,
		"seamstress_prick": 2, "seamstress_mend": 1, "seamstress_stitch_up": 1,
		"tinker_pop_shot": 2, "tinker_scrap_bomb": 1, "tinker_tune_up": 1}
	for id in counts:
		_check(deck.count(id) == counts[id], id + " original copy count unchanged")
	var starter := StarterCards.new()
	_check(starter.get_starting_deck() == deck, "real JSON and StarterCards starter membership match")
	for row in expected:
		var id: String = row["id"]
		_check(not deck.has(id) and not deck.has(id + "_plus")
			and not starter.has_card(id) and not starter.has_card(id + "_plus"),
			id + " pool/plus not added to original starter catalog/deck")
	_check(catalog.get_definition("tinker_pop_shot").is_empty(),
		"standalone Tinker reward catalog does not shadow starter-only Tinker cards")


func _test_no_random_consumption() -> void:
	seed(814177)
	var expected_next: int = randi()
	seed(814177)
	var fresh := TinkerPoolCards.new()
	for id in fresh.get_pool_card_ids():
		var card: Dictionary = fresh.get_definition(id)
		fresh.get_definition(fresh.get_upgrade_id(id))
		_check(not card.is_empty(), id + " RNG probe reads actual definition")
	_check(randi() == expected_next, "construction and lookup never draw global RNG")
