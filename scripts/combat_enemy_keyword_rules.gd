class_name CombatEnemyKeywordRules
extends RefCounted
## Scene-free enemy keyword rules for Thorns N ("attacker takes N per hit") and
## Enrage ("gain +2 attack when hit, max 3 stacks"), plus Drain ("heal for damage
## dealt").
## Thorns is an opt-in service: the battle caller invokes it once per CONFIRMED
## positive-damage hit, passing the defender's PRE-HIT record and the authentic
## CombatStatusAttacks.resolve_vs_enemy receipt for that hit. It never runs for
## previews, intents, misses or failed/zero-damage attacks, and never aggregates
## hits from one card. Retaliation goes through CombatParty.apply_damage, so hero
## Block absorbs it before HP. Inputs are never mutated and no RNG is used.
## N comes from content; this class assigns no production value.
## Enrage is a pure quote: it reports the stacks and additive attack bonus after
## one confirmed hit without touching the roster or any live attack intent.
## Drain is an opt-in service: the battle caller invokes it once per CONFIRMED
## enemy hit, passing the authentic CombatStatusAttacks.resolve_vs_hero receipt
## for that hit. It heals only the hero HP loss of that hit, so Block-absorbed
## damage never heals, and it is clamped to the source's missing HP. Nothing in
## the live enemy phase calls it yet; that hookup is a separate task.

## Enrage caps at three stacks; each stack adds +2 attack (0, +2, +4, +6).
const ENRAGE_MAX_STACKS := 3
const ENRAGE_ATTACK_BONUS_PER_STACK := 2

## Retaliate for one confirmed hit.
## party: the authoritative CombatParty that owns the attacking hero.
## attacker_position: 1-3; the hero must be living.
## pre_hit_enemy: CombatEnemies.get_enemy snapshot taken BEFORE the hit.
## receipt: the successful CombatStatusAttacks.resolve_vs_enemy result
##   {ok, damage, block_absorbed, hp_loss}.
## Returns a detached receipt {ok, applied, thorns, block_absorbed, hp_loss}.
## Malformed party/position/enemy/receipt and invalid Thorns N fail closed to ok=false.
## Absent or zero Thorns, or a confirmed zero-damage hit, return ok=true with applied=false.
func resolve_thorns_retaliation(party: CombatParty, attacker_position: int,
		pre_hit_enemy: Dictionary, receipt: Dictionary) -> Dictionary:
	if party == null or not party.is_valid():
		return _failure()
	if party.get_hero(attacker_position).is_empty() or party.is_downed(attacker_position):
		return _failure()
	if not _valid_enemy_record(pre_hit_enemy) or not _valid_receipt(receipt):
		return _failure()
	if not receipt["ok"]:
		return _failure()
	var thorns: int = pre_hit_enemy.get("thorns", 0)
	if receipt["damage"] <= 0 or thorns == 0:
		return _no_retaliation(thorns)
	var before: Dictionary = party.get_hero(attacker_position)
	if not party.apply_damage(attacker_position, thorns):
		return _failure()
	var after: Dictionary = party.get_hero(attacker_position)
	return {"ok": true, "applied": true, "thorns": thorns,
		"block_absorbed": before["block"] - after["block"],
		"hp_loss": before["hp"] - after["hp"]}


## Quote the Enrage stacks after ONE confirmed hit, without mutating anything.
## pre_hit_enemy: living pre-hit CombatEnemies.get_enemy snapshot; Enrage metadata
##   is `enrage: true` plus an optional integer `enrage_stacks` in 0..3 (missing
##   count means zero). A full snapshot (positive int hp) is required.
## receipt: the authentic CombatStatusAttacks.resolve_vs_enemy result
##   {ok, damage, block_absorbed, hp_loss}.
## Returns a detached quote {ok, applied, enrage_stacks, attack_bonus} with
## attack_bonus = enrage_stacks * 2. Confirmed hit = ok and positive damage,
## including a blow fully absorbed by Block; that awards one stack, capped at 3.
## A non-Enrage enemy, a zero-damage hit or an already capped enemy returns
## ok=true, applied=false and the unchanged stacks/bonus. Malformed metadata or
## receipt fail closed to ok=false. Each call quotes its own hit only: feed the
## returned `enrage_stacks` into the next call to quote a genuine multi-hit chain.
func quote_enrage_after_hit(pre_hit_enemy: Dictionary, receipt: Dictionary) -> Dictionary:
	if not _valid_enrage_enemy(pre_hit_enemy) or not _valid_receipt(receipt):
		return _enrage_failure()
	if not receipt["ok"]:
		return _enrage_failure()
	if not pre_hit_enemy.get("enrage", false):
		return _enrage_no_op(0)
	var stacks: int = pre_hit_enemy.get("enrage_stacks", 0)
	if receipt["damage"] <= 0 or stacks >= ENRAGE_MAX_STACKS:
		return _enrage_no_op(stacks)
	return _enrage_applied(stacks + 1)


