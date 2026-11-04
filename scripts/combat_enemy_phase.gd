class_name CombatEnemyPhase
extends RefCounted
## Stage every source in order, then publish once. No turn or RNG ownership.

## Authored content flag: this enemy's own attack also inflicts Bleed 1 on the
## hero who really loses HP to it. Strictly boolean or absent.
const BLEED_ON_ATTACK_FIELD := "bleed_on_attack"
const BLEED_ON_ATTACK_AMOUNT := 1
## Authored content flag: this enemy heals for the HP its own confirmed hit
## really removed, clamped to its missing HP. Block-absorbed damage is not
## Drain. Strictly boolean or absent, exactly like the bleeding sting.
const DRAIN_FIELD := "drain"
## Authored content flag: this enemy's own real attack first eats ALL Block on
## the hero who will actually take it, so the full status-adjusted bite reaches
## HP. Staged with the rest of the batch and strictly boolean or absent.
const CHEW_BLOCK_ON_ATTACK_FIELD := "chew_block_on_attack"
## Authored content flag: this enemy's own executed attack gains +2 damage per
## stored Enrage stack. Strictly boolean or absent; non-Enrage sources gain
## nothing even when a stack count is left over.
const ENRAGE_FIELD := "enrage"
## Optional stack count for an Enrage source: an integer in 0..3, where an
## absent count means zero. The phase only ever READS it; awarding a stack after
## a player hit is a separate task.
const ENRAGE_STACKS_FIELD := "enrage_stacks"

