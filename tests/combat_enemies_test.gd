extends SceneTree

var failures: Array[String] = []
var checks := 0
var attacks := CombatStatusAttacks.new()
var rules := CombatEnemyKeywordRules.new()


func _initialize() -> void:
	_test_construction()
	_test_broodling_model()
	_test_invalid_construction()
	_test_required_queries()
	_test_status_transaction()
	_test_healing()
	_test_drain_after_hit()
	for count in range(1, 4):
		_test_damage_and_death(count)
		_test_rejections(count)
		_test_replay(count)
	if failures.is_empty():
		print("combat_enemies_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_enemies_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_status_transaction() -> void:
	var enemies := CombatEnemies.new(_definitions(3))
	var identity: Dictionary = enemies._enemies[0]
	var additions := {1: {"bleed": 3}, 3: {"weak": 1}}
	var input := additions.duplicate(true)
	_check(enemies.can_apply_statuses(additions) and enemies.apply_statuses(additions), "valid status batch commits")
	_check(enemies.apply_statuses({1: {"bleed": 3, "exposed": 2}}), "repeated statuses add")
	var expected := _expected(3)
	expected[0]["statuses"] = {"bleed": 6, "exposed": 2}
	expected[2]["statuses"] = {"weak": 1}
	_check(enemies.get_enemies() == expected and is_same(identity, enemies._enemies[0]), "only named counters change, identity and slots retained")
	_check(additions == input, "transaction input immutable")
	for bad in [{1: {"bleed": 1}, 4: {"weak": 1}}, {1: {"bleed": 1}, 3: {"weak": -1}},
		{1: {"bleed": 1}, 3: {"weak": 1.5}}, {"1": {}}, {2: []}, {2: {"poison": 1}},
		{1: {"bleed": CombatEnemies.MAX_INT}}, {1: {"bleed": 1}, 3: {"weak": CombatEnemies.MAX_INT}}, {2: {8: 1}}]:
		_check(not enemies.can_apply_statuses(bad) and not enemies.apply_statuses(bad), "bad late entry or overflow rejects")
		_check(enemies.get_enemies() == expected, "failed status transaction is atomic")
	for malformed in [[], {"weak": -1}, {"exposed": "1"}, {"unknown": 1}]:
		enemies._enemies[2]["statuses"] = malformed
		var before := enemies.get_enemies()
		_check(not enemies.apply_statuses({1: {"bleed": 1}}) and enemies.get_enemies() == before, "malformed untouched slot rejects whole transaction")
	enemies._enemies[2]["statuses"] = {"weak": 1}
	_check(enemies.apply_damage(1, 100) and enemies.apply_statuses({1: {"bleed": 1}}), "confirmed lethal recipient accepts status without revival")
	_check(enemies.is_slain(1) and enemies.get_enemy(1).statuses == {"bleed": 7, "exposed": 2}, "lethal status retains original record")
	var before := enemies.get_enemies()
	_check(enemies.apply_statuses({1: {"bleed": 0}, 2: {}}) and enemies.get_enemies() == before, "zero additions preserve exact records")
	_check(enemies.apply_statuses({3: {"weak": CombatEnemies.MAX_INT - 1}})
		and enemies.get_enemy(3).statuses.weak == CombatEnemies.MAX_INT, "status counter reaches maximum without overflow")
	enemies._enemies[2]["position"] = 2
	before = enemies.get_enemies()
	_check(not enemies.apply_statuses({1: {"bleed": 1}}) and enemies.get_enemies() == before, "invalid original slot rejects atomically")


## The bounded heal primitive: exact HP restore, clamp at max_hp, no revival.
func _test_healing() -> void:
	var enemies := CombatEnemies.new(_definitions(3))
	var identity: Dictionary = enemies._enemies[1]
	_check(enemies.apply_damage(2, 6) and enemies.gain_block(2, 3)
		and enemies.apply_statuses({2: {"weak": 2}}), "fixture: wounded recipient carries Block and statuses")
	var expected := _expected(3)
	expected[1]["hp"] = 6
	expected[1]["block"] = 3
	expected[1]["statuses"] = {"weak": 2}
	_check(enemies.get_enemies() == expected, "fixture: exact wounded state before healing")
	_check(enemies.heal(2, 4), "heal succeeds on a living wounded slot")
	expected[1]["hp"] = 10
	_check(enemies.get_enemies() == expected and is_same(identity, enemies._enemies[1]),
		"heal restores exact HP and preserves identity, slot, Block and statuses")
	_check(enemies.heal(2, CombatEnemies.MAX_INT) and enemies.get_enemy(2)["hp"] == expected[1]["max_hp"],
		"large heal clamps to maximum HP without overflow")
	expected[1]["hp"] = expected[1]["max_hp"]
	_check(enemies.get_enemies() == expected, "maximum clamp leaves every other field exact")
	var before := enemies.get_enemies()
	_check(enemies.heal(2, 5) and enemies.get_enemies() == before, "healing a full-HP slot is a no-op success")
	_check(enemies.heal(2, 0) and enemies.get_enemies() == before, "zero heal on a living slot succeeds without change")
	_check(enemies.apply_damage(1, CombatEnemies.MAX_INT) and enemies.is_slain(1), "fixture: slot genuinely slain")
	before = enemies.get_enemies()
	for amount in [0, 1, CombatEnemies.MAX_INT]:
		_check(not enemies.heal(1, amount) and enemies.get_enemies() == before, "heal never revives a slain slot")
	_check(enemies.apply_damage(3, 2) and enemies.heal(3, 1) and enemies.get_enemy(3)["hp"] == 12,
		"wounded neighbors heal independently")
	for position in [-100, -1, 0, 4, 100]:
		_reject(enemies, "heal", position, 1)
	for position in range(1, 4):
		_reject(enemies, "heal", position, -1)
		_reject(enemies, "heal", position, -CombatEnemies.MAX_INT - 1)


func _definitions(count: int) -> Array:
	var definitions: Array = []
	for index in range(count):
		definitions.append({"id": "fixture_%d" % index, "max_hp": 11 + index,
			"metadata": {"tags": ["synthetic"]}, "position": -1, "hp": -1, "block": -1})
	return definitions


func _expected(count: int) -> Array:
	var expected := _definitions(count)
	for index in range(count):
		expected[index]["position"] = index + 1
		expected[index]["hp"] = expected[index]["max_hp"]
		expected[index]["block"] = 0
	return expected


func _party() -> CombatParty:
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	_check(party.is_valid() and party.get_heroes().size() == 3,
		"fixture: all three real living heroes")
	return party


## A real two-enemy roster whose source is a 24 HP Drain enemy. Pass null to omit
## the optional `drain` key entirely; any other value is stored as given.
func _drain_roster(drain: Variant = true) -> CombatEnemies:
	var source := {"id": "bobbin_bat_fixture", "max_hp": 24,
		"metadata": {"tags": ["synthetic"]}}
	if drain != null:
		source["drain"] = drain
	var enemies := CombatEnemies.new([source,
		{"id": "neighbor_fixture", "max_hp": 18, "metadata": {"tags": ["synthetic"]}}])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2,
		"fixture: valid living two-enemy roster")
	return enemies


