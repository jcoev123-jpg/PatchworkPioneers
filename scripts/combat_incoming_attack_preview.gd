class_name CombatIncomingAttackPreview
extends RefCounted
## Pure End Turn attack forecast after hero owner ticks. HP loss excludes Bleed;
## remaining HP includes it. Block reset belongs to the NEXT player turn.
## Every announced enemy kind is forecast from the real phase rules; a roster
## the committed phase would reject fails closed instead of inventing damage.

const MAX_INT := 9223372036854775807


func forecast(heroes: Array, enemies: Array, intents: Array,
		policy_targets := false) -> Dictionary:
	var invalid := {"ok": false, "heroes": []}
	if heroes.size() != CombatParty.PARTY_SIZE or enemies.is_empty() \
			or enemies.size() > CombatEnemies.OPT_IN_MAX_ENEMIES or intents.size() != enemies.size():
		return invalid
	var capacity := CombatEnemies.OPT_IN_MAX_ENEMIES if enemies.size() == CombatEnemies.OPT_IN_MAX_ENEMIES else CombatEnemies.MAX_ENEMIES
	var batch := CombatStatusTurnBatch.new()
	var tick := batch.tick_side("heroes", heroes)
	if not tick["ok"] or not batch.tick_side("enemies", enemies, capacity)["ok"]:
		return invalid
	for index in range(heroes.size()):
		if not _valid_actor(heroes[index], index + 1):
			return invalid
	for index in range(enemies.size()):
		if not _valid_actor(enemies[index], index + 1):
			return invalid
	var ordered := _validated_actions(enemies.size(), intents)
	if ordered.is_empty() or not _supported_actions(enemies, ordered, tick["actors"]):
		return invalid
	# The committed phase is the sole authority on whether the complete roster
	# is legal, including effects that depend on an earlier source.
	if not CombatEnemyPhase.new().execute_phase(_detached_party(tick["actors"]),
			_detached_enemies(enemies, capacity), ordered, null, policy_targets)["ok"]:
		return invalid
	# A shove changes positions, so every total follows the original actor id:
	# the returned rows stay on each actor's currently presented slot.
	return _simulate(_detached_party(tick["actors"]), _detached_enemies(enemies, capacity), ordered,
		heroes, policy_targets)


## Some real phase beats carry extra effects that this detached damage-only
## replay does not reproduce. Never turn an accepted complex phase into a
## plausible but false numerical ticket.
func _supported_actions(roster: Array, ordered: Array[Dictionary], heroes: Array) -> bool:
	for action in ordered:
		var kind: String = action["type"]
		if kind == "summon" or kind == "snip_block" or action.has("hits"):
			return false
		var actor: Dictionary = roster[action["enemy_position"] - 1]
		var charge: Variant = actor.get(CombatEnemyIntents.CHARGE_FLAG, false)
		if charge is bool and charge:
			return false
		if kind == "attack" and actor["hp"] > 0:
			for flag in [CombatEnemyPhase.CHEW_BLOCK_ON_ATTACK_FIELD,
					CombatEnemyPhase.DRAIN_FIELD, CombatEnemyPhase.BLEED_ON_ATTACK_FIELD,
					CombatEnemyPhase.ENRAGE_FIELD]:
				var value: Variant = actor.get(flag, false)
				if value is bool and value:
					return false
			var blind: Variant = actor.get("statuses", {}).get("blind_next_attack", 0)
			if blind is int and blind == 1:
				return false
			# Riposte can kill a source between beats; this replay only accounts
			# for hero damage, not the retaliatory enemy death and its later skips.
			for hero in heroes:
				if hero.get("statuses", {}).get("riposte", 0) > 0:
					return false
	return true


## The caller's schedule must be complete: exactly one announcement per source.
func _validated_actions(enemy_count: int, intents: Array) -> Array[Dictionary]:
	var seen: Array[int] = []
	var ordered: Array[Dictionary] = []
	for raw_intent in intents:
		if not raw_intent is Dictionary:
			return []
		var source = raw_intent.get("enemy_position")
		if not source is int or source < 1 or source > enemy_count or source in seen:
			return []
		var action: Dictionary = raw_intent.duplicate(true)
		action.erase("enemy_position")
		# Exactly the committed phase's action contract: type, amount, target,
		# status and direction keys, ranges and exact dictionary shapes.
		if not CombatEnemyIntents.valid_action(action):
			return []
		seen.append(source)
		ordered.append(raw_intent.duplicate(true))
	if seen.size() != enemy_count:
		return []
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["enemy_position"] < b["enemy_position"])
	return ordered


