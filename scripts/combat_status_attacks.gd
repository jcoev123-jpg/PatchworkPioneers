class_name CombatStatusAttacks
extends RefCounted
## Scene-free bridge: supplied actor-local statuses modify one attack, then the
## authoritative roster absorbs that damage with Block before HP. No status aging.

var _statuses := CombatStatuses.new()


func resolve_vs_enemy(enemies: CombatEnemies, target_position: int, base_damage: int,
		attacker_statuses: Dictionary, defender_statuses: Dictionary) -> Dictionary:
	if enemies == null or not enemies.is_valid() or base_damage < 0 \
			or not _valid_statuses(attacker_statuses) or not _valid_statuses(defender_statuses):
		return _failure()
	var before: Dictionary = enemies.get_enemy(target_position)
	if before.is_empty() or enemies.is_slain(target_position):
		return _failure()
	var damage: int = _statuses.adjusted_attack_damage(base_damage, attacker_statuses, defender_statuses)
	if not enemies.apply_damage(target_position, damage):
		return _failure()
	var after: Dictionary = enemies.get_enemy(target_position)
	return {"ok": true, "damage": damage, "block_absorbed": before["block"] - after["block"],
		"hp_loss": before["hp"] - after["hp"]}


func resolve_vs_hero(party: CombatParty, target_position: int, base_damage: int,
		attacker_statuses: Dictionary, defender_statuses: Dictionary) -> Dictionary:
	if party == null or not party.is_valid() or base_damage < 0 \
			or not _valid_statuses(attacker_statuses) or not _valid_statuses(defender_statuses):
		return _failure()
	var before: Dictionary = party.get_hero(target_position)
	if before.is_empty() or party.is_downed(target_position):
		return _failure()
	var damage: int = _statuses.adjusted_attack_damage(base_damage, attacker_statuses, defender_statuses)
	if not party.apply_damage(target_position, damage):
		return _failure()
	var after: Dictionary = party.get_hero(target_position)
	return {"ok": true, "damage": damage, "block_absorbed": before["block"] - after["block"],
		"hp_loss": before["hp"] - after["hp"]}


func _valid_statuses(statuses: Dictionary) -> bool:
	# Validate explicitly: adjusted_attack_damage() also returns zero for a
	# malformed map, which is indistinguishable from valid zero-damage attacks.
	for name in statuses:
		if not name is String or name not in ["bleed", "weak", "exposed"]:
			return false
		var count = statuses[name]
		if not count is int or count < 0:
			return false
	return true


func _failure() -> Dictionary:
	return {"ok": false, "damage": 0, "block_absorbed": 0, "hp_loss": 0}