## Invoke Drain and prove the only permitted change is the source's HP, exactly
## matching a reported `applied` heal. The caller's receipt must stay identical.
func _resolve_drain(enemies: CombatEnemies, position: int, receipt: Dictionary,
		label: String) -> Dictionary:
	var before: Array[Dictionary] = enemies.get_enemies()
	var receipt_before := receipt.duplicate(true)
	var result := rules.resolve_drain_after_hit(enemies, position, receipt)
	_check(receipt == receipt_before, label + ": the caller's attack receipt is unchanged")
	var after: Array[Dictionary] = enemies.get_enemies()
	if result.get("applied") == true:
		_check(after.size() == before.size(), label + ": roster size preserved")
		for index in range(after.size()):
			if index != position - 1:
				_check(after[index] == before[index], label + ": other enemy records preserved")
			else:
				var source: Dictionary = before[index].duplicate(true)
				source["hp"] += result["healed"]
				_check(after[index] == source, label + ": only the source HP changed")
	else:
		_check(after == before, label + ": roster unchanged")
	return result


func _test_drain_after_hit() -> void:
	_check(rules.has_method("resolve_drain_after_hit"),
		"scene-free keyword rules expose the documented Drain handler")
	# AC1: a confirmed hero hit heals the wounded source for exactly the HP lost.
	var party := _party()
	var enemies := _drain_roster()
	_check(enemies.apply_damage(1, 6) and enemies.gain_block(1, 2)
		and enemies.apply_statuses({1: {"bleed": 1}}),
		"fixture: wounded Drain source carries Block and statuses")
	var source_before := enemies.get_enemy(1)
	var neighbor_before := enemies.get_enemy(2)
	_check(source_before["hp"] == 18 and source_before["drain"] == true,
		"fixture: living wounded Drain source")
	var hit := attacks.resolve_vs_hero(party, 1, 5, {}, {})
	_check(hit == {"ok": true, "damage": 5, "block_absorbed": 0, "hp_loss": 5},
		"fixture: genuine confirmed hero hit with 5 HP loss")
	_check(_resolve_drain(enemies, 1, hit, "hp-loss hit")
		== {"ok": true, "applied": true, "healed": 5},
		"a confirmed hit heals the source for exactly the hero HP loss")
	var source_after := enemies.get_enemy(1)
	_check(source_after["hp"] == 23, "source HP rises by exactly hp_loss")
	source_after["hp"] = 18
	_check(source_after == source_before, "drain preserves slot, id, Block, metadata and statuses")
	_check(enemies.get_enemy(2) == neighbor_before, "drain leaves the other enemy record exact")
	_check(party.get_hero(1)["hp"] == 35, "drain never touches the damaged hero")
	# AC2: Block-absorbed damage is not HP lost, so only hp_loss heals.
	var blocked_party := _party()
	_check(blocked_party.gain_block(1, 3), "fixture: hero Block partially absorbs the hit")
	var blocked_hit := attacks.resolve_vs_hero(blocked_party, 1, 5, {}, {})
	_check(blocked_hit == {"ok": true, "damage": 5, "block_absorbed": 3, "hp_loss": 2},
		"fixture: genuine partially blocked hit loses 2 HP")
	var blocked_enemies := _drain_roster()
	_check(blocked_enemies.apply_damage(1, 4), "fixture: wounded Drain source facing a blocked hit")
	_check(_resolve_drain(blocked_enemies, 1, blocked_hit, "partially blocked hit")
		== {"ok": true, "applied": true, "healed": 2},
		"partially blocked hit heals only the 2 HP actually lost")
	var full_party := _party()
	_check(full_party.gain_block(1, 5), "fixture: hero Block fully absorbs the hit")
	var full_hit := attacks.resolve_vs_hero(full_party, 1, 5, {}, {})
	_check(full_hit == {"ok": true, "damage": 5, "block_absorbed": 5, "hp_loss": 0},
		"fixture: genuine fully absorbed positive hit with zero HP loss")
	var full_enemies := _drain_roster()
	_check(full_enemies.apply_damage(1, 4), "fixture: wounded Drain source facing a fully blocked hit")
	_check(_resolve_drain(full_enemies, 1, full_hit, "fully blocked hit")
		== {"ok": true, "applied": false, "healed": 0},
		"a fully blocked hit is an inert success and heals nothing")
	# AC2: zero-damage hits, full-HP sources and non-Drain sources stay inert.
	var zero_party := _party()
	var zero_hit := attacks.resolve_vs_hero(zero_party, 2, 0, {}, {})
	_check(zero_hit == {"ok": true, "damage": 0, "block_absorbed": 0, "hp_loss": 0},
		"fixture: genuine confirmed zero-damage hit")
	var zero_enemies := _drain_roster()
	_check(zero_enemies.apply_damage(1, 4), "fixture: wounded Drain source facing a zero-damage hit")
	_check(_resolve_drain(zero_enemies, 1, zero_hit, "zero-damage hit")
		== {"ok": true, "applied": false, "healed": 0},
		"a zero-damage hit heals nothing")
	var clamp_party := _party()
	var clamp_enemies := _drain_roster()
	_check(clamp_enemies.apply_damage(1, 2), "fixture: source missing exactly 2 HP")
	var clamp_hit := attacks.resolve_vs_hero(clamp_party, 3, 7, {}, {})
	_check(clamp_hit.get("hp_loss") == 7, "fixture: genuine 7 HP hit")
	_check(_resolve_drain(clamp_enemies, 1, clamp_hit, "clamped hit")
		== {"ok": true, "applied": true, "healed": 2},
		"healing clamps to the missing HP instead of the full hit")
	_check(clamp_enemies.get_enemy(1)["hp"] == 24, "clamped heal reaches max_hp exactly, never beyond")
	var full_hp_party := _party()
	var full_hp_enemies := _drain_roster()
	var full_hp_before := full_hp_enemies.get_enemies()
	var full_hp_hit := attacks.resolve_vs_hero(full_hp_party, 2, 6, {}, {})
	_check(full_hp_hit.get("hp_loss") == 6, "fixture: genuine 6 HP hit against a full-HP source")
	_check(_resolve_drain(full_hp_enemies, 1, full_hp_hit, "full-HP source")
		== {"ok": true, "applied": false, "healed": 0}, "a full-HP source has nothing to restore")
	_check(full_hp_enemies.get_enemies() == full_hp_before, "full-HP source keeps exact maximum HP")
	var plain_party := _party()
	var plain_enemies := _drain_roster(null)
	_check(not plain_enemies.get_enemy(1).has("drain"), "fixture: living source with no Drain metadata")
	_check(plain_enemies.apply_damage(1, 4), "fixture: wounded non-Drain source")
	var plain_before := plain_enemies.get_enemies()
	var plain_hit := attacks.resolve_vs_hero(plain_party, 1, 5, {}, {})
	_check(plain_hit.get("hp_loss") == 5, "fixture: genuine 5 HP hit on a non-Drain enemy")
	_check(_resolve_drain(plain_enemies, 1, plain_hit, "non-Drain source")
		== {"ok": true, "applied": false, "healed": 0}, "a non-Drain source reports inert success")
	_check(plain_enemies.get_enemies() == plain_before, "a non-Drain source gains no HP")
	var off_party := _party()
	var off_enemies := _drain_roster(false)
	_check(off_enemies.get_enemy(1).get("drain") == false, "fixture: explicitly disabled Drain metadata")
	_check(off_enemies.apply_damage(1, 4), "fixture: wounded explicitly non-Drain source")
	var off_hit := attacks.resolve_vs_hero(off_party, 1, 5, {}, {})
	_check(_resolve_drain(off_enemies, 1, off_hit, "disabled Drain")
		== {"ok": true, "applied": false, "healed": 0},
		"drain: false is a valid non-Drain source and heals nothing")
	# AC2: a slain source is never healed back to life.
	var slain_enemies := _drain_roster()
	_check(slain_enemies.apply_damage(1, 24) and slain_enemies.is_slain(1),
		"fixture: Drain source genuinely slain")
	var slain_party := _party()
	var slain_hit := attacks.resolve_vs_hero(slain_party, 1, 5, {}, {})
	_check(slain_hit.get("hp_loss") == 5, "fixture: genuine 5 HP hit while the source is slain")
	_check(_resolve_drain(slain_enemies, 1, slain_hit, "slain source")
		== {"ok": false, "applied": false, "healed": 0}, "a slain source fails closed")
	_check(slain_enemies.get_enemy(1)["hp"] == 0, "no healing can resurrect a slain enemy")
	# AC3: invalid Drain metadata fails closed without mutating the roster.
	for bad in ["true", 1, 0, [], {}]:
		var bad_enemies := _drain_roster(bad)
		_check(bad_enemies.is_valid() and bad_enemies.get_enemy(1)["drain"] == bad,
			"fixture: invalid Drain metadata " + str(bad))
		_check(bad_enemies.apply_damage(1, 4), "fixture: wounded invalid-metadata source")
		var bad_hit := attacks.resolve_vs_hero(_party(), 1, 4, {}, {})
		_check(_resolve_drain(bad_enemies, 1, bad_hit, "invalid metadata " + str(bad))
			== {"ok": false, "applied": false, "healed": 0},
			"invalid Drain metadata fails closed without mutation")
	# AC3: missing sources, invalid rosters and failed/malformed receipts.
	var invalid_enemies := _drain_roster()
	_check(invalid_enemies.apply_damage(1, 6), "fixture: wounded source for invalid-source cases")
	var valid_receipt := attacks.resolve_vs_hero(_party(), 1, 3, {}, {})
	_check(valid_receipt.get("ok") == true and valid_receipt.get("hp_loss") == 3,
		"fixture: genuine valid hit receipt")
	for position in [-1, 0, 3, 100]:
		_check(_resolve_drain(invalid_enemies, position, valid_receipt, "invalid source %d" % position)
			== {"ok": false, "applied": false, "healed": 0}, "a missing source position fails closed")
	_check(rules.resolve_drain_after_hit(null, 1, valid_receipt)
		== {"ok": false, "applied": false, "healed": 0}, "a missing roster fails closed")
	_check(rules.resolve_drain_after_hit(CombatEnemies.new([]), 1, valid_receipt)
		== {"ok": false, "applied": false, "healed": 0}, "an invalid roster fails closed")
	# A genuinely failed receipt from an actually downed target is not evidence of a hit.
	var downed_party := _party()
	_check(downed_party.apply_damage(1, 40) and downed_party.is_downed(1),
		"fixture: hero genuinely downed")
	var failed_hit := attacks.resolve_vs_hero(downed_party, 1, 5, {}, {})
	_check(failed_hit == {"ok": false, "damage": 0, "block_absorbed": 0, "hp_loss": 0},
		"fixture: no valid attack target yields a genuine failed receipt")
	var receipt_enemies := _drain_roster()
	_check(receipt_enemies.apply_damage(1, 6), "fixture: wounded Drain source for receipt cases")
	_check(_resolve_drain(receipt_enemies, 1, failed_hit, "failed receipt from a downed target")
		== {"ok": false, "applied": false, "healed": 0},
		"a real failed attack receipt fails closed without healing")
	for bad_receipt in [
			{}, {"ok": true}, {"result": "hit", "amount": 5},
			{"ok": 1, "damage": 5, "block_absorbed": 0, "hp_loss": 5},
			{"ok": "true", "damage": 5, "block_absorbed": 0, "hp_loss": 5},
			{"ok": true, "damage": -1, "block_absorbed": 0, "hp_loss": 0},
			{"ok": true, "damage": 5.5, "block_absorbed": 0, "hp_loss": 5},
			{"ok": true, "damage": 5, "block_absorbed": -1, "hp_loss": 5},
			{"ok": true, "damage": 5, "block_absorbed": 0, "hp_loss": -5},
			{"ok": true, "damage": 5, "block_absorbed": 0}]:
		_check(_resolve_drain(receipt_enemies, 1, bad_receipt, "malformed receipt " + str(bad_receipt))
			== {"ok": false, "applied": false, "healed": 0},
			"failed or malformed receipt fails closed without mutation")
	_check(_resolve_drain(receipt_enemies, 1,
		{"ok": true, "damage": 5, "block_absorbed": 0, "hp_loss": 4}, "valid receipt after rejections")
		== {"ok": true, "applied": true, "healed": 4},
		"a valid receipt still heals after the rejected receipts")
	_check(receipt_enemies.get_enemy(1)["hp"] == 22, "the surviving valid hit healed exactly 4")
	# Deterministic replay: identical fixtures produce identical receipts and rosters.
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var state_before := rng.state
	seed(13579)
	var next_global := randi()
	seed(13579)
	var first_result: Dictionary = {}
	var first_roster: Array[Dictionary] = []
	for repeat in range(3):
		var replay_party := _party()
		var replay_enemies := _drain_roster()
		_check(replay_enemies.apply_damage(1, 8), "fixture: replay source wounded identically")
		var replay_hit := attacks.resolve_vs_hero(replay_party, 1, 6, {}, {})
		_check(replay_hit.get("hp_loss") == 6, "fixture: replay hit loses 6 HP")
		var replay_result := _resolve_drain(replay_enemies, 1, replay_hit, "replay %d" % repeat)
		_check(replay_result == {"ok": true, "applied": true, "healed": 6},
			"replay %d: deterministic Drain heal" % repeat)
		if repeat == 0:
			first_result = replay_result.duplicate(true)
			first_roster = replay_enemies.get_enemies()
			replay_result["healed"] = 99
			_check(rules.resolve_drain_after_hit(replay_enemies, 1,
				{"ok": true, "damage": 0, "block_absorbed": 0, "hp_loss": 0})
				== {"ok": true, "applied": false, "healed": 0},
				"mutating a returned receipt cannot leak into the next call")
		else:
			_check(replay_result == first_result and replay_enemies.get_enemies() == first_roster,
				"identical fixtures replay the same Drain receipt and roster")
	_check(rng.state == state_before, "Drain consumes no seeded run RNG")
	_check(randi() == next_global, "Drain consumes no global RNG")


