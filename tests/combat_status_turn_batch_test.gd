extends SceneTree

var failures: Array[String] = []
var checks := 0
var batch := CombatStatusTurnBatch.new()
var rules := CombatStatuses.new()


func _initialize() -> void:
	_test_contract_and_real_rosters()
	_test_three_owner_turns()
	_test_downed_and_slain()
	_test_replay_and_copy_isolation()
	_test_tangled_and_riposte_batches()
	_test_invalid_atomicity()
	if failures.is_empty():
		print("combat_status_turn_batch_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("combat_status_turn_batch_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## A rejected or partial batch has no actor at that index; return an impossible
## placeholder record so the assertion reports a failure instead of a script error.
func _actor_at(result: Dictionary, index: int) -> Dictionary:
	var actors: Array = result.get("actors", [])
	if index >= 0 and index < actors.size() and actors[index] is Dictionary:
		return actors[index]
	return {"id": "<missing>", "position": -1, "hp": -1, "block": -1,
		"statuses": {"<missing>": -1}}


func _party() -> CombatParty:
	var party := CombatParty.new([
		{"id": "warden", "max_hp": 40, "metadata": {"tags": ["front"]}},
		{"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26}])
	_check(party.is_valid() and party.get_heroes().size() == 3
		and party.get_hero(1)["position"] == 1 and party.get_hero(3)["hp"] == 26,
		"precondition: actual three-hero party with canonical positions")
	return party


func _enemies() -> CombatEnemies:
	var enemies := CombatEnemies.new([
		{"id": "ragling", "max_hp": 12, "metadata": {"tags": ["starter"]}},
		{"id": "guard_ragling", "max_hp": 12}])
	_check(enemies.is_valid() and enemies.get_enemies().size() == 2
		and enemies.get_enemy(1)["hp"] == 12 and enemies.get_enemy(2)["position"] == 2,
		"precondition: actual two-enemy starter-sized roster")
	return enemies


func _expected(side: String, input: Array) -> Dictionary:
	var actors: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	for record in input:
		var tick: Dictionary = rules.end_owner_turn(record["hp"], record["block"],
			record.get("statuses", {}))
		_check(tick["ok"], "precondition: direct CombatStatuses tick accepts valid actor")
		var actor: Dictionary = record.duplicate(true)
		actor["hp"] = tick["hp"]
		actor["block"] = tick["block"]
		actor["statuses"] = tick["statuses"]
		actors.append(actor)
		events.append({"side": side, "position": record["position"],
			"id": record["id"], "bleed_hp_loss": tick["bleed_hp_loss"]})
	return {"ok": true, "actors": actors, "events": events}


func _test_contract_and_real_rosters() -> void:
	_check(batch.has_method("tick_side"), "public owner-side tick entrypoint exists")
	var party := _party()
	var enemies := _enemies()
	_check(party.gain_block(1, 6) and enemies.gain_block(2, 1),
		"real roster Block fixture constructed through APIs")
	var heroes := party.get_heroes()
	var foes := enemies.get_enemies()
	heroes[0]["statuses"] = {"bleed": 3, "weak": 2, "exposed": 1}
	heroes[1]["statuses"] = {"weak": 1}
	foes[0]["statuses"] = {"bleed": 2, "exposed": 1}
	foes[1]["statuses"] = {"weak": 3}
	var hero_before := heroes.duplicate(true)
	var enemy_before := foes.duplicate(true)
	var live_heroes := party.get_heroes()
	var live_enemies := enemies.get_enemies()

	var hero_result := batch.tick_side("heroes", heroes)
	_check(hero_result == _expected("heroes", hero_before),
		"all ordered heroes and events equal direct actor rules, including status-free fields")
	_check(hero_result["actors"].size() == 3 and hero_result["events"].size() == 3
		and hero_result["actors"][0]["id"] == "warden"
		and hero_result["actors"][2]["id"] == "tinker",
		"every hero position retained and never reindexed")
	_check(heroes == hero_before and foes == enemy_before,
		"hero owner tick does not change either caller snapshot")
	_check(party.get_heroes() == live_heroes and enemies.get_enemies() == live_enemies,
		"hero owner tick never changes actual opposite or owning roster")

	var enemy_result := batch.tick_side("enemies", foes)
	_check(enemy_result == _expected("enemies", enemy_before),
		"two enemy positions tick in order with exact delegate results")
	_check(enemy_result["events"] == [
		{"side": "enemies", "position": 1, "id": "ragling", "bleed_hp_loss": 2},
		{"side": "enemies", "position": 2, "id": "guard_ragling", "bleed_hp_loss": 0}],
		"ordered enemy events include side, original slot and ID")
	_check(heroes == hero_before and foes == enemy_before,
		"enemy owner tick leaves opposing and owning snapshots untouched")
	_check(party.get_heroes() == live_heroes and enemies.get_enemies() == live_enemies,
		"enemy owner tick leaves both authoritative rosters untouched")


func _test_three_owner_turns() -> void:
	var party := _party()
	var enemies := _enemies()
	_check(party.apply_damage(1, 30) and party.gain_block(1, 7),
		"precondition: actual Warden has 10 HP and 7 Block")
	var original := party.get_heroes()
	_check(original[0]["hp"] == 10 and original[0]["block"] == 7,
		"precondition: verified low-HP shielded Warden")
	original[0]["statuses"] = {"bleed": 3, "weak": 2, "exposed": 1}
	var before := original.duplicate(true)
	var foes_before := enemies.get_enemies()
	var current: Array = original
	var hp_values := [7, 5, 4, 4]
	var losses := [3, 2, 1, 0]
	var status_values: Array = [
		{"bleed": 2, "weak": 1}, {"bleed": 1}, {}, {}]
	for turn in range(4):
		var result := batch.tick_side("heroes", current)
		_check(result == _expected("heroes", current),
			"turn %d entire hero batch equals CombatStatuses" % (turn + 1))
		_check(result["actors"][0]["hp"] == hp_values[turn]
			and result["actors"][0]["block"] == 7
			and result["actors"][0]["statuses"] == status_values[turn]
			and result["events"][0]["bleed_hp_loss"] == losses[turn],
			"turn %d direct Bleed HP loss, unchanged Block, and independent status expiry" % (turn + 1))
		_check(result["actors"][1]["hp"] == 30 and result["actors"][2]["hp"] == 26,
			"status-free allies never lose HP or positions")
		current = result["actors"]
	_check(original == before and enemies.get_enemies() == foes_before,
		"four-turn trace preserves first snapshot and unchanged enemy roster")
	_check(party.get_hero(1)["hp"] == 10 and party.get_hero(1)["block"] == 7,
		"proposed transitions do not silently integrate authoritative HP")


func _test_downed_and_slain() -> void:
	var party := _party()
	var enemies := _enemies()
	_check(party.apply_damage(2, 30), "precondition: Seamstress downed through API")
	_check(enemies.apply_damage(1, 11) and enemies.gain_block(1, 4),
		"precondition: enemy 1 at 1 HP with retained Block")
	_check(enemies.gain_block(2, 5) and enemies.apply_damage(2, 17),
		"precondition: enemy 2 slain with Block retained")
	_check(party.is_downed(2) and enemies.get_enemy(1)["hp"] == 1
		and enemies.is_slain(2), "downed/slain fixtures are genuinely zero/near-zero")
	var heroes := party.get_heroes()
	var foes := enemies.get_enemies()
	heroes[1]["statuses"] = {"bleed": 3}
	foes[0]["statuses"] = {"bleed": 3}
	foes[1]["statuses"] = {"bleed": 2, "exposed": 1}
	var originals := [heroes.duplicate(true), foes.duplicate(true)]
	var hero_result := batch.tick_side("heroes", heroes)
	var enemy_result := batch.tick_side("enemies", foes)
	_check(hero_result == _expected("heroes", heroes)
		and enemy_result == _expected("enemies", foes),
		"downed and slain full batches still match direct rules")
	_check(hero_result["actors"][1]["hp"] == 0
		and hero_result["events"][1]["bleed_hp_loss"] == 0
		and hero_result["actors"][1]["statuses"] == {"bleed": 2},
		"downed hero bleeds no extra HP, but owner duration decrements")
	_check(enemy_result["actors"][0]["hp"] == 0
		and enemy_result["actors"][0]["block"] == 4
		and enemy_result["events"][0]["bleed_hp_loss"] == 1,
		"lethal Bleed clamps at zero without absorbing Block")
	_check(enemy_result["actors"][1]["hp"] == 0
		and enemy_result["actors"][1]["block"] == 0
		and enemy_result["events"][1]["bleed_hp_loss"] == 0
		and enemy_result["actors"][1]["statuses"] == {"bleed": 1},
		"already slain slot remains in place and statuses still age")
	_check(heroes == originals[0] and foes == originals[1],
		"all downed/slain input records remain unchanged")


func _test_replay_and_copy_isolation() -> void:
	var party := _party()
	var enemies := _enemies()
	var heroes := party.get_heroes()
	var foes := enemies.get_enemies()
	heroes[0]["statuses"] = {"bleed": 1}
	foes[0]["statuses"] = {"exposed": 2}
	var hero_before := heroes.duplicate(true)
	var enemy_before := foes.duplicate(true)
	var live_heroes := party.get_heroes()
	var live_foes := enemies.get_enemies()
	var first := batch.tick_side("heroes", heroes)
	var second := batch.tick_side("heroes", heroes)
	var enemy_first := batch.tick_side("enemies", foes)
	var enemy_second := batch.tick_side("enemies", foes)
	_check(first == second and enemy_first == enemy_second,
		"identically initialized hero/enemy traces repeat with exact event order")
	first["actors"][0]["metadata"]["tags"].append("changed")
	first["actors"][0]["statuses"]["weak"] = 99
	first["actors"][1]["id"] = "wrong"
	first["actors"].clear()
	enemy_first["actors"][0]["metadata"]["tags"].clear()
	enemy_first["actors"][0]["statuses"]["bleed"] = 5
	_check(heroes == hero_before and foes == enemy_before
		and batch.tick_side("heroes", heroes) == second
		and batch.tick_side("enemies", foes) == enemy_second,
		"mutating one output deeply cannot touch input or another output")
	_check(party.get_heroes() == live_heroes and enemies.get_enemies() == live_foes,
		"authoritative readers remain available after replay")


## Tangled and Riposte already age in CombatStatuses; the detached batch must
## carry them through real roster snapshots without owning the aging rules.
func _test_tangled_and_riposte_batches() -> void:
	var party := _party()
	var enemies := _enemies()
	_check(party.apply_damage(1, 4) and party.gain_block(2, 5),
		"precondition: real damaged Warden and shielded Seamstress")
	_check(enemies.gain_block(1, 3) and enemies.apply_damage(2, 2),
		"precondition: real shielded enemy 1 and damaged enemy 2")
	var live_heroes := party.get_heroes()
	var live_foes := enemies.get_enemies()
	var heroes := party.get_heroes()
	var foes := enemies.get_enemies()
	heroes[0]["statuses"] = {"tangled": 2, "riposte": 4}
	heroes[1]["statuses"] = {"tangled": 1}
	heroes[2]["statuses"] = {"riposte": 7}
	foes[0]["statuses"] = {"tangled": 1}
	foes[1]["statuses"] = {"tangled": 2, "riposte": 4}
	var hero_before := heroes.duplicate(true)
	var foe_before := foes.duplicate(true)
	_check(heroes.size() == CombatParty.PARTY_SIZE and foes.size() == 2
		and heroes[0]["hp"] == 36 and heroes[1]["block"] == 5,
		"precondition: non-vacuous three-hero snapshot with real HP and Block")

	var hero_tick := batch.tick_side("heroes", heroes)
	_check(hero_tick["ok"] and hero_tick == _expected("heroes", hero_before),
		"hero Tangled/Riposte batch equals direct CombatStatuses.end_owner_turn")
	var hero_states: Array = []
	for actor in hero_tick["actors"]:
		hero_states.append(actor["statuses"])
	_check(hero_states == [{"tangled": 1}, {}, {}],
		"hero Tangled 2 ages to 1 while Tangled 1 and Riposte 4/7 expire completely")
	_check(_actor_at(hero_tick, 0)["hp"] == 36 and _actor_at(hero_tick, 0)["block"] == 0
		and _actor_at(hero_tick, 1)["block"] == 5,
		"Tangled and Riposte deal no direct HP or Block damage at the owner turn end")
	_check(hero_tick["events"] == [
		{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 2, "id": "seamstress", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 3, "id": "tinker", "bleed_hp_loss": 0}],
		"hero events preserve side, canonical slot, ID and zero Bleed loss")
	_check(_actor_at(hero_tick, 0)["id"] == "warden"
		and _actor_at(hero_tick, 2)["id"] == "tinker"
		and _actor_at(hero_tick, 2)["position"] == 3,
		"hero Tangled/Riposte batch keeps roster order and positions")
	_check(heroes == hero_before and foes == foe_before
		and party.get_heroes() == live_heroes and enemies.get_enemies() == live_foes,
		"hero Tangled/Riposte tick mutates no caller snapshot or live roster")

	var foe_tick := batch.tick_side("enemies", foes)
	_check(foe_tick["ok"] and foe_tick == _expected("enemies", foe_before),
		"enemy Tangled/Riposte batch equals direct CombatStatuses.end_owner_turn")
	var foe_states: Array = []
	for actor in foe_tick["actors"]:
		foe_states.append(actor["statuses"])
	_check(foe_states == [{}, {"tangled": 1}],
		"enemy Tangled 1 expires and Tangled 2 ages once while Riposte 4 clears")
	_check(_actor_at(foe_tick, 0)["hp"] == 12 and _actor_at(foe_tick, 0)["block"] == 3
		and _actor_at(foe_tick, 1)["hp"] == 10,
		"enemy Tangled/Riposte tick leaves HP and Block exactly as they were")
	_check(foe_tick["events"] == [
		{"side": "enemies", "position": 1, "id": "ragling", "bleed_hp_loss": 0},
		{"side": "enemies", "position": 2, "id": "guard_ragling", "bleed_hp_loss": 0}],
		"enemy events preserve side, canonical slot, ID and zero Bleed loss")
	_check(foes == foe_before and heroes == hero_before,
		"enemy Tangled/Riposte tick mutates neither caller snapshot")

	# One and three enemy slots accept the same statuses as the starter two.
	for count in [1, 3]:
		var definitions: Array = []
		for index in range(count):
			definitions.append({"id": "v3_batch_enemy_%d" % index, "max_hp": 12})
		var roster := CombatEnemies.new(definitions)
		_check(roster.is_valid() and roster.get_enemies().size() == count,
			"precondition: real %d-slot enemy roster" % count)
		var state := roster.get_enemies()
		var fixtures: Array = [{"tangled": 2, "riposte": 4}, {"tangled": 1}, {"riposte": 4}]
		var pristine := state.duplicate(true)
		for index in range(count):
			state[index]["statuses"] = fixtures[index].duplicate(true)
		var before := state.duplicate(true)
		var result := batch.tick_side("enemies", state)
		_check(result["ok"] and result == _expected("enemies", before),
			"%d-slot enemy batch equals direct rules with Tangled and Riposte" % count)
		var expected_states: Array = [{"tangled": 1}, {}, {}]
		for index in range(count):
			_check(_actor_at(result, index)["statuses"] == expected_states[index],
				"%d-slot enemy %d ages Tangled once and clears Riposte once" % [count, index + 1])
			_check(_actor_at(result, index)["id"] == "v3_batch_enemy_%d" % index
				and _actor_at(result, index)["position"] == index + 1
				and _actor_at(result, index)["hp"] == 12,
				"%d-slot enemy %d keeps ID, slot and HP" % [count, index + 1])
		_check(state == before and roster.get_enemies() == pristine,
			"%d-slot enemy Tangled/Riposte tick mutates no input or roster" % count)

	# Mixed statuses: only the selected side ages, Bleed ignores Block, replay holds.
	var mix_party := _party()
	var mix_enemies := _enemies()
	_check(mix_party.apply_damage(1, 4) and mix_party.gain_block(1, 8),
		"precondition: real Warden at 36 HP behind 8 Block")
	_check(mix_enemies.gain_block(1, 3) and mix_enemies.apply_damage(2, 2)
		and mix_enemies.gain_block(2, 4),
		"precondition: real enemy 1 Block and bleedable enemy 2 with Block")
	var live_mixed_heroes := mix_party.get_heroes()
	var live_mixed_foes := mix_enemies.get_enemies()
	var mixed_heroes := mix_party.get_heroes()
	var mixed_foes := mix_enemies.get_enemies()
	mixed_heroes[0]["statuses"] = {"bleed": 2, "weak": 2, "exposed": 1, "tangled": 2,
		"riposte": 4}
	mixed_heroes[1]["statuses"] = {"tangled": 1, "riposte": 2}
	mixed_heroes[2]["statuses"] = {"bleed": 1, "tangled": 3, "riposte": 6}
	mixed_foes[0]["statuses"] = {"weak": 1, "tangled": 2, "riposte": 4}
	mixed_foes[1]["statuses"] = {"bleed": 3, "exposed": 2, "riposte": 5}
	var mixed_hero_before := mixed_heroes.duplicate(true)
	var mixed_foe_before := mixed_foes.duplicate(true)
	var first := batch.tick_side("heroes", mixed_heroes)
	var second := batch.tick_side("heroes", mixed_heroes)
	var foe_first := batch.tick_side("enemies", mixed_foes)
	var foe_second := batch.tick_side("enemies", mixed_foes)
	_check(first == second and foe_first == foe_second
		and first == _expected("heroes", mixed_hero_before)
		and foe_first == _expected("enemies", mixed_foe_before),
		"mixed status batches equal direct rules and repeat identically")
	_check(_actor_at(first, 0)["hp"] == 34 and _actor_at(first, 0)["block"] == 8
		and _actor_at(first, 0)["statuses"] == {"bleed": 1, "weak": 1, "tangled": 1},
		"mixed Bleed 2 costs HP through Block while Exposed and Riposte clear once")
	_check(_actor_at(first, 2)["hp"] == 25
		and _actor_at(first, 2)["statuses"] == {"tangled": 2}
		and _actor_at(first, 1)["statuses"] == {},
		"mixed hero ally Bleed, Tangled and Riposte age independently")
	_check(first["events"] == [
		{"side": "heroes", "position": 1, "id": "warden", "bleed_hp_loss": 2},
		{"side": "heroes", "position": 2, "id": "seamstress", "bleed_hp_loss": 0},
		{"side": "heroes", "position": 3, "id": "tinker", "bleed_hp_loss": 1}],
		"mixed hero events keep side, slot, ID and exact Bleed loss")
	_check(_actor_at(foe_first, 1)["hp"] == 7 and _actor_at(foe_first, 1)["block"] == 4
		and _actor_at(foe_first, 1)["statuses"] == {"bleed": 2, "exposed": 1},
		"enemy Bleed 3 bypasses retained Block while Exposed ages and Riposte clears")
	_check(foe_first["events"] == [
		{"side": "enemies", "position": 1, "id": "ragling", "bleed_hp_loss": 0},
		{"side": "enemies", "position": 2, "id": "guard_ragling", "bleed_hp_loss": 3}],
		"mixed enemy events keep side, slot, ID and exact Bleed loss")
	_check(mixed_heroes == mixed_hero_before and mixed_foes == mixed_foe_before
		and mix_party.get_heroes() == live_mixed_heroes
		and mix_enemies.get_enemies() == live_mixed_foes,
		"mixed ticks change neither caller snapshot nor either live roster")
	_check(not mix_party.get_hero(1).has("statuses")
		and not mix_enemies.get_enemy(1).has("statuses"),
		"mixed Tangled/Riposte fixtures never leak into authoritative state")
	if first["actors"].size() == 3 and foe_first["actors"].size() == 2:
		first["actors"][0]["statuses"]["tangled"] = 99
		first["actors"][0]["metadata"]["tags"].append("changed")
		foe_first["actors"][0]["statuses"]["riposte"] = 99
		foe_first["actors"].clear()
	_check(mixed_heroes == mixed_hero_before and mixed_foes == mixed_foe_before
		and batch.tick_side("heroes", mixed_heroes) == second
		and batch.tick_side("enemies", mixed_foes) == foe_second,
		"mutating mixed Tangled/Riposte output cannot touch input or a replay")


func _reject(side: String, input: Array, label: String,
		party: CombatParty, enemies: CombatEnemies) -> void:
	var before := input.duplicate(true)
	var live_party := party.get_heroes()
	var live_enemies := enemies.get_enemies()
	var result := batch.tick_side(side, input)
	_check(result == {"ok": false, "actors": [], "events": []},
		"atomic rejection with no partial events or actors: " + label)
	_check(input == before and party.get_heroes() == live_party
		and enemies.get_enemies() == live_enemies,
		"rejection leaves nested input and both live rosters unchanged: " + label)


func _test_invalid_atomicity() -> void:
	var party := _party()
	var enemies := _enemies()
	var valid := party.get_heroes()
	var foes := enemies.get_enemies()
	_reject("enemy", valid, "unsupported side", party, enemies)
	_reject("", valid, "empty side", party, enemies)
	_reject("enemies", valid + [foes[0]], "enemy exceeds capacity", party, enemies)
	_reject("heroes", foes, "enemy snapshots passed as heroes", party, enemies)
	_reject("enemies", [], "missing all enemies", party, enemies)
	_reject("heroes", [], "missing all heroes", party, enemies)
	_reject("heroes", valid.slice(0, 2), "missing final hero", party, enemies)
	_reject("heroes", valid + [foes[0]], "extra hero", party, enemies)
	_reject("enemies", valid.slice(1, 3), "enemy first position missing", party, enemies)
	for side in ["heroes", "enemies"]:
		var baseline: Array = valid if side == "heroes" else foes
		for key in ["id", "position", "hp", "max_hp", "block"]:
			var missing := baseline.duplicate(true)
			missing[-1].erase(key)
			_reject(side, missing, "missing " + key + " on final " + side, party, enemies)
		var faults: Array = [
			["wrong actor type", null, ""],
			["empty ID", "", "id"],
			["wrong ID type", 123, "id"],
			["bad position zero", 0, "position"],
			["bad position out of range", 5, "position"],
			["position nonint", 1.0, "position"],
			["negative HP", -1, "hp"],
			["HP over maximum", 100, "hp"],
			["HP nonint", 1.5, "hp"],
			["max HP zero", 0, "max_hp"],
			["max HP nonint", 12.0, "max_hp"],
			["negative Block", -1, "block"],
			["Block nonint", 0.5, "block"],
			["status type", [], "statuses"],
			["negative Bleed", {"bleed": -1}, "statuses"],
			["negative Weak", {"weak": -1}, "statuses"],
			["negative Exposed", {"exposed": -1}, "statuses"],
			["negative Tangled", {"tangled": -1}, "statuses"],
			["negative Riposte", {"riposte": -1}, "statuses"],
			["Tangled float", {"tangled": 1.0}, "statuses"],
			["Riposte float", {"riposte": 4.0}, "statuses"],
			["Tangled string", {"tangled": "2"}, "statuses"],
			["Riposte string", {"riposte": "4"}, "statuses"],
			["Tangled bool", {"tangled": true}, "statuses"],
			["Riposte bool", {"riposte": true}, "statuses"],
			["unknown status beside Tangled", {"tangled": 2, "pinned": 1}, "statuses"],
			["unknown status beside Riposte", {"riposte": 4, "poison": 1}, "statuses"],
			["unsupported status", {"poison": 1}, "statuses"],
			["status float", {"bleed": 1.0}, "statuses"],
			["status string", {"weak": "1"}, "statuses"],
			["status nonstring key", {1: 1}, "statuses"]]
		for fault in faults:
			var broken: Array = []
			for record in baseline:
				broken.append(record.duplicate(true))
			if fault[2] == "":
				broken[-1] = fault[1]
			else:
				broken[-1][fault[2]] = fault[1]
			_reject(side, broken, side + " " + fault[0], party, enemies)
		var duplicate_id := baseline.duplicate(true)
		duplicate_id[-1]["id"] = duplicate_id[0]["id"]
		_reject(side, duplicate_id, side + " duplicate ID", party, enemies)
		var duplicate_slot := baseline.duplicate(true)
		duplicate_slot[-1]["position"] = 1
		_reject(side, duplicate_slot, side + " duplicate position", party, enemies)
		var reordered := baseline.duplicate(true)
		reordered.reverse()
		_reject(side, reordered, side + " nonauthoritative order", party, enemies)
		var late_invalid := baseline.duplicate(true)
		late_invalid[0]["statuses"] = {"bleed": 2}
		late_invalid[-1]["statuses"] = {"exposed": -1}
		_reject(side, late_invalid, side + " late invalid after earlier valid bleed", party, enemies)
		var late_tangled := baseline.duplicate(true)
		late_tangled[0]["statuses"] = {"tangled": 2, "riposte": 4}
		late_tangled[-1]["statuses"] = {"tangled": 1.5}
		_reject(side, late_tangled,
			side + " late float Tangled after earlier valid Tangled/Riposte", party, enemies)
		var late_riposte := baseline.duplicate(true)
		late_riposte[0]["statuses"] = {"tangled": 1, "riposte": 4}
		late_riposte[-1]["statuses"] = {"riposte": -1}
		_reject(side, late_riposte,
			side + " late negative Riposte after earlier valid Tangled/Riposte", party, enemies)
		var late_unknown := baseline.duplicate(true)
		late_unknown[0]["statuses"] = {"tangled": 1, "riposte": 4}
		late_unknown[-1]["statuses"] = {"riposte": 4, "poison": 1}
		_reject(side, late_unknown,
			side + " late unknown status beside Riposte", party, enemies)
	# Enemy APIs accept one or three slots as well as the two-slot starter roster.
	for count in [1, 3]:
		var definitions: Array = []
		for index in range(count):
			definitions.append({"id": "enemy_%d" % index, "max_hp": 12})
		var other_enemies := CombatEnemies.new(definitions)
		_check(other_enemies.is_valid() and other_enemies.get_enemies().size() == count,
			"precondition: real variable-size enemy roster")
		var state := other_enemies.get_enemies()
		_check(batch.tick_side("enemies", state) == _expected("enemies", state),
			"valid enemy count %d delegates every slot" % count)
