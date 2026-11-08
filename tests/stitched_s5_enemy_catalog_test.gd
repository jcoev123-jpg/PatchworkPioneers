extends SceneTree
## S5 enemy cohort contract: every canonical normal, Elite and boss has one validated Stitched kit
## plus one unique tiered foreign part, the pure loader fails closed on malformed profiles, seeded
## rules replay two/three-foe and boss fights, and the live title Roadblock builds from that roster.
##
## Catalog checks are by required id and source record, never by a catalog total or ordered list.

const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const PHASE_TWO_PATH := "res://data/enemies/m05_behemoth_phase_two.json"
const BOSS_PATH := "res://data/enemies/boss.json"
const ELITE_PATH := "res://data/enemies/m04_elites.json"
const TOUGH_PATH := "res://data/enemies/v3_tough_normals.json"
const SHIPPED_TROPHIES := {
	"scissor_crab_claw_arm": "snip",
	"moth_swarm_wings": "flutter_back",
	"felt_bulwark_button_shield": "button_shield",
	"fray_scavenger_sack_arm": "sack_sweep",
	"moth_scribe_inkbrush_arm": "ink_stroke",
}
const ROADBLOCK_IDS := ["fray_scavenger", "scissor_crab", "moth_scribe"]
const DUPLICATE_IDS := ["spindle_ram", "razor_ribbon_wraith"]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(bool(catalog.get("ok", false)),
		"the canonical S5 roster loads: " + str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		_finish()
		return
	_test_completeness(catalog)
	_test_fray_scavenger_tuning(catalog)
	_test_trophies(catalog)
	_test_fail_closed(catalog)
	_test_seeded_fights(catalog)
	_test_invalid_inputs(catalog)
	_test_spool_kit(catalog)
	var spool_seed := _test_spool_combat(catalog)
	await _test_spool_live_intents(catalog, spool_seed)
	await _test_live_admission(catalog)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_enemy_catalog_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# ---------------------------------------------------------------- AC1 completeness

func _test_completeness(catalog: Dictionary) -> void:
	var raw_by_id: Dictionary = {}
	for entry in StitchedEnemyCatalog.CATALOGS:
		var parsed: Variant = _read_json(str(entry["path"]))
		_check(parsed is Array and not (parsed as Array).is_empty(),
			"canonical catalog parses: " + str(entry["path"]))
		if not parsed is Array:
			continue
		for raw in parsed:
			if not raw is Dictionary:
				_check(false, "canonical enemy is an object: " + str(entry["path"]))
				continue
			var record: Dictionary = raw
			var enemy_id := str(record.get("id", ""))
			if raw_by_id.has(enemy_id):
				_check(raw_by_id[enemy_id] == record,
					"duplicate enemy record agrees: " + enemy_id)
			else:
				raw_by_id[enemy_id] = record
			_check(catalog["enemies"].has(enemy_id),
				"AC1: every canonical enemy resolves a kit: " + enemy_id)
			_check(catalog["foes"].has(enemy_id),
				"AC1: every canonical enemy resolves a StitchedRules foe: " + enemy_id)
			var foe: Dictionary = catalog["foes"].get(enemy_id, {})
			_check(int(foe.get("max_hp", 0)) > 0 and not foe.get("abilities", []).is_empty(),
				"AC1: resolved foe carries real HP and abilities: " + enemy_id)
			_check(not str(catalog["trophies"].get(enemy_id, "")).is_empty(),
				"AC1: every canonical enemy resolves exactly one trophy: " + enemy_id)
	for enemy_id in raw_by_id:
		_check(catalog["enemies"].has(str(enemy_id)),
			"AC1: no stale profile without a canonical record: " + str(enemy_id))
	for duplicate_id in DUPLICATE_IDS:
		var occurrences := 0
		for entry in StitchedEnemyCatalog.CATALOGS:
			var parsed: Variant = _read_json(str(entry["path"]))
			if parsed is Array:
				for raw in parsed:
					if raw is Dictionary and str(raw.get("id", "")) == duplicate_id:
						occurrences += 1
		_check(occurrences == 2, "AC1: the tough normal is still repeated in both catalogs: "
			+ duplicate_id)
	# Boss tier: every boss record takes the authored two-turn exception; Elites never do.
	var bosses: Variant = _read_json(BOSS_PATH)
	var boss_ids: Array = []
	if bosses is Array:
		for raw in bosses:
			if raw is Dictionary:
				boss_ids.append(str(raw["id"]))
	for expected_boss in ["patchwork_behemoth", "sewing_machine_colossus", "moth_queen"]:
		_check(str(expected_boss) in boss_ids,
			"AC1: seed boss is still authored: " + str(expected_boss))
	_check(not boss_ids.is_empty(), "AC1: the boss catalog still authors its seed bosses")
	for boss_id in boss_ids:
		var foe: Dictionary = catalog["foes"].get(str(boss_id), {})
		_check(bool(foe.get("is_boss", false)) and int(foe.get("turns_per_round", 0)) == 2
			and StitchedEnemyCatalog.is_boss(catalog, str(boss_id)),
			"AC1/AC2: boss authors the two-turn exception: " + str(boss_id))
	var elites: Variant = _read_json(ELITE_PATH)
	if elites is Array:
		for raw in elites:
			if not raw is Dictionary:
				continue
			var elite_id := str(raw["id"])
			var foe: Dictionary = catalog["foes"].get(elite_id, {})
			_check(not bool(foe.get("is_boss", true)) and int(foe.get("turns_per_round", 0)) == 1,
				"AC1: Elite keeps one turn and no boss identity: " + elite_id)
	# Behemoth phase two preserves its authored identity and a distinct second kit.
	var phase_record: Variant = _read_json(PHASE_TWO_PATH)
	var kits: Dictionary = catalog.get("phase_two", {})
	_check(kits.has("patchwork_behemoth"), "AC1/AC2: Behemoth resolves an authored phase two")
	if phase_record is Dictionary and kits.has("patchwork_behemoth"):
		var legacy: Dictionary = phase_record
		var intent: Dictionary = legacy.get("intent", {})
		var actions: Array = intent.get("actions", [])
		_check(int(legacy.get("threshold_hp", 0)) == 21
			and int(kits["patchwork_behemoth"]["threshold_hp"]) == 21,
			"AC2: phase two keeps its 21 HP threshold")
		_check(actions.size() >= 6 and int(actions[0].get("amount", 0)) == 40,
			"AC2: phase two keeps its authored heavy legacy actions")
		var phase_two: Array = kits["patchwork_behemoth"]["abilities"]
		var phase_one: Array = catalog["foes"]["patchwork_behemoth"]["abilities"]
		var phase_one_ids: Dictionary = {}
		for ability in phase_one:
			phase_one_ids[str(ability["id"])] = true
		var distinct := 0
		for ability in phase_two:
			if not phase_one_ids.has(str(ability["id"])):
				distinct += 1
		_check(phase_two.size() >= 4 and distinct == phase_two.size(),
			"AC2: every phase-two action is a distinct authored move")


	# The Roadblock's Scissor Crab Pinch is the authored Bleed source the live
	# Peddler loop relies on. Only its Bleed was added; damage, ranks and the
	# sibling action keep their original authored values.
	var crab: Dictionary = catalog["foes"].get("scissor_crab", {})
	var pinch := {}
	var thread_snip := {}
	for ability in crab.get("abilities", []):
		if str(ability.get("id", "")) == "pinch":
			pinch = ability
		elif str(ability.get("id", "")) == "thread_snip":
			thread_snip = ability
	_check(not pinch.is_empty() and int(pinch.get("effects", {}).get("bleed", 0)) == 2
		and pinch.get("dmg") == [3, 6] and pinch.get("launch") == [1, 2, 3]
		and pinch.get("target") == [1, 2] and int(pinch.get("acc", 0)) == 86,
		"AC1: Scissor Crab Pinch authors Bleed 2 with its damage and ranks intact")
	_check(thread_snip.get("effects") == {"snip": 1},
		"AC1: Scissor Crab's other Stitched action is untouched")
	var crab_record := {}
	for entry in StitchedEnemyCatalog.CATALOGS:
		var parsed: Variant = _read_json(str(entry["path"]))
		if parsed is Array:
			for raw in parsed:
				if raw is Dictionary and str(raw.get("id", "")) == "scissor_crab":
					crab_record = raw
	var legacy_actions: Array = crab_record.get("intent", {}).get("actions", [])
	_check(legacy_actions.size() == 4 and int(crab_record.get("max_hp", 0)) == 26
		and int(crab.get("max_hp", 0)) == 22,
		"AC1: Scissor Crab's legacy card intent and both health values are unchanged")


# ---------------------------------------------------------------- AC1 trophies

func _test_trophies(catalog: Dictionary) -> void:
	var seen_ids: Dictionary = {}
	var seen_names: Dictionary = {}
	var seen_abilities: Dictionary = {}
	for enemy_id in catalog["trophies"]:
		var trophy := str(catalog["trophies"][enemy_id])
		_check(not seen_ids.has(trophy), "AC1: trophy is unique to one foe: " + trophy)
		seen_ids[trophy] = true
		var part: Dictionary = catalog["parts_by_id"].get(trophy, {})
		_check(not part.is_empty(), "AC1: trophy resolves in the part catalog: " + trophy)
		if part.is_empty():
			continue
		_check(str(part.get("owner", "")) == "any",
			"AC1: trophy can be worn by any hero: " + trophy)
		_check(str(part.get("slot", "")) in StitchedParts.SLOTS,
			"AC1: trophy fills a real slot: " + trophy)
		_check(not str(part.get("name", "")).is_empty() and not str(part.get("text", "")).is_empty(),
			"AC1: trophy is named and has rules text: " + trophy)
		_check(not seen_names.has(str(part["name"])),
			"AC1: trophy name is unique: " + str(part["name"]))
		seen_names[str(part["name"])] = true
		var tiers: Dictionary = part.get("tiers", {})
		_check(tiers.has("2") and tiers.has("3"),
			"AC1: trophy authors stitch tiers II and III: " + trophy)
		for tier in [1, 2, 3]:
			var ability := StitchedParts.ability_at_tier(part, tier)
			_check(not ability.is_empty()
				and bool(StitchedParts.validate_ability(ability).get("ok", false)),
				"AC1: %s tier %d ability validates" % [trophy, tier])
			var ability_id := str(ability.get("id", ""))
			if tier == 1:
				_check(not seen_abilities.has(ability_id),
					"AC1: trophy ability id is unique: " + ability_id)
				seen_abilities[ability_id] = true
			else:
				_check(ability_id == str(part["ability"]["id"]),
					"AC1: a tier keeps its trophy ability identity: " + trophy)
	for shipped_id in SHIPPED_TROPHIES:
		var shipped: Dictionary = catalog["parts_by_id"].get(shipped_id, {})
		_check(not shipped.is_empty()
			and str(shipped.get("ability", {}).get("id", "")) == expected_ability(shipped_id),
			"AC1: earlier trophy stays authored: " + shipped_id)


func expected_ability(part_id: String) -> String:
	return str(SHIPPED_TROPHIES[part_id])


# ---------------------------------------------------------------- pure loader refusals

func _documents(catalog: Dictionary) -> Array:
	var documents: Array = []
	for entry in StitchedEnemyCatalog.CATALOGS:
		documents.append({
			"path": str(entry["path"]),
			"tier": str(entry["tier"]),
			"entries": (_read_json(str(entry["path"])) as Array).duplicate(true),
		})
	return documents


func _phase_record() -> Dictionary:
	return (_read_json(PHASE_TWO_PATH) as Dictionary).duplicate(true)


func _document(documents: Array, path: String) -> Dictionary:
	for document in documents:
		if str(document["path"]) == path:
			return document
	return {}


func _record(documents: Array, enemy_id: String) -> Dictionary:
	for document in documents:
		for record in document["entries"]:
			if str(record.get("id", "")) == enemy_id:
				return record
	return {}


func _test_fail_closed(catalog: Dictionary) -> void:
	var parts: Array = catalog["parts"]
	# Missing profile.
	var missing := _documents(catalog)
	_record(missing, "ragling").erase("stitched")
	_check(not bool(StitchedEnemyCatalog.build_catalog(missing, _phase_record(), parts).get("ok", true)),
		"AC1: a canonical enemy without a Stitched profile is rejected")
	# Mismatched repeated record.
	var mismatched := _documents(catalog)
	var twin: Dictionary = _record(mismatched, "spindle_ram").duplicate(true)
	twin["max_hp"] = int(twin["max_hp"]) + 1
	(_document(mismatched, "res://data/enemies/v3_tough_normals.json"))["entries"].append(twin)
	_check(not bool(StitchedEnemyCatalog.build_catalog(mismatched, _phase_record(), parts).get("ok", true)),
		"AC1: repeated enemy ids with different records are rejected")
	# Duplicate trophy.
	var shared := _documents(catalog)
	_record(shared, "ragling_guard")["stitched"]["trophy"] = "ragling_tatter_claw"
	_check(not bool(StitchedEnemyCatalog.build_catalog(shared, _phase_record(), parts).get("ok", true)),
		"AC1: two foes cannot share one trophy")
	# Illegal boss and normal turn counts.
	var two_turn_normal := _documents(catalog)
	_record(two_turn_normal, "ragling")["stitched"]["turns_per_round"] = 2
	_check(not bool(StitchedEnemyCatalog.build_catalog(two_turn_normal, _phase_record(), parts).get("ok", true)),
		"AC2: an ordinary foe cannot take two turns")
	var one_turn_boss := _documents(catalog)
	_record(one_turn_boss, "moth_queen")["stitched"]["turns_per_round"] = 1
	_check(not bool(StitchedEnemyCatalog.build_catalog(one_turn_boss, _phase_record(), parts).get("ok", true)),
		"AC2: a boss must author its two-turn exception")
	# Illegal rank and duplicate ability ids.
	var bad_rank := _documents(catalog)
	_record(bad_rank, "ragling")["stitched"]["abilities"][0]["launch"] = [5]
	_check(not bool(StitchedEnemyCatalog.build_catalog(bad_rank, _phase_record(), parts).get("ok", true)),
		"AC2: an illegal launch rank is rejected")
	var repeated_move := _documents(catalog)
	var profile: Dictionary = _record(repeated_move, "ragling")["stitched"]
	profile["abilities"][1]["id"] = str(profile["abilities"][0]["id"])
	_check(not bool(StitchedEnemyCatalog.build_catalog(repeated_move, _phase_record(), parts).get("ok", true)),
		"AC1: one foe cannot repeat an ability id")
	# Phase-two refusals.
	var no_phase: Dictionary = _phase_record()
	no_phase.erase("stitched_phase_two")
	_check(not bool(StitchedEnemyCatalog.build_catalog(_documents(catalog), no_phase, parts).get("ok", true)),
		"AC2: the behemoth phase-two kit is required")
	var repeated_phase: Dictionary = _phase_record()
	repeated_phase["stitched_phase_two"]["abilities"][0]["id"] = "behemoth_maul"
	_check(not bool(StitchedEnemyCatalog.build_catalog(_documents(catalog), repeated_phase, parts).get("ok", true)),
		"AC2: phase two must author distinct actions")
	# An otherwise legal ally-only phase-two kit has no hostile action: the catalog
	# must reject it atomically instead of publishing a passive second phase.
	var ally_only: Dictionary = _phase_record()
	var iron_discipline := {}
	for ability in _record(_documents(catalog), "needle_marshal")["stitched"]["abilities"]:
		if str(ability.get("id", "")) == "iron_discipline":
			iron_discipline = (ability as Dictionary).duplicate(true)
	_check(not iron_discipline.is_empty() and str(iron_discipline.get("target_side", "")) == "ally",
		"AC1: the canonical Needle Marshal authors the valid ally-only iron_discipline")
	ally_only["stitched_phase_two"]["abilities"] = [iron_discipline]
	var ally_result: Dictionary = StitchedEnemyCatalog.build_catalog(_documents(catalog), ally_only, parts)
	_check(not bool(ally_result.get("ok", true)),
		"AC1: an ally-only phase-two kit is rejected by build_catalog")
	_check(ally_result.get("phase_two", {}).is_empty()
		and str(ally_result.get("error", "")).contains("enemy-targeted"),
		"AC1: the rejected phase-two kit publishes no kit and names the hostile-action rule")
	_check(bool(catalog.get("ok", false)) and catalog["foes"].size() > 0,
		"AC1: the real loader still validates after every malformed probe")


# ---------------------------------------------------------------- Fray Scavenger HP tuning

func _test_fray_scavenger_tuning(catalog: Dictionary) -> void:
	var raw: Variant = _read_json("res://data/enemies/run_enemies.json")
	var source: Dictionary = {}
	if raw is Array:
		for entry in raw:
			if entry is Dictionary and str(entry.get("id", "")) == "fray_scavenger":
				source = entry
				break
	_check(not source.is_empty() and int(source.get("max_hp", 0)) == 14
		and int(source.get("stitched", {}).get("max_hp", 0)) == 24,
		"AC1: only the ordinary Fray Scavenger's Stitched HP is tuned; legacy HP remains 14")
	var fray := StitchedEnemyCatalog.foe_for(catalog, "fray_scavenger")
	_check(not fray.is_empty() and int(fray.get("max_hp", 0)) == 24
		and int(fray.get("speed", -1)) == 4 and int(fray.get("prot", -1)) == 4
		and not fray.get("abilities", []).is_empty(),
		"AC1: real enemy loader resolves the tuned 24-HP Stitched foe with its authored kit")
	var first_battle := _battle(catalog, ["fray_scavenger", "ragling"], 6110)
	if first_battle == null:
		_check(false, "AC2: the tuned two-foe seeded fight must be constructible")
		return
	var first_foe := first_battle.get_unit("fray_scavenger")
	_check(first_battle.get_foes().size() == 2 and not first_foe.is_empty()
		and int(first_foe.get("max_hp", 0)) == 24 and int(first_foe.get("hp", 0)) == 24,
		"AC2: a real two-foe ranked battle starts with Fray Scavenger at 24/24 HP")
	var initial_state := first_battle.state_snapshot()
	var first := _auto_play(first_battle, 120)
	var legal_hero_part := false
	var genuine_fray_damage := false
	for receipt in first["receipts"]:
		if not bool(receipt.get("ok", false)) or str(receipt.get("actor_side", "")) != "hero" \
				or str(receipt.get("action", "")) != "ability" or str(receipt.get("part", "")).is_empty():
			continue
		legal_hero_part = true
		for result in receipt.get("results", []):
			if str(result.get("target", "")) == "fray_scavenger" \
					and bool(result.get("hit", false)) and int(result.get("damage", 0)) > 0 \
					and int(result.get("target_hp", 24)) < 24:
				genuine_fray_damage = true
	_check(legal_hero_part and genuine_fray_damage,
		"AC2: an equipped legal hero part lands real damage on the 24-HP Fray Scavenger")
	var replay_battle := _battle(catalog, ["fray_scavenger", "ragling"], 6110)
	if replay_battle == null:
		_check(false, "AC2: matching replay battle must be constructible")
		return
	_check(replay_battle.state_snapshot() == initial_state
		and first == _auto_play(replay_battle, 120) and not first["receipts"].is_empty(),
		"AC2: the same seed and ranked actions replay identical snapshots, RNG and receipts")


# ---------------------------------------------------------------- AC2 seeded rules

func _config(catalog: Dictionary, ids: Array, seed_value: int,
		phases: Dictionary = {}) -> Dictionary:
	var preview: Variant = _read_json(PREVIEW_PATH)
	if not preview is Dictionary:
		return {}
	var config: Dictionary = preview
	var parts: Array = catalog["parts"].duplicate(true)
	parts.append_array(config["parts"])
	var foes: Array = []
	for enemy_id in ids:
		var phase := str(phases.get(str(enemy_id), StitchedEnemyCatalog.PHASE_ONE))
		var foe := StitchedEnemyCatalog.foe_for(catalog, str(enemy_id), phase)
		if foe.is_empty():
			return {}
		foes.append(foe)
	return {
		"mode": "stitched",
		"seed": seed_value,
		"candle": 100,
		"heroes": config["heroes"].duplicate(true),
		"parts": parts,
		"foes": foes,
	}


func _battle(catalog: Dictionary, ids: Array, seed_value: int,
		phases: Dictionary = {}) -> StitchedRules:
	var config := _config(catalog, ids, seed_value, phases)
	if config.is_empty():
		return null
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)),
		"AC2: seeded %d-foe fight builds: %s" % [ids.size(), str(created.get("error", ""))])
	return created.get("battle") if bool(created.get("ok", false)) else null


