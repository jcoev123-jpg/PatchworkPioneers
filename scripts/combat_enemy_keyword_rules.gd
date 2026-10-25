class_name CombatEnemyKeywordRules
extends RefCounted
## Scene-free enemy keyword rules; currently only Thorns N ("attacker takes N per hit").
## Thorns is an opt-in service: the battle caller invokes it once per CONFIRMED
## positive-damage hit, passing the defender's PRE-HIT record and the authentic
## CombatStatusAttacks.resolve_vs_enemy receipt for that hit. It never runs for
## previews, intents, misses or failed/zero-damage attacks, and never aggregates
## hits from one card. Retaliation goes through CombatParty.apply_damage, so hero
## Block absorbs it before HP. Inputs are never mutated and no RNG is used.
## N comes from content; this class assigns no production value.

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
