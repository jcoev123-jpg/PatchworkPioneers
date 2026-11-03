class_name CombatYarnRangerUnspoolCards
extends RefCounted
## Scene-free paid resolver for Yarn Ranger's Unspool (damage 7) and Unspool+
## (damage 10). Only hits living enemies with an authoritative Tangled counter.
## Status admission is role-aware, exactly as CombatStatusAttacks.resolve_vs_enemy:
## a Dodging/Feared attacker and a Blind/Feared defender are legal and untouched.
## Each confirmed hit also triggers the defender's Thorns retaliation against the
## Ranger and its Enrage stack gain through CombatEnemyKeywordRules.
## No status mutation, no RNG use, no scene dependency.

const CARD_IDS := [
	"yarn_ranger_unspool",
	"yarn_ranger_unspool_plus"
]

var _catalog := preload("res://data/cards/yarn_ranger_pool_cards.gd").new()
var _attacks := CombatStatusAttacks.new()
var _keywords := CombatEnemyKeywordRules.new()


func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String) -> Dictionary:
	# Fail-closed: every preflight must pass before any mutation.
	if deck == null or party == null or enemies == null:
		return {"ok": false}
	if not CARD_IDS.has(card_id):
		return {"ok": false}

	# Catalog authentication (immutable descriptors only).
	var definition: Dictionary = _catalog.get_definition(card_id)
	if definition.is_empty() or definition.get("id") != card_id:
		return {"ok": false}
	if definition.get("owner") != "yarn_ranger":
		return {"ok": false}
	if definition.get("cost") != 2:
		return {"ok": false}
	if definition.get("from_positions") != [2, 3]:
		return {"ok": false}
	if definition.get("to_positions") != [1, 2, 3]:
		return {"ok": false}
	if definition.get("target_kind") != "enemy_all":
		return {"ok": false}
	var effects: Dictionary = definition.get("effects", {})
	if effects.get("requires_target_status") != "tangled" \
			or effects.get("living_targets_only") != true:
		return {"ok": false}

	# Active turn and genuine hand copy.
	if deck == null or not deck.turn_active:
		return {"ok": false}
	if not deck.hand.has(card_id):
		return {"ok": false}

	# Energy budget.
	if deck.energy < 2:
		return {"ok": false}

	# Party: exactly one living Yarn Ranger at position 2 or 3.
	if not party.is_valid():
		return {"ok": false}
	var heroes: Array[Dictionary] = party.get_heroes()
	var yr_positions: Array[int] = []
	var yr_statuses: Dictionary = {}
	for hero in heroes:
		if hero.get("id") == "yarn_ranger" and not hero.get("id").is_empty():
			var pos := int(hero.get("position", 0))
			if pos == 2 or pos == 3:
				if not party.is_downed(pos):
					yr_positions.append(pos)
				# Read real status snapshot from the hero record, failing closed on
				# malformed data instead of letting a typed assignment abort.
				var hero_statuses: Variant = hero.get("statuses", {})
				if not hero_statuses is Dictionary:
					return {"ok": false}
				yr_statuses = hero_statuses
	if yr_positions.size() != 1:
		return {"ok": false}
	var owner_position: int = yr_positions[0]

	# Enemy roster must be valid and a genuine model-configured roster: the
	# ordinary three-slot default or the explicit four-slot battle opt-in. An
	# unused capacity slot is never a target, so eligibility below enumerates
	# the actual occupied records rather than any fixed slot list.
	if enemies == null or not _valid_roster(enemies):
		return {"ok": false}

	# Identify eligible targets by walking the authoritative records in their
	# original slot order. The printed TO metadata stays [1, 2, 3] because
	# enemy_all means the real living roster: every occupied slot that is alive
	# and authentically Tangled > 0 is a target, including a summoned, split or
	# otherwise opted-in fourth foe. Untangled, slain and unused slots are never
	# targets, and no position is ever compacted.
	var eligible: Array[int] = []
	var roster: Array[Dictionary] = enemies.get_enemies()
	for index in range(roster.size()):
		var pos := index + 1
		var enemy_dict: Dictionary = roster[index]
		if int(enemy_dict.get("position", 0)) != pos:
			return {"ok": false}
		if enemies.is_slain(pos):
			continue
		var raw_statuses: Variant = _read_statuses(enemy_dict)
		if not raw_statuses is Dictionary:
			return {"ok": false}
		var statuses: Dictionary = raw_statuses
		var tangled_val: Variant = statuses.get("tangled", 0)
		if tangled_val is int and tangled_val > 0:
			eligible.append(pos)

	# No eligible target -> reject before any spend or change.
	if eligible.is_empty():
		return {"ok": false}

	# Preflight status validation: exactly the role-aware policy that the paid
	# hit itself uses (CombatStatusAttacks.resolve_vs_enemy). The attacking Yarn
	# Ranger may carry Dodge and Fear; a defending enemy may already carry Blind
	# and Fear. Both are admitted untouched, so a Blinded or Feared foe is still a
	# legal Tangled target and a Dodging owner can still attack. The opposite
	# role tokens and every malformed value are still refused before any spend.
	if not _valid_attacker_statuses(yr_statuses):
		return {"ok": false}
	for pos in eligible:
		var enemy_pre: Dictionary = enemies.get_enemy(pos)
		var defender_raw: Variant = _read_statuses(enemy_pre)
		if not defender_raw is Dictionary:
			return {"ok": false}
		var defender_statuses: Dictionary = defender_raw
		if not _valid_defender_statuses(defender_statuses):
			return {"ok": false}
		# Thorns/Enrage metadata and arithmetic of every proposed hit actor, so a
		# malformed keyword can never leave a paid, partially applied cast.
		if not _valid_keyword_metadata(enemy_pre):
			return {"ok": false}

	# Determine base damage from the printed descriptor.
	var base_damage: int = int(effects.get("damage", 0))

	# Charge and discard: exactly once after preflight succeeds.
	if not deck.try_spend_energy(2):
		return {"ok": false}
	if not deck.discard_played(card_id):
		# Should not fail after preflight; fail closed regardless.
		return {"ok": false}

	# Resolve each eligible target independently in original slot order.
	# Read real defender statuses directly from the authoritative roster.
	var hits: Array[Dictionary] = []
	# Detached PRE-HIT records and the authentic bridge receipt of each hit.
	var pre_hits: Dictionary = {}
	var receipts: Dictionary = {}
	for pos in eligible:
		var defender_dict: Dictionary = enemies.get_enemy(pos)
		pre_hits[pos] = defender_dict.duplicate(true)
		var defender_raw: Variant = _read_statuses(defender_dict)
		# Re-read attacker statuses from the real party hero.
		var hero_dict: Dictionary = party.get_hero(owner_position)
		var attacker_raw: Variant = _read_statuses(hero_dict)
		if not defender_raw is Dictionary or not attacker_raw is Dictionary:
			return {"ok": false, "hits": []}
		var defender_statuses: Dictionary = defender_raw
		var attacker_statuses: Dictionary = attacker_raw

		var event: Dictionary = _attacks.resolve_vs_enemy(
			enemies, pos, base_damage,
			attacker_statuses, defender_statuses)
		if not event.get("ok", false):
			# A validated target should never fail here, but fail closed.
			return {"ok": false, "hits": []}
		receipts[pos] = event
		hits.append({
			"position": pos,
			"damage": event.get("damage", 0),
			"block_absorbed": event.get("block_absorbed", 0),
			"hp_loss": event.get("hp_loss", 0)
		})

	# Keyword consequences of each confirmed hit, in original slot order, after
	# the whole paid area has landed (the starter area pattern). An earlier Thorns
	# that downs the Ranger never cancels a hit or the payment; later Thorns simply
	# cannot retaliate from a downed attacker.
	for pos in eligible:
		_keywords.commit_enrage_after_hit(enemies, pos, pre_hits[pos], receipts[pos])
		_keywords.resolve_thorns_retaliation(party, owner_position, pre_hits[pos],
			receipts[pos])

	return {"ok": true, "hits": hits}