func _auto_play(battle: StitchedRules, max_steps: int) -> Dictionary:
	var receipts: Array = []
	var rounds := 1
	for step in range(max_steps):
		if battle.is_over():
			break
		var actor_id := battle.current_actor_id()
		var actor := battle.get_unit(actor_id)
		var acted := false
		if battle.current_side() == "hero":
			for slot in StitchedParts.SLOTS:
				if acted:
					break
				var worn: Dictionary = actor.get("parts", {}).get(slot, {})
				if worn.is_empty() or bool(worn.get("torn", false)):
					continue
				var definition: Dictionary = battle._parts.get(str(worn["id"]), {})
				var ability := StitchedParts.ability_at_tier(definition, int(worn["tier"]))
				if ability.is_empty() or not battle._self_move_gate(actor, ability).is_empty():
					continue
				for rank in range(1, 5):
					if battle._legal_targets(actor, ability, rank).is_empty():
						continue
					var receipt := battle.use_part(str(worn["id"]), rank)
					if bool(receipt.get("ok", false)):
						receipts.append(receipt)
						acted = true
					break
		else:
			for ability in actor.get("abilities", []):
				if acted:
					break
				if not battle._self_move_gate(actor, ability).is_empty():
					continue
				for rank in range(1, 5):
					if battle._legal_targets(actor, ability, rank).is_empty():
						continue
					var receipt := battle.use_foe_ability(str(ability["id"]), rank)
					if bool(receipt.get("ok", false)):
						receipts.append(receipt)
						acted = true
					break
		if not acted and not battle.is_over():
			var passed := battle.pass_turn()
			if bool(passed.get("ok", false)):
				receipts.append(passed)
		rounds = battle.round_number()
	return {
		"rounds": rounds,
		"outcome": battle.outcome(),
		"snapshot": battle.state_snapshot(),
		"rng": battle.rng_state(),
		"receipts": receipts.duplicate(true),
	}


