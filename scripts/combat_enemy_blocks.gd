class_name CombatEnemyBlocks
extends RefCounted
## Executes announced enemy Block intents; never advances turns or resolves attacks.

static func execute_blocks(enemies: CombatEnemies, blocks: Array) -> Dictionary:
	if enemies == null or not enemies.is_valid() or blocks == null:
		return {"ok": false, "events": []}
	
	var roster := enemies.get_enemies()
	var roster_size := roster.size()
	
	# Prevalidate: all blocks must be valid dictionaries with required structure
	var validations: Array[Dictionary] = []
	for block in blocks:
		if not block is Dictionary:
			return {"ok": false, "events": []}
		
		# Must have exactly type="block", enemy_position, amount, and no unknown keys
		if not block.has("type") or not block.has("enemy_position") or not block.has("amount"):
			return {"ok": false, "events": []}
		if block.size() != 3:
			return {"ok": false, "events": []}
		
		var type_val = block["type"]
		var position = block["enemy_position"]
		var amount = block["amount"]
		
		if type_val != "block":
			return {"ok": false, "events": []}
		if not position is int or position < 1 or position > roster_size:
			return {"ok": false, "events": []}
		if not amount is int or amount < 0:
			return {"ok": false, "events": []}
		
		validations.append({"position": position, "amount": amount})
	
	# Check for duplicate positions
	var seen_positions: Array[int] = []
	for v in validations:
		if v.position in seen_positions:
			return {"ok": false, "events": []}
		seen_positions.append(v.position)
	
	# Prevalidate: check overflow for living sources
	for v in validations:
		var enemy := roster[v.position - 1]
		if enemy["hp"] > 0:  # living source
			if v.amount > CombatEnemies.MAX_INT - enemy["block"]:
				return {"ok": false, "events": []}
	
	# All validations passed, now execute
	var events: Array[Dictionary] = []
	# Sort by ascending position
	validations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.position < b.position
	)
	
	for v in validations:
		var position = v.position
		var amount = v.amount
		var applied = false
		
		if enemies.is_slain(position):
			applied = false
		else:
			# Living source: add block (gain_block handles the logic)
			var success = enemies.gain_block(position, amount)
			applied = success  # Should always succeed since we prevalidated
		
		events.append({"enemy_position": position, "applied": applied})
	
	return {"ok": true, "events": events}