func _test_broodling_model() -> void:
	var normal: Array = RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	var bosses: Array = RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/boss.json"))
	for id in [CombatEnemies.MOTH_ID, CombatEnemies.MOTH_QUEEN_ID]:
		var record := {}
		for candidate in normal + bosses:
			if candidate.get("id") == id:
				record = candidate
		_check(not record.is_empty() and
			CombatEnemies.authentic_broodling_mother(record, 1),
			"precondition: canonical mother has real weighted summon " + id)
		if record.is_empty():
			continue
		for count in [1, 2, 3]:
			var definitions: Array = [record.duplicate(true)]
			for i in range(1, count):
				definitions.append({"id": "passive_%d" % i, "max_hp": 12})
			var roster := CombatEnemies.new(definitions)
			var snapshot := roster.get_enemies()
			var result := roster.stage_broodling(1)
			_check(roster.is_valid() and result.get("ok", false),
				"valid mother stages or skips when full")
			if count == 3:
				_check(result == {"ok": true, "spawned": false}
					and roster.get_enemies() == snapshot,
					"three occupied slots skip without latch or state mutation " + id)
				continue
			_check(result == {"ok": true, "spawned": true, "position": count + 1}
				and roster.get_enemies().size() == count + 1
				and roster.get_enemy(count + 1).id == CombatEnemies.BROODLING_ID
				and roster.get_enemy(count + 1).hp == 8
				and roster.get_enemy(count + 1).max_hp == 8
				and roster.get_enemy(count + 1).block == 0
				and roster.get_enemy(1).get(CombatEnemies.BROODLING_LATCH) == true,
				"valid mother spawns exactly one healthy latched child " + id)
			var after := roster.get_enemies()
			_check(roster.stage_broodling(1) == {"ok": true, "spawned": false}
				and roster.get_enemies() == after,
				"repeat summon preserves every record " + id)
		var slain := CombatEnemies.new([record])
		_check(slain.apply_damage(1, slain.get_enemy(1).hp),
			"precondition: genuine mother can be slain")
		var dead_before := slain.get_enemies()
		_check(slain.stage_broodling(1) == {"ok": true, "spawned": false}
			and slain.get_enemies() == dead_before,
			"dead source is inert and never spends latch " + id)
		for forged in ["not_moth", "moth_swarm_broodling"]:
			var wrong := record.duplicate(true)
			wrong.id = forged
			var invalid := CombatEnemies.new([wrong])
			var prior := invalid.get_enemies()
			_check(invalid.stage_broodling(1) == {"ok": false, "spawned": false}
				and invalid.get_enemies() == prior,
				"forged identity rejects without partial child " + id)
		for bad in ["true", 1, [], {}]:
			var malformed := CombatEnemies.new([record])
			malformed._enemies[0][CombatEnemies.BROODLING_LATCH] = bad
			var before := malformed.get_enemies()
			_check(malformed.stage_broodling(1) == {"ok": false, "spawned": false}
				and malformed.get_enemies() == before,
				"malformed latch is failure-atomic " + id)
		var counterfeit := record.duplicate(true)
		counterfeit.intent.actions = [{"type": "summon", "amount": 0, "weight": 1}]
		var forged_spec := CombatEnemies.new([counterfeit])
		var before_spec := forged_spec.get_enemies()
		_check(forged_spec.stage_broodling(1) == {"ok": false, "spawned": false}
			and forged_spec.get_enemies() == before_spec,
			"unweighted single-option summon is not authentic " + id)