func _test_seeded_fights(catalog: Dictionary) -> void:
	# Two-foe front/rear normal fight: a melee rank-1 Ragling and a rear rank-2 Moth Scribe.
	var two := _battle(catalog, ["ragling", "moth_scribe"], 6101)
	if two != null:
		_check(two.get_foes().size() == 2 and two.current_side() == "hero",
			"AC2: seeded two-foe fight starts with living heroes and foes")
		var first := _auto_play(two, 120)
		var replay := _auto_play(_battle(catalog, ["ragling", "moth_scribe"], 6101), 120)
		_check(first == replay, "AC2: seeded two-foe normal fight replays receipts and state")
		_check(int(first["rounds"]) >= 1 and not first["receipts"].is_empty(),
			"AC2: seeded two-foe fight really executes actions")
	# Three-foe Elite fight with real legal ranks.
	var three := _battle(catalog, ["needle_marshal", "spool_hexer", "scissor_bailiff"], 6102)
	if three != null:
		_check(three.get_foes().size() == 3,
			"AC2: seeded three-foe Elite fight admits all three foes")
		var first := _auto_play(three, 140)
		var replay := _auto_play(
			_battle(catalog, ["needle_marshal", "spool_hexer", "scissor_bailiff"], 6102), 140)
		_check(first == replay, "AC2: seeded three-foe Elite fight replays receipts and state")
		_check(int(first["rounds"]) >= 1 and not first["receipts"].is_empty(),
			"AC2: seeded Elite fight really executes authored actions")
		_check(first["outcome"] in ["ongoing", "victory", "defeat"],
			"AC2: seeded Elite fight reaches a real rules outcome, never a mock")
	# Every boss: two turns in the rolled order, authored actions and identical replay.
	for boss_id in ["patchwork_behemoth", "sewing_machine_colossus", "moth_queen"]:
		var boss_battle := _battle(catalog, [str(boss_id), "ragling", "ragling_guard"], 6103)
		if boss_battle == null:
			continue
		var order := boss_battle.turn_order()
		var boss_turns := 0
		for entry in order:
			if str(entry) == str(boss_id):
				boss_turns += 1
		_check(boss_turns == 2 and int(
			boss_battle.get_unit(str(boss_id)).get("turns_per_round", 0)) == 2,
			"AC2: boss takes two turns in the rolled order: " + str(boss_id))
		var first := _auto_play(boss_battle, 160)
		var boss_actions := 0
		for receipt in first["receipts"]:
			if str(receipt.get("actor", "")) == str(boss_id) \
					and str(receipt.get("action", "")) == "ability":
				boss_actions += 1
		_check(boss_actions >= 2,
			"AC2: boss really acts twice before the fight ends: " + str(boss_id))
		var replay := _auto_play(
			_battle(catalog, [str(boss_id), "ragling", "ragling_guard"], 6103), 160)
		_check(first == replay, "AC2: seeded boss fight replays receipts and state: " + str(boss_id))
	# Behemoth phase two: build the actual second kit from the loader and witness its moves.
	var phase := StitchedEnemyCatalog.foe_for(catalog, "patchwork_behemoth", StitchedEnemyCatalog.PHASE_TWO)
	_check(not phase.is_empty() and phase["abilities"].size() >= 4,
		"AC2: the loader publishes the Behemoth phase-two kit")
	if not phase.is_empty():
		var phase_ids := {"patchwork_behemoth": StitchedEnemyCatalog.PHASE_TWO}
		var phase_battle := _battle(
			catalog, ["ragling", "ragling_guard", "patchwork_behemoth"], 6106, phase_ids)
		if phase_battle != null:
			_check(str(phase_battle.get_unit("patchwork_behemoth")["abilities"][0]["id"]) ==
				str(phase["abilities"][0]["id"]),
				"AC2: the phase-two battle really carries the second kit")
			var kit_ids: Dictionary = {}
			for ability in phase["abilities"]:
				kit_ids[str(ability["id"])] = true
			var first := _auto_play(phase_battle, 120)
			var used := 0
			for receipt in first["receipts"]:
				if str(receipt.get("actor", "")) == "patchwork_behemoth" \
						and kit_ids.has(str(receipt.get("ability", ""))):
					used += 1
			_check(used > 0, "AC2: a seeded phase-two Behemoth executes its distinct actions")
			var replay := _auto_play(
				_battle(catalog, ["ragling", "ragling_guard", "patchwork_behemoth"], 6106, phase_ids),
				120)
			_check(first == replay, "AC2: phase-two Behemoth fight replays identically")
	# Statuses and fray are genuinely exercised by the authored kits.
	var status_battle := _battle(catalog, ["pin_skitter", "moth_scribe"], 6107)
	if status_battle != null:
		var seen_status := false
		var seen_fray := false
		for step in range(60):
			if status_battle.is_over() or status_battle.current_side() != "foe":
				if status_battle.is_over():
					break
				status_battle.pass_turn()
				continue
			var actor := status_battle.get_unit(status_battle.current_actor_id())
			var acted := false
			for ability in actor.get("abilities", []):
				if acted:
					break
				for rank in range(1, 5):
					if status_battle._legal_targets(actor, ability, rank).is_empty():
						continue
					var receipt := status_battle.use_foe_ability(str(ability["id"]), rank)
					if bool(receipt.get("ok", false)):
						acted = true
						for hit in receipt.get("results", []):
							if hit.get("fray_event", {}).get("ok") == true:
								seen_fray = true
							if not hit.get("statuses", []).is_empty():
								seen_status = true
					break
			if not acted and not status_battle.is_over():
				status_battle.pass_turn()
			if seen_status and seen_fray:
				break
		_check(seen_status, "AC2: an authored foe status really lands in seeded combat")
		_check(seen_fray, "AC2: an authored fray attack really changes hero fray")


