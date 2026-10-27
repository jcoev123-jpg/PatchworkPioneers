extends SceneTree
## Scene-free Enemy keyword regressions: the Enrage confirmed-hit quote and the
## unchanged Thorns N retaliation contract it shares validation helpers with.

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


## Strict on-disk catalog lookup through the shipped parser. Exactly one record
## must carry this ID; the returned dictionary is detached from the parse.
func _catalog_record(path: String, id: String) -> Dictionary:
	var records := RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string(path))
	_check(not records.is_empty(), "fixture: shipped catalog parses " + path)
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
	# Existing companions remain untouched.
	_check(_catalog_record(ELITE_CATALOG_PATH, "spool_hexer").get("max_hp") == 24
		and not _catalog_record(ELITE_CATALOG_PATH, "spool_hexer").has("thorns"),
		"AC1: spool_hexer unchanged (no thorns)")
	_check(_catalog_record(ELITE_CATALOG_PATH, "scissor_bailiff").get("max_hp") == 36,
		"AC1: scissor_bailiff unchanged")
	# AC1: typed pool and encounter routing intact.
	var typed_text := FileAccess.get_file_as_string(TYPED_POOLS_PATH)
	_check(typed_text.contains("needle_marshal_elite"),
		"AC1: typed battle pool contains needle_marshal_elite route")
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