func _test_construction() -> void:
	for count in range(1, 4):
		var definitions := _definitions(count)
		var input_before := definitions.duplicate(true)
		var enemies := CombatEnemies.new(definitions)
		var expected := _expected(count)
		_check(enemies.is_valid() and enemies.get_enemies().size() == count, "valid roster has actual requested enemies")
		_check(enemies.get_enemies() == expected, "exact ordered full-HP zero-Block state")
		_check(definitions == input_before, "construction preserves input")
		_check(not enemies.is_defeated() and enemies.has_method("heal"), "living roster is not victory and exposes the bounded heal primitive")
		for position in range(1, count + 1):
			_check(enemies.get_enemy(position) == expected[position - 1] and not enemies.is_slain(position), "individual reader has exact living state")
		definitions[0]["metadata"]["tags"].clear()
		definitions[0]["max_hp"] = 999
		definitions.clear()
		_check(enemies.get_enemies() == expected, "constructor deep copy isolates nested input")
		var enemy := enemies.get_enemy(1)
		enemy["hp"] = 0
		enemy["metadata"]["tags"].append("changed")
		var roster := enemies.get_enemies()
		roster[0]["position"] = 99
		roster[0]["metadata"]["tags"].clear()
		roster.clear()
		_check(enemies.get_enemies() == expected, "both state readers return defensive deep copies")