## Replays the committed phase's source order on detached actors and keeps the
## hero-local attack totals, so swaps never move a total onto another actor.
func _simulate(party: CombatParty, enemies: CombatEnemies,
		ordered: Array[Dictionary], presented: Array, policy_targets := false) -> Dictionary:
	var invalid := {"ok": false, "heroes": []}
	var totals: Dictionary = {}
	for hero in party._heroes:
		totals[hero["id"]] = {"incoming": 0, "block_absorbed": 0, "hp_lost": 0}
	for action in ordered:
		var source: int = action["enemy_position"]
		# A battle-bound policy announcement resolves its living-target fallback
		# exactly as the committed phase will, without drawing any RNG.
		var policy := CombatEnemyIntents.policy_for(enemies, source) if policy_targets else ""
		var effective: Dictionary = action
		if not policy.is_empty():
			effective = CombatEnemyIntents.resolve_announced_action(party, action, enemies)
		var before := _hp_block(party)
		if not enemies.is_slain(source):
			if effective["type"] == "attack":
				var target: int = effective["target_position"]
				var damage := CombatStatuses.new().adjusted_attack_damage(effective["amount"],
					enemies.get_enemy(source).get("statuses", {}),
					party.get_hero(target).get("statuses", {}))
				var attack: Dictionary = effective.duplicate(true)
				attack.erase("type")
				attack.amount = damage
				var hit := CombatEnemyAttacks.new().execute_attacks(party, [attack], enemies.get_capacity())
				if not hit["ok"]:
					return invalid
				if hit["events"][0]["applied"]:
					var id: String = party.get_hero(target)["id"]
					if damage > MAX_INT - totals[id]["incoming"]:
						return invalid
					totals[id]["incoming"] += damage
			elif effective["type"] == "block":
				var block := CombatEnemyBlocks.execute_blocks(enemies, [effective])
				if not block["ok"]:
					return invalid
			else:
				var special: Dictionary = effective.duplicate(true)
				var result := CombatEnemySpecialActions.new().execute_actions(party, enemies, [special])
				if not result["ok"]:
					# A policy shove with no living neighbour is an inert beat.
					if not (special["type"] == "shove"
							and not policy.is_empty()
							and not CombatEnemyIntents.shove_is_legal(party,
								special["target_position"], special["direction"])):
						return invalid
		var after := _hp_block(party)
		for id in after:
			totals[id]["block_absorbed"] += before[id]["block"] - after[id]["block"]
			totals[id]["hp_lost"] += before[id]["hp"] - after[id]["hp"]
	var final: Dictionary = {}
	for hero in party._heroes:
		final[hero["id"]] = hero
	var rows: Array[Dictionary] = []
	for index in range(presented.size()):
		var id: String = presented[index]["id"]
		var actor: Dictionary = final[id]
		var total: Dictionary = totals[id]
		rows.append({"position": index + 1, "downed": actor["hp"] == 0,
			"incoming": total["incoming"], "block_absorbed": total["block_absorbed"],
			"hp_lost": total["hp_lost"], "hp_remaining": actor["hp"],
			"block_remaining": actor["block"]})
	return {"ok": true, "heroes": rows}


func _hp_block(party: CombatParty) -> Dictionary:
	var snapshot: Dictionary = {}
	for hero in party._heroes:
		snapshot[hero["id"]] = {"hp": hero["hp"], "block": hero["block"]}
	return snapshot


func _detached_party(actors: Array) -> CombatParty:
	var party := CombatParty.new(actors)
	party._heroes.assign(actors.duplicate(true))
	return party


func _detached_enemies(roster: Array, capacity: int) -> CombatEnemies:
	var enemies := CombatEnemies.new(roster, capacity)
	enemies._enemies.assign(roster.duplicate(true))
	return enemies


func _valid_actor(actor: Variant, expected_position: int) -> bool:
	if not actor is Dictionary:
		return false
	for field in ["position", "max_hp", "hp", "block"]:
		if not actor.has(field) or not actor[field] is int:
			return false
	return actor["position"] == expected_position and actor["max_hp"] > 0 and actor["hp"] >= 0 and actor["hp"] <= actor["max_hp"] and actor["block"] >= 0
