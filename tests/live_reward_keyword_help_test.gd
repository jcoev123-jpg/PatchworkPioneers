extends SceneTree
## Authored keyword text and real prepared Fight/Elite reward panel interactions.
const SCENE := "res://scenes/run_card_reward_choice_panel.tscn"
const HEROES := "res://data/heroes/starter_party.json"
const ENEMIES := "res://data/enemies/starter_enemies.json"

var failures: Array[String] = []
var checks := 0
var panel: LiveRunCardRewardChoicePanel
var requests: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


## A detached card definition wrapping caller-authored effects, so fixtures are
## shaped exactly like a catalog definition without touching the real catalog.
func _shape(effects: Dictionary) -> Dictionary:
	return {"effects": effects.duplicate(true)}


func _frames() -> void:
	for i in range(4):
		await process_frame


func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _mouse(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _defs(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "authored roster opens " + path)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(parsed is Array and not parsed.is_empty(), "authored roster parsed " + path)
	if not parsed is Array:
		return []
	var result: Array = []
	for raw in parsed:
		var item: Dictionary = (raw as Dictionary).duplicate(true)
		item["max_hp"] = int(item.get("max_hp", 0))
		result.append(item)
	return result


func _prepared(kind: String, seed_value: int, use_pool: bool = true,
		candidates_override: Array = []) -> Dictionary:
	var party := CombatParty.new(_defs(HEROES))
	var enemies := CombatEnemies.new(_defs(ENEMIES))
	_check(party.is_valid() and enemies.is_valid(), "genuine combat roster is valid")
	var result := CombatBattleResult.new(party, enemies)
	_check(result.get_outcome() == CombatBattleResult.ACTIVE, "combat starts active")
	for slot in range(1, enemies.get_enemies().size() + 1):
		_check(enemies.apply_damage(slot, enemies.get_enemy(slot).get("hp", 0)),
			"kill real enemy to witness victory")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "witnessed victory")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var deck: Array[String] = StarterCards.new().get_starting_deck()
	var candidates: Array = candidates_override
	if candidates.is_empty():
		candidates = RunPoolCardRewardOffers.get_authored_base_candidates() \
			if use_pool else StarterCards.new().get_all_card_ids()
	var service := RunFightVictoryRewards.new(result, rng,
		["warden", "seamstress", "tinker"], candidates, deck, 97,
		kind == "Elite", ["button_charm", "thread_token"], ["button_charm"])
	var receipt: Dictionary = service.prepare()
	_check(receipt.get("ok", false) and receipt.get("offers", []).size() == 3,
		"genuine prepared %s receipt with three offers" % kind)
	return {"rng": rng, "deck": deck, "party": party, "enemies": enemies,
		"result": result, "service": service, "receipt": receipt, "wallet": 97,
		"scraps": 0, "trinkets": ["button_charm"]}


func _snapshot(fixture: Dictionary) -> Dictionary:
	return {"seed": fixture["rng"].seed, "rng": fixture["rng"].state,
		"deck": fixture["deck"].duplicate(true), "gold": fixture["wallet"],
		"scraps": fixture["scraps"], "trinkets": fixture["trinkets"].duplicate(true),
		"party": fixture["party"].get_heroes(), "enemies": fixture["enemies"].get_enemies(),
		"outcome": fixture["result"].get_outcome(),
		"claimed": fixture["service"]._choice.is_claimed(),
		"receipt": fixture["receipt"].duplicate(true),
		"prepared": fixture["service"].prepare(),
		"panel_receipt": panel._receipt.duplicate(true)}


func _catalog_test() -> void:
	var warden := WardenPoolCards.new()
	var v3_warden := V3WardenPoolCards.new()
	var seamstress := SeamstressPoolCards.new()
	var tinker := TinkerPoolCards.new()
	var starter := StarterCards.new()
	var lantern_starters := LanternMonkStarterCards.new()
	var lantern_pool := LanternMonkPoolCards.new()
	var scarecrow_starter := ScarecrowStarterCards.new()
	var scarecrow_pool := ScarecrowPoolCards.new()
	var v3_seamstress_starter := V3SeamstressStarterCards.new()
	var v3_seamstress_pool := V3SeamstressPoolCards.new()
	var cases := [
		[warden, "warden_pinning_jab", ["Pinned"], ["DIFFERENT hero", "+5", "before Weak/Exposed", "expires"]],
		[warden, "warden_draw_fire", ["Guarding"], ["position 1", "other heroes", "next turn"]],
		[warden, "warden_counter_stitch", ["Thorns 3"], ["takes 3 damage", "confirmed positive-damage hit", "until the next turn"]],
		[seamstress, "seamstress_running_stitch", ["Bleed 3"], ["3 HP", "decreases by 1", "1 Unravel"]],
		[seamstress, "seamstress_snag", ["Weak 1", "Unravel 3"], ["25%", "8, elite 12, boss 16", "NEXT action", "rises by 4"]],
		[seamstress, "seamstress_red_thread", ["Bleed 6", "Exposed 1"], ["6 HP", "50%", "rounds down"]],
		[tinker, "tinker_spring_trap", ["Pinned"], ["DIFFERENT hero", "+5", "before Weak/Exposed"]],
		[tinker, "tinker_rivet_shot", ["Exposed 1"], ["50%", "minimum 0"]],
		[tinker, "tinker_spool_launcher", ["Unravel 3"], ["gauge", "normal 8"]],
		[tinker, "tinker_snip_the_seam", ["Conditional damage"],
			["Deal 5 damage", "15 instead", "Unravelled", " or ", "current threshold",
				"8 normal, 12 elite, 16 boss", "rises by 4"]],
		[tinker, "tinker_snip_the_seam_plus", ["Conditional damage"],
			["Deal 7 damage", "20 instead", "Unravelled", "current threshold"]],
		[tinker, "tinker_ricochet", ["Random hits"],
			["3 separate hits of 4 damage each", "random living enemy", "seeded RNG",
				"more than once"]],
		[tinker, "tinker_ricochet_plus", ["Random hits"],
			["3 separate hits of 6 damage each", "random living enemy", "single seeded RNG"]],
		[starter, "warden_strike", [], []],
	]
	for case in cases:
		var catalog: Variant = case[0]
		var id: String = case[1]
		var ids: Array[String] = catalog.get_all_card_ids() if catalog is StarterCards \
			else (catalog.get_pool_card_ids() if catalog is TinkerPoolCards else catalog.get_base_ids())
		var present: bool = catalog.has_card(id) if catalog is TinkerPoolCards else ids.has(id)
		_check(present, "required ID present in independent stable catalog " + id)
		var def: Dictionary = catalog.get_definition(id)
		_check(not def.is_empty() and def.get("id") == id, "actual definition " + id)
		if def.is_empty():
			continue
		var original: Dictionary = def.duplicate(true)
		var entries := CardKeywordGlossary.describe(def)
		var actual: Array[String] = []
		var words := ""
		for entry: Dictionary in entries:
			actual.append(String(entry["keyword"]))
			words += String(entry["explanation"]) + " "
		_check(actual == case[2], "fixed keyword order and numeric values for " + id)
		for phrase: String in case[3]:
			_check(words.contains(phrase), "mechanics '%s' for %s" % [phrase, id])
		_check(def == original and catalog.get_definition(id) == original,
			"glossary never mutates catalog or caller definition " + id)
		if not entries.is_empty():
			entries[0]["keyword"] = "Tampered"
			entries[0]["explanation"] = "Tampered"
			_check(CardKeywordGlossary.describe(def)[0]["keyword"] == case[2][0]
				and def == original, "glossary results are detached " + id)
	var reordered := {"id": "warden_strike", "effects": {
		"thorns": 3, "unravel": 3, "junk": 4, "bleed": 2,
		"guarding": true, "weak": 1, "pinned": true, "exposed": 1}}
	var expected := ["Bleed 2", "Weak 1", "Exposed 1", "Pinned",
		"Unravel 3", "Guarding", "Thorns 3"]
	var original := reordered.duplicate(true)
	var actual: Array[String] = []
	for entry: Dictionary in CardKeywordGlossary.describe(reordered):
		actual.append(entry["keyword"])
	_check(actual == expected, "seven combined keywords stable and once each")
	_check(reordered == original, "compound input untouched")
	_check(CardKeywordGlossary.describe({"effects": {"damage": 6, "unknown": 1}}).is_empty(),
		"unrecognized and ordinary effects never invent help")
	_check(CardKeywordGlossary.describe({"effects": {}}).is_empty()
		and CardKeywordGlossary.describe({}).is_empty()
		and CardKeywordGlossary.describe(null).is_empty(),
		"empty and invalid effects produce no help")
	# The documented D2-1 numbers straight from the real Tinker catalog, and the
	# Help rows must repeat exactly those authored amounts, never guesses.
	var snip_base: Dictionary = tinker.get_definition("tinker_snip_the_seam").get("effects", {})
	var snip_plus: Dictionary = tinker.get_definition("tinker_snip_the_seam_plus").get("effects", {})
	var ricochet_base: Dictionary = tinker.get_definition("tinker_ricochet").get("effects", {})
	var ricochet_plus: Dictionary = tinker.get_definition("tinker_ricochet_plus").get("effects", {})
	_check(int(snip_base.get("damage", 0)) == 5
		and int((snip_base.get("conditional_damage", {}) as Dictionary).get("damage", 0)) == 15
		and int(snip_plus.get("damage", 0)) == 7
		and int((snip_plus.get("conditional_damage", {}) as Dictionary).get("damage", 0)) == 20,
		"catalog Snip numbers are 5/15 base and 7/20 plus")
	_check(int(ricochet_base.get("hit_count", 0)) == 3 and int(ricochet_base.get("damage", 0)) == 4
		and int(ricochet_plus.get("hit_count", 0)) == 3 and int(ricochet_plus.get("damage", 0)) == 6,
		"catalog Ricochet numbers are 3x4 base and 3x6 plus")
	var snip_rows := CardKeywordGlossary.describe(tinker.get_definition("tinker_snip_the_seam"))
	var snip_plus_rows := CardKeywordGlossary.describe(tinker.get_definition("tinker_snip_the_seam_plus"))
	_check(not snip_rows.is_empty() and not snip_plus_rows.is_empty()
		and String(snip_rows[0]["explanation"]).contains("Deal %d damage" % int(snip_base["damage"]))
		and String(snip_rows[0]["explanation"]).contains("%d instead"
			% int(snip_base["conditional_damage"]["damage"]))
		and String(snip_plus_rows[0]["explanation"]).contains("Deal %d damage" % int(snip_plus["damage"]))
		and String(snip_plus_rows[0]["explanation"]).contains("%d instead"
			% int(snip_plus["conditional_damage"]["damage"])),
		"Snip Help repeats the authored base and empowered damage for base and plus")
	var ricochet_rows := CardKeywordGlossary.describe(tinker.get_definition("tinker_ricochet"))
	var ricochet_plus_rows := CardKeywordGlossary.describe(tinker.get_definition("tinker_ricochet_plus"))
	_check(not ricochet_rows.is_empty() and not ricochet_plus_rows.is_empty()
		and String(ricochet_rows[0]["explanation"]).contains("%d separate hits of %d damage"
			% [int(ricochet_base["hit_count"]), int(ricochet_base["damage"])])
		and String(ricochet_plus_rows[0]["explanation"]).contains("%d separate hits of %d damage"
			% [int(ricochet_plus["hit_count"]), int(ricochet_plus["damage"])]),
		"Ricochet Help repeats the authored hits and per-hit damage for base and plus")
	# Ordinary authored cards that only share one descriptor key never gain a
	# fabricated special rule (Scatter Bolts authors living_targets_only alone).
	for ordinary_id: String in ["tinker_scatter_bolts", "tinker_long_barrel"]:
		_check(CardKeywordGlossary.describe(tinker.get_definition(ordinary_id)).is_empty(),
			"ordinary authored %s never gains a special-rule row" % ordinary_id)
	_energy_catalog_test(tinker, seamstress)
	_bleed_doubling_catalog_test(seamstress)
	_pin_and_pound_catalog_test(warden)
	_blind_catalog_test(lantern_starters, lantern_pool)
	_thorns_test(warden, v3_warden)
	_scarecrow_crow_catalog_test(scarecrow_starter, scarecrow_pool)
	_tether_catalog_test(v3_seamstress_starter, v3_seamstress_pool)
	# Exact authored shapes are explained; every unknown, malformed or partial
	# variant stays silent and leaves the caller's definition untouched. These
	# effect fixtures mirror the catalog descriptors but are built independently.
	var snip_effects := {"damage": 5, "conditional_damage": {
		"damage": 15, "operator": "or",
		"conditions": [{"status": "unravelled"},
			{"gauge": "unravel", "comparison": "at_least_half",
				"threshold": "current_target_threshold"}]}}
	var ricochet_effects := {"damage": 4, "hit_count": 3, "random_target_each_hit": true,
		"rng_source": "run", "living_targets_only": true}
	_check(CardKeywordGlossary.describe(_shape(snip_effects)).size() == 1
		and CardKeywordGlossary.describe(_shape(ricochet_effects)).size() == 1,
		"exact authored special descriptor shapes are explained")
	var malformed: Array = []
	var bad_snip_condition := _shape(snip_effects)
	bad_snip_condition["effects"]["conditional_damage"]["conditions"].append({"status": "invented"})
	malformed.append(["unknown extra predicate", bad_snip_condition])
	var missing_conditions := _shape(snip_effects)
	missing_conditions["effects"]["conditional_damage"].erase("conditions")
	malformed.append(["missing conditions", missing_conditions])
	var empty_conditions := _shape(snip_effects)
	empty_conditions["effects"]["conditional_damage"]["conditions"] = []
	malformed.append(["empty conditions", empty_conditions])
	var unknown_operator := _shape(snip_effects)
	unknown_operator["effects"]["conditional_damage"]["operator"] = "xor"
	malformed.append(["unknown operator", unknown_operator])
	var no_gain := _shape(snip_effects)
	no_gain["effects"]["conditional_damage"]["damage"] = 5
	malformed.append(["no damage gain", no_gain])
	var text_condition := _shape(snip_effects)
	text_condition["effects"]["conditional_damage"]["conditions"] = "unravelled"
	malformed.append(["unreadable condition list", text_condition])
	var wrong_threshold := _shape(snip_effects)
	wrong_threshold["effects"]["conditional_damage"]["conditions"][1]["threshold"] = "starting_threshold"
	malformed.append(["unknown threshold source", wrong_threshold])
	var wrong_status := _shape(snip_effects)
	wrong_status["effects"]["conditional_damage"]["conditions"][0]["status"] = "bleeding"
	malformed.append(["unknown status", wrong_status])
	var extra_predicate_key := _shape(snip_effects)
	extra_predicate_key["effects"]["conditional_damage"]["conditions"][0]["invented"] = true
	malformed.append(["partial status predicate", extra_predicate_key])
	var unseeded_rng := _shape(ricochet_effects)
	unseeded_rng["effects"]["rng_source"] = "wall_clock"
	malformed.append(["unseeded rng source", unseeded_rng])
	var single_hit := _shape(ricochet_effects)
	single_hit["effects"]["hit_count"] = 1
	malformed.append(["single hit", single_hit])
	var missing_living := _shape(ricochet_effects)
	missing_living["effects"].erase("living_targets_only")
	malformed.append(["living targets not stated", missing_living])
	var non_living_flag := _shape(ricochet_effects)
	non_living_flag["effects"]["living_targets_only"] = false
	malformed.append(["non-living random flag", non_living_flag])
	var missing_damage := _shape(ricochet_effects)
	missing_damage["effects"].erase("damage")
	malformed.append(["no per-hit damage", missing_damage])
	for case in malformed:
		var broken: Dictionary = case[1]
		var broken_before: Dictionary = broken.duplicate(true)
		_check(CardKeywordGlossary.describe(broken).is_empty(),
			"%s never fabricates special-rule Help" % String(case[0]))
		_check(broken == broken_before, "%s leaves the definition untouched" % String(case[0]))
	_check(snip_effects == {"damage": 5, "conditional_damage": {
		"damage": 15, "operator": "or",
		"conditions": [{"status": "unravelled"},
			{"gauge": "unravel", "comparison": "at_least_half",
				"threshold": "current_target_threshold"}]}}
		and ricochet_effects == {"damage": 4, "hit_count": 3, "random_target_each_hit": true,
			"rng_source": "run", "living_targets_only": true},
		"negative special cases never mutate the positive fixtures")
	# Special rows always follow the seven keyword rows, in a stable order.
	var combined := {"effects": {
		"bleed": 1, "damage": 4, "hit_count": 3, "random_target_each_hit": true,
		"rng_source": "run", "living_targets_only": true,
		"conditional_damage": {"damage": 9, "operator": "or",
			"conditions": [{"status": "unravelled"}]}}}
	var combined_original: Dictionary = combined.duplicate(true)
	var combined_keywords: Array[String] = []
	for entry: Dictionary in CardKeywordGlossary.describe(combined):
		combined_keywords.append(String(entry["keyword"]))
	_check(combined_keywords == ["Bleed 1", "Conditional damage", "Random hits"],
		"special rows follow the fixed keyword rows in a stable order")
	_check(combined == combined_original, "combined special input untouched")


## A detached card definition with the authored structural keys the energy
## tradeoff contract re-checks, so malformed fixtures cannot borrow a positive
## verdict from the real catalog.
func _energy_definition(card_id: Variant, owner: Variant, cost: Variant,
		target_kind: Variant, to_positions: Array, effects: Dictionary,
		from_positions: Variant = [1, 2, 3]) -> Dictionary:
	return {"id": card_id, "owner": owner, "cost": cost, "target_kind": target_kind,
		"from_positions": from_positions.duplicate(true),
		"to_positions": to_positions.duplicate(true), "effects": effects.duplicate(true)}


