class_name CombatEnemyPhase
extends RefCounted
## Stage every source in order, then publish once. No turn or RNG ownership.

## Authored content flag: this enemy's own attack also inflicts Bleed 1 on the
## hero who really loses HP to it. Strictly boolean or absent.
const BLEED_ON_ATTACK_FIELD := "bleed_on_attack"
const BLEED_ON_ATTACK_AMOUNT := 1

func execute_phase(party: CombatParty, enemies: CombatEnemies, intents: Array,
		reactions: CombatWardenGuardReactions = null, policy_targets := false) -> Dictionary:
	var failure := {"ok": false, "events": []}
	if party == null or enemies == null or not party.is_valid() or not enemies.is_valid():
		return failure
	var heroes := party.get_heroes()
	var roster := enemies.get_enemies()
	# Malformed authored metadata fails the whole phase before any actor is
	# staged or published; an absent flag stays valid.
	if not _bleed_metadata_valid(roster):
		return failure
	var validator := CombatStatusTurnBatch.new()
	if not validator.tick_side("heroes", heroes).ok or not validator.tick_side("enemies", roster).ok:
		return failure
	var ordered: Array[Dictionary] = []
	var seen: Array[int] = []
	for raw in intents:
		if not raw is Dictionary:
			return failure
		var source = raw.get("enemy_position")
		if not source is int or source < 1 or source > roster.size() or source in seen:
			return failure
		var action: Dictionary = raw.duplicate(true)
		action.erase("enemy_position")
		if not CombatEnemyIntents.valid_action(action):
			return failure
		seen.append(source)
		ordered.append(raw.duplicate(true))
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.enemy_position < b.enemy_position)
	var staged_party := CombatParty.new(heroes)
	staged_party._heroes = heroes
	var staged_enemies := CombatEnemies.new(roster)
	staged_enemies._enemies = roster
	var events: Array[Dictionary] = []
	for action in ordered:
		var source: int = action.enemy_position
		# A cached policy announcement resolves against the actors as they stand
		# at its own beat: a hero downed earlier this phase or during the player
		# turn falls back deterministically to the policy's first living target.
		# Legacy pattern schedules keep their exact announced target, so only a
		# caller that passes battle-bound announcements opts into the fallback.
		var effective: Dictionary = action
		var policy := CombatEnemyIntents.policy_for(staged_enemies, source) \
			if policy_targets else ""
		if not staged_enemies.is_slain(source) and not policy.is_empty():
			effective = CombatEnemyIntents.resolve_announced_action(staged_party, action, staged_enemies)
		var event := {"type": effective.type, "enemy_position": source, "applied": false}
		for field in ["target_position", "status", "direction"]:
			if effective.has(field):
				event[field] = effective[field]
		if not staged_enemies.is_slain(source):
			if effective.type == "attack":
				var actual_target: int = effective.target_position
				if reactions != null:
					var preview: Dictionary = reactions.preview_actual_recipient(
						staged_party, effective.target_position)
					if not preview.get("ok", false):
						return failure
					actual_target = preview.actual_target_position
				# The sting's status is judged by the recipient's real HP change,
				# so Block and a Guard redirect decide it, not the announcement.
				var sting: bool = _stings(staged_enemies, source)
				var hp_before: int = -1
				if sting and actual_target >= 1 and actual_target <= CombatParty.PARTY_SIZE:
					hp_before = staged_party.get_hero(actual_target).get("hp", 0)
				var damage := CombatStatuses.new().adjusted_attack_damage(effective.amount,
					staged_enemies.get_enemy(source).get("statuses", {}),
					staged_party.get_hero(actual_target).get("statuses", {}))
				var attack: Dictionary = effective.duplicate(true)
				attack.erase("type")
				attack.amount = damage
				if reactions != null:
					var reaction_result: Dictionary = reactions.resolve_enemy_attack(
						staged_party, staged_enemies, attack)
					if not reaction_result.get("ok", false):
						return failure
					event.applied = reaction_result.applied
					event.actual_target_position = reaction_result.actual_target_position
					event.redirected = reaction_result.redirected
					event.retaliation_damage = reaction_result.retaliation_damage
					event.retaliatory_damage = reaction_result.retaliatory_damage
				else:
					var result := CombatEnemyAttacks.new().execute_attacks(staged_party, [attack])
					if not result.ok:
						return failure
					event.applied = result.events[0].applied
				# A slain attacker (Thorns retaliation) never lands its sting, and
				# the bonus status must not break the batch's atomicity.
				if sting and not staged_enemies.is_slain(source) \
						and not _sting_bleed(staged_party, actual_target, hp_before):
					return failure
			elif effective.type == "block":
				var result := CombatEnemyBlocks.execute_blocks(staged_enemies, [effective])
				if not result.ok:
					return failure
				event.applied = result.events[0].applied
			else:
				# A policy shove announced before a neighbour fell cannot be
				# executed; its beat stays inert instead of failing the batch.
				if effective.type == "shove" and not policy.is_empty() \
						and not CombatEnemyIntents.shove_is_legal(staged_party,
							effective.target_position, effective.direction):
					event.applied = false
				else:
					var result := CombatEnemySpecialActions.new().execute_actions(
						staged_party, staged_enemies, [effective])
					if not result.ok:
						return failure
					event.applied = result.events[0].applied
		if reactions != null and effective.type == "attack" and not event.has("actual_target_position"):
			# A slain source never enters the resolver, but still has a useful
			# skipped beat in the reaction-mode trace.
			event.actual_target_position = effective.target_position
			event.redirected = false
			event.retaliation_damage = 0
			event.retaliatory_damage = 0
		events.append(event)
	# Preserve dictionaries and unrelated metadata; actor identity follows swaps.
	var originals: Dictionary = {}
	for hero in party._heroes:
		originals[hero.id] = hero
	for index in range(heroes.size()):
		var next: Dictionary = staged_party._heroes[index]
		var original: Dictionary = originals[next.id]
		for field in ["position", "hp", "block", "statuses"]:
			if next.has(field):
				original[field] = next[field]
		party._heroes[index] = original
	for index in range(roster.size()):
		# Retaliation can damage an attacker and consume its Block, but slain
		# sources must remain in the same original enemy slot/dictionary.
		enemies._enemies[index].hp = staged_enemies._enemies[index].hp
		enemies._enemies[index].block = staged_enemies._enemies[index].block
	return {"ok": true, "events": events}


