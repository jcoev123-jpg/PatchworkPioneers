extends SceneTree
## Scene-free Enemy keyword regressions: the Enrage confirmed-hit quote and its
## authoritative stack commit, the unchanged Thorns N retaliation contract they
## share validation helpers with, and the shipped Marshal Enrage metadata.

const ELITE_CATALOG_PATH := "res://data/enemies/m04_elites.json"
const STARTER_CATALOG_PATH := "res://data/enemies/starter_enemies.json"
const TYPED_POOLS_PATH := "res://data/encounters/m03_typed_battle_pools.json"
const MARSHAL_ENCOUNTER_PATH := "res://data/encounters/needle_marshal_elite.json"

var failures: Array[String] = []
var checks := 0
var rules := CombatEnemyKeywordRules.new()
var attacks := CombatStatusAttacks.new()


func _initialize() -> void:
	_test_contract_and_single_hit_quotes()
	_test_blocked_and_zero_damage()
	_test_multi_hit_chain_and_cap()
	_test_non_enrage_and_malformed_receipts()
	_test_invalid_enemy_snapshots()
	_test_immutability_replay_and_rng()
	_test_thorns_contract_unchanged()
	_test_needle_marshal_thorns()
	_test_enrage_commit_contract()
	_test_enrage_commit_chain()
	_test_enrage_commit_blocked_zero_and_lethal()
	_test_enrage_commit_inert_sources()
	_test_enrage_commit_rejections()
	_test_enrage_commit_replay_and_rng()
	if failures.is_empty():
		print("combat_enemy_keyword_rules_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_enemy_keyword_rules_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## A real one-enemy CombatEnemies roster; the definition keeps the exact detached
## Enrage metadata a live caller would snapshot. Null omits an optional key.
func _enemies(hp: int = 40, enrage: Variant = null, stacks: Variant = null) -> CombatEnemies:
	var definition := {"id": "patch_imp", "max_hp": hp}
	if enrage != null:
		definition["enrage"] = enrage
	if stacks != null:
		definition["enrage_stacks"] = stacks
	var enemies := CombatEnemies.new([definition])
	_check(enemies.is_valid() and enemies.get_enemy(1).get("hp") == hp,
		"fixture: valid living enemy roster")
	return enemies


func _party() -> CombatParty:
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"fixture: all three real living heroes")
	return party


func _receipt(damage: int, absorbed: int, loss: int) -> Dictionary:
	return {"ok": true, "damage": damage, "block_absorbed": absorbed, "hp_loss": loss}


func _enrage(stacks: int) -> Dictionary:
	return {"ok": true, "applied": true, "enrage_stacks": stacks,
		"attack_bonus": stacks * 2}


func _no_op(stacks: int) -> Dictionary:
	return {"ok": true, "applied": false, "enrage_stacks": stacks,
		"attack_bonus": stacks * 2}


func _failure() -> Dictionary:
	return {"ok": false, "applied": false, "enrage_stacks": 0, "attack_bonus": 0}


## Every quote must be read-only: compare detached copies of both inputs.
func _quote(enemy: Dictionary, receipt: Dictionary, label: String) -> Dictionary:
	var enemy_before := enemy.duplicate(true)
	var receipt_before := receipt.duplicate(true)
	var quote := rules.quote_enrage_after_hit(enemy, receipt)
	_check(enemy == enemy_before and receipt == receipt_before,
		label + ": quote leaves the enemy snapshot and receipt unchanged")
	return quote


func _expect_failure(enemy: Dictionary, receipt: Dictionary, label: String) -> void:
	_check(_quote(enemy, receipt, label) == _failure(),
		label + ": reports ok=false with no stacks or attack bonus")


## One genuine confirmed hit through the real bridge for a living recipient.
func _confirmed(enemies: CombatEnemies, damage: int, label: String,
		position: int = 1) -> Array:
	var pre := enemies.get_enemy(position)
	var receipt := attacks.resolve_vs_enemy(enemies, position, damage, {}, {})
	_check(receipt.get("ok", false) and receipt.get("damage") == damage,
		label + ": authentic confirmed CombatStatusAttacks receipt")
	return [pre, receipt]


## Strict on-disk catalog parse through the shipped parser. Callers look records
## up by ID: never by catalog total or list position.
func _catalog_records(path: String) -> Array:
	var records := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string(path))
	_check(not records.is_empty(), "fixture: shipped catalog parses " + path)
	return records


## Strict on-disk catalog lookup through the shipped parser. Exactly one record
## must carry this ID; the returned dictionary is detached from the parse.
func _catalog_record(path: String, id: String) -> Dictionary:
	var records := _catalog_records(path)
	var matches: Array = records.filter(func(record: Dictionary) -> bool:
		return record.get("id") == id)
	_check(matches.size() == 1,
		"fixture: exactly one on-disk record %s in %s" % [id, path])
	if matches.size() != 1:
		return {}
	var found: Dictionary = matches[0]
	return found.duplicate(true)


## A real Marshal/escort roster built only from the shipped catalog records.
func _marshal_roster(marshal: Dictionary, escort: Dictionary) -> CombatEnemies:
	var enemies := CombatEnemies.new([marshal.duplicate(true), escort.duplicate(true)])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2
		and enemies.get_enemy(1).get("id") == "needle_marshal"
		and enemies.get_enemy(2).get("id") == "ragling_guard",
		"fixture: living Marshal/escort CombatEnemies roster")
	return enemies


## A real seeded starter deck that genuinely holds the authored Warden Strike.
func _real_deck() -> CombatDeck:
	var starting := StarterCards.new().get_starting_deck()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9137
	var deck := CombatDeck.new(starting, rng)
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == 5, "fixture: real seeded starter deck starts a turn")
	var draws := 0
	while not deck.hand.has("warden_strike") and not deck.draw_pile.is_empty() \
			and draws < starting.size():
		deck.draw_extra(1)
		draws += 1
	_check(deck.hand.has("warden_strike") and deck.turn_active and deck.energy == 3,
		"fixture: the real Warden Strike stays held and affordable")
	return deck