## One to the roster's genuine capacity of occupied enemy slots in original
## order. Only the model's own default three or explicit four-slot battle opt-in
## is admitted, so a tampered capacity is refused and a fourth foe is never
## admitted silently. A roster may fill only part of its capacity (a fourth foe
## joins later) and a default-capacity four-definition construction is inert.
## Structural validity only: target eligibility and keyword metadata are checked
## separately for the actual hit actors.
func _valid_roster(enemies: CombatEnemies) -> bool:
	if enemies == null or not enemies.is_valid():
		return false
	var capacity: int = enemies.get_capacity()
	if capacity != CombatEnemies.MAX_ENEMIES \
			and capacity != CombatEnemies.OPT_IN_MAX_ENEMIES:
		return false
	var roster: Array[Dictionary] = enemies.get_enemies()
	if roster.is_empty() or roster.size() > capacity:
		return false
	var seen: Dictionary = {}
	for index in range(roster.size()):
		var record: Dictionary = roster[index]
		var enemy_id: Variant = record.get("id")
		if not enemy_id is String or (enemy_id as String).is_empty() \
				or seen.has(enemy_id):
			return false
		seen[enemy_id] = true
		var position: Variant = record.get("position")
		if not position is int or position != index + 1:
			return false
		var max_hp: Variant = record.get("max_hp")
		if not max_hp is int or max_hp <= 0:
			return false
		var hp: Variant = record.get("hp")
		if not hp is int or hp < 0 or hp > max_hp:
			return false
		var block: Variant = record.get("block")
		if not block is int or block < 0:
			return false
		if not record.get("statuses", {}) is Dictionary:
			return false
	return true