## Overclock and Tailor's Trance, base and '+' records, straight from their real
## catalogs: one energy row each with the authored cost, gain/net result and the
## exact 3 self-damage risk or 2/3 draws. Ordinary, partial, mis-owned,
## mispriced, mistargeted, badly typed or extended fixtures stay silent.
func _energy_catalog_test(tinker: TinkerPoolCards, seamstress: SeamstressPoolCards) -> void:
	var cases := [
		{"catalog": tinker, "id": "tinker_overclock", "owner": "tinker", "cost": 0, "draws": 0},
		{"catalog": tinker, "id": "tinker_overclock_plus", "owner": "tinker", "cost": 0, "draws": 0},
		{"catalog": seamstress, "id": "seamstress_tailors_trance", "owner": "seamstress",
			"cost": 1, "draws": 2},
		{"catalog": seamstress, "id": "seamstress_tailors_trance_plus", "owner": "seamstress",
			"cost": 1, "draws": 3},
	]
	for case: Dictionary in cases:
		var catalog: Variant = case["catalog"]
		var card_id: String = String(case["id"])
		_check(catalog.has_card(card_id), "energy card is present in its real catalog " + card_id)
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			"actual energy catalog definition " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		var original: Dictionary = definition.duplicate(true)
		_check(String(definition.get("owner", "")) == String(case["owner"])
			and int(definition.get("cost", -1)) == int(case["cost"])
			and String(definition.get("target_kind", "")) == "self"
			and (definition.get("to_positions", [1]) as Array).is_empty()
			and not (definition.get("from_positions", []) as Array).is_empty(),
			"authored owner, cost and self-only target for " + card_id)
		var rows := CardKeywordGlossary.describe(definition)
		_check(rows.size() == 1 and String(rows[0]["keyword"]) == "Energy tradeoff",
			"exactly one energy tradeoff row for " + card_id)
		if rows.size() != 1:
			continue
		var text := String(rows[0]["explanation"])
		if card_id.begins_with("tinker_overclock"):
			_check(int(effects.get("gain_energy", 0)) == 1
				and int(effects.get("self_hp_loss", 0)) == 3,
				"catalog Overclock numbers are +1 energy and 3 self-damage " + card_id)
			_check(text.contains("Costs 0 energy") and text.contains("gains 1 energy")
				and text.contains("net gain of 1 energy")
				and text.contains("takes 3 damage herself")
				and text.contains("Block absorbs") and text.contains("leave her torn"),
				"Overclock Help states cost, gain, net result and the honest HP risk " + card_id)
			_check(not text.contains("Block 3") and not text.contains("3 Block")
				and not text.contains("damage 3"),
				"Overclock Help never redefines HP or Block " + card_id)
		else:
			var expected_draw: int = int(case["draws"])
			_check(int(effects.get("energy", 0)) == 1 and int(effects.get("draw", 0)) == expected_draw,
				"catalog Trance numbers are +1 energy and %d draws %s" % [expected_draw, card_id])
			_check(text.contains("Costs 1 energy")
				and text.contains("must be available before the play")
				and text.contains("regains that same 1 energy")
				and text.contains("net 0 energy")
				and text.contains("Draws %d cards" % expected_draw),
				"Trance Help states the up-front cost, the net 0 refund and %d draws %s"
					% [expected_draw, card_id])
			_check(not text.contains("free") and not text.contains("without energy"),
				"Trance Help never implies an empty-energy hand can cast it " + card_id)
		_check(definition == original and catalog.get_definition(card_id) == original,
			"energy Help never mutates the catalog definition " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"energy Help stays deterministic for " + card_id)
		rows[0]["keyword"] = "Tampered"
		rows[0]["explanation"] = "Tampered"
		var fresh := CardKeywordGlossary.describe(definition)
		_check(fresh.size() == 1 and String(fresh[0]["keyword"]) == "Energy tradeoff"
			and String(fresh[0]["explanation"]).contains("energy")
			and definition == original,
			"energy Help results are detached from the caller's definition " + card_id)
	var overclock := _energy_definition("tinker_overclock", "tinker", 0, "self", [],
		{"gain_energy": 1, "self_hp_loss": 3})
	var trance := _energy_definition("seamstress_tailors_trance", "seamstress", 1, "self", [],
		{"energy": 1, "draw": 2})
	_check(CardKeywordGlossary.describe(overclock).size() == 1
		and CardKeywordGlossary.describe(trance).size() == 1,
		"exact energy descriptor shapes are explained")
	var fixtures: Array = []
	var fixture := overclock.duplicate(true)
	fixture["owner"] = "seamstress"
	fixtures.append(["wrong Overclock owner", fixture])
	fixture = overclock.duplicate(true)
	fixture["cost"] = 1
	fixtures.append(["wrong Overclock cost", fixture])
	fixture = overclock.duplicate(true)
	fixture["target_kind"] = "ally_single"
	fixtures.append(["wrong Overclock target", fixture])
	fixture = overclock.duplicate(true)
	fixture["to_positions"] = [1]
	fixtures.append(["Overclock with a target slot", fixture])
	fixture = overclock.duplicate(true)
	fixture["effects"]["draw"] = 1
	fixtures.append(["Overclock with an extra effect", fixture])
	fixture = overclock.duplicate(true)
	fixture["effects"] = {"gain_energy": 1}
	fixtures.append(["partial Overclock effects", fixture])
	fixture = overclock.duplicate(true)
	fixture["effects"]["self_hp_loss"] = 2
	fixtures.append(["wrong Overclock self-damage", fixture])
	fixture = overclock.duplicate(true)
	fixture["effects"]["gain_energy"] = 2
	fixtures.append(["wrong Overclock gain", fixture])
	fixture = overclock.duplicate(true)
	fixture["effects"]["gain_energy"] = "1"
	fixtures.append(["text Overclock gain", fixture])
	fixture = overclock.duplicate(true)
	fixture["cost"] = "0"
	fixtures.append(["text Overclock cost", fixture])
	fixture = overclock.duplicate(true)
	fixture.erase("owner")
	fixtures.append(["Overclock without an owner", fixture])
	fixture = overclock.duplicate(true)
	fixture["id"] = "tinker_overclock_plus_plus"
	fixtures.append(["similarly named Overclock", fixture])
	fixture = overclock.duplicate(true)
	fixture["id"] = "tinker_ricochet"
	fixtures.append(["energy effects on an unrelated ID", fixture])
	fixture = overclock.duplicate(true)
	fixture["from_positions"] = [4]
	fixtures.append(["Overclock from an illegal slot", fixture])
	fixture = overclock.duplicate(true)
	fixture["from_positions"] = "1,2,3"
	fixtures.append(["text Overclock source slots", fixture])
	fixture = overclock.duplicate(true)
	fixture["id"] = 7
	fixtures.append(["non-string Overclock ID", fixture])
	fixture = trance.duplicate(true)
	fixture["owner"] = "tinker"
	fixtures.append(["wrong Trance owner", fixture])
	fixture = trance.duplicate(true)
	fixture["cost"] = 0
	fixtures.append(["wrong Trance cost", fixture])
	fixture = trance.duplicate(true)
	fixture["effects"]["draw"] = 3
	fixtures.append(["base Trance with upgraded draws", fixture])
	fixture = trance.duplicate(true)
	fixture["id"] = "seamstress_tailors_trance_plus"
	fixtures.append(["upgraded Trance with base draws", fixture])
	fixture = trance.duplicate(true)
	fixture["effects"]["energy"] = 2
	fixtures.append(["wrong Trance gain", fixture])
	fixture = trance.duplicate(true)
	fixture["target_kind"] = "enemy_single"
	fixtures.append(["wrong Trance target", fixture])
	fixture = trance.duplicate(true)
	fixture["effects"]["heal"] = 2
	fixtures.append(["Trance with an extra effect", fixture])
	fixture = trance.duplicate(true)
	fixture["effects"] = {"energy": 1}
	fixtures.append(["partial Trance effects", fixture])
	fixture = trance.duplicate(true)
	fixture["effects"]["draw"] = "2"
	fixtures.append(["text Trance draws", fixture])
	for case in fixtures:
		var broken: Dictionary = case[1]
		var broken_before: Dictionary = broken.duplicate(true)
		_check(CardKeywordGlossary.describe(broken).is_empty(),
			"%s never fabricates energy Help" % String(case[0]))
		_check(broken == broken_before, "%s leaves the fixture untouched" % String(case[0]))
	_check(overclock == _energy_definition("tinker_overclock", "tinker", 0, "self", [],
		{"gain_energy": 1, "self_hp_loss": 3})
		and trance == _energy_definition("seamstress_tailors_trance", "seamstress", 1,
			"self", [], {"energy": 1, "draw": 2}),
		"negative energy cases never mutate the positive fixtures")
	_check(CardKeywordGlossary.describe({"effects": {"gain_energy": 1, "self_hp_loss": 3}}).is_empty()
		and CardKeywordGlossary.describe({"id": "tinker_overclock",
			"effects": {"energy": 1, "draw": 2}}).is_empty(),
		"partial descriptors without the full authored contract stay silent")


## A detached Hemorrhage Hem definition with the authored structural keys the
## doubling contract re-checks, so malformed fixtures cannot borrow a positive
## verdict from the real catalog.
func _bleed_definition(card_id: Variant, owner: Variant, cost: Variant,
		target_kind: Variant, from_positions: Variant, to_positions: Variant,
		effects: Variant) -> Dictionary:
	var definition := {"id": card_id, "owner": owner, "cost": cost,
		"target_kind": target_kind}
	definition["from_positions"] = from_positions.duplicate(true) \
		if from_positions is Array else from_positions
	definition["to_positions"] = to_positions.duplicate(true) \
		if to_positions is Array else to_positions
	definition["effects"] = effects.duplicate(true) if effects is Dictionary else effects
	return definition


## Hemorrhage Hem, base and '+' records, straight from the real Seamstress pool:
## one Bleed doubling row each that states N -> 2N, that zero stays zero and that
## the ordinary turn-end tick/decrement still applies. It never teaches a fresh
## "Bleed 2" application. The authored cost, owner, slots, target, rarity and
## multiplier are checked against the catalog, and every foreign, mis-owned,
## mispriced, mistargeted, retyped or non-2 fixture stays silent.
func _bleed_doubling_catalog_test(seamstress: SeamstressPoolCards) -> void:
	var cases := [
		{"id": "seamstress_hemorrhage_hem", "cost": 2},
		{"id": "seamstress_hemorrhage_hem_plus", "cost": 1},
	]
	for case: Dictionary in cases:
		var card_id: String = String(case["id"])
		_check(seamstress.has_card(card_id),
			"Hemorrhage Hem is present in its real catalog " + card_id)
		var definition: Dictionary = seamstress.get_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			"actual Hemorrhage Hem catalog definition " + card_id)
		if definition.is_empty():
			continue
		var original: Dictionary = definition.duplicate(true)
		_check(String(definition.get("owner", "")) == "seamstress"
			and int(definition.get("cost", -1)) == int(case["cost"])
			and String(definition.get("target_kind", "")) == "enemy_single"
			and definition.get("from_positions") == [1, 2, 3]
			and definition.get("to_positions") == [1, 2, 3],
			"authored Seamstress owner, %d energy and 1-3 onto one enemy 1-3 for %s"
				% [int(case["cost"]), card_id])
		_check(String(definition.get("rarity", "")) == "uncommon",
			"Hemorrhage Hem stays an uncommon pool card " + card_id)
		var effects: Dictionary = definition.get("effects", {})
		_check(effects == {"bleed_multiplier": 2},
			"authored descriptor is exactly the multiplier 2 " + card_id)
		var rows := CardKeywordGlossary.describe(definition)
		var names: Array[String] = []
		var words := ""
		for row: Dictionary in rows:
			names.append(String(row["keyword"]))
			words += String(row["explanation"]) + " "
		_check(rows.size() == 1 and names == ["Bleed doubling"],
			"exactly one Bleed doubling row for " + card_id)
		if rows.size() != 1:
			continue
		_check(words.contains("Bleed N becomes 2N") and words.contains("stays at 0"),
			"doubling Help states N -> 2N and that zero remains zero " + card_id)
		_check(words.contains("turn end") and words.contains("decreases by 1")
			and words.contains("HP equal to its Bleed"),
			"doubling Help keeps the ordinary Bleed tick and decrement " + card_id)
		_check(words.contains("instead of adding new Bleed")
			and words.contains("not a fresh Bleed application")
			and words.contains("usual +1 Bleed does not apply"),
			"doubling Help never promises the Seamstress's +1 application passive " + card_id)
		_check(not words.contains("Bleed 2") and not words.contains("Bleed 2N"),
			"doubling Help is never taught as a fresh numeric Bleed 2 " + card_id)
		_check(definition == original and seamstress.get_definition(card_id) == original,
			"doubling Help never mutates the catalog definition " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"doubling Help stays deterministic for " + card_id)
		rows[0]["keyword"] = "Tampered"
		rows[0]["explanation"] = "Tampered"
		var fresh := CardKeywordGlossary.describe(definition)
		_check(fresh.size() == 1 and String(fresh[0]["keyword"]) == "Bleed doubling"
			and String(fresh[0]["explanation"]).contains("2N") and definition == original,
			"doubling Help results are detached from the caller's definition " + card_id)
	var base := _bleed_definition("seamstress_hemorrhage_hem", "seamstress", 2,
		"enemy_single", [1, 2, 3], [1, 2, 3], {"bleed_multiplier": 2})
	var plus := _bleed_definition("seamstress_hemorrhage_hem_plus", "seamstress", 1,
		"enemy_single", [1, 2, 3], [1, 2, 3], {"bleed_multiplier": 2})
	_check(CardKeywordGlossary.describe(base).size() == 1
		and CardKeywordGlossary.describe(plus).size() == 1,
		"exact doubling descriptor shapes are explained")
	var fixtures: Array = []
	fixtures.append(["bare multiplier descriptor without a card identity",
		_shape({"bleed_multiplier": 2})])
	var fixture := _bleed_definition("seamstress_running_stitch", "seamstress", 2,
		"enemy_single", [1, 2, 3], [1, 2, 3], {"bleed_multiplier": 2})
	fixtures.append(["multiplier on an unrelated Seamstress ID", fixture])
	fixture = base.duplicate(true)
	fixture["owner"] = "warden"
	fixtures.append(["wrong doubling owner", fixture])
	fixture = base.duplicate(true)
	fixture["cost"] = 1
	fixtures.append(["wrong base Hemorrhage Hem cost", fixture])
	fixture = plus.duplicate(true)
	fixture["cost"] = 2
	fixtures.append(["wrong upgraded Hemorrhage Hem cost", fixture])
	fixture = base.duplicate(true)
	fixture["target_kind"] = "enemy_all"
	fixtures.append(["wrong doubling target kind", fixture])
	fixture = base.duplicate(true)
	fixture["from_positions"] = [2, 3]
	fixtures.append(["doubling from two slots only", fixture])
	fixture = base.duplicate(true)
	fixture["from_positions"] = [1, 2, 4]
	fixtures.append(["doubling from an illegal slot", fixture])
	fixture = base.duplicate(true)
	fixture["to_positions"] = [1, 2]
	fixtures.append(["doubling onto two slots only", fixture])
	fixture = base.duplicate(true)
	fixture["to_positions"] = []
	fixtures.append(["doubling with no target slots", fixture])
	fixture = base.duplicate(true)
	fixture["from_positions"] = "1,2,3"
	fixtures.append(["text doubling source slots", fixture])
	fixture = base.duplicate(true)
	fixture["effects"]["bleed_multiplier"] = 0
	fixtures.append(["zero multiplier", fixture])
	fixture = base.duplicate(true)
	fixture["effects"]["bleed_multiplier"] = 1
	fixtures.append(["identity multiplier", fixture])
	fixture = base.duplicate(true)
	fixture["effects"]["bleed_multiplier"] = 3
	fixtures.append(["triple multiplier", fixture])
	fixture = base.duplicate(true)
	fixture["effects"]["bleed_multiplier"] = "2"
	fixtures.append(["text multiplier", fixture])
	fixture = base.duplicate(true)
	fixture["effects"]["bleed_multiplier"] = 2.0
	fixtures.append(["float multiplier", fixture])
	fixture = base.duplicate(true)
	fixture["effects"] = "double"
	fixtures.append(["unreadable effect block", fixture])
	fixture = base.duplicate(true)
	fixture["id"] = "seamstress_hemorrhage_hem_plus_plus"
	fixtures.append(["similarly named Hemorrhage Hem", fixture])
	fixture = base.duplicate(true)
	fixture.erase("id")
	fixtures.append(["doubling without a card ID", fixture])
	fixture = base.duplicate(true)
	fixture["id"] = 7
	fixtures.append(["non-string doubling ID", fixture])
	fixture = base.duplicate(true)
	fixture["cost"] = "2"
	fixtures.append(["text doubling cost", fixture])
	for case in fixtures:
		var broken: Dictionary = case[1]
		var broken_before: Dictionary = broken.duplicate(true)
		_check(CardKeywordGlossary.describe(broken).is_empty(),
			"%s never fabricates Bleed doubling Help" % String(case[0]))
		_check(broken == broken_before, "%s leaves the fixture untouched" % String(case[0]))
	_check(base == _bleed_definition("seamstress_hemorrhage_hem", "seamstress", 2,
			"enemy_single", [1, 2, 3], [1, 2, 3], {"bleed_multiplier": 2})
		and plus == _bleed_definition("seamstress_hemorrhage_hem_plus", "seamstress", 1,
			"enemy_single", [1, 2, 3], [1, 2, 3], {"bleed_multiplier": 2}),
		"negative doubling cases never mutate the positive fixtures")
	# Ordinary numeric Bleed keeps exactly its previous row, even on the same ID.
	var numeric := _bleed_definition("seamstress_hemorrhage_hem", "seamstress", 2,
		"enemy_single", [1, 2, 3], [1, 2, 3], {"bleed": 2})
	var numeric_rows := CardKeywordGlossary.describe(numeric)
	_check(numeric_rows.size() == 1 and String(numeric_rows[0]["keyword"]) == "Bleed 2"
		and not String(numeric_rows[0]["keyword"]).contains("doubling"),
		"ordinary numeric Bleed keeps its existing row and never becomes doubling")
	# An extended descriptor drops the doubling claim but not the numeric row it
	# genuinely authors.
	var mixed := base.duplicate(true)
	mixed["effects"]["bleed"] = 2
	var mixed_names: Array[String] = []
	for row: Dictionary in CardKeywordGlossary.describe(mixed):
		mixed_names.append(String(row["keyword"]))
	_check(not mixed_names.has("Bleed doubling") and mixed_names.has("Bleed 2"),
		"an extra effect key drops the doubling row and keeps the ordinary Bleed row")
	_check(CardKeywordGlossary.KEYWORD_ORDER == ["bleed", "weak", "exposed", "pinned",
		"unravel", "guarding", "thorns", "riposte", "tangled", "blind", "fear"]
		and CardKeywordGlossary.SPECIAL_ORDER == ["conditional_damage", "random_hit",
			"energy_tradeoff", "bleed_doubling", "two_hits", "dodge", "exhaust"],
		"Fear is the last keyword row after the legacy, Riposte, Tangled and Blind rows, and exhaust is the last special row after the new Dodge/Exhaust additions")


