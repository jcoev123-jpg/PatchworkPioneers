class_name StitchedWrenGiftFieldNotes
extends RefCounted
## Passive Wren bedroom notes. The live gift catalog and pool are the only
## source of names and unlock eligibility; never draws an offer or edits a save.

const GATES := ["floor_4", "floor_8", "boss"]


static func examples(profile: Variant, source: Variant = null) -> Array[String]:
	var lines: Array[String] = []
	if not profile is Dictionary or profile.size() != 2:
		return lines
	for key in ["best_floor", "boss_wins"]:
		if not profile.get(key) is int or profile[key] < 0:
			return lines
	var live := StitchedWrenGifts.catalog()
	var book: Variant = live if source == null else source
	# Detached copies can be tested, but cannot forge a gift name or a gate.
	if not book is Dictionary or not bool(book.get("ok", false)) or book != live:
		return lines
	if not book.get("by_id") is Dictionary or not book.get("order") is Array:
		return lines
	var pool := StitchedWrenGifts.pool_for(profile)
	var families := {}
	for gate in GATES:
		families[gate] = []
	for id in book.order:
		var entry: Dictionary = book.by_id.get(id, {})
		if entry.is_empty():
			return []
		if bool(entry.get("basic", false)):
			continue
		var gate: String = str(entry.get("unlock", ""))
		if gate in GATES:
			families[gate].append(id)
	# A malformed or truncated family must never imply that everything unlocked.
	for gate in GATES:
		if families[gate].is_empty():
			return []
		for id in families[gate]:
			var available: bool = id in pool
			if available != _gate_open(gate, profile):
				return []
	lines.append("WREN'S HAND  |  Wren carries up to four gifts into a fight and uses one hand action each round. Stronger gifts can be once per fight; at fear 50 or more, his hands may shake.")
	lines.append("GIFT CHOICES  |  Finished fights and Events may offer three gifts. Choose one; if all four slots are full, swap an old gift out. Chosen gifts last for this run only.")
	for gate in GATES:
		if not _gate_open(gate, profile):
			var example: Dictionary = book.by_id[families[gate][0]]
			if not example.get("name") is String or str(example.name).is_empty():
				return []
			var milestone := "reach floor four" if gate == "floor_4" else (
				"reach floor eight" if gate == "floor_8" else "win a boss fight")
			lines.append("NEXT GIFT UNLOCK  |  " + milestone.capitalize() + " to add more gifts to later runs' possible offers (such as " + str(example.name) + "). None is promised in an offer.")
			return lines
	lines.append("GIFT UNLOCKS  |  Every gift family can now appear in later runs' offers. No particular gift is promised.")
	return lines


static func _gate_open(gate: String, profile: Dictionary) -> bool:
	match gate:
		"floor_4": return profile.best_floor >= 4
		"floor_8": return profile.best_floor >= 8
		"boss": return profile.boss_wins >= 1
	return false
