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
	var seamstress := SeamstressPoolCards.new()
	var tinker := TinkerPoolCards.new()
	var starter := StarterCards.new()
	var cases := [
		[warden, "warden_pinning_jab", ["Pinned"], ["DIFFERENT hero", "+5", "before Weak/Exposed", "expires"]],
		[warden, "warden_draw_fire", ["Guarding"], ["position 1", "other heroes", "next turn"]],
		[warden, "warden_counter_stitch", ["Thorns 3"], ["3 damage", "positions 1-2", "next turn"]],
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
	var help := card.get_node_or_null("CardMargin/CardContent/OwnerPatch/HelpCorner/HelpButton") as Button
	_check(help != null and help.text == "Help" and help.focus_mode == Control.FOCUS_ALL,
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
	var list := overlay.get_node("HelpContent/KeywordScroll/KeywordLines") as VBoxContainer
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
	var help := card.get_node_or_null("CardMargin/CardContent/OwnerPatch/HelpCorner/HelpButton") as Button
	_check(help != null and help.text == "Help" and help.focus_mode == Control.FOCUS_ALL,
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
	var list := overlay.get_node("HelpContent/KeywordScroll/KeywordLines") as VBoxContainer
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
		var help := card.get_node_or_null("CardMargin/CardContent/OwnerPatch/HelpCorner/HelpButton") as Button
		_check(help != null and help.text == "Help" and help.focus_mode == Control.FOCUS_ALL,
			"%s energy offer gains the real Help tab" % card_id)
		if help == null or entries.size() != 1:
			continue
		await _mouse(help)
		var overlay := panel.get_node_or_null("KeywordHelpOverlay") as PanelContainer
		_check(overlay != null and panel._help_overlay == overlay,
			"mouse Help opens the %s energy popup" % card_id)
		if overlay == null:
			continue
		var list := overlay.get_node("HelpContent/KeywordScroll/KeywordLines") as VBoxContainer
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
		"CardMargin/CardContent/OwnerPatch/HelpCorner/HelpButton") as Button)
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
		"CardMargin/CardContent/OwnerPatch/HelpCorner/HelpButton") as Button)
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
				_check(panel.choices_container.get_child(i).get_node_or_null("HelpButton") == null,
					"real mounted no-keyword Strike has no Help control")
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
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_reward_keyword_help_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	if is_instance_valid(panel):
		panel.free()
	quit(0 if failures.is_empty() else 1)