## A detached Pin and Pound definition with the authored structural keys the
## two-hit contract re-checks, so malformed fixtures cannot borrow a positive
## verdict from the real catalog.
func _pin_definition(card_id: Variant, owner: Variant, cost: Variant,
		target_kind: Variant, from_positions: Variant, to_positions: Variant,
		effects: Variant) -> Dictionary:
	var definition := {"id": card_id, "owner": owner, "cost": cost,
		"target_kind": target_kind}
	definition["from_positions"] = from_positions.duplicate(true) \
		if from_positions is Array else from_positions
	definition["to_positions"] = to_positions.duplicate(true) \
		if to_positions is Array else to_positions
	definition["effects"] = effects.duplicate(true) if effects is Dictionary else effects
	return definition


## Pin and Pound, base and '+' records, straight from the real Warden pool: one
## authored Two hits row each that states the sequential same-target order, that
## hit 2 needs a surviving target, the single different-owner Pinned +5 on hit 1
## and that this attack creates no pin. The authored cost, owner, slot, target
## range and exact damage are re-checked against the catalog, and every foreign,
## mis-owned, mispriced, mispositioned, mistargeted or wrong-hit fixture stays
## silent.
func _pin_and_pound_catalog_test(warden: WardenPoolCards) -> void:
	var cases := [
		{"id": "warden_pin_and_pound", "damage": 9},
		{"id": "warden_pin_and_pound_plus", "damage": 12},
	]
	for case: Dictionary in cases:
		var card_id: String = String(case["id"])
		_check(warden.has_card(card_id),
			"Pin and Pound is present in its real catalog " + card_id)
		var definition: Dictionary = warden.get_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			"actual Pin and Pound catalog definition " + card_id)
		if definition.is_empty():
			continue
		var original: Dictionary = definition.duplicate(true)
		var effects: Dictionary = definition.get("effects", {})
		_check(String(definition.get("owner", "")) == "warden"
			and int(definition.get("cost", -1)) == 2
			and String(definition.get("target_kind", "")) == "enemy_single"
			and definition.get("from_positions") == [1]
			and definition.get("to_positions") == [1, 2, 3]
			and effects == {"damage": int(case["damage"]), "hits": 2},
			"authored Warden front slot, 2 energy and two hits on one enemy 1-3 for " + card_id)
		var rows := CardKeywordGlossary.describe(definition)
		_check(rows.size() == 1 and String(rows[0]["keyword"]) == "Two hits",
			"exactly one Two hits row for " + card_id)
		if rows.size() != 1:
			continue
		var text := String(rows[0]["explanation"])
		_check(text.contains("Costs %d energy" % int(definition.get("cost", -1)))
			and text.contains("two hits of %d damage each" % int(effects.get("damage", 0))),
			"two-hit Help repeats the authored cost and per-hit damage " + card_id)
		_check(text.contains("one after the other")
			and text.contains("same originally chosen enemy")
			and text.contains("second hit is skipped"),
			"two-hit Help states the sequential same-target order and survival rule " + card_id)
		_check(text.contains("DIFFERENT hero") and text.contains("+5")
			and text.contains("first hit only") and text.contains("before Weak/Exposed")
			and text.contains("consumed then") and text.contains("same hero does not apply"),
			"two-hit Help states one different-owner Pinned +5 on hit 1 only " + card_id)
		_check(text.contains("creates no Pinned token")
			and not text.contains("adds Pinned") and not text.contains("applies Pinned"),
			"two-hit Help never claims this attack pins its target " + card_id)
		_check(definition == original and warden.get_definition(card_id) == original,
			"two-hit Help never mutates the catalog definition " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"two-hit Help stays deterministic for " + card_id)
		rows[0]["keyword"] = "Tampered"
		rows[0]["explanation"] = "Tampered"
		var fresh := CardKeywordGlossary.describe(definition)
		_check(fresh.size() == 1 and String(fresh[0]["keyword"]) == "Two hits"
			and String(fresh[0]["explanation"]).contains("two hits")
			and definition == original,
			"two-hit Help results are detached from the caller's definition " + card_id)
	_check(CardKeywordGlossary.describe(warden.get_definition("warden_heavy_thimble")).is_empty(),
		"ordinary Warden Heavy Thimble never gains a two-hit row")
	var base := _pin_definition("warden_pin_and_pound", "warden", 2,
		"enemy_single", [1], [1, 2, 3], {"damage": 9, "hits": 2})
	var plus := _pin_definition("warden_pin_and_pound_plus", "warden", 2,
		"enemy_single", [1], [1, 2, 3], {"damage": 12, "hits": 2})
	_check(CardKeywordGlossary.describe(base).size() == 1
		and CardKeywordGlossary.describe(plus).size() == 1,
		"exact two-hit descriptor shapes are explained")
	var fixtures: Array = []
	fixtures.append(["bare two-hit descriptor without a card identity",
		_shape({"damage": 9, "hits": 2})])
	fixtures.append(["two-hit descriptor on an unrelated Warden ID",
		_pin_definition("warden_heavy_thimble", "warden", 2, "enemy_single",
			[1], [1, 2, 3], {"damage": 9, "hits": 2})])
	fixtures.append(["arbitrary hit count on another authored attack",
		_pin_definition("warden_pinning_jab", "warden", 1, "enemy_single",
			[1, 2], [1, 2, 3], {"damage": 4, "hits": 2})])
	var fixture := base.duplicate(true)
	fixture["owner"] = "seamstress"
	fixtures.append(["wrong two-hit owner", fixture])
	fixture = base.duplicate(true)
	fixture["cost"] = 1
	fixtures.append(["wrong base Pin and Pound cost", fixture])
	fixture = plus.duplicate(true)
	fixture["cost"] = 3
	fixtures.append(["wrong upgraded Pin and Pound cost", fixture])
	fixture = base.duplicate(true)
	fixture["target_kind"] = "enemy_all"
	fixtures.append(["wrong two-hit target kind", fixture])
	fixture = base.duplicate(true)
	fixture["from_positions"] = [2]
	fixtures.append(["two-hit from the middle slot only", fixture])
	fixture = base.duplicate(true)
	fixture["from_positions"] = [1, 2]
	fixtures.append(["two-hit from two slots", fixture])
	fixture = base.duplicate(true)
	fixture["from_positions"] = []
	fixtures.append(["two-hit from no slot", fixture])
	fixture = base.duplicate(true)
	fixture["from_positions"] = "1"
	fixtures.append(["text two-hit source slots", fixture])
	fixture = base.duplicate(true)
	fixture["to_positions"] = [1, 2]
	fixtures.append(["two-hit onto two slots only", fixture])
	fixture = base.duplicate(true)
	fixture["to_positions"] = [1, 2, 4]
	fixtures.append(["two-hit onto an illegal slot", fixture])
	fixture = base.duplicate(true)
	fixture["to_positions"] = []
	fixtures.append(["two-hit with no target slots", fixture])
	fixture = base.duplicate(true)
	fixture["effects"]["hits"] = 1
	fixtures.append(["single-hit rewrite", fixture])
	fixture = base.duplicate(true)
	fixture["effects"]["hits"] = 3
	fixtures.append(["three-hit rewrite", fixture])
	fixture = base.duplicate(true)
	fixture["effects"]["hits"] = "2"
	fixtures.append(["text hit count", fixture])
	fixture = base.duplicate(true)
	fixture["effects"]["hits"] = 2.0
	fixtures.append(["float hit count", fixture])
	fixture = base.duplicate(true)
	fixture["effects"]["damage"] = 10
	fixtures.append(["wrong two-hit damage", fixture])
	fixture = base.duplicate(true)
	fixture["effects"]["damage"] = 12
	fixtures.append(["base record with upgraded damage", fixture])
	fixture = plus.duplicate(true)
	fixture["effects"]["damage"] = 9
	fixtures.append(["upgraded record with base damage", fixture])
	fixture = base.duplicate(true)
	fixture["effects"]["damage"] = "9"
	fixtures.append(["text two-hit damage", fixture])
	fixture = base.duplicate(true)
	fixture["effects"].erase("hits")
	fixtures.append(["two-hit record without a hit count", fixture])
	fixture = base.duplicate(true)
	fixture["effects"].erase("damage")
	fixtures.append(["two-hit record without damage", fixture])
	fixture = base.duplicate(true)
	fixture["effects"] = "two hits"
	fixtures.append(["unreadable two-hit effect block", fixture])
	fixture = base.duplicate(true)
	fixture["id"] = "warden_pin_and_pound_plus_plus"
	fixtures.append(["similarly named Pin and Pound", fixture])
	fixture = base.duplicate(true)
	fixture.erase("id")
	fixtures.append(["two-hit descriptor without a card ID", fixture])
	fixture = base.duplicate(true)
	fixture["id"] = 7
	fixtures.append(["non-string two-hit ID", fixture])
	fixture = base.duplicate(true)
	fixture["cost"] = "2"
	fixtures.append(["text two-hit cost", fixture])
	for case in fixtures:
		var broken: Dictionary = case[1]
		var broken_before: Dictionary = broken.duplicate(true)
		_check(CardKeywordGlossary.describe(broken).is_empty(),
			"%s never fabricates two-hit Help" % String(case[0]))
		_check(broken == broken_before, "%s leaves the fixture untouched" % String(case[0]))
	_check(base == _pin_definition("warden_pin_and_pound", "warden", 2,
			"enemy_single", [1], [1, 2, 3], {"damage": 9, "hits": 2})
		and plus == _pin_definition("warden_pin_and_pound_plus", "warden", 2,
			"enemy_single", [1], [1, 2, 3], {"damage": 12, "hits": 2}),
		"negative two-hit cases never mutate the positive fixtures")
	# An extended descriptor that also claims to pin drops the two-hit row but
	# keeps the ordinary Pinned row it genuinely authors.
	var pin_claim := base.duplicate(true)
	pin_claim["effects"]["pinned"] = true
	var pin_claim_before: Dictionary = pin_claim.duplicate(true)
	var pin_claim_names: Array[String] = []
	for row: Dictionary in CardKeywordGlossary.describe(pin_claim):
		pin_claim_names.append(String(row["keyword"]))
	_check(not pin_claim_names.has("Two hits") and pin_claim_names.has("Pinned")
		and pin_claim == pin_claim_before,
		"an extra pin claim drops the two-hit row and keeps only its ordinary Pinned row")


## Row keywords of a describe() result, in the order the formatter produced them.
func _row_names(rows: Array[Dictionary]) -> Array[String]:
	var names: Array[String] = []
	for row: Dictionary in rows:
		names.append(String(row.get("keyword", "")))
	return names


## A detached Blind definition shaped like a real catalog record: the strict
## descriptor shape plus the authored target kind. A malformed fixture can never
## borrow a positive verdict from a real catalog entry.
func _blind_definition(target_kind: Variant, effects: Variant) -> Dictionary:
	var definition := {"id": "lantern_monk_help_fixture"}
	definition["target_kind"] = target_kind
	definition["effects"] = effects.duplicate(true) if effects is Dictionary else effects
	return definition


## The row a Blind card must print: one-shot, no stack and no duration, the NEXT
## attempted attack missing in full (a whole multi-hit sequence), the Blind spent
## once on that attempt, and the unspent marker kept through an enemy turn that
## never attacks. The row must state the shipped live enemy-phase consumption
## instead of the old "live combat does not yet cancel" disclaimer, and Blind has
## no amount to print.
func _check_blind_text(text: String, card_id: String) -> void:
	_check(text.contains("NEXT attempted attack") and text.contains("misses in full"),
		"Blind Help states the affected enemy's NEXT attempted attack misses in full for " + card_id)
	_check(text.contains("including every hit of a multi-hit sequence"),
		"Blind Help covers one whole attempted attack, multi-hit included, for " + card_id)
	_check(text.contains("spent once on that attempt"),
		"Blind Help states the Blind is spent once on that attempted attack for " + card_id)
	_check(text.contains("never a stack") and text.contains("never a number of turns"),
		"Blind Help invents no duration or stack for " + card_id)
	_check(text.contains("An enemy buff or debuff is not an attack")
		and text.contains("ends without attacking keeps the unspent Blind"),
		"Blind Help keeps unspent Blind through a non-attacking enemy turn for " + card_id)
	_check(text.contains("Live combat already resolves this")
		and text.contains("enemy phase spends the Blind"),
		"Blind Help states the shipped live enemy-phase consumption for " + card_id)
	_check(not text.contains("does not yet") and not text.contains("design rule only")
		and not text.contains("cannot cancel"),
		"Blind Help drops the false live-play disclaimer for " + card_id)
	var no_amount := true
	for digit: String in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		if text.contains(digit):
			no_amount = false
	_check(no_amount, "Blind Help prints no numeric amount or duration for " + card_id)