# ---------------------------------------------------------------- AC2 invalid inputs

func _test_invalid_inputs(catalog: Dictionary) -> void:
	seed(508001)
	var before_rng := randi()
	seed(508001)
	var four := _config(catalog, ["ragling", "ragling_guard", "moth_scribe", "pin_skitter"], 6108)
	var created := StitchedRules.create(four)
	_check(not bool(created.get("ok", false)) and created.get("battle") == null,
		"AC2: four opening foes are refused without a battle")
	_check(randi() == before_rng, "AC2: refusing four foes spends no global RNG")
	var battle := _battle(catalog, ["ragling", "moth_scribe"], 6109)
	if battle == null:
		return
	for step in range(20):
		if battle.current_side() == "foe":
			break
		battle.pass_turn()
	_check(battle.current_side() == "foe", "AC2: a real foe turn preceded invalid action checks")
	var foe := battle.get_unit(battle.current_actor_id())
	var ability_id := str(foe["abilities"][0]["id"])
	var before_state := battle.state_snapshot()
	var before_snapshot_rng := battle.rng_state()
	var unknown := battle.use_foe_ability("not_an_ability", 1)
	var illegal_rank := battle.use_foe_ability(ability_id, 4)
	_check(not bool(unknown.get("ok", true)) and not bool(illegal_rank.get("ok", true)),
		"AC2: unknown abilities and illegal target ranks are refused")
	_check(before_state == battle.state_snapshot() and before_snapshot_rng == battle.rng_state(),
		"AC2: refused foe actions change neither state nor seeded RNG")


