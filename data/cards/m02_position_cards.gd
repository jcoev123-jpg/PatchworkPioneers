class_name M02PositionCards
extends RefCounted
## Optional held movement cards; deliberately outside the starter catalog/deck.

const IDS := ["warden_backstep", "warden_advance"]


func get_definition(choice: Variant) -> Dictionary:
	if not choice is String or choice not in IDS:
		return {}
	var backstep: bool = choice == "warden_backstep"
	return {
		"id": choice, "display_name": "Backstep" if backstep else "Advance",
		"owner": "warden", "cost": 1,
		"from_positions": [1, 2] if backstep else [2, 3],
		"direction": 1 if backstep else -1, "action_kind": "adjacent_swap",
		"target_kind": "adjacent_ally", "to_positions": [], "effects": {},
		"illustration_path": "res://assets/paper/cards/%s.png" % choice,
		"starting_copies": 0,
	}