func _test_contract_and_single_hit_quotes() -> void:
	_check(rules.has_method("quote_enrage_after_hit"),
		"scene-free keyword rules expose the documented Enrage quote")
	_check(CombatEnemyKeywordRules.ENRAGE_MAX_STACKS == 3
		and CombatEnemyKeywordRules.ENRAGE_ATTACK_BONUS_PER_STACK == 2,
		"V3-2 authored cap of three stacks and +2 attack per stack")
	# AC1: 0->1/+2, 1->2/+4, 2->3/+6 from real pre-hit snapshots.
	for stacks in [0, 1, 2]:
		var enemies := _enemies(40, true, stacks)
		var pre := enemies.get_enemy(1)
		_check(pre.get("enrage") == true and pre.get("enrage_stacks") == stacks,
			"fixture: living Enrage enemy really starts at %d stacks" % stacks)
		var hit := _confirmed(enemies, 4, "single hit at %d stacks" % stacks)
		_check(_quote(hit[0], hit[1], "single hit at %d stacks" % stacks)
			== _enrage(stacks + 1),
			"confirmed hit quotes exactly one more stack and +2 per stack: %d" % stacks)
	# Absent enrage_stacks is zero only for valid Enrage metadata.
	var missing := _enemies(40, true)
	var missing_pre := missing.get_enemy(1)
	_check(not missing_pre.has("enrage_stacks") and missing_pre.get("enrage") == true,
		"fixture: Enrage metadata without an explicit stack count")
	var missing_hit := _confirmed(missing, 6, "hit without stack count")
	_check(_quote(missing_hit[0], missing_hit[1], "hit without stack count")
		== _enrage(1), "absent stack count means zero stacks before the hit")


func _test_blocked_and_zero_damage() -> void:
	# AC1: a positive hit fully absorbed by Block still awards one stack.
	var enemies := _enemies(40, true, 1)
	_check(enemies.gain_block(1, 10), "fixture: enemy Block 10 absorbs the whole hit")
	var pre := enemies.get_enemy(1)
	var blocked := attacks.resolve_vs_enemy(enemies, 1, 6, {}, {})
	_check(blocked == _receipt(6, 6, 0) and enemies.get_enemy(1)["hp"] == 40,
		"fixture: confirmed positive damage with block_absorbed > 0 and hp_loss == 0")
	_check(_quote(pre, blocked, "fully blocked hit") == _enrage(2),
		"fully blocked positive hit still awards one stack")
	# AC2: a successful zero-damage hit is a no-op that keeps the quorum.
	for stacks in [0, 2]:
		var idle := _enemies(40, true, stacks)
		var idle_hit := _confirmed(idle, 0, "zero-damage hit at %d" % stacks)
		_check(idle_hit[1] == _receipt(0, 0, 0),
			"fixture: zero-damage receipt at %d stacks is a successful hit" % stacks)
		_check(_quote(idle_hit[0], idle_hit[1], "zero-damage hit at %d" % stacks)
			== _no_op(stacks),
			"zero damage awards no stack and quotes the unchanged stacks: %d" % stacks)
	# A capped Enrage enemy never gains a stack from another hit either.
	var capped := _enemies(40, true, 3)
	var capped_hit := _confirmed(capped, 4, "hit at the cap")
	_check(_quote(capped_hit[0], capped_hit[1], "hit at the cap") == _no_op(3),
		"three-stack enemy stays at 3 stacks and +6 attack")


func _test_multi_hit_chain_and_cap() -> void:
	# AC2: feed each quote's stacks into the next call, exactly like a real caller.
	var enemies := _enemies(40, true)
	var roster_before := enemies.get_enemies()
	var stacks := 0
	var expected := [[1, 2, true], [2, 4, true], [3, 6, true], [3, 6, false]]
	for step in range(4):
		var pre := enemies.get_enemy(1)
		if step > 0:
			pre["enrage_stacks"] = stacks
		var receipt := attacks.resolve_vs_enemy(enemies, 1, 5, {}, {})
		_check(receipt == _receipt(5, 0, 5),
			"chain hit %d is an authentic confirmed 5-damage hit" % step)
		var quote := _quote(pre, receipt, "chain hit %d" % step)
		var want: Array = expected[step]
		_check(quote == {"ok": true, "applied": want[2],
			"enrage_stacks": want[0], "attack_bonus": want[1]},
			"chain hit %d quotes stacks %d and bonus +%d"
				% [step, want[0], want[1]])
		stacks = quote["enrage_stacks"]
	_check(stacks == 3, "four complete hits leave exactly three stacks")
	_check(enemies.get_enemy(1)["hp"] == 20
		and not enemies.get_enemy(1).has("enrage_stacks"),
		"quotes are read-only: the real roster only lost hit damage and stores no stacks")
	_check(roster_before.size() == 1 and roster_before[0].get("hp") == 40,
		"fixture: the untouched pre-hit roster snapshot is really independent")


func _test_non_enrage_and_malformed_receipts() -> void:
	# AC3: valid non-Enrage input reports a successful no-op.
	var plain := _enemies(40)
	var plain_pre := plain.get_enemy(1)
	_check(not plain_pre.has("enrage"), "fixture: enemy genuinely has no Enrage keyword")
	var plain_hit := _confirmed(plain, 4, "non-Enrage hit")
	_check(_quote(plain_pre, plain_hit[1], "non-Enrage enemy") == _no_op(0),
		"non-Enrage confirmed hit reports success with zero stacks and bonus")
	var off := _enemies(40, false, 2)
	var off_pre := off.get_enemy(1)
	_check(off_pre.get("enrage") == false and off_pre.get("enrage_stacks") == 2,
		"fixture: disabled keyword with leftover valid stack metadata")
	var off_hit := _confirmed(off, 4, "disabled keyword hit")
	_check(_quote(off_pre, off_hit[1], "disabled keyword") == _no_op(0),
		"explicitly disabled Enrage grants no stack or bonus")
	# AC3: malformed, failed, unknown or negative receipts fail closed.
	var enemy := _menaced()
	var good := _receipt(4, 0, 4)
	_expect_failure(enemy, {"ok": false, "damage": 4, "block_absorbed": 0, "hp_loss": 4},
		"failed hit receipt")
	for bad in [
			{}, {"ok": true}, {"damage": 4, "block_absorbed": 0, "hp_loss": 4},
			{"result": "hit", "amount": 4},
			{"ok": 1, "damage": 4, "block_absorbed": 0, "hp_loss": 4},
			{"ok": "true", "damage": 4, "block_absorbed": 0, "hp_loss": 4},
			{"ok": true, "damage": -1, "block_absorbed": 0, "hp_loss": 0},
			{"ok": true, "damage": 4.5, "block_absorbed": 0, "hp_loss": 4},
			{"ok": true, "damage": 4, "block_absorbed": -1, "hp_loss": 4},
			{"ok": true, "damage": 4, "block_absorbed": 0, "hp_loss": -4}]:
		_expect_failure(enemy, bad, "malformed receipt " + str(bad))
	_check(_quote(enemy, good, "valid receipt after malformed ones") == _enrage(1),
		"valid Enrage hit still quotes a stack after rejected receipts")