# ---------------------------------------------------------------- Spool Hexer's authored mark hunt

func _test_spool_kit(catalog: Dictionary) -> void:
	var foe := StitchedEnemyCatalog.foe_for(catalog, "spool_hexer")
	_check(not foe.is_empty(), "Hexer AC1: exact canonical id resolves")
	if foe.is_empty():
		return
	_check(foe["name"] == "Spool Hexer" and foe["max_hp"] == 24
		and foe["speed"] == 6 and foe["dodge"] == 7 and foe["acc"] == 0
		and foe["prot"] == 2 and not foe["is_boss"] and foe["turns_per_round"] == 1
		and StitchedEnemyCatalog.trophy_for(catalog, "spool_hexer") == "spool_hexer_spool",
		"Hexer AC1: existing stats, one turn and named trophy stay intact")
	var expected := [
		{"id": "hex_bolt", "name": "Hex Bolt", "kind": "ranged", "launch": [1, 4],
			"target": [1, 3], "target_side": "enemy", "multi": false, "acc": 88,
			"dmg": [4, 5], "crit": 0, "mark_damage": 3, "effects": {"weak": 1},
			"self_move": 0, "move": "attack2"},
		{"id": "spool_curse", "name": "Spool Curse", "kind": "debuff", "launch": [1, 4],
			"target": [1, 2, 3, 4], "target_side": "enemy", "multi": true, "acc": 90,
			"dmg": [0, 0], "crit": 0, "effects": {"exposed": 2},
			"self_move": 0, "move": "skill"},
		{"id": "thread_tag", "name": "Thread Tag", "kind": "debuff", "launch": [1, 2, 3, 4],
			"target": [1, 2, 3], "target_side": "enemy", "multi": false, "acc": 90,
			"dmg": [0, 0], "crit": 0, "effects": {"mark": 3},
			"self_move": 0, "move": "skill"},
	]
	_check(foe["abilities"].size() == 3, "Hexer AC1: exactly one third move appended")
	for index in range(mini(3, foe["abilities"].size())):
		var normalized := StitchedParts.validate_ability(expected[index])
		_check(normalized.get("ok", false) and foe["abilities"][index] == normalized["ability"],
			"Hexer AC1: exact independent ability contract at index %d" % index)
		var ability: Dictionary = foe["abilities"][index]
		for rank in range(1, 5):
			_check(StitchedParts.ranks_allowed(ability["launch_mask"], rank) == expected[index]["launch"].has(rank)
				and StitchedParts.ranks_allowed(ability["target_mask"], rank) == expected[index]["target"].has(rank),
				"Hexer AC1: exact launch/target masks at move %d rank %d" % [index, rank])
	var raw := _record(_documents(catalog), "spool_hexer")
	_check(raw.get("max_hp") == 24 and raw.get("name") == "Spool Hexer"
		and raw.get("art_path") == "res://assets/paper/enemies/spool_hexer.png",
		"Hexer AC1: legacy HP/name/art remain exact")
	var legacy_actions := [
			{"type": "attack", "amount": 9, "weight": 1},
			{"type": "attack", "amount": 8, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 10, "move": "attack3", "weight": 1},
			{"type": "debuff", "amount": 1, "status": "exposed", "weight": 1},
			{"type": "debuff", "amount": 1, "status": "weak", "weight": 1}]
	var legacy: Dictionary = raw.get("intent", {})
	_check(legacy.get("target") == "random" and legacy.get("actions", []).size() == legacy_actions.size(),
		"Hexer AC1: legacy intent target and action count remain exact")
	for index in range(mini(legacy.get("actions", []).size(), legacy_actions.size())):
		var action: Dictionary = legacy["actions"][index]
		_check(action.size() == legacy_actions[index].size(), "Hexer AC1: legacy action fields unchanged")
		for key in legacy_actions[index]:
			_check(action.get(key) == legacy_actions[index][key], "Hexer AC1: legacy action value unchanged: " + key)
	# Adjacent elites retain independent stat, action-order and trophy contracts.
	for neighbor in [
		["needle_marshal", 28, 5, 6, 6, "needle_marshal_sash", ["marshal_prick", "marshal_volley", "iron_discipline"]],
		["scissor_bailiff", 36, 4, 5, 8, "scissor_bailiff_shears", ["bailiff_snip", "seize_thread", "bailiff_unpick"]]]:
		var adjacent := StitchedEnemyCatalog.foe_for(catalog, neighbor[0])
		var ids: Array = []
		for ability in adjacent.get("abilities", []):
			ids.append(ability["id"])
			_check(ability["mark_damage"] == 0, "Hexer AC1: no mark bonus leaks to " + str(neighbor[0]))
		_check(adjacent.get("max_hp") == neighbor[1] and adjacent.get("speed") == neighbor[2]
			and adjacent.get("dodge") == neighbor[3] and adjacent.get("prot") == neighbor[4]
			and StitchedEnemyCatalog.trophy_for(catalog, neighbor[0]) == neighbor[5] and ids == neighbor[6],
			"Hexer AC1: unchanged neighbor profile " + str(neighbor[0]))