## Heal the attacking enemy after ONE confirmed hit.
## enemies: the authoritative CombatEnemies roster that owns the source.
## source_position: 1-3; the source must be a living slot of that roster carrying
##   boolean `drain: true` metadata. `drain: false` or an absent key is a valid
##   non-Drain source; a non-boolean flag, a missing/impossible max_hp or hp, or a
##   slain slot is invalid.
## attack_receipt: the authentic CombatStatusAttacks.resolve_vs_hero result
##   {ok, damage, block_absorbed, hp_loss} for that same hit.
## Returns a detached receipt {ok, applied, healed}. Drain N is not a separate
## multiplier: it restores min(receipt.hp_loss, max_hp - hp) HP through
## CombatEnemies.heal, so Block-absorbed damage never heals, nothing overheals and
## a slain enemy is never revived. A valid non-Drain source, or a confirmed hit
## with zero HP loss, returns an inert success (ok=true, applied=false, healed=0).
## Missing/invalid roster, source or metadata, and failed/malformed receipts fail
## closed to ok=false without mutating either side. Inputs are never mutated and
## no RNG is used.
func resolve_drain_after_hit(enemies: CombatEnemies, source_position: int,
		attack_receipt: Dictionary) -> Dictionary:
	if enemies == null or not enemies.is_valid():
		return _drain_failure()
	var source: Dictionary = enemies.get_enemy(source_position)
	if not _valid_drain_source(source) or not _valid_receipt(attack_receipt):
		return _drain_failure()
	if not attack_receipt["ok"]:
		return _drain_failure()
	if not source.get("drain", false):
		return _drain_inert()
	if attack_receipt["hp_loss"] <= 0:
		return _drain_inert()
	var missing_hp: int = source["max_hp"] - source["hp"]
	var amount: int = mini(attack_receipt["hp_loss"], missing_hp)
	if amount <= 0:
		return _drain_inert()
	if not enemies.heal(source_position, amount):
		return _drain_failure()
	return {"ok": true, "applied": true, "healed": amount}


## A full snapshot of a living slot with valid, explicitly boolean Drain metadata.
func _valid_drain_source(source: Dictionary) -> bool:
	if not _valid_enemy_record(source):
		return false
	var hp: Variant = source.get("hp")
	var max_hp: Variant = source.get("max_hp")
	if not hp is int or not max_hp is int:
		return false
	if hp <= 0 or max_hp <= 0 or hp > max_hp:
		return false
	if source.has("drain") and not source["drain"] is bool:
		return false
	return true


func _drain_inert() -> Dictionary:
	return {"ok": true, "applied": false, "healed": 0}


func _drain_failure() -> Dictionary:
	return {"ok": false, "applied": false, "healed": 0}


## Shared with Thorns, so keep every currently accepted record valid here too.
## The Enrage quote additionally requires a full snapshot of a living enemy.
func _valid_enrage_enemy(enemy: Dictionary) -> bool:
	if not _valid_enemy_record(enemy):
		return false
	var hp: Variant = enemy.get("hp")
	if not hp is int or hp <= 0:
		return false
	if enemy.has("enrage") and not enemy["enrage"] is bool:
		return false
	if enemy.has("enrage_stacks"):
		var stacks: Variant = enemy["enrage_stacks"]
		if not stacks is int or stacks < 0 or stacks > ENRAGE_MAX_STACKS:
			return false
	return true


func _enrage_applied(stacks: int) -> Dictionary:
	return {"ok": true, "applied": true, "enrage_stacks": stacks,
		"attack_bonus": stacks * ENRAGE_ATTACK_BONUS_PER_STACK}


func _enrage_no_op(stacks: int) -> Dictionary:
	return {"ok": true, "applied": false, "enrage_stacks": stacks,
		"attack_bonus": stacks * ENRAGE_ATTACK_BONUS_PER_STACK}


func _enrage_failure() -> Dictionary:
	return {"ok": false, "applied": false, "enrage_stacks": 0, "attack_bonus": 0}


func _valid_enemy_record(enemy: Dictionary) -> bool:
	if enemy.is_empty():
		return false
	if enemy.has("hp") and (not enemy["hp"] is int or enemy["hp"] < 0):
		return false
	if enemy.has("block") and (not enemy["block"] is int or enemy["block"] < 0):
		return false
	if enemy.has("thorns"):
		var thorns = enemy["thorns"]
		if not thorns is int or thorns < 0:
			return false
	return true


func _valid_receipt(receipt: Dictionary) -> bool:
	for key in ["ok", "damage", "block_absorbed", "hp_loss"]:
		if not receipt.has(key):
			return false
	if not receipt["ok"] is bool:
		return false
	for key in ["damage", "block_absorbed", "hp_loss"]:
		if not receipt[key] is int or receipt[key] < 0:
			return false
	return true


func _no_retaliation(thorns: int) -> Dictionary:
	return {"ok": true, "applied": false, "thorns": thorns,
		"block_absorbed": 0, "hp_loss": 0}


func _failure() -> Dictionary:
	return {"ok": false, "applied": false, "thorns": 0,
		"block_absorbed": 0, "hp_loss": 0}