## AC1: the real Lantern Monk catalogs author Blind in two shapes -- the starter
## `blind: 1` and the pool `blind_next_attack: true` -- and each base and '+' card
## that really authors one gets exactly one Blind Help row. The rows are read from
## detached catalog definitions, so no catalog total or ordered ID list is assumed;
## the other cards in both catalogs must never gain a Blind row.
func _blind_catalog_test(starters: LanternMonkStarterCards,
		pool: LanternMonkPoolCards) -> void:
	var cases := [
		{"catalog": starters, "id": "lantern_monk_wick_spark", "target": "enemy_single",
			"cost": 1, "damage": 4, "draw": 0, "exposed": 0, "spelling": "blind",
			"rows": ["Blind"]},
		{"catalog": starters, "id": "lantern_monk_wick_spark_plus", "target": "enemy_single",
			"cost": 1, "damage": 6, "draw": 0, "exposed": 0, "spelling": "blind",
			"rows": ["Blind"]},
		{"catalog": starters, "id": "lantern_monk_moth_wink", "target": "enemy_single",
			"cost": 1, "damage": 0, "draw": 1, "exposed": 0, "spelling": "blind",
			"rows": ["Blind"]},
		{"catalog": starters, "id": "lantern_monk_moth_wink_plus", "target": "enemy_single",
			"cost": 0, "damage": 0, "draw": 1, "exposed": 0, "spelling": "blind",
			"rows": ["Blind"]},
		{"catalog": pool, "id": "lantern_monk_wick_flicker", "target": "enemy_single",
			"cost": 1, "damage": 4, "draw": 0, "exposed": 0, "spelling": "blind_next_attack",
			"rows": ["Blind"]},
		{"catalog": pool, "id": "lantern_monk_wick_flicker_plus", "target": "enemy_single",
			"cost": 1, "damage": 6, "draw": 0, "exposed": 0, "spelling": "blind_next_attack",
			"rows": ["Blind"]},
		{"catalog": pool, "id": "lantern_monk_moth_lure", "target": "enemy_single",
			"cost": 1, "damage": 0, "draw": 1, "exposed": 0, "spelling": "blind_next_attack",
			"rows": ["Blind"]},
		{"catalog": pool, "id": "lantern_monk_moth_lure_plus", "target": "enemy_single",
			"cost": 0, "damage": 0, "draw": 1, "exposed": 0, "spelling": "blind_next_attack",
			"rows": ["Blind"]},
		{"catalog": pool, "id": "lantern_monk_snuff_flame", "target": "enemy_single",
			"cost": 1, "damage": 3, "draw": 0, "exposed": 1, "spelling": "blind_next_attack",
			"rows": ["Exposed 1", "Blind"]},
		{"catalog": pool, "id": "lantern_monk_snuff_flame_plus", "target": "enemy_single",
			"cost": 1, "damage": 4, "draw": 0, "exposed": 2, "spelling": "blind_next_attack",
			"rows": ["Exposed 2", "Blind"]},
		{"catalog": pool, "id": "lantern_monk_moth_cloud", "target": "enemy_all",
			"cost": 2, "damage": 0, "draw": 0, "exposed": 0, "spelling": "blind_next_attack",
			"rows": ["Blind", "Exhaust"]},
		{"catalog": pool, "id": "lantern_monk_moth_cloud_plus", "target": "enemy_all",
			"cost": 1, "damage": 0, "draw": 0, "exposed": 0, "spelling": "blind_next_attack",
			"rows": ["Blind", "Exhaust"]},
	]
	for case: Dictionary in cases:
		var catalog: Variant = case["catalog"]
		var card_id: String = String(case["id"])
		_check(catalog.has_card(card_id),
			"Blind card is present in its real catalog " + card_id)
		if not catalog.has_card(card_id):
			continue
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			"actual detached catalog definition " + card_id)
		if definition.is_empty():
			continue
		var original: Dictionary = definition.duplicate(true)
		var effects: Dictionary = definition.get("effects", {})
		_check(String(definition.get("owner", "")) == "lantern_monk"
			and String(definition.get("target_kind", "")) == String(case["target"])
			and int(definition.get("cost", -1)) == int(case["cost"]),
			"authored Lantern Monk owner, target and cost for " + card_id)
		_check(int(effects.get("damage", 0)) == int(case["damage"])
			and int(effects.get("draw", 0)) == int(case["draw"])
			and int(effects.get("exposed", 0)) == int(case["exposed"]),
			"authored damage, draw and Exposed amounts for " + card_id)
		if String(case["spelling"]) == "blind":
			_check(effects.get("blind") is int and int(effects["blind"]) == 1
				and not effects.has("blind_next_attack"),
				"authored starter Blind is exactly the integer one " + card_id)
		else:
			_check(effects.get("blind_next_attack") is bool
				and bool(effects["blind_next_attack"]) and not effects.has("blind"),
				"authored pool Blind is exactly the boolean true " + card_id)
		var rows := CardKeywordGlossary.describe(definition)
		var names := _row_names(rows)
		_check(names == case["rows"],
			"catalog %s prints exactly %s, got %s" % [card_id, str(case["rows"]), str(names)])
		_check(names.count("Blind") == 1, "exactly one Blind Help row for " + card_id)
		var blind_text := ""
		for row: Dictionary in rows:
			if String(row.get("keyword", "")) == "Blind":
				blind_text = String(row.get("explanation", ""))
		if blind_text.is_empty():
			continue
		_check_blind_text(blind_text, card_id)
		_check(definition == original and catalog.get_definition(card_id) == original,
			"Blind Help never mutates the catalog definition " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"Blind Help stays deterministic for " + card_id)
		rows[rows.size() - 1]["keyword"] = "Tampered"
		rows[rows.size() - 1]["explanation"] = "Tampered"
		var fresh := CardKeywordGlossary.describe(definition)
		_check(_row_names(fresh) == case["rows"] and definition == original,
			"Blind Help results are detached from the caller's definition " + card_id)
	# Blind is only authored on the six named starter cards and four named pool
	# families; every other base and '+' card in both catalogs stays without it.
	var blind_base_ids := ["lantern_monk_wick_spark", "lantern_monk_moth_wink",
		"lantern_monk_wick_flicker", "lantern_monk_moth_lure",
		"lantern_monk_snuff_flame", "lantern_monk_moth_cloud"]
	var others: Array[String] = []
	for base_id: String in starters.get_starter_ids():
		if not blind_base_ids.has(base_id):
			others.append(base_id)
	for base_id: String in pool.get_base_ids():
		if not blind_base_ids.has(base_id):
			others.append(base_id)
	_check(not others.is_empty(),
		"both real Lantern Monk catalogs still author cards without Blind")
	for base_id: String in others:
		var catalog: Variant = starters if starters.has_card(base_id) else pool
		var authored: Array[String] = [base_id, String(catalog.get_upgrade_id(base_id))]
		for card_id: String in authored:
			if card_id.is_empty():
				continue
			var definition: Dictionary = catalog.get_definition(card_id)
			_check(not definition.is_empty()
				and not (definition.get("effects", {}) as Dictionary).has("blind")
				and not (definition.get("effects", {}) as Dictionary).has("blind_next_attack"),
				"non-Blind Lantern Monk card authors no Blind descriptor " + card_id)
			_check(not _row_names(CardKeywordGlossary.describe(definition)).has("Blind"),
				"non-Blind Lantern Monk card gains no Blind Help row " + card_id)
	# AC2: a well-formed Blind is explained beside damage, draw, Exposed, exhaust
	# or a whole-enemy target, with the established rows keeping their own order.
	var single_with_damage := _blind_definition("enemy_single", {"damage": 4, "blind": 1})
	var all_with_exposed := _blind_definition("enemy_all",
		{"damage": 3, "exposed": 1, "blind_next_attack": true, "exhaust": true})
	var random_with_draw := _blind_definition("enemy_random",
		{"blind_next_attack": true, "draw": 1})
	_check(_row_names(CardKeywordGlossary.describe(single_with_damage)) == ["Blind"],
		"damage plus a single-enemy Blind prints one Blind row")
	_check(_row_names(CardKeywordGlossary.describe(all_with_exposed)) == ["Exposed 1", "Blind"],
		"a whole-enemy Exposed plus Blind prints Exposed first and Blind last")
	_check(_row_names(CardKeywordGlossary.describe(random_with_draw)) == ["Blind"],
		"a random-enemy Blind with draw prints one Blind row")
	var exposed_only := _blind_definition("enemy_all", {"exposed": 1})
	_check(CardKeywordGlossary.describe(all_with_exposed)[0]
		== CardKeywordGlossary.describe(exposed_only)[0],
		"the Exposed row beside a Blind keeps its established value and explanation")
	# AC3: every other authored shape stays silent instead of inventing a Blind.
	var fixtures: Array = []
	fixtures.append(["blind 0", _blind_definition("enemy_single", {"blind": 0})])
	fixtures.append(["blind 2", _blind_definition("enemy_single", {"blind": 2})])
	fixtures.append(["bool true in the integer spelling",
		_blind_definition("enemy_single", {"blind": true})])
	fixtures.append(["float one", _blind_definition("enemy_single", {"blind": 1.0})])
	fixtures.append(["text one", _blind_definition("enemy_single", {"blind": "1"})])
	fixtures.append(["null Blind", _blind_definition("enemy_single", {"blind": null})])
	fixtures.append(["blind_next_attack false",
		_blind_definition("enemy_single", {"blind_next_attack": false})])
	fixtures.append(["integer one in the boolean spelling",
		_blind_definition("enemy_single", {"blind_next_attack": 1})])
	fixtures.append(["text true", _blind_definition("enemy_single",
		{"blind_next_attack": "true"})])
	fixtures.append(["null next attack flag",
		_blind_definition("enemy_single", {"blind_next_attack": null})])
	fixtures.append(["both spellings once",
		_blind_definition("enemy_single", {"blind": 1, "blind_next_attack": true})])
	fixtures.append(["self target", _blind_definition("self", {"blind": 1})])
	fixtures.append(["self target in the boolean spelling",
		_blind_definition("self", {"blind_next_attack": true})])
	fixtures.append(["ally target", _blind_definition("ally_single", {"blind": 1})])
	fixtures.append(["party target", _blind_definition("party_all", {"blind_next_attack": true})])
	fixtures.append(["missing target kind", _blind_definition(null, {"blind": 1})])
	fixtures.append(["unknown target kind", _blind_definition("battlefield", {"blind": 1})])
	fixtures.append(["non-string target kind", _blind_definition(7, {"blind_next_attack": true})])
	fixtures.append(["unreadable effect block", _blind_definition("enemy_single", "blind")])
	for case in fixtures:
		var broken: Dictionary = case[1]
		var broken_before: Dictionary = broken.duplicate(true)
		var rows := CardKeywordGlossary.describe(broken)
		_check(not _row_names(rows).has("Blind"),
			"%s never fabricates a Blind Help row" % String(case[0]))
		_check(broken == broken_before,
			"%s leaves the fixture untouched" % String(case[0]))
		_check(CardKeywordGlossary.describe(broken) == rows,
			"%s stays deterministic" % String(case[0]))
	# A malformed or ambiguous Blind beside a legitimate keyword keeps that row
	# exactly as the keyword alone would print it.
	for pair in [[_blind_definition("enemy_single", {"blind": 2, "exposed": 1}),
			_blind_definition("enemy_single", {"exposed": 1})],
			[_blind_definition("party_all", {"blind_next_attack": true, "exposed": 1}),
			_blind_definition("party_all", {"exposed": 1})]]:
		var mixed: Dictionary = pair[0]
		var mixed_before: Dictionary = mixed.duplicate(true)
		var mixed_names := _row_names(CardKeywordGlossary.describe(mixed))
		_check(mixed_names == ["Exposed 1"] and not mixed_names.has("Blind"),
			"a malformed Blind keeps only the independent Exposed row: " + str(mixed_names))
		_check(CardKeywordGlossary.describe(mixed) == CardKeywordGlossary.describe(pair[1]),
			"a malformed Blind does not corrupt the Exposed row it sits beside")
		_check(mixed == mixed_before, "the malformed compound fixture is never mutated")
	_check(single_with_damage == _blind_definition("enemy_single", {"damage": 4, "blind": 1})
		and all_with_exposed == _blind_definition("enemy_all",
			{"damage": 3, "exposed": 1, "blind_next_attack": true, "exhaust": true})
		and random_with_draw == _blind_definition("enemy_random",
			{"blind_next_attack": true, "draw": 1}),
		"negative cases never mutate the positive Blind fixtures")
	var keyword_order := CardKeywordGlossary.KEYWORD_ORDER
	_check(keyword_order[keyword_order.size() - 1] == "fear"
		and keyword_order[keyword_order.size() - 2] == "blind"
		and keyword_order.find("blind") > keyword_order.find("tangled"),
		"Fear is appended after Blind, which is appended after Tangled")


## AC2: Thorns N Help explains the generic status effect without claiming a single
## source. The four real Thorns cards — Counter-stitch base/plus (live Warden
## pool) and Buckle Rebound base/plus (V3 Warden pool) — each carry Block, Thorns
## and the until-next-turn duration, and each earns exactly one Thorns %d row with
## the source-neutral retaliation wording plus the duration clause. Bad-count
## Thorns values (missing, zero, negative, boolean, string, float) produce no row,
## an enemy-shaped Thorns descriptor makes no Warden/position/expiry claims, and
## the fixed keyword ordering is preserved.
func _thorns_test(warden: WardenPoolCards, v3_warden: V3WardenPoolCards) -> void:
	# The four real Thorns cards: Counter-stitch base/plus and Buckle Rebound
	# base/plus. Plus variants are reached via has_card(), since get_base_ids()
	# only lists base forms.
	var cases := [
		{"catalog": warden, "id": "warden_counter_stitch", "thorns": 3},
		{"catalog": warden, "id": "warden_counter_stitch_plus", "thorns": 4},
		{"catalog": v3_warden, "id": "warden_v3_buckle_rebound", "thorns": 3},
		{"catalog": v3_warden, "id": "warden_v3_buckle_rebound_plus", "thorns": 4},
	]
	for case: Dictionary in cases:
		var catalog: Variant = case["catalog"]
		var card_id: String = String(case["id"])
		var authored: int = int(case["thorns"])
		_check(catalog.has_card(card_id), "Thorns card present in catalog " + card_id)
		if not catalog.has_card(card_id):
			continue
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			"actual catalog definition " + card_id)
		if definition.is_empty():
			continue
		var original: Dictionary = definition.duplicate(true)
		var effects: Dictionary = definition.get("effects", {})
		_check(effects.has("thorns") and effects.get("thorns") is int
			and int(effects["thorns"]) == authored,
			"authored Thorns %d read from catalog: %s" % [authored, card_id])
		_check(effects.get("block") is int and effects.get("duration") == "until_next_turn",
			"authored Block and until-next-turn duration for " + card_id)
		var rows := CardKeywordGlossary.describe(definition)
		var names := _row_names(rows)
		_check(names == ["Thorns %d" % authored],
			"exactly one Thorns %d row for %s (got %s)" % [authored, card_id, str(names)])
		if names != ["Thorns %d" % authored]:
			continue
		var text := str(rows[0]["explanation"])
		_check(text.contains("takes %d damage" % authored),
			"Thorns Help states the retaliation amount: " + card_id)
		_check(text.contains("confirmed positive-damage hit"),
			"Thorns Help states the hit trigger: " + card_id)
		_check(text.contains("attacker's own Block") and text.contains("before HP"),
			"Thorns Help states retaliation goes through Block before HP: " + card_id)
		_check(text.contains("Misses, previews and rejected"),
			"Thorns Help states misses/previews/rejected do not trigger: " + card_id)
		_check(text.contains("until the next turn"),
			"Thorns Help states the until-next-turn expiry: " + card_id)
		_check(not text.contains("Counter-stitch") and not text.contains("Buckle Rebound")
			and not text.contains("Warden's"),
			"Thorns Help makes no source-specific claim: " + card_id)
		_check(definition == original and catalog.get_definition(card_id) == original,
			"Thorns Help never mutates the catalog definition " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"Thorns Help stays deterministic for " + card_id)
		rows[0]["keyword"] = "Tampered"
		rows[0]["explanation"] = "Tampered"
		var fresh := CardKeywordGlossary.describe(definition)
		_check(_row_names(fresh) == ["Thorns %d" % authored] and definition == original,
			"Thorns Help results are detached from the caller's definition " + card_id)
	# Bad-count cases: missing, zero, negative, boolean, string, float all
	# produce no Thorns row instead of inventing one.
	var bad_counts: Array = [
		["missing", {"effects": {}}],
		["zero", {"effects": {"thorns": 0}}],
		["negative", {"effects": {"thorns": -1}}],
		["boolean true", {"effects": {"thorns": true}}],
		["string", {"effects": {"thorns": "3"}}],
		["float", {"effects": {"thorns": 3.0}}],
	]
	for case in bad_counts:
		var broken: Dictionary = case[1].duplicate(true)
		var broken_before: Dictionary = broken.duplicate(true)
		var rows := CardKeywordGlossary.describe(broken)
		_check(not _row_names(rows).has("Thorns 3") and not _row_names(rows).has("Thorns 0")
			and rows.is_empty(),
			"%s produces no Thorns row" % String(case[0]))
		_check(broken == broken_before,
			"%s leaves the fixture untouched" % String(case[0]))
	# Enemy-shaped Thorns descriptor: source-neutral text that never claims
	# Warden, positions or expiry when the record carries no duration.
	var enemy_thorns := {"id": "goblin_spine_crawler", "effects": {"thorns": 2}}
	var enemy_rows := CardKeywordGlossary.describe(enemy_thorns)
	var enemy_names := _row_names(enemy_rows)
	_check(enemy_names == ["Thorns 2"], "enemy-shaped Thorns keeps one row: " + str(enemy_names))
	if enemy_names.has("Thorns 2"):
		var idx: int = enemy_names.find("Thorns 2")
		var enemy_text: String = str(enemy_rows[idx]["explanation"])
		_check(not enemy_text.is_empty(), "enemy Thorns Help is non-empty")
		_check(enemy_text.contains("takes 2 damage")
			and enemy_text.contains("confirmed positive-damage hit")
			and enemy_text.contains("attacker's own Block")
			and enemy_text.contains("before HP")
			and enemy_text.contains("Misses, previews and rejected"),
			"enemy Thorns Help states the generic mechanics")
		_check(not enemy_text.contains("Warden")
			and not enemy_text.contains("Counter-stitch")
			and not enemy_text.contains("Buckle Rebound")
			and not enemy_text.contains("positions 1-2")
			and not enemy_text.contains("until the next turn"),
			"enemy Thorns Help makes no false Warden/position/expiry claims: " + enemy_text)
	# Stable ordering: Thorns sits inside KEYWORD_ORDER, after Guarding and
	# before Riposte; combined rows keep that fixed position.
	var order := CardKeywordGlossary.KEYWORD_ORDER
	_check(order.find("thorns") == 6
		and order.find("thorns") > order.find("guarding")
		and order.find("thorns") < order.find("riposte"),
		"Thorns stays in fixed keyword order between Guarding and Riposte: " + str(order))
	var combined := {"id": "thorns_order_probe", "effects": {
		"bleed": 1, "weak": 1, "guarding": true, "thorns": 2}}
	var combined_names := _row_names(CardKeywordGlossary.describe(combined))
	_check(combined_names == ["Bleed 1", "Weak 1", "Guarding", "Thorns 2"],
		"Thorns follows Guarding in combined stable order: " + str(combined_names))