## `eyelet` is the ONE fight-scoped Button Golem Eyelet Guard authority admitted
## by CombatRoundFlow. It is quoted read-only on this phase's detached actors and
## only ever writes retaliation into the staged enemy roster, so a rejected batch
## publishes neither its damage nor its thorns.
## Optional `run_gold` is a carried nonnegative integer. Wallet-aware success
## adds `gold`; each theft event reports actual `amount` and remaining `gold`.
## The caller adopts that final balance only when the entire phase succeeds.
func execute_phase(party: CombatParty, enemies: CombatEnemies, intents: Array,
		reactions: CombatWardenGuardReactions = null, policy_targets := false,
		eyelet: CombatButtonGolemEyeletGuardCards = null, run_gold: Variant = null) -> Dictionary:
	var failure := {"ok": false, "events": []}
	# Null preserves the exact legacy receipt. A supplied wallet is strictly an
	# integer balance; only the successful final receipt publishes its new value.
	if run_gold != null and (not run_gold is int or run_gold < 0):
		return failure
	var staged_gold: int = run_gold if run_gold is int else 0
	if party == null or enemies == null or not party.is_valid() or not enemies.is_valid():
		return failure
	var heroes := party.get_heroes()
	var roster := enemies.get_enemies()
	# Malformed authored metadata fails the whole phase before any actor is
	# staged or published; an absent flag stays valid.
	if not _attack_metadata_valid(roster):
		return failure
	var validator := CombatStatusTurnBatch.new()
	if not validator.tick_side("heroes", heroes).ok or not validator.tick_side("enemies", roster, enemies.get_capacity()).ok:
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
		var actor: Dictionary = roster[source - 1]
		var has_authored_move := false
		var spec: Variant = actor.get("intent")
		# Raw presence also opts in: malformed keyed data must not silently
		# downgrade the source to the legacy unkeyed execution contract.
		if spec is Dictionary and spec.get("actions") is Array:
			for entry in spec.actions:
				if entry is Dictionary and entry.has("move"):
					has_authored_move = true
		if action.has("move") or (policy_targets and action.get("type") == "attack" and has_authored_move
				and actor.get(CombatEnemyIntents.CHARGE_FLAG, false) != true):
			# Only this source's current authored amount/move pair is authority.
			# RoundFlow owns cache identity; presentation metadata owns neither.
			# Unbound legacy schedules retain their independent plain amounts.
			var slot := CombatEnemyIntents._weighted_slot(source, actor.get("intent"))
			var candidate := action.duplicate(true)
			candidate.erase("target_position")
			var authored := false
			for entry in slot.get("actions", []):
				if entry["action"] == candidate:
					authored = true
			if not authored:
				return failure
			# A front-policy announcement cannot select a later living seat while
			# an earlier seat is alive. Downed cached targets still use the existing
			# execution-time fallback below, including deaths earlier in the phase.
			if policy_targets and slot.get("target") == "front":
				var target: int = action.get("target_position", 0)
				for position in range(1, target):
					if not party.is_downed(position):
						return failure
		if action.get("type") == "steal_gold":
			if run_gold == null:
				return failure
			# Authenticate the amount against this source's data, never a caller's
			# forged receipt. Validate the whole policy before staging any beat.
			var slot := CombatEnemyIntents._weighted_slot(source, actor.get("intent"))
			var authored := false
			for entry in slot.get("actions", []):
				if entry["action"] == action:
					authored = true
			if not authored:
				return failure
		if actor.has(CombatEnemyIntents.CHARGE_PENDING) and action.has("move"):
			return failure
		if actor.get(CombatEnemyIntents.CHARGE_FLAG, false) == true and actor["hp"] > 0 \
				and not action.has("move"):
			var armed := actor.has(CombatEnemyIntents.CHARGE_PENDING)
			if armed and action.get("type") != "attack":
				return failure
			if action.get("type") == "attack":
				var base := CombatEnemyIntents.charge_attack_amount(actor)
				var step := CombatEnemyKeywordRules.new().project_charge_step(base, armed)
				if not step["ok"] or action.get("amount") != step["damage"]:
					return failure
		seen.append(source)
		ordered.append(raw.duplicate(true))
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.enemy_position < b.enemy_position)
	var staged_party := CombatParty.new(heroes)
	staged_party._heroes = heroes
	var staged_enemies := CombatEnemies.new(roster, enemies.get_capacity())
	# Keep the pre-phase source snapshot distinct from the appendable staged roster.
	staged_enemies._enemies = roster.duplicate(true)
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
		var hit_count: int = effective.get("hits", 1) if effective.type == "attack" else 1
		# Only the real attack choice winds up. The zero-damage preview and
		# subsequent held amount are checked above against the source's own
		# floor-scaled authored attack, not against a UI-only counter.
		# An unarmed charge wind-up is a telegraph/skip, not the next attempted
		# attack; Blind is bypassed and preserved for the armed 2.5x strike.
		if effective.type == "attack" and not effective.has("move") and not staged_enemies.is_slain(source) \
				and staged_enemies._enemies[source - 1].get(CombatEnemyIntents.CHARGE_FLAG, false) == true \
				and not staged_enemies._enemies[source - 1].has(CombatEnemyIntents.CHARGE_PENDING) \
				and not staged_party.is_downed(effective.target_position):
			var base := CombatEnemyIntents.charge_attack_amount(staged_enemies.get_enemy(source))
			var step := CombatEnemyKeywordRules.new().project_charge_step(base, false)
			if not step["ok"] or effective.amount != 0:
				return failure
			staged_enemies._enemies[source - 1][CombatEnemyIntents.CHARGE_PENDING] = {
				"amount": base, "target_position": effective.target_position}
			events.append({"type": "wind_up", "enemy_position": source,
				"target_position": effective.target_position, "damage": 0, "applied": true})
			continue
		# Blind belongs to the entire attempted attack, before mitigation or reactions.
		# All writes remain on the detached roster until every beat succeeds.
		if effective.type == "attack" and not staged_enemies.is_slain(source) \
				and not staged_party.is_downed(effective.target_position) \
				and staged_enemies._enemies[source - 1].get("statuses", {}).get("blind_next_attack", 0) == 1:
			staged_enemies._enemies[source - 1].statuses.erase("blind_next_attack")
			# Blind spends the attempted held strike without releasing it.
			staged_enemies._enemies[source - 1].erase(CombatEnemyIntents.CHARGE_PENDING)
			var miss := {"type": "attack", "enemy_position": source,
				"target_position": effective.target_position, "applied": false}
			if effective.has("move"):
				miss["move"] = effective.move
			if reactions != null:
				miss.merge({"actual_target_position": effective.target_position,
					"redirected": false, "retaliation_damage": 0, "retaliatory_damage": 0})
			events.append(miss)
			continue
		# One cached choice/target, independently resolved hits; no RNG per strike.
		for hit_index in range(hit_count):
			var event := {"type": effective.type, "enemy_position": source, "applied": false}
			if effective.type == "steal_gold":
				event["amount"] = 0
				event["gold"] = staged_gold
			for field in ["target_position", "status", "direction", "move"]:
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
					# A living cloth-eater eats the real recipient's Block before its
					# own bite resolves: the announced target, a Guard redirect and
					# earlier staged swaps all matter here, never a merely previewed
					# or already-skipped beat. Staged only, so a later rejection in
					# this batch publishes none of it.
					if _chews_block(staged_enemies, source) \
							and not _eat_block(staged_party, actual_target):
						return failure
					# The sting's status is judged by the recipient's real HP change,
					# so Block and a Guard redirect decide it, not the announcement.
					var sting: bool = _stings(staged_enemies, source)
					var drains: bool = _drains(staged_enemies, source)
					var hp_before: int = -1
					if sting and actual_target >= 1 and actual_target <= CombatParty.PARTY_SIZE:
						hp_before = staged_party.get_hero(actual_target).get("hp", 0)
					# Drain quotes only this single confirmed hit, so the real
					# recipient's pre-hit record is captured before it is dispatched.
					var recipient_before: Dictionary = staged_party.get_hero(actual_target)
					var pre_hit_living: bool = not staged_party.is_downed(actual_target)
					var hit_target: int = actual_target
					# The source's stored Enrage stacks add their authored bonus ONCE
					# to its own announced amount, before any status adjustment and
					# therefore before Guard/Block handling. The roster's count is only
					# read here: no stack is awarded or rewritten by this beat.
					var enrage_bonus := _enrage_attack_bonus(staged_enemies, source)
					if enrage_bonus < 0 or effective.amount > CombatParty.MAX_INT - enrage_bonus:
						return failure
					var total: int = effective.amount + enrage_bonus
					@warning_ignore("integer_division")
					var announced: int = total / hit_count
					# Preserve every point when a scaled total is odd.
					if hit_index < total % hit_count:
						announced += 1
					var status_rules := CombatStatuses.new()
					var damage := status_rules.adjusted_attack_damage(announced,
						staged_enemies.get_enemy(source).get("statuses", {}),
						staged_party.get_hero(actual_target).get("statuses", {}))
					# Armed Eyelet Guard Thorns is quoted on the PRE-hit living actual
					# recipient, after any Guard redirect and before any HP/Block write,
					# so a hit that downs the bearer still retaliates and a redirected
					# hit on a different hero never does.
					var eyelet_quote: Dictionary = {}
					if eyelet != null:
						eyelet_quote = eyelet.project_contact(staged_party, actual_target, damage)
					var attack: Dictionary = effective.duplicate(true)
					attack.erase("type")
					attack.erase("hits")
					attack.erase("move")
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
						hit_target = reaction_result.actual_target_position
					else:
						var result := CombatEnemyAttacks.new().execute_attacks(staged_party, [attack], staged_enemies.get_capacity())
						if not result.ok:
							return failure
						event.applied = result.events[0].applied
					if hit_target != actual_target:
						return failure
					# Riposte N strikes back against the real enemy source once per
					# confirmed positive-damage hit on the living pre-hit defender
					# (after any Guard redirect), even when hero Block absorbs the
					# whole hit or the hit downs that defender.
					var riposte_damage := status_rules.riposte_damage_for_confirmed_hit(
						recipient_before.get("statuses", {}),
						pre_hit_living and event.applied and damage > 0)
					if riposte_damage > 0 and not staged_enemies.is_slain(source):
						if not staged_enemies.apply_damage(source, riposte_damage):
							return failure
					# Armed Eyelet Guard Thorns retaliates N against the ORIGINAL
					# attacking enemy for each confirmed positive-damage hit on the
					# pre-hit living bearer, even when hero Block absorbed the whole
					# hit. It strikes the detached roster only, so Block, revival and
					# a source already slain by Riposte behave exactly as they do for
					# the Warden's own Thorns and this batch's atomic publication.
					var eyelet_thorns: int = int(eyelet_quote.get("thorns", 0)) \
						if bool(eyelet_quote.get("applied", false)) else 0
					if eyelet_thorns > 0 and pre_hit_living and event.applied and damage > 0 \
							and not staged_enemies.is_slain(source):
						if not staged_enemies.apply_damage(source, eyelet_thorns):
							return failure
					# Drain is the source's own reward for that one confirmed hit: it
					# heals the actor that really lost HP (after Guard and Block), not
					# the announced slot, and a skipped beat or a source slain by
					# Thorns or Riposte in the same resolution can never heal or revive anything.
					if drains and event.applied and not staged_enemies.is_slain(source):
						var receipt := _hit_receipt(recipient_before,
							staged_party.get_hero(hit_target), damage)
						if not receipt.get("ok", false) \
								or not CombatEnemyKeywordRules.new().resolve_drain_after_hit(
									staged_enemies, source, receipt).get("ok", false):
							return failure
					# A slain attacker (Thorns or Riposte retaliation) never lands its
					# sting, and the bonus status must not break the batch's atomicity.
					if sting and not staged_enemies.is_slain(source) \
							and not _sting_bleed(staged_party, actual_target, hp_before):
						return failure
				elif effective.type == "steal_gold":
					var stolen := mini(effective.amount, staged_gold)
					staged_gold -= stolen
					event.applied = true
					event.amount = stolen
					event.gold = staged_gold
				elif effective.type == "summon":
					# Spawn only in this detached batch; the original mother and
					# appended child publish together after every beat succeeds.
					var birth := staged_enemies.stage_broodling(source)
					if not birth.get("ok", false):
						return failure
					event.applied = birth.get("spawned", false)
					if event.applied:
						event["spawn_position"] = birth["position"]
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
					# An earlier beat of this same batch can down the party's last
					# living hero. The fight is already decided then, so a remaining
					# hero-targeted beat has nothing left to change: it stays inert
					# instead of rejecting an authentic lethal/Block-snipping batch
					# and locking the turn. A downed target beside a living ally still
					# fails closed below.
					elif effective.type in ["snip_block", "debuff"] \
							and _party_has_no_living_hero(staged_party):
						event.applied = false
					else:
						var result := CombatEnemySpecialActions.new().execute_actions(
							staged_party, staged_enemies, [effective])
						if not result.ok:
							return failure
						event.applied = result.events[0].applied
			if effective.type == "attack" and staged_enemies._enemies[source - 1].get(
					CombatEnemyIntents.CHARGE_FLAG, false) == true:
				# Success or an inert target consumes the held strike exactly once.
				staged_enemies._enemies[source - 1].erase(CombatEnemyIntents.CHARGE_PENDING)
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
		if staged_enemies._enemies[index].has("statuses"):
			enemies._enemies[index].statuses = staged_enemies._enemies[index].statuses
		# A Thorns kill revived on the staged copy must keep its once-only latch.
		if staged_enemies._enemies[index].has(CombatEnemies.REVIVED_FIELD):
			enemies._enemies[index][CombatEnemies.REVIVED_FIELD] = \
				staged_enemies._enemies[index][CombatEnemies.REVIVED_FIELD]
		if staged_enemies._enemies[index].has(CombatEnemies.BROODLING_LATCH):
			enemies._enemies[index][CombatEnemies.BROODLING_LATCH] = \
				staged_enemies._enemies[index][CombatEnemies.BROODLING_LATCH]
		# Publish the single actor-owned charge latch only with the complete
		# successful phase. A rejected later beat leaves its old value intact.
		if staged_enemies._enemies[index].has(CombatEnemyIntents.CHARGE_PENDING):
			enemies._enemies[index][CombatEnemyIntents.CHARGE_PENDING] = \
				staged_enemies._enemies[index][CombatEnemyIntents.CHARGE_PENDING].duplicate(true)
		else:
			enemies._enemies[index].erase(CombatEnemyIntents.CHARGE_PENDING)
	# Only a successfully staged birth may extend the real battle roster.
	for index in range(roster.size(), staged_enemies._enemies.size()):
		enemies._enemies.append(staged_enemies._enemies[index].duplicate(true))
	var receipt := {"ok": true, "events": events}
	if run_gold != null:
		receipt["gold"] = staged_gold
	return receipt