## True only for a roster record that authors the boolean bleeding sting.
static func _stings(enemies: CombatEnemies, source: int) -> bool:
	if enemies == null or not enemies.is_valid():
		return false
	var value: Variant = enemies.get_enemy(source).get(BLEED_ON_ATTACK_FIELD, false)
	return value is bool and value == true


## The optional authored flag is content, never a number or a truthy string:
## one malformed record fails the whole phase before any beat is staged.
static func _bleed_metadata_valid(roster: Array) -> bool:
	for enemy in roster:
		if not enemy is Dictionary:
			return false
		if enemy.has(BLEED_ON_ATTACK_FIELD) \
				and not (enemy[BLEED_ON_ATTACK_FIELD] is bool):
			return false
	return true


## Add exactly one Bleed to the hero who actually lost HP to the sting, already
## staged so it publishes with the rest of the phase. A fully blocked hit, a
## downed recipient or a stale reading is a no-op; an overflowing counter fails.
func _sting_bleed(staged_party: CombatParty, position: int, hp_before: int) -> bool:
	if staged_party == null or not staged_party.is_valid():
		return false
	if position < 1 or position > CombatParty.PARTY_SIZE or hp_before < 0:
		return true
	var hero: Dictionary = staged_party._heroes[position - 1]
	var hp_after: Variant = hero.get("hp")
	if not hp_after is int:
		return false
	if hp_after <= 0 or hp_after >= hp_before:
		return true
	var raw_statuses: Variant = hero.get("statuses", {})
	if not raw_statuses is Dictionary:
		return false
	var statuses: Dictionary = raw_statuses
	var previous: Variant = statuses.get("bleed", 0)
	if not previous is int or previous < 0:
		return false
	if previous >= CombatStatuses.MAX_INT:
		return false
	if not hero.has("statuses"):
		hero["statuses"] = {}
	hero["statuses"]["bleed"] = previous + BLEED_ON_ATTACK_AMOUNT
	return true