## A detached living Enrage record for receipt-only negative cases.
func _menaced() -> Dictionary:
	var enemies := _enemies(40, true)
	var pre := enemies.get_enemy(1)
	_check(pre.get("hp") == 40 and pre.get("enrage") == true,
		"fixture: valid living Enrage metadata for receipt cases")
	return pre


func _test_invalid_enemy_snapshots() -> void:
	var good := _receipt(4, 0, 4)
	# AC3: slain and genuinely invalid HP snapshots fail closed.
	var slain := _enemies(12, true)
	_check(slain.apply_damage(1, 12) and slain.is_slain(1), "fixture: enemy truly slain")
	var slain_pre := slain.get_enemy(1)
	_check(slain_pre.get("hp") == 0, "fixture: slain pre-hit snapshot has zero HP")
	_expect_failure(slain_pre, good, "slain enemy snapshot")
	for bad_hp in [{}, {"enrage": true}, {"hp": -1, "enrage": true},
			{"hp": 0, "enrage": true}, {"hp": "12", "enrage": true},
			{"hp": 12, "block": -2, "enrage": true},
			{"hp": 12, "thorns": -1, "enrage": true}]:
		_expect_failure(bad_hp, good, "invalid enemy record " + str(bad_hp))
	# AC3: a non-boolean enrage flag or an impossible stack count fails closed.
	var healthy := _menaced()
	for bad_flag in [1, "true", null, [], {}]:
		var flagged := healthy.duplicate(true)
		flagged["enrage"] = bad_flag
		_check(flagged.has("enrage") and flagged["enrage"] == bad_flag,
			"fixture: non-boolean enrage flag " + str(bad_flag))
		_expect_failure(flagged, good, "non-boolean enrage flag " + str(bad_flag))
	for bad_stacks in [-1, 4, 5, 1.5, "2", true, null, []]:
		var stacked := healthy.duplicate(true)
		stacked["enrage_stacks"] = bad_stacks
		_check(stacked.get("enrage_stacks") == bad_stacks,
			"fixture: invalid stack count " + str(bad_stacks))
		_expect_failure(stacked, good, "invalid stack count " + str(bad_stacks))
	# Valid boundary values still quote normally after all the rejections.
	var top := _enemies(40, true, 2)
	var top_hit := _confirmed(top, 4, "valid boundary stacks")
	_check(_quote(top_hit[0], top_hit[1], "valid boundary stacks") == _enrage(3),
		"two valid stacks still reach the cap after rejected snapshots")


func _test_immutability_replay_and_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77123
	var state_before := rng.state
	seed(24601)
	var next_global := randi()
	seed(24601)
	var first_quote: Dictionary = {}
	var first_roster: Array[Dictionary] = []
	for repeat in range(3):
		var enemies := _enemies(40, true, 1)
		var pre := enemies.get_enemy(1)
		var receipt := attacks.resolve_vs_enemy(enemies, 1, 4, {}, {})
		var quote := _quote(pre, receipt, "replay %d" % repeat)
		_check(quote == _enrage(2), "replay %d: deterministic Enrage quote" % repeat)
		if repeat == 0:
			first_quote = quote.duplicate(true)
			first_roster = enemies.get_enemies()
			quote["enrage_stacks"] = 99
			quote["attack_bonus"] = 99
			_check(rules.quote_enrage_after_hit(pre, receipt) == _enrage(2),
				"mutating a returned quote cannot leak into the next quote")
		else:
			_check(quote == first_quote and enemies.get_enemies() == first_roster,
				"identical fixtures replay the same quote and roster snapshot")
	_check(rng.state == state_before, "Enrage quotes consume no seeded run RNG")
	_check(randi() == next_global, "Enrage quotes consume no global RNG")


## Thorns shares _valid_receipt/_valid_enemy_record, so its live contract stays
## exactly as before: positive and fully blocked hits retaliate, zero/failed/
## non-Thorns hits do not.
func _test_thorns_contract_unchanged() -> void:
	var thorns_enemy := {"id": "patch_imp", "hp": 20, "block": 0, "thorns": 3}
	var party := _party()
	_check(rules.resolve_thorns_retaliation(party, 1, thorns_enemy, _receipt(5, 0, 5))
		== {"ok": true, "applied": true, "thorns": 3, "block_absorbed": 0, "hp_loss": 3},
		"Thorns 3 still retaliates for one confirmed positive hit")
	var blocked_party := _party()
	_check(rules.resolve_thorns_retaliation(blocked_party, 1, thorns_enemy,
		_receipt(5, 5, 0))
		== {"ok": true, "applied": true, "thorns": 3, "block_absorbed": 0, "hp_loss": 3},
		"Thorns still retaliates for a fully absorbed positive hit")
	var zero_party := _party()
	_check(rules.resolve_thorns_retaliation(zero_party, 1, thorns_enemy, _receipt(0, 0, 0))
		== {"ok": true, "applied": false, "thorns": 3, "block_absorbed": 0, "hp_loss": 0},
		"Thorns still does nothing for a confirmed zero-damage hit")
	var plain_party := _party()
	_check(rules.resolve_thorns_retaliation(plain_party, 1,
		{"id": "patch_imp", "hp": 20, "block": 0}, _receipt(5, 0, 5))
		== {"ok": true, "applied": false, "thorns": 0, "block_absorbed": 0, "hp_loss": 0},
		"an enemy without Thorns still returns the zero-effect receipt")
	var before := party.get_heroes()
	_check(rules.resolve_thorns_retaliation(party, 1, thorns_enemy,
		{"ok": false, "damage": 5, "block_absorbed": 0, "hp_loss": 5})
		== {"ok": false, "applied": false, "thorns": 0, "block_absorbed": 0, "hp_loss": 0}
		and party.get_heroes() == before,
		"failed Thorns receipts still fail closed without hero mutation")


