class_name CombatAttackCards
extends RefCounted
## Scene-free, single authoritative charge/discard for authored starter attacks.
## Damage uses caller-owned snapshots; confirmed hits persist on the enemy roster.

const ATTACK_IDS := [
	"warden_strike", "warden_shield_bash", "seamstress_prick",
	"tinker_pop_shot", "tinker_scrap_bomb"
]

var _targeting := CombatAttackTargeting.new()
var _damage := CombatStatusAttacks.new()
var _on_hit := CombatOnHitStatuses.new()
var _tinker := CombatTinkerFirstAttack.new()
var _basic := CombatBasicAttacks.new()
var _statuses := CombatStatuses.new()


## The live turn coordinator must call this once per new player turn.
## No deck, roster, or status state is changed by the reset.
func start_player_turn() -> void:
	_tinker.start_player_turn()


## Rejects every invalid selection, recipient and status snapshot before mutating
## any real combat state. Target positions are original roster slots, never indices
## compacted after deaths. Supplied status snapshots are never mutated.
func play_attack(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int = 0, attacker_statuses: Dictionary = {},
		enemy_statuses_by_position: Dictionary = {}) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _failure()
	if not ATTACK_IDS.has(card_id) or enemies.is_victorious():
		return _failure()

	var definition: Dictionary = StarterCards.new().get_definition(card_id)
	if definition.get("id") != card_id or not definition.get("effects") is Dictionary:
		return _failure()
	var damage_value: Variant = definition["effects"].get("damage")
	var cost_value: Variant = definition.get("cost")
	if not damage_value is int or damage_value < 0 or not cost_value is int or cost_value < 0:
		return _failure()

	# Preview owns hand/energy/owner-position and alive-target legality. Recheck
	# the chosen target below, as previews do not commit a selection.
	var preview := _targeting.get_preview(deck, party, enemies, card_id)
	if not preview.get("playable", false):
		return _failure()
	var positions: Array[int] = preview["target_positions"]
	if preview["requires_selection"]:
		if not positions.has(target_position):
			return _failure()
		positions = [target_position]
	elif target_position != 0:
		# Enemy-all is deliberately target-free, even when there is one enemy.
		return _failure()

	# Validate ALL supplied status entries, including late or unselected slots,
	# before damage/energy/discard or first-attack bonus can change.
	if not _valid_statuses(attacker_statuses):
		return _failure()
	for position in enemy_statuses_by_position:
		if not position is int or position < 1 or position > CombatEnemies.MAX_ENEMIES:
			return _failure()
		if enemies.get_enemy(position).is_empty():
			return _failure()
		var statuses: Variant = enemy_statuses_by_position[position]
		if not statuses is Dictionary or not _valid_statuses(statuses):
			return _failure()

	# Verify the entire batch before the first mutation (including late targets).
	for position in positions:
		var enemy := enemies.get_enemy(position)
		if enemy.is_empty() or enemy.get("position") != position or enemies.is_slain(position):
			return _failure()
		if not enemy.get("hp") is int or not enemy.get("block") is int:
			return _failure()
		if enemy["hp"] <= 0 or enemy["block"] < 0:
			return _failure()

	var applications := {}
	for position in positions:
		applications[position] = _on_hit.status_for_confirmed_hit(card_id, true)
	if not enemies.can_apply_statuses(applications):
		return _failure()
	var bonus := _tinker.bonus_for_attack(card_id)
	var attack_damage: int = damage_value + bonus
	if card_id in CombatBasicAttacks.SUPPORTED_CARD_IDS:
		var final_damage := _statuses.adjusted_attack_damage(attack_damage,
			attacker_statuses, enemy_statuses_by_position.get(target_position, {}))
		var before := enemies.get_enemy(target_position)
		if not _basic.play(deck, party, enemies, card_id, target_position, final_damage):
			return _failure()
		var after := enemies.get_enemy(target_position)
		enemies.apply_statuses(applications)
		_tinker.record_successful_attack(card_id)
		return {"ok": true, "hits": [{
			"position": target_position,
			"damage": final_damage,
			"block_absorbed": before["block"] - after["block"],
			"hp_loss": before["hp"] - after["hp"],
			"statuses": _on_hit.status_for_confirmed_hit(card_id, true)
		}]}
	# All downstream operations are now guaranteed by the real models and
	# immutable preflight. The existing status bridge owns final-floor rounding.
	if not deck.try_spend_energy(cost_value):
		return _failure()
	var hits: Array[Dictionary] = []
	for position in positions:
		var event := _damage.resolve_vs_enemy(enemies, position, attack_damage,
			attacker_statuses, enemy_statuses_by_position.get(position, {}))
		# The validated living recipient guarantees this bridge succeeds.
		var statuses := _on_hit.status_for_confirmed_hit(card_id, event["ok"])
		hits.append({
			"position": position,
			"damage": event["damage"],
			"block_absorbed": event["block_absorbed"],
			"hp_loss": event["hp_loss"],
			"statuses": statuses
		})
	deck.discard_played(card_id)
	enemies.apply_statuses(applications)
	_tinker.record_successful_attack(card_id)
	return {"ok": true, "hits": hits}


func _valid_statuses(statuses: Dictionary) -> bool:
	for name in statuses:
		if not name is String or name not in ["bleed", "weak", "exposed"]:
			return false
		var count: Variant = statuses[name]
		if not count is int or count < 0:
			return false
	return true


func _failure() -> Dictionary:
	return {"ok": false, "hits": []}