## Genuine catalog tests asserting that every authentic shoulder-crow printing
## produces exactly one Help row titled Pierce Block, whose explanation mentions
## the backmost living enemy, direct damage straight to HP without reducing or
## consuming enemy Block, Weak / Exposed / Tangled adjustment, and the explicit
## disclaimer that live hand wiring is pending. Also asserts detached row results,
## immutable catalog records, and fail-closed negative space.
func _scarecrow_crow_catalog_test(starter: ScarecrowStarterCards, pool: ScarecrowPoolCards) -> void:
	var cases := [
		{"catalog": starter, "id": "scarecrow_crow_dive", "damage": 3, "upgrades_to": "scarecrow_crow_dive_plus"},
		{"catalog": starter, "id": "scarecrow_crow_dive_plus", "damage": 5, "upgrades_to": ""},
		{"catalog": pool, "id": "scarecrow_crow_peck", "damage": 4, "upgrades_to": "scarecrow_crow_peck_plus"},
		{"catalog": pool, "id": "scarecrow_crow_peck_plus", "damage": 6, "upgrades_to": ""},
	]
	for case: Dictionary in cases:
		var catalog: Variant = case["catalog"]
		var card_id: String = String(case["id"])
		var authored_damage: int = int(case["damage"])
		_check(catalog.has_card(card_id), "shoulder-crow card present in catalog " + card_id)
		if not catalog.has_card(card_id):
			continue
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			"actual shoulder-crow catalog definition " + card_id)
		if definition.is_empty():
			continue
		var original: Dictionary = definition.duplicate(true)
		var effects: Dictionary = definition.get("effects", {})
		_check(effects.get("damage") == authored_damage and effects.get("ignore_block") == true,
			"authored damage %d and ignore_block true for %s" % [authored_damage, card_id])
		_check(String(definition.get("owner", "")) == "scarecrow"
			and int(definition.get("cost", -1)) == 1
			and String(definition.get("target_kind", "")) == "enemy_back"
			and Array(definition.get("from_positions", [])) == [1, 2, 3]
			and Array(definition.get("to_positions", [])) == [1, 2, 3],
			"authored owner, cost, target and positions for " + card_id)
		_check(CardShortRules.is_authored_block_pierce(definition),
			"CardShortRules authenticates block pierce " + card_id)
		_check(CardShortRules.is_authored_crow(definition),
			"CardShortRules authenticates crow alias " + card_id)
		_check(not CardShortRules.has_unknown(definition),
			"CardShortRules reports no unknown effects for authentic " + card_id)
		var face: String = CardShortRules.line(definition)
		var expected_face := "Deal %d to the backmost living enemy. Pierce Block." % authored_damage
		_check(face == expected_face, "face text exact match for %s: '%s'" % [card_id, face])
		var rows := CardKeywordGlossary.describe(definition)
		var names := _row_names(rows)
		_check(names == ["Pierce Block"],
			"exactly one Pierce Block row for %s (got %s)" % [card_id, str(names)])
		if names != ["Pierce Block"]:
			continue
		var text := str(rows[0]["explanation"])
		_check(text.contains("backmost living enemy"),
			"Pierce Block Help mentions the backmost living enemy: " + card_id)
		_check(text.contains("HP"),
			"Pierce Block Help mentions direct HP damage: " + card_id)
		_check(text.contains("without reducing or consuming enemy Block")
			or (text.contains("without reducing") and text.contains("Block")),
			"Pierce Block Help mentions direct HP without reducing Block: " + card_id)
		_check(text.contains("Weak") and text.contains("Exposed") and text.contains("Tangled"),
			"Pierce Block Help mentions Weak, Exposed and Tangled adjustments: " + card_id)
		_check(text.contains("authored card rule only") and text.contains("live combat does not yet play"),
			"Pierce Block Help contains explicit live hand disclaimer: " + card_id)
		_check(definition == original and catalog.get_definition(card_id) == original,
			"Pierce Block Help never mutates catalog definition: " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"Pierce Block Help stays deterministic for " + card_id)
		rows[0]["keyword"] = "Tampered"
		rows[0]["explanation"] = "Tampered"
		var fresh := CardKeywordGlossary.describe(definition)
		_check(_row_names(fresh) == ["Pierce Block"] and definition == original,
			"Pierce Block Help results are detached from caller definition: " + card_id)

	var authentic_dive: Dictionary = starter.get_definition("scarecrow_crow_dive")
	var authentic_dive_plus: Dictionary = starter.get_definition("scarecrow_crow_dive_plus")
	var authentic_peck: Dictionary = pool.get_definition("scarecrow_crow_peck")
	var authentic_peck_plus: Dictionary = pool.get_definition("scarecrow_crow_peck_plus")

	var negatives: Array = []

	# Non-boolean flag
	var f := authentic_dive.duplicate(true)
	f["effects"]["ignore_block"] = 1
	negatives.append(["integer ignore_block", f])
	f = authentic_dive.duplicate(true)
	f["effects"]["ignore_block"] = "true"
	negatives.append(["string ignore_block", f])
	f = authentic_dive.duplicate(true)
	f["effects"]["ignore_block"] = false
	negatives.append(["false ignore_block", f])
	f = authentic_dive.duplicate(true)
	f["effects"]["ignore_block"] = null
	negatives.append(["null ignore_block", f])

	# Wrong target
	f = authentic_dive.duplicate(true)
	f["target_kind"] = "enemy_front"
	negatives.append(["wrong target enemy_front", f])
	f = authentic_dive.duplicate(true)
	f["target_kind"] = "enemy_all"
	negatives.append(["wrong target enemy_all", f])
	f = authentic_dive.duplicate(true)
	f["target_kind"] = "self"
	negatives.append(["wrong target self", f])
	f = authentic_dive.duplicate(true)
	f["target_kind"] = "ally_single"
	negatives.append(["wrong target ally_single", f])

	# Wrong owner
	f = authentic_dive.duplicate(true)
	f["owner"] = "warden"
	negatives.append(["wrong owner warden", f])
	f = authentic_peck.duplicate(true)
	f["owner"] = "tinker"
	negatives.append(["wrong owner tinker", f])
	f = authentic_dive.duplicate(true)
	f.erase("owner")
	negatives.append(["missing owner", f])

	# Wrong cost
	f = authentic_dive.duplicate(true)
	f["cost"] = 0
	negatives.append(["wrong cost 0", f])
	f = authentic_dive.duplicate(true)
	f["cost"] = 2
	negatives.append(["wrong cost 2", f])
	f = authentic_dive.duplicate(true)
	f["cost"] = "1"
	negatives.append(["string cost", f])

	# Wrong positions
	f = authentic_dive.duplicate(true)
	f["from_positions"] = [1, 2]
	negatives.append(["wrong from_positions", f])
	f = authentic_dive.duplicate(true)
	f["to_positions"] = [1]
	negatives.append(["wrong to_positions [1]", f])
	f = authentic_dive.duplicate(true)
	f["to_positions"] = [1, 2]
	negatives.append(["wrong to_positions [1, 2]", f])
	f = authentic_dive.duplicate(true)
	f["to_positions"] = [3]
	negatives.append(["wrong to_positions [3]", f])
	f = authentic_peck.duplicate(true)
	f["to_positions"] = []
	negatives.append(["empty to_positions", f])

	# Wrong damage
	f = authentic_dive.duplicate(true)
	f["effects"]["damage"] = 4
	negatives.append(["wrong Dive damage 4", f])
	f = authentic_dive_plus.duplicate(true)
	f["effects"]["damage"] = 3
	negatives.append(["wrong Dive+ damage 3", f])
	f = authentic_peck.duplicate(true)
	f["effects"]["damage"] = 3
	negatives.append(["wrong Peck damage 3", f])
	f = authentic_peck_plus.duplicate(true)
	f["effects"]["damage"] = 7
	negatives.append(["wrong Peck+ damage 7", f])
	f = authentic_dive.duplicate(true)
	f["effects"]["damage"] = "3"
	negatives.append(["string damage", f])
	f = authentic_dive.duplicate(true)
	f["effects"].erase("damage")
	negatives.append(["missing damage", f])

	# Extra effects
	f = authentic_dive.duplicate(true)
	f["effects"]["bleed"] = 1
	negatives.append(["extra effect bleed", f])
	f = authentic_dive.duplicate(true)
	f["effects"]["block"] = 4
	negatives.append(["extra effect block", f])
	f = authentic_peck.duplicate(true)
	f["effects"]["weak"] = 1
	negatives.append(["extra effect weak", f])

	# Forged ID
	f = authentic_dive.duplicate(true)
	f["id"] = "scarecrow_crow_scratch"
	negatives.append(["forged ID scarecrow_crow_scratch", f])
	f = authentic_dive.duplicate(true)
	f["id"] = "scarecrow_crow_dive_forged"
	negatives.append(["forged ID scarecrow_crow_dive_forged", f])
	f = authentic_peck.duplicate(true)
	f["id"] = "warden_crow_peck"
	negatives.append(["forged ID warden_crow_peck", f])

	# Broken upgrade links
	f = authentic_dive.duplicate(true)
	f["upgrade_id"] = "scarecrow_crow_dive"
	negatives.append(["upgrade self loop", f])
	f = authentic_dive.duplicate(true)
	f["upgrade_id"] = "scarecrow_crow_peck_plus"
	negatives.append(["wrong upgrade link", f])
	f = authentic_dive.duplicate(true)
	f.erase("upgrade_id")
	negatives.append(["base missing upgrade_id", f])
	f = authentic_dive.duplicate(true)
	f["upgrade_of"] = "scarecrow_crow_dive"
	negatives.append(["base has upgrade_of", f])
	f = authentic_dive_plus.duplicate(true)
	f["upgrade_id"] = "scarecrow_crow_dive_plus_plus"
	negatives.append(["plus has upgrade_id", f])
	f = authentic_dive_plus.duplicate(true)
	f.erase("upgrade_of")
	negatives.append(["plus missing upgrade_of", f])
	f = authentic_peck_plus.duplicate(true)
	f["upgrade_id"] = "scarecrow_crow_peck_plus_plus"
	negatives.append(["peck plus has upgrade_id", f])
	f = authentic_peck_plus.duplicate(true)
	f["upgrade_of"] = "scarecrow_crow_dive"
	negatives.append(["peck plus wrong upgrade_of", f])

	# Detached canonical field-set negative probes: deleted/changed display_name,
	# changed reward_eligible or rarity, extra top-level field, changed illustration,
	# or changed starting copies must all fail authentication and produce no Help row.
	f = authentic_dive.duplicate(true)
	f.erase("display_name")
	negatives.append(["deleted display_name on dive", f])
	f = authentic_dive.duplicate(true)
	f["display_name"] = "Crow Strike"
	negatives.append(["changed display_name on dive", f])
	f = authentic_peck.duplicate(true)
	f.erase("display_name")
	negatives.append(["deleted display_name on peck", f])
	f = authentic_peck.duplicate(true)
	f["display_name"] = "Peck"
	negatives.append(["changed display_name on peck", f])
	f = authentic_dive.duplicate(true)
	f["reward_eligible"] = true
	negatives.append(["changed reward_eligible on dive", f])
	f = authentic_peck.duplicate(true)
	f["reward_eligible"] = false
	negatives.append(["changed reward_eligible on peck", f])
	f = authentic_peck.duplicate(true)
	f["rarity"] = "rare"
	negatives.append(["changed rarity on peck", f])
	f = authentic_peck.duplicate(true)
	f.erase("rarity")
	negatives.append(["deleted rarity on peck", f])
	f = authentic_dive.duplicate(true)
	f["rarity"] = "common"
	negatives.append(["extra rarity on dive", f])
	f = authentic_dive.duplicate(true)
	f["unexpected_top_level_field"] = "forged"
	negatives.append(["extra top-level field on dive", f])
	f = authentic_peck.duplicate(true)
	f["forged_flag"] = true
	negatives.append(["extra top-level field on peck", f])
	f = authentic_dive.duplicate(true)
	f["illustration_path"] = "res://other.png"
	negatives.append(["changed illustration_path on dive", f])
	f = authentic_dive.duplicate(true)
	f["starting_copies"] = 2
	negatives.append(["changed starting_copies on dive", f])
	f = authentic_peck.duplicate(true)
	f["starting_copies"] = 1
	negatives.append(["changed starting_copies on peck", f])

	for case_entry in negatives:
		var label: String = case_entry[0]
		var bad: Dictionary = case_entry[1]
		var bad_before := bad.duplicate(true)
		_check(not CardShortRules.is_authored_block_pierce(bad),
			"is_authored_block_pierce returns false for %s" % label)
		_check(not CardShortRules.is_authored_crow(bad),
			"is_authored_crow returns false for %s" % label)
		var bad_rows := CardKeywordGlossary.describe(bad)
		_check(not _row_names(bad_rows).has("Pierce Block"),
			"no Pierce Block row for %s" % label)
		if (bad.get("effects", {}) as Dictionary).has("ignore_block"):
			_check(CardShortRules.has_unknown(bad),
				"has_unknown returns true when unauthorized card carries ignore_block for %s" % label)
			var bad_line := CardShortRules.line(bad)
			_check(not bad_line.contains("Pierce Block"),
				"no Pierce Block on face for %s" % label)
			_check(bad_line.contains("Other authored effects are not described."),
				"unknown effect fallback on face for %s" % label)
		_check(bad == bad_before, "negative fixture %s is not mutated" % label)

	# Verify authentic catalog records are unchanged after negative probes
	_check(starter.get_definition("scarecrow_crow_dive") == authentic_dive
		and starter.get_definition("scarecrow_crow_dive_plus") == authentic_dive_plus
		and pool.get_definition("scarecrow_crow_peck") == authentic_peck
		and pool.get_definition("scarecrow_crow_peck_plus") == authentic_peck_plus,
		"authentic Scarecrow crow catalog records remain immutable")


