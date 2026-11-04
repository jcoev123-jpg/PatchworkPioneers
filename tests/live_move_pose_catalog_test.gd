extends SceneTree

const Catalog = preload("res://scripts/live_move_pose_catalog.gd")
const FALLBACK := "res://assets/paper/heroes/warden_attack.png"
var failures := 0

class CountingCatalog extends Catalog:
	var reads := 0
	func _read_manifest() -> Variant:
		reads += 1
		return super._read_manifest()

class FixtureCatalog extends Catalog:
	var source: Variant
	var reads := 0
	var available := true
	var checked: Array[String] = []
	func _read_manifest() -> Variant:
		reads += 1
		return source
	func _art_available(path: String) -> bool:
		checked.append(path)
		return available


func _initialize() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(Catalog.MANIFEST_PATH))
	check(manifest is Dictionary and manifest.get("enemies") is Dictionary,
		"real manifest exists and parses")
	var catalog := FixtureCatalog.new()
	catalog.source = manifest
	var rng := RandomNumberGenerator.new()
	rng.seed = 445
	var rng_before := rng.state
	var original: Dictionary = manifest.duplicate(true)
	var attack := {"type": "attack", "amount": 5, "target_position": 1, "enemy_position": 1}
	var action_before := attack.duplicate(true)
	var first := catalog.lookup_enemy("thread_biter", attack, FALLBACK)
	check_move(first, "Lint Spit", "attack")
	var lash := attack.duplicate(true)
	lash["move"] = "attack2"
	check_move(catalog.lookup_enemy("thread_biter", lash, FALLBACK), "Thread Lash", "attack2")
	check_move(catalog.lookup_hero("warden", "block", FALLBACK), "Shield Wall", "guard")
	check_move(catalog.lookup_hero("seamstress", "skill", FALLBACK), "Mending Stitch", "skill")
	check_move(catalog.lookup_enemy("thread_biter", {"type": "block", "amount": 2}, FALLBACK),
		"Fraying Coil", "skill")
	for boss in [
			["patchwork_behemoth", [["attack2", "Knuckle Slam"],
				["attack3", "Stuffing Hurl"], ["attack4", "Rope Lash"]]],
			["sewing_machine_colossus", [["attack2", "Needle Drive"],
				["attack3", "Bobbin Shot"], ["attack4", "Treadle Stomp"]]],
			["moth_queen", [["attack2", "Dust Gale"],
				["attack3", "Pin Crown Dive"], ["attack4", "Devour"]]]]:
		for pair in boss[1]:
			var boss_action := attack.duplicate(true)
			boss_action["move"] = pair[0]
			check_move(catalog.lookup_enemy(boss[0], boss_action, FALLBACK), pair[1], pair[0])
	var two_packet := {"type": "attack", "amount": 22, "hits": 2, "move": "attack3",
		"target_position": 1, "enemy_position": 1}
	check_move(catalog.lookup_enemy("patchwork_behemoth", two_packet, FALLBACK),
		"Stuffing Hurl", "attack3")
	first["name"] = "changed"
	first["covers"].append("changed")
	for repeat in range(5):
		var again := catalog.lookup_enemy("thread_biter", attack, FALLBACK)
		check_move(again, "Lint Spit", "attack")
		check(again.get("covers") == ["attack"], "receipt is detached")
	check(catalog.reads == 1, "one manifest read for repeated enemy and hero lookups")
	check(attack == action_before and manifest == original and rng.state == rng_before,
		"lookups preserve actions, source records and RNG")
	check(lash.get("move") == "attack2", "explicit move preserved")
	for invalid in [null, [], {}, {"type": "attack"}, {"type": "attack", "amount": -1, "target_position": 1},
		{"type": "block", "amount": 2, "move": "attack"},
		{"type": "block", "amount": 2, "move": "attack2"},
		{"type": "block", "amount": 2, "move": "attack3"},
		{"type": "block", "amount": 2, "move": "attack4"},
		{"type": "attack", "amount": 2, "target_position": 1, "move": "skill"},
		{"type": "attack", "amount": 2, "target_position": 1, "move": "unknown"},
		{"type": "attack", "amount": 2, "target_position": 1, "move": 2}]:
		check(catalog.lookup_enemy("thread_biter", invalid, FALLBACK).is_empty(), "invalid action fails closed")
	check(catalog.lookup_enemy("unknown", attack, FALLBACK).is_empty(), "unknown enemy")
	check(catalog.lookup_enemy("thread_biter", {"type": "summon", "amount": 0}, FALLBACK).is_empty(), "uncovered action")
	for role in ["attack", "attack2", "guard", "power", "", "unknown"]:
		check(catalog.lookup_hero("warden", role, FALLBACK).is_empty(), "invalid/unmapped hero role")
	check(catalog.lookup_hero("unknown", "block", FALLBACK).is_empty(), "unknown hero")
	# Force unavailable art without depending on whether pipeline PNGs exist.
	catalog.available = false
	var crab := {}
	for record in RunTypedBattleRoster._parse_catalog_text(FileAccess.get_file_as_string(
			"res://data/enemies/run_enemies.json")):
		if record.id == "scissor_crab":
			crab = record
	check(not crab.is_empty(), "authentic Crab pose source exists")
	for actor in [["felt_bulwark", "Roll Charge", "Felt Slam"], ["moth_scribe", "Quill Stab", "Ink Flick"],
			["seam_ripper", "Hook Rip", "Ripper Throw"], ["scissor_crab", "Pinch", "Blade Spin"]]:
		for index in [1, 2]:
			var named := attack.duplicate(true)
			named["move"] = "attack%d" % (index + 1)
			if actor[0] == "scissor_crab":
				if crab.is_empty():
					continue
				var normalized := CombatEnemyIntents.weighted_action(crab.intent.actions[index + 1])
				check(not normalized.is_empty() and normalized.get("weight") == 1,
					"authored Crab named alternative normalizes")
				if normalized.is_empty():
					continue
				named = normalized.action.duplicate(true)
				named.target_position = 1
				named.enemy_position = 1
			var named_before := named.duplicate(true)
			for available in [false, true]:
				catalog.available = available
				var receipt := catalog.lookup_enemy(actor[0], named, FALLBACK)
				check_move(receipt, actor[index], named.move)
				check(receipt.get("art_available") == available
					and receipt.get("fallback_used") == not available
					and receipt.get("named_art") == "res://assets/paper/enemies/%s_%s.png" % [actor[0], named.move]
					and receipt.get("art") == (receipt.get("named_art") if available else FALLBACK),
					"exact named pose and forced availability fallback: " + actor[index])
			check(named == named_before and manifest == original and rng.state == rng_before,
				"forced named pose previews preserve action, source manifest and run RNG")
	catalog.available = false
	var missing := catalog.lookup_hero("seamstress", "skill", FALLBACK)
	check_move(missing, "Mending Stitch", "skill")
	check(missing.get("art") == FALLBACK and missing.get("fallback_used") == true
		and missing.get("art_available") == false, "unavailable art uses supplied attack path")
	var real := CountingCatalog.new()
	var real_receipt := real.lookup_enemy("thread_biter", attack, FALLBACK)
	check_move(real_receipt, "Lint Spit", "attack")
	check(real_receipt.get("art") == (real_receipt.get("named_art")
		if ResourceLoader.exists(real_receipt.get("named_art", ""), "Texture2D") else FALLBACK),
		"production availability check chooses usable art")
	check(ResourceLoader.exists(FALLBACK, "Texture2D"), "fallback witness is a usable established texture")
	check_move(real.lookup_enemy("thread_biter", lash, FALLBACK), "Thread Lash", "attack2")
	check_move(real.lookup_hero("warden", "block", FALLBACK), "Shield Wall", "guard")
	check_move(real.lookup_hero("seamstress", "skill", FALLBACK), "Mending Stitch", "skill")
	check(real.reads == 1, "production parser runs once per instance")
	_test_malformed(attack)
	print("live_move_pose_catalog_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _test_malformed(attack: Dictionary) -> void:
	for source in [null, [], "bad JSON", {}, {"enemies": []}, {"enemies": {"thread_biter": []}},
		{"enemies": {"thread_biter": {"attack": []}}}]:
		var catalog := FixtureCatalog.new()
		catalog.source = source
		for repeat in range(2):
			check(catalog.lookup_enemy("thread_biter", attack, FALLBACK).is_empty(), "malformed manifest")
		check(catalog.reads == 1 and catalog.checked.is_empty(), "failed manifest cached; no texture access")
	var valid := {"name": "Witness", "covers": ["attack"], "art": FALLBACK}
	var values: Dictionary = {"name": [null, 2, "", "  "], "art": [null, 2, "", "bad", "res://bad.tres"],
		"covers": [null, {}, [], ["block"], ["attack", "unknown"], ["attack", 2]]}
	for field in values:
		for value in values[field]:
			var entry := valid.duplicate(true)
			entry[field] = value
			var catalog := FixtureCatalog.new()
			catalog.source = {"enemies": {"thread_biter": {"attack": entry}}}
			check(catalog.lookup_enemy("thread_biter", attack, FALLBACK).is_empty(), "malformed entry " + field)
			check(catalog.checked.is_empty(), "invalid entry never checks/loads art")
	var detached := FixtureCatalog.new()
	var source := {"enemies": {"thread_biter": {"attack": valid}}}
	detached.source = source
	check_move(detached.lookup_enemy("thread_biter", attack, FALLBACK), "Witness", "attack")
	source["enemies"].clear()
	check_move(detached.lookup_enemy("thread_biter", attack, FALLBACK), "Witness", "attack")
	for group in ["enemies", "heroes"]:
		var catalog := FixtureCatalog.new()
		catalog.source = {group: {"warden": {"skill": valid, "guard": valid}}}
		check(catalog.lookup_hero("warden", "block", FALLBACK).is_empty(), "incompatible guard covers")
		check(catalog.lookup_hero("warden", "skill", FALLBACK).is_empty(), "incompatible skill covers")
		check(catalog.lookup_enemy("warden", {"type": "block", "amount": 2}, FALLBACK).is_empty(), "enemy nonattack cannot use attack covers")


func check_move(receipt: Dictionary, title: String, pose: String) -> void:
	check(not receipt.is_empty() and receipt.get("name") == title and receipt.get("pose") == pose,
		"named move " + title + " / " + pose)
	if receipt.get("art_available") == true:
		check(receipt.get("art") == receipt.get("named_art") and receipt.get("fallback_used") == false,
			"available named art selected")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
