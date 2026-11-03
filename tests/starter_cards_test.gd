extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_definitions_exist()
	_test_warden_cards()
	_test_strike_plus()
	_test_support_plus()
	_test_offensive_plus()
	_test_seamstress_cards()
	_test_tinker_cards()
	_test_starting_deck_multiplicities()
	_test_v3_seamstress_starter_lookup()
	_test_v3_seamstress_records_are_detached()
	_test_v3_seamstress_unknown_ids_fail_closed()
	_test_unknown_id_returns_empty()
	_test_returned_data_is_deep_copy()
	_test_starting_deck_is_fresh_copy()
	if failures.is_empty():
		print("starter_cards_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("starter_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _get_catalog():
	var script = load("res://data/cards/starter_cards.gd")
	return script.new()


func _test_strike_plus() -> void:
	var catalog := StarterCards.new()
	var upgraded := catalog.get_definition("warden_strike_plus")
	var original := catalog.get_definition("warden_strike")
	_check(upgraded.get("id") == "warden_strike_plus", "Strike+ authored ID")
	_check(upgraded.get("display_name") == "Strike+", "Strike+ visible name")
	_check(upgraded.get("effects") == {"damage": 7}, "Strike+ exactly seven base damage")
	_check(upgraded.get("starting_copies") == 0 and not catalog.get_starting_deck().has("warden_strike_plus"), "upgrade adds no starter copies")
	for field in ["owner", "cost", "from_positions", "target_kind", "to_positions"]:
		_check(upgraded.get(field) == original.get(field), "Strike+ retains " + field)
	_check(catalog.get_starting_deck() == JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/starter_deck.json")), "exact twelve-card starter membership and order retained")


func _test_offensive_plus() -> void:
	var catalog := StarterCards.new()
	var expectations := {
		"warden_shield_bash_plus": ["Shield Bash+", {"damage": 11, "weak": 1}],
		"seamstress_prick_plus": ["Prick+", {"damage": 4, "bleed": 3}],
		"tinker_pop_shot_plus": ["Pop Shot+", {"damage": 7}],
		"tinker_scrap_bomb_plus": ["Scrap Bomb+", {"damage": 6}],
	}
	var starter_deck := catalog.get_starting_deck()
	
	for plus_id: String in expectations:
		var expected_name: String = expectations[plus_id][0]
		var expected_effects: Dictionary = expectations[plus_id][1]
		var base_id: String = plus_id.trim_suffix("_plus")
		
		var plus_def: Dictionary = catalog.get_definition(plus_id)
		var base_def: Dictionary = catalog.get_definition(base_id)
		
		_check(not plus_def.is_empty(), plus_id + " is authored")
		_check(plus_def.get("id") == plus_id, plus_id + " ID matches")
		_check(plus_def.get("display_name") == expected_name, plus_id + " display name")
		_check(plus_def.get("effects") == expected_effects, plus_id + " effects match exact requirements")
		_check(plus_def.get("starting_copies") == 0, plus_id + " starts with 0 copies")
		_check(not starter_deck.has(plus_id), plus_id + " is absent from starting deck")
		
		for field in ["owner", "cost", "from_positions", "target_kind", "to_positions", "illustration_path"]:
			_check(plus_def.get(field) == base_def.get(field), plus_id + " retains base " + field)


func _test_support_plus() -> void:
	var catalog := StarterCards.new()
	var expectations := {
		"tinker_tune_up_plus": ["Tune Up+", "tinker", "none", "draw", 2, [1, 2, 3]],
		"warden_brace_plus": ["Brace+", "warden", "self", "block", 10, [1, 2, 3]],
		"seamstress_mend_plus": ["Mend+", "seamstress", "ally_single", "heal", 7, [2, 3]],
		"seamstress_stitch_up_plus": ["Stitch Up+", "seamstress", "ally_single", "block", 7, [1, 2, 3]],
	}
	var starter_deck := catalog.get_starting_deck()
	var authored = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/starter_deck.json"))
	for card_id: String in expectations:
		var expected: Array = expectations[card_id]
		var plus: Dictionary = catalog.get_definition(card_id)
		var base: Dictionary = catalog.get_definition(card_id.trim_suffix("_plus"))
		_check(plus.get("id") == card_id and not plus.is_empty(), card_id + " authored ID")
		_check(plus.get("display_name") == expected[0], card_id + " visible name")
		_check(plus.get("owner") == expected[1], card_id + " owner")
		_check(plus.get("cost") == (0 if card_id == "tinker_tune_up_plus" else 1), card_id + " cost")
		_check(plus.get("from_positions") == expected[5], card_id + " from_positions")
		_check(plus.get("target_kind") == expected[2], card_id + " target_kind")
		_check(plus.get("to_positions") == [], card_id + " to_positions empty")
		_check(plus.get("effects") == {expected[3]: expected[4]}, card_id + " sole intended effect")
		_check(plus.get("starting_copies") == 0, card_id + " adds no starter copies")
		_check(not starter_deck.has(card_id), card_id + " absent from the starting deck")
		_check(plus.get("illustration_path") == base.get("illustration_path")
			and plus.get("illustration_path") == "res://assets/paper/cards/" + base.get("id", "") + ".png",
			card_id + " reuses its base illustration path")
		for field in ["owner", "cost", "from_positions", "target_kind", "to_positions"]:
			_check(plus.get(field) == base.get(field), card_id + " retains base " + field)
	# Base starters and the earlier numeric upgrade keep their authored numbers.
	_check(catalog.get_definition("warden_brace").get("effects") == {"block": 7},
		"original Warden Brace remains seven Block")
	_check(catalog.get_definition("seamstress_mend").get("effects") == {"heal": 5},
		"original Seamstress Mend remains five heal")
	_check(catalog.get_definition("seamstress_stitch_up").get("effects") == {"block": 5},
		"original Seamstress Stitch Up remains five Block")
	_check(catalog.get_definition("warden_strike_plus").get("effects") == {"damage": 7},
		"existing Strike+ remains seven damage")
	_check(catalog.get_definition("tinker_tune_up").get("effects") == {"draw": 1},
		"original Tune Up remains draw one")
	_check(not catalog.has_card("tinker_tune_up_plus_forged"),
		"forged Tune Up+ remains unauthored")
	_check(starter_deck == authored and starter_deck.size() == 12,
		"exact twelve-card starter membership and order retained")


func _test_definitions_exist() -> void:
	var catalog = _get_catalog()
	for card_id: String in [
		"warden_strike", "warden_brace", "warden_shield_bash",
		"seamstress_prick", "seamstress_mend", "seamstress_stitch_up",
		"tinker_pop_shot", "tinker_scrap_bomb", "tinker_tune_up"
	]:
		_check(catalog.has_card(card_id), "catalog has " + card_id)
		var def: Dictionary = catalog.get_definition(card_id)
		_check(not def.is_empty(), "definition for " + card_id + " is not empty")
		_check(def.get("id") == card_id, card_id + " has matching stable ID")


func _test_warden_cards() -> void:
	var catalog = _get_catalog()
	
	# warden_strike
	var strike: Dictionary = catalog.get_definition("warden_strike")
	_check(strike.get("display_name") == "Strike", "warden_strike display_name")
	_check(strike.get("owner") == "warden", "warden_strike owner")
	_check(strike.get("cost") == 1, "warden_strike cost")
	_check(strike.get("from_positions") == [1, 2], "warden_strike from_positions")
	_check(strike.get("target_kind") == "enemy_single", "warden_strike target_kind")
	_check(strike.get("to_positions") == [1, 2], "warden_strike to_positions")
	_check(strike.get("effects").get("damage") == 6, "warden_strike damage")
	_check(strike.get("starting_copies") == 2, "warden_strike starting_copies")
	_check(strike.get("illustration_path") == "res://assets/paper/cards/warden_strike.png", "warden_strike illustration_path")
	
	# warden_brace
	var brace: Dictionary = catalog.get_definition("warden_brace")
	_check(brace.get("display_name") == "Brace", "warden_brace display_name")
	_check(brace.get("owner") == "warden", "warden_brace owner")
	_check(brace.get("cost") == 1, "warden_brace cost")
	_check(brace.get("from_positions") == [1, 2, 3], "warden_brace from_positions")
	_check(brace.get("target_kind") == "self", "warden_brace target_kind")
	_check(brace.get("to_positions") == [], "warden_brace to_positions empty")
	_check(brace.get("effects").get("block") == 7, "warden_brace block")
	_check(brace.get("starting_copies") == 1, "warden_brace starting_copies")
	
	# warden_shield_bash
	var shield_bash: Dictionary = catalog.get_definition("warden_shield_bash")
	_check(shield_bash.get("display_name") == "Shield Bash", "warden_shield_bash display_name")
	_check(shield_bash.get("owner") == "warden", "warden_shield_bash owner")
	_check(shield_bash.get("cost") == 2, "warden_shield_bash cost")
	_check(shield_bash.get("from_positions") == [1], "warden_shield_bash from_positions")
	_check(shield_bash.get("target_kind") == "enemy_single", "warden_shield_bash target_kind")
	_check(shield_bash.get("to_positions") == [1], "warden_shield_bash to_positions")
	_check(shield_bash.get("effects").get("damage") == 8, "warden_shield_bash damage")
	_check(shield_bash.get("effects").get("weak") == 1, "warden_shield_bash weak")
	_check(shield_bash.get("starting_copies") == 1, "warden_shield_bash starting_copies")


func _test_seamstress_cards() -> void:
	var catalog = _get_catalog()
	
	# seamstress_prick
	var prick: Dictionary = catalog.get_definition("seamstress_prick")
	_check(prick.get("display_name") == "Prick", "seamstress_prick display_name")
	_check(prick.get("owner") == "seamstress", "seamstress_prick owner")
	_check(prick.get("cost") == 1, "seamstress_prick cost")
	_check(prick.get("from_positions") == [1, 2, 3], "seamstress_prick from_positions")
	_check(prick.get("target_kind") == "enemy_single", "seamstress_prick target_kind")
	_check(prick.get("to_positions") == [1, 2, 3], "seamstress_prick to_positions")
	_check(prick.get("effects").get("damage") == 3, "seamstress_prick damage")
	_check(prick.get("effects").get("bleed") == 2, "seamstress_prick bleed")
	_check(prick.get("starting_copies") == 2, "seamstress_prick starting_copies")
	
	# seamstress_mend
	var mend: Dictionary = catalog.get_definition("seamstress_mend")
	_check(mend.get("display_name") == "Mend", "seamstress_mend display_name")
	_check(mend.get("owner") == "seamstress", "seamstress_mend owner")
	_check(mend.get("cost") == 1, "seamstress_mend cost")
	_check(mend.get("from_positions") == [2, 3], "seamstress_mend from_positions")
	_check(mend.get("target_kind") == "ally_single", "seamstress_mend target_kind")
	_check(mend.get("to_positions") == [], "seamstress_mend to_positions empty")
	_check(mend.get("effects").get("heal") == 5, "seamstress_mend heal")
	_check(mend.get("starting_copies") == 1, "seamstress_mend starting_copies")
	
	# seamstress_stitch_up
	var stitch_up: Dictionary = catalog.get_definition("seamstress_stitch_up")
	_check(stitch_up.get("display_name") == "Stitch Up", "seamstress_stitch_up display_name")
	_check(stitch_up.get("owner") == "seamstress", "seamstress_stitch_up owner")
	_check(stitch_up.get("cost") == 1, "seamstress_stitch_up cost")
	_check(stitch_up.get("from_positions") == [1, 2, 3], "seamstress_stitch_up from_positions")
	_check(stitch_up.get("target_kind") == "ally_single", "seamstress_stitch_up target_kind")
	_check(stitch_up.get("to_positions") == [], "seamstress_stitch_up to_positions empty")
	_check(stitch_up.get("effects").get("block") == 5, "seamstress_stitch_up block")
	_check(stitch_up.get("starting_copies") == 1, "seamstress_stitch_up starting_copies")


func _test_tinker_cards() -> void:
	var catalog = _get_catalog()
	
	# tinker_pop_shot
	var pop_shot: Dictionary = catalog.get_definition("tinker_pop_shot")
	_check(pop_shot.get("display_name") == "Pop Shot", "tinker_pop_shot display_name")
	_check(pop_shot.get("owner") == "tinker", "tinker_pop_shot owner")
	_check(pop_shot.get("cost") == 1, "tinker_pop_shot cost")
	_check(pop_shot.get("from_positions") == [2, 3], "tinker_pop_shot from_positions")
	_check(pop_shot.get("target_kind") == "enemy_single", "tinker_pop_shot target_kind")
	_check(pop_shot.get("to_positions") == [1, 2, 3], "tinker_pop_shot to_positions")
	_check(pop_shot.get("effects").get("damage") == 5, "tinker_pop_shot damage")
	_check(pop_shot.get("starting_copies") == 2, "tinker_pop_shot starting_copies")
	
	# tinker_scrap_bomb
	var scrap_bomb: Dictionary = catalog.get_definition("tinker_scrap_bomb")
	_check(scrap_bomb.get("display_name") == "Scrap Bomb", "tinker_scrap_bomb display_name")
	_check(scrap_bomb.get("owner") == "tinker", "tinker_scrap_bomb owner")
	_check(scrap_bomb.get("cost") == 2, "tinker_scrap_bomb cost")
	_check(scrap_bomb.get("from_positions") == [3], "tinker_scrap_bomb from_positions")
	_check(scrap_bomb.get("target_kind") == "enemy_all", "tinker_scrap_bomb target_kind")
	_check(scrap_bomb.get("to_positions") == [1, 2, 3], "tinker_scrap_bomb to_positions")
	_check(scrap_bomb.get("effects").get("damage") == 4, "tinker_scrap_bomb damage")
	_check(scrap_bomb.get("starting_copies") == 1, "tinker_scrap_bomb starting_copies")
	
	# tinker_tune_up
	var tune_up: Dictionary = catalog.get_definition("tinker_tune_up")
	_check(tune_up.get("display_name") == "Tune Up", "tinker_tune_up display_name")
	_check(tune_up.get("owner") == "tinker", "tinker_tune_up owner")
	_check(tune_up.get("cost") == 0, "tinker_tune_up cost")
	_check(tune_up.get("from_positions") == [1, 2, 3], "tinker_tune_up from_positions")
	_check(tune_up.get("target_kind") == "none", "tinker_tune_up target_kind")
	_check(tune_up.get("to_positions") == [], "tinker_tune_up to_positions empty")
	_check(tune_up.get("effects").get("draw") == 1, "tinker_tune_up draw")
	_check(tune_up.get("starting_copies") == 1, "tinker_tune_up starting_copies")


func _test_starting_deck_multiplicities() -> void:
	var catalog = _get_catalog()
	var deck: Array[String] = catalog.get_starting_deck()
	
	# Count occurrences of each card
	var counts: Dictionary = {}
	for card_id: String in deck:
		if not counts.has(card_id):
			counts[card_id] = 0
		counts[card_id] += 1
	
	# Cards with 2 copies
	_check(counts.get("warden_strike", 0) == 2, "warden_strike appears twice")
	_check(counts.get("seamstress_prick", 0) == 2, "seamstress_prick appears twice")
	_check(counts.get("tinker_pop_shot", 0) == 2, "tinker_pop_shot appears twice")
	
	# Cards with 1 copy
	_check(counts.get("warden_brace", 0) == 1, "warden_brace appears once")
	_check(counts.get("warden_shield_bash", 0) == 1, "warden_shield_bash appears once")
	_check(counts.get("seamstress_mend", 0) == 1, "seamstress_mend appears once")
	_check(counts.get("seamstress_stitch_up", 0) == 1, "seamstress_stitch_up appears once")
	_check(counts.get("tinker_scrap_bomb", 0) == 1, "tinker_scrap_bomb appears once")
	_check(counts.get("tinker_tune_up", 0) == 1, "tinker_tune_up appears once")
	
	# Total should be 12
	_check(deck.size() == 12, "starting deck has 12 cards total")


## Independent literal facts for the four authored V3 Seamstress starter pairs, copied from
## data/cards/v3_seamstress_starter_cards.gd and the V3-1 design notes, never read back from the
## catalog under test.
func _v3_seamstress_starter_cases() -> Dictionary:
	return {
		"seamstress_v3_thread_prick": {
			"name": "Thread Prick", "cost": 1, "plus_cost": 1,
			"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"damage": 3, "bleed": 2},
			"plus_effects": {"damage": 4, "bleed": 3}},
		"seamstress_v3_tether_loop": {
			"name": "Tether Loop", "cost": 2, "plus_cost": 1,
			"from": [2, 3], "target": "enemy_pair", "to": [1, 2, 3],
			"effects": {"tether_share_percent": 50},
			"plus_effects": {"tether_share_percent": 50}},
		"seamstress_v3_mending_knot": {
			"name": "Mending Knot", "cost": 1, "plus_cost": 1,
			"from": [2, 3], "target": "ally_single", "to": [],
			"effects": {"heal": 4, "cleanse_debuff": 1},
			"plus_effects": {"heal": 6, "cleanse_debuff": 1}},
		"seamstress_v3_shielding_hem": {
			"name": "Shielding Hem", "cost": 1, "plus_cost": 1,
			"from": [1, 2, 3], "target": "ally_single", "to": [],
			"effects": {"block": 4, "heal": 2},
			"plus_effects": {"block": 6, "heal": 3}},
	}


## V3-1: the shared StarterCards lookup serves the eight authored V3 Seamstress records without
## adopting them into the legacy deck, enumeration or membership.
func _test_v3_seamstress_starter_lookup() -> void:
	var shared := StarterCards.new()
	var source := V3SeamstressStarterCards.new()
	var cases: Dictionary = _v3_seamstress_starter_cases()
	_check(cases.size() == 4, "V3 Seamstress fixture enumerates four authored starter pairs")
	var v3_deck: Array[String] = source.get_starting_deck()
	_check(not v3_deck.is_empty(), "V3 Seamstress dedicated starting deck is populated (precondition)")
	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(source.get_upgrade_id(base_id) == plus_id, base_id + " maps to its authored upgrade")
		for upgraded: bool in [false, true]:
			var card_id: String = plus_id if upgraded else base_id
			var shared_record: Dictionary = shared.get_definition(card_id)
			var source_record: Dictionary = source.get_definition(card_id)
			_check(not source_record.is_empty(), card_id + " is an authored V3 record (precondition)")
			_check(not shared_record.is_empty(), card_id + " resolves through the shared starter lookup")
			_check(shared_record == source_record, card_id + " shared lookup equals the full authored V3 record")
			_check(shared_record.get("id") == card_id, card_id + " keeps its authored ID")
			_check(shared_record.get("display_name")
				== str(spec["name"]) + ("+" if upgraded else ""), card_id + " keeps its printed name")
			_check(shared_record.get("owner") == "seamstress", card_id + " stays Seamstress-owned")
			_check(shared_record.get("cost") == (spec["plus_cost"] if upgraded else spec["cost"]),
				card_id + " keeps its printed energy cost")
			_check(shared_record.get("from_positions") == spec["from"],
				card_id + " keeps its legal FROM positions")
			_check(shared_record.get("target_kind") == spec["target"],
				card_id + " keeps its target shape")
			_check(shared_record.get("to_positions") == spec["to"],
				card_id + " keeps its legal TO positions")
			_check(shared_record.get("effects") == (spec["plus_effects"] if upgraded else spec["effects"]),
				card_id + " keeps its printed effects")
			_check(shared_record.get("illustration_path")
				== "res://assets/paper/cards/" + base_id + ".png",
				card_id + " keeps its authored illustration path")
			_check(shared_record.get("starting_copies") == (0 if upgraded else 1),
				card_id + " keeps its authored V3 starting copy count")
			_check(shared_record.get("reward_eligible") == false,
				card_id + " stays out of rewards")
			if upgraded:
				_check(shared_record.get("upgrade_of") == base_id, card_id + " points back at its base")
				_check(not shared_record.has("upgrade_id"), card_id + " is a terminal upgrade")
			else:
				_check(shared_record.get("upgrade_id") == plus_id, card_id + " points at its own upgrade")
				_check(not shared_record.has("upgrade_of"), card_id + " is not itself an upgrade")
		var shared_base: Dictionary = shared.get_definition(base_id)
		var shared_plus: Dictionary = shared.get_definition(plus_id)
		_check(shared_base.get("illustration_path") == shared_plus.get("illustration_path"),
			base_id + " base and upgrade share one illustration")
		_check(v3_deck.count(base_id) == 1, base_id + " is exactly one authored V3 starting copy")
		_check(not v3_deck.has(plus_id), plus_id + " adds no V3 starting copy")
	for deck_id: String in v3_deck:
		_check(cases.has(deck_id), deck_id + " in the V3 dedicated deck is one of its four authored bases")
	# The shared catalog keeps its legacy definitions, membership, enumeration and deck.
	var legacy_ids: Array[String] = shared.get_all_card_ids()
	var legacy_deck: Array[String] = shared.get_starting_deck()
	_check(not legacy_ids.is_empty(), "legacy enumeration is populated (precondition)")
	_check(not legacy_deck.is_empty(), "legacy starting deck is populated (precondition)")
	for base_id: String in cases:
		for card_id: String in [base_id, base_id + "_plus"]:
			_check(not shared.has_card(card_id), card_id + " is not legacy shared-catalog membership")
			_check(not legacy_ids.has(card_id), card_id + " stays out of legacy enumeration")
			_check(not legacy_deck.has(card_id), card_id + " stays out of the legacy starting deck")
	var authored_legacy: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/cards/starter_deck.json"))
	_check(authored_legacy is Array and legacy_deck == authored_legacy,
		"legacy starting deck still matches its authored membership and order")
	# A legacy ID is answered by the legacy data, not by any V3 fallback.
	_check(shared.get_definition("seamstress_prick").get("display_name") == "Prick",
		"legacy Seamstress Prick still resolves directly")
	_check(shared.get_definition("seamstress_prick").get("effects") == {"damage": 3, "bleed": 2},
		"legacy Seamstress Prick keeps its authored effects")
	# The existing V3 Tinker fallback still works after the Seamstress bridge.
	var tinker_v3: Dictionary = shared.get_definition("tinker_v3_cog_shot")
	_check(not tinker_v3.is_empty() and tinker_v3.get("owner") == "tinker",
		"existing V3 Tinker lookup bridge is preserved")


## AC1: a record returned through the shared lookup is detached from both catalogs.
func _test_v3_seamstress_records_are_detached() -> void:
	var shared := StarterCards.new()
	var source := V3SeamstressStarterCards.new()
	var source_before: Dictionary = source.get_definition("seamstress_v3_thread_prick")
	_check(not source_before.is_empty(), "V3 source mutation fixture is loaded (precondition)")
	var record: Dictionary = shared.get_definition("seamstress_v3_thread_prick")
	_check(not record.is_empty(), "shared mutation fixture is loaded (precondition)")
	if record.is_empty() or source_before.is_empty():
		return
	record["effects"]["damage"] = 999
	record["effects"]["bleed"] = 999
	record["effects"]["forged_effect"] = 1
	record["from_positions"].clear()
	record["from_positions"].append(9)
	record["to_positions"][0] = 9
	record["to_positions"].append(9)
	record["display_name"] = "Mutated"
	record["cost"] = 99
	record["starting_copies"] = 99
	record["upgrade_id"] = "seamstress_v3_forged_upgrade"
	var again: Dictionary = shared.get_definition("seamstress_v3_thread_prick")
	_check(again.get("effects") == {"damage": 3, "bleed": 2},
		"mutating a shared record's nested effects leaves later shared lookups pristine")
	_check(again.get("from_positions") == [1, 2, 3],
		"mutating a shared record's FROM positions leaves later shared lookups pristine")
	_check(again.get("to_positions") == [1, 2, 3],
		"mutating a shared record's TO positions leaves later shared lookups pristine")
	_check(again.get("display_name") == "Thread Prick" and again.get("cost") == 1
		and again.get("starting_copies") == 1,
		"mutating a shared record's metadata leaves later shared lookups pristine")
	_check(again.get("upgrade_id") == "seamstress_v3_thread_prick_plus",
		"mutating a shared record's upgrade link leaves the reciprocal link pristine")
	_check(source.get_definition("seamstress_v3_thread_prick") == source_before,
		"mutating a shared record never touches the authored V3 source catalog")
	# A record mutated at the V3 source itself still never leaks into the shared lookup.
	var source_record: Dictionary = source.get_definition("seamstress_v3_shielding_hem_plus")
	_check(not source_record.is_empty(), "V3 source upgrade fixture is loaded (precondition)")
	source_record["effects"]["block"] = 900
	source_record["effects"]["heal"] = 900
	source_record["from_positions"].append(900)
	var shared_plus: Dictionary = shared.get_definition("seamstress_v3_shielding_hem_plus")
	_check(shared_plus.get("effects") == {"block": 6, "heal": 3},
		"a record mutated at the V3 source cannot leak into the shared lookup")
	_check(shared_plus.get("from_positions") == [1, 2, 3],
		"a position array mutated at the V3 source cannot leak into the shared lookup")
	_check(source.get_definition("seamstress_v3_shielding_hem_plus").get("effects")
		== {"block": 6, "heal": 3}, "the V3 source catalog itself stays pristine")


## AC1: unknown, invented and foreign IDs still fail closed through the shared lookup.
func _test_v3_seamstress_unknown_ids_fail_closed() -> void:
	var shared := StarterCards.new()
	var source := V3SeamstressStarterCards.new()
	var invented: Array[String] = [
		"seamstress_v3_", "seamstress_v3_forged_starter", "seamstress_v3_forged_card",
		"seamstress_v3_thread_prick_plus_plus", "seamstress_v3_tether_loop_plus_plus",
		"seamstress_v3_mending_knot_plus_plus", "seamstress_v3_shielding_hem_plus_plus",
		"SEAMSTRESS_V3_THREAD_PRICK", " seamstress_v3_thread_prick",
		"seamstress_v3_thread_prick ", "seamstress_v3_thread_prick+",
		# Reward-pool IDs belong to their own catalog and are never starters.
		"seamstress_v3_needle_rain", "seamstress_v3_needle_rain_plus",
		"seamstress_v3_darn_the_tear", "seamstress_v3_tether_stitch",
		"seamstress_v3_blanket_of_barbs", "seamstress_v3_patchwork_poultice",
		# Legacy and other-hero IDs are never answered by the V3 Seamstress bridge.
		"seamstress_running_stitch", "warden_v3_pot_helm_bonk", "unknown_card", "",
	]
	_check(not invented.is_empty(), "invented-ID fixture is populated (precondition)")
	for card_id: String in invented:
		_check(not source.has_card(card_id),
			card_id + " is not an authored V3 Seamstress starter (precondition)")
		_check(shared.get_definition(card_id).is_empty(),
			card_id + " still refuses a definition through the shared lookup")
		_check(not shared.has_card(card_id), card_id + " still fails shared membership")
	_check(shared.get_definition("seamstress_v3_thread_prick_plus").get("id")
		== "seamstress_v3_thread_prick_plus", "a real plus ID still resolves (precondition)")
	_check(shared.get_definition("seamstress_prick").get("display_name") == "Prick",
		"a legacy ID is still answered by legacy data, not the V3 bridge")


func _test_unknown_id_returns_empty() -> void:
	var catalog = _get_catalog()
	var def: Dictionary = catalog.get_definition("unknown_card")
	_check(def.is_empty(), "unknown ID returns empty dictionary")
	_check(not catalog.has_card("unknown_card"), "has_card returns false for unknown ID")
	_check(not catalog.has_card(""), "has_card returns false for empty string")


func _test_returned_data_is_deep_copy() -> void:
	var catalog = _get_catalog()
	
	# Test definition copy
	var def1: Dictionary = catalog.get_definition("warden_strike")
	def1["display_name"] = "Mutated"
	var def2: Dictionary = catalog.get_definition("warden_strike")
	_check(def2.get("display_name") == "Strike", "mutating returned definition does not affect catalog")
	
	# Test nested effects copy
	var def3: Dictionary = catalog.get_definition("warden_shield_bash")
	def3["effects"]["damage"] = 999
	var def4: Dictionary = catalog.get_definition("warden_shield_bash")
	_check(def4.get("effects").get("damage") == 8, "mutating nested effects does not affect catalog")


func _test_starting_deck_is_fresh_copy() -> void:
	var catalog = _get_catalog()
	var deck1: Array[String] = catalog.get_starting_deck()
	var deck2: Array[String] = catalog.get_starting_deck()
	
	# They should be equal
	_check(deck1 == deck2, "two calls return equal decks")
	
	# Mutating one should not affect the other (proves they are different instances)
	deck1.clear()
	var deck3: Array[String] = catalog.get_starting_deck()
	_check(deck3.size() == 12, "mutating returned deck does not affect catalog")
	_check(deck2.size() == 12, "original deck unchanged after mutation of first copy")