## Genuine catalog tests asserting that every authentic Seamstress Tether card
## (starter Tether Loop base/plus and pool Tether Stitch base/plus) produces exactly
## one Help row titled Tether, whose explanation matches CardKeywordGlossary.TETHER_EXPLANATION,
## formats face text matching CardShortRules.TETHER_SENTENCE, reports not has_unknown(),
## and satisfies CardShortRules.is_authored_tether(). Also asserts detached row results,
## immutable catalog records, and fail-closed negative space.
func _tether_catalog_test(starter: V3SeamstressStarterCards, pool: V3SeamstressPoolCards) -> void:
	var cases := [
		{"catalog": starter, "id": "seamstress_v3_tether_loop", "cost": 2, "upgrades_to": "seamstress_v3_tether_loop_plus"},
		{"catalog": starter, "id": "seamstress_v3_tether_loop_plus", "cost": 1, "upgrades_to": ""},
		{"catalog": pool, "id": "seamstress_v3_tether_stitch", "cost": 2, "upgrades_to": "seamstress_v3_tether_stitch_plus"},
		{"catalog": pool, "id": "seamstress_v3_tether_stitch_plus", "cost": 1, "upgrades_to": ""},
	]
	for case: Dictionary in cases:
		var catalog: Variant = case["catalog"]
		var card_id: String = String(case["id"])
		var authored_cost: int = int(case["cost"])
		_check(catalog.has_card(card_id), "Tether card present in catalog " + card_id)
		if not catalog.has_card(card_id):
			continue
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty() and definition.get("id") == card_id,
			"actual Tether catalog definition " + card_id)
		if definition.is_empty():
			continue
		var original: Dictionary = definition.duplicate(true)
		var effects: Dictionary = definition.get("effects", {})
		_check(effects.get("tether_share_percent") == 50,
			"authored tether_share_percent 50 for %s" % card_id)
		_check(String(definition.get("owner", "")) == "seamstress"
			and int(definition.get("cost", -1)) == authored_cost
			and String(definition.get("target_kind", "")) == "enemy_pair"
			and Array(definition.get("from_positions", [])) == [2, 3]
			and Array(definition.get("to_positions", [])) == [1, 2, 3],
			"authored owner, cost, target and positions for " + card_id)
		_check(CardShortRules.is_authored_tether(definition),
			"CardShortRules authenticates tether " + card_id)
		_check(not CardShortRules.has_unknown(definition),
			"CardShortRules reports no unknown effects for authentic " + card_id)
		var face: String = CardShortRules.line(definition)
		_check(face == CardShortRules.TETHER_SENTENCE,
			"face text exact match for %s: '%s'" % [card_id, face])
		var rows := CardKeywordGlossary.describe(definition)
		var names := _row_names(rows)
		_check(names == [CardKeywordGlossary.TETHER_KEYWORD],
			"exactly one Tether row for %s (got %s)" % [card_id, str(names)])
		if names != [CardKeywordGlossary.TETHER_KEYWORD]:
			continue
		_check(rows[0]["keyword"] == CardKeywordGlossary.TETHER_KEYWORD,
			"keyword name matches TETHER_KEYWORD for " + card_id)
		_check(rows[0]["explanation"] == CardKeywordGlossary.TETHER_EXPLANATION,
			"explanation exact match for " + card_id)
		var text := str(rows[0]["explanation"])
		_check(text.contains("links two distinct living enemies"),
			"Tether Help mentions linking two distinct living enemies: " + card_id)
		_check(text.contains("deals zero immediate damage on play"),
			"Tether Help mentions zero immediate damage: " + card_id)
		_check(text.contains("later confirmed hit against either linked enemy causes positive HP loss"),
			"Tether Help mentions later confirmed hit with positive HP loss: " + card_id)
		_check(text.contains("half of that HP loss (50%, rounded down) is echoed as raw damage to the other linked living enemy"),
			"Tether Help mentions half echoed as raw damage: " + card_id)
		_check(text.contains("recipient's Block absorbing before HP"),
			"Tether Help mentions recipient's Block absorbing before HP: " + card_id)
		_check(text.contains("wholly absorbed by Block, there is no echo"),
			"Tether Help mentions wholly absorbed -> no echo: " + card_id)
		_check(text.contains("not a separate card attack and cannot trigger another echo, status, Thorns or Riposte"),
			"Tether Help mentions echo trigger constraints: " + card_id)
		_check(text.contains("explains the authored rules helper; it does not specify link lifetime or claim live hand wiring for Tether Stitch"),
			"Tether Help contains scope and live disclaimer: " + card_id)
		_check(definition == original and catalog.get_definition(card_id) == original,
			"Tether Help never mutates catalog definition: " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"Tether Help stays deterministic for " + card_id)
		rows[0]["keyword"] = "Tampered"
		rows[0]["explanation"] = "Tampered"
		var fresh := CardKeywordGlossary.describe(definition)
		_check(_row_names(fresh) == [CardKeywordGlossary.TETHER_KEYWORD] and definition == original,
			"Tether Help results are detached from caller definition: " + card_id)

	var authentic_loop: Dictionary = starter.get_definition("seamstress_v3_tether_loop")
	var authentic_loop_plus: Dictionary = starter.get_definition("seamstress_v3_tether_loop_plus")
	var authentic_stitch: Dictionary = pool.get_definition("seamstress_v3_tether_stitch")
	var authentic_stitch_plus: Dictionary = pool.get_definition("seamstress_v3_tether_stitch_plus")

	var negatives: Array = []

	# Cost tampered
	var f := authentic_loop.duplicate(true)
	f["cost"] = 0
	negatives.append(["wrong loop cost 0", f])
	f = authentic_loop.duplicate(true)
	f["cost"] = 1
	negatives.append(["wrong loop cost 1", f])
	f = authentic_loop.duplicate(true)
	f["cost"] = 3
	negatives.append(["wrong loop cost 3", f])
	f = authentic_loop.duplicate(true)
	f["cost"] = "2"
	negatives.append(["string loop cost", f])
	f = authentic_loop_plus.duplicate(true)
	f["cost"] = 2
	negatives.append(["wrong loop+ cost 2", f])
	f = authentic_loop_plus.duplicate(true)
	f["cost"] = 0
	negatives.append(["wrong loop+ cost 0", f])
	f = authentic_stitch.duplicate(true)
	f["cost"] = 1
	negatives.append(["wrong stitch cost 1", f])
	f = authentic_stitch.duplicate(true)
	f["cost"] = 3
	negatives.append(["wrong stitch cost 3", f])
	f = authentic_stitch_plus.duplicate(true)
	f["cost"] = 2
	negatives.append(["wrong stitch+ cost 2", f])
	f = authentic_stitch_plus.duplicate(true)
	f["cost"] = 0
	negatives.append(["wrong stitch+ cost 0", f])

	# from_positions tampered
	f = authentic_loop.duplicate(true)
	f["from_positions"] = [1, 2, 3]
	negatives.append(["wrong loop from_positions [1, 2, 3]", f])
	f = authentic_loop.duplicate(true)
	f["from_positions"] = [1]
	negatives.append(["wrong loop from_positions [1]", f])
	f = authentic_loop.duplicate(true)
	f["from_positions"] = []
	negatives.append(["empty loop from_positions", f])
	f = authentic_stitch.duplicate(true)
	f["from_positions"] = [3]
	negatives.append(["wrong stitch from_positions [3]", f])

	# to_positions tampered
	f = authentic_loop.duplicate(true)
	f["to_positions"] = [1, 2]
	negatives.append(["wrong loop to_positions [1, 2]", f])
	f = authentic_loop.duplicate(true)
	f["to_positions"] = []
	negatives.append(["empty loop to_positions", f])
	f = authentic_stitch.duplicate(true)
	f["to_positions"] = [1]
	negatives.append(["wrong stitch to_positions [1]", f])
	f = authentic_stitch.duplicate(true)
	f["to_positions"] = [1, 2, 3, 4]
	negatives.append(["wrong stitch to_positions [1, 2, 3, 4]", f])

	# target_kind tampered
	f = authentic_loop.duplicate(true)
	f["target_kind"] = "enemy_single"
	negatives.append(["wrong target enemy_single", f])
	f = authentic_loop.duplicate(true)
	f["target_kind"] = "enemy_first_two"
	negatives.append(["wrong target enemy_first_two", f])
	f = authentic_loop.duplicate(true)
	f["target_kind"] = "enemy_all"
	negatives.append(["wrong target enemy_all", f])
	f = authentic_loop.duplicate(true)
	f["target_kind"] = "self"
	negatives.append(["wrong target self", f])
	f = authentic_stitch.duplicate(true)
	f["target_kind"] = "ally_single"
	negatives.append(["wrong target ally_single", f])
	f = authentic_stitch.duplicate(true)
	f.erase("target_kind")
	negatives.append(["missing target_kind", f])

	# owner tampered
	f = authentic_loop.duplicate(true)
	f["owner"] = "warden"
	negatives.append(["wrong owner warden", f])
	f = authentic_stitch.duplicate(true)
	f["owner"] = "tinker"
	negatives.append(["wrong owner tinker", f])
	f = authentic_loop.duplicate(true)
	f.erase("owner")
	negatives.append(["missing owner", f])

	# effects tampered: tether_share_percent != 50, float/string/null/bool, missing, extra effects
	f = authentic_loop.duplicate(true)
	f["effects"]["tether_share_percent"] = 40
	negatives.append(["tether_share_percent 40", f])
	f = authentic_loop.duplicate(true)
	f["effects"]["tether_share_percent"] = 100
	negatives.append(["tether_share_percent 100", f])
	f = authentic_loop.duplicate(true)
	f["effects"]["tether_share_percent"] = 50.0
	negatives.append(["float tether_share_percent", f])
	f = authentic_loop.duplicate(true)
	f["effects"]["tether_share_percent"] = "50"
	negatives.append(["string tether_share_percent", f])
	f = authentic_loop.duplicate(true)
	f["effects"]["tether_share_percent"] = null
	negatives.append(["null tether_share_percent", f])
	f = authentic_loop.duplicate(true)
	f["effects"]["tether_share_percent"] = true
	negatives.append(["bool tether_share_percent", f])
	f = authentic_loop.duplicate(true)
	f["effects"].erase("tether_share_percent")
	negatives.append(["missing tether_share_percent", f])
	f = authentic_loop.duplicate(true)
	f["effects"]["damage"] = 3
	negatives.append(["extra effect damage", f])
	f = authentic_loop.duplicate(true)
	f["effects"]["bleed"] = 2
	negatives.append(["extra effect bleed", f])
	f = authentic_stitch.duplicate(true)
	f["effects"]["block"] = 4
	negatives.append(["extra effect block", f])
	f = authentic_stitch.duplicate(true)
	f["effects"]["weak"] = 1
	negatives.append(["extra effect weak", f])

	# Forged card IDs
	f = authentic_loop.duplicate(true)
	f["id"] = "seamstress_v3_tether_forged"
	negatives.append(["forged ID seamstress_v3_tether_forged", f])
	f = authentic_loop.duplicate(true)
	f["id"] = "warden_tether_loop"
	negatives.append(["forged ID warden_tether_loop", f])
	f = authentic_stitch.duplicate(true)
	f["id"] = "seamstress_tether_stitch"
	negatives.append(["forged ID seamstress_tether_stitch", f])
	f = authentic_stitch.duplicate(true)
	f["id"] = "seamstress_v3_tether_knot"
	negatives.append(["forged ID seamstress_v3_tether_knot", f])

	# Broken upgrade links
	f = authentic_loop.duplicate(true)
	f["upgrade_id"] = "seamstress_v3_tether_loop"
	negatives.append(["loop upgrade self loop", f])
	f = authentic_loop.duplicate(true)
	f["upgrade_id"] = "seamstress_v3_tether_stitch_plus"
	negatives.append(["loop wrong upgrade link", f])
	f = authentic_loop.duplicate(true)
	f.erase("upgrade_id")
	negatives.append(["loop missing upgrade_id", f])
	f = authentic_loop.duplicate(true)
	f["upgrade_of"] = "seamstress_v3_tether_loop"
	negatives.append(["loop base has upgrade_of", f])
	f = authentic_loop_plus.duplicate(true)
	f["upgrade_id"] = "seamstress_v3_tether_loop_plus_plus"
	negatives.append(["loop+ has upgrade_id", f])
	f = authentic_loop_plus.duplicate(true)
	f.erase("upgrade_of")
	negatives.append(["loop+ missing upgrade_of", f])
	f = authentic_stitch.duplicate(true)
	f["upgrade_id"] = "seamstress_v3_tether_stitch"
	negatives.append(["stitch upgrade self loop", f])
	f = authentic_stitch.duplicate(true)
	f.erase("upgrade_id")
	negatives.append(["stitch missing upgrade_id", f])
	f = authentic_stitch_plus.duplicate(true)
	f["upgrade_id"] = "seamstress_v3_tether_stitch_plus_plus"
	negatives.append(["stitch+ has upgrade_id", f])
	f = authentic_stitch_plus.duplicate(true)
	f["upgrade_of"] = "seamstress_v3_tether_loop"
	negatives.append(["stitch+ wrong upgrade_of", f])

	# Detached canonical field-set negative probes
	f = authentic_loop.duplicate(true)
	f.erase("display_name")
	negatives.append(["deleted display_name on loop", f])
	f = authentic_loop.duplicate(true)
	f["display_name"] = "Tether"
	negatives.append(["changed display_name on loop", f])
	f = authentic_stitch.duplicate(true)
	f.erase("display_name")
	negatives.append(["deleted display_name on stitch", f])
	f = authentic_stitch.duplicate(true)
	f["display_name"] = "Stitch"
	negatives.append(["changed display_name on stitch", f])
	f = authentic_loop.duplicate(true)
	f["reward_eligible"] = true
	negatives.append(["changed reward_eligible on loop", f])
	f = authentic_stitch.duplicate(true)
	f["reward_eligible"] = false
	negatives.append(["changed reward_eligible on stitch", f])
	f = authentic_stitch.duplicate(true)
	f["rarity"] = "rare"
	negatives.append(["changed rarity on stitch", f])
	f = authentic_stitch.duplicate(true)
	f.erase("rarity")
	negatives.append(["deleted rarity on stitch", f])
	f = authentic_loop.duplicate(true)
	f["rarity"] = "common"
	negatives.append(["extra rarity on loop", f])
	f = authentic_loop.duplicate(true)
	f["unexpected_field"] = "tampered"
	negatives.append(["extra top-level field on loop", f])
	f = authentic_stitch.duplicate(true)
	f["forged_flag"] = true
	negatives.append(["extra top-level field on stitch", f])
	f = authentic_loop.duplicate(true)
	f["illustration_path"] = "res://other.png"
	negatives.append(["changed illustration_path on loop", f])
	f = authentic_loop.duplicate(true)
	f["starting_copies"] = 2
	negatives.append(["changed starting_copies on loop", f])
	f = authentic_stitch.duplicate(true)
	f["starting_copies"] = 1
	negatives.append(["changed starting_copies on stitch", f])

	for case_entry in negatives:
		var label: String = case_entry[0]
		var bad: Dictionary = case_entry[1]
		var bad_before := bad.duplicate(true)
		_check(not CardShortRules.is_authored_tether(bad),
			"is_authored_tether returns false for %s" % label)
		var bad_rows := CardKeywordGlossary.describe(bad)
		_check(not _row_names(bad_rows).has(CardKeywordGlossary.TETHER_KEYWORD),
			"no Tether row for %s" % label)
		if (bad.get("effects", {}) as Dictionary).has("tether_share_percent"):
			_check(CardShortRules.has_unknown(bad),
				"has_unknown returns true when unauthorized card carries tether_share_percent for %s" % label)
			var bad_line := CardShortRules.line(bad)
			_check(not bad_line.contains(CardShortRules.TETHER_SENTENCE),
				"no Tether sentence on face for %s" % label)
			_check(bad_line.contains("Other authored effects are not described."),
				"unknown effect fallback on face for %s" % label)
		_check(bad == bad_before, "negative fixture %s is not mutated" % label)

	# Verify authentic catalog records are unchanged after negative probes
	_check(starter.get_definition("seamstress_v3_tether_loop") == authentic_loop
		and starter.get_definition("seamstress_v3_tether_loop_plus") == authentic_loop_plus
		and pool.get_definition("seamstress_v3_tether_stitch") == authentic_stitch
		and pool.get_definition("seamstress_v3_tether_stitch_plus") == authentic_stitch_plus,
		"authentic Seamstress tether catalog records remain immutable")


func _help_in_fixture(fixture: Dictionary, kind: String) -> void:
	var receipt: Dictionary = fixture["receipt"]
	if not receipt.get("ok", false):
		return
	var slot := -1
	for i in range(3):
		var definition := RunPoolCardRewardOffers.resolve_reward_definition(receipt["offers"][i]["id"])
		if not CardKeywordGlossary.describe(definition).is_empty():
			slot = i
			break
	_check(slot >= 0, "seeded %s receipt really contains a keyword offer" % kind)
	if slot < 0:
		return
	var node_id := "reward_%s" % kind.to_lower()
	_check(panel.open_rewards(node_id, kind, receipt), "mounted genuine %s receipt" % kind)
	await _frames()
	if not panel.has_open_rewards():
		return
	var before := _snapshot(fixture)
	var buttons := panel.get_choice_buttons()
	_check(buttons.size() == 4 and panel.choices_container.get_child_count() == 3,
		"mounted three authored choices and Skip")
	var card := panel.choices_container.get_child(slot) as PanelContainer
	var help := card.get_node_or_null("CardMargin/CardContent/CardHeader/HelpButton") as Button
	_check(help != null and help.text == "Details" and help.focus_mode == Control.FOCUS_ALL,
		"keyword offer gets styled Help control")
	if help == null:
		panel.close_rewards()
		return
	_check(help.get_theme_stylebox("normal") is StyleBoxFlat
		and help.get_node_or_null("FocusStitch") != null, "Help has sewn button/focus style")
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	var choose := card.get_node("CardMargin/CardContent/ChooseButton") as Button
	_check(screen.encloses(help.get_global_rect())
		and card.get_global_rect().encloses(help.get_global_rect()),
		"Help tab lies inside its card and the 1280x720 screen")
	_check(not help.get_global_rect().intersects(choose.get_global_rect()),
		"Help tab cannot cover Choose input geometry")
	var old_generation := panel._generation
	var old_pressed: Callable = help.pressed.get_connections()[0]["callable"]
	await _mouse(help)
	var overlay := panel.get_node_or_null("KeywordHelpOverlay") as PanelContainer
	_check(overlay != null and panel._help_overlay == overlay, "actual mouse opens in-panel Help")
	if overlay == null:
		panel.close_rewards()
		return
	_check(overlay.get_theme_stylebox("panel") is StyleBoxFlat,
		"parchment/felt popup styled, not default grey")
	_check(screen.encloses(overlay.get_global_rect())
		and not overlay.get_global_rect().intersects(panel.skip_button.get_global_rect()),
		"Help popup fits 1280x720 and leaves Skip unobscured")
	var definition := RunPoolCardRewardOffers.resolve_reward_definition(receipt["offers"][slot]["id"])
	var title := overlay.get_node("HelpContent/HelpTitle") as Label
	_check(title.text.contains(definition["display_name"]) and not title.text.contains("_"),
		"popup uses current authored human card name")
	var list := overlay.get_node("HelpContent/KeywordScroll/DetailBody/KeywordLines") as VBoxContainer
	var entries := CardKeywordGlossary.describe(definition)
	_check(list.get_child_count() == entries.size() and entries.size() > 0,
		"only matching offered keywords in popup")
	for i in range(entries.size()):
		var label := list.get_child(i) as Label
		_check(label.text.contains(entries[i]["keyword"])
			and label.text.contains(entries[i]["explanation"]),
			"full readable explanation for actual %s keyword %d" % [kind, i])
	var close := overlay.get_node("HelpContent/CloseHelpButton") as Button
	_check(close.has_focus(), "mouse Help opens focused Close")
	_check(screen.encloses(close.get_global_rect())
		and overlay.get_global_rect().encloses(close.get_global_rect()),
		"Close help is visible within felt popup and viewport")
	_check(_snapshot(fixture) == before and requests.is_empty()
		and not panel._awaiting_ack and not panel._accepted,
		"mouse inspection preserves RNG/receipt/deck/wallet/models and emits nothing")
	# Headless dummy rendering has no readable viewport texture; inspect the
	# mounted 1280x720 layout without writing PNG or art files.
	_check(root.size == Vector2i(1280, 720) and overlay.is_visible_in_tree()
		and overlay.get_global_rect().has_point(root.size * 0.5),
		"reward/help overlay is visible in the actual 1280x720 viewport")
	await _key(KEY_ESCAPE)
	_check(panel._help_overlay == null and help.has_focus(),
		"Escape closes and restores invoking Help focus")
	buttons[slot].grab_focus()
	await _key(KEY_RIGHT)
	_check(help.has_focus(), "keyboard-only Right from Choose focuses its own Help")
	await _key(KEY_ENTER)
	_check(panel._help_overlay != null, "keyboard Enter reopens focused Help")
	await _frames()
	var close_two := panel._help_overlay.get_node("HelpContent/CloseHelpButton") as Button
	await _key(KEY_SPACE)
	_check(panel._help_overlay == null and help.has_focus(),
		"keyboard Space activates focused Close and returns focus")
	await _key(KEY_ENTER)
	_check(panel._help_overlay != null, "third Help opens for direct mouse Close")
	var close_three := panel._help_overlay.get_node("HelpContent/CloseHelpButton") as Button
	await _mouse(close_three)
	_check(panel._help_overlay == null and help.has_focus(),
		"mouse Close restores Help focus")
	_check(_snapshot(fixture) == before and requests.is_empty(),
		"all inspections remain read-only with zero requests")
	# Inspecting Help may precede a real choice. A user click, never Help,
	# causes exactly one request even if repeated before acknowledgement.
	await _mouse(help)
	var chosen_id: String = receipt["offers"][slot]["id"]
	buttons[slot].pressed.emit()
	buttons[slot].pressed.emit()
	_check(panel._help_overlay == null and requests == [{"node": node_id, "card": chosen_id}],
		"Choose disposes Help and emits exactly one real offer: %s; overlay=%s" % [str(requests), str(panel._help_overlay)])
	_check(panel._awaiting_ack and not panel._accepted, "Choose waits for caller acknowledgement")
	_check(_snapshot(fixture) == before, "Choose request leaves prepared service unclaimed")
	panel.acknowledge(false)
	_check(not buttons[slot].disabled, "rejected request re-enables original offered card")
	await _mouse(help)
	buttons[3].grab_focus()
	await _key(KEY_SPACE)
	_check(panel._help_overlay == null and requests.size() == 2
		and requests[1] == {"node": node_id, "card": ""},
		"Skip dismisses help and emits empty card ID exactly once: %s; overlay=%s" % [str(requests), str(panel._help_overlay)])
	panel.acknowledge(true)
	_check(panel._accepted and buttons.all(func(b: Button) -> bool: return b.disabled),
		"accepted Skip remains latched")
	_check(_snapshot(fixture) == before, "requests and Help leave service, receipt, RNG and models unchanged")
	panel.close_rewards()
	_check(not panel.has_open_rewards() and panel._help_overlay == null,
		"close disposes Help and receipt")
	_check(not panel.open_rewards("", kind, receipt) and panel._help_overlay == null,
		"invalid receipt request cannot display stale Help")
	_check(panel.open_rewards(node_id, kind, receipt), "closed panel can reopen the same genuine receipt")
	await _frames()
	old_pressed.call()
	panel._on_help_pressed(old_generation, node_id, slot, chosen_id, help)
	_check(panel._help_overlay == null and panel._receipt == receipt and not panel._awaiting_ack,
		"stale generation callback cannot reveal prior offer or request")
	_check(requests.size() == 2, "old Help never emits a choice on reopened receipt")
	panel.close_rewards()
	await _frames()