func _test_invalid_construction() -> void:
	var invalid_sets: Array = [[], _definitions(4)]
	for count in range(1, 4):
		for bad in [null, 1, "bad", [], {}, {"id": "", "max_hp": 1},
			{"id": 4, "max_hp": 1}, {"id": &"name", "max_hp": 1},
			{"id": "bad"}, {"max_hp": 1}, {"id": "bad", "max_hp": null},
			{"id": "bad", "max_hp": 0}, {"id": "bad", "max_hp": -1},
			{"id": "bad", "max_hp": 1.0}, {"id": "bad", "max_hp": true},
			{"id": "bad", "max_hp": "2"}]:
			var definitions := _definitions(count)
			definitions[count - 1] = bad
			invalid_sets.append(definitions)
		if count > 1:
			var duplicate := _definitions(count)
			duplicate[count - 1]["id"] = duplicate[0]["id"]
			invalid_sets.append(duplicate)
	for definitions in invalid_sets:
		var before: Array = definitions.duplicate(true)
		var enemies := CombatEnemies.new(definitions)
		_check(not enemies.is_valid() and enemies.get_enemies() == [], "invalid construction rejects atomically, including late malformed entries")
		_check(definitions == before, "rejected construction preserves input")
		_check(not enemies.is_defeated() and not enemies.is_victorious(), "invalid roster never yields vacuous victory")
		for position in [-1, 0, 1, 3, 4]:
			_check(enemies.get_enemy(position) == {} and not enemies.is_slain(position), "invalid roster readers fail closed")
			_check(not enemies.is_dead(position), "required death query fails closed on invalid rosters")
			_reject(enemies, "apply_damage", position, 1)
			_reject(enemies, "gain_block", position, 1)
			_reject(enemies, "heal", position, 1)


