class_name CombatRagDuelistLungeCards
extends RefCounted
## Authenticated rules helper only; mounted-hand dispatch is a later task.
##
## One paid Lunge is one confirmed hit: the printed damage through
## CombatStatusAttacks (Weak/Exposed/Tangled keep their canonical math), then one
## forward swap with the living adjacent hero. The same confirmed hit answers the
## chosen foe's V3-2 enemy keywords by reusing CombatEnemyKeywordRules instead of
## restating them:
##   Thorns N - one retaliation of N against the Duelist at the slot he actually
##              occupies AFTER the swap, resolved through CombatParty so his own
##              Block absorbs before HP. It reads the frozen pre-hit foe, so a
##              blow fully absorbed by enemy Block still retaliates, and it runs
##              once per hit (a lethal thrust still provokes it).
##   Enrage   - one committed stack (0->1, 1->2, 2->3, capped at 3) for that same
##              foe on this one confirmed hit; it never adds to this strike.
## Both hooks receive the real resolve_vs_enemy receipt, so a refusal, a
## zero-damage hit, a forecast, a target selection or a replay can never trigger
## them, and a Lunge still never touches the run RNG.

const CARDS := {
	"rag_duelist_rapier_lunge": 5,
	"rag_duelist_rapier_lunge_plus": 7,
	"rag_duelist_needle_lunge": 6,
	"rag_duelist_needle_lunge_plus": 8,
}

var _attacks := CombatStatusAttacks.new()
var _keywords := CombatEnemyKeywordRules.new()


func is_supported_card(card_id: Variant) -> bool:
	return card_id is String and CARDS.has(card_id)


func _catalog_definition(card_id: String) -> Dictionary:
	if card_id.begins_with("rag_duelist_rapier_lunge"):
		return RagDuelistStarterCards.new().get_definition(card_id)
	return RagDuelistPoolCards.new().get_definition(card_id)


func _authentic(definition: Dictionary, card_id: String) -> bool:
	var effects: Variant = definition.get("effects")
	if not effects is Dictionary or not effects.get("damage") is int \
			or not effects.get("move_self_forward") is int:
		return false
	for field in ["from_positions", "to_positions"]:
		var positions: Variant = definition.get(field)
		if not positions is Array:
			return false
		for position in positions:
			if not position is int:
				return false
	return is_supported_card(card_id) and definition.get("id") == card_id \
		and definition.get("owner") == "rag_duelist" \
		and definition.get("cost") is int and definition.get("cost") == 1 \
		and definition.get("target_kind") == "enemy_single" \
		and definition.get("from_positions") == [2, 3] \
		and definition.get("to_positions") == [1, 2] \
		and definition.get("effects") == {"damage": CARDS[card_id], "move_self_forward": 1}


## Preflight both halves before the first write. No second paid movement transaction.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int = 0) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return {"ok": false}
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return {"ok": false}
	if not _authentic(_catalog_definition(card_id), card_id) \
			or not deck.hand.has(card_id) or deck.energy < 1:
		return {"ok": false}
	if not party.is_valid() or not enemies.is_valid() \
			or not _valid_actors(party.get_heroes()) or not _valid_actors(enemies.get_enemies()):
		return {"ok": false}
	var owner_position := 0
	for hero in party.get_heroes():
		if hero["id"] == "rag_duelist":
			owner_position = hero["position"]
	if owner_position not in [2, 3] or target_position not in [1, 2]:
		return {"ok": false}
	if enemies.get_enemy(target_position).is_empty() or enemies.is_slain(target_position):
		return {"ok": false}
	if not CombatPositionSwaps.preview_adjacent_swap(party, owner_position, -1)["ok"]:
		return {"ok": false}
	var mover: Dictionary = party._heroes[owner_position - 1]
	var neighbor: Dictionary = party._heroes[owner_position - 2]
	if CombatPositionSwaps._tangled_blocks(mover) or CombatPositionSwaps._tangled_blocks(neighbor):
		return {"ok": false}
	# The authentic PRE-HIT source record: its Thorns N and Enrage metadata are
	# frozen here, before the strike, so a reaction can never read what the hit
	# itself changed. Malformed keyword metadata refuses before any payment.
	var target: Dictionary = enemies.get_enemy(target_position)
	if not _keywords_acceptable(target):
		return {"ok": false}
	# All remaining calls are guaranteed by the preflight; no RNG is used by a Lunge.
	deck.try_spend_energy(1)
	deck.discard_played(card_id)
	var hit := _attacks.resolve_vs_enemy(enemies, target_position, CARDS[card_id],
		mover.get("statuses", {}), target.get("statuses", {}))
	# One stack for this confirmed hit on exactly that foe, before the swap (which
	# never touches the enemy roster). Plain, zero-damage and capped foes are inert.
	var enrage := _keywords.commit_enrage_after_hit(enemies, target_position, target, hit)
	# Swap original dictionaries, preserving every actor-local field and reference.
	party._heroes[owner_position - 2] = mover
	party._heroes[owner_position - 1] = neighbor
	mover["position"] = owner_position - 1
	neighbor["position"] = owner_position
	# Thorns answers the Duelist where he now stands, never the ally who took his
	# old slot; CombatParty keeps his own Block in front of his HP.
	var thorns := _keywords.resolve_thorns_retaliation(party, owner_position - 1,
		target, hit)
	hit.merge({"card_id": card_id, "cost": 1, "owner_position": owner_position,
		"destination_position": owner_position - 1, "target_position": target_position,
		"thorns_retaliation": thorns, "enrage_commit": enrage})
	return hit


## The chosen foe's Thorns N / Enrage metadata drives a real post-hit reaction, so
## it belongs to this play's authoritative shape. CombatEnemyKeywordRules owns both
## rules: a zero-damage probe validates every keyword field (Thorns count, Enrage
## flag, 0..3 stack count) and the living-record contract without mutating
## anything, so a malformed count or flag refuses BEFORE payment. An absent
## keyword is a plain foe and stays legal.
func _keywords_acceptable(target: Dictionary) -> bool:
	return _keywords.quote_enrage_after_hit(target,
		{"ok": true, "damage": 0, "block_absorbed": 0, "hp_loss": 0}).get("ok", false)


## The model's is_valid checks size only. Reject corrupt mutable actor records before pay.
func _valid_actors(actors: Array[Dictionary]) -> bool:
	var ids: Array[String] = []
	for index in range(actors.size()):
		var actor := actors[index]
		var id: Variant = actor.get("id")
		var hp: Variant = actor.get("hp")
		var maximum: Variant = actor.get("max_hp")
		var block: Variant = actor.get("block")
		var statuses: Variant = actor.get("statuses", {})
		if not id is String or id.is_empty() or ids.has(id):
			return false
		if not actor.get("position") is int or actor["position"] != index + 1:
			return false
		if not hp is int or not maximum is int or maximum <= 0 or hp < 0 or hp > maximum:
			return false
		if not block is int or block < 0 or not statuses is Dictionary:
			return false
		if not _attacks._valid_statuses(statuses):
			return false
		ids.append(id)
	return true