## Genuine authored candidate records: every warden/seamstress base card plus
## only the two special-rule Tinker base cards, so the real weighted selector
## always offers Snip or Ricochet to the Tinker slot. The receipt itself is
## produced by RunFightVictoryRewards.prepare and never edited afterwards.
func _special_candidates() -> Array:
	var special_ids := ["tinker_ricochet", "tinker_snip_the_seam"]
	var candidates: Array = []
	for record: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
		if String(record.get("owner", "")) == "tinker" \
				and not special_ids.has(String(record.get("id", ""))):
			continue
		candidates.append(record)
	return candidates


func _special_slot(receipt: Dictionary) -> int:
	for i in range(3):
		var offered_id: String = String(receipt["offers"][i]["id"])
		if offered_id == "tinker_snip_the_seam" or offered_id == "tinker_ricochet":
			return i
	return -1


## The mounted Help path for a genuinely offered special-rule card: the live
## popup must show the catalog's exact amounts and wording, open by mouse and
## keyboard, and change nothing (no request, RNG, receipt or model mutation).
func _special_help(fixture: Dictionary, slot: int) -> void:
	var receipt: Dictionary = fixture["receipt"]
	if not receipt.get("ok", false):
		return
	var offered_id: String = String(receipt["offers"][slot]["id"])
	var definition := RunPoolCardRewardOffers.resolve_reward_definition(offered_id)
	_check(definition.get("id") == offered_id, "reward resolves authored special card " + offered_id)
	var node_id := "reward_special_%s" % offered_id
	_check(panel.open_rewards(node_id, "Fight", receipt), "mounted genuine %s receipt" % offered_id)
	await _frames()
	if not panel.has_open_rewards():
		return
	var before := _snapshot(fixture)
	var card := panel.choices_container.get_child(slot) as PanelContainer
	var help := card.get_node_or_null("CardMargin/CardContent/CardHeader/HelpButton") as Button
	_check(help != null and help.text == "Details" and help.focus_mode == Control.FOCUS_ALL,
		"%s offer gains an authored Help tab" % offered_id)
	if help == null:
		panel.close_rewards()
		return
	await _mouse(help)
	var overlay := panel.get_node_or_null("KeywordHelpOverlay") as PanelContainer
	_check(overlay != null and panel._help_overlay == overlay,
		"mouse Help opens the %s special-rule popup" % offered_id)
	if overlay == null:
		panel.close_rewards()
		return
	var entries := CardKeywordGlossary.describe(definition)
	var list := overlay.get_node("HelpContent/KeywordScroll/DetailBody/KeywordLines") as VBoxContainer
	_check(entries.size() == 1 and list.get_child_count() == entries.size(),
		"%s Help shows exactly its authored special rule" % offered_id)
	var text := ""
	if list.get_child_count() > 0:
		text = (list.get_child(0) as Label).text
	var effects: Dictionary = definition.get("effects", {})
	if offered_id == "tinker_snip_the_seam":
		var rule: Dictionary = effects.get("conditional_damage", {})
		var empowered: int = int(rule.get("damage", 0))
		_check(text.contains("Deal %d damage" % int(effects.get("damage", 0)))
			and text.contains("%d instead" % empowered)
			and text.contains("Unravelled") and text.contains(" or ")
			and text.contains("current threshold")
			and text.contains("8 normal, 12 elite, 16 boss and rises by 4"),
			"live Snip Help states %d/%d, the OR condition and the current threshold"
				% [int(effects.get("damage", 0)), empowered])
		_check(not text.contains("different enem"),
			"live Snip Help never promises unrelated targets")
	else:
		_check(text.contains("%d separate hits of %d damage each"
				% [int(effects.get("hit_count", 0)), int(effects.get("damage", 0))])
			and text.contains("random living enemy") and text.contains("seeded RNG")
			and text.contains("can be hit more than once"),
			"live Ricochet Help states %dx%d, seeded living targets and possible repeats"
				% [int(effects.get("hit_count", 0)), int(effects.get("damage", 0))])
		_check(not text.contains("three different") and not text.contains("different enem"),
			"live Ricochet Help never promises three different enemies")
	_check(_snapshot(fixture) == before and requests.is_empty()
		and not panel._awaiting_ack and not panel._accepted,
		"opening %s Help stays read-only with zero requests" % offered_id)
	await _key(KEY_ESCAPE)
	_check(panel._help_overlay == null and help.has_focus(),
		"Escape closes %s Help and restores its Help tab" % offered_id)
	await _key(KEY_ENTER)
	_check(panel._help_overlay != null, "keyboard Enter reopens %s Help" % offered_id)
	await _key(KEY_ESCAPE)
	_check(panel._help_overlay == null and requests.is_empty(),
		"keyboard closes %s Help without requesting the card" % offered_id)
	panel.close_rewards()
	_check(not panel.has_open_rewards() and panel._help_overlay == null,
		"special Help closes with its receipt")


## Genuine authored candidate records for a constrained three-hero reward: one
## real warden, one real seamstress (Tailor's Trance) and one real tinker
## (Overclock) base card. With exactly one candidate per living hero, the real
## weighted selector must offer each of them once, so both energy cards are found
## by their catalog IDs and never by an offer index.
func _energy_candidates() -> Array:
	var wanted := ["warden_bastion_quilt", "seamstress_tailors_trance", "tinker_overclock"]
	var candidates: Array = []
	for record: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
		if wanted.has(String(record.get("id", ""))):
			candidates.append(record)
	return candidates


func _slot_for(receipt: Dictionary, card_id: String) -> int:
	var offers: Array = receipt.get("offers", [])
	for index in range(offers.size()):
		if String((offers[index] as Dictionary).get("id", "")) == card_id:
			return index
	return -1


## Genuine authored candidate records for a constrained three-hero Fight: exactly
## one real base card per hero, including the real Hemorrhage Hem base record.
## With one candidate per living hero the real weighted selector offers each of
## them once, so the doubling card is found by its catalog ID, never by index.
func _hemorrhage_candidates() -> Array:
	var wanted := ["warden_pinning_jab", "seamstress_hemorrhage_hem", "tinker_spring_trap"]
	var candidates: Array = []
	for record: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
		if wanted.has(String(record.get("id", ""))):
			candidates.append(record)
	return candidates


## The real Fight reward Help tab for base Hemorrhage Hem: the mounted popup must
## state N -> 2N, that zero stays zero and that the ordinary Bleed tick/decrement
## remains, open and close by mouse and keyboard, and change nothing; a real
## Choose and Skip afterwards still work and still claim nothing themselves.
func _hemorrhage_help(fixture: Dictionary) -> void:
	var receipt: Dictionary = fixture["receipt"]
	if not receipt.get("ok", false):
		return
	var card_id := "seamstress_hemorrhage_hem"
	var slot := _slot_for(receipt, card_id)
	_check(slot >= 0, "genuine prepared Fight offers the base Hemorrhage Hem by ID")
	if slot < 0:
		return
	var definition := RunPoolCardRewardOffers.resolve_reward_definition(card_id)
	_check(definition.get("id") == card_id and definition.get("owner") == "seamstress"
		and int(definition.get("cost", -1)) == 2,
		"offered Hemorrhage Hem resolves the authored base record")
	if definition.get("id") != card_id:
		return
	var node_id := "reward_hemorrhage_hem"
	_check(panel.open_rewards(node_id, "Fight", receipt),
		"mounted genuine Hemorrhage Hem receipt")
	await _frames()
	if not panel.has_open_rewards():
		return
	var before := _snapshot(fixture)
	var entries := CardKeywordGlossary.describe(definition)
	_check(entries.size() == 1 and String(entries[0]["keyword"]) == "Bleed doubling",
		"catalog-backed single Bleed doubling row for the offered Hemorrhage Hem")
	var card := panel.choices_container.get_child(slot) as PanelContainer
	var help := card.get_node_or_null(
		"CardMargin/CardContent/CardHeader/HelpButton") as Button
	_check(help != null and help.text == "Details" and help.focus_mode == Control.FOCUS_ALL,
		"offered Hemorrhage Hem gains the real Help tab")
	if help == null or entries.size() != 1:
		panel.close_rewards()
		return
	await _mouse(help)
	var overlay := panel.get_node_or_null("KeywordHelpOverlay") as PanelContainer
	_check(overlay != null and panel._help_overlay == overlay,
		"mouse Help opens the Hemorrhage Hem doubling popup")
	if overlay == null:
		panel.close_rewards()
		return
	var list := overlay.get_node("HelpContent/KeywordScroll/DetailBody/KeywordLines") as VBoxContainer
	_check(list.get_child_count() == 1, "Hemorrhage Hem Help shows exactly its doubling row")
	var text := ""
	if list.get_child_count() > 0:
		text = (list.get_child(0) as Label).text
	_check(text.contains("Bleed doubling")
		and text.contains(String(entries[0]["explanation"])),
		"live Hemorrhage Hem Help repeats the glossary explanation")
	_check(text.contains("Bleed N becomes 2N") and text.contains("stays at 0")
		and text.contains("turn end") and text.contains("decreases by 1")
		and not text.contains("Bleed 2"),
		"live Hemorrhage Hem Help states N -> 2N, zero stays zero and the ordinary tick")
	_check(_snapshot(fixture) == before and requests.is_empty()
		and not panel._awaiting_ack and not panel._accepted,
		"opening Hemorrhage Hem Help changes no receipt, deck, wallet, patches or RNG")
	await _mouse(overlay.get_node("HelpContent/CloseHelpButton") as Button)
	_check(panel._help_overlay == null and help.has_focus(),
		"mouse Close dismisses Hemorrhage Hem Help and restores its tab")
	_check(_snapshot(fixture) == before and requests.is_empty(),
		"closing Hemorrhage Hem Help stays read-only")
	panel.get_choice_buttons()[slot].grab_focus()
	await _key(KEY_RIGHT)
	_check(help.has_focus(), "keyboard Right from Choose reaches Hemorrhage Hem Help")
	await _key(KEY_ENTER)
	_check(panel._help_overlay != null, "keyboard Enter reopens Hemorrhage Hem Help")
	await _key(KEY_ESCAPE)
	_check(panel._help_overlay == null and help.has_focus() and requests.is_empty(),
		"Escape closes Hemorrhage Hem Help without requesting the card")
	_check(_snapshot(fixture) == before, "keyboard Help leaves the prepared receipt unclaimed")
	# Help inspection may precede a real choice; only the choice itself requests.
	var choose := panel.get_choice_buttons()[slot]
	await _mouse(help)
	choose.pressed.emit()
	_check(panel._help_overlay == null and requests == [{"node": node_id, "card": card_id}],
		"Choose after Hemorrhage Hem Help emits exactly one real offer")
	_check(panel._awaiting_ack and not panel._accepted,
		"Hemorrhage Hem Choose waits for caller acknowledgement")
	_check(_snapshot(fixture) == before, "Choose leaves the prepared reward unclaimed")
	panel.acknowledge(false)
	_check(not choose.disabled, "rejected Hemorrhage Hem Choose re-enables the offer")
	var skip := panel.get_choice_buttons()[3]
	await _mouse(help)
	skip.grab_focus()
	await _key(KEY_SPACE)
	_check(panel._help_overlay == null and requests.size() == 2
		and requests[1] == {"node": node_id, "card": ""},
		"Skip dismisses Hemorrhage Hem Help and requests the empty ID once")
	panel.acknowledge(true)
	_check(panel._accepted and skip.disabled, "accepted Hemorrhage Hem Skip stays latched")
	_check(_snapshot(fixture) == before,
		"Help, Choose and Skip leave service, receipt, deck, wallet, patches and RNG unchanged")
	panel.close_rewards()
	_check(not panel.has_open_rewards() and panel._help_overlay == null,
		"Hemorrhage Hem Help closes with its receipt")


## Genuine authored candidate records for a constrained three-hero Fight: exactly
## one real base card per hero, including the real Pin and Pound base record.
## With one candidate per living hero the real weighted selector offers each of
## them once, so the card is found by its catalog ID, never by index.
func _pin_and_pound_candidates() -> Array:
	var wanted := ["warden_pin_and_pound", "seamstress_snag", "tinker_spring_trap"]
	var candidates: Array = []
	for record: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
		if wanted.has(String(record.get("id", ""))):
			candidates.append(record)
	return candidates


## The real Fight reward Help tab for base Pin and Pound: the mounted popup must
## state the sequential same-target two hits, the single different-owner Pinned
## +5 on hit 1 only and that this attack creates no pin, open and close by mouse
## and keyboard, and change nothing (no request, receipt, wallet, deck, model or
## RNG mutation). It ends without emitting any reward choice.
func _pin_and_pound_help(fixture: Dictionary) -> void:
	var receipt: Dictionary = fixture["receipt"]
	if not receipt.get("ok", false):
		return
	var card_id := "warden_pin_and_pound"
	var slot := _slot_for(receipt, card_id)
	_check(slot >= 0, "genuine prepared Fight offers the base Pin and Pound by ID")
	if slot < 0:
		return
	var definition := RunPoolCardRewardOffers.resolve_reward_definition(card_id)
	var effects: Dictionary = definition.get("effects", {})
	_check(definition.get("id") == card_id and definition.get("owner") == "warden"
		and int(definition.get("cost", -1)) == 2
		and definition.get("from_positions") == [1]
		and definition.get("to_positions") == [1, 2, 3]
		and effects == {"damage": 9, "hits": 2},
		"offered Pin and Pound resolves the authored base record")
	if definition.get("id") != card_id:
		return
	var node_id := "reward_pin_and_pound"
	_check(panel.open_rewards(node_id, "Fight", receipt),
		"mounted genuine Pin and Pound receipt")
	await _frames()
	if not panel.has_open_rewards():
		return
	var before := _snapshot(fixture)
	var entries := CardKeywordGlossary.describe(definition)
	_check(entries.size() == 1 and String(entries[0]["keyword"]) == "Two hits",
		"catalog-backed single Two hits row for the offered Pin and Pound")
	var card := panel.choices_container.get_child(slot) as PanelContainer
	var help := card.get_node_or_null(
		"CardMargin/CardContent/CardHeader/HelpButton") as Button
	_check(help != null and help.text == "Details" and help.focus_mode == Control.FOCUS_ALL,
		"offered Pin and Pound gains the real Help tab")
	if help == null or entries.size() != 1:
		panel.close_rewards()
		return
	await _mouse(help)
	var overlay := panel.get_node_or_null("KeywordHelpOverlay") as PanelContainer
	_check(overlay != null and panel._help_overlay == overlay,
		"mouse Help opens the Pin and Pound two-hit popup")
	if overlay == null:
		panel.close_rewards()
		return
	var title := overlay.get_node("HelpContent/HelpTitle") as Label
	_check(title.text.contains("Pin and Pound") and not title.text.contains("_"),
		"Pin and Pound popup uses the authored human card name")
	var list := overlay.get_node("HelpContent/KeywordScroll/DetailBody/KeywordLines") as VBoxContainer
	_check(list.get_child_count() == 1,
		"Pin and Pound Help shows exactly its authored two-hit row")
	var text := ""
	if list.get_child_count() > 0:
		text = (list.get_child(0) as Label).text
	_check(text.contains("Two hits") and text.contains(String(entries[0]["explanation"])),
		"live Pin and Pound Help repeats the glossary explanation")
	_check(text.contains("Costs 2 energy")
		and text.contains("two hits of %d damage each" % int(effects.get("damage", 0)))
		and text.contains("one after the other")
		and text.contains("same originally chosen enemy")
		and text.contains("second hit is skipped"),
		"live Pin and Pound Help states both authored hits and the surviving-target rule")
	_check(text.contains("DIFFERENT hero") and text.contains("+5")
		and text.contains("first hit only") and text.contains("before Weak/Exposed")
		and text.contains("consumed then") and text.contains("same hero does not apply"),
		"live Pin and Pound Help states one different-owner Pinned +5 on hit 1 only")
	_check(text.contains("creates no Pinned token")
		and not text.contains("adds Pinned") and not text.contains("applies Pinned"),
		"live Pin and Pound Help never claims the attack pins its target")
	_check(_snapshot(fixture) == before and requests.is_empty()
		and not panel._awaiting_ack and not panel._accepted,
		"opening Pin and Pound Help changes no receipt, wallet, deck, model or RNG")
	await _mouse(overlay.get_node("HelpContent/CloseHelpButton") as Button)
	_check(panel._help_overlay == null and help.has_focus(),
		"mouse Close dismisses Pin and Pound Help and restores its tab")
	_check(_snapshot(fixture) == before and requests.is_empty(),
		"closing Pin and Pound Help stays read-only")
	panel.get_choice_buttons()[slot].grab_focus()
	await _key(KEY_RIGHT)
	_check(help.has_focus(), "keyboard Right from Choose reaches Pin and Pound Help")
	await _key(KEY_ENTER)
	_check(panel._help_overlay != null, "keyboard Enter reopens Pin and Pound Help")
	await _key(KEY_ESCAPE)
	_check(panel._help_overlay == null and help.has_focus() and requests.is_empty(),
		"Escape closes Pin and Pound Help without requesting the card")
	_check(_snapshot(fixture) == before and not panel._awaiting_ack,
		"keyboard Help leaves the prepared Pin and Pound reward unclaimed and unrequested")
	panel.close_rewards()
	_check(not panel.has_open_rewards() and panel._help_overlay == null,
		"Pin and Pound Help closes with its receipt")