## True only for a roster record that authors the boolean bleeding sting.
static func _stings(enemies: CombatEnemies, source: int) -> bool:
	if enemies == null or not enemies.is_valid():
		return false
	var value: Variant = enemies.get_enemy(source).get(BLEED_ON_ATTACK_FIELD, false)
	return value is bool and value == true


## True only for a roster record that authors boolean Drain.
static func _drains(enemies: CombatEnemies, source: int) -> bool:
	if enemies == null or not enemies.is_valid():
		return false
	var value: Variant = enemies.get_enemy(source).get(DRAIN_FIELD, false)
	return value is bool and value == true


## True only for a roster record that authors the boolean cloth-eating bite.
static func _chews_block(enemies: CombatEnemies, source: int) -> bool:
	if enemies == null or not enemies.is_valid():
		return false
	var value: Variant = enemies.get_enemy(source).get(CHEW_BLOCK_ON_ATTACK_FIELD, false)
	return value is bool and value == true


## The stored Enrage attack bonus of one roster source, using the accepted
## keyword constants (2 damage per stack, at most 3 stacks). Only a source that
## authors `enrage: true` gains anything; an absent or explicit-false flag gains
## nothing even with leftover stacks, and an absent count means zero stacks.
## Returns -1 for malformed metadata so the caller fails closed instead of
## inventing damage. Read-only: no stack is awarded and no RNG is used.
static func _enrage_attack_bonus(enemies: CombatEnemies, source: int) -> int:
	if enemies == null or not enemies.is_valid():
		return 0
	var enemy: Dictionary = enemies.get_enemy(source)
	if enemy.is_empty():
		return 0
	var flag: Variant = enemy.get(ENRAGE_FIELD, false)
	if not flag is bool:
		return -1
	if not flag:
		return 0
	var stacks: Variant = enemy.get(ENRAGE_STACKS_FIELD, 0)
	if not stacks is int or stacks < 0 or stacks > CombatEnemyKeywordRules.ENRAGE_MAX_STACKS:
		return -1
	return stacks * CombatEnemyKeywordRules.ENRAGE_ATTACK_BONUS_PER_STACK