func _test_needle_marshal_thorns() -> void:
	# AC1: the real on-disk Elite record carries exactly Thorns 3.
	var marshal := _catalog_record(ELITE_CATALOG_PATH, "needle_marshal")
	_check(not marshal.is_empty(), "AC1: needle_marshal record exists in m04_elites.json")
	_check(marshal.get("id") == "needle_marshal"
		and marshal.get("name") == "Needle Marshal"
		and marshal.get("max_hp") == 28
		and marshal.get("thorns") == 3
		and marshal.get("bleed_on_attack") == true
		and marshal.get("art_path") == "res://assets/paper/enemies/needle_marshal.png",
		"AC1: authored Needle Marshal fields intact with thorns 3 and bleed_on_attack true")
	# AC1: V3-2 Enrage is authored as a genuine boolean on the Marshal alone, and
	# the record starts with no committed stacks.
	_check(marshal.get("enrage") is bool and marshal.get("enrage") == true
		and not marshal.has("enrage_stacks"),
		"AC1: the shipped Marshal authors boolean enrage true at zero stacks")
	_check(marshal.get("max_hp") is int and marshal.get("thorns") is int,
		"AC1: the Enrage Marshal keeps genuine integer HP and Thorns metadata")
	var marshal_intent: Dictionary = marshal.get("intent", {})
	_check(marshal_intent.get("target") == "front"
		and marshal_intent.get("actions", []).size() == 5,
		"AC1: the Enrage Marshal keeps its front target with three attacks and two support actions")
	var marshal_actions: Array = []
	for raw in marshal_intent.get("actions", []):
		var weighted := CombatEnemyIntents.weighted_action(raw)
		var body: Dictionary = weighted.get("action", {}).duplicate(true)
		body["weight"] = weighted.get("weight", 0)
		marshal_actions.append(body)
	_check(marshal_actions == [
			{"type": "attack", "amount": 5, "weight": 2},
			{"type": "attack", "amount": 4, "move": "attack2", "weight": 1},
			{"type": "attack", "amount": 6, "move": "attack3", "weight": 1},
			{"type": "buff", "amount": 3, "weight": 1},
			{"type": "shove", "amount": 0, "direction": 1, "weight": 1}],
		"AC1: the five exact weighted alternatives preserve attack weight four")
	var enraged_records: Array = _catalog_records(ELITE_CATALOG_PATH).filter(
		func(record: Dictionary) -> bool:
			return record.get("enrage") is bool and record.get("enrage") == true)
	_check(enraged_records.size() == 1
		and enraged_records[0].get("id") == "needle_marshal",
		"AC1: the shipped Elite catalog authors Enrage on the Marshal alone")
	for id in ["spool_hexer", "scissor_bailiff", "zipper_hauler",
			"needle_briar_guard", "spool_snarekeeper", "pincushion_matriarch",
			"spool_leech"]:
		var other := _catalog_record(ELITE_CATALOG_PATH, id)
		_check(not other.is_empty() and not other.has("enrage"),
			"AC1: the named older Elite gains no Enrage flag " + id)
	var older_hp := {"spool_hexer": 24, "scissor_bailiff": 36, "zipper_hauler": 38,
		"needle_briar_guard": 42, "spool_snarekeeper": 40,
		"pincushion_matriarch": 44, "spool_leech": 42}
	for id in older_hp:
		var older := _catalog_record(ELITE_CATALOG_PATH, id)
		_check(older.get("id") == id and older.get("max_hp") == older_hp[id]
			and older.get("max_hp") is int,
			"AC1: the named older Elite keeps its exact HP " + id)
	# Existing companions remain untouched.
	_check(_catalog_record(ELITE_CATALOG_PATH, "spool_hexer").get("max_hp") == 24
		and not _catalog_record(ELITE_CATALOG_PATH, "spool_hexer").has("thorns"),
		"AC1: spool_hexer unchanged (no thorns)")
	_check(_catalog_record(ELITE_CATALOG_PATH, "scissor_bailiff").get("max_hp") == 36,
		"AC1: scissor_bailiff unchanged")
	# AC1: typed pool and encounter routing intact.
	var typed_text := FileAccess.get_file_as_string(TYPED_POOLS_PATH)
	_check(typed_text.contains("needle_marshal_elite")
		and typed_text.contains("res://data/encounters/needle_marshal_elite.json"),
		"AC1: typed battle pool contains the needle_marshal_elite route and schedule")
	var encounter_text := FileAccess.get_file_as_string(MARSHAL_ENCOUNTER_PATH)
	_check(encounter_text.contains("["),
		"AC1: needle_marshal_elite encounter file parses")
	# Real roster and party fixtures from shipped records.
	var escort := _catalog_record("res://data/enemies/starter_enemies.json", "ragling_guard")
	_check(escort.get("id") == "ragling_guard" and escort.get("max_hp") == 12,
		"fixture: ragling_guard companion from starter catalog")
	var enemies := _marshal_roster(marshal, escort)
	var party := _party()
	# AC2: real confirmed positive hit via resolve_vs_enemy on authored Marshal.
	var hit_enemies := _marshal_roster(marshal.duplicate(true), escort.duplicate(true))
	var hit_pre := hit_enemies.get_enemy(1)
	var hit_receipt := attacks.resolve_vs_enemy(hit_enemies, 1, 5, {}, {})
	_check(hit_receipt.get("ok", false) and hit_receipt.get("damage") == 5,
		"AC2: authentic positive-damage receipt from real marshal hit")
	var hit_before_heroes := party.get_heroes()
	var result := rules.resolve_thorns_retaliation(party, 1, hit_pre, hit_receipt)
	_check(result == {"ok": true, "applied": true, "thorns": 3,
		"block_absorbed": 0, "hp_loss": 3},
		"AC2: confirmed positive hit retaliates exactly Thorns 3")
	# Assert precise enemy state change: Marshal lost 5 HP, no block.
	_check(hit_enemies.get_enemy(1).get("hp") == 23,
		"AC2: real marshal HP dropped from 28 to 23 after 5 damage")
	# Assert actual hero state change from retaliation.
	var attacker_after := party.get_hero(1)
	_check(attacker_after.get("hp") == 37,
		"AC2: attacking hero lost 3 HP from retaliation")
	# Assert untouched other heroes.
	_check(party.get_hero(2) == hit_before_heroes[1] and party.get_hero(3) == hit_before_heroes[2],
		"AC2: other heroes untouched by retaliation")
	# Assert pre-hit snapshot and receipt are immutable.
	_check(hit_pre.get("id") == "needle_marshal" and hit_pre.get("hp") == 28
		and hit_pre.get("thorns") == 3,
		"AC2: pre-hit marshal snapshot unchanged after retaliation")
	_check(hit_receipt.get("ok") == true and hit_receipt.get("damage") == 5,
		"AC2: original receipt unchanged after retaliation")
	# AC2: fully enemy-Block-absorbed hit still retaliates 3.
	var blocked_enemies := _marshal_roster(marshal.duplicate(true), escort.duplicate(true))
	blocked_enemies.gain_block(1, 10)
	var blocked_pre := blocked_enemies.get_enemy(1)
	var blocked_receipt := attacks.resolve_vs_enemy(blocked_enemies, 1, 5, {}, {})
	_check(blocked_receipt.get("ok", false) and blocked_receipt.get("damage") == 5
		and blocked_receipt.get("block_absorbed") == 5 and blocked_receipt.get("hp_loss") == 0,
		"AC2: fully blocked positive hit produces authentic receipt")
	var blocked_result := rules.resolve_thorns_retaliation(party, 1, blocked_pre, blocked_receipt)
	_check(blocked_result == {"ok": true, "applied": true, "thorns": 3,
		"block_absorbed": 0, "hp_loss": 3},
		"AC2: fully blocked positive hit still retaliates 3")
	# Assert blocked marshal still at 28 HP; retaliation hits attacker.
	_check(blocked_enemies.get_enemy(1).get("hp") == 28,
		"AC2: blocked marshal HP unchanged at 28")
	# AC2: partial hero Block absorbs retaliation first.
	var partial_party := _party()
	partial_party.gain_block(1, 1)
	var partial_before := partial_party.get_hero(1)
	# Build fresh marshal for partial-block case.
	var partial_enemies := _marshal_roster(marshal.duplicate(true), escort.duplicate(true))
	var partial_pre := partial_enemies.get_enemy(1)
	var partial_receipt := attacks.resolve_vs_enemy(partial_enemies, 1, 5, {}, {})
	var partial_result := rules.resolve_thorns_retaliation(partial_party, 1, partial_pre, partial_receipt)
	_check(partial_result == {"ok": true, "applied": true, "thorns": 3,
		"block_absorbed": 1, "hp_loss": 2},
		"AC2: hero partial block (1) absorbs retaliation before HP (3 -> 1 block + 2 hp)")
	var partial_attacker_after := partial_party.get_hero(1)
	_check(partial_attacker_after.get("block") == 0 and partial_attacker_after.get("hp") == 38,
		"AC2: partial block hero: 1 block + 2 hp lost = 3 retaliation")
	# AC3: zero-damage receipt generated through the real bridge.
	var zero_enemies := _marshal_roster(marshal.duplicate(true), escort.duplicate(true))
	var zero_pre := zero_enemies.get_enemy(1)
	var zero_receipt := attacks.resolve_vs_enemy(zero_enemies, 1, 0, {}, {})
	_check(zero_receipt.get("ok", false) and zero_receipt.get("damage") == 0,
		"AC3: zero-damage receipt generated through real resolve_vs_enemy bridge")
	# Verify no mutation by zero-damage retaliation.
	var zero_before_heroes := party.get_heroes()
	var zero_result := rules.resolve_thorns_retaliation(party, 1, zero_pre, zero_receipt)
	_check(zero_result == {"ok": true, "applied": false, "thorns": 3,
		"block_absorbed": 0, "hp_loss": 0},
		"AC3: zero-damage receipt produces no retaliation")
	# Verify no mutation by zero-damage retaliation.
	_check(party.get_heroes() == zero_before_heroes,
		"AC3: party unchanged after zero-damage retaliation")
	# AC3: failed receipt fails closed.
	var fail_before := party.get_heroes()
	var fail_result := rules.resolve_thorns_retaliation(party, 1, zero_pre,
		{"ok": false, "damage": 5, "block_absorbed": 0, "hp_loss": 5})
	_check(fail_result == {"ok": false, "applied": false, "thorns": 0,
		"block_absorbed": 0, "hp_loss": 0}
		and party.get_heroes() == fail_before,
		"AC3: failed receipt fails closed without mutation")
	# AC3: non-Thorns neighbor does not invent retaliation.
	var plain_result := rules.resolve_thorns_retaliation(party, 1,
		{"id": "spool_hexer", "hp": 24, "block": 0}, _receipt(5, 0, 5))
	_check(plain_result == {"ok": true, "applied": false, "thorns": 0,
		"block_absorbed": 0, "hp_loss": 0},
		"AC3: non-Thorns enemy produces no retaliation")
	# AC3: RNG/state untouched by non-hit probes.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var state_before := rng.state
	seed(99999)
	var global_before := randi()
	rules.resolve_thorns_retaliation(party, 1, hit_pre, _receipt(0, 0, 0))
	_check(rng.state == state_before,
		"AC3: zero-thorns receipt consumes no local RNG state")
	seed(99999)
	_check(randi() == global_before,
		"AC3: non-hit probe consumes no global RNG")
	# AC1: existing bleed-on-attack preserved in authored record.
	_check(marshal.get("bleed_on_attack") == true,
		"AC1: Marshal retains bleed_on_attack true for bleeding sting")