## Fail-closed keyword metadata check for one living eligible enemy snapshot:
## Thorns is a nonnegative int, Enrage a bool and its stacks an int in 0..3.
## Absent keys mean a plain unkeyed foe, which stays valid.
func _valid_keyword_metadata(enemy: Dictionary) -> bool:
	var hp: Variant = enemy.get("hp")
	if not hp is int or hp <= 0:
		return false
	var block: Variant = enemy.get("block", 0)
	if not block is int or block < 0:
		return false
	var thorns: Variant = enemy.get("thorns", 0)
	if not thorns is int or thorns < 0:
		return false
	var enrage: Variant = enemy.get("enrage", false)
	if not enrage is bool:
		return false
	var stacks: Variant = enemy.get("enrage_stacks", 0)
	if not stacks is int or stacks < 0 or stacks > CombatEnemyKeywordRules.ENRAGE_MAX_STACKS:
		return false
	return true


## Absent statuses mean "no counters". A present non-Dictionary value is
## malformed and must be rejected, never coerced into {}.
func _read_statuses(actor: Dictionary) -> Variant:
	if not actor.has("statuses"):
		return {}
	return actor.get("statuses")


## The role-neutral damage-status vocabulary, delegated to the shared attack
## bridge. Retained for read-only callers; the paid play below always uses the
## role-aware attacker/defender policy, never this looser union.
func _valid_statuses(statuses: Dictionary) -> bool:
	return _attacks._valid_statuses(statuses)


## An attacking hero may carry the canonical Dodge token (`dodge_next_attack`
## integer 0 or 1) and Fear (`cannot_buff_next_turn: true`). Both are inert for
## this outgoing hit and are never consumed here; a hero-side Blind stays refused.
func _valid_attacker_statuses(statuses: Dictionary) -> bool:
	return _attacks._valid_attacker_statuses(statuses)


## A defending enemy may already carry the canonical Blind token
## (`blind_next_attack` integer 0 or 1) and Fear. Neither protects it from this
## incoming hit; an enemy-side Dodge stays refused.
func _valid_defender_statuses(statuses: Dictionary) -> bool:
	return _attacks._valid_defender_statuses(statuses)
