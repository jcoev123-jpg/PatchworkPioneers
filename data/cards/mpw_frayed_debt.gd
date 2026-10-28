class_name MpwFrayedDebt
extends RefCounted
## P11 curse data. CombatDeck._draw applies the first-draw Exhaust for each battle.

const CARD_ID := "frayed_debt"


func get_card_ids() -> Array[String]:
	return [CARD_ID]


func get_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING or card_id != CARD_ID:
		return {}
	return {
		"id": CARD_ID,
		"display_name": "Frayed Debt",
		"owner": "",
		"card_type": "curse",
		"playable": false,
		"removable": true,
		"can_upgrade": false,
		"can_stitch": false,
		"reward_eligible": false,
		"starting_copies": 0,
		"exhaust_on_first_draw": true,
		"consumes_draw": true,
		"illustration_path": "res://assets/paper/cards/frayed_debt.png",
	}