## The shipped typed Marshal route assembled by the production roster bridge from
## the real catalog, encounter schedule and roster bindings.
func _typed_marshal_roster() -> CombatEnemies:
	var schedule := RunFightEncounterSelection._parse_schedule_text(
		FileAccess.get_file_as_string(MARSHAL_ENCOUNTER_PATH))
	_check(not schedule.is_empty(),
		"fixture: the shipped needle_marshal_elite schedule parses")
	var assembled := RunTypedBattleRoster.new().assemble(
		{"success": true, "node_type": "Elite",
		"encounter_id": "needle_marshal_elite", "definitions": schedule},
		{"needle_marshal_elite": ["needle_marshal", "ragling_guard"]},
		[ELITE_CATALOG_PATH, STARTER_CATALOG_PATH])
	var enemies: CombatEnemies = assembled.get("enemies")
	_check(assembled.get("ok", false) and enemies != null and enemies.is_valid()
		and enemies.get_enemies().size() == 2
		and enemies.get_enemy(1).get("id") == "needle_marshal"
		and enemies.get_enemy(1).get("enrage") == true
		and enemies.get_enemy(1).get("hp") == 28
		and enemies.get_enemy(2).get("id") == "ragling_guard"
		and enemies.get_enemy(2).get("hp") == 12
		and not enemies.get_enemy(1).has("enrage_stacks"),
		"fixture: production typed roster carries the living Enrage Marshal at zero stacks")
	return enemies