## The optional authored flags are content, never numbers or truthy strings:
## one malformed record fails the whole phase before any beat is staged.
static func _attack_metadata_valid(roster: Array) -> bool:
	for enemy in roster:
		if not enemy is Dictionary:
			return false
		if not CombatEnemyIntents.valid_charge_actor(enemy):
			return false
		if enemy.has(BLEED_ON_ATTACK_FIELD) \
				and not (enemy[BLEED_ON_ATTACK_FIELD] is bool):
			return false
		if enemy.has(DRAIN_FIELD) and not (enemy[DRAIN_FIELD] is bool):
			return false
		if enemy.has(CHEW_BLOCK_ON_ATTACK_FIELD) \
				and not (enemy[CHEW_BLOCK_ON_ATTACK_FIELD] is bool):
			return false
		if enemy.has(CombatEnemies.BROODLING_LATCH) \
				and not (enemy[CombatEnemies.BROODLING_LATCH] is bool):
			return false
		if enemy.has(ENRAGE_FIELD) and not (enemy[ENRAGE_FIELD] is bool):
			return false
		if enemy.has(ENRAGE_STACKS_FIELD):
			var stacks: Variant = enemy[ENRAGE_STACKS_FIELD]
			if not stacks is int or stacks < 0 \
					or stacks > CombatEnemyKeywordRules.ENRAGE_MAX_STACKS:
				return false
	return true


