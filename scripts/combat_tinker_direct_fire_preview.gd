class_name CombatTinkerDirectFirePreview
extends RefCounted
## Pure live-hand adapter for the single-target Tinker pool attacks.
## The resolver's own _prepare decides legality for EACH original enemy slot.

const IDS := [
	"tinker_rivet_shot", "tinker_rivet_shot_plus",
	"tinker_spring_trap", "tinker_spring_trap_plus",
	"tinker_long_barrel", "tinker_long_barrel_plus",
	"tinker_bobbin_cannon", "tinker_bobbin_cannon_plus"
]

var _catalog := TinkerPoolCards.new()
var _statuses := CombatStatuses.new()


func supports(card_id: String) -> bool:
	return card_id in IDS


func definition(card_id: String) -> Dictionary:
	if not supports(card_id):
		return {}
	var record: Dictionary = _catalog.get_definition(card_id)
	if record.get("id") != card_id or record.get("owner") != "tinker" \
			or record.get("target_kind") != "enemy_single":
		return {}
	return record


func get_preview(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, resolver: CombatTinkerPoolAttacks,
		cost_discount: int = 0) -> Dictionary:
	var unavailable := {"playable": false, "requires_selection": false,
		"target_positions": [] as Array[int], "hits": []}
	if resolver == null or deck == null or party == null or enemies == null \
			or definition(card_id).is_empty() or not resolver.is_supported_card(card_id):
		return unavailable
	var hits: Array[Dictionary] = []
	var positions: Array[int] = []
	for enemy in enemies.get_enemies():
		var position: int = int(enemy.get("position", 0))
		if position < 1 or position > CombatEnemies.MAX_ENEMIES \
				or enemy.get("hp", 0) <= 0:
			continue
		# This is the exact non-mutating resolver preflight, including held
		# copy, energy, living owner/FROM, target/TO and status overflow.
		var plan: Dictionary = resolver._prepare(deck, party, enemies,
			card_id, position, resolver.get_pinned(), cost_discount)
		if not plan.get("ok", false):
			continue
		var defender: Dictionary = enemies.get_enemy(position)
		var pinned_bonus := 0
		if resolver.get_pinned() != null:
			pinned_bonus = resolver.get_pinned().bonus_for_attack(enemies, position, "tinker")
		var damage: int = _statuses.adjusted_attack_damage(
			int(plan["attack_damage"]) + pinned_bonus,
			plan["owner_statuses"], defender.get("statuses", {}))
		var exposed: int = int(plan["exposed"])
		var before: int = int(defender.get("statuses", {}).get("exposed", 0))
		hits.append({"position": position, "damage": damage,
			"exposed_before": before, "exposed_after": before + exposed,
			"exposed_added": exposed})
		positions.append(position)
	if hits.is_empty():
		return unavailable
	return {"playable": true, "requires_selection": true,
		"target_positions": positions, "hits": hits}
