extends SceneTree

const Service = preload("res://scripts/combat_tinker_v3_starter_attack_cards.gd")
const Catalog = preload("res://data/cards/v3_tinker_starter_cards.gd")
const IDS := ["tinker_v3_cog_shot", "tinker_v3_cog_shot_plus",
	"tinker_v3_scrap_bomb", "tinker_v3_scrap_bomb_plus"]
var checks := 0
var failures := 0


func _initialize() -> void:
	_catalog_contract()
	_paid_attacks()
	_paid_staged_fourth()
	_refusals()
	_counter_interoperability()
	print("Tinker starter attacks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(message)


func _fixture(id: String, seat: int = 3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 463
	var cards: Array[String] = [id, id, "other"]
	var deck := CombatDeck.new(cards, rng)
	_check(deck.start_turn(), "real active deck")
	var definitions: Array = [{"id": "warden", "max_hp": 30},
		{"id": "seamstress", "max_hp": 30}, {"id": "tinker", "max_hp": 30}]
	var swap: Dictionary = definitions[seat - 1]
	definitions[seat - 1] = definitions[2]
	definitions[2] = swap
	var party := CombatParty.new(definitions)
	var enemies := CombatEnemies.new([{"id": "a", "max_hp": 20},
		{"id": "b", "max_hp": 20}, {"id": "c", "max_hp": 20}])
	_check(party.is_valid() and enemies.is_valid(), "real valid party and enemies")
	return {"deck": deck, "party": party, "enemies": enemies, "rng": rng,
		"wallet": {"scraps": 91}, "receipt": {"previous": true}}


func _snapshot(f: Dictionary) -> Dictionary:
	var deck: CombatDeck = f.deck
	return {"hand": deck.hand.duplicate(), "draw": deck.draw_pile.duplicate(),
		"discard": deck.discard_pile.duplicate(), "exhausted": deck.exhausted.duplicate(),
		"combat_state": inst_to_dict(deck.combat_state).duplicate(true),
		"party": f.party._heroes.duplicate(true), "enemies": f.enemies._enemies.duplicate(true),
		"rng": f.rng.state, "seed": f.rng.seed, "wallet": f.wallet.duplicate(true),
		"receipt": f.receipt.duplicate(true)}


func _catalog_contract() -> void:
	var service := Service.new()
	var catalog := Catalog.new()
	for id in IDS:
		var definition := catalog.get_definition(id)
		_check(not definition.is_empty() and service.is_supported_card(id), "authentic " + id)
		var plus: bool = id.ends_with("_plus")
		_check(definition.get("upgrade_of" if plus else "upgrade_id") ==
			(id.trim_suffix("_plus") if plus else id + "_plus"), "upgrade link " + id)
		for key in definition:
			var forged := definition.duplicate(true)
			forged.erase(key)
			_check(not service.is_authentic_definition(forged, id), "missing field " + key)
		for alteration in [{"damage": 99, "combat_scrap_gain": 1},
			{"damage": float(definition.effects.damage), "combat_scrap_gain": 1},
			{"damage": definition.effects.damage, "combat_scrap_gain": 1, "extra": true}]:
			var forged := definition.duplicate(true)
			forged.effects = alteration
			_check(not service.is_authentic_definition(forged, id), "changed effects rejected")
		var forged := definition.duplicate(true)
		forged.owner = "warden"
		_check(not service.is_authentic_definition(forged, id), "forged owner")
		forged = definition.duplicate(true)
		forged["upgrade_of" if plus else "upgrade_id"] = "fake"
		_check(not service.is_authentic_definition(forged, id), "forged link")
	for id in ["fake", "tinker_pop_shot", "tinker_v3_overload", "tinker_v3_casing_ward", 1, null]:
		_check(not service.is_supported_card(id), "foreign ID")


func _paid_attacks() -> void:
	var service := Service.new()
	for i in range(IDS.size()):
		var id: String = IDS[i]
		var area := i >= 2
		var damage: int = [5, 7, 4, 6][i]
		for seat in ([3] if area else [2, 3]):
			for block in [0, 2, 10]:
				var f := _fixture(id, seat)
				f.enemies.gain_block(1, block)
				f.enemies.gain_block(3, 1)
				f.enemies.apply_damage(2, 20)
				f.party._heroes[seat - 1]["combat_scrap"] = 4
				f.party._heroes[0]["combat_scrap"] = 8
				var before := _snapshot(f)
				var plan := service.preflight(f.deck, f.party, f.enemies, id, 0 if area else 1)
				_check(plan.ok and _snapshot(f) == before, "legal preflight pure")
				var receipt := service.play_card(f.deck, f.party, f.enemies, id, 0 if area else 1)
				_check(receipt.ok, "paid " + id)
				_check(receipt.cost == (2 if area else 1) and
					f.deck.energy == 3 - receipt.cost, "printed energy once")
				_check(f.deck.hand.count(id) == 1 and f.deck.discard_pile == [id], "one held copy discarded")
				_check(receipt.combat_scrap_before == 4 and receipt.combat_scrap_after == 5
					and f.party.get_hero(seat).combat_scrap == 5, "one scrap per cast")
				_check(f.party.get_hero(1).combat_scrap == 8, "other hero counter preserved")
				_check(receipt.hits.size() == (2 if area else 1), "living targets only")
				var hit: Dictionary = receipt.hits[0]
				_check(hit.position == 1 and hit.raw_damage == damage and hit.block_before == block
					and hit.block_after == maxi(0, block - damage)
					and hit.block_absorbed == mini(block, damage) and hit.hp_before == 20
					and hit.hp_after == 20 - maxi(0, damage - block)
					and hit.hp_loss == maxi(0, damage - block), "actual block/HP receipt")
				_check(f.enemies._enemies[1] == before.enemies[1], "slain slot untouched")
				if area:
					_check(receipt.hits[1].position == 3 and receipt.hits[1].block_absorbed == 1
						and receipt.hits[1].hp_loss == damage - 1, "independent AoE block and original slot")
				else:
					_check(f.enemies._enemies[2] == before.enemies[2], "unchosen enemy untouched")
				_check(f.rng.state == before.rng and f.wallet == before.wallet, "no RNG or wallet use")
		# Exact seeded replay, including receipt and all resulting state.
		var a := _fixture(id)
		var b := _fixture(id)
		var target := 0 if area else 3
		var ra := service.play_card(a.deck, a.party, a.enemies, id, target)
		var rb := service.play_card(b.deck, b.party, b.enemies, id, target)
		_check(ra.ok and ra == rb and _snapshot(a) == _snapshot(b), "seeded identical replay")
		_check(a.party.get_hero(3).combat_scrap == 1, "absent counter starts at zero")


## An authored Moth mother starts in a genuine three-foe, four-capacity
## CombatEnemies roster. Its real staging method (not an injected fourth record)
## supplies the fourth target for both printed attack families.
func _staged_four_fixture(id: String, seat: int = 3) -> Dictionary:
	var f := _fixture(id, seat)
	var mother := {
		"id": CombatEnemies.MOTH_ID, "name": "Moth Swarm", "max_hp": 21,
		"art_path": "res://assets/paper/enemies/moth_swarm.png",
		"chew_block_on_attack": true,
		"intent": {"target": "front", "actions": [
			{"type": "snip_block", "amount": 0, "weight": 2},
			{"type": "attack", "amount": 7, "weight": 3},
			{"type": "debuff", "status": "weak", "amount": 1, "weight": 1},
			{"type": "summon", "amount": 0, "weight": 1},
			{"type": "attack", "amount": 6, "hits": 2, "move": "attack2", "weight": 1}
		]}}
	var enemies := CombatEnemies.new([mother, {"id": "guard", "max_hp": 20},
		{"id": "ward", "max_hp": 20}], CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(enemies.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES
		and enemies._enemies.size() == 3 and enemies.is_valid()
		and CombatEnemies.authentic_broodling_mother(enemies._enemies[0], 1),
		"genuine three-foe opt-in roster and authentic Moth mother")
	var birth := enemies.stage_broodling(1)
	_check(birth == {"ok": true, "spawned": true, "position": 4}
		and enemies._enemies.size() == 4
		and enemies._enemies[3].id == CombatEnemies.BROODLING_ID
		and enemies._enemies[3].position == 4 and enemies._enemies[3].hp == 8
		and enemies._enemies[0].get(CombatEnemies.BROODLING_LATCH) == true,
		"real broodling occupies living fourth position, no slot compaction")
	f.enemies = enemies
	return f


func _paid_staged_fourth() -> void:
	var service := Service.new()
	for i in range(IDS.size()):
		var id: String = IDS[i]
		var area: bool = i >= 2
		var damage: int = [5, 7, 4, 6][i]
		var positions: Array = [1, 3, 4] if area else [4]
		for seat in ([3] if area else [2, 3]):
			var a := _staged_four_fixture(id, seat)
			var b := _staged_four_fixture(id, seat)
			for f in [a, b]:
				_check(f.enemies.gain_block(1, 2) and f.enemies.gain_block(3, 9)
					and f.enemies.gain_block(4, 3)
					and f.enemies.apply_damage(2, 20)
					and f.enemies._enemies[1].hp == 0,
					"prepared independent Block and slain original slot")
				f.party._heroes[seat - 1]["combat_scrap"] = 4
			var before := _snapshot(a)
			_check(before.enemies.size() == 4 and before.enemies[3].hp == 8
				and a.deck.hand.has(id), "nonvacuous fourth-target paid preconditions")
			var target: int = 0 if area else 4
			var plan := service.preflight(a.deck, a.party, a.enemies, id, target)
			_check(plan.get("ok", false) and plan.get("cost") == (2 if area else 1)
				and plan.get("raw_damage") == damage and _snapshot(a) == before,
				"pure staged-fourth preflight " + id)
			if plan.get("ok", false):
				var plan_positions: Array[int] = []
				for foe in plan.targets:
					plan_positions.append(foe.position)
				_check(plan_positions == positions,
					"preflight names only actual living original slots " + id)
			var result := service.play_card(a.deck, a.party, a.enemies, id, target)
			var replay := service.play_card(b.deck, b.party, b.enemies, id, target)
			_check(result.get("ok", false) and result == replay
				and _snapshot(a) == _snapshot(b), "identical paid four-foe seed replay " + id)
			if not result.get("ok", false):
				continue
			_check(result.cost == (2 if area else 1)
				and result.raw_damage == damage
				and result.energy_before == 3 and result.energy_after == 3 - result.cost
				and a.deck.energy == result.energy_after
				and a.deck.hand.count(id) == 1 and a.deck.discard_pile == [id],
				"exact printed cost and one held discard " + id)
			_check(result.combat_scrap_before == 4 and result.combat_scrap_gain == 1
				and result.combat_scrap_after == 5
				and a.party._heroes[seat - 1].combat_scrap == 5,
				"exactly one Combat Scrap per cast (not per AoE recipient) " + id)
			for hero_index in range(3):
				if hero_index != seat - 1:
					_check(a.party._heroes[hero_index] == before.party[hero_index],
						"other hero unchanged " + id)
			_check(a.rng.state == before.rng and a.wallet == before.wallet
				and a.receipt == before.receipt, "no wallet/RNG/foreign receipt mutations " + id)
			var hits: Array = result.hits
			_check(hits.size() == positions.size(), "correct living hit count " + id)
			if hits.size() != positions.size():
				continue
			for j in range(positions.size()):
				var position: int = positions[j]
				var hit: Dictionary = hits[j]
				var enemy_before: Dictionary = before.enemies[position - 1]
				var enemy_after: Dictionary = a.enemies._enemies[position - 1]
				var absorbed: int = mini(enemy_before.block, damage)
				var lost: int = mini(enemy_before.hp, damage - absorbed)
				_check(hit.position == position and hit.raw_damage == damage
					and hit.block_before == enemy_before.block
					and hit.block_after == enemy_before.block - absorbed
					and hit.block_absorbed == absorbed
					and hit.hp_before == enemy_before.hp
					and hit.hp_after == enemy_before.hp - lost
					and hit.hp_loss == lost
					and enemy_after.block == hit.block_after
					and enemy_after.hp == hit.hp_after,
					"accurate original-slot Block/HP and receipt for %s slot %d" % [id, position])
			for slot in range(1, 5):
				if slot not in positions:
					_check(a.enemies._enemies[slot - 1] == before.enemies[slot - 1],
						"slain/unchosen original slot untouched for " + id)


func _refusals() -> void:
	for id in IDS:
		for problem in ["owner", "from", "middle_bomb", "downed", "unheld", "fake", "target", "energy",
			"inactive", "slain", "chosen_slain", "counter", "overflow", "enemy_flags", "catalog",
			"pending_revive", "dead_fourth", "fifth", "fifth_target", "out_of_capacity",
			"position_gap", "bad_hp_fourth", "default_four"]:
			if problem == "middle_bomb" and not id.contains("bomb"):
				continue
			if problem == "dead_fourth" and id.contains("bomb"):
				continue
			var f := _fixture(id)
			var service := Service.new()
			var request: Variant = id
			var target := 0 if id.contains("bomb") else 1
			match problem:
				"owner": f.party._heroes[2].id = "stranger"
				"from":
					f = _fixture(id, 1)
				"middle_bomb": f = _fixture(id, 2)
				"downed": f.party.apply_damage(3, 30)
				"unheld": f.deck.hand.clear()
				"fake":
					request = id + "_forged"
					f.deck.hand.append(request)
				"target": target = 4
				"energy": f.deck.try_spend_energy(3)
				"inactive": f.deck.end_turn()
				"slain":
					for position in [1, 2, 3]:
						f.enemies.apply_damage(position, 20)
				"chosen_slain":
					f.enemies.apply_damage(1, 20)
					# A single-target request cannot substitute another living slot;
					# an AoE request cannot select a slot at all.
					target = 1
				"pending_revive":
					f.enemies._enemies[2]["revive_once"] = true
					f.enemies._enemies[2].hp = 0
				"counter": f.party._heroes[2]["combat_scrap"] = -1
				"overflow": f.party._heroes[2]["combat_scrap"] = CombatParty.MAX_INT
				"enemy_flags": f.enemies._enemies[2]["revive_once"] = 1
				"catalog": service._catalog._definitions[id].effects.damage = 99
				"dead_fourth":
					f = _staged_four_fixture(id)
					_check(f.enemies.apply_damage(4, 8), "real fourth foe slain")
					target = 4
				"fifth":
					f = _staged_four_fixture(id)
					f.enemies._enemies.append({"id": "extra", "max_hp": 20, "hp": 20,
						"block": 0, "position": 5})
				"fifth_target":
					f = _staged_four_fixture(id)
					target = 5
				"out_of_capacity":
					f = _staged_four_fixture(id)
					f.enemies._capacity = CombatEnemies.MAX_ENEMIES
				"position_gap":
					f = _staged_four_fixture(id)
					f.enemies._enemies[3]["position"] = 5
				"bad_hp_fourth":
					f = _staged_four_fixture(id)
					f.enemies._enemies[3]["hp"] = -1
				"default_four":
					f.enemies = CombatEnemies.new([{"id": "a", "max_hp": 20},
						{"id": "b", "max_hp": 20}, {"id": "c", "max_hp": 20},
						{"id": "d", "max_hp": 20}])
			var before := _snapshot(f)
			var plan := service.preflight(f.deck, f.party, f.enemies, request, target)
			_check(not plan.ok and _snapshot(f) == before, "pure refused preflight " + problem)
			var result := service.play_card(f.deck, f.party, f.enemies, request, target)
			_check(not result.ok and result == plan and _snapshot(f) == before, "atomic refusal " + problem)
	# A getter-triggered revival must not mutate a rejected request.
	var f := _fixture(IDS[0])
	f.enemies._enemies[2]["revive_once"] = true
	f.enemies._enemies[2].hp = 0
	var before := _snapshot(f)
	_check(not Service.new().play_card(f.deck, f.party, f.enemies, "fake", 1).ok
		and _snapshot(f) == before, "refusal does not settle revival")


func _counter_interoperability() -> void:
	var f := _fixture(IDS[0])
	var support := CombatTinkerV3ScrapSupportCards.new()
	f.deck.hand.append("tinker_v3_casing_ward")
	_check(support.play_card(f.deck, f.party, "tinker_v3_casing_ward").ok, "real support producer")
	_check(Service.new().play_card(f.deck, f.party, f.enemies, IDS[0], 1).ok,
		"attack shares support counter")
	f.deck.hand.append("tinker_v3_overload")
	var receipt := CombatTinkerV3OverloadCards.new().play_card(
		f.deck, f.party, f.enemies, "tinker_v3_overload", 3)
	_check(receipt.ok and receipt.combat_scrap_before == 2 and receipt.raw_damage == 8
		and f.party.get_hero(3).combat_scrap == 0, "real Overload consumes same counter")