func _test_required_queries() -> void:
	var enemies := CombatEnemies.new(_definitions(3))
	_check(enemies.has_method("is_dead") and enemies.has_method("is_victorious"),
		"required public death and victory queries exist")
	for position in range(1, 4):
		_check(not enemies.is_dead(position) and enemies.is_dead(position) == enemies.is_slain(position),
			"living enemy is not dead and required query matches the alias")
	_check(not enemies.is_victorious() and enemies.is_victorious() == enemies.is_defeated(),
		"living roster is not victory and required query matches the alias")
	for position in [-1, 0, 4, 100]:
		_check(not enemies.is_dead(position), "required death query fails closed on invalid positions")
	_check(enemies.apply_damage(2, CombatEnemies.MAX_INT), "required queries exercise an intermediate death")
	_check(enemies.is_dead(2) and enemies.is_dead(2) == enemies.is_slain(2),
		"required death query reports the slain slot after a kill")
	_check(not enemies.is_dead(1) and not enemies.is_dead(3), "surviving neighbors are not dead")
	_check(not enemies.is_victorious() and enemies.is_victorious() == enemies.is_defeated(),
		"required victory query stays false while an enemy lives")
	_check(enemies.apply_damage(1, CombatEnemies.MAX_INT) and not enemies.is_victorious(),
		"required victory query stays false with one enemy alive")
	_check(enemies.apply_damage(3, CombatEnemies.MAX_INT) and enemies.is_victorious(),
		"required victory query is true only after the final death")
	_check(enemies.is_victorious() == enemies.is_defeated(), "required victory query matches the alias at victory")
	_check(not enemies.is_dead(0) and not enemies.is_dead(4), "required death query fails closed after victory")
	var invalid := CombatEnemies.new([])
	_check(not invalid.is_victorious(), "invalid roster never yields required victory")
	for position in [-1, 0, 1, 4]:
		_check(not invalid.is_dead(position), "invalid roster never yields required death")