## One exact expected roster derived from an earlier snapshot: only the Marshal's
## HP, Block and committed stack count may differ.
func _roster_with(initial: Array, hp: int, stacks: Variant, block: int = 0) -> Array:
	var expected := initial.duplicate(true)
	expected[0]["hp"] = hp
	expected[0]["block"] = block
	if stacks == null:
		expected[0].erase("enrage_stacks")
	else:
		expected[0]["enrage_stacks"] = stacks
	return expected


## Anonymous enemies and receipts are never mutated by a commit, and a commit that
## decides not to apply cannot touch any roster field.
func _commit(enemies: CombatEnemies, position: int, pre_hit_enemy: Dictionary,
		receipt: Dictionary, label: String) -> Dictionary:
	var roster_before := enemies.get_enemies()
	var pre_before := pre_hit_enemy.duplicate(true)
	var receipt_before := receipt.duplicate(true)
	var result := rules.commit_enrage_after_hit(
		enemies, position, pre_hit_enemy, receipt)
	_check(pre_hit_enemy == pre_before and receipt == receipt_before,
		label + ": commit leaves the pre-hit snapshot and receipt unchanged")
	if result.get("ok", false) and not result.get("applied", true):
		_check(enemies.get_enemies() == roster_before,
			label + ": an inert commit changes no roster field")
	return result


## A rejected commit must fail closed: no result, no roster change, no input change.
func _expect_commit_failure(enemies: CombatEnemies, position: int,
		pre_hit_enemy: Dictionary, receipt: Dictionary, label: String) -> void:
	var roster_before: Array = [] if enemies == null else enemies.get_enemies()
	var pre_before := pre_hit_enemy.duplicate(true)
	var receipt_before := receipt.duplicate(true)
	var result := rules.commit_enrage_after_hit(
		enemies, position, pre_hit_enemy, receipt)
	_check(result == _failure(),
		label + ": commit reports ok=false with no stacks or attack bonus")
	_check(pre_hit_enemy == pre_before and receipt == receipt_before,
		label + ": failed commit leaves its inputs unchanged")
	if enemies != null:
		_check(enemies.get_enemies() == roster_before,
			label + ": failed commit changes no roster HP, Block, statuses or stacks")


## AC2: one commit call writes exactly the quoted stack on the same authoritative
## Marshal and nothing else; its result is detached.
func _test_enrage_commit_contract() -> void:
	_check(rules.has_method("commit_enrage_after_hit"),
		"scene-free keyword rules expose the authoritative Enrage commit")
	var enemies := _typed_marshal_roster()
	var initial := enemies.get_enemies()
	var pre := enemies.get_enemy(1)
	var receipt := attacks.resolve_vs_enemy(enemies, 1, 5, {}, {})
	_check(receipt == _receipt(5, 0, 5),
		"commit precondition: one authentic confirmed five-damage hit")
	var result := _commit(enemies, 1, pre, receipt, "first commit")
	_check(result == _enrage(1) and result.get("attack_bonus") == 2,
		"the first confirmed hit persists exactly one stack and +2 attack")
	_check(enemies.get_enemies() == _roster_with(initial, 23, 1),
		"the commit writes only the stack: 28 -> 23 HP, zero Block, one stack")
	result["enrage_stacks"] = 99
	result["attack_bonus"] = 198
	_check(enemies.get_enemy(1).get("enrage_stacks") == 1
		and enemies.get_enemy(1).get("hp") == 23,
		"mutating the returned result cannot alter the authoritative enemy")


## AC2: successive confirmed hits on the real routed Marshal persist 1/+2, 2/+4,
## 3/+6 and stop at the cap, with the complete roster proven after every call.
func _test_enrage_commit_chain() -> void:
	var enemies := _typed_marshal_roster()
	var initial := enemies.get_enemies()
	var expected := [[1, 2], [2, 4], [3, 6]]
	for step in range(3):
		var pre := enemies.get_enemy(1)
		_check(pre.get("enrage") == true and pre.get("enrage_stacks", 0) == step
			and pre.get("hp") == 28 - 4 * step,
			"chain hit %d: genuine pre-hit snapshot at %d stacks" % [step, step])
		var receipt := attacks.resolve_vs_enemy(enemies, 1, 4, {}, {})
		_check(receipt == _receipt(4, 0, 4),
			"chain hit %d: authentic confirmed four-damage receipt" % step)
		var result := _commit(enemies, 1, pre, receipt, "chain hit %d" % step)
		var want: Array = expected[step]
		_check(result == _enrage(want[0]) and result.get("attack_bonus") == want[1],
			"chain hit %d persists %d stacks and +%d attack"
				% [step, want[0], want[1]])
		_check(enemies.get_enemies()
			== _roster_with(initial, 28 - 4 * (step + 1), want[0]),
			"chain hit %d changes only the Marshal HP and stack count" % step)
	var capped_pre := enemies.get_enemy(1)
	var capped_receipt := attacks.resolve_vs_enemy(enemies, 1, 4, {}, {})
	var capped_before := enemies.get_enemies()
	var capped := _commit(enemies, 1, capped_pre, capped_receipt, "capped fourth hit")
	_check(capped == _no_op(3),
		"a fourth confirmed hit stays at three stacks and +6 attack")
	_check(enemies.get_enemies() == capped_before,
		"the capped fourth hit writes no stack and no other roster field")
	_check(enemies.get_enemy(2).get("hp") == 12
		and enemies.get_enemy(2).get("block") == 0,
		"the escort keeps its exact HP and Block through the whole chain")