func _test_spool_combat(catalog: Dictionary) -> int:
	var live_seed := -1
	var witnesses := {"tag_hit": 0, "tag_miss": 0, "marked_hit": 0, "marked_miss": 0,
		"unmarked_hit": 0, "expired_hit": 0, "expired": 0, "protected": 0, "ticked_hit": 0}
	# Bounded independent seeds guarantee both accuracy outcomes without touching RNG.
	for seed_value in range(1, 33):
		var config := _config(catalog, ["spool_hexer", "needle_briar_guard", "scissor_bailiff"], seed_value)
		# A second deterministic control cohort exercises real protection, not a UI forecast.
		if seed_value > 16:
			config["heroes"][0]["prot"] = 40
		var created := StitchedRules.create(config)
		_check(created.get("ok", false), "Hexer AC2: seeded preview 4v3 fixture builds")
		if not created.get("ok", false):
			continue
		var battle: StitchedRules = created["battle"]
		_check(battle.get_heroes().size() == 4 and battle.get_foes().size() == 3,
			"Hexer AC2: living 4v3 preconditions")
		var tagged := false
		var ticks := 0
		var cycle: Array = []
		for step in range(64):
			if battle.is_over() or battle.round_number() > 7:
				break
			var actor := battle.get_unit(battle.current_actor_id())
			if battle.current_side() == "hero":
				if actor["id"] == "warden" and tagged:
					ticks += 1
					_check(int(actor["statuses"].get("mark", 0)) == maxi(0, 3 - ticks),
						"Hexer AC2: Mark counts down only on the affected hero's real turns")
					if ticks == 3:
						witnesses["expired"] += 1
				battle.pass_turn()
				continue
			var intent := StitchedFoeIntent.choose(battle, actor)
			if intent.get("pass", true):
				battle.pass_turn()
				continue
			var rank := int(intent["target_rank"])
			var round_value := battle.round_number()
			# The second legal tag goes to another hero, leaving a naturally expired control.
			if actor["id"] == "spool_hexer" and round_value == 6:
				rank = 2
			var targets := battle._legal_targets(actor, actor["abilities"][
				(round_value - 1) % actor["abilities"].size()], rank) if actor["id"] == "spool_hexer" else []
			var before: Dictionary = targets[0].duplicate(true) if not targets.is_empty() else {}
			var receipt := battle.use_foe_ability(intent["ability_id"], rank)
			_check(receipt.get("ok", false), "Hexer AC2: next legal action commits through StitchedRules")
			if actor["id"] != "spool_hexer":
				continue
			# Spool Curse alone reaches the whole living line; its separate receipt per doll is
			# the only place a Hexer action may return more than one hero result.
			var line_wide := str(receipt.get("ability", "")) == "spool_curse"
			var expected_results: int = targets.size() if line_wide else 1
			_check(not before.is_empty() and receipt.get("results", []).size() == expected_results,
				"Hexer AC2: real hero target count and one receipt per living legal doll")
			if before.is_empty() or receipt.get("results", []).size() != expected_results:
				continue
			cycle.append(receipt["ability"])
			if line_wide:
				var cursed_ranks: Array = []
				for result in receipt["results"]:
					cursed_ranks.append(int(result["target_rank"]))
					var doll := battle.get_unit(str(result["target"]))
					var curse_statuses: Array = (
						[{"status": "exposed", "duration": 2}] if bool(result["hit"]) else [])
					_check(result["statuses"] == curse_statuses and int(result["damage"]) == 0
						and not bool(result["crit"]) and int(result["target_hp"]) == int(doll["hp"]),
						"Hexer AC2: only a confirmed curse hit applies Exposed 2 with no direct damage")
					_check((int(doll["statuses"].get("exposed", 0)) > 0) == bool(result["hit"]),
						"Hexer AC2: curse exposure matches the actual doll state")
				_check(cursed_ranks == [1, 2, 3, 4],
					"Hexer AC2: the curse receipt covers the whole living four-rank line")
				continue
			var hit: Dictionary = receipt["results"][0]
			if receipt["ability"] == "thread_tag":
				_check(hit.has("roll") and hit["hit_chance"] == StitchedRules.hit_chance(
					90 + int(actor["acc"]) + int(battle.candle_band()["enemy_acc"]),
					battle.effective_dodge(before), actor["miss_streak"])
					and hit["hit"] == (hit["roll"] <= hit["hit_chance"])
					and hit["damage"] == 0 and hit["target_hp"] == before["hp"] and not hit["crit"],
					"Hexer AC2: zero-damage tag has a normal 90-ACC hit/miss receipt")
				_check(hit["statuses"] == ([{"status": "mark", "duration": 3}] if hit["hit"] else []),
					"Hexer AC2: only a confirmed tag hit applies Mark 3")
				if round_value == 3:
					tagged = hit["hit"]
					witnesses["tag_hit" if tagged else "tag_miss"] += 1
					var remaining := 3 - int(battle.current_actor_id() == "warden") if tagged else 0
					_check(int(battle.get_unit("warden")["statuses"].get("mark", 0)) == remaining,
						"Hexer AC2: tag updates actual hero state, accounting for next turn entry")
			elif receipt["ability"] == "hex_bolt":
				var marked := int(before["statuses"].get("mark", 0)) > 0
				if round_value == 4 and tagged:
					_check(marked, "Hexer AC2: fourth-round follow-up still finds active Mark")
				if not hit["hit"]:
					_check(hit["damage"] == 0 and hit["statuses"].is_empty() and hit["target_hp"] == before["hp"],
						"Hexer AC2: missed Hex Bolt has neither damage nor bonus nor Weak")
					if marked:
						witnesses["marked_miss"] += 1
					continue
				var bases := [StitchedRules.crit_damage(5)] if hit["crit"] else [4, 5]
				var damages: Array = []
				for base in bases:
					damages.append(StitchedRules.damage_after_modifiers(base, actor["statuses"],
						before["statuses"], marked, 3, before["prot"]))
				_check(damages.has(hit["damage"]) and hit["target_hp"] == maxi(0, int(before["hp"]) - int(hit["damage"])),
					"Hexer AC2: real Hex Bolt damage uses authored +3 only while marked before modifiers/PROT")
				witnesses["marked_hit" if marked else "unmarked_hit"] += 1
				if marked and ticks >= 1:
					witnesses["ticked_hit"] += 1
					if round_value == 4 and seed_value <= 16 and live_seed < 0:
						live_seed = seed_value
				if marked and before["prot"] >= 40:
					witnesses["protected"] += 1
				if round_value == 7 and tagged:
					_check(not marked and ticks >= 3, "Hexer AC2: expired Mark gives no later Hex Bolt bonus")
					witnesses["expired_hit"] += 1
		_check(cycle.slice(0, 4) == ["hex_bolt", "spool_curse", "thread_tag", "hex_bolt"],
			"Hexer AC2: natural round order preserves the original moves then tag/follow-up")
	for key in witnesses:
		_check(witnesses[key] > 0, "Hexer AC2: non-vacuous deterministic witness: " + key)
	_check(StitchedRules.damage_after_modifiers(5, {"weak": 1}, {"exposed": 1}, true, 3, 40) == 6
		and StitchedRules.damage_after_modifiers(5, {"weak": 1}, {"exposed": 1}, false, 3, 40) == 3,
		"Hexer AC2: +3 precedes combined Weak/Exposed and protection in the rules formula")
	_check(live_seed > 0, "Hexer AC2: deterministic unmodified preview seed confirms tag and follow-up hits after ticking")
	return live_seed