func _perform(enemies: CombatEnemies, expected: Array, method: String, position: int, amount: int, hp: int, block: int) -> void:
	_check(enemies.get_enemies() == expected, "exact pre-operation roster")
	_check(enemies.call(method, position, amount) == true, method + " succeeds on living target")
	expected[position - 1]["hp"] = hp
	expected[position - 1]["block"] = block
	_check(enemies.get_enemies() == expected, "exact post-operation roster includes unchanged neighbors")


func _test_damage_and_death(count: int) -> void:
	var enemies := CombatEnemies.new(_definitions(count))
	var expected := _expected(count)
	for position in range(1, count + 1):
		_perform(enemies, expected, "gain_block", position, 2, 10 + position, 2)
	_perform(enemies, expected, "gain_block", 1, 5, 11, 7)
	_perform(enemies, expected, "apply_damage", 1, 3, 11, 4)
	_perform(enemies, expected, "apply_damage", 1, 4, 11, 0)
	_perform(enemies, expected, "gain_block", 1, 3, 11, 3)
	_perform(enemies, expected, "apply_damage", 1, 7, 7, 0)
	_check(not enemies.is_defeated() and not enemies.is_victorious(), "partial damage is not victory")
	_perform(enemies, expected, "apply_damage", 1, 7, 0, 0)
	_check(enemies.is_slain(1) and enemies.is_defeated() == (count == 1), "exact lethal hit wins only on final enemy")
	_check(enemies.is_dead(1) and enemies.is_dead(1) == enemies.is_slain(1) and enemies.is_victorious() == enemies.is_defeated(),
		"required queries match the aliases at the first death")
	for amount in [0, 1, CombatEnemies.MAX_INT]:
		_reject(enemies, "apply_damage", 1, amount)
		_reject(enemies, "gain_block", 1, amount)
	_check(enemies.get_enemies() == expected, "single-death late calls preserve slain slot and living neighbors")
	for position in range(2, count + 1):
		_perform(enemies, expected, "apply_damage", position, CombatEnemies.MAX_INT, 0, 0)
		_check(enemies.is_slain(position) and enemies.is_defeated() == (position == count), "overkill clamps at zero; victory waits for last living enemy")
		_check(enemies.is_dead(position) and enemies.is_victorious() == (position == count),
			"required queries track each death and the final-death victory")
	_check(enemies.is_valid() and enemies.get_enemies().size() == count, "slain roster stays valid and retains all slots")
	for position in range(1, count + 1):
		_check(enemies.get_enemy(position)["position"] == position, "death preserves position")
		for amount in [0, 1, CombatEnemies.MAX_INT]:
			_reject(enemies, "apply_damage", position, amount)
			_reject(enemies, "gain_block", position, amount)
	_check(enemies.is_defeated() and enemies.is_victorious(), "late calls preserve victory through the required query")