## AC2/AC3: Block absorption, zero damage and a lethal hit each behave exactly
## like the quote, and a slain source is never revived by its stack gain.
func _test_enrage_commit_blocked_zero_and_lethal() -> void:
	var blocked := _typed_marshal_roster()
	_check(blocked.gain_block(1, 10), "fixture: ten Block absorbs the whole hit")
	var blocked_initial := blocked.get_enemies()
	var blocked_pre := blocked.get_enemy(1)
	var blocked_receipt := attacks.resolve_vs_enemy(blocked, 1, 6, {}, {})
	_check(blocked_receipt == _receipt(6, 6, 0),
		"fixture: confirmed positive hit fully absorbed by defender Block")
	var blocked_result := _commit(blocked, 1, blocked_pre, blocked_receipt,
		"fully blocked hit")
	_check(blocked_result == _enrage(1),
		"a fully Block-absorbed positive hit still commits one stack")
	_check(blocked.get_enemies() == _roster_with(blocked_initial, 28, 1, 4),
		"the blocked commit keeps 28 HP, spends exactly six Block and adds one stack")

	var idle := _typed_marshal_roster()
	var idle_pre := idle.get_enemy(1)
	var idle_receipt := attacks.resolve_vs_enemy(idle, 1, 0, {}, {})
	_check(idle_receipt == _receipt(0, 0, 0),
		"fixture: confirmed zero-damage receipt from the real bridge")
	var idle_before := idle.get_enemies()
	var idle_result := _commit(idle, 1, idle_pre, idle_receipt, "zero-damage hit")
	_check(idle_result == _no_op(0),
		"a zero-damage hit grants no stack and no bonus")
	_check(idle.get_enemies() == idle_before,
		"a zero-damage commit leaves every roster field as it was")

	var lethal := _typed_marshal_roster()
	_check(lethal.apply_damage(1, 23) and lethal.get_enemy(1).get("hp") == 5,
		"fixture: the real Marshal is genuinely down to five HP")
	var lethal_pre := lethal.get_enemy(1)
	var lethal_receipt := attacks.resolve_vs_enemy(lethal, 1, 9, {}, {})
	_check(lethal_receipt == _receipt(9, 0, 5) and lethal.is_slain(1),
		"fixture: confirmed overkill receipt leaves the Marshal slain")
	var lethal_result := _commit(lethal, 1, lethal_pre, lethal_receipt, "lethal hit")
	_check(lethal_result == _enrage(1),
		"a lethal confirmed hit still commits one stack")
	_check(lethal.get_enemy(1).get("hp") == 0 and lethal.is_slain(1)
		and lethal.get_enemy(1).get("enrage_stacks") == 1
		and lethal.get_enemy(1).get("block") == 0,
		"the slain Marshal stays dead at zero HP and only gains the stack")
	_check(lethal.get_enemy(2).get("hp") == 12,
		"the living escort is untouched by the lethal commit")


## AC2/AC3: real non-Enrage sources stay inert with no new stack key.
func _test_enrage_commit_inert_sources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55219
	var rng_before := rng.state
	seed(30411)
	var global_before := randi()
	seed(30411)
	var hexer := _catalog_record(ELITE_CATALOG_PATH, "spool_hexer")
	var escort := _catalog_record(STARTER_CATALOG_PATH, "ragling_guard")
	_check(hexer.get("max_hp") == 24 and not hexer.has("enrage"),
		"fixture: the real Spool Hexer authors no Enrage flag")
	var plain := CombatEnemies.new([hexer.duplicate(true), escort.duplicate(true)])
	_check(plain.is_valid() and plain.get_enemy(1).get("id") == "spool_hexer",
		"fixture: a living non-Enrage Spool Hexer roster")
	var plain_pre := plain.get_enemy(1)
	var plain_receipt := attacks.resolve_vs_enemy(plain, 1, 5, {}, {})
	var plain_before := plain.get_enemies()
	var plain_result := _commit(plain, 1, plain_pre, plain_receipt, "non-Enrage hit")
	_check(plain_result == _no_op(0),
		"a confirmed hit on a non-Enrage source is an inert success")
	_check(plain.get_enemies() == plain_before
		and not plain.get_enemy(1).has("enrage_stacks"),
		"a non-Enrage source gains no stack key and no other change")

	var disabled_record := hexer.duplicate(true)
	disabled_record["enrage"] = false
	disabled_record["enrage_stacks"] = 2
	var disabled := CombatEnemies.new([disabled_record, escort.duplicate(true)])
	_check(disabled.is_valid() and disabled.get_enemy(1).get("enrage") == false
		and disabled.get_enemy(1).get("enrage_stacks") == 2,
		"fixture: explicitly disabled Enrage with leftover valid stack metadata")
	var disabled_pre := disabled.get_enemy(1)
	var disabled_receipt := attacks.resolve_vs_enemy(disabled, 1, 4, {}, {})
	var disabled_before := disabled.get_enemies()
	var disabled_result := _commit(disabled, 1, disabled_pre, disabled_receipt,
		"disabled keyword hit")
	_check(disabled_result == _no_op(0),
		"an explicitly disabled keyword grants no stack or bonus")
	_check(disabled.get_enemies() == disabled_before
		and disabled.get_enemy(1).get("enrage_stacks") == 2,
		"a disabled keyword keeps its leftover stack metadata untouched")
	_check(rng.state == rng_before and randi() == global_before,
		"inert Enrage commits consume no local seeded or global RNG")


