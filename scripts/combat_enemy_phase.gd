class_name CombatEnemyPhase
extends RefCounted
## Executes one announced mixed enemy phase. The owner advances CombatEnemyIntents
## separately; this service neither advances turns nor resets player state.


func execute_phase(party: CombatParty, enemies: CombatEnemies, intents: Array) -> Dictionary:
	if party == null or not party.is_valid() or enemies == null or not enemies.is_valid():
		return {"ok": false, "events": []}

	# Validate the *entire* batch, including living Block capacity, before
	# either underlying executor can mutate its owner.
	var roster := enemies.get_enemies()
	var seen: Array[int] = []
	var ordered: Array[Dictionary] = []
	for intent in intents:
		if not intent is Dictionary:
			return {"ok": false, "events": []}
		if not intent.has("type") or not intent.has("enemy_position") or not intent.has("amount"):
			return {"ok": false, "events": []}
		var kind = intent["type"]
		var position = intent["enemy_position"]
		var amount = intent["amount"]
		if not kind is String or (kind != "attack" and kind != "block"):
			return {"ok": false, "events": []}
		if not position is int or position < 1 or position > roster.size() or position in seen:
			return {"ok": false, "events": []}
		if not amount is int or amount < 0:
			return {"ok": false, "events": []}
		if kind == "attack":
			if intent.size() != 4 or not intent.has("target_position"):
				return {"ok": false, "events": []}
			var target = intent["target_position"]
			if not target is int or target < 1 or target > CombatParty.PARTY_SIZE:
				return {"ok": false, "events": []}
		else:
			if intent.size() != 3:
				return {"ok": false, "events": []}
			var enemy: Dictionary = roster[position - 1]
			if enemy["hp"] > 0 and amount > CombatEnemies.MAX_INT - enemy["block"]:
				return {"ok": false, "events": []}
		seen.append(position)
		ordered.append(intent.duplicate(true))

	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["enemy_position"] < b["enemy_position"])

	var attacks := CombatEnemyAttacks.new()
	var events: Array[Dictionary] = []
	for intent in ordered:
		var position: int = intent["enemy_position"]
		var applied := false
		if not enemies.is_slain(position):
			if intent["type"] == "attack":
				# CombatEnemyAttacks expects the raw record, without the kind.
				var record := {"enemy_position": position,
					"target_position": intent["target_position"], "amount": intent["amount"]}
				var attack_result := attacks.execute_attacks(party, [record])
				applied = attack_result["events"][0]["applied"]
			else:
				var block_result := CombatEnemyBlocks.execute_blocks(enemies, [intent])
				applied = block_result["events"][0]["applied"]
		var event: Dictionary = {"type": intent["type"],
			"enemy_position": position, "applied": applied}
		if intent["type"] == "attack":
			event["target_position"] = intent["target_position"]
		events.append(event)
	return {"ok": true, "events": events}