## The real Fight/Elite reward Help tab for the two energy cards: the mounted
## popup must show the authored numbers, open and close by mouse and keyboard,
## and change nothing; a real Choose and Skip afterwards still work.
func _energy_help(fixture: Dictionary, kind: String) -> void:
	var receipt: Dictionary = fixture["receipt"]
	if not receipt.get("ok", false):
		return
	var overclock_slot := _slot_for(receipt, "tinker_overclock")
	var trance_slot := _slot_for(receipt, "seamstress_tailors_trance")
	_check(overclock_slot >= 0 and trance_slot >= 0,
		"genuine prepared %s offers Overclock and Tailor's Trance by ID" % kind)
	if overclock_slot < 0 or trance_slot < 0:
		return
	_check(overclock_slot != trance_slot, "energy offers keep distinct slots " + kind)
	var node_id := "reward_energy_%s" % kind.to_lower()
	_check(panel.open_rewards(node_id, kind, receipt), "mounted genuine energy %s receipt" % kind)
	await _frames()
	if not panel.has_open_rewards():
		return
	var before := _snapshot(fixture)
	for card_id: String in ["tinker_overclock", "seamstress_tailors_trance"]:
		var slot := _slot_for(receipt, card_id)
		var definition := RunPoolCardRewardOffers.resolve_reward_definition(card_id)
		var entries := CardKeywordGlossary.describe(definition)
		var effects: Dictionary = definition.get("effects", {})
		_check(entries.size() == 1 and String(entries[0]["keyword"]) == "Energy tradeoff",
			"catalog-backed single energy row for offered " + card_id)
		var card := panel.choices_container.get_child(slot) as PanelContainer
		var help := card.get_node_or_null("CardMargin/CardContent/CardHeader/HelpButton") as Button
		_check(help != null and help.text == "Details" and help.focus_mode == Control.FOCUS_ALL,
			"%s energy offer gains the real Help tab" % card_id)
		if help == null or entries.size() != 1:
			continue
		await _mouse(help)
		var overlay := panel.get_node_or_null("KeywordHelpOverlay") as PanelContainer
		_check(overlay != null and panel._help_overlay == overlay,
			"mouse Help opens the %s energy popup" % card_id)
		if overlay == null:
			continue
		var list := overlay.get_node("HelpContent/KeywordScroll/DetailBody/KeywordLines") as VBoxContainer
		_check(list.get_child_count() == 1, "%s Help shows exactly its energy row" % card_id)
		var text := ""
		if list.get_child_count() > 0:
			text = (list.get_child(0) as Label).text
		_check(text.contains("Energy tradeoff")
			and text.contains(String(entries[0]["explanation"])),
			"live %s Help repeats the glossary explanation" % card_id)
		if card_id == "tinker_overclock":
			_check(text.contains("Costs %d energy" % int(definition.get("cost", -1)))
				and text.contains("gains %d energy" % int(effects.get("gain_energy", 0)))
				and text.contains("takes %d damage herself" % int(effects.get("self_hp_loss", 0)))
				and text.contains("Block absorbs") and text.contains("torn"),
				"live Overclock Help states its cost, gain and 3 self-damage risk")
		else:
			_check(text.contains("Costs %d energy" % int(definition.get("cost", -1)))
				and text.contains("must be available before the play")
				and text.contains("regains that same %d energy" % int(effects.get("energy", 0)))
				and text.contains("net 0 energy")
				and text.contains("Draws %d cards" % int(effects.get("draw", 0))),
				"live Trance Help states the up-front cost, net 0 refund and exact draws")
		_check(_snapshot(fixture) == before and requests.is_empty()
			and not panel._awaiting_ack and not panel._accepted,
			"inspecting %s Help changes no offer, deck, gold, scraps, party, claim or RNG" % card_id)
		await _key(KEY_ESCAPE)
		_check(panel._help_overlay == null and help.has_focus(),
			"Escape closes %s energy Help and restores its tab" % card_id)
		panel.get_choice_buttons()[slot].grab_focus()
		await _key(KEY_RIGHT)
		_check(help.has_focus(), "keyboard Right from Choose reaches %s energy Help" % card_id)
		await _key(KEY_ENTER)
		_check(panel._help_overlay != null, "keyboard Enter opens %s energy Help" % card_id)
		await _key(KEY_ESCAPE)
		_check(panel._help_overlay == null and help.has_focus()
			and requests.is_empty() and _snapshot(fixture) == before,
			"keyboard closes %s energy Help without requesting the card" % card_id)
	var choose := panel.get_choice_buttons()[overclock_slot]
	await _mouse(panel.choices_container.get_child(overclock_slot).get_node(
		"CardMargin/CardContent/CardHeader/HelpButton") as Button)
	choose.pressed.emit()
	_check(panel._help_overlay == null and requests == [{"node": node_id, "card": "tinker_overclock"}],
		"Choose after energy Help emits exactly one Overclock request")
	_check(panel._awaiting_ack and not panel._accepted,
		"energy Choose waits for caller acknowledgement")
	_check(_snapshot(fixture) == before, "energy Choose leaves the prepared reward unclaimed")
	panel.acknowledge(false)
	_check(not choose.disabled, "rejected energy Choose re-enables the offer")
	var skip := panel.get_choice_buttons()[3]
	await _mouse(panel.choices_container.get_child(trance_slot).get_node(
		"CardMargin/CardContent/CardHeader/HelpButton") as Button)
	skip.grab_focus()
	await _key(KEY_SPACE)
	_check(panel._help_overlay == null and requests.size() == 2
		and requests[1] == {"node": node_id, "card": ""},
		"energy Skip dismisses Help and requests the empty ID once")
	panel.acknowledge(true)
	_check(panel._accepted and skip.disabled, "accepted energy Skip stays latched")
	_check(_snapshot(fixture) == before,
		"energy Help, Choose and Skip leave service, receipt, RNG and models unchanged")
	panel.close_rewards()
	_check(not panel.has_open_rewards() and panel._help_overlay == null,
		"energy Help closes with its receipt")


## A genuine V3 Fight reward prepared through the shipped party admission and
## RunFightVictoryRewards, with exactly one authentic base candidate per living
## hero, so the real weighted selector must offer a real Blind and a real Dodge
## card. The receipt is produced once by prepare() and never edited afterwards.
func _prepared_status_help() -> Dictionary:
	var admitted := RunV3PartyAdmission.admit(["lantern_monk", "rag_duelist", "scarecrow"])
	_check(admitted.get("ok", false) and (admitted.get("party", []) as Array).size() == 3,
		"real V3 party admission accepts lantern_monk, rag_duelist and scarecrow")
	if not admitted.get("ok", false) or (admitted.get("party", []) as Array).size() != 3:
		return {}
	var party := CombatParty.new(admitted["party"])
	var enemies := CombatEnemies.new(_defs(ENEMIES))
	_check(party.is_valid() and enemies.is_valid(), "genuine V3 combat roster is valid")
	var result := CombatBattleResult.new(party, enemies)
	_check(result.get_outcome() == CombatBattleResult.ACTIVE, "V3 combat starts active")
	for slot in range(1, enemies.get_enemies().size() + 1):
		_check(enemies.apply_damage(slot, enemies.get_enemy(slot).get("hp", 0)),
			"kill real enemy to witness V3 victory")
	_check(result.evaluate() == CombatBattleResult.VICTORY, "witnessed V3 victory")
	var wanted_cards := ["lantern_monk_wick_flicker", "rag_duelist_cape_flourish",
		"scarecrow_sack_grin"]
	var candidates: Array = []
	for record: Dictionary in RunPoolCardRewardOffers.get_authored_base_candidates():
		if wanted_cards.has(String(record.get("id", ""))):
			candidates.append(record)
	_check(candidates.size() == 3,
		"the three named authored base cards are real reward candidates")
	var party_ids: Array[String] = []
	for hero_id: String in admitted["hero_ids"]:
		party_ids.append(hero_id)
	var deck: Array[String] = []
	for card_id: String in admitted["deck"]:
		deck.append(card_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18420
	var service := RunFightVictoryRewards.new(result, rng, party_ids, candidates, deck, 97,
		false, ["button_charm", "thread_token"], ["button_charm"])
	var receipt: Dictionary = service.prepare()
	_check(receipt.get("ok", false) and receipt.get("offers", []).size() == 3,
		"genuine prepared V3 status Fight receipt with three offers")
	return {"rng": rng, "deck": deck, "party": party, "enemies": enemies,
		"result": result, "service": service, "receipt": receipt, "wallet": 97,
		"scraps": 0, "trinkets": ["button_charm"]}


## The live Help tab of a genuine V3 reward that offers a real Blind card and a
## real Dodge card: each popup must show exactly the catalog rows with the shipped
## one-shot wording, open by mouse and keyboard, and change nothing.
func _status_help(fixture: Dictionary) -> void:
	var receipt: Dictionary = fixture["receipt"]
	if not receipt.get("ok", false):
		return
	var node_id := "reward_status_help"
	_check(panel.open_rewards(node_id, "Fight", receipt),
		"mounted genuine V3 status receipt")
	await _frames()
	if not panel.has_open_rewards():
		return
	var before := _snapshot(fixture)
	for case: Dictionary in [
			{"id": "lantern_monk_wick_flicker", "keyword": "Blind"},
			{"id": "rag_duelist_cape_flourish", "keyword": "Dodge"}]:
		var card_id: String = String(case["id"])
		var keyword: String = String(case["keyword"])
		var slot := _slot_for(receipt, card_id)
		_check(slot >= 0, "genuine V3 receipt offers " + card_id)
		if slot < 0:
			continue
		var definition := RunPoolCardRewardOffers.resolve_reward_definition(card_id)
		_check(definition.get("id") == card_id,
			"offered card resolves the authored base record " + card_id)
		var entries := CardKeywordGlossary.describe(definition)
		var keyword_rows: Array[Dictionary] = []
		for row: Dictionary in entries:
			if String(row.get("keyword", "")) == keyword:
				keyword_rows.append(row)
		_check(keyword_rows.size() == 1,
			"catalog-backed single %s row for offered %s" % [keyword, card_id])
		var card := panel.choices_container.get_child(slot) as PanelContainer
		var help := card.get_node_or_null(
			"CardMargin/CardContent/CardHeader/HelpButton") as Button
		_check(help != null and help.text == "Details" and help.focus_mode == Control.FOCUS_ALL,
			"offered %s gains the real Help tab" % card_id)
		if help == null or keyword_rows.size() != 1:
			continue
		await _mouse(help)
		var overlay := panel.get_node_or_null("KeywordHelpOverlay") as PanelContainer
		_check(overlay != null and panel._help_overlay == overlay,
			"mouse Help opens the %s popup" % card_id)
		if overlay == null:
			continue
		var list := overlay.get_node("HelpContent/KeywordScroll/DetailBody/KeywordLines") as VBoxContainer
		_check(entries.size() > 0 and list.get_child_count() == entries.size(),
			"%s Help lists exactly its catalog rows" % card_id)
		var shown := ""
		for index in range(list.get_child_count()):
			shown += (list.get_child(index) as Label).text + "\n"
		_check(shown.contains(keyword)
			and shown.contains(String(keyword_rows[0]["explanation"])),
			"live %s Help repeats the glossary explanation" % card_id)
		if keyword == "Blind":
			_check(shown.contains("NEXT attempted attack")
				and shown.contains("spent once on that attempt")
				and shown.contains("multi-hit sequence")
				and not shown.contains("does not yet")
				and not shown.contains("design rule only"),
				"live Blind Help states the shipped consumption, not the old disclaimer")
		else:
			_check(shown.contains("next incoming attack HIT")
				and shown.contains("Warden Guard redirection")
				and shown.contains("skipped or downed target keeps its own")
				and shown.contains("owner-turn end")
				and not shown.contains("does not yet")
				and not shown.contains("not yet apply"),
				"live Dodge Help states the real recipient, one of several hits and expiry")
		_check(_snapshot(fixture) == before and requests.is_empty()
			and not panel._awaiting_ack and not panel._accepted,
			"opening %s Help changes no receipt, deck, wallet, party or RNG" % card_id)
		await _key(KEY_ESCAPE)
		_check(panel._help_overlay == null and help.has_focus(),
			"Escape closes %s Help and restores its tab" % card_id)
	panel.close_rewards()
	_check(not panel.has_open_rewards() and panel._help_overlay == null,
		"status Help closes with its receipt")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_catalog_test()
	var scene := load(SCENE) as PackedScene
	_check(scene != null, "live reward scene loads")
	if scene == null:
		_finish()
		return
	panel = scene.instantiate() as LiveRunCardRewardChoicePanel
	_check(panel != null, "live scene mounts actual reward script")
	if panel == null:
		_finish()
		return
	root.add_child(panel)
	panel.choice_requested.connect(func(n: String, id: String) -> void:
		requests.append({"node": n, "card": id}))
	await _frames()
	for kind in ["Fight", "Elite"]:
		requests.clear()
		# Find a deterministic genuine prepared reward with at least one applicable
		# keyword; never synthesize or replace offer IDs in its receipt.
		var fixture := {}
		for seed_value in range(18203, 18243):
			var candidate := _prepared(kind, seed_value)
			for offer: Dictionary in candidate["receipt"].get("offers", []):
				var definition := RunPoolCardRewardOffers.resolve_reward_definition(offer["id"])
				if not CardKeywordGlossary.describe(definition).is_empty():
					fixture = candidate
					break
			if not fixture.is_empty():
				break
		_check(not fixture.is_empty(), "genuine seeded %s has a keyword reward" % kind)
		if not fixture.is_empty():
			await _help_in_fixture(fixture, kind)
	# A valid starter offer without keyword does not produce a Help tab.
	requests.clear()
	var no_keyword := _prepared("Fight", 4120, false)
	var found := false
	for offset in range(4120, 4260):
		var test_receipt := _prepared("Fight", offset, false)
		for i in range(3):
			if test_receipt["receipt"]["offers"][i]["id"] == "warden_strike":
				no_keyword = test_receipt
				found = true
				break
		if found:
			break
	_check(found, "genuine starter reward eventually offers no-keyword Strike")
	if found and panel.open_rewards("starter_no_help", "Fight", no_keyword["receipt"]):
		await _frames()
		for i in range(3):
			if no_keyword["receipt"]["offers"][i]["id"] == "warden_strike":
				var details := panel.choices_container.get_child(i).get_node_or_null(
					"CardMargin/CardContent/CardHeader/HelpButton") as Button
				_check(details != null and details.text == "Details" and not details.disabled,
					"real mounted no-keyword Strike has its universal Details control")
		_check(requests.is_empty(), "no-keyword Help inspection does not request reward")
		panel.close_rewards()
	# The seeded offered Snip and Ricochet cards now explain their special rule in
	# the same live panel, reachable by mouse and keyboard, without any request.
	requests.clear()
	var mounted: Dictionary = {}
	for seed_value in range(18250, 18290):
		var special := _prepared("Fight", seed_value, true, _special_candidates())
		var slot := _special_slot(special["receipt"])
		_check(slot >= 0, "genuine special receipt offers Snip or Ricochet (seed %d)" % seed_value)
		if slot < 0:
			continue
		var offered_id: String = String(special["receipt"]["offers"][slot]["id"])
		if mounted.has(offered_id):
			continue
		mounted[offered_id] = true
		await _special_help(special, slot)
		if mounted.size() == 2:
			break
	_check(mounted.has("tinker_snip_the_seam") and mounted.has("tinker_ricochet"),
		"seeded Fight rewards really offered both special-rule Tinker cards")
	_check(requests.is_empty(), "special-rule Help never requests a reward")
	# The genuinely prepared Fight and Elite rewards that offer Overclock and
	# Tailor's Trance now explain their authored energy trade in the same panel.
	for kind in ["Fight", "Elite"]:
		requests.clear()
		var energy := _prepared(kind, 18300, true, _energy_candidates())
		var offered_ids: Array[String] = []
		for offer: Dictionary in energy["receipt"].get("offers", []):
			offered_ids.append(String(offer.get("id", "")))
		_check(offered_ids.has("tinker_overclock")
			and offered_ids.has("seamstress_tailors_trance"),
			"constrained %s reward really offers both energy cards" % kind)
		await _energy_help(energy, kind)
		_check(requests.size() == 2, "energy %s Help ends after exactly Choose and Skip" % kind)
		requests.clear()
	# The seeded Fight reward that genuinely offers base Hemorrhage Hem explains
	# its authored Bleed doubling in that same live Help surface.
	requests.clear()
	var hemorrhage := _prepared("Fight", 18360, true, _hemorrhage_candidates())
	var hemorrhage_ids: Array[String] = []
	for offer: Dictionary in hemorrhage["receipt"].get("offers", []):
		hemorrhage_ids.append(String(offer.get("id", "")))
	_check(hemorrhage_ids.has("seamstress_hemorrhage_hem"),
		"constrained Fight reward really offers base Hemorrhage Hem")
	await _hemorrhage_help(hemorrhage)
	_check(requests.size() == 2, "Hemorrhage Hem Help ends after exactly Choose and Skip")
	requests.clear()
	# The genuine Fight reward that offers base Pin and Pound explains its two
	# sequential authored hits in that same live Help surface. Help only: this
	# case must end without emitting any reward choice.
	var pin_and_pound := _prepared("Fight", 18390, true, _pin_and_pound_candidates())
	var pin_ids: Array[String] = []
	for offer: Dictionary in pin_and_pound["receipt"].get("offers", []):
		pin_ids.append(String(offer.get("id", "")))
	_check(pin_ids.has("warden_pin_and_pound"),
		"constrained Fight reward really offers base Pin and Pound")
	await _pin_and_pound_help(pin_and_pound)
	_check(requests.is_empty(), "Pin and Pound Help never requests a reward")
	requests.clear()
	# The genuine V3 reward that offers a real Lantern Monk Blind card and a real
	# Rag Duelist Dodge card explains the shipped one-shot rules in that same live
	# Help surface. Help only: this case ends without emitting any reward choice.
	var status_fixture := _prepared_status_help()
	if not status_fixture.is_empty():
		var status_ids: Array[String] = []
		for offer: Dictionary in status_fixture["receipt"].get("offers", []):
			status_ids.append(String(offer.get("id", "")))
		_check(status_ids.has("lantern_monk_wick_flicker")
			and status_ids.has("rag_duelist_cape_flourish"),
			"constrained V3 Fight reward really offers the Blind and Dodge cards")
		await _status_help(status_fixture)
	_check(requests.is_empty(), "status Help never requests a reward")
	requests.clear()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_reward_keyword_help_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	if is_instance_valid(panel):
		panel.free()
	quit(0 if failures.is_empty() else 1)