func _test_spool_live_intents(catalog: Dictionary, seed_value: int) -> void:
	var stage := StitchedBattleScreen.new()
	_check(stage.begin(_config(catalog, ["spool_hexer", "needle_briar_guard", "scissor_bailiff"], seed_value)),
		"Hexer AC3: actual live stage admits canonical elite 4v3")
	if stage.battle == null:
		stage.free()
		return
	root.add_child(stage)
	await process_frame
	var battle := stage.battle
	var seen: Dictionary = {}
	for step in range(40):
		if battle.is_over() or battle.round_number() > 4:
			break
		stage._refresh()
		var intent := StitchedFoeIntent.choose(battle, battle.get_unit("spool_hexer"))
		var ticket: StitchedFoeIntentPlate = stage._foe_tickets[1]
		_check(ticket.visible and stage._foe_intents[1] == intent and ticket.focus_mode == Control.FOCUS_ALL,
			"Hexer AC3: mounted focusable plate displays actual legal choice")
		var ability := str(intent.get("ability_id", ""))
		seen[ability] = true
		_check(intent.get("base_mark_damage", -1) == (3 if ability == "hex_bolt" else 0)
			and ticket.tooltip_text.contains("BONUS VS MARK +3") == (ability == "hex_bolt")
			and not ticket.secondary.text.contains("MARK"),
			"Hexer AC3: only Hex Bolt conditionally discloses bonus, separate from rank/base caption")
		if ability == "thread_tag":
			_check(intent["base_damage"] == [0, 0] and intent["base_effects"] == {"mark": 3}
				and intent["base_acc"] == 90 and intent["target_rank"] == 1 and intent["target_side"] == "hero"
				and ticket.glyph.texture == StitchedFoeIntentPlate.DEBUFF_TEXTURE,
				"Hexer AC3: legal Thread Tag truthfully announces zero damage, Mark 3 and hero rank")
			var units_before := battle._units.duplicate(true)
			for target_rank in [2, 3]:
				for hero in battle.get_heroes():
					if int(hero["rank"]) < target_rank:
						hero["lost"] = true
				var before := battle.state_snapshot()
				var legal := StitchedFoeIntent.choose(battle, battle.get_unit("spool_hexer"))
				_check(legal.get("ability_id") == "thread_tag" and legal.get("target_rank") == target_rank
					and legal.get("affected_ranks") == [target_rank] and before == battle.state_snapshot(),
					"Hexer AC3: read-only next-legal tag targets hero rank %d" % target_rank)
			battle._units = units_before
		elif ability == "spool_curse":
			_check(intent["multi"] and intent["affected_ranks"] == [1, 2, 3, 4]
				and intent["target_side"] == "hero" and intent["target_rank"] == 1
				and intent["base_acc"] == 90 and intent["base_damage"] == [0, 0]
				and intent["base_effects"] == {"exposed": 2}
				and ticket.glyph.texture == StitchedFoeIntentPlate.DEBUFF_TEXTURE,
				"Hexer AC3: the curse announces its whole living line, zero damage and Exposed 2")
			_check(ticket.secondary.text == "HERO RANKS 1,2,3,4"
				and ticket.tooltip_text.contains("ALL legal HERO ranks 1, 2, 3, 4"),
				"Hexer AC3: the live intent plate names every cursed doll rank")
		elif ability == "hex_bolt":
			_check(intent["base_damage"] == [4, 5] and intent["base_effects"] == {"weak": 1}
				and intent["base_acc"] == 88 and ticket.glyph.texture == StitchedFoeIntentPlate.ATTACK_TEXTURE
				and ticket.tooltip_text.contains("BASE DMG 4–5") and ticket.tooltip_text.contains("weak +1"),
				"Hexer AC3: Hex Bolt base damage/Weak remain separate from conditional bonus")
		var snapshot := battle.state_snapshot()
		var rng := battle.rng_state()
		var receipts := stage.receipts.duplicate(true)
		for repeat in range(3):
			stage._refresh_foe_intents()
			ticket.grab_focus()
			ticket.mouse_entered.emit()
			_check(stage._intent_disclosure.visible and stage._intent_disclosure_label.text == ticket.tooltip_text,
				"Hexer AC3: real hover/keyboard disclosure carries complete conditional text")
		_check(stage._intent_disclosure_label.get_line_count() <= stage._intent_disclosure_label.get_visible_line_count()
			and snapshot == battle.state_snapshot() and rng == battle.rng_state() and receipts == stage.receipts,
			"Hexer AC3: repeated mounted projection fits 1280x720 and preserves actors/ranks/round/RNG/receipts")
		# Drive the actual player Pass path and automatic foe driver.
		_check(battle.current_side() == "hero", "Hexer AC3: player has a real turn before Pass")
		stage._action_buttons["pass"].pressed.emit()
	_check(seen.has("hex_bolt") and seen.has("spool_curse") and seen.has("thread_tag"),
		"Hexer AC3: live intent test witnesses every authored move")
	var live_cycle: Array = []
	var live_tag_hit := false
	var live_followup_hit := false
	for receipt in stage.receipts:
		if receipt.get("actor") == "spool_hexer":
			live_cycle.append(receipt.get("ability"))
			if live_cycle.size() == 3 and receipt.get("results", []).size() == 1:
				live_tag_hit = receipt["results"][0].get("hit", false)
			if live_cycle.size() == 4 and receipt.get("results", []).size() == 1:
				live_followup_hit = receipt["results"][0].get("hit", false)
	_check(live_cycle.slice(0, 4) == ["hex_bolt", "spool_curse", "thread_tag", "hex_bolt"],
		"Hexer AC2/AC3: actual mounted foe driver executes all four natural-round actions")
	_check(live_tag_hit and live_followup_hit,
		"Hexer AC2/AC3: live driver seed confirms tag and marked follow-up hit witnesses")
	# Adversarial projections change preconditions only; preview itself stays read-only.
	var units := battle._units.duplicate(true)
	for state in ["stun", "illegal", "empty_targets", "lost", "dead"]:
		battle._units = units.duplicate(true)
		var actor: Dictionary = battle._units["spool_hexer"]
		if state == "stun":
			actor["statuses"]["stun"] = 1
		elif state == "illegal":
			actor["rank"] = 5
		elif state == "empty_targets":
			for hero in battle.get_heroes():
				hero["lost"] = true
		else:
			actor[state] = true
		var snapshot := battle.state_snapshot()
		var receipts := stage.receipts.duplicate(true)
		var intent := StitchedFoeIntent.choose(battle, actor)
		stage._foe_tickets[1].present_intent(intent, 1)
		_check(not intent.has("base_mark_damage") and not stage._foe_tickets[1].tooltip_text.contains("BONUS")
			and snapshot == battle.state_snapshot() and receipts == stage.receipts,
			"Hexer AC3: no ghost bonus or mutation for " + state)
		if state in ["stun", "illegal", "empty_targets"]:
			_check(intent.get("pass", false) and intent.get("stun", false) == (state == "stun")
				and not intent.has("base_damage") and intent["affected_ranks"].is_empty(),
				"Hexer AC3: no-action sentinel shape preserved for " + state)
		else:
			_check(intent.is_empty(), "Hexer AC3: unavailable foe has no intent: " + state)
	battle._units = units.duplicate(true)
	battle._units["spool_hexer"]["rank"] = 2
	var fallback_before := battle.state_snapshot()
	var fallback := StitchedFoeIntent.choose(battle, battle.get_unit("spool_hexer"))
	_check(fallback.get("ability_id") == "thread_tag" and fallback.get("base_mark_damage", -1) == 0
		and fallback_before == battle.state_snapshot(),
		"Hexer AC3: rank change falls through original illegal moves to legal tag without phantom bonus")
	battle._units = units.duplicate(true)
	var unrelated := StitchedFoeIntent.choose(battle, battle.get_unit("scissor_bailiff"))
	stage._foe_tickets[1].present_intent(unrelated, 3)
	_check(not unrelated.get("pass", true) and unrelated.get("base_mark_damage", -1) == 0
		and not stage._foe_tickets[1].tooltip_text.contains("BONUS"),
		"Hexer AC3: real unrelated legal foe clears stale conditional bonus")
	stage._foe_tickets[1].present_intent({}, 1)
	_check(stage._foe_tickets[1].tooltip_text.is_empty() and not stage._foe_tickets[1].visible,
		"Hexer AC3: empty intent clears all stale disclosure")
	stage.free()
	await process_frame