func _reject(enemies: CombatEnemies, method: String, position: int, amount: int) -> void:
	var before := enemies.get_enemies()
	_check(enemies.call(method, position, amount) == false, method + " rejects invalid target/amount")
	_check(enemies.get_enemies() == before, method + " rejection preserves entire roster")


func _test_rejections(count: int) -> void:
	var enemies := CombatEnemies.new(_definitions(count))
	_check(enemies.apply_damage(1, 3) and enemies.gain_block(count, 4), "rejections exercise wounded/protected state")
	for method in ["apply_damage", "gain_block"]:
		for position in [-100, -1, 0, count + 1, 100]:
			_reject(enemies, method, position, 3)
			_check(enemies.get_enemy(position) == {} and not enemies.is_slain(position), "invalid positions read safely")
		for position in range(1, count + 1):
			_reject(enemies, method, position, -1)
			_reject(enemies, method, position, -CombatEnemies.MAX_INT - 1)
			var before := enemies.get_enemies()
			_check(enemies.call(method, position, 0) == true and enemies.get_enemies() == before, "zero on living target succeeds without mutation")
	_check(enemies.gain_block(count, CombatEnemies.MAX_INT - 4), "Block reaches integer maximum exactly")
	_check(enemies.get_enemy(count)["block"] == CombatEnemies.MAX_INT, "maximum Block is exact")
	_reject(enemies, "gain_block", count, 1)
	_reject(enemies, "gain_block", count, CombatEnemies.MAX_INT)
	var before := enemies.get_enemies()
	_check(enemies.apply_damage(count, CombatEnemies.MAX_INT), "maximum Block safely absorbs maximum damage")
	before[count - 1]["block"] = 0
	_check(enemies.get_enemies() == before, "maximum absorption preserves exact HP and neighbors")
	var large := CombatEnemies.new([{"id": "large_fixture", "max_hp": CombatEnemies.MAX_INT}])
	_check(large.is_valid() and large.apply_damage(1, CombatEnemies.MAX_INT), "maximum HP accepts exact lethal hit without arithmetic overflow")
	_check(large.get_enemy(1)["hp"] == 0 and large.is_defeated(), "maximum HP reaches exact zero and victory")


func _test_replay(count: int) -> void:
	var first := CombatEnemies.new(_definitions(count))
	var second := CombatEnemies.new(_definitions(count))
	var operations: Array = [["gain_block", count, 6], ["apply_damage", count, 2],
		["apply_damage", 0, 4], ["gain_block", 1, -1], ["apply_damage", count, 7]]
	for position in range(1, count + 1):
		operations.append(["apply_damage", position, CombatEnemies.MAX_INT])
		operations.append(["gain_block", position, 2])
	for operation in operations:
		var a = first.call(operation[0], operation[1], operation[2])
		var b = second.call(operation[0], operation[1], operation[2])
		_check(a == b and first.get_enemies() == second.get_enemies(), "identical operation replay has identical return and complete state")
		_check(first.is_defeated() == second.is_defeated(), "identical replay has identical victory boundary")
		_check(first.is_victorious() == second.is_victorious(), "identical replay has identical required victory query")
	_check(first.is_defeated() and second.is_defeated(), "replay actually reaches victory")
	_check(first.is_victorious() and second.is_victorious(), "replay reaches victory through the required query")
