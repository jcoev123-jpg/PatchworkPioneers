class_name StitchedFoeIntent
extends RefCounted
## Read-only projection of the rank-rotated live foe driver's next legal ability.
## It does not advance a turn, roll RNG, or inspect/modify an actor's private state.

static func choose(battle: StitchedRules, foe: Dictionary) -> Dictionary:
	if battle == null or battle.is_over() or foe.is_empty():
		return {}
	# Only the current, authoritative living foe can have an intent. Public
	# actor dictionaries are snapshots; never trust a detached impostor.
	var actor := battle.get_unit(str(foe.get("id", "")))
	if actor.is_empty() or str(actor.get("side", "")) != "foe" or bool(actor.get("dead", false)) \
			or bool(actor.get("lost", false)) or int(actor.get("hp", 0)) <= 0:
		return {}
	var result := {
		"foe_id": str(actor["id"]),
		"foe_name": str(actor.get("name", "")),
		"ability_id": "",
		"ability_name": "",
		"ability_kind": "",
		"target_rank": 0,
		"target_side": "",
		"affected_ranks": [],
		"multi": false,
		"pass": true,
		"stun": false,
	}
	# The rules consume a stunned actor's turn in _enter_turn before the
	# automatic driver can act. Do not announce a guaranteed attack.
	if int(actor.get("statuses", {}).get("stun", 0)) > 0:
		result["stun"] = true
		return result
	var authored: Array = actor.get("abilities", [])
	var offset := (battle.round_number() - 1) % maxi(1, authored.size())
	for step in range(authored.size()):
		var ability: Dictionary = authored[(offset + step) % authored.size()]
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor["rank"])) \
				or not battle._self_move_gate(actor, ability).is_empty():
			continue
		# A pulling strike reels the deepest reachable doll forward, so it scans the
		# back rank first. Everything else keeps the nearest-legal-rank order.
		var scan_ranks: Array[int] = [1, 2, 3, 4]
		if str(ability.get("target_side", "")) == "enemy" \
				and int(ability.get("effects", {}).get("pull", 0)) == 1:
			scan_ranks = [4, 3, 2, 1]
		for rank in scan_ranks:
			var targets: Array = battle._legal_targets(actor, ability, rank)
			if targets.is_empty():
				continue
			var ranks: Array[int] = []
			for target in targets:
				var target_rank := int(target["rank"])
				if not ranks.has(target_rank):
					ranks.append(target_rank)
			ranks.sort()
			result["ability_id"] = str(ability["id"])
			result["ability_name"] = str(ability["name"])
			result["ability_kind"] = str(ability.get("kind", ""))
			result["target_rank"] = rank
			result["target_side"] = str(targets[0]["side"])
			result["affected_ranks"] = ranks
			result["multi"] = bool(ability["multi"])
			# Authored, unmodified numbers only; never a hit/damage forecast.
			# Deep copies prevent callers from editing the live ability catalog.
			var authored_damage: Array = ability.get("dmg", [0, 0])
			var authored_effects: Dictionary = ability.get("effects", {})
			result["base_acc"] = int(ability.get("acc", 0))
			result["base_damage"] = authored_damage.duplicate(true)
			result["base_crit"] = int(ability.get("crit", 0))
			result["base_mark_damage"] = int(ability.get("mark_damage", 0))
			result["base_effects"] = authored_effects.duplicate(true)
			result["pass"] = false
			return result
	return result
