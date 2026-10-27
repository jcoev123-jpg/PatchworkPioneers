class_name CombatStatusAttacks
extends RefCounted
## Scene-free bridge: supplied actor-local statuses modify one attack, then the
## authoritative roster absorbs that damage with Block before HP. No status aging.
##
## The canonical one-shot defense tokens are role-aware here and never modify the
## hit: an ATTACKER may carry Dodge (`dodge_next_attack`, integer 0 inert or 1
## active), which protects it from an incoming attack, and a DEFENDER may already
## be Blind (`blind_next_attack`, integer 0 or 1), which makes that enemy's OWN
## next attack miss. Both are admitted untouched, so a hero who is Dodging can
## still make a legal attack against an enemy that is already Blinded. The
## opposite roles (attacker Blind, defender Dodge) stay refused here: the separate
## miss/evasion attempt path owns those and must never be skipped silently.

## The status keys whose counters modify one attack.
const ATTACK_STATUS_KEYS: Array[String] = ["bleed", "weak", "exposed", "tangled", "riposte"]
const DODGE_STATUS_KEY := "dodge_next_attack"
const BLIND_STATUS_KEY := "blind_next_attack"

var _statuses := CombatStatuses.new()


func resolve_vs_enemy(enemies: CombatEnemies, target_position: int, base_damage: int,
		attacker_statuses: Dictionary, defender_statuses: Dictionary) -> Dictionary:
	if enemies == null or not enemies.is_valid() or base_damage < 0 \
			or not _valid_attacker_statuses(attacker_statuses) \
			or not _valid_defender_statuses(defender_statuses):
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
			or not _valid_attacker_statuses(attacker_statuses) \
			or not _valid_defender_statuses(defender_statuses):
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


## The plain damage-status vocabulary, with no one-shot token admitted. Kept for
## the read-only callers that preflight an actor's own damage modifiers.
func _valid_statuses(statuses: Dictionary) -> bool:
	return _valid_role_statuses(statuses, "")


## An attacking actor may carry the canonical Dodge token (0|1). It protects its
## bearer from an incoming attack and adds nothing to this outgoing hit.
func _valid_attacker_statuses(statuses: Dictionary) -> bool:
	if statuses.has(BLIND_STATUS_KEY):
		return false
	return _valid_role_statuses(statuses, DODGE_STATUS_KEY)


## A defending actor may already be carrying the canonical Blind token (0|1). It
## makes that enemy's own next attack miss and adds no incoming vulnerability.
func _valid_defender_statuses(statuses: Dictionary) -> bool:
	if statuses.has(DODGE_STATUS_KEY):
		return false
	return _valid_role_statuses(statuses, BLIND_STATUS_KEY)


## Validate explicitly: adjusted_attack_damage() also returns zero for a
## malformed map, which is indistinguishable from valid zero-damage attacks.
## Damage counters stay nonnegative ints, and at most the one named role token is
## admitted as exactly the int 0 or 1 (never bool, string, duration or stack).
func _valid_role_statuses(statuses: Dictionary, token_key: String) -> bool:
	for name in statuses:
		if not name is String:
			return false
		if token_key != "" and name == token_key:
			var token = statuses[name]
			if not token is int or (token != 0 and token != 1):
				return false
			continue
		if name not in ATTACK_STATUS_KEYS:
			return false
		var count = statuses[name]
		if not count is int or count < 0:
			return false
	return true


func _failure() -> Dictionary:
	return {"ok": false, "damage": 0, "block_absorbed": 0, "hp_loss": 0}