## AC3: bad rosters, slots, identities, metadata and receipts fail closed before
## any write, and the untrusted pair stays inert until a genuine commit.
func _test_enrage_commit_rejections() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 44801
	var rng_before := rng.state
	seed(91825)
	var global_before := randi()
	seed(91825)
	var enemies := _typed_marshal_roster()
	var pre := enemies.get_enemy(1)
	var receipt := attacks.resolve_vs_enemy(enemies, 1, 4, {}, {})
	_check(receipt == _receipt(4, 0, 4),
		"rejection precondition: one authentic confirmed hit on the real Marshal")
	var post_hit := enemies.get_enemies()
	# The pair is otherwise valid: only the tested defect may reject it.
	_expect_commit_failure(null, 1, pre, receipt, "null roster")
	_expect_commit_failure(CombatEnemies.new([]), 1, pre, receipt, "invalid roster")
	for bad_position in [0, -1, 4, 99]:
		_expect_commit_failure(enemies, bad_position, pre, receipt,
			"position outside the roster " + str(bad_position))
	_expect_commit_failure(enemies, 2, pre, receipt,
		"slot 1 snapshot committed on slot 2")
	var wrong_id := pre.duplicate(true)
	wrong_id["id"] = "spool_hexer"
	_expect_commit_failure(enemies, 1, wrong_id, receipt, "mismatched enemy identity")
	var wrong_max := pre.duplicate(true)
	wrong_max["max_hp"] = 40
	_expect_commit_failure(enemies, 1, wrong_max, receipt, "mismatched maximum HP")
	var wrong_slot := pre.duplicate(true)
	wrong_slot["position"] = 2
	_expect_commit_failure(enemies, 1, wrong_slot, receipt, "snapshot from another slot")
	var wrong_flag := pre.duplicate(true)
	wrong_flag["enrage"] = false
	_expect_commit_failure(enemies, 1, wrong_flag, receipt, "disagreeing enrage flag")
	var stale_stacks := pre.duplicate(true)
	stale_stacks["enrage_stacks"] = 2
	_expect_commit_failure(enemies, 1, stale_stacks, receipt,
		"stale committed stack count")
	var stale_hp := pre.duplicate(true)
	stale_hp["hp"] = 24
	_expect_commit_failure(enemies, 1, stale_hp, receipt,
		"post-hit snapshot reused as a pre-hit record")
	for bad_flag in [1, "true", null, [], {}]:
		var flagged := pre.duplicate(true)
		flagged["enrage"] = bad_flag
		_check(flagged.get("enrage") == bad_flag,
			"fixture: non-boolean enrage flag " + str(bad_flag))
		_expect_commit_failure(enemies, 1, flagged, receipt,
			"non-boolean enrage flag " + str(bad_flag))
	for bad_stacks in [-1, 4, 5, 1.5, "2", true, null, []]:
		var stacked := pre.duplicate(true)
		stacked["enrage_stacks"] = bad_stacks
		_check(stacked.get("enrage_stacks") == bad_stacks,
			"fixture: invalid stack count " + str(bad_stacks))
		_expect_commit_failure(enemies, 1, stacked, receipt,
			"invalid stack count " + str(bad_stacks))
	for bad_record in [{}, {"enrage": true}, {"hp": 0, "enrage": true},
			{"hp": -1, "enrage": true}, {"hp": "12", "enrage": true},
			{"hp": 12, "block": -2, "enrage": true},
			{"hp": 12, "thorns": -1, "enrage": true}]:
		_expect_commit_failure(enemies, 1, bad_record, receipt,
			"invalid pre-hit record " + str(bad_record))
	_check(enemies.get_enemies() == post_hit,
		"every rejected call leaves the complete post-hit roster untouched")

	# Forged or other-target receipts on an untouched real roster.
	var clean := _typed_marshal_roster()
	var clean_pre := clean.get_enemy(1)
	var clean_before := clean.get_enemies()
	_check(clean_pre.get("hp") == 28 and clean_pre.get("block") == 0,
		"fixture: untouched Marshal snapshot for forged-receipt cases")
	for bad in [
			{"ok": false, "damage": 4, "block_absorbed": 0, "hp_loss": 4},
			{}, {"ok": true}, {"ok": true, "damage": 4, "block_absorbed": 0},
			{"ok": 1, "damage": 4, "block_absorbed": 0, "hp_loss": 4},
			{"ok": true, "damage": 4.5, "block_absorbed": 0, "hp_loss": 4},
			{"ok": true, "damage": -4, "block_absorbed": 0, "hp_loss": 0},
			{"ok": true, "damage": 4, "block_absorbed": 1, "hp_loss": 3},
			{"ok": true, "damage": 4, "block_absorbed": 0, "hp_loss": 3},
			{"ok": true, "damage": 4, "block_absorbed": 0, "hp_loss": 5},
			{"ok": true, "damage": 4, "block_absorbed": 6, "hp_loss": 0},
			{"ok": true, "damage": 30, "block_absorbed": 0, "hp_loss": 30}]:
		_expect_commit_failure(clean, 1, clean_pre, bad,
			"forged or other-target receipt " + str(bad))
	_check(clean.get_enemies() == clean_before,
		"forged receipts leave the full-health Marshal and its escort untouched")
	_check(rng.state == rng_before and randi() == global_before,
		"no failed commit consumes local seeded or global RNG")

	# The genuine pair still commits once after every rejection.
	var applied := _commit(enemies, 1, pre, receipt, "genuine pair after rejections")
	_check(applied == _enrage(1) and enemies.get_enemy(1).get("enrage_stacks") == 1,
		"a genuine confirmed hit still commits exactly one stack after rejections")


## AC3: identical hits replay the same commit, and no commit touches any RNG.
func _test_enrage_commit_replay_and_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 60144
	var rng_before := rng.state
	seed(73921)
	var global_before := randi()
	seed(73921)
	var first: Dictionary = {}
	var first_roster: Array = []
	for repeat in range(3):
		var enemies := _typed_marshal_roster()
		var pre := enemies.get_enemy(1)
		var receipt := attacks.resolve_vs_enemy(enemies, 1, 4, {}, {})
		var result := _commit(enemies, 1, pre, receipt, "commit replay %d" % repeat)
		_check(result == _enrage(1),
			"commit replay %d: deterministic one-stack result" % repeat)
		if repeat == 0:
			first = result.duplicate(true)
			first_roster = enemies.get_enemies()
		else:
			_check(result == first and enemies.get_enemies() == first_roster,
				"identical hits replay the same commit result and roster state")
	_check(rng.state == rng_before, "Enrage commits consume no local seeded RNG")
	_check(randi() == global_before, "Enrage commits consume no global RNG")