## True only once every staged hero is already down: nothing a later beat does
## can matter, because that same batch has just lost the fight.
static func _party_has_no_living_hero(staged_party: CombatParty) -> bool:
	if staged_party == null or not staged_party.is_valid():
		return false
	for index in range(CombatParty.PARTY_SIZE):
		if not staged_party.is_downed(index + 1):
			return false
	return true


## Strip every point of one staged recipient's Block for a living opted-in
## attacker's real attack. A downed recipient simply keeps the beat inert; a
## stale or malformed counter fails the batch closed instead of guessing.
static func _eat_block(staged_party: CombatParty, position: int) -> bool:
	if staged_party == null or not staged_party.is_valid():
		return false
	if position < 1 or position > CombatParty.PARTY_SIZE:
		return false
	var hero: Dictionary = staged_party._heroes[position - 1]
	var hp: Variant = hero.get("hp")
	if not hp is int:
		return false
	if hp <= 0:
		return true
	var block: Variant = hero.get("block", 0)
	if not block is int or block < 0:
		return false
	hero["block"] = 0
	return true


## Detached CombatStatusAttacks.resolve_vs_hero-shaped receipt for the single hit
## the phase just dispatched, read from the real recipient's own before/after
## records. A stale or inverted reading fails closed instead of inventing damage.
static func _hit_receipt(before: Dictionary, after: Dictionary, damage: int) -> Dictionary:
	var failure := {"ok": false, "damage": 0, "block_absorbed": 0, "hp_loss": 0}
	if before.is_empty() or after.is_empty() or damage < 0:
		return failure
	var before_hp: Variant = before.get("hp")
	var before_block: Variant = before.get("block")
	var after_hp: Variant = after.get("hp")
	var after_block: Variant = after.get("block")
	if not before_hp is int or not before_block is int \
			or not after_hp is int or not after_block is int:
		return failure
	var block_absorbed: int = before_block - after_block
	var hp_loss: int = before_hp - after_hp
	if block_absorbed < 0 or hp_loss < 0:
		return failure
	return {"ok": true, "damage": damage, "block_absorbed": block_absorbed, "hp_loss": hp_loss}


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