# ---------------------------------------------------------------- live admission uses the loader

func _test_live_admission(catalog: Dictionary) -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var config: Dictionary = app._stitched_floor_config()
	_check(not config.is_empty(), "AC3: the real title still builds a Roadblock admission config")
	if not config.is_empty():
		_check(config.get("foes", []).size() == 3,
			"AC3: the live Roadblock keeps exactly its original three foes")
		var ids: Array = []
		for foe in config.get("foes", []):
			ids.append(str(foe.get("id", "")))
			_check(foe == StitchedEnemyCatalog.foe_for(catalog, str(foe.get("id", ""))),
				"AC3: the live foe is the canonical loader kit: " + str(foe.get("id", "")))
		_check(ids == ROADBLOCK_IDS, "AC3: the live Roadblock roster is unchanged")
		var parts: Dictionary = StitchedParts.build_catalog(config.get("parts", []))
		_check(bool(parts.get("ok", false)), "AC3: the live merged part catalog validates")
		for enemy_id in ROADBLOCK_IDS:
			var trophy := StitchedEnemyCatalog.trophy_for(catalog, str(enemy_id))
			_check(not trophy.is_empty() and parts["by_id"].has(trophy),
				"AC3: the live catalog can receive the foe's canonical trophy: " + str(enemy_id))
	app.free()
	await process_frame
