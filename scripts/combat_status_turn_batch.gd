class_name CombatStatusTurnBatch
extends RefCounted
## A proposed owner-side turn transition over defensive roster snapshots.
## This does not write to CombatParty, CombatEnemies, or the live game.


## "heroes" takes exactly three positions; "enemies" takes one to three.
## The entire input must be valid before any actor's statuses are advanced.
func tick_side(side: String, actors: Array) -> Dictionary:
	if not _valid_roster(side, actors):
		return {"ok": false, "actors": [], "events": []}

	var rules := CombatStatuses.new()
	var next_actors: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	for actor in actors:
		var current: Dictionary = actor
		var statuses: Dictionary = current.get("statuses", {})
		var tick: Dictionary = rules.end_owner_turn(current["hp"], current["block"], statuses)
		if not tick["ok"]:
			# No partial transition escapes, even if an underlying rule changes.
			return {"ok": false, "actors": [], "events": []}
		var next_actor: Dictionary = current.duplicate(true)
		next_actor["hp"] = tick["hp"]
		next_actor["block"] = tick["block"]
		next_actor["statuses"] = tick["statuses"]
		next_actors.append(next_actor)
		events.append({"side": side, "position": current["position"],
			"id": current["id"], "bleed_hp_loss": tick["bleed_hp_loss"]})
	return {"ok": true, "actors": next_actors, "events": events}


func _valid_roster(side: String, actors: Array) -> bool:
	if side == "heroes":
		if actors.size() != CombatParty.PARTY_SIZE:
			return false
	elif side == "enemies":
		if actors.is_empty() or actors.size() > CombatEnemies.MAX_ENEMIES:
			return false
	else:
		return false

	var ids: Array[String] = []
	for index in range(actors.size()):
		var record = actors[index]
		if not record is Dictionary:
			return false
		for required in ["id", "position", "hp", "max_hp", "block"]:
			if not record.has(required):
				return false
		var id = record["id"]
		var position = record["position"]
		var hp = record["hp"]
		var max_hp = record["max_hp"]
		var block = record["block"]
		if not id is String or id.is_empty() or id in ids:
			return false
		if not position is int or position != index + 1:
			return false
		if not max_hp is int or max_hp <= 0:
			return false
		if not hp is int or hp < 0 or hp > max_hp:
			return false
		if not block is int or block < 0:
			return false
		var statuses = record.get("statuses", {})
		if not statuses is Dictionary:
			return false
		for name in statuses:
			if not name is String:
				return false
			if name == "dodge_next_attack" or name == "blind_next_attack":
				var one_shot_count = statuses[name]
				if not one_shot_count is int or (one_shot_count != 0 and one_shot_count != 1):
					return false
				continue
			# Fear is admitted in exactly the same canonical shape CombatStatuses
			# validates: the literal boolean true, absent when inactive.
			if name == "cannot_buff_next_turn":
				var fear = statuses[name]
				if not fear is bool or not bool(fear):
					return false
				continue
			if name not in ["bleed", "weak", "exposed", "tangled", "riposte"]:
				return false
			var count = statuses[name]
			if not count is int or count < 0:
				return false
		ids.append(id)
	return true
