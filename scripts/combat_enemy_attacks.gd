class_name CombatEnemyAttacks
extends RefCounted
## Resolves a complete phase against fixed party positions, without RNG or scene state.


func execute_attacks(party: CombatParty, attacks: Array) -> Dictionary:
	if party == null or not party.is_valid():
		return {"ok": false, "events": []}
	var sources: Array[int] = []
	for attack in attacks:
		if not attack is Dictionary:
			return {"ok": false, "events": []}
		var source = attack.get("enemy_position")
		var target = attack.get("target_position")
		var amount = attack.get("amount")
		if not source is int or source < 1 or source > 3 or source in sources:
			return {"ok": false, "events": []}
		if not target is int or target < 1 or target > CombatParty.PARTY_SIZE:
			return {"ok": false, "events": []}
		if not amount is int or amount < 0:
			return {"ok": false, "events": []}
		sources.append(source)
	var ordered := attacks.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["enemy_position"] < b["enemy_position"])
	var events: Array = []
	for attack in ordered:
		var applied := party.apply_damage(attack["target_position"], attack["amount"])
		events.append({"enemy_position": attack["enemy_position"],
			"target_position": attack["target_position"], "applied": applied})
	return {"ok": true, "events": events}
